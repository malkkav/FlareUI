local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local messages = {}
env.print = function(text) messages[#messages + 1] = text end
env.date = function() return "11-22 17:30:00" end
env.GetBuildInfo = function() return "1.16", "12345" end
env.UnitClass = function() return "Mage", "MAGE" end
env.LibStub = function(name)
    if name == "LibSharedMedia-3.0" then return { Fetch = function() return "test-border" end } end
end
env.canaccessvalue = function(value) return value ~= "hidden" end
env.C_Timer.NewTimer = env.C_Timer.NewTicker
local enabled, peak, recent, spikes, fps, group, memory = false, 3, 1, 2, 60, 1, 1024
env.Enum = { AddOnProfilerMetric = {} }
local metrics = env.Enum.AddOnProfilerMetric
for _, name in ipairs({
    "CountTimeOver1Ms", "CountTimeOver5Ms", "CountTimeOver10Ms", "CountTimeOver50Ms", "CountTimeOver100Ms",
    "RecentAverageTime", "SessionAverageTime", "PeakTime", "EncounterAverageTime",
}) do
    metrics[name] = name
end
env.C_AddOnProfiler = {
    IsEnabled = function() return enabled end,
    GetAddOnMetric = function(_, metric)
        if metric == metrics.PeakTime then return peak end
        if metric:find("^Count") then return spikes end
        return recent
    end,
    GetOverallMetric = function() return 3 end,
    GetApplicationMetric = function() return 9 end,
}
env.GetFramerate = function() return fps end
env.GetNumGroupMembers = function() return group end
env.IsInInstance = function() return true, "party" end
env.UpdateAddOnMemoryUsage = function() assert(not ui.combat) end
env.GetAddOnMemoryUsage = function() return memory end

local ns = {
    db = { global = {}, profile = { off = { enabled = false } } },
    modules = { On = {}, Off = {}, Refuses = { ShouldLoad = function() return false end } },
    BORDER_COLOR = { r = 0.6, g = 0.4, b = 0.3 },
    IsGamepadUI = function() return false end,
}
local Widget = getmetatable(env.UIParent)
if not Widget.SetMultiLine then function Widget:SetMultiLine(value) self.multiLine = value end end
ui:load("Perf.lua", ns)
local perf = ns.Perf
perf.Command()
assert(messages[#messages]:find("isn't available", 1, true))
enabled = true
perf.Command("report")
assert(messages[#messages]:find("No recordings", 1, true))
perf.Command("start   Deadmines")
local ticker = ui.timers[#ui.timers]
perf.Command("start ignored")
assert(messages[#messages]:find('Already recording "Deadmines"', 1, true))
ticker.callback()
recent, fps, ui.combat, group = 2, 42, true, 5
ticker.callback()
ui:emit("ENCOUNTER_START", 1, "Mr. Smite")
recent, fps = 4, 36
ticker.callback()
ui:emit("ENCOUNTER_END", 1)
peak, spikes, ui.time = 6, 7, 105
perf.Command("stop")
local run = ns.db.global.perfRuns[1]
assert(ticker.cancelled and run.seconds == 5 and run.label == "Deadmines")
assert(run.calm.addon == 1 and run.combat.addon == 3 and run.combat.fpsMin == 36 and run.group == 5)
assert(run.spikes[1] == 5 and run.newPeak == 6 and run.modules == "On" and run.memEnd == nil)
assert(run.encounters[1].name == "Mr. Smite")
perf.Command("report")
local report = env.FlareUI_PerfReport
assert(report:IsShown() and report.box:HasFocus())
assert(report.text:find("encounter Mr. Smite", 1, true) and report.text:find("1.0 MB -> in combat", 1, true))
report.box:SetText("Edited locally")
report.box:RunScript("OnTextChanged", true)
assert(report.box:GetText() == report.text)
report.box:RunScript("OnEscapePressed")
assert(not report:IsShown() and not report.box:HasFocus())
perf.Command("start")
local clearTicker = ui.timers[#ui.timers]
perf.Command("clear")
assert(clearTicker.cancelled and ns.db.global.perfRuns == nil)

local milliseconds, kilobytes = 0, 500
env.debugprofilestop = function() return milliseconds end
env.collectgarbage = function(mode) assert(mode == "count"); return kilobytes end
local function aceCallback() milliseconds = milliseconds + 2 end
local listeners = { [ns.modules.On] = aceCallback }
local ace = { events = { events = { PLAYER_LOGIN = listeners } }, messages = { events = {} } }
local basicLib = env.LibStub
env.LibStub = function(name) return name == "AceEvent-3.0" and ace or basicLib(name) end
ui:load("PerfTrace.lua", ns)
local trace = ns.T
trace.Toggle()
assert(messages[#messages]:find("needs FlareUI's trace build", 1, true))
trace.instrumented, trace.sites, ui.combat = true, 2, false
local child = trace.W("Inner", function() milliseconds = milliseconds + 5; kilobytes = kilobytes + 2 end)
local outer = trace.W("Outer", function(_, event)
    assert(event == "UNIT_AURA")
    milliseconds, kilobytes = milliseconds + 4, kilobytes + 1
    child()
    trace.After("Later", 0, function() kilobytes = kilobytes - 2 end)
    return nil, "result"
end, true)
trace.Toggle()
assert(listeners[ns.modules.On] ~= aceCallback)
local empty, result = outer({}, "UNIT_AURA")
assert(empty == nil and result == "result")
listeners[ns.modules.On]()
local traceDriver = ui:find(function(frame) return frame:GetScript("OnUpdate") ~= nil and frame:IsShown() end)
traceDriver:RunScript("OnUpdate")
ui:flushTimers()
memory = 1060
perf.Command("trace")
assert(listeners[ns.modules.On] == aceCallback and not traceDriver:IsShown())
local log = ns.db.global.perfTrace
assert(log:find("UNIT_AURA 1 calls", 1, true) and log:find("PLAYER_LOGIN 1 calls", 1, true))
assert(log:find("Outer (9.0 ms)", 1, true) and log:find("their memory reads as 0): 1", 1, true))

env.SmartNavigation = { open = true, cursor = true }
env.issecurevariable = function(t, key) return key == "open" or type(t) == "string", "TestAddon" end
ui:load("TaintWatch.lua", ns)
ns.TaintWatch.Command()
local taintTicker = ui.timers[#ui.timers]
local notes = ns.db.global.taintWatch
assert(#notes == 1 and notes[1]:find("SmartNavigation.cursor", 1, true))
taintTicker.callback()
assert(#notes == 1)
ui.combat = true
ui:emit("ADDON_ACTION_BLOCKED", "OtherAddon", "SomeAction")
assert(#notes == 2 and notes[2]:find("[combat] blocked: SomeAction", 1, true))
for _ = 1, 102 do ui:emit("ADDON_ACTION_FORBIDDEN", "OtherAddon", "SomeAction") end
assert(#notes == 100 and notes[1]:find("forbidden", 1, true))
ns.TaintWatch.Command(" REPORT ")
assert(messages[#messages]:find("SomeAction", 1, true))
ns.TaintWatch.Command()
assert(taintTicker.cancelled)
ns.TaintWatch.Command("clear")
assert(#notes == 0)
-- the chat's globals and the pad's bound keys are watched too: those stay tainted until a /reload (11-23)
ui.combat = false
env.GamepadSharedUtility = { InputBindingManager = { activeBindings = { PADDUP = {} }, bindingSetStack = { {} } } }
env.issecurevariable = function(t, key)
    local poisoned = t == "LAST_ACTIVE_CHAT_EDIT_BOX" or key == "PADDUP" or key == 1
    return not poisoned, poisoned and "FlareUI" or nil
end
ns.TaintWatch.Command()
local joined = table.concat(notes, "\n")
assert(joined:find("LAST_ACTIVE_CHAT_EDIT_BOX is tainted (by FlareUI)", 1, true) and joined:find("activeBindings[PADDUP]", 1, true)
    and joined:find("bindingSetStack[1]", 1, true))
ns.TaintWatch.Command()
ns.TaintWatch.Command("clear")

local function chat(index, text, group)
    local window = env.CreateFrame("ScrollingMessageFrame", "ChatFrame" .. index)
    function window:ContainsMessageGroup(name) return name == group end
    function window:GetNumMessages() return 1 end
    function window:GetMessageInfo() return text end
end
chat(1, "Alba says: Hello there", "SAY")
chat(2, "hidden", "SAY")
env.FCF_GetChatWindowInfo = function(index) return index == 1 and "Main" or "Quiet" end
ui:load("SayLog.lua", ns)
local say = ns.SayLog
say.Command()
ui:emit("CHAT_MSG_SAY", "Hello there", "Alba")
ui:emit("CHAT_MSG_YELL", "Over here", "Alba")
ui:emit("CHAT_MSG_SAY", "hidden", "Alba")
ui:flushTimers()
local sayStore = ns.db.global.sayLog
assert(sayStore.on and #sayStore.notes == 3)
assert(sayStore.notes[1].line:find("text hidden", 1, true))
assert(sayStore.notes[2].line:find("MISSING from Quiet; shown in Main", 1, true))
assert(sayStore.notes[3].line:find("no chat window is set to show YELL", 1, true))
say.Command("report")
assert(messages[#messages]:find("text hidden", 1, true), "The report prints missing lines ahead of the rest")
say.Command()
ui:emit("CHAT_MSG_YELL", "Ignored", "Alba")
ui:flushTimers()
assert(not sayStore.on and #sayStore.notes == 3)
say.Command("clear")
assert(#sayStore.notes == 0)

print("PASS: performance recording, trace reports, taint observations and missing chat diagnostics")
