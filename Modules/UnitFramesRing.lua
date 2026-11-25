local _, ns = ...

--------------------------------------------------
-- FOREVER STYLE UNIT FRAMES
-- The ring styles: Forever's bronze portrait ring beside the player, target, focus, party and boss
-- frames (FlareUI Style), or on Forever's frame plate (Forever Style). The pet joins them with Simple
-- Pet Frame off. UnitFrames.lua and the tile modules call in at their layout points; the style switch
-- lives here too.
--------------------------------------------------
local Ring = {}
ns.UFRing = Ring

-- Both ring styles: Blizzard's gold plate, ring and boss dragon toned down to the bronze of Forever's other
-- frames (the minimap's heavy bronze, the bars' border), so they no longer stand out (picked in
-- game). FlareUI Style's ring had its own darker 0.80, 0.70, 0.56 until then.
Ring.PLATE_TINT = { 0.88, 0.80, 0.66 }
function Ring.TintPlateArt(tex)
    local t = Ring.PLATE_TINT
    tex:SetVertexColor(t[1], t[2], t[3])
end

--------------------------------------------------
-- 1. ART AND PLACEMENT
-- The ring is the game's atlas (UI-HUD-UnitFrame-*-PortraitOn), cropped and masked to the ring; the
-- art is drawn from the game, not copied into FlareUI (LICENSES/README.txt).
-- Everything round the ring sits where Blizzard puts it: each anchor on Blizzard's 232 x 100 frame,
-- taken from Blizzard's ring centre and scaled by ring size over Blizzard's; mirrored on the other side.
-- The ring is centred on the frame's middle, its end tucked under it so the bars start where their
-- corners meet the rim.
--------------------------------------------------
-- (the small frames: only a styled one has a portrait, which Ring.Applies asks for)
local RING_UNITS = { player = true, target = true, focus = true, pet = true, targettarget = true, focustarget = true }
-- the small frames, with the frame each takes its size and look from. Target of Focus too follows
-- the target: half of the focus frame would be too small to read
local SMALL_FRAMES = { pet = "player", targettarget = "target", focustarget = "target" }
-- their saved keys (<unit>Setup, <unit>Stash, <unit>Positions), built once: Ring.On checks them on every call
local SMALL_KEYS = {}
for unit in pairs(SMALL_FRAMES) do SMALL_KEYS[unit] = { unit .. "Setup", unit .. "Stash", unit .. "Positions" } end

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
ART.pet = ART.target
ART.targettarget = ART.target
ART.focustarget = ART.target
local CIRCLE_MASK   = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local SMALL_CIRCLE  = "UI-HUD-UnitFrame-SmallCircle"
local PORTRAIT_SHARE = 0.86   -- the portrait inside the ring, of its diameter
-- A dark disc behind the portrait, out under the rim: the art's
-- opening is off-centre and wider than the portrait at the bottom and outer side (0.84-0.90 of the
-- radius), so the world showed through a thin crescent there
local PORTRAIT_BACK_SHARE = 0.94
-- FlareUI Style (no plate): the whole art, cut to a circle so the art's join to the plate (a tail
-- on the bars' side) doesn't show. The art's rim reaches further out on the outer side, so
-- the circle is larger and moved outwards: its edge stays CLEAN_RING_BARS of the ring's diameter
-- from the centre on the bars' side and reaches CLEAN_RING_OUTER on the outer side (rim and shadow)
local CLEAN_RING_BARS, CLEAN_RING_OUTER = 0.49, 0.585
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
    -- the target's icons, in the same spots
    pvp = BLIZZ.target.pvp, leader = BLIZZ.target.leader, quest = BLIZZ.target.quest,
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
    -- the target's PvP crest spot: the flag carriers' faction crest (the boss frames show none)
    pvp = BLIZZ.target.pvp,
}
-- The styled pet: the player frame, small, with no icons on its ring
BLIZZ.pet = {
    centre = BLIZZ.player.centre, D = BLIZZ.player.D, side = "LEFT",
    level = BLIZZ.player.level,
}
-- The styled target of target and target of focus: small, with no icons on the ring. The ring on the
-- left, as Blizzard's own and the pet's: their bars and texts are laid out for a portrait on the
-- left, so a ring on the right would cover the bar's end and its text
BLIZZ.targettarget = {
    centre = BLIZZ.player.centre, D = BLIZZ.player.D, side = "LEFT",
    level = BLIZZ.player.level,
}
BLIZZ.focustarget = BLIZZ.targettarget
-- the small frames' size, of the frame they follow, and their Portrait Size default
local PET_SHARE, PET_RING_D = 0.5, 40
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
local STATUS_RESTING = { 1.0, 0.82, 0.35 }
local STATUS_COMBAT  = { 1.0, 0.22, 0.18 }
-- the player's rest / combat state tints the ring's own border, pulsing softly: alpha low, high,
-- seconds each way (the ring art is copied in grey, coloured, over the art)
local STATUS_PULSE   = { 0.12, 0.55, 1.2 }
local TINT_RIM_SHARE = 1.04   -- the tint's circle, of the ring's diameter (the rim's outer edge)
-- Blizzard's level text (WhiteLargeNumberFont) at 1x
local LEVEL_FONT, LEVEL_FONT_SIZE = "Fonts\\FRIZQT__.TTF", 14
-- the level disc, number and skull, of the atlas size (as Blizzard draws them)
local LEVEL_SCALE = 0.94

-- Each style keeps a whole unit frames setup, swapped on the switch (a reload follows); these keys
-- are shared. So is every option of the settings page's Unit Frames section: those are general.
local SHARED_KEYS = { enabled = true, foreverStyle = true, plateStyle = true, styleProfiles = true, editSections = true,
                      raid = true, resource = true, styleStart = true, tileStyle = true, plateTiles = true,
                      simplePet = true, simpleTargetOf = true, levelSize = true, palette = true, visibility = true, classColor = true, fullNames = true,
                      auraStyle = true, auraTimer = true, font = true, fontPower = true, fontCast = true, auraFont = true,
                      auraCountFont = true, auraCountFontSeeded = true, styleSavesThin = true,
                      -- (frameFonts, each frame's fonts, is NOT shared: every style keeps its own)
                      frameFontsSeeded = true, castTimeSeeded = true }
-- a stored setup may lack these
local TILE_KEYS = { party = true, boss = true }

-- Forever's frame plate: the left part of the target's atlas (194 x 68 art px) with its name box and
-- bar slots. The frame is x0..x1, y0..y1; cutX / cutY are the piece edges (ends keep their size, the
-- middles stretch). The last piece runs on under the ring. Scale sets its size, with the ring.
local PLATE = {
    atlas = "UI-HUD-UnitFrame-Target-PortraitOn", artW = 194, artH = 68,
    x0 = 1, x1 = 131, y0 = 8, y1 = 57,
    -- the second row stretches with the height; rowDelta resizes a row by that many art pixels.
    -- the last column (127 on) is Blizzard's ring rim: it keeps rowDelta whatever Power Height
    -- does to the rows, so the rim never bends (Ring.LayoutPlate)
    cutX = { 0, 8, 120, 127, 145 }, cutY = { 6, 14, 24, 32, 39, 47, 51, 59 },
    rowDelta = { 0, -3, 0, 2, 0, 1, 0 },
    defaultScale = { player = 130, target = 130, focus = 100, party = 100, boss = 100, pet = 75,
                     targettarget = 65, focustarget = 65 },   -- percent of Blizzard's size
    ringD = 61.8, ringX = 158.6,           -- Blizzard's ring on this art: its diameter and centre
    ringRise = 0.64,                       -- its centre above the plate's, in art pixels
    maskLeft = "Interface\\AddOns\\FlareUI\\Media\\Masks\\RingPlateLeft",     -- the ring art's mask: ring on the left
    maskRight = "Interface\\AddOns\\FlareUI\\Media\\Masks\\RingPlateRight",
    name   = { 4, 125, 11, 26 },           -- x from, x to, y from, y to
    -- the bars' art; mirrored files for right-to-left fill (a status bar crops an atlas from the left)
    health = { 4, 125, 29, 42, tex = "Interface\\AddOns\\FlareUI\\Media\\Bars\\FlareUI-Forever.tga",
               mirrored = "Interface\\AddOns\\FlareUI\\Media\\Bars\\FlareUI-Forever-Mirrored.tga" },
    power  = { 4, 125, 45, 53, tex = "Interface\\AddOns\\FlareUI\\Media\\Bars\\FlareUI-Forever-Mana.tga",
               mirrored = "Interface\\AddOns\\FlareUI\\Media\\Bars\\FlareUI-Forever-Mana-Mirrored.tga" },
    strip  = "UI-HUD-UnitFrame-Target-PortraitOn-Type",   -- the name box's reaction glow
    stripRight = 131, stripTop = 10,       -- where Blizzard's anchors put the glow on this art
}
-- (party and boss: the tiles' ring kinds)
Ring.PLATE_UNITS = { player = true, target = true, focus = true, party = true, boss = true, pet = true,
                     targettarget = true, focustarget = true }
Ring.STRIP_ATLAS = PLATE.strip
-- Power Height on the plate: the power slot's height in art pixels; 0 = no power
-- bar. The separator moves: row 4 (inside the health slot) gives or takes what row 6 (inside the
-- power slot) takes or gives. Off folds the separator's row (5) and row 6 into row 4, and the power
-- slot's bottom edge (row 7) closes the health slot.
Ring.PLATE_POWER = { default = 9, min = 4, max = 15 }
PLATE.healthFull = { PLATE.health[1], PLATE.health[2], PLATE.health[3], 53, tex = PLATE.health.tex,
                     mirrored = PLATE.health.mirrored }
-- Mana on Shapeshift: Blizzard's player plate with two power slots, unused on
-- Forever. Its upper part is the target's plate, mirrored and 4 art pixels lower (measured on the sheet:
-- x there = 197 - x here), so only what is below the power slot comes from it: the last row, 11 longer.
-- It hangs below the frame, which can't resize in a fight. Two more pieces carry its corner on under the
-- ring; the outer one is cut to a circle, as Blizzard's ring stands a little further out than ours.
PLATE.two = {
    atlas = "UI-HUD-UnitFrame-Player-PortraitOn-ClassResource", artW = 198, artH = 74, flipX = 197, downY = 4,
    from = 51, to = 70, drop = 11,         -- the last row's y here, and how much lower it ends (59 to 70)
    under = { 145, 158.6, 192 },           -- the two pieces under the ring: x from, between, to
    maskD = 62, maskX = 154.6, maskY = 36.9,   -- the outer piece's circle
    slot = { PLATE.power[1], PLATE.power[2], 56, 63.5, tex = PLATE.power.tex, mirrored = PLATE.power.mirrored },
}
local plateRows = {}
-- the rows' deltas for a power slot of that height
local function PlateRows(power)
    if not power or power == Ring.PLATE_POWER.default then return PLATE.rowDelta end
    if plateRows[power] then return plateRows[power] end
    local rows, cy = {}, PLATE.cutY
    for i, d in ipairs(PLATE.rowDelta) do rows[i] = d end
    if power == 0 then
        local r5 = (cy[6] - cy[5]) + rows[5]
        local r6 = (cy[7] - cy[6]) + rows[6]
        rows[4], rows[5], rows[6] = rows[4] + r5 + r6, rows[5] - r5, rows[6] - r6
    else
        local e = power - Ring.PLATE_POWER.default
        rows[4], rows[6] = rows[4] - e, rows[6] + e
    end
    plateRows[power] = rows
    return rows
end
-- an art y -> where it lands once the rows are squeezed or stretched (rowDelta, or a frame's rows)
local function RowY(y, rows)
    rows = rows or PLATE.rowDelta
    local cy, out = PLATE.cutY, PLATE.cutY[1]
    for i = 1, #cy - 1 do
        local a, b = cy[i], cy[i + 1]
        local length = (b - a) + (rows[i] or 0)
        if y <= b or i == #cy - 1 then return out + (y - a) * length / (b - a) end
        out = out + length
    end
end
-- The FlareUI Style preset: a new profile's and a first switch's frame settings, totems and default
-- positions (stored positions are dropped)
local FOREVER = {
    player = { border = "FlareUI Thin", portrait = "3d", width = 200, height = 60, powerHeight = 15, ringSize = 80 },
    target = { border = "FlareUI Thin", portrait = "3d", width = 200, height = 60, powerHeight = 15, ringSize = 80 },
    focus  = { border = "FlareUI Thin", portrait = "3d", width = 136, height = 35, ringSize = 47 },
    pet    = { height = 30 },
}
local FOREVER_TOTEMS = { size = 90, perRow = 2 }
-- the party (Party Style) and boss frames' FlareUI Style look
local FOREVER_TILES = {
    party = {
        showPlayer = false,
        classic = { width = 188, height = 50, powerHeight = 10, ringSize = 66, castHeight = 15, spacing = 14,
                    buffs = "ABOVE", debuffs = "ABOVE_RIGHT", auraSize = 18, portrait = "3d" },
    },
    boss  = { width = 164, height = 50, powerHeight = 10, ringSize = 66, castHeight = 15, spacing = 14,
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
    party = { point = "LEFT",  x = 64,  y = 0 },
    boss  = { point = "RIGHT", x = -88, y = 10 },
    flag  = { point = "RIGHT", x = -88, y = 204 },
}
-- Forever Style's
Ring.PLATE_TILE_POSITIONS = {
    party = { point = "LEFT",  x = 75,  y = 0 },
    boss  = { point = "RIGHT", x = -93, y = 10 },
    flag  = { point = "RIGHT", x = -93, y = 203 },
}
function Ring.TilePosition(kind)
    if Ring.PlateOn() then return Ring.PLATE_TILE_POSITIONS[kind] end
    return Ring.TILE_POSITIONS[kind]
end
-- this style's default positions (UnitFrames' and Totems' DEFAULT_POSITIONS)
Ring.POSITIONS = {
    player        = { point = "CENTER",      x = -286, y = -270 },
    target        = { point = "CENTER",      x = 286,  y = -270 },
    targettarget  = { point = "BOTTOM",      x = 236,  y = 240 },
    focus         = { point = "RIGHT",       x = -459, y = -256 },
    focustarget   = { point = "BOTTOMRIGHT", x = -495, y = 266 },
    pet           = { point = "BOTTOM",      x = -236, y = 258 },
    playercastbar = { point = "CENTER",      x = 0,    y = -221 },
}
Ring.TOTEM_POSITION = { point = "BOTTOM", x = -357, y = 241 }
-- the styled pet's size: FlareUI Style's height, Forever Style's Scale
Ring.PET_RING_HEIGHT, Ring.PET_PLATE_SCALE = 35, 75
-- the styled pet's (Simple Pet Frame off; the simple one keeps POSITIONS' pet)
Ring.PET_POSITION = { point = "BOTTOM", x = -236, y = 258 }

-- the styled target of target and target of focus (Simple "Target Of" off; the simple ones keep POSITIONS')
Ring.TARGET_OF_POSITIONS = {
    targettarget = { point = "BOTTOM",      x = 236,  y = 240 },
    focustarget  = { point = "BOTTOMRIGHT", x = -495, y = 266 },
}

-- The Forever Style preset, on top of the FlareUI Style setup it starts from
local PLATE_PRESET = {
    player = { portrait = "class" },
    target = { portrait = "class" },
    focus  = { portrait = "3d", powerText = "value", width = 146 },
}
local PLATE_TOTEMS = { size = 95, perRow = 2 }
Ring.PLATE_POSITIONS = {
    player        = { point = "CENTER",      x = -286, y = -270 },
    target        = { point = "CENTER",      x = 286,  y = -270 },
    targettarget  = { point = "BOTTOM",      x = 238,  y = 236 },
    focus         = { point = "RIGHT",       x = -430, y = -263 },
    focustarget   = { point = "BOTTOMRIGHT", x = -474, y = 250 },
    pet           = { point = "BOTTOM",      x = -238, y = 253 },
    playercastbar = { point = "CENTER",      x = 0,    y = -221 },
}
Ring.PLATE_TOTEM_POSITION = { point = "BOTTOM", x = -369, y = 237 }
Ring.PLATE_PET_POSITION = { point = "BOTTOM", x = -238, y = 253 }
Ring.PLATE_TARGET_OF_POSITIONS = {
    targettarget = { point = "BOTTOM",      x = 238,  y = 236 },
    focustarget  = { point = "BOTTOMRIGHT", x = -474, y = 250 },
}

-- a FlareUI Style preset value, for Edit Mode's defaults
function Ring.PresetValue(unit, key)
    -- Forever Style's own values over FlareUI Style's (its preset starts from that one)
    local plate = Ring.PlateOn() and PLATE_PRESET[unit]
    if plate and plate[key] ~= nil then return plate[key] end
    return FOREVER[unit] and FOREVER[unit][key]
end

-- this style's default positions: the frames', and the totems'
function Ring.DefaultPositions()
    if Ring.PlateOn() then return Ring.PLATE_POSITIONS, Ring.PLATE_TOTEM_POSITION end
    return Ring.POSITIONS, Ring.TOTEM_POSITION
end

-- this style's default position for the styled pet
function Ring.PetPosition()
    return Ring.PlateOn() and Ring.PLATE_PET_POSITION or Ring.PET_POSITION
end

-- this style's default position for a styled target of target or target of focus
function Ring.TargetOfPosition(unit)
    return (Ring.PlateOn() and Ring.PLATE_TARGET_OF_POSITIONS or Ring.TARGET_OF_POSITIONS)[unit]
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
    -- a settings preview's sample, while it is laid out (UnitFrames' UF.DrawSample)
    local sample = ns.UFSample
    if sample and sample.units[unit] then return sample.units[unit] end
    local db = GetDb()
    return db and db.units and db.units[unit]
end

local function Readable(v)
    if canaccessvalue(v) then return v end
end

-- what the ring takes a frame for: its unit (player, target, focus), or a tile's kind (party, boss)
local function Kind(f)
    return f.ringKind or f.fuiUnit
end

-- the frame's settings: the unit frame's, or the tile's own (f.ringDb)
local function Db(f)
    if f.ringDb then return f.ringDb() end
    return UnitDb(f.fuiUnit)
end

-- an Icons switch of the frame (udb.icons)
local function IconOn(f, key, default)
    local udb = Db(f)
    local store = udb and udb.icons and udb.icons[key]
    if store and store.shown ~= nil then return store.shown end
    return default or false
end

-- Threat Glow / Combat Glow (Look; udb.threatGlow, udb.combatGlow, a tile's in its own settings): on
-- unless saved off
function Ring.GlowOn(f, key)
    local udb = Db(f)
    return not (udb and udb[key] == false)
end

function Ring.On()
    if ns.UFSample then return ns.UFSample.style ~= "addon" end
    local db = GetDb()
    if not db then return false end
    if not db.styleStart then Ring.StartStyle(db) end
    if not db.tileStyle then Ring.StartTileStyle(db) end
    if not db.plateTiles then Ring.StartPlateTiles(db) end
    -- once: a style stored in full is cut down to its changes (Ring.StyleChanges)
    if not db.styleSavesThin then
        db.styleSavesThin = true
        for slot, setup in pairs(db.styleProfiles or {}) do
            if type(setup) == "table" then db.styleProfiles[slot] = Ring.StyleChanges(setup) end
        end
    end
    Ring.SyncPetSetup(db)
    return db.foreverStyle and true or false
end

-- Simple Pet Frame is off, in a ring style: the pet follows the style (a reload applies it)
function Ring.PetStyled()
    local db = GetDb()
    return Ring.On() and db.simplePet == false or false
end

-- Simple "Target Of" is off, in a ring style: target of target and of focus follow it (a reload applies it)
function Ring.TargetOfStyled()
    local db = GetDb()
    return Ring.On() and db.simpleTargetOf == false or false
end

-- this frame is drawn in a ring style (FlareUI Style or Forever Style)
function Ring.Applies(f)
    if not (f and f.Portrait) then return false end
    -- the tiles: both ring styles
    if f.ringKind then return Ring.Style() ~= "addon" end
    return RING_UNITS[f.fuiUnit] and Ring.On() or false
end

-- the ring shows the unit's rank itself (the elite / rare frame): target, focus and boss, not the
-- small target of target
function Ring.ShowsRank(f)
    local blizz = BLIZZ[Kind(f)]
    if f.ctx and f.ctx.noRank then return false end   -- the flag carriers: never the boss art
    return Ring.Applies(f) and blizz and blizz.boss or false
end

-- The style in use: "forever" (the ring on Forever's frame plate), "flareui" (the ring beside
-- FlareUI's bars) or "addon" (no ring)
function Ring.Style()
    if ns.UFSample then return ns.UFSample.style end
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

-- the ring's side (a tile: f.ringSide); Mirror only turns the bars here. Flip Portrait
-- (udb.portraitRight, on by default) picks it on target, focus and the target-of frames: on, the portrait
-- on the right as the target frame; off, on the left as the player frame. The geometry mirrors the
-- frame's Blizzard layout for the other side.
Ring.FLIP_UNITS = { target = true, focus = true, targettarget = true, focustarget = true }
function Ring.Side(f)
    if f.ringKind then return f.ringSide or "LEFT" end
    if Ring.FLIP_UNITS[f.fuiUnit] then
        local udb = Db(f)
        return (udb and udb.portraitRight == false) and "LEFT" or "RIGHT"
    end
    return BLIZZ[f.fuiUnit].side
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

-- FlareUI Style: the ring's size follows the frame's height, 80 for 60 as the player and target
-- presets (every preset keeps it: focus 35 -> 47, party and boss 50 -> 66, pet 30 -> 40). Forever
-- Style's ring follows its Scale (udb.ringSize).
Ring.RING_RATIO = 80 / 60
function Ring.RingDiameter(udb, f)
    if f and Ring.Plate(f) then return udb.ringSize or Ring.DefaultSize(Kind(f)) end
    -- Portrait Scale (FlareUI Style, 100%): the ring larger or smaller than the height gives it
    local scale = (tonumber(udb.portraitScale) or 100) / 100
    return math.floor((udb.height or 44) * Ring.RING_RATIO * scale + 0.5)
end

-- D, R, H, side, centre (from the frame's edge, positive inside), k (Blizzard's ring to this one)
local function Geometry(f)
    local udb = Db(f) or {}
    local H = udb.height or 44
    local D = Ring.RingDiameter(udb, f)
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
local function Crop(tex, artInfo, side, box)
    local info = C_Texture.GetAtlasInfo(artInfo.atlas)
    if not info then return false end
    local l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
    if not (l and r and t and b and info.file) then return false end
    box = box or artInfo.box
    local x1, x2 = l + box[1] * (r - l), l + box[2] * (r - l)
    if side and side ~= artInfo.side then x1, x2 = x2, x1 end
    tex:SetTexture(info.file)
    tex:SetTexCoord(x1, x2, t + box[3] * (b - t), t + box[4] * (b - t))
    return true
end

-- (an atlas found is remembered: GetAtlasInfo makes a new table on each call, and Ring.Update asks often)
Ring.atlasFound = {}
local function SetAtlasSafe(tex, atlas)
    if not (canaccessvalue(atlas) and atlas) then return false end
    if Ring.atlasFound[atlas] or C_Texture.GetAtlasInfo(atlas) then
        Ring.atlasFound[atlas] = true
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

-- The ring and level disc stand outside the frame's own box, so each has an invisible button doing what
-- the frame does: target, menu, click casting, ping, and the frame's own tooltip and highlight on hover
local function NewHitButton(f)
    local hit = CreateFrame("Button", nil, f, "SecureUnitButtonTemplate,PingableUnitFrameTemplate")
    hit.fuiUnit = f.fuiUnit
    hit:SetAttribute("unit", f:GetAttribute("unit"))
    hit:SetAttribute("*type1", "target")
    hit:SetAttribute("*type2", "togglemenu")
    hit:RegisterForClicks("AnyUp")
    hit:SetScript("OnEnter", function()
        local script = f:GetScript("OnEnter")
        if script then script(f) end
    end)
    hit:SetScript("OnLeave", function()
        local script = f:GetScript("OnLeave")
        if script then script(f) end
    end)
    -- after the scripts, as the frames' own (a click-cast addon wraps OnEnter / OnLeave as it registers)
    _G.ClickCastFrames = _G.ClickCastFrames or {}
    _G.ClickCastFrames[hit] = true
    return hit
end

-- Out of combat, as the frame's own layout is: just above the frame, under its auras. dx, dy: from the
-- ring's centre. Edit Mode's clicks are for placing the frame, not targeting.
local function PlaceHitButton(hit, f, g, dx, dy, w, h)
    local left = g.side == "LEFT"
    hit:ClearAllPoints()
    hit:SetSize(w, h)
    hit:SetPoint("CENTER", f, left and "LEFT" or "RIGHT", (left and g.centre or -g.centre) + dx, dy)
    hit:SetFrameLevel(f:GetFrameLevel() + 1)
    hit:EnableMouse(not LEM:IsInEditMode())
end

-- A hit button placed (when f is given) and shown or hidden. They are secure: in a fight the change waits
-- for its end (a druid's shapeshift re-lays the bars in combat when Shift Mana comes or goes, and a
-- secure ClearAllPoints is blocked then). The ring itself doesn't move then, so nothing is missed.
local hitWaiting, hitEvents = {}, nil
local function SetHit(hit, shown, f, g, dx, dy, w, h)
    if InCombatLockdown() then
        local wait = hitWaiting[hit] or {}
        wait.shown = shown
        if f then wait.f, wait.g, wait.dx, wait.dy, wait.w, wait.h = f, g, dx, dy, w, h end
        hitWaiting[hit] = wait
        if not hitEvents then
            hitEvents = CreateFrame("Frame")
            hitEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
            hitEvents:SetScript("OnEvent", function()
                for button, w8 in pairs(hitWaiting) do
                    hitWaiting[button] = nil
                    SetHit(button, w8.shown, w8.f, w8.g, w8.dx, w8.dy, w8.w, w8.h)
                end
            end)
        end
        return
    end
    hitWaiting[hit] = nil
    if f then PlaceHitButton(hit, f, g, dx, dy, w, h) end
    hit:SetShown(shown and true or false)
end

-- The frame runs on under the ring, which hid its end until the frame faded. A round hole cut in
-- everything there (under the rim, so no gap shows) leaves nothing to see through the portrait.
-- CLAMPTOWHITE: past the mask's own square nothing is cut, however wide the frame.
local BAR_HOLE_FILE = "Interface\\AddOns\\FlareUI\\Media\\Masks\\RingHole"
local BAR_HOLE_BACKDROP = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center" }

local function BarHoleRegions(f)
    local list = {}
    local function add(region) if region then list[#list + 1] = region end end
    for _, owner in ipairs({ f, f.Border, f.TargetHighlight and f.TargetHighlight.Border }) do
        for _, piece in ipairs(BAR_HOLE_BACKDROP) do add(owner[piece]) end
    end
    for _, key in ipairs({ "Health", "Power", "ShiftMana", "HealBar", "AbsorbBar", "DamageTrail" }) do
        local bar = f[key]
        if bar then
            add(bar:GetStatusBarTexture())
            add(bar.bg)
            -- Bar Edge Glow (UnitFrames.lua UF.BarLook)
            local look = bar.fuiLook
            if look then add(look.line) add(look.glow) end
        end
    end
    add(f.Separator)
    add(f.ShiftManaSeparator)
    add(f.Highlight)
    return list
end

-- Smooth Animated Bars (UnitFrames.lua ns.SAB) takes one mask per bar, the first time only: this one,
-- the frame's for good. It follows the ring hole: cut while ApplyBarHole's is, else it cuts nothing (a
-- white square, CLAMPTOWHITE past it), so the liquid never shows through the portrait.
function Ring.SyncSabHole(f)
    local mask = f and f.FlareUI_SabHole
    if not mask then return end
    local ring = f.RingFrame
    mask:ClearAllPoints()
    if ring and ring.BarHoleCut then
        mask:SetTexture(BAR_HOLE_FILE, "CLAMPTOWHITE", "CLAMPTOWHITE")
        mask:SetAllPoints(ring)
    else
        mask:SetTexture("Interface\\Buttons\\WHITE8X8", "CLAMPTOWHITE", "CLAMPTOWHITE")
        mask:SetAllPoints(f)
    end
end

function Ring.SabHole(f)
    if not f.FlareUI_SabHole then
        f.FlareUI_SabHole = f:CreateMaskTexture()
        Ring.SyncSabHole(f)
    end
    return f.FlareUI_SabHole
end

local function RemoveBarHole(ring)
    for region in pairs(ring.BarHoleCut or {}) do region:RemoveMaskTexture(ring.BarHole) end
    ring.BarHoleCut = nil
    Ring.SyncSabHole(ring:GetParent())
end

-- after the frame's backdrop and bars are set up: they make the regions it cuts
local function ApplyBarHole(f, ring)
    if not ring.BarHole then
        ring.BarHole = f:CreateMaskTexture()
        ring.BarHole:SetTexture(BAR_HOLE_FILE, "CLAMPTOWHITE", "CLAMPTOWHITE")
    end
    ring.BarHole:ClearAllPoints()
    ring.BarHole:SetAllPoints(ring)
    ring.BarHoleCut = ring.BarHoleCut or {}
    for _, region in ipairs(BarHoleRegions(f)) do
        if not ring.BarHoleCut[region] then
            region:AddMaskTexture(ring.BarHole)
            ring.BarHoleCut[region] = true
        end
    end
    Ring.SyncSabHole(f)
end

-- The same round hole under the level disc, through the ring and portrait, while the disc shows.
-- The disc's art has wide clear margins: this share of its region puts the hole's edge under its
-- gold rim (measured from a screenshot). size: the disc's width, when it changes.
local DISC_HOLE_SHARE = 0.77
local function SetDiscHole(f, ring, on, size)
    if not ring.DiscHole then
        ring.DiscHole = f:CreateMaskTexture()
        ring.DiscHole:SetTexture(BAR_HOLE_FILE, "CLAMPTOWHITE", "CLAMPTOWHITE")
        ring.DiscHole:SetPoint("CENTER", ring.Disc, "CENTER")
    end
    if size then ring.DiscHole:SetSize(size * DISC_HOLE_SHARE, size * DISC_HOLE_SHARE) end
    if on == (ring.discHoleOn or false) then return end
    for _, region in ipairs({ ring.Art, f.Portrait.Tex, ring.PortraitBack, ring.Status, ring.Flash, ring.Boss, ring.Tint }) do
        if on then region:AddMaskTexture(ring.DiscHole) else region:RemoveMaskTexture(ring.DiscHole) end
    end
    ring.discHoleOn = on
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
    ring.artMasked = true
    ring.PlateMask = ring:CreateMaskTexture()

    -- the portrait's mask, the same shape
    ring.PortraitMask = f.Portrait:CreateMaskTexture()
    ring.PortraitMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    ring.PortraitMask:SetAllPoints(f.Portrait)
    ring.PortraitBack = f.Portrait:CreateTexture(nil, "BACKGROUND", nil, -8)
    ring.PortraitBack:SetColorTexture(0, 0, 0, 1)
    ring.PortraitBackMask = f.Portrait:CreateMaskTexture()
    ring.PortraitBackMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    ring.PortraitBackMask:SetAllPoints(ring.PortraitBack)
    ring.PortraitBack:AddMaskTexture(ring.PortraitBackMask)
    ring.PortraitBack:Hide()

    -- the glows: resting / combat status (player) and the threat flash
    ring.Status = GlowTexture(ring)
    ring.Flash = GlowTexture(ring)
    -- the rest / combat tint: the ring art again, in grey and coloured, cut to the ring's circle (on
    -- Forever Style's plate the art runs on past the ring), pulsing
    ring.Tint = ring:CreateTexture(nil, "ARTWORK", nil, 7)
    ring.Tint:SetDesaturated(true)
    ring.Tint:SetBlendMode("BLEND")
    ring.Tint:Hide()
    ring.TintMask = ring:CreateMaskTexture()
    ring.TintMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    ring.TintMask:SetPoint("CENTER", ring, "CENTER")
    ring.Tint:AddMaskTexture(ring.TintMask)
    ring.Pulse = ring:CreateAnimationGroup()
    ring.Pulse:SetLooping("BOUNCE")
    local fade = ring.Pulse:CreateAnimation("Alpha")
    fade:SetTarget(ring.Tint)
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

    -- (a preview's sample takes no clicks)
    if not f.fuiSample then
        ring.Hit = NewHitButton(f)
        ring.DiscHit = NewHitButton(f)
        LEM:AddSelectionArea(ring.Hit)
        LEM:AddSelectionArea(ring.DiscHit)
    end

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
    if not f.fuiSample then frames[f] = true end

    -- bottom to top above the frame's own levels: portrait, ring, (+11: the Dispel Highlight's copy of
    -- the ring, Ring.SyncDispelTint), icons, level disc, PvP crest (the combo gems above all)
    f.Portrait:SetFrameLevel(level + 9)
    ring:SetFrameLevel(level + 10)
    ring.Icons:SetFrameLevel(level + 12)
    ring.Disc:SetFrameLevel(level + 13)
    ring.PvP:SetFrameLevel(level + 14)
    -- FlareUI Style: the auras and the cast bar over the ring, the elite / rare frame and the combo
    -- gems (+15), so the bottom corners' icons aren't hidden under the dragon. Forever
    -- Style keeps them under: its plate holds the art clear of them.
    f.auraLift = not Ring.Plate(f) and 16 or nil
    if ns.UnitFrames and ns.UnitFrames.RestackAuras then ns.UnitFrames.RestackAuras(f) end
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
    -- Blizzard's whole ring, shadow and all, out to the atlas's edges. Forever Style cuts it to the
    -- ring only where the plate's band meets it (PLATE.maskLeft / maskRight); FlareUI Style cuts it to
    -- a circle (CLEAN_RING_BARS / CLEAN_RING_OUTER).
    local plate = Ring.Plate(f)
    ring:SetPoint("CENTER", f, left and "LEFT" or "RIGHT", left and g.centre or -g.centre, plate and PLATE.ringRise * g.s or 0)
    local art = ART[Kind(f)]
    ring.Art:ClearAllPoints()
    do
        -- out to the atlas's own edges, at the same scale; the plate takes over on the bars' side
        local box = art.box
        local w, h = g.D / (box[2] - box[1]), g.D / (box[4] - box[3])
        local out = (1 - box[2]) * w
        ring.Art:SetPoint("TOPLEFT", ring, "TOPLEFT", left and -out or 0, box[3] * h)
        ring.Art:SetPoint("BOTTOMRIGHT", ring, "BOTTOMRIGHT", left and 0 or out, -(1 - box[4]) * h)
        ring.hasArt = Crop(ring.Art, art, g.side, { box[1], 1, 0, 1 })
    end
    -- Blizzard's gold ring in Forever's bronze, the same in both ring styles (Ring.PLATE_TINT)
    Ring.TintPlateArt(ring.Art)
    ring:SetShown(ring.hasArt)
    do
        -- the whole art past the plate's end; before it only the ring, as the art's copy of the plate's
        -- rails rounds differently from the plate and shows a step. The file is 2.5 radii wide.
        ring.PlateMask:SetTexture(left and PLATE.maskLeft or PLATE.maskRight, "CLAMPTOWHITE", "CLAMPTOWHITE")
        ring.PlateMask:ClearAllPoints()
        ring.PlateMask:SetPoint("CENTER", ring, "CENTER")
        ring.PlateMask:SetSize(g.R * 2.5, g.R * 2.5)
    end
    if not plate then
        ring.Mask:ClearAllPoints()
        local size = (CLEAN_RING_BARS + CLEAN_RING_OUTER) * g.D
        local shift = (CLEAN_RING_OUTER - CLEAN_RING_BARS) / 2 * g.D
        ring.Mask:SetPoint("CENTER", ring, "CENTER", left and -shift or shift, 0)
        ring.Mask:SetSize(size, size)
    end
    if plate and ring.artMasked then
        ring.Art:RemoveMaskTexture(ring.Mask)
        ring.Art:AddMaskTexture(ring.PlateMask)
        ring.artMasked = false
    elseif not plate and not ring.artMasked then
        ring.Art:RemoveMaskTexture(ring.PlateMask)
        ring.Art:AddMaskTexture(ring.Mask)
        ring.artMasked = true
    end
    -- the tint follows the art exactly
    ring.Tint:SetTexture(ring.Art:GetTexture())
    ring.Tint:SetTexCoord(ring.Art:GetTexCoord())
    ring.Tint:ClearAllPoints()
    for i = 1, ring.Art:GetNumPoints() do ring.Tint:SetPoint(ring.Art:GetPoint(i)) end
    ring.TintMask:SetSize(g.D * TINT_RIM_SHARE, g.D * TINT_RIM_SHARE)
    -- (pcall: a copy inside Blizzard's aura button is locked to addon code while a secret aura is in it)
    for holder in pairs(ring.DispelTints or {}) do pcall(Ring.SyncDispelTint, ring, holder) end
    if ring.Hit then
        SetHit(ring.Hit, true, f, g, 0, 0, g.D, g.D)
    end

    local size = g.D * PORTRAIT_SHARE
    f.Portrait:ClearAllPoints()
    f.Portrait:SetSize(size, size)
    f.Portrait:SetPoint("CENTER", ring, "CENTER", 0, 0)
    ring.PortraitBack:ClearAllPoints()
    ring.PortraitBack:SetSize(g.D * PORTRAIT_BACK_SHARE, g.D * PORTRAIT_BACK_SHARE)
    ring.PortraitBack:SetPoint("CENTER", ring, "CENTER", 0, 0)
    if not f.Portrait.ringMasked then
        f.Portrait.Tex:AddMaskTexture(ring.PortraitMask)
        f.Portrait.ringMasked = true
    end
    Ring.SyncBack(f)
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

    -- FlareUI Style only: on Forever Style's plate the ring stands past the frame's end
    if ring.hasArt and not Ring.Plate(f) then ApplyBarHole(f, ring) else RemoveBarHole(ring) end

    Ring.LayoutLevel(f, g)
    Ring.Update(f)
end

-- the level in its disc (always shown in this style)
function Ring.LayoutLevel(f, g)
    local ring = f.RingFrame
    if not ring then return end
    g = g or Geometry(f)
    local e = BLIZZ[Kind(f)].level
    local placed = PlaceRegion(f, g, ring.Disc, e)
    -- Level Disc Size (each frame's Edit Mode Text section; unset, the old shared size)
    local db, own = GetDb(), Db(f)
    local size = math.min(1, math.max(0.5, tonumber(own and own.levelSize) or tonumber(db and db.levelSize) or 1))
    -- a little under its atlas size, round the same centre
    local w, h = ring.Disc:GetSize()
    ring.Disc:SetSize(w * LEVEL_SCALE * size, h * LEVEL_SCALE * size)
    -- the skull and the number at the disc's own scale
    local k = g.D / BLIZZ[e.frame or Kind(f)].D * LEVEL_SCALE * size
    if SetAtlasSafe(ring.Skull, SKULL) then
        local info = C_Texture.GetAtlasInfo(SKULL)
        ring.Skull:SetSize(info.width * k, info.height * k)
    end
    -- Show Level: the disc goes with the number
    local udb = Db(f)
    ring.Disc:SetShown(udb and udb.showLevel and true or false)
    SetDiscHole(f, ring, placed and ring.Disc:IsShown(), w * LEVEL_SCALE * size)
    local dx, dy, dw, dh = Place(f, g, e)
    if ring.DiscHit then
        if dx then SetHit(ring.DiscHit, ring.Disc:IsShown(), f, g, dx, dy, dw * size, dh * size)
        else SetHit(ring.DiscHit, false) end
    end
    f.Level:SetParent(ring.Disc)
    f.Level:ClearAllPoints()
    f.Level:SetJustifyH("CENTER")
    f.Level:SetPoint("CENTER", ring.Disc, "CENTER", 0, 0)
    -- through FlareUI's font setter: a file not loaded yet falls back to the client's font and
    -- retries; a raw SetFont left the party tiles' level (no font of its own) blank
    ns.SetFontUnscaled(f.Level, LEVEL_FONT, math.max(8, math.floor(LEVEL_FONT_SIZE * k + 0.5)), "")
    f.Level:SetShadowOffset(1, -1)
    f.Level:SetShadowColor(0, 0, 0, 1)
end

-- Forever Faces ("Forever 3D Portraits", folder ForeverFaces) draws its model under our frame: with it
-- loaded, the ring's black disc goes while the portrait is 2D ("3d"), so its model shows through.
-- mode: the portrait mode (UnitFrames.lua / PartyFrames.lua); none keeps the last one (a ring layout)
function Ring.SyncBack(f, mode)
    local ring = f.RingFrame
    if not (ring and ring.PortraitBack) then return end
    if mode then ring.backMode = mode end
    if Ring.ffOn == nil then
        Ring.ffOn = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ForeverFaces") and true or false
    end
    -- (only while the ring is on: Ring.Reset hides the disc)
    if not f.Portrait.ringMasked then return end
    ring.PortraitBack:SetShown(not (ring.backMode == "3d" and Ring.ffOn))
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
local function EdgeY(y, s, rows)
    if y <= PLATE.cutY[2] then return "TOP", (RowY(PLATE.y0, rows) - RowY(y, rows)) * s end
    return "BOTTOM", (RowY(PLATE.y1, rows) - RowY(y, rows)) * s
end

-- Puts a region over art rect x1..x2, y1..y2 of the plate (flip: mirrored, ring on the left;
-- rows: the row sizes to use, else the frame's)
local function PlaceOnPlate(region, f, s, flip, x1, x2, y1, y2, rows)
    rows = rows or f.plateRows
    local lSide, lx = EdgeX(x1, s)
    local rSide, rx = EdgeX(x2, s)
    local tSide, ty = EdgeY(y1, s, rows)
    local bSide, by = EdgeY(y2, s, rows)
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
    for i = 1, (#PLATE.cutX - 1) * (#PLATE.cutY - 1) do plate.pieces[i] = plate:CreateTexture(nil, "BACKGROUND") end
    -- the player's: the second power slot's corner under the ring (PLATE.two), behind the rest
    if f.ShiftMana or (f.fuiUnit == "player" and not f.fuiSample and not f.ctx) then
        plate.underFrom = #plate.pieces
        for i = 1, 2 do plate.pieces[plate.underFrom + i] = plate:CreateTexture(nil, "BACKGROUND", nil, -1) end
        plate.UnderMask = plate:CreateMaskTexture()
        plate.UnderMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        plate.pieces[plate.underFrom + 2]:AddMaskTexture(plate.UnderMask)
    end
    -- Threat / Combat Glow on the plate: a lit copy of its art over it, tinted and
    -- pulsing with the ring's tint (one animation group, so every piece beats together). Added
    -- light: the bright metal glows, the dark slots stay dark.
    plate.glow = {}
    plate.GlowPulse = plate:CreateAnimationGroup()
    plate.GlowPulse:SetLooping("BOUNCE")
    for i = 1, #plate.pieces do
        local g = plate:CreateTexture(nil, "BACKGROUND", nil, 7)
        g:SetBlendMode("ADD")
        g:SetDesaturated(true)
        g:Hide()
        plate.glow[i] = g
        if plate.underFrom and i == plate.underFrom + 2 then g:AddMaskTexture(plate.UnderMask) end
        local fade = plate.GlowPulse:CreateAnimation("Alpha")
        fade:SetTarget(g)
        fade:SetFromAlpha(STATUS_PULSE[1])
        fade:SetToAlpha(STATUS_PULSE[2])
        fade:SetDuration(STATUS_PULSE[3])
        fade:SetSmoothing("IN_OUT")
    end
    -- the name box's reaction glow, and an anchor for the name
    plate.Strip = plate:CreateTexture(nil, "BORDER")
    plate.NameBox = CreateFrame("Frame", nil, plate)
    f.PlateFrame = plate
    return plate
end

-- A bar over its slot in the frame's Bar Texture (FlareUI Dark: the plate's own bar art); the
-- fill direction must be set first
local function PlaceBar(bar, f, s, flip, slot)
    PlaceOnPlate(bar, f, s, flip, slot[1], slot[2], slot[3], slot[4])
    -- for the heal and absorb overlays (LayoutIndicators): the bar's length
    local length = (f:GetWidth() or 0) - ((slot[1] - PLATE.x0) + (PLATE.x1 - slot[2])) * s
    bar.FlareUI_PlateInset = { length = length }
    local udb = Db(f)
    local name = udb and udb.texture
    if name == "FlareUI Light" and bar:GetReverseFill() then
        -- the light art's own right-to-left copy, as GetBarTexture picks off the plate
        bar:SetStatusBarTexture("Interface\\AddOns\\FlareUI\\Media\\Bars\\FlareUI-Forever-Bright-Mirrored.tga")
    elseif name and name ~= "" and name ~= "FlareUI Dark" and LSM:IsValid("statusbar", name) then
        bar:SetStatusBarTexture(LSM:Fetch("statusbar", name))
    else
        bar:SetStatusBarTexture(bar:GetReverseFill() and slot.mirrored or slot.tex)
    end
    if bar.bg then bar.bg:SetAlpha(0) end   -- the slot is the background
end

-- The second power slot (PLATE.two), over the last row's pieces and on under the ring; off: the pieces
-- under the ring draw nothing. info: the plate's own atlas; s, flip as LayoutPlate's
local function LayoutTwoSlots(f, plate, s, flip, two)
    local T = PLATE.two
    local du, dv = two and two.rightTexCoord - two.leftTexCoord, two and two.bottomTexCoord - two.topTexCoord
    local function Draw(i, x1, x2)
        local tex, g = plate.pieces[i], plate.glow[i]
        if not two then
            tex:SetTexture(nil)
            g:SetTexture(nil)
            return
        end
        local u1 = two.leftTexCoord + (T.flipX - x1) / T.artW * du
        local u2 = two.leftTexCoord + (T.flipX - x2) / T.artW * du
        if flip then u1, u2 = u2, u1 end
        local v1 = two.topTexCoord + (T.from + T.downY) / T.artH * dv
        local v2 = two.topTexCoord + (T.to + T.downY) / T.artH * dv
        for _, t in ipairs({ tex, g }) do
            t:SetTexture(two.file)
            t:SetTexCoord(u1, u2, v1, v2)
            PlaceOnPlate(t, f, s, flip, x1, x2, T.from, T.to, PLATE.rowDelta)
        end
        Ring.TintPlateArt(tex)
        tex:Show()
    end
    if plate.underFrom then
        Draw(plate.underFrom + 1, T.under[1], T.under[2])
        Draw(plate.underFrom + 2, T.under[2], T.under[3])
        local x = (T.maskX - PLATE.x1) * s
        plate.UnderMask:ClearAllPoints()
        plate.UnderMask:SetSize(T.maskD * s, T.maskD * s)
        plate.UnderMask:SetPoint("CENTER", f, flip and "BOTTOMLEFT" or "BOTTOMRIGHT", flip and -x or x,
            (RowY(PLATE.y1) - RowY(T.maskY)) * s)
    end
    if two then
        local cols = #PLATE.cutX - 1
        local first = (#PLATE.cutY - 2) * cols
        for col = 1, cols do Draw(first + col, PLATE.cutX[col], PLATE.cutX[col + 1]) end
    end
end

-- Whether the second power slot's art is there, and how far it reaches below the frame (0: not shown)
function Ring.TwoSlots()
    local info = C_Texture.GetAtlasInfo(PLATE.two.atlas)
    return info and info.file and info.leftTexCoord and info or nil
end
function Ring.PlateDrop(f)
    return f and f.PlateFrame and f.PlateFrame:IsShown() and f.plateDrop or 0
end
-- the room it needs while its option is on, shown or not
function Ring.PlateReserve(f)
    local udb = f and f.ShiftMana and Db(f)
    local test = ns.UnitFrames and ns.UnitFrames.shiftTest
    if not (udb and (udb.shiftMana or test) and Ring.Plate(f) and Ring.TwoSlots()) then return 0 end
    return PLATE.two.drop * Geometry(f).s
end

-- Lays out the plate and puts the bars in its slots (Forever Style)
function Ring.LayoutPlate(f)
    local g = Geometry(f)
    local s, flip = g.s, g.side == "LEFT"
    local plate = BuildPlate(f)
    plate:SetFrameLevel(f:GetFrameLevel())
    plate:Show()
    local power = Ring.PlatePower(f)
    f.plateRows = PlateRows(power)
    local UF = ns.UnitFrames
    local split = f.ShiftMana and UF and UF.ShiftManaShown and UF.ShiftManaShown(f)
    local two = split and Ring.TwoSlots() or nil
    f.plateDrop = two and PLATE.two.drop * s or 0
    local info = C_Texture.GetAtlasInfo(PLATE.atlas)
    if info and info.file then
        local du, dv = info.rightTexCoord - info.leftTexCoord, info.bottomTexCoord - info.topTexCoord
        local cx, cy, i = PLATE.cutX, PLATE.cutY, 0
        local cols = #cx - 1
        for row = 1, #cy - 1 do
            for col = 1, cols do
                i = i + 1
                local tex = plate.pieces[i]
                local x1, x2, y1, y2 = cx[col], cx[col + 1], cy[row], cy[row + 1]
                local u1 = info.leftTexCoord + x1 / PLATE.artW * du
                local u2 = info.leftTexCoord + x2 / PLATE.artW * du
                if flip then u1, u2 = u2, u1 end
                tex:SetTexture(info.file)
                tex:SetTexCoord(u1, u2, info.topTexCoord + y1 / PLATE.artH * dv, info.topTexCoord + y2 / PLATE.artH * dv)
                Ring.TintPlateArt(tex)
                -- the ring rim's column keeps the art's own rows (Power Height moves only the bars' line)
                local rows = col == cols and PLATE.rowDelta or f.plateRows
                PlaceOnPlate(tex, f, s, flip, x1, x2, y1, y2, rows)
                -- (a row folded away by Power Height Off has no height)
                tex:SetShown((y2 - y1) + (rows[row] or 0) > 0)
                local g = plate.glow[i]
                g:SetTexture(info.file)
                g:SetTexCoord(u1, u2, info.topTexCoord + y1 / PLATE.artH * dv, info.topTexCoord + y2 / PLATE.artH * dv)
                PlaceOnPlate(g, f, s, flip, x1, x2, y1, y2, rows)
            end
        end
    end
    if two or plate.underFrom then LayoutTwoSlots(f, plate, s, flip, two) end
    plate.glowOn = nil   -- the lit copy's art was set again: Ring.PlateGlow redoes its colour
    for holder in pairs(plate.dispelCopies or {}) do Ring.SyncPlateDispel(plate, holder) end
    local n = PLATE.name
    PlaceOnPlate(plate.NameBox, f, s, flip, n[1], n[2], n[3], n[4])
    -- the glow's atlas has clear edges round its colour: they hang outside the name box, as on
    -- Blizzard's frame, so the colour fills the box at any Width
    if SetAtlasSafe(plate.Strip, PLATE.strip) then
        local art = C_Texture.GetAtlasInfo(PLATE.strip)
        local left = n[1] - (PLATE.stripRight - art.width)
        local right = PLATE.stripRight - n[2]
        local top = n[3] - PLATE.stripTop
        local bottom = PLATE.stripTop + art.height - n[4]
        local boxW = (f:GetWidth() or 0) - ((n[1] - PLATE.x0) + (PLATE.x1 - n[2])) * s
        local rows = f.plateRows
        local boxH = (f:GetHeight() or 0) - ((RowY(n[3], rows) - RowY(PLATE.y0, rows)) + (RowY(PLATE.y1, rows) - RowY(n[4], rows))) * s
        local kx = boxW / (art.width - left - right)
        local ky = boxH / (art.height - top - bottom)
        plate.Strip:ClearAllPoints()
        plate.Strip:SetPoint("TOPLEFT", plate.NameBox, "TOPLEFT", -left * kx, top * ky)
        plate.Strip:SetPoint("BOTTOMRIGHT", plate.NameBox, "BOTTOMRIGHT", right * kx, -bottom * ky)
    else
        plate.Strip:Hide()
    end
    local strip, line = f.ShiftMana, f.ShiftManaSeparator
    if strip then
        -- Mana on Shapeshift: in the plate's second power slot, which has its own divider
        if two then
            strip:SetReverseFill(f.Power:GetReverseFill())
            PlaceBar(strip, f, s, flip, PLATE.two.slot)
        end
        strip:SetShown(two ~= nil)
        line:Hide()
    end
    if power > 0 then
        PlaceBar(f.Health, f, s, flip, PLATE.health)
        PlaceBar(f.Power, f, s, flip, PLATE.power)
        f.Power:Show()
    else
        -- Power Height Off: the health bar down to the power slot's bottom
        PlaceBar(f.Health, f, s, flip, PLATE.healthFull)
        f.Power:Hide()
    end
    Ring.UpdatePlate(f)
end

-- the dispel highlight tints the plate's bronze too: a grey copy of the plate's art
-- over it in the debuff type's colour, drawn as the portrait ring's dispel tint (DispelTint) so both
-- read as one colour and beat as one (added light washed blue out to white on the bronze). Its own
-- copy: Blizzard shows and tints these for a dispellable debuff. At the plate's own level, under the
-- bars (the frame's children, one level up). parent: the highlight's frame, which pulses. Each piece
-- sits on its plate piece; LayoutPlate keeps their art in step.
function Ring.DispelPlate(f, parent)
    local plate = f.PlateFrame
    local holder = parent and parent.FlareUI_PlateDispel
    if not (plate and plate.pieces and parent) then
        if holder then holder:Hide() end
        return nil
    end
    if not holder then
        holder = CreateFrame("Frame", nil, parent)
        holder.tex = {}
        for i, piece in ipairs(plate.pieces) do
            local tex = holder:CreateTexture(nil, "OVERLAY")
            tex:SetAllPoints(piece)
            tex:SetBlendMode("BLEND")
            tex:SetDesaturated(true)
            holder.tex[i] = tex
        end
        parent.FlareUI_PlateDispel = holder
        plate.dispelCopies = plate.dispelCopies or setmetatable({}, { __mode = "k" })
        plate.dispelCopies[holder] = true
    end
    holder:SetAllPoints(plate)
    holder:SetFrameLevel(plate:GetFrameLevel())
    holder:Show()
    Ring.SyncPlateDispel(plate, holder)
    return holder.tex
end
-- the copy takes each piece's art and cut (pcall: a copy inside Blizzard's aura button is locked to
-- addon code while a secret aura is in it)
function Ring.SyncPlateDispel(plate, holder)
    for i, tex in ipairs(holder.tex) do
        local piece = plate.pieces[i]
        if piece then
            pcall(function()
                tex:SetTexture(piece:GetTexture())
                tex:SetTexCoord(piece:GetTexCoord())
            end)
        end
    end
end

-- Forever Style's Power Height (art pixels, 0 = Off) for this frame; Off on a party tile Only Mana Power Bars
-- leaves without one
function Ring.PlatePower(f)
    if f.noPowerBar then return 0 end
    local udb = Db(f)
    return Ring.PlatePowerValue(udb and udb.platePower)
end
-- a stored platePower, read: nil the default, 0 Off, else within the slider's steps
function Ring.PlatePowerValue(p)
    local P = Ring.PLATE_POWER
    if type(p) ~= "number" then return P.default end
    if p < P.min then return 0 end
    return math.min(P.max, math.floor(p + 0.5))
end
-- the plate's power number: only on a power bar tall enough for it
function Ring.PlatePowerText(f)
    return Ring.PlatePower(f) >= 6
end

-- the name box's glow in the unit's reaction colour; a player character's in their class colour while
-- the frame's Class Colours is on. None on your own frame, as Blizzard's (7.0.1 to 7.0.15 had the class colour there),
-- nor on the pet's.
function Ring.UpdatePlate(f)
    local plate = f.PlateFrame
    if not (plate and plate:IsShown()) then return end
    local unit = f.fuiUnit
    local K = ns.UnitFrames and ns.UnitFrames.Kit
    if unit == "player" or unit == "pet" or f.fuiSample or not UnitExists(unit) then
        plate.Strip:Hide()
        return
    end
    local isPlayer = UnitIsPlayer(unit)
    if canaccessvalue(isPlayer) and isPlayer and K and K.GetHealthColor and ns.ClassColorsOn(Db(f)) then
        local r, g, b = K.GetHealthColor(unit, true)
        plate.Strip:SetVertexColor(r, g, b, 1)
        plate.Strip:Show()
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
    f.Health.FlareUI_PlateInset, f.Power.FlareUI_PlateInset = nil, nil
    f.plateDrop = nil
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
    RemoveBarHole(ring)
    if ring.Hit then SetHit(ring.Hit, false) end
    if ring.DiscHit then SetHit(ring.DiscHit, false) end
    f.Level:SetAlpha(1)
    f.Portrait:SetFrameLevel(level + 1)
    f.Overlay:SetFrameLevel(level + 5)
    f.auraLift = nil
    if ns.UnitFrames and ns.UnitFrames.RestackAuras then ns.UnitFrames.RestackAuras(f) end
    f.Level:SetParent(f.Overlay)
    ring.Disc:Hide()
    SetDiscHole(f, ring, false)
    for _, key in ipairs(RING_ICONS) do
        local region = f[key]
        if region then region:SetParent(region.ringHome or f.Overlay) end
    end
    ring.PortraitBack:Hide()
    if f.Portrait.ringMasked then
        f.Portrait.Tex:RemoveMaskTexture(ring.PortraitMask)
        f.Portrait.ringMasked = nil
    end
end

-- the mouse is on the ring or level disc
function Ring.MouseOverHit(f)
    local ring = f.RingFrame
    if not (ring and ring.Hit) then return false end
    return (ring.Hit:IsShown() and ring.Hit:IsMouseOver()) or (ring.DiscHit:IsShown() and ring.DiscHit:IsMouseOver()) or false
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
    -- the raid marker: smaller than Blizzard's and a little lower, clear of Show Threat's number
    if key == "raidIcon" then w, h, dy = w * 0.75, h * 0.75, dy - 3 end
    -- the flag carriers' faction crest: big, centred on the ring's outer edge
    if key == "role" and f.ctx and f.ctx.factionIcon then
        local size = g.D * 0.75   -- three quarters of the ring's width
        dx, dy, w, h = (g.side == "RIGHT" and 1 or -1) * (g.R + size * 0.2), 0, size, size
    end
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
    local editing = ns.EditPreviewing()
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
    -- a preview's sample has no unit state to show
    if f.fuiSample then return end
    -- Keep badge art, hit region and portrait cutout in sync after a live setting change.
    local udb = Db(f)
    local showLevel = udb and udb.showLevel and true or false
    if not InCombatLockdown() and ring.Disc:IsShown() ~= showLevel then Ring.LayoutLevel(f) end
    local unit, kind = f.fuiUnit, Kind(f)
    local blizz = BLIZZ[kind]
    local exists = Readable(UnitExists(unit))
    -- a boss tile's Edit Mode sample (f.sample): its art as a live boss would have it
    local sample = ns.EditPreviewing() and f.ringKind and f.sample

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
    -- not on the flag carriers (ctx.noRank): they borrow the boss ring, not its art
    if blizz.boss and not (f.ctx and f.ctx.noRank) and (exists or sample) and GetBossPortraitFrameData then
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
                -- the dragon in the same bronze as the ring
                Ring.TintPlateArt(ring.Boss)
                ring.Boss:SetShown(info ~= nil)
            end
        end
    end

    -- the level disc's skull for a "??" unit (10+ levels higher): target and focus with "High Level
    -- Skull" on; a red "??" everywhere else
    local level = Readable(ns.UnitShownLevel(unit))
    -- (the boss tiles too, Boss > Icons > High Level Skull)
    local isBoss = type(f.fuiUnit) == "string" and f.fuiUnit:find("^boss") ~= nil
    local skull = exists and level and level <= 0 and (f.fuiUnit == "target" or f.fuiUnit == "focus" or isBoss)
        and IconOn(f, "highSkull", true) or false
    ring.Skull:SetShown(skull and ring.Disc:IsShown())
    f.Level:SetAlpha(skull and 0 or 1)

    -- the player: the ring tinted red and swords in combat, else gold and the corner piece resting.
    -- The red with Combat Glow (Look), the gold with the Resting icon's Show switch.
    if kind == "player" then
        local combat = Readable(UnitAffectingCombat("player"))
        local resting = not combat and Readable(IsResting())
        local color
        if combat then
            color = Ring.GlowOn(f, "combatGlow") and STATUS_COMBAT or nil
        elseif resting then
            color = IconOn(f, "rest", true) and STATUS_RESTING or nil
        end
        ring.Status:Hide()
        -- the tint itself is applied by UpdateThreat below (threat, when there is any, comes first)
        ring.statusColor = color
        -- the player's level is white, as on Blizzard's frame
        f.Level:SetTextColor(1, 1, 1)
        ring.Corner:SetShown(resting and true or false)
        ring.Attack:SetShown(combat and true or false)
    end

    UpdateExtras(f)

    Ring.UpdateThreat(f)
end

-- Threat: the ring's border tinted in Blizzard's colours, pulsing; else the player's rest / combat
-- colour. Tiles off the plate use their border instead; on it a party member flashes for its own
-- aggro, a boss for the player's threat on it.
-- The plate's lit copy (Forever Style): shown in the tint's colour, or hidden
function Ring.PlateGlow(f, color)
    local plate = f and f.PlateFrame
    if not (plate and plate.glow) then return end
    local on = color and plate:IsShown()
    -- (threat events come often in a fight: the same state again leaves the pieces as they are)
    local r, gg, b = on and color[1], on and color[2], on and color[3]
    if plate.glowOn == (on and true or false) and plate.glowR == r and plate.glowG == gg and plate.glowB == b then return end
    plate.glowOn, plate.glowR, plate.glowG, plate.glowB = on and true or false, r, gg, b
    for _, g in ipairs(plate.glow) do
        if on then g:SetVertexColor(color[1], color[2], color[3]) end
        g:SetShown(on and true or false)
    end
    if not on then plate.GlowPulse:Stop() end
end

-- every pulse of one frame starts together, so the ring, the plate and the border (Threat / Combat
-- Glow, UnitFrames.lua UF.SetBorderGlow) are bright at the same moment
-- (a numeric loop: a frame without a ring or plate leaves nil holes, where ipairs would stop)
function Ring.SyncPulses(f)
    local ring = f and f.RingFrame
    local plate = f and f.PlateFrame
    local border = f and f.Border and f.Border.FlareUI_Pulse
    local groups = { ring and ring.Tint and ring.Tint:IsShown() and ring.Pulse,
                     plate and plate.glow and plate.glow[1] and plate.glow[1]:IsShown() and plate.GlowPulse,
                     border and border:IsPlaying() and border }
    for i = 1, 3 do
        local group = groups[i]
        if group then group:Stop(); group:Play() end
    end
end

local function ApplyTint(ring, color)
    local f = ring:GetParent()
    if color and ring.hasArt and ring.Tint then
        ring.Tint:SetVertexColor(color[1], color[2], color[3])
        ring.Tint:Show()
        Ring.PlateGlow(f, color)
        if not ring.Pulse:IsPlaying() then Ring.SyncPulses(f) end
    elseif ring.Tint then
        ring.Tint:Hide()
        ring.Pulse:Stop()
        Ring.PlateGlow(f, nil)
    end
end

-- Dispel Highlight on a ring tile: the portrait border again, in grey, for Blizzard to
-- show and colour with a dispellable debuff (the type can be secret: only Blizzard knows the colour).
-- parent: the highlight's button, or Edit Mode's sample. It follows the ring's layout.
function Ring.SyncDispelTint(ring, holder)
    local tex = holder.Tex
    tex:SetTexture(ring.Art:GetTexture())
    tex:SetTexCoord(ring.Art:GetTexCoord())
    tex:ClearAllPoints()
    for i = 1, ring.Art:GetNumPoints() do tex:SetPoint(ring.Art:GetPoint(i)) end
    holder.Mask:SetSize(ring.TintMask:GetSize())
    -- over the ring's art, under its icons, disc and crest (as the threat tint)
    holder:SetFrameLevel(ring:GetFrameLevel() + 1)
    holder:SetShown(ring.hasArt and true or false)
end

-- the grey copy's texture (nil: no ring art on this frame)
function Ring.DispelTint(f, parent)
    local ring = f.ringKind and f.RingFrame
    local holder = parent.FlareUI_RingDispel
    if not (ring and ring.Tint and ring.hasArt) then
        if holder then holder:Hide() end
        return nil
    end
    if not holder then
        holder = CreateFrame("Frame", nil, parent)
        holder:SetAllPoints(ring)
        holder.Tex = holder:CreateTexture(nil, "ARTWORK", nil, 7)
        holder.Tex:SetDesaturated(true)
        holder.Tex:SetBlendMode("BLEND")
        holder.Mask = holder:CreateMaskTexture()
        holder.Mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        holder.Mask:SetPoint("CENTER", ring, "CENTER")
        holder.Tex:AddMaskTexture(holder.Mask)
        parent.FlareUI_RingDispel = holder
    end
    ring.DispelTints = ring.DispelTints or {}
    ring.DispelTints[holder] = true
    Ring.SyncDispelTint(ring, holder)
    return holder.Tex
end

-- Threat Glow (Look) on every frame with a ring, tiles too (their border pulses with it,
-- PartyFrames.lua UpdateThreat); the player's threat goes with Combat Glow. None in Edit Mode.
function Ring.UpdateThreat(f)
    local ring = f.RingFrame
    if not ring then return end
    ring.Flash:Hide()
    local unit, kind = f.fuiUnit, Kind(f)
    local status
    if unit == "targettarget" or unit == "focustarget"   -- those two show no threat
        or not Ring.GlowOn(f, kind == "player" and "combatGlow" or "threatGlow") then
        status = nil
    elseif not ns.EditPreviewing() then
        local exists = unit and Readable(UnitExists(unit))
        if kind == "player" then
            status = Readable(UnitThreatSituation("player"))
        elseif kind == "party" or kind == "pet" then
            status = exists and Readable(UnitThreatSituation(unit)) or nil
        elseif exists then
            status = Readable(UnitThreatSituation("player", unit))
        end
    end
    if status and status > 0 and GetThreatStatusColor then
        local r, gg, b = GetThreatStatusColor(status)
        local c = ring.threatRGB or {}
        ring.threatRGB = c
        c[1], c[2], c[3] = r, gg, b
        ApplyTint(ring, c)
    else
        ApplyTint(ring, ring.statusColor)
    end
end

-- The state art follows combat, resting and threat without a full layout. Unit events only for the
-- ring units (threat fires for every group member); RegisterUnitEvent takes two units, so focus and
-- pet have a frame of their own.
do
    local function OnEvent(_, event, unit)
        -- threat only moves the flash, and fires often in a fight: the frame whose unit it names, or
        -- every unit frame for the player's own. Party and boss tiles follow their own threat events.
        if event == "UNIT_THREAT_SITUATION_UPDATE" or event == "UNIT_THREAT_LIST_UPDATE" then
            for f in pairs(frames) do
                if not f.ringKind and f:IsVisible() and (unit == "player" or f.fuiUnit == unit) then
                    Ring.UpdateThreat(f)
                end
            end
            return
        end
        -- another unit's state only changes its own frame; the player's (and combat, resting) all
        local only = unit and unit ~= "player" and unit or nil
        for f in pairs(frames) do
            if not only or f.fuiUnit == only then Ring.Update(f) end
        end
    end
    local events, focusEvents = CreateFrame("Frame"), CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_UPDATE_RESTING", "PVP_TIMER_UPDATE" }) do
        pcall(events.RegisterEvent, events, event)
    end
    for _, event in ipairs({ "UNIT_THREAT_SITUATION_UPDATE", "UNIT_THREAT_LIST_UPDATE", "UNIT_CLASSIFICATION_CHANGED",
            "UNIT_FACTION", "PLAYER_FLAGS_CHANGED" }) do
        pcall(events.RegisterUnitEvent, events, event, "player", "target")
        pcall(focusEvents.RegisterUnitEvent, focusEvents, event, "focus", "pet")
    end
    events:SetScript("OnEvent", OnEvent)
    focusEvents:SetScript("OnEvent", OnEvent)

    -- (a frame left in combat is laid out again when it ends, which sets this too)
    local function SetHitMouse(on)
        if InCombatLockdown() then return end
        for f in pairs(frames) do
            f.RingFrame.Hit:EnableMouse(on)
            f.RingFrame.DiscHit:EnableMouse(on)
        end
    end
    LEM:RegisterCallback("enter", function() SetHitMouse(false) end)
    LEM:RegisterCallback("exit", function() SetHitMouse(true) end)
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

-- A styled small frame's sizes: half the frame it follows as that stands, with its look
local function ApplySmallPreset(db, pet, unit)
    local from = SMALL_FRAMES[unit]
    local player = db.units[from] or {}
    local function Half(value, default) return math.floor((value or default) * PET_SHARE + 0.5) end
    pet.width = Half(player.width, 200)
    pet.texture, pet.border, pet.absorbTexture = player.texture, player.border, player.absorbTexture
    pet.healthText = player.healthText
    -- the level starts off on target of target and target of focus
    pet.showLevel = unit == "pet" and player.showLevel ~= false
    pet.powerHeight = Half(player.powerHeight, 15)
    if db.plateStyle then
        ApplyPlateScale(pet, Half(player.plateScale, PLATE.defaultScale[from]))
    else
        pet.height = Half(player.height, 60)
        pet.ringSize = Half(player.ringSize, FOREVER[from].ringSize)
    end
    -- the pet a little bigger than half the player frame
    if unit == "pet" then
        if db.plateStyle then ApplyPlateScale(pet, Ring.PET_PLATE_SCALE) else pet.height = Ring.PET_RING_HEIGHT end
    end
end

-- A small frame's stored place in every Edit Mode layout goes into `into` (the layouts' entries are
-- cleared), and `from`'s comes back
local function SwapSmallPositions(db, unit, into, from)
    for layoutName, store in pairs(db.layouts or {}) do
        into[layoutName] = store[unit]
        store[unit] = nil
    end
    db.layouts = db.layouts or {}
    for layoutName, position in pairs(from or {}) do
        db.layouts[layoutName] = db.layouts[layoutName] or {}
        db.layouts[layoutName][unit] = position
    end
end

-- The simple and the styled frame each keep their own settings and places, per style: the one the
-- option asks for is put in place here, its own switch aside. The first styled one starts from the
-- preset, at its style's default place. Saved as <unit>Setup, <unit>Stash, <unit>Positions.
local function SyncSmallSetup(db, unit)
    local frame = db.units and db.units[unit]
    local simple = db.simplePet
    if unit ~= "pet" then simple = db.simpleTargetOf end
    local wanted = (db.foreverStyle and simple == false) and "styled" or "simple"
    local keys = SMALL_KEYS[unit]
    local setupKey, stashKey, placesKey = keys[1], keys[2], keys[3]
    local current = db[setupKey] or "simple"
    if not frame or current == wanted then return end
    local enabled, saved = frame.enabled, {}
    for key, value in pairs(frame) do saved[key] = CopyRaw(value) end
    db[stashKey] = db[stashKey] or {}
    db[stashKey][current] = saved
    db[placesKey] = db[placesKey] or {}
    local positions = {}
    db[placesKey][current] = positions
    SwapSmallPositions(db, unit, positions, db[placesKey][wanted])
    local back = db[stashKey][wanted]
    if back then
        for key in pairs(frame) do frame[key] = nil end
        Fill(frame, back)
    else
        ApplySmallPreset(db, frame, unit)
    end
    frame.enabled = enabled
    db[setupKey] = wanted
end

function Ring.SyncPetSetup(db)
    for unit in pairs(SMALL_FRAMES) do SyncSmallSetup(db, unit) end
end

-- A style's first setup starts with the simple frames (Ring.SyncPetSetup then makes styled ones to
-- that style's measure)
local function ResetPetSetup(db)
    for unit in pairs(SMALL_FRAMES) do
        local frame = db.units and db.units[unit]
        local setupKey, stashKey, placesKey = unit .. "Setup", unit .. "Stash", unit .. "Positions"
        local simple = db[stashKey] and db[stashKey].simple
        if frame and db[setupKey] == "styled" and simple then
            local enabled = frame.enabled
            for key in pairs(frame) do frame[key] = nil end
            Fill(frame, simple)
            frame.enabled = enabled
        end
        db[setupKey], db[stashKey], db[placesKey] = nil, nil, nil
    end
end

-- Once (db.plateTiles): a Forever Style setup without ring tiles takes FlareUI Style's party and boss setup
local function CopyTiles(dst, src)
    if not (dst and src) then return end
    for key in pairs(TILE_KEYS) do
        if src[key] then
            -- the setup in use keeps its tables (their defaults stand behind them)
            if type(rawget(dst, key)) == "table" and getmetatable(dst[key]) then
                Clear(dst[key])
                Fill(dst[key], src[key])
            else
                dst[key] = CopyRaw(src[key])
            end
        end
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
        -- (the small frames' setups are Ring.SyncPetSetup's)
        if udb and not SMALL_FRAMES[unit] then ApplyPlateScale(udb, Ring.PlateDefaultScale(unit)) end
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

-- A style's setup as stored: only what differs from the defaults, so a later change of a default
-- reaches every style. Party and boss are always there (empty: their defaults), so switching back
-- restores them rather than keeping the other style's.
function Ring.StyleChanges(setup)
    local own = {}
    for k, v in pairs(setup) do
        if not SHARED_KEYS[k] then own[k] = v end
    end
    local defaults = ns.defaults and ns.defaults.profile and ns.defaults.profile.unitframes or {}
    local saved = CopyRaw(ns.ProfileChanges(own, defaults))
    for k in pairs(TILE_KEYS) do saved[k] = saved[k] or {} end
    return saved
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
    db.styleProfiles[STYLE_SLOT[current]] = Ring.StyleChanges(db)
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
    if not back then ResetPetSetup(db) end
    RestoreSwitches(db, switches)
    -- a stored setup holds only its changes: the defaults it left out go back in now, as AceDB puts
    -- them in at load (AceDB's copyDefaults), so the frames keep their size before any reload. A
    -- table's "**" defaults apply to each of its tables; "*" / "**" lookups stay with the tables
    -- that kept them (Clear)
    local function Defaults(dst, src)
        for k, v in pairs(src) do
            if k ~= "*" and k ~= "**" then
                if type(v) == "table" then
                    if rawget(dst, k) == nil then dst[k] = {} end
                    if type(dst[k]) == "table" then
                        Defaults(dst[k], v)
                        if src["**"] then Defaults(dst[k], src["**"]) end
                    end
                elseif rawget(dst, k) == nil then
                    dst[k] = v
                end
            end
        end
    end
    local defaults = ns.defaults and ns.defaults.profile and ns.defaults.profile.unitframes
    if defaults then Defaults(db, defaults) end
    db.foreverStyle = style ~= "addon"
    db.plateStyle = style == "forever"
end

-- The Frame Style picked in the settings waits for the reload (or the logout): the setups are swapped
-- as the profile is saved (AceDB's OnDatabaseShutdown, before it takes the defaults out), so no
-- refresh before the reload draws the new style, and picking the style in use back changes nothing.
-- Ring.choice: { style, db }, the pick and the profile it was made on
function Ring.ChosenStyle()
    local choice = Ring.choice
    if choice and choice.db == GetDb() then return choice.style end
    return Ring.Style()
end

function Ring.ChooseStyle(style)
    local db = GetDb()
    if not db or not STYLE_SLOT[style] then return end
    -- (no AceDB callbacks: switched at once, as before)
    if not (ns.db and ns.db.RegisterCallback) then Ring.SetStyle(style) return end
    Ring.choice = style ~= Ring.Style() and { style = style, db = db } or nil
    if not Ring.choiceHooked then
        Ring.choiceHooked = true
        ns.db.RegisterCallback(Ring, "OnDatabaseShutdown", function()
            local choice = Ring.choice
            Ring.choice = nil
            -- (a pick made on another profile stays with it)
            if choice and choice.db == GetDb() then Ring.SetStyle(choice.style) end
        end)
        -- the profile starts over, or takes another's: its own style counts, not a pick made before
        local function Forget() Ring.choice = nil end
        ns.db.RegisterCallback(Ring, "OnProfileReset", Forget)
        ns.db.RegisterCallback(Ring, "OnProfileCopied", Forget)
    end
end

-- A style's setup for a unit, for a settings preview's sample. Never written to the profile:
-- writes land on the returned table. The setup in use for the style in use; else the style's stored
-- setup, or the preset a first switch would apply, over the defaults.
-- preset: the style's own look only (the Frame Style cards), never the player's live setup
function Ring.SampleUnitDb(style, unit, preset)
    local db = GetDb()
    if not db or not STYLE_SLOT[style] then return nil end
    local base
    if preset then
        local defaults = ns.defaults and ns.defaults.profile and ns.defaults.profile.unitframes
        defaults = defaults and defaults.units and defaults.units[unit] or {}
        local layer = {}
        if style ~= "addon" then
            for k, v in pairs(FOREVER[unit] or {}) do layer[k] = v end
            if style == "forever" then
                for k, v in pairs(PLATE_PRESET[unit] or {}) do layer[k] = v end
                if Ring.PLATE_UNITS[unit] and not SMALL_FRAMES[unit] then ApplyPlateScale(layer, Ring.PlateDefaultScale(unit)) end
            end
        end
        base = setmetatable(layer, { __index = defaults })
    elseif style == Ring.Style() then
        base = db.units and db.units[unit]
    else
        local defaults = ns.defaults and ns.defaults.profile and ns.defaults.profile.unitframes
        defaults = defaults and defaults.units and defaults.units[unit] or {}
        local stored = db.styleProfiles and db.styleProfiles[STYLE_SLOT[style]]
        local own = stored and stored.units and stored.units[unit]
        local layer = {}
        if own then
            for k, v in pairs(own) do layer[k] = v end
        elseif style ~= "addon" then
            for k, v in pairs(FOREVER[unit] or {}) do layer[k] = v end
            if style == "forever" then
                for k, v in pairs(PLATE_PRESET[unit] or {}) do layer[k] = v end
                if Ring.PLATE_UNITS[unit] and not SMALL_FRAMES[unit] then ApplyPlateScale(layer, Ring.PlateDefaultScale(unit)) end
            end
        end
        base = setmetatable(layer, { __index = defaults })
    end
    if not base then return nil end
    return setmetatable({}, { __index = base })
end

--------------------------------------------------
-- 9. EDIT MODE
--------------------------------------------------
-- Edit Mode's defaults for the styled small frames: half the player and target frames' presets (the same)
function Ring.PetDefaults(unit)
    local player = FOREVER.player
    return {
        width = math.floor(player.width * PET_SHARE + 0.5),
        -- the pet's own height (Ring.PET_RING_HEIGHT), the target-of frames half the player's
        height = unit == "pet" and Ring.PET_RING_HEIGHT or math.floor(player.height * PET_SHARE + 0.5),
        powerHeight = math.floor(player.powerHeight * PET_SHARE + 0.5), healthText = "percent", showLevel = unit == "pet",
        powerText = "value", texture = "FlareUI Dark", border = player.border, absorbTexture = "FlareUI Striped",
        buffs = "OFF", debuffs = "OFF", auraSize = 12, castbar = false,
        -- Mirror Bars on for the target-of frames, in every style
        mirror = unit ~= "pet" or nil,
    }
end

-- Portrait Size's default: the preset's
function Ring.DefaultSize(unit)
    if unit == "party" or unit == "boss" then return TILE_RING_D end
    if SMALL_FRAMES[unit] then return PET_RING_D end
    return FOREVER[unit] and FOREVER[unit].ringSize
end
