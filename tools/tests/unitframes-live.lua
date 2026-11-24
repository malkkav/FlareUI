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
H.loadSections("Core.lua", {
    {"ns.AuraOrder = {}", "-- The level the frames show"},
    {"function ns.CastGlowDefault(", "-- For a time Lua can read"},
    {"ns.auraTipKind =", "-- GameTooltip for FlareUI's own buttons."},
    {"ns.AuraGroups = {}", "-- \"Show Speed\" / \"Hide Speed\" choices"},
    {"function ns.EditSections()", "-- A spell the player knows."},
}, env)
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

ui.editing = true
callbacks.enter()
assert(player:GetAttribute("visibility") == nil and targetDebuffs.editPreview)
local cast = UF.GetPlayerCastHolder().Cast
assert(cast:IsShown() and cast.Text:GetText() == "Sample Channel" and cast.LagZone:IsShown())
assert(cast.timerDirection == env.Enum.StatusBarTimerDirection.RemainingTime)
local tick = ui.timers[#ui.timers].callback
tick()
assert(cast.Text:GetText() == "Sample Cast (R2)" and cast.Delay:GetText() == "+0.5")
assert(cast.Delay:IsShown() and cast.timerDirection == env.Enum.StatusBarTimerDirection.ElapsedTime)
assert(targetDebuffs.groups[harm].maxFrameCount == 4 and target.Auras.TOPLEFT.lanes["debuffs#fill2"])
ui.editing = false
callbacks.exit()
assert(not cast:IsShown() and not targetDebuffs.editPreview and targetDebuffs.groups[harm].maxFrameCount == 9)
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
print("PASS: unit frame startup, resource events, combat deferral and cast changes")
