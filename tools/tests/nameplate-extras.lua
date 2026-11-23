-- Run from the repository root: luajit tools/tests/nameplate-extras.lua
-- NameplateExtras.lua, with Quality of Life off all the way through: the In Combat plates hold and give
-- back the game's switches, combo points sit on FlareUI's plates only, and Quality of Life's old saved
-- switches move into the module once.
local ui, ns, unit = dofile("tools/tests/fixtures/party-world.lua")
local env = ui.env
local tweaks, db = ns.db.profile.tweaks, {}
ns.db.profile.nameplates = db
ns.db.global = ns.db.global or {}
local callbacks = {}
ns.db.RegisterCallback = function(target, event, method) callbacks[event] = function() target[method](target) end end
tweaks.enabled = false
local held = {}
ns.Tweaks = { ForcedCVars = function() return held end }   -- (the module itself never started)
local cv = { nameplateShowEnemies = "1", nameplateShowFriendlyPlayers = "1", nameplateShowFriendlyNpcs = "0", nameplateShowFriendlyPlayerMinions = "1" }
env.GetCVar = function(key) return cv[key] end
env.GetCVarBool = function(key) return cv[key] == "1" end
env.SetCVar = function(key, value) cv[key] = tostring(value) end
local points, maximum, power = 3, 5, 3
unit.player.class = "ROGUE"
unit.nameplate1 = { name = "Wolf", level = 43, hostile = true }
unit.target = unit.nameplate1
env.GetComboPoints = function() return points end
env.Enum.PowerType.Energy, env.Enum.PowerType.ComboPoints = 3, 4
env.UnitPowerType = function() return power, "ENERGY" end
env.UnitPowerMax = function() return maximum end
local plate = env.CreateFrame("Frame", nil, env.UIParent)
env.C_NamePlate = {
    GetNamePlates = function() return { plate } end,
    GetNamePlateForUnit = function(token) if token == "target" then return plate end end,
}
local box, below = env.CreateFrame("Frame", nil, plate), env.CreateFrame("Frame", nil, plate)
local parts, allowed = { box = box, below = below }, true
local migrated = 0
ns.Nameplates = {
    PartsFor = function() return parts end,
    ComboAllowed = function() return allowed end,
    MigrateProfile = function() migrated = migrated + 1 end,
}
local NP = ns.Nameplates
ui:load("Modules/NameplateExtras.lua", ns)
local extras = assert(ns.modules.NameplateExtras)
local function picks() return NP.FriendlyPicks() end

-- IN COMBAT PLATES: off leaves the game's switches alone
extras:Init()
extras:Init()
assert(migrated == 1 and cv.nameplateShowEnemies == "1" and picks() == "101" and next(held) == nil)
ui:emit("PLAYER_REGEN_DISABLED")
ui:emit("PLAYER_REGEN_ENABLED")
assert(cv.nameplateShowEnemies == "1" and picks() == "101" and next(held) == nil, "off never touches them")
-- on: hidden out of a fight, the player's own picks back in one (the Nameplates module is off here)
db.enemyInCombat, db.friendlyInCombat = true, true
NP.ApplyCombatShow()
assert(cv.nameplateShowEnemies == "0" and picks() == "000" and NP.FriendlyHeld() == "101")
assert(NP.FriendlyIndex("NamePlateShowFriendlyNpcs") == 2 and NP.FriendlyIndex("other") == nil and NP.FriendlyIndex(5) == nil)
ui:emit("PLAYER_REGEN_DISABLED")
assert(cv.nameplateShowEnemies == "1" and picks() == "101")
ui.combat = true
db.enemyInCombat = false
NP.ApplyCombatShow()
assert(cv.nameplateShowEnemies == "1" and held.combatPlates == "1", "nothing changes in a fight")
db.enemyInCombat, ui.combat = true, false
ui:emit("PLAYER_REGEN_ENABLED")
assert(cv.nameplateShowEnemies == "0" and picks() == "000")
db.enemyInCombat, db.friendlyInCombat = false, false
callbacks.OnProfileChanged()
assert(cv.nameplateShowEnemies == "1" and picks() == "101" and next(held) == nil, "another choice gives both back")
-- nothing picked: friendly players; a leftover of the old one-character memory is dropped
for _, cvar in ipairs(NP.FRIENDLY_CVARS) do cv[cvar] = "0" end
held.combatFriendly = "1"
db.friendlyInCombat = true
NP.ApplyCombatShow()
assert(NP.FriendlyHeld() == "100")
db.friendlyInCombat = false
NP.ApplyCombatShow()
assert(picks() == "100")

-- COMBO POINTS: none before the module is ready or with the switch off
local function comboRow() return ui:find(function(f) return f:GetParent() == plate and type(f.gems) == "table" end) end
db.comboPoints = true
NP.ApplyCombo()
NP.ComboPlateChanged()
assert(not comboRow(), "Nameplates off: no points")
NP.ready = true
NP.ApplyCombo()
local row = assert(comboRow(), "FlareUI's plate gets its points with Quality of Life off")
assert(row:IsShown() and row.count == 5 and row.gems[1].gem.lit:GetValue() == 3)
assert(select(2, row:GetPoint()) == below)
points = 0
ui:emit("UNIT_POWER_FREQUENT", "player", "ENERGY")
assert(row:IsShown(), "energy updates do not refresh combo points")
ui:emit("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
assert(not row:IsShown(), "no points, no row")
points, maximum = 2, 3
ui:emit("PLAYER_TARGET_CHANGED")
assert(row:IsShown() and row.count == 3 and not row.gems[5]:IsShown())
unit.player.class, power = "DRUID", 0
ui:emit("UNIT_DISPLAYPOWER", "player")
assert(not row:IsShown())
power = 3
ui:emit("UNIT_DISPLAYPOWER", "player")
assert(row:IsShown(), "druids in cat form")
unit.player.class = "MAGE"
ui:emit("PLAYER_TARGET_CHANGED")
assert(not row:IsShown())
unit.player.class, allowed = "ROGUE", false
ui:emit("PLAYER_TARGET_CHANGED")
assert(not row:IsShown(), "the unit type's own Combo Points off")
allowed = true
ui:emit("PLAYER_TARGET_CHANGED")
assert(row:IsShown())
-- the plate goes back to Blizzard's, then is ours again
local ours = parts
parts = nil
NP.ComboPlateChanged()
assert(not row:IsShown(), "Blizzard's plates are left alone")
parts = ours
NP.ComboPlateChanged()
assert(row:IsShown())
db.comboPoints = false
NP.ApplyCombo()
ui:emit("PLAYER_TARGET_CHANGED")
assert(not row:IsShown(), "switched off live")
db.comboPoints = true
NP.ApplyCombo()
assert(row:IsShown())
NP.standDown = true
NP.ApplyCombo()
assert(not row:IsShown(), "another nameplate addon")
print("PASS: nameplate extras hold In Combat plates and draw combo points without Quality of Life")
