-- Run from the repository root: luajit tools/tests/loot-window-order.lua
-- Row Order: Top to Bottom puts the first row on top, Bottom to Top at the bottom with the next above
-- it. Looted rows stay gaps in both. For long loot the "+N more" line sits at the far end (under the
-- rows, or above them), the scroll thumb follows, and the wheel moves toward the rows it points at.
local ITEM = 1

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
function Stub:ClearAllPoints() self.points = {} end
function Stub:SetPoint(...) local p = rawget(self, "points") or {}; self.points = p; p[#p + 1] = { ... } end
function Stub:SetHeight(h) self.height = h end
function Stub:SetText(t) self.text = t end
function Stub:SetScript(name, fn) local s = rawget(self, "scripts") or {}; self.scripts = s; s[name] = fn end
function Stub:GetScript(name) local s = rawget(self, "scripts"); return s and s[name] end
function Stub:GetEffectiveScale() return 1 end
function Stub:GetFrameLevel() return 1 end
function Stub:CreateTexture() return setmetatable({}, Stub) end
function Stub:CreateFontString() return setmetatable({}, Stub) end

-- a screen with room for three rows and the "+N more" line: 34 + 3 * 48 + 2 * 4 + 15 + 8
local screen = 209
local tweaks = {}
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
local env = setmetatable({
    CreateFrame = function()
        local f = setmetatable({}, Stub)
        frames[#frames + 1] = f
        return f
    end,
    UIParent = setmetatable({ GetHeight = function() return screen end }, Stub),
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
}, { __index = _G })
setfenv(assert(loadfile('Modules/LootWindow.lua')), env)('FlareUI', ns)

local LW = ns.LootWindow
local function open(count)
    slots = {}
    for i = 1, count do
        slots[i] = { type = ITEM, texture = 't' .. i, name = 'Item ' .. i, quantity = 1, quality = 1, link = 'link:' .. i }
    end
    LW:Show(LW.ReadSlots())
end
local win
-- the shown slots from the top down ('-' a gap), each row's top
local function column()
    local list, tops = {}, {}
    for _, f in ipairs(frames) do
        if f.points and f.y and f ~= win then
            local i = #list + 1
            list[i] = { y = f.y, slot = f.shown and f.data and f.data.slot or '-', top = -f.points[#f.points][3] }
        end
    end
    table.sort(list, function(a, b) return a.y < b.y end)
    local out = {}
    for i, r in ipairs(list) do out[i] = tostring(r.slot); tops[i] = r.top end
    return table.concat(out, ' '), tops
end
local function wheel(delta) win:GetScript('OnMouseWheel')(win, delta) end
local function thumb() local q = win.thumb.points[1]; return -q[3], win.thumb.height end
local function more() return win.more.shown and win.more.text or nil end

-- Top to Bottom, short loot: as before
open(2)
win = LW.frame
local order, tops = column()
assert(order == '1 2' and tops[1] == 34 and tops[2] == 86, 'top, short: ' .. order)

-- Bottom to Top, short loot: the first row at the bottom, the window the same size
local height = win.height
tweaks.lootWindowOrder = 'bottom'
LW:Refresh()
order, tops = column()
assert(order == '2 1' and tops[1] == 34 and tops[2] == 86, 'bottom, short: ' .. order)
assert(win.height == height, 'same size')
assert(not win.thumb.shown and not more(), 'no scroll marks')

-- Top to Bottom, long loot: three of six rows, the "+3 more" line under them
tweaks.lootWindowOrder = nil
open(6)
order, tops = column()
assert(order == '1 2 3' and tops[1] == 34, 'top, long: ' .. order)
local top, h = thumb()
assert(top == 34 and h == 76, 'top: thumb at the top ' .. top .. ' ' .. h)
assert(more() == '+3 more' and win.more.points[1][1] == 'TOPLEFT' and win.more.points[1][3] == -(34 + 152 + 6), 'top: more under the rows')
-- wheel up at the start: nothing; wheel down: the next row
wheel(1)
assert(column() == '1 2 3', 'top: wheel up at the start stays')
wheel(-1)
assert(column() == '2 3 4', 'top: wheel down shows the rows below')
local longHeight = win.height

-- Bottom to Top, long loot: the first row at the bottom, under the "+N more" line
tweaks.lootWindowOrder = 'bottom'
open(6)
order, tops = column()
assert(order == '3 2 1', 'bottom, long: ' .. order)
assert(tops[1] == 49 and tops[3] == 49 + 104, 'rows under the more line: ' .. tops[1])
assert(win.height == longHeight, 'same size as Top to Bottom')
top, h = thumb()
assert(top == 49 + 76 and h == 76, 'bottom: thumb at the bottom ' .. top .. ' ' .. h)
local mp = win.more.points[1]
-- (hung by its top from the top of its band, 34 to 49, so a larger font grows down into the band, not
-- up into the header line)
assert(more() == '+3 more' and mp[1] == 'TOPLEFT' and #mp == 3 and mp[3] == -34, 'bottom: more above the rows')
-- wheel down at the start: nothing; wheel up: the rows above
wheel(-1)
assert(column() == '3 2 1', 'bottom: wheel down at the start stays')
wheel(1)
assert(column() == '4 3 2', 'bottom: wheel up shows the rows above: ' .. column())
top = thumb()
assert(math.abs(top - (49 + 152 * 2 / 6)) < 1e-9, 'bottom: the thumb moves up: ' .. top)
wheel(5)
assert(column() == '6 5 4' and not more(), 'bottom: scrolled to the end, nothing more')
top = thumb()
assert(top == 49, 'bottom: thumb at the top at the end')

-- a looted row stays a gap in its place
wheel(-5)
local _, before = column()
LW:RemoveSlot(2)
order, tops = column()
assert(order == '3 - 1', 'bottom: looted row is a gap: ' .. order)
assert(tops[1] == before[1] and tops[2] == before[2] and tops[3] == before[3], 'rows keep their places')
assert(win.height == longHeight, 'window keeps its size')
-- (a looted row further up doesn't count)
LW:RemoveSlot(5)
assert(more() == '+2 more', 'more counts the rows still to loot: ' .. tostring(more()))

print('PASS: loot window row order')
