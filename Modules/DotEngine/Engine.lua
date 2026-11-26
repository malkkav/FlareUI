-- Part of FlareUI's DoT tracker. Taken from Does It Die Advanced 1.3.7 by WhiteKnight / Smuggz_, itself based on
-- Does It Die by JoeGG (MIT License, Copyright (c) 2026 Joe Greive: LICENSES/DoesItDieAdvanced.txt), and changed for
-- FlareUI: its own namespace; FlareUI starts it (ns.start, at the end) in place of its ADDON_LOADED, options
-- window, slash commands and version check; drawing is FlareUI's (Modules/UnitFramesDoesItDie.lua, NameplateDots.lua).
-- DoesItDie
-- Tracks your DoTs on the target and shows the damage they still have to deal as a marker on its health
-- bar (if the health ends inside the marker, the DoTs will kill it), plus a skull on the portrait when
-- they're lethal. Look and animation are configurable in the options panel (/did).
--
-- In WoW: Forever, target health, player stats and auras are secret in combat, so addon code can
-- never compare "health vs DoT damage" itself. What stays readable:
--   * our own casts (UNIT_SPELLCAST_SUCCEEDED) and spell descriptions -> which DoT, base damage, duration
--   * UNIT_COMBAT damage amounts on units -> actual tick sizes (already include resists/reductions)
-- StatusBars accept secret values, so the "damage >= health" comparison is done by the widget, not
-- by Lua: see the skull notes in the Display section.

local _, flare = ...
local ns = flare.DotEngine -- the tracker's own namespace (Namespace.lua), apart from FlareUI's

-- Which client this is. WoW: Forever (interface 16xxx) runs the modern client with Midnight's addon restrictions:
-- the combat log is forbidden (registering it shows a "blocked" popup) and target health, spell power, combo points
-- and auras are secret. There the original Forever tracking (UNIT_COMBAT) is used; TBC and Classic Era add the combat log.
do
    local okB, version, _, _, interface = pcall(GetBuildInfo)
    interface = okB and tonumber(interface) or 0
    local minor = okB and type(version) == "string" and tonumber(version:match("^1%.(%d+)")) or nil
    -- Forever's client is version 1.60 and up (Classic Era is 1.15); its interface number is in the 16000s on the
    -- beta. Either is enough.
    ns.isForever = (minor ~= nil and minor >= 16) or (interface >= 16000 and interface < 20000)
end

local UPDATE_INTERVAL = 0.1

-- /dida cpu: how much time each part of the addon takes (for "my game stutters" reports). Always on; cheap.
ns.cpu = {}
local profileClock = debugprofilestop
function ns.timed(name, fn, ...)
    if not profileClock then return fn(...) end
    local started = profileClock()
    local a, b, c, d = fn(...)
    local spent = profileClock() - started
    local entry = ns.cpu[name]
    if not entry then entry = { total = 0, calls = 0, worst = 0 }; ns.cpu[name] = entry end
    entry.total, entry.calls = entry.total + spent, entry.calls + 1
    if spent > entry.worst then entry.worst = spent end
    return a, b, c, d
end
local DEFAULT_TICK_INTERVAL = 3
-- Seconds either side of an expected tick time. Observed on Forever: the first tick lands within ~0.1s of one
-- interval after the cast, and later ticks within ~0.1s of the first tick's rhythm. Tight windows keep melee
-- auto-attacks (same Physical school as bleeds, similar size, ~1s rhythm) from passing as ticks.
local TICK_MATCH_WINDOW = 0.45
local TICK_MATCH_WINDOW_ANCHORED = 0.25
local MISSED_TICKS_BEFORE_DROP = 2  -- a DoT that never ticks was resisted/immune
-- Projectile DoTs start when the projectile lands, not on the cast event: Serpent Sting's first tick came
-- 3.6-3.9s after the cast instead of 3s (log 253548.7, 12 casts). Their first tick may be this much later.
local PROJECTILE_TRAVEL = 1.5
local PROJECTILE_DOTS = {
    ["Serpent Sting"] = true, ["Fireball"] = true, ["Pyroblast"] = true, ["Frostfire Bolt"] = true,
}
-- Once a DoT's tick size is known, same-school hits further off than this are someone else's (the Imp's
-- Firebolt next to Immolate, white hits next to Rip). Ticks within one cast barely vary (15,15,15,16);
-- the minimum slack of 1 covers rounding (3 vs 4).
local TICK_AMOUNT_TOLERANCE = 0.25
-- Check for the first tick against a size learned on an earlier cast (gear/AP may have changed a little).
local FIRST_TICK_AMOUNT_TOLERANCE = 0.3
-- A crit tick is 1.5-2x a normal one; anything else flagged as a crit (white-hit crits) isn't this DoT.
local CRIT_MIN_RATIO, CRIT_MAX_RATIO = 1.3, 2.3
local DB_VERSION = 5                -- bump to discard learned data from older, buggier versions

-- Tick intervals that differ from the 3s default and aren't stated in the description.
local KNOWN_TICK_INTERVALS = {
    ["Insect Swarm"] = 2,
    ["Curse of Agony"] = 2,
    ["Bane of Agony"] = 2, -- Forever's name for Curse of Agony
    ["Fireball"] = 2,
    ["Holy Fire"] = 2,
    ["Rip"] = 2,
    ["Rupture"] = 2,
}

-- DoTs whose ticks aren't even: each tick is the average tick times its factor (factors average 1, so the
-- tooltip total still holds). Agony is back-loaded; seen in-game on Forever (log 166015.8, 72 over 24s):
-- ticks 3,3,3,3 then 6,6,... then 9s. Everything else ticks evenly.
local TICK_SHAPES = {}
do
    local agony = { 0.5, 0.5, 0.5, 0.5, 1, 1, 1, 1, 1.5, 1.5, 1.5, 1.5 }
    TICK_SHAPES["Bane of Agony"] = agony -- Forever's name
    TICK_SHAPES["Curse of Agony"] = agony
end

-- Descriptions that don't name their school.
local SCHOOL_BY_NAME = {
    ["Siphon Life"] = 32,
    ["Unstable Affliction"] = 32, -- TBC: "causing 1050 damage over 18 sec"
    ["Drain Life"] = 32,          -- "Transfers 108 health every 1 sec"
}

-- Read like DoTs but aren't one on the current target: ground/area effects, channels, traps, and
-- delayed damage (Wyvern Sting only starts after the sleep).
local IGNORED_SPELLS = {
    ["Rain of Fire"] = true, ["Hellfire"] = true, ["Blizzard"] = true, ["Flamestrike"] = true,
    ["Consecration"] = true, ["Hurricane"] = true, ["Volley"] = true,
    ["Drain Life"] = true, ["Drain Soul"] = true, ["Drain Mana"] = true, ["Health Funnel"] = true,
    ["Mind Flay"] = true, ["Arcane Missiles"] = true, ["Starshards"] = true,
    ["Explosive Trap"] = true, ["Wyvern Sting"] = true,
}
-- Starshards is a channel in Classic Era but an instant DoT from TBC on ("785 Arcane damage over 15 sec"): only
-- ignored on Classic Era.
do
    local okB, _, _, _, interface = pcall(GetBuildInfo)
    if okB and type(interface) == "number" and interface >= 20000 then IGNORED_SPELLS["Starshards"] = nil end
end

-- Traps that put a DoT on the first enemy to walk in. Placing one only arms it (the trap, not the player, casts
-- the DoT when it springs, so no cast event says when or on whom); the DoT starts on the mob that takes the
-- first plausible unmatched tick of its school while it's armed. See springTrap.
local TRAP_DOTS = { ["Immolation Trap"] = true }

-- The name-keyed tables also answer to the names of every registered language, and on ADDON_LOADED to the names
-- this client reports for them (Locale.lua).
-- Channels whose damage is predicted while you channel them (see the channel section). They stay in IGNORED_SPELLS
-- for the cast path: a channel isn't a DoT that outlives its cast, so only the channel events create and end it.
local CHANNEL_DOTS = { ["Drain Life"] = true, ["Drain Soul"] = true, ["Mind Flay"] = true }
KNOWN_TICK_INTERVALS["Mind Flay"] = 1

local NAME_TABLES = { KNOWN_TICK_INTERVALS, TICK_SHAPES, SCHOOL_BY_NAME, IGNORED_SPELLS, PROJECTILE_DOTS, TRAP_DOTS,
    CHANNEL_DOTS }
ns.locale.addNames(NAME_TABLES)

local SCHOOL_MASKS = {
    Physical = 1, Holy = 2, Fire = 4, Nature = 8, Frost = 16, Shadow = 32, Arcane = 64,
    Frostfire = 4 + 16, -- Forever's Frostfire Bolt: combined schools report as the OR of their masks
}

-- User options (edited in the options panel, saved in DoesItDieDB).
local DEFAULTS = {
    -- Skull
    showSkull = true,
    skullIcon = "cross",
    skullSize = 64,
    skullPulse = true,
    skullOffsetX = 0,
    skullOffsetY = 0,
    -- Damage marker
    showMarkers = true,
    fillTexture = "stripes",
    fillColor = "red",
    fillOpacity = 100,
    dotColors = "each",
    segmentDividers = true,
    outlineStyle = "dashed",
    dashLength = 4,
    outlineThickness = 1,
    outlineColor = "red",
    outlineOpacity = 85,
    -- Animation
    smoothMotion = true,
    flashOnApply = true,
    pulseOutline = true,
    -- Effects
    showSpark = true,
    showGlow = true,
    glowSize = 7,
    showShine = true,
    shineInterval = 3,
    scrollStripes = true,
    -- Damage text
    showLabel = false,
    labelPosition = "center",
    labelSize = 10,
    labelColor = "white",
    -- Misc
    debug = false,
    -- Custom frames (Frames.lua): another addon's target health bar / kill icon spot, as frame paths. Empty =
    -- a known replacement target frame (EllesmereUI's) if there is one, else Blizzard's.
    customHealthBar = "",
    customIconAnchor = "",
    -- Focus frame (Focus.lua): the marker on it too, on a custom bar or the one found, in its own look (Focus tab)
    focusMode = "markerIcon",
    customFocusHealthBar = "",
    customPlateHealthBar = "", -- (Nameplates.lua) keys from Blizzard's nameplate to a plate addon's bar
    focusIcon = "skull",
    focusIconSize = 18,
    focusIconPosition = "left", -- the portrait is on the right of Blizzard's focus frame
    focusIconOffsetX = 0,
    focusIconOffsetY = 0,
    focusDotColors = "each",
    focusFillTexture = "stripes",
    focusFillColor = "white",
    focusFillOpacity = 40,
    focusOutlineStyle = "dashed",
    focusDashLength = 4,
    focusOutlineThickness = 1,
    focusOutlineColor = "gold",
    focusOutlineOpacity = 75,
    -- Accuracy
    waitFirstTick = "off",
    estimateDuringCast = true,
    markerUnderText = true,
    -- Health text of other unit frame addons too, found by where it sits (Blizzard's own is always copied).
    markerUnderTextAddons = true,
    showOnPlayers = true,   -- TBC port: marker and kill icon on enemy players too (their health is measured) -- TBC port: the marker sits under the target frame's health text, not over it
    trackChannels = true, -- Drain Life, Drain Soul, Mind Flay while channelling (TBC port; /did channels)
    uiLanguage = "auto", -- the options window's language (Locale.lua): "auto" or a language tag
    -- Nameplates (Nameplates.lua): their own look, since enemy plates are red. Defaults read well on red.
    nameplateMode = "markerIcon",
    nameplateIconSize = 18,
    nameplateIconPosition = "left", -- the level badge sits right of the bar on Forever's plates
    plateIconOffsetX = 0,
    plateIconOffsetY = 15,          -- clear of the level number, which draws over the icon
    -- Target frame marker fit (Marker tab), for frame styles that draw a thinner or offset bar inside the bar frame.
    -- Default: the whole bar, which fits Blizzard's default frames. (v1.0.0 started Forever at 10 / -4 / 5, fitted to
    -- one player's frame; on another's default UI that put the marker below the bar.)
    markerHeight = 0,               -- pixels tall, centred on the bar; 0 = the bar frame's full height
    markerOffsetY = 0,              -- moved up (+) or down (-), in pixels
    markerInsetLeft = 0,            -- left end pulled in, in pixels
    markerInsetRight = 0,           -- right end pulled in, in pixels
    markerDirection = "auto",       -- marker from the left or right end; auto follows the bar's reverse fill
    updateNotice = true,            -- tell me when a newer version is out (heard from guild and group members)
    enemyFrames = true,             -- the marker and kill icon on Enemy Frames' list too (Krelock's addon, Forever)
    plateMarkerHeight = 0,          -- plate marker height in pixels, centred; 0 = the bar frame's full height
    plateIcon = "skull",
    plateDotColors = "each",
    plateFillTexture = "stripes",
    plateFillColor = "white",
    plateFillOpacity = 40,
    plateOutlineStyle = "dashed",
    plateDashLength = 4,
    plateOutlineThickness = 1,
    plateOutlineColor = "gold",
    plateOutlineOpacity = 75,
}

-- "Wait for first tick": whether a DoT counts toward the marker before its first tick has landed.
-- "unsure" = only when the starting estimate is shaky (finisher with unknown combo points, or no tick size
-- learned yet for that spell).
local WAIT_MODES = {
    { id = "off",    label = "Never (estimate straight away)" },
    { id = "unsure", label = "When unsure" },
    { id = "always", label = "Always (real ticks only)" },
}

local MAX_TRACE_LINES = 500

local db
local dotsByTarget = {}     -- targetKey -> { [spellName] = dot }
-- TBC: the combat log is allowed there (Forever forbids it). While it's registered, ticks, misses, aura
-- applications/removals and deaths come from it, exactly, and the UNIT_COMBAT guesswork is switched off.
local combatLog = { active = false }
local warnedSecretGuid = false

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffb39ddbFlareUI|r " .. msg)
end

-- Always recorded to SavedVariables (db.log) for diagnosing accuracy; echoed to chat with /did debug.
local function trace(msg)
    if not (db and db.log) then return end   -- (FlareUI: no log before ns.start or after ns.stop)
    table.insert(db.log, string.format("%.1f %s", GetTime(), msg))
    if #db.log > MAX_TRACE_LINES then table.remove(db.log, 1) end
    if db.debug then print("|cff888888" .. msg .. "|r") end
end

local function isSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, r = pcall(issecretvalue, v)
    return ok and r or false
end

-- The nameplate token ("nameplate3") of the mob behind `unit`, or nil (no plate, plates off, or unreadable).
-- Reported for Forever's instances (PR #8, Staypuft; unverified here): creature GUIDs are secret there, but a
-- mob keeps its nameplate token from NAME_PLATE_UNIT_ADDED to NAME_PLATE_UNIT_REMOVED, and
-- C_NamePlate.GetNamePlateForUnit("target") still finds the target's plate. So the token stands in for the GUID
-- while the plate is up; the nameplate events drop its DoTs before the token goes to another mob.
local function plateTokenFor(unit)
    if type(unit) == "string" and unit:match("^nameplate%d+$") then return unit end
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or not plate or isSecret(plate) or type(plate) ~= "table" then return nil end
    local token = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
    if type(token) ~= "string" or isSecret(token) or not token:match("^nameplate%d+$") then return nil end
    return token
end

-- Stable key for the mob behind a unit token, or nil if the unit can't be tracked: its GUID when readable (open
-- world); "plate:nameplateN" when the GUID is secret (instances) and the mob has a nameplate; "target" as the last
-- resort (secret GUID, no plate: only the current target is tracked, and target changes drop its DoTs).
-- The same hit arrives for target, nameplateN and focus, and their GUIDs may not all be readable, so a hidden GUID
-- only affects that one unit token.
local function unitKey(unit)
    local ok, guid = pcall(UnitGUID, unit)
    if ok and not isSecret(guid) then return guid end
    local token = plateTokenFor(unit)
    if token then
        if warnedSecretGuid ~= "plate" then
            warnedSecretGuid = "plate"
            trace("Mob GUIDs are secret here (instance?); tracking each mob by its nameplate instead")
        end
        return "plate:" .. token
    end
    if unit ~= "target" then return nil end
    if warnedSecretGuid ~= "target" then
        warnedSecretGuid = "target"
        trace("Target GUID is secret and it has no nameplate; tracking DoTs on the current target only"
            .. " (turn on enemy nameplates to track several mobs)")
    end
    return "target"
end

local function spellNameAndDescription(spellID)
    local name, desc
    if C_Spell and C_Spell.GetSpellName then
        name = C_Spell.GetSpellName(spellID)
    else
        name = GetSpellInfo(spellID)
    end
    local descFn = (C_Spell and C_Spell.GetSpellDescription) or GetSpellDescription
    if descFn then desc = descFn(spellID) end
    return name, desc
end

local function schoolFromWords(words)
    local school = SCHOOL_MASKS.Physical
    for word in words:gmatch("%a+") do
        if SCHOOL_MASKS[word] then school = SCHOOL_MASKS[word] end
    end
    return school
end

-- Finishers (Rip, Rupture) list their DoT per combo point:
--   "1 point : 243 damage over 12 sec. 2 points: 396 damage over 12 sec. ..."   (Rip; note the stray space)
--   "1 point: 25 damage over 8 secs\n ... 5 points: 87 damage over 16 secs"      (Rupture)
-- Returns total, school, duration for the given points (clamped to the listed range), or nil if the
-- finisher has no per-point DoT (e.g. Eviscerate).
local function parseFinisher(desc, comboPoints)
    local byPoints, highest = {}, 0
    -- Forever's Rip leaves out "damage": "1 point  : 8 over 1 sec" (any words, or none, between amount and "over").
    for pointsText, amount, secs in desc:gmatch("(%d+) points?%s*:%s*(%d+)%s*[%a ]-over (%d+%.?%d*) sec") do
        local points = tonumber(pointsText)
        byPoints[points] = { total = tonumber(amount), duration = tonumber(secs) }
        highest = math.max(highest, points)
    end
    if highest == 0 then return nil end
    local entry = byPoints[math.max(1, math.min(comboPoints, highest))] or byPoints[highest]
    return entry.total, SCHOOL_MASKS.Physical, entry.duration
end

-- Returns total damage, school mask, duration and (if the description states it) tick interval.
--   "... 10 Nature damage over 15 sec."  Takes the last such clause, so Immolate's
--       "11 Fire damage and then an additional 20 Fire damage over 15 sec" yields the periodic part.
--   "Transfers 15 health from the target to the caster every 3 sec. Lasts 30 sec."  (Siphon Life)
-- comboPoints is only used for finishers. (Rake/Garrote merely award a combo point, so finishers are
-- recognised by "Finishing move", not "combo point".)
-- Thousands separators out of tooltip numbers: "1,067 Shadow damage" was read as 67 (seen: Forever's Bane of Agony
-- rank 5, "tooltip 5.6 a tick" instead of 88.9). Commas, dots ("1.067", German) and spaces ("1 067", French) between
-- a digit and exactly three more digits.
local function joinThousands(desc)
    local previous
    repeat
        previous = desc
        desc = desc:gsub("(%d)[,%.](%d%d%d)%f[^%d]", "%1%2")
        desc = desc:gsub("(%d)\194\160(%d%d%d)%f[^%d]", "%1%2")     -- no-break space
        desc = desc:gsub("(%d)\226\128\175(%d%d%d)%f[^%d]", "%1%2") -- narrow no-break space
    until desc == previous
    return desc
end
ns.joinThousands = joinThousands

local function parseDot(desc, comboPoints)
    if type(desc) ~= "string" or isSecret(desc) then return nil end
    desc = joinThousands(desc)
    if desc:find("Finishing move") then return parseFinisher(desc, comboPoints or 5) end
    -- Weapon enchants (rogue poisons) describe a proc DoT but aren't cast on the target. Match the enchant
    -- wording only: Lacerate's tooltip also mentions "weapon damage".
    if desc:find("[Cc]oats a weapon") then return nil end
    -- Heals over time: Forever's Renew reads "Heals the target of 830 damage over 15 sec".
    if desc:find("^Heals") then return nil end
    -- Classic Era: some vanilla tooltips say "every second" where TBC says "every 1 sec".
    desc = desc:gsub("every second", "every 1 sec")

    -- Brackets are only dropped for the English reader: other languages need them ("40 Punkt(e) Schattenschaden").
    local original, english = desc, desc
    -- TBC Rend at low level: "bleed for 28 damage plus an additional 1 (based on weapon damage) over 12 sec." The
    -- weapon bonus is counted with the base, and the bracket dropped so "damage over" reads as usual.
    do
        local base, extra = desc:match("(%d+) damage plus an additional (%d+)")
        local clean = desc:gsub("%s*%b()", "")
        if base and extra then
            local secs = clean:match("plus an additional %d+%s*over (%d+%.?%d*) sec")
            if secs and tonumber(secs) > 0 then
                return tonumber(base) + tonumber(extra), SCHOOL_MASKS.Physical, tonumber(secs)
            end
        end
        english = clean
    end
    desc = english
    local total, school, duration
    for amount, words, secs in desc:gmatch("(%d+)%s*([%a ]-)%s*damage over (%d+%.?%d*) sec") do
        total, school, duration = tonumber(amount), schoolFromWords(words), tonumber(secs)
    end
    if total and duration > 0 then return total, school, duration end

    local amount, words, every = desc:match("(%d+)%s*([%a ]-)%s*damage every (%d+%.?%d*) sec")
    if not amount then
        amount, every = desc:match("(%d+) health.-every (%d+%.?%d*) sec")
        words = ""
    end
    local lasts = desc:match("[Ll]asts (%d+%.?%d*) sec")
    if amount and every and lasts then
        every, lasts = tonumber(every), tonumber(lasts)
        if every > 0 and lasts > 0 then
            return tonumber(amount) * math.floor(lasts / every + 0.5), schoolFromWords(words), lasts, every
        end
    end
    -- Not English DoT wording: try the registered languages (Locale.lua).
    return ns.locale.parseDot(original, comboPoints or 5)
end

---------------------------------------------------------------------------
-- DoT tracking
---------------------------------------------------------------------------

-- Curses that raise a school's damage taken (Curse of the Elements, Curse of Shadow). DoT ticks are worked out per
-- tick, so a curse that lands after the DoTs makes their remaining ticks bigger. Estimates are kept curse-free (ticks
-- are divided by the curse that was up when they landed) and the curse on the mob now is multiplied back in.
-- Schools are bits: fire 4, frost 16, shadow 32, arcane 64.
local CURSE_EFFECTS
do
    local okB, _, _, _, interface = pcall(GetBuildInfo)
    local tbc = okB and type(interface) == "number" and interface >= 20000 and interface < 30000
    if tbc then
        -- TBC: Curse of the Elements took over Curse of Shadow's schools.
        local all = 4 + 16 + 32 + 64
        CURSE_EFFECTS = { [1490] = { 0.06, all }, [11721] = { 0.08, all }, [11722] = { 0.10, all },
            [27228] = { 0.10, all } }
    else
        CURSE_EFFECTS = { [1490] = { 0.06, 4 + 16 }, [11721] = { 0.08, 4 + 16 }, [11722] = { 0.10, 4 + 16 },
            [17862] = { 0.08, 32 + 64 }, [17937] = { 0.10, 32 + 64 } }
    end
end
local CURSE_SECONDS = 300
local CURSE_SCAN_SECONDS = 0.25
-- Per mob (unitKey): seen = curses read from its debuffs (when the game shows them) and when; cast = the player's own
-- curse cast on it (Forever hides auras: then this is all there is). A warlock has one curse per mob, so a new
-- curse cast replaces the old one.
local cursesByKey = {}
local cursesKeptAt = 0

-- A curse's effect from its tooltip, so every rank on every client is right (Forever's Curse of the Elements has 4
-- ranks, 4-10%, on all Magic damage): "increasing Magic damage taken by 4%", "increasing Fire and Frost damage taken
-- by 10%". Other languages, or no tooltip: the table above.
local CURSE_SCHOOL_WORDS = { Magic = 2 + 4 + 8 + 16 + 32 + 64, Holy = 2, Fire = 4, Nature = 8, Frost = 16, Shadow = 32,
    Arcane = 64 }
local curseEffectCache = {}
local function curseEffect(spellID, name)
    if type(spellID) ~= "number" or isSecret(spellID) then return nil end
    local cached = curseEffectCache[spellID]
    if cached ~= nil then return cached or nil end
    local effect = CURSE_EFFECTS[spellID]
    local ok, spellName, desc = pcall(spellNameAndDescription, spellID)
    if ok and type(desc) == "string" and not isSecret(desc) then
        local schools, pct = desc:match("[Ii]ncreas%a* (.-) damage taken by (%d+)%%")
        if schools and pct then
            local mask = 0
            for word, bit in pairs(CURSE_SCHOOL_WORDS) do
                if schools:find(word) then mask = mask + (word == "Magic" and 0 or bit) end
            end
            if schools:find("Magic") then mask = CURSE_SCHOOL_WORDS.Magic end
            if mask > 0 then effect = { tonumber(pct) / 100, mask } end
        end
    elseif not ok or desc == nil or desc == "" then
        return effect -- tooltip not loaded yet: don't cache, try again next time
    end
    curseEffectCache[spellID] = effect or false
    return effect
end

local function debuffSpellID(unit, i)
    if UnitDebuff then
        local ok, name, _, _, _, _, _, _, _, _, id = pcall(UnitDebuff, unit, i)
        if ok then
            if name == nil then return nil, true end
            return id, false
        end
    end
    if C_UnitAuras and C_UnitAuras.GetDebuffDataByIndex then
        local ok, data = pcall(C_UnitAuras.GetDebuffDataByIndex, unit, i)
        if ok then
            if data == nil then return nil, true end
            if type(data) == "table" then return data.spellId, false end
        end
    end
    return nil, true
end

local function scanCurses(unit, key)
    if not unit or not key then return end
    if not UnitDebuff and not (C_UnitAuras and C_UnitAuras.GetDebuffDataByIndex) then return end
    local now = GetTime()
    local entry = cursesByKey[key]
    if entry and entry.seenAt and now - entry.seenAt < CURSE_SCAN_SECONDS then return end
    local seen, readable = {}, true
    for i = 1, 40 do
        local id, done = debuffSpellID(unit, i)
        if done then break end
        if isSecret(id) then readable = false break end
        local effect = id and curseEffect(id)
        if effect then table.insert(seen, effect) end
    end
    if not readable then return end
    entry = entry or {}
    entry.seen, entry.seenAt = seen, now
    cursesByKey[key] = entry
end

local function onCurseCast(key, spellID, name)
    if not key then return end
    local effect = curseEffect(spellID)
    local isCurse = effect or (type(name) == "string" and name:find("^Curse of "))
    if not isCurse then return end
    local entry = cursesByKey[key] or {}
    entry.cast = effect and { effect = effect, at = GetTime(), expiresAt = GetTime() + CURSE_SECONDS } or nil
    cursesByKey[key] = entry
end

local function sharesSchool(a, b)
    if bit and bit.band then return bit.band(a, b) ~= 0 end
    for i = 0, 6 do
        local flag = 2 ^ i
        if a % (flag * 2) >= flag and b % (flag * 2) >= flag then return true end
    end
    return false
end

-- The damage taken multiplier for `school` on the mob now (1 = no curse).
local function curseMultiplier(key, school)
    local entry = key and cursesByKey[key]
    if not entry or type(school) ~= "number" then return 1 end
    local now, best = GetTime(), 0
    -- What the mob's debuffs show wins (a resisted or replaced curse). On Forever enemy auras may be hidden without
    -- saying so, so the player's own cast still counts there.
    local list = {}
    local fresh = entry.seenAt and now - entry.seenAt < 5
    if fresh then for _, effect in ipairs(entry.seen) do table.insert(list, effect) end end
    local cast = entry.cast
    if cast and cast.expiresAt > now and (ns.isForever or not fresh or cast.at > entry.seenAt) then
        table.insert(list, cast.effect)
    end
    for _, effect in ipairs(list) do
        if sharesSchool(effect[2], school) and effect[1] > best then best = effect[1] end
    end
    if now - cursesKeptAt > 60 then -- forget long-gone mobs now and then
        cursesKeptAt = now
        for k, e in pairs(cursesByKey) do
            if (not e.seenAt or now - e.seenAt > CURSE_SECONDS) and (not e.cast or e.cast.expiresAt < now) then
                cursesByKey[k] = nil
            end
        end
    end
    return 1 + best
end
ns.curseMultiplier = curseMultiplier

-- Best known average damage per tick: observed average of non-crit ticks, else learned from earlier casts,
-- else the description. Crits are one-offs, so they never raise the expectation for later ticks. For shaped
-- DoTs (TICK_SHAPES) ticks are stored divided by their factor, so this is the average tick, not the latest.
local function expectedTick(dot)
    if dot.normalTicks > 0 then return dot.tickSum / dot.normalTicks end
    return dot.learnedAtApply or (dot.tickKey and db.ticks[dot.tickKey]) or (dot.total / dot.totalTicks)
end

-- Which tick of the DoT (1 = first) lands around `when`.
local function tickNumberAt(dot, when)
    return math.max(1, math.floor((when - dot.appliedAt) / dot.interval + 0.5))
end

-- The factor for tick `number` (1 for evenly ticking DoTs). Shapes are stretched to the DoT's tick count.
local function tickShape(dot, number)
    local shape = dot.shape
    if not shape then return 1 end
    local i = math.ceil(math.min(math.max(number, 1), dot.totalTicks) / dot.totalTicks * #shape)
    return shape[math.max(1, math.min(i, #shape))]
end

-- TBC: the ramp (Curse of Agony's) only applies to the spell's base damage, the tooltip's number. Bonus damage from
-- spell power is spread evenly over every tick. So a tick is base * factor + bonus, with base the tooltip's per-tick
-- share, and the average tick (what's learned and shown) is base + bonus. Seen in-game: base 113, bonus ~83 gave
-- ticks of ~139, 196 and 252; treating the whole tick as ramped doubled the bonus in the small early ticks and
-- predicted 11-29% too much. With no bonus this is the same as average * factor.
local function shapedTick(dot, average, factor)
    if not dot.shape or factor == 1 then return average * factor end
    local base = dot.total / dot.totalTicks
    return math.max(0, base * factor + (average - base))
end

-- The average tick a tick of `amount` with this factor stands for (the inverse of shapedTick).
local function averageFromTick(dot, amount, factor)
    amount = amount / (dot.curseNow or 1) -- kept curse-free (see CURSE_EFFECTS)
    if not dot.shape or factor == 1 then return amount / factor end
    local base = dot.total / dot.totalTicks
    return amount - base * factor + base
end

-- A waiting DoT doesn't count toward the marker until its first tick lands (see WAIT_MODES).
-- A doubtful DoT (an avoid right after the cast that may not have been its own) always waits.
local function isWaiting(dot)
    if dot.ticksSeen > 0 then return false end
    if dot.doubtful or db.waitFirstTick == "always" then return true end
    return db.waitFirstTick == "unsure" and dot.unsure
end

-- Combo points, for finishers. By UNIT_SPELLCAST_SUCCEEDED they're already spent, so they're read when the
-- cast is sent. They were unreadable in combat on the Forever beta, so the addon also counts them itself:
-- builders say "Awards N combo point(s)" in their tooltips; a dodge/parry/miss right after takes them back;
-- a finisher or a target change resets the count. If neither source knows, finishers assume the lowest
-- entry, so the estimate errs low (no false skull) and nothing is learned from that cast.
local COMBO_CAP = 5
local COMBO_CACHE_SECONDS = 3
local comboAtSend, lastComboPoints, lastComboAt = nil, nil, 0
local countedPoints = 0

-- Cast outcomes. UNIT_COMBAT reports a dodge/parry/miss/resist/immune on the target, but not which attack it
-- belongs to. A cast's own result arrives almost at once (same frame in the logs), so the first outcome on the
-- target right after a cast decides: a hit means it landed, an avoid means it didn't. A melee auto-attack
-- avoided in that instant is rare; it makes the addon drop a DoT that landed, which errs low (never a false
-- kill). Results can also arrive just before the cast event, hence the short look-back.
local OUTCOME_WINDOW = 0.4
local OUTCOME_LOOKBACK = 0.25
local AVOIDED_ACTIONS = {
    MISS = true, DODGE = true, PARRY = true, EVADE = true, IMMUNE = true, DEFLECT = true, RESIST = true, REFLECT = true,
}
-- Spells can't be dodged or parried: next to a spell DoT, these were someone's melee (usually the pet's).
local MELEE_ONLY_AVOIDS = { DODGE = true, PARRY = true, DEFLECT = true }
local lastBuilder    -- { key, points, at }: builder whose outcome isn't known yet
-- A DoT with a direct part (Rake, Immolate) gets two results: the direct part can hit while the DoT itself is
-- IMMUNE (a bleed on a mob immune to bleeds). So a cast whose direct part hit stays pending (landedAt) for the
-- rest of its window, and only an IMMUNE can still remove its DoT.
local lastDotCast    -- { key, name, dot, previous, at, landedAt }: DoT cast whose outcome isn't known yet
local lastOutcome    -- { key, avoided, action, school, at, immune }: most recent outcome on a mob; a hit keeps
                     -- an IMMUNE just before it in .immune
local armedTrap      -- { spellID, name, total, school, duration, interval, placedAt, expiresAt }: see TRAP_DOTS
-- The mob each cast was aimed at, by cast GUID, taken when the cast is sent. An instant DoT's
-- UNIT_SPELLCAST_SUCCEEDED comes a server round trip later, and a player who tabs to the next mob straight
-- away has changed target by then: the DoT used to be put on the new target.
local sentTargets = {} -- castGUID -> { key, at }
local SENT_TARGET_SECONDS = 10

local function describeReading(ok, value)
    if not ok then return "error" end
    if value == nil then return "nil" end
    if isSecret(value) then return "secret" end
    return tostring(value)
end

-- The combo points the game's own display shows (ComboFrame, a lit ComboPointN.Highlight per point), for when the
-- number itself is secret: the display stays readable in combat. 0 when the frame is hidden, nil if unreadable.
-- From PR #14 (Ironship). Unverified in-game here.
local function displayedComboPoints()
    local frame = _G and _G.ComboFrame
    if type(frame) ~= "table" or type(frame.IsShown) ~= "function" then return nil end
    local ok, shown = pcall(frame.IsShown, frame)
    if not ok or isSecret(shown) then return nil end
    if not shown then return 0 end
    local count = 0
    for index = 1, 12 do
        local point = _G["ComboPoint" .. index]
        local highlight = type(point) == "table" and point.Highlight
        if type(highlight) ~= "table" or type(highlight.GetAlpha) ~= "function" then break end
        local okV, visible = pcall(point.IsShown, point)
        local okA, alpha = pcall(highlight.GetAlpha, highlight)
        if not okV or not okA or isSecret(visible) or isSecret(alpha) then return nil end
        if type(alpha) ~= "number" then return nil end
        if visible and alpha > 0.5 then count = count + 1 end
    end
    return count
end

-- Returns the best plain reading (or nil) and a description of what each API returned, for the log.
local function readComboPoints()
    local best, parts = nil, {}
    local function consider(label, ok, points)
        table.insert(parts, label .. "=" .. describeReading(ok, points))
        if ok and type(points) == "number" and not isSecret(points) then best = math.max(best or 0, points) end
    end
    if GetComboPoints then consider("GetComboPoints", pcall(GetComboPoints, "player", "target")) end
    if UnitPower and Enum and Enum.PowerType and Enum.PowerType.ComboPoints then
        consider("UnitPower", pcall(UnitPower, "player", Enum.PowerType.ComboPoints))
    end
    -- Only when neither API gave a number (secret in combat): the display is read by appearance, so it must
    -- never raise a readable count (too many points would mean a too-high estimate, a false kill icon).
    if best == nil then
        consider("display", true, displayedComboPoints())
    else
        table.insert(parts, "display=not needed")
    end
    return best, table.concat(parts, " ")
end

local function rememberComboPoints()
    local points = readComboPoints()
    if points and points > 0 then lastComboPoints, lastComboAt = points, GetTime() end
    return points
end

local function isFinisherDescription(desc)
    return type(desc) == "string" and not isSecret(desc)
        and (desc:find("Finishing move") ~= nil or ns.locale.isFinisher(desc))
end

-- The mob a cast is going to. UNIT_SPELLCAST_SENT only names it, so a cast whose name matches the focus but not
-- the target (a /cast [@focus] macro) goes on the focus (toughnuts99's patch, issue #12), and one whose name
-- matches the soft enemy (a mouseover or soft-target cast) goes on that. A same-named target wins, as before. A
-- focus or soft enemy whose GUID is secret can't be tracked, so that cast is skipped (false), not put on the target.
-- A friendly hard target never takes a cast: with one selected, the soft enemy is the cast's default mob (PR #14).
local function sentTargetKey(targetName)
    local okAttack, attackable = pcall(UnitCanAttack, "player", "target")
    -- With action targeting the corpse of the last kill can stay the hard target while the next mob (often of the
    -- same name) is the soft enemy: a corpse can't be cast at, so the cast goes to the soft enemy.
    local okDead, dead = pcall(UnitIsDeadOrGhost, "target")
    local targetDead = okDead and not isSecret(dead) and dead == true
    local targetKey
    if (okAttack and not isSecret(attackable) and attackable == false) or targetDead then
        targetKey = unitKey("softenemy")
    else
        -- Attackable, or the client cannot say: keep the old target behaviour.
        targetKey = unitKey("target")
    end
    if type(targetName) ~= "string" or isSecret(targetName) or targetName == "" then return targetKey end
    local function nameOf(unit)
        local ok, name = pcall(UnitName, unit)
        if ok and type(name) == "string" and not isSecret(name) then return name end
    end
    if not targetDead and nameOf("target") == targetName then return targetKey end
    if nameOf("focus") == targetName then return unitKey("focus") or false end
    -- A mouseover/soft-target cast names the soft enemy even while an attackable hard target is selected.
    if nameOf("softenemy") == targetName then return unitKey("softenemy") or false end
    return targetKey
end

local function onCastSent(spellID, castGUID, targetName)
    local now = GetTime()
    for guid, sent in pairs(sentTargets) do
        if now - sent.at > SENT_TARGET_SECONDS then sentTargets[guid] = nil end
    end
    if castGUID and not isSecret(castGUID) then
        sentTargets[castGUID] = { key = sentTargetKey(targetName), at = now }
    end
    local ok, _, desc = pcall(spellNameAndDescription, spellID)
    if not ok or not isFinisherDescription(desc) then return end
    local points, readings = readComboPoints()
    comboAtSend = points
    trace("COMBO at send: " .. readings .. ", counted=" .. countedPoints)
end

-- The mob a cast went to: the target when it was sent, else (no send seen) the target now.
local function castTargetKey(castGUID)
    local sent = castGUID and not isSecret(castGUID) and sentTargets[castGUID]
    if not sent then return unitKey("target") end
    sentTargets[castGUID] = nil
    return sent.key
end

-- An avoid on `key` that arrived just before the cast event (see OUTCOME_LOOKBACK), or nil. With
-- includeImmune, also an IMMUNE followed by a hit (a DoT's direct part landed, the DoT didn't); builders leave
-- it out, since their direct part landing awarded the points.
local function avoidJustBefore(key, includeImmune)
    if not lastOutcome or lastOutcome.key ~= key then return nil end
    local now = GetTime()
    if lastOutcome.avoided and now - lastOutcome.at <= OUTCOME_LOOKBACK then return lastOutcome end
    local immune = includeImmune and lastOutcome.immune
    if immune and now - immune.at <= OUTCOME_LOOKBACK then return immune end
end

-- A builder was cast: count its points unless it was already avoided, else wait for its outcome.
local function onBuilderCast(key, points)
    local avoided = avoidJustBefore(key)
    if avoided then
        trace("COMBO builder " .. avoided.action .. " (before cast event), counted=" .. countedPoints)
        return
    end
    countedPoints = math.min(COMBO_CAP, countedPoints + points)
    lastBuilder = { key = key, points = points, at = GetTime() }
end

-- A DoT cast whose result was avoided isn't on the target: drop it. (Waiting for a first tick to prove it
-- instead doesn't work for bleeds: melee white hits look just like ticks.) A recast replaced a DoT that is
-- still ticking, so that one is put back.
-- Spell DoTs are different: the pet and other players' melee miss all the time, and their ticks are told apart
-- from melee by school. So an avoid that can't be the spell's is ignored, and one that might not be (not
-- reported in the spell's school) makes a new DoT wait for its first tick instead of dropping it.
-- Returns false if the avoid was ignored, so the cast's own outcome may still come.
local function removeAvoidedDot(cast, action, school)
    local dot = cast.dot
    local dots = dotsByTarget[cast.key]
    if not dots or dots[cast.name] ~= dot then return true end
    local spellSchool = type(school) == "number" and not isSecret(school) and school == dot.school
    if dot.school ~= SCHOOL_MASKS.Physical and not spellSchool then
        if MELEE_ONLY_AVOIDS[action] then
            trace(string.format("AVOID %s (school %s) right after %s: not the spell, ignored", action,
                tostring(school), cast.name))
            return false
        end
        if not cast.previous then
            dot.doubtful = true
            trace(string.format("AVOID %s (school %s) right after %s: may be someone else's, waiting for its first tick",
                action, tostring(school), cast.name))
            return true
        end
    end
    if cast.previous then
        -- (Not marked discarded: if the recast did land, its later ticks are in the damage meter's total.)
        dots[cast.name] = cast.previous
        trace(string.format("AVOID %s (school %s) right after %s recast; keeping the earlier one", action,
            tostring(school), cast.name))
    else
        dot.discarded = true -- never on the mob: the damage meter learning leaves it out
        dots[cast.name] = nil
        trace(string.format("AVOID %s (school %s) right after %s; dropped", action, tostring(school), cast.name))
    end
    return true
end

local function onAvoided(key, action, school)
    local now = GetTime()
    lastOutcome = { key = key, avoided = true, action = action, school = school, at = now }
    if lastBuilder and lastBuilder.key == key then
        if now - lastBuilder.at <= OUTCOME_WINDOW then
            countedPoints = math.max(0, countedPoints - lastBuilder.points)
            trace("COMBO builder " .. action .. ", counted=" .. countedPoints)
        end
        lastBuilder = nil
    end
    if lastDotCast and lastDotCast.key == key then
        if now - lastDotCast.at > OUTCOME_WINDOW then
            lastDotCast = nil
        elseif lastDotCast.landedAt then
            -- Its direct part hit: other avoids are someone else's, but the DoT itself may be immune.
            if action == "IMMUNE" then
                trace("IMMUNE after " .. lastDotCast.name .. "'s direct hit: the DoT didn't land")
                if removeAvoidedDot(lastDotCast, action, school) then lastDotCast = nil end
            end
        elseif removeAvoidedDot(lastDotCast, action, school) then
            lastDotCast = nil
        end
    end
end

-- A hit on a mob: the pending casts on it landed (a later avoid belongs to something else, except an IMMUNE for
-- a DoT's own part). For a spell DoT only a hit in its school says so (Immolate's direct damage); a melee hit is
-- someone else's.
-- When each mob last took damage (Forever): it was alive then. The damage meter learning counts a DoT's ticks up to
-- that moment, whether or not each tick was picked out.
local lastHitAt, lastHitPrunedAt = {}, 0
local function onHit(key, school)
    local now = GetTime()
    lastHitAt[key] = now
    if now - lastHitPrunedAt > 60 then -- forget mobs not hit for a few minutes (one entry per mob otherwise kept)
        lastHitPrunedAt = now
        for k, at in pairs(lastHitAt) do if now - at > 300 then lastHitAt[k] = nil end end
    end
    local prior = lastOutcome
    lastOutcome = { key = key, avoided = false, at = now }
    if prior and prior.key == key and prior.action == "IMMUNE" and now - prior.at <= OUTCOME_LOOKBACK then
        lastOutcome.immune = prior
    end
    if lastBuilder and lastBuilder.key == key then lastBuilder = nil end
    -- UNIT_COMBAT can hand out a secret school; this runs before the amount/school guard, so never compare it.
    local schoolKnown = not isSecret(school)
    if lastDotCast and lastDotCast.key == key and not lastDotCast.landedAt
        and (lastDotCast.dot.school == SCHOOL_MASKS.Physical
            or (schoolKnown and lastDotCast.dot.school == school)) then
        lastDotCast.landedAt = now
    end
end

local function resetComboCount()
    countedPoints, lastBuilder = 0, nil
    -- The cached reading belongs to the old target too: a finisher on a new target would otherwise use the points
    -- built on the previous one (5 points' damage instead of the cautious 1-point entry).
    lastComboPoints, lastComboAt = nil, 0
end

-- Returns points and where they came from, or nil and "unknown".
local function comboPointsForCast()
    local points, source = comboAtSend, "read"
    if not (points and points > 0) then
        if lastComboPoints and GetTime() - lastComboAt <= COMBO_CACHE_SECONDS then
            points, source = lastComboPoints, "cached"
        elseif countedPoints > 0 then
            points, source = countedPoints, "counted"
        else
            points, source = nil, "unknown"
        end
    end
    comboAtSend = nil
    resetComboCount()
    return points, source
end

-- TBC port: the player's power for a school, readable there (Forever hides it): spell damage for spells, attack
-- power for Physical bleeds. A DoT's power is fixed when it's cast, so this is read on the cast.
local SPELL_SCHOOL_INDEX = { [2] = 2, [4] = 3, [8] = 4, [16] = 5, [32] = 6, [64] = 7 } -- mask -> GetSpellBonusDamage
local function currentPower(school)
    local ok, value
    if school == SCHOOL_MASKS.Physical then
        if not UnitAttackPower then return nil end
        local okAP, base, pos, neg = pcall(UnitAttackPower, "player")
        -- Forever hides attack power in combat: a secret part can't be added up (seen in-game on feral bleeds).
        if not okAP or isSecret(base) or isSecret(pos) or isSecret(neg) then return nil end
        ok, value = true, type(base) == "number" and (base + (tonumber(pos) or 0) + (tonumber(neg) or 0)) or nil
    else
        local index = SPELL_SCHOOL_INDEX[school]
        if not index and school then -- combined schools: the highest of their parts
            for mask, i in pairs(SPELL_SCHOOL_INDEX) do
                if bit and bit.band and bit.band(school, mask) ~= 0 then index = i end
            end
        end
        if not (index and GetSpellBonusDamage) then return nil end
        ok, value = pcall(GetSpellBonusDamage, index)
    end
    if ok and type(value) == "number" and not isSecret(value) and value >= 0 then return value end
end

-- The learned tick size for this cast. Ticks are the tooltip's base share plus a bonus from spell (or attack)
-- power, so when power changed since the size was learned (a trinket, flask, new gear), the bonus part is
-- scaled to the power now. Percent effects (talents, curses and debuffs on the mob) are already in the learned
-- size; the cast's own ticks replace this once they land.
--
-- Before a cast's first tick, the CAUTIOUS size is used: the lowest of the last few casts, each scaled to the power
-- now. Ticks also depend on what's on the mob (Improved Shadow Bolt's Shadow Vulnerability, Curse of Shadow,
-- Shadow Weaving: +10-20%), and a size learned while one was up made the next cast on a mob without it look lethal
-- for its first seconds (seen in-game: Corruption learned at 291 under Shadow Vulnerability, 243 without). Erring
-- low only delays the kill icon until the first tick, which then gives the real size.
local TICK_HISTORY = 5
local function scaleTo(avg, entryPower, base, power)
    local bonus = avg - base
    if power and entryPower and entryPower > 0 and bonus > 0 then return base + bonus * power / entryPower end
    return avg
end
-- The cautious size never goes below CAUTIOUS_FLOOR of the latest cast's size: what's on a mob changes ticks by
-- 10-25%, so that covers it, while one odd cast (heavy resists, a tanky mob) can't halve the next five estimates
-- (seen in-game: Corruption predicted 175.8 per tick, real 351.8).
local CAUTIOUS_FLOOR = 0.8
local function scaledLearned(tickKey, base, power)
    local learned = tickKey and db.ticks[tickKey]
    if not learned then return nil end
    local latest = scaleTo(learned, db.tickPower and db.tickPower[tickKey], base, power)
    local history = db.tickHistory and db.tickHistory[tickKey]
    if type(history) == "table" and #history > 0 then
        local lowest
        for _, entry in ipairs(history) do
            local value = scaleTo(entry.avg, entry.power, base, power)
            if not lowest or value < lowest then lowest = value end
        end
        return math.max(lowest, latest * CAUTIOUS_FLOOR)
    end
    return latest
end

-- A DoT as it stands the moment it's applied, before any tick.
local function newDot(spellID, tickKey, name, total, school, duration, statedInterval, now)
    local interval = statedInterval or KNOWN_TICK_INTERVALS[name] or DEFAULT_TICK_INTERVAL
    school = SCHOOL_BY_NAME[name] or school
    local totalTicks = math.max(1, math.floor(duration / interval + 0.5))
    local power = currentPower(school)
    return {
        spellID = spellID,
        tickKey = tickKey,
        powerAtCast = power,
        -- The size learned before this cast (scaled to this cast's power): a same-slot collision is judged
        -- against it, not against the value the disputed tick just wrote (referenceTickSize).
        learnedAtApply = scaledLearned(tickKey, total / totalTicks, power),
        school = school,
        total = total,
        duration = duration,
        interval = interval,
        totalTicks = totalTicks,
        shape = TICK_SHAPES[name],
        travel = PROJECTILE_DOTS[name] and PROJECTILE_TRAVEL or nil,
        appliedAt = now,
        expiresAt = now + duration,
        nextTickAt = now + interval,
        tickSum = 0,        -- non-crit ticks only
        normalTicks = 0,
        ticksSeen = 0,      -- including crits
        missed = 0,
    }
end

-- Returns the target key the DoT was applied to, or nil if the cast wasn't a tracked DoT.
-- Forever: real tick sizes from Blizzard's damage meter (idea from JoeGG's Does It Die v0.9.1). Forever hides each
-- tick's amount, so a DoT's ticks are counted (school and timing) but teach no size, and the estimate stays at the
-- tooltip's, which leaves out spell and attack power. After combat the damage meter's per-spell totals can be read:
-- a spell's total over the ticks counted this combat is its real tick (an upfront hit, like Immolate's, is split off
-- by the tooltip's numbers). It's only learned when the two can match: every cast this combat was on a known mob and
-- showed its ticks.
local meterTally, meterUntracked = {}, {} -- this combat: tickKey -> counts; spellIDs cast at no known mob

local function meterTallyFor(dot)
    if not ns.isForever or not dot.tickKey then return nil end
    local t = meterTally[dot.tickKey]
    if not t then
        t = { spellID = dot.spellID, name = dot.name or tostring(dot.spellID), school = dot.school, shaped = dot.shape ~= nil, factors = 0, ticks = 0, direct = 0,
            descTick = dot.total / dot.totalTicks, dots = {} }
        meterTally[dot.tickKey] = t
    end
    return t
end

-- The upfront hit in an English tooltip, before the DoT's clause ("Burns the enemy for 11 Fire damage and then an
-- additional 20 Fire damage over 15 sec": 11; "44 to 52": their middle). nil: another language, can't tell.
local function directPart(desc)
    if type(desc) ~= "string" or isSecret(desc) then return nil end
    -- (FlareUI: not English text: the client's language tells its own upfront hit, Locale.lua L.directPart)
    if not desc:find("damage") then return ns.locale.directPart(desc) end
    desc = joinThousands(desc)
    local clauseAt
    for at in desc:gmatch("()%d+[%a ]-damage over %d") do clauseAt = at end
    if not clauseAt then return 0 end
    local head = desc:sub(1, clauseAt - 1)
    local lo, hi = head:match("(%d+) to (%d+)")
    if lo then return (tonumber(lo) + tonumber(hi)) / 2 end
    return tonumber(head:match("(%d+)[^%d]-damage")) or 0
end

local function meterCountTick(dot, factor, tickIndex)
    local t = meterTallyFor(dot)
    if t then t.factors, t.ticks = t.factors + (factor or 1), t.ticks + 1 end
    if tickIndex then dot.meterLastTick = math.max(dot.meterLastTick or 0, tickIndex) end
end

-- A spell's tooltip text can be missing the first time it's cast (the client loads spell data on demand, seen on
-- a fresh character): the cast waits up to DESC_WAIT_SECONDS for it, then is tracked as if it had just landed.
local DESC_WAIT_SECONDS = 3
local pendingDesc -- { spellID, key, at }
local skippedLogged = {} -- spellID -> true once its tooltip has been logged as not a DoT
local function onPlayerCast(spellID, castGUID, keyOverride)
    local key = keyOverride or castTargetKey(castGUID)
    local ok, name, desc = pcall(spellNameAndDescription, spellID)
    if not ok or not name or isSecret(name) then
        trace(string.format("CAST id %s: its name can't be read (%s)", tostring(spellID), ok and "hidden" or tostring(name)))
        return
    end
    if isSecret(desc) then
        trace(string.format("CAST %s (id %d): its tooltip is hidden by the game, so it can't be tracked", name, spellID))
        return
    end
    if desc == nil or desc == "" then
        if not keyOverride and key then
            pendingDesc = { spellID = spellID, key = key, at = GetTime() }
            if C_Spell and C_Spell.RequestLoadSpellData then pcall(C_Spell.RequestLoadSpellData, spellID) end
            trace(string.format("WAIT %s (id %d): its tooltip isn't loaded yet", name, spellID))
        end
        return
    end
    if type(desc) == "string" and not isSecret(desc) then
        local awarded = tonumber(desc:match("Awards (%d+) combo point")) or ns.locale.comboPointsAwarded(desc)
        if awarded then onBuilderCast(key, awarded) end
        -- Only one Fire trap can be active: any new one (Explosive Trap too) replaces the armed one.
        -- TBC words it "Place a fire trap ... Only one trap can be active at a time".
        if armedTrap and (desc:find("[Ff]ire trap") or desc:find("[Oo]nly one trap")) then armedTrap = nil end
    end
    onCurseCast(key, spellID, name)
    if IGNORED_SPELLS[name] then return end
    local isFinisher = isFinisherDescription(desc)
    local comboPoints, comboSource
    if isFinisher then comboPoints, comboSource = comboPointsForCast() end
    -- Unknown points: parse the lowest entry (errs low), and don't use or teach learned tick sizes.
    local total, school, duration, statedInterval = parseDot(desc, comboPoints or 1)
    if not total then
        if not isSecret(desc) and ns.locale.shouldLogUnread(spellID, desc) then
            trace(string.format("NOT READ %s (id %d): %s", name, spellID, desc))
        elseif not isSecret(desc) and not skippedLogged[spellID] then
            -- Once per spell: what a tooltip that wasn't read as a DoT says, so a missed DoT shows up in /did debug.
            skippedLogged[spellID] = true
            trace(string.format("SKIP %s (id %d), not a DoT by its tooltip: %s", name, spellID,
                tostring(desc):gsub("[\r\n]+", " "):sub(1, 160)))
        end
        return
    end
    -- A finisher's tick size depends on the points spent, so learned sizes are kept per point count.
    local tickKey = spellID
    if isFinisher then tickKey = comboPoints and (spellID .. "x" .. comboPoints) or nil end
    -- Ticks on players (resilience, PvP buffs) are learned separately, so PvP never drags down PvE estimates.
    if tickKey and type(key) == "string" and key:find("^Player%-") then tickKey = tickKey .. "p" end

    local now = GetTime()
    if TRAP_DOTS[name] then
        -- A new trap replaces the armed one ("Only one Fire trap can be active at a time").
        local interval = statedInterval or KNOWN_TICK_INTERVALS[name] or DEFAULT_TICK_INTERVAL
        school = SCHOOL_BY_NAME[name] or school
        local lifetime = tonumber(desc:match("[Tt]rap will exist for (%d+) min"))
        armedTrap = { spellID = spellID, name = name, total = total, school = school, duration = duration,
            interval = interval, placedAt = now, expiresAt = now + (lifetime or 1) * 60 }
        trace(string.format("TRAP %s (id %d) armed: %d dmg over %ss, school %d, per-tick %s", name, spellID, total,
            duration, school, db.ticks[spellID] and ("learned " .. db.ticks[spellID]) or "from description"))
        return
    end

    if not key then
        trace(string.format("CAST %s (id %d): no target to put it on", name, spellID))
        meterUntracked[spellID] = true
        return
    end

    dotsByTarget[key] = dotsByTarget[key] or {}
    local previous = dotsByTarget[key][name]
    -- A doubtful cast (see removeAvoidedDot) whose first tick was due in sight and didn't come, recast: its miss
    -- was real, it never landed.
    if previous and previous.doubtful and previous.ticksSeen == 0 and previous.missed >= 1 then
        previous.discarded = true
    end
    if previous then previous.replacedAt = now end
    local dot = newDot(spellID, tickKey, name, total, school, duration, statedInterval, now)
    dot.name = name
    dot.key = key
    -- FlareUI: a finisher's size is learned per combo point count, and a count not learned yet started from the
    -- tooltip, which leaves out attack power (seen in-game: Rip at 4 points learned 88 a tick against the
    -- tooltip's 50, at 5 points 102.7 against 60.5, the same 1.7x; at 1 and 3 points the estimate stayed at
    -- 37 and 39.5). So such a count borrows the ratio of the nearest count that was learned.
    local borrowedFrom
    if isFinisher and comboPoints and tickKey and not dot.learnedAtApply then
        local suffix = tostring(tickKey):match("p$") or ""
        local best, bestGap
        for points = 1, COMBO_CAP do
            local learnedSize = db.ticks[spellID .. "x" .. points .. suffix]
            local gap = math.abs(points - comboPoints)
            if learnedSize and points ~= comboPoints and (not bestGap or gap < bestGap) then
                local otherTotal, _, otherDuration, otherInterval = parseDot(desc, points)
                if otherTotal and otherDuration and otherDuration > 0 then
                    local every = otherInterval or KNOWN_TICK_INTERVALS[name] or DEFAULT_TICK_INTERVAL
                    local tooltipTick = otherTotal / math.max(1, math.floor(otherDuration / every + 0.5))
                    if tooltipTick > 0 then best, bestGap, borrowedFrom = learnedSize / tooltipTick, gap, points end
                end
            end
        end
        if best then dot.learnedAtApply = best * dot.total / dot.totalTicks else borrowedFrom = nil end
    end
    do
        local t = meterTallyFor(dot)
        if t then
            t.dots[#t.dots + 1] = dot
            local direct = isFinisher and 0 or directPart(desc)
            if direct == nil then
                t.unclear = true
                -- (FlareUI: once per spell, the text that couldn't be split, so the language's reader can be taught it)
                if not skippedLogged["direct" .. spellID] then
                    skippedLogged["direct" .. spellID] = true
                    trace(string.format("UPFRONT of %s (id %d) not told apart in: %s", name, spellID,
                        tostring(desc):gsub("[\r\n]+", " "):sub(1, 220)))
                end
            else
                t.direct = t.direct + direct
            end
        end
    end
    dotsByTarget[key][name] = dot
    lastDotCast = { key = key, name = name, dot = dot, previous = previous, at = now }
    local learned = dot.learnedAtApply and math.floor(dot.learnedAtApply * 10 + 0.5) / 10
    if borrowedFrom then
        learned = string.format("%s (the %d-point size's ratio to its tooltip)", learned, borrowedFrom)
    elseif learned and dot.powerAtCast and db.tickPower and db.tickPower[tickKey] then
        learned = string.format("%s (scaled from %s at power %d to %d)", learned, db.ticks[tickKey],
            db.tickPower[tickKey], dot.powerAtCast)
    end
    -- The starting estimate is shaky without a learned tick size (description numbers leave out spell power
    -- and attack power) or, for finishers, without knowing the combo points.
    dot.unsure = not learned
    trace(string.format("CAST %s (id %d)%s: %d dmg over %ss, school %d, tick every %ss, per-tick %s%s%s", name, spellID,
        isFinisher and string.format(" %s combo points (%s)", comboPoints or "?", comboSource) or "",
        total, duration, dot.school, dot.interval, learned and ("learned " .. learned) or "from description",
        isWaiting(dot) and ", waiting for first tick" or "",
        key ~= unitKey("target") and (" on " .. tostring(key) .. ", the target when sent") or ""))
    local avoided = avoidJustBefore(key, true)
    if avoided and removeAvoidedDot(lastDotCast, avoided.action, avoided.school) then
        lastDotCast = nil
        if dotsByTarget[key] and dotsByTarget[key][name] == dot then return key, isWaiting(dot) end
        return nil
    end
    return key, isWaiting(dot)
end

-- "Estimate during casting": a DoT with a cast time shows from UNIT_SPELLCAST_START, with the estimate its
-- cast would make. It's kept out of dotsByTarget, so ticks never match it and housekeeping leaves it alone,
-- and it stands in for a DoT of the same name that the cast would refresh (replaces, never adds). On success
-- onPlayerCast takes over exactly as without it. A failed or interrupted cast, or a target change, just drops
-- it, so a DoT it was about to refresh keeps ticking as if nothing happened. STOP ends every cast, successful
-- or not, and may come just before SUCCEEDED, so a stopped cast is only dropped if no success follows shortly.
local CAST_STOP_GRACE = 0.5
local CAST_MAX_SECONDS = 15 -- a lost end event never leaves an estimate behind
local castInProgress -- { key, name, dot, castGUID, spellID, startedAt, stoppedAt }

-- Whether an event's castGUID (or, when either GUID is unreadable, its spell ID) is the cast in progress.
local function sameCast(cast, castGUID, spellID)
    if cast.castGUID and castGUID ~= nil and not isSecret(castGUID) then return castGUID == cast.castGUID end
    return not isSecret(spellID) and spellID == cast.spellID
end

local function dropCastInProgress(reason)
    if not castInProgress then return end
    trace("CASTING " .. castInProgress.name .. " " .. reason .. "; estimate removed")
    castInProgress = nil
end

-- UNIT_SPELLCAST_START (player). Returns the target key when a DoT now shows for the cast.
local function onCastStart(castGUID, spellID)
    castInProgress = nil
    if not db.estimateDuringCast or isSecret(spellID) then return end
    local ok, name, desc = pcall(spellNameAndDescription, spellID)
    if not ok or not name or isSecret(name) or IGNORED_SPELLS[name] or isFinisherDescription(desc) then return end
    local total, school, duration, statedInterval = parseDot(desc, 1)
    if not total then return end
    -- The mob it was sent at (a [@focus] macro's focus), else the target. Kept for the cast's success.
    local sent = castGUID and not isSecret(castGUID) and sentTargets[castGUID]
    local key
    if sent then key = sent.key else key = unitKey("target") end
    if not key then return end
    local now = GetTime()
    local dot = newDot(spellID, spellID, name, total, school, duration, statedInterval, now)
    local learned = db.ticks[spellID]
    dot.unsure = not learned
    dot.provisional = true
    castInProgress = { key = key, name = name, dot = dot, spellID = spellID, startedAt = now,
        castGUID = not isSecret(castGUID) and castGUID or nil }
    trace(string.format("CASTING %s (id %d): %d dmg over %ss, per-tick %s%s", name, spellID, total, duration,
        learned and ("learned " .. learned) or "from description", isWaiting(dot) and ", waiting for first tick" or ""))
    return key
end

-- UNIT_SPELLCAST_SUCCEEDED (player), just before onPlayerCast: the cast's own DoT replaces the estimate.
local function onCastSucceeded(castGUID, spellID)
    if castInProgress and sameCast(castInProgress, castGUID, spellID) then castInProgress = nil end
end

-- UNIT_SPELLCAST_STOP / FAILED / INTERRUPTED (player). Returns true when the estimate was removed.
-- Channels (TBC port): Drain Life, Drain Soul and Mind Flay count toward the marker while you channel them. The
-- channel's end time is known (UnitChannelInfo) and moves with pushback (UNIT_SPELLCAST_CHANNEL_UPDATE), so the
-- damage still to come is the ticks left before it ends times the tick size, learned from real ticks like any
-- DoT's. Stopping the channel (moving, interrupt, the end) removes it.
local channels = {}
do
    local current -- { key, name, dot }

    local function channelEndTime()
        if not UnitChannelInfo then return nil end
        local ok, _, _, _, _, endMS = pcall(UnitChannelInfo, "player")
        if ok and type(endMS) == "number" and not isSecret(endMS) then return endMS / 1000 end
    end

    function channels.stop(reason)
        if not current then return false end
        current.dot.channelStoppedAt = GetTime() -- how many ticks it got in (damage meter learning)
        local dots = dotsByTarget[current.key]
        if dots and dots[current.name] == current.dot then
            dots[current.name] = nil
            if next(dots) == nil then dotsByTarget[current.key] = nil end
        end
        trace("CHANNEL " .. current.name .. " " .. reason)
        current = nil
        return true
    end

    -- UNIT_SPELLCAST_CHANNEL_START (player). Returns the key the channel is on.
    function channels.start(castGUID, spellID)
        channels.stop("replaced")
        if not db.trackChannels or isSecret(spellID) then return end
        local ok, name, desc = pcall(spellNameAndDescription, spellID)
        if not ok or not name or isSecret(name) or not CHANNEL_DOTS[name] then return end
        local total, school, duration, statedInterval = parseDot(desc, 1)
        if not total then return end
        local sent = castGUID and not isSecret(castGUID) and sentTargets[castGUID]
        local key = sent and sent.key or unitKey("target")
        if not key then return end
        local now = GetTime()
        local dot = newDot(spellID, spellID, name, total, school, duration, statedInterval, now)
        local endsAt = channelEndTime()
        if endsAt and endsAt > now then dot.expiresAt, dot.channelEndsAt = endsAt, endsAt end
        dot.channel = true
        dot.key = key
        -- Forever: learned from the damage meter like a DoT. The game says when the channel starts and stops, so
        -- the ticks it got in are known exactly even though each one is hidden.
        do
            local t = meterTallyFor(dot)
            if t then t.dots[#t.dots + 1] = dot end
        end
        local okS, _, _, _, startMS = pcall(UnitChannelInfo or function() end, "player")
        local start = okS and type(startMS) == "number" and not isSecret(startMS) and startMS / 1000 or nil
        dot.channelStart = (start and math.abs(start - now) < 1) and start or now
        dotsByTarget[key] = dotsByTarget[key] or {}
        dotsByTarget[key][name] = dot
        current = { key = key, name = name, dot = dot }
        trace(string.format("CHANNEL %s (id %d): %d dmg over %ss, per-tick %s, ends in %.1fs", name, spellID, total,
            duration, db.ticks[spellID] and ("learned " .. db.ticks[spellID]) or "from description",
            dot.expiresAt - now))
        return key
    end

    -- UNIT_SPELLCAST_CHANNEL_UPDATE (player): pushback shortened the channel.
    function channels.update()
        if not current then return false end
        local endsAt = channelEndTime()
        if not endsAt then return false end
        current.dot.expiresAt, current.dot.channelEndsAt = endsAt, endsAt
        trace(string.format("CHANNEL %s pushed back: ends in %.1fs", current.name, endsAt - GetTime()))
        return true
    end

    function channels.key() return current and current.key end
end

local function onCastEnded(event, castGUID, spellID)
    if not castInProgress or not sameCast(castInProgress, castGUID, spellID) then return end
    if event == "UNIT_SPELLCAST_STOP" then
        castInProgress.stoppedAt = castInProgress.stoppedAt or GetTime()
        return
    end
    dropCastInProgress(event == "UNIT_SPELLCAST_INTERRUPTED" and "interrupted" or "failed")
    return true
end

-- Seconds between now and the nearest expected tick time, and that tick's index. Anchored on the first tick
-- once seen (ticks keep its rhythm; anchoring on the latest tick would let jitter add up), else on the cast.
-- Using the nearest multiple of the interval means one missed tick doesn't lose the DoT.
local function distanceToExpectedTick(dot, now)
    local anchor = dot.firstTickAt or dot.appliedAt
    if not dot.firstTickAt and dot.travel then
        -- Still in flight: the DoT started anywhere up to `travel` seconds after the cast.
        local late = now - (anchor + dot.interval)
        if late > 0 then anchor = anchor + math.min(late, dot.travel) end
    end
    local k =math.max(1, math.floor((now - anchor) / dot.interval + 0.5))
    return math.abs(now - (anchor + k * dot.interval)), k
end

local function plausibleTickAmount(dot, amount, isCrit, number)
    local known, tolerance
    if dot.normalTicks > 0 then
        known, tolerance = dot.tickSum / dot.normalTicks, TICK_AMOUNT_TOLERANCE
    else
        known, tolerance = dot.learnedAtApply or (dot.tickKey and db.ticks[dot.tickKey]), FIRST_TICK_AMOUNT_TOLERANCE
    end
    if not known then return true end
    known = shapedTick(dot, known, tickShape(dot, number))
    if isCrit then
        return amount >= known * CRIT_MIN_RATIO - 1 and amount <= known * CRIT_MAX_RATIO + 1
    end
    return math.abs(amount - known) <= math.max(1, known * tolerance)
end

-- Tick size to judge a same-slot collision by: the average of the DoT's earlier ticks, or with fewer than two
-- ticks the size learned before this cast, else the description's per-tick share. Learned first: descriptions
-- leave out spell and attack power, so their share sits far below real ticks (Rake: 13 vs 26), and judging by it
-- took a white hit for the tick and learned that.
local function referenceTickSize(dot)
    if dot.normalTicks > 1 then
        return (dot.tickSum - averageFromTick(dot, dot.lastTickAmount, dot.lastTickShape)) / (dot.normalTicks - 1)
    end
    return dot.learnedAtApply or (dot.total / dot.totalTicks)
end

local function saveLearnedTick(dot)
    if dot.tickKey and dot.normalTicks > 0 then
        db.ticks[dot.tickKey] = math.floor(dot.tickSum / dot.normalTicks * 10 + 0.5) / 10
        db.tickPower = db.tickPower or {}
        db.tickPower[dot.tickKey] = dot.powerAtCast -- the power it was learned at (scaledLearned)
        -- This cast's entry in the per-spell history (scaledLearned uses the lowest of the last few).
        db.tickHistory = db.tickHistory or {}
        local history = db.tickHistory[dot.tickKey] or {}
        db.tickHistory[dot.tickKey] = history
        if not dot.historyEntry then
            dot.historyEntry = {}
            table.insert(history, dot.historyEntry)
            while #history > TICK_HISTORY do table.remove(history, 1) end
        end
        dot.historyEntry.avg = db.ticks[dot.tickKey]
        dot.historyEntry.power = dot.powerAtCast
    end
end

-- Moves a DoT's tick bookkeeping to the tick in slot `index` that landed at `now`.
local function anchorTick(dot, index, now)
    dot.missed = 0
    if dot.firstTickAt then
        dot.lastTickIndex = index
    else
        dot.firstTickAt, dot.lastTickIndex = now, 0
        -- A projectile DoT started when it landed: count its ticks from there.
        if dot.travel then dot.appliedAt = now - index * dot.interval end
    end
    dot.lastTickAt = now
    dot.nextTickAt = now + dot.interval
    -- Re-anchor expiry on the observed tick: ticks arrive slightly after their nominal time, and an
    -- expiry based on the cast event would otherwise cut off the final tick.
    local tickIndex = math.max(1, math.floor((now - dot.appliedAt) / dot.interval + 0.5))
    dot.expiresAt = now + (dot.totalTicks - tickIndex) * dot.interval
    return tickIndex
end

-- Two same-school hits in one tick slot (e.g. Shadow Bolt landing with a Corruption tick, log 123506.4): the
-- first one was taken as the tick. If this one is closer to the expected size, it was the real tick.
local SAME_SLOT_SECONDS = 0.2
local function trySwapSameSlot(dot, name, amount, isCrit, now)
    if isCrit or amount <= 0 or dot.lastTickCrit or not dot.lastTickAt
        or dot.lastTickAmount <= 0 or now - dot.lastTickAt > SAME_SLOT_SECONDS then
        return false
    end
    local factor = dot.lastTickShape
    local reference = shapedTick(dot, referenceTickSize(dot), factor)
    if math.abs(amount - reference) >= math.abs(dot.lastTickAmount - reference) then return false end
    trace(string.format("SWAP %s tick: %d was another hit, %d is the tick", name, dot.lastTickAmount, amount))
    dot.tickSum = dot.tickSum + averageFromTick(dot, amount, factor) - averageFromTick(dot, dot.lastTickAmount, factor)
    dot.lastTickAmount = amount
    saveLearnedTick(dot)
    return true
end

-- A learned size that's wrong rejects every real tick (log: Corruption learned 29 from Shadow Bolts, real ticks
-- 10-11, every cast dropped). Hits rejected only on size, but landing on the DoT's rhythm in two consecutive
-- slots and agreeing with each other, are the real ticks: relearn from them.
-- Description damage omits stat bonuses; a band around it or the old learned size can lock out real ticks.
local function tryRelearn(dot, name, amount, isCrit, index, distance, now)
    local window = dot.firstTickAt and TICK_MATCH_WINDOW_ANCHORED or TICK_MATCH_WINDOW
    local freshSlot = not dot.firstTickAt or index > dot.lastTickIndex
    if isCrit or amount <= 0 or not freshSlot or distance > window then return false end
    local previous = dot.offBeatCandidate
    local factor = tickShape(dot, tickNumberAt(dot, now))
    local average = averageFromTick(dot, amount, factor)
    dot.offBeatCandidate = { index = index, amount = amount, average = average, at = now }
    if not previous or index ~= previous.index + 1
        or math.abs(average - previous.average) > math.max(1, previous.average * TICK_AMOUNT_TOLERANCE) then
        return false
    end
    trace(string.format("RELEARN %s: ticks of %d and %d on its rhythm didn't fit %.1f/tick", name,
        previous.amount, amount, expectedTick(dot)))
    dot.offBeatCandidate = nil
    dot.tickSum, dot.normalTicks = previous.average + average, 2
    dot.ticksSeen = dot.ticksSeen + 2
    dot.lastTickAmount, dot.lastTickShape, dot.lastTickCrit = amount, factor, false
    saveLearnedTick(dot)
    if not dot.firstTickAt then
        dot.firstTickAt, dot.lastTickIndex = previous.at, 0
        index = 1
    end
    anchorTick(dot, index, now)
    return true
end

-- Counts a hit as the DoT's tick in slot `index`. Returns the tick's number (1 = first) and shape factor.
local function recordTick(dot, amount, isCrit, index, now)
    -- Accuracy report bookkeeping for clients without the combat log (Forever), where ticks come from UNIT_COMBAT:
    -- the combat log path (onPeriodic) does this itself, with partial resists kept apart.
    if not dot.predictedAt and (dot.ticksSeen or 0) == 0 then
        dot.predictedAt = math.floor((ns.remainingDamageOf and ns.remainingDamageOf(dot) or 0) + 0.5)
        dot.startPerTick = expectedTick(dot)
    end
    if not dot.dealtByLog then dot.dealt = (dot.dealt or 0) + (tonumber(amount) or 0) end
    local factor = tickShape(dot, tickNumberAt(dot, now))
    dot.ticksSeen = dot.ticksSeen + 1
    dot.lastTickAmount, dot.lastTickShape, dot.lastTickCrit = amount, factor, isCrit
    dot.offBeatCandidate = nil
    if not isCrit and amount > 0 then
        dot.tickSum = dot.tickSum + averageFromTick(dot, amount, factor)
        dot.normalTicks = dot.normalTicks + 1
        saveLearnedTick(dot)
    end
    return anchorTick(dot, index, now), factor
end

-- An armed trap's first tick: an unmatched hit of its school and size on any mob, at least one tick interval
-- after the trap was placed (the DoT ticks first one interval after it springs). Starts the DoT there, as tick
-- 1. Without a learned size the description's share is only a rough guide (it may leave out attack power), so
-- the range is wide (0.5-2.5x). If the trapped mob's first tick went unseen (not the target, focus or a visible
-- nameplate), a later tick is taken for the first and the estimate runs high for that trap.
local function springTrap(key, unit, amount, school, isCrit, now)
    local trap = armedTrap
    if not trap or school ~= trap.school then return false end
    if now > trap.expiresAt + trap.interval + TICK_MATCH_WINDOW then armedTrap = nil; return false end
    if now < trap.placedAt + trap.interval - TICK_MATCH_WINDOW then return false end
    local dot = newDot(trap.spellID, trap.spellID, trap.name, trap.total, trap.school, trap.duration,
        trap.interval, now - trap.interval)
    if amount == nil then
        -- Forever hides the amount: any hit in the trap's school after it could have been sprung takes it.
        dot.sizeHidden = true
    elseif db.ticks[trap.spellID] then
        if not plausibleTickAmount(dot, amount, isCrit, 1) then return false end
    else
        local share = trap.total / dot.totalTicks
        local low, high = share * 0.5, share * 2.5
        if isCrit then low, high = low * CRIT_MIN_RATIO, high * CRIT_MAX_RATIO end
        if amount < low or amount > high then return false end
    end
    armedTrap = nil
    dotsByTarget[key] = dotsByTarget[key] or {}
    dotsByTarget[key][trap.name] = dot
    local tickIndex = recordTick(dot, amount or 0, isCrit, 1, now)
    dot.confirmed = true
    trace(string.format("TRAP %s sprung on %s: first tick %s%s %.1fs after placing (tick %d/%d)", trap.name, unit,
        amount and tostring(amount) or "(amount hidden)", isCrit and " CRIT" or "", now - trap.placedAt, tickIndex, dot.totalTicks))
    return true
end

-- Returns the target key when this hit was the first tick of a DoT that was waiting for it (so the display
-- can flash now that the DoT shows), else nil.
-- The same hit arrives once per unit token showing the mob (target, nameplateN, focus...) and must count once. But
-- two DoTs of one school can tick for the same amount in the same instant: those are two hits from the same token.
-- So within an instant each signature (mob, amount, school) remembers its token and the DoTs it fed: a repeat
-- from the same token feeds another DoT, one from another token is a copy and is dropped (PR #14).
local combatFrameAt
local combatFrameHits = {}
-- A tick whose amount is hidden (Forever): matched to the same-school DoT whose rhythm it fits best. Returns the
-- mob's key when a DoT that was waiting for its first tick shows from now.
local hiddenFrameAt, hiddenFrameHits = nil, {}
local function onHiddenTick(key, unit, school)
    local dots = dotsByTarget[key]
    local now = GetTime()
    if not dots then
        -- Immolation Trap: its first tick on whoever walked into it.
        if springTrap(key, unit, nil, school, false, now) then return key end
        return
    end
    if hiddenFrameAt ~= now then hiddenFrameAt, hiddenFrameHits = now, {} end
    -- The same hit fires for target, nameplateN, ...: count it once.
    local signature = key .. ":" .. school
    if hiddenFrameHits[signature] and hiddenFrameHits[signature] ~= unit then return end
    hiddenFrameHits[signature] = unit
    local best, bestName, bestDistance, bestIndex
    for name, dot in pairs(dots) do
        if dot.school == school and not dot.channel then
            local distance, index = distanceToExpectedTick(dot, now)
            local window = dot.firstTickAt and TICK_MATCH_WINDOW_ANCHORED or TICK_MATCH_WINDOW
            local freshSlot
            if dot.firstTickAt then
                freshSlot = index > dot.lastTickIndex
            else
                freshSlot = index > (dot.hiddenSlot or 0)
            end
            if freshSlot and distance <= window and (not bestDistance or distance < bestDistance) then
                best, bestName, bestDistance, bestIndex = dot, name, distance, index
            end
        end
    end
    if not best then
        if springTrap(key, unit, nil, school, false, now) then return key end
        return
    end
    local wasWaiting = isWaiting(best)
    best.sizeHidden = true
    local tickIndex
    if school == SCHOOL_MASKS.Physical and not best.firstTickAt then
        -- Bleeds: a melee white hit is Physical too and can land in a tick's window, so with the amount hidden the
        -- hit may not be the tick. Re-timing the bleed on such hits pulled it earlier until the marker ran out a tick
        -- before the bleed did. Its ticks are counted on the schedule from the cast instead (the first lands within
        -- ~0.1s of one interval after it), and its timing never moves.
        best.missed = 0
        best.hiddenSlot = bestIndex
        best.ticksSeen = best.ticksSeen + 1
        local nextTickAt = best.appliedAt + (bestIndex + 1) * best.interval
        if nextTickAt > best.nextTickAt then best.nextTickAt = nextTickAt end
        tickIndex = bestIndex
    else
        tickIndex = recordTick(best, 0, false, bestIndex, now)
    end
    best.confirmed, best.doubtful = true, nil
    meterCountTick(best, tickShape(best, tickIndex) * (best.curseNow or 1), tickIndex)
    trace(string.format("TICK %s (amount hidden) on %s (tick %d/%d)%s", bestName, unit, tickIndex, best.totalTicks,
        wasWaiting and ", now shown" or ""))
    if wasWaiting then return key end
end

local unitCombatSeen = 0 -- the first few UNIT_COMBAT events are logged as they come, to see what the client hides
local function onUnitCombat(unit, action, flag, amount, school)
    if combatLog.active then return end -- the combat log does this exactly (TBC)
    if unitCombatSeen < 8 and (unit == "target" or (type(unit) == "string" and unit:find("^nameplate"))) then
        unitCombatSeen = unitCombatSeen + 1
        local function show(v) if isSecret(v) then return "SECRET" end return tostring(v) end
        trace(string.format("UNIT_COMBAT %s action=%s flag=%s amount=%s school=%s", tostring(unit), show(action),
            show(flag), show(amount), show(school)))
    end
    if isSecret(action) then return end
    -- A fully absorbed tick still landed (a shield ate it): it proves the DoT is on and keeps its rhythm, so ABSORB
    -- matches like WOUND, but a 0 never feeds tick sizes. With two DoTs it could be, it's ignored.
    local absorbed = action == "ABSORB"
    if not AVOIDED_ACTIONS[action] and action ~= "WOUND" and not absorbed then return end
    local key = unitKey(unit)
    if not key then return end
    if AVOIDED_ACTIONS[action] then return onAvoided(key, action, school) end
    if action == "WOUND" or absorbed then onHit(key, school) end
    -- Forever's live client hides the amount (seen in-game, 2026-11-05: "amount=SECRET school=4"). The school and
    -- timing are still readable, so the hit is matched to a DoT by those alone: the DoT keeps its rhythm and counts
    -- down instead of being dropped as "never ticked". Its size can't be learned, so the estimate stays at the
    -- tooltip's or an earlier learned size.
    if isSecret(amount) and not isSecret(school) and type(school) == "number" and action == "WOUND" then
        return onHiddenTick(key, unit, school)
    end
    if isSecret(amount) or isSecret(school) or type(amount) ~= "number" then return end
    local isCrit = not isSecret(flag) and flag == "CRITICAL"
    if not dotsByTarget[key] and not armedTrap then return end
    local dots = dotsByTarget[key] or {}

    -- The same hit fires for target, nameplateN, softenemy...: handle it once (see combatFrameHits above).
    local now = GetTime()
    if combatFrameAt ~= now then
        combatFrameHits = {}
        combatFrameAt = now
    end
    local signature = key .. ":" .. amount .. ":" .. school
    local hit = combatFrameHits[signature]
    if hit then
        if hit.unit ~= unit then return end
    else
        hit = { unit = unit, fed = {} }
        combatFrameHits[signature] = hit
    end
    local lastCombatFed = hit.fed

    local best, bestName, bestDistance, bestIndex
    local zeroAbsorb = absorbed and amount == 0
    local candidates = 0
    for name, dot in pairs(dots) do
        if not lastCombatFed[name] and dot.school == school
            and (zeroAbsorb or plausibleTickAmount(dot, amount, isCrit, tickNumberAt(dot, now))) then
            local distance, index = distanceToExpectedTick(dot, now)
            local window = dot.firstTickAt and TICK_MATCH_WINDOW_ANCHORED or TICK_MATCH_WINDOW
            -- Each tick slot takes one hit: a second hit near an already-matched tick is someone else's.
            local freshSlot = not dot.firstTickAt or index > dot.lastTickIndex
            if freshSlot and distance <= window then
                candidates = candidates + 1
                if not bestDistance or distance < bestDistance then
                    best, bestName, bestDistance, bestIndex = dot, name, distance, index
                end
            end
        end
    end
    -- A zero absorb has no size to distinguish two same-school DoTs.
    if zeroAbsorb and candidates ~= 1 then return end
    if not best then
        -- Not a tick as things stand; it may still correct one (same-slot swap, or a wrong learned size).
        for name, dot in pairs(dots) do
            if not lastCombatFed[name] and dot.school == school then
                local distance, index = distanceToExpectedTick(dot, now)
                local wasWaiting = isWaiting(dot)
                if trySwapSameSlot(dot, name, amount, isCrit, now) then
                    lastCombatFed[name] = true
                    return
                end
                if tryRelearn(dot, name, amount, isCrit, index, distance, now) then
                    lastCombatFed[name] = true
                    return wasWaiting and key or nil
                end
            end
        end
        -- Returned like a waiting DoT's first tick: the trap's DoT shows (and flashes) from now.
        if springTrap(key, unit, amount, school, isCrit, now) then return key end
        trace(string.format("HIT %d%s school %d on %s not matched to a DoT", amount, isCrit and " (crit)" or "",
            school, unit))
        return
    end

    local wasWaiting = isWaiting(best)
    local tickIndex, factor = recordTick(best, amount, isCrit, bestIndex, now)
    lastCombatFed[bestName] = true
    trace(string.format("TICK %s %d%s on %s (tick %d/%d, expecting %.1f for this tick)%s", bestName, amount,
        isCrit and " CRIT" or "", unit, tickIndex, best.totalTicks, shapedTick(best, expectedTick(best), factor),
        wasWaiting and ", now shown" or ""))
    if wasWaiting then return key end
end

-- Whether hits on a mob reach the addon right now. UNIT_COMBAT only reports unit tokens (the target, focus and
-- visible nameplates), so a mob you tabbed away from, with nameplates off or out of their range, ticks unseen.
-- Its DoTs used to be dropped as "never ticked", which lost every earlier mob when chain pulling.
local function isObservable(key)
    if combatLog.active then return true end -- the combat log reports every mob, seen or not
    if unitKey("target") == key or unitKey("focus") == key then return true end
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) and unitKey(unit) == key then return true end
    end
    return false
end

-- Accuracy report (TBC port): when a DoT ends, what it was predicted to deal when it landed vs what it really
-- dealt, and the per-tick size each came from. Kept in db.accuracy (last 20); /did accuracy prints them.
local MAX_ACCURACY = 20
local function noteAccuracy(dot, name, how)
    if not dot.predictedAt or dot.channel or (dot.ticksSeen or 0) == 0 or dot.sizeHidden then return end
    local dealt = dot.dealt or 0
    -- Off by: too high as a share of the prediction, too low as a share of what it really dealt (so a prediction
    -- of half the real damage reads "50% too low", never "-100%").
    local high = dot.predictedAt >= dealt
    local base = high and dot.predictedAt or dealt
    local diff = base > 0 and math.floor(math.abs(dot.predictedAt - dealt) / base * 100 + 0.5) or 0
    local real = dot.ticksSeen > 0 and dealt / dot.ticksSeen or 0
    local line = string.format("%s: predicted %d, dealt %d (%d%% too %s), ticks %d/%d, start per-tick %s, real %.1f, %s",
        name, dot.predictedAt, dealt, diff, high and "high" or "low", dot.ticksSeen,
        dot.totalTicks, dot.startPerTick and string.format("%.1f", dot.startPerTick) or "?", real, how)
    if (dot.resisted or 0) > 0 then line = line .. string.format(", %d resisted by the mob", dot.resisted) end
    trace("ACCURACY " .. line)
    db.accuracy = db.accuracy or {}
    table.insert(db.accuracy, date("%H:%M") .. " " .. line)
    while #db.accuracy > MAX_ACCURACY do table.remove(db.accuracy, 1) end
end

local function housekeep(now)
    for key, dots in pairs(dotsByTarget) do
        for name, dot in pairs(dots) do
            local late = (dot.ticksSeen == 0 and dot.travel) or 0
            while dot.nextTickAt < now - TICK_MATCH_WINDOW - late and dot.nextTickAt <= dot.expiresAt do
                dot.nextTickAt = dot.nextTickAt + dot.interval
                -- Only a tick that could have been seen counts as missed.
                -- A DoT the combat log saw land stays until it reports the aura removed (TBC).
                -- (Not a channel: it's on while the game says you're channelling it, and on Forever its ticks are
                -- hidden and never matched, so it "missed" two and was dropped halfway through Drain Life.)
                if dot.ticksSeen == 0 and not dot.confirmed and not dot.channel and isObservable(key) then
                    dot.missed = dot.missed + 1
                end
            end
            if now > dot.expiresAt + TICK_MATCH_WINDOW then
                dots[name] = nil
                trace("EXPIRE " .. name)
                noteAccuracy(dot, name, "ran out")
            elseif dot.ticksSeen == 0 and dot.missed >= MISSED_TICKS_BEFORE_DROP then
                dot.discarded = true
                dots[name] = nil
                trace("DROP " .. name .. " never ticked (resisted or immune?)")
            end
        end
        if next(dots) == nil then dotsByTarget[key] = nil end
    end
    if castInProgress then
        if castInProgress.stoppedAt and now - castInProgress.stoppedAt > CAST_STOP_GRACE then
            dropCastInProgress("stopped without succeeding")
        elseif now - castInProgress.startedAt > CAST_MAX_SECONDS then
            dropCastInProgress("never finished")
        end
    end
end

local function remainingDamage(dot)
    if dot.channelEndsAt then
        -- A channel only ticks until it ends (pushback moves that); a tick due after the end never comes.
        -- Its ticks come every interval from the start of the channel; the last lands right at the end. Counted from
        -- that schedule, not from when the last tick was seen: ticks are seen a moment late, and expecting the next
        -- from then pushed the last one past the end, so Drain Life left the marker a tick early.
        local endsAt = math.min(dot.expiresAt, dot.channelEndsAt)
        local start, interval = dot.channelStart or dot.appliedAt, dot.interval
        local total = math.floor((endsAt - start) / interval + 0.05)
        local now = GetTime()
        local due = 0 -- ticks whose time hasn't come yet (one just due but not yet seen isn't counted: cautious)
        for k = 1, total do
            if start + k * interval > now then due = due + 1 end
        end
        local left = math.max(0, math.min(total - (dot.ticksSeen or 0), due))
        return left * expectedTick(dot)
    end
    if dot.nextTickAt > dot.expiresAt + dot.interval / 2 then return 0 end
    local ticksLeft = math.floor((dot.expiresAt - dot.nextTickAt) / dot.interval + 0.5) + 1
    if not dot.shape then return ticksLeft * expectedTick(dot) end
    local average, total = expectedTick(dot), 0
    for number = math.max(1, dot.totalTicks - ticksLeft + 1), dot.totalTicks do
        total = total + shapedTick(dot, average, tickShape(dot, number))
    end
    return total
end
ns.remainingDamageOf = remainingDamage -- recordTick, defined above, needs it

-- Remaining damage per DoT on a mob (by unitKey), oldest application first. DoTs still waiting for their first
-- tick are left out. A DoT being cast on the mob replaces the one of the same name it would refresh.
local function dotBreakdown(key, unit)
    scanCurses(unit, key)
    local dots = key and dotsByTarget[key]
    local cast = key and castInProgress and castInProgress.key == key and castInProgress or nil
    local list = {}
    if not dots and not cast then return list end
    for name, dot in pairs(dots or {}) do
        dot.curseNow = curseMultiplier(key, dot.school)
        if not isWaiting(dot) and not (cast and name == cast.name) then
            table.insert(list, { name = name, school = dot.school, appliedAt = dot.appliedAt,
                damage = remainingDamage(dot) * dot.curseNow })
        end
    end
    if cast and not isWaiting(cast.dot) then
        cast.dot.curseNow = curseMultiplier(key, cast.dot.school)
        table.insert(list, { name = cast.name, school = cast.dot.school, appliedAt = cast.dot.appliedAt,
            damage = remainingDamage(cast.dot) * cast.dot.curseNow, provisional = true })
    end
    table.sort(list, function(a, b) return a.appliedAt < b.appliedAt end)
    return list
end

-- Returns what the target's DoTs still have to deal, how many DoTs count toward it, and the per-DoT
-- breakdown (see dotBreakdown).
local function targetRemainingDamage()
    local list = dotBreakdown(unitKey("target"), "target")
    local total = 0
    for _, entry in ipairs(list) do total = total + entry.damage end
    return math.floor(total + 0.5), #list, list
end

---------------------------------------------------------------------------
-- TBC: the combat log
---------------------------------------------------------------------------
-- Where the client allows COMBAT_LOG_EVENT_UNFILTERED (TBC does; Forever doesn't), every tick, miss, aura
-- application and removal of the player's spells is reported with its spell name and the mob's GUID, whether or
-- not the mob is the target or has a nameplate. So nothing has to be guessed from school, size and timing:
--   * SPELL_PERIODIC_DAMAGE / _MISSED  -> that DoT's tick (absorbed and resisted ticks keep its rhythm)
--   * SPELL_AURA_APPLIED / _REFRESH    -> it really landed; its clock starts here (projectile travel included)
--   * SPELL_MISSED right after a cast  -> it didn't land (a recast's earlier DoT is put back); IMMUNE only makes
--                                         it wait for a tick (Pounce's stun can be immune while its bleed lands)
--   * SPELL_AURA_REMOVED, UNIT_DIED    -> it's gone (dispelled, broken, expired early, mob dead)
-- Description parsing still gives each DoT's duration, tick count and first estimate; ticks teach the real size.
do
    -- Tick or aura names that differ from the cast's name.
    local TICK_NAME_ALIASES = {
        ["Pounce Bleed"] = "Pounce",
        ["Immolation Trap Effect"] = "Immolation Trap",
    }
    -- Learned on the spot for other client languages: an unknown debuff name landing right after a DoT cast.
    local learnedAliases = {}
    -- How long after its cast a DoT's own miss or aura may arrive (projectiles travel).
    local CAST_RESULT_SECONDS = 2.5
    local playerGUID

    -- The name a combat log spell name is tracked under on a mob, or nil.
    local function dotName(dots, spellName)
        if not dots or type(spellName) ~= "string" then return nil end
        if dots[spellName] then return spellName end
        local alias = TICK_NAME_ALIASES[spellName] or learnedAliases[spellName]
        if alias and dots[alias] then return alias end
    end

    local function dropIfEmpty(key)
        local dots = dotsByTarget[key]
        if dots and next(dots) == nil then dotsByTarget[key] = nil end
    end

    -- Returns true when a DoT starts showing (a sprung trap).
    local function onAuraApplied(key, spellName, school, now)
        local dots = dotsByTarget[key]
        local name = dotName(dots, spellName)
        local cast = lastDotCast
        if not name and dots and cast and cast.key == key and now - cast.at <= CAST_RESULT_SECONDS
            and dots[cast.name] == cast.dot and not cast.dot.confirmed and cast.dot.school == school
            and type(spellName) == "string" and not IGNORED_SPELLS[spellName] then
            learnedAliases[spellName] = cast.name
            name = cast.name
            trace(string.format("LOG debuff %s belongs to %s", spellName, cast.name))
        end
        if name then
            local dot = dots[name]
            if dot.ticksSeen == 0 and not dot.confirmed and now - dot.appliedAt <= CAST_RESULT_SECONDS then
                -- Its clock starts when it lands, not when it was cast (Serpent Sting, Fireball, Pyroblast travel).
                dot.appliedAt, dot.expiresAt, dot.nextTickAt = now, now + dot.duration, now + dot.interval
                dot.travel = nil
            end
            dot.confirmed, dot.doubtful = true, nil
            if not dot.predictedAt and dot.ticksSeen == 0 then
                dot.predictedAt = math.floor(remainingDamage(dot) + 0.5)
                dot.startPerTick = expectedTick(dot)
            end
            return false
        end
        -- Immolation Trap: the player's trap puts its debuff on whoever springs it.
        local trap = armedTrap
        if trap and now <= trap.expiresAt + 1 and type(spellName) == "string"
            and (spellName == trap.name or TICK_NAME_ALIASES[spellName] == trap.name
                or (school == trap.school and spellName:find(trap.name, 1, true))) then
            armedTrap = nil
            local dot = newDot(trap.spellID, trap.spellID, trap.name, trap.total, trap.school, trap.duration,
                trap.interval, now)
            dot.confirmed = true
            dotsByTarget[key] = dotsByTarget[key] or {}
            dotsByTarget[key][trap.name] = dot
            if spellName ~= trap.name then learnedAliases[spellName] = trap.name end
            trace(string.format("TRAP %s sprung on %s (log)", trap.name, tostring(key)))
            return true
        end
        return false
    end

    -- Returns true when the DoT was waiting for this tick (it shows from now).
    local function onPeriodic(key, spellName, amount, absorbed, isCrit, now, resisted)
        local dots = dotsByTarget[key]
        local name = dotName(dots, spellName)
        if not name then return false end
        local dot = dots[name]
        local wasWaiting = isWaiting(dot)
        local _, index = distanceToExpectedTick(dot, now)
        if dot.firstTickAt and index <= (dot.lastTickIndex or 0) then index = dot.lastTickIndex + 1 end
        -- Absorbed and partly resisted damage still came from the DoT: count it toward the tick size it learns, so
        -- an unlucky run of resists isn't learned as the spell's real size.
        local size = (tonumber(amount) or 0) + (tonumber(absorbed) or 0) + (tonumber(resisted) or 0)
        if not dot.predictedAt and dot.ticksSeen == 0 then
            dot.predictedAt = math.floor(remainingDamage(dot) + 0.5)
            dot.startPerTick = expectedTick(dot)
        end
        dot.dealtByLog = true
        dot.dealt = (dot.dealt or 0) + (tonumber(amount) or 0)
        dot.resisted = (dot.resisted or 0) + (tonumber(resisted) or 0) -- partial resists, for the accuracy report
        local tickIndex, factor = recordTick(dot, size, isCrit, index, now)
        dot.confirmed, dot.doubtful = true, nil
        trace(string.format("TICK %s %d%s (log, tick %d/%d, expecting %.1f for this tick)%s", name, size,
            isCrit and " CRIT" or "", tickIndex, dot.totalTicks, shapedTick(dot, expectedTick(dot), factor),
            wasWaiting and ", now shown" or ""))
        return wasWaiting
    end

    -- Returns true when a DoT was removed.
    local function onCastMissed(key, spellName, missType, now)
        if missType == "ABSORB" or missType == "BLOCK" then return false end -- it landed, partly soaked
        local dots = dotsByTarget[key]
        local name = dotName(dots, spellName)
        if not name then return false end
        local dot = dots[name]
        if dot.ticksSeen > 0 or now - dot.appliedAt > CAST_RESULT_SECONDS then return false end
        if missType == "IMMUNE" then
            -- One part of the spell may be immune while the DoT lands: wait for a tick to prove it.
            if not dot.confirmed then dot.doubtful = true end
            trace(string.format("LOG %s IMMUNE: waiting for its first tick", name))
            return true
        end
        local cast = lastDotCast
        if cast and cast.dot == dot and cast.previous then
            dots[name] = cast.previous
            trace(string.format("LOG %s %s: recast didn't land, keeping the earlier one", name, tostring(missType)))
        else
            dots[name] = nil
            trace(string.format("LOG %s %s: dropped", name, tostring(missType)))
        end
        if cast and cast.dot == dot then lastDotCast = nil end
        dropIfEmpty(key)
        return true
    end

    local function onAuraRemoved(key, spellName, now)
        local dots = dotsByTarget[key]
        local name = dotName(dots, spellName)
        if not name then return false end
        local dot = dots[name]
        -- A fresh recast may already stand where the old aura's removal arrives.
        if not dot.confirmed and now - dot.appliedAt <= CAST_RESULT_SECONDS then return false end
        dots[name] = nil
        trace(string.format("LOG %s removed from %s", name, tostring(key)))
        noteAccuracy(dot, name, dot.ticksSeen >= dot.totalTicks and "ran its course" or "removed early (mob died or debuff replaced; not a miss)")
        dropIfEmpty(key)
        return true
    end

    -- Returns "reveal" (a DoT started showing), "refresh" (something changed) or nil, and the mob's key.
    function combatLog.onEvent()
        local _, sub, _, sourceGUID, _, _, _, destGUID, _, _, _, _, spellName, school, a15, _, a17, a18, _, a20, a21 =
            CombatLogGetCurrentEventInfo()
        if not destGUID then return end
        if sub == "UNIT_DIED" or sub == "UNIT_DESTROYED" or sub == "PARTY_KILL" then
            if dotsByTarget[destGUID] then
                dotsByTarget[destGUID] = nil
                trace("LOG " .. tostring(destGUID) .. " died; its DoTs are gone")
                return "refresh", destGUID
            end
            return
        end
        playerGUID = playerGUID or UnitGUID("player")
        if sourceGUID ~= playerGUID then return end
        local now = GetTime()
        local result
        if sub == "SPELL_PERIODIC_DAMAGE" then
            result = onPeriodic(destGUID, spellName, a15, a20, a21 and true or false, now, a18) and "reveal"
        elseif sub == "SPELL_PERIODIC_MISSED" then
            result = onPeriodic(destGUID, spellName, 0, a15 == "ABSORB" and a17 or 0, false, now) and "reveal"
        elseif sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REFRESH" then
            if a15 ~= "DEBUFF" then return end
            result = onAuraApplied(destGUID, spellName, school, now) and "reveal" or "refresh"
        elseif sub == "SPELL_MISSED" then
            result = onCastMissed(destGUID, spellName, a15, now) and "refresh"
        elseif sub == "SPELL_AURA_REMOVED" then
            if a15 ~= "DEBUFF" then return end
            result = onAuraRemoved(destGUID, spellName, now) and "refresh"
        end
        return result or nil, destGUID
    end

    -- Registers the combat log where the client allows it. Returns whether it's in use.
    function combatLog.start(eventFrame)
        if type(CombatLogGetCurrentEventInfo) ~= "function" or ns.isForever then return false end
        local ok = pcall(eventFrame.RegisterEvent, eventFrame, "COMBAT_LOG_EVENT_UNFILTERED")
        combatLog.active = ok and true or false
        return combatLog.active
    end
end

---------------------------------------------------------------------------
-- Settings, and what the options window (Options.lua) needs
---------------------------------------------------------------------------

local function applyDefaults()
    -- v1.0.1: v1.0.0 started Forever with a marker fit (height 10, offset -4, left edge 5) that put the marker below
    -- the bar on the default UI. These options were new in v1.0.0, so the fit is reset once for everyone: the whole
    -- bar again. Anyone who needs a fit sets it again in the Marker tab.
    if not db.fitReset101 then
        db.markerHeight, db.markerOffsetY, db.markerInsetLeft, db.markerInsetRight = 0, 0, 0, 0
        db.fitReset101 = true
    end
    -- Forever: the damage meter learning in v1.2.0 could learn tick sizes too big (a tick it didn't pick out, or crits
    -- was still in the meter's total), so the skull showed on mobs that lived. Those sizes are forgotten once.
    -- Forever: v1.2.0 turned other addons' health text off by default there; it works (EllesmereUI, seen in-game), so
    -- it's back on once.
    -- v1.2.6: nameplates and focus used school colors by default, where Corruption and Agony are both purple:
    -- now every DoT has its own color everywhere (the same as on the target frame).
    if not db.dotColorsEach126 then
        if db.plateDotColors == "school" then db.plateDotColors = "each" end
        if db.focusDotColors == "school" then db.focusDotColors = "each" end
        db.dotColorsEach126 = true
    end
    if ns.isForever and not db.textAddonsOn124 then
        db.markerUnderTextAddons = true
        db.textAddonsOn124 = true
    end
    if ns.isForever and not db.meterReset126 then
        db.ticks, db.tickWeights, db.tickHistory, db.tickPower = {}, {}, {}, {}
        db.meterReset126 = true
    end
    -- Settings from earlier versions.
    if db.showMarkers == nil and db.showLine ~= nil then db.showMarkers = db.showLine end
    db.showLine, db.showRemaining = nil, nil
    db.showFullLine, db.lineThickness, db.lineColor = nil, nil, nil
    db.preview, db.previewPercent, db.previewOffInCombat = nil, nil, nil
    for key, value in pairs(DEFAULTS) do
        if db[key] == nil then db[key] = value end
    end
end

-- ns.db is set on ADDON_LOADED.
ns.DEFAULTS = DEFAULTS
ns.parseDot = parseDot -- tests

-- Learning from the damage meter after combat (see meterTally).
local LEARN_MIN_TICKS = 2                 -- at least two ticks' worth this combat
local LEARN_RATIO_MIN, LEARN_RATIO_MAX = 0.5, 2.5 -- real vs tooltip outside this: something else got mixed in
local LEARN_WEIGHT_CAP = 20               -- older fights count as at most this many ticks, so gear changes catch up
local METER_TRIES, METER_RETRY_SECONDS = 20, 0.5 -- the totals take a moment to show (and stop being hidden)

local function readableTable(v)
    if isSecret(v) or type(v) ~= "table" then return false end
    if type(canaccesstable) ~= "function" then return true end
    local ok, allowed = pcall(canaccesstable, v)
    return ok and allowed == true
end

-- The damage meter's rows for the combat that just ended: spellID -> total, or nil and why.
local function meterTotals()
    local DM = C_DamageMeter
    if type(DM) ~= "table" or type(DM.GetCombatSessionSourceFromType) ~= "function" then return nil, "no damage meter" end
    if type(DM.IsDamageMeterAvailable) == "function" then
        local ok, available = pcall(DM.IsDamageMeterAvailable)
        if ok and available == false then return nil, "switched off" end
    end
    local dmgType = Enum and Enum.DamageMeterType and Enum.DamageMeterType.DamageDone or 0
    local current = Enum and Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Current or 1
    local ok, totals, why = pcall(function()
        local src = DM.GetCombatSessionSourceFromType(current, dmgType, UnitGUID("player"))
        if not readableTable(src) or not readableTable(src.combatSpells) then return nil, "wait" end
        local list = src.combatSpells
        local n = #list
        if isSecret(n) or type(n) ~= "number" or n == 0 then return nil, "wait" end
        local found = {}
        for i = 1, n do
            local row = list[i]
            if readableTable(row) then
                if isSecret(row.totalAmount) or isSecret(row.spellID) then return nil, "wait" end
                if type(row.totalAmount) == "number" then found[row.spellID] = row.totalAmount end
            end
        end
        return found
    end)
    if not ok then return nil, "unreadable" end
    return totals, why
end

-- On Forever DoT ticks can crit (seen: Immolate ticks of 50, and 75 critical), and the meter's total includes the
-- crits. The skull shouldn't count on crits (no false skulls), so the learned size is the normal hit: the average
-- with the player's spell crit chance taken out (crits x1.5). Unknown or hidden crit chance: left as is.
local SCHOOL_CRIT_INDEX = { [2] = 2, [4] = 3, [8] = 4, [16] = 5, [32] = 6, [64] = 7 }
local function critShare(school)
    local index = SCHOOL_CRIT_INDEX[school]
    if not index or type(GetSpellCritChance) ~= "function" then return 0 end
    local ok, chance = pcall(GetSpellCritChance, index)
    if not ok or isSecret(chance) or type(chance) ~= "number" or chance <= 0 or chance > 60 then return 0 end
    return chance / 100
end

local function learnFromMeter(totals, tally, untracked)
    db.tickWeights = db.tickWeights or {}
    local perSpell = {}
    for _, t in pairs(tally) do perSpell[t.spellID] = (perSpell[t.spellID] or 0) + 1 end
    for key, t in pairs(tally) do
        -- A tick the addon didn't pick out still went into the meter's total: dividing by too few ticks made
        -- the size too big (seen: Corruption learned 132, real ticks 112). Every tick up to the last one seen
        -- landed (the mob was alive then), so those count even when one was missed.
        -- Also every tick due while the mob was still taking damage (seen: Bane of Agony learned from 1-2
        -- picked-out ticks when the meter held 7-8: "448 is 9.36x the tooltip").
        local due, dueCount = 0, 0
        for _, dot in ipairs(t.dots) do
            if dot.channel then
                -- Ticks every interval from the channel's start, until it stopped (or ran out).
                local stoppedAt = math.min(dot.channelStoppedAt or GetTime(), dot.channelEndsAt or math.huge)
                local landed = math.floor((stoppedAt - (dot.channelStart or dot.appliedAt)) / dot.interval + 0.05)
                landed = math.max(0, math.min(landed, dot.totalTicks))
                due = due + landed * (dot.curseNow or 1)
                dueCount = dueCount + landed * (dot.curseNow or 1)
            elseif not dot.discarded then
                local lastTick = dot.meterLastTick or 0
                local alive = dot.key and lastHitAt[dot.key]
                if alive and dot.appliedAt and dot.interval then
                    local untilAt = math.min(alive + 0.5, dot.replacedAt or math.huge, dot.expiresAt + 0.5)
                    local first = dot.firstTickAt or (dot.appliedAt + dot.interval)
                    if untilAt >= first then
                        lastTick = math.max(lastTick, math.floor((untilAt - first) / dot.interval) + 1)
                    end
                end
                for i = 1, math.min(lastTick, dot.totalTicks) do
                    due = due + tickShape(dot, i) * (dot.curseNow or 1)
                    dueCount = dueCount + (dot.curseNow or 1)
                end
            end
        end
        local count = t.ticks
        if due > t.factors then
            trace(string.format("LEARN %s: %d tick(s) picked out, %.1f were due: using the due ticks", t.name, t.ticks, due))
            t.factors, count = due, dueCount
        end
        local skip
        if t.factors < LEARN_MIN_TICKS then skip = t.ticks > 0 and string.format("only %d tick(s) counted", t.ticks) or ""
        elseif t.unclear then skip = "its upfront hit can't be told apart in this language"
        elseif #t.dots == 0 then skip = "not cast this combat"
        elseif untracked[t.spellID] then skip = "a cast had no known target"
        elseif not totals[t.spellID] then skip = "no damage meter total"
        elseif perSpell[t.spellID] > 1 then skip = "several combo point sizes share one total"
        else
            for _, dot in ipairs(t.dots) do
                -- (A cast that was missed, resisted or replaced before it landed did no damage: it doesn't count.)
                if dot.ticksSeen == 0 and not dot.discarded and not dot.channel then
                    skip = "a cast showed no ticks (out of sight, or the mob died first)"
                end
            end
        end
        if skip then
            if skip ~= "" then trace(string.format("LEARN %s skipped: %s", t.name, skip)) end
        else
            local total = totals[t.spellID]
            local ratio = total / (t.direct + t.descTick * t.factors)
            -- Agony: only the tooltip's base ramps up, the spell power bonus is the same on every tick (see
            -- shapedTick). Scaling the whole total by the ramp made fights that ended early (small ticks only)
            -- learn far too much. Bonus per tick = what's left after the ramped base, over the ticks.
            if t.shaped and count > 0 then
                ratio = (t.descTick + (total - t.direct - t.descTick * t.factors) / count) / t.descTick
            end
            if ratio < LEARN_RATIO_MIN or ratio > LEARN_RATIO_MAX then
                trace(string.format("LEARN %s skipped: damage meter %d is %.2fx the tooltip (%d tick(s) picked out, %.1f due, tooltip %.1f a tick)",
                    t.name, total, ratio, t.ticks, t.factors, t.descTick))
            else
                local crit = critShare(t.school)
                local tick = ratio * t.descTick / (1 + crit * 0.5)
                if crit > 0 then trace(string.format("LEARN %s: %.1f%% spell crit taken out", t.name, crit * 100)) end
                local old = db.ticks[key]
                local weight = old and math.min(db.tickWeights[key] or 0, LEARN_WEIGHT_CAP) or 0
                db.ticks[key] = math.floor(((old or 0) * weight + tick * t.factors) / (weight + t.factors) * 10 + 0.5) / 10
                db.tickWeights[key] = weight + t.factors
                if db.tickPower then db.tickPower[key] = nil end
                db.tickHistory = db.tickHistory or {}
                db.tickHistory[key] = { { avg = db.ticks[key] } } -- the cautious estimate starts from this
                trace(string.format("LEARN %s: damage meter %d over %d tick(s) = %.1f per tick (tooltip %.1f), saved %.1f",
                    t.name, total, t.ticks, tick, t.descTick, db.ticks[key]))
            end
        end
    end
end
ns.learnFromMeter = learnFromMeter -- tests

local function learnAfterCombat(tally, untracked, triesLeft)
    if InCombatLockdown() then
        trace("LEARN skipped: a new fight started before the damage meter could be read")
        return
    end
    local totals, why = meterTotals()
    if not totals and why == "wait" and triesLeft > 0 then
        C_Timer.After(METER_RETRY_SECONDS, function() learnAfterCombat(tally, untracked, triesLeft - 1) end)
        return
    end
    if not totals then
        trace("LEARN skipped: damage meter " .. (why == "wait" and "still empty or hidden" or tostring(why)))
        return
    end
    learnFromMeter(totals, tally, untracked)
end

local meterFrame = CreateFrame("Frame")
meterFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
meterFrame:SetScript("OnEvent", function()
    local tally, untracked = meterTally, meterUntracked
    meterTally, meterUntracked = {}, {}
    if not db or not ns.isForever or next(tally) == nil then return end
    C_Timer.After(METER_RETRY_SECONDS, function() learnAfterCombat(tally, untracked, METER_TRIES) end)
end)
-- Health for the kill icon's bar, never zero; a secret value (Forever) goes to the bar as it is, since it can't be
-- compared.
function ns.atLeast(health)
    if isSecret(health) or type(health) ~= "number" then return health end
    return math.max(health, 0.01)
end

-- Casts waiting for their tooltip text (see DESC_WAIT_SECONDS).
local descWaiter = CreateFrame("Frame")
descWaiter:SetScript("OnUpdate", function()
    local pending = pendingDesc
    if not pending then return end
    if GetTime() - pending.at > DESC_WAIT_SECONDS then
        pendingDesc = nil
        trace("DROP a cast whose tooltip never loaded")
        return
    end
    local ok, _, desc = pcall(spellNameAndDescription, pending.spellID)
    if ok and type(desc) == "string" and desc ~= "" then
        pendingDesc = nil
        onPlayerCast(pending.spellID, nil, pending.key)
    end
end)
ns.lists = { waitModes = WAIT_MODES } -- Display.lua adds the look lists
-- What Display.lua needs from the tracking above.
ns.tracking = { housekeep = housekeep, targetRemainingDamage = targetRemainingDamage, unitKey = unitKey }

-- The DoTs on the mob behind `unit` (e.g. "nameplate3"): per-DoT breakdown and total remaining damage.
function ns.dotBreakdownForUnit(unit)
    local list = dotBreakdown(unitKey(unit), unit)
    local total = 0
    for _, entry in ipairs(list) do total = total + entry.damage end
    return list, total
end
ns.print = print
ns.trace = trace

function ns.resetLearnedTicks()
    wipe(db.ticks)
    if db.tickPower then wipe(db.tickPower) end
    if db.tickHistory then wipe(db.tickHistory) end
    print("Learned tick sizes cleared.")
end

function ns.forgetLearnedTick(key)
    db.ticks[key] = nil
    if db.tickPower then db.tickPower[key] = nil end
    if db.tickHistory then db.tickHistory[key] = nil end
    trace("FORGET learned tick size for " .. tostring(key))
end

-- The options window's list of learned tick sizes: per entry its key in db.ticks, spellID, comboPoints (finishers,
-- whose keys are "spellIDxN"), perTick, and when the client has them the spell's name and what its description
-- predicts (tooltipPerTick, ticks, interval, duration, school). Shaped DoTs (Agony) learn their average tick.
-- Sorted by name, then combo points.
function ns.learnedTickList()
    local list = {}
    for key, perTick in pairs(db.ticks) do
        local spellID, points = key, nil
        if type(key) == "string" then
            local id, n = key:match("^(%d+)x(%d+)$")
            spellID, points = tonumber(id), tonumber(n)
        end
        if type(spellID) == "number" and type(perTick) == "number" then
            local entry = { key = key, spellID = spellID, comboPoints = points, perTick = perTick }
            local ok, name, desc = pcall(spellNameAndDescription, spellID)
            if ok and type(name) == "string" and not isSecret(name) then entry.name = name end
            if ok and entry.name and type(desc) == "string" and not isSecret(desc) then
                local total, school, duration, stated = parseDot(desc, points or 1)
                if total then
                    local interval = stated or KNOWN_TICK_INTERVALS[name] or DEFAULT_TICK_INTERVAL
                    entry.ticks = math.max(1, math.floor(duration / interval + 0.5))
                    entry.interval, entry.duration = interval, duration
                    entry.school = SCHOOL_BY_NAME[name] or school
                    entry.tooltipPerTick = total / entry.ticks
                end
            end
            entry.color = entry.school and ns.display.schoolColors[entry.school]
            table.insert(list, entry)
        end
    end
    table.sort(list, function(a, b)
        local an, bn = a.name or ("~" .. a.spellID), b.name or ("~" .. b.spellID)
        if an ~= bn then return an < bn end
        return (a.comboPoints or 0) < (b.comboPoints or 0)
    end)
    return list
end


---------------------------------------------------------------------------
-- FlareUI: starting the tracking
-- In place of the addon's ADDON_LOADED, options window, slash commands and version check. Nothing is registered
-- and nothing runs until FlareUI's DoT Tracker module starts it (Modules/DotTracker.lua) with the table its
-- learned tick sizes and accuracy options live in. Drawing is FlareUI's: ns.refresh and ns.playFlash are its hooks.
---------------------------------------------------------------------------

local frame = CreateFrame("Frame")
local started = false

function ns.start(saved)
    if started or type(saved) ~= "table" then return end
    started = true
    db = saved
    if db.version ~= DB_VERSION then
        db.ticks, db.intervals, db.version = nil, nil, DB_VERSION
    end
    db.ticks = db.ticks or {}
    db.log = {}          -- (this session's trace: saved with the character, for "the estimate was wrong" reports)
    db.shapeModel = 2
    applyDefaults()
    ns.db = db
    trace("===== session start =====")
    local added = ns.locale.addClientNames(NAME_TABLES, function(spellID)
        local name
        if C_Spell and C_Spell.GetSpellName then name = C_Spell.GetSpellName(spellID)
        elseif GetSpellInfo then name = GetSpellInfo(spellID) end
        if name and not isSecret(name) and type(name) == "string" then return name end
    end)
    if #added > 0 then trace("NAMES from this client: " .. table.concat(added, ", ")) end
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")    -- custom target frames (Frames.lua) exist by then
    frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")   -- combo points, before a finisher spends them
    frame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")  -- channels (Drain Life...), see channels
    frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
    frame:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")   -- keeps a recent combo point reading as backup
    frame:RegisterEvent("UNIT_COMBAT")
    frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")   -- plate tokens stand in for secret GUIDs (see plateTokenFor)
    frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    frame:RegisterEvent("PLAYER_LOGOUT")
end

-- The trace log is saved with the character (the last MAX_TRACE_LINES lines of the session), so a fight that
-- went wrong can be read back from the saved file after a /reload: nobody can type a command mid-fight.
function ns.stop() end

function ns.isStarted() return started end

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGOUT" then
        ns.stop()
        return
    elseif not db then
        return

    elseif event == "PLAYER_ENTERING_WORLD" then

    elseif event == "PLAYER_TARGET_CHANGED" then
        dotsByTarget.target = nil -- only used when the target's GUID is secret
        resetComboCount() -- combo points belong to the target they were built on
        dropCastInProgress("target changed")
        trace("TARGET changed to " .. (unitKey("target") or "none"))
        ns.refresh()

    elseif event == "UNIT_SPELLCAST_SENT" then
        local _, targetName, castGUID, spellID = ...
        onCastSent(spellID, castGUID, targetName)

    elseif event == "UNIT_POWER_FREQUENT" then
        local _, powerType = ...
        if not isSecret(powerType) and powerType == "COMBO_POINTS" then rememberComboPoints() end

    elseif event == "UNIT_SPELLCAST_START" then
        local _, castGUID, spellID = ...
        if onCastStart(castGUID, spellID) then ns.refresh() end

    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_INTERRUPTED" then
        local _, castGUID, spellID = ...
        if onCastEnded(event, castGUID, spellID) then ns.refresh() end

    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        local _, castGUID, spellID = ...
        local key = channels.start(castGUID, spellID)
        if key then
            ns.refresh()
            if key == unitKey("target") then ns.playFlash() end
        end

    elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        if channels.update() then ns.refresh() end

    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        if channels.stop("ended") then ns.refresh() end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local _, castGUID, spellID = ...
        onCastSucceeded(castGUID, spellID)
        local appliedTo, waiting = onPlayerCast(spellID, castGUID)
        ns.refresh()
        -- A DoT waiting for its first tick isn't drawn yet; it flashes when that tick lands instead.
        if appliedTo and not waiting and appliedTo == unitKey("target") then ns.playFlash() end

    elseif event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" then
        -- A plate token goes to the next mob that gets a plate: DoTs keyed by it belonged to the old one.
        local token = ...
        if type(token) == "string" and not isSecret(token) and dotsByTarget["plate:" .. token] then
            dotsByTarget["plate:" .. token] = nil
            trace("PLATE " .. token .. (event == "NAME_PLATE_UNIT_REMOVED" and " removed" or " reused")
                .. ": its DoTs were for the mob it showed before")
            ns.refresh()
        end

    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local result, key = combatLog.onEvent()
        if result and key == unitKey("target") then
            ns.refresh()
            if result == "reveal" then ns.playFlash() end
        end

    elseif event == "UNIT_COMBAT" then
        local revealed = onUnitCombat(...)
        if revealed and revealed == unitKey("target") then
            ns.refresh()
            ns.playFlash()
        end
    end
end)


local sinceUpdate = 0
frame:SetScript("OnUpdate", function(self, elapsed)
    if not db then return end
    sinceUpdate = sinceUpdate + elapsed
    if sinceUpdate < UPDATE_INTERVAL then return end
    sinceUpdate = 0
    housekeep(GetTime())
    ns.timed("refresh", ns.refresh)
end)
