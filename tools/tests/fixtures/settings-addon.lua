local UI = dofile("tools/tests/fixtures/settings-ui.lua")

local function noop() end
local function tokenSet(value)
    local map = {}
    for token in tostring(value or ""):gmatch("[^,]+") do map[token] = true end
    return map
end

local function setup(configureClient)
    local ui = UI.new()
    local env = ui.env
    local dialogs = {}
    local ns = {
        L = setmetatable({}, { __index = function(_, key) return key end }),
        db = { profile = {}, global = {} },
        defaults = { profile = {} },
        WINDOW_STYLE = { border = { 0.6, 0.5, 0.4 }, background = { 0.1, 0.1, 0.1 } },
        BORDER_COLOR = { r = 0.6, g = 0.5, b = 0.4, a = 1 },
        DOT = "·",
        Conditions = { Set = tokenSet, Ticked = function(value, token) return tokenSet(value)[token] == true end },
        IsGamepadUI = function() return ui.gamepad == true end,
        ButtonSound = function() env.PlaySound("Button") end,
        WindowOpenSound = function() env.PlaySound("Open") end,
        WindowCloseSound = function() env.PlaySound("Close") end,
        AnyDialogShown = function() return ui.dialogOpen == true end,
        ShowDialog = function(key, message, data) dialogs[#dialogs + 1] = { key = key, message = message, data = data } end,
        AddonMedia = function() return { "Custom Edge" } end,
        SetFontFamily = function(object, path, size, flags) object:SetFont(path, size, flags) end,
        ApplyShadow = function(object, cfg) object.shadow = cfg.enableShadow end,
        BorderEdgeSize = function(_, default) return default end,
        GLOBAL_FONT = "_global",
        GlobalFontFace = function() return "Friz Quadrata TT" end,
        GetFontPath = function(face) return "Fonts/" .. face end,
        LanguageChoices = function() return { { "enUS", "English" }, { "frFR", "Français" } } end,
        ResolveLocale = function(locale) return locale or "enUS" end,
        LoadedLocale = function() return "enUS" end,
        SecureReloadParent = function() return env.UIParent end,
        Fade = noop,
    }
    ui.dialogs = dialogs
    env.GetLocale = function() return "enUS" end
    env.SettingsTooltip = env.CreateFrame("GameTooltip", "SettingsTooltip", env.UIParent)
    env.SettingsTooltip:Hide()
    ns.OwnGameTooltip = function(owner, anchor) env.GameTooltip:SetOwner(owner, anchor) end
    local media = {
        List = function(_, kind) return kind == "font" and { "Friz Quadrata TT", "Custom" } or {} end,
        Fetch = function(_, kind, name) return kind .. "/" .. name end,
    }
    env.LibStub = function(name)
        if name == "LibSharedMedia-3.0" then return media end
        if name == "FlareEditMode" then return ui.editMode end
    end
    env.C_Texture = { GetAtlasInfo = function(atlas) return atlas and { width = 24, height = 24 } end }
    env.C_UIFileAsset = { IsKnownFile = function(path) return path ~= nil end }
    env.SearchBoxTemplate_OnTextChanged = noop
    env.SearchBoxTemplate_OnEditFocusLost = noop
    env.SearchBoxTemplate_OnEditFocusGained = noop
    env.Menu = {}
    env.Enum = { UITextureSliceMode = { Stretched = 0 } }
    if configureClient then configureClient(ui, ns) end
    ui:load("Settings/Copy.lua", ns)
    ui:load("Settings/Registry.lua", ns)
    ui:load("Settings/Preview.lua", ns)
    ui:load("Settings/Fonts.lua", ns)
    return ui, ns
end

return setup
