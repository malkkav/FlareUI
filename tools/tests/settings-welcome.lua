-- First login and About exercise the real setup tour and its deferred save.
local setup = dofile("tools/tests/fixtures/settings-addon.lua")
local ui, ns = setup()
local E, S = ui.env, ns.Settings
local gameMeter, copied
E.C_CVar = {
    GetCVarBool = function(key) assert(key == "damageMeterEnabled"); return gameMeter end,
    SetCVar = function(key, value) assert(key == "damageMeterEnabled"); gameMeter = value == "1" end,
}
E.ERR_NOT_IN_COMBAT = "Not in combat"
ns.Chat = { ShowCopyText = function(text) copied = text end }
ns.HEALTH_GREEN = { 0, 1, 0 }
local moduleKeys = { "uf", "ab", "au", "br", "rb", "rm", "qol", "bl", "ch", "dm", "mm", "qt", "tt" }
for _, key in ipairs(moduleKeys) do
    S:Module{ key = key, group = "interface", enabled = key .. ".enabled" }
end
S:Row{ key = "uf.frameStyle", path = "uf.style", kind = "styles", reload = true }
S:Row{ key = "qol.move", path = "qol.move" }
S:Row{ key = "qol.sync", path = "qol.sync" }
ui:load("Settings/EditModeLayout.lua", ns)
ui:load("Settings/Pages/About.lua", ns)
ui:load("Settings/PadNav.lua", ns)
ui:load("Settings/Panel.lua", ns)
ui:load("Settings/Welcome.lua", ns)

local function button(text)
    return assert(ui:find(function(w) return w:IsObjectType("Button") and w:GetText() == text and w:IsVisible() end), text)
end
local function control(key)
    return assert(ui:find(function(w) return w.key == key and w:IsObjectType("CheckButton") and w:IsVisible() end), key)
end

ui:emit("PLAYER_LOGIN")
assert(not E.FlareUI_Tour and not ns.db.global.welcomeSeen, "a fresh account waits for the loading screen")
ui:flushTimers()
local tour = assert(E.FlareUI_Tour)
assert(tour:IsShown())
button("Show Me Around"):Click()
assert(control("uf"):GetChecked() and not S.modules.uf:IsOn(), "the fresh proposal leaves saved modules alone")
local forever = assert(ui:find(function(w) return w.value == "forever" and w.tick and w:IsVisible() end))
control("uf"):Click()
assert(not forever:IsEnabled(), "style controls follow the unit frame switch")
control("uf"):Click()
forever:Click()
assert(forever.tick:IsShown())
button("Next"):Click()
assert(not control("rb"):GetChecked() and not control("br"):GetChecked(), "Resource Bars and Buff Reminders require an explicit choice")
control("rb"):Click()
button("Next"):Click()
assert(ui:find(function(w) return w:GetText() == "/fui" and w:IsVisible() end), "Edit Mode page shows both settings locations")
button("Next"):Click()
button("Copy Layout Code"):Click()
assert(copied == ns.EditModeLayout.code and copied:find("UIParent", 1, true), "layout button copies the exported layout")
button("Next"):Click()
assert(control("ch"):GetChecked() and control("dm"):GetChecked())
control("ch"):Click()
button("Next"):Click()
assert(control("mm"):GetChecked() and control("qt"):GetChecked())
button("Next"):Click()
assert(control("rm"):GetChecked())
button("Next"):Click()
control("move"):Click()
control("sync"):Click()
button("Next"):Click()
local reload = assert(E.FlareUI_TourReload)
assert(reload:IsShown() and reload:GetAttribute("macrotext") == "/stopmacro [combat]\n/reload")
assert(not S.modules.rb:IsOn() and S:GetPath("qol.move") == nil and not gameMeter,
    "the summary still has no effect on saved values")
ui.combat = true
reload:RunScript("PreClick")
assert(#ui.errors == 1 and not S.modules.rb:IsOn(), "a combat press leaves choices uncommitted")
ui.combat = false
reload:RunScript("PreClick")
assert(S.modules.uf:IsOn() and S:GetPath("uf.style") == "forever" and S.modules.rb:IsOn() and not S.modules.ch:IsOn())
assert(S:GetPath("qol.move") and S:GetPath("qol.sync") and gameMeter and ns.reloading)
assert(ns.db.global.welcomeSeen and ns.db.global.tourRadialKeys, "the next login will offer to configure the newly enabled radial's key")

tour:Hide()
assert(not reload:IsShown())
ns.SettingsPanel:Open("about")
button("Wago.io"):Click()
assert(copied == "https://addons.wago.io/addons/flareui", "About opens its listed site in the copy box")
button("Start Tour"):Click()
assert(tour:IsShown() and not ns.SettingsPanel:IsShown())
button("Show Me Around"):Click()
button("Next"):Click()
assert(control("rb"):GetChecked(), "a repeated tour starts with existing choices")
control("rb"):Click()
tour:Hide()
assert(S.modules.rb:IsOn(), "closing the repeated tour discards unsaved edits")

print("PASS: setup tour first login, saved choices, combat and About")
