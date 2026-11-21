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

-- every tunable number in one table (the main chunk keeps few locals)
local C = {
    POOL = 40,                -- Blizzard keeps 40 plates at most
    SYNC = 2,                 -- seconds between sync passes
    NAME_GAP = 2,             -- name above the bar
    LEVEL_GAP = 3,            -- level left of the bar
    AURA_GAP = 2,
    CAST_GAP = 0,             -- cast bar right under the bar's frame
    ELITE = 14,               -- elite / rare mark
    RAID = 18,                -- raid marker
    HIGHLIGHT = 0.18,         -- mouseover light
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

-- PLATE TYPES: enemyPlayer, enemyNpc, friendlyPlayer, friendlyNpc and minor (pets, totems, guardians
-- and minor mobs).
-- Each type keeps its own value of these settings (nameplates.types[kind]); every other setting is
-- shared. A type's view reads its own value first, then the shared one.
-- (11-20, Malkkav: open PvP is big on Forever, so players and NPCs are split again on both sides;
-- Minions merged into Minor, one type for pets, totems, guardians and minor mobs)
C.KINDS = { "enemyPlayer", "enemyNpc", "friendlyPlayer", "friendlyNpc", "minor" }
C.FRIENDLY = { friendlyPlayer = true, friendlyNpc = true }
C.TYPE_KEYS = {
    plate = true, width = true, height = true, level = true, levelSide = true, barText = true, hideTextAtFull = true,
    healthColor = true, castbar = true, castHeight = true, debuffs = true, debuffSize = true, debuffMax = true,
    buffs = true, buffSize = true, buffMax = true, hideBuffs = true, cc = true, ccSize = true, defensives = true, clickThrough = true,
    -- (11-20, Malkkav: every row on the Style tab is the type's own) the look rows and Name Only Size
    texture = true, border = true, bgOpacity = true, smoothBars = true, edgeGlow = true, damageTrail = true, nameOnlySize = true,
    -- (11-20, Malkkav: every row on the Plate, Extras, Cast Bar and Auras tabs is the type's own;
    -- Targeting, Visibility and Fonts stay shared. Role stays shared: it is yours, not the plate's;
    -- so do the colours, picked in their own window)
    rarityIcon = true, combo = true, questIcon = true, questProgress = true,
    threat = true, threatGlow = true, aggroFlash = true, threatScale = true, threatPercent = true,
    execute = true, colorBoss = true, colorElite = true, colorCaster = true, colorTrivial = true, mobTypesWhere = true,
    groupColor = true, raidColor = true,
    castIcon = true, castTimer = true, castTarget = true, kickReady = true, castKickMark = true, castTargetedFlash = true, castImportant = true,
}
-- these were one shared value before 11-20: a preset reads the profile's old shared value, so every
-- type keeps the look it had; a type's Custom keeps its own from then on
C.WAS_SHARED = { texture = true, border = true, bgOpacity = true, smoothBars = true, edgeGlow = true, damageTrail = true,
    rarityIcon = true, questProgress = true, threat = true, threatGlow = true, aggroFlash = true, threatScale = true, threatPercent = true,
    execute = true, colorBoss = true, colorElite = true, colorCaster = true, colorTrivial = true, mobTypesWhere = true,
    groupColor = true, raidColor = true,
    castIcon = true, castTimer = true, castTarget = true, kickReady = true, castKickMark = true, castTargetedFlash = true, castImportant = true }
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
-- EACH TYPE'S OWN DEFAULTS (11-20, Malkkav's setup): what Full and the other presets build on. Both
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
        width = 100, height = 13, level = "off", levelSide = "left",   -- (Colour By: Core's default, 11-20)
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
function NP.TypeDB(kind)
    kind = kind or "enemyNpc"
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
end
-- 11-19: types saved before presets (their own values over the shared ones) become their preset when
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
    for _, kind in ipairs(C.KINDS) do
        local own = db.types[kind] or {}
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
end
local function PDB(p) return p.tdb or NP.TypeDB("enemyNpc") end

function NP.Palette()
    local db = DB()
    return db and db.palette == "custom" and "custom" or "flareui"
end
-- a colour { r, g, b }: yours on the Custom palette, else FlareUI's
function NP.Color(key)
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
function NP.PulseTick(self)
    local wave = 0.5 + 0.5 * math.cos((GetTime() % C.PULSE_PERIOD) / C.PULSE_PERIOD * 2 * math.pi)
    self:SetAlpha(C.PULSE_LOW + (1 - C.PULSE_LOW) * wave)
end
function NP.ClockPulse(frame)
    local pulse = {}
    function pulse:Play() frame:SetScript("OnUpdate", NP.PulseTick) self.on = true end
    function pulse:Stop() frame:SetScript("OnUpdate", nil) frame:SetAlpha(1) self.on = false end
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
    g.pulse:Play()
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
        if ok and calc then p.calc = calc end
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
            local function Fade() NP.UpdateFade(p) NP.PlaceBelow(p) end
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
        -- (Full Name stays Full Name: before 11-21 it was read as First Name, so plates never showed
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
            local inIn = bgIn + 1
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

-- Debuffs and buffs share the row above the plate, half each; one alone takes the whole width
function NP.AuraRowWidth(p, db)
    local w = p.plateW or db.width
    if db.debuffs ~= "off" and db.buffs ~= "off" then return math_floor((w - C.AURA_GAP) / 2) end
    return w
end
-- where a row above the plate starts: buffs "left", debuffs "right", the one shown alone "center"
-- (nil: not a row above the plate)
function NP.AuraRowSide(db, place)
    if place ~= "debuffs" and place ~= "buffs" then return nil end
    if db.debuffs == "off" or db.buffs == "off" then return "center" end
    return place == "buffs" and "left" or "right"
end
-- how many icons of a size fit one line of it; each takes two lines at most (C.AURA_LINES)
function NP.AuraPerLine(p, db, size)
    return math_max(1, math_floor((NP.AuraRowWidth(p, db) + C.AURA_GAP) / (size + C.AURA_GAP)))
end
function NP.AuraCount(p, db, size, max)
    return math_max(1, math.min(max or 1, C.AURA_LINES * NP.AuraPerLine(p, db, size)))
end

-- The marks beside the plate (the bar and its level box or disc), SIDE_GAP from it as the level box:
--   the quest mark on the side away from the level (the right with no level beside the bar), its
--   progress outside it; crowd control on the right and defensives on the left, the same distance
--   out, past the quest mark on its side; the raid marker on the left, past the defensives.
-- Target Highlight arrows sit right against the plate; everything here draws above them.
function NP.PlaceSides(p)
    local leftOf = (p.levelAnchor and p.levelSide ~= "right") and p.levelAnchor or p.box
    p.rightOf = (p.levelAnchor and p.levelSide == "right") and p.levelAnchor or p.box
    local gap = C.SIDE_GAP
    p.quest:ClearAllPoints()
    p.questText:ClearAllPoints()
    p.raid:ClearAllPoints()
    local questRight = not (p.levelAnchor and p.levelSide == "right")
    p.questSide = questRight and "right" or "left"
    local outer = { left = leftOf, right = p.rightOf }
    -- (placed even while hidden: whatever shows them later finds them in place)
    -- (the progress beside the icon, or in its place with Objective Icon off)
    local iconOn = p.quest:IsShown()
    if questRight then
        p.quest:SetPoint("LEFT", p.rightOf, "RIGHT", gap, 0)
        if iconOn then p.questText:SetPoint("LEFT", p.quest, "RIGHT", 1, 0) else p.questText:SetPoint("LEFT", p.rightOf, "RIGHT", gap + 1, 0) end
    else
        p.quest:SetPoint("RIGHT", leftOf, "LEFT", -gap, 0)
        if iconOn then p.questText:SetPoint("RIGHT", p.quest, "LEFT", -1, 0) else p.questText:SetPoint("RIGHT", leftOf, "LEFT", -gap - 1, 0) end
    end
    p.questText:SetJustifyH(questRight and "LEFT" or "RIGHT")
    if p.questText:IsShown() then outer[p.questSide] = p.questText
    elseif iconOn then outer[p.questSide] = p.quest end
    -- (the quest art is mostly empty round its mark: what sits past it comes in by that much)
    local pad = { left = 0, right = 0 }
    if outer[p.questSide] == p.quest then pad[p.questSide] = p.questPad or 0 end
    local auras = p.auras
    local db = PDB(p)
    if auras then
        if auras.cc then
            auras.cc.container:ClearAllPoints()
            auras.cc.container:SetPoint("LEFT", outer.right, "RIGHT", gap - pad.right, 0)
        end
        if auras.defensives then
            auras.defensives.container:ClearAllPoints()
            auras.defensives.container:SetPoint("RIGHT", outer.left, "LEFT", -gap + pad.left, 0)
        end
    end
    -- (the raid marker clear of the defensives: two icons at most)
    local room = (db and db.defensives) and (2 * db.ccSize + C.AURA_GAP + gap) or 0
    if p.nameOnly then
        -- Name Only: the box is a whole plate wide round a short name, so beside it the marker stood
        -- far off (11-21); it sits over the name instead (a name's width can't be measured on a plate)
        p.raid:SetPoint("BOTTOM", p.name, "TOP", 0, 2)
    else
        p.raid:SetPoint("RIGHT", outer.left, "LEFT", -gap - room - 1 + pad.left, 0)
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

-- Your target stands out: its border in the target colour (Border), a tint over its bar (Bar Colour),
-- a soft glow round it (Outer Glow) and the arrows. Everything else draws as it was.
function NP.UpdateTargetLook(p)
    local db = PDB(p)
    local on = p.targetShown and not p.nameOnly and not p.hiddenPlate and not p.unitHidden
    p.targetTint:SetShown(on and db.targetBarColor and true or false)
    p.targetGlow:SetShown(on and db.targetGlow and true or false)
    -- (the level box or disc glows with it: they and the bar read as one plate)
    p.levelGlow:SetShown(on and db.targetGlow and p.levelFrame:IsShown() and true or false)
    p.discGlow:SetShown(on and db.targetGlow and p.levelAnchor == p.levelArt and p.levelArt:IsShown() and true or false)
    if on and db.targetGlow then NP.PaintGlow(p) end
    local art = C.ARROWS[db.targetArrows or "off"]
    local where = db.targetArrowSide or "both"
    local want = { left = where == "both" or where == "left", right = where == "both" or where == "right", top = where == "top" }
    local changed = false
    for side, a in pairs(p.arrows) do
        local show = (on or (p.sample and p.sampleTarget)) and art and want[side] or false
        if show ~= a:IsShown() then changed = true end
        a:SetShown(show and true or false)
        if show then
            if not a.bounce:IsPlaying() then a.bounce:Play() end
        else
            a.bounce:Stop()
        end
    end
    if changed then NP.PlaceSides(p) end
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
    local c = NP.Color("target")
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

local function AuraLook(size, isDebuff)
    local uf = ns.db and ns.db.profile and ns.db.profile.unitframes or {}
    return ns.AuraLook and ns.AuraLook.ForUnit(size, isDebuff, false, uf.auraShape or "square", "both", uf.auraTimer or "none", "target")
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
            local look = AuraLook(size, lane.isDebuff)
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
        -- above the plate, as the unit frames: buffs from the left, debuffs from the right; one alone
        -- centred, as Blizzard's (the container takes its icons' size, so its middle is theirs)
        local row = NP.AuraRowSide(db, place)
        if row then
            container:ClearAllPoints()
            local point = (row == "left" and "BOTTOMLEFT") or (row == "right" and "BOTTOMRIGHT") or "BOTTOM"
            container:SetPoint(point, p.box, (row == "left" and "TOPLEFT") or (row == "right" and "TOPRIGHT") or "TOP", 0, C.AURA_GAP)
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
function NP.Edge(db)
    local _, _, borderName = Look(db)
    local edgeFile = BorderFile(borderName)
    local edge = edgeFile and ns.BorderEdgeSize(edgeFile, C.PLATE_EDGE) or 0
    local pad = edgeFile and (edge >= C.PLATE_EDGE and 4 or 2) or 1
    if edge >= C.PLATE_EDGE and db.height + 2 * pad < 22 then edge = math_max(8, math_floor((db.height + 2 * pad) * 2 / 3)) end
    -- the bar and its background sit inside the border's rounded corners (no square corner poking out)
    if edgeFile then pad = math_max(pad, math.ceil(edge * 0.3)) end
    return edgeFile, edge, pad
end

-- Nothing sits above the bar but auras (the name is one of the bar's text slots)
function NP.NameRoom() return 0 end

function NP.Layout(p)
    local db = PDB(p)
    if not db then return end
    local _, textureName, borderName = Look(db)
    local w, h = db.width, db.height
    local edgeFile, edge, pad = NP.Edge(db)

    p.root:SetSize(w + 2 * pad, h + 2 * pad)
    p.plateW = w + 2 * pad
    p.box:ClearAllPoints()
    p.box:SetAllPoints(p.root)
    -- (the background inside the border, as the bar: its square corners never show past the round ones)
    local bgIn = edgeFile and math_max(1, pad - 1) or 0
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
    local heal, absorb, target = NP.Color("heal"), NP.Color("absorb"), NP.Color("target")
    p.heal:SetStatusBarColor(heal[1], heal[2], heal[3], 0.5)
    p.absorb:SetStatusBarColor(absorb[1], absorb[2], absorb[3], 0.6)
    p.outline:SetBackdropBorderColor(target[1], target[2], target[3], 1)
    if p.cast then
        local important = NP.Color("important")
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
    local exec = NP.Color("execute")
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
        if pick then p.nameSlot, p.nameFull = slot, pick == "fullname" break end
    end
    local POINT = { left = "LEFT", middle = "CENTER", right = "RIGHT" }
    local X = { left = 3, middle = 0, right = -3 }
    for slot, fs in pairs(p.texts) do
        ApplyFontTo(fs, db.healthFont)
        fs:ClearAllPoints()
        fs:SetPoint(POINT[slot], p.health, POINT[slot], X[slot], 0)
        fs:SetJustifyH(POINT[slot])
        fs:SetShown(slot ~= p.nameSlot)
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
    p.textOn = BT.HasNumbers(p.slots.left) or BT.HasNumbers(p.slots.middle) or BT.HasNumbers(p.slots.right)
    p.textHolder:SetShown(p.textOn)
    -- Threat Percentage: the bar's middle; with something already there (numbers or the name), right
    -- of it and in brackets
    ApplyFontTo(p.threatText, db.healthFont)
    p.threatText:ClearAllPoints()
    p.threatBesides = nil
    if p.nameSlot == "middle" then
        p.threatText:SetPoint("LEFT", p.name, "RIGHT", 2, 0)
        p.threatBesides = true
    elseif BT.HasNumbers(p.slots.middle) then
        p.threatText:SetPoint("LEFT", p.texts.middle, "RIGHT", 2, 0)
        p.threatBesides = true
    else
        p.threatText:SetPoint("CENTER", p.health, "CENTER", 0, 0)
    end

    -- cast bar under the bar's frame, as wide as the bar
    if p.cast then
        local inset = (K and K.INSET) or 4
        p.castAnchor:ClearAllPoints()
        p.castAnchor:SetPoint("TOPLEFT", p.health, "TOPLEFT", -inset, 0)
        p.castAnchor:SetPoint("BOTTOMRIGHT", p.health, "BOTTOMRIGHT", inset, -(pad + C.CAST_GAP))
        -- (no border from the kit: its border step reads a frame's points, which the game refuses
        -- on a nameplate while addon restrictions are on; the border is set here from known sizes)
        K.LayoutCastBar(p.cast, {
            height = db.castHeight, icon = db.castIcon, timer = db.castTimer ~= false, name = true,
            texture = textureName, border = false, borderTexture = borderName,
            bgOpacity = db.bgOpacity,
        }, p.castAnchor, "BOTTOM")
        if edgeFile then
            -- (a Thick plate keeps the Thin border on its cast bar: the slimmer bar reads better)
            local castFile = borderName == "FlareUI Thick" and BorderFile("FlareUI Frames") or edgeFile
            p.cast.Border:SetBackdrop({ edgeFile = castFile, edgeSize = math.min(edge, math_max(6, db.castHeight)) })
            local c = ns.BORDER_COLOR
            p.cast.Border:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
            p.cast.Border:Show()
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
        NP.LayoutPulseBorder(glow, p.cast.Border, p.cast.Backdrop, edgeFile)
        if edgeFile then glow:SetFrameLevel(p.cast.Border:GetFrameLevel() + 1) end
        NP.PaintImportantGlow(glow, glow.color or NP.Color("important"))
        -- Flash When Targeted: the frame's whole inside, under its border, corners cut as the
        -- border's (as the plate's background, from the cast bar's own edge)
        local castEdge = edgeFile and math.min(edge, math_max(6, db.castHeight)) or 0
        local castArt = edgeFile and (borderName == "FlareUI Thick" and BorderFile("FlareUI Frames") or edgeFile)
        local fin = edgeFile and math_max(1, math.ceil(castEdge * 0.3) - 1) or 0
        local slanted = castArt and (castArt:find("FlareUI%-Frames") or castArt:find("FlareUI%-Thick"))
        p.cast.targeted:ClearAllPoints()
        p.cast.targeted:SetAllPoints(p.cast.Backdrop)
        NP.Background(p.cast.targeted.fill, fin, slanted and math_floor(castEdge * 13 / 32 + 0.5) or fin, 0.5, C.TARGETED_RGB, "ADD")
        -- Highlight Important Casts: its soft glow round the frame (the border copy sits on the border)
        NP.PlaceGlow(glow.soft, p.cast.Backdrop, w + (db.castIcon and db.castHeight or 0) + 8, db.castHeight + 8, C.IMPORTANT_SIZE)
        -- Kick Ready Mark: the waiting bar as wide as the cast bar (its icon aside: the kit sets no gap)
        p.cast.kickWait:SetSize(math_max(1, w - (db.castIcon and db.castHeight or 0)), db.castHeight)
        p.cast.kickSpark:SetSize(12, db.castHeight * 2.2)
        local kick = NP.Color("kickReady")
        p.cast.kickSpark:SetVertexColor(kick[1], kick[2], kick[3])
    end

    LayoutAuras(p, db)
    NP.PlaceBelow(p)
    -- Plate: Bar (all of the above), Name Only (the name alone, centred, in its colour) or Hidden
    -- (Show Plates in Combat: a Name Only type picked there gets its bar in a fight, NP.CombatFull)
    p.layFull = NP.CombatFull(db.kind)
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
        p.name:ClearAllPoints()
        p.name:SetPoint("CENTER", p.box, "CENTER", 0, 0)
        -- Name Only Size (11-20): this type's name alone, scaled; the Names font itself stays as set
        -- (through the font family with a size offset, from the Names font's own size: a SetFont on
        -- the string would beat the family from then on, and each layout would scale it again)
        local scale = (tonumber(db.nameOnlySize) or 100) / 100
        if scale ~= 1 and K and K.ApplyFont then
            local base = (db.nameFont and db.nameFont.size) or 12
            K.ApplyFont(p.name, db.nameFont, math_floor(base * (scale - 1) + 0.5))
        end
        p.name:SetWidth((w + 40) * math_max(1, scale))
        p.name:SetJustifyH("CENTER")
        p.name:Show()
        -- the NPC title under it, a little smaller (NP.UpdateTitle fills it)
        if p.npcTitle then
            if K and K.ApplyFont then
                local base = (db.nameFont and db.nameFont.size) or 12
                K.ApplyFont(p.npcTitle, db.nameFont, math_floor(base * (scale * C.TITLE_SIZE - 1) + 0.5))
            end
            p.npcTitle:ClearAllPoints()
            p.npcTitle:SetPoint("TOP", p.name, "BOTTOM", 0, -1)
            p.npcTitle:SetWidth((w + 40) * math_max(1, scale))
        end
    elseif p.npcTitle then
        p.npcTitle:Hide()
    end
    -- (again now that nameOnly is known: the raid marker's place depends on it)
    NP.PlaceSides(p)
    p.layKind = db.kind
    p.laid = true
end

--------------------------------------------------
-- 5. UPDATES (live plates)
--------------------------------------------------
-- Am I a tank? The group role, a raid's main tank, Defensive Stance, Bear Form or Righteous Fury;
-- or the role picked by hand. Read out of combat and on form changes; a hidden answer keeps the last.
function NP.UpdateRole()
    local db = DB()
    if db and db.role and db.role ~= "auto" then state.role = db.role return end
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
            if not okF or not canaccessvalue(aura) then return end   -- hidden: keep the last answer
            tank = aura ~= nil
        end
    end
    state.role = tank and "tank" or "damage"
end

-- the other tanks in the group (role or main tank), for "Another Tank Has It"
function NP.UpdateGroup()
    state.inGroup = IsInGroup()
    wipe(state.tanks)
    local prefix, count = nil, 0
    if IsInRaid() then prefix, count = "raid", GetNumGroupMembers() elseif IsInGroup() then prefix, count = "party", 4 end
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

-- the threat colour, or nil for the plate's own colour
local function ThreatRGB(unit, db)
    local mode = db.threat
    if mode == "off" or (mode == "groups" and not state.inGroup) then return nil end
    if C_Secrets and C_Secrets.ShouldUnitThreatStateBeSecret then
        local ok, secret = pcall(C_Secrets.ShouldUnitThreatStateBeSecret, "player", unit)
        if not ok or not canaccessvalue(secret) or secret then return nil end
    end
    local status = Readable(UnitThreatSituation("player", unit))
    if type(status) ~= "number" then return nil end
    local fighting = Readable(UnitAffectingCombat(unit))
    if not fighting then return nil end
    local key
    if state.role == "tank" then
        if status == 3 then key = "holding"
        elseif status == 2 then key = "losing"
        else
            key = "lost"
            for _, tank in ipairs(state.tanks) do
                local other = Readable(UnitThreatSituation(tank, unit))
                if type(other) == "number" and other >= 2 then key = "offtank" break end
            end
        end
    else
        if status == 1 then key = "gaining" elseif status >= 2 then key = "aggro" end
    end
    if key then
        local c = NP.Color(key)
        return c[1], c[2], c[3], key
    end
end

-- Threat Scale (tanks): a mob you lost grows, one someone is taking grows a little, one you hold
-- shrinks a little; another tank's stays as it is. One size per state, never animated.
C.THREAT_SCALE = { lost = 1.15, losing = 1.07, holding = 0.92 }
function NP.ApplyScale(p)
    local db = PDB(p)
    -- Targeting: your target, the others while you have one, or every plate with no target
    local k
    if p.targetShown then k = db.targetScale or 1
    elseif not p.sample and UnitExists("target") then k = db.notTargetScale or 1
    else k = db.noTargetScale or 1 end
    if db.threatScale and state.role == "tank" and p.threatKey then k = k * (C.THREAT_SCALE[p.threatKey] or 1) end
    -- (the settings preview keeps one size: the window fits it to its box, and a hover changing the
    -- state would make it jump)
    if p.sample then k = 1 end
    if p.scaleNow ~= k then
        p.scaleNow = k
        p.root:SetScale(k)
    end
end

-- The bar's colour, and the Outer Glow's with it (the glow always takes the bar's colour)
function NP.BarColor(p, r, g, b)
    p.health:SetStatusBarColor(r, g, b)
    p.barR, p.barG, p.barB = r, g, b
    if p.targetGlow:IsShown() then NP.PaintGlow(p) end
end

function NP.PaintGlow(p)
    local r, g, b = p.barR or 1, p.barG or 1, p.barB or 1
    for _, t in ipairs(p.targetGlow.parts) do t:SetVertexColor(r, g, b, C.GLOW_ALPHA) end
    for _, t in ipairs(p.levelGlow.parts) do t:SetVertexColor(r, g, b, C.GLOW_ALPHA) end
    for _, t in ipairs(p.discGlow.parts) do t:SetVertexColor(r, g, b, C.GLOW_ALPHA) end
end

-- THREAT PERCENTAGE (11-20, Malkkav; Extras > Threat, off): your threat on the unit as a number, in
-- the colours of the unit frames' Threat Text (Blizzard's threat status colours). 100% is where you
-- pull it; a tank holding it reads its lead over the next. Shown in a fight with threat on it, and on
-- the Test plates; never on Name Only plates. A threat the game keeps hidden shows nothing.
function NP.UpdateThreatText(p, db)
    local fs = p.threatText
    if not fs then return end
    local unit = p.unit
    local display, status
    if db.threatPercent and unit and not p.nameOnly then
        if NP.testKind then
            display, status = 75, 1
        else
            -- (11-21) the numbers are read whenever the game hands them over; before, the text gave up
            -- whenever ShouldUnitThreatStateBeSecret said yes, so it never showed in a fight. A secret
            -- percent goes into the text unread (C_StringUtil rounds it, SetFormattedText draws it),
            -- in white: its colour would need comparing it.
            local ok, tanking, detailed, scaled = pcall(UnitDetailedThreatSituation, "player", unit)
            if ok and canaccessallvalues(tanking, detailed, scaled) then
                display, status = scaled, detailed
                if tanking then
                    local lead = UnitThreatPercentageOfLead("player", unit)
                    if canaccessvalue(lead) and lead then display = lead end
                end
            elseif ok and not canaccessvalue(scaled) and C_StringUtil and C_StringUtil.RoundToNearestString then
                local okR, text = pcall(C_StringUtil.RoundToNearestString, scaled)
                if okR and pcall(fs.SetFormattedText, fs, p.threatBesides and "(%s%%)" or "%s%%", text) then
                    fs:SetTextColor(1, 1, 1)
                    fs:Show()
                    return
                end
            end
        end
    end
    if type(display) ~= "number" or display <= 0 then fs:Hide() return end
    local r, g, b = 1, 1, 1
    if status and status >= 1 and GetThreatStatusColor then r, g, b = GetThreatStatusColor(status) end
    fs:SetTextColor(r, g, b)
    fs:SetFormattedText(p.threatBesides and "(%.0f%%)" or "%.0f%%", display)
    fs:Show()
end

function NP.UpdateColor(p)
    local db, unit = PDB(p), p.unit
    if not (db and unit) then return end
    local tapped = Readable(UnitIsTapDenied(unit))
    if tapped then local c = NP.Color("tapped") NP.BarColor(p, c[1], c[2], c[3]) return end
    local r, g, b, threatKey = ThreatRGB(unit, db)
    if threatKey ~= p.threatKey then
        local before = p.threatKey
        p.threatKey = threatKey
        NP.ApplyScale(p)
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
    NP.PaintBorder(p)
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
        r, g, b = UF.HealthBarColor(unit, true, { healthColor = "health" })
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
    if r == nil then r, g, b = ReactionRGB(unit) end
    if r == nil then local c = NP.Color("hostile") r, g, b = c[1], c[2], c[3] end
    NP.BarColor(p, r, g, b)
end

function NP.UpdateHealth(p, glide)
    local unit, db = p.unit, PDB(p)
    local max = UnitHealthMax(unit)
    p.health:SetMinMaxValues(0, max)
    ns.SetBarValue(p.health, UnitHealth(unit), glide and db.smoothBars)
    if UF and UF.SetDamageTrail then UF.SetDamageTrail(p.trail, unit, glide, db.damageTrail) end
    if UF and UF.BarLookUpdate then UF.BarLookUpdate(p.health, unit, glide) end
    if p.textOn then
        BT.FillAll(p.texts, p.slots, K.HealthSource(unit, p.slots))
        -- Hide at Full: the client turns the percent into the texts' alpha (0 at full health)
        if db.hideTextAtFull and UF and UF.LostCurve then
            p.textHolder:SetAlpha(UnitHealthPercent(unit, true, UF.LostCurve()))
        else
            p.textHolder:SetAlpha(1)
        end
    end
    if db.healthColor == "health" then NP.UpdateColor(p) end
    NP.UpdateExecute(p)
end

function NP.UpdateHeals(p)
    local unit = p.unit
    local max = UnitHealthMax(unit)
    p.heal:SetMinMaxValues(0, max)
    p.absorb:SetMinMaxValues(0, max)
    local calc = p.calc
    if calc and UnitGetDetailedHealPrediction and pcall(UnitGetDetailedHealPrediction, unit, "player", calc) then
        local okH, incoming = pcall(calc.GetIncomingHeals, calc)
        local okA, absorbs = pcall(calc.GetDamageAbsorbs, calc)
        if okH then p.heal:SetValue(incoming) end
        if okA then p.absorb:SetValue(absorbs) end
        return
    end
    local okH, incoming = pcall(UnitGetIncomingHeals, unit)
    if okH then pcall(p.heal.SetValue, p.heal, incoming) end
    local okA, absorbs = pcall(UnitGetTotalAbsorbs, unit)
    if okA then pcall(p.absorb.SetValue, p.absorb, absorbs) end
end

function NP.UpdateName(p)
    local db, unit = PDB(p), p.unit
    if not p.nameSlot then return end
    -- the first name, or the surname too when Bar Text picks Full Name; Follow Name puts the level in
    -- front, in its colour
    local name = ns.UnitDisplayName(unit, nil, p.nameFull and true or false)
    local prefix = p.levelFollow and NP.LevelPrefix(unit)
    if prefix then p.name:SetFormattedText("%s%s", prefix, name) else p.name:SetText(name) end
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
    if player then
        local _, class = UnitClass(unit)
        local ok, color = pcall(C_ClassColor.GetClassColor, class)
        if ok and color then p.name:SetTextColor(color:GetRGB()) return end
    end
    -- a name with no bar under it carries the reaction colour itself
    if p.nameOnly then
        local r, g, b = ReactionRGB(unit)
        if r then p.name:SetTextColor(r, g, b) return end
    end
    p.name:SetTextColor(1, 1, 1)
end

-- NPC TITLES (11-21, Malkkav: always on, no option): an NPC's title ("General Goods", "Blacksmithing
-- Trainer") under its name on a Name Only plate, as players asked. The game has no call for it: it is
-- the second line of the NPC's tooltip (one line lower in Colourblind Mode), unless that line is its
-- level. Read once per NPC name (C.TITLES), never in instances (tooltip data can be secret there),
-- never a secret line. Friendly and enemy NPCs only (a pet's second line is its owner).
C.TITLE_SIZE = 0.8
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
function NP.UpdateTitle(p)
    local fs = p.npcTitle
    if not fs then return end
    local title = p.nameOnly and p.unit and (p.kind == "friendlyNpc" or p.kind == "enemyNpc") and NP.NPCTitle(p.unit)
    if not title then fs:Hide() return end
    fs:SetText(title)
    -- (11-21, Malkkav) its own colour, apart from the name's: the palette's light bronze, a tan as other
    -- nameplate addons draw titles in
    local c = ns.PALETTE.bronze5
    fs:SetTextColor(c[1], c[2], c[3], 1)
    fs:Show()
end

function NP.UpdateLevel(p)
    local db, unit = PDB(p), p.unit
    local level = ns.UnitShownLevel(unit)
    local classification = Readable(UnitClassification(unit))
    -- elite gold, rare silver
    local atlas
    if classification == "elite" or classification == "worldboss" then atlas = C.ELITE_GOLD
    elseif classification == "rare" or classification == "rareelite" then atlas = C.ELITE_SILVER end
    if atlas and C_Texture.GetAtlasInfo(atlas) then p.elite:SetAtlas(atlas) p.elite:Show() else p.elite:Hide() end
    if p.nameOnly or db.rarityIcon == false then p.elite:Hide() end
    if p.levelFollow then NP.UpdateName(p) return end
    if not p.levelShown then return end
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
    NP.PaintBorder(p)
    p.outline:SetShown(isTarget and not p.edgeFile and db.targetBorder ~= false)
    NP.UpdateTargetLook(p)
    NP.ApplyScale(p)
    NP.UpdateFade(p)
end

-- The border: your target's colour, else the threat colour (Threat Glow), else bronze
function NP.PaintBorder(p)
    local db = PDB(p)
    local c
    if p.targetShown and db.targetBorder ~= false then c = NP.Color("target")
    elseif db.threatGlow and p.threatRGB then c = p.threatRGB end
    -- Threat Glow: the pulsing border and its glow too (not over your target's own border)
    local threat = c ~= nil and c == p.threatRGB and not p.nameOnly
    p.threatFx:SetShown(threat)
    if threat then
        NP.PaintImportantGlow(p.threatFx, c)
        if not p.threatFx.pulse:IsPlaying() then p.threatFx.pulse:Play() end
    end
    -- the level disc takes the same colour (the box's border below, with the plate's)
    if c then p.levelArt:SetVertexColor(c[1], c[2], c[3]) else p.levelArt:SetVertexColor(1, 1, 1) end
    if not p.edgeFile then return end
    if c then
        p.border:SetBackdropBorderColor(c[1], c[2], c[3], 1)
        p.levelBorder:SetBackdropBorderColor(c[1], c[2], c[3], 1)
    else
        local b = ns.BORDER_COLOR
        p.border:SetBackdropBorderColor(b.r, b.g, b.b, b.a)
        p.levelBorder:SetBackdropBorderColor(b.r, b.g, b.b, b.a)
    end
end

-- Kick Ready Mark: while your interrupt is cooling down, a spark where on this cast it will be ready
-- (none on a cast you can't interrupt; gone once it's ready, when Kick Ready colours the bar)
function NP.UpdateKickMark(p, db, duration, channeling, notInterruptible)
    local cast = p.cast
    local KICK = UF and UF.KICK
    local spellID = db.castKickMark and KICK and KICK.Active and KICK.Active()
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
function NP.UpdateCast(p, event, by, barID)
    local cast, unit, db = p.cast, p.unit, PDB(p)
    if not cast or NP.testing then return end   -- (Test on Plates draws its own casts)
    if not (unit and db.castbar) then cast:Hide() return end
    local interrupted = event == "UNIT_SPELLCAST_INTERRUPTED"
        or (event == "UNIT_SPELLCAST_CHANNEL_STOP" and cast.isChannel and not (canaccessvalue(by) and by == nil))
    if interrupted and cast:IsShown() and not cast.flashing
        and (barID == nil or cast.castBarID == nil or barID == cast.castBarID) then
        UF.FlashInterrupted(cast, by)
        cast.kickClip:Hide()
        cast.shield:SetAlpha(0)
        cast.important:SetAlpha(0)
        return
    end
    local channeling = false
    local name, text, texture, notInterruptible, spellID, castBarID, _
    local n = select("#", UnitCastingInfo(unit))
    if n > 0 then
        name, text, texture, _, _, _, _, notInterruptible, spellID, castBarID = UnitCastingInfo(unit)
    else
        n = select("#", UnitChannelInfo(unit))
        if n > 0 then
            name, text, texture, _, _, _, notInterruptible, spellID, _, _, castBarID = UnitChannelInfo(unit)
            channeling = true
        end
    end
    if n == 0 then
        if not cast.flashing then cast:Hide() end
        return
    end
    UF.EndCastFlash(cast)
    cast.castBarID, cast.isChannel = castBarID, channeling
    local duration
    if channeling then duration = UnitChannelDuration(unit) else duration = UnitCastingDuration(unit) end
    if canaccessvalue(duration) and not duration then cast:Hide() return end
    local direction = channeling and Enum.StatusBarTimerDirection.RemainingTime or Enum.StatusBarTimerDirection.ElapsedTime
    cast:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, direction)
    if cast.TimerBinding then pcall(cast.TimerBinding.SetDuration, cast.TimerBinding, duration) end
    local label = text
    if canaccessvalue(text) then label = text or name or "" end
    cast.Text:SetText(label)
    cast.Icon:SetTexture(UF.CastIcon and UF.CastIcon(texture, spellID, false) or texture)
    local base = NP.Color(channeling and "channel" or "cast")
    -- Kick Ready: an enemy cast you could interrupt, while your interrupt is ready
    if db.kickReady and UF.KICK and UF.KICK.IsReady() then base = NP.Color("kickReady") end
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
    if db.castTargetedFlash and PlayerIsSpellTarget then
        local ok, mine = pcall(PlayerIsSpellTarget, unit)
        if not (ok and pcall(cast.targeted.SetAlphaFromBoolean, cast.targeted, mine, 1, 0)) then cast.targeted:SetAlpha(0) end
        if not cast.targetedPulse:IsPlaying() then cast.targetedPulse:Play() end
    else
        cast.targeted:SetAlpha(0)
        cast.targetedPulse:Stop()
    end
    -- the cast's target, in its class colour
    if db.castTarget and UnitSpellTargetName then
        local okN, target = pcall(UnitSpellTargetName, unit)
        cast.target:SetText(okN and target or "")
        local okC, class = pcall(UnitSpellTargetClass, unit)
        local okK, color = false, nil
        if okC then okK, color = pcall(C_ClassColor.GetClassColor, class) end
        if okK and color then cast.target:SetTextColor(color:GetRGB()) else cast.target:SetTextColor(1, 1, 1) end
        cast.target:Show()
    else
        cast.target:Hide()
    end
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

-- Objective Icon (tweaks.nameplateQuest, shared with Blizzard's plates) and Objective Progress
-- (nameplates.questProgress; never set, it follows the icon, as before the two were split)
-- Objective Icon and Progress, per type (11-20): the icon needs the shared quest switch (it also
-- serves Blizzard's plates) and the type's own Objective Icon; Progress never set follows the icon.
-- With no plate: whether any type shows them (the module's quest events).
local function TypeQuest(tdb, master)
    local icon = master and tdb.questIcon ~= false
    local progress = tdb.questProgress
    if progress == nil then progress = icon end
    return icon and true or false, progress and true or false
end
function NP.QuestParts(p)
    local t = ns.db and ns.db.profile and ns.db.profile.tweaks
    local master = (t and t.nameplateQuest) and true or false
    -- Questie draws its own quest icons on plates when its option is on
    if ns.Tweaks and ns.Tweaks.QuestieHasNameplateIcons and ns.Tweaks:QuestieHasNameplateIcons() then return false, false end
    if p then return TypeQuest(PDB(p), master) end
    local anyIcon, anyProgress = false, false
    for _, kind in ipairs(C.KINDS) do
        local i, pr = TypeQuest(NP.TypeDB(kind), master)
        anyIcon, anyProgress = anyIcon or i, anyProgress or pr
    end
    return anyIcon, anyProgress
end
-- SHOW PLATES IN COMBAT (11-20, Malkkav; Plate > Name Only Mode): the unit types picked there leave
-- Name Only Mode while you are in a fight and show their whole plate (nameplates.combatPlates, a list
-- of types, "none" first). Entering and leaving combat lays the plates out again (NP.Relayout).
function NP.CombatList()
    local db = DB()
    local v = db and db.combatPlates
    local set = {}
    -- ("none", the default, is no type: before 11-21 it counted as one, and every fight's start and end
    -- laid out all forty plates again, the 70 ms combat stutter)
    if type(v) == "string" then for t in v:gmatch("[^,]+") do if t ~= "none" then set[t] = true end end end
    return set
end
function NP.CombatFull(kind)
    return state.combat and kind ~= nil and NP.CombatList()[kind] or false
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

-- Combo Points per type (11-20): Tweaks.lua asks before it puts the points on your target's plate
function NP.ComboAllowed(unit)
    if not NP.ready or NP.standDown then return true end
    local want, kind = NP.WantsPlate(unit)
    if not want or not kind then return true end
    local tdb = NP.TypeDB(kind)
    -- a Name Only plate has no bar to hang them from (unless Show Plates in Combat gives it one)
    if tdb.plate == "name" and not NP.CombatFull(kind) then return false end
    return tdb.combo ~= false
end
function NP.QuestOn()
    local icon, progress = NP.QuestParts()
    return icon or progress
end

function NP.UpdateQuest(p)
    local icon, showProgress = NP.QuestParts(p)
    if not (icon or showProgress) then p.quest:Hide() p.questText:Hide() NP.PlaceSides(p) return end
    local progress = NP.QuestProgress(p.unit)
    if progress == false then return end   -- unreadable now: kept as it was
    p.quest:SetShown(icon and progress ~= nil)
    p.questText:SetText(progress or "")
    p.questText:SetShown(showProgress and progress ~= nil and progress ~= "")
    NP.PlaceSides(p)
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
function NP.UpdateFade(p)
    local db = PDB(p)
    if not (db and p.unit) then return end
    -- Targeting: your target's opacity, the others' while you have one, or every plate's with no
    -- target; the plate under the mouse and a casting one stay clear
    local alpha
    if p.targetShown then alpha = db.targetAlpha or 1
    elseif UnitExists("target") then alpha = db.nonTargetAlpha or 1
    else alpha = db.noTargetAlpha or 1 end
    if alpha < 1 and not p.targetShown and (state.mouseover == p or (p.cast and p.cast:IsShown())) then alpha = 1 end
    p.root:SetAlpha(alpha)
end

-- Out of Range Opacity: your class's spells by name (any rank); in range if any one is. A secret
-- answer goes to the holder's alpha unread.
function NP.UpdateRange(p)
    local db = PDB(p)
    local alpha = db and db.rangeAlpha or 1
    if alpha >= 1 or not p.unit then p.holder:SetAlpha(1) return end
    local _, class = UnitClass("player")
    local list = C.RANGE[class]
    if class == "DRUID" and C.MELEE_FORMS[GetShapeshiftFormID and GetShapeshiftFormID() or 0] then list = C.RANGE.DRUID_MELEE end
    if not list then p.holder:SetAlpha(1) return end
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
                p.holder:SetAlpha(1)
                return
            elseif r == false then
                out = true
            end
        end
    end
    if hasSecret and pcall(p.holder.SetAlphaFromBoolean, p.holder, secret, 1, alpha) then return end
    p.holder:SetAlpha(out and alpha or 1)
end

function NP.UpdateAll(p)
    if not p.unit then return end
    NP.UpdateHealth(p, false)
    NP.UpdateHeals(p)
    NP.UpdateColor(p)
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

local function OnUnitEvent(self, event)
    local p = self.plate
    if not p.unit then return end
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        NP.UpdateHealth(p, true)
        if event == "UNIT_MAXHEALTH" then NP.UpdateHeals(p) end
    elseif event == "UNIT_ABSORB_AMOUNT_CHANGED" or event == "UNIT_HEAL_ABSORB_AMOUNT_CHANGED" or event == "UNIT_HEAL_PREDICTION" then
        NP.UpdateHeals(p)
    elseif event == "UNIT_FACTION" then
        -- its type changed (turned friendly or hostile): claimed again as the new type, or back to Blizzard
        local want, kind = NP.WantsPlate(p.unit)
        if not want or kind ~= p.kind then
            local unit = p.unit
            NP.ReleasePlate(p)
            if want then NP.Claim(unit) end
            return
        end
        NP.UpdateColor(p)
    elseif event == "UNIT_THREAT_LIST_UPDATE" or event == "UNIT_FLAGS" then
        -- Name Only While Unattackable: it became attackable (or stopped being): laid out again
        if event == "UNIT_FLAGS" and not NP.testKind and NP.Peaceful(p.unit, p.kind) ~= (p.layKind == "peaceful") then
            local unit = p.unit
            NP.ReleasePlate(p)
            NP.Claim(unit)
            return
        end
        NP.UpdateColor(p)
    elseif event == "UNIT_NAME_UPDATE" then
        NP.UpdateName(p)
        NP.UpdateColor(p)
        NP.UpdateTitle(p)
    elseif event == "UNIT_LEVEL" or event == "UNIT_CLASSIFICATION_CHANGED" then
        NP.UpdateLevel(p)
    end
end

local function OnCastEvent(self, event, unit, castGUID, spellID, by, barID)
    local p = self.plate
    if not p.unit then return end
    if event:find("^UNIT_SPELLCAST") then
        NP.UpdateCast(p, event, by, barID)
    else
        OnUnitEvent(self, event, unit)
    end
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
            p.quieted[#p.quieted + 1] = { frame, event, unit1, unit2 }
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
    p.quieted = p.quieted or {}
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
    for _, event in ipairs(CAST_EVENTS) do ev:RegisterUnitEvent(event, unit) end
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
-- NAME ONLY WHILE UNATTACKABLE (11-20, Malkkav): an
-- enemy NPC you can't attack (an event mob, a quest giver of the other side) shows only its name, as
-- the Name Only preset, until you can attack it. Off by default (nameplates.peacefulNames).
function NP.Peaceful(unit, kind)
    local db = DB()
    if not (db and db.peacefulNames) or kind ~= "enemyNpc" then return false end
    if Readable(UnitIsPlayer(unit)) then return false end
    return Readable(UnitCanAttack("player", unit)) == false
end
-- ENEMY PLAYERS / ENEMY NPCS (11-20, the Plates' Enemy Types): the game has no switch for these two, so
-- FlareUI hides its own plate for them (as Plate: Hidden). Both on by default (nameplates.enemyPlayers,
-- nameplates.enemyNpcs).
function NP.UnitHidden(unit, kind)
    local db = DB()
    if not db then return false end
    if kind == "enemyPlayer" then return db.enemyPlayers == false end
    if kind == "enemyNpc" then return db.enemyNpcs == false end
    return false
end
-- whether FlareUI draws this unit's plate (its type's Plate isn't Blizzard), its type, and whether the
-- game couldn't say yet
function NP.WantsPlate(unit)
    -- objects (chairs, signs, mailboxes, herbs and ore with the interact key) and widget-only plates:
    -- Blizzard's own plate shows them without a bar, so they stay Blizzard's (11-21: they read as
    -- Enemy NPCs and got a full plate with level and health)
    if UnitIsGameObject and Readable(UnitIsGameObject(unit)) then return false, nil end
    if UnitNameplateShowsWidgetsOnly and Readable(UnitNameplateShowsWidgetsOnly(unit)) then return false, nil end
    local kind = NP.Kind(unit)
    if not kind then return false, nil, true end
    if kind == "friendlyPlayer" and Readable(UnitIsUnit(unit, "player")) then return false, kind end
    return NP.TypeDB(kind).plate ~= "blizzard", kind
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
    p = p or table.remove(spare)
    if not p then stats.given = stats.given + 1 return end
    p.kind, p.tdb = kind, NP.TypeDB(look)
    p.unitHidden = NP.UnitHidden(unit, kind)
    if p.layKind ~= look or p.layFull ~= full then
        local okL, errL = pcall(NP.Layout, p)
        if not okL then ns.LogError("Nameplates Layout", errL) end
    end
    local ok, err = pcall(function()
        p.gamePlate, p.unit = plate, unit
        byPlate[plate] = p
        p.holder:SetParent(plate)
        p.holder:ClearAllPoints()
        p.holder:SetAllPoints(plate)
        p.holder:SetAlpha(1)
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
        -- then shrinks the whole plate, ours with it (11-21: Minor names tiny even at 200%). Ours has
        -- its own sizes: off while we hold the plate, Blizzard's value back on release.
        if C_NamePlateManager and C_NamePlateManager.SetNamePlateSimplified then
            pcall(C_NamePlateManager.SetNamePlateSimplified, unit, false)
        end
        if p.auras then
            for _, entry in pairs(p.auras) do pcall(entry.container.SetUnit, entry.container, unit) end
        end
        RegisterUnit(p, unit)
        p.targetShown = nil
        p.root:SetScale(1)
        p.scaleNow, p.threatKey = 1, nil
        p.root:SetShown(not (p.hiddenPlate or p.unitHidden))
        NP.UpdateAll(p)
    end)
    if ok then
        stats.claimed = stats.claimed + 1
        if ns.Tweaks and ns.Tweaks.PlateChanged then pcall(ns.Tweaks.PlateChanged, unit) end
    else
        stats.failed = stats.failed + 1
        stats.lastError = err
        ns.LogError("Nameplates Claim", err)
        Release(p)
    end
end

function Release(p)
    if not p then return end
    if p.events then p.events:UnregisterAllEvents() end
    if p.auras then
        for _, entry in pairs(p.auras) do pcall(entry.container.SetUnit, entry.container, "none") end
    end
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
    -- (a unit still on screen: its quest tag and combo points go back to Blizzard's plate)
    if unit and ns.Tweaks and ns.Tweaks.PlateChanged then pcall(ns.Tweaks.PlateChanged, unit) end
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
        if before ~= state.role then for _, p in pairs(byPlate) do NP.UpdateColor(p) end end
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
    end
    for _, unit in ipairs(reclaim) do NP.Claim(unit) end
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        local unit = plate.unitToken
        if unit and not byPlate[plate] and canaccessvalue(unit) then NP.Claim(unit) end
    end
end

function NP.StandDown()
    if NP.standDown then return end
    NP.standDown = true
    local held = {}
    for _, p in pairs(byPlate) do held[#held + 1] = p end
    for _, p in ipairs(held) do Release(p) end
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

-- Our parts of a game plate, for Quality of Life's combo points and quest tags (Tweaks.lua)
function NP.PartsFor(plate)
    local p = plate and byPlate[plate]
    if p and p.unit then return p end
end

--------------------------------------------------
-- 8. TARGET, MOUSEOVER, GLOBAL EVENTS
--------------------------------------------------
local function UpdateTargets()
    local targetPlate = C_NamePlate.GetNamePlateForUnit("target")
    for _, p in pairs(byPlate) do
        NP.UpdateTarget(p, targetPlate)
        NP.ApplyScale(p)   -- (the others' size follows whether you have a target)
        NP.UpdateFade(p)
    end
end

-- Leaving a unit with the mouse fires no event: a small watcher runs only while a plate is lit
local watcher = CreateFrame("Frame")
watcher:Hide()
local function SetMouseover(p)
    local before = state.mouseover
    if before and before ~= p then before.highlight:Hide() end
    state.mouseover = p
    if p then p.highlight:Show() watcher:Show() else watcher:Hide() end
    if before and before ~= p then NP.UpdateFade(before) end
    if p then NP.UpdateFade(p) end
end
watcher:SetScript("OnUpdate", function()
    local p = state.mouseover
    if not p or not p.gamePlate or C_NamePlate.GetNamePlateForUnit("mouseover") ~= p.gamePlate then SetMouseover(nil) end
end)

local function RepaintAll()
    for _, p in pairs(byPlate) do NP.UpdateColor(p) end
end

function NP:OnEvent(event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        NP.Claim(unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        NP.ReleaseUnit(unit)
    elseif event == "PLAYER_TARGET_CHANGED" then
        UpdateTargets()
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        local plate = C_NamePlate.GetNamePlateForUnit("mouseover")
        SetMouseover(plate and byPlate[plate] or nil)
    elseif event == "RAID_TARGET_UPDATE" then
        for _, p in pairs(byPlate) do NP.UpdateRaid(p) end
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" then
        NP.UpdateGroup()
        NP.UpdateRole()
        RepaintAll()
    elseif event == "PLAYER_REGEN_DISABLED" then
        state.combat = true
        if next(NP.CombatList()) then NP.Relayout() end
    elseif event == "UPDATE_SHAPESHIFT_FORM" or event == "PLAYER_REGEN_ENABLED" then
        if event == "PLAYER_REGEN_ENABLED" then
            local was = state.combat
            state.combat = false
            if was and next(NP.CombatList()) then NP.Relayout() end
        end
        if event == "PLAYER_REGEN_ENABLED" and state.sizePending then NP.ApplySize() end
        local before = state.role
        NP.UpdateRole()
        if before ~= state.role or event == "PLAYER_REGEN_ENABLED" then RepaintAll() end
    elseif event == "PLAYER_ENTERING_WORLD" then
        NP.UpdateGroup()
        NP.UpdateRole()
        NP.Sync()
    elseif event == "QUEST_LOG_UPDATE" or event == "UNIT_QUEST_LOG_CHANGED" then
        -- (they come in bursts: one pass on the next frame)
        if state.questQueued or not NP.QuestOn() then return end
        state.questQueued = true
        C_Timer.After(0, function()
            state.questQueued = nil
            for _, p in pairs(byPlate) do NP.UpdateQuest(p) end
        end)
    elseif event == "PLAYER_FOCUS_CHANGED" then
        local db = DB()
        if db and db.colorFocus then RepaintAll() end
    elseif event == "SPELLS_CHANGED" then
        -- Execute Range on Auto follows the spells you know
        -- (each type has its own Execute Range now: Auto's spot is the same for all)
        local at = NP.ExecuteAt({ execute = "auto" })
        if at ~= state.execAt then
            state.execAt = at
            NP:Refresh()
        end
    end
end

-- Out of Range Opacity: a few plates per tick, in turn
function NP.RangeTick()
    local db = DB()
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
    if not DB() then return end
    local db = NP.TypeDB(f.kind)
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
    p.holder:Show()
    p.root:ClearAllPoints()
    -- (room above for the aura lines the preview draws)
    local function Lines(on, size, max)
        if not on then return 0 end
        local lines = math.ceil(NP.AuraCount(p, db, size, max) / NP.AuraPerLine(p, db, size))
        local look = AuraLook(size, on == "debuff")
        return lines * ((look and look.cellHeight or size) + C.AURA_GAP)
    end
    local top = 12 + math_max(Lines(db.debuffs ~= "off" and "debuff", db.debuffSize, db.debuffMax),
                              Lines(db.buffs ~= "off" and "buff", db.buffSize, db.buffMax))
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
    local hostile = NP.Color("hostile")
    local r, g, b = hostile[1], hostile[2], hostile[3]
    -- threat: the warning state for your role (damage / healer: it's on you; tank: you lost it), so
    -- Threat Glow, Aggro Flash and Threat Scale show with it
    -- (shown whenever the preview asks for it: Colour by Threat may still be off while you look at its options)
    local threatKey = st.threat and (state.role == "tank" and "lost" or "aggro") or nil
    if threatKey then
        local c = NP.Color(threatKey)
        r, g, b = c[1], c[2], c[3]
    elseif st.focus and db.colorFocus then
        local c = NP.Color("focus")
        r, g, b = c[1], c[2], c[3]
    elseif db.colorElite then
        local c = NP.Color("elite")   -- (the sample is an elite)
        r, g, b = c[1], c[2], c[3]
    elseif db.healthColor == "health" and UF and UF.SampleHealthColor then
        r, g, b = UF.SampleHealthColor({ healthColor = "health" }, share, r, g, b)
    end
    if C.FRIENDLY[db.kind] then local c = NP.Color("friendly") r, g, b = c[1], c[2], c[3] end
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
        p.name:SetText(UnitName("player"))
        if cc then p.name:SetTextColor(cc:GetRGB()) end
    end
    local questOn = NP.QuestOn() and (st.quest or type(kind) ~= "table")
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
            local c = NP.Color(nokick and "castNoInterrupt" or (st.kick and db.kickReady and "kickReady") or "cast")
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
    local comboOn = ns.db and ns.db.profile and ns.db.profile.tweaks and ns.db.profile.tweaks.nameplateCombo
        and db.combo ~= false and not p.nameOnly
        and (st.combo or type(kind) ~= "table")
    p.sampleCombo = p.sampleCombo or {}
    local gemSize = 14
    local step = ns.ComboPointStep and ns.ComboPointStep(gemSize) or gemSize + 2
    for i = 1, 5 do
        local gem = p.sampleCombo[i]
        if comboOn and not gem and ns.CreateComboPoint then
            gem = ns.CreateComboPoint(p.overlay, i, gemSize)
            p.sampleCombo[i] = gem
        end
        if gem then
            gem:ClearAllPoints()
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
        local look = AuraLook(size, isDebuff)
        if look and ns.AuraLook and ns.AuraLook.Style then
            look.preview = true
            ns.AuraLook.Style(b, look)
            local c = look.colors and (look.colors[dispelType] or look.colors.None)
            if c then b.FlareUI_Border:SetVertexColor(c:GetRGBA()) end
            b.FlareUI_Count:SetText("")
            b.FlareUI_Duration:SetText("")
            b.FlareUI_Cooldown:Clear()
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
        local look = AuraLook(size, isDebuff)
        local cell = (look and look.cellHeight or size) + C.AURA_GAP
        local x, y = (i - 1) % per * (size + C.AURA_GAP), C.AURA_GAP + math_floor((i - 1) / per) * cell
        local row = NP.AuraRowSide(db, isDebuff and "debuffs" or "buffs")
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
    local db = DB()
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
    local db = DB()
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
    local tweaks = ns.db and ns.db.profile and ns.db.profile.tweaks
    local comboOn = tweaks and tweaks.nameplateCombo and ns.CreateComboPoint and PDB(p).combo ~= false and not p.nameOnly
    -- (made out of combat only: frames made on a nameplate in a fight come out forbidden)
    if comboOn and not p.testCombo and not InCombatLockdown() then
        p.testCombo = {}
        for i = 1, 5 do p.testCombo[i] = ns.CreateComboPoint(p.overlay, i, 14) end
    end
    if not p.testIcons then
        -- once per test: placed, and set to 3 of 5
        p.testIcons = true
        if questOn then NP.PlaceSides(p) end
        local step = ns.ComboPointStep and ns.ComboPointStep(14) or 16
        for i, gem in ipairs(p.testCombo or {}) do
            gem:ClearAllPoints()
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
    local db = NP.TypeDB("enemyNpc")
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
function NP:Refresh()
    if not NP.ready then return end
    local held = {}
    for _, p in pairs(byPlate) do held[#held + 1] = p end
    for _, p in ipairs(held) do Release(p) end
    for _, p in ipairs(pool) do
        local ok, err = pcall(NP.Layout, p)
        if not ok then ns.LogError("Nameplates Layout", err) end
    end
    NP.ApplySize()
    NP.PinZoom()   -- (the game settings FlareUI sets: out of a fight only)
    NP.Sync()
end

-- The game's own plate zoom (distance, target, larger plates) is set to 1 while the module is on, so
-- Target Scale is the only zoom. Each setting is backed up first and put back when the module is off
-- (at the next login: ShouldLoad runs either way) or stands down.
C.ZOOM_CVARS = { "nameplateSelectedScale", "nameplateMinScale", "nameplateMaxScale", "nameplateLargerScale" }
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
    local db = DB() or {}
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

function NP:ShouldLoad()
    local db = DB()
    -- 11-19: text slots saved by the first version kept the Left slot empty; they start over once
    if db and db.barText and not db.textV2 then db.barText = nil end
    if db then db.textV2 = true end
    -- 11-19: Friendly Plates (Blizzard / FlareUI) became the Friendly type's Plate
    if db and rawget(db, "friendly") == "flareui" then NP.TypeStore("friendly").plate = "bar" end
    if db then db.friendly = nil end
    -- 11-20: Enemy and Friendly split again into players and NPCs (each side keeps the one setup it
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
    NP.MigratePresets()
    -- 11-19: the Chevron and Hook arrows went (Chevron was the Yellow one turned)
    if db and (db.targetArrows == "chevron" or db.targetArrows == "hook") then db.targetArrows = "npe" end
    if not (db and db.enabled) then NP.RestoreZoom() return false end
    if not (K and BT and K.CreateCastBar) then return false end
    if NP.OtherAddon() then NP.standDown = true NP.RestoreZoom() return false end
    return true
end

-- the pool, all at once: aura containers made after login never show
local function BuildPool()
    for _ = 1, C.POOL do
        local p = NP.Build(hidden, false)
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
    -- the aura containers must be made now (later ones never show): all forty plates' at once
    if K.HasAuraSupport then K.HasAuraSupport() end
    BuildPool()
    NP.ready = true
    -- Musician: out of a fight it swaps a friendly player's plate for its own name frame, which
    -- showed next to ours (11-21, two names). Its API for nameplate addons turns that off, as its
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
            if (tdb.kickReady or tdb.castKickMark) and p.cast and p.cast:IsShown() and not p.cast.flashing then NP.UpdateCast(p) end
        end
    end
    NP.Sync()
end
