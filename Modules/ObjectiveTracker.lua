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
    FLAREUI_BORDER = "FlareUI Thick",   -- Frame Style FlareUI's own border (FlareUI Frames Thick, 11-18)
    WIDTH = 250, MAX_HEIGHT = 300,
    HEADER = 30,            -- header band
    HEADER_INSET = 8,       -- header contents from the frame edges
    PAD = 14,               -- text inset from the frame edges
    INDENT = 10,            -- objectives under their quest
    LIST_TOP = 10,          -- from the header line to the first line of the list
    LIST_BOTTOM = 14,       -- from the last line to the frame's bottom edge
    LINE_GAP = 2, QUEST_GAP = 9, GROUP_GAP = 10,
    ZONE_GAP = 5,           -- under a zone heading, before its first quest
    SCROLL_STEP = 40,
    SCROLLBAR_INSET = 6,    -- the scroll bar's right edge, in from the frame's
    SCROLLBAR_MIN = 16,     -- the shortest the thumb gets
    ITEM_SIZE = 22, ITEM_GAP = 3,
    TOOLTIP_GAP = 2,        -- a quest's tooltip from the frame's edge
    BOX = 14,               -- the header's minimize / expand button
    LONE = 18,              -- the lone expand button of Minimize Style "Button Only"
    ICON_PATH = "Interface\\AddOns\\FlareUI\\Media\\Icons\\",
    FOLD_SCALE = 16 / 15,
    FOLD_EXPAND = "ui-questtrackerbutton-secondary-expand",
    FOLD_COLLAPSE = "ui-questtrackerbutton-secondary-collapse",
    BOX_COLOR = { 0.50, 0.38, 0.21 },        -- a darker bronze than the frame border
    BOX_COLOR_LIT = { 0.65, 0.49, 0.27 },    -- the frame border's bronze while pointed at
    SCROLL_COLOR = { 0.32, 0.24, 0.13 },     -- the scroll bar: a dark bronze, as the frame's shadowed edges
    SORT_TICK = 2,          -- seconds between distance checks
    BUTTON_ROOM = 13,       -- beside a title, for each focus / play button
    BUTTON_SIZE = 12,
    -- Quest Icons: Blizzard's quest button (20 px on its tracker) at this size, and the room it takes
    POI_SIZE = 14, POI_ROOM = 15, POI_BLIZZARD = 20,
    -- the focused quest icon's outer glow: its alpha, and its size against the icon's scale
    POI_GLOW_ALPHA = 0.4, POI_GLOW_SCALE = 0.85,
    FOLD_ROOM = 16,         -- Collapsible Zones: room right of a heading for its fold arrow
    UNTRACKED_ALPHA = 0.55, -- Show Untracked Quests: how bright an untracked quest's text is
    -- Quest animations: px a quest slides, seconds for it to move, leave, and for a sheen to cross
    SLIDE = 24, MOVE_TIME = 0.25, LEAVE_TIME = 0.3, SHEEN_TIME = 0.6, SHEEN_WIDTH = 36,
    -- the header, zone headings and quest titles in Blizzard's yellow (NORMAL_FONT_COLOR); 11-18 Marcus:
    -- not the tracker's darker title gold (OBJECTIVE_TRACKER_BLOCK_HEADER_COLOR), it looked dull
    HEADING = { 1, 0.82, 0 },
    ZONE = { 1, 0.82, 0 },
    TITLE = { 1, 0.82, 0 },
    TITLE_DONE = { 0.13, 1, 0.13 },
    TITLE_FOCUS = { 0.40, 0.80, 1 },   -- quest pop-ups ("! title"), and the focused quest with no focus buttons
    OBJECTIVE = { 0.85, 0.85, 0.85 },
    OBJECTIVE_DONE = { 0.55, 0.55, 0.55 },
    -- the plain "Ready to turn in" line: Blizzard's grey (OBJECTIVE_TRACKER_COLOR.Complete); a quest's own
    -- closing text or a "talk to" waypoint keeps the objective colour, as in Blizzard's tracker
    READY = { 0.6, 0.6, 0.6 },
    DIM = { 0.55, 0.55, 0.55 },
    URGENT = { 1, 0.25, 0.25 },
    -- a quest timer by the quarter of its time it is in, last to first
    TIMER = { { 1, 0.25, 0.25 }, { 1, 0.5, 0.15 }, { 1, 1, 0 }, { 0.25, 1, 0.25 } },
    NO_FONT = {},           -- a font setting with nothing set (only ever read)
}

-- Colour Scheme (11-20, Malkkav): Blizzard's colours, or FlareUI's: the header and zone headings in light
-- bronze, quest titles in the accent bronze, every other colour (complete, focus, objectives, timers,
-- difficulty) in a softer tone of its own (ns.SoftColor). The C tables change in place, so every
-- holder of one follows. Blizzard frame style always takes Blizzard's; FlareUI and Custom default to
-- FlareUI's (objectivetracker.colorScheme nil).
OT.SCHEME_KEYS = { "HEADING", "ZONE", "TITLE", "TITLE_DONE", "TITLE_FOCUS", "OBJECTIVE", "OBJECTIVE_DONE", "READY", "DIM", "URGENT" }
OT.SCHEME_BRONZE = { HEADING = "bronze5", ZONE = "bronze5", TITLE = "bronze4" }
OT.blizzColors = {}
for _, key in ipairs(OT.SCHEME_KEYS) do OT.blizzColors[key] = { C[key][1], C[key][2], C[key][3] } end
for i, c in ipairs(C.TIMER) do OT.blizzColors["TIMER" .. i] = { c[1], c[2], c[3] } end
function OT.ColorScheme(db)
    if not db or db.frameStyle == "blizzard" then return "blizzard" end
    return db.colorScheme or "flareui"
end
function OT.ApplyColorScheme(db)
    local scheme = OT.ColorScheme(db)
    if scheme == OT.schemeApplied then return false end
    OT.schemeApplied = scheme
    OT.soft = scheme == "flareui"
    local function Set(t, from, bronze)
        local r, g, b = from[1], from[2], from[3]
        if OT.soft then
            if bronze then r, g, b = bronze[1], bronze[2], bronze[3] else r, g, b = ns.SoftColor(r, g, b) end
        end
        t[1], t[2], t[3] = r, g, b
    end
    for _, key in ipairs(OT.SCHEME_KEYS) do
        Set(C[key], OT.blizzColors[key], OT.SCHEME_BRONZE[key] and ns.PALETTE[OT.SCHEME_BRONZE[key]])
    end
    for i, c in ipairs(C.TIMER) do Set(c, OT.blizzColors["TIMER" .. i]) end
    -- the tables kept their identity: lines that skip an unchanged colour table paint again (LineLook)
    OT.schemeGen = (OT.schemeGen or 0) + 1
    return true
end

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
    linkChat = _G.SHARE_IN_CHAT or "Link to Chat",
    focus = _G.SUPER_TRACK_QUEST or "Focus",
    unfocus = _G.STOP_SUPER_TRACK_QUEST or "Stop Focusing",
    untrack = _G.OBJECTIVES_STOP_TRACKING or "Untrack Quest",
    track = _G.TRACK_QUEST or "Track Quest",
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
    arriving = {}, seen = {}, tops = {}, sheens = {}, pass = 0,   -- pass: renders so far (state.seen)
    zoneCounts = {}, fonts = {},   -- reused by every render
    voicePlayed = {},              -- quests whose voice line has played or been stopped this session
}
-- builders shared by the tracker and the settings preview's sample (OT.CreateSample)
local Build = {}
-- the header strips and their sizes, for the chat's FlareUI frame style (Chat.lua Chat.ApplyFrameStyleArt)
OT.Build, OT.C = Build, C

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
    -- (a layout with no spot of its own reads the profile's home layout's: ProfileLayout.lua)
    return ns.LayoutHome(db.layouts, layoutName)
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
    -- Frame Style: Blizzard has no border; FlareUI always has its frame border, the one its strips'
    -- knobs sit on; Custom takes the Border chosen
    local style = Build.FrameStyle(db)
    if style == "blizzard" then return nil end
    if style == "flareui" then name = C.FLAREUI_BORDER end
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
    -- (Frame Style Blizzard: no background, as Blizzard's tracker)
    local opacity = Build.FrameStyle(db) == "blizzard" and 0 or (db and db.opacity or 0.75)
    frame:SetBackdropColor(1, 1, 1, opacity)
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
local sortNew, sortRankOld = {}, {}   -- cached order and scratch for the distance check (OnSortTick)

local function AddZoneName(z)
    if z and z ~= "" then zoneNames[z] = true end
end

local function CurrentZoneNames()
    wipe(zoneNames)
    AddZoneName(GetRealZoneText())
    AddZoneName(GetZoneText())
    AddZoneName(GetSubZoneText())
end

-- By Distance only. By Zone (zoneFirst) keeps quest log order inside each zone, so quests don't jump
-- around while you run through it. Old settings can have sortByDistance on with By Zone: the check is
-- here, not in the saved value.
function OT.SortsByDistance(db)
    return db and db.sortByDistance and not db.zoneFirst or false
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
    if a.ftFocus ~= b.ftFocus then return a.ftFocus end   -- Focused Quest First
    if a.ftUntracked ~= b.ftUntracked then return not a.ftUntracked end   -- Show Untracked Quests: after the tracked
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
    -- Show Untracked Quests: the quests of the zone you are in that you don't track are listed too
    -- (dimmed, after the tracked ones; with no zone headings, after every tracked quest). Tracking is never changed here
    local showUntracked = db.showUntracked
    local byDistance = OT.SortsByDistance(db)
    state.untrackedShown = false
    for _, info in ipairs(logBuf) do
        local questID = info.questID
        local loose = showUntracked and not info.isHeader and not info.ftWatched and not info.isHidden
            and not info.isTask and not info.isBounty and canaccessvalue(questID) and type(questID) == "number" and questID > 0
        local here
        if loose then
            local onMap = C_QuestLog.IsOnMap(questID)
            here = (header and zoneNames[header]) or (canaccessvalue(onMap) and onMap)
            loose = here and true or false
        end
        if info.isHeader then
            header = info.title
        elseif info.ftWatched or loose then
            local distance = byDistance and Distance(info.questID) or 0
            -- every watched quest, listed or not: one coming into its zone has moved nearer too
            if byDistance then
                watched = watched + 1
                sortIDs[watched], sortDist[watched] = info.questID, distance
            end
            if here == nil then here = (header and zoneNames[header]) or C_QuestLog.IsOnMap(info.questID) end
            -- a running timer stays listed outside its zone
            if here or not db.zoneOnly or questTimers[info.questID] then
                info.ftUntracked = loose and true or false
                if loose then state.untrackedShown = true end
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
    state.sortCount = byDistance and watched or nil
    state.sortRanksReady = nil   -- CollectQuests replaced the distance snapshot

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
        -- no headings to sit under: the untracked ones go after every tracked quest
        if q.ftUntracked and not (db.zoneHeaders and not db.sortByLevel and not db.sortByProgress) then q.ftRank = 1e6 end
    end
    -- Pin to Top: pinned quests lead the list, in their own order
    local pinned = Char().pinned
    for _, q in ipairs(questBuf) do
        if pinned[q.questID] then q.ftRank = -1 end
    end
    -- Focused Quest First: the focused quest goes to the top, under any pinned ones. With zone
    -- headings its whole zone moves up with it (one heading, not two), and it leads that zone
    local focusedID = db.focusedFirst and C_SuperTrack.GetSuperTrackedQuestID() or nil
    local focusedHeader
    for _, q in ipairs(questBuf) do
        q.ftFocus = focusedID ~= nil and q.questID == focusedID
        if q.ftFocus and q.ftRank ~= -1 then focusedHeader = q.ftHeader end
    end
    if focusedHeader then
        local headings = db.zoneHeaders and not db.sortByLevel and not db.sortByProgress
        for _, q in ipairs(questBuf) do
            if q.ftRank ~= -1 and (q.ftFocus or (headings and q.ftHeader == focusedHeader)) then q.ftRank = -0.5 end
        end
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
    local id = tag and tag.tagID
    local T = Enum.QuestTag
    -- Forever marks elite quests with the Group tag (named Elite), not
    -- isElite: either one, or the quest's own isElite, gives the +
    if (tag and (tag.isElite or tag.tagName == _G.ELITE or (T and id == T.Group))) or q.isElite then tags = tags .. "+" end
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

-- The Gamepad UI: FlareUI must not open the quest log itself (a panel opened from addon code
-- taints the pad's binding stack), so a click picks the quest and the details show when the
-- player opens the quest log the pad's own way (the radial's Quests & Maps, or its key). Only
-- the details page changes then, a moment after Blizzard opened the map: nothing is shown or
-- registered from FlareUI's call. Out of fights only; a pick older than a minute is dropped.
local PAD_PICK_SECONDS = 60

function OT.PickForQuestLog(questID)
    if InCombatLockdown() then
        if UIErrorsFrame then UIErrorsFrame:AddMessage(L["The quest log can't be opened from the tracker in combat."], 1, 0.25, 0.25) end
        return
    end
    state.padPick, state.padPickAt = questID, GetTime()
    if UIErrorsFrame then UIErrorsFrame:AddMessage(L["Open your quest log to read this quest."], 1, 0.82, 0) end
    if OT.padPickHooked or not WorldMapFrame then return end
    OT.padPickHooked = true
    WorldMapFrame:HookScript("OnShow", function()
        C_Timer.After(0, function()
            local id, at = state.padPick, state.padPickAt
            state.padPick, state.padPickAt = nil, nil
            if not id or GetTime() - (at or 0) > PAD_PICK_SECONDS or InCombatLockdown() then return end
            if not (WorldMapFrame:IsShown() and QuestMapFrame and QuestMapFrame_ShowQuestDetails) then return end
            if not C_QuestLog.GetLogIndexForQuestID(id) then return end
            if QuestMapFrame.SetDisplayMode and QuestLogDisplayMode then QuestMapFrame:SetDisplayMode(QuestLogDisplayMode.Quests) end
            QuestMapFrame_ShowQuestDetails(id)
        end)
    end)
end

-- A finished auto-complete quest completes on the click, as on Blizzard's tracker
local function OpenQuest(questID)
    if ns.IsGamepadUI() then
        local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
        local info = logIndex and C_QuestLog.GetInfo(logIndex)
        -- completing one opens a quest window: refused here
        if info and info.isAutoComplete and C_QuestLog.IsComplete(questID) then CanOpenPanels() return end
        OT.PickForQuestLog(questID)
        return
    end
    if not CanOpenPanels() then return end
    local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
    local info = logIndex and C_QuestLog.GetInfo(logIndex)
    if info and info.isAutoComplete and C_QuestLog.IsComplete(questID) then
        ShowQuestComplete(questID)
        if RemoveAutoQuestPopUp then RemoveAutoQuestPopUp(questID) end
    elseif QuestMapFrame_OpenToQuestDetails then
        -- Blizzard's own tracker opens the map and details untainted where it can (OT.ShowSecureClick, a
        -- plain left click). Its parked tracker only builds the quests that fit in its height, so most
        -- have no header to click: those open from here, as before 7.0.1 (11-22: 7.0.1 only showed
        -- "Open your quest log" for them, and the click did nothing)
        QuestMapFrame_OpenToQuestDetails(questID)
    end
end

local function LinkToChat(questID)
    local link = GetQuestLink(questID)
    if link and not ChatFrameUtil.InsertLink(link) then ChatFrameUtil.OpenChat(link) end
end

-- A focus change (SUPER_TRACKING_CHANGED) or a watch-list change (QUEST_WATCH_LIST_CHANGED) fires
-- its event inside FlareUI's call, and the world map's quest pins rebuild there and then
-- (QuestDataProvider:RefreshAllData). Once the map has been opened they listen even while it is
-- closed. In combat that rebuild is blocked when FlareUI started it (ADDON_ACTION_BLOCKED,
-- SetPassThroughButtons on each pin), and no call path makes it secure, so in a fight both changes
-- wait for the fight to end. The last choice per quest wins.
function OT.RunAfterFight()
    if not OT.fightWaiter then
        OT.fightWaiter = CreateFrame("Frame")
        OT.fightWaiter:SetScript("OnEvent", function(self)
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            local focus, watches = OT.focusAfterCombat, OT.watchAfterCombat
            OT.focusAfterCombat, OT.watchAfterCombat = nil, nil
            for questID, watch in pairs(watches or {}) do
                -- only what still differs: the quest may have been finished or dropped meanwhile
                local watched = C_QuestLog.GetQuestWatchType(questID) ~= nil
                if watch and not watched and C_QuestLog.GetLogIndexForQuestID(questID) then
                    C_QuestLog.AddQuestWatch(questID)
                elseif not watch and watched then
                    C_QuestLog.RemoveQuestWatch(questID)
                end
            end
            if focus then C_SuperTrack.SetSuperTrackedQuestID(focus) end
        end)
    end
    OT.fightWaiter:RegisterEvent("PLAYER_REGEN_ENABLED")
end

function OT.SetFocus(questID)
    if not InCombatLockdown() then
        C_SuperTrack.SetSuperTrackedQuestID(questID)
        return
    end
    OT.focusAfterCombat = questID
    OT.RunAfterFight()
end

-- Track (watch true) or untrack a quest; in a fight it waits (see above)
function OT.SetWatched(questID, watch)
    if not InCombatLockdown() then
        if watch then C_QuestLog.AddQuestWatch(questID) else C_QuestLog.RemoveQuestWatch(questID) end
        return
    end
    OT.watchAfterCombat = OT.watchAfterCombat or {}
    OT.watchAfterCombat[questID] = watch and true or false
    OT.RunAfterFight()
end

-- Shift-click: tracked becomes untracked and back; a second click in the fight undoes the first
function OT.ToggleWatched(questID)
    local pending = OT.watchAfterCombat and OT.watchAfterCombat[questID]
    local watched = pending
    if watched == nil then watched = C_QuestLog.GetQuestWatchType(questID) ~= nil end
    if not watched then
        OT.SetWatched(questID, true)
    elseif QuestUtil.CanRemoveQuestWatch() then
        OT.SetWatched(questID, false)
    end
end

local function ToggleFocus(questID)
    local focused = C_SuperTrack.GetSuperTrackedQuestID() == questID
    if OT.focusAfterCombat == questID then focused = true end   -- a second click in the fight undoes the first
    if OT.KeepFocusManual then OT.KeepFocusManual() end   -- the player's own choice: Keep Quest Focus leaves it
    OT.SetFocus(focused and 0 or questID)
    if not focused and OT.QuestieFlash then OT.QuestieFlash(questID) end
end

-- Questie's per-quest Hide Icons / Show Icons, in our quest menu while Questie runs.
-- Questie keeps the state (quest.HideIcons + Questie.db.char.TrackerHiddenQuests); this does what its
-- own tracker menu does. Every Questie call is guarded: an update on its side only drops the entry.
do
    local function Module(name)
        local loader = _G.QuestieLoader
        if type(loader) ~= "table" then return end
        local mods = rawget(loader, "_modules")
        if type(mods) == "table" then   -- read only: ImportModule would create a missing module
            local m = mods[name]
            return type(m) == "table" and m or nil
        end
        if type(loader.ImportModule) == "function" then
            local ok, m = pcall(loader.ImportModule, loader, name)
            if ok and type(m) == "table" then return m end
        end
    end

    local function HiddenList()
        local q = _G.Questie
        local qdb = type(q) == "table" and rawget(q, "db")
        local char = type(qdb) == "table" and qdb.char
        local list = type(char) == "table" and char.TrackerHiddenQuests
        return type(list) == "table" and list or nil
    end

    local function GetQuest(questID)
        local qdb = Module("QuestieDB")
        if not (qdb and type(qdb.GetQuest) == "function") then return end
        local ok, quest = pcall(qdb.GetQuest, questID)
        if ok and type(quest) == "table" then return quest end
    end

    local function Redraw(show)
        local qq = Module("QuestieQuest")
        if not qq then return end
        if type(qq.ToggleQuestNotes) == "function" then
            pcall(qq.ToggleQuestNotes, show)
        elseif type(qq.ToggleNotes) == "function" then   -- older Questie
            pcall(qq.ToggleNotes, qq, show)
        end
    end

    function OT.AddQuestieIconsButton(root, questID)
        if not (questID and HiddenList() and Module("QuestieQuest")) then return end
        local quest = GetQuest(questID)
        if not quest then return end
        local hidden = quest.HideIcons and true or false
        -- Questie offers Hide only for a quest it can show on the map; Show always (to undo)
        if not hidden then
            local elig = Module("TrackerMapEligibility")
            if elig and type(elig.RefreshAndGetCapabilities) == "function" then
                local ok, _, caps = pcall(elig.RefreshAndGetCapabilities, questID)
                if ok and type(caps) == "table" and not caps.canFocusQuest then return end
            end
        end
        -- our own wording: plain "Hide Icons" doesn't say whose icons in FlareUI's menu
        local label = hidden and L["Show Questie Icons"] or L["Hide Questie Icons"]
        root:CreateButton(label, function()
            local list, q = HiddenList(), GetQuest(questID)
            if not (list and q) then return end
            local hide = not q.HideIcons
            q.HideIcons = hide or nil
            list[questID] = hide or nil
            Redraw(not hide)
        end)
    end

    -- Focusing a quest while the world map is open: Questie's own map flash, as its tracker's focus
    -- button does (the map moves to the quest's zone and its icons pulse). Only the flash is called,
    -- so Questie's saved focus is never written. One frame later, once the new focus has landed;
    -- never in a fight, where Questie can't open the map anyway.
    function OT.QuestieFlash(questID)
        if InCombatLockdown() or not (WorldMapFrame and WorldMapFrame:IsShown()) then return end
        if not Module("TrackerUtils") then return end
        C_Timer.After(0, function()
            if InCombatLockdown() or not WorldMapFrame:IsShown() then return end
            if C_SuperTrack.GetSuperTrackedQuestID() ~= questID then return end
            local utils = Module("TrackerUtils")
            if utils and type(utils.ShowQuestOnMap) == "function" then pcall(utils.ShowQuestOnMap, questID) end
        end)
    end
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
        -- (no Open Quest Log or Show on Map since 11-21: from a menu they would taint the map's pins;
        -- a left click on the quest opens both through Blizzard's own tracker)
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
        OT.AddQuestieIconsButton(root, questID)
        root:CreateButton(L["Wowhead Link"], function()
            ns.ShowDialog("FLAREUI_QUEST_LINK", nil, ("https://www.wowhead.com/forever/quest=%d/"):format(questID))
        end)
        if C_QuestLog.GetQuestWatchType(questID) == nil then
            -- an untracked quest (Show Untracked Quests): tracked only when the player picks this
            root:CreateButton(TEXT.track, function() OT.SetWatched(questID, true) end)
        elseif QuestUtil.CanRemoveQuestWatch() then
            root:CreateButton(TEXT.untrack, function() OT.SetWatched(questID, false) end)
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

-- The tooltip opens on the side facing the middle of the screen, right beside the frame (over the
-- quest item buttons, which sit outside it)
local function AnchorTooltip(line)
    ns.OwnGameTooltip(line, "ANCHOR_NONE")
    local right = OT:Side()
    local gap = C.TOOLTIP_GAP
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
    -- Show Untracked Quests: how to track one from here
    if C_QuestLog.GetQuestWatchType(questID) == nil then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["Not tracked. Shift-click to track it."], 0.6, 0.6, 0.6)
    end
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
    OT:Render()   -- a click redraws at once (the usual 0.1 s wait made the headings feel slow)
end

local function TryInsertQuestLink(link)
    if ChatFrameUtil.GetActiveWindow() then
        ChatFrameUtil.InsertLink(link)
        return true
    end

    local editBox = GetCurrentKeyBoardFocus()
    -- Blizzard also accepts links in the macro editor. Keep Shift-click tracking there.
    if not canaccessvalue(editBox) or not editBox or editBox == MacroFrameText
        or editBox:IsForbidden() or not editBox:IsObjectType("EditBox") then
        return false
    end

    local before = editBox:GetText()
    if not canaccessvalue(before) then return false end
    if ChatFrameUtil.InsertLink(link) then return true end

    -- A post-hook can insert into the focused box without changing Blizzard's return value.
    local after = editBox:GetText()
    return canaccessvalue(after) and after ~= before
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
        -- (a quest zone's heading always folds)
        local z = Char().collapsedZones
        z[self.zone] = not z[self.zone] or nil
        -- at once: the usual 0.1 s wait (and any slide still running) made the headings feel slow
        state.holdUntil = nil
        OT:Render()
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
        local link = GetQuestLink(questID)
        if link and TryInsertQuestLink(link) then return end
        OT.ToggleWatched(questID)
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
    -- Measure wrapped text without the height limit left by the previous layout.
    if wrap then line.text:SetHeight(0) end
    if line.ftText ~= text then
        line.ftText = text
        line.text:SetText(text)
    end
    if line.ftColor ~= color or line.ftScheme ~= OT.schemeGen then
        line.ftColor, line.ftScheme = color, OT.schemeGen
        SetColor(line.text, color)
    end
    if line.ftWidth ~= w then
        line.ftWidth = w
        line:SetWidth(w)
        line.text:SetWidth(w)
    end
    local textHeight = wrap and math.ceil(line.text:GetHeight()) or math_floor(line.text:GetStringHeight() + 0.5)
    local h = math_max(FontHeight(cfg, 12), textHeight)
    local heightChanged = line.ftHeight ~= h
    if heightChanged then
        line.ftHeight = h
        line:SetHeight(h)
    end
    if wrap or heightChanged then line.text:SetHeight(h) end
    return h
end

-- SECURE CLICK INTO BLIZZARD'S TRACKER (11-21). Opening the map or a quest's details from addon code
-- builds the map's quest pins under FlareUI's taint, and pins made that way stay tainted: in a fight
-- the game then blocks them (SetPassThroughButtons) even when the map is opened by its key. Even
-- C_Map.OpenWorldMap runs Blizzard's opener tainted on Forever (tested 11-21). So one secure button
-- covers the quest line under the mouse and clicks that quest's header in Blizzard's parked tracker:
-- Blizzard's own code opens the map and the details (or completes an auto-complete quest), untainted.
-- Only a plain left click goes there; every other click reaches the line's own handler (PostClick).
-- Out of fights only (attributes can't change in one; the button hides as a fight starts, and the
-- line's click then refuses to open panels, as before). Placed by screen position, never anchored to
-- the line: a line anchored to a secure button could not move in a fight. The idea is EllesmereUI's
-- tracker's (ideas only).
C.QUEST_MODULES = { "QuestObjectiveTracker", "CampaignQuestObjectiveTracker" }
function OT.BlizzardQuestHeader(questID)
    for _, name in ipairs(C.QUEST_MODULES) do
        local module = _G[name]
        local ok, block = false, nil
        if module and module.GetExistingBlock then ok, block = pcall(module.GetExistingBlock, module, questID) end
        local headerButton = ok and block and block.HeaderButton
        if headerButton and not headerButton:IsForbidden() then return headerButton end
    end
end
function OT.HideSecureClick()
    local o = OT.secureClick
    if o and o:IsShown() and not InCombatLockdown() then o:Hide() end
end
-- QUESTS BLIZZARD'S TRACKER HAS NO HEADER FOR (11-22, GitHub #141): it builds only the quests that fit
-- its height. For those the overlay runs a macro instead: Blizzard's own quest log button opens the
-- map (untainted, as a click on it), then a secure button clicks that quest's title in the log, which
-- Blizzard's code opens (QuestMapLogTitleButton_OnClick). The picker aims at its target in its
-- PreClick, out of a fight: the details' Back button when another quest's details are open (the
-- macro clicks it twice: back, then the quest), else the quest's title. If the log hides the quest
-- (collapsed, filtered), the map and log still open. Idea from the tracker research (11-22).
function OT.QuestPicker()
    local picker = OT.questPicker
    if picker then return picker end
    picker = CreateFrame("Button", "FlareUIQuestPick", UIParent, "SecureActionButtonTemplate")
    picker:SetAttribute("type", "click")
    picker:SetScript("PreClick", function(self)
        if InCombatLockdown() then return end
        local want, target = self.questID, nil
        local details = QuestMapFrame and QuestMapFrame.DetailsFrame
        if details and details:IsVisible() then
            if details.questID ~= want then target = details.BackFrame and details.BackFrame.BackButton end
        elseif want and QuestLogQuests_GetQuestButton then
            local b = QuestLogQuests_GetQuestButton(want)
            if b and b:IsVisible() then target = b end
        end
        self:SetAttribute("clickbutton", target)
    end)
    OT.questPicker = picker
    return picker
end
-- (#141: in the Gamepad UI a mouse click goes here too; the controller's own press keeps
-- OT.PickForQuestLog)
function OT.ShowSecureClick(line)
    if InCombatLockdown() or state.editMode then return end
    local questID = line.questID
    if not questID or line.popupQuestID or line.zone or line.recipeID then OT.HideSecureClick() return end
    local headerButton = OT.BlizzardQuestHeader(questID)
    if not headerButton then
        -- (a finished auto-complete quest completes from the line's own click)
        local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
        local info = logIndex and C_QuestLog.GetInfo(logIndex)
        if not (QuestLogQuests_GetQuestButton and _G.QuestLogMicroButton) or not logIndex
            or (info and info.isAutoComplete and C_QuestLog.IsComplete(questID)) then
            OT.HideSecureClick()
            return
        end
    end
    local o = OT.secureClick
    if not o then
        o = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
        o:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
        o:SetAttribute("useOnKeyDown", false)
        -- the picker path: the macro, written as the click comes (the map open or not)
        o:SetScript("PreClick", function(self, button)
            if InCombatLockdown() or self:GetAttribute("type1") ~= "macro" or button ~= "LeftButton" then return end
            local open = WorldMapFrame and WorldMapFrame:IsShown()
            self:SetAttribute("macrotext1", (open and "" or "/click QuestLogMicroButton\n")
                .. "/click FlareUIQuestPick\n/click FlareUIQuestPick")
        end)
        -- (only the plain left click: a modified one finds no "shift-type1" and takes the line's path)
        o:SetScript("PostClick", function(self, button)
            local l = self.line
            if not l then return end
            if button == "LeftButton" and not IsModifierKeyDown() then return end   -- Blizzard's header took it
            OnLineClick(l, button)
        end)
        o:SetScript("OnEnter", function(self)
            local l = self.line
            local onEnter = l and l:GetScript("OnEnter")
            if onEnter then onEnter(l) end
        end)
        o:SetScript("OnLeave", function(self)
            local l = self.line
            local onLeave = l and l:GetScript("OnLeave")
            if onLeave then onLeave(l) end
            OT.HideSecureClick()
        end)
        OT.secureClick = o
    end
    -- only the part of the line inside the list (it clips what scrolls out)
    local left, right, top, bottom = line:GetLeft(), line:GetRight(), line:GetTop(), line:GetBottom()
    if not (left and right and top and bottom) then return end
    if scroll and scroll:GetTop() then
        top, bottom = math.min(top, scroll:GetTop()), math.max(bottom, scroll:GetBottom())
    end
    if top <= bottom then OT.HideSecureClick() return end
    local s = line:GetEffectiveScale() / o:GetEffectiveScale()
    o:SetFrameStrata(line:GetFrameStrata())
    o:SetFrameLevel(line:GetFrameLevel() + 1)
    o:ClearAllPoints()
    o:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * s, top * s)
    o:SetSize((right - left) * s, (top - bottom) * s)
    if headerButton then
        o:SetAttribute("type1", "click")
        o:SetAttribute("clickbutton1", headerButton)
    else
        OT.QuestPicker().questID = questID
        o:SetAttribute("type1", "macro")
        o:SetAttribute("clickbutton1", nil)
    end
    o.line = line
    o:Show()
end

local function GetLine(i)
    local line = lines[i]
    if line then return line end
    line = Build.Line(content)
    line:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    line:SetScript("OnClick", OnLineClick)
    line:SetScript("OnEnter", function(self)
        if state.editMode then return end
        -- (a quest line: the secure click goes over it; from it, this runs again for the tooltip)
        if not (OT.secureClick and OT.secureClick.line == self and OT.secureClick:IsShown()) then OT.ShowSecureClick(self) end
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

-- Quest animations. Only for a reason: a quest accepted or turned in, an objective moved on or finished. Data
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

-- Blizzard's tracker glow (Blizzard_ObjectiveTrackerAnimTemplates.xml): a bar of light that grows out
-- from the left of the text, then fades. Its widths are Blizzard's, cut to the line's width.
--   line:  an objective added, moved on or finished (its GlowAnim)
--   title: a quest just accepted, on its title (the block's AddAnim)
--   leave: a quest turned in, on its title as it slides away (TurnInAnim, its sweep fitted into the slide)
C.GLOW = {
    atlas = "ui-questtracker-objfx-barglow",
    line = { width = 180, x = -2, top = 0, bottom = -4, delay = 0.1, grow = 0.66, smooth = "OUT", fadeDelay = 0.33, fade = 0.58 },
    title = { width = 240, x = 0, top = 3, bottom = -4, delay = 0.15, grow = 0.31, smooth = "NONE", fadeDelay = 0.33, fade = 0.41 },
    leave = { width = 240, x = 0, top = 3, bottom = -4, delay = 0, grow = C.LEAVE_TIME, smooth = "NONE", fadeDelay = C.LEAVE_TIME, fade = 0.1 },
}

-- Stops a line's glow (and the fallback band) at once, so a pooled line never carries it to another quest
function Build.StopGlow(line)
    if not line.glowing then return end
    line.glowing = nil
    if line.glowAnim then
        line.glowAnim:Stop()
        line.glow:SetAlpha(0)
    end
    if line.sheen then
        line.sheen.anim:Stop()
        line.sheen:Hide()
    end
end

-- A glow kept only while its line still shows the quest and the text it was lit for
function Build.CheckGlow(line)
    if line.glowing and (not line:IsShown() or line.questID ~= line.glowQuest or line.kind ~= line.glowKind
            or (line.kind == "objective" and line.ftText ~= line.glowText)) then
        Build.StopGlow(line)
    end
end

-- Plays one of C.GLOW's kinds on a line; one texture and one animation group per pooled line
function Build.PlayGlow(line, kind)
    local cfg = C.GLOW[kind]
    if not (cfg and Build.ArtInfo(C.GLOW.atlas)) then return false end
    local g = line.glowAnim
    if not g then
        local tex = line:CreateTexture(nil, "OVERLAY")
        tex:SetAtlas(C.GLOW.atlas)
        tex:SetAlpha(0)
        line.glow = tex
        g = line:CreateAnimationGroup()
        g:SetToFinalAlpha(true)
        g.grow = g:CreateAnimation("Scale")
        g.grow:SetTarget(tex)
        g.grow:SetScaleFrom(0, 1)
        g.grow:SetScaleTo(1, 1)
        g.grow:SetOrigin("LEFT", 0, 0)
        g.grow:SetOrder(1)
        g.show = g:CreateAnimation("Alpha")
        g.show:SetTarget(tex)
        g.show:SetFromAlpha(0)
        g.show:SetToAlpha(1)
        g.show:SetDuration(0)
        g.show:SetOrder(1)
        g.fade = g:CreateAnimation("Alpha")
        g.fade:SetTarget(tex)
        g.fade:SetFromAlpha(1)
        g.fade:SetToAlpha(0)
        g.fade:SetOrder(1)
        g:SetScript("OnFinished", function()
            line.glowing = nil
            tex:SetAlpha(0)
        end)
        line.glowAnim = g
    end
    Build.StopGlow(line)
    local tex = line.glow
    tex:ClearAllPoints()
    if kind == "line" then
        tex:SetPoint("LEFT", line.text, "LEFT", cfg.x, 0)
        tex:SetPoint("TOP", line, "TOP", 0, cfg.top)
        tex:SetPoint("BOTTOM", line, "BOTTOM", 0, cfg.bottom)
    else
        tex:SetPoint("TOPLEFT", line.text, "TOPLEFT", cfg.x, cfg.top)
        tex:SetPoint("BOTTOMLEFT", line.text, "BOTTOMLEFT", cfg.x, cfg.bottom)
    end
    tex:SetWidth(math_min(cfg.width, (line.ftWidth or cfg.width) + 4))
    g.grow:SetStartDelay(cfg.delay)
    g.grow:SetDuration(cfg.grow)
    g.grow:SetSmoothing(cfg.smooth)
    g.fade:SetStartDelay(cfg.fadeDelay)
    g.fade:SetDuration(cfg.fade)
    line.glowing, line.glowQuest, line.glowText, line.glowKind = true, line.questID, line.ftText, line.kind
    g:Play()
    return true
end

-- An objective's glow; without Blizzard's atlas, a soft band of light that crosses the line's text once
local function PlaySheen(line)
    if Build.PlayGlow(line, "line") then return end
    Build.StopGlow(line)
    line.glowing, line.glowQuest, line.glowText, line.glowKind = true, line.questID, line.ftText, line.kind
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
        g:SetScript("OnFinished", function()
            band:Hide()
            line.glowing = nil
        end)
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

-- The focus button, left of a title; pointing at it counts as pointing at the quest
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

-- Quest Icons: the round quest button of Blizzard's tracker, left of each title: a
-- yellow "..." while in progress, a "?" when ready to turn in, the focused quest in Blizzard's
-- selected look (its own ring, brown dots, the outer glow). Blizzard's atlases (Blizzard_POIButton
-- POIButton.lua) on a button of FlareUI's own: POIButtonTemplate's mixin reaches into map pins,
-- quest caches and the highlight manager, so none of that runs from here. A click focuses the
-- quest, or stops focusing it, as ToggleFocus does.
function Build.SizeAtlas(tex, atlas, k)
    tex:SetAtlas(atlas, true)
    local w, h = tex:GetSize()
    if w and h then tex:SetSize(w * k, h * k) end
end

function Build.QuestIcon(line)
    local b = CreateFrame("Button", nil, line)
    b:SetSize(C.POI_SIZE, C.POI_SIZE)
    local k = C.POI_SIZE / C.POI_BLIZZARD
    b.glow = b:CreateTexture(nil, "BACKGROUND")
    b.glow:SetPoint("CENTER")
    b.glow:SetBlendMode("ADD")
    Build.SizeAtlas(b.glow, "UI-QuestPoi-OuterGlow", k * C.POI_GLOW_SCALE)
    b.glow:SetAlpha(C.POI_GLOW_ALPHA)
    b.ring = b:CreateTexture(nil, "ARTWORK")
    b.ring:SetPoint("CENTER")
    b.mark = b:CreateTexture(nil, "OVERLAY")
    b.mark:SetPoint("CENTER")
    -- (a Button shows its HIGHLIGHT layer while pointed at)
    b.lit = b:CreateTexture(nil, "HIGHLIGHT")
    b.lit:SetPoint("CENTER")
    b.lit:SetBlendMode("ADD")
    Build.SizeAtlas(b.lit, "UI-QuestPoi-InnerGlow", k)
    return b
end

-- done: ready to turn in; focused: the super-tracked quest; pressed: held down (Blizzard's pressed ring)
function Build.PaintQuestIcon(b, done, focused, pressed)
    local k = C.POI_SIZE / C.POI_BLIZZARD
    Build.SizeAtlas(b.ring, "UI-QuestPoi-QuestNumber" .. (pressed and "-Pressed" or "") .. (focused and "-SuperTracked" or ""), k)
    local mark = done and "UI-QuestIcon-TurnIn-Normal"
        or (focused and "Quest-In-Progress-Icon-Brown" or "Quest-In-Progress-Icon-yellow")
    Build.SizeAtlas(b.mark, mark, k)
    b.mark:SetPoint("CENTER", pressed and 1 or 0, pressed and -1 or 0)
    b.glow:SetShown(focused and true or false)
end

function OT.QuestIconButton(line)
    local b = line.questIcon
    if b then return b end
    b = Build.QuestIcon(line)
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnEnter", function(self) local p = self:GetParent(); p:GetScript("OnEnter")(p) end)
    b:SetScript("OnLeave", function(self) local p = self:GetParent(); p:GetScript("OnLeave")(p) end)
    b:SetScript("OnMouseDown", function(self) Build.PaintQuestIcon(self, self.ftDone, self.ftFocus, true) end)
    b:SetScript("OnMouseUp", function(self) Build.PaintQuestIcon(self, self.ftDone, self.ftFocus, false) end)
    b:SetScript("OnClick", function(self)
        if not self.questID or state.editMode then return end
        local focused = C_SuperTrack.GetSuperTrackedQuestID() == self.questID
        if SOUNDKIT then PlaySound(focused and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
        ToggleFocus(self.questID)
    end)
    line.questIcon = b
    return b
end

-- Places a title's quest icon (painted again only when its state changed)
function Build.PlaceQuestIcon(b, line, x, titleCfg, done, focused)
    done, focused = done and true or false, focused and true or false
    if b.ftDone ~= done or b.ftFocus ~= focused then
        b.ftDone, b.ftFocus = done, focused
        Build.PaintQuestIcon(b, done, focused, false)
    end
    b:ClearAllPoints()
    b:SetPoint("RIGHT", line, "TOPLEFT", x + 1, -FontHeight(titleCfg, 12) / 2)
    b:Show()
end

-- Collapsible Zones: Blizzard's tracker's section arrow (collapse / expand) at a heading's right end
function Build.FoldIcon(line, show, folded, cfg)
    local icon = line.foldIcon
    if not show then
        if icon then icon:Hide() end
        return
    end
    if not icon then
        icon = line:CreateTexture(nil, "ARTWORK")
        line.foldIcon = icon
    end
    local h = FontHeight(cfg, 13) - 2
    local atlas = folded and C.FOLD_EXPAND or C.FOLD_COLLAPSE
    if icon.ftAtlas ~= atlas or icon.ftH ~= h then
        icon.ftAtlas, icon.ftH = atlas, h
        icon:SetAtlas(atlas, true)
        local w0, h0 = icon:GetSize()
        if w0 and h0 and h0 > 0 then icon:SetSize(w0 * h / h0, h) else icon:SetSize(h, h) end
    end
    icon:ClearAllPoints()
    icon:SetPoint("LEFT", line, "TOPRIGHT", 2, -(h + 2) / 2)
    icon:Show()
end

-- Voice lines from the Spoken addon's quest part, when it is installed, switched on and has this quest;
-- or (11-21, Archy) from Wayfarer, the Russian voice-over (global WayfarerRU), through the calls its
-- player described: Core:QuestVoice, QuestLog:Play, Queue.items / Queue:RemoveWhere, UI:Refresh. Every
-- one guarded: Wayfarer isn't installed here, so a change on its side only hides the button.
local function SpokenReady()
    local spoken, voice = _G.Spoken, _G.VoiceOver
    return spoken and voice and voice.DataModules and voice.QuestOverlayUI and voice.Player
        and spoken.IsPartOn and spoken:IsPartOn("quests")
end
function OT.Wayfarer()
    local w = _G.WayfarerRU
    if type(w) == "table" and type(w.Core) == "table" and type(w.QuestLog) == "table" and type(w.Queue) == "table" then return w end
end
local function VoiceOverReady()
    return SpokenReady() or OT.Wayfarer() ~= nil
end

local function SpokenHas(questID)
    local voice = _G.VoiceOver
    if not (voice and SpokenReady()) then return false end
    local ok, sound = pcall(voice.DataModules.PrepareSound, voice.DataModules,
        { event = voice.Enums.SoundEvent.QuestAccept, questID = questID })
    return ok and sound
end
function OT.WayfarerHas(questID)
    local w = OT.Wayfarer()
    if not (w and questID) then return false end
    local ok, line = pcall(w.Core.QuestVoice, w.Core, questID)
    return ok and line ~= nil
end
local function HasVoice(questID)
    return SpokenHas(questID) or OT.WayfarerHas(questID)
end

local function VoiceQueued(questID)
    if not questID then return nil end
    local voice = _G.VoiceOver
    if voice and SpokenHas(questID) then
        local ok, queued = pcall(voice.QuestOverlayUI.QueuedLine, voice.QuestOverlayUI, questID)
        return ok and queued or nil
    end
    local w = OT.Wayfarer()
    local items = w and type(w.Queue.items) == "table" and w.Queue.items
    if items then
        for _, item in pairs(items) do
            if type(item) == "table" and item.questID == questID then return item end
        end
    end
    return nil
end

-- The voice button: a small square box at the right end of a quest's title, its glyph inside at
-- seven tenths of it, dim until pointed at. All Blizzard art:
-- - the box: the checkbox-minimal atlas, an added copy of it lit while pointed at (as Blizzard's own
--   checkbox buttons light theirs), or the old checkbox where the atlas is missing
-- - play: the arrow of Blizzard's square buttons (its left-arrow cell, flipped as SquareButton_SetIcon
--   flips it for RIGHT), cut close to the arrow and drawn a little narrower than tall
-- - stop: the stopwatch's pause bars, cut from their button; the button's face is black, so the
--   glyph is added over the box and the face drops out
-- - replay: Blizzard's refresh arrow (the group finder's refresh button)
-- wide: the glyph's width as a share of its height; add: drawn with additive blending
C.VOICE = {
    BOX = "checkbox-minimal",
    BOX_FILE = "Interface\\Buttons\\UI-CheckBox-Up", LIT_FILE = "Interface\\Buttons\\UI-CheckBox-Highlight",
    GLYPH = 0.7,            -- the glyph's size, as a share of the box
    DIM = 0.6,              -- the glyph's alpha until pointed at
    LIT = 0.6,              -- the box's light while pointed at
    GAP = 3,                -- from the end of the title's text area to the box
    MIN = 12, MAX = 20,     -- the box follows the title font's height, within these
    play = { file = "Interface\\Buttons\\SquareButtonTextures", coords = { 23 / 64, 19 / 64, 0, 14 / 64 }, wide = 0.7 },
    stop = { file = "Interface\\TimeManager\\PauseButton", coords = { 9 / 32, 23 / 32, 9 / 32, 23 / 32 }, add = true },
    replay = { file = "Interface\\Buttons\\UI-RefreshButton", coords = { 0, 1, 0, 1 } },
}
-- shared with the settings preview, which draws the same button
OT.VoiceArt = C.VOICE

-- the box's side for a title font, and the room it takes right of the title
function Build.VoiceSize(cfg)
    return math_max(C.VOICE.MIN, math_min(C.VOICE.MAX, FontHeight(cfg, 12)))
end
function Build.VoiceRoom(cfg) return Build.VoiceSize(cfg) + C.VOICE.GAP end

function Build.VoiceButton(line)
    local art = C.VOICE
    local b = CreateFrame("Button", nil, line)
    b:SetSize(art.MIN, art.MIN)
    b.box = b:CreateTexture(nil, "BACKGROUND")
    b.box:SetAllPoints()
    -- (a Button shows its HIGHLIGHT layer while pointed at)
    b.lit = b:CreateTexture(nil, "HIGHLIGHT")
    b.lit:SetAllPoints()
    if Build.ArtInfo(art.BOX) then
        b.box:SetAtlas(art.BOX)
        b.lit:SetAtlas(art.BOX)
    else
        b.box:SetTexture(art.BOX_FILE)
        b.lit:SetTexture(art.LIT_FILE)
    end
    b.lit:SetBlendMode("ADD")
    b.lit:SetAlpha(art.LIT)
    b.glyph = b:CreateTexture(nil, "ARTWORK")
    b.glyph:SetPoint("CENTER")
    b.glyph:SetAlpha(art.DIM)
    return b
end

-- look: "play", "stop" or "replay"; written only when the look or the box's size changed
function Build.PaintVoiceGlyph(b, look)
    local art = C.VOICE
    local size = b.ftVoiceSize or art.MIN
    if b.ftVoice == look and b.ftGlyphSize == size then return end
    b.ftVoice, b.ftGlyphSize = look, size
    local spec, glyph = art[look] or art.play, b.glyph
    local c = spec.coords
    glyph:SetTexture(spec.file)
    glyph:SetTexCoord(c[1], c[2], c[3], c[4])
    glyph:SetBlendMode(spec.add and "ADD" or "BLEND")
    local h = math_floor(size * art.GLYPH + 0.5)
    glyph:SetSize(spec.wide and math_floor(h * spec.wide + 0.5) or h, h)
end

-- Stop while this quest's line is queued (speaking or waiting: a click takes it off either way),
-- Replay once it has played or been stopped, else Play. The previews' buttons have no quest: Play.
function Build.VoiceState(questID)
    if not questID then return "play" end
    if VoiceQueued(questID) then return "stop" end
    return state.voicePlayed[questID] and "replay" or "play"
end

local function PaintPlayButton(b)
    Build.PaintVoiceGlyph(b, Build.VoiceState(b.questID))
end

-- at the right end of the title's first line, in the room the title leaves for it
function Build.PlaceVoiceButton(b, line, titleCfg)
    local size = Build.VoiceSize(titleCfg)
    if b.ftVoiceSize ~= size then
        b.ftVoiceSize = size
        b:SetSize(size, size)
    end
    PaintPlayButton(b)
    b:ClearAllPoints()
    b:SetPoint("LEFT", line, "TOPRIGHT", C.VOICE.GAP, -FontHeight(titleCfg, 12) / 2)
    b:Show()
end

local function TogglePlay(self)
    local voice, questID = _G.VoiceOver, self.questID
    -- the previews' buttons do nothing
    if state.editMode or not (questID and VoiceOverReady() and HasVoice(questID)) then return end
    local queued = VoiceQueued(questID)
    -- Wayfarer's line (Spoken has none for this quest): its own queue plays and stops it
    if not SpokenHas(questID) then
        local w = OT.Wayfarer()
        if not w then return end
        if queued then
            pcall(w.Queue.RemoveWhere, w.Queue, function(item) return type(item) == "table" and item.questID == questID end)
            state.voicePlayed[questID] = true
        else
            pcall(w.QuestLog.Play, w.QuestLog, questID)
        end
        PaintPlayButton(self)
        return
    end
    if queued then
        voice.Player:Remove(queued)
        state.voicePlayed[questID] = true
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

-- the tracker's voice button: pointing at it lights the glyph and counts as pointing at the quest
function OT.VoiceButton(line)
    local b = line.playButton
    if b then return b end
    b = Build.VoiceButton(line)
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnEnter", function(self)
        self.glyph:SetAlpha(1)
        local p = self:GetParent(); p:GetScript("OnEnter")(p)
    end)
    b:SetScript("OnLeave", function(self)
        self.glyph:SetAlpha(C.VOICE.DIM)
        local p = self:GetParent(); p:GetScript("OnLeave")(p)
    end)
    b:SetScript("OnClick", TogglePlay)
    line.playButton = b
    return b
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
    b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cooldown:SetAllPoints(b.icon)
    -- FlareUI's frame border, as on the action bars' FlareUI Borders: Blizzard's bronze frame
    -- goes invisible, FlareUI Frames rounds the icon (not the button, so nothing shows past it), its
    -- edge scaled to the icon's size like the Cooldown Manager's icons (16 px at 50 px)
    b:GetNormalTexture():SetAlpha(0)
    b.border = CreateFrame("Frame", nil, b, "BackdropTemplate")
    b.border:SetAllPoints(b.icon)
    local file = LSM:Fetch("border", "FlareUI Frames")
    b.border:SetBackdrop({ edgeFile = file, edgeSize = ns.BorderEdgeSize(file, math.floor(16 * size / 50 + 0.5)) })
    local c = ns.BORDER_COLOR
    b.border:SetBackdropBorderColor(c.r, c.g, c.b, c.a or 1)
    -- over the cooldown swipe; the count over the border
    b.border:SetFrameLevel(b:GetFrameLevel() + 2)
    local texts = CreateFrame("Frame", nil, b)
    texts:SetAllPoints()
    texts:SetFrameLevel(b:GetFrameLevel() + 3)
    b.count = texts:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    b.count:SetPoint("BOTTOMRIGHT", -2, 2)
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
    local c
    if questID and HaveQuestData(questID) then
        c = GetDifficultyColor(C_PlayerInfo.GetContentDifficultyQuestForPlayer(questID))
    else
        c = GetQuestDifficultyColor(level)
    end
    -- FlareUI colour scheme: the same colour in a softer tone (one table per colour, kept)
    if OT.soft and c then
        Build.softDifficulty = Build.softDifficulty or {}
        local key = string_format("%.3f %.3f %.3f", c.r, c.g, c.b)
        local soft = Build.softDifficulty[key]
        if not soft then
            local r, g, b = ns.SoftColor(c.r, c.g, c.b)
            soft = { r = r, g = g, b = b }
            Build.softDifficulty[key] = soft
        end
        return soft
    end
    return c
end

-- Colour Names by Difficulty: the name in its level's colour, unless complete or focused (one
-- table per colour, so a line keeps its colour between renders)
-- Show Complete Tag (on by default): a green "(Complete)" after a finished quest's name; the name and
-- its turn-in line keep their usual colours either way
function Build.CompleteTag(db) return db.showCompleteTag ~= false end

function Build.DoneColor() return C.OBJECTIVE end

-- Room left of the titles (Quest Buttons): a quest icon and a focus dot, either or both. (The voice
-- button sits right of the title: Build.VoiceRoom.)
function Build.TitleRoom(db)
    return (db.questIcons and C.POI_ROOM or 0) + (db.focusButtons and C.BUTTON_ROOM or 0)
end

-- the focus dot: yellow on the focused quest, grey on the others
function Build.PaintFocusDot(b, focused)
    b.icon:SetTexture(focused and "Interface\\Common\\Indicator-Yellow" or "Interface\\Common\\Indicator-Gray")
end
-- its click (one function for every dot, not a new one each render)
function Build.OnFocusClick(self)
    if self.questID and not state.editMode then ToggleFocus(self.questID) end
end

-- the focused quest is blue only while no Quest Icon or Focus Button shows which one it is
function Build.TitleColor(db, level, questID, focus, done)
    if focus and not (db.questIcons or db.focusButtons) then return C.TITLE_FOCUS end
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

-- done: a finished quest gets a green "(Complete)" after its name (shown when folded too), unless
-- Show Complete Tag is off
function Build.TitleText(db, level, tags, title, collapsed, questID, done)
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
    -- a language FlareUI hasn't translated it into takes the game's own word (COMPLETE)
    local word = L["(Complete)"]
    if word == "(Complete)" and type(COMPLETE) == "string" and COMPLETE ~= "" then word = "(" .. COMPLETE .. ")" end
    local tag = (done and Build.CompleteTag(db)) and (" " .. ColorCode(C.TITLE_DONE) .. word .. "|r") or ""
    return prefix .. title .. tag .. (collapsed and ("  " .. ColorCode(C.DIM) .. "+|r") or "")
end

-- The header's title (with the count), the zone switch and the minimize button, placed
function Build.LayoutHeader(head, db, count, max, minimized)
    local title = TEXT.quests
    -- the quest count, always
    title = title .. "  " .. ColorCode(C.DIM) .. (max and (count .. "/" .. max) or count) .. "|r"
    head.title:SetText(title)
    head.zone.active = db.zoneOnly or nil
    head.zone:Paint(head.zone.lit)

    -- title on the left; the zone switch and the minimize button on the right
    local button = head.minimize
    button:ClearAllPoints()
    head.title:ClearAllPoints()
    head.zone:ClearAllPoints()
    head.sort:ClearAllPoints()
    button:SetPoint("RIGHT", head, "RIGHT", 0, 0)
    -- Header Buttons (Display): the filter and the sort, each left of the last one shown
    local last = button
    head.zone:SetShown(db.headerFilter ~= false)
    if head.zone:IsShown() then
        head.zone:SetPoint("RIGHT", last, "LEFT", -4, 0)
        last = head.zone
    end
    head.sort:SetShown(db.headerSort ~= false)
    if head.sort:IsShown() then
        head.sort:SetPoint("RIGHT", last, "LEFT", -4, 0)
        last = head.sort
    end
    head.lastButton = last
    Build.LayoutAutoButtons(head, db)
    head.title:SetPoint("LEFT", head, "LEFT", C.PAD - C.HEADER_INSET, 0)
    button:SetPlus(minimized)
    -- Header Art: Blizzard's title strip behind the header, reaching past it as on Blizzard's tracker
    if Build.HeaderArtOn(db) then
        local reach = Build.ArtReach(C.ART_TITLE)
        local leftOut = reach - C.ART_KNOB_IN + C.ART_TITLE_LEFT
        local rightOut = reach + C.ART_TITLE_RIGHT - C.ART_KNOB_IN - C.ART_TITLE_LEFT
        -- (C.ART_TITLE_DOWN: the knobs onto the Thick border's curve, as the chat's; FlareUI style only,
        -- the Blizzard style has no border and keeps its spot)
        local down = Build.FrameStyle(db) == "flareui" and -C.ART_TITLE_DOWN or nil
        Build.PlaceStrip(head, C.ART_TITLE, leftOut, rightOut, nil, down)
        -- and its bottom line, knobs and all, along the frame's bottom border: FlareUI style only (Blizzard
        -- has no border to put it on), and not while minimized (the frame is the header alone then)
        if minimized or Build.FrameStyle(db) ~= "flareui" then
            Build.HideStrip(head.foot)
        else
            Build.PlaceStrip(head.foot, C.ART_TITLE, leftOut, rightOut, C.ART_FOOT_BAND)
        end
    else
        Build.HideStrip(head)
        Build.HideStrip(head.foot)
    end
end

-- HEADER ART (Look > Frame Style: Blizzard and FlareUI, not Custom): Blizzard's own tracker strips behind the title and each zone
-- heading. Blizzard draws them at their own size on a header of fixed width, and FlareUI's tracker
-- can be any width: stretched whole, their ends stretch too. So each strip is cut in three: both ends
-- at their own width, and a thin slice of the plain middle stretched between them. Sizes and
-- coordinates come from the game (C_Texture.GetAtlasInfo), so no size is guessed.
C.ART_TITLE = "ui-questtracker-primary-objective-header"
C.ART_HEADING = "UI-QuestTracker-Secondary-Objective-Header"
C.ART_FRAME = 260   -- Blizzard's header width: its strips reach past it on both sides
C.ART_TEXT = 7      -- Blizzard's text inset on its headers
C.ART_CAP = 0.3     -- each end of a strip, as a share of its width
C.ART_PAD = 5       -- more room above and below a zone heading with its strip
C.ART_TITLE_RIGHT = 8   -- the title strip's art sits off its centre: its right end goes this much further out
C.ART_TITLE_LEFT = 1    -- and the whole title strip one pixel to the left, to sit centred on the border
C.ART_FOOT_BAND = { 31 / 40, 38 / 40 }   -- the title strip's bottom line with its knobs, for the frame's foot
C.ART_FOOT_Y = 2.5      -- that line's middle, up from the frame's bottom edge (on the border, as the knobs at the top;
                        -- 2.5 and ART_TITLE_DOWN -0.5 (up) fitted to the Thick border's curve in game, Malkkav 11-20)
C.ART_TITLE_DOWN = -0.5 -- the title strip this far below the header's middle
C.ART_KNOB_IN = 2       -- the title strip's end knobs sit on the frame border, half of each knob outside it
C.ART_HEADING_IN = 5    -- a zone heading's strip stays this far inside the frame border and the scroll bar
Build.artInfo = {}
function Build.ArtInfo(atlas)
    local info = Build.artInfo[atlas]
    if info == nil then
        local ok, found = pcall(C_Texture.GetAtlasInfo, atlas)
        info = ok and type(found) == "table" and found.file and (found.width or 0) > 0 and found or false
        Build.artInfo[atlas] = info
    end
    return info or nil
end
-- Frame Style: "blizzard" (strips, no background, border or scroll bar), "flareui" (strips on FlareUI's
-- frame, the default) or "custom" (the Modern style: no strips; the Background Opacity and Border chosen)
function Build.FrameStyle(db)
    local style = db and db.frameStyle
    if style == "blizzard" or style == "custom" then return style end
    return "flareui"
end
function Build.HeaderArtOn(db) return Build.FrameStyle(db) ~= "custom" end
-- the scroll bar: never in the Blizzard style; Hide Scroll Bar (FlareUI and Modern) drops it. The thumb sits
-- in the list's margin, so the text keeps its width either way; the mouse wheel always scrolls.
function Build.ScrollBarShown(db)
    return Build.FrameStyle(db) ~= "blizzard" and not (db and db.hideScrollBar)
end
-- how far a strip reaches past Blizzard's header on each side (its see-through ends)
function Build.ArtReach(atlas)
    local info = Build.ArtInfo(atlas)
    return info and math_max(0, (info.width - C.ART_FRAME) / 2) or 0
end

function Build.HideStrip(owner)
    local s = owner.ftStrip
    if s then s.L:Hide(); s.M:Hide(); s.R:Hide() end
end

-- the strip behind owner, centred on its height: from leftOut past its left edge to rightOut past
-- its right edge
-- band (optional): { from, to }, the part of the strip's height to draw, 0 at its top and 1 at its bottom
-- dy (optional): moves the strip up (+) or down (-) off its owner's middle, sub-pixel (no snapping)
function Build.PlaceStrip(owner, atlas, leftOut, rightOut, band, dy)
    local info = Build.ArtInfo(atlas)
    if not info then Build.HideStrip(owner) return end
    local s = owner.ftStrip
    if not s then
        s = {}
        for _, part in ipairs({ "L", "M", "R" }) do
            local tex = owner:CreateTexture(nil, "BACKGROUND", nil, -1)
            tex:SetSnapToPixelGrid(false)
            tex:SetTexelSnappingBias(0)
            tex:Hide()
            s[part] = tex
        end
        owner.ftStrip = s
    end
    local l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
    local height = info.height
    if band then
        local tall = b - t
        t, b = t + tall * band[1], t + tall * band[2]
        height = info.height * (band[2] - band[1])
    end
    local span = r - l
    local cap = math_floor(info.width * C.ART_CAP + 0.5)
    local capSpan = span * cap / info.width
    local mid = l + span / 2
    for _, tex in pairs(s) do
        tex:SetTexture(info.file)
        tex:ClearAllPoints()
        tex:SetHeight(height)
        tex:Show()
    end
    s.L:SetTexCoord(l, l + capSpan, t, b)
    s.L:SetWidth(cap)
    s.L:SetPoint("LEFT", owner, "LEFT", -leftOut, dy or 0)
    s.R:SetTexCoord(r - capSpan, r, t, b)
    s.R:SetWidth(cap)
    s.R:SetPoint("RIGHT", owner, "RIGHT", rightOut, dy or 0)
    s.M:SetTexCoord(mid - span * 0.005, mid + span * 0.005, t, b)
    s.M:SetPoint("LEFT", s.L, "RIGHT")
    s.M:SetPoint("RIGHT", s.R, "LEFT")
end

-- a zone heading's strip: from Blizzard's frame edge left of the text to the list's right edge
function Build.HeadingArt(line, db, rightRoom)
    if not Build.HeaderArtOn(db) then Build.HideStrip(line) return end
    local reach = Build.ArtReach(C.ART_HEADING) + C.ART_TEXT - C.ART_HEADING_IN
    Build.PlaceStrip(line, C.ART_HEADING, reach, (rightRoom or 0) + reach)
end

function OT:Render()
    state.pending = false
    local db = GetDb()
    if not (db and holder) then return end
    -- (the lines may move: the secure click over one would point at another quest; the next hover
    -- puts it back)
    OT.HideSecureClick()
    if OT.ApplyColorScheme(db) then
        state.difficultyColors = nil
        if header then SetColor(header.title, C.HEADING) end
    end
    local char = Char()
    local minimized = char.minimized and not state.editMode
    local questGap = db.questGap or C.QUEST_GAP
    local inScenario = C_Scenario and C_Scenario.GetStepInfo
        and ((C_Scenario.IsInScenario and C_Scenario.IsInScenario()) or select(2, IsInInstance()) == "scenario")
    state.watchMoney = false
    wipe(state.sheens)
    state.pass = state.pass + 1

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
    local wrap = true   -- long lines always wrap

    -- Show Untracked Quests: lines added while this is on are dimmed
    local dimLines = false

    -- (what a pooled line was given last is kept: Build.LineLook); rightRoom: kept free right of the text
    local function AddLine(text, kind, color, indent, rightRoom)
        n = n + 1
        local line = GetLine(n)
        local h = Build.LineLook(line, text, kind, fonts[kind], color, width - (indent or 0) - (rightRoom or 0), wrap)
        if line.ftDim ~= dimLines then
            line.ftDim = dimLines
            line.text:SetAlpha(dimLines and C.UNTRACKED_ALPHA or 1)
        end
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
        if line.questIcon then line.questIcon:Hide() end
        if line.foldIcon then line.foldIcon:Hide() end
        Build.HideStrip(line)
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
    local function TitleText(level, tags, title, collapsed, questID, done)
        return Build.TitleText(db, level, tags, title, collapsed, questID, done)
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

    -- Collapsible Zones: a heading click folds it, and its fold arrow shows. Whether a heading is
    -- folded: as it was when the fight began while quest item buttons hold the list still
    -- (FreezeForCombat), else the character's choice
    local function ZoneFolded(name)
        local frozen = state.frozenZones
        if frozen then return frozen[name] and true or false end
        return char.collapsedZones[name] and true or false
    end
    local function AddHeading(text, name, folded)
        local art = Build.HeaderArtOn(db)
        if art then y = y - C.ART_PAD end
        local line = AddLine(text, "header", C.ZONE, nil, C.FOLD_ROOM)
        line.zone = name
        Build.FoldIcon(line, true, folded, fonts.header)
        Build.HeadingArt(line, db, C.FOLD_ROOM)
        if art then y = y - C.ART_PAD end
        return line
    end

    -- The running scenario's stage and objectives, which live in the parked tracker
    local function AddScenario()
        local name = C_Scenario.GetInfo()
        local stage, _, numCriteria = C_Scenario.GetStepInfo()
        local title = (canaccessvalue(name) and name) or (canaccessvalue(stage) and stage) or nil
        if not title or title == "" then return false end
        local collapsed = ZoneFolded(title)
        AddHeading(title, title, collapsed)
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
    local questIcons = db.questIcons
    local titleRoom = Build.TitleRoom(db)
    local objectiveIndent = C.INDENT + titleRoom
    local voiceRoom = Build.VoiceRoom(fonts.title)
    -- the room a title leaves on its right: only for a quest that gets the voice button
    local function TitleRightRoom(questID)
        return (showPlay and (previewing or HasVoice(questID))) and voiceRoom or nil
    end

    -- rightRoom: what TitleRightRoom gave the title (the voice button goes there)
    local function AddTitleButtons(line, questID, isFocused, done, rightRoom)
        local x = -3
        if questIcons then
            local b = OT.QuestIconButton(line)
            b.questID = questID
            Build.PlaceQuestIcon(b, line, x, fonts.title, done, isFocused)
            b:SetAlpha(dimLines and C.UNTRACKED_ALPHA or 1)
            x = x - C.POI_ROOM
        end
        if db.focusButtons then
            local b = LineButton(line, "focusButton")
            b.questID = questID
            Build.PaintFocusDot(b, isFocused)
            b:SetScript("OnClick", Build.OnFocusClick)
            b:ClearAllPoints()
            b:SetPoint("TOPRIGHT", line, "TOPLEFT", x, 0)
            b:Show()
            x = x - C.BUTTON_ROOM
        end
        if rightRoom then
            local b = OT.VoiceButton(line)
            b.questID = questID
            Build.PlaceVoiceButton(b, line, fonts.title)
            b:SetAlpha(dimLines and C.UNTRACKED_ALPHA or 1)
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
                        AddHeading(s.text, nil, false)
                        y = y - C.ZONE_GAP
                    end
                else
                    local color = TitleColor(s.level, nil, s.focus, s.done)
                    local rightRoom = TitleRightRoom(nil)
                    local line = AddLine(TitleText(s.level, s.tags or "", s.title, nil, nil, s.done), "title", color, titleRoom, rightRoom)
                    AddTitleButtons(line, nil, s.focus, s.done, rightRoom)
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
                -- (a folded zone that holds the focused quest stays folded: the player folded it)
                local zoneCollapsed = headings and ZoneFolded(q.ftHeader)
                if headings and q.ftHeader ~= lastHeader then
                    lastHeader = q.ftHeader
                    if n > 0 then y = y - C.GROUP_GAP end
                    local text = zoneCollapsed and string_format("%s  %s(%d)|r", q.ftHeader, ColorCode(C.DIM), zoneCounts[q.ftHeader]) or q.ftHeader
                    AddHeading(text, q.ftHeader, zoneCollapsed)
                    if not zoneCollapsed then y = y - C.ZONE_GAP end
                end
                if not zoneCollapsed then
                    dimLines = q.ftUntracked and true or false
                    local collapsed = IsCollapsed(q.questID)
                    local complete = C_QuestLog.IsComplete(q.questID)
                    local color = TitleColor(q.difficultyLevel or q.level, q.questID, q.questID == focused, complete)
                    local rightRoom = TitleRightRoom(q.questID)
                    local line = AddLine(TitleText(q.difficultyLevel or q.level, db.showTags and QuestTags(q) or "", q.title or "?", collapsed, q.questID, complete), "title", color, titleRoom, rightRoom)
                    line.questID, line.logIndex = q.questID, q.ftLogIndex
                    -- quest item buttons for tracked quests only, as on Blizzard's tracker
                    if not q.ftUntracked then titleLines[#titleLines + 1] = line end
                    AddTitleButtons(line, q.questID, q.questID == focused, complete, rightRoom)
                    -- what this quest looked like last time, to tell what has just finished
                    -- (only from the render just before: a quest out of sight in between starts afresh)
                    local seen = state.seen[q.questID]
                    if seen and seen.pass ~= state.pass - 1 then seen = nil end
                    local now = { complete = complete, pass = state.pass }
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
                            -- the plain "Ready for turn-in" line in Blizzard's grey (11-20: 6.13 only did it in the sample)
                            local doneText = CompleteText(q)
                            local ready = AddLine(doneText, "objective", doneText == TEXT.ready and C.READY or Build.DoneColor(db), objectiveIndent)
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
                                -- its progress at [-i]: the count done, or the text when it has none
                                local progress = obj.numFulfilled or obj.text
                                now[-i] = progress
                                if obj.text and obj.text ~= "" and not (db.hideFinished and obj.finished) then
                                    -- a progress-bar objective has no count in its text: Blizzard draws a bar
                                    local text = obj.text
                                    if obj.type == "progressbar" and not obj.finished and GetQuestProgressBarPercent then
                                        local pct = GetQuestProgressBarPercent(q.questID)
                                        if canaccessvalue(pct) and type(pct) == "number" then text = string_format("%s (%d%%)", text, pct) end
                                    end
                                    local row = AddLine(text, "objective", obj.finished and C.OBJECTIVE_DONE or C.OBJECTIVE, objectiveIndent)
                                    row.questID = q.questID
                                    -- lit when it finishes, or when its progress moves on ("3/10" to "4/10")
                                    local was = seen and seen[-i]
                                    if seen and ((obj.finished and seen[i] == false)
                                            or (was ~= nil and was ~= progress
                                                and not (type(was) == "number" and type(progress) == "number" and progress < was))) then
                                        state.sheens[#state.sheens + 1] = row
                                    end
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
                    dimLines = false
                end
            end
            -- forget the quests this render did not draw
            for id, s in pairs(state.seen) do
                if s.pass ~= state.pass then state.seen[id] = nil end
            end

            -- recipes tracked in the profession window, with each reagent as "in bags/needed"
            local recipes = db.showRecipes and C_TradeSkillUI and C_TradeSkillUI.GetRecipesTracked
                and C_TradeSkillUI.GetRecipesTracked(false) or {}
            state.recipes = #recipes
            if #recipes > 0 then
                empty = false
                if n > 0 then y = y - C.GROUP_GAP end
                local collapsedRecipes = ZoneFolded(TEXT.recipes)
                local text = collapsedRecipes and string_format("%s  %s(%d)|r", TEXT.recipes, ColorCode(C.DIM), #recipes) or TEXT.recipes
                AddHeading(text, TEXT.recipes, collapsedRecipes)
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
            local focusB, playB, iconB = line.focusButton, line.playButton, line.questIcon
            if line:IsMouseOver()
                    or (focusB and focusB:IsShown() and focusB:IsMouseOver())
                    or (playB and playB:IsShown() and playB:IsMouseOver())
                    or (iconB and iconB:IsShown() and iconB:IsMouseOver()) then
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
    divider:SetShown(showList and not Build.HeaderArtOn(db))   -- (Header Art: the strip takes its place)
    -- only when it moves: its OnVerticalScroll redoes the scroll bar and item buttons, which this
    -- render does at its end anyway
    local offset = scroll:GetVerticalScroll()
    local clamped = math_min(offset, math_max(0, contentHeight - listHeight))
    if clamped ~= offset then scroll:SetVerticalScroll(clamped) end
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
    local tracked = state.logTracked > 0 or inScenario or state.untrackedShown
        or (db.showRecipes and C_TradeSkillUI and C_TradeSkillUI.GetRecipesTracked
            and #C_TradeSkillUI.GetRecipesTracked(false) > 0)
    -- nothing tracked: no tracker
    -- Visibility Never (OT:SetNever): hidden, not just faded, so its lines take no mouse or tooltips
    local hide = (not tracked or state.never) and not state.editMode and not state.preview
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
    -- a pooled line now showing something else drops the glow it had
    for i = 1, #lines do Build.CheckGlow(lines[i]) end
    -- the sample quests of Edit Mode and the settings preview never glow
    local glows = not (state.editMode or state.preview)
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
                    if glows and line.kind == "title" then Build.PlayGlow(line, "title") end
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
    if glows then
        for _, line in ipairs(state.sheens) do PlaySheen(line) end
    end
end

function OT:QuestAccepted(questID)
    if questID then state.arriving[questID] = GetTime() end
end

-- Keep Quest Focus: when the game focuses a quest the moment it is accepted, the focus
-- goes back to the quest that had it (or to none). Focus the player sets by hand stays. The focus can
-- change just before or just after QUEST_ACCEPTED, so both orders are handled.
do
    local WINDOW = 2          -- seconds after the accept in which a focus on that quest counts as the game's
    local cur, curAt = nil, 0 -- quest focused now (0 none) and when it got the focus
    local before = 0          -- quest focused before that
    local pending             -- { quest, prev, untilAt } between the accept and the focus

    local function FocusNow()
        local id = C_SuperTrack.GetSuperTrackedQuestID()
        return type(id) == "number" and id or 0
    end

    local function Wanted()
        local db = GetDb()
        return db and db.keepFocus
    end

    -- a frame later, so Blizzard (and Questie) finish their own focus handling first
    local function Restore(questID, prev)
        C_Timer.After(0, function()
            if not Wanted() or FocusNow() ~= questID then return end
            OT.SetFocus(prev or 0)
        end)
    end

    function OT.KeepFocusManual()
        pending = nil
    end

    function OT.KeepFocusAccepted(questID)
        if not questID then return end
        if cur == nil then cur = FocusNow() end
        if not Wanted() then pending = nil; return end
        local now = GetTime()
        if cur == questID and now - curAt < 1 then
            -- the focus came first: hand it back to the one before
            pending = nil
            Restore(questID, before)
        elseif cur ~= questID then
            pending = { quest = questID, prev = cur, untilAt = now + WINDOW }
        end
    end

    function OT.KeepFocusChanged()
        local now, id = GetTime(), FocusNow()
        if cur == nil then cur = id end
        if id ~= cur then before, cur, curAt = cur, id, now end
        local p = pending
        if not p then return end
        if now > p.untilAt then
            pending = nil
        elseif id ~= 0 and id == p.quest then
            pending = nil
            if Wanted() then Restore(id, p.prev) end
        end
    end
end

-- Its lines slide off first, and the redraw that closes the gap waits for them
function OT:QuestTurnedIn(questID)
    if not questID then return end
    local dx, any = SlideDistance(), false
    for _, line in ipairs(lines) do
        if line:IsShown() and line.questID == questID then
            line.leaving = true
            LeaveLine(line, dx)
            if line.kind == "title" and not (state.editMode or state.preview) then Build.PlayGlow(line, "leave") end
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
    local thumb = holder and holder.ScrollThumb
    if not thumb then return end
    local contentHeight, listHeight = state.contentHeight or 0, state.listHeight or 0
    -- (Frame Style Blizzard: no scroll bar; the mouse wheel still scrolls)
    local scrollable = scroll:IsShown() and contentHeight > listHeight + 1 and Build.ScrollBarShown(GetDb())
    thumb:SetShown(scrollable)
    if not scrollable then return end
    local range = contentHeight - listHeight
    local offset = range > 0 and math_min(1, math_max(0, scroll:GetVerticalScroll() / range)) or 0
    Build.PlaceScrollBar(thumb, scroll, holder, contentHeight, listHeight, offset)
end

-- The thumb down the list's right margin, offset 0 (top) to 1 (bottom); no track behind it
function Build.PlaceScrollBar(thumb, list, window, contentHeight, listHeight, offset)
    local px = ns.PixelSize(window)
    local x = -(C.SCROLLBAR_INSET)
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
    if not (OT.SortsByDistance(db) and holder and holder:IsVisible() and scroll:IsShown()) then return end
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
        -- Keep the previous rank order. It remains valid while every adjacent pair is still
        -- ordered by the new distances; no new sort is needed just because the player moved.
        if not state.sortRanksReady then
            for i = 1, count do sortRankOld[i] = i end
            for i = count + 1, #sortRankOld do sortRankOld[i] = nil end
            table.sort(sortRankOld, ByOldDistance)
            state.sortRanksReady = true
        end
        local swapped = false
        for i = 2, count do
            if ByNewDistance(sortRankOld[i], sortRankOld[i - 1]) then swapped = true break end
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

-- Visibility Never: the window is hidden outright (Render), not left at 0% where its lines would still
-- show tooltips and take clicks; Edit Mode and the settings page still show it
function OT:SetNever(on)
    on = on and true or false
    if state.never == on then return end
    state.never = on
    if holder then self:Render() end
end

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
    -- folded zones hold too (a heading clicked in the fight folds once it ends)
    local zones = {}
    for name, v in pairs(Char().collapsedZones) do zones[name] = v end
    state.frozenZones = zones
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
    -- Auto Minimize on Flight Paths (11-19)
    if rules.taxi == "minimize" and UnitOnTaxi("player") then return "taxi" end
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
-- layout, attached or not, so a parked tracker would draw it at a thousandth of its size. While
-- Blizzard's is parked, the column keeps the player's own scale,
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
    -- the Frame section (dropdowns, sliders, switches); Fading comes after it (Visibility.lua), then the
    -- Fonts section, always last
    local Section, settings = ns.EditSections()
    Section("Frame", {
        { name = L["Width"], kind = LEM.SettingType.Slider, default = C.WIDTH, minValue = 180, maxValue = 500, valueStep = 1,
          get = get("width", C.WIDTH), set = set("width") },
        { name = L["Max Height"], kind = LEM.SettingType.Slider, default = C.MAX_HEIGHT, minValue = 150, maxValue = 1000, valueStep = 1,
          get = get("maxHeight", C.MAX_HEIGHT), set = set("maxHeight") },
        { name = L["Quest Spacing"], kind = LEM.SettingType.Slider, default = C.QUEST_GAP, minValue = 2, maxValue = 20, valueStep = 1,
          get = get("questGap", C.QUEST_GAP), set = set("questGap") },
        -- the edge it is held by (it grows away from it); Automatic: the one nearest the screen edge
        { name = L["Anchor"], kind = LEM.SettingType.Dropdown, default = "auto",
          values = { { text = L["Automatic"], value = "auto", isRadio = true },
                     { text = L["Top"], value = "TOP", isRadio = true }, { text = L["Bottom"], value = "BOTTOM", isRadio = true } },
          desc = L["The edge that stays put as the tracker grows:\n* Automatic: whichever edge is nearer the edge of the screen\n* Top: grows downward\n* Bottom: grows upward"],
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
    return settings
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

Build.GLYPHS = { funnel = "QTFilter", exclaim = "QTExclaim", question = "QTQuestion", sort = "QTSort" }

function Build.IconButton(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    C.ICON_COLOR = C.ICON_COLOR or { r = C.BOX_COLOR[1], g = C.BOX_COLOR[2], b = C.BOX_COLOR[3], a = 1 }

    function b:Layout()
        local file = self.glyph or (self.plus and C.FOLD_EXPAND or C.FOLD_COLLAPSE)
        if file ~= self.file then
            self.file = file
            self.icon:ClearAllPoints()
            if self.glyph then
                self.icon:SetAllPoints()
                ns.BronzeIcon.Apply(self.icon, C.ICON_PATH .. file .. ".tga", C.ICON_COLOR)
            else
                self.icon:SetPoint("CENTER")
                self.icon:SetSize(size * C.FOLD_SCALE, size * C.FOLD_SCALE)
                self.icon:SetAtlas(file)
            end
        end
        self:Paint(self.lit)
    end
    function b:Paint(lit)
        self.lit = lit
        if not self.glyph then return end
        self.icon.FlareUI_Light:SetShown(not self.active)
        if self.active then
            local gold = OT.blizzColors.HEADING
            C.ICON_GOLD = C.ICON_GOLD or CreateColor(gold[1], gold[2], gold[3], 1)
            self.icon:SetGradient("VERTICAL", C.ICON_GOLD, C.ICON_GOLD)
            return
        end
        ns.BronzeIcon.Paint(self.icon, C.ICON_COLOR, lit)
    end
    function b:SetPlus(plus)
        self.plus = plus
        self:Layout()
    end
    b:HookScript("OnEnter", function(self) self:Paint(true) end)
    b:HookScript("OnLeave", function(self) self:Paint(false) end)
    b:Layout()
    return b
end

-- Auto Quest Buttons: with the switch on and Quality of Life running; not in the Gamepad UI, where
-- the auto quests stand aside. Left of the sort button, "!" then "?"
function OT.TweaksDb() return ns.db and ns.db.profile and ns.db.profile.tweaks end

function Build.LayoutAutoButtons(head, db)
    local accept, turnIn = head.autoAccept, head.autoTurnIn
    if not (accept and turnIn) then return end
    local tweaksModule = ns.modules and ns.modules["Tweaks"]
    local can = tweaksModule and tweaksModule.initialized and not ns.IsGamepadUI() or false
    -- each its own switch (11-20); a setup from before the split keeps its shared autoButtons
    local function On(key)
        local v = db[key]
        if v == nil then v = db.autoButtons end
        return can and v and true or false
    end
    local showAccept, showTurnIn = On("autoAcceptButton"), On("autoTurnInButton")
    accept:SetShown(showAccept)
    turnIn:SetShown(showTurnIn)
    if not (showAccept or showTurnIn) then return end
    local tweaks = OT.TweaksDb()
    local last = head.lastButton or head.sort
    if showTurnIn then
        turnIn:ClearAllPoints()
        turnIn:SetPoint("RIGHT", last, "LEFT", -4, 0)
        last = turnIn
    end
    if showAccept then
        accept:ClearAllPoints()
        accept:SetPoint("RIGHT", last, "LEFT", -4, 0)
    end
    for _, b in ipairs({ accept, turnIn }) do
        b.active = tweaks and tweaks[b.key] or nil
        b:Paint(b.lit)
    end
end

-- the sort in use, from the four settings (as Quest Tracker > Sort reads them)
Build.SORTS = { "zone", "distance", "level", "progress" }
function Build.SortMode(db)
    if db.sortByLevel then return "level" end
    if db.sortByProgress then return "progress" end
    return db.zoneFirst and "zone" or "distance"
end
Build.SORT_LABELS = {
    zone = function() return L["Sort: Zone"] end, distance = function() return L["Sort: Distance"] end,
    level = function() return L["Sort: Level"] end, progress = function() return L["Sort: Progress"] end,
}

-- The header band (title, zone switch, minimize button) and the divider under it, on a window: the
-- tracker's, or the settings preview's sample. No clicks or tooltips here.
function Build.Header(window)
    local head = CreateFrame("Frame", nil, window)
    head:SetPoint("TOPLEFT", C.HEADER_INSET, -3)
    head:SetPoint("TOPRIGHT", -C.HEADER_INSET, -3)
    head:SetHeight(C.HEADER - 3)
    head.title = head:CreateFontString(nil, "OVERLAY")
    head.minimize = Build.IconButton(head, C.BOX)
    -- All / Zone (a funnel, gold while only this zone shows) and the sort (three bars), as Kaliel's
    -- Tracker has them (the idea only: its art is its own)
    local zone = Build.IconButton(head, C.BOX)
    zone.glyph = Build.GLYPHS.funnel
    zone:Layout()
    head.zone = zone
    local sort = Build.IconButton(head, C.BOX)
    sort.glyph = Build.GLYPHS.sort
    sort:Layout()
    head.sort = sort
    -- Auto Quest Buttons: "!" Auto Accept, "?" Auto Turn-In (Quality of Life's switches), gold while on
    for _, def in ipairs({ { "autoAccept", "exclaim", "autoAcceptQuests" }, { "autoTurnIn", "question", "autoTurnInQuests" } }) do
        local b = Build.IconButton(head, C.BOX)
        b.glyph, b.key = Build.GLYPHS[def[2]], def[3]
        b:Layout()
        b:Hide()
        head[def[1]] = b
    end

    -- Header Art's line along the frame's bottom border (Build.LayoutHeader)
    local foot = CreateFrame("Frame", nil, window)
    foot:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", C.HEADER_INSET, C.ART_FOOT_Y)
    foot:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -C.HEADER_INSET, C.ART_FOOT_Y)
    foot:SetHeight(1)
    head.foot = foot

    local line = window:CreateTexture(nil, "ARTWORK")
    line:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
    line:SetPoint("TOPLEFT", window, "TOPLEFT", C.HEADER_INSET, -C.HEADER + 2)
    line:SetPoint("TOPRIGHT", window, "TOPRIGHT", -C.HEADER_INSET, -C.HEADER + 2)
    line:SetHeight(8)
    return head, line
end

function Build.StyleHeader(head, db)
    -- the live header: the scheme first, so "Quests" takes its colour (a preview's sample db never sets it)
    if head == header then OT.ApplyColorScheme(db) end
    ApplyFont(head.title, db.headerFont, 13)
    SetColor(head.title, C.HEADING)
end

-- the scroll bar: a dark bronze thumb down the list's right margin
function Build.ScrollBar(window)
    local thumb = window:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(C.SCROLL_COLOR[1], C.SCROLL_COLOR[2], C.SCROLL_COLOR[3], 1)
    thumb:SetSnapToPixelGrid(false)
    thumb:SetTexelSnappingBias(0)
    thumb:Hide()
    window.ScrollThumb = thumb
end

-- delta: wheel steps, up is positive
function OT.ScrollBy(delta)
    if not scroll then return end
    -- in a fight the quest item buttons cannot move with the list: it holds still while they show
    if InCombatLockdown() and (state.itemsShown or 0) > 0 then return end
    local max = math_max(0, content:GetHeight() - scroll:GetHeight())
    scroll:SetVerticalScroll(math_min(max, math_max(0, scroll:GetVerticalScroll() - delta * C.SCROLL_STEP)))
end

-- Gamepad scroll: in the Gamepad UI, while the cursor (a Steam Deck trackpad, or the pad's
-- cursor) rests on the list, the right stick's up / down scroll it (when the game sends them as
-- buttons), and held they keep going. The D-pad stays the gamepad action bar's. A listener of
-- FlareUI's own takes those buttons only then, passes every other button on, and goes off when the
-- cursor leaves or hides, the list fits, Edit Mode opens or a fight starts (never on in a fight).
-- Only once you click the tracker (the pad's cursor click too): a cursor that just rests on the list
-- while the right stick turns the camera doesn't scroll it. Moving the cursor off the list ends it.
local PAD_SCROLL = { PADRSTICKUP = 1, PADRSTICKDOWN = -1 }
local PAD_REPEAT_DELAY, PAD_REPEAT_RATE = 0.35, 0.08

function OT.SetPadScroll(on)
    local f = OT.padScroll
    if not f or (f.listening or false) == on then return end
    if on and InCombatLockdown() then return end
    f.listening, f.held = on, nil
    pcall(f.EnableGamePadButton, f, on)
    if not InCombatLockdown() then f:SetPropagateKeyboardInput(true) end
end

function OT.BuildPadScroll()
    if OT.padScroll or not ns.IsGamepadUI() then return end
    local f = CreateFrame("Frame", nil, holder)
    f.smartNavigationIgnored = true
    OT.padScroll = f
    -- a click on the list engages it (GLOBAL_MOUSE_DOWN: any click, the list's own buttons too)
    f:RegisterEvent("GLOBAL_MOUSE_DOWN")
    f:SetScript("OnEvent", function(self)
        if scroll:IsVisible() and scroll:IsMouseOver() then self.engaged = true end
    end)
    f:SetScript("OnGamePadButtonDown", function(self, key)
        local dir = PAD_SCROLL[key]
        if not InCombatLockdown() then self:SetPropagateKeyboardInput(not dir) end
        if not dir then return end
        OT.ScrollBy(dir)
        self.held, self.nextAt = dir, GetTime() + PAD_REPEAT_DELAY
    end)
    f:SetScript("OnGamePadButtonUp", function(self, key)
        if PAD_SCROLL[key] then self.held = nil end
        if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
    end)
    local elapsed = 0
    f:SetScript("OnUpdate", function(self, dt)
        if self.held and GetTime() >= self.nextAt then
            self.nextAt = GetTime() + PAD_REPEAT_RATE
            OT.ScrollBy(self.held)
        end
        elapsed = elapsed + dt
        if elapsed < 0.1 then return end
        elapsed = 0
        local over = IsCursorVisible() and scroll:IsVisible() and scroll:IsMouseOver()
        if not over or InCombatLockdown() then self.engaged = nil end
        OT.SetPadScroll(self.engaged and over and not InCombatLockdown() and not state.editMode and not Char().minimized
            and content:GetHeight() > scroll:GetHeight() + 1 or false)
    end)
    f:SetScript("OnHide", function() OT.SetPadScroll(false) end)
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
        self:Paint(true)
        ns.OwnGameTooltip(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(GetDb().zoneOnly and L["Showing the quests of this zone"] or L["Showing all tracked quests"])
        GameTooltip:AddLine(L["Click to switch"], 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    zone:SetScript("OnLeave", function(self)
        self:Paint(false)
        GameTooltip:Hide()
    end)

    -- Auto Quest Buttons: a click switches Quality of Life's setting
    for _, b in ipairs({ header.autoAccept, header.autoTurnIn }) do
        b:SetScript("OnClick", function(self)
            local tweaks = OT.TweaksDb()
            if not tweaks then return end
            tweaks[self.key] = not tweaks[self.key]
            PlaySound(tweaks[self.key] and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
            self.active = tweaks[self.key] or nil
            self:Paint(true)
            if ns.SettingsPanel and ns.SettingsPanel.Refresh then pcall(ns.SettingsPanel.Refresh, ns.SettingsPanel) end
            self:GetScript("OnEnter")(self)
        end)
        b:SetScript("OnEnter", function(self)
            self:Paint(true)
            local tweaks = OT.TweaksDb()
            ns.OwnGameTooltip(self, "ANCHOR_LEFT")
            GameTooltip:AddLine(self.key == "autoAcceptQuests" and L["Auto Accept Quests"] or L["Auto Turn-In Quests"])
            if tweaks and tweaks[self.key] then
                GameTooltip:AddLine(L["On"], GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b)
            else
                GameTooltip:AddLine(L["Off"], 0.5, 0.5, 0.5)
            end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function(self)
            self:Paint(false)
            GameTooltip:Hide()
        end)
    end

    -- Sort: a click the next way (Zone, Distance, Level, Progress), a right-click the one before; the
    -- same four settings as Quest Tracker > Sort (AstroFox's idea 11-18)
    local sort = header.sort
    sort:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    sort:SetScript("OnClick", function(self, mouse)
        local db = GetDb()
        local now = Build.SortMode(db)
        local at = 1
        for i, mode in ipairs(Build.SORTS) do if mode == now then at = i end end
        local step = mouse == "RightButton" and -1 or 1
        local mode = Build.SORTS[(at - 1 + step) % #Build.SORTS + 1]
        db.sortByLevel, db.sortByProgress = mode == "level", mode == "progress"
        db.zoneFirst, db.sortByDistance = mode == "zone", mode == "distance"
        OT:Render()
        self:GetScript("OnEnter")(self)
    end)
    sort:SetScript("OnEnter", function(self)
        self:Paint(true)
        ns.OwnGameTooltip(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(Build.SORT_LABELS[Build.SortMode(GetDb())]())
        GameTooltip:AddLine(L["Click: next sort. Right-click: the one before."], 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    sort:SetScript("OnLeave", function(self)
        self:Paint(false)
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
    scroll:SetScript("OnMouseWheel", function(_, delta) OT.ScrollBy(delta) end)
    scroll:SetScript("OnVerticalScroll", function()
        OT:UpdateScrollBar()
        OT:UpdateItemButtons()
    end)

    Build.ScrollBar(holder)
    OT.BuildPadScroll()

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
    -- the Header Art switch became Frame Style: off was the plain frame, now Modern ("custom", once)
    local db = GetDb()
    -- Quest Icon and Focus Button both focus a quest: one of them, the icon if both were saved
    if db and db.questIcons and db.focusButtons then db.focusButtons = false end
    if db and db.headerArt ~= nil then
        if db.headerArt == false and rawget(db, "frameStyle") == nil then db.frameStyle = "custom" end
        db.headerArt = nil
    end

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
        "QUEST_TURNED_IN", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED",
    }) do events:RegisterEvent(e) end
    events:RegisterUnitEvent("UNIT_QUEST_LOG_CHANGED", "player")
    OT.KeepFocusChanged()   -- Keep Quest Focus: note the focus we start with
    events:SetScript("OnEvent", function(_, event, arg1)
        if event == "PLAYER_ENTERING_WORLD" then
            ParkBlizzardTracker()
            OT:CheckContext()
            -- once more a moment later: the first layout can come before the fonts are ready
            C_Timer.After(1, function() OT:Render() end)
        elseif event == "PLAYER_REGEN_ENABLED" then
            ParkBlizzardTracker()
            local wasFrozen = state.frozenOrder ~= nil
            state.frozenOrder, state.frozenCollapsed, state.frozenZones = nil, nil, nil
            OT:CheckContext()
            if wasFrozen then OT:Render() end
            if state.itemsDirty then OT:UpdateItemButtons() end
            return
        elseif event == "PLAYER_REGEN_DISABLED" then
            -- (the secure click over a quest line: hidden while it still can be)
            OT.HideSecureClick()
            OT.SetPadScroll(false)
            OT:CheckContext()
            OT:FreezeForCombat()
            return
        elseif event == "BAG_UPDATE_COOLDOWN" then
            OT:UpdateItemCooldowns()
            return
        elseif event == "PLAYER_CONTROL_LOST" or event == "PLAYER_CONTROL_GAINED" then
            -- a flight path starts or ends (UnitOnTaxi can lag the event a moment)
            OT:CheckContext()
            C_Timer.After(0.5, function() OT:CheckContext() end)
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
            state.voicePlayed[arg1] = nil
        elseif event == "QUEST_ACCEPTED" then
            OT:QuestAccepted(arg1)
            OT.KeepFocusAccepted(arg1)
        elseif event == "SUPER_TRACKING_CHANGED" then
            OT.KeepFocusChanged()
        elseif event == "QUEST_TURNED_IN" then
            OT:QuestTurnedIn(arg1)
        end
        OT:RequestRender()
    end)
    C_Timer.NewTicker(C.SORT_TICK, OnSortTick)

    -- Wayfarer's queue changed (a line started, ended or was stopped): the buttons repaint
    local wayfarer = OT.Wayfarer()
    if wayfarer and type(wayfarer.UI) == "table" and type(wayfarer.UI.Refresh) == "function" then
        hooksecurefunc(wayfarer.UI, "Refresh", function()
            for _, line in ipairs(lines) do
                local b = line.playButton
                if b and b:IsShown() then PaintPlayButton(b) end
            end
        end)
    end
    -- The voice addon's packs load after the first draw; its play state changes on its own
    local spoken = _G.Spoken
    if spoken and spoken.RegisterCallback then
        local function Redraw() OT:RequestRender() end
        pcall(spoken.RegisterCallback, spoken, "VOICE_PACKS_LOADED", Redraw)
        pcall(spoken.RegisterCallback, spoken, "PART_SWITCHED", function(part)
            if part == "quests" then Redraw() end
        end)
        -- a quest's line that ended, played out or stopped from anywhere, offers Replay from then on
        -- (the queue's AUDIO_CHANGED follows and repaints)
        pcall(spoken.RegisterCallback, spoken, "CLIP_STOPPED", function(clip)
            local voice = _G.VoiceOver
            local enums = voice and voice.Enums and voice.Enums.SoundEvent
            if type(clip) == "table" and clip.questID and enums and clip.event == enums.QuestAccept then
                state.voicePlayed[clip.questID] = true
            end
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
        f.Header.sort:EnableMouse(false)
        f.Header.autoAccept:EnableMouse(false)
        f.Header.autoTurnIn:EnableMouse(false)
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

    -- the title's icon, focus and voice buttons, as AddTitleButtons places them: icon and focus dot left
    -- of the title, the voice button at its right end (previews show it on every quest, with Play)
    local function TitleButtons(line, db, focused, done)
        local x = -3
        if line.focusButton then line.focusButton:Hide() end
        if line.playButton then line.playButton:Hide() end
        if line.questIcon then line.questIcon:Hide() end
        if db.questIcons then
            local b = line.questIcon or Build.QuestIcon(line)
            line.questIcon = b
            b:EnableMouse(false)
            Build.PlaceQuestIcon(b, line, x, db.titleFont, done, focused)
            x = x - C.POI_ROOM
        end
        if db.focusButtons then
            local b = line.focusButton or Build.LineButton(line)
            line.focusButton = b
            b:EnableMouse(false)
            Build.PaintFocusDot(b, focused)
            b:ClearAllPoints()
            b:SetPoint("TOPRIGHT", line, "TOPLEFT", x, 0)
            b:Show()
            x = x - C.BUTTON_ROOM
        end
        if db.playButtons then
            local b = line.playButton or Build.VoiceButton(line)
            line.playButton = b
            b:EnableMouse(false)
            Build.PlaceVoiceButton(b, line, db.titleFont)
        end
    end

    local function DrawList(f, db, width)
        local n, y, lastBottom, bars = 0, 0, 0, 0
        local inner = width - C.PAD * 2
        local wrap = true   -- long lines always wrap
        local fonts = { header = db.headerFont, title = db.titleFont, objective = db.objectiveFont }
        local questGap = db.questGap or C.QUEST_GAP
        local titleRoom = Build.TitleRoom(db)
        local objectiveIndent = C.INDENT + titleRoom
        local voiceRoom = db.playButtons and Build.VoiceRoom(db.titleFont) or nil

        local function AddLine(text, kind, color, indent, rightRoom)
            n = n + 1
            local line = f.Lines[n]
            if not line then
                line = Build.Line(f.Content)
                line:EnableMouse(false)
                f.Lines[n] = line
            end
            local h = Build.LineLook(line, text, kind, fonts[kind], color, inner - (indent or 0) - (rightRoom or 0), wrap)
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", f.Content, "TOPLEFT", C.PAD + (indent or 0), y)
            if line.focusButton then line.focusButton:Hide() end
            if line.playButton then line.playButton:Hide() end
            if line.questIcon then line.questIcon:Hide() end
            if line.foldIcon then line.foldIcon:Hide() end
            Build.HideStrip(line)
            line:Show()
            lastBottom = y - h
            y = y - h - C.LINE_GAP
            return line
        end

        for _, s in ipairs(SampleQuests()) do
            if s.zone then
                if db.zoneHeaders then
                    if n > 0 then y = y - C.GROUP_GAP end
                    local art = Build.HeaderArtOn(db)
                    if art then y = y - C.ART_PAD end
                    local head = AddLine(s.zone, "header", C.ZONE, nil, C.FOLD_ROOM)
                    Build.FoldIcon(head, true, false, fonts.header)
                    Build.HeadingArt(head, db, C.FOLD_ROOM)
                    if art then y = y - C.ART_PAD end
                    y = y - C.ZONE_GAP
                end
            else
                -- Auto-Collapse Completed folds the finished one
                local collapsed = s.done and db.collapseCompleted
                local line = AddLine(Build.TitleText(db, s.level, s.tags or "", s.title, collapsed, nil, s.done), "title",
                    Build.TitleColor(db, s.level, nil, s.focus, s.done), titleRoom, voiceRoom)
                TitleButtons(line, db, s.focus, s.done)
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
                        AddLine(s.ready, "objective", s.ready == TEXT.ready and C.READY or Build.DoneColor(db), objectiveIndent)
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
        local thumb = window.ScrollThumb
        local height
        if minimized then
            -- minimized, the header keeps the same 3 px below it as above it
            f.List:Hide()
            f.Divider:Hide()
            thumb:Hide()
            height = C.HEADER + 3
        else
            local contentHeight = DrawList(f, db, width)
            local listHeight = math_min(contentHeight, db.maxHeight or C.MAX_HEIGHT)
            f.Content:SetSize(width, contentHeight)
            f.List:SetHeight(math_max(1, listHeight))
            f.List:Show()
            f.Divider:SetShown(not Build.HeaderArtOn(db))
            local scrollable = contentHeight > listHeight + 1 and Build.ScrollBarShown(db)
            thumb:SetShown(scrollable)
            if scrollable then Build.PlaceScrollBar(thumb, f.List, window, contentHeight, listHeight, 0) end
            height = C.HEADER + C.LIST_TOP + listHeight + C.LIST_BOTTOM
        end
        window:SetHeight(height)
        f:SetSize(width, height)
        f:Show()
        return width, height
    end
end
