local H = dofile("tools/tests/perf-helpers.lua")
local config = {
    enabled = true, palette = "custom", customBase = "blizzard", customColors = { queued = { 0.9, 0.2, 0.1 }, queueMaul = { 0.9, 0.2, 0.1 } },
    layouts = {}, font = { face = "Test Face", size = 10 },
    bars = {
        health = { enabled = true, lowHealth = true, show = "combat", font = {}, smoothBars = true },
        power = { enabled = true, gcd = true, fsr = true, font = {} },
        mana = { enabled = true, fsr = true, font = {} },
        combo = { enabled = true, look = "modern" },
        swingMain = { enabled = true, queueTint = true, waiting = true },
        swingRanged = { enabled = true, standStill = true },
        timer = { enabled = true },
    },
}
local db = { styleStart = true, resource = config, units = { player = {} }, frameFontsSeeded = true }
local ui, ns = dofile("tools/tests/fixtures/unitframes-ui.lua")(db)
local env = ui.env
ns.defaults.profile.unitframes.resource = { bars = config.bars }
ns.db.profile.visibility = { elements = {} }
local state = { health = 82, power = 70, mana = 60, points = 2, speed = 2.5, ranged = 3, progress = {} }
local playerClass, currentType, currentToken = "DRUID", 0, "MANA"
env.Enum = {
    PowerType = { Mana = 0, Energy = 3, ComboPoints = 4 },
    PlayerSwingType = { MainHand = 1, OffHand = 2, Ranged = 3 },
    LuaCurveType = { Step = 0 },
}
env.UnitClass = function() return "Druid", playerClass end
env.UnitHealth = function() return state.health end
env.UnitHealthMax = function() return 100 end
env.UnitHealthMissing = function() return 100 - state.health end
env.UnitPowerType = function() return currentType, currentToken end
env.UnitPower = function(_, kind) return kind == 0 and state.mana or state.power end
env.UnitPowerMax = function(_, kind) return kind == 4 and 5 or 100 end
env.UnitPowerPercent = env.UnitPower
env.UnitHealthPercent = function(_, scale, curve)
    if scale and curve == env.CurveConstants.ScaleTo100 then return state.health end
    local share, alpha = state.health / 100
    for _, point in ipairs(curve.points) do if share >= point[1] then alpha = point[2] end end
    return alpha
end
env.C_CurveUtil = { CreateCurve = function()
    return {
        points = {},
        SetType = function() end,
        AddPoint = function(curve, x, y) curve.points[#curve.points + 1] = { x, y } end,
    }
end }
env.UnitGetIncomingHeals = function() return 4 end
env.UnitGetTotalAbsorbs = function() return 8 end
env.UnitIsDeadOrGhost = function() return false end
env.UnitAttackSpeed = function() return state.speed, nil, state.ranged end
env.GetComboPoints = function() return state.points end
env.UnitCastingInfo = function() return state.cast end
env.C_Spell = {
    GetSpellPowerCost = function(id) return id == 10 and { { type = 0, cost = 5 } } or {} end,
    GetSpellName = function(id) return id == 6807 and "Maul" or id == 78 and "Heroic Strike" or nil end,
    IsCurrentSpell = function(name) return name == "Maul" and state.queued or name == 6603 and state.attacking end,
    IsAutoRepeatSpell = function(id) return id == 75 and state.shooting end,
    GetSpellCooldown = function() return state.gcd end,
}
local ranges = {}
env.C_SwingTimer = { EnableRangeCheck = function(hand, on) ranges[hand] = on end }
env.C_Timer.NewTimer = env.C_Timer.NewTicker
env.GetMirrorTimerInfo = function() end
env.GetMirrorTimerProgress = function(name) return state.progress[name] end
env.EventUtil = { ContinueOnAddOnLoaded = function() end }
env.MirrorTimerContainer = env.CreateFrame("Frame", "MirrorTimerContainer", env.UIParent)
function env.MirrorTimerContainer:IsProtected() return false end
function env.MirrorTimerContainer:ShouldShow() return true end
local Widget = getmetatable(env.UIParent)
function Widget:SetMouseClickEnabled(on) self.mouseClick = on end

ns.EditPreviewing = function() return ui.editing == true end
ns.SetBarValue = function(bar, value, glide)
    bar.SetBarValueCalls = (bar.SetBarValueCalls or 0) + 1
    bar.wasGliding = glide and true or false
    bar:SetValue(value)
end
ns.RawHide = function(frame) frame:Hide() end
ns.OnEditFight = function(callback) ui.editFightCallback = callback end
ns.TargetInRange = function(ranged) return not (ranged and state.outOfRange) end
ns.SEGMENT_LINE_COLOR = { 0.1, 0.1, 0.1, 1 }
ns.SegmentSpan = function(_, width, count, i) return (i - 1) * width / count, width / count, 1 end
ns.Visibility = { GetShow = function(_, key) return key == "rb_swingMain" and "inuse" or "always" end }
H.loadSections("Core.lua", {
    {"function ns.EditSections()", "-- A spell the player knows."},
}, env)
ns.OrderEditSettings = function() end
local editMode = env.LibStub("FlareEditMode")
editMode.SettingType = { Slider = 1, Checkbox = 2, Dropdown = 3, Expander = 4 }
local move, callbacks = {}, {}
function editMode:AddFrame(frame, moved) move[frame] = moved end
function editMode:AddFrameSettings() end
function editMode:SetFrameSnapper(frame, snap) frame.snap = snap end
function editMode:GetActiveLayoutName() return "Modern" end
function editMode:RegisterCallback(event, callback) callbacks[event] = callback end
function editMode:Defer() return false end
ui:load("Modules/ResourceBars.lua", ns)
local rb = ns.ResourceBars
config.enabled = false
assert(not rb:ShouldLoad())
config.enabled = true
assert(rb:ShouldLoad())
rb:Init()
local hp, power, mana, combo = rb:GetHolder("health"), rb:GetHolder("power"), rb:GetHolder("mana"), rb:GetHolder("combo")
local main, ranged, timer = rb:GetHolder("swingMain"), rb:GetHolder("swingRanged"), rb:GetHolder("timer")
assert(hp.Bar:GetValue() == 82 and hp.LowHealth:GetAlpha() == 0 and hp.HealBar:GetValue() == 4)
assert(hp.TextMid:GetText() == "82 / 100" and power.Bar:GetValue() == 60)
assert(not mana:IsShown() and not combo:IsShown() and not main:IsShown() and not timer:IsShown())
assert(not env.MirrorTimerContainer:IsShown() and ranges[1] and ranges[3])
assert(rb.basePalette == "blizzard" and config.customColors.queueHeroic[1] == 0.9 and not config.customColors.queued)
assert(rb.BarFont("health").size == 12 and rb.BarFont("power").face == "Test Face")
assert(ns.db.profile.visibility.elements.rb_health.show == "combat")

local function send(event, ...)
    assert(rb.events:IsEventRegistered(event), "event not registered: " .. event)
    rb.events:RunScript("OnEvent", event, ...)
end
state.health = 20
send("UNIT_HEALTH", "player")
assert(hp.Bar:GetValue() == 20 and hp.LowHealth:GetAlpha() == 1 and hp.Bar.wasGliding)
assert(hp.DamageTrail:GetValue() == 82)
ui.time = 100.6
ns.UnitFrames.trailDriver:RunScript("OnUpdate", 0.6)
assert(hp.DamageTrail:GetValue() == 20)

currentType, currentToken = 3, "ENERGY"
send("UNIT_DISPLAYPOWER", "player")
assert(mana:IsShown() and combo:IsShown() and combo.segments[5]:GetValue() == 2)
assert(power.Bar:GetValue() == 70 and mana.Bar:GetValue() == 60)
state.power, state.mana = 52, 57
send("UNIT_POWER_FREQUENT", "player", "MANA")
assert(power.Bar:GetValue() == 70 and mana.Bar:GetValue() == 57)
send("UNIT_POWER_FREQUENT", "player", "ENERGY")
local calls = power.Bar.SetBarValueCalls
send("UNIT_POWER_UPDATE", "player", "ENERGY")
assert(power.Bar:GetValue() == 52 and power.Bar.SetBarValueCalls == calls)
state.points = 4
send("COMBO_TARGET_CHANGED")
assert(combo.segments[5]:GetValue() == 4)
state.gcd = { startTime = ui.time, duration = 1.5 }
send("SPELL_UPDATE_COOLDOWN")
assert(power.Gcd:IsShown())

send("PLAYER_ENTER_COMBAT")
assert(main:IsShown() and main.waiting and main.Text:GetText() == "Waiting")
state.queued, ui.time = true, 101
send("CURRENT_SPELL_CAST_CHANGED")
send("PLAYER_SWING", 2.5, env.Enum.PlayerSwingType.MainHand)
assert(main.swingEnd == 103.5 and main.Spark:IsShown() and main.Bar.barColor[1] == 0.9)
send("UNIT_COMBAT", "player", "PARRY")
assert(main.swingEnd == 102.5)
ui.time, state.speed = 102, 2
send("UNIT_ATTACK_SPEED", "player")
assert(math.abs(main.swingEnd - 102.4) < 0.001)
main:RunScript("OnUpdate", 1)
assert(main.Bar:GetValue() > 0 and main.Text:GetText() ~= "Waiting")
send("PLAYER_LEAVE_COMBAT")
ui.time = 103
main:RunScript("OnUpdate", 1)
assert(main.swingHold and not main.Spark:IsShown())
main.swingHold.callback()
assert(not main:IsShown())

send("PLAYER_SWING", 3, env.Enum.PlayerSwingType.Ranged)
assert(ranged.StandStill:IsShown() and ranged.StandStill:GetWidth() < ranged.Bar:GetWidth())
send("PLAYER_SWING_RANGE_UPDATE", env.Enum.PlayerSwingType.Ranged, false, true)
assert(ranged.outOfRange and ranged.Bar.barColor[1] == rb.colors.outOfRange[1])
send("PLAYER_SWING_RANGE_UPDATE", env.Enum.PlayerSwingType.Ranged, true, true)
assert(not ranged.outOfRange)
send("PLAYER_DEAD")
ranged:RunScript("OnUpdate", 1)
assert(not ranged.swingEnd and not ranged.StandStill:IsShown())
-- (11-24) the auto attack state: read as the world loads (a reload in the middle of it), gone with your death
state.attacking, state.shooting = true, true
send("PLAYER_ENTERING_WORLD")
assert(rb.auto.melee and rb.auto.ranged)
send("PLAYER_DEAD")
assert(not rb.auto.melee and not rb.auto.ranged)
state.attacking, state.shooting = false, false
send("PLAYER_ENTERING_WORLD")
assert(not rb.auto.melee and not rb.auto.ranged)
-- queued attacks: only the classes that have one ask
local wasClass = playerClass
assert(rb.HasQueued())
playerClass = "ROGUE"
assert(not rb.HasQueued())
playerClass = wasClass

ui:emit("MIRROR_TIMER_START", "BREATH", 29000, 60000, -1, 0, "Breath")
assert(timer:IsShown() and not timer.Bar:IsShown() and rb.Timer.parts[1].Time:GetText() == "29")
ui:emit("MIRROR_TIMER_START", "EXHAUSTION", 95000, 120000, -2, 1, "Fatigue")
assert(rb.Timer.parts[2].Time:GetText() == "48" and rb.Timer.parts[2]:IsShown())
ui:emit("MIRROR_TIMER_PAUSE", "BREATH", 1)
assert(not timer:GetScript("OnUpdate"), "paused timers should not tick")
ui:emit("MIRROR_TIMER_STOP", "BREATH")
assert(rb.Timer.parts[1].Label:GetText() == "Fatigue" and not rb.Timer.parts[2]:IsShown())
config.bars.timer.enabled = false
rb.SetTimerBars(false)
assert(not timer:IsShown() and env.MirrorTimerContainer:IsShown())
config.bars.timer.enabled = true
rb.SetTimerBars(true)
assert(timer:IsShown() and not env.MirrorTimerContainer:IsShown())
ui:emit("MIRROR_TIMER_STOP", "EXHAUSTION")
assert(not timer:IsShown())

local sample = rb.CreateSample(env.UIParent, "timer")
rb.DrawSample(sample)
assert(sample.Text:GetText() == "42" and sample.Bar:GetValue() == 0.7)
ui.editing = true
callbacks.enter()
assert(main:IsShown() and hp.Bar:GetValue() == 0.25 and timer:IsShown())
ui.editing = false
callbacks.exit()
assert(hp.Bar:GetValue() == 20 and not timer:IsShown() and not main:IsShown())
move[hp](hp, "Modern", "BOTTOM", 4.4, 20.6)
callbacks.layout("Modern")
assert(hp:GetPoint() == "BOTTOM" and select(5, hp:GetPoint()) == 21)
print("PASS: resource health, shapeshift power, swing timing, mirror timers and Edit Mode")
