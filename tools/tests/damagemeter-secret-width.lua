local H = dofile('tools/tests/perf-helpers.lua')
local s = H.read('Modules/DamageMeter.lua')
-- A secret measure: the game hides a width while the region's anchoring is secret. Arithmetic on it
-- throws, as in game ("attempt to perform arithmetic on a secret number value").
local doubles = [[
local SECRET = setmetatable({}, { __add = function() error('arithmetic on a secret number value') end,
    __sub = function() error('arithmetic on a secret number value') end })
local function canaccessvalue(v) return v ~= SECRET end
local math_max, math_min = math.max, math.min
local TITLE_LEFT, HEADER_HEIGHT = 8, 22
local DamageMeter = {}
local textWidth, refWidth = 60, 200
local typeName = { GetUnboundedStringWidth = function() return textWidth end }
local dd = { TypeName = typeName, FlareUI_TitleReserve = 40,
    SetSize = function(self, w, h) self.w, self.h = w, h end }
local ref = { GetWidth = function() return refWidth end }
local window = { FlareUI_DMSkin = ref }
local function GetWindowTypeDropdown() return dd end
local function GetWindowHeader() return ref end
]]
local code = doubles
    .. H.section(s, '-- A text\'s width, or nil.', '-- Settings > Damage Meter open')
    .. H.section(s, 'local function FitTitleButton(window)', '----------------')
    .. [[
-- readable: the click area ends at the text (8 + 60 + 8)
FitTitleButton(window)
assert(dd.w == 76, 'readable width: ' .. tostring(dd.w))

-- the title's width turns secret: no error, the last width read stands in
textWidth = SECRET
dd.w = nil
FitTitleButton(window)
assert(dd.w == 76, 'secret title width kept the last size: ' .. tostring(dd.w))

-- the header's width turns secret too: no error, the size is left as it was
refWidth = SECRET
dd.w = 1
FitTitleButton(window)
assert(dd.w == 1, 'secret header width leaves the size alone')

-- a text never read while readable: nothing to stand in, no error
local fresh = { GetUnboundedStringWidth = function() return SECRET end }
assert(TextWidth(fresh) == nil)
]]
H.load(code)
print('PASS: a secret title or header width neither throws nor resizes from a guess')
