-- Run from the repository root: luajit tools/tests/loot-window.lua

local LOOT_NONE, LOOT_ITEM, LOOT_MONEY, LOOT_CURRENCY = 0, 1, 2, 3

local slots = {}
local ilvls = {}

local ns = {
    L = {},
    modules = {},
    Bags = { ItemLevelOf = function(link) return ilvls[link] end },
}
local env = setmetatable({
    CreateFrame = function() error('no frames at load') end,
    LibStub = function()
        return {
            Fetch = function(_, _, name) return 'path:' .. name end,
            IsValid = function(_, _, name) return name == 'FlareUI Thick' or name == 'FlareUI Frames' end,
        }
    end,
    Enum = { LootSlotType = { None = LOOT_NONE, Item = LOOT_ITEM, Money = LOOT_MONEY, Currency = LOOT_CURRENCY } },
    GetNumLootItems = function() return #slots end,
    GetLootSlotType = function(i) return slots[i].type end,
    GetLootSlotInfo = function(i)
        local s = slots[i]
        return s.texture, s.name, s.quantity, s.currencyID, s.quality, s.locked, s.isQuestItem, s.questID, s.isActive
    end,
    GetLootSlotLink = function(i) return slots[i].link end,
    C_Item = {
        GetItemCount = function(link, includeBank)
            if link == 'link:broken' then error('bad link') end
            assert(includeBank == true, 'bank included')
            return link == 'link:owned' and 7 or 0
        end,
        GetItemInfo = function(link)
            if link == 'link:uncached' then return nil end
            if link == 'link:broken' then error('bad link') end
            local price = link == 'link:soulbound-grey' and 0 or 25
            return 'n', link, 0, 1, 1, 't', 's', 1, '', 0, price
        end,
    },
    BACKPACK_CONTAINER = 0,
    NUM_BAG_SLOTS = 4,
    C_Container = {
        -- bag 3 is a profession bag (family 8): its free slots don't count
        GetContainerNumFreeSlots = function(bag)
            local free = { [0] = 3, [1] = 2, [2] = 0, [3] = 9, [4] = 1 }
            return free[bag], bag == 3 and 8 or 0
        end,
    },
    CurrencyContainerUtil = {
        GetCurrencyContainerInfo = function(_, quantity, _, _, quality)
            return 'Container Name', 'container-texture', quantity, quality
        end,
    },
}, { __index = _G })
setfenv(assert(loadfile('Modules/LootWindow.lua')), env)('FlareUI', ns)

local LW = ns.LootWindow
assert(LW and ns.modules['LootWindow'] == LW, 'module registered')

local function order(rows)
    local out = {}
    for i, r in ipairs(rows) do out[i] = r.slot end
    return table.concat(out, ',')
end

-- ReadSlots: None slots skipped, currency values from the container info
slots = {
    { type = LOOT_ITEM, texture = 't1', name = 'Sword', quantity = 1, quality = 4, link = 'link:sword' },
    { type = LOOT_NONE },
    { type = LOOT_CURRENCY, texture = 't3', name = 'Raw', quantity = 7, currencyID = 99, quality = 1 },
}
ilvls['link:sword'] = 250
local read = LW.ReadSlots()
assert(#read == 2, 'two rows')
assert(read[1].slot == 1 and read[2].slot == 3, 'slots 1 and 3')
assert(read[1].ilvl == 250 and read[1].link == 'link:sword', 'item level and link')
assert(read[2].name == 'Container Name' and read[2].texture == 'container-texture', 'currency container info')
assert(read[2].quantity == 7, 'currency quantity')

-- junk coin: grey items with a sell value only, as on the bags
assert(LW.IsJunk({ type = LOOT_ITEM, quality = 0, link = 'link:grey' }) == true, 'grey with a price')
assert(LW.IsJunk({ type = LOOT_ITEM, quality = 0, link = 'link:soulbound-grey' }) == false, 'grey, no price')
assert(LW.IsJunk({ type = LOOT_ITEM, quality = 0, link = 'link:uncached' }) == false, 'not cached yet')
assert(LW.IsJunk({ type = LOOT_ITEM, quality = 0, link = 'link:broken' }) == false, 'GetItemInfo error')
assert(LW.IsJunk({ type = LOOT_ITEM, quality = 1, link = 'link:grey' }) == false, 'not grey')
assert(LW.IsJunk({ type = LOOT_MONEY, quality = 0 }) == false, 'money')

-- owned count: a grey suffix, always, only above 0
assert(LW.NameWithCount('Linen Cloth', 12) == 'Linen Cloth |cff999999(12)|r', 'suffix')
assert(LW.NameWithCount('Linen Cloth', 0) == 'Linen Cloth', 'no suffix at 0')
assert(LW.OwnedCount({ type = LOOT_ITEM, link = 'link:owned' }) == 7, 'owned count')
assert(LW.OwnedCount({ type = LOOT_ITEM, link = 'link:broken' }) == 0, 'GetItemCount error')
assert(LW.OwnedCount({ type = LOOT_MONEY }) == 0, 'money has no count')
assert(LW.OwnedCount({ type = LOOT_CURRENCY, link = 'link:owned' }) == 0, 'currency has no count')

-- rows that fit (48 px rows, 4 px gaps); rows that scroll leave 15 px for the "+N more" line
local ROW_H, ROW_GAP = 48, 4
local function fit(space, total)
    local n, scrolls = LW.FitRows(space, total)
    return n .. ' ' .. tostring(scrolls)
end
local fourH = 4 * ROW_H + 3 * ROW_GAP
assert(fit(fourH, 4) == '4 false', 'exactly fits')
assert(fit(fourH - 1, 4) == '3 true', 'a pixel short scrolls')
assert(fit(fourH, 3) == '3 false', 'fewer than fit')
assert(fit(fourH, 0) == '0 false', 'no rows')
assert(fit(fourH, 5) == '3 true', 'overflow gives a row to the more line')
assert(fit(10, 5) == '1 true', 'at least one row')

-- the scroll thumb: at the top first, at the bottom of the rows once scrolled to the end
local area = 3 * ROW_H + 2 * ROW_GAP
local top, h = LW.ScrollThumb(10, 3, 0, area)
assert(top == 0 and math.abs(h - area * 0.3) < 1e-9, 'thumb at the top')
top, h = LW.ScrollThumb(10, 3, 7, area)
assert(math.abs(top + h - area) < 1e-9, 'thumb at the bottom')

assert(LW.ShouldShowOnOpen(true) == false)
assert(LW.ShouldShowOnOpen(false) == true)

-- free bag slots: general bags only (0 + 3 + 2 + 0 + 1; the family-8 bag's 9 left out)
assert(LW.FreeBagSlots() == 6, 'sums the family-0 bags only')

-- drag: the holder offset that puts its top left at (left, top); box 100 x 50 on a 1000 x 800 screen
local function offsetOf(...) local x, y = LW.HolderOffset(...) return x, y end
local x, y = offsetOf('TOPLEFT', 30, 700, 100, 50, 1000, 800)
assert(x == 30 and y == -100, 'TOPLEFT')
x, y = offsetOf('LEFT', 30, 700, 100, 50, 1000, 800)
assert(x == 30 and y == 275, 'LEFT: box middle 675 less screen middle 400')
x, y = offsetOf('CENTER', 450, 425, 100, 50, 1000, 800)
assert(x == 0 and y == 0, 'CENTER')
x, y = offsetOf('BOTTOMRIGHT', 900, 50, 100, 50, 1000, 800)
assert(x == 0 and y == 0, 'BOTTOMRIGHT')

print('PASS: loot window logic')
