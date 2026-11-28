local H = dofile('tools/tests/perf-helpers.lua')
-- The game hides a width while the region's anchoring is secret.
local SECRET = setmetatable({}, {
    __add = function() error('arithmetic on a secret number value') end,
    __sub = function() error('arithmetic on a secret number value') end,
})
local textWidth, refWidth = 60, 200
local typeName = { GetUnboundedStringWidth = function() return textWidth end }
local dd = { TypeName = typeName, FlareUI_TitleReserve = 40,
    SetSize = function(self, w, h) self.w, self.h = w, h end }
local ref = { GetWidth = function() return refWidth end }
local window = { FlareUI_DMSkin = ref }
local env = setmetatable({
    canaccessvalue = function(v) return v ~= SECRET end,
    math_max = math.max,
    math_min = math.min,
    TITLE_LEFT = 8,
    HEADER_HEIGHT = 22,
    DamageMeter = {},
    GetWindowTypeDropdown = function() return dd end,
    GetWindowHeader = function() return ref end,
}, { __index = _G })
local fitTitleButton, textWidthOf = H.loadSections('Modules/DamageMeter.lua', {
    {"-- A text's width, or nil.", '-- Settings > Damage Meter open'},
    {'local function FitTitleButton(window)', '----------------'},
}, env, 'FitTitleButton, TextWidth')

-- Readable: the click area ends at the text (8 + 60 + 8).
fitTitleButton(window)
assert(dd.w == 76, 'readable width: ' .. tostring(dd.w))

textWidth = SECRET
dd.w = nil
fitTitleButton(window)
assert(dd.w == 76, 'secret title width kept the last size: ' .. tostring(dd.w))

refWidth = SECRET
dd.w = 1
fitTitleButton(window)
assert(dd.w == 1, 'secret header width leaves the size alone')

local fresh = { GetUnboundedStringWidth = function() return SECRET end }
assert(textWidthOf(fresh) == nil)
print('PASS: a secret title or header width neither throws nor resizes from a guess')
