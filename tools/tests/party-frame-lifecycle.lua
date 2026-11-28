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
-- (11-24) Always Show: its row needs plain rules, so it has a container of its own, on past the buffs
do
    local oldAuras = ns.db.profile.auras
    ns.db.profile.auras = ns.db.profile.auras or {}
    local HA = ns.HiddenAuras
    assert(not a.AuraPos["RIGHT+"], "none made until it is needed")
    HA.Add(1243, "shown")
    pf:Refresh()
    local extra = a.AuraPos["RIGHT+"].container
    local _, always = next(extra.groups)
    assert(extra:IsShown() and always.filter == "HELPFUL" and always.candidates.includeSpellIDs[1243])
    assert(extra.auraPolicy == 0 and a.AuraPos.RIGHT.container.auraPolicy == 1, "plain rules beside Blizzard's")
    assert(extra.unit[1] == "party1")
    local _, over = extra:GetPoint()
    assert(over == a.AuraPos.RIGHT.container)
    for key, group in pairs(a.AuraPos.RIGHT.container.groups) do
        assert(not key:find("always") or not group.enabled, "not in the first one too")
    end
    -- stacked past the buffs, the other kind clears the second container's own line
    local buffs, debuffs, outer = party.classic.buffs, party.classic.debuffs, party.classic.auraOuter
    party.classic.buffs, party.classic.debuffs, party.classic.auraOuter = "ABOVE_WIDE", "ABOVE", "debuffs"
    pf:Refresh()
    assert(a.AuraPos["ABOVE_WIDE+"].lineOwn)
    local _, under = a.AuraStackStrip:GetPoint(3)
    assert(under == a.AuraPos["ABOVE_WIDE+"].container)
    assert(a.AuraStackStrip.template == "DisableUntrustedLayoutScriptsTemplate"
        and under.template:find("DisableUntrustedLayoutScriptsTemplate", 1, true), "both may be anchored to a container")
    party.classic.buffs, party.classic.debuffs, party.classic.auraOuter = buffs, debuffs, outer
    HA.Remove(1243, "shown")
    pf:Refresh()
    assert(not extra:IsShown() and not always.enabled)
    ns.db.profile.auras = oldAuras
end
-- (11-25) a member under Mind Control: no dispel type icons until they are back
do
    local look = ns.AuraLook
    local seen
    ns.AuraLook = { DispelSide = function(f, hidden) if f == a then seen = hidden end end }
    unit.party1.hostile = true
    a:RunScript("OnEvent", "UNIT_FACTION", "party1")
    assert(seen == true)
    unit.party1.hostile = nil
    a:RunScript("OnEvent", "UNIT_FLAGS", "party1")
    assert(seen == false)
    ns.AuraLook = look
end
-- (11-25) a side on its own takes the tile's whole width; both sides used, half each
do
    local function Line(pos)
        local v = a.AuraPos[pos].container.lineSize
        return type(v) == "table" and v[1] or v
    end
    party.classic.buffs, party.classic.debuffs = "ABOVE", "ABOVE_RIGHT"
    pf:Refresh()
    local half = Line("ABOVE")
    party.classic.debuffs = "BELOW"
    pf:Refresh()
    assert(Line("ABOVE") > half and Line("BELOW") == Line("ABOVE"), "nothing beside it")
    -- Above the Frame: as many as Max Buffs says, on lines the tile's width long
    local function Max(pos)
        for _, group in pairs(a.AuraPos[pos].container.groups) do
            if group.enabled and group.maxFrameCount > 0 then return group.maxFrameCount end
        end
    end
    local amount, width = party.classic.buffAmount, party.classic.width
    party.classic.buffs, party.classic.debuffs, party.classic.buffAmount = "ABOVE_WIDE", "BELOW", 2
    pf:Refresh()
    local narrow = Line("ABOVE_WIDE")
    assert(Max("ABOVE_WIDE") == 2, "Max Buffs")
    party.classic.width, party.classic.buffAmount = (width or 200) + 120, 9
    pf:Refresh()
    assert(Max("ABOVE_WIDE") == 9 and Line("ABOVE_WIDE") > narrow, "a wider tile, a longer line")
    party.classic.buffAmount, party.classic.width = amount, width
    pf:Refresh()
end
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

-- Only Mana Power Bars outside Raid Style too
assert(b.Power:IsShown())
party.classic.powerManaOnly = true
pf:Refresh()
assert(a.Power:IsShown() and not b.Power:IsShown() and b.noPowerBar and not a.noPowerBar, "the hunter keeps it, the warrior doesn't")
party.classic.powerManaOnly = nil
pf:Refresh()
assert(b.Power:IsShown() and not b.noPowerBar)

party.style, party.orientation, party.raid.powerManaOnly = "raid", "HORIZONTAL", true
local originalWidth = a:GetWidth()
ui.combat = true
pf:Refresh()
assert(a:GetWidth() == originalWidth)
ui.combat = false
ui:emit("PLAYER_REGEN_ENABLED")
assert(a:GetWidth() == party.raid.width and holder:GetWidth() > a:GetWidth())
assert(a.Power:IsShown() and not b.Power:IsShown(), "Raid Style's mana-only excludes warriors")
-- Raid Style (11-23, Malkkav): all three text places, as Classic, with no name in them
local slotTexts = a.btTexts.health
for _, slot in ipairs({ "left", "middle", "right" }) do assert((slotTexts[slot]:GetText() or "") == "", slot .. ": empty to start, nothing left of Classic's") end
local function refreshHealth()
    pf:Refresh()
    a:RunScript("OnEvent", "UNIT_HEALTH", "party1")
    for _, frame in ipairs(ui.widgets) do
        if frame:IsVisible() then frame:RunScript("OnUpdate", 0.1) end
    end
end
-- a pick made with the old Centre-only picker stays in the middle
ns.BarText.Toggle(party.raid, "health", "middle", "tile", "percent", false, nil, nil, "party")
refreshHealth()
assert((slotTexts.middle:GetText() or ""):find("%%") and slotTexts.middle:IsShown(), "the Centre pick: " .. tostring(slotTexts.middle:GetText()))
assert((slotTexts.right:GetText() or "") == "")
ns.BarText.Toggle(party.raid, "health", "left", "partytile", "max", false, nil, nil, "party")
ns.BarText.Toggle(party.raid, "health", "right", "partytile", "value", false, nil, nil, "party")
refreshHealth()
assert(slotTexts.right == a.HealthText and (slotTexts.right:GetText() or "") ~= "" and (slotTexts.left:GetText() or "") ~= "")
local function spot(fs) local p, anchor, r, _, dy = fs:GetPoint() return p, anchor, r, dy end
local lp, lf, lr, ly = spot(slotTexts.left)
assert(lp == "LEFT" and lf == a.Health and lr == "LEFT" and ly == -4, "under the name on top of the tile")
assert(select(1, spot(slotTexts.middle)) == "CENTER" and select(1, spot(slotTexts.right)) == "RIGHT")
assert(select(2, a.Name:GetPoint()) == a.RoleIcon and a.Name:IsShown() and a.Name:GetText() == "Mira Reed", "the name stays on top, beside the role icon")
-- no names in the list, and no level; the party's Show Name keeps deciding
for _, v in ipairs(ns.BarText.Values("health", "partytile")) do assert(v.value ~= "fullname" and v.value ~= "firstname") end
-- a slim power bar: its texts at the health bar's foot
ns.BarText.Toggle(party.raid, "power", "left", "partytile", "percent", false, nil, nil, "party")
party.raid.powerHeight = 6
pf:Refresh()
assert(a.btTexts.power.left:GetPoint() == "BOTTOMLEFT" and select(2, a.btTexts.power.left:GetPoint()) == a.Health)
assert(a.btTexts.power.middle:GetPoint() == "BOTTOM")
party.raid.powerHeight = 12
pf:Refresh()
assert(a.btTexts.power.left:GetPoint() == "LEFT" and select(2, a.btTexts.power.left:GetPoint()) == a.Power)
party.raid.powerHeight = 6
-- Dead and Offline stay in the middle
unit.party1.offline = true
local connected = env.UnitIsConnected
env.UnitIsConnected = function(token) return token ~= "party1" and connected(token) end
refreshHealth()
assert((slotTexts.middle:GetText() or "") ~= "" and (slotTexts.left:GetText() or "") == "" and (slotTexts.right:GetText() or "") == "")
env.UnitIsConnected, unit.party1.offline = connected, nil
refreshHealth()
assert((slotTexts.left:GetText() or "") ~= "")
-- one Health Text and one Power Text row, whatever the style
local rows = { ["Health Text"] = 0, ["Power Text"] = 0 }
for _, entry in ipairs(holder.settings) do if rows[entry.name] then rows[entry.name] = rows[entry.name] + 1 end end
assert(rows["Health Text"] == 1 and rows["Power Text"] == 1)
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

-- Show Level puts the level before Name Above Frames too, not in the ring styles
do
    local st, shown = party.classic, party.classic.showLevel
    local tile = setmetatable({ NameAboveText = a:CreateFontString() }, { __index = a })
    local function text(level, ring, sample)
        st.nameAbove, st.showLevel, tile.ringKind = "left:firstname", level, ring
        pf.SetNameAbove(tile, sample)
        return tile.NameAboveText:GetText()
    end
    local db = pf.NameAboveDb(tile)
    local old, oldLevel = db.nameAbove, db.showLevel
    if db ~= st then st = db end
    assert(text(true):find("42|r Mira", 1, true), "the level before the name")
    assert(text(false) == "Mira")
    assert(text(true, "party") == "Mira", "ring styles: the disc has it")
    tile.ringKind = nil
    assert(text(true, nil, { name = "Zorgath", level = 60 }) == "|cffffd10060|r Zorgath")
    db.nameAbove, db.showLevel = old, oldLevel
    party.classic.showLevel = shown
end

-- (11-25) Forever Style's name box: Show Name picks which name, as in Raid Style
do
    local tile = { index = 1, btTexts = { health = {}, power = {} } }
    local full = ns.BarText.FullOf
    assert(full("lastname") == "lastname" and full("firstname") == false and full("fullname") == true)
    local found
    for _, item in ipairs(holder.settings) do if item.name == "Show Name" then found = (found or 0) + 1 end end
    assert(found == 1, "one Show Name row")
end

-- (11-25) a secret PvP flag (battlegrounds): the crest is drawn and the flag sets its alpha, unread
do
    local icon, member = a.PvPIcon, unit[a.fuiUnit]
    local alpha
    local raidIcons = party.raid.icons
    party.raid.icons = { pvp = { shown = true } }   -- (the style on now)
    function icon:SetAlphaFromBoolean(value) alpha = value end
    member.pvp = true
    pf.UpdatePvP(a)
    assert(icon:IsShown() and alpha == nil)
    member.pvp = "hidden"
    pf.UpdatePvP(a)
    assert(icon:IsShown() and alpha == "hidden")
    icon:SetAlpha(0)
    member.pvp = true
    pf.UpdatePvP(a)
    assert(icon:IsShown() and icon:GetAlpha() == 1)
    icon.SetAlphaFromBoolean = nil
    member.pvp = "hidden"
    pf.UpdatePvP(a)
    assert(not icon:IsShown())
    member.pvp = false
    pf.UpdatePvP(a)
    assert(not icon:IsShown())
    party.raid.icons = raidIcons
end

-- a tile with Elite & Rare (the boss frames'): the dragon, the border bronze for every unit (11-26: no
-- gold or silver any more); no dragon for the rest and in the ring styles
do
    local tile = { fuiUnit = a.fuiUnit, Border = env.CreateFrame("Frame", nil, a), Overlay = env.CreateFrame("Frame", nil, a), ClassIcon = a:CreateTexture() }
    local function dragon() return tile.FUIDragon and tile.FUIDragon.kind end
    local classify, kind = env.UnitClassification, nil
    env.UnitClassification = function() return kind end
    tile.Border:SetBackdropBorderColor(0.1, 0.2, 0.3, 1)
    -- the border keeps whatever colour it had: the dragon alone shows the rank
    local function at()
        pf.UpdateClassIcon(tile)
        local r, g, b = tile.Border:GetBackdropBorderColor()
        return r == 0.1 and g == 0.2 and b == 0.3
    end
    kind = "worldboss"
    assert(at() and dragon() == "Boss" and not tile.ClassIcon:IsShown())
    kind = "rareelite"
    assert(at() and dragon() == "Rare")
    tile.ringKind = "boss"
    assert(at() and dragon() == nil)
    tile.ringKind, kind = nil, "normal"
    assert(at() and dragon() == nil)
    env.UnitClassification = classify
end
print("PASS: party frames live health, role/order, secure registration, pets, targets and Edit Mode")
