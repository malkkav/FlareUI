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
    -- the gryphons follow Quality of Life (Gryphons.lua), not Action Bars
    Gryphons = { On = function() return GRYPHONS_ON ~= false end },
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
H.loadCore(env, ns)
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
-- Slower Hide Speed through the shared fader: 55% after 2 s, a rest, then gone; showing again mid-fade
-- cancels it, and the next fade starts its stages afresh
vis:SetElementFade("bar2", "fadeIn", "instant")
vis:SetElementFade("bar2", "fadeOut", "slower")
assert(vis:GetFadeOut("bar2") == "slower" and vis:GetMinAlpha("bar2") == 20)
local function run(seconds)
    for _ = 1, math.floor(seconds / 0.05 + 0.5) do tick(0.05) end
    return b:GetAlpha()
end
local function nearly(value, expected) return math.abs(value - expected) < 0.04 end
b.mouseOver = true
assert(run(0.3) == 1)
b.mouseOver = false
run(0.1)                                    -- past the short grace before a fade starts
assert(nearly(run(2), 0.55), "first stage: 55% after 2 s")
assert(nearly(run(1), 0.55), "rests at 55%")
b.mouseOver = true
assert(run(0.2) == 1, "showing again cancels the fade at once")
b.mouseOver = false
run(0.1)
assert(nearly(run(2), 0.55), "restarted: the first stage again")
assert(nearly(run(1.5), 0.55), "restarted: the rest runs its full 2 s (it was cut short before)")
assert(run(1) < 0.55, "then it finishes")
assert(nearly(run(0.5), 0.2), "down to Faded Opacity")
-- (11-25, #195) Opacity: as see-through as that when it shows, never under its Faded Opacity
do
    assert(vis:GetMaxAlpha("bar2") == 100)
    vis:SetElementFade("bar2", "maxAlpha", 60)
    b.mouseOver = true
    for _ = 1, 10 do run(0.2) end
    assert(nearly(run(0.2), 0.6), "shows at 60%")
    vis:SetElementFade("bar2", "maxAlpha", 10)
    for _ = 1, 40 do run(0.2) end
    local v = run(0.2) assert(nearly(v, 0.2), "not under Faded Opacity " .. tostring(v) .. " " .. vis:GetMinAlpha("bar2"))
    vis:SetElementFade("bar2", "maxAlpha", nil)
    for _ = 1, 10 do run(0.2) end
    assert(run(0.2) == 1)
    b.mouseOver = false
    for _ = 1, 30 do run(0.2) end
end

-- Fade Delay (11-23): a frame stays its Fade Delay after its last reason to show, then fades
vis:SetElementFade("bar2", "fadeOut", "instant")
assert(vis:GetFadeDelay("bar2") == 0, "0 to start: today's fade")
vis:SetFadeDelay("bar2", 2)
assert(vis:GetFadeDelay("bar2") == 2 and db.elements.bar2.fadeDelay == 2)
b.mouseOver = true
assert(run(0.2) == 1)
b.mouseOver = false
assert(run(1.5) == 1, "still shown inside its Fade Delay")
assert(nearly(run(0.8), 0.2), "faded once the delay is over")
-- in a fade group the delay is the group's, shared by every member, and joining carries it over
vis:SetFadeDelay("bar1", 3)
assert(db.groups[1].fadeDelay == 3 and vis:GetFadeDelay("capLeft") == 3)
vis:SetGroup("bar2", 2)
assert(db.groups[2].fadeDelay == 2, "the first member brings its delay")
-- the chat keeps its own, and frames the game shows and hides itself have none
assert(vis:GetFadeDelay("chat") == 5 and vis:GetFadeDelay("uf_target") == 0)
local function hasDelayRow(rows)
    for _, row in ipairs(rows) do if row.name == "Fade Delay" then return true end end
    return false
end
assert(hasDelayRow(vis:UnitFrameSettings("player")) and hasDelayRow(vis:UnitFrameSettings("pet")))
assert(not hasDelayRow(vis:UnitFrameSettings("target")) and not hasDelayRow(vis:UnitFrameSettings("focus")))
assert(hasDelayRow(vis:ResourceBarSettings("power")) and not hasDelayRow(vis:ResourceBarSettings("swingMain")))
assert(not hasDelayRow(vis:PlayerCastSettings()))

-- in a fade group, ticking a condition on one member keeps those only another member has
vis:SetGroup("bar2", 2)
vis:SetShow("bar2", "mouseover,messages")
assert(vis.Toggled("bar2", "combat"):find("messages", 1, true), "the chat's New Messages stays in the group")
assert(vis.Toggled("bar2", "always") == "always")
vis:SetGroup("bar2", 0)
vis:SetShow("bar2", "mouseover")
assert(vis.Toggled("bar2", "combat") == "mouseover,combat")

-- A bar faded to nothing that the pointer doesn't bring back takes no clicks (11-24): not during its fade, not
-- while a fight or a drag could need it, and never on a bar with Mouseover or a Faded Opacity
vis:SetShow("bar2", "ingroup")
vis:SetElementFade("bar2", "fadeOut", "instant")
vis:SetFadeDelay("bar2", 0)
db.elements.bar2.minAlpha = 0
vis:Refresh()
run(0.5)
assert(b:GetAlpha() == 0 and not bButton:IsMouseEnabled() and vis.mouseOff.bar2 == b)
assert(aButton:IsMouseEnabled(), "Faded Opacity above 0: still there to click")
state.group = true
vis:Wake()
tick(0.1)
assert(bButton:IsMouseEnabled() and not vis.mouseOff.bar2, "shown: clickable from the first frame of its fade")
state.group = false
run(0.5)
assert(not bButton:IsMouseEnabled())
vis[moduleEvents.PLAYER_REGEN_DISABLED](vis, "PLAYER_REGEN_DISABLED")
assert(bButton:IsMouseEnabled(), "its mouse back as a fight starts")
run(0.5)
assert(bButton:IsMouseEnabled() and b:GetAlpha() == 0, "... and for all of it")
ui.combat = true
run(0.5)
vis[moduleEvents.PLAYER_REGEN_ENABLED](vis, "PLAYER_REGEN_ENABLED")
assert(bButton:IsMouseEnabled(), "not touched in combat lockdown")
ui.combat = false
run(1.2)
vis:Wake()
run(0.2)
assert(not bButton:IsMouseEnabled())
ns.ActionBars = { fcm = { wasDragging = true } }
vis:Wake()
run(0.3)
assert(bButton:IsMouseEnabled(), "a drag shows the bars and gives the mouse back")
ns.ActionBars.fcm.wasDragging = false
run(0.5)
assert(not bButton:IsMouseEnabled())
vis:SetShow("bar2", "mouseover")
run(0.5)
assert(bButton:IsMouseEnabled(), "Mouseover needs the pointer")
vis:SetShow("bar2", "never")
assert(not bButton:IsMouseEnabled())
env.EditModeManagerFrame:Show()
assert(bButton:IsMouseEnabled(), "Edit Mode shows it")
env.EditModeManagerFrame:Hide()
assert(not bButton:IsMouseEnabled())
vis:SetShow("bar2", "always")
assert(bButton:IsMouseEnabled())
ns.ActionBars = nil

-- Sharp Outline's texts go with a bar faded right out, and come back with it; other outlines are left alone
do
    local function Text(flags)
        local fs = { alpha = 1, GetFont = function() return "font", 12, flags end }
        function fs:SetAlpha(alpha) self.alpha = alpha end
        return fs
    end
    local sharp, plain, timer = Text("OUTLINE, SLUG"), Text("OUTLINE"), Text("OUTLINE, SLUG")
    local bar = { actionButtons = { { HotKey = sharp, Count = plain, cooldown = { GetCountdownFontString = function() return timer end } } } }
    vis.SetBarTexts(bar, 0.5)
    assert(sharp.alpha == 1)
    vis.SetBarTexts(bar, 0)
    assert(sharp.alpha == 0 and timer.alpha == 0 and plain.alpha == 1)
    vis.SetBarTexts(bar, 0.02)
    assert(sharp.alpha == 1 and timer.alpha == 1)
end
-- the Raid Manager switch is Quality of Life's: it works with Action Bars, and every other module, off
local manager = frame("CompactRaidFrameManager")
db.hideRaidManager, db.hidePetBar = true, true
local pet = frame("PetActionBar")
profile.actionbars.enabled = false
vis:Refresh()
assert(manager.FlareUI_Hidden and not pet.FlareUI_Hidden, "Blizzard's bars come with Action Bars")
env.EditModeManagerFrame:Show()
manager:Show()
assert(not manager:IsShown(), "Edit Mode's samples don't bring it back")
env.EditModeManagerFrame:Hide()

-- In a Battleground: battlegrounds and arenas, split off In an Instance (dungeons and raids)
local kind
env.IsInInstance = function() return kind ~= nil, kind end
kind = "pvp"
assert(vis.ShowRule("pvp") and not vis.ShowRule("instance"))
kind = "arena"
assert(vis.ShowRule("pvp") and not vis.ShowRule("instance"))
kind = "party"
assert(vis.ShowRule("instance") and not vis.ShowRule("pvp"))
kind = nil
assert(not vis.ShowRule("instance") and not vis.ShowRule("pvp"))
-- saved In an Instance gets In a Battleground once, so nothing changes for anyone
local old = { elements = { meter = { show = "mouseover,instance" }, chat = { show = "combat" } },
              groups = { { show = "instance" }, {} } }
profile.fcm = { show = "instance,pvp" }
vis.MigratePvpSplit(old)
assert(old.pvpSplit and old.elements.meter.show == "mouseover,instance,pvp" and old.elements.chat.show == "combat")
assert(old.groups[1].show == "instance,pvp" and profile.fcm.show == "instance,pvp")
profile.fcm = nil

-- the party, raid and boss frames fade their holder; on Never their tiles take no clicks
profile.unitframes.raid = { enabled = true }
assert(#vis:GroupFrameSettings("flagCarriers") == 5, "flag carriers have the same Fading rows")
local raid, tanks = frame("FlareUI_Raid"), frame("FlareUI_RaidTanks")
local header = frame(nil, raid)
local tile = frame(nil, header)
tile:SetAttribute("unit", "raid1")
vis:SetShow("uf_raid", "never")
assert(raid:GetAlpha() == 0 and tanks:GetAlpha() == 0 and not tile:IsMouseEnabled())
vis:SetShow("uf_raid", "always")
assert(raid:GetAlpha() == 1 and tanks:GetAlpha() == 1 and tile:IsMouseEnabled())
local rows = vis:GroupFrameSettings("raid")
assert(#rows == 5 and rows[1].name == "Visibility")
profile.unitframes.raid.enabled = false
vis:SetShow("uf_raid", "never")
assert(raid:GetAlpha() == 1, "left alone with the raid frames off")

for _, key in ipairs({ "unitframes", "objectivetracker", "damagemeter", "chat" }) do profile[key].enabled = false end
GRYPHONS_ON = false   -- (Quality of Life off too: the gryphons don't keep it loaded)
ns.CooldownManager = nil
assert(vis:ShouldLoad(), "loaded for this switch alone")
vis:Refresh()
assert(manager.FlareUI_Hidden)
db.hideRaidManager = false
vis:Refresh()
assert(not manager.FlareUI_Hidden and not vis:ShouldLoad())

-- (GitHub #220, OLEDGuard) a gryphon on Always, in no group, follows bar 1's opacity, so whatever dims the bar
-- dims it; with a rule of its own (or a group) it ignores the bar's and fades on that
do
    local wasOn = GRYPHONS_ON
    GRYPHONS_ON = true   -- (Quality of Life on: the gryphons are FlareUI's)
    local group, show = vis:GetGroup("capLeft"), vis:GetShow("capLeft")
    vis:SetGroup("capLeft", 0)
    vis:SetShow("capLeft", "always")
    vis:Refresh()
    assert(not cap.ignoreParentAlpha, "Always: follows bar 1")
    vis:SetShow("capLeft", "combat")
    vis:Refresh()
    assert(cap.ignoreParentAlpha, "a rule of its own: its own fading")
    vis:SetShow("capLeft", show)
    vis:SetGroup("capLeft", group)
    GRYPHONS_ON = wasOn
    vis:Refresh()
end
print("PASS: visibility migrates fades, groups bars, handles mouse and combat, and restores native opacity")
