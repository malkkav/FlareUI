-- Exercise the normal settings window, including real registration data and saved values.
local setup = dofile("tools/tests/fixtures/settings-addon.lua")
local ui, ns = setup()
local E, S = ui.env, ns.Settings
local opened = {}
local function row(key) return assert(S.rows[key], key) end
local function widgetFor(key)
    return assert(ui:find(function(w) return w.row == row(key) and w:IsVisible() end), key)
end

ns.db.profile.chat = { frameStyle = "modern" }
S:On("PageShown", function(key) opened[#opened + 1] = key or false end)
S:Module{ key = "about", group = "top" }
ui:load("Settings/Pages/ActionBars.lua", ns)
ui:load("Settings/Pages/Chat.lua", ns)
ui:load("Settings/Pages/BagsLooting.lua", ns)
ui:load("Settings/Pages/CooldownManager.lua", ns)
ui:load("Settings/PadNav.lua", ns)
ui:load("Settings/Panel.lua", ns)

local P = ns.SettingsPanel
assert(not P:IsShown(), "the panel is created lazily")
P:Open("ch")
local frame = E.FlareUI_SettingsPanel
assert(P:IsShown() and frame:IsShown(), "opening shows the settings window")
assert(ns.db.global.settingsPage == "ch" and opened[#opened] == "ch", "opening persists and announces the page")
local turnOn = assert(ui:find(function(w) return w:GetText() == "Turn On" and w:IsVisible() and w:IsObjectType("Button") end))
assert(not ui:find(function(w) return w.row == row("ch.opacity") and w:IsVisible() end), "off modules display their card")
turnOn:Click()
assert(S:GetPath("chat.enabled") == true and S:PendingCount() == 1, "Turn On enables the module and requires a reload")
assert(frame.footer:IsVisible() and E.FlareUI_SettingsReload:IsShown(), "reload notice includes the secure button")

local opacity = widgetFor("ch.opacity")
opacity.slider:RunScript("OnMouseDown")
opacity.slider:SetValue(36)
assert(opacity.value:GetText() == "35%" and row("ch.opacity"):Get() == nil, "dragging previews opacity before saving")
opacity.slider:RunScript("OnMouseUp")
assert(row("ch.opacity"):Get() == 0.35, "releasing writes the selected opacity once")
local frameStyle = widgetFor("ch.frameStyle")
local styles = frameStyle.control:OpenMenu().entries
assert(#styles == 2 and styles[2].selected(styles[2].data), "the choice control selects the saved style")
styles[1].pick(styles[1].data)
assert(row("ch.frameStyle"):Get() == "flareui" and row("ch.border"):IsHidden(), "choosing FlareUI hides the redundant border control")
P:JumpTo(row("ch.font.text.size"))
assert(P:ActiveTab(S.modules.ch).key == "fonts", "jump opens the target tab")
assert(row("ch.font.text").isOpen() and widgetFor("ch.font.text.size"), "jump expands a collapsed font heading")
ui:flushTimers()

frame.search:SetText("channel")
ui:flushTimers()
local result = S:Search("channel")[1]
assert(result and ui:find(function(w) return w.row == result and w:IsVisible() end), "typing shows a real search result")
frame.search:RunScript("OnEnterPressed")
assert(frame.search:GetText() == "" and ns.db.global.settingsPage == result.module, "Enter opens the first search result")
frame.search:SetText("xyzznonexistent")
ui:flushTimers()
assert(ui:find(function(w) return w:GetText() == "No settings match." and w:IsVisible() end), "empty search results explain the state")
P:Select("ch")
assert(frame.search:GetText() == "", "selecting a page clears the search")
-- (11-24) tab names too long for the row (Russian): the longest are cut, the rest keep theirs
do
    local tabs = {}
    for i = 1, 7 do tabs[i] = { key = "t" .. i, label = i == 3 and string.rep("W", 60) or ("Name " .. i) } end
    S:Module{ key = "wide", group = "top", tabs = tabs }
    P:Open("wide")
    local widths, total, room = {}, 0, nil
    for i = 1, 7 do
        local b = assert(ui:find(function(w) return w.tabKey == "t" .. i and w:IsVisible() end))
        widths[i] = b:GetWidth()
        total = total + widths[i]
        room = b:GetParent():GetWidth()
    end
    assert(total <= room and widths[3] < 60 * 6, "they fit: " .. total .. " in " .. room)
    assert(widths[1] == widths[2] and widths[1] >= 6 * 6 + 12 and widths[3] > widths[1])
    P:Select("ch")
end

local scale = frame:GetScale()
P.ScaleStep(1)
assert(ns.db.global.panelScale == 1.05 and frame:GetScale() > scale, "scale persists in account settings")
ui.combat = true
P.ScaleStep(1)
assert(ns.db.global.panelScale == 1.05, "combat keeps the settings window scale stable")
ui.combat = false

P:OpenWhatsNew()
assert(frame.news:IsShown() and not frame.body:IsShown(), "What's New switches the window contents")
frame.topTabs[1]:Click()
assert(frame.body:IsShown() and not frame.news:IsShown(), "Settings restores the module page")
P:Hide()
assert(not P:IsShown() and #ui.dialogs == 0, "the Edit Mode hide path suppresses the reload reminder")
P:Open("ch")
P:Toggle()
assert(not P:IsShown() and ui.dialogs[#ui.dialogs].key == "FLAREUI_RELOAD_ON_CLOSE", "ordinary close warns about pending changes")
S.modules.ch:SetOn(false)
P:Open("ch")
assert(not frame.footer:IsShown() and not E.FlareUI_SettingsReload:IsShown(), "reverting the module toggle clears the reload footer")

-- (11-23, BearAE) the X closes the window in a fight too
P:Open("ch")
ui:flushTimers()
ui.combat = true
local x = assert(ui:find(function(w) return w.template == "UIPanelCloseButton" and w:GetParent() == frame end))
x:Click()
assert(not frame:IsShown(), "the X hides the window itself")
ui.combat = false

S:SetPath("tweaks.bagModule", true)
P:Open("bl", "bank")
local gearWarning = widgetFor("qol.warnSellSetGear")
local questWarning = widgetFor("qol.warnSellQuestItems")
local gearPoint, gearX, gearY = gearWarning:GetPoint()
local questPoint, questX, questY = questWarning:GetPoint()
assert(gearPoint == "TOPLEFT" and questPoint == "TOPLEFT" and gearY == questY and gearX < questX,
    "the Bank & Vendor tab shows the set-gear and quest-item warnings side by side")

print("PASS: settings panel navigation, search, widgets and reload")
