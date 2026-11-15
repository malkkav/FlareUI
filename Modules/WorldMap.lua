local _, ns = ...
local L = ns.L

--------------------------------------------------
-- WORLD MAP (Quality of Life > Gameplay; 11-15, a player's request)
-- Four small things on Blizzard's world map, each off by default:
--   * Resize Grip: a grip in the windowed map's bottom right corner; dragged, it scales the map, its
--     top left corner staying put. The scale is Move Any Frame's (Tweaks.lua 3: the one Ctrl+wheel
--     sets, saved per window), so the grip needs Move Any Frame on. Right-click: 100%.
--   * Hide Map Backdrop: the black screen behind the maximised map goes (alpha and mouse only)
--   * Map Coordinates: the cursor's and your own position under the map
--   * Zone Levels: the level range after a zone's name in the map's own label
-- OpenMap and Leatrix Maps place, scale and dress the map themselves: with either loaded nothing here
-- runs (as Move Any Frame leaves the map to them).
--------------------------------------------------
local WM = {}
ns.WorldMap = WM

local GRIP_SIZE = 16
local MIN_SCALE, MAX_SCALE = 0.5, 2.0   -- Move Any Frame's range
local COORDS_EVERY = 0.1                -- seconds between coordinate readings

local function GetDb()
    return ns.db and ns.db.profile and ns.db.profile.tweaks
end

-- the name of a map addon in charge, or nil
function WM.Taken()
    for _, name in ipairs({ "Leatrix_Maps", "OpenMap" }) do
        if C_AddOns.IsAddOnLoaded(name) then return name end
    end
end

local function Maximized(map)
    return map.IsMaximized and map:IsMaximized() and true or false
end

--------------------------------------------------
-- 1. RESIZE GRIP
--------------------------------------------------
local function GripWanted(map)
    local db = GetDb()
    return db and db.mapGrip == true and db.moveAnyFrame and map.moveName and not Maximized(map)
        and ns.Tweaks and ns.Tweaks.SetFrameScale and true or false
end

local function GripTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(L["Drag to Resize"])
    GameTooltip:AddLine(L["Size"] .. ": " .. math.floor(self.map:GetScale() * 100 + 0.5) .. "%", 1, 1, 1)
    GameTooltip:AddLine(L["Right-click to reset."], 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

-- While the grip is held: the map is as much bigger as the cursor is further from its left edge than
-- at the press. In screen pixels, and the left edge stays put (SetFrameScale keeps the top left
-- corner), so the grip follows the cursor.
local function GripDrag(self)
    local map = self.map
    if not self.startSpan then return end
    local span = math.max(GetCursorPosition() - self.left, 1)
    local scale = self.startScale * span / self.startSpan
    scale = math.floor(math.max(MIN_SCALE, math.min(MAX_SCALE, scale)) * 100 + 0.5) / 100
    if scale == map:GetScale() then return end
    ns.Tweaks.SetFrameScale(map, scale)
    if GameTooltip:IsOwned(self) then GripTooltip(self) end
end

local function GripStop(self)
    self.startSpan = nil
    self:SetScript("OnUpdate", nil)
end

local function CreateGrip(map)
    -- (on the map's border frame, which Blizzard keeps above the map's canvas and pins)
    local grip = CreateFrame("Button", nil, map.BorderFrame or map)
    grip.map = map
    grip:SetSize(GRIP_SIZE, GRIP_SIZE)
    grip:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", -2, 2)
    grip:SetFrameLevel(grip:GetParent():GetFrameLevel() + 10)
    grip:RegisterForClicks("RightButtonUp")
    -- Blizzard's chat window grip
    for _, state in ipairs({ { "SetNormalTexture", "Up" }, { "SetHighlightTexture", "Highlight" }, { "SetPushedTexture", "Down" } }) do
        grip[state[1]](grip, "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-" .. state[2])
    end
    grip:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        local left = map:GetLeft()
        if not left then return end
        self.left = left * map:GetEffectiveScale()
        self.startSpan = math.max(GetCursorPosition() - self.left, 1)
        self.startScale = map:GetScale()
        self:SetScript("OnUpdate", GripDrag)
    end)
    grip:SetScript("OnMouseUp", GripStop)
    grip:SetScript("OnHide", GripStop)
    grip:SetScript("OnClick", function(self)
        ns.Tweaks.SetFrameScale(map, 1)
        if GameTooltip:IsOwned(self) then GripTooltip(self) end
    end)
    grip:SetScript("OnEnter", GripTooltip)
    grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return grip
end

local function ApplyGrip(map)
    local wanted = GripWanted(map)
    if wanted and not WM.grip then WM.grip = CreateGrip(map) end
    if WM.grip then WM.grip:SetShown(wanted) end
end

--------------------------------------------------
-- 2. HIDE MAP BACKDROP
--------------------------------------------------
local function ApplyBackdrop(map)
    local black = map.BlackoutFrame
    if not black then return end
    local db = GetDb()
    local hide = db and db.mapNoBackdrop == true or false
    -- never on this session: Blizzard's frame stays untouched
    if not hide and not WM.backdropHidden then return end
    WM.backdropHidden = hide
    black:SetAlpha(hide and 0 or 1)
    black:EnableMouse(not hide)
end

--------------------------------------------------
-- 3. ZONE LEVELS
-- The level range after the zone's name in the map's own label (the name Blizzard shows at the top
-- while the cursor is over a zone on a continent's map): "Duskwood (18-30)", red while you are under
-- the range, yellow in it, green past it. Blizzard's label writes the name on every frame
-- (AreaLabelFrameMixin:OnUpdate); a script hooked after it writes the name again with the range, so
-- Blizzard's own script is left in place.
--------------------------------------------------
-- Zone level ranges, by map ID: the client gives none here (C_Map.GetMapLevels is retail's), so they
-- are listed. The vanilla zones, in the usual questing ranges; a zone not listed shows no range.
local ZONE_LEVELS = {
    -- Eastern Kingdoms
    [1426] = { 1, 10 },    -- Dun Morogh
    [1429] = { 1, 10 },    -- Elwynn Forest
    [1420] = { 1, 10 },    -- Tirisfal Glades
    [1432] = { 10, 20 },   -- Loch Modan
    [1436] = { 10, 20 },   -- Westfall
    [1421] = { 10, 20 },   -- Silverpine Forest
    [1433] = { 15, 25 },   -- Redridge Mountains
    [1431] = { 18, 30 },   -- Duskwood
    [1424] = { 20, 30 },   -- Hillsbrad Foothills
    [1437] = { 20, 30 },   -- Wetlands
    [1416] = { 30, 40 },   -- Alterac Mountains
    [1417] = { 30, 40 },   -- Arathi Highlands
    [1434] = { 30, 45 },   -- Stranglethorn Vale
    [1418] = { 35, 45 },   -- Badlands
    [1435] = { 35, 45 },   -- Swamp of Sorrows
    [1425] = { 40, 50 },   -- The Hinterlands
    [1427] = { 43, 50 },   -- Searing Gorge
    [1419] = { 45, 55 },   -- Blasted Lands
    [1428] = { 50, 58 },   -- Burning Steppes
    [1422] = { 51, 58 },   -- Western Plaguelands
    [1423] = { 53, 60 },   -- Eastern Plaguelands
    [1430] = { 55, 60 },   -- Deadwind Pass
    -- Kalimdor
    [1411] = { 1, 10 },    -- Durotar
    [1412] = { 1, 10 },    -- Mulgore
    [1438] = { 1, 10 },    -- Teldrassil
    [1439] = { 10, 20 },   -- Darkshore
    [1413] = { 10, 25 },   -- The Barrens
    [1442] = { 15, 27 },   -- Stonetalon Mountains
    [1440] = { 18, 30 },   -- Ashenvale
    [1441] = { 25, 35 },   -- Thousand Needles
    [1443] = { 30, 40 },   -- Desolace
    [1445] = { 35, 45 },   -- Dustwallow Marsh
    [1444] = { 40, 50 },   -- Feralas
    [1446] = { 40, 50 },   -- Tanaris
    [1447] = { 45, 55 },   -- Azshara
    [1448] = { 48, 55 },   -- Felwood
    [1449] = { 48, 55 },   -- Un'Goro Crater
    [1452] = { 53, 60 },   -- Winterspring
    [1450] = { 55, 60 },   -- Moonglade
    [1451] = { 55, 60 },   -- Silithus
}
WM.ZONE_LEVELS = ZONE_LEVELS

-- After Blizzard's own label update: the zone under the cursor, with its range
local function AfterAreaLabel(label)
    local db = GetDb()
    if not (db and db.mapZoneLevels) or WM.Taken() then return end
    local kind = MAP_AREA_LABEL_TYPE and MAP_AREA_LABEL_TYPE.AREA_NAME
    local map = label.dataProvider and label.dataProvider:GetMap()
    if not (kind and map and map:IsCanvasMouseFocus()) then return end
    local mapID = map:GetMapID()
    local x, y = map:GetNormalizedCursorPosition()
    local under = mapID and x and C_Map.GetMapInfoAtPosition(mapID, x, y)
    local range = under and under.mapID ~= mapID and under.name and ZONE_LEVELS[under.mapID]
    if not range then return end
    local level = UnitLevel("player") or 0
    local color = (level < range[1] and "ffff4040") or (level > range[2] and "ff40c040") or "ffffd200"
    label:SetLabel(kind, ("%s |c%s(%d-%d)|r"):format(under.name, color, range[1], range[2]))
    label:EvaluateLabels()
end

local function ApplyZoneLevels(map)
    local db = GetDb()
    if WM.labelsHooked or not (db and db.mapZoneLevels) then return end
    WM.labelsHooked = true
    for provider in pairs(map.dataProviders or {}) do
        local label = provider.Label
        if type(label) == "table" and label.SetLabel and label.EvaluateLabels then
            label:HookScript("OnUpdate", AfterAreaLabel)
        end
    end
end

--------------------------------------------------
-- 3b. MAP COORDINATES
-- One line of text at the map's foot, read ten times a second while the map is open: the cursor's
-- position and your own.
--------------------------------------------------
local function Percent(v)
    return ("%.1f"):format(v * 100)
end

-- the cursor's place on the map shown (0 to 1 each way), or nil off the map
local function CursorOnMap(map)
    local scroll = map.ScrollContainer
    if not (scroll and scroll:IsMouseOver() and map.GetNormalizedCursorPosition) then return nil end
    local x, y = map:GetNormalizedCursorPosition()
    if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then return x, y end
end

local function ReadFooter(map)
    local db = GetDb()
    local parts = {}
    local mapID = map.GetMapID and map:GetMapID()
    local x, y = CursorOnMap(map)
    if db.mapCoords then
        if x then parts[#parts + 1] = L["Cursor"] .. ": " .. Percent(x) .. ", " .. Percent(y) end
        local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
        -- (no position in an instance, or on a map you aren't on)
        if position and (not canaccessvalue or canaccessvalue(position)) then
            local px, py = position:GetXY()
            if px and py and (not canaccessvalue or (canaccessvalue(px) and canaccessvalue(py))) then
                parts[#parts + 1] = L["Player"] .. ": " .. Percent(px) .. ", " .. Percent(py)
            end
        end
    end
    return table.concat(parts, "     ")
end

local function CreateFooter(map)
    local holder = CreateFrame("Frame", nil, map.BorderFrame or map)
    holder:SetSize(300, 16)
    holder:SetPoint("BOTTOM", map.ScrollContainer or map, "BOTTOM", 0, 6)
    holder:SetFrameLevel(holder:GetParent():GetFrameLevel() + 10)
    holder.text = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    holder.text:SetPoint("CENTER")
    local path, size = holder.text:GetFont()
    holder.text:SetFont(path, size, "OUTLINE")
    local elapsed = COORDS_EVERY
    holder:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed < COORDS_EVERY then return end
        elapsed = 0
        local ok, text = pcall(ReadFooter, map)
        self.text:SetText(ok and text or "")
    end)
    return holder
end

local function ApplyFooter(map)
    local db = GetDb()
    local wanted = db and db.mapCoords == true or false
    if wanted and not WM.footer then WM.footer = CreateFooter(map) end
    if WM.footer then WM.footer:SetShown(wanted) end
end

--------------------------------------------------
-- 4. PUBLIC
--------------------------------------------------
-- On and off live (Tweaks:Refresh and its setup). Hooked the first time an option is on.
function WM.Apply()
    local map = _G.WorldMapFrame
    if not map or WM.Taken() then return end
    local db = GetDb()
    local any = db and (db.mapGrip or db.mapNoBackdrop or db.mapCoords or db.mapZoneLevels)
    if not any and not WM.hooked then return end
    if not WM.hooked then
        WM.hooked = true
        -- the grip only shows on the windowed map
        map:HookScript("OnShow", function() ApplyGrip(map) end)
        for _, method in ipairs({ "Maximize", "Minimize" }) do
            if type(map[method]) == "function" then hooksecurefunc(map, method, function() ApplyGrip(map) end) end
        end
    end
    ApplyGrip(map)
    ApplyBackdrop(map)
    ApplyFooter(map)
    ApplyZoneLevels(map)
end
