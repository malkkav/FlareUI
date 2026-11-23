-- Raid headers, main tanks and Edit Mode samples use the real shared tile kit.
local ui, ns, unit, edit = dofile("tools/tests/fixtures/party-world.lua")
local E = ui.env
ui:installGroupHeaders()
ui.inRaid = true
ui:load("ProfileLayout.lua", ns)
local db = ns.db.profile.unitframes.raid
db.buffs, db.debuffs, db.dispels = "OFF", "OFF", "OFF"
db.spacing, db.groupSpacing, db.groupNumbers = 10, 16, true
db.mainTanks.enabled, db.mainTanks.tankTargets = true, "BOTTOM"
db.mainTanks.buffs, db.mainTanks.debuffs = "OFF", "OFF"
unit.raid1 = { name = "Ari", class = "WARRIOR", level = 60, health = 90, power = 30, role = "TANK", mark = 3 }
unit.raid2 = { name = "Yana", class = "PRIEST", level = 60, health = 80, power = 60, role = "HEALER" }
unit.raid1target = { name = "Sentinel", level = 60, health = 44, power = 0, hostile = true }
E.CompactRaidFrameContainer = E.CreateFrame("Frame", "CompactRaidFrameContainer", E.UIParent)
ui:load("Modules/RaidFrames.lua", ns)
local rf = ns.RaidFrames
local function option(holder, label)
    for _, row in ipairs(holder.settings) do if row.name == label then return row end end
    error("Missing setting " .. label)
end
assert(rf:ShouldLoad())
ui.combat = true
rf:Init()
assert(not rf.initialized and not E.FlareUI_Raid)
ui.combat = false
ui:emit("PLAYER_REGEN_ENABLED")
assert(rf.initialized and E.CompactRaidFrameContainer.FlareUI_Hidden and not E.CompactRaidFrameContainer:IsShown())

local holder, tanks = E.FlareUI_Raid, E.FlareUI_RaidTanks
local group1, group2 = E.FlareUI_RaidGroup1, E.FlareUI_RaidGroup2
assert(#group1 == 5 and #E.FlareUI_RaidGroup8 == 5 and #E.FlareUI_RaidTanksHeader == 4, "maximum raid and tank tiles are precreated")
assert(db.barSpacing and db.spacing == 10 + ns.UnitFrames.Kit.INSET * 2, "old frame gaps are migrated once")
assert(holder:GetAttribute("visibility"):find("%[group:raid%]"))
group1[1]:SetAttribute("unit", "raid1")
group1[1]:Show()
group2[1]:SetAttribute("unit", "raid2")
group2[1]:Show()
assert(group1[1].Name:GetText() == "Ari" and group2[1].Health:GetValue() == 80)
assert(E.ClickCastFrames[group1[1]] and group1[1]:GetAttribute("*type2") == "togglemenu")
assert(select(5, group1:GetPoint()) > select(5, group2:GetPoint()), "occupied groups stack in order")
assert(group1.Label:GetText() == "Group 1" and group1.Label:IsShown())
local tank = E.FlareUI_RaidTanksHeader[1]
tank:SetAttribute("unit", "raid1")
tank:Show()
rf:Refresh()
assert(E.ClickCastFrames[tank.TankTarget], "click-casting on a main tank's target")
assert(tank.TankTarget.unitWatched and tank.TankTarget:GetAttribute("unit") == "raid1target")
assert(tank.TankTarget.Name:GetText() == "Sentinel" and tank.TankTarget.Health:GetValue() == 44)
assert(select(3, tank.TankTarget:GetPoint()) == "BOTTOMLEFT")
option(tanks, "Tank Targets").set("Modern", "RIGHT")
assert(select(3, tank.TankTarget:GetPoint()) == "TOPRIGHT" and tank.TankTarget:GetHeight() == db.mainTanks.h)
option(tanks, "Target Frame Width").set("Modern", 135)
assert(tank.TankTarget:GetWidth() == 135)
option(tanks, "Target Frame Width").set("Modern", 0)
assert(tank.TankTarget:GetWidth() == db.mainTanks.w)
option(tanks, "Tank Targets").set("Modern", "OFF")
assert(not tank.TankTarget.unitWatched and not tank.TankTarget:IsShown())

option(holder, "Sort By").set("Modern", "ROLE")
assert(E.FlareUI_RaidAll:GetAttribute("groupBy") == "ASSIGNEDROLE" and not group1:IsShown())
option(holder, "Sort By").set("Modern", "CLASS")
assert(E.FlareUI_RaidAll:GetAttribute("groupBy") == "CLASS" and option(holder, "Group Numbers").hidden())
option(holder, "Groups").set("Modern", "COLUMNS")
assert(option(holder, "Growth").values()[2].text == "Right")
option(holder, "Growth").set("Modern", "UP")
assert(E.FlareUI_RaidAll:GetAttribute("columnAnchorPoint") == "RIGHT")
option(holder, "Sort By").set("Modern", "GROUP")
assert(not E.FlareUI_RaidAll:IsShown() and group1:IsShown())

holder.moved(holder, "Modern", "TOPLEFT", 19.6, -101.2)
tanks.moved(tanks, "Modern", "LEFT", 20, -10)
edit.callbacks.layout("Modern")
assert(select(4, holder:GetPoint()) == 20 and select(5, holder:GetPoint()) == -101)
assert(select(4, tanks:GetPoint()) == 20 and select(5, tanks:GetPoint()) == -10)

ui.editing = true
edit.callbacks.enter()
assert(not group1:IsShown() and holder.sampleLabels[1]:IsShown() and not holder.sampleLabels[6]:IsShown())
option(holder, "Sample Raid").set("Modern", "small")
assert(holder.sampleLabels[2]:IsShown() and not holder.sampleLabels[3]:IsShown())
option(tanks, "Tank Targets").set("Modern", "BOTTOM")
local sampleTarget = ui:find(function(frame) return frame:GetParent() == tanks and frame.SampleTarget and frame:IsVisible() end)
assert(sampleTarget and sampleTarget.SampleTarget:IsShown() and sampleTarget.SampleTarget.Name:GetText() == "Target")
ui.editing = false
edit.callbacks.exit()
assert(group1:IsShown() and not holder.sampleLabels[1]:IsShown() and not sampleTarget:IsShown())

ui.combat = true
option(holder, "Width").set("Modern", 115)
assert(group1[1]:GetWidth() ~= 115)
ui.combat = false
ui:emit("PLAYER_REGEN_ENABLED")
assert(group1[1]:GetWidth() == 115)
assert(db.spacing == 10 + ns.UnitFrames.Kit.INSET * 2, "later refreshes do not repeat migration")

print("PASS: raid lifecycle, headers, tank targets, Edit Mode and combat deferral")
