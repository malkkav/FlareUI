-- Run from the repository root: luajit tools/tests/unitframe-custom-text.lua
-- Load the actual formatter helpers without requiring a WoW client.
local file = assert(io.open("Modules/UnitFrames.lua", "r"))
local source = file:read("*a")
file:close()
local first = assert(source:find("UF.CUSTOM_DEFAULTS =", 1, true))
local last = assert(source:find("-- The text for every mode", first, true))
local load = loadstring or load
local shortCalls = 0
local function shortNumber(n)
 shortCalls = shortCalls + 1
 if type(n) ~= "number" then return n end -- opaque client values must not be inspected
 if n >= 1000000 then return tostring(n / 1000000) .. "M" end
 if n >= 10000 then return tostring(n / 1000) .. "K" end
 return tostring(n)
end
local UF = assert(load("return function(ns) local UF = {}; local unpack = unpack or table.unpack;\n"
    .. source:sub(first, last - 1) .. "\nreturn UF end"))()({ShortNumber = shortNumber})
local function font(shown)
 return { IsShown = function() return shown end,
 SetFormattedText = function(self, fmt, ...) self.text = string.format(fmt, ...) end }
end
local f, left = font(), font(true)
local function check(template, expected)
 UF.FormatCustomText(f, template, 18000, 75, 24000)
 assert(f.text == expected, template .. ": " .. f.text)
end
check("[value] / [max]", "18K / 24K")
check("[percent]", "75%")
check("[percent] [value]/[max]", "75% 18K/24K")
check("[percent] [percent]", "75% 75%")
check("100% %s %d [typo]", "100% %s %d [typo]")
check("", "")
check("[value]", "18K")
local cached = f.fuiCustomFormat
check("[value]", "18K")
assert(f.fuiCustomFormat == cached, "cache must be reused")
UF.SetCustomBarText(f, left, {}, "healthText", 18000, 75, 24000)
assert(left.text == "18K / 24K" and f.text == "75%")
local db = {healthTextCustomLeft = "[percent]", healthTextCustomRight = "[value]/[max]"}
UF.SetCustomBarText(f, left, db, "healthText", 18000, 75, 24000)
assert(left.text == "75%" and f.text == "18K/24K")
UF.SetCustomBarText(f, nil, db, "healthText", 18000, 75, 24000)
assert(f.text == "75% | 18K/24K")
db.healthTextCustomLeft = ""
UF.SetCustomBarText(f, nil, db, "healthText", 0, 0, 0)
assert(f.text == "0/0")
db.healthTextCustomRight = ""
UF.SetCustomBarText(f, left, db, "healthText", 0, 0, 0)
assert(f.text == "" and left.text == "")
assert(UF.CustomTemplate({healthTextCustomLeft = false}, "healthText", "Left") == "[value] / [max]")
assert(#UF.CustomTemplate({healthTextCustomLeft = string.rep("x", 250)}, "healthText", "Left") == 200)
local cur, pct, max = {}, {}, {}
local opaque = {SetFormattedText = function(_, fmt, a, b, c)
 assert(fmt == "%s / %s (%.0f%%)")
 assert(a == cur and b == max and c == pct)
end}
UF.FormatCustomText(opaque, "[value] / [max] ([percent])", cur, pct, max)
print("PASS: tags, ordering, literals, blank sides, fallbacks, cache reuse, limits, zero and opaque values")

-- Replacing settings, changing sides and switching to a one-region style must invalidate only
-- what changed. Warm updates reuse both the layout and compiled format/argument tables.
local main, side = font(), font(true)
local settings = {healthTextCustomLeft = "[value] / [max]", healthTextCustomRight = "[percent]"}
UF.SetCustomBarText(main, side, settings, "healthText", 1, 50, 2)
local layout, rightFormat, leftFormat = main.fuiCustomLayout, main.fuiCustomFormat, side.fuiCustomFormat
local args = rightFormat.args
UF.SetCustomBarText(main, side, settings, "healthText", 2, 100, 2)
assert(main.fuiCustomLayout == layout and main.fuiCustomFormat == rightFormat)
assert(side.fuiCustomFormat == leftFormat and main.fuiCustomFormat.args == args)
assert(main.text == "100%" and side.text == "2 / 2")
settings.healthTextCustomLeft = "[percent]"
settings.healthTextCustomRight = "[value] / [max]"
UF.SetCustomBarText(main, side, settings, "healthText", 1, 50, 2)
assert(main.fuiCustomLayout ~= layout and main.text == "1 / 2" and side.text == "50%")
UF.SetCustomBarText(main, font(false), settings, "healthText", 1, 50, 2)
assert(main.text == "50% | 1 / 2")
UF.SetCustomBarText(main, nil, {powerTextCustomLeft = "MP [value]", powerTextCustomRight = ""}, "powerText", 80, 40, 200)
assert(main.text == "MP 80")
-- Literal formats still render correctly after another mode overwrites the font string.
UF.FormatCustomText(main, "Ready", 0, 0, 0)
main.text = "another mode"
UF.FormatCustomText(main, "Ready", 0, 0, 0)
assert(main.text == "Ready")
print("PASS: cache invalidation, layout changes, power templates and literal refresh")

-- Exercise the actual health/power text update branches, including offline/dead cleanup.
local healthStart = assert(source:find('local function UpdateHealth(f, glide)', 1, true))
local powerStart = assert(source:find('local function UpdatePower(f, glide)', healthStart, true))
local healthBody = source:sub(healthStart, powerStart - 1)
local textStart
for at in healthBody:gmatch('()    local mode = udb and udb.healthText or "percent"') do textStart = at end
local powerEnd = assert(source:find('-- GetRaidTargetIndex', powerStart, true))
local updateFactory = assert(load([[
return function(UF, font)
    local connected, dead = true, false
    local db = {healthText = "custom", powerText = "custom"}
    local ns = {SetBarValue = function() end}
    local CurveConstants = {ScaleTo100 = {}}
    local function GetUnitDb() return db end
    local function UnitIsConnected() return connected end
    local function UnitHealth() return 18000 end
    local function UnitHealthMax() return 24000 end
    local function UnitHealthPercent() return 75 end
    local function UnitPowerType() return 0 end
    local function UnitPower() return 80 end
    local function UnitPowerMax() return 200 end
    local function UnitPowerPercent() return 40 end
    local function GetPowerColor() return 0, 0, 1 end
    local function UnitIsGhost() return false end
    local OFFLINE_TEXT, DEAD_TEXT = "Offline", "Dead"
    UF.IsDead = function() return dead end
    UF.PowerTextMode = function(mode) return mode end
    local function UpdateHealth(f)
        local unit, udb = f.fuiUnit, db
]] .. healthBody:sub(assert(textStart)) .. source:sub(powerStart, powerEnd - 1) .. [[
    local function text()
        local fs = font(true)
        fs.clears = 0
        fs.SetText = function(self, value) self.text = value; self.clears = self.clears + 1 end
        fs.SetAlpha = function() end
        return fs
    end
    local f = {fuiUnit = "player", HealthText = text(), HealthTextLeft = text(),
        PowerText = text(), PowerTextLeft = text(),
        Power = {SetMinMaxValues = function() end, SetStatusBarColor = function() end}}
    local function update() UpdateHealth(f); UpdatePower(f) end
    update()
    assert(f.HealthTextLeft.clears == 0 and f.PowerTextLeft.clears == 0)
    assert(f.HealthTextLeft.text == "18K / 24K" and f.PowerTextLeft.text == "80 / 200")
    connected = false; update()
    assert(f.HealthText.text == "Offline" and f.HealthTextLeft.text == "")
    assert(f.PowerText.text == "" and f.PowerTextLeft.text == "")
    connected = true; dead = true; update()
    assert(f.HealthText.text == "Dead" and f.HealthTextLeft.text == "")
    assert(f.PowerText.text == "" and f.PowerTextLeft.text == "")
    dead = false; update()
    assert(f.HealthText.text == "75%" and f.PowerText.text == "40%")
end
]]))()
updateFactory(UF, font)
print("PASS: live updates avoid redundant clears; offline, death and recovery refresh both ends")

-- Abbreviation is delegated once per used numeric tag, even when repeated.
local before = shortCalls
UF.FormatCustomText(main, "[percent]", 10000, 50, 20000)
assert(shortCalls == before, "percent-only text must not abbreviate unused values")
UF.FormatCustomText(main, "[value] [value] [max] [max]", 10000, 50, 20000)
assert(main.text == "10K 10K 20K 20K" and shortCalls == before + 2)
for _, case in ipairs({{0, "0"}, {9999, "9999"}, {10000, "10K"}, {1500000, "1.5M"}}) do
 UF.FormatCustomText(main, "[value]", case[1], 0, 0)
 assert(main.text == case[2])
end
print("PASS: abbreviation delegation, thresholds, repeated tags and unused values")
