local _, ns = ...
local L = ns.L

--------------------------------------------------
-- QUEST TRACKER
-- Replaces Blizzard's tracker (parked) with tracked quests and recipes in an Edit Mode window that
-- grows away from its screen edge and minimizes to its header or a lone "+". Third-party licence
-- notices: LICENSES/.
--------------------------------------------------

--------------------------------------------------
-- 1. MODULE REGISTRATION
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
    DEFAULT_POSITION = { point = "TOPLEFT", x = 2, y = -2 },
    DEFAULT_BORDER = "FlareUI Frames",
    WIDTH = 250, MAX_HEIGHT = 300,
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
    BUTTON_ROOM = 13,       -- beside a title, for each focus / play button
    BUTTON_SIZE = 12,
    -- Quest animations: px a quest slides, seconds for it to move, leave, and for a sheen to cross
    SLIDE = 24, MOVE_TIME = 0.25, LEAVE_TIME = 0.3, SHEEN_TIME = 0.6, SHEEN_WIDTH = 36,
    -- colours: zone headers in FlareUI's tab bronze, titles in Blizzard's tracker gold and blue
    ZONE = { 0.80, 0.60, 0.34 },
    TITLE = { 1, 0.82, 0 },
    TITLE_DONE = { 0.13, 1, 0.13 },
    TITLE_FOCUS = { 0.40, 0.80, 1 },
    OBJECTIVE = { 0.85, 0.85, 0.85 },
    OBJECTIVE_DONE = { 0.55, 0.55, 0.55 },
    DIM = { 0.55, 0.55, 0.55 },
    URGENT = { 1, 0.25, 0.25 },
    -- a quest timer by the quarter of its time it is in, last to first
    TIMER = { { 1, 0.25, 0.25 }, { 1, 0.5, 0.15 }, { 1, 1, 0 }, { 0.25, 1, 0.25 } },
    NO_FONT = {},           -- a font setting with nothing set (only ever read)
}

-- Shared with the settings specimen so its palette follows the live tracker.
OT.SampleColors = { TITLE = C.TITLE, TITLE_FOCUS = C.TITLE_FOCUS, ZONE = C.ZONE, OBJECTIVE = C.OBJECTIVE }

-- Blizzard's strings where it has them
local TEXT = {
    quests = _G.QUESTS_LABEL or "Quests",
    ready = _G.QUEST_WATCH_QUEST_READY or "Ready to turn in",
    failed = _G.FAILED or "Failed",
    timeLeft = _G.TIME_REMAINING or "Time Remaining:",
    clickComplete = _G.QUEST_WATCH_CLICK_TO_COMPLETE or "Click to complete quest",
    waypoint = _G.WAYPOINT_OBJECTIVE_FORMAT_OPTIONAL or "%s",
    showMap = _G.OBJECTIVES_SHOW_QUEST_MAP or "Show on Map",
    linkChat = _G.SHARE_IN_CHAT or "Link to Chat",
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
BINDING_NAME_FLAREUI_TRACKER = L["Minimize/Expand Tracker"]

local holder, header, scroll, content, divider, miniButton
local lines, itemButtons, titleLines = {}, {}, {}
local questTimers, timerTotals, timerLines = {}, {}, {}   -- by questID: seconds left, full time, the line showing them
local state = {
    pending = false, editMode = false,
    context = nil, order = {}, itemsDirty = false, rangeTicker = nil, itemsShown = 0,
    recipes = 0, empty = false, groups = {},
    arriving = {}, seen = {}, tops = {}, sheens = {},
    zoneCounts = {}, fonts = {},   -- reused by every render
}
-- builders shared by the tracker and the settings preview's sample (OT.CreateSample)
local Build = {}

local function GetDb()
    return ns.db and ns.db.profile and ns.db.profile.objectivetracker
end

-- Whether this tracker runs in the current input mode: always with keyboard and mouse; in the
-- Gamepad UI unless Blizzard's Tracker in Gamepad Mode is on. (Its own on/off is db.enabled.)
function OT.WantedInMode()
    if not ns.IsGamepadUI() then return true end
    local db = GetDb()
    return not (db and db.padBlizzard)
end

-- The character's own state: minimized, collapsed quests and zones
local function Char()
    local c = ns.CharDB()
    c.objectiveTracker = c.objectiveTracker or {}
    local t = c.objectiveTracker
    t.collapsedQuests = t.collapsedQuests or {}
    t.collapsedZones = t.collapsedZones or {}
    t.pinned = t.pinned or {}   -- questID -> true: Pin to Top
    return t
end

local function SetColor(fontString, c) fontString:SetTextColor(c[1], c[2], c[3]) end

-- How far along an objective is, 0 to 1. A count alone proves nothing: action objectives can read
-- 1/1 before they are finished
local function ObjectiveProgress(obj)
    if obj.finished then return 1 end
    local have, need = obj.numFulfilled, obj.numRequired
    if have and need and need > 0 and have < need then return have / need end
    return 0
end

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

-- Where the frame stands now: right when its centre is on the right half; top when its top edge is
-- nearer the screen's top than its bottom edge is to the screen's bottom. The edges, not the centre:
-- a tall tracker near the top has its centre low, and held by the bottom it would collapse downward.
local function SideFromRect()
    local right, top = true, true
    local left, bottom, width, height = holder:GetRect()
    if left then
        local w, h = UIParent:GetSize()
        right = left + width / 2 > w / 2
        top = h - (bottom + height) <= bottom
    end
    return right, top
end

local CORNER_SIDES = { TOPRIGHT = { true, true }, TOPLEFT = { false, true },
                       BOTTOMRIGHT = { true, false }, BOTTOMLEFT = { false, false } }

-- right, top: the corner the frame is held by, so the answer stays put while its height changes.
-- Edit Mode's Anchor (Top / Bottom) wins; fresh = judge where it stands now (after a move).
function OT:Side(fresh)
    local db = GetDb()
    local anchor = db and db.anchor
    local right, top = true, true
    if holder then
        local sides = not fresh and CORNER_SIDES[holder:GetPoint(1) or ""]
        if sides then right, top = sides[1], sides[2] else right, top = SideFromRect() end
    end
    if anchor == "TOP" then top = true elseif anchor == "BOTTOM" then top = false end
    return right, top
end

local function CornerOf(right, top)
    return (top and "TOP" or "BOTTOM") .. (right and "RIGHT" or "LEFT")
end

local function AnchorToCorner()
    local left, bottom, width, height = holder:GetRect()
    if not left then return nil end
    local right, top = OT:Side(true)
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

-- The list sits at the bottom of the frame when it is held by a bottom corner
function OT:ListBottom()
    local _, top = self:Side()
    return not top
end

local function OnFrameMoved(_, layoutName)
    local corner, x, y = AnchorToCorner()
    local store = GetLayoutStore(layoutName)
    if not (store and corner) then return end
    store.corner, store.x, store.y = corner, math_floor(x + 0.5), math_floor(y + 0.5)
    store.edgeJudged = true
    OT:RequestRender()
end

--------------------------------------------------
-- 4. FONTS AND LOOK
--------------------------------------------------
-- A string already showing exactly this font (not one still waiting for its file: ns.SetFont) and
-- shadow is left as it is, as every render passes here for every line. Answers true when it wrote.
local function ApplyFont(fontString, cfg, fallbackSize)
    cfg = cfg or C.NO_FONT
    local flags = cfg.flags
    if flags == "NONE" then flags = "" end
    flags = flags or ""
    local path, size = ns.GetFontPath(cfg.face or "Friz Quadrata TT"), cfg.size or fallbackSize or 12
    local shadow = cfg.enableShadow and true or false
    local shadowX, shadowY = shadow and (cfg.shadowX or 1) or 0, shadow and (cfg.shadowY or -1) or 0
    local shownPath, shownSize, shownFlags = fontString:GetFont()
    local wantPath, wantSize, wantFlags = ns.GetWantedFont(fontString)
    if shownPath == path and shownSize == size and shownFlags == flags
            and wantPath == path and wantSize == size and wantFlags == flags
            and fontString.ftShadow == shadow and fontString.ftShadowX == shadowX and fontString.ftShadowY == shadowY then
        return false
    end
    ns.SetFont(fontString, path, size, flags)
    ns.ApplyShadow(fontString, cfg)
    fontString.ftShadow, fontString.ftShadowX, fontString.ftShadowY = shadow, shadowX, shadowY
    return true
end

local function FontHeight(cfg, fallback)
    return (cfg and cfg.size or fallback or 12) + 2
end

local function GetBorderFile(db)
    local name = db and db.borderTexture
    if name == "None" then return nil end   -- Frame Border: None
    if not (name and LSM:IsValid("border", name)) then name = C.DEFAULT_BORDER end
    return LSM:Fetch("border", name)
end

-- the window's backdrop (frame: the tracker, or the settings preview's sample)
local function ApplyBackdrop(frame)
    local db = GetDb()
    local bg = LSM:Fetch("background", "Blizzard Dialog Background Dark") or "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"
    local edge = GetBorderFile(db)
    frame:SetBackdrop({ bgFile = bg, edgeFile = edge, tile = false, tileSize = 0,
        edgeSize = ns.BorderEdgeSize(edge, 16), insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    frame:SetBackdropColor(1, 1, 1, db and db.opacity or 0.6)
    local b = ns.BORDER_COLOR
    frame:SetBackdropBorderColor(b.r, b.g, b.b, b.a)
end

--------------------------------------------------
-- 5. QUESTS
-- Tracked quests under the log's zone headers: the current zone's groups first, the rest by their
-- nearest quest, quests by distance; completed quests sink to the bottom of their group.
--------------------------------------------------
-- reused on every pass (the distance check runs every few seconds)
local zoneNames, questBuf, groupRank, groupBest, groupOrder = {}, {}, {}, {}, {}
-- the quest log as last read; each watched quest's distance as the last sort saw it
local logBuf, sortIDs, sortDist = {}, {}, {}
local sortNew, sortRankOld, sortRankNew = {}, {}, {}   -- scratch for the distance check (OnSortTick)

local function AddZoneName(z)
    if z and z ~= "" then zoneNames[z] = true end
end

local function CurrentZoneNames()
    wipe(zoneNames)
    AddZoneName(GetRealZoneText())
    AddZoneName(GetZoneText())
    AddZoneName(GetSubZoneText())
end

local function Distance(questID)
    local distSq, onContinent = C_QuestLog.GetDistanceSqToQuest(questID)
    return (distSq and onContinent) and distSq or math_huge
end

-- One walk of the quest log (GetInfo makes a new table per entry) for everything that reads it next:
-- the entries in log order, the header's count and the number tracked. Read it again before each use
-- outside a render, as the log may have changed since.
local function ReadLog()
    wipe(logBuf)
    local count, tracked = 0, 0
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info then
            info.ftLogIndex = i
            if not info.isHeader and not info.isHidden then
                if not info.isTask and not info.isBounty then count = count + 1 end
                if info.questID and info.questID > 0 and C_QuestLog.GetQuestWatchType(info.questID) ~= nil then
                    info.ftWatched = true
                    tracked = tracked + 1
                end
            end
            logBuf[#logBuf + 1] = info
        end
    end
    state.logCount, state.logTracked = count, tracked
end

-- (after ReadLog)
local function QuestCount()
    local max = C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept() or nil
    return state.logCount, max
end

local function ByOrder(a, b)
    if a.ftRank ~= b.ftRank then return a.ftRank < b.ftRank end
    if a.ftDone ~= b.ftDone then return not a.ftDone end
    -- by level or progress: 0 for every quest in the other orders
    if a.ftLevel ~= b.ftLevel then return a.ftLevel < b.ftLevel end
    if a.ftDistance ~= b.ftDistance then return a.ftDistance < b.ftDistance end
    return a.ftIndex < b.ftIndex
end

-- By progress: the share of its objectives done, furthest along first
local function ProgressKey(questID)
    if C_QuestLog.IsComplete(questID) then return -1 end
    local objectives, sum = C_QuestLog.GetQuestObjectives(questID) or {}, 0
    for _, obj in ipairs(objectives) do
        if obj.type == "progressbar" and not obj.finished and GetQuestProgressBarPercent then
            local pct = GetQuestProgressBarPercent(questID)
            sum = sum + ((canaccessvalue(pct) and type(pct) == "number") and pct / 100 or 0)
        else
            sum = sum + ObjectiveProgress(obj)
        end
    end
    return #objectives > 0 and -(sum / #objectives) or 0
end

-- Blizzard's own timer panel is a child of its tracker, so it is parked with it
local function ReadTimers()
    wipe(questTimers)
    for _, t in ipairs(C_QuestLog.GetQuestTimers() or {}) do
        local id, seconds = t.questID, t.questTimer
        questTimers[id] = seconds
        -- the full time from the client; failing that, the most this session has seen
        local total = timerTotals[id] or C_QuestLog.GetTimeAllowed(id) or 0
        timerTotals[id] = math_max(total, seconds)
    end
end

local function TimerColor(questID, seconds)
    local total = timerTotals[questID]
    local quarter = total and total > 0 and math_floor(seconds / total * 4) + 1 or #C.TIMER
    return C.TIMER[math_max(1, math_min(#C.TIMER, quarter))]
end

local function TimerText(seconds)
    seconds = math_max(0, math_floor(seconds))
    if seconds <= 1 then return L["Time's up!"] end
    local h, m, s = math_floor(seconds / 3600), math_floor(seconds / 60) % 60, seconds % 60
    local clock = h > 0 and string_format("%d:%02d:%02d", h, m, s) or string_format("%d:%02d", m, s)
    return TEXT.timeLeft .. " " .. clock
end

-- Timer bars: a thin bar under each quest timer, pooled on the list
local timerBars, timerBarsUsed = {}, 0
function Build.TimerBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetMinMaxValues(0, 1)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.5)
    return bar
end

local function GetTimerBar(i)
    local bar = timerBars[i]
    if bar then return bar end
    bar = Build.TimerBar(content)
    timerBars[i] = bar
    return bar
end

local function FillTimerBar(bar, questID, seconds)
    local total = timerTotals[questID]
    bar:SetValue((total and total > 0) and math_max(0, math_min(1, seconds / total)) or 1)
    local c = TimerColor(questID, seconds)
    bar:SetStatusBarColor(c[1], c[2], c[3], 0.9)
end

-- Once a second while a timer is drawn; a timer that ended (turned in, failed) takes a redraw
local function UpdateTimers()
    ReadTimers()
    for questID, line in pairs(timerLines) do
        local seconds = questTimers[questID]
        if not seconds then OT:RequestRender() return end
        local text, color = TimerText(seconds), TimerColor(questID, seconds)
        line.text:SetText(text)
        SetColor(line.text, color)
        line.ftText, line.ftColor = text, color   -- what the line shows, for the next render (AddLine)
        if line.timerBar and line.timerBar:IsShown() then FillTimerBar(line.timerBar, questID, seconds) end
    end
end

-- (after ReadLog)
local function CollectQuests(db)
    CurrentZoneNames()
    ReadTimers()
    wipe(questBuf)
    local header
    local watched = 0
    for _, info in ipairs(logBuf) do
        if info.isHeader then
            header = info.title
        elseif info.ftWatched then
            local distance = db.sortByDistance and Distance(info.questID) or 0
            -- every watched quest, listed or not: one coming into its zone has moved nearer too
            if db.sortByDistance then
                watched = watched + 1
                sortIDs[watched], sortDist[watched] = info.questID, distance
            end
            local here = (header and zoneNames[header]) or C_QuestLog.IsOnMap(info.questID)
            -- a running timer stays listed outside its zone
            if here or not db.zoneOnly or questTimers[info.questID] then
                info.ftIndex = #questBuf + 1
                info.ftHeader = header or _G.OTHER or "Other"
                info.ftHere = here and true or false
                info.ftDone = db.completedLast and C_QuestLog.IsComplete(info.questID) or false
                info.ftDistance = distance
                info.ftLevel = (db.sortByLevel and (info.difficultyLevel or info.level))
                    or (db.sortByProgress and ProgressKey(info.questID)) or 0
                questBuf[#questBuf + 1] = info
            end
        end
    end
    state.sortCount = db.sortByDistance and watched or nil

    -- a group's place: current zone, then its nearest quest, then log order
    wipe(groupRank)
    wipe(groupBest)
    for _, q in ipairs(questBuf) do
        local best = groupBest[q.ftHeader]
        if not best then
            groupBest[q.ftHeader] = { distance = q.ftDistance, index = q.ftIndex, here = q.ftHere }
        else
            if q.ftDistance < best.distance then best.distance = q.ftDistance end
            if q.ftHere then best.here = true end
        end
    end
    wipe(groupOrder)
    for name in pairs(groupBest) do groupOrder[#groupOrder + 1] = name end
    local zoneFirst = db.zoneFirst
    table.sort(groupOrder, function(a, b)
        local ga, gb = groupBest[a], groupBest[b]
        if zoneFirst and ga.here ~= gb.here then return ga.here end
        if ga.distance ~= gb.distance then return ga.distance < gb.distance end
        return ga.index < gb.index
    end)
    for rank, name in ipairs(groupOrder) do groupRank[name] = rank end
    -- without zone headers a current-zone quest under another header still goes first; by level or
    -- progress, zones play no part
    for _, q in ipairs(questBuf) do
        if db.sortByLevel or db.sortByProgress then
            q.ftRank = 0
        else
            q.ftRank = (db.zoneHeaders or not db.zoneFirst) and groupRank[q.ftHeader] or (q.ftHere and 0 or 1)
        end
    end
    -- Pin to Top: pinned quests lead the list, in their own order
    local pinned = Char().pinned
    for _, q in ipairs(questBuf) do
        if pinned[q.questID] then q.ftRank = -1 end
    end
    table.sort(questBuf, ByOrder)
    -- in a fight with quest item buttons up, the list keeps the order it had when the fight began
    -- (the buttons cannot move then): quests already listed in place, new ones after them
    local frozen = state.frozenOrder
    if frozen then
        for i, q in ipairs(questBuf) do q.ftNow = i end
        table.sort(questBuf, function(a, b)
            local fa, fb = frozen[a.questID], frozen[b.questID]
            if fa and fb then return fa < fb end
            if fa or fb then return fa ~= nil end
            return a.ftNow < b.ftNow
        end)
    end
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

--------------------------------------------------
-- 6. CLICKS, MENU AND TOOLTIP
--------------------------------------------------
-- Wowhead Link: the quest's page on Wowhead's Forever site, selected for copying
ns.Dialogs = ns.Dialogs or {}
ns.Dialogs["FLAREUI_QUEST_LINK"] = {
    text = L["Wowhead link (Ctrl+C to copy)"],
    button1 = _G.CLOSE or L["Close"],
    hasEditBox = true,
    maxLetters = 0,
    editText = function(url) return url end,
    hideOnEscape = true,
}
-- Opening the log from here taints the gamepad bindings, and in combat it runs outside Blizzard's
-- secure click: both are refused with a message
local function CanOpenPanels()
    local refusal
    if ns.IsGamepadUI() then
        refusal = L["Open the quest log with your controller."]
    elseif InCombatLockdown() then
        refusal = L["The quest log can't be opened from the tracker in combat."]
    end
    if refusal and UIErrorsFrame then UIErrorsFrame:AddMessage(refusal, 1, 0.25, 0.25) end
    return not refusal
end

-- A map addon that finishes opening the map a moment later (OpenMap) can reset the quest panel to
-- the list after the details were shown: the first click then only opened the map. The details are
-- checked again on the next frames and shown again when another quest, or none, is up.
local OPEN_RECHECKS = { 0, 0.1, 0.3 }

local function OpenToDetails(questID)
    QuestMapFrame_OpenToQuestDetails(questID)
    for _, delay in ipairs(OPEN_RECHECKS) do
        C_Timer.After(delay, function()
            if InCombatLockdown() or not (WorldMapFrame and WorldMapFrame:IsShown()) then return end
            local shown = QuestMapFrame_GetDetailQuestID and QuestMapFrame_GetDetailQuestID()
            local detailsUp = QuestMapFrame.DetailsFrame and QuestMapFrame.DetailsFrame:IsShown()
            if shown ~= questID or not detailsUp then QuestMapFrame_OpenToQuestDetails(questID) end
        end)
    end
end

-- A finished auto-complete quest completes on the click, as on Blizzard's tracker
local function OpenQuest(questID)
    if not CanOpenPanels() then return end
    local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
    local info = logIndex and C_QuestLog.GetInfo(logIndex)
    if info and info.isAutoComplete and C_QuestLog.IsComplete(questID) then
        ShowQuestComplete(questID)
        if RemoveAutoQuestPopUp then RemoveAutoQuestPopUp(questID) end
    elseif QuestMapFrame_OpenToQuestDetails then
        OpenToDetails(questID)
    end
end

-- The world map on the quest's zone
local function ShowOnMap(questID)
    if not CanOpenPanels() then return end
    local mapID = GetQuestUiMapID(questID)
    if mapID and mapID ~= 0 then OpenWorldMap(mapID) elseif QuestMapFrame_OpenToQuestDetails then QuestMapFrame_OpenToQuestDetails(questID) end
end

local function LinkToChat(questID)
    local link = GetQuestLink(questID)
    if link and not ChatFrameUtil.InsertLink(link) then ChatFrameUtil.OpenChat(link) end
end

local function ToggleFocus(questID)
    local focused = C_SuperTrack.GetSuperTrackedQuestID() == questID
    C_SuperTrack.SetSuperTrackedQuestID(focused and 0 or questID)
end

-- Auto-Collapse Completed: a finished or failed quest with no timer folds until the player opens it
local function AutoCollapsed(questID)
    local db = GetDb()
    return db and db.collapseCompleted and not questTimers[questID]
        and (C_QuestLog.IsComplete(questID) or C_QuestLog.IsFailed(questID)) or false
end

-- collapsedQuests: true collapsed, false held open against the automatic rule, nil follows the rule
local function IsCollapsed(questID)
    local held = state.frozenCollapsed and state.frozenCollapsed[questID]
    if held ~= nil then return held end
    local choice = Char().collapsedQuests[questID]
    if choice == nil then return AutoCollapsed(questID) end
    return choice
end

local function SetCollapsed(questID, collapsed)
    if collapsed == AutoCollapsed(questID) then collapsed = nil end
    Char().collapsedQuests[questID] = collapsed
end

local function ToggleCollapsed(questID)
    SetCollapsed(questID, not IsCollapsed(questID))
    OT:RequestRender()
end

local function ShowQuestMenu(owner, questID)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(C_QuestLog.GetTitleForQuestID(questID) or "?")
        local focused = C_SuperTrack.GetSuperTrackedQuestID() == questID
        root:CreateButton(focused and TEXT.unfocus or TEXT.focus, function() ToggleFocus(questID) end)
        root:CreateButton(TEXT.openLog, function() OpenQuest(questID) end)
        root:CreateButton(TEXT.showMap, function() ShowOnMap(questID) end)
        root:CreateButton(TEXT.linkChat, function() LinkToChat(questID) end)
        local share = root:CreateButton(TEXT.share, function()
            QuestUtil.ShareQuest(questID)
        end)
        share:SetEnabled(IsInGroup() and C_QuestLog.IsPushableQuest(questID))
        root:CreateButton(IsCollapsed(questID) and L["Expand"] or L["Collapse"], function() ToggleCollapsed(questID) end)
        local pins = Char().pinned
        root:CreateButton(pins[questID] and L["Unpin"] or L["Pin to Top"], function()
            pins[questID] = (not pins[questID]) or nil
            OT:RequestRender()
        end)
        root:CreateButton(L["Wowhead Link"], function()
            ns.ShowDialog("FLAREUI_QUEST_LINK", nil, ("https://www.wowhead.com/forever/quest=%d/"):format(questID))
        end)
        if QuestUtil.CanRemoveQuestWatch() then
            root:CreateButton(TEXT.untrack, function() C_QuestLog.RemoveQuestWatch(questID) end)
        end
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

-- The quest's rewards, as the quest log lists them (when it shows them): XP, money, items, a choice
local function AddRewards(questID)
    if C_QuestLog.ShouldShowQuestRewards and not C_QuestLog.ShouldShowQuestRewards(questID) then return end
    local xp = GetQuestLogRewardXP and GetQuestLogRewardXP(questID) or 0
    local money = GetQuestLogRewardMoney and GetQuestLogRewardMoney(questID) or 0
    local items = GetNumQuestLogRewards and GetNumQuestLogRewards(questID) or 0
    local choices = GetNumQuestLogChoices and GetNumQuestLogChoices(questID, true) or 0
    if xp <= 0 and money <= 0 and items == 0 and choices == 0 then return false end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(_G.REWARDS or L["Rewards"], 1, 0.82, 0)
    if xp > 0 then GameTooltip:AddLine(L["%s XP"]:format(BreakUpLargeNumbers(xp)), 1, 1, 1) end
    if money > 0 and GetMoneyString then GameTooltip:AddLine(GetMoneyString(money), 1, 1, 1) end
    local missing = false
    local function Item(name, texture, count, quality)
        if not name then missing = true return end
        local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
        local r, g, b = 1, 1, 1
        if color then r, g, b = color.r, color.g, color.b end
        local text = (texture and ("|T" .. texture .. ":14:14|t ") or "") .. name
        if count and count > 1 then text = text .. " x" .. count end
        GameTooltip:AddLine(text, r, g, b)
    end
    for i = 1, items do
        local name, texture, count, quality = GetQuestLogRewardInfo(i, questID)
        Item(name, texture, count, quality)
    end
    if choices > 0 then
        GameTooltip:AddLine(_G.REWARD_CHOOSE or L["Choose one:"], 0.8, 0.8, 0.8)
        for i = 1, choices do
            local name, texture, count, quality = GetQuestLogChoiceInfo(i, questID)
            Item(name, texture, count, quality)
        end
    end
    return missing
end

local function QuestTooltip(line, retry)
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
    -- an item the client hasn't loaded yet: drawn once more a moment later
    if AddRewards(questID) and not retry then
        C_Timer.After(0.3, function()
            if GameTooltip:IsOwned(line) and line.questID == questID and line:IsMouseOver() then QuestTooltip(line, true) end
        end)
    end
    AddPartyProgress(questID)
    GameTooltip:Show()
end

-- Shift-click on a zone heading: all its quests collapse, or open if they already are
local function ToggleZoneQuests(zone)
    local db = GetDb()
    local allCollapsed = true
    ReadLog()
    local quests = CollectQuests(db)
    for _, q in ipairs(quests) do
        if q.ftHeader == zone and not IsCollapsed(q.questID) then allCollapsed = false end
    end
    for _, q in ipairs(quests) do
        if q.ftHeader == zone then SetCollapsed(q.questID, not allCollapsed) end
    end
    OT:RequestRender()
end

local function OnLineClick(self, button)
    if state.editMode then return end
    -- a quest offered from an item or an area, or one that completes on a click
    if self.popupQuestID then
        if CanOpenPanels() then
            if self.popupType == "OFFER" then ShowQuestOffer(self.popupQuestID) else ShowQuestComplete(self.popupQuestID) end
            if RemoveAutoQuestPopUp then RemoveAutoQuestPopUp(self.popupQuestID) end
            OT:RequestRender()
        end
        return
    end
    if self.zone then
        if IsShiftKeyDown() and button == "LeftButton" then
            ToggleZoneQuests(self.zone)
            return
        end
        local z = Char().collapsedZones
        z[self.zone] = not z[self.zone] or nil
        OT:RequestRender()
        return
    end
    if self.recipeID then
        -- the Gamepad UI: no menu and no professions window opened from here (see quests below)
        if ns.IsGamepadUI() and not (button ~= "RightButton" and IsShiftKeyDown()) then return end
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
        -- in the Gamepad UI a menu opened from addon code hangs the client (as on the chat tabs)
        if ns.IsGamepadUI() then return end
        GameTooltip:Hide()
        ShowQuestMenu(self, questID)
    elseif IsShiftKeyDown() then
        -- while typing in chat it links the quest; otherwise it untracks it (the list only holds tracked quests)
        local link = GetQuestLink(questID)
        if link and ChatFrameUtil.GetActiveWindow() then
            ChatFrameUtil.InsertLink(link)
        elseif QuestUtil.CanRemoveQuestWatch() then
            C_QuestLog.RemoveQuestWatch(questID)
        end
    elseif IsControlKeyDown() then
        ToggleFocus(questID)
    else
        OpenQuest(questID)
    end
end

--------------------------------------------------
-- 7. LINES (one pooled button per text line)
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

function Build.Line(parent)
    local line = CreateFrame("Button", nil, parent)
    line.text = line:CreateFontString(nil, "OVERLAY")
    line.text:SetJustifyH("LEFT")
    line.text:SetPoint("TOPLEFT", line, "TOPLEFT")
    return line
end

-- A line's font, wrap, text, colour and width. A line remembers what it was given last (ft*), and
-- only what differs is written: most lines read the same from one render to the next. Answers the
-- line's height.
function Build.LineLook(line, text, kind, cfg, color, w, wrap)
    -- a new font: text and colour are written again too
    if ApplyFont(line.text, cfg, kind == "objective" and 11 or 12) then line.ftText, line.ftColor = false, false end
    if line.ftWrap ~= wrap then
        line.ftWrap = wrap
        line.text:SetWordWrap(wrap)
        line.text:SetMaxLines(wrap and 0 or 1)
    end
    if line.ftText ~= text then
        line.ftText = text
        line.text:SetText(text)
    end
    if line.ftColor ~= color then
        line.ftColor = color
        SetColor(line.text, color)
    end
    if line.ftWidth ~= w then
        line.ftWidth = w
        line:SetWidth(w)
        line.text:SetWidth(w)
    end
    local h = math_max(FontHeight(cfg, 12), math_floor(line.text:GetStringHeight() + 0.5))
    if line.ftHeight ~= h then
        line.ftHeight = h
        line:SetHeight(h)
        line.text:SetHeight(h)
    end
    return h
end

local function GetLine(i)
    local line = lines[i]
    if line then return line end
    line = Build.Line(content)
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

-- Quest animations. Only for a reason: a quest accepted or turned in, an objective finished. Data
-- arriving at login just appears. Own frames, so they run in combat; the list clips what leaves it.

-- Drawn dx, dy px off and at fromAlpha, easing back to rest (visual only, the line never moves)
local function MoveLine(line, dx, dy, fromAlpha)
    local g = line.moveAnim
    if not g then
        g = line:CreateAnimationGroup()
        g.hold = g:CreateAnimation("Alpha")
        g.hold:SetDuration(0)
        g.hold:SetOrder(1)
        g.jump = g:CreateAnimation("Translation")
        g.jump:SetDuration(0)
        g.jump:SetOrder(1)
        g.move = g:CreateAnimation("Translation")
        g.move:SetDuration(C.MOVE_TIME)
        g.move:SetOrder(2)
        g.move:SetSmoothing("OUT")
        g.fade = g:CreateAnimation("Alpha")
        g.fade:SetToAlpha(1)
        g.fade:SetDuration(C.MOVE_TIME)
        g.fade:SetOrder(2)
        line.moveAnim = g
    end
    g:Stop()
    g.hold:SetFromAlpha(fromAlpha)
    g.hold:SetToAlpha(fromAlpha)
    g.fade:SetFromAlpha(fromAlpha)
    g.jump:SetOffset(dx, dy)
    g.move:SetOffset(-dx, -dy)
    g:Play()
end

-- Slides away and stays clear until the line is reused
local function LeaveLine(line, dx)
    local g = line.leaveAnim
    if not g then
        g = line:CreateAnimationGroup()
        g:SetToFinalAlpha(true)
        g.move = g:CreateAnimation("Translation")
        g.move:SetDuration(C.LEAVE_TIME)
        g.move:SetSmoothing("IN")
        local fade = g:CreateAnimation("Alpha")
        fade:SetFromAlpha(1)
        fade:SetToAlpha(0)
        fade:SetDuration(C.LEAVE_TIME)
        line.leaveAnim = g
    end
    if line.moveAnim then line.moveAnim:Stop() end
    g:Stop()
    g.move:SetOffset(dx, 0)
    g:Play()
end

-- A soft band of light that crosses the line's text once
local function PlaySheen(line)
    local band = line.sheen
    if not band then
        band = CreateFrame("Frame", nil, line)
        band:SetWidth(C.SHEEN_WIDTH)
        band:SetPoint("TOPLEFT", line, "TOPLEFT", -C.SHEEN_WIDTH, 0)
        band:SetPoint("BOTTOMLEFT", line, "BOTTOMLEFT", -C.SHEEN_WIDTH, 0)
        local c = C.TITLE_DONE
        local clear, lit = CreateColor(c[1], c[2], c[3], 0), CreateColor(c[1], c[2], c[3], 0.55)
        local left = band:CreateTexture(nil, "OVERLAY")
        left:SetColorTexture(1, 1, 1)
        left:SetBlendMode("ADD")
        left:SetPoint("TOPLEFT")
        left:SetPoint("BOTTOMRIGHT", band, "BOTTOM")
        left:SetGradient("HORIZONTAL", clear, lit)
        local right = band:CreateTexture(nil, "OVERLAY")
        right:SetColorTexture(1, 1, 1)
        right:SetBlendMode("ADD")
        right:SetPoint("TOPLEFT", band, "TOP")
        right:SetPoint("BOTTOMRIGHT")
        right:SetGradient("HORIZONTAL", lit, clear)
        local g = band:CreateAnimationGroup()
        g.move = g:CreateAnimation("Translation")
        g.move:SetDuration(C.SHEEN_TIME)
        g.move:SetSmoothing("IN_OUT")
        g:SetScript("OnFinished", function() band:Hide() end)
        band.anim = g
        band:Hide()
        line.sheen = band
    end
    band.anim:Stop()
    band.anim.move:SetOffset(line.text:GetStringWidth() + C.SHEEN_WIDTH, 0)
    band:Show()
    band.anim:Play()
end

-- Which way a line leaves or arrives: the side of the screen the tracker sits on
local function SlideDistance()
    return OT:Side() and C.SLIDE or -C.SLIDE
end

-- The focus and play buttons, left of a title; pointing at one counts as pointing at the quest
function Build.LineButton(line)
    local b = CreateFrame("Button", nil, line)
    b:SetSize(C.BUTTON_SIZE, C.BUTTON_SIZE)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    return b
end

local function LineButton(line, key)
    local b = line[key]
    if b then return b end
    b = Build.LineButton(line)
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnEnter", function(self) local p = self:GetParent(); p:GetScript("OnEnter")(p) end)
    b:SetScript("OnLeave", function(self) local p = self:GetParent(); p:GetScript("OnLeave")(p) end)
    line[key] = b
    return b
end

-- Voice lines from the Spoken addon's quest part, when it is installed, switched on and has this quest
local function VoiceOverReady()
    local spoken, voice = _G.Spoken, _G.VoiceOver
    return spoken and voice and voice.DataModules and voice.QuestOverlayUI and voice.Player
        and spoken.IsPartOn and spoken:IsPartOn("quests")
end

local function HasVoice(questID)
    local voice = _G.VoiceOver
    if not voice then return false end
    local ok, sound = pcall(voice.DataModules.PrepareSound, voice.DataModules,
        { event = voice.Enums.SoundEvent.QuestAccept, questID = questID })
    return ok and sound
end

local function VoiceQueued(questID)
    local voice = _G.VoiceOver
    if not (voice and questID) then return nil end
    local ok, queued = pcall(voice.QuestOverlayUI.QueuedLine, voice.QuestOverlayUI, questID)
    return ok and queued or nil
end

local function PaintPlayButton(b)
    b.icon:SetTexture(VoiceQueued(b.questID) and "Interface\\Common\\VoiceChat-Muted" or "Interface\\Common\\VoiceChat-Speaker")
end

local function TogglePlay(self)
    local voice, questID = _G.VoiceOver, self.questID
    -- the previews' buttons do nothing
    if state.editMode or not (questID and VoiceOverReady() and HasVoice(questID)) then return end
    local queued = VoiceQueued(questID)
    if queued then
        voice.Player:Remove(queued)
    else
        local enums, data = voice.Enums, voice.DataModules
        local giverType, giverID = data:GetQuestLogQuestGiverTypeAndID(questID)
        voice.Player:PlayNow({
            event = enums.SoundEvent.QuestAccept,
            questID = questID,
            name = giverID and data:GetObjectName(giverType, giverID) or "Unknown Name",
            title = C_QuestLog.GetTitleForQuestID(questID) or "",
            unitGUID = giverID and enums.GUID:CanHaveID(giverType) and voice.Utils:MakeGUID(giverType, giverID) or nil,
            unitIsObjectOrItem = giverID ~= nil and not enums.GUID:IsCreature(giverType),
            origin = "FlareUI Quest Tracker",
        })
    end
    PaintPlayButton(self)
end

--------------------------------------------------
-- 8. QUEST ITEM BUTTONS
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
    b:SetAlpha(OT.fadeAlpha or 1)
    itemButtons[i] = b
    return b
end

local function UpdateItemRanges()
    for _, b in ipairs(itemButtons) do
        if b:IsShown() and b.logIndex then
            -- 0 = out of range, 1 = in range, nil = no range for this item
            local range = IsQuestLogSpecialItemInRange(b.logIndex)
            local out = canaccessvalue(range) and range == 0
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
            if canaccessallvalues(start, duration, enable) and start then CooldownFrame_Set(b.cooldown, start, duration, enable) end
        end
    end
end

-- Minimized or hidden in combat the buttons cannot hide (they are protected) and stay where they are,
-- visible and working: made invisible, a click on the empty spot would still use the item. They go
-- once the fight ends. (Minimizing at the start of a fight runs before lockdown and hides them.)
function OT:UpdateItemButtons()
    local showing = holder and holder:IsVisible() and scroll:IsShown()
    if InCombatLockdown() then
        state.itemsDirty = true
        return
    end
    state.itemsDirty = false
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
-- 9. RENDER
--------------------------------------------------
-- Sample quests, in Edit Mode while nothing is tracked; one has a sample item button
local PREVIEW = {
    { zone = true, text = "Elwynn Forest" },
    { level = 7, title = "Kobold Camp Cleanup", timer = 285, objectives = { { text = "6/10 Kobold Vermin slain" } } },
    { level = 8, title = "Wolves Across the Border", focus = true, objectives = { { text = "4/8 Tough Wolf Meat" } },
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

-- the quest's own difficulty, as the quest log colours it; the sample quests have only a level
function Build.DifficultyColor(level, questID)
    if questID and HaveQuestData(questID) then
        return GetDifficultyColor(C_PlayerInfo.GetContentDifficultyQuestForPlayer(questID))
    end
    return GetQuestDifficultyColor(level)
end

-- Colour Names by Difficulty: the name in its level's colour, unless complete or focused (one
-- table per colour, so a line keeps its colour between renders)
function Build.TitleColor(db, level, questID, focus, done)
    if focus then return C.TITLE_FOCUS end
    if done then return C.TITLE_DONE end
    if not (db.colorNames and level) then return C.TITLE end
    local c = Build.DifficultyColor(level, questID)
    local key = string_format("%.3f %.3f %.3f", c.r, c.g, c.b)
    state.difficultyColors = state.difficultyColors or {}
    local color = state.difficultyColors[key]
    if not color then
        color = { c.r, c.g, c.b }
        state.difficultyColors[key] = color
    end
    return color
end

function Build.TitleText(db, level, tags, title, collapsed, questID)
    local prefix = ""
    if level then
        local c = Build.DifficultyColor(level, questID)
        local shownLevel = db.hideLevel and "" or level
        local shownTags = db.showTags and tags or ""
        if shownLevel == "" then shownTags = shownTags:gsub("^ +", "") end
        if shownLevel ~= "" or shownTags ~= "" then
            prefix = string_format("|cff%02x%02x%02x", Byte(c.r), Byte(c.g), Byte(c.b)) .. "[" .. shownLevel .. shownTags .. "]|r "
        end
    end
    return prefix .. title .. (collapsed and ("  " .. ColorCode(C.DIM) .. "+|r") or "")
end

-- The header's title (with the count), the zone switch and the minimize button, placed
function Build.LayoutHeader(head, db, count, max, minimized)
    local title = TEXT.quests
    if db.showCount then title = title .. "  " .. ColorCode(C.DIM) .. (max and (count .. "/" .. max) or count) .. "|r" end
    head.title:SetText(title)
    head.zone.text:SetText(db.zoneOnly and L["Zone"] or L["All"])
    head.zone:SetSize(head.zone.text:GetStringWidth() + 6, C.HEADER - 6)

    -- title on the left; the zone switch and the minimize button on the right
    local button = head.minimize
    button:ClearAllPoints()
    head.title:ClearAllPoints()
    head.zone:ClearAllPoints()
    button:SetPoint("RIGHT", head, "RIGHT", 0, 0)
    head.zone:SetPoint("RIGHT", button, "LEFT", -6, 0)
    head.title:SetPoint("LEFT", head, "LEFT", C.PAD - C.HEADER_INSET, 0)
    button:SetPlus(minimized)
end

function OT:Render()
    state.pending = false
    local db = GetDb()
    if not (db and holder) then return end
    local char = Char()
    local minimized = char.minimized and not state.editMode
    local questGap = db.questGap or C.QUEST_GAP
    local inScenario = C_Scenario and C_Scenario.GetStepInfo
        and ((C_Scenario.IsInScenario and C_Scenario.IsInScenario()) or select(2, IsInInstance()) == "scenario")
    state.watchMoney = false
    wipe(state.sheens)

    -- header
    ReadLog()   -- the one walk of the quest log this render reads
    local count, max = QuestCount()
    Build.LayoutHeader(header, db, count, max, minimized)

    -- content
    local n, y = 0, 0
    local lastBottom = 0   -- the bottom of the last line drawn
    local width = (db.width or C.WIDTH) - C.PAD * 2
    wipe(titleLines)
    wipe(timerLines)
    for _, bar in ipairs(timerBars) do bar:Hide() end
    timerBarsUsed = 0
    local fonts = state.fonts
    fonts.header, fonts.title, fonts.objective = db.headerFont, db.titleFont, db.objectiveFont
    local wrap = db.wrapText ~= false

    -- (what a pooled line was given last is kept: Build.LineLook)
    local function AddLine(text, kind, color, indent)
        n = n + 1
        local line = GetLine(n)
        local h = Build.LineLook(line, text, kind, fonts[kind], color, width - (indent or 0), wrap)
        line:ClearAllPoints()
        line.ftY = y
        -- the mouse area reaches the band's edges and the gap to the next line
        line.ftX = C.PAD + (indent or 0)
        if line.ftInset ~= line.ftX then
            line.ftInset = line.ftX
            line:SetHitRectInsets(-(C.PAD + (indent or 0) - 4), -(C.PAD - 4), -1, -(C.LINE_GAP - 1))
        end
        line:SetPoint("TOPLEFT", content, "TOPLEFT", line.ftX, y)
        line.questID, line.zone, line.recipeID, line.recipeName, line.logIndex = nil, nil, nil, nil, nil
        line.group, line.sampleItem = nil, nil
        line.popupQuestID, line.popupType, line.timerBar = nil, nil, nil
        if line.focusButton then line.focusButton:Hide() end
        if line.playButton then line.playButton:Hide() end
        if line.leaving then
            line.leaving = nil
            line.leaveAnim:Stop()
            line:SetAlpha(1)
        end
        line.kind = kind
        line:Show()
        lastBottom = y - h
        y = y - h - C.LINE_GAP
        return line
    end

    local function TitleColor(level, questID, focus, done) return Build.TitleColor(db, level, questID, focus, done) end
    local function TitleText(level, tags, title, collapsed, questID)
        return Build.TitleText(db, level, tags, title, collapsed, questID)
    end

    -- What a complete quest says: click to finish, its own closing text, where to go, or "ready"
    local function CompleteText(q)
        if q.isAutoComplete then return TEXT.clickComplete end
        local text = GetQuestLogCompletionText(q.ftLogIndex)
        if text and text ~= "" then return (text:gsub("[\r\n]+", " ")) end
        local waypoint = C_QuestLog.GetNextWaypointText(q.questID)
        if waypoint and waypoint ~= "" then return waypoint end
        return TEXT.ready
    end

    -- The running scenario's stage and objectives, which live in the parked tracker
    local function AddScenario()
        local name = C_Scenario.GetInfo()
        local stage, _, numCriteria = C_Scenario.GetStepInfo()
        local title = (canaccessvalue(name) and name) or (canaccessvalue(stage) and stage) or nil
        if not title or title == "" then return false end
        local collapsed = char.collapsedZones[title]
        AddLine(title, "header", C.ZONE).zone = title
        if collapsed then return true end
        y = y - C.ZONE_GAP
        if canaccessvalue(stage) and stage and stage ~= "" and stage ~= title then AddLine(stage, "title", C.TITLE) end
        -- Blizzard's rules: criteria only when the scenario shows them; a count in front unless the
        -- text carries its own (formatted) or the step fills a bar (weighted progress, shown here as n%)
        local showCriteria = not (C_Scenario.ShouldShowCriteria and C_Scenario.ShouldShowCriteria() == false)
        for i = 1, (showCriteria and canaccessvalue(numCriteria) and numCriteria) or 0 do
            local info = C_ScenarioInfo.GetCriteriaInfo(i)
            if info and canaccessallvalues(info.description, info.quantity, info.totalQuantity, info.completed) and info.description then
                local text = info.description
                local total = info.totalQuantity or 0
                local weighted = canaccessvalue(info.isWeightedProgress) and info.isWeightedProgress
                local formatted = canaccessvalue(info.isFormatted) and info.isFormatted
                if weighted then
                    if not info.completed then text = string_format("%s (%d%%)", text, info.quantity or 0) end
                elseif not formatted and total > 1 then
                    text = string_format("%d/%d %s", info.quantity or 0, total, text)
                end
                AddLine(text, "objective", info.completed and C.OBJECTIVE_DONE or C.OBJECTIVE, C.INDENT)
            end
        end
        y = y - questGap
        return true
    end

    -- Room left of the titles for their buttons; the objectives keep their step in from the title.
    -- While previewing, every quest shows the voice button, whether it has a voice line or not
    local previewing = state.editMode or state.preview
    local voiceReady = db.playButtons and VoiceOverReady()
    local showPlay = db.playButtons and (previewing or voiceReady)
    local titleRoom = (db.focusButtons and C.BUTTON_ROOM or 0) + (showPlay and C.BUTTON_ROOM or 0)
    local objectiveIndent = C.INDENT + titleRoom

    local function AddTitleButtons(line, questID, isFocused)
        local x = -3
        if db.focusButtons then
            local b = LineButton(line, "focusButton")
            b.questID = questID
            b.icon:SetTexture(isFocused and "Interface\\Common\\Indicator-Yellow" or "Interface\\Common\\Indicator-Gray")
            b:SetScript("OnClick", function(self)
                if self.questID and not state.editMode then ToggleFocus(self.questID) end
            end)
            b:ClearAllPoints()
            b:SetPoint("TOPRIGHT", line, "TOPLEFT", x, 0)
            b:Show()
            x = x - C.BUTTON_ROOM
        end
        if showPlay and (previewing or HasVoice(questID)) then
            local b = LineButton(line, "playButton")
            b.questID = questID
            PaintPlayButton(b)
            b:SetScript("OnClick", TogglePlay)
            b:ClearAllPoints()
            b:SetPoint("TOPRIGHT", line, "TOPLEFT", x, 0)
            b:Show()
        end
    end

    local empty = true
    if not minimized then
        if inScenario and not state.editMode and AddScenario() then empty = false end
        -- Quests Blizzard offers from an item or an area, and ones that complete on a click: Blizzard
        -- shows these in its own tracker, which is parked, and closes the quest window for an offer
        if not state.editMode and GetNumAutoQuestPopUps and GetAutoQuestPopUp then
            for i = 1, GetNumAutoQuestPopUps() do
                local questID, popUpType = GetAutoQuestPopUp(i)
                local bounty = questID and C_QuestLog.IsQuestBounty and C_QuestLog.IsQuestBounty(questID)
                local title = questID and not bounty and C_QuestLog.GetTitleForQuestID(questID)
                if title and title ~= "" then
                    local offer = popUpType == "OFFER"
                    local head = AddLine("! " .. title, "title", C.TITLE_FOCUS, titleRoom)
                    head.popupQuestID, head.popupType = questID, popUpType
                    local hint = offer and (_G.QUEST_WATCH_POPUP_CLICK_TO_VIEW or "Click to view quest")
                        or (_G.QUEST_WATCH_POPUP_CLICK_TO_COMPLETE or "Click to complete quest")
                    local row = AddLine(hint, "objective", C.OBJECTIVE, objectiveIndent)
                    row.popupQuestID, row.popupType = questID, popUpType
                    y = y - questGap
                    empty = false
                end
            end
        end
        if (state.editMode or state.preview) and state.logTracked == 0 then
            wipe(state.order)
            for _, s in ipairs(PREVIEW) do
                if s.zone then
                    if db.zoneHeaders then
                        if n > 0 then y = y - C.GROUP_GAP end
                        AddLine(s.text, "header", C.ZONE)
                        y = y - C.ZONE_GAP
                    end
                else
                    local color = TitleColor(s.level, nil, s.focus, s.done)
                    local line = AddLine(TitleText(s.level, s.tags or "", s.title), "title", color, titleRoom)
                    AddTitleButtons(line, nil, s.focus)
                    if s.item then
                        line.sampleItem = s.item
                        titleLines[#titleLines + 1] = line
                    end
                    if s.timer then AddLine(TimerText(s.timer), "objective", C.TIMER[#C.TIMER], objectiveIndent) end
                    for _, o in ipairs(s.objectives) do
                        if not (db.hideFinished and o.finished) then
                            AddLine(o.text, "objective", o.finished and C.OBJECTIVE_DONE or C.OBJECTIVE, objectiveIndent)
                        end
                    end
                    y = y - questGap
                end
            end
            empty = false
        else
            local quests = CollectQuests(db)
            local focused = C_SuperTrack.GetSuperTrackedQuestID()
            local lastHeader
            local zoneCounts = state.zoneCounts
            wipe(zoneCounts)
            for _, q in ipairs(quests) do zoneCounts[q.ftHeader] = (zoneCounts[q.ftHeader] or 0) + 1 end
            -- zone headings, except by level (the zones are mixed there)
            local headings = db.zoneHeaders and not db.sortByLevel and not db.sortByProgress
            local order = state.order
            wipe(order)
            for _, q in ipairs(quests) do
                empty = false
                order[#order + 1] = q.questID
                local zoneCollapsed = headings and char.collapsedZones[q.ftHeader]
                if headings and q.ftHeader ~= lastHeader then
                    lastHeader = q.ftHeader
                    if n > 0 then y = y - C.GROUP_GAP end
                    local text = zoneCollapsed and string_format("%s  %s(%d)|r", q.ftHeader, ColorCode(C.DIM), zoneCounts[q.ftHeader]) or q.ftHeader
                    AddLine(text, "header", C.ZONE).zone = q.ftHeader
                    if not zoneCollapsed then y = y - C.ZONE_GAP end
                end
                if not zoneCollapsed then
                    local collapsed = IsCollapsed(q.questID)
                    local complete = C_QuestLog.IsComplete(q.questID)
                    local color = TitleColor(q.difficultyLevel or q.level, q.questID, q.questID == focused, complete)
                    local line = AddLine(TitleText(q.difficultyLevel or q.level, db.showTags and QuestTags(q) or "", q.title or "?", collapsed, q.questID), "title", color, titleRoom)
                    line.questID, line.logIndex = q.questID, q.ftLogIndex
                    titleLines[#titleLines + 1] = line
                    AddTitleButtons(line, q.questID, q.questID == focused)
                    -- what this quest looked like last time, to tell what has just finished
                    local seen = state.seen[q.questID]
                    local now = { complete = complete }
                    -- a running timer shows on a collapsed quest too
                    local seconds = questTimers[q.questID]
                    if seconds then
                        local timer = AddLine(TimerText(seconds), "objective", TimerColor(q.questID, seconds), objectiveIndent)
                        timer.questID = q.questID
                        timerLines[q.questID] = timer
                        -- a thin bar under it, emptying as the time runs out. Held by the line, so it
                        -- follows the list when it sits at the bottom of the frame (drop, below)
                        timerBarsUsed = timerBarsUsed + 1
                        local bar = GetTimerBar(timerBarsUsed)
                        bar:ClearAllPoints()
                        bar:SetPoint("TOPLEFT", timer, "BOTTOMLEFT", 0, -1)
                        bar:SetSize(math_max(20, width - objectiveIndent - 4), 3)
                        FillTimerBar(bar, q.questID, seconds)
                        bar:Show()
                        timer.timerBar = bar
                        lastBottom = lastBottom - 5
                        y = y - 5
                    end
                    if not collapsed then
                        if complete then
                            local ready = AddLine(CompleteText(q), "objective", C.TITLE_DONE, objectiveIndent)
                            ready.questID = q.questID
                            if seen and seen.complete == false then state.sheens[#state.sheens + 1] = ready end
                        elseif C_QuestLog.IsFailed(q.questID) then
                            AddLine(TEXT.failed, "objective", C.URGENT, objectiveIndent).questID = q.questID
                        else
                            -- the next step on the way, for the focused quest
                            local waypoint = q.questID == focused and C_QuestLog.GetNextWaypointText(q.questID)
                            if waypoint and waypoint ~= "" then
                                AddLine(TEXT.waypoint:format(waypoint), "objective", C.OBJECTIVE, objectiveIndent).questID = q.questID
                            end
                            for i, obj in ipairs(C_QuestLog.GetQuestObjectives(q.questID) or {}) do
                                now[i] = obj.finished and true or false
                                if obj.text and obj.text ~= "" and not (db.hideFinished and obj.finished) then
                                    -- a progress-bar objective has no count in its text: Blizzard draws a bar
                                    local text = obj.text
                                    if obj.type == "progressbar" and not obj.finished and GetQuestProgressBarPercent then
                                        local pct = GetQuestProgressBarPercent(q.questID)
                                        if canaccessvalue(pct) and type(pct) == "number" then text = string_format("%s (%d%%)", text, pct) end
                                    end
                                    local row = AddLine(text, "objective", obj.finished and C.OBJECTIVE_DONE or C.OBJECTIVE, objectiveIndent)
                                    row.questID = q.questID
                                    if obj.finished and seen and seen[i] == false then state.sheens[#state.sheens + 1] = row end
                                end
                            end
                            -- gold the quest needs, while it is short
                            local needed = C_QuestLog.GetRequiredMoney(q.questID) or 0
                            if needed > 0 then
                                state.watchMoney = true
                                local have = GetMoney()
                                if needed > have then
                                    AddLine(GetMoneyString(have) .. " / " .. GetMoneyString(needed), "objective", C.OBJECTIVE, objectiveIndent).questID = q.questID
                                end
                            end
                        end
                        state.seen[q.questID] = now
                    else
                        state.seen[q.questID] = nil   -- nothing is lit for what finished out of sight
                    end
                    y = y - questGap
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
                                local r = AddLine(text, "objective", have >= slot.quantityRequired and C.OBJECTIVE_DONE or C.OBJECTIVE, C.INDENT)
                                r.recipeID, r.recipeName = recipeID, name
                            end
                        end
                        y = y - questGap
                    end
                end
            end

            -- nothing to list: say why, or the bare header looks minimized and its button does nothing
            if empty then
                local hint = (state.logTracked > 0 and db.zoneOnly)
                    and L["No tracked quests in this zone. Click Zone to show them all."]
                    or L["No quests tracked. Shift-click a quest in your quest log to track it."]
                AddLine(hint, "objective", C.DIM)
            end
        end
    end
    for i = n + 1, #lines do lines[i]:Hide() end
    local timing = next(timerLines) ~= nil
    if timing and not state.timerTicker then
        state.timerTicker = C_Timer.NewTicker(1, UpdateTimers)
    elseif not timing and state.timerTicker then
        state.timerTicker:Cancel()
        state.timerTicker = nil
    end
    wipe(state.groups)
    local underMouse
    for i = 1, n do
        local line = lines[i]
        local key = (line.questID and ("q" .. line.questID)) or (line.recipeID and ("r" .. line.recipeID))
            or (line.zone and ("z" .. i))
        line.group = key
        if key then
            -- (its buttons stand outside the line)
            local focusB, playB = line.focusButton, line.playButton
            if line:IsMouseOver() or (focusB and focusB:IsShown() and focusB:IsMouseOver())
                    or (playB and playB:IsShown() and playB:IsMouseOver()) then
                underMouse = key
            end
            local g = state.groups[key]
            if not g then g = { first = line }; state.groups[key] = g end
            g.last = line
        end
    end
    -- the quest pointed at keeps its band and tooltip through a redraw (leaving it clears them); once
    -- it is gone or has moved from under the mouse they go now, as no line will clear them
    if state.shownGroup and state.shownGroup == underMouse then
        self:HighlightGroup(state.shownGroup)
    else
        if state.shownGroup then GameTooltip:Hide() end
        state.shownGroup = nil
        self:HighlightGroup(nil)
    end
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
    -- on a bottom corner the lines sit at the bottom of the room they have
    local drop = (self:ListBottom() and listHeight > contentHeight) and (listHeight - contentHeight) or 0
    if drop > 0 then content:SetHeight(listHeight) end
    for i = 1, n do
        local line = lines[i]
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", content, "TOPLEFT", line.ftX, line.ftY - drop)
    end
    self:AnimateLayout(n, drop)
    scroll:SetHeight(math_max(1, listHeight))
    -- minimized, the header keeps the same 3 px below it as above it
    holder:SetHeight(C.HEADER + (showList and (C.LIST_TOP + listHeight + C.LIST_BOTTOM) or 3))
    state.contentHeight, state.listHeight = contentHeight, listHeight
    -- a saved corner without edgeJudged was picked by the centre: judged once by the edges, while open
    if not minimized and db.anchor ~= "TOP" and db.anchor ~= "BOTTOM" then
        local store = GetLayoutStore()
        if store and store.corner and not store.edgeJudged then
            store.edgeJudged = true
            OnFrameMoved(nil, LEM:GetActiveLayoutName())
        end
    end
    self:UpdateScrollBar()

    -- Minimize Style "button": minimized, only a lone "+" shows at the anchored corner
    local lone = minimized and db.minimizeStyle == "button"
    -- Hide When Empty asks whether anything is tracked, not whether anything was drawn
    local tracked = state.logTracked > 0 or inScenario
        or (db.showRecipes and C_TradeSkillUI and C_TradeSkillUI.GetRecipesTracked
            and #C_TradeSkillUI.GetRecipesTracked(false) > 0)
    local hide = not tracked and db.hideEmpty and not state.editMode and not state.preview
    holder:SetShown(not lone and not hide)
    if miniButton then
        miniButton:ClearAllPoints()
        local corner = CornerOf(self:Side())
        miniButton:SetPoint(corner, holder, corner, 0, 0)
        miniButton:SetShown(lone and not hide)
    end
    self:UpdateItemButtons()
end

-- Quests accepted slide in, the ones below make room, and finished objectives get their sheen
function OT:AnimateLayout(n, drop)
    local tops = {}
    local found = false
    for i = 1, n do
        local line = lines[i]
        local key = (line.questID and ("q" .. line.questID)) or (line.zone and ("z" .. line.zone))
        if key and not tops[key] then tops[key] = line.ftY - drop end
        if line.questID and state.arriving[line.questID] then found = true end
    end
    if found or state.glideNext then
        state.glideNext = nil
        local dx = SlideDistance()
        for i = 1, n do
            local line = lines[i]
            local key = (line.questID and ("q" .. line.questID)) or (line.zone and ("z" .. line.zone))
            if key then
                local old, top = state.tops[key], tops[key]
                if line.questID and state.arriving[line.questID] then
                    MoveLine(line, dx, 0, 0)
                elseif not old then
                    MoveLine(line, 0, 0, 0)
                elseif old ~= top then
                    MoveLine(line, 0, old - top, 1)
                end
            end
        end
        for i = 1, n do
            local id = lines[i].questID
            if id then state.arriving[id] = nil end
        end
    end
    state.tops = tops
    -- accepted but never drawn (not tracked, or filtered out)
    local stale = GetTime() - 3
    for id, at in pairs(state.arriving) do
        if at < stale then state.arriving[id] = nil end
    end
    for _, line in ipairs(state.sheens) do PlaySheen(line) end
end

function OT:QuestAccepted(questID)
    if questID then state.arriving[questID] = GetTime() end
end

-- Its lines slide off first, and the redraw that closes the gap waits for them
function OT:QuestTurnedIn(questID)
    if not questID then return end
    local dx, any = SlideDistance(), false
    for _, line in ipairs(lines) do
        if line:IsShown() and line.questID == questID then
            line.leaving = true
            LeaveLine(line, dx)
            any = true
        end
    end
    if any then
        state.glideNext = true
        state.holdUntil = GetTime() + C.LEAVE_TIME
    end
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
    local range = contentHeight - listHeight
    local offset = range > 0 and math_min(1, math_max(0, scroll:GetVerticalScroll() / range)) or 0
    Build.PlaceScrollBar(track, thumb, scroll, holder, contentHeight, listHeight, offset)
end

-- The track down the list's right margin and the thumb on it, offset 0 (top) to 1 (bottom)
function Build.PlaceScrollBar(track, thumb, list, window, contentHeight, listHeight, offset)
    local px = ns.PixelSize(window)
    local x = -(C.SCROLLBAR_INSET)
    track:ClearAllPoints()
    track:SetPoint("TOPRIGHT", list, "TOPRIGHT", x - px, 0)
    track:SetSize(px, listHeight)
    local thumbHeight = math_max(C.SCROLLBAR_MIN, listHeight * listHeight / contentHeight)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOPRIGHT", list, "TOPRIGHT", x, -(listHeight - thumbHeight) * offset)
    thumb:SetSize(px * 3, thumbHeight)
end

function OT:CountTracked()
    ReadLog()
    return state.logTracked
end

-- Quest log events come in bursts: one redraw for each burst
function OT:RequestRender()
    if state.pending or not holder then return end
    state.pending = true
    local function Later()
        -- a quest still sliding off keeps its place until it has gone
        local left = state.holdUntil and state.holdUntil - GetTime()
        state.holdUntil = nil
        if left and left > 0 then
            C_Timer.After(left, Later)
        else
            OT:Render()
        end
    end
    C_Timer.After(0.1, Later)
end

local function ByOldDistance(x, y)
    if sortDist[x] ~= sortDist[y] then return sortDist[x] < sortDist[y] end
    return x < y
end

local function ByNewDistance(x, y)
    if sortNew[x] ~= sortNew[y] then return sortNew[x] < sortNew[y] end
    return x < y
end

-- Distance changes while moving: redraw only when the order would change
local function OnSortTick()
    local db = GetDb()
    if not (db and db.sortByDistance and holder and holder:IsVisible() and scroll:IsShown()) then return end
    -- the order can only move once a watched quest is nearer or farther than the last sort saw it
    -- (standing still, nothing has); everything else that changes it comes with an event
    local count = state.sortCount
    if count then
        local same = true
        for i = 1, count do
            sortNew[i] = Distance(sortIDs[i])
            if sortNew[i] ~= sortDist[i] then same = false end
        end
        if same then return end
        -- moving changes the distances all the time, but the order only when two quests swap: the
        -- watched quests ranked by the old and the new distances. Unchanged, the log isn't read again
        for i = 1, count do sortRankOld[i], sortRankNew[i] = i, i end
        for i = count + 1, #sortRankOld do sortRankOld[i], sortRankNew[i] = nil, nil end
        table.sort(sortRankOld, ByOldDistance)
        table.sort(sortRankNew, ByNewDistance)
        local swapped = false
        for i = 1, count do
            if sortRankOld[i] ~= sortRankNew[i] then swapped = true break end
        end
        if not swapped then
            for i = 1, count do sortDist[i] = sortNew[i] end
            return
        end
    end
    ReadLog()
    local quests, order = CollectQuests(db), state.order
    if #quests ~= #order then OT:RequestRender() return end
    for i, q in ipairs(quests) do
        if q.questID ~= order[i] then OT:RequestRender() return end
    end
end

--------------------------------------------------
-- 10. MINIMIZE AND AUTO-MINIMIZE
--------------------------------------------------
-- While Settings > Quest Tracker is open: shown, with the sample quests when nothing is tracked
function OT:SetSettingsPreview(on)
    on = on and true or false
    if state.preview == on then return end
    state.preview = on
    if holder then self:Render() end
    -- a faded tracker shows while its page is open
    if ns.Visibility and ns.Visibility.Wake then ns.Visibility:Wake() end
end

function OT:IsSettingsPreview() return state.preview or false end

-- for Visibility: the window, and the pieces it fades with it that sit outside it
function OT:GetFrame() return holder end

function OT:SetFadeAlpha(alpha)
    self.fadeAlpha = alpha
    if miniButton then miniButton:SetAlpha(alpha) end
    for _, b in ipairs(itemButtons) do b:SetAlpha(alpha) end
end

function OT:IsMouseOverExtras()
    if miniButton and miniButton:IsShown() and miniButton:IsMouseOver() then return true end
    for _, b in ipairs(itemButtons) do
        if b:IsShown() and b:IsMouseOver() then return true end
    end
    return false
end

-- Quest item buttons up as a fight starts: the order and folding hold until it ends, so each button
-- stays beside its quest (a protected button cannot follow its title in a fight)
function OT:FreezeForCombat()
    if (state.itemsShown or 0) == 0 then return end
    local frozen, collapsed = {}, {}
    for i, questID in ipairs(state.order or {}) do
        frozen[questID] = i
        collapsed[questID] = IsCollapsed(questID)
    end
    state.frozenOrder, state.frozenCollapsed = frozen, collapsed
end

function OT:SetMinimized(minimized)
    local char = Char()
    char.minimized = minimized and true or false
    char.autoMinimized = nil   -- CheckContext marks its own after this; anything else is the player
    self:Render()
end

function OT:ToggleMinimized()
    self:SetMinimized(not Char().minimized)
end

-- The current context; combat counts only when it has a rule, the open world never minimizes
local INSTANCE_CONTEXT = { party = "dungeon", raid = "raid", pvp = "pvp", arena = "arena" }

local function CurrentContext(rules)
    -- lockdown only begins after PLAYER_REGEN_DISABLED, where this runs; the player is in combat already
    if rules.combat == "minimize" and UnitAffectingCombat("player") then return "combat" end
    local _, instanceType = IsInInstance()
    return INSTANCE_CONTEXT[instanceType] or "world"
end

-- Each rule applies once, on the way in, and opens the tracker again on the way out if the rule is
-- what closed it. Saved per character, so a /reload in a dungeon still opens it on leaving. A click
-- or the key takes over: the player's choice stays
function OT:CheckContext()
    local db = GetDb()
    local rules = db and db.autoMinimize
    if not rules then return end
    local context = CurrentContext(rules)
    if context == state.context then return end
    state.context = context
    local char = Char()
    if context ~= "world" and rules[context] == "minimize" then
        if not char.minimized then
            self:SetMinimized(true)
            char.autoMinimized = true
        end
    elseif char.autoMinimized then
        self:SetMinimized(false)
    end
end

--------------------------------------------------
-- 11. BLIZZARD'S TRACKER
-- Shrunk to nothing and see-through, where Blizzard keeps it: never hidden or re-parented. Any hide
-- or re-parent from here runs Blizzard's OnHide (the managed frame layout, UpdateHeight, MarkDirty)
-- tainted, and the tracker's next update then fails on secret auras (Maw buffs in its scenario
-- section), as on a level-up, when Blizzard re-lays its right-hand frames. Scale and alpha run no
-- scripts. It keeps running, so new quests are still tracked automatically.
--------------------------------------------------
local PARKED_SCALE = 0.001

local function ParkBlizzardTracker()
    local tracker = _G.ObjectiveTrackerFrame
    if not tracker or InCombatLockdown() then return end
    -- the widget's own SetScale: Edit Mode's override re-lays the frame
    local setScale = tracker.SetScaleBase or tracker.SetScale
    if math.abs(tracker:GetScale() - PARKED_SCALE) > 0.0001 then setScale(tracker, PARKED_SCALE) end
    if tracker:GetAlpha() ~= 0 then tracker:SetAlpha(0) end
end

-- Sections stacked under Blizzard's tracker through the shared ForeverTrackerHost (Shortest Path,
-- SkillUp and Adventure Guide Forever) would be parked with it: detached once while this tracker
-- is on, attached back when it is turned off.
-- The shared column (ForeverTrackerCompanion) also copies Blizzard's tracker's scale on every
-- layout, attached or not, so a parked tracker drew it at a thousandth of its size (5.0 to 5.0.6:
-- "their tracker disappeared"). While Blizzard's is parked, the column keeps the player's own scale,
-- and a detached column never dragged starts beside this tracker, not beside the parked one.
local DetachCompanionSections
do
    local function Parked()
        local tracker = _G.ObjectiveTrackerFrame
        return tracker and tracker:GetScale() < 0.01
    end

    local function KeepScale(column)
        local api = _G.ForeverTrackerHost
        if not Parked() or type(api) ~= "table" then return end
        local want = api.GetScale and api.GetScale() or 1
        if type(want) ~= "number" or want <= 0 then want = 1 end
        -- re-enters this hook once, at the right scale, and stops
        if math.abs(column:GetScale() - want) > 0.0001 then column:SetScale(want) end
    end

    local function SeedPosition(api)
        if not holder or not api.GetSettings or api.IsAttachedToQuestTracker() then return end
        local settings = api.GetSettings()
        if type(settings) ~= "table" or (settings.x and settings.y) then return end
        local left, right, top = holder:GetLeft(), holder:GetRight(), holder:GetTop()
        local uiScale = UIParent:GetEffectiveScale()
        if not (left and right and top) or uiScale <= 0 then return end
        -- the column's own units: UIParent's, from its top left corner (their SavePosition's)
        local k = holder:GetEffectiveScale() / uiScale
        left, right, top = left * k, right * k, top * k
        local tracker = _G.ObjectiveTrackerFrame
        local width = (tracker and tracker:GetWidth() or 250) * (api.GetScale and api.GetScale() or 1)
        local x = left - 8 - width
        if x < 0 then x = right + 8 end
        settings.x, settings.y = x, top - UIParent:GetHeight()
    end

    local hooked = false
    DetachCompanionSections = function()
        local host, db = _G.ForeverTrackerHost, GetDb()
        if type(host) ~= "table" or not (host.IsAttachedToQuestTracker and host.SetAttached) or not db then return end
        -- where this tracker stands aside (Gamepad UI, by choice), they stay with Blizzard's
        local on = db.enabled and OT.WantedInMode()
        if on and not db.companionDetached then
            if host.IsAttachedToQuestTracker() then
                host.SetAttached(false)
                db.companionDetached = true
            end
        elseif not on and db.companionDetached then
            if not host.IsAttachedToQuestTracker() then host.SetAttached(true) end
            db.companionDetached = nil
        end
        local column = _G.ForeverTrackerCompanion
        if not on or type(column) ~= "table" or not column.SetScale then return end
        if not hooked then
            hooked = true
            hooksecurefunc(column, "SetScale", KeepScale)
        end
        SeedPosition(host)
        KeepScale(column)
        if type(column.MarkDirty) == "function" then column:MarkDirty() end
    end
end

do
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        -- after the other addons' own first layout (they settle on PLAYER_ENTERING_WORLD too)
        C_Timer.After(0, DetachCompanionSections)
    end)
end

--------------------------------------------------
-- 12. EDIT MODE SETTINGS
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
    -- dropdowns, sliders, switches (ns.OrderEditSettings)
    return ns.OrderEditSettings({
        { name = L["Width"], kind = LEM.SettingType.Slider, default = C.WIDTH, minValue = 180, maxValue = 500, valueStep = 5,
          get = get("width", C.WIDTH), set = set("width") },
        { name = L["Max Height"], kind = LEM.SettingType.Slider, default = C.MAX_HEIGHT, minValue = 150, maxValue = 1000, valueStep = 10,
          get = get("maxHeight", C.MAX_HEIGHT), set = set("maxHeight") },
        { name = L["Quest Spacing"], kind = LEM.SettingType.Slider, default = C.QUEST_GAP, minValue = 2, maxValue = 20, valueStep = 1,
          get = get("questGap", C.QUEST_GAP), set = set("questGap") },
        -- the edge it is held by (it grows away from it); Automatic: the one nearest the screen edge
        { name = L["Anchor"], kind = LEM.SettingType.Dropdown, default = "auto",
          values = { { text = L["Automatic"], value = "auto", isRadio = true },
                     { text = L["Top"], value = "TOP", isRadio = true }, { text = L["Bottom"], value = "BOTTOM", isRadio = true } },
          desc = L["The edge the tracker is held by: Top grows it downward, Bottom upward. Automatic picks the edge nearest the screen's."],
          get = function()
              local db = GetDb()
              local anchor = db and db.anchor
              return (anchor == "TOP" or anchor == "BOTTOM") and anchor or "auto"
          end,
          set = function(_, value)
              local db = GetDb()
              if not db then return end
              db.anchor = value
              -- held by the new corner where it stands now
              OnFrameMoved(nil, LEM:GetActiveLayoutName())
              OT:Render()
          end },
    })
end

--------------------------------------------------
-- 13. SETUP
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

-- The header band (title, zone switch, minimize button) and the divider under it, on a window: the
-- tracker's, or the settings preview's sample. No clicks or tooltips here.
function Build.Header(window)
    local head = CreateFrame("Frame", nil, window)
    head:SetPoint("TOPLEFT", C.HEADER_INSET, -3)
    head:SetPoint("TOPRIGHT", -C.HEADER_INSET, -3)
    head:SetHeight(C.HEADER - 3)
    head.title = head:CreateFontString(nil, "OVERLAY")
    head.minimize = CreateBoxButton(head, nil, C.BOX)
    local zone = CreateFrame("Button", nil, head)
    zone.text = zone:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    zone.text:SetPoint("CENTER")
    head.zone = zone

    local line = window:CreateTexture(nil, "ARTWORK")
    line:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
    line:SetPoint("TOPLEFT", window, "TOPLEFT", C.HEADER_INSET, -C.HEADER + 2)
    line:SetPoint("TOPRIGHT", window, "TOPRIGHT", -C.HEADER_INSET, -C.HEADER + 2)
    line:SetHeight(8)
    return head, line
end

function Build.StyleHeader(head, db)
    ApplyFont(head.title, db.headerFont, 13)
    SetColor(head.title, C.TITLE)
    head.zone.text:SetTextColor(C.DIM[1], C.DIM[2], C.DIM[3])
end

-- the scroll bar: a faint track down the list's right margin and a bronze thumb on it
function Build.ScrollBar(window)
    window.ScrollTrack = window:CreateTexture(nil, "ARTWORK")
    window.ScrollTrack:SetColorTexture(C.BOX_COLOR[1], C.BOX_COLOR[2], C.BOX_COLOR[3], 0.25)
    window.ScrollThumb = window:CreateTexture(nil, "OVERLAY")
    window.ScrollThumb:SetColorTexture(C.BOX_COLOR[1], C.BOX_COLOR[2], C.BOX_COLOR[3], 1)
    for _, t in ipairs({ window.ScrollTrack, window.ScrollThumb }) do
        t:SetSnapToPixelGrid(false)
        t:SetTexelSnappingBias(0)
        t:Hide()
    end
end

local function CreateFrames()
    holder = CreateFrame("Frame", "FlareUI_ObjectiveTracker", UIParent, "BackdropTemplate")
    holder:SetFrameStrata("LOW")
    holder:SetClampedToScreen(true)
    holder:SetSize(C.WIDTH, C.HEADER)
    holder:EnableMouse(true)

    header, divider = Build.Header(holder)

    local minimize = header.minimize
    minimize:SetScript("OnClick", function() OT:ToggleMinimized() end)
    minimize:SetScript("OnEnter", function(self)
        ns.OwnGameTooltip(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(Char().minimized and L["Expand"] or L["Minimize"])
        GameTooltip:Show()
    end)
    minimize:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local zone = header.zone
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
        -- in a fight the quest item buttons cannot move with the list: it holds still while they show
        if InCombatLockdown() and (state.itemsShown or 0) > 0 then return end
        local max = math_max(0, content:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math_min(max, math_max(0, self:GetVerticalScroll() - delta * C.SCROLL_STEP)))
    end)
    scroll:SetScript("OnVerticalScroll", function()
        OT:UpdateScrollBar()
        OT:UpdateItemButtons()
    end)

    Build.ScrollBar(holder)

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
    ApplyBackdrop(holder)
    Build.StyleHeader(header, db)
end

function OT:Refresh()
    if not holder then return end
    self:ApplyLook()
    self:Render()
end

-- In the Gamepad UI only if the player keeps it there (Blizzard's Tracker in Gamepad Mode, off by
-- default): Blizzard's own tracker is part of its controller navigation (D-pad Up gives it the pad,
-- with its quest items and menus). Switching modes reloads.
function OT:ShouldLoad()
    return OT.WantedInMode()
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
        "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "BAG_UPDATE_COOLDOWN",
        "PLAYER_LEVEL_UP", "PLAYER_TARGET_CHANGED", "TRACKED_RECIPE_UPDATE", "BAG_UPDATE_DELAYED",
        "GET_ITEM_INFO_RECEIVED", "QUEST_AUTOCOMPLETE", "QUEST_DETAIL", "PLAYER_MONEY", "SCENARIO_UPDATE", "SCENARIO_CRITERIA_UPDATE",
        "QUEST_TURNED_IN",
    }) do events:RegisterEvent(e) end
    events:RegisterUnitEvent("UNIT_QUEST_LOG_CHANGED", "player")
    events:SetScript("OnEvent", function(_, event, arg1)
        if event == "PLAYER_ENTERING_WORLD" then
            ParkBlizzardTracker()
            OT:CheckContext()
            -- once more a moment later: the first layout can come before the fonts are ready
            C_Timer.After(1, function() OT:Render() end)
        elseif event == "PLAYER_REGEN_ENABLED" then
            ParkBlizzardTracker()
            local wasFrozen = state.frozenOrder ~= nil
            state.frozenOrder, state.frozenCollapsed = nil, nil
            OT:CheckContext()
            if wasFrozen then OT:Render() end
            if state.itemsDirty then OT:UpdateItemButtons() end
            return
        elseif event == "PLAYER_REGEN_DISABLED" then
            OT:CheckContext()
            OT:FreezeForCombat()
            return
        elseif event == "BAG_UPDATE_COOLDOWN" then
            OT:UpdateItemCooldowns()
            return
        elseif event == "PLAYER_TARGET_CHANGED" then
            UpdateRangeTicker()
            return
        elseif (event == "BAG_UPDATE_DELAYED" or event == "GET_ITEM_INFO_RECEIVED") and state.recipes == 0 then
            return
        elseif event == "PLAYER_MONEY" and not state.watchMoney then
            return
        elseif event == "ZONE_CHANGED_NEW_AREA" then
            OT:CheckContext()
        elseif event == "QUEST_REMOVED" and arg1 then
            Char().collapsedQuests[arg1] = nil
            Char().pinned[arg1] = nil
            state.seen[arg1] = nil
        elseif event == "QUEST_ACCEPTED" then
            OT:QuestAccepted(arg1)
        elseif event == "QUEST_TURNED_IN" then
            OT:QuestTurnedIn(arg1)
        end
        OT:RequestRender()
    end)
    C_Timer.NewTicker(C.SORT_TICK, OnSortTick)

    -- The voice addon's packs load after the first draw; its play state changes on its own
    local spoken = _G.Spoken
    if spoken and spoken.RegisterCallback then
        local function Redraw() OT:RequestRender() end
        pcall(spoken.RegisterCallback, spoken, "VOICE_PACKS_LOADED", Redraw)
        pcall(spoken.RegisterCallback, spoken, "PART_SWITCHED", function(part)
            if part == "quests" then Redraw() end
        end)
        pcall(spoken.RegisterCallback, spoken, "AUDIO_CHANGED", function()
            for _, line in ipairs(lines) do
                local b = line.playButton
                if b and b:IsShown() then PaintPlayButton(b) end
            end
        end)
    end

    self:ApplyLook()
    self:Render()
end

-- Key Bindings > AddOns > FlareUI > Minimize / Expand Quest Tracker
function FlareUI_ToggleObjectiveTracker()
    if OT.initialized then OT:ToggleMinimized() end
end

--------------------------------------------------
-- 14. SETTINGS PREVIEW SAMPLE
-- The tracker as Render draws it, on its own frames, from the same builders: header, lines, title
-- buttons, timer bar, scroll bar, backdrop. Kinds: "full" (default) and "header" (as minimized,
-- with the current Minimize Style). Sample quests only; no clicks, tooltips or item buttons.
--------------------------------------------------
do
    local SAMPLE_COUNT = 6
    -- built on first draw, so the strings come from a loaded locale
    local quests
    local function SampleQuests()
        if quests then return quests end
        quests = {
            { zone = L["Elwynn Forest"] },
            { level = 6, title = L["Hogger's Tax Return"], timer = 285, timerTotal = 300, objectives = {
                { text = L["2/5 Questionable deductions explained"] },
                { text = L["0/1 Receipt for 'Emergency Gnoll Snacks'"] } } },
            { level = 8, title = L["Murloc Diction Lessons"], focus = true, objectives = {
                { text = L["4/8 Murlocs saying 'Hello' clearly"] },
                { text = L["0/1 Agreed spelling of 'Mrglglgl'"] } } },
            { level = 5, title = L["Mankrik's Wife, Again"], done = true, ready = L["Return to Mankrik. Gently."], objectives = {
                { text = L["1/1 Wife found (she was in Goldshire)"], finished = true } } },
            { zone = L["Westfall"] },
            { level = 12, tags = "+ g5", title = L["Leeroy's Time Management Seminar"], objectives = {
                { text = L["1/1 Name shouted"], finished = true },
                { text = L["0/1 Excuses accepted by Garrosh"] },
                { text = L["0/1 Plan with 32.33% odds rehearsed"] } } },
            { level = 14, title = L["Gnomeregan Is Fine, Actually"], objectives = {
                { text = L["3/8 Leper gnomes reassured"] },
                { text = L["0/1 Glow described as 'cosy'"] } } },
            { level = 11, tags = " d", title = L["The Lich King's Missing Left Boot"], objectives = {
                { text = L["6/10 Kobold candles confiscated"] },
                { text = L["0/1 Left boot found in the Deadmines"] } } },
        }
        return quests
    end

    function OT.CreateSample(parent, kind)
        local f = CreateFrame("Frame", nil, parent)
        f.fuiSample = true
        f:EnableMouse(false)
        f.kind = kind == "header" and "header" or "full"
        local window = CreateFrame("Frame", nil, f, "BackdropTemplate")
        window:SetPoint("TOPLEFT")
        window:EnableMouse(false)
        f.Window = window
        f.Header, f.Divider = Build.Header(window)
        f.Header.minimize:EnableMouse(false)
        f.Header.zone:EnableMouse(false)
        -- the list, cut at Max Height as the real one's scroll frame cuts it
        local list = CreateFrame("Frame", nil, window)
        list:SetClipsChildren(true)
        list:SetPoint("TOPLEFT", window, "TOPLEFT", 0, -C.HEADER - C.LIST_TOP)
        list:SetPoint("RIGHT", window, "RIGHT", 0, 0)
        f.List = list
        f.Content = CreateFrame("Frame", nil, list)
        f.Content:SetPoint("TOPLEFT")
        Build.ScrollBar(window)
        f.Lines, f.Bars = {}, {}
        -- the lone "+" of Minimize Style "button"
        f.Lone = CreateBoxButton(f, nil, C.LONE)
        f.Lone:SetPlus(true)
        f.Lone:EnableMouse(false)
        f.Lone:SetPoint("TOPLEFT")
        f.Lone:Hide()
        return f
    end

    -- the title's focus and voice buttons, as AddTitleButtons places them (previews show the voice
    -- button on every quest)
    local function TitleButtons(line, db, focused)
        local x = -3
        if line.focusButton then line.focusButton:Hide() end
        if line.playButton then line.playButton:Hide() end
        if db.focusButtons then
            local b = line.focusButton or Build.LineButton(line)
            line.focusButton = b
            b:EnableMouse(false)
            b.icon:SetTexture(focused and "Interface\\Common\\Indicator-Yellow" or "Interface\\Common\\Indicator-Gray")
            b:ClearAllPoints()
            b:SetPoint("TOPRIGHT", line, "TOPLEFT", x, 0)
            b:Show()
            x = x - C.BUTTON_ROOM
        end
        if db.playButtons then
            local b = line.playButton or Build.LineButton(line)
            line.playButton = b
            b:EnableMouse(false)
            PaintPlayButton(b)
            b:ClearAllPoints()
            b:SetPoint("TOPRIGHT", line, "TOPLEFT", x, 0)
            b:Show()
        end
    end

    local function DrawList(f, db, width)
        local n, y, lastBottom, bars = 0, 0, 0, 0
        local inner = width - C.PAD * 2
        local wrap = db.wrapText ~= false
        local fonts = { header = db.headerFont, title = db.titleFont, objective = db.objectiveFont }
        local questGap = db.questGap or C.QUEST_GAP
        local titleRoom = (db.focusButtons and C.BUTTON_ROOM or 0) + (db.playButtons and C.BUTTON_ROOM or 0)
        local objectiveIndent = C.INDENT + titleRoom

        local function AddLine(text, kind, color, indent)
            n = n + 1
            local line = f.Lines[n]
            if not line then
                line = Build.Line(f.Content)
                line:EnableMouse(false)
                f.Lines[n] = line
            end
            local h = Build.LineLook(line, text, kind, fonts[kind], color, inner - (indent or 0), wrap)
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", f.Content, "TOPLEFT", C.PAD + (indent or 0), y)
            if line.focusButton then line.focusButton:Hide() end
            if line.playButton then line.playButton:Hide() end
            line:Show()
            lastBottom = y - h
            y = y - h - C.LINE_GAP
            return line
        end

        for _, s in ipairs(SampleQuests()) do
            if s.zone then
                if db.zoneHeaders then
                    if n > 0 then y = y - C.GROUP_GAP end
                    AddLine(s.zone, "header", C.ZONE)
                    y = y - C.ZONE_GAP
                end
            else
                -- Auto-Collapse Completed folds the finished one
                local collapsed = s.done and db.collapseCompleted
                local line = AddLine(Build.TitleText(db, s.level, s.tags or "", s.title, collapsed), "title",
                    Build.TitleColor(db, s.level, nil, s.focus, s.done), titleRoom)
                TitleButtons(line, db, s.focus)
                if s.timer then
                    local color = C.TIMER[#C.TIMER]
                    local timer = AddLine(TimerText(s.timer), "objective", color, objectiveIndent)
                    bars = bars + 1
                    local bar = f.Bars[bars] or Build.TimerBar(f.Content)
                    f.Bars[bars] = bar
                    bar:ClearAllPoints()
                    bar:SetPoint("TOPLEFT", timer, "BOTTOMLEFT", 0, -1)
                    bar:SetSize(math_max(20, inner - objectiveIndent - 4), 3)
                    bar:SetValue(s.timer / s.timerTotal)
                    bar:SetStatusBarColor(color[1], color[2], color[3], 0.9)
                    bar:Show()
                    lastBottom = lastBottom - 5
                    y = y - 5
                end
                if not collapsed then
                    if s.done then
                        AddLine(s.ready, "objective", C.TITLE_DONE, objectiveIndent)
                    else
                        for _, o in ipairs(s.objectives) do
                            if not (db.hideFinished and o.finished) then
                                AddLine(o.text, "objective", o.finished and C.OBJECTIVE_DONE or C.OBJECTIVE, objectiveIndent)
                            end
                        end
                    end
                end
                y = y - questGap
            end
        end
        for i = n + 1, #f.Lines do f.Lines[i]:Hide() end
        for i = bars + 1, #f.Bars do f.Bars[i]:Hide() end
        return math_max(1, -lastBottom)
    end

    function OT.DrawSample(f)
        local db = GetDb() or {}
        local width = db.width or C.WIDTH
        local window, head = f.Window, f.Header
        local minimized = f.kind == "header"
        if minimized and db.minimizeStyle == "button" then
            window:Hide()
            f.Lone:Show()
            local w, h = f.Lone:GetSize()
            f:SetSize(w, h)
            f:Show()
            return w, h
        end
        f.Lone:Hide()
        ApplyBackdrop(window)
        Build.StyleHeader(head, db)
        local max = C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept() or nil
        Build.LayoutHeader(head, db, SAMPLE_COUNT, max, minimized)
        window:SetWidth(width)
        window:Show()
        local track, thumb = window.ScrollTrack, window.ScrollThumb
        local height
        if minimized then
            -- minimized, the header keeps the same 3 px below it as above it
            f.List:Hide()
            f.Divider:Hide()
            track:Hide()
            thumb:Hide()
            height = C.HEADER + 3
        else
            local contentHeight = DrawList(f, db, width)
            local listHeight = math_min(contentHeight, db.maxHeight or C.MAX_HEIGHT)
            f.Content:SetSize(width, contentHeight)
            f.List:SetHeight(math_max(1, listHeight))
            f.List:Show()
            f.Divider:Show()
            local scrollable = contentHeight > listHeight + 1
            track:SetShown(scrollable)
            thumb:SetShown(scrollable)
            if scrollable then Build.PlaceScrollBar(track, thumb, f.List, window, contentHeight, listHeight, 0) end
            height = C.HEADER + C.LIST_TOP + listHeight + C.LIST_BOTTOM
        end
        window:SetHeight(height)
        f:SetSize(width, height)
        f:Show()
        return width, height
    end
end
