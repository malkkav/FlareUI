local H = dofile('tools/tests/perf-helpers.lua')
local s = H.read('Modules/DamageMeter.lua')
H.load([[
local now, queries, secondsReads, fighting = 0, 0, 0, true
local function GetTime() return now end
local function canaccessvalue() return true end
local function UnitAffectingCombat(unit) queries = queries + 1; return unit == 'raid40' and fighting end
local function IsInGroup() return true end
local function IsInRaid() return true end
local function GetNumGroupMembers() return 40 end
local function GetNumSubgroupMembers() return 4 end
local function CreateFrame()
 return {Hide = function(self) self.shown = false end, SetShown = function(self, v) self.shown = v end,
 SetScript = function(self, event, fn) self[event] = fn end}
end
local function GetDb() return {enabled = true, combatTimer = true} end
local Enum = {DamageMeterSessionType = {Current = 1}}
local C_DamageMeter = {GetSessionDurationSeconds = function() secondsReads = secondsReads + 1; return now end}
local function SecondsToClock(n) return tostring(n) end
local function GetWindowSessionTimer() return {SetAlpha = function() end} end
]] .. H.section(s, 'local liveTimers = {}', '-- after a fight (Threat View in Combat)') .. [[
local function window(visible)
 return {IsVisible = function(self) return self.visible end, visible = visible, GetSessionType = function() return 1 end}
end
local a, b = window(true), window(false)
local function text() return {SetText = function(self, v) self.text = v end, SetShown = function(self,v) self.shown = v end, Hide = function() end} end
liveTimers[a], liveTimers[b] = text(), text()
UpdateLiveTimers(); assert(queries == 41 and secondsReads == 1 and timerDriver.shown)
for i = 1, 10 do now = i * .1; timerDriver.OnUpdate(timerDriver, .1) end
assert(queries <= 123 and secondsReads == 11)
b.visible = true; now = 1.2; timerDriver.OnUpdate(timerDriver,.1)
assert(liveTimers[b].text and secondsReads == 13)
fighting = false
timerEvents.OnEvent(timerEvents,'GROUP_ROSTER_UPDATE')
assert(not timerDriver.shown)
now = 2; timerEvents.OnEvent(timerEvents,'PLAYER_REGEN_DISABLED'); assert(timerDriver.shown)
assert(combatStart == 2)
timerEvents.OnEvent(timerEvents,'GROUP_ROSTER_UPDATE'); assert(combatStart == 2)
timerEvents.OnEvent(timerEvents,'PLAYER_REGEN_ENABLED'); assert(not timerDriver.shown)
]])
print('PASS: combat timer bounds roster polling, skips hidden windows and refreshes immediately for roster/player transitions')
