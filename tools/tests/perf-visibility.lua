local H = dofile('tools/tests/perf-helpers.lua')
local s = H.read('Modules/Visibility.lua')
H.load([[
local Visibility, SHOW_SPEC, Conditions = {}, {}, {}
local inGroup, reads = false, 0
function Conditions.Set() return {ingroup = true} end
local function IsInGroup() reads = reads + 1; return inGroup end
]] .. H.section(s, 'local function EvaluateShowRule(show)', '-- the spellbook tab') .. [[
local cache = {}
for i = 1, 40 do assert(not ShowRule('ingroup', cache)) end
assert(reads == 1)
inGroup = true
assert(not ShowRule('ingroup', cache))
assert(Visibility.ShowRule('ingroup')) -- external callers never use the fader's snapshot
assert(reads == 2)
cache = {}; assert(ShowRule('ingroup', cache)); assert(reads == 3)
assert(not ShowRule(nil, cache))
]])
-- Run real fader passes to check that event-driven dirty passes invalidate prior results too.
H.load([[
local reads, group = 0, false
local Fader = {updateTimer = 0, dirty = {}, repairTimer = 0, ruleCache = {},
 groups = {a = {{show = 'ingroup'}}, b = {{show = 'ingroup'}}},
 delays = {}, shows = {}, counting = {}, settled = {}, watchesMouseover = true}
local function wipe(t) for k in pairs(t) do t[k] = nil end end
local FADE_DELAY, CHECK_INTERVAL, REPAIR_INTERVAL = 0, .05, 1
local function SpellbookOpen() return false end
local function CheckMember(data, _, _, cache)
 if cache[data.show] == nil then reads = reads + 1; cache[data.show] = group end
 return cache[data.show]
end
for _, members in pairs(Fader.groups) do
 members[1].frame = {GetAlpha = function() return group and 1 or 0 end}
 members[1].minAlpha = 0
end
local math_abs = math.abs
]] .. H.section(s, 'Fader.UpdateScript = function(self, elapsed)', '--------------------------------------------------\n-- 7. EDIT MODE SETTINGS') .. [[
Fader:UpdateScript(.1); assert(reads == 1 and not Fader.shows.a)
group = true; Fader.dirty.a = true
Fader:UpdateScript(0); assert(reads == 2 and Fader.shows.a and Fader.shows.b)
]])
print('PASS: visibility shares true/false rule results per pass, preserves uncached callers and invalidates dirty passes')
