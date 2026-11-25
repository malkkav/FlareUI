-- Smooth Animated Bars gets a druid's Mana on Shapeshift bar: in caster form too, since shifting comes in a fight,
-- and with no unit, so it never takes the form's rage effects
local db = {
    styleStart = true, frameFontsSeeded = true, castTimeSeeded = true, foreverStyle = true,
    units = { player = { enabled = true, width = 190, height = 60, powerHeight = 15, portrait = "3d", shiftMana = true } },
    layouts = { Main = { player = { point = "CENTER", x = 0, y = 0 } } },
    party = { size = {}, auras = {}, enabled = false }, boss = { enabled = true },
}
local ui, ns = dofile("tools/tests/fixtures/unitframes-ui.lua")(db)
local env = ui.env
local UF, S = ns.UnitFrames, ns.SAB
local timers = {}
env.C_Timer = env.C_Timer or {}
env.C_Timer.After = function(_, fn) timers[#timers + 1] = fn end
local function run() local list = timers timers = {} for _, fn in ipairs(list) do fn() end end
local bars = {}
env.SmoothAnimatedBars = {
    IsEnabled = function() return true end, RegisterCallback = function() end,
    AddBar = function(bar, unit, kind) bars[bar] = unit .. " " .. kind return true end,
    RemoveBar = function(bar) bars[bar] = nil return true end,
}
local f = env.CreateFrame("Button", nil, env.UIParent)
f.fuiUnit = "player"
f.Health, f.Power, f.ShiftMana = env.CreateFrame("StatusBar", nil, f), env.CreateFrame("StatusBar", nil, f), env.CreateFrame("StatusBar", nil, f)
for _, key in ipairs({ "Health", "Power", "ShiftMana" }) do f[key]:SetSize(180, 15) end
f.ShiftMana:Hide()
local look = 0
UF.BarLookOwnerChanged = function() look = look + 1 end
S.UnitFrame(f)
run()
assert(bars[f.Health] == "player health" and bars[f.Power] == "player power")
assert(bars[f.ShiftMana] == "none power" and S.owned[f.ShiftMana] and look == 3)

-- the switch off: our own fill
db.units.player.shiftMana = false
S.UnitFrame(f)
run()
assert(not bars[f.ShiftMana] and not S.owned[f.ShiftMana] and bars[f.Power])

-- the power bar off: a thin strip, too low for the liquid
db.units.player.shiftMana, db.units.player.powerHeight = true, 0
S.UnitFrame(f)
run()
assert(not bars[f.ShiftMana])

-- any other class has no such bar
f.ShiftMana = nil
S.UnitFrame(f)
run()
assert(bars[f.Health])
print("PASS: Smooth Animated Bars takes the Mana on Shapeshift bar, without the form's effects")
