-- A pet without a saved power height shows its resource bar; saved choices win.
-- Both halves run whole files: Core.lua for its defaults, UnitFrames.lua for the frame's layout.

-- Core.lua's defaults, as it hands them to the saved-settings library when FlareUI loads
local defaults
local ui = dofile("tools/tests/fixtures/core.lua")(nil, function(env)
    local editMode = { IsInEditMode = function() return false end, SettingType = { Dropdown = 1, Checkbox = 2 } }
    local db = { New = function(_, _, given) defaults = given error("stop here: only the defaults are wanted") end }
    env.LibStub = function(name)
        if name == "AceDB-3.0" then return db end
        return name == "FlareEditMode" and editMode or {}
    end
    env.DEFAULT_CHAT_FRAME = { AddMessage = function() end }
end)
ui:emit("ADDON_LOADED", "FlareUI")
local petDefaults = assert(defaults and defaults.profile.unitframes.units.pet, "Core.lua hands over its defaults")

-- The pet frame laid out with its saved settings over those defaults (the library's way)
local function layout(savedHeight)
    local saved = {}
    if savedHeight ~= nil then saved.powerHeight = savedHeight end
    setmetatable(saved, { __index = petDefaults })
    local frames, ns = dofile("tools/tests/fixtures/unitframes-ui.lua")({
        styleStart = true, frameFontsSeeded = true, castTimeSeeded = true,
        units = { pet = saved }, layouts = { Main = {} }, party = { size = {}, auras = {}, enabled = false },
    })
    ns.EditPreviewing = function() return false end
    local f = ns.UnitFrames.CreateSample(frames.env.UIParent, "pet")
    assert(ns.UnitFrames.DrawSample(f, "addon"))
    return f.Power
end

local default = layout()
assert(default:IsShown() and default:GetHeight() == 8, "default pet resource bar must be visible at height 8")
local hidden = layout(0)
assert(not hidden:IsShown(), "a saved height of 0 must keep the pet resource bar hidden")
local custom = layout(13)
assert(custom:IsShown() and custom:GetHeight() == 13, "a saved pet resource bar height must be kept")
print("PASS: pet power bar defaults to height 8 and keeps saved heights")
