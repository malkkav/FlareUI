-- Run from the repository root: luajit tools/tests/junkdelete-slot.lua
local function noop() end

local pickups, deletes, cursorItem = 0, 0, nil
local slotType = 1
local tweaks = { deleteJunkWhenFull = true }

local env = setmetatable({
    CreateFrame = function() return { RegisterEvent = noop, SetScript = noop, UnregisterAllEvents = noop } end,
    print = noop,
    InCombatLockdown = function() return false end,
    IsModifiedClick = function() return false end,
    GetCursorInfo = function()
        if cursorItem then return 'item', cursorItem end
        return false
    end,
    CursorHasItem = function() return cursorItem ~= nil end,
    ClearCursor = function() cursorItem = nil end,
    DeleteCursorItem = function() deletes = deletes + 1; cursorItem = nil end,
    GetLootSlotType = function() return slotType end,
    GetLootSlotLink = function() return 'item:100' end,
    Enum = { LootSlotType = { Item = 1, Money = 2 }, ItemQuality = { Poor = 0 } },
    C_Item = {
        GetItemInfoInstant = function() return 100 end,
        GetItemMaxStackSizeByID = function() return 1 end,
    },
    C_Container = {
        GetContainerNumFreeSlots = function() return 0, 0 end,
        GetContainerNumSlots = function(bag) return bag == 0 and 1 or 0 end,
        GetContainerItemInfo = function()
            return { quality = 0, itemID = 200, hasNoValue = true, stackCount = 1, hyperlink = 'item:200' }
        end,
        GetContainerItemQuestInfo = function() return nil end,
        PickupContainerItem = function() pickups = pickups + 1; cursorItem = 200 end,
    },
}, { __index = _G })

local ns = { L = setmetatable({}, { __index = function(_, k) return k end }), db = { profile = { tweaks = tweaks } } }
setfenv(assert(loadfile('Modules/JunkDelete.lua')), env)('FlareUI', ns)

local function reset() pickups, deletes, cursorItem = 0, 0, nil end

assert(type(ns.JunkDelete.BeforeLootSlot) == 'function', 'BeforeLootSlot must be exported')

reset()
ns.JunkDelete.BeforeLootSlot(1)
assert(pickups == 1, 'a full bag must pick up the junk stack, got ' .. pickups)
assert(deletes == 1, 'a full bag must delete the junk stack, got ' .. deletes)

reset()
tweaks.deleteJunkWhenFull = false
ns.JunkDelete.BeforeLootSlot(1)
assert(deletes == 0, 'the option off must delete nothing')
tweaks.deleteJunkWhenFull = true

reset()
slotType = 2
ns.JunkDelete.BeforeLootSlot(1)
assert(deletes == 0, 'a money slot must delete nothing')

print('PASS: junk delete by slot')
