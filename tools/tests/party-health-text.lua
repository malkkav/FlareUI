local H = dofile("tools/tests/perf-helpers.lua")
local secretPercent, secretLost, secretLostText = {}, {}, {}
local current, maximum, percent, missing = 1800, 2000, 90, 200
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    ShortNumber = function(value)
        if value == secretLost then return secretLostText end
        return tostring(value)
    end,
}
local env = setmetatable({
    canaccessvalue = function(value) return value ~= secretPercent and value ~= secretLost end,
    LibStub = function() return { SettingType = {} } end,
    UnitHealth = function() return current end,
    UnitHealthMax = function() return maximum end,
    UnitHealthPercent = function() return percent end,
    UnitHealthMissing = function(unit, usePredicted)
        assert(unit == "party1" and usePredicted == true)
        return missing
    end,
}, { __index = _G })
setfenv(assert(loadfile("Modules/BarText.lua")), env)("FlareUI", ns)
local BT = ns.BarText

local function Choice(values)
    for _, choice in ipairs(values) do
        if choice.text == "Percent | Health Lost" then return choice.value end
    end
end

local mode = assert(Choice(BT.Values("health", "plain", "party")), "Classic parties should offer the combined health text")
assert(Choice(BT.Values("health", "plate", "party")) == mode, "Forever Style should offer the same choice")
assert(not Choice(BT.Values("power", "plain", "party")) and not Choice(BT.Values("health", "plain", "boss")),
    "The choice should be limited to party health bars")

local unitFrames = H.read("Modules/UnitFrames.lua")
local format = H.section(unitFrames, "UF.RIGHT_MODES =", "-- Health Lost: \"")
local sources = H.section(unitFrames, "function UF.SlotsWant", "-- fills a bar's slots")
local UF = {}
local loadUnitFrames = assert(loadstring("local UF, ns, L, math_floor = ...\n" .. format .. sources .. "\nreturn HEALTH_TEXT_MODES"))
local sharedModes = setfenv(loadUnitFrames, env)(UF, ns, ns.L, math.floor)

-- Build the real Party Frames text settings with client widgets and other rows stubbed out.
local party = { classic = {}, raid = { healthText = "none" } }
local function EmptySetting() return {} end
ns.SplitFrameItems = function(items) return {}, items, {} end
local settingsEnv = setmetatable({
    ns = ns, L = ns.L, LEM = env.LibStub(),
    K = {
        HEALTH_TEXT_MODES = sharedModes,
        EditSections = function() return function() end, {} end,
        PlatePowerSetting = EmptySetting,
        ValuesOnHoverSetting = EmptySetting,
        HealthColorSetting = EmptySetting,
    },
    GetPartyDb = function() return party end,
    S = function() return party.raid, "raid" end,
    IsRaidStyle = function() return true end,
    StyleDefaults = function() return { healthText = "none" } end,
    Refresh = function() end,
}, { __index = env })
local partyFrames = H.read("Modules/PartyFrames.lua")
local buildText = H.section(partyFrames, "local function BuildSettings()", "    -- buffs, debuffs and dispel icons")
local loadTextSettings = assert(loadstring(buildText .. "\nreturn textItems\nend\nreturn BuildSettings()"))
local raidText
for _, setting in ipairs(setfenv(loadTextSettings, settingsEnv)()) do
    if setting.name == "Health Text" and not setting.hidden() then raidText = setting end
end
assert(raidText and Choice(raidText.values) == mode, "Raid Style should offer the combined choice in its dropdown")
assert(not Choice(sharedModes), "The shared dropdown for standalone Raid Frames should keep its own choices")
assert(raidText.get() == "none", "The new mode should be opt-in")
raidText.set(nil, mode)
assert(raidText.get() == mode and party.classic.healthText == nil, "The setting should save only to Raid Style")

local fs = {
    SetAlpha = function() end,
    SetText = function(self, text) self.text = text end,
    SetFormattedText = function(self, pattern, ...)
        self.pattern, self.args = pattern, { ... }
        if self.args[1] ~= secretPercent then self.text = string.format(pattern, ...) end
    end,
}

local db = {}
BT.Toggle(db, "health", "right", "plain", mode, false, nil, nil, "party")
local slots = BT.Slots(db, "health", "plain", nil, nil, "party")
BT.Fill(fs, slots.right, UF.HealthSource("party1", slots))
assert(fs.text == "90% | -200", "The new slot choice should replace its default percent without duplicating it")
BT.Fill(fs, slots.right, UF.SampleSource(0.9, 2000))
assert(fs.text == "90% | -200", "The Classic preview should match live text")
assert(BT.Summary(slots):find("Percent | Health Lost", 1, true), "The closed menu should show the choice")
BT.Toggle(db, "health", "right", "plain", "percent", false, nil, nil, "party")
BT.Fill(fs, BT.Slots(db, "health", "plain", nil, nil, "party").right, UF.SampleSource(0.9, 2000))
assert(fs.text == "90%", "A regular numeric choice should replace the combined preset")

UF.FormatBarText(fs, mode, current, percent, maximum, "party1")
assert(fs.text == "90% | -200", "Raid Style should display both values from the unit")
UF.FormatBarText(fs, mode, current, percent, maximum)
assert(fs.text == "90% | -200", "The Raid Style preview should match live text")
BT.Fill(fs, slots.right, UF.SampleSource(1, 2000))
assert(fs.text == "100%", "Classic should omit a readable zero deficit")
UF.FormatBarText(fs, mode, maximum, 100, maximum)
assert(fs.text == "100%", "Raid Style should omit a readable zero deficit")

percent, missing = secretPercent, secretLost
BT.Fill(fs, slots.right, UF.HealthSource("party1", slots))
assert(fs.pattern == "%.0f%% | -%s" and fs.args[1] == secretPercent and fs.args[2] == secretLostText)
UF.FormatBarText(fs, mode, current, percent, maximum, "party1")
assert(fs.pattern == "%.0f%% | -%s" and fs.args[1] == secretPercent and fs.args[2] == secretLostText)

print("PASS: party health text combines percent and health lost in live frames and previews")
