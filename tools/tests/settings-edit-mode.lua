-- Settings links its own frames to Edit Mode and keeps binding changes outside combat.
local setup = dofile("tools/tests/fixtures/settings-addon.lua")
local edit = { SettingType = { Divider = "divider", Expander = "expander" }, callbacks = {}, buttons = {} }
local function configure(ui) ui.editMode = edit end
local ui, ns = setup(configure)
local E, S = ui.env, ns.Settings
local frame = E.CreateFrame("Frame", "UnitFrame", E.UIParent)
local manager = E.CreateFrame("Frame", "EditModeManagerFrame", E.UIParent)
manager:Hide()
local canEnter = true
function manager:CanEnterEditMode() return canEnter end
E.ShowUIPanel = function(panel) panel:Show() end
E.HideUIPanel = function(panel) panel:Hide() end
local opened = {}
local panelShown, refreshes = true, 0
ns.SettingsPanel = {
    IsShown = function() return panelShown end,
    Hide = function() panelShown = false end,
    Open = function(_, key) opened[#opened + 1] = key; panelShown = true end,
    Refresh = function() refreshes = refreshes + 1 end,
}
function edit:GetFrameSettings(which)
    assert(which == frame)
    return {
        { name = "Fade Speed", hidden = function(layout) return layout == "Fading Off" end },
        { name = "Layout Balance", search = "Relative Offset" },
        { kind = "divider", name = "Skip Divider" },
    }
end
function edit:GetActiveLayoutName() return self.layout end
function edit:GetFrameName(which) return which:GetName() end
function edit:SelectFrame(which)
    assert(which == frame)
    manager:Show()
    return true
end
function edit:AddFrameSettingsButton(which, option) self.buttons[which] = option end
function edit:RegisterCallback(key, f) self.callbacks[key] = f end
edit.systemSettings = { [1] = { { name = "Size Method" }, { name = "|cffff0000Hidden Note|r" } } }
edit.subSystemSettings = { [2] = { [1] = { { search = "Fade Direction" }, { kind = "expander", name = "Skip Expander" } } } }

S:Module{ key = "sample", group = "combat", editFrames = { function() return frame end }, editSystems = function()
    return { { system = 1, name = "Action Bar" }, { system = 2, index = 1, name = "Secondary Bar" } }
end }
ns.Copy.rows["sample.fade"] = { label = "Fade Speed", desc = "Rate at which the frame fades.", tip = "The slider is adjustable." }
S:Row{ key = "sample.edit", kind = "frame", frame = function() return frame end }
ns.db.global = {}
local rows = S.modules.sample:EditModeRows()
assert(#rows == 4, "Edit Mode search deduplicates frames and omits structural labels")
assert(rows[1]:Label() == "Fade Speed" and rows[1]:Description() == "Rate at which the frame fades." and rows[1]:Tip() == "The slider is adjustable.")
assert(rows[2]:Label() == "Relative Offset" and rows[3].frame == nil and rows[4].frameName == "Secondary Bar")
assert(rows[1]:Get() == nil and not rows[1]:IsDisabled())
local result = S:Search("fade direction")
assert(#result == 1 and result[1] == rows[4], "system settings participate in the ordinary settings search")
edit.layout = "Fading Off"
assert(rows[1]:IsHidden() and #S:Search("fade speed") == 0)
ui:emit("PLAYER_LOGIN")
assert(not edit.buttons[frame], "the player login defers linking until frames exist")
ui:flushTimers()
local back = assert(edit.buttons[frame])
assert(back.text ~= "" and not S:LinkEditMode())

assert(S:EditFrame(frame, "sample") and manager:IsShown() and not panelShown)
edit.callbacks.enter()
assert(S.modules.sample:EditModeRows() ~= rows, "entering Edit Mode invalidates the search cache")
edit.callbacks.exit()
assert(#opened == 0)
ui:flushTimers()
assert(opened[1] == "sample" and panelShown, "leaving Edit Mode reopens the originating page")
back.click()
assert(not manager:IsShown() and opened[2] == "sample")
canEnter = false
assert(not S:OpenEditMode("sample"))
canEnter = true
assert(S:OpenEditMode("sample") and manager:IsShown() and not panelShown)
ui.gamepad = true
assert(not S:CanEditFrames() and not S:EditFrame(frame, "sample"))
ui.gamepad = false
ui.combat = true
edit.callbacks.exit()
ui:flushTimers()
assert(#opened == 2 and not S:CanEditFrames(), "combat blocks protected Edit Mode operations")

local set = { A = "TARGET", B = "TARGET", C = "OTHER" }
E.GetBindingKey = function(action)
    local keys = {}
    for key, value in pairs(set) do if value == action then keys[#keys + 1] = key end end
    table.sort(keys)
    return unpack(keys)
end
E.GetBindingAction = function(key) return set[key] or "" end
E.GetBindingName = function(action) return action == "OTHER" and "Existing Action" or action end
E.GetBindingText = function(key) return "[" .. key .. "]" end
E.SetBinding = function(key, action) set[key] = action end
E.GetCurrentBindingSet = function() return 2 end
local saved = 0
E.SaveBindings = function(which) assert(which == 2); saved = saved + 1 end
E.print = function() end
local binding = S:BindingAccessors("TARGET")
assert(binding.get() == "A")
binding.set("D")
assert(set.A == "TARGET" and not set.D and saved == 0)
ui.combat = false
binding.set("C")
local conflict = ui.dialogs[#ui.dialogs]
assert(conflict.key == "FLAREUI_KEY_TAKEN" and conflict.message:find("[C]", 1, true) and conflict.message:find("Existing Action", 1, true))
assert(set.C == "OTHER" and saved == 0, "a conflicting binding waits for consent")
ns.Dialogs[conflict.key].OnAccept(conflict.data)
assert(not set.A and not set.B and set.C == "TARGET" and saved == 1 and refreshes == 1)
binding.set("")
assert(binding.get() == "" and saved == 2, "clearing a binding removes the selected key and saves it")

print("PASS: settings Edit Mode search, return links and binding conflicts")
