local _, ns = ...
local L = ns.L

--------------------------------------------------
-- BANNER SOURCES
-- The game's events turned into banners (Banners.lua B:Push), and Blizzard's own announcements put
-- away for each kind that is on. The conditions and the way Blizzard's frames are silenced follow
-- Horizon Suite's Presence (MIT, LICENSES/HorizonSuite.txt: its PresenceBlizzard, PresenceZone,
-- PresenceErrors, PresenceQuest, PresenceAchievement and PresenceEvents), less what WoW: Forever has
-- not (Mythic+, delves) and with FlareUI's options in place of its own.
--   1. Blizzard's frames: a frame is "killed" (its events off, moved under a hidden parent, hidden
--      whenever it is shown) while its kind is on, and given back when the kind is switched off
--   2. zones            3. "Discovered" and the error frame      4. quests
--   5. levels, bosses   6. achievements                          7. scenarios and rares
--------------------------------------------------
local S = {}
ns.BannerSources = S

local B = ns.Banners
local ipairs, pairs, type, pcall, tostring, tonumber = ipairs, pairs, type, pcall, tostring, tonumber
local GetTime = GetTime
local Readable = B.Readable
local COL = B.COLORS

local T = {
    ZONE_DEBOUNCE = 0.25,       -- a border fires several zone events: one banner for them all
    SUBZONE_DEDUP = 2,          -- the same subzone again this soon says nothing
    DISCOVERY_KEEP = 4,         -- a "Discovered" line waits this long for a zone banner, then is forgotten
    QUEST_BUFFER = 0.35,        -- a quest's objectives settle before they are read (55/100 against 71/100)
    QUEST_ZERO_RETRY = 0.45,    -- "0/8" is read again: the count may lag
    QUEST_CACHE_RETRY = 0.4,    -- nothing changed after QUEST_WATCH_UPDATE: read once more
    QUEST_DISPOSED = 2,         -- a quest just handed in or dropped is left alone this long
    QUEST_RELOAD_QUIET = 2,     -- no blind quest updates this long after starting
    UI_MSG_THROTTLE = 1,
    ACH_DEBOUNCE = 0.6, ACH_DEDUPE = 3,
    RARE_DEBOUNCE = 0.5, RARE_COMBAT = 6, RARE_COOLDOWN = 10,
    SWEEPS = 20, SWEEP_EVERY = 0.25,   -- after a reload Blizzard may show queued toasts: five seconds of sweeping
}

local started = false

local function On(option) return started and B.Enabled(option) end

-- markup out of a name or a line (colours, textures, links' wrappers)
local function Strip(text)
    if type(text) ~= "string" or not Readable(text) then return text end
    text = text:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("|H.-|h(.-)|h", "%1")
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- one pending call per key: asking again starts the wait again
local timers = {}
local function Debounce(key, delay, callback)
    local token = {}
    timers[key] = token
    C_Timer.After(delay, function()
        if timers[key] ~= token then return end
        timers[key] = nil
        callback()
    end)
end
local function CancelDebounce(key) timers[key] = nil end

--------------------------------------------------
-- 1. BLIZZARD'S FRAMES
--------------------------------------------------
local Z = { suppressed = {}, parents = {}, points = {}, alphas = {}, showHooked = {}, alerts = {} }
Z.hidden = CreateFrame("Frame")
Z.hidden:Hide()
Z.ZONE_EVENTS = { "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }
-- AlertFrame's own events, each with the kind that replaces it (only events AlertFrame registers itself)
Z.ALERTS = { { "ACHIEVEMENT_EARNED", "achievement" }, { "CRITERIA_EARNED", "achievementProgress" }, { "QUEST_TURNED_IN", "questComplete" } }
-- the kinds Blizzard announces through its event toasts
Z.TOAST_KINDS = { "achievement", "achievementProgress", "questAccept", "questComplete", "questProgress", "scenario" }

-- (pcall throughout: a frame's methods can throw on a protected or forbidden frame)
local function Kill(frame)
    if not frame then return end
    pcall(function()
        frame:UnregisterAllEvents()
        if not Z.suppressed[frame] then
            Z.parents[frame] = frame:GetParent()
            local point, relative, relativePoint, x, y = frame:GetPoint(1)
            Z.points[frame] = point and { point, relative, relativePoint, x, y } or nil
            Z.alphas[frame] = frame:GetAlpha()
        end
        Z.suppressed[frame] = true
        frame:SetParent(Z.hidden)
        frame:Hide()
        frame:SetAlpha(0)
    end)
    pcall(function() frame:SetScript("OnShow", function(self) self:Hide() end) end)
    if not Z.showHooked[frame] then
        Z.showHooked[frame] = true
        pcall(function()
            hooksecurefunc(frame, "Show", function(self)
                if Z.suppressed[self] then self:Hide() end
            end)
        end)
    end
end

local function Restore(frame)
    if not (frame and Z.suppressed[frame]) then return end
    pcall(function()
        frame:SetScript("OnShow", nil)
        frame:SetParent(Z.parents[frame] or UIParent)
        frame:SetAlpha(Z.alphas[frame] or 1)
        local point = Z.points[frame]
        frame:ClearAllPoints()
        if point and point[1] then
            frame:SetPoint(point[1], point[2] or UIParent, point[3] or "CENTER", point[4] or 0, point[5] or 0)
        else
            frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
        -- (the zone text frames listen for the zone themselves)
        if frame == _G.ZoneTextFrame or frame == _G.SubZoneTextFrame then
            for _, event in ipairs(Z.ZONE_EVENTS) do frame:RegisterEvent(event) end
            -- (Quality of Life > Zone Text hides it by this script: put back, as it was before the banner took over)
            local tweaks = ns.db and ns.db.profile and ns.db.profile.tweaks
            if tweaks and tweaks.enabled and tweaks.hideZoneText then frame:SetScript("OnShow", frame.Hide) end
        end
        frame:Hide()
    end)
    Z.suppressed[frame], Z.parents[frame], Z.points[frame], Z.alphas[frame] = nil, nil, nil, nil
end

local function KillIf(frame, on)
    if on then Kill(frame) else Restore(frame) end
end

-- Newer clients have no RaidBossEmoteFrame: boss emotes share RaidWarningFrame with the leader's
-- warnings, so only its RAID_BOSS_EMOTE event is taken, never the frame
local function MuteBossEmote(mute)
    local frame = _G.RaidWarningFrame
    if not (frame and frame.UnregisterEvent) or mute == (Z.bossMuted or false) then return end
    local ok = pcall(mute and frame.UnregisterEvent or frame.RegisterEvent, frame, "RAID_BOSS_EMOTE")
    if ok then Z.bossMuted = mute end
end

-- AlertFrame's events: one is off only while its kind is on, so switching the kind off hands the
-- alert back
local function MuteAlerts()
    local frame = _G.AlertFrame
    if not (frame and frame.RegisterEvent and frame.UnregisterEvent) then return end
    for _, entry in ipairs(Z.ALERTS) do
        local mute, muted = On(entry[2]), Z.alerts[entry[1]] or false
        if mute ~= muted then
            local ok = pcall(mute and frame.UnregisterEvent or frame.RegisterEvent, frame, entry[1])
            if ok then Z.alerts[entry[1]] = mute or nil end
        end
    end
end

local function AllAlertsMuted()
    for _, entry in ipairs(Z.ALERTS) do
        if not Z.alerts[entry[1]] then return false end
    end
    return true
end

local function AnyToastKind()
    for _, option in ipairs(Z.TOAST_KINDS) do
        if On(option) then return true end
    end
    return false
end

-- the event toast frame shows itself from several methods: each is followed by a hide while it is killed
local function HookEventToasts()
    local frame = _G.EventToastManagerFrame
    if Z.toastsHooked or not frame then return end
    Z.toastsHooked = true
    for _, method in ipairs({ "DisplayToast", "ShowNextToast", "ReleaseToasts", "ShowToast" }) do
        if frame[method] then
            pcall(function()
                hooksecurefunc(frame, method, function(self)
                    if Z.suppressed[self] then
                        pcall(function()
                            self:Hide()
                            self:SetAlpha(0)
                        end)
                    end
                end)
            end)
        end
    end
end

-- Each kind's frame killed while the kind is on, restored while it is off. Called again whenever
-- an option changes, Blizzard loads one of the frames, or a level or a boss emote comes.
function S.ApplySuppression()
    if not started then return end
    KillIf(_G.ZoneTextFrame, On("zone"))
    -- (the subzone frame also while a subzone's banner hides the zone's name)
    KillIf(_G.SubZoneTextFrame, On("subzone") or On("hideZoneInSub"))
    KillIf(_G.LevelUpDisplay, On("levelUp"))
    if _G.RaidBossEmoteFrame then
        KillIf(_G.RaidBossEmoteFrame, On("bossEmote"))
    else
        MuteBossEmote(On("bossEmote"))
    end
    KillIf(_G.EventToastManagerFrame, AnyToastKind())
    KillIf(_G.WorldQuestCompleteBannerFrame, On("questComplete"))
    MuteAlerts()
    -- always, while Banners is on (no kind of their own)
    Kill(_G.BossBanner)
    Kill(_G.ObjectiveTrackerBonusBannerFrame)
    Kill(_G.ObjectiveTrackerTopBannerFrame)
    HookEventToasts()
end

-- (Blizzard may show the zone text again as the zone changes)
local function ReapplyZone()
    if not started then return end
    if On("zone") then Kill(_G.ZoneTextFrame) end
    if On("subzone") or On("hideZoneInSub") then Kill(_G.SubZoneTextFrame) end
end

local function Sweep()
    for frame in pairs(Z.suppressed) do
        pcall(function()
            if frame:IsShown() then frame:Hide() end
            frame:SetAlpha(0)
            if frame.GetChildren then
                for _, child in ipairs({ frame:GetChildren() }) do
                    if child and child.IsShown and child:IsShown() then pcall(child.Hide, child) end
                end
            end
        end)
    end
end

-- AlertFrame's backlog from the login, so its toasts don't come beside ours. Only while every alert
-- we replace is muted: the queue is shared, and one handed back to Blizzard would be lost with it.
local function DrainAlerts()
    if not AllAlertsMuted() then return end
    pcall(function()
        local frame = _G.AlertFrame
        if not frame then return end
        if type(frame.alertQueue) == "table" then wipe(frame.alertQueue) end
        if frame.GetChildren then
            for _, child in ipairs({ frame:GetChildren() }) do
                if child and child.IsShown and child:IsShown() then pcall(child.Hide, child) end
            end
        end
    end)
end

-- after a login or a reload Blizzard builds its frames again and may show what it had queued
local function StartSweep()
    Z.sweepRun = (Z.sweepRun or 0) + 1
    local run, count = Z.sweepRun, 0
    local function Tick()
        if Z.sweepRun ~= run or not started then return end
        count = count + 1
        Sweep()
        DrainAlerts()
        if count < T.SWEEPS then C_Timer.After(T.SWEEP_EVERY, Tick) end
    end
    C_Timer.After(T.SWEEP_EVERY, Tick)
end

function S:Refresh()
    S.ApplySuppression()
end

--------------------------------------------------
-- 2. ZONES
--------------------------------------------------
local zone = { last = nil, shownTitle = nil, shownAt = 0 }

local function ZoneColor()
    local inside, kind = IsInInstance()
    if inside and (kind == "party" or kind == "raid") then return COL.dungeon end
    if not B.Enabled("zoneColors") then return nil end
    local pvp = (C_PvP and C_PvP.GetZonePVPInfo and C_PvP.GetZonePVPInfo()) or (GetZonePVPInfo and GetZonePVPInfo())
    if pvp == "arena" or pvp == "combat" then pvp = "hostile" end
    return pvp and COL[pvp] or nil
end

local function ZoneNames()
    local name, sub = GetZoneText() or "", GetSubZoneText() or ""
    if not (Readable(name) and Readable(sub)) then return nil end
    return name, sub
end

-- the "Discovered" line that came before its banner joins the one just shown
local function JoinDiscovery()
    local pending = S.pendingDiscovery
    if not pending then return end
    S.pendingDiscovery = nil
    if GetTime() - pending.at <= T.DISCOVERY_KEEP then B:Extra(pending.text) end
end

local function ScheduleZone(isNewArea)
    local name, sub = ZoneNames()
    if not name then return end
    if not isNewArea and sub ~= "" and name == sub then return end
    if isNewArea then zone.last = name end

    Debounce("zone", T.ZONE_DEBOUNCE, function()
        if not started or B.Skipped() then return end
        name, sub = ZoneNames()
        if not name then return end
        -- (the zone banner showing is about where you were: it goes at once)
        B:CancelZone()
        local shown
        if isNewArea then
            zone.last = name
            if not B.Enabled("zone") then return end
            zone.shownTitle, zone.shownAt = nil, 0
            shown = B:Push{ kind = "zone", title = Strip(name), subtitle = sub ~= "" and Strip(sub) or nil,
                color = ZoneColor(), subColor = COL.gold }
        else
            if not B.Enabled("subzone") or sub == "" then return end
            -- an interior named after the zone you came from: the place is the title, that zone the line below
            local interior = zone.last and sub == zone.last
            local title, parent = interior and name or sub, interior and sub or name
            local sameZone = zone.last and ((not interior and name ~= "" and name == zone.last) or (interior and sub == zone.last))
            title = Strip(title)
            local below = Strip(parent)
            if below == "" or (B.Enabled("hideZoneInSub") and sameZone) then below = nil end
            local now = GetTime()
            if title == zone.shownTitle and now - zone.shownAt < T.SUBZONE_DEDUP then return end
            zone.shownTitle, zone.shownAt = title, now
            shown = B:Push{ kind = "subzone", title = title, subtitle = below, color = ZoneColor(), subColor = COL.gold }
        end
        if shown == "shown" then JoinDiscovery() end
    end)
end

local function OnZoneNewArea()
    C_Timer.After(0, ReapplyZone)
    ScheduleZone(true)
end

local function OnZoneChanged()
    C_Timer.After(0, ReapplyZone)
    local name, sub = ZoneNames()
    if name and sub ~= "" and sub ~= name then ScheduleZone(false) end
end

--------------------------------------------------
-- 3. "DISCOVERED" AND THE ERROR FRAME
-- Blizzard writes "Discovered: ..." and the quest lines in the yellow error text. Each is told by
-- the game's own format strings, so every language works. One we show ourselves is cleared there.
--------------------------------------------------
-- a format string ("%s: %d/%d", "%2$d of %1$s") as a pattern that matches its messages
local function ToPattern(format)
    if type(format) ~= "string" or format == "" then return nil end
    local pattern = format:gsub("[%(%)%.%+%-%*%?%[%]%^%$]", "%%%0")
    -- (marks first: a number's capture holds "%d" itself, which the next pass would take again)
    pattern = pattern:gsub("%%%d+%%%$s", "\1"):gsub("%%%d+%%%$d", "\2"):gsub("%%s", "\1"):gsub("%%d", "\2")
    pattern = pattern:gsub("\1", "(.+)"):gsub("\2", "(%%d+)")
    return "^" .. pattern .. "$"
end
S.ToPattern = ToPattern

-- a format string's fixed words ("%s slain: %d/%d" -> "slain"), for telling a quest line
local function Words(format, drop)
    if type(format) ~= "string" then return nil end
    local clean = format:gsub("%%[%d$]*[sd]", "")
    if drop then clean = clean:gsub(drop, "") end
    clean = clean:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if clean ~= "" and #clean > 2 then return clean end
end

local text = {}

local function BuildText()
    text.discovery, text.questWords, text.acceptWords, text.complete = {}, {}, {}, {}
    for _, name in ipairs({ "ERR_ZONE_EXPLORED", "ERR_ZONE_EXPLORED_XP" }) do
        local pattern = ToPattern(_G[name])
        if pattern then text.discovery[#text.discovery + 1] = pattern end
    end
    for _, name in ipairs({ "QUEST_COMPLETE", "ERR_QUEST_OBJECTIVE_COMPLETE_S", "QUEST_WATCH_QUEST_READY", "OBJECTIVE_COMPLETE",
        "ERR_QUEST_UNKNOWN_COMPLETE", "QUEST_WATCH_QUEST_COMPLETE", "ERR_QUEST_ADD_KILL_SII", "ERR_QUEST_ADD_ITEM_SII",
        "ERR_QUEST_ADD_PLAYER_KILL_SII" }) do
        local words = Words(_G[name], "[:/]")
        if words then text.questWords[#text.questWords + 1] = words end
    end
    for _, name in ipairs({ "ERR_QUEST_ACCEPTED_S", "ERR_QUEST_ADD_FOUND_SII" }) do
        local words = Words(_G[name], "[:/]")
        if words then text.acceptWords[#text.acceptWords + 1] = words end
    end
    -- the whole-line messages that only say a quest or an objective is done: the banner for that is its own
    for _, name in ipairs({ "OBJECTIVE_COMPLETE", "QUEST_COMPLETE", "QUEST_WATCH_QUEST_READY", "ERR_QUEST_UNKNOWN_COMPLETE",
        "QUEST_WATCH_QUEST_COMPLETE", "QUEST_WATCH_POPUP_QUEST_COMPLETE" }) do
        local line = _G[name]
        if type(line) == "string" then text.complete[(line:gsub("[%.%!%?]$", ""))] = true end
    end
end

local function IsDiscovery(message)
    for _, pattern in ipairs(text.discovery) do
        if message:match(pattern) then return true end
    end
    return false
end

-- a quest's line in the yellow text: a count, a percent, or the game's own quest words
local function IsQuestText(message)
    if message:find("%d+/%d+") or message:find("%%") then return true end
    for _, words in ipairs(text.questWords) do
        if message:find(words, 1, true) then return true end
    end
    return false
end

local function IsAcceptText(message)
    for _, words in ipairs(text.acceptWords) do
        if message:find(words, 1, true) then return true end
    end
    return false
end

local function OnErrorMessage(frame, message)
    if not started or type(message) ~= "string" or not Readable(message) then return end
    if not text.discovery then BuildText() end
    if IsDiscovery(message) then
        if not B.Enabled("discovery") or not (B.Enabled("zone") or B.Enabled("subzone")) then return end
        -- under the zone banner playing, else kept for the one about to come
        if not B:Extra(Strip(message)) then S.pendingDiscovery = { text = Strip(message), at = GetTime() } end
        if frame.Clear then frame:Clear() end
        return
    end
    if B.Enabled("questProgress") and IsQuestText(message) and frame.Clear then frame:Clear() end
end

--------------------------------------------------
-- 4. QUESTS
-- A quest's progress is read from its objectives, compared with what they were: the line that
-- changed is the banner's. QUEST_WATCH_UPDATE names the quest; QUEST_LOG_UPDATE and the yellow text
-- don't, so the quest is looked for among the watched ones ("blind").
--------------------------------------------------
local Q = { cache = {}, state = {}, pending = {}, retry = {}, disposed = {}, nonBlind = {}, hint = {} }

-- "Slay wolves: 3/8" and "Slay wolves (3/8)" as "3/8 Slay wolves"; a lone "1/1" is dropped
local function Normalize(line)
    if type(line) ~= "string" or line == "" then return line or "" end
    line = line:gsub("^%s+", ""):gsub("%s+$", "")
    local result = line
    if not line:match("^%d+/%d+%s") then
        local words, have, need = line:match("^(.+):%s*(%d+)/(%d+)$")
        if not words then words, have, need = line:match("^(.+)%s*%((%d+)/(%d+)%)$") end
        if words then result = ("%s/%s %s"):format(have, need, (words:gsub("%s+$", ""))) end
    end
    if result:match("^%d+/1[%s:]+") then result = result:gsub("^%d+/1[%s:]+%s*", "") end
    return result
end
S.Normalize = Normalize

local function ObjectiveLine(o)
    if not o then return nil end
    local words = o.text
    if words and words ~= "" and words ~= "0" then
        if o.numFulfilled ~= nil and o.numRequired ~= nil and o.numRequired > 0 then
            if o.numRequired == 1 then return words end
            if words:find(("%d/%d"):format(o.numFulfilled, o.numRequired), 1, true) then return words end
            return ("%s (%d/%d)"):format(words, o.numFulfilled, o.numRequired)
        end
        return words
    end
    if o.numFulfilled ~= nil and o.numRequired ~= nil and o.numRequired > 1 then
        return ("%d/%d"):format(o.numFulfilled, o.numRequired)
    end
    return nil
end

local function QuestName(questID)
    local name = questID and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID) or nil
    if type(name) ~= "string" or not Readable(name) then return nil end
    name = Strip(name)
    return name ~= "" and name or nil
end

-- Blizzard's own test quests
local function IsDNT(name) return name and name:find("%[DNT%]") ~= nil end

local function IsWorldQuest(questID)
    return questID and C_QuestLog.IsWorldQuest and C_QuestLog.IsWorldQuest(questID) or false
end

local function DisposeQuest(questID)
    if not questID then return end
    Q.cache[questID], Q.state[questID], Q.nonBlind[questID] = nil, nil, nil
    Q.pending[questID], Q.retry[questID], Q.hint[questID] = nil, nil, nil
    Q.disposed[questID] = GetTime()
    Q.standalone = nil
    CancelDebounce("quest:" .. questID)
    B:PurgeQuest(questID)
end

local ExecuteQuestUpdate
ExecuteQuestUpdate = function(questID, blind, source, isRetry, isCacheRetry)
    Q.pending[questID] = nil
    if not questID or questID <= 0 then return end
    local disposedAt = Q.disposed[questID]
    if disposedAt and GetTime() - disposedAt < T.QUEST_DISPOSED then return end
    if C_QuestLog.IsOnQuest and not C_QuestLog.IsOnQuest(questID) then return end
    local objectives = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(questID) or {}
    if type(objectives) ~= "table" or #objectives == 0 then return end

    local parts, state = {}, {}
    for i = 1, #objectives do
        local o = objectives[i]
        local words = o and o.text or ""
        if not Readable(words) then return end
        local finished = o and o.finished and true or false
        local have = o and type(o.numFulfilled) == "number" and o.numFulfilled or nil
        local need = o and type(o.numRequired) == "number" and o.numRequired or nil
        parts[i] = words .. "|" .. (finished and "1" or "0") .. "|" .. (have or "") .. "|" .. (need or "")
        state[i] = { text = words, finished = finished, numFulfilled = have, numRequired = need }
    end
    local key = table.concat(parts, ";")
    local oldState = Q.state[questID]

    if Q.cache[questID] == key then
        -- nothing changed yet: after QUEST_WATCH_UPDATE the count may still be on its way
        if not isCacheRetry and source == "QUEST_WATCH_UPDATE" and not Q.retry[questID] then
            Q.retry[questID] = true
            Debounce("quest:" .. questID, T.QUEST_CACHE_RETRY, function()
                Q.retry[questID] = nil
                ExecuteQuestUpdate(questID, blind, source, nil, true)
            end)
        end
        Q.hint[questID] = nil
        return
    end
    local isNew = Q.cache[questID] == nil
    Q.cache[questID], Q.state[questID] = key, state
    -- a quest first seen through a blind update has nothing to compare with: only remembered
    if blind and isNew then return end

    local line, why
    local hint = Q.hint[questID]
    Q.hint[questID] = nil
    if hint and hint ~= "" then
        for i = 1, #state do
            if state[i].text ~= "" and Normalize(Strip(state[i].text)) == hint then
                line, why = ObjectiveLine(state[i]), "hint"
                break
            end
        end
    end
    if not line and oldState then
        for i = 1, math.max(#oldState, #state) do
            local was, now = oldState[i], state[i]
            if now and now.text ~= "" and (not was or was.text ~= now.text or was.finished ~= now.finished
                or was.numFulfilled ~= now.numFulfilled or was.numRequired ~= now.numRequired) then
                line, why = ObjectiveLine(now), "changed"
                break
            end
        end
    end
    if not line and isNew then
        for i = 1, #state do
            if state[i].text ~= "" and state[i].finished then
                line, why = ObjectiveLine(state[i]), "finished"
                break
            end
        end
    end
    if not line then
        for i = 1, #state do
            if state[i].text ~= "" and not state[i].finished then
                line, why = ObjectiveLine(state[i]), "unfinished"
                break
            end
        end
    end
    if not line and state[1] and state[1].text ~= "" then line, why = ObjectiveLine(state[1]), "first" end
    -- several objectives and nothing to compare with: which one moved can't be told
    if why == "unfinished" and not oldState and #state > 1 then line = nil end
    if not line or line == "" then line = L["Objective updated"] end

    local normalized = Normalize(Strip(line))
    if not isRetry and not isNew and source == "QUEST_WATCH_UPDATE" and normalized:match("^0/%d+") then
        Q.cache[questID], Q.state[questID] = nil, nil
        Debounce("quest:" .. questID, T.QUEST_ZERO_RETRY, function() ExecuteQuestUpdate(questID, blind, source, true, nil) end)
        return
    end

    if not B.Enabled("questProgress") or B.Skipped() then return end
    local name = QuestName(questID)
    if IsDNT(name) then return end
    Q.lastMessage, Q.lastMessageAt = line, GetTime()
    B:Push{ kind = "questProgress", title = name or L["Quest Progress"], subtitle = normalized, questID = questID }
end

local function RequestQuestUpdate(questID, blind, source)
    if not questID then return end
    if not blind then Q.nonBlind[questID] = true end
    local effectiveBlind = blind and not Q.nonBlind[questID]
    Q.pending[questID] = true
    Debounce("quest:" .. questID, T.QUEST_BUFFER, function()
        Q.pending[questID], Q.nonBlind[questID] = nil, nil
        ExecuteQuestUpdate(questID, effectiveBlind, source, nil, nil)
    end)
end

-- the quest an unnamed update is about: the one tracked on the map, else the first watched one still open
local function BlindQuest()
    local super = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID() or 0
    if super and super > 0 and not (C_QuestLog.IsComplete and C_QuestLog.IsComplete(super)) then return super end
    if C_QuestLog.GetNumQuestWatches and C_QuestLog.GetQuestIDForQuestWatchIndex then
        for i = 1, C_QuestLog.GetNumQuestWatches() do
            local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
            if questID and questID > 0 and not (C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID)) then return questID end
        end
    end
    return nil
end

-- the quest one of whose objectives reads like this line
local function QuestByObjective(normalized)
    if not normalized or normalized == "" or not C_QuestLog.GetQuestObjectives then return nil end
    local function Matches(questID)
        for _, o in ipairs(C_QuestLog.GetQuestObjectives(questID) or {}) do
            local words = o and o.text
            if type(words) == "string" and Readable(words) and words ~= "" and Normalize(Strip(words)) == normalized then return true end
        end
        return false
    end
    if C_QuestLog.GetNumQuestWatches and C_QuestLog.GetQuestIDForQuestWatchIndex then
        for i = 1, C_QuestLog.GetNumQuestWatches() do
            local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
            if questID and questID > 0 and Matches(questID) then return questID end
        end
    end
    if C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo and C_QuestLog.IsOnQuest then
        for i = 1, (C_QuestLog.GetNumQuestLogEntries()) or 0 do
            local ok, info = pcall(C_QuestLog.GetInfo, i)
            if ok and info and not info.isHeader and info.questID and C_QuestLog.IsOnQuest(info.questID) and Matches(info.questID) then
                return info.questID
            end
        end
    end
    return nil
end

local function OnQuestAccepted(questID)
    if type(questID) ~= "number" or B.Skipped() then return end
    if C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetInfo then
        local index = C_QuestLog.GetLogIndexForQuestID(questID)
        if index then
            local ok, info = pcall(C_QuestLog.GetInfo, index)
            if ok and info and info.isHidden then return end
        end
    end
    local name = QuestName(questID) or L["New Quest"]
    if IsDNT(name) then return end
    B:Push{ kind = "questAccept", title = L["Quest Accepted"], subtitle = name, questID = questID,
        color = IsWorldQuest(questID) and COL.world or nil, icon = B.QUEST_ICON.accept }
end

local function OnQuestTurnedIn(questID)
    if B.Skipped() then return end
    local name = QuestName(questID)
    if IsDNT(name) then return end
    B:Push{ kind = "questComplete", title = L["Quest Complete"], subtitle = name, questID = questID,
        color = IsWorldQuest(questID) and COL.world or COL.complete, icon = B.QUEST_ICON.done }
    DisposeQuest(questID)
end

local function OnQuestLogUpdate()
    if Q.quietUntil and GetTime() < Q.quietUntil then return end
    local questID = BlindQuest()
    if questID then RequestQuestUpdate(questID, true, "QUEST_LOG_UPDATE") end
end

local function OnInfoMessage(message)
    if type(message) ~= "string" or not Readable(message) then return end
    if not text.discovery then BuildText() end
    if not IsQuestText(message) or IsAcceptText(message) then return end
    local plain = message:gsub("^%s+", ""):gsub("%s+$", ""):gsub("[%.%!%?]$", "")
    if text.complete[plain] then return end

    local normalized = Normalize(Strip(message))
    local questID = BlindQuest()
    if not questID and normalized ~= "" then questID = QuestByObjective(normalized) end
    if questID then
        Q.hint[questID] = normalized
        RequestQuestUpdate(questID, true, "UI_INFO_MESSAGE")
        return
    end
    -- no quest found for it: the line on its own, unless a quest's update is on its way
    if not B.Enabled("questProgress") or B.Skipped() then return end
    local now = GetTime()
    if Q.lastMessage == message and now - (Q.lastMessageAt or 0) < T.UI_MSG_THROTTLE then return end
    Q.lastMessage, Q.lastMessageAt = message, now
    local token = {}
    Q.standalone = token
    C_Timer.After(T.QUEST_BUFFER, function()
        if Q.standalone ~= token then return end
        Q.standalone = nil
        if next(Q.pending) ~= nil then return end
        B:Push{ kind = "questProgress", title = L["Quest Progress"], subtitle = normalized }
    end)
end

--------------------------------------------------
-- 5. LEVELS AND BOSSES
--------------------------------------------------
local function OnLevelUp(level)
    if not B.Enabled("levelUp") then return end
    S.ApplySuppression()
    if type(level) ~= "number" or not Readable(level) then level = UnitLevel("player") end
    B:Push{ kind = "levelUp", title = L["Level Up"], subtitle = L["You have reached level %d"]:format(level), color = COL.complete }
end

-- "%s begins to cast..." with the boss's name; a secret text goes to the banner as it is
local function OnBossEmote(message, name)
    if not B.Enabled("bossEmote") then return end
    S.ApplySuppression()
    local line, boss = message, name
    if type(message) == "string" and Readable(message) and (name == nil or Readable(name)) then
        boss = (type(name) == "string" and name ~= "") and name or L["Boss"]
        line = message:gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%%s", (boss:gsub("%%", "%%%%")))
        line = line:gsub("^%s+", ""):gsub("%s+$", "")
    end
    B:Push{ kind = "bossEmote", title = boss, subtitle = line, color = COL.boss }
end

--------------------------------------------------
-- 6. ACHIEVEMENTS
-- Progress is each achievement's criteria as a text, compared with what it was: the criterion that
-- changed is the banner's line.
--------------------------------------------------
local A = { cache = {}, pending = {}, hints = {} }

local function TrackedAchievements()
    local ids = {}
    if C_ContentTracking and C_ContentTracking.GetTrackedIDs then
        local kind = Enum and Enum.ContentTrackingType and Enum.ContentTrackingType.Achievement or 2
        local ok, tracked = pcall(C_ContentTracking.GetTrackedIDs, kind)
        if ok and type(tracked) == "table" then
            for _, id in ipairs(tracked) do ids[#ids + 1] = id end
        end
    end
    if #ids == 0 and GetTrackedAchievements then
        local found = { pcall(GetTrackedAchievements) }
        if found[1] then
            for i = 2, #found do
                if found[i] then ids[#ids + 1] = found[i] end
            end
        end
    end
    return ids
end

local function AchievementState(id)
    if not (GetAchievementCriteriaInfo and GetAchievementNumCriteria) then return nil end
    local ok, count = pcall(GetAchievementNumCriteria, id)
    if not ok or not count or count == 0 then return nil end
    local parts = {}
    for i = 1, count do
        local got, _, _, completed, quantity, required = pcall(GetAchievementCriteriaInfo, id, i)
        if got then parts[#parts + 1] = ("%s:%s:%s"):format(tostring(completed), tostring(quantity), tostring(required)) end
    end
    return table.concat(parts, ";")
end

-- "3/9 Areas explored", or the criterion's name alone once it is done
local function CriterionLine(id, index)
    local ok, name, _, completed, quantity, required = pcall(GetAchievementCriteriaInfo, id, index)
    if not ok then return nil end
    quantity, required = tonumber(quantity), tonumber(required)
    if name == "" then name = nil end
    local done = completed == true or completed == 1
    if (done or (quantity and quantity > 0)) and quantity and required and required > 0 then
        return name and ("%d/%d %s"):format(quantity, required, name) or ("%d/%d"):format(quantity, required)
    end
    return done and name or nil
end

local function CriterionIndex(id, criteriaID)
    criteriaID = tonumber(criteriaID)
    if not criteriaID or criteriaID <= 0 then return nil end
    local ok, count = pcall(GetAchievementNumCriteria, id)
    if not ok or not count then return nil end
    for i = 1, count do
        local got, _, _, _, _, _, _, _, _, _, own = pcall(GetAchievementCriteriaInfo, id, i)
        if got and tonumber(own) == criteriaID then return i end
    end
    return nil
end

local function ChangedIndex(oldState, newState)
    if not oldState or not newState then return nil end
    local was, now = { strsplit(";", oldState) }, { strsplit(";", newState) }
    for i = 1, math.max(#was, #now) do
        if (was[i] or "") ~= (now[i] or "") then return i end
    end
    return nil
end

local function ProgressLine(id, oldState, newState, hint)
    if hint and hint.fromEarned and hint.description and hint.description ~= "" then return hint.description end
    local index = hint and CriterionIndex(id, hint.criteriaID) or ChangedIndex(oldState, newState)
    local line = index and CriterionLine(id, index)
    if line then return line end
    -- the first criterion under way, else the first one done
    local ok, count = pcall(GetAchievementNumCriteria, id)
    if not ok or not count then return nil end
    for pass = 1, 2 do
        for i = 1, count do
            local got, _, _, completed = pcall(GetAchievementCriteriaInfo, id, i)
            local done = got and (completed == true or completed == 1)
            if got and ((pass == 1 and not done) or (pass == 2 and done)) then
                line = CriterionLine(id, i)
                if line then return line end
            end
        end
    end
    return nil
end

local function CheckAchievements(pending, hints)
    if not B.Enabled("achievementProgress") then return end
    local check = {}
    for id in pairs(pending) do check[id] = true end
    for _, id in ipairs(TrackedAchievements()) do check[id] = true end
    for id in pairs(A.cache) do check[id] = true end
    for id in pairs(check) do
        local newState = type(id) == "number" and id > 0 and AchievementState(id) or nil
        if newState then
            local oldState, hint = A.cache[id], hints[id]
            if (oldState and oldState ~= newState) or (not oldState and hint and hint.fromEarned) then
                local line = ProgressLine(id, oldState, newState, hint)
                local now = GetTime()
                if line and not (A.lastLine == line and now - (A.lastAt or 0) <= T.ACH_DEDUPE) then
                    A.lastLine, A.lastAt = line, now
                    local ok, _, name = pcall(GetAchievementInfo, id)
                    B:Push{ kind = "achievementProgress", title = ok and Strip(name) or nil, subtitle = Strip(line), color = COL.bronze }
                end
            end
            A.cache[id] = newState
        end
    end
end

local function OnCriteria(event, id, second)
    if not B.Enabled("achievementProgress") or not GetAchievementInfo then return end
    if type(id) == "number" and id > 0 then
        local hint = A.hints[id] or {}
        if event == "TRACKED_ACHIEVEMENT_UPDATE" then
            A.pending[id] = true
            if type(second) == "number" and second > 0 then hint.criteriaID = second end
            A.hints[id] = hint
        elseif event == "CRITERIA_EARNED" then
            A.pending[id] = true
            if type(second) == "string" and second ~= "" then hint.description = Strip(second) end
            hint.fromEarned = true
            A.hints[id] = hint
        end
    end
    Debounce("achievement", T.ACH_DEBOUNCE, function()
        local pending, hints = A.pending, A.hints
        A.pending, A.hints = {}, {}
        CheckAchievements(pending, hints)
    end)
end

local function OnAchievementEarned(id)
    if not B.Enabled("achievement") or type(GetAchievementInfo) ~= "function" then return end
    local ok, _, name, _, _, _, _, _, _, _, icon = pcall(GetAchievementInfo, id)
    if not ok or name == nil then return end
    B:Push{ kind = "achievement", title = L["Achievement Earned"], subtitle = Strip(name), icon = icon, color = COL.bronze }
end

-- what the tracked achievements stand at, so a login doesn't read as progress
local function SeedAchievements()
    if not (GetAchievementInfo and B.Enabled("achievementProgress")) then return end
    for _, id in ipairs(TrackedAchievements()) do
        local state = AchievementState(id)
        if state then A.cache[id] = state end
    end
end

--------------------------------------------------
-- 7. SCENARIOS AND RARES (where the client has them)
--------------------------------------------------
local scenario = { name = nil, criteria = {} }

local function ScenarioInfo()
    if not (C_Scenario and C_Scenario.GetInfo) then return nil end
    local ok, name, stage, stages = pcall(C_Scenario.GetInfo)
    if not ok or type(name) ~= "string" or not Readable(name) or name == "" then return nil end
    return name, stage, stages
end

local function OnScenarioUpdate()
    local name, stage, stages = ScenarioInfo()
    if not name then
        scenario.name = nil
        return
    end
    if name == scenario.name then return end
    scenario.name = name
    for key in pairs(scenario.criteria) do scenario.criteria[key] = nil end
    if B.Skipped() then return end
    local below
    if type(stage) == "number" and type(stages) == "number" and stages > 1 then below = L["Stage %d of %d"]:format(stage, stages) end
    B:Push{ kind = "scenarioStart", title = name, subtitle = below, color = COL.scenario }
end

local function OnScenarioCompleted()
    local name = scenario.name or ScenarioInfo()
    scenario.name = nil
    if B.Skipped() then return end
    B:Push{ kind = "scenarioComplete", title = L["Scenario Complete"], subtitle = name, color = COL.complete }
end

local function OnScenarioCriteria()
    local name = ScenarioInfo()
    if not (name and C_Scenario.GetStepInfo and C_ScenarioInfo and C_ScenarioInfo.GetCriteriaInfo) then return end
    local ok, _, _, count = pcall(C_Scenario.GetStepInfo)
    if not ok or type(count) ~= "number" then return end
    for i = 1, count do
        local got, info = pcall(C_ScenarioInfo.GetCriteriaInfo, i)
        if got and type(info) == "table" and Readable(info.description) and Readable(info.quantity) then
            local have, need = info.quantity, info.totalQuantity
            if type(have) == "number" and scenario.criteria[i] ~= nil and scenario.criteria[i] ~= have and not B.Skipped() then
                local line = info.description
                if type(need) == "number" and need > 1 then line = ("%d/%d %s"):format(have, need, line) end
                B:Push{ kind = "scenarioProgress", title = name, subtitle = line, color = COL.scenario }
            end
            scenario.criteria[i] = have
        end
    end
end

-- A rare is "defeated" when one seen on the map is gone within a few seconds of a fight (Presence's
-- test; its list of rares is the map's vignettes here)
local rare = { seen = {}, ready = false, combatAt = 0, cooldown = {} }

local function RaresOnMap()
    local found = {}
    if not (C_VignetteInfo and C_VignetteInfo.GetVignettes and C_VignetteInfo.GetVignetteInfo) then return found end
    local ok, list = pcall(C_VignetteInfo.GetVignettes)
    if not ok or type(list) ~= "table" then return found end
    for _, guid in ipairs(list) do
        local got, info = pcall(C_VignetteInfo.GetVignetteInfo, guid)
        if got and type(info) == "table" and Readable(guid) and Readable(info.name) and info.name and info.name ~= ""
            and not (Readable(info.isDead) and info.isDead) then
            found[guid] = Strip(info.name)
        end
    end
    return found
end

local function CheckRares()
    if not B.Enabled("rare") then return end
    local current = RaresOnMap()
    if not rare.ready then
        rare.seen, rare.ready = current, true
        return
    end
    local now = GetTime()
    if now - rare.combatAt <= T.RARE_COMBAT then
        for guid, name in pairs(rare.seen) do
            if not current[guid] and (rare.cooldown[name] or 0) + T.RARE_COOLDOWN <= now then
                rare.cooldown[name] = now
                B:Push{ kind = "rare", title = L["Rare Defeated"], subtitle = name, color = COL.gold }
            end
        end
    end
    rare.seen = current
end

local function OnVignettes()
    if not B.Enabled("rare") then
        rare.ready = false   -- (read afresh when it is switched on: an old list would read as kills)
        return
    end
    Debounce("rare", T.RARE_DEBOUNCE, CheckRares)
end

--------------------------------------------------
-- 8. EVENTS
--------------------------------------------------
local LATE_FRAMES = { Blizzard_LevelUpDisplay = true, Blizzard_RaidBossEmoteFrame = true, Blizzard_EventToastManager = true,
    Blizzard_WorldQuestComplete = true }

local HANDLERS = {
    -- one of Blizzard's announcement frames loaded late: put away at once, and again a moment later
    ADDON_LOADED = function(name)
        if not LATE_FRAMES[name] then return end
        S.ApplySuppression()
        C_Timer.After(0.05, S.ApplySuppression)
    end,
    PLAYER_ENTERING_WORLD = function()
        zone.last = GetZoneText() or nil
        rare.seen, rare.ready = RaresOnMap(), true
        C_Timer.After(1, SeedAchievements)
        scenario.name = ScenarioInfo()
        S.ApplySuppression()
        Sweep()
        DrainAlerts()
        StartSweep()
    end,
    ZONE_CHANGED_NEW_AREA = OnZoneNewArea,
    ZONE_CHANGED = OnZoneChanged,
    ZONE_CHANGED_INDOORS = OnZoneChanged,
    UI_INFO_MESSAGE = function(_, message) OnInfoMessage(message) end,
    -- (older clients send the log index first, then the quest)
    QUEST_ACCEPTED = function(a, b) OnQuestAccepted(type(b) == "number" and b or a) end,
    QUEST_TURNED_IN = OnQuestTurnedIn,
    QUEST_REMOVED = function(questID) DisposeQuest(questID) end,
    QUEST_WATCH_UPDATE = function(questID) RequestQuestUpdate(questID, false, "QUEST_WATCH_UPDATE") end,
    QUEST_LOG_UPDATE = OnQuestLogUpdate,
    PLAYER_LEVEL_UP = OnLevelUp,
    RAID_BOSS_EMOTE = OnBossEmote,
    ACHIEVEMENT_EARNED = OnAchievementEarned,
    CRITERIA_UPDATE = function(...) OnCriteria("CRITERIA_UPDATE", ...) end,
    CRITERIA_EARNED = function(...) OnCriteria("CRITERIA_EARNED", ...) end,
    TRACKED_ACHIEVEMENT_UPDATE = function(...) OnCriteria("TRACKED_ACHIEVEMENT_UPDATE", ...) end,
    SCENARIO_UPDATE = OnScenarioUpdate,
    SCENARIO_COMPLETED = OnScenarioCompleted,
    SCENARIO_CRITERIA_UPDATE = OnScenarioCriteria,
    VIGNETTES_UPDATED = OnVignettes,
    PLAYER_REGEN_DISABLED = function() rare.combatAt = GetTime() end,
    PLAYER_REGEN_ENABLED = function() rare.combatAt = GetTime() end,
}

function S:Start()
    if started then return end
    started = true
    Q.quietUntil = GetTime() + T.QUEST_RELOAD_QUIET
    local events = CreateFrame("Frame")
    for event in pairs(HANDLERS) do
        -- (an event this client doesn't know is an error to register: left out)
        pcall(events.RegisterEvent, events, event)
    end
    events:SetScript("OnEvent", function(_, event, ...)
        local handler = HANDLERS[event]
        if handler then handler(...) end
    end)
    if UIErrorsFrame and UIErrorsFrame.AddMessage then
        hooksecurefunc(UIErrorsFrame, "AddMessage", OnErrorMessage)
    end
    S.ApplySuppression()
end
