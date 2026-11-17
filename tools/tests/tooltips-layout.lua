-- Tooltips > Layout and the tooltip data (11-17): the real TooltipsLayout.lua and TooltipsData.lua on a
-- made-up GameTooltip. Checks the lines move as they should, the strip reads the game's own wording,
-- and a line the game hides leaves the tooltip alone.
local H = dofile('tools/tests/perf-helpers.lua')

local SECRET = setmetatable({}, { __tostring = function() return 'SECRET' end })
_G.canaccessvalue = function(v) return v ~= SECRET end
_G.issecretvalue = function(v) return v == SECRET end
_G.GetLocale = function() return 'enUS' end
_G.LibStub = function() return nil end
_G.C_Item = { GetItemNameByID = function() return nil end }
_G.C_Texture = { GetAtlasInfo = function() return { width = 80, height = 100 } end }
_G.C_Spell = { GetSpellTexture = function() return 135846 end }
_G.SetPortraitTexture = function() end
_G.UnitGUID = function() return 'Creature-0-1-2-3-1748-0' end
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
_G.ITEM_BIND_ON_EQUIP = 'Binds when equipped'
_G.ITEM_BIND_ON_PICKUP = 'Binds when picked up'
_G.strsplit = function(sep, s) local t = {} for p in (s .. sep):gmatch('(.-)%' .. sep) do t[#t + 1] = p end return unpack(t) end

-- the game's strings, as on an English client
_G.MANA_COST, _G.MANA = '%d Mana', 'Mana'
_G.SPELL_RANGE, _G.MELEE_RANGE = '%s yd range', 'Melee Range'
_G.SPELL_CAST_TIME_SEC, _G.SPELL_CAST_TIME_INSTANT = '%.3g sec cast', 'Instant'
_G.SPELL_RECAST_TIME_SEC, _G.SPELL_RECAST_TIME_MIN = '%.3g sec cooldown', '%.3g min cooldown'
_G.STRING_SCHOOL_FROST = 'Frost'
_G.DEAD = 'Dead'

-- frames: every method answers nothing, except the few the layout reads back
local frames = {}
local function Stub()
    local o = {}
    return setmetatable(o, { __index = function(_, key)
        if key == 'CreateTexture' or key == 'CreateFontString' then return function() return Stub() end end
        if key == 'SetText' then return function(self, t) rawset(self, '_text', t) end end
        if key == 'GetText' then return function(self) return rawget(self, '_text') end end
        if key == 'Show' then return function(self) rawset(self, '_shown', true) end end
        if key == 'Hide' then return function(self) rawset(self, '_shown', false) end end
        if key == 'IsShown' then return function(self) return rawget(self, '_shown') or false end end
        if key == 'GetFrameLevel' then return function() return 1 end end
        return function() end
    end })
end
_G.CreateFrame = function() local f = Stub(); frames[#frames + 1] = f; return f end

-- a tooltip's line: text, colour, font, and a height as the client would measure it
local function NewLine(text, font)
    local fs = { text = text, shown = text ~= nil, color = { 1, 1, 1 }, font = font or 'GameTooltipText', wrap = false }
    function fs:GetText() return self.text end
    function fs:SetText(t) self.text = t end
    function fs:GetTextColor() return self.color[1], self.color[2], self.color[3], 1 end
    function fs:SetTextColor(r, g, b) self.color = { r, g, b } end
    function fs:GetFontObject() return self.font end
    function fs:SetFontObject(f) self.font = f end
    function fs:CanWordWrap() return self.wrap end
    function fs:SetWordWrap(w) self.wrap = w end
    function fs:Show() self.shown = true end
    function fs:Hide() self.shown = false end
    function fs:SetShown(s) self.shown = s end
    function fs:IsShown() return self.shown end
    function fs:GetStringWidth()
        if self.text == SECRET then return SECRET end
        local plain = (self.text or ''):gsub('|T[^|]+|t', ''):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', '')
        return #plain * 6
    end
    function fs:SetHeight(h) self.height = h end
    function fs:SetJustifyV(j) self.justifyV = j end
    function fs:GetJustifyV() return self.justifyV or 'MIDDLE' end
    function fs:GetFont() return 'Fonts\\FRIZQT__.TTF', self.font == 'GameTooltipHeaderText' and 14 or 12, '' end
    -- each row as tall as its font, or its tallest inline texture
    function fs:GetStringHeight()
        if self.text == SECRET then return SECRET end
        local base = self.font == 'GameTooltipHeaderText' and 16 or 12
        local h, rows = 0, 0
        for row in ((self.text or '') .. '\n'):gmatch('(.-)\n') do
            local tall = tonumber(row:match('|T[^:]+:(%d+):'))
            h, rows = h + math.max(base, tall or 0), rows + 1
        end
        return h + (rows - 1) * 2
    end
    return fs
end

local function NewTooltip(name, lines)
    local tip = Stub()
    rawset(tip, 'n', 0)
    rawset(tip, 'hooks', {})
    function tip:HookScript(event, fn) local h = rawget(self, 'hooks'); h[event] = h[event] or {}; table.insert(h[event], fn) end
    -- the game clearing the tooltip for its next fill
    function tip:Clear()
        for _, fn in ipairs(rawget(self, 'hooks').OnTooltipCleared or {}) do fn(self) end
        for i = 1, rawget(self, 'n') do _G[name .. 'TextLeft' .. i].text = nil; _G[name .. 'TextRight' .. i].text = nil end
        rawset(self, 'n', 0)
    end
    function tip:GetName() return name end
    function tip:NumLines() return rawget(self, 'n') end
    function tip:GetHeight() return 120 end
    function tip:AddLine(text)
        local n = rawget(self, 'n') + 1
        rawset(self, 'n', n)
        _G[name .. 'TextLeft' .. n] = NewLine(text, n == 1 and 'GameTooltipHeaderText' or nil)
        _G[name .. 'TextRight' .. n] = NewLine(nil)
    end
    for _, line in ipairs(lines) do
        tip:AddLine(line[1])
        if line[2] then local r = _G[name .. 'TextRight' .. tip:NumLines()]; r:SetText(line[2]); r:Show() end
    end
    return tip
end
local function Left(i) return _G['GameTooltipTextLeft' .. i] end
local function Right(i) return _G['GameTooltipTextRight' .. i] end

-- ns as Tooltips.lua leaves it
local db = {}
local ns = { L = setmetatable({}, { __index = function(_, k) return k end }) }
ns.Tooltips = { borderColorOf = {}, util = {
    GetDb = function() return db end,
    Readable = function(v) if v ~= SECRET then return v end end,
    SafeToTouch = function() return true end,
    Line = function(tip, side, i) return _G[tip:GetName() .. 'Text' .. side .. i] end,
    ColorToHex = function(r, g, b) return ('|cff%02x%02x%02x'):format(r * 255, g * 255, b * 255) end,
    UnitLevelColor = function() return { r = 1, g = 0.82, b = 0 } end,
    DEFAULT_BORDER_COLOR = { 0.8, 0.6, 0.34 },
    PATTERN_MAGIC = '[%^%$%(%)%%%.%[%]%*%+%-%?]',
} }
local tooltips = H.read('Modules/Tooltips.lua')
local format = H.load(H.section(tooltips, 'local PATTERN_MAGIC', '-- 5. COLOURS') .. ' return FormatPattern')
ns.Tooltips.util.FormatPattern = format
assert(loadfile('Modules/TooltipsData.lua'))('FlareUI', ns)
assert(loadfile('Modules/TooltipsLayout.lua'))('FlareUI', ns)
local Layout, D = ns.Tooltips.Layout, ns.TooltipsData

-- the game's format strings as patterns
assert(('Durability 31 / 70'):match(format('Durability %d / %d')) == '31', 'durability figures')
assert(select(2, ('Durability 31 / 70'):match(format('Durability %d / %d'))) == '70', 'durability most')
assert(('2.2 sec cast'):match(format(_G.SPELL_CAST_TIME_SEC)) == '2.2', 'a cast time')
assert(('8-35 yd range'):match(format(_G.SPELL_RANGE)) == '8-35', 'a range with a minimum')
assert(not ('50 Mana per sec'):match(format(_G.MANA_COST)), 'only the whole line')

-- data
assert(D.SpellSchool(116) == 'Frost', 'Frostbolt rank 1 is Frost')
assert(D.SpellSchool(78) == nil, 'Heroic Strike is physical: no school')
assert(D.NodeLevel('Kingsblood') == 125 and D.NodeLevel('Mithril Deposit') == 175, 'node levels')
assert(D.NodeLevel('Mailbox') == nil, 'not a node')
assert(select(2, D.NodeLevel('Kingsblood')) == 'Herbalism' and select(2, D.NodeLevel('Rich Thorium Vein')) == 'Mining'
    and select(2, D.NodeLevel('Lesser Bloodstone Deposit')) == 'Mining', 'which skill a node needs')
local list = D.Disenchant(1, 4, 3, 48, 'INVTYPE_CHEST')
assert(#list == 1 and list[1] == 11178, 'a level 48 blue: a Large Radiant Shard')
list = D.Disenchant(1, 2, 2, 30, 'INVTYPE_WEAPON')
assert(list[1] == 11082 and list[2] == 11083 and list[3] == 11084, 'a green weapon: essence first')
list = D.Disenchant(1, 4, 2, 30, 'INVTYPE_CHEST')
assert(list[1] == 11083, 'green armour: dust first')
assert(D.Disenchant(1, 4, 2, 30, 'INVTYPE_TABARD') == nil, 'tabards are not disenchanted')
assert(D.Disenchant(1, 15, 2, 30, '') == nil, 'only weapons and armour')
assert(D.MaterialName(11178) == 'Large Radiant Shard', 'the English name until the client has it')

local function Rows(text) local r = {} for row in (text .. '\n'):gmatch('(.-)\n') do r[#r + 1] = row end return r end

-- a spell: school and rank on the name line's right, the strip's one row in the cost line; no line moves
db = { badges = true, spellStrip = true, headerIcon = true }
local function Frostbolt()
    return NewTooltip('GameTooltip', { { 'Frostbolt', 'Rank 3' }, { '50 Mana', '30 yd range' }, { '2.2 sec cast' },
        { 'Launches a bolt of frost at the enemy, causing 18 to 20 Frost damage and slowing movement speed by 40% for 5 sec.' } })
end
_G.GameTooltip = Frostbolt()
Layout.Spell(GameTooltip, { id = 116 })
assert(GameTooltip:NumLines() == 4, 'no line added or moved: ' .. GameTooltip:NumLines())
assert(Left(1).text:match('Empty:1:%d+|t'), 'room for the icon on the name')
assert(Right(1).shown and Right(1).text:find('Frost', 1, true) and Right(1).text:find('Rank 3', 1, true), 'school and rank, top right')
local strip = Left(2).text
assert(strip:match('Empty:1:%d+|t'), 'the strip row beside the icon')
assert(strip:find('50 Mana', 1, true) and strip:find('2.2 sec cast', 1, true) and strip:find('30 yd range', 1, true),
    'cost, cast and range on one row')
assert(strip:find('50 Mana', 1, true) < strip:find('2.2 sec', 1, true) and strip:find('2.2 sec', 1, true) < strip:find('30 yd', 1, true),
    'in the order cost, cast, range')
assert(strip:find('|cff', 1, true), 'the cost in its colour')
assert(not Right(2).shown and Left(3).text == nil, 'the range and the cast line go')
assert(Left(4).text == 'Launches a bolt of frost at the enemy, causing 18 to 20 Frost damage and slowing movement speed by 40% for 5 sec.', 'the description is left alone')

-- the strip alone: nothing else changes
db = { spellStrip = true }
GameTooltip = Frostbolt()
Layout.Spell(GameTooltip, { id = 116 })
assert(GameTooltip:NumLines() == 4 and Right(1).text == 'Rank 3', 'no badges, no icon')
assert(Left(2).text:find('2.2 sec cast', 1, true) and Left(4).text == 'Launches a bolt of frost at the enemy, causing 18 to 20 Frost damage and slowing movement speed by 40% for 5 sec.', 'strip only')

-- Life Tap: only "Instant"
GameTooltip = NewTooltip('GameTooltip', { { 'Life Tap', 'Rank 4' }, { 'Instant' }, { 'Converts 326 Health into 326 Mana.' } })
Layout.Spell(GameTooltip, { id = 1456 })
assert(Left(2).text == 'Instant' and Left(3).text == 'Converts 326 Health into 326 Mana.', 'one value is a row of one')

-- badges without the strip: only the name line's right changes
db = { badges = true }
GameTooltip = NewTooltip('GameTooltip', { { 'Life Tap', 'Rank 4' }, { 'Instant', '30 yd range' }, { 'Converts 326 Health into 326 Mana.' } })
Layout.Spell(GameTooltip, { id = 1456 })
assert(Right(1).text:find('Rank 4', 1, true) and Left(2).text == 'Instant' and Right(2).text == '30 yd range', 'badges top right')

-- a passive or anything that isn't cost / cast / range: no strip
db = { spellStrip = true }
GameTooltip = NewTooltip('GameTooltip', { { 'Frost Warding' }, { 'Passive' }, { 'Increases armor.' } })
Layout.Spell(GameTooltip, { id = 11189 })
assert(Left(2).text == 'Passive', 'a passive keeps its lines')

-- a line the game hides: left alone
db = { headerIcon = true }
GameTooltip = NewTooltip('GameTooltip', { { 'Frostbolt', 'Rank 3' }, { SECRET } })
Layout.Spell(GameTooltip, { id = 116 })
assert(Left(1).text == 'Frostbolt' and Left(2).text == SECRET, 'a secret line in the header: no icon, nothing moved')

-- a unit: badges as a row under the level line; the faction line stays where it is
_G.UnitClassification = function() return 'elite' end
_G.UnitLevel = function() return -1 end
_G.UnitIsPVP = function() return true end
_G.UnitIsAFK = function() return false end
_G.UnitIsDND = function() return false end
_G.UnitIsDeadOrGhost = function() return false end
db = { badges = true }
GameTooltip = NewTooltip('GameTooltip', { { 'Highlord Bolvar Fordragon' }, { 'Level ?? Humanoid' }, { 'Stormwind' } })
Layout.Unit(GameTooltip, 'mouseover', 2)
assert(Right(1).shown and Right(1).text:find('Boss', 1, true) and Right(1).text:find('PvP', 1, true), 'Boss · PvP top right')
assert(GameTooltip:NumLines() == 3 and Left(2).text == 'Level ?? Humanoid' and Left(3).text == 'Stormwind', 'the lines stay')

-- a unit with a portrait and a level plate: a blank row under a header that's too short
db = { headerIcon = true }
_G.UnitLevel = function() return 9 end
GameTooltip = NewTooltip('GameTooltip', { { 'Elder Mottled Boar' } })
Layout.Unit(GameTooltip, 'mouseover', nil)
rows = Rows(Left(1).text)
assert(GameTooltip:NumLines() == 1 and #rows == 2 and rows[2]:find('Empty:', 1, true), 'room for the icon and its plate')

-- an item whose second line wraps: it starts under the icon, the line after it isn't moved right
db = { headerIcon = true }
_G.TooltipUtil = { GetDisplayedItem = function() return 'Goldenbark Apple', 'item:4539' end }
_G.C_Item.GetItemInfoInstant = function() return 4539, nil, nil, nil, 133975 end
local use = 'Use: Restores 841 health over 27 sec.  Must remain seated while eating.'
GameTooltip = NewTooltip('GameTooltip', { { 'Goldenbark Apple' }, { use }, { 'Requires Level 25' } })
Layout.Item(GameTooltip, {})
assert(#Rows(Left(1).text) == 2 and Left(2).text == use, 'the long line under the icon, whole')
assert(Left(3).text == 'Requires Level 25', 'the line after it is left alone')

-- another addon's double line ("Vendor 87c") after a short header: not moved right
GameTooltip = NewTooltip('GameTooltip', { { 'Red Wolf Meat' }, { 'Crafting Reagent' }, { 'Vendor', '87c' }, { 'Auction', '2s 53c' } })
Layout.Item(GameTooltip, {})
assert(Left(2).text:find('Empty:1:', 1, true) and #Rows(Left(2).text) == 1, 'the icon fits the two-line header: no blank row')
assert(Left(3).text == 'Vendor' and Left(4).text == 'Auction', 'the addon lines are left alone')
assert(Left(2).height == 12 + 6 and Left(2).justifyV == 'TOP', 'the last header line is made taller: ' .. tostring(Left(2).height))
local padded = Left(2)
GameTooltip:Clear()
assert(padded.height == 0 and padded.justifyV == 'MIDDLE', 'and gets its height back when the tooltip clears')

-- a comparison gets the item's icon too
local compare = NewTooltip('ShoppingTooltip1', { { 'Vine Pruner\'s Cloak' }, { 'Soulbound' }, { 'Back' } })
Layout.Item(compare, {})
assert(_G.ShoppingTooltip1TextLeft1.text:match('Empty:1:%d+|t'), 'the comparison has room for the icon')

-- an item: the binding beside the slot, both beside the icon
db = { badges = true, headerIcon = true }
GameTooltip = NewTooltip('GameTooltip', { { 'Sorcerer Cloak of the Champion' }, { 'Binds when equipped' }, { 'Back' }, { '25 Armor' } })
Layout.Item(GameTooltip, {})
assert(Left(2).text:find('Back', 1, true) and Right(2).text == 'Binds when equipped' and Left(3).text == nil, 'Back | Binds when equipped')
assert(Left(2).text:match('Empty:1:%d+|t'), 'beside the icon')
-- a weapon's slot line has its type on the right: the binding stays
GameTooltip = NewTooltip('GameTooltip', { { 'Gnarled Staff' }, { 'Binds when picked up' }, { 'Two-Hand', 'Staff' } })
_G.ITEM_BIND_ON_PICKUP = 'Binds when picked up'
Layout.Item(GameTooltip, {})
assert(Left(2).text:find('Binds when picked up', 1, true) and Right(3).text == 'Staff', 'the binding stays')

-- with the plate, the level line drops "Level 27"
_G.LEVEL = 'Level'
db = { headerIcon = true }
_G.UnitLevel = function() return 27 end
GameTooltip = NewTooltip('GameTooltip', { { 'Bizder Vaelaris' }, { '<Ale Brutale>' },
    { '|cffffd100Level 27|r|cffffffff High Order Skyborne Hunter|r' }, { 'Alliance' } })
Layout.Unit(GameTooltip, 'mouseover', 3)
assert(not Left(3).text:find('Level', 1, true) and Left(3).text:find('|cffffffffHigh Order Skyborne Hunter|r', 1, true),
    'the level is on the plate only: ' .. Left(3).text)
-- a line that was only the level empties
_G.UnitLevel = function() return 39 end
GameTooltip = NewTooltip('GameTooltip', { { 'Farholde Scout' }, { '|cffffd100Level 39|r' }, { 'Brotherhood of the Horse' } })
Layout.Unit(GameTooltip, 'mouseover', 2)
assert(Left(2).text == nil and Left(3).text:find('Brotherhood', 1, true), 'only the level: the line empties')
-- a header that can't be read: no icon, the level comes back
GameTooltip = NewTooltip('GameTooltip', { { 'Farholde Scout' }, { '|cffffd100Level 39|r' }, { SECRET } })
Layout.Unit(GameTooltip, 'mouseover', 2)
assert(Left(2).text == '|cffffd100Level 39|r', 'no plate: the level is back')
-- without the icon the level stays
db = { badges = true }
GameTooltip = NewTooltip('GameTooltip', { { 'Bizder Vaelaris' }, { '|cffffd100Level 27|r|cffffffff Human Hunter|r' } })
Layout.Unit(GameTooltip, 'mouseover', 2)
assert(Left(2).text:find('Level 27', 1, true), 'the level stays without a plate')

-- emptied lines are made 1 px tall, and get their height back when the tooltip clears
db = { spellStrip = true }
GameTooltip = Frostbolt()
Layout.Spell(GameTooltip, { id = 116 })
assert(Left(3).text == nil and Left(3).height == 1, 'the cast line collapses')
local collapsedLine = Left(3)
GameTooltip:Clear()
assert(collapsedLine.height == 0, 'and gets its height back when the tooltip clears')

-- a second post-call on the same fill doesn't lay it out again
db = { badges = true }
GameTooltip = Frostbolt()
Layout.Spell(GameTooltip, { id = 116 })
local once = Right(1).text
Layout.Spell(GameTooltip, { id = 116 })
assert(Right(1).text == once and select(2, once:gsub('Frost', '')) == 1, 'laid out once per fill')
GameTooltip:Clear()
GameTooltip:AddLine('Frostbolt'); Right(1):SetText('Rank 3'); Right(1):Show()
Layout.Spell(GameTooltip, { id = 116 })
assert(Right(1).text:find('Rank 3', 1, true) and Right(1).text:find('Frost', 1, true), 'and again after the next clear')

-- a strip line with nothing on the left: the right side read once
db = { spellStrip = true }
GameTooltip = NewTooltip('GameTooltip', { { 'Shoot' }, { nil, '30 yd range' }, { 'Shoots at the enemy with a wand.' } })
Layout.Spell(GameTooltip, { id = 5019 })
local stripRow = Left(2).text
assert(stripRow and select(2, stripRow:gsub('30 yd range', '')) == 1, 'the range once: ' .. tostring(stripRow))

print('PASS: tooltips layout and data')
