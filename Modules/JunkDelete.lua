local _, ns = ...
local L = ns.L

--------------------------------------------------
-- DELETE JUNK WHEN FULL (Quality of Life > Convenience, tweaks.deleteJunkWhenFull, off)
-- With the bags full, clicking an item in the loot window first deletes the grey item worth the least at a
-- vendor (its whole stack), so the click loots into the freed slot. The game takes an item delete from
-- addon code only inside a click, never from an event or a timer, so this runs in the loot button's
-- PreClick: before Blizzard's own OnClick loots. Never in a fight, never with something on the cursor,
-- never when the loot would stack or fit in a free special bag slot anyway. Shift-click is Blizzard's.
--------------------------------------------------
local JunkDelete = {}
ns.JunkDelete = JunkDelete

local BAGS = { 0, 1, 2, 3, 4 }   -- the backpack and the four bags (not the bank, not the keyring)
local KEY_FAMILY = 256           -- items that go in the keyring
local CLICK_AGAIN = 1.5          -- seconds: the same loot clicked again before the server answered
local last = {}                  -- the loot the last delete was for: slot, link, when

local function On()
    local tweaks = ns.db and ns.db.profile and ns.db.profile.tweaks
    return tweaks and tweaks.enabled ~= false and tweaks.deleteJunkWhenFull and true or false
end

-- room for this item without deleting: a free general slot, a free slot in a special bag it goes in,
-- or a stack of it that isn't full
local function HasRoomFor(itemID)
    local family = itemID and C_Item.GetItemFamily and C_Item.GetItemFamily(itemID) or 0
    for _, bag in ipairs(BAGS) do
        local free, bagFamily = C_Container.GetContainerNumFreeSlots(bag)
        if free and free > 0 then
            if not bagFamily or bagFamily == 0 then return true end
            if family and bit.band(family, bagFamily) ~= 0 then return true end
        end
    end
    if not itemID then return false end
    -- (11-24) the crafting bag takes crafting reagents, the keyring takes keys
    local reagentBag = Enum.BagIndex and Enum.BagIndex.ReagentBag
    local keyring = Enum.BagIndex and Enum.BagIndex.Keyring
    if reagentBag and C_Container.GetContainerNumSlots(reagentBag) > 0
        and (C_Container.GetContainerNumFreeSlots(reagentBag) or 0) > 0 and select(17, C_Item.GetItemInfo(itemID)) then
        return true
    end
    if keyring and family and bit.band(family, KEY_FAMILY) ~= 0 and (C_Container.GetContainerNumFreeSlots(keyring) or 0) > 0 then
        return true
    end
    local maxStack = C_Item.GetItemMaxStackSizeByID and C_Item.GetItemMaxStackSizeByID(itemID) or 1
    if (maxStack or 1) <= 1 then return false end
    local function StackIn(bag)
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == itemID and (info.stackCount or 1) < maxStack then return true end
        end
    end
    for _, bag in ipairs(BAGS) do
        if StackIn(bag) then return true end
    end
    return (reagentBag and StackIn(reagentBag)) or false
end

-- (11-24) a bag whose greys stay: one set to Ignore Junk Selling in its own menu, or a special bag (the
-- slot freed there wouldn't take the loot)
local function BagKept(bag)
    local _, family = C_Container.GetContainerNumFreeSlots(bag)
    if family and family ~= 0 then return true end
    if bag == 0 then
        return C_Container.GetBackpackSellJunkDisabled and C_Container.GetBackpackSellJunkDisabled() or false
    end
    local flags = Enum.BagSlotFlags
    return flags and C_Container.GetBagSlotFlag and C_Container.GetBagSlotFlag(bag, flags.ExcludeJunkSell) or false
end

-- an item the player means to keep: a keepsake (bound, worth nothing at a vendor) or part of an equipment set
local function ItemKept(info, bag, slot)
    if info.isBound and info.hasNoValue then return true end
    return C_Container.GetContainerItemEquipmentSetInfo and C_Container.GetContainerItemEquipmentSetInfo(bag, slot) or false
end

-- a click on this loot slot takes nothing (yet): locked (still rolled for, not yours), or handed out by you
local function NothingToTake(index)
    local _, _, _, _, quality, locked = GetLootSlotInfo(index)
    if locked then return true end
    if not (ns.IsMasterLooter and ns.IsMasterLooter()) then return false end
    local threshold = GetLootThreshold and GetLootThreshold()
    return not (threshold and quality) or quality >= threshold
end

-- the grey stack worth least at a vendor (an item the game hasn't loaded yet is passed over)
local function CheapestJunk()
    local best, bestBag, bestSlot
    for _, bag in ipairs(BAGS) do
        for slot = 1, BagKept(bag) and 0 or C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.quality == Enum.ItemQuality.Poor and not info.isLocked and info.itemID
                and not ItemKept(info, bag, slot) then
                local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
                if not (quest and (quest.isQuestItem or quest.questID)) then
                    local price
                    if info.hasNoValue then
                        price = 0
                    else
                        local sell = select(11, C_Item.GetItemInfo(info.itemID))
                        if sell then price = sell * (info.stackCount or 1) end
                    end
                    if price and (not best or price < best.price) then
                        best = { price = price, itemID = info.itemID, link = info.hyperlink }
                        bestBag, bestSlot = bag, slot
                    end
                end
            end
        end
    end
    return best, bestBag, bestSlot
end

-- in a loot slot's click (Blizzard's loot button or FlareUI's loot window): makes room if the item needs it
function JunkDelete.BeforeLootSlot(index)
    if not On() or InCombatLockdown() or GetCursorInfo() or SpellIsTargeting() or IsModifiedClick() then return end
    if not index or GetLootSlotType(index) ~= Enum.LootSlotType.Item or NothingToTake(index) then return end
    local link = GetLootSlotLink(index)
    -- (the stack deleted a moment ago still fills its slot until the server answers)
    if last.slot == index and last.link == link and GetTime() - last.time < CLICK_AGAIN then return end
    local itemID = link and C_Item.GetItemInfoInstant(link)
    if HasRoomFor(itemID) then return end
    local junk, bag, slot = CheapestJunk()
    if not junk then return end
    C_Container.PickupContainerItem(bag, slot)
    local kind, cursorID = GetCursorInfo()
    if kind == "item" and cursorID == junk.itemID then
        DeleteCursorItem()
        -- refused (the click wasn't a real one): the item goes back
        if CursorHasItem() then ClearCursor() return end
        last.slot, last.link, last.time = index, link, GetTime()
        print("|cff00ccffFlareUI:|r " .. L["Deleted %s to make room."]:format(junk.link or ""))
    elseif CursorHasItem() then
        ClearCursor()
    end
end

local function BeforeLootClick(button)
    local element = button:GetParent()
    JunkDelete.BeforeLootSlot(element and element.GetSlotIndex and element:GetSlotIndex())
end

-- each loot button once, as the loot window's list makes it
local hooked = setmetatable({}, { __mode = "k" })
-- (the list's own callback passes its owner, then the frame; the walk over frames already made passes
-- the frame, then its element data: the frame is the one with an Item)
local function OnAcquired(a, b)
    local frame = (type(b) == "table" and b.Item) and b or a
    local item = type(frame) == "table" and frame.Item
    if not item or hooked[item] then return end
    hooked[item] = true
    item:HookScript("PreClick", BeforeLootClick)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    local box = _G.LootFrame and _G.LootFrame.ScrollBox
    if not (box and ScrollUtil and ScrollUtil.AddAcquiredFrameCallback) then return end
    ScrollUtil.AddAcquiredFrameCallback(box, OnAcquired, JunkDelete, true)
end)
