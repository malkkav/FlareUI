-- Run from the repository root: luajit tools/tests/loot-window-footer.lua
-- The footer holds only Free Bag Slots: it takes its height, and so room from the rows, only while
-- tweaks.lootWindowFreeSlots is on.
local ITEM = 1
local TOP, PAD, FOOT, MORE, ROW_H, ROW_GAP = 30, 8, 26, 15, 48, 4

local frames = {}
local Stub = {}
Stub.__index = function(_, key)
    if Stub[key] then return Stub[key] end
    if key:match("^%u") then return function() end end
end
function Stub:Show() self.shown = true end
function Stub:Hide() self.shown = false end
function Stub:IsShown() return self.shown == true end
function Stub:SetShown(shown) self.shown = shown and true or false end
function Stub:SetPoint(...) local p = rawget(self, "points") or {}; self.points = p; p[#p + 1] = { ... } end
function Stub:SetHeight(h) self.height = h end
function Stub:SetText(t) self.text = t end
function Stub:SetScript(name, fn) local s = rawget(self, "scripts") or {}; self.scripts = s; s[name] = fn end
function Stub:GetScript(name) local s = rawget(self, "scripts"); return s and s[name] end
function Stub:GetEffectiveScale() return 1 end
function Stub:GetHeight() return 1000 end
function Stub:GetFrameLevel() return 1 end
function Stub:CreateTexture() return setmetatable({}, Stub) end
function Stub:CreateFontString() return setmetatable({}, Stub) end

local screenH = 1000
local UIParent = setmetatable({}, Stub)
function UIParent.GetHeight() return screenH end

local tweaks = { lootWindowFreeSlots = false }
local ns = {
    L = setmetatable({}, { __index = function(_, k) return k end }),
    modules = {},
    db = { profile = { tweaks = tweaks } },
    BORDER_COLOR = { r = 1, g = 1, b = 1, a = 1 },
    SetFontFamily = function() end, SetFont = function() end, ApplyShadow = function() end,
    GetFontPath = function() return 'font' end, BorderEdgeSize = function() return 8 end,
    GLOBAL_FONT = 'font',
}
local slots = {}
for i = 1, 4 do
    slots[i] = { type = ITEM, texture = 't' .. i, name = 'Item ' .. i, quantity = 1, quality = 1, link = 'link:' .. i }
end
local env = setmetatable({
    CreateFrame = function()
        local f = setmetatable({}, Stub)
        frames[#frames + 1] = f
        return f
    end,
    UIParent = UIParent,
    UISpecialFrames = {},
    tinsert = table.insert,
    CreateColor = function() return {} end,
    GameTooltip = { IsOwned = function() return false end, Hide = function() end },
    LibStub = function()
        return { Fetch = function() return 'path' end, IsValid = function() return true end }
    end,
    Enum = { LootSlotType = { None = 0, Item = ITEM, Money = 2, Currency = 3 } },
    GetNumLootItems = function() return #slots end,
    GetLootSlotType = function(i) return slots[i].type end,
    GetLootSlotInfo = function(i)
        local s = slots[i]
        return s.texture, s.name, s.quantity, nil, s.quality
    end,
    GetLootSlotLink = function(i) return slots[i].link end,
    C_Container = { GetContainerNumFreeSlots = function(bag) return bag == 0 and 5 or 0, 0 end },
}, { __index = _G })
setfenv(assert(loadfile('Modules/LootWindow.lua')), env)('FlareUI', ns)

local LW = ns.LootWindow

-- the slots of the shown rows, in pool order
local function shownSlots()
    local out = {}
    for _, f in ipairs(frames) do
        if f.data and f.shown then out[#out + 1] = f.data.slot end
    end
    return table.concat(out, ',')
end
local function footerShown()
    local footer = LW.frame and LW.frame.footer
    return footer and footer.count.shown or false
end
local function setFreeSlots(on)
    tweaks.lootWindowFreeSlots = on
    LW:Refresh()
end

-- plenty of room: the footer adds exactly its height, and only while on
LW:Show(LW.ReadSlots())
local rowsH = 4 * ROW_H + 3 * ROW_GAP
assert(shownSlots() == '1,2,3,4', 'all rows fit: ' .. shownSlots())
assert(LW.frame.height == TOP + rowsH + PAD, 'off: no footer height, got ' .. tostring(LW.frame.height))
assert(not footerShown(), 'off: no footer')

setFreeSlots(true)
assert(shownSlots() == '1,2,3,4', 'still all rows: ' .. shownSlots())
assert(LW.frame.height == TOP + rowsH + FOOT + PAD, 'on: footer height added, got ' .. tostring(LW.frame.height))
assert(footerShown() and LW.frame.footer.count.text == 5, 'on: footer shows the free slots')

setFreeSlots(false)
assert(LW.frame.height == TOP + rowsH + PAD, 'off again: footer height gone, got ' .. tostring(LW.frame.height))
assert(not footerShown(), 'off again: footer hidden')

-- a screen with room for exactly the four rows: the footer's height costs a row (which then scrolls)
screenH = TOP + rowsH + PAD
LW:Refresh()
assert(shownSlots() == '1,2,3,4', 'off: four rows fit the screen: ' .. shownSlots())
assert(LW.frame.height == screenH, 'off: window fills the screen, got ' .. tostring(LW.frame.height))
assert(not LW.frame.more.shown, 'off: nothing below')

setFreeSlots(true)
local threeH = 3 * ROW_H + 2 * ROW_GAP
assert(shownSlots() == '1,2,3', 'on: the footer leaves room for three rows: ' .. shownSlots())
assert(LW.frame.height == TOP + threeH + MORE + FOOT + PAD, 'on: three rows, more line and footer, got ' .. tostring(LW.frame.height))
assert(LW.frame.more.shown and LW.frame.more.text == '+1 more', 'on: the fourth row is below')

-- the mouse wheel reaches the row the footer pushed out
LW:Scroll(-1)
assert(shownSlots() == '2,3,4', 'on: scrolled to the last row: ' .. shownSlots())

setFreeSlots(false)
LW:Scroll(1)
LW:Scroll(-1)
assert(shownSlots() == '1,2,3,4', 'off: nothing to scroll: ' .. shownSlots())

print('PASS: loot window footer')
