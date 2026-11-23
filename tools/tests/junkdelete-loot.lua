local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local loot = env.CreateFrame("Frame", "LootFrame", env.UIParent)
loot.ScrollBox = env.CreateFrame("Frame", nil, loot)
local row = env.CreateFrame("Frame", nil, loot.ScrollBox)
row.GetSlotIndex = function() return 1 end
row.Item = env.CreateFrame("Button", nil, row)
local onAcquired
env.ScrollUtil = {
    AddAcquiredFrameCallback = function(box, callback, _, includeExisting)
        assert(box == loot.ScrollBox and includeExisting)
        onAcquired = callback
        callback(row, {})
    end,
}

local profile = { deleteJunkWhenFull = true }
local ns = { db = { profile = { tweaks = profile } },
    L = setmetatable({}, { __index = function(_, key) return key end }) }
env.Enum = { ItemQuality = { Poor = 0 }, LootSlotType = { Item = 1, Money = 2 } }
env.bit = require("bit")
env.GetLootSlotType = function() return ui.money and 2 or 1 end
env.GetLootSlotLink = function() return "|Hitem:77|h[Ore]|h" end
env.IsModifiedClick = function() return ui.shift end
local free, family = 0, 0
local items = {
    { itemID = 11, quality = 0, stackCount = 2, hyperlink = "Old Boot" },
    { itemID = 12, quality = 0, stackCount = 1, hyperlink = "Dry Bone" },
    { itemID = 13, quality = 0, stackCount = 20, hyperlink = "Uncached" },
    { itemID = 14, quality = 0, hasNoValue = true, isLocked = true },
    { itemID = 15, quality = 0, hasNoValue = true }, -- quest item
    { itemID = 77, quality = 1, stackCount = 20 },
}
local pickups, deletions, messages = {}, {}, {}
env.print = function(message) messages[#messages + 1] = message end
env.GetCursorInfo = function() if ui.cursor then return "item", ui.cursor end end
env.CursorHasItem = function() return ui.cursor ~= nil end
env.ClearCursor = function() ui.cursor, ui.cleared = nil, true end
env.DeleteCursorItem = function()
    deletions[#deletions + 1] = ui.cursor
    for i, item in pairs(items) do if item.itemID == ui.cursor then items[i] = nil end end
    ui.cursor = nil
end
env.C_Item = {
    GetItemInfoInstant = function() return 77 end,
    GetItemFamily = function() return 16 end,
    GetItemMaxStackSizeByID = function() return 20 end,
    GetItemInfo = function(id) return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, ({ [11] = 6, [12] = 9 })[id] end,
}
env.C_Container = {
    GetContainerNumFreeSlots = function(bag) if bag == 0 then return free, family end end,
    GetContainerNumSlots = function(bag) return bag == 0 and 6 or 0 end,
    GetContainerItemInfo = function(_, slot) return items[slot] end,
    GetContainerItemQuestInfo = function(_, slot) if slot == 5 then return { questID = 5 } end end,
    PickupContainerItem = function(bag, slot)
        assert(bag == 0)
        pickups[#pickups + 1] = slot
        ui.cursor = ui.wrongPickup and 99 or items[slot].itemID
    end,
}
ui:load("Modules/JunkDelete.lua", ns)
ui:emit("PLAYER_LOGIN")
onAcquired(nil, row)
local function click() row.Item:Click() end

free = 1
click()
family = 16
click()
free = 0
items[6].stackCount = 19
click()
items[6].stackCount = 20
assert(#pickups == 0, "free general, compatible specialized, and partial stacks avoid deletion")
for _, condition in ipairs({ "shift", "money", "combat", "cursor" }) do
    ui[condition] = true
    click()
    ui[condition] = nil
end
assert(#pickups == 0, "skip modified clicks, non-items, combat and occupied cursors")
free, family = 1, 8  -- a free slot for another item family does not fit this one
click()
assert(#pickups == 1 and pickups[1] == 2 and deletions[1] == 12)
assert(messages[1]:find("Dry Bone", 1, true), "report the deleted cheapest stack")
ui.wrongPickup = true
click()
assert(pickups[2] == 1 and #deletions == 1 and ui.cleared and not ui.cursor, "wrong cursor item is cleared without deletion")
ui.wrongPickup = false
items[4].isLocked = false
click()
assert(pickups[3] == 4 and deletions[2] == 14)
profile.deleteJunkWhenFull = false
click()
assert(#pickups == 3)
print("PASS: junk deletion only frees an eligible cheapest stack when loot cannot fit")
