-- Run from the repository root: luajit tools/tests/loot-window-settings.lua
-- The loot window's panel rows (11-23, slimmed): Loot Window and Show Free Bag Slots on the Looting
-- tab, no tab or preview of its own, no look options; the loot roll window has no Background Opacity;
-- the Item Level font row follows the bags' Item Level.
local L = setmetatable({}, { __index = function(_, k) return k end })

-- Settings/Pages/BagsLooting.lua against a settings stub that keeps the row definitions
local paths, rows, fonts, module = {}, {}, {}, nil
local S = {
    BorderChoices = {},
    Module = function(_, def) module = def end,
    OpacityChoices = function() return {} end,
    Row = function(_, def) rows[def.key] = def end,
    FontRows = function(_, def) for _, f in ipairs(def.fonts) do fonts[f.key] = f end end,
    GetPath = function(_, path) return paths[path] end,
    SetPath = function(_, path, v) paths[path] = v end,
}
local ns = { L = L, Settings = S }
setfenv(assert(loadfile('Settings/Pages/BagsLooting.lua')), setmetatable({}, { __index = _G }))('FlareUI', ns)

-- the Item Level font row: shown while the bags' Item Level is on
local itemLevel = assert(fonts.itemLevel, 'itemLevel font row')
paths['tweaks.bagItemLevel'] = true
assert(itemLevel.hidden() == false, 'shown with Item Level on')
paths['tweaks.bagItemLevel'] = false
assert(itemLevel.hidden() == true, 'hidden with Item Level off')

-- four tabs, no side panel
local tabKeys = {}
for i, tab in ipairs(module.tabs) do tabKeys[i] = tab.key end
assert(table.concat(tabKeys, ',') == 'bags,looting,bank,fonts', 'tabs: ' .. table.concat(tabKeys, ','))
assert(module.sidePanel == nil, 'no side panel')

-- the loot window's two rows, a half pair on Looting; Show Free Bag Slots greys with the window off
local lw, free = assert(rows['bl.lootWindow']), assert(rows['bl.lootWindowFreeSlots'])
assert(lw.tab == 'looting' and free.tab == 'looting', 'on Looting')
assert(lw.half and free.half, 'a half pair')
paths['tweaks.lootWindow'] = false
assert(free.disabled() == true, 'greyed with the window off')
paths['tweaks.lootWindow'] = true
assert(free.disabled() == false, 'live with the window on')
local others = {}
for key in pairs(rows) do
    if key:find('^bl%.lootWindow') and key ~= 'bl.lootWindow' and key ~= 'bl.lootWindowFreeSlots' then others[#others + 1] = key end
end
assert(#others == 0, 'no other loot window rows: ' .. table.concat(others, ', '))
assert(rows['bl.lootRollsOpacity'] == nil, 'no loot roll Background Opacity')
assert(fonts.lootWindow == nil, 'the loot window takes the loot roll font')

-- Settings/Copy.lua
local copyNs = { L = L }
setfenv(assert(loadfile('Settings/Copy.lua')), setmetatable({}, { __index = _G }))('FlareUI', copyNs)
local copy = assert(copyNs.Copy and copyNs.Copy.rows, 'copy rows')
assert(copy['bl.lootWindowFreeSlots'] and copy['bl.lootWindowFreeSlots'].label == 'Show Free Bag Slots',
    'free slots label: ' .. tostring(copy['bl.lootWindowFreeSlots'] and copy['bl.lootWindowFreeSlots'].label))
assert(copy['bl.lootRollsOpacity'] == nil, 'no opacity copy')

print('PASS: loot window settings')
