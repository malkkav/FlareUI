local ui, ns, unit = dofile("tools/tests/fixtures/party-world.lua")
local env = ui.env
local db = ns.db.profile.tweaks
db.enabled, db.nameplateCombo, db.nameplateQuest = true, true, true
db.moveAnyFrame = false
local addon, points, maximum, power, related = nil, 3, 5, 3, true
local plate = env.CreateFrame("Frame", nil, env.UIParent)
plate.unitToken = "nameplate1"
local native = env.CreateFrame("Frame", nil, plate)
plate.UnitFrame, native.unit = native, plate.unitToken
native.HealthBarsContainer = env.CreateFrame("Frame", nil, native)
local health = env.CreateFrame("StatusBar", nil, native.HealthBarsContainer)
native.HealthBarsContainer.healthBar = health
native.CastBarsContainer = env.CreateFrame("Frame", nil, native)
native.PlayerLevelDiffFrame = env.CreateFrame("Frame", nil, native)
native.PlayerLevelDiffFrame:SetHeight(20)
native.name = native:CreateFontString()
native.UpdateAnchors = function() end
native.IsShowOnlyName = function(self) return self.nameOnly == true end
native.AurasFrame = env.CreateFrame("Frame", nil, native)
native.AurasFrame.CrowdControlListFrame = env.CreateFrame("Frame", nil, native.AurasFrame)
native.AurasFrame.LossOfControlFrame = env.CreateFrame("Frame", nil, native.AurasFrame)
unit.player.class = "ROGUE"
unit.nameplate1 = { name = "Wolf", level = 43, hostile = true }
unit.target = unit.nameplate1
env.C_NamePlate = {
    GetNamePlates = function() return { plate } end,
    GetNamePlateForUnit = function(token) if token == "target" or token == "nameplate1" then return plate end end,
}
env.C_AddOns.IsAddOnLoaded = function(name) return name == addon end
env.C_QuestLog = { UnitIsRelatedToActiveQuest = function(token) return token == plate.unitToken and related end }
env.GetComboPoints = function() return points end
env.Enum.PowerType.Energy, env.Enum.PowerType.ComboPoints = 3, 4
env.UnitPowerType = function() return power, "ENERGY" end
env.UnitPowerMax = function() return maximum end
env.GetCVar = function() return "0" end
env.GetCVarBool = function() return false end
env.SetCVar = function() end
env.C_CVar = { GetCVarInfo = function() return nil end }
env.EventUtil = { ContinueOnAddOnLoaded = function() end }
env.StaticPopup_Show = function() end
env.UnitEffectiveLevel = env.UnitLevel
env.GetUnitName = function(token) return unit[token].name end
env.GetQuestDifficultyColor = function() return { r = 1, g = 0.5, b = 0 } end
env.CompactUnitFrame_UpdateName = function(frame) frame.name:SetText(env.GetUnitName(frame.unit)) end

ui:load("Modules/TweaksCVars.lua", ns)
ui:load("Modules/Tweaks.lua", ns)
local tweaks = ns.Tweaks
tweaks:Init()
local row = assert(ui:find(function(f) return f:GetParent() == plate and type(f.gems) == "table" end))
local tag = assert(ui:find(function(f) return f:GetParent() == plate and f.icon and f.icon:GetAtlas() == "QuestNormal" end))
assert(row:IsShown() and row.count == 5 and row.gems[1].gem.lit:GetValue() == 3)
assert(select(2, row:GetPoint()) == native.CastBarsContainer)
local level = native.PlayerLevelDiffFrame
assert(tag:IsShown() and select(2, tag:GetPoint()) == level)
level:Hide()
assert(select(2, tag:GetPoint()) == health)
level:Show()
assert(select(2, tag:GetPoint()) == level)
related = false
ui:emit("QUEST_LOG_UPDATE")
ui:emit("QUEST_LOG_UPDATE")
ui:flushTimers()
assert(not tag:IsShown())
related = true
ui:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
assert(tag:IsShown())
ui:emit("NAME_PLATE_UNIT_REMOVED", "nameplate1")
assert(not tag:IsShown())
points = 0
ui:emit("UNIT_POWER_FREQUENT", "player", "ENERGY")
assert(row:IsShown(), "Energy updates do not refresh combo points")
ui:emit("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
assert(not row:IsShown())
points, maximum = 2, 3
ui:emit("PLAYER_TARGET_CHANGED")
assert(row:IsShown() and row.count == 3 and not row.gems[5]:IsShown())
unit.player.class, power = "DRUID", 0
ui:emit("UNIT_DISPLAYPOWER", "player")
assert(not row:IsShown())
power = 3
ui:emit("UNIT_DISPLAYPOWER", "player")
assert(row:IsShown())

db.nameplateHideLevel, db.nameplateLevelName = true, true
tweaks:Refresh()
assert(level:GetAlpha() == 0 and select(2, tag:GetPoint()) == health)
assert(native.name:GetText() == "|cffff7f0043|r Wolf")
assert(select(2, native.HealthBarsContainer:GetPoint()) == native.CastBarsContainer)
assert(select(2, native.AurasFrame.CrowdControlListFrame:GetPoint()) == native.HealthBarsContainer)
unit.nameplate1.level = -1
env.CompactUnitFrame_UpdateName(native)
assert(native.name:GetText() == "|cffff2020??|r Wolf")
db.nameplateHideNames = true
tweaks:Refresh()
assert(native.name:GetAlpha() == 0 and native.name:GetText() == "Wolf")
native.nameOnly = true
native:UpdateAnchors()
assert(native.name:GetAlpha() == 1, "Name-only native plates keep their name")

local sample = assert(tweaks.CreateSample(env.UIParent, "plate"))
db.nameplateHideNames = false
local width, height = tweaks.DrawSample(sample)
assert(width > 160 and height > 48 and sample.Combo:IsShown() and sample.Quest:IsShown())
assert(sample.Level:GetAlpha() == 0 and sample.Name:GetText():find("Duskbat", 1, true))
assert(select(2, sample.Quest:GetPoint()) == sample.CastSlot and not sample:IsMouseEnabled())

env.Questie = { db = { profile = { nameplateEnabled = true } } }
tweaks:Refresh()
assert(not tag:IsShown())
env.Questie = nil
addon = "Plater"
ui:emit("ADDON_LOADED", addon)
tweaks:Refresh()
assert(tweaks:GetNameplateAddon() == "Plater" and not tag:IsShown() and not row:IsShown())
tweaks.DrawSample(sample)
assert(not sample.Quest:IsShown() and not sample.Combo:IsShown() and sample.Level:GetAlpha() == 1)
print("PASS: Quality of Life nameplate decorations, range of display styles, and addon handoff")
