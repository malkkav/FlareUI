local _, ns = ...
local L = ns.L

--------------------------------------------------
-- RESOURCE BARS
-- Health, power, druid mana, combo point, swing timer, flight timer and seal bars, each an Edit Mode frame. Replaces the
-- Personal Resource Display and Blizzard's swing timers. Secret-safe: values go straight into
-- widgets, readable() guards every Lua test.
--------------------------------------------------

--------------------------------------------------
-- 1. MODULE REGISTRATION
--------------------------------------------------
ns.ResourceBars = ns.ResourceBars or {}
local RB = ns.ResourceBars
ns.modules["ResourceBars"] = RB

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
    combo      = { ns.COMBO_COLOR[1], ns.COMBO_COLOR[2], ns.COMBO_COLOR[3] },   -- (its own: the palette writes it)
    swingMain  = { 0.86, 0.65, 0.39 },
    swingOff   = { 0.72, 0.54, 0.32 },
    swingRanged = { 0.45, 0.68, 0.40 },
    outOfRange = { 0.78, 0.28, 0.24 },
    queued     = { 1.00, 0.82, 0.25 },   -- Queued Attack Colour: an on-next-swing attack is queued
    waiting    = { 0.45, 0.45, 0.45 },   -- Waiting State: auto attack on, no swing running
    flight     = { 0.40, 0.62, 0.86 },   -- Flight Timer
}

-- textSize: added to the Fonts tab size
local BAR_ORDER = { "health", "power", "mana", "combo", "swingMain", "swingOff", "swingRanged", "flight", "seal" }
local BARS = {
    health      = { kind = "health", label = L["Health Bar"],      default = { point = "CENTER", x = 0, y = -148 }, textSize = 2 },
    power       = { kind = "power",  label = L["Power Bar"],       default = { point = "CENTER", x = 0, y = -180 }, textSize = 2 },
    -- right under the power bar, the health-to-power gap apart (11-11)
    mana        = { kind = "mana",   label = L["Druid Mana"],      default = { point = "CENTER", x = 0, y = -212 }, textSize = 2 },
    -- from here on the default spots are Marcus's own (11-12)
    combo       = { kind = "combo",  label = L["Combo Points"],    default = { point = "CENTER", x = 0, y = -88 } },
    swingMain   = { kind = "swing",  label = L["Main-Hand Swing"], default = { point = "CENTER", x = 0, y = -288 }, textSize = 0,
                    swingType = SWING and SWING.MainHand, text = _G.SWING_TIMER_MAIN_HAND or "Main Hand" },
    swingOff    = { kind = "swing",  label = L["Off-Hand Swing"],  default = { point = "BOTTOM", x = 0, y = 276 }, textSize = 0,
                    swingType = SWING and SWING.OffHand, text = _G.SWING_TIMER_OFF_HAND or "Off Hand" },
    swingRanged = { kind = "swing",  label = L["Ranged Swing"],    default = { point = "BOTTOM", x = 0, y = 250 }, textSize = 0,
                    swingType = SWING and SWING.Ranged, text = _G.SWING_TIMER_RANGED or "Ranged" },
    -- a paladin's seal and its time left, in the seal's own colour (section 10c)
    seal        = { kind = "seal",   label = L["Paladin Seals"],   default = { point = "CENTER", x = 0, y = -262 }, textSize = 0 },
    -- a flight path's progress (section 10b), shown only while you fly
    flight      = { kind = "flight", label = L["Flight Timer"],    default = { point = "BOTTOM", x = 0, y = 222 }, textSize = 0 },
}

-- Visibility (the action bars' Show conditions, Fade Group, Fade Speed, Faded Opacity, and Missing
-- Health on the health bar) is Visibility.lua's: elements rb_<key>, faded by alpha. The bars still show
-- and hide themselves where they don't apply, and a swing bar set to Only When In Use with its swings.
-- How long a bar in that mode outlasts a finished swing: the next one rarely lands on the same frame
local SWING_IN_USE_HOLD = 1.5
-- power and mana: the percent comes from the client's curve (UnitPowerPercent), so a secret power works
local POWER_TEXT_VALUES = {
    { text = L["Off"],     value = "none",    isRadio = true },
    { text = L["Value"],   value = "value",   isRadio = true },
    { text = L["Percent"], value = "percent", isRadio = true },
}
local TEXT_VALUES = {
    { text = L["Off"],             value = "none",    isRadio = true },
    { text = L["Percent"],         value = "percent", isRadio = true },
    { text = L["Percent | Value"], value = "both",    isRadio = true },
    { text = L["Value"],           value = "value",   isRadio = true },
    { text = L["Value [Max]"],     value = "valuemax", isRadio = true },
}

local bars = {}            -- key -> holder
local fsrStart             -- GetTime() of the last mana cast, while the five seconds run

--------------------------------------------------
-- 3. SETTINGS ACCESS
--------------------------------------------------
local function GetResourceDb()
    local db = K and K.GetDb()
    return db and db.resource
end

-- Classic combo gems: on in the ring styles, off in Addon Style
local function ClassicCombo()
    return ns.UFRing and ns.UFRing.On() and true or false
end

-- The health bar's class colours follow the player frame's switch
local function PlayerClassColors()
    local db = K.GetDb()
    return ns.ClassColorsOn(db and db.units and db.units.player)
end

-- Each bar's font (11-13): once per profile, every bar with text starts from the shared font plus its
-- old size step (textSize)
function RB.SeedFonts()
    local rdb = GetResourceDb()
    if not rdb or rawget(rdb, "barFontsSeeded") then return end
    rdb.barFontsSeeded = true
    local from = rdb.font
    if type(from) ~= "table" then return end
    for key, info in pairs(BARS) do
        local to = info.textSize and rdb.bars and rdb.bars[key] and rdb.bars[key].font
        if type(to) == "table" then
            for _, field in ipairs({ "face", "flags", "enableShadow", "shadowX", "shadowY" }) do
                if from[field] ~= nil then to[field] = from[field] end
            end
            to.size = (from.size or 10) + info.textSize
        end
    end
end

local function Cfg(key)
    local rdb = GetResourceDb()
    if not rdb then return nil end
    rdb.bars = rdb.bars or {}
    rdb.bars[key] = rdb.bars[key] or {}
    return rdb.bars[key]
end

-- The health bar's own Class Colours; until set it follows the player frame's
local function HealthClassColors()
    local cfg = Cfg("health")
    if cfg and cfg.classColor ~= nil then return cfg.classColor end
    return PlayerClassColors()
end

-- Low Health Colour: a red layer over the fill, its alpha from your health through a step curve
-- (health is secret, so no comparison in Lua): shown under LOW_HEALTH of your health
local LOW_HEALTH = { at = 0.3, color = { 0.85, 0.1, 0.1 } }

-- COLOUR PALETTE (Resource Bars' own, 11-11): FlareUI, Blizzard or Custom, as the unit frames' but
-- kept apart (unitframes.resource.palette; until set, the unit frames' choice). Custom keeps the
-- picked colours (customColors) over the palette it started from (customBase).
RB.COLOR_DEFAULTS = {
    low = { 0.85, 0.1, 0.1 }, combo = { ns.COMBO_COLOR[1], ns.COMBO_COLOR[2], ns.COMBO_COLOR[3] },
    swingMain = { 0.86, 0.65, 0.39 }, swingOff = { 0.72, 0.54, 0.32 }, swingRanged = { 0.45, 0.68, 0.40 },
    outOfRange = { 0.78, 0.28, 0.24 }, queued = { 1.00, 0.82, 0.25 }, waiting = { 0.45, 0.45, 0.45 },
    zone = { 1, 0.2, 0.15 }, flight = { 0.40, 0.62, 0.86 },
    -- the seals (Seals bar), each its own colour
    sealRighteousness = { 0.51, 0.875, 0.922 }, sealCrusader = { 1, 0.647, 0.459 }, sealCommand = { 0.969, 0.49, 0.133 }, sealJustice = { 0.62, 0.502, 0.302 }, sealLight = { 0.98, 0.816, 0.38 }, sealWisdom = { 0.098, 0.584, 1 }, sealFury = { 0.91, 0.224, 0 }, sealMartyrdom = { 0.65, 0.35, 0.85 },
}
local RBC = {}   -- the colours in use, key -> { r, g, b }
RB.colors = RBC

function RB.PaletteName()
    local rdb = GetResourceDb()
    local palette = rdb and rdb.palette
    if palette == nil then
        local uf = ns.db and ns.db.profile and ns.db.profile.unitframes
        palette = uf and uf.palette
        -- (the unit frames' Custom is theirs: Resource Bars follow the palette it started from)
        if palette == "custom" then palette = uf.customBase end
    end
    if palette ~= "blizzard" and palette ~= "custom" then palette = "flareui" end
    return palette
end

-- a palette's colour for a key: the unit frames' table for what they share, Resource Bars' own for the rest
function RB.PaletteColor(key, paletteName)
    local UF = ns.UnitFrames
    if key == "classHealth" then
        local _, class = UnitClass("player")
        return UF.PaletteColor("class:" .. (class or "WARRIOR"), paletteName)
    elseif key == "druidMana" then
        return UF.PaletteColor("mana", paletteName)
    end
    return RB.COLOR_DEFAULTS[key] or UF.PaletteColor(key, paletteName)
end

function RB.ApplyPalette()
    local UF = ns.UnitFrames
    if not (UF and UF.PaletteColor) then return end
    local rdb = GetResourceDb()
    local palette = RB.PaletteName()
    local base = palette == "custom" and (rdb and rdb.customBase == "blizzard" and "blizzard" or "flareui") or palette
    RB.palette, RB.basePalette = palette, base
    local custom = palette == "custom" and rdb and rdb.customColors or nil
    for _, key in ipairs({ "health", "classHealth", "low", "mana", "rage", "energy", "druidMana", "combo",
                           "swingMain", "swingOff", "swingRanged", "outOfRange", "queued", "waiting", "zone",
                           "heal", "absorb", "flight",
                           "sealRighteousness", "sealCrusader", "sealCommand", "sealJustice", "sealLight", "sealWisdom", "sealFury", "sealMartyrdom" }) do
        local own = custom and custom[key]
        local c = (type(own) == "table" and own[1]) and own or RB.PaletteColor(key, base)
        RBC[key] = RBC[key] or {}
        RBC[key][1], RBC[key][2], RBC[key][3] = c[1], c[2], c[3]
    end
    -- the tables the bars read
    for _, key in ipairs({ "combo", "swingMain", "swingOff", "swingRanged", "outOfRange", "queued", "waiting", "flight" }) do
        COLORS[key][1], COLORS[key][2], COLORS[key][3] = RBC[key][1], RBC[key][2], RBC[key][3]
    end
    LOW_HEALTH.color[1], LOW_HEALTH.color[2], LOW_HEALTH.color[3] = RBC.low[1], RBC.low[2], RBC.low[3]
end

-- the health bar's colour: your class with Class Colours, else the palette's health
function RB.HealthColor()
    local c = HealthClassColors() and RBC.classHealth or RBC.health
    if not c then return K.GetHealthColor("player", HealthClassColors()) end
    return c[1], c[2], c[3]
end

-- the power bar's colour: the palette's mana, rage or energy, else Blizzard's
local RB_POWER = { MANA = "mana", RAGE = "rage", ENERGY = "energy" }
function RB.PowerColor()
    local _, token = UnitPowerType("player")
    local key = canaccessvalue(token) and RB_POWER[token]
    local c = key and RBC[key]
    if c then return c[1], c[2], c[3] end
    return K.GetPowerColor("player")
end

local function DruidManaColor()
    local c = RBC.druidMana or ns.MANA_BLUE
    return c[1], c[2], c[3]
end
function LOW_HEALTH.Alpha()
    if not LOW_HEALTH.curve then
        LOW_HEALTH.curve = C_CurveUtil.CreateCurve()
        LOW_HEALTH.curve:SetType(Enum.LuaCurveType.Step)
        LOW_HEALTH.curve:AddPoint(0, 1)
        LOW_HEALTH.curve:AddPoint(LOW_HEALTH.at, 0)
    end
    return UnitHealthPercent("player", false, LOW_HEALTH.curve)
end
-- Lays the red layer over the bar's fill (a layout can replace the fill texture) and shows it
function LOW_HEALTH.Place(holder)
    local low, fill = holder.LowHealth, holder.Bar:GetStatusBarTexture()
    low:ClearAllPoints()
    low:SetAllPoints(fill)
    low.Tex:SetTexture(fill:GetTexture())
    local c = LOW_HEALTH.color
    low.Tex:SetVertexColor(c[1], c[2], c[3])
    low:Show()
end

local function IsEditing()
    -- Edit Mode with its samples; a fight in Edit Mode shows the live bars (ns.OnEditFight)
    return ns.EditPreviewing()
end

local function ClassFile()
    local _, class = UnitClass("player")
    return readable(class)
end

--------------------------------------------------
-- 4. AVAILABILITY (Edit Mode shows every bar)
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

-- Attack speeds are secret while unit stats are restricted: the last readable answer stands in;
-- with none yet the bar shows
local hasWeapon = {}
local function HasSwingWeapon(swingType)
    if not (SWING and swingType) then return false end
    if swingType ~= SWING.OffHand and swingType ~= SWING.Ranged then return true end
    local _, off, ranged = UnitAttackSpeed("player")
    local speed = swingType == SWING.OffHand and off or ranged
    if canaccessvalue(speed) then hasWeapon[swingType] = speed ~= nil and speed > 0 end
    if hasWeapon[swingType] == nil then return true end
    return hasWeapon[swingType]
end

local function IsAvailable(holder)
    local info = BARS[holder.key]
    if info.kind == "mana" then
        return ManaIsSecondary()
    elseif info.kind == "combo" then
        return BuildsComboPoints()
    elseif info.kind == "swing" then
        return HasSwingWeapon(info.swingType)
    elseif info.kind == "seal" then
        return ClassFile() == "PALADIN"
    end
    return true
end

-- Auto attack state, for the swing bars' Waiting State: melee from PLAYER_ENTER/LEAVE_COMBAT,
-- Auto Shot and wands from START/STOP_AUTOREPEAT_SPELL
RB.auto = { melee = false, ranged = false }
local function AutoAttacking(key)
    if key == "swingRanged" then return RB.auto.ranged end
    return RB.auto.melee
end

local function ShouldShow(holder)
    local cfg = Cfg(holder.key)
    if not cfg then return false end
    if IsEditing() then return true end
    -- the flight bar: only on a flight path
    if BARS[holder.key].kind == "flight" then return RB.Flight and RB.Flight.now and true or false end
    -- a swing proves the weapon, so no availability check (attack speeds can be secret); Waiting
    -- State keeps the bar up while auto attack is on
    if RB.InUse(holder.key) then
        return (holder.swingEnd or holder.swingHold or (cfg.waiting and AutoAttacking(holder.key))) and true or false
    end
    -- the Show conditions fade the bar (Visibility.lua)
    return IsAvailable(holder)
end

--------------------------------------------------
-- 5. UPDATERS
--------------------------------------------------
-- max: only the health bar's Value [Max] uses it (the unit frames' formats)
local function SetText(holder, mode, value, percent, max)
    K.FormatBarText(holder.Text, mode, value, percent, max)
end

local function UpdateHealPrediction(holder)
    local heal, absorb = holder.HealBar, holder.AbsorbBar
    if not heal then return end
    local max = UnitHealthMax("player")
    heal:SetMinMaxValues(0, max)
    absorb:SetMinMaxValues(0, max)
    K.SetOverAbsorb(holder.OverAbsorb, "player", max)
    local calc = holder.HealCalc
    if calc and UnitGetDetailedHealPrediction and pcall(UnitGetDetailedHealPrediction, "player", "player", calc) then
        local okH, incoming = pcall(calc.GetIncomingHeals, calc)
        local okA, absorbs, clamped = pcall(calc.GetDamageAbsorbs, calc)
        if okH then heal:SetValue(incoming) end
        if okA then absorb:SetValue(absorbs) end
        if okA then K.SetShieldGlow(holder.ShieldGlow, clamped) else K.HideShieldGlow(holder.ShieldGlow) end
        return
    end
    K.HideShieldGlow(holder.ShieldGlow)
    pcall(function() heal:SetValue(UnitGetIncomingHeals("player")) end)
    pcall(function() absorb:SetValue(UnitGetTotalAbsorbs("player")) end)
end

-- Max and colour are set by the full updates below (UNIT_MAXHEALTH, UNIT_MAXPOWER, a show, a
-- setting, Refresh); the ticks only set the value and text, as Blizzard's own player bars do.
-- holder.ready: a full update has run since the last Edit Mode preview (which sets its own max).
local function UpdateHealthValue(holder, glide)
    local cfg = Cfg("health")
    ns.SetBarValue(holder.Bar, UnitHealth("player"), glide and cfg and cfg.smoothBars)
    if UnitIsDeadOrGhost("player") then
        holder.Text:SetText(UnitIsGhost("player") and K.GHOST_TEXT or K.DEAD_TEXT)
    else
        SetText(holder, cfg.text or "both", UnitHealth("player"), UnitHealthPercent("player", true, K.percentCurve), UnitHealthMax("player"))
    end
    UpdateHealPrediction(holder)   -- the amounts are clamped by the health missing
    local low = holder.LowHealth
    if low and low:IsShown() and not pcall(low.SetAlpha, low, LOW_HEALTH.Alpha()) then low:SetAlpha(0) end
end

local function UpdateHealth(holder, glide)
    local bar = holder.Bar
    bar:SetMinMaxValues(0, UnitHealthMax("player"))
    bar:SetStatusBarColor(RB.HealthColor())
    holder.ready = true
    local cfg = Cfg("health")
    if holder.LowHealth then
        if cfg and cfg.lowHealth then LOW_HEALTH.Place(holder) else holder.LowHealth:Hide() end
    end
    UpdateHealthValue(holder, glide)
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

-- Value and text of the power or mana bar. UNIT_POWER_UPDATE and UNIT_POWER_FREQUENT often come
-- in the same frame (GetTime() does not move within one) with the same readable value: the second
-- would redo the same work. Secret values can't be compared, so those always update.
local function SetPowerValue(holder, powerType, glide, full)
    local cfg = Cfg(holder.key)
    local value = UnitPower("player", powerType)
    local now, v, t = GetTime(), readable(value), readable(powerType)
    if not full and v ~= nil and t ~= nil and holder.valueTime == now and holder.valueType == t and holder.lastValue == v then
        return
    end
    holder.valueTime, holder.valueType, holder.lastValue = now, t, v
    ns.SetBarValue(holder.Bar, value, glide and cfg and cfg.smoothBars)
    local mode = cfg.text or "value"
    local percent   -- may be secret
    if mode == "percent" then percent = UnitPowerPercent("player", powerType, false, K.percentCurve) end
    SetText(holder, mode, value, percent)
end

-- holder.powerType: the type the max and colour were set for, so a tick that finds another type
-- (or one it can't read) still runs in full
local function UpdatePower(holder, glide)
    local bar = holder.Bar
    local powerType = UnitPowerType("player")
    bar:SetMinMaxValues(0, UnitPowerMax("player", powerType))
    bar:SetStatusBarColor(RB.PowerColor())
    holder.ready, holder.powerType = true, readable(powerType)
    SetPowerValue(holder, powerType, glide, true)
    if holder.ManaCost then holder.ManaCost:Refresh(powerType) end
end

local function UpdatePowerValue(holder, glide)
    local powerType = UnitPowerType("player")
    local t = readable(powerType)
    if not holder.ready or t == nil or t ~= holder.powerType then
        UpdatePower(holder, glide)
        return
    end
    SetPowerValue(holder, powerType, glide)
end

local function UpdateMana(holder, glide)
    local bar = holder.Bar
    bar:SetMinMaxValues(0, UnitPowerMax("player", MANA))
    bar:SetStatusBarColor(DruidManaColor())
    holder.ready = true
    SetPowerValue(holder, MANA, glide, true)
    if holder.ManaCost then holder.ManaCost:Refresh(MANA) end
end

local function UpdateManaValue(holder, glide)
    if not holder.ready then
        UpdateMana(holder, glide)
        return
    end
    SetPowerValue(holder, MANA, glide)
end

-- Segment count; each segment is a bar from i - 1 to i fed the (possibly secret) point count
local function ComboCount()
    local max = readable(UnitPowerMax("player", COMBO_POWER))
    if not (max and max >= 1) then max = COMBO_FALLBACK end
    return math_min(max, COMBO_MAX)
end

local LayoutCombo   -- section 6

-- Classic gems animate, except right after a target change
local function UpdateCombo(holder)
    local count = ComboCount()
    if count ~= holder.count then
        holder.count = count
        LayoutCombo(holder)
    end
    local editing = IsEditing() or holder.fuiSample
    local points = editing and 3 or GetComboPoints("player", "target")
    if not ClassicCombo() then
        for i = 1, count do holder.segments[i]:SetValue(points) end
        return
    end
    local animate = holder.lastPoints ~= nil and not editing
    for i = 1, count do ns.SetComboPoint(holder.gems[i], points, animate) end
    holder.lastPoints = (not editing and readable(points)) or nil
end

-- The swing bar's colour: out of range, else Waiting State (idle, auto attack on), else Queued
-- Attack Colour, else its own
local function SwingColor(holder)
    local c = COLORS[holder.key]
    if holder.outOfRange then c = COLORS.outOfRange
    elseif holder.waiting then c = COLORS.waiting
    elseif holder.queued or holder.previewQueued then
        local cfg = Cfg(holder.key)
        if cfg and cfg.queueTint then c = COLORS.queued end
    end
    holder.Bar:SetStatusBarColor(c[1], c[2], c[3])
end

-- Stand-Still Zone (ranged bar): the swing's last half second, when Auto Shot and wands need you
-- standing still
local STAND_STILL = 0.5
local function SwingZone(holder)
    local zone = holder.StandStill
    if not zone then return end
    local cfg, d = Cfg(holder.key), holder.swingDuration
    if cfg and cfg.standStill and d and d > 0 then
        local z = RBC.zone
        if z then zone:SetColorTexture(z[1], z[2], z[3], 0.35) end
        zone:SetWidth(math_max(1, holder.Bar:GetWidth() * math_min(STAND_STILL / d, 1)))
        zone:Show()
    else
        zone:Hide()
    end
end

-- An idle swing bar: empty, or with Waiting State full and grey while auto attack is on
local function SwingIdle(holder)
    local cfg = Cfg(holder.key)
    holder.waiting = (cfg and cfg.waiting and AutoAttacking(holder.key)) and true or false
    holder.Bar:SetMinMaxValues(0, 1)
    holder.Bar:SetValue(holder.waiting and 1 or 0)
    holder.Text:SetText(holder.waiting and L["Waiting"] or "")
    holder.Spark:Hide()
    SwingZone(holder)
    SwingColor(holder)
end

local function SwingOnUpdate(holder)
    local remaining = holder.swingEnd - GetTime()
    if remaining <= 0 then
        holder.swingEnd, holder.swingDuration, holder.swingTenth = nil, nil, nil
        holder:SetScript("OnUpdate", nil)
        SwingIdle(holder)
        local cfg = Cfg(holder.key)
        if cfg and RB.InUse(holder.key) then
            holder.swingHold = C_Timer.NewTimer(SWING_IN_USE_HOLD, function()
                holder.swingHold = nil
                local now = Cfg(holder.key)
                if now and RB.InUse(holder.key) and not holder.swingEnd and not IsEditing()
                    and not (now.waiting and AutoAttacking(holder.key)) then
                    holder:Hide()
                end
            end)
        end
        return
    end
    holder.Bar:SetValue((holder.swingDuration - remaining) / holder.swingDuration)
    -- runs every frame: the text only when it changes
    local tenth = math.floor(remaining * 10)
    if tenth ~= holder.swingTenth then
        holder.swingTenth = tenth
        holder.Text:SetFormattedText("%.1f", remaining)
    end
end

local function StartSwing(holder, duration)
    duration = readable(duration)
    if not (duration and duration > 0) then return end
    if holder.swingHold then
        holder.swingHold:Cancel()
        holder.swingHold = nil
    end
    holder.swingDuration = duration
    holder.swingSpeed = duration   -- the weapon speed it started at (a haste change rescales from it)
    holder.swingEnd = GetTime() + duration
    holder.Bar:SetMinMaxValues(0, 1)
    holder.Bar:SetValue(0)
    holder.Spark:Show()
    holder.waiting = false
    SwingColor(holder)
    SwingZone(holder)
    holder:SetScript("OnUpdate", SwingOnUpdate)
end

local function SetSwingRange(holder, outOfRange)
    holder.outOfRange = outOfRange and true or false
    SwingColor(holder)
end

local function UpdateSwing(holder)
    local info = BARS[holder.key]
    if not holder.swingEnd then SwingIdle(holder) end
    holder.Label:SetText(info.text)
    -- Range Check (rangeCheck, on by default) off: the bar never takes the out-of-range colour
    local cfg = Cfg(holder.key)
    if info.swingType and not IsEditing() and not (cfg and cfg.rangeCheck == false) then
        -- Forever's own swing check answers nothing: the spell book's (Core.lua ns.TargetInRange)
        SetSwingRange(holder, ns.TargetInRange(info.swingType == (SWING and SWING.Ranged)) == false)
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
    elseif kind == "swing" then UpdateSwing(holder)
    elseif kind == "flight" and RB.Flight then RB.Flight.Update(holder)
    elseif kind == "seal" and RB.Seal then RB.Seal.Update(holder) end
end

-- Edit Mode sample values
local function ApplyPreview(holder)
    local kind = BARS[holder.key].kind
    local cfg = Cfg(holder.key)
    if kind == "combo" then
        UpdateCombo(holder)
        return
    end
    local bar = holder.Bar
    bar:SetMinMaxValues(0, 1)
    holder.ready = nil   -- the next update sets the real max and colour again
    if kind == "health" then
        -- Low Health Colour: the sample is low and red
        local low = cfg.lowHealth and holder.LowHealth
        bar:SetValue(low and 0.25 or 0.75)
        bar:SetStatusBarColor(RB.HealthColor())
        SetText(holder, cfg.text or "both", low and 6000 or 18000, low and 25 or 75, 24000)
        if holder.HealBar then holder.HealBar:SetValue(0); holder.AbsorbBar:SetValue(0); K.HideShieldGlow(holder.ShieldGlow); K.SetOverAbsorb(holder.OverAbsorb) end
        if holder.LowHealth then
            if low then
                LOW_HEALTH.Place(holder)
                low:SetAlpha(1)
            else
                holder.LowHealth:Hide()
            end
        end
    elseif kind == "power" then
        bar:SetValue(0.6)
        bar:SetStatusBarColor(RB.PowerColor())
        SetText(holder, cfg.text or "value", 60, 60)
        if holder.ManaCost then holder.ManaCost:Refresh(UnitPowerType("player")) end   -- the sample cost
        -- GCD Spark: a still sample
        if holder.Gcd then
            holder.Gcd.preview = cfg.gcd and true or nil
            holder.Gcd:SetShown(cfg.gcd and true or false)
        end
    elseif kind == "mana" then
        bar:SetValue(0.4)
        bar:SetStatusBarColor(DruidManaColor())
        SetText(holder, cfg.text or "value", 1600, 40)
        if holder.ManaCost then holder.ManaCost:Refresh(MANA) end
    elseif kind == "seal" then
        -- a sample Seal of Righteousness, half run out (the real seals' bars wait in their container)
        if RB.Seal then RB.Seal.Preview(holder) end
    elseif kind == "flight" then
        -- a sample flight two thirds of the way
        holder:SetScript("OnUpdate", nil)
        holder.Label:SetText(L["Flight Timer"])
        holder.Spark:Show()
        bar:SetValue(0.65)
        holder.Text:SetText("0:42")
        local c = COLORS.flight
        bar:SetStatusBarColor(c[1], c[2], c[3])
    elseif kind == "swing" then
        holder:SetScript("OnUpdate", nil)
        holder.swingEnd = nil
        holder.Spark:Show()
        holder.Label:SetText(BARS[holder.key].text)
        holder.waiting = cfg.waiting and true or false
        holder.previewQueued = (holder.key == "swingMain" and cfg.queueTint) and true or nil
        if holder.waiting then
            bar:SetValue(1)
            holder.Spark:Hide()
            holder.Text:SetText(L["Waiting"])
        else
            bar:SetValue(0.6)
            holder.Text:SetText("1.4")
        end
        SetSwingRange(holder, false)
        -- Stand-Still Zone on a sample 2.5 s swing
        if holder.StandStill then
            if cfg.standStill and not holder.waiting then
                holder.StandStill:SetWidth(math_max(1, bar:GetWidth() * STAND_STILL / 2.5))
                holder.StandStill:Show()
            else
                holder.StandStill:Hide()
            end
        end
    end
end

local function ApplyShown(holder)
    local show = ShouldShow(holder)
    holder:SetShown(show)
    if not IsEditing() then
        -- the samples' extras go with Edit Mode
        holder.previewQueued = nil
        if holder.Gcd and holder.Gcd.preview then holder.Gcd.preview = nil holder.Gcd:Hide() end
    end
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

-- Target and combat edges: only which bars show can change. A health, power or mana bar already up
-- keeps its values (and a Smooth Bars glide in flight); one that just came up gets a full update.
-- The swing bars (range on the new target) and the combo points (newTarget) always update.
local function ApplyAllVisibility(newTarget)
    for _, key in ipairs(BAR_ORDER) do
        local holder = bars[key]
        if holder then
            local kind = BARS[key].kind
            local was = holder:IsShown()
            if kind == "swing" or kind == "flight" or kind == "seal" or (kind == "combo" and newTarget) or not was then
                ApplyShown(holder)
            else
                holder:SetShown(ShouldShow(holder))
            end
        end
    end
    UpdateFsrSpark()
end

--------------------------------------------------
-- 6. LAYOUT
--------------------------------------------------
-- FlareUI Thin keeps the full inset at any height; other borders are fitted to thin bars (BorderFit)
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

-- Classic gems in a row, no backdrop or border
local function LayoutClassicCombo(holder, cfg, count)
    local size = cfg.classicSize or (cfg.height or 12) * 2
    local spacing = ns.ComboPointStep(size)
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
    local classic = ClassicCombo()
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
        K.SetBarBackground(seg, cfg.bgOpacity)
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
    local info = BARS[holder.key]
    local kind = info.kind
    local PADDING = BarPadding(cfg, cfg.height or 14)
    ApplyFrameLook(holder, cfg)
    -- the bar's own font (Edit Mode > Fonts)
    RB.SeedFonts()
    local font = cfg.font

    if kind == "combo" then
        holder.count = ComboCount()
        LayoutCombo(holder)
        return
    end

    local bar = holder.Bar
    local texture = K.GetBarTexture(cfg.texture)
    bar:SetStatusBarTexture(texture)
    bar.bg:SetTexture(texture)
    K.SetBarBackground(bar, cfg.bgOpacity)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", holder, "TOPLEFT", PADDING, -PADDING)
    bar:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -PADDING, PADDING)

    K.ApplyFont(holder.Text, font)
    holder.Text:ClearAllPoints()
    if kind == "swing" or kind == "flight" or kind == "seal" then
        K.ApplyFont(holder.Label, font)
        holder.Label:ClearAllPoints()
        holder.Label:SetPoint("LEFT", bar, "LEFT", K.TEXT_INSET, 0)
        holder.Text:SetPoint("RIGHT", bar, "RIGHT", -K.TEXT_INSET, 0)
        holder.Text:SetJustifyH("RIGHT")
        -- Bar Text and Timer (Look): each text can go
        holder.Label:SetShown(cfg.showLabel ~= false)
        holder.Text:SetShown(cfg.showTimer ~= false)
        local spark = holder.Spark
        spark:ClearAllPoints()
        spark:SetSize(math_max(8, (cfg.height or 10)), math_max(18, (cfg.height or 10) * 2.2))
        spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", 0, 0)
    else
        holder.Text:SetJustifyH("CENTER")
        holder.Text:SetPoint("CENTER", bar, "CENTER", 0, 0)
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
        -- (the heal bar keeps its own texture and colour, set at creation: a new texture would drop the colour)
        absorb:ClearAllPoints()
        absorb:SetWidth(width)
        -- after the health and the incoming heals, as Blizzard's frames draw shields (UnitFrames.lua)
        absorb:SetReverseFill(false)
        local healFill = heal:GetStatusBarTexture()
        absorb:SetPoint("TOPLEFT", healFill, "TOPRIGHT", 0, 0)
        absorb:SetPoint("BOTTOMLEFT", healFill, "BOTTOMRIGHT", 0, 0)
        K.PlaceShieldGlow(holder.ShieldGlow, bar, false)
        absorb:SetStatusBarTexture(K.GetBarTexture(K.ABSORB_TEXTURE))
        local a, h = RBC.absorb or K.ABSORB_COLOR, RBC.heal or K.HEAL_COLOR
        absorb:SetStatusBarColor(a[1], a[2], a[3], K.ABSORB_COLOR[4])
        heal:SetStatusBarColor(h[1], h[2], h[3], K.HEAL_COLOR[4])
        -- the shield with no room after the health, over it (UnitFrames.lua UF.CreateOverAbsorb)
        K.PlaceOverAbsorb(holder.OverAbsorb, bar, width, false, K.GetBarTexture(K.ABSORB_TEXTURE))
    end
    if kind == "seal" and RB.Seal then RB.Seal.Layout(holder, cfg, font) end
end

--------------------------------------------------
-- 7. POSITION (per Edit Mode layout)
--------------------------------------------------
local function GetLayoutStore(layoutName)
    local rdb = GetResourceDb()
    if not rdb then return nil end
    layoutName = layoutName or LEM:GetActiveLayoutName() or "Modern"
    rdb.layouts = rdb.layouts or {}
    -- (a layout with no spot of its own reads the profile's home layout's: ProfileLayout.lua)
    return ns.LayoutHome(rdb.layouts, layoutName)
end

local function ApplyPosition(holder, layoutName)
    local store = GetLayoutStore(layoutName)
    local pos = (store and store[holder.key]) or BARS[holder.key].default
    holder:ClearAllPoints()
    holder:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or 0, pos.y or 0)
end

-- flush: the borders overlap by a pixel
local SNAP_DISTANCE, SNAP_GAP, SNAP_ALIGN = 10, -1, 30

-- FlareEditMode's snapper while dragging: the centre that puts this bar flush above or below the
-- nearest other bar (edges within SNAP_DISTANCE, centres within SNAP_ALIGN sideways)
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
-- parent: a settings preview's sample (no name, not in bars, shows the Edit Mode sample values)
local function CreateHolder(key, parent)
    local info = BARS[key]
    local holder = CreateFrame("Frame", not parent and ("FlareUI_Resource_" .. key) or nil, parent or UIParent)
    holder.key = key
    holder.fuiSample = parent and true or nil
    -- (a preview's sample stays in its parent's strata and above it)
    if not parent then
        holder:SetFrameStrata("MEDIUM")
        holder:SetClampedToScreen(true)
        holder.editModeName = "FlareUI " .. info.label
        for index, k in ipairs(BAR_ORDER) do
            if k == key then holder:SetFrameLevel(10 + (#BAR_ORDER - index) * 10) end
        end
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
        holder.ShieldGlow = K.CreateShieldGlow(holder.Bar, clip)
        holder.OverAbsorb = K.CreateOverAbsorb(holder.Bar, clip)
        -- Low Health Colour: on its own frame (its alpha may be secret; a texture's would not draw)
        local low = CreateFrame("Frame", nil, holder.Bar)
        low:SetFrameLevel(holder.Bar:GetFrameLevel() + 1)
        low.Tex = low:CreateTexture(nil, "ARTWORK")
        low.Tex:SetAllPoints()
        low:Hide()
        holder.LowHealth = low
        if CreateUnitHealPredictionCalculator then
            local ok, calc = pcall(CreateUnitHealPredictionCalculator)
            if ok and calc then holder.HealCalc = calc end
        end
    end

    if info.kind == "power" or info.kind == "mana" then
        -- the mana a spell being cast will cost, shaded at the fill's end (as on the player frame)
        holder.ManaCost = K.CreateManaCost(holder.Bar, function()
            if IsEditing() or holder.fuiSample then return 0.15 end   -- the Edit Mode sample (the bar runs 0 to 1 then)
            return RB.manaCost
        end, function()
            if info.kind == "mana" then return DruidManaColor() end
            return RB.PowerColor()
        end)
    end

    if info.kind == "power" then
        -- GCD Spark: crosses the bar during the global cooldown
        local gcd = CreateFrame("Frame", nil, holder.Bar)
        gcd:SetAllPoints(holder.Bar)
        gcd:SetFrameLevel(holder.Bar:GetFrameLevel() + 2)
        gcd:Hide()
        local spark = gcd:CreateTexture(nil, "OVERLAY")
        spark:SetTexture(FSR_SPARK)
        spark:SetBlendMode("ADD")
        spark:SetVertexColor(1, 0.85, 0.4)
        gcd.Spark = spark
        gcd:SetScript("OnShow", function(self)
            local h = holder.Bar:GetHeight()
            self.Spark:SetSize(math_max(h, 8), math_max(h * 2.2, 18))
        end)
        gcd:SetScript("OnUpdate", function(self)
            if self.preview then   -- Edit Mode: a still spark
                self.Spark:SetPoint("CENTER", holder.Bar, "LEFT", holder.Bar:GetWidth() * 0.4, 0)
                return
            end
            local elapsed = RB.gcdStart and (GetTime() - RB.gcdStart)
            if not elapsed or elapsed >= RB.gcdDuration then
                self:Hide()
                return
            end
            self.Spark:SetPoint("CENTER", holder.Bar, "LEFT", holder.Bar:GetWidth() * elapsed / RB.gcdDuration, 0)
        end)
        holder.Gcd = gcd
    end

    if info.kind == "power" or info.kind == "mana" then
        -- "Five-Second Rule": a spark crosses the bar for five seconds after a mana cast
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

    if info.kind == "swing" or info.kind == "flight" or info.kind == "seal" then
        holder.Label = overlay:CreateFontString(nil, "OVERLAY")
        holder.Label:SetJustifyH("LEFT")
        holder.Spark = holder.Bar:CreateTexture(nil, "OVERLAY")
        holder.Spark:SetTexture(SWING_SPARK)
        holder.Spark:SetBlendMode("ADD")
        holder.Spark:Hide()
        if key == "swingRanged" then
            holder.StandStill = holder.Bar:CreateTexture(nil, "ARTWORK", nil, 3)
            holder.StandStill:SetColorTexture(1, 0.2, 0.15, 0.35)
            holder.StandStill:SetPoint("TOPRIGHT", holder.Bar, "TOPRIGHT")
            holder.StandStill:SetPoint("BOTTOMRIGHT", holder.Bar, "BOTTOMRIGHT")
            holder.StandStill:Hide()
        end
    end

    holder:Hide()
    if not parent then bars[key] = holder end
    return holder
end

-- a settings preview's sample of a bar: its own build, layout and Edit Mode values
function RB.CreateSample(parent, key)
    if not BARS[key] then return nil end
    return CreateHolder(key, parent)
end
function RB.DrawSample(holder)
    LayoutBar(holder)
    ApplyPreview(holder)
    holder:Show()
    return holder:GetWidth(), holder:GetHeight()
end

--------------------------------------------------
-- 9. EDIT MODE SETTINGS
--------------------------------------------------
local function Relayout(key)
    local holder = bars[key]
    if not holder then return end
    LayoutBar(holder)
    ApplyShown(holder)
    UpdateFsrSpark()
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
    -- classic gems have one "Size"; width and height apply to the bar style
    local function classicOn() return info.kind == "combo" and ClassicCombo() end
    local function classicOff() return not classicOn() end
    local frameItems = {
        { name = L["Width"], kind = LEM.SettingType.Slider, default = defaults.width or 220, minValue = 40, maxValue = 600, valueStep = 2, get = get("width", 220), set = set("width"), hidden = classicOn },
        { name = L["Height"], kind = LEM.SettingType.Slider, default = defaults.height or 14, minValue = 4, maxValue = 48, valueStep = 1, get = get("height", defaults.height or 14), set = set("height"), hidden = classicOn },
    }
    local function add(item) frameItems[#frameItems + 1] = item end
    if info.kind == "combo" then
        add({ name = L["Size"], kind = LEM.SettingType.Slider, default = 24, minValue = 12, maxValue = 48, valueStep = 1,
              get = get("classicSize", 24), set = set("classicSize"), hidden = classicOff })
    end
    if info.kind == "power" or info.kind == "mana" then
        add({ name = L["Text"], kind = LEM.SettingType.Dropdown, default = defaults.text or "value", values = POWER_TEXT_VALUES,
              get = get("text", defaults.text or "value"), set = set("text") })
    end
    if info.kind == "health" then
        add({ name = L["Text"], kind = LEM.SettingType.Dropdown, default = defaults.text or "both", values = TEXT_VALUES, get = get("text", defaults.text or "both"), set = set("text") })
    end
    if info.kind == "power" or info.kind == "mana" then
        add({ name = L["Five-Second Rule"], kind = LEM.SettingType.Checkbox, default = false, get = get("fsr", false), set = set("fsr"),
              desc = L["A spark crosses the bar for five seconds after a spell that costs mana: spirit regen comes back when it ends."] })
    end
    -- at the bottom of Frame: each bar's own extras (off by default)
    if key == "power" then
        add({ name = L["GCD Spark"], kind = LEM.SettingType.Checkbox, default = false, get = get("gcd", false), set = set("gcd"),
              desc = L["A spark crosses the bar during the global cooldown."] })
    end
    if key == "swingRanged" then
        add({ name = L["Stand-Still Zone"], kind = LEM.SettingType.Checkbox, default = false, get = get("standStill", false), set = set("standStill"),
              desc = L["Marks the swing's last half second: Auto Shot and wands need you standing still then."] })
    end
    if key == "swingMain" then
        add({ name = L["Queued Attack Colour"], kind = LEM.SettingType.Checkbox, default = false, get = get("queueTint", false), set = set("queueTint"),
              desc = L["The bar turns gold while Heroic Strike, Cleave, Maul or Raptor Strike waits for the next swing."] })
    end
    if info.kind == "swing" then
        add({ name = L["Waiting State"], kind = LEM.SettingType.Checkbox, default = false, get = get("waiting", false), set = set("waiting"),
              desc = L["With auto attack on but no swing running (the target out of reach), the bar shows full and grey, saying Waiting."] })
    end
    -- classic gems have no Look
    local Section, settings = K.EditSections()
    Section("Frame", frameItems)
    Section("Look", {
        { name = L["Bar Texture"], kind = LEM.SettingType.Dropdown, default = defaults.texture or K.DEFAULT_TEXTURE,
          values = K.BuildTextureValues(), get = get("texture", defaults.texture or K.DEFAULT_TEXTURE), set = set("texture"), hidden = classicOn },
        { name = L["Border"], kind = LEM.SettingType.Dropdown, default = defaults.border or DEFAULT_BAR_BORDER,
          values = K.BuildBorderValues(false), get = get("border", defaults.border or DEFAULT_BAR_BORDER), set = set("border"), hidden = classicOn },
        (function()
            local item = K.BgOpacitySetting(K.BAR_BG_OPACITY, get("bgOpacity", K.BAR_BG_OPACITY), set("bgOpacity"))
            item.hidden = classicOn
            return item
        end)(),
        -- the health bar: Class Colours (until set, the player frame's), then Low Health Colour
        (function()
            local item = K.ClassColorSetting(HealthClassColors, set("classColor"))
            item.hidden = function() return info.kind ~= "health" end
            return item
        end)(),
        { name = L["Low Health Colour"], kind = LEM.SettingType.Checkbox, default = false, get = get("lowHealth", false), set = set("lowHealth"),
          desc = L["The bar turns red while your health is under 30%."],
          hidden = function() return info.kind ~= "health" end },
        -- the swing timers: the out-of-range colour, as the unit frames' range fading
        { name = L["Range Check"], kind = LEM.SettingType.Checkbox, default = true, get = get("rangeCheck", true), set = set("rangeCheck"),
          desc = L["The bar turns red while your target is out of reach of this attack. Off, it keeps its colour."],
          hidden = function() return info.kind ~= "swing" end },
        -- the swing timers' two texts, each on its own (11-11, a player's request)
        { name = L["Bar Text"], kind = LEM.SettingType.Checkbox, default = true, get = get("showLabel", true), set = set("showLabel"),
          desc = info.kind == "flight" and L["Where you're flying, on the left of the bar."]
              or info.kind == "seal" and L["The seal's name on the left of the bar."] or L["The swing's name on the left of the bar."],
          hidden = function() return info.kind ~= "swing" and info.kind ~= "flight" and info.kind ~= "seal" end },
        { name = L["Timer"], kind = LEM.SettingType.Checkbox, default = true, get = get("showTimer", true), set = set("showTimer"),
          desc = info.kind == "flight" and L["The time left on the right of the bar. A route you haven't flown yet counts up while it's learned."]
              or info.kind == "seal" and L["The seal's time left on the right of the bar."]
              or L["The seconds left on the right of the bar (and Waiting)."],
          hidden = function() return info.kind ~= "swing" and info.kind ~= "flight" and info.kind ~= "seal" end },
        (function()
            -- only the bars that hold a value: combo points are steps, swing timers already run smoothly
            local item = K.SmoothBarsSetting(get("smoothBars", false), set("smoothBars"))
            item.hidden = function() return info.kind ~= "health" and info.kind ~= "power" and info.kind ~= "mana" end
            return item
        end)(),
    })
    -- last: Fade Group, Visibility, Fade Speed and Faded Opacity, as on the action bars (Visibility.lua)
    if ns.Visibility and ns.Visibility.ResourceBarSettings then
        Section("Fading", ns.Visibility:ResourceBarSettings(key))
    end
    -- always last: the bar's text font (11-13); Apply to All: every bar with text takes it
    if info.textSize then
        Section("Fonts", ns.EditFonts({
            id = "rb." .. key, group = "rb",
            texts = { { key = "font", name = L["Bar Text"] } },
            font = function() RB.SeedFonts(); local cfg = Cfg(key); return cfg and cfg.font end,
            default = function() return defaults.font end,
            apply = function() RB:Refresh() end,
            all = { text = L["Apply to All"], desc = L["Every resource bar takes this bar's font."],
                    run = function()
                        local from = Cfg(key)
                        from = from and from.font
                        if not from then return end
                        for other, otherInfo in pairs(BARS) do
                            local to = other ~= key and otherInfo.textSize and Cfg(other)
                            to = to and to.font
                            if to then
                                for _, field in ipairs({ "face", "size", "flags", "enableShadow", "shadowX", "shadowY" }) do to[field] = from[field] end
                            end
                        end
                        RB:Refresh()
                    end },
        }))
    end
    return settings
end

--------------------------------------------------
-- 10. EVENTS
--------------------------------------------------
-- one list for every swing event, not a new table per swing
local SWING_KEYS = { "swingMain", "swingOff", "swingRanged" }

-- the range has no event that comes (PLAYER_SWING_RANGE_UPDATE never fires on Forever): asked again
-- four times a second for each swing bar on screen, recoloured only when it changes
local swingRangeTicker
local function PollSwingRange()
    for _, key in ipairs(SWING_KEYS) do
        local holder = bars[key]
        if holder and holder:IsShown() and not IsEditing() then
            local cfg = Cfg(key)
            local out = not (cfg and cfg.rangeCheck == false)
                and ns.TargetInRange(BARS[key].swingType == (SWING and SWING.Ranged)) == false
            if out ~= (holder.outOfRange or false) then SetSwingRange(holder, out) end
        end
    end
end

local function EnableSwingRange()
    if not swingRangeTicker and (bars.swingMain or bars.swingOff or bars.swingRanged) then
        swingRangeTicker = C_Timer.NewTicker(0.25, PollSwingRange)
    end
    if not (C_SwingTimer and C_SwingTimer.EnableRangeCheck) then return end
    for _, key in ipairs(SWING_KEYS) do
        local info = BARS[key]
        if info.swingType and bars[key] then
            pcall(C_SwingTimer.EnableRangeCheck, info.swingType, true)
        end
    end
end

-- A weapon swap restarts a running swing at the new weapon's speed (as Blizzard's timer does), and
-- ends it when that hand has no weapon any more
local function RestartSwings()
    local main, off, ranged = UnitAttackSpeed("player")
    for _, key in ipairs(SWING_KEYS) do
        local holder, swingType = bars[key], BARS[key].swingType
        if holder and holder.swingEnd then
            if HasSwingWeapon(swingType) then
                local speed = swingType == SWING.OffHand and off or (swingType == SWING.Ranged and ranged or main)
                StartSwing(holder, speed)   -- an unreadable speed leaves the old swing running
            else
                holder.swingEnd = GetTime()   -- SwingOnUpdate clears the bar on its next frame
            end
        end
    end
end

-- Classic swing rules the server applies with no swing event of its own (the next PLAYER_SWING
-- corrects the bar anyway):
-- * haste gained or lost mid-swing (Flurry, Slice and Dice, Rapid Fire) scales the time left by
--   new speed / old speed; only when both speeds can be read
local function RescaleSwings()
    local main, off, ranged = UnitAttackSpeed("player")
    local now = GetTime()
    for _, key in ipairs(SWING_KEYS) do
        local holder, swingType = bars[key], BARS[key].swingType
        if holder and holder.swingEnd and holder.swingSpeed then
            local new = readable(swingType == SWING.OffHand and off or (swingType == SWING.Ranged and ranged or main))
            local old = holder.swingSpeed
            if new and new > 0 and math.abs(new - old) > 0.001 then
                local ratio = new / old
                holder.swingEnd = now + (holder.swingEnd - now) * ratio
                holder.swingDuration = holder.swingDuration * ratio
                holder.swingSpeed = new
                SwingZone(holder)
            end
        end
    end
end

-- * a parry hastens your next main-hand swing: 40% of the speed off while more than 60% is left,
--   else down to 20% of the speed
local function ParryHaste()
    local holder = bars.swingMain
    if not (holder and holder.swingEnd and holder.swingSpeed) then return end
    local now, speed = GetTime(), holder.swingSpeed
    local remaining = holder.swingEnd - now
    if remaining > 0.6 * speed then
        holder.swingEnd = holder.swingEnd - 0.4 * speed
    elseif remaining > 0.2 * speed then
        holder.swingEnd = now + 0.2 * speed
    end
end

-- * finishing a spell with a cast time (Slam, a heal, Aimed Shot) restarts the swing; Auto Shot is
--   the ranged swing itself
local AUTO_SHOT = 75

-- Queued Attack Colour (main-hand bar): an on-next-swing attack is queued
local QUEUED_SPELLS = { 78, 845, 6807, 2973 }   -- Heroic Strike, Cleave, Maul, Raptor Strike (by name: every rank)
local function UpdateQueued()
    local holder = bars.swingMain
    if not holder then return end
    local cfg, on = Cfg("swingMain"), false
    if cfg and cfg.queueTint and C_Spell.IsCurrentSpell then
        for _, id in ipairs(QUEUED_SPELLS) do
            local name = C_Spell.GetSpellName(id)
            if name and readable(C_Spell.IsCurrentSpell(name)) then on = true break end
        end
    end
    if on ~= holder.queued then
        holder.queued = on
        SwingColor(holder)
    end
end

-- GCD Spark (power bar): the global cooldown, read from a spell that only has the GCD; only when
-- its times can be read
local GCD_SPELLS = { 29515, 61304 }
local function UpdateGcd()
    local power = bars.power
    local cfg = Cfg("power")
    if not (power and power.Gcd and power:IsShown() and cfg and cfg.gcd) then return end
    for _, id in ipairs(GCD_SPELLS) do
        local info = C_Spell.GetSpellCooldown(id)
        local start, duration = info and readable(info.startTime), info and readable(info.duration)
        if start and duration and duration > 0 and duration <= 2 then
            RB.gcdStart, RB.gcdDuration = start, duration
            power.Gcd:Show()
            return
        end
    end
end

-- Mana cost preview on the power and mana bars: the cost of the spell being cast
local function RefreshManaCost()
    local power, mana = bars.power, bars.mana
    if power and power.ManaCost and power:IsShown() then power.ManaCost:Refresh(UnitPowerType("player")) end
    if mana and mana.ManaCost and mana:IsShown() then mana.ManaCost:Refresh(MANA) end
end

-- no cast running any more: the preview goes (a secret name still means a cast)
local function ClearManaCostIfDone()
    local name = UnitCastingInfo("player")
    if not canaccessvalue(name) or name ~= nil then return end
    if canaccessvalue(RB.manaCost) and RB.manaCost == nil then return end
    RB.manaCost = nil
    RefreshManaCost()
end

function RB:OnEvent(event, arg1, arg2, arg3)
    -- the auto attack state is kept in Edit Mode too, for the bars after it
    if event == "PLAYER_ENTER_COMBAT" or event == "PLAYER_LEAVE_COMBAT" then
        RB.auto.melee = event == "PLAYER_ENTER_COMBAT"
    elseif event == "START_AUTOREPEAT_SPELL" or event == "STOP_AUTOREPEAT_SPELL" then
        RB.auto.ranged = event == "START_AUTOREPEAT_SPELL"
    end
    if IsEditing() then return end
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        if bars.health and bars.health:IsShown() then
            if event == "UNIT_MAXHEALTH" or not bars.health.ready then UpdateHealth(bars.health, true)
            else UpdateHealthValue(bars.health, true) end
        end
    elseif event == "UNIT_HEAL_PREDICTION" or event == "UNIT_ABSORB_AMOUNT_CHANGED" then
        if bars.health and bars.health:IsShown() then UpdateHealPrediction(bars.health) end
    elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER" then
        local maxChange = event == "UNIT_MAXPOWER"
        -- arg2 is the changed power's token: each bar takes only its own power (a cat's energy bar
        -- skips mana regen, the combo bar skips energy), as Blizzard's class power bars do; with no
        -- readable token every bar updates
        local token = readable(arg2)
        if bars.power and bars.power:IsShown() then
            local _, own = UnitPowerType("player")
            if token == nil or own == nil or token == own then
                if maxChange then UpdatePower(bars.power, true) else UpdatePowerValue(bars.power, true) end
            end
        end
        if bars.mana and bars.mana:IsShown() and (token == nil or token == "MANA") then
            if maxChange then UpdateMana(bars.mana, true) else UpdateManaValue(bars.mana, true) end
        end
        if bars.combo and bars.combo:IsShown() and (token == nil or token == "COMBO_POINTS") then
            UpdateCombo(bars.combo)
        end
    elseif event == "UNIT_DISPLAYPOWER" then
        -- a shapeshift: the mana and combo bars come or go
        ApplyAllShown()
    elseif event == "UNIT_SPELLCAST_START" then
        -- a cast with a cast time (instants fire no START): the swing restarts when it lands
        RB.castingSpell = readable(arg3)
        local costs, amount = K.CostsMana(arg3)
        -- (no "and/or" here: the amount may be secret, and that would test it)
        if costs then RB.manaCost = amount else RB.manaCost = nil end
        RefreshManaCost()
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED" then
        if event == "UNIT_SPELLCAST_INTERRUPTED" then RB.castingSpell = nil end
        ClearManaCostIfDone()
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        UpdateGcd()
    elseif event == "CURRENT_SPELL_CAST_CHANGED" or event == "ACTIONBAR_UPDATE_STATE" then
        UpdateQueued()
    elseif event == "PLAYER_ENTER_COMBAT" or event == "PLAYER_LEAVE_COMBAT"
        or event == "START_AUTOREPEAT_SPELL" or event == "STOP_AUTOREPEAT_SPELL" then
        for _, key in ipairs(SWING_KEYS) do
            if bars[key] then ApplyShown(bars[key]) end
        end
    elseif event == "UNIT_COMBAT" then
        if readable(arg2) == "PARRY" then ParryHaste() end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local spellID = arg3
        ClearManaCostIfDone()
        local hardCast = RB.castingSpell
        RB.castingSpell = nil
        if hardCast and canaccessvalue(spellID) and spellID == hardCast and spellID ~= AUTO_SHOT then
            RestartSwings()
        end
        if not (bars.power or bars.mana) then return end
        if not (canaccessvalue(spellID) and spellID) then return end
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
        for _, key in ipairs(SWING_KEYS) do
            local holder = bars[key]
            if holder and BARS[key].swingType == swingType then
                StartSwing(holder, duration)
                -- Only When In Use: a hidden bar's OnUpdate would not run
                if not holder:IsShown() then ApplyShown(holder) end
            end
        end
    elseif event == "PLAYER_SWING_RANGE_UPDATE" then
        local swingType, isInRange, checksRange = arg1, arg2, arg3
        for _, key in ipairs(SWING_KEYS) do
            local holder = bars[key]
            if holder and BARS[key].swingType == swingType then
                SetSwingRange(holder, readable(checksRange) and readable(isInRange) == false)
            end
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        if bars.combo then bars.combo.lastPoints = nil end   -- the new target's points do not animate
        -- Blizzard's own (hidden) swing timers still get events and can turn the shared range check
        -- off: it is turned back on with each target
        EnableSwingRange()
        ApplyAllVisibility(true)
    elseif event == "PLAYER_DEAD" then
        -- no swing runs on a corpse: SwingOnUpdate clears each bar on its next frame
        for _, key in ipairs(SWING_KEYS) do
            local holder = bars[key]
            if holder and holder.swingEnd then holder.swingEnd = GetTime() end
        end
    elseif event == "COMBO_TARGET_CHANGED" then
        -- points moved to a new target keep their count, so no power event fires (Forever's own
        -- combo bar listens for this too)
        if bars.combo and bars.combo:IsShown() then UpdateCombo(bars.combo) end
    elseif event == "UNIT_INVENTORY_CHANGED" or event == "UNIT_ATTACK_SPEED" or event == "WEAPON_SLOT_CHANGED" then
        -- gear and attack speed only touch the swing bars (looting fires UNIT_INVENTORY_CHANGED often)
        if event == "WEAPON_SLOT_CHANGED" then
            RestartSwings()
            EnableSwingRange()
        elseif event == "UNIT_ATTACK_SPEED" then
            RescaleSwings()
        end
        for _, key in ipairs(SWING_KEYS) do
            if bars[key] then ApplyShown(bars[key]) end
        end
    else
        -- combat, entering the world: any bar may come or go
        if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_DISABLED" then EnableSwingRange() end
        if event == "PLAYER_ENTERING_WORLD" then ApplyAllShown() else ApplyAllVisibility(false) end
    end
end

local UNIT_EVENTS = {
    "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_HEAL_PREDICTION", "UNIT_ABSORB_AMOUNT_CHANGED",
    "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
    "UNIT_SPELLCAST_SUCCEEDED", "UNIT_ATTACK_SPEED", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_COMBAT",
    "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
    "UNIT_INVENTORY_CHANGED",   -- as Blizzard's swing timers: the weapon events miss the login
}
local EVENTS = {
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD",
    "PLAYER_SWING", "PLAYER_SWING_RANGE_UPDATE", "WEAPON_SLOT_CHANGED", "PLAYER_IN_COMBAT_CHANGED",
    "COMBO_TARGET_CHANGED",   -- Forever: points moved to a new target (no power event)
    "PLAYER_DEAD",
    "SPELL_UPDATE_COOLDOWN", "CURRENT_SPELL_CAST_CHANGED", "ACTIONBAR_UPDATE_STATE",
    "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT", "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL",
    -- the In a group and Not mounted Show conditions (flight paths: control lost and gained)
    "GROUP_ROSTER_UPDATE", "PLAYER_MOUNT_DISPLAY_CHANGED", "UPDATE_SHAPESHIFT_FORM", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED",
}

--------------------------------------------------
-- 10b. FLIGHT TIMER (11-11, Marcus; the idea after Leatrix Plus, nothing taken)
-- Forever tells no flight's length, so each route is learned: the first flight counts up, landing
-- keeps its time (account-wide, db.global.flightTimes, "From > To" by the nodes' names), and every
-- later flight fills the bar with the time left. A flight is caught as it is picked (TakeTaxiNode on
-- the flight map) and timed from take-off (UnitOnTaxi) to landing. Not kept: a flight left early
-- (TaxiRequestEarlyLanding), one under 10 seconds, or one not caught from the start (a login in the
-- air without the record a reload leaves). Hovering a destination on the flight map adds its time.
--------------------------------------------------
local Flight = {}
RB.Flight = Flight
local FLIGHT_MIN = 10           -- shorter flights are not kept
local FLIGHT_CATCH = 15         -- seconds after the pick for take-off
local FLIGHT_RESUME = 3600      -- a reload's record older than this is dropped

local function FlightStore()
    local global = ns.db and ns.db.global
    if not global then return {} end
    global.flightTimes = global.flightTimes or {}
    return global.flightTimes
end

local function Clock(seconds)
    seconds = math_max(0, math_floor(seconds + 0.5))
    return string.format("%d:%02d", math_floor(seconds / 60), seconds % 60)
end
Flight.Clock = Clock

-- the flight map's node you stand at, and a route's key
local function HereName()
    if not (NumTaxiNodes and TaxiNodeGetType) then return nil end
    for i = 1, NumTaxiNodes() do
        if TaxiNodeGetType(i) == "CURRENT" then return TaxiNodeName(i) end
    end
end
local function RouteKey(from, to) return from .. " > " .. to end

-- the learned time from here to a slot on the open flight map, or nil
function Flight.TimeTo(slot)
    local here, there = HereName(), TaxiNodeName and TaxiNodeName(slot)
    if not (here and there) or here == there then return nil end
    return FlightStore()[RouteKey(here, there)]
end

-- "Ironforge, Dun Morogh": the place, not its zone
local function ShortName(name)
    return name and (name:match("^([^,]+)") or name) or ""
end

local function FlightOnUpdate(holder, elapsed)
    holder.flightTick = (holder.flightTick or 0) + elapsed
    local now = Flight.now
    if not now then return end
    local flown = GetTime() - now.start
    if now.total and now.total > 0 then
        holder.Bar:SetValue(math_min(flown / now.total, 1))
    end
    if holder.flightTick < 0.2 then return end
    holder.flightTick = 0
    if now.total and now.total > 0 then
        holder.Text:SetText(Clock(now.total - flown))
    elseif now.keep then
        holder.Text:SetText(string.format(L["Learning %s"], Clock(flown)))
    else
        -- caught mid-air (a login without a record): the time flown, nothing learned
        holder.Text:SetText(Clock(flown))
    end
end

function Flight.Update(holder)
    local now = Flight.now
    if not now then
        holder:SetScript("OnUpdate", nil)
        return
    end
    local c = COLORS.flight
    holder.Bar:SetStatusBarColor(c[1], c[2], c[3])
    holder.Bar:SetMinMaxValues(0, 1)
    holder.Bar:SetValue(0)
    holder.Label:SetText(now.dest and ShortName(now.dest) or L["Flight Timer"])
    holder.Spark:SetShown(now.total and now.total > 0 or false)
    holder.flightTick = 1   -- the text at once
    holder:SetScript("OnUpdate", FlightOnUpdate)
    FlightOnUpdate(holder, 0)
end

local flightTicker
local function FlightShown()
    if bars.flight then ApplyShown(bars.flight) end
end

local function TakeOff(pending, startedAt)
    local global = ns.db and ns.db.global
    Flight.now = { key = pending and pending.key, dest = pending and pending.dest, start = startedAt or GetTime(),
                   total = pending and pending.key and FlightStore()[pending.key], keep = pending and pending.key and true or false }
    Flight.pending = nil
    if global and pending and pending.key then
        global.flightNow = { key = pending.key, dest = pending.dest, epoch = time() - (GetTime() - Flight.now.start) }
    end
    FlightShown()
end

local function Land()
    local now = Flight.now
    Flight.now = nil
    local global = ns.db and ns.db.global
    if global then global.flightNow = nil end
    if now and now.keep and now.key then
        local flown = GetTime() - now.start
        if flown >= FLIGHT_MIN then FlightStore()[now.key] = math_floor(flown + 0.5) end
    end
    FlightShown()
end

local function FlightCheck()
    local onTaxi = UnitOnTaxi("player")
    if Flight.pending then
        if onTaxi then TakeOff(Flight.pending)
        elseif GetTime() - Flight.pending.at > FLIGHT_CATCH then Flight.pending = nil end
    elseif Flight.now and not onTaxi then
        Land()
    elseif not Flight.now and onTaxi then
        -- in the air with nothing caught (a login or reload): a reload's record carries on, else count up
        local global = ns.db and ns.db.global
        local record = global and global.flightNow
        if record and record.epoch and time() - record.epoch < FLIGHT_RESUME then
            TakeOff({ key = record.key, dest = record.dest }, GetTime() - (time() - record.epoch))
        else
            TakeOff(nil)
        end
    end
    -- a light check while something is under way; the control events do the rest
    local busy = Flight.pending or Flight.now
    if busy and not flightTicker then
        flightTicker = C_Timer.NewTicker(0.5, FlightCheck)
    elseif not busy and flightTicker then
        flightTicker:Cancel()
        flightTicker = nil
    end
end

-- the flight map's pins and the old taxi frame's buttons: the learned time under the cost
local function AddFlightTime(slot)
    local seconds = slot and Flight.TimeTo(slot)
    if not seconds then return end
    GameTooltip_AddNormalLine(GameTooltip, string.format(L["Flight time: %s"], Clock(seconds)))
    GameTooltip:Show()
end

function Flight.Init()
    if Flight.initialized then return end
    Flight.initialized = true
    if TakeTaxiNode then
        hooksecurefunc("TakeTaxiNode", function(slot)
            local here, there = HereName(), TaxiNodeName and TaxiNodeName(slot)
            if here and there and here ~= there then
                Flight.pending = { key = RouteKey(here, there), dest = there, at = GetTime() }
                FlightCheck()
            end
        end)
    end
    if TaxiRequestEarlyLanding then
        hooksecurefunc("TaxiRequestEarlyLanding", function() if Flight.now then Flight.now.keep = false end end)
    end
    if TaxiNodeOnButtonEnter then
        hooksecurefunc("TaxiNodeOnButtonEnter", function(button) AddFlightTime(button and button:GetID()) end)
    end
    EventUtil.ContinueOnAddOnLoaded("Blizzard_FlightMap", function()
        local mixin = _G.FlightMap_FlightPointPinMixin
        if mixin and mixin.OnMouseEnter then
            hooksecurefunc(mixin, "OnMouseEnter", function(pin)
                local data = pin.taxiNodeData
                if data and data.state == Enum.FlightPathState.Reachable then AddFlightTime(data.slotIndex) end
            end)
        end
    end)
    local events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "PLAYER_ENTERING_WORLD", "TAXIMAP_CLOSED" }) do
        pcall(events.RegisterEvent, events, event)
    end
    events:SetScript("OnEvent", function() C_Timer.After(0.2, FlightCheck) end)
    FlightCheck()
end

--------------------------------------------------
-- 10c. SEALS (11-11, Marcus; the idea after SealBar, its seal IDs only: it has no licence)
-- One bar for the paladin's seal: its name, the time left, the fill running down, each seal in its
-- own colour (Bar Colours), no icon. A seal's aura is secret in a fight, so the game draws it: an
-- AuraContainer (as Auras.lua's) holds one group per seal, filtered by the seal's spell IDs, and each
-- group's button binds a bar of FlareUI's look (SetDurationBar, SetDurationText). That bar sits on
-- the button, so it is up exactly while that seal is. The holder is only the Edit Mode frame (and its
-- sample); its fades reach the bars through the container, its child. Made out of a fight only.
-- A rank not listed is learned out of a fight by the seal's name (db.global.sealAuraIDs), from the
-- next login.
--------------------------------------------------
local Seal = { parts = {} }
RB.Seal = Seal
local SEALS = {
    { key = "sealRighteousness", id = 20293, ranks = { 20154, 21084, 20287, 20288, 20289, 20290, 20291, 20292, 27155 } },
    { key = "sealCrusader", id = 20308, ranks = { 21082, 20162, 20305, 20306, 20307, 27158 } },
    { key = "sealCommand", id = 20920, ranks = { 20375, 20915, 20918, 20919, 27170 } },
    { key = "sealJustice", id = 20164, ranks = {  } },
    { key = "sealLight", id = 20349, ranks = { 20165, 20347, 20348, 27160 } },
    { key = "sealWisdom", id = 20357, ranks = { 20166, 20356, 27166 } },
    { key = "sealFury", id = 20423, ranks = { 1311649, 1311656, 20163, 20419, 20421, 20422 } },
    { key = "sealMartyrdom", id = 407798, ranks = {  } },
}

local function SealName(seal)
    return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(seal.id) or nil
end

local function SealIDs(seal)
    local set = { [seal.id] = true }
    for _, id in ipairs(seal.ranks) do set[id] = true end
    local learned = ns.db and ns.db.global and ns.db.global.sealAuraIDs
    for id, key in pairs(learned or {}) do if key == seal.key then set[id] = true end end
    return set
end

-- one seal's bar, in the holder's look (section 6's sizes, texture, border, font)
local function LayoutPart(part, holder, cfg, font)
    local height = cfg.height or 14
    local PADDING = BarPadding(cfg, height)
    part:ClearAllPoints()
    part:SetAllPoints(holder)
    part.Backdrop:SetBackdrop({ bgFile = K.BACKDROP_FILE, insets = { left = PADDING, right = PADDING, top = PADDING, bottom = PADDING } })
    part.Backdrop:SetBackdropColor(0, 0, 0, K.BG_OPACITY)
    K.ApplyBorderStyle(part.Border, K.GetBorderFile(cfg.border or DEFAULT_BAR_BORDER), height + 2 * K.INSET)
    local texture = K.GetBarTexture(cfg.texture)
    part.Bar:SetStatusBarTexture(texture)
    part.Bar.bg:SetTexture(texture)
    K.SetBarBackground(part.Bar, cfg.bgOpacity)
    part.Bar:ClearAllPoints()
    part.Bar:SetPoint("TOPLEFT", part, "TOPLEFT", PADDING, -PADDING)
    part.Bar:SetPoint("BOTTOMRIGHT", part, "BOTTOMRIGHT", -PADDING, PADDING)
    local c = RBC[part.seal.key] or { 1, 1, 1 }
    part.Bar:SetStatusBarColor(c[1], c[2], c[3])
    K.ApplyFont(part.Label, font)
    part.Label:ClearAllPoints()
    part.Label:SetPoint("LEFT", part.Bar, "LEFT", K.TEXT_INSET, 0)
    part.Label:SetText(SealName(part.seal) or "")
    part.Label:SetShown(cfg.showLabel ~= false)
    K.ApplyFont(part.Time, font)
    part.Time:ClearAllPoints()
    part.Time:SetPoint("RIGHT", part.Bar, "RIGHT", -K.TEXT_INSET, 0)
    part.Time:SetShown(cfg.showTimer ~= false)
end

local function SealInit(seal, holder)
    return function(button)
        local part = CreateFrame("Frame", nil, button)
        part.seal = seal
        local level = holder:GetFrameLevel()
        part:SetFrameLevel(level)
        part.Backdrop = CreateFrame("Frame", nil, part, "BackdropTemplate")
        part.Backdrop:SetAllPoints()
        part.Backdrop:SetFrameLevel(level)
        part.Border = CreateFrame("Frame", nil, part, "BackdropTemplate")
        part.Border:SetAllPoints()
        part.Border:SetFrameLevel(level + 3)
        part.Bar = K.CreateBar(part, level + 1)
        part.Bar:SetMinMaxValues(0, 1)
        local overlay = CreateFrame("Frame", nil, part)
        overlay:SetAllPoints()
        overlay:SetFrameLevel(level + 4)
        part.Label = overlay:CreateFontString(nil, "OVERLAY")
        part.Label:SetJustifyH("LEFT")
        part.Label:SetWordWrap(false)
        part.Time = overlay:CreateFontString(nil, "OVERLAY")
        part.Time:SetJustifyH("RIGHT")
        Seal.parts[seal.key] = part
        local cfg = Cfg("seal") or {}
        RB.SeedFonts()
        LayoutPart(part, holder, cfg, cfg.font)
        -- the game fills the bar and writes the time (both secret in a fight)
        local E = Enum or {}
        pcall(button.SetDurationBar, button, part.Bar, {
            direction = E.StatusBarTimerDirection and E.StatusBarTimerDirection.RemainingTime,
            interpolation = E.StatusBarInterpolation and E.StatusBarInterpolation.Immediate,
        })
        pcall(button.SetDurationText, button, part.Time)
    end
end

local function BuildContainer(holder)
    if Seal.container or Seal.failed then return end
    if InCombatLockdown() then Seal.pendingBuild = true return end
    Seal.pendingBuild = nil
    if C_AddOns.DoesAddOnExist("Blizzard_AuraContainer") and not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
    end
    local ok, container = pcall(CreateFrame, "AuraContainer", nil, holder, "CustomAuraContainerTemplate")
    if not (ok and type(container) == "table" and container.AddAuraGroup) then Seal.failed = true return end
    Seal.container = container
    container:SetUnit("player")
    container:SetSize(1, 1)
    container:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    local E = Enum or {}
    for _, seal in ipairs(SEALS) do
        if SealName(seal) then
            pcall(container.AddAuraGroup, container, seal.key, "HELPFUL", {
                maxFrameCount = 1,
                candidateFilters = { includeSpellIDs = SealIDs(seal) },
                sortMethod = E.AuraContainerSortMethod and E.AuraContainerSortMethod.Default,
                sortDirection = E.AuraContainerSortDirection and E.AuraContainerSortDirection.Normal,
                initializeFrame = SealInit(seal, holder),
                layout = { elementWidth = 1, elementHeight = 1, elementSpacing = 0, lineSpacing = 0 },
            })
        end
    end
end

-- the holder's own art is the Edit Mode sample only; the live bars are the seals'
local function SampleShown(holder, shown)
    holder.Backdrop:SetShown(shown)
    holder.Border:SetShown(shown)
    holder.Bar:SetShown(shown)
    holder.Text:SetShown(shown and Cfg("seal").showTimer ~= false)
    holder.Label:SetShown(shown and Cfg("seal").showLabel ~= false)
end

function Seal.Update(holder)
    SampleShown(holder, false)
    BuildContainer(holder)
    if Seal.container and not InCombatLockdown() then
        Seal.container:Show()
        pcall(Seal.container.SetEnabled, Seal.container, true)
    end
end

function Seal.Preview(holder)
    -- (a settings preview's sample leaves the live bars alone)
    if not holder.fuiSample and Seal.container and not InCombatLockdown() then pcall(Seal.container.SetEnabled, Seal.container, false) end
    SampleShown(holder, true)
    local sample = SEALS[1]
    holder.Label:SetText(SealName(sample) or L["Paladin Seals"])
    holder.Text:SetText("18")
    holder.Bar:SetMinMaxValues(0, 1)
    holder.Bar:SetValue(0.6)
    local c = RBC[sample.key] or { 1, 1, 1 }
    holder.Bar:SetStatusBarColor(c[1], c[2], c[3])
end

function Seal.Layout(holder, cfg, font)
    if holder.fuiSample then return end
    for _, part in pairs(Seal.parts) do LayoutPart(part, holder, cfg, font) end
end

-- out of a fight: a seal aura with a spell ID not listed, by its name (from the next login)
function Seal.Learn()
    if ClassFile() ~= "PALADIN" or InCombatLockdown() then return end
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local ok, secret = pcall(C_Secrets.ShouldAurasBeSecret)
        if not ok or not canaccessvalue(secret) or secret then return end
    end
    local global = ns.db and ns.db.global
    if not global then return end
    local byName = {}
    for _, seal in ipairs(SEALS) do
        local name = SealName(seal)
        if name then byName[name] = seal end
    end
    for i = 1, 40 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not ok or not aura then break end
        local name, id = readable(aura.name), readable(aura.spellId)
        local seal = name and byName[name]
        if seal and id and not SealIDs(seal)[id] then
            global.sealAuraIDs = global.sealAuraIDs or {}
            global.sealAuraIDs[id] = seal.key
        end
    end
end

--------------------------------------------------
-- 11. PUBLIC
--------------------------------------------------
-- the bar Visibility fades (nil when it was not made: off at login)
function RB:GetHolder(key) return bars[key] end

-- a swing bar set to Only When In Use (its Visibility in Visibility.lua; a fade group's Show counts)
function RB.InUse(key)
    if BARS[key].kind ~= "swing" then return false end
    return ns.Visibility and ns.Visibility.GetShow and ns.Visibility:GetShow("rb_" .. key) == "inuse" or false
end

-- Up to 5.0.6 each bar's Visibility was saved with the bar (resource.bars[key].show, which hid it): each
-- one becomes its Visibility element once, as it was (shown or hidden = faded to 0%, at once)
function RB.SeedVisibility()
    local vis = ns.db and ns.db.profile and ns.db.profile.visibility
    if not (vis and vis.elements) then return end
    for _, key in ipairs(BAR_ORDER) do
        local element = "rb_" .. key
        if vis.elements[element] == nil then
            local cfg = Cfg(key)
            vis.elements[element] = { show = (cfg and cfg.show) or "always", group = 0, minAlpha = 0, fadeSpeed = "instant" }
        end
    end
end

function RB:Refresh()
    if not self.initialized then return end
    RB.ApplyPalette()
    for _, key in ipairs(BAR_ORDER) do
        local holder = bars[key]
        if holder then
            LayoutBar(holder)
            ApplyPosition(holder)
        end
    end
    ApplyAllShown()
    if ns.Visibility and ns.Visibility.Refresh then ns.Visibility:Refresh() end
end

local function BarOn(key)
    local cfg = Cfg(key)
    if key == "mana" and ClassFile() ~= "DRUID" then return false end
    if key == "seal" and ClassFile() ~= "PALADIN" then return false end
    return cfg and cfg.enabled and true or false
end

-- Loads when the module and any bar are on
function RB:ShouldLoad()
    local db = K and K.GetDb()
    if not (db and db.resource and db.resource.enabled) then return false end
    for _, key in ipairs(BAR_ORDER) do
        if BarOn(key) then return true end
    end
    return false
end

-- Blizzard's counterparts are parked for the session: the Personal Resource Display with a health,
-- power, mana or combo bar (not for swing timers alone), each swing timer with its bar
local BLIZZARD_COUNTERPARTS = {
    { addon = "Blizzard_PersonalResourceDisplay", frame = "PersonalResourceDisplayFrame", bars = { "health", "power", "mana", "combo" } },
    { addon = "Blizzard_SwingTimer", frame = "SwingTimerMainHandFrame", bars = { "swingMain" } },
    { addon = "Blizzard_SwingTimer", frame = "SwingTimerOffHandFrame",  bars = { "swingOff" } },
    { addon = "Blizzard_SwingTimer", frame = "SwingTimerRangedFrame",   bars = { "swingRanged" } },
}

local function HideBlizzardCounterparts()
    for _, entry in ipairs(BLIZZARD_COUNTERPARTS) do
        local wanted = false
        for _, key in ipairs(entry.bars or {}) do if BarOn(key) then wanted = true end end
        if wanted then
            local function hide()
                local frame = _G[entry.frame]
                if not frame then return end
                K.HardHide(entry.frame)
                -- (11-13, a player report: Blizzard's swing timer showed in busy fights) these bars are
                -- run by Blizzard's SwingTimerManagerFrame, not their own events, and the bottom frame
                -- manager can take one back under its own parent mid-fight, out of the hidden parent; so
                -- they are also kept fully transparent and mouse-deaf, which holds in a fight too
                if entry.addon == "Blizzard_SwingTimer" and not frame.FlareUI_Invisible then
                    frame.FlareUI_Invisible = true
                    frame:SetAlpha(0)
                    if frame.EnableMouse then pcall(frame.EnableMouse, frame, false) end
                    hooksecurefunc(frame, "SetAlpha", function(f, alpha) if alpha ~= 0 then f:SetAlpha(0) end end)
                end
            end
            if _G[entry.frame] then
                hide()
            elseif EventUtil and EventUtil.ContinueOnAddOnLoaded then
                EventUtil.ContinueOnAddOnLoaded(entry.addon, hide)
            end
        end
    end
end

-- Blizzard's scrolling combat text shares the MEDIUM strata with no level of its own, so it drew
-- behind these bars. Above the unit frames too (their top level is about 205); a strata change
-- would also put it over every open window.
local COMBAT_TEXT_LEVEL = 250
local function RaiseCombatText()
    if CombatText then CombatText:SetFrameLevel(COMBAT_TEXT_LEVEL) end
end

function RB:Init()
    if self.initialized or not K then return end
    self.initialized = true
    RB.ApplyPalette()
    RB.SeedVisibility()
    EventUtil.ContinueOnAddOnLoaded("Blizzard_CombatText", RaiseCombatText)

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
    LEM:RegisterCallback("exit", function() ApplyAllShown() end)
    ns.OnEditFight(function() ApplyAllShown() end)

    HideBlizzardCounterparts()
    EnableSwingRange()
    if bars.flight then Flight.Init() end
    if bars.seal then
        local sealEvents = CreateFrame("Frame")
        sealEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
        sealEvents:RegisterUnitEvent("UNIT_AURA", "player")
        sealEvents:SetScript("OnEvent", function(_, event)
            if event == "PLAYER_REGEN_ENABLED" and Seal.pendingBuild then ApplyShown(bars.seal) end
            if not Seal.learnPending then
                Seal.learnPending = true
                C_Timer.After(1, function() Seal.learnPending = nil; Seal.Learn() end)
            end
        end)
    end
    self:Refresh()
end
