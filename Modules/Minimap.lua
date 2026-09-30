local _, ns = ...

--------------------------------------------------
-- 1. MODULE REGISTRATION
-- A square minimap dressed in Blizzard's own art: the metal frame of the game's panels (the AddOn
-- List's NineSlice layout) around it, Blizzard's instance difficulty banner and Forever's day/night
-- badge. The header - tracking, zone text, clock and calendar - runs inside the map along its top,
-- and the day/night badge sits on the bottom-left corner. The size is fixed; Edit Mode still places it.
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
local LEFT_SHIFT    = -6     -- that layout sits further in on the left; pull its left side out to the map edge
local SQUARE_MASK   = "Interface\\BUTTONS\\WHITE8X8"

-- The frame's top edge is a title band drawn over the top of the map; the header row is centred in
-- it, and anything hanging into the map starts below it.
local BAND_HEIGHT   = 22     -- how far the title band reaches down over the map
local HEADER_HEIGHT = 17
local HEADER_TOP    = 2      -- the header row's distance from the map's top edge
local HEADER_SIDE   = 6      -- ... and from its side edges
local HEADER_GAP    = 2      -- between the pieces of the header row
local CLOCK_WIDTH   = 40
local CALENDAR_DROP = 1      -- the calendar icon sits this much below the row's middle line
local SUN_SCALE     = 0.9    -- Forever's day/night badge, a little under its own size
local SUN_OVERHANG  = 6      -- how far the badge reaches past the map's bottom-left corner, onto the frame
local MAIL_GAP      = 3      -- between the title band and the mail icon
local COORDS_INSET  = 6      -- player coordinates, along the bottom edge
local ROW_LEVEL     = 5      -- header row above the map and its frame

-- Difficulty banner colours by group size: muted, so the number on the banner stays readable
local BANNER_COLORS = {
    { size = 5,  color = { 0.30, 0.62, 0.34 } },   -- dungeon: green
    { size = 10, color = { 0.30, 0.48, 0.78 } },   -- 10-man: blue
    { size = 25, color = { 0.56, 0.38, 0.76 } },   -- 25-man: purple
    { size = 40, color = { 0.76, 0.30, 0.28 } },   -- 40-man: red
}

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

-- Blizzard's layout as Camelot adjusted it (a copy, one level deep: pieces are flat tables), with
-- its left side moved out to the map's edge
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
local function StyleHeader()
    _G.MinimapCompassTexture:SetAlpha(0)   -- Blizzard's round frame art
    Remove(MinimapFrame.ZoomIn)
    Remove(MinimapFrame.ZoomOut)
    Remove(MinimapFrame.ZoomHitArea)
    if _G.MinimapBackdrop then Remove(_G.MinimapBackdrop.StaticOverlayTexture) end

    local header = Cluster.BorderTop
    header:SetHeight(HEADER_HEIGHT)
    for _, frame in ipairs({ header, Cluster.ZoneTextButton, Cluster.Tracking, _G.GameTimeFrame }) do Raise(frame) end

    -- tracking: a square as tall as the header, its icon centred in it
    local tracking = Cluster.Tracking
    tracking:SetSize(HEADER_HEIGHT, HEADER_HEIGHT)
    tracking.Button:ClearAllPoints()
    tracking.Button:SetPoint("CENTER", tracking, "CENTER", 0, 0)
    tracking.Button:SetSize(HEADER_HEIGHT - 2, HEADER_HEIGHT - 2)

    -- zone text: the bar up to the clock at its right end
    local zoneButton, zoneText = Cluster.ZoneTextButton, _G.MinimapZoneText
    zoneButton:ClearAllPoints()
    zoneButton:SetPoint("TOPLEFT", header, "TOPLEFT", HEADER_GAP, 0)
    zoneButton:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -CLOCK_WIDTH, 0)
    zoneText:ClearAllPoints()
    zoneText:SetAllPoints(zoneButton)
    zoneText:SetJustifyH("LEFT")
    zoneText:SetWordWrap(false)

    -- clock: the bar's right end, next to the calendar; Blizzard's white text. The whole button
    -- answers the mouse (Blizzard's XML insets its hit area by 8/5/3/3 px, which on this small
    -- button left a spot in the middle), and it grows with the time text ("12:00 PM" is wider than
    -- CLOCK_WIDTH), taking the width from the zone text, so no part of the time sits over the zone
    -- button and shows its tooltip instead.
    EventUtil.ContinueOnAddOnLoaded("Blizzard_TimeManager", function()
        local clock, ticker = _G.TimeManagerClockButton, _G.TimeManagerClockTicker
        if not clock then return end
        clock:ClearAllPoints()
        clock:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, 0)
        clock:SetSize(CLOCK_WIDTH, HEADER_HEIGHT)
        clock:SetHitRectInsets(0, 0, 0, 0)
        Raise(clock)
        ticker:ClearAllPoints()
        ticker:SetPoint("RIGHT", clock, "RIGHT", 0, 0)
        ticker:SetFontObject("GameFontHighlight")

        local function FitClock()
            local width = math.max(CLOCK_WIDTH, math.ceil(ticker:GetUnboundedStringWidth()) + 2)
            if width == clock:GetWidth() then return end
            clock:SetWidth(width)
            zoneButton:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -width, 0)
        end
        hooksecurefunc("TimeManagerClockButton_Update", FitClock)
        FitClock()
    end)
end

-- Tracking, the zone / clock bar and the calendar, left to right, in the title band. The bar is
-- centred on the tracking button and sized to fill what the two buttons leave, so the whole row
-- shares one middle line; the calendar sits a touch below it.
local function PlaceHeader()
    local tracking, calendar, header = Cluster.Tracking, _G.GameTimeFrame, Cluster.BorderTop
    tracking:ClearAllPoints()
    calendar:ClearAllPoints()
    header:ClearAllPoints()
    tracking:SetPoint("TOPLEFT", MinimapFrame, "TOPLEFT", HEADER_SIDE, -HEADER_TOP)
    header:SetPoint("LEFT", tracking, "RIGHT", HEADER_GAP, 0)
    header:SetWidth(MAP_SIZE - 2 * HEADER_SIDE - tracking:GetWidth() - calendar:GetWidth() - 2 * HEADER_GAP)
    calendar:SetPoint("LEFT", header, "RIGHT", HEADER_GAP, -CALENDAR_DROP)
end

-- Blizzard's difficulty banner, in the map's top-right corner just below the title band
local function PlaceFlag()
    local flag = Cluster.InstanceDifficulty
    if not flag then return end
    flag:SetFlipped(false)
    flag:ClearAllPoints()
    flag:SetPoint("TOPRIGHT", MinimapFrame, "TOPRIGHT", -HEADER_SIDE, -BAND_HEIGHT)
    Raise(flag)
end

-- Mail and similar indicators: the map's top-left corner, a little below the title band
local function PlaceIndicators()
    local indicators = Cluster.IndicatorFrame
    Raise(indicators)
    indicators:ClearAllPoints()
    indicators:SetPoint("TOPLEFT", MinimapFrame, "TOPLEFT", HEADER_SIDE, -(BAND_HEIGHT + MAIL_GAP))
end

-- The normal banner filled in for a group size - what Blizzard shows outside guild groups
local function FillDefaultBanner(flag, groupSize)
    local banner = flag.Default
    flag:SetInstanceFrameText(banner, groupSize, groupSize)
    local texture = flag:GetDifficultyTexture(banner, false, false, false, false)
    for _, t in ipairs(banner.DifficultyTextures) do t:SetShown(t == texture) end
    banner:Layout()
    for _, frame in ipairs(flag.ContentModes) do frame:SetShown(frame == banner) end
end

local function BannerColor(groupSize)
    for _, entry in ipairs(BANNER_COLORS) do
        if groupSize <= entry.size then return entry.color end
    end
    return BANNER_COLORS[#BANNER_COLORS].color
end

-- After each of Blizzard's updates: the guild banner is swapped for the normal one, and the banner
-- cloth is tinted by group size
local function DressBanner(flag)
    local _, _, _, _, maxPlayers = GetInstanceInfo()
    local groupSize = maxPlayers or 5
    if flag.Guild:IsShown() then FillDefaultBanner(flag, groupSize) end
    local color = BannerColor(groupSize)
    flag.Default.Background:SetDesaturated(true)
    flag.Default.Background:SetVertexColor(color[1], color[2], color[3])
end

-- Blizzard's player coordinates, along the bottom edge
local function PlaceCoords()
    local coords = Cluster.MinimapContainer and Cluster.MinimapContainer.PlayerCoords
    if not coords then return end
    Raise(coords)
    coords:ClearAllPoints()
    coords:SetPoint("BOTTOM", MinimapFrame, "BOTTOM", 0, COORDS_INSET)
end

-- Forever's day/night badge in the map's bottom-left corner, reaching a little onto the frame, or
-- hidden by the Day/Night Badge option. Blizzard never shows it again on its own.
local function PlaceSun()
    local sun = Cluster.DielFrame
    if not sun then return end
    local db = GetDb()
    sun:SetShown(not db or db.showDayNight)
    sun:SetScale(SUN_SCALE)
    sun:ClearAllPoints()
    local overhang = SUN_OVERHANG / SUN_SCALE   -- offsets are in the badge's own, scaled units
    sun:SetPoint("BOTTOMLEFT", MinimapFrame, "BOTTOMLEFT", -overhang, -overhang)
    Raise(sun, 1)
end

--------------------------------------------------
-- 7. LAYOUT
--------------------------------------------------
-- Edit Mode sizes the cluster and scales the map container from its own Size setting; the size
-- here is fixed, so both are put back after Blizzard. The guard keeps the SetSize hook from
-- answering its own call.
local sizingCluster = false
local function SizeCluster()
    if sizingCluster then return end
    sizingCluster = true
    Cluster:SetSize(CLUSTER_SIZE, CLUSTER_SIZE)
    sizingCluster = false
end

function MM:UpdateLayout()
    if not self.initialized then return end
    Cluster.MinimapContainer:SetScale(1)
    Cluster.BorderTop:SetScale(1)
    Cluster.ZoneTextButton:SetScale(1)
    SizeCluster()

    MinimapFrame:SetSize(MAP_SIZE, MAP_SIZE)
    MinimapFrame:ClearAllPoints()
    MinimapFrame:SetPoint("CENTER", Cluster, "CENTER", 0, 0)
    ApplySquareMap()

    PlaceHeader()
    PlaceFlag()
    PlaceIndicators()
    PlaceCoords()
    PlaceSun()
end

--------------------------------------------------
-- 8. EDIT MODE
-- Three of Blizzard's minimap settings do not apply to this map and are taken out of its dialog:
-- Size (the size is fixed), Rotate Minimap (a rotating map does not fit a square frame) and Header
-- Underneath (the header always runs along the top). A stored value of any of them is harmless -
-- the layout above is re-applied after Blizzard's.
--------------------------------------------------
local function RemoveEditModeSettings()
    local removed = {
        [Enum.EditModeMinimapSetting.Size] = true,
        [Enum.EditModeMinimapSetting.RotateMinimap] = true,
        [Enum.EditModeMinimapSetting.HeaderUnderneath] = true,
    }
    -- Never rewrite saved layouts to pin these: a layout table written by addon code taints Edit
    -- Mode's data (CompactUnitFrame.lua:699 then compares secret colours while tainted).
    local byId = EditModeSettingDisplayInfoManager and EditModeSettingDisplayInfoManager.systemSettingDisplayInfo
    local displayInfo = byId and byId[Enum.EditModeSystem.Minimap]
    if not displayInfo then return end
    for i = #displayInfo, 1, -1 do
        if removed[displayInfo[i].setting] then table_remove(displayInfo, i) end
    end
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

local function InstallHooks()
    hooksecurefunc(Cluster, "SetSize", SizeCluster)
    -- Forever's own SetEditModeScale re-places the day/night badge, and SetHeaderUnderneath
    -- re-anchors the header and banner from a stored layout; the layout goes back on after both
    hooksecurefunc(Cluster, "SetEditModeScale", function() MM:UpdateLayout() end)
    hooksecurefunc(Cluster, "SetHeaderUnderneath", function() MM:UpdateLayout() end)
    hooksecurefunc("MiniMapIndicatorFrame_UpdatePosition", PlaceIndicators)
    if Cluster.InstanceDifficulty then
        hooksecurefunc(Cluster.InstanceDifficulty, "Update", DressBanner)
    end
    hooksecurefunc(MinimapFrame, "SetZoom", OnZoom)
    if not _G.HybridMinimap then
        EventUtil.ContinueOnAddOnLoaded("Blizzard_HybridMinimap", SquareHybridMinimap)
    end
end

--------------------------------------------------
-- 10. OBJECTIVE TRACKER SCALE
-- "Match Objective Tracker Width" scales the whole tracker, text and all, so the lines above and
-- below its header bars are as long as the minimap's frame is wide. The bars are Blizzard's 300 px
-- atlas art, whose lines fade out at the ends: about 288 px of line actually shows.
--------------------------------------------------
local TRACKER_LINE_WIDTH = 288

-- the minimap frame's outer width, in the tracker's parent's units
local function FrameOuterWidth(tracker)
    local frame = MM.Frame
    local left = frame and frame.TopLeftCorner and frame.TopLeftCorner:GetLeft()
    local right = frame and frame.TopRightCorner and frame.TopRightCorner:GetRight()
    if not (left and right) then return nil end
    return (right - left) * frame:GetEffectiveScale() / tracker:GetParent():GetEffectiveScale()
end

function MM:UpdateTrackerScale()
    local tracker = _G.ObjectiveTrackerFrame
    local db = GetDb()
    if not (tracker and db) then return end
    local scale = 1
    if db.matchTrackerWidth then
        local width = FrameOuterWidth(tracker)
        if width then scale = width / TRACKER_LINE_WIDTH end
    end
    tracker:SetScale(scale)
end

--------------------------------------------------
-- 11. PUBLIC
--------------------------------------------------
-- FPS and latency under the times in the clock's tooltip. Blizzard rebuilds that tooltip every second
-- while it is up (TimeManagerClockButton_UpdateTooltip -> GameTime_UpdateTooltip), so the numbers stay
-- live. GameTime_UpdateTooltip is shared, hence the owner check.
local function AddClockStats()
    local db = GetDb()
    local clock = _G.TimeManagerClockButton
    if not (db and db.enabled and db.clockStats and clock and GameTooltip:GetOwner() == clock) then return end
    local _, _, latencyHome, latencyWorld = GetNetStats()
    local label, value = NORMAL_FONT_COLOR, HIGHLIGHT_FONT_COLOR
    GameTooltip:AddDoubleLine("Framerate", string.format("%.0f fps", GetFramerate()),
        label.r, label.g, label.b, value.r, value.g, value.b)
    GameTooltip:AddDoubleLine("Latency (Home)", latencyHome .. " ms", label.r, label.g, label.b, value.r, value.g, value.b)
    GameTooltip:AddDoubleLine("Latency (World)", latencyWorld .. " ms", label.r, label.g, label.b, value.r, value.g, value.b)
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
    -- Blizzard's clock only takes the tooltip on enter and fills it on its next one-second tick, so it
    -- came up to a second late; filling it on enter makes it instant like every other tooltip
    EventUtil.ContinueOnAddOnLoaded("Blizzard_TimeManager", function()
        local clock = _G.TimeManagerClockButton
        if clock then clock:HookScript("OnEnter", function() TimeManagerClockButton_UpdateTooltip() end) end
    end)
    if not (MinimapFrame and Cluster and Cluster.BorderTop and Cluster.Tracking and Cluster.MinimapContainer) then
        print("|cffff0000FlareUI:|r Minimap module could not find the Blizzard minimap cluster.")
        return
    end

    RemoveEditModeSettings()
    -- free to be dragged partly off screen; the clamp only comes from Edit Mode's XML template
    Cluster:SetClampedToScreen(false)
    -- Blizzard's addon drawer has no place in this frame; Blizzard re-shows it from UpdateDisplay
    local drawer = _G.AddonCompartmentFrame
    if drawer then
        hooksecurefunc(drawer, "UpdateDisplay", drawer.Hide)
        drawer:Hide()
    end
    CreateMapArt()
    StyleHeader()
    InstallHooks()
    self.initialized = true

    EventUtil.ContinueOnAddOnLoaded("Blizzard_ObjectiveTracker", function() self:UpdateTrackerScale() end)
    self:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED", "Refresh")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "Refresh")

    self:Refresh()
    -- the frame's corners only have positions once the first layout pass has run
    C_Timer.After(0, function() self:Refresh() end)
end
