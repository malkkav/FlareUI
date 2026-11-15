local H = dofile('tools/tests/perf-helpers.lua')
local s = H.read('Modules/Minimap.lua')
H.load([[
local repairs, reads, hooks = 0, 0, 0
local placingSun = false
local function PlaceSun() repairs = repairs + 1 end
local function SunMoved() reads = reads + 1; return true end
local Cluster = {DielFrame = {SetPoint = true, SetAllPoints = true, ClearAllPoints = true, SetScale = true, SetParent = true}}
local MM, MinimapFrame = {}, {}
local EventUtil = {ContinueOnAddOnLoaded = function() end}
local function hooksecurefunc() hooks = hooks + 1 end
local function CreateFrame(_, _, parent)
 assert(parent == MinimapFrame)
 return {SetScript = function(self, key, fn) self[key] = fn end}
end
]] .. H.section(s, 'local function KeepSunPlaced()', '--------------------------------------------------\n-- 7. LAYOUT') .. [[
KeepSunPlaced(); assert(repairs == 1 and hooks == 5)
for i = 1, 9 do MM.sunGuard.OnUpdate(MM.sunGuard, .01) end
assert(reads == 0)
MM.sunGuard.OnUpdate(MM.sunGuard, .02); assert(reads == 1 and repairs == 2)
MM.sunGuard.OnShow(MM.sunGuard); assert(repairs == 3 and MM.sunGuard.elapsed == 0)
KeepSunPlaced(); assert(hooks == 5)
]])
print('PASS: minimap guard is parented to map visibility, throttled, repairs on show and hooks once')
