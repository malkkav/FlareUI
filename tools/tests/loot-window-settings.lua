-- Run from the repository root: luajit tools/tests/loot-window-settings.lua
-- The loot window's panel rows (11-23, slimmed): Loot Window, Show Free Bag Slots, Growth and Row Order
-- on the Looting tab, no tab or preview of its own, no look options; the loot roll window has no Background Opacity;
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

-- the Item Level font row: greyed (not hidden, 11-26) until the bags' Item Level is on
local itemLevel = assert(fonts.itemLevel, 'itemLevel font row')
assert(itemLevel.hidden == nil, 'never hidden')
paths['tweaks.bagItemLevel'] = true
assert(itemLevel.disabled() == false, 'live with Item Level on')
paths['tweaks.bagItemLevel'] = false
assert(itemLevel.disabled() == true, 'greyed with Item Level off')

-- four tabs, no side panel
local tabKeys = {}
for i, tab in ipairs(module.tabs) do tabKeys[i] = tab.key end
assert(table.concat(tabKeys, ',') == 'bags,looting,bank,fonts', 'tabs: ' .. table.concat(tabKeys, ','))
assert(module.sidePanel == nil, 'no side panel')

-- (11-26, M8) Loot Window: one choice, Off, Grow Down or Grow Up, over the switch and Growth; then Row
-- Order and Show Free Bag Slots, both greyed with the window off
local lw, free = assert(rows['bl.lootWindow']), assert(rows['bl.lootWindowFreeSlots'])
local order = assert(rows['bl.lootWindowOrder'], 'order row')
assert(lw.tab == 'looting' and free.tab == 'looting' and order.tab == 'looting', 'on Looting')
assert(lw.kind == 'choice' and table.concat(lw.choices, ',') == 'off,down,up', 'Loot Window choices')
assert(order.kind == 'choice' and table.concat(order.choices, ',') == 'top,bottom', 'order choices')
assert(rows['bl.lootWindowGrowth'] == nil, 'Growth joined Loot Window')
paths['tweaks.lootWindow'] = false
assert(lw.get() == 'off' and free.disabled() == true and order.disabled() == true, 'greyed with the window off')
lw.set('up')
assert(paths['tweaks.lootWindow'] == true and paths['tweaks.lootWindowGrowth'] == 'up' and lw.get() == 'up')
assert(free.disabled() == false and order.disabled() == false, 'live with the window on')
lw.set('off')
assert(paths['tweaks.lootWindow'] == false and paths['tweaks.lootWindowGrowth'] == 'up', 'Off keeps the growth for later')
paths['tweaks.lootWindow'] = true
local called = {}
ns.LootWindow = { Replace = function() called[#called + 1] = 'replace' end, Refresh = function() called[#called + 1] = 'refresh' end }
order.apply()
assert(table.concat(called, ',') == 'refresh', 'apply: ' .. table.concat(called, ','))
ns.LootWindow = nil
-- (their defaults: core-profile-lifecycle.lua, a real profile)

local others = {}
local known = { ['bl.lootWindow'] = true, ['bl.lootWindowFreeSlots'] = true, ['bl.lootWindowOrder'] = true }
for key in pairs(rows) do
    if key:find('^bl%.lootWindow') and not known[key] then others[#others + 1] = key end
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
local cw, co = assert(copy['bl.lootWindow'], 'window copy'), assert(copy['bl.lootWindowOrder'], 'order copy')
assert(table.concat(cw.choices, ',') == 'Off,Grow Down,Grow Up', 'window copy choices')
assert(co.label == 'Row Order' and table.concat(co.choices, ',') == 'Top to Bottom,Bottom to Top' and co.desc, 'order copy: ' .. tostring(co.label))
assert(cw.section == 'bl.lootWindowSection' and co.section == 'bl.lootWindowSection', 'in the Loot Window section')

print('PASS: loot window settings')
