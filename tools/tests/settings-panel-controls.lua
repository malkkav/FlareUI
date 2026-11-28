-- Exercise the panel's remaining control types through the public settings registry.
local setup = dofile("tools/tests/fixtures/settings-addon.lua")
local selectedFrame
local edit = { SelectFrame = function(_, frame) selectedFrame = frame; return true end }
local ui, ns = setup(function(state) state.editMode = edit end)
local E, S = ui.env, ns.Settings
ns.KeyText = tostring
local target = E.CreateFrame("Frame", "FlareUI_TestTarget", E.UIParent)
local db = { choice = "a", binding = "J", frame = true }
ns.db.profile.test = db
ns.defaults.profile.test = { choice = "a", binding = "J", frame = true }
local painted, built, refreshed, action = 0, 0, 0, 0
S:Module{ key = "about", group = "top", tabs = {
    { key = "controls" },
    { key = "wide", wide = true, preview = true, custom = function(host, preview)
        built = built + 1
        host.customLabel = host:CreateFontString()
        host.customLabel:SetText("Embedded controls")
        preview.customLabel = preview:CreateFontString()
        preview.customLabel:SetText("Embedded preview")
    end, refresh = function(host) assert(host.customLabel:IsVisible()); refreshed = refreshed + 1 end },
} }
ns.Copy.sections["about.controls"] = "Controls"
local function row(key, kind, def)
    def.key, def.section, def.kind = "about." .. key, "about.controls", kind
    return S:Row(def)
end
local style = row("styles", "styles", { path = "test.choice", choices = { { "a", "First" }, { "b", "Second" } }, previewFont = "test.font" })
row("binding", "keybind", { path = "test.binding" })
row("frame", "frame", { path = "test.frame", reload = true, frame = function() return target end })
row("legend", "legend", { lines = function() return { "Left to move", "Right to equip" } end })
row("buttons", "buttons", { fitButtonsWidth = 180, buttons = {
    { text = "A long button label that needs room" },
    { text = "Action", onClick = function() action = action + 1 end },
    { text = "Unavailable", disabled = function() return true end },
} })
row("note", "text", { noTitle = true, textFn = function() return "* First note\n* Second note with `code`" end })
ns.SettingsPreview.renderers.font = function(canvas, spec)
    painted = painted + 1
    canvas:Text("sample", spec.value or "", 8, 8)
end
ui:load("Settings/PadNav.lua", ns)
ui:load("Settings/Panel.lua", ns)
local P = ns.SettingsPanel
P:Open()
local window = E.FlareUI_SettingsPanel
local function rowFrame(key)
    return assert(ui:find(function(w) return w.row and w.row.key == "about." .. key and w:IsVisible() end), key)
end

local cards = rowFrame("styles").cards
assert(cards[1].tick:IsShown() and not cards[2].tick:IsShown() and painted >= 2)
cards[2]:Click()
assert(style:Get() == "b" and cards[2].tick:IsShown() and not cards[1].tick:IsShown())
assert(rowFrame("legend").lines:GetText() == "Left to move\nRight to equip")
assert(rowFrame("note").body:GetText() == "• First note\n• Second note with |cffffd100code|r")
local buttons = rowFrame("buttons").buttons
buttons[2]:Click()
buttons[3]:Click()
assert(action == 1 and not buttons[3]:IsEnabled(), "buttons route independently and respect disabled state")
local section = assert(ui:find(function(w) return w.kind == "section" and w.sectionKey == "about.controls" and w:IsVisible() end))
section:RunScript("OnMouseUp")
assert(not ui:find(function(w) return w.row and w.row.key == "about.styles" and w:IsVisible() end))
section:RunScript("OnMouseUp")
assert(rowFrame("styles"):IsVisible())
section.reset:Click()
local reset = ui.dialogs[#ui.dialogs]
assert(reset.key == "FLAREUI_RESET_SECTION" and reset.data.section == "about.controls")
ui.combat = true
ns.Dialogs[reset.key].OnAccept(reset.data)
assert(db.choice == "b", "combat blocks resetting the section")
ui.combat = false
ns.Dialogs[reset.key].OnAccept(reset.data)
assert(db.choice == "a" and db.binding == "J" and db.frame, "reset restores the visible changed settings without clearing keybinds or reload values")

local key = rowFrame("binding").control
assert(key:GetText() == "J")
key:Click()
assert(ns.keyCapturing == key and key.keyboardEnabled and not key.propagate)
key:RunScript("OnKeyDown", "LSHIFT")
assert(key.waiting and db.binding == "J")
ui.shift = true
key:RunScript("OnMouseDown", "Button4")
assert(not ns.keyCapturing and db.binding == "SHIFT-BUTTON4")
ui.shift = false
key:Click()
key:RunScript("OnKeyDown", "ESCAPE")
assert(not ns.keyCapturing and db.binding == "SHIFT-BUTTON4")
key:Click("RightButton")
assert(db.binding == "" and key:GetText():find("Not bound", 1, true))

local width = window:GetWidth()
P:Open("about", "wide")
assert(window:GetWidth() > width and built == 1 and refreshed == 1)
P:Refresh()
assert(built == 1 and refreshed == 2, "custom tabs reuse their frames")
P:Open("about", "controls")
assert(window:GetWidth() == width and not ui:find(function(w) return w:GetText() == "Embedded controls" and w:IsVisible() end))
local frame = rowFrame("frame")
assert(frame.edit:IsEnabled())
ui.combat = true
ui:emit("PLAYER_REGEN_DISABLED")
ui:flushTimers()
assert(not frame.edit:IsEnabled() and frame.control:GetChecked())
ui.combat = false
ui:emit("PLAYER_REGEN_ENABLED")
assert(frame.edit:IsEnabled())
frame.edit:Click()
assert(selectedFrame == target and not P:IsShown(), "Edit selects its frame and quietly closes the panel")

ui.gamepad = true
E.IsKeyDown = function() return false end
ns.PadTriggerKey = function(which) return which == "LT" and "PADLTRIGGER" or "PADRTRIGGER" end
ns.PadComboKey = function(stick, side) return side .. "+" .. stick end
ns.PadBarKey = function(side, button) return side .. "+" .. button end
local captured
local stick = P.KeyButton(E.UIParent, function(value) captured = value end, nil, "stick")
stick:Click()
stick:RunScript("OnGamePadButtonDown", "PADLSHOULDER")
assert(stick.waiting and ui.errors[#ui.errors]:find("targeting", 1, true))
stick:RunScript("OnGamePadButtonUp", "PADLSHOULDER")
stick:RunScript("OnGamePadButtonDown", "PADLTRIGGER")
stick:RunScript("OnGamePadButtonDown", "PADRTRIGGER")
stick:RunScript("OnGamePadButtonDown", "PADRSTICK")
assert(captured == "LTRT+R3" and not stick.waiting)
local bar = P.KeyButton(E.UIParent, function(value) captured = value end, nil, "bar")
bar:Click()
bar:RunScript("OnGamePadButtonDown", "PAD2")
assert(not bar.waiting and captured == "LTRT+R3")
bar:Click()
bar:RunScript("OnGamePadButtonDown", "PADLTRIGGER")
bar:RunScript("OnGamePadButtonDown", "PAD2")
assert(captured == "LT+PAD2", "B cancels alone and is bindable with a trigger")

print("PASS: settings styles, section resets, custom tabs, Edit buttons and input capture")
