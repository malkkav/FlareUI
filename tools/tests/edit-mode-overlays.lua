-- The Edit Mode eye and account controls coordinate Blizzard and FlareUI frames.
local setup = dofile("tools/tests/fixtures/settings-addon.lua")
local edit = { frameSelections = {}, callbacks = {} }
local ui, ns = setup(function(state) state.editMode = edit end)
local E = ui.env
local function make(name, parent, kind) return E.CreateFrame(kind or "Frame", name, parent or E.UIParent) end
local function callback(event, ...)
    for _, f in ipairs(edit.callbacks[event] or {}) do f(...) end
end
function edit:IsInEditMode() return ui.editing == true end
function edit:RegisterCallback(event, f)
    self.callbacks[event] = self.callbacks[event] or {}
    table.insert(self.callbacks[event], f)
end

local manager = make("EditModeManagerFrame")
manager:Hide()
manager.CloseButton = make(nil, manager, "Button")
local account = make(nil, manager)
manager.AccountSettings = account
local scroll = { BasicOptionsContainer = make(nil, account), AdvancedOptionsContainer = make(nil, account) }
account.SettingsContainer = { ScrollChild = scroll }
local layouts = 0
local function layout() layouts = layouts + 1 end
manager.Layout = layout
scroll.BasicOptionsContainer.Layout = layout
scroll.AdvancedOptionsContainer.Layout = layout
local child = make(nil, scroll.BasicOptionsContainer)
child.Layout = layout

local boxes = {}
for _, key in ipairs({ "StanceBar", "PetActionBar", "VehicleLeaveButton", "GroupFinder", "TimerBars", "SwingTimer" }) do
    local box = make(nil, account)
    box.Button = make(nil, box, "CheckButton")
    box.Label = box:CreateFontString()
    box.isBasicOption = key ~= "PetActionBar"
    box.UpdateDisplay = function(self) self.Button:Disable() end
    boxes[key] = box
end
account.settingsCheckButtons = boxes
function account:LayoutSettings()
    for _, box in pairs(boxes) do box:SetShown(not box.shouldHide and (ui.advanced or box.isBasicOption)) end
end
function manager:AreAdvancedOptionsEnabled() return ui.advanced end
local values, saved = { [1] = false, [2] = false }, {}
function manager:GetAccountSettingValueBool(key) return values[key] end
function account:SetTargetAndFocusShown(shown) values[1] = shown end
function account:SetTimerBarsShown(shown) values[2] = shown end
function manager:SelectSystem(system) if system and system.Selection then system.Selection:SetAlpha(1) end end

E.Enum.EditModeAccountSetting = { ShowTargetAndFocus = 1, ShowTimerBars = 2 }
E.Enum.EditModeSystem = { ActionBar = 4 }
E.C_EditMode = { SetAccountSetting = function(key, value) saved[key] = value end }
E.canaccessvalue = function(value) return value ~= "secret" end
local ownFrame = make("FlareUI_UF_Target")
local ownSelection = make(nil, ownFrame)
edit.frameSelections[ownFrame] = ownSelection
local timerFrame = make("FlareUI_Resource_timer")
local timerSelection = make(nil, timerFrame)
edit.frameSelections[timerFrame] = timerSelection
local blizz = make(nil, manager)
blizz.Selection = make(nil, blizz)
blizz.system = E.Enum.EditModeSystem.ActionBar
manager.registeredSystemFrames = { blizz }
local walk = make(nil, manager)
walk.ShowHighlighted, walk.ShowSelected, walk.MouseOverHighlight = function() end, function() end, {}
local otherSelection = make(nil, manager)
local oldLibStub = E.LibStub
E.LibStub = setmetatable({
    IterateLibraries = function() return pairs({ OtherEditMode = { frameSelections = { unrelated = otherSelection, own = ownSelection } } }) end,
}, { __call = function(_, ...) return oldLibStub(...) end })

local walked = 0
E.EnumerateFrames = function(previous)
    walked = walked + 1
    if not previous then return walk end
end
local tooltip = make("GameTooltipDefaultContainer")
tooltip:SetSize(260, 70)
tooltip:SetFrameLevel(10)
tooltip:Hide()
local gripRefresh = 0
ns.Minimap = { Moves = { UpdateHandles = function() gripRefresh = gripRefresh + 1 end } }
ns.db.profile.actionbars = { enabled = true }
ns.db.profile.visibility = { hideStanceBar = true, hidePetBar = true }
ns.db.profile.minimap = { enabled = true, vehicleExit = true, finderEye = false }
ns.db.profile.chat = { opacity = 0.35 }

ui:load("EditModeOverlays.lua", ns)
ui:emit("PLAYER_LOGIN")
ui:flushTimers()
assert(edit.resetSettingsText == "Reset Settings" and saved[1] == 1 and saved[2] == 1)
assert(ns.db.global.editModeSwitchesSet.ShowTargetAndFocus and ns.db.global.editModeSwitchesSet.ShowTimerBars)
assert(not E.FlareUI_EditModeEye, "the overlay controls are created when Edit Mode opens")
ui.editing = true
ui.advanced = true
manager:Show()
callback("enter")
ui:flushTimers()
assert(ownFrame:GetAlpha() == 1 and timerFrame:GetAlpha() == 1, "newly installed frames are visible before the CVar cache refreshes")
assert(not boxes.StanceBar:IsShown() and not boxes.PetActionBar:IsShown() and not boxes.VehicleLeaveButton:IsShown()
    and boxes.GroupFinder:IsShown() and layouts > 0)
boxes.TimerBars:UpdateDisplay()
assert(boxes.TimerBars.Button:IsEnabled() and boxes.TimerBars.Label:GetFontObject() == "GameFontHighlightMedium",
    "the replacement timer vehicle box stays usable after Blizzard updates it")

account:SetTargetAndFocusShown(false, true)
assert(ownFrame:GetAlpha() == 0 and ownSelection.FlareUI_Hidden and not ownSelection:IsShown())
ownSelection:Show()
assert(not ownSelection:IsShown(), "a disabled frame's selection cannot be restored by Blizzard")
account:SetTargetAndFocusShown(true, true)
assert(ownFrame:GetAlpha() == 1 and ownSelection:IsShown())
account:SetTimerBarsShown(false, true)
assert(timerFrame:GetAlpha() == 0)
ui.editing = false
callback("exit")
assert(timerFrame:GetAlpha() == 1, "Edit Mode visibility switches do not hide live frames")

local eye = assert(E.FlareUI_EditModeEye)
assert(select(2, eye:GetPoint()) == manager.CloseButton)
eye:RunScript("OnEnter")
assert(E.GameTooltip:IsShown() and E.GameTooltip:GetText() == "Toggle Edit Mode Overlays")
eye:RunScript("OnLeave")
assert(not E.GameTooltip:IsShown())
local selections = { ownSelection, timerSelection, blizz.Selection, walk, otherSelection }
local shown = {}
for i, selection in ipairs(selections) do shown[i] = selection:IsShown() end
eye:Click()
assert(ns.db.profile.editModeOverlaysHidden and gripRefresh == 1)
for i, selection in ipairs(selections) do
    assert(selection:GetAlpha() == 0 and selection:IsShown() == shown[i], "the eye only changes selection alpha")
end
manager:SelectSystem(blizz)
assert(blizz.Selection:GetAlpha() == 1)
ui:flushTimers()
assert(blizz.Selection:GetAlpha() == 0 and ns.db.global.editModeHintSeen, "selection is hidden again and the hint is dismissed")
eye:Click()
assert(not ns.db.profile.editModeOverlaysHidden and gripRefresh == 2 and walked == 2, "the costly frame walk is cached")

local sample = assert(ui:find(function(w) return w.allPoints == tooltip and w.backdrop ~= nil end))
assert(not sample:IsShown() and not sample:IsMouseEnabled())
tooltip:Show()
local _, _, _, opacity = sample.backdrop:GetBackdropColor()
assert(sample:IsShown() and opacity == 0.35 and sample:GetFrameLevel() == 9)
tooltip:Hide()
assert(not sample:IsShown())

ns.db.profile.visibility.hideStanceBar = false
ns.db.profile.visibility.hidePetBar = false
ns.db.profile.minimap.vehicleExit = false
ui.advanced = false
account:LayoutSettings()
assert(boxes.StanceBar:IsShown() and boxes.VehicleLeaveButton:IsShown() and not boxes.PetActionBar:IsShown(),
    "restoring boxes respects the game's Advanced Options filter")
ns.db.profile.visibility.hideStanceBar = true
ui.combat = true
ns.ApplyHiddenBarBoxes()
assert(boxes.StanceBar:IsShown(), "combat leaves the protected layout untouched")
ui.combat = false
ns.ApplyHiddenBarBoxes()
assert(not boxes.StanceBar:IsShown())

print("PASS: Edit Mode overlay eye, frame toggles, hidden boxes and tooltip mover")
