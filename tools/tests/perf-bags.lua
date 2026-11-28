local H = dofile('tools/tests/perf-helpers.lua')
local s = H.read('Modules/Bags.lua')
H.load([[
local noop = function() end
local callbacks, reads, paints, time = {}, 0, 0, 0
local function GetTime() return time end
local info = {hyperlink = 'A', itemID = 1, quality = 2}
local button = {GetBagID = function() return 0 end, GetID = function() return 1 end}
local db = {bagItemLevel = true, bagSkinSlots = false}
local ov = {Show = noop, border = {Hide = noop}, junk = {Hide = noop}, ilvl = {Hide = noop}, eye = {Hide = noop}, boe = {Hide = noop}, set = {Hide = noop}, plain = {SetShown = noop}}
local function GetOverlay() return ov end
local Bags = {StyleIconTexts = noop}
local UpdateItemFilter, UpdateItemBorder, StyleIconText = noop, noop, noop
local function ShowItemData(_, config, _, _, link) assert(config == db); paints = paints + 1 end
local dimmedIcons = {}
local Enum = {ItemQuality = {Poor = 0}}
local cached = false
local C_Item = {IsItemDataCachedByID = function() return cached end}
local C_Container = {GetContainerItemInfo = function() return info end}
local Item = {CreateFromItemLink = function()
 reads = reads + 1
 return {ContinueOnItemLoad = function(_, fn) callbacks[#callbacks + 1] = fn end}
end}
]] .. H.section(s, 'function Bags.DecorateButton(', 'local function UpdateFrameItems(') .. [[
local function draw() Bags.DecorateButton(button, db, info, 0, 1) end
for i = 1, 20 do draw() end
assert(reads == 1)
info = {hyperlink = 'B', itemID = 2}; draw()
info = {hyperlink = 'A', itemID = 1}; draw(); assert(reads == 3)
callbacks[1](); assert(paints == 0 and ov.itemLoad)
callbacks[2](); assert(paints == 0 and ov.itemLoad)
db = {bagItemLevel = true, bagSkinSlots = false}; draw()
callbacks[3](); assert(paints == 1 and not ov.itemLoad)
draw(); assert(reads == 4)
db.bagItemLevel = false; draw(); callbacks[4](); assert(paints == 1)
db.bagItemLevel = true; draw(); assert(reads == 5)
info = nil; draw(); callbacks[5](); assert(paints == 1)
info = {hyperlink = 'C', itemID = 3}; draw(); cached = true; draw()
assert(paints == 2 and not ov.itemLoad)
callbacks[6](); assert(paints == 2)
cached = false; draw(); assert(reads == 7)
time = 5; draw(); assert(reads == 8)
callbacks[7](); assert(paints == 2 and ov.itemLoad)
callbacks[8](); assert(paints == 3 and not ov.itemLoad)
]])
print('PASS: bag item loads deduplicate, reject stale generations, follow current settings and clear completed requests')
