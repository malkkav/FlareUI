-- Run from the repository root: luajit tools/tests/unitframes-two-slots.lua
-- Mana on Shapeshift in Forever Style: the mana bar sits in the plate's second power slot, which hangs below
-- the frame, and what is under the frame makes room (11-23).
local db = {
    styleStart = true, frameFontsSeeded = true, castTimeSeeded = true,
    units = { player = { enabled = true, width = 240, height = 52, powerHeight = 12, showLevel = true, portrait = "class",
        shiftMana = true, castbarPosition = "BOTTOM" } },
    layouts = { Main = {} }, party = { size = {}, auras = {}, enabled = false }, boss = { enabled = true },
}
local ui, ns = dofile("tools/tests/fixtures/unitframes-ui.lua")(db)
local env = ui.env
local UF, Ring = ns.UnitFrames, ns.UFRing
local power, missing = 3, false
local TWO = "UI-HUD-UnitFrame-Player-PortraitOn-ClassResource"
env.Enum = env.Enum or {}
env.Enum.PowerType = env.Enum.PowerType or { Mana = 0 }
env.UnitPowerType = function() return power end
ns.EditPreviewing = function() return false end
local info = env.C_Texture.GetAtlasInfo
env.C_Texture.GetAtlasInfo = function(atlas)
    if atlas == TWO then
        if missing then return nil end
        return { width = 198, height = 74, file = "Two", leftTexCoord = 0, rightTexCoord = 1, topTexCoord = 0, bottomTexCoord = 1 }
    end
    return info(atlas)
end

Ring.SetStyle("forever")
assert(Ring.Style() == "forever")
db.units.player.shiftMana, db.units.player.castbarPosition = true, "BOTTOM"
local f = UF.CreateSample(env.UIParent, "player")
f.ShiftMana = UF.Kit.CreateBar(f, 2)
f.ShiftMana:Hide()
f.ShiftManaSeparator = f.Overlay:CreateTexture()
f.ShiftManaText, f.ShiftManaTextLeft, f.ShiftManaTextMid = UF.NewText(f.Overlay), UF.NewText(f.Overlay), UF.NewText(f.Overlay)
local function draw() return assert(UF.DrawSample(f, "forever")) end

-- a druid in Cat or Bear Form
draw()
local plate = f.PlateFrame
assert(#plate.pieces == 30 and #plate.glow == 30 and plate.underFrom == 28)
assert(f.ShiftMana:IsShown() and not f.ShiftManaSeparator:IsShown(), "the plate has its own divider")
assert(f.Power:IsShown() and f.Power.barTexture ~= false)
local drop = Ring.PlateDrop(f)
assert(drop > 0 and drop == f.plateDrop)
for i = 25, 30 do assert(plate.pieces[i]:GetTexture() == "Two" and plate.pieces[i]:IsShown(), i) end
assert(plate.pieces[24]:GetTexture() ~= "Two", "the rows above are the plate's own")
for i = 25, 30 do assert(plate.glow[i]:GetTexture() == "Two") end
assert(plate.pieces[30].masks[plate.UnderMask] and plate.glow[30].masks[plate.UnderMask] and not (plate.pieces[29].masks or {})[plate.UnderMask])
-- its y in that art: 55 to 74 of 74
local u1, u2, v1, v2 = plate.pieces[25]:GetTexCoord()
assert(math.abs(v1 - 55 / 74) < 0.0001 and math.abs(v2 - 1) < 0.0001)
-- the ring is on the left: that art as it is (mirrored twice)
assert(u1 < u2, "not mirrored")
-- the last piece ends as far below the frame as the slot reaches
local function bottom(region)
    for i = 1, region:GetNumPoints() do
        local point, _, relative, _, y = region:GetPoint(i)
        if point == "BOTTOMRIGHT" then return relative, y end
    end
end
local relative, y = bottom(plate.pieces[26])
assert(relative:find("^BOTTOM") and y < -drop and y > -drop * 1.4, "the edge's shadow past the slot")
local _, slotBottom = bottom(f.ShiftMana)
local _, powerBottom = bottom(f.Power)
assert(powerBottom > 0 and slotBottom < 0 and slotBottom > -drop, "power in the frame, mana below it")

-- the cast bar and the auras under the frame make room, in a fight too
local cast = env.CreateFrame("StatusBar", nil, f)
cast:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 5, -4)
cast:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", -5, -4)
f.Cast = cast
f.plateDropUsed = nil
UF.PlateDropChanged(f)
assert(select(5, cast:GetPoint(1)) == -4 - drop and select(4, cast:GetPoint(1)) == 5 and select(5, cast:GetPoint(2)) == -4 - drop)
assert(f.plateDropUsed == drop)
cast:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 5, -99)
UF.PlateDropChanged(f)
assert(select(5, cast:GetPoint(1)) == -99, "nothing changed: left alone")
f.Cast = nil

assert(math.abs(Ring.PlateReserve(f) - drop) < 0.001, "the room kept for what cannot move in a fight")
-- back in caster form: the plate is whole again
ui.combat, power = true, 0
draw()
assert(not f.ShiftMana:IsShown() and Ring.PlateDrop(f) == 0)
assert(plate.pieces[25]:GetTexture() ~= "Two" and plate.pieces[29]:GetTexture() == nil and plate.glow[30]:GetTexture() == nil)
assert(f.plateDropUsed == 0, "in a fight too")
ui.combat = false

-- a Power Height of Off keeps the mana slot
power = 3
db.units.player.platePower = 0
draw()
assert(not f.Power:IsShown() and f.ShiftMana:IsShown())
db.units.player.platePower = nil

-- a client without the art: no slot
missing = true
draw()
assert(not f.ShiftMana:IsShown() and Ring.PlateDrop(f) == 0 and Ring.PlateReserve(f) == 0)
missing = false

-- off the plate: the strip inside the frame, and nothing hangs below
draw()
UF.DrawSample(f, "addon")
assert(f.ShiftMana:IsShown() and Ring.PlateDrop(f) == 0 and not plate:IsShown())

-- /fui druidbar: the same on a class without it, nothing saved
ns.UnitShownLevel = function() return 43 end
ns.UnitLevelColor = function() end
ns.SetHighLevelText = function() end
env.UnitAffectingCombat = env.UnitAffectingCombat or function() end
env.IsResting = env.IsResting or function() end
env.UnitThreatSituation = env.UnitThreatSituation or function() end
local said = {}
env.print = function(text) said[#said + 1] = text end
db.units.player.shiftMana = nil
power = 0
UF.PlayerFrame = function() end
UF.ShiftManaTest()
assert(said[1]:find("is off", 1, true) and not UF.shiftTest)
local other = UF.CreateSample(env.UIParent, "player")
other.fuiSample = nil
UF.PlayerFrame = function() return other end
local redrawn = 0
UF.Redraw = function(frame)
    redrawn = redrawn + 1
    frame.fuiSample = true
    assert(UF.DrawSample(frame, "forever"))
    frame.fuiSample = nil
end
ui.combat = true
UF.ShiftManaTest()
assert(not other.ShiftMana and not UF.shiftTest, "made out of a fight")
ui.combat = false
UF.ShiftManaTest()
assert(redrawn == 1 and other.ShiftMana and other.shiftTestOnly and UF.shiftTest)
assert(other.ShiftMana:IsShown() and other.ShiftMana:GetValue() == 0.7 and Ring.PlateDrop(other) > 0 and Ring.PlateReserve(other) > 0)
assert(other.ShiftManaText:GetText() ~= nil and db.units.player.shiftMana == nil)
-- off and on again in a fight, as shifting is
ui.combat = true
UF.ShiftManaTest()
assert(not other.ShiftMana:IsShown() and Ring.PlateDrop(other) == 0 and not UF.shiftTest)
UF.ShiftManaTest()
assert(other.ShiftMana:IsShown() and redrawn == 1)
ui.combat = false
UF.ShiftManaTest()
-- a druid's saved option means nothing on this class, whatever its power
db.units.player.shiftMana, power = true, 1
UF.UpdateShiftMana(other)
assert(not other.ShiftMana:IsShown())
print("PASS: Mana on Shapeshift in Forever Style has the plate's second power slot, below the frame")
