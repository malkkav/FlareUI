local H = dofile('tools/tests/perf-helpers.lua')
local s = H.read('Modules/ProcGlow.lua')
H.load([[
local now, timers, paints = 10, {}, 0
local function GetTime() return now end
local function wipe(t) for k in pairs(t) do t[k] = nil end end
local boosted = {}
local function ScheduleNow() paints = paints + 1 end
local C_Timer = {NewTimer = function(delay, fn)
 local t = {at = now + delay, fn = fn, Cancel = function(self) self.cancelled = true end}
 timers[#timers + 1] = t; return t
end}
local BP = {procs = {{auraUntil = 20, glows = {'A'}}, {auraUntil = 30, glows = {'B'}}}, want = {}}
function BP.IsOn(proc) return proc.auraUntil and proc.auraUntil > now end
]] .. H.section(s, 'function BP.ScheduleExpiry()', '-- the class\'s procs')
    .. H.section(s, 'function BP.Recompute()', '-- Your buffs')
    .. H.section(s, 'function BP.Stop()', '--------------------------------------------------\n-- 3.') .. [[
BP.Recompute(); assert(#timers == 1 and BP.expiryAt == 20 and paints == 1)
BP.Recompute(); assert(#timers == 1)
BP.procs[1].auraUntil = 40; BP.Recompute()
assert(#timers == 2 and timers[1].cancelled and BP.expiryAt == 30)
now = 30.1; timers[2].fn()
assert(BP.expiryAt == 40 and #timers == 3 and paints == 2)
BP.procs[1].auraUntil = nil; BP.Recompute()
assert(timers[3].cancelled and not BP.expiryTimer)
BP.procs[1].auraUntil = math.huge; BP.Recompute(); assert(#timers == 3)
BP.procs[1].auraUntil = 50; BP.Recompute()
BP.Stop(); assert(timers[4].cancelled and not BP.expiryTimer and not BP.expiryAt)
]])
print('PASS: one proc expiry timer, refresh replacement, expiry chaining, consumption and stop cancellation')
