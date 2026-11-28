local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local controller, gamepad = nil, false
local messages, vibration, actions, bindings, changes = {}, {}, {}, {}, {}
env.print = function(text) messages[#messages + 1] = text end
env.GetLocale = function() return "enUS" end
env.NUM_CHAT_WINDOWS = 1
env.LibStub = function() return { IsInEditMode = function() return false end } end
env.C_AddOns.IsAddOnLoaded = function(name) return name == controller end
env.C_InputInterfaceStyle = { GetCurrentStyle = function() return gamepad and 1 or 0 end }
env.Enum = { InputDeviceInterfaceType = { Gamepad = 1 } }
env.SetCVar = function(key, value) changes[#changes + 1] = { key, value } end
env.GetBindingKey = function(action, mode)
    assert(mode == 1)
    if action == "GAMEPADLEFTMOD" then return "PADLSHOULDER" end
end
local labels = { PADLSHOULDER = "LB", PADRTRIGGER = "RT", PADLSTICK = "L3", PADRSTICK = "R3", PAD1 = "A", PAD2 = "B", PAD3 = "X" }
env.GetBindingText = function(key) return labels[key] or key end
env.RegisterStateDriver = function(widget, attribute, rule) widget.driver = { attribute, rule } end
env.SetOverrideBindingClick = function(_, _, key, button) bindings[key] = button end
env.SetOverrideBinding = function(_, _, key, action) assert(not ui.combat and action == nil); bindings[key] = nil end
env.ClearOverrideBindings = function() env.wipe(bindings) end
env.UnitIsUnit = function(a, b) return a == b end
env.canaccessvalue = function() return true end
env.ReloadUI = function() error("reload blocked") end
env.C_GamePad = {
    SetVibration = function(kind, strength) vibration[#vibration + 1] = { kind, strength } end,
    StopVibration = function() vibration[#vibration + 1] = "stop" end,
}
local makeFrame = env.CreateFrame
env.CreateFrame = function(kind, name, parent, template)
    local f = makeFrame(kind, name, parent, template)
    function f:SetPropagateKeyboardInput(value) self.propagate = value end
    function f:GetPropagateKeyboardInput() return self.propagate end
    return f
end
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    Settings = { ButtonWidthForText = function(button, default) return math.max(default, #button:GetText() * 8) end },
    db = { profile = { tweaks = { gamepadPrompt = true, rumbleAlerts = true, rumbleProcs = true } } },
}
ui:load("Core.lua", ns)
ui:load("Dialog.lua", ns)
ui:load("GamepadMode.lua", ns)

local function record(action)
    return function(data, text) actions[#actions + 1] = { action, data, text } end
end
ns.Dialogs.EDIT = {
    text = "Rename %s", button1 = "Save", button2 = "Cancel", button3 = "Reset",
    hideOnEscape = true, hasEditBox = true, maxLetters = 12, showAlert = true, readable = true,
    editText = function(data) return data.initial end,
    OnAccept = record("save"), OnCancel = record("cancel"), OnAlt = record("reset"),
}
local data = { initial = "Old" }
env.UIParent:SetScale(0.5)
ns.ShowDialog("EDIT", "profile", data)
local dialog = env.FlareUIDialog
assert(dialog.Text:GetText() == "Rename profile" and dialog.Alert:IsShown() and dialog:GetScale() > 1)
assert(dialog.EditBox:GetText() == "Old" and dialog.EditBox:HasFocus())
dialog.EditBox:SetText("New")
dialog.EditBox:RunScript("OnEnterPressed")
assert(not ns.AnyDialogShown() and not dialog.EditBox:HasFocus())
assert(actions[1][1] == "save" and actions[1][2] == data and actions[1][3] == "New")
ns.ShowDialog("EDIT", "profile", data)
dialog.Button3:Click()
assert(actions[2][1] == "reset" and not dialog:IsShown())
ns.ShowDialog("EDIT", "profile", data)
dialog:RunScript("OnKeyDown", "ESCAPE")
assert(actions[3][1] == "cancel" and not dialog:IsShown())
ns.ShowDialog("EDIT", "profile", data)
ns.CancelDialog("OTHER")
assert(dialog:IsShown())
ns.CancelDialog("EDIT")
assert(actions[4][1] == "cancel")
ns.ShowDialog("EDIT", "profile", data)
dialog:Hide()
assert(#actions == 4, "Closing without choosing an answer does not run a callback")

ns.Dialogs.SECURE = {
    text = "Switch layout", button1 = "Switch", button2 = "Later", padSecure = true,
    macro = function(info) return "/run C_EditMode.SetActiveLayout(" .. info.index .. ")" end,
    OnMacro = record("macro"), OnAccept = record("fallback"),
}
ns.ShowDialog("SECURE", nil, { index = 3 })
local secure = env.FlareUIDialogReload
assert(secure:IsShown() and not dialog.Button1:IsShown() and not dialog.Pad.gamepadEnabled)
assert(secure:GetAttribute("macrotext") == "/stopmacro [combat]\n/run C_EditMode.SetActiveLayout(3)")
assert(bindings.ENTER == secure:GetName() and bindings.PAD1 == secure:GetName() and bindings.PAD2 == "FlareUIDialogPadNo")
assert(env.FlareUI_ReloadParent.driver[2] == "[combat] hide; show")
secure:RunScript("PreClick", "LeftButton", true)
secure:RunScript("PostClick")
assert(actions[5][1] == "macro" and actions[5][2].index == 3 and not ns.AnyDialogShown())
assert(not next(bindings), "Override bindings are released when the dialog closes")

ns.Dialogs.RELOAD = { text = "Reload", reloads = true, hideOnEscape = true, OnAccept = record("reload") }
ns.ShowDialog("RELOAD")
assert(secure:IsShown() and not dialog.Button1:IsShown())
ui.combat = true
ui:emit("PLAYER_REGEN_DISABLED")
assert(dialog.Button1:IsShown())
dialog.Button1:Click()
assert(actions[6][1] == "reload" and ns.reloading and secure:GetAlpha() == 0)
ui:flushTimers()
assert(not ns.reloading and messages[#messages]:find("/reload", 1, true))
ui.combat = false
ui:emit("PLAYER_REGEN_ENABLED")
assert(not secure:IsShown() and not next(bindings))

-- The Gamepad UI (11-23): a reload answered with A must be a secure press, the third answer is X, and a
-- fight gives A and B back to the game
do
    gamepad = true
    ns.Dialogs.PADRELOAD = { text = "Reload", reloads = true, hideOnEscape = true, button3 = "Never", OnAlt = record("never"), OnCancel = record("later") }
    ns.ShowDialog("PADRELOAD")
    assert(not dialog.Pad.gamepadEnabled and bindings.PAD1 == secure:GetName() and bindings.PAD2 == "FlareUIDialogPadNo" and bindings.PAD3 == "FlareUIDialogPadAlt")
    assert(secure:GetAttribute("macrotext") == "/stopmacro [combat]\n/reload" and dialog.Button3:GetText() == "X Never")
    ui:emit("PLAYER_REGEN_DISABLED")   -- (still before the lockdown)
    assert(not bindings.PAD1 and not bindings.PAD2 and not bindings.PAD3 and dialog.Button1:IsShown(), "a fight: the bar's buttons work")
    ui.combat = true
    ui.combat = false
    ui:emit("PLAYER_REGEN_ENABLED")
    assert(bindings.PAD1 == secure:GetName() and not dialog.Button1:IsShown())
    env.FlareUIDialogPadAlt:Click()
    assert(actions[#actions][1] == "never" and not ns.AnyDialogShown() and not next(bindings))
    ns.ShowDialog("PADRELOAD")
    env.FlareUIDialogPadNo:Click()
    assert(actions[#actions][1] == "later" and not next(bindings))
    -- a plain dialog reads the pad itself with a listener that passes nothing on (a passed-on press runs the
    -- game's action as ours and breaks its controller code until a /reload), off in a fight
    ns.ShowDialog("EDIT", "profile", data)
    assert(dialog.Pad.gamepadEnabled)
    local before = #actions
    assert(not dialog.Pad.propagate)
    dialog.Pad:RunScript("OnGamePadButtonDown", "PADLSHOULDER")
    assert(not dialog.Pad.propagate and dialog:IsShown(), "another button isn't passed on either")
    ui:emit("PLAYER_REGEN_DISABLED")
    ui.combat = true
    assert(not dialog.Pad.gamepadEnabled, "a fight: the pad is the game's")
    dialog.Pad:RunScript("OnGamePadButtonDown", "PAD1")
    dialog.Pad:RunScript("OnGamePadButtonDown", "PAD2")
    assert(#actions == before and dialog:IsShown())
    ui.combat = false
    ui:emit("PLAYER_REGEN_ENABLED")
    assert(dialog.Pad.gamepadEnabled)
    dialog.Pad:RunScript("OnGamePadButtonDown", "PAD3")
    assert(actions[#actions][1] == "reset" and not dialog:IsShown() and not dialog.Pad.gamepadEnabled)
    -- Blizzard's navigation is kept off frames through its own call, after a fight if need be
    local marked = {}
    env.SmartNavigation_MarkFrameIgnored = function(w) assert(not ui.combat); marked[#marked + 1] = w end
    ns.IgnorePadNav(dialog)
    ui.combat = true
    ns.IgnorePadNav(dialog.Pad)
    assert(#marked == 1)
    ui.combat = false
    ui:emit("PLAYER_REGEN_ENABLED")
    assert(marked[1] == dialog and marked[2] == dialog.Pad and dialog.smartNavigationIgnored == nil)
    gamepad = false
    ns.ShowDialog("PADRELOAD")
    assert(not bindings.PAD1, "outside the Gamepad UI the pad's buttons stay other addons'")
    dialog:Hide()
end

assert(ns.PadStickKey("L3") == "PADLSTICK" and ns.PadComboKey("L3", "TOP") == "PADCOMBO-L3")
local stick, side = ns.ParsePadCombo(ns.PadComboKey("R3", "LTRT"))
assert(stick == "R3" and side == "LTRT" and ns.KeyText("PADCOMBO-LTRT-R3") == "LB + RT + R3")
assert(not ns.ParsePadCombo("PADCOMBO-INVALID-L3") and not ns.ParsePadBar("PADBAR-ZZ-PAD1"))
assert(ns.KeyText(ns.PadBarKey("RT", "PAD1")) == "RT + A" and ns.KeyText("F1") == "F1" and ns.KeyText(nil) == "")

ui:emit("PLAYER_ENTERING_WORLD", true)
ui:flushTimers()
assert(messages[#messages]:find("7.0.4", 1, true))
controller = "ConsolePort"
ui:emit("GAME_PAD_ACTIVE_CHANGED", true)
assert(ns.OtherControllerAddon() == "ConsolePort" and not ns.AnyDialogShown())
controller, ui.combat = nil, true
ui:emit("GAME_PAD_ACTIVE_CHANGED", true)
assert(not ns.AnyDialogShown())
ui.combat = false
ui:emit("PLAYER_REGEN_ENABLED")
assert(ns.AnyDialogShown() and dialog.Button1:GetText() == "A Switch")
dialog.Pad:RunScript("OnGamePadButtonDown", "PAD1")
assert(not ns.AnyDialogShown() and changes[1][1] == "InputDeviceInterfaceStyle" and changes[1][2] == 1)
ui:flushTimers()
assert(messages[#messages]:find("The switch did not go through", 1, true))
gamepad = true
ns.ToggleGamepadMode()
assert(dialog.Text:GetText():find("keyboard and mouse", 1, true))
dialog.Pad:RunScript("OnGamePadButtonDown", "PAD2")
assert(not ns.AnyDialogShown())

ui:emit("READY_CHECK", "player")
assert(#vibration == 0)
ui:emit("READY_CHECK", "party1")
assert(vibration[1][1] == "High")
local alertTicker = ui.timers[#ui.timers]
ui:emit("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 123)
assert(alertTicker.cancelled and vibration[2][1] == "Low")
ui:emit("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 124)
assert(#vibration == 2, "Consecutive procs share a rumble throttle")
local pulseTicker = ui.timers[#ui.timers]
pulseTicker.callback(pulseTicker)
pulseTicker.callback(pulseTicker)
assert(pulseTicker.cancelled and vibration[#vibration] == "stop")
print("PASS: dialogs, secure bindings, controller mode prompts and rumble")
