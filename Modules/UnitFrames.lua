local _, ns = ...

--------------------------------------------------
-- 1. MODULE REGISTRATION
-- Custom player / target / target-of-target / focus / pet frames in the FlareUI look.
-- Written for 12.x secret values: every health/power/name value is handed straight to a
-- widget setter and never inspected. Positions and per-frame tuning live in Edit Mode
-- through FlareEditMode; Blizzard's own frames are parked out of sight.
--------------------------------------------------
ns.UnitFrames = ns.UnitFrames or {}
local UF = ns.UnitFrames
ns.modules["UnitFrames"] = UF

LibStub("AceEvent-3.0"):Embed(UF)

--------------------------------------------------
-- 2. UPVALUES
--------------------------------------------------
local _G = _G
local pairs, ipairs, select, type, tostring = pairs, ipairs, select, type, tostring
local pcall = pcall
local unpack = unpack
local math_floor = math.floor
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local C_Timer = C_Timer
local LSM = LibStub("LibSharedMedia-3.0")
local LEM = LibStub("FlareEditMode")

local canaccessvalue = canaccessvalue or function() return true end

--------------------------------------------------
-- 3. CONSTANTS
--------------------------------------------------
local BORDER_FILE   = "Interface\\Tooltips\\UI-Tooltip-Border"
local BACKDROP_FILE = "Interface\\Buttons\\WHITE8x8"
-- Fixed look (not user-facing): the border art overlaps the bar edges by INSET, the backdrop is
-- fully transparent, the border band is 16 px. Bar and border textures are per frame in Edit Mode;
-- the border colour is FlareUI's fixed bronze.
local INSET         = 4
local BORDER_SIZE   = 16
local BG_OPACITY    = 0
local DEFAULT_BORDER_COLOR = ns.BORDER_COLOR   -- FlareUI's border bronze, fixed (no option)
local DEFAULT_BORDER  = "Blizzard Tooltip"
local DEFAULT_TEXTURE = "Flat"
local SEPARATOR_TEXTURE = "Interface\\Common\\UI-TooltipDivider-Transparent"   -- same as chat / damage meter
local SEPARATOR_HEIGHT  = 8
local AURA_GAP      = 4     -- between the frame (or cast bar) and the aura rows
local TEXT_INSET    = 4
local CAST_HEIGHT   = 18
local CAST_GAP      = 4
local CAST_ICON_GAP = 0     -- icon sits flush against the bar
local RAID_ICON     = 18     -- the smallest pet happiness face
local RAID_ICON_SHARE = 0.5  -- raid marker: mid health bar, this share of the bar's height
local HAPPINESS_SHARE = 0.7  -- pet happiness face: mid health bar, this share of the bar's height

local DEAD_TEXT     = _G.DEAD or "Dead"
local GHOST_TEXT    = _G.GHOST or "Ghost"
local OFFLINE_TEXT  = _G.PLAYER_OFFLINE or "Offline"

-- Reaction colours (Blizzard's FACTION_BAR_COLORS shape, fixed here so they never change)
local REACTION = {
    [1] = { 0.87, 0.27, 0.27 },  -- hated
    [2] = { 0.87, 0.27, 0.27 },  -- hostile
    [3] = { 0.87, 0.27, 0.27 },  -- unfriendly
    [4] = { 0.93, 0.78, 0.25 },  -- neutral
    [5] = { 0.30, 0.78, 0.30 },  -- friendly
    [6] = { 0.30, 0.78, 0.30 },
    [7] = { 0.30, 0.78, 0.30 },
    [8] = { 0.30, 0.78, 0.30 },
}
local GREY      = { 0.55, 0.55, 0.55 }
local CAST_COLOR            = { 0.80, 0.60, 0.36 }   -- #CC995C
local CAST_NOINTERRUPT      = { 0.55, 0.55, 0.55 }
local CAST_CHANNEL          = { 0.30, 0.65, 0.90 }
-- the player's own bar is cool-toned so it never reads as the target's
local PLAYER_CAST_COLOR     = { 0.36, 0.56, 0.78 }   -- #5C8FC7 steel blue
local PLAYER_CAST_CHANNEL   = { 0.50, 0.75, 0.88 }   -- #80BFE0 lighter sky for channels

-- Power colours (PowerBarColor's shape; fallback if the global is missing)
local POWER_FALLBACK = {
    MANA        = { 0.00, 0.00, 1.00 },
    RAGE        = { 1.00, 0.00, 0.00 },
    FOCUS       = { 1.00, 0.50, 0.25 },
    ENERGY      = { 1.00, 1.00, 0.00 },
    RUNIC_POWER = { 0.00, 0.82, 1.00 },
    LUNAR_POWER = { 0.30, 0.52, 0.90 },
    MAELSTROM   = { 0.00, 0.50, 1.00 },
    INSANITY    = { 0.40, 0.00, 0.80 },
    FURY        = { 0.79, 0.26, 0.99 },
    PAIN        = { 1.00, 0.61, 0.00 },
}

-- Unit definitions. `driver` is the visibility condition; player is always shown.
local UNITS = {
    player = {
        key = "Player", label = "Player", order = 1, auras = true,
        blizzard = { "PlayerFrame" },
        events = { "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE" },
        globalEvents = { PLAYER_UPDATE_RESTING = true, GROUP_ROSTER_UPDATE = true, PARTY_LEADER_CHANGED = true,
                         PLAYER_FLAGS_CHANGED = "player" },
        indicators = { rest = true, leader = true, pvp = true, heals = true },
    },
    target = {
        mirrorable = true,
        key = "Target", label = "Target", order = 2, auras = true,
        blizzard = { "TargetFrame" },
        driver = "[@target,exists] show; hide",
        globalEvents = { PLAYER_TARGET_CHANGED = true, GROUP_ROSTER_UPDATE = true, PARTY_LEADER_CHANGED = true, PLAYER_FLAGS_CHANGED = "target" },
        castbar = true,
        comboPoints = true,
        indicators = { leader = true, pvp = true, classification = true, quest = true, threat = true, heals = true },
    },
    targettarget = {
        key = "TargetOfTarget", label = "Target of Target", order = 3,
        driver = "[@targettarget,exists] show; hide",
        globalEvents = { PLAYER_TARGET_CHANGED = true, UNIT_TARGET = "target" },
    },
    focus = {
        mirrorable = true,
        key = "Focus", label = "Focus", order = 4, auras = true,
        blizzard = { "FocusFrame", "TargetofFocusFrame" },
        driver = "[@focus,exists] show; hide",
        globalEvents = { PLAYER_FOCUS_CHANGED = true },
        castbar = true,
        indicators = { classification = true, threat = true, heals = true },
    },
    pet = {
        key = "Pet", label = "Pet", order = 5, happiness = true, noRaidIcon = true,
        blizzard = { "PetFrame" },
        driver = "[@pet,exists] show; hide",
        indicators = { heals = true },
        globalEvents = { UNIT_PET = "player" },
    },
}
local UNIT_ORDER = { "player", "target", "targettarget", "focus", "pet" }

-- the player's power events the target frame also takes, for its combo strip
local COMBO_EVENTS = { UNIT_POWER_FREQUENT = true, UNIT_MAXPOWER = true, UNIT_DISPLAYPOWER = true }

local UNIT_EVENTS = {
    "UNIT_HEALTH", "UNIT_MAXHEALTH",
    "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_POWER_FREQUENT",
    "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_FACTION", "UNIT_CONNECTION", "UNIT_FLAGS",
    "UNIT_CLASSIFICATION_CHANGED",
}

local CAST_EVENTS = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
}

local HEALTH_TEXT_MODES = {
    { text = "None",            value = "none",    isRadio = true },
    { text = "Percent",         value = "percent", isRadio = true },
    { text = "Value",           value = "value",   isRadio = true },
    { text = "Value + Percent", value = "both",    isRadio = true },
}

--------------------------------------------------
-- 4. HELPERS
--------------------------------------------------
local frames = {}          -- unit -> frame
local pendingLayout = false
local LayoutAuras          -- defined in 5b

local function GetDb()
    if not ns.db or not ns.db.profile or not ns.db.profile.unitframes then return nil end
    return ns.db.profile.unitframes
end

local function GetUnitDb(unit)
    local db = GetDb()
    return db and db.units and db.units[unit]
end

-- an element switch from Unit Frames > General > Elements; anything not switched off is on
local function ElementOn(key)
    local db = GetDb()
    local elements = db and db.elements
    return not (elements and elements[key] == false)
end

-- Percent curve (0..1 -> 0..100) so UnitHealthPercent's secret result can be shown directly
local percentCurve = CurveConstants.ScaleTo100

local function GetBarTexture(name)
    if name == "" then name = nil end
    return LSM:Fetch("statusbar", name or DEFAULT_TEXTURE) or "Interface\\TargetingFrame\\UI-StatusBar"
end

-- a name LibSharedMedia does not know (a removed media pack, an old save) falls back to the default
local function GetBorderFile(name)
    if not (name and name ~= "" and LSM:IsValid("border", name)) then name = DEFAULT_BORDER end
    return LSM:Fetch("border", name) or BORDER_FILE
end

local function GetColor(c, fallback)
    c = c or fallback or DEFAULT_BORDER_COLOR
    return c.r or 1, c.g or 1, c.b or 1, c.a or 1
end

-- Border colour: FlareUI's fixed bronze at rest, a status colour (threat) when there is one
local function ResetBorderTint(border)
    border:SetBackdropBorderColor(GetColor(nil))
end

local function SetBorderTint(border, r, g, b)
    border:SetBackdropBorderColor(r, g, b, 1)
end

local function ApplyBorderStyle(border, edgeFile)
    border:SetBackdrop({ edgeFile = edgeFile, edgeSize = BORDER_SIZE })
    ResetBorderTint(border)
end

local function CreateBar(parent, level)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetFrameLevel(level)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetVertexColor(0.15, 0.15, 0.15, 0.9)
    return bar
end

local function ApplyFont(fontString, fontDb)
    local path = ns.GetFontPath(fontDb and fontDb.face or "Friz Quadrata TT")
    local flags = fontDb and fontDb.flags or "OUTLINE"
    if flags == "NONE" then flags = "" end
    fontString:SetFont(path, fontDb and fontDb.size or 12, flags)
    ns.ApplyShadow(fontString, fontDb)
end

-- r, g, b for the health bar: class colour for players, reaction colour for NPCs. Class can be a
-- secret in restricted PvP; fall back to the reaction colour rather than inspect it.
local function GetHealthColor(unit)
    if not UnitIsConnected(unit) then return GREY[1], GREY[2], GREY[3] end
    if UnitIsPlayer(unit) then
        local _, classFile = UnitClass(unit)
        if canaccessvalue(classFile) and classFile then
            local color = C_ClassColor.GetClassColor(classFile)
            if color then return color:GetRGB() end
        end
    end
    if UnitIsTapDenied(unit) then return GREY[1], GREY[2], GREY[3] end
    local reaction = UnitReaction(unit, "player")
    local c = reaction and REACTION[reaction] or REACTION[5]
    return c[1], c[2], c[3]
end

local function GetPowerColor(unit)
    local powerType, powerToken = UnitPowerType(unit)
    local tbl = _G.PowerBarColor
    local c = tbl and (tbl[powerToken] or tbl[powerType])
    if c and c.r then return c.r, c.g, c.b end
    c = POWER_FALLBACK[powerToken] or POWER_FALLBACK.MANA
    return c[1], c[2], c[3]
end

local hiddenParent = CreateFrame("Frame", nil, UIParent)
hiddenParent:Hide()

-- Parks a Blizzard unit frame (an Edit Mode system) where it can never come back
local function HardHide(name)
    local frame = _G[name]
    if not frame or frame.FlareUI_Hidden then return end
    frame.FlareUI_Hidden = true
    pcall(frame.UnregisterAllEvents, frame)
    for _, key in ipairs({ "healthbar", "manabar", "spellbar", "castBar", "totFrame", "petFrame", "powerBarAlt" }) do
        local child = frame[key]
        if child and child.UnregisterAllEvents then pcall(child.UnregisterAllEvents, child) end
    end
    if not InCombatLockdown() then
        pcall(frame.Hide, frame)
        pcall(frame.SetParent, frame, hiddenParent)
    end
    hooksecurefunc(frame, "Show", function(f) if not InCombatLockdown() then f:Hide() end end)
end

--------------------------------------------------
-- 5. UPDATERS (all secret-safe: values go straight into widgets)
--------------------------------------------------
local function UpdateName(f)
    local unit = f.unit
    f.Name:SetText(UnitName(unit) or "")
end

local function UpdateLevel(f)
    local unit = f.unit
    local udb = GetUnitDb(unit)
    if not (udb and udb.showLevel) then f.Level:SetText("") return end
    local level = UnitLevel(unit)
    local classification = UnitClassification(unit)
    local suffix = ""
    if classification == "elite" or classification == "rareelite" then suffix = "+" end
    if classification == "rare" or classification == "rareelite" then suffix = "R" .. suffix end
    if canaccessvalue(level) and level then
        if level < 0 then
            f.Level:SetText("??")
            f.Level:SetTextColor(1, 0.1, 0.1)
        else
            f.Level:SetFormattedText("%d%s", level, suffix)
            local color = GetQuestDifficultyColor and GetQuestDifficultyColor(level)
            if color then f.Level:SetTextColor(color.r, color.g, color.b) else f.Level:SetTextColor(1, 1, 1) end
        end
    else
        f.Level:SetText(level)
        f.Level:SetTextColor(1, 1, 1)
    end
end

local function UpdateHealth(f)
    local unit = f.unit
    local udb = GetUnitDb(unit)
    local bar = f.Health

    bar:SetMinMaxValues(0, UnitHealthMax(unit))
    bar:SetValue(UnitHealth(unit))
    bar:SetStatusBarColor(GetHealthColor(unit))

    local mode = udb and udb.healthText or "percent"
    local text = f.HealthText
    if not UnitIsConnected(unit) then
        text:SetText(OFFLINE_TEXT)
    elseif UnitIsDeadOrGhost(unit) then
        text:SetText(UnitIsGhost(unit) and GHOST_TEXT or DEAD_TEXT)
    elseif mode == "percent" then
        text:SetFormattedText("%.0f%%", UnitHealthPercent(unit, true, percentCurve))
    elseif mode == "value" then
        text:SetText(AbbreviateNumbers(UnitHealth(unit)))
    elseif mode == "both" then
        text:SetFormattedText("%s  %.0f%%", AbbreviateNumbers(UnitHealth(unit)), UnitHealthPercent(unit, true, percentCurve))
    else
        text:SetText("")
    end
end

local function UpdatePower(f)
    local unit = f.unit
    local udb = GetUnitDb(unit)
    local bar = f.Power
    local powerType = UnitPowerType(unit)
    bar:SetMinMaxValues(0, UnitPowerMax(unit, powerType))
    bar:SetValue(UnitPower(unit, powerType))
    bar:SetStatusBarColor(GetPowerColor(unit))
    if udb and udb.powerText and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) then
        f.PowerText:SetText(AbbreviateNumbers(UnitPower(unit, powerType)))
    else
        f.PowerText:SetText("")
    end
end

-- GetRaidTargetIndex is SecretReturns: addon code usually gets a secret it may not read. A secret is
-- never nil, so it still means a marker is set, and SetRaidTargetIconTexture hands it straight to
-- SetSpriteSheetCell, which takes secrets - no Lua ever looks at the number.
local function UpdateRaidIcon(f)
    if UNITS[f.unit].noRaidIcon then
        f.RaidIcon:Hide()
        return
    end
    local index = GetRaidTargetIndex(f.unit)
    local show
    if not ElementOn("raidIcon") then
        show = false
    elseif not canaccessvalue(index) then
        show = true
    else
        show = index ~= nil and index > 0
    end
    if show then SetRaidTargetIconTexture(f.RaidIcon, index) end
    f.RaidIcon:SetShown(show)
end

--------------------------------------------------
-- 6. CAST BARS
-- One object serves the target / focus bars and the standalone player bar. The bar itself is
-- driven by the client through a duration object (SetTimerDuration) and the timer text through
-- a duration text binding, so both keep moving even when the cast data is secret.
--------------------------------------------------
local SAMPLE_CAST_SECONDS = 3
local SAMPLE_CAST_ICON = "Interface\\Icons\\Spell_Fire_FlameBolt"
local sampleCastTicker
local castBars = {}          -- every cast bar object, for previews

local timerFormatter
local function GetTimerFormatter()
    if timerFormatter ~= nil then return timerFormatter or nil end
    timerFormatter = false
    -- one decimal, the way a cast bar has always counted
    local ok, fmt = pcall(C_StringUtil.CreateNumericRuleFormatter)
    if ok and fmt and pcall(fmt.SetBreakpoints, fmt, { { threshold = 0, format = "%.1f" } }) then
        timerFormatter = fmt
    end
    -- "3s" rather than nothing at all, if the rule formatter will not build
    if not timerFormatter then
        ok, fmt = pcall(C_StringUtil.CreateSecondsFormatter)
        if ok and fmt then timerFormatter = fmt end
    end
    return timerFormatter or nil
end

-- style: { height, icon, timer, name, texture, border, borderTexture, width }
local function GetCastStyle(udb, standalone)
    if standalone then
        return {
            width = udb.width or 292, height = udb.height or 26,
            icon = udb.icon ~= false, timer = udb.timer ~= false, name = udb.name ~= false,
            texture = udb.texture, border = true,
            borderTexture = udb.borderTexture,
        }
    end
    local castTexture = udb.castTexture
    if castTexture == "" then castTexture = udb.texture end
    local castBorder = udb.castBorderTexture
    if castBorder == "" then castBorder = udb.border end
    return {
        height = udb.castHeight or CAST_HEIGHT,
        icon = udb.castIcon ~= false, timer = udb.castTimer ~= false, name = true,
        texture = castTexture, border = true,
        borderTexture = castBorder,
    }
end

local function CreateCastBar(parent, unit)
    local cast = CreateBar(parent, parent:GetFrameLevel() + 1)
    cast.unit = unit
    cast:SetMinMaxValues(0, 1)
    cast:Hide()

    cast.Backdrop = CreateFrame("Frame", nil, cast, "BackdropTemplate")
    cast.Backdrop:SetFrameLevel(cast:GetFrameLevel() - 1)
    cast.Border = CreateFrame("Frame", nil, cast, "BackdropTemplate")
    cast.Border:SetFrameLevel(cast:GetFrameLevel() + 2)

    cast.Icon = cast:CreateTexture(nil, "ARTWORK")
    cast.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local overlay = CreateFrame("Frame", nil, cast)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(cast:GetFrameLevel() + 3)
    cast.Text = overlay:CreateFontString(nil, "OVERLAY")
    cast.Text:SetJustifyH("LEFT")
    cast.Text:SetWordWrap(false)
    cast.Time = overlay:CreateFontString(nil, "OVERLAY")
    cast.Time:SetJustifyH("RIGHT")

    -- Remaining time, formatted client-side so it keeps counting even when the cast data is secret.
    -- SetFormatter is the whole configuration, and is what Blizzard's own aura buttons use
    -- (Blizzard_CustomAuraButton.lua:193). Not SetTextFormat: it takes "{}" placeholders, not "%s".
    local ok, binding = pcall(C_DurationUtil.CreateDurationTextBinding)
    if ok and binding then
        pcall(binding.SetFontString, binding, cast.Time)
        local fmt = GetTimerFormatter()
        if fmt then pcall(binding.SetFormatter, binding, fmt) end
        pcall(binding.SetZeroDurationText, binding, "")
        -- Without these the binding renders once when the duration is set and never again,
        -- which is why the timer showed a number but never counted. The interval is the
        -- MINIMUM gap between updates, so 0.05 is as smooth as a tenth-second display needs.
        pcall(binding.SetUpdateInterval, binding, 0.05)
        pcall(binding.Enable, binding)
        cast.TimerBinding = binding
    end

    castBars[#castBars + 1] = cast
    return cast
end

local function SetCastTimer(cast, duration)
    if cast.TimerBinding and duration then
        pcall(cast.TimerBinding.SetDuration, cast.TimerBinding, duration)
    end
end

-- Places the bar. mode "TOP" / "BOTTOM" hangs it off `anchor` (a unit frame); "FILL" fills `anchor`
-- (the standalone holder). The icon sits left of the bar, the backdrop / border wrap both.
local function LayoutCastBar(cast, style, anchor, mode)
    local db = GetDb()
    if not db then return end
    local PADDING = INSET
    local edgeFile = GetBorderFile(style.borderTexture)
    local texture = GetBarTexture(style.texture)
    local height = style.height
    local iconOffset = style.icon and (height + CAST_ICON_GAP) or 0

    cast.style = style
    cast:SetStatusBarTexture(texture)
    cast.bg:SetTexture(texture)
    cast:ClearAllPoints()
    if mode == "TOP" then
        cast:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", PADDING + iconOffset, CAST_GAP)
        cast:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", -PADDING, CAST_GAP)
        cast:SetHeight(height)
    elseif mode == "BOTTOM" then
        cast:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", PADDING + iconOffset, -CAST_GAP)
        cast:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", -PADDING, -CAST_GAP)
        cast:SetHeight(height)
    else
        cast:SetPoint("TOPLEFT", anchor, "TOPLEFT", PADDING + iconOffset, -PADDING)
        cast:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -PADDING, PADDING)
    end

    cast.Icon:ClearAllPoints()
    cast.Icon:SetSize(height, height)
    cast.Icon:SetPoint("RIGHT", cast, "LEFT", -CAST_ICON_GAP, 0)
    cast.Icon:SetShown(style.icon)

    cast.Backdrop:ClearAllPoints()
    cast.Backdrop:SetPoint("TOPLEFT", style.icon and cast.Icon or cast, "TOPLEFT", -PADDING, PADDING)
    cast.Backdrop:SetPoint("BOTTOMRIGHT", cast, "BOTTOMRIGHT", PADDING, -PADDING)
    cast.Backdrop:SetBackdrop({ bgFile = BACKDROP_FILE, insets = { left = PADDING, right = PADDING, top = PADDING, bottom = PADDING } })
    cast.Backdrop:SetBackdropColor(0, 0, 0, BG_OPACITY)
    cast.Border:ClearAllPoints()
    cast.Border:SetAllPoints(cast.Backdrop)
    if style.border then
        ApplyBorderStyle(cast.Border, edgeFile)
        cast.Border:Show()
    else
        cast.Border:Hide()
    end

    ApplyFont(cast.Text, db.fontCast or db.font)
    ApplyFont(cast.Time, db.fontCast or db.font)
    cast.Time:ClearAllPoints()
    cast.Time:SetPoint("RIGHT", cast, "RIGHT", -TEXT_INSET, 0)
    cast.Time:SetShown(style.timer)
    cast.Text:ClearAllPoints()
    cast.Text:SetPoint("LEFT", cast, "LEFT", TEXT_INSET, 0)
    if style.timer then
        cast.Text:SetPoint("RIGHT", cast.Time, "LEFT", -4, 0)
    else
        cast.Text:SetPoint("RIGHT", cast, "RIGHT", -TEXT_INSET, 0)
    end
    cast.Text:SetShown(style.name)
end

-- Edit Mode: a looping 3 s sample cast so the bar can be placed without a casting unit
local function ShowSampleCast(cast)
    local duration = C_DurationUtil.CreateDuration()
    duration:SetTimeFromStart(GetTime(), SAMPLE_CAST_SECONDS)
    cast:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, Enum.StatusBarTimerDirection.ElapsedTime)
    SetCastTimer(cast, duration)
    cast.Text:SetText("Sample Cast")
    cast.Icon:SetTexture(SAMPLE_CAST_ICON)
    local color = cast.standalone and PLAYER_CAST_COLOR or CAST_COLOR
    cast:SetStatusBarColor(color[1], color[2], color[3])
    cast:Show()
end

local function UpdateCastBar(cast, enabled)
    if not enabled then cast:Hide() return end
    if LEM:IsInEditMode() then ShowSampleCast(cast) return end
    local unit = cast.unit

    local channeling = false
    local n = select("#", UnitCastingInfo(unit))
    local name, text, texture, _, _, _, _, notInterruptible
    if n > 0 then
        name, text, texture, _, _, _, _, notInterruptible = UnitCastingInfo(unit)
    else
        n = select("#", UnitChannelInfo(unit))
        if n > 0 then
            name, text, texture, _, _, _, notInterruptible = UnitChannelInfo(unit)
            channeling = true
        end
    end
    if n == 0 then
        cast:Hide()
        return
    end

    local duration = channeling and UnitChannelDuration(unit) or UnitCastingDuration(unit)
    if not duration then cast:Hide() return end
    local direction = channeling and Enum.StatusBarTimerDirection.RemainingTime or Enum.StatusBarTimerDirection.ElapsedTime
    cast:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, direction)
    SetCastTimer(cast, duration)

    -- `text or name` would boolean-test a secret; only pick when the value is readable
    local label = text
    if canaccessvalue(text) then label = text or name or "" end
    cast.Text:SetText(label)
    if canaccessvalue(texture) and texture then
        cast.Icon:SetTexture(texture)
    else
        cast.Icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end

    local color
    if cast.standalone then
        color = channeling and PLAYER_CAST_CHANNEL or PLAYER_CAST_COLOR
    else
        color = channeling and CAST_CHANNEL or CAST_COLOR
    end
    if canaccessvalue(notInterruptible) and notInterruptible then
        color = CAST_NOINTERRUPT
    end
    cast:SetStatusBarColor(color[1], color[2], color[3])
    cast:Show()
end

local function IsCastEnabled(cast)
    if cast.standalone then
        local db = GetDb()
        return db and db.playerCastbar and db.playerCastbar.enabled
    end
    return true
end

local function UpdateCast(f)
    if f.Cast then UpdateCastBar(f.Cast, IsCastEnabled(f.Cast)) end
end

local function SetCastPreview(enabled)
    if sampleCastTicker then sampleCastTicker:Cancel() sampleCastTicker = nil end
    if enabled then
        local function tick()
            for _, cast in ipairs(castBars) do
                if IsCastEnabled(cast) then ShowSampleCast(cast) end
            end
        end
        tick()
        sampleCastTicker = C_Timer.NewTicker(SAMPLE_CAST_SECONDS, tick)
    else
        for _, cast in ipairs(castBars) do UpdateCastBar(cast, IsCastEnabled(cast)) end
    end
end

local UpdateComboPoints   -- defined in 5c (needs the layout helpers below)
local UpdateHappiness     -- defined in 8c
local UpdateIndicators, UpdateHealPrediction   -- defined in 5d

local function UpdateAll(f)
    UpdateName(f)
    UpdateLevel(f)
    UpdateHealth(f)
    UpdatePower(f)
    UpdateRaidIcon(f)
    UpdateCast(f)
    if f.Combo then UpdateComboPoints(f) end
    UpdateIndicators(f)
    UpdateHappiness(f)
end

local function OnUnitEvent(f, event, arg1)
    if arg1 == "player" and f.unit ~= "player" and COMBO_EVENTS[event] then
        if f.Combo then UpdateComboPoints(f) end
        return
    end
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        UpdateHealth(f)
    elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_POWER_FREQUENT"
        or event == "UNIT_DISPLAYPOWER" then
        UpdatePower(f)
    elseif event == "UNIT_HEAL_PREDICTION" or event == "UNIT_ABSORB_AMOUNT_CHANGED" then
        UpdateHealPrediction(f)
    elseif event == "UNIT_THREAT_SITUATION_UPDATE" or event == "UNIT_THREAT_LIST_UPDATE"
        or event == "PLAYER_UPDATE_RESTING" or event == "GROUP_ROSTER_UPDATE" or event == "PARTY_LEADER_CHANGED" or event == "PLAYER_FLAGS_CHANGED" then
        UpdateIndicators(f)
    elseif event == "UNIT_NAME_UPDATE" then
        UpdateName(f)
    elseif event == "UNIT_LEVEL" or event == "UNIT_CLASSIFICATION_CHANGED" then
        UpdateLevel(f)
    elseif event == "UNIT_FACTION" or event == "UNIT_CONNECTION" or event == "UNIT_FLAGS" then
        UpdateHealth(f)
        UpdatePower(f)
        if f.Combo then UpdateComboPoints(f) end   -- a target can turn hostile (duels, mind control)
    elseif event == "RAID_TARGET_UPDATE" then
        UpdateRaidIcon(f)
    elseif event:find("^UNIT_SPELLCAST") then
        UpdateCast(f)
    elseif event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
        UpdateAll(f)
    else
        UpdateAll(f)
    end
end

--------------------------------------------------
-- 7. AURAS (Blizzard's native aura containers)
-- Aura data is secret in restricted content, so the icons are rendered by Blizzard's
-- CustomAuraContainer: we only hand it our textures / font strings and describe the layout.
-- One container per corner of the frame; buffs and debuffs each pick a corner. Containers are
-- created with the frame (at login) - ones created later get access-restricted and never show.
--------------------------------------------------
local AURA_CONTAINER_TEMPLATE = "CustomAuraContainerTemplate"
local AURA_CORNERS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
local AURA_SPACING = 2
local auraSupport   -- nil = unknown, true / false after the first probe

local function HasAuraSupport()
    if auraSupport ~= nil then return auraSupport end
    auraSupport = false
    if C_AddOns.DoesAddOnExist("Blizzard_AuraContainer") and not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
    end
    local ok, probe = pcall(CreateFrame, "AuraContainer", nil, hiddenParent, AURA_CONTAINER_TEMPLATE)
    if ok and probe and type(probe.AddAuraGroup) == "function" and type(probe.SetFlowLayoutAxis) == "function" then
        auraSupport = true
    end
    return auraSupport
end

-- initializeFrame: Blizzard calls this for every pooled aura button; we build the visuals once
-- and register them so the (secure) button drives icon, cooldown, stacks, duration, dispel colour
local function InitAuraButton(button, size, isDebuff, unit, font)
    button:SetSize(size, size)
    if not button.FlareUI_Icon then
        local bg = button:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 1)

        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", -1, 1)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.FlareUI_Icon = icon

        local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        cd:SetAllPoints(icon)
        cd:SetReverse(true)
        cd:SetDrawEdge(false)
        cd:SetDrawBling(false)
        cd:SetHideCountdownNumbers(true)
        button.FlareUI_Cooldown = cd

        local overlay = CreateFrame("Frame", nil, button)
        overlay:SetAllPoints()
        overlay:SetFrameLevel(cd:GetFrameLevel() + 5)
        button.FlareUI_Overlay = overlay

        local dispel = overlay:CreateTexture(nil, "OVERLAY", nil, 1)
        dispel:SetPoint("TOPLEFT", -1, 1)
        dispel:SetPoint("BOTTOMRIGHT", 1, -1)
        button.FlareUI_Dispel = dispel

        local count = overlay:CreateFontString(nil, "OVERLAY", nil, 3)
        count:SetPoint("BOTTOMRIGHT", -1, 1)
        count:SetJustifyH("RIGHT")
        button.FlareUI_Count = count

        local duration = overlay:CreateFontString(nil, "OVERLAY", nil, 3)
        duration:SetPoint("CENTER", 0, 0)
        duration:SetJustifyH("CENTER")
        button.FlareUI_Duration = duration
    end

    local fontPath = ns.GetFontPath(font and font.face or "Friz Quadrata TT")
    local textSize = math.max(8, math_floor(size * 0.45))
    button.FlareUI_Count:SetFont(fontPath, textSize, "OUTLINE")
    button.FlareUI_Duration:SetFont(fontPath, math.max(8, textSize - 1), "OUTLINE")
    ns.ApplyShadow(button.FlareUI_Count, font)
    ns.ApplyShadow(button.FlareUI_Duration, font)

    pcall(button.SetIcon, button, button.FlareUI_Icon)
    pcall(button.SetDurationCooldown, button, button.FlareUI_Cooldown)
    pcall(button.SetApplicationCount, button, button.FlareUI_Count, {})
    pcall(button.SetDurationText, button, button.FlareUI_Duration, {})
    pcall(button.ClearDispelTypeTextures, button)
    if isDebuff and Enum.CustomAuraButtonDispelTypeTextureStyle then
        button.FlareUI_Dispel:Show()
        pcall(button.AddDispelTypeTexture, button, button.FlareUI_Dispel, {
            style = Enum.CustomAuraButtonDispelTypeTextureStyle.Border,
            showWhenHarmful = true,
            showWhenHelpful = false,
        })
    else
        button.FlareUI_Dispel:Hide()
    end
    if unit == "player" and not isDebuff and button.SetCancelAuraButtons then
        pcall(button.SetCancelAuraButtons, button, "RightButtonUp")
    end
end

-- Called from CreateUnitFrame: one container per corner, all at login
local function PrecreateAuraContainers(f)
    if not UNITS[f.unit].auras or not HasAuraSupport() then return end
    f.Auras = {}
    for _, corner in ipairs(AURA_CORNERS) do
        local ok, container = pcall(CreateFrame, "AuraContainer", nil, f, AURA_CONTAINER_TEMPLATE)
        if ok and container then
            pcall(container.SetUnit, container, f.unit)
            container:SetFrameLevel(f:GetFrameLevel() + 4)
            container:Hide()
            f.Auras[corner] = { container = container, groups = {}, generation = 0 }
        end
    end
end

-- corner: TOPLEFT | TOPRIGHT | BOTTOMLEFT | BOTTOMRIGHT; lanes: { {key, filter, isDebuff, candidates}, ... }
local function ConfigureAuraCorner(f, corner, lanes)
    local entry = f.Auras and f.Auras[corner]
    if not entry then return end
    local container = entry.container
    local db, udb = GetDb(), GetUnitDb(f.unit)

    -- retire the previous generation of groups (keys must be unique per container)
    for _, key in ipairs(entry.groups) do
        pcall(container.SetAuraGroupEnabled, container, key, false)
        pcall(container.SetAuraGroupMaxFrameCount, container, key, 0)
    end
    entry.groups = {}

    if #lanes == 0 then
        pcall(container.SetEnabled, container, false)
        container:Hide()
        return
    end

    local size = udb.auraSize or 22
    local max = udb.auraMax or 16
    entry.generation = entry.generation + 1
    local gen = entry.generation
    for index, lane in ipairs(lanes) do
        local key = lane.key .. gen
        local isDebuff, unit, font = lane.isDebuff, f.unit, db and db.font
        local ok, err = pcall(container.AddAuraGroup, container, key, lane.filter, {
            maxFrameCount = max,
            candidateFilters = lane.candidates,
            initializeFrame = function(button) InitAuraButton(button, size, isDebuff, unit, font) end,
            layout = {
                elementWidth = size, elementHeight = size,
                elementSpacing = AURA_SPACING, lineSpacing = AURA_SPACING,
                groupSpacing = AURA_SPACING, groupLineSpacing = AURA_SPACING,
                layoutIndex = index,
                forceNewLine = index > 1,
            },
        })
        if ok then
            entry.groups[#entry.groups + 1] = key
        else
            print("|cffff0000FlareUI:|r aura group failed: " .. tostring(err))
        end
    end

    -- grow away from the corner: right/left along the edge, up from the top, down from the bottom;
    -- wrap a little before the middle of the frame so two corners on one edge never meet
    local isTop, isLeft = corner:find("^TOP") ~= nil, corner:find("LEFT$") ~= nil
    local inset = INSET
    local lineSize = math.max(size, math_floor(f:GetWidth() / 2) - inset - 4)
    pcall(container.SetFlowLayoutAxis, container, AnchorUtil.FlowLayoutAxis.Horizontal)
    pcall(container.SetFlowLayoutAnchorPoint, container, (isTop and "BOTTOM" or "TOP") .. (isLeft and "LEFT" or "RIGHT"))
    pcall(container.SetFlowLayoutGrowthDirection, container,
        isLeft and AnchorUtil.FlowDirection.Right or AnchorUtil.FlowDirection.Left,
        isTop and AnchorUtil.FlowDirection.Up or AnchorUtil.FlowDirection.Down)
    pcall(container.SetFlowLayoutMaximumLineSize, container, lineSize)
    pcall(container.SetFlowLayoutPadding, container, 0, 0, 0, 0)
    pcall(container.SetEnabled, container, true)
    pcall(container.SetEditModePreviewEnabled, container, LEM:IsInEditMode())
    container:Show()
    pcall(container.UpdateAllAuras, container)
end

local function PositionAuraContainers(f)
    if not f.Auras then return end
    local inset = INSET
    for corner, entry in pairs(f.Auras) do
        local c = entry.container
        local isTop, isLeft = corner:find("^TOP") ~= nil, corner:find("LEFT$") ~= nil
        local x = isLeft and inset or -inset
        local y = isTop and AURA_GAP or -AURA_GAP
        c:ClearAllPoints()
        -- container's own corner nearest the frame sits on the frame's corner, a few px out
        c:SetPoint((isTop and "BOTTOM" or "TOP") .. (isLeft and "LEFT" or "RIGHT"), f, corner, x, y)
        c:SetFrameLevel(f:GetFrameLevel() + 4)
    end
end

LayoutAuras = function(f)
    local udb = GetUnitDb(f.unit)
    if not udb or not f.Auras then return end
    if InCombatLockdown() then pendingLayout = true return end
    local perCorner = {}
    for _, corner in ipairs(AURA_CORNERS) do perCorner[corner] = {} end
    local function AddLane(corner, key, filter, isDebuff, candidates)
        local list = corner and perCorner[corner]
        if list then list[#list + 1] = { key = key, filter = filter, isDebuff = isDebuff, candidates = candidates } end
    end
    local buffCandidates
    if udb.hidePermanentBuffs then buffCandidates = { maxDuration = 999999 } end
    local debuffCandidates
    if udb.onlyMyDebuffs then debuffCandidates = { isFromPlayerOrPlayerPet = true } end
    -- debuffs first: closest to the frame when both share a corner
    AddLane(udb.debuffs, "debuffs", "HARMFUL", true, debuffCandidates)
    AddLane(udb.buffs, "buffs", "HELPFUL", false, buffCandidates)
    for _, corner in ipairs(AURA_CORNERS) do
        ConfigureAuraCorner(f, corner, perCorner[corner])
    end
    PositionAuraContainers(f)
end

-- Edit Mode: Blizzard switches every container to a sample data source; enabling the preview
-- makes ours render it, so placement and size can be judged without a target
local function SetAuraPreview(enabled)
    for _, f in pairs(frames) do
        if f.Auras then
            for _, entry in pairs(f.Auras) do
                pcall(entry.container.SetEditModePreviewEnabled, entry.container, enabled)
            end
        end
    end
end

--------------------------------------------------
-- 8. COMBO POINTS (target frame)
-- On Forever combo points belong to the target, as in Classic: each enemy keeps the points built on
-- it, so a rogue can swap targets for a kick and come back to a full set. Forever's own UI shows them
-- on the target frame (Camelot ComboFrameOverrides.lua) and drops the player-side combo bars, so the
-- strip lives on the target frame too, for rogues and cat-form druids alike.
-- It is a thin segmented strip drawn ON TOP of the health bar, along its upper edge, so the unspent
-- slots do not read as a black band across the frame. Combo point counts can be secret in combat,
-- so each segment is a StatusBar with range [i-1, i] fed the raw value: full when points >= i, empty
-- otherwise. No Lua compares the number. Replaces Blizzard's ComboFrame, which is hidden.
--------------------------------------------------
local COMBO_HEIGHT = 5
local COMBO_SEGMENT_GAP = 1
local COMBO_MAX_SEGMENTS = 10
local COMBO_FALLBACK_MAX = 5
local COMBO_PREVIEW_POINTS = 3
-- cool teal -> cyan: the one hue no Forever class or power colour uses, so it reads against the
-- warm bronze / olive / orange around it
local COMBO_COLOR_FIRST = { 0.10, 0.52, 0.58 }   -- teal on the left...
local COMBO_COLOR_LAST  = { 0.40, 0.88, 0.95 }   -- ...to cyan on the right

local function PlayerClass()
    local _, class = UnitClass("player")
    if canaccessvalue(class) then return class end
    return nil
end

-- Rogues always; druids only in a form that runs on energy (cat). Only on a target that can take
-- combo points - a friendly one never will. Edit Mode previews for both classes.
local function ShouldShowComboPoints()
    local class = PlayerClass()
    if class ~= "ROGUE" and class ~= "DRUID" then return false end
    if LEM:IsInEditMode() then return true end
    if class == "DRUID" then
        local powerType = UnitPowerType("player")
        if not (canaccessvalue(powerType) and powerType == Enum.PowerType.Energy) then return false end
    end
    local hostile = UnitCanAttack("player", "target")
    return canaccessvalue(hostile) and hostile or false
end

local function CreateComboPoints(f)
    local combo = CreateFrame("Frame", nil, f)
    -- above the health bar and the heal overlay it covers, still below the frame border
    combo:SetFrameLevel(f.Health:GetFrameLevel() + 2)
    combo.segments = {}
    combo.count = 0
    combo:Hide()
    f.Combo = combo
end

local function GetComboSegment(f, i)
    local seg = f.Combo.segments[i]
    if not seg then
        seg = CreateBar(f.Combo, f.Combo:GetFrameLevel())
        seg:SetMinMaxValues(i - 1, i)
        f.Combo.segments[i] = seg
    end
    return seg
end

-- distributes the segments across the strip; colours run from COMBO_COLOR_FIRST to COMBO_COLOR_LAST
local function LayoutComboSegments(f)
    local combo, udb = f.Combo, GetUnitDb(f.unit)
    if not combo or combo.count == 0 then return end
    local n = combo.count
    local width = (udb and udb.width or 220) - 2 * INSET
    local segWidth = (width - (n - 1) * COMBO_SEGMENT_GAP) / n
    local texture = GetBarTexture(udb and udb.texture)
    for i = 1, n do
        local seg = GetComboSegment(f, i)
        local t = n > 1 and (i - 1) / (n - 1) or 0
        seg:SetStatusBarTexture(texture)
        seg.bg:SetTexture(texture)
        -- dark enough to show where the unspent points are, sheer enough that the health bar's own
        -- colour still reads through the strip
        seg.bg:SetVertexColor(0, 0, 0, 0.45)
        seg:SetStatusBarColor(
            COMBO_COLOR_FIRST[1] + (COMBO_COLOR_LAST[1] - COMBO_COLOR_FIRST[1]) * t,
            COMBO_COLOR_FIRST[2] + (COMBO_COLOR_LAST[2] - COMBO_COLOR_FIRST[2]) * t,
            COMBO_COLOR_FIRST[3] + (COMBO_COLOR_LAST[3] - COMBO_COLOR_FIRST[3]) * t)
        seg:ClearAllPoints()
        -- left to right even on a mirrored frame: the points are the player's, not the target's
        seg:SetPoint("TOPLEFT", combo, "TOPLEFT", (i - 1) * (segWidth + COMBO_SEGMENT_GAP), 0)
        seg:SetSize(segWidth, COMBO_HEIGHT)
        seg:Show()
    end
    for i = n + 1, #combo.segments do combo.segments[i]:Hide() end
end

-- true when the strip is currently part of the frame (drives the bar layout)
local function IsComboShown(f)
    return f.Combo ~= nil and f.Combo.count > 0
end

-- Classic Combo Points (target frame option, off by default): Blizzard's own ComboFrame in place of
-- the strip, its points laid out in a row inside the top-left corner of the health bar, clear of the
-- auras and the cast bar around the frame. Blizzard's code keeps driving it either way; with the
-- option off it is parked on a hidden parent, where it still runs but never shows.
local CLASSIC_COMBO_X       = 3    -- from the health bar's left edge
local CLASSIC_COMBO_Y       = -3   -- from the health bar's top edge (negative = down)
local CLASSIC_COMBO_SPACING = 13   -- the points are 12 px wide
local classicComboHooked = false

-- ComboFrame_Update ends in ComboFrame_ApplyOverrides, which on Forever pins the frame back onto
-- TargetFrame (Camelot ComboFrameOverrides.lua), so the placement is re-applied after it. Only
-- anchors are touched: the point count can be secret and is left to Blizzard's own code.
local function PlaceClassicCombo(combo, f)
    combo:ClearAllPoints()
    combo:SetPoint("TOPLEFT", f.Health, "TOPLEFT", CLASSIC_COMBO_X, CLASSIC_COMBO_Y)
    -- the XML arcs the points around the old portrait; the first one used depends on the max
    local first = combo.startComboPointIndex or 2
    for i, point in ipairs(combo.ComboPoints) do
        point:ClearAllPoints()
        point:SetPoint("TOPLEFT", combo, "TOPLEFT", (i - first) * CLASSIC_COMBO_SPACING, 0)
    end
end

-- nil when the client has Blizzard's combo display switched off (comboPointLocation): its OnLoad
-- then never registers the events, and the option falls back to the strip
local function GetClassicCombo()
    local combo = _G.ComboFrame
    if combo and combo:IsEventRegistered("PLAYER_TARGET_CHANGED") then return combo end
end

local function UsesClassicCombo(f)
    local udb = GetUnitDb(f.unit)
    return (udb and udb.classicCombo and GetClassicCombo()) and true or false
end

-- puts Blizzard's ComboFrame on our frame, or parks it, to match the option
local function ApplyComboMode(f)
    local combo = GetClassicCombo()
    if not combo then return end
    if not UsesClassicCombo(f) then
        combo:SetParent(hiddenParent)
        return
    end
    combo:SetParent(f)
    combo:SetFrameStrata(f:GetFrameStrata())
    combo:SetFrameLevel(f.Border:GetFrameLevel() + 2)
    PlaceClassicCombo(combo, f)
    if not classicComboHooked then
        classicComboHooked = true
        hooksecurefunc("ComboFrame_ApplyOverrides", function(self) PlaceClassicCombo(self, f) end)
    end
end

--------------------------------------------------
-- 8b. FIVE-SECOND RULE
-- Forever keeps classic's rule: spirit regen stops when a spell that costs mana is cast and comes
-- back five seconds later. A spark crosses the player's mana bar over those five seconds; another
-- such cast starts it again. Mana itself is secret, so nothing here reads it: the cast event and
-- the spell's cost type are the whole signal. A free cast (a zero cost, Clearcasting) does not
-- count; a secret amount does. Hidden while the bar shows another power (a druid in a form) and
-- picked up again, where the window has got to, on the way back to mana.
--------------------------------------------------
local FSR_SECONDS = 5
local FSR_SPARK   = "Interface\\CastingBar\\UI-CastingBar-Spark"
local fsrStart            -- GetTime() of the last mana cast while a window runs

local function CostsMana(spellID)
    if not (spellID and canaccessvalue(spellID)) then return false end
    local costs = C_Spell.GetSpellPowerCost(spellID)
    if not costs then return false end
    for _, cost in ipairs(costs) do
        if canaccessvalue(cost.type) and cost.type == Enum.PowerType.Mana then
            local amount = cost.cost
            return not canaccessvalue(amount) or (type(amount) == "number" and amount > 0)
        end
    end
    return false
end

local function BarShowsMana()
    local powerType = UnitPowerType("player")
    return canaccessvalue(powerType) and powerType == Enum.PowerType.Mana
end

local function MoveFsrSpark(holder)
    local elapsed = fsrStart and (GetTime() - fsrStart)
    if not elapsed or elapsed >= FSR_SECONDS then
        fsrStart = nil
        holder:Hide()
        return
    end
    local bar = holder:GetParent()
    local width = bar:GetWidth()
    local x = width * elapsed / FSR_SECONDS
    if bar:GetReverseFill() then x = width - x end
    holder.Spark:SetPoint("CENTER", bar, "LEFT", x, 0)
end

local function CreateFsrSpark(f)
    local bar = f.Power
    local holder = CreateFrame("Frame", nil, bar)
    holder:SetAllPoints(bar)
    holder:SetFrameLevel(bar:GetFrameLevel() + 1)
    holder:Hide()
    local spark = holder:CreateTexture(nil, "OVERLAY")
    spark:SetTexture(FSR_SPARK)
    spark:SetBlendMode("ADD")
    holder.Spark = spark
    -- the spark art is mostly glow, so it is drawn taller than the bar it crosses
    holder:SetScript("OnShow", function(self)
        local height = bar:GetHeight()
        self.Spark:SetSize(math.max(height, 8), math.max(height * 2.2, 18))
    end)
    holder:SetScript("OnUpdate", MoveFsrSpark)
    f.FsrSpark = holder
end

local function UpdateFsrSpark()
    local f = frames.player
    local holder = f and f.FsrSpark
    if not holder then return end
    if fsrStart and GetTime() - fsrStart >= FSR_SECONDS then fsrStart = nil end
    holder:SetShown(fsrStart ~= nil and f.Power:IsShown() and BarShowsMana())
end

local function InitFsrSpark()
    local events = CreateFrame("Frame")
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    events:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
    events:SetScript("OnEvent", function(_, event, _, _, spellID)
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            if not CostsMana(spellID) then return end
            fsrStart = GetTime()
        end
        UpdateFsrSpark()
    end)
end

--------------------------------------------------
-- 8c. PET HAPPINESS
-- Blizzard's own indicator (PetFrameHappinessTemplate, PetHappiness.lua): the happy / content /
-- unhappy face, its tooltip (damage, loyalty, diet), its events, and showing only for a hunter's
-- pet. It sits in the middle of the pet frame's health bar, at HAPPINESS_SHARE of its height.
-- Clicks pass through to the frame underneath, so the face does not get in the way of targeting
-- the pet or opening its menu; only the hover stays with it, for the tooltip. In Edit Mode it shows
-- the happy face whatever the pet, so it can be seen while the frame is placed.
--------------------------------------------------
local HAPPINESS_PREVIEW = "UI-PetHappiness"

local function CreateHappiness(f)
    local face = CreateFrame("Frame", nil, f.Overlay, "PetFrameHappinessTemplate")
    face:Hide()
    pcall(face.SetPropagateMouseClicks, face, true)
    f.Happiness = face
end

function UpdateHappiness(f)
    local face = f.Happiness
    if not face then return end
    local udb = GetUnitDb(f.unit)
    if udb and udb.happiness ~= false then
        face:RegisterEvent("UNIT_HAPPINESS")
        face:RegisterEvent("UNIT_PET")
        face:UpdateHappiness()
        if LEM:IsInEditMode() and not face:IsShown() then
            face.Texture:SetAtlas(HAPPINESS_PREVIEW)
            face:Show()
        end
    else
        face:UnregisterAllEvents()
        face:Hide()
    end
end

--------------------------------------------------
-- 9. INDICATORS
-- Fixed-position icons (rested, leader, PvP, classification, quest boss), the threat outline and
-- the incoming-heal / absorb overlays. The icons can be switched off in Unit Frames > General >
-- Elements (ElementOn). Art: Blizzard atlases with the classic textures as fallback.
--------------------------------------------------
local REST_SIZE       = 28
local LEADER_SIZE     = 20
local PVP_SIZE        = 24
local CLASS_ICON_SIZE = 18
local QUEST_SIZE      = 24
-- Blizzard's own CUF_MY_HEAL_PREDICTION_COLOR (CompactUnitFrame.lua:7), opaque as it is there:
-- both overlays are clipped to the EMPTY part of the health bar, so nothing needs to show through
-- them, and any transparency only muddies the colour against the dark track.
local HEAL_COLOR      = { 11/255, 136/255, 105/255, 1 }   -- #0B8869, incoming heals
-- Blizzard draws absorbs as the tiled raidframe-shield-fill atlas rather than a flat colour; this is
-- our striped texture tinted to that art's pale steel blue.
local ABSORB_COLOR    = { 0.67, 0.78, 0.92, 1 }           -- damage absorbs
local HEAL_TEXTURE    = "Armory"
local ABSORB_TEXTURE  = "Striped"

local function HasAtlas(name)
    return name ~= nil and C_Texture.GetAtlasInfo(name) ~= nil
end

-- atlas when the client has it, otherwise the classic texture (with optional tex coords)
local function SetIconArt(tex, atlas, file, coords)
    if HasAtlas(atlas) then
        tex:SetAtlas(atlas, false)
    else
        tex:SetTexture(file)
        if coords then tex:SetTexCoord(unpack(coords)) else tex:SetTexCoord(0, 1, 0, 1) end
    end
end

local function CreateIndicators(f)
    local info = UNITS[f.unit]
    local ind = info.indicators
    if not ind then return end
    local overlay = f.Overlay

    if ind.rest then
        local rest = CreateFrame("Frame", nil, overlay)
        rest:SetSize(REST_SIZE, REST_SIZE)
        local tex = rest:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints()
        if HasAtlas("UI-HUD-UnitFrame-Player-Rest-Flipbook") then
            tex:SetAtlas("UI-HUD-UnitFrame-Player-Rest-Flipbook", false)
            local anim = rest:CreateAnimationGroup()
            anim:SetLooping("REPEAT")
            local ok, flip = pcall(anim.CreateAnimation, anim, "FlipBook")
            if ok and flip then
                flip:SetTarget(tex)
                flip:SetDuration(1.5)
                pcall(flip.SetFlipBookRows, flip, 7)
                pcall(flip.SetFlipBookColumns, flip, 6)
                pcall(flip.SetFlipBookFrames, flip, 42)
                rest.anim = anim
            end
        else
            tex:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
            tex:SetTexCoord(0, 0.5, 0, 0.421875)
        end
        rest.tex = tex
        rest:Hide()
        f.RestIcon = rest
    end
    if ind.leader then
        f.LeaderIcon = overlay:CreateTexture(nil, "OVERLAY")
        f.LeaderIcon:Hide()
    end
    if ind.pvp then
        f.PvPIcon = overlay:CreateTexture(nil, "OVERLAY")
        f.PvPIcon:Hide()
    end
    if ind.classification then
        f.ClassIcon = overlay:CreateTexture(nil, "OVERLAY")
        f.ClassIcon:Hide()
    end
    if ind.quest then
        f.QuestIcon = overlay:CreateTexture(nil, "OVERLAY")
        f.QuestIcon:Hide()
    end
    -- threat: the frame border itself is tinted (see UpdateIndicators); nothing to create
    f.threatTint = ind.threat and true or false
    if ind.heals then
        -- the overlays live in a clipping frame covering the empty part of the health bar, so
        -- they can never draw past the bar; both are anchored to fill textures, never to numbers
        local clip = CreateFrame("Frame", nil, f.Health)
        clip:SetFrameLevel(f.Health:GetFrameLevel() + 1)
        clip:SetClipsChildren(true)
        local heal = CreateFrame("StatusBar", nil, clip)
        heal:SetStatusBarTexture(GetBarTexture(HEAL_TEXTURE))
        heal:SetStatusBarColor(unpack(HEAL_COLOR))
        heal:SetMinMaxValues(0, 1)
        heal:SetValue(0)
        local absorb = CreateFrame("StatusBar", nil, clip)
        absorb:SetStatusBarTexture(GetBarTexture(ABSORB_TEXTURE))
        absorb:SetStatusBarColor(unpack(ABSORB_COLOR))
        absorb:SetMinMaxValues(0, 1)
        absorb:SetValue(0)
        f.HealClip, f.HealBar, f.AbsorbBar = clip, heal, absorb
        if CreateUnitHealPredictionCalculator then
            local ok, calc = pcall(CreateUnitHealPredictionCalculator)
            if ok and calc then f.HealCalc = calc end
        end
    end
end

local function LayoutIndicators(f)
    local udb = GetUnitDb(f.unit)
    local mirror = udb and udb.mirror and true or false
    if f.RestIcon then
        f.RestIcon:ClearAllPoints()
        f.RestIcon:SetPoint("CENTER", f, "TOPRIGHT", -2, 0)
    end
    if f.LeaderIcon then
        f.LeaderIcon:ClearAllPoints()
        f.LeaderIcon:SetSize(LEADER_SIZE, LEADER_SIZE)
        f.LeaderIcon:SetPoint("CENTER", f, "TOPLEFT", 16, -2)
    end
    if f.PvPIcon then
        -- bottom-left on the player, bottom-right on a mirrored frame: symmetrical across the screen
        f.PvPIcon:ClearAllPoints()
        f.PvPIcon:SetSize(PVP_SIZE, PVP_SIZE)
        if mirror then
            f.PvPIcon:SetPoint("CENTER", f, "BOTTOMRIGHT", -4, 2)
        else
            f.PvPIcon:SetPoint("CENTER", f, "BOTTOMLEFT", 4, 2)
        end
    end
    if f.ClassIcon then
        f.ClassIcon:ClearAllPoints()
        f.ClassIcon:SetSize(CLASS_ICON_SIZE, CLASS_ICON_SIZE)
        f.ClassIcon:SetPoint("CENTER", f, "TOPRIGHT", -10, -4)
    end
    if f.QuestIcon then
        f.QuestIcon:ClearAllPoints()
        f.QuestIcon:SetSize(QUEST_SIZE, QUEST_SIZE)
        f.QuestIcon:SetPoint("CENTER", f, "TOP", 0, 0)   -- half above the frame's top edge
    end
    if f.HealClip then
        local health, clip, heal, absorb = f.Health, f.HealClip, f.HealBar, f.AbsorbBar
        local fill = health:GetStatusBarTexture()
        local width = (udb and udb.width or 220) - 2 * INSET
        local reverse = (udb and udb.absorbReverseFill) and true or false

        clip:ClearAllPoints()
        heal:ClearAllPoints()
        absorb:ClearAllPoints()
        heal:SetWidth(width)
        absorb:SetWidth(width)
        heal:SetReverseFill(mirror)
        -- A reversed absorb grows against the health bar, so its fill flag is the mirror flag
        -- inverted; left alone it runs with the bar, continuing on from the incoming heals.
        absorb:SetReverseFill(reverse ~= mirror)

        -- The clip covers the EMPTY part of the bar. It is what stops either overlay drawing past
        -- the health bar, and it does so geometrically - no Lua ever compares the (possibly secret)
        -- absorb against the missing health, which it could not do anyway.
        if mirror then
            -- bar fills from the right; the empty part is on the left
            clip:SetPoint("TOPLEFT", health, "TOPLEFT", 0, 0)
            clip:SetPoint("BOTTOMRIGHT", fill, "BOTTOMLEFT", 0, 0)
            heal:SetPoint("TOPRIGHT", clip, "TOPRIGHT", 0, 0)
            heal:SetPoint("BOTTOMRIGHT", clip, "BOTTOMRIGHT", 0, 0)
        else
            clip:SetPoint("TOPLEFT", fill, "TOPRIGHT", 0, 0)
            clip:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", 0, 0)
            heal:SetPoint("TOPLEFT", clip, "TOPLEFT", 0, 0)
            heal:SetPoint("BOTTOMLEFT", clip, "BOTTOMLEFT", 0, 0)
        end

        -- Where the absorb starts. Normally where the incoming heals leave off; reversed, from the
        -- far end of the bar so it grows back towards the health. Both sides flip with mirror.
        local edge, relTo, relEdge
        if reverse then
            edge = mirror and "LEFT" or "RIGHT"
            relTo, relEdge = clip, edge
        else
            edge = mirror and "RIGHT" or "LEFT"
            relTo, relEdge = heal:GetStatusBarTexture(), mirror and "LEFT" or "RIGHT"
        end
        absorb:SetPoint("TOP" .. edge, relTo, "TOP" .. relEdge, 0, 0)
        absorb:SetPoint("BOTTOM" .. edge, relTo, "BOTTOM" .. relEdge, 0, 0)

        -- The absorb always sits over the heals. They only overlap when it is reversed, and when
        -- they do the shield is the thing you want to read.
        local base = clip:GetFrameLevel()
        absorb:SetFrameLevel(base + 2)
        heal:SetFrameLevel(base + 1)

        -- "" is the dropdown's Frame Texture entry, so it means the frame's own bar texture
        local absorbTex = udb and udb.absorbTexture
        if absorbTex == nil then absorbTex = ABSORB_TEXTURE end
        if absorbTex == "" then absorbTex = udb and udb.texture end
        absorb:SetStatusBarTexture(GetBarTexture(absorbTex))
        absorb:SetStatusBarColor(unpack(ABSORB_COLOR))
    end
end

function UpdateHealPrediction(f)
    local heal, absorb = f.HealBar, f.AbsorbBar
    if not heal then return end
    local unit = f.unit
    local max = UnitHealthMax(unit)
    heal:SetMinMaxValues(0, max)
    absorb:SetMinMaxValues(0, max)
    -- the calculator hands back (possibly secret) numbers that SetValue accepts as-is
    local calc = f.HealCalc
    if calc and UnitGetDetailedHealPrediction then
        local ok = pcall(UnitGetDetailedHealPrediction, unit, "player", calc)
        if ok then
            local okH, incoming = pcall(calc.GetIncomingHeals, calc)
            local okA, absorbs = pcall(calc.GetDamageAbsorbs, calc)
            if okH then heal:SetValue(incoming) end
            if okA then absorb:SetValue(absorbs) end
            return
        end
    end
    pcall(function() heal:SetValue(UnitGetIncomingHeals(unit)) end)
    pcall(function() absorb:SetValue(UnitGetTotalAbsorbs(unit)) end)
end

-- Threat: the player's standing against this unit. 1 = higher than the tank, 2 = tanking
-- insecurely, 3 = tanking securely. Muted versions of Blizzard's yellow / orange / red so the
-- border tint reads without shouting.
local THREAT_COLORS = {
    [1] = { 0.80, 0.68, 0.30 },   -- above the tank
    [2] = { 0.80, 0.48, 0.25 },   -- tanking, insecure
    [3] = { 0.78, 0.28, 0.24 },   -- tanking, secure
}
local function ThreatColor(status)
    local c = THREAT_COLORS[status] or THREAT_COLORS[3]
    return c[1], c[2], c[3]
end

function UpdateIndicators(f)
    local unit = f.unit
    local readable = function(v) return canaccessvalue(v) and v or nil end

    if f.RestIcon then
        local show = ElementOn("rest") and IsResting()
        f.RestIcon:SetShown(show)
        if f.RestIcon.anim then
            if show then
                if not f.RestIcon.anim:IsPlaying() then f.RestIcon.anim:Play() end
            elseif f.RestIcon.anim:IsPlaying() then
                f.RestIcon.anim:Stop()
            end
        end
    end
    if f.LeaderIcon then
        local leader = readable(UnitIsGroupLeader(unit))
        local assist = readable(UnitIsGroupAssistant(unit))
        if not ElementOn("leader") then
            f.LeaderIcon:Hide()
        elseif leader then
            SetIconArt(f.LeaderIcon, "UI-HUD-UnitFrame-Player-Group-LeaderIcon", "Interface\\GroupFrame\\UI-Group-LeaderIcon")
            f.LeaderIcon:Show()
        elseif assist then
            SetIconArt(f.LeaderIcon, nil, "Interface\\GroupFrame\\UI-Group-AssistantIcon")
            f.LeaderIcon:Show()
        else
            f.LeaderIcon:Hide()
        end
    end
    if f.PvPIcon then
        local ffa = readable(UnitIsPVPFreeForAll(unit))
        local pvp = readable(UnitIsPVP(unit))
        local faction = readable(UnitFactionGroup(unit))
        if not ElementOn("pvp") then
            f.PvPIcon:Hide()
        elseif ffa then
            SetIconArt(f.PvPIcon, "UI-HUD-UnitFrame-Player-PVP-FFAIcon", "Interface\\TargetingFrame\\UI-PVP-FFA")
            f.PvPIcon:Show()
        elseif pvp and faction == "Horde" then
            SetIconArt(f.PvPIcon, "UI-HUD-UnitFrame-Player-PVP-HordeIcon", "Interface\\TargetingFrame\\UI-PVP-Horde")
            f.PvPIcon:Show()
        elseif pvp and faction == "Alliance" then
            SetIconArt(f.PvPIcon, "UI-HUD-UnitFrame-Player-PVP-AllianceIcon", "Interface\\TargetingFrame\\UI-PVP-Alliance")
            f.PvPIcon:Show()
        else
            f.PvPIcon:Hide()
        end
    end
    if f.ClassIcon then
        local c = readable(UnitClassification(unit))
        local atlas
        if c == "elite" or c == "worldboss" then atlas = "nameplates-icon-elite-gold"
        elseif c == "rareelite" then atlas = "nameplates-icon-elite-silver"
        elseif c == "rare" then atlas = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star" end
        if atlas and HasAtlas(atlas) and ElementOn("classification") then
            f.ClassIcon:SetAtlas(atlas, false)
            f.ClassIcon:Show()
        else
            f.ClassIcon:Hide()
        end
    end
    if f.QuestIcon then
        local show = ElementOn("questBoss") and readable(UnitIsQuestBoss(unit)) == true
        if show then SetIconArt(f.QuestIcon, "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Quest", "Interface\\TargetingFrame\\PortraitQuestBadge") end
        f.QuestIcon:SetShown(show)
    end
    if f.threatTint then
        -- the frame border takes the threat colour and returns to the fixed colour when clear
        local status = readable(UnitThreatSituation("player", unit))
        if status and status >= 1 then
            local r, g, b = ThreatColor(status)
            SetBorderTint(f.Border, r, g, b)
        else
            ResetBorderTint(f.Border)
        end
    end
    UpdateHealPrediction(f)
end

--------------------------------------------------
-- 10. LAYOUT
--------------------------------------------------
-- Anchors the bars inside the frame: health / [power], the seam straddled by the chat / damage meter
-- divider. The combo strip is laid over the health bar's top edge rather than taking a row of its
-- own. Touches only unprotected children, so it may run in combat (a druid shifting into cat form
-- mid-fight gains the strip immediately).
local function LayoutBars(f)
    local udb = GetUnitDb(f.unit)
    if not udb then return end
    local PADDING = INSET
    local powerHeight = udb.powerHeight or 8
    local health, power = f.Health, f.Power
    local comboShown = IsComboShown(f)

    health:ClearAllPoints()
    power:ClearAllPoints()
    health:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, -PADDING)

    if comboShown then
        local combo = f.Combo
        combo:ClearAllPoints()
        combo:SetPoint("TOPLEFT", health, "TOPLEFT", 0, 0)
        combo:SetPoint("TOPRIGHT", health, "TOPRIGHT", 0, 0)
        combo:SetHeight(COMBO_HEIGHT)
        combo:Show()
        LayoutComboSegments(f)
    elseif f.Combo then
        f.Combo:Hide()
    end
    if powerHeight > 0 then
        power:Show()
        power:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PADDING, PADDING)
        power:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PADDING, PADDING)
        power:SetHeight(powerHeight)
        health:SetPoint("BOTTOMRIGHT", power, "TOPRIGHT", 0, 0)
        f.Separator:ClearAllPoints()
        f.Separator:SetPoint("TOPLEFT", power, "TOPLEFT", 0, SEPARATOR_HEIGHT / 2)
        f.Separator:SetPoint("TOPRIGHT", power, "TOPRIGHT", 0, SEPARATOR_HEIGHT / 2)
        f.Separator:SetHeight(SEPARATOR_HEIGHT)
        f.Separator:Show()
    else
        f.Separator:Hide()
        power:Hide()
        health:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PADDING, PADDING)
    end
end

-- Decides whether the strip is shown and how many segments it has, feeds the values, and
-- re-lays the bars when the strip appears or disappears.
function UpdateComboPoints(f)
    local combo = f.Combo
    if not combo then return end
    local count = 0
    if not UsesClassicCombo(f) and ShouldShowComboPoints() then
        local max = UnitPowerMax("player", Enum.PowerType.ComboPoints)
        if not (canaccessvalue(max) and max and max >= 1) then max = COMBO_FALLBACK_MAX end
        count = math.min(max, COMBO_MAX_SEGMENTS)
    end
    if count ~= combo.count then
        combo.count = count
        LayoutBars(f)
    end
    if count > 0 then
        local value = LEM:IsInEditMode() and COMBO_PREVIEW_POINTS or GetComboPoints("player", "target")
        for i = 1, count do GetComboSegment(f, i):SetValue(value) end
    end
end

local function LayoutFrame(f)
    local db, udb = GetDb(), GetUnitDb(f.unit)
    if not db or not udb then return end
    if InCombatLockdown() then pendingLayout = true return end

    local width, height = udb.width or 220, udb.height or 44
    local powerHeight = udb.powerHeight or 8
    local PADDING = INSET
    f:SetSize(width, height)

    local edgeFile = GetBorderFile(udb.border)
    f:SetBackdrop({ bgFile = BACKDROP_FILE, insets = { left = PADDING, right = PADDING, top = PADDING, bottom = PADDING } })
    f:SetBackdropColor(0, 0, 0, BG_OPACITY)
    -- the border sits on its own frame above the bars, so the art overlaps the bar edges and no
    -- backdrop shows through between them
    ApplyBorderStyle(f.Border, edgeFile)

    local texture = GetBarTexture(udb.texture)
    local health, power = f.Health, f.Power
    health:SetStatusBarTexture(texture)
    power:SetStatusBarTexture(texture)
    health.bg:SetTexture(texture)
    power.bg:SetTexture(texture)
    -- mirrored frames (target / focus facing the player frame) fill right to left and swap the
    -- text order to [health][name][level]
    local mirror = udb.mirror and true or false
    health:SetReverseFill(mirror)
    power:SetReverseFill(mirror)

    LayoutBars(f)

    -- texts
    ApplyFont(f.Name, db.font)
    ApplyFont(f.Level, db.font)
    ApplyFont(f.HealthText, db.font)
    ApplyFont(f.PowerText, db.fontPower or db.font)

    f.Level:ClearAllPoints()
    f.Name:ClearAllPoints()
    f.HealthText:ClearAllPoints()
    f.PowerText:ClearAllPoints()
    if mirror then
        f.Level:SetJustifyH("RIGHT")
        f.Name:SetJustifyH("RIGHT")
        f.HealthText:SetJustifyH("LEFT")
        f.PowerText:SetJustifyH("LEFT")
        f.Level:SetPoint("RIGHT", health, "RIGHT", -TEXT_INSET, 0)
        if udb.showLevel then
            f.Name:SetPoint("RIGHT", f.Level, "LEFT", -3, 0)
        else
            f.Name:SetPoint("RIGHT", health, "RIGHT", -TEXT_INSET, 0)
        end
        f.HealthText:SetPoint("LEFT", health, "LEFT", TEXT_INSET, 0)
        f.Name:SetPoint("LEFT", f.HealthText, "RIGHT", 4, 0)
        f.PowerText:SetPoint("LEFT", power, "LEFT", TEXT_INSET, 0)
    else
        f.Level:SetJustifyH("LEFT")
        f.Name:SetJustifyH("LEFT")
        f.HealthText:SetJustifyH("RIGHT")
        f.PowerText:SetJustifyH("RIGHT")
        f.Level:SetPoint("LEFT", health, "LEFT", TEXT_INSET, 0)
        if udb.showLevel then
            f.Name:SetPoint("LEFT", f.Level, "RIGHT", 3, 0)
        else
            f.Name:SetPoint("LEFT", health, "LEFT", TEXT_INSET, 0)
        end
        f.HealthText:SetPoint("RIGHT", health, "RIGHT", -TEXT_INSET, 0)
        f.Name:SetPoint("RIGHT", f.HealthText, "LEFT", -4, 0)
        f.PowerText:SetPoint("RIGHT", power, "RIGHT", -TEXT_INSET, 0)
    end
    f.PowerText:SetShown(udb.powerText and powerHeight >= 10)

    -- the raid marker and the pet's happiness face sit mid health bar, sized off its height; the
    -- health bar runs from the top inset down to the power bar (or the bottom inset)
    local healthHeight = height - 2 * PADDING - (powerHeight > 0 and powerHeight or 0)
    local markerSize = math.max(8, healthHeight * RAID_ICON_SHARE)
    f.RaidIcon:ClearAllPoints()
    f.RaidIcon:SetSize(markerSize, markerSize)
    f.RaidIcon:SetPoint("CENTER", f.Health, "CENTER", 0, 0)

    if f.Happiness then
        local size = math.max(RAID_ICON, healthHeight * HAPPINESS_SHARE)
        f.Happiness:SetSize(size, size)
        f.Happiness:ClearAllPoints()
        f.Happiness:SetPoint("CENTER", f.Health, "CENTER", 0, 0)
    end

    -- cast bar hangs off the frame
    if f.Cast then
        LayoutCastBar(f.Cast, GetCastStyle(udb, false), f, udb.castbarPosition == "TOP" and "TOP" or "BOTTOM")
    end

    LayoutAuras(f)
    LayoutIndicators(f)
end

--------------------------------------------------
-- 11. BLIZZARD EXTRAS THAT MUST FOLLOW OUR FRAMES
-- Forever puts totems / pet in the PlayerBottomManagedFrameContainer (anchored to PlayerFrame);
-- re-anchor it to our player frame. The classic ComboFrame is hidden (see 5c).
--------------------------------------------------

local function AttachExtras(f)
    if InCombatLockdown() then pendingLayout = true return end
    if f.unit == "player" then
        local container = _G.PlayerBottomManagedFrameContainer
        if container then
            container:ClearAllPoints()
            container:SetPoint("TOP", f, "BOTTOM", 0, -2)
        end
    end
end

local extrasHooked = false
local function HookExtras()
    if extrasHooked then return end
    extrasHooked = true
    -- Blizzard re-anchors the bottom container when the player art changes (vehicles)
    for _, name in ipairs({ "PlayerFrame_ToPlayerArt", "PlayerFrame_ToVehicleArt" }) do
        if type(_G[name]) == "function" then
            hooksecurefunc(name, function() if frames.player then AttachExtras(frames.player) end end)
        end
    end
end

--------------------------------------------------
-- 12. POSITIONS (per Edit Mode layout)
--------------------------------------------------
-- Laid out in Edit Mode on 2026-09-25 and copied from the saved layout. Player and target mirror
-- each other either side of the centre. Pet and cast bar share a line below them, target of target
-- sits under the target's cast bar, and all three are pinned to the bottom edge so they keep their
-- distance from the action bars. Focus is pinned to the right edge. Each point anchors to the same point on UIParent (ApplyPosition).
local DEFAULT_POSITIONS = {
    player        = { point = "CENTER", x = -330, y = -270 },
    target        = { point = "CENTER", x = 330,  y = -270 },
    targettarget  = { point = "BOTTOM", x = 270,  y = 248 },
    focus         = { point = "RIGHT",  x = -453, y = -258 },
    pet           = { point = "BOTTOM", x = -290, y = 271 },   -- its right edge lines up with the player frame's
    playercastbar = { point = "BOTTOM", x = 0,    y = 268 },
}

-- The cast bar's default follows the gamepad UI: its action bar stands taller than ours, so the cast
-- bar moves up to clear it. Only the default switches - a position dragged in Edit Mode is kept per
-- layout and still wins. The table is updated in place because FlareEditMode keeps a reference to it
-- (lib.frameDefaults) for its own "reset position".
local CASTBAR_DEFAULTS = {
    keyboard = { point = "BOTTOM", x = 0, y = 268 },
    gamepad  = { point = "CENTER", x = 0, y = -221 },
}

local function UpdateCastbarDefault()
    local src = CASTBAR_DEFAULTS[ns.IsGamepadUI() and "gamepad" or "keyboard"]
    local pos = DEFAULT_POSITIONS.playercastbar
    pos.point, pos.x, pos.y = src.point, src.x, src.y
end

local function GetLayoutStore(layoutName)
    local db = GetDb()
    if not db then return nil end
    layoutName = layoutName or LEM:GetActiveLayoutName() or "Modern"
    db.layouts = db.layouts or {}
    db.layouts[layoutName] = db.layouts[layoutName] or {}
    return db.layouts[layoutName]
end

local function ApplyPosition(f, layoutName)
    if InCombatLockdown() then pendingLayout = true return end
    if f.unit == "playercastbar" then UpdateCastbarDefault() end
    local store = GetLayoutStore(layoutName)
    local pos = store and store[f.unit] or DEFAULT_POSITIONS[f.unit]
    -- The pet frame grew from 120 to 160 px, its default moving left to keep the right edge on the
    -- player frame's. A saved position still at the old default is that default, so it moves too.
    if f.unit == "pet" and pos.point == "BOTTOM" and pos.x == -270 and pos.y == 271 then
        pos.x = DEFAULT_POSITIONS.pet.x
    end
    f:ClearAllPoints()
    f:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or 0, pos.y or 0)
end

local function OnFrameMoved(f, layoutName, point, x, y)
    local store = GetLayoutStore(layoutName)
    if not store then return end
    store[f.unit] = { point = point, x = math_floor(x + 0.5), y = math_floor(y + 0.5) }
end

--------------------------------------------------
-- 13. VISIBILITY
-- "visibility" state drivers are evaluated in plain Lua by SecureStateDriver - no snippet to
-- compile. In Edit Mode every frame is shown for placing.
--------------------------------------------------
local function ApplyVisibility(f)
    if InCombatLockdown() then pendingLayout = true return end
    local info = UNITS[f.unit]
    if LEM:IsInEditMode() then
        UnregisterStateDriver(f, "visibility")
        f:Show()
    elseif info.driver then
        RegisterStateDriver(f, "visibility", info.driver)
    else
        UnregisterStateDriver(f, "visibility")
        f:Show()
    end
end

--------------------------------------------------
-- 14. CONDITIONAL VISIBILITY (fading)
-- Three settings sets: "player" (shared by the pet frame), "target", "focus". With no condition on,
-- a frame is always at Max Alpha; otherwise it fades to Min Alpha until any condition holds.
-- Alpha is not protected, so this works in combat; the state drivers still own show / hide.
--------------------------------------------------
local VIS_SET = { player = "player", pet = "player", target = "target", focus = "focus" }
local FADE_INTERVAL = 0.1

local function GetVisDb(set)
    local db = GetDb()
    return db and db.visibility and db.visibility[set]
end

local function HasConditions(cfg)
    return cfg.condMouseover or cfg.condCombat or cfg.condTarget or cfg.condHarm or cfg.condHealth
end

-- UnitCanAttack / UnitHealth can be secret; a bare truth test or comparison would throw
local function IsAttackable(unit)
    if not UnitExists(unit) then return false end
    local can = UnitCanAttack("player", unit)
    return canaccessvalue(can) and can and true or false
end

local function IsHealthMissing(unit)
    local hp, max = UnitHealth(unit), UnitHealthMax(unit)
    if not (canaccessvalue(hp) and canaccessvalue(max)) then return false end
    return hp < max
end

local function IsFrameMouseOver(f)
    return f and f:IsShown() and f:IsMouseOver()
end

local function ShouldShow(set, cfg)
    if LEM:IsInEditMode() then return true end
    if not HasConditions(cfg) then return true end
    if cfg.condCombat and InCombatLockdown() then return true end
    if set == "player" then
        if cfg.condMouseover and (IsFrameMouseOver(frames.player) or IsFrameMouseOver(frames.pet)) then return true end
        if cfg.condTarget and UnitExists("target") then return true end
        if cfg.condHarm and IsAttackable("target") then return true end
        if cfg.condHealth and IsHealthMissing("player") then return true end
    else
        if cfg.condHarm and IsAttackable(set) then return true end
    end
    return false
end

local fader = CreateFrame("Frame")
fader.elapsed = 0

local function FadeTick(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed < FADE_INTERVAL then return end
    self.elapsed = 0

    local decided = {}
    for unit, f in pairs(frames) do
        local set = VIS_SET[unit]
        local cfg = set and GetVisDb(set)
        if cfg then
            if decided[set] == nil then decided[set] = ShouldShow(set, cfg) end
            local target = decided[set] and (cfg.alphaMax or 1) or (cfg.alphaMin or 0)
            if math.abs(f:GetAlpha() - target) > 0.005 then f:SetAlpha(target) end
        end
    end
end

-- Runs the ticker only while some set has a condition; otherwise frames sit at Max Alpha.
local function RefreshVisibilityFader()
    local active = false
    for unit, f in pairs(frames) do
        local set = VIS_SET[unit]
        local cfg = set and GetVisDb(set)
        if cfg then
            if HasConditions(cfg) then
                active = true
            else
                f:SetAlpha(cfg.alphaMax or 1)
            end
        end
    end
    fader.elapsed = FADE_INTERVAL
    if active then
        fader:SetScript("OnUpdate", FadeTick)
        FadeTick(fader, 0)
    else
        fader:SetScript("OnUpdate", nil)
    end
end

--------------------------------------------------
-- 15. FRAME CREATION
--------------------------------------------------
local function OnEnter(f)
    f.Highlight:Show()
    if GameTooltip:IsForbidden() then return end
    GameTooltip_SetDefaultAnchor(GameTooltip, f)
    GameTooltip:SetUnit(f.unit)
    GameTooltip:Show()
end

local function OnLeave(f)
    f.Highlight:Hide()
    if not GameTooltip:IsForbidden() then GameTooltip:Hide() end
end

local function CreateUnitFrame(unit)
    local info = UNITS[unit]
    local f = CreateFrame("Button", "FlareUI_UF_" .. info.key, UIParent, "SecureUnitButtonTemplate,PingableUnitFrameTemplate,BackdropTemplate")
    f.unit = unit
    f:SetFrameStrata("LOW")
    f:SetAttribute("unit", unit)
    f:SetAttribute("*type1", "target")
    f:SetAttribute("*type2", "togglemenu")
    f:RegisterForClicks("AnyUp")
    if type(f.SetRolesets) == "function" then pcall(f.SetRolesets, f, "unitFrames") end
    _G.ClickCastFrames = _G.ClickCastFrames or {}
    _G.ClickCastFrames[f] = true
    f:SetClampedToScreen(true)
    f.editModeName = "FlareUI " .. info.label

    local level = f:GetFrameLevel()
    f.Health = CreateBar(f, level + 1)
    f.Power = CreateBar(f, level + 1)

    -- Levels, in order: bars +1, heal / absorb overlay +2, combo strip +3, border +4, text +5.
    -- The combo strip needs a slot between the overlays it covers and the border that has to stay
    -- on top of everything, which is why these are not simply consecutive.
    f.Border = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.Border:SetAllPoints()
    f.Border:SetFrameLevel(level + 4)

    local overlay = CreateFrame("Frame", nil, f)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(level + 5)
    f.Overlay = overlay
    f.Name = overlay:CreateFontString(nil, "OVERLAY")
    f.Name:SetJustifyH("LEFT")
    f.Name:SetWordWrap(false)
    f.Level = overlay:CreateFontString(nil, "OVERLAY")
    f.Level:SetJustifyH("LEFT")
    f.HealthText = overlay:CreateFontString(nil, "OVERLAY")
    f.HealthText:SetJustifyH("RIGHT")
    f.PowerText = overlay:CreateFontString(nil, "OVERLAY")
    f.PowerText:SetJustifyH("RIGHT")

    f.RaidIcon = overlay:CreateTexture(nil, "OVERLAY")
    f.RaidIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    f.RaidIcon:Hide()

    f.Separator = overlay:CreateTexture(nil, "ARTWORK")
    f.Separator:SetTexture(SEPARATOR_TEXTURE)
    f.Separator:SetVertexColor(1, 1, 1, 1)
    f.Separator:Hide()

    f.Highlight = overlay:CreateTexture(nil, "OVERLAY")
    f.Highlight:SetAllPoints(f.Health)
    f.Highlight:SetColorTexture(1, 1, 1, 0.08)
    f.Highlight:Hide()

    if info.castbar then f.Cast = CreateCastBar(f, unit) end
    if info.comboPoints then
        CreateComboPoints(f)
        ApplyComboMode(f)
    end
    CreateIndicators(f)
    if unit == "player" then CreateFsrSpark(f) end
    if info.happiness then CreateHappiness(f) end
    PrecreateAuraContainers(f)

    f:SetScript("OnEnter", OnEnter)
    f:SetScript("OnLeave", OnLeave)
    f:SetScript("OnEvent", OnUnitEvent)
    for _, event in ipairs(UNIT_EVENTS) do
        pcall(f.RegisterUnitEvent, f, event, unit)
    end
    if info.events then
        for _, event in ipairs(info.events) do pcall(f.RegisterUnitEvent, f, event, unit) end
    end
    if f.Combo then
        -- re-registering replaces the unit filter, so these now fire for the target and the player
        for event in pairs(COMBO_EVENTS) do pcall(f.RegisterUnitEvent, f, event, unit, "player") end
    end
    if info.castbar then
        for _, event in ipairs(CAST_EVENTS) do pcall(f.RegisterUnitEvent, f, event, unit) end
    end
    pcall(f.RegisterEvent, f, "RAID_TARGET_UPDATE")
    if info.indicators then
        if info.indicators.heals then
            pcall(f.RegisterUnitEvent, f, "UNIT_HEAL_PREDICTION", unit)
            pcall(f.RegisterUnitEvent, f, "UNIT_ABSORB_AMOUNT_CHANGED", unit)
        end
        if info.indicators.threat then
            pcall(f.RegisterUnitEvent, f, "UNIT_THREAT_LIST_UPDATE", unit)
            pcall(f.RegisterUnitEvent, f, "UNIT_THREAT_SITUATION_UPDATE", "player", unit)
        end
    end
    -- the unit behind a token changed: refresh everything
    if info.globalEvents then
        for event, filter in pairs(info.globalEvents) do
            if filter == true then
                pcall(f.RegisterEvent, f, event)
            else
                pcall(f.RegisterUnitEvent, f, event, filter)
            end
        end
    end

    frames[unit] = f
    return f
end

--------------------------------------------------
-- 16. EDIT MODE SETTINGS
--------------------------------------------------
-- LSM statusbar names for the Edit Mode dropdowns; "" = the frames' shared texture
local function BuildTextureValues(withFrameDefault)
    local values = {}
    if withFrameDefault then values[#values + 1] = { text = "Frame Texture", value = "", isRadio = true } end
    for _, name in ipairs(LSM:List("statusbar")) do
        values[#values + 1] = { text = name, value = name, isRadio = true }
    end
    return values
end

local function BuildBorderValues(withFrameDefault)
    local values = {}
    if withFrameDefault then values[#values + 1] = { text = "Frame Border", value = "", isRadio = true } end
    for _, name in ipairs(LSM:List("border")) do
        values[#values + 1] = { text = name, value = name, isRadio = true }
    end
    return values
end

--------------------------------------------------
-- 17. STANDALONE PLAYER CAST BAR
-- Replaces PlayerCastingBarFrame with a bar in the unit-frame style that moves freely in Edit Mode.
--------------------------------------------------
local playerCastHolder

local function GetPlayerCastDb()
    local db = GetDb()
    return db and db.playerCastbar
end

local function LayoutPlayerCastBar()
    local holder = playerCastHolder
    local cfg = GetPlayerCastDb()
    if not holder or not cfg then return end
    if InCombatLockdown() then pendingLayout = true return end
    local style = GetCastStyle(cfg, true)
    local PADDING = INSET
    local iconOffset = style.icon and (style.height + CAST_ICON_GAP) or 0
    holder:SetSize(style.width + iconOffset + 2 * PADDING, style.height + 2 * PADDING)
    LayoutCastBar(holder.Cast, style, holder, "FILL")
end

local function CreatePlayerCastBar()
    if playerCastHolder then return playerCastHolder end
    local holder = CreateFrame("Frame", "FlareUI_UF_PlayerCastBar", UIParent)
    holder:SetFrameStrata("MEDIUM")
    holder:SetClampedToScreen(true)
    holder.unit = "playercastbar"
    holder.editModeName = "FlareUI Player Cast Bar"
    holder.Cast = CreateCastBar(holder, "player")
    holder.Cast.standalone = true
    holder:SetScript("OnEvent", function(self) UpdateCastBar(self.Cast, IsCastEnabled(self.Cast)) end)
    for _, event in ipairs(CAST_EVENTS) do pcall(holder.RegisterUnitEvent, holder, event, "player") end
    pcall(holder.RegisterEvent, holder, "PLAYER_ENTERING_WORLD")
    playerCastHolder = holder
    return holder
end

local function BuildPlayerCastSettings()
    local function get(key, default)
        return function() local c = GetPlayerCastDb(); local v = c and c[key]; if v == nil then return default end; return v end
    end
    local function set(key)
        return function(_, value)
            local c = GetPlayerCastDb()
            if not c then return end
            c[key] = value
            LayoutPlayerCastBar()
            if playerCastHolder then UpdateCastBar(playerCastHolder.Cast, IsCastEnabled(playerCastHolder.Cast)) end
        end
    end
    return {
        { name = "Width", kind = LEM.SettingType.Slider, default = 292, minValue = 100, maxValue = 600, valueStep = 2, get = get("width", 292), set = set("width") },
        { name = "Height", kind = LEM.SettingType.Slider, default = 26, minValue = 8, maxValue = 48, valueStep = 1, get = get("height", 26), set = set("height") },
        { name = "Texture", kind = LEM.SettingType.Dropdown, default = "Armory", values = BuildTextureValues(true), get = get("texture", "Armory"), set = set("texture") },
        { name = "Border Texture", kind = LEM.SettingType.Dropdown, default = DEFAULT_BORDER, values = BuildBorderValues(false), get = get("borderTexture", DEFAULT_BORDER), set = set("borderTexture") },
        { name = "Icon", kind = LEM.SettingType.Checkbox, default = true, get = get("icon", true), set = set("icon") },
        { name = "Spell Name", kind = LEM.SettingType.Checkbox, default = true, get = get("name", true), set = set("name") },
        { name = "Timer", kind = LEM.SettingType.Checkbox, default = true, get = get("timer", true), set = set("timer") },
    }
end

local function BuildSettings(unit)
    local info = UNITS[unit]
    local function get(key) return function() local u = GetUnitDb(unit); return u and u[key] end end
    local function set(key, refreshAll)
        return function(_, value)
            local u = GetUnitDb(unit)
            if not u then return end
            u[key] = value
            local f = frames[unit]
            if f then LayoutFrame(f); UpdateAll(f) end
        end
    end
    local defaults = ns.defaults and ns.defaults.profile.unitframes.units[unit] or {}

    local settings = {
        { name = "Width", kind = LEM.SettingType.Slider, default = defaults.width or 220, minValue = 60, maxValue = 500, valueStep = 2, get = get("width"), set = set("width") },
        { name = "Height", kind = LEM.SettingType.Slider, default = defaults.height or 44, minValue = 16, maxValue = 120, valueStep = 1, get = get("height"), set = set("height") },
        { name = "Power Bar Height", kind = LEM.SettingType.Slider, default = defaults.powerHeight or 8, minValue = 0, maxValue = 40, valueStep = 1, get = get("powerHeight"), set = set("powerHeight"),
          formatter = function(value) return value == 0 and _G.OFF or value end },
        { name = "Health Text", kind = LEM.SettingType.Dropdown, default = defaults.healthText or "percent", values = HEALTH_TEXT_MODES, get = get("healthText"), set = set("healthText") },
        { name = "Power Text", kind = LEM.SettingType.Checkbox, default = defaults.powerText or false, get = get("powerText"), set = set("powerText") },
        { name = "Show Level", kind = LEM.SettingType.Checkbox, default = defaults.showLevel ~= false, get = get("showLevel"), set = set("showLevel") },
    }
    if info.mirrorable then
        -- flips text order and bar fill so the frame faces the player frame
        settings[#settings + 1] = { name = "Mirror", kind = LEM.SettingType.Checkbox, default = defaults.mirror or false, get = function() local u = GetUnitDb(unit); return u and u.mirror or false end,
            set = function(_, value) local u = GetUnitDb(unit); if not u then return end; u.mirror = value; local f = frames[unit]; if f then LayoutFrame(f); AttachExtras(f); UpdateAll(f) end end }
    end
    if info.happiness then
        settings[#settings + 1] = { name = "Happiness", kind = LEM.SettingType.Checkbox, default = true,
            get = function() local u = GetUnitDb(unit); return not u or u.happiness ~= false end, set = set("happiness"),
            desc = "Your hunter pet's happiness face in the middle of the health bar." }
    end
    tAppendAll(settings, {
        { name = "Look", kind = LEM.SettingType.Divider },
        { name = "Bar Texture", kind = LEM.SettingType.Dropdown, default = defaults.texture or DEFAULT_TEXTURE, values = BuildTextureValues(false),
          get = function() local u = GetUnitDb(unit); return u and u.texture or DEFAULT_TEXTURE end, set = set("texture") },
        { name = "Border Texture", kind = LEM.SettingType.Dropdown, default = defaults.border or DEFAULT_BORDER, values = BuildBorderValues(false),
          get = function() local u = GetUnitDb(unit); return u and u.border or DEFAULT_BORDER end, set = set("border") },
    })
    if info.indicators and info.indicators.heals then
        settings[#settings + 1] = { name = "Absorbs", kind = LEM.SettingType.Divider }
        settings[#settings + 1] = { name = "Absorb Texture", kind = LEM.SettingType.Dropdown,
            default = defaults.absorbTexture or "", values = BuildTextureValues(true),
            get = function() local u = GetUnitDb(unit); return u and u.absorbTexture or "" end,
            set = set("absorbTexture") }
        settings[#settings + 1] = { name = "Absorb Reverse Fill", kind = LEM.SettingType.Checkbox,
            default = defaults.absorbReverseFill ~= false,
            get = function() local u = GetUnitDb(unit); return u and u.absorbReverseFill ~= false end,
            set = set("absorbReverseFill") }
    end
    if info.castbar then
        settings[#settings + 1] = { name = "Cast Bar", kind = LEM.SettingType.Divider }
        settings[#settings + 1] = { name = "Cast Bar Position", kind = LEM.SettingType.Dropdown, default = defaults.castbarPosition or "BOTTOM",
            values = { { text = "Above", value = "TOP", isRadio = true }, { text = "Below", value = "BOTTOM", isRadio = true } },
            get = get("castbarPosition"), set = set("castbarPosition") }
        settings[#settings + 1] = { name = "Cast Bar Height", kind = LEM.SettingType.Slider, default = defaults.castHeight or CAST_HEIGHT, minValue = 8, maxValue = 40, valueStep = 1, get = get("castHeight"), set = set("castHeight") }
        settings[#settings + 1] = { name = "Cast Bar Texture", kind = LEM.SettingType.Dropdown, default = defaults.castTexture or "", values = BuildTextureValues(true), get = function() local u = GetUnitDb(unit); return u and u.castTexture or "" end, set = set("castTexture") }
        settings[#settings + 1] = { name = "Cast Bar Border Texture", kind = LEM.SettingType.Dropdown, default = defaults.castBorderTexture or "", values = BuildBorderValues(true),
            get = function() local u = GetUnitDb(unit); return u and u.castBorderTexture or "" end, set = set("castBorderTexture") }
        settings[#settings + 1] = { name = "Cast Icon", kind = LEM.SettingType.Checkbox, default = defaults.castIcon ~= false, get = function() local u = GetUnitDb(unit); return u and u.castIcon ~= false end, set = set("castIcon") }
        settings[#settings + 1] = { name = "Cast Timer", kind = LEM.SettingType.Checkbox, default = defaults.castTimer ~= false, get = function() local u = GetUnitDb(unit); return u and u.castTimer ~= false end, set = set("castTimer") }
    end
    if info.auras then
        local positions = {
            { text = "Off",          value = "OFF",         isRadio = true },
            { text = "Top Left",     value = "TOPLEFT",     isRadio = true },
            { text = "Top Right",    value = "TOPRIGHT",    isRadio = true },
            { text = "Bottom Left",  value = "BOTTOMLEFT",  isRadio = true },
            { text = "Bottom Right", value = "BOTTOMRIGHT", isRadio = true },
        }
        settings[#settings + 1] = { name = "Auras", kind = LEM.SettingType.Divider }
        settings[#settings + 1] = { name = "Buffs", kind = LEM.SettingType.Dropdown, default = defaults.buffs or "OFF", values = positions, get = get("buffs"), set = set("buffs") }
        settings[#settings + 1] = { name = "Debuffs", kind = LEM.SettingType.Dropdown, default = defaults.debuffs or "OFF", values = positions, get = get("debuffs"), set = set("debuffs") }
        settings[#settings + 1] = { name = "Aura Size", kind = LEM.SettingType.Slider, default = defaults.auraSize or 22, minValue = 12, maxValue = 48, valueStep = 1, get = get("auraSize"), set = set("auraSize") }
        settings[#settings + 1] = { name = "Max Per Type", kind = LEM.SettingType.Slider, default = defaults.auraMax or 16, minValue = 1, maxValue = 40, valueStep = 1, get = get("auraMax"), set = set("auraMax") }
        settings[#settings + 1] = { name = "Only My Debuffs", kind = LEM.SettingType.Checkbox, default = defaults.onlyMyDebuffs or false, get = get("onlyMyDebuffs"), set = set("onlyMyDebuffs") }
        settings[#settings + 1] = { name = "Hide Permanent Buffs", kind = LEM.SettingType.Checkbox, default = defaults.hidePermanentBuffs or false, get = get("hidePermanentBuffs"), set = set("hidePermanentBuffs") }
    end
    return settings
end

local function RegisterEditMode(f)
    LEM:AddFrame(f, OnFrameMoved, DEFAULT_POSITIONS[f.unit], "FlareUI " .. UNITS[f.unit].label)
    LEM:AddFrameSettings(f, BuildSettings(f.unit))
end

--------------------------------------------------
-- 18. PUBLIC
--------------------------------------------------
function UF:Refresh()
    if not self.initialized then return end
    if InCombatLockdown() then pendingLayout = true return end
    pendingLayout = false
    -- one frame failing to lay out must not leave the others (or the cast bar) half-built
    local function guard(label, fn, ...)
        local ok, err = pcall(fn, ...)
        if not ok then print("|cffff0000FlareUI UnitFrames:|r " .. label .. ": " .. tostring(err)) end
    end
    for unit, f in pairs(frames) do
        guard(unit, function()
            LayoutFrame(f)
            ApplyPosition(f)
            ApplyVisibility(f)
            AttachExtras(f)
            if f.Combo then ApplyComboMode(f) end
            UpdateAll(f)
        end)
    end
    RefreshVisibilityFader()
    if playerCastHolder then
        guard("player cast bar", function()
            LayoutPlayerCastBar()
            ApplyPosition(playerCastHolder)
            UpdateCastBar(playerCastHolder.Cast, IsCastEnabled(playerCastHolder.Cast))
        end)
    end
end

function UF:RefreshVisibility()
    if not self.initialized then return end
    RefreshVisibilityFader()
end

function UF:PLAYER_REGEN_ENABLED()
    if pendingLayout then self:Refresh() end
end

-- Re-places the cast bar whenever the gamepad bar comes or goes, so toggling the gamepad UI moves it
-- between its two defaults without a reload. Retried from later events, since the gamepad bar may
-- not exist yet when this module starts.
function UF:PLAYER_ENTERING_WORLD()
    for _, f in pairs(frames) do UpdateAll(f) end
    if playerCastHolder then UpdateCastBar(playerCastHolder.Cast, IsCastEnabled(playerCastHolder.Cast)) end
end

-- the cast bar's default follows the gamepad UI (CASTBAR_DEFAULTS), so it moves on the switch
function UF:INPUT_DEVICE_INTERFACE_TRANSITION()
    if playerCastHolder then ApplyPosition(playerCastHolder) end
end

-- Saves from before the release name the LS:Borders art FlareUI no longer ships. GetBorderFile
-- already draws the default for them; this makes the Edit Mode dropdowns show it too.
local REMOVED_BORDERS = { Thick = true, Thin = true }
local function MigrateRemovedBorders(db)
    local function fix(t, key)
        if t and REMOVED_BORDERS[t[key]] then t[key] = DEFAULT_BORDER end
    end
    fix(db.playerCastbar, "borderTexture")
    for _, udb in pairs(db.units or {}) do
        fix(udb, "border")
        fix(udb, "castBorderTexture")
    end
end

function UF:Init()
    if self.initialized then return end
    local db = GetDb()
    if not db then return end
    MigrateRemovedBorders(db)

    for _, unit in ipairs(UNIT_ORDER) do
        local udb = db.units[unit]
        if udb and udb.enabled then
            local f = CreateUnitFrame(unit)
            RegisterEditMode(f)
            if UNITS[unit].blizzard then
                for _, name in ipairs(UNITS[unit].blizzard) do HardHide(name) end
            end
        end
    end
    -- target of target lives inside TargetFrame; hiding the target frame takes it along
    if db.playerCastbar and db.playerCastbar.enabled then
        local holder = CreatePlayerCastBar()
        LEM:AddFrame(holder, OnFrameMoved, DEFAULT_POSITIONS.playercastbar, holder.editModeName)
        LEM:AddFrameSettings(holder, BuildPlayerCastSettings())
        HardHide("PlayerCastingBarFrame")
    end
    HookExtras()
    if frames.player then InitFsrSpark() end
    self.initialized = true

    LEM:RegisterCallback("layout", function(layoutName)
        for _, f in pairs(frames) do ApplyPosition(f, layoutName) end
        if playerCastHolder then ApplyPosition(playerCastHolder, layoutName) end
    end)
    LEM:RegisterCallback("enter", function()
        for _, f in pairs(frames) do ApplyVisibility(f); f:SetAlpha(1); if f.Combo then UpdateComboPoints(f) end; UpdateHappiness(f) end
        SetAuraPreview(true)
        SetCastPreview(true)
    end)
    LEM:RegisterCallback("exit", function()
        for _, f in pairs(frames) do ApplyVisibility(f); if f.Combo then UpdateComboPoints(f) end; UpdateHappiness(f) end
        RefreshVisibilityFader()
        SetAuraPreview(false)
        SetCastPreview(false)
    end)

    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("INPUT_DEVICE_INTERFACE_TRANSITION")

    self:Refresh()
    C_Timer.After(0, function() self:Refresh() end)
end
