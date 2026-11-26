-- Part of FlareUI's DoT tracker. Taken from Does It Die Advanced 1.3.7 by WhiteKnight / Smuggz_, itself based on
-- Does It Die by JoeGG (MIT License, Copyright (c) 2026 Joe Greive: LICENSES/DoesItDieAdvanced.txt), and changed for
-- FlareUI: its own namespace; nothing else.
-- DoesItDie: French (frFR) spell descriptions and names. Registers itself with Locale.lua.
-- Ported from PR #11 (gou-gouze). The French patterns only see descriptions the English and German ones didn't
-- read, and can't match their text (they need "points de dégâts", "points de vie", "Coup de grâce").
--
-- The wording is WoW: Forever's own French tooltips (Wowhead, data env Forever, locale fr), except the names
-- marked S below (standard Classic French, confirm in-game). Not verified on a French client yet. How it differs
-- from English:
--   * the school follows the amount, with varying case and connector: "40 points de dégâts d'Ombre en 12 sec",
--     "de Feu", "des Arcanes", "du Sacré"; no school is physical
--   * "sec" or plain "s" for seconds ("en 8 s" on Rupture)
--   * bleeds may be stated as health lost ("perd 15 points de vie en 9 sec", Pourfendre)

local _, flare = ...
local ns = flare.DotEngine -- the tracker's own namespace (Namespace.lua), apart from FlareUI's

local PHYSICAL = 1

-- Lower-cases a string and drops French accents, so school words match whatever the case and accents
-- ("Sacré"/"sacre", straight ' vs curly ’). UTF-8 bytes: \195\137 is É, \226\128\153 is ’.
local ACCENTS = {
    ["\195\137"] = "e", ["\195\169"] = "e", ["\195\136"] = "e", ["\195\168"] = "e", -- É é È è
    ["\195\138"] = "e", ["\195\170"] = "e", ["\195\139"] = "e", ["\195\171"] = "e", -- Ê ê Ë ë
    ["\195\128"] = "a", ["\195\160"] = "a", ["\195\130"] = "a", ["\195\162"] = "a", -- À à Â â
    ["\195\142"] = "i", ["\195\174"] = "i", ["\195\143"] = "i", ["\195\175"] = "i", -- Î î Ï ï
    ["\195\148"] = "o", ["\195\180"] = "o",                                         -- Ô ô
    ["\195\155"] = "u", ["\195\187"] = "u", ["\195\153"] = "u", ["\195\185"] = "u", -- Û û Ù ù
    ["\195\135"] = "c", ["\195\167"] = "c",                                         -- Ç ç
}
local function strip(s)
    s = s:gsub("\226\128\153", "'")
    s = s:gsub("\195[\128-\191]", ACCENTS)
    return s:lower()
end

-- The French client writes a non-breaking space (U+00A0 \194\160, or narrow U+202F \226\128\175) between the
-- number and "points" -- "78\194\160points de dégâts ..." -- which %s doesn't match, so the amount patterns miss
-- it (seen in-game: Immolation and Plaie d'agonie logged NOT READ, while Corruption, which uses an ordinary
-- space, worked). Immolation also reorders to "points supplémentaires de dégâts". Fix both before matching.
local function normalize(desc)
    desc = desc:gsub("\194\160", " "):gsub("\226\128\175", " ")
    desc = desc:gsub("points supplémentaires de dégâts", "points de dégâts supplémentaires")
    return desc
end

-- Accent-free stems of the school words, combined schools first.
local SCHOOL_STEMS = {
    { "givrefeu", 4 + 16 }, { "ombre", 32 }, { "arcane", 64 }, { "givre", 16 }, { "feu", 4 }, { "nature", 8 },
    { "sacr", 2 }, { "physique", 1 },
}
local function schoolOf(fragment)
    local f = strip(fragment)
    for _, pair in ipairs(SCHOOL_STEMS) do
        if f:find(pair[1], 1, true) then return pair[2] end
    end
    return PHYSICAL
end

-- French names of the spells in DoesItDie.lua's name-keyed tables. F: Forever's French tooltip; S: standard
-- Classic French name, confirm in-game. Names the client reports by spell ID are added at load anyway
-- (Locale.lua), so these mostly matter for spells without a known ID (Frostfire Bolt) and for the tests.
local NAMES = {
    ["Insect Swarm"] = { "Nuée d'insectes" },           -- S
    ["Bane of Agony"] = { "Plaie d'agonie" },           -- F (spell 980)
    ["Curse of Agony"] = { "Malédiction d'agonie" },    -- S
    ["Fireball"] = { "Boule de feu" },                  -- F
    ["Holy Fire"] = { "Flammes sacrées" },              -- F
    ["Rip"] = { "Déchirure" },                          -- F
    ["Siphon Life"] = { "Siphon de vie" },              -- F
    ["Serpent Sting"] = { "Morsure de serpent" },       -- F
    ["Pyroblast"] = { "Explosion pyrotechnique" },      -- F
    ["Frostfire Bolt"] = { "Trait de givrefeu" },       -- S (Forever's own spell)
    ["Rain of Fire"] = { "Pluie de feu" },              -- F
    ["Hellfire"] = { "Flammes infernales" },            -- F
    ["Flamestrike"] = { "Choc de flammes" },            -- F
    ["Consecration"] = { "Consécration" },              -- F
    ["Hurricane"] = { "Ouragan" },                      -- F
    ["Volley"] = { "Salve" },                           -- F
    ["Drain Life"] = { "Drain de vie" },                -- F
    ["Drain Soul"] = { "Siphon d'âme" },                -- F
    ["Drain Mana"] = { "Drain de mana" },               -- F
    ["Health Funnel"] = { "Captation de vie" },         -- F
    ["Mind Flay"] = { "Fouet mental" },                 -- F
    ["Arcane Missiles"] = { "Projectiles des arcanes" }, -- F
    ["Starshards"] = { "Éclats stellaires" },           -- F
    ["Immolation Trap"] = { "Piège immolation" },       -- S
    ["Explosive Trap"] = { "Piège explosif" },          -- S
    ["Wyvern Sting"] = { "Piqûre de wyverne" },         -- S
}

local function isFinisher(desc)
    desc = normalize(desc)
    return desc:find("Coup de grâce") ~= nil
end

-- Builders: "Vous gagnez 1 point de combo."
local function comboPointsAwarded(desc)
    desc = normalize(desc)
    return tonumber(desc:match("[Vv]ous gagnez%s+(%d+)%s*points? de combo"))
end

-- Finishers list a DoT per combo point: "1 point : 44 points de dégâts en 12 sec." (Déchirure),
-- "1 point : 25 points de dégâts en 8 s" (Rupture).
local function parseFinisher(desc, comboPoints)
    local byPoints, highest = {}, 0
    for pts, amount, secs in desc:gmatch("(%d+)%s*points?%s*:%s*(%d+)%s*points de dégâts en%s+(%d+%.?%d*)") do
        local points = tonumber(pts)
        byPoints[points] = { total = tonumber(amount), duration = tonumber(secs) }
        highest = math.max(highest, points)
    end
    if highest == 0 then return nil end
    local entry = byPoints[math.max(1, math.min(comboPoints, highest))] or byPoints[highest]
    return entry.total, PHYSICAL, entry.duration
end

local function parseDot(desc, comboPoints)
    desc = normalize(desc)
    if isFinisher(desc) then return parseFinisher(desc, comboPoints or 5) end
    -- Weapon enchants (rogue poisons: "Enduit une arme...") are proc DoTs, not cast on the target.
    if desc:find("[Ee]nduit") then return nil end
    -- Heals over time ("Rend/Soigne/Restaure N points de vie ...").
    if desc:find("^Rend ") or desc:find("^Soigne") or desc:find("^Restaure") then return nil end

    -- The last "<n> points de dégâts <school> en <secs> sec" clause, so a direct hit first (Immolation, Éclat
    -- lunaire, Boule de feu) yields the periodic part. The middle can't hold digits or dots, so it can't reach
    -- across to another clause.
    local total, school, duration
    for amount, mid, secs in desc:gmatch("(%d+)%s*points de dégâts([^%d.]*)en%s+(%d+%.?%d*)%s*s") do
        total, school, duration = tonumber(amount), schoolOf(mid), tonumber(secs)
    end
    if total and duration and duration > 0 then return total, school, duration end

    -- A bleed stated as health lost: "... saigne et perd 15 points de vie en 9 sec" (Pourfendre).
    local amount, secs = desc:match("perd%s+(%d+)%s*points de vie en%s+(%d+%.?%d*)%s*s")
    if amount and secs then return tonumber(amount), PHYSICAL, tonumber(secs) end

    -- A drain stated as a rate: "Transfère 11 points de vie ... toutes les 3 s. Dure 30 sec" (Siphon de vie; its
    -- school comes from SCHOOL_BY_NAME).
    local hp, every = desc:match("Transfère%s+(%d+)%s*points de vie.-toutes les%s+(%d+%.?%d*)%s*s")
    local lasts = desc:match("[Dd]ure%s+(%d+%.?%d*)%s*s")
    if hp and every and lasts then
        every, lasts = tonumber(every), tonumber(lasts)
        if every > 0 and lasts > 0 then
            return tonumber(hp) * math.floor(lasts / every + 0.5), PHYSICAL, lasts, every
        end
    end
end

-- The options window in this language: English text -> translation (see T in Locale.lua). Untranslated text
-- stays English. Every key, ready to fill in: python tools/test_load.py --dump-strings strings.lua
local STRINGS = {
}

ns.locale.register({
    tag = "frFR",
    label = "Français",
    strings = STRINGS,
    parseDot = parseDot,
    isFinisher = isFinisher,
    comboPointsAwarded = comboPointsAwarded,
    names = NAMES,
})
