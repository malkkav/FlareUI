local _, ns = ...
local L = ns.L

--------------------------------------------------
-- MINIMAP
-- A square minimap in Blizzard's panel frame art (the AddOn List's NineSlice layout). The header
-- (tracking, zone, clock, calendar) runs inside the map along its top; the day/night badge sits on
-- the bottom-left corner. Edit Mode's Size setting scales the whole frame.
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
local table_remove = table.remove
local hooksecurefunc = hooksecurefunc
local C_Timer = C_Timer

-- Blizzard's frames. "Minimap" is a global, so the module table and the frame keep separate names.
local MinimapFrame = _G.Minimap
local Cluster = _G.MinimapCluster

--------------------------------------------------
-- 3. CONSTANTS
--------------------------------------------------
local MAP_SIZE      = 244                           -- the square map
local FRAME_PAD     = 8                             -- room around the map for the frame art
local CLUSTER_SIZE  = MAP_SIZE + 2 * FRAME_PAD      -- 260
local BORDER_LAYOUT = "ButtonFrameTemplateNoPortrait"   -- Blizzard NineSlice layout (AddOn List frame)
local LEFT_SHIFT    = -6     -- the layout sits further in on the left
-- the border art's transparent shadow outside its gold line, per side (measured in game)
local BORDER_SHADOW = { left = 10, top = 11, right = 4, bottom = 5 }
local SQUARE_MASK   = "Interface\\BUTTONS\\WHITE8X8"

-- The frame's top edge is a title band over the map; the header row is centred in it
local BAND_HEIGHT   = 22     -- how far the title band reaches down over the map
local HEADER_HEIGHT = 19     -- Forever's header buttons (23 px art) drawn a little smaller
local HEADER_TOP    = 2      -- the header row's distance from the map's top edge
local HEADER_SIDE   = 6      -- ... and from its side edges
local HEADER_GAP    = 2      -- between the pieces of the header row
local CLOCK_WIDTH   = 40
-- Forever's zone plate, stretched along the whole bar: its rounded ends keep their size
local PLATE_ATLAS   = "ui-hud-minimap-header-button"
local PLATE_SLICE   = 12     -- the ends, in the art's pixels
local PLATE_INSET   = 6      -- zone text and clock, in from the plate's ends
local SUN_SCALE     = 0.9    -- Forever's day/night badge, a little under its own size
local SUN_OVERHANG  = 6      -- how far the badge reaches past the map's corner, onto the frame
local MAIL_GAP      = 3      -- between the title band and the mail icon
-- Blizzard's player coordinates: a size up, in gold, clear of the frame art along the bottom edge
local COORDS = {
    GAP = 8,             -- map's bottom edge to the bottom of the text
    FONT_STEP = 1,       -- points added to Blizzard's font
    MAP_LIFT = 5,        -- the world map's coordinates, raised this much off its edge
}
local ROW_LEVEL     = 5      -- header row above the map and its frame

--------------------------------------------------
-- 4. HELPERS
--------------------------------------------------
local function GetDb()
    return ns.db and ns.db.profile and ns.db.profile.minimap
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
-- Other addons (LibDBIcon buttons, for one) ask this global which shape to follow
local function MinimapShape() return "SQUARE" end

local function SquareHybridMinimap()
    local hybrid = _G.HybridMinimap
    if not hybrid then return end
    hybrid.CircleMask:SetTexture(SQUARE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    hybrid.MapCanvas:SetMaskTexture(hybrid.CircleMask)
end

-- A copy of Blizzard's layout (pieces are flat tables), its left side moved out to the map's edge
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
    -- Blizzard's panel frame, built from its NineSlice layout, just above the map
    local frame = CreateFrame("Frame", nil, MinimapFrame)
    frame:SetAllPoints(MinimapFrame)
    frame:SetFrameLevel(MinimapFrame:GetFrameLevel() + 2)
    NineSliceUtil.ApplyLayout(frame, BorderLayout())
    MM.Frame = frame

    -- black under the map, for wherever the map texture has no data
    local back = Cluster:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints(MinimapFrame)
    back:SetColorTexture(0, 0, 0, 1)
end

local function ApplySquareMap()
    MinimapFrame:SetMaskTexture(SQUARE_MASK)
    MinimapFrame:SetArchBlobRingScalar(0)
    MinimapFrame:SetQuestBlobRingScalar(0)
    MinimapFrame:SetTaskBlobRingScalar(0)
    _G.GetMinimapShape = MinimapShape
    SquareHybridMinimap()
end

--------------------------------------------------
-- 6. HEADER, INDICATORS AND BADGES
--------------------------------------------------
-- Forever's header buttons (since the 2026-10-16 build) draw their own art at its atlas size, again
-- on every mouse state: fitted to the button instead (two anchors outrank the size)
local function FitButtonArt(button)
    for _, key in ipairs({ "StateTexture", "AddTexture" }) do
        local texture = button and button[key]
        if texture then
            texture:ClearAllPoints()
            texture:SetAllPoints(button)
        end
    end
end

-- A texture stretched over a frame with Forever's zone plate, its ends kept whole
local function Plate(texture, frame)
    texture:SetAtlas(PLATE_ATLAS)
    texture:ClearAllPoints()
    texture:SetAllPoints(frame)
    if texture.SetTextureSliceMargins then
        texture:SetTextureSliceMargins(PLATE_SLICE, PLATE_SLICE, PLATE_SLICE, PLATE_SLICE)
        if Enum.UITextureSliceMode then texture:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched) end
    end
end

-- The bar behind the zone text and clock: Forever's zone plate, one level under the text. (Blizzard's
-- BorderTop is gone from Forever's cluster, and the zone button's own plate is a fixed width.)
local function CreateHeader()
    local header = CreateFrame("Frame", nil, Cluster)
    header:SetHeight(HEADER_HEIGHT)
    header.Plate = header:CreateTexture(nil, "BACKGROUND")
    Plate(header.Plate, header)
    MM.Header = header
    return header
end

-- The zone text button: the bar up to the clock. Forever's cluster re-places it itself (header
-- underneath, Edit Mode), so every layout pass puts it back.
local clockWidth = CLOCK_WIDTH
local function PlaceZone()
    local zoneButton, header = Cluster.ZoneTextButton, MM.Header
    zoneButton:ClearAllPoints()
    zoneButton:SetPoint("TOPLEFT", header, "TOPLEFT", HEADER_GAP, 0)
    zoneButton:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -clockWidth, 0)
    Raise(zoneButton)
end

local function StyleHeader()
    _G.MinimapCompassTexture:SetAlpha(0)   -- Blizzard's round frame art
    -- Forever's skin shows a round underlay whenever rotateMinimap is on
    Remove(_G.MinimapCompassTextureUnderlay)
    Remove(MinimapFrame.ZoomIn)
    Remove(MinimapFrame.ZoomOut)
    Remove(MinimapFrame.ZoomHitArea)
    if _G.MinimapBackdrop then Remove(_G.MinimapBackdrop.StaticOverlayTexture) end

    local header = CreateHeader()
    for _, frame in ipairs({ Cluster.ZoneTextButton, Cluster.Tracking, _G.GameTimeFrame }) do Raise(frame) end
    Raise(header, -1)

    -- tracking and calendar: Forever's own buttons, squares as tall as the header
    local tracking = Cluster.Tracking
    tracking:SetSize(HEADER_HEIGHT, HEADER_HEIGHT)
    if tracking.Background then tracking.Background:Hide() end   -- the button art has its own frame
    tracking.Button:ClearAllPoints()
    tracking.Button:SetAllPoints(tracking)
    FitButtonArt(tracking.Button)
    local calendar = _G.GameTimeFrame
    calendar:SetSize(HEADER_HEIGHT, HEADER_HEIGHT)
    FitButtonArt(calendar)

    -- zone text: the bar up to the clock. Its plate is the header's; the button's mouse-over glow
    -- spreads over the whole plate
    local zoneButton, zoneText = Cluster.ZoneTextButton, _G.MinimapZoneText
    if zoneButton.StateTexture then zoneButton.StateTexture:SetParent(hiddenParent) end
    if zoneButton.AddTexture then Plate(zoneButton.AddTexture, header) end
    PlaceZone()
    zoneText:ClearAllPoints()
    zoneText:SetPoint("TOPLEFT", zoneButton, "TOPLEFT", PLATE_INSET, 0)
    zoneText:SetPoint("BOTTOMRIGHT", zoneButton, "BOTTOMRIGHT", 0, 0)
    zoneText:SetJustifyH("LEFT")
    zoneText:SetWordWrap(false)

    -- clock: the bar's right end, its whole button answering the mouse; it grows with the time text,
    -- taking the width from the zone text
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
        FitClock()
    end)
end

-- Tracking, the zone / clock bar and the calendar, left to right on one middle line
local function PlaceHeader()
    local tracking, calendar, header = Cluster.Tracking, _G.GameTimeFrame, MM.Header
    tracking:ClearAllPoints()
    calendar:ClearAllPoints()
    header:ClearAllPoints()
    tracking:SetPoint("TOPLEFT", MinimapFrame, "TOPLEFT", HEADER_SIDE, -HEADER_TOP)
    header:SetPoint("LEFT", tracking, "RIGHT", HEADER_GAP, 0)
    header:SetWidth(MAP_SIZE - 2 * HEADER_SIDE - tracking:GetWidth() - calendar:GetWidth() - 2 * HEADER_GAP)
    calendar:SetPoint("LEFT", header, "RIGHT", HEADER_GAP, 0)
    PlaceZone()
end

-- Mail and similar indicators: the map's top-left corner, a little below the title band
local function PlaceIndicators()
    local indicators = Cluster.IndicatorFrame
    Raise(indicators)
    indicators:ClearAllPoints()
    indicators:SetPoint("TOPLEFT", MinimapFrame, "TOPLEFT", HEADER_SIDE, -(BAND_HEIGHT + MAIL_GAP))
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

local function PlaceCoords()
    local coords = Cluster.MinimapContainer and Cluster.MinimapContainer.PlayerCoords
    if not coords then return end
    local text = coords.CoordText
    Raise(coords)
    RestyleCoordText(text)
    local size = text and select(2, text:GetFont()) or 10
    coords:SetHeight(size + 2)
    coords:ClearAllPoints()
    coords:SetPoint("BOTTOM", MinimapFrame, "BOTTOM", 0, COORDS.GAP)
end

-- The world map's coordinates: the same font and gold, lifted off the map's edge. A single anchor
-- per label, so the bigger font is not cut by its 100 px frame.
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

-- Forever's day/night badge in the map's bottom-left corner, always shown
local function PlaceSun()
    local sun = Cluster.DielFrame
    if not sun then return end
    sun:Show()   -- also the Addon Button Bag's button (MinimapBag.lua)
    sun:SetScale(SUN_SCALE)
    sun:ClearAllPoints()
    local overhang = SUN_OVERHANG / SUN_SCALE   -- offsets are in the badge's own, scaled units
    sun:SetPoint("BOTTOMLEFT", MinimapFrame, "BOTTOMLEFT", -overhang, -overhang)
    Raise(sun, 1)
end

--------------------------------------------------
-- 7. LAYOUT
--------------------------------------------------
-- The layout is built at one fixed size and Edit Mode's Size scales the whole cluster, so every
-- piece keeps its place on the frame art
local sizingCluster = false
local function SizeCluster()
    if sizingCluster then return end
    sizingCluster = true
    Cluster:SetSize(CLUSTER_SIZE, CLUSTER_SIZE)
    sizingCluster = false
end

-- Edit Mode's Size setting (50-200%), 100% before Edit Mode has it
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
    Cluster.MinimapContainer:SetScale(1)
    Cluster.ZoneTextButton:SetScale(1)
    SizeCluster()
    -- Edit Mode's SetScale on a system frame moves it so it stays in place on screen
    local scale = EditModeSize()
    if math.abs(Cluster:GetScale() - scale) > 0.001 then ns.SetSystemScale(Cluster, scale) end

    MinimapFrame:SetSize(MAP_SIZE, MAP_SIZE)
    MinimapFrame:ClearAllPoints()
    MinimapFrame:SetPoint("CENTER", Cluster, "CENTER", 0, 0)
    ApplySquareMap()

    PlaceHeader()
    PlaceIndicators()
    PlaceCoords()
    PlaceSun()
end

--------------------------------------------------
-- 8. EDIT MODE
-- Rotate Minimap and Header Underneath do not apply and leave the dialog; a stored value is
-- harmless, as the layout is re-applied after Blizzard's.
--------------------------------------------------
local function RemoveEditModeSettings()
    local removed = {
        [Enum.EditModeMinimapSetting.RotateMinimap] = true,
        [Enum.EditModeMinimapSetting.HeaderUnderneath] = true,
    }
    -- never rewrite saved layouts: addon-written layout tables taint Edit Mode's data
    local byId = EditModeSettingDisplayInfoManager and EditModeSettingDisplayInfoManager.systemSettingDisplayInfo
    local displayInfo = byId and byId[Enum.EditModeSystem.Minimap]
    if not displayInfo then return end
    for i = #displayInfo, 1, -1 do
        if removed[displayInfo[i].setting] then table_remove(displayInfo, i) end
    end
end

-- The square map cannot rotate: the rotateMinimap CVar goes off at load and whenever a layout sets it
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
        zoomTimer = C_Timer.NewTimer(delay, function() MinimapFrame:SetZoom(0) end)
    end
end

-- Forever's skin puts its round mask back each time rotateMinimap changes
local maskGuard = false
local function KeepSquareMask(_, texture)
    if maskGuard or texture == SQUARE_MASK then return end
    maskGuard = true
    MinimapFrame:SetMaskTexture(SQUARE_MASK)
    maskGuard = false
end

local function InstallHooks()
    hooksecurefunc(Cluster, "SetSize", SizeCluster)
    hooksecurefunc(MinimapFrame, "SetMaskTexture", KeepSquareMask)
    -- both re-place pieces from Blizzard's layout; ours goes back on after them
    hooksecurefunc(Cluster, "SetEditModeScale", function()
        MM:UpdateLayout()
        MM:UpdateTrackerScale()   -- Blizzard's tracker follows the new width
    end)
    hooksecurefunc(Cluster, "SetHeaderUnderneath", function() MM:UpdateLayout() end)
    -- Forever's config pass (rotateMinimap, layout) drops the zone button to its own frame level
    if Cluster.UpdateMinimapConfig then hooksecurefunc(Cluster, "UpdateMinimapConfig", PlaceZone) end
    hooksecurefunc("MiniMapIndicatorFrame_UpdatePosition", PlaceIndicators)
    hooksecurefunc(MinimapFrame, "SetZoom", OnZoom)
    if not _G.HybridMinimap then
        EventUtil.ContinueOnAddOnLoaded("Blizzard_HybridMinimap", SquareHybridMinimap)
    end
end

--------------------------------------------------
-- 10. OBJECTIVE TRACKER SCALE
-- Blizzard's tracker is scaled so its header lines (about 288 px of the 300 px art shows) are as
-- wide as the minimap frame.
--------------------------------------------------
local TRACKER_LINE_WIDTH = 288

-- The minimap frame's outer width, in the tracker's parent's units
local function FrameOuterWidth(tracker)
    local frame = MM.Frame
    local left = frame and frame.TopLeftCorner and frame.TopLeftCorner:GetLeft()
    local right = frame and frame.TopRightCorner and frame.TopRightCorner:GetRight()
    if not (left and right) then return nil end
    return (right - left) * frame:GetEffectiveScale() / tracker:GetParent():GetEffectiveScale()
end

-- ns.SetSystemScale, not Edit Mode's SetScale (whose re-layout would run tainted); out of combat
local trackerScaleWaiter
function MM:UpdateTrackerScale()
    local tracker = _G.ObjectiveTrackerFrame
    if not (tracker and GetDb()) then return end
    -- FlareUI's Quest Tracker parks Blizzard's
    local own = ns.db.profile.objectivetracker
    if own and own.enabled then return end
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
    ns.SetSystemScale(tracker, width and width / TRACKER_LINE_WIDTH or 1)
end

--------------------------------------------------
-- 11. PUBLIC
--------------------------------------------------
-- FPS and latency in the clock's tooltip (rebuilt by Blizzard every second; the function is shared,
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
end

function MM:Init()
    if self.initialized then return end
    hooksecurefunc("GameTime_UpdateTooltip", AddClockStats)
    -- filled on enter, not on Blizzard's next one-second tick
    EventUtil.ContinueOnAddOnLoaded("Blizzard_TimeManager", function()
        local clock = _G.TimeManagerClockButton
        if clock then clock:HookScript("OnEnter", function() TimeManagerClockButton_UpdateTooltip() end) end
    end)
    if not (MinimapFrame and Cluster and Cluster.ZoneTextButton and Cluster.Tracking and Cluster.MinimapContainer and _G.GameTimeFrame) then
        print("|cffff0000FlareUI:|r Minimap module could not find the Blizzard minimap cluster.")
        return
    end

    RemoveEditModeSettings()
    KeepMapUnrotated()
    if Cluster.SetRotateMinimap then hooksecurefunc(Cluster, "SetRotateMinimap", KeepMapUnrotated) end
    -- Blizzard's addon drawer has no place here (Blizzard re-shows it from UpdateDisplay)
    local drawer = _G.AddonCompartmentFrame
    if drawer then
        hooksecurefunc(drawer, "UpdateDisplay", drawer.Hide)
        drawer:Hide()
    end
    CreateMapArt()
    StyleHeader()
    InstallHooks()
    -- Edit Mode's box on the border art, which keeps it on screen and lets it sit flush with the
    -- edges: the art's four edge strips, less the transparent shadow they carry outside the gold line
    ns.FitEditModeBox(Cluster, function()
        local art = MM.Frame
        local leftEdge, rightEdge, topEdge, bottomEdge = art and art.LeftEdge, art and art.RightEdge, art and art.TopEdge, art and art.BottomEdge
        if not (art and art:GetLeft() and leftEdge and rightEdge and topEdge and bottomEdge and leftEdge:GetLeft()) then return nil end
        local cut = BORDER_SHADOW
        return art, leftEdge:GetLeft() + cut.left - art:GetLeft(), topEdge:GetTop() - cut.top - art:GetTop(),
            rightEdge:GetRight() - cut.right - art:GetRight(), bottomEdge:GetBottom() + cut.bottom - art:GetBottom()
    end)
    self.initialized = true
    if ns.MinimapBag then ns.MinimapBag:Init() end

    EventUtil.ContinueOnAddOnLoaded("Blizzard_ObjectiveTracker", function() self:UpdateTrackerScale() end)
    EventUtil.ContinueOnAddOnLoaded("Blizzard_WorldMap", RestyleWorldMapCoords)
    self:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED", "Refresh")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "Refresh")

    self:Refresh()
    -- the frame's corners only have positions after the first layout pass
    C_Timer.After(0, function() self:Refresh() end)
end
