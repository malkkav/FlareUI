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

-- Header (minimap.squareHeader, 11-13 Marcus): two looks for the frame's top.
-- * Headerless (default): the border lies under the map, so its title bar is covered and the header
--   row sits on the terrain; the top edge comes down onto the map's top.
-- * Bordered: the title bar and its corners draw over the map, a band the header row sits in (the
--   look before 6.1.1).
-- band: how far below the frame's top the mail and other indicators start; headerTop: the header row's
-- inset from the frame's top; drop: the top edge lowered onto the map; over: top pieces above the map.
-- (Tried and rolled back 11-13: a top made of the bottom edge upside down, a taller Headerless map,
-- its top corners above the map. Marcus: this version is the best.)
-- bronze (11-13, Marcus): Headerless framed in the settings window's border instead, the character
-- select's heavy bronze frame without its rivets, over the map; the metal frame's pieces stay (unseen)
-- to measure the Edit Mode box, and come back if the client lacks the atlas.
local HEADER_STYLES = {
    headerless = { band = 27, headerTop = 7, drop = 3, over = false, bronze = true, side = 10, shift = -1 },
    art        = { band = 22, headerTop = 2, drop = 0, over = true, side = 6 },
}
local BRONZE_ATLAS = "heavybronze-frame-basic"
-- the bronze frame this far past the map frame's edges, per side: measured against Bordered's metal
-- frame on Marcus's screenshots (11-13) so both styles cover the same box
local BRONZE_OUT   = { left = 9, right = 7, top = 11, bottom = 8 }   -- (top +1: Marcus 11-13)
local function HeaderStyle(db)
    -- (a style card's sample draws its own header, whatever the one in use: MM.sampleHeader)
    if MM.sampleHeader then return HEADER_STYLES[MM.sampleHeader] or HEADER_STYLES.headerless end
    db = db or (ns.db and ns.db.profile and ns.db.profile.minimap)
    return HEADER_STYLES[db and db.squareHeader or "headerless"] or HEADER_STYLES.headerless
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
local SUN_OVERHANG  = 9      -- badge overhang past the map's corner (11-13 Marcus: 3 more, to pop out)
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
    -- Info Text (11-13): the coordinates, framerate and latency
    local coords = Cluster.MinimapContainer and Cluster.MinimapContainer.PlayerCoords
    if coords and coords.CoordText then
        ApplyFont(coords.CoordText, db.infoFont)
        coords:SetHeight((db.infoFont and db.infoFont.size or 11) * (ns.TEXT_SCALE or 1) + 2)
    end
    for fontString in pairs(MM.infoTexts) do ApplyFont(fontString, db.infoFont) end
end
-- the framerate and latency texts, made when first shown (NewStat)
MM.infoTexts = {}

-- Node addons' scans (Lueur, NodeSight, Nodeworthy): since Forever build 70862 the minimap tooltip
-- only reads the real mouse, so they slide the hidden map under the cursor with AdjustPointsOffset
-- and take their whole offset back at the end. The sum of those moves says where the map is: while
-- it is away, FlareUI keeps their offset when it anchors the map, leaves their empty mask on, keeps
-- the coordinates and auto zoom-out still and lets the mouse wheel through (it would zoom the hidden
-- map instead of the camera). What waited runs once the map is home. NodeRadar never moves it.
-- Node addons (Lueur, NodeSight, Nodeworthy) scan by sliding the hidden map under the cursor. A scan
-- is on while the map is away from home, while one of them holds the map's clicks off (each turns
-- them off at the start and back on at the end), and for a moment after the last move. Lueur 1.6
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
    -- Headerless: the top edge down onto the map's top (11-13, Marcus: a black gap showed between them
    -- once the border went under the map); it hangs between the top corners, so it moves with them
    for _, key in ipairs({ "TopLeftCorner", "TopRightCorner" }) do
        if layout[key] then layout[key].y = (layout[key].y or 0) - style.drop end
    end
    return layout
end

-- The border in the chosen Header style. It lies under the map (since 11-13), but some pieces reach in
-- over the map and draw on `above`, a frame just over the map in its strata (addon buttons are MEDIUM,
-- above both): always the sides, the bottom and its corners (the map cut their inner shadow and its
-- square corners across them), and with Bordered the title bar and its corners too. The pieces stay
-- border.TopEdge etc. for measuring.
local TOP_PIECES = { "TopEdge", "TopLeftCorner", "TopRightCorner" }
local function ApplyBorder(border, above, style)
    style = style or HeaderStyle()
    NineSliceUtil.ApplyLayout(border, BorderLayout(style))
    -- (11-13, Marcus) the sides and bottom too: their inner shadow falls over the map's edges, and the
    -- map cut it off while they lay under it
    for _, key in ipairs({ "BottomLeftCorner", "BottomRightCorner", "LeftEdge", "RightEdge", "BottomEdge" }) do
        if border[key] then border[key]:SetParent(above) end
    end
    for _, key in ipairs(TOP_PIECES) do
        if border[key] then border[key]:SetParent(style.over and above or border) end
    end
    -- Headerless in the heavy bronze frame (BRONZE_ATLAS): Blizzard's own frames stretch it to any size
    local bronze = style.bronze and C_Texture.GetAtlasInfo(BRONZE_ATLAS) and true or false
    if bronze and not above.Bronze then
        above.Bronze = above:CreateTexture(nil, "BORDER")
        above.Bronze:SetAtlas(BRONZE_ATLAS)
        above.Bronze:SetPoint("TOPLEFT", border, "TOPLEFT", -BRONZE_OUT.left, BRONZE_OUT.top)
        above.Bronze:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", BRONZE_OUT.right, -BRONZE_OUT.bottom)
    end
    if above.Bronze then above.Bronze:SetShown(bronze) end
    for _, key in ipairs({ "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
                           "TopEdge", "BottomEdge", "LeftEdge", "RightEdge" }) do
        if border[key] then border[key]:SetAlpha(bronze and 0 or 1) end
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
    -- the bronze border itself on a frame of its own in the lowest strata (11-13, after four reports of
    -- addon buttons under it): under the map and everything on and around it, as ElvUI and BasicMinimap
    -- draw theirs, so no button can ever sit beneath it. The frame above keeps holding the tracking
    -- button, indicators, coordinates and sun at their own levels.
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
    MinimapFrame:SetMaskTexture(MM.mapFaded and MASKS.EMPTY or SQUARE_MASK)
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

-- Forever's zone plate stretched over a frame, its ends kept whole
local function Plate(texture, frame)
    texture:SetAtlas(PLATE_ATLAS)
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
    local side = HeaderStyle().side or HEADER_SIDE   -- (11-13: the bronze frame's sides are thicker: the zone bar narrows)
    -- shift: the row centred on the frame art, not the map (the bronze reaches 9 out on the left, 7 on
    -- the right: its centre is 1 left of the map's; 11-13 Marcus "super centered")
    tracking:SetPoint("TOPLEFT", frame, "TOPLEFT", side + (HeaderStyle().shift or 0), -HeaderStyle().headerTop)
    header:SetPoint("LEFT", tracking, "RIGHT", HEADER_GAP, 0)
    header:SetWidth(MAP_SIZE - 2 * side - tracking:GetWidth() - calendar:GetWidth() - 2 * HEADER_GAP)
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
    coords:SetPoint("BOTTOM", MM.Frame, "BOTTOM", 0, COORDS.GAP)
end

-- The world map's coordinates in the same style; one anchor per label so the bigger font is not cut
-- by its 100 px frame
local function RestyleWorldMapCoords()
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
local SUN_ROUND_X, SUN_ROUND_Y = 55, 86   -- Diel.lua's DielFrameData.AnchorX / AnchorY

-- scale, point, relative frame, relative point, x, y
local function SunSpot()
    if squareStyle then
        local overhang = SUN_OVERHANG / SUN_SCALE   -- offsets are in the badge's own, scaled units
        return SUN_SCALE, "BOTTOMLEFT", MM.Frame, "BOTTOMLEFT", -overhang, -overhang
    end
    local container = Cluster.MinimapContainer
    local s = container:GetScale()
    if not (s and s > 0) then s = 1 end
    return 1 / s, "CENTER", container, "CENTER", SUN_ROUND_X * s, SUN_ROUND_Y * s
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

-- Every way to place it puts it straight back, and a check every frame catches the calls these hooks
-- never see (a method taken from the frame metatable, or a parent moved under it).
local function KeepSunPlaced()
    local sun = Cluster.DielFrame
    if not sun or MM.sunGuard then return end
    EventUtil.ContinueOnAddOnLoaded("EnhanceQoL", SilenceEQoLMoon)
    for _, method in ipairs({ "SetPoint", "SetAllPoints", "ClearAllPoints", "SetScale", "SetParent" }) do
        if sun[method] then hooksecurefunc(sun, method, PlaceSun) end
    end
    MM.sunGuard = CreateFrame("Frame")
    MM.sunGuard:SetScript("OnUpdate", function()
        if not placingSun and SunMoved(sun) then PlaceSun() end
    end)
    PlaceSun()
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

    local size = MAP_SIZE
    MinimapFrame:SetSize(size - 2 * MAP_CROP, size - 2 * MAP_CROP)
    MinimapFrame:ClearAllPoints()
    -- a node addon's scan keeps its offset, so the move it takes back at the end lands home
    MinimapFrame:SetPoint("CENTER", Cluster, "CENTER", Scan.x, Scan.y)
    -- and its empty mask (the map hidden under the cursor) stays until it is home
    if Scan.Busy() then Scan.Later("mask", ApplySquareMap) else ApplySquareMap() end

    -- the Header style (Headerless / Bordered) can change at any time
    if MM.Border and MM.BorderAbove then ApplyBorder(MM.Border, MM.BorderAbove) end
    PlaceHeader()
    PlaceIndicators()
    PlaceCoords()
    PlaceSun()
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

-- FRAMERATE AND LATENCY (11-11 a controller player asked; latency 11-13 Marcus): at the map's bottom
-- right in the coordinates' look, each always or only while pointing at the map (both off by
-- default). One stack from the bottom up: the latency's two lines (world, home over it) and the
-- framerate; the one shown always sits at the bottom, the mouseover one above it, and with both the
-- same the framerate goes above the latency. Updated once a second while shown.
local stats = {}                -- fps, home, world: font strings
local statsTicker
local FPS_INSET = 6             -- in from the coordinates' gap at the corner
local function StatMode(key)
    local db = GetDb()
    local mode = db and db[key]
    return (mode == "always" or mode == "hover") and mode or "off"
end

-- Coordinates (11-11): Off, Always or On Mouseover, one with Blizzard's own option (the
-- minimapShowPlayerCoords CVar): off here turns it off there, and off there reads as Off here.
-- Up to 11-11 a switch (coordsOnHover): off was Always.
local function CoordsCVarOn()
    local value = C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("minimapShowPlayerCoords")
    return value ~= "0"
end
function MM.CoordsMode()
    local db = GetDb()
    if not CoordsCVarOn() then return "off" end
    local mode = db and db.coords
    if mode ~= "always" and mode ~= "hover" then mode = "hover" end
    return mode
end
function MM.SetCoordsMode(mode)
    local db = GetDb()
    if not db then return end
    db.coords = mode
    if C_CVar and C_CVar.SetCVar then pcall(C_CVar.SetCVar, "minimapShowPlayerCoords", mode == "off" and "0" or "1") end
end

-- what pointing at the map shows: the coordinates and the framerate, each set to On Mouseover
local function HoverWanted()
    local db = GetDb()
    return db and (MM.CoordsMode() == "hover" or db.fps == "hover" or db.latency == "hover") or false
end
local function ShowHovered(over)
    ShowCoords(MM.CoordsMode() ~= "hover" or over)
    if stats.fps then stats.fps:SetAlpha((StatMode("fps") ~= "hover" or over) and 1 or 0) end
    local latency = (StatMode("latency") ~= "hover" or over) and 1 or 0
    if stats.home then stats.home:SetAlpha(latency); stats.world:SetAlpha(latency) end
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

local function UpdateStats()
    if stats.fps and stats.fps:IsShown() then stats.fps:SetFormattedText("%.0f fps", GetFramerate()) end
    if stats.home and stats.home:IsShown() then
        local _, _, home, world = GetNetStats()
        stats.home:SetFormattedText("%d (h) ms", home or 0)
        stats.world:SetFormattedText("%d (w) ms", world or 0)
    end
end

local function NewStat(holder)
    local fs = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetJustifyH("RIGHT")
    -- the coordinates' font and gold (their text, else Blizzard's small font a size up)
    local coords = CoordsFrame()
    local source = coords and coords.CoordText
    local font, size, flags = (source or fs):GetFont()
    if font and size then fs:SetFont(font, (source and source.FlareUI_Styled) and size or size + COORDS.FONT_STEP, flags) end
    local c = NORMAL_FONT_COLOR
    fs:SetTextColor(c.r, c.g, c.b)
    local db = GetDb()
    if db and db.infoFont then ApplyFont(fs, db.infoFont) end
    MM.infoTexts[fs] = true
    fs:Hide()
    return fs
end

function MM.SetupFps()
    local fps, latency = StatMode("fps"), StatMode("latency")
    for _, fs in pairs(stats) do fs:Hide() end
    if fps == "off" and latency == "off" then
        if statsTicker then statsTicker:Cancel(); statsTicker = nil end
        UpdateCoordsHover()
        return
    end
    if not stats.fps then
        local holder = CreateFrame("Frame", nil, MM.Frame or MinimapFrame)
        holder:SetAllPoints(MM.Frame or MinimapFrame)
        Raise(holder)
        stats.fps, stats.home, stats.world = NewStat(holder), NewStat(holder), NewStat(holder)
    end
    -- bottom up: the latency's lines (world, then home) and the framerate; the one shown always at
    -- the bottom when the other is On Mouseover
    local order = {}
    local function Latency() order[#order + 1] = stats.world; order[#order + 1] = stats.home end
    if fps ~= "off" and latency ~= "off" then
        if fps == "always" and latency == "hover" then
            order[1] = stats.fps; Latency()
        else
            Latency(); order[#order + 1] = stats.fps
        end
    elseif fps ~= "off" then
        order[1] = stats.fps
    else
        Latency()
    end
    -- the bottom line level with the coordinates' text (their box sits COORDS.GAP up, the text in its
    -- middle), a little in from the corner (11-11, Marcus); each next line a text height above
    local coords = CoordsFrame()
    local mid = COORDS.GAP + ((coords and coords:GetHeight()) or 12) / 2
    local _, size = stats.fps:GetFont()
    local step = math.floor((size or 12) + 2)
    for i, fs in ipairs(order) do
        fs:ClearAllPoints()
        fs:SetPoint("RIGHT", MM.Frame or MinimapFrame, "BOTTOMRIGHT", -(COORDS.GAP + FPS_INSET), mid + (i - 1) * step)
        fs:Show()
    end
    UpdateStats()
    if not statsTicker then statsTicker = C_Timer.NewTicker(1, UpdateStats) end
    UpdateCoordsHover()
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

-- Clicks on the map (11-12, second rework: as before 6.0.3, locked in battlegrounds). A surface of
-- FlareUI's own lies over the map and takes its clicks, so Blizzard's click handler is never replaced,
-- wrapped or hooked:
-- * outside battlegrounds it does what FlareUI always did: the middle button opens the menu (no ping),
--   any other button pings (the square style's corners too; the round map only inside its circle, as
--   Blizzard's own), and the square style zooms with the wheel.
-- * in a battleground it lets every click through (Minimap:PingLocation is protected there, 11-11
--   ADDON_ACTION_BLOCKED in Warsong Gulch): Blizzard's untouched map pings, there is no menu, and the
--   square's corners don't ping. The wheel still zooms.
local surface
local function InBattleground()
    local inInstance, kind = IsInInstance()
    return inInstance and kind == "pvp" or false
end

-- (EnableMouse on FlareUI's own plain frame: allowed in a fight too)
-- 11-13 (the menu still only pinged): the surface sat at the map's own level, so the map took the clicks
-- first. Now it sits well above (as EllesmereUI's middle-click catcher, the idea only) and lets
-- through, to Blizzard's untouched map, every button it doesn't use:
-- * the middle button is the menu's while it's on (in a battleground too: no ping is involved);
-- * the square style takes the left and right buttons outside battlegrounds to ping its corners;
--   the round map and battlegrounds leave them to Blizzard.
-- (SetPassThroughButtons can't change in a fight: the last setting stays until it ends.)
function MM.UpdateMapMouse()
    if not surface then return end
    local db = GetDb()
    local menu = db and db.microMenu and true or false
    local ownPings = squareStyle and not InBattleground()
    surface:EnableMouse(menu or ownPings)
    if surface.SetPassThroughButtons and not InCombatLockdown() then
        local through = { "Button4", "Button5" }
        if not ownPings then through[#through + 1] = "LeftButton"; through[#through + 1] = "RightButton" end
        if not menu then through[#through + 1] = "MiddleButton" end
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
    MM.SetupFps()
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
    if squareStyle then return SQUARE_MASK end
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
Scan.OnEnd = function() SetMask() end

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
    -- (11-13, ForeverFarmHUD: putting rotateMinimap back runs it as the HUD lets go) it also sizes the
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
-- has a new child (a light 2-second count), and after loading screens.
-- 11-11 (a player's report, buttons left out of MinimapButtonButton under the border): buttons on
-- MinimapBackdrop and every LibDBIcon button count too, whatever their parent, and one an addon later
-- sets back under the border (its own level or strata) is lifted again a frame later.
local STRATA_RANK = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6,
    FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
local liftHooked = setmetatable({}, { __mode = "k" })
-- 11-13 (reported a third time): a button hidden when it was checked was skipped and never watched, so
-- one an addon shows later (or makes hidden first) stayed under the border. Hidden ones are lifted and
-- watched too.
-- (11-13 performance pass, a player's "5-second lag splits") map pins are left alone: gathering and
-- quest addons (HereBeDragons) put hundreds or thousands of pins on the map and show / hide them every
-- frame while you move. Each was hooked and re-levelled, and each show started a full pass over every
-- pin. The map draws its children with itself anyway (see LiftMapButtons), so lifting them did nothing.
MM.PIN_LIBS = { "HereBeDragons-Pins-2.0", "HereBeDragons-Pins-1.0" }
function MM.IsMapPin(frame)
    for i = 1, #MM.PIN_LIBS do
        local pins = LibStub and LibStub(MM.PIN_LIBS[i], true)
        if pins and ((pins.minimapPins and pins.minimapPins[frame]) or (pins.activeMinimapPins and pins.activeMinimapPins[frame])) then
            return true
        end
    end
    return false
end
local function LiftButton(child, strata, want)
    if MM.IsMapPin(child) then return end
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

-- 11-13 (a player: the game hangs turning GatherLite's HUD or FarmHud on or off, since 6.1.1): a HUD
-- takes the map, re-parents and re-levels it and every child, and moves hundreds of gathering pins.
-- Each change queued a whole lift pass of its own, and FlareUI pulled the pins back over its border
-- against the HUD. Now one pass waits at most, and nothing here touches the map while it is away from
-- its home (MM.MapAway); it is all put back once when the map comes home (WatchMapHome).
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
    for _, parent in ipairs({ MinimapFrame, _G.MinimapBackdrop }) do
        for _, child in ipairs(parent and { parent:GetChildren() } or {}) do LiftButton(child, strata, want) end
    end
    -- LibDBIcon's buttons (the ones Keep on the Minimap leaves out of the drawer) go a whole strata
    -- above the border: one level above it still left them under its edge (11-11, reported twice).
    -- Other map buttons (gathering pins) stay in the border's strata, under the world map.
    -- 11-13 (/fui mapdebug: BigWigs MEDIUM 8 under the LOW 4 bronze edge): the map draws its children
    -- with itself, whatever their strata, so a border over the map covered them all. Those buttons now
    -- hang on MM.ButtonHolder, above the border, still anchored to the map where LibDBIcon puts them.
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
                LiftButton(button, above, want)
            end
        end
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
            -- (11-13) frames too: some addons make their map button a plain Frame
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

-- Square style: LibDBIcon places every button's centre BUTTON_RADIUS from the map's edge at an angle it
-- saves (never the distance), 5 px outside by default, so on a square map with FlareUI's border its
-- buttons straddle the border and go back there on every reload, wherever they were dragged (11-13,
-- /fui mapdebug: they were above the border all along). LibDBIcon's own SetButtonRadius pulls every
-- button inside the square, the way minimap replacements do; LibDBIcon keeps placing them there.
-- Square style: where LibDBIcon's buttons sit (11-13, after several rounds with Marcus). LibDBIcon places
-- them on a circle (the shape it was told was round), at a saved angle, and the order addons load in
-- changed them on every reload. FlareUI places them itself, every time LibDBIcon does (SetPoint):
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
local function EdgePoint(angle, half)
    local x, y = math.cos(math.rad(angle)), math.sin(math.rad(angle))
    local reach = math.max(math.abs(x), math.abs(y))
    return x / reach * half, y / reach * half
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
    local x, y
    if button.FlareUI_DragAngle then
        -- FlareUI's own button being dragged: the pointer's angle, on the square
        x, y = EdgePoint(button.FlareUI_DragAngle, half)
    elseif button:GetScript("OnUpdate") then
        -- being dragged: LibDBIcon's angle, on the square
        local _, _, _, px, py = button:GetPoint(1)
        if not (px and py) or (px == 0 and py == 0) then return end
        x, y = EdgePoint(math.deg(math.atan2(py, px)), half)
    elseif Spots()[name] then
        x, y = EdgePoint(Spots()[name], half)
    else
        -- packed along the bottom, then up the right side
        local along = STACK.first + (StackIndex(button) - 1) * STACK.step
        if along <= 2 * half then
            x, y = -half + along, -half
        else
            x, y = half, -half + (along - 2 * half)
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

function MM.PullButtonsIn()
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

-- FlareUI's own minimap button (11-13, Marcus; 11-14 its own option): with FlareUI Minimap Button on
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

local function FlareButton()
    if MM.flareButton then return MM.flareButton end
    -- (named ^FlareUI: the drawer never adopts it)
    local b = CreateFrame("Button", "FlareUIMinimapButton", MinimapFrame)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
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
            print("|cff00ccffFlareUI:|r " .. L["Minimap button hidden. Turn it back on in Settings > Minimap > FlareUI Minimap Button."])
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
        -- (11-13, ForeverFarmHUD) a HUD can put its zoom, rotation and other settings back after the
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
    local frame = MM.Border or MM.Frame   -- (the border pieces live on MM.Border since 11-13)
    if not squareStyle then frame = Cluster.MinimapContainer end
    if not frame then return end
    local width
    if squareStyle then
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
    self:UpdateLayout()
    self:UpdateTrackerScale()
    self:ApplyFonts()
    UpdateCoordsHover()
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
-- Nodeworthy: the 11-10 audit) hide or shrink what is on the map while they scan, so quest areas and
-- icons flash, on Blizzard's minimap too. Players blamed FlareUI: a notice, once per account and
-- addon, says whose it is (and the Minimap settings page says so while one is loaded).
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

-- Farming HUDs (11-13, ForeverFarmHUD report) take the real minimap into a big see-through map in
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
    -- Coordinates on Mouseover (a switch up to 11-11) set off: Always
    if db and rawget(db, "coords") == nil and rawget(db, "coordsOnHover") == false then db.coords = "always" end
    if db then db.coordsOnHover = nil end

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
    end
    KeepSunPlaced()   -- both styles
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
    if bag then bag:Init() end
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
-- plate, header row, coordinates style, menu rows), for the settings Info Panel. Blizzard's minimap
-- is never touched: the terrain is a shipped picture and the badge is drawn from its atlases.
-- Kinds: "map" (default) and "menu". The clock's tooltip is Blizzard's (FlareUI only adds lines to
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
    local SAMPLE_X, SAMPLE_Y = 48.2, 36.7
    local OVER_LEVEL = 12      -- badge, coordinates and drawer over both styles' header rows
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
        -- layered as the real map (11-13): the border under the terrain, the pieces that reach over the
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
        -- (11-13) the three cards: Square (Clean) and Square (Header) each with its own top
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
        f.Coords = over:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.Coords:SetJustifyH("CENTER")
        RestyleCoordText(f.Coords)
        local bag = ns.MinimapBag
        if bag and bag.CreateSample then
            f.Drawer = bag.CreateSample(f)
            f.Drawer:SetFrameLevel(f:GetFrameLevel() + OVER_LEVEL)
        end
        return f
    end

    local function CoordsText()
        local tenths = GetCVarBool("coordsByTenths")
        local ok, text
        if tenths then
            ok, text = pcall(string.format, _G.MINIMAP_PLAYER_COORDS or "%.1f, %.1f", SAMPLE_X, SAMPLE_Y)
        else
            ok, text = pcall(string.format, _G.MINIMAP_PLAYER_COORDS_INTEGER or "%d, %d", math.floor(SAMPLE_X + 0.5), math.floor(SAMPLE_Y + 0.5))
        end
        return ok and text or "48, 37"
    end

    local function DrawMap(f)
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
        if f.Coords then ApplyFont(f.Coords, db.infoFont) end
        if square then
            -- the Header style (Headerless / Bordered), as the real map, or the card's own
            local sq = f.Square
            MM.sampleHeader = f.forceHeader
            ApplyBorder(sq.Art, sq.Above)
            MM.PlaceHeaderRow(sq.Art, sq.Tracking, sq.Header, sq.Calendar)
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
            local overhang = SUN_OVERHANG / SUN_SCALE
            badge:SetPoint("BOTTOMLEFT", f.Square.Art, "BOTTOMLEFT", -overhang, -overhang)
        else
            badge:SetScale(1)
            badge:SetPoint("CENTER", f.Round.Box, "CENTER", SUN_ROUND_X, SUN_ROUND_Y)
        end
        badge:SetShown(not EQoLHidesSun())

        -- Blizzard shows coordinates unless its own option is off; FlareUI only on hover with Coordinates on Hover
        local coords = f.Coords
        local cvar = C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("minimapShowPlayerCoords")
        coords:SetShown((db.coords == "always") and cvar ~= "0")
        coords:SetText(CoordsText())
        coords:ClearAllPoints()
        if square then
            coords:SetPoint("BOTTOM", f.Square.Art, "BOTTOM", 0, COORDS.GAP + 1)
        else
            coords:SetPoint("CENTER", f.Round.Terrain, "BOTTOM", 0, -13)
        end

        local base = square and f.Square or f.Round
        local width, height = base:GetSize()
        -- the addon drawer, open under the map
        local drawer = f.Drawer
        local bag = ns.MinimapBag
        if drawer and bag and bag:IsOn() then
            local w, h = bag.DrawSample(drawer)
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

    function MM.DrawSample(f)
        local width, height
        if f.kind == "menu" then
            width, height = f.Menu:GetSize()
        else
            width, height = DrawMap(f)
        end
        f:SetSize(width, height)
        f:Show()
        return width, height
    end
end
