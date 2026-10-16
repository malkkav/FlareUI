local _, ns = ...

--------------------------------------------------
-- FOREVER STYLE UNIT FRAMES
-- The default look of the player, target and focus frames: Forever's own bronze portrait ring beside
-- them instead of the square portrait (Unit Frames > Addon style frames switches to the plain look).
-- UnitFrames.lua asks this file at its layout points (bars, texts, cast bar, auras, icons, classic
-- combo points); everything else is the frames' own code.
--------------------------------------------------
local Ring = {}
ns.UFRing = Ring

--------------------------------------------------
-- 1. ART AND PLACEMENT
-- The ring is the game's atlas (UI-HUD-UnitFrame-*-PortraitOn), cropped to the ring and masked to its
-- outline, so the frame plate it is painted with stays out; FlareUI ships no Blizzard art.
--
-- Everything around the ring is placed as Blizzard places it: each element's anchor on Blizzard's
-- own frame (PlayerFrame.xml / TargetFrame.xml, a 232 x 100 frame), taken relative to Blizzard's ring
-- centre and scaled by our ring's size over Blizzard's; sizes are the game's atlas sizes, scaled
-- the same way. A frame whose ring is on its other side mirrors them. Everything on the portrait is
-- Blizzard's, in Blizzard's proportions: the level always shows, and combo points are always the gems.
--   * the level in Forever's dark disc, with the elite skull there for "??" units
--   * the PvP / faction crest beside the level disc (player, target)
--   * the leader crown, the raid marker on the portrait's top edge, the rare star or quest mark on its
--     bottom edge, the resting "zzz", the corner embellishment while resting and the swords in combat
--   * the status glow (yellow resting, red in combat), the threat flash, and the elite / rare frame
--
-- Each style keeps a whole unit frames setup of its own (SHARED_KEYS: what the two share); the switch
-- puts one away and brings the other back, then reloads.
--
-- Geometry, from the ring's diameter D and the frame's height H: the ring sits on the portrait side,
-- centred on the frame's middle; the frame's end tucks under it as Blizzard's plate does (the bars
-- start where their corners meet the rim). The ring is 1.5 x the frame's height unless Portrait Size says
-- otherwise.
--------------------------------------------------
local RING_UNITS = { player = true, target = true, focus = true }

-- the art: the atlas, and where its ring is inside it (fractions of the atlas, measured on the sheet
-- against its backing: the outer edge of the ring's soft shadow, the same on every side). The ring
-- is on the atlas's right; on the left it is mirrored. Since Forever's build of 2026-10-16 the
-- player's frame has the target's round ring too (the teardrop is gone), so all three share it.
local ART = {
    target = { atlas = "UI-HUD-UnitFrame-Target-PortraitOn", side = "RIGHT",
               box = { 252.78 / 384, 375.0 / 384, 1.67 / 134, 123.89 / 134 } },
}
ART.player = ART.target
ART.focus = ART.target
local CIRCLE_MASK   = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local SMALL_CIRCLE  = "UI-HUD-UnitFrame-SmallCircle"
local PORTRAIT_SHARE = 0.86   -- the portrait inside the ring, of its diameter
-- Blizzard's combo points around its target ring (Camelot ComboFrame.lua POINT_LAYOUT_DATA, in its
-- 61.1 px ring's units): an arc from just under 3 o'clock upwards, started higher while the PvP crest
-- shows; radius in the points' own scale, shift from the portrait's centre
local RING_COMBO = { radius = 66, start = -10, pvpStart = 2, step = 21, scale = 0.6, shift = { 2, 2 } }
local RING_SHARE    = 1.5     -- the ring's default diameter, of the frame's height
local BAR_INSET     = 4       -- UnitFrames' INSET: the bars start this far in from the frame's edge
local GLOW_SHARE    = 1.35    -- the glow textures' size, of the ring's diameter
-- the glows: FlareUI's own line over the ring's rim (white, tinted, a little transparent). Drawn for
-- GLOW_SHARE 1.35: change both together.
local GLOW_FILE = "Interface\\AddOns\\FlareUI\\Media\\Masks\\RingHaloCircle"

-- Blizzard's frames (1x, origin at the frame's top-left, y down negative): the ring's centre and
-- diameter as measured on the atlas, and every element's anchor. scale = the template's scale (the
-- art's size only; the anchor's offsets are the parent's). size = a fixed size where there is one.
-- pvp: the faction crest, placed off the level disc (centre offset and size in the level disc's
-- texture widths, as measured on Forever's frames when the crest had a disc), then moved as Blizzard
-- moved it (move, see PvPSpot). The player's and target's aren't mirror images.
local BLIZZ = {
    player = {
        -- the target's ring, mirrored (the 2026-10-16 player frame)
        centre = { 232 - 176.9, -47.9 }, D = 61.1, side = "LEFT",
        -- 1.5 px in from Blizzard's anchor (13, -93): matched to screenshots of the 2026-10-16 frames
        level   = { atlas = SMALL_CIRCLE, point = "BOTTOMLEFT", x = 14.5, y = -91.5, frame = "player" },
        pvp     = { dx = -0.435, dy = 0.46, share = 0.8, move = { 6, -11.6 } },   -- the target's, mirrored
        leader  = { atlas = "UI-HUD-UnitFrame-Player-Group-LeaderIcon", point = "TOPLEFT", x = 86, y = -10 },
        rest    = { size = 20, point = "TOPLEFT", x = 64, y = -6 },
        raidIcon = { size = 26, point = "CENTER", x = 53.8, y = -19 },   -- the target's spot, mirrored
        corner  = { atlas = "UI-HUD-UnitFrame-Player-PortraitOn-CornerEmbellishment", point = "TOPLEFT", x = 58.5, y = -53.5 },
        attack  = { atlas = "UI-HUD-UnitFrame-Player-CombatIcon", point = "TOPLEFT", x = 64, y = -62 },
        readyCheck = { size = 40, point = "CENTER", x = 53.8, y = -49.6 },   -- on the portrait
    },
    target = {
        centre = { 176.9, -47.9 }, D = 61.1, side = "RIGHT", boss = true,
        pvp     = { dx = 0.435, dy = 0.46, share = 0.8, move = { -6, -11.6 } },   -- the player's, mirrored
        leader  = { atlas = "UI-HUD-UnitFrame-Player-Group-LeaderIcon", point = "TOPRIGHT", x = 147, y = -8 },
        raidIcon = { size = 26, point = "CENTER", x = 177, y = -19 },
        classification = { atlas = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star", point = "CENTER", x = 177, y = -77 },
        quest   = { atlas = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Quest", point = "CENTER", x = 177, y = -77 },
        readyCheck = { size = 40, point = "CENTER", x = 176.9, y = -47.9 },  -- on the portrait, as the player's
    },
}
-- the target's level disc is the player's, mirrored, so the pair matches
BLIZZ.target.level = BLIZZ.player.level
BLIZZ.focus = {
    centre = BLIZZ.target.centre, D = BLIZZ.target.D, side = "RIGHT", boss = true,
    level = BLIZZ.target.level, raidIcon = BLIZZ.target.raidIcon,
    classification = BLIZZ.target.classification, readyCheck = BLIZZ.target.readyCheck,
}
local BLIZZ_FRAME_W = 232   -- Blizzard's target frame width (the elite frame anchors to its right edge)
local SKULL = "UI-HUD-UnitFrame-Target-HighLevelTarget_Icon"
local PVP_ICONS = {
    Horde = "UI-HUD-UnitFrame-SmallCircle-Horde",
    Alliance = "UI-HUD-UnitFrame-SmallCircle-Alliance",
    FFA = "UI-HUD-UnitFrame-Player-PVP-FFAIcon",
}
local STATUS_RESTING = { 1.0, 0.88, 0.25 }
local STATUS_COMBAT  = { 1.0, 0.0, 0.0 }
local STATUS_PULSE   = { 55 / 255, 1, 0.5 }   -- Blizzard's status glow: alpha low, high, seconds each way
-- Blizzard's level text: Friz Quadrata 14 with a shadow (WhiteLargeNumberFont), at 1x
local LEVEL_FONT, LEVEL_FONT_SIZE = "Fonts\\FRIZQT__.TTF", 14
-- the level disc, number and skull, of the atlas size (as Blizzard's 2026-10-16 frames show them)
local LEVEL_SCALE = 0.94

-- Each style is a whole unit frames setup of its own: every frame's settings and positions, the totem
-- bar and the cast bar, swapped on the switch (a reload follows). Shared between the two: the party,
-- raid and boss frames, the resource bars (a module of their own), and what is switched on.
local SHARED_KEYS = { enabled = true, foreverStyle = true, plateStyle = true, styleProfiles = true, editSections = true,
                      party = true, raid = true, boss = true, resource = true, styleStart = true }

-- Forever's frame plate (Forever Style): the left part of the target's atlas (194 x 68 art pixels),
-- name box, health and power slots, as measured on the art. The frame's own rect is x0..x1, y0..y1
-- (rim to rim, the joining piece under the ring included); the art is cut into ends that keep their
-- size and middles that stretch (cutX / cutY: the piece edges, the stretching piece in the middle).
-- The bars' atlases have margins round their colour: the bars are made that much bigger (inner).
local PLATE = {
    atlas = "UI-HUD-UnitFrame-Target-PortraitOn", artW = 194, artH = 68,
    x0 = 1, x1 = 131, y0 = 8, y1 = 57,
    cutX = { 0, 8, 120, 131 }, cutY = { 6, 14, 24, 59 },
    ringD = 61.8, ringX = 158.6,           -- Blizzard's ring on this art: its diameter and centre
    name   = { 4, 125, 11, 26 },           -- x from, x to, y from, y to
    health = { 4, 125, 29, 42, atlas = "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health", w = 126, h = 20, innerW = 120, innerH = 12 },
    power  = { 4, 125, 45, 53, atlas = "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Mana", w = 134, h = 10, innerW = 120, innerH = 8 },
    strip  = "UI-HUD-UnitFrame-Target-PortraitOn-Type",   -- the name box's reaction glow
}
Ring.PLATE_UNITS = { player = true, target = true, focus = true }
-- The Forever preset: a new profile starts with it (the Forever style is the default), as does the
-- first switch to this style: these frame settings, the totems', and the default positions below
-- (stored positions are dropped, so the defaults apply). Party frames are left as they are.
local FOREVER = {
    player = { border = "FlareUI Thin", portrait = "3d", width = 200, height = 60, powerHeight = 15, ringSize = 90 },
    target = { border = "FlareUI Thin", portrait = "3d", width = 200, height = 60, powerHeight = 15, classicCombo = true },
    focus  = { border = "FlareUI Thin", portrait = "3d", width = 110, height = 35 },
    pet    = { height = 30 },
}
local FOREVER_TOTEMS = { size = 100, perRow = 2 }
-- the default positions in this style (UnitFrames' and Totems' DEFAULT_POSITIONS)
Ring.POSITIONS = {
    player        = { point = "CENTER",      x = -286, y = -270 },
    target        = { point = "CENTER",      x = 286,  y = -270 },
    targettarget  = { point = "BOTTOM",      x = 236,  y = 251 },
    focus         = { point = "RIGHT",       x = -467, y = -256 },
    focustarget   = { point = "BOTTOMRIGHT", x = -477, y = 277 },
    pet           = { point = "BOTTOM",      x = -246, y = 270 },
    playercastbar = { point = "CENTER",      x = 0,    y = -221 },
}
Ring.TOTEM_POSITION = { point = "BOTTOM", x = -337, y = 218 }

-- the frame's icon regions that move onto the ring's layer (UnitFrames' field names)
local RING_ICONS = { "RestIcon", "LeaderIcon", "PvPIcon", "ClassIcon", "QuestIcon", "RaidIcon", "ReadyIcon" }
-- UnitFrames' icon keys -> the BLIZZ entry they use
local ICON_KEYS = { rest = "rest", leader = "leader", pvp = "pvp", classification = "classification",
                    quest = "quest", raidIcon = "raidIcon", readyCheck = "readyCheck" }

--------------------------------------------------
-- 2. HELPERS
--------------------------------------------------
local LEM = LibStub("FlareEditMode")

local frames = {}   -- the frames laid out in this style (for the state events)

local function GetDb()
    return ns.db and ns.db.profile and ns.db.profile.unitframes
end

local function UnitDb(unit)
    local db = GetDb()
    return db and db.units and db.units[unit]
end

local function Readable(v)
    if v ~= nil and canaccessvalue(v) then return v end
end

-- an Icons switch of the frame (UnitFrames' udb.icons): the PvP timer starts off, the glows on
local function IconOn(f, key, default)
    local udb = UnitDb(f.unit)
    local store = udb and udb.icons and udb.icons[key]
    if store and store.shown ~= nil then return store.shown end
    return default or false
end

function Ring.On()
    local db = GetDb()
    if not db then return false end
    if not db.styleStart then Ring.StartStyle(db) end
    return db.foreverStyle and true or false
end

-- this frame is drawn in a ring style (FlareUI Style or Forever Style)
function Ring.Applies(f)
    return f and f.Portrait ~= nil and RING_UNITS[f.unit] and Ring.On() or false
end

-- The style in use: "forever" (the ring on Forever's frame plate), "flareui" (the ring beside
-- FlareUI's bars) or "addon" (no ring)
function Ring.Style()
    if not Ring.On() then return "addon" end
    local db = GetDb()
    return db.plateStyle and "forever" or "flareui"
end

-- Forever Style is in use
function Ring.PlateOn()
    return Ring.Style() == "forever"
end

-- this frame is drawn on Forever's frame plate
function Ring.Plate(f)
    return Ring.Applies(f) and Ring.PLATE_UNITS[f.unit] and Ring.PlateOn() or false
end

-- the ring's side: its natural one, or the other on a frame mirrored away from it
function Ring.Side(f)
    if f.unit == "player" then return "LEFT" end
    local udb = UnitDb(f.unit)
    local natural = BLIZZ[f.unit].side
    return (udb and udb.mirror) and natural or (natural == "LEFT" and "RIGHT" or "LEFT")
end

--------------------------------------------------
-- 3. GEOMETRY
--------------------------------------------------
-- The ring's default size for a frame of height h
local function DefaultDiameter(h)
    return math.floor((h or 44) * RING_SHARE + 0.5)
end

-- D, R, H, the ring's side, its centre from the frame's edge (positive: inside), and the scale from
-- Blizzard's ring to ours
-- Forever Style: the plate's scale (screen pixels per art pixel) for a ring of diameter D, and the
-- least height and width its fixed rows and ends take
local function PlateScale(D) return D / PLATE.ringD end
function Ring.PlateMinSize(f)
    local udb = UnitDb(f.unit) or {}
    local s = PlateScale(udb.ringSize or DefaultDiameter(udb.height))
    local fixedH = (PLATE.y1 - PLATE.y0) - (PLATE.cutY[3] - PLATE.cutY[2])
    local fixedW = (PLATE.x1 - PLATE.x0) - (PLATE.cutX[3] - PLATE.cutX[2])
    -- a few pixels of name box, and of middle, at the least
    return math.ceil((fixedW + 12) * s), math.ceil((fixedH + 4) * s)
end

local function Geometry(f)
    local udb = UnitDb(f.unit) or {}
    local H = udb.height or 44
    local D = udb.ringSize or DefaultDiameter(H)
    local R = D / 2
    local g = { D = D, R = R, side = Ring.Side(f), k = D / BLIZZ[f.unit].D }
    if Ring.Plate(f) then
        -- on the plate: the ring stands where Blizzard's art has it, past the plate's end
        g.s = PlateScale(D)
        local _, minH = Ring.PlateMinSize(f)
        g.H = math.max(H, minH)
        g.centre = -(PLATE.ringX - PLATE.x1) * g.s
        return g
    end
    local half = H / 2
    -- the bars' corners meet the rim: the frame's edge is a bar inset outside that point
    local chord = half < R and math.sqrt(R * R - half * half) or 0
    g.H, g.centre = H, BAR_INSET - chord
    return g
end

-- how far into the frame (from its edge) the ring reaches at `dy` above / below the middle
local function ReachAt(g, dy)
    if dy >= g.R then return 0 end
    return math.max(0, g.centre + math.sqrt(g.R * g.R - dy * dy))
end

-- room an aura row or the cast bar needs on the ring's side, at `gap` beyond the frame's edge
function Ring.Clearance(f, gap)
    local g = Geometry(f)
    return math.ceil(ReachAt(g, g.H / 2 + gap)) + 3
end

-- the name's extra inset on the ring's side, from the health bar's edge: clear of the portrait
function Ring.TextPad(f)
    local g = Geometry(f)
    return math.max(0, math.ceil(g.centre + g.R) - BAR_INSET + 3)
end

-- An element's centre (from our ring's centre) and size, from its BLIZZ entry; nil without one
local function Place(f, g, e, atlasOverride)
    if not e then return nil end
    -- frame: the entry is in another frame's coordinates (mirrored to ours like everything else)
    local blizz = BLIZZ[e.frame or f.unit]
    local k = g.D / blizz.D
    local s = e.scale or 1
    local w, h
    if e.size then
        w, h = e.size, e.size
    else
        local info = C_Texture.GetAtlasInfo(atlasOverride or e.atlas)
        if not (info and info.width and info.height) then return nil end
        w, h = info.width, info.height
    end
    w, h = w * s, h * s
    -- the anchor point in Blizzard's frame, then the element's centre
    local ax, ay = e.x, e.y
    local point = e.point
    local cx = point:find("LEFT") and ax + w / 2 or point:find("RIGHT") and ax - w / 2 or ax
    local cy = point:find("TOP") and ay - h / 2 or point:find("BOTTOM") and ay + h / 2 or ay
    local dx, dy = (cx - blizz.centre[1]) * k, (cy - blizz.centre[2]) * k
    if g.side ~= blizz.side then dx = -dx end
    return dx, dy, w * k, h * k
end

-- The PvP disc's centre (from our ring's centre) and size: off the level disc, mirrored with it
local function PvPSpot(f, g)
    local blizz = BLIZZ[f.unit]
    local e = blizz.pvp
    if not e then return nil end
    local lx, ly, lw = Place(f, g, blizz.level)
    if not lx then return nil end
    local sign = (g.side ~= blizz.side) and -1 or 1
    local x, y = lx + sign * e.dx * lw, ly + e.dy * lw
    -- Forever's build of 2026-10-16 dropped the crest's dark disc and moved the crest: its top now
    -- sits where the disc's top was, moved by e.move (Blizzard pixels, from Blizzard's anchors, then
    -- matched to screenshots of its frames), so its centre drops by half the crest's extra height too.
    -- (The dx / dy above were measured on the disc.)
    local crest, disc = C_Texture.GetAtlasInfo(PVP_ICONS.Horde), C_Texture.GetAtlasInfo(SMALL_CIRCLE)
    if e.move and disc and disc.width and disc.width > 0 and disc.height then
        local k = lw / disc.width
        local grow = (crest and crest.height) and (crest.height - disc.height) * e.share / 2 or 0
        x = x + sign * e.move[1] * k
        y = y + (e.move[2] - grow) * k
    end
    return x, y, lw * e.share, lw * e.share
end

--------------------------------------------------
-- 4. BUILD
--------------------------------------------------
-- the ring out of its atlas, mirrored on the other side from the atlas's
local function Crop(tex, artInfo, side)
    local info = C_Texture.GetAtlasInfo(artInfo.atlas)
    if not info then return false end
    local l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
    if not (l and r and t and b and info.file) then return false end
    local box = artInfo.box
    local x1, x2 = l + box[1] * (r - l), l + box[2] * (r - l)
    if side and side ~= artInfo.side then x1, x2 = x2, x1 end
    tex:SetTexture(info.file)
    tex:SetTexCoord(x1, x2, t + box[3] * (b - t), t + box[4] * (b - t))
    return true
end

local function SetAtlasSafe(tex, atlas)
    if atlas and C_Texture.GetAtlasInfo(atlas) then
        tex:SetAtlas(atlas, false)
        return true
    end
    return false
end

-- a glow around the ring
local function GlowTexture(ring)
    local tex = ring:CreateTexture(nil, "OVERLAY")
    tex:SetPoint("CENTER", ring, "CENTER")
    tex:Hide()
    return tex
end

-- the ring, its masks, the discs, glows and extras: made once
local function Build(f)
    if f.RingFrame then return f.RingFrame end
    local ring = CreateFrame("Frame", nil, f)
    -- the art itself is cropped at each layout (mirrored with the ring's side)
    ring.Art = ring:CreateTexture(nil, "ARTWORK")
    ring.Art:SetAllPoints()
    ring.Mask = ring:CreateMaskTexture()
    ring.Mask:SetAllPoints(ring.Art)
    ring.Mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    ring.Art:AddMaskTexture(ring.Mask)

    -- the portrait's mask, the same shape
    ring.PortraitMask = f.Portrait:CreateMaskTexture()
    ring.PortraitMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    ring.PortraitMask:SetAllPoints(f.Portrait)

    -- the glows: resting / combat status (player) and the threat flash
    ring.Status = GlowTexture(ring)
    ring.Flash = GlowTexture(ring)
    -- the status glow pulses, as Blizzard's does
    ring.Pulse = ring:CreateAnimationGroup()
    ring.Pulse:SetLooping("BOUNCE")
    local fade = ring.Pulse:CreateAnimation("Alpha")
    fade:SetTarget(ring.Status)
    fade:SetFromAlpha(STATUS_PULSE[1])
    fade:SetToAlpha(STATUS_PULSE[2])
    fade:SetDuration(STATUS_PULSE[3])

    -- the icons that live on the ring sit on their own layer above it
    ring.Icons = CreateFrame("Frame", nil, ring)
    ring.Icons:SetAllPoints(f)
    ring.Corner = ring.Icons:CreateTexture(nil, "OVERLAY")
    ring.Corner:Hide()
    ring.Attack = ring.Icons:CreateTexture(nil, "OVERLAY")
    ring.Attack:Hide()

    -- the elite / rare frame wraps the ring, above it
    ring.Boss = ring.Icons:CreateTexture(nil, "ARTWORK")
    ring.Boss:Hide()

    -- the level: Forever's dark disc at the ring's lower outer corner, the skull in it for "??" units
    ring.Disc = CreateFrame("Frame", nil, ring)
    ring.Disc.Tex = ring.Disc:CreateTexture(nil, "ARTWORK")
    ring.Disc.Tex:SetAllPoints()
    if not SetAtlasSafe(ring.Disc.Tex, SMALL_CIRCLE) then
        ring.Disc.Tex:SetTexture(CIRCLE_MASK)
        ring.Disc.Tex:SetVertexColor(0, 0, 0, 0.9)
    end
    ring.Skull = ring.Disc:CreateTexture(nil, "OVERLAY")
    ring.Skull:SetPoint("CENTER")
    ring.Skull:Hide()

    -- the PvP / faction crest's layer, above the dragon frame. PvPDisc is the crest's spot, never
    -- drawn (Forever's frames have shown the crest without a disc since the 2026-10-16 build); the
    -- PvP timer hangs off it
    ring.PvP = CreateFrame("Frame", nil, ring)
    ring.PvP:SetAllPoints(f)
    ring.PvPDisc = ring.PvP:CreateTexture(nil, "ARTWORK")
    ring.PvPDisc:Hide()

    -- Blizzard's PvP timer (player), beside the PvP disc
    if f.unit == "player" then
        ring.PvPTimer = ring.PvP:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ring.PvPTimer:SetPoint("RIGHT", ring.PvPDisc, "LEFT", 2, 0)
        ring.PvPTimer:Hide()
    end
    -- the PvP countdown's OnUpdate, set while it runs
    ring.Ticker = CreateFrame("Frame", nil, ring)

    f.RingFrame = ring
    return ring
end

-- places a region at a BLIZZ element (or hides it without one)
--------------------------------------------------
-- 5. LAYOUT
--------------------------------------------------
local function PlaceRegion(f, g, region, e, atlas)
    local dx, dy, w, h = Place(f, g, e, atlas)
    region:ClearAllPoints()
    if not dx then return false end
    region:SetSize(w, h)
    region:SetPoint("CENTER", f.RingFrame, "CENTER", dx, dy)
    return true
end

-- Lays out the ring, portrait, discs and extras (called from UnitFrames' LayoutBars)
function Ring.Layout(f)
    local ring = Build(f)
    local g = Geometry(f)
    -- FlareUI Style: no plate (Forever Style lays it out from LayoutBars)
    if not Ring.Plate(f) then Ring.HidePlate(f) end
    local level = f:GetFrameLevel()
    local left = g.side == "LEFT"
    local blizz = BLIZZ[f.unit]
    frames[f] = true

    -- bottom to top: bars, border, texts and the bars' divider (the frame's own levels), then the
    -- portrait, the ring (with its glows), the icons on it, the level disc, the PvP crest over its
    -- edge (the combo gems go above all of it)
    f.Portrait:SetFrameLevel(level + 9)
    ring:SetFrameLevel(level + 10)
    ring.Icons:SetFrameLevel(level + 11)
    ring.Disc:SetFrameLevel(level + 12)
    ring.PvP:SetFrameLevel(level + 13)
    for _, key in ipairs(RING_ICONS) do
        local region = f[key]
        if region then region:SetParent(key == "PvPIcon" and ring.PvP or ring.Icons) end
    end

    ring:ClearAllPoints()
    ring:SetSize(g.D, g.D)
    ring:SetPoint("CENTER", f, left and "LEFT" or "RIGHT", left and g.centre or -g.centre, 0)
    ring.hasArt = Crop(ring.Art, ART[f.unit], g.side)
    ring:SetShown(ring.hasArt)

    local size = g.D * PORTRAIT_SHARE
    f.Portrait:ClearAllPoints()
    f.Portrait:SetSize(size, size)
    f.Portrait:SetPoint("CENTER", ring, "CENTER", 0, 0)
    if not f.Portrait.ringMasked then
        f.Portrait.Tex:AddMaskTexture(ring.PortraitMask)
        f.Portrait.ringMasked = true
    end
    if f.PortraitDivider then f.PortraitDivider:Hide() end

    -- the glows: a line over the ring's rim
    for _, glow in ipairs({ ring.Status, ring.Flash }) do
        glow:SetTexture(GLOW_FILE)
        glow:SetSize(g.D * GLOW_SHARE, g.D * GLOW_SHARE)
        if left then glow:SetTexCoord(1, 0, 0, 1) else glow:SetTexCoord(0, 1, 0, 1) end
    end
    if blizz.corner then
        SetAtlasSafe(ring.Corner, blizz.corner.atlas)
        PlaceRegion(f, g, ring.Corner, blizz.corner)
        SetAtlasSafe(ring.Attack, blizz.attack.atlas)
        PlaceRegion(f, g, ring.Attack, blizz.attack)
    end
    ring.PvPDisc:ClearAllPoints()
    local px, py, pw, ph = PvPSpot(f, g)
    if px then
        ring.PvPDisc:SetSize(pw, ph)
        ring.PvPDisc:SetPoint("CENTER", ring, "CENTER", px, py)
    end

    Ring.LayoutLevel(f, g)
    Ring.Update(f)
end

-- the level in its disc (always shown in this style)
function Ring.LayoutLevel(f, g)
    local ring = f.RingFrame
    if not ring then return end
    g = g or Geometry(f)
    local e = BLIZZ[f.unit].level
    PlaceRegion(f, g, ring.Disc, e)
    -- Blizzard's 2026-10-16 frames draw it a little under its atlas size: around the same centre
    local w, h = ring.Disc:GetSize()
    ring.Disc:SetSize(w * LEVEL_SCALE, h * LEVEL_SCALE)
    -- the skull and the number at the disc's own scale
    local k = g.D / BLIZZ[e.frame or f.unit].D * LEVEL_SCALE
    if SetAtlasSafe(ring.Skull, SKULL) then
        local info = C_Texture.GetAtlasInfo(SKULL)
        ring.Skull:SetSize(info.width * k, info.height * k)
    end
    ring.Disc:Show()
    f.Level:SetParent(ring.Disc)
    f.Level:ClearAllPoints()
    f.Level:SetJustifyH("CENTER")
    f.Level:SetPoint("CENTER", ring.Disc, "CENTER", 0, 0)
    f.Level:SetFont(LEVEL_FONT, math.max(8, math.floor(LEVEL_FONT_SIZE * k + 0.5)), "")
    f.Level:SetShadowOffset(1, -1)
    f.Level:SetShadowColor(0, 0, 0, 1)
end

--------------------------------------------------
-- 5b. FOREVER STYLE: THE FRAME PLATE
-- Forever's plate behind the bars (name box, health and power slots), cut from the target's atlas
-- into nine pieces: the corners and ends keep their art size, the middle column stretches with the
-- width and the name box's middle row with the height, so the bars stay in Blizzard's proportions.
-- A frame whose ring is on its left (the player) gets the art mirrored.
--------------------------------------------------
-- an edge in art pixels -> its anchor on the frame: the side it hangs from and the offset
local function EdgeX(x, s)
    if x <= PLATE.cutX[2] then return "LEFT", (x - PLATE.x0) * s end
    return "RIGHT", (x - PLATE.x1) * s
end
local function EdgeY(y, s)
    if y <= PLATE.cutY[2] then return "TOP", (PLATE.y0 - y) * s end
    return "BOTTOM", (PLATE.y1 - y) * s
end

-- Puts a region over art rect x1..x2, y1..y2 of the plate (the ring on the art's right; flip: on the
-- frame's left, mirrored). xs / ys: the art edge's side, for edges of the stretching pieces.
local function PlaceOnPlate(region, f, s, flip, x1, x2, y1, y2)
    local lSide, lx = EdgeX(x1, s)
    local rSide, rx = EdgeX(x2, s)
    local tSide, ty = EdgeY(y1, s)
    local bSide, by = EdgeY(y2, s)
    if flip then
        -- the art's left edge becomes the frame's right edge
        local function other(side) return side == "LEFT" and "RIGHT" or "LEFT" end
        lSide, lx, rSide, rx = other(rSide), -rx, other(lSide), -lx
    end
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", f, tSide .. lSide, lx, ty)
    region:SetPoint("BOTTOMRIGHT", f, bSide .. rSide, rx, by)
end

local function BuildPlate(f)
    if f.PlateFrame then return f.PlateFrame end
    local plate = CreateFrame("Frame", nil, f)
    plate:SetAllPoints(f)
    plate.pieces = {}
    for i = 1, 9 do plate.pieces[i] = plate:CreateTexture(nil, "BACKGROUND") end
    -- the name box's reaction glow, and an anchor for the name
    plate.Strip = plate:CreateTexture(nil, "BORDER")
    plate.NameBox = CreateFrame("Frame", nil, plate)
    f.PlateFrame = plate
    return plate
end

-- A bar over its slot: the bar's atlas has margins round its colour, so the bar is that much bigger
local function PlaceBar(bar, f, s, flip, slot)
    local w = ((slot[2] - slot[1]) * slot.w / slot.innerW - (slot[2] - slot[1])) / 2
    local h = ((slot[4] - slot[3]) * slot.h / slot.innerH - (slot[4] - slot[3])) / 2
    PlaceOnPlate(bar, f, s, flip, slot[1] - w, slot[2] + w, slot[3] - h, slot[4] + h)
    bar:SetStatusBarTexture(slot.atlas)
    local tex = bar:GetStatusBarTexture()
    -- Blizzard's art greyed, then FlareUI's colours (class, reaction, power) tint it
    if tex then tex:SetDesaturated(true) end
    if bar.bg then bar.bg:SetAlpha(0) end   -- the slot is the background
end

-- Lays out the plate and puts the bars in its slots (UnitFrames' LayoutBars, Forever Style)
function Ring.LayoutPlate(f)
    local g = Geometry(f)
    local s, flip = g.s, g.side == "LEFT"
    local plate = BuildPlate(f)
    plate:SetFrameLevel(f:GetFrameLevel())
    plate:Show()
    local info = C_Texture.GetAtlasInfo(PLATE.atlas)
    if info and info.file then
        local du, dv = info.rightTexCoord - info.leftTexCoord, info.bottomTexCoord - info.topTexCoord
        local cx, cy, i = PLATE.cutX, PLATE.cutY, 0
        for row = 1, 3 do
            for col = 1, 3 do
                i = i + 1
                local tex = plate.pieces[i]
                local x1, x2, y1, y2 = cx[col], cx[col + 1], cy[row], cy[row + 1]
                local u1 = info.leftTexCoord + x1 / PLATE.artW * du
                local u2 = info.leftTexCoord + x2 / PLATE.artW * du
                if flip then u1, u2 = u2, u1 end
                tex:SetTexture(info.file)
                tex:SetTexCoord(u1, u2, info.topTexCoord + y1 / PLATE.artH * dv, info.topTexCoord + y2 / PLATE.artH * dv)
                PlaceOnPlate(tex, f, s, flip, x1, x2, y1, y2)
                tex:Show()
            end
        end
    end
    local n = PLATE.name
    PlaceOnPlate(plate.NameBox, f, s, flip, n[1], n[2], n[3], n[4])
    PlaceOnPlate(plate.Strip, f, s, flip, n[1], n[2], n[3], n[4])
    if not SetAtlasSafe(plate.Strip, PLATE.strip) then plate.Strip:Hide() end
    PlaceBar(f.Health, f, s, flip, PLATE.health)
    PlaceBar(f.Power, f, s, flip, PLATE.power)
    f.Power:Show()
    Ring.UpdatePlate(f)
end

-- the name box's glow in the unit's reaction colour, as on Blizzard's target and focus frames (the
-- player's has none)
function Ring.UpdatePlate(f)
    local plate = f.PlateFrame
    if not (plate and plate:IsShown()) then return end
    local unit = f.unit
    if unit == "player" or not UnitExists(unit) then
        plate.Strip:Hide()
        return
    end
    local r, g, b = UnitSelectionColor(unit)
    plate.Strip:SetVertexColor(r, g, b, 1)
    plate.Strip:Show()
end

-- the name box, for the name to sit in (nil off the plate)
function Ring.NameBox(f)
    return f.PlateFrame and f.PlateFrame:IsShown() and f.PlateFrame.NameBox or nil
end

local function HidePlate(f)
    if not f.PlateFrame then return end
    f.PlateFrame:Hide()
    if f.Health.bg then f.Health.bg:SetAlpha(1) end
    if f.Power.bg then f.Power.bg:SetAlpha(1) end
    for _, bar in ipairs({ f.Health, f.Power }) do
        local tex = bar:GetStatusBarTexture()
        if tex then tex:SetDesaturated(false) end
    end
end
Ring.HidePlate = HidePlate

-- back to the usual style: levels, parents and masks as UnitFrames made them
function Ring.Reset(f)
    HidePlate(f)
    local ring = f.RingFrame
    if not ring then return end
    frames[f] = nil
    local level = f:GetFrameLevel()
    ring:Hide()
    f.Level:SetAlpha(1)
    f.Portrait:SetFrameLevel(level + 1)
    f.Overlay:SetFrameLevel(level + 5)
    f.Level:SetParent(f.Overlay)
    for _, key in ipairs(RING_ICONS) do
        local region = f[key]
        if region then region:SetParent(f.Overlay) end
    end
    if f.Portrait.ringMasked then
        f.Portrait.Tex:RemoveMaskTexture(ring.PortraitMask)
        f.Portrait.ringMasked = nil
    end
end

-- An icon's place on the ring: point, relativeTo, relativePoint, x, y, width, height; nil without one
function Ring.IconSpot(f, key)
    local entryKey = ICON_KEYS[key]
    local e = entryKey and BLIZZ[f.unit] and BLIZZ[f.unit][entryKey]
    if not e or not f.RingFrame then return nil end
    local g = Geometry(f)
    local dx, dy, w, h
    if key == "pvp" then
        -- the crest: on its disc's centre, its atlas's size against the disc's
        dx, dy, w, h = PvPSpot(f, g)
        local crest, disc = C_Texture.GetAtlasInfo(PVP_ICONS.Horde), C_Texture.GetAtlasInfo(SMALL_CIRCLE)
        if dx and crest and disc and crest.width and disc.width and disc.width > 0 then
            w, h = w * crest.width / disc.width, h * crest.height / disc.height
        end
    else
        dx, dy, w, h = Place(f, g, e)
    end
    if not dx then return nil end
    -- the crown: Blizzard's spot along the frame, at the usual frame's height (its centre 2 px under
    -- the top edge), so it stays clear of the auras above
    if key == "leader" then dy = g.H / 2 - 2 end
    return "CENTER", f.RingFrame, "CENTER", dx, dy, w, h
end

--------------------------------------------------
-- 6. STATE ART
--------------------------------------------------
-- the Ticker: the PvP countdown
local function Tick(ticker, elapsed)
    local ring = ticker:GetParent()
    local busy = false
    if ring.pvpEnd then
        ring.pvpElapsed = (ring.pvpElapsed or 0) + elapsed
        if ring.pvpElapsed >= 0.2 then
            ring.pvpElapsed = 0
            local left = ring.pvpEnd - GetTime()
            if left < 0 then
                ring.pvpEnd = nil
                ring.PvPTimer:Hide()
            else
                ring.PvPTimer:SetFormattedText(SecondsToTimeAbbrev(math.floor(left)))
            end
        end
        busy = ring.pvpEnd ~= nil
    end
    if not busy then ticker:SetScript("OnUpdate", nil) end
end

local function StartTicker(ring)
    if not ring.Ticker:GetScript("OnUpdate") then ring.Ticker:SetScript("OnUpdate", Tick) end
end

-- the PvP timer, and its Edit Mode sample
local function UpdateExtras(f)
    local ring = f.RingFrame
    local editing = LEM:IsInEditMode()
    if ring.PvPTimer then
        local on = IconOn(f, "pvpTimer")
        if on and Readable(IsPVPTimerRunning()) then
            local ms = Readable(GetPVPTimer())
            ring.pvpEnd = ms and GetTime() + ms / 1000 or nil
            ring.pvpElapsed = 1   -- the text at once
            ring.PvPTimer:SetShown(ring.pvpEnd ~= nil)
            if ring.pvpEnd then StartTicker(ring) end
        elseif on and editing then
            ring.pvpEnd = nil
            ring.PvPTimer:SetFormattedText(SecondsToTimeAbbrev(299))
            ring.PvPTimer:Show()
        else
            ring.pvpEnd = nil
            ring.PvPTimer:Hide()
        end
    end
end

-- The state art: PvP disc and crest, elite / rare frame, skull, resting / combat glow, corner
-- embellishment, combat swords and the threat flash. Readable values only; secret ones hide the art.
function Ring.Update(f)
    local ring = f.RingFrame
    if not ring or not Ring.Applies(f) then return end
    Ring.UpdatePlate(f)
    local unit, g, blizz = f.unit, Geometry(f), BLIZZ[f.unit]
    local exists = Readable(UnitExists(unit))

    -- PvP: Forever's faction crest on its own disc (the frame's PvP icon, re-arted)
    if blizz.pvp and f.PvPIcon then
        local shown = f.PvPIcon:IsShown()
        if shown then
            local ffa = Readable(UnitIsPVPFreeForAll(unit))
            local faction = Readable(UnitFactionGroup(unit))
            local atlas = ffa and PVP_ICONS.FFA or PVP_ICONS[faction or ""]
            if atlas then SetAtlasSafe(f.PvPIcon, atlas) end
        end
        -- the combo arc starts higher while the crest shows (Blizzard's alternate start)
        local combo = _G.ComboFrame
        if unit == "target" and ring.comboPvP ~= nil and ring.comboPvP ~= (shown and true or false)
            and combo and combo:GetParent() == f then
            Ring.PlaceCombo(combo, f)
        end
    end

    -- the elite / rare frame, as Forever picks it (gold elite, silver rare, winged gold boss)
    ring.Boss:Hide()
    if blizz.boss and exists and GetBossPortraitFrameData then
        local classification = Readable(UnitClassification(unit))
        local ok, atlas, ox, oy = pcall(GetBossPortraitFrameData, unit, classification)
        if ok and atlas and SetAtlasSafe(ring.Boss, atlas) then
            local info = C_Texture.GetAtlasInfo(atlas)
            -- TOPRIGHT at Blizzard's frame's top-right corner plus Forever's offsets
            local e = { point = "TOPRIGHT", x = BLIZZ_FRAME_W + (ox or 0), y = oy or 0 }
            local dx, dy, w, h = Place(f, g, e, atlas)
            if dx then
                ring.Boss:ClearAllPoints()
                ring.Boss:SetSize(w, h)
                ring.Boss:SetPoint("CENTER", ring, "CENTER", dx, dy)
                if g.side ~= blizz.side then ring.Boss:SetTexCoord(1, 0, 0, 1) else ring.Boss:SetTexCoord(0, 1, 0, 1) end
                ring.Boss:SetShown(info ~= nil)
            end
        end
    end

    -- the skull in the level disc for a unit far above you ("??")
    local level = Readable(UnitLevel(unit))
    local skull = exists and level and level < 0 or false
    ring.Skull:SetShown(skull and ring.Disc:IsShown())
    f.Level:SetAlpha(skull and 0 or 1)

    -- the player: red glow and swords in combat, else yellow glow and corner piece resting (combat
    -- first, as Blizzard's frame since the 2026-10-16 build)
    if unit == "player" then
        local combat = Readable(UnitAffectingCombat("player"))
        local resting = not combat and Readable(IsResting())
        local color = combat and STATUS_COMBAT or resting and STATUS_RESTING or nil
        if color and IconOn(f, "statusGlow", true) then
            ring.Status:SetVertexColor(color[1], color[2], color[3], 1)
            ring.Status:Show()
            if not ring.Pulse:IsPlaying() then ring.Pulse:Play() end
        else
            ring.Status:Hide()
            ring.Pulse:Stop()
        end
        -- the player's level is white, as on Blizzard's frame
        f.Level:SetTextColor(1, 1, 1)
        ring.Corner:SetShown(resting and true or false)
        ring.Attack:SetShown(combat and true or false)
    end

    UpdateExtras(f)

    -- threat: the flash in Blizzard's threat colours
    do
        local status
        if unit == "player" then
            status = Readable(UnitThreatSituation("player"))
        elseif exists then
            status = Readable(UnitThreatSituation("player", unit))
        end
        if status and status > 0 and GetThreatStatusColor and IconOn(f, "threatGlow", true) then
            local r, gg, b = GetThreatStatusColor(status)
            ring.Flash:SetVertexColor(r, gg, b, 1)
            ring.Flash:Show()
        else
            ring.Flash:Hide()
        end
    end
end

-- the state art follows combat, resting and threat without a full layout
-- Unit events only for the ring frames' units: threat updates fire for every group member.
-- RegisterUnitEvent takes two units, so focus has a frame of its own.
do
    local function OnEvent()
        for f in pairs(frames) do Ring.Update(f) end
    end
    local events, focusEvents = CreateFrame("Frame"), CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_UPDATE_RESTING", "PVP_TIMER_UPDATE" }) do
        pcall(events.RegisterEvent, events, event)
    end
    for _, event in ipairs({ "UNIT_THREAT_SITUATION_UPDATE", "UNIT_THREAT_LIST_UPDATE", "UNIT_CLASSIFICATION_CHANGED",
            "UNIT_FACTION", "PLAYER_FLAGS_CHANGED" }) do
        pcall(events.RegisterUnitEvent, events, event, "player", "target")
        pcall(focusEvents.RegisterUnitEvent, focusEvents, event, "focus")
    end
    events:SetScript("OnEvent", OnEvent)
    focusEvents:SetScript("OnEvent", OnEvent)
end

--------------------------------------------------
-- 7. CLASSIC COMBO POINTS
--------------------------------------------------
-- Classic combo points as Blizzard lays them around its target ring, scaled to ours (mirrored on a
-- ring at the left). Anchors only: the count may be secret.
function Ring.PlaceCombo(combo, f)
    if f.unit ~= "target" or not f.RingFrame then return false end
    local g = Geometry(f)
    local c = RING_COMBO
    local k = g.D / BLIZZ.target.D
    local pvp = f.PvPIcon and f.PvPIcon:IsShown()
    local start = pvp and c.pvpStart or c.start
    f.RingFrame.comboPvP = pvp and true or false
    combo:ClearAllPoints()
    combo:SetAllPoints(f.RingFrame)
    -- above everything on the ring, the PvP crest included
    combo:SetFrameLevel(f.RingFrame.PvP:GetFrameLevel() + 1)
    for i, point in ipairs(combo.ComboPoints) do
        -- Blizzard's arc: point 1 lowest; it fills its last points first, so the top ones light first
        local a = math.rad(start + (i - 1) * c.step)
        point:SetScale(c.scale * k)
        local s = point:GetScale() or 1   -- offsets are in the point's own scale
        local x = (math.cos(a) * c.radius * c.scale + c.shift[1]) * k
        local y = (math.sin(a) * c.radius * c.scale + c.shift[2]) * k
        if g.side == "LEFT" then x = -x end
        point:ClearAllPoints()
        point:SetPoint("CENTER", f.RingFrame, "CENTER", x / s, y / s)
    end
    return true
end

--------------------------------------------------
-- 8. STYLE SWITCH
--------------------------------------------------
-- a table's own values, deep (AceDB's defaults stay behind their metatables)
local function CopyRaw(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = CopyRaw(x) end
    return t
end

-- empties a table's own values; tables AceDB made (they carry its defaults) are kept, emptied
local function Clear(t)
    for k, v in pairs(t) do
        if type(v) == "table" and getmetatable(v) then Clear(v) else t[k] = nil end
    end
end

-- top: the unit frames table itself, whose shared keys are never taken from a stash
local function Fill(dst, src, top)
    for k, v in pairs(src) do
        if not (top and SHARED_KEYS[k]) then
            if type(v) == "table" and type(rawget(dst, k)) == "table" then Fill(dst[k], v) else dst[k] = CopyRaw(v) end
        end
    end
end

-- the Forever preset on the setup in use
local function ApplyForeverPreset(db)
    for unit, keys in pairs(FOREVER) do
        local udb = db.units and db.units[unit]
        if udb then for key, value in pairs(keys) do udb[key] = value end end
    end
    if db.totems then for key, value in pairs(FOREVER_TOTEMS) do db.totems[key] = value end end
    db.layouts = {}
    db.totemLayouts = {}
end

-- A new profile starts in the Forever style with its preset (once: db.styleStart)
function Ring.StartStyle(db)
    db.styleStart = true
    ApplyForeverPreset(db)
    db.foreverStyle = true
end

-- What is switched on (each frame, the resource bars and each bar, the cast bar, the totems) is the
-- player's choice in both styles: every "enabled" below the unit frames table survives a switch
local SWITCH_SKIP = { layouts = true, totemLayouts = true, tankLayouts = true }
local function CaptureSwitches(t, keys, out)
    if t.enabled ~= nil and #keys > 0 then
        local copy = {}
        for i, k in ipairs(keys) do copy[i] = k end
        out[#out + 1] = { keys = copy, value = t.enabled }
    end
    for k, v in pairs(t) do
        if type(k) == "string" and type(v) == "table" and not SWITCH_SKIP[k] and not (#keys == 0 and SHARED_KEYS[k]) then
            keys[#keys + 1] = k
            CaptureSwitches(v, keys, out)
            keys[#keys] = nil
        end
    end
    return out
end

local function RestoreSwitches(db, switches)
    for _, s in ipairs(switches) do
        local t = db
        for _, k in ipairs(s.keys) do
            if type(t[k]) ~= "table" then t[k] = {} end
            t = t[k]
        end
        t.enabled = s.value
    end
end

-- Forever Style's first time: the frames take the plate's proportions for their ring (the name box
-- as Blizzard's), the ring keeping its size
local function ApplyPlatePreset(db)
    for unit in pairs(Ring.PLATE_UNITS) do
        local udb = db.units and db.units[unit]
        if udb then
            local D = udb.ringSize or DefaultDiameter(udb.height)
            udb.ringSize = math.floor(D + 0.5)
            udb.height = math.floor((PLATE.y1 - PLATE.y0) * PlateScale(D) + 0.5)
        end
    end
end

-- each style's stored setup (styleProfiles keys: "usual" and "forever" are the older names)
local STYLE_SLOT = { addon = "usual", flareui = "forever", forever = "plate" }

-- Switches the style: the setup in use is kept for its style, and the new style's comes back (the
-- first time: Forever Style starts from the FlareUI Style setup with the plate's proportions,
-- FlareUI Style from its preset, Addon Style from the defaults). What is switched on stays.
function Ring.SetStyle(style)
    local db = GetDb()
    local current = Ring.Style()
    if not db or not STYLE_SLOT[style] or current == style then return end
    local switches = CaptureSwitches(db, {}, {})
    db.styleProfiles = db.styleProfiles or {}
    local saved = {}
    for k, v in pairs(db) do
        if not SHARED_KEYS[k] then saved[k] = CopyRaw(v) end
    end
    db.styleProfiles[STYLE_SLOT[current]] = saved
    local function Restore(back)
        for k, v in pairs(db) do
            if not SHARED_KEYS[k] then
                if type(v) == "table" and getmetatable(v) then Clear(v) else db[k] = nil end
            end
        end
        Fill(db, back, true)
    end
    local back = db.styleProfiles[STYLE_SLOT[style]]
    if back then
        Restore(back)
    elseif style == "forever" then
        -- from FlareUI Style's setup: the one in use, or the stored one, or its preset
        if current ~= "flareui" then
            if db.styleProfiles.forever then Restore(db.styleProfiles.forever) else ApplyForeverPreset(db) end
        end
        ApplyPlatePreset(db)
    elseif style == "flareui" then
        -- the preset's positions: none stored, so the style's defaults apply (party frames keep theirs)
        ApplyForeverPreset(db)
    else
        -- the Addon style's first time: the preset's settings and positions back to the defaults
        for unit, keys in pairs(FOREVER) do
            local udb = db.units and db.units[unit]
            if udb then for key in pairs(keys) do udb[key] = nil end end
        end
        if db.totems then for key in pairs(FOREVER_TOTEMS) do db.totems[key] = nil end end
        db.layouts = {}
        db.totemLayouts = {}
    end
    RestoreSwitches(db, switches)
    db.foreverStyle = style ~= "addon"
    db.plateStyle = style == "forever"
end

--------------------------------------------------
-- 9. EDIT MODE
--------------------------------------------------
-- Edit Mode's Portrait Size default: from the frame's current height
function Ring.DefaultSize(unit)
    local udb = UnitDb(unit)
    return DefaultDiameter(udb and udb.height)
end
