-- Run from the repository root: luajit tools/tests/loot-window-settings.lua
-- The loot window's panel rows: the Item Level font row follows either Item Level option, and the copy
-- names the opacity row Background Opacity. The loot window rows sit on their own
-- Loot Window tab (its font row stays on Fonts), labelled in the copy.
local L = setmetatable({}, { __index = function(_, k) return k end })

-- Settings/Pages/BagsLooting.lua against a settings stub that keeps the row definitions
local paths, rows, fonts, fontTabs, module = {}, {}, {}, {}, nil
local S = {
    BorderChoices = {},
    Module = function(_, def) module = def end,
    OpacityChoices = function() return {} end,
    Row = function(_, def) rows[def.key] = def end,
    FontRows = function(_, def) for _, f in ipairs(def.fonts) do fonts[f.key] = f; fontTabs[f.key] = def.tab end end,
    GetPath = function(_, path) return paths[path] end,
    SetPath = function(_, path, v) paths[path] = v end,
}
local ns = { L = L, Settings = S }
setfenv(assert(loadfile('Settings/Pages/BagsLooting.lua')), setmetatable({}, { __index = _G }))('FlareUI', ns)

local itemLevel = assert(fonts.itemLevel, 'itemLevel font row')
assert(type(itemLevel.hidden) == 'function', 'itemLevel font row has a hidden function')
for _, bags in ipairs({ false, true }) do
    for _, window in ipairs({ false, true }) do
        for _, windowLevel in ipairs({ false, true }) do
            paths['tweaks.bagItemLevel'] = bags
            paths['tweaks.lootWindow'] = window
            paths['tweaks.lootWindowItemLevel'] = windowLevel
            local want = not (bags or (window and windowLevel))
            local got = itemLevel.hidden()
            assert(got == want, ('hidden: bags %s, window %s, window item level %s: want %s, got %s'):format(
                tostring(bags), tostring(window), tostring(windowLevel), tostring(want), tostring(got)))
        end
    end
end
-- unset options count as off
paths = {}
assert(itemLevel.hidden() == true, 'hidden with nothing set')

assert(rows['bl.lootWindowOpacity'], 'opacity row on the page')

-- the Loot Window tab, after Looting; every loot window row on it, none left on Looting
local tabKeys = {}
for i, tab in ipairs(module.tabs) do tabKeys[i] = tab.key end
assert(table.concat(tabKeys, ',') == 'bags,looting,lootWindow,fonts', 'tabs: ' .. table.concat(tabKeys, ','))
for key, def in pairs(rows) do
    if key:find('^bl%.lootWindow') then
        assert(def.tab == 'lootWindow', key .. ' on the Loot Window tab, got ' .. tostring(def.tab))
    end
end
assert(rows['bl.lootRolls'].tab == 'looting' and rows['bl.fastLoot'].tab == 'looting', 'the rest stay on Looting')
assert(fonts.lootWindow and fontTabs.lootWindow == 'fonts', 'the loot window font row stays on Fonts')
-- its Live Preview only on that tab
assert(module.sidePanel and module.sidePanel.tab == 'lootWindow', 'side panel on the Loot Window tab')
assert(type(module.sidePanel.show) == 'function' and type(module.sidePanel.hover) == 'function', 'side panel show and hover')

-- Settings/Copy.lua
local copyNs = { L = L }
setfenv(assert(loadfile('Settings/Copy.lua')), setmetatable({}, { __index = _G }))('FlareUI', copyNs)
local copy = assert(copyNs.Copy and copyNs.Copy.rows, 'copy rows')
local opacity = assert(copy['bl.lootWindowOpacity'], 'opacity copy')
assert(opacity.label == 'Background Opacity', 'opacity label: ' .. tostring(opacity.label))
local blTabs = copyNs.Copy.modules and copyNs.Copy.modules.bl and copyNs.Copy.modules.bl.tabs
assert(blTabs and table.concat(blTabs, ',') == 'Bags,Looting,Loot Window,Fonts', 'tab labels: ' .. table.concat(blTabs or {}, ','))

print('PASS: loot window settings')
