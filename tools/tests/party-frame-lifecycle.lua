local ui, ns, unit, libEdit = assert(loadfile("tools/tests/fixtures/party-world.lua"))(true)
local env = ui.env
local party = ns.db.profile.unitframes.party
env.AuraUtil = { AuraUpdateChangedType = { Buff = 1, Dispel = 2 } }
env.Enum.CustomAuraButtonDispelTypeTextureStyle = { Icon = 1, PreserveAsset = 2, Border = 3 }
local Widget = getmetatable(env.UIParent)
env.C_StringUtil = { CreateNumericRuleFormatter = function() return nil end }
function Widget:SetReverse(value) self.reverseCooldown = value end
function Widget:SetAuraSlotFilterString(key, filter) self.auraSlots[key].filter = filter end
function Widget:SetMouseMotionEnabled(value) self.mouseMotion = value end
local tooltipSettings = ns.db.profile.tooltips
tooltipSettings.enabled, tooltipSettings.visibility.groupAuras = true, "combat"
party.pets, party.targets, party.showSolo = true, true, true
party.classic.portrait = "class"
party.classic.castbar, party.classic.smoothBars = true, true
party.classic.icons.pvp = { shown = true }
party.classic.buffs = "LEFT"
local pf = ns.PartyFrames
assert(pf:ShouldLoad())
ui.combat = true
pf:Init()
assert(not pf.initialized and not env.FlareUI_Party)
ui.combat = false
ui:emit("PLAYER_REGEN_ENABLED")
local holder, a, b = env.FlareUI_Party, env.FlareUI_Party1, env.FlareUI_Party2
local pet, targetTile = env.FlareUI_PartyPet1, env.FlareUI_PartyTarget1
assert(pf.initialized and not env.PartyFrame:IsShown() and party.classic.buffs == "RIGHT")
assert(a.unitWatched and pet.unitWatched and targetTile.unitWatched)
assert(a.Health:GetValue() == 80 and a.Power:GetValue() == 60 and a.Name:GetText() == "Mira Reed")
assert(a.Portrait.Tex:GetAtlas() == "class:HUNTER")
assert(pet.Health:GetValue() == 71 and targetTile.Health:GetValue() == 25 and targetTile.Name:GetText() == "Spider")
assert(b.LeaderIcon:IsShown() and b.RoleIcon:IsShown())
assert(select(5, b:GetPoint()) > select(5, a:GetPoint()), "Role order puts the tank first")
assert(holder:GetAttribute("visibility"):find("%[group:raid%] hide"))
assert(env.ClickCastFrames[a] and a:GetAttribute("*type2") == "togglemenu")

local buffLane, debuffLane = a.AuraPos.RIGHT.container, a.AuraPos.INSIDE_TOPRIGHT.container
local buffKey, buffGroup = next(buffLane.groups)
assert(buffGroup.filter == "HELPFUL|PLAYER" and buffGroup.layout.elementWidth == party.classic.auraSize)
local _, debuffGroup = next(debuffLane.groups)
local auraButton = env.CreateFrame("Frame", nil, debuffLane)
debuffGroup.opts.initializeFrame(auraButton)
assert(ns.auraTipKind[auraButton] == "group" and auraButton.propagate and auraButton.mouseMotion)
ui:emit("PLAYER_REGEN_DISABLED")
assert(not auraButton.mouseMotion)
ui:emit("PLAYER_REGEN_ENABLED")
assert(auraButton.mouseMotion)
local highlight = a.AuraHighlight.container
local highlightKey, highlightSlot = next(highlight.auraSlots)
assert(highlightSlot.filter == "HARMFUL|RAID" and highlightSlot.enabled)
party.classic.dispelHighlight = "all"
pf:Refresh()
assert(highlight.auraSlots[highlightKey].enabled and highlightSlot.filter == "HARMFUL|RAID_PLAYER_DISPELLABLE")
party.classic.hideBuffs = "30"
pf:Refresh()
assert(buffLane.groups[buffKey].candidates.maxDuration == 30)
unit.party1.far = true
a:RunScript("OnEvent", "UNIT_IN_RANGE_UPDATE", "party1")
assert(not buffLane.groups[buffKey].candidates.maxDuration)
unit.party1.far = false
a:RunScript("OnEvent", "UNIT_IN_RANGE_UPDATE", "party1")
assert(buffLane.groups[buffKey].candidates.maxDuration == 30)
party.classic.buffs, party.classic.debuffs, party.classic.auraOuter = "ABOVE_WIDE", "ABOVE", "buffs"
pf:Refresh()
assert(a.AuraPos.ABOVE_WIDE.container:IsShown() and not buffLane:IsShown() and a.AuraStackStrip)
assert(not buffLane.groups[buffKey].enabled and buffLane.groups[buffKey].maxFrameCount == 0)

unit.party1.health, unit.party1.heal, unit.party1.absorb = 40, 15, 10
a:RunScript("OnEvent", "UNIT_HEALTH", "party1")
a:RunScript("OnEvent", "UNIT_HEAL_PREDICTION", "party1")
assert(a.Health:GetValue() == 80, "Health and prediction changes are coalesced until the next frame")
for _, frame in ipairs(ui.widgets) do
    if frame:IsVisible() then frame:RunScript("OnUpdate", 0.1) end
end
assert(a.Health:GetValue() == 40 and a.HealBar:GetValue() == 15 and a.AbsorbBar:GetValue() == 10)
unit.party1.power = 14
a:RunScript("OnEvent", "UNIT_POWER_UPDATE", "party1")
assert(a.Power:GetValue() == 14)
unit.party1.far, unit.party1.phase = true, 1
a:RunScript("OnEvent", "UNIT_PHASE", "party1")
a:RunScript("OnEvent", "UNIT_IN_RANGE_UPDATE", "party1")
assert(a:GetAlpha() == 0.45 and a.StatusIcon:IsShown())
unit.party1.distance = 100000
a:RunScript("OnEvent", "UNIT_IN_RANGE_UPDATE", "party1")
assert(not a.StatusIcon:IsShown())
unit.party1.far, unit.party1.phase, unit.party1.mark = false, nil, 4
ui:emit("RAID_TARGET_UPDATE")
assert(a.RaidIcon:IsShown() and a.RaidIcon.raidMark == 4)
ui.targetUnit = "party1"
ui:emit("PLAYER_TARGET_CHANGED")
assert(a.TargetHighlight:GetAlpha() > 0 and b.TargetHighlight:GetAlpha() == 0)
unit.party1.ready = "waiting"
ui:emit("READY_CHECK")
assert(a.ReadyIcon:IsShown())
ui:emit("READY_CHECK_FINISHED")
assert(a.ReadyIcon:IsShown())
unit.party1.ready = nil
ui:flushTimers()
assert(not a.ReadyIcon:IsShown())
a:RunScript("OnEnter")
assert(a.Highlight:IsShown() and env.GameTooltip.unit == "party1")
a:RunScript("OnLeave")
assert(not a.Highlight:IsShown() and not env.GameTooltip:IsShown())

party.style, party.orientation, party.raid.powerManaOnly = "raid", "HORIZONTAL", true
local originalWidth = a:GetWidth()
ui.combat = true
pf:Refresh()
assert(a:GetWidth() == originalWidth)
ui.combat = false
ui:emit("PLAYER_REGEN_ENABLED")
assert(a:GetWidth() == party.raid.width and holder:GetWidth() > a:GetWidth())
assert(a.Power:IsShown() and not b.Power:IsShown(), "Raid Style's mana-only excludes warriors")
-- (11-23) the same tiles leave Classic: its Left / Middle texts go, Raid Style's Centre pick shows alone
assert(a.btTexts and a.btTexts.health, "Classic made its slot texts")
for _, bar in ipairs({ "health", "power" }) do
    local t = a.btTexts[bar]
    if t then assert(not t.left:IsShown() and not t.middle:IsShown(), bar .. ": Classic texts left on a Raid Style tile") end
end
ns.BarText.Toggle(party.raid, "health", "middle", "tile", "percent", false, nil, nil, "party")
pf:Refresh()
a:RunScript("OnEvent", "UNIT_HEALTH", "party1")
for _, frame in ipairs(ui.widgets) do
    if frame:IsVisible() then frame:RunScript("OnUpdate", 0.1) end
end
assert((a.HealthText:GetText() or ""):find("%%"), "the Centre pick: " .. tostring(a.HealthText:GetText()))
assert(not a.btTexts.health.middle:IsShown())
holder.moved(holder, "Other", "CENTER", 20.6, -30)
libEdit.callbacks.layout("Other")
local point, _, _, x, y = holder:GetPoint()
assert(point == "CENTER" and x == 21 and y == -30)

-- Show Target Markers (11-23): off to start; on, the raid marker over the target tile's right border
local token = targetTile.fuiUnit
unit[token].mark = 8
ui:emit("RAID_TARGET_UPDATE")
assert(not targetTile.RaidIcon:IsShown(), "off to start")
local row, seenBorder
for _, entry in ipairs(holder.settings) do
    if entry.name == "Target Border" then seenBorder = true end
    if entry.name == "Show Target Markers" then row = assert(seenBorder and entry, "after the sliders and dropdowns") end
end
assert(row and row.default == false and row.get() == false)
row.set(nil, true)
assert(party.classic.targetMarkers == true, "the dialog was built for Classic")
party.raid.targetMarkers = true
pf:Refresh()
assert(targetTile.RaidIcon:IsShown() and targetTile.RaidIcon.raidMark == 8)
local point2, anchor2, relative2, offX = targetTile.RaidIcon:GetPoint()
assert(point2 == "CENTER" and anchor2 == targetTile and relative2 == "RIGHT" and offX == 0, "half over the right border")
local nameEnd = select(4, targetTile.Name:GetPoint(2))
unit[token].mark = nil
ui:emit("RAID_TARGET_UPDATE")
assert(not targetTile.RaidIcon:IsShown())
unit[token].mark = 1
targetTile:RunScript("OnEvent", "UNIT_TARGET", "party1")
assert(targetTile.RaidIcon:IsShown() and targetTile.RaidIcon.raidMark == 1, "a new target's")

ui.editing = true
libEdit.callbacks.enter()
local samples, skulls = 0, 0
for i = 0, 4 do
    local t = env["FlareUI_PartyTarget" .. i]
    if t and t:IsShown() then
        samples = samples + 1
        if t.RaidIcon:IsShown() then skulls = skulls + 1 assert(t.RaidIcon.raidMark == 8) end
    end
end
assert(samples > 0 and skulls > 0 and skulls < samples, "the sample enemies wear the skull, the sample friend nothing")
assert(holder:IsShown() and holder:GetAttribute("visibility") == nil)
assert(a:IsShown() and not a.unitWatched and a.Name:GetText() ~= "Mira Reed")
local sample = pf.SampleTile(env.UIParent, nil, nil, 1)
local w, h = pf.DrawSampleTile(sample)
assert(w == party.raid.width and h == party.raid.height and sample.Name:GetText() ~= "")
ui.editing = false
libEdit.callbacks.exit()
assert(a.unitWatched and a.Name:GetText() == "Mira Reed")
assert(targetTile.RaidIcon.raidMark == 1)
party.raid.targetMarkers = false
pf:Refresh()
assert(not targetTile.RaidIcon:IsShown() and select(4, targetTile.Name:GetPoint(2)) > nameEnd, "the name has its room back")

-- the Gamepad UI doubles the target highlight with a second copy; the mouse UI keeps one
local hl, isGamepad = a.TargetHighlight, ns.IsGamepadUI
ui:emit("PLAYER_TARGET_CHANGED")
assert(hl.Border:IsShown() and not hl.Border2:IsShown(), "mouse UI: one highlight")
ns.IsGamepadUI = function() return true end
ui:emit("PLAYER_TARGET_CHANGED")
assert(hl.Border:IsShown() and hl.Border2:IsShown(), "Gamepad UI: the second copy shows")
assert(hl.Border2:GetBackdrop() ~= nil, "the second copy has the border art")
ns.IsGamepadUI = isGamepad
ui:emit("PLAYER_TARGET_CHANGED")
assert(not hl.Border2:IsShown())
print("PASS: party frames live health, role/order, secure registration, pets, targets and Edit Mode")
