local _, ns = ...
local L = ns.L

--------------------------------------------------
-- MINIMAP
-- A square minimap in Blizzard's panel frame art, the header (tracking, zone, clock, calendar)
-- inside its top edge and the day/night badge on its bottom-left corner. Edit Mode's Size (shown as
-- Scale) scales it.
-- Style Round (minimap.style) keeps Forever's native round minimap and skips all of the above.
--------------------------------------------------

--------------------------------------------------
-- 1. MODULE REGISTRATION
--------------------------------------------------
ns.Minimap = ns.Minimap or {}
local MM = ns.Minimap
ns.modules["Minimap"] = MM

LibStub("AceEvent-3.0"):Embed(MM)

--------------------------------------------------
-- 2. UPVALUES
--------------------------------------------------
local _G = _G
local ipairs, pairs, type = ipairs, pairs, type
local hooksecurefunc = hooksecurefunc
local LEM = LibStub("FlareEditMode")
local C_Timer = C_Timer

-- Blizzard's frames. "Minimap" is a global, so the module table and the frame keep separate names.
local MinimapFrame = _G.Minimap
local Cluster = _G.MinimapCluster
local squareStyle -- latched at startup because the square layout's hooks last until reload

--------------------------------------------------
-- 3. CONSTANTS
--------------------------------------------------
-- the square map and its art, in unscaled pixels
local MAP_SIZE      = 244
local FRAME_PAD     = 8                             -- room around the map for the frame art
-- the map stops this far inside the art, per side: its square corners would show past the art's
-- angled ones, and the gold line (5 px wide) hides the edge
local MAP_CROP      = 4
local BORDER_LAYOUT = "ButtonFrameTemplateNoPortrait"   -- Blizzard NineSlice layout
local LEFT_SHIFT    = -6     -- the layout sits further in on the left
-- the border art's transparent shadow outside its gold line, per side (measured in game)
local BORDER_SHADOW = { left = 10, top = 11, right = 4, bottom = 5 }
local SQUARE_MASK   = "Interface\\BUTTONS\\WHITE8X8"
-- a faded-out map: an empty mask hides its terrain and the dots the game draws at full strength
-- (Hide would stop node addons' scans); Forever's own round mask (Blizzard_Minimap\Camelot)
local MASKS = { EMPTY = "Interface\\AddOns\\FlareUI\\Media\\Art\\Empty", FOREVER = "ui-hud-minimap-frame-generic-mask" }

-- Header (minimap.squareHeader): two looks for the frame's top.
-- * Headerless (default): the border lies under the map, so its title bar is covered and the header
--   row sits on the terrain; the top edge comes down onto the map's top.
-- * Bordered: the title bar and its corners draw over the map, a band the header row sits in.
-- band: how far below the frame's top the mail and other indicators start; headerTop: the header row's
-- inset from the frame's top; drop: the top edge lowered onto the map; over: top pieces above the map.
-- bronze: Headerless framed in the settings window's border instead, the character select's heavy
-- bronze frame without its rivets, over the map; the metal frame's pieces stay (unseen) to measure the
-- Edit Mode box, and come back if the client lacks the atlas.
local HEADER_STYLES = {
    headerless = { band = 27, headerTop = 7, drop = 3, over = false, bronze = true, side = 10, shift = -1 },
    art        = { band = 22, headerTop = 2, drop = 0, over = true, side = 6, barSide = 10 },
}
-- Border (minimap.squareBorder), Headerless only: the heavy bronze, or a FlareUI edge drawn around the
-- map in its place (the bronze and metal pieces then unseen). Each border's numbers place what sits on
-- its edge:
-- * barBottom: the Info Bar's inset from the map frame's bottom
-- * sun: the sundial's overhang past the map frame's corner; sunRoom: the Info Bar's room for it
-- * eye: the edge icons' centre in from the map frame's edge (MinimapEye.lua)
-- * buttons: the addon buttons' line past the map's own edge, at its top and bottom (EdgePoint)
-- The FlareUI borders also set the header row like HEADER_STYLES (side, headerTop, band, shift), and:
-- * lsm, edge: the LibSharedMedia border and its edge size
-- * grow: the map frame past the bronze's 244 square, per side. With a FlareUI border the map frame is
--   its edge frame (MM.ArtBox), so every number here and in HEADER_STYLES counts from its edge.
-- * line: the line's lit outside, in from the edge frame's (the border's visible outside: Edit Mode's
--   box, the quest tracker's width)
-- * crop: the terrain's inset from the edge frame's narrower sides (it stays square)
-- The edge files' alpha: Thick's line lies 1.5 to 4 px in from the edge frame's outside (its bright core
-- from 2), Thin's 2.5 to 4; both shadows reach in to 6. grow puts the lit outside on the bronze frame's
-- visible outside (its gold line and rim, not its clear shadow): 1.5 past the map frame on the left,
-- 3.5 at the top, 2.5 short of it on the right and 1.5 at the bottom, measured in game, so all four
-- looks cover one 243 x 246 box. The terrain (242) runs under the line on every side.
MM.SQUARE_BORDERS = {
    bronze = { barBottom = 8, sun = 9, sunRoom = 30, eye = 3, buttons = 0 },
    thick  = { lsm = "FlareUI Thick", edge = 16, side = 8, headerTop = 8, band = 28, shift = 0,
               grow = { left = 3, right = 1, top = 3, bottom = 0 }, line = 1.5, crop = 2,
               barBottom = 8, sun = 6, sunRoom = 33, eye = 2.75, buttons = 0.75,
               mask = "Interface\\AddOns\\FlareUI\\Media\\Art\\MinimapMaskThick" },
    thin   = { lsm = "FlareUI Thin", edge = 8, side = 8, headerTop = 8, band = 28, shift = 0,
               grow = { left = 4, right = 2, top = 4, bottom = 1 }, line = 2.5, crop = 3,
               barBottom = 8, sun = 6, sunRoom = 33, eye = 3.25, buttons = 1.25,
               mask = "Interface\\AddOns\\FlareUI\\Media\\Art\\MinimapMaskThin" },
}
-- each style's border numbers; Headerless with a FlareUI border is a style of its own (flare: its border)
HEADER_STYLES.headerless.border = MM.SQUARE_BORDERS.bronze
HEADER_STYLES.art.border = MM.SQUARE_BORDERS.bronze
for _, spec in pairs(MM.SQUARE_BORDERS) do
    if spec.lsm then
        local style = {}
        for k, v in pairs(HEADER_STYLES.headerless) do style[k] = v end
        for _, k in ipairs({ "side", "headerTop", "band", "shift" }) do style[k] = spec[k] end
        style.bronze, style.flare, style.border = false, spec, spec
        spec.style = style
    end
end
local BRONZE_ATLAS = "heavybronze-frame-basic"
-- the bronze frame this far past the map frame's edges, per side: measured against Bordered's metal
-- frame so both styles cover the same box
local BRONZE_OUT   = { left = 9, right = 7, top = 11, bottom = 8 }
local function HeaderStyle(db)
    -- (a style card's sample draws its own header, whatever the one in use: MM.sampleHeader)
    db = db or (ns.db and ns.db.profile and ns.db.profile.minimap)
    local style = HEADER_STYLES[MM.sampleHeader or (db and db.squareHeader) or "headerless"] or HEADER_STYLES.headerless
    -- Headerless: in the chosen border
    local spec = style.bronze and db and MM.SQUARE_BORDERS[db.squareBorder]
    return spec and spec.style or style
end
-- the border numbers in use (MM.SQUARE_BORDERS)
function MM.SquareBorder()
    return HeaderStyle().border
end
-- The square map's mask: a FlareUI border cuts the terrain's corners along its angled ones (mask: a
-- 45-degree cut of 3 px for Thin, 5 px for Thick on the 243 terrain), else plain square. The square
-- corners showed past the border's (MunchieDog, 11-19).
function MM.SquareMask()
    local flare = HeaderStyle().flare
    return flare and flare.mask or SQUARE_MASK
end
-- the black backing takes the same corners
function MM.MaskBack(back)
    if not back.fuiMask then
        back.fuiMask = back:GetParent():CreateMaskTexture()
        back.fuiMask:SetAllPoints(back)
        back:AddMaskTexture(back.fuiMask)
    end
    back.fuiMask:SetTexture(MM.SquareMask(), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
end
-- The map frame's box in the border in use: width, height, its centre's offset from the cluster's,
-- the terrain's side, and the black backing's width and height. The bronze looks: the 244 square on the
-- cluster's centre. A FlareUI border: its edge frame, grown per side (grow), with the terrain filling it
-- up to under the line and the backing out to the line's outside.
function MM.ArtBox()
    local flare = HeaderStyle().flare
    if not flare then
        local inner = MAP_SIZE - 2 * MAP_CROP
        return MAP_SIZE, MAP_SIZE, 0, 0, inner, inner, inner
    end
    local g = flare.grow
    local w, h = MAP_SIZE + g.left + g.right, MAP_SIZE + g.top + g.bottom
    -- the backing only as big as the terrain: its square corners would show past the border's angled ones
    local side = math.min(w, h) - 2 * flare.crop
    return w, h, (g.right - g.left) / 2, (g.top - g.bottom) / 2, side, side, side
end
-- Sizes and centres the map frame (frame, on relative), the terrain and the backing to MM.ArtBox;
-- dx, dy: an offset the terrain keeps (a node addon's scan). Returns the terrain's side.
function MM.FitArt(frame, relative, terrain, back, dx, dy)
    local w, h, x, y, side, backW, backH = MM.ArtBox()
    if frame then
        frame:SetSize(w, h)
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", relative, "CENTER", x, y)
    end
    if back then
        MM.MaskBack(back)
        back:SetSize(backW, backH)
        back:ClearAllPoints()
        back:SetPoint("CENTER", relative, "CENTER", x, y)
    end
    if terrain then
        terrain:SetSize(side, side)
        terrain:ClearAllPoints()
        terrain:SetPoint("CENTER", relative, "CENTER", x + (dx or 0), y + (dy or 0))
    end
    return side
end
local HEADER_HEIGHT = 19     -- Forever's header buttons (23 px art), a little smaller
local HEADER_SIDE   = 6      -- header row inset from the frame's sides
local HEADER_GAP    = 2
local CLOCK_WIDTH   = 40
-- Forever's zone plate, stretched along the whole bar with its ends kept whole
local PLATE_ATLAS   = "ui-hud-minimap-header-button"
local PLATE_SLICE   = 12     -- end size, in art pixels
local PLATE_INSET   = 6      -- zone text and clock inset from the plate's ends
local SUN_SCALE     = 0.9    -- day/night badge scale
local MAIL_GAP      = 3      -- title band to mail icon
-- Player coordinates: a size up, in gold, clear of the frame art
local COORDS = {
    GAP = 8,             -- map's bottom edge to the text's bottom
    FONT_STEP = 1,       -- points added to Blizzard's font
    MAP_LIFT = 5,        -- world map coordinates lifted off its edge
}
local ROW_LEVEL     = 5      -- header row above the map and its frame

--------------------------------------------------
-- 4. HELPERS
--------------------------------------------------
local function GetDb()
    return ns.db and ns.db.profile and ns.db.profile.minimap
end

-- Settings > Minimap > Fonts: the zone name and the clock
local function ApplyFont(fontString, font)
    if not (fontString and font) then return end
    local flags = font.flags or ""
    if flags == "NONE" then flags = "" end
    ns.SetFont(fontString, ns.GetFontPath(font.face or "Friz Quadrata TT"), font.size or 12, flags)
    ns.ApplyShadow(fontString, font)
end

function MM:ApplyFonts()
    local db = GetDb()
    if not db then return end
    ApplyFont(_G.MinimapZoneText, db.zoneFont)
    ApplyFont(_G.TimeManagerClockTicker, db.clockFont)
    if self.FitClock then self.FitClock() end
    -- Info Text: the coordinates
    local coords = Cluster.MinimapContainer and Cluster.MinimapContainer.PlayerCoords
    if coords and coords.CoordText then
        ApplyFont(coords.CoordText, db.infoFont)
        coords:SetHeight((db.infoFont and db.infoFont.size or 11) * (ns.TEXT_SCALE or 1) + 2)
    end
    -- the Info Bar's own font (barFont), else Info Text's
    for fontString in pairs(MM.infoTexts) do ApplyFont(fontString, db.barFont or db.infoFont) end
    if self.PlaceBar then self.PlaceBar() end
end
-- the Info Bar's cells, made when first shown (CreateBar)
MM.infoTexts = {}

-- Node addons' scans (Lueur, NodeSight, Nodeworthy): Forever's minimap tooltip only reads the real
-- mouse, so they slide the hidden map under the cursor with AdjustPointsOffset
-- and take their whole offset back at the end. The sum of those moves says where the map is: while
-- it is away, FlareUI keeps their offset when it anchors the map, leaves their empty mask on, keeps
-- the coordinates and auto zoom-out still and lets the mouse wheel through (it would zoom the hidden
-- map instead of the camera). What waited runs once the map is home. NodeRadar never moves it.
-- Node addons (Lueur, NodeSight, Nodeworthy) scan by sliding the hidden map under the cursor. A scan
-- is on while the map is away from home, while one of them holds the map's clicks off (each turns
-- them off at the start and back on at the end), and for a moment after the last move. Lueur
-- parks the map at home, still hidden, while the pointer is on a window, then moves it again: home
-- alone is not the end, and FlareUI's square mask put back there showed the map chasing the cursor.
-- (clicks left off with no move for HELD seconds are not a scan: Lueur's longest wait is 2)
local Scan = { x = 0, y = 0, onHome = {}, clicksOff = false, movedAt = 0, offAt = 0, QUIET = 0.4, HELD = 5 }
function Scan.Away() return math.abs(Scan.x) > 0.5 or math.abs(Scan.y) > 0.5 end
function Scan.Busy()
    local since = GetTime() - math.max(Scan.movedAt, Scan.offAt)
    return Scan.Away() or (Scan.clicksOff and since < Scan.HELD) or (GetTime() - Scan.movedAt) < Scan.QUIET
end
function Scan.Later(key, fn) Scan.onHome[key] = fn end
local function ScanCheck()
    local busy, was = Scan.Busy(), Scan.wasBusy
    if busy ~= was then
        Scan.wasBusy = busy
        if Scan.UpdateArt then Scan.UpdateArt() end
        if Scan.OnChange then Scan.OnChange(busy) end
    end
    if busy then
        -- the time limits run out with no call of theirs: look again then
        if not Scan.Away() and not Scan.timer then
            Scan.timer = C_Timer.NewTimer(Scan.clicksOff and 1 or Scan.QUIET, function() Scan.timer = nil; ScanCheck() end)
        end
        return
    end
    if not was then return end   -- (not the end of a scan: none was on)
    local waiting = Scan.onHome
    Scan.onHome = {}
    for _, fn in pairs(waiting) do fn() end
    if Scan.OnEnd then Scan.OnEnd() end
end
function Scan.Watch()
    if Scan.watching or not MinimapFrame.AdjustPointsOffset then return end
    Scan.watching = true
    hooksecurefunc(MinimapFrame, "AdjustPointsOffset", function(_, dx, dy)
        if type(dx) ~= "number" or type(dy) ~= "number" or not (canaccessvalue(dx) and canaccessvalue(dy)) then return end
        Scan.x, Scan.y = Scan.x + dx, Scan.y + dy
        if not Scan.Away() then Scan.x, Scan.y = 0, 0 end
        Scan.movedAt = GetTime()
        if Scan.Away() and Scan.OnAway then Scan.OnAway() end
        ScanCheck()
    end)
    if MinimapFrame.SetMouseClickEnabled then
        hooksecurefunc(MinimapFrame, "SetMouseClickEnabled", function(_, enabled)
            if not canaccessvalue(enabled) then return end
            Scan.clicksOff = not enabled
            if not enabled then Scan.offAt = GetTime() end
            ScanCheck()
        end)
    end
end

local hiddenParent = CreateFrame("Frame", nil, UIParent)
hiddenParent:Hide()

-- Takes a non-secure Blizzard element off screen for good
local function Remove(object)
    if not object then return end
    object:Hide()
    if object.EnableMouse then object:EnableMouse(false) end
    object:SetParent(hiddenParent)
end

local function Raise(frame, extra)
    if frame then frame:SetFrameLevel(MinimapFrame:GetFrameLevel() + ROW_LEVEL + (extra or 0)) end
end

--------------------------------------------------
-- 5. THE SQUARE MAP
--------------------------------------------------
-- Other addons' minimap buttons read the GetMinimapShape global
local function MinimapShape() return "SQUARE" end

local function SquareHybridMinimap()
    local hybrid = _G.HybridMinimap
    if not hybrid then return end
    hybrid.CircleMask:SetTexture(SQUARE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    hybrid.MapCanvas:SetMaskTexture(hybrid.CircleMask)
end

-- A copy of Blizzard's layout with its left side moved out to the map's edge
local function BorderLayout(style)
    style = style or HeaderStyle()
    local layout = {}
    for key, value in pairs(NineSliceUtil.GetLayout(BORDER_LAYOUT)) do
        if type(value) == "table" then
            local piece = {}
            for k, v in pairs(value) do piece[k] = v end
            value = piece
        end
        layout[key] = value
    end
    for _, key in ipairs({ "TopLeftCorner", "BottomLeftCorner" }) do
        if layout[key] then layout[key].x = (layout[key].x or 0) + LEFT_SHIFT end
    end
    -- Headerless: the top edge down onto the map's top (with the border under the map, a black gap
    -- would show between them); it hangs between the top corners, so it moves with them
    for _, key in ipairs({ "TopLeftCorner", "TopRightCorner" }) do
        if layout[key] then layout[key].y = (layout[key].y or 0) - style.drop end
    end
    return layout
end

-- The border in the chosen Header style. It lies under the map, but some pieces reach in
-- over the map and draw on `above`, a frame just over the map in its strata (addon buttons are MEDIUM,
-- above both): always the sides, the bottom and its corners (the map cut their inner shadow and its
-- square corners across them), and with Bordered the title bar and its corners too. The pieces stay
-- border.TopEdge etc. for measuring.
local TOP_PIECES = { "TopEdge", "TopLeftCorner", "TopRightCorner" }
local function ApplyBorder(border, above, style)
    style = style or HeaderStyle()
    NineSliceUtil.ApplyLayout(border, BorderLayout(style))
    -- the sides and bottom too: their inner shadow falls over the map's edges, and the map would cut
    -- it off if they lay under it
    for _, key in ipairs({ "BottomLeftCorner", "BottomRightCorner", "LeftEdge", "RightEdge", "BottomEdge" }) do
        if border[key] then border[key]:SetParent(above) end
    end
    for _, key in ipairs(TOP_PIECES) do
        if border[key] then border[key]:SetParent(style.over and above or border) end
    end
    for _, key in ipairs({ "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
                           "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center" }) do
        MM.TintArt(border[key])
    end
    -- Headerless in the heavy bronze frame (BRONZE_ATLAS): Blizzard's own frames stretch it to any size
    local bronze = style.bronze and C_Texture.GetAtlasInfo(BRONZE_ATLAS) and true or false
    if bronze and not above.Bronze then
        above.Bronze = above:CreateTexture(nil, "BORDER")
        above.Bronze:SetAtlas(BRONZE_ATLAS)
        MM.TintArt(above.Bronze)
        above.Bronze:SetPoint("TOPLEFT", border, "TOPLEFT", -BRONZE_OUT.left, BRONZE_OUT.top)
        above.Bronze:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", BRONZE_OUT.right, -BRONZE_OUT.bottom)
    end
    if above.Bronze then above.Bronze:SetShown(bronze) end
    -- Headerless in a FlareUI border (style.flare): its edge on `above`, over the map, so its inner
    -- shadow covers the terrain's edge; on the map frame's edges (MM.ArtBox sizes it to the edge frame)
    local flare = style.flare
    if flare and not above.Flare then
        above.Flare = CreateFrame("Frame", nil, above, "BackdropTemplate")
    end
    if flare and above.Flare.spec ~= flare then
        local edge = above.Flare
        edge.spec = flare
        edge:ClearAllPoints()
        edge:SetAllPoints(border)
        edge:SetBackdrop({ edgeFile = LibStub("LibSharedMedia-3.0"):Fetch("border", flare.lsm), edgeSize = flare.edge })
        local c = ns.BORDER_COLOR
        edge:SetBackdropBorderColor(c.r, c.g, c.b, 1)
    end
    if above.Flare then above.Flare:SetShown(flare and true or false) end
    for _, key in ipairs({ "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
                           "TopEdge", "BottomEdge", "LeftEdge", "RightEdge" }) do
        if border[key] then border[key]:SetAlpha((bronze or flare) and 0 or 1) end
    end
end

local function CreateMapArt()
    -- On the cluster, placed where the map sits (UpdateLayout centres the map on the cluster), never
    -- parented or anchored to the map: node addons (Lueur, NodeSight) slide the map under the cursor
    -- and fade it out to read its tooltips. The tracking button, indicators, coordinates and sun hang
    -- off this frame, so anything tied to the map chased the cursor and flickered.
    local frame = CreateFrame("Frame", nil, Cluster)
    frame:SetPoint("CENTER", Cluster, "CENTER", 0, 0)
    frame:SetSize(MAP_SIZE, MAP_SIZE)
    frame:SetFrameStrata(MinimapFrame:GetFrameStrata())
    frame:SetFrameLevel(MinimapFrame:GetFrameLevel() + 2)
    -- the bronze border itself on a frame of its own in the lowest strata: under the map and everything
    -- on and around it, so no addon button can ever sit beneath it. The frame above keeps holding the
    -- tracking button, indicators, coordinates and sun at their own levels.
    local border = CreateFrame("Frame", nil, frame)
    border:SetAllPoints(frame)
    border:SetFrameStrata("BACKGROUND")
    local above = CreateFrame("Frame", nil, frame)
    above:SetAllPoints(frame)
    above:SetFrameStrata(MinimapFrame:GetFrameStrata())
    above:SetFrameLevel(MinimapFrame:GetFrameLevel() + 1)
    ApplyBorder(border, above)
    MM.Frame = frame
    MM.Border = border
    MM.BorderAbove = above
    -- the addon buttons left out of the drawer, above the border (MM.LiftMapButtons): on the art frame,
    -- so they show, hide and fade with the map's frame, never with the map a node addon moves
    local holder = CreateFrame("Frame", nil, frame)
    holder:SetAllPoints(frame)
    holder:SetFrameStrata("MEDIUM")
    MM.ButtonHolder = holder

    -- black where the map texture has no data. On the cluster, so it draws under the map, and placed
    -- where the map sits (ApplyLayout) rather than anchored to it: some node addons move the invisible
    -- map under the cursor to read its tooltip, and a texture anchored to it would follow the cursor
    local back = Cluster:CreateTexture(nil, "BACKGROUND")
    back:SetPoint("CENTER", Cluster, "CENTER", 0, 0)
    back:SetSize(MAP_SIZE - 2 * MAP_CROP, MAP_SIZE - 2 * MAP_CROP)
    back:SetColorTexture(0, 0, 0, 1)
    MM.Back = back   -- (sized with the map frame: MM.FitArt)

    -- Keep the stationary border during a scan, but not the opaque backing: with the real map
    -- away it leaves a black rectangle wherever the scanner has no replacement terrain to draw.
    -- Both still follow an explicitly hidden map (Toggle Minimap key, a full fade).
    local function FollowMapShown()
        local shown = MinimapFrame:IsShown()
        frame:SetShown(shown)
        back:SetShown(shown and not Scan.Busy())
    end
    Scan.UpdateArt = FollowMapShown
    MinimapFrame:HookScript("OnShow", FollowMapShown)
    MinimapFrame:HookScript("OnHide", FollowMapShown)
    FollowMapShown()
end

local function ApplySquareMap()
    MinimapFrame:SetMaskTexture(MM.mapFaded and MASKS.EMPTY or MM.SquareMask())
    MinimapFrame:SetArchBlobRingScalar(0)
    MinimapFrame:SetQuestBlobRingScalar(0)
    MinimapFrame:SetTaskBlobRingScalar(0)
    _G.GetMinimapShape = MinimapShape
    SquareHybridMinimap()
end

--------------------------------------------------
-- 6. HEADER, INDICATORS AND BADGES
--------------------------------------------------
-- Forever's header buttons draw their art at atlas size on every mouse state: two anchors fit it to
-- the button (anchors outrank the size)
local function FitButtonArt(button)
    for _, key in ipairs({ "StateTexture", "AddTexture" }) do
        local texture = button and button[key]
        if texture then
            texture:ClearAllPoints()
            texture:SetAllPoints(button)
        end
    end
end

-- Blizzard's minimap art in FlareUI's bronze (11-20, palette work): the heavy bronze frame, the
-- Bordered frame's pieces, Forever's round ring and the zone / Info Bar plates, multiplied like the
-- unit frames' plate (UnitFramesRing.lua Ring.PLATE_TINT; picked in game 11-20).
MM.ART_TINT = { 0.88, 0.80, 0.66 }
function MM.TintArt(texture)
    if not texture then return end
    local t = MM.ART_TINT
    texture:SetVertexColor(t[1], t[2], t[3])
end

-- Forever's zone plate stretched over a frame, its ends kept whole
local function Plate(texture, frame)
    texture:SetAtlas(PLATE_ATLAS)
    MM.TintArt(texture)
    texture:ClearAllPoints()
    texture:SetAllPoints(frame)
    if texture.SetTextureSliceMargins then
        texture:SetTextureSliceMargins(PLATE_SLICE, PLATE_SLICE, PLATE_SLICE, PLATE_SLICE)
        if Enum.UITextureSliceMode then texture:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched) end
    end
end

-- The bar behind the zone text and clock: Forever's cluster has no BorderTop, and the zone button's
-- own plate is a fixed width (also the settings preview's sample header)
local function CreateHeader(parent)
    local header = CreateFrame("Frame", nil, parent)
    header:SetHeight(HEADER_HEIGHT)
    header.Plate = header:CreateTexture(nil, "BACKGROUND")
    Plate(header.Plate, header)
    return header
end

-- The clock's width: room for its time text, never under CLOCK_WIDTH
function MM.ClockWidth(ticker)
    return math.max(CLOCK_WIDTH, math.ceil(ticker:GetUnboundedStringWidth() or 0) + 2 + PLATE_INSET)
end

-- The zone button spans the bar up to the clock; Forever's cluster re-places it, so every layout
-- pass puts it back
local clockWidth = CLOCK_WIDTH
local function PlaceZone()
    local zoneButton, header = Cluster.ZoneTextButton, MM.Header
    zoneButton:ClearAllPoints()
    zoneButton:SetPoint("TOPLEFT", header, "TOPLEFT", HEADER_GAP, 0)
    zoneButton:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -clockWidth, 0)
    Raise(zoneButton)
end

-- Forever's round art, parked: an alpha of 0 isn't enough, as any addon tinting it with
-- SetVertexColor sets the alpha too (BetterBlizzFrames does at every login). Forever's skin shows a
-- round underlay whenever rotateMinimap is on. Parked again when a HUD gives the map back.
local function ParkRoundArt()
    for _, art in ipairs({ _G.MinimapCompassTexture, _G.MinimapCompassTextureUnderlay }) do
        if art and (art:GetParent() ~= hiddenParent or art:IsShown()) then Remove(art) end
    end
end

local function StyleHeader()
    local compass = _G.MinimapCompassTexture
    Remove(compass)
    hooksecurefunc(compass, "SetParent", function(self, parent)
        if parent ~= hiddenParent then self:SetParent(hiddenParent) end
    end)
    Remove(_G.MinimapCompassTextureUnderlay)
    Remove(MinimapFrame.ZoomIn)
    Remove(MinimapFrame.ZoomOut)
    Remove(MinimapFrame.ZoomHitArea)
    if _G.MinimapBackdrop then Remove(_G.MinimapBackdrop.StaticOverlayTexture) end

    local header = CreateHeader(Cluster)
    MM.Header = header
    for _, frame in ipairs({ Cluster.ZoneTextButton, Cluster.Tracking, _G.GameTimeFrame }) do Raise(frame) end
    Raise(header, -1)

    -- tracking and calendar: squares as tall as the header
    local tracking = Cluster.Tracking
    tracking:SetSize(HEADER_HEIGHT, HEADER_HEIGHT)
    if tracking.Background then tracking.Background:Hide() end   -- the button art has its own frame
    tracking.Button:ClearAllPoints()
    tracking.Button:SetAllPoints(tracking)
    FitButtonArt(tracking.Button)
    local calendar = _G.GameTimeFrame
    calendar:SetSize(HEADER_HEIGHT, HEADER_HEIGHT)
    FitButtonArt(calendar)

    -- the plate is the header's; the zone button's mouse-over glow spreads over all of it
    local zoneButton, zoneText = Cluster.ZoneTextButton, _G.MinimapZoneText
    if zoneButton.StateTexture then zoneButton.StateTexture:SetParent(hiddenParent) end
    if zoneButton.AddTexture then Plate(zoneButton.AddTexture, header) end
    PlaceZone()
    zoneText:ClearAllPoints()
    zoneText:SetPoint("TOPLEFT", zoneButton, "TOPLEFT", PLATE_INSET, 0)
    zoneText:SetPoint("BOTTOMRIGHT", zoneButton, "BOTTOMRIGHT", 0, 0)
    zoneText:SetJustifyH("LEFT")
    zoneText:SetWordWrap(false)

    -- clock: the bar's right end; grows with the time text, taking width from the zone text
    EventUtil.ContinueOnAddOnLoaded("Blizzard_TimeManager", function()
        local clock, ticker = _G.TimeManagerClockButton, _G.TimeManagerClockTicker
        if not clock then return end
        clock:ClearAllPoints()
        clock:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, 0)
        clock:SetSize(CLOCK_WIDTH, HEADER_HEIGHT)
        clock:SetHitRectInsets(0, 0, 0, 0)
        Raise(clock)
        ticker:ClearAllPoints()
        ticker:SetPoint("RIGHT", clock, "RIGHT", -PLATE_INSET, 0)
        ticker:SetFontObject("GameFontHighlight")

        local function FitClock()
            local width = MM.ClockWidth(ticker)
            if width == clock:GetWidth() then return end
            clock:SetWidth(width)
            clockWidth = width
            PlaceZone()
        end
        hooksecurefunc("TimeManagerClockButton_Update", FitClock)
        MM.FitClock = FitClock
        MM:ApplyFonts()
    end)
    MM:ApplyFonts()
end

-- Tracking, the zone / clock bar and the calendar, left to right along the frame art's top (the
-- real row and the settings preview's sample)
function MM.PlaceHeaderRow(frame, tracking, header, calendar)
    tracking:ClearAllPoints()
    calendar:ClearAllPoints()
    header:ClearAllPoints()
    local side = HeaderStyle().side or HEADER_SIDE   -- (the bronze frame's sides are thicker: the zone bar narrows)
    -- shift: the row centred on the frame art, not the map (the bronze reaches 9 out on the left, 7 on
    -- the right: its centre is 1 left of the map's)
    tracking:SetPoint("TOPLEFT", frame, "TOPLEFT", side + (HeaderStyle().shift or 0), -HeaderStyle().headerTop)
    header:SetPoint("LEFT", tracking, "RIGHT", HEADER_GAP, 0)
    header:SetWidth(frame:GetWidth() - 2 * side - tracking:GetWidth() - calendar:GetWidth() - 2 * HEADER_GAP)
    calendar:SetPoint("LEFT", header, "RIGHT", HEADER_GAP, 0)
end

local function PlaceHeader()
    MM.PlaceHeaderRow(MM.Frame, Cluster.Tracking, MM.Header, _G.GameTimeFrame)
    PlaceZone()
end

-- Mail and similar indicators: top-left, just below the title band
local function PlaceIndicators()
    local indicators = Cluster.IndicatorFrame
    Raise(indicators)
    indicators:ClearAllPoints()
    local style = HeaderStyle()
    indicators:SetPoint("TOPLEFT", MM.Frame, "TOPLEFT", style.side or HEADER_SIDE, -(style.band + MAIL_GAP))
end

-- One size up and in Blizzard's gold, once per font string
local function RestyleCoordText(text)
    if not text or text.FlareUI_Styled then return end
    text.FlareUI_Styled = true
    local font, size, flags = text:GetFont()
    if font and size then text:SetFont(font, size + COORDS.FONT_STEP, flags) end
    local c = NORMAL_FONT_COLOR
    text:SetTextColor(c.r, c.g, c.b)
end

local Bar = { cells = {}, lines = {}, picks = {}, at = {}, SUN_ROOM = 30, shown = false }
Bar.SIDES = { "left", "center", "right" }
Bar.ICONS = { bags = "Interface\\Buttons\\Button-Backpack-Up", durability = "Interface\\Minimap\\Tracking\\Repair" }
Bar.COINS = { "ffffd700", "ffc7c7cf", "ffeda55f" }
Bar.WARN, Bar.ALERT, Bar.BAGS_WARN = "|cffff9933", "|cffff4040", 0.85

local function BarMoney()
    local cash = GetMoney() or 0
    local coins = { math.floor(cash / 10000), math.floor(cash / 100) % 100, cash % 100 }
    local symbols = { _G.GOLD_AMOUNT_SYMBOL or "g", _G.SILVER_AMOUNT_SYMBOL or "s", _G.COPPER_AMOUNT_SYMBOL or "c" }
    -- copper only below 1 gold; silver dropped from 1000 gold
    local last = coins[1] >= 1000 and 1 or coins[1] >= 1 and 2 or 3
    local parts = {}
    for i = 1, last do
        if coins[i] > 0 or #parts > 0 or i == last then
            parts[#parts + 1] = ("|c%s%d%s|r"):format(Bar.COINS[i], coins[i], symbols[i])
        end
    end
    return table.concat(parts, " ")
end

local function BarBags()
    local used, total = 0, 0
    for bag = 0, _G.NUM_BAG_SLOTS or 4 do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        local free, family = C_Container.GetContainerNumFreeSlots(bag)
        if slots > 0 and (family or 0) == 0 then
            total = total + slots
            used = used + slots - (free or 0)
        end
    end
    local color = (total > 0 and used >= total) and Bar.ALERT or (total > 0 and used / total >= Bar.BAGS_WARN) and Bar.WARN or ""
    return ("|T%s:0:0:0:-1|t %s%d/%d%s"):format(Bar.ICONS.bags, color, used, total, color ~= "" and "|r" or "")
end

local function BarDurability()
    local low, alert = nil, 0
    for slot = 1, 18 do
        local cur, max = GetInventoryItemDurability(slot)
        if canaccessvalue(cur) and canaccessvalue(max) and cur and max and max > 0 then
            if not low or cur / max < low then low = cur / max end
            local status = GetInventoryAlertStatus and GetInventoryAlertStatus(slot)
            if type(status) ~= "number" then status = cur == 0 and 2 or cur / max < 0.2 and 1 or 0 end
            if status > alert then alert = status end
        end
    end
    if not low then return ("|T%s:0|t -"):format(Bar.ICONS.durability) end
    local color = alert >= 2 and Bar.ALERT or alert == 1 and Bar.WARN or "|cffffffff"
    return ("|T%s:0|t %s%d%%|r"):format(Bar.ICONS.durability, color, math.floor(low * 100 + 0.5))
end

-- Coords (Decimals) "45.3, 62.1"; whole: Coords (Simple) "45, 62"
local function BarCoords(whole)
    local map = C_Map.GetBestMapForUnit("player")
    local pos = map and C_Map.GetPlayerMapPosition(map, "player")
    if not pos then return "-" end
    local x, y = pos:GetXY()
    if whole then return ("%d, %d"):format(math.floor(x * 100), math.floor(y * 100)) end
    return ("%.1f, %.1f"):format(x * 100, y * 100)
end

Bar.sources = {
    gold       = { text = BarMoney, events = { "PLAYER_MONEY" } },
    bags       = { text = BarBags, events = { "BAG_UPDATE_DELAYED" } },
    durability = { text = BarDurability, events = { "UPDATE_INVENTORY_DURABILITY", "PLAYER_EQUIPMENT_CHANGED" } },
    fps        = { text = function() return ("%.0f fps"):format(GetFramerate()) end, every = 1, sample = "888 fps" },
    latency    = { text = function()
        local _, _, home, world = GetNetStats()
        -- just the numbers, home / world: "ms" doesn't fit a cell
        return ("%d / %d"):format(home or 0, world or 0)
    end, every = 1, sample = "888 / 888" },
    -- sample: the widest text a cell can show, so the cell is sized for it before it changes (Bar.Need)
    coords       = { text = function() return BarCoords(false) end, every = 0.2, sample = "88.8, 88.8" },
    coordsSimple = { text = function() return BarCoords(true) end, every = 0.2, sample = "88, 88" },
    -- Experience: how far into the level, "XP 45%" (Sam's idea 11-19); the rested part in blue
    -- after it; at the level cap, the level alone
    xp = { text = function()
        local max = UnitXPMax("player") or 0
        if (IsPlayerAtEffectiveMaxLevel and IsPlayerAtEffectiveMaxLevel()) or max <= 0 then
            return (_G.LEVEL or "Level") .. " " .. (UnitLevel("player") or "")
        end
        local text = ("XP %d%%"):format(math.floor((UnitXP("player") or 0) / max * 100))
        local rested = GetXPExhaustion and GetXPExhaustion() or 0
        if rested > 0 then text = text .. (" |cff4d85e6+%d%%|r"):format(math.floor(rested / max * 100)) end
        return text
    end, events = { "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION" }, sample = "XP 88% +88%" },
}
Bar.PAD = 8   -- a cell's room around its widest text

function Bar.Lift()
    return Bar.shown and (MM.SquareBorder().barBottom + (Bar.height or HEADER_HEIGHT) - 4) or 0
end

-- The width cell i needs for its source's sample in the cell's own font (0: no sample, the even share
-- is enough). The cell's text is put back after measuring.
function Bar.Need(i)
    local source = Bar.sources[Bar.picks[Bar.SIDES[i]]]
    local sample = source and source.sample
    if type(sample) == "function" then sample = sample() end
    local fs = Bar.cells[i]
    if not (sample and fs) then return 0 end
    local old = fs:GetText()
    fs:SetText(sample)
    local width = fs:GetUnboundedStringWidth() or 0
    fs:SetText(old or "")
    return width + Bar.PAD
end

function Bar.Fill(timedOnly)
    local now = GetTime()
    for i, side in ipairs(Bar.SIDES) do
        local source = Bar.sources[Bar.picks[side]]
        if not source then
            Bar.cells[i]:SetText("")
        elseif not timedOnly or (source.every and now - (Bar.at[i] or 0) >= source.every - 0.05) then
            Bar.cells[i]:SetText(source.text())
            Bar.at[i] = now
        end
    end
end

local function CreateBar()
    -- the round map has no frame of FlareUI's: the bar hangs on Blizzard's cluster
    local f = CreateFrame("Frame", nil, MM.Frame or Cluster)
    f:SetHeight(HEADER_HEIGHT)
    -- a plate in the zone plate's look only under the cells in use: one per run of neighbouring cells
    -- (all three used: one plate over the whole bar). Bar.Place sizes them.
    f.Plates = {}
    for i = 1, #Bar.SIDES do
        f.Plates[i] = f:CreateTexture(nil, "BACKGROUND")
        Plate(f.Plates[i], f)
    end
    local c = NORMAL_FONT_COLOR
    for i = 1, #Bar.SIDES do
        local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetWordWrap(false)
        fs:SetTextColor(c.r, c.g, c.b)
        local db = GetDb()
        if db and (db.barFont or db.infoFont) then ApplyFont(fs, db.barFont or db.infoFont) end
        MM.infoTexts[fs] = true
        Bar.cells[i] = fs
        if i > 1 then
            local line = f:CreateTexture(nil, "ARTWORK")
            line:SetColorTexture(c.r, c.g, c.b, 0.25)
            Bar.lines[i - 1] = line
        end
    end
    f:SetScript("OnEvent", function() Bar.Fill() end)
    f:SetScript("OnShow", function() Bar.Fill(); Bar.Tick() end)
    f:SetScript("OnHide", function() Bar.Tick() end)
    Bar.frame = f
end

function Bar.Tick()
    local every = Bar.frame and Bar.frame:IsVisible() and Bar.every or nil
    if Bar.ticker and every ~= Bar.ticking then Bar.ticker:Cancel(); Bar.ticker = nil end
    if every and not Bar.ticker then
        Bar.ticking = every
        Bar.ticker = C_Timer.NewTicker(every, function() Bar.Fill(true) end)
    end
end

-- Round style: the Center cell alone, inside the circle at its bottom, the size of a
-- square map's cell (its bar's height; its width with the sundial: (MAP_SIZE - SUN_ROOM - HEADER_SIDE) / 3),
-- raised clear of the circle's curve. The frame is three cells wide so the Center cell lands in the middle.
Bar.ROUND_UP = 14
function Bar.PlaceRound(f)
    Bar.ROUND_CELL = Bar.ROUND_CELL or math.floor((MAP_SIZE - Bar.SUN_ROOM - HEADER_SIDE) / #Bar.SIDES)
    f:SetHeight(HEADER_HEIGHT)
    local width = Bar.ROUND_CELL * #Bar.SIDES
    f:ClearAllPoints()
    f:SetWidth(width)
    f:SetPoint("BOTTOM", MinimapFrame, "BOTTOM", 0, Bar.ROUND_UP)
    return width
end

function Bar.Place()
    local f = Bar.frame
    local style = HeaderStyle()
    local side, shift = style.barSide or style.side or HEADER_SIDE, style.shift or 0
    local sun = Cluster.DielFrame
    -- the room for the sundial only while it shows: the Sundial switch (Map Tools) hides
    -- it by its look, so the frame still counts as shown
    local bag = ns.MinimapBag
    local sunShown = sun and sun:IsShown() and not (bag and bag.SundialShown and not bag.SundialShown()) or false
    -- the bar's height follows its font (never below the header buttons' height); first, as the
    -- sundial's room depends on the bar's band
    local size = Bar.cells[1] and select(2, ns.GetWantedFont(Bar.cells[1]))
    Bar.height = math.max(HEADER_HEIGHT, math.ceil(type(size) == "number" and size or 0) + 8)
    local left, right = side, side
    if sunShown then left, right = Bar.SunRoom(side) end
    -- what this layout was made for: a drag of the sundial lays the bar out again only when it changes
    Bar.side, Bar.sunShown, Bar.sunLeft, Bar.sunRight = side, sunShown, left, right
    local inner
    if squareStyle then
        f:ClearAllPoints()
        local bottom = style.border.barBottom
        f:SetPoint("BOTTOMLEFT", MM.Frame, "BOTTOMLEFT", left + shift, bottom)
        f:SetPoint("BOTTOMRIGHT", MM.Frame, "BOTTOMRIGHT", -right + shift, bottom)
        inner = MM.Frame:GetWidth() - left - right
    else
        inner = Bar.PlaceRound(f)
    end
    Raise(f)
    f:SetHeight(Bar.height)
    -- each cell an even share of the bar, a used one wider when its text needs it; unused cells give up
    -- their room first, and a bar still too wide spills evenly past both ends
    local count = #Bar.SIDES
    local share = inner / count
    local used, width, center = {}, {}, {}
    local total, free = 0, 0
    for i, sideName in ipairs(Bar.SIDES) do
        used[i] = Bar.picks[sideName] ~= nil
        width[i] = used[i] and math.max(share, Bar.Need(i)) or share
        if not used[i] then free = free + 1 end
        total = total + width[i]
    end
    if total > inner and free > 0 then
        local spare = math.max(0, share - (total - inner) / free)
        for i = 1, count do
            if not used[i] then total = total - width[i] + spare; width[i] = spare end
        end
    end
    local x = (inner - total) / 2
    for i = 1, count do
        center[i] = x + width[i] / 2
        x = x + width[i]
    end
    -- the Middle cell alone: centred on the map itself, not on the room beside the sundial
    if used[2] and not used[1] and not used[3] then
        center[2] = squareStyle and (MM.Frame:GetWidth() / 2 - left) or inner / 2
    end
    for i, fs in ipairs(Bar.cells) do
        fs:ClearAllPoints()
        fs:SetPoint("CENTER", f, "LEFT", center[i], 0)
        fs:SetWidth(math.max(1, width[i] - 4))
    end
    -- a divider only between two cells in use (they share a plate). Show Box off (minimap.infoBarBox):
    -- no plates or dividers, the text alone
    local db = GetDb()
    local box = not (db and db.infoBarBox == false)
    local px = ns.PixelSize(f)
    for i, line in ipairs(Bar.lines) do
        line:ClearAllPoints()
        line:SetSize(px, Bar.height - 8)
        line:SetPoint("CENTER", f, "LEFT", center[i] + width[i] / 2, 0)
        line:SetShown(box and used[i] and used[i + 1] or false)
    end
    -- the plates: one per run of cells in use, from its first cell's left edge to its last one's right
    local n, i = 0, 1
    while i <= #Bar.SIDES do
        if box and used[i] then
            local first = i
            while i < #Bar.SIDES and used[i + 1] do i = i + 1 end
            n = n + 1
            local plate = f.Plates[n]
            plate:ClearAllPoints()
            plate:SetPoint("TOPLEFT", f, "TOPLEFT", center[first] - width[first] / 2, 0)
            plate:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", center[i] + width[i] / 2, 0)
            plate:Show()
        end
        i = i + 1
    end
    for k = n + 1, #f.Plates do f.Plates[k]:Hide() end
end

function Bar.Update()
    local db = GetDb()
    local picks = db and db.infoBar or {}
    local shown, every = false, nil
    for _, side in ipairs(Bar.SIDES) do
        -- (the round map: the Center cell only)
        local source = (MM.Frame or (not squareStyle and side == "center")) and Bar.sources[picks[side]]
        Bar.picks[side] = source and picks[side] or nil
        if source then
            shown = true
            if source.every and (not every or source.every < every) then every = source.every end
        end
    end
    Bar.shown = shown
    Bar.every = every
    if shown then
        if not Bar.frame then CreateBar() end
        local f = Bar.frame
        f:UnregisterAllEvents()
        f:RegisterEvent("PLAYER_ENTERING_WORLD")
        for _, side in ipairs(Bar.SIDES) do
            for _, event in ipairs(Bar.sources[Bar.picks[side]] and Bar.sources[Bar.picks[side]].events or {}) do
                f:RegisterEvent(event)
            end
        end
        f:Show()
        Bar.Place()
        Bar.Fill()
    elseif Bar.frame then
        Bar.frame:UnregisterAllEvents()
        Bar.frame:Hide()
    end
    Bar.Tick()
end

-- a font change resizes the cells to the new text (MM:ApplyFonts)
function MM.PlaceBar()
    if not (Bar.frame and Bar.shown) or MM.MapAway() then return end
    Bar.Place()
    Bar.Fill()
end

local function StyleCoords()
    local coords = Cluster.MinimapContainer and Cluster.MinimapContainer.PlayerCoords
    if not coords then return end
    local text = coords.CoordText
    RestyleCoordText(text)
    -- Info Text font (Minimap > Fonts), over the size-up above
    local db = GetDb()
    if text and db and db.infoFont then ApplyFont(text, db.infoFont) end
    local size = text and select(2, ns.GetWantedFont(text)) or 10
    coords:SetHeight(size + 2)
    return coords
end

local function PlaceCoords()
    local coords = StyleCoords()
    if not coords then return end
    Raise(coords)
    coords:ClearAllPoints()
    coords:SetPoint("BOTTOM", MM.Frame, "BOTTOM", 0, COORDS.GAP + Bar.Lift())
end

-- The world map's coordinates in the same style; one anchor per label so the bigger font is not cut
-- by its 100 px frame. Leatrix Maps has its own coordinate footer there: left alone.
local function RestyleWorldMapCoords()
    if C_AddOns.IsAddOnLoaded("Leatrix_Maps") then return end
    local map = _G.WorldMapFrame
    for _, frame in ipairs(map and map.overlayFrames or {}) do
        if frame.PlayerCoords and frame.CursorCoords then
            for _, key in ipairs({ "CursorCoords", "CrosshairCoords", "PlayerCoords" }) do
                local row = frame[key]
                local label = row and row.Label
                if label and not label.FlareUI_Styled then
                    RestyleCoordText(label)
                    label:ClearAllPoints()
                    label:SetPoint("LEFT", row, "LEFT", 0, COORDS.MAP_LIFT)
                end
            end
        end
    end
end

-- Forever's day/night badge (also the Addon Button Bag's button, MinimapBag.lua). Square style: the
-- map's bottom-left corner, always shown. Round style: Blizzard's own spot (Diel.lua's transform).
-- Nothing else may place it: other addons (EnhanceQoL's "Minimap moon") put it over the calendar.
-- A spot the player gave it on the map's edge (MM.Moves: an angle, a size) is the one kept instead.
local SUN_ROUND_X, SUN_ROUND_Y = 55, 86   -- Diel.lua's DielFrameData.AnchorX / AnchorY

-- scale, point, relative frame, relative point, x, y
local function SunSpot()
    -- the player's own angle and size (MM.Moves), on the same edge line the badge sits on by default:
    -- at the default angle and size it lands on the default spot exactly
    local moves = MM.Moves
    local angle, size = moves.Angle("sundial"), moves.Scale("sundial")
    if angle or size ~= 1 then
        if squareStyle then
            -- its centre from MM.Frame's centre, in MM.Frame's units (the badge's parent, the
            -- container, has the same scale on the square map): the default corner spot's reach
            local sun = Cluster.DielFrame
            local width = ((sun:GetWidth() or 0) + (sun:GetHeight() or 0)) / 2
            local out = MM.SquareBorder().sun - width * SUN_SCALE / 2
            local x, y = moves.EdgeXY(angle or moves.SUN_SQUARE_ANGLE, MM.Frame:GetWidth() / 2 + out,
                MM.Frame:GetHeight() / 2 + out)
            local scale = SUN_SCALE * size
            return scale, "CENTER", MM.Frame, "CENTER", x / scale, y / scale
        end
        -- round: on Blizzard's own circle through its spot, in the container's units
        local container = Cluster.MinimapContainer
        local s = container:GetScale()
        if not (s and s > 0) then s = 1 end
        local a = angle and math.rad(angle) or math.atan2(SUN_ROUND_Y, SUN_ROUND_X)
        -- (offsets are in the badge's own, scaled units)
        local r = math.sqrt(SUN_ROUND_X * SUN_ROUND_X + SUN_ROUND_Y * SUN_ROUND_Y) * s / size
        return size / s, "CENTER", container, "CENTER", math.cos(a) * r, math.sin(a) * r
    end
    if squareStyle then
        local overhang = MM.SquareBorder().sun / SUN_SCALE   -- offsets are in the badge's own, scaled units
        return SUN_SCALE, "BOTTOMLEFT", MM.Frame, "BOTTOMLEFT", -overhang, -overhang
    end
    local container = Cluster.MinimapContainer
    local s = container:GetScale()
    if not (s and s > 0) then s = 1 end
    return 1 / s, "CENTER", container, "CENTER", SUN_ROUND_X * s, SUN_ROUND_Y * s
end

-- The Info Bar's room at each end of the square map for the sundial (side: the bar's plain margin),
-- left and right. In its default spot: the border's sunRoom at the left. Moved or resized: room only at
-- the end where it overlaps the bar's band, as much more or less than sunRoom as its inner edge lies past
-- or short of the default badge's; none when it sits over the bar's middle third instead.
function Bar.SunRoom(side)
    local sun = Cluster.DielFrame
    if not (squareStyle and sun and MM.Frame) then return side, side end
    local moves = MM.Moves
    local spec = MM.SquareBorder()
    if not moves.Angle("sundial") and moves.Scale("sundial") == 1 then return spec.sunRoom, side end
    local w, h = sun:GetWidth() or 0, sun:GetHeight() or 0
    local scale, _, _, _, x, y = SunSpot()
    -- its centre from MM.Frame's centre and its half sizes, in MM.Frame's units
    x, y = x * scale, y * scale
    local halfW, halfH = w * scale / 2, h * scale / 2
    local mapW = MM.Frame:GetWidth()
    local bottom = spec.barBottom - MM.Frame:GetHeight() / 2
    if y - halfH >= bottom + (Bar.height or HEADER_HEIGHT) or y + halfH <= bottom then return side, side end
    -- how far its inner edge lies from its end of the map, against the default badge's
    local reach = x <= 0 and (x + halfW + mapW / 2) or (mapW / 2 - x + halfW)
    local room = math.floor(spec.sunRoom + reach - (w * SUN_SCALE - spec.sun) + 0.5)
    if room <= side or room > mapW / 3 then return side, side end
    if x <= 0 then return room, side end
    return side, room
end

-- EnhanceQoL's "Hide minimap moon" switch (MapNavigation_Camelot.lua) still hides it
local function EQoLHidesSun()
    local eqol = _G.EnhanceQoL
    local db = type(eqol) == "table" and eqol.db
    return type(db) == "table" and db.squareMinimapDialHidden == true
end

local placingSun = false
local function PlaceSun()
    local sun = Cluster.DielFrame
    if not sun or placingSun or (squareStyle and not MM.Frame) then return end
    placingSun = true
    local scale, point, relative, relativePoint, x, y = SunSpot()
    -- Blizzard's parent: a borrowed one carries someone else's scale and visibility
    if sun:GetParent() ~= Cluster.MinimapContainer then sun:SetParent(Cluster.MinimapContainer) end
    if squareStyle and not EQoLHidesSun() then sun:Show() end
    sun:SetScale(scale)
    sun:ClearAllPoints()
    sun:SetPoint(point, relative, relativePoint, x, y)
    if squareStyle then Raise(sun, 1) end
    placingSun = false
end

local function SunMoved(sun)
    if squareStyle and not MM.Frame then return false end
    local scale, point, relative, relativePoint, x, y = SunSpot()
    if sun:GetParent() ~= Cluster.MinimapContainer or sun:GetNumPoints() ~= 1
        or math.abs(sun:GetScale() - scale) > 0.001 then
        return true
    end
    local p, r, rp, px, py = sun:GetPoint(1)
    return p ~= point or r ~= relative or rp ~= relativePoint
        or math.abs((px or 0) - x) > 0.01 or math.abs((py or 0) - y) > 0.01
end

-- EnhanceQoL's "Minimap moon" places the badge on Minimap (top right by default, over the calendar)
-- and hooks its SetPoint / SetAllPoints to put it back there, so the two hooks would fight and
-- theirs would win. Every one of its paths (hooks, events, settings) calls
-- EnhanceQoL.functions.ApplySquareMinimapDial by name: that function now only shows or hides it.
local function SilenceEQoLMoon()
    local eqol = _G.EnhanceQoL
    local fns = type(eqol) == "table" and eqol.functions
    if type(fns) ~= "table" or type(fns.ApplySquareMinimapDial) ~= "function" or fns.FlareUI_MoonSilenced then return end
    fns.FlareUI_MoonSilenced = true
    fns.ApplySquareMinimapDial = function()
        local sun = Cluster.DielFrame
        if sun then sun:SetShown(not EQoLHidesSun()) end
    end
    PlaceSun()
end

-- Every way to place it puts it straight back, and a throttled safety check catches calls these hooks
-- never see (a method taken from the frame metatable, or a parent moved under it).
local function KeepSunPlaced()
    local sun = Cluster.DielFrame
    if not sun or MM.sunGuard then return end
    EventUtil.ContinueOnAddOnLoaded("EnhanceQoL", SilenceEQoLMoon)
    for _, method in ipairs({ "SetPoint", "SetAllPoints", "ClearAllPoints", "SetScale", "SetParent" }) do
        if sun[method] then hooksecurefunc(sun, method, PlaceSun) end
    end
    -- the Info Bar leaves room for the badge only while it shows (EnhanceQoL can hide it)
    if sun.HookScript then
        sun:HookScript("OnShow", function() MM.PlaceBar() end)
        sun:HookScript("OnHide", function() MM.PlaceBar() end)
    end
    -- The map's visibility also sleeps this guard; hooks still repair direct changes immediately.
    MM.sunGuard = CreateFrame("Frame", nil, MinimapFrame)
    MM.sunGuard.elapsed = 0
    MM.sunGuard:SetScript("OnShow", function(self) self.elapsed = 0; PlaceSun() end)
    MM.sunGuard:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed < 0.1 then return end
        self.elapsed = 0
        if not placingSun and SunMoved(sun) then PlaceSun() end
    end)
    PlaceSun()
end

--------------------------------------------------
-- 6b. MOVABLE EDGE ICONS
-- The icons on the map's edge: the sundial, the Group Finder Icon (MinimapEye.lua), the Vehicle Exit
-- Icon (MinimapVehicle.lua) and the Durability Warning (MinimapDurability.lua). Each one slides only
-- along the map's border, as LibDBIcon's buttons do: a moved one keeps an angle around the map's
-- centre (degrees, 0 = right, counter-clockwise) and sits on the border at that angle, on the circle
-- for the round map, on the square's edge for the square one (the angle's ray pushed out to the
-- edge, as EdgePoint does for addon buttons), as far from the edge as the icon sits by default.
-- An unmoved one keeps its stack spot (above the sundial up the square's left edge, up the circle's
-- lower left on the round map); a moved one leaves the stack and the ones still in it close up.
-- Gestures: outside Edit Mode, Shift+drag slides one along the edge, Ctrl+mouse wheel resizes it,
-- Shift+right-click puts it back in the stack, Ctrl+right-click gives back its size. In Edit Mode the
-- same with no keys (a right-click puts back both), and a faint blue glow shows what can be grabbed.
-- A handle lies over each icon only then, so their own clicks work otherwise; the drag follows the
-- cursor with an OnUpdate that runs only while it lasts.
-- Saved per profile as minimap.buttonMoves[key] = { angle =, scale = }. The sundial's spot is kept by
-- its lock (SunSpot, KeepSunPlaced): it reads the same spot, the drag's too, so other addons still
-- can't move it and the lock never fights the player's drag.
--------------------------------------------------
MM.Moves = {
    MIN = 0.5, MAX = 2, STEP = 0.1,                 -- sizes
    ORDER = { "sundial", "finder", "vehicle", "durability" },
    -- the icons' own buttons and modules
    FRAMES = { finder = "FlareUIFinderEye", vehicle = "FlareUIVehicleExit", durability = "FlareUIDurability" },
    MODULES = { finder = "MinimapEye", vehicle = "MinimapVehicle", durability = "MinimapDurability" },
    -- the sundial's default spot on the square map as an angle: the bottom-left corner (on the round
    -- map, Blizzard's own spot: SunSpot)
    SUN_SQUARE_ANGLE = 225,
    handles = {},                                   -- key -> handle
    hinted = {},                                    -- icon -> its tooltip hint is hooked
}
do
    local Moves = MM.Moves
    local DragStop

    -- the saved spot of a key, while it holds an angle or a size
    function Moves.Spot(key)
        local db = GetDb()
        local spot = db and type(db.buttonMoves) == "table" and db.buttonMoves[key]
        if type(spot) ~= "table" or not (type(spot.angle) == "number" or type(spot.scale) == "number") then return nil end
        return spot
    end

    -- the angle of a moved icon (the drag's while it is dragged), nil in the stack
    function Moves.Angle(key)
        if Moves.dragKey == key and Moves.dragAngle then return Moves.dragAngle end
        local spot = Moves.Spot(key)
        return spot and type(spot.angle) == "number" and spot.angle or nil
    end

    function Moves.Scale(key)
        local spot = Moves.Spot(key)
        local scale = spot and type(spot.scale) == "number" and spot.scale
        if not scale then return 1 end
        return math.max(Moves.MIN, math.min(Moves.MAX, scale))
    end

    -- an angle on a square's edge, reach from its centre to the edge line (as EdgePoint); reachY: a
    -- box taller or wider than square (a FlareUI border's), the square's point stretched to it, so the
    -- corners' angles still land on its corners
    function Moves.EdgeXY(angle, reach, reachY)
        local x, y = math.cos(math.rad(angle)), math.sin(math.rad(angle))
        local most = math.max(math.abs(x), math.abs(y))
        return x / most * reach, y / most * (reachY or reach)
    end

    -- the icon's button, nil when there is none (the sundial switched off is unseen, not hidden)
    function Moves.Frame(key)
        if key == "sundial" then
            local bag = ns.MinimapBag
            if bag and bag.SundialShown and not bag.SundialShown() then return nil end
            return Cluster.DielFrame
        end
        return _G[Moves.FRAMES[key]]
    end

    -- the frame whose centre the angle turns around: the one each icon is placed from
    function Moves.Centre(key)
        if squareStyle then return MM.Frame or MinimapFrame end
        if key == "sundial" then return Cluster.MinimapContainer end
        return MinimapFrame
    end

    -- the cursor's angle around that centre, in degrees
    function Moves.CursorAngle(key)
        local ref = Moves.Centre(key)
        local cx, cy = ref:GetCenter()
        if not (cx and cy) then return nil end
        local s = ref:GetEffectiveScale()
        local x, y = GetCursorPosition()
        return math.deg(math.atan2(y - cy * s, x - cx * s)) % 360
    end

    -- the Group Finder and Vehicle Exit icons are secure buttons: they can't move in a fight
    local function Blocked(frame)
        return frame ~= nil and InCombatLockdown() and frame:IsProtected()
    end

    -- one icon to its spot at once (the drag)
    function Moves.PlaceKey(key)
        if key == "sundial" then PlaceSun() return end
        local mod = ns[Moves.MODULES[key]]
        if mod and mod.PlaceNow then mod.PlaceNow() end
    end

    -- a spot changed: the map lays itself out again (the stack closes up), the badge goes to its spot
    -- (the round map's pass leaves it alone), and an open drawer follows the badge
    function Moves.Request()
        MM:Refresh()
        PlaceSun()
        local bag = ns.MinimapBag
        if bag and bag.Reanchor then bag.Reanchor() end
    end

    -- Settings > Minimap: every icon back in its stack spot, at its own size
    function MM.ResetButtonMoves()
        local db = GetDb()
        if db then db.buttonMoves = {} end
        Moves.Request()
    end

    local function Edit(key)
        local db = GetDb()
        if not db then return {} end
        if type(db.buttonMoves) ~= "table" then db.buttonMoves = {} end
        if type(db.buttonMoves[key]) ~= "table" then db.buttonMoves[key] = {} end
        return db.buttonMoves[key]
    end

    local function Prune(key)
        local db = GetDb()
        local spot = db and type(db.buttonMoves) == "table" and db.buttonMoves[key]
        if type(spot) == "table" and not (spot.angle or spot.scale) then db.buttonMoves[key] = nil end
    end

    -- the old free-form spots (x / y, and the header's buttons) go, once per load
    function Moves.Cleanup()
        local db = GetDb()
        if not db then return end
        if type(db.buttonMoves) ~= "table" then db.buttonMoves = {} return end
        for key, spot in pairs(db.buttonMoves) do
            if type(spot) ~= "table" or not (key == "sundial" or Moves.FRAMES[key]) then
                db.buttonMoves[key] = nil
            else
                spot.x, spot.y = nil, nil
                if type(spot.angle) ~= "number" then spot.angle = nil end
                if type(spot.scale) ~= "number" then spot.scale = nil end
                if not (spot.angle or spot.scale) then db.buttonMoves[key] = nil end
            end
        end
    end

    -- while dragging: the icon follows the cursor's angle around the map's centre
    local function Follow()
        local key = Moves.dragKey
        local frame = key and Moves.Frame(key)
        if not frame or Blocked(frame) or MM.MapAway() then DragStop() return end
        local angle = Moves.CursorAngle(key)
        if angle and angle ~= Moves.dragAngle then
            Moves.dragAngle = angle
            Moves.PlaceKey(key)
            -- the Info Bar makes or gives up room for the sundial as it slides past the bar's ends
            if key == "sundial" and Bar.shown and Bar.sunShown then
                local left, right = Bar.SunRoom(Bar.side)
                if left ~= Bar.sunLeft or right ~= Bar.sunRight then MM.PlaceBar() end
            end
        end
    end

    local function DragStart(handle)
        local key = handle.key
        local frame = Moves.Frame(key)
        if not frame or not (IsShiftKeyDown() or Moves.editing) or Moves.dragKey or Blocked(frame) or MM.MapAway() then return end
        local angle = Moves.CursorAngle(key)
        if not angle then return end
        GameTooltip:Hide()
        Moves.dragKey, Moves.dragAngle = key, angle
        -- dropped on any mouse-up: OnDragStop may never come (the cursor leaving the game window)
        Moves.watch:RegisterEvent("GLOBAL_MOUSE_UP")
        Moves.mover:SetScript("OnUpdate", Follow)
        -- out of the stack at once: the others close up
        Moves.Request()
    end

    DragStop = function()
        local key, angle = Moves.dragKey, Moves.dragAngle
        if not key then return end
        Moves.watch:UnregisterEvent("GLOBAL_MOUSE_UP")
        Moves.mover:SetScript("OnUpdate", nil)
        Moves.dragKey, Moves.dragAngle = nil, nil
        if angle then Edit(key).angle = math.floor(angle * 10 + 0.5) / 10 % 360 end
        Moves.Request()
        Moves.UpdateHandles()
    end

    local function Wheel(handle, delta)
        if not (IsControlKeyDown() or Moves.editing) or Moves.dragKey then return end
        local frame = Moves.Frame(handle.key)
        if not frame or Blocked(frame) then return end
        local spot = Edit(handle.key)
        local scale = (spot.scale or 1) + Moves.STEP * delta
        scale = math.max(Moves.MIN, math.min(Moves.MAX, math.floor(scale * 100 + 0.5) / 100))
        spot.scale = math.abs(scale - 1) > 0.001 and scale or nil
        Prune(handle.key)
        Moves.Request()
    end

    local function MouseUp(handle, button)
        if button ~= "RightButton" or Moves.dragKey then return end
        if Blocked(Moves.Frame(handle.key)) then return end
        local spot = Moves.Spot(handle.key)
        if not spot then return end
        local shift, ctrl = IsShiftKeyDown(), IsControlKeyDown()
        -- in Edit Mode a plain right-click puts back both
        if shift or (Moves.editing and not ctrl) then spot.angle = nil end
        if ctrl or (Moves.editing and not shift) then spot.scale = nil end
        Prune(handle.key)
        Moves.Request()
    end

    -- the handle's tip (Shift or Ctrl held, or Edit Mode): one line, how to put it back
    local function ShowTip(handle)
        ns.OwnGameTooltip(handle, "ANCHOR_LEFT")
        GameTooltip:AddLine(Moves.editing and L["Drag to move, wheel to resize, right-click to reset"]
            or L["Right-click with Shift or Ctrl to reset"], 1, 1, 1)
        GameTooltip:Show()
    end

    -- the icon's own tooltip ends with one grey line saying it can be moved (an icon with no tooltip
    -- of its own gets just that line)
    function Moves.AddHint(frame)
        if not frame or Moves.hinted[frame] or not frame.HookScript then return end
        Moves.hinted[frame] = true
        frame:HookScript("OnEnter", function(self)
            if Moves.editing or IsShiftKeyDown() or IsControlKeyDown() then return end
            if GameTooltip:GetOwner() ~= self or not GameTooltip:IsShown() then ns.OwnGameTooltip(self, "ANCHOR_LEFT") end
            GameTooltip:AddLine(L["Shift+drag to move, Ctrl+wheel to resize"], 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        if not frame:GetScript("OnLeave") then frame:HookScript("OnLeave", GameTooltip_Hide) end
    end

    -- one handle per icon, a child of its button (so it moves, scales and hides with it), over its face
    local function Handle(key, frame)
        local handle = Moves.handles[key]
        if handle and handle.owner == frame then return handle end
        if handle then handle:Hide() end
        handle = CreateFrame("Frame", nil, frame)
        handle.key, handle.owner = key, frame
        handle:SetAllPoints(frame)
        -- Edit Mode shows what can be grabbed, in its selection blue
        handle.Glow = handle:CreateTexture(nil, "OVERLAY")
        handle.Glow:SetAllPoints()
        handle.Glow:SetColorTexture(0.25, 0.6, 1, 0.3)
        handle.Glow:Hide()
        handle:EnableMouse(true)
        handle:RegisterForDrag("LeftButton")
        handle:SetScript("OnDragStart", DragStart)
        handle:SetScript("OnDragStop", function() DragStop() end)
        handle:SetScript("OnMouseUp", MouseUp)
        handle:SetScript("OnMouseWheel", Wheel)
        handle:SetScript("OnEnter", ShowTip)
        handle:SetScript("OnLeave", GameTooltip_Hide)
        handle:Hide()
        Moves.handles[key] = handle
        return handle
    end

    -- the handles while Shift or Ctrl is held or Edit Mode is open (the secure icons' not in a fight);
    -- the wheel only with Ctrl or in Edit Mode, so a plain wheel still zooms the map. A handle shows
    -- only while its icon does: the icons that come and go show in Edit Mode for placing.
    function Moves.UpdateHandles()
        if not MM.initialized or Moves.dragKey then return end
        local editing = Moves.editing
        local ctrl = IsControlKeyDown() or editing
        local on = IsShiftKeyDown() or ctrl
        for _, key in ipairs(Moves.ORDER) do
            Moves.AddHint(Moves.Frame(key))
            local frame = on and Moves.Frame(key)
            if frame and Blocked(frame) then frame = nil end
            local handle = Moves.handles[key]
            if frame then
                handle = Handle(key, frame)
                -- above the icon's own children (the badge's click area); in Edit Mode above the
                -- minimap's own selection box
                handle:SetFrameStrata(editing and "DIALOG" or frame:GetFrameStrata())
                handle:SetFrameLevel(frame:GetFrameLevel() + 20)
                handle:EnableMouseWheel(ctrl)
                -- (hidden with the selection boxes by Edit Mode's eye button)
                local boxesOff = ns.db and ns.db.profile and ns.db.profile.editModeOverlaysHidden
                handle.Glow:SetShown((editing and not boxesOff) and true or false)
                handle:Show()
            elseif handle then
                handle:Hide()
            end
        end
    end

    -- from MM:Init, after the icons' own modules
    function Moves.Init()
        if Moves.watch then return end
        Moves.Cleanup()
        Moves.mover = CreateFrame("Frame")
        Moves.watch = CreateFrame("Frame")
        Moves.watch:RegisterEvent("MODIFIER_STATE_CHANGED")
        Moves.watch:RegisterEvent("PLAYER_REGEN_DISABLED")
        Moves.watch:RegisterEvent("PLAYER_REGEN_ENABLED")
        Moves.watch:SetScript("OnEvent", function(_, event)
            if event == "GLOBAL_MOUSE_UP" then DragStop() else Moves.UpdateHandles() end
        end)
        LEM:RegisterCallback("enter", function() Moves.editing = true; Moves.UpdateHandles() end)
        LEM:RegisterCallback("exit", function()
            Moves.editing = false
            DragStop()
            GameTooltip_Hide()
            Moves.UpdateHandles()
        end)
        -- the icons' tooltip hints, once they exist
        C_Timer.After(1, Moves.UpdateHandles)
    end
end

--------------------------------------------------
-- 7. LAYOUT
--------------------------------------------------
-- The cluster fits the map plus the frame art; Edit Mode's Size scales the whole of it
local sizingCluster = false
local function SizeCluster()
    if sizingCluster then return end
    sizingCluster = true
    local size = MAP_SIZE + 2 * FRAME_PAD
    Cluster:SetSize(size, size)
    sizingCluster = false
end

-- Edit Mode's Size setting as a scale; 1 until Edit Mode has it
local function EditModeSize()
    if not (Cluster.HasSetting and Cluster.GetSettingValue) then return 1 end
    local ok, has = pcall(Cluster.HasSetting, Cluster, Enum.EditModeMinimapSetting.Size)
    if not (ok and has) then return 1 end
    local ok2, value = pcall(Cluster.GetSettingValue, Cluster, Enum.EditModeMinimapSetting.Size)
    if not (ok2 and type(value) == "number" and value > 0) then return 1 end
    return value / 100
end

function MM:UpdateLayout()
    if not self.initialized or MM.MapAway() then return end   -- (a HUD has the map: WatchMapHome)
    -- (the minimap and its cluster are not protected on Forever: this runs in a fight too)
    if not squareStyle then
        StyleCoords()
        Bar.Update()   -- the Info Bar under the round map
        return
    end
    -- a gathering addon's secure button on the map (Gathercraft) makes it protected: after the fight
    if InCombatLockdown() and MinimapFrame:IsProtected() then
        if not self.layoutWaiter then
            self.layoutWaiter = CreateFrame("Frame")
            self.layoutWaiter:SetScript("OnEvent", function(waiter)
                waiter:UnregisterEvent("PLAYER_REGEN_ENABLED")
                self:UpdateLayout()
            end)
        end
        self.layoutWaiter:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    Cluster.MinimapContainer:SetScale(1)
    Cluster.ZoneTextButton:SetScale(1)
    SizeCluster()
    local scale = EditModeSize()
    if math.abs(Cluster:GetScale() - scale) > 0.001 then ns.SetSystemScale(Cluster, scale) end

    -- the map frame, terrain and backing in the border in use (a FlareUI border grows them); a node
    -- addon's scan keeps its offset, so the move it takes back at the end lands home
    local oldSide = MinimapFrame:GetWidth()
    local side = MM.FitArt(MM.Frame, Cluster, MinimapFrame, MM.Back, Scan.x, Scan.y)
    -- the game keeps drawing the map at its old size until its zoom changes: one step and back after a
    -- resize (not mid-scan, where a zoom would end it: once the map is home)
    if math.abs((oldSide or 0) - side) > 0.5 then
        local function Redraw()
            local zoom, levels = MinimapFrame:GetZoom(), MinimapFrame:GetZoomLevels() or 6
            MinimapFrame:SetZoom(zoom + 1 < levels and zoom + 1 or zoom - 1)
            MinimapFrame:SetZoom(zoom)
        end
        if Scan.Busy() then Scan.Later("redraw", Redraw) else Redraw() end
    end
    -- and its empty mask (the map hidden under the cursor) stays until it is home
    if Scan.Busy() then Scan.Later("mask", ApplySquareMap) else ApplySquareMap() end

    -- the Header style (Headerless / Bordered) can change at any time
    if MM.Border and MM.BorderAbove then ApplyBorder(MM.Border, MM.BorderAbove) end
    PlaceHeader()
    PlaceIndicators()
    PlaceSun()
    Bar.Update()
    PlaceCoords()
end

--------------------------------------------------
-- 8. EDIT MODE
-- "Rotate Minimap" and "Header Underneath" leave the minimap's dialog and Size reads "Scale". Done on
-- the dialog's own rows after Blizzard builds them, never in Blizzard's table they are built from
-- (addon-written entries there would taint Edit Mode). Stored values are harmless: the layout is
-- re-applied after Blizzard's.
--------------------------------------------------
local function TrimMinimapDialog(dialog)
    local system = dialog and dialog.attachedToSystem
    if not (system and system.system == Enum.EditModeSystem.Minimap and dialog.Settings) then return end
    local hidden = {
        [Enum.EditModeMinimapSetting.RotateMinimap] = true,
        [Enum.EditModeMinimapSetting.HeaderUnderneath] = true,
    }
    local changed = false
    for _, row in ipairs({ dialog.Settings:GetChildren() }) do
        if row:IsShown() and row.setting then
            if hidden[row.setting] then
                row:Hide()
                changed = true
            elseif row.setting == Enum.EditModeMinimapSetting.Size and row.Label then
                -- Blizzard's Size scales the whole minimap
                row.Label:SetText(L["Scale"])
            end
        end
    end
    if changed then
        dialog.Settings:Layout()
        if dialog.Layout then dialog:Layout() end
    end
end

local function RemoveEditModeSettings()
    local dialog = _G.EditModeSystemSettingsDialog
    if not dialog then
        if EventUtil and EventUtil.ContinueOnAddOnLoaded then EventUtil.ContinueOnAddOnLoaded("Blizzard_EditMode", RemoveEditModeSettings) end
        return
    end
    if dialog.FlareUI_MinimapTrim then return end
    dialog.FlareUI_MinimapTrim = true
    hooksecurefunc(dialog, "UpdateSettings", TrimMinimapDialog)
end

--------------------------------------------------
-- 8b. MOUSE: WHOLE SQUARE, MIDDLE-CLICK MENU, COORDINATES ON HOVER
--------------------------------------------------
-- Pointing at the map (or anything on it) shows the coordinates with Coordinates on Hover; a light
-- check while the pointer is around, stopped once it has left the cluster
local hoverTicker
local function CoordsFrame() return Cluster.MinimapContainer and Cluster.MinimapContainer.PlayerCoords end

local function ShowCoords(shown)
    local coords = CoordsFrame()
    if coords then coords:SetAlpha(shown and 1 or 0) end
end

-- The map's own coordinates text stays hidden: coordinates are an Info Bar cell. Blizzard's own
-- option (minimapShowPlayerCoords) is left alone.

-- Info Bar On Mouseover (minimap.infoBarHover, off): the bar shows only while you point at the map
function MM.BarHover()
    local db = GetDb()
    return db and db.infoBarHover == true and Bar.shown or false
end

-- what pointing at the map shows: the Info Bar on mouseover (the coordinates text: never)
local function HoverWanted()
    return GetDb() and MM.BarHover() or false
end
local function ShowHovered(over)
    ShowCoords(false)
    if Bar.frame then Bar.frame:SetAlpha((not MM.BarHover() or over) and 1 or 0) end
end

local function UpdateCoordsHover()
    if not HoverWanted() then
        if hoverTicker then hoverTicker:Cancel(); hoverTicker = nil end
        ShowHovered(true)
        return
    end
    -- mid-scan the coordinates are the scan's to hide (Lueur puts back what it found at the end)
    if Scan.Busy() then return end
    local over = Cluster:IsMouseOver()
    ShowHovered(over)
    if not over and hoverTicker then hoverTicker:Cancel(); hoverTicker = nil end
end

local function OnMapEnter()
    if not HoverWanted() then return end
    -- the hidden map slid under the pointer by a node addon's scan is not the player pointing at it
    if Scan.Busy() or not Cluster:IsMouseOver() then return end
    ShowHovered(true)
    if not hoverTicker then hoverTicker = C_Timer.NewTicker(0.2, UpdateCoordsHover) end
end

-- Middle-click Menu: Blizzard's panels as secure buttons, each a macro clicking the micro button (a
-- panel opened from addon code would taint its frames). Out of combat only: the list holds protected
-- buttons.
local menu
local MENU_KEYS = { "character", "spellbook", "talents", "professions", "quests", "groupfinder", "guild",
    "collections", "social", "legacy", "flareui" }
local MENU_ROW, MENU_PAD = 22, 8

local function HideMenu()
    if menu and menu:IsShown() and not InCombatLockdown() then menu:Hide() end
end

-- The menu's look and rows on any BackdropTemplate frame: secure rows for the real menu, plain ones
-- (labels and icons only) for the settings preview's sample. Sizes the frame; false without panels.
function MM.FillMenu(f, secure)
    local panels = ns.RadialMenu and ns.RadialMenu.MICRO_PANELS
    if not panels then return false end
    local LSM = LibStub("LibSharedMedia-3.0")
    local file = LSM:Fetch("border", "FlareUI Frames")
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = file, edgeSize = ns.BorderEdgeSize(file, 16),
        insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    f:SetBackdropColor(0, 0, 0, 0.9)
    f:SetBackdropBorderColor(ns.BORDER_COLOR.r, ns.BORDER_COLOR.g, ns.BORDER_COLOR.b, 1)
    local width, n = 0, 0
    for _, key in ipairs(MENU_KEYS) do
        local p = panels[key]
        local usable = p and ((p.button and _G[p.button]) or p.macrotext)
        if usable then
            n = n + 1
            local b = CreateFrame("Button", nil, f, secure and "SecureActionButtonTemplate" or nil)
            b:SetHeight(MENU_ROW)
            b:SetPoint("TOPLEFT", f, "TOPLEFT", MENU_PAD, -MENU_PAD - (n - 1) * MENU_ROW)
            b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -MENU_PAD, -MENU_PAD - (n - 1) * MENU_ROW)
            local icon = b:CreateTexture(nil, "ARTWORK")
            icon:SetSize(16, 16)
            icon:SetPoint("LEFT", 2, 0)
            icon:SetTexture(p.icon or 134400)
            local text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            text:SetPoint("LEFT", icon, "RIGHT", 6, 0)
            text:SetText(p.label)
            width = math.max(width, text:GetStringWidth() + 28)
            if secure then
                b:RegisterForClicks("AnyUp", "AnyDown")
                b:SetAttribute("type", "macro")
                b:SetAttribute("macrotext", (p.button and _G[p.button]) and ("/click " .. p.button) or p.macrotext)
                local hl = b:CreateTexture(nil, "HIGHLIGHT")
                hl:SetAllPoints()
                hl:SetColorTexture(1, 1, 1, 0.08)
                b:HookScript("PostClick", function() C_Timer.After(0, HideMenu) end)
            else
                b:EnableMouse(false)
            end
        end
    end
    f:SetSize(width + 2 * MENU_PAD, n * MENU_ROW + 2 * MENU_PAD)
    return true
end

local function BuildMenu()
    if not (ns.RadialMenu and ns.RadialMenu.MICRO_PANELS) then return nil end
    local f = CreateFrame("Frame", "FlareUI_MinimapMenu", UIParent, "BackdropTemplate")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    MM.FillMenu(f, true)
    f:Hide()
    table.insert(UISpecialFrames, "FlareUI_MinimapMenu")   -- Escape closes it
    -- a click elsewhere or a fight closes it (the fight first: lockdown begins after this event)
    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    -- clicks are watched only while the menu is open
    f:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
    f:SetScript("OnHide", function(self) self:UnregisterEvent("GLOBAL_MOUSE_DOWN") end)
    f:SetScript("OnEvent", function(self, event)
        if event == "GLOBAL_MOUSE_DOWN" and self:IsMouseOver() then return end
        HideMenu()
    end)
    return f
end

local function ToggleMenu()
    local db = GetDb()
    if not (db and db.microMenu) then return end
    if InCombatLockdown() then
        if UIErrorsFrame then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT or "Can't do that in combat", 1, 0.25, 0.25) end
        return
    end
    menu = menu or BuildMenu()
    if not menu then return end
    if menu:IsShown() then menu:Hide() return end
    local x, y = GetCursorPosition()
    local scale = menu:GetEffectiveScale()
    menu:ClearAllPoints()
    menu:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    menu:Show()
end

-- Clicks on the map. A surface of FlareUI's own lies over the map and takes its clicks, so Blizzard's
-- click handler is never replaced, wrapped or hooked:
-- * outside battlegrounds it does what FlareUI always did: the middle button opens the menu (no ping),
--   any other button pings (the square style's corners too; the round map only inside its circle, as
--   Blizzard's own), and the square style zooms with the wheel.
-- * in a battleground it lets every click through (Minimap:PingLocation is protected there:
--   ADDON_ACTION_BLOCKED): Blizzard's untouched map pings, and the square's corners don't ping. The
--   wheel still zooms.
local surface
local function InBattleground()
    local inInstance, kind = IsInInstance()
    return inInstance and kind == "pvp" or false
end

-- (EnableMouse on FlareUI's own plain frame: allowed in a fight too)
-- The surface sits well above the map (at the map's own level the map takes the clicks first) and
-- lets through, to Blizzard's untouched map, every button it doesn't use:
-- * the middle button is the menu's while it's on (in a battleground too: no ping is involved);
-- * the square style takes the left and right buttons outside battlegrounds to ping its corners;
--   the round map and battlegrounds leave them to Blizzard.
-- (SetPassThroughButtons can't change in a fight: the last setting stays until it ends.)
function MM.UpdateMapMouse()
    if not surface then return end
    local db = GetDb()
    local menuOn = db and db.microMenu and true or false
    local ownPings = squareStyle and not InBattleground()
    surface:EnableMouse(menuOn or ownPings)
    if surface.SetPassThroughButtons and not InCombatLockdown() then
        local through = { "Button4", "Button5" }
        if not ownPings then through[#through + 1] = "LeftButton"; through[#through + 1] = "RightButton" end
        if not menuOn then through[#through + 1] = "MiddleButton" end
        surface:SetPassThroughButtons(unpack(through))
    end
end

local function Ping()
    local x, y = GetCursorPosition()
    local scale = MinimapFrame:GetEffectiveScale()
    local cx, cy = MinimapFrame:GetCenter()
    if not cx then return end
    x, y = x / scale - cx, y / scale - cy
    -- the round map: inside its circle only, as Blizzard's own click
    if not squareStyle and math.sqrt(x * x + y * y) >= MinimapFrame:GetWidth() / 2 then return end
    pcall(MinimapFrame.PingLocation, MinimapFrame, x, y)
end

local function CreateMapSurface()
    surface = CreateFrame("Frame", nil, MinimapFrame)
    surface:SetAllPoints(MinimapFrame)
    surface:SetFrameLevel(MinimapFrame:GetFrameLevel() + 10)   -- above the map, which would take the clicks first
    -- clicks and the wheel only: the pointer's hover stays the map's own, as the game's dot tooltip
    -- and node addons (Gathercraft reads the mouse focus) need
    if surface.SetMouseMotionEnabled then surface:SetMouseMotionEnabled(false) end
    if surface.SetPropagateMouseMotion then surface:SetPropagateMouseMotion(true) end
    if squareStyle then
        surface:EnableMouseWheel(true)
        -- a node addon's scan holds the hidden map under the pointer: the wheel goes to the camera
        Scan.OnChange = function(busy) surface:EnableMouseWheel(not busy) end
        surface:SetScript("OnMouseWheel", function(_, delta)
            if delta > 0 then Minimap_ZoomIn() elseif delta < 0 then Minimap_ZoomOut() end
        end)
    end
    surface:SetScript("OnMouseUp", function(_, button)
        local db = GetDb()
        if button == "MiddleButton" then
            if db and db.microMenu then ToggleMenu() end
            return
        end
        if squareStyle and not InBattleground() then Ping() end
    end)
    MM.UpdateMapMouse()
    -- a battleground's start or end
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", MM.UpdateMapMouse)
end

local function SetupMapMouse()
    CreateMapSurface()
    MinimapFrame:HookScript("OnEnter", OnMapEnter)
    Cluster:HookScript("OnEnter", OnMapEnter)
    UpdateCoordsHover()
end

local function AddEditModeSettings()
    local rows = ns.Visibility and ns.Visibility:MinimapSettings() or {}
    LEM:AddSystemSettings(Enum.EditModeSystem.Minimap, rows)
end

-- The square map can't rotate: rotateMinimap goes off at load and whenever a layout sets it
local function KeepMapUnrotated()
    if MM.MapAway() then return end   -- (a HUD that has the map may rotate it)
    if GetCVarBool("rotateMinimap") then SetCVar("rotateMinimap", "0") end
end

--------------------------------------------------
-- 9. HOOKS
--------------------------------------------------
local zoomTimer
local function OnZoom(_, level)
    if zoomTimer then zoomTimer:Cancel() zoomTimer = nil end
    local db = GetDb()
    local delay = db and db.autoZoom or 0
    if level ~= 0 and delay > 0 then
        -- not in the middle of a node addon's scan (a new zoom would end it): once the map is home
        zoomTimer = C_Timer.NewTimer(delay, function()
            if Scan.Busy() then Scan.Later("zoom", function() MinimapFrame:SetZoom(0) end) else MinimapFrame:SetZoom(0) end
        end)
    end
end

-- The mask the map should have: empty while faded out, else square, else (round style) the last one
-- Forever set
local maskGuard = false
local function WantedMask()
    if MM.mapFaded then return MASKS.EMPTY end
    if squareStyle then return MM.SquareMask() end
    return MM.roundMask or MASKS.FOREVER
end
local function SetMask()
    maskGuard = true
    MinimapFrame:SetMaskTexture(WantedMask())
    maskGuard = false
end

-- Forever's skin puts its round mask back each time rotateMinimap changes: the square (or the empty
-- mask of a faded-out map) goes back on. A node addon's scan sets its empty one past this hook.
-- While a scan has the map away from home, it stays empty whoever shows it: a drawn map there chases
-- the cursor. Set through the frame's own method, past every hook (as the scans do), so no addon
-- takes the empty mask for the one to put back.
local function HideMapDirect()
    local meta = getmetatable(MinimapFrame)
    local set = type(meta) == "table" and type(meta.__index) == "table" and meta.__index.SetMaskTexture
    if type(set) ~= "function" then return end
    maskGuard = true
    pcall(set, MinimapFrame, MASKS.EMPTY)
    maskGuard = false
    Scan.hidden = true
end
Scan.OnAway = function() if not Scan.hidden then HideMapDirect() end end
-- A scan over: the wanted mask goes back on, whatever the scan put back (Lueur restores the last one
-- it saw set, which can be stale)
-- The game draws the blips (player arrow, quest marks, party dots, gathering nodes) at
-- full strength whatever the map's alpha. While the map is faded at all they are scaled to nothing
-- (Minimap:SetIconScale, as the node scanners do; nothing of Blizzard's sets it, so 1 is its own size),
-- and full size again once it shows fully. Through the frame's own method, and again after a scan (the
-- scanners put their own scale back at the end).
-- 0, so nothing is left: at 0.001 the player arrow still draws a one-pixel dot in the middle. If the
-- client refuses 0, the smallest size it takes.
MM.ICONS_FADED = { 0, 0.001 }
local function SetIcons()
    local meta = getmetatable(MinimapFrame)
    local set = meta and meta.__index and meta.__index.SetIconScale or MinimapFrame.SetIconScale
    if not set then return end
    if not MM.iconsFaded then pcall(set, MinimapFrame, 1) return end
    for _, scale in ipairs(MM.ICONS_FADED) do
        if pcall(set, MinimapFrame, scale) then return end
    end
end
function MM:SetIconsFaded(faded)
    if not self.initialized then return end
    faded = faded and true or false
    if (self.iconsFaded or false) == faded then return end
    self.iconsFaded = faded
    if Scan.Busy() then Scan.Later("icons", SetIcons) else SetIcons() end
end

Scan.OnEnd = function()
    SetMask()
    if MM.iconsFaded then SetIcons() end
end

local function KeepMask(_, texture)
    if texture ~= MASKS.EMPTY then Scan.hidden = false end
    if MM.MapAway() then return end   -- (a HUD has the map: its mask is its own)
    if maskGuard then return end
    if texture ~= MASKS.EMPTY and Scan.Away() then HideMapDirect() return end
    -- (a mask set mid-scan, another addon's empty one maybe, is not the round one to keep)
    if Scan.Busy() then return end   -- Scan.OnEnd puts the wanted one back
    if not squareStyle and texture ~= MASKS.EMPTY and texture ~= nil then MM.roundMask = texture end
    if (squareStyle or MM.mapFaded) and texture ~= WantedMask() then SetMask() end
end
local function WatchMask()
    if MM.maskWatched then return end
    MM.maskWatched = true
    hooksecurefunc(MinimapFrame, "SetMaskTexture", KeepMask)
end

-- Minimap fading (Visibility.lua): faded right out, the map is masked empty rather than hidden, so
-- node addons keep scanning it (they stop on a hidden map). Not mid-scan: once the map is home.
function MM:SetMapFaded(faded)
    if not self.initialized then return false end
    if InCombatLockdown() and MinimapFrame:IsProtected() then return true end
    if (self.mapFaded or false) == faded then return true end
    self.mapFaded = faded
    if Scan.Busy() then Scan.Later("fade", SetMask) else SetMask() end
    return true
end

-- First thing in Init: a failure anywhere later must not leave the round map inside the square frame
local function KeepMapSquare()
    ApplySquareMap()
    WatchMask()
    if not _G.HybridMinimap then
        EventUtil.ContinueOnAddOnLoaded("Blizzard_HybridMinimap", SquareHybridMinimap)
    end
end

local function InstallSquareHooks()
    hooksecurefunc(Cluster, "SetSize", SizeCluster)
    hooksecurefunc(Cluster, "SetHeaderUnderneath", function() MM:UpdateLayout() end)
    -- Forever's config pass (rotateMinimap, layout) drops the zone button to its own frame level
    -- (ForeverFarmHUD: putting rotateMinimap back runs it as the HUD lets go); it also sizes the
    -- map's container to the round art and sets the round mask: the whole square layout goes back on,
    -- once, on the next frame
    if Cluster.UpdateMinimapConfig then
        local configPending = false
        hooksecurefunc(Cluster, "UpdateMinimapConfig", function()
            PlaceZone()
            if configPending then return end
            configPending = true
            C_Timer.After(0, function()
                configPending = false
                if not MM.MapAway() then MM:Refresh() end
            end)
        end)
    end
    hooksecurefunc("MiniMapIndicatorFrame_UpdatePosition", PlaceIndicators)
end

-- Square style: addon buttons on the map. They are the map's children at its level + 1 unless they
-- set their own (LibDBIcon's sit in MEDIUM), so the square border, two above the map, drew over the
-- ones on its edge. Any Button child of the map at or under the border goes one above it; the border
-- keeps its level over the map. Addons add buttons whenever they like: checked again whenever the map
-- has a new child (a light 2-second count), and after loading screens. Buttons on MinimapBackdrop and
-- every LibDBIcon button count too, whatever their parent, and one an addon later sets back under the
-- border (its own level or strata) is lifted again a frame later. Hidden buttons are lifted and watched
-- too, so one an addon shows later doesn't stay under the border.
local STRATA_RANK = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6,
    FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
local liftHooked = setmetatable({}, { __mode = "k" })
-- Map pins are left alone: gathering and quest addons (HereBeDragons) put hundreds or thousands of
-- pins on the map and show / hide them every frame while you move, so hooking and re-levelling each
-- one costs a full pass per show. The map draws its children with itself anyway (see LiftMapButtons),
-- so lifting them would do nothing.
MM.PIN_LIBS = { "HereBeDragons-Pins-2.0", "HereBeDragons-Pins-1.0" }
-- the pin libraries' lookup tables, read once per pass rather than once per child
function MM.PinSets()
    local sets = {}
    for i = 1, #MM.PIN_LIBS do
        local pins = LibStub and LibStub(MM.PIN_LIBS[i], true)
        if pins then
            if pins.minimapPins then sets[#sets + 1] = pins.minimapPins end
            if pins.activeMinimapPins then sets[#sets + 1] = pins.activeMinimapPins end
        end
    end
    return sets
end
function MM.IsMapPin(frame, sets)
    sets = sets or MM.PinSets()
    for i = 1, #sets do
        if sets[i][frame] then return true end
    end
    return false
end
local function LiftButton(child, strata, want, sets)
    if MM.IsMapPin(child, sets) then return end
    if not (child and child.IsObjectType and child:IsObjectType("Button")) or (child.IsForbidden and child:IsForbidden())
            or (InCombatLockdown() and child:IsProtected()) then
        return
    end
    if not liftHooked[child] then
        liftHooked[child] = true
        hooksecurefunc(child, "SetFrameLevel", MM.LiftSoon)
        hooksecurefunc(child, "SetFrameStrata", MM.LiftSoon)
        child:HookScript("OnShow", MM.LiftSoon)
    end
    local mine = child:GetFrameStrata()
    local below = (STRATA_RANK[mine] or 0) < (STRATA_RANK[strata] or 0)
    if below then child:SetFrameStrata(strata) end
    if (below or mine == strata) and child:GetFrameLevel() <= want then child:SetFrameLevel(want + 1) end
end

local lifting = false

-- A HUD (GatherLite's, FarmHud) takes the map, re-parents and re-levels it and every child, and moves
-- hundreds of gathering pins: one pass waits at most, and nothing here touches the map while it is
-- away from its home (MM.MapAway); it is all put back once when the map comes home (WatchMapHome).
local liftPending, placePending = false, false
function MM.LiftSoon()
    -- (a pass's own re-layering fires the hooks: no second pass for frames it just handled)
    if liftPending or lifting then return end
    liftPending = true
    C_Timer.After(0, function() liftPending = false; MM.LiftMapButtons() end)
end
function MM.PlaceSoon()
    if placePending then return end
    placePending = true
    C_Timer.After(0, function() placePending = false; MM.PlaceAllButtons() end)
end
function MM.MapAway()
    return MM.mapHome ~= nil and MinimapFrame:GetParent() ~= MM.mapHome
end

-- a LibDBIcon button on the map: still the map's child, or moved to the button holder (below)
function MM.OnMap(button)
    local parent = button and button:GetParent()
    return parent ~= nil and (parent == MinimapFrame or parent == MM.ButtonHolder)
end
function MM.LiftMapButtons()
    local art = MM.Frame
    if not art or lifting or MM.MapAway() then return end
    lifting = true
    local want = MinimapFrame:GetFrameLevel() + 2
    if art:GetFrameLevel() ~= want then art:SetFrameLevel(want) end
    local strata = art:GetFrameStrata()
    local sets = MM.PinSets()
    for _, parent in ipairs({ MinimapFrame, _G.MinimapBackdrop }) do
        for _, child in ipairs(parent and { parent:GetChildren() } or {}) do LiftButton(child, strata, want, sets) end
    end
    -- LibDBIcon's buttons, and other addons' map buttons, left out of the drawer go a whole strata above the border: one
    -- level above it still leaves them under its edge. Other map buttons (gathering pins) stay in the
    -- border's strata, under the world map. The map draws its children with itself, whatever their
    -- strata, so a border over the map would cover them all: those buttons hang on MM.ButtonHolder,
    -- above the border, still anchored to the map where LibDBIcon puts them.
    local lib = LibStub and LibStub("LibDBIcon-1.0", true)
    if lib and lib.GetButtonList then
        local above = strata
        for name, rank in pairs(STRATA_RANK) do
            if rank == (STRATA_RANK[strata] or 0) + 1 then above = name end
        end
        for _, name in ipairs(lib:GetButtonList() or {}) do
            local button = lib:GetMinimapButton(name)
            -- (one in the addon drawer is parked off the map)
            if button and MM.OnMap(button) then
                local holder = MM.ButtonHolder
                if holder and button:GetParent() ~= holder then button:SetParent(holder) end
                LiftButton(button, above, want, sets)
            end
        end
    end
    -- other addons' own buttons left on the map (not in the drawer): the same, on the holder. Their
    -- anchors to the map stay; one that runs its own round drag keeps it (it ignores the map's shape).
    local holder, Bag = MM.ButtonHolder, ns.MinimapBag
    if holder and Bag and Bag.ForeignButtons then
        local above = strata
        for name, rank in pairs(STRATA_RANK) do
            if rank == (STRATA_RANK[strata] or 0) + 1 then above = name end
        end
        for _, button in ipairs(Bag.ForeignButtons(MinimapFrame, sets)) do
            if button:IsShown() and not (InCombatLockdown() and button:IsProtected()) then
                if button.HasFixedFrameStrata and button:HasFixedFrameStrata() then button:SetFixedFrameStrata(false) end
                if button.HasFixedFrameLevel and button:HasFixedFrameLevel() then button:SetFixedFrameLevel(false) end
                button:SetParent(holder)
            end
        end
        for _, button in ipairs({ holder:GetChildren() }) do LiftButton(button, above, want, sets) end
    end
    lifting = false
end

-- /fui mapdebug: the border's layer, then every button on the map, its backdrop and the cluster, with
-- where it sits, so a report says why one is under the border
function MM.DebugLayers()
    local function Line(label, f)
        if not f then return end
        local name = f.GetName and f:GetName() or tostring(f)
        local p = f.GetParent and f:GetParent()
        local pn = p and (p.GetName and p:GetName() or "?") or "-"
        local l, t = f:GetLeft(), f:GetTop()
        print(("%s %s [%s] %s %d %s %s at %s,%s"):format(label, name, pn, f:GetFrameStrata(), f:GetFrameLevel(),
            f:IsShown() and "shown" or "hidden", f.IsObjectType and f:GetObjectType() or "?",
            l and math.floor(l) or "-", t and math.floor(t) or "-"))
    end
    print("|cffffd100FlareUI map layers|r (square style: " .. tostring(squareStyle) .. ")")
    Line("map", MinimapFrame)
    Line("border", MM.Frame)
    Line("edges (sides, bottom, bronze)", MM.BorderAbove)
    for _, parent in ipairs({ MinimapFrame, _G.MinimapBackdrop, Cluster }) do
        for _, child in ipairs(parent and { parent:GetChildren() } or {}) do
            -- frames too: some addons make their map button a plain Frame
            if child.IsObjectType and child:IsObjectType("Frame") and child ~= MM.Frame then
                Line(child:IsObjectType("Button") and "  btn" or "  frame", child)
            end
        end
    end
    -- every LibDBIcon button, parked in the drawer or not, and LibDBIcon's own hide setting
    local lib = LibStub and LibStub("LibDBIcon-1.0", true)
    if lib then
        print("LibDBIcon radius " .. tostring(lib.radius) .. ", buttons:")
        for _, name in ipairs(lib.GetButtonList and lib:GetButtonList() or {}) do
            local b = lib:GetMinimapButton(name)
            local hide = b and b.db and b.db.hide
            Line("  ldb " .. name .. (hide and " (hidden by its addon)" or ""), b)
        end
    end
    local db = ns.db and ns.db.profile and ns.db.profile.minimap
    local left = {}
    for id in pairs(type(db and db.bagLeave) == "table" and db.bagLeave or {}) do left[#left + 1] = id end
    print("left out of the drawer: " .. (#left > 0 and table.concat(left, ", ") or "none"))
end

-- Square style: where LibDBIcon's buttons sit. LibDBIcon places them on a circle at a saved angle, so
-- on a square map they straddle the border, and the order addons load in would move them on every
-- reload. FlareUI places them itself, every time LibDBIcon does (SetPoint):
-- * by default they sit packed along the bottom border, from just right of the sundial, in name
--   order (then up the right side when the bottom is full), centred on the border line, above it;
-- * a button the player drags follows the pointer along the square's edge, and where it's dropped is
--   saved in FlareUI's own settings (minimap.buttonSpots[name], an angle) and kept from then on.
-- Buttons the drawer holds are never touched.
local STACK = { first = 34, step = 32 }   -- from the left corner past the sundial; one button and a gap
local buttonName = setmetatable({}, { __mode = "k" })   -- LibDBIcon button -> its name
MM.extraButtons = {}   -- FlareUI's own minimap button: name -> button (MM.UpdateFlareButton)
local placing = false

local function Spots()
    local db = GetDb()
    if not db then return {} end
    db.buttonSpots = type(db.buttonSpots) == "table" and db.buttonSpots or {}
    return db.buttonSpots
end

-- an angle (LibDBIcon's degrees) on the square's edge, centred on the border line
-- (halfY: the line's half height where the border's box is not square, as Moves.EdgeXY)
local function EdgePoint(angle, half, halfY)
    return MM.Moves.EdgeXY(angle, half, halfY)
end

-- the packed row: the buttons with no spot of their own, in name order
local function StackIndex(button)
    local lib = LibStub and LibStub("LibDBIcon-1.0", true)
    local names, spots = {}, Spots()
    for _, name in ipairs(lib and lib:GetButtonList() or {}) do
        local b = lib:GetMinimapButton(name)
        local held = ns.MinimapBag and ns.MinimapBag.Holds and ns.MinimapBag.Holds(name)
        if b and not held and not spots[name] and MM.OnMap(b) and b:IsShown() then names[#names + 1] = name end
    end
    -- FlareUI's own button (MM.extraButtons) in the same row
    for name, b in pairs(MM.extraButtons) do
        if not spots[name] and MM.OnMap(b) and b:IsShown() then names[#names + 1] = name end
    end
    table.sort(names)
    for i, name in ipairs(names) do if name == buttonName[button] then return i end end
    return #names + 1
end

local function PlaceButton(button)
    if placing or not button or not squareStyle or MM.MapAway() then return end
    local name = buttonName[button]
    if not name or not MM.OnMap(button) then return end
    local half = math.min(MinimapFrame:GetWidth(), MinimapFrame:GetHeight()) / 2
    if half <= 0 then return end
    -- (on the border's line: buttons is its distance past the terrain's top and bottom edges; a
    -- FlareUI border's box is narrower than tall, so its side lines lie that much nearer)
    local halfY = half + MM.SquareBorder().buttons
    local box = MM.Frame
    half = halfY + (box and (box:GetWidth() - box:GetHeight()) / 2 or 0)
    local x, y
    if button.FlareUI_DragAngle then
        -- FlareUI's own button being dragged: the pointer's angle, on the square
        x, y = EdgePoint(button.FlareUI_DragAngle, half, halfY)
    elseif button:GetScript("OnUpdate") then
        -- being dragged: LibDBIcon's angle, on the square
        local _, _, _, px, py = button:GetPoint(1)
        if not (px and py) or (px == 0 and py == 0) then return end
        x, y = EdgePoint(math.deg(math.atan2(py, px)), half, halfY)
    elseif Spots()[name] then
        x, y = EdgePoint(Spots()[name], half, halfY)
    else
        -- packed along the bottom, then up the right side
        local along = STACK.first + (StackIndex(button) - 1) * STACK.step
        if along <= 2 * half then
            x, y = -half + along, -halfY
        else
            x, y = half, -halfY + (along - 2 * half)
        end
    end
    local _, _, _, cx, cy = button:GetPoint(1)
    if cx and cy and math.abs(cx - x) < 0.5 and math.abs(cy - y) < 0.5 then return end
    placing = true
    button:ClearAllPoints()
    button:SetPoint("CENTER", MinimapFrame, "CENTER", x, y)
    placing = false
end

-- a drop saves the spot (the angle of where it was let go)
local function SaveSpot(button)
    local name = buttonName[button]
    local _, _, _, px, py = button:GetPoint(1)
    if name and px and py and not (px == 0 and py == 0) then
        Spots()[name] = math.deg(math.atan2(py, px)) % 360
        MM.PlaceAllButtons()
    end
end

function MM.PlaceAllButtons()
    for _, b in pairs(MM.extraButtons) do PlaceButton(b) end
    local lib = LibStub and LibStub("LibDBIcon-1.0", true)
    if not (lib and lib.GetButtonList) then return end
    for _, name in ipairs(lib:GetButtonList() or {}) do PlaceButton(lib:GetMinimapButton(name)) end
end

-- Popular addons with a minimap button of their own (not LibDBIcon): placed for their own idea of the
-- map, so on the square map they sat apart from the row (MunchieDog 11-20). Adopted like LibDBIcon's:
-- in the packed row, dragged along the square edge, the spot saved under the frame's name. Their own
-- placing still runs (a SetPoint), and the hook puts them back on the square.
MM.OWN_BUTTONS = { "HappyCamperMinimapButton", "LoreForeverMinimapButton" }
function MM.AdoptOwnButtons()
    local added = false
    for _, name in ipairs(MM.OWN_BUTTONS) do
        local button = _G[name]
        if button and not buttonName[button] and button.HookScript then
            buttonName[button] = name
            MM.extraButtons[name] = button
            hooksecurefunc(button, "SetPoint", PlaceButton)
            button:HookScript("OnDragStop", SaveSpot)
            button:HookScript("OnShow", MM.PlaceSoon)
            button:HookScript("OnHide", MM.PlaceSoon)
            added = true
        end
    end
    if added then MM.PlaceAllButtons() end
end

function MM.PullButtonsIn()
    MM.AdoptOwnButtons()
    local lib = LibStub and LibStub("LibDBIcon-1.0", true)
    if not (lib and lib.GetButtonList) then return end
    for _, name in ipairs(lib:GetButtonList() or {}) do
        local button = lib:GetMinimapButton(name)
        if button and not buttonName[button] then
            buttonName[button] = name
            hooksecurefunc(button, "SetPoint", PlaceButton)
            button:HookScript("OnDragStop", SaveSpot)
            button:HookScript("OnShow", MM.PlaceSoon)
            button:HookScript("OnHide", MM.PlaceSoon)
        end
    end
    MM.PlaceAllButtons()
end

-- FlareUI's own minimap button: with FlareUI Minimap Button on
-- (minimap.flareButton), on the minimap unless the drawer holds FlareUI (MinimapBag.lua Bag.FlareIn).
-- Left-click opens the settings, right-click turns the option off (back on only in the settings). It
-- sits and drags like the LibDBIcon buttons: in the packed row on the square map, its spot saved as
-- "FlareUI".
local FLARE_NAME, FLARE_ROUND_ANGLE = "FlareUI", 225   -- (round map: bottom left until dragged)

local function CursorAngle()
    local x, y = GetCursorPosition()
    local scale = MinimapFrame:GetEffectiveScale()
    local midX, midY = MinimapFrame:GetCenter()
    if not (midX and scale and scale > 0) then return FLARE_ROUND_ANGLE end
    return math.deg(math.atan2(y / scale - midY, x / scale - midX)) % 360
end

local function PlaceFlare(b)
    if squareStyle then PlaceButton(b) return end
    -- the round map: on a circle just outside the edge, as LibDBIcon puts buttons there
    local angle = math.rad(b.FlareUI_DragAngle or Spots()[FLARE_NAME] or FLARE_ROUND_ANGLE)
    local r = MinimapFrame:GetWidth() / 2 + 5
    b:ClearAllPoints()
    b:SetPoint("CENTER", MinimapFrame, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function SetFlareButtonArt(b)
    b:SetSize(31, 31)
    local ground = b:CreateTexture(nil, "BACKGROUND")
    ground:SetSize(24, 24)
    ground:SetPoint("CENTER")
    ground:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\AddOns\\FlareUI\\Media\\Art\\Icon.png")
    local mask = b:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(icon)
    icon:AddMaskTexture(mask)
    local ring = b:CreateTexture(nil, "OVERLAY")
    ring:SetSize(50, 50)
    ring:SetPoint("TOPLEFT")
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
end

local function FlareButton()
    if MM.flareButton then return MM.flareButton end
    -- (named ^FlareUI: the drawer never adopts it)
    local b = CreateFrame("Button", "FlareUIMinimapButton", MinimapFrame)
    SetFlareButtonArt(b)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    b:SetScript("OnEnter", function(self)
        ns.OwnGameTooltip(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(L["FlareUI"])
        GameTooltip:AddLine(L["Left-click: open settings"], 1, 1, 1)
        GameTooltip:AddLine(L["Right-click: hide this button"], 1, 1, 1)
        GameTooltip:AddLine(L["Drag to move this button."], 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then
            local db = GetDb()
            if not db then return end
            GameTooltip:Hide()
            db.flareButton = false
            if ns.MinimapBag and ns.MinimapBag.FlareChanged then ns.MinimapBag.FlareChanged() else MM.UpdateFlareButton() end
            print("|cff00ccffFlareUI:|r " .. L["Minimap button hidden. Turn it back on in Settings > Minimap > Addon Buttons."])
            if ns.SettingsPanel and ns.SettingsPanel.Refresh then pcall(ns.SettingsPanel.Refresh, ns.SettingsPanel) end
        elseif ns.SettingsPanel then
            ns.SettingsPanel:Toggle()
        end
    end)
    local function Dragging(self)
        self.FlareUI_DragAngle = CursorAngle()
        PlaceFlare(self)
    end
    b:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", Dragging)
    end)
    b:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        Spots()[FLARE_NAME] = CursorAngle()
        self.FlareUI_DragAngle = nil
        if squareStyle then MM.PlaceAllButtons() else PlaceFlare(self) end
    end)
    buttonName[b] = FLARE_NAME
    MM.flareButton = b
    return b
end

function MM.UpdateFlareButton()
    local bag = ns.MinimapBag
    local db = GetDb()
    local want = MM.initialized and db and db.flareButton ~= false and not (bag and bag.FlareIn and bag.FlareIn())
    if not want then
        if MM.flareButton then MM.flareButton:Hide() end
        if squareStyle then MM.PlaceSoon() end   -- (the packed row closes up)
        return
    end
    local b = FlareButton()
    -- on the square map, above the border with the other left-out buttons (MM.ButtonHolder)
    local parent = squareStyle and MM.ButtonHolder or MinimapFrame
    if b:GetParent() ~= parent then
        b:SetParent(parent)
        b:SetFrameStrata("MEDIUM")
    end
    b:Show()
    if squareStyle then
        MM.extraButtons[FLARE_NAME] = b
        MM.PlaceAllButtons()
    else
        PlaceFlare(b)
    end
end

local function WatchMapButtons()
    MM.PullButtonsIn()
    -- the library can arrive with an addon loading after FlareUI
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:RegisterEvent("PLAYER_LOGIN")
    loader:SetScript("OnEvent", function() MM.PullButtonsIn() end)
    MM.LiftMapButtons()
    -- LibDBIcon tells when it makes a button (an addon registering late)
    local lib = LibStub and LibStub("LibDBIcon-1.0", true)
    if lib and lib.RegisterCallback then
        pcall(lib.RegisterCallback, MM, "LibDBIcon_IconCreated", function()
            C_Timer.After(0, function() MM.PullButtonsIn(); MM.LiftMapButtons() end)
        end)
    end
    MM.mapChildren = MinimapFrame:GetNumChildren()
    -- a new child at once (2 s), and every 6 s anyway: an addon can re-parent, re-layer or show a button
    -- without anything to hook (a light walk of the map's children)
    local beats = 0
    C_Timer.NewTicker(2, function()
        local count = MinimapFrame:GetNumChildren()
        beats = beats + 1
        if count ~= MM.mapChildren or beats >= 3 then
            MM.mapChildren = count
            beats = 0
            MM.AdoptOwnButtons()   -- (made late: LoreForever builds its button after its UI)
            MM.LiftMapButtons()
        end
    end)
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:SetScript("OnEvent", function() C_Timer.After(1, MM.LiftMapButtons) end)
end

-- The map's home parent, and its return from a HUD (MM.MapAway): the layout, mask, rotation and
-- buttons put back once, a frame after the HUD has finished restoring it
local function WatchMapHome()
    MM.mapHome = MinimapFrame:GetParent()
    local wasAway, pending = false, false
    local function Check()
        pending = false
        if MM.MapAway() then wasAway = true return end
        if not wasAway then return end
        wasAway = false
        local function Home()
            if MM.MapAway() then return end
            KeepMapUnrotated()
            -- a HUD shows again what it hid (ForeverFarmHUD: Forever's compass ring among them)
            ParkRoundArt()
            MM:Refresh()
            MM.LiftMapButtons()
            MM.PlaceAllButtons()
        end
        Home()
        -- (ForeverFarmHUD) a HUD can put its zoom, rotation and other settings back after the
        -- map itself: once more when it has finished
        C_Timer.After(0.5, Home)
    end
    local function Soon()
        if pending then return end
        pending = true
        C_Timer.After(0, Check)
    end
    -- GatherLite's HUD calls the map's own SetParent; FarmHud calls the method directly (no hook
    -- fires) but hides and shows the map as it puts it back
    hooksecurefunc(MinimapFrame, "SetParent", Soon)
    MinimapFrame:HookScript("OnShow", Soon)
    MinimapFrame:HookScript("OnHide", Soon)
end

local function InitSquare()
    WatchMapHome()
    KeepMapSquare()
    RemoveEditModeSettings()
    KeepMapUnrotated()
    if Cluster.SetRotateMinimap then hooksecurefunc(Cluster, "SetRotateMinimap", KeepMapUnrotated) end
    CreateMapArt()
    WatchMapButtons()
    StyleHeader()
    InstallSquareHooks()
    -- Edit Mode's box on the border art's edge strips, less their shadow outside the gold line
    ns.FitEditModeBox(Cluster, function()
        local art = MM.Frame
        -- a FlareUI border: on its line's lit outside (the bronze frame's visible outside, MM.SQUARE_BORDERS)
        local flare = HeaderStyle().flare
        if flare and art and art:GetLeft() then
            local v = flare.line
            return art, v, -v, -v, v
        end
        local pieces = MM.Border or art
        local leftEdge, rightEdge, topEdge, bottomEdge = pieces and pieces.LeftEdge, pieces and pieces.RightEdge, pieces and pieces.TopEdge, pieces and pieces.BottomEdge
        if not (art and art:GetLeft() and leftEdge and rightEdge and topEdge and bottomEdge and leftEdge:GetLeft()) then return nil end
        local cut = BORDER_SHADOW
        return art, leftEdge:GetLeft() + cut.left - art:GetLeft(), topEdge:GetTop() - cut.top - art:GetTop(),
            rightEdge:GetRight() - cut.right - art:GetRight(), bottomEdge:GetBottom() + cut.bottom - art:GetBottom()
    end)
end

--------------------------------------------------
-- 10. OBJECTIVE TRACKER SCALE
-- Blizzard's tracker is scaled so its header lines (about 288 px visible) match the minimap's width
--------------------------------------------------
local TRACKER_LINE_WIDTH = 288

-- The map's outer width in the tracker's parent's units
local function FrameOuterWidth(tracker)
    local frame = MM.Border or MM.Frame   -- (the border pieces live on MM.Border)
    if not squareStyle then frame = Cluster.MinimapContainer end
    if not frame then return end
    local width
    local flare = squareStyle and HeaderStyle().flare
    if flare then
        -- a FlareUI border: its visible outside, its line's lit outside (MM.Border spans its edge frame)
        width = frame:GetWidth() - 2 * flare.line
        if width <= 0 then return end
    elseif squareStyle then
        local left = frame.TopLeftCorner and frame.TopLeftCorner:GetLeft()
        local right = frame.TopRightCorner and frame.TopRightCorner:GetRight()
        if not (left and right) then return end
        width = right - left
    else
        width = frame:GetWidth()
        if width <= 0 then return end
    end
    return width * frame:GetEffectiveScale() / tracker:GetParent():GetEffectiveScale()
end

-- ns.SetSystemScale, not Edit Mode's SetScale (its re-layout would run tainted); out of combat only
local trackerScaleWaiter
function MM:UpdateTrackerScale()
    local tracker = _G.ObjectiveTrackerFrame
    if not (tracker and GetDb()) then return end
    -- FlareUI's Quest Tracker parks Blizzard's (unless it stands aside in Gamepad mode)
    local own = ns.db.profile.objectivetracker
    local OT = ns.ObjectiveTracker
    if own and own.enabled and not (OT and OT.WantedInMode and not OT.WantedInMode()) then return end
    if InCombatLockdown() then
        if not trackerScaleWaiter then
            trackerScaleWaiter = CreateFrame("Frame")
            trackerScaleWaiter:SetScript("OnEvent", function(waiter)
                waiter:UnregisterEvent("PLAYER_REGEN_ENABLED")
                self:UpdateTrackerScale()
            end)
        end
        trackerScaleWaiter:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    local width = FrameOuterWidth(tracker)
    if width or squareStyle then
        ns.SetSystemScale(tracker, width and width / TRACKER_LINE_WIDTH or 1)
    end
end

--------------------------------------------------
-- 11. PUBLIC
--------------------------------------------------
-- FPS and latency in the clock's tooltip (Blizzard rebuilds it every second; the function is shared,
-- hence the owner check)
local function AddClockStats()
    local db = GetDb()
    local clock = _G.TimeManagerClockButton
    if not (db and db.enabled and db.clockStats and clock and GameTooltip:GetOwner() == clock) then return end
    local _, _, latencyHome, latencyWorld = GetNetStats()
    local label, value = NORMAL_FONT_COLOR, HIGHLIGHT_FONT_COLOR
    GameTooltip:AddDoubleLine(L["Framerate"], string.format("%.0f fps", GetFramerate()),
        label.r, label.g, label.b, value.r, value.g, value.b)
    GameTooltip:AddDoubleLine(L["Latency (Home)"], latencyHome .. " ms", label.r, label.g, label.b, value.r, value.g, value.b)
    GameTooltip:AddDoubleLine(L["Latency (World)"], latencyWorld .. " ms", label.r, label.g, label.b, value.r, value.g, value.b)
end

function MM:Refresh()
    local db = GetDb()
    if not db or not db.enabled or not self.initialized then return end
    -- the round style's frame is Blizzard's own texture
    MM.TintArt(_G.MinimapCompassTexture)
    self:UpdateLayout()
    self:UpdateTrackerScale()
    self:ApplyFonts()
    UpdateCoordsHover()
    if ns.MinimapEye then ns.MinimapEye.Place() end
    if ns.MinimapVehicle then ns.MinimapVehicle.Place() end
    if ns.MinimapDurability then ns.MinimapDurability.Place() end
end

-- The style in use until the next reload (minimap.style is latched at startup)
function MM.IsSquare()
    return squareStyle
end

-- a node addon's scan has the map away: fn runs when it is home again (true: it waits)
function MM.AfterScan(key, fn)
    if Scan.Busy() then Scan.Later(key, fn) return true end
end

-- The zone map (Shift+M, Blizzard_BattlefieldMap): FlareUI Thin in bronze instead of Blizzard's gold
-- frame, on its BorderFrame so Blizzard's opacity slider fades it too; and its tab (shown while the
-- mouse is on the map) drags it. Blizzard saves a moved tab's place at logout.
local ZONE_MAP_PIECES = { "TopLeft", "TopRight", "BottomLeft", "BottomRight", "Top", "Bottom", "Left", "Right", "CloseButtonBorder" }
local function SkinZoneMap()
    local map, tab = _G.BattlefieldMapFrame, _G.BattlefieldMapTab
    local frame = map and map.BorderFrame
    if not frame or map.FlareUI_Skinned then return end
    map.FlareUI_Skinned = true
    for _, key in ipairs(ZONE_MAP_PIECES) do
        if frame[key] then frame[key]:Hide() end
    end
    local area = map.ScrollContainer or map
    local border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    border:SetPoint("TOPLEFT", area, "TOPLEFT", -3, 3)
    border:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", 3, -3)
    border:SetBackdrop({ edgeFile = LibStub("LibSharedMedia-3.0"):Fetch("border", "FlareUI Thin"), edgeSize = 8 })
    local c = ns.BORDER_COLOR
    border:SetBackdropBorderColor(c.r, c.g, c.b, 1)
    if frame.CloseButton then
        frame.CloseButton:ClearAllPoints()
        frame.CloseButton:SetPoint("TOPRIGHT", border, "TOPRIGHT", 2, 2)
    end

    -- Blizzard drags the tab only while unlocked, and then moves the map away from it: here the tab
    -- drags whatever Lock says, and takes the map along (it hangs below the tab)
    if not (tab and tab.StartMoving) then return end
    tab:RegisterForDrag("LeftButton")
    tab:SetScript("OnDragStart", function(self)
        self:SetMovable(true)
        self:StartMoving()
    end)
    tab:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if ValidateFramePosition then ValidateFramePosition(self) end
    end)
end

-- Gathering addons that read nodes by sliding the hidden map under the cursor (Lueur, NodeSight,
-- Nodeworthy) hide or shrink what is on the map while they scan, so quest areas and icons flash, on
-- Blizzard's minimap too. A notice, once per account and addon, says whose it is (and the Minimap
-- settings page says so while one is loaded).
MM.SCANNERS = { "Lueur", "NodeSight", "Nodeworthy" }
function MM.LoadedScanners()
    local list = {}
    for _, name in ipairs(MM.SCANNERS) do
        if C_AddOns.IsAddOnLoaded(name) then list[#list + 1] = C_AddOns.GetAddOnMetadata(name, "Title") or name end
    end
    return list
end

ns.Dialogs = ns.Dialogs or {}
ns.Dialogs["FLAREUI_NODE_SCAN"] = {
    text = L["%s finds gathering nodes by sliding the minimap under your cursor. While it scans, the map and what is on it (quest areas, icons) can flash or vanish for a moment.\n\nThat comes from the addon itself, not FlareUI, and happens on Blizzard's minimap too. NodeRadar, FarmMap and GatherMemory find nodes without moving the map."],
    hideOnEscape = true,   -- (one button: the game's own Okay)
}

-- Farming HUDs take the real minimap into a big see-through map in
-- the middle of the screen while they are on, and put it back when turned off. FlareUI stands back
-- meanwhile (MM.MapAway) and lays its map out again after (WatchMapHome).
MM.HUDS = { "ForeverFarmHUD", "FarmHud" }
function MM.LoadedHUDs()
    local list = {}
    for _, name in ipairs(MM.HUDS) do
        if C_AddOns.IsAddOnLoaded(name) then list[#list + 1] = C_AddOns.GetAddOnMetadata(name, "Title") or name end
    end
    return list
end

ns.Dialogs["FLAREUI_MAP_HUD"] = {
    text = L["%s moves the minimap into its farming HUD while the HUD is on. The map is then the addon's: FlareUI puts its own minimap back when you turn the HUD off.\n\nIf the minimap still looks wrong after that, type /reload."],
    hideOnEscape = true,
}

function MM.NoticeScanners()
    local global = ns.db and ns.db.global
    if not global then return end
    global.nodeScanNotice = global.nodeScanNotice or {}
    for _, group in ipairs({ { MM.SCANNERS, "FLAREUI_NODE_SCAN" }, { MM.HUDS, "FLAREUI_MAP_HUD" } }) do
        for _, name in ipairs(group[1]) do
            if C_AddOns.IsAddOnLoaded(name) and not global.nodeScanNotice[name] then
                global.nodeScanNotice[name] = true
                local title = C_AddOns.GetAddOnMetadata(name, "Title") or name
                -- a moment after login, once the screen has settled
                C_Timer.After(6, function() ns.ShowDialog(group[2], title) end)
                return   -- one notice at a time; another such addon gets its own next login
            end
        end
    end
end

function MM:Init()
    if self.initialized then return end
    EventUtil.ContinueOnAddOnLoaded("Blizzard_BattlefieldMap", SkinZoneMap)
    if not (MinimapFrame and Cluster and Cluster.ZoneTextButton and Cluster.Tracking and Cluster.MinimapContainer and _G.GameTimeFrame) then
        print("|cffff0000FlareUI:|r Minimap module could not find the Blizzard minimap cluster.")
        return
    end
    local db = GetDb()
    squareStyle = not db or db.style ~= "round"
    if db then db.coordsOnHover, db.coords = nil, nil end   -- (old settings, no longer read)
    if db then
        local had = {}
        for _, key in ipairs({ "fps", "latency" }) do
            local mode = rawget(db, key)
            if mode == "always" or mode == "hover" then had[#had + 1] = key end
            db[key] = nil
        end
        local bar = db.infoBar
        if #had > 0 and type(bar) == "table" then
            for _, key in ipairs(had) do
                local shown = bar.left == key or bar.center == key or bar.right == key
                for _, side in ipairs(Bar.SIDES) do
                    if not shown and (bar[side] or "none") == "none" then bar[side] = key; shown = true end
                end
            end
        end
    end

    hooksecurefunc("GameTime_UpdateTooltip", AddClockStats)
    -- filled on enter, not on Blizzard's next tick
    EventUtil.ContinueOnAddOnLoaded("Blizzard_TimeManager", function()
        local clock = _G.TimeManagerClockButton
        if clock then clock:HookScript("OnEnter", function() TimeManagerClockButton_UpdateTooltip() end) end
        if not squareStyle then self:ApplyFonts() end
    end)

    if squareStyle then
        InitSquare()
    else
        -- Rotation can change the native frame's width.
        Cluster.MinimapContainer:HookScript("OnSizeChanged", function() self:UpdateTrackerScale() end)
        -- the quest, task and dig-site areas' edge arcs draw past the round map's edge (at its square
        -- frame's): off, as on the square map. The areas themselves still show.
        for _, method in ipairs({ "SetQuestBlobRingScalar", "SetTaskBlobRingScalar", "SetArchBlobRingScalar" }) do
            if MinimapFrame[method] then pcall(MinimapFrame[method], MinimapFrame, 0) end
        end
    end
    KeepSunPlaced()   -- both styles
    if ns.MinimapEye then ns.MinimapEye.Init() end   -- Group Finder Icon, above the badge (MinimapEye.lua)
    if ns.MinimapVehicle then ns.MinimapVehicle.Init() end   -- Vehicle Exit Icon, above it (MinimapVehicle.lua)
    if ns.MinimapDurability then ns.MinimapDurability.Init() end   -- Durability Icon, above them (MinimapDurability.lua)
    AddEditModeSettings()
    Scan.Watch()
    WatchMask()   -- the round style too: a faded-out map keeps its empty mask
    SetupMapMouse()
    hooksecurefunc(MinimapFrame, "SetZoom", OnZoom)
    hooksecurefunc(Cluster, "SetEditModeScale", function()
        self:UpdateLayout()
        self:UpdateTrackerScale()
    end)
    self.initialized = true
    C_Timer.After(0, MM.UpdateFlareButton)   -- (FlareUI's own button: the drawer starts in this same pass)

    EventUtil.ContinueOnAddOnLoaded("Blizzard_ObjectiveTracker", function() self:UpdateTrackerScale() end)
    EventUtil.ContinueOnAddOnLoaded("Blizzard_WorldMap", RestyleWorldMapCoords)
    self:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED", "Refresh")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "Refresh")

    self:Refresh()
    -- the frame's corners have positions only after the first layout pass
    C_Timer.After(0, function() self:Refresh() end)
    -- last: it reads other addons' buttons, and the map doesn't depend on it
    local bag = ns.MinimapBag
    if bag and bag.ApplyStyle then bag.ApplyStyle() end   -- Sundial off hides the badge
    if bag then bag:Init() end
    MM.Moves.Init()   -- the edge icons' handles (after the icons' own modules)
    local drawer = _G.AddonCompartmentFrame
    if drawer and bag and bag.initialized then
        -- Blizzard's addon drawer stays hidden while the bag replaces it.
        hooksecurefunc(drawer, "UpdateDisplay", drawer.Hide)
        drawer:Hide()
    end
    MM.NoticeScanners()
end

--------------------------------------------------
-- 12. SETTINGS PREVIEW SAMPLE
-- A plain copy of the minimap as FlareUI draws it, from the module's own pieces (border layout,
-- plate, header row, menu rows), for the settings Info Panel. Blizzard's minimap
-- is never touched: the terrain is a shipped picture and the badge is drawn from its atlases.
-- Kinds: "map" (default), "drawer" and "menu". The clock's tooltip is Blizzard's (FlareUI only adds lines to
-- it), so it has no sample.
--------------------------------------------------
do
    local TERRAIN = "Interface\\AddOns\\FlareUI\\Media\\Art\\Tour\\Minimap.png"
    local CROP_A, CROP_B = 35 / 512, 247 / 512        -- the map inside the picture
    local ROUND_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
    -- Blizzard's round layout (Blizzard_Minimap Minimap.xml, Camelot Minimap.lua and the clock override)
    local ROUND = { FRAME = "UI-HUD-Minimap-Frame", W = 215, H = 226, MAP = 198, CLUSTER = 256, TOP = 30, SHIFT = 10,
        ZONE_W = 152, ZONE_H = 23, BUTTON = 23, TRACKING = 17, ZONE_LEVEL = 10 }
    -- Forever's day/night badge (Camelot Diel.lua)
    local DIEL = { BORDER = "UI-HUD-Minimap-Frame-Cycle", DAY = "UI-HUD-Minimap-DayCycle", NIGHT = "UI-HUD-Minimap-NightCycle" }
    local TRACKING_ATLAS, CALENDAR_ATLAS = "ui-hud-minimap-tracking-button", "ui-hud-minimap-calendar-button"
    local OVER_LEVEL = 12      -- badge and drawer over both styles' header rows
    local DRAWER_GAP = 6

    local function AtlasSize(atlas, w, h)
        local info = C_Texture.GetAtlasInfo(atlas)
        if info and info.width and info.width > 0 then return info.width, info.height end
        return w, h
    end

    -- a header button's art, without the button
    local function ArtFrame(parent, atlas, size)
        local frame = CreateFrame("Frame", nil, parent)
        frame:SetSize(size, size)
        frame.Art = frame:CreateTexture(nil, "ARTWORK")
        frame.Art:SetAtlas(atlas)
        frame.Art:SetAllPoints()
        return frame
    end

    local function Terrain(parent, size)
        local t = parent:CreateTexture(nil, "BACKGROUND", nil, 1)
        t:SetTexture(TERRAIN)
        t:SetTexCoord(CROP_A, CROP_B, CROP_A, CROP_B)
        t:SetPoint("CENTER")
        t:SetSize(size, size)
        return t
    end

    local function ZoneAndClock(plate)
        plate.Zone = plate:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        plate.Zone:SetJustifyH("LEFT")
        plate.Zone:SetWordWrap(false)
        plate.Clock = plate:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    end

    -- Square style: the frame art, the black backing and the header row, as InitSquare lays them
    local function BuildSquare(f)
        local sq = CreateFrame("Frame", nil, f)
        sq:SetPoint("TOPLEFT")
        sq:SetSize(MAP_SIZE + 2 * FRAME_PAD, MAP_SIZE + 2 * FRAME_PAD)
        local inner = MAP_SIZE - 2 * MAP_CROP
        -- layered as the real map: the border under the terrain, the pieces that reach over the
        -- map (bottom corners; Bordered's title bar) above it
        local art = CreateFrame("Frame", nil, sq)
        art:SetPoint("CENTER")
        art:SetSize(MAP_SIZE, MAP_SIZE)
        art:SetFrameLevel(sq:GetFrameLevel() + 1)
        sq.Art = art
        local map = CreateFrame("Frame", nil, sq)
        map:SetAllPoints(art)
        map:SetFrameLevel(sq:GetFrameLevel() + 2)
        local back = map:CreateTexture(nil, "BACKGROUND")
        back:SetPoint("CENTER")
        back:SetSize(inner, inner)
        back:SetColorTexture(0, 0, 0, 1)
        sq.Back = back
        sq.Terrain = Terrain(map, inner)
        local corners = CreateFrame("Frame", nil, sq)
        corners:SetAllPoints(art)
        corners:SetFrameLevel(sq:GetFrameLevel() + 3)
        ApplyBorder(art, corners)
        sq.Above = corners
        sq.Tracking = ArtFrame(sq, TRACKING_ATLAS, HEADER_HEIGHT)
        sq.Calendar = ArtFrame(sq, CALENDAR_ATLAS, HEADER_HEIGHT)
        sq.Header = CreateHeader(sq)
        ZoneAndClock(sq.Header)
        local row = sq:GetFrameLevel() + ROW_LEVEL
        sq.Tracking:SetFrameLevel(row)
        sq.Calendar:SetFrameLevel(row)
        sq.Header:SetFrameLevel(row - 1)
        MM.PlaceHeaderRow(art, sq.Tracking, sq.Header, sq.Calendar)
        return sq
    end

    -- Round style: Forever's own cluster, which FlareUI leaves as it is (zone button, tracking,
    -- calendar, round frame)
    local function BuildRound(f)
        local rd = CreateFrame("Frame", nil, f)
        rd:SetPoint("TOPLEFT")
        local w, h = AtlasSize(ROUND.FRAME, ROUND.W, ROUND.H)
        rd:SetSize(ROUND.CLUSTER, ROUND.TOP + h)
        local box = CreateFrame("Frame", nil, rd)
        box:SetSize(w, h)
        box:SetPoint("TOP", rd, "TOP", ROUND.SHIFT, -ROUND.TOP)
        rd.Box = box
        rd.Terrain = Terrain(box, ROUND.MAP)
        local mask = box:CreateMaskTexture()
        mask:SetTexture(ROUND_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(rd.Terrain)
        rd.Terrain:AddMaskTexture(mask)
        local ring = box:CreateTexture(nil, "OVERLAY", nil, 2)
        ring:SetAtlas(ROUND.FRAME)
        MM.TintArt(ring)
        ring:SetSize(w, h)
        ring:SetPoint("CENTER")
        local zone = CreateFrame("Frame", nil, rd)
        zone:SetSize(ROUND.ZONE_W, ROUND.ZONE_H)
        zone:SetPoint("TOP", rd, "TOP", ROUND.SHIFT, 0)
        zone:SetFrameLevel(rd:GetFrameLevel() + ROUND.ZONE_LEVEL)
        zone.Plate = zone:CreateTexture(nil, "BACKGROUND")
        zone.Plate:SetAtlas(PLATE_ATLAS)
        zone.Plate:SetAllPoints()
        ZoneAndClock(zone)
        zone.Zone:SetPoint("LEFT", zone, "LEFT", 8, -1)
        zone.Zone:SetSize(110, 12)
        -- the clock button sits 3 px in from the plate's right end, its text 3 px right of its middle
        zone.Clock:SetPoint("CENTER", zone, "RIGHT", -20, -1)
        rd.Zone = zone
        local tracking = CreateFrame("Frame", nil, rd)
        tracking:SetSize(ROUND.TRACKING, ROUND.TRACKING)
        tracking:SetPoint("RIGHT", zone, "LEFT", 0, 0)
        tracking:SetFrameLevel(zone:GetFrameLevel())
        local trackingBack = tracking:CreateTexture(nil, "BACKGROUND")
        trackingBack:SetAtlas("ui-hud-minimap-button")
        trackingBack:SetAllPoints()
        local trackingArt = ArtFrame(tracking, TRACKING_ATLAS, ROUND.BUTTON)
        trackingArt:SetPoint("CENTER")
        local calendar = ArtFrame(rd, CALENDAR_ATLAS, ROUND.BUTTON)
        calendar:SetPoint("TOPLEFT", zone, "TOPRIGHT", -4, 0)
        calendar:SetFrameLevel(zone:GetFrameLevel())
        rd.Calendar = calendar
        return rd
    end

    local function BuildBadge(parent)
        local badge = CreateFrame("Frame", nil, parent)
        badge:SetSize(AtlasSize(DIEL.BORDER, 42, 42))
        badge.Background = badge:CreateTexture(nil, "BACKGROUND")
        badge.Background:SetPoint("CENTER")
        local border = badge:CreateTexture(nil, "OVERLAY", nil, 1)
        border:SetAllPoints()
        border:SetAtlas(DIEL.BORDER)
        return badge
    end

    function MM.CreateSample(parent, kind)
        local f = CreateFrame("Frame", nil, parent)
        f.fuiSample = true
        f:EnableMouse(false)
        f.kind = kind == "menu" and "menu" or "map"
        -- the style cards: their own style, whatever the one in use
        if kind == "square" or kind == "round" then f.forceStyle = kind end
        -- the Square (Clean) and Square (Header) cards each with its own top
        if kind == "headerless" or kind == "bordered" then
            f.forceStyle, f.forceHeader = "square", kind == "bordered" and "art" or "headerless"
        end
        if f.kind == "menu" then
            -- the real menu's rows, without their secure clicks
            f.Menu = CreateFrame("Frame", nil, f, "BackdropTemplate")
            f.Menu:SetPoint("TOPLEFT")
            f.Menu:EnableMouse(false)
            if not MM.FillMenu(f.Menu, false) then f.Menu:SetSize(120, 40) end
            return f
        end
        f.Square = BuildSquare(f)
        f.Round = BuildRound(f)
        local over = CreateFrame("Frame", nil, f)
        over:SetAllPoints()
        over:SetFrameLevel(f:GetFrameLevel() + OVER_LEVEL)
        f.Badge = BuildBadge(over)
        f.Badge:SetFrameLevel(over:GetFrameLevel() + 1)
        if kind == "drawer" then
            f.Flare = CreateFrame("Frame", nil, over)
            SetFlareButtonArt(f.Flare)
            f.Compartment = CreateFrame("Frame", nil, over)
            f.Compartment:SetSize(23, 22)
            local art = f.Compartment:CreateTexture(nil, "ARTWORK")
            art:SetAtlas("ui-hud-minimap-addon-indicator", true)
            art:SetPoint("CENTER")
            f.Compartment.Text = f.Compartment:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            f.Compartment.Text:SetPoint("CENTER")
            f.Compartment.Text:SetScale(0.9)
            f.Badge.Highlight = f.Badge:CreateTexture(nil, "OVERLAY", nil, 2)
            f.Badge.Highlight:SetAllPoints()
            f.Badge.Highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
            f.Badge.Highlight:SetBlendMode("ADD")
            f.Badge.Highlight:SetAlpha(0.65)
        end
        local bag = ns.MinimapBag
        if bag and bag.CreateSample then
            f.Drawer = bag.CreateSample(f)
            f.Drawer:SetFrameLevel(f:GetFrameLevel() + OVER_LEVEL)
        end
        return f
    end

    local function PlaceSampleFlare(f, square, db)
        local angle = type(db.buttonSpots) == "table" and tonumber(db.buttonSpots[FLARE_NAME])
        local terrain = square and f.Square.Terrain or f.Round.Terrain
        local half = terrain:GetWidth() / 2
        local x, y
        if square then
            local art = f.Square.Art
            local halfY = half + MM.SquareBorder().buttons
            local halfX = halfY + (art:GetWidth() - art:GetHeight()) / 2
            if angle then
                x, y = EdgePoint(angle, halfX, halfY)
            else
                x, y = -halfX + STACK.first, -halfY
            end
        else
            angle = math.rad(angle or FLARE_ROUND_ANGLE)
            x, y = math.cos(angle) * (half + 5), math.sin(angle) * (half + 5)
        end
        f.Flare:ClearAllPoints()
        f.Flare:SetPoint("CENTER", terrain, "CENTER", x, y)
    end

    local function DrawMap(f, spec)
        local db = GetDb() or {}
        local square = (f.forceStyle or db.style) ~= "round"
        f.Square:SetShown(square)
        f.Round:SetShown(not square)

        -- the zone's name and colour and the time, read from Blizzard's own (never written)
        local zone = GetMinimapZoneText and GetMinimapZoneText() or ""
        if zone == "" then zone = L["Deathknell"] end
        local r, g, b = 1, 0.82, 0
        if _G.MinimapZoneText then r, g, b = _G.MinimapZoneText:GetTextColor() end
        local ticker = _G.TimeManagerClockTicker
        local clock = ticker and ticker:GetText()
        if not clock or clock == "" then clock = date("%H:%M") end
        local plate = square and f.Square.Header or f.Round.Zone
        ApplyFont(plate.Zone, db.zoneFont)
        plate.Zone:SetText(zone)
        plate.Zone:SetTextColor(r, g, b)
        ApplyFont(plate.Clock, db.clockFont)
        plate.Clock:SetText(clock)
        if square then
            -- the Header style (Headerless / Bordered), as the real map, or the card's own
            local sq = f.Square
            MM.sampleHeader = f.forceHeader
            -- the map frame, terrain and backing grown for a FlareUI border, as the real map's
            MM.FitArt(sq.Art, sq, sq.Terrain, sq.Back)
            ApplyBorder(sq.Art, sq.Above)
            MM.PlaceHeaderRow(sq.Art, sq.Tracking, sq.Header, sq.Calendar)
            f.sunOverhang = MM.SquareBorder().sun
            MM.sampleHeader = nil
            -- the zone text runs up to the clock, which grows with its time (StyleHeader)
            local header = f.Square.Header
            local clockWidth = MM.ClockWidth(plate.Clock)
            plate.Zone:ClearAllPoints()
            plate.Zone:SetPoint("TOPLEFT", header, "TOPLEFT", HEADER_GAP + PLATE_INSET, 0)
            plate.Zone:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -clockWidth, 0)
            plate.Clock:ClearAllPoints()
            plate.Clock:SetPoint("RIGHT", header, "RIGHT", -PLATE_INSET, 0)
        end

        local badge = f.Badge
        local day = not C_DateAndTime or not C_DateAndTime.IsDayTime or C_DateAndTime.IsDayTime()
        badge.Background:SetAtlas(day and DIEL.DAY or DIEL.NIGHT, true)
        badge:ClearAllPoints()
        if square then
            badge:SetScale(SUN_SCALE)
            local overhang = (f.sunOverhang or MM.SQUARE_BORDERS.bronze.sun) / SUN_SCALE
            badge:SetPoint("BOTTOMLEFT", f.Square.Art, "BOTTOMLEFT", -overhang, -overhang)
        else
            badge:SetScale(1)
            badge:SetPoint("CENTER", f.Round.Box, "CENTER", SUN_ROUND_X, SUN_ROUND_Y)
        end
        -- hidden with the Sundial switch (Map Tools) too
        local bag = ns.MinimapBag
        badge:SetShown(not EQoLHidesSun() and not (bag and bag.SundialShown and not bag.SundialShown()))

        -- (the map's own coordinates text is always hidden: coordinates are an Info Bar cell)
        local base = square and f.Square or f.Round
        local width, height = base:GetSize()
        -- the addon drawer, open under the map
        local drawer = f.Drawer
        local drawerOn = bag and bag:IsOn()
        local preview
        if f.Compartment and bag then
            local style = bag.Style()
            local flareOn = bag.FlareOn()
            local size
            if spec then
                if spec.key == "mm.drawerStyle" then style = spec.value or style end
                if spec.key == "mm.flareButton" and spec.value ~= nil then flareOn = spec.value end
                if spec.key == "mm.bagButtonSize" then size = spec.value end
            end
            if style == "sundial" and not bag.SundialShown() then style = "blizzard" end
            drawerOn = style ~= "disabled" and db.buttonBag ~= false
            preview = { buttonSize = bag.ButtonSize(size), flareIn = drawerOn and flareOn and bag.FlareSelected() }
            f.Flare:SetShown(flareOn and not preview.flareIn)
            if f.Flare:IsShown() then PlaceSampleFlare(f, square, db) end
            f.Badge.Highlight:SetShown(drawerOn and style == "sundial")
            f.Compartment:SetShown(drawerOn and style == "blizzard")
            f.Compartment:ClearAllPoints()
            f.Compartment:SetPoint("TOP", base.Calendar, "BOTTOM", 0, 1)
        end
        if drawer and drawerOn then
            local w, h, count = bag.DrawSample(drawer, preview)
            if preview and f.Compartment:IsShown() then f.Compartment.Text:SetText(count) end
            local x = square and FRAME_PAD or (ROUND.CLUSTER - f.Round.Box:GetWidth()) / 2 + ROUND.SHIFT
            drawer:ClearAllPoints()
            drawer:SetPoint("TOPLEFT", f, "TOPLEFT", x, -(height + DRAWER_GAP))
            width = math.max(width, x + w)
            height = height + DRAWER_GAP + h
        elseif drawer then
            drawer:Hide()
        end
        return width, height
    end

    function MM.DrawSample(f, kind, spec)
        local width, height
        if f.kind == "menu" then
            width, height = f.Menu:GetSize()
        else
            width, height = DrawMap(f, spec)
        end
        f:SetSize(width, height)
        f:Show()
        return width, height
    end
end
