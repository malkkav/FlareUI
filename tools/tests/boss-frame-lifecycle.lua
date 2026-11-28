-- The boss frames use live unit watches and pack visible bosses into contiguous slots.
local ui, ns, unit, edit = dofile("tools/tests/fixtures/party-world.lua")
local E = ui.env
ui:installGroupHeaders()
ui:load("ProfileLayout.lua", ns)
local db = ns.db.profile.unitframes.boss
db.buffs, db.debuffs, db.portrait = "RIGHT", "LEFT", "model"
unit.boss1 = { name = "Dreadseer", level = -1, health = 80, power = 35, hostile = true, classification = "worldboss" }
unit.boss3 = { name = "Guardian", level = -1, health = 55, power = 60, hostile = true, mark = 3 }
local container = E.CreateFrame("Frame", "BossTargetFrameContainer", E.UIParent)
local blizzardBoss = E.CreateFrame("Frame", "Boss1TargetFrame", container)
ui:load("Modules/BossFrames.lua", ns)
local bf = ns.BossFrames
assert(bf:ShouldLoad())
ui.combat = true
bf:Init()
assert(not bf.initialized)
ui.combat = false
ui:emit("PLAYER_REGEN_ENABLED")
local holder, a, b, c = E.FlareUI_Boss, E.FlareUI_Boss1, E.FlareUI_Boss2, E.FlareUI_Boss3
local function option(label)
    for _, row in ipairs(holder.settings) do if row.name == label then return row end end
    error("Missing setting " .. label)
end
assert(bf.initialized and not container:IsShown() and not blizzardBoss:IsShown())
assert(db.buffs == "OFF" and db.debuffs == "LEFT" and bf.PreviewCtx.Settings().portrait == "3d", "old aura and portrait settings migrate")
assert(a:IsShown() and not b:IsShown() and c:IsShown() and a.unitWatched)
assert(a.Name:GetText() == "Dreadseer" and c.Health:GetValue() == 55 and E.ClickCastFrames[a])
assert(select(5, a:GetPoint()) - select(5, c:GetPoint()) == holder.Stacker:GetAttribute("step"),
    "visible bosses use adjacent slots even when boss2 does not exist")
ui.targetUnit = "boss3"
ui:emit("PLAYER_TARGET_CHANGED")
assert(c.TargetHighlight:GetAlpha() == 1 and a.TargetHighlight:GetAlpha() == 0)
unit.boss3.mark = 8
ui:emit("RAID_TARGET_UPDATE")
assert(c.RaidIcon.raidMark == 8 and c.RaidIcon:IsShown())
-- Elite & Rare (11-25): the winged dragon on a boss, on the tile's right end (the tiles are mirrored)
assert(a.FUIDragon and a.FUIDragon.kind == "Boss" and a.FUIDragon.side == "RIGHT" and not a.ClassIcon:IsShown())
assert(not (c.FUIDragon and c.FUIDragon.kind), "a normal unit: no dragon")

local oldHeight = holder:GetHeight()
option("Cast Bar").set("Modern", false)
assert(holder:GetHeight() < oldHeight, "cast bar space is removed immediately")
option("Growth").set("Modern", "UP")
assert(select(5, c:GetPoint()) > select(5, a:GetPoint()), "growth up places the second active boss above the first")
holder.moved(holder, "Modern", "BOTTOMRIGHT", -110.7, 181.5)
edit.callbacks.layout("Modern")
assert(select(4, holder:GetPoint()) == -111 and select(5, holder:GetPoint()) == 182)

ui.editing = true
edit.callbacks.enter()
assert(not a.unitWatched and b:IsShown() and b.Name:GetText() == "Ragnaros")
assert(b.FUIDragon and b.FUIDragon.kind == "Boss", "the sample bosses show the dragon in Edit Mode")
ui.editing = false
edit.callbacks.exit()
assert(a.unitWatched and not b:IsShown() and a.Name:GetText() == "Dreadseer")

ui.combat = true
option("Width").set("Modern", 185)
assert(holder:GetWidth() ~= 185, "a frame size is deferred during combat")
unit.boss1 = nil
a:Hide()
holder.Stacker:SetAttribute("state-boss1", "0")
assert(select(5, c:GetPoint()) < select(5, b:GetPoint()), "the stacker moves the remaining live slot")
ui.combat = false
ui:emit("PLAYER_REGEN_ENABLED")
assert(holder:GetWidth() == 185)

unit.boss3.health = 38
ui:emit("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
assert(c.Health:GetValue() == 38)
unit.boss3.name, unit.boss3.guid, unit.boss3.health = "New Guardian", "Boss-GUID-4", 68
ui:flushTimers()
assert(c.Name:GetText() == "New Guardian" and c.Health:GetValue() == 68, "the next-frame refresh tracks a slot reassignment")

print("PASS: boss frames watch units, stack slots and defer layout in combat")
