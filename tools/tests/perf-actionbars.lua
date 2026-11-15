local H = dofile('tools/tests/perf-helpers.lua')
local s = H.read('Modules/ActionBars.lua')
H.load([[
local scans, timers, formReads, broken = 0, {}, 0, false
local activeButtons = {[{}] = true, [{}] = true}
local function ActiveFormName() formReads = formReads + 1; if broken then error('unreadable form') end; return 'Bear' end
local function UpdateActive(_, state) assert(state.form == (not broken and 'Bear' or nil)); scans = scans + 1 end
local C_Timer = {After = function(delay, fn) timers[#timers + 1] = {delay, fn} end}
]] .. H.section(s, 'local activeState =', 'local function UpdateActiveAll()') .. [[
for i = 1, 100 do OnActiveEvent() end
assert(scans == 0 and #timers == 2)
timers[1][2](); assert(scans == 2 and formReads == 1)
OnActiveEvent(); assert(#timers == 3)
timers[3][2](); assert(scans == 4 and formReads == 2)
timers[2][2](); assert(scans == 6 and formReads == 3)
broken = true; OnActiveEvent(); timers[4][2](); assert(scans == 8 and formReads == 4)
]])
H.load([[
local C_ActionBar = {HasAction = function() return true end, IsAutoRepeatAction = function() return false end,
 IsCurrentAction = function() return false end}
local function ActionSpellName() return 'Bear' end
local function QueuedName() return false end
local reads = 0
local function ActiveFormName() reads = reads + 1; return 'Bear' end
]] .. H.section(s, 'local function ActionActive(', 'local function IsActiveButton(') .. [[
assert(ActionActive(1, {form = 'Bear'}))
assert(not ActionActive(1, {}))
assert(reads == 0)
assert(ActionActive(1))
assert(reads == 1)
]])
print('PASS: action event bursts coalesce, later frames refresh, delayed safety remains, form snapshot handles no form')
