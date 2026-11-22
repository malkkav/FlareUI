-- Run from the repository root: luajit tools/tests/loot-window-random.lua
-- LW.RandomLoot: the settings' Live Preview sample rows (New Loot), in LW.ReadSlots' shape.
local ITEM, MONEY = 1, 2

local Stub = {}
Stub.__index = function(_, key)
    if Stub[key] then return Stub[key] end
    if key:match("^%u") then return function() end end
end

local ns = {
    L = setmetatable({}, { __index = function(_, k) return k end }),
    modules = {},
    db = { profile = { tweaks = {} } },
}
local env = setmetatable({
    CreateFrame = function() return setmetatable({}, Stub) end,
    UIParent = setmetatable({}, Stub),
    LibStub = function() return { Fetch = function() return 'path' end, IsValid = function() return true end } end,
    C_Item = { GetItemIconByID = function(id) return id ~= 3169 and 1000 + id or nil end },
    Enum = { LootSlotType = { None = 0, Item = ITEM, Money = MONEY, Currency = 3 } },
}, { __index = _G })
setfenv(assert(loadfile('Modules/LootWindow.lua')), env)('FlareUI', ns)
local LW = ns.LootWindow

local function lowest(m, n) return n and m or 1 end
local function highest(m, n) return n or m end

local function check(rows, label)
    local items, seen = 0, {}
    for i, r in ipairs(rows) do
        assert(r.slot == i, label .. ': slots in order')
        assert(type(r.name) == 'string' and r.texture ~= nil, label .. ': name and icon')
        assert(r.link == nil, label .. ': no link')
        if r.type == MONEY then
            assert(i == 1, label .. ': money leads, once')
        else
            assert(r.type == ITEM, label .. ': item row')
            items = items + 1
            assert(not seen[r.name], label .. ': each sample once, got ' .. r.name .. ' twice')
            seen[r.name] = true
            assert(type(r.quality) == 'number' and r.quality >= 0 and r.quality <= 4, label .. ': quality 0-4')
            if r.ilvl then
                assert(r.quantity == 1, label .. ': gear comes one at a time, got ' .. tostring(r.quantity))
            else
                assert(r.quantity >= 1 and r.quantity <= 20, label .. ': stack of 1-20, got ' .. tostring(r.quantity))
            end
        end
    end
    assert(items >= 2 and items <= 6, label .. ': 2-6 items, got ' .. items)
    return items, rows[1] and rows[1].type == MONEY
end

local low = LW.RandomLoot(lowest)
local items, money = check(low, 'lowest')
assert(items == 2 and money, 'lowest rolls: money and 2 items')
local high = LW.RandomLoot(highest)
items, money = check(high, 'highest')
assert(items == 6 and not money, 'highest rolls: no money, 6 items')

-- seeded rolls: every shape stays valid, and the mix covers what the window can show
math.randomseed(1234)
local saw = { money = false, noMoney = false, gear = false, stackBig = false, q = {}, marks = {} }
for n = 1, 500 do
    local rows = LW.RandomLoot(math.random)
    local _, m = check(rows, 'seeded ' .. n)
    if m then saw.money = true else saw.noMoney = true end
    for _, r in ipairs(rows) do
        if r.type == ITEM then
            saw.q[r.quality] = true
            if r.ilvl then saw.gear = true end
            if not r.ilvl and r.quantity > 1 then saw.stackBig = true end
            for _, mark in ipairs({ 'boe', 'junk', 'uncollected', 'owned' }) do
                if r[mark] then saw.marks[mark] = true end
            end
        end
    end
end
assert(saw.money and saw.noMoney, 'money row is optional')
assert(saw.gear and saw.stackBig, 'gear and stacks')
for q = 0, 4 do assert(saw.q[q], 'quality ' .. q .. ' rolled') end
for _, mark in ipairs({ 'boe', 'junk', 'uncollected', 'owned' }) do assert(saw.marks[mark], mark .. ' rolled') end
check(LW.RandomLoot(), 'default rand')

-- icons: the item's own by ID, else the sample's file, else a question mark
local byName = {}
for _, r in ipairs(high) do byName[r.name] = r end
for _, r in ipairs(low) do byName[r.name] = r end
assert(byName['Bear Meat'].texture == 1000 + 3173, 'icon by item ID')
assert(byName['Barbaric Battle Axe of the Gorilla'].texture == 'Interface\\Icons\\INV_Axe_09', 'icon file without an ID')

print('PASS: loot window random loot')
