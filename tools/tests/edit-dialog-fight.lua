-- Run from the repository root: luajit tools/tests/edit-dialog-fight.lua
-- Edit Mode's FlareUI dialog in a fight: no key stays with it, and its X closes it without HideUIPanel.
local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local Widget = getmetatable(env.UIParent)
function Widget:SetDontSavePosition() end
function Widget:SetHideIfUnscrollable() end
function Widget:SetPropagateKeyboardInput(value)
    assert(not ui.combat, "refused in a fight")
    self.propagate = value
end
function Widget:SetOnClickHandler(callback) self.handler = callback end
env.Mixin = function(object, mixin)
    for key, value in pairs(mixin) do object[key] = value end
    return object
end
env.GenerateClosure = function(f, ...)
    local first = ...
    return function(...) return f(first, ...) end
end
env.RESET_TO_DEFAULT = "Reset"
local moved, placed = 0, 0
local internal = { PlaceSaved = function() placed = placed + 1 end, SaveDialogPos = function() end }
function internal.MoveParent() moved = moved + 1 end
ui:load("Libs/FlareEditMode/widgets/dialog.lua", { FlareEditMode = { internal = internal } })
internal.MoveParent = function() moved = moved + 1 end

local dialog = internal:CreateDialog()
assert(dialog.propagate == true, "keys go on from the start, before any was pressed")
dialog:Show()
dialog.selection = {}
dialog:OnKeyDown("LEFT")
assert(moved == 1 and dialog.propagate == false, "a nudge stays with the dialog")
ui:emit("PLAYER_REGEN_DISABLED")
assert(dialog.propagate == true, "a fight starts: the keys are the game's again")
ui.combat = true
dialog:OnKeyDown("LEFT")
assert(moved == 1 and dialog.propagate == true)
ui:emit("PLAYER_REGEN_DISABLED")   -- (late: nothing it may not do)
dialog.Close:RunScript("OnClick")
assert(not dialog:IsShown() and dialog.selection == nil and placed > 0, "the X closes it in a fight")
ui.combat = false
print("PASS: the Edit Mode dialog gives its keys back as a fight starts and closes in one")
