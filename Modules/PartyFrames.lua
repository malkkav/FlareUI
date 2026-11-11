local _, ns = ...
local L = ns.L

--------------------------------------------------
-- PARTY FRAMES
-- The player (optional) and up to four party members, Classic or Raid-Style, each style with its own
-- settings; also the tile kit the raid and boss frames build on. Secret-safe: values go straight
-- into widgets and readable() guards every Lua test. Blizzard's PartyFrame is hidden.
--------------------------------------------------

--------------------------------------------------
-- 1. MODULE REGISTRATION
--------------------------------------------------
ns.PartyFrames = ns.PartyFrames or {}
local PF = ns.PartyFrames
ns.modules["PartyFrames"] = PF

LibStub("AceEvent-3.0"):Embed(PF)

--------------------------------------------------
-- 2. UPVALUES / CONSTANTS
--------------------------------------------------
local _G = _G
local pairs, ipairs, type, pcall, tostring = pairs, ipairs, type, pcall, tostring
local math_floor, math_max, math_min = math.floor, math.max, math.min
local CreateFrame, InCombatLockdown = CreateFrame, InCombatLockdown
local LEM = LibStub("FlareEditMode")
local K = ns.UnitFrames and ns.UnitFrames.Kit

-- the aura shape and timer shared with the unit frames
local function UFAura(field, default)
    local db = K and K.GetDb and K.GetDb()
    local value = db and db[field]
    if value == nil then return default end
    return value
end

local canaccessvalue = canaccessvalue or function() return true end
local function readable(v) if canaccessvalue(v) then return v end end

local MAX_MEMBERS = 4
local SLOT_UNITS = { [0] = "player", "party1", "party2", "party3", "party4" }
local PET_UNITS  = { [0] = "pet", "partypet1", "partypet2", "partypet3", "partypet4" }
local TARGET_UNITS = { [0] = "target", "party1target", "party2target", "party3target", "party4target" }
local BASE_POSITION = { point = "LEFT", x = 3, y = 0 }
-- Edit Mode keeps a reference to this table: ApplyPosition refills it for the style in use
local DEFAULT_POSITION = { point = "LEFT", x = 3, y = 0 }
local PET_GAP = 2
local TARGET_GAP = 6                 -- gap between a party frame and its target
local TARGET_INTERVAL = 0.2          -- a member's target sends no health events: re-read this often
local PREVIEW_HOSTILE_RGB = { 0.87, 0.27, 0.27 }
local AURA_SPACING = 2
local AURA_CONTAINER_TEMPLATE = "CustomAuraContainerTemplate"
local READY_CHECK_HOLD = 6           -- seconds the result stays after a ready check ends
local RANGE_INTERVAL = 1   -- a safety re-check: range comes from UNIT_IN_RANGE_UPDATE
local RANGE_ALPHA = 0.45             -- out of range
-- auras per lane and per row, by party style (an owner's view gives its own: auraMax, auraPerRow)
local PARTY_AURA_GRID = { classic = { 5, 5 }, raid = { 6, 3 } }

-- Where a lane of auras can go. WIDE_PLACES span the width; INSIDE_CENTER / LEFT / RIGHT are the
-- raid frames' only; PORTRAIT holds the party frames' dispel icons.
local AURA_POSITIONS = { "RIGHT", "LEFT", "ABOVE", "ABOVE_RIGHT", "ABOVE_WIDE", "BELOW", "BELOW_RIGHT", "BELOW_WIDE",
                         "INSIDE_TOPLEFT", "INSIDE_TOPRIGHT", "INSIDE_TOP", "INSIDE_BOTTOMLEFT", "INSIDE_BOTTOMRIGHT",
                         "INSIDE_BOTTOM", "INSIDE_CENTER", "INSIDE_LEFT", "INSIDE_RIGHT", "PORTRAIT" }
local AURA_POSITION_VALUES = {
    { text = L["Off"],                 value = "OFF",                isRadio = true },
    { text = L["Right of the Frame"],  value = "RIGHT",              isRadio = true },
    { text = L["Left of the Frame"],   value = "LEFT",               isRadio = true },
    { text = L["Above the Frame"],        value = "ABOVE_WIDE",   isRadio = true },
    { text = L["Above the Frame, Left"],  value = "ABOVE",        isRadio = true },
    { text = L["Above the Frame, Right"], value = "ABOVE_RIGHT",  isRadio = true },
    { text = L["Below the Frame"],        value = "BELOW_WIDE",   isRadio = true },
    { text = L["Below the Frame, Left"],  value = "BELOW",        isRadio = true },
    { text = L["Below the Frame, Right"], value = "BELOW_RIGHT",  isRadio = true },
    { text = L["Inside, Top"],          value = "INSIDE_TOP",         isRadio = true },
    { text = L["Inside, Top Left"],     value = "INSIDE_TOPLEFT",     isRadio = true },
    { text = L["Inside, Top Right"],    value = "INSIDE_TOPRIGHT",    isRadio = true },
    { text = L["Inside, Bottom"],       value = "INSIDE_BOTTOM",      isRadio = true },
    { text = L["Inside, Bottom Left"],  value = "INSIDE_BOTTOMLEFT",  isRadio = true },
    { text = L["Inside, Bottom Right"], value = "INSIDE_BOTTOMRIGHT", isRadio = true },
}
-- the edge each place sits on: a whole-width place clashes with every other place on its edge
local PLACE_EDGE = { ABOVE = "above", ABOVE_RIGHT = "above", ABOVE_WIDE = "above",
                     BELOW = "below", BELOW_RIGHT = "below", BELOW_WIDE = "below",
                     INSIDE_TOPLEFT = "insideTop", INSIDE_TOPRIGHT = "insideTop", INSIDE_TOP = "insideTop",
                     INSIDE_BOTTOMLEFT = "insideBottom", INSIDE_BOTTOMRIGHT = "insideBottom", INSIDE_BOTTOM = "insideBottom",
                     INSIDE_LEFT = "insideMiddle", INSIDE_RIGHT = "insideMiddle", INSIDE_CENTER = "insideMiddle" }
local WIDE_PLACES = { ABOVE_WIDE = true, BELOW_WIDE = true, INSIDE_TOP = true, INSIDE_BOTTOM = true, INSIDE_CENTER = true }
local function PlacesClash(a, b)
    if not a or not b or a == "OFF" or b == "OFF" then return false end
    if a == b then return true end
    return PLACE_EDGE[a] ~= nil and PLACE_EDGE[a] == PLACE_EDGE[b] and (WIDE_PLACES[a] or WIDE_PLACES[b]) or false
end
-- the places below the frame (the cast bar goes past the auras there)
local BELOW_PLACES = { "BELOW", "BELOW_RIGHT", "BELOW_WIDE" }
local ABOVE_PLACES = { "ABOVE", "ABOVE_RIGHT", "ABOVE_WIDE" }

-- Blizzard's raid frame center status (CompactUnitFrame.lua centerStatusSetupData)
local STATUS_ATLAS = {
    IncomingResurrection   = "RaidFrame-Icon-Rez",
    IncomingSummonPending  = "RaidFrame-Icon-SummonPending",
    IncomingSummonAccepted = "RaidFrame-Icon-SummonAccepted",
    IncomingSummonDeclined = "RaidFrame-Icon-SummonDeclined",
    InOtherPhase           = "RaidFrame-Icon-Phasing",
    InPublicGroup          = "RaidFrame-Icon-LFR",
}
local READY_ATLAS = {
    ready    = _G.READY_CHECK_READY_TEXTURE or "UI-LFG-ReadyMark",
    notready = _G.READY_CHECK_NOT_READY_TEXTURE or "UI-LFG-DeclineMark",
    waiting  = _G.READY_CHECK_WAITING_TEXTURE or "UI-LFG-PendingMark",
}
-- Blizzard's unit frame role icons
local ROLE_ATLAS = { TANK = "UI-LFG-RoleIcon-Tank-Micro-GroupFinder", HEALER = "UI-LFG-RoleIcon-Healer-Micro-GroupFinder",
                     DAMAGER = "UI-LFG-RoleIcon-DPS-Micro-GroupFinder" }

-- The frame icons, switched per style in Edit Mode: style.icons[key] = { shown }
local ICON_ORDER  = { "role", "leader", "raidIcon", "readyCheck", "status" }
local ICON_LABELS = { role = L["Role"], leader = L["Leader"], raidIcon = L["Raid Markers"], readyCheck = L["Ready Check"], status = L["Summon / Resurrect / Phase"] }
-- the icons drawn larger than their base size (the role icon also on Raid-Style tiles: RAID_ROLE_SCALE)
local ICON_SCALE = { raidIcon = 1.25, readyCheck = 1.25, status = 1.25 }
local RAID_ROLE_SCALE = 1.2

-- Edit Mode samples: a tank, a healer and three damage dealers
local PREVIEW = {
    { name = "Thalorien", class = "WARRIOR", role = "TANK",    health = 0.92, power = 0.35, leader = true,
      portrait = "Interface\\Icons\\INV_Misc_Head_Human_01" },
    { name = "Elysande",  class = "PRIEST",  role = "HEALER",  health = 0.64, power = 0.85, ready = "ready",
      portrait = "Interface\\Icons\\INV_Misc_Head_Elf_02" },
    { name = "Morwen",    class = "WARLOCK", role = "DAMAGER", health = 0.48, power = 0.60, marker = 8, highlight = "Magic", pet = "Voidwalker",
      portrait = "Interface\\Icons\\INV_Misc_Head_Undead_02" },
    { name = "Sylvara",   class = "HUNTER",  role = "DAMAGER", health = 0.81, power = 0.72, pet = "Wolf", status = "IncomingResurrection",
      portrait = "Interface\\Icons\\INV_Misc_Head_Troll_02" },
    { name = "Kestrel",   class = "ROGUE",   role = "DAMAGER", health = 0.27, power = 0.90, status = "IncomingSummonPending",
      portrait = "Interface\\Icons\\INV_Misc_Head_Gnome_01" },
}
-- the samples' targets: the healer on the tank, the rest on an enemy
local PREVIEW_TARGETS = {
    { name = "Defias Pillager", health = 0.58 },
    { name = "Thalorien", class = "WARRIOR", health = 0.92 },
    { name = "Defias Pillager", health = 0.58 },
    { name = "Defias Pillager", health = 0.58 },
    { name = "Defias Pillager", health = 0.58 },
}
-- sample class and power colours, independent of the API
local PREVIEW_CLASS_RGB = {
    WARRIOR = { 0.78, 0.61, 0.43 }, PRIEST = { 1, 1, 1 }, WARLOCK = { 0.53, 0.53, 0.93 },
    HUNTER = { 0.67, 0.83, 0.45 }, ROGUE = { 1, 0.96, 0.41 },
}
local PREVIEW_POWER = { WARRIOR = "RAGE", PRIEST = "MANA", WARLOCK = "MANA", HUNTER = "MANA", ROGUE = "ENERGY" }
local PREVIEW_POWER_RGB = { MANA = { 0, 0, 1 }, RAGE = { 1, 0, 0 }, ENERGY = { 1, 1, 0 } }
local DISPEL_TYPES = { "Magic", "Curse", "Poison", "Disease" }
local DISPEL_RGB = { Magic = { 0.20, 0.60, 1.00 }, Curse = { 0.60, 0.00, 1.00 }, Poison = { 0.00, 0.60, 0.00 }, Disease = { 0.60, 0.40, 0.00 } }
-- sample auras for tiles without aura containers (the raid frames' Edit Mode samples)
local SAMPLE_BUFF_ICONS = { "Interface\\Icons\\Spell_Holy_Renew", "Interface\\Icons\\Spell_Nature_Rejuvenation", "Interface\\Icons\\Spell_Holy_PowerWordShield" }
local SAMPLE_DEBUFF_ICONS = { "Interface\\Icons\\Spell_Shadow_ShadowWordPain", "Interface\\Icons\\Spell_Fire_Immolation", "Interface\\Icons\\Ability_Creature_Poison_02" }

--------------------------------------------------
-- 3. SETTINGS ACCESS
--------------------------------------------------
local holder
local members, pets, targets = {}, {}, {}    -- [0..4] -> frame
local pendingLayout = false
local readyCheckHold            -- C_Timer handle while a finished check's results stay up

local function GetPartyDb()
    local db = K and K.GetDb()
    return db and db.party
end

-- The settings of the style in use
local function S()
    local party = GetPartyDb()
    if not party then return nil end
    local key = party.style == "raid" and "raid" or "classic"
    party[key] = party[key] or {}
    return party[key], key
end

local function IsRaidStyle()
    local party = GetPartyDb()
    return party and party.style == "raid"
end

-- A tile's settings: its owner's (f.ctx: raid and boss frames), else the party style's
local function TS(f)
    if f and f.ctx then return f.ctx.Settings() end
    return S()
end

-- Pets and Party Targets: "OFF", "BOTTOM" or "RIGHT" (party.petPlace / targetPlace). The party.pets /
-- party.targets switches are kept in step and answer "is it on"; without a place they decide it.
local function PetPlace()
    local party = GetPartyDb()
    if not party then return "OFF" end
    return party.petPlace or (party.pets and "BOTTOM" or "OFF")
end
local function Horizontal()
    local party = GetPartyDb()
    return party and party.orientation == "HORIZONTAL" or false
end

local function TargetPlace()
    local party = GetPartyDb()
    if not party then return "OFF" end
    return party.targetPlace or (party.targets and "RIGHT" or "OFF")
end

-- Raid-Style: the party in raid style, or an owned tile unless its owner wants the classic look
local function RaidTile(f)
    if f and f.ctx then return not f.ctx.classic end
    return IsRaidStyle()
end

-- Mirrored (the boss frames, like the target frame): portrait, level and name on the right, bars
-- filling right to left. fill: the bars' direction alone (ctx.fillMirror, when it differs)
local function Mirrored(f, fill)
    local c = f and f.ctx
    if not c then return false end
    if fill and c.fillMirror ~= nil then return c.fillMirror and true or false end
    return c.mirror and true or false
end

-- How many auras a lane holds, and how many to a row
local function AuraGrid(st)
    local party = GetPartyDb()
    local grid = party and (st == party.raid and PARTY_AURA_GRID.raid or st == party.classic and PARTY_AURA_GRID.classic)
    if grid then return grid[1], grid[2] end
    return st.auraMax, st.auraPerRow
end

-- Above or below the frame: one row per lane, as many as fit before the frame's middle (whole-width:
-- across, less the ring's room). Secure frames cannot move in combat, so LanesExtent reserves exactly
-- that row. Inside whole-width places fill the health bar in the grid's rows; elsewhere the fixed
-- grid.
local EDGE_PLACES = { ABOVE = true, ABOVE_RIGHT = true, ABOVE_WIDE = true, BELOW = true, BELOW_RIGHT = true, BELOW_WIDE = true }
-- Buffs Size / Debuffs Size: a place is as big as the largest kind it holds (dispel icons go with the
-- debuffs); a stored setup with both kinds in one place takes the larger
local function PlaceAuraSize(st, pos)
    local buff, debuff = ns.AuraSize(st, false, 18), ns.AuraSize(st, true, 18)
    local hasBuff = st.buffs == pos
    local hasDebuff = st.debuffs == pos or st.dispels == pos
    if hasBuff and not hasDebuff then return buff end
    if hasDebuff and not hasBuff then return debuff end
    return math_max(buff, debuff)
end

local function AuraFit(st, pos, f)
    local size = PlaceAuraSize(st, pos)
    local function PerRow(lineSize)
        return math_max(2, math_floor((math_max(size, lineSize) + AURA_SPACING) / (size + AURA_SPACING)))
    end
    if pos == "INSIDE_TOP" or pos == "INSIDE_BOTTOM" or pos == "INSIDE_CENTER" then
        local gridMax, gridPerRow = AuraGrid(st)
        local rows = math.ceil((gridMax or 5) / math_max(1, gridPerRow or 5))
        local width = (f and f.Health and f.Health:GetWidth()) or ((st.width or 200) - 2 * K.INSET)
        local perRow = PerRow(width - 4)
        return rows * perRow, perRow
    end
    if not EDGE_PLACES[pos] then return AuraGrid(st) end
    local lineSize
    if WIDE_PLACES[pos] then
        local clear = (f and f.ringKind and ns.UFRing) and ns.UFRing.Clearance(f, K.AURA_GAP) or 0
        lineSize = (st.width or 200) - 2 * K.INSET - clear
    else
        lineSize = math_floor((st.width or 200) / 2) - K.INSET - 4
    end
    local perRow = PerRow(lineSize)
    return perRow, perRow
end

-- A side and its opposite, swapped on a mirrored tile, and which way +x goes from the near side
local function Sides(f)
    if Mirrored(f) then return "RIGHT", "LEFT", -1 end
    return "LEFT", "RIGHT", 1
end

-- FlareUI Style: party (not Raid-Style) and boss tiles take the portrait ring (UnitFramesRing.lua);
-- stored as f.ringKind at layout
local function RingKind(f)
    if RaidTile(f) or not (ns.UFRing and ns.UFRing.Style() ~= "addon") then return nil end
    if f.ctx then return f.ctx.ringKind end
    return "party"
end

-- Forever Style: party (not Raid-Style) and boss tiles on the frame plate: sized by Scale, no inside
-- auras, no border (aggro flashes the ring; target and dispel highlight glow on the name box)
local function OnPlate(f)
    return f and f.ringKind and ns.UFRing and ns.UFRing.Plate(f) or false
end
-- the same, for the settings dialogs
local function PlateStyle()
    return ns.UFRing and ns.UFRing.PlateOn() or false
end
local function IsInsidePlace(pos) return type(pos) == "string" and pos:find("^INSIDE") ~= nil end

-- The party frames' Dispel Icons switch: up to four on the portrait (or the health bar). Any saved
-- place counts as on; owned tiles use their place setting.
local function DispelPlace(f, st)
    if f.ctx then return st.dispels end
    return (st.dispels and st.dispels ~= "OFF") and "PORTRAIT" or nil
end

-- the portrait's middle (the ring's, or the square's), else the health bar's
local function PortraitCentre(f)
    local st = TS(f)
    if f.ringKind or (not RaidTile(f) and st and (st.portrait or "none") ~= "none") then return f.Portrait end
    return f.Health
end

-- the dispel grid on the portrait: the ready check's size, split two by two (a cell, and the whole)
local function DispelGrid(f)
    local whole = math_max(20, math_floor(f.ReadyIcon:GetWidth() + 0.5))
    local cell = math_floor((whole - AURA_SPACING) / 2)
    return cell, 2 * cell + AURA_SPACING
end

-- room a row beside the ring needs: on the ring's side, where the ring ends at that distance out
local function RingClear(f, isLeft, gap)
    if not f.ringKind or (f.ringSide == "LEFT") ~= isLeft then return 0 end
    return ns.UFRing.Clearance(f, gap)
end

-- Edit Mode, unless a fight ended its previews (ns.OnEditFight)
local function IsEditing()
    return ns.EditPreviewing()
end

local function IconStore(key, create, f)
    local st = TS(f)
    if not st then return nil end
    if create then
        st.icons = st.icons or {}
        st.icons[key] = st.icons[key] or {}
    end
    return st.icons and st.icons[key]
end

local function IconShown(key, f)
    local store = IconStore(key, nil, f)
    if store and store.shown ~= nil then return store.shown end
    return true
end

local function PlaceIcon(f, key, region, width, height, point, relativeTo, relativePoint, x, y)
    local scale = ICON_SCALE[key] or 1
    if key == "role" and RaidTile(f) then scale = RAID_ROLE_SCALE end
    region:ClearAllPoints()
    region:SetSize(width * scale, height * scale)
    region:SetPoint(point, relativeTo, relativePoint, x, y)
end

local function ScaledFont(base, size)
    if not size then return base end
    return setmetatable({ size = size }, { __index = base or {} })
end

--------------------------------------------------
-- 4. UPDATERS (secret-safe, as in UnitFrames.lua)
--------------------------------------------------
-- a name can be secret: never tested unless it can be read
local function SafeName(name)
    if canaccessvalue(name) and not name then return "" end
    return name
end

local function UpdateName(f)
    -- the party frames pass "party" (first-name rules); raid and boss tiles show the whole name
    f.Name:SetText(SafeName(ns.UnitDisplayName(f.fuiUnit, not f.ctx and "party" or nil)))
end

local function UpdateLevel(f)
    local st = TS(f)
    if not (st and st.showLevel) then f.Level:SetText("") return end
    local level = UnitLevel(f.fuiUnit)
    if canaccessvalue(level) and level then
        if level < 0 then
            f.Level:SetText("??")
            f.Level:SetTextColor(1, 0.1, 0.1)
        else
            f.Level:SetFormattedText("%d", level)
            -- friendly: Blizzard's gold; neutral and hostile: by difficulty
            local color = ns.UnitLevelColor(f.fuiUnit, level)
            if color then f.Level:SetTextColor(color.r, color.g, color.b) else f.Level:SetTextColor(1, 1, 1) end
        end
    else
        f.Level:SetText(level)
        f.Level:SetTextColor(1, 1, 1)
    end
end

local function UpdateHealth(f, glide)
    local unit, st = f.fuiUnit, TS(f)
    local bar = f.Health
    bar:SetMinMaxValues(0, UnitHealthMax(unit))
    ns.SetBarValue(bar, UnitHealth(unit), glide and st and st.smoothBars and not UnitIsDead(unit))
    -- (a plain health change has the same colour, but for a hostile tile going grey when tapped)
    if not glide or (f.ctx and f.ctx.hostile) then bar:SetStatusBarColor(K.GetHealthColor(unit, ns.ClassColorsOn(st))) end

    local mode = st and st.healthText or "percent"
    local text = f.HealthText
    text:SetAlpha(1)
    if not UnitIsConnected(unit) then
        text:SetText(K.OFFLINE_TEXT)
    elseif K.IsDead(unit) then
        text:SetText(UnitIsGhost(unit) and K.GHOST_TEXT or K.DEAD_TEXT)
    elseif mode == "lost" then
        K.SetHealthLost(text, unit)
    elseif mode == "none" then
        text:SetText("")
    else
        K.FormatBarText(text, mode, UnitHealth(unit), UnitHealthPercent(unit, true, K.percentCurve), UnitHealthMax(unit))
    end
end

local LayoutBars   -- section 6

-- Mana Users Only (raid tiles): no power bar for the classes that never use mana. By class, so it
-- holds for a druid in Cat or Bear Form; an unreadable class keeps the bar.
local NO_MANA = { WARRIOR = true, ROGUE = true }
local function WantsPower(f, previewClass)
    -- the plate always has its power bar (LayoutBars)
    if OnPlate(f) then return true end
    local st = TS(f)
    if not (st and (st.powerHeight or 0) > 0) then return false end
    if st.powerManaOnly and RaidTile(f) then
        local class = previewClass
        if not class and f.fuiUnit then
            local _, file = UnitClass(f.fuiUnit)
            if canaccessvalue(file) then class = file end
        end
        if class and NO_MANA[class] then return false end
    end
    return true
end

-- Power Text: the raid's (and raid-style tiles') default is None, the party's Value
local function TilePowerMode(f, st)
    if RaidTile(f) then
        local v = st and st.powerText
        return K.IsPowerTextMode(v) and v or "none"
    end
    return K.PowerTextMode(st and st.powerText)
end

local function UpdatePower(f, glide)
    local unit, st = f.fuiUnit, TS(f)
    local want = WantsPower(f)
    local appeared = want ~= f.powerShown
    if appeared then
        f.powerShown = want
        LayoutBars(f)
    end
    if not want then return end
    local bar = f.Power
    local powerType = UnitPowerType(unit)
    bar:SetMinMaxValues(0, UnitPowerMax(unit, powerType))
    ns.SetBarValue(bar, UnitPower(unit, powerType), glide and not appeared and st and st.smoothBars)
    bar:SetStatusBarColor(K.GetPowerColor(unit))
    -- kept for the ticks (UpdatePowerValue); a secret type always takes this full path
    f.powerType = canaccessvalue(powerType) and powerType or nil
    f.powerTextMode = nil
    local ptMode = st and TilePowerMode(f, st) or "none"
    if ptMode ~= "none" and UnitIsConnected(unit) and not K.IsDead(unit) then
        f.powerTextMode = ptMode
        K.SetPowerText(f.PowerText, unit, powerType, f.powerTextMode)
    else
        f.PowerText:SetText("")
    end
end

-- A power tick: only the value (and its text) moves. The type, colour, maximum and layout follow
-- UNIT_DISPLAYPOWER / UNIT_MAXPOWER and unit changes, which run UpdatePower.
local function UpdatePowerValue(f)
    local powerType = f.powerType
    if not powerType then UpdatePower(f, true) return end
    if not f.powerShown then return end
    local unit, st = f.fuiUnit, TS(f)
    ns.SetBarValue(f.Power, UnitPower(unit, powerType), st and st.smoothBars)
    if f.powerTextMode then K.SetPowerText(f.PowerText, unit, powerType, f.powerTextMode) end
end

-- Incoming heals and absorbs, clipped to the empty part of the health bar (as UnitFrames.lua)
local function UpdateHealPrediction(f)
    local heal, absorb = f.HealBar, f.AbsorbBar
    if not heal then return end
    local unit = f.fuiUnit
    local max = UnitHealthMax(unit)
    heal:SetMinMaxValues(0, max)
    absorb:SetMinMaxValues(0, max)
    K.SetOverAbsorb(f.OverAbsorb, unit, max)
    local calc = f.HealCalc
    if calc and UnitGetDetailedHealPrediction then
        if pcall(UnitGetDetailedHealPrediction, unit, "player", calc) then
            local okH, incoming = pcall(calc.GetIncomingHeals, calc)
            local okA, absorbs, clamped = pcall(calc.GetDamageAbsorbs, calc)
            if okH then heal:SetValue(incoming) end
            if okA then absorb:SetValue(absorbs) end
            if okA then K.SetShieldGlow(f.ShieldGlow, clamped) else K.HideShieldGlow(f.ShieldGlow) end
            return
        end
    end
    K.HideShieldGlow(f.ShieldGlow)
    pcall(function() heal:SetValue(UnitGetIncomingHeals(unit)) end)
    pcall(function() absorb:SetValue(UnitGetTotalAbsorbs(unit)) end)
end

-- GetRaidTargetIndex is secret to addon code; a secret is never nil, and the texture setter takes it
local function UpdateRaidIcon(f)
    local icon = f.RaidIcon
    if not IconShown("raidIcon", f) then icon:Hide() return end
    local index = GetRaidTargetIndex(f.fuiUnit)
    local show
    if not canaccessvalue(index) then show = true else show = index ~= nil and index > 0 end
    if show then SetRaidTargetIconTexture(icon, index) end
    icon:SetShown(show)
end

local function UpdateLeader(f)
    local icon = f.LeaderIcon
    if not IconShown("leader", f) then icon:Hide() return end
    if readable(UnitIsGroupLeader(f.fuiUnit)) then
        K.SetIconArt(icon, "UI-HUD-UnitFrame-Player-Group-LeaderIcon", "Interface\\GroupFrame\\UI-Group-LeaderIcon")
        icon:Show()
    elseif readable(UnitIsGroupAssistant(f.fuiUnit)) then
        K.SetIconArt(icon, nil, "Interface\\GroupFrame\\UI-Group-AssistantIcon")
        icon:Show()
    else
        icon:Hide()
    end
end

-- Blizzard's role icon routine (keeps a secret role secret), handed a stand-in frame; the plain
-- role lookup is the fallback
local function UpdateRole(f)
    local icon = f.RoleIcon
    if not IconShown("role", f) then icon:Hide() return end
    local util = _G.UnitFrameUtil and _G.UnitFrameUtil.UpdateUnitFrameRoleIcon
    if util then
        f.roleProxy = f.roleProxy or { optionTable = { displayRoleIcon = true } }
        f.roleProxy.roleIcon, f.roleProxy.unit = icon, f.fuiUnit
        if pcall(util, f.roleProxy) then return end
    end
    local role = readable(UnitGroupRolesAssigned(f.fuiUnit))
    local atlas = role and ROLE_ATLAS[role]
    if atlas and K.HasAtlas(atlas) then
        icon:SetAtlas(atlas, false)
        icon:Show()
    else
        icon:Hide()
    end
end

local function UpdateReadyCheck(f)
    local icon = f.ReadyIcon
    if not IconShown("readyCheck", f) then icon:Hide() return end
    -- the raid frames keep their own hold
    local hold = readyCheckHold
    if f.ctx then hold = f.ctx.ReadyHold() end
    local status = readable(GetReadyCheckStatus(f.fuiUnit))
    if not status and hold then status = f.lastReady end
    -- a member who never answered was not ready (Blizzard's CompactUnitFrame_FinishReadyCheck)
    if hold and status == "waiting" then status = "notready" end
    if status and READY_ATLAS[status] then
        if hold == nil then f.lastReady = status end
        icon:SetAtlas(READY_ATLAS[status], false)
        icon:Show()
    else
        icon:Hide()
    end
end

-- Far members often report a phase reason: as on Blizzard's raid frames, the phasing icon only
-- shows within 250 yards (a distance the client measured)
local function WithinPhaseDistance(unit)
    local distance, checked = UnitDistanceSquared(unit)
    return canaccessvalue(checked) and checked and canaccessvalue(distance) and distance < 62500 or false
end

local function CenterStatus(unit)
    if C_IncomingSummon and readable(C_IncomingSummon.HasIncomingSummon(unit)) then
        local status = readable(C_IncomingSummon.IncomingSummonStatus(unit))
        local SS = Enum.SummonStatus
        if SS and status == SS.Pending then return "IncomingSummonPending"
        elseif SS and status == SS.Accepted then return "IncomingSummonAccepted"
        elseif SS and status == SS.Declined then return "IncomingSummonDeclined" end
    end
    if readable(UnitHasIncomingResurrection(unit)) then return "IncomingResurrection" end
    if UnitPhaseReason and readable(UnitPhaseReason(unit)) and WithinPhaseDistance(unit) then return "InOtherPhase" end
    if UnitInOtherParty and readable(UnitInOtherParty(unit)) then return "InPublicGroup" end
    return nil
end

local function UpdateStatus(f)
    local icon = f.StatusIcon
    if not IconShown("status", f) then icon:Hide() return end
    local state = CenterStatus(f.fuiUnit)
    local atlas = state and STATUS_ATLAS[state]
    if atlas and K.HasAtlas(atlas) then
        icon:SetAtlas(atlas, false)
        icon:Show()
    else
        icon:Hide()
    end
end

-- A group member too far away to be visible comes with no aura durations: Hide Buffs drops until the
-- unit is near again (ns.AuraPolicy.UpdateReach). Enemy tiles keep it.
local function UpdateAuraReach(f)
    if not f.AuraPos or (f.ctx and f.ctx.hostile) then return end
    ns.AuraPolicy.UpdateReach(f, f.fuiUnit)
end

-- The resurrection spell you know, if any: Resurrection, Redemption, Ancestral Spirit, Rebirth
local RezSpell
do
    local ids = { 2006, 7328, 2008, 20484 }
    RezSpell = function()
        for _, id in ipairs(ids) do
            if C_SpellBook.IsSpellKnown(id, Enum.SpellBookSpellBank.Player) then return id end
        end
    end
end

-- Out of range fades the frame (UnitInRange is secret: SetAlphaFromBoolean picks the alpha). The
-- player's own frame never fades; enemy tiles (bosses) go by spell range, as the target frame.
local function UpdateRange(f)
    UpdateAuraReach(f)
    -- the phasing icon follows the distance, so it is checked with the range (enemy tiles have none)
    if f.StatusIcon and f.fuiUnit and not (f.ctx and f.ctx.hostile) and not IsEditing() then
        local near = WithinPhaseDistance(f.fuiUnit)
        if near ~= f.phaseNear then
            f.phaseNear = near
            UpdateStatus(f)
        end
    end
    -- Range Check off (rangeCheck in the frame's settings, on by default): always in full
    local st = TS(f)
    if st and st.rangeCheck == false then
        f:SetAlpha(1)
        return
    end
    if f.ctx and f.ctx.hostile and not IsEditing() and K.ApplyRangeAlpha then
        K.ApplyRangeAlpha(f, f.fuiUnit)
        return
    end
    -- raidN can be the player too
    if f.fuiUnit == "player" or (f.ctx and f.ctx.hostile) or IsEditing() or readable(UnitIsUnit(f.fuiUnit, "player")) then
        f:SetAlpha(1)
        return
    end
    -- a dead member: the range to their corpse, which is where a rez goes (the ghost may be far off),
    -- measured with your resurrection spell when you have one
    if K.IsDead(f.fuiUnit) then
        local rez = RezSpell()
        local r = rez and C_Spell.IsSpellInRange(rez, f.fuiUnit)
        if not canaccessvalue(r) then
            if f.SetAlphaFromBoolean and pcall(f.SetAlphaFromBoolean, f, r, 1, RANGE_ALPHA) then return end
        elseif r ~= nil then
            f:SetAlpha(r and 1 or RANGE_ALPHA)
            return
        end
    end
    -- a range the client could not check is not out of range (as Blizzard's raid frames)
    local inRange, checkedRange = UnitInRange(f.fuiUnit)
    if readable(checkedRange) == false then
        f:SetAlpha(1)
        return
    end
    if f.SetAlphaFromBoolean then
        if not pcall(f.SetAlphaFromBoolean, f, inRange, 1, RANGE_ALPHA) then f:SetAlpha(1) end
    elseif canaccessvalue(inRange) then
        f:SetAlpha(inRange and 1 or RANGE_ALPHA)
    end
end

-- The player's target: a brighter border
local function UpdateTarget(f)
    local hl = f.TargetHighlight
    -- the border's bright copy, or on the plate the name box's glow (the frame's alpha drives both)
    local plate = OnPlate(f) and f.PlateFrame and f.PlateFrame.Strip
    hl.Border:SetShown(not plate)
    if plate then
        if not hl.PlateGlow then
            hl.PlateGlow = hl:CreateTexture(nil, "OVERLAY")
            hl.PlateGlow:SetBlendMode("ADD")
        end
        pcall(hl.PlateGlow.SetAtlas, hl.PlateGlow, ns.UFRing.STRIP_ATLAS, false)
        hl.PlateGlow:SetVertexColor(1, 1, 1, 0.9)
        hl.PlateGlow:ClearAllPoints()
        hl.PlateGlow:SetAllPoints(plate)
        hl.PlateGlow:Show()
    elseif hl.PlateGlow then
        hl.PlateGlow:Hide()
    end
    if IsEditing() then hl:SetAlpha(0) return end
    local isTarget = UnitIsUnit(f.fuiUnit, "target")
    if hl.SetAlphaFromBoolean then
        if not pcall(hl.SetAlphaFromBoolean, hl, isTarget, 1, 0) then hl:SetAlpha(0) end
    else
        hl:SetAlpha(readable(isTarget) and 1 or 0)
    end
end

-- Aggro: the border takes the threat colour (on an enemy tile: the player's threat on that enemy)
local function UpdateThreat(f)
    local status
    if f.ctx and f.ctx.hostile then
        status = readable(UnitThreatSituation("player", f.fuiUnit))
    else
        status = readable(UnitThreatSituation(f.fuiUnit))
    end
    -- Forever Style's plate has no border: the ring flashes instead
    if OnPlate(f) then
        K.ResetBorderTint(f.Border)
        ns.UFRing.UpdateThreat(f)
        return
    end
    if status and status >= 1 and not IsEditing() then
        K.SetBorderTint(f.Border, K.ThreatColor(status))
    else
        K.ResetBorderTint(f.Border)
    end
end

local function UpdatePortrait(f)
    local portrait = f.Portrait
    local st = TS(f)
    local mode = (not RaidTile(f) and st and st.portrait) or "none"
    -- the ring always holds a portrait
    if f.ringKind and mode == "none" then mode = "3d" end
    if mode == "none" then portrait:Hide() return end
    local unit = (UnitExists(f.fuiUnit) and not IsEditing()) and f.fuiUnit or "player"
    local tex = portrait.Tex
    local class
    if mode == "class" then
        local isPlayer = UnitIsPlayer(unit)
        if canaccessvalue(isPlayer) and isPlayer then
            local _, classFile = UnitClass(unit)
            if canaccessvalue(classFile) then class = classFile end
        end
        if IsEditing() and f.preview and f.preview.class then class = f.preview.class end
    end
    if class then
        tex:SetAtlas(GetClassAtlas(class), false, nil, true)
    elseif IsEditing() and f.preview and f.preview.portrait then
        tex:SetTexture(f.preview.portrait)
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    else
        SetPortraitTexture(tex, unit, true)
        tex:SetTexCoord(0, 1, 0, 1)
    end
    portrait:Show()
end

local function UpdateCast(f, event, by, barID)
    if not f.Cast then return end
    -- a settings preview's sample has no unit: the Edit Mode sample cast
    -- (a settings preview's sample shows the frame only)
    if f.fuiSample then f.Cast:Hide() return end
    K.UpdateCastBar(f.Cast, f.Cast.isEnabled(), event, by, barID)
end

local ApplyPreview, HidePreviewExtras   -- section 9

-- the ring's extras (elite art, level skull)
local function UpdateRing(f)
    if f.ringKind and ns.UFRing then ns.UFRing.Update(f) end
end

-- Aura containers only follow UNIT_AURA for their token: when another unit takes it (roster change,
-- new boss1) the old auras would linger. Rebuild on a new GUID (always when it is secret).
local function RefreshAurasOnNewUnit(f)
    if f.AuraPos or f.AuraHighlight then ns.AuraPolicy.UnitChanged(f, f.fuiUnit, true) end
end

local function UpdateAll(f)
    -- (a settings preview's sample always shows the Edit Mode values)
    -- (a sample is drawn only once laid out: its OnShow can come first)
    if f.fuiSample and not f.fuiLaid then return end
    if IsEditing() or f.fuiSample then
        ApplyPreview(f)
        UpdateRing(f)
        return
    end
    HidePreviewExtras(f)
    if not UnitExists(f.fuiUnit) then return end
    RefreshAurasOnNewUnit(f)
    UpdateName(f)
    UpdateLevel(f)
    UpdateHealth(f)
    UpdatePower(f)
    UpdateHealPrediction(f)
    UpdateRaidIcon(f)
    UpdateLeader(f)
    UpdateRole(f)
    UpdateReadyCheck(f)
    UpdateStatus(f)
    UpdateRange(f)
    UpdateTarget(f)
    UpdateThreat(f)
    UpdatePortrait(f)
    UpdateCast(f)
    UpdateRing(f)
end

local function UpdatePet(p, glide)
    UpdateRange(p)   -- out of range fades it, as the members (full in Edit Mode)
    if IsEditing() then return end
    if not UnitExists(p.fuiUnit) then return end
    local unit = p.fuiUnit
    p.Health:SetMinMaxValues(0, UnitHealthMax(unit))
    local st = TS(p)
    ns.SetBarValue(p.Health, UnitHealth(unit), glide and st and st.smoothBars and not UnitIsDead(unit))
    p.Health:SetStatusBarColor(K.GetHealthColor(unit, false))
    p.Name:SetText(SafeName(ns.UnitDisplayName(unit)))
end

local function UpdatePartyTarget(t)
    if IsEditing() then return end
    local unit = t.fuiUnit
    if not UnitExists(unit) then return end
    t.Health:SetMinMaxValues(0, UnitHealthMax(unit))
    t.Health:SetValue(UnitHealth(unit))
    t.Health:SetStatusBarColor(K.GetHealthColor(unit, ns.ClassColorsOn(TS(t))))
    t.Name:SetText(SafeName(ns.UnitDisplayName(unit, "party")))
end

-- Health and heal prediction are drawn at most once per frame per tile: in a raid one unit can get
-- several health, heal and absorb events in a frame (Blizzard's raid frames batch them the same way).
-- The flush runs in OnUpdate, before the frame is drawn, and only while something waits.
-- dirty[f]: 1 heal prediction only, 2 health with glide, 3 health without glide (the colour too);
-- health is always followed by the prediction (its amounts are clamped by the health missing)
local dirty, flushing = {}, {}
local flusher = CreateFrame("Frame")
local function FlushTiles(self)
    self:SetScript("OnUpdate", nil)
    dirty, flushing = flushing, dirty
    for f, level in pairs(flushing) do
        if f.fuiUnit and f:IsVisible() and not IsEditing() then
            if level >= 2 then
                UpdateHealth(f, level == 2)
                -- death and release come as health ticks: the power text blanks (or returns) with them
                local dead = K.IsDead(f.fuiUnit)
                if dead ~= f.wasDead then
                    f.wasDead = dead
                    UpdatePower(f)
                end
            end
            UpdateHealPrediction(f)
        end
    end
    wipe(flushing)
end
local function MarkDirty(f, level)
    local old = dirty[f]
    if not old then
        if not next(dirty) then flusher:SetScript("OnUpdate", FlushTiles) end
        dirty[f] = level
    elseif level > old then
        dirty[f] = level
    end
end

local function OnMemberEvent(f, event, _, _, _, by, barID)
    -- hidden (solo or in a raid, the holder is): OnShow runs UpdateAll when it comes back
    if IsEditing() or not f:IsVisible() then return end
    if event == "UNIT_HEALTH" then
        MarkDirty(f, 2)
    elseif event == "UNIT_MAXHEALTH" then
        MarkDirty(f, 3)
    elseif event == "UNIT_POWER_UPDATE" then
        UpdatePowerValue(f)
    elseif event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
        UpdatePower(f, event ~= "UNIT_DISPLAYPOWER")
    elseif event == "UNIT_HEAL_PREDICTION" or event == "UNIT_ABSORB_AMOUNT_CHANGED" then
        MarkDirty(f, 1)
    elseif event == "UNIT_NAME_UPDATE" then
        UpdateName(f)
        MarkDirty(f, 3)   -- a far member's class comes with its name: the health colour follows
    elseif event == "UNIT_LEVEL" then
        UpdateLevel(f)
    elseif event == "UNIT_IN_RANGE_UPDATE" then
        UpdateRange(f)
    elseif event == "UNIT_THREAT_SITUATION_UPDATE" or event == "UNIT_THREAT_LIST_UPDATE" then
        UpdateThreat(f)
    elseif event == "UNIT_PHASE" or event == "UNIT_OTHER_PARTY_CHANGED" then
        UpdateStatus(f)
    elseif event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED" then
        UpdatePortrait(f)
    elseif event:find("^UNIT_SPELLCAST") then
        UpdateCast(f, event, by, barID)
    elseif event == "UNIT_FLAGS" then
        -- every member fires it entering and leaving combat: one batched health repaint (the colour
        -- for charm and tapped, Dead and Ghost with the power text after it)
        MarkDirty(f, 3)
    elseif event == "UNIT_FACTION" or event == "UNIT_CONNECTION" then
        -- no aura rebuild for these
        UpdateHealth(f)
        UpdatePower(f)
        UpdateStatus(f)
        UpdateLevel(f)
        UpdateRing(f)
        -- no range event comes for a disconnect or a return
        if event == "UNIT_CONNECTION" then UpdateRange(f) end
    else
        UpdateAll(f)
    end
end

--------------------------------------------------
-- 5. AURAS
-- Blizzard's aura containers render everything (aura data can be secret): one per place, plus the
-- dispel highlight slot. What each place shows, and on which policy, comes from ns.AuraPolicy.
--------------------------------------------------
local auraSupport
local function HasAuraSupport()
    if auraSupport == nil then auraSupport = K.HasAuraSupport() and true or false end
    return auraSupport
end

local function PrecreateAuraContainers(f)
    if not HasAuraSupport() then return end
    f.AuraPos = {}
    local policy = _G.CustomAuraContainerAuraProcessingPolicy
    -- a tile may use fewer places (f.auraPositions: the raid frames keep theirs inside)
    for _, pos in ipairs(f.auraPositions or AURA_POSITIONS) do
        local ok, container = pcall(CreateFrame, "AuraContainer", nil, f, AURA_CONTAINER_TEMPLATE)
        if ok and container then
            pcall(container.SetUnit, container, f.fuiUnit or "none")
            if policy then pcall(container.SetAuraProcessingPolicy, container, policy.ProcessAura, {}) end
            container:SetFrameLevel(f:GetFrameLevel() + 6)
            container:Hide()
            f.AuraPos[pos] = { container = container, policy = "process" }
        end
    end
    -- the dispel highlight, kept out of Edit Mode's sample data (ApplyPreview draws its own)
    local okH, hl = pcall(CreateFrame, "AuraContainer", nil, f, AURA_CONTAINER_TEMPLATE)
    if okH and hl then
        pcall(hl.SetUnit, hl, f.fuiUnit or "none")
        hl:SetSize(1, 1)
        hl:SetPoint("CENTER", f, "CENTER")
        hl:SetFrameLevel(f:GetFrameLevel() + 3)
        f.AuraHighlight = { container = hl, keys = {}, generation = 0 }
    end
end

-- Aura buttons inside the frame pass clicks through to it and keep their tooltip
local function PassClicks(button)
    if button.SetPropagateMouseClicks then pcall(button.SetPropagateMouseClicks, button, true) end
end

-- Party and raid tiles' aura tooltips: Tooltips > On Party/Raid Auras (tooltips.visibility.groupAuras).
-- Never (the default): hovering an icon falls through to the tile (its unit tooltip, mouseover
-- healing). Always: the icons take the mouse. Hide in Combat: only out of a fight, switched as one
-- starts (PLAYER_REGEN_DISABLED, the last moment before lockdown) and ends, so mouseover healing
-- works in it. Clicks reach the tile either way. Boss tiles keep theirs. (11-11, a player's request)
local groupAuraButtons = setmetatable({}, { __mode = "k" })
local inFight = false
local function GroupAuraMouse()
    local db = ns.db and ns.db.profile and ns.db.profile.tooltips
    local mode = db and db.enabled and db.visibility and db.visibility.groupAuras or "never"
    return mode == "always" or (mode == "combat" and not inFight)
end

local function NoAuraTooltip(f, button)
    if f and f.ctx and f.ctx.hostile then return end
    groupAuraButtons[button] = true
    if button.SetMouseMotionEnabled then pcall(button.SetMouseMotionEnabled, button, GroupAuraMouse()) end
end

function PF.ApplyAuraMouse()
    local on = GroupAuraMouse()
    for button in pairs(groupAuraButtons) do
        if button.SetMouseMotionEnabled then pcall(button.SetMouseMotionEnabled, button, on) end
    end
end

do
    local fight = CreateFrame("Frame")
    fight:RegisterEvent("PLAYER_REGEN_DISABLED")
    fight:RegisterEvent("PLAYER_REGEN_ENABLED")
    fight:SetScript("OnEvent", function(_, event)
        inFight = event == "PLAYER_REGEN_DISABLED"
        if next(groupAuraButtons) then PF.ApplyAuraMouse() end
    end)
end

-- A dispel type's symbol, drawn by Blizzard from the aura
local function InitDispelIcon(button, size, inside)
    button:SetSize(size, size)
    if not button.FlareUI_DispelIcon then
        button.FlareUI_DispelIcon = button:CreateTexture(nil, "ARTWORK")
        button.FlareUI_DispelIcon:SetAllPoints()
    end
    pcall(button.ClearDispelTypeTextures, button)
    local styles = Enum.CustomAuraButtonDispelTypeTextureStyle
    if styles then
        pcall(button.AddDispelTypeTexture, button, button.FlareUI_DispelIcon, {
            style = styles.Icon, showWhenHarmful = true, showWhenHelpful = false,
        })
    end
    if inside then PassClicks(button) end
    NoAuraTooltip(nil, button)   -- (dispel icons: party and raid tiles only)
end

-- inside the frame: no timer, whatever the Aura Timer setting (it would cover the bars and names)
local function LaneLook(size, isDebuff, inside)
    local timer = inside and "none" or UFAura("auraTimer", "none")
    return ns.AuraLook and ns.AuraLook.ForUnit(size, isDebuff, false, UFAura("auraStyle", "square"), "both", timer)
end

-- Where a place's auras start and which way they grow
local SIDE_GAP = 4   -- beside the frame
local EDGE_GAP = K and K.AURA_GAP or 2   -- above and below it, as on the unit frames
local function AuraAnchor(f, pos)
    local gap, inset = SIDE_GAP, 2
    if EDGE_PLACES[pos] then gap = EDGE_GAP end
    local health = f.Health
    local H = AnchorUtil.FlowDirection
    local point, rel, relPoint, x, y, growH, growV
    if pos == "RIGHT" then
        point, rel, relPoint, x, y, growH, growV = "TOPLEFT", f, "TOPRIGHT", gap, -K.INSET, H.Right, H.Down
    elseif pos == "LEFT" then
        point, rel, relPoint, x, y, growH, growV = "TOPRIGHT", f, "TOPLEFT", -gap, -K.INSET, H.Left, H.Down
    elseif pos == "ABOVE" then
        point, rel, relPoint, x, y, growH, growV = "BOTTOMLEFT", f, "TOPLEFT", K.INSET + RingClear(f, true, gap), gap, H.Right, H.Up
    elseif pos == "ABOVE_RIGHT" then
        point, rel, relPoint, x, y, growH, growV = "BOTTOMRIGHT", f, "TOPRIGHT", -K.INSET - RingClear(f, false, gap), gap, H.Left, H.Up
    elseif pos == "ABOVE_WIDE" then
        -- the whole width, from the left (past the ring when it is on the left)
        point, rel, relPoint, x, y, growH, growV = "BOTTOMLEFT", f, "TOPLEFT", K.INSET + RingClear(f, true, gap), gap, H.Right, H.Up
    elseif pos == "BELOW" or pos == "BELOW_RIGHT" or pos == "BELOW_WIDE" then
        -- under the frame, pushed below the cast bar while it shows
        local below = gap
        if f.Cast and f.Cast:IsShown() and f.Cast.isEnabled() then
            local st = TS(f)
            -- the cast bar's gap from the frame, the bar, and the same gap again before the auras
            below = (st.castHeight or 16) + 2 * K.CAST_GAP
        end
        if pos == "BELOW_RIGHT" then
            point, rel, relPoint, x, y, growH, growV = "TOPRIGHT", f, "BOTTOMRIGHT", -K.INSET - RingClear(f, false, below), -below, H.Left, H.Down
        else
            point, rel, relPoint, x, y, growH, growV = "TOPLEFT", f, "BOTTOMLEFT", K.INSET + RingClear(f, true, below), -below, H.Right, H.Down
        end
    elseif pos == "INSIDE_TOP" then
        point, rel, relPoint, x, y, growH, growV = "TOPLEFT", health, "TOPLEFT", inset, -inset, H.Right, H.Down
    elseif pos == "INSIDE_BOTTOM" then
        point, rel, relPoint, x, y, growH, growV = "BOTTOMLEFT", health, "BOTTOMLEFT", inset, inset, H.Right, H.Up
    elseif pos == "INSIDE_CENTER" or pos == "INSIDE_LEFT" then
        -- the middle row: from the left, across (or along the left side's middle)
        point, rel, relPoint, x, y, growH, growV = "LEFT", health, "LEFT", inset, 0, H.Right, H.Down
    elseif pos == "INSIDE_RIGHT" then
        point, rel, relPoint, x, y, growH, growV = "RIGHT", health, "RIGHT", -inset, 0, H.Left, H.Down
    elseif pos == "INSIDE_TOPLEFT" then
        point, rel, relPoint, x, y, growH, growV = "TOPLEFT", health, "TOPLEFT", inset, -inset, H.Right, H.Down
    elseif pos == "INSIDE_TOPRIGHT" then
        point, rel, relPoint, x, y, growH, growV = "TOPRIGHT", health, "TOPRIGHT", -inset, -inset, H.Left, H.Down
    elseif pos == "INSIDE_BOTTOMLEFT" then
        point, rel, relPoint, x, y, growH, growV = "BOTTOMLEFT", health, "BOTTOMLEFT", inset, inset, H.Right, H.Up
    elseif pos == "PORTRAIT" then
        -- the dispel grid, centred on the portrait: from its top-left, two to a row
        local _, whole = DispelGrid(f)
        point, rel, relPoint, x, y, growH, growV = "TOPLEFT", PortraitCentre(f), "CENTER", -whole / 2, whole / 2, H.Right, H.Down
    else -- INSIDE_BOTTOMRIGHT
        point, rel, relPoint, x, y, growH, growV = "BOTTOMRIGHT", health, "BOTTOMRIGHT", -inset, inset, H.Left, H.Up
    end
    return point, rel, relPoint, x, y, growH, growV
end

-- Anchors a container at its place and sets its flow
local function PlaceAuraContainer(f, pos, container, size, perRow)
    local point, rel, relPoint, x, y, growH, growV = AuraAnchor(f, pos)
    -- a middle place: the container hangs on its side's middle and the row flows from its top
    local flowAnchor, V = point, growV
    if point == "LEFT" or point == "RIGHT" then flowAnchor = "TOP" .. point end
    container:ClearAllPoints()
    container:SetPoint(point, rel, relPoint, x, y)
    local lineSize = perRow * (size + AURA_SPACING)
    pcall(container.SetFlowLayoutAxis, container, AnchorUtil.FlowLayoutAxis.Horizontal)
    pcall(container.SetFlowLayoutAnchorPoint, container, flowAnchor)
    pcall(container.SetFlowLayoutGrowthDirection, container, growH, V)
    pcall(container.SetFlowLayoutMaximumLineSize, container, lineSize)
    pcall(container.SetFlowLayoutPadding, container, 0, 0, 0, 0)
end

-- Dispel icons alone in their place: one icon per type you can dispel, as Forever's raid frames show
-- them (a group repeats a type, and three Magic debuffs push the Poison symbol out). A slot per type,
-- one button each, filtered by type in Blizzard's code (the type is never read here), in a fixed cell
-- each in the order Magic, Curse, Disease, Poison. No class dispels more than three types. Edit Mode
-- keeps the group: slots get no sample icons.
local DISPEL_SLOT_TYPES = {
    PRIEST = { "Magic", "Disease" }, PALADIN = { "Magic", "Disease", "Poison" }, SHAMAN = { "Disease", "Poison" },
    DRUID = { "Curse", "Poison" }, MAGE = { "Curse" }, WARLOCK = { "Magic" },
}

local function DisableDispelSlots(container, entry)
    for key in pairs(entry.dispelSlots or {}) do pcall(container.SetAuraSlotEnabled, container, key, false) end
end

-- true when the place shows as slots (its groups then step aside)
local function ConfigureDispelSlots(f, pos, entry, container, lanes, size, perRow, inside)
    local lane = lanes[1]
    local processed = AuraUtil and AuraUtil.AuraUpdateChangedType
    local _, class = UnitClass("player")
    local types = DISPEL_SLOT_TYPES[class]
    if #lanes ~= 1 or lane.kind ~= "dispels" or IsEditing() or not types or not processed or not container.AddAuraSlot then
        DisableDispelSlots(container, entry)
        return false
    end
    ns.AuraGroups.Finish(container, entry)
    entry.dispelSlots = entry.dispelSlots or {}
    local point, _, _, _, _, growH, growV = AuraAnchor(f, pos)
    -- the cells grow from where the container meets its place (its own size doesn't matter then)
    local corner = (point == "LEFT" or point == "RIGHT") and ("TOP" .. point) or point
    local sx = growH == AnchorUtil.FlowDirection.Left and -1 or 1
    local sy = growV == AnchorUtil.FlowDirection.Up and 1 or -1
    local step = size + AURA_SPACING
    local used = {}
    for i, dtype in ipairs(types) do
        local key = "dispel" .. dtype
        used[key] = true
        local button = entry.dispelSlots[key]
        if button then
            pcall(container.SetAuraSlotEnabled, container, key, true)
            pcall(InitDispelIcon, button, size, inside)
        else
            local ok, frame = pcall(container.AddAuraSlot, container, key, lane.filter, {
                candidateFilters = { processedAuraType = processed.Dispel, includeDispelTypes = { [dtype] = true } },
                initializeFrame = function(b) InitDispelIcon(b, size, inside) end,
            })
            if ok and frame then
                entry.dispelSlots[key] = frame
                button = frame
            end
        end
        if button then
            local col, row = (i - 1) % perRow, math_floor((i - 1) / perRow)
            pcall(function()
                button:ClearAllPoints()
                button:SetPoint(corner, container, point, sx * col * step, sy * row * step)
            end)
        end
    end
    for key in pairs(entry.dispelSlots) do
        if not used[key] then pcall(container.SetAuraSlotEnabled, container, key, false) end
    end
    return true
end

local function ConfigurePosition(f, pos, lanes)
    local entry = f.AuraPos and f.AuraPos[pos]
    if not entry then return end
    local container = entry.container
    -- groups are reused per lane and look (ns.AuraGroups); the lanes left out turn off
    ns.AuraGroups.Begin(entry)
    if #lanes == 0 then
        DisableDispelSlots(container, entry)
        ns.AuraGroups.Finish(container, entry)
        pcall(container.SetEnabled, container, false)
        container:Hide()
        return
    end

    local st = TS(f)
    local db = K.GetDb()
    local portrait = pos == "PORTRAIT"
    local size = portrait and DispelGrid(f) or PlaceAuraSize(st, pos)
    local max, perRow = AuraFit(st, pos, f)
    if portrait then max, perRow = 4, 2 end
    local inside = portrait or pos:find("^INSIDE") ~= nil
    local showTimer = not inside and UFAura("auraTimer", "none") ~= "none"
    local font = db and db.font
    local unit = f.fuiUnit
    -- Aura Ordering: the buffs and debuffs rows (dispel icons keep Blizzard's)
    local order = TS(f)
    local sortMethod, sortDirection = ns.AuraOrder.Options(order and order.auraSort, order and order.auraReverse, order and order.auraMineFirst)
    local slotted = ConfigureDispelSlots(f, pos, entry, container, lanes, size, perRow, inside)
    for index, lane in ipairs(slotted and {} or lanes) do
        local isDebuff, kind = lane.isDebuff, lane.kind
        local sorted = lane.key == "buffs" or lane.key == "debuffs" or lane.key == "purge"
        -- each kind at its own size (the portrait grid keeps its cell)
        local size = portrait and size or ns.AuraSize(st, isDebuff, 18)
        local look = kind ~= "dispels" and LaneLook(size, isDebuff, inside) or nil
        if look and lane.stealable then look.stealable = true end   -- Highlight Purgeable Buffs (boss tiles)
        local lookSig = ns.AuraGroups.Sig(kind, size, isDebuff, inside, font, showTimer, look)
        local key, err = ns.AuraGroups.Add(container, entry, lane.key, lookSig, lane.filter, {
            maxFrameCount = kind == "dispels" and not portrait and math_min(max, 3) or max,
            candidateFilters = lane.candidates,
            sortMethod = sorted and sortMethod or nil, sortDirection = sorted and sortDirection or nil,
            initializeFrame = function(button)
                if kind == "dispels" then
                    InitDispelIcon(button, size, inside)
                else
                    K.InitAuraButton(button, size, isDebuff, unit, font, showTimer, look)
                    if inside then PassClicks(button) end
                    NoAuraTooltip(f, button)
                end
            end,
            layout = {
                elementWidth = size, elementHeight = look and look.cellHeight or size,
                elementSpacing = AURA_SPACING, lineSpacing = AURA_SPACING,
                groupSpacing = AURA_SPACING, groupLineSpacing = AURA_SPACING,
                layoutIndex = index,
                -- each kind starts a row of its own
                forceNewLine = index > 1 and not lane.joinPrevious,
            },
        })
        if not key then
            geterrorhandler()(err)
        else
            ns.AuraPolicy.Track(f, container, key, lane)
        end
    end
    ns.AuraGroups.Finish(container, entry)
    PlaceAuraContainer(f, pos, container, size, perRow)
    container:SetFrameLevel(f:GetFrameLevel() + 6)
    -- the portrait's grid: over it and under the ready check (the ring's icons: +11)
    if portrait then container:SetFrameLevel(f:GetFrameLevel() + (f.ringKind and 10 or 7)) end
    pcall(container.SetEnabled, container, true)
    pcall(container.SetEditModePreviewEnabled, container, IsEditing())
    container:Show()
    pcall(container.UpdateAllAuras, container)
end

-- Rebuilding creates new aura groups, so only when the settings that shape them change (signature)
local function Signature(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
    return table.concat(parts, "|")
end

local function ConfigureAuras(f)
    if not f.AuraPos then return end
    local st = TS(f)
    if not st then return end
    -- what each lane shows, and on which rules, comes from ns.AuraPolicy (debuffs first, nearest the
    -- frame); the places and sizes are this module's
    local hostile = f.ctx and f.ctx.hostile or false
    local lanes = ns.AuraPolicy.TileLanes(st, { hostile = hostile, dispelPlace = DispelPlace(f, st), editing = IsEditing() })
    -- rebuilt only when what shapes the groups changes: the places and sizes, plus the lanes and a
    -- look as computed, so a new aura rule or look setting can't be missed here
    local sig = Signature(st.debuffs, st.buffs, st.dispels, st.auraSize, st.buffSize, st.debuffSize, st.width, st.height, st.powerHeight, st.portrait, st.ringSize, (DispelGrid(f)), f.ringKind, AuraGrid(st),
        ns.AuraGroups.Sig(UFAura("font")), st.castbar, st.castHeight, OnPlate(f), IsEditing(), st.auraSort, st.auraReverse, st.auraMineFirst,
        ns.AuraGroups.Sig(lanes), ns.AuraGroups.Sig(LaneLook(10, false, false)))
    if f.auraSignature == sig then return end
    f.auraSignature = sig
    local perPos = {}
    for _, pos in ipairs(AURA_POSITIONS) do perPos[pos] = {} end
    -- (on the plate the bars are too slim for auras: an inside place shows nothing)
    local plate = OnPlate(f)
    for _, lane in ipairs(lanes) do
        local pos = lane.place
        if pos and perPos[pos] and not (plate and IsInsidePlace(pos)) then perPos[pos][#perPos[pos] + 1] = lane end
    end
    -- the processing policy is per container: set before its groups are built
    for _, pos in ipairs(AURA_POSITIONS) do
        local rec, placeLanes = f.AuraPos[pos], perPos[pos]
        if rec and #placeLanes > 0 then
            local policy = ns.AuraPolicy.PlacePolicy(placeLanes)
            if rec.policy ~= policy then
                rec.policy = policy
                ns.AuraPolicy.ApplyPolicy(rec.container, policy)
            end
        end
    end
    ns.AuraPolicy.Begin(f)
    for _, pos in ipairs(AURA_POSITIONS) do ConfigurePosition(f, pos, perPos[pos]) end
    -- the groups were just given their filters: reach applies on top (enemy tiles: never)
    if not hostile then ns.AuraPolicy.Done(f, f.fuiUnit) end
end

-- The dispel highlight: a slot in its own container, showing the first aura of its filter (never given
-- Edit Mode's sample data)
local function ConfigureDispelHighlight(f)
    local hlEntry = f.AuraHighlight
    if not hlEntry then return end
    local st = TS(f)
    local plate = OnPlate(f)
    -- (border and short heights: the highlight copies the backdrop once, and its edge shrinks under 22)
    local sig = Signature(st.dispelHighlight, plate, K.Border(st.border), (st.height and st.height < 22 and st.height or 22))
    if hlEntry.signature == sig then return end
    hlEntry.signature = sig
    local hlContainer = hlEntry.container
    -- slots can't be removed and their button is styled once: one slot per look, reused when that
    -- look comes back; the filter (mine / all) changes in place
    for _, key in pairs(hlEntry.keys) do pcall(hlContainer.SetAuraSlotEnabled, hlContainer, key, false) end
    local highlight = st.dispelHighlight or "mine"
    local styles = Enum.CustomAuraButtonDispelTypeTextureStyle
    local lookSig = Signature(plate, K.Border(st.border), (st.height and st.height < 22 and st.height or 22))
    if highlight ~= "off" and styles then
        local filter = highlight == "all" and "HARMFUL|RAID_PLAYER_DISPELLABLE" or "HARMFUL|RAID"
        local reused = hlEntry.keys[lookSig]
        if reused then
            pcall(hlContainer.SetAuraSlotFilterString, hlContainer, reused, filter)
            pcall(hlContainer.SetAuraSlotEnabled, hlContainer, reused, true)
        end
        hlEntry.generation = hlEntry.generation + 1
        local key = "dispelhl" .. hlEntry.generation
        local ok = not reused and pcall(hlContainer.AddAuraSlot, hlContainer, key, filter, {
            -- a copy of the frame's border just over it: Blizzard shows and tints its pieces for a
            -- dispellable debuff (the type may be secret)
            initializeFrame = function(button)
                button:ClearAllPoints()
                if button.EnableMouse then pcall(button.EnableMouse, button, false) end
                -- Forever Style's plate: the name box's glow, in the debuff type's colour
                local strip = plate and f.PlateFrame and f.PlateFrame.Strip
                if strip then
                    button:SetAllPoints(strip)
                    button:SetFrameLevel(f.PlateFrame:GetFrameLevel() + 2)
                    local glow = button.FlareUI_HighlightStrip
                    if not glow then
                        glow = button:CreateTexture(nil, "OVERLAY")
                        glow:SetAllPoints(button)
                        button.FlareUI_HighlightStrip = glow
                    end
                    pcall(glow.SetAtlas, glow, ns.UFRing.STRIP_ATLAS, false)
                    if button.FlareUI_HighlightBorder then button.FlareUI_HighlightBorder:Hide() end
                    pcall(button.ClearDispelTypeTextures, button)
                    glow:Hide()   -- until Blizzard shows it for a dispellable debuff
                    pcall(button.AddDispelTypeTexture, button, glow, {
                        style = styles.PreserveAsset, showWhenHarmful = true, showWhenHelpful = false,
                    })
                    return
                end
                if button.FlareUI_HighlightStrip then button.FlareUI_HighlightStrip:Hide() end
                button:SetAllPoints(f.Border)
                button:SetFrameLevel(f.Border:GetFrameLevel() + 1)
                local ring = button.FlareUI_HighlightBorder
                if not ring then
                    ring = CreateFrame("Frame", nil, button, "BackdropTemplate")
                    ring:SetAllPoints(button)
                    button.FlareUI_HighlightBorder = ring
                end
                ring:SetBackdrop(f.Border:GetBackdrop())
                pcall(button.ClearDispelTypeTextures, button)
                for _, region in ipairs({ ring:GetRegions() }) do
                    if region:IsObjectType("Texture") then
                        region:Hide()   -- until Blizzard shows it for a dispellable debuff
                        pcall(button.AddDispelTypeTexture, button, region, {
                            style = styles.PreserveAsset, showWhenHarmful = true, showWhenHelpful = false,
                        })
                    end
                end
            end,
        })
        if ok then hlEntry.keys[lookSig] = key end
    end
    hlContainer:Show()
    pcall(hlContainer.SetEditModePreviewEnabled, hlContainer, false)
    pcall(hlContainer.UpdateAllAuras, hlContainer)
end

local function SetAuraPreview(enabled)
    for i = 0, MAX_MEMBERS do
        local f = members[i]
        if f then
            if f.AuraPos then
                for _, entry in pairs(f.AuraPos) do pcall(entry.container.SetEditModePreviewEnabled, entry.container, enabled) end
            end
        end
    end
end

--------------------------------------------------
-- 6. LAYOUT
--------------------------------------------------
local function PortraitSpace(f)
    local st = TS(f)
    -- (the ring's portrait stands beside the bars, over the frame's end)
    if RaidTile(f) or f.ringKind or not st or (st.portrait or "none") == "none" then return 0 end
    return (st.height or 46) - 2 * K.INSET
end

LayoutBars = function(f)
    local st = TS(f)
    if not st then return end
    if OnPlate(f) then
        -- the bars in the plate's slots, the ring beside it (UnitFramesRing.lua), the power bar always
        local mirrored = Mirrored(f, true)
        f.Health:SetReverseFill(mirrored)
        f.Power:SetReverseFill(mirrored)
        f.Separator:Hide()
        if f.PortraitDivider then f.PortraitDivider:Hide() end
        ns.UFRing.LayoutPlate(f)
        f.Power:Show()
        f.PowerText:SetShown(TilePowerMode(f, st) ~= "none")
        return
    end
    local PADDING = K.INSET
    local health, power = f.Health, f.Power
    local space = PortraitSpace(f)
    local left = PADDING + space
    local powerHeight = st.powerHeight or 0
    local showPower = f.powerShown ~= false and powerHeight > 0
    if f.powerShown == nil then showPower = WantsPower(f) end

    -- near: the portrait's side (left, or right on a mirrored tile)
    local near, far, sx = Sides(f)
    health:ClearAllPoints()
    power:ClearAllPoints()
    health:SetPoint("TOP" .. near, f, "TOP" .. near, sx * left, -PADDING)
    health:SetReverseFill(Mirrored(f, true))
    power:SetReverseFill(Mirrored(f, true))

    local portrait, divider = f.Portrait, f.PortraitDivider
    -- the ring places its own portrait
    if not f.ringKind then portrait:ClearAllPoints() end
    divider:ClearAllPoints()
    if space > 0 then
        portrait:SetSize(space, space)
        portrait:SetPoint("TOP" .. near, f, "TOP" .. near, sx * PADDING, -PADDING)
        divider:SetPoint("TOP", portrait, "TOP" .. far, 0, 0)
        divider:SetPoint("BOTTOM", portrait, "BOTTOM" .. far, 0, 0)
        divider:SetWidth(K.SEPARATOR_HEIGHT)
        divider:Show()
    else
        divider:Hide()
        if not f.ringKind then portrait:Hide() end
    end

    if showPower then
        power:Show()
        power:SetPoint("BOTTOM" .. near, f, "BOTTOM" .. near, sx * left, PADDING)
        power:SetPoint("BOTTOM" .. far, f, "BOTTOM" .. far, -sx * PADDING, PADDING)
        power:SetHeight(powerHeight)
        health:SetPoint("BOTTOM" .. far, power, "TOP" .. far, 0, 0)
        f.Separator:ClearAllPoints()
        f.Separator:SetPoint("TOPLEFT", power, "TOPLEFT", 0, K.SEPARATOR_HEIGHT / 2)
        f.Separator:SetPoint("TOPRIGHT", power, "TOPRIGHT", 0, K.SEPARATOR_HEIGHT / 2)
        f.Separator:SetHeight(K.SEPARATOR_HEIGHT)
        f.Separator:Show()
    else
        power:Hide()
        f.Separator:Hide()
        health:SetPoint("BOTTOM" .. far, f, "BOTTOM" .. far, -sx * PADDING, PADDING)
    end
    -- (a raid tile with a slim bar shows it at the health bar's foot: LayoutTexts)
    f.PowerText:SetShown(TilePowerMode(f, st) ~= "none" and showPower and (powerHeight >= 10 or RaidTile(f)))
end

local function LayoutHealClip(f)
    if not f.HealClip then return end
    local st = TS(f)
    local health, clip, heal, absorb = f.Health, f.HealClip, f.HealBar, f.AbsorbBar
    local fill = health:GetStatusBarTexture()
    local width = (st.width or 200) - 2 * K.INSET - PortraitSpace(f)
    -- Forever Style's plate: the bar's real length (UnitFramesRing PlaceBar), as the unit frames use
    local inset = health.FlareUI_PlateInset
    if inset then width = inset.length end
    clip:ClearAllPoints()
    heal:ClearAllPoints()
    absorb:ClearAllPoints()
    -- near: where the health fill starts (the right on a mirrored fill)
    local mirror = Mirrored(f, true)
    local near, far = mirror and "RIGHT" or "LEFT", mirror and "LEFT" or "RIGHT"
    heal:SetWidth(width)
    absorb:SetWidth(width)
    heal:SetReverseFill(mirror)
    -- shields follow the health and the incoming heals, as Blizzard's frames draw them (UnitFrames.lua)
    absorb:SetReverseFill(mirror)
    -- incoming heals in the tile's own bar texture
    heal:SetStatusBarTexture(K.GetBarTexture(inset and "FlareUI Forever" or st.texture, mirror))
    clip:SetPoint("TOP" .. near, fill, "TOP" .. far, 0, 0)
    clip:SetPoint("BOTTOM" .. far, health, "BOTTOM" .. far, 0, 0)
    heal:SetPoint("TOP" .. near, clip, "TOP" .. near, 0, 0)
    heal:SetPoint("BOTTOM" .. near, clip, "BOTTOM" .. near, 0, 0)
    local healFill = heal:GetStatusBarTexture()
    absorb:SetPoint("TOP" .. near, healFill, "TOP" .. far, 0, 0)
    absorb:SetPoint("BOTTOM" .. near, healFill, "BOTTOM" .. far, 0, 0)
    K.PlaceShieldGlow(f.ShieldGlow, health, mirror)
    local base = clip:GetFrameLevel()
    heal:SetFrameLevel(base + 1)
    absorb:SetFrameLevel(base + 2)
    local absorbTex = st.absorbTexture
    if absorbTex == nil then absorbTex = K.ABSORB_TEXTURE end
    if absorbTex == "" then absorbTex = st.texture end
    absorb:SetStatusBarTexture(K.GetBarTexture(absorbTex))
    absorb:SetStatusBarColor(K.ABSORB_COLOR[1], K.ABSORB_COLOR[2], K.ABSORB_COLOR[3], K.ABSORB_COLOR[4])
    -- the shield with no room after the health, over it (UnitFrames.lua UF.CreateOverAbsorb)
    K.PlaceOverAbsorb(f.OverAbsorb, health, width, mirror, K.GetBarTexture(absorbTex))
end

local function CastStyle(st)
    local castTexture = st.castTexture
    if castTexture == nil or castTexture == "" then castTexture = st.texture end
    local castBorder = st.castBorderTexture
    if castBorder == nil or castBorder == "" then castBorder = st.border end
    return {
        height = st.castHeight or 14,
        icon = st.castIcon ~= false, timer = st.castTimer ~= false, name = true,
        texture = castTexture, border = true, borderTexture = K.Border(castBorder),
        bgOpacity = st.bgOpacity,
    }
end

local function LayoutTexts(f)
    local st, raid = TS(f), RaidTile(f)
    local db = K.GetDb()
    local font = db and db.font
    -- FlareUI Style: the level is in the ring's disc (UnitFramesRing.lua lays it out)
    local levelOnRing = f.ringKind ~= nil
    K.ApplyFont(f.Name, font)
    if not levelOnRing then K.ApplyFont(f.Level, font) end
    K.ApplyFont(f.HealthText, font)
    K.ApplyFont(f.PowerText, db and (db.fontPower or db.font))
    local health, power = f.Health, f.Power
    local T = K.TEXT_INSET
    f.Name:ClearAllPoints()
    if not levelOnRing then f.Level:ClearAllPoints() end
    f.HealthText:ClearAllPoints()
    f.PowerText:ClearAllPoints()
    if raid then
        f.Level:Hide()
        f.Name:SetJustifyH("LEFT")
        f.Name:SetPoint("TOPLEFT", health, "TOPLEFT", T, -3)
        f.Name:SetPoint("RIGHT", health, "RIGHT", -T, 0)
        f.HealthText:SetJustifyH("CENTER")
        f.HealthText:SetPoint("CENTER", health, "CENTER", 0, -4)
        -- Power Text: in the power bar when it has the room, else at the health bar's foot
        f.PowerText:SetJustifyH("CENTER")
        if (st.powerHeight or 0) >= 10 then
            f.PowerText:SetPoint("CENTER", power, "CENTER", 0, 0)
        else
            f.PowerText:SetPoint("BOTTOM", health, "BOTTOM", 0, 2)
        end
    else
        -- level and name from the near side, the numbers on the far side (swapped when mirrored)
        local near, far, sx = Sides(f)
        -- FlareUI Style: the texts start past the ring's portrait
        local pad = f.ringKind and ns.UFRing.TextPad(f) or 0
        f.Name:SetJustifyH(near)
        f.HealthText:SetJustifyH(far)
        if not levelOnRing then
            f.Level:Show()
            f.Level:SetJustifyH(near)
            f.Level:SetPoint(near, health, near, sx * (T + pad), 0)
        end
        if st.showLevel and not levelOnRing then
            f.Name:SetPoint(near, f.Level, far, sx * 3, 0)
        else
            f.Name:SetPoint(near, health, near, sx * (T + pad), 0)
        end
        f.HealthText:SetPoint(far, health, far, -sx * T, 0)
        f.Name:SetPoint(far, f.HealthText, near, -sx * 4, 0)
        f.PowerText:SetJustifyH(far)
        f.PowerText:SetPoint(far, power, far, -sx * T, 0)
    end
    -- Forever Style's plate: the name centred in the name box, the numbers centred in their bars
    local nameBox = OnPlate(f) and ns.UFRing.NameBox(f)
    if nameBox then
        f.Name:ClearAllPoints()
        f.Name:SetPoint("LEFT", nameBox, "LEFT", T, 0)
        f.Name:SetPoint("RIGHT", nameBox, "RIGHT", -T, 0)
        f.Name:SetJustifyH("CENTER")
        f.HealthText:ClearAllPoints()
        f.HealthText:SetPoint("CENTER", health, "CENTER", 0, 0)
        f.HealthText:SetJustifyH("CENTER")
        f.PowerText:ClearAllPoints()
        f.PowerText:SetPoint("CENTER", power, "CENTER", 0, 0)
        f.PowerText:SetJustifyH("CENTER")
    end
end

local function LayoutIcons(f)
    local st, raid = TS(f), RaidTile(f)
    local health = f.Health
    local wantsPower = f.powerShown
    if wantsPower == nil then wantsPower = WantsPower(f) end
    local healthHeight = (st.height or 46) - 2 * K.INSET - (wantsPower and (st.powerHeight or 0) or 0)
    local mid = math_max(12, math_min(24, healthHeight * 0.6))
    if raid then
        PlaceIcon(f, "role", f.RoleIcon, 12, 12, "TOPLEFT", health, "TOPLEFT", 2, -2)
        -- the name moves over for the role icon
        f.Name:ClearAllPoints()
        f.Name:SetPoint("LEFT", f.RoleIcon, "RIGHT", 2, 0)
        f.Name:SetPoint("RIGHT", health, "RIGHT", -K.TEXT_INSET, 0)
        -- Show Level: the level just before the name
        if st.showLevel then
            f.Level:Show()
            f.Level:ClearAllPoints()
            f.Level:SetJustifyH("LEFT")
            f.Level:SetPoint("LEFT", f.RoleIcon, "RIGHT", 2, 0)
            f.Name:ClearAllPoints()
            f.Name:SetPoint("LEFT", f.Level, "RIGHT", 3, 0)
            f.Name:SetPoint("RIGHT", health, "RIGHT", -K.TEXT_INSET, 0)
        end
        PlaceIcon(f, "leader", f.LeaderIcon, 14, 14, "CENTER", f, "TOPLEFT", 8, -2)
        PlaceIcon(f, "raidIcon", f.RaidIcon, 14, 14, "CENTER", f, "TOP", 0, -3)
    else
        -- leader where the player frame has it, role in the bottom-right corner
        PlaceIcon(f, "leader", f.LeaderIcon, 20, 20, "CENTER", f, "TOPLEFT", 16, -2)
        PlaceIcon(f, "role", f.RoleIcon, 24, 24, "CENTER", f, "BOTTOMRIGHT", -4, 2)
        PlaceIcon(f, "raidIcon", f.RaidIcon, 16, 16, "CENTER", f, "TOP", 0, -2)
    end
    local readyAnchor = PortraitSpace(f) > 0 and f.Portrait or health
    PlaceIcon(f, "readyCheck", f.ReadyIcon, mid, mid, "CENTER", readyAnchor, "CENTER", 0, 0)
    PlaceIcon(f, "status", f.StatusIcon, mid, mid, "CENTER", health, "CENTER", 0, 0)
    -- FlareUI Style: on the ring, where the player frame has them
    if f.ringKind and f.RingFrame then
        for key, region in pairs({ leader = f.LeaderIcon, role = f.RoleIcon, raidIcon = f.RaidIcon,
                                   readyCheck = f.ReadyIcon, status = f.StatusIcon }) do
            local point, rel, relPoint, x, y, w, h = ns.UFRing.IconSpot(f, key)
            if point then
                region:ClearAllPoints()
                region:SetSize(w, h)
                region:SetPoint(point, rel, relPoint, x, y)
            end
        end
    end
end

-- An aura row's height: the icon, plus its timer when that hangs under it
local function CellHeight(size)
    if UFAura("auraTimer", "none") == "below" then return size + math_max(7, math_floor(size * 0.4 + 0.5)) + 3 end
    return size
end

-- How far the lanes at these places reach out from the frame
local function LanesExtent(st, places, across)
    local buffSize, debuffSize = ns.AuraSize(st, false, 18), ns.AuraSize(st, true, 18)
    local best = 0
    for _, pos in ipairs(places) do
        local max, perRow = AuraFit(st, pos)
        local reach = 0
        if across then
            -- beside the frame: a row's width
            if st.debuffs == pos or st.buffs == pos or st.dispels == pos then
                reach = perRow * (PlaceAuraSize(st, pos) + AURA_SPACING)
            end
        else
            if st.debuffs == pos then reach = reach + math.ceil(max / perRow) * (CellHeight(debuffSize) + AURA_SPACING) end
            if st.dispels == pos then reach = reach + math.ceil(math_min(max, 3) / perRow) * (debuffSize + AURA_SPACING) end
            if st.buffs == pos then reach = reach + math.ceil(max / perRow) * (CellHeight(buffSize) + AURA_SPACING) end
        end
        if reach > best then best = reach end
    end
    return best > 0 and (best + (EDGE_PLACES[places[1]] and EDGE_GAP or SIDE_GAP)) or 0
end

local function LayoutMember(f)
    local st = TS(f)
    if not st then return end
    if InCombatLockdown() and not f.fuiSample then pendingLayout = true return end
    -- FlareUI Style's ring, or back to the plain tile
    local kind = RingKind(f)
    if kind then
        f.ringKind, f.ringSide = kind, (Sides(f))
        f.ringDb = f.ringDb or function() return TS(f) end
    elseif f.ringKind then
        f.ringKind = nil
        ns.UFRing.Reset(f)
    end
    local PADDING = K.INSET
    if OnPlate(f) then
        -- Forever Style: the plate is the background and the border; Scale sets the height and ring
        if st.plateScale == nil then ns.UFRing.ApplyPlateScale(st, ns.UFRing.PlateDefaultScale(f.ringKind)) end
        local minW, minH = ns.UFRing.PlateMinSize(f)
        f:SetSize(math_max(st.width or 200, minW), math_max(st.height or 46, minH))
        f:SetBackdrop(nil)
        f.Border:Hide()
    else
        f:SetSize(st.width or 200, st.height or 46)
        f:SetBackdrop({ bgFile = K.BACKDROP_FILE, insets = { left = PADDING, right = PADDING, top = PADDING, bottom = PADDING } })
        f:SetBackdropColor(0, 0, 0, K.BG_OPACITY)
        K.ApplyBorderStyle(f.Border, K.GetBorderFile(K.Border(st.border)), st.height or 46)
        f.Border:Show()
        -- added over the border, so any border art comes out brighter in its own shape
        local bright = f.TargetHighlight.Border
        bright:SetBackdrop(f.Border:GetBackdrop())
        bright:SetBackdropBorderColor(1, 0.85, 0.5, 1)
        bright:SetBorderBlendMode("ADD")
    end

    -- mirrored tiles turn the FlareUI Forever gradient with the fill
    local texture = K.GetBarTexture(st.texture, Mirrored(f, true))
    f.Health:SetStatusBarTexture(texture)
    f.Power:SetStatusBarTexture(texture)
    f.Health.bg:SetTexture(texture)
    f.Power.bg:SetTexture(texture)
    f.powerShown = WantsPower(f)
    LayoutBars(f)
    if f.ringKind then ns.UFRing.Layout(f) end
    -- the bars' empty part (Background Opacity; on the plate its slot is the background: 0 unless set)
    local bgOpacity = st.bgOpacity
    -- on the plate its art is the background
    if OnPlate(f) then bgOpacity = 0 end
    K.SetBarBackground(f.Health, bgOpacity)
    K.SetBarBackground(f.Power, bgOpacity)
    LayoutHealClip(f)
    LayoutTexts(f)
    LayoutIcons(f)
    if f.Cast then
        -- FlareUI Style: the cast bar ends where the ring starts at its height
        local leftExtra, rightExtra
        if f.ringKind then
            local clear = ns.UFRing.Clearance(f, K.CAST_GAP)
            if f.ringSide == "LEFT" then leftExtra = clear else rightExtra = clear end
        end
        K.LayoutCastBar(f.Cast, CastStyle(st), f, "BOTTOM", leftExtra, rightExtra)
        -- the auras below move down while it shows (in a fight too: they are not protected)
        f.Cast.onShownChanged = f.Cast.onShownChanged or function()
            for _, pos in ipairs(BELOW_PLACES) do
                local entry = f.AuraPos and f.AuraPos[pos]
                if entry and entry.container:IsShown() then
                    local point, rel, relPoint, x, y = AuraAnchor(f, pos)
                    entry.container:ClearAllPoints()
                    entry.container:SetPoint(point, rel, relPoint, x, y)
                end
            end
        end
    end
    ConfigureAuras(f)
    ConfigureDispelHighlight(f)
end

-- Pets and party targets. The bottom row sits below the frame's auras and cast bar (room reserved:
-- secure frames cannot move in combat). The right side sits past the right-hand auras; both there
-- stack, target on top, together no taller than the frame.
local SIDE = { STACK_GAP = 2 }
function SIDE.BottomY(st, owner)
    local y = -PET_GAP - LanesExtent(st, BELOW_PLACES)
    if owner.Cast and owner.Cast.isEnabled() then y = y - (st.castHeight or 16) - K.CAST_GAP - K.INSET end
    return y
end
function SIDE.RightX(st)
    return TARGET_GAP + LanesExtent(st, { "RIGHT" }, true)
end
function SIDE.Stacked()
    return PetPlace() == "RIGHT" and TargetPlace() == "RIGHT"
end
-- a frame's outer height: its own under the frame; beside it, never taller than the party frame
function SIDE.Height(st, own, place)
    if place ~= "RIGHT" then return own end
    local h = st.height or 46
    if SIDE.Stacked() then h = math_floor((h - SIDE.STACK_GAP) / 2) end
    return math_max(8, math_min(own, h))
end
function SIDE.PetOuter(st) return (st.petHeight or 19) + 2 * K.INSET end
function SIDE.TargetOuter(st) return st.targetHeight or 25 end
-- the bottom row's height under member i (0: nothing there)
function SIDE.BottomRow(st, hasPet)
    local h = 0
    if PetPlace() == "BOTTOM" and hasPet then h = SIDE.PetOuter(st) end
    if TargetPlace() == "BOTTOM" then h = math_max(h, SIDE.TargetOuter(st)) end
    return h
end
-- the room beside each frame, for a horizontal party (Step)
function SIDE.RightRoom(st)
    local w = 0
    if PetPlace() == "RIGHT" then w = math_max(w, st.petWidth or 120) end
    if TargetPlace() == "RIGHT" then w = math_max(w, st.targetWidth or 100) end
    if w == 0 then return 0 end
    return SIDE.RightX(st) + w - LanesExtent(st, { "RIGHT" }, true)
end

local function LayoutPet(p)
    local st = S()
    if not st then return end
    if InCombatLockdown() then pendingLayout = true return end
    local PADDING = K.INSET
    local owner = p.owner
    local place = PetPlace()
    local outer = SIDE.Height(st, SIDE.PetOuter(st), place)
    local height = outer - 2 * PADDING
    p:SetSize(st.petWidth or 120, outer)
    K.ApplyBorderStyle(p.Border, K.GetBorderFile(K.Border(st.petBorder or "FlareUI Thin")), outer)
    local texture = K.GetBarTexture(st.texture)
    p.Health:SetStatusBarTexture(texture)
    p.Health.bg:SetTexture(texture)
    K.SetBarBackground(p.Health, st.bgOpacity)
    p.Health:ClearAllPoints()
    p.Health:SetPoint("TOPLEFT", p, "TOPLEFT", PADDING, -PADDING)
    p.Health:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -PADDING, PADDING)
    local db = K.GetDb()
    K.ApplyFont(p.Name, ScaledFont(db and db.font, math_max(8, math_min((db and db.font and db.font.size) or 12, height - 4))))
    p.Name:ClearAllPoints()
    p.Name:SetPoint("LEFT", p.Health, "LEFT", K.TEXT_INSET, 0)
    p.Name:SetPoint("RIGHT", p.Health, "RIGHT", -K.TEXT_INSET, 0)
    p:ClearAllPoints()
    if place == "RIGHT" then
        -- beside the frame: centred on it, or under the target when both are there
        if SIDE.Stacked() then
            p:SetPoint("BOTTOMLEFT", owner, "BOTTOMRIGHT", SIDE.RightX(st), 0)
        else
            p:SetPoint("LEFT", owner, "RIGHT", SIDE.RightX(st), 0)
        end
    else
        -- the bottom row, right edges lined up
        p:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, SIDE.BottomY(st, owner))
    end
end

-- A member's target: beside the frame (centred on it, or above the pet when both are there), or in
-- the bottom row with its left edge on the frame's, left of the pet there (narrowed so they never meet)
local function LayoutTarget(t)
    local st = S()
    if not st then return end
    if InCombatLockdown() then pendingLayout = true return end
    local PADDING = K.INSET
    local owner = t.owner
    local place = TargetPlace()
    local height = SIDE.Height(st, SIDE.TargetOuter(st), place)
    local width = st.targetWidth or 100
    if place == "BOTTOM" and PetPlace() == "BOTTOM" then
        width = math_max(30, math_min(width, (st.width or 200) - (st.petWidth or 120) - TARGET_GAP))
    end
    t:SetSize(width, height)
    K.ApplyBorderStyle(t.Border, K.GetBorderFile(K.Border(st.targetBorder or "FlareUI Thin")), height)
    local texture = K.GetBarTexture(st.texture)
    t.Health:SetStatusBarTexture(texture)
    t.Health.bg:SetTexture(texture)
    K.SetBarBackground(t.Health, st.bgOpacity)
    t.Health:ClearAllPoints()
    t.Health:SetPoint("TOPLEFT", t, "TOPLEFT", PADDING, -PADDING)
    t.Health:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -PADDING, PADDING)
    local db = K.GetDb()
    K.ApplyFont(t.Name, ScaledFont(db and db.font, math_max(8, math_min((db and db.font and db.font.size) or 12, height - 2 * PADDING - 4))))
    t.Name:ClearAllPoints()
    t.Name:SetPoint("LEFT", t.Health, "LEFT", K.TEXT_INSET, 0)
    t.Name:SetPoint("RIGHT", t.Health, "RIGHT", -K.TEXT_INSET, 0)
    t:ClearAllPoints()
    if place == "BOTTOM" then
        t:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, SIDE.BottomY(st, owner))
    elseif SIDE.Stacked() then
        t:SetPoint("TOPLEFT", owner, "TOPRIGHT", SIDE.RightX(st), 0)
    else
        t:SetPoint("LEFT", owner, "RIGHT", SIDE.RightX(st), 0)
    end
end

-- One step from a frame to the next, and where the first frame starts in the holder
local function Step()
    local st = S()
    local above = LanesExtent(st, ABOVE_PLACES)
    local below = LanesExtent(st, BELOW_PLACES)
    -- a row: each frame with its side auras and what sits on its right (pet, target)
    if Horizontal() then
        local left = LanesExtent(st, { "LEFT" }, true)
        local right = LanesExtent(st, { "RIGHT" }, true)
        -- FlareUI / Forever Style: the ring past the frame's edge, on its side
        local f = members[1]
        if f and f.ringKind and ns.UFRing then
            local overhang = ns.UFRing.Overhang(f)
            if f.ringSide == "LEFT" then left = math_max(left, overhang) else right = math_max(right, overhang) end
        end
        return left + (st.width or 200) + right + SIDE.RightRoom(st) + (st.spacing or 8), 0, left, -above
    end
    local h = st.height or 46
    if st.castbar then h = h + (st.castHeight or 16) + K.CAST_GAP + K.INSET end
    -- the bottom row's room is added per frame (LayoutHolder: BottomRoom); under it the gap is
    -- tighter, but never closer than the row sits to its owner
    return 0, -(above + h + below + (st.spacing or 8)), 0, -above
end

-- The room a member's bottom row (pet, target) adds under it, for a row this high
local function BottomRoom(st, rowHeight)
    if rowHeight <= 0 then return 0 end
    local spacing = st.spacing or 8
    local gapBelow = math_max(spacing - 4, PET_GAP + 2)
    return PET_GAP + rowHeight + gapBelow - spacing
end

-- Whether this frame has a pet under it (in Edit Mode: the samples with one)
local function HasPet(i)
    local party = GetPartyDb()
    if PetPlace() == "OFF" then return false end
    if IsEditing() then
        local sample = PREVIEW[i - (party.showPlayer and 0 or 1) + 1]
        return sample and sample.pet and true or false
    end
    if UnitExists(PET_UNITS[i]) then return true end
    -- a pet called mid-fight shows at once, but the frames can't move then: room is kept under the
    -- classes with pets (and under anyone whose class can't be read)
    local unit = SLOT_UNITS[i]
    if not UnitExists(unit) then return false end
    local _, class = UnitClass(unit)
    if not canaccessvalue(class) then return true end
    return class == "HUNTER" or class == "WARLOCK"
end

local function FirstSlot()
    return GetPartyDb().showPlayer and 0 or 1
end

-- The frames in order: party order, or by role (an unreadable role counts as none; absent members
-- go last)
local ROLE_RANK = { TANK = 1, HEALER = 2, DAMAGER = 3, NONE = 4 }
local function SlotOrder(first)
    local order = {}
    for i = first, MAX_MEMBERS do order[#order + 1] = i end
    if not GetPartyDb().sortByRole or IsEditing() then return order end
    local rank = {}
    for _, i in ipairs(order) do
        local unit = SLOT_UNITS[i]
        if UnitExists(unit) then
            local role = readable(UnitGroupRolesAssigned(unit))
            rank[i] = ROLE_RANK[role or "NONE"] or 4
        else
            rank[i] = 9
        end
    end
    table.sort(order, function(a, b)
        if rank[a] ~= rank[b] then return rank[a] < rank[b] end
        return a < b
    end)
    return order
end

local function LayoutHolder()
    if not holder then return end
    if InCombatLockdown() then pendingLayout = true return end
    local st = S()
    local first = FirstSlot()
    local count = MAX_MEMBERS - first + 1
    local dx, dy, ox, oy = Step()
    -- each frame's place: the ones before it, and the room their bottom rows take (vertical only)
    local x, y = ox, oy
    local placed = {}
    -- Growth Up: laid out from the last place, so the first member sits at the bottom and the party
    -- grows upward (absent members take the top places)
    local order = SlotOrder(first)
    if GetPartyDb().grow == "UP" then
        local reversed = {}
        for k = #order, 1, -1 do reversed[#reversed + 1] = order[k] end
        order = reversed
    end
    for _, i in ipairs(order) do
        placed[i] = { x, y }
        x = x + dx
        y = y + dy
        if dy ~= 0 then y = y - BottomRoom(st, SIDE.BottomRow(st, HasPet(i))) end
    end
    for i = 0, MAX_MEMBERS do
        local f = members[i]
        -- your own frame, when it is not shown, waits just outside the first place
        local p = placed[i] or { ox - dx, oy - dy }
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", holder, "TOPLEFT", p[1], p[2])
    end
    if dx ~= 0 then
        holder:SetSize(count * dx - (st.spacing or 8), st.height or 46)
    else
        holder:SetSize(st.width or 200, math_max(1, -y - (st.spacing or 8)))
    end
end

--------------------------------------------------
-- 7. POSITION (per Edit Mode layout)
--------------------------------------------------
local function GetLayoutStore(layoutName)
    local party = GetPartyDb()
    if not party then return nil end
    layoutName = layoutName or LEM:GetActiveLayoutName() or "Modern"
    party.layouts = party.layouts or {}
    -- (a layout with no spot of its own reads the profile's home layout's: ProfileLayout.lua)
    return ns.LayoutHome(party.layouts, layoutName)
end

local function ApplyPosition(layoutName)
    if not holder then return end
    if InCombatLockdown() then pendingLayout = true return end
    -- FlareUI Style's party (not Raid-Style) has its own default, past the ring
    local base = (RingKind({}) and ns.UFRing.TilePosition("party")) or BASE_POSITION
    for k, v in pairs(base) do DEFAULT_POSITION[k] = v end
    local store = GetLayoutStore(layoutName)
    local pos = (store and store.point) and store or DEFAULT_POSITION
    holder:ClearAllPoints()
    holder:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
end

local function OnFrameMoved(_, layoutName, point, x, y)
    local store = GetLayoutStore(layoutName)
    if not store then return end
    store.point, store.x, store.y = point, math_floor(x + 0.5), math_floor(y + 0.5)
end

--------------------------------------------------
-- 8. VISIBILITY
-- The holder shows in a party, never in a raid (the raid frames take over there); member frames
-- follow their units. In Edit Mode everything shows, with samples.
--------------------------------------------------
local function ApplyVisibility()
    if not holder then return end
    if InCombatLockdown() then pendingLayout = true return end
    local party = GetPartyDb()
    local editing = IsEditing()
    if editing then
        UnregisterStateDriver(holder, "visibility")
        holder:Show()
    else
        -- [group:party] can stay false through a fight after joining one (party1 already exists):
        -- the unit checks cover it, and raid1 hides it in a raid the same way
        RegisterStateDriver(holder, "visibility", "[group:raid] hide; [@raid1,exists] hide; [group:party] show; [@party1,exists] show; hide")
    end
    for i = 0, MAX_MEMBERS do
        local f, p = members[i], pets[i]
        local wanted = i > 0 or party.showPlayer
        if editing then
            UnregisterUnitWatch(f)
            UnregisterStateDriver(f, "visibility")
            f:SetShown(wanted)
        elseif i == 0 then
            UnregisterUnitWatch(f)
            RegisterStateDriver(f, "visibility", wanted and "show" or "hide")
        else
            RegisterUnitWatch(f)
        end
        if p then
            if editing then
                UnregisterUnitWatch(p)
                local first = party.showPlayer and 0 or 1
                local sample = PREVIEW[i - first + 1]
                p:SetShown(wanted and party.pets and sample and sample.pet and true or false)
            elseif wanted and party.pets then
                RegisterUnitWatch(p)
            else
                UnregisterUnitWatch(p)
                p:Hide()
            end
        end
        local t = targets[i]
        if t then
            if editing then
                UnregisterUnitWatch(t)
                t:SetShown(wanted and party.targets and true or false)
            elseif wanted and party.targets then
                RegisterUnitWatch(t)
            else
                UnregisterUnitWatch(t)
                t:Hide()
            end
        end
    end
end

--------------------------------------------------
-- 9. EDIT MODE PREVIEW
--------------------------------------------------
local function PreviewColor(class)
    local c = ns.ClassHealthOverride(class) or PREVIEW_CLASS_RGB[class]
    if c then return c[1], c[2], c[3] end
    local cc = class and C_ClassColor and C_ClassColor.GetClassColor(class)
    if cc then return cc:GetRGB() end
    return ns.HEALTH_GREEN[1], ns.HEALTH_GREEN[2], ns.HEALTH_GREEN[3]
end

-- A hand-drawn sample aura for tiles without containers (raid and main tank samples), tinted as a
-- real one
local function PreviewAura(f, n, size, isDebuff, texture, dispelKey)
    f.previewAuras = f.previewAuras or {}
    local b = f.previewAuras[n]
    if not b then
        b = CreateFrame("Frame", nil, f)
        f.previewAuras[n] = b
    end
    local look = LaneLook(size, isDebuff, true)
    if look and ns.AuraLook then
        ns.AuraLook.Style(b, look)
        b.FlareUI_Icon:SetTexture(texture)
        local c = look.colors[dispelKey or "None"] or look.colors.None
        b.FlareUI_Border:SetVertexColor(c:GetRGBA())
        b.FlareUI_Count:SetText("")
        b.FlareUI_Duration:SetText("")
        if b.FlareUI_Cooldown and b.FlareUI_Cooldown.Clear then b.FlareUI_Cooldown:Clear() end
    else
        b:SetSize(size, size)
        b.Icon = b.Icon or b:CreateTexture(nil, "ARTWORK")
        b.Icon:SetAllPoints()
        b.Icon:SetTexture(texture)
    end
    b:SetFrameLevel(f:GetFrameLevel() + 7)
    b:ClearAllPoints()
    b:Show()
    return b
end

-- Samples the aura containers cannot show in Edit Mode: dispel icons and the dispel highlight
local function PreviewBit(f, used, size)
    f.previewBits = f.previewBits or {}
    local b = f.previewBits[used]
    if not b then
        b = CreateFrame("Frame", nil, f)
        b.Icon = b:CreateTexture(nil, "ARTWORK")
        b.Icon:SetAllPoints()
        f.previewBits[used] = b
    end
    b:SetFrameLevel(f:GetFrameLevel() + 7)
    b:SetSize(size, size)
    b:ClearAllPoints()
    b:Show()
    return b
end

HidePreviewExtras = function(f)
    if f.previewBits then for _, b in ipairs(f.previewBits) do b:Hide() end end
    if f.previewAuras then for _, b in ipairs(f.previewAuras) do b:Hide() end end
    if f.HighlightSample then f.HighlightSample:Hide() end
end

local function ApplyPreviewExtras(f, data)
    HidePreviewExtras(f)
    local st = TS(f)
    local used = 0
    local size = ns.AuraSize(st, true, 18)   -- the debuffs' (the dispel samples go with them)
    -- buffs and debuffs drawn by hand where there are no containers to show Edit Mode's samples
    if f.noAuras then
        local auras = 0
        local function Row(place, count, icons, isDebuff)
            if not place or place == "OFF" or (count or 0) <= 0 then return end
            local size = ns.AuraSize(st, isDebuff, 18)
            local max = AuraFit(st, place, f)
            local point, rel, relPoint, x, y, growH = AuraAnchor(f, place)
            local sx = growH == AnchorUtil.FlowDirection.Left and -1 or 1
            local offset = 0
            for i = 1, math_min(count, max) do
                auras = auras + 1
                local b = PreviewAura(f, auras, size, isDebuff, icons[(i - 1) % #icons + 1])
                b:SetPoint(point, rel, relPoint, x + sx * offset, y)
                offset = offset + size + AURA_SPACING
            end
        end
        Row(st.buffs, data.buffs, SAMPLE_BUFF_ICONS, false)
        Row(st.debuffs, data.debuffs, SAMPLE_DEBUFF_ICONS, true)
    end
    -- sample dispel icons at their place (below the debuff rows when shared); the party's on the
    -- portrait of the sample with a dispellable debuff
    local pos = DispelPlace(f, st)
    local sampled = not f.ctx or data.highlight
    if pos == "PORTRAIT" then
        -- three types on the member with a dispellable debuff: the grid's first row and a half
        if data.highlight then
            local cell = DispelGrid(f)
            local point, rel, relPoint, x, y = AuraAnchor(f, pos)
            for i = 1, 3 do
                used = used + 1
                local b = PreviewBit(f, used, cell)
                local atlas = "RaidFrame-Icon-Debuff" .. DISPEL_TYPES[i]
                if K.HasAtlas(atlas) then
                    b.Icon:SetAtlas(atlas, false)
                else
                    local c = DISPEL_RGB[DISPEL_TYPES[i]]
                    b.Icon:SetColorTexture(c[1], c[2], c[3], 1)
                end
                b:SetFrameLevel(f:GetFrameLevel() + (f.ringKind and 10 or 7))
                local col, row = (i - 1) % 2, math_floor((i - 1) / 2)
                b:SetPoint(point, rel, relPoint, x + col * (cell + AURA_SPACING), y - row * (cell + AURA_SPACING))
            end
        end
    elseif pos and pos ~= "OFF" and sampled then
        local point, rel, relPoint, x, y, growH, growV = AuraAnchor(f, pos)
        local sx = growH == AnchorUtil.FlowDirection.Left and -1 or 1
        local sy = growV == AnchorUtil.FlowDirection.Up and 1 or -1
        local max, perRow = AuraFit(st, pos, f)
        local skip = 0
        if st.debuffs == pos then
            skip = math.ceil(max / perRow) * (CellHeight(size) + AURA_SPACING)
        end
        for i = 1, math_min(max, 3) do
            used = used + 1
            local b = PreviewBit(f, used, size)
            local atlas = "RaidFrame-Icon-Debuff" .. DISPEL_TYPES[i]
            if K.HasAtlas(atlas) then
                b.Icon:SetAtlas(atlas, false)
            else
                local c = DISPEL_RGB[DISPEL_TYPES[i]]
                b.Icon:SetColorTexture(c[1], c[2], c[3], 1)
            end
            b:SetPoint(point, rel, relPoint, x + sx * (i - 1) * (size + AURA_SPACING), y + sy * skip)
        end
    end
    -- the dispel highlight, on one sample member
    if data.highlight and (st.dispelHighlight or "mine") ~= "off" then
        -- the frame's border again, in the debuff type's colour (as the real one)
        local hl = f.HighlightSample
        if not hl then
            hl = CreateFrame("Frame", nil, f, "BackdropTemplate")
            f.HighlightSample = hl
        end
        local c = DISPEL_RGB[data.highlight] or DISPEL_RGB.Magic
        hl:ClearAllPoints()
        -- Forever Style's plate: the name box's glow instead
        local strip = OnPlate(f) and f.PlateFrame and f.PlateFrame.Strip
        if strip then
            hl:SetAllPoints(strip)
            hl:SetFrameLevel(f.PlateFrame:GetFrameLevel() + 2)
            hl:SetBackdrop(nil)
            if not hl.Glow then
                hl.Glow = hl:CreateTexture(nil, "OVERLAY")
                hl.Glow:SetAllPoints(hl)
            end
            pcall(hl.Glow.SetAtlas, hl.Glow, ns.UFRing.STRIP_ATLAS, false)
            hl.Glow:SetVertexColor(c[1], c[2], c[3], 1)
            hl.Glow:Show()
        else
            if hl.Glow then hl.Glow:Hide() end
            hl:SetAllPoints(f.Border)
            hl:SetFrameLevel(f.Border:GetFrameLevel() + 1)
            hl:SetBackdrop(f.Border:GetBackdrop())
            hl:SetBackdropBorderColor(c[1], c[2], c[3], 1)
        end
        hl:Show()
    end
end

ApplyPreview = function(f)
    local data
    if f.ctx then
        data = f.ctx.PreviewData(f)
    else
        local first = GetPartyDb().showPlayer and 0 or 1
        data = PREVIEW[f.index - first + 1] or PREVIEW[1]
    end
    f.preview = data
    f.powerShown = nil
    local st = TS(f)
    local class = data.class
    f.Name:SetText(data.name)
    if st.showLevel and data.level == -1 then
        f.Level:SetText("??")
        f.Level:SetTextColor(1, 0.1, 0.1)
    elseif st.showLevel then
        f.Level:SetText(UnitLevel("player") or "")
        f.Level:SetTextColor(1, 0.82, 0)
    else
        f.Level:SetText("")
    end
    f.Health:SetMinMaxValues(0, 1)
    f.Health:SetValue(data.health or 1)
    if data.rgb then
        f.Health:SetStatusBarColor(data.rgb[1], data.rgb[2], data.rgb[3])
    elseif ns.ClassColorsOn(st) then
        f.Health:SetStatusBarColor(PreviewColor(class))
    else
        f.Health:SetStatusBarColor(ns.HEALTH_GREEN[1], ns.HEALTH_GREEN[2], ns.HEALTH_GREEN[3])
    end
    local mode = st.healthText or "percent"
    f.HealthText:SetAlpha(1)
    if data.dead then
        f.HealthText:SetText(K.DEAD_TEXT)
    elseif mode == "lost" then
        K.SetSampleHealthLost(f.HealthText, data.health or 1)
    else
        K.FormatBarText(f.HealthText, mode, math_floor((data.health or 1) * 24000), (data.health or 1) * 100, 24000)
    end
    f.powerShown = WantsPower(f, class)
    LayoutBars(f)
    f.Power:SetMinMaxValues(0, 1)
    f.Power:SetValue(data.power or 1)
    local powerToken = PREVIEW_POWER[class] or "MANA"
    local r, g, b = ns.PowerColor(powerToken)
    if r then
        f.Power:SetStatusBarColor(r, g, b)
    else
        local p = PREVIEW_POWER_RGB[powerToken]
        f.Power:SetStatusBarColor(p[1], p[2], p[3])
    end
    local ptMode = TilePowerMode(f, st)
    K.FormatBarText(f.PowerText, ptMode, math_floor((data.power or 1) * 9000), math_floor((data.power or 1) * 100), 9000)
    -- a sample incoming heal and shield past the health, as the unit frames' samples show (they read
    -- as missing on party frames without: a player's question 11-11); none on the dead
    if f.HealBar then
        local on = not data.dead
        f.HealBar:SetMinMaxValues(0, 1)
        f.AbsorbBar:SetMinMaxValues(0, 1)
        f.HealBar:SetValue(on and 0.12 or 0)
        f.AbsorbBar:SetValue(on and 0.15 or 0)
        K.HideShieldGlow(f.ShieldGlow)
        K.SetOverAbsorb(f.OverAbsorb, nil, 1, on and 0.15 or 0)
    end

    -- the icons at their size again (Blizzard's role routine narrows the role icon to 1 px when the
    -- unit has no role)
    LayoutIcons(f)
    local function ShowIcon(key, region, fn)
        if IconShown(key, f) and fn() then region:Show() else region:Hide() end
    end
    ShowIcon("role", f.RoleIcon, function()
        local atlas = ROLE_ATLAS[data.role or "DAMAGER"]
        if not (atlas and K.HasAtlas(atlas)) then return false end
        f.RoleIcon:SetAtlas(atlas, false)
        return true
    end)
    ShowIcon("leader", f.LeaderIcon, function()
        if not data.leader then return false end
        K.SetIconArt(f.LeaderIcon, "UI-HUD-UnitFrame-Player-Group-LeaderIcon", "Interface\\GroupFrame\\UI-Group-LeaderIcon")
        return true
    end)
    ShowIcon("raidIcon", f.RaidIcon, function()
        if not data.marker then return false end
        SetRaidTargetIconTexture(f.RaidIcon, data.marker)
        return true
    end)
    ShowIcon("readyCheck", f.ReadyIcon, function()
        local status = data.ready
        if not status then return false end
        f.ReadyIcon:SetAtlas(READY_ATLAS[status], false)
        return true
    end)
    ShowIcon("status", f.StatusIcon, function()
        local state = data.status
        local atlas = state and STATUS_ATLAS[state]
        if not (atlas and K.HasAtlas(atlas)) then return false end
        f.StatusIcon:SetAtlas(atlas, false)
        return true
    end)
    f:SetAlpha(1)
    f.TargetHighlight:SetAlpha(0)
    K.ResetBorderTint(f.Border)
    UpdatePortrait(f)
    UpdateCast(f)
    -- the icons and auras of Edit Mode's sample; a settings preview shows the frame alone
    if f.fuiSample then HidePreviewExtras(f) else ApplyPreviewExtras(f, data) end

    local p = not f.ctx and pets[f.index]
    if p then
        p.Health:SetMinMaxValues(0, 1)
        p.Health:SetValue(0.8)
        p.Health:SetStatusBarColor(0, 0.8, 0)
        p.Name:SetText(data.pet or "")
    end

    local t = not f.ctx and targets[f.index]
    if t then
        local first = GetPartyDb().showPlayer and 0 or 1
        local sample = PREVIEW_TARGETS[f.index - first + 1] or PREVIEW_TARGETS[1]
        local r, g, b
        if sample.class then
            r, g, b = PreviewColor(sample.class)
        else
            r, g, b = PREVIEW_HOSTILE_RGB[1], PREVIEW_HOSTILE_RGB[2], PREVIEW_HOSTILE_RGB[3]
        end
        t.Health:SetMinMaxValues(0, 1)
        t.Health:SetValue(sample.health)
        t.Health:SetStatusBarColor(r, g, b)
        t.Name:SetText(sample.name)
    end
end

--------------------------------------------------
-- 10. FRAME CREATION
--------------------------------------------------
local function OnEnter(f)
    f.Highlight:Show()
    if GameTooltip:IsForbidden() or IsEditing() or not f.fuiUnit then return end
    GameTooltip_SetDefaultAnchor(GameTooltip, f)
    GameTooltip:SetUnit(f.fuiUnit)
    GameTooltip:Show()
end

local function OnLeave(f)
    f.Highlight:Hide()
    if not GameTooltip:IsForbidden() then GameTooltip:Hide() end
end

local function SecureUnitButton(name, unit)
    local f = CreateFrame("Button", name, holder, "SecureUnitButtonTemplate,PingableUnitFrameTemplate,BackdropTemplate")
    f.fuiUnit = unit
    f:SetAttribute("unit", unit)
    f:SetAttribute("*type1", "target")
    f:SetAttribute("*type2", "togglemenu")
    f:RegisterForClicks("AnyUp")
    if type(f.SetRolesets) == "function" then pcall(f.SetRolesets, f, "unitFrames") end
    f:SetScript("OnEnter", OnEnter)
    f:SetScript("OnLeave", OnLeave)
    -- after the scripts: a click-cast addon wraps OnEnter / OnLeave as it registers the frame
    _G.ClickCastFrames = _G.ClickCastFrames or {}
    _G.ClickCastFrames[f] = true
    return f
end

local MEMBER_UNIT_EVENTS = {
    "UNIT_HEALTH", "UNIT_MAXHEALTH",
    "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
    "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_FACTION", "UNIT_CONNECTION", "UNIT_FLAGS",
    "UNIT_HEAL_PREDICTION", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_THREAT_SITUATION_UPDATE",
    "UNIT_PHASE", "UNIT_OTHER_PARTY_CHANGED",
    "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED",
}

-- UNIT_IN_RANGE_UPDATE only while the tile shows, and never on enemy tiles (they don't fade): the
-- client does extra work for every frame registered for it, as Blizzard's raid frames note
local function SetRangeEvent(f, on)
    if on and f.fuiUnit and not (f.ctx and f.ctx.hostile) then
        pcall(f.RegisterUnitEvent, f, "UNIT_IN_RANGE_UPDATE", f.fuiUnit)
    else
        pcall(f.UnregisterEvent, f, "UNIT_IN_RANGE_UPDATE")
    end
end
local function RangeEventOn(f) SetRangeEvent(f, true) end
local function RangeEventOff(f) SetRangeEvent(f, false) end

-- Builds a tile on a unit button: bars, texts, icons, highlights, heal overlays, auras and events.
-- f.ctx (set first) gives it an owner of its own; f.noAuras leaves out the aura containers (samples).
local function BuildTile(f, unit)
    local level = f:GetFrameLevel()

    f.Health = K.CreateBar(f, level + 1)
    f.Power = K.CreateBar(f, level + 1)
    if unit == "player" and ns.UnitFrames.AttachFsrSpark then ns.UnitFrames.AttachFsrSpark(f) end

    -- levels as on the unit frames: bars +1, overlays +2 / +3, border +4, text +5, inside auras +6
    f.Border = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.Border:SetAllPoints()
    f.Border:SetFrameLevel(level + 4)

    local overlay = CreateFrame("Frame", nil, f)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(level + 5)
    f.Overlay = overlay
    f.Name = overlay:CreateFontString(nil, "OVERLAY")
    f.Name:SetWordWrap(false)
    f.Level = overlay:CreateFontString(nil, "OVERLAY")
    f.HealthText = overlay:CreateFontString(nil, "OVERLAY")
    f.PowerText = overlay:CreateFontString(nil, "OVERLAY")

    f.Separator = overlay:CreateTexture(nil, "ARTWORK")
    f.Separator:SetTexture(K.SEPARATOR_TEXTURE)
    f.Separator:Hide()

    f.Portrait = CreateFrame("Frame", nil, f)
    f.Portrait:SetFrameLevel(level + 1)
    f.Portrait.Tex = f.Portrait:CreateTexture(nil, "ARTWORK")
    f.Portrait.Tex:SetAllPoints()
    f.Portrait:Hide()
    f.PortraitDivider = overlay:CreateTexture(nil, "ARTWORK")
    f.PortraitDivider:SetTexture(K.SEPARATOR_TEXTURE)
    f.PortraitDivider:SetTexCoord(0, 0, 1, 0, 0, 1, 1, 1)
    f.PortraitDivider:Hide()

    f.RaidIcon = overlay:CreateTexture(nil, "OVERLAY", nil, 4)
    f.RaidIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    f.RaidIcon:Hide()
    f.LeaderIcon = overlay:CreateTexture(nil, "OVERLAY", nil, 3)
    f.LeaderIcon:Hide()
    f.RoleIcon = overlay:CreateTexture(nil, "OVERLAY", nil, 3)
    f.RoleIcon:Hide()

    -- the centre icons sit above the inside auras
    local top = CreateFrame("Frame", nil, f)
    top:SetAllPoints()
    top:SetFrameLevel(level + 8)
    f.ReadyIcon = top:CreateTexture(nil, "OVERLAY", nil, 2)
    f.ReadyIcon:Hide()
    f.StatusIcon = top:CreateTexture(nil, "OVERLAY", nil, 1)
    f.StatusIcon:Hide()

    f.Highlight = overlay:CreateTexture(nil, "OVERLAY")
    f.Highlight:SetAllPoints(f.Health)
    f.Highlight:SetColorTexture(1, 1, 1, 0.08)
    f.Highlight:Hide()

    -- the target's highlight: the frame's border again, brightened (its backdrop: LayoutMember)
    local hl = CreateFrame("Frame", nil, f)
    hl:SetPoint("TOPLEFT", f, "TOPLEFT", K.INSET - 1, -K.INSET + 1)
    hl:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -K.INSET + 1, K.INSET - 1)
    hl:SetFrameLevel(level + 5)
    hl.Border = CreateFrame("Frame", nil, hl, "BackdropTemplate")
    hl.Border:SetAllPoints(f.Border)
    hl:SetAlpha(0)
    f.TargetHighlight = hl

    -- incoming heals and absorbs (UnitFrames.lua CreateIndicators)
    local clip = CreateFrame("Frame", nil, f.Health)
    clip:SetFrameLevel(f.Health:GetFrameLevel() + 1)
    clip:SetClipsChildren(true)
    local heal = CreateFrame("StatusBar", nil, clip)
    heal:SetStatusBarTexture(K.GetBarTexture(K.HEAL_TEXTURE))
    heal:SetStatusBarColor(K.HEAL_COLOR[1], K.HEAL_COLOR[2], K.HEAL_COLOR[3], K.HEAL_COLOR[4])
    heal:SetMinMaxValues(0, 1)
    heal:SetValue(0)
    local absorb = CreateFrame("StatusBar", nil, clip)
    absorb:SetMinMaxValues(0, 1)
    absorb:SetValue(0)
    f.HealClip, f.HealBar, f.AbsorbBar = clip, heal, absorb
    f.ShieldGlow = K.CreateShieldGlow(f.Health, clip)
    f.OverAbsorb = K.CreateOverAbsorb(f.Health, clip)
    if CreateUnitHealPredictionCalculator then
        local ok, calc = pcall(CreateUnitHealPredictionCalculator)
        if ok and calc then f.HealCalc = calc end
    end

    if not f.ctx or f.ctx.castbar then
        f.Cast = K.CreateCastBar(f, unit, f.fuiSample)
        f.Cast.isEnabled = function() local st = TS(f); return st and st.castbar and true or false end
    end

    if not f.noAuras then PrecreateAuraContainers(f) end

    f:SetScript("OnEvent", OnMemberEvent)
    if unit then
        for _, event in ipairs(MEMBER_UNIT_EVENTS) do pcall(f.RegisterUnitEvent, f, event, unit) end
        if f.Cast then for _, event in ipairs(K.CAST_EVENTS) do pcall(f.RegisterUnitEvent, f, event, unit) end end
    end
    f:HookScript("OnShow", RangeEventOn)
    f:HookScript("OnHide", RangeEventOff)
    if f:IsVisible() then RangeEventOn(f) end
    f:HookScript("OnShow", UpdateAll)
end

-- A raid header hands its tiles a new unit (in combat too: no protected calls here)
local function SetTileUnit(f, unit)
    if f.fuiUnit == unit then return end
    f.fuiUnit = unit
    f.unitSetAt = GetTime()   -- drawn in full now (or on its OnShow): the roster pass can skip it
    for _, event in ipairs(MEMBER_UNIT_EVENTS) do pcall(f.UnregisterEvent, f, event) end
    if unit then
        for _, event in ipairs(MEMBER_UNIT_EVENTS) do pcall(f.RegisterUnitEvent, f, event, unit) end
    end
    SetRangeEvent(f, f:IsVisible())
    local function Retarget(container) pcall(container.SetUnit, container, unit or "none") end   -- no unit: the containers' own null token
    if f.AuraPos then for _, entry in pairs(f.AuraPos) do Retarget(entry.container) end end
    if f.AuraHighlight then Retarget(f.AuraHighlight.container) end
    if unit and f:IsVisible() then UpdateAll(f) end
end

local function CreateMember(index)
    local unit = SLOT_UNITS[index]
    local f = SecureUnitButton("FlareUI_Party" .. index, unit)
    f.index = index
    BuildTile(f, unit)
    members[index] = f
    return f
end

local function CreatePet(index)
    local owner = members[index]
    local p = SecureUnitButton("FlareUI_PartyPet" .. index, PET_UNITS[index])
    p.owner = owner
    p.index = index
    local level = p:GetFrameLevel()
    p.Health = K.CreateBar(p, level + 1)
    p.Border = CreateFrame("Frame", nil, p, "BackdropTemplate")
    p.Border:SetAllPoints()
    p.Border:SetFrameLevel(level + 4)
    local overlay = CreateFrame("Frame", nil, p)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(level + 5)
    p.Name = overlay:CreateFontString(nil, "OVERLAY")
    p.Name:SetJustifyH("LEFT")
    p.Name:SetWordWrap(false)
    p.Highlight = overlay:CreateTexture(nil, "OVERLAY")
    p.Highlight:SetAllPoints(p.Health)
    p.Highlight:SetColorTexture(1, 1, 1, 0.08)
    p.Highlight:Hide()
    -- hidden (no pet, or the holder is): OnShow below repaints it when it comes back
    p:SetScript("OnEvent", function(self, event)
        if not self:IsVisible() then return end
        if event == "UNIT_IN_RANGE_UPDATE" then UpdateRange(self) else UpdatePet(self, true) end
    end)
    for _, event in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE", "UNIT_CONNECTION" }) do
        pcall(p.RegisterUnitEvent, p, event, p.fuiUnit)
    end
    p:HookScript("OnShow", RangeEventOn)
    p:HookScript("OnHide", RangeEventOff)
    if p:IsVisible() then RangeEventOn(p) end
    p:HookScript("OnShow", function(self) UpdatePet(self) end)
    LEM:AddSelectionArea(p)
    pets[index] = p
    return p
end

-- Clicking a member's target targets it too (the frame is a unit button like the others)
local function CreatePartyTarget(index)
    local t = SecureUnitButton("FlareUI_PartyTarget" .. index, TARGET_UNITS[index])
    t.owner = members[index]
    t.index = index
    local level = t:GetFrameLevel()
    t.Health = K.CreateBar(t, level + 1)
    t.Border = CreateFrame("Frame", nil, t, "BackdropTemplate")
    t.Border:SetAllPoints()
    t.Border:SetFrameLevel(level + 4)
    local overlay = CreateFrame("Frame", nil, t)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(level + 5)
    t.Name = overlay:CreateFontString(nil, "OVERLAY")
    t.Name:SetJustifyH("LEFT")
    t.Name:SetWordWrap(false)
    t.Highlight = overlay:CreateTexture(nil, "OVERLAY")
    t.Highlight:SetAllPoints(t.Health)
    t.Highlight:SetColorTexture(1, 1, 1, 0.08)
    t.Highlight:Hide()
    -- the member picks a new target (your own: PLAYER_TARGET_CHANGED, in OnGlobalEvent)
    -- hidden (no target, or the holder is): the OnShow hook repaints it when it comes back
    t:SetScript("OnEvent", function(self) if self:IsVisible() then UpdatePartyTarget(self) end end)
    if index > 0 then pcall(t.RegisterUnitEvent, t, "UNIT_TARGET", SLOT_UNITS[index]) end
    t:HookScript("OnShow", UpdatePartyTarget)
    LEM:AddSelectionArea(t)
    targets[index] = t
    return t
end

--------------------------------------------------
-- 11. BLIZZARD'S PARTY FRAMES (hidden with HardHide)
--------------------------------------------------
local function HideBlizzardParty()
    if _G.PartyFrame then K.HardHide("PartyFrame") end
end

--------------------------------------------------
-- 12. EDIT MODE SETTINGS
--------------------------------------------------
local Refresh   -- section 14

-- The defaults of the style in use, for the dialog's reset (FlareUI Style's party frames: its look)
local function StyleDefaults()
    local _, key = S()
    local d = ns.defaults and ns.defaults.profile.unitframes.party
    local base = (d and d[key or "classic"]) or {}
    local ring = key ~= "raid" and ns.UFRing and ns.UFRing.TileDefaults("party")
    if not ring then return base end
    return setmetatable({}, { __index = function(_, k)
        if ring[k] ~= nil then return ring[k] end
        return base[k]
    end })
end

local RebuildSettings   -- the dialog is rebuilt when the style changes

local function BuildSettings()
    local D = StyleDefaults()
    local function getS(key)
        return function()
            local st = S()
            local v = st and st[key]
            if v == nil then return D[key] end
            return v
        end
    end
    local function setS(key)
        return function(_, value)
            local st = S()
            if not st then return end
            st[key] = value
            Refresh()
        end
    end
    local function getP(key, default)
        return function()
            local party = GetPartyDb()
            local v = party and party[key]
            if v == nil then return default end
            return v
        end
    end
    local function setP(key)
        return function(_, value)
            local party = GetPartyDb()
            if not party then return end
            party[key] = value
            Refresh()
        end
    end
    local function classicOnly() return IsRaidStyle() end
    -- Pets / Party Targets: the place, with its switch kept in step
    local SIDE_PLACES = {
        { text = L["Off"], value = "OFF", isRadio = true },
        { text = L["Bottom of the Frame"], value = "BOTTOM", isRadio = true },
        { text = L["Right of the Frame"], value = "RIGHT", isRadio = true },
    }
    local function SetPlace(key, switch)
        return function(_, value)
            local party = GetPartyDb()
            if not party then return end
            party[key] = value
            party[switch] = value ~= "OFF"
            Refresh()
            LEM:RefreshFrameSettings(holder)
        end
    end
    local ringPortrait = ns.UFRing and ns.UFRing.Style() ~= "addon"
    -- Show Player: FlareUI Style's party leaves you out by default
    local group = ns.UFRing and ns.UFRing.TileDefaults("partyGroup")
    local showPlayerDefault = true
    if group and group.showPlayer ~= nil then showPlayerDefault = group.showPlayer end

    local Section, settings = K.EditSections()

    Section("Party", {
        { name = L["Style"], kind = LEM.SettingType.Dropdown, default = "classic",
          values = { { text = L["Classic"], value = "classic", isRadio = true }, { text = L["Raid Style"], value = "raid", isRadio = true } },
          desc = L["Classic: the player frame's look. Raid-Style: compact tiles with the auras inside. Each style keeps its own settings."],
          get = getP("style", "classic"),
          set = function(_, value)
              local party = GetPartyDb()
              if not party then return end
              party.style = value
              Refresh()
              RebuildSettings()
          end },
        { name = L["Orientation"], kind = LEM.SettingType.Dropdown, default = "VERTICAL",
          values = { { text = L["Vertical"], value = "VERTICAL", isRadio = true }, { text = L["Horizontal"], value = "HORIZONTAL", isRadio = true } },
          get = getP("orientation", "VERTICAL"),
          set = function(layoutName, value) setP("orientation")(layoutName, value); LEM:RefreshFrameSettings(holder) end },
        -- in a row, Down / Up read as Right / Left
        { name = L["Growth"], kind = LEM.SettingType.Dropdown, default = "DOWN",
          values = function()
              if Horizontal() then
                  return { { text = L["Right"], value = "DOWN", isRadio = true }, { text = L["Left"], value = "UP", isRadio = true } }
              end
              return { { text = L["Down"], value = "DOWN", isRadio = true }, { text = L["Up"], value = "UP", isRadio = true } }
          end,
          desc = L["Which way the frames go from the first member."],
          get = getP("grow", "DOWN"), set = setP("grow") },
        { name = L["Pets"], kind = LEM.SettingType.Dropdown, default = "OFF", values = SIDE_PLACES,
          get = PetPlace, set = SetPlace("petPlace", "pets"),
          desc = L["A small frame for each pet: under its owner, or beside it. Its size is in the Pet section."] },
        { name = L["Party Targets"], kind = LEM.SettingType.Dropdown, default = "OFF", values = SIDE_PLACES,
          get = TargetPlace, set = SetPlace("targetPlace", "targets"),
          desc = L["What each member is targeting, in a small frame under theirs or beside it. Click one to target it too. Its size is in the Target section."] },
        { name = L["Spacing"], kind = LEM.SettingType.Slider, default = D.spacing, minValue = 0, maxValue = 80, valueStep = 1,
          get = getS("spacing"), set = setS("spacing"),
          desc = L["The gap between the frames. Each style keeps its own."] },
        { name = L["Sort by Role"], kind = LEM.SettingType.Checkbox, default = true, get = getP("sortByRole", true), set = setP("sortByRole"),
          desc = L["Tanks first, then healers, then damage dealers. A change during combat is applied when the fight ends."] },
        { name = L["Show Player"], kind = LEM.SettingType.Checkbox, default = showPlayerDefault, get = getP("showPlayer", showPlayerDefault),
          set = function(layoutName, value)
              setP("showPlayer")(layoutName, value)
              LEM:RefreshFrameSettings(holder)
              if ns.UnitFrames.RefreshPartyHide then ns.UnitFrames:RefreshPartyHide() end
          end,
          desc = L["Your own frame first, with the party."] },
        { name = L["Hide Player Frame in a Party"], kind = LEM.SettingType.Checkbox, default = false,
          get = getP("hidePlayerInParty", false),
          set = function(_, value)
              local party = GetPartyDb()
              if not party then return end
              party.hidePlayerInParty = value
              if ns.UnitFrames.RefreshPartyHide then ns.UnitFrames:RefreshPartyHide() end
          end,
          hidden = function() return not getP("showPlayer", showPlayerDefault)() end,
          desc = L["Your player and pet frames hide while you're in a party, and come back solo and in a raid. Your frame in the party has the same right-click menu."] },
    })

    -- Forever Style (classic look): the plate keeps Blizzard's proportions; Scale sizes it
    local function onPlate() return PlateStyle() and not IsRaidStyle() end
    Section("Frame", {
        { name = L["Scale"], kind = LEM.SettingType.Slider, default = ns.UFRing and ns.UFRing.PlateDefaultScale("party") or 100,
          minValue = 75, maxValue = 250, valueStep = 5, formatter = function(value) return value .. "%" end,
          get = function() local st = S(); return st and st.plateScale or (ns.UFRing and ns.UFRing.PlateDefaultScale("party")) or 100 end,
          set = function(_, value)
              if not onPlate() then return end
              ns.UFRing.ApplyPlateScale(S(), value)
              Refresh()
          end,
          hidden = function() return not onPlate() end },
        { name = L["Width"], kind = LEM.SettingType.Slider, default = D.width, minValue = 60, maxValue = 400, valueStep = 2, get = getS("width"), set = setS("width") },
        { name = L["Height"], kind = LEM.SettingType.Slider, default = D.height, minValue = 20, maxValue = 120, valueStep = 1, get = getS("height"), set = setS("height"),
          hidden = onPlate },
        { name = L["Power Bar Height"], kind = LEM.SettingType.Slider, default = D.powerHeight, minValue = 0, maxValue = 30, valueStep = 1,
          get = getS("powerHeight"), set = setS("powerHeight"), formatter = function(value) return value == 0 and _G.OFF or value end,
          hidden = onPlate },
        { name = L["Portrait Size"], kind = LEM.SettingType.Slider, default = ns.UFRing and ns.UFRing.DefaultSize("party") or 80,
          minValue = 36, maxValue = 120, valueStep = 1,
          get = function() local st = S(); return st and st.ringSize or (ns.UFRing and ns.UFRing.DefaultSize("party")) or 80 end,
          set = setS("ringSize"), hidden = function() return not RingKind({}) or onPlate() end },
        -- the ring always holds a portrait (no None; 3D by default)
        { name = L["Portrait"], kind = LEM.SettingType.Dropdown, default = ringPortrait and "3d" or D.portrait or "none",
          values = ringPortrait and { { text = L["3D"], value = "3d", isRadio = true }, { text = L["Class Icon"], value = "class", isRadio = true } }
              or { { text = L["None"], value = "none", isRadio = true }, { text = L["3D"], value = "3d", isRadio = true }, { text = L["Class Icon"], value = "class", isRadio = true } },
          get = function()
              local v = getS("portrait")()
              if ringPortrait and (v == nil or v == "none") then return "3d" end
              return v
          end,
          set = setS("portrait"), hidden = classicOnly },
        { name = L["Health Text"], kind = LEM.SettingType.Dropdown, default = D.healthText, values = K.HEALTH_TEXT_MODES, get = getS("healthText"), set = setS("healthText") },
        { name = L["Power Text"], kind = LEM.SettingType.Dropdown, default = "value", values = K.POWER_TEXT_MODES,
          get = function() local st = S(); return K.PowerTextMode(st and st.powerText) end, set = setS("powerText"), hidden = classicOnly },
        { name = L["Show Level"], kind = LEM.SettingType.Checkbox, default = D.showLevel ~= false, get = getS("showLevel"), set = setS("showLevel") },
    })

    -- buffs, debuffs and dispel icons never share a place: clashing places grey out
    local AURA_FIELDS = { "buffs", "debuffs", "dispels" }
    local PARTY_PLACES = PF.AuraPlaces("LEFT")
    local function Place(field)
        return function(_, rootDescription, data)
            local st = S()
            for _, p in ipairs(PARTY_PLACES) do
                -- (Forever Style's plate: no inside places)
                if not (PlateStyle() and not IsRaidStyle() and IsInsidePlace(p.value)) then
                    local radio = rootDescription:CreateRadio(p.text,
                        function(value) local now = S(); return now and now[field] == value end,
                        function(value) data.set(nil, value) end, p.value)
                    if st and radio.SetEnabled then
                        for _, other in ipairs(AURA_FIELDS) do
                            if other ~= field and PlacesClash(p.value, st[other]) then radio:SetEnabled(false) end
                        end
                    end
                end
            end
        end
    end
    Section("Look", {
        { name = L["Bar Texture"], kind = LEM.SettingType.Dropdown, default = D.texture, values = K.BuildTextureValues(),
          get = getS("texture"), set = setS("texture") },
        { name = L["Border"], kind = LEM.SettingType.Dropdown, default = D.border, values = K.BuildBorderValues(false),
          get = getS("border"), set = setS("border"), hidden = K.NoBorderOptions },
        { name = L["Absorb Texture"], kind = LEM.SettingType.Dropdown, default = D.absorbTexture, values = K.BuildAbsorbValues(),
          get = getS("absorbTexture"), set = setS("absorbTexture"),
          desc = L["The texture of the shield (absorb) over the health bar."] },
        (function()
            local item = K.BgOpacitySetting(K.BAR_BG_OPACITY,
                function() local v = getS("bgOpacity")(); if v == nil then return K.BAR_BG_OPACITY end; return v end,
                setS("bgOpacity"))
            item.hidden = onPlate
            return item
        end)(),
        K.ClassColorSetting(function() return ns.ClassColorsOn(S()) end, setS("classColor")),
        K.SmoothBarsSetting(getS("smoothBars"), setS("smoothBars")),
        { name = L["Range Check"], kind = LEM.SettingType.Checkbox, default = true,
          desc = L["The frame fades while the unit is out of your range. Off, it always shows in full."],
          get = function() return getS("rangeCheck")() ~= false end, set = setS("rangeCheck") },
    })

    local function noCast() return not getS("castbar")() end
    Section("Cast Bar", {
        { name = L["Cast Bars"], kind = LEM.SettingType.Checkbox, default = D.castbar or false, get = getS("castbar"),
          set = function(layoutName, value) setS("castbar")(layoutName, value); LEM:RefreshFrameSettings(holder) end },
        { name = L["Cast Bar Texture"], kind = LEM.SettingType.Dropdown, default = D.castTexture, values = K.BuildTextureValues(),
          get = getS("castTexture"), set = setS("castTexture"), hidden = noCast, },
        { name = L["Cast Bar Border"], kind = LEM.SettingType.Dropdown, default = D.castBorderTexture, values = K.BuildBorderValues(true),
          get = getS("castBorderTexture"), set = setS("castBorderTexture"),
          hidden = function() return noCast() or K.NoBorderOptions() end,
          desc = L["Frame Border uses the frame's own border."] },
        { name = L["Cast Bar Height"], kind = LEM.SettingType.Slider, default = D.castHeight, minValue = 8, maxValue = 30, valueStep = 1,
          get = getS("castHeight"), set = setS("castHeight"), hidden = noCast },
        { name = L["Hide Icon"], kind = LEM.SettingType.Checkbox, default = false,
          get = function() return getS("castIcon")() == false end,
          set = function(layoutName, value) setS("castIcon")(layoutName, not value) end,
          hidden = noCast,
          desc = L["No spell icon left of the bar."] },
        { name = L["Hide Spell Timer"], kind = LEM.SettingType.Checkbox, default = false,
          get = function() return getS("castTimer")() == false end,
          set = function(layoutName, value) setS("castTimer")(layoutName, not value) end,
          hidden = noCast,
          desc = L["No time left at the right end of the bar."] },
    })

    Section("Auras", {
        { name = L["Buffs"], kind = LEM.SettingType.Dropdown, default = D.buffs, values = PARTY_PLACES, generator = Place("buffs"),
          get = getS("buffs"), set = setS("buffs"),
          desc = L["Buffs as Blizzard's raid frames pick them: mostly your own heals over time and buffs."] },
        { name = L["Debuffs"], kind = LEM.SettingType.Dropdown, default = D.debuffs, values = PARTY_PLACES, generator = Place("debuffs"),
          get = getS("debuffs"), set = setS("debuffs"),
          desc = L["Debuffs as Blizzard's raid frames pick them: boss and role debuffs, priority debuffs, and the ones you can dispel."] },
        K.HideBuffsSetting("PERMANENT", function() return getS("hideBuffs")() or "PERMANENT" end, setS("hideBuffs")),
        { name = L["Dispel Highlight"], kind = LEM.SettingType.Dropdown, default = D.dispelHighlight,
          values = { { text = L["Off"], value = "off", isRadio = true }, { text = L["Dispellable by Me"], value = "mine", isRadio = true },
                     { text = L["Dispellable by the Group"], value = "all", isRadio = true } },
          desc = L["A dispellable debuff colours the frame's border in its type's colour."],
          get = getS("dispelHighlight"), set = setS("dispelHighlight") },
        { name = L["Buff Size"], kind = LEM.SettingType.Slider, default = D.auraSize, minValue = 10, maxValue = 40, valueStep = 1,
          get = function() return ns.AuraSize(S(), false, D.auraSize) end, set = setS("buffSize") },
        { name = L["Debuff Size"], kind = LEM.SettingType.Slider, default = D.auraSize, minValue = 10, maxValue = 40, valueStep = 1,
          get = function() return ns.AuraSize(S(), true, D.auraSize) end, set = setS("debuffSize") },
        { name = L["Only My Buffs"], kind = LEM.SettingType.Checkbox, default = true,
          get = function() return getS("onlyMyBuffs")() ~= false end, set = setS("onlyMyBuffs"),
          desc = L["Only the buffs you cast (your heals over time, your blessings). Off: everyone's buffs."] },
        { name = L["Dispellable Debuffs Only"], kind = LEM.SettingType.Checkbox, default = false,
          get = function() return getS("dispellableOnly")() and true or false end, set = setS("dispellableOnly"),
          desc = L["Only the debuffs you can dispel, plus boss debuffs and other important ones, as on Blizzard's raid frames."] },
        -- a dispel icon per type you can dispel, on the portrait (or the health bar's middle)
        { name = L["Dispel Icons"], kind = LEM.SettingType.Checkbox, default = D.dispels ~= "OFF",
          get = function() local st = S(); local v = st and st.dispels; if v == nil then v = D.dispels end; return v ~= "OFF" end,
          set = function(_, value) setS("dispels")(nil, value and "PORTRAIT" or "OFF") end,
          desc = L["The symbol of each debuff type you can dispel, two to a row in the middle of the portrait (or of the health bar without one)."] },
    })
    Section("Aura Ordering", ns.AuraOrder.Items(getS, setS))

    -- one switch per icon; where they sit is fixed
    local iconItems = {}
    for _, key in ipairs(ICON_ORDER) do
        iconItems[#iconItems + 1] = { name = ICON_LABELS[key], kind = LEM.SettingType.Checkbox, default = true,
            get = function() return IconShown(key) end,
            set = function(_, value)
                local store = IconStore(key, true)
                if not store then return end
                store.shown = value
                Refresh()
            end }
    end
    Section("Icons", iconItems)

    -- the pets' frames, under their owners: only while Pets (Party section) is on
    local function noPets() return not getP("pets", false)() end
    Section("Pet", {
        { name = L["Pet Frame Width"], kind = LEM.SettingType.Slider, default = D.petWidth, minValue = 40, maxValue = 300, valueStep = 2,
          get = getS("petWidth"), set = setS("petWidth"), hidden = noPets },
        { name = L["Pet Frame Height"], kind = LEM.SettingType.Slider, default = D.petHeight, minValue = 10, maxValue = 40, valueStep = 1,
          get = getS("petHeight"), set = setS("petHeight"), hidden = noPets },
        { name = L["Pet Border"], kind = LEM.SettingType.Dropdown, default = D.petBorder, values = K.BuildBorderValues(false),
          get = getS("petBorder"), set = setS("petBorder"), hidden = function() return noPets() or K.NoBorderOptions() end },
    })

    -- the members' targets: only while Party Targets (Party section) is on
    local function noTargets() return not getP("targets", false)() end
    Section("Target", {
        { name = L["Target Frame Width"], kind = LEM.SettingType.Slider, default = D.targetWidth, minValue = 40, maxValue = 300, valueStep = 2,
          get = getS("targetWidth"), set = setS("targetWidth"), hidden = noTargets },
        { name = L["Target Frame Height"], kind = LEM.SettingType.Slider, default = D.targetHeight, minValue = 12, maxValue = 60, valueStep = 1,
          get = getS("targetHeight"), set = setS("targetHeight"), hidden = noTargets },
        { name = L["Target Border"], kind = LEM.SettingType.Dropdown, default = D.targetBorder, values = K.BuildBorderValues(false),
          get = getS("targetBorder"), set = setS("targetBorder"), hidden = function() return noTargets() or K.NoBorderOptions() end },
    })
    return settings
end

RebuildSettings = function()
    if not holder then return end
    LEM:AddFrameSettings(holder, BuildSettings())
    C_Timer.After(0, function() if holder then LEM:RefreshFrameSettings(holder) end end)
end

--------------------------------------------------
-- 13. PUBLIC
--------------------------------------------------
-- A member's target sends no health events: the shown ones are re-read while Party Targets is on
local targetTicker
local function UpdateTargetTicker()
    local on = GetPartyDb().targets
    if on and not targetTicker then
        targetTicker = C_Timer.NewTicker(TARGET_INTERVAL, function()
            if not (holder and holder:IsShown()) or IsEditing() then return end
            for i = 0, MAX_MEMBERS do
                local t = targets[i]
                if t and t:IsShown() then UpdatePartyTarget(t) end
            end
        end)
    elseif not on and targetTicker then
        targetTicker:Cancel()
        targetTicker = nil
    end
end

Refresh = function()
    if not holder then return end
    if InCombatLockdown() then pendingLayout = true return end
    pendingLayout = false
    for i = 0, MAX_MEMBERS do
        local f = members[i]
        local ok, err = pcall(LayoutMember, f)
        if not ok then geterrorhandler()(err) end
        if pets[i] then pcall(LayoutPet, pets[i]) end
        if targets[i] then pcall(LayoutTarget, targets[i]) end
    end
    LayoutHolder()
    ApplyPosition()
    ApplyVisibility()
    for i = 0, MAX_MEMBERS do
        UpdateAll(members[i])
        if pets[i] then UpdatePet(pets[i]) end
        if targets[i] and targets[i]:IsShown() then UpdatePartyTarget(targets[i]) end
    end
    UpdateTargetTicker()
end

function PF:Refresh()
    Refresh()
end

-- The tile kit (RaidFrames.lua and BossFrames.lua build their tiles with it). A tile's owner sets f.ctx:
--   Settings()     the tile settings (the party style's keys, plus auraMax and auraPerRow)
--   PreviewData(f) the sample shown in Edit Mode
--   ReadyHold()    true while a finished ready check's results stay up
--   classic        the classic look (else Raid-Style); mirror: laid out as the target frame
--   hostile        enemy units: their buffs and the player's debuffs, no range fading
--   castbar        the tile has a cast bar
PF.Tile = {
    Build = BuildTile, SetUnit = SetTileUnit, Layout = LayoutMember, UpdateAll = UpdateAll,
    UpdateRange = UpdateRange, UpdateTarget = UpdateTarget, UpdateRaidIcon = UpdateRaidIcon,
    UpdateLeader = UpdateLeader, UpdateRole = UpdateRole, UpdatePower = UpdatePower,
    UpdateReadyCheck = UpdateReadyCheck, UpdateStatus = UpdateStatus,
    OnEnter = OnEnter, OnLeave = OnLeave, ICON_ORDER = ICON_ORDER, ICON_LABELS = ICON_LABELS,
    PlacesClash = PlacesClash, ABOVE_PLACES = ABOVE_PLACES, BELOW_PLACES = BELOW_PLACES,
    IconShown = IconShown, IconStore = IconStore, LanesExtent = LanesExtent,
}

-- A settings preview's sample tile (11-10): a plain button with no unit, mouse or auras, built and laid
-- out by the tile kit, showing the Edit Mode sample. ctx: the owner's (raid, boss), or nil for the
-- party; index: the party sample's place (PREVIEW)
function PF.SampleTile(parent, ctx, sample, index)
    local f = CreateFrame("Button", nil, parent, "BackdropTemplate")
    f.ctx, f.sample, f.index = ctx, sample, index
    f.noAuras, f.fuiSample = true, true
    BuildTile(f, nil)
    f:EnableMouse(false)
    f:SetScript("OnEnter", nil)
    f:SetScript("OnLeave", nil)
    return f
end
function PF.DrawSampleTile(f)
    LayoutMember(f)
    f.fuiLaid = true
    UpdateAll(f)
    f:Show()
    return f:GetWidth(), f:GetHeight()
end

-- The aura places for a dropdown, without one (the party frames have no Left of the Frame, the
-- boss frames no Right of the Frame: that side faces the screen's edge)
function PF.AuraPlaces(without)
    local list = {}
    for _, p in ipairs(AURA_POSITION_VALUES) do
        if p.value ~= without then list[#list + 1] = p end
    end
    return list
end

function PF:ShouldLoad()
    local db = K and K.GetDb()
    return db and db.enabled and db.party and db.party.enabled and true or false
end

-- Range comes from UNIT_IN_RANGE_UPDATE; every second the shown frames re-check it (in case an event
-- was missed) and their aura reach, which has no event
local rangeTicker
local function StartRangeTicker()
    if rangeTicker then return end
    rangeTicker = C_Timer.NewTicker(RANGE_INTERVAL, function()
        if not (holder and holder:IsShown()) or IsEditing() then return end
        for i = 1, MAX_MEMBERS do
            local f = members[i]
            if f and f:IsShown() then UpdateRange(f) end
        end
        -- the pets too, your own among them (index 0)
        for i = 0, MAX_MEMBERS do
            local p = pets[i]
            if p and p:IsVisible() then UpdateRange(p) end
        end
    end)
end

function PF:OnGlobalEvent(event, ...)
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingLayout then Refresh() end
        return
    end
    if IsEditing() then return end
    -- only the party's own pets concern these frames (in a raid every raid pet sends UNIT_PET)
    if event == "UNIT_PET" then
        local unit = ...
        if canaccessvalue(unit) then
            local ours = false
            for i = 0, MAX_MEMBERS do if SLOT_UNITS[i] == unit then ours = true end end
            if not ours then return end
        end
    end
    -- a new member or role re-places the frames (after combat when in one). While the holder is
    -- hidden (solo, in a raid) that waits for its OnShow (see Init).
    local party = GetPartyDb()
    if ((event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED") and party.sortByRole)
        or ((event == "GROUP_ROSTER_UPDATE" or event == "UNIT_PET") and party.pets) then
        if holder:IsShown() or InCombatLockdown() then
            LayoutHolder()
        else
            holder.layoutStale = true
        end
    end
    if event == "READY_CHECK_FINISHED" then
        if readyCheckHold then readyCheckHold:Cancel() end
        readyCheckHold = C_Timer.NewTimer(READY_CHECK_HOLD, function()
            readyCheckHold = nil
            for i = 0, MAX_MEMBERS do if members[i] then members[i].lastReady = nil; UpdateReadyCheck(members[i]) end end
        end)
    elseif event == "READY_CHECK" then
        if readyCheckHold then readyCheckHold:Cancel(); readyCheckHold = nil end
    end
    local own = targets[0]
    if event == "PLAYER_TARGET_CHANGED" and own and own:IsShown() then UpdatePartyTarget(own) end
    for i = 0, MAX_MEMBERS do
        local f = members[i]
        if f and f:IsVisible() then
            if event == "PLAYER_TARGET_CHANGED" then
                UpdateTarget(f)
            elseif event == "RAID_TARGET_UPDATE" then
                UpdateRaidIcon(f)
            elseif event == "READY_CHECK" or event == "READY_CHECK_CONFIRM" or event == "READY_CHECK_FINISHED" then
                UpdateReadyCheck(f)
            elseif event == "INCOMING_SUMMON_CHANGED" or event == "INCOMING_RESURRECT_CHANGED" then
                UpdateStatus(f)
            elseif event == "PARTY_LEADER_CHANGED" then
                UpdateLeader(f)
            elseif event == "PORTRAITS_UPDATED" then
                UpdatePortrait(f)
            elseif event == "PLAYER_ROLES_ASSIGNED" then
                UpdateRole(f)
                UpdatePower(f)
            elseif event ~= "UNIT_PET" then
                UpdateAll(f)
            end
        end
        -- a pet under a hidden holder is repainted by its OnShow instead
        local p = pets[i]
        if p and p:IsVisible() and (event == "GROUP_ROSTER_UPDATE" or event == "UNIT_PET" or event == "PLAYER_ENTERING_WORLD") then
            UpdatePet(p)
        end
    end
end

local GLOBAL_EVENTS = {
    "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "RAID_TARGET_UPDATE", "PLAYER_TARGET_CHANGED",
    "PLAYER_ROLES_ASSIGNED", "READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED",
    "INCOMING_SUMMON_CHANGED", "INCOMING_RESURRECT_CHANGED", "PLAYER_ENTERING_WORLD", "UNIT_PET",
    "PLAYER_REGEN_ENABLED", "PORTRAITS_UPDATED",
}

function PF:Init()
    if self.initialized or not K then return end
    if InCombatLockdown() then
        -- secure frames cannot be created in combat (a /reload mid-fight): wait for it to end
        self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            self:Init()
        end)
        return
    end
    self.initialized = true

    -- Left of the Frame is not offered: saved auras there move to the right (off when taken)
    local party = GetPartyDb()
    for _, key in ipairs({ "classic", "raid" }) do
        local st = party and party[key]
        if st then
            for _, field in ipairs({ "buffs", "debuffs" }) do
                if st[field] == "LEFT" then
                    local other = field == "buffs" and "debuffs" or "buffs"
                    st[field] = st[other] == "RIGHT" and "OFF" or "RIGHT"
                end
            end
        end
    end

    holder = CreateFrame("Frame", "FlareUI_Party", UIParent)
    holder:SetFrameStrata("LOW")
    holder:SetClampedToScreen(true)
    holder:SetSize(200, 200)
    holder.editModeName = "FlareUI Party Frames"
    -- roster and pet changes while hidden skip the layout (OnGlobalEvent): it catches up here
    -- (after combat when it shows in one: LayoutHolder defers to Refresh)
    holder:HookScript("OnShow", function(self)
        if self.layoutStale then
            self.layoutStale = nil
            LayoutHolder()
        end
    end)
    for i = 0, MAX_MEMBERS do CreateMember(i) end
    for i = 0, MAX_MEMBERS do CreatePet(i) end
    for i = 0, MAX_MEMBERS do CreatePartyTarget(i) end

    LEM:AddFrame(holder, OnFrameMoved, DEFAULT_POSITION, "FlareUI Party Frames")
    LEM:AddFrameSettings(holder, BuildSettings())
    HideBlizzardParty()

    for _, event in ipairs(GLOBAL_EVENTS) do self:RegisterEvent(event, "OnGlobalEvent") end

    LEM:RegisterCallback("layout", function(layoutName) ApplyPosition(layoutName) end)
    local function ShowPreview()
        ApplyVisibility()
        LayoutHolder()   -- the sample pets take their room
        -- Hide Buffs is skipped in Edit Mode (samples have no duration): not protected, fine in combat
        for i = 0, MAX_MEMBERS do ConfigureAuras(members[i]) end
        SetAuraPreview(true)
        for i = 0, MAX_MEMBERS do UpdateAll(members[i]) end
    end
    local function EndPreview()
        ApplyVisibility()
        SetAuraPreview(false)
        Refresh()
    end
    LEM:RegisterCallback("enter", ShowPreview)
    LEM:RegisterCallback("exit", EndPreview)
    ns.OnEditFight(function() if IsEditing() then ShowPreview() else EndPreview() end end)

    StartRangeTicker()
    Refresh()
    C_Timer.After(0, Refresh)
end
