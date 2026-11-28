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
env.SpellIsTargeting = function() return ui.targeting end
local locked, quality = false, 1
env.GetLootSlotInfo = function() return nil, "Ore", 1, nil, quality, locked end
env.GetLootThreshold = function() return 2 end
ns.IsMasterLooter = function() return ui.master end
env.Enum.BagIndex = { Keyring = -1, ReagentBag = 5 }
env.Enum.BagSlotFlags = { ExcludeJunkSell = 64 }
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
    GetItemFamily = function() return ui.itemFamily or 16 end,
    GetItemMaxStackSizeByID = function() return 20 end,
    GetItemInfo = function(id)
        return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, ({ [11] = 6, [12] = 9 })[id], nil, nil, nil, nil, nil, id == 77 and ui.reagent
    end,
}
env.C_Container = {
    -- (bag 1 is the special one; 5 the crafting bag, -1 the keyring)
    GetContainerNumFreeSlots = function(bag)
        if bag == 0 then return family == 0 and free or 0, 0 end
        if bag == 1 then return family ~= 0 and free or 0, family end
        if bag == 5 then return ui.reagentFree or 0, 0 end
        return ui.keyFree or 0, 256
    end,
    GetContainerNumSlots = function(bag) return bag == 0 and 6 or (bag == 5 and 2) or (bag == 1 and family ~= 0 and 1) or 0 end,
    GetContainerItemInfo = function(bag, slot)
        if bag == 5 then return slot == 1 and ui.reagentStack or nil end
        if bag == 1 then return { itemID = 90, quality = 0, hasNoValue = true } end
        return items[slot]
    end,
    GetContainerItemEquipmentSetInfo = function(_, slot) return ui.setSlot == slot end,
    GetBackpackSellJunkDisabled = function() return ui.keepBackpack end,
    GetBagSlotFlag = function() return false end,
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
-- (each click well after the last one, unless told otherwise)
local function click(again)
    ui.time = (ui.time or 100) + (again or 5)
    row.Item:Click()
end

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
-- (11-24) a click that takes nothing deletes nothing: locked, a spell on the cursor, the master looter's item
locked = true
click()
locked, ui.targeting = false, true
click()
ui.targeting, ui.master, quality = nil, true, 2
click()
ui.master, quality = nil, 1
-- room in the crafting bag (a free slot for a reagent, a stack) or the keyring
ui.reagent, ui.reagentFree = true, 1
click()
ui.reagent, ui.reagentFree, ui.reagentStack = nil, nil, { itemID = 77, stackCount = 3 }
click()
ui.reagentStack, ui.itemFamily, ui.keyFree = nil, 256, 1
click()
ui.itemFamily, ui.keyFree = nil, nil
-- a bag whose junk the player keeps
ui.keepBackpack = true
click()
ui.keepBackpack = nil
assert(#pickups == 0, "nothing to take, room elsewhere, or a kept bag: nothing is deleted")
-- below the threshold the master looter loots like anyone
ui.master = true
free, family = 1, 8  -- a free slot for another item family does not fit this one
click()
ui.master = nil
assert(#pickups == 1 and pickups[1] == 2 and deletions[1] == 12)
assert(messages[1]:find("Dry Bone", 1, true), "report the deleted cheapest stack")
click(0.5)
assert(#pickups == 1, "the same loot clicked again before the server answered")
-- a piece of an equipment set is kept, and so is the special bag's grey
ui.setSlot = 1
click()
assert(#pickups == 1)
ui.setSlot = nil
-- refused by the game: the item goes back and nothing is said
local delete = env.DeleteCursorItem
env.DeleteCursorItem = function() end
click()
assert(#pickups == 2 and not ui.cursor and #messages == 1)
env.DeleteCursorItem = delete
pickups[2], ui.cleared = nil, nil
ui.wrongPickup = true
click()
assert(pickups[2] == 1 and #deletions == 1 and ui.cleared and not ui.cursor, "wrong cursor item is cleared without deletion")
ui.wrongPickup = false
items[4].isLocked, items[4].isBound = false, true
click()
assert(pickups[3] == 1, "a bound grey worth nothing is a keepsake: the boot goes instead")
pickups[3], deletions[2] = nil, nil
items[4].isBound = nil
click()
assert(pickups[3] == 4 and deletions[2] == 14)
profile.deleteJunkWhenFull = false
click()
assert(#pickups == 3)
print("PASS: junk deletion only frees an eligible cheapest stack when loot cannot fit")
