local H = dofile("tools/tests/perf-helpers.lua")
local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local noop = function() end
local state = { health = 1, mana = 1 }
local db = {
    petFollowsPlayer = true,
    elements = {
        bar1 = { show = "ingroup", group = 1 },
        bar2 = { show = "always", group = 1 },
        capLeft = { show = "bar1" },
        uf_player = { show = "health", minAlpha = 15 },
        uf_target = { show = "never" },
        cdm_buffs = { show = "combat" },
    },
    groups = { { show = "combat", fadeSpeed = "fast", minAlpha = 20 }, {}, {}, {}, {} },
}
local profile = { visibility = db, actionbars = { enabled = true }, unitframes = { enabled = true },
    objectivetracker = { enabled = true }, damagemeter = { enabled = true, visibility = "hidden", showOnMouseover = true },
    chat = { enabled = true, visibility = "combat", minAlpha = 0.2, fadeSpeed = "slow" } }
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    db = { profile = profile },
    modules = {},
    RawHide = function(frame) frame:Hide() end,
    HideFrameSecurely = function(frame, on) frame.FlareUI_Hidden = on or nil end,
}
env.ns = ns
env.UnitExists = function(unit) return unit == "player" or unit == "target" and state.target end
env.UnitIsDead = function() return state.targetDead end
env.UnitCanAttack = function() return state.hostile end
env.UnitAffectingCombat = function() return false end
env.IsInGroup = function() return state.group end
env.IsInInstance = function() return state.instance end
env.IsMounted = function() return state.mounted end
env.UnitOnTaxi = function() return state.taxi end
env.GetShapeshiftFormID = function() return state.form end
env.C_Map = { GetBestMapForUnit = function() return state.map end }
env.canaccessvalue = function() return true end
env.Enum = {
    PowerType = { Mana = 0 }, LuaCurveType = { Step = 1 },
    EditModeCooldownViewerSetting = { Opacity = 1 },
    EditModeSystem = { ActionBar = 1, CooldownViewer = 2, DamageMeter = 3, ChatFrame = 4 },
    EditModeActionBarSystemIndices = { MainBar = 1, Bar2 = 2 },
    EditModeCooldownViewerSystemIndices = { BuffIcon = 3 },
}
env.C_AddOns.IsAddOnLoaded = function() return false end
env.C_CurveUtil = { CreateCurve = function()
    return { SetType = noop, ClearPoints = noop, AddPoint = function(curve, x, alpha)
        if x == 1 then curve.faded = alpha end
    end }
end }
env.UnitHealthPercent = function(_, _, curve) return state.health < 1 and 1 or curve.faded end
env.UnitPowerPercent = function(_, _, _, curve) return state.mana < 1 and 1 or curve.faded end
env.UnitPowerMax = function() return 100 end
env.tContains = function(values, want)
    for _, value in ipairs(values) do if value == want then return true end end
    return false
end
H.loadSections("Core.lua", {
    {"local FADE_TIMES =", "-- Numbers on the bars"},
    {"function ns.EditSections()", "-- A spell the player knows."},
    {"ns.Conditions = {}", "-- Fake CM is on"},
}, env)
ns.OrderEditSettings = noop
local edit = { SettingType = { Dropdown = 1, Slider = 2, Checkbox = 3, Expander = 4 }, settings = {} }
function edit:RegisterCallback(event, callback) self[event] = callback end
function edit:Defer() return false end
function edit:RefreshOpenSettings() self.refreshed = true end
function edit:AddSystemSettings(system, rows, index) self.settings[system .. "/" .. (index or 0)] = rows end
function env.LibStub(name)
    if name == "FlareEditMode" then return edit end
    if name == "AceEvent-3.0" then return { Embed = noop } end
    error("unexpected library " .. name)
end
env.HelpTip = { Show = noop, framePool = { EnumerateActive = function() return function() end end } }
env.EventUtil = { ContinueOnAddOnLoaded = noop }
env.CompactRaidFrameManager_UpdateShown = noop
env.EditModeManagerFrame = env.CreateFrame("Frame", nil, env.UIParent)
env.EditModeManagerFrame:Hide()
env.QuickKeybindFrame = env.CreateFrame("Frame", nil, env.UIParent)
env.QuickKeybindFrame:Hide()
local Widget = getmetatable(env.UIParent)
function Widget:SetIgnoreParentAlpha(on) self.ignoreParentAlpha = on end
function Widget:SetDrawBling(on) self.bling = on end
function Widget:GetDrawBling() return self.bling end

local function frame(name, parent)
    return env.CreateFrame("Frame", name, parent or env.UIParent)
end
local a, b = frame("MainActionBar"), frame("MultiBarBottomLeft")
local cap = frame(nil, a)
a.EndCaps = { LeftEndCap = cap }
local aButton, bButton = frame(nil, a), frame(nil, b)
aButton.cooldown, bButton.cooldown = frame(nil, aButton), frame(nil, bButton)
aButton.cooldown:SetDrawBling(true)
bButton.cooldown:SetDrawBling(false)
a.actionButtons, b.actionButtons = { aButton }, { bButton }
local blizzViewer = frame("BuffIconCooldownViewer")
function blizzViewer:GetSettingValue(setting) assert(setting == 1); return 60 end
ns.CooldownManager = { Started = function() return true end, Enabled = function() return true end }
local holders, unitButtons = {}, {}
for _, unit in ipairs({ "player", "target", "pet" }) do
    holders[unit] = frame()
    unitButtons[unit] = frame(nil, holders[unit])
end
ns.UnitFrames = {
    initialized = true,
    GetFadeFrame = function(_, unit) return holders[unit] end,
    GetUnitButton = function(_, unit) return unitButtons[unit] end,
    IsMouseOverUnit = function(_, unit) return unitButtons[unit]:IsMouseOver() end,
}
local quest = frame()
ns.ObjectiveTracker = { GetFrame = function() return quest end, SetNever = function(self, on) self.never = on end }
local meter = frame("DamageMeter")
ns.DamageMeter = { ApplyVisibility = function(self) self.updated = (self.updated or 0) + 1 end }
local chat = frame("ChatFrame1")
ns.Chat = {
    fadeAlpha = 1,
    FadeApply = function(self, alpha) self.fadeAlpha = alpha; chat:SetAlpha(alpha) end,
    FadeHold = function(show) return show or state.typing end,
}
ui:load("Modules/Visibility.lua", ns)
local vis, moduleEvents = ns.Visibility, {}
function vis:RegisterEvent(event, method) moduleEvents[event] = method end
assert(vis:ShouldLoad())
vis:Init()
assert(db.mouseToken and db.fadesMoved and db.capsBar1Moved and cap.ignoreParentAlpha)
assert(vis:GetGroup("capLeft") == 1 and vis:GetShow("bar1") == "mouseover,combat")
assert(vis:GetShow("meter") == "mouseover" and vis:GetShow("chat") == "mouseover,combat,messages")
assert(vis:GetMinAlpha("chat") == 20 and vis:GetFadeIn("bar1") == "fast")
assert(not unitButtons.target:IsMouseEnabled() and holders.target:GetAlpha() == 0)
assert(holders.player:GetAlpha() == 0.15 and holders.pet:GetAlpha() == 0.15 and blizzViewer:GetAlpha() == 0)
assert(#vis:EditSystems("ab") == 2 and edit.settings["1/1"] and edit.settings["2/3"])
ui:flushTimers()
assert(ns.DamageMeter.updated and meter:IsShown())

local driver = assert(ui:find(function(widget) return widget.groups and widget.groupOf end))
local function tick(dt)
    ui.time = env.GetTime() + dt
    driver:RunScript("OnUpdate", dt)
end
local function near(value, expected) return math.abs(value - expected) < 0.001 end
tick(0.25)
assert(near(a:GetAlpha(), 0.2) and near(b:GetAlpha(), 0.2) and not aButton.cooldown:GetDrawBling())
a.mouseOver = true
tick(0.1)
assert(near(a:GetAlpha(), 0.7) and near(cap:GetAlpha(), 0.7))
assert(aButton.cooldown:GetDrawBling() and not bButton.cooldown:GetDrawBling())
tick(0.1)
assert(a:GetAlpha() == 1 and b:GetAlpha() == 1)
a.mouseOver = false
tick(0.05)
assert(a:GetAlpha() == 1, "a group stays visible across a short mouse gap")
tick(0.05)
assert(a:GetAlpha() < 1)
tick(0.5)
assert(near(a:GetAlpha(), 0.2))

-- A moved button fades on its own, then hands fading back to its bar when reparented.
a.mouseOver = true
tick(0.25)
aButton:SetParent(env.UIParent)
a.mouseOver = false
vis:Wake()
tick(1)
assert(a:GetAlpha() == 1 and near(aButton:GetAlpha(), 0.2))
aButton.mouseOver = true
tick(0.25)
assert(aButton:GetAlpha() == 1 and b:GetAlpha() == 1)
aButton:SetParent(a)
aButton.mouseOver = false
tick(0.25)
assert(aButton:GetAlpha() == 1 and near(a:GetAlpha(), 0.2))

state.health = 0.7
ui:emit("UNIT_HEALTH", "player")
assert(holders.player:GetAlpha() == 1)
state.health = 1
ui:emit("UNIT_HEALTH", "player")
assert(near(holders.player:GetAlpha(), 0.15))
vis:SetShow("uf_player", "mana")
state.mana = 0.6
ui:emit("UNIT_POWER_UPDATE", "player", "ENERGY")
assert(near(holders.player:GetAlpha(), 0.15))
ui:emit("UNIT_POWER_UPDATE", "player", "MANA")
assert(holders.player:GetAlpha() == 1)

vis[moduleEvents.PLAYER_REGEN_DISABLED](vis, "PLAYER_REGEN_DISABLED")
tick(0.5)
assert(a:GetAlpha() == 1 and blizzViewer:GetAlpha() == 1 and chat:GetAlpha() == 1)
vis[moduleEvents.PLAYER_REGEN_ENABLED](vis, "PLAYER_REGEN_ENABLED")
tick(0.6)
assert(near(a:GetAlpha(), 0.2) and blizzViewer:GetAlpha() == 0)
vis:SetShow("cdm_buffs", "always")
assert(blizzViewer:GetAlpha() == 0.6, "Blizzard's own viewer opacity is restored")

vis:SetShow("quest", "never")
local part = frame(nil, quest)
env.GameTooltip:SetOwner(part, "ANCHOR_RIGHT")
env.GameTooltip:Show()
assert(ns.ObjectiveTracker.never and not env.GameTooltip:IsShown())
env.EditModeManagerFrame:Show()
tick(0.25)
assert(unitButtons.target:IsMouseEnabled() and holders.target:GetAlpha() == 1 and a:GetAlpha() == 1)
env.GameTooltip:Show()
assert(env.GameTooltip:IsShown())
env.EditModeManagerFrame:Hide()
assert(not unitButtons.target:IsMouseEnabled() and holders.target:GetAlpha() == 0)
vis:SetGroup("bar2", 0)
assert(vis:GetGroup("bar2") == 0 and vis:GetShow("bar2") == "mouseover,combat" and vis:GetMinAlpha("bar2") == 20)
vis:SetShow("bar1", "ingroup")
assert(vis:GetShow("capLeft") == "ingroup" and vis:GetShow("bar2") == "mouseover,combat")
assert(not vis.ShowRule("attackable"))
state.target, state.targetDead, state.hostile = true, false, true
assert(vis.ShowRule("hastarget") and vis.ShowRule("attackable"))
state.targetDead = true
assert(not vis.ShowRule("attackable"))
state.form = 3
assert(not vis.ShowRule("unmounted"))
state.form, state.map = nil, 1453
assert(vis.ShowRule("unmounted") and vis.ShowRule("city") and not vis.ShowRule("notcity"))
print("PASS: visibility migrates fades, groups bars, handles mouse and combat, and restores native opacity")
