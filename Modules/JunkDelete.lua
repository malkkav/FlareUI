local _, ns = ...
local L = ns.L

--------------------------------------------------
-- DELETE JUNK WHEN FULL (Quality of Life > Convenience, tweaks.deleteJunkWhenFull, off; 11-14, a player's
-- request after EnhanceQoL and EllesmereUI: the idea only, both are all rights reserved)
-- With the bags full, clicking an item in the loot window first deletes the grey item worth the least at a
-- vendor (its whole stack), so the click loots into the freed slot. The game takes an item delete from
-- addon code only inside a click, never from an event or a timer, so this runs in the loot button's
-- PreClick: before Blizzard's own OnClick loots. Never in a fight, never with something on the cursor,
-- never when the loot would stack or fit in a free special bag slot anyway. Shift-click is Blizzard's.
--------------------------------------------------
local JunkDelete = {}
ns.JunkDelete = JunkDelete

local BAGS = { 0, 1, 2, 3, 4 }   -- the backpack and the four bags (not the bank, not the keyring)

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
    local maxStack = C_Item.GetItemMaxStackSizeByID and C_Item.GetItemMaxStackSizeByID(itemID) or 1
    if (maxStack or 1) <= 1 then return false end
    for _, bag in ipairs(BAGS) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == itemID and (info.stackCount or 1) < maxStack then return true end
        end
    end
    return false
end

-- the grey stack worth least at a vendor (an item the game hasn't loaded yet is passed over)
local function CheapestJunk()
    local best, bestBag, bestSlot
    for _, bag in ipairs(BAGS) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.quality == Enum.ItemQuality.Poor and not info.isLocked and info.itemID then
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

-- in the loot button's click: makes room if the item needs it
local function BeforeLootClick(button)
    if not On() or InCombatLockdown() or GetCursorInfo() or IsModifiedClick() then return end
    local element = button:GetParent()
    local index = element and element.GetSlotIndex and element:GetSlotIndex()
    if not index or GetLootSlotType(index) ~= Enum.LootSlotType.Item then return end
    local link = GetLootSlotLink(index)
    local itemID = link and C_Item.GetItemInfoInstant(link)
    if HasRoomFor(itemID) then return end
    local junk, bag, slot = CheapestJunk()
    if not junk then return end
    C_Container.PickupContainerItem(bag, slot)
    local kind, cursorID = GetCursorInfo()
    if kind == "item" and cursorID == junk.itemID then
        DeleteCursorItem()
        print("|cff00ccffFlareUI:|r " .. L["Deleted %s to make room."]:format(junk.link or ""))
    elseif CursorHasItem() then
        ClearCursor()
    end
end

-- each loot button once, as the loot window's list makes it
local hooked = setmetatable({}, { __mode = "k" })
-- (the list's own callback passes its owner first; the walk over frames already made passes the frame)
local function OnAcquired(a, b)
    local frame = b ~= nil and b or a
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
