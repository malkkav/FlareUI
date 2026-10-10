local _, ns = ...

--------------------------------------------------
-- FOREVER STYLE UNIT FRAMES
-- The default look of the player, target and focus frames: Forever's own bronze portrait ring beside
-- them instead of the square portrait (Unit Frames > Addon style frames switches to the plain look). The ring is the game's atlas (UI-HUD-UnitFrame-*-PortraitOn), cropped to the
-- ring and masked to its outline, so the frame plate it is painted with stays out; FlareUI ships no
-- Blizzard art. UnitFrames.lua asks this file at its layout points (bars, texts, cast bar, auras,
-- icons, classic combo points); everything else is the frames' own code.
--
-- Everything around the ring is placed as Blizzard places it: each element's anchor on Blizzard's
-- own frame (PlayerFrame.xml / TargetFrame.xml, a 232 x 100 frame), taken relative to Blizzard's ring
-- centre and scaled by our ring's size over Blizzard's; sizes are the game's atlas sizes, scaled
-- the same way. A frame whose ring is on its other side mirrors them. Everything on the portrait is
-- Blizzard's, in Blizzard's proportions: the level always shows, and combo points are always the gems.
--   * the level in Forever's dark disc, with the elite skull there for "??" units
--   * the PvP / faction disc (player, target)
--   * the leader crown, the raid marker on the portrait's top edge, the rare star or quest mark on its
--     bottom edge, the resting "zzz", the corner embellishment while resting and the swords in combat
--   * the status glow (yellow resting, red in combat), the threat flash, and the elite / rare frame
--
-- Each style keeps a whole unit frames setup of its own (SHARED_KEYS: what the two share); the switch
-- puts one away and brings the other back, then reloads.
--
-- Geometry, from the ring's diameter D and the frame's height H: the ring sits on the portrait side,
-- centred on the frame's middle; the frame's end tucks under it as Blizzard's plate does (the bars
-- start where their corners meet the rim). The ring is 1.5 x the frame's height unless Ring Size says
-- otherwise.
--------------------------------------------------
local Ring = {}
ns.UFRing = Ring

local RING_UNITS = { player = true, target = true, focus = true }

-- the art: the atlas, and where its ring is inside it (fractions of the atlas, measured on the sheet
-- against its backing: the outer edge of the ring's soft shadow, the same on every side)
local ART = {
    player = { atlas = "UI-HUD-UnitFrame-Player-PortraitOn", drop = true,
               box = { 9.44 / 396, 137.78 / 396, 6.11 / 142, 134.44 / 142 } },
    target = { atlas = "UI-HUD-UnitFrame-Target-PortraitOn", drop = false,
               box = { 252.78 / 384, 375.0 / 384, 1.67 / 134, 123.89 / 134 } },
}
ART.focus = ART.target
local CIRCLE_MASK   = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
-- FlareUI's own teardrop: a circle plus the square bottom-right quadrant, edge to edge
local DROP_MASK     = "Interface\\AddOns\\FlareUI\\Media\\Masks\\RingDrop"
local SMALL_CIRCLE  = "UI-HUD-UnitFrame-SmallCircle"
local PORTRAIT_SHARE = 0.86   -- the portrait inside the ring, of its diameter
local GEM_GAP       = 0.30    -- combo gems sit this share of their size outside the rim
-- Blizzard's combo points on the ring (Forever's October 2026 art): a little smaller than on the
-- row, spaced by their art's reach (Core.lua ns.ComboPointStep)
local RING_COMBO = { size = 14 }
local RING_SHARE    = 1.5     -- the ring's default diameter, of the frame's height
local BAR_INSET     = 4       -- UnitFrames' INSET: the bars start this far in from the frame's edge
local GLOW_SHARE    = 1.35    -- the glow textures' size, of the ring's diameter
-- the glows: FlareUI's own line over the ring's rim (white, tinted, a little transparent). Drawn for
-- GLOW_SHARE 1.35: change both together.
local GLOW_FILES = {
    drop   = "Interface\\AddOns\\FlareUI\\Media\\Masks\\RingHaloDrop",
    circle = "Interface\\AddOns\\FlareUI\\Media\\Masks\\RingHaloCircle",
}

-- Blizzard's frames (1x, origin at the frame's top-left, y down negative): the ring's centre and
-- diameter as measured on the atlas, and every element's anchor. scale = the template's scale (the
-- art's size only; the anchor's offsets are the parent's). size = a fixed size where there is one.
-- pvp: the faction disc, placed off the level disc (centre offset and size in the level disc's
-- texture widths), as measured on Forever's own frames. The player's and target's aren't mirror images.
local BLIZZ = {
    player = {
        centre = { 53.8, -49.6 }, D = 64.17, side = "LEFT",
        level   = { atlas = SMALL_CIRCLE, point = "BOTTOMLEFT", x = 13, y = -93, frame = "player" },
        pvp     = { dx = -0.435, dy = 0.46, share = 0.8 },
        leader  = { atlas = "UI-HUD-UnitFrame-Player-Group-LeaderIcon", point = "TOPLEFT", x = 86, y = -10 },
        rest    = { size = 20, point = "TOPLEFT", x = 64, y = -6 },
        raidIcon = { size = 26, point = "CENTER", x = 53.8, y = -19 },   -- the target's spot, mirrored
        corner  = { atlas = "UI-HUD-UnitFrame-Player-PortraitOn-CornerEmbellishment", point = "TOPLEFT", x = 58.5, y = -53.5 },
        attack  = { atlas = "UI-HUD-UnitFrame-Player-CombatIcon", point = "TOPLEFT", x = 64, y = -62 },
        readyCheck = { size = 40, point = "CENTER", x = 53.8, y = -49.6 },   -- on the portrait
    },
    target = {
        centre = { 176.9, -47.9 }, D = 61.1, side = "RIGHT", boss = true,
        pvp     = { dx = 0.435, dy = 0.46, share = 0.8 },   -- the player's, mirrored
        leader  = { atlas = "UI-HUD-UnitFrame-Player-Group-LeaderIcon", point = "TOPRIGHT", x = 147, y = -8 },
        raidIcon = { size = 26, point = "CENTER", x = 177, y = -19 },
        classification = { atlas = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star", point = "CENTER", x = 177, y = -77 },
        quest   = { atlas = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Quest", point = "CENTER", x = 177, y = -77 },
        readyCheck = { size = 40, point = "CENTER", x = 176.9, y = -47.9 },  -- on the portrait, as the player's
    },
}
-- the target's level disc is the player's, mirrored (Marcus's call: the pair looks better matched)
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

-- Each style is a whole unit frames setup of its own: every frame's settings and positions, the totem
-- bar and the cast bar, swapped on the switch (a reload follows). Shared between the two: the party,
-- raid and boss frames, the resource bars (a module of their own), and what is switched on.
local SHARED_KEYS = { enabled = true, foreverStyle = true, styleProfiles = true, editSections = true,
                      party = true, raid = true, boss = true, resource = true, styleStart = true }
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

-- this frame is drawn in the Forever style
function Ring.Applies(f)
    return f and f.Portrait ~= nil and RING_UNITS[f.unit] and Ring.On() or false
end

-- the ring's side: its natural one, or the other on a frame mirrored away from it
function Ring.Side(f)
    if f.unit == "player" then return "LEFT" end
    local udb = UnitDb(f.unit)
    local natural = BLIZZ[f.unit].side
    return (udb and udb.mirror) and natural or (natural == "LEFT" and "RIGHT" or "LEFT")
end

-- The ring's default size for a frame of height h
local function DefaultDiameter(h)
    return math.floor((h or 44) * RING_SHARE + 0.5)
end

-- D, R, H, the ring's side, its centre from the frame's edge (positive: inside), and the scale from
-- Blizzard's ring to ours
function Ring.Geometry(f)
    local udb = UnitDb(f.unit) or {}
    local H = udb.height or 44
    local D = udb.ringSize or DefaultDiameter(H)
    local R = D / 2
    local half = H / 2
    -- the bars' corners meet the rim: the frame's edge is a bar inset outside that point
    local chord = half < R and math.sqrt(R * R - half * half) or 0
    return { D = D, R = R, H = H, side = Ring.Side(f), centre = BAR_INSET - chord, k = D / BLIZZ[f.unit].D }
end

-- how far into the frame (from its edge) the ring reaches at `dy` above / below the middle
local function ReachAt(g, dy)
    if dy >= g.R then return 0 end
    return math.max(0, g.centre + math.sqrt(g.R * g.R - dy * dy))
end

-- the bars start at the frame's usual inset: the ring covers their first px instead
function Ring.BarSpace()
    return 0
end

-- room an aura row or the cast bar needs on the ring's side, at `gap` beyond the frame's edge
function Ring.Clearance(f, gap)
    local g = Ring.Geometry(f)
    return math.ceil(ReachAt(g, g.H / 2 + gap)) + 3
end

-- the name's extra inset on the ring's side, from the health bar's edge: clear of the portrait
function Ring.TextPad(f)
    local g = Ring.Geometry(f)
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
    return lx + sign * e.dx * lw, ly + e.dy * lw, lw * e.share, lw * e.share
end

local function Crop(tex, artInfo)
    local info = C_Texture.GetAtlasInfo(artInfo.atlas)
    if not info then return false end
    local l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
    if not (l and r and t and b and info.file) then return false end
    local box = artInfo.box
    tex:SetTexture(info.file)
    tex:SetTexCoord(l + box[1] * (r - l), l + box[2] * (r - l), t + box[3] * (b - t), t + box[4] * (b - t))
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
    local art = ART[f.unit]
    local maskFile = art.drop and DROP_MASK or CIRCLE_MASK
    local ring = CreateFrame("Frame", nil, f)
    ring.Art = ring:CreateTexture(nil, "ARTWORK")
    ring.Art:SetAllPoints()
    ring.Mask = ring:CreateMaskTexture()
    ring.Mask:SetAllPoints(ring.Art)
    ring.Mask:SetTexture(maskFile, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    ring.Art:AddMaskTexture(ring.Mask)
    ring.hasArt = Crop(ring.Art, art)

    -- the portrait's mask, the same shape
    ring.PortraitMask = f.Portrait:CreateMaskTexture()
    ring.PortraitMask:SetTexture(maskFile, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
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

    -- the PvP / faction disc: its own dark disc under the frame's PvP icon, above the dragon frame
    ring.PvP = CreateFrame("Frame", nil, ring)
    ring.PvP:SetAllPoints(f)
    ring.PvPDisc = ring.PvP:CreateTexture(nil, "ARTWORK")
    if not SetAtlasSafe(ring.PvPDisc, SMALL_CIRCLE) then ring.PvPDisc:SetColorTexture(0, 0, 0, 0.8) end
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
    local g = Ring.Geometry(f)
    local level = f:GetFrameLevel()
    local left = g.side == "LEFT"
    local blizz = BLIZZ[f.unit]
    frames[f] = true

    -- bottom to top: bars, border, texts and the bars' divider (the frame's own levels), then the
    -- portrait, the ring (with its glows), the icons on it, the PvP disc, the level disc (the combo
    -- gems go above all of it)
    f.Portrait:SetFrameLevel(level + 9)
    ring:SetFrameLevel(level + 10)
    ring.Icons:SetFrameLevel(level + 11)
    ring.PvP:SetFrameLevel(level + 12)
    ring.Disc:SetFrameLevel(level + 13)
    for _, key in ipairs(RING_ICONS) do
        local region = f[key]
        if region then region:SetParent(key == "PvPIcon" and ring.PvP or ring.Icons) end
    end

    ring:ClearAllPoints()
    ring:SetSize(g.D, g.D)
    ring:SetPoint("CENTER", f, left and "LEFT" or "RIGHT", left and g.centre or -g.centre, 0)
    -- (the player's teardrop is always on the left, its point into the frame: never flipped)
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
    local drop = ART[f.unit].drop
    for _, glow in ipairs({ ring.Status, ring.Flash }) do
        glow:SetTexture(drop and GLOW_FILES.drop or GLOW_FILES.circle)
        glow:SetSize(g.D * GLOW_SHARE, g.D * GLOW_SHARE)
        if not drop and left then glow:SetTexCoord(1, 0, 0, 1) else glow:SetTexCoord(0, 1, 0, 1) end
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
    g = g or Ring.Geometry(f)
    local e = BLIZZ[f.unit].level
    PlaceRegion(f, g, ring.Disc, e)
    -- the skull and the number at the disc's own scale
    local k = g.D / BLIZZ[e.frame or f.unit].D
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

-- back to the usual style: levels, parents and masks as UnitFrames made them
function Ring.Reset(f)
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
    local g = Ring.Geometry(f)
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
function Ring.UpdateExtras(f, g)
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
    local unit, g, blizz = f.unit, Ring.Geometry(f), BLIZZ[f.unit]
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
        ring.PvPDisc:SetShown(shown)
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

    -- the player: yellow glow and corner piece resting, red glow and swords in combat
    if unit == "player" then
        local resting = Readable(IsResting())
        local combat = Readable(UnitAffectingCombat("player"))
        local color = resting and STATUS_RESTING or combat and STATUS_COMBAT or nil
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
        ring.Attack:SetShown((combat and not resting) and true or false)
    end

    Ring.UpdateExtras(f, g)

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
do
    local events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_UPDATE_RESTING",
            "UNIT_THREAT_SITUATION_UPDATE", "UNIT_THREAT_LIST_UPDATE", "UNIT_CLASSIFICATION_CHANGED", "UNIT_FACTION" }) do
        pcall(events.RegisterEvent, events, event)
    end
    events:SetScript("OnEvent", function()
        for f in pairs(frames) do Ring.Update(f) end
    end)
    for _, event in ipairs({ "PVP_TIMER_UPDATE", "PLAYER_FLAGS_CHANGED" }) do
        pcall(events.RegisterEvent, events, event)
    end
end

-- Classic combo points along the ring's top arc (clockwise from just right of 12 o'clock on a ring
-- at the right, mirrored on a ring at the left). Anchors only: the count may be secret.
function Ring.PlaceCombo(combo, f)
    if f.unit ~= "target" then return false end
    local g = Ring.Geometry(f)
    local max = combo.maxComboPoints
    if not (canaccessvalue(max) and type(max) == "number" and max >= 1) then max = 5 end
    local last = math.min(max, #combo.ComboPoints)
    -- Blizzard's points, smaller here: their art's whole reach plus a gap per step
    local gemSize = RING_COMBO.size
    local reach = ns.ComboPointStep(gemSize)
    local radius = g.R + gemSize * GEM_GAP
    -- one step along the arc per point; the first just right of 12 o'clock
    local step = math.deg(reach / radius)
    local start = 90 - step * 0.6
    combo:ClearAllPoints()
    combo:SetAllPoints(f.RingFrame)
    -- over the ring: the gems overlap its rim
    combo:SetFrameLevel(f:GetFrameLevel() + 14)
    for i, point in ipairs(combo.ComboPoints) do
        -- the arc fills from the top: Blizzard fills its last points first, so they go first
        local a = math.rad(start - (last - i) * step)
        point:SetScale(RING_COMBO.size / 20)
        local s = point:GetScale() or 1   -- offsets are in the point's own scale
        local x, y = math.cos(a) * radius / s, math.sin(a) * radius / s
        if g.side == "LEFT" then x = -x end
        point:ClearAllPoints()
        point:SetPoint("CENTER", f.RingFrame, "CENTER", x, y)
    end
    return true
end

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

-- Switches the style: the setup in use is kept for its style, and the other style's comes back (the
-- first time: the Forever preset, or the Addon style's defaults). What is switched on stays.
function Ring.SetOn(on)
    local db = GetDb()
    if not db or (db.foreverStyle and true or false) == on then return end
    local switches = CaptureSwitches(db, {}, {})
    db.styleProfiles = db.styleProfiles or {}
    local leaving, coming = on and "usual" or "forever", on and "forever" or "usual"
    local saved = {}
    for k, v in pairs(db) do
        if not SHARED_KEYS[k] then saved[k] = CopyRaw(v) end
    end
    db.styleProfiles[leaving] = saved
    local back = db.styleProfiles[coming]
    if back then
        for k, v in pairs(db) do
            if not SHARED_KEYS[k] then
                if type(v) == "table" and getmetatable(v) then Clear(v) else db[k] = nil end
            end
        end
        Fill(db, back, true)
    elseif on then
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
    db.foreverStyle = on and true or false
end

-- Edit Mode's Ring Size default: from the frame's current height
function Ring.DefaultSize(unit)
    local udb = UnitDb(unit)
    return DefaultDiameter(udb and udb.height)
end
