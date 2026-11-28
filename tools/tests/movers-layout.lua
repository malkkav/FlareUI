local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local noop = function() end
local edit = { entries = {}, callbacks = {}, frameSelections = {}, SettingType = { Slider = "slider" } }
function edit:GetActiveLayoutName() return "Modern" end
function edit:AddFrame(holder, onMove)
    self.entries[holder] = { move = onMove }
    self.frameSelections[holder] = env.CreateFrame("Frame", nil, holder)
end
function edit:AddFrameSettings(holder, rows) self.entries[holder].scale = rows[1] end
function edit:RegisterCallback(event, callback) self.callbacks[event] = callback end
env.LibStub = function(name)
    if name == "FlareEditMode" then return edit end
    assert(name == "LibSharedMedia-3.0")
    return { Fetch = function(_, _, value) return "Media/" .. value end }
end
env.C_CVar = { SetCVar = function(name, value) ui.setting = { name, value } end }
local function frame(name) return env.CreateFrame("Frame", name, env.UIParent) end
local container = frame("GroupLootContainer")
local loot = frame("GroupLootFrame1")
loot.Border = loot:CreateTexture()
local base = frame("AlertFrame")
base.UpdateAnchors = noop
base.baseAnchorFrame = base
local toast, queued, newToast = frame(), frame(), frame()
local list = { queued }
local anchors = {}
base.alertFrameSubSystems = {
    { anchorFrame = container, AdjustAnchors = function() error("the relocated loot frame cannot anchor toasts") end },
    { alertFrame = toast, AdjustAnchors = function(_, target) anchors[1] = target; return toast end },
    { alertFramePool = { EnumerateActive = function()
        local i = 0
        return function() i = i + 1; return list[i] end
    end },
      ShowAlert = function() list[#list + 1] = newToast end,
      AdjustAnchors = function(_, target) anchors[2] = target; return queued end },
}
local objectives = frame("UIWidgetTopCenterContainerFrame")
objectives:SetSize(175, 32)
objectives.numWidgetsShowing = 1
objectives.IsProtected = function() return true end

local db = { lootScale = 1.2, toastScale = 1.1, objectivesScale = 0.8,
    moverLayouts = { Modern = { toast = { point = "TOPLEFT", x = 25, y = -75 } } } }
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }), modules = {},
    db = { profile = { tweaks = db }, global = { flagCarriersSet = true } },
    IsGamepadUI = function() return ui.gamepad == true end,
    LayoutHome = function(layouts, key)
        layouts[key] = layouts[key] or {}
        return layouts[key]
    end,
    EditSection = function(_, rows) return rows end,
    BorderEdgeSize = function(_, size) return size end,
    BORDER_COLOR = env.CreateColor(0.8, 0.6, 0.34, 1),
    CopyStrata = function(widget, source) widget:SetFrameStrata(source:GetFrameStrata()) end,
}
ui:load("Modules/Movers.lua", ns)
ui.combat = true
ui:emit("PLAYER_LOGIN")
assert(not ui.setting and ns.db.global.flagCarriersSet)
ui.combat = false
ui:emit("PLAYER_REGEN_ENABLED")
assert(ui.setting[1] == "showArenaEnemyFrames" and ui.setting[2] == "1" and not ns.db.global.flagCarriersSet)
local movers = ns.Movers
assert(movers:ShouldLoad())
ui.gamepad = true
assert(not movers:ShouldLoad())
ui.gamepad = false
movers:Init()
local rollHolder, toastHolder, objHolder = env.FlareUI_LootRolls, env.FlareUI_Toasts, env.FlareUI_BattlegroundObjectives
assert(select(2, container:GetPoint()) == rollHolder and loot:GetScale() == 1.2)
container:SetPoint("CENTER", env.UIParent, "CENTER")
container:SetHeight(75)
assert(container:GetPoint() == "BOTTOM" and container:GetHeight() == 1)
assert(base:GetPoint() == "BOTTOM" and select(2, base:GetPoint()) == toastHolder)
assert(toastHolder:GetPoint() == "TOPLEFT" and select(4, toastHolder:GetPoint()) == 25)
base:UpdateAnchors()
assert(anchors[1] == base and anchors[2] == toast)
assert(toast:GetScale() == 1.1 and queued:GetScale() == 1.1)
base.alertFrameSubSystems[3]:ShowAlert()
assert(newToast:GetScale() == 1.1)

local box = env.FlareUI_BattlegroundObjectivesBox
assert(box:IsShown() and not box:IsMouseEnabled() and objectives:GetScale() == 0.8)
assert(select(2, objectives:GetPoint()) == objHolder)
objectives.numWidgetsShowing = 0
objectives:RunScript("OnSizeChanged")
assert(not box:IsShown())
objectives.numWidgetsShowing = 2
objectives:RunScript("OnSizeChanged")
assert(box:IsShown())
ui.combat = true
edit.entries[objHolder].scale.set(nil, 125)
objectives:ClearAllPoints()
objectives:SetPoint("CENTER", env.UIParent, "CENTER")
assert(objectives:GetScale() == 0.8 and objectives:GetPoint() == "CENTER")
ui.combat = false
ui:emit("PLAYER_REGEN_ENABLED")
assert(objectives:GetScale() == 1.25 and select(2, objectives:GetPoint()) == objHolder)
env.EnhanceQoL = { Mover = { functions = { IsFrameEnabled = function() return true end } } }
objectives:ClearAllPoints()
objectives:SetPoint("CENTER", env.UIParent, "CENTER")
assert(objectives:GetPoint() == "CENTER", "the mover yields to EnhanceQoL")

edit.callbacks.enter()
for _, holder in ipairs({ rollHolder, toastHolder, objHolder }) do
    assert(holder.preview:IsShown())
    assert(edit.frameSelections[holder]:GetFrameLevel() > holder.preview:GetFrameLevel())
end
edit.entries[toastHolder].move(nil, "Battle", "BOTTOM", 40.5, 155.6)
edit.callbacks.layout("Battle")
assert(toastHolder:GetPoint() == "BOTTOM" and select(4, toastHolder:GetPoint()) == 41)
edit.entries[toastHolder].scale.set(nil, 100)
assert(not db.toastScale and toast:GetScale() == 1 and newToast:GetScale() == 1)
edit.callbacks.exit()
assert(not rollHolder.preview:IsShown() and not toastHolder.preview:IsShown() and not objHolder.preview:IsShown())
print("PASS: movers' native hooks, saved layouts, scaling, combat deferral and Edit Mode")
