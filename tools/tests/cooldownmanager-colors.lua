-- Run from the repository root:  luajit tools/tests/cooldownmanager-colors.lua
-- Bar Colour (CooldownManager.lua, 11-20): FlareUI's colour window, palette FlareUI or Custom. A plain
-- barColor from the first build becomes the Custom palette once.
local H = dofile("tools/tests/perf-helpers.lua")
local source = H.read("Modules/CooldownManager.lua")
local s = assert(source:find("local function GetDb()", 1, true))
local e = assert(source:find("\nlocal function Readable", s, true))
local loader = loadstring or load
local profile = { cooldownmanager = { movedFromAuras = true } }
local env = setmetatable({ ns = { db = { profile = profile } }, CM = {} }, { __index = _G })
local chunk = assert(loader(source:sub(s, e)))
setfenv(chunk, env)
chunk()
local CM = env.CM

local function check(ok, message) assert(ok, message) end
local function same(a, b) return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] end

check(CM.Palette() == "flareui" and same(CM.Color("bar"), CM.COLORS.bar), "FlareUI's colour by default")

local db = profile.cooldownmanager
db.palette, db.customColors = "custom", { bar = { 0.2, 0.4, 0.6 } }
check(same(CM.Color("bar"), { 0.2, 0.4, 0.6 }), "Custom: the picked colour")
db.palette = nil
check(same(CM.Color("bar"), CM.COLORS.bar), "back to FlareUI's: the custom one is kept but unused")

-- the first build's plain Bar Colour
profile.cooldownmanager = { movedFromAuras = true, barColor = { 0.9, 0.1, 0.1 } }
check(CM.Palette() == "custom" and same(CM.Color("bar"), { 0.9, 0.1, 0.1 }), "old Bar Colour carried over")
check(profile.cooldownmanager.barColor == nil, "old key cleared")

print("PASS: cooldown manager colours")
