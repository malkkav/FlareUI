local H = dofile("tools/tests/perf-helpers.lua")
local ui, ns = dofile("tools/tests/fixtures/unitframes-ui.lua")({
    styleStart = true, auraSwipe = false, auraTimer = "none", auraTimerColor = true,
    frameFontsSeeded = true, castTimeSeeded = true,
})
local env = ui.env
ns.PALETTE = { bronze5 = { 0.85, 0.68, 0.47 }, parchment = { 0.93, 0.85, 0.68 } }
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
    nameFont = { face = "Expressway", size = 17, flags = "OUTLINE" },
}
ns.db.profile.nameplates = db
-- (Quality of Life's old switches, moved once into the module's own: MigrateProfile)
ns.db.profile.tweaks = { nameplateQuest = true, combatPlates = true, nameplateHideNames = true }
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
env.UnitGUID = function() return "Player-1-0001" end
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
H.loadCore(env, ns)
ui:load("Modules/Nameplates.lua", ns)
local plates = ns.Nameplates

assert(plates:ShouldLoad())
for _, other in ipairs({ "Platynator", "MFNameplates" }) do
    env.C_AddOns.IsAddOnLoaded = function(name) return name == other end
    assert(plates.OtherAddon() == other, other .. " runs the nameplates")
end
env.C_AddOns.IsAddOnLoaded = function() return false end
assert(not plates.OtherAddon())
assert(db.ownSwitches and db.questMarks and not db.comboPoints and not db.enemyInCombat and next(ns.db.profile.tweaks) == nil,
    "the quest switch moves; In Combat plates did nothing with Quality of Life off, so they don't start now")
assert(db.nameOnlyFontV1 and db.nameOnlyFont ~= db.nameFont and db.nameOnlyFont.size == 17 and db.nameOnlyFont.face == "Expressway",
    "Name Only starts with the Names font it used")
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
-- (11-27) new players: Name Only keeps the type's own cast bar for the whole plate; an account that used
-- FlareUI before keeps the old preset, which turned it off (nameplates.legacyBase, Import.lua 5)
assert(plates.TypeDB("enemyNpc").plate == "name" and plates.TypeDB("enemyNpc").castbar)
db.legacyBase = true
assert(plates.TypeDB("enemyNpc").plate == "name" and not plates.TypeDB("enemyNpc").castbar)
db.legacyBase = nil
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
assert(p.arrows.left:IsShown() and p.arrows.right:IsShown() and not p.arrows.top:IsShown())
-- (11-25) the quest mark: its own art, half as wide as tall as the art is, 2 from the plate
do
    local w, h = p.quest:GetSize()
    assert(w / h == 0.5 and p.quest:GetTexture():find("QuestMark", 1, true))
    assert(math.abs((select(4, p.quest:GetPoint(1)))) == 2 + p.sideRoom[p.questSide])
    assert(p.questPad == math.floor(w * 0.14 + 0.5))
end
-- (11-25) Target Highlight: the bar only gets brighter, and its colour is fixed
do
    local tint, set = nil, p.targetTint.SetColorTexture
    p.targetTint.SetColorTexture = function(_, ...) tint = { ... } end
    plates.LayoutTargetLook(p, plates.TypeDB("enemyNpc"), 19, false)
    p.targetTint.SetColorTexture = set
    plates.PlaceSides(p)
    assert(tint[1] == 1 and tint[2] == 1 and tint[3] == 1 and tint[4] < 0.3, "white, whatever the colours are")
    local palette, custom = db.palette, db.customColors
    db.palette, db.customColors = "custom", { target = { 0.1, 0.2, 0.3 }, cast = { 0.4, 0.5, 0.6 } }
    assert(plates.Color("target")[1] == plates.C.COLORS.target[1])
    db.palette, db.customColors = palette, custom
end
-- the arrows push what sits beside the plate away, and only while they show
do
    local a, room = p.arrows.right, plates.ArrowRoom(p, "right")
    assert(room > 1 and p.sideRoom.right == room)
    local function x() return (select(4, p.quest:GetPoint(1))) end
    local shownAt = x()
    a:Hide() p.arrows.left:Hide()
    plates.PlaceSides(p)
    assert(math.abs(shownAt) > math.abs(x()), "the quest mark stands past the arrow")
    assert(p.sideRoom.left == 0 and p.sideRoom.right == 0)
    a:Show() p.arrows.left:Show()
    plates.PlaceSides(p)
    assert(x() == shownAt)
end
-- Crowd Control and Defensives: their own shape, swipe and timer once picked, the plate's until then
do
    local old = ns.AuraLook
    ns.AuraLook = { ForUnit = function(_, _, _, style, _, timer, _, opts) return { style = style, timer = timer, swipe = opts.swipe } end }
    local db = plates.TypeDB("enemyNpc")
    local base = plates.AuraLook(24, true, db)
    -- (11-27) new players: the big icons start round, both swipes, the timer in the middle
    local same = plates.AuraLook(24, true, db, true)
    assert(same.style == "round" and same.swipe == "both" and same.timer == "middle")
    -- (back 11-27) once picked, the big icons draw their own; the rows keep the plate's
    db.ccStyle, db.ccSwipe, db.ccTimer = "round", "border", "middle"
    local big = plates.AuraLook(24, true, db, true)
    assert(big.timer == "middle" and big.swipe == "border" and big.style == "round")
    local rows = plates.AuraLook(24, true, db)
    assert(rows.timer == base.timer and rows.swipe == base.swipe and rows.style == base.style)
    db.ccStyle, db.ccSwipe, db.ccTimer = nil, nil, nil
    ns.AuraLook = old
end
-- the arrow's bounce: from rest, 3 px towards the plate half way, back at rest after both ways
do
    local a = p.arrows.right
    local function x() return (select(4, a.tex:GetPoint(1))) end
    a:RunScript("OnUpdate", 0)
    assert(math.abs(x()) < 1e-6, "starts at rest")
    a:RunScript("OnUpdate", plates.C.BOUNCE_TIME)
    assert(math.abs(x() + 3) < 1e-6, "the right one moves left")
    a:RunScript("OnUpdate", plates.C.BOUNCE_TIME)
    assert(math.abs(x()) < 1e-6, "and comes back")
end
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
-- the clock looks up what shows five times a second, not every frame
do
    local edge, asked = p.cast.important.edge, 0
    local see = edge.IsVisible
    edge.IsVisible = function(self) asked = asked + 1 return see(self) end
    plates.Pulse.wait = 0
    for _ = 1, 60 do plates.Pulse.driver:RunScript("OnUpdate", 1 / 60) end
    assert(asked >= 5 and asked <= 6, "a second of frames: " .. asked)
    edge.IsVisible = nil
    local other = plates.ClockPulse(env.CreateFrame("Frame", nil, env.UIParent))
    other:Play()
    plates.Pulse.driver:RunScript("OnUpdate", 0.01)
    assert(#plates.Pulse.live >= 2, "a pulse just played joins at once")
    local n = #plates.Pulse.live
    other:Stop()
    plates.Pulse.driver:RunScript("OnUpdate", 0.01)
    assert(#plates.Pulse.live == n - 1)
end

-- the bar starts where the border's line ends: no gap, and no corner past the slanted border (johnivve 11-23)
do
    local DIR = "Borders/"
    assert(plates.BorderFit(DIR .. "FlareUI-Frames.tga", 12) == 3 and plates.BorderFit(DIR .. "FlareUI-Thick.tga", 8) == 2)
    assert(plates.BorderFit(DIR .. "FlareUI-Thin.tga", 6) == 3)
    assert(plates.BorderFit("Other.tga", 12) == nil and plates.BorderFit(nil, 0) == nil)
    local function Offset(frame)
        local _, _, _, x, y = frame:GetPoint(1)
        return x, y
    end
    for key, value in pairs({ border = "FlareUI-Thick", castBorder = "FlareUI-Frames", castHeight = 14, level = "box", height = 16 }) do
        plates.TypeSet("enemyNpc", key, value)
    end
    plates.DrawSample(f, { cast = true })
    local x, y = Offset(p.health)
    assert(x == 3 and y == -3, "the bar right at the line")
    assert(p.root:GetHeight() == 16 + 6 and Offset(p.levelInner) == 3, "the level box too")
    -- (the kit's backdrop is 4 px round a 14 px cast bar)
    assert(Offset(p.cast.Border) == 1, "the cast bar's border too")
    -- (11-27) with the icon on, the divider between the icon and the bar: the cast border's own art
    plates.TypeSet("enemyNpc", "castIcon", true)
    plates.DrawSample(f, { cast = true })
    local divider = p.cast.FlareUI_Divider
    assert(divider and divider:IsShown(), "the icon divider on the plate's cast bar")
    plates.TypeSet("enemyNpc", "castIcon", false)
    plates.DrawSample(f, { cast = true })
    assert(not divider:IsShown(), "no icon, no divider")
    -- a border with art we don't know: as far as its background always reached
    plates.TypeSet("enemyNpc", "border", "Other")
    plates.DrawSample(f, { cast = true })
    assert(Offset(p.health) == 3 and Offset(p.levelInner) == 3)
    plates.TypeSet("enemyNpc", "border", "None")
    plates.DrawSample(f, { cast = true })
    assert(Offset(p.health) == 1 and Offset(p.levelInner) == 1, "no border")
    for key, value in pairs({ border = "", castBorder = "", level = "disc" }) do plates.TypeSet("enemyNpc", key, value) end
end

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
local cvars = { nameplateSelectedScale = "1.3", nameplateTargetRadialPosition = "0", nameplateMinAlpha = "0.6", nameplateNotSelectedAlpha = "0.5" }
env.C_CVar.GetCVar = function(name) return cvars[name] end
env.SetCVar = function(name, value) cvars[name] = tostring(value) end
env.C_AddOns.DoesAddOnExist = function() return false end
env.IsInGroup, env.IsInRaid, env.IsInInstance = function() return false end, function() return false end, function() return false end
env.UnitExists = function(unit) return unit == "player" or units[unit] ~= nil or aliases[unit] ~= nil end
env.UnitIsDeadOrGhost = function() return false end
env.UnitReaction = function() return 2 end
local reads = {}
local function counted(key, get)
    return function(...)
        reads[key] = (reads[key] or 0) + 1
        return get(...)
    end
end
env.UnitIsDead = function(unit) return units[unit] and units[unit].dead or false end
env.UnitIsTapDenied = counted("color", function(unit) return units[unit] and units[unit].tapped end)
testMob.max, testMob.incoming, testMob.absorb = 100, 8, 12
env.UnitHealth = counted("health", function(unit) return units[unit].health end)
env.UnitHealthMax = counted("max", function(unit) return units[unit].max end)
env.UnitHealthMissing = counted("missing", function(unit) return units[unit].max - units[unit].health end)
env.UnitGetIncomingHeals = counted("incoming", function(unit) return units[unit].incoming end)
env.UnitGetTotalAbsorbs = counted("absorb", function(unit) return units[unit].absorb end)
env.UnitThreatSituation = function(_, unit) return units[unit].threat end
env.UnitAffectingCombat = function() return true end
env.UnitThreatPercentageOfLead = function() return 18 end
env.UnitDetailedThreatSituation = function(_, unit) return false, units[unit].threat, 80 end
env.canaccessallvalues = function(...)
    for i = 1, select("#", ...) do if select(i, ...) == secret then return false end end
    return true
end
env.GetRaidTargetIndex = counted("raid", function(unit) return units[unit].raid end)
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
    local share = units[unit].health / units[unit].max
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
db.notTargetScale = 0.88
db.palette, db.customColors = "custom", { tapped = { 0.4, 0.5, 0.6 } }
env.UsefulPlatesAndTooltips_API = {}
function plates:RegisterEvent(event, cb) callbacks[event] = cb end
function plates:UnregisterAllEvents() callbacks = {} end
local function send(event, arg)
    local cb = assert(callbacks[event], "event not registered: " .. event)
    if type(cb) == "string" then plates[cb](plates, event, arg) else cb(event, arg) end
end
local function nextFrame()
    plates.updateQueue.driver:RunScript("OnUpdate", 0)
end
local profileCallbacks = {}
function ns.db.RegisterCallback(owner, event, method)
    method = method or event
    if type(method) == "string" then
        profileCallbacks[event] = function(...) owner[method](owner, ...) end
    else
        profileCallbacks[event] = method
    end
end
local function profileEvent(event)
    assert(profileCallbacks[event], "missing profile callback " .. event)(event, ns.db, "Test")
end
plates.SetPreset("enemyNpc", "custom")
plates.TypeSet("enemyNpc", "barText", { health = { left = { firstname = 1 }, middle = {}, right = { value = 1, max = 2 } } })
plates.TypeSet("enemyNpc", "threat", "always")
plates.TypeSet("enemyNpc", "threatPercent", true)
plates.TypeSet("enemyNpc", "colorElite", true)
plates:Init()
local live = assert(plates.PartsFor(gamePlate))
assert(live.unit == token and live ~= p and not live.sample and gamePlate.FlareUIHealthBar == live.health)
assert(gamePlate.UnitFrame:GetAlpha() == 0 and not gamePlate.UnitFrame:IsEventRegistered("UNIT_HEALTH"))
assert(gamePlate.UnitFrame.WidgetContainer:GetParent() == gamePlate and gamePlate.clickEnabled)
assert(cvars.nameplateMinAlpha == "1" and cvars.nameplateNotSelectedAlpha == "1", "the game's own fades are off (11-24)")
assert(simplified[token] == false and cvars.nameplateSelectedScale == "1" and cvars.nameplateTargetRadialPosition == "1")
assert(live.threatKey == "gaining" and live.threatText:GetText() == "80%")
-- (11-23, #145) Threat Percentage in its own box, on the side away from the level, never in its place
assert(live.threatInLevel == false and live.threatBoxOn and live.threatBox:IsShown())
-- (11-25) the threat box is part of the plate: your target's border colour and Outer Glow reach it too
do
    local tdb = live.tdb
    live.tdb = setmetatable({ targetGlow = true, targetBorder = true }, { __index = tdb })
    live.targetShown, live.borderDirty = true, true
    plates.UpdateTargetLook(live)
    plates.PaintBorder(live)
    assert(live.threatGlow:IsShown() and live.targetGlow:IsShown())
    local r, g, b = live.threatBoxBorder:GetBackdropBorderColor()
    local r2, g2, b2 = live.border:GetBackdropBorderColor()
    assert(r == r2 and g == g2 and b == b2)
    live.targetShown, live.borderDirty, live.tdb = false, true, tdb
    plates.UpdateTargetLook(live)
    plates.PaintBorder(live)
    assert(not live.threatGlow:IsShown())
end
-- Threat Percentage: In a Group, In an Instance (the old switch's true is Always, its false Off)
do
    local tdb, group, instance = live.tdb, env.IsInGroup, env.IsInInstance
    local function shown(mode, inGroup, inInstance)
        env.IsInGroup = function() return inGroup end
        env.IsInInstance = function() return inInstance, inInstance and "party" or "none" end
        plates.UpdateGroup()
        live.tdb = setmetatable({ threatPercent = mode }, { __index = tdb })
        plates.UpdateThreatText(live, live.tdb)
        return live.threatText:IsShown()
    end
    assert(shown(true, false, false) and not shown(false, true, true) and not shown("off", true, true))
    assert(not shown("groups", false, true) and shown("groups", true, false))
    assert(not shown("instances", true, false) and shown("instances", false, true))
    env.IsInGroup, env.IsInInstance = group, instance
    plates.UpdateGroup()
    live.tdb = tdb
    plates.UpdateThreatText(live, tdb)
end
-- a tank's own number: its threat against the next in line, never stuck at 100 (11-24). Hidden values (an
-- instance) are drawn unread, the lead too while the threat state says you hold it
do
    local detail, situation, lead, util = env.UnitDetailedThreatSituation, env.UnitThreatSituation, env.UnitThreatPercentageOfLead, env.C_StringUtil
    local hidden, leadNow, state = false, 260, 3
    env.UnitDetailedThreatSituation = function()
        if hidden then return secret, secret, secret end
        return state >= 2, state, state >= 2 and 100 or 80
    end
    env.UnitThreatSituation = function() return state end
    env.UnitThreatPercentageOfLead = function() if hidden then return leadNow and secret end return leadNow end
    local asked = 0
    env.C_StringUtil = { RoundToNearestString = function(value) assert(value == secret) asked = asked + 1 return "260" end }
    local function text()
        plates.UpdateThreatText(live, live.tdb)
        return live.threatText:IsShown() and live.threatText:GetText() or nil
    end
    assert(text() == "260%", "holding it: the lead")
    leadNow = 12000
    assert(text() == "999%")
    leadNow = nil
    assert(text() == "100%", "nobody else on the list")
    leadNow = 0
    assert(text() == "100%")
    state, leadNow = 1, 260
    assert(text() == "80%", "not holding it: 100 is where you pull it")
    hidden, state = true, 3
    local value, status, isSecret = ns.ThreatPercent(live.unit)
    assert(value == secret and status == 3 and isSecret)
    assert(text() == "260%" and asked == 1, "hidden values: the lead, rounded by the client")
    -- (11-25) a hidden lead of 0: with nobody else on the mob it's 100, and a 0 that still comes is no text
    local alone, groupNow = ns.ThreatAlone, env.IsInGroup
    ns.ThreatAlone = function() return true end
    value, status, isSecret = ns.ThreatPercent(live.unit)
    assert(value == 100 and status == 3 and not isSecret and text() == "100%")
    ns.ThreatAlone = alone
    env.C_StringUtil.TruncateWhenZero = function(v) assert(v == secret) return "" end
    env.C_StringUtil.WrapString = function(infix, _, suffix) return infix == "" and "" or infix .. suffix end
    assert(text() == "", "no 0%")
    env.C_StringUtil.TruncateWhenZero = function() return "260" end
    assert(text() == "260%")
    env.C_StringUtil.TruncateWhenZero, env.C_StringUtil.WrapString = nil, nil
    -- who else is on its list: the group and the pets; a state that can't be read counts
    local exists, others = env.UnitExists, {}
    env.IsInGroup, env.IsInRaid = function() return true end, function() return false end
    env.UnitExists = function(token) return token == "party1" or token == "partypet1" or token == "pet" end
    env.UnitThreatSituation = function(token) if token == "player" then return state end return others[token] end
    assert(ns.ThreatAlone(live.unit))
    for _, token in ipairs({ "party1", "partypet1", "pet" }) do
        others = { [token] = 0 }
        assert(not ns.ThreatAlone(live.unit), token)
    end
    others = { party1 = secret }
    assert(not ns.ThreatAlone(live.unit))
    -- (a raid: you are one of its members)
    local raid, members, same = env.IsInRaid, env.GetNumGroupMembers, env.UnitIsUnit
    env.IsInRaid, env.GetNumGroupMembers = function() return true end, function() return 2 end
    env.UnitIsUnit = function(token) return token == "raid1" end
    env.UnitExists = function(token) return token == "raid1" or token == "raid2" end
    others = { raid1 = 3 }
    assert(ns.ThreatAlone(live.unit))
    others.raid2 = 1
    assert(not ns.ThreatAlone(live.unit))
    env.IsInRaid, env.GetNumGroupMembers, env.UnitIsUnit = raid, members, same
    env.UnitExists, env.IsInGroup = exists, groupNow
    env.UnitThreatSituation = function() return secret end
    value, status, isSecret = ns.ThreatPercent(live.unit)
    assert(value == secret and status == nil and isSecret and text() == "260%", "a hidden state: the number, uncoloured")
    env.C_StringUtil = nil
    assert(not text(), "a client that can't round it shows none")
    env.UnitDetailedThreatSituation = function() end
    assert(ns.ThreatPercent(live.unit) == nil and not text(), "not on its threat list")
    env.UnitDetailedThreatSituation, env.UnitThreatSituation, env.UnitThreatPercentageOfLead, env.C_StringUtil = detail, situation, lead, util
    plates.UpdateThreatText(live, live.tdb)
end
-- a plate's aura rows (11-24): only the ones its type uses get its unit, a few plates a frame
do
    local queue = plates.AuraQueue
    local function Fake(unit)
        local made = { unit = unit, auras = {} }
        for _, place in ipairs({ "debuffs", "buffs", "cc" }) do
            local set = {}
            made.auras[place] = { set = set, used = place ~= "cc",
                container = { SetUnit = function(_, value) set[#set + 1] = value end } }
        end
        return made
    end
    local one, two, three = Fake("nameplate11"), Fake("nameplate12"), Fake("nameplate13")
    for _, plate in ipairs({ one, two, three }) do plates.QueueAuras(plate) end
    plates.QueueAuras(one)
    assert(#queue.list == 3 and queue.driver:IsShown() and #one.auras.debuffs.set == 0, "nothing in the claim itself")
    queue.driver:RunScript("OnUpdate")
    assert(one.auras.debuffs.set[1] == "nameplate11" and two.auras.buffs.set[1] == "nameplate12" and #three.auras.debuffs.set == 0)
    assert(one.auras.cc.set[1] == "none" and #one.auras.cc.set == 1, "a row the type has off reads nobody's auras")
    -- let go before its turn: skipped; its rows are cleared once
    plates.ClearAuras(three)
    three.unit = nil
    assert(#queue.list == 0 and three.auras.debuffs.set[1] == "none")
    queue.driver:RunScript("OnUpdate")
    assert(not queue.driver:IsShown() and #three.auras.debuffs.set == 1)
    plates.ClearAuras(one)
    assert(one.auras.debuffs.set[2] == "none" and #one.auras.cc.set == 1, "a row on none is left alone")
    -- the same token again is a new unit
    one.unit = "nameplate11"
    plates.QueueAuras(one)
    queue.driver:RunScript("OnUpdate")
    assert(one.auras.debuffs.set[3] == "nameplate11")
    -- a row switched on while held, then a hidden plate
    one.auras.cc.used = true
    plates.SetAuraUnits(one)
    assert(one.auras.cc.set[2] == "nameplate11" and #one.auras.debuffs.set == 3)
    one.hiddenPlate = true
    plates.SetAuraUnits(one)
    assert(one.auras.cc.set[3] == "none" and one.auras.debuffs.set[4] == "none")
    plates.QueueAuras({})
    assert(#queue.list == 0, "a client without aura rows")
end
-- (11-25) a row's room is Width and 4 px on each side whatever the border takes: 8 icons of 18 in a width of 150
do
    local view = { width = 150, debuffs = "mine", buffs = "off" }
    assert(plates.AuraPerLine({ plateW = 156 }, view, 18) == 8 and plates.AuraOverhang({ plateW = 156 }, view) == 1)
    assert(plates.AuraOverhang({ plateW = 160 }, view) == 0 and plates.AuraRowWidth({ plateW = 160 }, view) == 160, "never less than the plate")
    view.buffs, view.auraRows = "all", "one"
    assert(plates.AuraPerLine({ plateW = 156 }, view, 18) == 4, "half each")
end
-- (11-25) the dispel type icons: only on friendly plates you can help, a plate reused in a fight included
do
    local AP, look, seen = ns.AuraPolicy, ns.AuraLook, nil
    local help = true
    ns.AuraPolicy = { CanDispelOn = function() return help end }
    ns.AuraLook = { DispelSide = function(_, hidden) seen = hidden end }
    local plate = { root = {}, auras = {}, unit = "nameplate14", kind = "friendlyPlayer" }
    plates.DispelSide(plate)
    assert(seen == false)
    help = false
    plates.DispelSide(plate)
    assert(seen == true, "under Mind Control")
    help, plate.kind = true, "enemyNpc"
    plates.DispelSide(plate)
    assert(seen == true)
    ns.AuraPolicy, ns.AuraLook = AP, look
end
assert(live.threatSide == (live.levelAnchor and live.levelSide == "right" and "left" or "right"))
assert(live.health:GetValue() == 100 and live.textHolder:GetAlpha() == 0 and live.holder:GetAlpha() == 0.35)
assert(live.heal:GetValue() == 8 and live.absorb:GetValue() == 12)

testMob.health, testMob.raid, testMob.threat, testMob.inRange = 10, 3, 2, true
reads = {}
for _ = 1, 8 do live.events:RunScript("OnEvent", "UNIT_HEALTH", token) end
assert(not reads.health and live.health:GetValue() == 100, "health events wait for the shared driver")
nextFrame()
assert(reads.health == 1 and not reads.max and not reads.incoming and not reads.absorb,
    "one health sample feeds the bar and text without refreshing the range or predictions")
assert(live.texts.right:GetText() == "10 / 100")
assert(live.health:GetValue() == 10 and live.textHolder:GetAlpha() == 1 and live.execTint:GetAlpha() == 1)
assert(live.trail:GetValue() == 100)
ui.time = 1
ns.UnitFrames.trailDriver:RunScript("OnUpdate", 0.7)
assert(live.trail:GetValue() == 10)
live.events:RunScript("OnEvent", "UNIT_THREAT_LIST_UPDATE", token)
send("GROUP_ROSTER_UPDATE")
send("PLAYER_ROLES_ASSIGNED")
assert(live.threatKey == "gaining", "threat changes are coalesced to the next frame")
reads = {}
nextFrame()
assert(reads.color == 1 and live.threatKey == "aggro" and live.flashAnim:IsPlaying(),
    "group-wide and per-unit colour requests paint the plate once")
reads = {}
send("RAID_TARGET_UPDATE")
send("RAID_TARGET_UPDATE")
assert(not reads.raid)
nextFrame()
assert(reads.raid == 1, "a raid-marker burst reads each plate once")
assert(live.raid:IsShown() and live.raid.raid == 3)
plates.RangeTick()
nextFrame()
assert(live.holder:GetAlpha() == 1)

testMob.max = 200
reads = {}
live.events:RunScript("OnEvent", "UNIT_MAXHEALTH", token)
nextFrame()
assert(reads.max == 1, "all ranges and maximum-health text share one maximum")
for _, bar in ipairs({ live.health, live.heal, live.absorb, live.trail }) do
    local _, maximum = bar:GetMinMaxValues()
    assert(maximum == 200, "a maximum-health change resizes each health overlay")
end
assert(live.texts.right:GetText() == "10 / 200")

reads = {}
testMob.absorb = 27
live.events:RunScript("OnEvent", "UNIT_ABSORB_AMOUNT_CHANGED", token)
live.events:RunScript("OnEvent", "UNIT_ABSORB_AMOUNT_CHANGED", token)
nextFrame()
assert(live.absorb:GetValue() == 27 and live.heal:GetValue() == 8)
assert(reads.absorb == 1 and not reads.incoming and not reads.health and not reads.max)
reads = {}
testMob.incoming = 21
live.events:RunScript("OnEvent", "UNIT_HEAL_PREDICTION", token)
nextFrame()
assert(live.heal:GetValue() == 21 and live.absorb:GetValue() == 27)
assert(reads.incoming == 1 and not reads.absorb and not reads.health and not reads.max)
reads = {}
testMob.absorb, testMob.incoming = 31, 16
local fallbackCalc = live.calc
live.calc = {
    GetIncomingHeals = counted("incoming", function() return testMob.incoming end),
    GetDamageAbsorbs = counted("absorb", function() return testMob.absorb end),
}
env.UnitGetDetailedHealPrediction = counted("prediction", function(unit, source, calc)
    assert(unit == token and source == "player" and calc == live.calc)
end)
live.events:RunScript("OnEvent", "UNIT_ABSORB_AMOUNT_CHANGED", token)
live.events:RunScript("OnEvent", "UNIT_HEAL_ABSORB_AMOUNT_CHANGED", token)
nextFrame()
assert(live.heal:GetValue() == 16 and live.absorb:GetValue() == 31)
assert(reads.prediction == 1 and reads.incoming == 1 and reads.absorb == 1 and not reads.health and not reads.max)
live.calc, env.UnitGetDetailedHealPrediction = fallbackCalc, nil
reads = {}
live.events:RunScript("OnEvent", "UNIT_ABSORB_AMOUNT_CHANGED", token)
nextFrame()
assert(reads.incoming == 1 and reads.absorb == 1, "a change back to raw predictions refreshes both overlays")

-- The client can clamp the two predictions against one another. Only an affected bar needs
-- another read and write. Exercise the real construction and update paths with each public mode.
do
    local damageModes = { MissingHealth = 0, MissingHealthWithoutIncomingHeals = 1, MaximumHealth = 2 }
    local maximumModes = { Default = 0, WithAbsorbs = 1 }
    local oldFactory = env.CreateUnitHealPredictionCalculator
    local oldDamageModes, oldMaximumModes = env.Enum.UnitDamageAbsorbClampMode, env.Enum.UnitMaximumHealthMode
    local oldHeals, oldAbsorbs = env.UnitGetIncomingHeals, env.UnitGetTotalAbsorbs
    local incoming, shield, calculated
    env.UnitGetIncomingHeals = counted("rawHeal", function() return incoming end)
    env.UnitGetTotalAbsorbs = counted("rawShield", function() return shield end)
    env.UnitGetDetailedHealPrediction = counted("prediction", function() assert(calculated) end)

    local function checkModes(damageMode, maximumMode, exposeModes, readShieldOnHeal, readHealOnShield)
        incoming, shield, calculated = 0, 25, true
        local function missing()
            return 100 + (maximumMode == maximumModes.WithAbsorbs and shield or 0) - 70
        end
        local function predictedHeal() return math.min(incoming, missing()) end
        local function predictedShield()
            if damageMode == damageModes.MissingHealth then return math.min(shield, missing() - predictedHeal()) end
            if damageMode == damageModes.MissingHealthWithoutIncomingHeals then return math.min(shield, missing()) end
            return shield
        end
        env.Enum.UnitDamageAbsorbClampMode = exposeModes and damageModes or nil
        env.Enum.UnitMaximumHealthMode = exposeModes and maximumModes or nil
        env.CreateUnitHealPredictionCalculator = function()
            return {
                GetDamageAbsorbClampMode = counted("damageMode", function() return damageMode end),
                GetMaximumHealthMode = counted("maximumMode", function() return maximumMode end),
                GetIncomingHeals = counted("calcHeal", predictedHeal),
                GetDamageAbsorbs = counted("calcShield", predictedShield),
            }
        end
        reads = {}
        local part = plates.Build(env.UIParent, false)
        assert((reads.damageMode or 0) == (exposeModes and 1 or 0) and reads.damageMode == reads.maximumMode)
        part.unit = token
        part.events:SetScript("OnEvent", live.events:GetScript("OnEvent"))
        part.health:SetMinMaxValues(0, 100)
        part.heal.SetValue = counted("writeHeal", part.heal.SetValue)
        part.absorb.SetValue = counted("writeShield", part.absorb.SetValue)
        plates.UpdateHeals(part)

        local function check(event, wantHeal, wantShield)
            reads = {}
            part.events:RunScript("OnEvent", event, token)
            part.events:RunScript("OnEvent", event, token)
            nextFrame()
            assert(reads.prediction == 1 and not reads.damageMode and not reads.maximumMode)
            assert(reads.calcHeal == (calculated and wantHeal or nil) and reads.calcShield == (calculated and wantShield or nil))
            assert(reads.rawHeal == (not calculated and wantHeal or nil) and reads.rawShield == (not calculated and wantShield or nil))
            assert(reads.writeHeal == wantHeal and reads.writeShield == wantShield)
            assert(part.heal:GetValue() == (calculated and predictedHeal() or incoming))
            assert(part.absorb:GetValue() == (calculated and predictedShield() or shield))
        end
        incoming = 20
        check("UNIT_HEAL_PREDICTION", 1, readShieldOnHeal)    -- MissingHealth: the shield shrinks from 25 to 10.
        incoming = 60
        check("UNIT_HEAL_PREDICTION", 1, readShieldOnHeal)
        shield = 0
        check("UNIT_ABSORB_AMOUNT_CHANGED", readHealOnShield, 1)   -- WithAbsorbs: the heal falls from 55 to 30.
        shield = 25
        check("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", 1, 1)
        calculated = false
        check("UNIT_ABSORB_AMOUNT_CHANGED", 1, 1)   -- Detailed API failed: both bars switch to raw figures.
        check("UNIT_ABSORB_AMOUNT_CHANGED", nil, 1)
        check("UNIT_HEAL_PREDICTION", 1, nil)
        calculated = true
        check("UNIT_HEAL_PREDICTION", 1, 1)         -- The calculator recovers; restore both calculated figures.
    end
    checkModes(damageModes.MissingHealth, maximumModes.Default, true, 1, nil)
    checkModes(damageModes.MissingHealthWithoutIncomingHeals, maximumModes.Default, true, nil, nil)
    checkModes(damageModes.MaximumHealth, maximumModes.Default, true, nil, nil)
    checkModes(damageModes.MaximumHealth, maximumModes.WithAbsorbs, true, nil, 1)
    checkModes(damageModes.MissingHealth, maximumModes.WithAbsorbs, false, 1, 1)
    env.CreateUnitHealPredictionCalculator, env.UnitGetDetailedHealPrediction = oldFactory, nil
    env.UnitGetIncomingHeals, env.UnitGetTotalAbsorbs = oldHeals, oldAbsorbs
    env.Enum.UnitDamageAbsorbClampMode, env.Enum.UnitMaximumHealthMode = oldDamageModes, oldMaximumModes
end

-- Independent masks survive a global event in the same frame.
local secondToken = "nameplate2"
local secondPlate = env.CreateFrame("Frame", nil, env.UIParent)
secondPlate.unitToken = secondToken
secondPlate.UnitFrame = env.CreateFrame("Frame", nil, secondPlate)
units[secondToken] = { attack = true, friend = false, health = 30, max = 80, incoming = 0, absorb = 2, threat = 0 }
aliases[secondToken], native[2] = secondPlate, secondPlate
send("NAME_PLATE_UNIT_ADDED", secondToken)
local secondParts = assert(plates.PartsFor(secondPlate))
units[secondToken].health, units[secondToken].raid = 25, 4
testMob.absorb = 30
reads = {}
secondParts.events:RunScript("OnEvent", "UNIT_HEALTH", secondToken)
live.events:RunScript("OnEvent", "UNIT_ABSORB_AMOUNT_CHANGED", token)
send("RAID_TARGET_UPDATE")
nextFrame()
assert(reads.health == 1 and reads.absorb == 1 and reads.raid == 2 and not reads.incoming)
assert(secondParts.health:GetValue() == 25 and secondParts.raid.raid == 4 and live.absorb:GetValue() == 30)
assert(not plates.updateQueue.driver:IsShown(), "the shared driver sleeps after the last pending plate")
reads = {}
nextFrame()
assert(not next(reads) and not plates.updateQueue.driver:IsShown(), "an idle frame does no plate work")
send("NAME_PLATE_UNIT_REMOVED", secondToken)
units[secondToken], aliases[secondToken], native[2] = nil, nil, nil

aliases.target = gamePlate
send("PLAYER_TARGET_CHANGED")
nextFrame()
-- your own side changed (a duel, a PvP flag): every plate is checked once, a frame later
do
    local check, checked = plates.CheckSide, 0
    plates.CheckSide = function() checked = checked + 1 end
    plates.CheckSides()
    plates.CheckSides()
    assert(checked == 0)
    ui:flushTimers()
    local held = 0
    for _ in pairs(plates.HeldPlates()) do held = held + 1 end
    assert(held > 0 and checked == held, checked .. " of " .. held)
    plates.CheckSide = check
end
-- Target Scale grows over a moment (11-24), slowing down; a threat change and a plate just taken jump
do
    local glide = plates.Glide
    assert(live.targetTint:IsShown() and live.root:GetScale() == 1 and glide.driver:IsShown())
    glide.driver:RunScript("OnUpdate", 0.075)
    local half = live.root:GetScale()
    assert(half > 1.15 and half < 1.25, half)
    glide.driver:RunScript("OnUpdate", 0.1)
    assert(live.root:GetScale() == 1.25 and not glide.driver:IsShown() and not next(glide.plates))
    local shown = live.targetShown
    live.targetShown = false
    plates.ApplyScale(live)
    assert(glide.plates[live], "back to its size the same way")
    local threat = live.threatKey
    live.threatKey, live.targetShown = "test", shown
    plates.ApplyScale(live)
    assert(live.root:GetScale() == 1.25 and not glide.plates[live], "a threat change jumps")
    live.targetShown, live.scaleFresh = false, true
    plates.ApplyScale(live)
    assert(live.root:GetScale() ~= 1.25 and not glide.plates[live], "a plate just taken jumps")
    live.threatKey, live.targetShown, live.scaleFresh = threat, shown, true
    plates.ApplyScale(live)
end
assert(live.targetTint:IsShown() and live.root:GetScale() == 1.25)
aliases.target = env.CreateFrame("Frame", nil, env.UIParent)
send("PLAYER_TARGET_CHANGED")
nextFrame()
assert(not live.targetTint:IsShown() and live.root:GetAlpha() == 0.55)
aliases.mouseover = gamePlate
send("UPDATE_MOUSEOVER_UNIT")
nextFrame()
assert(live.highlight:IsShown() and live.root:GetAlpha() == 1)
aliases.mouseover = nil
send("UPDATE_MOUSEOVER_UNIT")
nextFrame()
assert(not live.highlight:IsShown() and live.root:GetAlpha() == 0.55)

-- Saved settings stay on the cold path even while live unit, group and target state changes.
do
    local function guardReads(saved, keys)
        local values = {}
        for _, key in ipairs(keys) do
            values[key] = assert(saved[key])
            saved[key] = nil
        end
        setmetatable(saved, { __index = function(_, key)
            assert(values[key] == nil, "live plate reread saved setting " .. key)
        end })
        return function()
            setmetatable(saved, nil)
            for key, value in pairs(values) do saved[key] = value end
        end
    end
    local restorePlate = guardReads(db, { "targetScale", "notTargetScale", "rangeAlpha", "nonTargetAlpha", "role", "palette", "customColors" })
    local restoreQuest = guardReads(db, { "questMarks" })
    local presetOf, presetValue = plates.PresetOf, plates.PresetValue
    local function resolveAgain() error("live plate resolved its preset again") end
    plates.PresetOf, plates.PresetValue = resolveAgain, resolveAgain
    local otherTarget = aliases.target
    aliases.target, testMob.inRange = gamePlate, false
    live.events:RunScript("OnEvent", "UNIT_HEALTH", token)
    live.events:RunScript("OnEvent", "UNIT_THREAT_LIST_UPDATE", token)
    send("GROUP_ROSTER_UPDATE")
    send("QUEST_LOG_UPDATE")
    send("PLAYER_TARGET_CHANGED")
    plates.RangeTick()
    nextFrame()
    plates.Glide.driver:RunScript("OnUpdate", 1)
    assert(live.root:GetScale() == 1.25 and live.holder:GetAlpha() == 0.35)
    aliases.target, testMob.inRange = otherTarget, true
    send("PLAYER_TARGET_CHANGED")
    plates.RangeTick()
    nextFrame()
    plates.Glide.driver:RunScript("OnUpdate", 1)
    assert(live.root:GetScale() == 0.88 and live.root:GetAlpha() == 0.55 and live.holder:GetAlpha() == 1)
    plates.PresetOf, plates.PresetValue = presetOf, presetValue
    restoreQuest()
    restorePlate()
end

-- Cast timing stays in the client-facing duration object, including when either
-- the interruptibility or targeting flag cannot be read by addon Lua.
local casting, channeling, blocked = true, false, false
local castName, castBarID, castIcon, castSpell = "Shadow Bolt", 10, 161, 686
local castGUID, channelBarID = "first", 11
local duration = { GetTotalDuration = function() return 3 end, GetElapsedDuration = function() return 1 end }
local remaining = { GetRemainingDuration = function() return 0.75 end }
env.UnitCastingInfo = counted("castInfo", function(unit)
    if casting then
        assert(unit == token)
        return castName, castName, castIcon, nil, nil, nil, castGUID, blocked, castSpell, castBarID
    end
end)
env.UnitChannelInfo = counted("channelInfo", function(unit)
    if channeling then
        assert(unit == token)
        return "Drain Soul", nil, 162, nil, nil, nil, blocked, 1120, nil, nil, channelBarID
    end
end)
env.UnitCastingDuration, env.UnitChannelDuration = function() return duration end, function() return duration end
env.C_Spell.IsSpellImportant = function(spell) return spell == 686 end
env.C_Spell.GetSpellCooldownDuration = function(spell) assert(spell == 2139); return remaining end
local targetName, targetClass, aimedAtPlayer = "Juniper", "DRUID", secret
env.PlayerIsSpellTarget = counted("aim", function() return (casting or channeling) and aimedAtPlayer end)
env.UnitSpellTargetName = counted("targetName", function() if casting or channeling then return targetName end end)
env.UnitSpellTargetClass = counted("targetClass", function() if casting or channeling then return targetClass end end)
local classColor = env.C_ClassColor.GetClassColor
env.C_ClassColor.GetClassColor = counted("classColor", function(class)
    if class == "DRUID" then return env.CreateColor(1, 0.5, 0.1, 1) end
    return classColor(class)
end)
local function checkCastTarget(name, red, green, blue, highlight)
    local r, g, b = live.cast.target:GetTextColor()
    assert(live.cast.target:IsShown() and live.cast.target:GetText() == name, "expected cast target " .. name)
    assert(r == red and g == green and b == blue, "expected class colour for " .. name)
    assert(live.cast.targeted:GetAlpha() == highlight, "expected targeting highlight for " .. name)
end
local makeColour = env.CreateColor
function env.CreateColor(...)
    local c = makeColour(...)
    function c:SetRGB(r, g, b) self.r, self.g, self.b = r, g, b end
    return c
end
local kick = ns.UnitFrames.KICK
kick.known[2139] = false
do
    local logError, tapDenied = ns.LogError, env.UnitIsTapDenied
    local errors = 0
    env.UnitIsTapDenied = function() error("injected colour failure") end
    ns.LogError = function(where, err)
        assert(where and err:find("injected colour failure", 1, true), tostring(err))
        errors = errors + 1
    end
    live.events:RunScript("OnEvent", "UNIT_THREAT_LIST_UPDATE", token)
    nextFrame()
    assert(errors == 1 and not live.cast:IsShown(), "a colour error alone must not paint a cast")

    live.events:RunScript("OnEvent", "UNIT_THREAT_LIST_UPDATE", token)
    reads = {}
    live.events:RunScript("OnEvent", "UNIT_SPELLCAST_START", token)
    nextFrame()
    assert(errors == 2 and live.cast:IsShown() and live.cast.Text:GetText() == "Shadow Bolt",
        "the queued cast paints in the same frame as the colour error")
    assert(reads.aim == 1 and reads.targetName == 1 and reads.targetClass == 1 and reads.classColor == 1,
        "one target sample for a normal start")
    assert(reads.castInfo == 2 and not reads.channelInfo, "one cast snapshot at START and one at paint")
    assert(not plates.updateQueue.driver:IsShown())
    ns.LogError, env.UnitIsTapDenied = logError, tapDenied
end
assert(live.cast:IsShown() and live.cast.Text:GetText() == "Shadow Bolt" and live.root:GetAlpha() == 1)
assert(live.cast.timerDuration == duration and live.cast.timerDirection == env.Enum.StatusBarTimerDirection.ElapsedTime)
assert(live.cast.kickClip:IsShown() and live.cast.kickWait:GetValue() == 0.75)
assert(live.cast.targeted.secretBoolean == secret and live.cast.target:GetText() == "Juniper")
blocked = secret
live.events:RunScript("OnEvent", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE", token)
nextFrame()
assert(live.cast.shield.secretBoolean == secret and live.cast:GetStatusBarTexture().secretColour == secret)
assert(live.cast.kickClip:GetAlpha() == 0)
casting, channeling, blocked = false, true, false
live.events:RunScript("OnEvent", "UNIT_SPELLCAST_CHANNEL_START", token)
nextFrame()
assert(live.cast.Text:GetText() == "Drain Soul" and live.cast.kickWait:GetReverseFill())
assert(live.cast.timerDirection == env.Enum.StatusBarTimerDirection.RemainingTime)
kick.known[2139] = true
live.events:RunScript("OnEvent", "UNIT_SPELLCAST_CHANNEL_UPDATE", token)
nextFrame()
assert(not live.cast.kickClip:IsShown())
channeling = false
env.C_Timer.NewTimer = env.C_Timer.NewTicker
live.events:RunScript("OnEvent", "UNIT_SPELLCAST_CHANNEL_STOP", token, "cast", 1120, "Player-1", 11)
nextFrame()
assert(live.cast.Text:GetText() == "Interrupted" and live.cast.flashing)
live.cast.flashTimer.callback()
assert(not live.cast:IsShown() and live.root:GetAlpha() == 0.55)

casting = true
targetName, targetClass, aimedAtPlayer = "Briar", "MAGE", false
live.events:RunScript("OnEvent", "UNIT_SPELLCAST_START", token, "first", 686, nil, 10)
targetName, targetClass, aimedAtPlayer = "Linden", "DRUID", true
live.events:RunScript("OnEvent", "UNIT_SPELLCAST_DELAYED", token, "first", 686, nil, 10)
nextFrame()
assert(live.cast.castBarID == 10)
checkCastTarget("Linden", 1, 0.5, 0.1, 1)
live.events:RunScript("OnEvent", "UNIT_SPELLCAST_INTERRUPTED", token, "first", 686, "Player-1", 10)
castName, castBarID, castIcon, castSpell, castGUID = "Frostbolt", 12, 164, 116, "second"
targetName, targetClass, aimedAtPlayer = "Rowan", "MAGE", false
live.events:RunScript("OnEvent", "UNIT_SPELLCAST_START", token, "second", 116, nil, 12)
nextFrame()
assert(live.cast:IsShown() and not live.cast.flashing and live.cast.Text:GetText() == "Frostbolt")
checkCastTarget("Rowan", 0.2, 0.4, 0.6, 0)
live.events:RunScript("OnEvent", "UNIT_SPELLCAST_INTERRUPTED", token, "first", 686, "Player-1", 10)
nextFrame()
assert(live.cast.castBarID == 12 and not live.cast.flashing, "a late interrupt belongs to the previous cast")
casting = false
live.events:RunScript("OnEvent", "UNIT_SPELLCAST_INTERRUPTED", token, "second", 116, "Player-1", 12)
live.events:RunScript("OnEvent", "UNIT_SPELLCAST_STOP", token, "second", 116, nil, 12)
nextFrame()
assert(live.cast.flashing and live.cast.Text:GetText() == "Interrupted", "an ordinary stop preserves the interrupt")
live.cast.flashTimer.callback()
assert(not live.cast:IsShown())
casting, castName, castBarID, castIcon, castSpell, castGUID = true, "Fireball", 13, 165, 133, "quick"
targetName, targetClass, aimedAtPlayer = "Hazel", "DRUID", secret
live.cast.targeted.secretBoolean = nil
live.events:RunScript("OnEvent", "UNIT_SPELLCAST_START", token, "quick", 133, nil, 13)
casting = false
live.events:RunScript("OnEvent", "UNIT_SPELLCAST_INTERRUPTED", token, "quick", 133, "Player-1", 13)
nextFrame()
assert(live.cast.flashing and live.cast.Icon:GetTexture() == 165, "a cast kicked before its first paint keeps its icon")
checkCastTarget("Hazel", 1, 0.5, 0.1, 1)
assert(live.cast.targeted.secretBoolean == secret and live.cast.targetedPulse:IsPlaying(),
    "the interrupted cast passes its secret targeting flag to the highlight")
live.cast.flashTimer.callback()

channeling, targetName, targetClass, aimedAtPlayer = true, "Aspen", "MAGE", true
live.events:RunScript("OnEvent", "UNIT_SPELLCAST_CHANNEL_START", token, "beam", 1120, nil, 11)
channeling = false
live.events:RunScript("OnEvent", "UNIT_SPELLCAST_CHANNEL_STOP", token, "beam", 1120, "Player-1", 11)
nextFrame()
assert(live.cast.flashing and live.cast.Text:GetText() == "Interrupted" and live.cast.Icon:GetTexture() == 162)
checkCastTarget("Aspen", 0.2, 0.4, 0.6, 1)
live.cast.flashTimer.callback()

-- The START payload can identify a cast before its bar ID is returned by the live query.
casting, castBarID, castGUID = true, nil, secret
reads = {}
live.events:RunScript("OnEvent", "UNIT_SPELLCAST_START", token, castGUID, castSpell, 27)
live.events:RunScript("OnEvent", "UNIT_SPELLCAST_STOP", token, castGUID, castSpell, 27)
castBarID = 27
nextFrame()
assert(live.cast:IsShown() and not live.cast.flashing and reads.targetName == 1,
    "a matching event bar ID reuses the START target while that cast is still reported")

-- A stopped cast and its successor can be the same spell and both lack a bar ID.
-- For normal casts, UnitCastingInfo result seven identifies the cast when readable.
casting, castBarID = true, nil
for _, hidden in ipairs({ false, true }) do
    local firstGUID = hidden and secret or "Fireball-A"
    castGUID = firstGUID
    targetName, targetClass, aimedAtPlayer = "Rowan", "MAGE", false
    reads = {}
    live.events:RunScript("OnEvent", "UNIT_SPELLCAST_START", token, firstGUID, castSpell)
    castGUID = hidden and secret or "Fireball-B"
    targetName, targetClass, aimedAtPlayer = "Hazel", "DRUID", true
    live.events:RunScript("OnEvent", "UNIT_SPELLCAST_STOP", token, firstGUID, castSpell)
    nextFrame()
    checkCastTarget("Hazel", 1, 0.5, 0.1, 1)
    assert(reads.castInfo == 2 and not reads.channelInfo)
    assert(reads.aim == 2 and reads.targetName == 2 and reads.targetClass == 2 and reads.classColor == 2,
        "one fresh target for the successor")
    live.events:RunScript("OnEvent", "UNIT_SPELLCAST_INTERRUPTED", token, firstGUID, castSpell, "Player-1")
    nextFrame()
    assert(live.cast:IsShown() and not live.cast.flashing and live.cast.Text:GetText() == castName,
        "an old interrupt cannot replace a live successor")
    if not hidden then
        live.events:RunScript("OnEvent", "UNIT_SPELLCAST_INTERRUPTED", token, castGUID, castSpell, "Player-1")
        nextFrame()
        assert(live.cast.flashing, "the successor's own interrupt matches its observed cast GUID")
        live.cast.flashTimer.callback()
    end
end

castGUID = "Fireball-C"
live.events:RunScript("OnEvent", "UNIT_SPELLCAST_START", token, castGUID, castSpell)
nextFrame()
reads = {}
live.events:RunScript("OnEvent", "UNIT_SPELLCAST_INTERRUPTED", token, castGUID, castSpell, "Player-1")
nextFrame()
assert(live.cast.flashing and live.cast.Text:GetText() == "Interrupted", "the live cast GUID confirms its own interrupt")
assert(reads.castInfo == 1 and not reads.channelInfo)
live.cast.flashTimer.callback()

-- UnitChannelInfo has no cast GUID. An unidentified live channel keeps its own target.
casting, channeling, channelBarID = false, true, nil
targetName, targetClass, aimedAtPlayer = "Hazel", "DRUID", true
live.events:RunScript("OnEvent", "UNIT_SPELLCAST_CHANNEL_START", token, "beam-A", 1120)
targetName, targetClass, aimedAtPlayer = "Rowan", "MAGE", false
live.events:RunScript("OnEvent", "UNIT_SPELLCAST_CHANNEL_STOP", token, "beam-A", 1120, "Player-1")
nextFrame()
assert(not live.cast.flashing and live.cast.Text:GetText() == "Drain Soul")
checkCastTarget("Rowan", 0.2, 0.4, 0.6, 0)
channeling, channelBarID = false, 11
live.events:RunScript("OnEvent", "UNIT_SPELLCAST_CHANNEL_STOP", token, "beam-B", 1120)
nextFrame()

plates.TypeSet("enemyNpc", "castTarget", false)
plates.TypeSet("enemyNpc", "castTargetedFlash", false)
reads, casting, castGUID = {}, true, "off-A"
live.events:RunScript("OnEvent", "UNIT_SPELLCAST_START", token, castGUID, castSpell)
castGUID = "off-B"
live.events:RunScript("OnEvent", "UNIT_SPELLCAST_STOP", token, "off-A", castSpell)
nextFrame()
assert(not reads.aim and not reads.targetName and not reads.targetClass and not reads.classColor,
    "disabled target options do not query the client")
assert(reads.castInfo == 2 and not reads.channelInfo)
assert(not live.cast.target:IsShown() and live.cast.targeted:GetAlpha() == 0 and not live.cast.targetedPulse:IsPlaying())
casting = false
live.events:RunScript("OnEvent", "UNIT_SPELLCAST_STOP", token)
nextFrame()
plates.TypeSet("enemyNpc", "castTarget", true)
plates.TypeSet("enemyNpc", "castTargetedFlash", true)

env.GetCVar = function() return "0" end
env.Enum.TooltipDataLineType = { QuestTitle = 1, QuestPlayer = 2, QuestObjective = 3 }
local questRelated, tooltipLine = true, { type = 3, leftText = "Spider fangs: 3/8" }
env.C_QuestLog.UnitIsRelatedToActiveQuest = function() return questRelated end
env.C_TooltipInfo = { GetUnit = counted("tooltip", function()
    return { lines = { { leftText = "Forest Spider" }, { type = 1, leftText = "Spider Slayer" }, tooltipLine } }
end) }
send("QUEST_LOG_UPDATE")
send("UNIT_QUEST_LOG_CHANGED")
ui:flushTimers()
nextFrame()
assert(live.quest:IsShown() and live.questText:IsShown() and live.questText:GetText() == "3/8")
-- Deliver a whole frame's worth of work through the live event handlers. Count the
-- queued reads separately from the spell snapshot taken when START is delivered.
do
    local previousTarget, previousMouseover = aliases.target, aliases.mouseover
    for _, repetitions in ipairs({ 1, 4 }) do
        casting = true
        aliases.target, aliases.mouseover = gamePlate, gamePlate
        reads = {}
        for _ = 1, repetitions do
            for _, event in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_HEAL_PREDICTION",
                "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_THREAT_LIST_UPDATE", "UNIT_NAME_UPDATE", "UNIT_LEVEL" }) do
                live.events:RunScript("OnEvent", event, token)
            end
            live.events:RunScript("OnEvent", "UNIT_SPELLCAST_START", token, castGUID, castSpell, castBarID)
            for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "RAID_TARGET_UPDATE",
                "QUEST_LOG_UPDATE", "GROUP_ROSTER_UPDATE", "UPDATE_SHAPESHIFT_FORM", "SPELLS_CHANGED" }) do
                send(event)
            end
        end
        assert(reads.castInfo == repetitions and not reads.health)
        reads = {}
        nextFrame()
        for _, key in ipairs({ "health", "max", "absorb", "incoming", "color", "castInfo", "raid", "tooltip" }) do
            assert(reads[key] == 1, "expected one queued " .. key .. " read, got " .. tostring(reads[key]))
        end
        assert(live.cast:IsShown() and live.targetTint:IsShown() and live.highlight:IsShown())
        assert(live.texts.right:GetText() == testMob.health .. " / " .. testMob.max)
        assert(live.questText:GetText() == "3/8" and not plates.updateQueue.driver:IsShown())

        casting = false
        aliases.target, aliases.mouseover = previousTarget, previousMouseover
        live.events:RunScript("OnEvent", "UNIT_SPELLCAST_STOP", token, castGUID, castSpell)
        send("PLAYER_TARGET_CHANGED")
        send("UPDATE_MOUSEOVER_UNIT")
        nextFrame()
    end
end
-- Two producers change side anchors in the same frame. Position the widgets
-- using the final threat box and quest visibility, including on the way back.
do
    local position, detail = plates.PlaceSides, env.UnitDetailedThreatSituation
    local targetBefore = aliases.target
    local layouts, repairing, percent = 0, false, 0
    plates.PlaceSides = function(part, ...)
        if repairing and part == live then layouts = layouts + 1 end
        return position(part, ...)
    end
    env.UnitDetailedThreatSituation = function(_, unit) return false, units[unit].threat, percent end
    local function change(visible)
        percent, questRelated = visible and 80 or 0, visible
        live.events:RunScript("OnEvent", "UNIT_THREAT_LIST_UPDATE", token)
        send("QUEST_LOG_UPDATE")
        nextFrame()
        assert(live.threatBox:IsShown() == visible and live.quest:IsShown() == visible)
        assert(live.questText:IsShown() == visible)
        local _, anchor = live.questText:GetPoint(1)
        assert(anchor == (visible and live.quest or live.rightOf), "quest progress must use its final anchor")
    end
    change(false)
    repairing = true
    change(true)
    assert(layouts == 1, "threat box and quest marker appeared together")
    change(true)
    aliases.target = gamePlate
    send("PLAYER_TARGET_CHANGED")
    nextFrame()
    assert(layouts == 1, "unchanged quest and showing anchored target arrows preserve positions")
    change(false)
    assert(layouts == 2, "threat box and quest marker disappeared together")
    repairing = false
    plates.PlaceSides, env.UnitDetailedThreatSituation, aliases.target = position, detail, targetBefore
    questRelated = true
    live.events:RunScript("OnEvent", "UNIT_THREAT_LIST_UPDATE", token)
    send("QUEST_LOG_UPDATE")
    send("PLAYER_TARGET_CHANGED")
    nextFrame()
end
do
    local profile = { nameplateEnabled = false }
    env.Questie = { db = { profile = profile } }
    reads = {}
    send("QUEST_LOG_UPDATE")
    send("UNIT_QUEST_LOG_CHANGED")
    profile.nameplateEnabled = true
    nextFrame()
    assert(not live.quest:IsShown() and not live.questText:IsShown(), "Questie took over before the queued repaint")
    assert(not reads.tooltip, "hiding FlareUI quest markers does not read the unit tooltip")
    profile.nameplateEnabled = false
    send("QUEST_LOG_UPDATE")
    nextFrame()
    assert(reads.tooltip == 1 and live.quest:IsShown() and live.questText:IsShown() and live.questText:GetText() == "3/8")
    env.Questie = nil
end
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
-- (Malkkav 11-27) the test draws sample auras, crowd control and defensives in place of the unit's own
do
    local tdb = plates.TypeDB(live.kind)
    local saved = { tdb.debuffs, tdb.buffs, tdb.cc, tdb.defensives }
    tdb.debuffs, tdb.buffs, tdb.cc, tdb.defensives = "all", "all", true, true
    live.testAuras = nil
    plates.TestTick()
    local shown = 0
    for _, icon in ipairs(live.sampleIcons or {}) do if icon:IsShown() then shown = shown + 1 end end
    assert(shown >= 4 and live.ccIcon and live.defIcon, "sample auras on the live plate: " .. shown)
    for _, entry in pairs(live.auras or {}) do assert(not entry.container:IsShown(), "the unit's own auras wait") end
    tdb.debuffs, tdb.buffs, tdb.cc, tdb.defensives = saved[1], saved[2], saved[3], saved[4]
end
ui.time = 22
plates.TestTick()
assert(not plates.testing and not live.cast:IsShown() and not live.questText:IsShown())
for _, icon in ipairs(live.sampleIcons or {}) do assert(not icon:IsShown(), "the sample auras go with the test") end

-- (11-23, Rex / saamor) PET THREAT: your pet holding the mob reads as another tank having it
local petThreat
env.UnitThreatSituation = function(who, unit)
    if who == "pet" then return petThreat end
    return units[unit].threat
end
units.pet = {}
testMob.threat, petThreat = 0, 3
assert(plates.PetHolds(token))
plates.UpdateColor(live)
assert(live.threatKey == "offtank", "damage: the pet holds it -> " .. tostring(live.threatKey))
testMob.threat = nil   -- (the pet pulled: you aren't on its threat list yet)
plates.UpdateColor(live)
assert(live.threatKey == "offtank", "not on the list yet -> " .. tostring(live.threatKey))
db.role = "tank"
plates:Refresh()
live = assert(plates.PartsFor(gamePlate))
plates.UpdateRole()
testMob.threat = 0
plates.UpdateColor(live)
assert(live.threatKey == "offtank", "tank: the pet holds it -> " .. tostring(live.threatKey))
petThreat = 1
assert(not plates.PetHolds(token))
plates.UpdateColor(live)
assert(live.threatKey == "lost", "tank: nobody of ours holds it -> " .. tostring(live.threatKey))
-- (11-25) a hunter's plates don't fade up close: no Wing Clip yet, or between it and the shots' reach
do
    local names = { "UnitClass", "C_Spell" }
    local old = {}
    for _, name in ipairs(names) do old[name] = env[name] end
    local close, answers = ns.HunterClose, { spell75 = false, spell2974 = false }
    local near = false
    ns.HunterClose = function() return near end
    env.UnitClass = function() return "Hunter", "HUNTER" end
    env.C_Spell = setmetatable({ GetSpellName = function(id) return "spell" .. id end,
        IsSpellInRange = function(name) return answers[name] end }, { __index = old.C_Spell })
    local ids = {}
    for id, name in pairs(plates.C.RANGE_NAMES) do ids[id] = name end
    wipe = wipe or function(t) for k in pairs(t) do t[k] = nil end end
    wipe(plates.C.RANGE_NAMES)
    local tdb, set = live.tdb, plates.SetRangeAlpha
    live.tdb = setmetatable({ rangeAlpha = 0.5 }, { __index = tdb })
    local alpha
    plates.SetRangeAlpha = function(_, a) alpha = a end
    local function at() alpha = nil plates.UpdateRange(live) return alpha end
    assert(at() == 0.5, "far")
    near = true
    assert(at() == 1, "in the gap")
    -- (dstro7 11-28) no Wing Clip yet (level 9): far still fades; up close the item check keeps it bright
    near, answers.spell2974 = false, nil
    assert(at() == 0.5, "no Wing Clip yet, far: fades")
    near = true
    assert(at() == 1, "no Wing Clip yet, close: bright")
    near = false
    answers.spell75 = true
    assert(at() == 1)
    plates.SetRangeAlpha, live.tdb, ns.HunterClose = set, tdb, close
    wipe(plates.C.RANGE_NAMES)
    for id, name in pairs(ids) do plates.C.RANGE_NAMES[id] = name end
    for _, name in ipairs(names) do env[name] = old[name] end
end
-- (11-25) Caster: by having mana at all where how much is hidden (dungeons), by how much where it isn't
do
    local names = { "UnitPowerType", "UnitPowerMax", "UnitHasPowerType", "UnitIsPlayer" }
    local old = {}
    for _, name in ipairs(names) do old[name] = env[name] end
    local kind, max, has = 0, 500, true
    env.UnitPowerType = function() return kind end
    env.UnitPowerMax = function() return max end
    env.UnitHasPowerType = function(_, power) return power == 0 and has end
    env.UnitIsPlayer = function() return false end
    local db = { colorCaster = true, mobTypesWhere = "everywhere" }
    local function caster() return plates.MobRGB(token, db) ~= nil end
    assert(caster())
    max = 0
    assert(not caster(), "no mana")
    max = secret
    assert(caster(), "hidden, but it has mana")
    has = false
    assert(not caster())
    has, kind = true, 1
    assert(not caster(), "rage")
    kind, env.UnitHasPowerType = 0, nil
    assert(not caster(), "nothing to ask")
    for _, name in ipairs(names) do env[name] = old[name] end
end
-- (11-25) Threat Percentage's colour by Role
local function ThreatTextRed(status, held)
    local colour, holds = env.GetThreatStatusColor, plates.OtherTankHolds
    env.GetThreatStatusColor = function(n) return n * 10, 0, 0 end
    plates.OtherTankHolds = function() return held or false end
    local red = plates.ThreatTextRGB(token, status)
    env.GetThreatStatusColor, plates.OtherTankHolds = colour, holds
    return red
end
local safeRed = plates.Color("holding")[1]
assert(ThreatTextRed(3) == safeRed and ThreatTextRed(2) == 20 and ThreatTextRed(1) == 30 and ThreatTextRed(0) == 30,
    "tank: holding green, losing orange, lost red")
assert(ThreatTextRed(0, true) == safeRed and ThreatTextRed(1, true) == safeRed, "another tank has it")
assert(ThreatTextRed(nil) == 1, "not readable: white")
units.pet, petThreat = nil, nil
db.role = "damage"
plates:Refresh()
plates.UpdateRole()
assert(ThreatTextRed(3) == 30 and ThreatTextRed(2) == 20 and ThreatTextRed(0) == safeRed, "damage: red when it's on you")
live = assert(plates.PartsFor(gamePlate))
plates.UpdateRole()

-- the threat box moves to the left when the level sits on the right; with no level, it stays right
plates.TypeSet("enemyNpc", "level", "box")
plates.TypeSet("enemyNpc", "levelSide", "right")
plates.Layout(live)
assert(live.levelAnchor and live.threatSide == "left", "level right -> box left, got " .. tostring(live.threatSide))
plates.TypeSet("enemyNpc", "level", "off")
plates.Layout(live)
assert(live.threatSide == "right", "no level -> box right, got " .. tostring(live.threatSide))
plates.TypeSet("enemyNpc", "levelSide", "left")
plates.TypeSet("enemyNpc", "level", "box")
plates.Layout(live)

-- (11-23) the cast bar's own look: FlareUI Dark and FlareUI Thin by default, None for no border
assert(plates.CastTexture({}) == "FlareUI Dark" and plates.CastTexture({ castTexture = "Custom" }) == "Custom")
assert(plates.CastBorder({ castHeight = 12 }) ~= nil, "a default border")
assert(plates.CastBorder({ castBorder = "None", castHeight = 12 }) == nil, "None: no border")
-- Show Titles: NPC types on, players and Minor off, unless set
assert(plates.TitlesOn({}, "enemyNpc") and plates.TitlesOn({}, "friendlyNpc"))
assert(not plates.TitlesOn({}, "friendlyPlayer") and not plates.TitlesOn({}, "minor"))
assert(plates.TitlesOn({ showTitles = true }, "minor") and not plates.TitlesOn({ showTitles = false }, "enemyNpc"))
-- a player's title: the PvP name less the name
local oldPvp, oldDisplay = env.UnitPVPName, ns.UnitDisplayName
env.UnitPVPName = function() return "Corporal Bob Smith" end
ns.UnitDisplayName = function() return "Bob Smith" end
assert(plates.PlayerTitle("nameplate9") == "Corporal", tostring(plates.PlayerTitle("nameplate9")))
env.UnitPVPName = function() return "Bob Smith the Patient" end
assert(plates.PlayerTitle("nameplate9") == "the Patient", tostring(plates.PlayerTitle("nameplate9")))
env.UnitPVPName = function() return "Bob Smith" end
assert(plates.PlayerTitle("nameplate9") == nil, "no title")
env.UnitPVPName, ns.UnitDisplayName = oldPvp, oldDisplay
-- Show Guild Name (11-24): players' Name Only plates, off by default, under the title when it shows
do
    local oldGuild, guild = env.GetGuildInfo, "Emerald Circle"
    env.GetGuildInfo = function() return guild end
    local p = { nameOnly = true, unit = "nameplate9", kind = "friendlyPlayer", sample = true,
                name = env.UIParent:CreateFontString(), npcTitle = env.UIParent:CreateFontString(), guildName = env.UIParent:CreateFontString() }
    p.npcTitle:Hide()
    local function shown(on)
        p.tdb = { showGuild = on }
        plates.UpdateGuild(p)
        return p.guildName:IsShown()
    end
    assert(not plates.TypeDB("friendlyPlayer").showGuild and not shown(nil) and not shown(false))
    assert(shown(true) and p.guildName:GetText() == "<Emerald Circle>" and select(2, p.guildName:GetPoint()) == p.name)
    p.npcTitle:Show()
    assert(shown(true) and select(2, p.guildName:GetPoint()) == p.npcTitle, "under the title")
    -- its own colour, clear of the warrior brown (0.78, 0.61, 0.43)
    do
        local r, g, b = p.guildName:GetTextColor()
        assert(r == 0.93 and g == 0.85 and b == 0.68)
    end
    guild = nil
    assert(not shown(true), "no guild")
    guild = "Secret Circle"
    local readable = env.canaccessvalue
    env.canaccessvalue = function(v) return v ~= "Secret Circle" and readable(v) end
    assert(not shown(true), "a secret guild is left out")
    env.canaccessvalue, guild = readable, "Emerald Circle"
    p.nameOnly = false
    assert(not shown(true), "a full plate never shows it")
    p.nameOnly, p.kind = true, "friendlyNpc"
    assert(not shown(true), "players only")
    env.GetGuildInfo = oldGuild
end
-- Copy From: every one of the type's settings, the other type left alone, later changes apart
do
    local before = plates.TypeDB("friendlyNpc").width
    plates.TypeSet("friendlyNpc", "width", 190)
    plates.TypeSet("friendlyNpc", "castIcon", true)
    plates.CopyType("minor", "friendlyNpc")
    assert(plates.PresetOf("minor") == "custom")
    for key in pairs(plates.C.TYPE_KEYS) do
        local source = plates.TypeDB("friendlyNpc")[key]   -- (nil: this test's profile has no default for it)
        assert(source == nil or plates.SameValue(plates.TypeDB("minor")[key], source), key)
    end
    plates.TypeSet("minor", "width", 80)
    assert(plates.TypeDB("friendlyNpc").width == 190 and plates.TypeDB("minor").width == 80)
    plates.CopyType("minor", "minor")
    assert(plates.TypeDB("minor").width == 80)
    plates.TypeSet("friendlyNpc", "width", before)
end
-- the mouseover border: lighter than the plate's own bronze, back after (target and threat colours get lighter too)
local savedThreat, savedTarget = live.threatRGB, live.targetShown
live.threatRGB, live.targetShown = nil, nil
live.borderDirty = true
plates.PaintBorder(live)
local restR = live.border:GetBackdropBorderColor()
aliases.mouseover = gamePlate
send("UPDATE_MOUSEOVER_UNIT")
nextFrame()
local hoverR = live.border:GetBackdropBorderColor()
assert(live.edgeFile == nil or hoverR > restR, "the plate under the mouse gets a lighter border")
live.threatRGB = { 0.5, 0, 0 }
live.borderDirty = true
plates.PaintBorder(live)
local threatR = live.border:GetBackdropBorderColor()
assert(threatR > 0.5, "a hovered threat colour is lighter too: " .. tostring(threatR))
aliases.mouseover = nil
send("UPDATE_MOUSEOVER_UNIT")
nextFrame()
live.threatRGB, live.targetShown = savedThreat, savedTarget
-- Mouseover Highlight: Border and Bar by default; Outer Glow on request; None lights nothing
assert(plates.HoverParts().border and plates.HoverParts().bar and not plates.HoverParts().glow)
db.mouseoverHighlight = "glow"
aliases.mouseover = gamePlate
send("UPDATE_MOUSEOVER_UNIT")
nextFrame()
assert(not live.highlight:IsShown() and (live.targetGlow:IsShown() or live.targetShown), "Outer Glow only: no bar light, the glow shows")
aliases.mouseover = nil
send("UPDATE_MOUSEOVER_UNIT")
nextFrame()
db.mouseoverHighlight = "none"
aliases.mouseover = gamePlate
send("UPDATE_MOUSEOVER_UNIT")
nextFrame()
assert(not live.highlight:IsShown(), "None: no bar light")
aliases.mouseover = nil
send("UPDATE_MOUSEOVER_UNIT")
nextFrame()
db.mouseoverHighlight = nil

-- (11-23) DOESITDIE: an invisible bar named like "health" over ours on the game plate, hidden on release
env.DoesItDie = {}
plates.DieProxy(gamePlate, live)
local proxy = assert(gamePlate.FlareUI_DieHealth, "the proxy bar")
assert(proxy:IsShown() and proxy:GetParent() == gamePlate)
assert(proxy:GetReverseFill() == (live.health:GetReverseFill() and true or false))
plates.DieProxy(gamePlate, nil)
assert(not proxy:IsShown(), "hidden when we let the plate go")
env.DoesItDie = nil

-- Change a saved setting and switch profiles with a health event already pending.
-- Refresh must lay out the new display, including numeric slots that were previously unused.
local originalProfile = ns.db.profile
db.notTargetScale, db.nonTargetAlpha, db.rangeAlpha = 0.82, 0.62, 0.45
db.customColors.tapped = { 0.3, 0.2, 0.1 }
testMob.tapped, testMob.inRange = true, false
db.questMarks = false
questRelated, tooltipLine.leftText = true, "Spider fangs: 3/8"
do
    ui:load("Settings/Copy.lua", ns)
    ui:load("Settings/Registry.lua", ns)
    ui:load("Settings/Fonts.lua", ns)
    ui:load("Settings/Pages/Nameplates.lua", ns)
    local width, text = ns.Settings.rows["np.width"], ns.Settings.rows["np.barText"]
    local oldWidth, oldRootWidth = width:Get(), live.root:GetWidth()
    assert(live.root:IsShown() and text:Get() == "left=firstname;middle=;right=value,max")

    testMob.health = 32
    live.events:RunScript("OnEvent", "UNIT_HEALTH", token)
    nextFrame()
    assert(live.texts.right:GetText() == "32 / 200", "the existing plate uses the previous health slots")
    width:Set(170)
    live = assert(plates.PartsFor(gamePlate))
    assert(live.root:GetWidth() - oldRootWidth == 170 - oldWidth, "the settings row applies the width change to the existing nameplate")

    local resolveSlots, resolutions = plates.TextSlots, 0
    plates.TextSlots = function(...)
        resolutions = resolutions + 1
        return resolveSlots(...)
    end
    testMob.health = 44
    live.events:RunScript("OnEvent", "UNIT_HEALTH", token)
    text:Set("left=lost;middle=max;right=")
    live = assert(plates.PartsFor(gamePlate))
    nextFrame()
    assert(resolutions > 0 and live.root:IsShown(), "the settings row rebuilds slots for the displayed plate")
    assert(live.texts.left:GetText() == "-156" and live.texts.middle:GetText() == "200" and live.texts.right:GetText() == "",
        "a pending health event cannot restore the old text layout after the setting changes")

    resolutions, reads = 0, {}
    testMob.health, testMob.max = 60, 240
    live.events:RunScript("OnEvent", "UNIT_MAXHEALTH", token)
    live.events:RunScript("OnEvent", "UNIT_HEALTH", token)
    nextFrame()
    assert(live.texts.left:GetText() == "-180" and live.texts.middle:GetText() == "240" and live.texts.right:GetText() == "")
    assert(resolutions == 0 and reads.health == 1 and reads.max == 1,
        "queued health and maximum changes use the newly cached slots and one sample per value")
    plates.TextSlots = resolveSlots
    testMob.health, testMob.max = 10, 200
    width:Set(oldWidth)
end
live = assert(plates.PartsFor(gamePlate))
nextFrame()
assert(live.texts.left:GetText() == "-190" and live.texts.middle:GetText() == "200" and live.texts.right:GetText() == "")
assert(live.root:GetScale() == 0.82 and live.root:GetAlpha() == 0.62 and live.holder:GetAlpha() == 0.45)
local red, green, blue = live.health:GetStatusBarColor()
assert(red == 0.3 and green == 0.2 and blue == 0.1)
assert(not live.quest:IsShown() and live.questText:GetText() == "3/8")
live.events:RunScript("OnEvent", "UNIT_HEALTH", token)
ns.db.profile = setmetatable({ nameplates = { enabled = true, role = "damage",
    notTargetScale = 1.18, nonTargetAlpha = 0.77, rangeAlpha = 0.7,
    types = { enemy = { plate = "name", castbar = false } } } }, { __index = originalProfile })
profileEvent("OnProfileChanged")
live = assert(plates.PartsFor(gamePlate))
nextFrame()
assert(live.nameOnly and not live.health:IsShown() and not live.cast:IsShown())
-- its own font, with the Names font left to the other plates
do
    local kit, seen = ns.UnitFrames.Kit, {}
    local apply = kit.ApplyFont
    kit.ApplyFont = function(fs, font, delta) seen[fs] = { font, delta } return apply(fs, font, delta) end
    local tdb = live.tdb
    local own, names = { face = "A", size = 10 }, { face = "B", size = 20 }
    live.tdb = setmetatable({ nameOnlyFont = own, nameFont = names, nameOnlySize = 150 }, { __index = tdb })
    plates.Layout(live)
    assert(seen[live.name][1] == own and seen[live.name][2] == 5)
    live.tdb = setmetatable({ nameOnlyFont = own, nameFont = names, nameOnlySize = 100 }, { __index = tdb })
    plates.Layout(live)
    assert(seen[live.name][1] == own and seen[live.name][2] == nil)
    kit.ApplyFont, live.tdb = apply, tdb
    plates.Layout(live)
end
assert(live.root:GetScale() == 1.18 and live.root:GetAlpha() == 0.77 and live.holder:GetAlpha() == 0.7)
-- (11-25) Show Target's Plate: the whole plate while it's the target, in and out of a fight, the name alone after
do
    local function now() nextFrame() return assert(plates.PartsFor(gamePlate)) end
    local function target(on) aliases.target = on and gamePlate or nil send("PLAYER_TARGET_CHANGED") return now() end
    local was = aliases.target
    assert(not plates.AnyTargetFull() and target(true).nameOnly, "off to start")
    target(false)
    plates.TypeSet("enemyNpc", "nameOnlyTarget", true)
    profileEvent("OnProfileChanged")
    assert(plates.AnyTargetFull() and now().nameOnly, "not the target yet")
    local full = target(true)
    assert(not full.nameOnly and full.layFull and full.health:IsShown())
    ui.combat = true
    assert(target(false).nameOnly, "in a fight too")
    assert(not target(true).nameOnly)
    ui.combat = false
    assert(target(false).nameOnly)
    plates.TypeSet("enemyNpc", "nameOnlyTarget", nil)
    profileEvent("OnProfileChanged")
    aliases.target = was
    send("PLAYER_TARGET_CHANGED")
    live = now()
    assert(live.nameOnly and live.root:GetAlpha() == 0.77, tostring(live.root:GetAlpha()))
end
reads = {}
testMob.health = 13
live.events:RunScript("OnEvent", "UNIT_HEALTH", token)
live.events:RunScript("OnEvent", "UNIT_HEAL_PREDICTION", token)
nextFrame()
assert(live.health:GetValue() == 13 and reads.health == 1, "the public bar stays current in Name Only")
assert(not reads.missing and not reads.incoming and not reads.absorb, "hidden overlays and slots do no work in Name Only")

-- AceDB copy/reset may rewrite the same table. Combat defers the protected layout until regen.
ui.combat = true
ns.db.profile.nameplates.nonTargetAlpha = 0.81
profileEvent("OnProfileCopied")
assert(live.root:GetAlpha() == 0.77)
ui.combat = false
send("PLAYER_REGEN_ENABLED")
nextFrame()
live = assert(plates.PartsFor(gamePlate))
assert(live.root:GetAlpha() == 0.81)
ns.db.profile.nameplates.nonTargetAlpha = nil
profileEvent("OnProfileReset")
live = assert(plates.PartsFor(gamePlate))
assert(live.root:GetAlpha() == 1, "a reset forgets a removed shared option")
ns.db.profile = originalProfile
profileEvent("OnProfileChanged")
live = assert(plates.PartsFor(gamePlate))
nextFrame()
assert(not live.nameOnly and live.health:IsShown() and live.texts.middle:GetText() == "200")
assert(live.root:GetScale() == 0.82 and live.root:GetAlpha() == 0.62 and live.holder:GetAlpha() == 0.45)

-- The settings panel can redraw its open preview while a profile switch waits for combat to end.
do
    local function checkRGB(bar, expected, why)
        local r, g, b = bar:GetStatusBarColor()
        assert(r == expected[1] and g == expected[2] and b == expected[3], why)
    end
    local newColor = { 0.12, 0.71, 0.86 }
    local aggro, lost = { 0.98, 0.25, 0.12 }, { 0.75, 0.18, 0.85 }
    local assigned, previousRoleAPI = "DAMAGER", env.UnitGroupRolesAssigned
    env.UnitGroupRolesAssigned = function() return assigned end
    f:Show()
    plates.DrawSample(f, {})
    local panel, pinned = ns.SettingsPanel, ns.NameplatesPinned
    local previewState = {}
    ns.SettingsPanel = { IsShown = function() return f:IsVisible() end }
    ns.NameplatesPinned = { Draw = function() plates.DrawSample(f, previewState) end }
    local oldWidth = live.root:GetWidth()
    assert(p.root:IsVisible() and p.root:GetWidth() == oldWidth)
    ui.combat = true
    send("PLAYER_REGEN_DISABLED")
    ns.db.profile = setmetatable({ nameplates = {
        enabled = true, typesV3 = true, presetsV1 = true, role = "auto", types = { enemyNpc = { preset = "compact" } },
        palette = "custom", customColors = { hostile = newColor, tapped = newColor, aggro = aggro, lost = lost },
    } }, { __index = originalProfile })
    profileEvent("OnProfileChanged")
    local compactWidth = p.root:GetWidth()
    assert(compactWidth < oldWidth, "open preview uses the newly selected Compact preset in combat")
    checkRGB(p.health, newColor, "open preview uses the newly selected palette in combat")
    live.events:RunScript("OnEvent", "UNIT_THREAT_LIST_UPDATE", token)
    nextFrame()
    assert(plates.PartsFor(gamePlate) == live and live.root:GetWidth() == oldWidth)
    checkRGB(live.health, db.customColors.tapped, "preview repaint leaves the combat plate on its applied palette")
    previewState.threat = true
    ns.NameplatesPinned.Draw()
    checkRGB(p.health, aggro, "Auto previews the damage warning while the player is assigned damage")
    local beforeThreat = testMob.threat
    assigned, testMob.tapped, testMob.threat = "TANK", false, 3
    send("PLAYER_ROLES_ASSIGNED")
    nextFrame()
    checkRGB(p.health, lost, "Auto previews the tank warning after the player's role changes in combat")
    assert(live.threatKey == "aggro", "the live plate still uses its explicitly selected damage role")
    testMob.tapped, testMob.threat = true, beforeThreat

    -- AceDB can copy over the selected profile again while its first change is still deferred.
    local selected = ns.db.profile.nameplates
    local copiedColor = { 0.24, 0.84, 0.41 }
    selected.types.enemyNpc = { preset = "custom", custom = { width = p.tdb.width + 90, height = p.tdb.height } }
    selected.customColors = { hostile = copiedColor, tapped = copiedColor }
    previewState.threat = false
    profileEvent("OnProfileCopied")
    local copiedWidth = compactWidth + 90
    assert(p.root:GetWidth() == copiedWidth, "the open preview replaces the pending Compact layout with the copied width")
    checkRGB(p.health, copiedColor, "the open preview uses the most recently copied palette")
    live.events:RunScript("OnEvent", "UNIT_THREAT_LIST_UPDATE", token)
    nextFrame()
    assert(plates.PartsFor(gamePlate) == live and live.root:GetWidth() == oldWidth)
    checkRGB(live.health, db.customColors.tapped, "a second profile change keeps the original combat palette")
    local selectedSettings = p.tdb
    assert(selectedSettings ~= live.tdb, "the combat plate keeps its applied settings")
    ui.combat = false
    send("PLAYER_REGEN_ENABLED")
    nextFrame()
    live = assert(plates.PartsFor(gamePlate))
    assert(live.root:GetWidth() == copiedWidth, "combat end applies the last copied width to the live plate")
    assert(live.tdb == selectedSettings, "combat end reuses the settings already resolved for the selected profile")
    checkRGB(live.health, copiedColor, "combat end applies the last copied palette to the live plate")
    env.UnitGroupRolesAssigned = previousRoleAPI
    ns.SettingsPanel, ns.NameplatesPinned = panel, pinned
    ns.db.profile = originalProfile
    profileEvent("OnProfileChanged")
    live = assert(plates.PartsFor(gamePlate))
end

-- A nameplate token can refer to a new NPC on the same native frame before the next tick.
casting, castName, castBarID, castIcon, castSpell, castGUID = true, "Shadow Bolt", 31, 161, 686, "old mob"
targetName, targetClass, aimedAtPlayer = "Hazel", "DRUID", true
live.events:RunScript("OnEvent", "UNIT_SPELLCAST_START", token)
nextFrame()
assert(live.cast.castBarID == 31)
live.events:RunScript("OnEvent", "UNIT_SPELLCAST_INTERRUPTED", token, "old mob", 686, "Player-1", 31)
live.events:RunScript("OnEvent", "UNIT_HEALTH", token)
send("NAME_PLATE_UNIT_REMOVED", token)
assert(not plates.PartsFor(gamePlate) and gamePlate.FlareUIHealthBar == nil and gamePlate.UnitFrame:GetAlpha() == 1)
assert(gamePlate.UnitFrame.WidgetContainer:GetParent() == gamePlate.UnitFrame and simplified[token])
assert(gamePlate.UnitFrame:IsEventRegistered("UNIT_HEALTH") and not live.events:IsEventRegistered("UNIT_HEALTH"))
units[token] = { attack = true, friend = false, health = 47, max = 80, threat = 0, incoming = 0, absorb = 0 }
castName, castIcon, castSpell, castGUID = "Fireball", 165, 133, "new mob"
targetName, targetClass, aimedAtPlayer = "Willow", "MAGE", false
send("NAME_PLATE_UNIT_ADDED", token)
assert(plates.PartsFor(gamePlate) == live, "release returns the plate to the pool")
reads = {}
nextFrame()
assert(not reads.health and live.health:GetValue() == 47, "an old queued event cannot update the new owner")
assert(live.cast.Text:GetText() == "Fireball" and not live.cast.flashing, "interrupt metadata belongs to a single claim")
checkCastTarget("Willow", 0.2, 0.4, 0.6, 0)
-- (11-23, exillix3) Names Above Plate: its colour is this unit's, also with no name in the bar
do
    local slot, kind, only = live.nameSlot, live.aboveKind, live.nameOnly
    local set
    local oldSet = live.name.SetTextColor
    live.name.SetTextColor = function(self, ...) set = { ... } return oldSet(self, ...) end
    live.nameSlot, live.aboveKind, live.nameOnly = nil, "fullname", false
    plates.UpdateBarName(live)
    assert(set, "coloured")
    set = nil
    live.aboveKind = nil
    plates.UpdateBarName(live)
    assert(not set, "no name shown, nothing to do")
    live.name.SetTextColor = oldSet
    live.nameSlot, live.aboveKind, live.nameOnly = slot, kind, only
end
-- (11-23, Tride) Level: Follow Name goes in front of the name above the plate too
local above = { SetFormattedText = function(self, format, ...) self.text = format:format(...) end,
    SetText = function(self, text) self.text = text end, IsShown = function() return true end, SetTextColor = function() end }
local named = { aboveName = above, aboveKind = "fullname", unit = token, name = live.name, levelFollow = true }
plates.UpdateNameAbove(named)
assert(above.text:find("44", 1, true), "the level comes with the name: " .. tostring(above.text))
named.levelFollow = false
plates.UpdateNameAbove(named)
assert(not above.text:find("44", 1, true))
-- Colour Names by Class: lighter on a bar of the same colour, the plain class colour above the plate
do
    local tdb, slot, kind, only, player = live.tdb, live.nameSlot, live.aboveKind, live.nameOnly, units[token].player
    local set
    local oldSet, oldClass = live.name.SetTextColor, env.C_ClassColor.GetClassColor
    live.name.SetTextColor = function(_, ...) set = { ... } end
    env.C_ClassColor.GetClassColor = function() return { GetRGB = function() return 0.5, 0, 1 end } end
    units[token].player = true
    live.nameSlot, live.aboveKind, live.nameOnly = "left", "fullname", false
    live.tdb = setmetatable({ nameClassColor = true, healthColor = "class" }, { __index = tdb })
    plates.UpdateBarName(live)
    assert(set[1] > 0.5 and set[2] > 0.5 and set[2] < 1 and set[3] == 1 and live.aboveColor:GetRGB() == 0.5)
    live.tdb.healthColor = "reaction"
    plates.UpdateBarName(live)
    assert(set[1] == 0.5 and set[2] == 0 and live.aboveColor == nil, "a bar of another colour: the class colour itself")
    live.tdb.nameClassColor, live.tdb.healthColor = false, "class"
    plates.UpdateBarName(live)
    assert(set[1] == 1 and set[2] == 1)
    live.name.SetTextColor, env.C_ClassColor.GetClassColor = oldSet, oldClass
    units[token].player = player
    live.tdb, live.nameSlot, live.aboveKind, live.nameOnly = tdb, slot, kind, only
end
-- Questie's icon follows our frame, and goes back on the game's plate with it
do
    local icon = env.CreateFrame("Frame", nil, gamePlate)
    icon.Icon, icon.lastIcon = icon:CreateTexture(), "slay"
    icon:SetPoint("LEFT", gamePlate, "LEFT", -17, -7)
    local children = gamePlate.GetChildren
    gamePlate.GetChildren = function() return icon end
    plates.FixQuestie(live)
    assert(select(2, icon:GetPoint(1)) == gamePlate, "without Questie nothing moves")
    env.Questie = { db = { profile = { nameplateEnabled = true, nameplateX = -17, nameplateY = -7 } } }
    env._G = env._G or env
    env._G.Questie = env.Questie
    plates.FixQuestie(live)
    local _, relative, _, x = icon:GetPoint(icon:GetNumPoints())
    assert(relative == (live.leftOf or live.root) and x == -17 and live.questie == icon)
    -- past the level box, and past a raid marker on that side
    local leftOf, questSide = live.leftOf, live.questSide
    live.leftOf, live.questSide = live.box, "right"
    plates.FixQuestie(live)
    assert(select(2, icon:GetPoint(icon:GetNumPoints())) == live.box)
    local raidShown, only = live.raid:IsShown(), live.nameOnly
    live.raid:Show()
    live.nameOnly = false
    plates.FixQuestie(live)
    assert(select(2, icon:GetPoint(icon:GetNumPoints())) == live.raid)
    live.raid:SetShown(raidShown)
    live.leftOf, live.questSide, live.nameOnly = leftOf, questSide, only
    plates.ReturnQuestie(live)
    _, relative, _, x = icon:GetPoint(icon:GetNumPoints())
    assert(relative == gamePlate and x == -17 and live.questie == nil)
    env.Questie, env._G.Questie = nil, nil
    gamePlate.GetChildren = children
end
-- (11-24) a hidden bar colour is never compared: always painted, and told apart from a readable one
do
    local mt = { __eq = function() error("compared a secret") end }
    local function Hidden() return setmetatable({}, mt) end
    local access, painted, glow = env.canaccessvalue, {}, {}
    env.canaccessvalue = function(v) return not (type(v) == "table" and getmetatable(v) == mt) end
    local q = { health = { SetStatusBarColor = function(_, r) painted[#painted + 1] = r end }, targetGlow = { parts = {}, IsShown = function() return false end },
        levelGlow = { parts = {} }, threatGlow = { parts = {} }, discGlow = { parts = {} } }
    q.targetGlow.parts[1] = { SetVertexColor = function(_, r) glow[#glow + 1] = r end }
    plates.PaintGlow(q)
    assert(glow[1] == 1, "no colour yet: white")
    plates.BarColor(q, 0.1, 0.2, 0.3)
    plates.BarColor(q, 0.1, 0.2, 0.3)
    assert(#painted == 1)
    local a, b = Hidden(), Hidden()
    plates.BarColor(q, a, a, a)
    plates.BarColor(q, b, b, b)
    plates.BarColor(q, b, b, b)
    assert(#painted == 4)
    plates.PaintGlow(q)
    assert(rawequal(glow[2], b))
    plates.BarColor(q, 0.1, 0.2, 0.3)
    assert(#painted == 5)
    env.canaccessvalue = access
end
-- a tapped mob shows no threat look, nor the last unit's on the same plate
do
    testMob.tapped, testMob.threat = false, 3
    live.threatRGB, live.threatKey = { 1, 0, 0 }, "aggro"
    testMob.tapped = true
    plates.UpdateColor(live)
    assert(live.threatRGB == nil and live.threatKey == nil)
end
-- a dead mob's plate goes at once; a dead player's, or one whose state can't be read, stays
do
    local dead, player, isDead, isPlayer = false, false, env.UnitIsDead, env.UnitIsPlayer
    env.UnitIsDead = function() return dead end
    env.UnitIsPlayer = function() return player end
    plates.UpdateDead(live)
    assert(live.root:IsShown())
    dead = true
    plates.UpdateHealth(live)
    assert(not live.root:IsShown() and live.deadHidden)
    dead = false
    plates.UpdateHealth(live)
    assert(live.root:IsShown(), "alive again")
    dead, player = true, true
    plates.UpdateHealth(live)
    assert(live.root:IsShown())
    dead, player = secret, false
    plates.UpdateHealth(live)
    assert(live.root:IsShown())
    env.UnitIsDead, env.UnitIsPlayer = isDead, isPlayer
end
-- the debuff type icon (what you could dispel): not on an enemy's plate
do
    local look = ns.AuraLook
    ns.AuraLook = { ForUnit = function() return {} end }
    assert(plates.AuraLook(24, true, { kind = "enemyNpc" }).noTypeIcon and plates.AuraLook(24, true, { kind = "minor" }).noTypeIcon)
    assert(not plates.AuraLook(24, true, { kind = "friendlyPlayer" }).noTypeIcon)
    ns.AuraLook = look
end
-- Kick Ready: only on an enemy's cast
do
    local attack = env.UnitCanAttack
    assert(plates.Kickable(live))
    assert(not plates.Kickable({ kind = "friendlyPlayer", unit = token }))
    env.UnitCanAttack = function() return false end
    assert(not plates.Kickable({ kind = "minor", unit = token }), "a friend's pet")
    env.UnitCanAttack = function() return secret end
    assert(plates.Kickable({ kind = "minor", unit = token }), "not readable: as before")
    env.UnitCanAttack = attack
end
plates.StandDown()
assert(not plates.PartsFor(gamePlate) and not next(callbacks) and size[1] == 110 and size[2] == 17)
assert(cvars.nameplateSelectedScale == "1.3" and cvars.nameplateTargetRadialPosition == "0")
assert(cvars.nameplateMinAlpha == "0.6" and cvars.nameplateNotSelectedAlpha == "0.5", "and back as they were")
-- (11-26, Ric / bearae) Name Only + Show Target's Plate + Names Above Plate: the name above follows
-- this layout's target state, not the last one's (it went missing on the target, twice off it)
do
    local seen = {}
    local layAbove = plates.LayoutNameAbove
    plates.LayoutNameAbove = function(pp, db)
        seen[#seen + 1] = pp.layFull
        return layAbove(pp, db)
    end
    local full = false
    local showsFull = plates.ShowsFull
    plates.ShowsFull = function() return full end
    full = true
    pcall(plates.Layout, p)
    full = false
    pcall(plates.Layout, p)
    plates.ShowsFull, plates.LayoutNameAbove = showsFull, layAbove
    assert(seen[1] == true and seen[2] == false, "Names Above Plate reads this layout's state")
end
-- (11-26) the zoom backup: a setting saved per character is backed up per character, and one backed
-- up account-wide before moves to the character
do
    local tweaks = ns.Tweaks
    ns.Tweaks = { SavedPerCharacter = function(name) return name == "perChar" end }
    local global, char = { perChar = "0.8", shared = "1.2" }, {}
    assert(plates.ZoomBackupFor("perChar", global, char) == char and char.perChar == "0.8" and global.perChar == nil)
    assert(plates.ZoomBackupFor("shared", global, char) == global and global.shared == "1.2")
    ns.Tweaks = tweaks
end
-- (11-27) Show Whole Plate > When It Fights: a picked type shows its whole plate while the unit fights
do
    local db = ns.db.profile.nameplates
    local was, combat, fighting = db.fightingPlates, env.UnitAffectingCombat, true
    env.UnitAffectingCombat = function() return fighting end
    db.fightingPlates = "enemyNpc"
    pcall(plates.Refresh, plates)
    assert(plates.FightList().enemyNpc, "the picked type is in the list")
    assert(plates.FightFull("enemyNpc", { unit = "nameplate1" }), "a fighting unit of a picked type")
    assert(not plates.FightFull("enemyPlayer", { unit = "nameplate1" }), "a type not picked")
    assert(not plates.FightFull("enemyNpc", { unit = "nameplate1", sample = true }), "samples stay Name Only")
    fighting = false
    assert(not plates.FightFull("enemyNpc", { unit = "nameplate1" }), "out of its fight")
    db.fightingPlates, env.UnitAffectingCombat = was, combat
end

print("PASS: nameplates migrate presets, draw preview states and claim, update and release live plates")
