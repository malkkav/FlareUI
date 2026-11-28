-- Run from the repository root: luajit tools/tests/unitframes-targetof-portrait.lua
-- Ring styles with Simple "Target Of" off: target of target and target of focus have a portrait, and their
-- Edit Mode dialogs offer Portrait (2D or Class Icon, as the other ring frames). The styled pet has none.
local db = {
    styleStart = true, frameFontsSeeded = true, castTimeSeeded = true,
    simplePet = false, simpleTargetOf = false,
    units = { player = { enabled = true }, target = { enabled = true }, targettarget = { enabled = true },
              focus = { enabled = true }, focustarget = { enabled = true }, pet = { enabled = true } },
    layouts = { Modern = {} }, party = { size = {}, auras = {}, enabled = false }, boss = { enabled = false },
}
local ui, ns = dofile("tools/tests/fixtures/unitframes-ui.lua")(db)
local env = ui.env
local UF, Ring = ns.UnitFrames, ns.UFRing
ns.OrderEditSettings = function() end
ns.EditPreviewing = function() return false end
local editMode = env.LibStub("FlareEditMode")
editMode.SettingType = { Slider = 1, Checkbox = 2, Dropdown = 3, Expander = 4 }
local settings = {}
function editMode:AddFrame() end
function editMode:AddFrameSettings(frame, rows) settings[frame] = rows end
function editMode:AddSelectionArea() end
function editMode:GetActiveLayoutName() return "Modern" end
function editMode:RegisterCallback() end
function editMode:Defer() return false end
function editMode:IsInEditMode() return false end
function UF:RegisterEvent() end
getmetatable(env.UIParent).UpdateHappiness = function() end   -- (the happiness face's game mixin)
-- no units exist: every unit query the frames' first update makes answers nothing
setmetatable(env, { __index = function(_, key)
    if _G[key] ~= nil then return _G[key] end
    if type(key) == "string" and (key:find("^Unit") or key:find("^Get") or key:find("^Is")) then return function() end end
end })
env.UnitExists = function() return false end
env.C_DurationUtil = { CreateDurationTextBinding = function() end, CreateDuration = function() return { SetTimeFromStart = function() end } end }
env.Enum = env.Enum or {}
env.Enum.PowerType = env.Enum.PowerType or { Mana = 0 }
env.Enum.StatusBarInterpolation = { Immediate = 0 }
env.Enum.StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 }
env.RegisterStateDriver = function(frame, attr, driver) frame:SetAttribute(attr, driver) end
env.UnregisterStateDriver = function(frame, attr) frame:SetAttribute(attr, nil) end
env.securecallfunction = function(func, ...) return func(...) end
env.canaccessallvalues = function() return true end
env.tContains = function(values, want) for _, v in ipairs(values) do if v == want then return true end end return false end
env.C_AddOns.DoesAddOnExist, env.C_AddOns.IsAddOnLoaded = function() return false end, function() return false end
env.GetNetStats = function() return 0, 0, 95, 120 end
env.PlayerFrame = env.CreateFrame("Frame", nil, env.UIParent)
env.TargetFrame = env.CreateFrame("Frame", nil, env.UIParent)
env.FocusFrame = env.CreateFrame("Frame", nil, env.UIParent)
env.PetFrame = env.CreateFrame("Frame", nil, env.UIParent)
env.TargetofFocusFrame = env.CreateFrame("Frame", nil, env.UIParent)
env.PlayerCastingBarFrame = env.CreateFrame("StatusBar", nil, env.UIParent)
env.PlayerBottomManagedFrameContainer = env.CreateFrame("Frame", nil, env.PlayerFrame)
ns.db.profile.auras = {}
ui:load("Modules/Auras.lua", ns)
Ring.SetStyle("forever")
assert(Ring.TargetOfStyled())
-- (Bar Effects, on in Forever Style since 11-28, read the health through a step curve: UF.LostCurve)
env.Enum.LuaCurveType = env.Enum.LuaCurveType or { Step = 1 }
env.UnitHealthPercent = env.UnitHealthPercent or function() return 1 end
env.C_CurveUtil = env.C_CurveUtil or { CreateCurve = function()
    return { SetType = function() end, AddPoint = function() end }
end }
UF:Init()

local function portrait(unit)
    local f = assert(UF:GetUnitButton(unit), unit)
    for _, row in ipairs(assert(settings[f], unit)) do
        if row.name == "Portrait" then return row end
    end
end
for _, unit in ipairs({ "targettarget", "focustarget" }) do
    local row = assert(portrait(unit), unit .. " has Portrait")
    local picks = {}
    row.generator(nil, { CreateRadio = function(_, text) picks[#picks + 1] = text end }, row)
    assert(#picks == 2 and picks[1] == "2D" and picks[2] == "Class Icon", unit .. ": 2D and Class Icon, no None")
    -- (11-28) a first switch to Forever Style gives Malkkav's setup: the class icon
    assert(row.get() == "class", unit .. ": Forever Style starts with the class icon")
    row.set("Modern", "3d")
    assert(db.units[unit].portrait == "3d" and row.get() == "3d")
    row.set("Modern", "class")
    assert(db.units[unit].portrait == "class" and row.get() == "class")
end
assert(not portrait("pet"), "the styled pet keeps its own portrait")
print("PASS: styled target of target and target of focus offer Portrait (2D, Class Icon)")
