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
local DEFAULT_POSITION = { point = "LEFT", x = 3, y = 0 }
local PET_GAP = 2
local AURA_SPACING = 2
local AURA_CONTAINER_TEMPLATE = "CustomAuraContainerTemplate"
local PRIVATE_AURA_COUNT = 2
local READY_CHECK_HOLD = 6           -- seconds the result stays after a ready check ends
local RANGE_INTERVAL = 0.5

-- Where a lane of auras can go: beside / above / below the frame, or inside the health bar
local AURA_POSITIONS = { "RIGHT", "LEFT", "ABOVE", "ABOVE_RIGHT", "BELOW", "BELOW_RIGHT",
                         "INSIDE_TOPLEFT", "INSIDE_TOPRIGHT", "INSIDE_BOTTOMLEFT", "INSIDE_BOTTOMRIGHT" }
local AURA_POSITION_VALUES = {
    { text = L["Off"],                 value = "OFF",                isRadio = true },
    { text = L["Right of the Frame"],  value = "RIGHT",              isRadio = true },
    { text = L["Left of the Frame"],   value = "LEFT",               isRadio = true },
    { text = L["Above the Frame, Left"],  value = "ABOVE",        isRadio = true },
    { text = L["Above the Frame, Right"], value = "ABOVE_RIGHT",  isRadio = true },
    { text = L["Below the Frame, Left"],  value = "BELOW",        isRadio = true },
    { text = L["Below the Frame, Right"], value = "BELOW_RIGHT",  isRadio = true },
    { text = L["Inside, Top Left"],     value = "INSIDE_TOPLEFT",     isRadio = true },
    { text = L["Inside, Top Right"],    value = "INSIDE_TOPRIGHT",    isRadio = true },
    { text = L["Inside, Bottom Left"],  value = "INSIDE_BOTTOMLEFT",  isRadio = true },
    { text = L["Inside, Bottom Right"], value = "INSIDE_BOTTOMRIGHT", isRadio = true },
}

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

-- The frame icons, per style in Edit Mode: style.icons[key] = { shown, x, y, scale }
local ICON_ORDER  = { "role", "leader", "raidIcon", "readyCheck", "status" }
local ICON_LABELS = { role = L["Role"], leader = L["Leader"], raidIcon = L["Raid Target"], readyCheck = L["Ready Check"], status = L["Summon / Resurrect / Phase"] }
-- Icon Scale when the player has not set one (percent)
local ICON_DEFAULT_SCALE = { raidIcon = 125, readyCheck = 125, status = 125 }

-- Edit Mode sample group: a tank, a healer and three damage dealers
local PREVIEW = {
    { name = "Thalorien", class = "WARRIOR", role = "TANK",    health = 0.92, power = 0.35, leader = true },
    { name = "Elysande",  class = "PRIEST",  role = "HEALER",  health = 0.64, power = 0.85, ready = "ready" },
    { name = "Morwen",    class = "WARLOCK", role = "DAMAGER", health = 0.48, power = 0.60, marker = 8, highlight = "Magic", pet = "Voidwalker" },
    { name = "Sylvara",   class = "HUNTER",  role = "DAMAGER", health = 0.81, power = 0.72, pet = "Wolf" },
    { name = "Kestrel",   class = "ROGUE",   role = "DAMAGER", health = 0.27, power = 0.90, status = "IncomingSummonPending" },
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
local PRIVATE_SAMPLE_ICONS = { "Interface\\Icons\\Spell_Shadow_AntiShadow", "Interface\\Icons\\Ability_Creature_Cursed_02" }
-- sample auras for tiles without aura containers (the raid frames' Edit Mode samples)
local SAMPLE_BUFF_ICONS = { "Interface\\Icons\\Spell_Holy_Renew", "Interface\\Icons\\Spell_Nature_Rejuvenation", "Interface\\Icons\\Spell_Holy_PowerWordShield" }
local SAMPLE_DEBUFF_ICONS = { "Interface\\Icons\\Spell_Shadow_ShadowWordPain", "Interface\\Icons\\Spell_Fire_Immolation", "Interface\\Icons\\Ability_Creature_Poison_02" }

--------------------------------------------------
-- 3. SETTINGS ACCESS
--------------------------------------------------
local holder
local members, pets = {}, {}    -- [0..4] -> frame
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

-- A tile's settings: its owner's when it has one (f.ctx: the raid frames), else the party style's
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
    local st = TS(f)
    return st and st.mirror and true or false
end

-- A side and its opposite, swapped on a mirrored tile, and which way +x goes from the near side
local function Sides(f)
    if Mirrored(f) then return "RIGHT", "LEFT", -1 end
    return "LEFT", "RIGHT", 1
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
    local store = IconStore(key, nil, f)
    local dx, dy, scale = 0, 0, (ICON_DEFAULT_SCALE[key] or 100) / 100
    if store then dx, dy, scale = store.x or 0, store.y or 0, (store.scale or ICON_DEFAULT_SCALE[key] or 100) / 100 end
    region:ClearAllPoints()
    region:SetSize(width * scale, height * scale)
    region:SetPoint(point, relativeTo, relativePoint, x + dx, y + dy)
end

local selectedIcon = ICON_ORDER[1]   -- the icon picked in the Edit Mode dialog (not saved)

local function ScaledFont(base, size)
    if not size then return base end
    return setmetatable({ size = size }, { __index = base or {} })
end

--------------------------------------------------
-- 4. UPDATERS (secret-safe, as in UnitFrames.lua)
--------------------------------------------------
local function UpdateName(f)
    f.Name:SetText(UnitName(f.unit) or "")
end

local function UpdateLevel(f)
    local st = TS(f)
    if RaidTile(f) or not (st and st.showLevel) then f.Level:SetText("") return end
    local level = UnitLevel(f.unit)
    if canaccessvalue(level) and level then
        if level < 0 then
            f.Level:SetText("??")
            f.Level:SetTextColor(1, 0.1, 0.1)
        else
            f.Level:SetFormattedText("%d", level)
            local color = GetQuestDifficultyColor and GetQuestDifficultyColor(level)
            if color then f.Level:SetTextColor(color.r, color.g, color.b) else f.Level:SetTextColor(1, 1, 1) end
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

-- Healers Only: the power bar shows for healers alone (the role can be secret; then it shows)
local function WantsPower(f)
    local st = TS(f)
    if not st or (st.powerHeight or 0) <= 0 then return false end
    if not st.healersOnlyPower then return true end
    if IsEditing() then return (f.preview and f.preview.role) == "HEALER" end
    local role = readable(UnitGroupRolesAssigned(f.unit))
    return role == nil or role == "HEALER" or role == "NONE"
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

-- Out of range: the whole frame fades (UnitInRange is secret, so the alpha is picked by the client)
local function UpdateRange(f)
    local st = TS(f)
    local alpha = st and st.rangeAlpha or 0.45
    if f.unit == "player" or alpha >= 1 or IsEditing() then
        f:SetAlpha(1)
        return
    end
    local inRange = UnitInRange(f.unit)
    if f.SetAlphaFromBoolean then
        if not pcall(f.SetAlphaFromBoolean, f, inRange, 1, alpha) then f:SetAlpha(1) end
    elseif canaccessvalue(inRange) then
        f:SetAlpha(inRange and 1 or alpha)
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

local function UpdateAll(f)
    if IsEditing() then ApplyPreview(f) return end
    HidePreviewExtras(f)
    if not UnitExists(f.unit) then return end
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
end

local function UpdatePet(p)
    if IsEditing() then return end
    if not UnitExists(p.unit) then return end
    local unit = p.unit
    p.Health:SetMinMaxValues(0, UnitHealthMax(unit))
    p.Health:SetValue(UnitHealth(unit))
    p.Health:SetStatusBarColor(K.GetHealthColor(unit, false))
    p.Name:SetText(UnitName(unit) or "")
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
-- Private auras use Blizzard's own anchors.
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

local function LaneLook(st, size, isDebuff)
    return ns.AuraLook and ns.AuraLook.ForUnit(size, isDebuff, false, UFAura("auraStyle", "square"), "icon", UFAura("auraTimer", "none"))
end

-- Below a frame come its cast bar and pet, then any auras placed below it
local function BelowOffset(f)
    local st = TS(f)
    local y = 0
    if st.castbar then y = y + (st.castHeight or 16) + K.CAST_GAP + K.INSET end
    if not f.ctx and GetPartyDb().pets then y = y + PET_GAP + (st.petHeight or 19) + 2 * K.INSET end
    return y
end

-- Where a place's auras start and which way they grow
local function AuraAnchor(f, pos)
    local gap, inset = K.AURA_GAP, 2
    local health = f.Health
    local H = AnchorUtil.FlowDirection
    local point, rel, relPoint, x, y, growH, growV
    if pos == "RIGHT" then
        point, rel, relPoint, x, y, growH, growV = "TOPLEFT", f, "TOPRIGHT", gap, -K.INSET, H.Right, H.Down
    elseif pos == "LEFT" then
        point, rel, relPoint, x, y, growH, growV = "TOPRIGHT", f, "TOPLEFT", -gap, -K.INSET, H.Left, H.Down
    elseif pos == "ABOVE" then
        point, rel, relPoint, x, y, growH, growV = "BOTTOMLEFT", f, "TOPLEFT", K.INSET, gap, H.Right, H.Up
    elseif pos == "ABOVE_RIGHT" then
        point, rel, relPoint, x, y, growH, growV = "BOTTOMRIGHT", f, "TOPRIGHT", -K.INSET, gap, H.Left, H.Up
    elseif pos == "BELOW" then
        point, rel, relPoint, x, y, growH, growV = "TOPLEFT", f, "BOTTOMLEFT", K.INSET, -gap - BelowOffset(f), H.Right, H.Down
    elseif pos == "BELOW_RIGHT" then
        point, rel, relPoint, x, y, growH, growV = "TOPRIGHT", f, "BOTTOMRIGHT", -K.INSET, -gap - BelowOffset(f), H.Left, H.Down
    elseif pos == "INSIDE_TOPLEFT" then
        point, rel, relPoint, x, y, growH, growV = "TOPLEFT", health, "TOPLEFT", inset, -inset, H.Right, H.Down
    elseif pos == "INSIDE_TOPRIGHT" then
        point, rel, relPoint, x, y, growH, growV = "TOPRIGHT", health, "TOPRIGHT", -inset, -inset, H.Left, H.Down
    elseif pos == "INSIDE_BOTTOMLEFT" then
        point, rel, relPoint, x, y, growH, growV = "BOTTOMLEFT", health, "BOTTOMLEFT", inset, inset, H.Right, H.Up
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
    local size = st.auraSize or 18
    local max = st.auraMax or 4
    local perRow = math_max(1, st.auraPerRow or max)
    local inside = pos:find("^INSIDE") ~= nil
    entry.generation = entry.generation + 1
    local gen = entry.generation
    for index, lane in ipairs(lanes) do
        local key = lane.key .. gen
        local isDebuff, kind = lane.isDebuff, lane.kind
        local laneSize = lane.scale and math_floor(size * lane.scale + 0.5) or size
        local look = kind ~= "dispels" and LaneLook(st, laneSize, isDebuff) or nil
        local showTimer = UFAura("auraTimer", "none") ~= "none"
        local font = db and db.font
        local unit = f.unit
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
    local sig = Signature(st.debuffs, st.buffs, st.dispels, st.auraSize, st.auraMax, st.auraPerRow, UFAura("auraStyle", "square"),
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
        Add(st.debuffs, { key = "debuffs", kind = "debuffs", filter = "HARMFUL|PLAYER", isDebuff = true })
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
    Add(st.dispels, { key = "dispels", kind = "dispels", filter = "HARMFUL", isDebuff = true,
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
        local look = LaneLook(st, size, false)
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
            initializeFrame = function(button)
                button:ClearAllPoints()
                button:SetAllPoints(health)
                button:SetFrameLevel(health:GetFrameLevel() + 2)
                if button.EnableMouse then pcall(button.EnableMouse, button, false) end
                local function AddTexture(tex)
                    tex:Hide()   -- until Blizzard shows it for a dispellable debuff
                    pcall(button.AddDispelTypeTexture, button, tex, {
                        style = styles.PreserveAsset, showWhenHarmful = true, showWhenHelpful = false,
                    })
                end
                local edges = {
                    { "TOPLEFT", "TOPRIGHT", nil, 2 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 2 },
                    { "TOPLEFT", "BOTTOMLEFT", 2, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 2, nil },
                }
                for _, e in ipairs(edges) do
                    local line = button:CreateTexture(nil, "OVERLAY")
                    line:SetTexture("Interface\\Buttons\\WHITE8x8")
                    line:SetPoint(e[1])
                    line:SetPoint(e[2])
                    if e[3] then line:SetWidth(e[3]) else line:SetHeight(e[4]) end
                    AddTexture(line)
                end
            end,
        })
        if ok then hlEntry.keys[#hlEntry.keys + 1] = key end
    end
    hlContainer:Show()
    pcall(hlContainer.SetEditModePreviewEnabled, hlContainer, false)
    pcall(hlContainer.UpdateAllAuras, hlContainer)
end

-- Private auras (boss mechanics addons cannot see) on Blizzard's anchors
local function ConfigurePrivateAuras(f)
    local api = C_UnitAuras
    if not (api and api.AddPrivateAuraAnchor) then return end
    local st0 = TS(f)
    local sig = Signature(st0 and st0.privateAuras, st0 and st0.privateAuraSize, RaidTile(f), f.unit)
    if f.privateSignature == sig then return end
    f.privateSignature = sig
    if f.privateAnchors then
        for _, id in ipairs(f.privateAnchors) do pcall(api.RemovePrivateAuraAnchor, id) end
    end
    f.privateAnchors = {}
    local st = TS(f)
    if not st or st.privateAuras == false or not f.unit then return end
    local size = st.privateAuraSize or 20
    local raid = RaidTile(f)
    for i = 1, PRIVATE_AURA_COUNT do
        local x = (i - (PRIVATE_AURA_COUNT + 1) / 2) * (size + 2)
        local ok, id = pcall(api.AddPrivateAuraAnchor, {
            unitToken = f.unit,
            auraIndex = i,
            parent = f,
            showCooldownFrame = true,   -- Forever's name for it (retail: showCountdownFrame)
            showCountdownNumbers = false,
            isContainer = false,
            iconInfo = {
                iconAnchor = {
                    point = raid and "BOTTOM" or "CENTER",
                    relativeTo = f.Health,
                    relativePoint = raid and "BOTTOM" or "CENTER",
                    offsetX = x, offsetY = raid and 2 or 0,
                },
                iconWidth = size,
                iconHeight = size,
            },
        })
        if ok and id then f.privateAnchors[#f.privateAnchors + 1] = id end
    end
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
    if RaidTile(f) or not st or (st.portrait or "none") == "none" then return 0 end
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
    portrait:ClearAllPoints()
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
        portrait:Hide()
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
    local reverse = st.absorbReverseFill ~= false
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
        texture = castTexture, border = true, borderTexture = castBorder,
    }
end

local function LayoutTexts(f)
    local st, raid = TS(f), RaidTile(f)
    local db = K.GetDb()
    local font = db and db.font
    K.ApplyFont(f.Name, font)
    K.ApplyFont(f.Level, font)
    K.ApplyFont(f.HealthText, font)
    K.ApplyFont(f.PowerText, db and (db.fontPower or db.font))
    local health, power = f.Health, f.Power
    local T = K.TEXT_INSET
    f.Name:ClearAllPoints()
    f.Level:ClearAllPoints()
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
        f.Level:Show()
        f.Level:SetJustifyH(near)
        f.Name:SetJustifyH(near)
        f.HealthText:SetJustifyH(far)
        f.Level:SetPoint(near, health, near, sx * T, 0)
        if st.showLevel then
            f.Name:SetPoint(near, f.Level, far, sx * 3, 0)
        else
            f.Name:SetPoint(near, health, near, sx * T, 0)
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
end

local function LayoutMember(f)
    local st = TS(f)
    if not st then return end
    if InCombatLockdown() then pendingLayout = true return end
    local PADDING = K.INSET
    f:SetSize(st.width or 200, st.height or 46)
    f:SetBackdrop({ bgFile = K.BACKDROP_FILE, insets = { left = PADDING, right = PADDING, top = PADDING, bottom = PADDING } })
    f:SetBackdropColor(0, 0, 0, K.BG_OPACITY)
    K.ApplyBorderStyle(f.Border, K.GetBorderFile(st.border), st.height or 46)

    local texture = K.GetBarTexture(st.texture)
    f.Health:SetStatusBarTexture(texture)
    f.Power:SetStatusBarTexture(texture)
    f.Health.bg:SetTexture(texture)
    f.Power.bg:SetTexture(texture)
    f.powerShown = WantsPower(f)
    LayoutBars(f)
    LayoutHealClip(f)
    LayoutTexts(f)
    LayoutIcons(f)
    if f.Cast then K.LayoutCastBar(f.Cast, CastStyle(st), f, "BOTTOM") end
    ConfigureAuras(f)
    ConfigureSlots(f)
    ConfigurePrivateAuras(f)
end

local function LayoutPet(p)
    local st = S()
    if not st then return end
    if InCombatLockdown() then pendingLayout = true return end
    local PADDING = K.INSET
    local owner = p.owner
    local height = st.petHeight or 19
    p:SetSize(st.petWidth or 120, height + 2 * PADDING)
    K.ApplyBorderStyle(p.Border, K.GetBorderFile(st.petBorder or "FlareUI Thin"), height + 2 * PADDING)
    local texture = K.GetBarTexture(st.texture)
    p.Health:SetStatusBarTexture(texture)
    p.Health.bg:SetTexture(texture)
    p.Health:ClearAllPoints()
    p.Health:SetPoint("TOPLEFT", p, "TOPLEFT", PADDING, -PADDING)
    p.Health:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -PADDING, PADDING)
    local db = K.GetDb()
    K.ApplyFont(p.Name, ScaledFont(db and db.font, math_max(8, math_min((db and db.font and db.font.size) or 12, height - 4))))
    p.Name:ClearAllPoints()
    p.Name:SetPoint("LEFT", p.Health, "LEFT", K.TEXT_INSET, 0)
    p.Name:SetPoint("RIGHT", p.Health, "RIGHT", -K.TEXT_INSET, 0)
    -- under the owner and its cast bar, right edges lined up
    local y = -PET_GAP
    if owner.Cast and owner.Cast.isEnabled() then y = y - (st.castHeight or 16) - K.CAST_GAP - PADDING end
    p:ClearAllPoints()
    p:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, y)
end

-- An aura row's height: the icon, plus its timer when that hangs under it
local function CellHeight(st, size)
    if UFAura("auraTimer", "none") == "below" then return size + math_max(7, math_floor(size * 0.4 + 0.5)) + 3 end
    return size
end

-- How far the lanes at these places reach out from the frame
local function LanesExtent(st, places, across)
    local size, max = st.auraSize or 18, st.auraMax or 4
    local perRow = math_max(1, st.auraPerRow or max)
    local best = 0
    for _, pos in ipairs(places) do
        local reach = 0
        if across then
            -- beside the frame: a row's width
            if st.debuffs == pos or st.buffs == pos or st.dispels == pos then
                local boss = (st.debuffs == pos and st.bigBossDebuffs ~= false) and math_floor(size * 0.5 + 0.5) * 2 or 0
                reach = perRow * (size + AURA_SPACING) + boss
            end
        else
            if st.debuffs == pos then
                reach = reach + math.ceil(max / perRow) * (CellHeight(st, size) + AURA_SPACING)
                if st.bigBossDebuffs ~= false then reach = reach + math_floor(size * 0.5 + 0.5) end
            end
            if st.dispels == pos then reach = reach + math.ceil(math_min(max, 3) / perRow) * (size + AURA_SPACING) end
            if st.buffs == pos then reach = reach + math.ceil(max / perRow) * (CellHeight(st, size) + AURA_SPACING) end
        end
        if reach > best then best = reach end
    end
    return best > 0 and (best + K.AURA_GAP) or 0
end

-- One step from a frame to the next, and where the first frame starts in the holder
local function Step()
    local st = S()
    local party = GetPartyDb()
    local above = LanesExtent(st, { "ABOVE", "ABOVE_RIGHT" })
    local below = LanesExtent(st, { "BELOW", "BELOW_RIGHT" })
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

-- Samples the aura containers cannot show in Edit Mode: dispel icons, private auras, the dispel
-- highlight
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
            local point, rel, relPoint, x, y, growH = AuraAnchor(f, place)
            local sx = growH == AnchorUtil.FlowDirection.Left and -1 or 1
            local offset = 0
            for i = 1, math_min(count, st.auraMax or 3) do
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
    -- dispel icons, at their place (under the debuffs' rows when they share it)
    local pos = st.dispels
    local sampled = not f.ctx or data.highlight
    if pos and pos ~= "OFF" and sampled then
        local point, rel, relPoint, x, y, growH, growV = AuraAnchor(f, pos)
        local sx = growH == AnchorUtil.FlowDirection.Left and -1 or 1
        local sy = growV == AnchorUtil.FlowDirection.Up and 1 or -1
        local skip = 0
        if st.debuffs == pos then
            local perRow = math_max(1, st.auraPerRow or st.auraMax or 4)
            skip = math.ceil((st.auraMax or 4) / perRow) * (CellHeight(st, size) + AURA_SPACING)
        end
        for i = 1, math_min(st.auraMax or 3, 3) do
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
    -- private auras, where Blizzard's anchors put them
    if st.privateAuras ~= false and sampled then
        local psize = st.privateAuraSize or 20
        local raid = RaidTile(f)
        for i = 1, PRIVATE_AURA_COUNT do
            used = used + 1
            local b = PreviewBit(f, used, psize)
            b.Icon:SetTexture(PRIVATE_SAMPLE_ICONS[i])
            b.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            local x = (i - (PRIVATE_AURA_COUNT + 1) / 2) * (psize + 2)
            if raid then
                b:SetPoint("BOTTOM", f.Health, "BOTTOM", x, 2)
            else
                b:SetPoint("CENTER", f.Health, "CENTER", x, 0)
            end
        end
    end
    -- the dispel highlight, on one sample member
    if data.highlight and (st.dispelHighlight or "mine") ~= "off" then
        local hl = f.HighlightSample
        if not hl then
            hl = CreateFrame("Frame", nil, f)
            hl.lines = {}
            for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, 2 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 2 },
                                 { "TOPLEFT", "BOTTOMLEFT", 2, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 2, nil } }) do
                local line = hl:CreateTexture(nil, "OVERLAY")
                line:SetTexture("Interface\\Buttons\\WHITE8x8")
                line:SetPoint(e[1])
                line:SetPoint(e[2])
                if e[3] then line:SetWidth(e[3]) else line:SetHeight(e[4]) end
                hl.lines[#hl.lines + 1] = line
            end
            f.HighlightSample = hl
        end
        hl:SetAllPoints(f.Health)
        hl:SetFrameLevel(f.Health:GetFrameLevel() + 2)
        local c = DISPEL_RGB[data.highlight] or DISPEL_RGB.Magic
        for _, line in ipairs(hl.lines) do line:SetVertexColor(c[1], c[2], c[3], 1) end
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
    if not RaidTile(f) and st.showLevel and data.level == -1 then
        f.Level:SetText("??")
        f.Level:SetTextColor(1, 0.1, 0.1)
    elseif not RaidTile(f) and st.showLevel then
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
    f.PowerText:SetText(st.powerText and AbbreviateNumbers(math_floor((data.power or 1) * 9000)) or "")
    if f.HealBar then f.HealBar:SetValue(0); f.AbsorbBar:SetValue(0) end

    -- the icons at their size again (Blizzard's role routine narrows the role icon to 1 px when the
    -- unit has no role)
    LayoutIcons(f)
    local function ShowIcon(key, region, fn)
        if IconShown(key, f) and fn() then region:Show() else region:Hide() end
    end
    -- the icon picked in the dialog shows on every frame, so it can be placed
    local picked = selectedIcon
    ShowIcon("role", f.RoleIcon, function()
        local atlas = ROLE_ATLAS[data.role or "DAMAGER"]
        if not (atlas and K.HasAtlas(atlas)) then return false end
        f.RoleIcon:SetAtlas(atlas, false)
        return true
    end)
    ShowIcon("leader", f.LeaderIcon, function()
        if not (data.leader or picked == "leader") then return false end
        K.SetIconArt(f.LeaderIcon, "UI-HUD-UnitFrame-Player-Group-LeaderIcon", "Interface\\GroupFrame\\UI-Group-LeaderIcon")
        return true
    end)
    ShowIcon("raidIcon", f.RaidIcon, function()
        if not (data.marker or picked == "raidIcon") then return false end
        SetRaidTargetIconTexture(f.RaidIcon, data.marker or 8)
        return true
    end)
    ShowIcon("readyCheck", f.ReadyIcon, function()
        local status = data.ready or (picked == "readyCheck" and "ready")
        if not status then return false end
        f.ReadyIcon:SetAtlas(READY_ATLAS[status], false)
        return true
    end)
    ShowIcon("status", f.StatusIcon, function()
        local state = data.status or (picked == "status" and "IncomingSummonPending")
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
    pcall(ConfigurePrivateAuras, f)
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
    p:SetScript("OnEvent", function(self) UpdatePet(self) end)
    for _, event in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE", "UNIT_CONNECTION" }) do
        pcall(p.RegisterUnitEvent, p, event, p.unit)
    end
    p:HookScript("OnShow", UpdatePet)
    pets[index] = p
    return p
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

-- The defaults of the style in use, for the dialog's reset
local function StyleDefaults()
    local _, key = S()
    local d = ns.defaults and ns.defaults.profile.unitframes.party
    return (d and d[key or "classic"]) or {}
end

local RebuildSettings   -- the dialog is rebuilt when the style or the picked icon changes

local function BuildSettings()
    local settings = {}
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

    local function SectionOpen(name)
        local db = K.GetDb()
        return db and db.editSections and db.editSections[name] or false
    end
    local function Section(name, items)
        settings[#settings + 1] = { name = "|cffffd100" .. L[name] .. "|r", kind = LEM.SettingType.Expander, default = false,
            get = function() return SectionOpen(name) end,
            set = function(_, value)
                local db = K.GetDb()
                if not db then return end
                db.editSections = db.editSections or {}
                db.editSections[name] = value and true or nil
            end }
        for _, item in ipairs(items) do
            local own = item.hidden
            item.hidden = function(...)
                if not SectionOpen(name) then return true end
                if type(own) == "function" then return own(...) end
                return own
            end
            settings[#settings + 1] = item
        end
    end

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
        { name = L["Show Player"], kind = LEM.SettingType.Checkbox, default = true, get = getP("showPlayer", true), set = setP("showPlayer"),
          desc = L["Your own frame first, with the party."] },
        { name = L["Pets"], kind = LEM.SettingType.Checkbox, default = false, get = getP("pets", false), set = setP("pets"),
          desc = L["A small frame for each pet, under its owner."] },
        { name = L["Sort by Role"], kind = LEM.SettingType.Checkbox, default = true, get = getP("sortByRole", true), set = setP("sortByRole"),
          desc = L["Tanks first, then healers, then damage dealers. A change during combat is applied when the fight ends."] },
        { name = L["Orientation"], kind = LEM.SettingType.Dropdown, default = "VERTICAL",
          values = { { text = L["Vertical"], value = "VERTICAL", isRadio = true }, { text = L["Horizontal"], value = "HORIZONTAL", isRadio = true } },
          get = getP("orientation", "VERTICAL"), set = setP("orientation") },
    })

    Section("Frame", {
        { name = L["Width"], kind = LEM.SettingType.Slider, default = D.width, minValue = 60, maxValue = 400, valueStep = 2, get = getS("width"), set = setS("width") },
        { name = L["Height"], kind = LEM.SettingType.Slider, default = D.height, minValue = 20, maxValue = 120, valueStep = 1, get = getS("height"), set = setS("height") },
        { name = L["Power Bar Height"], kind = LEM.SettingType.Slider, default = D.powerHeight, minValue = 0, maxValue = 30, valueStep = 1,
          get = getS("powerHeight"), set = setS("powerHeight"), formatter = function(value) return value == 0 and _G.OFF or value end },
        { name = L["Power Bar for Healers Only"], kind = LEM.SettingType.Checkbox, default = D.healersOnlyPower or false, get = getS("healersOnlyPower"), set = setS("healersOnlyPower") },
        { name = L["Health Text"], kind = LEM.SettingType.Dropdown, default = D.healthText, values = K.HEALTH_TEXT_MODES, get = getS("healthText"), set = setS("healthText") },
        { name = L["Power Text"], kind = LEM.SettingType.Checkbox, default = D.powerText or false, get = getS("powerText"), set = setS("powerText"), hidden = classicOnly },
        { name = L["Show Level"], kind = LEM.SettingType.Checkbox, default = D.showLevel ~= false, get = getS("showLevel"), set = setS("showLevel"), hidden = classicOnly },
        { name = L["Portrait"], kind = LEM.SettingType.Dropdown, default = D.portrait or "none",
          values = { { text = L["None"], value = "none", isRadio = true }, { text = L["3D"], value = "3d", isRadio = true }, { text = L["Class Icon"], value = "class", isRadio = true } },
          get = getS("portrait"), set = setS("portrait"), hidden = classicOnly },
    })

    -- debuffs, buffs and dispel icons never share a place: a place taken by one is greyed out on
    -- the others
    local AURA_FIELDS = { "buffs", "debuffs", "dispels" }
    local function Place(field)
        return function(_, rootDescription, data)
            local st = S()
            for _, p in ipairs(AURA_POSITION_VALUES) do
                local radio = rootDescription:CreateRadio(p.text,
                    function(value) local now = S(); return now and now[field] == value end,
                    function(value) data.set(nil, value) end, p.value)
                if st and p.value ~= "OFF" and radio.SetEnabled then
                    for _, other in ipairs(AURA_FIELDS) do
                        if other ~= field and st[other] == p.value then radio:SetEnabled(false) end
                    end
                end
            end
        end
    end
    Section("Auras", {
        { name = L["Buffs"], kind = LEM.SettingType.Dropdown, default = D.buffs, values = AURA_POSITION_VALUES, generator = Place("buffs"),
          get = getS("buffs"), set = setS("buffs"),
          desc = L["Buffs as Blizzard's raid frames pick them: mostly your own heals over time and buffs."] },
        { name = L["Debuffs"], kind = LEM.SettingType.Dropdown, default = D.debuffs, values = AURA_POSITION_VALUES, generator = Place("debuffs"),
          get = getS("debuffs"), set = setS("debuffs"),
          desc = L["Debuffs as Blizzard's raid frames pick them: boss and role debuffs, priority debuffs, and the ones you can dispel."] },
        { name = L["Dispel Icons"], kind = LEM.SettingType.Dropdown, default = D.dispels, values = AURA_POSITION_VALUES, generator = Place("dispels"),
          get = getS("dispels"), set = setS("dispels"),
          desc = L["The symbol of each debuff type you can dispel (Magic, Curse, Disease, Poison)."] },
        { name = L["Bigger Boss Debuffs"], kind = LEM.SettingType.Checkbox, default = D.bigBossDebuffs ~= false, get = getS("bigBossDebuffs"), set = setS("bigBossDebuffs"),
          desc = L["Boss and role debuffs first and half again as big, as Blizzard's raid frames show them."] },
        { name = L["Aura Size"], kind = LEM.SettingType.Slider, default = D.auraSize, minValue = 10, maxValue = 40, valueStep = 1, get = getS("auraSize"), set = setS("auraSize") },
    })

    Section("Important Auras", {
        { name = L["Dispel Highlight"], kind = LEM.SettingType.Dropdown, default = D.dispelHighlight,
          values = { { text = L["Off"], value = "off", isRadio = true }, { text = L["Dispellable by Me"], value = "mine", isRadio = true },
                     { text = L["Dispellable by the Group"], value = "all", isRadio = true } },
          desc = L["A dispellable debuff outlines the health bar in its type's colour."],
          get = getS("dispelHighlight"), set = setS("dispelHighlight") },
    })

    Section("Cast Bar", {
        { name = L["Cast Bars"], kind = LEM.SettingType.Checkbox, default = D.castbar or false, get = getS("castbar"), set = setS("castbar") },
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
Refresh = function()
    if not holder then return end
    if InCombatLockdown() then pendingLayout = true return end
    pendingLayout = false
    for i = 0, MAX_MEMBERS do
        local f = members[i]
        local ok, err = pcall(LayoutMember, f)
        if not ok then geterrorhandler()(err) end
        if pets[i] then pcall(LayoutPet, pets[i]) end
    end
    LayoutHolder()
    ApplyPosition()
    ApplyVisibility()
    for i = 0, MAX_MEMBERS do
        UpdateAll(members[i])
        if pets[i] then UpdatePet(pets[i]) end
    end
end

function PF:Refresh()
    Refresh()
end

-- The tile kit (Modules/RaidFrames.lua builds its tiles with it). A tile's owner sets f.ctx:
--   Settings()    the tile settings (the party style's keys)
--   PreviewData(f) the sample shown in Edit Mode
--   ReadyHold()   true while a finished ready check's results stay up
PF.Tile = {
    Build = BuildTile, SetUnit = SetTileUnit, Layout = LayoutMember, UpdateAll = UpdateAll,
    UpdateRange = UpdateRange, UpdateTarget = UpdateTarget, UpdateRaidIcon = UpdateRaidIcon,
    UpdateLeader = UpdateLeader, UpdateRole = UpdateRole, UpdatePower = UpdatePower,
    UpdateReadyCheck = UpdateReadyCheck, UpdateStatus = UpdateStatus, UpdateThreat = UpdateThreat,
    OnEnter = OnEnter, OnLeave = OnLeave,
    AURA_POSITION_VALUES = AURA_POSITION_VALUES, ICON_ORDER = ICON_ORDER, ICON_LABELS = ICON_LABELS,
    IconShown = IconShown, IconStore = IconStore, LanesExtent = LanesExtent,
    PREVIEW_CLASS_RGB = PREVIEW_CLASS_RGB,
}

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
end

local GLOBAL_EVENTS = {
    "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "RAID_TARGET_UPDATE", "PLAYER_TARGET_CHANGED",
    "PLAYER_ROLES_ASSIGNED", "READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED",
    "INCOMING_SUMMON_CHANGED", "INCOMING_RESURRECT_CHANGED", "PLAYER_ENTERING_WORLD", "UNIT_PET",
    "PLAYER_REGEN_ENABLED",
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

    holder = CreateFrame("Frame", "FlareUI_Party", UIParent)
    holder:SetFrameStrata("LOW")
    holder:SetClampedToScreen(true)
    holder:SetSize(200, 200)
    holder.editModeName = "FlareUI Party Frames"
    for i = 0, MAX_MEMBERS do CreateMember(i) end
    for i = 0, MAX_MEMBERS do CreatePet(i) end

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
