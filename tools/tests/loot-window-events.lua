-- Run from the repository root: luajit tools/tests/loot-window-events.lua
-- The window's loot events: an auto loot opens the window at once (as Blizzard's) and LOOT_CLOSED
-- hides it without closing the loot again, and Owned Count follows BAG_UPDATE_DELAYED
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
env_master = false   -- (global: read by ns.IsMasterLooter below)
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
    IsMasterLooter = function() return env_master end,
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
-- (Malkkav 11-27) the close button: a header icon button 16 px from the right edge, not Blizzard's red one
local closePoint = win.close.points[1]
assert(closePoint[1] == "CENTER" and closePoint[3] == "TOPRIGHT" and closePoint[4] == -16 and closePoint[5] == -15)
assert(win.close.icon, "a bronze cross, as the chat's header buttons")
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

-- auto loot: the window opens at once, as Blizzard's does (11-23), and the loot isn't closed by us
slots = { item(1, 'link:1'), item(2, 'link:2') }
fire('LOOT_OPENED', true, false)
assert(LW.looting and win:IsShown(), 'auto loot: the window shows right away')
runTimers()
assert(closes == 0, 'auto loot: no CloseLoot from the window, got ' .. closes)
assert(#errors == 0, 'no show error: ' .. tostring(errors[1]))
-- the game takes the items, then closes the loot: the window goes with it, without closing it again
fire('LOOT_SLOT_CLEARED', 1)
fire('LOOT_SLOT_CLEARED', 2)
fire('LOOT_CLOSED')
assert(LW.looting == nil, 'LOOT_CLOSED clears looting')
assert(not win:IsShown(), 'LOOT_CLOSED hides the window')
assert(closes == 0, 'LOOT_CLOSED does not close the loot again, got ' .. closes)

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

fire('LOOT_CLOSED')
runTimers()

-- (11-24) the Master Looter's loot goes to Blizzard's window, which has the assign menu: never in the middle
-- of a loot
local blizzard = {}
env.LootFrame.RegisterEvent = function(_, event) blizzard[event] = true end
env.LootFrame.UnregisterEvent = function(_, event) blizzard[event] = nil end
slots = { item(1, 'link:1') }
fire('LOOT_OPENED', false, false)
env_master = true
fire('PARTY_LOOT_METHOD_CHANGED')
assert(not blizzard.LOOT_OPENED and win:IsShown(), 'the open loot stays')
fire('LOOT_CLOSED')
runTimers()
assert(blizzard.LOOT_OPENED and blizzard.LOOT_CLOSED)
fire('LOOT_OPENED', false, false)
assert(not win:IsShown(), "Blizzard's window has it")
fire('LOOT_CLOSED')
runTimers()
env_master = false
fire('GROUP_ROSTER_UPDATE')
assert(not blizzard.LOOT_OPENED)
fire('LOOT_OPENED', false, false)
assert(win:IsShown())

-- (Malkkav 11-26) Edit Mode: Blizzard's Loot Window checkbox shows FlareUI's box, and Blizzard's own box
-- is see-through and can't be clicked while ours is on
do
    local ticked, underMouse = true, false
    env._G = env   -- (the module reads _G.EditModeManagerFrame and _G.LootFrame)
    env.EditModeManagerFrame = { AccountSettings = { settingsCheckButtons = {
        LootFrame = { IsControlChecked = function() return ticked end } } } }
    env.GetCVarBool = function(name) return name == "lootUnderMouse" and underMouse end
    assert(LW.EditShown(), "ticked: ours shows")
    ticked = false
    assert(not LW.EditShown(), "unticked: ours hides")
    ticked, underMouse = true, true
    assert(not LW.EditShown(), "Loot Under Mouse: nothing to place")
    underMouse = false
    local alpha, mouse
    env.LootFrame.SetAlpha = function(_, a) alpha = a end
    env.LootFrame.Selection = { EnableMouse = function(_, on) mouse = on end }
    LW.HideBlizzardBox(true)
    assert(alpha == 0 and mouse == false)
    LW.HideBlizzardBox(false)
    assert(alpha == 1 and mouse == true)
    env.GetCVarBool = function() return false end
    env._G = nil
end

-- (Malkkav 11-27) Edit Mode: the window with sample loot under its box, never looting a click; gone after
do
    local looted = 0
    env.LootSlot = function() looted = looted + 1 end
    env.IsModifiedClick = function() return false end
    function Stub:EnableMouse(on) self.mouse = on end
    win:Hide()
    LW.looting = nil
    LW.EditPreview(true)
    assert(win.mouse == false and win.grip.mouse == false and win.close.mouse == false, "it only follows the box: no drag, no clicks")
    -- (11-27) the Edit Mode box drawn over the whole preview: from the box down to the window's bottom
    local selection = setmetatable({}, Stub)
    lib.frameSelections = { [win.holder] = selection }
    LW.FitBox(true)
    local last = selection.points[#selection.points]
    assert(last[1] == "BOTTOMRIGHT" and last[2] == win, "the box reaches the preview's far edge")
    lib.frameSelections = nil
    assert(win:IsShown() and LW.previewing, "the sample loot shows")
    local p = win.points and win.points[#win.points]
    assert(p and p[1] == "TOPLEFT" and type(p[2]) == "table" and p[2] ~= env.UIParent and p[3] == "TOPLEFT", "hung from the Edit Mode box, not left in the middle")
    local sampleRow
    for _, f in ipairs(frames) do if rawget(f, "data") and f.data.sample then sampleRow = f break end end
    assert(sampleRow, "rows drawn from the samples")
    sampleRow:GetScript("OnClick")(sampleRow)
    assert(looted == 0, "a sample row loots nothing")
    LW.EditPreview(false)
    assert(not win:IsShown() and not LW.previewing, "gone with Edit Mode")
    assert(win.mouse == true and win.grip.mouse == true, "clicks back for a real loot")
    Stub.EnableMouse = nil
end

print('PASS: loot window events')
