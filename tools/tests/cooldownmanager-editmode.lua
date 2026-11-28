-- Run from the repository root with Lua 5.1 or LuaJIT.
-- The Cooldown Manager in Edit Mode: Blizzard's Visibility and Opacity rows leave a viewer's dialog only
-- while they hold their defaults (Modules/CooldownManager.lua), and Blizzard's Opacity comes back after a
-- FlareUI fade (Modules/Visibility.lua).
local H = dofile("tools/tests/perf-helpers.lua")
hooksecurefunc = function(object, method, hook)
    local original = object[method]
    object[method] = function(...)
        original(...)
        hook(...)
    end
end
C_CooldownViewer = {}
C_AddOns = { IsAddOnLoaded = function() return true end }
C_Timer = { After = function() end }
EventUtil = { ContinueOnAddOnLoaded = function() end }
GetCVarBool = function() return true end
CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end
local VIEWER, VISIBLE, OPACITY, SIZE = 20, 4, 5, 1
Enum = {
    EditModeSystem = { CooldownViewer = VIEWER },
    EditModeCooldownViewerSetting = { VisibleSetting = VISIBLE, Opacity = OPACITY, IconSize = SIZE },
    CooldownViewerVisibleSetting = { Always = 0 },
}

local function Row(setting)
    local row = { setting = setting, shown = true }
    function row:IsShown() return self.shown end
    function row:Hide() self.shown = false end
    return row
end
local values = {}
local system = { system = VIEWER, GetSettingValue = function(_, setting) return values[setting] end }
local visible, opacity, size = Row(VISIBLE), Row(OPACITY), Row(SIZE)
local layouts = 0
EditModeSystemSettingsDialog = {
    attachedToSystem = system,
    Settings = {
        GetChildren = function() return visible, opacity, size end,
        Layout = function() layouts = layouts + 1 end,
    },
    -- (Blizzard shows every row again when it builds the dialog)
    UpdateSettings = function() visible.shown, opacity.shown, size.shown = true, true, true end,
}
local dialog = EditModeSystemSettingsDialog

local ns = { modules = {}, L = setmetatable({}, { __index = function(_, key) return key end }) }
assert(loadfile("Modules/CooldownManager.lua"))("FlareUI", ns)
ns.IsGamepadUI = function() return false end
local CM = ns.CooldownManager
local db = { enabled = false, movedFromAuras = true }
ns.db = { profile = { cooldownmanager = db } }

-- off at login, switched on since: not started until the reload
CM:ShouldLoad()
assert(not CM.Started(), "off at login")
db.enabled = true
assert(not CM.Started(), "switched on, the reload still to come")
CM:ShouldLoad()
assert(CM.Started(), "on at login")

CM:Init()
local function open(visibleValue, opacityValue)
    values[VISIBLE], values[OPACITY], values[SIZE] = visibleValue, opacityValue, 3
    layouts = 0
    dialog:UpdateSettings()
end

open(0, 100)
assert(not visible.shown and not opacity.shown, "both rows at their defaults leave the dialog")
assert(size.shown, "Blizzard's other rows stay")
assert(layouts == 1, "the dialog is laid out again")

open(0, 60)
assert(not visible.shown and opacity.shown, "an Opacity the player set stays, to be set back")

open(1, 100)
assert(visible.shown and not opacity.shown, "a viewer hidden by Blizzard's row keeps the row")

db.enabled = false
open(0, 100)
assert(visible.shown and opacity.shown and layouts == 0, "module off: Blizzard's dialog is left alone")
db.enabled = true

system.system = VIEWER + 1
open(0, 100)
assert(visible.shown and opacity.shown and layouts == 0, "another system's dialog is left alone")

-- Always after a fade (Visibility.lua, the fader's rebuild)
local giveBack = H.load([[
local applied
local function ApplyElementAlpha(_, _, alpha) applied = alpha end
return function(e, frame, key)
    applied = nil
    if not e.keepAlpha then
        applied = "reset"
    elseif e.faded then
]] .. H.section(H.read("Modules/Visibility.lua"), "-- Blizzard's own Opacity back", "if e.own then unitValues[key] = 1 end") .. [[
    return applied
end
]])
local asked
local function Viewer(value)
    return { GetSettingValue = function(_, setting)
        asked = setting
        if value == "error" then error("no value") end
        return value
    end }
end

local e = { keepAlpha = true, faded = true }
assert(giveBack(e, Viewer(60), "cdm_buffs") == 0.6, "Blizzard's Opacity is given back")
assert(asked == OPACITY and e.faded == nil, "once, from Blizzard's own setting")
assert(giveBack(e, Viewer(60), "cdm_buffs") == nil, "a viewer FlareUI never faded keeps the alpha it has")
assert(giveBack({ keepAlpha = true, faded = true }, Viewer("error"), "cdm_buffs") == 1, "no value: fully shown")
assert(giveBack({ keepAlpha = true, faded = true }, Viewer(0), "cdm_buffs") == 1, "never left invisible")
print("PASS: Cooldown Manager Edit Mode rows and Opacity given back")
