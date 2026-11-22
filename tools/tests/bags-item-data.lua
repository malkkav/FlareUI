local H = dofile('tools/tests/perf-helpers.lua')
local s = H.read('Modules/Bags.lua')
H.load([[
local Bags = {}
local wipe = function(t) for k in pairs(t) do t[k] = nil end end
Enum = { ItemBind = { OnEquip = 2 }, ItemClass = { Weapon = 2, Armor = 4 } }
C_Item = {
    GetItemInfo = function(link) return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, link == "boe" and 2 or 1 end,
    GetItemInfoInstant = function() return nil, nil, nil, nil, nil, 1 end,
}
]] .. H.section(s, 'local BORDERS =', '\n\n') .. '\n' .. H.section(s, 'local itemLevels, uncollected', 'local function ShowItemLevel(') .. H.section(s, 'local BIND_ON_EQUIP', 'local function ShowItemData(') .. [[

assert(type(Bags.ItemLevelOf) == "function", "ItemLevelOf is shared")
assert(type(Bags.Uncollected) == "function", "Uncollected is shared")
assert(Bags.ItemLevelOf("potion") == nil, "a non-gear item has no level")
assert(Bags.Uncollected("potion") == false, "a non-gear item has no appearance")
assert(Bags.IsBoE("boe") == true, "a BoE link")
assert(Bags.IsBoE("bop") == false, "a non-BoE link")
assert(Bags.ITEM_BORDERS.thick[1] == "FlareUI Thick", "thick border art")
assert(Bags.ITEM_BORDERS.thin[2] == 8, "thin border edge size")
]])
print("PASS: bags item data")
