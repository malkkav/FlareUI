local db = {
    styleStart = true, frameFontsSeeded = true, castTimeSeeded = true,
    simplePet = false, simpleTargetOf = true,
    units = {
        player = { enabled = true, width = 240, height = 52, powerHeight = 12, showLevel = true, portrait = "class" },
        target = { enabled = false, width = 210, height = 48, powerHeight = 0, mirror = true, portrait = "none" },
        pet = { enabled = true, width = 90 },
    },
    layouts = { Main = {} },
    party = { size = {}, auras = {}, enabled = false },
    boss = { enabled = true },
}
local ui, ns = dofile("tools/tests/fixtures/unitframes-ui.lua")(db)
local env = ui.env
local UF, Ring = ns.UnitFrames, ns.UFRing
assert(not UF.CreateSample(env.UIParent, "missing"))

-- All three preview cards use the real geometry and may be drawn in a fight. Saved settings
-- remain untouched, including explicit zero power, while preview-only scale and masks change.
local player = UF.CreateSample(env.UIParent, "player")
local target = UF.CreateSample(env.UIParent, "target")
local pet = UF.CreateSample(env.UIParent, "pet")
local addon = assert(UF.DrawSample(player, "addon"))
assert(addon.width == 240 and addon.height == 52 and addon.left == 0)
assert(player.Power:IsShown() and player.HealthText:GetText() ~= "" and player.Name:GetText() == "Juniper Vale")
assert(player.Portrait:IsShown() and player.Portrait.Tex:GetAtlas())
assert(UF.DrawSample(target, "addon").width == 210 and not target.Power:IsShown())
assert(target.Health:GetReverseFill() and not target.Portrait:IsShown())

ui.combat = true
local flare = assert(UF.DrawSample(player, "flareui", { preset = true, noClassColor = true }))
assert(flare.left > 0 and flare.top > 0 and player.RingFrame:IsShown())
assert(player.Portrait.ringMasked and player.RingFrame.artMasked)
assert(player.RaidIcon:GetParent() == player.RingFrame.Icons)
assert(player.Health.barColor[2] > player.Health.barColor[1], "preview can demonstrate the ordinary health colour")

local forever = assert(UF.DrawSample(player, "forever", { preset = true }))
assert(forever.left > 0 and player.PlateFrame:IsShown())
assert(not player.Border:IsShown() and not player.RingFrame.artMasked)
assert(player.Name:GetPoint() == "LEFT" and player.btStyle == "plate")
assert(player.HealthTextMid:GetText():find("24000", 1, true), "Forever preview puts the maximum in the central health text")
assert(#player.PlateFrame.pieces == 28 and not player.PlateFrame.Strip:IsShown())
-- (11-25) your own name box has no glow, with Class Colours on too
do
    local on, sample, unit = ns.ClassColorsOn, player.fuiSample, player.fuiUnit
    ns.ClassColorsOn = function() return true end
    player.fuiSample, player.fuiUnit = nil, "player"
    player.PlateFrame.Strip:Show()
    ns.UFRing.UpdatePlate(player)
    assert(not player.PlateFrame.Strip:IsShown())
    ns.ClassColorsOn, player.fuiSample, player.fuiUnit = on, sample, unit
end
assert(not db.units.player.plateScale and not db.units.player.classColor and not ns.UFSample)

assert(UF.DrawSample(player, "addon").width == 240)
assert(not player.PlateFrame:IsShown() and not player.RingFrame:IsShown() and not player.Portrait.ringMasked)
assert(player.Border:IsShown() and player.RaidIcon:GetParent() == player.Overlay)
assert(UF.DrawSample(pet, "addon").width == 90)

-- The happiness face beside the pet frame is as tall as the health bar, never smaller than before;
-- mid health bar it keeps its share of the bar.
pet.Happiness = env.CreateFrame("Frame", nil, pet)
local function faceHeight(style, barHeight, place)
    pet.Health.height = barHeight
    db.units.pet.icons = place and { happiness = { place = place } } or nil
    UF.DrawSample(pet, style)
    return pet.Happiness:GetHeight()
end
assert(faceHeight("addon", 27) == 27 and faceHeight("addon", 27, "LEFT") == 27)
assert(faceHeight("addon", 6) >= 14, "a thin bar keeps the least size")
local mid = faceHeight("addon", 27, "CENTER")
assert(mid == faceHeight("addon", 60, "CENTER"), "mid health bar follows the bar's set height")
db.units.pet.icons = nil
pet.Happiness = nil

-- Switching styles preserves per-frame enablement and shared settings while remembering the
-- frame sizes and pet positions for the setup that owns each of them.
db.layouts.Main.pet = { point = "BOTTOM", x = 12 }
db.resource = { enabled = true }
Ring.SetStyle("flareui")
assert(Ring.Style() == "flareui" and db.styleProfiles.usual.units.player.width == 240)
assert(db.units.player.enabled and not db.units.target.enabled and db.units.pet.enabled and db.resource.enabled)
assert(Ring.PetStyled() and not Ring.TargetOfStyled() and db.petSetup == "styled")
assert(db.units.pet.width ~= 90)
db.layouts.Main = { pet = { point = "TOP", x = 23 } }
db.units.player.width = 303
db.simplePet = true
assert(not Ring.PetStyled() and db.units.pet.width == 90)
db.simplePet = false
assert(Ring.PetStyled() and db.layouts.Main.pet.x == 23)

Ring.SetStyle("forever")
assert(Ring.Style() == "forever" and Ring.GetPlateScale("player") == 130)
Ring.SetPlateScale("player", 110)
assert(Ring.GetPlateScale("player") == 110 and db.units.player.ringSize == 68)
Ring.SetStyle("addon")
assert(Ring.Style() == "addon" and db.units.player.width == 240 and db.layouts.Main.pet.x == 12)
Ring.SetStyle("flareui")
assert(db.units.player.width == 303 and db.layouts.Main.pet.x == 23)
Ring.SetStyle("forever")
assert(Ring.GetPlateScale("player") == 110 and not db.units.target.enabled and db.resource.enabled)
print("PASS: unit frame previews render all three styles and style switching preserves each setup")
