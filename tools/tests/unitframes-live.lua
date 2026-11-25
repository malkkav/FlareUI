local H = dofile("tools/tests/perf-helpers.lua")
local playerDb = {
    enabled = true, width = 220, height = 46, powerHeight = 12, showLevel = true,
    castbar = false, gcd = true, fsr = true, combatGlow = true, smoothBars = true,
    healthText = "valuemaxpct", nameAbove = "left:fullname", valuesOnHover = true,
    buffs = "TOPLEFT", debuffs = "OFF", onlyMyBuffs = true,
}
local targetDb = {
    enabled = true, width = 200, height = 42, powerHeight = 12, showLevel = true, castbar = true,
    mirror = true, showThreat = true, icons = { threatGlow = { shown = false } },
    buffs = "TOP", debuffs = "TOPLEFT", onlyMyDebuffs = true, hideBuffs = "PERMANENT", debuffAmount = 9,
}
local focusDb = { enabled = false, hideAuras = true }
local db = {
    styleStart = true, frameFontsSeeded = true, castTimeSeeded = true,
    visibility = { player = { condCombat = true, minAlpha = 15 } },
    party = { enabled = true, showPlayer = true, hidePlayerInParty = true },
    playerCastbar = { enabled = true, width = 240, height = 21, pushback = true },
    units = { player = playerDb, target = targetDb, focus = focusDb },
    layouts = { Modern = { player = { point = "CENTER", x = 100, y = 22 } } },
}
local ui, ns = dofile("tools/tests/fixtures/unitframes-ui.lua")(db)
local env = ui.env
ns.db.profile.visibility = { elements = {} }
local UF = ns.UnitFrames
local state = {
    player = { name = "Juniper", health = 95, power = 48, class = "MAGE", level = 43, player = true, online = true },
    target = { name = "Forest Spider", health = 92, power = 65, level = 41, online = true, hostile = true },
}
ns.defaults.profile.unitframes.units = { player = {}, target = {}, focus = {} }
local functions = {
    UnitExists = function(unit) return state[unit] ~= nil end,
    UnitIsVisible = function(unit) return not (state[unit] and state[unit].outOfSight) end,
    UnitIsPlayer = function(unit) return state[unit] and state[unit].player end,
    UnitIsConnected = function(unit) return state[unit] and state[unit].online end,
    UnitIsDeadOrGhost = function(unit) return state[unit] and state[unit].dead end,
    UnitIsDead = function(unit) return state[unit] and state[unit].dead end,
    UnitIsGhost = function(unit) return state[unit] and state[unit].ghost end,
    UnitHealth = function(unit) return state[unit].health end,
    UnitHealthMax = function() return 100 end,
    UnitPower = function(unit) return state[unit].power end,
    UnitPowerType = function() return 0, "MANA" end,
    UnitPowerMax = function() return 100 end,
    UnitPowerPercent = function(unit) return state[unit].power end,
    UnitHealthPercent = function(unit) return state[unit].health end,
    UnitHealthMissing = function(unit) return 100 - state[unit].health end,
    UnitCanAttack = function(_, unit) return state[unit] and state[unit].hostile end,
    UnitCanAssist = function(_, unit) return state[unit] and not state[unit].hostile and not state[unit].unflagged or false end,
    UnitIsTapDenied = function(unit) return state[unit] and state[unit].tapped end,
    UnitReaction = function() return 2 end,
    UnitIsUnit = function(a, b) return a == b end,
    UnitInParty = function() return false end,
    UnitInRaid = function() return false end,
    UnitClass = function(unit) return nil, state[unit] and state[unit].class end,
    UnitLevel = function(unit) return state[unit] and state[unit].level end,
    UnitClassification = function(unit) return state[unit] and state[unit].classification end,
    UnitThreatSituation = function(_, unit) return state[unit or "player"].threat end,
    UnitDetailedThreatSituation = function() return false, 1, 35 end,
    UnitAffectingCombat = function() return ui.combat end,
    UnitIsGroupLeader = function(unit) return unit == "player" end,
    UnitIsGroupAssistant = function() return false end,
    UnitIsPVPFreeForAll = function() return false end,
    UnitIsPVP = function(unit) return state[unit] and state[unit].pvp end,
    UnitFactionGroup = function() return "Alliance" end,
    UnitIsQuestBoss = function() return false end,
    UnitGetIncomingHeals = function() return 9 end,
    UnitGetTotalAbsorbs = function() return 12 end,
    UnitCastingInfo = function(unit)
        local cast = state[unit] and state[unit].casting
        if cast then return "Shadow Bolt", "Shadow Bolt", 21, 100000, 103000, false, "Cast-1", cast.noInterrupt, 686, 1 end
    end,
    UnitCastingDuration = function(unit) return state[unit].casting.duration end,
    UnitChannelInfo = function() end,
    GetRaidTargetIndex = function(unit) return state[unit] and state[unit].raid end,
    SetRaidTargetIconTexture = function(tex, raid) tex.raid = raid end,
    GetReadyCheckStatus = function(unit) return state[unit] and state[unit].ready end,
    IsResting = function() return state.player.resting end,
    RegisterStateDriver = function(frame, attr, driver) frame:SetAttribute(attr, driver) end,
    UnregisterStateDriver = function(frame, attr) frame:SetAttribute(attr, nil) end,
    tContains = function(values, want)
        for _, value in ipairs(values) do if value == want then return true end end
        return false
    end,
    securecallfunction = function(func, ...) return func(...) end,
}
for name, callback in pairs(functions) do env[name] = callback end
env.C_AddOns.DoesAddOnExist, env.C_AddOns.IsAddOnLoaded = function() return false end, function() return false end
env.C_DurationUtil = {
    CreateDurationTextBinding = function() end,
    CreateDuration = function()
        return { SetTimeFromStart = function(self, start, duration) self.start, self.duration = start, duration end }
    end,
}
env.C_Spell = { GetSpellPowerCost = function(id) return id == 10 and { { type = 0, cost = 8 } } or {} end,
    GetSpellCooldown = function() return state.gcd end,
    GetSpellSubtext = function() return "Rank 2" end,
}
env.C_ActionBar = { IsHighestSpellRank = function() return false end }
env.GetTimePreciseSec = env.GetTime
env.GetNetStats = function() return 0, 0, 95, 120 end
env.C_QuestLog = { UnitIsRelatedToActiveQuest = function() return false end }
env.Enum = {
    PowerType = { Mana = 0 },
    StatusBarInterpolation = { Immediate = 0 },
    StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 },
}
local function timer(_, callback)
    local entry = { callback = callback }
    function entry:Cancel() self.cancelled = true end
    ui.timers[#ui.timers + 1] = entry
    return entry
end
env.C_Timer.NewTimer = timer
function env.canaccessallvalues() return true end
local Widget = getmetatable(env.UIParent)
function Widget:SetTimerDuration(duration, interpolation, direction)
    self.timerDuration, self.timerInterpolation, self.timerDirection = duration, interpolation, direction
end
function Widget:SetResizeBounds(...) self.bounds = {...} end
function Widget:SetPropagateMouseClicks(on) self.propagateClicks = on end
function Widget:SetMouseClickEnabled(on) self.mouseClick = on end
function Widget:GetShadowOffset() return 1, -1 end
function Widget:GetShadowColor() return 0, 0, 0, 1 end

ns.SetBarValue = function(bar, value, glide) bar.testGlide = glide; bar:SetValue(value) end
ns.UnitShownLevel, ns.UnitLevelColor = env.UnitLevel, function() return { r = 1, g = 0.7, b = 0 } end
ns.UnitDisplayName = function(unit, _, full)
    return state[unit] and (unit == "player" and full and "Juniper Vale" or state[unit].name)
end
ns.OnEditFight = function(callback) ui.editFightCallback = callback end
ns.IsGamepadUI = function() return false end
ns.RawHide = function(frame) frame:Hide() end
ns.SetFont = ns.SetFontFamily
ns.GLOBAL_FONT = "_global"
ns.AuraSize = function(unit, debuff, fallback) return (debuff and unit.debuffSize or unit.buffSize) or unit.auraSize or fallback end
ns.EditPreviewing = function() return ui.editing == true end
env.L = ns.L
env.CopyTable = function(source)
    local result = {}
    for key, value in pairs(source) do result[key] = value end
    return result
end
ns.SetAuraDurationText = function(button, text) button:SetDurationText(text) end
dofile("tools/tests/fixtures/aura-containers.lua")(env)
for _, method in ipairs({ "SetReverse", "SetDrawSwipe", "SetUseCircularEdge", "SetEdgeTexture" }) do
    Widget[method] = function(self, value) self[method .. "Value"] = value end
end
ns.OrderEditSettings = function() end
local editMode = env.LibStub("FlareEditMode")
editMode.SettingType = { Slider = 1, Checkbox = 2, Dropdown = 3, Expander = 4 }
local settings, moves, callbacks = {}, {}, {}
function editMode:AddFrame(frame, moved) moves[frame] = moved end
function editMode:AddFrameSettings(frame, rows) settings[frame] = rows end
function editMode:AddSelectionArea() end
function editMode:GetActiveLayoutName() return "Modern" end
function editMode:RegisterCallback(event, callback) callbacks[event] = callback end
function editMode:Defer() return false end
local moduleEvents = {}
function UF:RegisterEvent(event) moduleEvents[event] = true end
function env.print(message) error(message, 0) end
env.PlayerFrame = env.CreateFrame("Frame", nil, env.UIParent)
env.TargetFrame = env.CreateFrame("Frame", nil, env.UIParent)
env.PlayerCastingBarFrame = env.CreateFrame("StatusBar", nil, env.UIParent)
env.PlayerBottomManagedFrameContainer = env.CreateFrame("Frame", nil, env.PlayerFrame)
targetDb.rangeCheck = false
ns.db.profile.auras = {}
ui:load("Modules/Auras.lua", ns)

UF:Init()
local player, target = UF:GetUnitButton("player"), UF:GetUnitButton("target")
assert(UF.initialized and moduleEvents.PLAYER_REGEN_ENABLED and not UF:GetUnitButton("focus"))
assert(not env.PlayerFrame:IsShown() and not env.TargetFrame:IsShown())
assert(player:GetParent() == UF:GetFadeFrame("player") and env.ClickCastFrames[target])
assert(player:GetAttribute("visibility"):find("group:party", 1, true) and target:GetAttribute("visibility"):find("@target", 1, true))
assert(player.Health:GetValue() == 95 and player.Power:GetValue() == 48 and player.HealBar:GetValue() == 9)
assert(player.AbsorbBar:GetValue() == 12 and player.NameAboveText:GetText() == "|cffffb30043|r Juniper Vale", "Show Level: before the name above too")
assert(player.Level:GetText() == "43", "and still in the bar")
assert(player.NameAboveText:IsShown() and player.HealthText:GetText() == "95 / 100")
assert(target.Health:GetReverseFill() and target.Name:GetText() == "Forest Spider")
assert(not db.visibility and ns.db.profile.visibility.elements.uf_player.minAlpha == 15)
assert(playerDb.healthText == "valuemax" and targetDb.threatGlow == false and not targetDb.icons.threatGlow)
assert(focusDb.buffs == "OFF" and focusDb.debuffs == "OFF" and focusDb.hideAuras == nil)
assert(select(2, env.PlayerBottomManagedFrameContainer:GetPoint()) == player)
assert(not env.PlayerCastingBarFrame:IsShown() and UF.GetPlayerCastHolder():IsShown())
local targetBuffs, targetDebuffs = target.Auras.TOP.container, target.Auras.TOPLEFT.container
local purge, normal = target.Auras.TOP.lanes.purge.key, target.Auras.TOP.lanes.buffs.key
local harm = target.Auras.TOPLEFT.lanes.debuffs.key
assert(targetBuffs:IsShown() and targetDebuffs:IsShown() and target.AuraStackStrip)
-- Center Spell Name: the name's two ends stand equally far from the bar's
do
    local cast = target.Cast
    cast.Text.SetJustifyH = function(self, h) self.centred = h == "CENTER" end
    local function ends()
        local _, _, _, left = cast.Text:GetPoint(1)
        local _, relative, _, right = cast.Text:GetPoint(2)
        return left, relative, right
    end
    local left, relative = ends()
    assert(not cast.Text.centred)
    targetDb.castCenter = true
    UF.Redraw(target)
    local l, rel, r = ends()
    assert(cast.Text.centred and rel == cast and l == -r and l > left)
    targetDb.castCenter = nil
    UF.Redraw(target)
    assert(not cast.Text.centred and select(2, ends()) == relative)
end
-- what is anchored to an aura container must be made with Blizzard's template for it, or its SetPoint errors
assert(target.AuraStackStrip.template == "DisableUntrustedLayoutScriptsTemplate")
do
    local AP, outer = ns.AuraPolicy, env.CreateFrame("Frame", nil, target)
    local strip = target.AuraStackStrip
    strip.SetPoint = function() error("Anchoring disallowed as dependent object would inherit forbidden aspects") end
    AP.HangPast(target, outer, targetBuffs, target, true, "LEFT", 3, 2)
    local point, relative, relativePoint, _, y = outer:GetPoint(1)
    assert(point == "BOTTOMLEFT" and relative == targetBuffs and relativePoint == "TOPLEFT" and y == 2, "refused: straight past the nearer one")
    strip.SetPoint = nil
end
assert(targetDebuffs.groups[harm].filter == "HARMFUL|PLAYER" and targetBuffs.groups[purge].enabled)
assert(targetBuffs.groups[normal].filter == "HELPFUL|!RAID_PLAYER_DISPELLABLE")
assert(targetBuffs.groups[normal].candidates.maxDuration == 999999)
state.target.hostile, state.target.outOfSight = false, true
target:RunScript("OnEvent", "UNIT_FACTION", "target")
UF.UpdateAuraReach(target)
assert(targetDebuffs.groups[harm].filter == "HARMFUL" and not targetBuffs.groups[purge].enabled)
assert(targetBuffs.groups[normal].filter == "HELPFUL" and not targetBuffs.groups[normal].candidates.maxDuration)
state.target.hostile, state.target.outOfSight = true, false
target:RunScript("OnEvent", "UNIT_FACTION", "target")
UF.UpdateAuraReach(target)
assert(targetBuffs.groups[purge].enabled and targetBuffs.groups[normal].candidates.maxDuration == 999999)
local aura = env.CreateFrame("Frame", nil, targetDebuffs)
targetDebuffs.groups[harm].opts.initializeFrame(aura)
assert(aura.auraIcon == aura.FlareUI_Icon and aura.duration == aura.FlareUI_Duration)
assert(ns.auraTipKind[aura] == "solo")

state.player.health = 50
player:RunScript("OnEvent", "UNIT_HEALTH", "player")
assert(player.Health:GetValue() == 50 and player.Health.testGlide and player.DamageTrail:GetValue() == 95)
ui.time = 101
UF.trailDriver:RunScript("OnUpdate", 1)
assert(player.DamageTrail:GetValue() == 50 and not UF.trailDriver:GetScript("OnUpdate"))
state.player.dead, state.player.health = true, 0
player:RunScript("OnEvent", "UNIT_HEALTH", "player")
assert(player.HealthText:GetText() == "Dead" and player.PowerText:GetText() == "" and not player.Health.testGlide)
state.player.dead, state.player.health, state.player.power = false, 90, 35
player:RunScript("OnEvent", "UNIT_HEALTH", "player")
assert(player.HealthText:GetText() == "90 / 100" and player.PowerText:GetText() == "35")
state.player.power = 31
player:RunScript("OnEvent", "UNIT_POWER_FREQUENT", "player", "ENERGY")
assert(player.Power:GetValue() == 35)
player:RunScript("OnEvent", "UNIT_POWER_FREQUENT", "player", "MANA")
assert(player.Power:GetValue() == 31)
state.player.power = 29
player:RunScript("OnEvent", "UNIT_POWER_UPDATE", "player", "MANA")
assert(player.Power:GetValue() == 31, "power work is deduplicated on the same frame")
ui.time = 102
player:RunScript("OnEvent", "UNIT_POWER_UPDATE", "player", "MANA")
assert(player.Power:GetValue() == 29)

state.gcd = { startTime = 102, duration = 1.5 }
UF.Gcd.events:RunScript("OnEvent", "SPELL_UPDATE_COOLDOWN")
assert(player.GcdSpark:IsShown())
ui.time = 102.75
player.GcdSpark:RunScript("OnUpdate", 0.75)
assert(select(4, player.GcdSpark.Spark:GetPoint()) == player.Power:GetWidth() / 2)
ui.time = 104
player.GcdSpark:RunScript("OnUpdate", 1.25)
assert(not player.GcdSpark:IsShown())
ui:emit("UNIT_SPELLCAST_SUCCEEDED", "player", "instant", 10)
assert(player.FsrSpark:IsShown())
ui.time = 106
player.FsrSpark:RunScript("OnUpdate", 2)
assert(select(4, player.FsrSpark.Spark:GetPoint()) == player.Power:GetWidth() * 0.4)
ui.time = 110
player.FsrSpark:RunScript("OnUpdate", 4)
assert(not player.FsrSpark:IsShown())

local width
for _, setting in ipairs(settings[player]) do if setting.name == "Width" then width = setting end end
assert(width and width.get() == 220)
ui.combat = true
width.set("Modern", 260)
assert(playerDb.width == 260 and player:GetWidth() == 220)
player:RunScript("OnEvent", "PLAYER_REGEN_DISABLED")
assert(player.Border.FlareUI_Pulse:IsPlaying())
ui.combat = false
UF:PLAYER_REGEN_ENABLED()
assert(player:GetWidth() == 260 and not player.Border.FlareUI_Pulse:IsPlaying())
moves[player](player, "Modern", "LEFT", 11.2, -24.7)
callbacks.layout("Modern")
local point, _, _, x, y = player:GetPoint()
assert(point == "LEFT" and x == 11 and y == -25)

do  -- the FlareUI Player Cast Bar's Width is what its border wraps, icon included
    local castDb, holder = ns.db.profile.unitframes.playerCastbar, UF.GetPlayerCastHolder()
    assert(castDb.width == 240 + 21 and holder:GetWidth() == castDb.width + 2 * 4, "a width saved without the icon takes it in, once")
    local castWidth
    for _, setting in ipairs(settings[holder]) do if setting.name == "Width" then castWidth = setting end end
    castWidth.set("Modern", 300)
    assert(castDb.width == 300 and holder:GetWidth() == 300 + 2 * 4 and holder:GetHeight() == 21 + 2 * 4)
    assert(select(4, holder.Cast:GetPoint(1)) == 21 + 4 and select(4, holder.Cast:GetPoint(2)) == -4, "the bar takes what the icon and border leave")
    local function converted(saved)
        UF.CastWidthWithIcon(saved)
        UF.CastWidthWithIcon(saved)
        return saved.width
    end
    -- (11-25) the box stays as it was for every bar, on the default too
    assert(converted({ width = 250, height = 25 }) == 275, "the old default saved: the icon taken in")
    assert(converted({ height = 25 }) == nil, "on the default: the new default is the same box")
    assert(converted({ height = 30 }) == 280, "default width, another height")
    assert(converted({ width = 300, height = 30 }) == 330, "once only")
    assert(converted({ width = 300, height = 30, icon = false }) == 300, "no icon: nothing to take in")
    assert(converted({ icon = false }) == 250, "no icon on the default: the old width, not the new default")
end

state.target.casting = { noInterrupt = false, duration = {} }
target:RunScript("OnEvent", "UNIT_SPELLCAST_START", "target", "Cast-1", 686)
assert(target.Cast:IsShown() and target.Cast.Text:GetText() == "Shadow Bolt")
assert(target.Cast.timerDuration == state.target.casting.duration and target.Cast.timerDirection == env.Enum.StatusBarTimerDirection.ElapsedTime)
state.target.casting.noInterrupt = true
target:RunScript("OnEvent", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "target")
local r, g, b = target.Cast:GetStatusBarColor()
assert(r == g and g == b, "uninterruptible cast is grey")
state.target.casting = nil
target:RunScript("OnEvent", "UNIT_SPELLCAST_INTERRUPTED", "target")
assert(target.Cast.flashing and target.Cast.Text:GetText() == "Interrupted")
target.Cast.flashTimer.callback()
assert(not target.Cast:IsShown())

-- Elite & Rare (11-24): gold border for an elite, silver for a rare, bronze for the rest; a glow keeps the
-- border and gives it back to the rank; off with the icon's switch.
do
    local border, rank = target.Border, UF.RANK_BORDER
    local function at(c) local r, g, b = border:GetBackdropBorderColor() return r == c.r and g == c.g and b == c.b end
    local function classify(kind)
        state.target.classification = kind
        target:RunScript("OnEvent", "UNIT_CLASSIFICATION_CHANGED", "target")
    end
    for kind, color in pairs({ elite = rank.elite, worldboss = rank.elite, rare = rank.rare, rareelite = rank.rare, normal = ns.BORDER_COLOR }) do
        classify(kind)
        assert(at(color), kind)
        assert(target.ClassIcon:IsShown() == (kind ~= "normal"), kind)
    end
    classify("elite")
    UF.SetBorderGlow(border, 1, 0, 0)
    assert(border.fuiGlow == true and at({ r = 1, g = 0, b = 0 }))
    classify("rare")
    assert(at({ r = 1, g = 0, b = 0 }), "the glow keeps the border")
    UF.SetBorderGlow(border)
    assert(at(rank.rare), "the border comes back to the rank")
    targetDb.icons.classification = { shown = false }
    classify("elite")
    assert(at(ns.BORDER_COLOR) and not target.ClassIcon:IsShown())
    targetDb.icons.classification = nil
    classify(nil)
    assert(at(ns.BORDER_COLOR) and player.Border.fuiRank == nil)
end

-- the name above sits over the ring and the elite dragon (11-24)
assert(player.NameAboveText:GetParent() == player.NameAboveHolder and player.NameAboveHolder:GetFrameLevel() == player:GetFrameLevel() + 6)
player.auraLift = 16
ns.NameAbove.Layout(player, playerDb, player, player.Name)
assert(player.NameAboveHolder:GetFrameLevel() == player:GetFrameLevel() + 16)
player.auraLift = nil
ns.NameAbove.Layout(player, playerDb, player, player.Name)

-- The level before the name above (11-24): the bar's + and R, a new level, Show Level off, the skull
do
    local above = player.NameAboveText
    local function level(event) player:RunScript("OnEvent", event or "UNIT_LEVEL", "player") return above:GetText() end
    state.player.level = 44
    assert(level() == "|cffffb30044|r Juniper Vale")
    for kind, mark in pairs({ elite = "+", rare = "R", rareelite = "R+" }) do
        state.player.classification = kind
        assert(level("UNIT_CLASSIFICATION_CHANGED") == "|cffffb30044" .. mark .. "|r Juniper Vale", kind)
    end
    state.player.classification = nil
    state.player.level = -1
    ns.HIGH_LEVEL_SKULL, ns.SetHighLevelText = "SKULL", function(fs) fs:SetText("SKULL") end
    assert(level() == "SKULL Juniper Vale")
    state.player.level, playerDb.showLevel = 43, false
    assert(level() == "Juniper Vale")
    playerDb.showLevel = true
    local readable = env.canaccessvalue
    local shownLevel = ns.UnitShownLevel
    ns.UnitShownLevel = function() return 51 end
    env.canaccessvalue = function(v) return v ~= 51 and readable(v) end
    assert(level() == "51 Juniper Vale", "a secret level goes to the text unread")
    env.canaccessvalue, ns.UnitShownLevel = readable, shownLevel
    assert(level() == "|cffffb30043|r Juniper Vale")
    -- the ring styles have the level in their disc
    local ring = ns.UFRing
    ns.UFRing = setmetatable({ Applies = function() return true end }, { __index = ring })
    UF.SetNameAbove(player)
    assert(above:GetText() == "Juniper Vale")
    ns.UFRing = ring
    UF.SetNameAbove(player)
end

-- (11-25) the PvP crest where the game hides the flag (battlegrounds): drawn by faction, the secret flag
-- sets its alpha; a readable flag works as before
do
    local icon = target.PvPIcon
    local function emit() target:RunScript("OnEvent", "UNIT_FACTION", "target") end
    state.target.pvp = true
    emit()
    assert(icon:IsShown() and icon:GetAlpha() == 1)
    local fed
    function icon:SetAlphaFromBoolean(value, on, off) fed = { value, on, off }; self:SetAlpha(0) end
    state.target.pvp = "hidden"
    emit()
    assert(icon:IsShown() and fed[1] == "hidden" and fed[2] == 1 and fed[3] == 0)
    state.target.pvp = true
    emit()
    assert(icon:IsShown() and icon:GetAlpha() == 1, "the secret's alpha doesn't stay")
    icon.SetAlphaFromBoolean = nil
    state.target.pvp = "hidden"
    emit()
    assert(not icon:IsShown(), "no way to show it unread: hidden")
    state.target.pvp = nil
    emit()
    assert(not icon:IsShown())
end

ui.editing = true
callbacks.enter()
assert(player:GetAttribute("visibility") == nil and targetDebuffs.editPreview)
local cast = UF.GetPlayerCastHolder().Cast
assert(cast:IsShown() and cast.Text:GetText() == "Sample Channel" and cast.LagZone:IsShown())
assert(cast.timerDirection == env.Enum.StatusBarTimerDirection.RemainingTime)
-- (11-25) Show Latency off: no red end
do
    local pc, zone = db.playerCastbar, cast.LagZone
    local function draw() UF.UpdatePlayerCastExtras(cast, "UNIT_SPELLCAST_START", false, nil, 1000, 4000, nil, 686) end
    draw()
    assert(zone:IsShown())
    pc.latency = false
    draw()
    assert(not zone:IsShown())
    pc.latency = nil
    draw()
    assert(zone:IsShown())
    local item = UF.LatencySetting(function() return true end, function() end)
    assert(item.name == "Show Latency" and item.default == true)
end
-- (11-25) Range Check never asks a "next swing" attack: those are in range at any distance
do
    local class, known = env.UnitClass, {}
    for name, lists in pairs(UF.RANGE_SPELLS) do
        for _, kind in ipairs({ "harm", "help", "melee" }) do
            for _, id in ipairs(lists[kind] or {}) do
                assert(id ~= 78 and id ~= 2973 and id ~= 6807, name)
            end
        end
    end
    local spell, spells, enum = env.C_Spell, env.C_SpellBook, env.Enum.SpellBookSpellBank
    env.Enum.SpellBookSpellBank = { Player = 0 }
    env.C_SpellBook = { GetNumSpellBookSkillLines = function() return 0 end }
    env.C_Spell = {}
    env.UnitClass = function() return "Hunter", "HUNTER" end
    env.C_Spell.GetSpellName = function(id) return "spell" .. id end
    env.C_SpellBook.IsSpellKnown = function(id) return known[id] == true end
    local function list(...)
        known = {}
        for _, id in ipairs({ ... }) do known[id] = true end
        UF.rangeKnown = nil
        return table.concat(UF.RangeKnown("harm"), ",")
    end
    assert(list(75) == "75,2973", "before Wing Clip: Raptor Strike, or the frame fades in melee")
    assert(list(75, 2974) == "75,2974")
    env.UnitClass, env.C_Spell, env.C_SpellBook, env.Enum.SpellBookSpellBank = class, spell, spells, enum
    UF.rangeKnown = nil
end
-- (11-25) Plumber's pet food button moves onto the happiness face shown
do
    local home, face = env.CreateFrame("Frame"), env.CreateFrame("Frame")
    home.GetChildren = function(self) return unpack(self.kids or {}) end
    local button = env.CreateFrame("Button", nil, home)
    button.enabled, button.GetFeedPetSpellName = true, function() end
    button.Attach = function(self) self:SetParent(home) end
    home.kids = { env.CreateFrame("Frame", nil, home), button }
    local loaded = env.C_AddOns.IsAddOnLoaded
    env.PetFrameHappiness = home
    UF.PlumberPetFood(face)
    assert(button:GetParent() == home, "without Plumber nothing moves")
    env.C_AddOns.IsAddOnLoaded = function(name) return name == "Plumber" end
    local combat = ui.combat
    ui.combat = true
    UF.PlumberPetFood(face)
    assert(button:GetParent() == home, "not in a fight")
    ui.combat = false
    UF.PlumberPetFood(face)
    assert(button:GetParent() == face and select(2, button:GetPoint(1)) == face)
    button:Attach()
    assert(button:GetParent() == face, "switched on again in Plumber")
    ui.combat, env.C_AddOns.IsAddOnLoaded, env.PetFrameHappiness = combat, loaded, nil
    UF.plumberFood, UF.plumberFace = nil, nil
end
local tick = ui.timers[#ui.timers].callback
tick()
assert(cast.Text:GetText() == "Sample Cast (R2)" and cast.Delay:GetText() == "+0.5")
assert(cast.Delay:IsShown() and cast.timerDirection == env.Enum.StatusBarTimerDirection.ElapsedTime)
do  -- a setting changed in Edit Mode redraws the running sample: it doesn't start the next one
    local started = cast.timerDuration.start
    ui.time = (ui.time or 100) + 1
    UF.RedrawPlayerCast()
    assert(cast.Text:GetText() == "Sample Cast (R2)" and cast.timerDuration.start == started)
end
assert(targetDebuffs.groups[harm].maxFrameCount == 4 and target.Auras.TOPLEFT.lanes["debuffs#fill2"])
ui.editing = false
callbacks.exit()
assert(not cast:IsShown() and not targetDebuffs.editPreview and targetDebuffs.groups[harm].maxFrameCount == 9)
-- (11-25, synx1z) a corner wraps at the frame's middle only while the edge's other corner is in use
do
    local buffs, debuffs = targetDb.buffs, targetDb.debuffs
    targetDb.buffs, targetDb.debuffs = "BOTTOMLEFT", "BOTTOMRIGHT"
    UF:Refresh()
    local function Value(corner)
        local v = target.Auras[corner].container.lineSize
        return type(v) == "table" and v[1] or v
    end
    local half = Value("BOTTOMLEFT")
    assert(half < target:GetWidth() / 2 and Value("BOTTOMRIGHT") == half, "both corners used: half each")
    targetDb.buffs = "TOPLEFT"
    UF:Refresh()
    assert(Value("BOTTOMRIGHT") > target:GetWidth() / 2, "alone on its edge: past the middle")
    assert(Value("TOPLEFT") > target:GetWidth() / 2)
    targetDb.buffs = "OFF"
    UF:Refresh()
    assert(Value("BOTTOMRIGHT") > target:GetWidth() / 2)
    -- Above the Frame: as many as Max Buffs says, on lines the frame's width long
    local amount, width = targetDb.buffAmount, targetDb.width
    local function Max()
        local entry = target.Auras.TOP
        return entry.container.groups[entry.lanes.buffs.key].maxFrameCount
    end
    targetDb.buffs, targetDb.debuffs, targetDb.buffAmount = "TOP", "BOTTOMRIGHT", 3
    UF:Refresh()
    local narrow = Value("TOP")
    assert(Max() == 3 and narrow > target:GetWidth() / 2, "Max Buffs, on the whole width")
    targetDb.width, targetDb.buffAmount = target:GetWidth() + 120, 12
    UF:Refresh()
    assert(Max() == 12 and Value("TOP") == narrow + 120, "a wider frame, a longer line")
    targetDb.buffAmount, targetDb.width = amount, width
    targetDb.buffs, targetDb.debuffs = buffs, debuffs
    UF:Refresh()
end
-- (11-23, Kelvan) Values on Mouseover keeps each text on a layer of its own bar: a hidden druid mana bar
-- (caster form) no longer hides the health numbers with it
do
    local frame = env.CreateFrame("Frame", nil, env.UIParent)
    local healthBar = env.CreateFrame("Frame", nil, frame)
    local manaBar = env.CreateFrame("Frame", nil, frame)
    local manaText, healthText = manaBar:CreateFontString(), healthBar:CreateFontString()
    UF.ValuesOnHover(frame, true, { manaText, healthText })
    assert(manaText:GetParent() ~= healthText:GetParent(), "one layer per bar")
    assert(healthText:GetParent():GetParent() == healthBar and manaText:GetParent():GetParent() == manaBar)
    manaBar:Hide()
    UF.SetValueLayersAlpha(frame, 1)
    assert(healthText:IsVisible() and not manaText:IsVisible(), "the health numbers stay with the mana bar hidden")
    UF.SetValueLayersAlpha(frame, 0)
    assert(healthText:GetParent():GetAlpha() == 0 and manaText:GetParent():GetAlpha() == 0, "off the frame: all hidden")
    UF.ValuesOnHover(frame, true, { manaText, healthText })
    assert(manaText:GetParent():GetParent() == manaBar, "a second pass keeps each text on its own bar")
    -- (11-23, betonlol) in group content a layer's alpha can't be read: it never is
    local sets = 0
    local layer = healthText:GetParent()
    function layer:GetAlpha() error("secret number value") end
    function layer:SetAlpha(a) sets = sets + 1 self.alpha = a end
    UF.SetValueLayersAlpha(frame, 1)
    UF.SetValueLayersAlpha(frame, 1)
    assert(sets == 1 and layer.alpha == 1, "set once, not read back")
    UF.SetValueLayersAlpha(frame, 0)
    assert(sets == 2 and layer.alpha == 0)
end
-- (11-24, #180) pointing at a frame's auras counts as pointing at the frame
do
    local foci = env.GetMouseFoci
    local f = UF:GetUnitButton("player")
    local over = f.mouseOver
    f.mouseOver = false
    local container = env.CreateFrame("Frame", nil, f)
    local aura = env.CreateFrame("Button", nil, container)
    local on = {}
    env.GetMouseFoci = function() return on end
    assert(not UF:IsMouseOverUnit("player"))
    on = { aura }
    assert(UF:IsMouseOverUnit("player"))
    on = { env.CreateFrame("Frame", nil, env.UIParent) }
    assert(not UF:IsMouseOverUnit("player"))
    on = { { IsForbidden = function() return true end } }
    assert(not UF:IsMouseOverUnit("player"))
    env.GetMouseFoci, f.mouseOver = foci, over
end
-- (11-24) Kick Ready: the interrupt by its best known rank (its rank 1 no longer counts as known)
do
    local KICK = UF.KICK
    local book, spell, player, enum = env.C_SpellBook, env.C_Spell, ns.IsPlayerSpell, env.Enum.SpellBookSpellBank
    local names = { [1766] = "Kick", [1767] = "Kick", [2139] = "Counterspell" }
    local ranks = { [1766] = "Rank 1", [1767] = "Rank 2" }
    local items, cooling = { 1766, 1767 }, false
    env.Enum.SpellBookSpellBank = { Player = 0 }
    env.C_SpellBook = {
        GetNumSpellBookSkillLines = function() return 1 end,
        GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = #items } end,
        GetSpellBookItemInfo = function(i) return { spellID = items[i] } end,
        IsSpellKnown = function(id) return id == 1767 end,
    }
    ns.IsPlayerSpell = function() return true end
    env.C_Spell = setmetatable({
        GetSpellName = function(id) return names[id] end,
        GetSpellSubtext = function(id) return ranks[id] end,
        GetSpellCooldown = function(id) return { isActive = cooling and id == 1767, isOnGCD = false } end,
        GetSpellCooldownDuration = function() end,
    }, { __index = spell })
    KICK.Learn()
    assert(KICK.Active() == 1767 and KICK.IsReady() == true and KICK.known[1766] == nil)
    cooling = true
    KICK.Refresh(true)
    assert(KICK.Active() == 1767 and KICK.IsReady() == false)
    -- no book entry: known by its own ID, as before
    cooling, items = false, {}
    env.C_SpellBook.IsSpellKnown = function(id) return id == 2139 end
    KICK.Learn()
    assert(KICK.Active() == 2139 and KICK.IsReady() == true)
    -- a warrior: only the one the stance (and a shield) allows counts; low rage alone doesn't matter
    env.C_SpellBook.IsSpellKnown = function(id) return id == 6552 or id == 72 end
    local usable = { [6552] = false, [72] = true }
    local noRage = {}
    names[6552], names[72] = "Pummel", "Shield Bash"
    env.C_Spell = setmetatable({ IsSpellUsable = function(id) return usable[id], noRage[id] or false end }, { __index = env.C_Spell })
    KICK.Learn()
    assert(KICK.Active() == 72 and KICK.IsReady() == true, "Defensive Stance: Shield Bash")
    cooling = true
    KICK.known[72] = false
    assert(KICK.IsReady() == false, "Pummel is off cooldown but can't be pressed here")
    usable[6552], usable[72], noRage[6552] = false, false, true
    assert(KICK.IsReady() == true and KICK.Active() == 6552, "no rage for it yet")
    assert(KICK.events:IsEventRegistered("UPDATE_SHAPESHIFT_FORM"))
    cooling = false
    env.C_SpellBook.IsSpellKnown = function() return false end
    KICK.Learn()
    assert(KICK.Active() == nil and KICK.IsReady() == nil)
    env.C_SpellBook, env.C_Spell, ns.IsPlayerSpell, env.Enum.SpellBookSpellBank = book, spell, player, enum
end
print("PASS: unit frame startup, resource events, combat deferral and cast changes")
