local _, ns = ...

--------------------------------------------------
-- FOREVER STYLE UNIT FRAMES
-- The ring styles: Forever's bronze portrait ring beside the player, target, focus, party and boss
-- frames (FlareUI Style), or on Forever's frame plate (Forever Style). UnitFrames.lua and the tile
-- modules call in at their layout points; the style switch lives here too.
--------------------------------------------------
local Ring = {}
ns.UFRing = Ring

--------------------------------------------------
-- 1. ART AND PLACEMENT
-- The ring is the game's atlas (UI-HUD-UnitFrame-*-PortraitOn), cropped and masked to the ring; the
-- art is drawn from the game, not copied into FlareUI (LICENSES/README.txt).
-- Everything round the ring sits where Blizzard puts it: each anchor on Blizzard's 232 x 100 frame,
-- taken from Blizzard's ring centre and scaled by ring size over Blizzard's; mirrored on the other side.
-- The ring is centred on the frame's middle, its end tucked under it so the bars start where their
-- corners meet the rim.
--------------------------------------------------
local RING_UNITS = { player = true, target = true, focus = true }

-- the art: the atlas and the ring's box in it (fractions, to the outer edge of its shadow). The ring
-- is on the atlas's right; on the left it is mirrored. Every frame shares the target's ring.
local ART = {
    target = { atlas = "UI-HUD-UnitFrame-Target-PortraitOn", side = "RIGHT",
               box = { 252.78 / 384, 375.0 / 384, 1.67 / 134, 123.89 / 134 } },
}
ART.player = ART.target
ART.focus = ART.target
ART.party = ART.target
ART.boss = ART.target
local CIRCLE_MASK   = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local SMALL_CIRCLE  = "UI-HUD-UnitFrame-SmallCircle"
local PORTRAIT_SHARE = 0.86   -- the portrait inside the ring, of its diameter
-- Blizzard's combo arc round its 61.1 px target ring (Camelot ComboFrame.lua POINT_LAYOUT_DATA),
-- started higher while the PvP crest shows; radius in the points' scale, shift from the centre
local RING_COMBO = { radius = 66, start = -10, pvpStart = 2, step = 21, scale = 0.6, shift = { 2, 2 } }
local RING_SHARE    = 1.5     -- the ring's default diameter, of the frame's height
local BAR_INSET     = 4       -- UnitFrames' INSET
local GLOW_SHARE    = 1.35    -- the glow textures' size, of the ring's diameter
-- the glows' rim line art, drawn for GLOW_SHARE 1.35: change both together
local GLOW_FILE = "Interface\\AddOns\\FlareUI\\Media\\Masks\\RingHaloCircle"

-- Blizzard's frames (1x, origin top-left, y negative down): the ring's centre and diameter, and each
-- element's anchor. scale: the art's scale only; size: a fixed size. pvp: placed off the level disc
-- (in disc widths), then shifted by move (PvPSpot).
local BLIZZ = {
    player = {
        -- the target's ring, mirrored
        centre = { 232 - 176.9, -47.9 }, D = 61.1, side = "LEFT",
        -- 1.5 px in from Blizzard's anchor (13, -93), matched to the game
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
-- The party and boss tiles (f.ringKind): the party as the player frame (role icon at the PvP crest),
-- the boss as the target frame
BLIZZ.party = {
    centre = BLIZZ.player.centre, D = BLIZZ.player.D, side = "LEFT",
    level = BLIZZ.player.level, pvp = BLIZZ.player.pvp, leader = BLIZZ.player.leader,
    raidIcon = BLIZZ.player.raidIcon, readyCheck = BLIZZ.player.readyCheck,
}
BLIZZ.boss = {
    centre = BLIZZ.target.centre, D = BLIZZ.target.D, side = "RIGHT", boss = true,
    level = BLIZZ.target.level, raidIcon = BLIZZ.target.raidIcon, readyCheck = BLIZZ.target.readyCheck,
}
-- the tiles' Portrait Size default (FlareUI Style's party and boss look)
local TILE_RING_D = 66
-- the boss frames' Edit Mode samples, with GetBossPortraitFrameData's art and offsets
local SAMPLE_BOSS_ART = {
    { "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold-Winged", 11, -4 },
    { "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold-Winged", 11, -4 },
    { "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold-Winged", 11, -4 },
    { "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold", 0, 1 },
    { "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Silver-Winged", 8, -7 },
}
function Ring.SampleBossArt(index)
    local art = SAMPLE_BOSS_ART[index or 1]
    if art then return art[1], art[2], art[3] end
end
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
-- Blizzard's level text (WhiteLargeNumberFont) at 1x
local LEVEL_FONT, LEVEL_FONT_SIZE = "Fonts\\FRIZQT__.TTF", 14
-- the level disc, number and skull, of the atlas size (as Blizzard draws them)
local LEVEL_SCALE = 0.94

-- Each style keeps a whole unit frames setup, swapped on the switch (a reload follows); these keys
-- are shared
local SHARED_KEYS = { enabled = true, foreverStyle = true, plateStyle = true, styleProfiles = true, editSections = true,
                      raid = true, resource = true, styleStart = true, tileStyle = true, plateTiles = true }
-- a stored setup may lack these
local TILE_KEYS = { party = true, boss = true }

-- Forever's frame plate: the left part of the target's atlas (194 x 68 art px) with its name box and
-- bar slots. The frame is x0..x1, y0..y1; cutX / cutY are the piece edges (ends keep their size, the
-- middles stretch). The last piece runs on under the ring. Scale sets its size, with the ring.
local PLATE = {
    atlas = "UI-HUD-UnitFrame-Target-PortraitOn", artW = 194, artH = 68,
    x0 = 1, x1 = 131, y0 = 8, y1 = 57,
    -- the second row stretches with the height; rowDelta resizes a row by that many art pixels
    cutX = { 0, 8, 120, 145 }, cutY = { 6, 14, 24, 32, 39, 47, 51, 59 },
    rowDelta = { 0, -3, 0, 2, 0, 1, 0 },
    defaultScale = { player = 130, target = 130, focus = 100, party = 100, boss = 100 },   -- percent of Blizzard's size
    ringD = 61.8, ringX = 158.6,           -- Blizzard's ring on this art: its diameter and centre
    name   = { 4, 125, 11, 26 },           -- x from, x to, y from, y to
    -- the bars' art; mirrored files for right-to-left fill (a status bar crops an atlas from the left)
    health = { 4, 125, 29, 42, tex = "Interface\\AddOns\\FlareUI\\Media\\Bars\\FlareUI-Forever.tga",
               mirrored = "Interface\\AddOns\\FlareUI\\Media\\Bars\\FlareUI-Forever-Mirrored.tga" },
    power  = { 4, 125, 45, 53, tex = "Interface\\AddOns\\FlareUI\\Media\\Bars\\FlareUI-Forever-Mana.tga",
               mirrored = "Interface\\AddOns\\FlareUI\\Media\\Bars\\FlareUI-Forever-Mana-Mirrored.tga" },
    strip  = "UI-HUD-UnitFrame-Target-PortraitOn-Type",   -- the name box's reaction glow
}
-- (party and boss: the tiles' ring kinds)
Ring.PLATE_UNITS = { player = true, target = true, focus = true, party = true, boss = true }
Ring.STRIP_ATLAS = PLATE.strip
-- an art y -> where it lands once the rows are squeezed or stretched (rowDelta)
local function RowY(y)
    local cy, out = PLATE.cutY, PLATE.cutY[1]
    for i = 1, #cy - 1 do
        local a, b = cy[i], cy[i + 1]
        local length = (b - a) + (PLATE.rowDelta[i] or 0)
        if y <= b or i == #cy - 1 then return out + (y - a) * length / (b - a) end
        out = out + length
    end
end
-- The FlareUI Style preset: a new profile's and a first switch's frame settings, totems and default
-- positions (stored positions are dropped)
local FOREVER = {
    player = { border = "FlareUI Thin", portrait = "3d", width = 200, height = 60, powerHeight = 15, ringSize = 80 },
    target = { border = "FlareUI Thin", portrait = "3d", width = 200, height = 60, powerHeight = 15, ringSize = 80 },
    focus  = { border = "FlareUI Thin", portrait = "3d", width = 110, height = 35, ringSize = 47 },
    pet    = { height = 30 },
}
local FOREVER_TOTEMS = { size = 90, perRow = 3 }
-- the party (Party Style) and boss frames' FlareUI Style look
local FOREVER_TILES = {
    party = {
        showPlayer = false,
        classic = { width = 188, height = 50, powerHeight = 10, ringSize = 66, castHeight = 15, spacing = 12,
                    buffs = "ABOVE", debuffs = "ABOVE_RIGHT", auraSize = 18, bigDefensiveSize = 24, portrait = "3d" },
    },
    boss  = { width = 164, height = 50, powerHeight = 10, ringSize = 66, castHeight = 15, spacing = 12,
              buffs = "ABOVE", debuffs = "ABOVE_RIGHT", auraSize = 18 },
}

-- Edit Mode's defaults for the party or boss frames in the ring styles; nil in Addon Style
function Ring.TileDefaults(kind)
    if Ring.Style() == "addon" then return nil end
    -- partyGroup: the party frames' own switches
    if kind == "partyGroup" then return FOREVER_TILES.party end
    return kind == "party" and FOREVER_TILES.party.classic or FOREVER_TILES.boss
end
-- their default positions (the ring stands out past the outer side)
Ring.TILE_POSITIONS = {
    party = { point = "LEFT",  x = 65,  y = 0 },
    boss  = { point = "RIGHT", x = -88, y = 10 },
}
-- Forever Style's
Ring.PLATE_TILE_POSITIONS = {
    party = { point = "LEFT",  x = 71,  y = 0 },
    boss  = { point = "RIGHT", x = -93, y = 10 },
}
function Ring.TilePosition(kind)
    if Ring.PlateOn() then return Ring.PLATE_TILE_POSITIONS[kind] end
    return Ring.TILE_POSITIONS[kind]
end
-- this style's default positions (UnitFrames' and Totems' DEFAULT_POSITIONS)
Ring.POSITIONS = {
    player        = { point = "CENTER",      x = -286, y = -270 },
    target        = { point = "CENTER",      x = 286,  y = -270 },
    targettarget  = { point = "BOTTOM",      x = 236,  y = 251 },
    focus         = { point = "RIGHT",       x = -477, y = -256 },
    focustarget   = { point = "BOTTOMRIGHT", x = -487, y = 277 },
    pet           = { point = "BOTTOM",      x = -246, y = 270 },
    playercastbar = { point = "CENTER",      x = 0,    y = -221 },
}
Ring.TOTEM_POSITION = { point = "BOTTOM", x = -347, y = 225 }

-- The Forever Style preset, on top of the FlareUI Style setup it starts from
local PLATE_PRESET = {
    player = { portrait = "class" },
    target = { portrait = "class" },
    focus  = { portrait = "3d", powerText = true },
}
local PLATE_TOTEMS = { size = 95, perRow = 3 }
Ring.PLATE_POSITIONS = {
    player        = { point = "CENTER",      x = -286, y = -270 },
    target        = { point = "CENTER",      x = 286,  y = -270 },
    targettarget  = { point = "BOTTOM",      x = 234,  y = 249 },
    focus         = { point = "RIGHT",       x = -467, y = -263 },
    focustarget   = { point = "BOTTOMRIGHT", x = -478, y = 264 },
    pet           = { point = "BOTTOM",      x = -246, y = 268 },
    playercastbar = { point = "CENTER",      x = 0,    y = -221 },
}
Ring.PLATE_TOTEM_POSITION = { point = "BOTTOM", x = -352, y = 220 }

-- a FlareUI Style preset value, for Edit Mode's defaults
function Ring.PresetValue(unit, key)
    return FOREVER[unit] and FOREVER[unit][key]
end

-- this style's default positions: the frames', and the totems'
function Ring.DefaultPositions()
    if Ring.PlateOn() then return Ring.PLATE_POSITIONS, Ring.PLATE_TOTEM_POSITION end
    return Ring.POSITIONS, Ring.TOTEM_POSITION
end

-- this style's totem size and totems per row
function Ring.DefaultTotems()
    return Ring.PlateOn() and PLATE_TOTEMS or FOREVER_TOTEMS
end

-- the icon regions that move onto the ring's layer (UnitFrames' and the tiles' field names)
local RING_ICONS = { "RestIcon", "LeaderIcon", "PvPIcon", "ClassIcon", "QuestIcon", "RaidIcon", "ReadyIcon",
                     "RoleIcon", "StatusIcon" }
-- icon keys -> the BLIZZ entry they use (role: the PvP crest's spot; status: the portrait's middle)
local ICON_KEYS = { rest = "rest", leader = "leader", pvp = "pvp", classification = "classification",
                    quest = "quest", raidIcon = "raidIcon", readyCheck = "readyCheck",
                    role = "pvp", status = "readyCheck" }

--------------------------------------------------
-- 2. HELPERS
--------------------------------------------------
local LEM = LibStub("FlareEditMode")
local LSM = LibStub("LibSharedMedia-3.0")

local frames = {}   -- the ring frames, for the state events

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

-- what the ring takes a frame for: its unit (player, target, focus), or a tile's kind (party, boss)
local function Kind(f)
    return f.ringKind or f.unit
end

-- the frame's settings: the unit frame's, or the tile's own (f.ringDb)
local function Db(f)
    if f.ringDb then return f.ringDb() end
    return UnitDb(f.unit)
end

-- an Icons switch of the frame (udb.icons)
local function IconOn(f, key, default)
    local udb = Db(f)
    local store = udb and udb.icons and udb.icons[key]
    if store and store.shown ~= nil then return store.shown end
    return default or false
end

function Ring.On()
    local db = GetDb()
    if not db then return false end
    if not db.styleStart then Ring.StartStyle(db) end
    if not db.tileStyle then Ring.StartTileStyle(db) end
    if not db.plateTiles then Ring.StartPlateTiles(db) end
    return db.foreverStyle and true or false
end

-- this frame is drawn in a ring style (FlareUI Style or Forever Style)
function Ring.Applies(f)
    if not (f and f.Portrait) then return false end
    -- the tiles: both ring styles
    if f.ringKind then return Ring.Style() ~= "addon" end
    return RING_UNITS[f.unit] and Ring.On() or false
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

-- Forever Style has one fixed border (its border options are hidden)
local PLATE_BORDER = "FlareUI Thin"
function Ring.Border(name)
    if Ring.PlateOn() then return PLATE_BORDER end
    return name
end

-- this frame is drawn on Forever's frame plate
function Ring.Plate(f)
    return Ring.Applies(f) and Ring.PLATE_UNITS[Kind(f)] and Ring.PlateOn() or false
end

-- the ring's side (a tile: f.ringSide); Mirror only turns target's and focus's bars here
function Ring.Side(f)
    if f.ringKind then return f.ringSide or "LEFT" end
    if f.unit == "player" then return "LEFT" end
    if f.unit == "target" or f.unit == "focus" then return BLIZZ[f.unit].side end
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

-- the plate's screen pixels per art pixel for a ring of diameter D
local function PlateScale(D) return D / PLATE.ringD end
-- Forever Style's Scale (percent of Blizzard's size) writes the ring size and the height
local function ApplyPlateScale(udb, percent)
    local s = percent / 100
    udb.plateScale = math.floor(percent + 0.5)
    udb.ringSize = math.floor(PLATE.ringD * s + 0.5)
    udb.height = math.floor((PLATE.y1 - PLATE.y0) * s + 0.5)
end

function Ring.PlateDefaultScale(unit)
    return PLATE.defaultScale[unit] or 100
end

-- a tile's Scale, on its own settings
function Ring.ApplyPlateScale(settings, percent)
    if settings then ApplyPlateScale(settings, percent) end
end

function Ring.GetPlateScale(unit)
    local udb = UnitDb(unit)
    return udb and udb.plateScale or Ring.PlateDefaultScale(unit)
end

function Ring.SetPlateScale(unit, percent)
    local udb = UnitDb(unit)
    if udb then ApplyPlateScale(udb, percent) end
end

function Ring.PlateMinSize(f)
    local udb = Db(f) or {}
    local s = PlateScale(udb.ringSize or DefaultDiameter(udb.height))
    local fixedH = (RowY(PLATE.y1) - RowY(PLATE.y0)) - (RowY(PLATE.cutY[3]) - RowY(PLATE.cutY[2]))
    local fixedW = (PLATE.x1 - PLATE.x0) - (PLATE.cutX[3] - PLATE.cutX[2])
    -- a few pixels of name box and middle at least
    return math.ceil((fixedW + 12) * s), math.ceil((fixedH + 4) * s)
end

-- D, R, H, side, centre (from the frame's edge, positive inside), k (Blizzard's ring to this one)
local function Geometry(f)
    local udb = Db(f) or {}
    local H = udb.height or 44
    local D = udb.ringSize or Ring.DefaultSize(Kind(f), H)
    local R = D / 2
    local g = { D = D, R = R, side = Ring.Side(f), k = D / BLIZZ[Kind(f)].D }
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

-- how far the ring stands out past the frame's edge (a horizontal party's spacing)
function Ring.Overhang(f)
    local g = Geometry(f)
    return math.max(0, math.ceil(g.R - g.centre))
end

-- the name's extra inset on the ring's side, from the health bar's edge: clear of the portrait
function Ring.TextPad(f)
    local g = Geometry(f)
    return math.max(0, math.ceil(g.centre + g.R) - BAR_INSET + 3)
end

-- An element's centre (from the ring's centre) and size, from its BLIZZ entry; nil without one
local function Place(f, g, e, atlasOverride)
    if not e then return nil end
    -- e.frame: the entry is in another frame's coordinates
    local blizz = BLIZZ[e.frame or Kind(f)]
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

-- The PvP crest's centre (from the ring's centre) and size: off the level disc, mirrored with it
local function PvPSpot(f, g)
    local blizz = BLIZZ[Kind(f)]
    local e = blizz.pvp
    if not e then return nil end
    local lx, ly, lw = Place(f, g, blizz.level)
    if not lx then return nil end
    local sign = (g.side ~= blizz.side) and -1 or 1
    local x, y = lx + sign * e.dx * lw, ly + e.dy * lw
    -- the crest has no disc: its top sits where the disc's top would be, moved by e.move (Blizzard px)
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

    -- the PvP crest's layer, above the dragon frame; PvPDisc only marks the crest's spot (never drawn)
    ring.PvP = CreateFrame("Frame", nil, ring)
    ring.PvP:SetAllPoints(f)
    ring.PvPDisc = ring.PvP:CreateTexture(nil, "ARTWORK")
    ring.PvPDisc:Hide()

    -- the player's PvP timer, beside the crest
    if Kind(f) == "player" then
        ring.PvPTimer = ring.PvP:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ring.PvPTimer:SetPoint("RIGHT", f.PvPIcon or ring.PvPDisc, "LEFT", 0, 0)
        ring.PvPTimer:Hide()
    end
    -- the PvP countdown's OnUpdate, set while it runs
    ring.Ticker = CreateFrame("Frame", nil, ring)

    f.RingFrame = ring
    return ring
end

--------------------------------------------------
-- 5. LAYOUT
--------------------------------------------------
-- places a region at a BLIZZ element; false without one
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
    local blizz = BLIZZ[Kind(f)]
    frames[f] = true

    -- bottom to top above the frame's own levels: portrait, ring, icons, level disc, PvP crest (the
    -- combo gems above all)
    f.Portrait:SetFrameLevel(level + 9)
    ring:SetFrameLevel(level + 10)
    ring.Icons:SetFrameLevel(level + 11)
    ring.Disc:SetFrameLevel(level + 12)
    ring.PvP:SetFrameLevel(level + 13)
    for _, key in ipairs(RING_ICONS) do
        local region = f[key]
        if region then
            -- where it goes back to (Reset)
            if not region.ringHome then region.ringHome = region:GetParent() end
            -- the PvP crest, and the party's role icon in its place, over the level disc
            region:SetParent((key == "PvPIcon" or key == "RoleIcon") and ring.PvP or ring.Icons)
        end
    end

    ring:ClearAllPoints()
    ring:SetSize(g.D, g.D)
    ring:SetPoint("CENTER", f, left and "LEFT" or "RIGHT", left and g.centre or -g.centre, 0)
    ring.hasArt = Crop(ring.Art, ART[Kind(f)], g.side)
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
    local e = BLIZZ[Kind(f)].level
    PlaceRegion(f, g, ring.Disc, e)
    -- a little under its atlas size, round the same centre
    local w, h = ring.Disc:GetSize()
    ring.Disc:SetSize(w * LEVEL_SCALE, h * LEVEL_SCALE)
    -- the skull and the number at the disc's own scale
    local k = g.D / BLIZZ[e.frame or Kind(f)].D * LEVEL_SCALE
    if SetAtlasSafe(ring.Skull, SKULL) then
        local info = C_Texture.GetAtlasInfo(SKULL)
        ring.Skull:SetSize(info.width * k, info.height * k)
    end
    -- Show Level: the disc goes with the number
    local udb = Db(f)
    ring.Disc:SetShown(udb and udb.showLevel and true or false)
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
-- Forever's plate behind the bars, cut from the target's atlas: ends keep their art size, middles
-- stretch. Mirrored when the ring is on the left.
--------------------------------------------------
-- an edge in art pixels -> its anchor on the frame: the side it hangs from and the offset
local function EdgeX(x, s)
    if x <= PLATE.cutX[2] then return "LEFT", (x - PLATE.x0) * s end
    return "RIGHT", (x - PLATE.x1) * s
end
local function EdgeY(y, s)
    if y <= PLATE.cutY[2] then return "TOP", (RowY(PLATE.y0) - RowY(y)) * s end
    return "BOTTOM", (RowY(PLATE.y1) - RowY(y)) * s
end

-- Puts a region over art rect x1..x2, y1..y2 of the plate (flip: mirrored, ring on the left)
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
    for i = 1, 3 * (#PLATE.cutY - 1) do plate.pieces[i] = plate:CreateTexture(nil, "BACKGROUND") end
    -- the name box's reaction glow, and an anchor for the name
    plate.Strip = plate:CreateTexture(nil, "BORDER")
    plate.NameBox = CreateFrame("Frame", nil, plate)
    f.PlateFrame = plate
    return plate
end

-- A bar over its slot in the frame's Bar Texture (FlareUI Forever: the plate's own bar art); the
-- fill direction must be set first
local function PlaceBar(bar, f, s, flip, slot)
    PlaceOnPlate(bar, f, s, flip, slot[1], slot[2], slot[3], slot[4])
    -- for the heal and absorb overlays (LayoutIndicators): the colour's insets and the bar's length
    local length = (f:GetWidth() or 0) - ((slot[1] - PLATE.x0) + (PLATE.x1 - slot[2])) * s
    bar.FlareUI_PlateInset = { x = 0, y = 0, length = length }
    local udb = Db(f)
    local name = udb and udb.texture
    if name and name ~= "" and name ~= "FlareUI Forever" and LSM:IsValid("statusbar", name) then
        bar:SetStatusBarTexture(LSM:Fetch("statusbar", name))
    else
        bar:SetStatusBarTexture(bar:GetReverseFill() and slot.mirrored or slot.tex)
    end
    if bar.bg then bar.bg:SetAlpha(0) end   -- the slot is the background
end

-- Lays out the plate and puts the bars in its slots (Forever Style)
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
        for row = 1, #cy - 1 do
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

-- the name box's glow in the unit's reaction colour (none on the player's)
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
        bar.FlareUI_PlateInset = nil
    end
end
Ring.HidePlate = HidePlate

-- back to Addon Style: levels, parents and masks as UnitFrames made them
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
    ring.Disc:Hide()
    for _, key in ipairs(RING_ICONS) do
        local region = f[key]
        if region then region:SetParent(region.ringHome or f.Overlay) end
    end
    if f.Portrait.ringMasked then
        f.Portrait.Tex:RemoveMaskTexture(ring.PortraitMask)
        f.Portrait.ringMasked = nil
    end
end

-- An icon's place on the ring: point, relativeTo, relativePoint, x, y, width, height; nil without one
function Ring.IconSpot(f, key)
    local entryKey = ICON_KEYS[key]
    local e = entryKey and BLIZZ[Kind(f)] and BLIZZ[Kind(f)][entryKey]
    if not e or not f.RingFrame then return nil end
    local g = Geometry(f)
    local dx, dy, w, h
    if key == "pvp" or key == "role" then
        -- the crest's atlas size against the disc's
        dx, dy, w, h = PvPSpot(f, g)
        local crest, disc = C_Texture.GetAtlasInfo(PVP_ICONS.Horde), C_Texture.GetAtlasInfo(SMALL_CIRCLE)
        if dx and crest and disc and crest.width and disc.width and disc.width > 0 then
            w, h = w * crest.width / disc.width, h * crest.height / disc.height
        end
        -- a party's role icon: square, the crest's width
        if key == "role" and w then h = w end
    else
        dx, dy, w, h = Place(f, g, e)
    end
    if not dx then return nil end
    -- the crown: 2 px under the frame's top edge, clear of the auras above
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

-- The state art: PvP crest, elite / rare frame, skull, status glow, corner piece, combat swords and
-- the threat flash. Secret values hide the art.
function Ring.Update(f)
    local ring = f.RingFrame
    if not ring or not Ring.Applies(f) then return end
    Ring.UpdatePlate(f)
    local unit, kind = f.unit, Kind(f)
    local blizz = BLIZZ[kind]
    local exists = Readable(UnitExists(unit))
    -- a boss tile's Edit Mode sample (f.sample): its art as a live boss would have it
    local sample = LEM:IsInEditMode() and f.ringKind and f.sample

    -- PvP: the frame's PvP icon, re-arted as Forever's crest
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
        if kind == "target" and ring.comboPvP ~= nil and ring.comboPvP ~= (shown and true or false)
            and combo and combo:GetParent() == f then
            Ring.PlaceCombo(combo, f)
        end
    end

    -- the elite / rare frame, as Forever picks it (gold elite, silver rare, winged gold boss)
    ring.Boss:Hide()
    if blizz.boss and (exists or sample) and GetBossPortraitFrameData then
        local ok, atlas, ox, oy
        if sample then
            ok, atlas, ox, oy = true, Ring.SampleBossArt(f.index)
        else
            local classification = Readable(UnitClassification(unit))
            ok, atlas, ox, oy = pcall(GetBossPortraitFrameData, unit, classification)
        end
        if ok and atlas and SetAtlasSafe(ring.Boss, atlas) then
            local g = Geometry(f)
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

    -- the level disc's skull for a "??" unit (10+ levels higher): target and focus with "High Level
    -- Skull" on; a red "??" everywhere else
    local level = Readable(UnitLevel(unit))
    local skull = exists and level and level < 0 and (f.unit == "target" or f.unit == "focus")
        and IconOn(f, "highSkull", true) or false
    ring.Skull:SetShown(skull and ring.Disc:IsShown())
    f.Level:SetAlpha(skull and 0 or 1)

    -- the player: red glow and swords in combat, else yellow glow and corner piece resting
    if kind == "player" then
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

    Ring.UpdateThreat(f)
end

-- Threat: the ring's flash in Blizzard's colours. Tiles off the plate use their border instead; on
-- it a party member flashes for its own aggro, a boss for the player's threat on it.
function Ring.UpdateThreat(f)
    local ring = f.RingFrame
    if not ring then return end
    if f.ringKind and not Ring.Plate(f) then ring.Flash:Hide() return end
    local unit, kind = f.unit, Kind(f)
    local exists = unit and Readable(UnitExists(unit))
    local status
    if kind == "player" then
        status = Readable(UnitThreatSituation("player"))
    elseif kind == "party" then
        status = exists and Readable(UnitThreatSituation(unit)) or nil
    elseif exists then
        status = Readable(UnitThreatSituation("player", unit))
    end
    if status and status > 0 and GetThreatStatusColor and not LEM:IsInEditMode() and IconOn(f, "threatGlow", true) then
        local r, gg, b = GetThreatStatusColor(status)
        ring.Flash:SetVertexColor(r, gg, b, 1)
        ring.Flash:Show()
    else
        ring.Flash:Hide()
    end
end

-- The state art follows combat, resting and threat without a full layout. Unit events only for the
-- ring units (threat fires for every group member); RegisterUnitEvent takes two units, so focus has
-- a frame of its own.
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
-- Blizzard's combo arc round its target ring, scaled to this one (mirrored on the left). Anchors
-- only: the count may be secret.
function Ring.PlaceCombo(combo, f)
    if Kind(f) ~= "target" or not f.RingFrame then return false end
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
-- deep copy of a table's own values (AceDB's defaults stay behind their metatables)
local function CopyRaw(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = CopyRaw(x) end
    return t
end

-- empties a table; AceDB's tables (with metatables) are kept, emptied
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

-- FlareUI Style's party and boss look on the setup in use. untouched: only where nothing is set;
-- clear: back to the defaults
local function ApplyTilePreset(db, mode)
    local function Apply(dst, values)
        for field, value in pairs(values) do
            if type(value) == "table" then
                if dst[field] then Apply(dst[field], value) end
            elseif mode == "clear" then
                dst[field] = nil
            elseif mode ~= "untouched" or rawget(dst, field) == nil then
                dst[field] = value
            end
        end
    end
    for key, preset in pairs(FOREVER_TILES) do
        local t = db[key]
        if t then
            Apply(t, preset)
            -- their positions: the style's defaults
            if mode ~= "untouched" then t.layouts = {} end
        end
    end
end

-- the Forever preset on the setup in use
local function ApplyForeverPreset(db)
    ApplyTilePreset(db)
    for unit, keys in pairs(FOREVER) do
        local udb = db.units and db.units[unit]
        if udb then for key, value in pairs(keys) do udb[key] = value end end
    end
    if db.totems then for key, value in pairs(FOREVER_TOTEMS) do db.totems[key] = value end end
    db.layouts = {}
    db.totemLayouts = {}
end

-- Once (db.plateTiles): a Forever Style setup without ring tiles takes FlareUI Style's party and boss setup
local function CopyTiles(dst, src)
    if not (dst and src) then return end
    for key in pairs(TILE_KEYS) do
        if src[key] then dst[key] = CopyRaw(src[key]) end
    end
end
function Ring.StartPlateTiles(db)
    db.plateTiles = true
    local slots = db.styleProfiles
    if not slots then return end
    local flareui = (db.foreverStyle and not db.plateStyle) and db or slots.forever
    if db.foreverStyle and db.plateStyle then
        CopyTiles(db, flareui)
    elseif slots.plate then
        CopyTiles(slots.plate, flareui)
    end
end

-- Once (db.tileStyle): a FlareUI Style profile gets the party and boss look where nothing is set
function Ring.StartTileStyle(db)
    db.tileStyle = true
    if db.foreverStyle and not db.plateStyle then ApplyTilePreset(db, "untouched") end
end

-- A new profile starts in the Forever style with its preset (once: db.styleStart)
function Ring.StartStyle(db)
    db.styleStart = true
    db.tileStyle = true
    ApplyForeverPreset(db)
    db.foreverStyle = true
end

-- Every "enabled" below the unit frames table survives a switch
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

-- Forever Style's first time: the frames take Blizzard's proportions at the default Scale
local function ApplyPlatePreset(db)
    for unit in pairs(Ring.PLATE_UNITS) do
        local udb = db.units and db.units[unit]
        if udb then ApplyPlateScale(udb, Ring.PlateDefaultScale(unit)) end
    end
    for unit, keys in pairs(PLATE_PRESET) do
        local udb = db.units and db.units[unit]
        if udb then for key, value in pairs(keys) do udb[key] = value end end
    end
    if db.totems then for key, value in pairs(PLATE_TOTEMS) do db.totems[key] = value end end
    -- the stored positions go, so the style's defaults apply
    db.layouts = {}
    db.totemLayouts = {}
end

-- each style's styleProfiles slot (saved names: never rename)
local STYLE_SLOT = { addon = "usual", flareui = "forever", forever = "plate" }

-- Switches the style: the setup in use is stored and the new style's restored. First time: Forever
-- Style starts from FlareUI Style's setup, FlareUI Style from its preset, Addon Style from defaults.
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
    -- a stored setup without party / boss entries leaves theirs as they are
    local function Restore(back)
        local keepTiles = {}
        for k in pairs(TILE_KEYS) do keepTiles[k] = back[k] == nil end
        for k, v in pairs(db) do
            if not SHARED_KEYS[k] and not keepTiles[k] then
                if type(v) == "table" and getmetatable(v) then Clear(v) else db[k] = nil end
            end
        end
        Fill(db, back, true)
        if style == "addon" and current ~= "addon" and (keepTiles.party or keepTiles.boss) then ApplyTilePreset(db, "clear") end
        -- into FlareUI or Forever Style: the ring tiles' look where nothing is set
        if style ~= "addon" and (keepTiles.party or keepTiles.boss) then ApplyTilePreset(db, "untouched") end
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
        ApplyForeverPreset(db)
    else
        -- Addon Style's first time: the presets' values and positions back to the defaults
        for _, preset in ipairs({ FOREVER, PLATE_PRESET }) do
            for unit, keys in pairs(preset) do
                local udb = db.units and db.units[unit]
                if udb then for key in pairs(keys) do udb[key] = nil end end
            end
        end
        for unit in pairs(Ring.PLATE_UNITS) do
            local udb = db.units and db.units[unit]
            if udb then udb.plateScale = nil end
        end
        if db.totems then for key in pairs(FOREVER_TOTEMS) do db.totems[key] = nil end end
        ApplyTilePreset(db, "clear")
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
-- Edit Mode's Portrait Size default: the preset's, else from the frame's height
function Ring.DefaultSize(unit, height)
    if unit == "party" or unit == "boss" then return TILE_RING_D end
    local preset = FOREVER[unit] and FOREVER[unit].ringSize
    if preset then return preset end
    local udb = UnitDb(unit)
    return DefaultDiameter(udb and udb.height)
end
