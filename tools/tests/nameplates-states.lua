local H = dofile("tools/tests/perf-helpers.lua")
local ui, ns = dofile("tools/tests/fixtures/unitframes-ui.lua")({
    styleStart = true, auraSwipe = false, auraTimer = "none", auraTimerColor = true,
    frameFontsSeeded = true, castTimeSeeded = true,
})
local env = ui.env
local db = {
    enabled = true,
    types = {
        enemy = { width = 165 },
        friendly = { nameOnlySize = 130 },
        minion = { width = 166 },
    },
    combatPlates = "friendly,enemy,enemyPlayer,minion",
    targetArrows = "chevron",
    targetGlow = true, targetBarColor = true,
}
ns.db.profile.nameplates = db
ns.db.profile.tweaks = { nameplateQuest = true }
ns.defaults.profile.nameplates = { plate = "bar", castTimer = true, auraRows = "stacked" }
local units = {}
local secret = {}
env.canaccessvalue = function(value) return value ~= secret end
env.UnitCanAttack = function(_, unit) return units[unit].attack end
env.UnitIsFriend = function(_, unit) return units[unit].friend end
env.UnitIsPlayer = function(unit) return unit == "player" or units[unit].player end
env.UnitIsMinion = function(unit) return units[unit].minion end
env.UnitClassification = function(unit) return units[unit].classification end
env.UnitIsUnit = function(a, b) return a == b end
env.UnitIsGameObject = function(unit) return units[unit].object end
env.UnitNameplateShowsWidgetsOnly = function(unit) return units[unit].widget end
env.UnitName = function() return "Juniper" end
env.C_DurationUtil = { CreateDurationTextBinding = function() end }
env.C_AddOns.IsAddOnLoaded = function() return false end
env.GetCVarBool = function() return true end
env.C_CVar = { GetCVar = function() return nil end }
local Widget = getmetatable(env.UIParent)
function Widget:SetOffset(x, y) self.offset = { x, y } end
function Widget:SetAlphaFromBoolean(value, on, off)
    if value == secret then self.secretBoolean = value; value = true end
    self:SetAlpha(value and on or off)
end
function Widget:SetVertexColorFromBoolean(value, _, _)
    assert(value == secret)
    self.secretColour = value
end
function Widget:SetTimerDuration(duration, interpolation, direction)
    self.timerDuration, self.timerInterpolation, self.timerDirection = duration, interpolation, direction
end
H.loadSections("Core.lua", {
    {"function ns.CastGlowDefault(", "-- For a time Lua can read"},
}, env)
ui:load("Modules/Nameplates.lua", ns)
local plates = ns.Nameplates

assert(plates:ShouldLoad())
assert(db.targetArrows == "npe" and db.types.enemy == nil and db.types.friendly == nil and db.types.minion == nil)
assert(db.combatPlates == "friendlyPlayer,friendlyNpc,enemyPlayer,enemyNpc,minor")
assert(db.auraSwipe == false and db.auraTimer == "none" and db.auraTimerColor)
assert(plates.TypeDB("enemyNpc").width == 165 and plates.TypeDB("enemyPlayer").width == 165)
assert(plates.TypeDB("friendlyPlayer").plate == "name" and plates.TypeDB("friendlyNpc").nameOnlySize == 130)
assert(plates.TypeDB("minor").width == 100)

plates.SetPreset("enemyNpc", "compact")
assert(plates.TypeDB("enemyNpc").width == 100 and plates.TypeDB("enemyNpc").castbar)
plates.TypeSet("enemyNpc", "width", 100)
assert(plates.PresetOf("enemyNpc") == "compact", "a no-op setting keeps its preset")
plates.TypeSet("enemyNpc", "width", 112)
assert(plates.PresetOf("enemyNpc") == "custom" and plates.TypeDB("enemyNpc").debuffs == "off")
plates.SetPreset("enemyNpc", "name")
assert(plates.TypeDB("enemyNpc").plate == "name" and not plates.TypeDB("enemyNpc").castbar)
plates.SetPreset("enemyNpc", "custom")
assert(plates.TypeDB("enemyNpc").width == 112 and plates.TypeDB("enemyPlayer").width == 165)

units.unknown = { attack = secret, friend = secret }
units.vendor = { attack = false, friend = true }
units.ally = { attack = false, friend = true, player = true }
units.opponent = { attack = true, friend = false, player = true }
units.pet = { attack = false, friend = true, minion = true }
units.trivial = { attack = true, friend = false, classification = "minus" }
units.peaceful = { attack = false, friend = false }
units.mailbox = { object = true }
units.progress = { widget = true }
units.player = units.ally
assert(plates.Kind("vendor") == "friendlyNpc" and plates.Kind("ally") == "friendlyPlayer")
assert(plates.Kind("opponent") == "enemyPlayer" and plates.Kind("pet") == "minor" and plates.Kind("trivial") == "minor")
assert(not plates.WantsPlate("mailbox") and not plates.WantsPlate("progress") and not plates.WantsPlate("player"))
local want, kind, unknown = plates.WantsPlate("unknown")
assert(not want and not kind and unknown)
db.peacefulNames = true
assert(plates.Peaceful("peaceful", "enemyNpc") and not plates.Peaceful("opponent", "enemyPlayer"))
plates.TypeSet("enemyPlayer", "plate", "blizzard")
assert(not plates.WantsPlate("opponent") and plates.WantsPlate("vendor"))
plates.TypeSet("enemyPlayer", "plate", "bar")

-- The settings cards build the actual plate, layout and cast bar. Exercise state changes
-- on the same widgets so stale icons, glows, arrows and layout become observable.
local f = plates.CreateSample(env.UIParent, "enemyNpc")
f.kind = "enemyNpc"
for key, value in pairs({
    execute = 20, level = "disc", castbar = true, castTarget = true, castImportant = true,
    debuffs = "mine", buffs = "all", cc = true, defensives = true,
    threatGlow = true, aggroFlash = true, questProgress = true, nameAbove = "middle:fullname",
}) do plates.TypeSet("enemyNpc", key, value) end
local width, height = plates.DrawSample(f, {
    target = true, cast = true, kick = true, important = true, targeted = true,
    threat = true, execute = true, quest = true,
})
local p = f.plates[1]
assert(width == f:GetWidth() and height == f:GetHeight() and p.root:IsVisible())
assert(p.health:GetValue() == 0.15 and p.execMark:IsShown() and p.execTint:GetAlpha() == 1)
assert(p.targetTint:IsShown() and p.targetGlow:IsShown() and p.discGlow:IsShown())
assert(p.arrows.left:IsShown() and p.arrows.right.bounce:IsPlaying() and not p.arrows.top:IsShown())
assert(p.threatKey == "aggro" and p.flashAnim:IsPlaying() and not p.threatFx:IsShown(),
    "the target border has priority over the threat border")
assert(p.cast:IsShown() and p.cast.target:GetText() == "Juniper" and p.cast.kickClip:IsShown())
assert(p.cast.important:GetAlpha() == 1 and p.cast.targetedPulse:IsPlaying())
assert(p.debuffIcon:IsShown() and p.buffIcon:IsShown() and p.ccIcon:IsShown() and p.defIcon:IsShown())
assert(p.quest:IsShown() and p.questText:GetText() == "3/8")
assert(p.hits["np.castbar"]:IsShown() and p.hits["np.debuffs"]:IsShown())
ui.time = 0.4
plates.Pulse.driver:RunScript("OnUpdate", 0.1)
assert(p.cast.important.edge:GetAlpha() < 0.3)

plates.DrawSample(f, { threat = true })
assert(p.threatFx:IsShown() and p.threatFx.pulse:IsPlaying())
plates.DrawSample(f, "nokick")
assert(p.cast.shield:GetAlpha() == 1 and not p.cast.targetedPulse:IsPlaying())
assert(not p.flashAnim:IsPlaying() and not p.targetGlow:IsShown() and p.execTint:GetAlpha() == 0)
db.targetArrowSide = "top"
plates.DrawSample(f, "overview")
assert(f.cycling and not p.targetGlow:IsShown())
f:RunScript("OnUpdate", 2.6)
assert(p.targetGlow:IsShown() and p.arrows.top:IsShown() and not p.arrows.left:IsShown())
plates.SetPreset("enemyNpc", "name")
plates.DrawSample(f, {})
assert(not f.cycling and not p.health:IsShown() and not p.cast:IsShown() and not p.hits["np.castbar"]:IsShown())

local native, aliases, simplified = {}, {}, {}
local callbacks, size = {}, { 110, 17 }
local token, testMob = "nameplate1", { attack = true, friend = false, classification = "elite", health = 100, threat = 1 }
units[token] = testMob
local gamePlate = env.CreateFrame("Frame", nil, env.UIParent)
gamePlate.unitToken = token
gamePlate.UnitFrame = env.CreateFrame("Frame", nil, gamePlate)
gamePlate.UnitFrame.WidgetContainer = env.CreateFrame("Frame", nil, gamePlate.UnitFrame)
gamePlate.UnitFrame.SoftTargetFrame = env.CreateFrame("Frame", nil, gamePlate.UnitFrame)
gamePlate.UnitFrame.isSimplified = true
gamePlate.UnitFrame:RegisterUnitEvent("UNIT_HEALTH", token)
function gamePlate:CanChangeHitTestPoints() return true end
function gamePlate:SetAllHitTestPoints(frame) assert(frame == self); self.clickEnabled = true end
function gamePlate:ClearAllHitTestPoints() self.clickEnabled = false end
native[1] = gamePlate
env.C_NamePlate = {
    GetNamePlateForUnit = function(unit) return aliases[unit] or (unit == token and gamePlate or nil) end,
    GetNamePlates = function() return native end,
    GetNamePlateSize = function() return unpack(size) end,
    SetNamePlateSize = function(...) size = { ... } end,
}
env.C_NamePlateManager = { SetNamePlateSimplified = function(unit, on) simplified[unit] = on end }
local cvars = { nameplateSelectedScale = "1.3", nameplateTargetRadialPosition = "0" }
env.C_CVar.GetCVar = function(name) return cvars[name] end
env.SetCVar = function(name, value) cvars[name] = tostring(value) end
env.C_AddOns.DoesAddOnExist = function() return false end
env.IsInGroup, env.IsInRaid, env.IsInInstance = function() return false end, function() return false end, function() return false end
env.UnitExists = function(unit) return unit == "player" or units[unit] ~= nil or aliases[unit] ~= nil end
env.UnitIsTapDenied = function(unit) return units[unit] and units[unit].tapped end
env.UnitIsDeadOrGhost = function() return false end
env.UnitReaction = function() return 2 end
env.UnitHealth = function(unit) return assert(units[unit]).health end
env.UnitHealthMax = function() return 100 end
env.UnitGetIncomingHeals = function() return 8 end
env.UnitGetTotalAbsorbs = function() return 12 end
env.UnitThreatSituation = function(_, unit) return units[unit].threat end
env.UnitAffectingCombat = function() return true end
env.UnitThreatPercentageOfLead = function() return 18 end
env.UnitDetailedThreatSituation = function(_, unit) return false, units[unit].threat, 80 end
env.canaccessallvalues = function(...)
    for i = 1, select("#", ...) do if select(i, ...) == secret then return false end end
    return true
end
env.GetRaidTargetIndex = function(unit) return units[unit].raid end
env.SetRaidTargetIconTexture = function(tex, raid) tex.raid = raid end
env.UnitCastingInfo, env.UnitChannelInfo = function() end, function() end
env.Enum = {
    LuaCurveType = { Step = 1 },
    StatusBarInterpolation = { Immediate = 0 },
    StatusBarTimerDirection = { ElapsedTime = 1, RemainingTime = 2 },
}
env.C_CurveUtil = { CreateCurve = function()
    return {
        points = {},
        SetType = function(_, kindValue) assert(kindValue == env.Enum.LuaCurveType.Step) end,
        AddPoint = function(curve, x, y) curve.points[#curve.points + 1] = { x, y } end,
    }
end }
env.UnitHealthPercent = function(unit, _, curve)
    local share = units[unit].health / 100
    if curve == env.CurveConstants.ScaleTo100 then return share * 100 end
    local result
    for _, point in ipairs(curve.points) do if share >= point[1] then result = point[2] end end
    return result
end
env.C_QuestLog = { UnitIsRelatedToActiveQuest = function() return false end }
env.C_Spell = {
    GetSpellName = function(id) return "Spell " .. id end,
    IsSpellInRange = function(_, unit) return units[unit].inRange == true end,
}
ns.UnitShownLevel = function() return 44 end
ns.UnitLevelColor = function() return { r = 1, g = 0.7, b = 0 } end
ns.SetBarValue = function(bar, value) bar:SetValue(value) end
ns.LogError = function(where, err) error(where .. ": " .. err, 0) end
ns.db.global = {}
db.role, db.rangeAlpha, db.targetScale, db.nonTargetAlpha, db.clampTarget = "damage", 0.35, 1.25, 0.55, true
env.UsefulPlatesAndTooltips_API = {}
function plates:RegisterEvent(event, cb) callbacks[event] = cb end
function plates:UnregisterAllEvents() callbacks = {} end
local function send(event, arg)
    local cb = assert(callbacks[event], "event not registered: " .. event)
    if type(cb) == "string" then plates[cb](plates, event, arg) else cb(event, arg) end
end
plates.SetPreset("enemyNpc", "custom")
plates.TypeSet("enemyNpc", "threat", "always")
plates.TypeSet("enemyNpc", "threatPercent", true)
plates.TypeSet("enemyNpc", "colorElite", true)
plates:Init()
local live = assert(plates.PartsFor(gamePlate))
assert(live.unit == token and live ~= p and not live.sample and gamePlate.FlareUIHealthBar == live.health)
assert(gamePlate.UnitFrame:GetAlpha() == 0 and not gamePlate.UnitFrame:IsEventRegistered("UNIT_HEALTH"))
assert(gamePlate.UnitFrame.WidgetContainer:GetParent() == gamePlate and gamePlate.clickEnabled)
assert(simplified[token] == false and cvars.nameplateSelectedScale == "1" and cvars.nameplateTargetRadialPosition == "1")
assert(live.threatKey == "gaining" and live.threatText:GetText() == "80%")
assert(live.health:GetValue() == 100 and live.textHolder:GetAlpha() == 0 and live.holder:GetAlpha() == 0.35)
assert(live.heal:GetValue() == 8 and live.absorb:GetValue() == 12)

testMob.health, testMob.raid, testMob.threat, testMob.inRange = 10, 3, 2, true
live.events:RunScript("OnEvent", "UNIT_HEALTH", token)
assert(live.health:GetValue() == 10 and live.textHolder:GetAlpha() == 1 and live.execTint:GetAlpha() == 1)
assert(live.trail:GetValue() == 100)
ui.time = 1
ns.UnitFrames.trailDriver:RunScript("OnUpdate", 0.7)
assert(live.trail:GetValue() == 10)
live.events:RunScript("OnEvent", "UNIT_THREAT_LIST_UPDATE", token)
assert(live.threatKey == "gaining", "threat changes are coalesced to the next frame")
plates.colorQueue.driver:RunScript("OnUpdate", 0.1)
assert(live.threatKey == "aggro" and live.flashAnim:IsPlaying())
send("RAID_TARGET_UPDATE")
assert(live.raid:IsShown() and live.raid.raid == 3)
plates.RangeTick()
assert(live.holder:GetAlpha() == 1)

aliases.target = gamePlate
send("PLAYER_TARGET_CHANGED")
assert(live.targetTint:IsShown() and live.root:GetScale() == 1.25)
aliases.target = env.CreateFrame("Frame", nil, env.UIParent)
send("PLAYER_TARGET_CHANGED")
assert(not live.targetTint:IsShown() and live.root:GetAlpha() == 0.55)
aliases.mouseover = gamePlate
send("UPDATE_MOUSEOVER_UNIT")
assert(live.highlight:IsShown() and live.root:GetAlpha() == 1)
aliases.mouseover = nil
send("UPDATE_MOUSEOVER_UNIT")
assert(not live.highlight:IsShown() and live.root:GetAlpha() == 0.55)

-- Cast timing stays in the client-facing duration object, including when either
-- the interruptibility or targeting flag cannot be read by addon Lua.
local casting, channeling, blocked = true, false, false
local duration = { GetTotalDuration = function() return 3 end, GetElapsedDuration = function() return 1 end }
local remaining = { GetRemainingDuration = function() return 0.75 end }
function env.UnitCastingInfo(unit)
    if casting then
        assert(unit == token)
        return "Shadow Bolt", "Shadow Bolt", 161, nil, nil, nil, nil, blocked, 686, 10
    end
end
function env.UnitChannelInfo(unit)
    if channeling then
        assert(unit == token)
        return "Drain Soul", nil, 162, nil, nil, nil, blocked, 1120, nil, nil, 11
    end
end
env.UnitCastingDuration, env.UnitChannelDuration = function() return duration end, function() return duration end
env.C_Spell.IsSpellImportant = function(spell) return spell == 686 end
env.C_Spell.GetSpellCooldownDuration = function(spell) assert(spell == 2139); return remaining end
env.PlayerIsSpellTarget = function() return secret end
env.UnitSpellTargetName = function() return "Juniper" end
env.UnitSpellTargetClass = function() return "MAGE" end
local makeColour = env.CreateColor
function env.CreateColor(...)
    local c = makeColour(...)
    function c:SetRGB(r, g, b) self.r, self.g, self.b = r, g, b end
    return c
end
local kick = ns.UnitFrames.KICK
kick.known[2139] = false
live.events:RunScript("OnEvent", "UNIT_SPELLCAST_START", token)
assert(live.cast:IsShown() and live.cast.Text:GetText() == "Shadow Bolt" and live.root:GetAlpha() == 1)
assert(live.cast.timerDuration == duration and live.cast.timerDirection == env.Enum.StatusBarTimerDirection.ElapsedTime)
assert(live.cast.kickClip:IsShown() and live.cast.kickWait:GetValue() == 0.75)
assert(live.cast.targeted.secretBoolean == secret and live.cast.target:GetText() == "Juniper")
blocked = secret
live.events:RunScript("OnEvent", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE", token)
assert(live.cast.shield.secretBoolean == secret and live.cast:GetStatusBarTexture().secretColour == secret)
assert(live.cast.kickClip:GetAlpha() == 0)
casting, channeling, blocked = false, true, false
live.events:RunScript("OnEvent", "UNIT_SPELLCAST_CHANNEL_START", token)
assert(live.cast.Text:GetText() == "Drain Soul" and live.cast.kickWait:GetReverseFill())
assert(live.cast.timerDirection == env.Enum.StatusBarTimerDirection.RemainingTime)
kick.known[2139] = true
live.events:RunScript("OnEvent", "UNIT_SPELLCAST_CHANNEL_UPDATE", token)
assert(not live.cast.kickClip:IsShown())
channeling = false
env.C_Timer.NewTimer = env.C_Timer.NewTicker
live.events:RunScript("OnEvent", "UNIT_SPELLCAST_CHANNEL_STOP", token, "cast", 1120, "Player-1", 11)
assert(live.cast.Text:GetText() == "Interrupted" and live.cast.flashing)
live.cast.flashTimer.callback()
assert(not live.cast:IsShown() and live.root:GetAlpha() == 0.55)

env.GetCVar = function() return "0" end
env.Enum.TooltipDataLineType = { QuestTitle = 1, QuestPlayer = 2, QuestObjective = 3 }
local questRelated, tooltipLine = true, { type = 3, leftText = "Spider fangs: 3/8" }
env.C_QuestLog.UnitIsRelatedToActiveQuest = function() return questRelated end
env.C_TooltipInfo = { GetUnit = function()
    return { lines = { { leftText = "Forest Spider" }, { type = 1, leftText = "Spider Slayer" }, tooltipLine } }
end }
send("QUEST_LOG_UPDATE")
send("UNIT_QUEST_LOG_CHANGED")
ui:flushTimers()
assert(live.quest:IsShown() and live.questText:GetText() == "3/8")
tooltipLine.leftText = secret
plates.UpdateQuest(live)
assert(live.questText:GetText() == "3/8", "a secret quest answer does not clear the current display")
tooltipLine.leftText = "Spider fangs: 8/8"
plates.UpdateQuest(live)
assert(not live.quest:IsShown() and not live.questText:IsShown())
questRelated = false

plates.TestMode(true, nil)
plates.TestTick()
assert(live.cast:IsShown() and live.questText:GetText() == "3/8")
ui.time = 22
plates.TestTick()
assert(not plates.testing and not live.cast:IsShown() and not live.questText:IsShown())

send("NAME_PLATE_UNIT_REMOVED", token)
assert(not plates.PartsFor(gamePlate) and gamePlate.FlareUIHealthBar == nil and gamePlate.UnitFrame:GetAlpha() == 1)
assert(gamePlate.UnitFrame.WidgetContainer:GetParent() == gamePlate.UnitFrame and simplified[token])
assert(gamePlate.UnitFrame:IsEventRegistered("UNIT_HEALTH") and not live.events:IsEventRegistered("UNIT_HEALTH"))
send("NAME_PLATE_UNIT_ADDED", token)
assert(plates.PartsFor(gamePlate) == live, "release returns the plate to the pool")
plates.StandDown()
assert(not plates.PartsFor(gamePlate) and not next(callbacks) and size[1] == 110 and size[2] == 17)
assert(cvars.nameplateSelectedScale == "1.3" and cvars.nameplateTargetRadialPosition == "0")
print("PASS: nameplates migrate presets, draw preview states and claim, update and release live plates")
