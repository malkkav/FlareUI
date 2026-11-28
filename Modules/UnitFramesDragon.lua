local ADDON, ns = ...

-- The elite / rare / boss dragon on Modern (Addon Style) frames: target, focus and the boss tiles.
-- It replaces the Elite & Rare skull there (the ring styles have Blizzard's own dragon round the
-- portrait). Blizzard's art (sheet 8244544) bent square by Development/Tools/unit-frame-art/dragons.js:
-- head on the frame's top edge, body down its outer end, tail under its bottom edge.
--
-- Each file holds four pieces (texel rows, [first, past-last]): top (head, neck, top corner), seg
-- (the straight stretch with the wing), bot (bottom corner and tail) and run (plain body, repeated
-- between seg and bot to fill the frame's height). Nothing is stretched; the dragon's size follows the
-- frame's height.
local Dragon = {}
ns.UFDragon = Dragon

local PATH = "Interface\\AddOns\\FlareUI\\Media\\Frames\\Dragon"
local SIZE = 256   -- the files are SIZE x SIZE texels
-- from dragons.js: w = art width, outer = the texel column on the frame's outer edge, frameTop = the
-- frame's top edge in the top piece, frameBottom = its bottom edge in the bot piece
Dragon.ART = {
    Elite = { w = 211, outer = 117, top = { 1, 67 }, seg = { 67, 124 }, bot = { 126, 195 }, run = { 197, 226 }, frameTop = 47.3, frameBottom = 19 },
    Rare = { w = 215, outer = 121, top = { 1, 53 }, seg = { 53, 109 }, bot = { 111, 175 }, run = { 177, 205 }, frameTop = 33, frameBottom = 19 },
    Boss = { w = 211, outer = 117, top = { 1, 61 }, seg = { 61, 116 }, bot = { 118, 179 }, run = { 181, 208 }, frameTop = 40.8, frameBottom = 19 },
}
-- UI px the body sits over the frame's edge: the border's bronze line is drawn 1.5 px inside it
-- (FlareUI Thick: 1 px inset, half a px clear), so this closes the gap (Malkkav 11-26)
Dragon.PULL = 2
-- the art's scale (1 = Blizzard's size) by frame height: HEIGHT px tall frames get MAX, small ones
-- no less than MIN (a frame too short for the pieces shrinks it further)
Dragon.SCALE = { HEIGHT = 90, MIN = 0.45, MAX = 0.75 }
-- squished flatter (its height times SQUISH) and the head and tail TUCK px further in over the frame's
-- top and bottom borders, so less of it sticks out over auras and the cast bar (Malkkav 11-26)
Dragon.SQUISH = 0.8
Dragon.TUCK = 3
-- the tail further still, so its feet sit over the whole bottom border (Malkkav 11-26)
Dragon.TUCK_BOTTOM = 7

-- Which dragon a unit gets, as Forever picks it (TargetFrameUtils.lua GetBossPortraitFrameData): winged
-- gold for a boss, silver for a rare, gold for an elite
function Dragon.Kind(unit)
    if not unit then return nil end
    local c = UnitClassification(unit)
    if not canaccessvalue(c) then return nil end
    local boss = UnitIsBossMob and UnitIsBossMob(unit)
    if (canaccessvalue(boss) and boss) or c == "worldboss" then return "Boss" end
    if c == "rare" or c == "rareelite" then return "Rare" end
    if c == "elite" then return "Elite" end
    return nil
end

-- The sample boss tiles' classification ("worldboss", "elite", ...)
function Dragon.SampleKind(classification)
    if classification == "worldboss" then return "Boss" end
    if classification == "rare" or classification == "rareelite" then return "Rare" end
    if classification == "elite" then return "Elite" end
    return nil
end

local function NewPiece(host)
    -- under the frame's texts and icons (OVERLAY on the same frame), over its border
    local t = host:CreateTexture(nil, "ARTWORK", nil, -8)
    t:SetSnapToPixelGrid(false)
    t:SetTexelSnappingBias(0)
    t:Hide()
    return t
end

local function Holder(f)
    local d = f.FUIDragon
    if d then return d end
    local host = f.Overlay or f
    d = { host = host, top = NewPiece(host), seg = NewPiece(host), bot = NewPiece(host), run = {} }
    f.FUIDragon = d
    host:HookScript("OnSizeChanged", function()
        if d.kind then Dragon.Layout(f) end
    end)
    return d
end

-- One piece: rows r0..r1 of the file, its top y (UI px, from the frame's top, up is +) and height
local function Place(tex, d, art, r0, r1, y, h, u)
    -- (u: across, UI px per texel; the height h comes in already squished)
    local host, right = d.host, d.side == "RIGHT"
    tex:ClearAllPoints()
    local width = art.w * u
    if right then
        tex:SetPoint("TOPLEFT", host, "TOPRIGHT", -art.outer * u - Dragon.PULL, y)
        tex:SetTexCoord(0, art.w / SIZE, r0 / SIZE, r1 / SIZE)
    else
        tex:SetPoint("TOPRIGHT", host, "TOPLEFT", art.outer * u + Dragon.PULL, y)
        tex:SetTexCoord(art.w / SIZE, 0, r0 / SIZE, r1 / SIZE)
    end
    tex:SetSize(width, h)
    tex:Show()
end

function Dragon.Scale(height)
    local s = Dragon.SCALE
    return math.max(s.MIN, math.min(s.MAX, height / s.HEIGHT))
end

-- UI px per texel across (u) and down (v) for a frame this tall, and how far the head and the tail
-- tuck in
function Dragon.Fit(art, height)
    -- (the art has two texels per px at scale 1)
    local u = Dragon.Scale(height) / 2
    local v, tuck, tuckBottom = u * Dragon.SQUISH, Dragon.TUCK, Dragon.TUCK_BOTTOM
    local topH, segH = art.top[2] - art.top[1], art.seg[2] - art.seg[1]
    local need = (topH - art.frameTop) + segH + art.frameBottom
    -- a frame too short for the pieces: less tuck (both in step), then smaller
    local room = height - need * v
    if tuck + tuckBottom > room then
        local k = math.max(0, room) / (tuck + tuckBottom)
        tuck, tuckBottom = tuck * k, tuckBottom * k
    end
    if need * v > height then
        local k = height / (need * v)
        u, v = u * k, v * k
    end
    return u, v, tuck, tuckBottom
end

function Dragon.Layout(f)
    local d = f.FUIDragon
    if not (d and d.kind) then return end
    local art = Dragon.ART[d.kind]
    local height = d.host:GetHeight()
    if not (canaccessvalue(height) and height and height > 0) then return end
    -- (the same dragon on the same size: nothing to redo)
    if d.laidKind == d.kind and d.laidSide == d.side and d.laidHeight == height then return end
    d.laidKind, d.laidSide, d.laidHeight = d.kind, d.side, height
    local u, v, tuck, tuckBottom = Dragon.Fit(art, height)
    local topH, segH = art.top[2] - art.top[1], art.seg[2] - art.seg[1]
    local file = PATH .. d.kind .. ".tga"
    for _, t in ipairs({ d.top, d.seg, d.bot }) do t:SetTexture(file) end

    local y = art.frameTop * v - tuck
    Place(d.top, d, art, art.top[1], art.top[2], y, topH * v, u)
    y = y - topH * v
    Place(d.seg, d, art, art.seg[1], art.seg[2], y, segH * v, u)
    y = y - segH * v
    local botTop = -height + art.frameBottom * v + tuckBottom
    Place(d.bot, d, art, art.bot[1], art.bot[2], botTop, (art.bot[2] - art.bot[1]) * v, u)

    -- the run, tile by tile from the seg down to the bot (the last one cut short)
    local tileRows = art.run[2] - art.run[1]
    local tileH = tileRows * v
    local left = y - botTop
    local i = 0
    while left > 0.05 do
        i = i + 1
        local t = d.run[i]
        if not t then
            t = NewPiece(d.host)
            d.run[i] = t
        end
        t:SetTexture(file)
        local h = math.min(tileH, left)
        Place(t, d, art, art.run[1], art.run[1] + h / v, y, h, u)
        y, left = y - h, left - h
    end
    for j = i + 1, #d.run do d.run[j]:Hide() end
end

-- Show a dragon on the frame's outer end ("RIGHT" or "LEFT"), or none (kind nil)
function Dragon.Set(f, kind, side)
    if not f then return end
    if not kind then
        local d = f.FUIDragon
        if d and d.kind then
            d.kind, d.laidKind = nil, nil
            d.top:Hide(); d.seg:Hide(); d.bot:Hide()
            for _, t in ipairs(d.run) do t:Hide() end
        end
        return
    end
    local d = Holder(f)
    d.kind, d.side = kind, side == "LEFT" and "LEFT" or "RIGHT"
    Dragon.Layout(f)
end
