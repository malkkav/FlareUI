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

-- Hide Pop-up Alerts (off): syncs happen without their reload pop-up, on every character (account-wide);
-- the pop-up's Hide These Alerts turns it on
S:Row{
    key = "qol.syncHideAlerts", module = "language", parent = "qol.sync", section = "qol.syncBlizzUi",
    get = function() return ns.db and ns.db.global and ns.db.global.syncHideAlerts == true or false end,
    set = function(on) if ns.db and ns.db.global then ns.db.global.syncHideAlerts = on and true or nil end end,
    resetValue = function() return false end,
    disabled = function() return not S:GetPath("tweaks.syncUI") end,
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
-- Text Scale: all text larger or smaller, frames as they are (Core.lua ns.TEXT_SCALE), account-wide
local TEXT_CHOICES = {}
for percent = 80, 150, 5 do TEXT_CHOICES[#TEXT_CHOICES + 1] = { percent, percent .. "%" } end
S:Row{
    key = "qol.textScale", kind = "choice", module = "language", choices = TEXT_CHOICES, reload = true,
    get = function()
        local g = Global()
        return math.floor((g and tonumber(g.textScale) or 1) * 20 + 0.5) * 5
    end,
    set = function(percent) local g = Global(); if g then g.textScale = percent ~= 100 and percent / 100 or nil end end,
}

-- Global Font (11-13): the face of every font set to Global (Core.lua ns.GlobalFontFace), then the
-- two all-font buttons side by side (Settings/Fonts.lua)
S:Row{
    key = "fonts.global.face", kind = "dropdown", module = "language", dropdownWidth = 150,
    path = "fonts.global.face", previewFont = "fonts.global",
    choices = function() return S.FontFaces() end,
    apply = function() S:ApplyAllFonts() end,
}
-- Blizzard's own text (11-13, Settings/Fonts.lua ns.GameFonts): off / Default leave it as it is
local function BlizzardFaces()
    local list = S.FontFaces()
    table.insert(list, 1, { ns.GLOBAL_FONT, L["Global (%s)"]:format(ns.GlobalFontFace()) })
    table.insert(list, 1, { "", L["Default"] })
    return list
end
S:Row{
    key = "fonts.gameText", module = "language", path = "fonts.gameText",
    apply = function() S:ApplyAllFonts() end,
}
S:Row{
    key = "fonts.nameplate.face", kind = "dropdown", module = "language", dropdownWidth = 150,
    path = "fonts.nameplate.face", previewFont = "fonts.nameplate", choices = BlizzardFaces,
    apply = function() S:ApplyAllFonts() end,
}
S:Row{
    key = "fonts.combat.face", kind = "dropdown", module = "language", dropdownWidth = 150,
    path = "fonts.combat.face", previewFont = "fonts.combat", choices = BlizzardFaces,
    -- the game reads it as you log in: the file is saved now, for then
    apply = function() if ns.GameFonts then ns.GameFonts.SaveCombatPath() end end,
}
ns.Dialogs["FLAREUI_FONTS_USE_GLOBAL"] = {
    text = L["Set every FlareUI font to the Global Font?\n\nEach font keeps its size, outline and shadow."],
    button1 = L["Use Global Font"],
    button2 = L["Cancel"],
    OnAccept = function() S:UseGlobalFontEverywhere() end,
    hideOnEscape = true,
}
ns.Dialogs["FLAREUI_FONTS_RESET"] = {
    text = L["Put every FlareUI font, and the Global Font, back to its defaults?"],
    button1 = L["Reset"],
    button2 = L["Cancel"],
    OnAccept = function() S:ResetAllFonts() end,
    hideOnEscape = true,
}
S:Row{
    key = "fonts.buttons", kind = "buttons", module = "language", labelFn = function() return "" end,
    center = true, buttonGap = 16,
    buttons = {
        { text = L["Use Global Font Everywhere"], width = 220,
          onClick = function() ns.ShowDialog("FLAREUI_FONTS_USE_GLOBAL") end },
        { text = L["Reset All Fonts"], width = 220, disabled = function() return not S:AnyFontChanged() end,
          onClick = function() ns.ShowDialog("FLAREUI_FONTS_RESET") end },
    },
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
