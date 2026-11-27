-- Run from the repository root: luajit tools/tests/loot-window-growth.lua
-- Growth: Down hangs the window from the Edit Mode spot's top edge, Up stands it on the bottom edge.
-- A header drag saves the spot by that edge; Loot Under Mouse mirrors Blizzard's cursor spot for Up;
-- changing the option re-places an open window.
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
function Stub:SetScript(name, fn) local s = rawget(self, "scripts") or {}; self.scripts = s; s[name] = fn end
function Stub:GetScript(name) local s = rawget(self, "scripts"); return s and s[name] end
function Stub:GetEffectiveScale() return 1 end
function Stub:GetHeight() return 800 end
function Stub:GetWidth() return 1000 end
function Stub:GetFrameLevel() return 1 end
function Stub:CreateTexture() return setmetatable({}, Stub) end
function Stub:CreateFontString() return setmetatable({}, Stub) end

local tweaks = {}
local ns = {
    L = setmetatable({}, { __index = function(_, k) return k end }),
    modules = {},
    db = { profile = { tweaks = tweaks } },
    BORDER_COLOR = { r = 1, g = 1, b = 1, a = 1 },
    SetFontFamily = function() end, SetFont = function() end, ApplyShadow = function() end,
    GetFontPath = function() return 'font' end, BorderEdgeSize = function() return 8 end,
    GLOBAL_FONT = 'font',
    IsGamepadUI = function() return false end, IsMasterLooter = function() return false end,
    LogError = function(_, err) error(err) end,
    EditSection = function() return {} end,
    LayoutHome = function(t, name) t[name] = t[name] or {}; return t[name] end,
}
local lib = setmetatable({
    Fetch = function() return 'path' end,
    IsValid = function() return true end,
    SettingType = {},
}, { __index = function() return function() end end })
local underMouse, cursorX, cursorY = false, 500, 300
local env = setmetatable({
    CreateFrame = function(_, name)
        local f = setmetatable({ name = name }, Stub)
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
    GetCVarBool = function(name) return name == 'lootUnderMouse' and underMouse end,
    GetCursorPosition = function() return cursorX, cursorY end,
    StaticPopup_Hide = function() end,
    CloseLoot = function() end,
    C_Timer = { After = function() end },
    Enum = { LootSlotType = { None = 0, Item = ITEM, Money = 2, Currency = 3 } },
    GetNumLootItems = function() return 1 end,
    GetLootSlotType = function() return ITEM end,
    GetLootSlotInfo = function() return 't1', 'Item 1', 1, nil, 1 end,
    GetLootSlotLink = function() return 'link:1' end,
}, { __index = _G })
setfenv(assert(loadfile('Modules/LootWindow.lua')), env)('FlareUI', ns)

local LW = ns.LootWindow
LW:Init()
local win = LW.frame
local holder, events
for _, f in ipairs(frames) do
    if f.name == 'FlareUI_LootWindowHolder' then holder = f end
    if f:GetScript('OnEvent') then events = f end
end
assert(holder and events, 'holder and event frame')
local function fire(event, a, b) events:GetScript('OnEvent')(events, event, a, b) end
-- the window's point and the holder's point it is tied to
local function anchor() return table.concat({ tostring(win.points[1][1]), tostring(win.points[1][3]) }, ' '), win.points[1] end

-- Down (the default): the top left at the holder's top left
fire('LOOT_OPENED', false, false)
assert(win:IsShown(), 'shown')
local spot, p = anchor()
assert(#win.points == 1 and spot == 'TOPLEFT TOPLEFT' and p[2] == holder, 'Down: ' .. spot)

-- Up, changed while open: re-placed on the holder's bottom left
tweaks.lootWindowGrowth = 'up'
LW:Replace()
spot, p = anchor()
assert(#win.points == 1 and spot == 'BOTTOMLEFT BOTTOMLEFT' and p[2] == holder, 'Up: ' .. spot)
-- a new loot opens there too
fire('LOOT_OPENED', false, false)
spot = anchor()
assert(spot == 'BOTTOMLEFT BOTTOMLEFT', 'Up on open: ' .. spot)

-- a header drag saves the spot by the window's growing edge. HOLDER_H = 34 + 48 + 8 = 90; the spot's
-- point is RIGHT (the default, 11-27) on a 1000 x 800 screen, so x = holder right (100 + 260) - 1000 and
-- y = holder top - 45 - 400.
win.GetLeft = function() return 100 end
win.GetTop = function() return 600 end
win.GetBottom = function() return 400 end
local function drag() win.grip:GetScript('OnDragStop')(win.grip) end
local function saved() local s = tweaks.moverLayouts.Modern.lootWindow; return s.point .. ' ' .. s.x .. ' ' .. s.y end
drag()
assert(saved() == 'RIGHT -640 45', 'Up: the holder takes the bottom edge (400 + 90): ' .. saved())
spot = anchor()
assert(spot == 'BOTTOMLEFT BOTTOMLEFT', 'Up after the drag: ' .. spot)
tweaks.lootWindowGrowth = 'down'
drag()
assert(saved() == 'RIGHT -640 155', 'Down: the holder takes the top edge (600): ' .. saved())
spot = anchor()
assert(spot == 'TOPLEFT TOPLEFT', 'Down after the drag: ' .. spot)

-- Loot Under Mouse: Blizzard's spot for Down (top 50 above the cursor, at least 350 up), its mirror
-- for Up (bottom 50 below the cursor, at least 350 under the screen's top)
underMouse = true
local function at() local q = win.points[1]; return table.concat({ q[1], tostring(q[2] == env.UIParent), q[3], q[4], q[5] }, ' ') end
fire('LOOT_OPENED', false, false)
assert(at() == 'TOPLEFT true BOTTOMLEFT 470 350', 'Down at the cursor: ' .. at())
tweaks.lootWindowGrowth = 'up'
fire('LOOT_OPENED', false, false)
assert(at() == 'BOTTOMLEFT true BOTTOMLEFT 470 250', 'Up at the cursor: ' .. at())
cursorY = 780
fire('LOOT_OPENED', false, false)
assert(at() == 'BOTTOMLEFT true BOTTOMLEFT 470 450', 'Up near the top keeps room to grow: ' .. at())
-- a drag only moves it for this loot, held by its bottom edge; nothing saved
drag()
assert(at() == 'BOTTOMLEFT true BOTTOMLEFT 100 400', 'Up drag at the cursor: ' .. at())
assert(saved() == 'RIGHT -640 155', 'nothing saved at the cursor')
-- switching to Down keeps it where it is, now by its top edge
tweaks.lootWindowGrowth = 'down'
LW:Replace()
assert(at() == 'TOPLEFT true BOTTOMLEFT 100 600', 'Down at the cursor, re-pinned: ' .. at())

-- Up at 150% scale: the window's edges are in its own scaled units (k = 1.5), the holder is 90 * 1.5
-- tall, so its top is 400 * 1.5 + 135 = 735 and y = 735 - 67.5 - 400, saved rounded
underMouse = false
tweaks.lootWindowGrowth = 'up'
tweaks.lootWindowScale = 1.5
win.GetEffectiveScale = function() return 1.5 end
drag()
-- (x from the right edge: left 150 + width 260 * 1.5 = 540, so 540 - 1000)
assert(saved() == 'RIGHT -460 268', 'Up at 150%: ' .. saved())

print('PASS: loot window growth')
