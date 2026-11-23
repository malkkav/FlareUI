-- Run from the repository root: luajit tools/tests/loot-window-events.lua
-- The window's loot events: an auto loot with nothing left after the half-second check closes the
-- loot (as Blizzard's window does when it doesn't show), and Owned Count follows BAG_UPDATE_DELAYED
-- with the rows repainted in place.
local ITEM = 1

local frames = {}
local Stub = {}
Stub.__index = function(_, key)
    if Stub[key] then return Stub[key] end
    if key:match("^%u") then return function() end end
end
function Stub:Show() self.shown = true; self.shows = (rawget(self, "shows") or 0) + 1 end
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

local tweaks = {}
local errors = {}
local ns = {
    L = setmetatable({}, { __index = function(_, k) return k end }),
    modules = {},
    db = { profile = { tweaks = tweaks } },
    BORDER_COLOR = { r = 1, g = 1, b = 1, a = 1 },
    SetFontFamily = function() end, SetFont = function() end, ApplyShadow = function() end,
    GetFontPath = function() return 'font' end, BorderEdgeSize = function() return 8 end,
    GLOBAL_FONT = 'font',
    IsGamepadUI = function() return false end,
    LogError = function(_, err) errors[#errors + 1] = err end,
    EditSection = function() return {} end,
    LayoutHome = function(t, name) t[name] = t[name] or {}; return t[name] end,
}
local lib = setmetatable({
    Fetch = function() return 'path' end,
    IsValid = function() return true end,
    SettingType = {},
}, { __index = function() return function() end end })
local slots, counts, timers = {}, {}, {}
local closes = 0
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
    LibStub = function() return lib end,
    LootFrame = setmetatable({}, Stub),
    GetCVarBool = function() return false end,
    StaticPopup_Hide = function() end,
    CloseLoot = function() closes = closes + 1 end,
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
    C_Item = { GetItemCount = function(link) return counts[link] or 0 end },
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
LW:Init()
local win = LW.frame
local events
for _, f in ipairs(frames) do
    if f:GetScript('OnEvent') then events = f end
end
assert(events, 'event frame')
local function fire(event, a, b) events:GetScript('OnEvent')(events, event, a, b) end
local function runTimers()
    local due = timers
    timers = {}
    for _, fn in ipairs(due) do fn() end
end
local function item(i, link)
    return { type = ITEM, texture = 't' .. i, name = 'Item ' .. i, quantity = 1, quality = 1, link = link }
end

-- auto loot with nothing left half a second on: the loot closes and nothing shows
fire('LOOT_OPENED', true, false)
assert(LW.looting and not win:IsShown(), 'auto loot: window stays closed')
assert(closes == 0, 'auto loot: loot not closed before the check')
runTimers()
assert(closes == 1, 'empty auto loot: CloseLoot once, got ' .. closes)
assert(not win:IsShown() and not rawget(win, 'shows'), 'empty auto loot: the window never shows')
fire('LOOT_CLOSED')
assert(LW.looting == nil, 'LOOT_CLOSED clears looting')
assert(closes == 1, 'LOOT_CLOSED does not close the loot again, got ' .. closes)

-- auto loot with slots still left: what is left shows, the loot stays open
slots = { item(1, 'link:1'), item(2, 'link:2') }
fire('LOOT_OPENED', true, false)
runTimers()
assert(win:IsShown(), 'auto loot with slots left: the window shows')
assert(closes == 1, 'auto loot with slots left: no CloseLoot, got ' .. closes)
assert(#errors == 0, 'no show error: ' .. tostring(errors[1]))
fire('LOOT_CLOSED')
win:Hide()

-- Owned Count: two stacks of one item; looting the first raises the count the second shows
slots = { item(1, 'link:1'), item(2, 'link:x'), item(3, 'link:x') }
counts['link:x'] = 4
fire('LOOT_OPENED', false, false)
assert(win:IsShown(), 'manual loot shows')

local function rowOf(slot)
    for _, f in ipairs(frames) do
        if f.data and f.data.slot == slot then return f, f.points[1][3] end
    end
end
local row1, y1 = rowOf(1)
local row2 = rowOf(2)
local row3, y3 = rowOf(3)
assert(row3.name.text == 'Item 3 |cff999999(4)|r', 'owned count shown: ' .. tostring(row3.name.text))

fire('LOOT_SLOT_CLEARED', 2)
assert(row2.shown == false and row2.data == nil, 'looted row is a gap')
counts['link:x'] = 5
fire('BAG_UPDATE_DELAYED')
assert(row3.name.text == 'Item 3 |cff999999(5)|r', 'owned count follows the bags: ' .. tostring(row3.name.text))
assert(rowOf(1) == row1 and select(2, rowOf(1)) == y1, 'row 1 keeps its place')
assert(rowOf(3) == row3 and select(2, rowOf(3)) == y3, 'row 3 keeps its place')
assert(row2.shown == false and row2.data == nil and rowOf(2) == nil, 'the gap stays')

print('PASS: loot window events')
