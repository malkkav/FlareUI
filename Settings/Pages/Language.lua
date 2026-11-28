local _, ns = ...
local L = ns.L
local S = ns.Settings

-- GENERAL: the whole interface's own options (the page key stays "language"), in two tabs:
-- Account (Sync Blizz UI, Move Any Window, language; its key already was "account") and Interface
-- (scale, fonts)
ns.Copy.modules.language = {
    title = L["General"],
    desc = L["Options for the whole interface: your characters, windows, scale and language."],
    -- Account first, ESC Menu on top of it
    tabs = { L["Account"], L["Interface"] },
}
ns.Copy.sections["language.main"] = L["Language"]
-- Language: one list, the game's language first (it was Use the Game Language + Addon Language)
ns.Copy.rows["language.override"] = {
    label = L["Language"],
    desc = L["The language of FlareUI's text. Game Language follows the language World of Warcraft uses."],
    tags = { "addon language", "use the game language", "translation", "locale" },
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
    tabs = { { key = "account" }, { key = "interface" } },
    -- no Reset on its sections (one-off choices, most of them reloading)
    noReset = true,
}

-- ESC Menu: a FlareUI button in the game menu, under Shop (Launcher.lua 4b); on for new installs (11-27),
-- for every character
S:Row{
    key = "language.escButton", module = "language", tab = "account", section = "language.escMenu", account = true,
    get = function() local g = ns.db and ns.db.global; return g and g.escMenuButton == true or false end,
    set = function(on) local g = ns.db and ns.db.global; if g then g.escMenuButton = on and true or nil end end,
    resetValue = function() return true end,   -- (on for new players, 11-27)
}

-- Sync Blizz UI: copies one character's Blizzard settings to the others
S:Row{ key = "qol.sync", module = "language", tab = "account", path = "tweaks.syncUI", reload = true, section = "qol.syncBlizzUi" }
S:Row{
    key = "qol.source", kind = "button", module = "language", tab = "account", parent = "qol.sync", section = "qol.syncBlizzUi",
    labelFn = function()
        local label = ns.Tweaks and ns.Tweaks.GetSyncSourceLabel and ns.Tweaks:GetSyncSourceLabel()
        return label and L["Current source: %s"]:format(label) or L["No source yet."]
    end,
    buttonText = L["Make This Character the Source"],
    fitButtonText = true,
    disabled = function() return ns.Tweaks and ns.Tweaks.IsSyncSource and ns.Tweaks:IsSyncSource() or false end,
    apply = function() ns.ShowDialog("FLAREUI_SYNC_SOURCE") end,
}

-- Copy Now: the only way a character copies after its one question at login (Tweaks.AskSync, 11-26)
S:Row{
    key = "qol.copyNow", kind = "button", module = "language", tab = "account", parent = "qol.sync", section = "qol.syncBlizzUi",
    buttonText = L["Copy Now"],
    fitButtonText = true,
    disabled = function() return not (ns.Tweaks and ns.Tweaks.CanCopySync and ns.Tweaks:CanCopySync()) end,
    apply = function() if ns.Tweaks and ns.Tweaks.CopySyncNow then ns.Tweaks:CopySyncNow() end end,
}

-- one switch for moving windows and placing loot rolls / toasts
S:Row{
    key = "qol.move", module = "language", tab = "account", reload = true,
    get = function() return S:GetPath("tweaks.moveAnyFrame") end,
    set = function(on)
        S:SetPath("tweaks.moveAnyFrame", on)
        S:SetPath("tweaks.moveLootToasts", on)
    end,
}

-- The whole interface's scale (Tweaks.lua 17b): a preset applied as you log in,
-- account-wide; Custom opens its own scale row
-- (Custom last: the presets first, then your own)
local SCALE_PRESETS = { "blizzard", "auto", "4k", "1440p", "1440p125", "1080p", "1080p125", "custom" }
local CUSTOM_CHOICES = {}
for percent = 30, 200, 5 do CUSTOM_CHOICES[#CUSTOM_CHOICES + 1] = { percent, percent .. "%" } end
local function Global() return ns.db and ns.db.global end
S:Row{
    key = "qol.uiScale", kind = "choice", module = "language", tab = "interface", choices = SCALE_PRESETS, reload = true, account = true,
    get = function() local g = Global(); return g and g.uiScale or "blizzard" end,
    set = function(preset)
        local g = Global()
        if not g then return end
        -- the scale before, for the keep-or-go-back question after the reload (Tweaks.lua 17b)
        if ns.Tweaks and ns.Tweaks.UIScale then ns.Tweaks.UIScale.Remember() end
        g.uiScale = preset ~= "blizzard" and preset or nil
        -- Custom starts from the scale in use
        if preset == "custom" and not g.uiScaleCustom then g.uiScaleCustom = UIParent:GetScale() end
    end,
}
S:Row{
    -- (a slider; right under UI Scale, greyed until Custom is picked, not indented)
    key = "qol.uiScaleCustom", kind = "range", module = "language", tab = "interface", choices = CUSTOM_CHOICES, reload = true, account = true,
    disabled = function() local g = Global(); return not (g and g.uiScale == "custom") end,
    get = function()
        local g = Global()
        local value = g and tonumber(g.uiScaleCustom) or 1
        return math.max(30, math.min(200, math.floor(value * 20 + 0.5) * 5))
    end,
    set = function(percent)
        local g = Global()
        if not g then return end
        if ns.Tweaks and ns.Tweaks.UIScale then ns.Tweaks.UIScale.Remember() end
        g.uiScaleCustom = percent / 100
    end,
}
-- Text Scale: all text larger or smaller, frames as they are (Core.lua ns.TEXT_SCALE), account-wide
local TEXT_CHOICES = {}
for percent = 80, 150, 5 do TEXT_CHOICES[#TEXT_CHOICES + 1] = { percent, percent .. "%" } end
S:Row{
    key = "qol.textScale", kind = "range", module = "language", tab = "interface", choices = TEXT_CHOICES, reload = true, account = true,   -- (a slider)
    get = function()
        local g = Global()
        return math.floor((g and tonumber(g.textScale) or 1) * 20 + 0.5) * 5
    end,
    set = function(percent) local g = Global(); if g then g.textScale = percent ~= 100 and percent / 100 or nil end end,
}


-- Global Font: the face of every font set to Global (Core.lua ns.GlobalFontFace), then the
-- two all-font buttons side by side (Settings/Fonts.lua)
S:Row{
    key = "fonts.global.face", kind = "dropdown", module = "language", tab = "interface", dropdownWidth = 150,
    path = "fonts.global.face", previewFont = "fonts.global",
    choices = function() return S.FontFaces() end,
    apply = function() S:ApplyAllFonts() end,
}
-- one outline over every FlareUI font's own (Core.lua ns.OutlineFlags)
S:Row{
    key = "fonts.outline", kind = "choice", module = "language", tab = "interface", path = "fonts.outline", reload = true,
    choices = { "", "NONE", "OUTLINE", "THICKOUTLINE", "OUTLINE, SLUG" },
}
-- Blizzard's own text (Settings/Fonts.lua ns.GameFonts): off / Default leave it as it is
local function BlizzardFaces()
    local list = S.FontFaces()
    table.insert(list, 1, { ns.GLOBAL_FONT, L["Global (%s)"]:format(ns.GlobalFontFace()) })
    table.insert(list, 1, { "", L["Default"] })
    return list
end
S:Row{
    key = "fonts.gameText", module = "language", tab = "interface", path = "fonts.gameText",
    apply = function() S:ApplyAllFonts() end,
}
S:Row{
    key = "fonts.nameplate.face", kind = "dropdown", module = "language", tab = "interface", dropdownWidth = 150,
    path = "fonts.nameplate.face", previewFont = "fonts.nameplate", choices = BlizzardFaces,
    apply = function() S:ApplyAllFonts() end,
}
S:Row{
    key = "fonts.combat.face", kind = "dropdown", module = "language", tab = "interface", dropdownWidth = 150,
    path = "fonts.combat.face", previewFont = "fonts.combat", choices = BlizzardFaces,
    -- the game reads it as you log in: the file is saved now, for then
    apply = function() if ns.GameFonts then ns.GameFonts.SaveCombatPath() end end,
}
-- Combat Text Size: the game's own scale of the damage numbers, shown only
-- where the client has it (WorldTextScale_v2, else WorldTextScale). Nothing is written until you move it.
local function CombatTextCVar()
    if not (C_CVar and C_CVar.GetCVarInfo) then return nil end
    for _, name in ipairs({ "WorldTextScale_v2", "WorldTextScale" }) do
        local ok, value = pcall(C_CVar.GetCVarInfo, name)
        if ok and value ~= nil then return name end
    end
    return nil
end
local COMBAT_TEXT_CHOICES = {}
for percent = 50, 200, 10 do COMBAT_TEXT_CHOICES[#COMBAT_TEXT_CHOICES + 1] = { percent, percent .. "%" } end
S:Row{
    key = "fonts.combatSize", kind = "range", module = "language", tab = "interface", choices = COMBAT_TEXT_CHOICES,
    hidden = function() return CombatTextCVar() == nil end,
    get = function()
        local name = CombatTextCVar()
        local value = name and tonumber(C_CVar.GetCVar(name)) or 1
        return math.floor(value * 10 + 0.5) * 10
    end,
    set = function(percent)
        local name = CombatTextCVar()
        if name then pcall(C_CVar.SetCVar, name, percent / 100) end
    end,
    resetValue = function() return 100 end,
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
    key = "fonts.buttons", kind = "buttons", module = "language", tab = "interface", labelFn = function() return "" end,
    center = true, buttonGap = 16,
    buttons = {
        { text = L["Use Global Font Everywhere"], width = 220,
          onClick = function() ns.ShowDialog("FLAREUI_FONTS_USE_GLOBAL") end },
        { text = L["Reset All Fonts"], width = 220, disabled = function() return not S:AnyFontChanged() end,
          onClick = function() ns.ShowDialog("FLAREUI_FONTS_RESET") end },
    },
}


-- Language: Game Language (global.useGameLanguage, the default) first, then each language
S:Row{
    key = "language.override", kind = "dropdown", tab = "account", account = true, reloadNote = true,   -- (its own reload tracking)
    choices = function()
        local list = { { "game", L["Game Language"] }, { divider = true } }
        for _, c in ipairs(ns.LanguageChoices()) do list[#list + 1] = c end
        return list
    end,
    get = function() return UseGameLanguage() and "game" or PreferredLanguage() end,
    set = function(locale)
        local global = ns.db.global
        if locale == "game" then
            global.useGameLanguage = true
        else
            global.useGameLanguage = false
            global.language = locale
        end
        TrackLanguageReload()
    end,
    resetValue = function() return "game" end,
}
