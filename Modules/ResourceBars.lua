local _, ns = ...
local L = ns.L

--------------------------------------------------
-- RESOURCE BARS
-- The player's resources as separate bars in the cast bar look, each its own Edit Mode frame:
--   Health      health, incoming heals and absorbs
--   Power       the current power in its colour; the five-second rule spark while it is mana
--   Mana        mana while another power is the main one (a druid in Bear or Cat Form)
--   Combo       combo points on the target (rogues, druids in Cat Form)
--   Swing       main-hand, off-hand and ranged swing timers (PLAYER_SWING), with a range check
-- Part of the Unit Frames module; replaces the Personal Resource Display and Blizzard's swing
-- timers. Secret-safe: values go straight into widgets, readable() guards every Lua test.
--------------------------------------------------

--------------------------------------------------
-- 1. MODULE REGISTRATION
--------------------------------------------------
ns.ResourceBars = ns.ResourceBars or {}
local RB = ns.ResourceBars
ns.modules["ResourceBars"] = RB

LibStub("AceEvent-3.0"):Embed(RB)

--------------------------------------------------
-- 2. UPVALUES / CONSTANTS
--------------------------------------------------
local _G = _G
local pairs, ipairs, pcall = pairs, ipairs, pcall
local math_floor, math_max, math_min = math.floor, math.max, math.min
local CreateFrame, InCombatLockdown, GetTime = CreateFrame, InCombatLockdown, GetTime
local LEM = LibStub("FlareEditMode")
local K = ns.UnitFrames and ns.UnitFrames.Kit

local canaccessvalue = canaccessvalue or function() return true end
local function readable(v) if canaccessvalue(v) then return v end end

local MANA = Enum.PowerType.Mana
local COMBO_POWER = Enum.PowerType.ComboPoints
local SWING = Enum.PlayerSwingType
local COMBO_MAX, COMBO_FALLBACK = 7, 5
local FSR_SECONDS = 5
local FSR_SPARK = "Interface\\CastingBar\\UI-CastingBar-Spark"
local SWING_SPARK = "Interface\\CastingBar\\UI-CastingBar-Spark"

local COLORS = {
    combo      = ns.COMBO_COLOR,
    swingMain  = { 0.86, 0.65, 0.39 },   -- a touch brighter than the off hand
    swingOff   = { 0.72, 0.54, 0.32 },
    swingRanged = { 0.45, 0.68, 0.40 },
    outOfRange = { 0.78, 0.28, 0.24 },
}

local BAR_ORDER = { "health", "power", "mana", "combo", "swingMain", "swingOff", "swingRanged" }
local BARS = {
    health      = { kind = "health", label = L["Health Bar"],      default = { point = "CENTER", x = 0, y = -148 } },
    power       = { kind = "power",  label = L["Power Bar"],       default = { point = "CENTER", x = 0, y = -170 } },
    mana        = { kind = "mana",   label = L["Druid Mana"],        default = { point = "CENTER", x = 0, y = -192 } },
    combo       = { kind = "combo",  label = L["Combo Points"],    default = { point = "CENTER", x = 0, y = -128 } },
    swingMain   = { kind = "swing",  label = L["Main-Hand Swing"], default = { point = "CENTER", x = 0, y = -248 },
                    swingType = SWING and SWING.MainHand, text = _G.SWING_TIMER_MAIN_HAND or "Main Hand" },
    swingOff    = { kind = "swing",  label = L["Off-Hand Swing"],  default = { point = "CENTER", x = 0, y = -266 },
                    swingType = SWING and SWING.OffHand, text = _G.SWING_TIMER_OFF_HAND or "Off Hand" },
    swingRanged = { kind = "swing",  label = L["Ranged Swing"],    default = { point = "CENTER", x = 0, y = -284 },
                    swingType = SWING and SWING.Ranged, text = _G.SWING_TIMER_RANGED or "Ranged" },
}

-- the same choices as every other "when does it show" in FlareUI (no Mouseover: these bars only display)
local SHOW_VALUES = {
    { text = L["Always"],                       value = "always", isRadio = true },
    { text = L["Combat"],                       value = "combat", isRadio = true },
    { text = L["Combat + Target"],              value = "target", isRadio = true },
    { text = L["Combat + Attackable Target"],   value = "harm",   isRadio = true },
}
local TEXT_VALUES = {
    { text = L["None"],            value = "none",    isRadio = true },
    { text = L["Percent"],         value = "percent", isRadio = true },
    { text = L["Value"],           value = "value",   isRadio = true },
    { text = L["Value + Percent"], value = "both",    isRadio = true },
}

local bars = {}            -- key -> holder
local fsrStart             -- GetTime() of the last mana cast while the five-second window runs

--------------------------------------------------
-- 3. SETTINGS ACCESS
--------------------------------------------------
local function GetResourceDb()
    local db = K and K.GetDb()
    return db and db.resource
end

local function Cfg(key)
    local rdb = GetResourceDb()
    if not rdb then return nil end
    rdb.bars = rdb.bars or {}
    rdb.bars[key] = rdb.bars[key] or {}
    return rdb.bars[key]
end

local function IsEditing()
    return LEM:IsInEditMode()
end

local function ClassFile()
    local _, class = UnitClass("player")
    return readable(class)
end

--------------------------------------------------
-- 4. AVAILABILITY (whether a bar has anything to show right now; Edit Mode shows them all)
--------------------------------------------------
local function PowerTypeNow()
    return readable(UnitPowerType("player"))
end

-- A druid in Bear or Cat Form, or anyone with mana whose main power is something else
local function ManaIsSecondary()
    local now = PowerTypeNow()
    if now == nil or now == MANA then return false end
    local max = readable(UnitPowerMax("player", MANA))
    return max == nil or max > 0
end

local function BuildsComboPoints()
    local class = ClassFile()
    if class == "ROGUE" then return true end
    if class == "DRUID" then return PowerTypeNow() == Enum.PowerType.Energy end
    return false
end

local function HasSwingWeapon(swingType)
    if not (SWING and swingType) then return false end
    local _, off, ranged = UnitAttackSpeed("player")
    if swingType == SWING.OffHand then
        off = readable(off)
        return off ~= nil and off > 0
    elseif swingType == SWING.Ranged then
        ranged = readable(ranged)
        return ranged ~= nil and ranged > 0
    end
    return true
end

local function IsAvailable(holder)
    local info = BARS[holder.key]
    if info.kind == "mana" then
        -- Druid mana: only while a form puts another power on the power bar
        return ManaIsSecondary()
    elseif info.kind == "combo" then
        return BuildsComboPoints()
    elseif info.kind == "swing" then
        return HasSwingWeapon(info.swingType)
    end
    return true
end

local function ShouldShow(holder)
    local cfg = Cfg(holder.key)
    if not cfg then return false end
    if IsEditing() then return true end
    if not IsAvailable(holder) then return false end
    local show = cfg.show or "always"
    if show == "always" then return true end
    if InCombatLockdown() or UnitAffectingCombat("player") then return true end
    if (show == "target" or show == "combatTarget") and UnitExists("target") then return true end
    if show == "harm" and UnitExists("target") then
        local canAttack = UnitCanAttack("player", "target")
        if canaccessvalue(canAttack) and canAttack then return true end
    end
    return false
end

--------------------------------------------------
-- 5. UPDATERS
--------------------------------------------------
local function SetText(holder, mode, value, percent)
    local text = holder.Text
    if mode == "percent" then
        text:SetFormattedText("%.0f%%", percent)
    elseif mode == "value" then
        text:SetText(AbbreviateNumbers(value))
    elseif mode == "both" then
        text:SetFormattedText("%s | %.0f%%", AbbreviateNumbers(value), percent)
    else
        text:SetText("")
    end
end

local function UpdateHealPrediction(holder)
    local heal, absorb = holder.HealBar, holder.AbsorbBar
    if not heal then return end
    local max = UnitHealthMax("player")
    heal:SetMinMaxValues(0, max)
    absorb:SetMinMaxValues(0, max)
    local calc = holder.HealCalc
    if calc and UnitGetDetailedHealPrediction and pcall(UnitGetDetailedHealPrediction, "player", "player", calc) then
        local okH, incoming = pcall(calc.GetIncomingHeals, calc)
        local okA, absorbs = pcall(calc.GetDamageAbsorbs, calc)
        if okH then heal:SetValue(incoming) end
        if okA then absorb:SetValue(absorbs) end
        return
    end
    pcall(function() heal:SetValue(UnitGetIncomingHeals("player")) end)
    pcall(function() absorb:SetValue(UnitGetTotalAbsorbs("player")) end)
end

local function UpdateHealth(holder)
    local cfg = Cfg("health")
    local bar = holder.Bar
    bar:SetMinMaxValues(0, UnitHealthMax("player"))
    bar:SetValue(UnitHealth("player"))
    bar:SetStatusBarColor(K.GetHealthColor("player", ns.ClassColorsOn()))
    if UnitIsDeadOrGhost("player") then
        holder.Text:SetText(UnitIsGhost("player") and K.GHOST_TEXT or K.DEAD_TEXT)
    else
        SetText(holder, cfg.text or "percent", UnitHealth("player"), UnitHealthPercent("player", true, K.percentCurve))
    end
    UpdateHealPrediction(holder)
end

local function UpdateFsrSpark()
    local power, mana = bars.power, bars.mana
    if fsrStart and GetTime() - fsrStart >= FSR_SECONDS then fsrStart = nil end
    local onPower = PowerTypeNow() == MANA
    if power and power.FsrSpark then
        power.FsrSpark:SetShown(fsrStart ~= nil and onPower and power:IsShown() and Cfg("power").fsr == true)
    end
    if mana and mana.FsrSpark then
        mana.FsrSpark:SetShown(fsrStart ~= nil and not onPower and mana:IsShown() and Cfg("mana").fsr == true)
    end
end

local function UpdatePower(holder)
    local bar = holder.Bar
    local powerType = UnitPowerType("player")
    bar:SetMinMaxValues(0, UnitPowerMax("player", powerType))
    bar:SetValue(UnitPower("player", powerType))
    bar:SetStatusBarColor(K.GetPowerColor("player"))
    SetText(holder, "value", UnitPower("player", powerType))   -- power and mana show the value only
end

local function UpdateMana(holder)
    local bar = holder.Bar
    bar:SetMinMaxValues(0, UnitPowerMax("player", MANA))
    bar:SetValue(UnitPower("player", MANA))
    bar:SetStatusBarColor(ns.MANA_BLUE[1], ns.MANA_BLUE[2], ns.MANA_BLUE[3])
    SetText(holder, "value", UnitPower("player", MANA))
end

-- How many segments: each is a bar from i - 1 to i fed the (possibly secret) point count
local function ComboCount()
    local max = readable(UnitPowerMax("player", COMBO_POWER))
    if not (max and max >= 1) then max = COMBO_FALLBACK end
    return math_min(max, COMBO_MAX)
end

local LayoutCombo   -- section 6

-- Classic: Blizzard's combo points (Core.lua), animated except right after a target change
local function UpdateCombo(holder)
    local count = ComboCount()
    if count ~= holder.count then
        holder.count = count
        LayoutCombo(holder)
    end
    local points = IsEditing() and 3 or GetComboPoints("player", "target")
    if not Cfg(holder.key).classic then
        for i = 1, count do holder.segments[i]:SetValue(points) end
        return
    end
    local animate = holder.lastPoints ~= nil and not IsEditing()
    for i = 1, count do ns.SetComboPoint(holder.gems[i], points, animate) end
    holder.lastPoints = (not IsEditing() and readable(points)) or nil
end

-- Swing: the bar fills over the swing, the spark rides its edge, the time counts down
local function SwingOnUpdate(holder)
    local remaining = holder.swingEnd - GetTime()
    if remaining <= 0 then
        holder.swingEnd, holder.swingDuration = nil, nil
        holder:SetScript("OnUpdate", nil)
        holder.Bar:SetValue(0)
        holder.Text:SetText("")
        holder.Spark:Hide()
        return
    end
    holder.Bar:SetValue((holder.swingDuration - remaining) / holder.swingDuration)
    if Cfg(holder.key).timer ~= false then holder.Text:SetFormattedText("%.1f", remaining) end
end

local function StartSwing(holder, duration)
    duration = readable(duration)
    if not (duration and duration > 0) then return end
    holder.swingDuration = duration
    holder.swingEnd = GetTime() + duration
    holder.Bar:SetMinMaxValues(0, 1)
    holder.Bar:SetValue(0)
    holder.Spark:Show()
    holder:SetScript("OnUpdate", SwingOnUpdate)
end

local function SetSwingRange(holder, outOfRange)
    holder.outOfRange = outOfRange and true or false
    local c = holder.outOfRange and COLORS.outOfRange or COLORS[holder.key]
    holder.Bar:SetStatusBarColor(c[1], c[2], c[3])
end

local function UpdateSwing(holder)
    local info = BARS[holder.key]
    if not holder.swingEnd then
        holder.Bar:SetMinMaxValues(0, 1)
        holder.Bar:SetValue(0)
        holder.Text:SetText("")
        holder.Spark:Hide()
    end
    holder.Label:SetText(Cfg(holder.key).label ~= false and info.text or "")
    if C_SwingTimer and info.swingType and not IsEditing() then
        local inRange = readable(C_SwingTimer.IsTargetWithinSwingRange(info.swingType))
        SetSwingRange(holder, inRange == false)
    else
        SetSwingRange(holder, false)
    end
end

local function UpdateBar(holder)
    local kind = BARS[holder.key].kind
    if kind == "health" then UpdateHealth(holder)
    elseif kind == "power" then UpdatePower(holder)
    elseif kind == "mana" then UpdateMana(holder)
    elseif kind == "combo" then UpdateCombo(holder)
    elseif kind == "swing" then UpdateSwing(holder) end
end

-- Edit Mode: each bar shows a sample
local function ApplyPreview(holder)
    local kind = BARS[holder.key].kind
    local cfg = Cfg(holder.key)
    if kind == "combo" then
        UpdateCombo(holder)
        return
    end
    local bar = holder.Bar
    bar:SetMinMaxValues(0, 1)
    if kind == "health" then
        bar:SetValue(0.75)
        bar:SetStatusBarColor(K.GetHealthColor("player", ns.ClassColorsOn()))
        SetText(holder, cfg.text or "both", 18000, 75)
        if holder.HealBar then holder.HealBar:SetValue(0); holder.AbsorbBar:SetValue(0) end
    elseif kind == "power" then
        bar:SetValue(0.6)
        bar:SetStatusBarColor(K.GetPowerColor("player"))
        SetText(holder, "value", 60)
    elseif kind == "mana" then
        bar:SetValue(0.4)
        bar:SetStatusBarColor(ns.MANA_BLUE[1], ns.MANA_BLUE[2], ns.MANA_BLUE[3])
        SetText(holder, "value", 1600)
    elseif kind == "swing" then
        holder:SetScript("OnUpdate", nil)
        holder.swingEnd = nil
        bar:SetValue(0.6)
        SetSwingRange(holder, false)
        holder.Spark:Show()
        holder.Text:SetText(cfg.timer ~= false and "1.4" or "")
        holder.Label:SetText(cfg.label ~= false and BARS[holder.key].text or "")
    end
end

local function ApplyShown(holder)
    local show = ShouldShow(holder)
    holder:SetShown(show)
    if show then
        if IsEditing() then ApplyPreview(holder) else UpdateBar(holder) end
    end
end

local function ApplyAllShown()
    for _, key in ipairs(BAR_ORDER) do
        if bars[key] then ApplyShown(bars[key]) end
    end
    UpdateFsrSpark()
end

--------------------------------------------------
-- 6. LAYOUT
--------------------------------------------------
-- FlareUI Thin keeps the full inset at any height; another border is fitted to a thin bar (BorderFit)
local DEFAULT_BAR_BORDER = "FlareUI Thin"
local function BarPadding(cfg, height)
    local _, pad = K.BorderFit(height, K.GetBorderFile(cfg.border or DEFAULT_BAR_BORDER))
    return pad
end

local function ApplyFrameLook(holder, cfg)
    local width, height = cfg.width or 220, cfg.height or 14
    local PADDING = BarPadding(cfg, height)
    holder:SetSize(width + 2 * PADDING, height + 2 * PADDING)
    holder.Backdrop:SetBackdrop({ bgFile = K.BACKDROP_FILE, insets = { left = PADDING, right = PADDING, top = PADDING, bottom = PADDING } })
    holder.Backdrop:SetBackdropColor(0, 0, 0, K.BG_OPACITY)
    K.ApplyBorderStyle(holder.Border, K.GetBorderFile(cfg.border or DEFAULT_BAR_BORDER), height + 2 * K.INSET)
end

-- Classic Combo Points: Blizzard's points in a row, twice the bar's height, no backdrop or border
local function LayoutClassicCombo(holder, cfg, count)
    local size = cfg.classicSize or (cfg.height or 12) * 2
    local spacing = ns.ComboPointStep(size)   -- Blizzard's art never touches its neighbour
    for i = 1, count do
        local gem = holder.gems[i]
        if gem then
            ns.SizeComboPoint(gem, size)
        else
            gem = ns.CreateComboPoint(holder, i, size, true)
            holder.gems[i] = gem
        end
        gem:ClearAllPoints()
        gem:SetPoint("TOPLEFT", holder, "TOPLEFT", (i - 1) * spacing, 0)
    end
    holder:SetSize((count - 1) * spacing + size, size)
end

LayoutCombo = function(holder)
    local cfg = Cfg(holder.key)
    local count = holder.count or COMBO_FALLBACK
    local classic = cfg.classic and true or false
    holder.Backdrop:SetShown(not classic)
    holder.Border:SetShown(not classic)
    for i = 1, COMBO_MAX do
        holder.segments[i]:SetShown(not classic and i <= count)
        holder.separators[i]:SetShown(not classic and i < count)
        if holder.gems[i] then holder.gems[i]:SetShown(classic and i <= count) end
    end
    holder.lastPoints = nil
    if classic then
        LayoutClassicCombo(holder, cfg, count)
        return
    end

    local width, height = cfg.width or 220, cfg.height or 12
    local PADDING = BarPadding(cfg, height)
    local texture = K.GetBarTexture(cfg.texture)
    for i = 1, count do
        local seg = holder.segments[i]
        local x, segWidth, px = ns.SegmentSpan(holder, width, count, i)
        seg:ClearAllPoints()
        seg:SetPoint("TOPLEFT", holder, "TOPLEFT", PADDING + x, -PADDING)
        seg:SetSize(segWidth, height)
        seg:SetStatusBarTexture(texture)
        seg.bg:SetTexture(texture)
        seg:SetStatusBarColor(COLORS.combo[1], COLORS.combo[2], COLORS.combo[3])
        seg:SetMinMaxValues(i - 1, i)
        -- the separator is the last pixel of this segment
        local sep = holder.separators[i]
        sep:ClearAllPoints()
        sep:SetPoint("TOPLEFT", holder, "TOPLEFT", PADDING + x + segWidth - px, -PADDING)
        sep:SetSize(px, height)
    end
end

local function LayoutBar(holder)
    local cfg = Cfg(holder.key)
    if not cfg then return end
    local kind = BARS[holder.key].kind
    local PADDING = BarPadding(cfg, cfg.height or 14)
    ApplyFrameLook(holder, cfg)
    local db = K.GetDb()
    local font = db and (db.fontPower or db.font)
    if cfg.textSize then font = setmetatable({ size = cfg.textSize }, { __index = font or {} }) end

    if kind == "combo" then
        holder.count = ComboCount()
        LayoutCombo(holder)
        return
    end

    local bar = holder.Bar
    local texture = K.GetBarTexture(cfg.texture)
    bar:SetStatusBarTexture(texture)
    bar.bg:SetTexture(texture)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", holder, "TOPLEFT", PADDING, -PADDING)
    bar:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -PADDING, PADDING)

    K.ApplyFont(holder.Text, font)
    holder.Text:ClearAllPoints()
    if kind == "swing" then
        K.ApplyFont(holder.Label, font)
        holder.Label:ClearAllPoints()
        holder.Label:SetPoint("LEFT", bar, "LEFT", K.TEXT_INSET, 0)
        holder.Text:SetPoint("RIGHT", bar, "RIGHT", -K.TEXT_INSET, 0)
        holder.Text:SetJustifyH("RIGHT")
        local spark = holder.Spark
        spark:ClearAllPoints()
        spark:SetSize(math_max(8, (cfg.height or 10)), math_max(18, (cfg.height or 10) * 2.2))
        spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", 0, 0)
    else
        local align = cfg.textAlign or "CENTER"
        holder.Text:SetJustifyH(align)
        if align == "LEFT" then
            holder.Text:SetPoint("LEFT", bar, "LEFT", K.TEXT_INSET, 0)
        elseif align == "RIGHT" then
            holder.Text:SetPoint("RIGHT", bar, "RIGHT", -K.TEXT_INSET, 0)
        else
            holder.Text:SetPoint("CENTER", bar, "CENTER", 0, 0)
        end
    end

    if holder.HealClip then
        local clip, heal, absorb = holder.HealClip, holder.HealBar, holder.AbsorbBar
        local fill = bar:GetStatusBarTexture()
        local width = cfg.width or 220
        clip:ClearAllPoints()
        clip:SetPoint("TOPLEFT", fill, "TOPRIGHT", 0, 0)
        clip:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
        heal:ClearAllPoints()
        heal:SetWidth(width)
        heal:SetPoint("TOPLEFT", clip, "TOPLEFT", 0, 0)
        heal:SetPoint("BOTTOMLEFT", clip, "BOTTOMLEFT", 0, 0)
        absorb:ClearAllPoints()
        absorb:SetWidth(width)
        absorb:SetReverseFill(true)
        absorb:SetPoint("TOPRIGHT", clip, "TOPRIGHT", 0, 0)
        absorb:SetPoint("BOTTOMRIGHT", clip, "BOTTOMRIGHT", 0, 0)
        absorb:SetStatusBarTexture(K.GetBarTexture(K.ABSORB_TEXTURE))
        absorb:SetStatusBarColor(K.ABSORB_COLOR[1], K.ABSORB_COLOR[2], K.ABSORB_COLOR[3], K.ABSORB_COLOR[4])
    end
end

--------------------------------------------------
-- 7. POSITION (per Edit Mode layout)
--------------------------------------------------
local function GetLayoutStore(layoutName)
    local rdb = GetResourceDb()
    if not rdb then return nil end
    layoutName = layoutName or LEM:GetActiveLayoutName() or "Modern"
    rdb.layouts = rdb.layouts or {}
    rdb.layouts[layoutName] = rdb.layouts[layoutName] or {}
    return rdb.layouts[layoutName]
end

local function ApplyPosition(holder, layoutName)
    local store = GetLayoutStore(layoutName)
    local pos = (store and store[holder.key]) or BARS[holder.key].default
    holder:ClearAllPoints()
    holder:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or 0, pos.y or 0)
end

-- flush: the borders overlap by a pixel; a gentle pull, and the arrow keys stay free for the last pixel
local SNAP_DISTANCE, SNAP_GAP, SNAP_ALIGN = 10, -1, 30

-- The nearest other bar this one sits just above or below (edges within SNAP_DISTANCE, centres
-- within SNAP_ALIGN sideways): the centre it lands on, centred on the other bar and flush with it.
-- Edit Mode calls it while the bar is dragged (FlareEditMode SetFrameSnapper), and shows the spot.
local function SnapTarget(holder)
    local cx = holder:GetCenter()
    local top, bottom = holder:GetTop(), holder:GetBottom()
    if not (cx and top and bottom) then return nil end
    local half = (top - bottom) / 2
    local best, bestDistance
    for _, other in pairs(bars) do
        if other ~= holder and other:IsShown() then
            local ox = other:GetCenter()
            local otop, obottom = other:GetTop(), other:GetBottom()
            if ox and otop and obottom and math.abs(ox - cx) <= SNAP_ALIGN then
                local below = math.abs(bottom - otop)    -- this bar resting on the other
                local above = math.abs(obottom - top)    -- this bar hanging under the other
                if below <= SNAP_DISTANCE and (not bestDistance or below < bestDistance) then
                    best, bestDistance = { x = ox, y = otop + SNAP_GAP + half }, below
                end
                if above <= SNAP_DISTANCE and (not bestDistance or above < bestDistance) then
                    best, bestDistance = { x = ox, y = obottom - SNAP_GAP - half }, above
                end
            end
        end
    end
    if best then return best.x, best.y end
end

local function OnFrameMoved(holder, layoutName, point, x, y)
    local store = GetLayoutStore(layoutName)
    if not store then return end
    store[holder.key] = { point = point, x = math_floor(x + 0.5), y = math_floor(y + 0.5) }
end

--------------------------------------------------
-- 8. FRAME CREATION
--------------------------------------------------
local function CreateHolder(key)
    local info = BARS[key]
    local holder = CreateFrame("Frame", "FlareUI_Resource_" .. key, UIParent)
    holder.key = key
    holder:SetFrameStrata("MEDIUM")
    holder:SetClampedToScreen(true)
    holder.editModeName = "FlareUI " .. info.label
    for index, k in ipairs(BAR_ORDER) do
        if k == key then holder:SetFrameLevel(10 + (#BAR_ORDER - index) * 10) end
    end
    local level = holder:GetFrameLevel()

    holder.Backdrop = CreateFrame("Frame", nil, holder, "BackdropTemplate")
    holder.Backdrop:SetAllPoints()
    holder.Backdrop:SetFrameLevel(level)
    holder.Border = CreateFrame("Frame", nil, holder, "BackdropTemplate")
    holder.Border:SetAllPoints()
    holder.Border:SetFrameLevel(level + 3)
    local overlay = CreateFrame("Frame", nil, holder)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(level + 4)
    holder.Text = overlay:CreateFontString(nil, "OVERLAY")
    holder.Text:SetWordWrap(false)

    if info.kind == "combo" then
        holder.segments, holder.separators, holder.gems = {}, {}, {}
        -- the separators sit over the segments and under the border
        local sepFrame = CreateFrame("Frame", nil, holder)
        sepFrame:SetAllPoints()
        sepFrame:SetFrameLevel(level + 2)
        for i = 1, COMBO_MAX do
            local seg = K.CreateBar(holder, level + 1)
            seg:Hide()
            holder.segments[i] = seg
            -- a one-pixel black line between segments
            local sep = sepFrame:CreateTexture(nil, "BACKGROUND")
            local c = ns.SEGMENT_LINE_COLOR
            sep:SetColorTexture(c[1], c[2], c[3], c[4])
            sep:Hide()
            holder.separators[i] = sep
        end
        holder.Text:Hide()
    else
        holder.Bar = K.CreateBar(holder, level + 1)
    end

    if info.kind == "health" then
        local clip = CreateFrame("Frame", nil, holder.Bar)
        clip:SetFrameLevel(holder.Bar:GetFrameLevel() + 1)
        clip:SetClipsChildren(true)
        local heal = CreateFrame("StatusBar", nil, clip)
        heal:SetStatusBarTexture(K.GetBarTexture(K.HEAL_TEXTURE))
        heal:SetStatusBarColor(K.HEAL_COLOR[1], K.HEAL_COLOR[2], K.HEAL_COLOR[3], K.HEAL_COLOR[4])
        heal:SetMinMaxValues(0, 1)
        heal:SetValue(0)
        local absorb = CreateFrame("StatusBar", nil, clip)
        absorb:SetMinMaxValues(0, 1)
        absorb:SetValue(0)
        holder.HealClip, holder.HealBar, holder.AbsorbBar = clip, heal, absorb
        if CreateUnitHealPredictionCalculator then
            local ok, calc = pcall(CreateUnitHealPredictionCalculator)
            if ok and calc then holder.HealCalc = calc end
        end
    end

    if info.kind == "power" or info.kind == "mana" then
        -- the five-second rule: a spark crosses the bar for five seconds after a mana cast
        local fsr = CreateFrame("Frame", nil, holder.Bar)
        fsr:SetAllPoints(holder.Bar)
        fsr:SetFrameLevel(holder.Bar:GetFrameLevel() + 1)
        fsr:Hide()
        local spark = fsr:CreateTexture(nil, "OVERLAY")
        spark:SetTexture(FSR_SPARK)
        spark:SetBlendMode("ADD")
        fsr.Spark = spark
        fsr:SetScript("OnShow", function(self)
            local h = holder.Bar:GetHeight()
            self.Spark:SetSize(math_max(h, 8), math_max(h * 2.2, 18))
        end)
        fsr:SetScript("OnUpdate", function(self)
            local elapsed = fsrStart and (GetTime() - fsrStart)
            if not elapsed or elapsed >= FSR_SECONDS then
                fsrStart = nil
                self:Hide()
                return
            end
            self.Spark:SetPoint("CENTER", holder.Bar, "LEFT", holder.Bar:GetWidth() * elapsed / FSR_SECONDS, 0)
        end)
        holder.FsrSpark = fsr
    end

    if info.kind == "swing" then
        holder.Label = overlay:CreateFontString(nil, "OVERLAY")
        holder.Label:SetJustifyH("LEFT")
        holder.Spark = holder.Bar:CreateTexture(nil, "OVERLAY")
        holder.Spark:SetTexture(SWING_SPARK)
        holder.Spark:SetBlendMode("ADD")
        holder.Spark:Hide()
    end

    holder:Hide()
    bars[key] = holder
    return holder
end

--------------------------------------------------
-- 9. EDIT MODE SETTINGS
--------------------------------------------------
local function Relayout(key)
    local holder = bars[key]
    if not holder then return end
    LayoutBar(holder)
    ApplyShown(holder)
end

local function BuildSettings(key)
    local info = BARS[key]
    local defaults = ns.defaults and ns.defaults.profile.unitframes.resource.bars[key] or {}
    local function get(field, default)
        return function()
            local cfg = Cfg(key)
            local v = cfg and cfg[field]
            if v == nil then return default end
            return v
        end
    end
    local function set(field)
        return function(_, value)
            local cfg = Cfg(key)
            if not cfg then return end
            cfg[field] = value
            Relayout(key)
        end
    end
    -- classic combo gems have one Size; the bar's width and height wait for the bar style
    local function classicOn() local cfg = Cfg(key); return info.kind == "combo" and cfg and cfg.classic and true or false end
    local function classicOff() return not classicOn() end
    local settings = {
        { name = L["Show"], kind = LEM.SettingType.Dropdown, default = defaults.show or "always", values = SHOW_VALUES, get = get("show", "always"), set = set("show") },
        { name = L["Width"], kind = LEM.SettingType.Slider, default = defaults.width or 220, minValue = 40, maxValue = 600, valueStep = 2, get = get("width", 220), set = set("width"), hidden = classicOn },
        { name = L["Height"], kind = LEM.SettingType.Slider, default = defaults.height or 14, minValue = 4, maxValue = 48, valueStep = 1, get = get("height", defaults.height or 14), set = set("height"), hidden = classicOn },
    }
    local function add(item) settings[#settings + 1] = item end
    -- power and mana always show the value: percentages of a (possibly secret) power are unreliable
    if info.kind == "health" then
        add({ name = L["Text"], kind = LEM.SettingType.Dropdown, default = defaults.text or "both", values = TEXT_VALUES, get = get("text", defaults.text or "both"), set = set("text") })
    end
    if info.kind == "combo" then
        add({ name = L["Classic Combo Points"], kind = LEM.SettingType.Checkbox, default = false, get = get("classic", false),
              set = function(layoutName, value)
                  set("classic")(layoutName, value)
                  if bars[key] then LEM:RefreshFrameSettings(bars[key]) end
              end })
        add({ name = L["Size"], kind = LEM.SettingType.Slider, default = 24, minValue = 12, maxValue = 48, valueStep = 1,
              get = get("classicSize", 24), set = set("classicSize"), hidden = classicOff })
    end
    if info.kind == "power" or info.kind == "mana" then
        add({ name = L["Five-Second Rule"], kind = LEM.SettingType.Checkbox, default = false, get = get("fsr", false), set = set("fsr"),
              desc = L["A spark crosses the bar for five seconds after a spell that costs mana: spirit regen comes back when it ends."] })
    end
    return settings
end

--------------------------------------------------
-- 10. EVENTS
--------------------------------------------------
local function EnableSwingRange()
    if not (C_SwingTimer and C_SwingTimer.EnableRangeCheck) then return end
    for _, key in ipairs({ "swingMain", "swingOff", "swingRanged" }) do
        local info = BARS[key]
        if info.swingType and bars[key] then
            pcall(C_SwingTimer.EnableRangeCheck, info.swingType, true)
        end
    end
end

function RB:OnEvent(event, arg1, arg2, arg3)
    if IsEditing() then return end
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_HEAL_PREDICTION" or event == "UNIT_ABSORB_AMOUNT_CHANGED" then
        if bars.health and bars.health:IsShown() then UpdateHealth(bars.health) end
    elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER" then
        if bars.power and bars.power:IsShown() then UpdatePower(bars.power) end
        if bars.mana and bars.mana:IsShown() then UpdateMana(bars.mana) end
        local comboChange = not (event == "UNIT_POWER_FREQUENT" and canaccessvalue(arg2) and arg2 ~= "COMBO_POINTS")
        if comboChange and bars.combo and bars.combo:IsShown() then UpdateCombo(bars.combo) end
    elseif event == "UNIT_DISPLAYPOWER" then
        -- a shapeshift: the main power changes, the mana and combo bars come or go
        ApplyAllShown()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local spellID = arg3
        if not (spellID and canaccessvalue(spellID)) then return end
        local costs = C_Spell.GetSpellPowerCost(spellID)
        if not costs then return end
        for _, cost in ipairs(costs) do
            if canaccessvalue(cost.type) and cost.type == MANA then
                local amount = cost.cost
                if not canaccessvalue(amount) or (type(amount) == "number" and amount > 0) then
                    fsrStart = GetTime()
                    UpdateFsrSpark()
                end
                return
            end
        end
    elseif event == "PLAYER_SWING" then
        local duration, swingType = arg1, arg2
        for _, key in ipairs({ "swingMain", "swingOff", "swingRanged" }) do
            local holder = bars[key]
            if holder and BARS[key].swingType == swingType then StartSwing(holder, duration) end
        end
    elseif event == "PLAYER_SWING_RANGE_UPDATE" then
        local swingType, isInRange, checksRange = arg1, arg2, arg3
        for _, key in ipairs({ "swingMain", "swingOff", "swingRanged" }) do
            local holder = bars[key]
            if holder and BARS[key].swingType == swingType then
                SetSwingRange(holder, readable(checksRange) and readable(isInRange) == false)
            end
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        if bars.combo then bars.combo.lastPoints = nil end   -- the new target's points do not animate
        ApplyAllShown()
    else
        -- combat in or out, gear, attack speed, entering the world: everything may come or go
        if event == "PLAYER_ENTERING_WORLD" or event == "WEAPON_SLOT_CHANGED" then EnableSwingRange() end
        ApplyAllShown()
    end
end

local UNIT_EVENTS = {
    "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_HEAL_PREDICTION", "UNIT_ABSORB_AMOUNT_CHANGED",
    "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
    "UNIT_SPELLCAST_SUCCEEDED", "UNIT_ATTACK_SPEED",
}
local EVENTS = {
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD",
    "PLAYER_SWING", "PLAYER_SWING_RANGE_UPDATE", "WEAPON_SLOT_CHANGED", "PLAYER_IN_COMBAT_CHANGED",
}

--------------------------------------------------
-- 11. PUBLIC
--------------------------------------------------
function RB:Refresh()
    if not self.initialized then return end
    for _, key in ipairs(BAR_ORDER) do
        local holder = bars[key]
        if holder then
            LayoutBar(holder)
            ApplyPosition(holder)
        end
    end
    ApplyAllShown()
end

-- Druid mana is for druids only
local function BarOn(key)
    local cfg = Cfg(key)
    if key == "mana" and ClassFile() ~= "DRUID" then return false end
    return cfg and cfg.enabled and true or false
end

-- loads when any bar is on
function RB:ShouldLoad()
    local db = K and K.GetDb()
    -- its own module in the 2.0 settings (unitframes.resource.enabled), apart from the unit frames
    if not (db and db.resource and db.resource.enabled) then return false end
    for _, key in ipairs(BAR_ORDER) do
        if BarOn(key) then return true end
    end
    return false
end

-- Blizzard's versions are parked while ours are on (back after a reload). The Personal Resource
-- Display goes whenever the module is on (it also shows combo points); each swing bar has its own.
local BLIZZARD_COUNTERPARTS = {
    { addon = "Blizzard_PersonalResourceDisplay", frame = "PersonalResourceDisplayFrame", always = true },
    { addon = "Blizzard_SwingTimer", frame = "SwingTimerMainHandFrame", bars = { "swingMain" } },
    { addon = "Blizzard_SwingTimer", frame = "SwingTimerOffHandFrame",  bars = { "swingOff" } },
    { addon = "Blizzard_SwingTimer", frame = "SwingTimerRangedFrame",   bars = { "swingRanged" } },
}

local function HideBlizzardCounterparts()
    for _, entry in ipairs(BLIZZARD_COUNTERPARTS) do
        local wanted = entry.always or false
        for _, key in ipairs(entry.bars or {}) do if BarOn(key) then wanted = true end end
        if wanted then
            local function hide() if _G[entry.frame] then K.HardHide(entry.frame) end end
            if _G[entry.frame] then
                hide()
            elseif EventUtil and EventUtil.ContinueOnAddOnLoaded then
                EventUtil.ContinueOnAddOnLoaded(entry.addon, hide)
            end
        end
    end
end

function RB:Init()
    if self.initialized or not K then return end
    self.initialized = true

    for _, key in ipairs(BAR_ORDER) do
        local info = BARS[key]
        if BarOn(key) and (info.kind ~= "swing" or info.swingType) then
            local holder = CreateHolder(key)
            LEM:AddFrame(holder, OnFrameMoved, info.default, holder.editModeName)
            if LEM.SetFrameSnapper then LEM:SetFrameSnapper(holder, SnapTarget) end
            LEM:AddFrameSettings(holder, BuildSettings(key))
        end
    end

    local events = CreateFrame("Frame")
    events:SetScript("OnEvent", function(_, event, ...) RB:OnEvent(event, ...) end)
    for _, event in ipairs(UNIT_EVENTS) do pcall(events.RegisterUnitEvent, events, event, "player") end
    for _, event in ipairs(EVENTS) do pcall(events.RegisterEvent, events, event) end
    self.events = events

    LEM:RegisterCallback("layout", function(layoutName)
        for _, holder in pairs(bars) do ApplyPosition(holder, layoutName) end
    end)
    LEM:RegisterCallback("enter", function() ApplyAllShown() end)
    LEM:RegisterCallback("exit", function()
        for _, holder in pairs(bars) do
            if holder.swingEnd == nil and holder.Spark then holder.Spark:Hide() end
        end
        ApplyAllShown()
    end)

    HideBlizzardCounterparts()
    EnableSwingRange()
    self:Refresh()
end
