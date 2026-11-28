-- Run from the repository root: luajit tools/tests/loot-window-gaps.lua
-- A looted row stays as an empty gap: the rows below keep their place and the window keeps its size.
local MONEY, ITEM = 2, 1

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
function Stub:SetScript(name, fn) local s = rawget(self, "scripts") or {}; self.scripts = s; s[name] = fn end
function Stub:GetScript(name) local s = rawget(self, "scripts"); return s and s[name] end
function Stub:GetEffectiveScale() return 1 end
function Stub:GetHeight() return 1000 end
function Stub:GetFrameLevel() return 1 end
function Stub:CreateTexture() return setmetatable({}, Stub) end
function Stub:CreateFontString() return setmetatable({}, Stub) end

local ns = {
    L = setmetatable({}, { __index = function(_, k) return k end }),
    modules = {},
    BORDER_COLOR = { r = 1, g = 1, b = 1, a = 1 },
    SetFontFamily = function() end, SetFont = function() end, ApplyShadow = function() end,
    GetFontPath = function() return 'font' end, BorderEdgeSize = function() return 8 end,
    GLOBAL_FONT = 'font',
}
local slots = {
    { type = MONEY, texture = 'coin', name = 'Money', quality = 0 },
    { type = ITEM, texture = 't2', name = 'Two', quantity = 1, quality = 1, link = 'link:2' },
    { type = ITEM, texture = 't3', name = 'Three', quantity = 1, quality = 1, link = 'link:3' },
    { type = ITEM, texture = 't4', name = 'Four', quantity = 1, quality = 1, link = 'link:4' },
}
local env = setmetatable({
    CreateFrame = function()
        local f = setmetatable({}, Stub)
        frames[#frames + 1] = f
        return f
    end,
    UIParent = setmetatable({}, Stub),
    UISpecialFrames = {},
    tinsert = table.insert,
    CreateColor = function() return {} end,
    GameTooltip = { IsOwned = function() return false end, Hide = function() end },
    LibStub = function()
        return { Fetch = function() return 'path' end, IsValid = function() return true end }
    end,
    Enum = { LootSlotType = { None = 0, Item = ITEM, Money = MONEY, Currency = 3 } },
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
LW:Show(LW.ReadSlots())

-- the pool row showing a slot, with its index and anchor
local function rowOf(slot)
    for _, f in ipairs(frames) do
        if f.data and f.data.slot == slot then
            return f, f.points[1][3]
        end
    end
end

local row2, y2 = rowOf(2)
local row3, y3 = rowOf(3)
local row4, y4 = rowOf(4)
assert(row2 and row3 and row4, 'rows shown')
local height = LW.frame.height

LW:RemoveSlot(3)
assert(row3.shown == false and row3.data == nil, 'looted row is an empty gap')
local after2, after4 = rowOf(2), rowOf(4)
assert(after2 == row2 and select(2, rowOf(2)) == y2, 'row 2 keeps its place')
assert(after4 == row4 and select(2, rowOf(4)) == y4, 'row 4 keeps its place')
assert(row2.shown and row4.shown, 'neighbours stay shown')
assert(y3 ~= y2 and y3 ~= y4, 'the gap has its own position')
assert(LW.frame.height == height, 'window keeps its size')

LW:UpdateSlot(3)
assert(row3.shown == false and row3.data == nil and rowOf(3) == nil, 'update does not bring the gap back')

print('PASS: loot window gaps')
