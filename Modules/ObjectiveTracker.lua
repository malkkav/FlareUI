local _, ns = ...
local L = ns.L

--------------------------------------------------
-- 1. MODULE REGISTRATION
-- The Quest Tracker, in place of Blizzard's: the tracked quests (current zone first, nearest
-- first) and tracked recipes, in a FlareUI window placed in Edit Mode.
--   * It grows away from the screen edge it sits on; quest item buttons sit outside the edge facing
--     the middle of the screen.
--   * Minimizes to its header or a lone "+" (also by keybind); each kind of place can minimize or
--     expand it once on the way in.
--   * Blizzard's tracker is parked while this one is on.
-- Adapted in part from BetterQuestTracker by deface (MIT License, LICENSES/BetterQuestTracker.txt):
-- the zone and distance ordering, the secure item buttons and the party progress tooltip.
-- Stands aside in the Gamepad UI.
--------------------------------------------------
ns.ObjectiveTracker = ns.ObjectiveTracker or {}
local OT = ns.ObjectiveTracker
ns.modules["ObjectiveTracker"] = OT

--------------------------------------------------
-- 2. UPVALUES / CONSTANTS
--------------------------------------------------
local LEM = LibStub("FlareEditMode")
local LSM = LibStub("LibSharedMedia-3.0")
local ipairs, pairs, wipe = ipairs, pairs, wipe
local math_max, math_min, math_floor, math_huge = math.max, math.min, math.floor, math.huge
local string_format = string.format
local C_QuestLog, C_SuperTrack = C_QuestLog, C_SuperTrack
local InCombatLockdown = InCombatLockdown

local C = {
    DEFAULT_POSITION = { point = "TOPRIGHT", x = -60, y = -300 },
    DEFAULT_BORDER = "FlareUI Frames",
    WIDTH = 260, MAX_HEIGHT = 500,
    HEADER = 30,            -- header band
    HEADER_INSET = 8,       -- header contents from the frame edges
    PAD = 14,               -- text inset from the frame edges
    INDENT = 10,            -- objectives under their quest
    LIST_TOP = 10,          -- from the header line to the first line of the list
    LIST_BOTTOM = 10,       -- from the last line to the frame's bottom edge
    LINE_GAP = 2, QUEST_GAP = 9, GROUP_GAP = 10,
    ZONE_GAP = 5,           -- under a zone heading, before its first quest
    SCROLL_STEP = 40,
    SCROLLBAR_INSET = 6,    -- the scroll bar's right edge, in from the frame's
    SCROLLBAR_MIN = 16,     -- the shortest the thumb gets
    ITEM_SIZE = 22, ITEM_GAP = 3,
    BOX = 12,               -- the header's minimize / expand button
    LONE = 18,              -- the lone expand button of Minimize Style "Button Only"
    BOX_COLOR = { 0.50, 0.38, 0.21 },        -- a darker bronze than the frame border
    BOX_COLOR_LIT = { 0.65, 0.49, 0.27 },    -- the frame border's bronze while pointed at
    SORT_TICK = 2,          -- seconds between distance checks
    -- colours: zone headers in FlareUI's tab bronze, titles in Blizzard's tracker gold and blue
    ZONE = { 0.80, 0.60, 0.34 },
    TITLE = { 1, 0.82, 0 },
    TITLE_DONE = { 0.13, 1, 0.13 },
    TITLE_FOCUS = { 0.40, 0.80, 1 },
    OBJECTIVE = { 0.85, 0.85, 0.85 },
    OBJECTIVE_DONE = { 0.55, 0.55, 0.55 },
    DIM = { 0.55, 0.55, 0.55 },
    CONTEXTS = { "world", "resting", "dungeon", "raid", "pvp", "arena", "combat" },
}
OT.CONTEXTS = C.CONTEXTS

-- Blizzard's strings where it has them
local TEXT = {
    quests = _G.QUESTS_LABEL or "Quests",
    ready = _G.QUEST_WATCH_QUEST_READY or "Ready to turn in",
    focus = _G.SUPER_TRACK_QUEST or "Focus",
    unfocus = _G.STOP_SUPER_TRACK_QUEST or "Stop Focusing",
    openLog = _G.OBJECTIVES_VIEW_IN_QUESTLOG or "Open Quest Log",
    untrack = _G.OBJECTIVES_STOP_TRACKING or "Untrack Quest",
    share = _G.SHARE_QUEST or "Share Quest",
    abandon = _G.ABANDON_QUEST_ABBREV or "Abandon Quest",
    recipes = _G.PROFESSIONS_TRACKER_HEADER_PROFESSION or "Professions",
    openRecipe = _G.PROFESSIONS_TRACKING_VIEW_RECIPE or "Open Recipe",
}

-- Key Bindings > AddOns > FlareUI
BINDING_NAME_FLAREUI_TRACKER = L["Minimize / Expand Quest Tracker"]

local holder, header, scroll, content, divider, miniButton
local lines, itemButtons, titleLines = {}, {}, {}
local state = {
    rendered = false, pending = false, editMode = false,
    context = nil, order = {}, itemsDirty = false, rangeTicker = nil, itemsShown = 0,
    recipes = 0, empty = false, groups = {},
}

local function GetDb()
    return ns.db and ns.db.profile and ns.db.profile.objectivetracker
end

-- The character's own state: minimized, collapsed quests and zones, quests this module untracked
local function Char()
    local c = ns.CharDB()
    c.objectiveTracker = c.objectiveTracker or {}
    local t = c.objectiveTracker
    t.collapsedQuests = t.collapsedQuests or {}
    t.collapsedZones = t.collapsedZones or {}
    t.autoUntracked = t.autoUntracked or {}
    return t
end

local function SetColor(fontString, c) fontString:SetTextColor(c[1], c[2], c[3]) end

local function Byte(v) return math_floor(v * 255 + 0.5) end

local function ColorCode(c)
    return string_format("|cff%02x%02x%02x", Byte(c[1]), Byte(c[2]), Byte(c[3]))
end

--------------------------------------------------
-- 3. SIDE AND POSITION
-- Anchored by the corner nearest the screen edges, so it grows away from them. After each Edit Mode
-- move the corner is worked out again and stored, per layout.
--------------------------------------------------
local function GetLayoutStore(layoutName)
    local db = GetDb()
    if not db then return nil end
    layoutName = layoutName or LEM:GetActiveLayoutName() or "Modern"
    db.layouts = db.layouts or {}
    db.layouts[layoutName] = db.layouts[layoutName] or {}
    return db.layouts[layoutName]
end

-- right: the frame's centre is on the right half of the screen; top: the top half
function OT:Side()
    if not holder then return true, true end
    local x, y = holder:GetCenter()
    local w, h = UIParent:GetSize()
    if not x then return true, true end
    return x > w / 2, y > h / 2
end

local function CornerOf(right, top)
    return (top and "TOP" or "BOTTOM") .. (right and "RIGHT" or "LEFT")
end

local function AnchorToCorner()
    local left, bottom, width, height = holder:GetRect()
    if not left then return nil end
    local right, top = OT:Side()
    local corner = CornerOf(right, top)
    local x = right and (left + width - UIParent:GetWidth()) or left
    local y = top and (bottom + height - UIParent:GetHeight()) or bottom
    holder:ClearAllPoints()
    holder:SetPoint(corner, UIParent, corner, x, y)
    return corner, x, y
end

local function ApplyPosition(layoutName)
    if not holder then return end
    local store = GetLayoutStore(layoutName)
    holder:ClearAllPoints()
    if store and store.corner then
        holder:SetPoint(store.corner, UIParent, store.corner, store.x or 0, store.y or 0)
    else
        local p = C.DEFAULT_POSITION
        holder:SetPoint(p.point, UIParent, p.point, p.x, p.y)
    end
end

local function OnFrameMoved(_, layoutName)
    local corner, x, y = AnchorToCorner()
    local store = GetLayoutStore(layoutName)
    if not (store and corner) then return end
    store.corner, store.x, store.y = corner, math_floor(x + 0.5), math_floor(y + 0.5)
    OT:RequestRender()
end

--------------------------------------------------
-- 4. FONTS AND LOOK
--------------------------------------------------
local function ApplyFont(fontString, cfg, fallbackSize)
    cfg = cfg or {}
    local flags = cfg.flags
    if flags == "NONE" then flags = "" end
    fontString:SetFont(ns.GetFontPath(cfg.face or "Friz Quadrata TT"), cfg.size or fallbackSize or 12, flags or "")
    ns.ApplyShadow(fontString, cfg)
end

local function FontHeight(cfg, fallback)
    return (cfg and cfg.size or fallback or 12) + 2
end

local function GetBorderFile(db)
    local name = db and db.borderTexture
    if not (name and LSM:IsValid("border", name)) then name = C.DEFAULT_BORDER end
    return LSM:Fetch("border", name)
end

local function ApplyBackdrop()
    local db = GetDb()
    local bg = LSM:Fetch("background", "Blizzard Dialog Background Dark") or "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"
    local edge = GetBorderFile(db)
    holder:SetBackdrop({ bgFile = bg, edgeFile = edge, tile = false, tileSize = 0,
        edgeSize = ns.BorderEdgeSize(edge, 16), insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    holder:SetBackdropColor(1, 1, 1, db and db.opacity or 0.6)
    local b = ns.BORDER_COLOR
    holder:SetBackdropBorderColor(b.r, b.g, b.b, b.a)
end

--------------------------------------------------
-- 5. QUESTS
-- Tracked quests under the log's zone headers: the current zone's groups first, the rest by their
-- nearest quest, quests by distance; completed quests sink to the bottom of their group.
--------------------------------------------------
local zoneNames, questBuf, groupRank, groupBest = {}, {}, {}, {}

local function CurrentZoneNames()
    wipe(zoneNames)
    for _, z in ipairs({ GetRealZoneText(), GetZoneText(), GetSubZoneText() }) do
        if z and z ~= "" then zoneNames[z] = true end
    end
end

local function Distance(questID)
    local distSq, onContinent = C_QuestLog.GetDistanceSqToQuest(questID)
    return (distSq and onContinent) and distSq or math_huge
end

local function QuestCount()
    local n = 0
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and not info.isHidden and not info.isTask and not info.isBounty then n = n + 1 end
    end
    local max = C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept() or nil
    return n, max
end

local function ByOrder(a, b)
    if a.ftRank ~= b.ftRank then return a.ftRank < b.ftRank end
    if a.ftDone ~= b.ftDone then return not a.ftDone end
    if a.ftDistance ~= b.ftDistance then return a.ftDistance < b.ftDistance end
    return a.ftIndex < b.ftIndex
end

local function CollectQuests(db)
    CurrentZoneNames()
    wipe(questBuf)
    local header
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info then
            if info.isHeader then
                header = info.title
            elseif not info.isHidden and info.questID and info.questID > 0
                    and C_QuestLog.GetQuestWatchType(info.questID) ~= nil then
                local here = (header and zoneNames[header]) or C_QuestLog.IsOnMap(info.questID)
                if here or not db.zoneOnly then
                    info.ftLogIndex = i
                    info.ftIndex = #questBuf + 1
                    info.ftHeader = header or _G.OTHER or "Other"
                    info.ftHere = here and true or false
                    info.ftDone = db.completedLast and C_QuestLog.IsComplete(info.questID) or false
                    info.ftDistance = db.sortByDistance and Distance(info.questID) or 0
                    questBuf[#questBuf + 1] = info
                end
            end
        end
    end

    -- a group's place: current zone, then its nearest quest, then log order
    wipe(groupRank)
    wipe(groupBest)
    for _, q in ipairs(questBuf) do
        local best = groupBest[q.ftHeader]
        if not best or q.ftDistance < best.distance then
            groupBest[q.ftHeader] = { distance = q.ftDistance, index = best and best.index or q.ftIndex, here = (best and best.here) or q.ftHere }
        elseif q.ftHere then
            best.here = true
        end
    end
    local order = {}
    for name, g in pairs(groupBest) do order[#order + 1] = { name = name, g = g } end
    table.sort(order, function(a, b)
        if db.zoneFirst and a.g.here ~= b.g.here then return a.g.here end
        if a.g.distance ~= b.g.distance then return a.g.distance < b.g.distance end
        return a.g.index < b.g.index
    end)
    for rank, entry in ipairs(order) do groupRank[entry.name] = rank end
    -- without zone headers a current-zone quest under another header still goes first
    for _, q in ipairs(questBuf) do
        q.ftRank = (db.zoneHeaders or not db.zoneFirst) and groupRank[q.ftHeader] or (q.ftHere and 0 or 1)
    end
    table.sort(questBuf, ByOrder)
    return questBuf
end

-- Tags in front of the title: + elite, g3 group of 3, d dungeon, r raid, pvp, ! daily, !! weekly
local function QuestTags(q)
    local tags = ""
    local tag = C_QuestLog.GetQuestTagInfo(q.questID)
    if tag and tag.isElite then tags = tags .. "+" end
    local id = tag and tag.tagID
    local T = Enum.QuestTag
    if id == T.Dungeon then tags = tags .. " d"
    elseif id == T.Raid or id == T.Raid10 or id == T.Raid25 then tags = tags .. " r"
    elseif id == T.PvP then tags = tags .. " pvp"
    elseif id == T.Heroic then tags = tags .. " hc"
    elseif (q.suggestedGroup or 0) > 1 then
        tags = tags .. " g" .. q.suggestedGroup
    end
    local F = Enum.QuestFrequency
    if q.frequency == F.Daily then tags = tags .. " !"
    elseif q.frequency == F.Weekly then tags = tags .. " !!" end
    return tags
end

-- Forever writes the count first ("3/8 Boar Tusks"); Numbers Last turns it into "Boar Tusks: 3/8"
local function NumbersLast(text)
    local count, name = text:match("^(%d+%s*/%s*%d+)%s+(.+)$")
    if count then return name .. ": " .. count end
    return text
end

--------------------------------------------------
-- 6. HIGH-LEVEL QUESTS
-- Quests too far above you are untracked when accepted and tracked again once close enough (or
-- when the option goes off). Only quests this module untracked are tracked again.
--------------------------------------------------
local function UntrackIfTooHigh(questID)
    local db = GetDb()
    if not (db and db.untrackHighLevel) then return end
    local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
    local info = logIndex and C_QuestLog.GetInfo(logIndex)
    if not (info and info.level) then return end
    if info.level - UnitLevel("player") < (db.highLevelDiff or 3) then return end
    if C_QuestLog.GetQuestWatchType(questID) == nil then return end
    C_QuestLog.RemoveQuestWatch(questID)
    Char().autoUntracked[questID] = true
end

function OT:CheckHighLevel(newLevel)
    local db = GetDb()
    if not db then return end
    local char = Char()
    local level = newLevel or UnitLevel("player")
    for questID in pairs(char.autoUntracked) do
        local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
        local info = logIndex and C_QuestLog.GetInfo(logIndex)
        if not info then
            char.autoUntracked[questID] = nil
        elseif not db.untrackHighLevel or (info.level or 0) - level < (db.highLevelDiff or 3) then
            char.autoUntracked[questID] = nil
            C_QuestLog.AddQuestWatch(questID)
        end
    end
    if db.untrackHighLevel then
        for i = 1, C_QuestLog.GetNumQuestLogEntries() do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader and info.questID and info.questID > 0 then UntrackIfTooHigh(info.questID) end
        end
    end
end

--------------------------------------------------
-- 7. CLICKS, MENU AND TOOLTIP
--------------------------------------------------
local function OpenQuest(questID)
    if QuestMapFrame_OpenToQuestDetails then QuestMapFrame_OpenToQuestDetails(questID) end
end

local function ToggleFocus(questID)
    local focused = C_SuperTrack.GetSuperTrackedQuestID() == questID
    C_SuperTrack.SetSuperTrackedQuestID(focused and 0 or questID)
end

local function ToggleCollapsed(questID)
    local c = Char().collapsedQuests
    c[questID] = not c[questID] or nil
    OT:RequestRender()
end

local function ShowQuestMenu(owner, questID)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(C_QuestLog.GetTitleForQuestID(questID) or "?")
        local focused = C_SuperTrack.GetSuperTrackedQuestID() == questID
        root:CreateButton(focused and TEXT.unfocus or TEXT.focus, function() ToggleFocus(questID) end)
        root:CreateButton(TEXT.openLog, function() OpenQuest(questID) end)
        local share = root:CreateButton(TEXT.share, function()
            C_QuestLog.SetSelectedQuest(questID)
            QuestLogPushQuest()
        end)
        share:SetEnabled(IsInGroup() and C_QuestLog.IsPushableQuest(questID))
        root:CreateButton(Char().collapsedQuests[questID] and L["Expand"] or L["Collapse"], function() ToggleCollapsed(questID) end)
        root:CreateButton(TEXT.untrack, function() C_QuestLog.RemoveQuestWatch(questID) end)
        root:CreateDivider()
        -- Blizzard's own abandon flow: its confirmation, its warning about quest items
        root:CreateButton("|cffff4040" .. TEXT.abandon .. "|r", function() QuestMapQuestOptions_AbandonQuest(questID) end)
    end)
end

local function ShowRecipeMenu(owner, recipeID, name)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(name)
        root:CreateButton(TEXT.openRecipe, function() C_TradeSkillUI.OpenRecipe(recipeID) end)
        root:CreateButton(TEXT.untrack, function() C_TradeSkillUI.SetRecipeTracked(recipeID, false, false) end)
    end)
end

local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t"

-- Blizzard's party progress lines for the quest (finished ones are grey in its data)
local function AddPartyProgress(questID)
    if GetNumSubgroupMembers() == 0 or not C_TooltipInfo or not C_TooltipInfo.GetQuestPartyProgress then return end
    local data = C_TooltipInfo.GetQuestPartyProgress(questID, true, true)
    if not (data and data.lines and #data.lines > 0) then return end
    GameTooltip:AddLine(" ")
    for _, l in ipairs(data.lines) do
        if l.leftText and l.leftText ~= "" then
            local r, g, b = 1, 1, 1
            if l.leftColor then r, g, b = l.leftColor:GetRGB() end
            if r == g and g == b and r < 0.9 then
                GameTooltip:AddLine(CHECK .. " " .. l.leftText, 0.6, 0.6, 0.6)
            else
                GameTooltip:AddLine(l.leftText, r, g, b)
            end
        end
    end
end

-- The tooltip opens on the side facing the middle of the screen, past the item buttons
local function AnchorTooltip(line)
    ns.OwnGameTooltip(line, "ANCHOR_NONE")
    local right = OT:Side()
    local gap = C.ITEM_SIZE + C.ITEM_GAP * 2
    if right then
        GameTooltip:SetPoint("TOPRIGHT", holder, "TOPLEFT", -gap, select(2, line:GetCenter()) - holder:GetTop() + 8)
    else
        GameTooltip:SetPoint("TOPLEFT", holder, "TOPRIGHT", gap, select(2, line:GetCenter()) - holder:GetTop() + 8)
    end
end

local function QuestTooltip(line)
    local questID = line.questID
    AnchorTooltip(line)
    GameTooltip:AddLine(C_QuestLog.GetTitleForQuestID(questID) or "?")
    local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
    if logIndex then
        local _, objectiveText = GetQuestLogQuestText(logIndex)
        if objectiveText and objectiveText ~= "" then GameTooltip:AddLine(objectiveText, 1, 1, 1, true) end
    end
    GameTooltip:AddLine(" ")
    if C_QuestLog.IsComplete(questID) then
        GameTooltip:AddLine(TEXT.ready, C.TITLE_DONE[1], C.TITLE_DONE[2], C.TITLE_DONE[3])
    else
        for _, obj in ipairs(C_QuestLog.GetQuestObjectives(questID) or {}) do
            if obj.text and obj.text ~= "" then
                if obj.finished then
                    GameTooltip:AddLine(CHECK .. " " .. obj.text, 0.6, 0.6, 0.6)
                else
                    GameTooltip:AddLine("- " .. obj.text, 1, 1, 1)
                end
            end
        end
    end
    AddPartyProgress(questID)
    GameTooltip:Show()
end

local function OnLineClick(self, button)
    if state.editMode then return end
    if self.zone then
        local z = Char().collapsedZones
        z[self.zone] = not z[self.zone] or nil
        OT:RequestRender()
        return
    end
    if self.recipeID then
        if button == "RightButton" then
            GameTooltip:Hide()
            ShowRecipeMenu(self, self.recipeID, self.recipeName)
        elseif IsShiftKeyDown() then
            C_TradeSkillUI.SetRecipeTracked(self.recipeID, false, false)
        else
            C_TradeSkillUI.OpenRecipe(self.recipeID)
        end
        return
    end
    local questID = self.questID
    if not questID then return end
    if button == "MiddleButton" then
        ToggleCollapsed(questID)
    elseif button == "RightButton" then
        GameTooltip:Hide()
        ShowQuestMenu(self, questID)
    elseif IsShiftKeyDown() then
        -- like Blizzard's tracker: while typing in chat, shift-click links the quest
        local link = GetQuestLink(questID)
        if link and ChatFrameUtil.GetActiveWindow() then
            ChatFrameUtil.InsertLink(link)
        else
            C_QuestLog.RemoveQuestWatch(questID)
        end
    else
        OpenQuest(questID)
    end
end

--------------------------------------------------
-- 8. LINES (one pooled button per text line)
--------------------------------------------------
-- Moving between two lines of a quest leaves one and enters the other in the same frame, so the
-- band and the tooltip go a frame after the mouse has left the quest: nothing blinks.
local function UnhoverLater()
    if state.hover == nil and state.shownGroup then
        state.shownGroup = nil
        OT:HighlightGroup(nil)
        GameTooltip:Hide()
    end
end

local function GetLine(i)
    local line = lines[i]
    if line then return line end
    line = CreateFrame("Button", nil, content)
    line.text = line:CreateFontString(nil, "OVERLAY")
    line.text:SetAllPoints()
    line:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    line:SetScript("OnClick", OnLineClick)
    line:SetScript("OnEnter", function(self)
        if state.editMode then return end
        state.hover = self.group
        if state.shownGroup == self.group then return end
        state.shownGroup = self.group
        OT:HighlightGroup(self.group)
        if self.questID then QuestTooltip(self) else GameTooltip:Hide() end
    end)
    line:SetScript("OnLeave", function()
        state.hover = nil
        C_Timer.After(0, UnhoverLater)
    end)
    lines[i] = line
    return line
end

--------------------------------------------------
-- 9. QUEST ITEM BUTTONS
-- Secure buttons, on UIParent by screen position (a protected frame may only anchor to UIParent),
-- beside their quest's title. In combat they stay put and work; the layout catches up after.
--------------------------------------------------
local function GetItemButton(i)
    local b = itemButtons[i]
    if b then return b end
    b = CreateFrame("Button", "FlareUI_TrackerItem" .. i, UIParent, "SecureActionButtonTemplate")
    local size = C.ITEM_SIZE
    b:SetSize(size, size)
    b:SetFrameStrata("MEDIUM")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "item")
    -- Blizzard's small action button: the mask at 1.5x the button, the frame art 31.6 x 30.9 per 30 px
    b.icon = b:CreateTexture(nil, "BACKGROUND")
    b.icon:SetAllPoints()
    local mask = b:CreateMaskTexture()
    mask:SetAtlas("UI-HUD-ActionBar-IconFrame-Mask")
    mask:SetPoint("CENTER", b.icon, "CENTER")
    mask:SetSize(size * 1.5, size * 1.5)
    b.icon:AddMaskTexture(mask)
    local art = size / 30
    b:SetNormalAtlas("UI-HUD-ActionBar-IconFrame")
    b:SetPushedAtlas("UI-HUD-ActionBar-IconFrame-Down")
    b:SetHighlightAtlas("UI-HUD-ActionBar-IconFrame-Mouseover")
    for _, t in ipairs({ b:GetNormalTexture(), b:GetPushedTexture(), b:GetHighlightTexture() }) do
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT")
        t:SetSize(31.6 * art, 30.9 * art)
    end
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    b.count:SetPoint("BOTTOMRIGHT", -2, 2)
    b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cooldown:SetAllPoints(b.icon)
    b:SetScript("OnEnter", function(self)
        if not self.logIndex then return end
        ns.OwnGameTooltip(self, "ANCHOR_LEFT")
        GameTooltip:SetQuestLogSpecialItem(self.logIndex)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:Hide()
    itemButtons[i] = b
    return b
end

local function UpdateItemRanges()
    for _, b in ipairs(itemButtons) do
        if b:IsShown() and b.logIndex then
            -- 0 = out of range, 1 = in range, nil = no range for this item
            local out = IsQuestLogSpecialItemInRange(b.logIndex) == 0
            if b.out ~= out then
                b.out = out
                if out then b.icon:SetVertexColor(1, 0.3, 0.3) else b.icon:SetVertexColor(1, 1, 1) end
            end
        end
    end
end

local function UpdateRangeTicker()
    local wanted = state.itemsShown > 0 and UnitExists("target")
    if wanted and not state.rangeTicker then
        state.rangeTicker = C_Timer.NewTicker(0.25, UpdateItemRanges)
    elseif not wanted and state.rangeTicker then
        state.rangeTicker:Cancel()
        state.rangeTicker = nil
        for _, b in ipairs(itemButtons) do b.out = nil; b.icon:SetVertexColor(1, 1, 1) end
    end
    if wanted then UpdateItemRanges() end
end

function OT:UpdateItemCooldowns()
    for _, b in ipairs(itemButtons) do
        if b:IsShown() and b.logIndex then
            local start, duration, enable = GetQuestLogSpecialItemCooldown(b.logIndex)
            if start then CooldownFrame_Set(b.cooldown, start, duration, enable) end
        end
    end
end

-- While minimized or hidden in combat the buttons cannot hide: they turn invisible instead
local function SetItemsAlpha(alpha)
    for _, b in ipairs(itemButtons) do b:SetAlpha(alpha) end
end

function OT:UpdateItemButtons()
    local showing = holder and holder:IsVisible() and scroll:IsShown()
    if InCombatLockdown() then
        state.itemsDirty = true
        SetItemsAlpha(showing and 1 or 0)
        return
    end
    state.itemsDirty = false
    SetItemsAlpha(1)
    local used = 0
    if showing then
        local right = self:Side()
        local viewTop, viewBottom = scroll:GetTop(), scroll:GetBottom()
        local edge = right and holder:GetLeft() or holder:GetRight()
        for _, line in ipairs(titleLines) do
            local link, texture, charges, showWhenComplete
            if line.sampleItem then
                link, texture, showWhenComplete = "sample", line.sampleItem, true
            else
                link, texture, charges, showWhenComplete = GetQuestLogSpecialItemInfo(line.logIndex)
            end
            local top = line:GetTop()
            local itemID = link and (line.sampleItem and 0 or link:match("item:(%d+)"))
            if itemID and top and viewTop and edge and top <= viewTop + 1 and top - C.ITEM_SIZE >= viewBottom - 1
                    and (showWhenComplete or line.sampleItem or not C_QuestLog.IsComplete(line.questID)) then
                used = used + 1
                local b = GetItemButton(used)
                if b.link ~= link then
                    b.link = link
                    -- the sample button gets no item, so a click on it does nothing
                    b:SetAttribute("item", (not line.sampleItem) and ("item:" .. itemID) or nil)
                    b.icon:SetTexture(texture)
                end
                b.logIndex = line.logIndex
                b.count:SetText((charges and charges > 1) and tostring(charges) or "")
                b:ClearAllPoints()
                if right then
                    b:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", edge - C.ITEM_GAP, top + 2)
                else
                    b:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", edge + C.ITEM_GAP, top + 2)
                end
                b:Show()
            end
        end
    end
    for i = used + 1, #itemButtons do itemButtons[i]:Hide() end
    state.itemsShown = used
    self:UpdateItemCooldowns()
    UpdateRangeTicker()
end

--------------------------------------------------
-- 10. RENDER
--------------------------------------------------
-- Sample quests, in Edit Mode while nothing is tracked; one has a sample item button
local PREVIEW = {
    { zone = true, text = "Elwynn Forest" },
    { level = 7, title = "Kobold Camp Cleanup", objectives = { { text = "6/10 Kobold Vermin slain" } } },
    { level = 8, title = "Wolves Across the Border", objectives = { { text = "4/8 Tough Wolf Meat" } },
      item = "Interface\\Icons\\INV_Misc_Bag_10" },
    { level = 9, title = "Red Linen Goods", objectives = { { text = "6/6 Red Linen Bandana", finished = true } }, done = true },
    { zone = true, text = "Westfall" },
    { level = 14, tags = "+ g5", title = "The Defias Brotherhood", objectives = { { text = "Speak with Gryan Stoutmantle" } } },
    { level = 12, title = "Westfall Stew", objectives = {
        { text = "3/3 Stringy Vulture Meat", finished = true }, { text = "1/3 Goretusk Snout" },
        { text = "0/3 Murloc Eye" }, { text = "2/3 Okra" } } },
    { level = 11, title = "Poor Old Blanchy", objectives = { { text = "8/8 Handful of Oats", finished = true } }, done = true },
    { zone = true, text = "Duskwood" },
    { level = 24, tags = " d", title = "The Night Watch", objectives = { { text = "0/12 Skeletal Warrior slain" }, { text = "0/6 Skeletal Mage slain" } } },
}

function OT:Render()
    state.pending = false
    local db = GetDb()
    if not (db and holder) then return end
    local char = Char()
    local minimized = char.minimized and not state.editMode

    -- header
    local count, max = QuestCount()
    local title = TEXT.quests
    if db.showCount then title = title .. "  " .. ColorCode(C.DIM) .. (max and (count .. "/" .. max) or count) .. "|r" end
    header.title:SetText(title)
    header.zone.text:SetText(db.zoneOnly and L["Zone"] or L["All"])
    header.zone:SetSize(header.zone.text:GetStringWidth() + 6, C.HEADER - 6)

    -- title on the left; the zone switch and the minimize button on the right
    local button = header.minimize
    button:ClearAllPoints()
    header.title:ClearAllPoints()
    header.zone:ClearAllPoints()
    button:SetPoint("RIGHT", header, "RIGHT", 0, 0)
    header.zone:SetPoint("RIGHT", button, "LEFT", -6, 0)
    header.title:SetPoint("LEFT", header, "LEFT", C.PAD - C.HEADER_INSET, 0)
    button:SetPlus(minimized)

    -- content
    local n, y = 0, 0
    local lastBottom = 0   -- the bottom of the last line drawn
    local width = (db.width or C.WIDTH) - C.PAD * 2
    wipe(titleLines)
    local fonts = { header = db.headerFont, title = db.titleFont, objective = db.objectiveFont }

    local function AddLine(text, kind, color, indent)
        n = n + 1
        local line = GetLine(n)
        local w = width - (indent or 0)
        local cfg = fonts[kind]
        ApplyFont(line.text, cfg, kind == "objective" and 11 or 12)
        line.text:SetJustifyH("LEFT")
        line.text:SetWordWrap(db.wrapText ~= false)
        line.text:SetMaxLines(db.wrapText ~= false and 0 or 1)
        line.text:SetText(text)
        SetColor(line.text, color)
        line:SetWidth(w)
        line.text:SetWidth(w)
        local h = math_max(FontHeight(cfg, 12), math_floor(line.text:GetStringHeight() + 0.5))
        line:SetHeight(h)
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", content, "TOPLEFT", C.PAD + (indent or 0), y)
        -- the mouse area reaches the band's edges and the gap to the next line
        line:SetHitRectInsets(-(C.PAD + (indent or 0) - 4), -(C.PAD - 4), -1, -(C.LINE_GAP - 1))
        line.questID, line.zone, line.recipeID, line.recipeName, line.logIndex = nil, nil, nil, nil, nil
        line.group, line.sampleItem = nil, nil
        line:Show()
        lastBottom = y - h
        y = y - h - C.LINE_GAP
        return line
    end

    local function TitleText(level, tags, title, collapsed)
        local prefix = ""
        if db.showLevel and level then
            local c = GetQuestDifficultyColor(level)
            prefix = ColorCode({ c.r, c.g, c.b }) .. "[" .. level .. (db.showTags and tags or "") .. "]|r "
        end
        return prefix .. title .. (collapsed and ("  " .. ColorCode(C.DIM) .. "+|r") or "")
    end

    local empty = true
    if not minimized then
        if state.editMode and self:CountTracked() == 0 then
            for _, s in ipairs(PREVIEW) do
                if s.zone then
                    if db.zoneHeaders then
                        if n > 0 then y = y - C.GROUP_GAP end
                        AddLine(s.text, "header", C.ZONE)
                        y = y - C.ZONE_GAP
                    end
                else
                    local line = AddLine(TitleText(s.level, s.tags or "", s.title), "title", s.done and C.TITLE_DONE or C.TITLE)
                    if s.item then
                        line.sampleItem = s.item
                        titleLines[#titleLines + 1] = line
                    end
                    for _, o in ipairs(s.objectives) do
                        AddLine(db.numbersLast and NumbersLast(o.text) or o.text, "objective", o.finished and C.OBJECTIVE_DONE or C.OBJECTIVE, C.INDENT)
                    end
                    y = y - C.QUEST_GAP
                end
            end
            empty = false
        else
            local quests = CollectQuests(db)
            local focused = C_SuperTrack.GetSuperTrackedQuestID()
            local lastHeader
            local zoneCounts = {}
            for _, q in ipairs(quests) do zoneCounts[q.ftHeader] = (zoneCounts[q.ftHeader] or 0) + 1 end
            local order = state.order
            wipe(order)
            for _, q in ipairs(quests) do
                empty = false
                order[#order + 1] = q.questID
                local zoneCollapsed = db.zoneHeaders and char.collapsedZones[q.ftHeader]
                if db.zoneHeaders and q.ftHeader ~= lastHeader then
                    lastHeader = q.ftHeader
                    if n > 0 then y = y - C.GROUP_GAP end
                    local text = zoneCollapsed and string_format("%s  %s(%d)|r", q.ftHeader, ColorCode(C.DIM), zoneCounts[q.ftHeader]) or q.ftHeader
                    AddLine(text, "header", C.ZONE).zone = q.ftHeader
                    if not zoneCollapsed then y = y - C.ZONE_GAP end
                end
                if not zoneCollapsed then
                    local collapsed = char.collapsedQuests[q.questID]
                    local complete = C_QuestLog.IsComplete(q.questID)
                    local color = q.questID == focused and C.TITLE_FOCUS or (complete and C.TITLE_DONE or C.TITLE)
                    local line = AddLine(TitleText(q.level, QuestTags(q), q.title or "?", collapsed), "title", color)
                    line.questID, line.logIndex = q.questID, q.ftLogIndex
                    titleLines[#titleLines + 1] = line
                    if not collapsed then
                        if complete then
                            AddLine(TEXT.ready, "objective", C.TITLE_DONE, C.INDENT).questID = q.questID
                        else
                            for _, obj in ipairs(C_QuestLog.GetQuestObjectives(q.questID) or {}) do
                                if obj.text and obj.text ~= "" then
                                    local text = db.numbersLast and NumbersLast(obj.text) or obj.text
                                    AddLine(text, "objective", obj.finished and C.OBJECTIVE_DONE or C.OBJECTIVE, C.INDENT).questID = q.questID
                                end
                            end
                        end
                    end
                    y = y - C.QUEST_GAP
                end
            end

            -- recipes tracked in the profession window, with each reagent as "in bags/needed"
            local recipes = db.showRecipes and C_TradeSkillUI and C_TradeSkillUI.GetRecipesTracked
                and C_TradeSkillUI.GetRecipesTracked(false) or {}
            state.recipes = #recipes
            if #recipes > 0 then
                empty = false
                if n > 0 then y = y - C.GROUP_GAP end
                local collapsedRecipes = char.collapsedZones[TEXT.recipes]
                local text = collapsedRecipes and string_format("%s  %s(%d)|r", TEXT.recipes, ColorCode(C.DIM), #recipes) or TEXT.recipes
                AddLine(text, "header", C.ZONE).zone = TEXT.recipes
                if not collapsedRecipes then
                    y = y - C.ZONE_GAP
                    for _, recipeID in ipairs(recipes) do
                        local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeID, false)
                        local name = schematic and schematic.name or "?"
                        local line = AddLine(name, "title", C.TITLE)
                        line.recipeID, line.recipeName = recipeID, name
                        for _, slot in ipairs(schematic and schematic.reagentSlotSchematics or {}) do
                            local reagent = slot.reagents and slot.reagents[1]
                            if slot.reagentType == Enum.CraftingReagentType.Basic and reagent and reagent.itemID then
                                local have = C_Item.GetItemCount(reagent.itemID)
                                local itemName = C_Item.GetItemNameByID(reagent.itemID) or "..."
                                local text = string_format("%d/%d %s", have, slot.quantityRequired, itemName)
                                if db.numbersLast then text = string_format("%s: %d/%d", itemName, have, slot.quantityRequired) end
                                local r = AddLine(text, "objective", have >= slot.quantityRequired and C.OBJECTIVE_DONE or C.OBJECTIVE, C.INDENT)
                                r.recipeID, r.recipeName = recipeID, name
                            end
                        end
                        y = y - C.QUEST_GAP
                    end
                end
            end
        end
    end
    for i = n + 1, #lines do lines[i]:Hide() end
    wipe(state.groups)
    for i = 1, n do
        local line = lines[i]
        local key = (line.questID and ("q" .. line.questID)) or (line.recipeID and ("r" .. line.recipeID))
            or (line.zone and ("z" .. i))
        line.group = key
        if key then
            local g = state.groups[key]
            if not g then g = { first = line }; state.groups[key] = g end
            g.last = line
        end
    end
    state.shownGroup = nil
    self:HighlightGroup(nil)
    state.empty = empty

    -- size: the header, then the list up to the maximum height (scrolling past it)
    local contentHeight = math_max(1, -lastBottom)
    local maxHeight = db.maxHeight or C.MAX_HEIGHT
    local listHeight = math_min(contentHeight, maxHeight)
    content:SetWidth(db.width or C.WIDTH)
    content:SetHeight(contentHeight)
    local showList = not minimized and n > 0
    scroll:SetShown(showList)
    divider:SetShown(showList)
    scroll:SetVerticalScroll(math_min(scroll:GetVerticalScroll(), math_max(0, contentHeight - listHeight)))
    holder:SetWidth(db.width or C.WIDTH)
    -- in Edit Mode the frame takes its maximum height, so the selection shows its full reach
    if state.editMode then listHeight = maxHeight end
    scroll:SetHeight(math_max(1, listHeight))
    holder:SetHeight(C.HEADER + (showList and (C.LIST_TOP + listHeight + C.LIST_BOTTOM) or 0))
    state.contentHeight, state.listHeight = contentHeight, listHeight
    self:UpdateScrollBar()

    -- Minimize Style "button": minimized, only a lone "+" shows at the anchored corner
    local lone = minimized and db.minimizeStyle == "button"
    -- Hide When Empty asks whether anything is tracked, not whether anything was drawn
    local tracked = self:CountTracked() > 0
        or (db.showRecipes and C_TradeSkillUI and C_TradeSkillUI.GetRecipesTracked
            and #C_TradeSkillUI.GetRecipesTracked(false) > 0)
    local hide = not tracked and db.hideEmpty and not state.editMode
    holder:SetShown(not lone and not hide)
    if miniButton then
        miniButton:ClearAllPoints()
        local corner = CornerOf(self:Side())
        miniButton:SetPoint(corner, holder, corner, 0, 0)
        miniButton:SetShown(lone and not hide)
    end
    self:UpdateItemButtons()
    state.rendered = true
end

-- A faint band behind every line of the quest pointed at, across the list's width
function OT:HighlightGroup(key)
    local band = content and content.Highlight
    if not band then return end
    local g = key and state.groups[key]
    if not g then band:Hide() return end
    band:ClearAllPoints()
    band:SetPoint("TOPLEFT", g.first, "TOPLEFT", -(C.PAD - 4), 2)
    band:SetPoint("BOTTOMRIGHT", g.last, "BOTTOMRIGHT", C.PAD - 4, -2)
    band:Show()
end

-- Shown while the list is longer than the frame: a thumb sized and placed as the visible part of the
-- list (the mouse wheel scrolls)
function OT:UpdateScrollBar()
    local track, thumb = holder and holder.ScrollTrack, holder and holder.ScrollThumb
    if not track then return end
    local contentHeight, listHeight = state.contentHeight or 0, state.listHeight or 0
    local scrollable = scroll:IsShown() and contentHeight > listHeight + 1
    track:SetShown(scrollable)
    thumb:SetShown(scrollable)
    if not scrollable then return end
    local px = ns.PixelSize(holder)
    local x = -(C.SCROLLBAR_INSET)
    track:ClearAllPoints()
    track:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", x - px, 0)
    track:SetSize(px, listHeight)
    local thumbHeight = math_max(C.SCROLLBAR_MIN, listHeight * listHeight / contentHeight)
    local range = contentHeight - listHeight
    local offset = range > 0 and math_min(1, math_max(0, scroll:GetVerticalScroll() / range)) or 0
    thumb:ClearAllPoints()
    thumb:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", x, -(listHeight - thumbHeight) * offset)
    thumb:SetSize(px * 3, thumbHeight)
end

function OT:CountTracked()
    local n = 0
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID and info.questID > 0
                and C_QuestLog.GetQuestWatchType(info.questID) ~= nil then n = n + 1 end
    end
    return n
end

-- Quest log events come in bursts: one redraw for each burst
function OT:RequestRender()
    if state.pending or not holder then return end
    state.pending = true
    C_Timer.After(0.1, function() OT:Render() end)
end

-- Distance changes as you walk: redraw only when the order would change
local function OnSortTick()
    local db = GetDb()
    if not (db and db.sortByDistance and holder and holder:IsVisible() and scroll:IsShown()) then return end
    local quests, order = CollectQuests(db), state.order
    if #quests ~= #order then OT:RequestRender() return end
    for i, q in ipairs(quests) do
        if q.questID ~= order[i] then OT:RequestRender() return end
    end
end

--------------------------------------------------
-- 11. MINIMIZE AND AUTO-MINIMIZE
--------------------------------------------------
function OT:SetMinimized(minimized)
    Char().minimized = minimized and true or false
    self:Render()
end

function OT:ToggleMinimized()
    self:SetMinimized(not Char().minimized)
end

-- The kind of place you are in; combat counts while it lasts (when it has a rule)
local function CurrentContext(db)
    local rules = db.autoMinimize or {}
    if InCombatLockdown() and rules.combat and rules.combat ~= "none" then return "combat" end
    local _, instanceType = IsInInstance()
    if instanceType == "party" then return "dungeon" end
    if instanceType == "raid" then return "raid" end
    if instanceType == "pvp" then return "pvp" end
    if instanceType == "arena" then return "arena" end
    if IsResting() then return "resting" end
    return "world"
end

-- Each rule applies once, on the way in
function OT:CheckContext()
    local db = GetDb()
    if not db then return end
    local context = CurrentContext(db)
    if context == state.context then return end
    state.context = context
    local rule = db.autoMinimize and db.autoMinimize[context]
    if rule == "minimize" then self:SetMinimized(true)
    elseif rule == "expand" then self:SetMinimized(false) end
end

--------------------------------------------------
-- 12. BLIZZARD'S TRACKER
-- Parked under a hidden frame (Hide is blocked in combat, and Blizzard re-shows it), re-parented
-- whenever Blizzard moves it. It keeps running, so new quests are still tracked automatically.
--------------------------------------------------
local parking = CreateFrame("Frame")
parking:Hide()

local function ParkBlizzardTracker()
    local tracker = _G.ObjectiveTrackerFrame
    if not tracker or InCombatLockdown() then return end
    if not state.parkHooked then
        state.parkHooked = true
        hooksecurefunc(tracker, "SetParent", function(self, parent)
            if parent ~= parking and not InCombatLockdown() then self:SetParent(parking) end
        end)
    end
    if tracker:GetParent() ~= parking then tracker:SetParent(parking) end
end

--------------------------------------------------
-- 13. EDIT MODE SETTINGS
--------------------------------------------------
local function BuildSettings()
    local function get(key, default)
        return function()
            local db = GetDb()
            return db and db[key] or default
        end
    end
    local function set(key)
        return function(_, value)
            local db = GetDb()
            if not db then return end
            db[key] = value
            OT:Render()
        end
    end
    return {
        { name = L["Width"], kind = LEM.SettingType.Slider, default = C.WIDTH, minValue = 180, maxValue = 500, valueStep = 5,
          get = get("width", C.WIDTH), set = set("width") },
        { name = L["Max Height"], kind = LEM.SettingType.Slider, default = C.MAX_HEIGHT, minValue = 150, maxValue = 1000, valueStep = 10,
          get = get("maxHeight", C.MAX_HEIGHT), set = set("maxHeight") },
    }
end

--------------------------------------------------
-- 14. SETUP
--------------------------------------------------
-- A small square button: a one-pixel bronze outline with chamfered corners (2 px, 3 on the big
-- one), a dark fill and a two-pixel minus or plus, on whole screen pixels (re-laid on each show)
local function CreateBoxButton(parent, name, size)
    local b = CreateFrame("Button", name, parent)
    b:SetSize(size, size)
    local chamfer = size >= 16 and 3 or 2
    local function Tex(layer)
        local t = b:CreateTexture(nil, layer)
        t:SetSnapToPixelGrid(false)
        t:SetTexelSnappingBias(0)
        return t
    end
    b.edges = { Tex("ARTWORK"), Tex("ARTWORK"), Tex("ARTWORK"), Tex("ARTWORK") }
    b.steps, b.fill = {}, {}
    b.dash, b.stem = Tex("ARTWORK"), Tex("ARTWORK")

    function b:Layout()
        local px = ns.PixelSize(self)
        local n = math_max(chamfer * 2 + 4, math_floor(size / px + 0.5))   -- the side, in pixels
        if n % 2 == 1 then n = n + 1 end                                    -- even, so the glyph centres
        local c = chamfer
        local function Place(t, x, y, w, h)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", self, "TOPLEFT", x * px, -y * px)
            t:SetSize(w * px, h * px)
            t:Show()
        end
        self:SetSize(n * px, n * px)
        -- outline: the four sides, stopping short of the corners ...
        local e = self.edges
        Place(e[1], c, 0, n - 2 * c, 1)
        Place(e[2], c, n - 1, n - 2 * c, 1)
        Place(e[3], 0, c, 1, n - 2 * c)
        Place(e[4], n - 1, c, 1, n - 2 * c)
        -- ... and the steps that join them across each corner
        local i = 0
        for k = 1, c - 1 do
            for _, xy in ipairs({ { k, c - k }, { n - 1 - k, c - k }, { k, n - 1 - (c - k) }, { n - 1 - k, n - 1 - (c - k) } }) do
                i = i + 1
                local t = self.steps[i]
                if not t then t = Tex("ARTWORK"); self.steps[i] = t end
                Place(t, xy[1], xy[2], 1, 1)
            end
        end
        for j = i + 1, #self.steps do self.steps[j]:Hide() end
        -- fill: overlapping rectangles, each a pixel narrower and taller, so it stops at the steps
        for k = 1, c do
            local t = self.fill[k]
            if not t then
                t = Tex("BACKGROUND")
                t:SetColorTexture(0, 0, 0, 0.85)
                self.fill[k] = t
            end
            local inset = c - k + 1
            Place(t, k, inset, n - 2 * k, n - 2 * inset)
        end
        -- the minus, and the stem that makes it a plus
        local arm = math_floor(n * 0.5 + 0.5)
        if (n - arm) % 2 == 1 then arm = arm + 1 end
        Place(self.dash, (n - arm) / 2, (n - 2) / 2, arm, 2)
        Place(self.stem, (n - 2) / 2, (n - arm) / 2, 2, arm)
        self.stem:SetShown(self.plus or false)
        self:Paint(self.lit)
    end
    function b:Paint(lit)
        self.lit = lit
        local c = lit and C.BOX_COLOR_LIT or C.BOX_COLOR
        for _, t in ipairs(self.edges) do t:SetColorTexture(c[1], c[2], c[3], 1) end
        for _, t in ipairs(self.steps) do t:SetColorTexture(c[1], c[2], c[3], 1) end
        self.dash:SetColorTexture(c[1], c[2], c[3], 1)
        self.stem:SetColorTexture(c[1], c[2], c[3], 1)
    end
    function b:SetPlus(plus)
        self.plus = plus
        self.stem:SetShown(plus)
    end
    b:HookScript("OnEnter", function(self) self:Paint(true) end)
    b:HookScript("OnLeave", function(self) self:Paint(false) end)
    b:HookScript("OnShow", function(self) self:Layout() end)
    b:Layout()
    return b
end

local function CreateFrames()
    holder = CreateFrame("Frame", "FlareUI_ObjectiveTracker", UIParent, "BackdropTemplate")
    holder:SetFrameStrata("LOW")
    holder:SetClampedToScreen(true)
    holder:SetSize(C.WIDTH, C.HEADER)
    holder:EnableMouse(true)

    header = CreateFrame("Frame", nil, holder)
    header:SetPoint("TOPLEFT", C.HEADER_INSET, -3)
    header:SetPoint("TOPRIGHT", -C.HEADER_INSET, -3)
    header:SetHeight(C.HEADER - 3)

    header.title = header:CreateFontString(nil, "OVERLAY")

    local minimize = CreateBoxButton(header, nil, C.BOX)
    minimize:SetScript("OnClick", function() OT:ToggleMinimized() end)
    minimize:SetScript("OnEnter", function(self)
        ns.OwnGameTooltip(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(Char().minimized and L["Expand"] or L["Minimize"])
        GameTooltip:Show()
    end)
    minimize:SetScript("OnLeave", function() GameTooltip:Hide() end)
    header.minimize = minimize

    local zone = CreateFrame("Button", nil, header)
    zone.text = zone:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    zone.text:SetPoint("CENTER")
    zone:SetScript("OnClick", function(self)
        local db = GetDb()
        db.zoneOnly = not db.zoneOnly
        OT:Render()
        self:GetScript("OnEnter")(self)
    end)
    zone:SetScript("OnEnter", function(self)
        self.text:SetTextColor(1, 1, 1)
        ns.OwnGameTooltip(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(GetDb().zoneOnly and L["Showing the quests of this zone"] or L["Showing all tracked quests"])
        GameTooltip:AddLine(L["Click to switch"], 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    zone:SetScript("OnLeave", function(self)
        self.text:SetTextColor(C.DIM[1], C.DIM[2], C.DIM[3])
        GameTooltip:Hide()
    end)
    header.zone = zone

    divider = holder:CreateTexture(nil, "ARTWORK")
    divider:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
    divider:SetPoint("TOPLEFT", holder, "TOPLEFT", C.HEADER_INSET, -C.HEADER + 2)
    divider:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -C.HEADER_INSET, -C.HEADER + 2)
    divider:SetHeight(8)

    scroll = CreateFrame("ScrollFrame", nil, holder)
    scroll:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -C.HEADER - C.LIST_TOP)
    scroll:SetPoint("RIGHT", holder, "RIGHT", 0, 0)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(C.WIDTH, 1)
    scroll:SetScrollChild(content)
    content.Highlight = content:CreateTexture(nil, "BACKGROUND")
    content.Highlight:SetColorTexture(1, 1, 1, 0.04)
    content.Highlight:Hide()
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local max = math_max(0, content:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math_min(max, math_max(0, self:GetVerticalScroll() - delta * C.SCROLL_STEP)))
    end)
    scroll:SetScript("OnVerticalScroll", function()
        OT:UpdateScrollBar()
        OT:UpdateItemButtons()
    end)

    -- the scroll bar: a faint track down the list's right margin and a bronze thumb on it
    holder.ScrollTrack = holder:CreateTexture(nil, "ARTWORK")
    holder.ScrollTrack:SetColorTexture(C.BOX_COLOR[1], C.BOX_COLOR[2], C.BOX_COLOR[3], 0.25)
    holder.ScrollThumb = holder:CreateTexture(nil, "OVERLAY")
    holder.ScrollThumb:SetColorTexture(C.BOX_COLOR[1], C.BOX_COLOR[2], C.BOX_COLOR[3], 1)
    for _, t in ipairs({ holder.ScrollTrack, holder.ScrollThumb }) do
        t:SetSnapToPixelGrid(false)
        t:SetTexelSnappingBias(0)
        t:Hide()
    end

    -- the lone "+" of Minimize Style "button"
    miniButton = CreateBoxButton(UIParent, "FlareUI_ObjectiveTrackerButton", C.LONE)
    miniButton:SetFrameStrata("LOW")
    miniButton:SetPlus(true)
    miniButton:SetScript("OnClick", function() OT:SetMinimized(false) end)
    miniButton:SetScript("OnEnter", function(self)
        ns.OwnGameTooltip(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(TEXT.quests)
        GameTooltip:AddLine(L["Expand"], 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    miniButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    miniButton:Hide()
end

function OT:ApplyLook()
    if not holder then return end
    local db = GetDb()
    ApplyBackdrop()
    ApplyFont(header.title, db.headerFont, 13)
    SetColor(header.title, C.TITLE)
    header.zone.text:SetTextColor(C.DIM[1], C.DIM[2], C.DIM[3])
end

function OT:Refresh()
    if not holder then return end
    self:ApplyLook()
    self:CheckHighLevel()
    self:Render()
end

-- Stands aside in the Gamepad UI
function OT:ShouldLoad()
    return not ns.IsGamepadUI()
end

function OT:Init()
    if self.initialized then return end
    self.initialized = true

    CreateFrames()
    ApplyPosition()
    LEM:AddFrame(holder, OnFrameMoved, C.DEFAULT_POSITION, "FlareUI Quest Tracker")
    LEM:AddFrameSettings(holder, BuildSettings())
    LEM:RegisterCallback("layout", function(layoutName) ApplyPosition(layoutName); OT:RequestRender() end)
    LEM:RegisterCallback("enter", function() state.editMode = true; OT:Render() end)
    LEM:RegisterCallback("exit", function() state.editMode = false; OT:Render() end)

    local events = CreateFrame("Frame")
    for _, e in ipairs({
        "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "QUEST_ACCEPTED", "QUEST_REMOVED",
        "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED_INDOORS", "SUPER_TRACKING_CHANGED",
        "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_UPDATE_RESTING", "BAG_UPDATE_COOLDOWN",
        "PLAYER_LEVEL_UP", "PLAYER_TARGET_CHANGED", "TRACKED_RECIPE_UPDATE", "BAG_UPDATE_DELAYED",
        "GET_ITEM_INFO_RECEIVED", "UNIT_QUEST_LOG_CHANGED",
    }) do events:RegisterEvent(e) end
    events:SetScript("OnEvent", function(_, event, arg1, arg2)
        if event == "PLAYER_ENTERING_WORLD" then
            ParkBlizzardTracker()
            OT:CheckContext()
            -- once more a moment later: the first layout can come before the fonts are ready
            C_Timer.After(1, function() OT:Render() end)
        elseif event == "PLAYER_REGEN_ENABLED" then
            ParkBlizzardTracker()
            OT:CheckContext()
            if state.itemsDirty then OT:UpdateItemButtons() end
            return
        elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_UPDATE_RESTING" then
            OT:CheckContext()
            return
        elseif event == "BAG_UPDATE_COOLDOWN" then
            OT:UpdateItemCooldowns()
            return
        elseif event == "PLAYER_TARGET_CHANGED" then
            UpdateRangeTicker()
            return
        elseif event == "UNIT_QUEST_LOG_CHANGED" and arg1 ~= "player" then
            return
        elseif (event == "BAG_UPDATE_DELAYED" or event == "GET_ITEM_INFO_RECEIVED") and state.recipes == 0 then
            return
        elseif event == "ZONE_CHANGED_NEW_AREA" then
            OT:CheckContext()
        elseif event == "PLAYER_LEVEL_UP" then
            -- UnitLevel can still answer the old level here; the event has the new one
            OT:CheckHighLevel(arg1)
        elseif event == "QUEST_REMOVED" and arg1 then
            local char = Char()
            char.collapsedQuests[arg1] = nil
            char.autoUntracked[arg1] = nil
        elseif event == "QUEST_WATCH_LIST_CHANGED" and arg1 and arg2 then
            -- ticked by hand: no longer one of ours to re-tick
            Char().autoUntracked[arg1] = nil
        elseif event == "QUEST_ACCEPTED" then
            -- Blizzard ticks a new quest just after this event, so the check waits a moment
            local questID = arg2 or arg1
            C_Timer.After(0.5, function() UntrackIfTooHigh(questID) end)
        end
        OT:RequestRender()
    end)
    C_Timer.NewTicker(C.SORT_TICK, OnSortTick)

    self:ApplyLook()
    self:CheckHighLevel()
    self:Render()
end

-- Key Bindings > AddOns > FlareUI > Minimize / Expand Quest Tracker
function FlareUI_ToggleObjectiveTracker()
    if OT.initialized then OT:ToggleMinimized() end
end
