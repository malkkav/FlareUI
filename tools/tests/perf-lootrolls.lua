local H = dofile('tools/tests/perf-helpers.lua')
local left = 59.9
local env = setmetatable({
    TimeLeft = function() return left end,
    math_min = math.min,
    math_ceil = math.ceil,
}, { __index = _G })
local updateTimer, startTimer = H.loadSections('Modules/LootRolls.lua', {
    {'local function UpdateTimer(card)', 'local function Timer(card, height)'},
}, env, 'UpdateTimer, StartTimer')

local colors, texts, values = 0, 0, 0
local card = {session = {duration = 120}, SetScript = function(self, _, fn) self.tick = fn end,
 timer = {SetShown = function() end, SetValue = function() values = values + 1 end,
 SetStatusBarColor = function() colors = colors + 1 end},
 timeText = {SetShown = function() end, SetText = function() texts = texts + 1 end}}
for i = 1, 120 do left = 59.9 - i/120; updateTimer(card) end
assert(values == 120 and texts == 2 and colors == 1)
left = 90; updateTimer(card); assert(colors == 2)
startTimer(card, card.session); assert(colors == 3 and texts == 4 and card.tick)
left = nil; updateTimer(card); assert(card.tick == nil)
left = 0; startTimer(card, card.session); assert(card.tick and card.timerSecond == 0)
print('PASS: loot timer stays smooth, caches seconds/color, repaints reused cards and stops expired updates')
