-- Run from the repository root: luajit tools/tests/unitframes-dragon.lua
-- The elite / rare / boss dragon on Addon Style frames (Modules/UnitFramesDragon.lua): which dragon a
-- unit gets, how its pieces fill a frame's end at any height, on either side, and that the art files
-- match the numbers.
local SECRET = setmetatable({}, { __tostring = function() return "secret" end })

local unit = { classification = "normal", boss = false }
local env = setmetatable({
    UnitClassification = function() return unit.classification end,
    UnitIsBossMob = function() return unit.boss end,
    canaccessvalue = function(v) return v ~= SECRET end,
}, { __index = _G })

-- a frame double: textures record their points, size, coords and texture
local function newTexture()
    local t = { shown = false }
    function t:SetSnapToPixelGrid() end
    function t:SetTexelSnappingBias() end
    function t:SetTexture(file) self.file = file end
    function t:ClearAllPoints() self.point = nil end
    function t:SetPoint(p, rel, rp, x, y) self.point = { p, rel, rp, x, y } end
    function t:SetTexCoord(l, r, top, bottom) self.coords = { l, r, top, bottom } end
    function t:SetSize(w, h) self.w, self.h = w, h end
    function t:Show() self.shown = true end
    function t:Hide() self.shown = false end
    function t:IsShown() return self.shown end
    return t
end
local function newFrame(height)
    local f = { height = height, scripts = {} }
    function f:CreateTexture() return newTexture() end
    function f:GetHeight() return self.height end
    function f:HookScript(event, fn) self.scripts[event] = fn end
    function f:Resize(h) self.height = h; self.scripts.OnSizeChanged(self) end
    return f
end

local ns = {}
local chunk = assert(loadfile("Modules/UnitFramesDragon.lua"))
setfenv(chunk, env)
chunk("FlareUI", ns)
local Dragon = ns.UFDragon

-- 1. which dragon: Forever's choice (winged gold boss, silver rare, gold elite)
local function kind(classification, boss)
    unit.classification, unit.boss = classification, boss
    return Dragon.Kind("target")
end
assert(kind("elite", false) == "Elite")
assert(kind("elite", true) == "Boss", "a boss mob gets the winged dragon")
assert(kind("worldboss", false) == "Boss")
assert(kind("rare", false) == "Rare" and kind("rareelite", false) == "Rare")
assert(kind("normal", false) == nil and kind("trivial", false) == nil)
assert(kind(SECRET, false) == nil, "a hidden classification shows nothing")
assert(kind("elite", SECRET) == "Elite", "a hidden boss flag falls back to the classification")
assert(Dragon.SampleKind("worldboss") == "Boss" and Dragon.SampleKind("rareelite") == "Rare"
    and Dragon.SampleKind("elite") == "Elite" and Dragon.SampleKind("normal") == nil)

local function near(a, b) return math.abs(a - b) < 1e-6 end
local function bottom(t) return t.point[5] - t.h end

-- 2. the pieces fill the frame's end without gaps: top, seg, run tiles, bot, frame edges where the art says
local function check(f, height, side)
    local d, art = f.FUIDragon, Dragon.ART[f.FUIDragon.kind]
    local u, v, tuck, tuckBottom = Dragon.Fit(art, height)
    assert(near(d.top.point[5], art.frameTop * v - tuck), "the head sits on the frame's top border")
    assert(near(d.top.h, (art.top[2] - art.top[1]) * v) and near(d.top.w, art.w * u), "squished flatter, not narrower")
    assert(near(bottom(d.top), d.seg.point[5]), "seg right under top")
    local y = bottom(d.seg)
    for _, t in ipairs(d.run) do
        if t.shown then
            assert(near(t.point[5], y), "run tiles one under the other")
            assert(t.h <= (art.run[2] - art.run[1]) * v + 1e-6)
            assert(near(t.coords[3], art.run[1] / 256) and near((t.coords[4] - t.coords[3]) * 256 * v, t.h),
                "a cut tile shows only its top rows")
            y = bottom(t)
        end
    end
    assert(near(y, d.bot.point[5]), "the run ends where the tail starts")
    assert(near(d.bot.point[5], -height + art.frameBottom * v + tuckBottom), "the tail on the frame's bottom border")
    for _, t in ipairs({ d.top, d.seg, d.bot }) do
        assert(t.shown and t.file == "Interface\\AddOns\\FlareUI\\Media\\Frames\\Dragon" .. d.kind .. ".tga")
        if side == "RIGHT" then
            assert(t.point[1] == "TOPLEFT" and t.point[3] == "TOPRIGHT" and near(t.point[4], -art.outer * u - Dragon.PULL))
            assert(t.coords[1] == 0 and t.coords[2] > 0, "the art as drawn on the right")
        else
            assert(t.point[1] == "TOPRIGHT" and t.point[3] == "TOPLEFT" and near(t.point[4], art.outer * u + Dragon.PULL))
            assert(t.coords[1] > 0 and t.coords[2] == 0, "mirrored on the left")
        end
    end
    return u, v, tuck, tuckBottom
end

local target = { Overlay = newFrame(60) }
Dragon.Set(target, "Elite", "RIGHT")
local u, v, tuck, tuckBottom = check(target, 60, "RIGHT")
assert(near(u * 2, 60 / Dragon.SCALE.HEIGHT), "the target's default height picks its scale by height")
assert(near(v, u * Dragon.SQUISH) and tuck == Dragon.TUCK and tuckBottom == Dragon.TUCK_BOTTOM,
    "a 60 px frame: squished and tucked in full")
local tiles = 0
for _, t in ipairs(target.FUIDragon.run) do if t.shown then tiles = tiles + 1 end end
assert(tiles > 0, "a 60 px frame needs some plain body")

-- taller: more tiles, the same pieces; the frame's own size change lays it out again
target.Overlay:Resize(110)
check(target, 110, "RIGHT")
local more = 0
for _, t in ipairs(target.FUIDragon.run) do if t.shown then more = more + 1 end end
assert(more > tiles, "a taller frame gets a longer body")

-- each kind, both sides, a boss tile's height
for _, k in ipairs({ "Elite", "Rare", "Boss" }) do
    for _, side in ipairs({ "RIGHT", "LEFT" }) do
        local f = { Overlay = newFrame(70) }
        Dragon.Set(f, k, side)
        check(f, 70, side)
    end
end

-- a short frame: no tuck, and the dragon shrinks below its least scale so head and tail still meet, no body tiles
local small = { Overlay = newFrame(20) }
Dragon.Set(small, "Boss", "LEFT")
check(small, 20, "LEFT")
for _, t in ipairs(small.FUIDragon.run) do assert(not t.shown) end

-- off: every piece hidden; a size change then does nothing
Dragon.Set(target, nil)
local d = target.FUIDragon
assert(not d.top.shown and not d.seg.shown and not d.bot.shown and d.kind == nil)
for _, t in ipairs(d.run) do assert(not t.shown) end
target.Overlay:Resize(80)
assert(not d.top.shown, "a hidden dragon stays hidden on resize")
Dragon.Set({ Overlay = newFrame(60) }, nil)   -- never shown: nothing to hide, no error

-- 3. the art: each file is 256 x 256, 32-bit, and holds the pieces the numbers name
for k, art in pairs(Dragon.ART) do
    local fh = assert(io.open("Media/Frames/Dragon" .. k .. ".tga", "rb"))
    local head = fh:read(18)
    local body = fh:read("*a")
    fh:close()
    local w = head:byte(13) + head:byte(14) * 256
    local h = head:byte(15) + head:byte(16) * 256
    assert(w == 256 and h == 256 and head:byte(17) == 32, k .. " is 256 x 256 RGBA")
    assert(art.w <= 256 and art.run[2] <= 256 and art.top[2] == art.seg[1])
    -- a row (counted from the top; the file is stored bottom-up) has some art in it
    local function rowHasArt(row)
        local base = (255 - row) * 256 * 4
        for x = 0, 255 do if body:byte(base + x * 4 + 4) > 0 then return true end end
        return false
    end
    for _, piece in ipairs({ "top", "seg", "bot", "run" }) do
        local r = art[piece]
        local any = false
        for row = r[1], r[2] - 1 do any = any or rowHasArt(row) end
        assert(any, k .. " " .. piece .. " rows hold art")
    end
end

print("PASS: unit frame dragon kinds, layout on both sides at any height, and its art files")
