local _, ns = ...
local L = ns.L

--------------------------------------------------
-- XP BAR
-- Replaces Blizzard's status tracking bars: XP, reputation or honor in two sections, placed in
-- Edit Mode. Loads with the Action Bars module.
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
local TEXTURE_NAME  = "FlareUI Dark"   -- Bar Texture's default
local BORDER_NAME   = "FlareUI Thin"
local BORDER_SIZE   = 16
local BORDER_COLOR  = { 0.80, 0.60, 0.34 }         -- #CC9957
local TRACK_COLOR   = { 0.15, 0.15, 0.15, 0.9 }

-- the XP and rested colours: XPB.DefaultColor / XPB.Color (XP Bar Colours)
-- the rested bonus ahead of the fill: light blue, apart from the fill's own blue
local COLOR_REST_BONUS = { 0.40, 0.80, 1.00 }      -- #66CCFF
-- Quest XP: what the quests ready to hand in would give
local COLOR_QUEST  = { 1.00, 0.76, 0.10 }

--------------------------------------------------
-- 4. HELPERS
--------------------------------------------------
local function GetDb()
    local ab = ns.db and ns.db.profile and ns.db.profile.actionbars
    return ab and ab.xpbar
end

local function GetTexture()
    local db = GetDb()
    local name = db and db.texture
    if not (name and LSM:IsValid("statusbar", name)) then name = TEXTURE_NAME end
    return LSM:Fetch("statusbar", name) or "Interface\\Buttons\\WHITE8x8"
end

-- "Bar Texture" choices: FlareUI's bars, a divider, then other addons' (the settings page reads them)
local function TextureValues()
    local values = {}
    for _, name in ipairs({ "FlareUI Flat", "FlareUI Dark", "FlareUI Light", "FlareUI Striped" }) do
        if LSM:IsValid("statusbar", name) then values[#values + 1] = { text = name, value = name, isRadio = true } end
    end
    local others = ns.AddonMedia("statusbar")
    if #others > 0 then
        values[#values + 1] = { isDivider = true }
        for _, name in ipairs(others) do values[#values + 1] = { text = name, value = name, isRadio = true } end
    end
    return values
end

-- Action Bars > Fonts > XP Bar: its own font, seeded once from the Keybinds font
local function ApplyFont(fontString)
    local ab = ns.db and ns.db.profile.actionbars
    if ab then ns.SeedFont(ab, "hotkeyFont", "xpFont", "xpFontSeeded") end
    local fontDb = ab and ab.xpFont
    local flags = fontDb and fontDb.flags or "OUTLINE"
    if flags == "NONE" then flags = "" end
    ns.SetFont(fontString, ns.GetFontPath(fontDb and fontDb.face or "Friz Quadrata TT"), fontDb and fontDb.size or 12, flags)
    ns.ApplyShadow(fontString, fontDb)
end

--------------------------------------------------
-- 5. THE FLAREUI XP BAR
-- Two sections in one border under Blizzard's rested pip. Below max level: XP, then the watched
-- reputation or Honor; at max level: reputation, then Honor. An empty section yields its room;
-- values are read as Blizzard_StatusTrackingBar reads them.
-- Style (actionbars.xpbar.style; Off saves enabled = false and never loads the bar):
--   single: the first section only, the whole width
--   split : both side by side (the default)
--   double: both the whole width, the second below the first, as Blizzard stacks its two bars
--------------------------------------------------
local FLARE_NAME    = "FlareUI_XPBar"
local FLARE_LABEL   = "FlareUI XP Bar"
local FLARE_INSET   = 4                        -- the fill starts this far in, inside the border's line
local FLARE_DEFAULT = { point = "TOP", x = 0, y = -1 }
-- Blizzard's rested XP pip (10 x 14)
local PIP_ATLAS, PIP_RATIO, PIP_OVERHANG = "UI-HUD-ExperienceBar-Frame-Pip", 10 / 14, 2
local REST_ALPHA    = 0.4
-- Bubbles: the classic XP bar's 20 bubbles of 5% (or 10 of 10%), each divider a dark line with a light edge
local BUBBLES       = 20                           -- the most bubbles; the dropdown picks 0, 10 or 20
local BUBBLE_DARK, BUBBLE_LIGHT = 0.85, 0.28           -- the two lines' alpha
local DOUBLE_GAP    = 3                            -- Double: the dark gap between the two bars
-- each reaction's colour key (Blizzard's FACTION_*_COLOR: Hated and Hostile red ... Friendly up green)
local STANDING_BY_REACTION = { "repHostile", "repHostile", "repUnfriendly", "repNeutral",
    "repFriendly", "repFriendly", "repFriendly", "repFriendly" }

-- XP Bar Colours: every colour the bar paints, FlareUI's (Blizzard's own) or yours
-- (actionbars.xpbar.palette "custom", actionbars.xpbar.customColors), picked in the colour window
-- (Settings/ColorPicker.lua "xp"). Honor: your faction's colour unless you pick one.
function XPB.DefaultColor(key)
    if key == "xp" then return { 0.58, 0.00, 0.55 }
    elseif key == "rested" or key == "renown" then return { 0.00, 0.39, 0.88 }
    elseif key == "restBonus" then return { 0.40, 0.80, 1.00 }
    elseif key == "quest" then return { 1.00, 0.76, 0.10 }
    elseif key == "honor" then
        local faction = UnitFactionGroup("player")
        local named = (faction == "Alliance" and PLAYER_FACTION_COLOR_ALLIANCE) or (faction == "Horde" and PLAYER_FACTION_COLOR_HORDE)
        if named then return { named:GetRGB() } end
        return { 0.00, 0.39, 0.88 }
    end
    local global = (key == "repHostile" and "FACTION_RED_COLOR") or (key == "repUnfriendly" and "FACTION_ORANGE_COLOR")
        or (key == "repNeutral" and "FACTION_YELLOW_COLOR") or "FACTION_GREEN_COLOR"
    local named = _G[global]
    if named then return { named:GetRGB() } end
    return { 1, 1, 1 }
end
function XPB.Palette()
    local db = GetDb()
    return db and db.palette == "custom" and "custom" or "flareui"
end
function XPB.Color(key)
    local db = GetDb()
    local own = XPB.Palette() == "custom" and db.customColors and db.customColors[key]
    if type(own) == "table" and own[1] then return own end
    return XPB.DefaultColor(key)
end
-- the overlays keep their tables: refilled in place
function XPB.ApplyColors()
    local bonus, quest = XPB.Color("restBonus"), XPB.Color("quest")
    COLOR_REST_BONUS[1], COLOR_REST_BONUS[2], COLOR_REST_BONUS[3] = bonus[1], bonus[2], bonus[3]
    COLOR_QUEST[1], COLOR_QUEST[2], COLOR_QUEST[3] = quest[1], quest[2], quest[3]
end

local flare                                    -- the bar frame
local LEM

-- XP Text (actionbars.xpbar.text): one dropdown, as the unit frames' Bar Text but one spot, in the
-- middle. Show Always or Show On Mouseover (one of the two), then any of Percent, Value,
-- Max and Remaining, joined by " / ". Saved as an ns.Conditions value ("hover,value,max"). Until set
-- it reads the old XP Text Visibility (textMode) and XP Text (textFormat) choices.
XPB.TEXT_SPEC = { tokens = { "always", "hover", "percent", "value", "max", "remaining" },
    rivals = { always = "hover", hover = "always" }, exclusive = {}, empty = "hover" }
XPB.TEXT_PARTS = { "percent", "value", "max", "remaining" }
XPB.OLD_TEXT_FORMAT = { VALUES = "value,max", BOTH = "percent,value,max", PERCENT = "percent", REMAINING = "remaining" }
function XPB.TextValue()
    local db = GetDb()
    if not db then return "hover,value,max" end
    if type(db.text) == "string" then return db.text end
    local mode = db.textMode == "ALWAYS" and "always" or "hover"
    return mode .. "," .. (XPB.OLD_TEXT_FORMAT[db.textFormat] or "value,max")
end
-- one of the two is always ticked: unticking it picks the other
function XPB.SetTextValue(value)
    local db = GetDb()
    if not db then return end
    local C = ns.Conditions
    if type(value) ~= "string" then value = "" end
    if not (C.Has(value, "always") or C.Has(value, "hover")) then
        local other = C.Has(XPB.TextValue(), "always") and "hover" or "always"
        value = value == "" and other or (other .. "," .. value)
    end
    db.text = value
end
function XPB.TextAlways() return ns.Conditions.Has(XPB.TextValue(), "always") end

-- The numbers the XP Text picks, joined by " / " ("" when none is ticked)
local function FormatValues(value, maxValue)
    local C, picked, parts = ns.Conditions, XPB.TextValue(), {}
    -- a paragon reward waiting takes the value past the max
    local percent = maxValue > 0 and math.min(100, math.floor(value / maxValue * 100)) or 0
    for _, part in ipairs(XPB.TEXT_PARTS) do
        if C.Has(picked, part) then
            if part == "percent" then parts[#parts + 1] = percent .. "%"
            elseif part == "value" then parts[#parts + 1] = BreakUpLargeNumbers(value)
            elseif part == "max" then parts[#parts + 1] = BreakUpLargeNumbers(maxValue)
            else parts[#parts + 1] = L["%s to go"]:format(BreakUpLargeNumbers(math.max(0, maxValue - value))) end
        end
    end
    return table.concat(parts, " / ")
end
-- a section's text: its name, then the numbers (the name alone when none is ticked)
local function Labelled(name, value, maxValue)
    local numbers = FormatValues(value, maxValue)
    if numbers == "" then return name end
    return name .. "  " .. numbers
end
-- Style: single, split or double (Off never loads the bar)
function XPB.Style()
    local db = GetDb()
    local v = db and db.style
    if v == "single" or v == "double" then return v end
    return "split"
end

-- The reward XP of the quests in the log: those ready to hand in, and (Quest XP Counts "all" or
-- "zone") those still in progress. Read again only after a quest log change, a level-up or a new zone
-- (questXPStale), not on every XP tick
local questXPStale, questXPDone, questXPOpen = true, 0, 0
-- the quests ready to hand in, { title, xp }, biggest first, for the tooltip
local questXPList = {}
local QUEST_LIST_MAX = 10
local function QuestXPTotals()
    if not questXPStale then return questXPDone, questXPOpen end
    questXPStale = false
    local db = GetDb()
    local mode = db and db.questXPMode or "done"
    local done, open = 0, 0
    wipe(questXPList)
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        local id = info and not info.isHeader and info.questID
        if id and id > 0 and (mode ~= "zone" or C_QuestLog.IsOnMap(id)) then
            local xp = GetQuestLogRewardXP(id) or 0
            if C_QuestLog.ReadyForTurnIn(id) or C_QuestLog.IsComplete(id) then
                done = done + xp
                if xp > 0 then questXPList[#questXPList + 1] = { info.title or "?", xp } end
            elseif mode ~= "done" then
                open = open + xp
            end
        end
    end
    table.sort(questXPList, function(a, b) return a[2] > b[2] end)
    questXPDone, questXPOpen = done, open
    return done, open
end

-- Each kind of section: value, max, rested bonus and quest XP (XP only), colour and text
local Read = {}

function Read.xp()
    local value, maxValue = UnitXP("player"), UnitXPMax("player")
    if not maxValue or maxValue <= 0 then value, maxValue = 0, 1 end
    local rested = GetXPExhaustion() or 0
    local color = rested > 0 and XPB.Color("rested") or XPB.Color("xp")
    local db = GetDb()
    local text = Labelled(L["XP"], value, maxValue)
    local quest, questOpen = 0, 0
    if db and db.questXP then quest, questOpen = QuestXPTotals() end
    if quest > 0 then text = text .. "  " .. L["+%s quest XP"]:format(BreakUpLargeNumbers(quest)) end
    return { kind = "xp", value = value, max = maxValue, rested = rested, quest = quest, questOpen = questOpen,
        color = color, text = text, level = UnitLevel("player") }
end

function Read.rep(data)
    local factionID = data.factionID
    local low, high, value = data.currentReactionThreshold or 0, data.nextReactionThreshold or 1, data.currentStanding or 0
    local reaction, color = data.reaction or 4, nil
    local capped = false
    if C_Reputation.IsFactionParagonForCurrentPlayer and C_Reputation.IsFactionParagonForCurrentPlayer(factionID) then
        local current, threshold, _, rewardPending = C_Reputation.GetFactionParagonInfo(factionID)
        low, high, value = 0, threshold or 1, (current or 0) % (threshold or 1)
        if rewardPending then value = value + (threshold or 0) end
    elseif C_Reputation.IsMajorFaction and C_Reputation.IsMajorFaction(factionID) then
        local major = C_MajorFactions.GetMajorFactionData(factionID)
        low, high, value = 0, major and major.renownLevelThreshold or 1, major and major.renownReputationEarned or 0
        color = XPB.Color("renown")
    else
        local friend = C_GossipInfo.GetFriendshipReputation(factionID)
        if friend and friend.friendshipFactionID and friend.friendshipFactionID > 0 then
            reaction = 5
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
    if not color then color = XPB.Color(STANDING_BY_REACTION[reaction] or "repNeutral") end
    -- the standing's name, as Blizzard's reputation panel shows it
    local standing
    local friend = C_GossipInfo.GetFriendshipReputation(factionID)
    if friend and friend.friendshipFactionID and friend.friendshipFactionID > 0 then
        standing = friend.reaction
    else
        standing = GetText and GetText("FACTION_STANDING_LABEL" .. reaction, UnitSex("player")) or nil
    end
    return {
        kind = "rep", name = data.name, standing = standing, capped = capped,
        value = value, max = maxValue, rested = 0, color = color,
        text = capped and data.name or Labelled(data.name, value, maxValue),
    }
end

function Read.honor()
    local value, maxValue = UnitHonor("player") or 0, UnitHonorMax("player") or 1
    if maxValue <= 0 then maxValue = 1 end
    local color = XPB.Color("honor")
    return {
        kind = "honor", level = UnitHonorLevel and UnitHonorLevel("player") or nil,
        value = value, max = maxValue, rested = 0, color = color,
        text = Labelled(HONOR, value, maxValue),
    }
end

-- Blizzard's bar manager tests (CanShowBar)
local function WatchedReputation()
    local data = C_Reputation.GetWatchedFactionData()
    if data and data.name and data.name ~= "" and data.factionID and data.factionID ~= 0 then return data end
end

local function TracksHonor()
    return (IsWatchingHonorAsXP and IsWatchingHonorAsXP()) or (C_PvP.IsActiveBattlefield and C_PvP.IsActiveBattlefield())
        or (IsInActiveWorldPVP and IsInActiveWorldPVP()) or false
end

-- The two sections' contents (nil = nothing to show)
local function PickSections()
    local rep, honor = WatchedReputation(), TracksHonor()
    if GameRulesUtil.CanShowExperienceBar() then
        return Read.xp(), (rep and Read.rep(rep)) or (honor and Read.honor()) or nil
    end
    local left = (rep and Read.rep(rep)) or (honor and Read.honor()) or nil
    local right = (rep and honor) and Read.honor() or nil
    return left, right
end

-- XP per hour this session: the XP gained between readings (a level-up adds what the old level still
-- needed), over the time since the first reading. Shown after a minute.
local xpRate = {}
local function TrackXP()
    local value, maxValue, level = UnitXP("player"), UnitXPMax("player"), UnitLevel("player")
    if not (value and maxValue and level) then return false end
    local gained = false
    if not xpRate.start then
        xpRate.start, xpRate.total = GetTime(), 0
    elseif level > (xpRate.level or level) then
        xpRate.total = xpRate.total + math.max(0, (xpRate.max or 0) - (xpRate.value or 0)) + value
        gained = true
    elseif level == xpRate.level and value > (xpRate.value or value) then
        xpRate.total = xpRate.total + value - xpRate.value
        gained = true
    end
    xpRate.value, xpRate.max, xpRate.level = value, maxValue, level
    return gained
end

local function XPPerHour()
    local elapsed = xpRate.start and GetTime() - xpRate.start or 0
    if elapsed < 60 or not xpRate.total or xpRate.total <= 0 then return nil end
    return xpRate.total * 3600 / elapsed
end

-- The bar's tooltip, unless Tooltips > On action/data bars hides it (Hold Shift shows it)
local function ShowSectionTooltip(section)
    local info = section.info
    if not info then return end
    if ns.Tooltips and ns.Tooltips.BarTooltipHidden and ns.Tooltips.BarTooltipHidden() then
        GameTooltip:Hide()
        return
    end
    ns.OwnGameTooltip(section, "ANCHOR_TOP")
    local function Pct(v, m) return m > 0 and math.floor(v / m * 100 + 0.5) or 0 end
    if info.kind == "xp" then
        GameTooltip:AddLine(LEVEL and (LEVEL .. " " .. (info.level or "")) or L["XP"], 1, 0.82, 0)
        GameTooltip:AddDoubleLine(L["XP"], ("%s / %s (%d%%)"):format(BreakUpLargeNumbers(info.value), BreakUpLargeNumbers(info.max), Pct(info.value, info.max)), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine(L["To next level"], BreakUpLargeNumbers(math.max(0, info.max - info.value)), 1, 1, 1, 1, 1, 1)
        if info.rested and info.rested > 0 then
            GameTooltip:AddDoubleLine(L["Rested"], ("%s (%d%%)"):format(BreakUpLargeNumbers(info.rested), Pct(info.rested, info.max)), 1, 1, 1, COLOR_REST_BONUS[1], COLOR_REST_BONUS[2], COLOR_REST_BONUS[3])
        end
        if (info.quest or 0) > 0 then
            GameTooltip:AddDoubleLine(L["Quests ready to hand in"], BreakUpLargeNumbers(info.quest), 1, 1, 1, COLOR_QUEST[1], COLOR_QUEST[2], COLOR_QUEST[3])
            -- each one, so the total can be trusted (a talk quest counts as ready too)
            for i = 1, math.min(#questXPList, QUEST_LIST_MAX) do
                local entry = questXPList[i]
                GameTooltip:AddDoubleLine("   " .. entry[1], BreakUpLargeNumbers(entry[2]), 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
            end
            if #questXPList > QUEST_LIST_MAX then
                GameTooltip:AddLine("   " .. L["and %d more"]:format(#questXPList - QUEST_LIST_MAX), 0.6, 0.6, 0.6)
            end
        end
        if (info.questOpen or 0) > 0 then
            GameTooltip:AddDoubleLine(L["Quests in progress"], BreakUpLargeNumbers(info.questOpen), 1, 1, 1, COLOR_QUEST[1], COLOR_QUEST[2], COLOR_QUEST[3])
        end
        local rate = XPPerHour()
        if rate then
            GameTooltip:AddDoubleLine(L["XP per hour"], BreakUpLargeNumbers(math.floor(rate)), 1, 1, 1, 1, 1, 1)
            local left = math.max(0, info.max - info.value)
            if left > 0 and SecondsToTime then
                GameTooltip:AddDoubleLine(L["Time to level"], SecondsToTime(math.floor(left / rate * 3600)), 1, 1, 1, 1, 1, 1)
            end
        end
    elseif info.kind == "rep" then
        GameTooltip:AddLine(info.name or REPUTATION, 1, 0.82, 0)
        if info.standing then GameTooltip:AddLine(info.standing, info.color[1], info.color[2], info.color[3]) end
        if not info.capped then
            GameTooltip:AddDoubleLine(REPUTATION, ("%s / %s (%d%%)"):format(BreakUpLargeNumbers(info.value), BreakUpLargeNumbers(info.max), Pct(info.value, info.max)), 1, 1, 1, 1, 1, 1)
        end
    elseif info.kind == "honor" then
        GameTooltip:AddLine(HONOR, 1, 0.82, 0)
        if info.level and HONOR_LEVEL_LABEL then GameTooltip:AddLine(HONOR_LEVEL_LABEL:format(info.level), 1, 1, 1) end
        GameTooltip:AddDoubleLine(HONOR, ("%s / %s (%d%%)"):format(BreakUpLargeNumbers(info.value), BreakUpLargeNumbers(info.max), Pct(info.value, info.max)), 1, 1, 1, 1, 1, 1)
    else
        GameTooltip:Hide()
        return
    end
    GameTooltip:Show()
end

-- Edit Mode samples, so the frame can be placed whatever is tracked
local function SampleSections()
    return { value = 6, max = 10, rested = 2, quest = GetDb().questXP and 1 or 0, color = XPB.Color("rested"), text = L["XP"] },
           { value = 4, max = 10, rested = 0, color = XPB.Color("repFriendly"), text = REPUTATION }
end

local function CreateSection(parent)
    local section = CreateFrame("StatusBar", nil, parent)
    section:SetMinMaxValues(0, 1)
    section:SetValue(0)
    section:EnableMouse(true)

    local track = section:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    section.Track = track

    -- rested XP: from the left edge to where the bonus would take the fill, after the quest XP
    -- (under it: each layer starts at the left edge, the later ones lower down)
    local rested = section:CreateTexture(nil, "BORDER", nil, -1)
    rested:SetPoint("TOPLEFT")
    rested:SetPoint("BOTTOMLEFT")
    rested:Hide()
    section.Rested = rested

    -- quest XP: from the left edge to where handing in the finished quests would take the fill
    local quest = section:CreateTexture(nil, "BORDER", nil, 1)
    quest:SetPoint("TOPLEFT")
    quest:SetPoint("BOTTOMLEFT")
    quest:Hide()
    section.Quest = quest

    -- quests still in progress (Quest XP Counts): paler, past the finished ones
    local questOpen = section:CreateTexture(nil, "BORDER", nil, 0)
    questOpen:SetPoint("TOPLEFT")
    questOpen:SetPoint("BOTTOMLEFT")
    questOpen:Hide()
    section.QuestOpen = questOpen

    local textHolder = CreateFrame("Frame", nil, section)
    textHolder:SetAllPoints()
    textHolder:SetFrameLevel(section:GetFrameLevel() + 2)
    local text = textHolder:CreateFontString(nil, "OVERLAY")
    text:SetPoint("LEFT", 4, 0)
    text:SetPoint("RIGHT", -4, 0)
    text:SetWordWrap(false)
    section.Text = text

    -- the numbers on mouseover. The tooltip only with Show Tooltip (11-20, Malkkav: off by default, it
    -- covered the bar's own text)
    section:SetScript("OnEnter", function(self)
        if not XPB.TextAlways() then self.Text:Show() end
        local db = ns.db and ns.db.profile.actionbars.xpbar
        if db and db.tooltip then ShowSectionTooltip(self) end
    end)
    section:SetScript("OnLeave", function(self)
        if not XPB.TextAlways() then self.Text:Hide() end
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)

    -- a short light over the fill on an XP gain
    local flash = section:CreateTexture(nil, "OVERLAY")
    flash:SetAllPoints(section:GetStatusBarTexture() or section)
    flash:SetColorTexture(1, 1, 1, 1)
    flash:SetBlendMode("ADD")
    flash:SetAlpha(0)
    local anim = flash:CreateAnimationGroup()
    local up = anim:CreateAnimation("Alpha")
    up:SetFromAlpha(0); up:SetToAlpha(0.35); up:SetDuration(0.15); up:SetOrder(1)
    local down = anim:CreateAnimation("Alpha")
    down:SetFromAlpha(0.35); down:SetToAlpha(0); down:SetDuration(0.5); down:SetOrder(2)
    flash.anim = anim
    section.Flash = flash

    -- the bubble dividers (the Separators option): over the fill and the gain flash, under the text
    section.Bubbles = {}
    for i = 1, BUBBLES - 1 do
        local dark = section:CreateTexture(nil, "OVERLAY", nil, 1)
        dark:SetColorTexture(0, 0, 0, BUBBLE_DARK)
        dark:Hide()
        local light = section:CreateTexture(nil, "OVERLAY", nil, 1)
        light:SetColorTexture(1, 1, 1, BUBBLE_LIGHT)
        light:Hide()
        section.Bubbles[i] = { dark, light }
    end
    return section
end

-- How many bubbles a saved value asks for: 10 or 20, else none. A saved true (from the older switch)
-- means 20
local function BubbleCount(value)
    if value == true then return BUBBLES end
    local n = tonumber(value)
    if n == 10 or n == 20 then return n end
    return 0
end

-- The dividers on whole screen pixels, one pixel each side of every bubble's edge; laid out again only
-- when the width, the UI scale or the count changes
local function LayoutBubbles(section, width)
    local db = GetDb()
    local count = BubbleCount(db and db.bubbles)
    -- a settings preview's sample shows the value the Bubbles row previews
    local spec = section:GetParent().fuiSample and ns.SettingsPreview and ns.SettingsPreview.activeSpec
    if spec and spec.key == "ab.xpBubbles" and spec.value ~= nil then count = BubbleCount(spec.value) end
    local px = ns.PixelSize(section)
    local key = count > 0 and (count .. ":" .. width .. ":" .. px) or "off"
    if section.ftBubbles == key then return end
    section.ftBubbles = key
    local total = math.floor(width / px + 0.5)
    for i, pair in ipairs(section.Bubbles) do
        local dark, light = pair[1], pair[2]
        local on = i < count
        if on then
            local x = math.floor(total * i / count + 0.5) * px
            dark:ClearAllPoints()
            dark:SetPoint("TOPLEFT", section, "TOPLEFT", x - px, 0)
            dark:SetPoint("BOTTOMLEFT", section, "BOTTOMLEFT", x - px, 0)
            dark:SetWidth(px)
            light:ClearAllPoints()
            light:SetPoint("TOPLEFT", section, "TOPLEFT", x, 0)
            light:SetPoint("BOTTOMLEFT", section, "BOTTOMLEFT", x, 0)
            light:SetWidth(px)
        end
        dark:SetShown(on)
        light:SetShown(on)
    end
end

local function FillSection(section, info, width)
    if not info then section:Hide() return end
    local fraction = info.max > 0 and info.value / info.max or 0
    local smooth = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
    -- it glides forward only: a level-up or a new faction lands at once instead of sliding back
    -- across the whole bar
    local forward = section.ftFraction == nil or fraction >= section.ftFraction
    section.ftFraction = fraction
    if smooth and forward and section:IsShown() then section:SetValue(fraction, smooth) else section:SetValue(fraction) end
    local r, g, b = info.color[1], info.color[2], info.color[3]
    section:SetStatusBarColor(r, g, b, 1)
    -- rested reaches past the quest XP, or the quest layers would hide it
    if info.rested and info.rested > 0 then
        local reach = math.min(1, (info.value + (info.quest or 0) + (info.questOpen or 0) + info.rested) / info.max)
        section.Rested:SetWidth(math.max(1, reach * width))
        section.Rested:SetVertexColor(COLOR_REST_BONUS[1], COLOR_REST_BONUS[2], COLOR_REST_BONUS[3], REST_ALPHA + 0.15)
        section.Rested:Show()
    else
        section.Rested:Hide()
    end
    if info.quest and info.quest > 0 then
        local reach = math.min(1, (info.value + info.quest) / info.max)
        section.Quest:SetWidth(math.max(1, reach * width))
        section.Quest:SetVertexColor(COLOR_QUEST[1], COLOR_QUEST[2], COLOR_QUEST[3], REST_ALPHA + 0.15)
        section.Quest:Show()
    else
        section.Quest:Hide()
    end
    if info.questOpen and info.questOpen > 0 then
        local reach = math.min(1, (info.value + (info.quest or 0) + info.questOpen) / info.max)
        section.QuestOpen:SetWidth(math.max(1, reach * width))
        section.QuestOpen:SetVertexColor(COLOR_QUEST[1], COLOR_QUEST[2], COLOR_QUEST[3], REST_ALPHA - 0.15)
        section.QuestOpen:Show()
    else
        section.QuestOpen:Hide()
    end
    section.info = info
    if section:IsMouseOver() and GameTooltip:IsOwned(section) then ShowSectionTooltip(section) end
    section.Text:SetText(info.text or "")
    section:Show()
end

-- target: a settings preview's sample (always the Edit Mode sample), else the bar
local function UpdateFlare(target)
    local flare = type(target) == "table" and target or flare
    if not flare then return end
    local db = GetDb()
    local left, right
    local gained = false
    if flare.fuiSample or (LEM and LEM:IsInEditMode()) then
        left, right = SampleSections()
    else
        if GameRulesUtil.CanShowExperienceBar() then gained = TrackXP() end
        left, right = PickSections()
    end
    if not left then flare:Hide() return end

    local style = XPB.Style()
    if style == "single" then right = nil end
    local width, height = flare.sampleWidth or db.width or 560, flare.sampleHeight or db.height or 14
    local double = style == "double" and right ~= nil
    local leftWidth = (right and not double) and width / 2 or width
    -- Double grows the frame down for the second bar (and back when it goes)
    local frameHeight = double and (2 * height + DOUBLE_GAP) or height
    flare:SetSize(width + 2 * FLARE_INSET, frameHeight + 2 * FLARE_INSET)
    flare.Left:ClearAllPoints()
    flare.Left:SetPoint("TOPLEFT", flare, "TOPLEFT", FLARE_INSET, -FLARE_INSET)
    flare.Left:SetSize(leftWidth, height)
    flare.Right:ClearAllPoints()
    if double then
        flare.Right:SetPoint("TOPLEFT", flare.Left, "BOTTOMLEFT", 0, -DOUBLE_GAP)
    else
        flare.Right:SetPoint("TOPRIGHT", flare, "TOPRIGHT", -FLARE_INSET, -FLARE_INSET)
    end
    flare.Right:SetSize(leftWidth, height)
    FillSection(flare.Left, left, leftWidth)
    FillSection(flare.Right, right, leftWidth)
    LayoutBubbles(flare.Left, leftWidth)
    LayoutBubbles(flare.Right, leftWidth)
    -- XP is the left section whenever it shows
    if gained and left.kind == "xp" and flare.Left.Flash then
        flare.Left.Flash.anim:Stop()
        flare.Left.Flash.anim:Play()
    end
    local pipHeight = height + 2 * PIP_OVERHANG
    flare.Pip:SetSize(math.max(4, math.floor(pipHeight * PIP_RATIO + 0.5)), pipHeight)
    flare.Pip:SetShown(right ~= nil and not double)   -- (the pip sits between two halves: Split only)
    flare:Show()
end

local function LayoutFlare(target)
    local flare = type(target) == "table" and target or flare
    if not flare then return end
    local db = GetDb()
    local texture = GetTexture()
    flare:SetSize((flare.sampleWidth or db.width or 560) + 2 * FLARE_INSET, (flare.sampleHeight or db.height or 14) + 2 * FLARE_INSET)
    -- Border: its own choice, None first; an unknown name falls back to FlareUI Thin
    local name = db.border or BORDER_NAME
    if name ~= "None" and not LSM:IsValid("border", name) then name = BORDER_NAME end
    if name == "None" then
        flare.Border:SetBackdrop(nil)
    else
        local file = LSM:Fetch("border", name)
        -- the edge only: it draws over the fill (whose square corners would show past its rounded
        -- ones); the dark background is its own texture under the sections (BuildParts)
        flare.Border:SetBackdrop({ edgeFile = file, edgeSize = ns.BorderEdgeSize(file, BORDER_SIZE) })
        flare.Border:SetBackdropBorderColor(BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3], 1)
    end
    for _, section in ipairs({ flare.Left, flare.Right }) do
        section:SetStatusBarTexture(texture)
        -- the gain flash covers the fill only (the fill region exists once the texture is set)
        if section.Flash and section:GetStatusBarTexture() then section.Flash:ClearAllPoints(); section.Flash:SetAllPoints(section:GetStatusBarTexture()) end
        section.Track:SetTexture(texture)
        section.Track:SetVertexColor(TRACK_COLOR[1], TRACK_COLOR[2], TRACK_COLOR[3], TRACK_COLOR[4])
        section.Rested:SetTexture(texture)
        section.Quest:SetTexture(texture)
        section.QuestOpen:SetTexture(texture)
        ApplyFont(section.Text)
        section.Text:SetShown(XPB.TextAlways())
    end
    -- the quest log only matters with Show Quest XP on (it changes often)
    if not flare.fuiSample then
        if db.questXP then pcall(flare.RegisterEvent, flare, "QUEST_LOG_UPDATE") else flare:UnregisterEvent("QUEST_LOG_UPDATE") end
    end
    UpdateFlare(flare)
end

-- Position, per Edit Mode layout
local function FlareStore(layoutName)
    local db = GetDb()
    layoutName = layoutName or LEM:GetActiveLayoutName() or "Modern"
    db.layouts = db.layouts or {}
    -- (a layout with no spot of its own reads the profile's home layout's: ProfileLayout.lua)
    return ns.LayoutHome(db.layouts, layoutName)
end

local function PlaceFlare(layoutName)
    if not flare then return end
    local store = FlareStore(layoutName)
    local pos = store.point and store or FLARE_DEFAULT
    flare:ClearAllPoints()
    flare:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
end

local function OnFlareMoved(_, layoutName, point, x, y)
    local store = FlareStore(layoutName)
    store.point, store.x, store.y = point, math.floor(x + 0.5), math.floor(y + 0.5)
end

-- A state driver plus a Show hook (Edit Mode) keep Blizzard's bars hidden
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
    "CVAR_UPDATE",   -- Blizzard's "show honor as XP" switch is a CVar; every other one is skipped below
}

-- the events after which the quest XP total is read again
local QUEST_XP_EVENTS = { QUEST_LOG_UPDATE = true, PLAYER_LEVEL_UP = true, PLAYER_ENTERING_WORLD = true, UNIT_LEVEL = true,
    ZONE_CHANGED_NEW_AREA = true }

-- the bar's border, two sections and the pip between them (the bar's and the previews' samples)
local function BuildParts(f)
    f.Border = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.Border:SetAllPoints()
    f.Left = CreateSection(f)
    f.Right = CreateSection(f)
    f.Left:SetFrameLevel(f:GetFrameLevel() + 2)
    f.Right:SetFrameLevel(f:GetFrameLevel() + 2)
    -- the edge over the sections (their texts sit at +4, the pip at +5), the dark background under them
    f.Border:SetFrameLevel(f:GetFrameLevel() + 3)
    f.Bg = f:CreateTexture(nil, "BACKGROUND")
    f.Bg:SetPoint("TOPLEFT", FLARE_INSET, -FLARE_INSET)
    f.Bg:SetPoint("BOTTOMRIGHT", -FLARE_INSET, FLARE_INSET)
    f.Bg:SetColorTexture(0, 0, 0, 0.8)
    local pipHolder = CreateFrame("Frame", nil, f)
    pipHolder:SetAllPoints()
    pipHolder:SetFrameLevel(f:GetFrameLevel() + 5)
    f.Pip = pipHolder:CreateTexture(nil, "OVERLAY")
    f.Pip:SetAtlas(PIP_ATLAS)
    f.Pip:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.Pip:Hide()
end

-- a settings preview's sample: the bar's own parts and layout, with the Edit Mode values (no events,
-- no mouse)
function XPB.CreateSample(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.fuiSample = true
    -- shorter and thicker than the bar, so it reads in the preview
    f.sampleWidth, f.sampleHeight = 240, 20
    BuildParts(f)
    f.Left:EnableMouse(false)
    f.Right:EnableMouse(false)
    return f
end
function XPB.DrawSample(f)
    LayoutFlare(f)
    return f:GetWidth(), f:GetHeight()
end

local function BuildFlare()
    LEM = LibStub("FlareEditMode")
    flare = CreateFrame("Frame", FLARE_NAME, UIParent)
    flare:SetFrameStrata("LOW")
    flare:SetClampedToScreen(true)
    BuildParts(flare)

    -- events come in bursts; one update per frame
    local queued = false
    local function Flush() queued = false; UpdateFlare() end
    flare:SetScript("OnEvent", function(_, event, cvar)
        if event == "CVAR_UPDATE" and cvar ~= "showHonorAsExperience" then return end
        if QUEST_XP_EVENTS[event] then questXPStale = true end
        if queued then return end
        queued = true
        C_Timer.After(0, Flush)
    end)
    for _, event in ipairs(FLARE_EVENTS) do pcall(flare.RegisterEvent, flare, event) end
    -- the new level can land after PLAYER_LEVEL_UP's update (Blizzard re-checks on UNIT_LEVEL too)
    pcall(flare.RegisterUnitEvent, flare, "UNIT_LEVEL", "player")

    KeepBlizzardBarsHidden()
    -- Blizzard's hidden bars' manager keeps handling its events (fades, layout, the bottom action bar
    -- positions on every XP tick) for bars nobody sees: silenced for the session, as the FlareUI bar
    -- replaces them while Action Bars is on
    local manager = _G.StatusTrackingBarManager
    if manager and manager.UnregisterAllEvents then manager:UnregisterAllEvents() end

    -- faded out (Visibility), the bar lets the mouse through; its own hover text comes back with it
    hooksecurefunc(flare, "SetAlpha", function(f, alpha)
        local on = (alpha or 1) > 0.05
        if f.ftMouse ~= on then
            f.ftMouse = on
            f.Left:EnableMouse(on)
            f.Right:EnableMouse(on)
        end
    end)

    LEM:AddFrame(flare, OnFlareMoved, FLARE_DEFAULT, FLARE_LABEL)
    -- one Frame section (dropdowns, sliders, switches); Fading comes after it (Visibility.lua)
    LEM:AddFrameSettings(flare, ns.EditSection("Frame", {
        { name = L["Width"], kind = LEM.SettingType.Slider, default = 560, minValue = 200, maxValue = 1200, valueStep = 1,
          get = function() return GetDb().width or 560 end, set = function(_, value) GetDb().width = value; LayoutFlare() end },
        { name = L["Height"], kind = LEM.SettingType.Slider, default = 14, minValue = 6, maxValue = 30, valueStep = 1,
          get = function() return GetDb().height or 14 end, set = function(_, value) GetDb().height = value; LayoutFlare() end },
        -- (Bar Texture and Border: Settings > Action Bars > XP Bar, 11-20, as every other frame's look)
    }))
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
    -- with the module, unless its FlareUI XP Bar switch is off (Blizzard's bars are then untouched)
    return (ab and ab.enabled and not (ab.xpbar and ab.xpbar.enabled == false)) or false
end

-- Bar Texture and Border for Settings > Action Bars > XP Bar: { value, label } lists and the defaults
function XPB.LookChoices(which)
    local values = which == "border" and ns.UnitFrames.Kit.BuildBorderValues(false) or TextureValues()
    if type(values) == "function" then values = values() end
    local list = {}
    for _, v in ipairs(values) do
        if v.isDivider then list[#list + 1] = { divider = true } else list[#list + 1] = { v.value, v.text } end
    end
    return list
end
XPB.DEFAULT_TEXTURE, XPB.DEFAULT_BORDER = TEXTURE_NAME, BORDER_NAME

-- The FlareUI XP Bar, for the Visibility module's fader
function XPB:GetFrame()
    return flare
end

function XPB:Refresh()
    questXPStale = true   -- Quest XP Counts may have changed
    XPB.ApplyColors()
    if flare then
        PlaceFlare()
        LayoutFlare()
    end
end

function XPB:Init()
    if self.initialized or not GetDb() then return end
    self.initialized = true
    XPB.ApplyColors()
    BuildFlare()
    C_Timer.After(0, function()
        if ns.Visibility and ns.Visibility.Refresh then ns.Visibility:Refresh() end
    end)
end
