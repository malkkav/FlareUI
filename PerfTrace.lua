local ADDON_NAME, ns = ...

--------------------------------------------------
-- PERF TRACE (/fui perf trace)
-- Finds what in FlareUI makes the garbage and the slow frames. A developer's tool, in two halves:
--   * tools/tracebuild.js writes a "trace build" into the AddOns folder: every hook, script and timer
--     FlareUI sets up is wrapped in ns.T.W / ns.T.After / ns.T.NewTimer with a label naming its file
--     and line. The repo's own files never call these, so a normal install runs none of it.
--   * here: while a trace runs, each wrapped call is timed and its memory counted (what it made
--     itself, minus what the calls inside it made), and every frame where FlareUI took long is kept
--     with the call that took most of it. Stopped, the results open in a window to copy and are kept
--     in FlareUI2_DB.global.perfTrace for the developer to read.
-- Not running, each wrapped call costs one test of a boolean. The report is plain English on
-- purpose, like /fui perf's: it is pasted into bug reports, not read in game.
--------------------------------------------------

local T = { sites = 0 }
ns.T = T

local tracing = false
local gc, clock = collectgarbage, debugprofilestop
local SLOW_FRAME_MS = 8   -- a frame where FlareUI's own calls took this long is listed
local MAX_SLOW = 40

local stats = {}          -- label -> { calls, kb, ms, worst, subs = { event -> { calls, kb, ms } } }
local depth = 0
local childKB, childMS = {}, {}   -- per depth: what the calls inside the open call took
local frameMS, frameTop, frameTopMS = 0, nil, 0
local slowFrames = {}
local run                 -- the trace in progress: start time, memory, counters

local function Record(label, sub, kb, ms)
    local s = stats[label]
    if not s then
        s = { calls = 0, kb = 0, ms = 0, worst = 0 }
        stats[label] = s
    end
    s.calls = s.calls + 1
    s.kb = s.kb + kb
    s.ms = s.ms + ms
    if ms > s.worst then s.worst = ms end
    if sub then
        local subs = s.subs
        if not subs then subs = {} s.subs = subs end
        local t = subs[sub]
        if not t then
            t = { calls = 0, kb = 0, ms = 0 }
            subs[sub] = t
        end
        t.calls = t.calls + 1
        t.kb = t.kb + kb
        t.ms = t.ms + ms
    end
end

local function Leave(label, sub, m0, t0, ...)
    local m1, t1 = gc("count"), clock()
    local d = depth
    local inclKB, inclMS = m1 - m0, t1 - t0
    local selfKB, selfMS = inclKB - (childKB[d] or 0), inclMS - (childMS[d] or 0)
    depth = d - 1
    if run then
        -- the collector ran a step inside the call: what it freed hides what was made
        if selfKB < 0 then run.gcSteps = run.gcSteps + 1 selfKB = 0 end
        Record(label, sub, selfKB, selfMS)
    end
    -- the bookkeeping above is this tool's, not the caller's
    local overheadKB, overheadMS = gc("count") - m1, clock() - t1
    if depth > 0 then
        childKB[depth] = childKB[depth] + inclKB + overheadKB
        childMS[depth] = childMS[depth] + inclMS + overheadMS
    else
        frameMS = frameMS + inclMS
        if inclMS > frameTopMS then frameTop, frameTopMS = label, inclMS end
    end
    return ...
end

local function Run(label, sub, fn, ...)
    local d = depth + 1
    depth = d
    childKB[d], childMS[d] = 0, 0
    local m0 = gc("count")
    return Leave(label, sub, m0, clock(), fn(...))
end

-- One wrapper per function, so a handler set again and again makes no new closures
local wrappers = setmetatable({}, { __mode = "kv" })   -- (weak both ways: a wrapper holds its fn)

-- fn wrapped under label; isEvent: an OnEvent handler, counted per event too
function T.W(label, fn, isEvent)
    if type(fn) ~= "function" then return fn end
    local w = wrappers[fn]
    if w then return w end
    if isEvent then
        w = function(self, event, ...)
            if not tracing then return fn(self, event, ...) end
            return Run(label, event, fn, self, event, ...)
        end
    else
        w = function(...)
            if not tracing then return fn(...) end
            return Run(label, nil, fn, ...)
        end
    end
    wrappers[fn] = w
    return w
end

-- One-shot timers are made all the time: wrapped only while a trace runs, so a normal session
-- makes nothing extra. The wrapping's own memory is taken off the call that asked for the timer.
local function WrapTimer(label, fn)
    if not tracing or type(fn) ~= "function" then return fn end
    local m0, t0 = gc("count"), clock()
    local w = T.W(label, fn)
    if depth > 0 then
        childKB[depth] = childKB[depth] + (gc("count") - m0)
        childMS[depth] = childMS[depth] + (clock() - t0)
    end
    return w
end
function T.After(label, delay, fn) return C_Timer.After(delay, WrapTimer(label, fn)) end
function T.NewTimer(label, delay, fn) return C_Timer.NewTimer(delay, WrapTimer(label, fn)) end

--------------------------------------------------
-- ACEEVENT: handlers live in the library's registry; the ones FlareUI registered are wrapped
-- while a trace runs and put back after
--------------------------------------------------
local restoreList = {}

local function ModuleName(obj)
    for name, module in pairs(ns.modules or {}) do
        if module == obj then return name end
    end
end

local function WrapAceEvents()
    local AceEvent = LibStub and LibStub("AceEvent-3.0", true)
    if not AceEvent then return 0 end
    local count = 0
    for _, reg in ipairs({ AceEvent.events, AceEvent.messages }) do
        for event, list in pairs(reg and reg.events or {}) do
            for obj, fn in pairs(list) do
                local name = type(fn) == "function" and ModuleName(obj)
                if name then
                    local label = name .. " (AceEvent)"
                    local w = function(...)
                        if not tracing then return fn(...) end
                        return Run(label, event, fn, ...)
                    end
                    list[obj] = w
                    restoreList[#restoreList + 1] = { list, obj, fn, w }
                    count = count + 1
                end
            end
        end
    end
    return count
end

local function UnwrapAceEvents()
    for _, r in ipairs(restoreList) do
        if r[1][r[2]] == r[4] then r[1][r[2]] = r[3] end
    end
    wipe(restoreList)
end

--------------------------------------------------
-- FRAMES: once a frame, FlareUI's total in it closes; a long one is kept
--------------------------------------------------
local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function()
    if run then
        run.frames = run.frames + 1
        if frameMS >= SLOW_FRAME_MS and #slowFrames < MAX_SLOW then
            slowFrames[#slowFrames + 1] = { at = GetTime() - run.started, ms = frameMS, top = frameTop or "?", topMS = frameTopMS }
        end
    end
    frameMS, frameTop, frameTopMS = 0, nil, 0
    depth = 0   -- a call that errored never left; nothing spans frames
end)

--------------------------------------------------
-- START / STOP / REPORT
--------------------------------------------------
local function Say(text) print("|cff00ccffFlareUI trace:|r " .. text) end

local function MemoryKB()
    if InCombatLockdown() then return nil end
    UpdateAddOnMemoryUsage()
    return GetAddOnMemoryUsage(ADDON_NAME)
end

local function Start()
    wipe(stats)
    wipe(slowFrames)
    frameMS, frameTop, frameTopMS, depth = 0, nil, 0, 0
    run = { started = GetTime(), frames = 0, gcSteps = 0, memStart = MemoryKB(), date = date("%Y-%m-%d %H:%M") }
    run.aceEvents = WrapAceEvents()
    tracing = true
    driver:Show()
    Say(("Tracing %d hooks, scripts and timers and %d AceEvent handlers. Play normally for a minute or two, then type |cffffff00/fui perf trace|r again.")
        :format(T.sites, run.aceEvents))
end

local function Sorted(field, limit)
    local list = {}
    for label, s in pairs(stats) do list[#list + 1] = { label = label, s = s } end
    table.sort(list, function(a, b) return a.s[field] > b.s[field] end)
    for i = #list, limit + 1, -1 do list[i] = nil end
    return list
end

local function SubLine(s, field)
    if not s.subs then return nil end
    local subs = {}
    for name, t in pairs(s.subs) do subs[#subs + 1] = { name = name, t = t } end
    table.sort(subs, function(a, b) return a.t[field] > b.t[field] end)
    local parts = {}
    for i = 1, math.min(4, #subs) do
        local x = subs[i]
        parts[#parts + 1] = ("%s %d calls %.0f KB %.1f ms"):format(tostring(x.name), x.t.calls, x.t.kb, x.t.ms)
    end
    return "      " .. table.concat(parts, " | ")
end

local function BuildReport()
    local secs = math.max(1, GetTime() - run.started)
    local memEnd = MemoryKB()
    local lines = {}
    local function Add(text) if text then lines[#lines + 1] = text end end
    local totalKB, totalMS = 0, 0
    for _, s in pairs(stats) do totalKB, totalMS = totalKB + s.kb, totalMS + s.ms end
    Add(("FlareUI trace | %s | %.0f s | %d frames | FlareUI %s | build %s")
        :format(run.date, secs, run.frames, C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "?", tostring((select(2, GetBuildInfo())))))
    Add(("Traced: %d sites, %d AceEvent handlers. Measured %.0f KB made (%.1f KB/s), %.0f ms of work (%.3f ms per frame).")
        :format(T.sites, run.aceEvents or 0, totalKB, totalKB / secs, totalMS, totalMS / math.max(1, run.frames)))
    if run.memStart and memEnd then
        Add(("FlareUI memory %.1f -> %.1f MB (+%.0f KB). The traced calls account for about %.0f%% of that growth.")
            :format(run.memStart / 1024, memEnd / 1024, memEnd - run.memStart,
                memEnd > run.memStart and math.min(999, totalKB / (memEnd - run.memStart) * 100) or 0))
    end
    Add(("Collector steps inside calls (their memory reads as 0): %d."):format(run.gcSteps))
    local uf = ns.UnitFrames
    if uf and uf.lastPendingWhy then Add("Unit frames' last full refresh after a fight was asked for by: " .. tostring(uf.lastPendingWhy)) end
    Add("")
    Add("MOST MEMORY (label | calls | KB | KB/s | ms | worst call ms)")
    for _, e in ipairs(Sorted("kb", 30)) do
        local s = e.s
        if s.kb >= 1 then
            Add(("  %s | %d | %.0f | %.1f | %.1f | %.2f"):format(e.label, s.calls, s.kb, s.kb / secs, s.ms, s.worst))
            Add(SubLine(s, "kb"))
        end
    end
    Add("")
    Add("MOST TIME (label | calls | ms | ms per call | worst call ms)")
    for _, e in ipairs(Sorted("ms", 20)) do
        local s = e.s
        Add(("  %s | %d | %.1f | %.3f | %.2f"):format(e.label, s.calls, s.ms, s.ms / math.max(1, s.calls), s.worst))
        Add(SubLine(s, "ms"))
    end
    Add("")
    Add(("SLOW FRAMES (FlareUI over %d ms; at s | FlareUI ms | biggest call)"):format(SLOW_FRAME_MS))
    if #slowFrames == 0 then Add("  none") end
    for _, f in ipairs(slowFrames) do
        Add(("  %.1f | %.1f | %s (%.1f ms)"):format(f.at, f.ms, f.top, f.topMS))
    end
    return table.concat(lines, "\n")
end

local function Stop()
    tracing = false
    driver:Hide()
    UnwrapAceEvents()
    local text = BuildReport()
    run = nil
    local global = ns.db and ns.db.global
    if global then global.perfTrace = text end
    if ns.Perf and ns.Perf.ShowText then ns.Perf.ShowText("FlareUI trace", text) else print(text) end
    Say("Saved. The report is also kept for the developer in the saved settings.")
end

function T.Toggle()
    if not T.instrumented then
        Say("This needs FlareUI's trace build, which the developer makes with tools/tracebuild.js. A normal install has nothing to trace.")
        return
    end
    if tracing then Stop() else Start() end
end
