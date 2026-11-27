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
assert(player.Portrait.ringMasked and player.RingFrame.Art:GetTexture():find("Frames.Ring"))
assert(player.RaidIcon:GetParent() == player.RingFrame.Icons)
assert(player.Health.barColor[2] > player.Health.barColor[1], "preview can demonstrate the ordinary health colour")

local forever = assert(UF.DrawSample(player, "forever", { preset = true }))
assert(forever.left > 0 and player.PlateFrame:IsShown())
assert(not player.Border:IsShown() and player.RingFrame.hasArt)
assert(player.Name:GetPoint() == "LEFT" and player.btStyle == "plate")
assert(player.HealthTextMid:GetText():find("24000", 1, true), "Forever preview puts the maximum in the central health text")
assert(#player.PlateFrame.pieces == 28 and not player.PlateFrame.Strip:IsShown())
-- (11-25) the rims are in front of the bars and behind the texts, over each slot's wood
do
    local plate, level = player.PlateFrame, player:GetFrameLevel()
    assert(plate.Front:GetFrameLevel() == level + 4 and player.Health:GetFrameLevel() < level + 4
        and player.Overlay:GetFrameLevel() > level + 4, "bars, rims, texts")
    for _, piece in ipairs(plate.pieces) do
        assert(piece.parent == plate.Front and piece:GetTexture():find("Frames.Plate"))
        for _, uv in ipairs({ piece:GetTexCoord() }) do assert(uv >= 0 and uv <= 1) end
    end
    local function box(region)
        local t = {}
        for i = 1, region:GetNumPoints() do
            local point, _, _, x, y = region:GetPoint(i)
            t[point] = { x, y }
        end
        return t.TOPLEFT[1], t.TOPLEFT[2], t.BOTTOMRIGHT[1], t.BOTTOMRIGHT[2]
    end
    for i, bar in ipairs({ player.Health, player.Power }) do
        local a, b = { box(bar) }, { box(plate.backs[i + 1]) }
        for k = 1, 4 do assert(a[k] == b[k], "the wood is as big as its bar") end
        assert(plate.backs[i + 1]:IsShown())
    end
    assert(plate.backs[1]:IsShown() and not plate.backs[4]:IsShown(), "no second power slot")
end
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

-- (11-25) The portrait, its dark disc, the tint and the bars' hole are centred on the painted ring, which is
-- not the ring box's middle: further out from the bars and lower, mirrored with the ring. The portrait's
-- edge stays under the rim (the painted opening is 26.2 art pixels in radius, the rim ends at 32.3).
for _, style in ipairs({ "flareui", "forever" }) do
    for _, f in ipairs({ player, target }) do
        assert(UF.DrawSample(f, style, { preset = true }))
        local ring = f.RingFrame
        local art = ring:GetWidth() / 61.8
        local point, relative, relPoint, x, y = ring.Centre:GetPoint()
        local out = Ring.Side(f) == "LEFT" and -1 or 1
        assert(point == "CENTER" and relative == ring and relPoint == "CENTER" and ring.Centre:GetWidth() == ring:GetWidth())
        assert(math.abs(x - out * Ring.PAINTED.out * art) < 0.01 and math.abs(y + Ring.PAINTED.down * art) < 0.01, style)
        for _, region in ipairs({ f.Portrait, ring.PortraitBack, ring.TintMask }) do
            local p, rel, rp, rx, ry = region:GetPoint()
            assert(p == "CENTER" and rel == ring.Centre and rp == "CENTER" and (rx or 0) == 0 and (ry or 0) == 0)
        end
        local radius = f.Portrait:GetWidth() / 2 / art
        assert(radius > 26.2 and radius < 32.3, "the rim covers the portrait's edge")
        assert(ring.TintMask:GetWidth() / 2 / art >= 32.3, "the tint reaches the rim's outer edge")
        -- the ring's own picture, on the same centre: flipped with the side, 128 art pixels wide
        assert(select(2, ring.Art:GetPoint()) == ring.Centre and math.abs(ring.Art:GetWidth() / art - 128) < 0.01)
        local u1, u2 = ring.Art:GetTexCoord()
        assert((u1 > u2) == (out < 0), "flipped on the left")
        if style == "flareui" then
            -- the painted circle stands on the bars' middle, however far off it its elements are placed from
            local _, _, _, rx, ry = ring:GetPoint()
            assert(math.abs(ry + y) < 0.01, "level with the bars")
            local r, half = ring:GetWidth() / 2, f:GetHeight() / 2
            assert(math.abs((rx + x) * out - (math.sqrt(r * r - half * half) - 4)) < 0.01, "the bars' corners meet the rim")
        end
    end
end

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
-- (Malkkav 11-27) Edit Mode's box round the whole frame: the portrait (left, taller) and the level disc
-- (below) inside it; back on the frame outside Edit Mode
do
    local LEM = env.LibStub("FlareEditMode")
    local function Rect(l, r, t, b, shown)
        return { GetLeft = function() return l end, GetRight = function() return r end, GetTop = function() return t end,
            GetBottom = function() return b end, IsShown = function() return shown ~= false end }
    end
    local f = Rect(100, 340, 500, 448)
    f.RingFrame = Rect(0, 0, 0, 0)
    f.RingFrame.Hit = Rect(40, 110, 515, 445)         -- the portrait, left of the bars and taller
    f.RingFrame.DiscHit = Rect(60, 84, 452, 428)      -- the level disc, under it
    local points, all
    local selection = { ClearAllPoints = function() points, all = {}, nil end,
        SetPoint = function(_, ...) points[#points + 1] = { ... } end, SetAllPoints = function(_, to) all = to end }
    local frames, editing, saved = LEM.frameSelections, LEM.IsInEditMode, nil
    LEM.frameSelections = { [f] = selection }
    LEM.IsInEditMode = function() return true end
    Ring.FitSelection(f)
    assert(points[1][1] == "TOPLEFT" and points[1][4] == -60 and points[1][5] == 15, "out to the portrait's left and top")
    assert(points[2][1] == "BOTTOMRIGHT" and points[2][4] == 0 and points[2][5] == -20, "down to the disc's bottom")
    LEM.IsInEditMode = function() return false end
    Ring.FitSelection(f)
    assert(all == f and #points == 0, "outside Edit Mode: on the frame alone")
    LEM.frameSelections, LEM.IsInEditMode = frames, editing
end

print("PASS: unit frame previews render all three styles and style switching preserves each setup")
