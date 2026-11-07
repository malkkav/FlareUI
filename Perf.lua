local ADDON_NAME, ns = ...

--------------------------------------------------
-- PERF (/fui perf)
-- Measures FlareUI with Blizzard's addon profiler (C_AddOnProfiler, always on in the client), so the
-- performance work can be ranked on real numbers and each fix shown to help.
--   /fui perf              a snapshot in chat
--   /fui perf start [name] start recording a scenario (city, dummy, dungeon, raid...)
--   /fui perf stop         stop and save it
--   /fui perf report       every saved recording in a window, ready to copy
--   /fui perf clear        forget the saved recordings
-- A recording samples twice a second: the profiler's average over the last 60 frames for FlareUI, all
-- addons and the whole game, plus FPS, split by combat. Spikes come from the profiler's own counters
-- (frames over 1/5/10/50/100 ms), read at start and stop. Memory is read only out of combat, because
-- refreshing it walks every addon (reported to hitch). Nothing runs until a command is typed.
-- Plain English on purpose: the output is for pasting into a bug report, not for reading in game.
--------------------------------------------------

local Perf = {}
ns.Perf = Perf

local MAX_RUNS = 30
local SAMPLE_EVERY = 0.5
local SPIKE_LIMITS = { 1, 5, 10, 50, 100 }

local P = C_AddOnProfiler
local M = Enum and Enum.AddOnProfilerMetric

local function Say(text) print("|cff00ccffFlareUI perf:|r " .. text) end

local function Available()
    return P and M and P.IsEnabled and P.IsEnabled()
end

local function Addon(metric) return P.GetAddOnMetric(ADDON_NAME, metric) or 0 end
local function Overall(metric) return P.GetOverallMetric(metric) or 0 end
local function Game(metric) return P.GetApplicationMetric(metric) or 0 end

local function SpikeCounts()
    local metrics = { M.CountTimeOver1Ms, M.CountTimeOver5Ms, M.CountTimeOver10Ms, M.CountTimeOver50Ms, M.CountTimeOver100Ms }
    local counts = {}
    for i, metric in ipairs(metrics) do counts[i] = Addon(metric) end
    return counts
end

-- KB, or nil in combat (UpdateAddOnMemoryUsage walks every addon)
local function MemoryKB()
    if InCombatLockdown() then return nil end
    UpdateAddOnMemoryUsage()
    return GetAddOnMemoryUsage(ADDON_NAME)
end

-- The same test Core runs at login, so the list matches what this session started
local function ModulesOn()
    local profile = ns.db and ns.db.profile
    local names = {}
    for name, module in pairs(ns.modules) do
        local on = true
        if module.ShouldLoad then
            local ok, result = pcall(module.ShouldLoad, module)
            on = ok and result and true or false
        end
        local moduleDB = profile and profile[name:lower()]
        if moduleDB and moduleDB.enabled == false then on = false end
        if on then names[#names + 1] = name end
    end
    table.sort(names)
    return names
end

local function Runs()
    local global = ns.db and ns.db.global
    if not global then return nil end
    global.perfRuns = global.perfRuns or {}
    return global.perfRuns
end

--------------------------------------------------
-- 1. SNAPSHOT
--------------------------------------------------
local function PrintSnapshot()
    local recent, all, game = Addon(M.RecentAverageTime), Overall(M.RecentAverageTime), Game(M.RecentAverageTime)
    local share = all > 0 and (recent / all * 100) or 0
    Say(("FlareUI %.3f ms per frame (last 60 frames), %.0f%% of all addons (%.3f ms). Whole game %.2f ms, %.0f FPS.")
        :format(recent, share, all, game, GetFramerate()))
    Say(("This session: FlareUI average %.3f ms, worst frame %.1f ms."):format(Addon(M.SessionAverageTime), Addon(M.PeakTime)))
    local kb = MemoryKB()
    if kb then Say(("FlareUI memory %.1f MB."):format(kb / 1024)) end
    Say("|cffffff00/fui perf start <name>|r to record a scenario, |cffffff00stop|r, |cffffff00report|r, |cffffff00clear|r.")
end

--------------------------------------------------
-- 2. RECORDING
--------------------------------------------------
local active   -- the recording in progress, or nil
local events = CreateFrame("Frame")

local function NewSide() return { n = 0, addon = 0, addonMax = 0, all = 0, game = 0, fps = 0, fpsMin = math.huge } end

local function Sample()
    local run = active
    if not run then return end
    local side = InCombatLockdown() and run.combat or run.calm
    local recent = Addon(M.RecentAverageTime)
    local fps = GetFramerate()
    side.n = side.n + 1
    side.addon = side.addon + recent
    if recent > side.addonMax then side.addonMax = recent end
    side.all = side.all + Overall(M.RecentAverageTime)
    side.game = side.game + Game(M.RecentAverageTime)
    side.fps = side.fps + fps
    if fps < side.fpsMin then side.fpsMin = fps end
    local group = GetNumGroupMembers()
    if group > run.group then run.group = group end
end

-- Boss fights: the profiler keeps its own average for the encounter, read when it ends
events:SetScript("OnEvent", function(_, event, _, encounterName)
    if not active then return end
    if event == "ENCOUNTER_START" then
        active.encounterName = encounterName
    elseif event == "ENCOUNTER_END" then
        active.encounters[#active.encounters + 1] = {
            name = active.encounterName or encounterName or "?",
            addon = Addon(M.EncounterAverageTime),
            all = Overall(M.EncounterAverageTime),
        }
    end
end)

local function Start(label)
    if active then Say("Already recording \"" .. active.label .. "\". Type |cffffff00/fui perf stop|r first.") return end
    local runs = Runs()
    if not runs then Say("Settings aren't loaded yet.") return end
    if label == "" then label = "run " .. (#runs + 1) end
    local _, instanceType = IsInInstance()
    active = {
        label = label,
        started = GetTime(),
        date = date("%Y-%m-%d %H:%M"),
        instance = instanceType or "none",
        group = GetNumGroupMembers(),
        spikes = SpikeCounts(),
        peak = Addon(M.PeakTime),
        memStart = MemoryKB(),
        calm = NewSide(),
        combat = NewSide(),
        encounters = {},
    }
    active.ticker = C_Timer.NewTicker(SAMPLE_EVERY, Sample)
    events:RegisterEvent("ENCOUNTER_START")
    events:RegisterEvent("ENCOUNTER_END")
    Say("Recording \"" .. label .. "\". Play normally, then type |cffffff00/fui perf stop|r.")
end

local function Finish(side)
    if side.n == 0 then return nil end
    return {
        n = side.n,
        addon = side.addon / side.n, addonMax = side.addonMax,
        all = side.all / side.n, game = side.game / side.n,
        fps = side.fps / side.n, fpsMin = side.fpsMin,
    }
end

local function Stop()
    local run = active
    if not run then Say("Nothing is recording. Type |cffffff00/fui perf start <name>|r.") return end
    active = nil
    run.ticker:Cancel()
    events:UnregisterAllEvents()

    local spikes = SpikeCounts()
    for i = 1, #spikes do spikes[i] = spikes[i] - (run.spikes[i] or 0) end
    local peak = Addon(M.PeakTime)
    local _, class = UnitClass("player")
    local saved = {
        label = run.label,
        date = run.date,
        seconds = math.floor(GetTime() - run.started + 0.5),
        version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "?",
        build = (select(2, GetBuildInfo())),
        class = class,
        instance = run.instance,
        group = run.group,
        calm = Finish(run.calm),
        combat = Finish(run.combat),
        spikes = spikes,
        newPeak = peak > run.peak and peak or nil,
        memStart = run.memStart,
        memEnd = MemoryKB(),
        encounters = #run.encounters > 0 and run.encounters or nil,
        modules = table.concat(ModulesOn(), ", "),
    }
    local runs = Runs()
    runs[#runs + 1] = saved
    while #runs > MAX_RUNS do table.remove(runs, 1) end
    Say(("Saved \"%s\" (%d s). Type |cffffff00/fui perf report|r to copy every recording."):format(saved.label, saved.seconds))
end

--------------------------------------------------
-- 3. REPORT
--------------------------------------------------
local function SideLine(name, s)
    if not s then return nil end
    return ("  %s (%d samples): FlareUI avg %.3f ms, highest %.3f | all addons %.3f | game %.2f ms | FPS avg %.0f, low %.0f")
        :format(name, s.n, s.addon, s.addonMax, s.all, s.game, s.fps, s.fpsMin)
end

local function RunText(i, r)
    local lines = {}
    local function Add(text) if text then lines[#lines + 1] = text end end
    Add(("#%d \"%s\" | %s | %d s | FlareUI %s | build %s | %s | %s | group %d")
        :format(i, r.label, r.date, r.seconds, r.version, tostring(r.build), r.class or "?", r.instance, r.group))
    Add(SideLine("out of combat", r.calm))
    Add(SideLine("in combat", r.combat))
    Add(("  FlareUI frames over 1/5/10/50/100 ms: %s"):format(table.concat(r.spikes, "/")))
    if r.newPeak then Add(("  new worst FlareUI frame: %.1f ms"):format(r.newPeak)) end
    if r.memStart or r.memEnd then
        local function MB(kb) return kb and ("%.1f MB"):format(kb / 1024) or "in combat" end
        Add(("  FlareUI memory: %s -> %s"):format(MB(r.memStart), MB(r.memEnd)))
    end
    for _, e in ipairs(r.encounters or {}) do
        Add(("  encounter %s: FlareUI avg %.3f ms | all addons %.3f ms"):format(e.name, e.addon, e.all))
    end
    Add("  modules on: " .. r.modules)
    return table.concat(lines, "\n")
end

local reportFrame
local function ShowReport()
    local runs = Runs()
    if not runs or #runs == 0 then Say("No recordings yet. Type |cffffff00/fui perf start <name>|r.") return end
    local parts = { ("FlareUI perf report, %d recording(s)"):format(#runs) }
    for i, r in ipairs(runs) do parts[#parts + 1] = RunText(i, r) end
    local text = table.concat(parts, "\n\n")

    local f = reportFrame
    if not f then
        local LSM = LibStub("LibSharedMedia-3.0")
        f = CreateFrame("Frame", "FlareUI_PerfReport", UIParent, "BackdropTemplate")
        f:SetSize(720, 440)
        f:SetPoint("CENTER")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetToplevel(true)
        f:SetClampedToScreen(true)
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = LSM:Fetch("border", "Blizzard Tooltip"),
                        edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
        f:SetBackdropColor(0, 0, 0, 0.95)
        f:SetBackdropBorderColor(ns.BORDER_COLOR.r, ns.BORDER_COLOR.g, ns.BORDER_COLOR.b, 1)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", 14, -12)
        title:SetText("FlareUI perf report")
        local note = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        note:SetPoint("BOTTOMLEFT", 14, 10)
        note:SetText("Ctrl+C to copy, then paste it to the developer.")
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -2, -2)

        local scroll = CreateFrame("ScrollFrame", nil, f)
        scroll:SetPoint("TOPLEFT", 14, -34)
        scroll:SetPoint("BOTTOMRIGHT", -24, 28)
        local box = CreateFrame("EditBox", nil, scroll)
        box:SetMultiLine(true)
        box:SetAutoFocus(false)
        box:SetMaxLetters(0)
        box:SetFontObject("ChatFontNormal")
        box:SetWidth(720 - 14 - 24)
        box:SetScript("OnEscapePressed", function() f:Hide() end)
        -- read-only: typing puts the text back
        box:SetScript("OnTextChanged", function(self, userInput)
            if not userInput then return end
            self:SetText(f.text or "")
            self:HighlightText()
        end)
        scroll:SetScrollChild(box)
        f.box = box
        if ns.SettingsPanel and ns.SettingsPanel.AttachScrollLine then ns.SettingsPanel.AttachScrollLine(scroll, f) end

        f:SetScript("OnHide", function() box:ClearFocus() end)
        tinsert(UISpecialFrames, "FlareUI_PerfReport")
        reportFrame = f
    end
    f.text = text
    f.box:SetText(text)
    f:Show()
    f:Raise()
    f.box:SetFocus()
    f.box:HighlightText()
end

--------------------------------------------------
-- 4. COMMAND (from Launcher.lua's /fui)
--------------------------------------------------
function Perf.Command(args)
    if not Available() then Say("Blizzard's addon profiler isn't available on this client.") return end
    local word, rest = (args or ""):match("^%s*(%S*)%s*(.-)%s*$")
    word = word:lower()
    if word == "" then
        PrintSnapshot()
    elseif word == "start" then
        Start(rest)
    elseif word == "stop" then
        Stop()
    elseif word == "report" then
        ShowReport()
    elseif word == "clear" then
        if active then
            active.ticker:Cancel()
            events:UnregisterAllEvents()
            active = nil
        end
        local global = ns.db and ns.db.global
        if global then global.perfRuns = nil end
        Say("Recordings cleared.")
    else
        PrintSnapshot()
    end
end
