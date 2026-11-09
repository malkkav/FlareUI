local _, ns = ...
local L = ns.L
local S = ns.Settings

ns.Copy.modules.language = {
    title = L["Language"],
    desc = L["Choose which language FlareUI uses."],
}
ns.Copy.rows["language.useGame"] = {
    label = L["Use the Game Language"],
    desc = L["Match the language selected in World of Warcraft."],
}
ns.Copy.rows["language.override"] = {
    label = L["Addon Language"],
    desc = L["Applies after reloading the UI."],
}

local function UseGameLanguage()
    return ns.db.global.useGameLanguage ~= false
end

local function PreferredLanguage()
    return ns.ResolveLocale(ns.db.global.language)
end

local function TrackLanguageReload()
    local nextLocale = UseGameLanguage() and ns.ResolveLocale() or PreferredLanguage()
    S:TrackReload("language", nextLocale, ns.LoadedLocale())
end

S:Module{
    key = "language", group = "top", order = 3,
    navIcon = 137195, navIconRound = true, -- Interface/WorldMap/WorldMap-Icon
}

S:Row{
    key = "language.useGame", lead = true,   -- on top: the language list below only counts while it is off
    get = UseGameLanguage,
    set = function(on)
        local global = ns.db.global
        if not on and global.language == nil then
            global.language = PreferredLanguage()
        end
        global.useGameLanguage = on
        TrackLanguageReload()
    end,
}

S:Row{
    key = "language.override", kind = "dropdown", choices = ns.LanguageChoices,
    get = PreferredLanguage, disabled = UseGameLanguage,
    set = function(locale)
        ns.db.global.language = locale
        TrackLanguageReload()
    end,
}
