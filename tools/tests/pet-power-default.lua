-- A pet without a saved power height shows its resource bar; saved choices win.
local H = dofile("tools/tests/perf-helpers.lua")
local core = H.read("Core.lua")
local ace = H.read("Libs/AceDB-3.0/AceDB-3.0.lua")
local frames = H.read("Modules/UnitFrames.lua")

H.load([[
local ns = { UF_FONT_DEFAULTS = {}, UF_FONT_FRAME_DEFAULTS = {} }
local function FCMBars() return {} end
local function VisibilityElements() return {} end
]] .. H.section(core, "local defaults = {", "\n--------------------------------------------------\n-- 5. SHARED UTILITIES") .. [[
]] .. H.section(ace, "local function copyDefaults(", "-- Called to remove all defaults") .. [[
local INSET, SEPARATOR_HEIGHT = 2, 1
local UF = { LayoutMirrored = function() return false end }
local function IsComboShown() return false end
local function PortraitSpace() return 0 end
local settings
local function GetUnitDb() return settings end
]] .. H.section(frames, "local function LayoutBars(f)", "-- Shows or hides the bar") .. [[
local function widget()
    return {
        ClearAllPoints = function() end, SetPoint = function() end,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
        SetHeight = function(self, height) self.height = height end,
    }
end
local function layout(savedHeight)
    settings = {}
    if savedHeight ~= nil then settings.powerHeight = savedHeight end
    copyDefaults(settings, defaults.profile.unitframes.units.pet)
    local frame = { fuiUnit = "pet", Health = widget(), Power = widget(), Separator = widget() }
    LayoutBars(frame)
    return frame.Power
end
local default = layout()
assert(default.shown and default.height == 8, "default pet resource bar must be visible at height 8")
local hidden = layout(0)
assert(hidden.shown == false, "a saved height of 0 must keep the pet resource bar hidden")
local custom = layout(13)
assert(custom.shown and custom.height == 13, "a saved pet resource bar height must be kept")
]])
print("PASS: pet power bar defaults to height 8 and keeps saved heights")
