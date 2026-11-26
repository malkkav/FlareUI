-- Part of FlareUI's DoT tracker. Taken from Does It Die Advanced 1.3.7 by WhiteKnight / Smuggz_, itself based on
-- Does It Die by JoeGG (MIT License, Copyright (c) 2026 Joe Greive: LICENSES/DoesItDieAdvanced.txt), and changed for
-- FlareUI: its own namespace; nothing else.
-- DoesItDie: Brazilian Portuguese (ptBR) spell descriptions and names. Registers itself with Locale.lua.
-- The Portuguese patterns only see descriptions the other languages didn't read, and can't match their text (they
-- need "de dano", "ao longo de N s", "Golpe final", "ponto de combo").
--
-- The wording is WoW: Forever's own Portuguese tooltips (Wowhead's tooltip API, data env Forever, locale pt), for
-- every spell the addon tracks or ignores (issue #19). Not verified on a Portuguese client yet. How it differs:
--   * "causando 40 de dano de Sombra ao longo de 12 s" (40 Shadow damage over 12 sec); bleeds name no school
--   * the school follows "dano": "de Sombra", "de Fogo", "de Natureza", "de Gelo", "Sagrado", "Arcano"
--   * finishers: "Golpe final", then "1 ponto: 44 de dano ao longo de 12 s." per combo point count
--   * builders: "Concede 1 ponto de combo."

local _, flare = ...
local ns = flare.DotEngine -- the tracker's own namespace (Namespace.lua), apart from FlareUI's

local PHYSICAL = 1

-- School words, combined schools first (Frostfire Bolt's Portuguese school is unverified: Fogo and Gelo together).
local function schoolFromWords(words)
    local fire, frost = words:find("Fogo", 1, true), words:find("Gelo", 1, true)
    if fire and frost then return 4 + 16 end
    if words:find("Sombra", 1, true) then return 32 end
    if fire then return 4 end
    if words:find("Natureza", 1, true) then return 8 end
    if frost then return 16 end
    if words:find("Sagrado", 1, true) then return 2 end
    if words:find("Arcano", 1, true) then return 64 end
    return PHYSICAL
end

-- Portuguese names of the spells in DoesItDie.lua's name-keyed tables (Forever's, from Wowhead). Names the client
-- reports by spell ID are added at load anyway (Locale.lua), so these mostly matter for the tests.
local NAMES = {
    ["Insect Swarm"] = { "Nuvem de Insetos" },
    ["Bane of Agony"] = { "Ruína da Agonia" },
    ["Curse of Agony"] = { "Maldição da Agonia" },
    ["Corruption"] = { "Corrupção" },
    ["Fireball"] = { "Bola de Fogo" },
    ["Holy Fire"] = { "Fogo Sagrado" },
    ["Rip"] = { "Rasgar" },
    ["Rupture"] = { "Ruptura" },
    ["Siphon Life"] = { "Sifão de Vida" },
    ["Serpent Sting"] = { "Picada de Serpente" },
    ["Pyroblast"] = { "Ignimpacto" },
    ["Rain of Fire"] = { "Chuva de Fogo" },
    ["Hellfire"] = { "Fogo do Inferno" },
    ["Blizzard"] = { "Nevasca" },
    ["Flamestrike"] = { "Golpe Flamejante" },
    ["Consecration"] = { "Consagração" },
    ["Hurricane"] = { "Furacão" },
    ["Volley"] = { "Salva" },
    ["Drain Life"] = { "Drenar Vida" },
    ["Drain Soul"] = { "Drenar Alma" },
    ["Drain Mana"] = { "Drenar Mana" },
    ["Health Funnel"] = { "Funil de Vida" },
    ["Mind Flay"] = { "Açoite Mental" },
    ["Arcane Missiles"] = { "Mísseis Arcanos" },
    ["Starshards"] = { "Fragmentos Estelares" },
    ["Immolation Trap"] = { "Armadilha Imolante" },
    ["Explosive Trap"] = { "Armadilha Explosiva" },
}

-- Thousands separators ("1.132" -> "1132") and decimal commas ("1,5 s" -> "1.5 s").
local function normalize(desc)
    return (desc:gsub("(%d)%.(%d%d%d)", "%1%2"):gsub("(%d),(%d)", "%1.%2"))
end

local function isFinisher(desc)
    return desc:find("Golpe final", 1, true) ~= nil
end

-- "Concede 1 ponto de combo." (Rake, Claw, Sinister Strike).
local function comboPointsAwarded(desc)
    return tonumber(desc:match("Concede (%d+) pontos? de combo"))
end

-- "1 ponto: 44 de dano ao longo de 12 s." per combo point count (Rip, Rupture).
local function parseFinisher(desc, comboPoints)
    local byPoints, highest = {}, 0
    for pts, amount, secs in desc:gmatch("(%d+) pontos? *: *(%d+) de dano ao longo de (%d+%.?%d*) s") do
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
    -- Weapon poisons ("Cobre a arma com um veneno") are proc DoTs, not cast on the target.
    if desc:find("Cobre a arma", 1, true) then return nil end

    -- The last "X de dano [school] ao longo de N s" clause, so a direct hit first (Immolate, Moonfire, Rake) yields
    -- the periodic part. Between "dano" and "ao longo" there are no digits or sentence ends.
    local total, school, duration
    for amount, words, secs in desc:gmatch("(%d+) de dano([^%d%.]-) ao longo de (%d+%.?%d*) s") do
        total, school, duration = tonumber(amount), schoolFromWords(words), tonumber(secs)
    end
    if total and duration and duration > 0 then return total, school, duration end

    -- A drain stated as a rate: "Transfere 11 pontos de vida do alvo para o lançador a cada 3 s. Dura 30 s." (Siphon
    -- Life; its school comes from SCHOOL_BY_NAME). Drain Life reads the same way but is ignored by name.
    local amount, every = desc:match("Transfere (%d+) pontos de vida.-a cada (%d+%.?%d*) s")
    local lasts = desc:match("Dura (%d+%.?%d*) s")
    if amount and every and lasts then
        every, lasts = tonumber(every), tonumber(lasts)
        if every > 0 and lasts > 0 then
            return tonumber(amount) * math.floor(lasts / every + 0.5), PHYSICAL, lasts, every
        end
    end
end

-- The options window in this language: English text -> translation (see T in Locale.lua). Untranslated text
-- stays English. Every key, ready to fill in: python tools/test_load.py --dump-strings strings.lua
local STRINGS = {
}

ns.locale.register({
    tag = "ptBR",
    label = "Português",
    strings = STRINGS,
    parseDot = parseDot,
    isFinisher = function(desc) return isFinisher(normalize(desc)) end,
    comboPointsAwarded = comboPointsAwarded,
    names = NAMES,
})
