local H = dofile('tools/tests/perf-helpers.lua')
local s = H.read('Modules/BuffReminders.lua')
H.load([[
local BR, ns = {}, {EditPreviewing = function() return false end}
local now, combat, apiReads, reachReads, rosterReads = 0, false, 0, 0, 0
local timers, auras, classReads = {}, {}, 0
for i = 1, 40 do auras['raid' .. i] = {Fort = {expirationTime = 1000}, Int = {expirationTime = 1000}} end
local function canonical(unit) return unit == 'player' and 'raid1' or unit end
local function GetTime() return now end
local function InCombatLockdown() return combat end
local function canaccessvalue() return true end
local function Readable(value) return value end
local function wipe(t) for k in pairs(t) do t[k] = nil end end
local function GetDb() return {group = 'all', before = 2} end
local function IsInRaid() return true end
local function IsInGroup() return true end
local function GetNumGroupMembers() rosterReads = rosterReads + 1; return 40 end
local function UnitExists() reachReads = reachReads + 1; return true end
local function UnitIsDeadOrGhost() return false end
local function UnitIsConnected() return true end
local function UnitIsVisible() return true end
local function UnitIsUnit(a,b) return canonical(a) == canonical(b) end
local function UnitClass() classReads = classReads + 1; return 'Mage','MAGE' end
local function UnitOnTaxi() return false end
local function IsMounted() return false end
local function IsResting() return false end
local function IsInInstance() return false end
local function AurasLocked() return false end
local C_UnitAuras = {GetAuraDataBySpellName = function(unit, name)
 apiReads = apiReads + 1
 local aura = auras[canonical(unit)][name]
 if aura and aura.expirationTime > now then return aura end
end}
local C_Timer = {After = function(_, fn) timers[#timers + 1] = fn end}
]] .. H.section(s, 'local scan =', '-- an option of this kind whose icon')
    .. H.section(s, 'local units = {}', '--------------------------------------------------\n-- 4. ICONS') .. [[
local holder = {}
local active = {
 {key = 'fort', def = {group = true}, names = {Fort = true}},
 {key = 'int', def = {group = true}, names = {Int = true}},
 {key = 'self', def = {}, names = {Fort = true}}}
local snoozed = {}
local function Enabled() return true end
function BR.HideKey(entry) return entry.key end
function BR.KindMode() return 'always' end
local result = {}
function BR.ShowFaded(shows)
 result = {}
 for _, v in ipairs(shows) do result[v.entry.key] = {missing = v.missing, running = v.running} end
end
]] .. H.section(s, 'local shows, pool =', '-- Fade Speed (Fading section)')
    .. H.section(s, 'local pending = false\nlocal function Soon(unit)', '--------------------------------------------------\n-- 6. POSITION') .. [[
local function flush()
 assert(#timers == 1)
 local fn = timers[1]; timers = {}; fn()
end
BR.Update(); assert(apiReads == 81 and reachReads == 40 and rosterReads == 1 and next(result) == nil)
auras.raid5.Fort = nil
for i = 1, 100 do Soon('raid5') end
flush(); assert(apiReads == 83 and result.fort.missing == 1 and not result.fort.running)
assert(reachReads == 80 and rosterReads == 2)
auras.raid1.Fort = nil
Soon('raid1'); flush(); assert(apiReads == 86 and result.self.missing == 1 and result.fort.missing == 2)
Soon('raid2'); Soon(); flush(); assert(apiReads == 167) -- full invalidation wins a mixed burst
BR.Update(); assert(apiReads == 248) -- a direct/UI update never reuses an old snapshot
combat = true; Soon('raid3'); assert(#timers == 0)
combat = false; Soon(); flush(); assert(apiReads == 329)
now = 900; Soon('raid5'); flush()
assert(result.int.running and result.fort.running == false)
local before = apiReads
now = 1001; Soon('raid5'); flush()
assert(apiReads > before and not result.int.running and not result.fort.running)
assert(not scan.active and classReads == 0)
]])
-- Execute the real placement block: unchanged reminders keep their anchors; a reordered slot moves.
H.load([[
local b = {clears = 0, points = 0,
 ClearAllPoints = function(self) self.clears = self.clears + 1 end,
 SetPoint = function(self) self.points = self.points + 1 end}
local parentRow, offset, i, size, spacing, vertical, back = {}, 0, 1, 36, 6, false, false
local function place()
]] .. H.section(s, '        local step = offset + (i - 1) * (size + spacing)', '        b:Show()\n        -- On Mouseover') .. [[
end
place(); place(); assert(b.clears == 1 and b.points == 1)
i = 2; place(); assert(b.points == 2)
vertical = true; place(); assert(b.points == 3)
back = true; place(); assert(b.points == 4)
parentRow = {}; place(); assert(b.points == 5)
]])
print('PASS: reminder caches invalidate units/aliases, full/direct updates and expiry; bursts coalesce, combat skips work, roster/reach and layout reuse')
