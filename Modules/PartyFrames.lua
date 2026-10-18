local _, ns = ...
local L = ns.L

--------------------------------------------------
-- PARTY FRAMES
-- You (optional) and up to four party members, in one of two styles with their own settings:
--   Classic     the player frame's look, auras beside the frame
--   Raid-Style  compact tiles, auras inside
-- Auras are sorted by Blizzard's raid frame rules (the containers' ProcessAura policy). Secret-safe
-- as the unit frames are: values go straight into widgets, readable() guards every Lua test.
-- Part of the Unit Frames module; tuned in Edit Mode. Blizzard's PartyFrame is parked.
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

-- The aura look the party shares with the unit frames (Settings > Unit Frames: shape and timer)
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
-- the default in use (FlareUI Style's party has its own); Edit Mode's reset keeps this table
local DEFAULT_POSITION = { point = "LEFT", x = 3, y = 0 }
local PET_GAP = 2
local TARGET_GAP = 6                 -- gap between a party frame and its target
local TARGET_INTERVAL = 0.2          -- a member's target sends no health events: re-read this often
local PREVIEW_HOSTILE_RGB = { 0.87, 0.27, 0.27 }
local AURA_SPACING = 2
local AURA_CONTAINER_TEMPLATE = "CustomAuraContainerTemplate"
local READY_CHECK_HOLD = 6           -- seconds the result stays after a ready check ends
local RANGE_INTERVAL = 0.5
local RANGE_ALPHA = 0.45             -- a member out of range
-- auras per lane and per row, by party style (an owner's view gives its own: auraMax, auraPerRow)
local PARTY_AURA_GRID = { classic = { 5, 5 }, raid = { 6, 3 } }

-- Where a lane of auras can go: beside / above / below the frame, or inside the health bar; the
-- *_WIDE and INSIDE_TOP / INSIDE_BOTTOM places take the whole width (and PORTRAIT: the party frames'
-- dispel icons, on the portrait or the health bar's middle)
local AURA_POSITIONS = { "RIGHT", "LEFT", "ABOVE", "ABOVE_RIGHT", "ABOVE_WIDE", "BELOW", "BELOW_RIGHT", "BELOW_WIDE",
                         "INSIDE_TOPLEFT", "INSIDE_TOPRIGHT", "INSIDE_TOP", "INSIDE_BOTTOMLEFT", "INSIDE_BOTTOMRIGHT",
                         "INSIDE_BOTTOM", "PORTRAIT" }
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
-- the places along one edge, and the whole-width ones: a whole-width place shares its edge with
-- nothing, so it greys out the others on that edge (and they grey it out)
local PLACE_EDGE = { ABOVE = "above", ABOVE_RIGHT = "above", ABOVE_WIDE = "above",
                     BELOW = "below", BELOW_RIGHT = "below", BELOW_WIDE = "below",
                     INSIDE_TOPLEFT = "insideTop", INSIDE_TOPRIGHT = "insideTop", INSIDE_TOP = "insideTop",
                     INSIDE_BOTTOMLEFT = "insideBottom", INSIDE_BOTTOMRIGHT = "insideBottom", INSIDE_BOTTOM = "insideBottom" }
local WIDE_PLACES = { ABOVE_WIDE = true, BELOW_WIDE = true, INSIDE_TOP = true, INSIDE_BOTTOM = true }
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

-- Edit Mode sample group: a tank, a healer and three damage dealers (portrait: a face for the 3D
-- portrait's place)
local PREVIEW = {
    { name = "Thalorien", class = "WARRIOR", role = "TANK",    health = 0.92, power = 0.35, leader = true,
      portrait = "Interface\\Icons\\INV_Misc_Head_Human_01" },
    { name = "Elysande",  class = "PRIEST",  role = "HEALER",  health = 0.64, power = 0.85, ready = "ready",
      portrait = "Interface\\Icons\\INV_Misc_Head_Elf_02" },
    { name = "Morwen",    class = "WARLOCK", role = "DAMAGER", health = 0.48, power = 0.60, marker = 8, highlight = "Magic", pet = "Voidwalker", missing = { "int" },
      portrait = "Interface\\Icons\\INV_Misc_Head_Undead_02" },
    { name = "Sylvara",   class = "HUNTER",  role = "DAMAGER", health = 0.81, power = 0.72, pet = "Wolf", missing = { "fort", "mark" }, status = "IncomingResurrection",
      portrait = "Interface\\Icons\\INV_Misc_Head_Troll_02" },
    { name = "Kestrel",   class = "ROGUE",   role = "DAMAGER", health = 0.27, power = 0.90, status = "IncomingSummonPending",
      portrait = "Interface\\Icons\\INV_Misc_Head_Gnome_01" },
}
-- their targets (Party > Show Party Targets): the healer on the tank, everyone else on the enemy
local PREVIEW_TARGETS = {
    { name = "Defias Pillager", health = 0.58 },
    { name = "Thalorien", class = "WARRIOR", health = 0.92 },
    { name = "Defias Pillager", health = 0.58 },
    { name = "Defias Pillager", health = 0.58 },
    { name = "Defias Pillager", health = 0.58 },
}
-- sample class colours and power types, independent of the API
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

-- A tile's settings: its owner's when it has one (f.ctx: the raid and boss frames), else the party style's
local function TS(f)
    if f and f.ctx then return f.ctx.Settings() end
    return S()
end

-- A Raid-Style tile: the party in raid style, or a tile with an owner of its own (unless the owner
-- asks for the classic look: the boss frames)
local function RaidTile(f)
    if f and f.ctx then return not f.ctx.classic end
    return IsRaidStyle()
end

-- A mirrored tile (the boss frames, as the target frame): portrait on the right, bars filling right
-- to left, level and name on the right, the numbers on the left
local function Mirrored(f)
    return f and f.ctx and f.ctx.mirror and true or false
end

-- How many auras a lane holds, and how many to a row
local function AuraGrid(st)
    local party = GetPartyDb()
    local grid = party and (st == party.raid and PARTY_AURA_GRID.raid or st == party.classic and PARTY_AURA_GRID.classic)
    if grid then return grid[1], grid[2] end
    return st.auraMax, st.auraPerRow
end

-- Above or below the frame, as on the unit frames: each lane wraps a little before the frame's
-- middle, two rows at most, so the frame's width and the aura size set how many fit (elsewhere: the
-- fixed grid)
-- The whole-width places fill the frame's width (inside: the health bar's, in as many rows as the
-- fixed grid has), less the portrait ring's room on its side (f: the tile, when there is one).
local EDGE_PLACES = { ABOVE = true, ABOVE_RIGHT = true, ABOVE_WIDE = true, BELOW = true, BELOW_RIGHT = true, BELOW_WIDE = true }
local function AuraFit(st, pos, f)
    local size = st.auraSize or 18
    local function PerRow(lineSize)
        return math_max(2, math_floor((math_max(size, lineSize) + AURA_SPACING) / (size + AURA_SPACING)))
    end
    if pos == "INSIDE_TOP" or pos == "INSIDE_BOTTOM" then
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
    return 2 * perRow, perRow
end

-- A side and its opposite, swapped on a mirrored tile, and which way +x goes from the near side
local function Sides(f)
    if Mirrored(f) then return "RIGHT", "LEFT", -1 end
    return "LEFT", "RIGHT", 1
end

-- FlareUI Style: the party frames (not Raid-Style) and the boss frames (ctx.ringKind) take the unit
-- frames' portrait ring (UnitFramesRing.lua). Set on the tile at its layout as f.ringKind.
local function RingKind(f)
    if RaidTile(f) or not (ns.UFRing and ns.UFRing.Style() == "flareui") then return nil end
    if f.ctx then return f.ctx.ringKind end
    return "party"
end

-- The party frames' Dispel Icons (a switch): up to four, two to a row, in the portrait's middle (the
-- health bar's without a portrait). Any older place counts as on. Other tiles keep theirs.
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

local function IsEditing()
    return LEM:IsInEditMode()
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
local function UpdateName(f)
    f.Name:SetText(ns.UnitDisplayName(f.unit) or "")
end

local function UpdateLevel(f)
    local st = TS(f)
    if not (st and st.showLevel) then f.Level:SetText("") return end
    local level = UnitLevel(f.unit)
    if canaccessvalue(level) and level then
        if level < 0 then
            f.Level:SetText("??")
            f.Level:SetTextColor(1, 0.1, 0.1)
        else
            f.Level:SetFormattedText("%d", level)
            -- friendly (nothing you can attack): Blizzard's gold; the rest by difficulty
            local color = GetQuestDifficultyColor and GetQuestDifficultyColor(level)
            if readable(UnitCanAttack("player", f.unit)) == false then
                f.Level:SetTextColor(1, 0.82, 0)
            elseif color then f.Level:SetTextColor(color.r, color.g, color.b) else f.Level:SetTextColor(1, 1, 1) end
        end
    else
        f.Level:SetText(level)
        f.Level:SetTextColor(1, 1, 1)
    end
end

local function UpdateHealth(f)
    local unit, st = f.unit, TS(f)
    local bar = f.Health
    bar:SetMinMaxValues(0, UnitHealthMax(unit))
    bar:SetValue(UnitHealth(unit))
    bar:SetStatusBarColor(K.GetHealthColor(unit, ns.ClassColorsOn()))

    local mode = st and st.healthText or "percent"
    local text = f.HealthText
    if not UnitIsConnected(unit) then
        text:SetText(K.OFFLINE_TEXT)
    elseif UnitIsDeadOrGhost(unit) then
        text:SetText(UnitIsGhost(unit) and K.GHOST_TEXT or K.DEAD_TEXT)
    elseif mode == "percent" then
        text:SetFormattedText("%.0f%%", UnitHealthPercent(unit, true, K.percentCurve))
    elseif mode == "value" then
        text:SetText(AbbreviateNumbers(UnitHealth(unit)))
    elseif mode == "both" then
        text:SetFormattedText("%s | %.0f%%", AbbreviateNumbers(UnitHealth(unit)), UnitHealthPercent(unit, true, K.percentCurve))
    else
        text:SetText("")
    end
end

local LayoutBars   -- section 6

-- the power bar: on every tile with a power bar height
local function WantsPower(f)
    local st = TS(f)
    return st and (st.powerHeight or 0) > 0 or false
end

local function UpdatePower(f)
    local unit, st = f.unit, TS(f)
    local want = WantsPower(f)
    if want ~= f.powerShown then
        f.powerShown = want
        LayoutBars(f)
    end
    if not want then return end
    local bar = f.Power
    local powerType = UnitPowerType(unit)
    bar:SetMinMaxValues(0, UnitPowerMax(unit, powerType))
    bar:SetValue(UnitPower(unit, powerType))
    bar:SetStatusBarColor(K.GetPowerColor(unit))
    if st and st.powerText and not RaidTile(f) and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) then
        f.PowerText:SetText(AbbreviateNumbers(UnitPower(unit, powerType)))
    else
        f.PowerText:SetText("")
    end
end

-- Incoming heals and absorbs, clipped to the empty part of the health bar (as UnitFrames.lua)
local function UpdateHealPrediction(f)
    local heal, absorb = f.HealBar, f.AbsorbBar
    if not heal then return end
    local unit = f.unit
    local max = UnitHealthMax(unit)
    heal:SetMinMaxValues(0, max)
    absorb:SetMinMaxValues(0, max)
    local calc = f.HealCalc
    if calc and UnitGetDetailedHealPrediction then
        if pcall(UnitGetDetailedHealPrediction, unit, "player", calc) then
            local okH, incoming = pcall(calc.GetIncomingHeals, calc)
            local okA, absorbs = pcall(calc.GetDamageAbsorbs, calc)
            if okH then heal:SetValue(incoming) end
            if okA then absorb:SetValue(absorbs) end
            return
        end
    end
    pcall(function() heal:SetValue(UnitGetIncomingHeals(unit)) end)
    pcall(function() absorb:SetValue(UnitGetTotalAbsorbs(unit)) end)
end

-- GetRaidTargetIndex is secret to addon code; a secret is never nil, and the texture setter takes it
local function UpdateRaidIcon(f)
    local icon = f.RaidIcon
    if not IconShown("raidIcon", f) then icon:Hide() return end
    local index = GetRaidTargetIndex(f.unit)
    local show
    if not canaccessvalue(index) then show = true else show = index ~= nil and index > 0 end
    if show then SetRaidTargetIconTexture(icon, index) end
    icon:SetShown(show)
end

local function UpdateLeader(f)
    local icon = f.LeaderIcon
    if not IconShown("leader", f) then icon:Hide() return end
    if readable(UnitIsGroupLeader(f.unit)) then
        K.SetIconArt(icon, "UI-HUD-UnitFrame-Player-Group-LeaderIcon", "Interface\\GroupFrame\\UI-Group-LeaderIcon")
        icon:Show()
    elseif readable(UnitIsGroupAssistant(f.unit)) then
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
        f.roleProxy.roleIcon, f.roleProxy.unit = icon, f.unit
        if pcall(util, f.roleProxy) then return end
    end
    local role = readable(UnitGroupRolesAssigned(f.unit))
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
    local status = readable(GetReadyCheckStatus(f.unit))
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

local function CenterStatus(unit)
    if C_IncomingSummon and readable(C_IncomingSummon.HasIncomingSummon(unit)) then
        local status = readable(C_IncomingSummon.IncomingSummonStatus(unit))
        local SS = Enum.SummonStatus
        if SS and status == SS.Pending then return "IncomingSummonPending"
        elseif SS and status == SS.Accepted then return "IncomingSummonAccepted"
        elseif SS and status == SS.Declined then return "IncomingSummonDeclined" end
    end
    if readable(UnitHasIncomingResurrection(unit)) then return "IncomingResurrection" end
    if UnitPhaseReason and readable(UnitPhaseReason(unit)) then return "InOtherPhase" end
    if UnitInOtherParty and readable(UnitInOtherParty(unit)) then return "InPublicGroup" end
    return nil
end

local function UpdateStatus(f)
    local icon = f.StatusIcon
    if not IconShown("status", f) then icon:Hide() return end
    local state = CenterStatus(f.unit)
    local atlas = state and STATUS_ATLAS[state]
    if atlas and K.HasAtlas(atlas) then
        icon:SetAtlas(atlas, false)
        icon:Show()
    else
        icon:Hide()
    end
end

-- Out of range: the whole frame fades (UnitInRange is secret, so the alpha is picked by the client).
-- Your own frame and enemy tiles never fade.
local function UpdateRange(f)
    if f.unit == "player" or (f.ctx and f.ctx.hostile) or IsEditing() then
        f:SetAlpha(1)
        return
    end
    local inRange = UnitInRange(f.unit)
    if f.SetAlphaFromBoolean then
        if not pcall(f.SetAlphaFromBoolean, f, inRange, 1, RANGE_ALPHA) then f:SetAlpha(1) end
    elseif canaccessvalue(inRange) then
        f:SetAlpha(inRange and 1 or RANGE_ALPHA)
    end
end

-- The player's target: a bright outline inside the border
local function UpdateTarget(f)
    local hl = f.TargetHighlight
    if IsEditing() then hl:SetAlpha(0) return end
    local isTarget = UnitIsUnit(f.unit, "target")
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
        status = readable(UnitThreatSituation("player", f.unit))
    else
        status = readable(UnitThreatSituation(f.unit))
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
    local unit = (UnitExists(f.unit) and not IsEditing()) and f.unit or "player"
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

local function UpdateCast(f)
    if f.Cast then K.UpdateCastBar(f.Cast, f.Cast.isEnabled()) end
end

local ApplyPreview, HidePreviewExtras   -- section 9

-- FlareUI Style's ring: the boss frame's elite art, the level skull
local function UpdateRing(f)
    if f.ringKind and ns.UFRing then ns.UFRing.Update(f) end
end

-- Blizzard's aura containers only follow UNIT_AURA for their token: when someone else takes it (a
-- roster change, a new boss in boss1) the last unit's auras would stay beside the new ones, their
-- removals never coming. They rebuild when the unit behind the token changes (every time when its
-- GUID is secret). Not protected: fine in combat.
local function RefreshAurasOnNewUnit(f)
    local guid = UnitGUID(f.unit)
    if not canaccessvalue(guid) then guid = nil end
    if guid and guid == f.auraGUID then return end
    f.auraGUID = guid
    local function Refresh(entry)
        if entry and entry.container:IsShown() then pcall(entry.container.UpdateAllAuras, entry.container) end
    end
    if f.AuraPos then for _, entry in pairs(f.AuraPos) do Refresh(entry) end end
    Refresh(f.AuraSlots)
    Refresh(f.AuraHighlight)
end

local function UpdateAll(f)
    if IsEditing() then
        ApplyPreview(f)
        UpdateRing(f)
        return
    end
    HidePreviewExtras(f)
    if not UnitExists(f.unit) then return end
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

local function UpdatePet(p)
    if IsEditing() then return end
    if not UnitExists(p.unit) then return end
    local unit = p.unit
    p.Health:SetMinMaxValues(0, UnitHealthMax(unit))
    p.Health:SetValue(UnitHealth(unit))
    p.Health:SetStatusBarColor(K.GetHealthColor(unit, false))
    p.Name:SetText(ns.UnitDisplayName(unit) or "")
end

local function UpdatePartyTarget(t)
    if IsEditing() then return end
    local unit = t.unit
    if not UnitExists(unit) then return end
    t.Health:SetMinMaxValues(0, UnitHealthMax(unit))
    t.Health:SetValue(UnitHealth(unit))
    t.Health:SetStatusBarColor(K.GetHealthColor(unit, ns.ClassColorsOn()))
    t.Name:SetText(ns.UnitDisplayName(unit) or "")
end

local function OnMemberEvent(f, event, arg1)
    if IsEditing() then return end
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        UpdateHealth(f)
        UpdateHealPrediction(f)
    elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_POWER_FREQUENT" or event == "UNIT_DISPLAYPOWER" then
        UpdatePower(f)
    elseif event == "UNIT_HEAL_PREDICTION" or event == "UNIT_ABSORB_AMOUNT_CHANGED" then
        UpdateHealPrediction(f)
    elseif event == "UNIT_NAME_UPDATE" then
        UpdateName(f)
    elseif event == "UNIT_LEVEL" then
        UpdateLevel(f)
    elseif event == "UNIT_IN_RANGE_UPDATE" then
        UpdateRange(f)
    elseif event == "UNIT_THREAT_SITUATION_UPDATE" then
        UpdateThreat(f)
    elseif event == "UNIT_PHASE" or event == "UNIT_OTHER_PARTY_CHANGED" then
        UpdateStatus(f)
    elseif event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED" then
        UpdatePortrait(f)
    elseif event:find("^UNIT_SPELLCAST") then
        UpdateCast(f)
    else
        UpdateAll(f)
    end
end

--------------------------------------------------
-- 5. AURAS
-- Blizzard's aura containers render everything (aura data can be secret). One container per place
-- a lane can go, created at login, on the ProcessAura policy (buff / debuff / dispel by Blizzard's
-- raid frame rules). Separate containers hold the big defensive slot and the dispel highlight.
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
            pcall(container.SetUnit, container, f.unit)
            if policy then pcall(container.SetAuraProcessingPolicy, container, policy.ProcessAura, {}) end
            container:SetFrameLevel(f:GetFrameLevel() + 6)
            container:Hide()
            f.AuraPos[pos] = { container = container, groups = {}, generation = 0 }
        end
    end
    local ok, slots = pcall(CreateFrame, "AuraContainer", nil, f, AURA_CONTAINER_TEMPLATE)
    if ok and slots then
        pcall(slots.SetUnit, slots, f.unit)
        slots:SetSize(1, 1)
        slots:SetPoint("CENTER", f, "CENTER")
        slots:SetFrameLevel(f:GetFrameLevel() + 3)
        f.AuraSlots = { container = slots, keys = {}, generation = 0 }
    end
    -- the dispel highlight, kept out of Edit Mode's sample data (ApplyPreview draws its own)
    local okH, hl = pcall(CreateFrame, "AuraContainer", nil, f, AURA_CONTAINER_TEMPLATE)
    if okH and hl then
        pcall(hl.SetUnit, hl, f.unit)
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
end

-- inside the frame: no timer, whatever the Aura Timer setting (it would cover the bars and names)
local function LaneLook(size, isDebuff, inside)
    local timer = inside and "none" or UFAura("auraTimer", "none")
    return ns.AuraLook and ns.AuraLook.ForUnit(size, isDebuff, false, UFAura("auraStyle", "square"), "icon", timer)
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
        -- under the frame; past the cast bar while it shows (it pushes them down, and they come back
        -- up when it hides)
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
    local flowAnchor, V = point, growV
    container:ClearAllPoints()
    container:SetPoint(point, rel, relPoint, x, y)
    local lineSize = perRow * (size + AURA_SPACING)
    pcall(container.SetFlowLayoutAxis, container, AnchorUtil.FlowLayoutAxis.Horizontal)
    pcall(container.SetFlowLayoutAnchorPoint, container, flowAnchor)
    pcall(container.SetFlowLayoutGrowthDirection, container, growH, V)
    pcall(container.SetFlowLayoutMaximumLineSize, container, lineSize)
    pcall(container.SetFlowLayoutPadding, container, 0, 0, 0, 0)
end

local function ConfigurePosition(f, pos, lanes)
    local entry = f.AuraPos and f.AuraPos[pos]
    if not entry then return end
    local container = entry.container
    for _, key in ipairs(entry.groups) do
        pcall(container.SetAuraGroupEnabled, container, key, false)
        pcall(container.SetAuraGroupMaxFrameCount, container, key, 0)
    end
    entry.groups = {}
    if #lanes == 0 then
        pcall(container.SetEnabled, container, false)
        container:Hide()
        return
    end

    local st = TS(f)
    local db = K.GetDb()
    local portrait = pos == "PORTRAIT"
    local size = portrait and DispelGrid(f) or st.auraSize or 18
    local max, perRow = AuraFit(st, pos, f)
    if portrait then max, perRow = 4, 2 end
    local inside = portrait or pos:find("^INSIDE") ~= nil
    local showTimer = not inside and UFAura("auraTimer", "none") ~= "none"
    local font = db and db.font
    local unit = f.unit
    entry.generation = entry.generation + 1
    local gen = entry.generation
    for index, lane in ipairs(lanes) do
        local key = lane.key .. gen
        local isDebuff, kind = lane.isDebuff, lane.kind
        local laneSize = lane.scale and math_floor(size * lane.scale + 0.5) or size
        local look = kind ~= "dispels" and LaneLook(laneSize, isDebuff, inside) or nil
        local ok, err = pcall(container.AddAuraGroup, container, key, lane.filter, {
            maxFrameCount = lane.max or (kind == "dispels" and math_min(max, 3) or max),
            candidateFilters = lane.candidates,
            initializeFrame = function(button)
                if kind == "dispels" then
                    InitDispelIcon(button, laneSize, inside)
                else
                    K.InitAuraButton(button, laneSize, isDebuff, unit, font, showTimer, look)
                    if inside then PassClicks(button) end
                end
            end,
            layout = {
                elementWidth = laneSize, elementHeight = look and look.cellHeight or laneSize,
                elementSpacing = AURA_SPACING, lineSpacing = AURA_SPACING,
                groupSpacing = AURA_SPACING, groupLineSpacing = AURA_SPACING,
                layoutIndex = index,
                -- each kind starts a row of its own; boss debuffs share the debuffs' row
                forceNewLine = index > 1 and not lane.sameLine,
            },
        })
        if ok then
            entry.groups[#entry.groups + 1] = key
        else
            geterrorhandler()(err)
        end
    end
    PlaceAuraContainer(f, pos, container, size, perRow)
    container:SetFrameLevel(f:GetFrameLevel() + 6)
    -- the portrait's grid: over it and under the ready check (the ring's icons: +11)
    if portrait then container:SetFrameLevel(f:GetFrameLevel() + (f.ringKind and 10 or 7)) end
    pcall(container.SetEnabled, container, true)
    pcall(container.SetEditModePreviewEnabled, container, IsEditing())
    container:Show()
    pcall(container.UpdateAllAuras, container)
end

-- Rebuilding makes new aura groups, so it only happens when a setting that shapes them changed (the
-- signature is those settings in a string)
local function Signature(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
    return table.concat(parts, "|")
end

local function ConfigureAuras(f)
    if not f.AuraPos then return end
    local st = TS(f)
    if not st then return end
    local sig = Signature(st.debuffs, st.buffs, st.dispels, st.auraSize, st.width, st.height, st.powerHeight, st.portrait, (DispelGrid(f)), f.ringKind, AuraGrid(st), UFAura("auraStyle", "square"),
        UFAura("auraTimer", "none"), st.bigBossDebuffs, st.castbar, st.castHeight, st.petHeight, (not f.ctx and GetPartyDb().pets))
    if f.auraSignature == sig then return end
    f.auraSignature = sig
    local processed = AuraUtil and AuraUtil.AuraUpdateChangedType
    local perPos = {}
    for _, pos in ipairs(AURA_POSITIONS) do perPos[pos] = {} end
    local function Add(pos, lane)
        if pos and perPos[pos] then perPos[pos][#perPos[pos] + 1] = lane end
    end
    -- an enemy tile: every buff on it, and only the player's debuffs (damage over time, sunders)
    if f.ctx and f.ctx.hostile then
        -- (Only My Debuffs, boss frames: on by default)
        Add(st.debuffs, { key = "debuffs", kind = "debuffs", filter = st.onlyMyDebuffs == false and "HARMFUL" or "HARMFUL|PLAYER", isDebuff = true })
        Add(st.buffs,   { key = "buffs", kind = "buffs", filter = "HELPFUL", isDebuff = false })
        for _, pos in ipairs(AURA_POSITIONS) do ConfigurePosition(f, pos, perPos[pos]) end
        return
    end
    -- debuffs first, nearest the frame; boss and role debuffs lead, bigger, then the rest on their row
    if st.bigBossDebuffs ~= false then
        Add(st.debuffs, { key = "bossdebuffs", kind = "debuffs", filter = "HARMFUL", isDebuff = true, scale = 1.5, max = 2,
                          candidates = { isBossOrRoleAura = true } })
        Add(st.debuffs, { key = "debuffs", kind = "debuffs", filter = "HARMFUL", isDebuff = true, sameLine = true,
                          candidates = { isBossOrRoleAura = false } })
    else
        Add(st.debuffs, { key = "debuffs", kind = "debuffs", filter = "HARMFUL", isDebuff = true })
    end
    Add(DispelPlace(f, st), { key = "dispels", kind = "dispels", filter = "HARMFUL", isDebuff = true,
                      candidates = processed and { processedAuraType = processed.Dispel } })
    Add(st.buffs,   { key = "buffs", kind = "buffs", filter = "HELPFUL", isDebuff = false,
                      candidates = processed and { processedAuraType = processed.Buff } })
    for _, pos in ipairs(AURA_POSITIONS) do ConfigurePosition(f, pos, perPos[pos]) end
end

-- The big defensive (mid health bar) and the dispel highlight (over it): slots showing the first
-- aura of their filter. A change of size or style makes new slots.
local function ConfigureSlots(f)
    local slots = f.AuraSlots
    if not slots then return end
    local st = TS(f)
    local sig = Signature(st.bigDefensive, st.bigDefensiveSize, UFAura("auraStyle", "square"), st.dispelHighlight)
    if slots.signature == sig then
        pcall(slots.container.SetEditModePreviewEnabled, slots.container, IsEditing())
        return
    end
    slots.signature = sig
    local container = slots.container
    for _, key in ipairs(slots.keys) do pcall(container.SetAuraSlotEnabled, container, key, false) end
    slots.keys = {}
    slots.generation = slots.generation + 1
    local gen = slots.generation
    local health = f.Health
    local unit = f.unit
    local db = K.GetDb()

    if st.bigDefensive ~= false then
        local size = st.bigDefensiveSize or 22
        local look = LaneLook(size, false, true)   -- mid-frame: inside, no timer
        local key = "bigdef" .. gen
        local ok = pcall(container.AddAuraSlot, container, key, "HELPFUL|BIG_DEFENSIVE", {
            initializeFrame = function(button)
                K.InitAuraButton(button, size, false, unit, db and db.font, false, look and { size = size, style = look.style,
                    swipe = look.swipe, timer = "none", font = look.font, isDebuff = false, cancel = false, colors = look.colors,
                    cellHeight = size } or nil)
                button:ClearAllPoints()
                button:SetPoint("CENTER", health, "CENTER", 0, 0)
                button:SetFrameLevel(health:GetFrameLevel() + 6)
                PassClicks(button)
            end,
        })
        if ok then slots.keys[#slots.keys + 1] = key end
    end

    container:Show()
    pcall(container.SetEditModePreviewEnabled, container, IsEditing())
    pcall(container.UpdateAllAuras, container)

    -- the dispel highlight, in its own container (never given Edit Mode's sample data)
    local hlEntry = f.AuraHighlight
    if not hlEntry then return end
    local hlContainer = hlEntry.container
    for _, key in ipairs(hlEntry.keys) do pcall(hlContainer.SetAuraSlotEnabled, hlContainer, key, false) end
    hlEntry.keys = {}
    hlEntry.generation = hlEntry.generation + 1
    local highlight = st.dispelHighlight or "mine"
    local styles = Enum.CustomAuraButtonDispelTypeTextureStyle
    if highlight ~= "off" and styles then
        local filter = highlight == "all" and "HARMFUL|RAID_PLAYER_DISPELLABLE" or "HARMFUL|RAID"
        local key = "dispelhl" .. hlEntry.generation
        local ok = pcall(hlContainer.AddAuraSlot, hlContainer, key, filter, {
            -- the frame's own border again, just over it, in the debuff type's colour: Blizzard
            -- shows and tints its pieces for a dispellable debuff (the type may be secret)
            initializeFrame = function(button)
                button:ClearAllPoints()
                button:SetAllPoints(f.Border)
                button:SetFrameLevel(f.Border:GetFrameLevel() + 1)
                if button.EnableMouse then pcall(button.EnableMouse, button, false) end
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
        if ok then hlEntry.keys[#hlEntry.keys + 1] = key end
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
            if f.AuraSlots then pcall(f.AuraSlots.container.SetEditModePreviewEnabled, f.AuraSlots.container, enabled) end
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
    health:SetReverseFill(sx < 0)
    power:SetReverseFill(sx < 0)

    local portrait, divider = f.Portrait, f.PortraitDivider
    -- (FlareUI Style: the ring places the portrait; the Edit Mode preview runs this again)
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
    f.PowerText:SetShown(not RaidTile(f) and st.powerText and showPower and powerHeight >= 10)
end

local function LayoutHealClip(f)
    if not f.HealClip then return end
    local st = TS(f)
    local health, clip, heal, absorb = f.Health, f.HealClip, f.HealBar, f.AbsorbBar
    local fill = health:GetStatusBarTexture()
    local width = (st.width or 200) - 2 * K.INSET - PortraitSpace(f)
    -- shields grow back from the end of the bar, so they show at full health too
    local reverse = true
    clip:ClearAllPoints()
    heal:ClearAllPoints()
    absorb:ClearAllPoints()
    -- near: where the health fill starts (the right on a mirrored tile)
    local near, far = Sides(f)
    local mirror = near == "RIGHT"
    heal:SetWidth(width)
    absorb:SetWidth(width)
    heal:SetReverseFill(mirror)
    absorb:SetReverseFill(reverse ~= mirror)
    -- incoming heals in the tile's own bar texture
    heal:SetStatusBarTexture(K.GetBarTexture(st.texture, mirror))
    clip:SetPoint("TOP" .. near, fill, "TOP" .. far, 0, 0)
    clip:SetPoint("BOTTOM" .. far, health, "BOTTOM" .. far, 0, 0)
    heal:SetPoint("TOP" .. near, clip, "TOP" .. near, 0, 0)
    heal:SetPoint("BOTTOM" .. near, clip, "BOTTOM" .. near, 0, 0)
    if reverse then
        absorb:SetPoint("TOP" .. far, clip, "TOP" .. far, 0, 0)
        absorb:SetPoint("BOTTOM" .. far, clip, "BOTTOM" .. far, 0, 0)
    else
        absorb:SetPoint("TOP" .. near, heal:GetStatusBarTexture(), "TOP" .. far, 0, 0)
        absorb:SetPoint("BOTTOM" .. near, heal:GetStatusBarTexture(), "BOTTOM" .. far, 0, 0)
    end
    local base = clip:GetFrameLevel()
    heal:SetFrameLevel(base + 1)
    absorb:SetFrameLevel(base + 2)
    local absorbTex = st.absorbTexture
    if absorbTex == nil then absorbTex = K.ABSORB_TEXTURE end
    if absorbTex == "" then absorbTex = st.texture end
    absorb:SetStatusBarTexture(K.GetBarTexture(absorbTex))
    absorb:SetStatusBarColor(K.ABSORB_COLOR[1], K.ABSORB_COLOR[2], K.ABSORB_COLOR[3], K.ABSORB_COLOR[4])
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
end

local function LayoutIcons(f)
    local st, raid = TS(f), RaidTile(f)
    local health = f.Health
    local healthHeight = (st.height or 46) - 2 * K.INSET - (WantsPower(f) and (st.powerHeight or 0) or 0)
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
    -- FlareUI Style: where the player frame has them, on the ring (the role icon in the level disc's
    -- spot, the ready check and summon / resurrect / phase on the portrait)
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
    local size = st.auraSize or 18
    local best = 0
    for _, pos in ipairs(places) do
        local max, perRow = AuraFit(st, pos)
        local reach = 0
        if across then
            -- beside the frame: a row's width
            if st.debuffs == pos or st.buffs == pos or st.dispels == pos then
                local boss = (st.debuffs == pos and st.bigBossDebuffs ~= false) and math_floor(size * 0.5 + 0.5) * 2 or 0
                reach = perRow * (size + AURA_SPACING) + boss
            end
        else
            if st.debuffs == pos then
                reach = reach + math.ceil(max / perRow) * (CellHeight(size) + AURA_SPACING)
                if st.bigBossDebuffs ~= false then reach = reach + math_floor(size * 0.5 + 0.5) end
            end
            if st.dispels == pos then reach = reach + math.ceil(math_min(max, 3) / perRow) * (size + AURA_SPACING) end
            if st.buffs == pos then reach = reach + math.ceil(max / perRow) * (CellHeight(size) + AURA_SPACING) end
        end
        if reach > best then best = reach end
    end
    return best > 0 and (best + (EDGE_PLACES[places[1]] and EDGE_GAP or SIDE_GAP)) or 0
end

local function LayoutMember(f)
    local st = TS(f)
    if not st then return end
    if InCombatLockdown() then pendingLayout = true return end
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
    f:SetSize(st.width or 200, st.height or 46)
    f:SetBackdrop({ bgFile = K.BACKDROP_FILE, insets = { left = PADDING, right = PADDING, top = PADDING, bottom = PADDING } })
    f:SetBackdropColor(0, 0, 0, K.BG_OPACITY)
    K.ApplyBorderStyle(f.Border, K.GetBorderFile(K.Border(st.border)), st.height or 46)

    -- (a mirrored tile, as the boss frames: FlareUI Forever's gradient turns with the fill)
    local texture = K.GetBarTexture(st.texture, Mirrored(f))
    f.Health:SetStatusBarTexture(texture)
    f.Power:SetStatusBarTexture(texture)
    f.Health.bg:SetTexture(texture)
    f.Power.bg:SetTexture(texture)
    f.powerShown = WantsPower(f)
    LayoutBars(f)
    if f.ringKind then ns.UFRing.Layout(f) end
    -- the bars' empty part (Background Opacity)
    K.SetBarBackground(f.Health, st.bgOpacity)
    K.SetBarBackground(f.Power, st.bgOpacity)
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
        f.Cast.onShownChanged = function()
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
    ConfigureSlots(f)
end

local function LayoutPet(p)
    local st = S()
    if not st then return end
    if InCombatLockdown() then pendingLayout = true return end
    local PADDING = K.INSET
    local owner = p.owner
    local height = st.petHeight or 19
    p:SetSize(st.petWidth or 120, height + 2 * PADDING)
    K.ApplyBorderStyle(p.Border, K.GetBorderFile(K.Border(st.petBorder or "FlareUI Thin")), height + 2 * PADDING)
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
    -- under the owner, the room its auras below can take and its cast bar, right edges lined up (a
    -- pet is a secure frame: it keeps this place in a fight, so the room is the most the auras take)
    local y = -PET_GAP - LanesExtent(st, BELOW_PLACES)
    if owner.Cast and owner.Cast.isEnabled() then y = y - (st.castHeight or 16) - K.CAST_GAP - PADDING end
    p:ClearAllPoints()
    p:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, y)
end

-- A member's target: beside the frame and centred on it, or, in a horizontal party, under the
-- frame, its cast bar and its pet's place, right edges lined up
local function LayoutTarget(t)
    local st = S()
    if not st then return end
    if InCombatLockdown() then pendingLayout = true return end
    local party = GetPartyDb()
    local PADDING = K.INSET
    local owner = t.owner
    local height = st.targetHeight or 25
    t:SetSize(st.targetWidth or 100, height)
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
    local gap = TARGET_GAP
    t:ClearAllPoints()
    if party.orientation == "HORIZONTAL" then
        local y = -gap - LanesExtent(st, BELOW_PLACES)
        if owner.Cast and owner.Cast.isEnabled() then y = y - (st.castHeight or 16) - K.CAST_GAP - PADDING end
        if party.pets then y = y - PET_GAP - (st.petHeight or 19) - 2 * PADDING end
        t:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, y)
    else
        t:SetPoint("LEFT", owner, "RIGHT", gap, 0)
    end
end

-- One step from a frame to the next, and where the first frame starts in the holder
local function Step()
    local st = S()
    local party = GetPartyDb()
    local above = LanesExtent(st, ABOVE_PLACES)
    local below = LanesExtent(st, BELOW_PLACES)
    if party.orientation == "HORIZONTAL" then
        local left = LanesExtent(st, { "LEFT" }, true)
        local right = LanesExtent(st, { "RIGHT" }, true)
        return left + (st.width or 200) + right + (st.spacing or 8), 0, left, -above
    end
    local h = st.height or 46
    if st.castbar then h = h + (st.castHeight or 16) + K.CAST_GAP + K.INSET end
    -- a pet's room is added per frame (LayoutHolder); under a pet the gap is tighter, but never
    -- closer than the pet sits to its owner
    local spacing = st.spacing or 8
    local gapBelow = math_max(spacing - 4, PET_GAP + 2)
    local petRoom = PET_GAP + (st.petHeight or 19) + 2 * K.INSET + gapBelow - spacing
    return 0, -(above + h + below + spacing), 0, -above, petRoom
end

-- Whether this frame has a pet under it (in Edit Mode: the samples with one)
local function HasPet(i)
    local party = GetPartyDb()
    if not party.pets then return false end
    if IsEditing() then
        local sample = PREVIEW[i - (party.showPlayer and 0 or 1) + 1]
        return sample and sample.pet and true or false
    end
    return UnitExists(PET_UNITS[i]) and true or false
end

local function SlotsInUse()
    local party = GetPartyDb()
    local first = party.showPlayer and 0 or 1
    return first, MAX_MEMBERS
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
    local first, last = SlotsInUse()
    local count = last - first + 1
    local dx, dy, ox, oy, petRoom = Step()
    -- each frame's place: the ones before it, and the room their pets take (vertical only)
    local x, y = ox, oy
    local placed = {}
    for _, i in ipairs(SlotOrder(first)) do
        placed[i] = { x, y }
        x = x + dx
        y = y + dy
        if dy ~= 0 and HasPet(i) then y = y - petRoom end
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
    party.layouts[layoutName] = party.layouts[layoutName] or {}
    return party.layouts[layoutName]
end

local function ApplyPosition(layoutName)
    if not holder then return end
    if InCombatLockdown() then pendingLayout = true return end
    -- the default: FlareUI Style's own for the party frames (not Raid-Style), past the ring
    local base = (RingKind({}) and ns.UFRing.TILE_POSITIONS.party) or BASE_POSITION
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
        RegisterStateDriver(holder, "visibility", "[group:raid] hide; [group:party] show; hide")
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
    local c = PREVIEW_CLASS_RGB[class]
    if c then return c[1], c[2], c[3] end
    local cc = class and C_ClassColor and C_ClassColor.GetClassColor(class)
    if cc then return cc:GetRGB() end
    return ns.HEALTH_GREEN[1], ns.HEALTH_GREEN[2], ns.HEALTH_GREEN[3]
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
    if f.HighlightSample then f.HighlightSample:Hide() end
end

local function ApplyPreviewExtras(f, data)
    HidePreviewExtras(f)
    local st = TS(f)
    local used = 0
    local size = st.auraSize or 18
    -- buffs and debuffs drawn by hand where there are no containers to show Edit Mode's samples
    if f.noAuras then
        local function Row(place, count, icons, bossFirst)
            if not place or place == "OFF" or (count or 0) <= 0 then return end
            local max, perRow = AuraFit(st, place, f)
            local point, rel, relPoint, x, y, growH = AuraAnchor(f, place)
            local sx = growH == AnchorUtil.FlowDirection.Left and -1 or 1
            local offset = 0
            for i = 1, math_min(count, max) do
                local s = (bossFirst and i == 1 and st.bigBossDebuffs ~= false) and math_floor(size * 1.5 + 0.5) or size
                used = used + 1
                local b = PreviewBit(f, used, s)
                b.Icon:SetTexture(icons[(i - 1) % #icons + 1])
                b.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                b:SetPoint(point, rel, relPoint, x + sx * offset, y)
                offset = offset + s + AURA_SPACING
            end
        end
        Row(st.buffs, data.buffs, SAMPLE_BUFF_ICONS)
        Row(st.debuffs, (data.debuffs or 0) + (data.bossDebuff and 1 or 0), SAMPLE_DEBUFF_ICONS, data.bossDebuff)
    end
    -- dispel icons, at their place (under the debuffs' rows when they share it); the party's: one,
    -- big on the portrait, on the member with a dispellable debuff
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
        hl:ClearAllPoints()
        hl:SetAllPoints(f.Border)
        hl:SetFrameLevel(f.Border:GetFrameLevel() + 1)
        hl:SetBackdrop(f.Border:GetBackdrop())
        local c = DISPEL_RGB[data.highlight] or DISPEL_RGB.Magic
        hl:SetBackdropBorderColor(c[1], c[2], c[3], 1)
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
    elseif ns.ClassColorsOn() then
        f.Health:SetStatusBarColor(PreviewColor(class))
    else
        f.Health:SetStatusBarColor(ns.HEALTH_GREEN[1], ns.HEALTH_GREEN[2], ns.HEALTH_GREEN[3])
    end
    f.Health:SetAlpha(1)
    local mode = st.healthText or "percent"
    if data.dead then
        f.HealthText:SetText(K.DEAD_TEXT)
    elseif mode == "percent" then
        f.HealthText:SetFormattedText("%.0f%%", (data.health or 1) * 100)
    elseif mode == "value" then
        f.HealthText:SetText(AbbreviateNumbers(math_floor((data.health or 1) * 24000)))
    elseif mode == "both" then
        f.HealthText:SetFormattedText("%s | %.0f%%", AbbreviateNumbers(math_floor((data.health or 1) * 24000)), (data.health or 1) * 100)
    else
        f.HealthText:SetText("")
    end
    f.powerShown = WantsPower(f)
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
    f.PowerText:SetText(not RaidTile(f) and st.powerText and AbbreviateNumbers(math_floor((data.power or 1) * 9000)) or "")
    if f.HealBar then f.HealBar:SetValue(0); f.AbsorbBar:SetValue(0) end

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
    ApplyPreviewExtras(f, data)

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
    if GameTooltip:IsForbidden() or IsEditing() or not f.unit then return end
    GameTooltip_SetDefaultAnchor(GameTooltip, f)
    GameTooltip:SetUnit(f.unit)
    GameTooltip:Show()
end

local function OnLeave(f)
    f.Highlight:Hide()
    if not GameTooltip:IsForbidden() then GameTooltip:Hide() end
end

local function SecureUnitButton(name, unit)
    local f = CreateFrame("Button", name, holder, "SecureUnitButtonTemplate,PingableUnitFrameTemplate,BackdropTemplate")
    f.unit = unit
    f:SetAttribute("unit", unit)
    f:SetAttribute("*type1", "target")
    f:SetAttribute("*type2", "togglemenu")
    f:RegisterForClicks("AnyUp")
    if type(f.SetRolesets) == "function" then pcall(f.SetRolesets, f, "unitFrames") end
    _G.ClickCastFrames = _G.ClickCastFrames or {}
    _G.ClickCastFrames[f] = true
    f:SetScript("OnEnter", OnEnter)
    f:SetScript("OnLeave", OnLeave)
    return f
end

local MEMBER_UNIT_EVENTS = {
    "UNIT_HEALTH", "UNIT_MAXHEALTH",
    "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_POWER_FREQUENT",
    "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_FACTION", "UNIT_CONNECTION", "UNIT_FLAGS",
    "UNIT_HEAL_PREDICTION", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_THREAT_SITUATION_UPDATE",
    "UNIT_IN_RANGE_UPDATE", "UNIT_PHASE", "UNIT_OTHER_PARTY_CHANGED",
    "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED",
}

-- Builds a tile on a unit button: bars, texts, icons, highlights, heal overlays, auras and events.
-- f.ctx (set first) gives it an owner of its own; f.noAuras leaves out the aura containers (samples).
local function BuildTile(f, unit)
    local level = f:GetFrameLevel()

    f.Health = K.CreateBar(f, level + 1)
    f.Power = K.CreateBar(f, level + 1)

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

    -- the centre icons sit above the inside auras and the big defensive
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

    -- the target outline: four thin lines just inside the border
    local hl = CreateFrame("Frame", nil, f)
    hl:SetPoint("TOPLEFT", f, "TOPLEFT", K.INSET - 1, -K.INSET + 1)
    hl:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -K.INSET + 1, K.INSET - 1)
    hl:SetFrameLevel(level + 5)
    for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 },
                         { "TOPLEFT", "BOTTOMLEFT", 1, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 1, nil } }) do
        local line = hl:CreateTexture(nil, "OVERLAY")
        line:SetColorTexture(1, 1, 1, 0.9)
        line:SetPoint(e[1])
        line:SetPoint(e[2])
        if e[3] then line:SetWidth(e[3]) else line:SetHeight(e[4]) end
    end
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
    if CreateUnitHealPredictionCalculator then
        local ok, calc = pcall(CreateUnitHealPredictionCalculator)
        if ok and calc then f.HealCalc = calc end
    end

    if not f.ctx or f.ctx.castbar then
        f.Cast = K.CreateCastBar(f, unit)
        f.Cast.isEnabled = function() local st = TS(f); return st and st.castbar and true or false end
    end

    if not f.noAuras then PrecreateAuraContainers(f) end

    f:SetScript("OnEvent", OnMemberEvent)
    if unit then
        for _, event in ipairs(MEMBER_UNIT_EVENTS) do pcall(f.RegisterUnitEvent, f, event, unit) end
        if f.Cast then for _, event in ipairs(K.CAST_EVENTS) do pcall(f.RegisterUnitEvent, f, event, unit) end end
    end
    f:HookScript("OnShow", UpdateAll)
end

-- A raid header hands its tiles a new unit (in combat too: no protected calls here)
local function SetTileUnit(f, unit)
    if f.unit == unit then return end
    f.unit = unit
    for _, event in ipairs(MEMBER_UNIT_EVENTS) do pcall(f.UnregisterEvent, f, event) end
    if unit then
        for _, event in ipairs(MEMBER_UNIT_EVENTS) do pcall(f.RegisterUnitEvent, f, event, unit) end
    end
    local function Retarget(container) pcall(container.SetUnit, container, unit) end
    if f.AuraPos then for _, entry in pairs(f.AuraPos) do Retarget(entry.container) end end
    if f.AuraSlots then Retarget(f.AuraSlots.container) end
    if f.AuraHighlight then Retarget(f.AuraHighlight.container) end
    if unit and f:IsVisible() then UpdateAll(f) end
end

local function CreateMember(index)
    local unit = SLOT_UNITS[index]
    local f = SecureUnitButton("FlareUI_Party" .. index, unit)
    f.index = index
    BuildTile(f, unit)
    members[index] = f
    -- a member can get its unit before the frame shows (UpdateMissing is in section 12b)
    f:HookScript("OnShow", function(self) if PF.UpdateMissing then PF.UpdateMissing(self) end end)
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
    p:SetScript("OnEvent", function(self) UpdatePet(self) end)
    for _, event in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE", "UNIT_CONNECTION" }) do
        pcall(p.RegisterUnitEvent, p, event, p.unit)
    end
    p:HookScript("OnShow", UpdatePet)
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
    t:SetScript("OnEvent", function(self) UpdatePartyTarget(self) end)
    if index > 0 then pcall(t.RegisterUnitEvent, t, "UNIT_TARGET", SLOT_UNITS[index]) end
    t:HookScript("OnShow", UpdatePartyTarget)
    targets[index] = t
    return t
end

--------------------------------------------------
-- 11. BLIZZARD'S PARTY FRAMES (both styles live in PartyFrame; parked with HardHide)
--------------------------------------------------
local function HideBlizzardParty()
    if _G.PartyFrame then K.HardHide("PartyFrame") end
end

--------------------------------------------------
-- 12. EDIT MODE SETTINGS
--------------------------------------------------
local Refresh   -- section 13

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
    local ringPortrait = ns.UFRing and ns.UFRing.Style() == "flareui"
    -- Show Player: FlareUI Style's party leaves you out by default
    local group = ns.UFRing and ns.UFRing.TileDefaults("partyGroup")
    local showPlayerDefault = true
    if group and group.showPlayer ~= nil then showPlayerDefault = group.showPlayer end

    local Section, settings = K.EditSections()

    Section("Party", {
        { name = L["Style"], kind = LEM.SettingType.Dropdown, default = "classic",
          values = { { text = L["Classic"], value = "classic", isRadio = true }, { text = L["Raid-Style"], value = "raid", isRadio = true } },
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
          get = getP("orientation", "VERTICAL"), set = setP("orientation") },
        { name = L["Spacing"], kind = LEM.SettingType.Slider, default = D.spacing, minValue = 0, maxValue = 80, valueStep = 1,
          get = getS("spacing"), set = setS("spacing"),
          desc = L["The gap between the frames. Each style keeps its own."] },
        { name = L["Sort by Role"], kind = LEM.SettingType.Checkbox, default = true, get = getP("sortByRole", true), set = setP("sortByRole"),
          desc = L["Tanks first, then healers, then damage dealers. A change during combat is applied when the fight ends."] },
        { name = L["Show Player"], kind = LEM.SettingType.Checkbox, default = showPlayerDefault, get = getP("showPlayer", showPlayerDefault), set = setP("showPlayer"),
          desc = L["Your own frame first, with the party."] },
        { name = L["Show Pets"], kind = LEM.SettingType.Checkbox, default = false, get = getP("pets", false),
          set = function(layoutName, value) setP("pets")(layoutName, value); LEM:RefreshFrameSettings(holder) end,
          desc = L["A small frame for each pet, under its owner. Its size is in the Pet section."] },
        { name = L["Show Party Targets"], kind = LEM.SettingType.Checkbox, default = false, get = getP("targets", false),
          set = function(layoutName, value) setP("targets")(layoutName, value); LEM:RefreshFrameSettings(holder) end,
          desc = L["What each member is targeting, in a small frame beside theirs (under it in a horizontal party). Click one to target it too. Its size is in the Target section."] },
    })

    Section("Frame", {
        { name = L["Width"], kind = LEM.SettingType.Slider, default = D.width, minValue = 60, maxValue = 400, valueStep = 2, get = getS("width"), set = setS("width") },
        { name = L["Height"], kind = LEM.SettingType.Slider, default = D.height, minValue = 20, maxValue = 120, valueStep = 1, get = getS("height"), set = setS("height") },
        { name = L["Power Bar Height"], kind = LEM.SettingType.Slider, default = D.powerHeight, minValue = 0, maxValue = 30, valueStep = 1,
          get = getS("powerHeight"), set = setS("powerHeight"), formatter = function(value) return value == 0 and _G.OFF or value end },
        -- FlareUI Style: the ring's size, as the player frame's
        { name = L["Portrait Size"], kind = LEM.SettingType.Slider, default = ns.UFRing and ns.UFRing.DefaultSize("party") or 80,
          minValue = 36, maxValue = 120, valueStep = 1,
          get = function() local st = S(); return st and st.ringSize or (ns.UFRing and ns.UFRing.DefaultSize("party")) or 80 end,
          set = setS("ringSize"), hidden = function() return not RingKind({}) end },
        -- FlareUI Style: the ring always holds a portrait (no None; 3D by default)
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
        { name = L["Power Text"], kind = LEM.SettingType.Checkbox, default = D.powerText or false, get = getS("powerText"), set = setS("powerText"), hidden = classicOnly },
        { name = L["Show Level"], kind = LEM.SettingType.Checkbox, default = D.showLevel ~= false, get = getS("showLevel"), set = setS("showLevel") },
    })

    -- debuffs, buffs and dispel icons never share a place: a place taken by one is greyed out on
    -- the others
    local AURA_FIELDS = { "buffs", "debuffs", "dispels" }
    local PARTY_PLACES = PF.AuraPlaces("LEFT")
    local function Place(field)
        return function(_, rootDescription, data)
            local st = S()
            for _, p in ipairs(PARTY_PLACES) do
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
    Section("Look", {
        { name = L["Bar Texture"], kind = LEM.SettingType.Dropdown, default = D.texture, values = K.BuildTextureValues(),
          get = getS("texture"), set = setS("texture") },
        { name = L["Border Texture"], kind = LEM.SettingType.Dropdown, default = D.border, values = K.BuildBorderValues(false),
          get = getS("border"), set = setS("border"), hidden = K.NoBorderOptions },
        { name = L["Absorb Texture"], kind = LEM.SettingType.Dropdown, default = D.absorbTexture, values = K.BuildAbsorbValues(),
          get = getS("absorbTexture"), set = setS("absorbTexture"),
          desc = L["The texture of the shield (absorb) over the health bar."] },
        K.BgOpacitySetting(K.BAR_BG_OPACITY,
            function() local v = getS("bgOpacity")(); if v == nil then return K.BAR_BG_OPACITY end; return v end,
            setS("bgOpacity")),
    })

    local function noCast() return not getS("castbar")() end
    Section("Cast Bar", {
        { name = L["Cast Bars"], kind = LEM.SettingType.Checkbox, default = D.castbar or false, get = getS("castbar"),
          set = function(layoutName, value) setS("castbar")(layoutName, value); LEM:RefreshFrameSettings(holder) end },
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
        { name = L["Cast Bar Texture"], kind = LEM.SettingType.Dropdown, default = D.castTexture, values = K.BuildTextureValues(),
          get = getS("castTexture"), set = setS("castTexture"), hidden = noCast, },
        { name = L["Cast Bar Border Texture"], kind = LEM.SettingType.Dropdown, default = D.castBorderTexture, values = K.BuildBorderValues(true),
          get = getS("castBorderTexture"), set = setS("castBorderTexture"),
          hidden = function() return noCast() or K.NoBorderOptions() end,
          desc = L["Frame Border uses the frame's own border."] },
    })

    Section("Auras", {
        { name = L["Buffs"], kind = LEM.SettingType.Dropdown, default = D.buffs, values = PARTY_PLACES, generator = Place("buffs"),
          get = getS("buffs"), set = setS("buffs"),
          desc = L["Buffs as Blizzard's raid frames pick them: mostly your own heals over time and buffs."] },
        { name = L["Debuffs"], kind = LEM.SettingType.Dropdown, default = D.debuffs, values = PARTY_PLACES, generator = Place("debuffs"),
          get = getS("debuffs"), set = setS("debuffs"),
          desc = L["Debuffs as Blizzard's raid frames pick them: boss and role debuffs, priority debuffs, and the ones you can dispel."] },
        { name = L["Dispel Highlight"], kind = LEM.SettingType.Dropdown, default = D.dispelHighlight,
          values = { { text = L["Off"], value = "off", isRadio = true }, { text = L["Dispellable by Me"], value = "mine", isRadio = true },
                     { text = L["Dispellable by the Group"], value = "all", isRadio = true } },
          desc = L["A dispellable debuff colours the frame's border in its type's colour."],
          get = getS("dispelHighlight"), set = setS("dispelHighlight") },
        -- one dispel icon, big on the portrait (or the health bar's middle)
        { name = L["Dispel Icons"], kind = LEM.SettingType.Checkbox, default = D.dispels ~= "OFF",
          get = function() local st = S(); local v = st and st.dispels; if v == nil then v = D.dispels end; return v ~= "OFF" end,
          set = function(_, value) setS("dispels")(nil, value and "PORTRAIT" or "OFF") end,
          desc = L["The debuffs you can dispel, up to four, two to a row in the middle of the portrait (or of the health bar without one)."] },
        { name = L["Aura Size"], kind = LEM.SettingType.Slider, default = D.auraSize, minValue = 10, maxValue = 40, valueStep = 1, get = getS("auraSize"), set = setS("auraSize") },
        { name = L["Missing Buffs"], kind = LEM.SettingType.Checkbox, default = D.missingBuffs or false,
          get = function() return getS("missingBuffs")() and true or false end, set = setS("missingBuffs"),
          desc = L["Out of combat, the group buffs a member lacks that you can cast show in the corner across from the buffs."] },
        { name = L["Bigger Boss Debuffs"], kind = LEM.SettingType.Checkbox, default = D.bigBossDebuffs ~= false, get = getS("bigBossDebuffs"), set = setS("bigBossDebuffs"),
          desc = L["Boss and role debuffs first and half again as big, as Blizzard's raid frames show them."] },
        { name = L["Big Defensive"], kind = LEM.SettingType.Checkbox, default = D.bigDefensive ~= false,
          get = function() return getS("bigDefensive")() ~= false end,
          set = function(layoutName, value) setS("bigDefensive")(layoutName, value); LEM:RefreshFrameSettings(holder) end,
          desc = L["A big defensive cooldown on the member (Shield Wall, Divine Shield...) in the middle of the frame."] },
        { name = L["Big Defensive Size"], kind = LEM.SettingType.Slider, default = D.bigDefensiveSize, minValue = 12, maxValue = 48, valueStep = 1,
          get = getS("bigDefensiveSize"), set = setS("bigDefensiveSize"),
          hidden = function() return getS("bigDefensive")() == false end },
    })

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
        { name = L["Pet Border Texture"], kind = LEM.SettingType.Dropdown, default = D.petBorder, values = K.BuildBorderValues(false),
          get = getS("petBorder"), set = setS("petBorder"), hidden = function() return noPets() or K.NoBorderOptions() end },
    })

    -- the members' targets: only while Show Party Targets (Party section) is on
    local function noTargets() return not getP("targets", false)() end
    Section("Target", {
        { name = L["Target Frame Width"], kind = LEM.SettingType.Slider, default = D.targetWidth, minValue = 40, maxValue = 300, valueStep = 2,
          get = getS("targetWidth"), set = setS("targetWidth"), hidden = noTargets },
        { name = L["Target Frame Height"], kind = LEM.SettingType.Slider, default = D.targetHeight, minValue = 12, maxValue = 60, valueStep = 1,
          get = getS("targetHeight"), set = setS("targetHeight"), hidden = noTargets },
        { name = L["Target Border Texture"], kind = LEM.SettingType.Dropdown, default = D.targetBorder, values = K.BuildBorderValues(false),
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
-- 12b. MISSING BUFFS (Auras > Missing Buffs)
-- The raid frames' reminder (RaidFrames.lua section 8, shared as ns.MissingBuffs): the group buffs
-- a member lacks that you can cast, out of a fight only. They sit in the corner across from the
-- buffs (buffs top left: bottom left), at the aura size.
--------------------------------------------------
local MIRROR = { INSIDE_TOPLEFT = "INSIDE_BOTTOMLEFT", INSIDE_BOTTOMLEFT = "INSIDE_TOPLEFT",
                 INSIDE_TOPRIGHT = "INSIDE_BOTTOMRIGHT", INSIDE_BOTTOMRIGHT = "INSIDE_TOPRIGHT" }

local function UpdateMissing(f)
    local MB = ns.MissingBuffs
    if not (f and MB) then return end
    local st = S()
    if not (st and st.missingBuffs) then
        if f.MissingBuffs then MB.Show(f) end
        return
    end
    if not f.MissingBuffs then MB.Attach(f) end
    f.MissingBuffs.place = MIRROR[st.buffs] or "INSIDE_BOTTOMLEFT"
    f.MissingBuffs.size = st.auraSize or 16
    if IsEditing() then
        MB.Show(f, MB.SampleIcons(f.preview and f.preview.missing))
        return
    end
    if InCombatLockdown() or not (f.unit and f:IsVisible() and UnitExists(f.unit)) then MB.Show(f) return end
    if not MB.Learned() then MB.Learn() end
    MB.Show(f, MB.Icons(f.unit))
end

local function UpdateMissingAll()
    for i = 0, MAX_MEMBERS do UpdateMissing(members[i]) end
end

-- aura changes come in bursts: looked at once, a moment later
local missingDirty, missingScheduled = {}, false
local function OnMissingAura(unit)
    if not (holder and holder:IsShown()) then return end   -- every unit's auras come through here
    local st = S()
    if not (st and st.missingBuffs) or InCombatLockdown() then return end
    unit = readable(unit)
    if not unit then return end
    for i = 0, MAX_MEMBERS do
        local f = members[i]
        if f and f.unit == unit then missingDirty[f] = true end
    end
    if missingScheduled or not next(missingDirty) then return end
    missingScheduled = true
    C_Timer.After(0.3, function()
        missingScheduled = false
        for f in pairs(missingDirty) do UpdateMissing(f) end
        wipe(missingDirty)
    end)
end

--------------------------------------------------
-- 13. PUBLIC
--------------------------------------------------
-- A member's target sends no health events: the shown ones are re-read while Show Party Targets is on
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
    UpdateMissingAll()
end

function PF:Refresh()
    Refresh()
end

PF.UpdateMissing = UpdateMissing

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
    UpdateReadyCheck = UpdateReadyCheck, UpdateStatus = UpdateStatus, UpdateThreat = UpdateThreat,
    OnEnter = OnEnter, OnLeave = OnLeave,
    AURA_POSITION_VALUES = AURA_POSITION_VALUES, ICON_ORDER = ICON_ORDER, ICON_LABELS = ICON_LABELS,
    PlacesClash = PlacesClash, ABOVE_PLACES = ABOVE_PLACES, BELOW_PLACES = BELOW_PLACES, WIDE_PLACES = WIDE_PLACES,
    IconShown = IconShown, IconStore = IconStore, LanesExtent = LanesExtent,
}

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

-- Range has no event for every change; frames in a group re-check twice a second
local rangeTicker
local function StartRangeTicker()
    if rangeTicker then return end
    rangeTicker = C_Timer.NewTicker(RANGE_INTERVAL, function()
        if not (holder and holder:IsShown()) or IsEditing() then return end
        for i = 1, MAX_MEMBERS do
            local f = members[i]
            if f and f:IsShown() then UpdateRange(f) end
        end
    end)
end

function PF:OnGlobalEvent(event, ...)
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingLayout then Refresh() end
        UpdateMissingAll()
        return
    elseif event == "PLAYER_REGEN_DISABLED" then
        UpdateMissingAll()   -- hidden in a fight
        return
    elseif event == "UNIT_AURA" then
        OnMissingAura(...)
        return
    elseif event == "SPELLS_CHANGED" then
        if ns.MissingBuffs and S() and S().missingBuffs then ns.MissingBuffs.Learn(); UpdateMissingAll() end
        return
    end
    if IsEditing() then return end
    -- a new member or role: the frames take their places again (after the fight, in combat)
    local party = GetPartyDb()
    if ((event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED") and party.sortByRole)
        or ((event == "GROUP_ROSTER_UPDATE" or event == "UNIT_PET") and party.pets) then
        LayoutHolder()
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
        if f and f:IsShown() then
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
            elseif event == "PLAYER_ROLES_ASSIGNED" then
                UpdateRole(f)
                UpdatePower(f)
            else
                UpdateAll(f)
            end
        end
        local p = pets[i]
        if p and p:IsShown() and (event == "GROUP_ROSTER_UPDATE" or event == "UNIT_PET" or event == "PLAYER_ENTERING_WORLD") then
            UpdatePet(p)
        end
    end
    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then UpdateMissingAll() end
end

local GLOBAL_EVENTS = {
    "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "RAID_TARGET_UPDATE", "PLAYER_TARGET_CHANGED",
    "PLAYER_ROLES_ASSIGNED", "READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED",
    "INCOMING_SUMMON_CHANGED", "INCOMING_RESURRECT_CHANGED", "PLAYER_ENTERING_WORLD", "UNIT_PET",
    "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "UNIT_AURA", "SPELLS_CHANGED",
}

function PF:Init()
    if self.initialized or not K then return end
    if InCombatLockdown() then
        -- secure frames cannot be made in a fight (a /reload mid-combat); they come after it
        self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            self:Init()
        end)
        return
    end
    self.initialized = true

    -- Left of the Frame is gone: auras set there move to the right (off when that is taken)
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
    for i = 0, MAX_MEMBERS do CreateMember(i) end
    for i = 0, MAX_MEMBERS do CreatePet(i) end
    for i = 0, MAX_MEMBERS do CreatePartyTarget(i) end

    LEM:AddFrame(holder, OnFrameMoved, DEFAULT_POSITION, "FlareUI Party Frames")
    LEM:AddFrameSettings(holder, BuildSettings())
    HideBlizzardParty()

    for _, event in ipairs(GLOBAL_EVENTS) do self:RegisterEvent(event, "OnGlobalEvent") end

    LEM:RegisterCallback("layout", function(layoutName) ApplyPosition(layoutName) end)
    LEM:RegisterCallback("enter", function()
        ApplyVisibility()
        LayoutHolder()   -- the sample pets take their room
        SetAuraPreview(true)
        for i = 0, MAX_MEMBERS do UpdateAll(members[i]) end
        UpdateMissingAll()
    end)
    LEM:RegisterCallback("exit", function()
        ApplyVisibility()
        SetAuraPreview(false)
        Refresh()
    end)

    StartRangeTicker()
    Refresh()
    C_Timer.After(0, Refresh)
end
