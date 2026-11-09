local _, ns = ...

--------------------------------------------------
-- LOCALIZATION
-- ns.L["English text"]: the phrase in the player's language, falling back to the English key.
-- Locales/<locale>.lua hold CurseForge packager keywords; Locales/enUS.lua (not loaded) is the phrase
-- list. Loads first: some files build labels as they load.
--------------------------------------------------
-- This runs before AceDB initializes, so read the language choice from SavedVariables.
local gameLocale = GetLocale()
local requestedLocale = gameLocale
local db = _G.FlareUI2_DB
local global = type(db) == "table" and db.global
if type(global) == "table" and global.useGameLanguage == false and type(global.language) == "string" then
    requestedLocale = global.language
end
local available = { enUS = true }
local languages = {
    { "enUS", "English" },
    { "deDE", "Deutsch" },
    { "esES", "Español (España)" },
    { "esMX", "Español (Latinoamérica)" },
    { "frFR", "Français" },
    { "itIT", "Italiano" },
    { "koKR", "한국어" },
    { "ptBR", "Português (Brasil)" },
    { "ruRU", "Русский" },
    { "zhCN", "简体中文" },
    { "zhTW", "繁體中文" },
}

local L = setmetatable({}, {
    __index = function(_, key) return key end,
})
ns.L = L

-- a language with few phrases of its own borrows a close one's first: Mexican Spanish takes the Spain
-- Spanish phrases, and its own file (loaded after) puts its words over them
local FALLBACK = { esMX = "esES" }

-- The packager can populate otherwise empty locale files. Discover which ones
-- have translations, and keep only the strings for the locale loaded this session.
function ns.LocaleStrings(locale)
    return setmetatable({}, {
        __newindex = function(_, key, value)
            available[locale] = true
            if locale == requestedLocale or locale == FALLBACK[requestedLocale] then L[key] = value end
        end,
    })
end

function ns.ResolveLocale(locale)
    locale = type(locale) == "string" and locale or gameLocale
    return (available[locale] or available[FALLBACK[locale] or false]) and locale or "enUS"
end

function ns.LoadedLocale()
    return ns.ResolveLocale(requestedLocale)
end

-- the languages with phrases, their own or a fallback's (as ResolveLocale accepts them)
function ns.LanguageChoices()
    local choices = {}
    for _, entry in ipairs(languages) do
        if ns.ResolveLocale(entry[1]) == entry[1] then choices[#choices + 1] = entry end
    end
    return choices
end
