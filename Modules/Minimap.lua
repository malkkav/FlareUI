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

-- The frame's top edge is a title band over the map; the header row is centred in it
local BAND_HEIGHT   = 22     -- title band depth over the map
local HEADER_HEIGHT = 19     -- Forever's header buttons (23 px art), a little smaller
local HEADER_TOP    = 2      -- header row inset from the map's top edge
local HEADER_SIDE   = 6      -- ... and from its sides
local HEADER_GAP    = 2
local CLOCK_WIDTH   = 40
-- Forever's zone plate, stretched along the whole bar with its ends kept whole
local PLATE_ATLAS   = "ui-hud-minimap-header-button"
local PLATE_SLICE   = 12     -- end size, in art pixels
local PLATE_INSET   = 6      -- zone text and clock inset from the plate's ends
local SUN_SCALE     = 0.9    -- day/night badge scale
local SUN_OVERHANG  = 6      -- badge overhang past the map's corner
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
end

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
local function BorderLayout()
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
    return layout
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
    NineSliceUtil.ApplyLayout(frame, BorderLayout())
    MM.Frame = frame

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
-- own plate is a fixed width
local function CreateHeader()
    local header = CreateFrame("Frame", nil, Cluster)
    header:SetHeight(HEADER_HEIGHT)
    header.Plate = header:CreateTexture(nil, "BACKGROUND")
    Plate(header.Plate, header)
    MM.Header = header
    return header
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

local function StyleHeader()
    -- Forever's round art, parked: an alpha of 0 isn't enough, as any addon tinting it with
    -- SetVertexColor sets the alpha too (BetterBlizzFrames does at every login). Kept there if moved.
    local compass = _G.MinimapCompassTexture
    Remove(compass)
    hooksecurefunc(compass, "SetParent", function(self, parent)
        if parent ~= hiddenParent then self:SetParent(hiddenParent) end
    end)
    -- Forever's skin shows a round underlay whenever rotateMinimap is on
    Remove(_G.MinimapCompassTextureUnderlay)
    Remove(MinimapFrame.ZoomIn)
    Remove(MinimapFrame.ZoomOut)
    Remove(MinimapFrame.ZoomHitArea)
    if _G.MinimapBackdrop then Remove(_G.MinimapBackdrop.StaticOverlayTexture) end

    local header = CreateHeader()
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
            local width = math.max(CLOCK_WIDTH, math.ceil(ticker:GetUnboundedStringWidth() or 0) + 2 + PLATE_INSET)
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

-- Tracking, the zone / clock bar and the calendar, left to right
local function PlaceHeader()
    local tracking, calendar, header = Cluster.Tracking, _G.GameTimeFrame, MM.Header
    tracking:ClearAllPoints()
    calendar:ClearAllPoints()
    header:ClearAllPoints()
    tracking:SetPoint("TOPLEFT", MM.Frame, "TOPLEFT", HEADER_SIDE, -HEADER_TOP)
    header:SetPoint("LEFT", tracking, "RIGHT", HEADER_GAP, 0)
    header:SetWidth(MAP_SIZE - 2 * HEADER_SIDE - tracking:GetWidth() - calendar:GetWidth() - 2 * HEADER_GAP)
    calendar:SetPoint("LEFT", header, "RIGHT", HEADER_GAP, 0)
    PlaceZone()
end

-- Mail and similar indicators: top-left, just below the title band
local function PlaceIndicators()
    local indicators = Cluster.IndicatorFrame
    Raise(indicators)
    indicators:ClearAllPoints()
    indicators:SetPoint("TOPLEFT", MM.Frame, "TOPLEFT", HEADER_SIDE, -(BAND_HEIGHT + MAIL_GAP))
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
    local size = text and select(2, text:GetFont()) or 10
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
    if not self.initialized then return end
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

local function UpdateCoordsHover()
    local db = GetDb()
    if not (db and db.coordsOnHover) then
        if hoverTicker then hoverTicker:Cancel(); hoverTicker = nil end
        ShowCoords(true)
        return
    end
    -- mid-scan the coordinates are the scan's to hide (Lueur puts back what it found at the end)
    if Scan.Busy() then return end
    local over = Cluster:IsMouseOver()
    ShowCoords(over)
    if not over and hoverTicker then hoverTicker:Cancel(); hoverTicker = nil end
end

local function OnMapEnter()
    local db = GetDb()
    if not (db and db.coordsOnHover) then return end
    -- the hidden map slid under the pointer by a node addon's scan is not the player pointing at it
    if Scan.Busy() or not Cluster:IsMouseOver() then return end
    ShowCoords(true)
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

local function BuildMenu()
    local panels = ns.RadialMenu and ns.RadialMenu.MICRO_PANELS
    if not panels then return nil end
    local f = CreateFrame("Frame", "FlareUI_MinimapMenu", UIParent, "BackdropTemplate")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
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
            local b = CreateFrame("Button", nil, f, "SecureActionButtonTemplate")
            b:SetHeight(MENU_ROW)
            b:SetPoint("TOPLEFT", f, "TOPLEFT", MENU_PAD, -MENU_PAD - (n - 1) * MENU_ROW)
            b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -MENU_PAD, -MENU_PAD - (n - 1) * MENU_ROW)
            b:RegisterForClicks("AnyUp", "AnyDown")
            b:SetAttribute("type", "macro")
            b:SetAttribute("macrotext", (p.button and _G[p.button]) and ("/click " .. p.button) or p.macrotext)
            local icon = b:CreateTexture(nil, "ARTWORK")
            icon:SetSize(16, 16)
            icon:SetPoint("LEFT", 2, 0)
            icon:SetTexture(p.icon or 134400)
            local text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            text:SetPoint("LEFT", icon, "RIGHT", 6, 0)
            text:SetText(p.label)
            width = math.max(width, text:GetStringWidth() + 28)
            local hl = b:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.08)
            b:HookScript("PostClick", function() C_Timer.After(0, HideMenu) end)
        end
    end
    f:SetSize(width + 2 * MENU_PAD, n * MENU_ROW + 2 * MENU_PAD)
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

-- Square style: one surface over the whole square, so the corners zoom and ping too (Blizzard pings
-- only inside the round map it draws); the middle button opens the menu
local function CreateMapSurface()
    local surface = CreateFrame("Frame", nil, MinimapFrame)
    surface:SetAllPoints(MinimapFrame)
    surface:SetFrameLevel(MinimapFrame:GetFrameLevel())   -- under the buttons and pins on the map
    surface:EnableMouse(true)
    surface:EnableMouseWheel(true)
    -- clicks and the wheel only: the pointer's hover stays the map's own, as the game's dot tooltip
    -- and node addons (Gathercraft reads the mouse focus) need
    if surface.SetMouseMotionEnabled then surface:SetMouseMotionEnabled(false) end
    if surface.SetPropagateMouseMotion then surface:SetPropagateMouseMotion(true) end
    -- a node addon's scan holds the hidden map under the pointer: the wheel goes to the camera
    Scan.OnChange = function(busy) surface:EnableMouseWheel(not busy) end
    surface:SetScript("OnMouseWheel", function(_, delta)
        if delta > 0 then Minimap_ZoomIn() elseif delta < 0 then Minimap_ZoomOut() end
    end)
    surface:SetScript("OnMouseUp", function(_, button)
        if button == "MiddleButton" then ToggleMenu() return end
        if button ~= "LeftButton" then return end
        local x, y = GetCursorPosition()
        local scale = MinimapFrame:GetEffectiveScale()
        local cx, cy = MinimapFrame:GetCenter()
        if not cx then return end
        pcall(MinimapFrame.PingLocation, MinimapFrame, x / scale - cx, y / scale - cy)
    end)
end

-- Blizzard's map pings on any button (Minimap:OnClick on OnMouseUp), and clicks can land on it rather
-- than the square surface, so its handler is wrapped: the middle button opens the menu instead of
-- pinging while Middle-click Menu is on. The map is not a protected frame.
local function WrapMapClick()
    local blizzard = MinimapFrame:GetScript("OnMouseUp")
    MinimapFrame:SetScript("OnMouseUp", function(self, button, ...)
        local db = GetDb()
        if button == "MiddleButton" and db and db.microMenu then ToggleMenu() return end
        if blizzard then return blizzard(self, button, ...) end
    end)
end

local function SetupMapMouse()
    if squareStyle then CreateMapSurface() end
    WrapMapClick()
    MinimapFrame:HookScript("OnEnter", OnMapEnter)
    Cluster:HookScript("OnEnter", OnMapEnter)
    UpdateCoordsHover()
end

local function AddEditModeSettings()
    if ns.Visibility then LEM:AddSystemSettings(Enum.EditModeSystem.Minimap, ns.Visibility:MinimapSettings()) end
end

-- The square map can't rotate: rotateMinimap goes off at load and whenever a layout sets it
local function KeepMapUnrotated()
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
    if Cluster.UpdateMinimapConfig then hooksecurefunc(Cluster, "UpdateMinimapConfig", PlaceZone) end
    hooksecurefunc("MiniMapIndicatorFrame_UpdatePosition", PlaceIndicators)
end

-- Square style: addon buttons on the map. They are the map's children at its level + 1 unless they
-- set their own (LibDBIcon's sit in MEDIUM), so the square border, two above the map, drew over the
-- ones on its edge. Any Button child of the map at or under the border goes one above it; the border
-- keeps its level over the map. Addons add buttons whenever they like: checked again whenever the map
-- has a new child (a light 2-second count), and after loading screens.
function MM.LiftMapButtons()
    local art = MM.Frame
    if not art then return end
    local want = MinimapFrame:GetFrameLevel() + 2
    if art:GetFrameLevel() ~= want then art:SetFrameLevel(want) end
    local strata = art:GetFrameStrata()
    for _, child in ipairs({ MinimapFrame:GetChildren() }) do
        if child.IsObjectType and child:IsObjectType("Button") and not (child.IsForbidden and child:IsForbidden())
                and not (InCombatLockdown() and child:IsProtected())
                and child:GetFrameStrata() == strata and child:GetFrameLevel() <= want then
            child:SetFrameLevel(want + 1)
        end
    end
end

local function WatchMapButtons()
    MM.LiftMapButtons()
    MM.mapChildren = MinimapFrame:GetNumChildren()
    C_Timer.NewTicker(2, function()
        local count = MinimapFrame:GetNumChildren()
        if count ~= MM.mapChildren then
            MM.mapChildren = count
            MM.LiftMapButtons()
        end
    end)
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:SetScript("OnEvent", function() C_Timer.After(1, MM.LiftMapButtons) end)
end

local function InitSquare()
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
        local leftEdge, rightEdge, topEdge, bottomEdge = art and art.LeftEdge, art and art.RightEdge, art and art.TopEdge, art and art.BottomEdge
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
    local frame = MM.Frame
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

function MM:Init()
    if self.initialized then return end
    EventUtil.ContinueOnAddOnLoaded("Blizzard_BattlefieldMap", SkinZoneMap)
    if not (MinimapFrame and Cluster and Cluster.ZoneTextButton and Cluster.Tracking and Cluster.MinimapContainer and _G.GameTimeFrame) then
        print("|cffff0000FlareUI:|r Minimap module could not find the Blizzard minimap cluster.")
        return
    end
    local db = GetDb()
    squareStyle = not db or db.style ~= "round"

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
end
