-- Launcher routes slash commands, key bindings, options, and the game menu.
local setup = dofile("tools/tests/fixtures/settings-addon.lua")
local ui, ns = setup()
local E, S = ui.env, ns.Settings
local calls, messages = {}, {}
local function record(key)
    return function(value) calls[#calls + 1] = { key, value } end
end
local function last(key, value)
    local item = calls[#calls]
    assert(item and item[1] == key and item[2] == value, key)
end
local panel = {
    Open = function(_, key) record("open")(key) end,
    Toggle = function() record("toggle")() end,
    Hide = record("hide"),
    NewBadge = function(parent) return E.CreateFrame("Frame", nil, parent, "NewFeatureLabelNoAnimateTemplate") end,
}
ns.SettingsPanel = panel
ns.FCMActive = function() return ui.fcm end
ns.ToggleFCMSetupMode, ns.ToggleGamepadMode, ns.ShowTour, ns.Reload = record("fcm"), record("pad"), record("tour"), record("reload")
ns.Perf, ns.TaintWatch, ns.SayLog = { Command = record("perf") }, { Command = record("taint") }, { Command = record("saylog") }
ns.ErrorsCommand = record("errors")
ns.Tweaks = { UIScale = { Reset = record("reset") } }
ns.Visibility = { DebugPlayer = function() record("fade")() end }
ns.Minimap = { DebugLayers = function() record("map")() end }
ns.RadialMenu = { PadLogCommand = record("padlog") }
ns.UnitFrames = { RangeReport = record("range"), ShiftManaTest = record("druidbar") }
ns.Nameplates = { Report = record("plates") }
ns.db.profile.tweaks = { enabled = true, way = true }
S:Module{ key = "ch", group = "interface" }
S:Row{ key = "ch.editBoxBorder", kind = "choice", path = "chat.editBoxBorder" }
E.print = function(text) messages[#messages + 1] = text end
E.SlashCmdList = {}
E.ERR_NOT_IN_COMBAT = "Not in combat"
E.C_AddOns.LoadAddOn = function(name)
    assert(name == "Blizzard_QuickKeybind")
    E.QuickKeybindFrame = E.CreateFrame("Frame", "QuickKeybindFrame", E.UIParent)
    E.QuickKeybindFrame:Hide()
end
E.HideUIPanel = function(frame) frame:Hide() end
E.GameFontNormal = E.CreateFont()
E.Settings = {
    RegisterCanvasLayoutCategory = function(frame, name) return { frame = frame, name = name } end,
    RegisterAddOnCategory = function(category) ui.category = category end,
}
E.SettingsPanel = E.CreateFrame("Frame", "SettingsPanel", E.UIParent)
local categoryFrame = E.CreateFrame("Frame", nil, E.SettingsPanel)
categoryFrame.Label = categoryFrame:CreateFontString()
categoryFrame.Label:SetText("FlareUI")
local list = {
    FindCategoryElementData = function(_, category) return category == ui.category and ui.category end,
    ScrollBox = { FindFrame = function() return categoryFrame end },
}
function E.SettingsPanel:GetCategoryList() return list end
function E.SettingsPanel:Close(skipMenu) assert(skipMenu); self:Hide() end
local gameMenu = E.CreateFrame("Frame", "GameMenuFrame", E.UIParent)
E.BLIZZARD_STORE, E.GAMEMENU_OPTIONS = "Shop", "Options"
function gameMenu:AddButton(text, click)
    local button = E.CreateFrame("Button", nil, self)
    button:SetText(text)
    button:SetScript("OnClick", click)
    button.layoutIndex = #self.buttons + 1
    table.insert(self.buttons, button)
    return button
end
function gameMenu:InitButtons()
    self.buttons = {}
    self:AddButton("Options")
    if not ui.shopDisabled then self:AddButton("Shop") end
    self:AddButton("Exit Game")
end
function gameMenu:MarkDirty() self.dirty = true end

ui:load("Launcher.lua", ns)
assert(E.BINDING_NAME_FLAREUI_SETTINGS == "Open Settings" and E.BINDING_HEADER_FLAREUI == "FlareUI")
ui:emit("PLAYER_LOGIN")
assert(E.SLASH_FLAREUI1 == "/flareui" and E.SLASH_FLAREUI2 == "/fui" and E.SLASH_FLARERL1 == "/rl" and E.SLASH_FLAREKB1 == "/kb")
assert(ui.category.frame == E.FlareUI_BlizzOptionsPanel and ui.category.name == "FlareUI")
local watcher = assert(ui:find(function(w) return w:GetParent() == E.SettingsPanel and w:GetScript("OnUpdate") end))
local tag = watcher:GetChildren()
watcher:RunScript("OnShow")
watcher:RunScript("OnUpdate", 0.1)
assert(tag:IsShown() and select(2, tag:GetPoint()) == categoryFrame.Label)
categoryFrame:Hide()
watcher:RunScript("OnUpdate", 0.1)
assert(not tag:IsShown(), "scrolling the Blizzard settings list away hides the badge")
categoryFrame = E.CreateFrame("Frame", nil, E.SettingsPanel)
categoryFrame.Label = categoryFrame:CreateFontString()
categoryFrame.Label:SetText("FlareUI")
watcher:RunScript("OnUpdate", 0.1)
assert(tag:IsShown() and select(2, tag:GetPoint()) == categoryFrame.Label, "the tag follows a recycled row")
S:MarkAllNewSeen()
watcher:RunScript("OnShow")
watcher:RunScript("OnUpdate", 0.1)
assert(not tag:IsShown())
local configuration = assert(ui:find(function(w) return w:IsObjectType("Button") and w:GetText() == "Open Configuration" end))
configuration:Click()
last("open")
assert(not E.SettingsPanel:IsShown())

local command = E.SlashCmdList.FLAREUI
local actions = {
    { " ", "toggle" }, { "CM", "fcm" }, { "gamepad", "pad" }, { "tour", "tour" }, { " BUFFS ", "open", "br" },
    { "perf RecordA", "perf", " RecordA" }, { "fadedebug", "fade" }, { "mapdebug", "map" }, { "scale reset", "reset" },
    { "errors CLEAR", "errors", "clear" }, { "taint START", "taint", " start" }, { "padlog", "padlog" },
    { "saylog SHOW", "saylog", " show" }, { "range", "range" }, { "plates", "plates" }, { "druidbar", "druidbar" },
}
for _, action in ipairs(actions) do command(action[1]); last(action[2], action[3]) end
ui.fcm = true
command("nonsense")
local help = table.concat(messages, "\n")
assert(help:find("/fui cm", 1, true) and help:find("/way", 1, true), "help includes enabled optional commands")
E.SlashCmdList.FLARERL()
last("reload")
ui.combat = true
command("kb")
assert(not E.QuickKeybindFrame and ui.errors[#ui.errors] == "Not in combat")
ui.combat = false
E.SlashCmdList.FLAREKB()
assert(E.QuickKeybindFrame:IsShown())
assert(calls[#calls][1] == "hide")

gameMenu:InitButtons()
assert(#gameMenu.buttons == 3, "the Escape menu entry is off by default")
ns.db.global.escMenuButton = true
gameMenu:InitButtons()
local entry = gameMenu.buttons[4]
assert(gameMenu.dirty and entry:GetText() == "FlareUI" and entry.layoutIndex == 2.5)
entry:Click()
last("open")
assert(not gameMenu:IsShown())
ui.shopDisabled = true
gameMenu:InitButtons()
assert(gameMenu.buttons[3].layoutIndex == 1.5, "without Shop the entry goes after Options")
local wasPad = ns.IsGamepadUI
ns.IsGamepadUI = function() return true end
gameMenu:InitButtons()
assert(#gameMenu.buttons == 2, "no entry in the Gamepad UI's game menu")
ns.IsGamepadUI = wasPad

E.FlareUI_ToggleSettings()
last("toggle")
E.FlareUI_OnAddonCompartmentClick(nil, "RightButton")
last("fcm")
E.FlareUI_OnAddonCompartmentClick(nil, "LeftButton")
last("toggle")
E.FlareUI_OnAddonCompartmentEnter(nil, entry)
assert(E.GameTooltip:IsShown() and E.GameTooltip:GetOwner() == entry and #E.GameTooltip.lines == 3)
E.FlareUI_OnAddonCompartmentLeave()
assert(not E.GameTooltip:IsShown())

local pad, padNS = setup()
pad.gamepad = true
local P = pad.env
P.SlashCmdList = { OTHER = function() end }
P.SLASH_OTHER1 = "/KB"
local added
P.Settings = {
    RegisterCanvasLayoutCategory = E.Settings.RegisterCanvasLayoutCategory,
    RegisterAddOnCategory = function(category) added = category end,
}
P.EventUtil = { ContinueOnAddOnLoaded = function(name, f) assert(name == "Blizzard_GameMenu"); pad.loadMenu = f end }
pad:load("Launcher.lua", padNS)
pad:emit("PLAYER_LOGIN")
assert(added and not P.SLASH_FLAREKB1 and P.SlashCmdList.OTHER and pad.loadMenu,
    "Gamepad startup preserves an existing /kb command and can wait for Blizzard's game menu")
assert(pad:find(function(w) return w:GetText():find("minimap's addon button", 1, true) ~= nil end))
assert(not pad:find(function(w) return w:GetText() == "Open Configuration" end))

print("PASS: launcher entry points, gamepad alternatives, settings badge and command conflicts")
