-- Run from the repository root: luajit tools/tests/loot-window-preview.lua
-- The Loot Window tab's Live Preview: R.lootWindow draws the rows it is given (else its fixed ones) in
-- every option; the side panel draws it on each show and hover, and New Loot rolls LW.RandomLoot rows;
-- Panel.lua shows a side panel with a tab only on that tab.
local ITEM, MONEY = 1, 2
local L = setmetatable({}, { __index = function(_, k) return k end })

local Stub = {}
Stub.__index = function(_, key)
    if Stub[key] then return Stub[key] end
    if key:match('^%u') then return function() end end
end
local areaW, areaH = 256, 312
function Stub:SetText(t) self.text = t end
function Stub:SetShown(s) self.shown = s and true or false end
function Stub:Show() self.shown = true end
function Stub:Hide() self.shown = false end
function Stub:IsShown() return self.shown ~= false end
function Stub:SetTexture(t) self.texture = t end
function Stub:SetAlpha(a) self.alpha = a end
function Stub:SetScale(k) self.scale = k end
function Stub:SetHeight(h) self.height = h end
function Stub:SetEnabled(e) self.enabled = e end
function Stub:GetWidth() return areaW end
function Stub:GetHeight() return areaH end
function Stub:GetFrameLevel() return 1 end
function Stub:CreateTexture() return setmetatable({}, Stub) end
function Stub:CreateFontString() return setmetatable({}, Stub) end
function Stub:GetFontString() return setmetatable({}, Stub) end
function Stub:SetScript(name, fn) local s = rawget(self, 'scripts') or {}; self.scripts = s; s[name] = fn end
function Stub:GetScript(name) local s = rawget(self, 'scripts'); return s and s[name] end

local paths = {}
local S = { GetPath = function(_, path) return paths[path] end }

--------------------------------------------------
-- R.lootWindow (Settings/PreviewSamples.lua)
--------------------------------------------------
local ns = { L = L, Settings = S, SettingsPreview = { renderers = {} }, modules = {},
    db = { profile = { tweaks = {} } }, BORDER_COLOR = { r = 1, g = 1, b = 1, a = 1 } }
local env = setmetatable({
    CreateFrame = function() return setmetatable({}, Stub) end,
    UIParent = setmetatable({}, Stub),
    LibStub = function() return { Fetch = function() return 'path' end, IsValid = function() return true end } end,
    C_Item = { GetItemIconByID = function(id) return 1000 + id end },
    C_Texture = { GetAtlasInfo = function() return nil end },
    CreateColor = function() return {} end,
    Enum = { LootSlotType = { None = 0, Item = ITEM, Money = MONEY, Currency = 3 } },
}, { __index = _G })
setfenv(assert(loadfile('Modules/LootWindow.lua')), env)('FlareUI', ns)
setfenv(assert(loadfile('Settings/PreviewSamples.lua')), env)('FlareUI', ns)
local Draw = assert(ns.SettingsPreview.renderers.lootWindow, 'R.lootWindow')

-- a canvas that keeps what is drawn, by id
local function Canvas()
    local c = { width = 256, height = 256, objects = {}, overlay = setmetatable({}, Stub) }
    local function Obj(id)
        local o = c.objects[id] or setmetatable({}, Stub)
        c.objects[id] = o
        o.shown = true
        return o
    end
    function c:Text(id, text) local o = Obj(id); o.text = text; return o end
    function c:Texture(id, path) local o = Obj(id); o.texture = path; return o end
    function c:Box(id) return Obj(id) end
    function c:Object(id) return Obj(id) end
    return c
end
local function Names(c)
    local out = {}
    for i = 1, 10 do
        local o = c.objects['lootWinName' .. i]
        if not o then break end
        out[i] = o.text
    end
    return table.concat(out, ' / ')
end

-- no rows given: the fixed ones, under the heading
local FIXED = '2 Silver 34 Copper / Barbaric Battle Axe of the Gorilla / Bear Meat / Large Bear Tooth'
local c = Canvas()
Draw(c, { kind = 'lootWindow', key = 'bl.lootWindowBorder' })
assert(Names(c) == FIXED, 'fixed rows: ' .. Names(c))
assert(c.objects.heading and c.objects.heading.shown, 'the heading')
assert(c.used == 30 + 30 + 4 * 41 + 3 * 3 + 8, 'below the heading, got ' .. tostring(c.used))
assert(c.objects.lootWinIcon3.texture == 1000 + 3173, 'Bear Meat by its item ID')

-- the footer takes the fixed money row's room on the column's canvas, not in the Live Preview (bare)
paths['tweaks.lootWindowFreeSlots'] = true
c = Canvas()
Draw(c, { kind = 'lootWindow', key = 'bl.lootWindowFreeSlots' })
assert(Names(c) == 'Barbaric Battle Axe of the Gorilla / Bear Meat / Large Bear Tooth', 'footer: ' .. Names(c))
assert(c.objects.lootWinFree.shown, 'footer shown')
c = Canvas()
Draw(c, { kind = 'lootWindow', key = 'bl.lootWindowPreview', bare = true })
assert(Names(c) == FIXED, 'bare footer keeps the fixed rows: ' .. Names(c))
assert(c.objects.heading == nil, 'bare: no heading')
assert(c.used == 30 + 4 * 41 + 3 * 3 + 26 + 8, 'bare: from the top, got ' .. tostring(c.used))

-- rows given: drawn in their order and options, the marks from the row data, the table untouched
local given = {
    { slot = 1, type = ITEM, name = 'Tooth', quality = 0, quantity = 4, junk = true, owned = 4, texture = 'tex:tooth' },
    { slot = 2, type = ITEM, name = 'Axe', quality = 2, quantity = 1, ilvl = 18, boe = true, uncollected = true, texture = 'tex:axe' },
    { slot = 3, type = MONEY, name = '5 Silver', texture = 'tex:coin' },
}
paths['tweaks.lootWindowSort'] = 'quality'
for _, k in ipairs({ 'Junk', 'BoE', 'Uncollected', 'Owned', 'ItemLevel' }) do paths['tweaks.lootWindow' .. k] = true end
c = Canvas()
Draw(c, { kind = 'lootWindow', key = 'bl.lootWindowPreview', bare = true, rows = given })
assert(Names(c) == '5 Silver / Axe / Tooth |cff999999(4)|r', 'given rows, sorted, owned count: ' .. Names(c))
assert(given[1].name == 'Tooth' and given[3].name == '5 Silver', 'the given table keeps its order')
assert(c.objects.lootWinFree.shown, 'footer with given rows')
local column = Canvas()
Draw(column, { kind = 'lootWindow', key = 'bl.lootWindowPreview', rows = given })
assert(Names(column) == '5 Silver / Axe / Tooth |cff999999(4)|r', 'given rows keep their money row: ' .. Names(column))
assert(c.objects.lootWinIcon1.texture == 'tex:coin' and c.objects.lootWinIcon2.texture == 'tex:axe', 'the rows\' own icons')
local axe, tooth = c.objects.lootWinMarks2, c.objects.lootWinMarks3
assert(axe.boe.shown and axe.eye.shown and not axe.junk.shown, 'BoE and uncollected from the row')
assert(axe.ilvl.shown and axe.ilvl.text == 18, 'item level from the row')
assert(tooth.junk.shown and not tooth.boe.shown and not tooth.eye.shown, 'junk coin from the row')
assert(tooth.count.shown and tooth.count.text == 4, 'stack count')
-- the options still rule
for _, k in ipairs({ 'Junk', 'BoE', 'Uncollected', 'Owned', 'ItemLevel', 'FreeSlots' }) do paths['tweaks.lootWindow' .. k] = false end
paths['tweaks.lootWindowSort'] = 'loot'
c = Canvas()
Draw(c, { kind = 'lootWindow', key = 'bl.lootWindowPreview', bare = true, rows = given })
assert(Names(c) == '5 Silver / Tooth / Axe', 'loot order, no count: ' .. Names(c))
assert(not c.objects.lootWinMarks2.junk.shown and not c.objects.lootWinMarks3.boe.shown, 'marks off')
assert(not c.objects.lootWinMarks3.ilvl.shown, 'item level off')
assert(c.objects.lootWinFree == nil, 'no footer')

-- the main switch's own picture while off
c = Canvas()
Draw(c, { kind = 'lootWindow', key = 'bl.lootWindow' })
assert(c.objects.lootWinOff and c.objects.lootWinOff.text == 'Disabled', 'Disabled while off')

--------------------------------------------------
-- THE SIDE PANEL (Settings/Pages/BagsLooting.lua)
--------------------------------------------------
local module
local pageS = setmetatable({ Module = function(_, def) module = def end }, { __index = function(_, k)
    if k == 'GetPath' then return S.GetPath end
    return function() return {} end
end })
local shows, made, rolls = {}, 0, 0
local usedH = 200
local rolled = { { slot = 1, type = ITEM, name = 'Rolled' } }
local pageNs = {
    L = L, Settings = pageS,
    SettingsPanel = { Box = function() end, RIGHT_W = 280, PAD = 12 },
    SettingsPreview = {
        Create = function(_, w, h)
            made = made + 1
            return { frame = setmetatable({}, Stub), width = w, height = h }
        end,
        Show = function(canvas, spec)
            shows[#shows + 1] = spec
            canvas.used = usedH
            return true
        end,
    },
    LootWindow = { RandomLoot = function() rolls = rolls + 1; return rolled end },
}
local pageEnv = setmetatable({
    CreateFrame = function() return setmetatable({}, Stub) end,
    C_Timer = { After = function(_, fn) fn() end },
}, { __index = _G })
setfenv(assert(loadfile('Settings/Pages/BagsLooting.lua')), pageEnv)('FlareUI', pageNs)
local side = assert(module and module.sidePanel, 'side panel')
local host = setmetatable({}, Stub)
local function last() return shows[#shows] end

paths['tweaks.lootWindow'] = nil
side.show(host)
assert(#shows == 2, 'drawn on show and again once laid out, got ' .. #shows)
assert(last().kind == 'lootWindow' and last().bare and last().rows == nil, 'the fixed rows, bare')
assert(made == 1 and host.canvas.width == 256, 'one canvas, the column picture\'s width')
assert(host.title.text == 'Live Preview' and host.newLoot.text == 'New Loot', 'title and New Loot')
assert(host.newLoot.enabled == true, 'New Loot live')
assert(host.canvas.frame.alpha == 0.4, 'greyed while the loot window is off')
assert(host.canvas.frame.scale == 1, 'fits the width, got ' .. tostring(host.canvas.frame.scale))

paths['tweaks.lootWindow'] = true
usedH = 400
side.show(host)
assert(made == 1, 'the canvas is made once')
assert(host.canvas.frame.alpha == 1, 'full while on')
assert(math.abs(host.canvas.frame.scale - 312 / 400) < 1e-9, 'a tall window shrinks to fit')
areaW, areaH, usedH = 1000, 1000, 200
side.hover('bl.lootWindowSort')
assert(host.canvas.frame.scale == 1.5, 'scaled up to 1.5 at most')
areaW, areaH = 256, 312

-- New Loot: rolled rows, drawn at once, kept through hovers and refreshes
local n = #shows
host.newLoot:GetScript('OnClick')()
assert(rolls == 1, 'New Loot calls LW.RandomLoot')
assert(#shows == n + 1 and last().rows == rolled, 'and draws its rows')
side.hover('bl.lootWindowBorder')
assert(#shows == n + 2 and last().rows == rolled, 'hover redraws, rows kept')
side.hover(nil)
side.show(host)
assert(last().rows == rolled, 'a refresh keeps them')

-- no loot window module: no New Loot, still drawn
pageNs.LootWindow = nil
side.show(host)
assert(host.newLoot.enabled == false, 'New Loot greyed without the module')
n = #shows
host.newLoot:GetScript('OnClick')()
assert(rolls == 1 and #shows == n, 'nothing rolled or drawn')

-- a hidden host: nothing drawn
host.shown = false
n = #shows
side.show(host)
assert(#shows == n, 'nothing drawn while hidden')

--------------------------------------------------
-- TAB GATING (Settings/Panel.lua SidePanel)
--------------------------------------------------
local any
local anyMt = { __index = function() return any end, __call = function() return any end }
any = setmetatable({}, anyMt)
local panelS = { modules = {} }
local panelNs = setmetatable({ L = L, Settings = panelS }, { __index = function() return any end })
local panelEnv = setmetatable({}, { __index = function(_, k)
    local v = _G[k]
    if v ~= nil then return v end
    return any
end })
setfenv(assert(loadfile('Settings/Panel.lua')), panelEnv)('FlareUI', panelNs)
local Panel = rawget(panelNs, 'SettingsPanel')
local function Upvalue(fn, name)
    for i = 1, 200 do
        local up, v = debug.getupvalue(fn, i)
        if not up then return nil end
        if up == name then return i, v end
    end
end
local function Set(name, value) debug.setupvalue(Panel.SidePanel, assert(Upvalue(Panel.SidePanel, name), name), value) end
local _, currentTab = Upvalue(Panel.ActiveTab, 'currentTab')
assert(type(currentTab) == 'table', 'currentTab')

local npOn, blOn = true, true
local np = { key = 'np', tabs = { { key = 'style' }, { key = 'fonts' } }, enabled = 'nameplates.enabled', sidePanel = {},
    IsOn = function() return npOn end }
local bl = { key = 'bl', tabs = { { key = 'bags' }, { key = 'looting' }, { key = 'lootWindow' }, { key = 'fonts' } },
    enabled = 'tweaks.bagModule', sidePanel = { tab = 'lootWindow' }, IsOn = function() return blOn end }
panelS.modules.np, panelS.modules.bl = np, bl

-- no tab: every tab, as before
Set('current', 'np')
assert(Panel.SidePanel() == np.sidePanel, 'Nameplates: first tab')
currentTab.np = 'fonts'
assert(Panel.SidePanel() == np.sidePanel, 'Nameplates: any tab')
npOn = false
assert(Panel.SidePanel() == nil, 'Nameplates off: none')

-- a tab: only there
Set('current', 'bl')
currentTab.bl = nil
assert(Panel.SidePanel() == nil, 'Bags & Looting first tab: none')
for _, key in ipairs({ 'bags', 'looting', 'fonts' }) do
    currentTab.bl = key
    assert(Panel.SidePanel() == nil, 'none on ' .. key)
end
currentTab.bl = 'lootWindow'
assert(Panel.SidePanel() == bl.sidePanel, 'on the Loot Window tab')
Set('searchText', 'loot')
assert(Panel.SidePanel() == nil, 'none in search results')
Set('searchText', '')
blOn = false
assert(Panel.SidePanel() == nil, 'none while the module is off')

print('PASS: loot window preview')
