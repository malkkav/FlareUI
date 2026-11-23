local _, ns = ...
local L = ns.L

--------------------------------------------------
-- UNIT FRAMES
-- Player, target, target of target, focus, focus target and pet frames, set up in Edit Mode.
-- Secret values go straight into widget setters; Blizzard's frames are parked.
-- Main-chunk locals are near Lua's limit of 200: new constants go into tables.
--------------------------------------------------

--------------------------------------------------
-- 1. MODULE REGISTRATION
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

-- the value, or nil when it is secret
local function Readable(v)
    if canaccessvalue(v) then return v end
end

--------------------------------------------------
-- 3. CONSTANTS
--------------------------------------------------
local BORDER_FILE   = "Interface\\Tooltips\\UI-Tooltip-Border"
local BACKDROP_FILE = "Interface\\Buttons\\WHITE8x8"
-- the border art overlaps the bars by INSET; the backdrop is transparent
local INSET         = 4
local BORDER_SIZE   = 16
local BG_OPACITY    = 0
local DEFAULT_BORDER_COLOR = ns.BORDER_COLOR
local DEFAULT_BORDER  = "FlareUI Thick"
local DEFAULT_TEXTURE = "FlareUI Dark"
local SEPARATOR_TEXTURE = "Interface\\Common\\UI-TooltipDivider-Transparent"
local SEPARATOR_HEIGHT  = 8
local AURA_GAP      = 2     -- frame (or cast bar) to the aura rows
local TEXT_INSET    = 4
local PORTRAIT_GAP  = 0      -- portrait to bars; the divider straddles the seam
local CAST_HEIGHT   = 18
local CAST_GAP      = 4
local CAST_ICON_GAP = 0
local RAID_ICON     = 18     -- least pet happiness face size
local RAID_ICON_SHARE = 0.5  -- raid marker: mid health bar, this share of the bar's height
local HAPPINESS_SHARE = 0.7  -- pet happiness face: mid health bar, this share of the bar's height

local DEAD_TEXT     = _G.DEAD or "Dead"
local GHOST_TEXT    = _G.GHOST or L["Ghost"]   -- (Forever has no GHOST string: translated here)
local OFFLINE_TEXT  = _G.PLAYER_OFFLINE or "Offline"

-- Reaction colours (FACTION_BAR_COLORS' shape)
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
local CAST_COLOR            = { 0.80, 0.60, 0.36 }
local CAST_NOINTERRUPT      = { 0.55, 0.55, 0.55 }
local CAST_CHANNEL          = { 0.30, 0.65, 0.90 }
-- the player's bar is cool-toned so it never reads as the target's
local PLAYER_CAST_COLOR     = { 0.36, 0.56, 0.78 }
local PLAYER_CAST_CHANNEL   = { 0.50, 0.75, 0.88 }

-- "Colour palette": ApplyPalette copies the chosen set into the colour tables above and ns's, in place
UF.PALETTES = {
    flareui = {
        health = { 0.15, 0.82, 0.15 }, mana = { 0.18, 0.48, 1.00 }, grey = { 0.55, 0.55, 0.55 },
        hostile = { 0.87, 0.27, 0.27 }, neutral = { 0.93, 0.78, 0.25 }, friendly = { 0.30, 0.78, 0.30 },
        cast = { 0.80, 0.60, 0.36 }, castNoInterrupt = { 0.55, 0.55, 0.55 }, castChannel = { 0.30, 0.65, 0.90 },
        playerCast = { 0.36, 0.56, 0.78 }, playerChannel = { 0.50, 0.75, 0.88 },
        interrupted = { 0.85, 0.12, 0.10 }, latency = { 1, 0.15, 0.1 },
        heal = { 11/255, 136/255, 105/255 }, absorb = { 0.67, 0.78, 0.92 }, trail = { 1, 0.9, 0.75 },
        -- health bars only, kept apart from these classes' mana and energy bars; names keep the real colours
        classHealth = { SHAMAN = { 0.00, 0.32, 0.62 }, ROGUE = { 0.90, 0.80, 0.25 } },
    },
    -- Blizzard's own colours (the player's cast bar the same as everyone's)
    blizzard = {
        health = { 0, 1, 0 }, mana = { 0, 0, 1 }, grey = { 0.5, 0.5, 0.5 },
        hostile = { 1, 0, 0 }, neutral = { 1, 1, 0 }, friendly = { 0, 1, 0 },
        cast = { 1, 0.7, 0 }, castNoInterrupt = { 0.7, 0.7, 0.7 }, castChannel = { 0, 1, 0 },
        playerCast = { 1, 0.7, 0 }, playerChannel = { 0, 1, 0 },
        interrupted = { 0.85, 0.12, 0.10 }, latency = { 1, 0.15, 0.1 },
        heal = { 11/255, 136/255, 105/255 }, absorb = { 0.67, 0.78, 0.92 }, trail = { 1, 0.9, 0.75 },
        texture = "Interface\\AddOns\\FlareUI\\Media\\Bars\\FlareUI-Flat-Bright",
    },
}

-- COLOUR PALETTE: FlareUI, Blizzard, or Custom: Custom keeps the colours the player picked
-- (unitframes.customColors, key -> { r, g, b }) over the palette it started from (customBase). Keys:
-- the palettes' own, "class:<CLASS>" (health bars), "rage" / "energy" / "focus" (power bars).
-- Resource Bars has the same three under its own settings (ResourceBars.lua RB.ApplyPalette).
UF.CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
UF.POWER_KEYS = { rage = "RAGE", energy = "ENERGY", focus = "FOCUS" }

-- a palette's colour for a key, as { r, g, b }: classes their real colour unless the palette has its
-- own, power its Blizzard colour
function UF.PaletteColor(key, paletteName)
    local p = UF.PALETTES[paletteName] or UF.PALETTES.flareui
    local class = key:match("^class:(.+)$")
    if class then
        local own = p.classHealth and p.classHealth[class]
        if own then return own end
        local c = C_ClassColor and C_ClassColor.GetClassColor(class)
        if c then return { c.r, c.g, c.b } end
        return p.health
    end
    local token = UF.POWER_KEYS[key]
    if token then
        local c = _G.PowerBarColor and _G.PowerBarColor[token]
        if c and c.r then return { c.r, c.g, c.b } end
        return (UF.POWER_FALLBACK and UF.POWER_FALLBACK[token]) or p.mana
    end
    return p[key]
end

-- the colour in use for a key (a custom one first)
function UF.Color(key)
    local db = ns.db and ns.db.profile and ns.db.profile.unitframes
    if UF.palette == "custom" then
        local own = db and db.customColors and db.customColors[key]
        if type(own) == "table" and own[1] then return own end
    end
    return UF.PaletteColor(key, UF.basePalette or "flareui")
end

-- The health bar colour for a class in use, or nil for the class's real colour
function ns.ClassHealthOverride(classFile)
    if UF.palette == "custom" then
        local db = ns.db and ns.db.profile and ns.db.profile.unitframes
        local own = db and db.customColors and db.customColors["class:" .. tostring(classFile)]
        if type(own) == "table" and own[1] then return own end
    end
    local overrides = UF.PALETTES[UF.basePalette or "flareui"].classHealth
    return overrides and overrides[classFile]
end

function UF.ApplyPalette()
    local db = ns.db and ns.db.profile and ns.db.profile.unitframes
    local palette = db and db.palette
    if palette ~= "blizzard" and palette ~= "custom" then palette = "flareui" end
    UF.palette = palette
    UF.basePalette = palette == "custom" and (db.customBase == "blizzard" and "blizzard" or "flareui") or palette
    local function set(dst, src) if dst and src then dst[1], dst[2], dst[3] = src[1], src[2], src[3] end end
    local C = UF.Color
    set(ns.HEALTH_GREEN, C("health"))
    set(ns.MANA_BLUE, C("mana"))
    set(GREY, C("grey"))
    for reaction = 1, 8 do
        set(REACTION[reaction], reaction <= 3 and C("hostile") or reaction == 4 and C("neutral") or C("friendly"))
    end
    set(CAST_COLOR, C("cast"))
    set(CAST_NOINTERRUPT, C("castNoInterrupt"))
    set(CAST_CHANNEL, C("castChannel"))
    set(PLAYER_CAST_COLOR, C("playerCast"))
    set(PLAYER_CAST_CHANNEL, C("playerChannel"))
    set(UF.INTERRUPT_COLOR, C("interrupted"))
    set(UF.LAG_COLOR, C("latency"))
    set(UF.HEAL_COLOR, C("heal"))
    set(UF.ABSORB_COLOR, C("absorb"))
    set(UF.TRAIL_COLOR, C("trail"))   -- (its see-through alpha stays)
    -- custom power colours only: the others keep Blizzard's
    local power
    if palette == "custom" and db.customColors then
        for key, token in pairs(UF.POWER_KEYS) do
            local own = db.customColors[key]
            if type(own) == "table" and own[1] then power = power or {}; power[token] = own end
        end
    end
    ns.POWER_OVERRIDE = power
    -- a new version on every apply: a custom colour changes nothing else (the player's health keeps its
    -- colour until it differs)
    UF.paletteVersion = (UF.paletteVersion or 0) + 1
end

-- Power colours when PowerBarColor lacks one
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
UF.POWER_FALLBACK = POWER_FALLBACK   -- (UF.PaletteColor, above)

-- Unit definitions. `driver` is the visibility condition; player is always shown.
local UNITS = {
    player = {
        key = "Player", label = L["Player"], order = 1, auras = true, portrait = true,
        blizzard = { "PlayerFrame" },
        -- its own cast bar: the Cast Bar switch in Edit Mode (off by default), apart from the FlareUI Player Cast Bar
        castbar = true,
        -- Hide Player Frame while in party: when the party frames show, so a raid brings it back
        partyDriver = "[group:raid] show; [@raid1,exists] show; [group:party] hide; [@party1,exists] hide; show",
        -- Hide Player Frame in a Raid, alone or with the party one
        raidDriver = "[group:raid] hide; [@raid1,exists] hide; show",
        groupDriver = "[group:raid] hide; [@raid1,exists] hide; [group:party] hide; [@party1,exists] hide; show",
        events = { "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE" },
        globalEvents = { PLAYER_UPDATE_RESTING = true, GROUP_ROSTER_UPDATE = true, PARTY_LEADER_CHANGED = true,
                         PLAYER_FLAGS_CHANGED = "player", PVP_TIMER_UPDATE = true,
                         -- Combat Glow (UpdateThreat)
                         PLAYER_REGEN_DISABLED = true, PLAYER_REGEN_ENABLED = true },
        indicators = { rest = true, leader = true, pvp = true, threat = true, heals = true, readyCheck = true,
                       pvpTimer = true },
        -- Combat Glow (Look): border and ring pulse in a fight, in the threat colour with aggro
        combatGlow = true,
    },
    target = {
        mirrorable = true,
        key = "Target", label = L["Target"], order = 2, auras = true, portrait = true,
        blizzard = { "TargetFrame" },
        driver = "[@target,exists] show; hide",
        globalEvents = { PLAYER_TARGET_CHANGED = true, GROUP_ROSTER_UPDATE = true, PARTY_LEADER_CHANGED = true, PLAYER_FLAGS_CHANGED = "target",
                         QUEST_LOG_UPDATE = true, COMBO_TARGET_CHANGED = true },
        castbar = true,
        comboPoints = true,
        indicators = { leader = true, pvp = true, classification = true, highSkull = true, quest = true, threat = true,
                       heals = true, readyCheck = true },
        threatGlow = true,   -- Threat Glow (Look): the player's threat on it
    },
    targettarget = {
        key = "TargetOfTarget", label = L["Target of Target"], order = 3, noRaidIcon = true, mirrorOption = true,
        driver = "[@targettarget,exists] show; hide",
        globalEvents = { PLAYER_TARGET_CHANGED = true, UNIT_TARGET = "target" },
        poll = true,
    },
    focus = {
        mirrorable = true,
        key = "Focus", label = L["Focus"], order = 4, auras = true, portrait = true,
        blizzard = { "FocusFrame", "TargetofFocusFrame" },
        driver = "[@focus,exists] show; hide",
        globalEvents = { PLAYER_FOCUS_CHANGED = true, GROUP_ROSTER_UPDATE = true, PARTY_LEADER_CHANGED = true, PLAYER_FLAGS_CHANGED = "focus",
                         QUEST_LOG_UPDATE = true },
        castbar = true,
        -- (11-20: the target's Leader, PvP Flag and Quest Objective too: a focus can be a player or a quest mob)
        indicators = { leader = true, pvp = true, classification = true, highSkull = true, quest = true, threat = true,
                       heals = true, readyCheck = true },
        threatGlow = true,   -- Threat Glow (Look): the player's threat on it
    },
    focustarget = {
        key = "TargetOfFocus", label = L["Target of Focus"], order = 6, noRaidIcon = true, mirrorOption = true,
        driver = "[@focustarget,exists] show; hide",
        globalEvents = { PLAYER_FOCUS_CHANGED = true, UNIT_TARGET = "focus" },
        poll = true,
        sample = { name = L["Target of Focus"] },
    },
    pet = {
        key = "Pet", label = L["Pet"], order = 5, happiness = true, noRaidIcon = true, auras = true, castbar = true,
        sample = { name = L["Pet"], powerToken = "FOCUS", health = 0.85, power = 0.7 },
        blizzard = { "PetFrame" },
        driver = "[@pet,exists] show; hide",
        partyDriver = "[group:raid,@pet,exists] show; [group:raid] hide; [group:party] hide; [@party1,exists] hide; [@pet,exists] show; hide",
        raidDriver = "[group:raid] hide; [@raid1,exists] hide; [@pet,exists] show; hide",
        groupDriver = "[group:raid] hide; [@raid1,exists] hide; [group:party] hide; [@party1,exists] hide; [@pet,exists] show; hide",
        indicators = { heals = true },
        globalEvents = { UNIT_PET = "player" },
    },
}
local UNIT_ORDER = { "player", "target", "targettarget", "focus", "focustarget", "pet" }

-- The player's power events the target frame also takes, for its combo strip
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

-- Health Text and Power Text modes: the party, raid and boss tiles' dropdowns (UF.Kit), and the old
-- unit frame choices BarText.lua converts. "Value" is the current amount, "Max" the maximum.
-- Saved names: "both" is Percent | Value, "valuemax" Value [Max], "valuelost" Value | Health Lost,
-- "valuepct" Value | Percent. "valuemaxpct" (Current (Max) | Percent) reads as Value [Max]
-- (UF.MigrateTextModes). "split" / "splitvp" (Forever Style's two-ended texts) read as their | modes.
-- > Value and > Percent ("rvalue" / "rpercent", Forever Style's power text at the bar's right end)
-- read as their plain modes.
UF.RIGHT_MODES = { rvalue = "value", rpercent = "percent" }
local HEALTH_TEXT_MODES = {
    { text = L["Off"],                      value = "none",        isRadio = true },
    { text = L["Percent"],                  value = "percent",     isRadio = true },
    { text = L["Percent | Value"],          value = "both",        isRadio = true },
    { text = L["Value"],                    value = "value",       isRadio = true },
    { text = L["Value [Max]"],              value = "valuemax",    isRadio = true },
    { text = L["Value | Percent"],          value = "valuepct",    isRadio = true },
    { text = L["Value | Health Lost"],      value = "valuelost",   isRadio = true },
    { text = L["Health Lost"],              value = "lost",        isRadio = true },
}

-- The text for every mode but Health Lost. cur and max go through ns.ShortNumber (in full up to 9999) and percent is
-- 0-100; all three can be secret, which SetFormattedText takes as they are.
function UF.FormatBarText(fs, mode, cur, percent, max, unit)
    mode = UF.RIGHT_MODES[mode] or mode
    if mode == "percent" then
        fs:SetFormattedText("%.0f%%", percent)
    elseif mode == "value" then
        fs:SetText(ns.ShortNumber(cur))
    elseif mode == "valuelost" then
        -- Value | Health Lost: "1234 | -216", the value alone at full health. A secret amount lost
        -- can't be checked for 0 in Lua, so it shows as it is.
        local lost
        if unit then
            lost = UnitHealthMissing(unit, true)
        elseif canaccessvalue(cur) and canaccessvalue(max) and cur and max then
            lost = max - cur
        end
        if lost == nil or (canaccessvalue(lost) and lost <= 0) then
            fs:SetText(ns.ShortNumber(cur))
        else
            fs:SetFormattedText("%s | -%s", ns.ShortNumber(cur), ns.ShortNumber(lost))
        end
    elseif mode == "both" or mode == "split" then
        fs:SetFormattedText("%.0f%% | %s", percent, ns.ShortNumber(cur))
    elseif mode == "valuepct" or mode == "splitvp" then
        fs:SetFormattedText("%s | %.0f%%", ns.ShortNumber(cur), percent)
    elseif mode == "valuemax" or mode == "valuemaxpct" then
        fs:SetFormattedText("%s [%s]", ns.ShortNumber(cur), ns.ShortNumber(max))
    else
        fs:SetText("")
    end
end

-- Health Lost: "-1234" or "-12K" from UnitHealthMissing. The value can be secret, so "-0" at full health can't
-- be caught in Lua: a step curve turns the health percent into the text's alpha (1 below full, 0 at
-- full). Every other mode puts the alpha back to 1.
function UF.LostCurve()
    if not UF.lostCurve then
        UF.lostCurve = C_CurveUtil.CreateCurve()
        UF.lostCurve:SetType(Enum.LuaCurveType.Step)
        UF.lostCurve:AddPoint(0, 1)
        UF.lostCurve:AddPoint(1, 0)
    end
    return UF.lostCurve
end
function UF.SetHealthLost(fs, unit)
    UF.LostCurve()
    fs:SetFormattedText("-%s", ns.ShortNumber(UnitHealthMissing(unit, true)))
    fs:SetAlpha(UnitHealthPercent(unit, true, UF.lostCurve))
end

-- Edit Mode samples: health is a 0-1 share of a 24000 sample maximum
function UF.SetSampleHealthLost(fs, health)
    local lost = math.floor((1 - health) * 24000 + 0.5)
    if lost > 0 then fs:SetFormattedText("-%s", ns.ShortNumber(lost)) else fs:SetText("") end
end

-- Power Text: Health Text's modes but Health Lost. A saved true or false (a checkbox's) reads as Value.
UF.POWER_TEXT_MODES = {}
for _, mode in ipairs(HEALTH_TEXT_MODES) do
    if mode.value ~= "lost" and mode.value ~= "valuelost" then UF.POWER_TEXT_MODES[#UF.POWER_TEXT_MODES + 1] = mode end
end
local POWER_MODE = { none = true, percent = true, value = true, both = true, valuepct = true, valuemax = true, valuemaxpct = true, split = true, splitvp = true,
                     rvalue = true, rpercent = true }
function UF.IsPowerTextMode(v) return POWER_MODE[v] or false end
function UF.PowerTextMode(v)
    if v == "valuemaxpct" then return "valuemax" end
    if POWER_MODE[v] then return v end
    return "value"
end

-- Current (Max) | Percent saved choices become Value [Max], once per profile,
-- in every frame's settings (unit, party, raid and boss frames keep healthText / powerText)
function UF.MigrateTextModes()
    local profile = ns.db and ns.db.profile
    if not profile or profile.textModes1113 then return end
    profile.textModes1113 = true
    local seen = {}
    local function Walk(t, depth)
        if seen[t] or depth > 8 then return end
        seen[t] = true
        for k, v in pairs(t) do
            if (k == "healthText" or k == "powerText") and v == "valuemaxpct" then
                t[k] = "valuemax"
            elseif type(v) == "table" then
                Walk(v, depth + 1)
            end
        end
    end
    Walk(profile, 0)
end
-- percent from the client's curve (power can be secret)
function UF.SetPowerText(fs, unit, powerType, mode)
    if mode == "value" then
        fs:SetText(ns.ShortNumber(UnitPower(unit, powerType)))
    elseif POWER_MODE[mode] and mode ~= "none" then
        UF.FormatBarText(fs, mode, UnitPower(unit, powerType),
            UnitPowerPercent(unit, powerType, false, CurveConstants.ScaleTo100), UnitPowerMax(unit, powerType))
    else
        fs:SetText("")
    end
end

--------------------------------------------------
-- 4. HELPERS
--------------------------------------------------
local frames = {}          -- unit -> frame
local pendingLayout = false   -- false, or the name of the last layout step a fight put off (UF.lastPendingWhy, for /fui perf trace)
local LayoutAuras          -- defined in 7

local function GetDb()
    if not ns.db or not ns.db.profile or not ns.db.profile.unitframes then return nil end
    return ns.db.profile.unitframes
end

-- Each frame's fonts, set on the settings' Fonts tabs and saved per frame style
-- (unitframes.frameFonts). Keys: the single frames' units, then party, raid, boss, flag and the
-- Player Cast Bar. Elements: names, health, level, power, cast, castTime, auras, auraCount (Core.lua
-- ns.UF_FONT_DEFAULTS).
UF.FONT_KEYS = { "player", "target", "focus", "pet", "targettarget", "focustarget", "party", "raid", "boss", "flag", "playercast" }
local SEED_FROM = { names = "font", health = "font", level = "font", power = "fontPower", cast = "fontCast",
                    castTime = "fontCast", auras = "auraFont", auraCount = "auraCountFont" }
-- Once per profile: every frame, in every saved frame style, starts from the shared fonts it used
function UF.SeedFrameFonts()
    local db = GetDb()
    if not db or rawget(db, "frameFontsSeeded") then return end
    db.frameFontsSeeded = true
    ns.SeedFont(db, "auraFont", "auraCountFont", "auraCountFontSeeded", true)
    local fields = { "face", "size", "flags", "enableShadow", "shadowX", "shadowY" }
    local function Into(fonts, raw)
        for _, key in ipairs(UF.FONT_KEYS) do
            local frame = fonts[key]
            if raw and frame == nil then frame = {}; fonts[key] = frame end
            for element, old in pairs(SEED_FROM) do
                local from = db[old]
                local to = frame[element]
                if raw and to == nil then to = {}; frame[element] = to end
                if type(from) == "table" then
                    for _, field in ipairs(fields) do
                        if from[field] ~= nil then to[field] = from[field] end
                    end
                end
            end
        end
    end
    Into(db.frameFonts, false)
    for _, slot in pairs(db.styleProfiles or {}) do
        if type(slot) == "table" and slot.frameFonts == nil then
            slot.frameFonts = {}
            Into(slot.frameFonts, true)
        end
    end
    db.castTimeSeeded = true   -- (castTime came from fontCast above)
end
-- Once per profile: the cast countdown, split off the spell name's font, starts as its copy
-- on every frame and in every saved frame style
function UF.SeedCastTime()
    local db = GetDb()
    if not db or rawget(db, "castTimeSeeded") then return end
    db.castTimeSeeded = true
    local fields = { "face", "size", "flags", "enableShadow", "shadowX", "shadowY" }
    local function Copy(frame, raw)
        local from = frame and frame.cast
        if type(from) ~= "table" then return end
        local to = frame.castTime
        if raw and to == nil then to = {}; frame.castTime = to end
        for _, field in ipairs(fields) do
            if from[field] ~= nil then to[field] = from[field] end
        end
    end
    for _, key in ipairs(UF.FONT_KEYS) do Copy(db.frameFonts[key], false) end
    for _, slot in pairs(db.styleProfiles or {}) do
        if type(slot) == "table" and type(slot.frameFonts) == "table" then
            for _, frame in pairs(slot.frameFonts) do
                if type(frame) == "table" then Copy(frame, true) end
            end
        end
    end
end
-- the saved, writable table (nil before the profile loads): the Edit Mode Fonts section writes here
function UF.FontDb(key, element)
    UF.Font(key, element)   -- seeds first
    local db = GetDb()
    local fonts = db and db.frameFonts
    local frame = fonts and fonts[key or "player"]
    return frame and frame[element]
end
-- the level's font at the name's size (Addon Style: the level sits before the name, so
-- they match); the ring styles size it to their disc themselves (UnitFramesRing.lua LayoutLevel)
UF.levelFonts = {}
function UF.LevelFont(key)
    local level, name = UF.Font(key, "level"), UF.Font(key, "names")
    if not (level and name) then return level end
    local t = UF.levelFonts[key] or {}
    UF.levelFonts[key] = t
    for k, v in pairs(level) do t[k] = v end
    t.size = name.size
    return t
end

-- the font of one text on one frame (key: a unit, "party", "raid", "boss", "flag" or "playercast":
-- the FlareUI Player Cast Bar)
function UF.Font(key, element)
    if not UF.fontsSeeded then
        UF.fontsSeeded = GetDb() ~= nil
        UF.SeedFrameFonts()
        UF.SeedCastTime()
    end
    local db = GetDb()
    local fonts = db and db.frameFonts
    -- the Player Cast Bar's own fonts (added after the first copy): it starts as the player frame's
    if key == "playercast" and fonts and rawget(fonts, "playercast") == nil then
        local from, to = fonts.player, fonts.playercast
        for element in pairs(ns.UF_FONT_DEFAULTS) do
            for _, field in ipairs({ "face", "size", "flags", "enableShadow", "shadowX", "shadowY" }) do
                to[element][field] = from[element][field]
            end
        end
    end
    local frame = fonts and fonts[key or "player"]
    return frame and frame[element] or ns.UFFontDefault(key or "player", element)
end

local function GetUnitDb(unit)
    -- while a settings preview lays out a sample (UF.DrawSample): the sample's own setup
    local sample = ns.UFSample
    if sample and sample.units[unit] then return sample.units[unit] end
    local db = GetDb()
    return db and db.units and db.units[unit]
end

-- Portrait: "none", "3d" or "class", a square taken from the bars. The ring styles always have one,
-- in the ring, and the bars keep their full width.
local function PortraitMode(f)
    local udb = GetUnitDb(f.fuiUnit)
    local mode = (f.Portrait and udb and udb.portrait) or "none"
    if mode == "model" then mode = "3d" end   -- a saved 3D model (no longer offered) draws as 2D
    if mode == "none" and ns.UFRing and ns.UFRing.Applies(f) then mode = "3d" end
    return mode
end

local function PortraitSpace(f)
    if ns.UFRing and ns.UFRing.Applies(f) then return 0 end
    if PortraitMode(f) == "none" then return 0 end
    local udb = GetUnitDb(f.fuiUnit)
    return ((udb and udb.height) or 44) - 2 * INSET + PORTRAIT_GAP
end

-- The frame icons: one Show switch each in Edit Mode (udb.icons[key].shown); their places are fixed
local ICON_UI = {
    order = { "rest", "leader", "pvp", "pvpTimer", "classification", "highSkull", "quest", "raidIcon", "readyCheck",
              "happiness" },
    defs = {
        rest           = { label = L["Resting"],          field = "RestIcon" },
        leader         = { label = L["Leader"],           field = "LeaderIcon" },
        pvp            = { label = L["PvP Flag"],         field = "PvPIcon" },
        classification = { label = L["Elite & Rare"],     field = "ClassIcon", noRing = true },
        quest          = { label = L["Quest Objective"],  field = "QuestIcon" },
        raidIcon       = { label = L["Raid Markers"],      field = "RaidIcon" },
        happiness      = { label = L["Pet Happiness"],    field = "Happiness" },
        -- noRing: not in the ring styles (the dragon frame shows elites); ring: only in them
        readyCheck     = { label = L["Ready Check"],      field = "ReadyIcon" },
        pvpTimer       = { label = L["PvP Timer"],        default = false },
        -- the ring's level skull for a "??" unit
        highSkull      = { label = L["High Level Skull"], ring = true },
    },
    -- Blizzard's ready check marks
    READY = {
        ready    = _G.READY_CHECK_READY_TEXTURE or "UI-LFG-ReadyMark",
        notready = _G.READY_CHECK_NOT_READY_TEXTURE or "UI-LFG-DeclineMark",
        waiting  = _G.READY_CHECK_WAITING_TEXTURE or "UI-LFG-PendingMark",
    },
    HAPPINESS_GAP = 4,   -- the happiness face outside the frame
    HAPPINESS_PLATE_SIZE = 20,   -- ... and its size beside Forever Style's small pet frame
    READY_HOLD = 6,   -- seconds a finished check's results stay up
}

-- The icons a frame has, in dialog order
function ICON_UI.List(unit)
    local info, list = UNITS[unit], {}
    local ind = info and info.indicators or {}
    for _, key in ipairs(ICON_UI.order) do
        local has
        if key == "raidIcon" then has = not info.noRaidIcon
        elseif key == "happiness" then has = info.happiness
        elseif key == "quest" then has = ind.quest
        else has = ind[key] end
        if has then list[#list + 1] = key end
    end
    return list
end

function ICON_UI.Store(unit, key, create)
    local udb = GetUnitDb(unit)
    if not udb then return nil end
    if create then
        udb.icons = udb.icons or {}
        udb.icons[key] = udb.icons[key] or {}
    end
    return udb.icons and udb.icons[key]
end

-- Where the pet's happiness face sits. The styled pet: always right of the frame on Forever Style;
-- centre or right on FlareUI Style (right by default). The simple frame: any of the three.
function ICON_UI.HappinessPlace(unit)
    local store = ICON_UI.Store(unit, "happiness")
    local place = store and store.place
    -- beside the frame on the right by default, in Addon Style too
    if not UNITS[unit].styledPet then return place or "RIGHT" end
    if ns.UFRing.PlateOn() or place ~= "CENTER" then return "RIGHT" end
    return place
end

-- the pet's Happiness Position and switch, for the party frames (their player tile shows the face
-- while Hide Player Frame in a Party hides the pet frame, PartyFrames.lua PF.LayoutPetHappiness)
function UF.PetHappinessPlace() return ICON_UI.HappinessPlace("pet") end
function UF.PetHappinessShown() return ICON_UI.Shown("pet", "happiness") end

-- every icon starts shown except those with default = false
function ICON_UI.Shown(unit, key)
    local store = ICON_UI.Store(unit, key)
    if store and store.shown ~= nil then return store.shown end
    return ICON_UI.defs[key].default ~= false
end

-- Threat Glow / Combat Glow (Look; udb.threatGlow, udb.combatGlow): on unless saved off
function UF.GlowOn(unit, key)
    local udb = GetUnitDb(unit)
    return not (udb and udb[key] == false)
end

-- Threat Glow and Rest & Combat Glow were once Icons switches (udb.icons[key].shown): one saved off
-- leaves its Look switch off. Once: the old entries go (also in each stored frame style).
function UF.MigrateGlows()
    local db = GetDb()
    if not db then return end
    local function Units(units)
        if type(units) ~= "table" then return end
        for unit, udb in pairs(units) do
            local icons = type(udb) == "table" and udb.icons
            if type(icons) == "table" then
                local threat, status = icons.threatGlow, icons.statusGlow
                -- (the player's threat goes with Combat Glow)
                if unit ~= "player" and type(threat) == "table" and threat.shown == false and rawget(udb, "threatGlow") == nil then
                    udb.threatGlow = false
                end
                if unit == "player" and type(status) == "table" and status.shown == false and rawget(udb, "combatGlow") == nil then
                    udb.combatGlow = false
                end
                icons.threatGlow, icons.statusGlow = nil, nil
            end
        end
    end
    Units(db.units)
    for _, slot in pairs(db.styleProfiles or {}) do
        if type(slot) == "table" then Units(slot.units) end
    end
end

function ICON_UI.Place(region, width, height, point, relativeTo, relativePoint, x, y)
    region:ClearAllPoints()
    region:SetSize(width, height)
    region:SetPoint(point, relativeTo, relativePoint, x, y)
end

-- Percent curve (0..1 -> 0..100) so UnitHealthPercent's secret result can be shown directly
local percentCurve = CurveConstants.ScaleTo100

-- An unknown name falls back to FlareUI Dark; mirrored: its right-to-left gradient file
local function GetBarTexture(name, mirrored)
    if not (name and name ~= "" and LSM:IsValid("statusbar", name)) then name = DEFAULT_TEXTURE end
    if name == "FlareUI Flat" and UF.basePalette == "blizzard" then return UF.PALETTES.blizzard.texture end
    if mirrored and name == "FlareUI Dark" then return "Interface\\AddOns\\FlareUI\\Media\\Bars\\FlareUI-Forever-Mirrored.tga" end
    if mirrored and name == "FlareUI Light" then return "Interface\\AddOns\\FlareUI\\Media\\Bars\\FlareUI-Forever-Bright-Mirrored.tga" end
    return LSM:Fetch("statusbar", name) or "Interface\\TargetingFrame\\UI-StatusBar"
end

-- An unknown border name falls back to the default
-- "None" (first in every Border list): no border file; ApplyBorderStyle then clears the
-- edge and the bars keep their place
UF.NO_BORDER = "None"
local function GetBorderFile(name)
    if name == UF.NO_BORDER then return nil end
    if not (name and name ~= "" and LSM:IsValid("border", name)) then name = DEFAULT_BORDER end
    return LSM:Fetch("border", name) or BORDER_FILE
end

-- fixed bronze at rest, a status colour (threat) otherwise
-- (each tint forgets the glow UF.SetBorderGlow remembers, so its next call sets the border again)
local function ResetBorderTint(border)
    local c = DEFAULT_BORDER_COLOR
    border.fuiGlow = nil
    border:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
end

local function SetBorderTint(border, r, g, b)
    border.fuiGlow = nil
    border:SetBackdropBorderColor(r, g, b, 1)
end

-- Threat Glow / Combat Glow: the frame's own border in a colour, pulsing (the soft
-- pulse of the portrait ring's tint); no colour stops it and gives the border back its bronze. An
-- alpha animation on the border's own frame (no children, not secure): fine in a fight.
UF.GLOW_PULSE = { 0.5, 1, 1.2 }   -- alpha from, to, seconds each way: the ring tint's beat and direction (STATUS_PULSE, dim to bright), so both pulse together
UF.COMBAT_RGB = { 1.0, 0.22, 0.18 }   -- the ring's combat red (UnitFramesRing.lua STATUS_COMBAT)
function UF.SetBorderGlow(border, r, g, b)
    local pulse = border.FlareUI_Pulse
    -- (threat events come often in a fight: the same state again redraws nothing; border.fuiGlow is
    -- false at rest, true with the colour in fuiGlowR / G / B)
    if not r then
        if border.fuiGlow == false then return end
        if pulse then pulse:Stop() end
        border:SetAlpha(1)
        ResetBorderTint(border)
        border.fuiGlow = false
        return
    end
    if not (border.fuiGlow == true and border.fuiGlowR == r and border.fuiGlowG == g and border.fuiGlowB == b) then
        SetBorderTint(border, r, g, b)
        border.fuiGlow, border.fuiGlowR, border.fuiGlowG, border.fuiGlowB = true, r, g, b
    end
    if not pulse then
        pulse = border:CreateAnimationGroup()
        pulse:SetLooping("BOUNCE")
        local fade = pulse:CreateAnimation("Alpha")
        fade:SetFromAlpha(UF.GLOW_PULSE[1])
        fade:SetToAlpha(UF.GLOW_PULSE[2])
        fade:SetDuration(UF.GLOW_PULSE[3])
        fade:SetSmoothing("IN_OUT")
        border.FlareUI_Pulse = pulse
    end
    if not pulse:IsPlaying() then
        pulse:Play()
        -- in step with the frame's ring (UnitFramesRing.lua Ring.SyncPulses)
        local f = border:GetParent()
        if ns.UFRing and ns.UFRing.SyncPulses and f then ns.UFRing.SyncPulses(f) end
    end
end

-- Edge and inset for a bar of this inner height: under 22 px the 16 px corners overlap, so both
-- shrink (FlareUI Thin's 8 px corners fit any bar)
local function BorderFit(innerHeight, edgeFile)
    if edgeFile and ns.BorderEdgeSize(edgeFile, BORDER_SIZE) ~= BORDER_SIZE then
        return ns.BorderEdgeSize(edgeFile, BORDER_SIZE), INSET
    end
    local total = innerHeight + 2 * INSET
    if total >= 22 then return BORDER_SIZE, INSET end
    local edge = math.max(6, math_floor(total * 2 / 3))
    return edge, INSET * edge / BORDER_SIZE
end

-- height: the bordered frame's height (BorderFit's rule). The thick edge fades on its inner side,
-- leaving a see-through seam, so it sits one scaled pixel in, over the bars' edges.
local function ApplyBorderStyle(border, edgeFile, height)
    border.fuiGlow = nil   -- a new backdrop: UF.SetBorderGlow sets its colour again
    -- None: no edge at all (its tint calls do nothing without a backdrop)
    if not edgeFile then border:SetBackdrop(nil) return end
    local edge, thick = BORDER_SIZE, true
    if ns.BorderEdgeSize(edgeFile, BORDER_SIZE) ~= BORDER_SIZE then
        edge, thick = ns.BorderEdgeSize(edgeFile, BORDER_SIZE), false
    elseif height and height < 22 then
        edge = math.max(6, math_floor(height * 2 / 3))
    end
    local _, rel = border:GetPoint(1)
    rel = rel or border:GetParent()
    local d = thick and edge / BORDER_SIZE or 0
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", rel, "TOPLEFT", d, -d)
    border:SetPoint("BOTTOMRIGHT", rel, "BOTTOMRIGHT", -d, d)
    border:SetBackdrop({ edgeFile = edgeFile, edgeSize = edge })
    ResetBorderTint(border)
end

local function CreateBar(parent, level)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetFrameLevel(level)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetVertexColor(0.15, 0.15, 0.15, UF.BAR_BG_OPACITY / 100)
    return bar
end

-- "Background Opacity": the bars' empty part, in percent; 0 on the plate, whose slot shows there
UF.BAR_BG_OPACITY = 90
function UF.DefaultBgOpacity(unit)
    local plate = ns.UFRing and ns.UFRing.PlateOn() and ns.UFRing.PLATE_UNITS[unit] and ns.UFRing.Applies(frames[unit])
    return plate and 0 or UF.BAR_BG_OPACITY
end

function UF.SetBarBackground(bar, percent)
    if not bar.bg then return end
    if percent == nil then percent = UF.BAR_BG_OPACITY end
    bar.bg:SetAlpha(1)
    bar.bg:SetVertexColor(0.15, 0.15, 0.15, math.max(0, math.min(100, percent)) / 100)
end

function UF.BgOpacitySetting(default, get, set)
    -- ("Background Opacity" would wrap onto two lines in Edit Mode)
    return { name = L["Background"], search = L["Background Opacity"], kind = LEM.SettingType.Slider, default = default,
        minValue = 0, maxValue = 100, valueStep = 5,
        formatter = function(value) return value end,   -- plain: "100%" clips the value box
        get = get, set = set,
        desc = L["How dark the empty part of the bars is."] }
end

-- Forever Style's Power Height: moves the plate's separator (UnitFramesRing.lua
-- PlateRows). In the plate's art pixels; the step below the least is Off. read() gives the stored
-- platePower, store(value) saves it (0 = Off); onPlate() shows it.
function UF.PlatePowerSetting(read, store, onPlate)
    local P = ns.UFRing.PLATE_POWER
    return { name = L["Power Height"], search = L["Power Bar Height"], kind = LEM.SettingType.Slider, default = P.default,
        minValue = P.min - 1, maxValue = P.max, valueStep = 1,
        formatter = function(value) return value < P.min and _G.OFF or value end,
        get = function()
            local value = ns.UFRing.PlatePowerValue(read())
            return value == 0 and P.min - 1 or value
        end,
        set = function(_, value) store(value < P.min and 0 or value) end,
        hidden = function() return not onPlate() end }
end

-- Which buffs a frame leaves out, by their full duration: one choice, as Blizzard's filter for a longest
-- duration always leaves out the permanent ones too
function UF.HideBuffsSetting(default, get, set)
    return { name = L["Hide Buffs"], kind = LEM.SettingType.Dropdown, default = default,
        values = {
            { text = L["Off"], value = "OFF", isRadio = true },
            { text = L["Permanent"], value = "PERMANENT", isRadio = true },
            { text = L["Longer Than 15 Minutes"], value = "900", isRadio = true },
            { text = L["Longer Than 10 Minutes"], value = "600", isRadio = true },
            { text = L["Longer Than 5 Minutes"], value = "300", isRadio = true },
            { text = L["Longer Than 1 Minute"], value = "60", isRadio = true },
        },
        get = get, set = set,
        desc = L["Leaves long buffs off this frame:\n* Permanent: buffs with no duration\n* Longer Than: buffs whose full duration is longer, and permanent ones"] }
end

-- Right below Absorb Texture
function UF.ClassColorSetting(get, set)
    return { name = L["Class Colours"], kind = LEM.SettingType.Checkbox, default = true, get = get, set = set,
        desc = L["Players' health bars in their class colour. Off: green. NPCs keep their reaction colour."] }
end

-- Always right below Background Opacity
function UF.SmoothBarsSetting(get, set)
    -- (search finds it by its longer name too)
    return { name = L["Bar Animations"], search = L["Smooth Bar Animations"], kind = LEM.SettingType.Checkbox, default = false,
        get = function() return get() and true or false end, set = set,
        desc = L["Health and power glide to their new value instead of jumping there."] }
end

-- A font string with a starting font: SetText on one with no font throws ("Font not set"), and an
-- event (a cast already running at login) can reach it before the frame's real font is applied.
-- No font object, so no shadow or colour the later ApplyFont / ns.SetFont would have to undo.
-- (a plain font OBJECT, not SetFont: a font set on the string itself wins over every font object set
-- after it, so ApplyFont's family would never change the size or outline)
function UF.NewText(parent, layer)
    if not UF.plainFont then
        UF.plainFont = CreateFont("FlareUI_UFPlainText")
        UF.plainFont:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
        UF.plainFont:SetShadowOffset(0, 0)
    end
    local text = parent:CreateFontString(nil, layer or "OVERLAY")
    text:SetFontObject(UF.plainFont)
    return text
end

local function ApplyFont(fontString, fontDb, sizeDelta)
    local path = ns.GetFontPath(fontDb and fontDb.face or "Friz Quadrata TT")
    local flags = fontDb and fontDb.flags or "OUTLINE"
    if flags == "NONE" then flags = "" end
    -- a family: names of other players keep their Cyrillic and Chinese / Korean letters
    ns.SetFontFamily(fontString, path, (fontDb and fontDb.size or 12) + (sizeDelta or 0), flags)
    ns.ApplyShadow(fontString, fontDb)
end

-- A secret class still colours: GetClassColor takes it, and the bar takes the secret r, g, b.
-- pcall covers a missing colour (nil) or an unreadable one.
local function SecretClassRGB(classFile)
    return C_ClassColor.GetClassColor(classFile):GetRGB()
end

-- Health bar colour: class colour for players (green with Class Color off), reaction colour for
-- NPCs. A secret reaction falls back to friendly. The class is secret for a chained unit
-- (targettarget, focustarget) whenever a unit in the chain is an NPC: it keeps Blizzard's class
-- colour then (no custom class colours, which need a readable class).
local function GetHealthColor(unit, classColor)
    if not UnitIsConnected(unit) then return GREY[1], GREY[2], GREY[3] end
    if UnitIsPlayer(unit) and not classColor then return ns.HEALTH_GREEN[1], ns.HEALTH_GREEN[2], ns.HEALTH_GREEN[3] end
    if UnitIsPlayer(unit) then
        local _, classFile = UnitClass(unit)
        if not canaccessvalue(classFile) then
            local ok, r, g, b = pcall(SecretClassRGB, classFile)
            if ok then return r, g, b end
        elseif classFile then
            local override = ns.ClassHealthOverride(classFile)
            if override then return override[1], override[2], override[3] end
            local color = C_ClassColor.GetClassColor(classFile)
            if color then return color:GetRGB() end
        end
    end
    if UnitIsTapDenied(unit) then return GREY[1], GREY[2], GREY[3] end
    local reaction = Readable(UnitReaction(unit, "player"))
    local c = reaction and REACTION[reaction] or REACTION[5]
    return c[1], c[2], c[3]
end

local function GetPowerColor(unit)
    local powerType, powerToken = UnitPowerType(unit)
    local r, g, b = ns.PowerColor(powerToken, powerType)
    if r then return r, g, b end
    local c = POWER_FALLBACK[Readable(powerToken) or "MANA"] or POWER_FALLBACK.MANA
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
    local function Park()
        pcall(ns.RawHide, frame)
        pcall(frame.SetParent, frame, hiddenParent)
    end
    if InCombatLockdown() then
        -- a /reload mid-fight: parked as soon as the fight ends
        local waiter = CreateFrame("Frame")
        waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
        waiter:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            Park()
        end)
    else
        Park()
    end
    hooksecurefunc(frame, "Show", function(f) if not InCombatLockdown() then ns.RawHide(f) end end)
end

-- Gamepad UI: the target menu opens on TargetFrame and closes if it is hidden, so TargetFrame stays
-- shown, silent, invisible and mouse-deaf, pinned over this target frame. Out of combat only.
local function KeepAsMenuOwner(name, over)
    local frame = _G[name]
    if not frame or frame.FlareUI_Hidden then return end
    if InCombatLockdown() then
        local waiter = CreateFrame("Frame")
        waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
        waiter:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            KeepAsMenuOwner(name, over)
        end)
        return
    end
    frame.FlareUI_Hidden = true
    pcall(frame.UnregisterAllEvents, frame)
    for _, key in ipairs({ "healthbar", "manabar", "spellbar", "castBar", "totFrame", "petFrame", "powerBarAlt" }) do
        local child = frame[key]
        if child and child.UnregisterAllEvents then pcall(child.UnregisterAllEvents, child) end
    end
    frame:SetAlpha(0)
    local function Deafen(f)
        if f.IsMouseEnabled and f:IsMouseEnabled() then f:EnableMouse(false) end
        if f.IsMouseClickEnabled and f:IsMouseClickEnabled() then f:SetMouseClickEnabled(false) end
        for _, child in ipairs({ f:GetChildren() }) do Deafen(child) end
    end
    Deafen(frame)
    local placing = false
    local function Pin()
        if placing or InCombatLockdown() then return end
        placing = true
        local clear, setPoint = frame.ClearAllPointsBase or frame.ClearAllPoints, frame.SetPointBase or frame.SetPoint
        clear(frame)
        setPoint(frame, "TOPLEFT", over, "TOPLEFT")
        setPoint(frame, "BOTTOMRIGHT", over, "BOTTOMRIGHT")
        placing = false
    end
    Pin()
    hooksecurefunc(frame, "SetPoint", Pin)
    frame:Show()
    hooksecurefunc(frame, "Hide", function(f) if not InCombatLockdown() then f:Show() end end)
end

-- the parked TargetFrame plays no target-select sounds, so they play here
do
    local listener = CreateFrame("Frame")
    listener:RegisterEvent("PLAYER_TARGET_CHANGED")
    listener:SetScript("OnEvent", function(self)
        local hadTarget = self.hadTarget
        self.hadTarget = UnitExists("target")
        local blizzard = _G.TargetFrame
        if not (blizzard and blizzard.FlareUI_Hidden) then return end
        if not self.hadTarget then
            -- soft target changes stay silent, as on Blizzard's frame
            if hadTarget and not IsTargetLoose() then PlaySound(SOUNDKIT.INTERFACE_SOUND_LOST_TARGET_UNIT, nil, true) end
            return
        end
        local interaction = C_PlayerInteractionManager
        if interaction and interaction.IsReplacingUnit and interaction.IsReplacingUnit() then return end
        if Readable(UnitIsEnemy("target", "player")) then
            PlaySound(SOUNDKIT.IG_CREATURE_AGGRO_SELECT)
        elseif Readable(UnitIsFriend("player", "target")) then
            PlaySound(SOUNDKIT.IG_CHARACTER_NPC_SELECT)
        else
            PlaySound(SOUNDKIT.IG_CREATURE_NEUTRAL_SELECT)
        end
    end)
end

--------------------------------------------------
-- 5. UPDATERS (all secret-safe: values go straight into widgets)
--------------------------------------------------
local function UpdateName(f)
    -- First Name or Full Name by the frame's pick (UF.ShowsFullName)
    local unit = f.fuiUnit
    local name = ns.UnitDisplayName(unit, nil, UF.ShowsFullName(f))
    if canaccessvalue(name) and not name then name = "" end
    f.Name:SetText(name)
    ns.NameAbove.SetName(f, GetUnitDb(unit), unit)   -- Name Above Frames (BarText.lua)
end

-- BAR TEXT (BarText.lua): each bar's Left, Middle and Right slot texts. The Right slot
-- keeps the bar's old text (HealthText, PowerText, ShiftManaText); Left and Middle are its "Left" and
-- "Mid". Off the plate Left is the name side (Mirror puts it on the right), on the plate the bar's end.
-- VALUES ON MOUSEOVER (11-20, every frame's Text section, off; Blizzard's own status text option): the
-- health and power numbers sit on a layer of their own that shows only while the pointer is on the
-- frame. Names and the level stay. Edit Mode always shows them. texts: the font strings to move there.
-- (11-23, Kelvan) one layer per bar the texts sat on: a single layer took the first text's bar, and
-- when that was the druid's Mana on Shapeshift bar (hidden in caster form) every number hid with it.
-- f.ValueLayer stays the first one made, f.ValueLayers holds them all (by the texts' own bar).
function UF.SetValueLayersAlpha(f, a)
    for _, layer in pairs(f.ValueLayers or {}) do
        if layer:GetAlpha() ~= a then layer:SetAlpha(a) end
    end
end
function UF.ValuesOnHover(f, on, texts)
    if not f then return end
    if not on and not f.ValueLayer then return end
    if not f.ValueLayers then
        f.ValueLayers = {}
        f:HookScript("OnEnter", function(self) if self.valuesOnHover then UF.SetValueLayersAlpha(self, 1) end end)
        f:HookScript("OnLeave", function(self)
            if self.valuesOnHover and not ns.EditPreviewing() then UF.SetValueLayersAlpha(self, 0) end
        end)
    end
    for _, fs in ipairs(texts) do
        if fs then
            -- the bar the text belongs to: where it sat before its first move onto a layer
            local home = fs.FlareUI_ValueHome or fs:GetParent()
            fs.FlareUI_ValueHome = home
            local layer = f.ValueLayers[home]
            if not layer then
                layer = CreateFrame("Frame", nil, home)
                layer:SetAllPoints(home)
                f.ValueLayers[home] = layer
                f.ValueLayer = f.ValueLayer or layer
            end
            -- the layer above its bar's level, as the texts were
            layer:SetFrameLevel(home:GetFrameLevel() + 1)
            if fs:GetParent() ~= layer then fs:SetParent(layer) end
        end
    end
    f.valuesOnHover = on and true or nil
    UF.SetValueLayersAlpha(f, (not on or ns.EditPreviewing() or f:IsMouseOver()) and 1 or 0)
    UF.WatchValuesHover(f, on)
end
-- (11-22) the frame's own OnEnter/OnLeave miss the pointer when a part of the frame takes the mouse (the
-- player frame's numbers never came back), and nothing looked again after Edit Mode closed (one hover
-- was needed): a light watcher, ten checks a second, only for frames with the option on, follows the
-- pointer itself
UF.hoverValueFrames = setmetatable({}, { __mode = "k" })
function UF.WatchValuesHover(f, on)
    UF.hoverValueFrames[f] = on and true or nil
    local watch = UF.hoverWatch
    if not watch then
        if not on then return end
        watch = CreateFrame("Frame")
        UF.hoverWatch = watch
        watch:SetScript("OnUpdate", function(self, elapsed)
            self.wait = (self.wait or 0) + elapsed
            if self.wait < 0.1 then return end
            self.wait = 0
            local previewing = ns.EditPreviewing()
            for frame in pairs(UF.hoverValueFrames) do
                if frame.ValueLayers and frame.valuesOnHover then
                    UF.SetValueLayersAlpha(frame, (previewing or (frame:IsVisible() and frame:IsMouseOver())) and 1 or 0)
                end
            end
        end)
    end
    watch:SetShown(next(UF.hoverValueFrames) ~= nil)
end
-- the row in each frame's Text section
function UF.ValuesOnHoverSetting(get, set)
    local LEM = LibStub("FlareEditMode")
    return { name = L["Values on Mouseover"], kind = LEM.SettingType.Checkbox, default = false,
        desc = L["The health and power numbers show only while you point at the frame, as Blizzard's own option does."],
        get = function() return get() and true or false end, set = set }
end

UF.SLOT_KEYS = { health = "HealthText", power = "PowerText", mana = "ShiftManaText" }
-- the slots' font strings per bar, kept on the frame (read on every health and power tick)
UF.SLOT_FIELDS = {
    health = { "HealthTextLeft", "HealthTextMid" }, power = { "PowerTextLeft", "PowerTextMid" },
    mana = { "ShiftManaTextLeft", "ShiftManaTextMid" },
}
function UF.SlotTexts(f, bar)
    local key = UF.SLOT_KEYS[bar]
    if not (key and f[key]) then return nil end
    local fields = UF.SLOT_FIELDS[bar]
    local left, middle, right = f[fields[1]], f[fields[2]], f[key]
    f.btTexts = f.btTexts or {}
    local t = f.btTexts[bar]
    if not (t and t.left == left and t.middle == middle and t.right == right) then
        t = { left = left, middle = middle, right = right }
        f.btTexts[bar] = t
    end
    return t
end
-- the bar's slots for this layout (read again at each layout: f.btSlots = nil)
function UF.TextSlots(f, bar)
    f.btSlots = f.btSlots or {}
    if not f.btSlots[bar] then f.btSlots[bar] = ns.BarText.Slots(GetUnitDb(f.fuiUnit), bar, f.btStyle or "plain", UF.FirstNameOnly(f.fuiUnit), nil, f.fuiUnit) end
    return f.btSlots[bar]
end
-- a "name" from the defaults or an old setup: First Name on the focus and target-of frames,
-- and everywhere for a setup that had Full Player Names off
function UF.FirstNameOnly(unit)
    local uf = GetDb()
    if uf and uf.fullNames == false then return true end
    return unit == "focus" or unit == "targettarget" or unit == "focustarget"
end
-- whether the frame shows the full name: Forever Style everywhere but the focus frame; the others by
-- the health bar's name pick
function UF.ShowsFullName(f)
    -- the focus and target-of frames show the first name in every style
    if f.btStyle == "plate" then
        local unit = f.fuiUnit
        return unit ~= "focus" and unit ~= "targettarget" and unit ~= "focustarget"
    end
    local slots = UF.TextSlots(f, "health")
    for _, slot in ipairs(ns.BarText.SLOTS) do
        local pick = ns.BarText.NameOf(slots[slot])
        if pick then return pick == "fullname" end
    end
    return false
end
-- whether any of a bar's slots shows this item (slots: UF.TextSlots)
function UF.SlotsWant(slots, item)
    return (slots.left[item] or slots.middle[item] or slots.right[item]) and true or false
end
-- what the slots read: the unit's numbers (secret ones as they are), or a sample's share of max.
-- slots (optional): only what they show is read; the rest stays nil, which Fill skips
-- A nameplate supplies the values already read for its bar and the fields selected at layout.
function UF.HealthSource(unit, slots, src)
    local showPercent, showLost
    if src then
        showPercent, showLost = src.showPercent, src.showLost
    else
        src = UF.healthSrc or {}
        UF.healthSrc = src
        src.cur, src.max = UnitHealth(unit), UnitHealthMax(unit)
        showPercent = not slots or UF.SlotsWant(slots, "percent")
        showLost = not slots or UF.SlotsWant(slots, "lost")
    end
    src.percent, src.lost, src.lostAlpha = nil, nil, nil
    if showPercent then src.percent = UnitHealthPercent(unit, true, percentCurve) end
    if showLost then
        src.lost = UnitHealthMissing(unit, true)
        src.lostAlpha = UnitHealthPercent(unit, true, UF.LostCurve())
    end
    return src
end
function UF.PowerSource(unit, powerType, slots)
    local src = UF.powerSrc or {}
    UF.powerSrc = src
    src.cur, src.max = UnitPower(unit, powerType), UnitPowerMax(unit, powerType)
    src.percent = nil
    if not slots or UF.SlotsWant(slots, "percent") then
        src.percent = UnitPowerPercent(unit, powerType, false, CurveConstants.ScaleTo100)
    end
    src.lost, src.lostAlpha = nil, nil
    return src
end
function UF.SampleSource(share, max)
    local src = UF.sampleSrc or {}
    UF.sampleSrc = src
    src.cur, src.max, src.percent = math_floor(share * max), max, share * 100
    src.lost = max - src.cur
    src.lostAlpha = src.lost > 0 and 1 or 0
    return src
end
-- fills a bar's slots; status (Dead, Offline) instead of the numbers, in the slot that has them
function UF.FillSlots(f, bar, src, status)
    local texts = UF.SlotTexts(f, bar)
    if not texts then return end
    local slots = UF.TextSlots(f, bar)
    local BT = ns.BarText
    local statusSlot = status and BT.StatusSlot(slots) or "middle"
    for _, slot in ipairs(BT.SLOTS) do
        local fs = texts[slot]
        -- the name (or the level standing for it) shares this slot: "/ " between them
        local prefix = (bar == "health" and f.btPrefixSlot == slot) and "/ " or nil
        if status then
            fs:SetAlpha(1)
            fs:SetText(slot == statusSlot and ((prefix or "") .. status) or "")
        elseif src then
            BT.Fill(fs, slots[slot], src, prefix)
        else
            fs:SetText("")
        end
    end
end

-- Places a bar's slot texts; on the health bar off the plate, the name and the level before it too.
-- pad: more room at the name side's end (the ring's portrait overlaps it).
function UF.PlaceSlots(f, bar, barFrame, mirror, plate, pad, levelInRow)
    local texts = UF.SlotTexts(f, bar)
    if not texts then return end
    local BT = ns.BarText
    local slots = UF.TextSlots(f, bar)
    local swap = mirror and not plate
    local side = { left = swap and "RIGHT" or "LEFT", middle = "CENTER", right = swap and "LEFT" or "RIGHT" }
    local function Inset(at)
        local inset = TEXT_INSET + ((not plate and at == side.left) and (pad or 0) or 0)
        return (at == "LEFT" and inset) or (at == "RIGHT" and -inset) or 0
    end
    for _, slot in ipairs(BT.SLOTS) do
        local fs, at = texts[slot], side[slot]
        fs:ClearAllPoints()
        fs:SetJustifyH(at)
        fs:SetWordWrap(false)
        fs:SetPoint(at, barFrame, at, Inset(at), 0)
    end
    if bar ~= "health" then return end
    f.btPrefixSlot, f.btNameNextTo = nil, nil
    if plate then return end

    -- the name: in the first slot holding a name pick, alone there. Show Level puts the level before
    -- it (Addon Style); a mirrored frame keeps it after the name, at the bar's end
    local udb = GetUnitDb(f.fuiUnit)
    local nameSlot
    for _, slot in ipairs(BT.SLOTS) do
        if BT.NameOf(slots[slot]) then nameSlot = slot break end
    end
    -- (11-20: off the plate the name slot alone decides; Show Name is the plate's name box)
    local showName = true
    local lead = levelInRow and f.Level or nil
    local piece = (showName and f.Name) or lead
    if piece == lead then lead = nil end
    f.Name:SetShown((showName and nameSlot) and true or false)
    if levelInRow then f.Level:SetShown(nameSlot and true or false) end
    if not (nameSlot and piece) then return end
    local at = side[nameSlot]
    local after = swap
    -- the next text across the bar, which the name stops short of
    local other = nameSlot == "left" and "right" or "left"
    -- (with no numbers across, the other side's text: empty, or Dead / Offline there: BT.StatusSlot)
    local nextTo = (nameSlot ~= "middle") and ((BT.HasNumbers(slots.middle) and texts.middle)
        or texts[other]) or nil
    piece:SetJustifyH(at == "RIGHT" and "RIGHT" or (at == "CENTER" and "CENTER" or "LEFT"))
    if at == "LEFT" then
        if lead and not after then
            lead:SetPoint("LEFT", barFrame, "LEFT", Inset("LEFT"), 0)
            piece:SetPoint("LEFT", lead, "RIGHT", 3, 0)
        else
            piece:SetPoint("LEFT", barFrame, "LEFT", Inset("LEFT"), 0)
            if lead then lead:SetPoint("LEFT", piece, "RIGHT", 3, 0) end
        end
        if piece == f.Name and not (lead and after) then
            if nextTo then
                f.Name:SetPoint("RIGHT", nextTo, "LEFT", -4, 0)
                f.btNameNextTo = nextTo
            else
                f.Name:SetPoint("RIGHT", barFrame, "RIGHT", -TEXT_INSET, 0)
            end
        end
    elseif at == "RIGHT" then
        if lead and after then
            lead:SetPoint("RIGHT", barFrame, "RIGHT", Inset("RIGHT"), 0)
            piece:SetPoint("RIGHT", lead, "LEFT", -3, 0)
        else
            piece:SetPoint("RIGHT", barFrame, "RIGHT", Inset("RIGHT"), 0)
            if lead then lead:SetPoint("RIGHT", piece, "LEFT", -3, 0) end
        end
        if piece == f.Name and not (lead and not after) then
            if nextTo then
                f.Name:SetPoint("LEFT", nextTo, "RIGHT", 4, 0)
                f.btNameNextTo = nextTo
            else
                f.Name:SetPoint("LEFT", barFrame, "LEFT", TEXT_INSET, 0)
            end
        end
    else
        piece:SetPoint("CENTER", barFrame, "CENTER", 0, 0)
        if lead then
            if after then lead:SetPoint("LEFT", piece, "RIGHT", 3, 0) else lead:SetPoint("RIGHT", piece, "LEFT", -3, 0) end
        end
    end
end

local function UpdateLevel(f)
    local unit = f.fuiUnit
    local udb = GetUnitDb(unit)
    if not (udb and udb.showLevel) then f.Level:SetText("") return end
    local level = ns.UnitShownLevel(unit)
    local classification = Readable(UnitClassification(unit))
    -- a ring that shows the rank (the dragon, the star): the number only, as on Blizzard's frame, and
    -- "21+" does not fit the disc
    local ring = ns.UFRing and ns.UFRing.ShowsRank(f)
    local suffix = ""
    if not ring and (classification == "elite" or classification == "rareelite") then suffix = "+" end
    if not ring and (classification == "rare" or classification == "rareelite") then suffix = "R" .. suffix end
    if canaccessvalue(level) and level then
        if level <= 0 then
            ns.SetHighLevelText(f.Level, udb.icons)
        else
            f.Level:SetFormattedText("%d%s", level, suffix)
            -- friendly: Blizzard's gold; neutral and hostile: by difficulty
            local color = ns.UnitLevelColor(unit, level)
            if color then f.Level:SetTextColor(color.r, color.g, color.b) else f.Level:SetTextColor(1, 1, 1) end
        end
    else
        f.Level:SetText(level)
        f.Level:SetTextColor(1, 1, 1)
    end
    -- ring styles: the player's level is white, as on Blizzard's frame
    if (unit == "player" or unit == "pet") and ns.UFRing and ns.UFRing.Applies(f) then f.Level:SetTextColor(1, 1, 1) end
end

-- Dead or a ghost, but not a hunter feigning death (group members can read a feign as dead)
function UF.IsDead(unit)
    return UnitIsDeadOrGhost(unit) and not (UnitIsFeignDeath and UnitIsFeignDeath(unit))
end

local function UpdateHealth(f, glide)
    local unit = f.fuiUnit
    local udb = GetUnitDb(unit)
    local bar = f.Health

    -- Edit Mode (and a settings preview's sample): sample health in the unit's colour when there is one
    if f.fuiSample or ns.EditPreviewing() then
        f.colorClass = nil   -- the colour below is the sample's: the next tick sets it again
        local health = (UNITS[unit].sample or {}).health or 0.75
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(health)
        UF.SampleDamageTrail(f.DamageTrail, health, not UNITS[unit].poll and UF.DamageTrailOn(udb and udb.damageTrail))
        UF.BarLookUpdate(bar, nil, false, false)
        -- (Health Colour: the sample's colour at the sample's health)
        if UnitExists(unit) and not f.fuiSample then
            bar:SetStatusBarColor(UF.SampleHealthColor(udb, health, GetHealthColor(unit, ns.ClassColorsOn(udb))))
        elseif unit == "pet" then
            local c = REACTION[5]
            bar:SetStatusBarColor(UF.SampleHealthColor(udb, health, c[1], c[2], c[3]))
        else
            -- no unit: yours, so Class Colours shows here too
            bar:SetStatusBarColor(UF.SampleHealthColor(udb, health, GetHealthColor("player", ns.ClassColorsOn(udb))))
        end
        UF.FillSlots(f, "health", UF.SampleSource(health, 24000))
        return
    end

    local poll = UNITS[unit].poll
    bar:SetMinMaxValues(0, UnitHealthMax(unit))
    -- a corpse gets no more health ticks, so a glide could stop short of empty
    ns.SetBarValue(bar, UnitHealth(unit), glide and udb and udb.smoothBars and not poll and not UnitIsDead(unit))
    UF.SetDamageTrail(f.DamageTrail, unit, glide, not poll and UF.DamageTrailOn(udb and udb.damageTrail))
    -- (the polled frames update on a timer: no change to bump the edge glow for)
    UF.BarLookUpdate(bar, unit, glide and not poll)
    -- A connected player's colour only follows the class (readable), the palette and Class Colours, so a
    -- health tick keeps it unless one changed since it was set. A new unit comes as an update without
    -- glide and an offline one is set on every tick, so both set it again.
    local classOn = ns.ClassColorsOn(udb)
    local classFile
    if glide then
        local isPlayer = unit == "player" or UnitIsPlayer(unit)
        local connected = unit == "player" or UnitIsConnected(unit)
        if canaccessvalue(isPlayer) and isPlayer and canaccessvalue(connected) and connected then
            local _, file = UnitClass(unit)
            if canaccessvalue(file) then classFile = file end
        end
    end
    -- (Health Colour on: the colour changes with the health, so every tick sets it)
    if UF.HealthColorLive(udb) then
        bar:SetStatusBarColor(UF.HealthBarColor(unit, classOn, udb))
        f.colorClass = nil
    elseif not (classFile and f.colorClass == classFile and f.colorPalette == UF.paletteVersion and f.colorClassOn == classOn) then
        bar:SetStatusBarColor(GetHealthColor(unit, classOn))
        f.colorClass, f.colorPalette, f.colorClassOn = classFile, UF.paletteVersion, classOn
    end

    -- Bar Text: the slots, or Dead / Offline in the slot of the numbers
    local status
    if not UnitIsConnected(unit) then
        status = OFFLINE_TEXT
    elseif UF.IsDead(unit) then
        status = UnitIsGhost(unit) and GHOST_TEXT or DEAD_TEXT
    end
    UF.FillSlots(f, "health", not status and UF.HealthSource(unit, UF.TextSlots(f, "health")) or nil, status)
end

local function UpdatePower(f, glide)
    local unit = f.fuiUnit
    local udb = GetUnitDb(unit)
    local bar = f.Power
    local powerType, powerToken = UnitPowerType(unit)
    bar:SetMinMaxValues(0, UnitPowerMax(unit, powerType))
    ns.SetBarValue(bar, UnitPower(unit, powerType), glide and udb and udb.smoothBars and not UNITS[unit].poll)
    -- the colour only follows the power type (readable) and the palette: a power tick keeps it. An
    -- update without glide (a new unit, a new form, a layout) always sets it.
    local token = glide and canaccessvalue(powerToken) and powerToken or nil
    if not (token and f.powerColorToken == token and f.powerColorPalette == UF.paletteVersion) then
        bar:SetStatusBarColor(GetPowerColor(unit))
        f.powerColorToken, f.powerColorPalette = token, UF.paletteVersion
    end
    if f.ManaCost then f.ManaCost:Refresh(powerType) end
    if f.ShiftMana then UF.UpdateShiftMana(f) end
    -- Bar Text: the power bar's slots
    if udb and UnitIsConnected(unit) and not UF.IsDead(unit) then
        UF.FillSlots(f, "power", UF.PowerSource(unit, powerType, UF.TextSlots(f, "power")))
    else
        UF.FillSlots(f, "power")
    end
end

-- GetRaidTargetIndex can be secret. A secret is never nil, so it still means a marker is set, and
-- SetRaidTargetIconTexture takes it as is.
local function UpdateRaidIcon(f)
    if UNITS[f.fuiUnit].noRaidIcon then
        f.RaidIcon:Hide()
        return
    end
    local index = GetRaidTargetIndex(f.fuiUnit)
    local show
    if not ICON_UI.Shown(f.fuiUnit, "raidIcon") then
        show = false
    elseif not canaccessvalue(index) then
        show = true
    else
        show = index ~= nil and index > 0
    end
    if show then SetRaidTargetIconTexture(f.RaidIcon, index) end
    f.RaidIcon:SetShown(show)
    ICON_UI.Preview(f)
end

--------------------------------------------------
-- 6. CAST BARS
-- Target / focus bars and the standalone player bar. The client drives the bar (SetTimerDuration)
-- and the timer text (a duration text binding), so both move even when the cast data is secret.
--------------------------------------------------
local SAMPLE_CAST_SECONDS = 3
local SAMPLE_CAST_ICON = "Interface\\Icons\\Spell_Fire_FlameBolt"
local sampleCastTicker
local castBars = {}          -- every cast bar object, for previews

-- Interrupt ready: an interruptible enemy cast is green while the player's interrupt is ready, and
-- its normal colour while it cools down. All ranks share one cooldown, so rank 1 stands for them all.
-- isActive and isOnGCD are never secret; a hidden Cooldown frame tells when a cooldown ends.
local KICK = {
    spells = { 1766, 6552, 72, 2139, 8042, 15487 },   -- Kick, Pummel, Shield Bash, Counterspell, Earth Shock, Silence
    READY = { 0.30, 0.72, 0.36 },
    known = {},       -- spellID -> true while ready, false while cooling
    timers = {},      -- spellID -> Cooldown frame
}

UF.KICK = KICK   -- (the Nameplates module's Kick Ready colour reads it: UF.onKickChanged)

-- nil when the player has no interrupt, else whether one is ready
function KICK.IsReady()
    local any
    for _, ready in pairs(KICK.known) do
        if ready then return true end
        any = false
    end
    return any
end

-- the cast bar colour for an interruptible cast, or nil to keep the normal one
function KICK.Color(cast)
    if cast.standalone or cast.unit == "player" or not KICK.IsReady() then return end
    local canAttack = UnitCanAttack("player", cast.unit)
    if not canaccessvalue(canAttack) or not canAttack then return end
    return KICK.READY
end

local timerFormatter
local function GetTimerFormatter()
    if timerFormatter ~= nil then return timerFormatter or nil end
    timerFormatter = false
    -- one decimal
    local ok, fmt = pcall(C_StringUtil.CreateNumericRuleFormatter)
    if ok and fmt and pcall(fmt.SetBreakpoints, fmt, { { threshold = 0, format = "%.1f" } }) then
        timerFormatter = fmt
    end
    -- fallback: whole seconds
    if not timerFormatter then
        ok, fmt = pcall(C_StringUtil.CreateSecondsFormatter)
        if ok and fmt then timerFormatter = fmt end
    end
    return timerFormatter or nil
end

-- style: { height, icon, timer, name, texture, border, borderTexture, width }
-- plate: the frame is on Forever's plate, whose cast bar keeps the plate's border
local function GetCastStyle(udb, standalone, plate)
    if standalone then
        return {
            width = udb.width or 250, height = udb.height or 25,
            icon = udb.icon ~= false, timer = udb.timer ~= false, name = true,
            -- (its own border in every style, Forever Style too)
            texture = udb.texture, border = true, borderTexture = udb.borderTexture,
            bgOpacity = udb.bgOpacity, glow = ns.CastGlowOn(udb.castGlow),
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
        borderTexture = plate and ns.UFRing and ns.UFRing.Border(castBorder) or castBorder,
        -- on the plate the frame's Background is 0 (its slots are the bars' background),
        -- but the cast bar hangs outside the plate: its own Background there (the Cast Bar section)
        bgOpacity = udb.castBgOpacity or (plate and UF.BAR_BG_OPACITY) or udb.bgOpacity,
        glow = ns.CastGlowOn(udb.castGlow),   -- Edge Glow (Core.lua ns.CastGlowOn)
    }
end

-- sample: a settings preview's (no Edit Mode selection, not in castBars)
local function CreateCastBar(parent, unit, sample)
    local cast = CreateBar(parent, parent:GetFrameLevel() + 1)
    cast.unit = unit
    cast:SetMinMaxValues(0, 1)
    cast:Hide()
    if not sample then LEM:AddSelectionArea(cast) end

    cast.Backdrop = CreateFrame("Frame", nil, cast, "BackdropTemplate")
    cast.Backdrop:SetFrameLevel(cast:GetFrameLevel() - 1)
    cast.Border = CreateFrame("Frame", nil, cast, "BackdropTemplate")
    cast.Border:SetFrameLevel(cast:GetFrameLevel() + 2)

    cast.Icon = cast:CreateTexture(nil, "ARTWORK")
    cast.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local overlay = CreateFrame("Frame", nil, cast)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(cast:GetFrameLevel() + 3)
    cast.Text = UF.NewText(overlay)
    cast.Text:SetJustifyH("LEFT")
    cast.Text:SetWordWrap(false)
    cast.Time = UF.NewText(overlay)
    cast.Time:SetJustifyH("RIGHT")

    -- remaining time, formatted by the client: SetFormatter (SetTextFormat takes "{}" placeholders)
    local ok, binding = pcall(C_DurationUtil.CreateDurationTextBinding)
    if ok and binding then
        pcall(binding.SetFontString, binding, cast.Time)
        local fmt = GetTimerFormatter()
        if fmt then pcall(binding.SetFormatter, binding, fmt) end
        pcall(binding.SetZeroDurationText, binding, "")
        -- without these the binding renders once; the interval is the minimum gap between updates
        pcall(binding.SetUpdateInterval, binding, 0.05)
        pcall(binding.Enable, binding)
        cast.TimerBinding = binding
    end

    -- shown / hidden: the owner moves the auras on the cast bar's side (cast.onShownChanged)
    local function ShownChanged(self) if self.onShownChanged then self.onShownChanged(self) end end
    cast:HookScript("OnShow", ShownChanged)
    cast:HookScript("OnHide", ShownChanged)

    if not sample then castBars[#castBars + 1] = cast end
    return cast
end

local function SetCastTimer(cast, duration)
    -- (the duration can be secret: never tested)
    if cast.TimerBinding then
        pcall(cast.TimerBinding.SetDuration, cast.TimerBinding, duration)
    end
end

-- mode "TOP" / "BOTTOM" hangs the bar off a unit frame; "FILL" fills the standalone holder. The
-- icon sits left of the bar; the border wraps both.
-- leftExtra / rightExtra: more room from the anchor's edges (the ring)
local function LayoutCastBar(cast, style, anchor, mode, leftExtra, rightExtra)
    local db = GetDb()
    if not db then return end
    local PADDING = INSET
    leftExtra, rightExtra = leftExtra or 0, rightExtra or 0
    local edgeFile = GetBorderFile(style.borderTexture)
    local texture = GetBarTexture(style.texture)
    local height = style.height
    local iconOffset = style.icon and (height + CAST_ICON_GAP) or 0

    cast:SetStatusBarTexture(texture)
    cast.bg:SetTexture(texture)
    UF.SetBarBackground(cast, style.bgOpacity)
    -- Edge Glow: the health bars' bright edge, at the cast's front (style.glow; Core.lua ns.CastGlowOn)
    UF.BarLook(cast, false, style.glow)
    cast:ClearAllPoints()
    if mode == "TOP" then
        -- above Name Above Frames' name when the frame has one
        local lift = CAST_GAP + (anchor.nameAboveLift or 0)
        cast:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", PADDING + iconOffset + leftExtra, lift)
        cast:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", -PADDING - rightExtra, lift)
        cast:SetHeight(height)
    elseif mode == "BOTTOM" then
        -- (under the plate's second power slot while it shows)
        local drop = CAST_GAP + (ns.UFRing and ns.UFRing.PlateDrop(anchor) or 0)
        cast:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", PADDING + iconOffset + leftExtra, -drop)
        cast:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", -PADDING - rightExtra, -drop)
        cast:SetHeight(height)
    else
        local _, pad = BorderFit(height, edgeFile)
        cast:SetPoint("TOPLEFT", anchor, "TOPLEFT", pad + iconOffset, -pad)
        cast:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -pad, pad)
    end

    cast.Icon:ClearAllPoints()
    cast.Icon:SetSize(height, height)
    cast.Icon:SetPoint("RIGHT", cast, "LEFT", -CAST_ICON_GAP, 0)
    cast.Icon:SetShown(style.icon)

    -- the border wrap: the inset shrinks with the edge on a thin bar (BorderFit)
    local _, wrap = BorderFit(height, style.border and edgeFile)
    cast.Backdrop:ClearAllPoints()
    -- anchored to the bar alone: a secret cast icon makes anything anchored to the icon secret-sized,
    -- and BackdropTemplate does Lua maths on its own size
    cast.Backdrop:SetPoint("TOPLEFT", cast, "TOPLEFT", -iconOffset - wrap, wrap)
    cast.Backdrop:SetPoint("BOTTOMRIGHT", cast, "BOTTOMRIGHT", wrap, -wrap)
    cast.Backdrop:SetBackdrop({ bgFile = BACKDROP_FILE, insets = { left = wrap, right = wrap, top = wrap, bottom = wrap } })
    cast.Backdrop:SetBackdropColor(0, 0, 0, BG_OPACITY)
    cast.Border:ClearAllPoints()
    cast.Border:SetAllPoints(cast.Backdrop)
    if style.border then
        ApplyBorderStyle(cast.Border, edgeFile, height + 2 * PADDING)
        cast.Border:Show()
    else
        cast.Border:Hide()
    end

    -- the frame's Cast Name and Cast Countdown fonts (its style says whose frame: UF.Font)
    ApplyFont(cast.Text, UF.Font(style.fontKey or "player", "cast"))
    ApplyFont(cast.Time, UF.Font(style.fontKey or "player", "castTime"))
    cast.Time:ClearAllPoints()
    cast.Time:SetPoint("RIGHT", cast, "RIGHT", -TEXT_INSET, 0)
    cast.Time:SetShown(style.timer)
    cast.timerShown = style.timer and true or false   -- Hide Spell Timer: the end of a cast brings it back only if wanted
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
-- Your own bar's sample takes turns: a cast (latency zone, pushback) and a channel (its latency
-- zone on the left)
local SAMPLE_CHANNEL_SPELL = 5143
local function ShowSampleCast(cast)
    UF.EndCastFlash(cast)
    local own = cast.unit == "player"
    local channel = false
    if own then
        cast.sampleChannel = not cast.sampleChannel
        channel = cast.sampleChannel
    end
    local now = GetTime()
    local duration = C_DurationUtil.CreateDuration()
    duration:SetTimeFromStart(now, SAMPLE_CAST_SECONDS)
    cast:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate,
        channel and Enum.StatusBarTimerDirection.RemainingTime or Enum.StatusBarTimerDirection.ElapsedTime)
    SetCastTimer(cast, duration)
    -- (your own sample cast shows a lower rank, "(R2)", as a real one does)
    if own and not channel then
        cast.Text:SetText(L["%s (R%d)"]:format(L["Sample Cast"], 2))
    else
        cast.Text:SetText(channel and L["Sample Channel"] or L["Sample Cast"])
    end
    cast.Icon:SetTexture(SAMPLE_CAST_ICON)
    local color
    if cast.standalone or own then
        color = channel and PLAYER_CAST_CHANNEL or PLAYER_CAST_COLOR
    else
        color = channel and CAST_CHANNEL or CAST_COLOR
    end
    cast:SetStatusBarColor(color[1], color[2], color[3])
    cast:Show()
    if own then
        local startMs = now * 1000
        UF.UpdatePlayerCastExtras(cast, channel and "UNIT_SPELLCAST_CHANNEL_START" or "UNIT_SPELLCAST_START", channel, nil,
            startMs, startMs + SAMPLE_CAST_SECONDS * 1000, not channel and 500 or nil, SAMPLE_CHANNEL_SPELL)
    end
end

-- A cast's icon. Crafting casts can carry a placeholder or the wrong picture, so they take what the
-- profession window shows: the item it makes, then the recipe's icon. A secret icon goes straight to
-- the texture, which takes it. With none or the question mark: the recipe, then the spell's own icon;
-- the question mark only when nothing has a real one.
do
    local QUESTION_MARK = 134400
    local function IsRealIcon(icon)
        return icon and icon ~= 0 and icon ~= QUESTION_MARK
    end
    local function RecipeIcon(spellID)
        if not C_TradeSkillUI then return nil end
        local ok, output = pcall(C_TradeSkillUI.GetRecipeOutputItemData, spellID)
        if ok and output and IsRealIcon(output.icon) then return output.icon end
        local okInfo, recipe = pcall(C_TradeSkillUI.GetRecipeInfo, spellID)
        if okInfo and recipe and IsRealIcon(recipe.icon) then return recipe.icon end
        return nil
    end
    function UF.CastIcon(texture, spellID, isTradeskill)
        local id = canaccessvalue(spellID) and spellID or nil
        local secret = not canaccessvalue(texture)
        local crafting = canaccessvalue(isTradeskill) and isTradeskill
        if id and (crafting or (not secret and not IsRealIcon(texture))) then
            local icon = RecipeIcon(id)
            if icon then return icon end
        end
        if secret or IsRealIcon(texture) then return texture end
        if id then
            local icon = C_Spell.GetSpellTexture(id)
            if IsRealIcon(icon) then return icon end
        end
        return QUESTION_MARK
    end
end

-- "Interrupted": an interrupted cast stays up for a moment, filled red, before it goes. The fill is
-- an overlay over the bar (the client keeps driving the bar's own timer underneath).
UF.INTERRUPT_HOLD, UF.INTERRUPT_COLOR = 0.7, { 0.85, 0.12, 0.10 }

function UF.EndCastFlash(cast)
    if cast.flashTimer then cast.flashTimer:Cancel() cast.flashTimer = nil end
    if cast.FadeAnim and cast.FadeAnim:IsPlaying() then cast.FadeAnim:Stop() end   -- back to full alpha
    if not cast.flashing then return end
    cast.flashing = nil
    if cast.FlashFill then cast.FlashFill:Hide() end
    cast:GetStatusBarTexture():SetAlpha(1)
    cast.Time:SetShown(cast.timerShown ~= false)
end

-- Your own cast that finishes: the bar fills to full (the client's timer can stop just short of it)
-- and fades out, as Blizzard's does; a channel, which runs down to empty, only fades. A new cast
-- ends it (EndCastFlash).
UF.FINISH_FADE = 0.25
function UF.FinishCast(cast, channel)
    if not cast.FlashFill then
        cast.FlashFill = cast:CreateTexture(nil, "ARTWORK", nil, 7)
        cast.FlashFill:SetAllPoints(cast)
    end
    if not channel then
        cast.FlashFill:SetTexture(cast:GetStatusBarTexture():GetTexture())
        cast.FlashFill:SetVertexColor(cast:GetStatusBarColor())
        cast.FlashFill:Show()
        cast:GetStatusBarTexture():SetAlpha(0)
    end
    cast.Time:Hide()
    UF.HideCastExtras(cast)
    cast.flashing = true
    if not cast.FadeAnim then
        local anim = cast:CreateAnimationGroup()
        local fade = anim:CreateAnimation("Alpha")
        fade:SetFromAlpha(1)
        fade:SetToAlpha(0)
        fade:SetDuration(UF.FINISH_FADE)
        anim:SetScript("OnFinished", function()
            UF.EndCastFlash(cast)
            cast:Hide()
        end)
        cast.FadeAnim = anim
    end
    cast.FadeAnim:Stop()
    cast.FadeAnim:Play()
end

-- "Interrupted by <name>" as Blizzard's cast bar says it, the name class-coloured when readable.
-- by: the event's interruptedBy GUID, maybe secret (UnitNameFromGUID takes a secret one; a secret
-- name goes to the text as is)
function UF.SetInterruptText(text, by)
    local plain = _G.INTERRUPTED or "Interrupted"
    local fmt = _G.SPELL_INTERRUPTED_BY
    if (canaccessvalue(by) and by == nil) or not fmt then text:SetText(plain) return end
    local ok, name = pcall(UnitNameFromGUID, by)
    if not ok or (canaccessvalue(name) and (name == nil or name == "")) then text:SetText(plain) return end
    if canaccessvalue(name) then
        local okClass, _, classFile = pcall(UnitClassFromGUID, by)
        local color = okClass and canaccessvalue(classFile) and classFile and RAID_CLASS_COLORS[classFile]
        if color then name = color:WrapTextInColorCode(name) end
    end
    text:SetFormattedText(fmt, name)
end

-- failed: "Failed" (your own cast) instead of "Interrupted"
function UF.FlashInterrupted(cast, by, failed)
    if not cast.FlashFill then
        cast.FlashFill = cast:CreateTexture(nil, "ARTWORK", nil, 7)
        cast.FlashFill:SetAllPoints(cast)
    end
    local c = UF.INTERRUPT_COLOR
    cast.FlashFill:SetTexture(cast:GetStatusBarTexture():GetTexture())
    cast.FlashFill:SetVertexColor(c[1], c[2], c[3])
    cast.FlashFill:Show()
    cast:GetStatusBarTexture():SetAlpha(0)
    cast.Time:Hide()
    UF.HideCastExtras(cast)
    if failed then
        cast.Text:SetText(_G.FAILED or "Failed")
    else
        UF.SetInterruptText(cast.Text, by)
    end
    cast.flashing = true
    if cast.flashTimer then cast.flashTimer:Cancel() end
    cast.flashTimer = C_Timer.NewTimer(UF.INTERRUPT_HOLD, function()
        cast.flashTimer = nil
        UF.EndCastFlash(cast)
        cast:Hide()
    end)
end

-- The cast bar's extras: on your own bar the latency zone and the pushback, on an enemy's the kick tick
function UF.HideCastExtras(cast)
    if cast.LagZone then cast.LagZone:Hide() end
    if cast.Delay then cast.Delay:Hide() end
    if cast.KickHost then cast.KickHost:Hide() end
    if UF.HideCraftTotal then UF.HideCraftTotal(cast) end
end

-- CRAFT TOTAL (Quality of Life > Other > Craft Batch Time, off): while
-- you craft several of the same thing ("Create 3"), your cast bar's timer is followed by the whole
-- batch's time left, "0:12 (1:02)". The game knows how many crafts follow this one
-- (C_TradeSkillUI.GetRemainingRecasts, as Blizzard's Create box refills from it); each craft takes the
-- current one's time. The timer itself is the client's text binding, so the total is its own text in
-- the timer's place, and the timer moves to its left while it shows.
local function CraftTotalOn()
    local t = ns.db and ns.db.profile and ns.db.profile.tweaks
    return t and t.enabled and t.craftTotal and true or false
end

local function FormatTime(seconds)
    seconds = math.max(0, math.floor(seconds + 0.5))
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

function UF.HideCraftTotal(cast)
    local text = cast.CraftTotal
    if not (text and text:IsShown()) then return end
    text:Hide()
    if cast.craftTicker then cast.craftTicker:Cancel(); cast.craftTicker = nil end
    -- the timer back where its layout put it
    if cast.craftTimePoint then
        cast.Time:ClearAllPoints()
        cast.Time:SetPoint(unpack(cast.craftTimePoint))
        cast.craftTimePoint = nil
    end
end

function UF.UpdateCraftTotal(cast, isTradeskill, startMs, endMs)
    local remaining = 0
    if CraftTotalOn() and isTradeskill == true and C_TradeSkillUI and C_TradeSkillUI.GetRemainingRecasts
        and canaccessvalue(startMs) and canaccessvalue(endMs) and type(startMs) == "number" and type(endMs) == "number" then
        local ok, n = pcall(C_TradeSkillUI.GetRemainingRecasts)
        if ok and type(n) == "number" then remaining = n end
    end
    if remaining <= 0 then UF.HideCraftTotal(cast) return end
    local each = (endMs - startMs) / 1000
    cast.craftEnd = endMs / 1000 + remaining * each
    local text = cast.CraftTotal
    if not text then
        text = UF.NewText(cast.Time:GetParent())
        text:SetJustifyH("RIGHT")
        cast.CraftTotal = text
    end
    local face, size, flags = cast.Time:GetFont()
    if face then text:SetFont(face, size, flags or "") end
    text:SetTextColor(cast.Time:GetTextColor())
    if not text:IsShown() then
        -- the total takes the timer's place; the timer moves to its left
        local point, rel, relPoint, x, y = cast.Time:GetPoint(1)
        if point then
            cast.craftTimePoint = { point, rel, relPoint, x, y }
            text:ClearAllPoints()
            text:SetPoint(point, rel, relPoint, x, y)
            cast.Time:ClearAllPoints()
            cast.Time:SetPoint("RIGHT", text, "LEFT", -3, 0)
        end
        text:Show()
    end
    local function Tick()
        local left = cast.craftEnd and cast.craftEnd - GetTime() or 0
        if left <= 0 then UF.HideCraftTotal(cast) return end
        text:SetText("(" .. FormatTime(left) .. ")")
    end
    Tick()
    if not cast.craftTicker then cast.craftTicker = C_Timer.NewTicker(0.25, Tick) end
end

-- Your own cast's times are readable. Latency zone: the end of the bar your world latency covers
-- (a channel ends on the left). Pushback: how far the cast was set back ("+0.5") or the channel cut
-- short ("-0.5"), kept from the cast's first end time.
UF.LAG_COLOR, UF.DELAY_COLOR = { 1, 0.15, 0.1, 0.45 }, { 1, 0.3, 0.25 }

-- Blizzard's own player cast bar (FlareUI's Player Cast Bar switch off, the default) draws a cast
-- flagged "can't be interrupted" in its grey art, and Forever flags many of your own casts so: every
-- cast looked greyed out, like a range grey. Your own cast gets the normal
-- (or channel) art back after Blizzard picks it; the grey stays for casts you could kick. Only the
-- bar's texture is touched, never its fields (taint).
do
    local wasChannel   -- the last cast put right: its finish (cast info gone by then) too
    local function OwnCastLook(bar, isFull)
        local types, infos = _G.CastingBarType, _G.CastingBarTypeInfo
        if not (types and infos) then return end
        local castNoKick = select(8, UnitCastingInfo("player"))
        local channel = false
        if castNoKick == nil then
            castNoKick = select(7, UnitChannelInfo("player"))
            channel = castNoKick ~= nil
        end
        if castNoKick == nil and isFull and wasChannel ~= nil then
            -- the finish of a cast put right: still the grey type (not Interrupted)
            local barType = bar.barType
            if not (canaccessvalue(barType) and barType == types.Uninterruptable) then wasChannel = nil return end
            castNoKick, channel, wasChannel = true, wasChannel, nil
        elseif not (canaccessvalue(castNoKick) and castNoKick) then
            wasChannel = nil
            return
        else
            wasChannel = channel
        end
        local info = types and infos and infos[channel and types.Channel or types.Standard]
        if not info then return end
        if bar.classicStyleCastBar then
            local color = isFull and info.classicFullColor or info.classicFillColor
            if color then bar:SetStatusBarColor(color:GetRGB()) end
        else
            bar:SetStatusBarTexture(isFull and info.full or info.filling)
        end
    end
    local bar = _G.PlayerCastingBarFrame
    if bar and bar.UpdateBarFillTexture then hooksecurefunc(bar, "UpdateBarFillTexture", OwnCastLook) end
end

-- Latency Zone, measured per cast: the time from your spell's
-- request (UNIT_SPELLCAST_SENT) to the server starting it, which is what the zone stands for. The
-- network figure (GetNetStats) is a rolling average refreshed every few seconds, so it only stands
-- in until a cast has been measured. A request made during a cast or the global cooldown waited
-- in the queue: its time is not taken. A reading lasts a minute, then the average returns.
UF.lag = {}
do
    local GCD_SPELL = 61304
    local function Queued()
        local cast = UnitCastingInfo("player") or UnitChannelInfo("player")
        if not canaccessvalue(cast) or cast ~= nil then return true end
        local cd = C_Spell.GetSpellCooldown(GCD_SPELL)
        local s, d = cd and cd.startTime, cd and cd.duration
        if not (canaccessvalue(s) and canaccessvalue(d) and s and d) then return true end
        local now = GetTime()
        return s > 0 and s < now - 0.05 and s + d > now
    end
    local watch = CreateFrame("Frame")
    watch:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
    watch:SetScript("OnEvent", function()
        UF.lag.sentAt, UF.lag.queued = GetTimePreciseSec(), Queued()
    end)
end
-- the latency in ms for the cast now on the bar; isStart: its start event (takes the measurement)
function UF.CastLatency(isStart)
    local lag, now = UF.lag, GetTimePreciseSec()
    if isStart then
        local sent = lag.sentAt
        lag.sentAt = nil
        if sent and not lag.queued then
            local ms = (now - sent) * 1000
            if ms > 5 and ms < 1500 then lag.last, lag.lastAt = ms, now end
        end
    end
    if lag.last and now - lag.lastAt < 60 then return lag.last end
    local _, _, home, world = GetNetStats()
    return (world and world > 0) and world or home
end

-- Spell rank: your own cast of a lower rank shows it, "Holy Light (R2)". Your highest rank keeps its
-- plain name. Always on. The rank is the
-- number in the spell's subtext ("Rank 2" in any language); a spell without one keeps its plain name,
-- and so does a name or spell ID the client keeps secret.
function UF.CastNameWithRank(cast, label, spellID)
    if cast.unit ~= "player" then return label end
    if not (canaccessvalue(label) and type(label) == "string" and label ~= "") then return label end
    if not (canaccessvalue(spellID) and spellID) then return label end
    local okHigh, highest = pcall(C_ActionBar.IsHighestSpellRank, spellID)
    if okHigh and canaccessvalue(highest) and highest then return label end
    local ok, subtext = pcall(C_Spell.GetSpellSubtext, spellID)
    if not (ok and canaccessvalue(subtext) and type(subtext) == "string") then return label end
    local rank = tonumber(subtext:match("(%d+)"))
    if not rank then return label end
    return L["%s (R%d)"]:format(label, rank)
end

-- delayMs: UnitCastingInfo's delay so far (never secret); a channel has none, so it is tracked here
function UF.UpdatePlayerCastExtras(cast, event, channeling, castBarID, startMs, endMs, delayMs, spellID)
    if cast.unit ~= "player" then return end
    if not (canaccessvalue(startMs) and canaccessvalue(endMs) and startMs and endMs and endMs > startMs) then
        UF.HideCastExtras(cast)
        return
    end
    local zone = cast.LagZone
    if not zone then
        zone = cast:CreateTexture(nil, "ARTWORK", nil, 6)
        zone:SetColorTexture(1, 1, 1, 1)
        cast.LagZone = zone
    end
    -- this cast's measured latency (UF.CastLatency), the network average until one is measured
    local lag = UF.CastLatency(event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START")
    -- The Latency Zone always shows. Spell Pushback is the player cast bar's switch: the standalone
    -- bar keeps it in playerCastbar, the bar on the player frame with the frame's own settings.
    local db = GetDb()
    local pc
    if cast.standalone then pc = db and db.playerCastbar else pc = GetUnitDb("player") end
    local width = cast:GetWidth()
    local zoneWidth = (lag and lag > 0 and width) and width * math.min(lag / (endMs - startMs), 1) or 0
    if zoneWidth >= 1 then
        local c = UF.LAG_COLOR
        zone:SetVertexColor(c[1], c[2], c[3], c[4])
        zone:ClearAllPoints()
        local side = channeling and "LEFT" or "RIGHT"
        zone:SetPoint("TOP" .. side, cast, "TOP" .. side)
        zone:SetPoint("BOTTOM" .. side, cast, "BOTTOM" .. side)
        zone:SetWidth(zoneWidth)
        zone:Show()
    else
        zone:Hide()
    end

    local text = cast.Delay
    if not text then
        text = UF.NewText(cast.Time:GetParent())
        text:SetJustifyH("RIGHT")
        cast.Delay = text
    end
    local newCast = event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START"
        or not cast.pushEnd or (castBarID ~= nil and castBarID ~= cast.pushID)
    if not channeling and canaccessvalue(delayMs) and type(delayMs) == "number" then
        cast.pushDelay = delayMs / 1000
    elseif newCast then
        cast.pushID, cast.pushEnd, cast.pushDelay = castBarID, endMs, 0
    elseif event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        cast.pushDelay = (channeling and (cast.pushEnd - endMs) or (endMs - cast.pushEnd)) / 1000
    end
    -- Spell Pushback (the player cast bar's switch, off by default)
    if pc and pc.pushback and cast.pushDelay and cast.pushDelay >= 0.05 then
        local face, size, flags = cast.Time:GetFont()
        if face then text:SetFont(face, math.max(6, math.floor(size * 0.85 + 0.5)), flags or "") end
        text:ClearAllPoints()
        text:SetPoint("RIGHT", cast.Time, "LEFT", -4, 0)
        local c = UF.DELAY_COLOR
        text:SetTextColor(c[1], c[2], c[3])
        text:SetFormattedText(channeling and "-%.1f" or "+%.1f", cast.pushDelay)
        text:Show()
    else
        text:Hide()
    end
end

-- Kick tick: where on an enemy's cast your interrupt comes off cooldown. Two hidden bars on the
-- cast's scale, read at the same moment: the first filled to the time gone (a channel: the time
-- left), the second chained to its end and filled to your kick's cooldown left. The tick sits at
-- the second's end and stays put as both run down together; past the cast's end it is clipped.
-- Shown only while the kick cools and the cast can be interrupted; both may be secret, so frame
-- alphas follow them (a texture's boolean alpha draws nothing on this client).
function KICK.Active()
    for _, spellID in ipairs(KICK.spells) do
        if KICK.known[spellID] ~= nil then return spellID end
    end
end

function UF.NoSnap(bar)
    local tex = bar:GetStatusBarTexture()
    if tex and tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false); tex:SetTexelSnappingBias(0) end
end

function UF.UpdateKickTick(cast, channeling, duration, notInterruptible)
    local host = cast.KickHost
    local spellID = KICK.Active()
    local canAttack = not cast.standalone and cast.unit ~= "player" and spellID and UnitCanAttack("player", cast.unit)
    local cd = canaccessvalue(canAttack) and canAttack and canaccessvalue(duration) and duration
        and C_Spell.GetSpellCooldownDuration(spellID, true)
    local width = cast:GetWidth()
    if not cd or (canaccessvalue(notInterruptible) and notInterruptible) or not (canaccessvalue(width) and width > 0) then
        if host then host:Hide() end
        return
    end
    if not host then
        host = CreateFrame("Frame", nil, cast)
        host:SetAllPoints(cast)
        host:SetClipsChildren(true)
        host:SetFrameLevel(cast:GetFrameLevel() + 1)
        local function Bar()
            local bar = CreateFrame("StatusBar", nil, host)
            bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
            bar:GetStatusBarTexture():SetAlpha(0)
            bar:SetMinMaxValues(0, 1)
            return bar
        end
        host.Elapsed, host.Cooldown = Bar(), Bar()
        host.TickFrame = CreateFrame("Frame", nil, host)
        host.TickFrame:SetAllPoints(host)
        host.Tick = host.TickFrame:CreateTexture(nil, "OVERLAY")
        host.Tick:SetColorTexture(1, 1, 1, 0.9)
        host.Tick:SetWidth(2)
        cast.KickHost = host
    end
    local first, second, tick = host.Elapsed, host.Cooldown, host.Tick
    local height = cast:GetHeight()
    first:SetSize(width, height)
    second:SetSize(width, height)
    first:ClearAllPoints()
    first:SetPoint("LEFT", host, "LEFT")
    local total = duration:GetTotalDuration()
    first:SetMinMaxValues(0, total)
    second:SetMinMaxValues(0, total)
    -- a channel's bar drains to the left: the kick point is its time left minus the cooldown
    first:SetValue(channeling and duration:GetRemainingDuration() or duration:GetElapsedDuration())
    second:SetValue(cd:GetRemainingDuration())
    second:SetFillStyle(channeling and Enum.StatusBarFillStyle.Reverse or Enum.StatusBarFillStyle.Standard)
    UF.NoSnap(first)
    UF.NoSnap(second)
    second:ClearAllPoints()
    tick:ClearAllPoints()
    if channeling then
        second:SetPoint("RIGHT", first:GetStatusBarTexture(), "RIGHT")
        tick:SetPoint("RIGHT", second:GetStatusBarTexture(), "LEFT", 1, 0)
    else
        second:SetPoint("LEFT", first:GetStatusBarTexture(), "RIGHT")
        tick:SetPoint("LEFT", second:GetStatusBarTexture(), "RIGHT", -1, 0)
    end
    tick:SetPoint("TOP", host, "TOP")
    tick:SetPoint("BOTTOM", host, "BOTTOM")
    -- hidden once the kick is ready (the bar turns green then) and on a cast that can't be kicked
    local ready = cd:IsZero()
    if not pcall(host.TickFrame.SetAlphaFromBoolean, host.TickFrame, ready, 0, 1) then host.TickFrame:SetAlpha(0) end
    if canaccessvalue(notInterruptible) then
        host:SetAlpha(1)
    elseif not pcall(host.SetAlphaFromBoolean, host, notInterruptible, 0, 1) then
        host:SetAlpha(0)
    end
    host:Show()
end

-- event: the cast event that asked (an interrupt shows the flash)
-- by, barID: the event's interruptedBy (maybe secret) and castBarID (never secret, may be nil)
local function UpdateCastBar(cast, enabled, event, by, barID)
    if not enabled then UF.EndCastFlash(cast) cast:Hide() return end
    if ns.EditPreviewing() then UF.HideCastExtras(cast) ShowSampleCast(cast) return end
    -- a kicked channel only says so through CHANNEL_STOP's interruptedBy (a secret one is a GUID, so set)
    local interrupted = event == "UNIT_SPELLCAST_INTERRUPTED"
        or (event == "UNIT_SPELLCAST_CHANNEL_STOP" and cast.isChannel and not (canaccessvalue(by) and by == nil))
    -- only the cast on screen: a late interrupt of an earlier cast must not cover the next one
    if interrupted and cast:IsShown() and not cast.flashing
        and (barID == nil or cast.castBarID == nil or barID == cast.castBarID) then
        UF.FlashInterrupted(cast, by)
        return
    end
    local unit = cast.unit

    local channeling = false
    local n = select("#", UnitCastingInfo(unit))
    -- your own cast failing holds a moment on "Failed". FAILED's castBarID is its 4th argument (by's
    -- place); a key pressed during a cast also fails, so only when that same cast has stopped
    if event == "UNIT_SPELLCAST_FAILED" and unit == "player" and n == 0 and cast:IsShown() and not cast.flashing
        and by ~= nil and by == cast.castBarID then
        UF.FlashInterrupted(cast, nil, true)
        return
    end
    local name, text, texture, startMs, endMs, isTradeskill, notInterruptible, spellID, castBarID, delayMs
    if n > 0 then
        name, text, texture, startMs, endMs, isTradeskill, _, notInterruptible, spellID, castBarID, delayMs = UnitCastingInfo(unit)
    else
        n = select("#", UnitChannelInfo(unit))
        if n > 0 then
            name, text, texture, startMs, endMs, isTradeskill, notInterruptible, spellID, _, _, castBarID = UnitChannelInfo(unit)
            channeling = true
        end
    end
    if n == 0 then
        if cast.flashing then return end   -- the STOP after an interrupt: the flash ends by itself
        -- a channel restarted at once (Mind Flay clipped, Arcane Missiles chained) can read empty at
        -- its START: one more look next frame, the bar left as it is until then
        if (event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_START") and not cast.startRetry then
            cast.startRetry = true
            C_Timer.After(0, function()
                cast.startRetry = nil
                UpdateCastBar(cast, enabled)
            end)
            return
        end
        -- your own cast done (a kick or a failure has flashed already): filled and faded out
        if unit == "player" and cast:IsShown()
            and (event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP") then
            UF.FinishCast(cast, event == "UNIT_SPELLCAST_CHANNEL_STOP")
            return
        end
        cast:Hide()
        return
    end
    UF.EndCastFlash(cast)   -- a new cast replaces the flash
    cast.castBarID, cast.isChannel = castBarID, channeling

    local duration
    if channeling then duration = UnitChannelDuration(unit) else duration = UnitCastingDuration(unit) end
    if canaccessvalue(duration) and not duration then cast:Hide() return end
    local direction = channeling and Enum.StatusBarTimerDirection.RemainingTime or Enum.StatusBarTimerDirection.ElapsedTime
    cast:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, direction)
    SetCastTimer(cast, duration)
    -- Craft Batch Time: the whole batch's time after the timer
    if unit == "player" and not channeling then UF.UpdateCraftTotal(cast, isTradeskill, startMs, endMs)
    elseif cast.CraftTotal then UF.HideCraftTotal(cast) end

    -- `text or name` would boolean-test a secret; only pick when the value is readable
    local label = text
    if canaccessvalue(text) then label = text or name or "" end
    cast.Text:SetText(UF.CastNameWithRank(cast, label, spellID))
    cast.Icon:SetTexture(UF.CastIcon(texture, spellID, isTradeskill))

    local color
    -- your own casts in the player colours, on either player bar
    if cast.standalone or cast.unit == "player" then
        color = channeling and PLAYER_CAST_CHANNEL or PLAYER_CAST_COLOR
    else
        color = channeling and CAST_CHANNEL or CAST_COLOR
    end
    color = KICK.Color(cast) or color
    -- your own cast on the target or focus bar (targeting yourself), and any profession cast, are no
    -- kick either: they skip the grey as the player bar's do
    local own = cast.unit and cast.unit ~= "player" and UnitIsUnit(cast.unit, "player")
    own = (canaccessvalue(own) and own) or (canaccessvalue(isTradeskill) and isTradeskill) or false
    if cast.standalone or cast.unit == "player" or own then
        -- your own cast never takes the uninterruptible grey: it's for casts you could kick, and some
        -- of yours are flagged so, which read as a range grey
        cast:SetStatusBarColor(color[1], color[2], color[3])
    elseif canaccessvalue(notInterruptible) then
        if notInterruptible then color = CAST_NOINTERRUPT end
        cast:SetStatusBarColor(color[1], color[2], color[3])
    else
        -- secret on enemy casts in combat: the fill texture picks the colour itself
        cast.noInterruptColor = cast.noInterruptColor or CreateColor(1, 1, 1)
        cast.baseColor = cast.baseColor or CreateColor(1, 1, 1)
        cast.noInterruptColor:SetRGB(CAST_NOINTERRUPT[1], CAST_NOINTERRUPT[2], CAST_NOINTERRUPT[3])
        cast.baseColor:SetRGB(color[1], color[2], color[3])
        cast:GetStatusBarTexture():SetVertexColorFromBoolean(notInterruptible, cast.noInterruptColor, cast.baseColor)
    end
    cast:Show()
    -- your own cast: if its STOP is ever lost, one more look a second past its end clears the bar
    if unit == "player" and canaccessvalue(endMs) and type(endMs) == "number" then
        if cast.safetyTimer then cast.safetyTimer:Cancel() end
        local wait = endMs / 1000 + 1 - GetTime()
        cast.safetyTimer = wait > 0 and C_Timer.NewTimer(wait, function()
            cast.safetyTimer = nil
            if cast:IsShown() and not cast.flashing then UpdateCastBar(cast, enabled) end
        end) or nil
    end
    UF.UpdatePlayerCastExtras(cast, event, channeling, castBarID, startMs, endMs, delayMs, spellID)
    UF.UpdateKickTick(cast, channeling, duration, notInterruptible)
end

-- Player Cast Bar (Unit Frames settings): the FlareUI Player Cast Bar in place of Blizzard's. Off,
-- Blizzard's bar comes back after a reload. The player frame's own Cast Bar (Edit Mode) is apart.
function UF.PlayerCastOn()
    local db = GetDb()
    return db and db.playerCastbar and db.playerCastbar.enabled and true or false
end

local function IsCastEnabled(cast)
    if cast.isEnabled then return cast.isEnabled() end
    if cast.standalone then return UF.PlayerCastOn() end
    -- player, target, focus, pet: the frame's Cast Bar switch in Edit Mode
    local udb = GetUnitDb(cast.unit)
    return not (udb and udb.castbar == false)
end

local function UpdateCast(f, event, by, barID)
    if f.Cast then UpdateCastBar(f.Cast, IsCastEnabled(f.Cast), event, by, barID) end
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

-- Recolour the enemy casts on screen when the interrupt state flips
function KICK.UpdateBars()
    for _, cast in ipairs(castBars) do
        if cast:IsShown() and not cast.standalone and cast.unit ~= "player" then
            UpdateCastBar(cast, IsCastEnabled(cast))
        end
    end
    if UF.onKickChanged then pcall(UF.onKickChanged) end
end

function KICK.Timer(spellID)
    local timer = KICK.timers[spellID]
    if not timer then
        -- shown but invisible: a hidden Cooldown frame may never finish
        timer = CreateFrame("Cooldown", nil, UIParent, "CooldownFrameTemplate")
        timer:SetSize(1, 1)
        timer:SetPoint("CENTER")
        timer:SetAlpha(0)
        timer:SetDrawSwipe(false)
        timer:SetDrawEdge(false)
        timer:SetDrawBling(false)
        timer:SetHideCountdownNumbers(true)
        timer:EnableMouse(false)
        timer:SetScript("OnCooldownDone", function()
            if KICK.known[spellID] == false then
                KICK.known[spellID] = true
                KICK.UpdateBars()
            end
        end)
        KICK.timers[spellID] = timer
    end
    return timer
end

-- isOnGCD is only trustworthy on SPELL_UPDATE_COOLDOWN: the global cooldown counts as ready
function KICK.Refresh(cooldownEvent)
    local before = KICK.IsReady()
    for spellID in pairs(KICK.known) do
        local info = C_Spell.GetSpellCooldown(spellID)
        local ready = not (info and info.isActive) or (cooldownEvent and info.isOnGCD == true)
        KICK.known[spellID] = ready and true or false
        if not ready then
            local duration = C_Spell.GetSpellCooldownDuration(spellID, true)
            if duration then KICK.Timer(spellID):SetCooldownFromDurationObject(duration) end
        end
    end
    if KICK.IsReady() ~= before then KICK.UpdateBars() end
end

function KICK.Learn()
    wipe(KICK.known)
    for _, spellID in ipairs(KICK.spells) do
        if C_SpellBook.IsSpellKnown(spellID, Enum.SpellBookSpellBank.Player) then KICK.known[spellID] = true end
    end
    KICK.Refresh(false)
    KICK.UpdateBars()
end

KICK.events = CreateFrame("Frame")
KICK.events:RegisterEvent("PLAYER_LOGIN")
KICK.events:RegisterEvent("SPELLS_CHANGED")
KICK.events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
KICK.events:SetScript("OnEvent", function(_, event)
    if event == "SPELL_UPDATE_COOLDOWN" then
        if (castBars[1] or UF.onKickChanged) and next(KICK.known) then KICK.Refresh(true) end
    else
        KICK.Learn()
    end
end)

local UpdateComboPoints   -- defined in 10 (needs the layout helpers)
local UpdateHappiness     -- defined in 8c
local UpdateIndicators, UpdateHealPrediction, UpdateThreat   -- defined in 9

-- Blizzard's portrait faces right for players and friendly NPCs, left for most hostile creatures.
-- A mirrored frame flips the right-facing ones; anything unreadable counts as right-facing.
local function PortraitFacesRight(unit)
    local isPlayer = UnitIsPlayer(unit)
    if not canaccessvalue(isPlayer) or isPlayer then return true end
    local reaction = UnitReaction("player", unit)
    if not canaccessvalue(reaction) or not reaction then return true end
    return reaction >= 5
end

-- Blizzard's render can reset the coordinates just after SetPortraitTexture: the flip is held for a second
local function KeepPortraitFlipped(portrait)
    if portrait.Tex:GetTexCoord() ~= 1 then portrait.Tex:SetTexCoord(1, 0, 0, 1) end
    if GetTime() > portrait.flipUntil then portrait:SetScript("OnUpdate", nil) end
end

-- 2D ("3d", the stored value) is Blizzard's static portrait (square, unmasked). Class Icon falls
-- back to 2D for NPCs and secret classes. A frame with no unit (Edit Mode) shows the player.
local function UpdatePortrait(f)
    local portrait = f.Portrait
    if not portrait then return end
    local mode = PortraitMode(f)
    if mode == "none" then
        portrait:Hide()
        return
    end
    local unit = not f.fuiSample and UnitExists(f.fuiUnit) and f.fuiUnit or "player"
    local tex = portrait.Tex
    if ns.UFRing and ns.UFRing.SyncBack then ns.UFRing.SyncBack(f, mode) end
    local class
    if mode == "class" then
        local isPlayer = UnitIsPlayer(unit)
        if canaccessvalue(isPlayer) and isPlayer then
            local _, classFile = UnitClass(unit)
            if canaccessvalue(classFile) then class = classFile end
        end
    end
    if class then
        portrait:SetScript("OnUpdate", nil)
        tex:SetAtlas(GetClassAtlas(class), false, nil, true)   -- reset coords: SetAtlas keeps a 3D flip otherwise
    else
        SetPortraitTexture(tex, unit, true)
        local udb = GetUnitDb(f.fuiUnit)
        local flip = udb and UF.LayoutMirrored(f) and PortraitFacesRight(unit) or false
        if flip then
            tex:SetTexCoord(1, 0, 0, 1)
            portrait.flipUntil = GetTime() + 1
            portrait:SetScript("OnUpdate", KeepPortraitFlipped)
        else
            portrait:SetScript("OnUpdate", nil)
            tex:SetTexCoord(0, 1, 0, 1)
        end
    end
    portrait:Show()
end

-- Edit Mode with no unit behind the frame: sample values, texts per the frame's settings
local function ApplySample(f)
    local info, udb = UNITS[f.fuiUnit], GetUnitDb(f.fuiUnit)
    local s = info.sample or {}
    local power = s.power or 0.6
    f.Name:SetText(s.name or info.label)
    ns.NameAbove.SetSample(f, udb, s.name or info.label, s.surname)
    if udb and udb.showLevel then
        f.Level:SetText(UnitLevel("player") or "")
        f.Level:SetTextColor(1, 0.82, 0)
    else
        f.Level:SetText("")
    end
    UpdateHealth(f)
    f.Power:SetMinMaxValues(0, 1)
    f.Power:SetValue(power)
    local r, g, b = ns.PowerColor(s.powerToken or "MANA")
    f.Power:SetStatusBarColor(r or ns.MANA_BLUE[1], g or ns.MANA_BLUE[2], b or ns.MANA_BLUE[3])
    UF.FillSlots(f, "power", UF.SampleSource(power, 3000))
end

local function UpdateAll(f)
    if ns.EditPreviewing() and not UnitExists(f.fuiUnit) then
        ApplySample(f)
        UpdateRaidIcon(f)
        UpdateCast(f)
        if f.Combo then UpdateComboPoints(f) end
        UpdateIndicators(f)
        UpdateThreat(f)
        UpdateHealPrediction(f)
        UpdateHappiness(f)
        UpdatePortrait(f)
        return
    end
    UpdateName(f)
    UpdateLevel(f)
    UpdateHealth(f)
    UpdatePower(f)
    if f.fuiUnit == "target" or f.fuiUnit == "focus" then UF.ApplyRangeAlpha(f, f.fuiUnit) end
    UpdateRaidIcon(f)
    UpdateCast(f)
    if f.Combo then UpdateComboPoints(f) end
    UpdateIndicators(f)
    UpdateThreat(f)
    UpdateHealPrediction(f)
    UpdateHappiness(f)
    UpdatePortrait(f)
end

-- the most frequent events first
local function OnUnitEvent(f, event, arg1, arg2, _, arg4, arg5)
    if arg1 == "player" and f.fuiUnit ~= "player" and COMBO_EVENTS[event] then
        -- the player's energy ticks are not combo point changes
        if event == "UNIT_POWER_FREQUENT" and canaccessvalue(arg2) and arg2 ~= "COMBO_POINTS" then return end
        if f.Combo then UpdateComboPoints(f) end
        return
    end
    if event == "UNIT_FACTION" and arg1 == "player" and f.fuiUnit ~= "player" then
        if f.Auras then ns.AuraPolicy.UpdateSide(f, f.fuiUnit) end
        return
    end
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        UpdateHealth(f, true)
        UpdateHealPrediction(f)   -- the overlays' range, and the amounts are clamped by the health missing
        -- death and release come as health ticks: the power text blanks (or returns) with them
        local dead = UF.IsDead(f.fuiUnit)
        if dead ~= f.wasDead then
            f.wasDead = dead
            UpdatePower(f)
        end
    elseif event == "UNIT_POWER_FREQUENT" or event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER"
        or event == "UNIT_DISPLAYPOWER" then
        -- another power than the bar's (a cat's mana regen, a rogue's combo points): only Mana on
        -- Shapeshift wants mana. An unreadable token updates everything.
        if event ~= "UNIT_DISPLAYPOWER" and canaccessvalue(arg2) and arg2 then
            local _, own = UnitPowerType(f.fuiUnit)
            if canaccessvalue(own) and own and arg2 ~= own then
                if arg2 == "MANA" and f.ShiftMana then UF.UpdateShiftMana(f) end
                return
            end
        end
        -- UNIT_POWER_UPDATE right after UNIT_POWER_FREQUENT in the same frame (GetTime is the frame's
        -- time) repeats the change already drawn: the same reads would set the same values
        if event == "UNIT_POWER_UPDATE" then
            if f.powerFrequentAt == GetTime() then return end
        elseif event == "UNIT_POWER_FREQUENT" then
            f.powerFrequentAt = GetTime()
        end
        -- a new power type (a druid's form) lands at once: its value has nothing to do with the old one
        UpdatePower(f, event ~= "UNIT_DISPLAYPOWER")
    elseif event == "UNIT_THREAT_LIST_UPDATE" or event == "UNIT_THREAT_SITUATION_UPDATE"
        or event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        UpdateThreat(f)   -- (the fight's start and end: the player's Combat Glow)
    elseif event == "UNIT_HEAL_PREDICTION" or event == "UNIT_ABSORB_AMOUNT_CHANGED" then
        UpdateHealPrediction(f)
    elseif event == "PLAYER_UPDATE_RESTING" or event == "GROUP_ROSTER_UPDATE" or event == "PARTY_LEADER_CHANGED"
        or event == "PLAYER_FLAGS_CHANGED" or event == "QUEST_LOG_UPDATE" or event == "PVP_TIMER_UPDATE" then
        -- the quest log only moves the quest mark: with it unchanged nothing else is redone (Edit Mode
        -- always redraws, for its sample icons)
        if f:IsVisible() and not (event == "QUEST_LOG_UPDATE" and f.QuestIcon and not ns.EditPreviewing()
            and ICON_UI.QuestShown(f.fuiUnit) == f.questShown) then
            UpdateIndicators(f)
        end
    elseif event == "COMBO_TARGET_CHANGED" then
        -- Forever: points moved to a new target keep their count, so no power event fires
        if f.Combo then UpdateComboPoints(f) end
    elseif event == "UNIT_NAME_UPDATE" then
        UpdateName(f)
    elseif event == "UNIT_LEVEL" or event == "UNIT_CLASSIFICATION_CHANGED" then
        UpdateLevel(f)
        if event == "UNIT_CLASSIFICATION_CHANGED" then
            UpdateIndicators(f)   -- the elite / rare icon
        elseif ns.UFRing and ns.UFRing.Applies(f) then
            ns.UFRing.Update(f)   -- the level skull
        end
    elseif event == "UNIT_FACTION" or event == "UNIT_CONNECTION" or event == "UNIT_FLAGS" then
        UpdateHealth(f)
        UpdatePower(f)
        if f.Combo then UpdateComboPoints(f) end   -- a target can turn hostile (duels, mind control)
        -- the PvP flag follows UNIT_FACTION, and friendly levels have their own colour
        if event == "UNIT_FACTION" then
            UpdateLevel(f)
            UpdateIndicators(f)
        end
        -- a unit turning hostile or friendly: Only My Debuffs applies to enemies only
        if f.Auras then ns.AuraPolicy.UpdateSide(f, f.fuiUnit) end
    elseif event == "RAID_TARGET_UPDATE" then
        UpdateRaidIcon(f)
    elseif event == "READY_CHECK" or event == "READY_CHECK_CONFIRM" or event == "READY_CHECK_FINISHED" then
        ICON_UI.UpdateReady(f, event)
    elseif event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED" then
        UpdatePortrait(f)
    elseif event:find("^UNIT_SPELLCAST") then
        UpdateCast(f, event, arg4, arg5)
    else
        f.lastReady = nil   -- the unit behind the token changed: the last one's ready check goes
        UpdateAll(f)
        -- the auras rebuild for the new unit, and Only My Debuffs follows its side (ns.AuraPolicy)
        if f.Auras then ns.AuraPolicy.UnitChanged(f, f.fuiUnit) end
    end
end

--------------------------------------------------
-- 7. AURAS (Blizzard's aura containers)
-- Aura data can be secret, so Blizzard's CustomAuraContainer renders the icons. One container per
-- place, created at login (later ones are access-restricted and never show).
--------------------------------------------------
local AURA_CONTAINER_TEMPLATE = "CustomAuraContainerTemplate"
-- TOP and BOTTOM take the frame's whole width
local AURA_CORNERS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT", "TOP", "BOTTOM" }
local AURA = { FULL = { TOP = true, BOTTOM = true } }
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

-- initializeFrame: a pooled button's visuals, built once; the button drives them. look: the Buffs /
-- Debuffs look (ns.AuraLook), else the plain style.
local function InitAuraButton(button, size, isDebuff, unit, font, showTimer, look)
    -- (a party or raid tile's marks itself "group" after this: PartyFrames NoAuraTooltip)
    ns.MarkAuraTooltip(button, "solo")
    if look then
        ns.AuraLook.Style(button, look)
        ns.AuraLook.Hook(button, look)
        return
    end
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

        local count = UF.NewText(overlay)
        count:SetDrawLayer("OVERLAY", 3)   -- above the dispel border
        count:SetPoint("BOTTOMRIGHT", -1, 1)
        count:SetJustifyH("RIGHT")
        button.FlareUI_Count = count

        local duration = UF.NewText(overlay)
        duration:SetDrawLayer("OVERLAY", 3)
        duration:SetPoint("CENTER", 0, 0)
        duration:SetJustifyH("CENTER")
        button.FlareUI_Duration = duration
    end

    local fontPath = ns.GetFontPath(font and font.face or "Friz Quadrata TT")
    local textSize = math.max(8, math_floor(size * 0.45))
    ns.SetFont(button.FlareUI_Count, fontPath, textSize, "OUTLINE")
    ns.SetFont(button.FlareUI_Duration, fontPath, math.max(8, textSize - 1), "OUTLINE")
    ns.ApplyShadow(button.FlareUI_Count, font)
    ns.ApplyShadow(button.FlareUI_Duration, font)
    -- Blizzard shows and fills the duration text itself, so it is hidden by alpha
    button.FlareUI_Duration:SetAlpha(showTimer and 1 or 0)

    pcall(button.SetIcon, button, button.FlareUI_Icon)
    pcall(button.SetDurationCooldown, button, button.FlareUI_Cooldown)
    pcall(button.SetApplicationCount, button, button.FlareUI_Count, {})
    ns.SetAuraDurationText(button, button.FlareUI_Duration)
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
    if not UNITS[f.fuiUnit].auras or not HasAuraSupport() then return end
    f.Auras = {}
    for _, corner in ipairs(AURA_CORNERS) do
        local ok, container = pcall(CreateFrame, "AuraContainer", nil, f, AURA_CONTAINER_TEMPLATE)
        if ok and container then
            pcall(container.SetUnit, container, f.fuiUnit)
            container:SetFrameLevel(f:GetFrameLevel() + (f.auraLift or 4))
            container:Hide()
            f.Auras[corner] = { container = container }
        end
    end
end

-- Buff Amount / Debuff Amount:
-- how many icons a frame shows, 1 to 12, in as many rows as they need (each row as many as fit in the
-- corner). Unset: 8 in Addon Style, 6 in FlareUI and Forever Style; the focus frame 4 and the pet 3 in
-- every style.
UF.AURA_AMOUNT = { min = 1, max = 12, addon = 8, ring = 6, units = { focus = 4, pet = 3 } }
function UF.AuraAmountDefault(unit)
    local own = unit and UF.AURA_AMOUNT.units[unit]
    if own then return own end
    local style = ns.UFRing and ns.UFRing.Style and ns.UFRing.Style()
    return style == "addon" and UF.AURA_AMOUNT.addon or UF.AURA_AMOUNT.ring
end
function UF.AuraAmount(udb, isDebuff, unit)
    local v = udb and (isDebuff and udb.debuffAmount or udb.buffAmount)
    if type(v) ~= "number" then return UF.AuraAmountDefault(unit) end
    return math.max(UF.AURA_AMOUNT.min, math.min(UF.AURA_AMOUNT.max, math_floor(v + 0.5)))
end

-- Blizzard's sample auras are a fixed
-- set: 7 helpful, 4 harmful. In Edit Mode a lane is followed by copies of itself, on the same rows, until
-- the samples reach Buff / Debuff Amount; each copy shows the same samples again.
UF.SAMPLE_AURAS = { helpful = 7, harmful = 4 }
-- amount: the lane's Buff / Debuff Amount (the party and boss tiles use this too)
function UF.PreviewFillLanes(list, lane, amount)
    local per = lane.isDebuff and UF.SAMPLE_AURAS.harmful or UF.SAMPLE_AURAS.helpful
    local left = amount - per
    local n = 0
    while left > 0 do
        n = n + 1
        local copy = {}
        for k, v in pairs(lane) do copy[k] = v end
        copy.key = lane.key .. "#fill" .. n
        copy.joinPrevious = true
        copy.fillCount = math.min(per, left)
        list[#list + 1] = copy
        left = left - per
    end
    if n > 0 then lane.fillCount = per end
end

-- corner: TOPLEFT | TOPRIGHT | BOTTOMLEFT | BOTTOMRIGHT; lanes: ns.AuraPolicy lanes
local function ConfigureAuraCorner(f, corner, lanes)
    local entry = f.Auras and f.Auras[corner]
    if not entry then return end
    local container = entry.container
    local db, udb = GetDb(), GetUnitDb(f.fuiUnit)

    -- groups are reused per lane and look (ns.AuraGroups); the lanes left out turn off
    ns.AuraGroups.Begin(entry)

    if #lanes == 0 then
        ns.AuraGroups.Finish(container, entry)
        pcall(container.SetEnabled, container, false)
        container:Hide()
        return
    end

    -- Buffs Size and Debuffs Size: each lane its own; the line holds the larger of the corner's lanes
    local largest = 0
    for _, lane in ipairs(lanes) do largest = math.max(largest, ns.AuraSize(udb, lane.isDebuff, 20)) end
    -- a corner wraps before the frame's middle, in as many rows as Buff / Debuff Amount needs; Top / Bottom:
    -- the whole width less the ring's room
    local lineSize
    if AURA.FULL[corner] then
        local clear = (ns.UFRing and ns.UFRing.Applies(f)) and ns.UFRing.Clearance(f, AURA_GAP) or 0
        lineSize = math.max(largest, f:GetWidth() - 2 * INSET - clear)
    else
        lineSize = math.max(largest, math_floor(f:GetWidth() / 2) - INSET - 4)
    end
    local unit, font = f.fuiUnit, UF.Font(f.fuiUnit, "auras")
    local auraTimer = db and db.auraTimer or "none"
    local showTimer = auraTimer ~= "none"
    local sortMethod, sortDirection = ns.AuraOrder.Options(udb.auraSort, udb.auraReverse, udb.auraMineFirst)
    for index, lane in ipairs(lanes) do
        if lane.lead then
            UF.AddEnchantLead(f, container, entry, lane, index, udb)
        else
            local isDebuff = lane.isDebuff
            local size = ns.AuraSize(udb, isDebuff, 20)
            -- Buff Amount / Debuff Amount (a preview fill lane: its own share); each row holds as many as
            -- fit at this lane's size
            local max = lane.fillCount or UF.AuraAmount(udb, isDebuff, unit)
            local look = ns.AuraLook and ns.AuraLook.ForUnit(size, isDebuff, unit == "player", db and db.auraStyle or "square", "both", auraTimer, unit)
            if look and lane.stealable then look.stealable = true end   -- Highlight Purgeable Buffs
            local key, err = ns.AuraGroups.Add(container, entry, lane.key, ns.AuraGroups.Sig(size, isDebuff, font, showTimer, look), ns.AuraPolicy.FilterFor(lane, unit), {
                maxFrameCount = max,
                candidateFilters = lane.candidates,
                sortMethod = sortMethod, sortDirection = sortDirection,
                initializeFrame = function(button) InitAuraButton(button, size, isDebuff, unit, font, showTimer, look) end,
                layout = {
                    elementWidth = size, elementHeight = look and look.cellHeight or size,
                    elementSpacing = AURA_SPACING, lineSpacing = AURA_SPACING,
                    groupSpacing = AURA_SPACING, groupLineSpacing = AURA_SPACING,
                    layoutIndex = index,
                    forceNewLine = index > 1 and not lane.joinPrevious,
                },
            })
            if not key then
                print("|cffff0000FlareUI:|r aura group failed: " .. tostring(err))
            else
                ns.AuraPolicy.Track(f, container, key, lane)
            end
        end
    end
    ns.AuraGroups.Finish(container, entry)

    -- grow away from the corner (Top / Bottom: from the left)
    local isTop, isLeft = corner:find("^TOP") ~= nil, AURA.FULL[corner] or corner:find("LEFT$") ~= nil
    pcall(container.SetFlowLayoutAxis, container, AnchorUtil.FlowLayoutAxis.Horizontal)
    pcall(container.SetFlowLayoutAnchorPoint, container, (isTop and "BOTTOM" or "TOP") .. (isLeft and "LEFT" or "RIGHT"))
    pcall(container.SetFlowLayoutGrowthDirection, container,
        isLeft and AnchorUtil.FlowDirection.Right or AnchorUtil.FlowDirection.Left,
        isTop and AnchorUtil.FlowDirection.Up or AnchorUtil.FlowDirection.Down)
    pcall(container.SetFlowLayoutMaximumLineSize, container, lineSize)
    pcall(container.SetFlowLayoutPadding, container, 0, 0, 0, 0)
    pcall(container.SetEnabled, container, true)
    pcall(container.SetEditModePreviewEnabled, container, ns.EditPreviewing())
    container:Show()
    pcall(container.UpdateAllAuras, container)
end

-- DISPEL HIGHLIGHT on the player frame (Auras > Dispel Highlight, off): the party frames' (PartyFrames.lua
-- PF.DispelHighlight), a dispellable debuff on you pulsing the border, and the ring, in its type's colour
function UF.LayoutDispelHighlight(f)
    local PF = ns.PartyFrames
    -- (11-20: target and focus too, for a friendly target you dispel)
    local unit = f.fuiUnit
    if not (unit == "player" or unit == "target" or unit == "focus") or not (PF and PF.DispelHighlight) then return end
    local udb = GetUnitDb(unit)
    local setting = udb and udb.dispelHighlight or "off"
    if setting == "off" and not f.AuraHighlight then return end
    if not PF.NewDispelHighlight(f) then return end
    local plate = ns.UFRing and ns.UFRing.Plate and ns.UFRing.Plate(f) or false
    PF.DispelHighlight(f, setting, plate and true or false, udb and udb.border, udb and udb.height)
end

-- WEAPON ENCHANTS on the player frame: Forever keeps them out of the aura containers (Auras.lua
-- section 7), so FlareUI's own icons lead the first row of buffs. The corner's container gets a "lead"
-- group just before the buffs: one buff (any the buffs show) as wide as the enchant icons and no height,
-- so the first row starts with an empty stretch the icons are drawn in, and the buffs follow. Groups
-- filter on their own, so that buff still shows with the others. Changing the group works in combat.
-- Only while the buffs come first in their corner: after the debuffs, their first row's height can't
-- be known in a fight.
function UF.LeadBuffs(f, perCorner, editing)
    f.enchantLead = nil
    if f.fuiUnit ~= "player" or editing then return end
    local udb = GetUnitDb("player")
    if udb and udb.showEnchants == false then return end   -- Show Weapon Enchants off
    for corner, list in pairs(perCorner) do
        local first = list[1]
        if first and first.key == "buffs" then
            local lead = {}
            for k, v in pairs(first) do lead[k] = v end
            lead.key, lead.lead, lead.corner = "enchantLead", true, corner
            first.joinPrevious = true
            table.insert(list, 1, lead)
            return
        end
    end
end

function UF.InitSpacer(button)
    button:SetSize(0, 0)
    if button.SetMouseClickEnabled then pcall(button.SetMouseClickEnabled, button, false) end
    if button.SetMouseMotionEnabled then pcall(button.SetMouseMotionEnabled, button, false) end
end

-- the lead group's room for n icons of size
function UF.EnchantLeadLayout(size, n, index)
    return {
        elementWidth = math.max(n * (size + AURA_SPACING) - AURA_SPACING, 0), elementHeight = 0,
        elementSpacing = 0, lineSpacing = 0, groupSpacing = 0, groupLineSpacing = 0,
        layoutIndex = index, forceNewLine = false,
    }
end

function UF.AddEnchantLead(f, container, entry, lane, index, udb)
    local db = GetDb()
    local size = ns.AuraSize(udb, false, 20)
    local n = f.FlareUI_Enchants and f.FlareUI_Enchants.leadCount or 0
    local key = ns.AuraGroups.Add(container, entry, lane.key, "lead", ns.AuraPolicy.FilterFor(lane, f.fuiUnit), {
        maxFrameCount = 1, candidateFilters = lane.candidates, initializeFrame = UF.InitSpacer,
        layout = UF.EnchantLeadLayout(size, n, index),
    })
    if not key then return end
    pcall(container.SetAuraGroupEnabled, container, key, n > 0)
    f.enchantLead = {
        container = container, key = key, size = size, index = index, corner = lane.corner,
        look = ns.AuraLook and ns.AuraLook.ForUnit(size, false, true, db and db.auraStyle or "square", "both", db and db.auraTimer or "none", "player"),
    }
    f.enchantStamp = (f.enchantStamp or 0) + 1   -- the icons restyle once
end

-- The icons, one step apart from where the corner's first row starts (as AURA.Placement places it)
function UF.PlaceEnchants(f)
    local lead, holder = f.enchantLead, f.FlareUI_Enchants
    if not (lead and holder) then return end
    local isTop, isLeft, x, y = AURA.Placement(f, lead.corner)
    local point = (isTop and "BOTTOM" or "TOP") .. (isLeft and "LEFT" or "RIGHT")
    local relative = (isTop and "TOP" or "BOTTOM") .. (isLeft and "LEFT" or "RIGHT")
    local step = (lead.size + AURA_SPACING) * (isLeft and 1 or -1)
    local n = 0
    for _, b in ipairs(holder.enchants or {}) do
        if b.enchant then
            b:ClearAllPoints()
            b:SetPoint(point, f, relative, x + n * step, y)
            n = n + 1
        end
    end
end

-- Hide Buffs on the enchants as on the buffs: one whose full duration is longer than the choice
-- stays hidden (a 1-hour poison with "Longer Than 1 Minute"). Permanent hides none: enchants run out.
function UF.EnchantsShown(list, udb)
    local hide = udb and udb.hideBuffs or "OFF"
    local max = tonumber(hide)
    if hide == "OFF" or hide == "PERMANENT" or not max then return list end
    local shown = {}
    for _, e in ipairs(list) do
        if (e.duration or 0) <= max then shown[#shown + 1] = e end
    end
    return shown
end

UF.ENCHANT_EVENTS = { "WEAPON_ENCHANT_CHANGED", "WEAPON_SLOT_CHANGED", "PLAYER_EQUIPMENT_CHANGED",
    "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_ENTERING_WORLD" }

-- Reads the enchants and shows them on the player frame (in a fight too)
function UF.UpdateEnchants()
    local f = frames.player
    local lead = f and f.enchantLead
    local holder = f and f.FlareUI_Enchants
    local AU = ns.Auras
    local list = (lead and lead.look and AU and AU.ReadEnchants) and AU.ReadEnchants() or {}
    list = UF.EnchantsShown(list, GetUnitDb("player"))
    if not holder then
        if not (f and lead) then return end
        holder = CreateFrame("Frame", nil, f)
        holder:SetAllPoints(f)
        f.FlareUI_Enchants = holder
        local driver = CreateFrame("Frame", nil, holder)
        for _, event in ipairs(UF.ENCHANT_EVENTS) do pcall(driver.RegisterEvent, driver, event) end
        pcall(driver.RegisterUnitEvent, driver, "UNIT_INVENTORY_CHANGED", "player")
        driver:SetScript("OnEvent", function(_, event)
            UF.UpdateEnchants()
            -- no weapon event follows coming back to life: once more a moment later
            if event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" or event == "PLAYER_ENTERING_WORLD" then
                C_Timer.After(1, UF.UpdateEnchants)
            end
        end)
    end
    if lead then
        holder:SetFrameLevel(lead.container:GetFrameLevel())
        holder.lookStamp = f.enchantStamp
        AU.ShowEnchants(holder, list, lead.look)
        UF.PlaceEnchants(f)
    else
        for _, b in ipairs(holder.enchants or {}) do b.enchant = nil b:Hide() end
        holder:SetScript("OnUpdate", nil)
    end
    -- the buffs make room
    if lead and #list ~= (holder.leadCount or 0) then
        holder.leadCount = #list
        pcall(lead.container.SetAuraGroupLayout, lead.container, lead.key, UF.EnchantLeadLayout(lead.size, #list, lead.index))
        pcall(lead.container.SetAuraGroupEnabled, lead.container, lead.key, #list > 0)
    end
end

-- A container's spot: a few px out from its corner, past the cast bar while it shows on that side,
-- and past the ring at that height on the ring's side
function AURA.Placement(f, corner)
    local isTop = corner:find("^TOP") ~= nil
    local isLeft = AURA.FULL[corner] or corner:find("LEFT$") ~= nil
    local x = isLeft and INSET or -INSET
    local y = isTop and AURA_GAP or -AURA_GAP
    local udb = GetUnitDb(f.fuiUnit)
    if f.Cast and f.Cast:IsShown() and udb and UNITS[f.fuiUnit].castbar and (udb.castbarPosition == "TOP") == isTop then
        -- the cast bar's gap from the frame, the bar, and the same gap again before the auras
        local reach = (udb.castHeight or CAST_HEIGHT) + 2 * CAST_GAP
        y = isTop and reach or -reach
    end
    -- Name Above Frames: auras above the frame go over the name (BarText.lua); below it, under the
    -- plate's second power slot
    if isTop then
        y = y + (f.nameAboveLift or 0)
    elseif ns.UFRing then
        y = y - ns.UFRing.PlateDrop(f)
    end
    if ns.UFRing and ns.UFRing.Applies(f) and (ns.UFRing.Side(f) == "LEFT") == isLeft then
        local clear = ns.UFRing.Clearance(f, math.abs(y))
        x = x + (isLeft and clear or -clear)
    end
    return isTop, isLeft, x, y
end

-- A group member too far away to be visible comes with no aura durations (ns.AuraPolicy.UpdateReach):
-- Hide Buffs drops until the unit is near again. Target, focus and pet; the player is always near.
function UF.UpdateAuraReach(f)
    if f and f.Auras then ns.AuraPolicy.UpdateReach(f, f.fuiUnit) end
end

-- Two places clash: the same one, or a whole-width one and anything on its edge
function AURA.Clash(a, b)
    if not a or not b or a == "OFF" or b == "OFF" then return false end
    if a == b then return true end
    return (a:find("^TOP") ~= nil) == (b:find("^TOP") ~= nil) and (AURA.FULL[a] or AURA.FULL[b]) or false
end

-- STACKED AURAS (11-22, Malkkav): Buffs and Debuffs may pick clashing places; they stack instead.
-- The one that was in its place first stays nearer the frame, the one picked after it goes one row
-- further out (udb.auraOuter = "buffs" | "debuffs", saved when the clashing pick is made). The same
-- place: one container, the nearer kind's rows first (LayoutAuras). Top / Bottom with a corner on that
-- edge: two containers, the outer one hung under the inner one (PositionAuraContainers), on its own side.
-- Returns the nearer and the further kind, or nil when they don't clash.
function AURA.Stack(udb)
    local b, d = udb and udb.buffs or "OFF", udb and udb.debuffs or "OFF"
    if not AURA.Clash(b, d) then return nil end
    if udb.auraOuter == "buffs" then return "debuffs", "buffs" end
    return "buffs", "debuffs"
end

function UF.RestackAuras(f)
    if f.Auras then
        for _, entry in pairs(f.Auras) do entry.container:SetFrameLevel(f:GetFrameLevel() + (f.auraLift or 4)) end
    end
    -- the boss and party tiles' places (PartyFrames.lua ConfigurePosition); the portrait's grid keeps
    -- its own level, under the ready check
    if f.AuraPos then
        for pos, entry in pairs(f.AuraPos) do
            if pos ~= "PORTRAIT" then entry.container:SetFrameLevel(f:GetFrameLevel() + (f.auraLift or 6)) end
        end
    end
    -- the frame's cast bar too (placed above the frame it would go under the dragon), its pieces kept
    -- in their order above it: backdrop, bar, border, text
    local cast = f.Cast
    if cast and cast:GetParent() == f then
        local base = f:GetFrameLevel() + (f.auraLift or 1)
        local delta = base - cast:GetFrameLevel()
        if delta ~= 0 then
            local children = { cast:GetChildren() }
            local levels = {}
            for i, child in ipairs(children) do levels[i] = child:GetFrameLevel() end
            cast:SetFrameLevel(base)
            for i, child in ipairs(children) do child:SetFrameLevel(math.max(0, levels[i] + delta)) end
        end
    end
end

local function PositionAuraContainers(f)
    if not f.Auras then return end
    for corner, entry in pairs(f.Auras) do
        local c = entry.container
        local isTop, isLeft, x, y = AURA.Placement(f, corner)
        c:ClearAllPoints()
        c:SetPoint((isTop and "BOTTOM" or "TOP") .. (isLeft and "LEFT" or "RIGHT"), f,
            (isTop and "TOP" or "BOTTOM") .. (isLeft and "LEFT" or "RIGHT"), x, y)
        -- (FlareUI Style lifts them over the ring's art: f.auraLift, UnitFramesRing.lua Ring.Layout)
        c:SetFrameLevel(f:GetFrameLevel() + (f.auraLift or 4))
    end
    -- Top / Bottom and a corner on that edge (AURA.Stack): the further one hangs past the nearer one.
    -- A strip as wide as the frame takes the nearer container's far edge, so the further one keeps its
    -- own side; nothing is measured (aura sizes can be secret in a fight).
    local udb = GetUnitDb(f.fuiUnit)
    local near, far = AURA.Stack(udb)
    local nearCorner, farCorner = near and udb[near], far and udb[far]
    if near and nearCorner ~= farCorner and f.Auras[nearCorner] and f.Auras[farCorner] then
        local inner, outer = f.Auras[nearCorner].container, f.Auras[farCorner].container
        local isTop, isLeft, x = AURA.Placement(f, farCorner)
        local strip = f.AuraStackStrip
        if not strip then
            strip = CreateFrame("Frame", nil, f)
            f.AuraStackStrip = strip
        end
        strip:ClearAllPoints()
        strip:SetHeight(1)
        strip:SetPoint("LEFT", f, "LEFT")
        strip:SetPoint("RIGHT", f, "RIGHT")
        strip:SetPoint(isTop and "BOTTOM" or "TOP", inner, isTop and "TOP" or "BOTTOM", 0, isTop and AURA_SPACING or -AURA_SPACING)
        local side = isLeft and "LEFT" or "RIGHT"
        outer:ClearAllPoints()
        outer:SetPoint((isTop and "BOTTOM" or "TOP") .. side, strip, (isTop and "BOTTOM" or "TOP") .. side, x, 0)
    end
    if f.enchantLead then UF.PlaceEnchants(f) end
end

LayoutAuras = function(f)
    local udb = GetUnitDb(f.fuiUnit)
    if not udb or not f.Auras then return end
    if InCombatLockdown() then pendingLayout = "LayoutAuras" return end
    local perCorner = {}
    for _, corner in ipairs(AURA_CORNERS) do perCorner[corner] = {} end
    -- what each lane shows comes from ns.AuraPolicy (filters, Hide Buffs, Only My Debuffs / Buffs);
    -- the corners and sizes are this module's
    local editing = ns.EditPreviewing()
    for _, lane in ipairs(ns.AuraPolicy.UnitLanes(f.fuiUnit, udb, editing)) do
        local list = lane.place and perCorner[lane.place]
        if list then
            list[#list + 1] = lane
            if editing then UF.PreviewFillLanes(list, lane, UF.AuraAmount(udb, lane.isDebuff, f.fuiUnit)) end
        end
    end
    -- a shared place: the nearer kind's lanes first (AURA.Stack; a stable sort keeps each kind's order)
    local near = AURA.Stack(udb)
    if near and udb.buffs == udb.debuffs then
        local list = perCorner[udb.buffs]
        if list then
            local nearDebuff = near == "debuffs"
            local first, after = {}, {}
            for _, lane in ipairs(list) do
                local into = ((lane.isDebuff and true or false) == nearDebuff) and first or after
                into[#into + 1] = lane
            end
            wipe(list)
            for _, lane in ipairs(first) do list[#list + 1] = lane end
            for _, lane in ipairs(after) do list[#list + 1] = lane end
        end
    end
    UF.LeadBuffs(f, perCorner, editing)
    ns.AuraPolicy.Begin(f)
    for _, corner in ipairs(AURA_CORNERS) do
        ConfigureAuraCorner(f, corner, perCorner[corner])
    end
    PositionAuraContainers(f)
    UF.UpdateEnchants()
    -- the groups were just given their layout-time filters: the unit's side and reach apply on top
    ns.AuraPolicy.Done(f, f.fuiUnit)
end

-- Edit Mode: the containers render Blizzard's sample auras
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
-- Combo points belong to the target, as in Classic. A segmented strip on the health bar's top edge:
-- each segment is a StatusBar with range [i-1, i] fed the raw (possibly secret) count. The ring
-- styles use Blizzard's ComboFrame instead.
--------------------------------------------------
local COMBO = {
    height = 5, maxSegments = 10, fallbackMax = 5, previewPoints = 3,
    color = ns.COMBO_COLOR,
}

local function PlayerClass()
    local _, class = UnitClass("player")
    if canaccessvalue(class) then return class end
    return nil
end

-- Rogues, and druids in cat form, on an attackable target. Edit Mode previews for both classes.
local function ShouldShowComboPoints()
    local class = PlayerClass()
    if class ~= "ROGUE" and class ~= "DRUID" then return false end
    if ns.EditPreviewing() then return true end
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
    combo.segments, combo.separators = {}, {}
    combo.count = 0
    -- the one-pixel lines between segments sit over them
    combo.Lines = CreateFrame("Frame", nil, combo)
    combo.Lines:SetAllPoints()
    combo.Lines:SetFrameLevel(combo:GetFrameLevel() + 1)
    -- a dark line along the strip's bottom edge parts it from the health bar
    combo.Shadow = combo:CreateTexture(nil, "BACKGROUND")
    combo.Shadow:SetColorTexture(0, 0, 0, 0.8)
    combo.Shadow:SetHeight(1)
    combo.Shadow:SetPoint("TOPLEFT", combo, "TOPLEFT", 0, -COMBO.height)
    combo.Shadow:SetPoint("TOPRIGHT", combo, "TOPRIGHT", 0, -COMBO.height)
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

-- Spreads the segments across the strip on whole pixels, a one-pixel line between each
local function LayoutComboSegments(f)
    local combo, udb = f.Combo, GetUnitDb(f.fuiUnit)
    if not combo or combo.count == 0 then return end
    local n = combo.count
    local width = (udb and udb.width or 220) - 2 * INSET - PortraitSpace(f) - (combo.clear or 0)
    local texture = GetBarTexture(udb and udb.texture)
    for i = 1, n do
        local seg = GetComboSegment(f, i)
        local x, segWidth, px = ns.SegmentSpan(combo, width, n, i)
        seg:SetStatusBarTexture(texture)
        seg.bg:SetTexture(texture)
        -- unspent points: dark, with the health colour reading through
        seg.bg:SetVertexColor(0, 0, 0, 0.45)
        seg:SetStatusBarColor(COMBO.color[1], COMBO.color[2], COMBO.color[3])
        seg:ClearAllPoints()
        -- left to right even on a mirrored frame: the points are the player's, not the target's
        seg:SetPoint("TOPLEFT", combo, "TOPLEFT", x, 0)
        seg:SetSize(segWidth, COMBO.height)
        seg:Show()
        local sep = combo.separators[i]
        if not sep then
            sep = combo.Lines:CreateTexture(nil, "OVERLAY")
            local c = ns.SEGMENT_LINE_COLOR
            sep:SetColorTexture(c[1], c[2], c[3], c[4])
            combo.separators[i] = sep
        end
        sep:ClearAllPoints()
        sep:SetPoint("TOPLEFT", combo, "TOPLEFT", x + segWidth - px, 0)
        sep:SetSize(px, COMBO.height)
        sep:SetShown(i < n)
    end
    for i = n + 1, #combo.segments do combo.segments[i]:Hide() end
    for i = n + 1, #combo.separators do combo.separators[i]:Hide() end
end

local function IsComboShown(f)
    return f.Combo ~= nil and f.Combo.count > 0
end

-- Blizzard's ComboFrame: round the ring; unused, it is parked on a hidden parent, where Blizzard's
-- code still runs it
local CLASSIC_COMBO = { hooked = false }

-- nil when the client's combo display is off (comboPointLocation); the strip is used then
local function GetClassicCombo()
    local combo = _G.ComboFrame
    if combo and combo:IsEventRegistered("PLAYER_TARGET_CHANGED") then return combo end
end

-- FlareUI Style's Combo Points: Classic (gems round the portrait, the default), Modern (Addon Style's
-- strip over the health bar) or Off. A saved modernCombo reads as Modern.
function UF.RingComboMode(udb)
    local mode = udb and udb.ringCombo
    if mode == "classic" or mode == "modern" or mode == "off" then return mode end
    return (udb and udb.modernCombo) and "modern" or "classic"
end

local function IsFlareUIRing(f)
    return ns.UFRing and ns.UFRing.Applies(f) and ns.UFRing.Style() == "flareui" or false
end

-- Classic combo points go with the style: on in the ring styles (round the ring), off in Addon Style
local function UsesClassicCombo(f)
    local ringOn = ns.UFRing and ns.UFRing.Applies(f)
    -- (11-20: Forever Style reads the mode too, so its gems can be turned off)
    if ringOn and UF.RingComboMode(GetUnitDb(f.fuiUnit)) ~= "classic" then return false end
    return (ringOn and GetClassicCombo()) and true or false
end

-- Puts Blizzard's ComboFrame on the frame, or parks it
local function ApplyComboMode(f)
    local combo = GetClassicCombo()
    if not combo then return end
    if not UsesClassicCombo(f) then
        combo:SetParent(hiddenParent)
        return
    end
    combo:SetParent(f)
    ns.CopyStrata(combo, f)
    combo:SetFrameLevel(f.Border:GetFrameLevel() + 2)
    ns.UFRing.PlaceCombo(combo, f)
    if not CLASSIC_COMBO.hooked then
        CLASSIC_COMBO.hooked = true
        -- Blizzard puts the points back in its circle layout on every update (each power change, every
        -- class). Anchors only: the count can be secret. Nothing to do while parked or without points.
        if type(combo.LayoutPointsCircle) == "function" then
            hooksecurefunc(combo, "LayoutPointsCircle", function(self)
                if self:GetParent() ~= f then return end
                local max = self.maxComboPoints
                if canaccessvalue(max) and max == 0 then return end
                ns.UFRing.PlaceCombo(self, f)
            end)
        end
    end
end

-- Edit Mode: the ring styles' gems show a sample of three, for rogues and druids.
-- FlareUI's own sample gems sit over Blizzard's (its gems are never touched: what they store feeds
-- its combo update in a fight). Blizzard's frame hides with no points, on every energy tick: a hook on
-- its Update shows it again. Leaving Edit Mode clears it; the next power update shows real points.
function CLASSIC_COMBO.Sample(point, i)
    local samples = CLASSIC_COMBO.samples or {}
    CLASSIC_COMBO.samples = samples
    local sample = samples[i]
    if not sample then
        sample = CreateFrame("Frame", nil, point)
        sample:SetAllPoints(point)
        sample.Empty = sample:CreateTexture(nil, "ARTWORK", nil, 3)
        sample.Empty:SetAtlas("uf-roguecp-bg-dis", true)
        sample.Empty:SetPoint("CENTER")
        sample.Full = sample:CreateTexture(nil, "ARTWORK", nil, 3)
        sample.Full:SetAtlas("uf-roguecp-bg", true)
        sample.Full:SetPoint("CENTER")
        sample.Gem = sample:CreateTexture(nil, "ARTWORK", nil, 4)
        sample.Gem:SetAtlas("uf-roguecp-icon-red", true)
        sample.Gem:SetPoint("CENTER")
        samples[i] = sample
    end
    sample:SetFrameLevel(point:GetFrameLevel() + 5)
    return sample
end

function CLASSIC_COMBO.Preview(f)
    local combo = GetClassicCombo()
    if not (combo and combo.ComboPoints) then return end
    local owner = combo:GetParent() == f
    if ns.EditPreviewing() and not owner then return end
    if owner and ns.EditPreviewing() and UsesClassicCombo(f) and ShouldShowComboPoints() then
        local max = combo.maxComboPoints
        if not (canaccessvalue(max) and max and max > 0) then return end
        CLASSIC_COMBO.preview = f
        if not CLASSIC_COMBO.updateHooked and type(combo.Update) == "function" then
            CLASSIC_COMBO.updateHooked = true
            hooksecurefunc(combo, "Update", function(self)
                if CLASSIC_COMBO.preview and not self:IsShown() then self:SetAlpha(1); self:Show() end
            end)
        end
        local first = max - COMBO.previewPoints + 1   -- Blizzard fills the last points first
        for i, point in ipairs(combo.ComboPoints) do
            local sample = CLASSIC_COMBO.Sample(point, i)
            local full = i >= first
            sample.Empty:SetShown(not full)
            sample.Full:SetShown(full)
            sample.Gem:SetShown(full)
            sample:SetShown(i <= max)
        end
        combo:SetAlpha(1)
        combo:Show()
    elseif CLASSIC_COMBO.preview then
        CLASSIC_COMBO.preview = nil
        for _, sample in pairs(CLASSIC_COMBO.samples or {}) do sample:Hide() end
        combo:Hide()
    end
end

--------------------------------------------------
-- 8b. FIVE-SECOND RULE
-- A spark crosses the player's mana bar for five seconds after a mana-costing cast. Mana can be
-- secret, so the cast event and cost type are the signal (a secret amount counts). The same events
-- drive the mana cost preview: the cost shows darker at the fill's end while casting.
--------------------------------------------------
local FSR_SECONDS = 5
local FSR_SPARK   = "Interface\\CastingBar\\UI-CastingBar-Spark"
local fsrStart            -- GetTime() of the last mana cast while a window runs

local function CostsMana(spellID)
    if not (canaccessvalue(spellID) and spellID) then return false end
    local costs = C_Spell.GetSpellPowerCost(spellID)
    if not costs then return false end
    for _, cost in ipairs(costs) do
        if canaccessvalue(cost.type) and cost.type == Enum.PowerType.Mana then
            local amount = cost.cost
            if canaccessvalue(amount) and not (type(amount) == "number" and amount > 0) then return false end
            return true, amount
        end
    end
    return false
end

local function BarShowsMana()
    local powerType = UnitPowerType("player")
    return canaccessvalue(powerType) and powerType == Enum.PowerType.Mana
end

-- the seconds into the window; Edit Mode's sample loops one every five seconds
local function FsrElapsed()
    if ns.EditPreviewing() then return GetTime() % FSR_SECONDS end
    return fsrStart and (GetTime() - fsrStart)
end

local function MoveFsrSpark(holder)
    local elapsed = FsrElapsed()
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

-- the spark on a mana bar, hidden until a window runs
local function NewFsrHolder(bar)
    local holder = CreateFrame("Frame", nil, bar)
    holder:SetAllPoints(bar)
    holder:SetFrameLevel(bar:GetFrameLevel() + 2)
    holder:Hide()
    local spark = holder:CreateTexture(nil, "OVERLAY")
    spark:SetTexture(FSR_SPARK)
    spark:SetBlendMode("ADD")
    holder.Spark = spark
    -- the spark art is mostly glow, so it is taller than the bar
    holder:SetScript("OnShow", function(self)
        local height = bar:GetHeight()
        self.Spark:SetSize(math.max(height, 8), math.max(height * 2.2, 18))
    end)
    holder:SetScript("OnUpdate", MoveFsrSpark)
    return holder
end

-- Mana cost preview without arithmetic (mana can be secret): a clip to the fill's end holds a bar
-- of the same width filling from the other end. getAmount: the cost now (nil: none); getColor: the
-- bar's colour (the preview is a darker shade). Also on the Resource Bars (UF.Kit.CreateManaCost).
function UF.CreateManaCost(bar, getAmount, getColor)
    local clip = CreateFrame("Frame", nil, bar)
    clip:SetFrameLevel(bar:GetFrameLevel() + 1)
    clip:SetClipsChildren(true)
    clip:Hide()
    local cost = CreateFrame("StatusBar", nil, clip)
    cost:SetMinMaxValues(0, 1)
    cost:SetValue(0)
    function cost:Refresh(powerType)
        local amount = getAmount()
        if (canaccessvalue(amount) and amount == nil) or not (canaccessvalue(powerType) and powerType == Enum.PowerType.Mana) then
            clip:Hide()
            return
        end
        local fill = bar:GetStatusBarTexture()
        local reverse = bar:GetReverseFill()
        -- the anchors follow the fill's end by themselves: set again only for a new fill or side
        if self.anchorFill ~= fill or self.anchorReverse ~= reverse then
            self.anchorFill, self.anchorReverse = fill, reverse
            clip:ClearAllPoints()
            self:ClearAllPoints()
            if reverse then
                clip:SetPoint("TOPLEFT", fill, "TOPLEFT")
                clip:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT")
                self:SetPoint("TOPLEFT", clip, "TOPLEFT")
                self:SetPoint("BOTTOMLEFT", clip, "BOTTOMLEFT")
            else
                clip:SetPoint("TOPLEFT", bar, "TOPLEFT")
                clip:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
                self:SetPoint("TOPRIGHT", clip, "TOPRIGHT")
                self:SetPoint("BOTTOMRIGHT", clip, "BOTTOMRIGHT")
            end
        end
        local w, tex = bar:GetWidth(), fill:GetTexture()
        if self.fuiW ~= w then self.fuiW = w; self:SetWidth(w) end
        if self.fuiRev ~= reverse then self.fuiRev = reverse; self:SetReverseFill(not reverse) end
        if self.fuiTex ~= tex then self.fuiTex = tex; self:SetStatusBarTexture(tex) end
        local r, g, b = getColor()
        self:SetStatusBarColor(r * 0.6, g * 0.6, b * 0.6)
        self:SetMinMaxValues(bar:GetMinMaxValues())
        self:SetValue(amount)
        clip:Show()
    end
    return cost
end

local function CreateFsrSpark(f)
    local bar = f.Power
    f.ManaCost = UF.CreateManaCost(bar, function() return f.manaCost end, function() return GetPowerColor("player") end)

    f.FsrSpark = NewFsrHolder(bar)
    -- a druid in Cat or Bear Form: the window runs on the Mana on Shapeshift strip (powershifting)
    if f.ShiftMana then f.ShiftFsrSpark = NewFsrHolder(f.ShiftMana) end
    UF.Gcd.Create(f)
end

-- Your frame in the party shows the spark too, following the player frame's option (PartyFrames.lua)
function UF.AttachFsrSpark(tile)
    tile.FsrSpark = NewFsrHolder(tile.Power)
    UF.fsrTile = tile
end

-- GCD SPARK (as on the Resource Bars' power bar, ResourceBars.lua UpdateGcd): a warm
-- spark crosses the player frame's power bar during the global cooldown, any power type. The GCD is
-- read from a spell that only has the GCD, only when its times can be read. Edit Mode: a still spark
-- at 40%. Option "gcd" on the player frame, off; right after Five-Second Rule.
UF.Gcd = { SPELLS = { 29515, 61304 }, COLOR = { 1, 0.85, 0.4 } }
function UF.Gcd.Create(f)
    local bar = f.Power
    local holder = CreateFrame("Frame", nil, bar)
    holder:SetAllPoints(bar)
    holder:SetFrameLevel(bar:GetFrameLevel() + 3)
    holder:Hide()
    local spark = holder:CreateTexture(nil, "OVERLAY")
    spark:SetTexture(FSR_SPARK)
    spark:SetBlendMode("ADD")
    spark:SetVertexColor(UF.Gcd.COLOR[1], UF.Gcd.COLOR[2], UF.Gcd.COLOR[3])
    holder.Spark = spark
    holder:SetScript("OnShow", function(self)
        local height = bar:GetHeight()
        self.Spark:SetSize(math.max(height, 8), math.max(height * 2.2, 18))
    end)
    holder:SetScript("OnUpdate", function(self)
        local part
        if ns.EditPreviewing() then
            part = 0.4
        else
            local start, duration = UF.Gcd.start, UF.Gcd.duration
            local elapsed = start and (GetTime() - start)
            if not elapsed or elapsed >= duration then
                self:Hide()
                return
            end
            part = elapsed / duration
        end
        local width = bar:GetWidth()
        local x = width * part
        if bar:GetReverseFill() then x = width - x end
        self.Spark:SetPoint("CENTER", bar, "LEFT", x, 0)
    end)
    f.GcdSpark = holder
end
function UF.Gcd.On()
    local u = GetUnitDb("player")
    return u and u.gcd == true or false
end
-- a GCD started (SPELL_UPDATE_COOLDOWN): the spark runs
function UF.Gcd.Start()
    local f = frames.player
    if not (f and f.GcdSpark and UF.Gcd.On() and f.Power:IsShown()) or ns.EditPreviewing() then return end
    for _, id in ipairs(UF.Gcd.SPELLS) do
        local info = C_Spell.GetSpellCooldown(id)
        local start, duration = info and Readable(info.startTime), info and Readable(info.duration)
        if start and duration and duration > 0 and duration <= 2 then
            UF.Gcd.start, UF.Gcd.duration = start, duration
            f.GcdSpark:Show()
            return
        end
    end
end
-- the option, Edit Mode or the power bar changed
function UF.Gcd.Update()
    local f = frames.player
    local holder = f and f.GcdSpark
    if not holder then return end
    local on = UF.Gcd.On() and f.Power:IsShown()
    if not on then holder:Hide() return end
    if ns.EditPreviewing() then holder:Show() return end
    holder:Hide()
    UF.Gcd.Start()
end
function UF.Gcd.Init()
    if UF.Gcd.events then return end
    UF.Gcd.events = CreateFrame("Frame")
    UF.Gcd.events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    UF.Gcd.events:SetScript("OnEvent", UF.Gcd.Start)
end

local function UpdateFsrSpark()
    UF.Gcd.Update()   -- (the same moments: Edit Mode, the option, the druid strip)
    local f = frames.player
    local holder = f and f.FsrSpark
    if not holder then return end
    if fsrStart and GetTime() - fsrStart >= FSR_SECONDS then fsrStart = nil end
    local u = GetUnitDb("player")
    local running = u and u.fsr == true and (fsrStart ~= nil or ns.EditPreviewing())
    local on = running and BarShowsMana()
    holder:SetShown(on and f.Power:IsShown())
    if f.ShiftFsrSpark then f.ShiftFsrSpark:SetShown(running and f.ShiftMana:IsShown() or false) end
    local tile = UF.fsrTile
    if tile then tile.FsrSpark:SetShown(on and tile.Power:IsShown()) end
end

local function InitFsrSpark()
    -- warriors and rogues never spend mana: no spark, no cost preview, no cast events
    local _, class = UnitClass("player")
    if class == "WARRIOR" or class == "ROGUE" then return end
    local events = CreateFrame("Frame")
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    events:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
    for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }) do
        events:RegisterUnitEvent(event, "player")
    end
    events:SetScript("OnEvent", function(_, event, _, _, spellID)
        -- mana cost preview: set on cast start, cleared once no cast runs (an off-GCD spell keeps it)
        local f = frames.player
        if f and f.ManaCost and event ~= "UNIT_DISPLAYPOWER" then
            local old = f.manaCost
            if event == "UNIT_SPELLCAST_START" then
                local costs, amount = CostsMana(spellID)
                f.manaCost = nil
                if costs then f.manaCost = amount end
            elseif select("#", UnitCastingInfo("player")) == 0 then   -- the count: the values may be secret
                f.manaCost = nil
            end
            -- only a changed preview redraws the bar (a spammed key fires FAILED on every press)
            local new = f.manaCost
            if not (canaccessvalue(old) and canaccessvalue(new) and old == new) then UpdatePower(f, true) end
            if event ~= "UNIT_SPELLCAST_SUCCEEDED" then return end
        end
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            if not CostsMana(spellID) then return end
            fsrStart = GetTime()
        end
        UpdateFsrSpark()
    end)
end

--------------------------------------------------
-- 8c. PET HAPPINESS
-- Blizzard's own indicator (PetFrameHappinessTemplate) mid health bar. Clicks pass through to the
-- frame; the hover keeps its tooltip. Edit Mode shows the happy face.
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
    if ICON_UI.Shown(f.fuiUnit, "happiness") then
        face:RegisterEvent("UNIT_HAPPINESS")
        face:RegisterEvent("UNIT_PET")
        face:UpdateHappiness()
        if ns.EditPreviewing() and not face:IsShown() then
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
-- Icons (rested, leader, PvP, classification, quest), the threat border tint and the incoming-heal
-- / absorb overlays. Art: Blizzard atlases, with the classic textures as fallback.
--------------------------------------------------
local ICON_SIZE = {
    rest = 28, leader = 20, pvp = 24,   -- the Elite & Rare skull takes the PvP crest's size
    quest = 24,   -- the quest "!" height; its width follows the art
}
local QUEST_ATLAS     = "QuestNormal"   -- the map's quest-offer "!", as on the nameplate quest tags
local QUEST_FILE      = "Interface\\GossipFrame\\AvailableQuestIcon"
-- Blizzard's CUF_MY_HEAL_PREDICTION_COLOR, opaque: the overlays only cover the empty part of the bar
local HEAL_COLOR      = { 11/255, 136/255, 105/255, 1 }   -- #0B8869, incoming heals
local ABSORB_COLOR    = { 0.67, 0.78, 0.92, 1 }           -- damage absorbs, the shield art's steel blue
-- (the Colour Palette writes into these: UF.ApplyPalette)
UF.HEAL_COLOR, UF.ABSORB_COLOR = HEAL_COLOR, ABSORB_COLOR
local HEAL_TEXTURE    = "FlareUI Dark"
local ABSORB_TEXTURE  = "FlareUI Striped"

-- (an atlas found is remembered: GetAtlasInfo makes a new table on each call, and the icons ask on
-- every update)
ICON_UI.atlasFound = {}
local function HasAtlas(name)
    if name == nil then return false end
    if ICON_UI.atlasFound[name] then return true end
    local found = C_Texture.GetAtlasInfo(name) ~= nil
    if found then ICON_UI.atlasFound[name] = true end
    return found
end

-- The atlas when the client has it, otherwise the classic texture
local function SetIconArt(tex, atlas, file, coords)
    if HasAtlas(atlas) then
        tex:SetAtlas(atlas, false)
    else
        tex:SetTexture(file)
        if coords then tex:SetTexCoord(unpack(coords)) else tex:SetTexCoord(0, 1, 0, 1) end
    end
end

local function CreateIndicators(f)
    local info = UNITS[f.fuiUnit]
    local ind = info.indicators
    if not ind then return end
    local overlay = f.Overlay

    if ind.rest then
        local rest = CreateFrame("Frame", nil, overlay)
        rest:SetSize(ICON_SIZE.rest, ICON_SIZE.rest)
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
    -- the PvP timer, right beside the flag (Addon Style; the ring has its own)
    if ind.pvpTimer and f.PvPIcon then
        f.PvPTimer = CreateFrame("Frame", nil, overlay)
        f.PvPTimer:SetAllPoints(overlay)
        f.PvPTimer.Text = f.PvPTimer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.PvPTimer.Text:SetPoint("RIGHT", f.PvPIcon, "LEFT", 0, 0)
        f.PvPTimer.Text:Hide()
    end
    if ind.classification then
        f.ClassIcon = overlay:CreateTexture(nil, "OVERLAY")
        f.ClassIcon:Hide()
    end
    if ind.readyCheck then
        f.ReadyIcon = overlay:CreateTexture(nil, "OVERLAY", nil, 6)
        f.ReadyIcon:Hide()
    end
    if ind.quest then
        -- under the raid marker (sublevel 4), which shares its spot mid health bar
        f.QuestIcon = overlay:CreateTexture(nil, "OVERLAY", nil, 1)
        f.QuestIcon:Hide()
    end
    -- threat tints the frame border (UpdateThreat)
    f.threatTint = ind.threat and true or false
    if ind.heals then
        -- the overlays live in a clip frame over the empty part of the health bar
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
        f.ShieldGlow = UF.CreateShieldGlow(f.Health, clip)
        f.OverAbsorb = UF.CreateOverAbsorb(f.Health, clip)
        if CreateUnitHealPredictionCalculator then
            local ok, calc = pcall(CreateUnitHealPredictionCalculator)
            if ok and calc then f.HealCalc = calc end
        end
    end
end

-- The frame laid out as the target frame (portrait, icons, texts). In the ring styles Mirror only
-- turns the bars' fill, so target and focus keep that layout; the fill always follows udb.mirror.
function UF.LayoutMirrored(f)
    local info = UNITS[f.fuiUnit]
    -- the ring styles: the texts follow the ring's side (Flip Portrait); Mirror Bars
    -- turns only the bars' fill there
    if info and ns.UFRing and ns.UFRing.Applies(f) then return ns.UFRing.Side(f) == "RIGHT" end
    local udb = GetUnitDb(f.fuiUnit)
    return udb and udb.mirror and true or false
end

local function LayoutIndicators(f)
    local udb = GetUnitDb(f.fuiUnit)
    local mirror = UF.LayoutMirrored(f)
    local fillMirror = udb and udb.mirror and true or false
    -- Forever style: the icons with a home on the ring go there
    local onRing = {}
    if ns.UFRing and ns.UFRing.Applies(f) then
        for _, key in ipairs({ "rest", "leader", "pvp", "classification", "quest", "readyCheck" }) do
            local region = f[ICON_UI.defs[key].field]
            if region then
                local point, rel, relPoint, x, y, w, h = ns.UFRing.IconSpot(f, key)
                if point then
                    ICON_UI.Place(region, w, h, point, rel, relPoint, x, y)
                    onRing[key] = true
                end
            end
        end
    end
    -- FlareUI's own placement
    if f.RestIcon and not onRing.rest then
        ICON_UI.Place(f.RestIcon, ICON_SIZE.rest, ICON_SIZE.rest, "CENTER", f, "TOPRIGHT", -2, 0)
    end
    if f.LeaderIcon and not onRing.leader then
        ICON_UI.Place(f.LeaderIcon, ICON_SIZE.leader, ICON_SIZE.leader, "CENTER", f, "TOPLEFT", 16, -2)
    end
    if f.PvPIcon and not onRing.pvp then
        -- bottom-left on the player, bottom-right on a mirrored frame: symmetrical across the screen
        if mirror then
            ICON_UI.Place(f.PvPIcon, ICON_SIZE.pvp, ICON_SIZE.pvp, "CENTER", f, "BOTTOMRIGHT", -4, 2)
        else
            ICON_UI.Place(f.PvPIcon, ICON_SIZE.pvp, ICON_SIZE.pvp, "CENTER", f, "BOTTOMLEFT", 4, 2)
        end
    end
    if f.ClassIcon and not onRing.classification then
        local info = C_Texture.GetAtlasInfo(ICON_UI.CLASS_SKULL)
        local aspect = (info and info.width > 0 and info.height > 0) and (info.width / info.height) or 1
        -- above the PvP crest, in its column and at its size (top-right on a mirrored frame, top-left otherwise)
        local size = ICON_SIZE.pvp
        if mirror then
            ICON_UI.Place(f.ClassIcon, size * aspect, size, "CENTER", f, "TOPRIGHT", -4, -2)
        else
            ICON_UI.Place(f.ClassIcon, size * aspect, size, "CENTER", f, "TOPLEFT", 4, -2)
        end
    end
    if f.QuestIcon and not onRing.quest then
        local info = C_Texture.GetAtlasInfo(QUEST_ATLAS)
        local aspect = (info and info.width > 0 and info.height > 0) and (info.width / info.height) or 1
        -- centred on the health bar's right edge, like a badge (clear of the raid marker and the health text)
        ICON_UI.Place(f.QuestIcon, ICON_SIZE.quest * aspect, ICON_SIZE.quest, "CENTER", f.Health, "RIGHT", 0, 0)
    end
    if f.ReadyIcon and not onRing.readyCheck then
        -- mid health bar, over the raid marker, sized to the bar
        local healthHeight = ((udb and udb.height) or 44) - ((udb and udb.powerHeight) or 0) - 2 * INSET
        local size = math.min(32, math.max(14, healthHeight - 4))
        ICON_UI.Place(f.ReadyIcon, size, size, "CENTER", f.Health, "CENTER", 0, 0)
    end
    if f.HealClip then
        local health, clip, heal, absorb = f.Health, f.HealClip, f.HealBar, f.AbsorbBar
        local fill = health:GetStatusBarTexture()
        local width = (udb and udb.width or 220) - 2 * INSET - PortraitSpace(f)
        -- Forever Style: the bar is bigger than its slot (its art has margins round the colour):
        -- the overlays keep to the colour, and scale with the bar's whole length as the health does
        local inset = health.FlareUI_PlateInset
        if inset then width = inset.length end

        clip:ClearAllPoints()
        heal:ClearAllPoints()
        absorb:ClearAllPoints()
        heal:SetWidth(width)
        absorb:SetWidth(width)
        mirror = fillMirror
        heal:SetReverseFill(mirror)
        -- incoming heals in the frame's own bar texture (on the plate, whose bars are Blizzard's art:
        -- FlareUI Dark, the same art)
        heal:SetStatusBarTexture(GetBarTexture(inset and "FlareUI Dark" or (udb and udb.texture), mirror))
        -- shields follow the health and the incoming heals, as Blizzard's frames draw them: what the
        -- bar has no room for is cut at its end, where the over-shield glow shows instead
        absorb:SetReverseFill(mirror)

        -- the clip keeps the overlays inside the bar without comparing (secret) values
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

        -- the absorb starts where the incoming heals end (the heal fill's far edge: no secret value read)
        local near, far = mirror and "RIGHT" or "LEFT", mirror and "LEFT" or "RIGHT"
        local healFill = heal:GetStatusBarTexture()
        absorb:SetPoint("TOP" .. near, healFill, "TOP" .. far, 0, 0)
        absorb:SetPoint("BOTTOM" .. near, healFill, "BOTTOM" .. far, 0, 0)
        UF.PlaceShieldGlow(f.ShieldGlow, health, mirror)

        -- the absorb sits over the heals
        local base = clip:GetFrameLevel()
        absorb:SetFrameLevel(base + 2)
        heal:SetFrameLevel(base + 1)

        -- "" is the dropdown's Frame Texture entry, so it means the frame's own bar texture
        local absorbTex = udb and udb.absorbTexture
        if absorbTex == nil then absorbTex = ABSORB_TEXTURE end
        if absorbTex == "" then absorbTex = udb and udb.texture end
        absorb:SetStatusBarTexture(GetBarTexture(absorbTex))
        absorb:SetStatusBarColor(unpack(ABSORB_COLOR))
        heal:SetStatusBarColor(unpack(HEAL_COLOR))   -- (the Colour Palette may have changed it)
        UF.PlaceOverAbsorb(f.OverAbsorb, health, width, mirror, GetBarTexture(absorbTex))
    end
end

-- SHIELD OVER THE HEALTH: the shield that has no room after the health
-- (all of it at full health) is drawn back from the health's end, over the health, so a shield on
-- the pull shows how much is left as it is hit. Without comparing (secret) values: a bar as long as
-- the whole health bar, anchored where the health starts and filled from its far end with the whole
-- shield, inside a clip frame over the health fill. Only its part over the health shows: the shield
-- minus the health missing, ending where the health ends. The part after the health is AbsorbBar's.
function UF.CreateOverAbsorb(health, clip)
    local over = CreateFrame("Frame", nil, health)
    over:SetClipsChildren(true)
    over:SetFrameLevel((clip or health):GetFrameLevel() + 2)
    local bar = CreateFrame("StatusBar", nil, over)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    over.Bar = bar
    return over
end

function UF.PlaceOverAbsorb(over, health, width, mirror, texture)
    if not over then return end
    local fill = health:GetStatusBarTexture()
    local near = mirror and "RIGHT" or "LEFT"
    over:ClearAllPoints()
    over:SetAllPoints(fill)
    local bar = over.Bar
    bar:ClearAllPoints()
    bar:SetPoint("TOP" .. near, fill, "TOP" .. near, 0, 0)
    bar:SetPoint("BOTTOM" .. near, fill, "BOTTOM" .. near, 0, 0)
    bar:SetWidth(width)
    bar:SetReverseFill(not mirror)
    bar:SetStatusBarTexture(texture)
    -- see-through: the health still reads under it, also under a shield larger than the whole bar
    -- (Templar's Bulwark covered all of it at 0.75, capo's report 11-19)
    bar:SetStatusBarColor(ABSORB_COLOR[1], ABSORB_COLOR[2], ABSORB_COLOR[3], 0.4)
end

-- value nil: none (Edit Mode samples pass theirs on a 0..1 health)
function UF.SetOverAbsorb(over, unit, max, value)
    if not over then return end
    local bar = over.Bar
    if value then
        bar:SetMinMaxValues(0, max or 1)
        bar:SetValue(value)
        return
    end
    if not unit then bar:SetValue(0) return end
    pcall(bar.SetMinMaxValues, bar, 0, max)
    -- (no closure: this runs on every health tick)
    local ok, total = pcall(UnitGetTotalAbsorbs, unit)
    if not (ok and pcall(bar.SetValue, bar, total)) then bar:SetValue(0) end
end

-- Over-shield glow: shields never draw past the bar (the calculator clamps them to the health
-- missing), so a unit with more shield than missing health, at full health too, gets Blizzard's
-- raid-frame glow at the bar's far end. The calculator's "clamped" flag (maybe secret) drives it.
UF.SHIELD_GLOW_ATLAS = "RaidFrame-Shield-Overshield"

-- clip: the heal/absorb clip frame; the glow sits over it and is not clipped by it
function UF.CreateShieldGlow(health, clip)
    local holder = CreateFrame("Frame", nil, health)
    holder:SetAllPoints(health)
    holder:SetFrameLevel((clip or health):GetFrameLevel() + 3)
    local glow = holder:CreateTexture(nil, "OVERLAY", nil, 7)
    local ok, set = pcall(glow.SetAtlas, glow, UF.SHIELD_GLOW_ATLAS, false)
    if not (ok and set) then
        glow:SetColorTexture(1, 1, 1, 0.6)
    end
    glow:SetBlendMode("ADD")
    -- the boolean alpha goes on the holder frame: on a texture it draws nothing on this client
    glow.holder = holder
    holder:SetAlpha(0)
    return glow
end

-- on the far end of the bar (the left on a mirrored fill)
function UF.PlaceShieldGlow(glow, health, mirror)
    if not glow then return end
    glow:ClearAllPoints()
    local edge = mirror and "LEFT" or "RIGHT"
    local x = mirror and 7 or -7
    glow:SetPoint("TOP" .. (mirror and "RIGHT" or "LEFT"), health, "TOP" .. edge, x, 0)
    glow:SetPoint("BOTTOM" .. (mirror and "RIGHT" or "LEFT"), health, "BOTTOM" .. edge, x, 0)
    glow:SetWidth(16)
    local info = C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(UF.SHIELD_GLOW_ATLAS)
    if info then
        local l, r = info.leftTexCoord, info.rightTexCoord
        if mirror then l, r = r, l end
        glow:SetTexCoord(l, r, info.topTexCoord, info.bottomTexCoord)
    end
end

-- clamped: GetDamageAbsorbs' second return (maybe secret: never tested in Lua)
function UF.SetShieldGlow(glow, clamped)
    if not glow then return end
    local holder = glow.holder
    if not (holder.SetAlphaFromBoolean and pcall(holder.SetAlphaFromBoolean, holder, clamped, 1, 0)) then
        holder:SetAlpha(0)
    end
end

-- Edit Mode, no calculator
function UF.HideShieldGlow(glow)
    if glow then glow.holder:SetAlpha(0) end
end

-- DAMAGE TRAIL (each frame's Damage Trail switch, on): the health just lost stays a moment in a light
-- colour, then shrinks to the new health. Without comparing (secret) values: a second bar the size of the
-- health bar, in its texture and fill direction, inside a clip frame over the bar's empty part (the
-- heal clip when there is one, under the heals and shields). Only its part past the health shows.
-- Each health change (re)starts a short hold; then the trail glides to the health as it is then
-- (the client eases secret values). Healing needs nothing: the trail lags under the health fill,
-- where it is clipped, and catches up. One OnUpdate, only while a trail waits to move.
UF.TRAIL_DELAY = 0.4    -- seconds the lost health holds after a change
UF.TRAIL_HOLD = 1.2     -- the most a burst of changes can hold it
UF.TRAIL_COLOR = { 1, 0.9, 0.75, 0.7 }   -- a warm near-white: reads on green, class and reaction colours
UF.trailPending = {}    -- trail -> time it starts to move

-- clip: the heal / absorb clip frame of the bar, or nil (the trail makes its own)
function UF.CreateDamageTrail(health, clip)
    local own = not clip
    if own then
        clip = CreateFrame("Frame", nil, health)
        clip:SetFrameLevel(health:GetFrameLevel() + 1)
        clip:SetClipsChildren(true)
    end
    local trail = CreateFrame("StatusBar", nil, clip)
    -- at the clip's own level: the heals (+1) and shields (+2) draw over it
    trail:SetFrameLevel(clip:GetFrameLevel())
    trail:SetMinMaxValues(0, 1)
    trail:SetValue(0)
    trail:SetAllPoints(health)
    trail:Hide()
    trail.clip, trail.ownClip, trail.health = clip, own, health
    return trail
end

-- after the health bar's texture, fill direction and place are set (any style: the trail follows
-- the bar itself). mirror: the bar fills from the right.
-- color: the Resource Bars pass their palette's, the unit frames use UF.TRAIL_COLOR
function UF.PlaceDamageTrail(trail, mirror, color)
    if not trail then return end
    local health = trail.health
    local fill = health:GetStatusBarTexture()
    if trail.ownClip then
        -- the bar's empty part, as the heal clip's
        local clip = trail.clip
        clip:ClearAllPoints()
        if mirror then
            clip:SetPoint("TOPLEFT", health, "TOPLEFT", 0, 0)
            clip:SetPoint("BOTTOMRIGHT", fill, "BOTTOMLEFT", 0, 0)
        else
            clip:SetPoint("TOPLEFT", fill, "TOPRIGHT", 0, 0)
            clip:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", 0, 0)
        end
    end
    trail:SetReverseFill(mirror and true or false)
    trail:SetStatusBarTexture((fill and fill:GetTexture()) or BACKDROP_FILE)
    local c = color or UF.TRAIL_COLOR
    trail:SetStatusBarColor(c[1], c[2], c[3], UF.TRAIL_COLOR[4])
end

function UF.MoveDamageTrails(self)
    local now, waiting = GetTime(), false
    for trail, due in pairs(UF.trailPending) do
        if now >= due then
            UF.trailPending[trail] = nil
            trail.firstAt = nil
            local unit = trail.unit
            if unit and trail:IsShown() and UnitExists(unit) then
                ns.SetBarValue(trail, UnitHealth(unit), true)
            end
        else
            waiting = true
        end
    end
    if not waiting then self:SetScript("OnUpdate", nil) end
end

-- After the health bar is set. glide: a change on the unit already shown (a new unit, or a frame
-- just shown, lands at once); on: false hides it (the frame's Damage Trail switch).
-- A nameplate maintains the trail's range on maximum-health changes and supplies the bar value.
function UF.SetDamageTrail(trail, unit, glide, on, values)
    if not trail then return end
    -- (off while Smooth Animated Bars' liquid owns the bar: ns.SAB below)
    if not on or ns.SAB.owned[trail.health] then
        UF.trailPending[trail], trail.firstAt = nil, nil
        if trail:IsShown() then trail:Hide() end
        return
    end
    trail:Show()
    trail.unit = unit
    if not values then trail:SetMinMaxValues(0, UnitHealthMax(unit)) end
    if not glide or not trail:IsVisible() then
        UF.trailPending[trail], trail.firstAt = nil, nil
        if values then trail:SetValue(values.cur) else trail:SetValue(UnitHealth(unit)) end
        return
    end
    local now = GetTime()
    trail.firstAt = trail.firstAt or now
    UF.trailPending[trail] = math.min(now + UF.TRAIL_DELAY, trail.firstAt + UF.TRAIL_HOLD)
    if not UF.trailDriver then UF.trailDriver = CreateFrame("Frame") end
    UF.trailDriver:SetScript("OnUpdate", UF.MoveDamageTrails)
end

-- Edit Mode: a sample hit just taken, on a 0..1 sample health
function UF.SampleDamageTrail(trail, health, on)
    if not trail then return end
    UF.trailPending[trail], trail.firstAt = nil, nil
    if not on or ns.SAB.owned[trail.health] then trail:Hide() return end
    trail:SetMinMaxValues(0, 1)
    trail:SetValue(math.min(1, (health or 1) + 0.15))
    trail:Show()
end

-- BAR EDGE GLOW: an edge line and a front glow (art: Media/Bars/FlareUI-EdgeLine / -EdgeGlow, made by
-- a script). A per-frame switch (barEdgeGlow, off) in the Look section of each frame's Edit Mode dialog:
-- the unit frames (UF.BarEdgeGlowSetting), party / raid / boss tiles (PartyFrames.lua) and the Resource
-- Bars' health (ResourceBars.lua). No health value is read: everything hangs off the fill texture's
-- edge, as the Damage Trail's clip does.
-- A clip frame over the whole bar (one level above it: under the heals at +2 in the heal clip) holds a
-- bright line just inside the fill's front and a soft glow centred on it. Each health change bumps the
-- glow for a quarter second (an animation, no OnUpdate). A dead unit's edge is hidden.
-- A bar Smooth Animated Bars owns (ns.SAB.owned) gets none: its liquid replaces it. Ring styles: the
-- two textures are in the bar's ring hole list (UnitFramesRing.lua BarHoleRegions, bar.fuiLook).
UF.LOOK = {
    LINE = "Interface\\AddOns\\FlareUI\\Media\\Bars\\FlareUI-EdgeLine",
    GLOW = "Interface\\AddOns\\FlareUI\\Media\\Bars\\FlareUI-EdgeGlow",
    LINE_ALPHA = 0.35, GLOW_ALPHA = 0.22, GLOW_PEAK = 0.55,
}

function UF.CreateBarLook(bar)
    local level = bar:GetFrameLevel() + 1
    local look = { bar = bar }
    -- the whole bar, clipped (the glow never spills onto the border)
    local edgeClip = CreateFrame("Frame", nil, bar)
    edgeClip:SetAllPoints(bar)
    edgeClip:SetFrameLevel(level)
    edgeClip:SetClipsChildren(true)
    local edge = CreateFrame("Frame", nil, edgeClip)
    edge:SetAllPoints(edgeClip)
    edge:SetFrameLevel(level)
    local glow = edge:CreateTexture(nil, "ARTWORK")
    glow:SetTexture(UF.LOOK.GLOW)
    glow:SetBlendMode("ADD")
    glow:SetAlpha(UF.LOOK.GLOW_ALPHA)
    local line = edge:CreateTexture(nil, "OVERLAY")
    line:SetTexture(UF.LOOK.LINE)
    line:SetBlendMode("ADD")
    line:SetAlpha(UF.LOOK.LINE_ALPHA)
    -- the bump on a health change: up fast, back slower (the glow's own alpha after)
    local pulse = glow:CreateAnimationGroup()
    local up = pulse:CreateAnimation("Alpha")
    up:SetFromAlpha(UF.LOOK.GLOW_ALPHA)
    up:SetToAlpha(UF.LOOK.GLOW_PEAK)
    up:SetDuration(0.07)
    up:SetOrder(1)
    local down = pulse:CreateAnimation("Alpha")
    down:SetFromAlpha(UF.LOOK.GLOW_PEAK)
    down:SetToAlpha(UF.LOOK.GLOW_ALPHA)
    down:SetDuration(0.18)
    down:SetOrder(2)
    -- sizes follow the bar's height
    edge:SetScript("OnSizeChanged", function(_, _, h)
        if type(h) ~= "number" or h <= 0 then return end
        line:SetWidth(h >= 24 and 6 or (h >= 12 and 5 or 4))
        glow:SetWidth(math.max(14, math.min(36, h * 1.6)))
    end)
    edgeClip:Hide()
    look.edgeClip, look.edge, look.line, look.glow, look.pulse = edgeClip, edge, line, glow, pulse
    bar.fuiLook = look
    return look
end

-- At the bar's layout, after its texture and fill direction are set (before the ring style's
-- layout, which masks bar.fuiLook's textures). mirror: the bar fills from the right; on: the frame's
-- Bar Edge Glow switch. Made the first time it is on; off, it is only hidden.
function UF.BarLook(bar, mirror, on)
    if not bar then return end
    bar.fuiLookMirror = mirror and true or false
    bar.fuiLookOn = on and true or false
    local edgeOn = bar.fuiLookOn
    if ns.SAB and ns.SAB.owned[bar] then edgeOn = false end
    local look = bar.fuiLook
    if not look then
        if not edgeOn then return end
        look = UF.CreateBarLook(bar)
    end
    local fill = bar:GetStatusBarTexture()
    if not fill then edgeOn = false end
    if edgeOn then
        local front = mirror and "LEFT" or "RIGHT"
        local line, glow = look.line, look.glow
        -- centred on the fill's front, as the glow (inside the fill it reads as a line short of the edge)
        line:ClearAllPoints()
        line:SetPoint("TOP", fill, "TOP" .. front, 0, 0)
        line:SetPoint("BOTTOM", fill, "BOTTOM" .. front, 0, 0)
        glow:ClearAllPoints()
        glow:SetPoint("TOP", fill, "TOP" .. front, 0, 0)
        glow:SetPoint("BOTTOM", fill, "BOTTOM" .. front, 0, 0)
    else
        look.pulse:Stop()
    end
    look.edgeClip:SetShown(edgeOn)
end

-- Edge Glow in a frame's Cast Bar section (unit, party, boss and flag carrier frames): db() the
-- frame's saved table, set its castGlow setter, hidden the section's own (no cast bar)
function UF.CastGlowSetting(db, set, hidden)
    return { name = L["Edge Glow"], kind = LEM.SettingType.Checkbox, default = ns.CastGlowDefault(),
        get = function() local u = db() return ns.CastGlowOn(u and u.castGlow) end,
        set = set, hidden = hidden,
        desc = L["A bright edge at the front of the cast, as on Blizzard's cast bars."] }
end

-- Smooth Animated Bars took or gave back the bar (ns.SAB.Pass)
function UF.BarLookOwnerChanged(bar)
    if bar and bar.fuiLookMirror ~= nil then UF.BarLook(bar, bar.fuiLookMirror, bar.fuiLookOn) end
end

-- After each health update. unit: the bar's unit (nil: a sample, never dead unless dead is given);
-- changed: a change on the unit already shown (the glow's bump).
function UF.BarLookUpdate(bar, unit, changed, dead)
    local look = bar and bar.fuiLook
    if not (look and look.edgeClip:IsShown()) then return end
    if unit then dead = UF.IsDead(unit) end
    if not canaccessvalue(dead) then dead = false end
    -- none at full health: the bar has no front to show then. The same step curve as
    -- Health Lost (1 below full, 0 at full), so a secret health works too
    if unit and not dead then
        look.edge:SetAlpha(UnitHealthPercent(unit, true, UF.LostCurve()))
    else
        look.edge:SetAlpha(dead and 0 or 1)
    end
    if changed and not dead and look.edge:IsVisible() then
        look.pulse:Stop()
        look.pulse:Play()
    end
end

-- Look section switch (default off)
function UF.BarEdgeGlowSetting(get, set)
    return { name = L["Bar Edge Glow"], kind = LEM.SettingType.Checkbox, default = false,
        get = function() return get() and true or false end, set = set,
        desc = L["A bright line and a soft glow at the front of the health bar. It flashes when health changes."] }
end

-- Damage Trail switch: on by default; saved as "damageTrail" (false = off). Right under Bar Edge Glow
-- in the Look section. on(v): the saved value -> shown.
function UF.DamageTrailOn(v) return v ~= false end
function UF.DamageTrailSetting(get, set)
    return { name = L["Damage Trail"], kind = LEM.SettingType.Checkbox, default = true,
        get = function() return UF.DamageTrailOn(get()) end, set = set,
        desc = L["Health you lose stays a moment in a light colour, then shrinks away. It isn't one of the Bar Animations."] }
end

-- TINT HEALTH (saved as healthColor): the health bar's colour follows the health left.
--   off    : the frame's own colour (class, reaction, green)
--   low    : that colour, red under 30%
--   health : green at full, yellow at half, red when nearly dead
-- Health is secret, so Lua never sees the percent: UnitHealthPercent evaluates a colour curve and
-- hands back the colour, which goes straight to SetStatusBarColor. "low" needs a curve per base
-- colour (step: red, then the base at 30%), cached by colour; a secret base (a chained unit's
-- secret class) keeps its own colour. Offline and tapped units stay grey. Every unit frame, the
-- party, raid and boss tiles (their pets and targets follow) and the Resource Bars' health bar.
-- In each frame's Behaviour section (any row not in Size or Text lands there: Core.lua
-- ns.SplitFrameItems). Default Off.
UF.HealthTint = { AT = 0.3, RED = { 0.85, 0.1, 0.1 }, YELLOW = { 0.95, 0.8, 0.1 }, steps = {} }
function UF.HealthColorMode(db)
    local v = db and db.healthColor
    if v == "low" or v == "health" then return v end
    return "off"
end
-- the colour must be set again on every health change (not only on a unit or setting change)
function UF.HealthColorLive(db) return UF.HealthColorMode(db) ~= "off" end
function UF.HealthTint.Gradient()
    local T = UF.HealthTint
    if T.gradient == nil then
        T.gradient = false
        local ok, curve = pcall(C_CurveUtil.CreateColorCurve)
        if ok and curve then
            pcall(curve.SetType, curve, Enum.LuaCurveType.Linear)
            local green = ns.HEALTH_GREEN
            curve:AddPoint(0, CreateColor(T.RED[1], T.RED[2], T.RED[3], 1))
            curve:AddPoint(0.5, CreateColor(T.YELLOW[1], T.YELLOW[2], T.YELLOW[3], 1))
            curve:AddPoint(1, CreateColor(green[1], green[2], green[3], 1))
            T.gradient = curve
        end
    end
    return T.gradient or nil
end
function UF.HealthTint.Step(r, g, b)
    local T = UF.HealthTint
    if not (canaccessvalue(r) and canaccessvalue(g) and canaccessvalue(b)) then return nil end
    local key = string.format("%.3f:%.3f:%.3f", r, g, b)
    local curve = T.steps[key]
    if curve == nil then
        curve = false
        local ok, made = pcall(C_CurveUtil.CreateColorCurve)
        if ok and made then
            pcall(made.SetType, made, Enum.LuaCurveType.Step)
            made:AddPoint(0, CreateColor(T.RED[1], T.RED[2], T.RED[3], 1))
            made:AddPoint(T.AT, CreateColor(r, g, b, 1))
            curve = made
        end
        T.steps[key] = curve
    end
    return curve or nil
end
function UF.HealthTint.CurveRGB(unit, curve)
    local color = UnitHealthPercent(unit, true, curve)
    return color:GetRGB()
end
-- The health bar's colour with the frame's Health Colour (db: the frame's settings)
function UF.HealthBarColor(unit, classOn, db)
    local mode = UF.HealthColorMode(db)
    local r, g, b = GetHealthColor(unit, classOn)
    if mode == "off" or not (C_CurveUtil and C_CurveUtil.CreateColorCurve and UnitHealthPercent) then return r, g, b end
    if not UnitIsConnected(unit) or UnitIsTapDenied(unit) then return r, g, b end
    local curve
    if mode == "health" then curve = UF.HealthTint.Gradient() else curve = UF.HealthTint.Step(r, g, b) end
    if not curve then return r, g, b end
    local ok, cr, cg, cb = pcall(UF.HealthTint.CurveRGB, unit, curve)
    if ok then return cr, cg, cb end   -- (never test cr itself: a secret number cannot be tested)
    return r, g, b
end
-- Edit Mode samples: the same colours from the sample's plain health (0..1) and base colour
function UF.SampleHealthColor(db, health, r, g, b)
    local T, mode = UF.HealthTint, UF.HealthColorMode(db)
    if mode == "low" then
        if health < T.AT then return T.RED[1], T.RED[2], T.RED[3] end
        return r, g, b
    elseif mode == "health" then
        local green = ns.HEALTH_GREEN
        local from, to, t
        if health < 0.5 then from, to, t = T.RED, T.YELLOW, health / 0.5 else from, to, t = T.YELLOW, green, (health - 0.5) / 0.5 end
        return from[1] + (to[1] - from[1]) * t, from[2] + (to[2] - from[2]) * t, from[3] + (to[3] - from[3]) * t
    end
    return r, g, b
end
function UF.HealthColorSetting(get, set)
    return { name = L["Tint Health"], kind = LEM.SettingType.Dropdown, default = "off",
        values = {
            { text = L["Off"], value = "off", isRadio = true },
            { text = L["On Low Health"], value = "low", isRadio = true },
            { text = L["By Health"], value = "health", isRadio = true },
        },
        get = function() return UF.HealthColorMode({ healthColor = get() }) end, set = set,
        desc = L["The health bar's colour follows the health left:\n* On Low Health: red under 30%\n* By Health: green at full, yellow at half, red when nearly dead. Takes over from Class Colours.\nOffline and tapped units stay grey."] }
end

-- SMOOTH ANIMATED BARS SUPPORT. Smooth Animated Bars (SAB, MIT, its own
-- addon) puts its liquid on other addons' bars through its public API (SmoothAnimatedBars.AddBar /
-- RemoveBar / IsEnabled / RegisterCallback, its SmoothAnimatedBars.lua "For other addons"). While SAB
-- is installed and its "other addons' bars" switch is on, FlareUI hands it the health and power bars
-- of the player, target, focus, pet and target-of frames, the party tiles' health bars (not raid or
-- boss tiles: SAB takes at most ten group bars) and the Resource Bars' health and power. No option of
-- ours: SAB's switch decides, and its callback adds or removes them. Without SAB nothing happens.
-- SAB adds child frames to the bar (a clip one level above it, LEVEL), makes our fill see-through and
-- reads our colour and fill direction itself. Our heals and shields stay over it: in the heal clip
-- (bar +1) they are at +2 / +3, the over-shield at +3, the glow at +4. Our fill keeps moving
-- (unseen), so they stay anchored to it; Smooth Bar Animations keeps easing it alongside the liquid.
-- The Damage Trail is off on a bar SAB owns (it would fight the liquid). Ring styles: the bar's
-- portrait hole goes to SAB as its mask (UnitFramesRing.lua Ring.SabHole). Out of combat only.
ns.SAB = {
    bars = {},       -- bar -> { unit, kind, wanted, holeOwner, trail }
    owned = {},      -- bar -> true while SAB has it from us
    LEVEL = 1,       -- SAB's clip: one level over the bar, under our heal and shield bars
    MIN_HEIGHT = 6,  -- thinner bars stay ours: the liquid's waves and bubbles are noise at that size
}

-- At a frame's layout (again and again is fine). holeOwner: the frame whose ring hole masks the
-- liquid; trail: the bar's Damage Trail.
function ns.SAB.Want(bar, unit, kind, wanted, holeOwner, trail)
    local S = ns.SAB
    if not bar or S.absent then return end
    local e = S.bars[bar]
    if not e then
        e = {}
        S.bars[bar] = e
    end
    e.unit, e.kind, e.wanted = unit, kind, (wanted and unit) and true or false
    e.holeOwner, e.trail = holeOwner, trail
    S.Schedule()
end

-- One pass next frame (so the bars' sizes are laid out), or after the fight
function ns.SAB.Schedule()
    local S = ns.SAB
    if S.absent or S.queued then return end
    if not S.events then
        S.events = CreateFrame("Frame")
        S.events:RegisterEvent("PLAYER_ENTERING_WORLD")
        S.events:SetScript("OnEvent", function(self, event)
            if event == "PLAYER_REGEN_ENABLED" then self:UnregisterEvent(event) end
            if event == "PLAYER_ENTERING_WORLD" then S.inWorld = true end
            S.Schedule()
        end)
    end
    S.queued = true
    C_Timer.After(0, S.Pass)
end

function ns.SAB.Pass()
    local S = ns.SAB
    S.queued = false
    local api = _G.SmoothAnimatedBars
    if type(api) ~= "table" then
        -- not installed (every addon has loaded once the player is in the world): stop for good
        if S.inWorld then
            S.absent = true
            S.events:UnregisterAllEvents()
            S.bars = {}
        end
        return
    end
    if InCombatLockdown() then
        S.events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    if not S.hooked then
        S.hooked = true
        pcall(api.RegisterCallback, function(event) if event == "enabled" then S.Schedule() end end)
    end
    local okOn, on = pcall(api.IsEnabled)
    on = okOn and on and true or false
    for bar, e in pairs(S.bars) do
        local want = on and e.wanted
        if want then
            local okH, h = pcall(bar.GetHeight, bar)
            if okH and type(h) == "number" and h > 0 and h < S.MIN_HEIGHT then want = false end
        end
        if want then
            -- (SAB keeps the mask it gets the first time: always the same one, ring or not)
            local mask = e.holeOwner and ns.UFRing and ns.UFRing.SabHole and ns.UFRing.SabHole(e.holeOwner)
            local ok, taken = pcall(api.AddBar, bar, e.unit, e.kind, { name = "FlareUI", level = S.LEVEL, mask = mask })
            want = (ok and taken) and true or false
            if not ok then pcall(api.RemoveBar, bar) end
        elseif S.owned[bar] then
            pcall(api.RemoveBar, bar)
        end
        if want ~= (S.owned[bar] or false) then
            S.owned[bar] = want or nil
            S.TrailChanged(e.trail, want)
            -- our Bar Edge Glow steps aside for the liquid, or comes back
            UF.BarLookOwnerChanged(bar)
        end
    end
end

-- The Damage Trail of a bar SAB takes (hidden) or gives back (set to the health now, still hidden:
-- the next health change shows it again without a stale piece gliding away)
function ns.SAB.TrailChanged(trail, owned)
    if not trail then return end
    UF.trailPending[trail], trail.firstAt = nil, nil
    if owned then
        trail:Hide()
        return
    end
    local unit = trail.unit
    if unit and UnitExists(unit) then
        pcall(trail.SetMinMaxValues, trail, 0, UnitHealthMax(unit))
        pcall(trail.SetValue, trail, UnitHealth(unit))
    end
end

-- A unit frame's health and power bars (not a settings preview's)
function ns.SAB.UnitFrame(f)
    if f.fuiSample or ns.SAB.absent then return end
    ns.SAB.Want(f.Health, f.fuiUnit, "health", true, f, f.DamageTrail)
    ns.SAB.Want(f.Power, f.fuiUnit, "power", f.Power:IsShown(), f)
end

function UpdateHealPrediction(f)
    local heal, absorb = f.HealBar, f.AbsorbBar
    if not heal then return end
    -- Edit Mode: a sample incoming heal and barrier on the sample health (UpdateHealth, 0..1)
    if ns.EditPreviewing() then
        heal:SetMinMaxValues(0, 1)
        absorb:SetMinMaxValues(0, 1)
        heal:SetValue(0.12)
        absorb:SetValue(0.15)
        UF.HideShieldGlow(f.ShieldGlow)
        UF.SetOverAbsorb(f.OverAbsorb, nil, 1, 0.15)
        return
    end
    local unit = f.fuiUnit
    local max = UnitHealthMax(unit)
    heal:SetMinMaxValues(0, max)
    absorb:SetMinMaxValues(0, max)
    UF.SetOverAbsorb(f.OverAbsorb, unit, max)
    -- the calculator hands back (possibly secret) numbers that SetValue accepts as-is
    local calc = f.HealCalc
    if calc and UnitGetDetailedHealPrediction then
        local ok = pcall(UnitGetDetailedHealPrediction, unit, "player", calc)
        if ok then
            local okH, incoming = pcall(calc.GetIncomingHeals, calc)
            local okA, absorbs, clamped = pcall(calc.GetDamageAbsorbs, calc)
            if okH then heal:SetValue(incoming) end
            if okA then absorb:SetValue(absorbs) end
            if okA then UF.SetShieldGlow(f.ShieldGlow, clamped) else UF.HideShieldGlow(f.ShieldGlow) end
            return
        end
    end
    UF.HideShieldGlow(f.ShieldGlow)
    local okH, incoming = pcall(UnitGetIncomingHeals, unit)
    if okH then pcall(heal.SetValue, heal, incoming) end
    local okA, absorbs = pcall(UnitGetTotalAbsorbs, unit)
    if okA then pcall(absorb.SetValue, absorb, absorbs) end
end

-- Threat on this unit: 1 above the tank, 2 tanking insecurely, 3 tanking securely. Muted versions of
-- Blizzard's colours.
local THREAT_COLORS = {
    [1] = { 0.80, 0.68, 0.30 },   -- above the tank
    [2] = { 0.80, 0.48, 0.25 },   -- tanking, insecure
    [3] = { 0.78, 0.28, 0.24 },   -- tanking, secure
}
local function ThreatColor(status)
    local c = THREAT_COLORS[status] or THREAT_COLORS[3]
    return c[1], c[2], c[3]
end

-- Show Threat (target, focus): your threat on the unit as a percent, in Blizzard's threat colours
-- (white with none, then yellow, orange, red). Ring styles: a big number above the portrait ring
-- (the auras keep clear of the ring). Addon Style: after the health value, "75% | 42%". Threat
-- values are readable on Forever; a hidden one shows nothing. Tanking, it shows your lead (over 100%).
-- The text is placed once per layout (f.threatLaid, cleared by LayoutFrame), not on every threat event.
UF.THREAT_PERCENT_UNITS = { target = true, focus = true }
UF.THREAT_RING_SIZE = 8   -- added to the frame font's size above the ring
-- the ring's frame is the box round its art, shadow and all, wider on its outer side: the number moves
-- this share of the ring's width towards the frame, over the ring's middle
UF.THREAT_RING_NUDGE = 0
function UF.UpdateThreatPercent(f)
    local unit = f.fuiUnit
    if not UF.THREAT_PERCENT_UNITS[unit] then return end
    local udb = GetUnitDb(unit)
    local text = f.ThreatText
    if not (udb and udb.threatPercent) then if text then text:Hide() end return end
    if not text then
        -- a layer a strata above the frame: the number draws over the raid marker and the ring's art
        local layer = CreateFrame("Frame", nil, f)
        layer:SetAllPoints(f)
        layer:SetFrameStrata("MEDIUM")
        text = UF.NewText(layer)
        text:SetWordWrap(false)
        f.ThreatText = text
    end
    local ring = ns.UFRing and ns.UFRing.Applies(f) and f.RingFrame
    local mirrored = not ring and UF.LayoutMirrored(f)
    local laid = ring and "ring" or (mirrored and "mirror" or "plain")
    if f.threatLaid ~= laid then
        f.threatLaid = laid
        local db = GetDb()
        text:ClearAllPoints()
        if ring then
            ApplyFont(text, UF.Font(f.fuiUnit, "health"), UF.THREAT_RING_SIZE)
            text:SetJustifyH("CENTER")
            f.threatNudgeWidth = nil   -- placed below, once the ring has its size
        else
            -- the health value, then the threat: the texts beside it move over for it
            ApplyFont(text, UF.Font(f.fuiUnit, "health"), 0)
            if mirrored then
                text:SetJustifyH("LEFT")
                text:SetPoint("LEFT", f.HealthText, "RIGHT", 0, 0)
                if f.btNameNextTo == f.HealthText then f.Name:SetPoint("LEFT", text, "RIGHT", 4, 0) end
            else
                text:SetJustifyH("RIGHT")
                text:SetPoint("RIGHT", f.Health, "RIGHT", -TEXT_INSET, 0)
                f.HealthText:SetPoint("RIGHT", text, "LEFT", 0, 0)
            end
        end
    end
    -- the ring's number: placed again whenever the ring's width changes (it has none at the first layout).
    -- Side is the ring's side of the frame, so the frame is the other way.
    if ring then
        local width = ring:GetWidth() or 0
        if width > 0 and f.threatNudgeWidth ~= width then
            f.threatNudgeWidth = width
            local towardsFrame = (ns.UFRing.Side and ns.UFRing.Side(f) == "LEFT") and 1 or -1
            text:ClearAllPoints()
            text:SetPoint("BOTTOM", ring, "TOP", towardsFrame * width * UF.THREAT_RING_NUDGE, 2)
        end
    end
    text:Show()
    local display, status
    -- Edit Mode shows a sample whatever is targeted
    if ns.EditPreviewing() then
        display, status = 75, 1
    else
        -- the scaled percent: 100% is where you pull the mob
        local ok, tanking, detailed, scaled = pcall(UnitDetailedThreatSituation, "player", unit)
        if ok and canaccessallvalues(tanking, detailed, scaled) then
            display, status = scaled, detailed
            if tanking then
                local lead = UnitThreatPercentageOfLead("player", unit)
                if canaccessvalue(lead) and lead then display = lead end
            end
        end
        local class = UnitClassification(unit)
        if canaccessvalue(class) and class == "minus" then display = nil end
    end
    if not display or display == 0 then text:SetText("") return end
    local r, g, b = 1, 1, 1
    if status and status >= 1 and GetThreatStatusColor then r, g, b = GetThreatStatusColor(status) end
    if ring then
        text:SetTextColor(r, g, b)
        text:SetFormattedText("%.0f%%", display)
    else
        text:SetTextColor(f.HealthText:GetTextColor())
        text:SetFormattedText(" | |cff%02x%02x%02x%.0f%%|r", r * 255, g * 255, b * 255, display)
    end
end

-- Threat Glow (target, focus, the styled pet): the border pulses in the threat colour (target and focus:
-- the player's threat on the unit; the pet: its own aggro). Combat Glow (player): the border pulses red
-- in a fight, in the threat colour while the player has threat (its highest on anything). The portrait
-- ring follows in UnitFramesRing.lua. None in Edit Mode, but for the aggro test.
function UpdateThreat(f)
    UF.UpdateThreatPercent(f)
    if not f.threatTint then return end
    local unit = f.fuiUnit
    local info = UNITS[unit]
    local live = not ns.EditPreviewing()
    if unit == "player" then
        if not (info.combatGlow and UF.GlowOn(unit, "combatGlow")) then UF.SetBorderGlow(f.Border) return end
        local status = live and Readable(UnitThreatSituation("player")) or nil
        if status and status >= 1 then
            UF.SetBorderGlow(f.Border, ThreatColor(status))
        elseif live and Readable(UnitAffectingCombat("player")) then
            local c = UF.COMBAT_RGB
            UF.SetBorderGlow(f.Border, c[1], c[2], c[3])
        else
            UF.SetBorderGlow(f.Border)
        end
        return
    end
    if not info.threatGlow or info.noThreatGlow or not UF.GlowOn(unit, "threatGlow") then UF.SetBorderGlow(f.Border) return end
    local status
    if live then
        if unit == "pet" then
            status = Readable(UnitThreatSituation(unit))
        else
            status = Readable(UnitThreatSituation("player", unit))
        end
    end
    if status and status >= 1 then
        UF.SetBorderGlow(f.Border, ThreatColor(status))
    else
        UF.SetBorderGlow(f.Border)
    end
end

-- The ready check mark: during a check, and its result for a few seconds after (a member who never
-- answered counts as not ready, as on Blizzard's frames)
function ICON_UI.UpdateReady(f, event)
    local icon = f.ReadyIcon
    if not icon then return end
    if event == "READY_CHECK" then
        if f.readyHold then f.readyHold:Cancel(); f.readyHold = nil end
    elseif event == "READY_CHECK_FINISHED" then
        if f.readyHold then f.readyHold:Cancel() end
        f.readyHold = C_Timer.NewTimer(ICON_UI.READY_HOLD, function()
            f.readyHold, f.lastReady = nil, nil
            ICON_UI.UpdateReady(f)
        end)
    end
    if not ICON_UI.Shown(f.fuiUnit, "readyCheck") then icon:Hide() return end
    local status = Readable(GetReadyCheckStatus(f.fuiUnit))
    if not status and f.readyHold then status = f.lastReady end
    if f.readyHold and status == "waiting" then status = "notready" end
    local atlas = status and ICON_UI.READY[status]
    if atlas then
        if not f.readyHold then f.lastReady = status end
        icon:SetAtlas(atlas, false)
        icon:Show()
    elseif not ns.EditPreviewing() then
        icon:Hide()
    end
end

-- The quest mark: a quest boss, or a hostile unit tied to an active quest (the nameplate quest tags' test)
function ICON_UI.QuestShown(unit)
    if not ICON_UI.Shown(unit, "quest") then return false end
    local show = Readable(UnitIsQuestBoss(unit)) == true
    if not show and Readable(UnitCanAttack("player", unit)) then
        show = Readable(C_QuestLog.UnitIsRelatedToActiveQuest(unit)) == true
    end
    return show
end

function UpdateIndicators(f)
    local unit = f.fuiUnit
    local readable = Readable

    if f.RestIcon then
        local show = ICON_UI.Shown(unit, "rest") and IsResting()
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
        if not ICON_UI.Shown(unit, "leader") then
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
        if not ICON_UI.Shown(unit, "pvp") then
            f.PvPIcon:Hide()
        elseif ffa then
            SetIconArt(f.PvPIcon, "UI-HUD-UnitFrame-Player-PVP-FFAIcon", "Interface\\TargetingFrame\\UI-PVP-FFA")
            f.PvPIcon:Show()
        elseif pvp and faction == "Horde" then
            SetIconArt(f.PvPIcon, "UI-HUD-UnitFrame-SmallCircle-Horde", "Interface\\TargetingFrame\\UI-PVP-Horde")
            f.PvPIcon:Show()
        elseif pvp and faction == "Alliance" then
            SetIconArt(f.PvPIcon, "UI-HUD-UnitFrame-SmallCircle-Alliance", "Interface\\TargetingFrame\\UI-PVP-Alliance")
            f.PvPIcon:Show()
        else
            f.PvPIcon:Hide()
        end
    end
    if f.ClassIcon then
        -- the level disc's skull: as it is for rares, gold for elites and bosses
        local c = readable(UnitClassification(unit))
        local kind = (c == "elite" or c == "worldboss") and "elite" or (c == "rare" or c == "rareelite") and "rare" or nil
        if kind and ICON_UI.Shown(unit, "classification") and ICON_UI.ClassArt(f.ClassIcon, kind) then
            f.ClassIcon:Show()
        else
            f.ClassIcon:Hide()
        end
    end
    if f.QuestIcon then
        local show = ICON_UI.QuestShown(unit)
        f.questShown = show   -- QUEST_LOG_UPDATE compares against it
        if show then SetIconArt(f.QuestIcon, QUEST_ATLAS, QUEST_FILE) end
        f.QuestIcon:SetShown(show)
    end
    ICON_UI.UpdateReady(f)
    ICON_UI.Preview(f)
    ICON_UI.UpdatePvPTimer(f)
    if ns.UFRing and ns.UFRing.Applies(f) then
        -- Forever style: Blizzard's art; elites get the dragon frame instead of the small icon, and the
        -- quest mark sits where the rare star would
        if f.QuestIcon and f.QuestIcon:IsShown() then
            SetIconArt(f.QuestIcon, "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Quest", QUEST_FILE)
            if f.ClassIcon then f.ClassIcon:Hide() end
        elseif f.ClassIcon then
            local c = readable(UnitClassification(unit))
            if c == "rare" or c == "rareelite" then
                SetIconArt(f.ClassIcon, "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star", nil)
                f.ClassIcon:SetVertexColor(1, 1, 1)
                f.ClassIcon:Show()
            else
                f.ClassIcon:Hide()
            end
        end
        ns.UFRing.Update(f)
    end
end

-- The Elite & Rare icon: Blizzard's high-level skull, gold for an elite (false without the art)
ICON_UI.CLASS_SKULL = "UI-HUD-UnitFrame-Target-HighLevelTarget_Icon"
ICON_UI.ELITE_GOLD = { 1, 0.82, 0.25 }
function ICON_UI.ClassArt(tex, kind)
    if not HasAtlas(ICON_UI.CLASS_SKULL) then return false end
    tex:SetAtlas(ICON_UI.CLASS_SKULL, false)
    local gold = ICON_UI.ELITE_GOLD
    if kind == "elite" then tex:SetVertexColor(gold[1], gold[2], gold[3]) else tex:SetVertexColor(1, 1, 1) end
    return true
end

-- The PvP timer (Addon Style): Blizzard's countdown to the flag dropping, readable values only; a
-- sample in Edit Mode
function ICON_UI.PvPTick(timer, elapsed)
    timer.wait = (timer.wait or 0) + elapsed
    if timer.wait < 0.2 then return end
    timer.wait = 0
    local left = timer.pvpEnd and timer.pvpEnd - GetTime()
    if not left or left < 0 then
        timer.pvpEnd = nil
        timer.Text:Hide()
        timer:SetScript("OnUpdate", nil)
    else
        timer.Text:SetFormattedText(SecondsToTimeAbbrev(math_floor(left)))
    end
end

function ICON_UI.UpdatePvPTimer(f)
    local timer = f.PvPTimer
    if not timer then return end
    local on = ICON_UI.Shown(f.fuiUnit, "pvpTimer") and not (ns.UFRing and ns.UFRing.Applies(f))
    timer.pvpEnd = nil
    timer:SetScript("OnUpdate", nil)
    if on and Readable(IsPVPTimerRunning()) then
        local ms = Readable(GetPVPTimer())
        if ms then
            timer.pvpEnd = GetTime() + ms / 1000
            timer.wait = 1   -- the text at once
            timer:SetScript("OnUpdate", ICON_UI.PvPTick)
            timer.Text:Show()
            return
        end
    end
    if on and ns.EditPreviewing() then
        timer.Text:SetFormattedText(SecondsToTimeAbbrev(299))
        timer.Text:Show()
    else
        timer.Text:Hide()
    end
end

-- Edit Mode: every icon the frame shows appears with sample art
function ICON_UI.Preview(f)
    if not ns.EditPreviewing() then return end
    local ringOn = ns.UFRing and ns.UFRing.Applies(f)
    for _, key in ipairs(ICON_UI.List(f.fuiUnit)) do
        local def = ICON_UI.defs[key]
        if key ~= "happiness" and def.field and not def.ring and not (def.noRing and ringOn) and ICON_UI.Shown(f.fuiUnit, key) then
            ICON_UI.PreviewIcon(f, key)
        end
    end
end

function ICON_UI.PreviewIcon(f, key)
    local region = f[ICON_UI.defs[key].field]
    if not region then return end
    if key == "rest" then
        if region.anim and not region.anim:IsPlaying() then region.anim:Play() end
    elseif key == "leader" then
        SetIconArt(region, "UI-HUD-UnitFrame-Player-Group-LeaderIcon", "Interface\\GroupFrame\\UI-Group-LeaderIcon")
    elseif key == "pvp" then
        if UnitFactionGroup("player") == "Horde" then
            SetIconArt(region, "UI-HUD-UnitFrame-SmallCircle-Horde", "Interface\\TargetingFrame\\UI-PVP-Horde")
        else
            SetIconArt(region, "UI-HUD-UnitFrame-SmallCircle-Alliance", "Interface\\TargetingFrame\\UI-PVP-Alliance")
        end
    elseif key == "classification" then
        if not ICON_UI.ClassArt(region, "elite") then return end
    elseif key == "quest" then
        SetIconArt(region, QUEST_ATLAS, QUEST_FILE)
    elseif key == "raidIcon" then
        SetRaidTargetIconTexture(region, 8)
    elseif key == "readyCheck" then
        region:SetAtlas(ICON_UI.READY.ready, false)
    end
    region:Show()
end

--------------------------------------------------
-- 10. LAYOUT
--------------------------------------------------
-- "Mana on Shapeshift": a druid in a form without mana gets a mana bar at the frame's bottom, as tall
-- as the power bar (its Power Bar Height), with the power text's font; only with the power bar off
-- is it a thin strip with small text. In Forever Style it has the plate's second power slot, below the
-- frame (UnitFramesRing.lua PLATE.two). Edit Mode previews it.
UF.SHIFT_MANA_HEIGHT = 5
UF.SHIFT_MANA_TEXT_SIZE = 8
function UF.ShiftManaHeight(f)
    local udb = GetUnitDb(f.fuiUnit)
    local height = udb and udb.powerHeight or 8
    return height > 0 and height or UF.SHIFT_MANA_HEIGHT
end
function UF.ShiftManaShown(f)
    if not f.ShiftMana then return false end
    local udb = GetUnitDb(f.fuiUnit)
    if not (udb and udb.shiftMana) then return false end
    -- Forever Style: in the plate's second slot, if the client has its art
    if ns.UFRing and ns.UFRing.Plate(f) and not ns.UFRing.TwoSlots() then return false end
    if ns.EditPreviewing() then return true end
    local powerType = UnitPowerType("player")
    if not canaccessvalue(powerType) then return f.ShiftMana:IsShown() end
    return powerType ~= Enum.PowerType.Mana
end

-- Forever Style with Mana on Shapeshift: the second slot's numbers, in the power text's font, at most
-- as large as fits the slot. In combat too (shifting re-lays the bars).
UF.SHIFT_SLOT_TEXT = 12
function UF.PlateSlotText(f)
    local shown = UF.ShiftManaShown(f)
    local font = UF.Font(f.fuiUnit, "power")
    local size = font and font.size or 12
    for _, fs in pairs(UF.SlotTexts(f, "mana")) do
        ApplyFont(fs, font, math.min(0, UF.SHIFT_SLOT_TEXT - size))
        fs:SetShown(shown and true or false)
    end
end

-- The plate's second slot came or went: the cast bar and the auras under the frame make room (in a fight
-- too: none of them is protected)
function UF.PlateDropChanged(f)
    local drop = ns.UFRing and ns.UFRing.PlateDrop(f) or 0
    if f.plateDropUsed == drop then return end
    f.plateDropUsed = drop
    local cast, udb = f.Cast, GetUnitDb(f.fuiUnit)
    if cast and udb and udb.castbarPosition ~= "TOP" then
        for i = 1, cast:GetNumPoints() do
            local point, anchor, relative, x = cast:GetPoint(i)
            if anchor == f and relative and relative:find("^BOTTOM") then
                cast:SetPoint(point, anchor, relative, x, -CAST_GAP - drop)
            end
        end
    end
    PositionAuraContainers(f)
end

-- Anchors health / power and the divider on their seam; the combo strip lies over the health bar's
-- top edge. Unprotected children only, so it may run in combat (cat form gains the strip at once).
local function LayoutBars(f)
    local udb = GetUnitDb(f.fuiUnit)
    if not udb then return end
    -- the bars may get new textures: the next health and power ticks set their colours again
    f.colorClass, f.powerColorToken = nil, nil
    local PADDING = INSET
    local powerHeight = udb.powerHeight or 8
    local health, power = f.Health, f.Power
    local comboShown = IsComboShown(f)
    -- the portrait square on the left, or on the right of a mirrored frame
    local space, mirror = PortraitSpace(f), UF.LayoutMirrored(f)
    local left, right = PADDING + (mirror and 0 or space), PADDING + (mirror and space or 0)

    if f.Portrait and ns.UFRing and ns.UFRing.Plate(f) then
        -- Forever Style: the bars sit in the frame plate's slots, the ring beside it
        f.Separator:Hide()
        if f.Combo then f.Combo:Hide() end
        ns.UFRing.LayoutPlate(f)
        ns.UFRing.Layout(f)
        UpdatePortrait(f)
        if f.ShiftMana then
            UF.PlateSlotText(f)
            UF.PlateDropChanged(f)
        end
        return
    end

    health:ClearAllPoints()
    power:ClearAllPoints()
    health:SetPoint("TOPLEFT", f, "TOPLEFT", left, -PADDING)

    if f.Portrait and ns.UFRing and ns.UFRing.Applies(f) then
        ns.UFRing.Layout(f)
        UpdatePortrait(f)
    elseif f.Portrait then
        if ns.UFRing then ns.UFRing.Reset(f) end
        local portrait, divider = f.Portrait, f.PortraitDivider
        portrait:ClearAllPoints()
        divider:ClearAllPoints()
        if space > 0 then
            local size = space - PORTRAIT_GAP
            portrait:SetSize(size, size)
            local edge = mirror and "LEFT" or "RIGHT"
            if mirror then
                portrait:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, -PADDING)
            else
                portrait:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, -PADDING)
            end
            divider:SetPoint("TOP", portrait, "TOP" .. edge, 0, 0)
            divider:SetPoint("BOTTOM", portrait, "BOTTOM" .. edge, 0, 0)
            divider:SetWidth(SEPARATOR_HEIGHT)
            divider:Show()
        else
            divider:Hide()
        end
        UpdatePortrait(f)
    end

    if comboShown then
        local combo = f.Combo
        -- FlareUI Style, Combo Points Modern: the strip ends where the ring starts at its depth
        combo.clear = 0
        local ringSide
        if ns.UFRing and ns.UFRing.Applies(f) then
            combo.clear = ns.UFRing.Clearance(f, -(PADDING + COMBO.height))
            ringSide = ns.UFRing.Side(f)
        end
        combo:ClearAllPoints()
        combo:SetPoint("TOPLEFT", health, "TOPLEFT", ringSide == "LEFT" and combo.clear or 0, 0)
        combo:SetPoint("TOPRIGHT", health, "TOPRIGHT", ringSide == "RIGHT" and -combo.clear or 0, 0)
        combo:SetHeight(COMBO.height)
        combo:Show()
        LayoutComboSegments(f)
    elseif f.Combo then
        f.Combo:Hide()
    end
    local bottom = PADDING
    local shiftMana = f.ShiftMana
    if shiftMana then
        local separator = f.ShiftManaSeparator
        if UF.ShiftManaShown(f) then
            shiftMana:ClearAllPoints()
            shiftMana:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", left, PADDING)
            shiftMana:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -right, PADDING)
            shiftMana:SetHeight(UF.ShiftManaHeight(f))
            shiftMana:Show()
            separator:ClearAllPoints()
            separator:SetPoint("TOPLEFT", shiftMana, "TOPLEFT", 0, SEPARATOR_HEIGHT / 2)
            separator:SetPoint("TOPRIGHT", shiftMana, "TOPRIGHT", 0, SEPARATOR_HEIGHT / 2)
            separator:SetHeight(SEPARATOR_HEIGHT)
            separator:Show()
            bottom = PADDING + UF.ShiftManaHeight(f)
        else
            shiftMana:Hide()
            separator:Hide()
        end
    end
    if powerHeight > 0 then
        power:Show()
        power:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", left, bottom)
        power:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -right, bottom)
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
        health:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -right, bottom)
    end
end

-- Shows or hides the bar (re-laying the frame when that changes) and feeds its values
function UF.UpdateShiftMana(f)
    local bar = f.ShiftMana
    local shown = UF.ShiftManaShown(f)
    local appeared = shown ~= bar:IsShown()
    if appeared then
        LayoutBars(f)
        UpdateFsrSpark()   -- a running window moves onto the strip, or back to the power bar
    end
    if not shown then return end
    local mana = Enum.PowerType.Mana
    bar:SetMinMaxValues(0, UnitPowerMax("player", mana))
    local udb = GetUnitDb(f.fuiUnit)
    ns.SetBarValue(bar, UnitPower("player", mana), not appeared and udb and udb.smoothBars)
    local r, g, b = ns.PowerColor("MANA", mana)
    bar:SetStatusBarColor(r or ns.MANA_BLUE[1], g or ns.MANA_BLUE[2], b or ns.MANA_BLUE[3])
    -- Bar Text: the strip's own Druid Mana slots
    if udb and not UnitIsDeadOrGhost("player") then
        UF.FillSlots(f, "mana", UF.PowerSource("player", mana, UF.TextSlots(f, "mana")))
    else
        UF.FillSlots(f, "mana")
    end
end

-- Shows the strip with the right number of segments, feeds the values, and re-lays the bars when it
-- comes or goes
function UpdateComboPoints(f)
    local combo = f.Combo
    if not combo then return end
    local count = 0
    local udb = GetUnitDb(f.fuiUnit)
    -- the strip: FlareUI Style's Modern, else the Combo Points switch (Addon Style)
    local strip
    if ns.UFRing and ns.UFRing.Applies(f) then   -- (both ring styles: the mode; Forever has no strip)
        strip = IsFlareUIRing(f) and UF.RingComboMode(udb) == "modern"
    else
        strip = not (udb and udb.comboPoints == false)
    end
    if not UsesClassicCombo(f) and strip and ShouldShowComboPoints() then
        local max = UnitPowerMax("player", Enum.PowerType.ComboPoints)
        if not (canaccessvalue(max) and max and max >= 1) then max = COMBO.fallbackMax end
        count = math.min(max, COMBO.maxSegments)
    end
    if count ~= combo.count then
        combo.count = count
        LayoutBars(f)
    end
    if count > 0 then
        local value = ns.EditPreviewing() and COMBO.previewPoints or GetComboPoints("player", "target")
        for i = 1, count do GetComboSegment(f, i):SetValue(value) end
    end
    CLASSIC_COMBO.Preview(f)
end

local function LayoutFrame(f)
    local db, udb = GetDb(), GetUnitDb(f.fuiUnit)
    if not db or not udb then return end
    -- (a preview's sample is not secure: it can be laid out in a fight)
    if InCombatLockdown() and not f.fuiSample then pendingLayout = "LayoutFrame" return end

    local width, height = udb.width or 220, udb.height or 44
    local powerHeight = udb.powerHeight or 8
    local PADDING = INSET
    -- Forever Style: the frame plate is the background and the border, and has a least size
    local plate = ns.UFRing and ns.UFRing.Plate(f)
    if plate then
        -- no stored Scale: the default (ring and height)
        if udb.plateScale == nil then
            -- (a sample's setup takes it, never the profile)
            if f.fuiSample then ns.UFRing.ApplyPlateScale(udb, ns.UFRing.PlateDefaultScale(f.fuiUnit))
            else ns.UFRing.SetPlateScale(f.fuiUnit, ns.UFRing.PlateDefaultScale(f.fuiUnit)) end
            height = udb.height
        end
        local minW, minH = ns.UFRing.PlateMinSize(f)
        width, height = math.max(width, minW), math.max(height, minH)
    end
    f:SetSize(width, height)

    if plate then
        f:SetBackdrop(nil)
        f.Border:Hide()
    else
        -- (off Forever's plate every frame picks its own border, Forever Style too)
        local edgeFile = GetBorderFile(udb.border or DEFAULT_BORDER)
        f:SetBackdrop({ bgFile = BACKDROP_FILE, insets = { left = PADDING, right = PADDING, top = PADDING, bottom = PADDING } })
        f:SetBackdropColor(0, 0, 0, BG_OPACITY)
        -- the border's own frame sits above the bars
        ApplyBorderStyle(f.Border, edgeFile, height)
        f.Border:Show()
    end

    -- mirrored frames fill right to left, text order [health][name][level]
    local fillMirror = udb.mirror and true or false
    local mirror = UF.LayoutMirrored(f)
    local texture = GetBarTexture(udb.texture, fillMirror)
    local health, power = f.Health, f.Power
    health:SetStatusBarTexture(texture)
    power:SetStatusBarTexture(texture)
    health.bg:SetTexture(texture)
    power.bg:SetTexture(texture)
    health:SetReverseFill(fillMirror)
    power:SetReverseFill(fillMirror)
    if f.ShiftMana then
        f.ShiftMana:SetStatusBarTexture(texture)
        f.ShiftMana.bg:SetTexture(texture)
        f.ShiftMana:SetReverseFill(fillMirror)
    end
    -- Bar Edge Glow (before LayoutBars: the ring style's layout masks it)
    UF.BarLook(health, fillMirror, udb.barEdgeGlow)

    LayoutBars(f)
    -- the bars' empty part (Background Opacity; after LayoutBars, which hides it on the plate)
    local bgOpacity = udb.bgOpacity
    if bgOpacity == nil then bgOpacity = UF.DefaultBgOpacity(f.fuiUnit) end
    -- on the plate its art is the background
    if ns.UFRing and ns.UFRing.Plate(f) then bgOpacity = 0 end
    UF.SetBarBackground(health, bgOpacity)
    UF.SetBarBackground(power, bgOpacity)
    if f.ShiftMana then UF.SetBarBackground(f.ShiftMana, bgOpacity) end
    -- the trail follows the health bar's texture and fill (set by now, on the plate too)
    UF.PlaceDamageTrail(f.DamageTrail, fillMirror)

    -- ring styles: the level one point smaller (its disc)
    local fontDelta = (ns.UFRing and ns.UFRing.Applies(f)) and -1 or 0
    -- target of target and target of focus: their set size in every style
    if UNITS[f.fuiUnit].poll then fontDelta = 0 end
    local key = f.fuiUnit
    -- the name and the bar texts at their set size in every style; the level keeps the ring's smaller
    -- disc size
    local levelDelta = fontDelta
    fontDelta = 0
    ApplyFont(f.Name, UF.Font(key, "names"), fontDelta)
    ApplyFont(f.Level, UF.LevelFont(key), levelDelta)
    -- (every slot of each bar: Bar Text)
    for _, fs in pairs(UF.SlotTexts(f, "health")) do ApplyFont(fs, UF.Font(key, "health"), fontDelta) end
    for _, fs in pairs(UF.SlotTexts(f, "power")) do ApplyFont(fs, UF.Font(key, "power"), fontDelta) end
    if f.ShiftManaText then
        -- the power text's font and size; a small one on the thin strip (power bar off)
        local font = UF.Font(key, "power")
        local delta = UF.ShiftManaHeight(f) > UF.SHIFT_MANA_HEIGHT and fontDelta or (UF.SHIFT_MANA_TEXT_SIZE - (font and font.size or 12))
        for _, fs in pairs(UF.SlotTexts(f, "mana")) do ApplyFont(fs, font, delta) end
    end

    f.Level:ClearAllPoints()
    f.Name:ClearAllPoints()
    f.threatLaid = nil   -- Show Threat's text is placed again against the new anchors
    -- ring styles: the level is in the ring's disc
    local ringOn = ns.UFRing and ns.UFRing.Applies(f)
    local levelInRow = udb.showLevel and not ringOn
    -- the name side's end starts past the portrait
    local namePad = ringOn and ns.UFRing.TextPad(f) or 0
    -- Forever Style: the name centred in the plate's name box
    local nameBox = ringOn and ns.UFRing.NameBox(f)
    -- Bar Text: each bar's Left / Middle / Right slots (BarText.lua), read again for
    -- this layout; off the plate the health bar's slots place the name (and the level before it) too
    f.btStyle, f.btSlots = nameBox and "plate" or "plain", nil
    local onPlate = nameBox and true or false
    UF.PlaceSlots(f, "health", health, mirror, onPlate, namePad, levelInRow)
    UF.PlaceSlots(f, "power", power, mirror, onPlate, namePad, false)
    if f.ShiftManaText then UF.PlaceSlots(f, "mana", f.ShiftMana, mirror, onPlate, 0, false) end
    if nameBox then
        -- Show Name: off hides it
        f.Name:SetShown(udb.showName ~= false)
        f.Name:SetPoint("LEFT", nameBox, "LEFT", TEXT_INSET, 0)
        f.Name:SetPoint("RIGHT", nameBox, "RIGHT", -TEXT_INSET, 0)
        f.Name:SetJustifyH("CENTER")
    end
    -- (on the plate: by its own Power Height, which may be Off)
    local roomForText
    if nameBox then roomForText = ns.UFRing.PlatePowerText(f) else roomForText = powerHeight >= 10 end
    for _, fs in pairs(UF.SlotTexts(f, "power")) do fs:SetShown(roomForText and true or false) end
    if nameBox and f.ShiftMana then UF.PlateSlotText(f) end
    if ringOn then
        ns.UFRing.LayoutLevel(f)
        -- the classic gems follow the ring's size and side
        if f.Combo then ApplyComboMode(f) end
    end

    -- the raid marker and the happiness face sit mid health bar, sized off its height
    local healthHeight = height - 2 * PADDING - (powerHeight > 0 and powerHeight or 0)
    local markerSize = math.max(8, healthHeight * RAID_ICON_SHARE)
    local rp, rrel, rrelPoint, rx, ry, rw, rh
    if ringOn then rp, rrel, rrelPoint, rx, ry, rw, rh = ns.UFRing.IconSpot(f, "raidIcon") end
    if rp then
        ICON_UI.Place(f.RaidIcon, rw, rh, rp, rrel, rrelPoint, rx, ry)
    else
        ICON_UI.Place(f.RaidIcon, markerSize - 2, markerSize - 2, "CENTER", f, "TOP", 0, -2)
    end

    if f.Happiness then
        local size = math.max(RAID_ICON, healthHeight * HAPPINESS_SHARE) - 4
        if UNITS[f.fuiUnit].styledPet and ns.UFRing.PlateOn() then size = ICON_UI.HAPPINESS_PLATE_SIZE end
        -- Happiness Position: mid health bar, or just outside the frame on either side
        local place = ICON_UI.HappinessPlace(f.fuiUnit)
        if place == "RIGHT" then
            ICON_UI.Place(f.Happiness, size, size, "LEFT", f, "RIGHT", ICON_UI.HAPPINESS_GAP, 0)
        elseif place == "LEFT" then
            ICON_UI.Place(f.Happiness, size, size, "RIGHT", f, "LEFT", -ICON_UI.HAPPINESS_GAP, 0)
        else
            ICON_UI.Place(f.Happiness, size, size, "CENTER", f.Health, "CENTER", 0, 0)
        end
    end

    -- a settings preview's sample stops here: no cast bar, auras or icons
    if f.fuiSample then return end

    -- Name Above Frames (BarText.lua): not on Forever Style's plate, which has its name box
    ns.NameAbove.Layout(f, not (ns.UFRing and ns.UFRing.Plate(f)) and udb or nil, f, f.Name)
    if f.NameAboveText and f.NameAboveText:IsShown() then
        if f.fuiSample or not UnitExists(f.fuiUnit) then
            local s = UNITS[f.fuiUnit].sample or {}
            ns.NameAbove.SetSample(f, udb, s.name or UNITS[f.fuiUnit].label, s.surname)
        else
            ns.NameAbove.SetName(f, udb, f.fuiUnit)
        end
    end

    -- cast bar hangs off the frame
    if f.Cast then
        local leftExtra, rightExtra
        if ringOn then
            -- ends where the ring starts at the cast bar's height
            local clear = ns.UFRing.Clearance(f, CAST_GAP)
            if ns.UFRing.Side(f) == "LEFT" then leftExtra = clear else rightExtra = clear end
        end
        local castStyle = GetCastStyle(udb, false, ns.UFRing and ns.UFRing.Plate(f))
        castStyle.fontKey = f.fuiUnit
        LayoutCastBar(f.Cast, castStyle, f, udb.castbarPosition == "TOP" and "TOP" or "BOTTOM", leftExtra, rightExtra)
        -- the auras on its side move out while it shows (in a fight too: they are not protected)
        f.Cast.onShownChanged = function() PositionAuraContainers(f) end
    end

    LayoutAuras(f)
    UF.LayoutDispelHighlight(f)
    -- Values on Mouseover: every slot's text of every bar
    do
        local list = {}
        for bar in pairs(UF.SLOT_KEYS) do
            local t = UF.SlotTexts(f, bar)
            if t then list[#list + 1], list[#list + 2], list[#list + 3] = t.left, t.middle, t.right end
        end
        UF.ValuesOnHover(f, udb.valuesOnHover, list)
    end
    LayoutIndicators(f)
    -- Smooth Animated Bars, when installed and on (ns.SAB)
    ns.SAB.UnitFrame(f)
end

--------------------------------------------------
-- 11. BLIZZARD EXTRAS THAT FOLLOW OUR FRAMES
-- PlayerBottomManagedFrameContainer (anchored to PlayerFrame) goes under the player frame.
--------------------------------------------------
local function AttachExtras(f)
    if InCombatLockdown() then pendingLayout = "AttachExtras" return end
    if f.fuiUnit == "player" then
        local container = _G.PlayerBottomManagedFrameContainer
        if container then
            container:ClearAllPoints()
            -- (room for the plate's second power slot kept while its option is on: this one can't move in a fight)
            container:SetPoint("TOP", f, "BOTTOM", 0, -2 - (ns.UFRing and ns.UFRing.PlateReserve(f) or 0))
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
-- Each point anchors to the same point on UIParent
local DEFAULT_POSITIONS = {
    player        = { point = "CENTER", x = -305, y = -270 },
    target        = { point = "CENTER", x = 305,  y = -270 },
    targettarget  = { point = "BOTTOM", x = 235,  y = 252 },
    focus         = { point = "RIGHT",  x = -478, y = -257 },
    focustarget   = { point = "BOTTOM", x = 479,  y = 277 },
    pet           = { point = "BOTTOM", x = -245, y = 271 },   -- its right edge lines up with the player frame's
    playercastbar = { point = "CENTER", x = 0,    y = -221 },  -- mid-screen above the action bars
}

local function GetLayoutStore(layoutName)
    local db = GetDb()
    if not db then return nil end
    layoutName = layoutName or LEM:GetActiveLayoutName() or "Modern"
    db.layouts = db.layouts or {}
    -- (a layout with no spot of its own reads the profile's home layout's: ProfileLayout.lua)
    return ns.LayoutHome(db.layouts, layoutName)
end

local function ApplyPosition(f, layoutName)
    if InCombatLockdown() then pendingLayout = "ApplyPosition" return end
    local store = GetLayoutStore(layoutName)
    local pos = store and store[f.fuiUnit] or DEFAULT_POSITIONS[f.fuiUnit]
    -- An old save: a frame moved in Edit Mode while its fade holder had no size was saved as TOPRIGHT
    -- with its right and top edges counted from the screen's bottom left (the frame then snapped to the
    -- top right corner). Turned back into the spot it was dropped on.
    if store and store[f.fuiUnit] == pos and pos.point == "TOPRIGHT" and (pos.x or 0) > 50 and (pos.y or 0) > 50 then
        local scale = f:GetScale() or 1
        pos.x = math_floor(pos.x - UIParent:GetWidth() / scale + 0.5)
        pos.y = math_floor(pos.y - UIParent:GetHeight() / scale + 0.5)
    end
    f:ClearAllPoints()
    f:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or 0, pos.y or 0)
end

local function OnFrameMoved(f, layoutName, point, x, y)
    local store = GetLayoutStore(layoutName)
    if not store then return end
    store[f.fuiUnit] = { point = point, x = math_floor(x + 0.5), y = math_floor(y + 0.5) }
end

--------------------------------------------------
-- 13. VISIBILITY (state drivers; in Edit Mode every frame shows)
--------------------------------------------------
local function ApplyVisibility(f)
    if InCombatLockdown() then pendingLayout = "ApplyVisibility" return end
    local info = UNITS[f.fuiUnit]
    local party = GetDb() and GetDb().party
    -- the party frames must be on and showing the player, or there'd be no frame of yours left
    local hideInParty = info.partyDriver and party and party.enabled and party.showPlayer and party.hidePlayerInParty
    -- and in a raid: the raid frames must be on (they always show you)
    local raid = GetDb() and GetDb().raid
    local hideInRaid = info.raidDriver and raid and raid.enabled and raid.hidePlayerInRaid
    local driver = info.driver
    if hideInParty and hideInRaid then driver = info.groupDriver
    elseif hideInRaid then driver = info.raidDriver
    elseif hideInParty then driver = info.partyDriver end
    if ns.EditPreviewing() then
        UnregisterStateDriver(f, "visibility")
        f:Show()
    elseif driver then
        RegisterStateDriver(f, "visibility", driver)
    else
        UnregisterStateDriver(f, "visibility")
        f:Show()
    end
end

--------------------------------------------------
-- 14. FADING (Visibility.lua)
-- Each frame sits on a plain holder that Visibility fades, by the Show choice and Faded Opacity in its
-- Edit Mode dialog (the action bars' rows). The player and pet frames can join a fade group: they
-- then fade at the group's Fade In / Fade Out Speed, and pointing at any member brings the group back.
-- The frame's own alpha stays the range fading's (14b, set from secret values): the two multiply,
-- and neither reads the other.
--------------------------------------------------
UF.fadeHolders = {}   -- unit -> holder

function UF:GetFadeFrame(unit) return UF.fadeHolders[unit] end
-- the unit's clickable frame (Visibility's Never takes its clicks away)
function UF:GetUnitButton(unit) return frames[unit] end

-- the pointer on the frame, or on a ring style's portrait outside it
function UF:IsMouseOverUnit(unit)
    local f = frames[unit]
    if not (f and f:IsVisible()) then return false end
    return f:IsMouseOver() or (ns.UFRing and ns.UFRing.MouseOverHit(f)) or false
end

-- The old Fade Player and Pet setting (combat, target, missing health and the mouse showed both
-- frames) becomes the same on each of the two frames. Its Off (the default, no fading) stays Always.
function UF.MigrateOldFade()
    local db, profile = GetDb(), ns.db and ns.db.profile
    local old = db and rawget(db, "visibility")
    if type(old) ~= "table" then return end
    local v = old.player
    local vis = profile and profile.visibility
    if type(v) == "table" and (v.condCombat or v.condMouseover or v.condTarget or v.condHealth) and vis and vis.elements then
        for _, key in ipairs({ "uf_player", "uf_pet" }) do
            vis.elements[key] = vis.elements[key] or { show = "combat,hastarget,health", group = 0, minAlpha = v.minAlpha or 0, fadeSpeed = "instant" }
        end
    end
    db.visibility = nil
end

--------------------------------------------------
-- 14b. OUT OF RANGE FADING (target, focus, and the boss tiles through UF.Kit)
-- Group members answer UnitInRange (as the party tiles); anyone else is measured with the
-- player's own spells: a harmful one for enemies, a helpful one for friends. Any spell in range
-- counts as in range, so a hunter inside Auto Shot's minimum range stays bright.
--------------------------------------------------
UF.RANGE_ALPHA = 0.45
UF.RANGE_SPELLS = {   -- rank-1 spell IDs; only the ones the player knows are used
    WARRIOR = { harm = { 78, 100 } },                                -- Heroic Strike, Charge
    ROGUE   = { harm = { 1752, 2764 } },                             -- Sinister Strike, Throw
    HUNTER  = { harm = { 75, 2973 } },                               -- Auto Shot, Raptor Strike
    PALADIN = { harm = { 20271, 853 }, help = { 635 } },             -- Judgement, Hammer of Justice; Holy Light
    PRIEST  = { harm = { 585, 589 }, help = { 2050, 1243 } },        -- Smite, Shadow Word: Pain; Lesser Heal, Fortitude
    SHAMAN  = { harm = { 403, 8042 }, help = { 331 } },              -- Lightning Bolt, Earth Shock; Healing Wave
    MAGE    = { harm = { 133, 116, 2136 }, help = { 1459 } },        -- Fireball, Frostbolt, Fire Blast; Arcane Intellect
    WARLOCK = { harm = { 686, 348, 172 }, help = { 5697 } },         -- Shadow Bolt, Immolate, Corruption; Unending Breath
    DRUID   = { harm = { 5176, 8921 }, help = { 5185, 774, 1126 },   -- Wrath, Moonfire; Healing Touch, Rejuvenation, Mark of the Wild
                melee = { 1082, 6807 } },                            -- Claw, Maul: enemies in Cat and Bear Form
}
-- form IDs (not stance bar slots, which follow the order the forms were learned)
UF.MELEE_FORMS = { [1] = true, [5] = true, [8] = true }   -- Cat, Bear, Dire Bear

-- The player's spells by name, each at the best rank in the book. A rank-1 ID stops counting as
-- known once a higher rank is learned: a rogue then kept only Throw, and faded up close (5.0).
local BookByName
do
local function RankOf(spellID)
    local subtext = C_Spell.GetSpellSubtext(spellID)
    return type(subtext) == "string" and tonumber(subtext:match("(%d+)")) or 0
end
function BookByName()
    local best, rankOf = {}, {}
    local bank = Enum.SpellBookSpellBank.Player
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(line)
        local count = (lineInfo and not lineInfo.offSpecID) and lineInfo.numSpellBookItems or 0
        for offset = 1, count do
            local item = C_SpellBook.GetSpellBookItemInfo(lineInfo.itemIndexOffset + offset, bank)
            local id = item and item.spellID
            local name = id and ns.IsPlayerSpell(id) and C_Spell.GetSpellName(id)
            if name then
                local rank = RankOf(id)
                if not rankOf[name] or rank > rankOf[name] then best[name], rankOf[name] = id, rank end
            end
        end
    end
    return best
end
end

-- the known spells of one list (best rank), rebuilt when the spellbook changes (UF.rangeKnown = nil)
function UF.RangeKnown(kind)
    if not UF.rangeKnown then
        UF.rangeKnown = { harm = {}, help = {}, melee = {} }
        local _, class = UnitClass("player")
        local lists = UF.RANGE_SPELLS[class] or {}
        local book = BookByName()
        for k in pairs(UF.rangeKnown) do
            for _, id in ipairs(lists[k] or {}) do
                local name = C_Spell.GetSpellName(id)
                local known = name and book[name]
                if not known and C_SpellBook.IsSpellKnown(id, Enum.SpellBookSpellBank.Player) then known = id end
                if known then table.insert(UF.rangeKnown[k], known) end
            end
        end
    end
    return UF.rangeKnown[kind]
end

-- Sets f's alpha from unit's range: full in Edit Mode, for the player, for a range nobody can check,
-- and with the frame's Range Check off (rangeCheck, on by default)
function UF.ApplyRangeAlpha(f, unit)
    if not f then return end
    local u = GetUnitDb(unit)
    -- (UF.RANGE_OFF_FIRST: the pet's and target-of frames' Range Check starts off)
    local off = (u and u.rangeCheck == false) or (UF.RANGE_OFF_FIRST[unit] and not (u and u.rangeCheck))
    if ns.EditPreviewing() or off or not UnitExists(unit)
            or canaccessvalue(UnitIsUnit(unit, "player")) and UnitIsUnit(unit, "player") then
        f:SetAlpha(1)
        return
    end
    -- (the pet reads the group range too: UnitInRange covers it)
    local inGroup = unit == "pet" or UnitInParty(unit)
    if not (canaccessvalue(inGroup) and inGroup) then inGroup = UnitInRaid(unit) end
    if canaccessvalue(inGroup) and inGroup then
        local inRange, checked = UnitInRange(unit)
        if not (canaccessvalue(checked) and checked == false) and f.SetAlphaFromBoolean
            and pcall(f.SetAlphaFromBoolean, f, inRange, 1, UF.RANGE_ALPHA) then
            return
        end
        f:SetAlpha(1)
        return
    end
    local canAttack = UnitCanAttack("player", unit)
    if not canaccessvalue(canAttack) then f:SetAlpha(1) return end
    local out, hasSecret, secret = false, false, nil
    local list = UF.RangeKnown(canAttack and "harm" or "help")
    -- a cat or bear fights in melee: its casting spells would keep it bright at 30 yards
    if canAttack and UF.MELEE_FORMS[GetShapeshiftFormID and GetShapeshiftFormID() or 0] and #UF.RangeKnown("melee") > 0 then
        list = UF.RangeKnown("melee")
    end
    for _, id in ipairs(list) do
        local r = C_Spell.IsSpellInRange(id, unit)
        if not canaccessvalue(r) then
            if not hasSecret then hasSecret, secret = true, r end
        elseif r == true then
            f:SetAlpha(1)
            return
        elseif r == false then
            out = true
        end
    end
    if hasSecret and f.SetAlphaFromBoolean and pcall(f.SetAlphaFromBoolean, f, secret, 1, UF.RANGE_ALPHA) then return end
    f:SetAlpha(out and UF.RANGE_ALPHA or 1)
end

-- /fui range: what the fading reads for the target (developer probe, English only). Prints the
-- class and form, each listed spell (known, in range, minimum range) and the alpha it ends on.
function UF.RangeReport()
    local unit = "target"
    if not UnitExists(unit) then print("|cffffd100FlareUI range:|r no target") return end
    local _, class = UnitClass("player")
    local form = GetShapeshiftFormID and GetShapeshiftFormID() or 0
    local canAttack = UnitCanAttack("player", unit)
    local function Show(v)
        if not canaccessvalue(v) then return "secret" end
        return tostring(v)
    end
    print(("|cffffd100FlareUI range:|r %s, level %s, form %s, can attack %s, in combat %s, group %s"):format(
        tostring(class), Show(UnitLevel("player")), tostring(form), Show(canAttack),
        tostring(InCombatLockdown()), Show(UnitInParty(unit) or UnitInRaid(unit))))
    UF.rangeKnown = nil
    for kind in pairs(UF.RANGE_SPELLS[class] or {}) do
        local used = {}
        for _, id in ipairs(UF.RangeKnown(kind)) do
            used[#used + 1] = id .. " " .. tostring(C_Spell.GetSpellName(id)) .. " " .. tostring(C_Spell.GetSpellSubtext(id))
        end
        print(("  %s uses: %s"):format(kind, #used > 0 and table.concat(used, ", ") or "nothing"))
    end
    for kind, ids in pairs(UF.RANGE_SPELLS[class] or {}) do
        for _, id in ipairs(ids) do
            local info = C_Spell.GetSpellInfo(id)
            local known = C_SpellBook.IsSpellKnown(id, Enum.SpellBookSpellBank.Player)
            local byName = info and info.name and C_Spell.IsSpellInRange(info.name, unit)
            print(("  %s %d %s: known %s, in range %s (by name %s), range %s-%s"):format(kind, id,
                info and info.name or "?", tostring(known), Show(C_Spell.IsSpellInRange(id, unit)), Show(byName),
                tostring(info and info.minRange), tostring(info and info.maxRange)))
        end
    end
    local f = frames[unit]
    if f then
        UF.ApplyRangeAlpha(f, unit)
        local alpha = f:GetAlpha()
        print("  frame alpha " .. (canaccessvalue(alpha) and ("%.2f"):format(alpha) or "secret"))
    end
end

-- target, focus, pet and the target-of frames re-check five times a second while shown (range has no event for them)
UF.RANGE_UNITS = { "target", "focus", "pet", "targettarget", "focustarget" }
-- the ones whose Range Check starts off (the pet since 11-20; Target of Target and Target of Focus
-- since 11-22, Kelvan): on only once switched on
UF.RANGE_OFF_FIRST = { pet = true, targettarget = true, focustarget = true }
function UF.UpdateFrameRanges()
    for _, unit in ipairs(UF.RANGE_UNITS) do
        local f = frames[unit]
        if f and f:IsShown() then UF.ApplyRangeAlpha(f, unit) end
    end
end

--------------------------------------------------
-- 15. FRAME CREATION
--------------------------------------------------
local function OnEnter(f)
    f.Highlight:Show()
    if GameTooltip:IsForbidden() then return end
    GameTooltip_SetDefaultAnchor(GameTooltip, f)
    GameTooltip:SetUnit(f.fuiUnit)
    GameTooltip:Show()
end

local function OnLeave(f)
    f.Highlight:Hide()
    if not GameTooltip:IsForbidden() then GameTooltip:Hide() end
end

-- The frame's bars, border, texts and their layers (the real frames' and the previews' samples)
local function BuildBody(f)
    local level = f:GetFrameLevel()
    f.Health = CreateBar(f, level + 1)
    f.Power = CreateBar(f, level + 1)

    -- levels: bars +1, heal / absorb overlay +2, combo strip +3, border +4, text +5
    f.Border = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.Border:SetAllPoints()
    f.Border:SetFrameLevel(level + 4)

    local overlay = CreateFrame("Frame", nil, f)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(level + 5)
    f.Overlay = overlay
    f.Name = UF.NewText(overlay)
    f.Name:SetJustifyH("LEFT")
    f.Name:SetWordWrap(false)
    f.Level = UF.NewText(overlay)
    f.Level:SetJustifyH("LEFT")
    f.HealthText = UF.NewText(overlay)
    f.HealthText:SetJustifyH("RIGHT")
    f.PowerText = UF.NewText(overlay)
    f.PowerText:SetJustifyH("RIGHT")
    -- Bar Text: the Left and Middle slots (HealthText / PowerText are the Right ones)
    f.HealthTextLeft = UF.NewText(overlay)
    f.HealthTextMid = UF.NewText(overlay)
    f.PowerTextLeft = UF.NewText(overlay)
    f.PowerTextMid = UF.NewText(overlay)

    f.RaidIcon = overlay:CreateTexture(nil, "OVERLAY", nil, 4)   -- above the quest "!" it shares a spot with
    f.RaidIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    f.RaidIcon:Hide()

    f.Separator = overlay:CreateTexture(nil, "ARTWORK")
    f.Separator:SetTexture(SEPARATOR_TEXTURE)
    f.Separator:SetVertexColor(1, 1, 1, 1)
    f.Separator:Hide()
end

-- the portrait square and its divider
local function BuildPortrait(f)
    local level = f:GetFrameLevel()
    -- at the bars' level, under the border; the divider is the separator art turned upright
    f.Portrait = CreateFrame("Frame", nil, f)
    f.Portrait:SetFrameLevel(level + 1)
    f.Portrait.Tex = f.Portrait:CreateTexture(nil, "ARTWORK")
    f.Portrait.Tex:SetAllPoints()
    f.Portrait:Hide()
    f.PortraitDivider = f.Overlay:CreateTexture(nil, "ARTWORK")
    f.PortraitDivider:SetTexture(SEPARATOR_TEXTURE)
    f.PortraitDivider:SetTexCoord(0, 0, 1, 0, 0, 1, 1, 1)
    f.PortraitDivider:SetVertexColor(1, 1, 1, 1)
    f.PortraitDivider:Hide()
end

local function CreateUnitFrame(unit)
    local info = UNITS[unit]
    -- on its own fade holder (section 14), which stays on UIParent's scale
    local holder = CreateFrame("Frame", nil, UIParent)
    -- the whole screen: Edit Mode measures a moved frame against its parent (it catches no mouse)
    holder:SetAllPoints(UIParent)
    UF.fadeHolders[unit] = holder
    local f = CreateFrame("Button", "FlareUI_UF_" .. info.key, holder, "SecureUnitButtonTemplate,PingableUnitFrameTemplate,BackdropTemplate")
    f.fuiUnit = unit
    f:SetFrameStrata("LOW")
    f:SetAttribute("unit", unit)
    f:SetAttribute("*type1", "target")
    f:SetAttribute("*type2", "togglemenu")
    f:RegisterForClicks("AnyUp")
    if type(f.SetRolesets) == "function" then pcall(f.SetRolesets, f, "unitFrames") end
    f:SetClampedToScreen(true)
    f.editModeName = "FlareUI " .. info.label
    -- stack order: the frames higher in the list draw above the ones after them, so two frames
    -- that touch never mix their borders
    f:SetFrameLevel(10 + (10 - (info.order or 9)) * 20)

    BuildBody(f)
    local level, overlay = f:GetFrameLevel(), f.Overlay

    if unit == "player" and PlayerClass() == "DRUID" then
        f.ShiftMana = CreateBar(f, level + 1)
        f.ShiftMana:Hide()
        f.ShiftManaSeparator = overlay:CreateTexture(nil, "ARTWORK")
        f.ShiftManaSeparator:SetTexture(SEPARATOR_TEXTURE)
        f.ShiftManaSeparator:SetVertexColor(1, 1, 1, 1)
        f.ShiftManaSeparator:Hide()
        -- its number (Power Text) on a layer above the strip, so it comes and goes with it
        local textLayer = CreateFrame("Frame", nil, f.ShiftMana)
        textLayer:SetAllPoints()
        textLayer:SetFrameLevel(level + 5)
        f.ShiftManaText = UF.NewText(textLayer)
        f.ShiftManaTextLeft = UF.NewText(textLayer)
        f.ShiftManaTextMid = UF.NewText(textLayer)
    end

    if info.portrait then
        BuildPortrait(f)
        pcall(f.RegisterUnitEvent, f, "UNIT_PORTRAIT_UPDATE", unit)
        pcall(f.RegisterUnitEvent, f, "UNIT_MODEL_CHANGED", unit)
    end

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
    -- Damage Trail (always on: made for every frame but the polled ones); in the heal
    -- clip when there is one, under the heals
    if not info.poll then f.DamageTrail = UF.CreateDamageTrail(f.Health, f.HealClip) end
    if unit == "player" then CreateFsrSpark(f) end
    if info.happiness then CreateHappiness(f) end
    PrecreateAuraContainers(f)

    f:SetScript("OnEnter", OnEnter)
    f:SetScript("OnLeave", OnLeave)
    -- after the scripts: a click-cast addon wraps OnEnter / OnLeave as it registers the frame, so a
    -- later SetScript would replace its wrappers
    _G.ClickCastFrames = _G.ClickCastFrames or {}
    _G.ClickCastFrames[f] = true
    f:SetScript("OnEvent", OnUnitEvent)
    for _, event in ipairs(UNIT_EVENTS) do
        pcall(f.RegisterUnitEvent, f, event, unit)
    end
    if info.events then
        for _, event in ipairs(info.events) do pcall(f.RegisterUnitEvent, f, event, unit) end
    end
    if f.Combo then
        -- re-registered for the target and the player
        for event in pairs(COMBO_EVENTS) do pcall(f.RegisterUnitEvent, f, event, unit, "player") end
    end
    -- the level's colour and skull depend on the player's level too
    if unit == "target" or unit == "focus" then pcall(f.RegisterUnitEvent, f, "UNIT_LEVEL", unit, "player") end
    -- flagging yourself for PvP can make the unit attackable: Only My Debuffs follows
    if info.auras and unit ~= "player" then pcall(f.RegisterUnitEvent, f, "UNIT_FACTION", unit, "player") end
    if info.castbar then
        for _, event in ipairs(CAST_EVENTS) do pcall(f.RegisterUnitEvent, f, event, unit) end
    end
    pcall(f.RegisterEvent, f, "RAID_TARGET_UPDATE")
    if info.indicators then
        if info.indicators.heals then
            pcall(f.RegisterUnitEvent, f, "UNIT_HEAL_PREDICTION", unit)
            pcall(f.RegisterUnitEvent, f, "UNIT_ABSORB_AMOUNT_CHANGED", unit)
        end
        if info.indicators.readyCheck then
            for _, event in ipairs({ "READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED" }) do
                pcall(f.RegisterEvent, f, event)
            end
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

    -- hidden frames skip these two in their events (the player's, by Hide Player Frame in a party)
    f:HookScript("OnShow", function(self)
        UpdateIndicators(self)
        if ns.UFRing then ns.UFRing.UpdateThreat(self) end
    end)

    -- the client sends no unit events for targettarget / focustarget: Blizzard polls them too
    if info.poll then
        local elapsed = 0
        f:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            if elapsed < 0.2 then return end
            elapsed = 0
            if not UnitExists(self.fuiUnit) then return end
            UpdateHealth(self)
            UpdatePower(self)
            -- no event says this unit changed (the target's target can switch unseen), so the GUID
            -- does when it can be read: name and level on every frame, portrait and ring where shown
            local guid = UnitGUID(self.fuiUnit)
            local readable = canaccessvalue(guid)
            local same = readable and guid == self.polledGuid
            self.polledGuid = readable and guid or nil
            -- unreadable: at most once a second
            local now = GetTime()
            if not same and (readable or now - (self.polledAt or 0) >= 1) then
                self.polledAt = now
                UpdateName(self)
                UpdateLevel(self)
                if self.Portrait then
                    UpdatePortrait(self)
                    if ns.UFRing then ns.UFRing.Update(self) end
                end
            end
        end)
    end

    frames[unit] = f
    return f
end

--------------------------------------------------
-- 15b. SAMPLES FOR THE SETTINGS PREVIEWS
-- A plain frame (no unit, no clicks, no events) built and laid out by the real frames' own code, so
-- a preview shows exactly what the frame looks like. ns.UFSample holds the style and the setup
-- while it is laid out; nothing is written to the profile.
--------------------------------------------------
function UF.CreateSample(parent, unit)
    local info = UNITS[unit]
    if not info then return nil end
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f.fuiUnit, f.fuiSample = unit, true
    f:EnableMouse(false)
    BuildBody(f)
    if info.portrait then BuildPortrait(f) end
    return f
end

-- Lays the sample out in a style ("flareui", "forever", "addon"); returns its extent past the
-- frame (the ring stands out): { width, height, left, top }, or nil when it cannot be drawn.
-- opts.noClassColor: the palette's health colour instead of the class's (the palette's preview)
function UF.DrawSample(f, style, opts)
    local unit = f.fuiUnit
    local setup = ns.UFRing and ns.UFRing.SampleUnitDb(style, unit, opts and opts.preset)
    if not setup then
        local live = GetUnitDb(unit)
        setup = live and setmetatable({}, { __index = live })
    end
    if not setup then return nil end
    if opts and opts.noClassColor then setup.classColor = false end
    ns.UFSample = { style = style, units = { [unit] = setup } }
    local ok, result = pcall(function()
        LayoutFrame(f)
        ApplySample(f)
        if unit == "player" then f.Name:SetText(ns.UnitDisplayName("player", nil, UF.ShowsFullName(f)) or "") end
        UpdatePortrait(f)
        local w, h = f:GetSize()
        local left, right, top = 0, 0, 0
        if ns.UFRing and ns.UFRing.Applies(f) and f.RingFrame then
            local over = ns.UFRing.Overhang(f)
            if ns.UFRing.Side(f) == "LEFT" then left = over else right = over end
            top = math.max(0, (f.RingFrame:GetHeight() - h) / 2) + 4
        end
        return { width = w + left + right, height = h + 2 * top, left = left, top = top }
    end)
    ns.UFSample = nil
    if not ok then
        if geterrorhandler then geterrorhandler()(result) end
        return nil
    end
    return result
end

-- The FlareUI Player Cast Bar's sample: its own bar and layout, casting the Edit Mode sample on a loop
-- while it shows. unit "target" (Pick Your Colours): the target frame's cast bar instead, in
-- its own look, as long as the frame
function UF.CreateCastSample(parent, unit)
    local holder = CreateFrame("Frame", nil, parent)
    holder.unit = unit or "player"
    holder.Cast = CreateCastBar(holder, holder.unit, true)
    holder.Cast.standalone = holder.unit == "player"
    holder:SetScript("OnHide", function(self)
        if self.ticker then self.ticker:Cancel(); self.ticker = nil end
    end)
    return holder
end

function UF.DrawCastSample(holder)
    local db = GetDb()
    local style
    if holder.unit and holder.unit ~= "player" then
        local udb = GetUnitDb(holder.unit) or {}
        style = GetCastStyle(udb, false, ns.UFRing and ns.UFRing.Plate(frames[holder.unit]))
        style.width = (udb.width or 220) - 2 * INSET - (style.icon and (style.height + CAST_ICON_GAP) or 0)
        style.fontKey = holder.unit
    else
        style = GetCastStyle(db and db.playerCastbar or {}, true)
        style.fontKey = "playercast"
    end
    local _, PADDING = BorderFit(style.height, style.border and GetBorderFile(style.borderTexture))
    local iconOffset = style.icon and (style.height + CAST_ICON_GAP) or 0
    holder:SetSize(style.width + iconOffset + 2 * PADDING, style.height + 2 * PADDING)
    LayoutCastBar(holder.Cast, style, holder, "FILL")
    ShowSampleCast(holder.Cast)
    if holder.ticker then holder.ticker:Cancel() end
    holder.ticker = C_Timer.NewTicker(SAMPLE_CAST_SECONDS, function() ShowSampleCast(holder.Cast) end)
    return holder:GetWidth(), holder:GetHeight()
end

--------------------------------------------------
-- 16. EDIT MODE SETTINGS
--------------------------------------------------
-- Media dropdown values: FlareUI's own, then a divider and other addons' (ns.AddonMedia). A function,
-- so media registered later is listed. first: an entry before FlareUI's ("" = the frame's own).
function UF.MediaValues(mediaType, base, first)
    return function()
        local values = {}
        if first then values[1] = first end
        for _, name in ipairs(base) do
            if LSM:IsValid(mediaType, name) then values[#values + 1] = { text = name, value = name, isRadio = true } end
        end
        local others = ns.AddonMedia(mediaType)
        if #others > 0 then
            values[#values + 1] = { isDivider = true }
            for _, name in ipairs(others) do values[#values + 1] = { text = name, value = name, isRadio = true } end
        end
        return values
    end
end
UF.FLAREUI_BARS = { "FlareUI Flat", "FlareUI Dark", "FlareUI Light", "FlareUI Striped" }

-- Bar, Cast Bar and Absorb Texture values
local function BuildTextureValues()
    return UF.MediaValues("statusbar", UF.FLAREUI_BARS)
end

-- Border Texture values (Frame Border first on the cast bars)
-- None first, then (cast bars) Frame Border, then FlareUI's and other addons' borders
local function BuildBorderValues(withFrameDefault)
    local list = UF.MediaValues("border", { "FlareUI Thick", "FlareUI Thin" },
        withFrameDefault and { text = L["Frame Border"], value = "", isRadio = true } or nil)
    return function()
        local values = list()
        table.insert(values, 1, { text = L["None"], value = UF.NO_BORDER, isRadio = true })
        return values
    end
end

-- Edit Mode dialogs in collapsible sections (Core.lua ns.EditSections: open state for the session)
local function EditSections()
    return ns.EditSections()
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
    if InCombatLockdown() then pendingLayout = "LayoutPlayerCastBar" return end
    local style = GetCastStyle(cfg, true)
    style.fontKey = "playercast"
    local _, PADDING = BorderFit(style.height, style.border and GetBorderFile(style.borderTexture))
    local iconOffset = style.icon and (style.height + CAST_ICON_GAP) or 0
    holder:SetSize(style.width + iconOffset + 2 * PADDING, style.height + 2 * PADDING)
    LayoutCastBar(holder.Cast, style, holder, "FILL")
end

-- the FlareUI Player Cast Bar's frame, for its fading (Visibility.lua); nil until it is made
function UF.GetPlayerCastHolder() return playerCastHolder end

local function CreatePlayerCastBar()
    if playerCastHolder then return playerCastHolder end
    local holder = CreateFrame("Frame", "FlareUI_UF_PlayerCastBar", UIParent)
    holder:SetFrameStrata("MEDIUM")
    -- above the resource bars (and their swing bar), which stack at levels 10-114 in MEDIUM
    holder:SetFrameLevel(130)
    holder:SetClampedToScreen(true)
    holder.fuiUnit = "playercastbar"
    holder.editModeName = "FlareUI Player Cast Bar"
    holder.Cast = CreateCastBar(holder, "player")
    holder.Cast.standalone = true
    -- Cinematic fades this holder between fights, as the game's cast bar: the bar itself stays up, so
    -- hearthing, gathering and quest objects still show their cast. It also hides the holder once at
    -- load; FlareUI never hides it, so it is shown back
    if C_AddOns.IsAddOnLoaded("Cinematic") then
        holder.Cast:SetIgnoreParentAlpha(true)
        local function KeepShown(self) if not self:IsShown() and UF.PlayerCastOn() then self:Show() end end
        hooksecurefunc(holder, "Hide", KeepShown)
        hooksecurefunc(holder, "SetShown", KeepShown)
    end
    holder:SetScript("OnEvent", function(self, event, _, _, _, by, barID)
        UpdateCastBar(self.Cast, IsCastEnabled(self.Cast), event, by, barID)
    end)
    for _, event in ipairs(CAST_EVENTS) do pcall(holder.RegisterUnitEvent, holder, event, "player") end
    pcall(holder.RegisterEvent, holder, "PLAYER_ENTERING_WORLD")
    playerCastHolder = holder
    return holder
end

-- Both player cast bars brought up to date: the FlareUI Player Cast Bar (made only while Player Cast Bar
-- is on) and the player frame's own. A plain frame: fine in a fight.
function UF.ApplyPlayerCastMode()
    if playerCastHolder then
        playerCastHolder:SetShown(UF.PlayerCastOn())
        UpdateCastBar(playerCastHolder.Cast, IsCastEnabled(playerCastHolder.Cast))
    end
    local f = frames.player
    if f and f.Cast then
        UpdateCastBar(f.Cast, IsCastEnabled(f.Cast))
        if not InCombatLockdown() then LayoutFrame(f) end
    end
end

--------------------------------------------------
-- Combat text on the portrait (Show Combat Text: player and pet, off; not in Addon Style). Blizzard's own hit numbers
-- (CombatFeedback.lua: the same words, sizes, colours and timings), on FlareUI's frames: centred on
-- the portrait, or on the health bar when the frame has none. UNIT_COMBAT's amount is secret in
-- fights: it reaches the font string untouched, through BreakUpLargeNumbers (it takes secrets);
-- only the readable event and flags pick the look. A secret amount can't be told from 0, so a WOUND
-- with an Absorb / Block / Resist flag shows the word then (Blizzard shows a partial hit's number).
--------------------------------------------------
UF.CT = {
    UNITS = { player = true, pet = true },
    FADE_IN = 0.2, HOLD = 0.7, FADE_OUT = 0.3,
    PORTRAIT_SIZE = 30 / 64,   -- Blizzard: a 30 high font on a 64 px portrait
    MIN_SIZE = 14, MAX_SIZE = 44,
    AVOIDED = { ABSORB = true, BLOCK = true, RESIST = true },
    -- Edit Mode's samples, one every SAMPLE_EVERY seconds: a hit, a crit, a heal, a block, a fire hit
    SAMPLES = { { "WOUND", "", 1234, 1 }, { "WOUND", "CRITICAL", 2468, 1 }, { "HEAL", "", 856, 1 },
                { "WOUND", "BLOCK", 0, 1 }, { "WOUND", "", 512, 4 } },
    SAMPLE_EVERY = 1.3,
}

-- (FlareUI and Forever Style only: Addon Style has no good place for it)
function UF.CombatTextOn(unit)
    if not ns.UFRing or ns.UFRing.Style() == "addon" then return false end
    local udb = UF.CT.UNITS[unit] and GetUnitDb(unit)
    return udb and udb.combatText == true or false
end

function UF.CT.Word(key)
    local words = _G.CombatFeedbackText
    return (words and words[key]) or _G[key]
end

function UF.CombatTextHolder(f)
    if f.CombatText then return f.CombatText end
    local holder = CreateFrame("Frame", nil, f)
    -- above the ring, its icons and the combo strip
    holder:SetFrameLevel(f:GetFrameLevel() + 20)
    holder.Text = holder:CreateFontString(nil, "OVERLAY", "NumberFontNormalHuge")
    holder.Text:SetPoint("CENTER")
    holder:Hide()
    holder:SetScript("OnUpdate", function(self)
        local t, ct = GetTime() - (self.start or 0), UF.CT
        if t < ct.FADE_IN then
            self.Text:SetAlpha(t / ct.FADE_IN)
        elseif t < ct.FADE_IN + ct.HOLD then
            self.Text:SetAlpha(1)
        elseif t < ct.FADE_IN + ct.HOLD + ct.FADE_OUT then
            self.Text:SetAlpha(1 - (t - ct.FADE_IN - ct.HOLD) / ct.FADE_OUT)
        else
            self:Hide()
        end
    end)
    f.CombatText = holder
    return holder
end

-- On the portrait when it shows, else the health bar; the size follows it (and so Portrait Scale)
function UF.CT.Place(f, holder)
    local spot = (f.Portrait and f.Portrait:IsShown()) and f.Portrait or f.Health
    holder:ClearAllPoints()
    holder:SetAllPoints(spot)
    local h = tonumber(spot:GetHeight()) or 0
    local size = spot == f.Portrait and h * UF.CT.PORTRAIT_SIZE or h * 0.8
    return math.max(UF.CT.MIN_SIZE, math.min(UF.CT.MAX_SIZE, size))
end

function UF.ShowCombatText(f, event, flags, amount, school)
    if not (canaccessvalue(event) and canaccessvalue(flags)) then return end
    local holder = UF.CombatTextHolder(f)
    local size = UF.CT.Place(f, holder)
    -- the frame's Combat Text font (Fonts tab); a set size replaces the portrait's (Auto: 0)
    local font = UF.Font(f.fuiUnit, "combatText")
    if font and (font.size or 0) > 0 then size = font.size end
    local r, g, b = 1, 1, 1
    local text, format
    if event == "IMMUNE" then
        size, text = size * 0.5, UF.CT.Word(event)
    elseif event == "WOUND" then
        local hit
        if canaccessvalue(amount) then hit = amount ~= 0 else hit = not UF.CT.AVOIDED[flags] end
        if hit then
            if flags == "CRITICAL" or flags == "CRUSHING" then size = size * 1.5
            elseif flags == "GLANCING" then size = size * 0.75 end
            local physical = Enum.Damageclass and Enum.Damageclass.MaskPhysical or 1
            if canaccessvalue(school) and school ~= physical then r, g, b = 1, 1, 0 end
            text = BreakUpLargeNumbers(amount)
            if flags == "BLOCK_REDUCED" then format = _G.COMBAT_TEXT_BLOCK_REDUCED end
        elseif UF.CT.AVOIDED[flags] then
            size, text = size * 0.75, UF.CT.Word(flags)
        else
            text = UF.CT.Word("MISS")
        end
    elseif event == "BLOCK" then
        size, text = size * 0.75, UF.CT.Word(event)
    elseif event == "HEAL" or event == "ENERGIZE" then
        text = BreakUpLargeNumbers(amount)
        if event == "HEAL" then r, g, b = 0, 1, 0 else r, g, b = 0.41, 0.8, 0.94 end
        if flags == "CRITICAL" then size = size * 1.5 end
    else
        text = UF.CT.Word(event)
    end
    if text == nil then return end
    local fs = holder.Text
    ApplyFont(fs, font, math.floor(size + 0.5) - (font and font.size or 12))
    if format then fs:SetFormattedText(format, text) else fs:SetText(text) end
    fs:SetTextColor(r, g, b)
    fs:SetAlpha(0)
    holder.start = GetTime()
    holder:Show()
end

-- Events on while a frame has it on; Edit Mode cycles the samples on those frames
function UF.CombatTextSync()
    local ct = UF.CT
    local any = false
    for unit in pairs(ct.UNITS) do
        local f = frames[unit]
        if f and UF.CombatTextOn(unit) then any = true
        elseif f and f.CombatText then f.CombatText:Hide() end
    end
    if any and not ct.events then
        ct.events = CreateFrame("Frame")
        ct.events:SetScript("OnEvent", function(_, _, unit, event, flags, amount, school)
            if not canaccessvalue(unit) then return end
            local f = frames[unit]
            if f and f:IsVisible() and UF.CombatTextOn(unit) and not ns.EditPreviewing() then
                UF.ShowCombatText(f, event, flags, amount, school)
            end
        end)
    end
    if ct.events then
        if any then pcall(ct.events.RegisterUnitEvent, ct.events, "UNIT_COMBAT", "player", "pet")
        else ct.events:UnregisterAllEvents() end
    end
    local preview = any and ns.EditPreviewing()
    if preview and not ct.ticker then
        ct.sample = 0
        local function Next()
            ct.sample = ct.sample % #ct.SAMPLES + 1
            local s = ct.SAMPLES[ct.sample]
            for unit in pairs(ct.UNITS) do
                local f = frames[unit]
                if f and f:IsVisible() and UF.CombatTextOn(unit) then UF.ShowCombatText(f, s[1], s[2], s[3], s[4]) end
            end
        end
        Next()
        ct.ticker = C_Timer.NewTicker(ct.SAMPLE_EVERY, Next)
    elseif not preview and ct.ticker then
        ct.ticker:Cancel()
        ct.ticker = nil
        for unit in pairs(ct.UNITS) do
            local f = frames[unit]
            if f and f.CombatText then f.CombatText:Hide() end
        end
    end
end

-- a setting's redraw of its frame: once after Edit Mode's Reset Settings (LEM:Defer), else at once
function UF.Redraw(f)
    if LEM:Defer(UF.Redraw, f) then return end
    LayoutFrame(f)
    UpdateAll(f)
    if UF.CT.UNITS[f.fuiUnit] then UF.CombatTextSync() end
end
-- the same for the FlareUI Player Cast Bar
function UF.RedrawPlayerCast()
    if LEM:Defer(UF.RedrawPlayerCast) then return end
    LayoutPlayerCastBar()
    if playerCastHolder then UpdateCastBar(playerCastHolder.Cast, IsCastEnabled(playerCastHolder.Cast)) end
end
-- the Resource Bars after the player frame's Class Colours (their health bar follows it)
function UF.RefreshResourceBars()
    if LEM:Defer(UF.RefreshResourceBars) then return end
    if ns.ResourceBars and ns.ResourceBars.Refresh then ns.ResourceBars:Refresh() end
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
            UF.RedrawPlayerCast()
        end
    end
    -- Show Icon / Show Spell Timer (saved as icon / timer, false = hidden)
    local function show(key)
        return function() local c = GetPlayerCastDb(); return not (c and c[key] == false) end, set(key)
    end
    local getShowIcon, setShowIcon = show("icon")
    local getShowTimer, setShowTimer = show("timer")
    -- the same sections, in the same order, as the frames (Show Icon, Show Spell Timer and Spell
    -- Pushback are their Cast Bar section's rows too)
    local Section, settings = EditSections()
    Section("Size", {
        { name = L["Width"], kind = LEM.SettingType.Slider, default = 250, minValue = 100, maxValue = 600, valueStep = 1, get = get("width", 250), set = set("width") },
        { name = L["Height"], kind = LEM.SettingType.Slider, default = 25, minValue = 8, maxValue = 48, valueStep = 1, get = get("height", 25), set = set("height") },
    })
    local castItems = {
        { name = L["Show Icon"], kind = LEM.SettingType.Checkbox, default = true, get = getShowIcon, set = setShowIcon,
          desc = L["The spell's icon, left of the bar."] },
        { name = L["Show Spell Timer"], kind = LEM.SettingType.Checkbox, default = true, get = getShowTimer, set = setShowTimer,
          desc = L["The time left, at the right end of the bar."] },
        { name = L["Show Spell Pushback"], kind = LEM.SettingType.Checkbox, default = false, get = get("pushback", false), set = set("pushback"),
          desc = L["Next to the timer: how far hits pushed your cast back or cut your channel short, like \"+0.5\"."] },
    }
    Section("Look", {
        { name = L["Bar Texture"], kind = LEM.SettingType.Dropdown, default = DEFAULT_TEXTURE, values = BuildTextureValues(), get = get("texture", DEFAULT_TEXTURE), set = set("texture") },
        { name = L["Border"], kind = LEM.SettingType.Dropdown, default = "FlareUI Thin", values = BuildBorderValues(false), get = get("borderTexture", "FlareUI Thin"), set = set("borderTexture") },
        UF.BgOpacitySetting(UF.BAR_BG_OPACITY, get("bgOpacity", UF.BAR_BG_OPACITY), set("bgOpacity")),
        -- (11-22, Malkkav: here under Look; on the frames, in their Cast Bar section)
        UF.CastGlowSetting(GetPlayerCastDb, set("castGlow")),
    })
    -- the bar is the frame here: no Cast Bar section, its rows are Behaviour
    Section("Behaviour", castItems)
    -- last: Visibility and Faded Opacity (Visibility.lua; Always by default)
    if ns.Visibility and ns.Visibility.PlayerCastSettings then
        Section("Fading", ns.Visibility:PlayerCastSettings())
    end
    return settings
end

-- Bar Text's dropdowns for a unit frame: one per bar (Health Text, Power Text, the
-- player's Druid Mana Text), Left / Middle / Right submenus (BarText.lua BT.Setting)
UF.BAR_TEXT_NAMES = { health = L["Health Text"], power = L["Power Text"], mana = L["Druid Mana Text"] }
function UF.BarTextSettings(unit, style)
    local BT = ns.BarText
    local out = {}
    for _, bar in ipairs(unit == "player" and BT.BARS or { "health", "power" }) do
        out[#out + 1] = BT.Setting({
            name = UF.BAR_TEXT_NAMES[bar], bar = bar, style = style, unit = unit,
            db = function() return GetUnitDb(unit) end,
            firstOnly = function() return UF.FirstNameOnly(unit) end,
            changed = function()
                local f = frames[unit]
                if f then UF.Redraw(f) end
            end,
        })
    end
    return out
end

local function BuildSettings(unit)
    local info = UNITS[unit]
    local function get(key) return function() local u = GetUnitDb(unit); return u and u[key] end end
    local function set(key)
        return function(_, value)
            local u = GetUnitDb(unit)
            if not u then return end
            u[key] = value
            local f = frames[unit]
            if f then UF.Redraw(f) end
        end
    end
    local defaults = ns.defaults and ns.defaults.profile.unitframes.units[unit] or {}
    if info.styledPet then defaults = ns.UFRing.PetDefaults(unit) end

    -- sizes, then the portrait, then the texts. Forever Style's Scale sets ring and height together.
    local function onPlate() return ns.UFRing and ns.UFRing.Plate(frames[unit]) or false end
    -- on the plate Scale owns these: Edit Mode's reset runs hidden settings too, and must leave them
    local function setOffPlate(key)
        local apply = set(key)
        return function(layoutName, value, fromReset)
            if fromReset and onPlate() then return end
            apply(layoutName, value)
        end
    end
    local settings = {}
    if info.portrait and ns.UFRing and ns.UFRing.PLATE_UNITS[unit] then
        settings[#settings + 1] = { name = L["Scale"], kind = LEM.SettingType.Slider, default = ns.UFRing.PlateDefaultScale(unit),
            minValue = info.styledPet and 40 or 75, maxValue = 250, valueStep = 5,
            formatter = function(value) return value end,   -- plain: "100%" clips the value box
            get = function() return ns.UFRing.GetPlateScale(unit) end,
            set = function(layoutName, value)
                -- Forever Style only (Edit Mode's reset runs hidden settings too)
                if not onPlate() then return end
                -- saved for this Edit Mode layout (ProfileLayout.lua)
                local db, udb = GetDb(), GetUnitDb(unit)
                if db and udb and ns.SetLayoutPlateScale then
                    db.layouts = db.layouts or {}
                    ns.SetLayoutPlateScale(db.layouts, layoutName or LEM:GetActiveLayoutName() or "Modern", unit .. "Scale",
                        udb, value, ns.UFRing.PlateDefaultScale(unit))
                else
                    ns.UFRing.SetPlateScale(unit, value)
                end
                local f = frames[unit]
                if f then UF.Redraw(f) end
            end,
            hidden = function() return not onPlate() end,
            desc = L["Each Edit Mode layout keeps its own Scale."] }
    end
    -- the ring styles' presets have their own widths
    local width = ns.UFRing and ns.UFRing.On() and ns.UFRing.PresetValue(unit, "width") or defaults.width or 220
    settings[#settings + 1] = { name = L["Width"], kind = LEM.SettingType.Slider, default = width, minValue = 60, maxValue = 500, valueStep = 1, get = get("width"), set = set("width") }
    settings[#settings + 1] = { name = L["Height"], kind = LEM.SettingType.Slider, default = defaults.height or 44, minValue = 16, maxValue = 120, valueStep = 1, get = get("height"), set = setOffPlate("height"),
        hidden = onPlate }
    -- Portrait Scale (FlareUI Style only, 100%): the ring in proportion, apart from the height
    if info.portrait and ns.UFRing then
        settings[#settings + 1] = { name = L["Portrait Scale"], kind = LEM.SettingType.Slider, default = 100, minValue = 50, maxValue = 150, valueStep = 5,
            formatter = function(value) return value end,   -- plain: "100%" clips the value box
            get = function() local u = GetUnitDb(unit); return u and u.portraitScale or 100 end, set = set("portraitScale"),
            hidden = function() return not (ns.UFRing.Applies(frames[unit]) and ns.UFRing.Style() == "flareui") end,
            desc = L["The portrait ring in percent of its usual size. It keeps its shape, and the frame keeps its height."] }
    end
    settings[#settings + 1] = { name = L["Power Height"], search = L["Power Bar Height"], kind = LEM.SettingType.Slider, default = defaults.powerHeight or 8, minValue = 0, maxValue = 40, valueStep = 1, get = get("powerHeight"), set = set("powerHeight"),
        formatter = function(value) return value == 0 and _G.OFF or value end,
        -- Forever Style: the plate has its own power slot
        hidden = onPlate }
    if ns.UFRing and ns.UFRing.PLATE_UNITS[unit] then
        settings[#settings + 1] = UF.PlatePowerSetting(
            function() local u = GetUnitDb(unit); return u and u.platePower end,
            function(value)
                -- Forever Style only (Edit Mode's reset runs hidden settings too)
                if not onPlate() then return end
                local u = GetUnitDb(unit)
                if not u then return end
                u.platePower = value
                local f = frames[unit]
                if f then UF.Redraw(f) end
            end, onPlate)
    end
    -- (no Portrait Size: FlareUI Style's ring follows the frame's height, UnitFramesRing.lua RingDiameter)
    -- (the styled pet always shows its own portrait)
    if info.portrait and not info.styledPet then
        -- "3d" is the stored name of the 2D picture (kept for saved setups)
        local portraitValues = {
            { text = L["None"],       value = "none",  isRadio = true },
            { text = L["2D"],         value = "3d",    isRadio = true },
            { text = L["Class Icon"], value = "class", isRadio = true },
        }
        settings[#settings + 1] = { name = L["Portrait"], kind = LEM.SettingType.Dropdown, default = "none",
            values = portraitValues,
            -- the Forever style always has a portrait: None is left out there
            generator = function(_, rootDescription, data)
                local ring = ns.UFRing and ns.UFRing.On()
                for _, p in ipairs(portraitValues) do
                    if not (ring and p.value == "none") then
                        rootDescription:CreateRadio(p.text,
                            function(value) local u = GetUnitDb(unit); local cur = u and u.portrait or "none"; if cur == "model" then cur = "3d" end; if ring and cur == "none" then cur = "3d" end; return cur == value end,
                            function(value) data.set(nil, value) end, p.value)
                    end
                end
            end,
            get = function() local u = GetUnitDb(unit); local v = u and u.portrait or "none"; if v == "model" then v = "3d" end; return v end, set = set("portrait") }
    end
    -- Bar Text: Left, Middle and Right on each bar, several picks each (BarText.lua);
    -- Druid Mana for the player (shown for every class, as class options are)
    for _, item in ipairs(UF.BarTextSettings(unit, function() return (ns.UFRing and ns.UFRing.PlateOn() and onPlate()) and "plate" or "plain" end)) do
        settings[#settings + 1] = item
    end
    -- Name Above Frames (BarText.lua): hidden on Forever Style's plate, which has its name box
    settings[#settings + 1] = ns.NameAbove.Setting({
        db = function() return GetUnitDb(unit) end,
        hidden = onPlate,
        changed = function() local f = frames[unit] if f then UF.Redraw(f) end end,
    })
    if info.comboPoints then
        -- (the redraw is UF.Redraw's, so a Reset Settings lays the frame out once; LayoutFrame applies
        -- the combo mode again in the ring styles, with the settings as they end up)
        local function refreshCombo()
            local f = frames[unit]
            if not f then return end
            ApplyComboMode(f)
            UF.Redraw(f)
        end
        -- one dropdown in every style (11-20, was a switch in Modern and nothing in Forever):
        -- Classic is Blizzard's gems round the portrait (the ring styles), Modern the strip along the
        -- health bar (Modern Style, and FlareUI Style's option). Saved as before: ringCombo in the
        -- ring styles, the comboPoints switch in Modern Style.
        local function Style() return ns.UFRing and ns.UFRing.Style() or "addon" end
        settings[#settings + 1] = { name = L["Combo Points"], kind = LEM.SettingType.Dropdown,
            default = (Style() == "addon") and "modern" or "classic",
            values = function()
                local style = Style()
                local list = { { text = L["Off"], value = "off", isRadio = true } }
                if style ~= "addon" then list[#list + 1] = { text = L["Classic"], value = "classic", isRadio = true } end
                if style ~= "forever" then list[#list + 1] = { text = L["Modern"], value = "modern", isRadio = true } end
                return list
            end,
            get = function()
                local u = GetUnitDb(unit)
                if Style() == "addon" then return (u and u.comboPoints == false) and "off" or "modern" end
                local mode = UF.RingComboMode(u)
                if Style() == "forever" and mode == "modern" then mode = "classic" end
                return mode
            end,
            set = function(_, value)
                local u = GetUnitDb(unit)
                if not u then return end
                if value == nil then value = (Style() == "addon") and "modern" or "classic" end
                if Style() == "addon" then
                    u.comboPoints = value ~= "off"
                else
                    u.ringCombo, u.modernCombo = value, nil
                end
                refreshCombo()
            end,
            desc = L["Classic: gems round the portrait. Modern: a bar along the top of the health bar, as in Modern Style."] }
    end
    if UF.THREAT_PERCENT_UNITS[unit] then
        settings[#settings + 1] = { name = L["Threat Text"], kind = LEM.SettingType.Checkbox, default = false,
            desc = L["Your threat on this unit as a percent, in threat colours. Above the portrait ring, or after the health value in Modern Style."],
            get = function() local u = GetUnitDb(unit); return u and u.threatPercent or false end,
            set = function(_, value)
                local u = GetUnitDb(unit)
                if not u then return end
                u.threatPercent = value
                local f = frames[unit]
                if f then UF.Redraw(f) end   -- off gives the health text its place back
            end }
    end
    -- (the ring styles show it in the ring's disc, which goes with it)
    -- (Forever Style's name box only: elsewhere the name is a Health Text pick)
    settings[#settings + 1] = { name = L["Show Name"], kind = LEM.SettingType.Checkbox, default = true,
        get = function() return get("showName")() ~= false end, set = set("showName"),
        hidden = function() return not onPlate() end }
    settings[#settings + 1] = { name = L["Show Level"], kind = LEM.SettingType.Checkbox, default = defaults.showLevel ~= false, get = get("showLevel"), set = set("showLevel") }
    settings[#settings + 1] = UF.ValuesOnHoverSetting(get("valuesOnHover"), set("valuesOnHover"))
    settings[#settings + 1] = (function()
        local ret = { name = L["Level Disc Size"], kind = LEM.SettingType.Slider, default = 100, minValue = 50, maxValue = 100, valueStep = 5,
          formatter = function(value) return value end,   -- plain: "100%" clips the value box
          get = function() local v = get("levelSize")(); return math.floor((tonumber(v) or 1) * 100 + 0.5) end,
          set = function(layoutName, value) set("levelSize")(layoutName, value ~= 100 and value / 100 or nil) end,
          hidden = function() return not (ns.UFRing and ns.UFRing.Style() ~= "addon") or not (get("showLevel")() ~= false) end }
        return ret
    end)()
    -- Show Combat Text (player and pet, off; FlareUI and Forever Style): the hits and heals taken, on the portrait
    if UF.CT.UNITS[unit] then
        settings[#settings + 1] = { name = L["Show Combat Text"], kind = LEM.SettingType.Checkbox, default = false,
            desc = L["Damage and heals taken show on the portrait, as on Blizzard's frames. With no portrait, they show on the health bar."],
            get = function() local u = GetUnitDb(unit); return u and u.combatText == true or false end, set = set("combatText"),
            hidden = function() return not ns.UFRing or ns.UFRing.Style() == "addon" end }
    end
    -- Flip Portrait: the portrait on the right, the whole frame laid out as the
    -- target frame; off, on the left as the player frame. Target, focus and the target-of frames, on by
    -- default; the ring styles (Addon Style's Mirror Bars lays its frames out). Above Mirror.
    if ns.UFRing and ns.UFRing.FLIP_UNITS[unit] then
        settings[#settings + 1] = { name = L["Flip Portrait"], kind = LEM.SettingType.Checkbox, default = true,
            desc = L["The portrait on the right, as on the target frame. Off: on the left, as on the player frame."],
            get = function() local u = GetUnitDb(unit); return not (u and u.portraitRight == false) end,
            set = function(_, value)
                local u = GetUnitDb(unit)
                if not u then return end
                if value then u.portraitRight = nil else u.portraitRight = false end
                local f = frames[unit]
                if f then UF.Redraw(f); AttachExtras(f) end
            end,
            -- (a simple Target of Target / Target of Focus has no portrait to flip)
            hidden = function()
                if not (ns.UFRing and ns.UFRing.Style() ~= "addon") then return true end
                local db = ns.db and ns.db.profile and ns.db.profile.unitframes
                return (unit == "targettarget" or unit == "focustarget") and db and db.simpleTargetOf and true or false
            end }
    end
    -- target of target and target of focus offer it too (info.mirrorOption)
    if info.mirrorable or info.mirrorOption then
        -- flips text order and bar fill so the frame faces the player frame
        settings[#settings + 1] = { name = L["Mirror Bars"], kind = LEM.SettingType.Checkbox, default = defaults.mirror or false, get = function() local u = GetUnitDb(unit); return u and u.mirror or false end,
            set = function(_, value) local u = GetUnitDb(unit); if not u then return end; u.mirror = value; local f = frames[unit]; if f then UF.Redraw(f); AttachExtras(f) end end,
            desc = L["The bars fill from the other side, and the texts swap sides, so the frame faces the player frame."] }
    end
    if unit == "player" then
        settings[#settings + 1] = { name = L["Five-Second Rule"], kind = LEM.SettingType.Checkbox, default = false,
            get = function() local u = GetUnitDb(unit); return u and u.fsr == true or false end,
            set = function(_, value) local u = GetUnitDb(unit); if not u then return end; u.fsr = value; UpdateFsrSpark() end,
            desc = L["A spark crosses the bar for five seconds after you spend mana. Spirit regeneration starts again when it ends."] }
        -- as on the Resource Bars' power bar, right after Five-Second Rule
        settings[#settings + 1] = { name = L["GCD Spark"], kind = LEM.SettingType.Checkbox, default = false,
            get = function() local u = GetUnitDb(unit); return u and u.gcd == true or false end,
            set = function(_, value) local u = GetUnitDb(unit); if not u then return end; u.gcd = value; UF.Gcd.Update() end,
            desc = L["A spark crosses the bar during the global cooldown."] }
        settings[#settings + 1] = { name = L["Mana on Shapeshift"], kind = LEM.SettingType.Checkbox, default = false,
            get = function() local u = GetUnitDb(unit); return u and u.shiftMana == true or false end,
            set = function(_, value)
                local u = GetUnitDb(unit); if not u then return end
                u.shiftMana = value
                local f = frames[unit]
                if f and f.ShiftMana then
                    UF.UpdateShiftMana(f)
                    AttachExtras(f)
                end
            end,
            desc = L["Druids: a thin mana bar under the power bar, in forms without mana. The health bar gets shorter to make room; in Forever Style the frame gets a second power slot."] }
    end
    -- Range Check: the frames that fade out of range (target and focus); with the frame's own rows
    -- (it changes how the frame behaves, not how it looks)
    if tContains(UF.RANGE_UNITS, unit) then
        settings[#settings + 1] = { name = L["Range Check"], kind = LEM.SettingType.Checkbox, default = not UF.RANGE_OFF_FIRST[unit],
            desc = L["The frame fades while the unit is out of range."],
            get = function()
                local u = GetUnitDb(unit)
                if UF.RANGE_OFF_FIRST[unit] then return u and u.rangeCheck == true or false end
                return not (u and u.rangeCheck == false)
            end,
            set = function(_, value)
                local u = GetUnitDb(unit)
                if not u then return end
                u.rangeCheck = value
                UF.ApplyRangeAlpha(frames[unit], unit)
            end }
    end
    -- Tint Health: Behaviour, on every unit frame
    settings[#settings + 1] = UF.HealthColorSetting(get("healthColor"), set("healthColor"))
    -- everything above is the frame itself: Size and Text first, Behaviour after Look (Core.lua
    -- ns.SplitFrameItems)
    local frameItems = settings
    local Section
    Section, settings = EditSections()
    local sizeItems, textItems, behaviourItems = ns.SplitFrameItems(frameItems)
    Section("Size", sizeItems)
    Section("Text", textItems)

    -- the bars' texture and the border; the ring styles keep their own border
    local lookItems = {
        { name = L["Bar Texture"], kind = LEM.SettingType.Dropdown, default = defaults.texture or DEFAULT_TEXTURE, values = BuildTextureValues(),
          get = function() local u = GetUnitDb(unit); return u and u.texture or DEFAULT_TEXTURE end, set = set("texture") },
        { name = L["Border"], kind = LEM.SettingType.Dropdown, default = defaults.border or DEFAULT_BORDER, values = BuildBorderValues(false),
          get = function() local u = GetUnitDb(unit); return u and u.border or DEFAULT_BORDER end, set = set("border"),
          -- Forever Style's plate has its own frame; every other frame (simple pet, simple target of
          -- target) picks a border in every style
          hidden = onPlate },
    }
    -- the absorb overlay, on frames with heal prediction; "" is the frame's own texture
    if info.indicators and info.indicators.heals then
        lookItems[#lookItems + 1] = { name = L["Absorb Texture"], kind = LEM.SettingType.Dropdown, default = defaults.absorbTexture or ABSORB_TEXTURE,
            values = BuildTextureValues(),
            get = function() local u = GetUnitDb(unit); local v = u and u.absorbTexture; if v == nil then return ABSORB_TEXTURE end; return v end,
            set = set("absorbTexture"),
            desc = L["The texture of the shield (absorb) over the health bar."] }
    end
    -- how dark the bars' empty part is, then Class Colours below it
    local bgDefault = UF.DefaultBgOpacity(unit)
    lookItems[#lookItems + 1] = UF.BgOpacitySetting(bgDefault,
        function() local u = GetUnitDb(unit); local v = u and u.bgOpacity; if v == nil then return bgDefault end; return v end,
        set("bgOpacity"))
    lookItems[#lookItems].hidden = onPlate
    if unit ~= "pet" then
        lookItems[#lookItems + 1] = UF.ClassColorSetting(function() return ns.ClassColorsOn(GetUnitDb(unit)) end,
            function(layoutName, value)
                set("classColor")(layoutName, value)
                -- the Resource Bars' health bar follows the player frame
                if unit == "player" then UF.RefreshResourceBars() end
            end)
    end
    -- (not on target of target and target of focus)
    if not info.poll then
        lookItems[#lookItems + 1] = UF.SmoothBarsSetting(function() local u = GetUnitDb(unit); return u and u.smoothBars end, set("smoothBars"))
    end
    -- (per frame, off)
    lookItems[#lookItems + 1] = UF.BarEdgeGlowSetting(get("barEdgeGlow"), set("barEdgeGlow"))
    if not info.poll then lookItems[#lookItems + 1] = UF.DamageTrailSetting(get("damageTrail"), set("damageTrail")) end
    -- Threat Glow, and the player's Combat Glow
    if info.threatGlow then
        lookItems[#lookItems + 1] = { name = L["Threat Glow"], kind = LEM.SettingType.Checkbox, default = true,
            desc = unit == "pet" and L["The border pulses in the threat colour while the unit has aggro."]
                or L["The border pulses in the threat colour while you have threat on it."],
            get = function() return UF.GlowOn(unit, "threatGlow") end, set = set("threatGlow") }
    end
    if info.combatGlow then
        lookItems[#lookItems + 1] = { name = L["Combat Glow"], kind = LEM.SettingType.Checkbox, default = true,
            desc = L["In a fight, the border and portrait pulse red. With aggro, the threat colour shows instead."],
            get = function() return UF.GlowOn(unit, "combatGlow") end, set = set("combatGlow") }
    end
    Section("Look", lookItems)
    Section("Behaviour", behaviourItems)

    if info.castbar then
        local function castOff() local u = GetUnitDb(unit); return u and u.castbar == false or false end
        local noCast = castOff
        local castItems = {
            { name = L["Cast Bar"], kind = LEM.SettingType.Checkbox, default = defaults.castbar ~= false,
              get = function() return not castOff() end,
              set = function(layoutName, value)
                  set("castbar")(layoutName, value)
                  if frames[unit] then LEM:RefreshFrameSettings(frames[unit]) end
              end },
            { name = L["Position"], canon = "Cast Bar Position", search = L["Cast Bar Position"], kind = LEM.SettingType.Dropdown, default = defaults.castbarPosition or "BOTTOM",
              values = { { text = L["Above"], value = "TOP", isRadio = true }, { text = L["Below"], value = "BOTTOM", isRadio = true } },
              get = get("castbarPosition"), set = set("castbarPosition"), hidden = noCast },
            { name = L["Bar Texture"], canon = "Cast Bar Texture", search = L["Cast Bar Texture"], kind = LEM.SettingType.Dropdown, default = defaults.castTexture or "", values = BuildTextureValues(),
              get = function() local u = GetUnitDb(unit); return u and u.castTexture or "" end, set = set("castTexture"), hidden = noCast },
            { name = L["Border"], canon = "Cast Bar Border", search = L["Cast Bar Border"], kind = LEM.SettingType.Dropdown, default = defaults.castBorderTexture or "", values = BuildBorderValues(true),
              get = function() local u = GetUnitDb(unit); return u and u.castBorderTexture or "" end, set = set("castBorderTexture"),
              desc = L["The cast bar's border. Frame Border matches the frame's own border."],
              hidden = function() return noCast() or onPlate() end },
            { name = L["Height"], canon = "Cast Bar Height", search = L["Cast Bar Height"], kind = LEM.SettingType.Slider, default = defaults.castHeight or CAST_HEIGHT, minValue = 8, maxValue = 40, valueStep = 1,
              get = function() local u = GetUnitDb(unit); return u and u.castHeight or CAST_HEIGHT end, set = set("castHeight"), hidden = noCast },
            -- the cast bar's own Background, every style. Until set: the frame's Background off the
            -- plate, the default on it (the plate's slots are the bars' there)
            (function()
                local item = UF.BgOpacitySetting(UF.BAR_BG_OPACITY,
                    function()
                        local u = GetUnitDb(unit)
                        local v = u and u.castBgOpacity
                        if v ~= nil then return v end
                        if not onPlate() and u and u.bgOpacity ~= nil then return u.bgOpacity end
                        return UF.BAR_BG_OPACITY
                    end,
                    set("castBgOpacity"))
                item.canon, item.search = "Cast Bar Background", L["Cast Bar Background"]
                item.hidden = noCast
                return item
            end)(),
            { name = L["Show Icon"], kind = LEM.SettingType.Checkbox, default = true,
              get = function() local u = GetUnitDb(unit); return not (u and u.castIcon == false) end,
              set = set("castIcon"),
              hidden = noCast,
              desc = L["The spell's icon, left of the bar."] },
            { name = L["Show Spell Timer"], kind = LEM.SettingType.Checkbox, default = true,
              get = function() local u = GetUnitDb(unit); return not (u and u.castTimer == false) end,
              set = set("castTimer"),
              hidden = noCast,
              desc = L["The time left, at the right end of the bar."] },
            UF.CastGlowSetting(function() return GetUnitDb(unit) end, set("castGlow"), noCast),
        }
        if unit == "player" then
            -- the FlareUI Player Cast Bar's extras, on the bar on the player frame too
            local function flag(key, default)
                return function() local u = GetUnitDb(unit); local v = u and u[key]; if v == nil then return default end; return v end
            end
            local extras = {
                { name = L["Show Spell Pushback"], kind = LEM.SettingType.Checkbox, default = false, get = flag("pushback", false), set = set("pushback"),
                  desc = L["Next to the timer: how far hits pushed your cast back or cut your channel short, like \"+0.5\"."] },
            }
            for _, item in ipairs(extras) do
                item.hidden = noCast
                castItems[#castItems + 1] = item
            end
        end
        Section("Cast Bar", castItems)
    end
    if info.auras then
        local positions = {
            { text = L["Off"],          value = "OFF" },
            { text = L["Above the Frame"],        value = "TOP" },
            { text = L["Above the Frame, Left"],  value = "TOPLEFT" },
            { text = L["Above the Frame, Right"], value = "TOPRIGHT" },
            { text = L["Below the Frame"],        value = "BOTTOM" },
            { text = L["Below the Frame, Left"],  value = "BOTTOMLEFT" },
            { text = L["Below the Frame, Right"], value = "BOTTOMRIGHT" },
        }
        -- buffs and debuffs may share a place or an edge: they stack, the one picked later further
        -- out (AURA.Stack); a pick that clashes with the other kind's records itself as the further one
        local function SetPlace(field, other)
            local base = set(field)
            return function(layoutName, value)
                local u = GetUnitDb(unit)
                if u and AURA.Clash(value, get(other)()) then u.auraOuter = field end
                base(layoutName, value)
            end
        end
        local function Corner(field, other)
            return function(_, rootDescription, data)
                for _, p in ipairs(positions) do
                    local radio = rootDescription:CreateRadio(p.text,
                        function(value) return (get(field)() or "OFF") == value end,
                        function(value) data.set(nil, value) end, p.value)
                end
            end
        end
        local auraItems = {
            { name = L["Buffs"], kind = LEM.SettingType.Dropdown, default = defaults.buffs or "OFF", values = positions,
              generator = Corner("buffs", "debuffs"), get = get("buffs"), set = SetPlace("buffs", "debuffs") },
            { name = L["Debuffs"], kind = LEM.SettingType.Dropdown, default = defaults.debuffs or "OFF", values = positions,
              generator = Corner("debuffs", "buffs"), get = get("debuffs"), set = SetPlace("debuffs", "buffs") },
            { name = L["Buff Size"], kind = LEM.SettingType.Slider, default = defaults.auraSize or 22, minValue = 8, maxValue = 48, valueStep = 1,
              get = function() return ns.AuraSize(GetUnitDb(unit), false, defaults.auraSize or 22) end, set = set("buffSize") },
            { name = L["Max Buffs"], kind = LEM.SettingType.Slider, default = UF.AuraAmountDefault(unit),
              minValue = UF.AURA_AMOUNT.min, maxValue = UF.AURA_AMOUNT.max, valueStep = 1,
              get = function() return UF.AuraAmount(GetUnitDb(unit), false, unit) end, set = set("buffAmount"),
              desc = L["How many buffs show. They take as many rows as they need."] },
            { name = L["Debuff Size"], kind = LEM.SettingType.Slider, default = defaults.auraSize or 22, minValue = 8, maxValue = 48, valueStep = 1,
              get = function() return ns.AuraSize(GetUnitDb(unit), true, defaults.auraSize or 22) end, set = set("debuffSize") },
            { name = L["Max Debuffs"], kind = LEM.SettingType.Slider, default = UF.AuraAmountDefault(unit),
              minValue = UF.AURA_AMOUNT.min, maxValue = UF.AURA_AMOUNT.max, valueStep = 1,
              get = function() return UF.AuraAmount(GetUnitDb(unit), true, unit) end, set = set("debuffAmount"),
              desc = L["How many debuffs show. They take as many rows as they need."] },
        }
        table.insert(auraItems, 3, UF.HideBuffsSetting("OFF",
            function() local u = GetUnitDb(unit); return u and u.hideBuffs or "OFF" end, set("hideBuffs")))
        -- the player: Only My Buffs, after the sizes, and the party frames' Dispel Highlight
        if unit == "player" then
            auraItems[#auraItems + 1] = { name = L["Only My Buffs"], kind = LEM.SettingType.Checkbox, default = false,
                get = function() local u = GetUnitDb(unit); return u and u.onlyMyBuffs or false end, set = set("onlyMyBuffs"),
                desc = L["Only the buffs you cast on yourself."] }
            auraItems[#auraItems + 1] = { name = L["Show Weapon Enchants"], kind = LEM.SettingType.Checkbox, default = true,
                get = function() local u = GetUnitDb(unit); return not (u and u.showEnchants == false) end, set = set("showEnchants"),
                desc = L["Poisons, sharpening stones, oils and shaman weapon spells, at the start of the buffs. They follow Hide Buffs too."] }
            auraItems[#auraItems + 1] = { name = L["Dispel Highlight"], kind = LEM.SettingType.Dropdown, default = "off",
                values = { { text = L["Off"], value = "off", isRadio = true }, { text = L["Dispellable by Me"], value = "mine", isRadio = true },
                           { text = L["Dispellable by the Group"], value = "all", isRadio = true } },
                desc = L["A dispellable debuff on you makes the frame's border pulse in its type's colour. In the ring styles the portrait's ring pulses too."],
                get = function() local u = GetUnitDb(unit); return u and u.dispelHighlight or "off" end, set = set("dispelHighlight") }
        end
        -- target and focus: the same Dispel Highlight, for a friendly unit you dispel (11-20, off)
        if unit == "target" or unit == "focus" then
            auraItems[#auraItems + 1] = { name = L["Dispel Highlight"], kind = LEM.SettingType.Dropdown, default = "off",
                values = { { text = L["Off"], value = "off", isRadio = true }, { text = L["Dispellable by Me"], value = "mine", isRadio = true },
                           { text = L["Dispellable by the Group"], value = "all", isRadio = true } },
                desc = L["A dispellable debuff on a friendly unit makes the frame's border pulse in its type's colour."],
                get = function() local u = GetUnitDb(unit); return u and u.dispelHighlight or "off" end, set = set("dispelHighlight") }
        end
        -- every debuff on yourself is yours to see: other units only
        if unit ~= "player" then
            auraItems[#auraItems + 1] = { name = L["Only My Debuffs"], kind = LEM.SettingType.Checkbox, default = defaults.onlyMyDebuffs or false, get = get("onlyMyDebuffs"), set = set("onlyMyDebuffs") }
        end
        Section("Auras", ns.AuraOrder.With(auraItems, get, set))
    end

    -- one switch per icon; where they sit is fixed
    local icons = ICON_UI.List(unit)
    if #icons > 0 then
        local items = {}
        for _, key in ipairs(icons) do
            local def = ICON_UI.defs[key]
            if key ~= "happiness" then
            items[#items + 1] = { name = def.label, kind = LEM.SettingType.Checkbox, default = def.default ~= false,
                hidden = (def.ring and function() return not (ns.UFRing and ns.UFRing.On()) end)
                    or (def.noRing and function() return ns.UFRing and ns.UFRing.On() or false end) or nil,
                get = function() return ICON_UI.Shown(unit, key) end,
                set = function(_, value)
                    local store = ICON_UI.Store(unit, key, true)
                    if not store then return end
                    store.shown = value
                    local f = frames[unit]
                    if f then UF.Redraw(f) end
                end }
            else
                -- the pet's happiness face: one dropdown, Off or where it sits. The styled pet has no
                -- Left, and on Forever Style's plate the face has a fixed spot: Off or Shown.
                local function Places()
                    local list = { { text = L["Off"], value = "OFF", isRadio = true } }
                    if info.styledPet and onPlate() then
                        list[2] = { text = L["Shown"], value = "ON", isRadio = true }
                        return list
                    end
                    list[2] = { text = L["Centre"], value = "CENTER", isRadio = true }
                    list[3] = { text = L["Right of the Frame"], value = "RIGHT", isRadio = true }
                    if not info.styledPet then list[4] = { text = L["Left of the Frame"], value = "LEFT", isRadio = true } end
                    return list
                end
                items[#items + 1] = { name = def.label, kind = LEM.SettingType.Dropdown,
                    default = def.default == false and "OFF" or "RIGHT",
                    values = Places,
                    desc = L["Your pet's happiness face, and where it sits."],
                    get = function()
                        if not ICON_UI.Shown(unit, "happiness") then return "OFF" end
                        if info.styledPet and onPlate() then return "ON" end
                        return ICON_UI.HappinessPlace(unit)
                    end,
                    set = function(_, value)
                        local store = ICON_UI.Store(unit, "happiness", true)
                        if not store then return end
                        store.shown = value ~= "OFF"
                        if value ~= "OFF" and value ~= "ON" then store.place = value end
                        local f = frames[unit]
                        if f then UF.Redraw(f) end
                    end }
            end
        end
        Section("Icons", items)
    end
    -- last: Fade Group (player and pet), Visibility, the fade speeds and Faded Opacity, as on the action bars (Visibility.lua)
    if ns.Visibility and ns.Visibility.UnitFrameSettings then
        Section("Fading", ns.Visibility:UnitFrameSettings(unit))
    end
    return settings
end

-- Each frame's fonts: set on the Unit Frames page's Fonts tab, a section per frame
-- (Settings/Pages/UnitFrames.lua). The texts a frame has, in order (key: a unit, "party", "raid",
-- "boss", "flag" or "playercast")
local FRAME_TEXTS = { party = { castbar = true, auras = true }, raid = { auras = true }, boss = { castbar = true, auras = true },
                      flag = { castbar = true } }
function UF.FontElements(key)
    if key == "playercast" then return { "cast", "castTime" } end
    local info = UNITS[key] or FRAME_TEXTS[key] or {}
    local list = { "names", "health", "level", "power" }
    if info.castbar then list[#list + 1] = "cast"; list[#list + 1] = "castTime" end
    if info.auras then list[#list + 1] = "auras"; list[#list + 1] = "auraCount" end
    if UF.CT.UNITS[key] then list[#list + 1] = "combatText" end   -- Show Combat Text
    return list
end

local function RegisterEditMode(f)
    LEM:AddFrame(f, OnFrameMoved, DEFAULT_POSITIONS[f.fuiUnit], "FlareUI " .. UNITS[f.fuiUnit].label)
    LEM:AddFrameSettings(f, BuildSettings(f.fuiUnit))
end

--------------------------------------------------
-- 18. PUBLIC
--------------------------------------------------
-- Building blocks the party, raid and boss frames and the resource bars share with these frames
UF.Kit = {
    Font = UF.Font,   -- a frame's text font (party, raid and boss tiles: PartyFrames.lua PF.FontKey)
    -- Forever Style's fixed border, and whether border options are hidden (Forever Style: always);
    -- Background Opacity's bar background and its Edit Mode slider
    Border = function(name) return ns.UFRing and ns.UFRing.Border(name) or name end,
    NoBorderOptions = function() return ns.UFRing and ns.UFRing.PlateOn() or false end,
    BAR_BG_OPACITY = UF.BAR_BG_OPACITY, SetBarBackground = UF.SetBarBackground, BgOpacitySetting = UF.BgOpacitySetting, PlatePowerSetting = UF.PlatePowerSetting, SmoothBarsSetting = UF.SmoothBarsSetting, BarEdgeGlowSetting = UF.BarEdgeGlowSetting, DamageTrailSetting = UF.DamageTrailSetting, DamageTrailOn = UF.DamageTrailOn, HideBuffsSetting = UF.HideBuffsSetting, ClassColorSetting = UF.ClassColorSetting, ValuesOnHover = UF.ValuesOnHover, ValuesOnHoverSetting = UF.ValuesOnHoverSetting,
    HealthColorSetting = UF.HealthColorSetting, HealthBarColor = UF.HealthBarColor, HealthColorLive = UF.HealthColorLive, HealthColorMode = UF.HealthColorMode, SampleHealthColor = UF.SampleHealthColor,
    INSET = INSET, BG_OPACITY = BG_OPACITY, BACKDROP_FILE = BACKDROP_FILE,
    SEPARATOR_TEXTURE = SEPARATOR_TEXTURE, SEPARATOR_HEIGHT = SEPARATOR_HEIGHT, TEXT_INSET = TEXT_INSET,
    CAST_GAP = CAST_GAP, AURA_GAP = AURA_GAP,
    DEFAULT_TEXTURE = DEFAULT_TEXTURE,
    HEAL_COLOR = HEAL_COLOR, ABSORB_COLOR = ABSORB_COLOR, HEAL_TEXTURE = HEAL_TEXTURE, ABSORB_TEXTURE = ABSORB_TEXTURE,
    HEALTH_TEXT_MODES = HEALTH_TEXT_MODES, CAST_EVENTS = CAST_EVENTS,
    SetHealthLost = UF.SetHealthLost, SetSampleHealthLost = UF.SetSampleHealthLost,
    POWER_TEXT_MODES = UF.POWER_TEXT_MODES, PowerTextMode = UF.PowerTextMode, SetPowerText = UF.SetPowerText,
    IsPowerTextMode = UF.IsPowerTextMode, FormatBarText = UF.FormatBarText,
    HealthSource = UF.HealthSource, PowerSource = UF.PowerSource, SampleSource = UF.SampleSource,
    DEAD_TEXT = DEAD_TEXT, GHOST_TEXT = GHOST_TEXT, OFFLINE_TEXT = OFFLINE_TEXT,
    percentCurve = percentCurve, LevelFont = UF.LevelFont,
    GetDb = GetDb,
    GetBarTexture = GetBarTexture, GetBorderFile = GetBorderFile, BorderFit = BorderFit,
    ApplyBorderStyle = ApplyBorderStyle,
    CreateBar = CreateBar, ApplyFont = ApplyFont,
    GetHealthColor = GetHealthColor, GetPowerColor = GetPowerColor,
    HardHide = HardHide, SetIconArt = SetIconArt, HasAtlas = HasAtlas,
    CreateCastBar = CreateCastBar, LayoutCastBar = LayoutCastBar, UpdateCastBar = UpdateCastBar,
    ClassArt = ICON_UI.ClassArt, CLASS_SKULL = ICON_UI.CLASS_SKULL, CLASS_ICON_SIZE = ICON_SIZE.pvp,
    InitAuraButton = InitAuraButton, HasAuraSupport = HasAuraSupport,
    ApplyRangeAlpha = UF.ApplyRangeAlpha,
    CreateManaCost = UF.CreateManaCost, CostsMana = CostsMana,
    IsDead = UF.IsDead, CreateShieldGlow = UF.CreateShieldGlow, PlaceShieldGlow = UF.PlaceShieldGlow,
    CreateDamageTrail = UF.CreateDamageTrail, PlaceDamageTrail = UF.PlaceDamageTrail, SetDamageTrail = UF.SetDamageTrail, SampleDamageTrail = UF.SampleDamageTrail,
    BarLook = UF.BarLook, BarLookUpdate = UF.BarLookUpdate,
    CreateOverAbsorb = UF.CreateOverAbsorb, PlaceOverAbsorb = UF.PlaceOverAbsorb, SetOverAbsorb = UF.SetOverAbsorb, SetShieldGlow = UF.SetShieldGlow, HideShieldGlow = UF.HideShieldGlow,
    BuildTextureValues = BuildTextureValues, BuildBorderValues = BuildBorderValues, BuildAbsorbValues = BuildTextureValues, EditSections = EditSections,
    ThreatColor = ThreatColor, SetBorderGlow = UF.SetBorderGlow,
}

function UF:Refresh()
    if not self.initialized then return end
    if InCombatLockdown() then pendingLayout = "Refresh" return end
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
    -- the frames that exist now are the ones that fade
    if ns.Visibility and ns.Visibility.Refresh then guard("fading", function() ns.Visibility:Refresh() end) end
    -- the group frames and resource bars share the fonts, palette and class colours set here
    if ns.PartyFrames and ns.PartyFrames.initialized then guard("party frames", function() ns.PartyFrames:Refresh() end) end
    if ns.RaidFrames and ns.RaidFrames.initialized then guard("raid frames", function() ns.RaidFrames:Refresh() end) end
    if ns.BossFrames and ns.BossFrames.initialized then guard("boss frames", function() ns.BossFrames:Refresh() end) end
    if ns.ResourceBars and ns.ResourceBars.initialized then guard("resource bars", function() ns.ResourceBars:Refresh() end) end
    if playerCastHolder then
        guard("player cast bar", function()
            LayoutPlayerCastBar()
            ApplyPosition(playerCastHolder)
            UpdateCastBar(playerCastHolder.Cast, IsCastEnabled(playerCastHolder.Cast))
        end)
    end
    guard("player cast mode", UF.ApplyPlayerCastMode)
    guard("combat text", UF.CombatTextSync)
end

-- Show Player or Hide Player Frame while in party changed (Party frames' Edit Mode)
function UF:RefreshPartyHide()
    for _, unit in ipairs({ "player", "pet" }) do
        if frames[unit] then ApplyVisibility(frames[unit]) end
    end
    -- the pet's happiness moves to the party frames, or back
    if ns.PartyFrames and ns.PartyFrames.Refresh then ns.PartyFrames:Refresh() end
end

function UF:PLAYER_REGEN_ENABLED()
    if pendingLayout then UF.lastPendingWhy = pendingLayout self:Refresh() end
end

function UF:PLAYER_ENTERING_WORLD()
    for _, f in pairs(frames) do UpdateAll(f) end
    if playerCastHolder then UpdateCastBar(playerCastHolder.Cast, IsCastEnabled(playerCastHolder.Cast)) end
end

-- the client's portrait cache was rebuilt (after a loading screen): no unit event says so
function UF:PORTRAITS_UPDATED()
    for _, f in pairs(frames) do UpdatePortrait(f) end
end

function UF:Init()
    if self.initialized then return end
    local db = GetDb()
    if not db then return end
    UF.MigrateTextModes()
    UF.ApplyPalette()
    UF.MigrateOldFade()
    UF.MigrateGlows()
    -- a saved Hide Auras on the focus frame becomes Buffs and Debuffs Off
    local focusDb = db.units and db.units.focus
    if focusDb and focusDb.hideAuras then
        focusDb.buffs, focusDb.debuffs, focusDb.hideAuras = "OFF", "OFF", nil
    end
    -- the ring styles have their own default positions (a style switch reloads)
    if ns.UFRing and ns.UFRing.On() then
        for key, pos in pairs((ns.UFRing.DefaultPositions())) do DEFAULT_POSITIONS[key] = pos end
    end

    -- Simple Pet Frame off: the pet is a small frame of the style, with its ring and own default place
    if ns.UFRing and ns.UFRing.PetStyled() then
        local pet = UNITS.pet
        pet.portrait, pet.styledPet = true, true
        -- Threat Glow (Look): its own aggro, on the border and the ring
        pet.threatGlow, pet.indicators.threat = true, true
        DEFAULT_POSITIONS.pet = ns.UFRing.PetPosition()
    end
    -- A pet saved before it had auras, or swapped back in from a stored setup, has none of these
    local petDb = db.units.pet
    if petDb then
        petDb.buffs, petDb.debuffs = petDb.buffs or "OFF", petDb.debuffs or "OFF"
        petDb.auraSize, petDb.hideBuffs = petDb.auraSize or 12, petDb.hideBuffs or "OFF"
    end

    -- Simple "Target Of" off: the same, for target of target and target of focus
    if ns.UFRing and ns.UFRing.TargetOfStyled() then
        for _, unit in ipairs({ "targettarget", "focustarget" }) do
            local info = UNITS[unit]
            info.portrait, info.styledPet, info.noThreatGlow = true, true, true
            DEFAULT_POSITIONS[unit] = ns.UFRing.TargetOfPosition(unit)
        end
    end

    for _, unit in ipairs(UNIT_ORDER) do
        local udb = db.units[unit]
        if udb and udb.enabled then
            local f = CreateUnitFrame(unit)
            RegisterEditMode(f)
            if UNITS[unit].blizzard then
                for _, name in ipairs(UNITS[unit].blizzard) do
                    if name == "TargetFrame" and ns.IsGamepadUI() then KeepAsMenuOwner(name, f) else HardHide(name) end
                end
            end
        end
    end
    -- Player Cast Bar (its own switch in the settings): off, Blizzard's bar stays
    if db.playerCastbar and db.playerCastbar.enabled then
        local holder = CreatePlayerCastBar()
        LEM:AddFrame(holder, OnFrameMoved, DEFAULT_POSITIONS.playercastbar, holder.editModeName)
        LEM:AddFrameSettings(holder, BuildPlayerCastSettings())
        -- also the Gamepad UI's bar (Forever has no GamepadPlayerCastingBarFrame)
        HardHide("PlayerCastingBarFrame")
    end
    -- only a first draw of a cast already running (Refresh draws it again): its error is reported
    -- but can't stop the frames' layout below
    securecallfunction(UF.ApplyPlayerCastMode)
    HookExtras()
    if frames.player then InitFsrSpark(); UF.Gcd.Init() end
    self.initialized = true
    -- out of range fading on target, focus and pet (no event for their range); a new spellbook re-picks
    -- the spells it measures with
    C_Timer.NewTicker(0.2, UF.UpdateFrameRanges)
    local spells = CreateFrame("Frame")
    spells:RegisterEvent("SPELLS_CHANGED")
    spells:SetScript("OnEvent", function() UF.rangeKnown = nil end)
    -- nothing announces a unit going out of sight
    C_Timer.NewTicker(1, function()
        UF.UpdateAuraReach(frames.target)
        UF.UpdateAuraReach(frames.focus)
        UF.UpdateAuraReach(frames.pet)
    end)

    LEM:RegisterCallback("layout", function(layoutName)
        -- Forever Style's Scale, saved per layout (ProfileLayout.lua); in a fight LayoutFrame waits for its end
        local db = GetDb()
        if db and db.layouts and ns.ApplyLayoutPlateScale and ns.UFRing and ns.UFRing.PlateOn() then
            for unit, f in pairs(frames) do
                if ns.UFRing.PLATE_UNITS[unit] and ns.UFRing.Plate(f)
                    and ns.ApplyLayoutPlateScale(db.layouts, layoutName, unit .. "Scale", GetUnitDb(unit)) then
                    LayoutFrame(f); UpdateAll(f)
                end
            end
        end
        for _, f in pairs(frames) do ApplyPosition(f, layoutName) end
        if playerCastHolder then ApplyPosition(playerCastHolder, layoutName) end
    end)
    local function ShowPreview()
        -- (UpdateAll does the combo points and the happiness face too)
        for _, f in pairs(frames) do ApplyVisibility(f); f:SetAlpha(1); UpdateAll(f) end
        for _, f in pairs(frames) do LayoutAuras(f) end
        SetAuraPreview(true)
        SetCastPreview(true)
        UF.CombatTextSync()
        UpdateFsrSpark()
    end
    local function EndPreview()
        for _, f in pairs(frames) do ApplyVisibility(f); UpdateAll(f) end
        for _, f in pairs(frames) do LayoutAuras(f) end
        SetAuraPreview(false)
        SetCastPreview(false)
        UF.CombatTextSync()
        UpdateFsrSpark()
    end
    LEM:RegisterCallback("enter", ShowPreview)
    LEM:RegisterCallback("exit", EndPreview)
    -- a fight in Edit Mode ends the samples (ns.EditPreviewing), its end brings them back
    ns.OnEditFight(function() if ns.EditPreviewing() then ShowPreview() else EndPreview() end end)

    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PORTRAITS_UPDATED")

    self:Refresh()
    C_Timer.After(0, function() self:Refresh() end)
end
