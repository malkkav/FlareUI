-- Run from the repository root: luajit tools/tests/edit-extension-pairs.lua
-- (Malkkav 11-28) The panel under Blizzard's own Edit Mode dialogs (the chat's Fading, ...) puts its switches
-- two to a line, as FlareUI's own frames' dialog does: it pairs them before each layout.
local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local Widget = getmetatable(env.UIParent)
local order = {}
function Widget:Layout() order[#order + 1] = "layout" end
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
env.EditModeSystemSettingsDialog = env.CreateFrame("Frame", nil, env.UIParent)
local paired
local internal = {}
function internal.PairCheckboxes(settings) paired = settings; order[#order + 1] = "pair" end
ui:load("Libs/FlareEditMode/widgets/extension.lua", { FlareEditMode = { internal = internal } })

local extension = internal:CreateExtension()
extension.Settings.widgets = {}
extension.PlaceSoon = function() end
extension:Show()
extension:RefreshWidgets()
assert(paired == extension.Settings, "the panel's switches are paired")
assert(order[1] == "pair" and order[2] == "layout", "before the layout measures them")
print("PASS: the panel under Blizzard's Edit Mode dialogs pairs its switches")
