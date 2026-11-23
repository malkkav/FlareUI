local H = dofile('tools/tests/perf-helpers.lua')
local path = 'Modules/ActionBars.lua'
local scans, timers, formReads, broken = 0, {}, 0, false
local function activeFormName()
    formReads = formReads + 1
    if broken then error('unreadable form') end
    return 'Bear'
end
local env = setmetatable({
    activeButtons = {[{}] = true, [{}] = true},
    ActiveFormName = activeFormName,
    UpdateActive = function(_, state)
        assert(state.form == (not broken and 'Bear' or nil))
        scans = scans + 1
    end,
    C_Timer = { After = function(delay, fn) timers[#timers + 1] = {delay, fn} end },
}, { __index = _G })
local onEvent = H.loadSections(path, {
    {'local activeState =', 'local function UpdateActiveAll()'},
}, env, 'OnActiveEvent')
for _ = 1, 100 do onEvent() end
assert(scans == 0 and #timers == 2)
timers[1][2](); assert(scans == 2 and formReads == 1)
onEvent(); assert(#timers == 3)
timers[3][2](); assert(scans == 4 and formReads == 2)
timers[2][2](); assert(scans == 6 and formReads == 3)
broken = true; onEvent(); timers[4][2](); assert(scans == 8 and formReads == 4)

local function no() return false end
env.C_ActionBar = { HasAction = function() return true end, IsAutoRepeatAction = no, IsCurrentAction = no }
env.ActionSpellName = function() return 'Bear' end
env.QueuedName = no
local actionActive = H.loadSections(path, {
    {'local function ActionActive(', 'local function IsActiveButton('},
}, env, 'ActionActive')
formReads, broken = 0, false
assert(actionActive(1, {form = 'Bear'}))
assert(not actionActive(1, {}))
assert(formReads == 0)
assert(actionActive(1))
assert(formReads == 1)
print('PASS: action event bursts coalesce, later frames refresh, delayed safety remains, form snapshot handles no form')
