local _, ns = ...
local L = ns.L

--------------------------------------------------
-- XP BAR
-- FlareUI's XP bar in place of Blizzard's status tracking bars: XP, reputation or honor in two
-- sections, placed in Edit Mode. Loads with the Action Bars module.
--------------------------------------------------

--------------------------------------------------
-- 1. MODULE REGISTRATION
--------------------------------------------------
ns.XPBar = ns.XPBar or {}
local XPB = ns.XPBar
ns.modules["XPBar"] = XPB

--------------------------------------------------
-- 2. UPVALUES
--------------------------------------------------
local _G = _G
local ipairs = ipairs
local CreateFrame = CreateFrame
local LSM = LibStub("LibSharedMedia-3.0")

--------------------------------------------------
-- 3. CONSTANTS
--------------------------------------------------
local TEXTURE_NAME  = "FlareUI Flat"
local BORDER_NAME   = "FlareUI Thin"
local BORDER_SIZE   = 16
local BORDER_COLOR  = { 0.80, 0.60, 0.34 }         -- #CC9957
local TRACK_COLOR   = { 0.15, 0.15, 0.15, 0.9 }

-- Blizzard's XP purple and rested blue
local COLOR_XP     = { 0.58, 0.00, 0.55 }          -- #94008C
local COLOR_RESTED = { 0.00, 0.39, 0.88 }          -- #0063E0

--------------------------------------------------
-- 4. HELPERS
--------------------------------------------------
local function GetDb()
    local ab = ns.db and ns.db.profile and ns.db.profile.actionbars
    return ab and ab.xpbar
end

local function GetTexture()
    return LSM:Fetch("statusbar", TEXTURE_NAME) or "Interface\\Buttons\\WHITE8x8"
end

local function ApplyFont(fontString)
    local fontDb = ns.db and ns.db.profile.actionbars and ns.db.profile.actionbars.hotkeyFont
    local flags = fontDb and fontDb.flags or "OUTLINE"
    if flags == "NONE" then flags = "" end
    fontString:SetFont(ns.GetFontPath(fontDb and fontDb.face or "Friz Quadrata TT"), fontDb and fontDb.size or 12, flags)
    ns.ApplyShadow(fontString, fontDb)
end

--------------------------------------------------
-- 5. THE FLAREUI XP BAR
-- Two sections in one border, meeting under Blizzard's rested pip; Blizzard's bars are hidden.
--   Below max level   left: XP              right: the watched reputation, or Honor without one
--   At max level      left: the reputation   right: Honor
-- An empty section gives its room to the other; with nothing to show the bar hides. Values are
-- read as Blizzard_StatusTrackingBar reads them.
--------------------------------------------------
local FLARE_NAME    = "FlareUI_XPBar"
local FLARE_LABEL   = "FlareUI XP Bar"
local FLARE_INSET   = 4                        -- the fill starts this far in, inside the border's line
local FLARE_DEFAULT = { point = "TOP", x = 0, y = -1 }
-- Blizzard's rested XP pip (10 x 14)
local PIP_ATLAS, PIP_RATIO, PIP_OVERHANG = "UI-HUD-ExperienceBar-Frame-Pip", 10 / 14, 2
local REST_ALPHA    = 0.4
local COLOR_MAJOR   = COLOR_RESTED                      -- renown factions: Blizzard's blue bar
local STANDING_BY_REACTION = { "FACTION_RED_COLOR", "FACTION_RED_COLOR", "FACTION_ORANGE_COLOR",
    "FACTION_YELLOW_COLOR", "FACTION_GREEN_COLOR", "FACTION_GREEN_COLOR", "FACTION_GREEN_COLOR", "FACTION_GREEN_COLOR" }

local flare                                    -- the bar frame
local LEM

local function Percent(value, maxValue)
    return maxValue > 0 and value / maxValue * 100 or 0
end

-- A section's text: current / max, as Blizzard's bars show it (shown on mouseover)
local function FormatValues(value, maxValue)
    return ("%s / %s"):format(BreakUpLargeNumbers(value), BreakUpLargeNumbers(maxValue))
end

-- Each kind of section: value, max, rested bonus (XP only), colour, text and tooltip
local Read = {}

function Read.xp()
    local value, maxValue = UnitXP("player"), UnitXPMax("player")
    if not maxValue or maxValue <= 0 then value, maxValue = 0, 1 end
    local rested = GetXPExhaustion() or 0
    local color = rested > 0 and COLOR_RESTED or COLOR_XP
    return {
        value = value, max = maxValue, rested = rested, color = color,
        -- Blizzard's own experience bar text ("XP: 1234/5000")
        text = XP_STATUS_BAR_TEXT and XP_STATUS_BAR_TEXT:format(value, maxValue) or FormatValues(value, maxValue),
        tooltip = function(tip)
            GameTooltip_SetTitle(tip, XP_TEXT:format(BreakUpLargeNumbers(value), BreakUpLargeNumbers(maxValue), math.ceil(Percent(value, maxValue))))
            local stateID, stateName, multiplier = GetRestState()
            if stateID and stateName and multiplier then
                GameTooltip_AddHighlightLine(tip, EXHAUST_TOOLTIP1:format(stateName, multiplier * 100))
            end
        end,
    }
end

function Read.rep(data)
    local factionID = data.factionID
    local low, high, value = data.currentReactionThreshold or 0, data.nextReactionThreshold or 1, data.currentStanding or 0
    local reaction, color = data.reaction or 4, nil
    local standing = GetText("FACTION_STANDING_LABEL" .. reaction, UnitSex("player"))
    local capped = false
    if C_Reputation.IsFactionParagonForCurrentPlayer and C_Reputation.IsFactionParagonForCurrentPlayer(factionID) then
        local current, threshold, _, rewardPending = C_Reputation.GetFactionParagonInfo(factionID)
        low, high, value = 0, threshold or 1, (current or 0) % (threshold or 1)
        if rewardPending then value = value + (threshold or 0) end
    elseif C_Reputation.IsMajorFaction and C_Reputation.IsMajorFaction(factionID) then
        local major = C_MajorFactions.GetMajorFactionData(factionID)
        low, high, value = 0, major and major.renownLevelThreshold or 1, major and major.renownReputationEarned or 0
        color = COLOR_MAJOR
        if major then standing = RENOWN_LEVEL_LABEL and RENOWN_LEVEL_LABEL:format(major.renownLevel) or standing end
    else
        local friend = C_GossipInfo.GetFriendshipReputation(factionID)
        if friend and friend.friendshipFactionID and friend.friendshipFactionID > 0 then
            reaction = 5
            standing = friend.reaction or standing
            if friend.nextThreshold then
                low, high, value = friend.reactionThreshold, friend.nextThreshold, friend.standing
            else
                capped = true
            end
        elseif reaction >= MAX_REPUTATION_REACTION then
            capped = true   -- as Blizzard's bar: at the top standing only the name shows
        end
    end
    local maxValue = high - low
    value = value - low
    if capped or maxValue <= 0 then value, maxValue = 1, 1 end
    if not color then
        local named = _G[STANDING_BY_REACTION[reaction] or "FACTION_YELLOW_COLOR"]
        color = named and { named:GetRGB() } or COLOR_RESTED
    end
    return {
        value = value, max = maxValue, rested = 0, color = color,
        text = capped and data.name or (data.name .. "  " .. FormatValues(value, maxValue)),
        tooltip = function(tip)
            GameTooltip_SetTitle(tip, data.name)
            GameTooltip_AddNormalLine(tip, standing)
            if not capped then GameTooltip_AddHighlightLine(tip, FormatValues(value, maxValue)) end
        end,
    }
end

function Read.honor()
    local value, maxValue = UnitHonor("player") or 0, UnitHonorMax("player") or 1
    if maxValue <= 0 then maxValue = 1 end
    local faction = UnitFactionGroup("player")
    local named = (faction == "Alliance" and PLAYER_FACTION_COLOR_ALLIANCE) or (faction == "Horde" and PLAYER_FACTION_COLOR_HORDE)
    local color = named and { named:GetRGB() } or COLOR_RESTED
    return {
        value = value, max = maxValue, rested = 0, color = color,
        text = HONOR .. "  " .. FormatValues(value, maxValue),
        tooltip = function(tip)
            GameTooltip_SetTitle(tip, HONOR)
            if UnitHonorLevel and HONOR_LEVEL_LABEL then
                GameTooltip_AddNormalLine(tip, HONOR_LEVEL_LABEL:format(UnitHonorLevel("player")))
            end
            GameTooltip_AddHighlightLine(tip, FormatValues(value, maxValue))
        end,
    }
end

-- Blizzard's bar manager's tests (CanShowBar)
local function WatchedReputation()
    local data = C_Reputation.GetWatchedFactionData()
    if data and data.name and data.name ~= "" and data.factionID and data.factionID ~= 0 then return data end
end

local function TracksHonor()
    return (IsWatchingHonorAsXP and IsWatchingHonorAsXP()) or (C_PvP.IsActiveBattlefield and C_PvP.IsActiveBattlefield())
        or (IsInActiveWorldPVP and IsInActiveWorldPVP()) or false
end

local function ShowsXP()
    if GameRulesUtil and GameRulesUtil.CanShowExperienceBar then return GameRulesUtil.CanShowExperienceBar() end
    return not IsXPUserDisabled() and not (GameRulesUtil and GameRulesUtil.IsPlayerAtEffectiveMaxLevel())
end

-- The two sections' contents (nil = nothing to show there)
local function PickSections()
    local rep, honor = WatchedReputation(), TracksHonor()
    if ShowsXP() then
        return Read.xp(), (rep and Read.rep(rep)) or (honor and Read.honor()) or nil
    end
    local left = (rep and Read.rep(rep)) or (honor and Read.honor()) or nil
    local right = (rep and honor) and Read.honor() or nil
    return left, right
end

-- Edit Mode samples, so the frame can be placed whatever is tracked
local function SampleSections()
    return { value = 6, max = 10, rested = 2, color = COLOR_RESTED, text = L["XP"] },
           { value = 4, max = 10, rested = 0, color = FACTION_GREEN_COLOR and { FACTION_GREEN_COLOR:GetRGB() } or COLOR_RESTED, text = REPUTATION }
end

local function CreateSection(parent)
    local section = CreateFrame("StatusBar", nil, parent)
    section:SetMinMaxValues(0, 1)
    section:SetValue(0)
    section:EnableMouse(true)

    local track = section:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    section.Track = track

    -- rested XP: from the left edge to where the bonus would take the fill, under the fill
    local rested = section:CreateTexture(nil, "BORDER")
    rested:SetPoint("TOPLEFT")
    rested:SetPoint("BOTTOMLEFT")
    rested:Hide()
    section.Rested = rested

    local textHolder = CreateFrame("Frame", nil, section)
    textHolder:SetAllPoints()
    textHolder:SetFrameLevel(section:GetFrameLevel() + 2)
    local text = textHolder:CreateFontString(nil, "OVERLAY")
    text:SetPoint("LEFT", 4, 0)
    text:SetPoint("RIGHT", -4, 0)
    text:SetWordWrap(false)
    section.Text = text

    section:SetScript("OnEnter", function(self)
        local db = GetDb()
        if not (db and db.textMode == "ALWAYS") then self.Text:Show() end
        if self.info and self.info.tooltip and not (db and db.showTooltip == false) then
            GameTooltip:SetOwner(self, "ANCHOR_NONE")
            local _, y = self:GetCenter()
            if y and y > UIParent:GetHeight() / 2 then
                GameTooltip:SetPoint("TOP", self, "BOTTOM", 0, -FLARE_INSET - 2)
            else
                GameTooltip:SetPoint("BOTTOM", self, "TOP", 0, FLARE_INSET + 2)
            end
            self.info.tooltip(GameTooltip)
            GameTooltip:Show()
        end
    end)
    section:SetScript("OnLeave", function(self)
        local db = GetDb()
        if not (db and db.textMode == "ALWAYS") then self.Text:Hide() end
        GameTooltip:Hide()
    end)
    return section
end

local function FillSection(section, info, width)
    section.info = info
    if not info then section:Hide() return end
    local fraction = info.max > 0 and info.value / info.max or 0
    local smooth = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
    if smooth and section:IsShown() then section:SetValue(fraction, smooth) else section:SetValue(fraction) end
    local r, g, b = info.color[1], info.color[2], info.color[3]
    section:SetStatusBarColor(r, g, b, 1)
    if info.rested and info.rested > 0 then
        local reach = math.min(1, (info.value + info.rested) / info.max)
        section.Rested:SetWidth(math.max(1, reach * width))
        section.Rested:SetVertexColor(r, g, b, REST_ALPHA)
        section.Rested:Show()
    else
        section.Rested:Hide()
    end
    section.Text:SetText(info.text or "")
    section:Show()
end

local function UpdateFlare()
    if not flare then return end
    local db = GetDb()
    local left, right
    if LEM:IsInEditMode() then left, right = SampleSections() else left, right = PickSections() end
    if not left and not right then flare:Hide() return end
    left, right = left or right, left and right or nil

    local width, height = db.width or 560, db.height or 14
    local leftWidth = right and width / 2 or width
    flare.Left:ClearAllPoints()
    flare.Left:SetPoint("TOPLEFT", flare, "TOPLEFT", FLARE_INSET, -FLARE_INSET)
    flare.Left:SetSize(leftWidth, height)
    flare.Right:ClearAllPoints()
    flare.Right:SetPoint("TOPRIGHT", flare, "TOPRIGHT", -FLARE_INSET, -FLARE_INSET)
    flare.Right:SetSize(leftWidth, height)
    FillSection(flare.Left, left, leftWidth)
    FillSection(flare.Right, right, leftWidth)
    local pipHeight = height + 2 * PIP_OVERHANG
    flare.Pip:SetSize(math.max(4, math.floor(pipHeight * PIP_RATIO + 0.5)), pipHeight)
    flare.Pip:SetShown(right ~= nil)
    flare:Show()
end

local function LayoutFlare()
    if not flare then return end
    local db = GetDb()
    local texture = GetTexture()
    flare:SetSize((db.width or 560) + 2 * FLARE_INSET, (db.height or 14) + 2 * FLARE_INSET)
    local file = LSM:Fetch("border", BORDER_NAME)
    flare.Border:SetBackdrop({ edgeFile = file, edgeSize = ns.BorderEdgeSize(file, BORDER_SIZE),
        bgFile = "Interface\\Buttons\\WHITE8x8", insets = { left = FLARE_INSET, right = FLARE_INSET, top = FLARE_INSET, bottom = FLARE_INSET } })
    flare.Border:SetBackdropColor(0, 0, 0, 0.8)
    flare.Border:SetBackdropBorderColor(BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3], 1)
    for _, section in ipairs({ flare.Left, flare.Right }) do
        section:SetStatusBarTexture(texture)
        section.Track:SetTexture(texture)
        section.Track:SetVertexColor(TRACK_COLOR[1], TRACK_COLOR[2], TRACK_COLOR[3], TRACK_COLOR[4])
        section.Rested:SetTexture(texture)
        ApplyFont(section.Text)
        section.Text:SetShown(db.textMode == "ALWAYS")
    end
    UpdateFlare()
end

-- Position, per Edit Mode layout
local function FlareStore(layoutName)
    local db = GetDb()
    layoutName = layoutName or LEM:GetActiveLayoutName() or "Modern"
    db.layouts = db.layouts or {}
    db.layouts[layoutName] = db.layouts[layoutName] or {}
    return db.layouts[layoutName]
end

local function PlaceFlare(layoutName)
    if not flare then return end
    local pos = FlareStore(layoutName).point and FlareStore(layoutName) or FLARE_DEFAULT
    flare:ClearAllPoints()
    flare:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
end

local function OnFlareMoved(_, layoutName, point, x, y)
    local store = FlareStore(layoutName)
    store.point, store.x, store.y = point, math.floor(x + 0.5), math.floor(y + 0.5)
end

-- Blizzard's bars stay hidden while ours is on: a state driver, plus a Show hook for Edit Mode
local function KeepBlizzardBarsHidden()
    for _, name in ipairs({ "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }) do
        local frame = _G[name]
        if frame then
            if not InCombatLockdown() then ns.RawHide(frame) end
            pcall(RegisterStateDriver, frame, "visibility", "hide")
            hooksecurefunc(frame, "Show", function(f) if not InCombatLockdown() then ns.RawHide(f) end end)
        end
    end
end

local FLARE_EVENTS = {
    "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION", "PLAYER_UPDATE_RESTING",
    "ENABLE_XP_GAIN", "DISABLE_XP_GAIN", "UPDATE_EXPANSION_LEVEL", "PLAYER_MAX_LEVEL_UPDATE",
    "UPDATE_FACTION", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "HONOR_XP_UPDATE", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA",
}

local function BuildFlare()
    LEM = LibStub("FlareEditMode")
    flare = CreateFrame("Frame", FLARE_NAME, UIParent)
    flare:SetFrameStrata("LOW")
    flare:SetClampedToScreen(true)
    flare.Border = CreateFrame("Frame", nil, flare, "BackdropTemplate")
    flare.Border:SetAllPoints()
    flare.Left = CreateSection(flare)
    flare.Right = CreateSection(flare)
    flare.Border:SetFrameLevel(flare:GetFrameLevel())
    flare.Left:SetFrameLevel(flare:GetFrameLevel() + 2)
    flare.Right:SetFrameLevel(flare:GetFrameLevel() + 2)
    local pipHolder = CreateFrame("Frame", nil, flare)
    pipHolder:SetAllPoints()
    pipHolder:SetFrameLevel(flare:GetFrameLevel() + 5)
    flare.Pip = pipHolder:CreateTexture(nil, "OVERLAY")
    flare.Pip:SetAtlas(PIP_ATLAS)
    flare.Pip:SetPoint("CENTER", flare, "CENTER", 0, 0)
    flare.Pip:Hide()

    -- events come in bursts; one update per frame
    local queued = false
    flare:SetScript("OnEvent", function()
        if queued then return end
        queued = true
        C_Timer.After(0, function() queued = false; UpdateFlare() end)
    end)
    for _, event in ipairs(FLARE_EVENTS) do pcall(flare.RegisterEvent, flare, event) end

    KeepBlizzardBarsHidden()

    LEM:AddFrame(flare, OnFlareMoved, FLARE_DEFAULT, FLARE_LABEL)
    LEM:AddFrameSettings(flare, {
        { name = L["Width"], kind = LEM.SettingType.Slider, default = 560, minValue = 200, maxValue = 1200, valueStep = 2,
          get = function() return GetDb().width or 560 end, set = function(_, value) GetDb().width = value; LayoutFlare() end },
        { name = L["Height"], kind = LEM.SettingType.Slider, default = 14, minValue = 6, maxValue = 30, valueStep = 1,
          get = function() return GetDb().height or 14 end, set = function(_, value) GetDb().height = value; LayoutFlare() end },
    })
    LEM:RegisterCallback("layout", function(layoutName) PlaceFlare(layoutName) end)
    LEM:RegisterCallback("enter", UpdateFlare)
    LEM:RegisterCallback("exit", UpdateFlare)

    PlaceFlare()
    LayoutFlare()
end

--------------------------------------------------
-- 6. PUBLIC
--------------------------------------------------
function XPB:ShouldLoad()
    local ab = ns.db and ns.db.profile and ns.db.profile.actionbars
    return ab and ab.enabled and ab.xpbar and ab.xpbar.enabled or false
end

-- The FlareUI XP Bar, for the Visibility module's fader
function XPB:GetFrame()
    return flare
end

function XPB:Refresh()
    if flare then
        PlaceFlare()
        LayoutFlare()
    end
end

function XPB:Init()
    if self.initialized or not GetDb() then return end
    self.initialized = true
    BuildFlare()
    C_Timer.After(0, function()
        if ns.Visibility and ns.Visibility.Refresh then ns.Visibility:Refresh() end
    end)
end
