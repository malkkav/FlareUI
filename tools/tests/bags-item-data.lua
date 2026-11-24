-- Run from the repository root: luajit tools/tests/bags-item-data.lua
-- What the bags and the loot window share about an item (item level, missing appearance, binds when equipped,
-- the border art): the whole of Bags.lua loaded with client doubles, whatever its layout or line endings (#183).
local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
env.Enum = env.Enum or {}
env.Enum.ItemBind = { OnEquip = 2 }
env.Enum.ItemClass = { Weapon = 2, Armor = 4 }
env.C_Item = {
    GetItemInfo = function(link) return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, link == "boe" and 2 or 1 end,
    GetItemInfoInstant = function() return nil, nil, nil, nil, nil, 1 end,
}
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    modules = {}, db = { profile = { tweaks = {} } },
}
ui:load("Modules/Bags.lua", ns)
local Bags = assert(ns.Bags)

assert(type(Bags.ItemLevelOf) == "function", "ItemLevelOf is shared")
assert(type(Bags.Uncollected) == "function", "Uncollected is shared")
assert(Bags.ItemLevelOf("potion") == nil, "a non-gear item has no level")
assert(Bags.Uncollected("potion") == false, "a non-gear item has no appearance")
assert(Bags.IsBoE("boe") == true, "a BoE link")
assert(Bags.IsBoE("bop") == false, "a non-BoE link")
assert(Bags.ITEM_BORDERS.thick[1] == "FlareUI Thick", "thick border art")
assert(Bags.ITEM_BORDERS.thin[2] == 8, "thin border edge size")
print("PASS: bags item data")
