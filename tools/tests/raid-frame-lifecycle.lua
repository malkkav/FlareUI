-- Raid headers, main tanks and Edit Mode samples use the real shared tile kit.
local ui, ns, unit, edit = assert(loadfile("tools/tests/fixtures/party-world.lua"))(true)
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
-- Blizzard's frames inside the holder, a main tank's target, another holder's, and a nameplate's
local function compact(name, parent)
    local frame = E.CreateFrame("Button", name, parent)
    frame.IsForbidden = function() return false end
    frame:RegisterEvent("UNIT_AURA")
    return frame
end
local nativeGroup = compact("CompactRaidGroup1", E.CompactRaidFrameContainer)
local nativeMember = compact("CompactRaidGroup1Member1", nativeGroup)
local nativeTarget = compact("CompactRaidFrame1", E.CompactRaidFrameContainer)
nativeTarget.onUpdateFrame = E.CreateFrame("Frame")
nativeTarget.onUpdateFrame:SetScript("OnUpdate", function() end)
E.PartyFrame = E.CreateFrame("Frame", "PartyFrame", E.UIParent)
local partyHolder = E.CreateFrame("Frame", nil, E.PartyFrame)
local partyMember = compact("CompactPartyFrameMember1", partyHolder)
local plateFrame = compact(nil, E.CreateFrame("Frame", nil, E.UIParent))
local forbidden = { IsForbidden = function() return true end, UnregisterAllEvents = function() error("forbidden") end }
E.CompactUnitFrame_UpdateUnitEvents = function(frame) if frame.RegisterEvent then frame:RegisterEvent("UNIT_AURA") end end
E.CompactUnitFrame_SetUpdateAllOnUpdate = function(frame, on)
    frame.onUpdateFrame:SetScript("OnUpdate", on and function() end or nil)
end
E.CompactRaidGroup_InitializeForGroup = function(frame) frame:RegisterEvent("GROUP_ROSTER_UPDATE") end
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

-- (11-24) they hear nothing more, whenever Blizzard registers them again; nobody else's frames are touched
assert(not nativeGroup:IsEventRegistered("UNIT_AURA") and not nativeMember:IsEventRegistered("UNIT_AURA"))
assert(not nativeTarget.onUpdateFrame:GetScript("OnUpdate"))
E.CompactUnitFrame_UpdateUnitEvents(nativeMember)
E.CompactUnitFrame_SetUpdateAllOnUpdate(nativeTarget, true)
E.CompactUnitFrame_UpdateUnitEvents(nativeTarget)
assert(not nativeMember:IsEventRegistered("UNIT_AURA") and not nativeTarget:IsEventRegistered("UNIT_AURA")
    and not nativeTarget.onUpdateFrame:GetScript("OnUpdate"))
local lateGroup = compact("CompactRaidGroup2", E.CompactRaidFrameContainer)
E.CompactRaidGroup_InitializeForGroup(lateGroup)
assert(not lateGroup:IsEventRegistered("GROUP_ROSTER_UPDATE"))
E.CompactUnitFrame_UpdateUnitEvents(partyMember)
E.CompactUnitFrame_UpdateUnitEvents(plateFrame)
E.CompactUnitFrame_UpdateUnitEvents(forbidden)
assert(partyMember:IsEventRegistered("UNIT_AURA") and plateFrame:IsEventRegistered("UNIT_AURA"), "Blizzard's party frames still in use, and nameplates")
-- the party's holder parked later: its frames too, the classic ones with their bars
E.CompactPartyFrame = partyHolder
partyHolder.memberUnitFrames, partyHolder.petUnitFrames = { partyMember }, {}
local classic = compact(nil, E.PartyFrame)
classic.ManaBar = compact(nil, classic)
E.PartyFrame.PartyMemberFramePool = { EnumerateActive = function() return pairs({ [classic] = true }) end }
ns.UnitFrames.GroupQuiet.Park("PartyFrame")
assert(not partyMember:IsEventRegistered("UNIT_AURA") and not classic:IsEventRegistered("UNIT_AURA") and not classic.ManaBar:IsEventRegistered("UNIT_AURA"))
E.CompactUnitFrame_UpdateUnitEvents(partyMember)
E.CompactUnitFrame_UpdateUnitEvents(plateFrame)
assert(not partyMember:IsEventRegistered("UNIT_AURA") and plateFrame:IsEventRegistered("UNIT_AURA"))
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
-- (11-24) one column of five: a reload in a raid makes no tile more
assert(group1:GetAttribute("unitsPerColumn") == 5 and group1:GetAttribute("maxColumns") == 1)
-- somebody else behind the same unit, inside one burst of roster changes: drawn again
unit.raid3 = { name = "Pell", class = "MAGE", level = 60, health = 70, power = 10 }
ui:emit("GROUP_ROSTER_UPDATE")
group1[2]:SetAttribute("unit", "raid3")
group1[2]:Show()
assert(group1[2].Name:GetText() == "Pell" and group1[2].paintedGUID == "GUID-raid3")
unit.raid3.name, unit.raid3.guid = "Quill", "GUID-other"
ui:flushTimers()
assert(group1[2].Name:GetText() == "Quill")
-- a ready check's answer goes with its unit, and with the next check
unit.raid3.ready = "ready"
ui:emit("READY_CHECK")
assert(group1[2].lastReady == "ready")
unit.raid3.ready = nil
ui:emit("READY_CHECK")
assert(group1[2].lastReady == nil)
group1[2].lastReady = "ready"
group1[2]:SetAttribute("unit", nil)
assert(group1[2].lastReady == nil)
group1[2]:Hide()
unit.raid3 = nil
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

option(holder, "Group Order").set("Modern", "ROLE")
assert(E.FlareUI_RaidAll:GetAttribute("groupBy") == "ASSIGNEDROLE" and not group1:IsShown())
option(holder, "Group Order").set("Modern", "CLASS")
assert(E.FlareUI_RaidAll:GetAttribute("groupBy") == "CLASS" and option(holder, "Group Numbers").hidden())
option(holder, "Orientation").set("Modern", "COLUMNS")
assert(option(holder, "Growth").values()[2].text == "Right")
option(holder, "Growth").set("Modern", "UP")
assert(E.FlareUI_RaidAll:GetAttribute("columnAnchorPoint") == "RIGHT")
option(holder, "Group Order").set("Modern", "GROUP")
assert(not E.FlareUI_RaidAll:IsShown() and group1:IsShown())

holder.moved(holder, "Modern", "TOPLEFT", 19.6, -101.2)
tanks.moved(tanks, "Modern", "LEFT", 20, -10)
edit.callbacks.layout("Modern")
assert(select(4, holder:GetPoint()) == 20 and select(5, holder:GetPoint()) == -101)
assert(select(4, tanks:GetPoint()) == 20 and select(5, tanks:GetPoint()) == -10)

-- (Edit Mode: only the party goes a strata up, and only when that changes)
local partyFrame, stacks = E.CreateFrame("Frame", "FlareUI_Party", E.UIParent), 0
local setStrata = partyFrame.SetFrameStrata
function partyFrame:SetFrameStrata(value) stacks = stacks + 1; setStrata(self, value) end
ui.editing = true
edit.callbacks.enter()
assert(partyFrame:GetFrameStrata() == "MEDIUM" and stacks == 1)
edit.callbacks.enter()
assert(stacks == 1 and holder:GetFrameStrata() == "LOW")
assert(not group1:IsShown() and holder.sampleLabels[1]:IsShown() and not holder.sampleLabels[6]:IsShown())
option(holder, "Raid Size").set("Modern", "small")
assert(holder.sampleLabels[2]:IsShown() and not holder.sampleLabels[3]:IsShown())
option(tanks, "Tank Targets").set("Modern", "BOTTOM")
local sampleTarget = ui:find(function(frame) return frame:GetParent() == tanks and frame.SampleTarget and frame:IsVisible() end)
assert(sampleTarget and sampleTarget.SampleTarget:IsShown() and sampleTarget.SampleTarget.Name:GetText() == "Target")
ui.editing = false
edit.callbacks.exit()
assert(partyFrame:GetFrameStrata() == "LOW")
assert(group1:IsShown() and not holder.sampleLabels[1]:IsShown() and not sampleTarget:IsShown())

ui.combat = true
option(holder, "Width").set("Modern", 115)
assert(group1[1]:GetWidth() ~= 115)
ui.combat = false
ui:emit("PLAYER_REGEN_ENABLED")
assert(group1[1]:GetWidth() == 115)
assert(db.spacing == 10 + ns.UnitFrames.Kit.INSET * 2, "later refreshes do not repeat migration")

-- (Malkkav 11-27) Width, Height and Power Height per raid size: a size takes its own copy once changed
-- (Raid Size picks which one the Size section sets); the others keep the shared values; in a raid the
-- group's size picks them
do
    local RF = ns.RaidFrames
    assert(db.sizes and db.sizes.small and db.sizes.small.width == 115, "the Width set above went to the size picked (10)")
    local shared = db.width
    ui.editing = true
    edit.callbacks.enter()
    edit.refreshed = nil
    option(holder, "Raid Size").set("Modern", "large")
    assert(edit.refreshed == holder, "(e_kul) picking a Raid Size redraws the dialog, so the sliders show that size's values")
    assert(option(holder, "Width").get() == shared, "a size never changed shows the shared Width")
    option(holder, "Width").set("Modern", 70)
    assert(db.sizes.large.width == 70 and db.width == shared, "its own copy; the shared value stays")
    ui.editing = false
    edit.callbacks.exit()
    E.GetNumGroupMembers = function() return 30 end
    assert(RF.SizeTier() == "large" and RF.SizeValue("width") == 70)
    E.GetNumGroupMembers = function() return 18 end
    assert(RF.SizeTier() == "medium" and RF.SizeValue("width") == shared, "medium: never changed, the shared Width")
    E.GetNumGroupMembers = function() return 8 end
    assert(RF.SizeTier() == "small" and RF.SizeValue("width") == 115)
end

do
    -- Aura Tooltips: the raid's pick, the main tanks' own over it, a pick saved on the Tooltips page under both
    local raidRow, tankRow = option(holder, "Aura Tooltips"), option(tanks, "Aura Tooltips")
    assert(raidRow.get() == "always" and tankRow.get() == "always")
    ns.db.profile.tooltips.visibility.groupAuras = "combat"
    assert(raidRow.get() == "combat" and tankRow.get() == "combat", "a pick saved on the Tooltips page carries over")
    raidRow.set("Modern", "never")
    assert(db.auraTooltips == "never" and tankRow.get() == "never", "the main tanks follow the raid")
    tankRow.set("Modern", "always")
    assert(db.mainTanks.auraTooltips == "always" and tankRow.get() == "always" and raidRow.get() == "never")

    -- each tile's icons follow their own frame's pick
    local Widget = getmetatable(E.UIParent)
    function Widget:SetMouseMotionEnabled(value) self.mouseMotion = value end
    function Widget:SetReverse(value) self.reverseCooldown = value end
    E.C_StringUtil = E.C_StringUtil or { CreateNumericRuleFormatter = function() return nil end }
    option(holder, "Debuffs").set("Modern", "INSIDE_TOPRIGHT")
    option(tanks, "Debuffs").set("Modern", "INSIDE_TOPRIGHT")
    local function icon(tile)
        local _, group = next(tile.AuraPos.INSIDE_TOPRIGHT.container.groups)
        local button = E.CreateFrame("Frame", nil, tile)
        group.opts.initializeFrame(button)
        return button
    end
    local raidIcon, tankIcon = icon(group1[1]), icon(E.FlareUI_RaidTanksHeader[1])
    assert(raidIcon.mouseMotion == false and tankIcon.mouseMotion == true, "Never on the raid only")
    raidRow.set("Modern", "always")
    tankRow.set("Modern", "never")
    assert(raidIcon.mouseMotion == true and tankIcon.mouseMotion == false, "Never on the main tanks only")
    ns.db.profile.tooltips.visibility.groupAuras = nil
    db.auraTooltips, db.mainTanks.auraTooltips = nil, nil
    assert(raidRow.get() == "always" and tankRow.get() == "always")
end

print("PASS: raid lifecycle, headers, tank targets, Edit Mode and combat deferral")
