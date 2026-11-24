local _, ns = ...
local L = ns.L

--------------------------------------------------
-- NAMEPLATES (Settings > Nameplates, off; a reload turns it on or off)
-- FlareUI's own plates, drawn on top of Blizzard's nameplate frames. Blizzard keeps its plate
-- (position, stacking, clicks, occlusion fading); only its unit frame goes invisible, and ours sits
-- on the plate in its place.
--
-- Safety net (plates that vanish until /reload are the classic failure of this kind of module):
--   * every plate, aura container and cast bar is built at login, out of combat, into a pool
--     (frames made on a nameplate in combat come out forbidden)
--   * a plate is checked after it is attached; anything wrong and Blizzard keeps its own plate for
--     that unit, so a unit never ends up with no plate at all
--   * a plate that leaves is detached at once; a sync pass every 2 s catches a unit swap that came
--     with no event, and a Blizzard unit frame handed out late
--   * another nameplate addon (by folder name, or one that took Blizzard's unit frame off its plate)
--     makes the module stand down
--   * /fui plates prints what the module sees
--
-- Secret values: health, class, casts, auras and names only ever go into Blizzard's widgets
-- (SetValue, SetText, SetTimerDuration, the "from boolean" helpers, colour curves, aura containers).
-- Threat between you and a nameplate is readable on Forever; when the client says it is hidden, the
-- plate keeps its usual colour. Inside instances friendly plates stay Blizzard's (they are forbidden
-- to addons there).
--------------------------------------------------

ns.Nameplates = ns.Nameplates or {}
local NP = ns.Nameplates
local D = {
    HEALTH = 1, MAXHEALTH = 2, HEALS = 4, ABSORB = 8, COLOR = 16, NAME = 32, LEVEL = 64,
    CAST = 128, RAID = 256, QUEST = 512, TARGET = 1024, FADE = 2048,
    MOUSEOVER = 4096, GROUP = 8192, ROLE = 16384, SPELLS = 32768,
}
local band, bor = bit.band, bit.bor
local healthBits = bor(D.HEALTH, D.MAXHEALTH)
local healBits = bor(D.MAXHEALTH, D.HEALS, D.ABSORB)
local healthOrHealBits = bor(healthBits, healBits)
local nameOrLevelBits = bor(D.NAME, D.LEVEL)
ns.modules["Nameplates"] = NP
LibStub("AceEvent-3.0"):Embed(NP)

--------------------------------------------------
-- 1. CONSTANTS
--------------------------------------------------
local pairs, ipairs, pcall, type, select = pairs, ipairs, pcall, type, select
local math_max, math_floor = math.max, math.floor
local CreateFrame, InCombatLockdown = CreateFrame, InCombatLockdown
local UF = ns.UnitFrames
local K = UF and UF.Kit
local BT = ns.BarText
local LSM = LibStub("LibSharedMedia-3.0")

-- When several state handlers can change the same widget in a flush, apply that
-- operation once, after the plate has its final state. Direct updates still apply it now.
local paint = {}
local function ApplyVisual(p, method)
    if paint.plate == p then
        paint[method] = true
    else
        NP[method](p, paint.draining and paint or nil)
    end
end

-- every tunable number in one table (the main chunk keeps few locals)
local C = {
    SHARED_VISUALS = { "ApplyScale", "PaintBorder", "PaintGlow", "UpdateFade" },
    POOL = 40,                -- Blizzard keeps 40 plates at most
    SYNC = 2,                 -- seconds between sync passes
    NAME_GAP = 2,             -- name above the bar
    LEVEL_GAP = 3,            -- level left of the bar
    AURA_GAP = 2,
    CAST_GAP = 0,             -- cast bar right under the bar's frame
    ELITE = 14,               -- elite / rare mark
    RAID = 18,                -- raid marker
    HIGHLIGHT = 0.18,         -- mouseover light
    HOVER_BORDER = 0.35,      -- mouseover: the border this much of the way to white
    TEXT_ROOM = 40,           -- what a slot of numbers takes beside the name
    -- Nameplate Colours: FlareUI's palette (muted, as the unit frames'); yours replace any of them
    -- (nameplates.palette "custom", nameplates.customColors), picked in the colour window
    -- (Settings/ColorPicker.lua "np"). Threat Safe (damage / healer) keeps the plate's own colour.
    COLORS = {
        hostile = { 0.87, 0.27, 0.27 }, neutral = { 0.93, 0.78, 0.25 }, friendly = { 0.30, 0.78, 0.30 },
        tapped = { 0.55, 0.55, 0.55 },
        holding = { 0.29, 0.69, 0.42 },   -- tank: you hold it
        losing  = { 0.95, 0.62, 0.20 },   -- tank: someone is close
        lost    = { 0.86, 0.22, 0.20 },   -- tank: it's on someone else
        offtank = { 0.56, 0.45, 0.86 },   -- tank: another tank has it
        gaining = { 0.95, 0.62, 0.20 },   -- damage / healer: you're above the tank
        aggro   = { 0.86, 0.22, 0.20 },   -- damage / healer: it's on you
        cast = { 0.80, 0.60, 0.36 }, channel = { 0.30, 0.65, 0.90 }, castNoInterrupt = { 0.55, 0.55, 0.55 },
        important = { 1.00, 0.82, 0.20 },
        target = { 1.00, 0.84, 0.42 },    -- your target's border: bright bronze
        heal = { 0.30, 0.90, 0.30 }, absorb = { 0.90, 0.90, 1.00 },
        -- Phase 2: mob types, focus, execute, your interrupt ready, group members
        boss = { 0.72, 0.25, 0.80 }, elite = { 0.90, 0.55, 0.20 }, caster = { 0.35, 0.55, 0.95 }, trivial = { 0.60, 0.60, 0.50 },
        -- (focus darker than the bright target colour, so the two stand apart)
        focus = { 0.62, 0.42, 0.10 }, targetGlow = { 1.00, 1.00, 1.00 }, execute = { 1.00, 0.95, 0.40 }, kickReady = { 0.30, 0.72, 0.36 }, group = { 0.45, 0.75, 1.00 }, raid = { 1.00, 0.50, 0.00 },
    },
    -- debuffs first in a row, crowd control alone on the right, buffs on the right above the name
    FILTERS = {
        cc = { "HARMFUL|CROWD_CONTROL" },
        -- Defensives: big defensives and the ones others put on the unit (shields, guardians)
        big = { "HELPFUL|BIG_DEFENSIVE" },
        external = { "HELPFUL|EXTERNAL_DEFENSIVE" },
    },
    -- Debuffs and Buffs: Off, All, or filters ticked as toggles ("mine,dispel"); each ticked one
    -- adds its word to the filter, so every one must match (AuraLanes)
    DEBUFF_SPEC = { exclusive = { "off", "all" }, tokens = { "mine", "dispel" }, empty = "all" },
    BUFF_SPEC = { exclusive = { "off", "all" }, tokens = { "purge", "important", "mine" }, empty = "all" },
    -- (dispel: the ones you can dispel)
    FILTER_WORDS = { mine = "|PLAYER", dispel = "|RAID", purge = "|RAID_PLAYER_DISPELLABLE", important = "|IMPORTANT" },
    SIDE_GAP = 1,
    QUEST_PAD = 0.3,          -- the empty share of the quest mark's art on each side of the "!"
    PULSE_PERIOD = 0.8,       -- the shared pulse: one rise and fall, in seconds
    PULSE_LOW = 0.25,         -- and its faintest
    AURA_LINES = 2,           -- debuffs and buffs: two lines each at most
    AGGRO_RGB = { 1, 0.2, 0.15 },      -- Aggro Flash
    WHITE = "Interface\\Buttons\\WHITE8x8",
    TARGETED_RGB = { 1, 0.15, 0.1 },   -- Flash When Targeted
    IMPORTANT_GLOW = 0.8,     -- Highlight Important Casts: its soft glow's strength
    IMPORTANT_SIZE = 7,       -- and its size (the plate glow's is GLOW_SIZE)
    ELITE_IN = 0.25,          -- Rare/Elite Icon: its centre this share of its size inside the top right corner
    -- spells that make you a tank: Defensive Stance, Righteous Fury
    DEFENSIVE_STANCE = 71, RIGHTEOUS_FURY = 25780,
    LEVEL_ATLAS = "ui-hud-nameplates-levelindicator",
    ELITE_GOLD = "nameplates-icon-elite-gold", ELITE_SILVER = "nameplates-icon-elite-silver",
    SHIELD_ATLAS = "nameplates-InterruptShield",
    QUEST_ATLAS = "QuestNormal", QUEST_FILE = "Interface\\GossipFrame\\AvailableQuestIcon",
    -- Execute Range on Auto: the class's own execute spell, by name (any rank), and where it works
    EXECUTE = { WARRIOR = { 5308, 0.2 }, PALADIN = { 24275, 0.2 } },
    -- Out of Range Opacity: spells by name (any rank answers), never "next swing" attacks (in range
    -- at any distance); any one in range counts. Cat and Bear Form fight in melee.
    RANGE = {
        WARRIOR = { 772, 100 }, ROGUE = { 1752, 2764 }, HUNTER = { 75, 2974 }, PALADIN = { 20271, 853 },
        PRIEST = { 585, 589 }, SHAMAN = { 403, 8042 }, MAGE = { 133, 116, 2136 }, WARLOCK = { 686, 348, 172 },
        DRUID = { 5176, 8921 }, DRUID_MELEE = { 1082, 779 },
    },
    MELEE_FORMS = { [1] = true, [5] = true, [8] = true },   -- Cat, Bear, Dire Bear (form IDs)
    RANGE_NAMES = {},         -- spell ID -> name, filled as NP.UpdateRange asks
    -- folder names of other nameplate addons: the module stands down while one is loaded (the
    -- runtime check in Claim catches the rest)
    OTHER_ADDONS = { "Plater", "Kui_Nameplates", "TidyPlates_ThreatPlates", "TidyPlates", "NeatPlates",
                     "BetterBlizzPlates", "EllesmereUINameplates", "nPlates", "DaylightUI_Nameplates" },
    -- Blizzard's nameplate CVars the Visibility tab shows (the game saves them itself)
    CVARS = { "nameplateShowAll", "nameplateShowEnemies", "nameplateShowEnemyMinions", "nameplateShowEnemyMinus",
              "nameplateShowFriendlyPlayers", "nameplateShowFriendlyNpcs" },
}
NP.C = C

-- Target Highlight arrows: Blizzard's own art, each with the way it points as drawn; turned to point
-- at the plate on each side (and down from the top)
C.ARROWS = {
    npe = { "NPE_ArrowRight", "right", L["Yellow"] },
    red = { "Soulbinds_Tree_ActivateArrow", "down", L["Red"] },
    npeGlow = { "NPE_ArrowRightGlow", "right", L["Orange"] },
    big = { "ui-journeys-delve-arrow-big-left", "left", L["Big"] },
}
C.ARROW_ORDER = { "npe", "red", "npeGlow", "big" }
C.ARROW_ANGLE = { right = 0, up = math.pi / 2, left = math.pi, down = -math.pi / 2 }
C.TARGET_GLOW = "Interface\\AddOns\\FlareUI\\Media\\Nameplates\\TargetGlow"
C.BG_CORNER = "Interface\\AddOns\\FlareUI\\Media\\Nameplates\\BgCorner"
C.DISC_GLOW = "Interface\\AddOns\\FlareUI\\Media\\Nameplates\\DiscGlow"   -- (round; the disc's edge at 0.6 of its radius)
-- the glow, in the bar's own colour (NP.BarColor): eight plain pieces (four rounded corners, four straight edges) cut from TargetGlow
-- (64 px: the plate's edge 16 px in, a soft fade outside it, corners rounded over the next 12 px),
-- GLOW_SIZE px wide, starting GLOW_IN px under the plate's edge. (The game's nine-slice drawing
-- squashes the fade into a hard band on Forever, so it isn't used.)
C.GLOW_SIZE, C.GLOW_IN, C.GLOW_ALPHA = 11, 1, 0.25
C.GLOW_ART, C.GLOW_FADE, C.GLOW_CORNER = 64, 16, 28   -- (the art's size, its fade, its corner pieces)

local hidden = CreateFrame("Frame")   -- where spare plates wait
hidden:Hide()
local pool = {}           -- every plate we built
local spare = {}          -- plates not on a game plate
local byPlate = {}        -- game plate -> our plate
local stats = { claimed = 0, given = 0, forbidden = 0, secret = 0, failed = 0, lastError = nil }
NP.stats = stats
local state = { role = "damage", tanks = {}, inGroup = false, mouseover = nil }

local function DB() return ns.db and ns.db.profile and ns.db.profile.nameplates end
local settings, pendingSettings   -- applied to live plates, and the selected profile waiting for combat to end
-- During a profile switch in combat only the settings preview uses the new snapshot.
local function SettingsFor(preview)
    return preview and pendingSettings or settings
end
local function SharedSettings(preview)
    local cache = SettingsFor(preview)
    return cache and cache.shared or DB()
end

-- PLATE TYPES: enemyPlayer, enemyNpc, friendlyPlayer, friendlyNpc and minor (pets, totems, guardians
-- and minor mobs).
-- Each type keeps its own value of these settings (nameplates.types[kind]); every other setting is
-- shared. A type's view reads its own value first, then the shared one.
-- (open PvP is big on Forever, so players and NPCs are split again on both sides;
-- Minions merged into Minor, one type for pets, totems, guardians and minor mobs)
C.KINDS = { "enemyPlayer", "enemyNpc", "friendlyPlayer", "friendlyNpc", "minor" }
C.FRIENDLY = { friendlyPlayer = true, friendlyNpc = true }
C.TYPE_KEYS = {
    plate = true, width = true, height = true, level = true, levelSide = true, barText = true, hideTextAtFull = true,
    healthColor = true, castbar = true, castHeight = true, debuffs = true, debuffSize = true, debuffMax = true,
    buffs = true, buffSize = true, buffMax = true, hideBuffs = true, cc = true, ccSize = true, defensives = true, clickThrough = true,
    -- (every row on the Style tab is the type's own) the look rows and Name Only Size
    texture = true, border = true, bgOpacity = true, smoothBars = true, edgeGlow = true, damageTrail = true, nameOnlySize = true,
    -- (every row on the Plate, Extras, Cast Bar and Auras tabs is the type's own;
    -- Targeting, Visibility and Fonts stay shared. Role stays shared: it is yours, not the plate's;
    -- so do the colours, picked in their own window)
    rarityIcon = true, combo = true, questIcon = true, questProgress = true,
    threat = true, threatGlow = true, aggroFlash = true, threatScale = true, threatPercent = true,
    execute = true, colorBoss = true, colorElite = true, colorCaster = true, colorTrivial = true, mobTypesWhere = true,
    groupColor = true, raidColor = true,
    castIcon = true, castTimer = true, castTarget = true, kickReady = true, castKickMark = true, castTargetedFlash = true, castImportant = true,
    -- the Auras and Aura Positions sections
    auraStyle = true, auraSwipe = true, auraTimer = true, auraTimerColor = true, auraRows = true,
    nameAbove = true, nameOnlyFull = true, castGlow = true,
    -- the cast bar's own look; names by class on a full plate, guild colour, titles
    castTexture = true, castBorder = true, nameClassColor = true, guildColor = true, showTitles = true, showGuild = true,
}
-- these were one shared value in older versions: a preset reads the profile's old shared value, so every
-- type keeps the look it had; a type's Custom keeps its own from then on
C.WAS_SHARED = { texture = true, border = true, bgOpacity = true, smoothBars = true, edgeGlow = true, damageTrail = true,
    rarityIcon = true, questProgress = true, threat = true, threatGlow = true, aggroFlash = true, threatScale = true, threatPercent = true,
    execute = true, colorBoss = true, colorElite = true, colorCaster = true, colorTrivial = true, mobTypesWhere = true,
    groupColor = true, raidColor = true,
    castIcon = true, castTimer = true, castTarget = true, kickReady = true, castKickMark = true, castTargetedFlash = true, castImportant = true,
    auraSwipe = true, auraTimer = true, auraTimerColor = true }
-- PRESETS: each type picks one (types[kind].preset); a preset is a few values over the Core.lua
-- defaults. Changing any of the type's settings turns it into Custom: the preset's values are copied
-- into types[kind].custom, and the change goes there. Custom stays saved while another preset is
-- picked; editing that other preset later starts a new Custom from it.
C.PRESETS = {
    full = {},
    compact = { width = 100, height = 10, level = "off", debuffs = "off", buffs = "off", cc = false },
    tiny = { width = 100, height = 10, level = "off", debuffs = "off", buffs = "off", cc = false, castbar = false },
    name = { plate = "name", castbar = false, debuffs = "off", buffs = "off", cc = false, level = "off" },
}
C.PRESET_ORDER = { "full", "compact", "tiny", "name", "custom" }
C.DEFAULT_PRESET = { enemyPlayer = "full", enemyNpc = "full", friendlyPlayer = "name", friendlyNpc = "name", minor = "full",
    -- (not a type of its own: Name Only While Unattackable lays an enemy NPC you can't attack out
    -- with the Name Only preset, NP.Peaceful)
    peaceful = "name" }
-- EACH TYPE'S OWN DEFAULTS: what Full and the other presets build on. Both
-- enemy types and both friendly types share Enemy's; the friendly ones start on Name Only, its
-- name at 140%. Minor (minions too) has its own.
C.ENEMY_BASE = {
    width = 150, height = 15, level = "box", levelSide = "left", healthColor = "class",
    barText = { health = { left = { firstname = 1 }, middle = {}, right = { percent = 1 } } },
    hideTextAtFull = true, texture = "FlareUI Dark", border = "FlareUI Frames",
    smoothBars = true, edgeGlow = true, damageTrail = true, rarityIcon = false, questProgress = false,
    execute = "auto", raidColor = false,
    castbar = true, castHeight = 12, castIcon = false, castTarget = false,
    kickReady = true, castKickMark = true, castTargetedFlash = true,
    debuffs = "mine", debuffSize = 18, debuffMax = 8, buffs = "off", buffSize = 18, buffMax = 3,
    cc = false, ccSize = 24, defensives = false, clickThrough = false,
}
C.TYPE_BASE = {
    enemyPlayer = C.ENEMY_BASE, enemyNpc = C.ENEMY_BASE, peaceful = C.ENEMY_BASE,   -- (peaceful: NP.Peaceful)
    friendlyPlayer = setmetatable({ nameOnlySize = 140 }, { __index = C.ENEMY_BASE }),
    friendlyNpc = setmetatable({ nameOnlySize = 140 }, { __index = C.ENEMY_BASE }),
    minor = {
        width = 100, height = 13, level = "off", levelSide = "left",   -- (Colour By: Core's default)
        hideTextAtFull = false, texture = "FlareUI Dark", border = "FlareUI Frames",
        smoothBars = true, edgeGlow = true, damageTrail = true, rarityIcon = false, questProgress = false,
        execute = "auto", raidColor = false, combo = false,
        castbar = false, castHeight = 10, castIcon = false, castTarget = false,
        kickReady = true, castKickMark = true, castTargetedFlash = true,
        debuffs = "off", debuffSize = 20, debuffMax = 6, buffs = "off", buffSize = 16, buffMax = 3, hideBuffs = "OFF",
        cc = false, ccSize = 28, defensives = false, clickThrough = false,
    },
}
local function Defaults()
    return ns.defaults and ns.defaults.profile and ns.defaults.profile.nameplates or {}
end
local function Copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = Copy(x) end
    return t
end
-- a preset's value of a per-type setting: the preset's own, then a value the profile saved when the
-- setting was shared, then the type's own default (C.TYPE_BASE), then Core.lua's
function NP.PresetValue(preset, key, kind)
    local p = C.PRESETS[preset] or C.PRESETS.full
    local v = p[key]
    if v ~= nil then return v end
    if C.WAS_SHARED[key] then
        local db = DB()
        if db and rawget(db, key) ~= nil then return rawget(db, key) end
    end
    local base = kind and C.TYPE_BASE[kind]
    if base and base[key] ~= nil then return base[key] end
    return Defaults()[key]
end
local function Own(kind)
    local db = DB()
    return db and db.types and db.types[kind]
end
function NP.PresetOf(kind)
    local own = Own(kind)
    local preset = own and own.preset
    if preset == "custom" and not own.custom then preset = nil end
    return preset or C.DEFAULT_PRESET[kind] or "full"
end
local typeViews = {}
function NP.TypeDB(kind, forPlate, preview)
    kind = kind or "enemyNpc"
    local cache = forPlate and SettingsFor(preview)
    if cache and cache.types[kind] then return cache.types[kind] end
    local view = typeViews[kind]
    if not view then
        view = setmetatable({ kind = kind }, { __index = function(_, key)
            local db = DB()
            if not db then return nil end
            if C.TYPE_KEYS[key] then
                local preset = NP.PresetOf(kind)
                if preset == "custom" then
                    local v = Own(kind).custom[key]
                    if v ~= nil then return v end
                    return NP.PresetValue("full", key, kind)
                end
                return NP.PresetValue(preset, key, kind)
            end
            return db[key]
        end })
        typeViews[kind] = view
    end
    return view
end
-- All plates with the same look share one resolved table. Keep its identity across refreshes:
-- parked plates can still hold it, and a reset can remove previously saved options.
local function CacheType(kind, cache)
    if not cache then return end
    local view = cache.types[kind] or {}
    for key in pairs(view) do view[key] = nil end
    for key, value in pairs(cache.shared) do view[key] = value end
    local saved = NP.TypeDB(kind)
    for key in pairs(C.TYPE_KEYS) do view[key] = Copy(saved[key]) end
    view.kind = kind
    cache.types[kind] = view
end

local function CombatTypes(value)
    local set = {}
    if type(value) == "string" then
        for kind in value:gmatch("[^,]+") do
            if kind ~= "none" then set[kind] = true end
        end
    end
    return set
end

local function CacheSettings(cache)
    local db = DB()
    if not db then return end
    local shared = {}
    -- Include inherited defaults as well as optional keys such as obscuredAlpha and customColors.
    for key in pairs(Defaults()) do
        if key ~= "types" and rawget(db, key) == nil then shared[key] = Copy(db[key]) end
    end
    for key, value in pairs(db) do
        if key ~= "types" then shared[key] = Copy(value) end
    end
    cache = cache or { types = {} }
    cache.shared = shared
    cache.combatTypes = CombatTypes(shared.combatPlates)
    cache.colors = C.COLORS
    if shared.palette == "custom" and type(shared.customColors) == "table" then
        local colors = setmetatable({}, { __index = C.COLORS })
        for key, rgb in pairs(shared.customColors) do
            if type(rgb) == "table" and rgb[1] then colors[key] = rgb end
        end
        cache.colors = colors
    end
    for _, kind in ipairs(C.KINDS) do CacheType(kind, cache) end
    CacheType("peaceful", cache)
    return cache
end
-- a type's own table, made when first written
function NP.TypeStore(kind)
    local db = DB()
    if not db then return nil end
    db.types = db.types or {}
    db.types[kind] = db.types[kind] or {}
    return db.types[kind]
end
-- pick a preset; Custom brings back the saved one (or starts one from the preset in use)
function NP.SetPreset(kind, preset)
    local own = NP.TypeStore(kind)
    if not own then return end
    if preset == "custom" and not own.custom then
        local from = NP.PresetOf(kind)
        own.custom = {}
        for key in pairs(C.TYPE_KEYS) do own.custom[key] = Copy(NP.PresetValue(from, key, kind)) end
    end
    own.preset = preset
    CacheType(kind, SettingsFor(true))
end
-- change one of a type's settings: a preset becomes a new Custom first
function NP.TypeSet(kind, key, value)
    local own = NP.TypeStore(kind)
    if not own then return end
    local preset = NP.PresetOf(kind)
    if preset ~= "custom" then
        -- (a Reset that changes nothing keeps the preset)
        if NP.SameValue(value, NP.PresetValue(preset, key, kind)) then return end
        own.custom = {}
        for k in pairs(C.TYPE_KEYS) do own.custom[k] = Copy(NP.PresetValue(preset, k, kind)) end
        own.preset = "custom"
    end
    own.custom[key] = Copy(value)
    CacheType(kind, SettingsFor(true))
end
-- types saved before presets (their own values over the shared ones) become their preset when
-- nothing differs, else Custom with what they showed
local function Same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do if not Same(v, b[k]) then return false end end
    for k, v in pairs(b) do if a[k] == nil and v ~= nil then return false end end
    return true
end
NP.SameValue = Same
function NP.MigratePresets()
    local db = DB()
    if not db or db.presetsV1 then return end
    db.presetsV1 = true
    db.types = db.types or {}
    local function MigrateType(kind)
        local own = db.types[kind] or {}
        -- A partial import can already contain the new preset without the migration flag.
        if C.PRESETS[own.preset] or (own.preset == "custom" and type(own.custom) == "table") then return end
        local base = C.DEFAULT_PRESET[kind]
        local custom, differs = {}, false
        for key in pairs(C.TYPE_KEYS) do
            local v = own[key]
            if v == nil then v = C.PRESETS[base][key] end
            -- (only a value the profile saved: a default read here would hide the type's own default)
            if v == nil then v = rawget(db, key) end
            if v == nil then v = NP.PresetValue(base, key, kind) end
            custom[key] = Copy(v)
            if not Same(v, NP.PresetValue(base, key, kind)) then differs = true end
        end
        local fresh = { preset = base }
        if differs then fresh.preset, fresh.custom = "custom", custom end
        db.types[kind] = fresh
    end
    for _, kind in ipairs(C.KINDS) do MigrateType(kind) end
end
local function PDB(p) return p.tdb or NP.TypeDB("enemyNpc", true) end

function NP.Palette()
    local db = DB()
    return db and db.palette == "custom" and "custom" or "flareui"
end
-- a colour { r, g, b }: yours on the Custom palette, else FlareUI's
function NP.Color(key, preview)
    local cache = SettingsFor(preview)
    if cache then return cache.colors[key] or C.COLORS.hostile end
    local db = DB()
    local own = db and db.palette == "custom" and db.customColors and db.customColors[key]
    if type(own) == "table" and own[1] then return own end
    return C.COLORS[key] or C.COLORS.hostile
end

--------------------------------------------------
-- 2. LOOK HELPERS
--------------------------------------------------
-- The bar texture and border: FlareUI's by default (FlareUI Thick; "FlareUI Frames" is the border shown as FlareUI Thin)
C.DEFAULT_TEXTURE, C.DEFAULT_BORDER = "FlareUI Light", "FlareUI Thick"
local function Look(db)
    local texture = (db.texture and db.texture ~= "") and db.texture or C.DEFAULT_TEXTURE
    local border = (db.border and db.border ~= "") and db.border or C.DEFAULT_BORDER
    return nil, texture, border
end

local function BorderFile(name)
    if not name or name == "None" or not LSM:IsValid("border", name) then return nil end
    return LSM:Fetch("border", name)
end

local function ApplyFontTo(fs, font)
    if K and K.ApplyFont then K.ApplyFont(fs, font) end
end

-- the colour of a reaction (1..8), or nil when it can't be read
local function ReactionRGB(unit)
    local reaction = UnitReaction(unit, "player")
    if not canaccessvalue(reaction) or type(reaction) ~= "number" then return nil end
    local c = NP.Color(reaction <= 3 and "hostile" or reaction == 4 and "neutral" or "friendly")
    return c[1], c[2], c[3]
end

-- Pulses on one shared clock (Flash When Targeted, Highlight Important Casts, Threat Glow): every
-- pulse on screen rises and falls together, on every plate. Play / Stop / IsPlaying as an animation.
-- one shared clock for every pulse: the wave is worked out once a frame and set
-- on each playing frame that shows (it was one OnUpdate per frame); the clock stops with none playing.
-- every plate of the pool keeps its important glow playing from its layout, so the clock
-- rarely stops: which frames show is looked up five times a second, not every frame (a quarter of all
-- FlareUI's time before, with no plate on screen)
NP.Pulse = { set = {}, live = {}, wait = 0, EVERY = 0.2, driver = CreateFrame("Frame") }
NP.Pulse.driver:Hide()
NP.Pulse.driver:SetScript("OnUpdate", function(_, elapsed)
    local P = NP.Pulse
    local live = P.live
    P.wait = P.wait - (elapsed or 0)
    if P.wait <= 0 then
        P.wait = P.EVERY
        wipe(live)
        for f in pairs(P.set) do
            if f:IsVisible() then live[#live + 1] = f end
        end
    end
    if not live[1] then return end
    local wave = 0.5 + 0.5 * math.cos((GetTime() % C.PULSE_PERIOD) / C.PULSE_PERIOD * 2 * math.pi)
    local a = C.PULSE_LOW + (1 - C.PULSE_LOW) * wave
    for i = 1, #live do live[i]:SetAlpha(a) end
end)
function NP.ClockPulse(frame)
    local pulse = {}
    function pulse:Play()
        NP.Pulse.set[frame] = true
        NP.Pulse.wait = 0
        NP.Pulse.driver:Show()
        self.on = true
    end
    function pulse:Stop()
        NP.Pulse.set[frame] = nil
        NP.Pulse.wait = 0   -- (looked up again before the next alpha)
        frame:SetAlpha(1)
        self.on = false
        if not next(NP.Pulse.set) then NP.Pulse.driver:Hide() end
    end
    function pulse:IsPlaying() return self.on end
    return pulse
end

-- A pulsing border: the frame's own border again, in a colour, laid exactly over it and added to it,
-- with the soft plate glow round it. Highlight Important Casts (on the cast bar: shown from the game's
-- own secret answer on the outer frame's alpha) and Threat Glow (on the plate). NP.Layout gives it the
-- border's art and size; the pulse runs on the inner frame.
function NP.ImportantGlow(cast)
    local g = CreateFrame("Frame", nil, cast)
    g:SetFrameLevel(cast:GetFrameLevel() + 7)
    g.edge = CreateFrame("Frame", nil, g, "BackdropTemplate")
    g.edge:SetAllPoints(g)
    -- (a soft glow round it for weight, the plate glow's art, pulsing with it)
    g.soft = CreateFrame("Frame", nil, g.edge)
    g.soft:SetFrameLevel(math_max(0, cast:GetFrameLevel() - 2))
    g.soft.parts = {}
    for i = 1, 8 do
        local t = g.soft:CreateTexture(nil, "BACKGROUND")
        t:SetTexture(C.TARGET_GLOW)
        t:SetBlendMode("ADD")
        g.soft.parts[i] = t
    end
    g.pulse = NP.ClockPulse(g.edge)
    -- (played by the layout only with Highlight Important Casts on: NP.Layout)
    return g
end
function NP.PaintImportantGlow(g, c)
    if not g then return end
    g.color = c
    if g.edge:GetBackdrop() then
        g.edge:SetBackdropBorderColor(c[1], c[2], c[3], 1)
        -- (added over the border, not laid on it: brighter than the colour alone; once per backdrop,
        -- NP.LayoutPulseBorder clears the mark)
        if not g.edge.addBlend then
            g.edge.addBlend = true
            for _, region in ipairs({ g.edge:GetRegions() }) do
                if region.SetBlendMode then region:SetBlendMode("ADD") end
            end
        end
    end
    for _, t in ipairs(g.soft.parts) do t:SetVertexColor(c[1], c[2], c[3], C.IMPORTANT_GLOW) end
end
-- its border: the frame's own (border, a BackdropTemplate frame), or a 1 px line round "to" without one
function NP.LayoutPulseBorder(g, border, to, edgeFile)
    g:ClearAllPoints()
    g.edge.addBlend = nil
    if edgeFile then
        g:SetAllPoints(border)
        g.edge:SetBackdrop(border:GetBackdrop())
    else
        g:SetPoint("TOPLEFT", to, "TOPLEFT", -1, 1)
        g:SetPoint("BOTTOMRIGHT", to, "BOTTOMRIGHT", 1, -1)
        g.edge:SetBackdrop({ edgeFile = C.WHITE, edgeSize = 1 })
    end
end

--------------------------------------------------
-- 3. THE PLATE (one builder for the live plates and the settings preview)
--------------------------------------------------
local function NewText(parent, layer)
    if UF and UF.NewText then return UF.NewText(parent, layer) end
    local fs = parent:CreateFontString(nil, layer or "OVERLAY", "GameFontHighlightSmall")
    return fs
end

-- sample: the settings preview's plate (no aura containers, no events)
function NP.Build(parent, sample)
    local p = { sample = sample }
    -- the holder carries Out of Range Opacity (a secret range answer sets its alpha unread), the root
    -- Non-Target Opacity and Target Scale: two alphas that multiply without Lua maths
    p.holder = CreateFrame("Frame", nil, parent)
    local root = CreateFrame("Frame", nil, p.holder)
    root:SetSize(1, 1)
    root:Hide()
    p.root = root

    -- the frame round the bar: background, border and target colour
    local box = CreateFrame("Frame", nil, root, "BackdropTemplate")
    box:SetFrameLevel(root:GetFrameLevel() + 1)
    p.box = box
    local border = CreateFrame("Frame", nil, box, "BackdropTemplate")
    border:SetFrameLevel(box:GetFrameLevel() + 5)
    border:SetAllPoints(box)
    p.border = border
    -- a thin line for the target when the border is None
    local outline = CreateFrame("Frame", nil, box, "BackdropTemplate")
    outline:SetFrameLevel(box:GetFrameLevel() + 6)
    outline:SetPoint("TOPLEFT", box, "TOPLEFT", -1, 1)
    outline:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 1, -1)
    outline:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    outline:Hide()
    p.outline = outline

    local health = CreateFrame("StatusBar", nil, box)
    health:SetFrameLevel(box:GetFrameLevel() + 1)
    health:SetMinMaxValues(0, 1)
    health:SetValue(1)
    health.bg = health:CreateTexture(nil, "BACKGROUND")
    health.bg:SetAllPoints()
    p.health = health

    -- incoming heals and absorbs, after the health, clipped to the bar
    local clip = CreateFrame("Frame", nil, health)
    clip:SetAllPoints(health)
    clip:SetFrameLevel(health:GetFrameLevel() + 2)
    -- Bar Effects: Damage Trail (in its own clip of the bar's empty part, under the heals) and Edge
    -- Glow, both the unit frames' own (UnitFrames.lua)
    if UF and UF.CreateDamageTrail then p.trail = UF.CreateDamageTrail(health) end
    clip:SetClipsChildren(true)
    local fill = health:GetStatusBarTexture()
    local function Overlay(color)
        local bar = CreateFrame("StatusBar", nil, clip)
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        bar:SetStatusBarColor(color[1], color[2], color[3], color[4] or 1)
        return bar
    end
    p.heal = Overlay({ 1, 1, 1 })
    p.absorb = Overlay({ 1, 1, 1 })
    p.fill = fill
    if not sample and CreateUnitHealPredictionCalculator then
        local ok, calc = pcall(CreateUnitHealPredictionCalculator)
        if ok and calc then
            p.calc = calc
            -- The client owns the defaults. Its mode getters are public even when the amounts are secret.
            local damageModes = Enum and Enum.UnitDamageAbsorbClampMode
            if damageModes and calc.GetDamageAbsorbClampMode then
                local known, mode = pcall(calc.GetDamageAbsorbClampMode, calc)
                p.shieldIgnoresHeals = known and mode ~= nil and (mode == damageModes.MissingHealthWithoutIncomingHeals
                    or mode == damageModes.MaximumHealth)
            end
            local maximumModes = Enum and Enum.UnitMaximumHealthMode
            if maximumModes and calc.GetMaximumHealthMode then
                local known, mode = pcall(calc.GetMaximumHealthMode, calc)
                p.healIgnoresShields = known and mode ~= nil and mode == maximumModes.Default
            end
        end
    end

    local overlay = CreateFrame("Frame", nil, box)
    overlay:SetAllPoints(root)
    overlay:SetFrameLevel(box:GetFrameLevel() + 8)
    p.overlay = overlay

    p.highlight = health:CreateTexture(nil, "OVERLAY")
    p.highlight:SetAllPoints(health)
    p.highlight:SetColorTexture(1, 1, 1, C.HIGHLIGHT)
    p.highlight:SetBlendMode("ADD")
    p.highlight:Hide()
    -- TARGET HIGHLIGHT: a tint over your target's bar, a soft glow round its plate and Blizzard-style
    -- arrows pointing at it (NP.UpdateTargetLook)
    p.targetTint = health:CreateTexture(nil, "ARTWORK", nil, 3)
    p.targetTint:SetBlendMode("ADD")
    p.targetTint:Hide()
    -- (one round the bar, one round the level box, a round one for the level disc)
    local function Glow(n, file)
        local g = CreateFrame("Frame", nil, root)
        g:SetFrameLevel(math_max(0, box:GetFrameLevel() - 1))
        g.parts = {}
        for i = 1, n do
            local t = g:CreateTexture(nil, "BACKGROUND")
            t:SetTexture(file)
            g.parts[i] = t
        end
        g:Hide()
        return g
    end
    p.targetGlow = Glow(8, C.TARGET_GLOW)
    p.levelGlow = Glow(8, C.TARGET_GLOW)
    p.discGlow = Glow(1, C.DISC_GLOW)
    p.discGlow.parts[1]:SetAllPoints()
    p.arrows = {}
    for _, side in ipairs({ "left", "right", "top" }) do
        local a = CreateFrame("Frame", nil, root)
        -- (under the overlay: the quest mark, raid marker and auras draw above the arrows)
        a:SetFrameLevel(box:GetFrameLevel() + 7)
        a.tex = a:CreateTexture(nil, "OVERLAY")
        a.tex:SetAllPoints()
        -- (it moves 3 px: snapped to whole pixels it went in steps)
        a.tex:SetSnapToPixelGrid(false)
        a.tex:SetTexelSnappingBias(0)
        -- a small bounce towards the plate
        a.bounce = a:CreateAnimationGroup()
        a.bounce:SetLooping("BOUNCE")
        a.move = a.bounce:CreateAnimation("Translation")
        a.move:SetDuration(0.45)
        a.move:SetSmoothing("IN_OUT")
        a:Hide()
        p.arrows[side] = a
    end
    -- Aggro Flash: one quick flash over the plate's whole inside when threat turns against you, under
    -- the border, corners cut as the border's (NP.Layout; the preview repeats it)
    p.flash = CreateFrame("Frame", nil, box)
    p.flash:SetFrameLevel(box:GetFrameLevel() + 4)
    p.flash:SetAllPoints(box)
    p.flash:SetAlpha(0)
    p.flashAnim = p.flash:CreateAnimationGroup()
    if sample then p.flashAnim:SetLooping("REPEAT") end
    local up = p.flashAnim:CreateAnimation("Alpha")
    up:SetFromAlpha(0) up:SetToAlpha(0.7) up:SetDuration(0.12) up:SetOrder(1)
    local down = p.flashAnim:CreateAnimation("Alpha")
    down:SetFromAlpha(0.7) down:SetToAlpha(0) down:SetDuration(0.5) down:SetOrder(2)
    if sample then
        local rest = p.flashAnim:CreateAnimation("Alpha")
        rest:SetFromAlpha(0) rest:SetToAlpha(0) rest:SetDuration(0.8) rest:SetOrder(3)
    end
    -- Threat Glow: the plate's border pulsing in the threat colour, with a soft glow round it
    p.threatFx = NP.ImportantGlow(box)
    p.threatFx:Hide()

    -- Execute Range: the fill in the execute colour below the threshold (its alpha from a curve on
    -- the health percent, so it works on secret health), and a thin mark where the range starts
    p.execTint = health:CreateTexture(nil, "ARTWORK", nil, 2)
    p.execTint:SetAllPoints(health:GetStatusBarTexture())
    p.execTint:SetAlpha(0)
    p.execMark = health:CreateTexture(nil, "OVERLAY", nil, 1)
    p.execMark:SetColorTexture(1, 1, 1, 0.7)
    p.execMark:SetWidth(1)
    p.execMark:Hide()

    p.name = NewText(overlay)
    p.name:SetWordWrap(false)
    -- an NPC's title ("General Goods") under a Name Only name (NP.UpdateTitle)
    p.npcTitle = NewText(overlay)
    p.npcTitle:SetWordWrap(false)
    p.npcTitle:SetJustifyH("CENTER")
    p.npcTitle:Hide()
    -- a player's guild, under the title or the name (NP.UpdateGuild)
    p.guildName = NewText(overlay)
    p.guildName:SetWordWrap(false)
    p.guildName:SetJustifyH("CENTER")
    p.guildName:Hide()
    -- Quest Marks: the quest "!" and what's left ("3/8") at the name line's right end
    p.quest = overlay:CreateTexture(nil, "OVERLAY", nil, 2)
    p.quest:Hide()
    p.questText = NewText(overlay)
    p.questText:SetJustifyH("RIGHT")
    p.questText:Hide()
    -- the level box: the plate's background and border in a square (NP.LayoutLevel)
    p.levelFrame = CreateFrame("Frame", nil, root, "BackdropTemplate")
    p.levelFrame:SetFrameLevel(box:GetFrameLevel())
    p.levelBorder = CreateFrame("Frame", nil, p.levelFrame, "BackdropTemplate")
    p.levelBorder:SetAllPoints(p.levelFrame)
    p.levelBorder:SetFrameLevel(box:GetFrameLevel() + 5)
    -- the threat box: Threat Percentage when there is no level box (NP.LayoutThreat), in its look
    p.threatBox = CreateFrame("Frame", nil, root, "BackdropTemplate")
    p.threatBox:SetFrameLevel(box:GetFrameLevel())
    p.threatBoxBorder = CreateFrame("Frame", nil, p.threatBox, "BackdropTemplate")
    p.threatBoxBorder:SetAllPoints(p.threatBox)
    p.threatBoxBorder:SetFrameLevel(box:GetFrameLevel() + 5)
    p.threatBox:Hide()
    p.levelArt = overlay:CreateTexture(nil, "ARTWORK")
    p.level = NewText(overlay)
    p.level:SetJustifyH("CENTER")
    p.elite = overlay:CreateTexture(nil, "OVERLAY", nil, 2)
    p.raid = overlay:CreateTexture(nil, "OVERLAY", nil, 3)
    p.raid:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    -- (under the plate, centred: combo points hang from it; NP.PlaceBelow)
    p.below = CreateFrame("Frame", nil, root)
    p.below:SetHeight(1)
    p.raid:Hide()

    -- health text: Left, Middle and Right (Bar Text slots), in a holder so Hide at Full fades them all
    p.textHolder = CreateFrame("Frame", nil, overlay)
    p.textHolder:SetAllPoints(health)
    p.texts = {}
    for _, slot in ipairs(BT and BT.SLOTS or { "left", "middle", "right" }) do
        local fs = NewText(p.textHolder)
        fs:SetWordWrap(false)
        p.texts[slot] = fs
    end
    -- Threat Percentage: outside the holder, so Hide at Full doesn't fade it (NP.UpdateThreatText)
    p.threatText = NewText(overlay)
    p.threatText:SetWordWrap(false)
    p.threatText:Hide()

    -- the cast bar: the unit frames' (its interrupted flash and timer binding come with it)
    if K and K.CreateCastBar then
        p.castAnchor = CreateFrame("Frame", nil, root)
        p.cast = K.CreateCastBar(root, nil, true)
        local cast = p.cast
        -- (the shield on a frame above the bar's border)
        cast.shieldFrame = CreateFrame("Frame", nil, cast)
        cast.shieldFrame:SetAllPoints(cast)
        cast.shieldFrame:SetFrameLevel(cast:GetFrameLevel() + 8)
        cast.shield = cast.shieldFrame:CreateTexture(nil, "OVERLAY", nil, 2)
        if C_Texture.GetAtlasInfo(C.SHIELD_ATLAS) then cast.shield:SetAtlas(C.SHIELD_ATLAS) end
        cast.target = NewText(cast)
        cast.target:SetWordWrap(false)
        -- Highlight Important Casts: a quiet proc-style glow round the bar (NP.ImportantGlow)
        cast.important = NP.ImportantGlow(cast)
        cast.important:SetAlpha(0)
        -- Flash When Targeted: a red pulse round the cast bar while the spell is aimed at you (its frame's
        -- alpha comes from the game's own answer, unread)
        -- (the whole inside of the frame, icon too, under the border; its corners cut as the border's:
        -- NP.Layout)
        cast.targeted = CreateFrame("Frame", nil, cast)
        cast.targeted:SetFrameLevel(cast:GetFrameLevel() + 1)
        cast.targeted.fill = CreateFrame("Frame", nil, cast.targeted)
        cast.targeted.fill:SetAllPoints()
        cast.targetedPulse = NP.ClockPulse(cast.targeted.fill)
        cast.targeted:SetAlpha(0)
        -- Kick Ready Mark: where on the cast your interrupt will be ready. Two invisible bars laid on
        -- the cast's timeline: the first fills to now, the second starts at its end and fills for the
        -- time your interrupt still needs; the mark sits at the second's end. The game places both
        -- from its own (hidden) times: no Lua maths on them.
        cast.kickClip = CreateFrame("Frame", nil, cast)
        cast.kickClip:SetAllPoints(cast)
        cast.kickClip:SetClipsChildren(true)
        cast.kickClip:SetFrameLevel(cast:GetFrameLevel() + 5)
        local function Hidden(parent)
            local bar = CreateFrame("StatusBar", nil, parent)
            bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
            bar:GetStatusBarTexture():SetAlpha(0)
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(0)
            return bar
        end
        cast.kickNow = Hidden(cast.kickClip)
        cast.kickNow:SetAllPoints(cast)
        cast.kickWait = Hidden(cast.kickClip)
        cast.kickSpark = cast.kickClip:CreateTexture(nil, "OVERLAY", nil, 4)
        cast.kickSpark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
        cast.kickSpark:SetBlendMode("ADD")
        cast.kickClip:Hide()
        -- a casting plate stays at full opacity (Non-Target Opacity)
        if not sample then
            local function Fade() ApplyVisual(p, "UpdateFade") NP.PlaceBelow(p) end
            cast:HookScript("OnShow", Fade)
            cast:HookScript("OnHide", Fade)
        end
    end

    -- aura containers (live plates only: the preview draws plain icons)
    if not sample and K and K.HasAuraSupport and K.HasAuraSupport() then
        p.auras = {}
        for _, place in ipairs({ "debuffs", "buffs", "cc", "defensives" }) do
            local ok, container = pcall(CreateFrame, "AuraContainer", nil, root, "CustomAuraContainerTemplate")
            if ok and container then
                container:SetFrameLevel(root:GetFrameLevel() + 12)
                if ns.AuraPolicy and ns.AuraPolicy.ApplyPolicy then ns.AuraPolicy.ApplyPolicy(container, "none") end
                p.auras[place] = { container = container }
            end
        end
    elseif sample then
        p.sampleIcons = {}
    end

    -- one event frame per plate: unit events for its own unit only
    if not sample then
        p.events = CreateFrame("Frame")
        p.events.plate = p
    end
    return p
end

--------------------------------------------------
-- 4. LAYOUT (on settings change; never on a health tick)
--------------------------------------------------
-- What Blizzard's own plates show by default (its Info Display setting's default: health value and/or
-- percent), read from the game's stored default in its own bit layout (CvarUtil.lua)
function NP.BlizzardHealthDefault()
    if C.healthDefault then return C.healthDefault end
    local set = {}
    local ok, value = pcall(C_CVar.GetCVarDefault, "nameplateInfoDisplay")
    local T = Enum.NamePlateInfoDisplay
    if ok and type(value) == "string" and T and bit then
        local function Has(index)
            index = index - 1
            local byte = value:byte(2 + math_floor(index / 6))
            return byte ~= nil and bit.band(byte, bit.lshift(1, index % 6)) ~= 0
        end
        local n = 0
        if Has(T.CurrentHealthValue) then n = n + 1; set.value = n end
        if Has(T.CurrentHealthPercent) then n = n + 1; set.percent = n end
    else
        set.percent = 1
    end
    C.healthDefault = set
    return set
end

-- Bar text slots, as the unit frames' (BarText.lua): the saved picks, or Left = First Name and Right =
-- Blizzard's default health text. Plates always show the first name only.
function NP.TextSlots(db)
    local stored = db.barText and db.barText.health
    local out = {}
    for _, slot in ipairs(BT.SLOTS) do
        local set = stored and stored[slot]
        if not set then
            set = (slot == "left" and { firstname = 1 }) or (slot == "right" and NP.BlizzardHealthDefault()) or {}
        end
        -- (Full Name stays Full Name: in older versions it was read as First Name, so plates never showed
        -- surnames; NP.UpdateName reads p.nameFull)
        local copy = {}
        for k, v in pairs(set) do copy[k] = v end
        out[slot] = copy
    end
    return out
end

-- Level: Box (a square in the plate's own background and border) or Disc (the unit frames' level
-- disc), each as tall as the plate, beside the bar on the Level Side; Follow Name puts the level in
-- front of the name. (An old "ring" pick reads as Disc.)
C.LEVEL_DISC = "UI-HUD-UnitFrame-SmallCircle"
C.DISC_SCALE = 1.08   -- the disc a little taller than the plate
C.DISC_INNER = 0.32   -- (the share cut off each side of the disc art for the level box's inside)
C.PLATE_EDGE = 12     -- the border's width on plates (thinner than the 16 of buttons: plates are often drawn larger)
function NP.LayoutLevel(p, db, boxH)
    local mode = db.level or "box"
    if mode == "ring" then mode = "disc" end
    p.levelSide = db.levelSide == "right" and "right" or "left"
    p.levelFollow = mode == "name"
    p.levelShown = mode == "box" or mode == "disc"
    for _, r in ipairs({ p.levelArt, p.levelFrame, p.level }) do r:ClearAllPoints() r:Hide() end
    p.levelAnchor = nil
    if not p.levelShown then return end
    ApplyFontTo(p.level, db.levelFont)
    local right = p.levelSide == "right"
    local holder
    if mode == "box" then
        holder = p.levelFrame
        holder:SetSize(boxH, boxH)
        local bgIn = p.bgInset or 0
        NP.Background(holder, bgIn, p.bgCut or bgIn, (db.bgOpacity or 90) / 100)
        -- (inside the border: the middle of the level disc's art, its dark shaded inside without
        -- the round frame, so the box and the disc look alike behind the number)
        if not p.levelInner then p.levelInner = holder:CreateTexture(nil, "BACKGROUND", nil, -7) end
        local info = C_Texture.GetAtlasInfo(C.LEVEL_DISC)
        if info and info.file and info.leftTexCoord then
            local l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
            local f = C.DISC_INNER
            p.levelInner:SetTexture(info.file)
            p.levelInner:SetTexCoord(l + (r - l) * f, r - (r - l) * f, t + (b - t) * f, b - (b - t) * f)
            p.levelInner:ClearAllPoints()
            local inIn = p.edgeFile and bgIn or 1
            p.levelInner:SetPoint("TOPLEFT", holder, "TOPLEFT", inIn, -inIn)
            p.levelInner:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -inIn, inIn)
            p.levelInner:Show()
        else
            p.levelInner:Hide()
        end
        if p.edgeFile then
            p.levelBorder:SetBackdrop({ edgeFile = p.edgeFile, edgeSize = p.edgeSize })
            local c = ns.BORDER_COLOR
            p.levelBorder:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
            p.levelBorder:Show()
        else
            p.levelBorder:Hide()
        end
        holder:Show()
    else
        holder = p.levelArt
        if C_Texture.GetAtlasInfo(C.LEVEL_DISC) then holder:SetAtlas(C.LEVEL_DISC) else holder:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask") end
        holder:SetSize(boxH * C.DISC_SCALE, boxH * C.DISC_SCALE)
        holder:Show()
    end
    local gap = holder == p.levelArt and -1 or 1   -- (the disc sits 2 px closer than the box)
    holder:SetPoint(right and "LEFT" or "RIGHT", p.box, right and "RIGHT" or "LEFT", right and gap or -gap, 0)
    p.level:SetPoint("CENTER", holder, "CENTER", 0, 0)
    p.level:Show()
    p.levelAnchor = holder
end

-- THREAT PERCENTAGE'S PLACE: never over the name. A box in the level box's look,
-- shown while there is threat. (#145 Zackarias) its own box always, never in the
-- level's place: on the side away from the level box or disc, or on the right with none. It fits
-- "100%" in the level's font. The quest icon, marker and Crowd Control on that side move out while it
-- shows. Not on Name Only plates.
C.THREAT_BOX_PAD = 6   -- room round the text in the box
function NP.LayoutThreat(p, db)
    local fs, box = p.threatText, p.threatBox
    fs:ClearAllPoints()
    box:ClearAllPoints()
    box:Hide()
    p.threatBoxShown = false
    p.threatInLevel = false
    p.threatBoxOn = db.threatPercent and db.threatPercent ~= "off" and not p.nameOnly and not p.hiddenPlate or false
    p.threatSide = (p.levelAnchor and p.levelSide == "right") and "left" or "right"
    if p.threatBoxOn then
        local boxH = p.boxH or db.height
        ApplyFontTo(fs, db.levelFont)
        -- as wide as "100%" in that font (never narrower than a square)
        fs:SetText("100%")
        local textW = fs:GetStringWidth()
        if not (canaccessvalue(textW) and type(textW) == "number" and textW > 0) then textW = boxH * 1.7 end
        box:SetSize(math_max(boxH, math_floor(textW + C.THREAT_BOX_PAD + 0.5)), boxH)
        fs:SetText("")
        if p.threatSide == "left" then
            box:SetPoint("RIGHT", p.box, "LEFT", -1, 0)
        else
            box:SetPoint("LEFT", p.box, "RIGHT", 1, 0)
        end
        local bgIn = p.bgInset or 0
        NP.Background(box, bgIn, p.bgCut or bgIn, (db.bgOpacity or 90) / 100)
        if p.edgeFile then
            p.threatBoxBorder:SetBackdrop({ edgeFile = p.edgeFile, edgeSize = p.edgeSize })
            local c = ns.BORDER_COLOR
            p.threatBoxBorder:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
            p.threatBoxBorder:Show()
        else
            p.threatBoxBorder:Hide()
        end
        fs:SetPoint("CENTER", box, "CENTER", 0, 0)
    end
    -- (a plate laid out again while held: DoesItDie's bar follows, NP.DieProxy)
    if p.gamePlate then pcall(NP.DieProxy, p.gamePlate, p) end
end

-- Debuffs and buffs share the row above the plate, half each; one alone takes the whole width
-- AURA POSITIONS (per type, saved as auraRows): with both rows on, One Line (the
-- default: side by side, half the width each), Buffs on Top or Debuffs on Top (each its own line, the
-- whole width, one line at most, one above the other). Returns "buffsTop" / "debuffsTop", or nil.
function NP.AuraStack(db)
    if db.debuffs == "off" or db.buffs == "off" then return nil end
    local v = db.auraRows
    if v == "buffsTop" or v == "debuffsTop" then return v end
end
function NP.AuraRowWidth(p, db)
    local w = p.plateW or db.width
    if db.debuffs ~= "off" and db.buffs ~= "off" and not NP.AuraStack(db) then return math_floor((w - C.AURA_GAP) / 2) end
    return w
end
-- where a row above the plate starts: buffs "left", debuffs "right", the one shown alone (or each of
-- two stacked lines) "center" (nil: not a row above the plate)
function NP.AuraRowSide(db, place)
    if place ~= "debuffs" and place ~= "buffs" then return nil end
    if db.debuffs == "off" or db.buffs == "off" or NP.AuraStack(db) then return "center" end
    return place == "buffs" and "left" or "right"
end
-- how many icons of a size fit one line of it; each takes two lines at most (C.AURA_LINES), one
-- when the rows are stacked
function NP.AuraPerLine(p, db, size)
    return math_max(1, math_floor((NP.AuraRowWidth(p, db) + C.AURA_GAP) / (size + C.AURA_GAP)))
end
function NP.AuraCount(p, db, size, max)
    local lines = NP.AuraStack(db) and 1 or C.AURA_LINES
    return math_max(1, math.min(max or 1, lines * NP.AuraPerLine(p, db, size)))
end

-- The marks beside the plate (the bar and its level box or disc), SIDE_GAP from it as the level box:
--   the quest mark on the side away from the level (the right with no level beside the bar), its
--   progress outside it; crowd control on the right and defensives on the left, the same distance
--   out, past the quest mark on its side; the raid marker on the left, past the defensives.
-- Target Highlight arrows sit right against the plate; everything here draws above them.
function NP.PlaceSides(p, iconOn, textOn)
    -- (the threat box sits on the side away from the level: NP.LayoutThreat)
    local threatShown = p.threatBoxShown
    local leftOf = (p.levelAnchor and p.levelSide ~= "right") and p.levelAnchor
        or (threatShown and p.threatSide == "left" and p.threatBox) or p.box
    p.rightOf = (p.levelAnchor and p.levelSide == "right") and p.levelAnchor
        or (threatShown and p.threatSide == "right" and p.threatBox) or p.box
    p.leftOf = leftOf
    if p.questie then pcall(NP.FixQuestie, p) end
    local gap = C.SIDE_GAP
    p.quest:ClearAllPoints()
    p.questText:ClearAllPoints()
    p.raid:ClearAllPoints()
    local questRight = not (p.levelAnchor and p.levelSide == "right")
    p.questSide = questRight and "right" or "left"
    local outer = { left = leftOf, right = p.rightOf }
    -- (placed even while hidden: whatever shows them later finds them in place)
    -- (the progress beside the icon, or in its place with Objective Icon off)
    if iconOn == nil then iconOn, textOn = p.quest:IsShown(), p.questText:IsShown() end
    if questRight then
        p.quest:SetPoint("LEFT", p.rightOf, "RIGHT", gap, 0)
        if iconOn then p.questText:SetPoint("LEFT", p.quest, "RIGHT", 1, 0) else p.questText:SetPoint("LEFT", p.rightOf, "RIGHT", gap + 1, 0) end
    else
        p.quest:SetPoint("RIGHT", leftOf, "LEFT", -gap, 0)
        if iconOn then p.questText:SetPoint("RIGHT", p.quest, "LEFT", -1, 0) else p.questText:SetPoint("RIGHT", leftOf, "LEFT", -gap - 1, 0) end
    end
    p.questText:SetJustifyH(questRight and "LEFT" or "RIGHT")
    if textOn then outer[p.questSide] = p.questText
    elseif iconOn then outer[p.questSide] = p.quest end
    -- (the quest art is mostly empty round its mark: what sits past it comes in by that much)
    local pad = { left = 0, right = 0 }
    if outer[p.questSide] == p.quest then pad[p.questSide] = p.questPad or 0 end
    -- The raid marker: as the quest icon, on the other side of the plate (quest icon
    -- right, marker left; level box on the right moves the quest icon left, the marker right), the
    -- same gap from the plate. The aura row on its side (Defensives left, Crowd Control right) goes past
    -- it. Name Only: over the name (the box is a whole plate wide round a short name).
    local markerSide = (not p.nameOnly) and (questRight and "left" or "right") or nil
    if p.nameOnly then
        p.raid:SetPoint("BOTTOM", p.name, "TOP", 0, 2)
    elseif markerSide == "left" then
        p.raid:SetPoint("RIGHT", leftOf, "LEFT", -gap, 0)
    else
        p.raid:SetPoint("LEFT", p.rightOf, "RIGHT", gap, 0)
    end
    local auras = p.auras
    if auras then
        if auras.cc then
            auras.cc.container:ClearAllPoints()
            if markerSide == "right" then
                auras.cc.container:SetPoint("LEFT", p.raid, "RIGHT", gap, 0)
            else
                auras.cc.container:SetPoint("LEFT", outer.right, "RIGHT", gap - pad.right, 0)
            end
        end
        if auras.defensives then
            auras.defensives.container:ClearAllPoints()
            if markerSide == "left" then
                auras.defensives.container:SetPoint("RIGHT", p.raid, "LEFT", -gap, 0)
            else
                auras.defensives.container:SetPoint("RIGHT", outer.left, "LEFT", -gap + pad.left, 0)
            end
        end
    end
    p.sideLeft, p.sideRight, p.sidePad = outer.left, outer.right, pad
    local arrows = p.arrows
    if arrows then
        local left, right, top = arrows.left, arrows.right, arrows.top
        left:ClearAllPoints()
        left:SetPoint("RIGHT", leftOf, "LEFT", -1, 0)
        right:ClearAllPoints()
        right:SetPoint("LEFT", p.rightOf, "RIGHT", 1, 0)
        top:ClearAllPoints()
        top:SetPoint("BOTTOM", p.box, "TOP", 0, p.arrowTop or 2)
        for _, a in pairs(arrows) do a:SetSize(a.w or 16, a.h or 16) end
    end
end

local function RequestSideLayout(p, iconOn, textOn)
    if paint.plate ~= p then
        NP.PlaceSides(p, iconOn, textOn)
        return
    end
    paint.PlaceSides = true
    if iconOn ~= nil then paint.questIcon, paint.questText = iconOn, textOn end
end

-- Your target stands out: its border in the target colour (Border), a tint over its bar (Bar Colour),
-- a soft glow round it (Outer Glow) and the arrows. Everything else draws as it was.
-- MOUSEOVER HIGHLIGHT (Targeting, shared): which parts light up on the plate under
-- the mouse: Border (a lighter border, NP.PaintBorder), Bar (p.highlight's light) and Outer Glow (the
-- target's glow). Border and Bar by default; saved as a list, "none" for nothing.
function NP.HoverParts()
    local db = DB()
    local v = db and db.mouseoverHighlight
    if type(v) ~= "string" then v = "border,bar" end
    local parts = {}
    for token in v:gmatch("[^,]+") do parts[token] = true end
    return parts
end
function NP.UpdateTargetLook(p)
    local db = PDB(p)
    local plain = not p.nameOnly and not p.hiddenPlate and not p.unitHidden
    local on = p.targetShown and plain
    -- (the plate under the mouse takes the glow too, with Mouseover Highlight's Outer Glow)
    local glow = (on and db.targetGlow) or (plain and not p.sample and state.mouseover == p and NP.HoverParts().glow) or false
    p.targetTint:SetShown(on and db.targetBarColor and true or false)
    p.targetGlow:SetShown(glow and true or false)
    -- (the level box or disc glows with it: they and the bar read as one plate)
    p.levelGlow:SetShown(glow and p.levelFrame:IsShown() and true or false)
    p.discGlow:SetShown(glow and p.levelAnchor == p.levelArt and p.levelArt:IsShown() and true or false)
    if glow then ApplyVisual(p, "PaintGlow") end
    local art = C.ARROWS[db.targetArrows or "off"]
    local where = db.targetArrowSide or "both"
    local want = { left = where == "both" or where == "left", right = where == "both" or where == "right", top = where == "top" }
    -- Layout positions even the hidden arrows. Selecting a target only toggles them.
    for side, a in pairs(p.arrows) do
        local show = (on or (p.sample and p.sampleTarget)) and art and want[side] or false
        a:SetShown(show and true or false)
        if show then
            if not a.bounce:IsPlaying() then a.bounce:Play() end
        else
            a.bounce:Stop()
        end
    end
end

-- The soft glow's eight pieces round a frame (to), gw x gh in size: four rounded corners, four
-- straight edges between them (a side shorter than two corners gets none)
function NP.PlaceGlow(glowFrame, to, gw, gh, glowSize)
    local size, inset = glowSize or C.GLOW_SIZE, C.GLOW_IN   -- (glowSize: a smaller glow, Highlight Important Casts)
    local k = size / C.GLOW_FADE                      -- (screen px per art px)
    local c = C.GLOW_CORNER / C.GLOW_ART               -- (a corner piece's share of the art)
    local f = C.GLOW_FADE / C.GLOW_ART                 -- (an edge piece's depth in the art)
    local out = size - inset                           -- (how far the glow reaches past the edge)
    local inner = (C.GLOW_CORNER - C.GLOW_FADE) * k + inset   -- (how far a corner reaches in)
    do
        glowFrame:ClearAllPoints()
        glowFrame:SetAllPoints(to)
        local t = glowFrame.parts
        for i = 1, 8 do t[i]:ClearAllPoints() end
        -- corners (each holds the whole rounded curve)
        local cs = C.GLOW_CORNER * k
        t[1]:SetSize(cs, cs) t[1]:SetPoint("TOPLEFT", to, "TOPLEFT", -out, out) t[1]:SetTexCoord(0, c, 0, c)
        t[2]:SetSize(cs, cs) t[2]:SetPoint("TOPRIGHT", to, "TOPRIGHT", out, out) t[2]:SetTexCoord(1 - c, 1, 0, c)
        t[3]:SetSize(cs, cs) t[3]:SetPoint("BOTTOMLEFT", to, "BOTTOMLEFT", -out, -out) t[3]:SetTexCoord(0, c, 1 - c, 1)
        t[4]:SetSize(cs, cs) t[4]:SetPoint("BOTTOMRIGHT", to, "BOTTOMRIGHT", out, -out) t[4]:SetTexCoord(1 - c, 1, 1 - c, 1)
        -- straight edges between them (a side shorter than two corners gets none)
        t[5]:SetPoint("BOTTOMLEFT", to, "TOPLEFT", inner, -inset) t[5]:SetPoint("BOTTOMRIGHT", to, "TOPRIGHT", -inner, -inset)
        t[5]:SetHeight(size) t[5]:SetTexCoord(c, 1 - c, 0, f)
        t[6]:SetPoint("TOPLEFT", to, "BOTTOMLEFT", inner, inset) t[6]:SetPoint("TOPRIGHT", to, "BOTTOMRIGHT", -inner, inset)
        t[6]:SetHeight(size) t[6]:SetTexCoord(c, 1 - c, 1 - f, 1)
        t[7]:SetPoint("TOPRIGHT", to, "TOPLEFT", inset, -inner) t[7]:SetPoint("BOTTOMRIGHT", to, "BOTTOMLEFT", inset, inner)
        t[7]:SetWidth(size) t[7]:SetTexCoord(0, f, c, 1 - c)
        t[8]:SetPoint("TOPLEFT", to, "TOPRIGHT", -inset, -inner) t[8]:SetPoint("BOTTOMLEFT", to, "BOTTOMRIGHT", -inset, inner)
        t[8]:SetWidth(size) t[8]:SetTexCoord(1 - f, 1, c, 1 - c)
        t[5]:SetShown(gw > 2 * inner) t[6]:SetShown(gw > 2 * inner)
        t[7]:SetShown(gh > 2 * inner) t[8]:SetShown(gh > 2 * inner)
    end
end

-- the highlight parts' look, at layout (the arrows' art turned to point at the plate)
function NP.LayoutTargetLook(p, db, boxH, aurasUp)
    local c = NP.Color("target", p.sample)
    p.targetTint:ClearAllPoints()
    p.targetTint:SetAllPoints(p.fill)
    p.targetTint:SetColorTexture(c[1], c[2], c[3], 0.3)
    p.targetGlow:ClearAllPoints()
    -- (a glow in its own colour behind the plate: the plate hides its middle, so only a soft edge
    -- about 3 px wide shows round the bar and round the level box)
    local lw, lh = p.levelFrame:GetSize()
    NP.PlaceGlow(p.targetGlow, p.box, db.width + boxH - db.height, boxH)
    NP.PlaceGlow(p.levelGlow, p.levelFrame, lw, lh)
    -- the disc's glow: round, centred on the disc (its circle is about the plate's height across)
    p.discGlow:ClearAllPoints()
    p.discGlow:SetPoint("CENTER", p.levelArt, "CENTER", 0, 0)
    p.discGlow:SetSize(boxH * C.DISC_SCALE / 0.6, boxH * C.DISC_SCALE / 0.6)
    p.arrowSize = math_max(12, math_floor(boxH * 1.2 + 0.5))
    p.arrowTop = aurasUp and (db.debuffSize + 2 * C.AURA_GAP + 2) or 2
    local art = C.ARROWS[db.targetArrows or "off"]
    local POINT = { left = 0, right = math.pi, top = -math.pi / 2 }   -- (where each side's arrow points)
    local MOVE = { left = { 3, 0 }, right = { -3, 0 }, top = { 0, -3 } }
    -- each arrow's frame takes the art's own shape, turned (no empty square round a narrow arrow),
    -- p.arrowSize across the way it points
    local info = art and C_Texture.GetAtlasInfo(art[1])
    local aw, ah = info and info.width or 16, info and info.height or 16
    local horizontal = art and (art[2] == "left" or art[2] == "right")
    local along, across = horizontal and aw or ah, horizontal and ah or aw
    local k = p.arrowSize / math_max(1, across)
    for side, a in pairs(p.arrows) do
        if art then
            a.tex:SetAtlas(art[1])
            a.tex:SetRotation(POINT[side] - C.ARROW_ANGLE[art[2]])
        end
        -- (the frame is the turned art's footprint: the art turns inside it without stretching)
        if side == "top" then a.w, a.h = p.arrowSize, along * k else a.w, a.h = along * k, p.arrowSize end
        a.move:SetOffset(MOVE[side][1], MOVE[side][2])
    end
end

-- Under the plate, centred: what hangs below it (combo points). It moves below the cast bar while
-- one shows.
function NP.PlaceBelow(p)
    local under = (p.cast and p.cast:IsShown()) and p.cast or p.box
    p.below:ClearAllPoints()
    p.below:SetPoint("TOPLEFT", under, "BOTTOMLEFT", 0, -1)
    p.below:SetPoint("TOPRIGHT", p.box, "BOTTOMRIGHT", 0, -1)
end

-- The Auras section (per type, as every Auras tab row): Aura Icon Shape, Aura Swipe,
-- Aura Timer and Timer Colour, the unit frames' four, saved on the nameplates' own (auraStyle,
-- auraSwipe, auraTimer, auraTimerColor). Defaults are the look the plates had: square, both, none.
local function AuraLook(size, isDebuff, db)
    local look = ns.AuraLook and ns.AuraLook.ForUnit(size, isDebuff, false, db.auraStyle or "square", nil,
        db.auraTimer or "none", "target", { swipe = db.auraSwipe or "both", timerColor = db.auraTimerColor ~= false })
    -- the debuff's type icon is for what you could dispel: not on an enemy's plate
    if look and not C.FRIENDLY[db.kind] then look.noTypeIcon = true end
    return look
end
NP.AuraLook = AuraLook
-- the higher of two stacked rows (NP.AuraStack) sits this far further up: the lower row's line
function NP.AuraLift(db, place)
    local stack = NP.AuraStack(db)
    if not stack then return 0 end
    local top = stack == "buffsTop" and "buffs" or "debuffs"
    if place ~= top then return 0 end
    local lowerIsDebuff = top == "buffs"
    local size = lowerIsDebuff and db.debuffSize or db.buffSize
    local look = AuraLook(size, lowerIsDebuff, db)
    return (look and look.cellHeight or size) + C.AURA_GAP
end

-- the lanes of each aura place, with Aura Filters' Hide / Show lists for "nameplates"
-- a filter string: base and the words of the ticked toggles (each word once), then rest
function NP.FilterFor(base, set, tokens, rest)
    local out, seen = base, {}
    for _, token in ipairs(tokens) do
        if set[token] then
            for word in C.FILTER_WORDS[token]:gmatch("[^|]+") do
                if not seen[word] then seen[word] = true out = out .. "|" .. word end
            end
        end
    end
    return out .. (rest or "")
end
local function AuraLanes(db)
    local lanes = {}
    local CS = ns.Conditions
    if db.debuffs ~= "off" then
        local set = CS.Set(db.debuffs, C.DEBUFF_SPEC)
        local tokens = C.DEBUFF_SPEC.tokens
        lanes[#lanes + 1] = { key = "debuffs", kind = "debuffs", place = "debuffs", isDebuff = true, policy = "none",
                              filters = { NP.FilterFor("HARMFUL", set, tokens, "|INCLUDE_NAME_PLATE_ONLY|!CROWD_CONTROL"),
                                          NP.FilterFor("HARMFUL", set, tokens) } }
    end
    if db.buffs ~= "off" then
        local set = CS.Set(db.buffs, C.BUFF_SPEC)
        lanes[#lanes + 1] = { key = "buffs", kind = "buffs", place = "buffs", isDebuff = false, policy = "none",
                              filters = { NP.FilterFor("HELPFUL", set, C.BUFF_SPEC.tokens) }, stealable = set.purge or nil,
                              -- Hide Buffs: as the unit frames' (Blizzard's longest full duration)
                              candidates = ns.AuraPolicy and ns.AuraPolicy.HideBuffs(db.hideBuffs, false) or nil }
    end
    if db.defensives then
        lanes[#lanes + 1] = { key = "big", kind = "buffs", place = "defensives", isDebuff = false, policy = "none", filters = C.FILTERS.big }
        lanes[#lanes + 1] = { key = "external", kind = "buffs", place = "defensives", isDebuff = false, policy = "none",
                              filters = C.FILTERS.external, joinPrevious = true }
    end
    if db.cc then
        lanes[#lanes + 1] = { key = "cc", kind = "debuffs", place = "cc", isDebuff = true, policy = "none", filters = C.FILTERS.cc }
    end
    for _, lane in ipairs(lanes) do lane.filter = lane.filters[1] end
    if ns.AuraPolicy and ns.AuraPolicy.ApplyHidden then lanes = ns.AuraPolicy.ApplyHidden(lanes, "nameplates") end
    -- an always-show row sits in its row's place, with that row's fallbacks
    for _, lane in ipairs(lanes) do
        if not lane.filters then lane.filters = { lane.filter } end
    end
    return lanes
end

-- WHOSE AURAS (a new plate cost about a millisecond, so a big pull was one long frame). Giving a
-- row (an aura container) its unit makes the game read that unit's auras. So only rows the type uses get one,
-- and when several plates arrive at once their rows follow over the next frames, AURAS_A_FRAME plates each. A
-- plate is asked for its own unit then, so one let go meanwhile is skipped; a row still on an earlier unit is
-- cleared before the plate shows.
C.AURAS_A_FRAME = 2
NP.AuraQueue = { list = {}, driver = CreateFrame("Frame") }
NP.AuraQueue.driver:Hide()
NP.AuraQueue.driver:SetScript("OnUpdate", function(self)
    local list = NP.AuraQueue.list
    for _ = 1, C.AURAS_A_FRAME do
        local p = table.remove(list, 1)
        if not p then break end
        p.aurasQueued = nil
        NP.SetAuraUnits(p)
    end
    if not list[1] then self:Hide() end
end)
-- every row of a plate on the plate's unit now, or on none
function NP.SetAuraUnits(p)
    if not p.auras then return end
    local unit = not (p.hiddenPlate or p.unitHidden) and p.unit or nil
    for _, entry in pairs(p.auras) do
        local want = entry.used and unit or "none"
        if entry.unit ~= want then
            entry.unit = want
            pcall(entry.container.SetUnit, entry.container, want)
        end
    end
end
-- a plate just claimed: its rows now, or after the plates before it
function NP.QueueAuras(p)
    if not p.auras or p.aurasQueued then return end
    p.aurasQueued = true
    local queue = NP.AuraQueue
    queue.list[#queue.list + 1] = p
    queue.driver:Show()
end
function NP.ClearAuras(p)
    if not p.auras then return end
    if p.aurasQueued then
        p.aurasQueued = nil
        local list = NP.AuraQueue.list
        for i = #list, 1, -1 do if list[i] == p then table.remove(list, i) end end
    end
    for _, entry in pairs(p.auras) do
        if entry.unit ~= "none" then
            entry.unit = "none"
            pcall(entry.container.SetUnit, entry.container, "none")
        end
    end
end

local function LayoutAuras(p, db)
    if not p.auras then return end
    local lanes = AuraLanes(db)
    local byPlace = { debuffs = {}, buffs = {}, cc = {}, defensives = {} }
    for _, lane in ipairs(lanes) do
        local list = byPlace[lane.place]
        if list then list[#list + 1] = lane end
    end
    local sortMethod, sortDirection = ns.AuraOrder.Options("default", false, true)
    for place, entry in pairs(p.auras) do
        local container = entry.container
        local list = byPlace[place]
        ns.AuraGroups.Begin(entry)
        local size = (place == "cc" or place == "defensives") and db.ccSize or (place == "buffs" and db.buffSize or db.debuffSize)
        local max = (place == "cc" and 1) or (place == "defensives" and 2) or NP.AuraCount(p, db, size, place == "buffs" and db.buffMax or db.debuffMax)
        for index, lane in ipairs(list) do
            local look = AuraLook(size, lane.isDebuff, db)
            if look and lane.stealable then look.stealable = true end
            local key
            for _, filter in ipairs(lane.filters) do
                key = ns.AuraGroups.Add(container, entry, lane.key, ns.AuraGroups.Sig(size, lane.isDebuff, look, filter, lane.hiddenStamp,
                        lane.candidates and lane.candidates.maxDuration), filter, {
                    maxFrameCount = max,
                    candidateFilters = lane.candidates,
                    sortMethod = sortMethod, sortDirection = sortDirection,
                    initializeFrame = function(button) K.InitAuraButton(button, size, lane.isDebuff, "target", nil, false, look) end,
                    layout = {
                        elementWidth = size, elementHeight = look and look.cellHeight or size,
                        elementSpacing = C.AURA_GAP, lineSpacing = C.AURA_GAP,
                        groupSpacing = C.AURA_GAP, groupLineSpacing = C.AURA_GAP,
                        layoutIndex = index, forceNewLine = false,
                    },
                })
                if key then break end   -- (a filter word this client doesn't know: the plainer one)
            end
        end
        ns.AuraGroups.Finish(container, entry)
        entry.used = #list > 0
        -- above the plate, as the unit frames: buffs from the left, debuffs from the right; one alone
        -- centred, as Blizzard's (the container takes its icons' size, so its middle is theirs)
        local row = NP.AuraRowSide(db, place)
        if row then
            container:ClearAllPoints()
            local point = (row == "left" and "BOTTOMLEFT") or (row == "right" and "BOTTOMRIGHT") or "BOTTOM"
            container:SetPoint(point, p.box, (row == "left" and "TOPLEFT") or (row == "right" and "TOPRIGHT") or "TOP", 0,
                C.AURA_GAP + NP.AuraLift(db, place) + (p.nameAboveLift or 0))
        end
        -- (crowd control and defensives beside the plate: NP.PlaceSides)
        pcall(container.SetFlowLayoutAxis, container, AnchorUtil.FlowLayoutAxis.Horizontal)
        local side = (place == "cc" and "LEFT") or (place == "defensives" and "RIGHT") or (row == "right" and "BOTTOMRIGHT") or "BOTTOMLEFT"
        pcall(container.SetFlowLayoutAnchorPoint, container, side)
        pcall(container.SetFlowLayoutGrowthDirection, container,
            (place == "defensives" or row == "right") and AnchorUtil.FlowDirection.Left or AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Up)
        -- debuffs and buffs share the plate's width; one alone takes all of it
        local line = (place == "debuffs" or place == "buffs") and NP.AuraRowWidth(p, db) or db.width
        pcall(container.SetFlowLayoutMaximumLineSize, container, math_max(size, line))
        pcall(container.SetFlowLayoutPadding, container, 0, 0, 0, 0)
        local on = #list > 0
        pcall(container.SetEnabled, container, on)
        container:SetShown(on)
    end
end

-- A plate's (or level box's) dark background, bgIn px inside the frame, its corners cut on a slant
-- that ends cut px from the frame's edge (no cut when cut <= bgIn). Seven pieces: a middle column,
-- two side strips and four slanted corners (BgCorner, flipped per corner)
C.BG_CORNERS = {
    { "TOPLEFT", 1, -1, 0, 1, 0, 1 }, { "TOPRIGHT", -1, -1, 1, 0, 0, 1 },
    { "BOTTOMLEFT", 1, 1, 0, 1, 1, 0 }, { "BOTTOMRIGHT", -1, 1, 1, 0, 1, 0 },
}
function NP.Background(f, bgIn, cut, alpha, rgb, blend)
    local t = f.bgParts
    if not t then
        t = {}
        for i = 1, 7 do
            t[i] = f:CreateTexture(nil, "BACKGROUND", nil, -8)
            t[i]:SetTexture(i <= 3 and "Interface\\Buttons\\WHITE8x8" or C.BG_CORNER)
        end
        f.bgParts = t
    end
    -- (rgb, blend: Flash When Targeted's red, added over the bar)
    local r, g, b = 0, 0, 0
    if rgb then r, g, b = rgb[1], rgb[2], rgb[3] end
    for i = 1, 7 do
        t[i]:ClearAllPoints()
        t[i]:SetVertexColor(r, g, b, alpha)
        if blend then t[i]:SetBlendMode(blend) end
    end
    local s = cut - bgIn
    if s < 1 then
        t[1]:SetPoint("TOPLEFT", f, "TOPLEFT", bgIn, -bgIn)
        t[1]:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -bgIn, bgIn)
        t[1]:Show()
        for i = 2, 7 do t[i]:Hide() end
        return
    end
    t[1]:SetPoint("TOPLEFT", f, "TOPLEFT", cut, -bgIn)
    t[1]:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -cut, bgIn)
    t[2]:SetPoint("TOPLEFT", f, "TOPLEFT", bgIn, -cut)
    t[2]:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", cut, cut)
    t[3]:SetPoint("TOPLEFT", f, "TOPRIGHT", -cut, -cut)
    t[3]:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -bgIn, cut)
    for i, c in ipairs(C.BG_CORNERS) do
        local corner = t[3 + i]
        corner:SetSize(s, s)
        corner:SetPoint(c[1], f, c[1], c[2] * bgIn, c[3] * bgIn)
        corner:SetTexCoord(c[4], c[5], c[6], c[7])
    end
    for i = 1, 7 do t[i]:Show() end
end

-- The border's file, its edge size and the room it takes round the bar: a thin edge needs a
-- little, the 16 px frames more (shrunk on a thin bar)
-- how far in FlareUI's own borders' line ends (a dark gap between the bar and the border):
-- 8 of the art's 32 px, 8 of 16 for the thin cut. What's inside starts right there: no gap, and its square
-- corners stay under the slanted ones (further out, they showed past them). nil for other borders.
function NP.BorderFit(edgeFile, edge)
    if type(edgeFile) ~= "string" then return nil end
    if edgeFile:find("FlareUI%-Frames") or edgeFile:find("FlareUI%-Thick") then return edge / 4 end
    if edgeFile:find("FlareUI%-Thin%.tga") then return edge / 2 end
end
function NP.Edge(db)
    local _, _, borderName = Look(db)
    local edgeFile = BorderFile(borderName)
    local edge = edgeFile and ns.BorderEdgeSize(edgeFile, C.PLATE_EDGE) or 0
    local pad = edgeFile and (edge >= C.PLATE_EDGE and 4 or 2) or 1
    if edge >= C.PLATE_EDGE and db.height + 2 * pad < 22 then edge = math.min(edge, math_max(8, math_floor((db.height + 2 * pad) * 2 / 3))) end
    -- the bar and its background sit inside the border's rounded corners (no square corner poking out).
    -- Other addons' art can't be measured: the bar goes as far as the background always did there
    if edgeFile then pad = NP.BorderFit(edgeFile, edge) or math_max(1, math_max(pad, math.ceil(edge * 0.3)) - 1) end
    return edgeFile, edge, pad
end

-- the cast bar's own Bar Texture and Border, per type, apart from the plate's so
-- changing the health bar never changes it: FlareUI Dark and FlareUI Thin ("FlareUI Frames") by default
C.CAST_TEXTURE, C.CAST_BORDER = "FlareUI Dark", "FlareUI Frames"
function NP.CastTexture(db)
    local own = db.castTexture
    return (type(own) == "string" and own ~= "") and own or C.CAST_TEXTURE
end
-- its border file and edge size; nil for None
function NP.CastBorder(db)
    local own = db.castBorder
    if type(own) ~= "string" or own == "" then own = C.CAST_BORDER end
    local file = BorderFile(own)
    if not file then return nil, 0 end
    return file, math.min(ns.BorderEdgeSize(file, C.PLATE_EDGE), math_max(6, db.castHeight or 12))
end

-- Nothing sits above the bar but auras (the name is one of the bar's text slots)
function NP.NameRoom() return 0 end

function NP.Layout(p)
    local db = PDB(p)
    if not db then return end
    p.barDirty, p.borderDirty = true, true   -- (painted again after a layout: NP.BarColor, NP.PaintBorder)
    p.smoothHealth, p.damageTrail, p.healthEdge = db.smoothBars, db.damageTrail, db.edgeGlow
    p.healthTint, p.hideHealthTextAtFull = db.healthColor == "health", db.hideTextAtFull
    local _, textureName, borderName = Look(db)
    local w, h = db.width, db.height
    local edgeFile, edge, pad = NP.Edge(db)

    p.root:SetSize(w + 2 * pad, h + 2 * pad)
    p.plateW = w + 2 * pad
    p.box:ClearAllPoints()
    p.box:SetAllPoints(p.root)
    -- (the background inside the border, as the bar: its square corners never show past the round ones)
    local bgIn = edgeFile and pad or 0
    p.bgInset = bgIn
    -- (FlareUI Thin and Thick have slanted corners: the background's corners are cut to match, so no dark
    -- square shows past them. Its slant ends 13 of the art's 32 px in)
    p.bgCut = (edgeFile and (edgeFile:find("FlareUI%-Frames") or edgeFile:find("FlareUI%-Thick"))) and math_floor(edge * 13 / 32 + 0.5) or bgIn
    NP.Background(p.box, bgIn, p.bgCut, (db.bgOpacity or 40) / 100)
    NP.Background(p.flash, bgIn, p.bgCut, 1, C.AGGRO_RGB, "ADD")
    p.health:ClearAllPoints()
    p.health:SetPoint("TOPLEFT", p.box, "TOPLEFT", pad, -pad)
    p.health:SetPoint("BOTTOMRIGHT", p.box, "BOTTOMRIGHT", -pad, pad)
    local texture = K and K.GetBarTexture(textureName) or LSM:Fetch("statusbar", textureName)
    p.health:SetStatusBarTexture(texture)
    p.health.bg:SetTexture(texture)
    p.health.bg:SetVertexColor(0.15, 0.15, 0.15, 0.6)
    p.fill = p.health:GetStatusBarTexture()
    p.execTint:ClearAllPoints()
    p.execTint:SetAllPoints(p.fill)
    if UF and UF.PlaceDamageTrail then UF.PlaceDamageTrail(p.trail, false) end
    if UF and UF.BarLook then UF.BarLook(p.health, false, db.edgeGlow) end
    -- (the edge's widths from the known height: its own size event may not come on a plate)
    local edgeLook = p.health.fuiLook
    if edgeLook then
        edgeLook.line:SetWidth(h >= 12 and 5 or 4)
        edgeLook.glow:SetWidth(math_max(14, math.min(36, h * 1.6)))
    end
    for _, bar in ipairs({ p.heal, p.absorb }) do
        bar:SetStatusBarTexture(texture)
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", p.fill, "TOPRIGHT")
        bar:SetPoint("BOTTOMLEFT", p.fill, "BOTTOMRIGHT")
        bar:SetWidth(w)
    end
    -- the palette's colours (laid out again when a colour changes)
    local heal, absorb, target = NP.Color("heal", p.sample), NP.Color("absorb", p.sample), NP.Color("target", p.sample)
    p.heal:SetStatusBarColor(heal[1], heal[2], heal[3], 0.5)
    p.absorb:SetStatusBarColor(absorb[1], absorb[2], absorb[3], 0.6)
    p.outline:SetBackdropBorderColor(target[1], target[2], target[3], 1)
    if p.cast then
        local important = NP.Color("important", p.sample)
        NP.PaintImportantGlow(p.cast.important, important)
    end

    p.edgeFile, p.edgeSize = edgeFile, edge
    if edgeFile then
        p.border:SetBackdrop({ edgeFile = edgeFile, edgeSize = edge })
        p.border:Show()
    else
        p.border:SetBackdrop(nil)
        p.border:Hide()
    end
    p.targetShown = nil   -- the border colour is set again (NP.UpdateTarget)
    NP.LayoutPulseBorder(p.threatFx, p.border, p.box, edgeFile)
    NP.PlaceGlow(p.threatFx.soft, p.box, w + 2 * pad, h + 2 * pad)

    -- Execute Range: its colour and the mark where it starts
    local exec = NP.Color("execute", p.sample)
    p.execTint:SetColorTexture(exec[1], exec[2], exec[3], 1)
    p.execAt = NP.ExecuteAt(db)
    p.execMark:ClearAllPoints()
    if p.execAt then
        p.execMark:SetPoint("TOP", p.health, "TOPLEFT", math_floor(w * p.execAt + 0.5), 0)
        p.execMark:SetPoint("BOTTOM", p.health, "BOTTOMLEFT", math_floor(w * p.execAt + 0.5), 0)
        p.execMark:Show()
    else
        p.execMark:Hide()
        p.execTint:SetAlpha(0)
    end

    -- Level: a box or a disc beside the bar (Level Side), or in front of the name (Follow Name)
    NP.LayoutLevel(p, db, h + 2 * pad)

    -- Rare/Elite Icon: on the plate's top right corner, mostly inside it
    p.elite:ClearAllPoints()
    p.elite:SetSize(C.ELITE, C.ELITE)
    p.elite:SetPoint("CENTER", p.box, "TOPRIGHT", -C.ELITE * C.ELITE_IN, -C.ELITE * C.ELITE_IN)
    -- Target Highlight: tint, glow and arrows (shown by NP.UpdateTargetLook)
    NP.LayoutTargetLook(p, db, h + 2 * pad, db.debuffs ~= "off")
    -- quest mark, its progress, crowd control, defensives and the raid marker beside the plate (NP.PlaceSides)
    local markSize = math_max(12, h + 2 * pad)
    if C_Texture.GetAtlasInfo(C.QUEST_ATLAS) then p.quest:SetAtlas(C.QUEST_ATLAS) else p.quest:SetTexture(C.QUEST_FILE) end
    p.quest:SetSize(markSize * 0.7, markSize)
    p.questPad = math_floor(markSize * 0.7 * C.QUEST_PAD + 0.5)
    ApplyFontTo(p.questText, db.healthFont)
    p.questText:SetTextColor(1, 0.82, 0)
    p.raid:SetSize(markSize, markSize)
    NP.PlaceSides(p)

    -- Bar text: Left, Middle and Right inside the bar. The name is one slot's pick and stands alone
    -- there; it gives way to the numbers in the other slots.
    p.slots = NP.TextSlots(db)
    p.nameSlot, p.nameFull = nil, false
    for _, slot in ipairs(BT.SLOTS) do
        local pick = BT.NameOf(p.slots[slot])
        if pick then p.nameSlot, p.nameFull = slot, BT.FullOf(pick) break end
    end
    local POINT = { left = "LEFT", middle = "CENTER", right = "RIGHT" }
    local X = { left = 3, middle = 0, right = -3 }
    p.healthTextSlots, p.healthValues = {}, {}
    for slot, fs in pairs(p.texts) do
        ApplyFontTo(fs, db.healthFont)
        fs:ClearAllPoints()
        fs:SetPoint(POINT[slot], p.health, POINT[slot], X[slot], 0)
        fs:SetJustifyH(POINT[slot])
        fs:SetShown(slot ~= p.nameSlot)
        local fields = p.slots[slot]
        if slot ~= p.nameSlot and BT.HasNumbers(fields) then
            p.healthTextSlots[#p.healthTextSlots + 1] = slot
            local values = p.healthValues
            values.showMax = values.showMax or fields.max
            values.showPercent = values.showPercent or fields.percent
            values.showLost = values.showLost or fields.lost
        else
            fs:SetText("")
        end
    end
    ApplyFontTo(p.name, db.nameFont)
    p.name:ClearAllPoints()
    if p.nameSlot then
        local slot = p.nameSlot
        local room = w - 6
        if slot == "middle" then
            if BT.HasNumbers(p.slots.left) or BT.HasNumbers(p.slots.right) then room = w - 2 * C.TEXT_ROOM end
        else
            local other = slot == "left" and "right" or "left"
            if BT.HasNumbers(p.slots[other]) then room = room - C.TEXT_ROOM end
            if BT.HasNumbers(p.slots.middle) then room = math_floor(w / 2) - C.TEXT_ROOM / 2 end
        end
        p.name:SetPoint(POINT[slot], p.health, POINT[slot], X[slot], 0)
        p.name:SetWidth(math_max(20, room))
        p.name:SetJustifyH(POINT[slot])
        p.name:Show()
    else
        p.name:Hide()
    end
    p.textOn = #p.healthTextSlots > 0
    p.textHolder:SetShown(p.textOn)
    p.textHolder:SetAlpha(1)
    -- (Threat Percentage's place: NP.LayoutThreat, once the level box is laid out)
    p.boxH = h + 2 * pad

    -- cast bar under the bar's frame, as wide as the bar
    if p.cast then
        local inset = (K and K.INSET) or 4
        p.castAnchor:ClearAllPoints()
        p.castAnchor:SetPoint("TOPLEFT", p.health, "TOPLEFT", -inset, 0)
        p.castAnchor:SetPoint("BOTTOMRIGHT", p.health, "BOTTOMRIGHT", inset, -(pad + C.CAST_GAP))
        -- (no border from the kit: its border step reads a frame's points, which the game refuses
        -- on a nameplate while addon restrictions are on; the border is set here from known sizes)
        -- the cast bar's own Bar Texture and Border (NP.CastTexture / CastBorder)
        local castTexture = NP.CastTexture(db)
        local castArt, castEdge = NP.CastBorder(db)
        K.LayoutCastBar(p.cast, {
            height = db.castHeight, icon = db.castIcon, timer = db.castTimer ~= false, name = true,
            texture = castTexture, border = false, borderTexture = borderName,
            bgOpacity = db.bgOpacity, glow = ns.CastGlowOn(db.castGlow),
        }, p.castAnchor, "BOTTOM")
        -- (the border's line right on the bar, as the plate's: the kit's backdrop is wrap px round the bar)
        local castFit = NP.BorderFit(castArt, castEdge)
        local _, wrap = K.BorderFit(db.castHeight, false)
        local castIn = castFit and wrap - castFit or 0
        p.cast.Border:ClearAllPoints()
        p.cast.Border:SetPoint("TOPLEFT", p.cast.Backdrop, "TOPLEFT", castIn, -castIn)
        p.cast.Border:SetPoint("BOTTOMRIGHT", p.cast.Backdrop, "BOTTOMRIGHT", -castIn, castIn)
        if castArt then
            p.cast.Border:SetBackdrop({ edgeFile = castArt, edgeSize = castEdge })
            local c = ns.BORDER_COLOR
            p.cast.Border:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
            p.cast.Border:Show()
        else
            p.cast.Border:Hide()
        end
        ApplyFontTo(p.cast.Text, db.castFont)
        ApplyFontTo(p.cast.Time, db.castFont)
        ApplyFontTo(p.cast.target, db.castFont)
        p.cast.target:ClearAllPoints()
        -- Show Cast Target: right of the bar, clear of the Can't Interrupt shield on its right end
        p.cast.target:SetPoint("LEFT", p.cast.Backdrop, "RIGHT", math_floor(db.castHeight * 0.55) + 3, 0)
        p.cast.target:SetJustifyH("LEFT")
        -- Can't Interrupt: the shield sits on the middle of the bar's right border (clear of the icon)
        p.cast.shield:ClearAllPoints()
        p.cast.shield:SetSize(db.castHeight * 1.1, db.castHeight * 1.3)
        p.cast.shield:SetPoint("CENTER", p.cast.Backdrop, "RIGHT", 0, 0)
        p.cast.shield:SetAlpha(0)
        -- the important glow round the whole bar, icon too (its size from known numbers: a nameplate's
        -- regions can't be measured under addon restrictions)
        local glow = p.cast.important
        NP.LayoutPulseBorder(glow, p.cast.Border, p.cast.Backdrop, castArt)
        if castArt then glow:SetFrameLevel(p.cast.Border:GetFrameLevel() + 1) end
        NP.PaintImportantGlow(glow, glow.color or NP.Color("important", p.sample))
        if db.castImportant then glow.pulse:Play() else glow.pulse:Stop() end
        -- Flash When Targeted: the frame's whole inside, under its border, corners cut as the
        -- border's (as the plate's background, from the cast bar's own edge)
        local fin = castFit or (castArt and math_max(1, math.ceil(castEdge * 0.3) - 1)) or 0
        local slanted = castArt and (castArt:find("FlareUI%-Frames") or castArt:find("FlareUI%-Thick"))
        p.cast.targeted:ClearAllPoints()
        p.cast.targeted:SetAllPoints(p.cast.Border)
        NP.Background(p.cast.targeted.fill, fin, slanted and math_floor(castEdge * 13 / 32 + 0.5) or fin, 0.5, C.TARGETED_RGB, "ADD")
        -- Highlight Important Casts: its soft glow round the frame (the border copy sits on the border)
        local room = 2 * (castFit or 4)
        NP.PlaceGlow(glow.soft, p.cast.Border, w + (db.castIcon and db.castHeight or 0) + room, db.castHeight + room, C.IMPORTANT_SIZE)
        -- Kick Ready Mark: the waiting bar as wide as the cast bar (its icon aside: the kit sets no gap)
        p.cast.kickWait:SetSize(math_max(1, w - (db.castIcon and db.castHeight or 0)), db.castHeight)
        p.cast.kickSpark:SetSize(12, db.castHeight * 2.2)
        local kick = NP.Color("kickReady", p.sample)
        p.cast.kickSpark:SetVertexColor(kick[1], kick[2], kick[3])
    end

    NP.LayoutNameAbove(p, db)
    LayoutAuras(p, db)
    NP.PlaceBelow(p)
    -- Plate: Bar (all of the above), Name Only (the name alone, centred, in its colour) or Hidden
    -- (Show Plates in Combat: a Name Only type picked there gets its bar in a fight, NP.CombatFull)
    p.layFull = NP.CombatFull(db.kind, p.sample)
    p.nameOnly = db.plate == "name" and not p.layFull
    p.hiddenPlate = db.plate == "hidden"
    p.health:SetShown(not p.nameOnly)
    if p.nameOnly then
        NP.Background(p.box, p.bgInset or 0, p.bgCut or 0, 0)
        p.border:Hide()
        p.textHolder:Hide()
        p.levelFrame:Hide()
        p.levelArt:Hide()
        p.level:Hide()
        p.levelShown, p.levelAnchor = false, nil
        p.nameSlot = p.nameSlot or "middle"
        -- Show Name (per type): a player's full name (true), first (false) or last ("lastname")
        p.nameFull = db.nameOnlyFull == "lastname" and "lastname" or db.nameOnlyFull ~= false
        p.name:ClearAllPoints()
        p.name:SetPoint("CENTER", p.box, "CENTER", 0, 0)
        -- its own font, and Name Only Size: this type's name alone, scaled
        -- (through the font family with a size offset, from the font's own size: a SetFont on the
        -- string would beat the family from then on, and each layout would scale it again)
        local scale = (tonumber(db.nameOnlySize) or 100) / 100
        local font = db.nameOnlyFont or db.nameFont
        local base = (font and font.size) or 12
        if K and K.ApplyFont then K.ApplyFont(p.name, font, scale ~= 1 and math_floor(base * (scale - 1) + 0.5) or nil) end
        p.name:SetWidth((w + 40) * math_max(1, scale))
        p.name:SetJustifyH("CENTER")
        p.name:Show()
        -- the NPC title under it, a little smaller (NP.UpdateTitle fills it)
        if p.npcTitle then
            if K and K.ApplyFont then
                K.ApplyFont(p.npcTitle, font, math_floor(base * (scale * C.TITLE_SIZE - 1) + 0.5))
            end
            p.npcTitle:ClearAllPoints()
            p.npcTitle:SetPoint("TOP", p.name, "BOTTOM", 0, -1)
            p.npcTitle:SetWidth((w + 40) * math_max(1, scale))
        end
        if p.guildName then
            if K and K.ApplyFont then
                K.ApplyFont(p.guildName, font, math_floor(base * (scale * C.TITLE_SIZE - 1) + 0.5))
            end
            p.guildName:SetWidth((w + 40) * math_max(1, scale))
        end
    elseif p.npcTitle then
        p.npcTitle:Hide()
        if p.guildName then p.guildName:Hide() end
    end
    NP.LayoutThreat(p, db)
    -- (again now that nameOnly is known: the raid marker's place depends on it)
    NP.PlaceSides(p)
    p.layKind = db.kind
    p.laid = true
    -- (a held plate laid out again: a row just switched on or off)
    if p.unit and not p.sample and not p.aurasQueued then NP.SetAuraUnits(p) end
end

--------------------------------------------------
-- 5. UPDATES (live plates)
--------------------------------------------------
-- Am I a tank? The group role, a raid's main tank, Defensive Stance, Bear Form or Righteous Fury;
-- or the role picked by hand. Read out of combat and on form changes; a hidden answer keeps the last.
local function ResolveRole(db, previous)
    if db and db.role and db.role ~= "auto" then return db.role end
    local tank = false
    local ok, role = pcall(UnitGroupRolesAssigned, "player")
    if ok and canaccessvalue(role) and role == "TANK" then tank = true end
    if not tank and GetPartyAssignment then
        local okA, main = pcall(GetPartyAssignment, "MAINTANK", "player")
        if okA and canaccessvalue(main) and main then tank = true end
    end
    if not tank then
        local _, class = UnitClass("player")
        if class == "WARRIOR" then
            local form = GetShapeshiftForm()
            if form and form > 0 then
                local _, active, _, spellID = GetShapeshiftFormInfo(form)
                tank = active and spellID == C.DEFENSIVE_STANCE or false
            end
        elseif class == "DRUID" then
            local id = GetShapeshiftFormID and GetShapeshiftFormID()
            tank = id ~= nil and id == (_G.DRUID_BEAR_FORM or 8)
        elseif class == "PALADIN" and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
            local okF, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, C.RIGHTEOUS_FURY)
            if not okF or not canaccessvalue(aura) then return previous end   -- hidden: keep the last answer
            tank = aura ~= nil
        end
    end
    return tank and "tank" or "damage"
end
local function PendingRole(applied)
    local selected = pendingSettings.shared
    if (selected.role or "auto") == (applied and applied.role or "auto") then return state.role end
    return ResolveRole(selected, pendingSettings.role or state.role)
end
local function RedrawOpenPreview()
    if ns.NameplatesPinned and ns.SettingsPanel and ns.SettingsPanel:IsShown() then
        ns.SafeCall("Nameplates Preview", ns.NameplatesPinned.Draw)
    end
end
function NP.UpdateRole()
    local applied = SharedSettings()
    state.role = ResolveRole(applied, state.role)
    if pendingSettings then
        local role = PendingRole(applied)
        if role ~= pendingSettings.role then
            pendingSettings.role = role
            RedrawOpenPreview()
        end
    end
end

-- the other tanks in the group (role or main tank), for "Another Tank Has It"
function NP.UpdateGroup()
    state.inGroup = IsInGroup()
    state.inInstance = (IsInInstance()) and true or false
    wipe(state.tanks)
    local prefix, count = nil, 0
    if IsInRaid() then prefix, count = "raid", GetNumGroupMembers() elseif state.inGroup then prefix, count = "party", 4 end
    for i = 1, count do
        local unit = prefix .. i
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            local ok, role = pcall(UnitGroupRolesAssigned, unit)
            local tank = ok and canaccessvalue(role) and role == "TANK"
            if not tank and GetPartyAssignment then
                local okA, main = pcall(GetPartyAssignment, "MAINTANK", unit)
                tank = okA and canaccessvalue(main) and main or false
            end
            if tank then state.tanks[#state.tanks + 1] = unit end
        end
    end
end

local function Readable(v) if canaccessvalue(v) then return v end end

-- PET THREAT (Rex / saamor): your own pet holding the mob counts as another tank having it
-- (the Another Tank colour), for tanks and damage alike; the game hands pet threat over in a fight
function NP.PetHolds(unit)
    if not UnitExists("pet") then return false end
    local pet = Readable(UnitThreatSituation("pet", unit))
    return type(pet) == "number" and pet >= 2
end

-- the threat colour, or nil for the plate's own colour
local function ThreatRGB(unit, db)
    local mode = db.threat
    if mode == "off" or (mode == "groups" and not state.inGroup) then return nil end
    if C_Secrets and C_Secrets.ShouldUnitThreatStateBeSecret then
        local ok, secret = pcall(C_Secrets.ShouldUnitThreatStateBeSecret, "player", unit)
        if not ok or not canaccessvalue(secret) or secret then return nil end
    end
    local raw = UnitThreatSituation("player", unit)
    local status = Readable(raw)
    -- (not on its threat list yet, as when your pet pulls: only the pet's threat counts; a secret
    -- answer isn't "not on the list")
    if raw == nil and NP.PetHolds(unit) then status = 0 end
    if type(status) ~= "number" then return nil end
    local fighting = Readable(UnitAffectingCombat(unit))
    if not fighting then return nil end
    local key
    if state.role == "tank" then
        if status == 3 then key = "holding"
        elseif status == 2 then key = "losing"
        else
            key = "lost"
            if NP.PetHolds(unit) then key = "offtank" end
            for _, tank in ipairs(state.tanks) do
                if key == "offtank" then break end
                local other = Readable(UnitThreatSituation(tank, unit))
                if type(other) == "number" and other >= 2 then key = "offtank" end
            end
        end
    else
        if status == 1 then key = "gaining" elseif status >= 2 then key = "aggro"
        elseif NP.PetHolds(unit) then key = "offtank" end
    end
    if key then
        local c = NP.Color(key)
        return c[1], c[2], c[3], key
    end
end

-- Threat Scale (tanks): a mob you lost grows, one someone is taking grows a little, one you hold
-- shrinks a little; another tank's stays as it is. One size per state, never animated (the target's is).
C.THREAT_SCALE = { lost = 1.15, losing = 1.07, holding = 0.92 }

-- A target can exist without a visible plate. Share that lookup across a queued pass,
-- and skip it when both settings give the same result.
local function OtherPlateValue(targetState, withTarget, noTarget)
    withTarget, noTarget = withTarget or 1, noTarget or 1
    if withTarget == noTarget then return withTarget end
    local hasTarget = targetState and targetState.hasTarget
    if hasTarget == nil then
        hasTarget = not not UnitExists("target")
        if targetState then targetState.hasTarget = hasTarget end
    end
    return hasTarget and withTarget or noTarget
end

function NP.ApplyScale(p, targetState)
    local db = PDB(p)
    -- The settings preview stays at the size of its box.
    local k = 1
    if not p.sample then
        if p.targetShown then k = db.targetScale or 1
        else k = OtherPlateValue(targetState, db.notTargetScale, db.noTargetScale) end
        if db.threatScale and state.role == "tank" and p.threatKey then k = k * (C.THREAT_SCALE[p.threatKey] or 1) end
    end
    -- a plate just taken, a threat change and the previews jump; picking a target grows and shrinks
    local jump = p.sample or p.scaleFresh or not p.scaleNow or p.scaleThreat ~= p.threatKey
    p.scaleFresh, p.scaleThreat = nil, p.threatKey
    if p.scaleNow == k then return end
    p.scaleNow = k
    jump = jump or not p.root:IsVisible()
    if jump then NP.StopScale(p) p.root:SetScale(k) else NP.GlideScale(p, k) end
end

-- TARGET SCALE, as smooth as Blizzard's own plates: one clock over the plates on their way to a new size
C.SCALE_TIME = 0.15
NP.Glide = { plates = {}, driver = CreateFrame("Frame") }
NP.Glide.driver:Hide()
function NP.GlideScale(p, k)
    local glide = NP.Glide.plates[p] or {}
    glide.from, glide.to, glide.time = p.root:GetScale(), k, 0
    NP.Glide.plates[p] = glide
    NP.Glide.driver:Show()
end
function NP.StopScale(p)
    NP.Glide.plates[p] = nil
end
NP.Glide.driver:SetScript("OnUpdate", function(driver, elapsed)
    for p, glide in pairs(NP.Glide.plates) do
        glide.time = glide.time + elapsed
        local left = 1 - glide.time / C.SCALE_TIME
        if left <= 0 then
            NP.Glide.plates[p] = nil
            p.root:SetScale(glide.to)
        else
            p.root:SetScale(glide.to + (glide.from - glide.to) * left * left)   -- (slows down as it gets there)
        end
    end
    if not next(NP.Glide.plates) then driver:Hide() end
end)

-- The bar's colour, and the Outer Glow's with it (the glow always takes the bar's colour)
-- the bar, border and level art are painted only when their colour changed; a
-- layout or a claim paints them again (p.barDirty, p.borderDirty). A colour Lua can't read is always written.
function NP.BarColor(p, r, g, b)
    -- a hidden colour is never compared, the new one nor the last one painted: that is an error
    local known = canaccessvalue(r) and canaccessvalue(g) and canaccessvalue(b)
    if known and p.barKnown and not p.barDirty and p.barR == r and p.barG == g and p.barB == b then return end
    p.health:SetStatusBarColor(r, g, b)
    p.barDirty = false
    p.barR, p.barG, p.barB = r, g, b
    p.barKnown, p.barSet = known, true
    if p.targetGlow:IsShown() then ApplyVisual(p, "PaintGlow") end
end

function NP.PaintGlow(p)
    local r, g, b = 1, 1, 1
    if p.barSet then r, g, b = p.barR, p.barG, p.barB end
    for _, t in ipairs(p.targetGlow.parts) do t:SetVertexColor(r, g, b, C.GLOW_ALPHA) end
    for _, t in ipairs(p.levelGlow.parts) do t:SetVertexColor(r, g, b, C.GLOW_ALPHA) end
    for _, t in ipairs(p.discGlow.parts) do t:SetVertexColor(r, g, b, C.GLOW_ALPHA) end
end

-- THREAT PERCENTAGE (Extras > Threat, off): your threat on the unit as a number, in
-- the colours of the unit frames' Threat Text (Blizzard's threat status colours). 100% is where you
-- pull it; a tank holding it reads its lead over the next. Shown in a fight with threat on it, and on
-- the Test plates; never on Name Only plates. A threat the game keeps hidden shows nothing.
-- Off, In a Group ("groups"), In an Instance ("instances") or Always (saved true / false while it
-- was a switch, and still for Always and Off)
function NP.ThreatPercentOn(db)
    local mode = db.threatPercent
    if mode == "groups" then return state.inGroup and true or false end
    if mode == "instances" then return state.inInstance and true or false end
    return mode and mode ~= "off" and true or false
end
function NP.UpdateThreatText(p, db)
    local fs = p.threatText
    if not fs then return end
    local unit = p.unit
    local display, status
    -- the threat in the level's place (the level comes back without it), or in its own box
    local function Place(shown)
        if p.threatInLevel then p.level:SetShown(not shown and p.levelShown or false) end
        if p.threatBox then
            local boxShown = shown and p.threatBoxOn or false
            if p.threatBoxShown ~= boxShown then
                p.threatBox:SetShown(boxShown)
                p.threatBoxShown = boxShown
                -- the pieces on the right make room only while the box shows: out of a
                -- fight they sit right beside the plate
                RequestSideLayout(p)
            end
        end
        fs:SetShown(shown and (p.threatInLevel or p.threatBoxOn) or false)
    end
    local wanted = NP.ThreatPercentOn(db) or (NP.testKind and db.threatPercent and db.threatPercent ~= "off")
    if wanted and unit and not p.nameOnly then
        if NP.testKind then
            display, status = 75, 1
        else
            -- the numbers are read whenever the game hands them over; before, the text gave up
            -- whenever ShouldUnitThreatStateBeSecret said yes, so it never showed in a fight. A secret
            -- percent goes into the text unread (ns.ThreatPercent, ns.ThreatPercentText).
            local secret
            display, status, secret = ns.ThreatPercent(unit)
            if secret then
                local text = ns.ThreatPercentText(display)
                if not (text and pcall(fs.SetFormattedText, fs, "%s%%", text)) then Place(false) return end
                if status and status >= 1 and GetThreatStatusColor then
                    fs:SetTextColor(GetThreatStatusColor(status))
                else
                    fs:SetTextColor(1, 1, 1)
                end
                Place(true)
                return
            end
        end
    end
    if type(display) ~= "number" or display <= 0 then Place(false) return end
    local r, g, b = 1, 1, 1
    if status and status >= 1 and GetThreatStatusColor then r, g, b = GetThreatStatusColor(status) end
    fs:SetTextColor(r, g, b)
    fs:SetFormattedText("%.0f%%", display)
    Place(true)
end

function NP.UpdateColor(p)
    local db, unit = PDB(p), p.unit
    if not (db and unit) then return end
    local tapped = Readable(UnitIsTapDenied(unit))
    if tapped then
        -- no threat look: not one it had before the tap, nor the last unit's on this plate
        p.threatRGB = nil
        if p.threatKey then
            p.threatKey = nil
            ApplyVisual(p, "ApplyScale")
        end
        NP.UpdateThreatText(p, db)
        ApplyVisual(p, "PaintBorder")
        local c = NP.Color("tapped")
        NP.BarColor(p, c[1], c[2], c[3])
        return
    end
    local r, g, b, threatKey = ThreatRGB(unit, db)
    if threatKey ~= p.threatKey then
        local before = p.threatKey
        p.threatKey = threatKey
        ApplyVisual(p, "ApplyScale")
        -- Aggro Flash: it turned on you (damage / healer) or away from you (tank)
        if db.aggroFlash and before and (threatKey == "aggro" or threatKey == "lost") then p.flashAnim:Stop() p.flashAnim:Play() end
    end
    -- (one table per plate, filled again: PaintBorder tells it apart from the target colour by identity)
    if r then
        local t = p.threatBuf or {}
        t[1], t[2], t[3] = r, g, b
        p.threatBuf, p.threatRGB = t, t
    else
        p.threatRGB = nil
    end
    NP.UpdateThreatText(p, db)
    ApplyVisual(p, "PaintBorder")
    if r then NP.BarColor(p, r, g, b) return end
    -- your focus (Focus Colour), then the mob type colours
    if db.colorFocus and p.gamePlate and p.gamePlate == C_NamePlate.GetNamePlateForUnit("focus") then
        local c = NP.Color("focus")
        NP.BarColor(p, c[1], c[2], c[3])
        return
    end
    r, g, b = NP.MobRGB(unit, db)
    if r then NP.BarColor(p, r, g, b) return end
    local mode = db.healthColor
    if mode == "health" and UF and UF.HealthBarColor then
        r, g, b = UF.HealthBarColor(unit, true, db)
    elseif mode == "reaction" then
        r, g, b = ReactionRGB(unit)
    elseif mode == "off" then
        local ok, sr, sg, sb = pcall(UnitSelectionColor, unit, true)
        if ok then r, g, b = sr, sg, sb end
    elseif Readable(UnitIsPlayer(unit)) and K and K.GetHealthColor then
        r, g, b = K.GetHealthColor(unit, true)   -- Class & Reaction: a player's class colour
    else
        r, g, b = ReactionRGB(unit)              -- everyone else in the plates' reaction colours
    end
    -- (type: a hidden colour isn't compared)
    if type(r) == "nil" then r, g, b = ReactionRGB(unit) end
    if type(r) == "nil" then local c = NP.Color("hostile") r, g, b = c[1], c[2], c[3] end
    NP.BarColor(p, r, g, b)
end

-- a dead mob's plate goes at once: the game takes it away a while later on Forever. A
-- player's stays (a friend to resurrect).
function NP.UpdateDead(p)
    local dead = UnitIsDead(p.unit)
    dead = canaccessvalue(dead) and dead and Readable(UnitIsPlayer(p.unit)) == false or false
    if (p.deadHidden or false) == dead then return end
    p.deadHidden = dead
    p.root:SetShown(not (p.hiddenPlate or p.unitHidden or dead))
end

function NP.UpdateHealth(p, glide, mask)
    local unit, values = p.unit, p.healthValues
    if not p.sample and unit then NP.UpdateDead(p) end
    local shown = not (p.nameOnly or p.hiddenPlate or p.unitHidden)
    if not mask or band(mask, D.MAXHEALTH) ~= 0 then
        values.max = UnitHealthMax(unit)
        p.health:SetMinMaxValues(0, values.max)
        if p.trail and p.damageTrail then p.trail:SetMinMaxValues(0, values.max) end
    elseif shown and values.showMax then
        local _, max = p.health:GetMinMaxValues()
        values.max = max
    end
    -- Other addons can read this StatusBar even when the plate shows just the name.
    values.cur = UnitHealth(unit)
    ns.SetBarValue(p.health, values.cur, glide and p.smoothHealth)
    if shown then
        if UF and UF.SetDamageTrail and (p.damageTrail or not mask) then
            UF.SetDamageTrail(p.trail, unit, glide, p.damageTrail, values)
        end
        local lostAlpha
        if p.textOn then
            K.HealthSource(unit, p.slots, values)
            lostAlpha = values.lostAlpha
            for _, slot in ipairs(p.healthTextSlots) do BT.Fill(p.texts[slot], p.slots[slot], values) end
            if p.hideHealthTextAtFull then
                if not values.showLost then lostAlpha = UnitHealthPercent(unit, true, UF.LostCurve()) end
                p.textHolder:SetAlpha(lostAlpha)
            end
        end
        if p.healthEdge and UF and UF.BarLookUpdate then UF.BarLookUpdate(p.health, unit, glide, nil, lostAlpha) end
        if p.execAt then NP.UpdateExecute(p) end
    end
    values.cur, values.max, values.percent, values.lost, values.lostAlpha = nil, nil, nil, nil, nil
    -- A queued flush also handles threat/colour events and repaints the plate once.
    if not mask and p.healthTint then NP.UpdateColor(p) end
end

function NP.UpdateHeals(p, mask)
    if p.nameOnly or p.hiddenPlate or p.unitHidden then return end
    local unit = p.unit
    local resize = not mask or band(mask, D.MAXHEALTH) ~= 0
    if resize then
        -- The health bar receives the new range first, including when a plate changes units.
        local _, max = p.health:GetMinMaxValues()
        p.heal:SetMinMaxValues(0, max)
        p.absorb:SetMinMaxValues(0, max)
    end
    local heals = resize or band(mask, D.HEALS) ~= 0
    local absorbs = resize or band(mask, D.ABSORB) ~= 0
    local getHeals, getAbsorbs, source = UnitGetIncomingHeals, UnitGetTotalAbsorbs, unit
    local calc = p.calc
    if calc and UnitGetDetailedHealPrediction and pcall(UnitGetDetailedHealPrediction, unit, "player", calc) then
        getHeals, getAbsorbs, source = calc.GetIncomingHeals, calc.GetDamageAbsorbs, calc
        -- MissingHealth subtracts incoming heals from the room for a shield. WithAbsorbs
        -- counts shields in the maximum used to clamp heals. Unknown modes refresh both.
        if (heals and not p.shieldIgnoresHeals) or (absorbs and not p.healIgnoresShields) then
            heals, absorbs = true, true
        end
    end
    if source ~= p.predictionSource then
        -- Switching between calculated and raw amounts also changes the untouched overlay.
        p.predictionSource = source
        heals, absorbs = true, true
    end
    if heals then
        local ok, incoming = pcall(getHeals, source)
        if ok then pcall(p.heal.SetValue, p.heal, incoming) end
    end
    if absorbs then
        local ok, absorbs = pcall(getAbsorbs, source)
        if ok then pcall(p.absorb.SetValue, p.absorb, absorbs) end
    end
end

-- NAMES ABOVE PLATE (per type): the name above the plate, as the unit frames' Name
-- Above Frames: Off, or Left / Centre / Right with First, Full or Last Name (nameAbove =
-- "<slot>:<firstname|fullname|lastname>"). Debuffs and buffs above the plate move up by its height
-- (p.nameAboveLift). Never on a Name Only or hidden plate: the name is the plate there.
function NP.NameAbovePick(db)
    local v = db.nameAbove
    if type(v) ~= "string" then return nil end
    local slot, kind = v:match("^(%a+):(%a+)$")
    if (slot == "left" or slot == "middle" or slot == "right") and BT.NAMES[kind] then
        return slot, kind
    end
end
function NP.LayoutNameAbove(p, db)
    local slot, kind = NP.NameAbovePick(db)
    local nameOnly = db.plate == "name" and not NP.CombatFull(db.kind, p.sample)
    if not slot or nameOnly or db.plate == "hidden" then
        if p.aboveName then p.aboveName:Hide() end
        p.nameAboveLift, p.aboveKind = 0, nil
        return
    end
    local fs = p.aboveName
    if not fs then
        fs = p.root:CreateFontString(nil, "OVERLAY")
        fs:SetWordWrap(false)
        p.aboveName = fs
    end
    ApplyFontTo(fs, db.nameFont)
    local at = (slot == "left" and "LEFT") or (slot == "right" and "RIGHT") or ""
    fs:ClearAllPoints()
    fs:SetPoint("BOTTOM" .. at, p.box, "TOP" .. at, (slot == "left" and 1) or (slot == "right" and -1) or 0, C.AURA_GAP)
    fs:SetJustifyH(at == "" and "CENTER" or at)
    fs:SetWidth(math_max(20, p.plateW or db.width))
    fs:Show()
    local _, size = fs:GetFont()
    p.aboveKind = kind
    p.nameAboveLift = math_floor((tonumber(size) or 12) + C.AURA_GAP + 1)
end
-- its text and colour: the unit's, in the bar name's colour (a settings sample: the sample's name)
function NP.UpdateNameAbove(p)
    local fs = p.aboveName
    if not (fs and p.aboveKind and fs:IsShown()) then return end
    if p.unit and UnitExists(p.unit) then
        -- Level: Follow Name goes in front of this name too
        local name = ns.UnitDisplayName(p.unit, nil, BT.FullOf(p.aboveKind))
        local prefix = p.levelFollow and NP.LevelPrefix(p.unit)
        if prefix then fs:SetFormattedText("%s%s", prefix, name) else fs:SetText(name) end
    else
        fs:SetText(p.sampleName or "")
    end
    local full = p.aboveColor
    if full then fs:SetTextColor(full:GetRGB()) else fs:SetTextColor(p.name:GetTextColor()) end
end

function NP.UpdateName(p)
    NP.UpdateBarName(p)
    NP.UpdateNameAbove(p)
end
function NP.UpdateBarName(p)
    local db, unit = PDB(p), p.unit
    -- the colour even with no name in the bar: Names Above Plate takes it, and it kept
    -- the colour of whichever unit the plate had shown before
    if not (p.nameSlot or p.aboveKind) then return end
    p.aboveColor = nil
    -- the first name, or the surname too when Bar Text picks Full Name; Follow Name puts the level in
    -- front, in its colour
    if p.nameSlot then
        local name = ns.UnitDisplayName(unit, nil, p.nameFull or false)
        local prefix = p.levelFollow and NP.LevelPrefix(unit)
        if prefix then p.name:SetFormattedText("%s%s", prefix, name) else p.name:SetText(name) end
    end
    -- Party Colour (groupColor) and Raid Colour: your party or raid members' names in their own
    -- colour; other players by class, everyone else white. (Raid Colour never set follows the old
    -- Group Colour switch, which covered both.)
    local player = Readable(UnitIsPlayer(unit))
    if player then
        local raidOn = db.raidColor
        if raidOn == nil then raidOn = db.groupColor end
        local key
        if IsInRaid() then
            if raidOn and Readable(UnitInRaid(unit)) then key = "raid" end
        elseif db.groupColor and Readable(UnitInParty(unit)) then
            key = "group"
        end
        if key then
            local c = NP.Color(key)
            p.name:SetTextColor(c[1], c[2], c[3])
            return
        end
    end
    -- Colour Guild Members: your guild's names in Blizzard's guild green
    -- on Friendly Player's Name Only plates (off)
    if player and p.nameOnly and db.guildColor and p.kind == "friendlyPlayer" and UnitIsInMyGuild
        and Readable(UnitIsInMyGuild(unit)) then
        local g = ChatTypeInfo and ChatTypeInfo.GUILD
        p.name:SetTextColor(g and g.r or 0.25, g and g.g or 1, g and g.b or 0.25)
        return
    end
    -- the class colour on a Name Only plate: on a full plate the bar already carries
    -- it, and a class-coloured name on a class-coloured bar was hard to read (white instead).
    -- (Ha'Beebs) Colour Names by Class (off) gives full plates their class colour too
    if player and (p.nameOnly or db.nameClassColor) then
        local _, class = UnitClass(unit)
        local ok, color = pcall(C_ClassColor.GetClassColor, class)
        if ok and color then
            -- on a bar of the same colour: a lighter shade, or the name is lost in it (the name above keeps it)
            local mode = db.healthColor
            local r, g, b = color:GetRGB()
            if not p.nameOnly and p.nameSlot and mode ~= "health" and mode ~= "reaction" and mode ~= "off" then
                p.aboveColor = color
                if canaccessvalue(r) and canaccessvalue(g) and canaccessvalue(b) then
                    local k = C.NAME_LIFT
                    r, g, b = r + (1 - r) * k, g + (1 - g) * k, b + (1 - b) * k
                else
                    r, g, b = 1, 1, 1
                end
            end
            p.name:SetTextColor(r, g, b)
            return
        end
    end
    -- a name with no bar under it carries the reaction colour itself
    if p.nameOnly then
        local r, g, b = ReactionRGB(unit)
        if r then p.name:SetTextColor(r, g, b) return end
    end
    p.name:SetTextColor(1, 1, 1)
end

C.NAME_LIFT = 0.6   -- Colour Names by Class: how far towards white on a class-coloured bar

-- NPC TITLES (always on, no option): an NPC's title ("General Goods", "Blacksmithing
-- Trainer") under its name on a Name Only plate, as players asked. The game has no call for it: it is
-- the second line of the NPC's tooltip (one line lower in Colourblind Mode), unless that line is its
-- level. Read once per NPC name (C.TITLES), never in instances (tooltip data can be secret there),
-- never a secret line. Friendly and enemy NPCs only (a pet's second line is its owner).
C.TITLE_SIZE = 0.8
C.SAMPLE_SECONDS = { 24, 8, 75, 3, 42, 130, 15, 6 }   -- the settings preview's aura times
C.TITLES = {}   -- NPC name -> its title, or false for none
function NP.NPCTitle(unit)
    if IsInInstance() then return nil end
    local name = UnitName(unit)
    local key = (canaccessvalue(name) and type(name) == "string") and name or nil
    if key and C.TITLES[key] ~= nil then return C.TITLES[key] or nil end
    if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then return nil end
    local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
    if not (ok and type(data) == "table" and type(data.lines) == "table") then return nil end
    local colourblind = tonumber(GetCVar("colorblindMode")) or 0
    local line = data.lines[2 + colourblind]
    local text = type(line) == "table" and line.leftText
    local title = false
    if text and canaccessvalue(text) and type(text) == "string" and text ~= "" then
        -- a level line ("Level 30 Humanoid", "Level ?? Elite") is no title
        local levelWord = _G.LEVEL or "Level"
        if not text:find(levelWord, 1, true) then title = text end
    end
    -- (remembered only once the tooltip has that line: one still loading would be "no title" for good)
    if key and type(line) == "table" then C.TITLES[key] = title end
    return title or nil
end
-- SHOW TITLES (per type): NPC types on by default, players and Minor off
function NP.TitlesOn(db, kind)
    local v = db and db.showTitles
    if v == nil then v = kind == "friendlyNpc" or kind == "enemyNpc" end
    return v and true or false
end
-- a player's title: their PvP name ("Corporal Bob Smith") less their name; nil without one
function NP.PlayerTitle(unit)
    local pvp = UnitPVPName and UnitPVPName(unit)
    local name = ns.UnitDisplayName(unit, nil, true)
    if not (canaccessvalue(pvp) and canaccessvalue(name) and type(pvp) == "string" and type(name) == "string") then return nil end
    if name == "" or pvp == name then return nil end
    local a, b = pvp:find(name, 1, true)
    if not a then return nil end
    local title = (pvp:sub(1, a - 1) .. pvp:sub(b + 1)):gsub("%s+", " ")
    title = title:gsub("^%s*,?%s*", ""):gsub("%s+$", "")
    return title ~= "" and title or nil
end
-- SHOW GUILD NAME (the player types, off): a player's guild on a Name Only plate,
-- under the title when there is one, as Blizzard writes it: <Guild>. A secret one is left out.
function NP.UpdateGuild(p)
    local fs = p.guildName
    if not fs then return end
    local guild
    if p.nameOnly and p.unit and (p.kind == "friendlyPlayer" or p.kind == "enemyPlayer") and PDB(p).showGuild then
        guild = GetGuildInfo(p.unit)
        if not (canaccessvalue(guild) and type(guild) == "string" and guild ~= "") then guild = nil end
    end
    if not guild then fs:Hide() return end
    fs:SetText("<" .. guild .. ">")
    local c = ns.PALETTE.bronze5
    fs:SetTextColor(c[1], c[2], c[3], 1)
    fs:ClearAllPoints()
    fs:SetPoint("TOP", (p.npcTitle and p.npcTitle:IsShown()) and p.npcTitle or p.name, "BOTTOM", 0, -1)
    fs:Show()
end
-- the lines under a Name Only name: the title, then the guild
function NP.UpdateTitle(p)
    NP.UpdateTitleLine(p)
    NP.UpdateGuild(p)
end
function NP.UpdateTitleLine(p)
    local fs = p.npcTitle
    if not fs then return end
    local title
    if p.nameOnly and p.unit and NP.TitlesOn(PDB(p), p.kind) then
        if p.kind == "friendlyPlayer" or p.kind == "enemyPlayer" then title = NP.PlayerTitle(p.unit)
        else title = NP.NPCTitle(p.unit) end
    end
    if not title then fs:Hide() return end
    fs:SetText(title)
    -- its own colour, apart from the name's: the palette's light bronze, a tan as other
    -- nameplate addons draw titles in
    local c = ns.PALETTE.bronze5
    fs:SetTextColor(c[1], c[2], c[3], 1)
    fs:Show()
end

function NP.UpdateLevel(p)
    local db, unit = PDB(p), p.unit
    local showRarity = not p.nameOnly and db.rarityIcon ~= false
    local classification
    if showRarity or (p.levelShown and not p.levelFollow) then classification = Readable(UnitClassification(unit)) end
    -- elite gold, rare silver
    local atlas
    if showRarity then
        if classification == "elite" or classification == "worldboss" then atlas = C.ELITE_GOLD
        elseif classification == "rare" or classification == "rareelite" then atlas = C.ELITE_SILVER end
    end
    if atlas and C_Texture.GetAtlasInfo(atlas) then p.elite:SetAtlas(atlas) p.elite:Show() else p.elite:Hide() end
    if p.levelFollow then NP.UpdateName(p) return end
    if not p.levelShown then return end
    local level = ns.UnitShownLevel(unit)
    if not canaccessvalue(level) then p.level:SetText("") return end
    if type(level) == "number" and level < 0 or classification == "worldboss" then
        ns.SetHighLevelText(p.level)
        return
    end
    p.level:SetText(level)
    local color = ns.UnitLevelColor(unit, level)
    if color then p.level:SetTextColor(color.r, color.g, color.b) else p.level:SetTextColor(1, 0.82, 0) end
end

-- GetRaidTargetIndex can be secret: a secret is never nil, so it means a marker is set
function NP.UpdateRaid(p)
    local index = GetRaidTargetIndex(p.unit)
    local show
    if not canaccessvalue(index) then show = true else show = index ~= nil and index > 0 end
    if show then SetRaidTargetIconTexture(p.raid, index) end
    p.raid:SetShown(show)
end

-- Your target: the bright border, Target Scale, full opacity. Compared by plate (UnitIsUnit can be
-- secret; the plate for "target" is a plain frame).
function NP.UpdateTarget(p, targetPlate)
    local db = PDB(p)
    local isTarget = p.gamePlate ~= nil and p.gamePlate == targetPlate
    if p.sample then isTarget = p.sampleTarget or false end
    if p.targetShown == isTarget then return end
    p.targetShown = isTarget
    ApplyVisual(p, "PaintBorder")
    p.outline:SetShown(isTarget and not p.edgeFile and db.targetBorder ~= false)
    NP.UpdateTargetLook(p)
    ApplyVisual(p, "ApplyScale")
    ApplyVisual(p, "UpdateFade")
    if not p.sample and NP.Sab then pcall(NP.Sab.Apply, p) end
end

-- The border: your target's colour, else the threat colour (Threat Glow), else bronze
function NP.PaintBorder(p)
    local db = PDB(p)
    local c
    if p.targetShown and db.targetBorder ~= false then c = NP.Color("target", p.sample)
    elseif db.threatGlow and p.threatRGB then c = p.threatRGB end
    -- Threat Glow: the pulsing border and its glow too (not over your target's own border)
    local threat = c ~= nil and c == p.threatRGB and not p.nameOnly
    -- (always on) the plate under the mouse: its border a little lighter, whatever
    -- colour it has (the bronze, your target's or threat's); the bar's light is p.highlight (SetMouseover)
    local hover = state.mouseover == p and NP.HoverParts().border or false
    local r1, g1, b1 = c and c[1], c and c[2], c and c[3]
    if not p.borderDirty and p.paintedThreat == threat and p.paintedHover == hover and p.paintedR == r1 and p.paintedG == g1 and p.paintedB == b1 then return end
    p.paintedThreat, p.paintedHover, p.paintedR, p.paintedG, p.paintedB = threat, hover, r1, g1, b1
    p.borderDirty = false
    p.threatFx:SetShown(threat)
    if threat then
        NP.PaintImportantGlow(p.threatFx, c)
        if not p.threatFx.pulse:IsPlaying() then p.threatFx.pulse:Play() end
    end
    -- the level disc takes the same colour (the box's border below, with the plate's)
    if c then p.levelArt:SetVertexColor(c[1], c[2], c[3]) else p.levelArt:SetVertexColor(1, 1, 1) end
    if not p.edgeFile then return end
    local b = ns.BORDER_COLOR
    local r, g, bl, a
    if c then r, g, bl, a = c[1], c[2], c[3], 1 else r, g, bl, a = b.r, b.g, b.b, b.a end
    if hover then
        local k = C.HOVER_BORDER
        r, g, bl = r + (1 - r) * k, g + (1 - g) * k, bl + (1 - bl) * k
    end
    p.border:SetBackdropBorderColor(r, g, bl, a)
    p.levelBorder:SetBackdropBorderColor(r, g, bl, a)
end

-- whether this plate's casts are an enemy's, which you could interrupt (Kick Ready and its mark)
function NP.Kickable(p)
    if C.FRIENDLY[p.kind] or not p.unit then return false end
    local can = UnitCanAttack("player", p.unit)
    if not canaccessvalue(can) then return true end
    return can and true or false
end

-- Kick Ready Mark: while your interrupt is cooling down, a spark where on this cast it will be ready
-- (none on a cast you can't interrupt; gone once it's ready, when Kick Ready colours the bar)
function NP.UpdateKickMark(p, db, duration, channeling, notInterruptible)
    local cast = p.cast
    local KICK = UF and UF.KICK
    local spellID = db.castKickMark and KICK and KICK.Active and NP.Kickable(p) and KICK.Active()
    local wait = spellID and C_Spell.GetSpellCooldownDuration and C_Spell.GetSpellCooldownDuration(spellID, true)
    if not (spellID and wait and duration) or KICK.IsReady() then cast.kickClip:Hide() return end
    local ok = pcall(function()
        local total = duration:GetTotalDuration()
        cast.kickNow:SetReverseFill(channeling and true or false)
        cast.kickWait:SetReverseFill(channeling and true or false)
        cast.kickNow:SetMinMaxValues(0, total)
        cast.kickWait:SetMinMaxValues(0, total)
        cast.kickNow:SetValue(duration:GetElapsedDuration())
        cast.kickWait:SetValue(wait:GetRemainingDuration())
    end)
    if not ok then cast.kickClip:Hide() return end
    NP.PlaceKickMark(cast, channeling)
    if not pcall(cast.kickClip.SetAlphaFromBoolean, cast.kickClip, notInterruptible, 0, 1) then cast.kickClip:SetAlpha(1) end
    cast.kickClip:Show()
end
-- (a channel drains from the right: its timeline runs the other way)
function NP.PlaceKickMark(cast, channeling)
    local nowFill, waitFill = cast.kickNow:GetStatusBarTexture(), cast.kickWait:GetStatusBarTexture()
    cast.kickWait:ClearAllPoints()
    cast.kickSpark:ClearAllPoints()
    if channeling then
        cast.kickWait:SetPoint("TOPRIGHT", nowFill, "TOPLEFT")
        cast.kickSpark:SetPoint("CENTER", waitFill, "LEFT")
    else
        cast.kickWait:SetPoint("TOPLEFT", nowFill, "TOPRIGHT")
        cast.kickSpark:SetPoint("CENTER", waitFill, "RIGHT")
    end
end

-- the cast bar: secret-safe as the unit frames' (the client times the bar; the uninterruptible grey
-- and the shield come from the flag through "from boolean" calls)
local function CastDetails(channel, ...)
    if select("#", ...) == 0 then return end   -- only the result count is always readable
    local name, text, texture = ...
    local notInterruptible, spellID, barID, guid
    if channel then
        notInterruptible, spellID = select(7, ...)
        barID = select(11, ...)
    else
        guid, notInterruptible, spellID, barID = select(7, ...)
    end
    return channel, name, text, texture, notInterruptible, spellID, barID, guid
end

-- Compare cast instances. Channels expose only the bar ID in the live query.
local function SameCast(barID, guid, liveBarID, liveGUID)
    if barID ~= nil then
        local id = Readable(liveBarID)
        if id ~= nil then return barID == id end
    end
    if guid then
        local id = Readable(liveGUID)
        if id then return guid == id end
    end
end

local function ReadCastTarget(unit, db)
    local name, color, readAim, aimedAtPlayer
    if db.castTarget and UnitSpellTargetName then
        local ok
        ok, name = pcall(UnitSpellTargetName, unit)
        if not ok then name = "" end
        local okClass, class = pcall(UnitSpellTargetClass, unit)
        if okClass then
            ok, color = pcall(C_ClassColor.GetClassColor, class)
            if not ok then color = nil end
        end
    end
    if db.castTargetedFlash and PlayerIsSpellTarget then
        readAim, aimedAtPlayer = pcall(PlayerIsSpellTarget, unit)
    end
    return name, color, readAim, aimedAtPlayer
end

local function PaintCastTarget(cast, unit, db, start)
    local name, color, readAim, aimedAtPlayer
    if start then
        name, color, readAim, aimedAtPlayer = start.targetName, start.targetColor, start.readAim, start.aimedAtPlayer
    else
        name, color, readAim, aimedAtPlayer = ReadCastTarget(unit, db)
    end
    if db.castTarget and UnitSpellTargetName then
        cast.target:SetText(name)
        if color then cast.target:SetTextColor(color:GetRGB()) else cast.target:SetTextColor(1, 1, 1) end
        cast.target:Show()
    else
        cast.target:Hide()
    end
    if db.castTargetedFlash and PlayerIsSpellTarget then
        if not (readAim and pcall(cast.targeted.SetAlphaFromBoolean, cast.targeted, aimedAtPlayer, 1, 0)) then
            cast.targeted:SetAlpha(0)
        end
        if not cast.targetedPulse:IsPlaying() then cast.targetedPulse:Play() end
    else
        cast.targeted:SetAlpha(0)
        cast.targetedPulse:Stop()
    end
end

function NP.UpdateCast(p, pending)
    local cast, unit, db = p.cast, p.unit, PDB(p)
    if not cast or NP.testing then return end   -- (Test on Plates draws its own casts)
    if not (unit and db.castbar) then cast:Hide() return end
    local channeling, name, text, texture, notInterruptible, spellID, castBarID, liveGUID = CastDetails(false, UnitCastingInfo(unit))
    if channeling == nil then
        channeling, name, text, texture, notInterruptible, spellID, castBarID = CastDetails(true, UnitChannelInfo(unit))
    end
    -- A follow-up STOP has no interrupter, and the client may already be casting
    -- something else. A live cast wins unless we can identify it as the interrupted one.
    if pending and pending.interrupt and (channeling == nil or
        SameCast(pending.barID, pending.interruptGUID, castBarID, liveGUID)) then
        if pending.start then
            -- A cast can start and get kicked before this plate is next painted.
            -- The client may already have cleared its icon and target.
            UF.EndCastFlash(cast)
            local icon = pending.texture
            if UF.CastIcon then icon = UF.CastIcon(icon, pending.spellID, false) end
            cast.Icon:SetTexture(icon)
            cast.castBarID, cast.castGUID, cast.isChannel = pending.startBarID, pending.guid, pending.channel
            PaintCastTarget(cast, unit, db, pending)
            cast:Show()
        end
        if cast:IsShown() and not cast.flashing then
            UF.FlashInterrupted(cast, pending.by)
            cast.kickClip:Hide()
            cast.shield:SetAlpha(0)
            cast.important:SetAlpha(0)
            return
        end
        if cast.flashing then return end
    end
    if channeling == nil then
        if pending and pending.start then UF.EndCastFlash(cast) end
        if not cast.flashing then cast:Hide() end
        return
    end
    UF.EndCastFlash(cast)
    local start = pending and pending.start and pending
    if start then
        local same = SameCast(start.startBarID, start.guid, castBarID, liveGUID)
        if start.channel ~= channeling or same == false
            or (same == nil and (start.ended or start.interrupt or start.startBarID ~= nil)) then
            start = nil
        end
    end
    if start then
        cast.castGUID = start.guid or liveGUID
    elseif not channeling then
        cast.castGUID = liveGUID
    elseif pending or not cast.isChannel then
        cast.castGUID = nil
    end
    cast.castBarID, cast.isChannel = castBarID, channeling
    local duration
    if channeling then duration = UnitChannelDuration(unit) else duration = UnitCastingDuration(unit) end
    if canaccessvalue(duration) and not duration then cast:Hide() return end
    local direction = channeling and Enum.StatusBarTimerDirection.RemainingTime or Enum.StatusBarTimerDirection.ElapsedTime
    cast:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, direction)
    if cast.TimerBinding then pcall(cast.TimerBinding.SetDuration, cast.TimerBinding, duration) end
    local label = text
    if canaccessvalue(text) and not text then
        label = name
        if canaccessvalue(name) and not name then label = "" end
    end
    cast.Text:SetText(label)
    if UF.CastIcon then texture = UF.CastIcon(texture, spellID, false) end
    cast.Icon:SetTexture(texture)
    local base = NP.Color(channeling and "channel" or "cast")
    -- Kick Ready: an enemy cast you could interrupt, while your interrupt is ready
    if db.kickReady and UF.KICK and NP.Kickable(p) and UF.KICK.IsReady() then base = NP.Color("kickReady") end
    if canaccessvalue(notInterruptible) then
        local color = notInterruptible and NP.Color("castNoInterrupt") or base
        cast:SetStatusBarColor(color[1], color[2], color[3])
        cast.shield:SetAlpha(notInterruptible and 1 or 0)
    else
        local nk = NP.Color("castNoInterrupt")
        cast.noKick = cast.noKick or CreateColor(1, 1, 1)
        cast.noKick:SetRGB(nk[1], nk[2], nk[3])
        cast.baseColor = cast.baseColor or CreateColor(1, 1, 1)
        cast.baseColor:SetRGB(base[1], base[2], base[3])
        cast:GetStatusBarTexture():SetVertexColorFromBoolean(notInterruptible, cast.noKick, cast.baseColor)
        if not pcall(cast.shield.SetAlphaFromBoolean, cast.shield, notInterruptible, 1, 0) then cast.shield:SetAlpha(0) end
    end
    NP.UpdateKickMark(p, db, duration, channeling, notInterruptible)
    -- Highlight Important Casts and casts at you: Blizzard's own flags, through the alpha
    local important = false
    if db.castImportant and C_Spell and C_Spell.IsSpellImportant then
        local ok, v = pcall(C_Spell.IsSpellImportant, spellID)
        if ok then important = v end
    end
    if not pcall(cast.important.SetAlphaFromBoolean, cast.important, important, 1, 0) then cast.important:SetAlpha(0) end
    PaintCastTarget(cast, unit, db, start)
    cast:Show()
end

--------------------------------------------------
-- 5b. PHASE 2: EXECUTE, MOB TYPES, QUESTS, TITLES, FADING
--------------------------------------------------
-- Execute Range: where it starts (0..1), or nil when it's off or your class has none on Auto. A
-- spell name only finds a spell you know (any rank).
function NP.ExecuteAt(db)
    local v = db.execute
    if not v or v == "off" then return nil end
    if v ~= "auto" then return (tonumber(v) or 0) / 100 end
    local _, class = UnitClass("player")
    local e = C.EXECUTE[class]
    local name = e and C_Spell.GetSpellName(e[1])
    local ok, info = false, nil
    if name then ok, info = pcall(C_Spell.GetSpellInfo, name) end
    if ok and info then return e[2] end
end

local execCurves = {}
local function ExecCurve(at)
    local curve = execCurves[at]
    if curve == nil then
        curve = false
        local ok, made = pcall(C_CurveUtil.CreateCurve)
        if ok and made then
            made:SetType(Enum.LuaCurveType.Step)
            made:AddPoint(0, 1)
            made:AddPoint(at, 0)
            curve = made
        end
        execCurves[at] = curve
    end
    return curve or nil
end

-- the tint shows below the threshold: the client turns the percent into its alpha
function NP.UpdateExecute(p)
    local at = p.execAt
    if not at then return end
    local curve = ExecCurve(at)
    if curve then p.execTint:SetAlpha(UnitHealthPercent(p.unit, false, curve)) end
end

-- Mob type colours (Boss, Elite, Caster, Trivial; each its own switch), in instances only unless set
-- otherwise. A caster is an NPC with mana.
function NP.MobRGB(unit, db)
    if not (db.colorBoss or db.colorElite or db.colorCaster or db.colorTrivial) then return nil end
    if db.mobTypesWhere ~= "everywhere" then
        local inside, kind = IsInInstance()
        if not inside or (kind ~= "party" and kind ~= "raid") then return nil end
    end
    if Readable(UnitIsPlayer(unit)) then return nil end
    local classification = Readable(UnitClassification(unit))
    local level = Readable(UnitLevel(unit))
    local c
    if db.colorBoss and (classification == "worldboss" or level == -1) then c = NP.Color("boss")
    elseif db.colorElite and (classification == "elite" or classification == "rareelite") then c = NP.Color("elite")
    elseif db.colorTrivial and (classification == "trivial" or classification == "minus") then c = NP.Color("trivial")
    elseif db.colorCaster then
        local powerType = Readable(UnitPowerType(unit))
        local max = powerType == 0 and Readable(UnitPowerMax(unit, 0))
        if type(max) == "number" and max > 0 then c = NP.Color("caster") end
    end
    if c then return c[1], c[2], c[3] end
end

-- Quest Marks: the "!" on units your quests need, with what's left of the first objective not done
-- ("3/8", "40%"), read from the unit's tooltip. Open world only (inside, quest data is hidden).
-- Returns the text ("" with no number), nil for no quest, or false when it can't be read now.
function NP.QuestProgress(unit)
    local related = C_QuestLog.UnitIsRelatedToActiveQuest and C_QuestLog.UnitIsRelatedToActiveQuest(unit)
    if not canaccessvalue(related) then return false end
    if not related then return nil end
    if IsInInstance() then return "" end
    local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
    if not (ok and data and data.lines) then return "" end
    local T = Enum.TooltipDataLineType
    local me = UnitName("player")
    local mine, objectives = false, 0
    for i = 2, #data.lines do
        local line = data.lines[i]
        local text = line.leftText
        if not canaccessvalue(text) then return false end
        if type(text) == "string" then
            if line.type == T.QuestTitle then
                mine = true
            elseif line.type == T.QuestPlayer then
                mine = text == me
            elseif line.type == T.QuestObjective and mine then
                objectives = objectives + 1
                local cur, goal = text:match("(%d+)%s*/%s*(%d+)")
                if cur and tonumber(cur) < tonumber(goal) then return cur .. "/" .. goal end
                local pct = not cur and text:match("(%d+)%%")
                if pct and tonumber(pct) < 100 then return pct .. "%" end
            end
        end
    end
    -- objectives listed and all done: nothing left to do on this unit
    if objectives > 0 then return nil end
    return ""
end

-- Objective Icon (nameplates.questMarks) and Objective Progress
-- (nameplates.questProgress; never set, it follows the icon, as before the two were split)
-- Objective Icon and Progress, per type: the icon needs the shared quest switch
-- and the type's own Objective Icon; Progress never set follows the icon.
-- With no plate: whether any type shows them (the module's quest events).
local function TypeQuest(tdb, master)
    local icon = master and tdb.questIcon ~= false
    local progress = tdb.questProgress
    if progress == nil then progress = icon end
    return icon and true or false, progress and true or false
end
-- Questie draws its own quest icons on nameplates. Read each time: its option applies live
function NP.QuestieHasIcons()
    local questie = _G.Questie
    local db = type(questie) == "table" and questie.db
    local profile = type(db) == "table" and db.profile
    return type(profile) == "table" and profile.nameplateEnabled == true
end
-- Questie hangs its icon on the game's plate, which stays one size while ours grows and shrinks around
-- your target, so the icon sat elsewhere on your target's plate, over the level box. Its left
-- point goes on the leftmost of our parts instead (the bar, the level box, a marker beside them); its settings,
-- size and parent stay Questie's. The same point goes back when the unit's plate does (Questie's own
-- SetPoint replaces it on reuse anyway).
function NP.FixQuestie(p)
    local plate = p.gamePlate
    if not (plate and NP.QuestieHasIcons()) then return end
    local profile = _G.Questie.db.profile
    local x, y = tonumber(profile.nameplateX), tonumber(profile.nameplateY)
    if not (x and y) then return end
    local outer = (not p.nameOnly and p.questSide == "right" and p.raid and p.raid:IsShown() and p.raid)
        or p.leftOf or p.root
    for _, child in ipairs({ plate:GetChildren() }) do
        if not child:IsForbidden() and child.Icon and child.lastIcon then
            p.questie = child
            child:SetPoint("LEFT", outer, "LEFT", x, y)
        end
    end
end
function NP.ReturnQuestie(p)
    local child, plate = p.questie, p.gamePlate
    p.questie = nil
    if not (child and plate and child:GetParent() == plate and NP.QuestieHasIcons()) then return end
    local profile = _G.Questie.db.profile
    child:SetPoint("LEFT", plate, "LEFT", tonumber(profile.nameplateX) or 0, tonumber(profile.nameplateY) or 0)
end
function NP.QuestParts(p, preview)
    local shared = SharedSettings(preview or (p and p.sample))
    local master = (shared and shared.questMarks) and true or false
    if NP.QuestieHasIcons() then return false, false end
    if p then return TypeQuest(PDB(p), master) end
    local anyIcon, anyProgress = false, false
    for _, kind in ipairs(C.KINDS) do
        local i, pr = TypeQuest(NP.TypeDB(kind, true, preview), master)
        anyIcon, anyProgress = anyIcon or i, anyProgress or pr
    end
    return anyIcon, anyProgress
end
-- SHOW PLATES IN COMBAT (Plate > Name Only Mode): the unit types picked there leave
-- Name Only Mode while you are in a fight and show their whole plate (nameplates.combatPlates, a list
-- of types, "none" first). Entering and leaving combat lays the plates out again (NP.Relayout).
function NP.CombatList(preview)
    local cache = SettingsFor(preview)
    if cache then return cache.combatTypes end
    local db = DB()
    return CombatTypes(db and db.combatPlates)
end
function NP.CombatFull(kind, preview)
    return state.combat and kind ~= nil and NP.CombatList(preview)[kind] or false
end
-- A fight began or ended: only the plates on screen whose look changes (a Name Only type picked in
-- Show Plates in Combat) come off and are claimed again, which lays them out (no settings or game
-- options touched: fine in a fight). Spare plates are laid out when claimed (NP.Claim checks layFull).
function NP.Relayout()
    if not NP.ready then return end
    local stale = {}
    for _, p in pairs(byPlate) do
        if p.layFull ~= NP.CombatFull(p.layKind) then stale[#stale + 1] = p end
    end
    if #stale == 0 then return end
    for _, p in ipairs(stale) do NP.ReleasePlate(p) end
    NP.Sync()
end

-- Combo Points per type: asked before the points go on your target's plate (NameplateExtras.lua)
function NP.ComboAllowed(unit)
    if not NP.ready or NP.standDown then return true end
    local want, kind = NP.WantsPlate(unit)
    if not want or not kind then return true end
    local tdb = NP.TypeDB(kind, true)
    -- a Name Only plate has no bar to hang them from (unless Show Plates in Combat gives it one)
    if tdb.plate == "name" and not NP.CombatFull(kind) then return false end
    return tdb.combo ~= false
end
function NP.QuestOn(preview)
    local icon, progress = NP.QuestParts(nil, preview)
    return icon or progress
end

function NP.UpdateQuest(p)
    local icon, showProgress = NP.QuestParts(p)
    local progress
    if icon or showProgress then
        progress = NP.QuestProgress(p.unit)
        if progress == false then return end   -- unreadable now: kept as it was
        p.questText:SetText(progress or "")
    end
    local showIcon = icon and progress ~= nil or false
    local showText = showProgress and progress ~= nil and progress ~= "" or false
    local iconChanged = p.quest:IsShown() ~= showIcon
    local textChanged = p.questText:IsShown() ~= showText
    if iconChanged then p.quest:SetShown(showIcon) end
    if textChanged then p.questText:SetShown(showText) end
    if iconChanged or textChanged or (paint.plate == p and paint.PlaceSides) then
        RequestSideLayout(p, showIcon, showText)
    end
end

-- Follow Name: the level, coloured, and a space, to go in front of the name (nil when unreadable)
function NP.LevelPrefix(unit)
    local level = ns.UnitShownLevel(unit)
    if not canaccessvalue(level) or type(level) ~= "number" then return nil end
    local classification = Readable(UnitClassification(unit))
    if level < 0 or classification == "worldboss" then return ns.HIGH_LEVEL_SKULL .. " " end
    local c = ns.UnitLevelColor(unit, level) or { r = 1, g = 0.82, b = 0 }
    return ("|cff%02x%02x%02x%d|r "):format(c.r * 255 + 0.5, c.g * 255 + 0.5, c.b * 255 + 0.5, level)
end

-- Non-Target Opacity: with a target, other plates dim; your target and casting units stay full
function NP.UpdateFade(p, targetState)
    local db = PDB(p)
    if not (db and p.unit) then return end
    -- Targeting: your target's opacity, the others' while you have one, or every plate's with no
    -- target; the plate under the mouse and a casting one stay clear
    local alpha
    if p.targetShown then alpha = db.targetAlpha or 1
    else alpha = OtherPlateValue(targetState, db.nonTargetAlpha, db.noTargetAlpha) end
    if alpha < 1 and not p.targetShown and (state.mouseover == p or (p.cast and p.cast:IsShown())) then alpha = 1 end
    p.root:SetAlpha(alpha)
end

-- Out of Range Opacity: your class's spells by name (any rank); in range if any one is. A secret
-- answer goes to the holder's alpha unread.
-- the alpha is written only when it changes (p.rangeAlphaNow; nil after a claim
-- or a secret answer), friendly plates are never checked (the list is attack spells)
function NP.SetRangeAlpha(p, a)
    if p.rangeAlphaNow == a then return end
    p.rangeAlphaNow = a
    p.holder:SetAlpha(a)
end
function NP.UpdateRange(p)
    local db = PDB(p)
    local alpha = db and db.rangeAlpha or 1
    if alpha >= 1 or not p.unit or C.FRIENDLY[p.kind] then NP.SetRangeAlpha(p, 1) return end
    local _, class = UnitClass("player")
    local list = C.RANGE[class]
    if class == "DRUID" and C.MELEE_FORMS[GetShapeshiftFormID and GetShapeshiftFormID() or 0] then list = C.RANGE.DRUID_MELEE end
    if not list then NP.SetRangeAlpha(p, 1) return end
    local out, hasSecret, secret = false, false, nil
    for _, id in ipairs(list) do
        -- (spell names by ID never change: looked up once)
        local name = C.RANGE_NAMES[id]
        if not name then
            name = C_Spell.GetSpellName(id)
            C.RANGE_NAMES[id] = name
        end
        local ok, r = false, nil
        if name then ok, r = pcall(C_Spell.IsSpellInRange, name, p.unit) end
        if ok then
            if not canaccessvalue(r) then
                if not hasSecret then hasSecret, secret = true, r end
            elseif r == true then
                NP.SetRangeAlpha(p, 1)
                return
            elseif r == false then
                out = true
            end
        end
    end
    if hasSecret and pcall(p.holder.SetAlphaFromBoolean, p.holder, secret, 1, alpha) then p.rangeAlphaNow = nil return end
    NP.SetRangeAlpha(p, out and alpha or 1)
end

function NP.UpdateAll(p)
    if not p.unit then return end
    NP.UpdateHealth(p, false)
    NP.UpdateHeals(p)
    if not p.healthTint then NP.UpdateColor(p) end
    NP.UpdateName(p)
    NP.UpdateTitle(p)
    NP.UpdateLevel(p)
    NP.UpdateRaid(p)
    NP.UpdateTarget(p, C_NamePlate.GetNamePlateForUnit("target"))
    NP.UpdateCast(p)
    NP.UpdateQuest(p)
    NP.UpdateFade(p)
    NP.UpdateRange(p)
end

--------------------------------------------------
-- 6. EVENTS PER PLATE
--------------------------------------------------
local UNIT_EVENTS = {
    "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_ABSORB_AMOUNT_CHANGED",
    "UNIT_HEAL_PREDICTION", "UNIT_NAME_UPDATE", "UNIT_FACTION", "UNIT_THREAT_LIST_UPDATE", "UNIT_LEVEL",
    "UNIT_CLASSIFICATION_CHANGED", "UNIT_FLAGS",
}
local CAST_EVENTS = (K and K.CAST_EVENTS) or {}

-- Only public flags enter the mask. Health, absorbs and cast data stay in the client-facing helpers.
local queue = { plates = {}, processing = {}, world = 0, driver = CreateFrame("Frame") }
NP.updateQueue = queue
queue.driver:Hide()
local function WakeQueue()
    if queue.scheduled then return end
    queue.scheduled = true
    queue.driver:Show()
end
function NP.QueuePlate(p, mask)
    if not p.unit then return end
    queue.plates[p] = bor(queue.plates[p] or 0, mask)
    WakeQueue()
end
local function QueueWorld(mask)
    queue.world = bor(queue.world, mask)
    WakeQueue()
end
local function OnUnitEvent(self, event)
    local p = self.plate
    if not p.unit then return end
    if event == "UNIT_HEALTH" then
        NP.QueuePlate(p, D.HEALTH)
    elseif event == "UNIT_MAXHEALTH" then
        NP.QueuePlate(p, D.MAXHEALTH)
    elseif event == "UNIT_ABSORB_AMOUNT_CHANGED" then
        NP.QueuePlate(p, D.ABSORB)
    elseif event == "UNIT_HEAL_PREDICTION" then
        NP.QueuePlate(p, D.HEALS)
    elseif event == "UNIT_HEAL_ABSORB_AMOUNT_CHANGED" then
        NP.QueuePlate(p, bor(D.HEALS, D.ABSORB))
    elseif event == "UNIT_FACTION" then
        -- its type changed (turned friendly or hostile): claimed again as the new type, or back to Blizzard
        local want, kind = NP.WantsPlate(p.unit)
        if not want or kind ~= p.kind then
            local unit = p.unit
            NP.ReleasePlate(p)
            if want then NP.Claim(unit) end
            return
        end
        NP.QueuePlate(p, D.COLOR)
    elseif event == "UNIT_THREAT_LIST_UPDATE" or event == "UNIT_FLAGS" then
        -- Name Only While Unattackable: it became attackable (or stopped being): laid out again
        if event == "UNIT_FLAGS" and not NP.testKind and NP.Peaceful(p.unit, p.kind) ~= (p.layKind == "peaceful") then
            local unit = p.unit
            NP.ReleasePlate(p)
            NP.Claim(unit)
            return
        end
        -- a pull sends many of these per mob in one frame: one repaint per frame
        NP.QueuePlate(p, D.COLOR)
    elseif event == "UNIT_NAME_UPDATE" then
        NP.QueuePlate(p, bor(D.NAME, D.COLOR))
    elseif event == "UNIT_LEVEL" or event == "UNIT_CLASSIFICATION_CHANGED" then
        NP.QueuePlate(p, D.LEVEL)
    end
end

function NP.ResetPendingCast(p)
    p.pendingCast = nil
    if p.cast then p.cast.castBarID, p.cast.castGUID, p.cast.isChannel = nil, nil, nil end
end

function NP.FlushCast(p)
    local pending = p.pendingCast
    p.pendingCast = nil
    NP.UpdateCast(p, pending)
end

local function OnCastEvent(self, event, unit, castGUID, spellID, by, barID)
    local p = self.plate
    if not p.unit then return end
    if not event:find("^UNIT_SPELLCAST") then
        OnUnitEvent(self, event, unit)
        return
    end
    local db = PDB(p)
    if not p.cast or not db.castbar or NP.testing then return end
    local pending = p.pendingCast
    local captureTarget
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        pending = { start = true, channel = event == "UNIT_SPELLCAST_CHANNEL_START", spellID = spellID, guid = Readable(castGUID) }
        p.pendingCast = pending   -- a new cast replaces an older interrupt, even on the same unit
        if pending.channel then
            local _, _, icon, _, _, _, _, _, _, _, id = UnitChannelInfo(p.unit)
            pending.texture, pending.startBarID = icon, Readable(id)
        else
            local _, _, icon, _, _, _, guid, _, _, id = UnitCastingInfo(p.unit)
            pending.texture, pending.startBarID = icon, Readable(id)
            if not pending.guid and not pending.startBarID then pending.guid = Readable(guid) end
        end
        -- START carries the bar ID in the fourth event argument.
        if not pending.startBarID then pending.startBarID = Readable(by) end
        captureTarget = true
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" or
        (event == "UNIT_SPELLCAST_CHANNEL_STOP" and not (canaccessvalue(by) and by == nil)) then
        local currentID, currentGUID, isChannel
        if pending and pending.start then
            currentID, currentGUID, isChannel = pending.startBarID, pending.guid, pending.channel
        else
            currentID, currentGUID, isChannel = Readable(p.cast.castBarID), Readable(p.cast.castGUID), p.cast.isChannel
        end
        local guid, id = Readable(castGUID), Readable(barID)
        if (event == "UNIT_SPELLCAST_INTERRUPTED" or isChannel)
            and (not guid or not currentGUID or guid == currentGUID)
            and (not id or not currentID or id == currentID) then
            pending = pending or {}
            if not pending.interrupt or not (canaccessvalue(by) and by == nil) then pending.by = by end
            -- An unreadable event ID cannot identify the live cast by itself.
            -- Its START's bar ID is usable only when the event GUID matches that START.
            pending.interrupt = true
            pending.interruptGUID = guid or pending.interruptGUID
            pending.barID = id or (guid and guid == currentGUID and currentID) or pending.barID
            p.pendingCast = pending
        end
    elseif pending and pending.start and (event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP"
            or event == "UNIT_SPELLCAST_FAILED") then
        pending.ended = true
    elseif pending and pending.start and not pending.interrupt then
        captureTarget = event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE"
                     or event == "UNIT_SPELLCAST_INTERRUPTIBLE" or event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE"
    end
    if captureTarget then
        -- Once interrupted, a spell no longer exposes its target. Keep the latest one with its icon.
        pending.targetName, pending.targetColor, pending.readAim, pending.aimedAtPlayer = ReadCastTarget(p.unit, db)
    end
    NP.QueuePlate(p, D.CAST)
end

--------------------------------------------------
-- 7. CLAIM / RELEASE (the safety net)
--------------------------------------------------
local Release

-- Blizzard's unit frame goes invisible; its widgets (quest progress, gather icons) and the
-- soft-target icon move onto the plate so they still show. Blizzard sets the frame's alpha on its own
-- updates (its range fade), so a hook puts it back to 0 while we hold the frame.
-- Its unit events go quiet too (no work for a plate nobody sees). Blizzard registers them again
-- itself whenever it hands the frame a new unit (CompactUnitFrame_SetUnit, the cast bar's SetUnit,
-- OnUnitSet), so only a plate handed back while its unit is still there (it turned friendly, a
-- failed check) needs them back: each one is noted with its units and registered again then.
C.QUIET = {
    frame = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_MAX_HEALTH_MODIFIERS_CHANGED", "UNIT_ABSORB_AMOUNT_CHANGED",
              "UNIT_HEAL_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_PREDICTION", "UNIT_AURA", "UNIT_THREAT_LIST_UPDATE",
              "UNIT_THREAT_SITUATION_UPDATE", "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_FLAGS", "UNIT_FACTION",
              "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_CONNECTION", "UNIT_PHASE",
              "UNIT_IN_RANGE_UPDATE", "UNIT_DISTANCE_CHECK_UPDATE", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
              "RAID_TARGET_UPDATE" },
    cast = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
             "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE",
             "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" },
}
local function Quiet(p, frame, list)
    if not frame or frame:IsForbidden() then return end
    for _, event in ipairs(list) do
        local ok, registered, unit1, unit2 = pcall(frame.IsEventRegistered, frame, event)
        if ok and registered then
            -- (the records are used again: a claim made some twenty new tables)
            local rec = table.remove(p.quietSpare) or {}
            rec[1], rec[2], rec[3], rec[4] = frame, event, unit1, unit2
            p.quieted[#p.quieted + 1] = rec
            pcall(frame.UnregisterEvent, frame, event)
        end
    end
end
local function Unquiet(p, live)
    for i, rec in ipairs(p.quieted) do
        if live then
            local frame, event, unit1, unit2 = rec[1], rec[2], rec[3], rec[4]
            if unit1 then pcall(frame.RegisterUnitEvent, frame, event, unit1, unit2)
            else pcall(frame.RegisterEvent, frame, event) end
        end
        rec[1], rec[2], rec[3], rec[4] = nil, nil, nil, nil
        p.quietSpare[#p.quietSpare + 1] = rec
        p.quieted[i] = nil
    end
end
local muted = setmetatable({}, { __mode = "k" })
local hooked = setmetatable({}, { __mode = "k" })
local inAlphaHook = false
local function KeepHidden(frame)
    if inAlphaHook or not muted[frame] then return end
    inAlphaHook = true
    frame:SetAlpha(0)
    inAlphaHook = false
end
local function HideBlizzard(p, unitFrame)
    p.blizz = unitFrame
    muted[unitFrame] = true
    if not hooked[unitFrame] then
        hooked[unitFrame] = true
        hooksecurefunc(unitFrame, "SetAlpha", KeepHidden)
    end
    KeepHidden(unitFrame)
    p.quieted, p.quietSpare = p.quieted or {}, p.quietSpare or {}
    Quiet(p, unitFrame, C.QUIET.frame)
    Quiet(p, unitFrame.CastBarsContainer and unitFrame.CastBarsContainer.castBar, C.QUIET.cast)
    p.moved = p.moved or {}
    for _, key in ipairs({ "WidgetContainer", "SoftTargetFrame" }) do
        local child = unitFrame[key]
        if child and not child:IsForbidden() then
            child:SetParent(p.gamePlate)
            p.moved[key] = child
        end
    end
end

-- Everything back as Blizzard had it: the unit frame visible, its children at home. live: the frame
-- still shows its unit on this plate, so its quieted events come back (otherwise Blizzard has let
-- go of it and registers them itself for its next unit).
local function ShowBlizzard(p, live)
    local unitFrame = p.blizz
    if not unitFrame then return end
    muted[unitFrame] = nil
    if p.quieted then Unquiet(p, live) end
    if p.moved then
        for key, child in pairs(p.moved) do
            if not child:IsForbidden() then child:SetParent(unitFrame) end
            p.moved[key] = nil
        end
    end
    unitFrame:SetAlpha(1)
    p.blizz = nil
end

local function RegisterUnit(p, unit)
    local ev = p.events
    ev:UnregisterAllEvents()
    for _, event in ipairs(UNIT_EVENTS) do ev:RegisterUnitEvent(event, unit) end
    if PDB(p).castbar then
        for _, event in ipairs(CAST_EVENTS) do ev:RegisterUnitEvent(event, unit) end
    end
    ev:SetScript("OnEvent", OnCastEvent)
end

-- A unit's plate type: enemyPlayer, enemyNpc, friendlyPlayer, friendlyNpc or minor (NP.WantsPlate
-- checks the type's Plate). nil: the game couldn't say yet (a plate far away can arrive before its
-- unit's reaction).
function NP.Kind(unit)
    local canAttack = Readable(UnitCanAttack("player", unit))
    local friend = Readable(UnitIsFriend("player", unit))
    if canAttack == nil and friend == nil then return nil end
    local player = Readable(UnitIsPlayer(unit))
    -- (pets, totems and guardians are Minor on either side: the game's own check, as Blizzard's
    -- plates use; a mob under Mind Control stays what it is)
    local minion
    if not player then
        if UnitIsMinion then minion = Readable(UnitIsMinion(unit)) else minion = Readable(UnitPlayerControlled(unit)) end
    end
    if not canAttack and friend ~= false then
        if minion then return "minor" end
        return player and "friendlyPlayer" or "friendlyNpc"
    end
    if player then return "enemyPlayer" end
    if minion then return "minor" end
    if Readable(UnitClassification(unit)) == "minus" then return "minor" end
    return "enemyNpc"
end
-- NAME ONLY WHILE UNATTACKABLE: an
-- enemy NPC you can't attack (an event mob, a quest giver of the other side) shows only its name, as
-- the Name Only preset, until you can attack it. Off by default (nameplates.peacefulNames).
function NP.Peaceful(unit, kind)
    local db = SharedSettings()
    if not (db and db.peacefulNames) or kind ~= "enemyNpc" then return false end
    if Readable(UnitIsPlayer(unit)) then return false end
    return Readable(UnitCanAttack("player", unit)) == false
end
-- ENEMY PLAYERS / ENEMY NPCS (the Plates' Enemy Types): the game has no switch for these two, so
-- FlareUI hides its own plate for them (as Plate: Hidden). Both on by default (nameplates.enemyPlayers,
-- nameplates.enemyNpcs).
function NP.UnitHidden(unit, kind)
    local db = SharedSettings()
    if not db then return false end
    if kind == "enemyPlayer" then return db.enemyPlayers == false end
    if kind == "enemyNpc" then return db.enemyNpcs == false end
    return false
end
-- whether FlareUI draws this unit's plate (its type's Plate isn't Blizzard), its type, and whether the
-- game couldn't say yet
function NP.WantsPlate(unit)
    -- objects (chairs, signs, mailboxes, herbs and ore with the interact key) and widget-only plates:
    -- Blizzard's own plate shows them without a bar, so they stay Blizzard's (they read as
    -- Enemy NPCs and got a full plate with level and health)
    if UnitIsGameObject and Readable(UnitIsGameObject(unit)) then return false, nil end
    if UnitNameplateShowsWidgetsOnly and Readable(UnitNameplateShowsWidgetsOnly(unit)) then return false, nil end
    local kind = NP.Kind(unit)
    if not kind then return false, nil, true end
    if kind == "friendlyPlayer" and Readable(UnitIsUnit(unit, "player")) then return false, kind end
    return NP.TypeDB(kind, true).plate ~= "blizzard", kind
end

-- A plate whose unit couldn't be read yet: asked again a few times, soon
local retries = {}
local function Retry(unit)
    local n = (retries[unit] or 0) + 1
    if n > 4 then retries[unit] = nil return end
    retries[unit] = n
    C_Timer.After(0.25, function()
        if retries[unit] then NP.Claim(unit) end
    end)
end

-- Clicks: the game plate's own box (sized to our plate, NP.ApplySize) is the click area. The game
-- allows the change only on the moment a unit arrives; any other time Blizzard's own area stays.
local function SetClickArea(plate, none)
    local okC, can = pcall(plate.CanChangeHitTestPoints, plate)
    if not (okC and can) then return end
    if none then pcall(plate.ClearAllHitTestPoints, plate) else pcall(plate.SetAllHitTestPoints, plate, plate) end
end

-- DOESITDIE: DoesItDie draws its marker and kill icon on nameplates itself, on the
-- health bar it finds on the game's plate: Blizzard's (hidden under ours) or a field named like
-- "health". Each game plate we hold gets an invisible bar under that name, laid over our health bar,
-- so its marker lands on ours with all of its own settings. One per game plate (DoesItDie remembers
-- the bar it found per plate), hidden when we let the plate go or show no bar on it.
function NP.DieProxy(plate, p)
    if not (plate and _G.DoesItDie) then return end
    local proxy = plate.FlareUI_DieHealth
    if not p then
        if proxy then proxy:Hide() end
        return
    end
    local health = p.health
    local barShown = health and health:IsVisible() and not (p.hiddenPlate or p.unitHidden or p.nameOnly)
    if not barShown then
        if proxy then proxy:Hide() end
        return
    end
    if not proxy then
        proxy = CreateFrame("StatusBar", nil, plate)
        proxy:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
        proxy:SetStatusBarColor(0, 0, 0, 0)
        proxy:SetMinMaxValues(0, 1)
        proxy:SetValue(1)
        plate.FlareUI_DieHealth = proxy
    end
    proxy:ClearAllPoints()
    proxy:SetAllPoints(health)
    proxy:SetFrameStrata(health:GetFrameStrata())
    proxy:SetFrameLevel(health:GetFrameLevel())
    proxy:SetReverseFill(health:GetReverseFill() and true or false)
    proxy:Show()
end

function NP.Claim(unit)
    if NP.standDown or not NP.ready then return end
    if not canaccessvalue(unit) or type(unit) ~= "string" then stats.secret = stats.secret + 1 return end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate or plate:IsForbidden() then stats.forbidden = stats.forbidden + 1 return end
    local unitFrame = plate.UnitFrame
    if not unitFrame or unitFrame:IsForbidden() then stats.forbidden = stats.forbidden + 1 return end
    -- another addon took Blizzard's unit frame off its plate: it runs the nameplates
    if unitFrame:GetParent() ~= plate then
        NP.otherAddon = true
        NP.StandDown()
        return
    end
    local mine = byPlate[plate]
    if mine then
        if mine.unit == unit and mine.blizz == unitFrame then return end
        Release(mine)
    end
    local want, kind, unknown = NP.WantsPlate(unit)
    if not want then
        if unknown then Retry(unit) end
        return
    end
    retries[unit] = nil
    -- a spare plate already laid out for this type, else any (Test: every plate as the picked type)
    local look = NP.testKind or (NP.Peaceful(unit, kind) and "peaceful") or kind
    -- (and laid out for the fight as it stands now: Show Plates in Combat, NP.CombatFull)
    local full = NP.CombatFull(look)
    local p
    for i = #spare, 1, -1 do
        if spare[i].layKind == look and spare[i].layFull == full then p = table.remove(spare, i) break end
    end
    -- (else the one let go longest ago: the last ones are the types in use, and a new layout costs the most)
    if not p then
        local at = 1
        for i = #spare, 1, -1 do if spare[i].layKind == look then at = i break end end
        p = table.remove(spare, at)
    end
    if not p then stats.given = stats.given + 1 return end
    p.kind, p.tdb = kind, NP.TypeDB(look, true)
    p.unitHidden = NP.UnitHidden(unit, kind)
    if p.layKind ~= look or p.layFull ~= full then
        local okL, errL = pcall(NP.Layout, p)
        if not okL then ns.LogError("Nameplates Layout", errL) end
    end
    if NP.Sab then pcall(NP.Sab.Prepare, p, unit) end
    local ok, err = pcall(function()
        p.gamePlate, p.unit = plate, unit
        byPlate[plate] = p
        p.holder:SetParent(plate)
        p.holder:ClearAllPoints()
        p.holder:SetAllPoints(plate)
        p.holder:SetAlpha(1)
        p.rangeAlphaNow = 1
        p.barDirty, p.borderDirty = true, true   -- (a new unit: its colours painted afresh)
        p.holder:Show()
        p.root:ClearAllPoints()
        -- the name and bar together sit in the middle of the game plate's box
        p.root:SetPoint("CENTER", plate, "CENTER", 0, -(p.nameRoom or 0) / 2)
        SetClickArea(plate, p.hiddenPlate or p.unitHidden or p.tdb.clickThrough)
        -- the check: our frame must be usable on this plate
        -- (nothing is measured here: the game refuses measuring nameplate parts under restrictions)
        if p.root:IsForbidden() then error("forbidden after attach") end
        HideBlizzard(p, unitFrame)
        -- (Musician's name frame, if it made one before we took the plate: NP:Init)
        local musicianFrame = plate.musicianUnitFrame
        if musicianFrame and not musicianFrame:IsForbidden() then musicianFrame:Hide() end
        -- Blizzard marks minions, minor mobs and (by its setting) friends "simplified", and the game
        -- then shrinks the whole plate, ours with it (Minor names tiny even at 200%). Ours has
        -- its own sizes: off while we hold the plate, Blizzard's value back on release.
        if C_NamePlateManager and C_NamePlateManager.SetNamePlateSimplified then
            pcall(C_NamePlateManager.SetNamePlateSimplified, unit, false)
        end
        NP.QueueAuras(p)
        RegisterUnit(p, unit)
        p.targetShown = nil
        NP.StopScale(p)
        p.root:SetScale(1)
        p.scaleNow, p.threatKey, p.threatRGB, p.scaleFresh = 1, nil, nil, true
        p.deadHidden = false
        p.root:SetShown(not (p.hiddenPlate or p.unitHidden))
        NP.UpdateAll(p)
        -- Plus discovers health-named fields on the game plate and rechecks cached bar ancestry.
        -- Original DoesItDie does not recheck ancestry: keep its existing behavior when also loaded.
        if _G.UsefulPlatesAndTooltips_API and not _G.DoesItDie
            and canaccessvalue(plate.FlareUIHealthBar) and plate.FlareUIHealthBar == nil then
            plate.FlareUIHealthBar = p.health
        end
        pcall(NP.DieProxy, plate, p)
    end)
    if ok then
        stats.claimed = stats.claimed + 1
        -- (Questie may make its icon after us)
        if NP.QuestieHasIcons() then
            C_Timer.After(0, function() if p.unit == unit and p.gamePlate == plate then pcall(NP.FixQuestie, p) end end)
        end
        if NP.ComboPlateChanged then pcall(NP.ComboPlateChanged) end
    else
        stats.failed = stats.failed + 1
        stats.lastError = err
        ns.LogError("Nameplates Claim", err)
        Release(p)
    end
end

function Release(p)
    if not p then return end
    -- A recycled Blizzard token may have exactly the same string on the next claim.
    queue.plates[p], queue.processing[p] = nil, nil
    NP.ResetPendingCast(p)
    if p.events then p.events:UnregisterAllEvents() end
    NP.ClearAuras(p)
    if p.cast then
        if UF and UF.EndCastFlash then UF.EndCastFlash(p.cast) end
        if UF and UF.SetDamageTrail then UF.SetDamageTrail(p.trail, nil, false, false) end
        p.cast:Hide()
    end
    -- only a unit whose plate stays on screen (NAME_PLATE_UNIT_REMOVED: no plate left to move to)
    local token = p.gamePlate and p.gamePlate.unitToken
    local unit = (canaccessvalue(token) and token ~= nil and token == p.unit) and p.unit or nil
    local live = unit ~= nil and p.blizz ~= nil and p.gamePlate.UnitFrame == p.blizz
    if live and C_NamePlateManager and C_NamePlateManager.SetNamePlateSimplified then
        pcall(C_NamePlateManager.SetNamePlateSimplified, unit, p.blizz.isSimplified == true)
    end
    pcall(ShowBlizzard, p, live)
    if p.gamePlate and canaccessvalue(p.gamePlate.FlareUIHealthBar) and p.gamePlate.FlareUIHealthBar == p.health then
        p.gamePlate.FlareUIHealthBar = nil
    end
    pcall(NP.DieProxy, p.gamePlate, nil)
    pcall(NP.ReturnQuestie, p)
    if p.gamePlate and byPlate[p.gamePlate] == p then byPlate[p.gamePlate] = nil end
    p.gamePlate, p.unit, p.targetShown = nil, nil, nil
    p.root:Hide()
    p.holder:SetParent(hidden)
    p.holder:ClearAllPoints()
    p.root:ClearAllPoints()
    p.highlight:Hide()
    if state.mouseover == p then state.mouseover = nil end
    local known = false
    for _, s in ipairs(spare) do if s == p then known = true break end end
    if not known then spare[#spare + 1] = p end
    if unit and NP.ComboPlateChanged then pcall(NP.ComboPlateChanged) end
end
NP.ReleasePlate = Release

function NP.ReleaseUnit(unit)
    if not canaccessvalue(unit) then return end
    for _, p in pairs(byPlate) do
        if p.unit == unit then Release(p) end
    end
end

-- A unit swap with no event, or a unit frame handed out late: put right
function NP.Sync()
    if not NP.ready or NP.standDown then return end
    -- (Righteous Fury has no event of its own: the role is read again out of a fight)
    if not InCombatLockdown() then
        local before = state.role
        NP.UpdateRole()
        if before ~= state.role then QueueWorld(D.COLOR) end
    end
    -- (claimed after the loop: a new key while pairs() walks the table is not allowed)
    local reclaim = {}
    for plate, p in pairs(byPlate) do
        local unit = plate.unitToken
        if type(unit) ~= "nil" and not canaccessvalue(unit) then unit = nil end
        if not unit or unit ~= p.unit or plate.UnitFrame == nil then
            Release(p)
            if unit then reclaim[#reclaim + 1] = unit end
        elseif plate.UnitFrame ~= p.blizz then
            pcall(ShowBlizzard, p)
            if not plate.UnitFrame:IsForbidden() then HideBlizzard(p, plate.UnitFrame) end
        end
        if p.unit then pcall(NP.FixQuestie, p) end
    end
    if NP.Sab then NP.Sab.ApplyAll() end
    for _, unit in ipairs(reclaim) do NP.Claim(unit) end
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        local unit = plate.unitToken
        if unit and not byPlate[plate] and canaccessvalue(unit) then NP.Claim(unit) end
    end
end

function NP.StandDown()
    if NP.standDown then return end
    NP.standDown = true
    settings, pendingSettings = nil, nil
    local held = {}
    for _, p in pairs(byPlate) do held[#held + 1] = p end
    for _, p in ipairs(held) do Release(p) end
    queue.scheduled, queue.world = false, 0
    queue.driver:Hide()
    NP:UnregisterAllEvents()
    -- Blizzard's own plate size back (the other addon sets its own if it wants)
    if state.blizzW and not InCombatLockdown() then pcall(C_NamePlate.SetNamePlateSize, state.blizzW, state.blizzH) end
    NP.RestoreZoom()
end

-- Another nameplate addon by folder name (the runtime check in Claim catches others)
function NP.OtherAddon()
    for _, name in ipairs(C.OTHER_ADDONS) do
        if C_AddOns.IsAddOnLoaded(name) then return name end
    end
    if C_AddOns.IsAddOnLoaded("ElvUI") then
        local E = _G.ElvUI and _G.ElvUI[1]
        if type(E) == "table" and type(E.private) == "table" and type(E.private.nameplates) == "table"
            and E.private.nameplates.enable then return "ElvUI" end
    end
    if NP.otherAddon then return true end
end

-- (NameplateExtras.lua) our plates on the game's, for Smooth Animated Bars
function NP.HeldPlates() return byPlate end
-- Our parts of a game plate, for the combo points
function NP.PartsFor(plate)
    local p = plate and byPlate[plate]
    if p and p.unit then return p end
end

--------------------------------------------------
-- 8. TARGET, MOUSEOVER, GLOBAL EVENTS
--------------------------------------------------
-- Leaving a unit with the mouse fires no event: a small watcher runs only while a plate is lit
local watcher = CreateFrame("Frame")
watcher:Hide()
local function SetMouseover(p)
    local before = state.mouseover
    if before and before ~= p then before.highlight:Hide() end
    state.mouseover = p
    if p and NP.HoverParts().bar then p.highlight:Show() end
    if p then watcher:Show() else watcher:Hide() end
    if before and before ~= p then NP.QueuePlate(before, D.FADE) end
    if p and before ~= p then NP.QueuePlate(p, D.FADE) end
    -- (the lighter border and the outer glow on the plate under the mouse: NP.PaintBorder, UpdateTargetLook)
    if before ~= p then
        if before and before.unit then NP.PaintBorder(before) NP.UpdateTargetLook(before) end
        if p and p.unit then NP.PaintBorder(p) NP.UpdateTargetLook(p) end
    end
end
watcher:SetScript("OnUpdate", function()
    local p = state.mouseover
    if not p or not p.gamePlate or C_NamePlate.GetNamePlateForUnit("mouseover") ~= p.gamePlate then SetMouseover(nil) end
end)

local function FlushHealth(p, mask)
    -- Prediction bars use the range written by UpdateHealth on a maximum-health change.
    if band(mask, healthBits) ~= 0 then NP.UpdateHealth(p, true, mask) end
    if band(mask, healBits) ~= 0 then NP.UpdateHeals(p, mask) end
end

local function FlushNameAndLevel(p, mask)
    local level = band(mask, D.LEVEL) ~= 0
    if level then NP.UpdateLevel(p) end
    if band(mask, D.NAME) ~= 0 then
        if not (level and p.levelFollow) then NP.UpdateName(p) end
        NP.UpdateTitle(p)
    end
end

local function FlushTarget(p, targetPlate)
    if p.targetShown ~= (p.gamePlate == targetPlate) then
        NP.UpdateTarget(p, targetPlate)
    else
        -- Other plates' scale and opacity also depend on whether you have a target.
        ApplyVisual(p, "ApplyScale")
        ApplyVisual(p, "UpdateFade")
    end
end

local function FlushPlate(p, mask, targetPlate)
    -- An error in one widget must not discard other pending work for this plate.
    local color = band(mask, D.COLOR) ~= 0 or (p.healthTint and band(mask, healthBits) ~= 0)
    local cast, quest = band(mask, D.CAST) ~= 0, band(mask, D.QUEST) ~= 0
    local target, fade = band(mask, D.TARGET) ~= 0, band(mask, D.FADE) ~= 0
    local shared = (color and (quest or target)) or (cast and (target or fade))
    if shared then paint.plate = p end
    if band(mask, healthOrHealBits) ~= 0 then ns.SafeCall("Nameplates Health", FlushHealth, p, mask) end
    if color then ns.SafeCall("Nameplates Color", NP.UpdateColor, p) end
    if band(mask, nameOrLevelBits) ~= 0 then ns.SafeCall("Nameplates Name and Level", FlushNameAndLevel, p, mask) end
    if cast then ns.SafeCall("Nameplates Cast", NP.FlushCast, p) end
    if band(mask, D.RAID) ~= 0 then ns.SafeCall("Nameplates Raid Marker", NP.UpdateRaid, p) end
    if quest then ns.SafeCall("Nameplates Quest", NP.UpdateQuest, p) end
    if target then
        ns.SafeCall("Nameplates Target", FlushTarget, p, targetPlate)
    elseif fade then
        if shared then paint.UpdateFade = true else ns.SafeCall("Nameplates Opacity", NP.UpdateFade, p, paint) end
    end
    if shared then
        paint.plate = nil
        if paint.PlaceSides then
            ns.SafeCall("Nameplates Side Layout", NP.PlaceSides, p, paint.questIcon, paint.questText)
            paint.PlaceSides, paint.questIcon, paint.questText = nil, nil, nil
        end
        for _, method in ipairs(C.SHARED_VISUALS) do
            if paint[method] then
                paint[method] = nil
                ns.SafeCall("Nameplates " .. method, NP[method], p, paint)
            end
        end
    end
end

queue.driver:SetScript("OnUpdate", function(self)
    local world = queue.world
    queue.world = 0
    local all = band(world, bor(D.COLOR, D.TARGET, D.RAID, D.QUEST))
    if band(world, D.GROUP) ~= 0 then
        NP.UpdateGroup()
        NP.UpdateRole()
        all = bor(all, D.COLOR)
    elseif band(world, D.ROLE) ~= 0 then
        local before = state.role
        NP.UpdateRole()
        if before ~= state.role then all = bor(all, D.COLOR) end
    end
    if band(world, D.SPELLS) ~= 0 then
        local at = NP.ExecuteAt({ execute = "auto" })
        if at ~= state.execAt then
            state.execAt = at
            NP:Refresh()
        end
    end
    if band(world, D.MOUSEOVER) ~= 0 then
        local plate = C_NamePlate.GetNamePlateForUnit("mouseover")
        SetMouseover(plate and byPlate[plate] or nil)
    end
    local pending = queue.plates
    if all ~= 0 then
        for _, p in pairs(byPlate) do pending[p] = bor(pending[p] or 0, all) end
    end
    local targetPlate
    if band(all, D.TARGET) ~= 0 then targetPlate = C_NamePlate.GetNamePlateForUnit("target") end
    paint.draining, paint.hasTarget = true, targetPlate and true or nil
    -- Work requested by a widget callback during this pass belongs to the following frame.
    queue.plates, queue.processing = queue.processing, pending
    for p, mask in pairs(pending) do
        pending[p] = nil
        if p.unit then FlushPlate(p, mask, targetPlate) end
    end
    paint.draining, paint.hasTarget = nil, nil
    if queue.world == 0 and not next(queue.plates) then
        queue.scheduled = false
        self:Hide()
    end
end)

function NP:OnEvent(event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        NP.Claim(unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        NP.ReleaseUnit(unit)
    elseif event == "PLAYER_TARGET_CHANGED" then
        QueueWorld(D.TARGET)
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        QueueWorld(D.MOUSEOVER)
    elseif event == "RAID_TARGET_UPDATE" then
        QueueWorld(D.RAID)
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" then
        QueueWorld(D.GROUP)
    elseif event == "PLAYER_REGEN_DISABLED" then
        state.combat = true
        if next(NP.CombatList()) then NP.Relayout() end
    elseif event == "UPDATE_SHAPESHIFT_FORM" or event == "PLAYER_REGEN_ENABLED" then
        if event == "PLAYER_REGEN_ENABLED" then
            local was = state.combat
            state.combat = false
            if pendingSettings then
                if not InCombatLockdown() then
                    settings, pendingSettings = pendingSettings, nil
                    state.role = settings.role
                    NP.ApplyPlateSettings()
                end
            elseif was and next(NP.CombatList()) then
                NP.Relayout()
            end
        end
        if event == "PLAYER_REGEN_ENABLED" and state.sizePending then NP.ApplySize() end
        QueueWorld(event == "PLAYER_REGEN_ENABLED" and bor(D.ROLE, D.COLOR) or D.ROLE)
    elseif event == "PLAYER_ENTERING_WORLD" then
        NP.UpdateGroup()
        NP.UpdateRole()
        NP.Sync()
    elseif event == "QUEST_LOG_UPDATE" or event == "UNIT_QUEST_LOG_CHANGED" then
        -- Once scheduled, finish the pass even if quest marks were turned off:
        -- UpdateQuest also removes marks that are already on screen.
        if band(queue.world, D.QUEST) == 0 and NP.QuestOn() then QueueWorld(D.QUEST) end
    elseif event == "PLAYER_FOCUS_CHANGED" then
        local db = SharedSettings()
        if db and db.colorFocus then QueueWorld(D.COLOR) end
    elseif event == "SPELLS_CHANGED" then
        QueueWorld(D.SPELLS)
    end
end

-- Out of Range Opacity: a few plates per tick, in turn
function NP.RangeTick()
    local db = SharedSettings()
    if not db or (db.rangeAlpha or 1) >= 1 then return end
    local checked, n = 0, #pool
    for _ = 1, n do
        state.rangeAt = (state.rangeAt or 0) % n + 1
        local p = pool[state.rangeAt]
        if p.unit then
            NP.UpdateRange(p)
            checked = checked + 1
            if checked >= 8 then return end
        end
    end
end

local GLOBAL_EVENTS = {
    "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT",
    "RAID_TARGET_UPDATE", "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "UPDATE_SHAPESHIFT_FORM",
    "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE", "UNIT_QUEST_LOG_CHANGED",
    "PLAYER_FOCUS_CHANGED", "SPELLS_CHANGED",
}

--------------------------------------------------
-- 9. SETTINGS PREVIEW (the settings panel's picture: our own plate code with sample values)
--------------------------------------------------
local SAMPLE_ICONS = { "Spell_Shadow_ShadowWordPain", "Spell_Shadow_AbominationExplosion", "Ability_Warrior_Sunder",
                       "Spell_Shadow_CurseOfTounges", "Spell_Nature_FaerieFire", "Spell_Shadow_UnholyStrength" }
C.SAMPLE_DISPEL = { "Magic", "None", "None", "Curse", "Magic", "Disease" }
C.SAMPLE_BUFFS = { "Spell_Holy_PowerWordShield", "Spell_Nature_Rejuvenation", "Spell_Holy_Renew" }
-- kind given (the settings panel's picture): its parts can be clicked to open their setting. The
-- colour window's samples are plain pictures.
function NP.CreateSample(parent, kind)
    local f = CreateFrame("Frame", nil, parent)
    f.plates = {}
    f.clickable = kind ~= nil
    return f
end

-- The page's own picture shows each state in turn
C.CYCLE = { "enemy", "target", "cast", "threat" }
C.CYCLE_SECONDS = 2.5
local function CycleTick(f, elapsed)
    f.cycleElapsed = (f.cycleElapsed or 0) + elapsed
    if f.cycleElapsed < C.CYCLE_SECONDS then return end
    f.cycleElapsed = 0
    f.cycleAt = f.cycleAt % #C.CYCLE + 1
    NP.DrawSample(f, "overview")
end

-- Clicking a part of the picture opens its setting (the panel's search jump)
C.HITS = {
    { "name", "np.barText" }, { "level", "np.level" }, { "health", "np.healthColor" },
    { "cast", "np.castbar" }, { "quest", "np.questMarks" }, { "questText", "np.questProgress" }, { "debuffIcon", "np.debuffs" },
    { "buffIcon", "np.buffs" }, { "ccIcon", "np.cc" },
}
local function HitEnter(self)
    self.light:Show()
    local row = ns.Settings and ns.Settings.rows and ns.Settings.rows[self.rowKey]
    if not row then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(row:Label() or "", 1, 0.82, 0)
    GameTooltip:AddLine(L["Click to go to this setting."], 1, 1, 1)
    GameTooltip:Show()
end
local function HitLeave(self)
    self.light:Hide()
    GameTooltip:Hide()
end
local function HitClick(self)
    local row = ns.Settings and ns.Settings.rows and ns.Settings.rows[self.rowKey]
    local panel = ns.SettingsPanel
    if row and panel and panel.JumpTo then panel:JumpTo(row) end
end
local function PlaceHits(p)
    p.hits = p.hits or {}
    for _, h in ipairs(C.HITS) do
        local region, key = p[h[1]], h[2]
        local hit = p.hits[key]
        if not hit then
            hit = CreateFrame("Button", nil, p.overlay)
            hit:SetFrameLevel(p.overlay:GetFrameLevel() + 10)
            hit.light = hit:CreateTexture(nil, "OVERLAY")
            hit.light:SetAllPoints()
            hit.light:SetColorTexture(1, 1, 1, 0.18)
            hit.light:SetBlendMode("ADD")
            hit.light:Hide()
            hit.rowKey = key
            hit:SetScript("OnEnter", HitEnter)
            hit:SetScript("OnLeave", HitLeave)
            hit:SetScript("OnClick", HitClick)
            p.hits[key] = hit
        end
        hit:ClearAllPoints()
        local shown = region and region:IsShown() and region:IsVisible()
        if region == p.name and shown then shown = (p.name:GetText() or "") ~= "" end
        if shown then
            hit:SetPoint("TOPLEFT", region, "TOPLEFT", -1, 1)
            hit:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 1, -1)
            hit:Show()
        else
            hit:Hide()
        end
    end
end

-- kind: "enemy", "target", "cast", "nokick", "kick", "threat", "execute", or "overview" (each in turn)
-- A view (one state) as a set of states: the preview strip's chips can set several at once
C.VIEWS = {
    enemy = {}, target = { target = true }, cast = { cast = true }, nokick = { cast = true, nokick = true },
    kick = { cast = true, kick = true }, threat = { threat = true }, execute = { execute = true },
}
-- kind: a view name ("enemy", "target", "cast", "nokick", "kick", "threat", "execute"), "overview"
-- (each in turn), or a table of states: target, cast, nokick, kick, important, threat, focus,
-- execute, quest, combo. A state shows only what its setting draws (a quest mark needs Quest Marks).
function NP.DrawSample(f, kind)
    if not SharedSettings(true) then return end
    local db = NP.TypeDB(f.kind, true, true)
    if kind == "overview" then
        f.cycleAt = f.cycleAt or 1
        if not f.cycling then
            f.cycling = true
            f.cycleElapsed = 0
            f:SetScript("OnUpdate", CycleTick)
        end
        kind = C.CYCLE[f.cycleAt]
    elseif f.cycling then
        f.cycling = nil
        f:SetScript("OnUpdate", nil)
    end
    local st = type(kind) == "table" and kind or C.VIEWS[kind] or C.VIEWS.enemy
    f.states = st
    -- a single view keeps the cast bar on show whenever it's on (as before)
    local showCast = st.cast or (type(kind) ~= "table" and db.castbar)
    local p = f.plates[1]
    if not p then
        p = NP.Build(f, true)
        f.plates[1] = p
    end
    p.kind, p.tdb = db.kind, db
    NP.Layout(p)
    p.holder:SetParent(f)
    p.holder:ClearAllPoints()
    p.holder:SetAllPoints(f)
    p.holder:SetAlpha(1)
    p.rangeAlphaNow = 1
    p.holder:Show()
    p.root:ClearAllPoints()
    -- (room above for the aura lines the preview draws)
    local function Lines(on, size, max)
        if not on then return 0 end
        local lines = math.ceil(NP.AuraCount(p, db, size, max) / NP.AuraPerLine(p, db, size))
        local look = AuraLook(size, on == "debuff", db)
        return lines * ((look and look.cellHeight or size) + C.AURA_GAP)
    end
    local dLines = Lines(db.debuffs ~= "off" and "debuff", db.debuffSize, db.debuffMax)
    local bLines = Lines(db.buffs ~= "off" and "buff", db.buffSize, db.buffMax)
    -- (stacked rows: one above the other)
    local top = 12 + (NP.AuraStack(db) and (dLines + bLines) or math_max(dLines, bLines)) + (p.nameAboveLift or 0)
    p.root:SetPoint("TOP", f, "TOP", 0, -top)
    p.root:Show()
    -- sample values
    local share = (st.execute and 0.15) or f.demoShare or (st.threat and 0.64) or 0.72
    p.health:SetMinMaxValues(0, 1)
    p.health:SetValue(share)
    if UF and UF.SampleDamageTrail then UF.SampleDamageTrail(p.trail, share, db.damageTrail) end
    if UF and UF.BarLookUpdate then UF.BarLookUpdate(p.health, nil, false) end
    p.heal:SetMinMaxValues(0, 1); p.heal:SetValue(0.08)
    p.absorb:SetMinMaxValues(0, 1); p.absorb:SetValue(0)
    local hostile = NP.Color("hostile", true)
    local r, g, b = hostile[1], hostile[2], hostile[3]
    -- threat: the warning state for your role (damage / healer: it's on you; tank: you lost it), so
    -- Threat Glow, Aggro Flash and Threat Scale show with it
    -- (shown whenever the preview asks for it: Colour by Threat may still be off while you look at its options)
    local role = pendingSettings and pendingSettings.role or state.role
    local threatKey = st.threat and (role == "tank" and "lost" or "aggro") or nil
    if threatKey then
        local c = NP.Color(threatKey, true)
        r, g, b = c[1], c[2], c[3]
    elseif st.focus and db.colorFocus then
        local c = NP.Color("focus", true)
        r, g, b = c[1], c[2], c[3]
    elseif db.colorElite then
        local c = NP.Color("elite", true)   -- (the sample is an elite)
        r, g, b = c[1], c[2], c[3]
    elseif db.healthColor == "health" and UF and UF.SampleHealthColor then
        r, g, b = UF.SampleHealthColor({ healthColor = "health" }, share, r, g, b)
    end
    if C.FRIENDLY[db.kind] then local c = NP.Color("friendly", true) r, g, b = c[1], c[2], c[3] end
    NP.BarColor(p, r, g, b)
    -- the execute tint below its threshold
    p.execTint:SetAlpha((p.execAt and share < p.execAt) and 1 or 0)
    local color = GetQuestDifficultyColor and GetQuestDifficultyColor(12) or { r = 1, g = 0.82, b = 0 }
    if p.levelFollow then
        p.name:SetFormattedText("|cff%02x%02x%02x12|r %s", color.r * 255 + 0.5, color.g * 255 + 0.5, color.b * 255 + 0.5, L["Forest Spider"])
    else
        p.name:SetText(L["Forest Spider"])
    end
    p.name:SetTextColor(1, 1, 1)
    -- players: a player's name in your class colour
    -- (the friendly sample is a player: you, in your class colour)
    if db.kind == "friendlyPlayer" then
        local _, class = UnitClass("player")
        local cc = class and C_ClassColor.GetClassColor(class)
        -- (Full Name in Bar Text, or Show Full Name on a Name Only plate: your surname too)
        p.name:SetText(ns.UnitDisplayName("player", nil, p.nameFull or false))
        -- (as the real plates: the class colour only on a Name Only plate)
        if cc and p.nameOnly then p.name:SetTextColor(cc:GetRGB()) end
    end
    p.sampleName = (db.kind == "friendlyPlayer") and ns.UnitDisplayName("player", nil, BT.FullOf(p.aboveKind)) or L["Forest Spider"]
    NP.UpdateNameAbove(p)
    local questOn = NP.QuestOn(true) and (st.quest or type(kind) ~= "table")
    local questIcon, questProgress = NP.QuestParts(p)
    p.quest:SetShown(questOn and questIcon)
    p.questText:SetText("3/8")
    p.questText:SetShown(questOn and questProgress)
    NP.PlaceSides(p)
    p.level:SetText("12")
    p.level:SetTextColor(color.r, color.g, color.b)
    if C_Texture.GetAtlasInfo(C.ELITE_GOLD) then p.elite:SetAtlas(C.ELITE_GOLD) end
    p.elite:SetShown(db.rarityIcon ~= false and not p.nameOnly)
    if p.textOn then
        local src = { cur = math_floor(share * 1840), max = 1840, percent = share * 100, lost = math_floor((1 - share) * 1840) }
        BT.FillAll(p.texts, p.slots, src)
        p.textHolder:SetAlpha(1)
    end
    p.sampleTarget = st.target or false
    p.targetShown = nil
    p.scaleNow = nil
    p.threatRGB = threatKey and { r, g, b } or nil
    if threatKey and db.aggroFlash then
        if not p.flashAnim:IsPlaying() then p.flashAnim:Play() end
    else
        p.flashAnim:Stop()
    end
    p.sampleThreat = threatKey
    p.threatKey = threatKey
    NP.UpdateTarget(p)
    -- the cast bar
    local cast = p.cast
    if cast then
        if db.castbar and showCast then
            cast:SetMinMaxValues(0, 1)
            cast:SetValue(0.55)
            cast.Text:SetText(L["Shadow Bolt"])
            cast.Time:SetText("1.2")
            cast.Icon:SetTexture("Interface\\Icons\\Spell_Shadow_ShadowBolt")
            local nokick = st.nokick
            local c = NP.Color(nokick and "castNoInterrupt" or (st.kick and db.kickReady and "kickReady") or "cast", true)
            cast:GetStatusBarTexture():SetAlpha(1)
            cast:SetStatusBarColor(c[1], c[2], c[3])
            cast.shield:SetAlpha(nokick and 1 or 0)
            -- Highlight Important Casts: the glow, pulsing as it would
            cast.important:SetAlpha((st.important and db.castImportant) and 1 or 0)
            -- Kick Ready Mark: your interrupt ready a quarter of the cast from now
            if db.castKickMark then
                cast.kickNow:SetReverseFill(false)
                cast.kickWait:SetReverseFill(false)
                cast.kickNow:SetMinMaxValues(0, 1)
                cast.kickWait:SetMinMaxValues(0, 1)
                cast.kickNow:SetValue(0.55)
                cast.kickWait:SetValue(0.25)
                NP.PlaceKickMark(cast, false)
                cast.kickClip:SetAlpha(1)
                cast.kickClip:Show()
            else
                cast.kickClip:Hide()
            end
            -- Flash When Targeted
            if st.targeted and db.castTargetedFlash then
                cast.targeted:SetAlpha(1)
                cast.targetedPulse:Play()
            else
                cast.targeted:SetAlpha(0)
                cast.targetedPulse:Stop()
            end
            if db.castTarget then
                cast.target:SetText(UnitName("player"))
                local _, class = UnitClass("player")
                local cc = class and C_ClassColor.GetClassColor(class)
                if cc then cast.target:SetTextColor(cc:GetRGB()) end
                cast.target:Show()
            else
                cast.target:Hide()
            end
            cast:Show()
        else
            cast:Hide()
        end
    end
    -- combo points under the plate (below the cast bar while it shows), 3 of 5, as the live ones
    NP.PlaceBelow(p)
    -- (the unit type's own Combo Points too, and never on a Name Only plate: NP.ComboAllowed)
    local shared = SharedSettings(true)
    local comboOn = shared and shared.comboPoints
        and db.combo ~= false and not p.nameOnly
        and (st.combo or type(kind) ~= "table")
    p.sampleCombo = p.sampleCombo or {}
    local gemSize = 14 * (NP.ComboScale and NP.ComboScale(db.width) or 1)
    local step = ns.ComboPointStep and ns.ComboPointStep(gemSize) or gemSize + 2
    for i = 1, 5 do
        local gem = p.sampleCombo[i]
        if comboOn and not gem and ns.CreateComboPoint then
            gem = ns.CreateComboPoint(p.overlay, i, gemSize)
            p.sampleCombo[i] = gem
        end
        if gem then
            gem:ClearAllPoints()
            if ns.SizeComboPoint then ns.SizeComboPoint(gem, gemSize) end
            gem:SetPoint("TOP", p.below, "BOTTOM", (i - 3) * step, -4)
            if comboOn then
                if ns.SetComboPoint then ns.SetComboPoint(gem, 3, false) end
                gem:Show()
            else
                gem:Hide()
            end
        end
    end
    -- the aura rows: styled as the live ones (the unit frames' aura look, border and all), above the
    -- arrows; as many as fit the row (debuffs and buffs share it, one alone fills it)
    local icons = p.sampleIcons
    for _, t in ipairs(icons) do t:Hide() end
    local n = 0
    local function Icon(path, size, isDebuff, dispelType, point, rel, relPoint, x, y)
        n = n + 1
        local b = icons[n]
        if not b then
            b = CreateFrame("Frame", nil, p.root)
            b:SetFrameLevel(p.root:GetFrameLevel() + 12)
            icons[n] = b
        end
        local look = AuraLook(size, isDebuff, db)
        if look and ns.AuraLook and ns.AuraLook.Style then
            look.preview = true
            ns.AuraLook.Style(b, look)
            local c = look.colors and (look.colors[dispelType] or look.colors.None)
            if c then b.FlareUI_Border:SetVertexColor(c:GetRGBA()) end
            b.FlareUI_Count:SetText("")
            -- a sample time and swipe, so Aura Timer, Timer Colour and Aura Swipe show here
            local secs = C.SAMPLE_SECONDS[(n - 1) % #C.SAMPLE_SECONDS + 1]
            b.FlareUI_Duration:SetText(look.timer ~= "none" and ns.FormatAuraTime(secs) or "")
            if look.timerColor and secs < 5 then b.FlareUI_Duration:SetTextColor(1, 0.2, 0.2)
            elseif look.timerColor and secs < 10 then b.FlareUI_Duration:SetTextColor(1, 0.82, 0)
            else b.FlareUI_Duration:SetTextColor(1, 1, 1) end
            b.FlareUI_Cooldown:SetCooldown(GetTime() - (secs % 7), secs + (secs % 7))
        else
            -- (no aura look: a plain icon on a black edge)
            if not b.FlareUI_Icon then
                local bg = b:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(0, 0, 0, 1)
                b.FlareUI_Icon = b:CreateTexture(nil, "ARTWORK")
                b.FlareUI_Icon:SetPoint("TOPLEFT", 1, -1)
                b.FlareUI_Icon:SetPoint("BOTTOMRIGHT", -1, 1)
                b.FlareUI_Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end
            b:SetSize(size, size)
        end
        b.FlareUI_Icon:SetTexture("Interface\\Icons\\" .. path)
        b:ClearAllPoints()
        b:SetPoint(point, rel, relPoint, x, y)
        b:Show()
    end
    -- (as many as the row holds, in up to two lines; the second line above the first)
    -- an icon's place: point, the plate's point, x, y (centred: the first line's middle on the plate's)
    local function Spot(i, size, isDebuff, count)
        local per = NP.AuraPerLine(p, db, size)
        local look = AuraLook(size, isDebuff, db)
        local cell = (look and look.cellHeight or size) + C.AURA_GAP
        local place = isDebuff and "debuffs" or "buffs"
        local x, y = (i - 1) % per * (size + C.AURA_GAP), C.AURA_GAP + math_floor((i - 1) / per) * cell + NP.AuraLift(db, place) + (p.nameAboveLift or 0)
        local row = NP.AuraRowSide(db, place)
        if row == "right" then return "BOTTOMRIGHT", "TOPRIGHT", -x, y end
        if row == "left" then return "BOTTOMLEFT", "TOPLEFT", x, y end
        local n = math.min(count, per)
        return "BOTTOMLEFT", "TOP", x - (n * size + (n - 1) * C.AURA_GAP) / 2, y
    end
    p.debuffIcon, p.buffIcon, p.ccIcon = nil, nil, nil
    if db.debuffs ~= "off" then
        local count = NP.AuraCount(p, db, db.debuffSize, db.debuffMax)
        for i = 1, count do
            local point, to, x, y = Spot(i, db.debuffSize, true, count)
            Icon(SAMPLE_ICONS[(i - 1) % #SAMPLE_ICONS + 1], db.debuffSize, true, C.SAMPLE_DISPEL[(i - 1) % #C.SAMPLE_DISPEL + 1],
                point, p.box, to, x, y)
            if i == 1 then p.debuffIcon = icons[n] end
        end
    end
    if db.buffs ~= "off" then
        local count = NP.AuraCount(p, db, db.buffSize, db.buffMax)
        for i = 1, count do
            local point, to, x, y = Spot(i, db.buffSize, false, count)
            Icon(C.SAMPLE_BUFFS[(i - 1) % #C.SAMPLE_BUFFS + 1], db.buffSize, false, "None",
                point, p.box, to, x, y)
            if i == 1 then p.buffIcon = icons[n] end
        end
    end
    if db.cc then
        Icon("Spell_Nature_Polymorph", db.ccSize, true, "Magic", "LEFT", p.sideRight or p.rightOf or p.box, "RIGHT",
            C.SIDE_GAP - (p.sidePad and p.sidePad.right or 0), 0)
        p.ccIcon = icons[n]
    end
    p.defIcon = nil
    if db.defensives then
        Icon("Spell_Holy_DivineIntervention", db.ccSize, false, "None", "RIGHT", p.sideLeft or p.box, "LEFT",
            -C.SIDE_GAP + (p.sidePad and p.sidePad.left or 0), 0)
        p.defIcon = icons[n]
    end
    if f.clickable then PlaceHits(p) end
    local castRoom = (cast and db.castbar and showCast) and (db.castHeight + C.CAST_GAP + 16) or 0
    -- (room for the quest mark and its progress on one side, crowd control or defensives on both)
    local w = db.width + 2 * (db.ccSize + db.height + 16) + 40 + (questOn and 40 or 0)
    local h = top + db.height + 8 + castRoom + 6 + (comboOn and 22 or 0)
    f:SetSize(w, h)
    return w, h
end

-- Bar Effects in the preview: a hit (or a heal back up once low), as a live plate takes it, so
-- Animations glides, the Damage Trail holds then shrinks, and the Edge Glow flashes
function NP.SampleHit(f)
    local p = f.plates and f.plates[1]
    local db = SharedSettings(true)
    if not (p and db and p.health:IsVisible()) or (f.states and f.states.execute) then return end
    local before = f.demoShare or 0.72
    local after = before - 0.16
    if after < 0.3 then after = 0.9 end
    f.demoShare = after
    ns.SetBarValue(p.health, after, db.smoothBars)
    local trail = p.trail
    if trail then
        if db.damageTrail and after < before then
            trail:SetMinMaxValues(0, 1)
            trail:SetValue(before)
            trail:Show()
            C_Timer.After(UF and UF.TRAIL_DELAY or 0.4, function()
                if trail:IsShown() then ns.SetBarValue(trail, after, true) end
            end)
        elseif db.damageTrail then
            trail:SetValue(after)
        else
            trail:Hide()
        end
    end
    local look = p.health.fuiLook
    if look and look.edgeClip:IsShown() then
        look.pulse:Stop()
        look.pulse:Play()
    end
    if p.textOn then
        BT.FillAll(p.texts, p.slots, { cur = math_floor(after * 1840), max = 1840, percent = after * 100, lost = math_floor((1 - after) * 1840) })
    end
    p.execTint:SetAlpha((p.execAt and after < p.execAt) and 1 or 0)
end

--------------------------------------------------
-- 10. CVARS, DIAGNOSTICS, REFRESH, INIT
--------------------------------------------------
function NP.GetCVar(name) return GetCVarBool(name) end
function NP.SetCVar(name, on)
    if InCombatLockdown() then return end
    SetCVar(name, on and "1" or "0")
end

-- Test on Plates (the preview strip's button): for 20 seconds every plate FlareUI draws shows a
-- looping sample cast; every second one is an important cast, every third one you can't interrupt
C.TEST_SECONDS, C.TEST_LOOP = 20, 2.5
-- kind: the type every plate shows while the test runs (the one picked in the settings)
function NP.TestMode(on, kind, endless)
    if on == nil then on = not NP.testing end
    if not on then
        local was = NP.testKind
        NP.testing, NP.testKind = nil, nil
        if NP.testTicker then NP.testTicker:Cancel() NP.testTicker = nil end
        -- the test's sample combo points go
        for _, p in ipairs(pool) do
            for _, gem in ipairs(p.testCombo or {}) do gem:Hide() end
            p.testIcons = nil
        end
        if was then NP:Refresh() else for _, p in pairs(byPlate) do NP.UpdateAll(p) end end
        return
    end
    -- (endless: runs until stopped, the settings' Stop Testing button)
    NP.testing = endless and math.huge or GetTime() + C.TEST_SECONDS
    if kind ~= NP.testKind then
        NP.testKind = kind
        for _, p in ipairs(pool) do p.testIcons = nil end
        NP:Refresh()
    end
    if not NP.testTicker then NP.testTicker = C_Timer.NewTicker(0.05, NP.TestTick) end
end
function NP.TestTick()
    local db = SharedSettings()
    if not NP.testing or GetTime() > NP.testing or not db then
        NP.TestMode(false)
        if ns.NameplatesPinned then ns.NameplatesPinned.Draw() end
        return
    end
    local share = (GetTime() % C.TEST_LOOP) / C.TEST_LOOP
    local n = 0
    for _, p in pairs(byPlate) do
        n = n + 1
        local cast = p.cast
        local tdb = PDB(p)
        if cast and tdb.castbar and not p.nameOnly then
            if UF and UF.EndCastFlash then UF.EndCastFlash(cast) end
            cast:SetMinMaxValues(0, 1)
            cast:SetValue(share)
            cast.Text:SetText(L["Shadow Bolt"])
            cast.Icon:SetTexture("Interface\\Icons\\Spell_Shadow_ShadowBolt")
            local nokick = n % 3 == 0
            local c = NP.Color(nokick and "castNoInterrupt" or "cast")
            cast:GetStatusBarTexture():SetVertexColor(1, 1, 1)
            cast:SetStatusBarColor(c[1], c[2], c[3])
            cast.shield:SetAlpha(nokick and 1 or 0)
            cast.important:SetAlpha((n % 2 == 0 and tdb.castImportant) and 1 or 0)
            cast.target:SetShown(false)
            if not cast:IsShown() then cast:Show() end
        end
        NP.TestIcons(p, tdb)
    end
end

-- the test shows every icon the type's settings draw: the rarity dragon, the quest mark and its
-- progress, and combo points under the plate (kept up on each tick: the plate's own updates hide them)
function NP.TestIcons(p, tdb)
    if p.nameOnly then return end
    if tdb.rarityIcon ~= false then
        if C_Texture.GetAtlasInfo(C.ELITE_GOLD) then p.elite:SetAtlas(C.ELITE_GOLD) end
        p.elite:Show()
    end
    local questOn = NP.QuestOn()
    if questOn then
        -- (the plate's own quest check may have hidden them since the last tick: shown again, the
        -- side auras move back out past them)
        local icon, progress = NP.QuestParts(p)
        local changed = p.quest:IsShown() ~= icon or p.questText:IsShown() ~= progress
        p.quest:SetShown(icon)
        if p.questText:GetText() ~= "3/8" then p.questText:SetText("3/8") end
        p.questText:SetShown(progress)
        if changed and p.testIcons then NP.PlaceSides(p) end
    end
    local shared = SharedSettings()
    local comboOn = shared and shared.comboPoints and ns.CreateComboPoint and PDB(p).combo ~= false and not p.nameOnly
    -- (made out of combat only: frames made on a nameplate in a fight come out forbidden)
    if comboOn and not p.testCombo and not InCombatLockdown() then
        p.testCombo = {}
        for i = 1, 5 do p.testCombo[i] = ns.CreateComboPoint(p.overlay, i, 14) end
    end
    if not p.testIcons then
        -- once per test: placed, and set to 3 of 5
        p.testIcons = true
        if questOn then NP.PlaceSides(p) end
        local gemSize = 14 * (NP.ComboScale and NP.ComboScale(PDB(p).width) or 1)
        local step = ns.ComboPointStep and ns.ComboPointStep(gemSize) or 16
        for i, gem in ipairs(p.testCombo or {}) do
            gem:ClearAllPoints()
            if ns.SizeComboPoint then ns.SizeComboPoint(gem, gemSize) end
            gem:SetPoint("TOP", p.below, "BOTTOM", (i - 3) * step, -4)
            if ns.SetComboPoint then ns.SetComboPoint(gem, 3, false) end
        end
    end
    for _, gem in ipairs(p.testCombo or {}) do gem:SetShown(comboOn and true or false) end
end

-- /fui plates
function NP.Report()
    local db = DB()
    local onPlates, mine = 0, 0
    for _ in ipairs(C_NamePlate.GetNamePlates()) do onPlates = onPlates + 1 end
    for _ in pairs(byPlate) do mine = mine + 1 end
    local lines = {
        "|cffffd100FlareUI Nameplates|r",
        ("Module: %s%s"):format(db and db.enabled and "on" or "off", NP.standDown and " (standing down: another nameplate addon)" or ""),
        ("Plates now: %d from the game, %d drawn by FlareUI, %d spare"):format(onPlates, mine, #spare),
        ("Since login: %d drawn, %d left to Blizzard (forbidden), %d (hidden unit), %d (none spare), %d failed"):format(
            stats.claimed, stats.forbidden, stats.secret, stats.given, stats.failed),
        ("Enemy plates: %s, friendly players: %s, always: %s"):format(tostring(GetCVarBool("nameplateShowEnemies")),
            tostring(GetCVarBool("nameplateShowFriendlyPlayers")), tostring(GetCVarBool("nameplateShowAll"))),
        ("Role: %s"):format(state.role),
    }
    if stats.lastError then lines[#lines + 1] = "Last error: " .. tostring(stats.lastError) end
    for _, line in ipairs(lines) do print(line) end
end

-- The game plate's box (stacking and clicks) sized to our plate: the bar, its border and the name
-- above, with a little room to click. Blizzard's friendly plates share the box (the game has one size
-- for all); Blizzard builds them up from the box's bottom, so a shorter box leaves them as they look.
-- Refused in a fight: done when it ends. Blizzard sets its own size again on display and option changes; the hook
-- on its driver notes Blizzard's size and puts ours back.
C.CLICK_ROOM = 4
function NP.ApplySize()
    if not NP.ready or NP.standDown then return end
    if InCombatLockdown() then state.sizePending = true return end
    state.sizePending = nil
    local db = NP.TypeDB("enemyNpc", true)
    local _, _, pad = NP.Edge(db)
    local w = db.width + 2 * pad + 2 * C.CLICK_ROOM
    local h = db.height + 2 * pad + NP.NameRoom(db) + 2 * C.CLICK_ROOM
    state.ourW, state.ourH = w, h
    pcall(C_NamePlate.SetNamePlateSize, w, h)
end
local function NoteBlizzardSize()
    local ok, w, h = pcall(C_NamePlate.GetNamePlateSize)
    if ok and type(w) == "number" and type(h) == "number" and not (w == state.ourW and h == state.ourH) then
        state.blizzW, state.blizzH = w, h
    end
end
function NP.HookDriver()
    local driver = _G.NamePlateDriverFrame
    if state.driverHooked or not (driver and driver.UpdateNamePlateSize) then return end
    state.driverHooked = true
    hooksecurefunc(driver, "UpdateNamePlateSize", function()
        if NP.standDown then return end
        NoteBlizzardSize()
        NP.ApplySize()
    end)
end

-- A settings change: every plate comes off its nameplate, is laid out while parked (a plate on a
-- nameplate can't be measured under addon restrictions), and the sync pass puts them back
function NP.ApplyPlateSettings()
    local held = {}
    for _, p in pairs(byPlate) do held[#held + 1] = p end
    for _, p in ipairs(held) do Release(p) end
    for _, p in ipairs(pool) do
        -- A parked plate may still point into the profile that was active in combat.
        if p.tdb then p.tdb = NP.TypeDB(p.tdb.kind, true) end
        local ok, err = pcall(NP.Layout, p)
        if not ok then ns.LogError("Nameplates Layout", err) end
    end
    NP.ApplySize()
    NP.PinZoom()   -- (the game settings FlareUI sets: out of a fight only)
    NP.Sync()
end

local function CachePendingSettings()
    pendingSettings = CacheSettings(pendingSettings)
    if pendingSettings then pendingSettings.role = PendingRole(SharedSettings()) end
end

function NP:Refresh()
    if not NP.ready then return end
    if pendingSettings then
        CachePendingSettings()
        return
    end
    settings = CacheSettings(settings)
    NP.ApplyPlateSettings()
    if NP.ApplyCombo then NP.ApplyCombo() end
end

-- The game's own plate zoom (distance, target, larger plates) is set to 1 while the module is on, so
-- Target Scale is the only zoom, and its fades with distance and for plates that aren't your
-- target are off, so Out of Range, Out of Sight and the target options are the only ones. Each setting is backed up first and put back when the module is off
-- (at the next login: ShouldLoad runs either way) or stands down.
C.ZOOM_CVARS = { "nameplateSelectedScale", "nameplateMinScale", "nameplateMaxScale", "nameplateLargerScale",
    "nameplateMinAlpha", "nameplateMaxAlpha", "nameplateSelectedAlpha", "nameplateNotSelectedAlpha" }
-- Keep Target on Screen: the game's own setting (its name differs between game versions)
C.CLAMP_CVARS = { "nameplateTargetRadialPosition", "clampTargetNameplateToScreen" }
function NP.ClampCVar()
    for _, name in ipairs(C.CLAMP_CVARS) do
        if C_CVar.GetCVar(name) ~= nil then return name end
    end
end
-- The game settings FlareUI sets while the module is on: the plate zoom at 1, Out of Sight opacity
-- (once picked) and Keep Target on Screen. Each is backed up first and put back when FlareUI stops
-- setting it (the setting turned off, the module off at the next login, or standing down).
function NP.PinZoom()
    if InCombatLockdown() or not (ns.db and ns.db.global) then return end
    local db = SharedSettings() or {}
    local want = {}
    for _, name in ipairs(C.ZOOM_CVARS) do want[name] = "1" end
    if db.obscuredAlpha then want.nameplateOccludedAlphaMult = string.format("%.2f", db.obscuredAlpha) end
    local clamp = NP.ClampCVar()
    if clamp and db.clampTarget then want[clamp] = "1" end
    local backup = ns.db.global.nameplateZoomBackup or {}
    for name, value in pairs(want) do
        local now = C_CVar.GetCVar(name)
        if now ~= nil then
            if backup[name] == nil then backup[name] = now end
            if tonumber(now) ~= tonumber(value) then pcall(SetCVar, name, value) end
        end
    end
    -- no longer set by FlareUI: back as it was
    for name, value in pairs(backup) do
        if want[name] == nil then
            if C_CVar.GetCVar(name) ~= nil then pcall(SetCVar, name, value) end
            backup[name] = nil
        end
    end
    ns.db.global.nameplateZoomBackup = backup
end
function NP.RestoreZoom()
    local backup = ns.db and ns.db.global and ns.db.global.nameplateZoomBackup
    if not backup or InCombatLockdown() then return end
    for name, value in pairs(backup) do
        if C_CVar.GetCVar(name) ~= nil then pcall(SetCVar, name, value) end
    end
    ns.db.global.nameplateZoomBackup = nil
end

local function MigrateProfile()
    local db = DB()
    -- text slots saved by the first version kept the Left slot empty; they start over once
    if db and db.barText and not db.textV2 then db.barText = nil end
    if db then db.textV2 = true end
    -- Friendly Plates (Blizzard / FlareUI) became the Friendly type's Plate
    if db and rawget(db, "friendly") == "flareui" then NP.TypeStore("friendly").plate = "bar" end
    if db then db.friendly = nil end
    -- Enemy and Friendly split again into players and NPCs (each side keeps the one setup it
    -- had, copied to both); Minions went into Minor (Minor's setup stays). Once per profile.
    if db and not db.typesV3 then
        db.typesV3 = true
        local t = db.types
        if t then
            local function Split(from, player, npc)
                local own = t[from]
                if own then
                    t[player] = t[player] or Copy(own)
                    t[npc] = t[npc] or Copy(own)
                end
                t[from] = nil
            end
            Split("enemy", "enemyPlayer", "enemyNpc")
            Split("friendly", "friendlyPlayer", "friendlyNpc")
            t.minion = nil
        end
        if type(db.combatPlates) == "string" and db.combatPlates ~= "none" then
            local MAP = { enemy = "enemyPlayer,enemyNpc", friendly = "friendlyPlayer,friendlyNpc", minion = "minor", minor = "minor" }
            local seen, out = {}, {}
            for token in db.combatPlates:gmatch("[^,]+") do
                for k in (MAP[token] or token):gmatch("[^,]+") do
                    if not seen[k] then seen[k] = true out[#out + 1] = k end
                end
            end
            db.combatPlates = #out > 0 and table.concat(out, ",") or "none"
        end
    end
    -- Combo Points, Quest Objective and the In Combat plates were saved with Quality of Life. Once
    -- per profile (a Quality of Life import later on never reaches the plates). In Combat only worked with
    -- Quality of Life on: with it off nothing is carried over, so no one's plates start to hide.
    if db and not db.ownSwitches then
        db.ownSwitches = true
        local tw = ns.db.profile.tweaks
        if tw then
            if tw.nameplateCombo then db.comboPoints = true end
            if tw.nameplateQuest then db.questMarks = true end
            if tw.enabled then
                if tw.combatPlates then db.enemyInCombat = true end
                if tw.combatFriendly then db.friendlyInCombat = true end
            end
            for _, key in ipairs({ "nameplateCombo", "nameplateQuest", "combatPlates", "combatFriendly", "nameplateHideLevel",
                    "nameplateHideNames", "nameplateLevelName" }) do tw[key] = nil end
        end
    end
    NP.MigratePresets()
    -- the plates read the unit frames' Aura Swipe, Aura Timer and Timer Colour before they had
    -- their own: those values are saved here once as the old shared ones (C.WAS_SHARED), so every
    -- type's preset keeps them and no plate changes
    if db and not db.auraLookV1 then
        db.auraLookV1 = true
        local uf = ns.db.profile.unitframes or {}
        for _, key in ipairs({ "auraSwipe", "auraTimer", "auraTimerColor" }) do
            if uf[key] ~= nil and rawget(db, key) == nil then db[key] = uf[key] end
        end
    end
    -- Name Only plates have their own font: it starts as the Names font they used until now
    if db and not db.nameOnlyFontV1 then
        db.nameOnlyFontV1 = true
        if type(db.nameFont) == "table" then
            db.nameOnlyFont = type(db.nameOnlyFont) == "table" and db.nameOnlyFont or {}
            for key, value in pairs(db.nameFont) do db.nameOnlyFont[key] = Copy(value) end
        end
    end
    -- the Chevron and Hook arrows went (Chevron was the Yellow one turned)
    if db and (db.targetArrows == "chevron" or db.targetArrows == "hook") then db.targetArrows = "npe" end
    return db
end
NP.MigrateProfile = MigrateProfile

function NP:ProfileChanged()
    if not self.ready or self.standDown then return end
    MigrateProfile()
    if InCombatLockdown() then
        CachePendingSettings()
        -- The panel's AceDB callback can run before ours. Repaint an already open preview.
        RedrawOpenPreview()
    else
        pendingSettings = nil
        self:Refresh()
    end
end

function NP:ShouldLoad()
    local db = MigrateProfile()
    if not (db and db.enabled) then NP.RestoreZoom() return false end
    if not (K and BT and K.CreateCastBar) then return false end
    if NP.OtherAddon() then NP.standDown = true NP.RestoreZoom() return false end
    return true
end

-- the pool, all at once: aura containers made after login never show
local function BuildPool()
    -- laid out for the types as they usually come, so the first ones need no layout as they appear
    local share = { "enemyNpc", "friendlyNpc", "enemyNpc", "friendlyPlayer", "enemyNpc", "minor", "enemyNpc", "enemyPlayer" }
    for i = 1, C.POOL do
        local p = NP.Build(hidden, false)
        p.kind = share[(i - 1) % #share + 1]
        p.tdb = NP.TypeDB(p.kind, true)
        local ok, err = pcall(NP.Layout, p)
        if not ok then ns.LogError("Nameplates Layout", err) end
        pool[#pool + 1] = p
        spare[#spare + 1] = p
    end
end

function NP:Init()
    if self.initialized then return end
    if InCombatLockdown() then
        -- a /reload in a fight: the plates are built when it ends
        self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            self:Init()
        end)
        return
    end
    self.initialized = true
    settings = CacheSettings(settings)
    -- the aura containers must be made now (later ones never show): all forty plates' at once
    if K.HasAuraSupport then K.HasAuraSupport() end
    BuildPool()
    NP.ready = true
    if ns.db.RegisterCallback then
        for _, event in ipairs({ "OnProfileChanged", "OnProfileCopied", "OnProfileReset" }) do
            ns.db.RegisterCallback(self, event, "ProfileChanged")
        end
    end
    -- Musician: out of a fight it swaps a friendly player's plate for its own name frame, which
    -- showed next to ours. Its API for nameplate addons turns that off, as its
    -- own Plater and ElvUI modules do (NP.Claim hides a frame it already made)
    local musician = _G.Musician and _G.Musician.NamePlates
    if musician and musician.ForbidHideHealthBars then pcall(musician.ForbidHideHealthBars) end
    NP.PinZoom()
    NoteBlizzardSize()
    NP.HookDriver()
    NP.ApplySize()
    pcall(NP.UpdateGroup)
    pcall(NP.UpdateRole)
    for _, event in ipairs(GLOBAL_EVENTS) do self:RegisterEvent(event, "OnEvent") end
    C_Timer.NewTicker(C.SYNC, NP.Sync)
    C_Timer.NewTicker(0.1, NP.RangeTick)
    state.execAt = NP.ExecuteAt({ execute = "auto" })
    -- Kick Ready: casts on screen take the new colour when your interrupt comes back or goes
    UF.onKickChanged = function()
        -- (per type: each plate checks its own)
        for _, p in pairs(byPlate) do
            local tdb = PDB(p)
            if (tdb.kickReady or tdb.castKickMark) and p.cast and p.cast:IsShown() and not p.cast.flashing then NP.QueuePlate(p, D.CAST) end
        end
    end
    NP.Sync()
    if NP.ApplyCombo then NP.ApplyCombo() end
end
