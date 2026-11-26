-- Part of FlareUI's DoT tracker. Taken from Does It Die Advanced 1.3.7 by WhiteKnight / Smuggz_, itself based on
-- Does It Die by JoeGG (MIT License, Copyright (c) 2026 Joe Greive: LICENSES/DoesItDieAdvanced.txt), and changed for
-- FlareUI: its own namespace; nothing else.
-- DoesItDie: Spanish (esES) spell descriptions and names. Registers itself with Locale.lua.
-- Ported from PR #6 (13Karl). The Spanish patterns only see descriptions the English, German and French ones
-- didn't read, and can't match their text (they need "durante N s", "daño", "Remate", "Otorga").
--
-- Names and wording checked against Wowhead Forever's Spanish pages (wowhead.com/forever/es); not verified on a
-- Spanish client yet. How it differs from English:
--   * the school follows the amount: "40 p. de daño de las Sombras durante 12 s."; no school is physical
--   * numbers: "1.314" is a thousand three hundred and fourteen, "1,5 s" is one point five seconds

local _, flare = ...
local ns = flare.DotEngine -- the tracker's own namespace (Namespace.lua), apart from FlareUI's

local PHYSICAL = 1

-- School words as they follow "p. de daño" ("de las Sombras", "Arcano"). Pirofrío (Frostfire) first, before
-- the schools it combines.
local SCHOOLS = {
    { "Pirofrío", 4 + 16 }, { "Sombras", 32 }, { "Fuego", 4 }, { "Naturaleza", 8 }, { "Escarcha", 16 },
    { "Arcano", 64 }, { "Sagrado", 2 },
}
local function schoolFromWords(words)
    for _, entry in ipairs(SCHOOLS) do
        if words:find(entry[1], 1, true) then return entry[2] end
    end
    return PHYSICAL
end

-- Spanish names of the spells in DoesItDie.lua's name-keyed tables. Names the client reports by spell ID are
-- added at load anyway (Locale.lua), so these mostly matter for spells without a known ID and for the tests.
local NAMES = {
    ["Serpent Sting"] = { "Aguijón de serpiente" },
    ["Fireball"] = { "Bola de Fuego" },
    ["Pyroblast"] = { "Piroexplosión" },
    ["Frostfire Bolt"] = { "Descarga de Pirofrío" },
    ["Insect Swarm"] = { "Enjambre de insectos" },
    ["Curse of Agony"] = { "Maldición de Agonía" },
    ["Bane of Agony"] = { "Terror de agonía" },
    ["Holy Fire"] = { "Fuego Sagrado" },
    ["Rip"] = { "Destripar" },
    ["Rupture"] = { "Ruptura" },
    ["Siphon Life"] = { "Succionar vida" },
    ["Rain of Fire"] = { "Lluvia de Fuego" },
    ["Hellfire"] = { "Piroinferno" },
    ["Blizzard"] = { "Ventisca" },
    ["Flamestrike"] = { "Fogonazo" },
    ["Consecration"] = { "Consagración" },
    ["Hurricane"] = { "Huracán" },
    ["Volley"] = { "Lluvia" },
    ["Drain Life"] = { "Drenar vida" },
    ["Drain Soul"] = { "Drenar alma" },
    ["Drain Mana"] = { "Drenar maná" },
    ["Health Funnel"] = { "Cauce de salud" },
    ["Mind Flay"] = { "Despelleje mental" },
    ["Arcane Missiles"] = { "Misiles Arcanos" },
    ["Starshards"] = { "Fragmentos estelares" },
    ["Immolation Trap"] = { "Trampa de inmolación" },
    ["Explosive Trap"] = { "Trampa explosiva" },
    ["Wyvern Sting"] = { "Picadura de dracoleón" },
}

-- Thousands separator and decimal comma: "1.314" -> "1314", "1,5 s" -> "1.5 s".
local function normalize(desc)
    return (desc:gsub("(%d)%.(%d%d%d)", "%1%2"):gsub("(%d),(%d)", "%1.%2"))
end

-- "Remate que inflige daño en el tiempo...: 1 punto: 44 de daño durante 12 s." (Destripar)
local function isFinisher(desc)
    return desc:find("^Remate") ~= nil
end

-- "Otorga 1 punto de combo." (Garrote) or "Otorga 1 p. de combo." (Golpe siniestro).
local function comboPointsAwarded(desc)
    return tonumber(desc:match("Otorga (%d+) puntos? de combo") or desc:match("Otorga (%d+) p%. de combo"))
end

-- Finishers list a DoT per combo point: "1 punto: 44 de daño durante 12 s." (Destripar),
-- "1 punto: 25 p. de daño durante 8 s" (Ruptura).
local function parseFinisher(desc, comboPoints)
    local byPoints, highest = {}, 0
    for pointsText, amount, secs in desc:gmatch("(%d+) puntos?%s*:%s*(%d+)%D-durante (%d+%.?%d*) s") do
        local points = tonumber(pointsText)
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
    -- Poisons ("Cubre un arma con veneno...") and heals over time ("Cura el objetivo en 45 p. ... durante 15 s.").
    if desc:find("[Cc]ubre un arma") or desc:find("^Cura") then return nil end

    --   "causando 40 p. de daño de las Sombras durante 12 s."           (Corrupción)
    --   "15 p. de daño de Fuego más durante 15 s."                       (Inmolar)
    --   "un daño extra de 48 p. durante 9 s."                            (Arañazo)
    -- The amount is the last number before "durante", and must read as an amount ("p." or "de daño" after it,
    -- not "40% durante" as in Seccionar) of damage. Takes the last such clause, like the English parser.
    local total, school, duration
    for pos, amount, words, secs in desc:gmatch("()(%d+)(%D-)durante (%d+%.?%d*) s") do
        local isAmount = words:find("^%s*p%.") or words:find("^%s*de daño")
        local isDamage = words:find("daño") or desc:sub(math.max(1, pos - 20), pos - 1):find("daño")
        if isAmount and isDamage then
            total, school, duration = tonumber(amount), schoolFromWords(words), tonumber(secs)
        end
    end
    if total and duration > 0 then return total, school, duration end

    -- "Transfiere 11 p. de salud del objetivo al taumaturgo cada 3 s. Dura 30 s." (Succionar vida)
    local amount, words, every = desc:match("(%d+)(%D-)cada (%d+%.?%d*) s")
    local lasts = desc:match("[Dd]ura (%d+%.?%d*) s")
    if amount and every and lasts and (words:find("daño") or words:find("salud")) then
        every, lasts = tonumber(every), tonumber(lasts)
        if every > 0 and lasts > 0 then
            return tonumber(amount) * math.floor(lasts / every + 0.5), schoolFromWords(words), lasts, every
        end
    end
end

-- The options window in this language: English text -> translation (see T in Locale.lua). Untranslated text
-- stays English. Every key, ready to fill in: python tools/test_load.py --dump-strings strings.lua
local STRINGS = {
}

ns.locale.register({
    tag = "esES",
    label = "Español",
    strings = STRINGS,
    parseDot = parseDot,
    isFinisher = function(desc) return isFinisher(normalize(desc)) end,
    comboPointsAwarded = comboPointsAwarded,
    names = NAMES,
})
