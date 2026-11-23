-- Controller navigation in FlareUI windows and dropdown lists.
local setup = dofile("tools/tests/fixtures/settings-addon.lua")
local ui, ns = setup()
local E, S = ui.env, ns.Settings
ui.gamepad = true
ns.KeyText = tostring
ui:load("Settings/PadNav.lua", ns)
local pad = ns.PadNav
local window = E.CreateFrame("Frame", nil, E.UIParent)
local header = E.CreateFrame("Button", nil, window)
header.left, header.top = 0, 600
local scroll = E.CreateFrame("ScrollFrame", nil, window)
scroll:SetHeight(120)
local content = E.CreateFrame("Frame", nil, scroll)
content:SetHeight(400)
scroll:SetScrollChild(content)

local function control(kind, parent, left, top)
    local object = E.CreateFrame(kind, nil, parent)
    object:SetSize(30, 20)
    object.left, object.top = left, top
    return object
end
local initial = control("Button", content, 30, 475)
local skipped = control("Button", content, 0, 485)
skipped.padSkip = true
local disabled = control("Button", content, 1, 495)
disabled:Disable()
local slider = control("Slider", content, 120, 475)
local rowBox = E.CreateFrame("Frame", nil, content)
S:Module{ key = "test", group = "interface" }
local row = S:Row{ key = "test.choice", kind = "choice", path = "test.choice", choices = { "a", { divider = true }, "b" } }
rowBox.row = row
local dropdown = control("DropdownButton", rowBox, 120, 395)
local tab, page, clicks, hovered, removed = 0, 0, 0, 0, 0
initial:SetScript("OnEnter", function() hovered = hovered + 1 end)
initial:SetScript("OnClick", function() clicks = clicks + 1 end)
initial.padX = function() removed = removed + 1 end
slider:SetMinMaxValues(0, 3)
slider.padCycle = function(delta) slider:SetValue(math.max(0, math.min(3, slider:GetValue() + delta))) end
pad.Attach(window, {
    close = function() window:Hide() end,
    tab = function(delta) tab = tab + delta end,
    page = function(delta) page = page + delta end,
    start = function() return content end,
})
local listener = assert(E.FlareUI_PadNav)
local function press(key) listener:RunScript("OnGamePadButtonDown", key) end
local function up(key) listener:RunScript("OnGamePadButtonUp", key) end
local ring = assert(ui:find(function(w) return w.edges ~= nil end))
local function focused() local _, object = ring:GetPoint(); return object end
ui:flushTimers()
assert(window.smartNavigationIgnored and listener.gamepadEnabled and focused() == initial and hovered == 1,
    "controller focus starts on an enabled content control")
press("PAD1")
assert(clicks == 1 and listener.propagate == false)
press("PAD3")
assert(removed == 1)
press("PADDRIGHT")
assert(focused() == slider)
up("PADDRIGHT")
press("PAD1")
press("PADDRIGHT")
assert(slider:GetValue() == 1, "a grabbed slider steps horizontally")
ui.time = 100.4
listener:RunScript("OnUpdate", 0.4)
assert(slider:GetValue() == 2, "a held direction repeats")
up("PADDRIGHT")
press("PAD2")
assert(window:IsShown(), "Back releases an adjustment before closing the window")
press("PADDDOWN")
assert(focused() == dropdown and scroll:GetVerticalScroll() > 0, "focus reveals a control deeper in the scroller")
up("PADDDOWN")
press("PAD1")
press("PADDRIGHT")
assert(row:Get() == "a")
up("PADDRIGHT")
press("PADDRIGHT")
assert(row:Get() == "b", "a dropdown skips dividers while stepping")
up("PADDRIGHT")
press("PADRSHOULDER")
press("PADLTRIGGER")
ui:flushTimers()
assert(tab == 1 and page == -1)
ui.dialogOpen = true
press("PAD1")
assert(clicks == 1 and listener.propagate, "the settings listener yields to an open dialog")
ui.dialogOpen = false
ui.combat = true
ui:emit("PLAYER_REGEN_DISABLED")
assert(not listener.gamepadEnabled and not ring:IsShown())
ui.combat = false
ui:emit("PLAYER_REGEN_ENABLED")
ui:flushTimers()
assert(listener.gamepadEnabled and ring:IsShown())

local closings, ticks = 0, 0
local entries = { { divider = true } }
for i = 2, 21 do
    entries[i] = {
        text = "Option " .. i, multi = i == 18, checked = function() return (i == 18 and ticks == 18) or i == 20 end,
        pick = function() ticks = i end,
    }
end
pad.GuardDropdown(dropdown, function() return entries end, function() closings = closings + 1 end)
dropdown.padCatcher:Click()
local list = pad.list
assert(list:IsShown() and list.offset == 5 and list.rows[15].tick:IsShown(),
    "a long menu opens with its selected value in view")
list.rows[13]:Click()
assert(list:IsShown() and ticks == 18 and list.rows[13].tick:IsShown(), "multi-select updates without closing")
list:RunScript("OnMouseWheel", 5)
assert(list.offset == 0 and list.rows[1].line:IsShown() and not list.rows[1].text:IsShown())
list.rows[2]:Click()
assert(not list:IsShown() and ticks == 2 and closings == 1)
dropdown.padCatcher:Click()
list.mouseOver = true
ui:emit("GLOBAL_MOUSE_DOWN")
assert(list:IsShown())
list.mouseOver = nil
ui:emit("GLOBAL_MOUSE_DOWN")
assert(not list:IsShown() and closings == 2, "an outside click closes the list")
dropdown:Disable()
dropdown.padCatcher:Click()
assert(not list:IsShown())
press("PAD2")
assert(not window:IsShown() and not listener.gamepadEnabled, "closing the window releases the controller")

ui:load("Settings/Panel.lua", ns)
ui:load("Settings/Welcome.lua", ns)
ui:emit("PLAYER_LOGIN")
ui:flushTimers()
ui:flushTimers()
assert(E.FlareUI_Welcome:IsShown() and not E.FlareUI_Tour, "Gamepad UI uses the welcome pop-up")
press("PAD2")
assert(not E.FlareUI_Welcome:IsShown() and ns.db.global.welcomeSeen, "Back dismisses and records the welcome")

print("PASS: gamepad focus, repeat, dropdowns, combat and welcome")
