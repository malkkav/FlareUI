local H = dofile('tools/tests/perf-helpers.lua')
local s = H.read('Modules/Bags.lua')
H.load([[
local L = setmetatable({}, {__index = function(_, k) return k end})
local Bags = {}
-- locations: 1000000 + bag * 100 + slot in the bags, 2000000 + ... in the bank, small numbers otherwise
local function EquipmentManager_GetLocationData(location)
 if location < 1000000 then return {} end
 local bank = location >= 2000000
 local rest = location % 1000000
 return {isBags = true, isBank = bank, bag = math.floor(rest / 100), slot = rest % 100}
end
local sets = {
 [7] = {name = 'Tank', locations = {[1] = 1000003, [2] = 0, [3] = 1, [5] = 1000105, [6] = 2000502}},
 [4] = {name = 'Fishing', locations = {[16] = 1000003, [17] = 1000201, [18] = -1}},
 [9] = {name = 'Empty', locations = {}},
}
local C_EquipmentSet = {
 GetEquipmentSetIDs = function() return {7, 4, 9} end,
 GetEquipmentSetInfo = function(id) return sets[id].name end,
 GetItemLocations = function(id) return sets[id].locations end,
}
]] .. H.section(s, 'local CATEGORY_ORDER', 'local function ItemCategory(') .. [[
local list, where = Bags.SetCategories.Read()
assert(#list == 3 and list[1].key == 'set:7' and list[1].name == 'Tank' and list[2].name == 'Fishing')
-- an item in two sets goes in the first (Tank's bag 0 slot 3 is also in Fishing)
assert(where[0][3] == 'set:7')
assert(where[1][5] == 'set:7' and where[2][1] == 'set:4')
-- bank items, and empty, ignored or missing slots, are left out
assert(not where[5])
local count = 0
for _, bag in pairs(where) do for _ in pairs(bag) do count = count + 1 end end
assert(count == 3)
-- the grid's order is bottom first: the sets sit between Junk and Equipment, reading Tank first below Equipment
local order = Bags.SetCategories.Order(list)
local want = {'other', 'quest', 'materials', 'junk', 'set:9', 'set:4', 'set:7', 'equipment', 'consumables'}
assert(#order == #want)
for i, key in ipairs(want) do assert(order[i] == key, 'order ' .. i .. ': ' .. tostring(order[i])) end
-- without the Equipment Manager API, no sets
C_EquipmentSet = nil
local none, nowhere = Bags.SetCategories.Read()
assert(#none == 0 and next(nowhere) == nil)
]])
print('PASS: equipment sets become bag categories in Blizzard\'s order, first set wins, bank and empty slots left out')
