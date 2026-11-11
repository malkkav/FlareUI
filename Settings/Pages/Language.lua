local _, ns = ...
local L = ns.L
local S = ns.Settings

-- 11-11 (Marcus): the Language page became Settings, the whole interface's own options: Sync Blizz UI,
-- Move Any Window and UI Scale (from Quality of Life's Advanced tab), then the language
ns.Copy.modules.language = {
    title = L["Settings"],
    desc = L["Options for the whole interface: your characters, windows, scale and language."],
}
ns.Copy.sections["language.main"] = L["Language"]
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
    -- no Reset on its sections (one-off choices, most of them reloading)
    noReset = true,
}

-- Sync Blizz UI: copies one character's Blizzard settings to the others
S:Row{ key = "qol.sync", module = "language", path = "tweaks.syncUI", reload = true, section = "qol.syncBlizzUi" }
S:Row{
    key = "qol.source", kind = "button", module = "language", parent = "qol.sync", section = "qol.syncBlizzUi",
    labelFn = function()
        local label = ns.Tweaks and ns.Tweaks.GetSyncSourceLabel and ns.Tweaks:GetSyncSourceLabel()
        return label and L["Current source: %s"]:format(label) or L["No source yet."]
    end,
    buttonText = L["Make This Character the Source"],
    fitButtonText = true,
    disabled = function() return ns.Tweaks and ns.Tweaks.IsSyncSource and ns.Tweaks:IsSyncSource() or false end,
    apply = function() ns.ShowDialog("FLAREUI_SYNC_SOURCE") end,
}

-- one switch for moving windows and placing loot rolls / toasts
S:Row{
    key = "qol.move", module = "language", reload = true,
    get = function() return S:GetPath("tweaks.moveAnyFrame") end,
    set = function(on)
        S:SetPath("tweaks.moveAnyFrame", on)
        S:SetPath("tweaks.moveLootToasts", on)
    end,
}

-- The whole interface's scale (Tweaks.lua 17b), as EnhanceQoL's: a preset applied as you log in,
-- account-wide; Custom opens its own scale row
local SCALE_PRESETS = { "blizzard", "auto", "custom", "4k", "1440p", "1440p125", "1080p", "1080p125" }
local CUSTOM_CHOICES = {}
for percent = 30, 200, 5 do CUSTOM_CHOICES[#CUSTOM_CHOICES + 1] = { percent, percent .. "%" } end
local function Global() return ns.db and ns.db.global end
S:Row{
    key = "qol.uiScale", kind = "choice", module = "language", choices = SCALE_PRESETS, reload = true,
    get = function() local g = Global(); return g and g.uiScale or "blizzard" end,
    set = function(preset)
        local g = Global()
        if not g then return end
        g.uiScale = preset ~= "blizzard" and preset or nil
        -- Custom starts from the scale in use, as EnhanceQoL's
        if preset == "custom" and not g.uiScaleCustom then g.uiScaleCustom = UIParent:GetScale() end
    end,
}
S:Row{
    key = "qol.uiScaleCustom", kind = "choice", module = "language", parent = "qol.uiScale", choices = CUSTOM_CHOICES, reload = true,
    hidden = function() local g = Global(); return not (g and g.uiScale == "custom") end,
    get = function()
        local g = Global()
        local value = g and tonumber(g.uiScaleCustom) or 1
        return math.max(30, math.min(200, math.floor(value * 20 + 0.5) * 5))
    end,
    set = function(percent) local g = Global(); if g then g.uiScaleCustom = percent / 100 end end,
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
