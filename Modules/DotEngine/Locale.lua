-- Part of FlareUI's DoT tracker. Taken from Does It Die Advanced 1.3.7 by WhiteKnight / Smuggz_, itself based on
-- Does It Die by JoeGG (MIT License, Copyright (c) 2026 Joe Greive: LICENSES/DoesItDieAdvanced.txt), and changed for
-- FlareUI: its own namespace; nothing else.
-- DoesItDie: other client languages
-- DoesItDie.lua reads English spell descriptions and looks spells up by their English names. This file lets other
-- languages add their own wording for the same readings, and their names for the name-keyed tables. Each language
-- is one file (Locale_deDE.lua, ...) loaded after this one and before DoesItDie.lua, which calls
--
--     ns.locale.register({
--         tag = "deDE",
--         parseDot = function(desc, comboPoints) ... end,   -- same returns as parseDot in DoesItDie.lua
--         isFinisher = function(desc) ... end,              -- a combo point finisher ("Finishing move")
--         comboPointsAwarded = function(desc) ... end,      -- N from "Awards N combo point", or nil
--         names = { ["Rip"] = { "Zerfetzen" }, ... },       -- English name -> names in this language
--         label = "Deutsch",                                -- the language's own name (Window language list)
--         strings = { ["Live preview"] = "Vorschau", ... }, -- the options window's text: English -> this language
--     })
--
-- The English patterns always run first and are unchanged. Descriptions they don't read go to every registered
-- language in registration order, whatever GetLocale() says: one language's patterns can't match another's text,
-- and on WoW: Forever GetLocale() answers enUS while the spell text is German.

local _, flare = ...
local ns = flare.DotEngine -- the tracker's own namespace (Namespace.lua), apart from FlareUI's

local L = { languages = {} }
ns.locale = L

-- Every field but tag is optional.
function L.register(language)
    assert(type(language) == "table" and type(language.tag) == "string", "Does It Die Advanced: a language needs a tag")
    table.insert(L.languages, language)
end

---------------------------------------------------------------------------
-- The addon's own text (options window, chat): T("English text") returns it in the window language, else as is.
-- Keys are the exact English text, so a translator works from what's on screen; anything a language doesn't
-- translate stays English. The window language is the uiLanguage setting: "auto" picks the registered language
-- whose tag is GetLocale() (which may answer enUS on a non-English Forever client, hence the setting). It's
-- read when text is built, so a change applies after /reload. List every key: tools/test_load.py --dump-strings.
---------------------------------------------------------------------------

local function hasStrings(language)
    return type(language.strings) == "table" and next(language.strings) ~= nil
end

local function windowLanguage()
    local setting = ns.db and ns.db.uiLanguage or "auto"
    local wanted = setting
    if setting == "auto" then wanted = GetLocale and GetLocale() end
    for _, language in ipairs(L.languages) do
        if language.tag == wanted and hasStrings(language) then return language end
    end
end

-- Every key T was asked for, when L.collectStrings is set (tools/test_load.py --dump-strings).
L.seenStrings = {}

function L.T(text)
    if type(text) ~= "string" or text == "" then return text end
    if L.collectStrings then L.seenStrings[text] = true end
    local language = windowLanguage()
    local translated = language and language.strings[text]
    if type(translated) == "string" and translated ~= "" then return translated end
    return text
end

-- The Window language choices: Auto, English, then every language with translations.
function L.windowLanguages()
    local list = { { id = "auto", label = "Auto (game client)" }, { id = "enUS", label = "English" } }
    for _, language in ipairs(L.languages) do
        if hasStrings(language) then table.insert(list, { id = language.tag, label = language.label or language.tag }) end
    end
    return list
end

---------------------------------------------------------------------------
-- Names
---------------------------------------------------------------------------

-- One spell ID per entry of DoesItDie.lua's name-keyed tables (KNOWN_TICK_INTERVALS, TICK_SHAPES, SCHOOL_BY_NAME,
-- IGNORED_SPELLS, PROJECTILE_DOTS), Classic Era rank 1; all ranks share the name. At load the tables also get the
-- name the client itself reports for it, whatever the language, and Forever's own renames (980 is its Bane of
-- Agony). Frostfire Bolt is Forever's own spell with no known ID: it relies on each language's names.
L.SPELL_IDS = {
    ["Insect Swarm"] = 5570, ["Curse of Agony"] = 980, ["Fireball"] = 133, ["Holy Fire"] = 14914,
    ["Rip"] = 1079, ["Rupture"] = 1943, ["Siphon Life"] = 18265,
    ["Rain of Fire"] = 5740, ["Hellfire"] = 1949, ["Blizzard"] = 10, ["Flamestrike"] = 2120,
    ["Consecration"] = 26573, ["Hurricane"] = 16914, ["Volley"] = 1510,
    ["Drain Life"] = 689, ["Drain Soul"] = 1120, ["Drain Mana"] = 5138, ["Health Funnel"] = 755,
    ["Mind Flay"] = 15407, ["Arcane Missiles"] = 5143, ["Starshards"] = 10797,
    ["Immolation Trap"] = 13795, ["Explosive Trap"] = 13813, ["Wyvern Sting"] = 19386,
    ["Serpent Sting"] = 1978, ["Pyroblast"] = 11366, ["Corruption"] = 172,
    ["Unstable Affliction"] = 30108, -- TBC
}

-- Gives `alias` the entry `englishName` has, in every table that has one and doesn't know `alias` yet.
local function addAlias(tables, englishName, alias)
    if type(alias) ~= "string" or alias == "" or alias == englishName then return false end
    local added = false
    for _, tbl in ipairs(tables) do
        if tbl[englishName] ~= nil and tbl[alias] == nil then
            tbl[alias] = tbl[englishName]
            added = true
        end
    end
    return added
end

-- The names of every registered language.
function L.addNames(tables)
    for _, language in ipairs(L.languages) do
        for englishName, aliases in pairs(language.names or {}) do
            for _, alias in ipairs(aliases) do addAlias(tables, englishName, alias) end
        end
    end
end

-- getName(spellID) returns the client's name for a spell, or nil. Returns what was added, for the log.
function L.addClientNames(tables, getName)
    local added = {}
    for englishName, spellID in pairs(L.SPELL_IDS) do
        local ok, name = pcall(getName, spellID)
        if ok and addAlias(tables, englishName, name) then
            table.insert(added, name .. " = " .. englishName)
        end
    end
    table.sort(added)
    return added
end

---------------------------------------------------------------------------
-- Descriptions
---------------------------------------------------------------------------

-- The first registered language that reads `desc` as a DoT: total damage, school mask, duration, stated tick
-- interval (the returns of parseDot in DoesItDie.lua).
function L.parseDot(desc, comboPoints)
    for _, language in ipairs(L.languages) do
        if language.parseDot then
            local total, school, duration, interval = language.parseDot(desc, comboPoints)
            if total then return total, school, duration, interval end
        end
    end
end

-- FlareUI: the damage a description says the spell deals at once, before its DoT (0 when it deals none), or nil
-- when no language can tell. DoesItDie.lua reads this from English text only, so on any other client no spell
-- but a finisher ever learned its tick size from the damage meter ("its upfront hit can't be told apart").
function L.directPart(desc)
    for _, language in ipairs(L.languages) do
        local direct = language.directPart and language.directPart(desc)
        if direct then return direct end
    end
end

function L.isFinisher(desc)
    for _, language in ipairs(L.languages) do
        if language.isFinisher and language.isFinisher(desc) then return true end
    end
    return false
end

function L.comboPointsAwarded(desc)
    for _, language in ipairs(L.languages) do
        local points = language.comboPointsAwarded and language.comboPointsAwarded(desc)
        if points then return points end
    end
end

-- Words nearly every English description has and other languages' descriptions don't ("sec" is left out: French
-- writes it too).
local ENGLISH_WORDS = { the = true, damage = true, ["and"] = true, ["for"] = true, over = true, of = true,
    to = true, by = true, with = true, your = true, you = true }

local function looksEnglish(desc)
    for word in desc:gmatch("%a+") do
        if ENGLISH_WORDS[word:lower()] then return true end
    end
    return false
end

-- Whether to log a description nothing read as a DoT (once per spell per session), so a play session collects
-- the wording of a language that isn't read yet, or not fully. Decided by the text itself, not GetLocale():
-- English descriptions that aren't DoTs (Fireball) aren't logged.
local loggedUnread = {}
function L.shouldLogUnread(spellID, desc)
    if type(desc) ~= "string" or desc == "" or looksEnglish(desc) then return false end
    if loggedUnread[spellID] then return false end
    loggedUnread[spellID] = true
    return true
end
