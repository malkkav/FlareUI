local _, ns = ...
local L = ns.L

--------------------------------------------------
-- RESOURCE BARS
-- Health, power, druid mana, combo point, swing timer, flight timer, seal and timer bars, each an Edit Mode frame.
-- Replaces the Personal Resource Display, Blizzard's swing timers and its mirror timers (breath, fatigue,
-- feign death). Secret-safe: values go straight into
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
    -- an on-next-swing attack queued: the main-hand bar takes that attack's colour
    queueHeroic = { 1.00, 0.80, 0.10 },   -- Heroic Strike
    queueCleave = { 0.30, 0.60, 1.00 },   -- Cleave
    queueMaul   = { 1.00, 0.42, 0.08 },   -- Maul
    queueRaptor = { 0.30, 0.85, 0.30 },   -- Raptor Strike
    waiting   = { 0.45, 0.45, 0.45 },   -- Waiting State: auto attack on, no swing running
    flight     = { 0.40, 0.62, 0.86 },   -- Flight Timer
}

-- textSize: added to the Fonts tab size
local BAR_ORDER = { "health", "power", "mana", "combo", "swingMain", "swingOff", "swingRanged", "flight", "seal", "timer" }
local BARS = {
    health      = { kind = "health", label = L["Health Bar"],      default = { point = "CENTER", x = 0, y = -128 }, textSize = 2 },
    power       = { kind = "power",  label = L["Power Bar"],       default = { point = "CENTER", x = 0, y = -151 }, textSize = 2 },
    -- right under the power bar, the health-to-power gap apart
    mana        = { kind = "mana",   label = L["Druid Mana"],      default = { point = "CENTER", x = 0, y = -174 }, textSize = 2 },
    combo       = { kind = "combo",  label = L["Combo Points"],    default = { point = "CENTER", x = 0, y = -88 } },
    swingMain   = { kind = "swing",  label = L["Main-Hand Swing"], default = { point = "CENTER", x = 0, y = -282 }, textSize = 0,
                    swingType = SWING and SWING.MainHand, text = _G.SWING_TIMER_MAIN_HAND or "Main Hand" },
    swingOff    = { kind = "swing",  label = L["Off-Hand Swing"],  default = { point = "BOTTOM", x = 0, y = 289 }, textSize = 0,
                    swingType = SWING and SWING.OffHand, text = _G.SWING_TIMER_OFF_HAND or "Off Hand" },
    swingRanged = { kind = "swing",  label = L["Ranged Swing"],    default = { point = "BOTTOM", x = 0, y = 270 }, textSize = 0,
                    swingType = SWING and SWING.Ranged, text = _G.SWING_TIMER_RANGED or "Ranged" },
    -- a paladin's seal and its time left, in the seal's own colour (section 10c)
    seal        = { kind = "seal",   label = L["Paladin Seals"],   default = { point = "CENTER", x = 0, y = -262 }, textSize = 0 },
    -- a flight path's progress (section 10b), shown only while you fly
    flight      = { kind = "flight", label = L["Flight Timer"],    default = { point = "TOP", x = 0, y = -100 }, textSize = 0 },
    -- Blizzard's mirror timers (breath, fatigue, feign death, section 10d), on Blizzard's own spot
    timer       = { kind = "timer",  label = L["Duration Bars"],      default = { point = "TOP", x = 0, y = -73 }, textSize = 0 },
}

-- Visibility (the action bars' Show conditions, Fade Group, Fade Speed, Faded Opacity, and Missing
-- Health on the health bar) is Visibility.lua's: elements rb_<key>, faded by alpha. The bars still show
-- and hide themselves where they don't apply, and a swing bar set to Only When In Use with its swings.
-- How long a bar in that mode outlasts a finished swing: the next one rarely lands on the same frame
local SWING_IN_USE_HOLD = 1.5

local bars = {}            -- key -> holder
local fsrStart             -- GetTime() of the last mana cast, while the five seconds run

--------------------------------------------------
-- 3. SETTINGS ACCESS
--------------------------------------------------
local function GetResourceDb()
    local db = K and K.GetDb()
    return db and db.resource
end

-- Classic combo gems: on in the ring styles, off in Addon Style, unless the bar's Style says
-- otherwise ("classic" gems or the "modern" bar in any frame style)
local function ClassicCombo()
    local rdb = GetResourceDb()
    local look = rdb and rdb.bars and rdb.bars.combo and rdb.bars.combo.look
    if look == "classic" then return true elseif look == "modern" then return false end
    return ns.UFRing and ns.UFRing.On() and true or false
end

-- The health bar's class colours follow the player frame's switch
local function PlayerClassColors()
    local db = K.GetDb()
    return ns.ClassColorsOn(db and db.units and db.units.player)
end

-- Each bar's font: once per profile, every bar with text starts from the shared font plus its size
-- step (textSize)
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

-- a bar's text font, for the page's Fonts tab (Settings/Pages/ResourceBars.lua)
function RB.BarFont(key)
    RB.SeedFonts()
    local cfg = Cfg(key)
    return cfg and cfg.font
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

-- COLOUR PALETTE (Resource Bars' own): FlareUI, Blizzard or Custom, as the unit frames' but
-- kept apart (unitframes.resource.palette; until set, the unit frames' choice). Custom keeps the
-- picked colours (customColors) over the palette it started from (customBase).
RB.COLOR_DEFAULTS = {
    low = { 0.85, 0.1, 0.1 }, combo = { ns.COMBO_COLOR[1], ns.COMBO_COLOR[2], ns.COMBO_COLOR[3] },
    swingMain = { 0.86, 0.65, 0.39 }, swingOff = { 0.72, 0.54, 0.32 }, swingRanged = { 0.45, 0.68, 0.40 },
    outOfRange = { 0.78, 0.28, 0.24 }, waiting = { 0.45, 0.45, 0.45 },
    -- the queued on-next-swing attacks, each its own colour
    queueHeroic = { 1.00, 0.80, 0.10 }, queueCleave = { 0.30, 0.60, 1.00 }, queueMaul = { 1.00, 0.42, 0.08 }, queueRaptor = { 0.30, 0.85, 0.30 },
    zone = { 1, 0.2, 0.15 }, flight = { 0.40, 0.62, 0.86 },
    -- the seals (Seals bar), each its own colour
    sealRighteousness = { 0.51, 0.875, 0.922 }, sealCrusader = { 1, 0.647, 0.459 }, sealCommand = { 0.969, 0.49, 0.133 }, sealJustice = { 0.62, 0.502, 0.302 }, sealLight = { 0.98, 0.816, 0.38 }, sealWisdom = { 0.098, 0.584, 1 }, sealFury = { 0.91, 0.224, 0 }, sealMartyrdom = { 0.65, 0.35, 0.85 },
    -- the timer bars, as Blizzard's mirror timer art: breath the crafting-cast blue, fatigue the cast
    -- gold, feign death the channel green
    timerBreath = { 0.20, 0.55, 1.00 }, timerFatigue = { 1.00, 0.70, 0.00 }, timerFeign = { 0.15, 0.80, 0.20 },
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
    -- a saved single Queued Attack Colour (customColors.queued) moves to Heroic Strike once
    local picked = rdb and rdb.customColors
    if picked and picked.queued ~= nil then
        if picked.queueHeroic == nil then picked.queueHeroic = picked.queued end
        picked.queued = nil
    end
    local custom = palette == "custom" and rdb and rdb.customColors or nil
    for _, key in ipairs({ "health", "classHealth", "low", "mana", "rage", "energy", "druidMana", "combo",
                           "swingMain", "swingOff", "swingRanged", "outOfRange", "waiting", "zone",
                           "queueHeroic", "queueCleave", "queueMaul", "queueRaptor",
                           "heal", "absorb", "trail", "flight", "timerBreath", "timerFatigue", "timerFeign",
                           "sealRighteousness", "sealCrusader", "sealCommand", "sealJustice", "sealLight", "sealWisdom", "sealFury", "sealMartyrdom" }) do
        local own = custom and custom[key]
        local c = (type(own) == "table" and own[1]) and own or RB.PaletteColor(key, base)
        RBC[key] = RBC[key] or {}
        RBC[key][1], RBC[key][2], RBC[key][3] = c[1], c[2], c[3]
    end
    -- the tables the bars read
    for _, key in ipairs({ "combo", "swingMain", "swingOff", "swingRanged", "outOfRange", "waiting", "flight",
                           "queueHeroic", "queueCleave", "queueMaul", "queueRaptor" }) do
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
-- Health Colour (UnitFrames.lua UF.HealthBarColor): "off", "low" or "health". A saved Low Health
-- Colour switch (lowHealth = true) reads as "low" until the dropdown is set. "low" keeps the red
-- layer below (it takes the palette's Low Health colour); "health" colours the fill itself on every
-- health change.
function LOW_HEALTH.Mode(cfg)
    if cfg and cfg.healthColor == nil and cfg.lowHealth then return "low" end
    return K.HealthColorMode(cfg)
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
-- (11-26, Ballsy) the off-hand bar only with a weapon in the off hand: no item there, or a shield or a
-- held-in-off-hand item (not a weapon), and it stays hidden whatever the attack speed says
function RB.OffHandWeapon()
    local id = GetInventoryItemID("player", INVSLOT_OFFHAND or 17)
    if not canaccessvalue(id) then return nil end   -- (hidden: the attack speed decides)
    if id == nil then return false end
    local getInfo = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if not getInfo then return nil end
    local classID = select(6, getInfo(id))
    if not canaccessvalue(classID) or classID == nil then return nil end
    return classID == (Enum.ItemClass and Enum.ItemClass.Weapon or 2)
end
local function HasSwingWeapon(swingType)
    if not (SWING and swingType) then return false end
    if swingType == SWING.OffHand and RB.OffHandWeapon() == false then return false end
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
        -- Show in Caster Form (Pedrix): up whenever you have mana, not only in Bear or Cat Form
        local cfg = Cfg(holder.key)
        if cfg and cfg.casterForm then
            local max = readable(UnitPowerMax("player", MANA))
            if max == nil or max > 0 then return true end
        end
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
-- read once as the world loads: a reload, or a loading screen that ended the attack, tells no event
function RB.SeedAuto()
    local current = C_Spell.IsCurrentSpell
    if current then
        local on = current(6603)   -- Auto Attack
        if canaccessvalue(on) then RB.auto.melee = on and true or false end
    end
    local repeating = C_Spell.IsAutoRepeatSpell
    local shot, wand
    if repeating then shot, wand = repeating(75), repeating(5019) end   -- Auto Shot, Shoot
    RB.auto.ranged = (canaccessvalue(shot) and shot or canaccessvalue(wand) and wand) and true or false
end
local function AutoAttacking(key)
    if key == "swingRanged" then return RB.auto.ranged end
    return RB.auto.melee
end

local function ShouldShow(holder)
    local cfg = Cfg(holder.key)
    if not cfg then return false end
    -- the timer bars can be switched off live (RB.SetTimerBars): gone at once, Edit Mode too
    local kind = BARS[holder.key].kind
    if kind == "timer" and not cfg.enabled then return false end
    if IsEditing() then return true end
    -- the timer bars: while a timer runs
    if kind == "timer" then return RB.Timer and RB.Timer.Running() or false end
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
-- Bar Text (BarText.lua): health, power and mana have Left / Middle / Right texts (Text is the Right
-- one); a saved single Text choice becomes the Middle slot once
RB.SLOT_BARS = { health = "health", power = "power", mana = "mana" }
function RB.SlotTexts(holder)
    return { left = holder.TextLeft, middle = holder.TextMid, right = holder.Text }
end
-- runs on every health and power tick: the texts and slots are kept per holder, the slots read again
-- after each layout (LayoutBar) or for another profile's settings
-- (nil: a bar without text slots)
function RB.Slots(holder)
    local bar = RB.SLOT_BARS[holder.key]
    if not (bar and holder.TextLeft) then return nil end
    local cfg = Cfg(holder.key)
    if not holder.btSlots or holder.btCfg ~= cfg then
        holder.btSlots, holder.btCfg = ns.BarText.Slots(cfg, bar, "bar", nil, "text"), cfg
    end
    return holder.btSlots
end
function RB.FillSlots(holder, src, status)
    local slots = RB.Slots(holder)
    if not slots then return end
    holder.slotTexts = holder.slotTexts or RB.SlotTexts(holder)
    ns.BarText.FillAll(holder.slotTexts, slots, src, status)
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
    -- (no closures per tick: each step guarded on its own, as UnitFrames.lua)
    local okH, incoming = pcall(UnitGetIncomingHeals, "player")
    if okH then pcall(heal.SetValue, heal, incoming) end
    local okA, absorbs = pcall(UnitGetTotalAbsorbs, "player")
    if okA then pcall(absorb.SetValue, absorb, absorbs) end
end

-- Max and colour are set by the full updates below (UNIT_MAXHEALTH, UNIT_MAXPOWER, a show, a
-- setting, Refresh); the ticks only set the value and text, as Blizzard's own player bars do.
-- holder.ready: a full update has run since the last Edit Mode preview (which sets its own max).
local function UpdateHealthValue(holder, glide)
    local cfg = Cfg("health")
    ns.SetBarValue(holder.Bar, UnitHealth("player"), glide and cfg and cfg.smoothBars)
    -- Damage Trail (UnitFrames.lua UF.SetDamageTrail): holds, then glides; lands at once on a full update
    K.SetDamageTrail(holder.DamageTrail, "player", glide, K.DamageTrailOn(cfg and cfg.damageTrail))
    -- Bar Edge Glow: hidden while dead, a bump on each change (UnitFrames.lua UF.BarLook)
    K.BarLookUpdate(holder.Bar, "player", glide)
    if UnitIsDeadOrGhost("player") then
        RB.FillSlots(holder, nil, UnitIsGhost("player") and K.GHOST_TEXT or K.DEAD_TEXT)
    else
        -- (only the numbers the slots show are read)
        local slots = RB.Slots(holder)
        if slots then RB.FillSlots(holder, K.HealthSource("player", slots)) end
    end
    UpdateHealPrediction(holder)   -- the amounts are clamped by the health missing
    local low = holder.LowHealth
    if low and low:IsShown() and not pcall(low.SetAlpha, low, LOW_HEALTH.Alpha()) then low:SetAlpha(0) end
    -- Health Colour "By Health": the fill's colour from the health left
    if LOW_HEALTH.Mode(cfg) == "health" then holder.Bar:SetStatusBarColor(K.HealthBarColor("player", false, cfg)) end
end

local function UpdateHealth(holder, glide)
    local bar = holder.Bar
    bar:SetMinMaxValues(0, UnitHealthMax("player"))
    bar:SetStatusBarColor(RB.HealthColor())
    holder.ready = true
    local cfg = Cfg("health")
    if holder.LowHealth then
        if LOW_HEALTH.Mode(cfg) == "low" then LOW_HEALTH.Place(holder) else holder.LowHealth:Hide() end
    end
    UpdateHealthValue(holder, glide)
end

local function UpdateFsrSpark()
    local power, mana = bars.power, bars.mana
    if fsrStart and GetTime() - fsrStart >= FSR_SECONDS then fsrStart = nil end
    local onPower = PowerTypeNow() == MANA
    -- Edit Mode's sample loops a window every five seconds
    local running = fsrStart ~= nil or IsEditing()
    if power and power.FsrSpark then
        power.FsrSpark:SetShown(running and onPower and power:IsShown() and Cfg("power").fsr == true)
    end
    if mana and mana.FsrSpark then
        mana.FsrSpark:SetShown(running and not onPower and mana:IsShown() and Cfg("mana").fsr == true)
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
    -- Bar Edge Glow: steady, as power changes all the time
    if cfg and cfg.barEdgeGlow then K.BarLookUpdate(holder.Bar, "player", false, nil, K.PowerEdgeAlpha(powerType)) end
    local slots = RB.Slots(holder)
    if slots then RB.FillSlots(holder, K.PowerSource("player", powerType, slots)) end
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

-- The swing bar's colour: out of range, else Waiting State (idle, auto attack on), else the queued
-- attack's colour (main-hand bar, holder.queued = its colour key), else its own
local function SwingColor(holder)
    local c = COLORS[holder.key]
    if holder.outOfRange then c = COLORS.outOfRange
    elseif holder.waiting then c = COLORS.waiting
    elseif holder.queued then c = COLORS[holder.queued] or c
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
    -- (the queued attack just landed, or one is still waiting: asked again as the swing starts)
    if holder.key == "swingMain" and RB.UpdateQueued then RB.UpdateQueued() end
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
    -- (a running swing keeps its fill; its Stand-Still Zone takes a changed colour at once)
    if not holder.swingEnd then SwingIdle(holder) else SwingZone(holder) end
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
    elseif kind == "seal" and RB.Seal then RB.Seal.Update(holder)
    elseif kind == "timer" and RB.Timer then RB.Timer.Update(holder) end
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
        -- Health Colour: Low Health's sample is low and red; By Health's is at 40%, in its orange
        local mode = LOW_HEALTH.Mode(cfg)
        local low = mode == "low" and holder.LowHealth
        local health = low and 0.25 or mode == "health" and 0.4 or 0.75
        bar:SetValue(health)
        if mode == "health" then
            bar:SetStatusBarColor(K.SampleHealthColor(cfg, health, RB.HealthColor()))
        else
            bar:SetStatusBarColor(RB.HealthColor())
        end
        -- a sample hit just taken, 15% past the sample health
        K.SampleDamageTrail(holder.DamageTrail, health, K.DamageTrailOn(cfg.damageTrail))
        K.BarLookUpdate(bar, nil, false, false)
        RB.FillSlots(holder, K.SampleSource(health, 24000))
        -- a sample incoming heal and shield, as on the unit frames' samples
        if holder.HealBar then
            holder.HealBar:SetMinMaxValues(0, 1)
            holder.AbsorbBar:SetMinMaxValues(0, 1)
            holder.HealBar:SetValue(0.12)
            holder.AbsorbBar:SetValue(0.15)
            K.HideShieldGlow(holder.ShieldGlow)
            K.SetOverAbsorb(holder.OverAbsorb, nil, 1, low and 0 or 0.1)
        end
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
        K.BarLookUpdate(bar, nil, false, false)
        RB.FillSlots(holder, K.SampleSource(0.6, 100))
        if holder.ManaCost then holder.ManaCost:Refresh(UnitPowerType("player")) end   -- the sample cost
        -- GCD Spark: a still sample
        if holder.Gcd then
            holder.Gcd.preview = cfg.gcd and true or nil
            holder.Gcd:SetShown(cfg.gcd and true or false)
        end
    elseif kind == "mana" then
        bar:SetValue(0.4)
        bar:SetStatusBarColor(DruidManaColor())
        K.BarLookUpdate(bar, nil, false, false)
        RB.FillSlots(holder, K.SampleSource(0.4, 4000))
        if holder.ManaCost then holder.ManaCost:Refresh(MANA) end
    elseif kind == "seal" then
        -- a sample Seal of Righteousness, half run out (the real seals' bars wait in their container)
        if RB.Seal then RB.Seal.Preview(holder) end
    elseif kind == "timer" then
        -- a sample breath bar (the live bars wait under the holder)
        if RB.Timer then RB.Timer.Preview(holder) end
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
        holder.queued = nil   -- (the sample in its own colour; asked again after Edit Mode)
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
                local z = RBC.zone
                if z then holder.StandStill:SetColorTexture(z[1], z[2], z[3], 0.35) end
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
        if holder.key == "swingMain" and RB.UpdateQueued then RB.UpdateQueued() end
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
    holder.btSlots = nil   -- Bar Text's slots, read again on the next fill (RB.FillSlots)
    local PADDING = BarPadding(cfg, cfg.height or 14)
    ApplyFrameLook(holder, cfg)
    -- the bar's own font (Edit Mode > Fonts)
    RB.SeedFonts()
    local font = cfg.font

    if kind == "combo" then
        holder.count = ComboCount()
        LayoutCombo(holder)
        UpdateCombo(holder)   -- a Style switch repaints the points in the new look at once
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
    if kind == "swing" or kind == "flight" or kind == "seal" or kind == "timer" then
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
    elseif holder.TextLeft then
        -- Bar Text: Left, Middle and Right at the bar's ends and centre
        local texts = RB.SlotTexts(holder)
        for slot, at in pairs({ left = "LEFT", middle = "CENTER", right = "RIGHT" }) do
            local fs = texts[slot]
            if fs ~= holder.Text then K.ApplyFont(fs, font) end
            fs:ClearAllPoints()
            fs:SetJustifyH(at)
            fs:SetPoint(at, bar, at, (at == "LEFT" and K.TEXT_INSET) or (at == "RIGHT" and -K.TEXT_INSET) or 0, 0)
        end
        -- Values on Mouseover (off, 11-26): the bar's texts only while you point at it, as on the unit frames
        if K.ValuesOnHover then K.ValuesOnHover(holder, cfg.valuesOnHover, { texts.left, texts.middle, texts.right }) end
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
        -- Absorb Texture (Look): "" is the bar's own texture
        local absorbTex = cfg.absorbTexture
        if absorbTex == nil then absorbTex = K.ABSORB_TEXTURE end
        if absorbTex == "" then absorbTex = cfg.texture or K.DEFAULT_TEXTURE end
        absorb:SetStatusBarTexture(K.GetBarTexture(absorbTex))
        local a, h = RBC.absorb or K.ABSORB_COLOR, RBC.heal or K.HEAL_COLOR
        absorb:SetStatusBarColor(a[1], a[2], a[3], K.ABSORB_COLOR[4])
        heal:SetStatusBarColor(h[1], h[2], h[3], K.HEAL_COLOR[4])
        -- the shield with no room after the health, over it (UnitFrames.lua UF.CreateOverAbsorb)
        K.PlaceOverAbsorb(holder.OverAbsorb, bar, width, false, K.GetBarTexture(absorbTex))
        -- the Damage Trail takes the bar's texture (set above) and fills the same way
        K.PlaceDamageTrail(holder.DamageTrail, false, RBC.trail)
        -- Bar Edge Glow (UnitFrames.lua UF.BarLook): the bar fills left to right
        K.BarLook(bar, false, cfg and cfg.barEdgeGlow)
    elseif kind == "power" or kind == "mana" then
        K.BarLook(bar, false, cfg.barEdgeGlow)
    end
    -- Smooth Animated Bars, when installed and on (UnitFrames.lua ns.SAB): the health and power bars
    if ns.SAB and not holder.fuiSample and (holder.key == "health" or holder.key == "power") then
        ns.SAB.Want(bar, "player", kind, true, nil, holder.DamageTrail)
    end
    if kind == "seal" and RB.Seal then RB.Seal.Layout(holder, cfg, font) end
    if kind == "timer" and RB.Timer then RB.Timer.Layout(holder, cfg, font) end
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
    if RB.SLOT_BARS[key] then
        -- Bar Text: the Left and Middle texts (Text is the Right one)
        holder.TextLeft = overlay:CreateFontString(nil, "OVERLAY")
        holder.TextLeft:SetWordWrap(false)
        holder.TextMid = overlay:CreateFontString(nil, "OVERLAY")
        holder.TextMid:SetWordWrap(false)
    end

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
        -- Damage Trail: in the heal clip, under the heals and shields (UnitFrames.lua UF.CreateDamageTrail)
        holder.DamageTrail = K.CreateDamageTrail(holder.Bar, clip)
        -- Low Health Colour: on its own frame (its alpha may be secret; a texture's would not draw)
        local low = CreateFrame("Frame", nil, holder.Bar)
        -- (+2: over Smooth Animated Bars' liquid at +1, UnitFrames.lua ns.SAB; it covers the fill only,
        -- the heals and the trail are in the empty part, the over-shield +3 stays above it)
        low:SetFrameLevel(holder.Bar:GetFrameLevel() + 2)
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
            if IsEditing() then elapsed = GetTime() % FSR_SECONDS end
            if not elapsed or elapsed >= FSR_SECONDS then
                fsrStart = nil
                self:Hide()
                return
            end
            self.Spark:SetPoint("CENTER", holder.Bar, "LEFT", holder.Bar:GetWidth() * elapsed / FSR_SECONDS, 0)
        end)
        holder.FsrSpark = fsr
    end

    if info.kind == "swing" or info.kind == "flight" or info.kind == "seal" or info.kind == "timer" then
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
    -- (a Reset Settings in Edit Mode runs this once, after its last setting: LEM:Defer)
    if LEM:Defer(Relayout, key) then return end
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
        { name = L["Width"], kind = LEM.SettingType.Slider, default = defaults.width or 220, minValue = 40, maxValue = 600, valueStep = 1, get = get("width", 220), set = set("width"), hidden = classicOn },
        { name = L["Height"], kind = LEM.SettingType.Slider, default = defaults.height or 14, minValue = 4, maxValue = 48, valueStep = 1, get = get("height", defaults.height or 14), set = set("height"), hidden = classicOn },
    }
    local function add(item) frameItems[#frameItems + 1] = item end
    if info.kind == "combo" then
        -- Style: the gems or the bar, whatever the frame style (FlareUI Style's target has the same)
        table.insert(frameItems, 1, { name = L["Combo Points"], kind = LEM.SettingType.Dropdown,
            default = (ns.UFRing and ns.UFRing.On()) and "classic" or "modern",
            values = {
                { text = L["Classic"], value = "classic", isRadio = true },
                { text = L["Modern"],  value = "modern",  isRadio = true },
            },
            get = function() return ClassicCombo() and "classic" or "modern" end,
            set = set("look"),
            desc = L["Classic: Blizzard's combo point gems. Modern: a bar split into points, which takes the Combo Points colour."] })
        add({ name = L["Size"], kind = LEM.SettingType.Slider, default = 24, minValue = 12, maxValue = 48, valueStep = 1,
              get = get("classicSize", 24), set = set("classicSize"), hidden = classicOff })
    end
    -- Bar Text: Left / Middle / Right, as on the unit frames (BarText.lua)
    if RB.SLOT_BARS[key] then
        add(ns.BarText.Setting({
            name = L["Text"], bar = RB.SLOT_BARS[key], oldKey = "text",
            style = function() return "bar" end,
            db = function() return Cfg(key) end,
            changed = function() Relayout(key) end,
        }))
        -- Values on Mouseover (off), as on every unit frame's Text section
        add(K.ValuesOnHoverSetting(get("valuesOnHover", false), set("valuesOnHover")))
    end
    if info.kind == "power" or info.kind == "mana" then
        add({ name = L["Five-Second Rule"], kind = LEM.SettingType.Checkbox, default = false, get = get("fsr", false), set = set("fsr"),
              desc = L["A spark crosses the bar for five seconds after you spend mana. Spirit regeneration starts again when it ends."] })
    end
    -- at the bottom of Frame: each bar's own extras (off by default)
    if key == "power" then
        add({ name = L["GCD Spark"], kind = LEM.SettingType.Checkbox, default = false, get = get("gcd", false), set = set("gcd"),
              desc = L["A spark crosses the bar during the global cooldown."] })
    end
    -- (Malkkav 11-27: 7.1 made these three always on, players asked for them back) the main-hand bar's
    -- colour per queued attack (on by default), colours in Bar Colours
    if key == "swingMain" then
        add({ name = L["Queued Attack Colour"], kind = LEM.SettingType.Checkbox, default = true, get = get("queueTint", true), set = set("queueTint"),
              desc = L["While Heroic Strike, Cleave, Maul or Raptor Strike waits for the next swing, the bar takes its colour (set in Bar Colours)."] })
    end
    if key == "swingRanged" then
        add({ name = L["Stand-Still Zone"], kind = LEM.SettingType.Checkbox, default = true, get = get("standStill", true), set = set("standStill"),
              desc = L["Marks the swing's last half second. Auto Shot and wands need you to stand still then."] })
    end
    if info.kind == "swing" then
        -- the out-of-range colour, as the unit frames' range fading (in Frame: it changes what the
        -- bar tells you, not how it looks)
        add({ name = L["Range Check"], kind = LEM.SettingType.Checkbox, default = true, get = get("rangeCheck", true), set = set("rangeCheck"),
              desc = L["The bar turns red while your target is out of reach of this attack."] })
        add({ name = L["Waiting State"], kind = LEM.SettingType.Checkbox, default = true, get = get("waiting", true), set = set("waiting"),
              desc = L["When auto attack is on but you can't swing (the target is out of reach), the bar shows full and grey, with Waiting."] })
    end
    -- the swing, flight, seal and duration bars' two texts, each on its own. In Frame: what a bar
    -- tells you belongs with the bar, not with its look.
    if info.kind == "swing" or info.kind == "flight" or info.kind == "seal" or info.kind == "timer" then
        add({ name = L["Show Name"], kind = LEM.SettingType.Checkbox, default = true, get = get("showLabel", true), set = set("showLabel"),
              desc = info.kind == "flight" and L["Where you're flying, on the left of the bar."]
                  or info.kind == "seal" and L["The seal's name on the left of the bar."]
                  or info.kind == "timer" and L["The timer's name on the left of the bar."] or L["The swing's name on the left of the bar."] })
        add({ name = L["Show Timer"], kind = LEM.SettingType.Checkbox, default = true, get = get("showTimer", true), set = set("showTimer"),
              desc = info.kind == "flight" and L["The time left on the right of the bar. A route you haven't flown yet counts up while it's learned."]
                  or info.kind == "seal" and L["The seal's time left on the right of the bar."]
                  or info.kind == "timer" and L["The time left on the right of the bar."]
                  or L["The seconds left on the right of the bar (and Waiting)."] })
    end
    -- (Show in Caster Form is a choice in its Visibility list since 11-26: Fading below)
    -- Show Icon (off): the seal's icon at the bar's left end
    if info.kind == "seal" then
        add({ name = L["Show Icon"], kind = LEM.SettingType.Checkbox, default = false, get = get("showIcon", false), set = set("showIcon"),
              desc = L["The seal's icon at the left end of the bar, so you know it at a glance."] })
    end
    -- Health Colour: the health bar's Behaviour, as on the unit frames (a saved Low Health Colour
    -- switch reads as Low Health: LOW_HEALTH.Mode)
    if info.kind == "health" then
        add(K.HealthColorSetting(function() return LOW_HEALTH.Mode(Cfg(key)) end, function(_, value)
            local cfg = Cfg(key)
            if not cfg then return end
            cfg.healthColor, cfg.lowHealth = value, nil
            Relayout(key)
        end))
    end
    -- the same sections, in the same order, as the unit frames: Size, Text, Look,
    -- Behaviour, Fading (Core.lua ns.SplitFrameItems). Classic gems have no Look.
    local Section, settings = K.EditSections()
    local sizeItems, textItems, behaviourItems = ns.SplitFrameItems(frameItems)
    Section("Size", sizeItems)
    Section("Text", textItems)
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
        -- the health bar's shields, as on the unit frames
        { name = L["Absorb Texture"], kind = LEM.SettingType.Dropdown, default = K.ABSORB_TEXTURE, values = K.BuildAbsorbValues(),
          get = get("absorbTexture", K.ABSORB_TEXTURE), set = set("absorbTexture"),
          desc = L["The texture of the shield (absorb) over the health bar."],
          hidden = function() return info.kind ~= "health" end },
        -- the health bar: Class Colours (until set, the player frame's); Low Health is in Behaviour's
        -- Health Colour
        (function()
            local item = K.ClassColorSetting(HealthClassColors, set("classColor"))
            item.hidden = function() return info.kind ~= "health" end
            return item
        end)(),
        (function()
            -- only the bars that hold a value: combo points are steps, swing timers already run smoothly
            local item = K.SmoothBarsSetting(get("smoothBars", false), set("smoothBars"))
            item.hidden = function() return info.kind ~= "health" and info.kind ~= "power" and info.kind ~= "mana" end
            return item
        end)(),
        -- Bar Edge Glow on the health, power and mana bars, as on the unit frames (default off)
        (function()
            local item = K.BarEdgeGlowSetting(get("barEdgeGlow", false), set("barEdgeGlow"))
            item.hidden = function() return info.kind ~= "health" and info.kind ~= "power" and info.kind ~= "mana" end
            if info.kind ~= "health" then item.desc = L["A bright line and a soft glow at the front of the bar."] end
            return item
        end)(),
        (function()
            local item = K.DamageTrailSetting(get("damageTrail"), set("damageTrail"))
            item.hidden = function() return info.kind ~= "health" end
            return item
        end)(),
    })
    Section("Behaviour", behaviourItems)
    -- last: Fade Group, Visibility, Show Speed, Hide Speed and Faded Opacity, as on the action bars (Visibility.lua)
    if ns.Visibility and ns.Visibility.ResourceBarSettings then
        local rows = ns.Visibility:ResourceBarSettings(key)
        -- the Druid Mana bar: In Caster Form (casterForm, off) under a line in its Visibility list: the bar
        -- stays up in caster form too, not only in Bear and Cat Form (IsAvailable)
        if info.kind == "mana" then
            for _, row in ipairs(rows) do
                if row.multiple and row.kind == LEM.SettingType.Dropdown then
                    local values, showGet, showSet = row.values, row.get, row.set
                    local casterGet, casterSet = get("casterForm", false), set("casterForm")
                    row.values = function()
                        local list = {}
                        for _, v in ipairs(type(values) == "function" and values() or values or {}) do list[#list + 1] = v end
                        list[#list + 1] = { isDivider = true }
                        list[#list + 1] = { text = L["In Caster Form"], value = "casterForm" }
                        return list
                    end
                    row.get = function(...)
                        local picked = {}
                        for _, v in ipairs(showGet(...) or {}) do picked[#picked + 1] = v end
                        if casterGet() then picked[#picked + 1] = "casterForm" end
                        return picked
                    end
                    row.set = function(layoutName, value, ...)
                        if value == "casterForm" then return casterSet(layoutName, not casterGet()) end
                        return showSet(layoutName, value, ...)
                    end
                    row.desc = (row.desc and (row.desc .. "\n") or "") .. L["In Caster Form: the bar stays up in caster form too, not only in Bear and Cat Form."]
                    break
                end
            end
        end
        Section("Fading", rows)
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

-- Queued attacks (main-hand bar, Queued Attack Colour): while an on-next-swing attack waits, the bar
-- takes that attack's colour (Bar Colours). Asked on CURRENT_SPELL_CAST_CHANGED /
-- ACTIONBAR_UPDATE_STATE and when a main-hand swing starts, never per frame; asked by name, so
-- every rank counts.
RB.QUEUED_SPELLS = {
    { 78,   "queueHeroic", "Heroic Strike", class = "WARRIOR" },
    { 845,  "queueCleave", "Cleave",        class = "WARRIOR" },
    { 6807, "queueMaul",   "Maul",          class = "DRUID" },
    { 2973, "queueRaptor", "Raptor Strike", class = "HUNTER" },
}
RB.QUEUE_EVENTS = { CURRENT_SPELL_CAST_CHANGED = true, ACTIONBAR_UPDATE_STATE = true }
-- whether your class has such an attack (the others' events aren't asked for)
function RB.HasQueued()
    local class = ClassFile()
    for _, s in ipairs(RB.QUEUED_SPELLS) do
        if s.class == class then return true end
    end
    return false
end
function RB.UpdateQueued()
    local holder = bars.swingMain
    if not holder then return end
    local isCurrent = C_Spell.IsCurrentSpell or IsCurrentSpell
    local names = RB.queuedNames
    if not names then
        -- names looked up once (your class's; a spell this client lacks is left out)
        names = {}
        local class = ClassFile()
        for i, s in ipairs(RB.QUEUED_SPELLS) do names[i] = s.class == class and C_Spell.GetSpellName(s[1]) or false end
        RB.queuedNames = names
    end
    local key
    local cfg = Cfg("swingMain")
    if isCurrent and cfg and cfg.queueTint then
        for i, s in ipairs(RB.QUEUED_SPELLS) do
            local name = names[i]
            if name and readable(isCurrent(name)) then key = s[2] break end
        end
    end
    if key ~= holder.queued then
        holder.queued = key
        if not IsEditing() then SwingColor(holder) end
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
    elseif event == "PLAYER_ENTERING_WORLD" then
        RB.SeedAuto()
    elseif event == "PLAYER_DEAD" then
        RB.auto.melee, RB.auto.ranged = false, false
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
        RB.UpdateQueued()
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
-- 10b. FLIGHT TIMER (the idea after Leatrix Plus, nothing taken)
-- Forever tells no flight's length, so each route is learned: the first flight counts up, landing
-- keeps its time (account-wide, db.global.flightTimes, "From > To" by the nodes' names), and every
-- later flight fills the bar with the time left. A flight is caught as it is picked (TakeTaxiNode on
-- the flight map) and timed from take-off (UnitOnTaxi) to landing. Not kept: a flight left early
-- (TaxiRequestEarlyLanding), one under 10 seconds, or one not caught from the start (a login in the
-- air without the record a reload leaves). A flight started in a conversation, with no flight map (the
-- druids' Moonglade to Rut'theran), is known by the answer picked; its name is the place it landed at
-- the first time (global.flightPlaces). Hovering a destination on the flight map adds its time.
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
        -- a route not timed yet: the time so far, counting up
        holder.Text:SetText(string.format(L["New Route %s"], Clock(flown)))
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
    if global and pending and pending.key and pending.gossip and not Flight.now.dest then
        Flight.now.dest = global.flightPlaces and global.flightPlaces[pending.key]
    end
    Flight.now.gossip = pending and pending.gossip
    if global and pending and pending.key then
        global.flightNow = { key = pending.key, dest = Flight.now.dest, gossip = pending.gossip, epoch = time() - (GetTime() - Flight.now.start) }
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
        if flown >= FLIGHT_MIN then
            FlightStore()[now.key] = math_floor(flown + 0.5)
            local place = now.gossip and global and GetMinimapZoneText and GetMinimapZoneText()
            if place and canaccessvalue(place) and place ~= "" then
                global.flightPlaces = global.flightPlaces or {}
                global.flightPlaces[now.key] = place
            end
        end
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
            TakeOff({ key = record.key, dest = record.dest, gossip = record.gossip }, GetTime() - (time() - record.epoch))
        else
            local talk = Flight.talk
            TakeOff(talk and GetTime() - talk.at < FLIGHT_CATCH and talk or nil)
        end
        Flight.talk = nil
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
    -- an answer picked in a conversation: if a flight starts within seconds, it was that
    local function Talked(id)
        if canaccessvalue(id) and type(id) == "number" then
            Flight.talk = { key = "gossip " .. id, at = GetTime(), gossip = true }
        end
    end
    if C_GossipInfo and C_GossipInfo.SelectOption then hooksecurefunc(C_GossipInfo, "SelectOption", Talked) end
    -- (Blizzard's window picks by the answer's place.) A flight answer closes the talk before this
    -- post-hook runs, so the answers are read when the talk opens (Flight.options) as well
    if C_GossipInfo and C_GossipInfo.SelectOptionByIndex and C_GossipInfo.GetOptions then
        hooksecurefunc(C_GossipInfo, "SelectOptionByIndex", function(index)
            local ok, options = pcall(C_GossipInfo.GetOptions)
            for _, list in ipairs({ ok and options or {}, Flight.options or {} }) do
                for _, option in ipairs(list) do
                    if option.orderIndex == index then Talked(option.gossipOptionID) return end
                end
            end
        end)
    end
    -- A talk that closes right before a flight with no answer caught: the flight is known by where it
    -- leaves from (map and faction; the druids' Moonglade flight has one way out per faction. The idea
    -- after DaylightUI, which names those flights by the map you leave from.)
    local talk = CreateFrame("Frame")
    for _, event in ipairs({ "GOSSIP_SHOW", "GOSSIP_CLOSED" }) do pcall(talk.RegisterEvent, talk, event) end
    talk:SetScript("OnEvent", function(_, event)
        if event == "GOSSIP_SHOW" then
            local ok, options = pcall(function() return C_GossipInfo.GetOptions() end)
            Flight.options = ok and type(options) == "table" and options or nil
            return
        end
        Flight.options = nil
        if Flight.talk and GetTime() - Flight.talk.at < FLIGHT_CATCH then return end
        local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        local faction = UnitFactionGroup and UnitFactionGroup("player")
        if canaccessvalue(map) and type(map) == "number" and canaccessvalue(faction) and type(faction) == "string" then
            Flight.talk = { key = ("from %d %s"):format(map, faction), at = GetTime(), gossip = true }
        end
    end)
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
-- 10c. SEALS (the idea after SealBar, its seal IDs only: it has no licence)
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

-- Show Icon (off): the seal's own icon at the bar's left end, inside the border, a square as tall as
-- the bar; the bar and the name start after it, the whole bar keeps its size. The spell's icon, so
-- it is known in a fight too. owner: a seal's bar, or the holder for the Edit Mode sample.
function Seal.PlaceIcon(owner, bar, cfg, PADDING, spellID)
    local show = cfg.showIcon == true
    local icon = owner.SealIcon
    if show and not icon then
        local frame = CreateFrame("Frame", nil, owner)
        frame:SetFrameLevel(owner:GetFrameLevel() + 2)
        icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        owner.SealIcon = icon
    end
    bar:ClearAllPoints()
    if show then
        local size = math.max(1, (owner:GetHeight() or 0) - 2 * PADDING)
        icon:SetSize(size, size)
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", owner, "TOPLEFT", PADDING, -PADDING)
        icon:SetTexture(C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID) or nil)
        icon:Show()
        bar:SetPoint("TOPLEFT", icon, "TOPRIGHT", 0, 0)
    else
        if icon then icon:Hide() end
        bar:SetPoint("TOPLEFT", owner, "TOPLEFT", PADDING, -PADDING)
    end
    bar:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", -PADDING, PADDING)
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
    Seal.PlaceIcon(part, part.Bar, cfg, PADDING, part.seal.id)
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
    if holder.SealIcon then holder.SealIcon:SetShown(shown and Cfg("seal").showIcon == true) end
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
    -- the sample (Edit Mode, settings preview) shows the icon too, Seal of Righteousness's
    if holder.Bar then
        Seal.PlaceIcon(holder, holder.Bar, cfg, BarPadding(cfg, cfg.height or 14), SEALS[1].id)
        if holder.SealIcon and not holder.Bar:IsShown() then holder.SealIcon:Hide() end
    end
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
-- 10d. TIMER BARS: Blizzard's mirror timers (breath, fatigue, feign death) in the bars' look.
-- One bar per running timer, in the order they started: the first on the holder's spot, the next ones
-- under it, flush as the snapper sets bars. Each bar has Blizzard's label on the left and the time left
-- on the right; a paused timer stands still. The holder is the Edit Mode frame and its sample; the
-- live bars are its children, so its fades reach them. Values are kept in milliseconds, as the game
-- gives them, so a secret one still fills the bar.
-- Blizzard's MirrorTimerContainer (a plain layout frame, not protected) is kept hidden while the bar is
-- on, its own Show included (Edit Mode's Timer Bars box with it), and given back as Blizzard would
-- have it when the bar is switched off. Never touched while off.
--------------------------------------------------
local Timer = { parts = {}, active = {} }
RB.Timer = Timer
-- each timer's colour (Bar Colours); death (spirit release) uses fatigue's gold, as Blizzard's art does
local TIMER_COLOR = { BREATH = "timerBreath", EXHAUSTION = "timerFatigue", DEATH = "timerFatigue", FEIGNDEATH = "timerFeign" }
local MIRROR_TIMERS = 3

function Timer.Running()
    return #Timer.active > 0
end

-- paused comes as a number (0 or 1) on Forever, a boolean elsewhere
local function TimerPaused(paused)
    paused = readable(paused)
    return paused == true or (type(paused) == "number" and paused > 0)
end

-- one bar, in the holder's look; slot 1 on the holder, the others each under the last
local function TimerLayoutPart(part, holder, i, cfg, font)
    local height = cfg.height or 14
    local PADDING = BarPadding(cfg, height)
    part:ClearAllPoints()
    part:SetSize(holder:GetWidth(), holder:GetHeight())
    if i == 1 then
        part:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    else
        part:SetPoint("TOPLEFT", Timer.parts[i - 1], "BOTTOMLEFT", 0, -SNAP_GAP)
    end
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
    K.ApplyFont(part.Label, font)
    part.Label:ClearAllPoints()
    part.Label:SetPoint("LEFT", part.Bar, "LEFT", K.TEXT_INSET, 0)
    part.Label:SetShown(cfg.showLabel ~= false)
    K.ApplyFont(part.Time, font)
    part.Time:ClearAllPoints()
    part.Time:SetPoint("RIGHT", part.Bar, "RIGHT", -K.TEXT_INSET, 0)
    part.Time:SetShown(cfg.showTimer ~= false)
end

local function TimerPart(holder, i)
    local part = Timer.parts[i]
    if part then return part end
    local level = holder:GetFrameLevel()
    part = CreateFrame("Frame", nil, holder)
    part:SetFrameLevel(level)
    part.Backdrop = CreateFrame("Frame", nil, part, "BackdropTemplate")
    part.Backdrop:SetAllPoints()
    part.Backdrop:SetFrameLevel(level)
    part.Border = CreateFrame("Frame", nil, part, "BackdropTemplate")
    part.Border:SetAllPoints()
    part.Border:SetFrameLevel(level + 3)
    part.Bar = K.CreateBar(part, level + 1)
    local overlay = CreateFrame("Frame", nil, part)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(level + 4)
    part.Label = overlay:CreateFontString(nil, "OVERLAY")
    part.Label:SetJustifyH("LEFT")
    part.Label:SetWordWrap(false)
    part.Time = overlay:CreateFontString(nil, "OVERLAY")
    part.Time:SetJustifyH("RIGHT")
    part.Time:SetWordWrap(false)
    Timer.parts[i] = part
    local cfg = Cfg("timer") or {}
    RB.SeedFonts()
    TimerLayoutPart(part, holder, i, cfg, cfg.font)
    return part
end

-- "42", "1:05": whole seconds, rounded up, so 0 shows only as the timer ends
local function TimerText(seconds)
    seconds = math.ceil(math_max(0, seconds))
    if seconds < 60 then return tostring(seconds) end
    return Clock(seconds)
end

-- the bar's fill and time left; the text only when the second changes
local function TimerTick(part, entry)
    local progress = GetMirrorTimerProgress(entry.name)
    if canaccessvalue(progress) and progress == nil then progress = entry.value end
    if canaccessvalue(progress) and progress == nil then return end
    part.Bar:SetValue(progress)
    local ms = readable(progress)
    if not ms then
        part.Time:SetText("")
        part.second = nil
        return
    end
    -- a timer that drains faster (scale under -1) runs out sooner than its amount says
    local seconds = ms / 1000
    local scale = entry.scale
    if scale and scale < 0 then seconds = seconds / -scale end
    local second = math.ceil(seconds)
    if second ~= part.second then
        part.second = second
        part.Time:SetText(TimerText(seconds))
    end
end

local function TimerOnUpdate()
    for i, entry in ipairs(Timer.active) do
        local part = Timer.parts[i]
        if part and not entry.paused and i <= MIRROR_TIMERS then TimerTick(part, entry) end
    end
end

-- the holder's own art is the Edit Mode sample only; the live bars are the parts
local function TimerSampleShown(holder, shown)
    local cfg = Cfg("timer") or {}
    holder.Backdrop:SetShown(shown)
    holder.Border:SetShown(shown)
    holder.Bar:SetShown(shown)
    holder.Text:SetShown(shown and cfg.showTimer ~= false)
    holder.Label:SetShown(shown and cfg.showLabel ~= false)
end

function Timer.Update(holder)
    TimerSampleShown(holder, false)
    local ticking = false
    for i = 1, MIRROR_TIMERS do
        local entry = Timer.active[i]
        if entry then
            local part = TimerPart(holder, i)
            local c = RBC[TIMER_COLOR[entry.name] or "timerFatigue"] or { 1, 0.7, 0 }
            part.Bar:SetStatusBarColor(c[1], c[2], c[3])
            part.Bar:SetMinMaxValues(0, entry.max)
            part.Label:SetText(entry.label)
            part.second = nil
            TimerTick(part, entry)
            part:Show()
            if not entry.paused then ticking = true end
        elseif Timer.parts[i] then
            Timer.parts[i]:Hide()
        end
    end
    holder:SetScript("OnUpdate", ticking and TimerOnUpdate or nil)
end

function Timer.Preview(holder)
    holder:SetScript("OnUpdate", nil)
    -- (a settings preview's sample leaves the live bars alone)
    if not holder.fuiSample then
        for _, part in pairs(Timer.parts) do part:Hide() end
    end
    TimerSampleShown(holder, true)
    holder.Label:SetText(L["Breath"])
    holder.Text:SetText("42")
    holder.Spark:Hide()
    holder.Bar:SetMinMaxValues(0, 1)
    holder.Bar:SetValue(0.7)
    local c = RBC.timerBreath or { 0.2, 0.55, 1 }
    holder.Bar:SetStatusBarColor(c[1], c[2], c[3])
end

function Timer.Layout(holder, cfg, font)
    if holder.fuiSample then return end
    for i = 1, MIRROR_TIMERS do
        local part = Timer.parts[i]
        if part then TimerLayoutPart(part, holder, i, cfg, font) end
    end
end

local function TimerShown()
    if bars.timer then ApplyShown(bars.timer) end
end

local function TimerFind(name)
    for i, entry in ipairs(Timer.active) do
        if entry.name == name then return entry, i end
    end
end

-- MIRROR_TIMER_START and the login's GetMirrorTimerInfo: name, value, max (ms), scale, paused, label
local function TimerStart(name, value, max, scale, paused, label)
    name = readable(name)
    if not name or name == "UNKNOWN" then return end
    local entry = TimerFind(name)
    if not entry then
        entry = { name = name }
        Timer.active[#Timer.active + 1] = entry
    end
    -- (a secret max or label is passed on as it is, untested: the bar and text take it)
    if canaccessvalue(max) then
        entry.max = (type(max) == "number" and max > 0) and max or 1
    else
        entry.max = max
    end
    if canaccessvalue(label) then entry.label = label or "" else entry.label = label end
    entry.value = value
    local s = readable(scale)
    entry.scale = type(s) == "number" and s or nil
    entry.paused = TimerPaused(paused)
end

function Timer.OnEvent(_, event, arg1, arg2, arg3, arg4, arg5, arg6)
    if event == "MIRROR_TIMER_START" then
        TimerStart(arg1, arg2, arg3, arg4, arg5, arg6)
    elseif event == "MIRROR_TIMER_STOP" then
        local _, index = TimerFind(readable(arg1))
        if index then table.remove(Timer.active, index) end
    elseif event == "MIRROR_TIMER_PAUSE" then
        local entry = TimerFind(readable(arg1))
        if entry then entry.paused = TimerPaused(arg2) end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- timers already running at login or after a loading screen
        wipe(Timer.active)
        for i = 1, MIRROR_TIMERS do
            local name, value, max, scale, paused, label = GetMirrorTimerInfo(i)
            if name then TimerStart(name, value, max, scale, paused, label) end
        end
    end
    TimerShown()
end

-- Blizzard's container: hidden while on (its Show re-hidden), given back when switched off
local function BlizzardTimers()
    local container = _G.MirrorTimerContainer
    if not container or container:IsProtected() then return nil end
    return container
end

function Timer.HideBlizzard(hide)
    local container = BlizzardTimers()
    if not container then
        if hide and not Timer.waiting and EventUtil and EventUtil.ContinueOnAddOnLoaded then
            Timer.waiting = true
            EventUtil.ContinueOnAddOnLoaded("Blizzard_MirrorTimer", function()
                if Timer.hiding then Timer.HideBlizzard(true) end
            end)
        end
        Timer.hiding = hide and true or false
        return
    end
    if hide then
        Timer.hiding = true
        if not Timer.hooked then
            Timer.hooked = true
            container:HookScript("OnShow", function(self) if Timer.hiding then ns.RawHide(self) end end)
        end
        ns.RawHide(container)
    elseif Timer.hiding then
        Timer.hiding = false
        -- as Blizzard would have it now: up with a timer running or its Edit Mode box ticked (the
        -- engine's Show: Edit Mode's own would re-lay its systems from addon code)
        if not container:IsShown() and container.ShouldShow and container:ShouldShow() then
            local show = container.ShowBase or container.Show
            show(container)
        end
    end
end

function Timer.Init()
    if Timer.initialized then return end
    Timer.initialized = true
    local events = CreateFrame("Frame")
    for _, event in ipairs({ "MIRROR_TIMER_START", "MIRROR_TIMER_STOP", "MIRROR_TIMER_PAUSE", "PLAYER_ENTERING_WORLD" }) do
        pcall(events.RegisterEvent, events, event)
    end
    events:SetScript("OnEvent", Timer.OnEvent)
    Timer.events = events
    Timer.HideBlizzard(true)
    Timer.OnEvent(nil, "PLAYER_ENTERING_WORLD")
end

-- the settings switch (Settings/Pages/ResourceBars.lua): off at once, Blizzard's timers back; on again
-- in the same session takes over again if the bar was made at login (else after the reload)
function RB.SetTimerBars(on)
    if not RB.initialized then return end
    local holder = bars.timer
    if on then
        if not holder then return end
        Timer.HideBlizzard(true)
        ApplyShown(holder)
    else
        Timer.HideBlizzard(false)
        if holder then
            holder:SetScript("OnUpdate", nil)
            holder:Hide()
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

-- Older setups saved each bar's Visibility with the bar (resource.bars[key].show, which hid it): each
-- one becomes its Visibility element once, unchanged (shown, or hidden = faded to 0% at once)
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
    -- Druid Mana is built on every class, so anyone can place it in Edit Mode; in play it
    -- shows only while mana is a second power (ManaIsSecondary: a druid in Bear or Cat Form)
    -- the same for Seals: placed on any class, shown in play only on a paladin with a seal up
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
                -- Blizzard's swing timer could show in busy fights: these bars are run by Blizzard's
                -- SwingTimerManagerFrame, not their own events, and the bottom frame
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
    local queued = RB.HasQueued()
    for _, event in ipairs(EVENTS) do
        if queued or not RB.QUEUE_EVENTS[event] then pcall(events.RegisterEvent, events, event) end
    end
    self.events = events

    LEM:RegisterCallback("layout", function(layoutName)
        for _, holder in pairs(bars) do ApplyPosition(holder, layoutName) end
    end)
    LEM:RegisterCallback("enter", function() ApplyAllShown() end)
    LEM:RegisterCallback("exit", function() ApplyAllShown() end)
    ns.OnEditFight(function() ApplyAllShown() end)

    HideBlizzardCounterparts()
    EnableSwingRange()
    if bars.timer then Timer.Init() end
    if bars.seal then
        local sealEvents = CreateFrame("Frame")
        sealEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
        -- (the bar is built on every class; only a paladin's auras can teach a seal: Seal.Learn)
        local class = ClassFile()
        if class == nil or class == "PALADIN" then sealEvents:RegisterUnitEvent("UNIT_AURA", "player") end
        sealEvents:SetScript("OnEvent", function(_, event)
            if event == "PLAYER_REGEN_ENABLED" and Seal.pendingBuild then ApplyShown(bars.seal) end
            if not Seal.learnPending then
                Seal.learnPending = true
                C_Timer.After(1, function() Seal.learnPending = nil; Seal.Learn() end)
            end
        end)
    end
    self:Refresh()
    if bars.flight then Flight.Init() end
end
