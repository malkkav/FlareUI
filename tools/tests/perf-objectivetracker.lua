local H = dofile('tools/tests/perf-helpers.lua')
local s = H.read('Modules/ObjectiveTracker.lua')
local factory = H.load([[
return function(old, fresh)
 local state = {sortCount = #old, order = {}}
 local sortDist, sortNew, sortIDs, sortRankOld = {}, {}, {}, {}
 for i, v in ipairs(old) do sortDist[i] = v; sortIDs[i] = i end
 local reads, sorts, renders = 0, 0, 0
 local realSort = table.sort
 local table = {sort = function(...) sorts = sorts + 1; realSort(...) end}
 local OT = {SortsByDistance = function() return true end, RequestRender = function() renders = renders + 1 end}
 local holder, scroll = {IsVisible = function() return true end}, {IsShown = function() return true end}
 local function GetDb() return {} end
 local function Distance(id) return fresh[id] end
 local function ReadLog() reads = reads + 1 end
 local function CollectQuests() return {} end
]] .. H.section(s, 'local function ByOldDistance(', '--------------------------------------------------\n-- 10. MINIMIZE') .. [[
 return function(nextDistances)
  fresh = nextDistances or fresh
  OnSortTick(); return reads, sorts, renders
 end
end
]])
math.randomseed(872)
for trial = 1, 500 do
 local old, new, a, b = {}, {}, {}, {}
 for i = 1, math.random(1, 30) do old[i] = math.random(0, 10); new[i] = math.random(0, 10); a[i], b[i] = i, i end
 table.sort(a, function(x,y) return old[x] == old[y] and x < y or old[x] < old[y] end)
 table.sort(b, function(x,y) return new[x] == new[y] and x < y or new[x] < new[y] end)
 local changed = false
 for i = 1, #a do if a[i] ~= b[i] then changed = true end end
 local reads = factory(old, new)()
 assert((reads > 0) == changed, 'adjacent-order check must match full-sort oracle')
end
local run = factory({10,20,math.huge}, {9,19,math.huge})
local reads, sorts = run(); assert(reads == 0 and sorts == 1)
reads, sorts = run({8,18,math.huge}); assert(reads == 0 and sorts == 1)
reads, sorts = run({8,18,math.huge}); assert(reads == 0 and sorts == 1)
reads = run({18,8,math.huge}); assert(reads == 1)
print('PASS: quest rank cache matches 500 full-sort oracles, handles ties/infinite distance and reuses unchanged ranks')
