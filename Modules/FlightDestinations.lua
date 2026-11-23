local _, ns = ...

local Destinations = {}
ns.FlightDestinations = Destinations

local function IsFlightTarget(node)
    return node.state == Enum.FlightPathState.Reachable and not node.isMapLayerTransition
end

local function GetFare(slot, node)
    local cost = TaxiNodeCost(slot)
    if node and (not cost or cost == 0) and node.specialIconCostString then
        return cost, node.specialIconCostString, node.useSpecialIcon and HIGHLIGHT_FONT_COLOR or RED_FONT_COLOR
    end
    return cost
end

local function SameFare(entry, cost, text, color)
    return entry.cost == cost and entry.priceText == text and entry.priceColor == color
end

local function SplitName(name)
    local place, zone = name:match("^%s*(.-)%s*,%s*(.-)%s*$")
    if not place then place, zone = name:match("^%s*(.-)%s*，%s*(.-)%s*$") end
    if place and place ~= "" and zone ~= "" then return place, zone end
    return name
end

local function ZoneAtNode(mapID, node)
    if not (node and node.position and C_Map and C_Map.GetMapInfoAtPosition and Enum.UIMapType) then return end
    local info = C_Map.GetMapInfoAtPosition(mapID, node.position:GetXY())
    if info and (info.mapType == Enum.UIMapType.Micro or info.mapType == Enum.UIMapType.Dungeon)
        and MapUtil and MapUtil.GetMapParentInfo then
        info = MapUtil.GetMapParentInfo(info.mapID, Enum.UIMapType.Zone)
    end
    if info and info.mapType == Enum.UIMapType.Zone then return info.name end
end

-- The old taxi map uses its own texture coordinates. Only map positions from
-- C_TaxiMap, matched to the same live slot and name, can be used to find a zone.
local function LegacyMapNodes(mapID)
    local bySlot = {}
    if mapID and C_TaxiMap and C_TaxiMap.GetAllTaxiNodes then
        for _, node in ipairs(C_TaxiMap.GetAllTaxiNodes(mapID)) do bySlot[node.slotIndex] = node end
    end
    return bySlot
end

function Destinations.GetDestinations(frame, layout)
    local entries = {}
    local originSlot, modernNodes
    if not frame or not frame:IsShown() then return entries end

    if frame == _G.TaxiFrame then
        local mapID = GetTaxiMapID and GetTaxiMapID()
        local validMap = type(mapID) == "number" and mapID > 0 and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
        local nodes = validMap and LegacyMapNodes(mapID)
        local positions, namedPositions = {}, {}
        local count = NumTaxiNodes()
        if layout then
            layout.changed = layout.count ~= count or layout.mapID ~= mapID
            layout.count, layout.mapID = count, mapID
        end
        for slot = 1, count do
            local state = TaxiNodeGetType(slot)
            local x, y, position, name, oldKey
            if state ~= "NONE" then
                x, y = TaxiNodePosition(slot)
                name = TaxiNodeName(slot)
                if x and y then
                    position = ("%s:%.6f:%.6f"):format(mapID or 0, x, y)
                    positions[position] = (positions[position] or 0) + 1
                end
                if name then
                    oldKey = ("%s:%s"):format(position or mapID or 0, name)
                    namedPositions[oldKey] = (namedPositions[oldKey] or 0) + 1
                end
            end
            if layout then
                local old = layout[slot]
                if not old or old.state ~= state or old.x ~= x or old.y ~= y then
                    layout[slot] = { state = state, x = x, y = y }
                    layout.changed = true
                end
            end
            local node = nodes and nodes[slot] or nil
            if node and node.name ~= name then node = nil end
            if state == "CURRENT" then
                originSlot = slot
            elseif state == "REACHABLE" then
                local place, zone = SplitName(name)
                entries[#entries + 1] = {
                    frame = frame, mapID = mapID, slot = slot, name = name, x = x, y = y,
                    place = place, zone = zone or ZoneAtNode(mapID, node), cost = TaxiNodeCost(slot),
                    nodeID = node and node.nodeID, positionKey = position, oldFavoriteKey = oldKey,
                }
            end
        end
        for _, entry in ipairs(entries) do
            local position = entry.positionKey
            -- Names only disambiguate pins that Blizzard places at exactly the same coordinates.
            entry.sharedPosition = position and positions[position] > 1
            entry.locationKey = position and not entry.sharedPosition and position or "named:" .. entry.oldFavoriteKey
            entry.ambiguousPoint = namedPositions[entry.oldFavoriteKey] > 1
            entry.favoriteKey = entry.nodeID
            if not entry.favoriteKey and not entry.ambiguousPoint then entry.favoriteKey = entry.locationKey end
        end
    elseif frame == _G.FlightMapFrame then
        local mapID = frame:GetMapID()
        if type(mapID) == "number" and mapID > 0 then
            modernNodes = C_TaxiMap.GetAllTaxiNodes(mapID)
            for _, node in ipairs(modernNodes) do
                if node.state == Enum.FlightPathState.Current and not node.isMapLayerTransition then
                    originSlot = node.slotIndex
                elseif IsFlightTarget(node) then
                    local cost, priceText, priceColor = GetFare(node.slotIndex, node)
                    local place, zone = SplitName(node.name)
                    entries[#entries + 1] = {
                        frame = frame, mapID = mapID, nodeID = node.nodeID, slot = node.slotIndex, name = node.name,
                        favoriteKey = node.nodeID,
                        place = place, zone = zone or ZoneAtNode(mapID, node),
                        cost = cost, priceText = priceText, priceColor = priceColor,
                    }
                end
            end
            -- The current flight master may be on another layer.
            if not originSlot and #entries > 0 then
                for slot = 1, NumTaxiNodes() do
                    if TaxiNodeGetType(slot) == "CURRENT" then
                        originSlot = slot
                        break
                    end
                end
            end
        end
    end
    return entries, originSlot, modernNodes
end

local function FindLiveNode(entry)
    for _, node in ipairs(C_TaxiMap.GetAllTaxiNodes(entry.mapID)) do
        if node.slotIndex == entry.slot and node.nodeID == entry.nodeID and node.name == entry.name then return node end
    end
end

-- If Blizzard provides no ID for an overlapping point, do not buy a route we
-- cannot distinguish from another slot with the same full name and position.
local function IsUniqueLegacyPoint(entry)
    for slot = 1, NumTaxiNodes() do
        if slot ~= entry.slot and TaxiNodeGetType(slot) ~= "NONE" and TaxiNodeName(slot) == entry.name then
            local x, y = TaxiNodePosition(slot)
            if x == entry.x and y == entry.y then return false end
        end
    end
    return true
end

-- Slot indices are valid only for the open flight master and map layer.
function Destinations.CanFly(frame, entry, checkFare)
    if not frame or not entry or entry.frame ~= frame or type(entry.slot) ~= "number" or not frame:IsShown() then return false end
    local liveNode
    if frame == _G.TaxiFrame then
        if entry.mapID ~= (GetTaxiMapID and GetTaxiMapID()) or entry.slot < 1 or entry.slot > NumTaxiNodes()
            or TaxiNodeGetType(entry.slot) ~= "REACHABLE" or TaxiNodeName(entry.slot) ~= entry.name then return false end
        local x, y = TaxiNodePosition(entry.slot)
        if x ~= entry.x or y ~= entry.y then return false end
        if checkFare then
            if entry.nodeID then
                if not FindLiveNode(entry) then return false end
            elseif entry.ambiguousPoint or not IsUniqueLegacyPoint(entry) then
                return false
            end
        end
    elseif frame == _G.FlightMapFrame and entry.mapID and entry.mapID == frame:GetMapID() then
        liveNode = FindLiveNode(entry)
        if not liveNode or not IsFlightTarget(liveNode) then return false end
    else
        return false
    end
    return not checkFare or SameFare(entry, GetFare(entry.slot, liveNode))
end

-- Called directly from the destination row's left-click handler.
function Destinations.Fly(frame, entry)
    if not Destinations.CanFly(frame, entry, true) then return false end
    TakeTaxiNode(entry.slot)
    return true
end

local function SameDestination(a, b)
    return a and b and a.frame == b.frame and a.slot == b.slot and a.name == b.name
        and a.mapID == b.mapID and a.nodeID == b.nodeID and a.x == b.x and a.y == b.y
end

local hoveredEntry, hoveredPin, hoveredNode, hoveredPath
local hoveredSlots, hiddenRoutePins

-- A newly learned stop can change the path without changing the destination.
-- Only the route under the pointer needs to be compared when node data changes.
local function RoutePath(slot, slots, hiddenPins)
    local legs = {}
    for hop = 1, GetNumRoutes(slot) do
        legs[2 * hop - 1] = TaxiGetNodeSlot(slot, hop, true) or 0
        legs[2 * hop] = TaxiGetNodeSlot(slot, hop, false) or 0
    end
    if hiddenPins then
        for _, routeSlot in ipairs(legs) do
            local pin = slots[routeSlot]
            if pin and not pin:IsShown() then hiddenPins[pin] = pin.taxiNodeData end
        end
    end
    return table.concat(legs, ",")
end

-- MapCanvas can give the same pin to a different node when it redraws a layer.
local function OwnsHoveredNode()
    return hoveredPin.owner.slotIndexToPin == hoveredSlots and hoveredPin.taxiNodeData == hoveredNode
        and hoveredNode.nodeID == hoveredEntry.nodeID and hoveredNode.slotIndex == hoveredEntry.slot
end

local function CanKeepHighlight(entry, checkPath)
    if not SameDestination(hoveredEntry, entry) or not hoveredPin:IsShown() then return false end
    if hoveredNode then
        if not OwnsHoveredNode() or not IsFlightTarget(hoveredNode) then return false end
    elseif hoveredPin ~= _G["TaxiButton" .. entry.slot] then
        return false
    end
    return not checkPath or hoveredPath == RoutePath(entry.slot)
end

function Destinations.Leave(skipClassicLines)
    if not hoveredEntry then return end
    local frame = hoveredEntry.frame
    if frame == _G.TaxiFrame then
        hoveredPin:UnlockHighlight()
        if not skipClassicLines and frame:IsShown() and NumTaxiNodes() > 0 then DrawOneHopLines() end
    elseif frame:IsShown() and frame:GetMapID() == hoveredEntry.mapID
        and hoveredPin:IsShown() and OwnsHoveredNode() then
        hoveredPin.owner:RemoveRouteToPin(hoveredPin)
        -- Blizzard removes the current route. A reroute may have dropped a stop that our preview revealed.
        for pin, node in pairs(hiddenRoutePins) do
            if pin:IsShown() and pin.taxiNodeData == node and hoveredSlots[node.slotIndex] == pin
                and node.state == Enum.FlightPathState.Unreachable and not node.isMapLayerTransition then pin:Hide() end
        end
        hoveredPin:SetFlightPathStyle(hoveredNode.state)
    end
    hoveredEntry, hoveredPin, hoveredNode, hoveredPath = nil, nil, nil, nil
    hoveredSlots, hiddenRoutePins = nil, nil
end

function Destinations.Hover(frame, entry)
    if frame and frame == _G.TaxiFrame then
        local pin = Destinations.CanFly(frame, entry) and _G["TaxiButton" .. entry.slot]
        if not pin or not pin:IsShown() then
            Destinations.Leave()
            return false
        end
        -- The native hover handler replaces every route line with the next preview.
        Destinations.Leave(true)
        hoveredEntry, hoveredPin, hoveredPath = entry, pin, RoutePath(entry.slot)
        pin:LockHighlight()
        TaxiNodeOnButtonEnter(pin)
        -- The list already shows the name and price; keep the route visible.
        if GameTooltip:IsOwned(pin) then GameTooltip:Hide() end
        return true
    end
    Destinations.Leave()
    if not frame or frame ~= _G.FlightMapFrame or not frame:IsShown() or not entry or entry.frame ~= frame
        or entry.mapID ~= frame:GetMapID() then return false end
    -- All flight pins belong to one provider. Its live slot index also identifies a fresh draw of this layer.
    for anyPin in frame:EnumeratePinsByTemplate("FlightMap_FlightPointPinTemplate") do
        local slots = anyPin.owner.slotIndexToPin
        local pin = slots[entry.slot]
        local node = pin and pin.taxiNodeData
        if not node or node.nodeID ~= entry.nodeID or node.name ~= entry.name or node.slotIndex ~= entry.slot
            or not IsFlightTarget(node) or not pin:IsShown() then return false end
        hoveredEntry, hoveredPin, hoveredNode = entry, pin, node
        hoveredSlots, hiddenRoutePins = slots, {}
        hoveredPath = RoutePath(entry.slot, slots, hiddenRoutePins)
        pin.owner:HighlightRouteToPin(pin)
        pin.Icon:SetAtlas(pin.atlasFormat:format("Taxi_Frame_Yellow"))
        return true
    end
    return false
end

-- Lua's string.lower does not fold Cyrillic. Compare whole UTF-8 characters with
-- the same locale-aware comparator Blizzard uses for names in its lists.
function Destinations.Matches(name, query)
    local starts
    for word in query:gmatch("%S+") do
        if not name:find(word, 1, true) then
            if not starts then
                starts = {}
                for at in name:gmatch("()[^\128-\191]") do starts[#starts + 1] = at end
                starts[#starts + 1] = #name + 1
            end
            local length = strlenutf8(word)
            local found = false
            for i = 1, #starts - length do
                if strcmputf8i(name:sub(starts[i], starts[i + length] - 1), word) == 0 then
                    found = true
                    break
                end
            end
            if not found then return false end
        end
    end
    return true
end

local WIDTH, ROW_HEIGHT = 286, 37
local SPECIAL_FARE_MAX_WIDTH = 84 -- Keep the zone readable even at the narrowest docked width.
local LIST_LEFT, LIST_RIGHT = 8, 27 -- room for the scroll thumb
local TAB_WIDTH, VERTICAL_INSET = 16, 64
local panels = {}
local expanded = true

local function LeaveRow(panel)
    if panel.hoveredControl and GameTooltip:IsOwned(panel.hoveredControl) then GameTooltip:Hide() end
    panel.hoveredControl, panel.pendingLeave = nil, nil
    Destinations.Leave()
end

local function LeaveControl(panel, control, other)
    if GameTooltip:IsOwned(control) then GameTooltip:Hide() end
    if panel.hoveredControl ~= control then return end
    if other:IsMouseOver() or (panel.map == _G.TaxiFrame and panel.scroll:IsMouseOver()) then
        -- Give the next row or star its OnEnter before restoring the unhovered map.
        panel.pendingLeave = true
    else
        LeaveRow(panel)
    end
end

local function EnterRow(panel, row, control, checkPath)
    local entry = row.entry
    if not entry then return end
    local previousControl = panel.hoveredControl
    panel.hoveredControl, panel.pendingLeave = control, nil
    if not CanKeepHighlight(entry, checkPath) then Destinations.Hover(panel.map, entry) end
    if control == row.favorite then
        GameTooltip:SetOwner(control, "ANCHOR_LEFT")
        GameTooltip:SetText(entry.isFavorite and BATTLE_PET_UNFAVORITE or BATTLE_PET_FAVORITE)
        GameTooltip:AddLine(entry.name, 1, 1, 1, true)
        GameTooltip:Show()
    elseif row.place:IsTruncated() or row.zone:IsTruncated() or (entry.priceText and row.fare:IsTruncated()) then
        GameTooltip:SetOwner(row, "ANCHOR_LEFT")
        GameTooltip:SetText(entry.place)
        if entry.zone and entry.zone ~= entry.place then GameTooltip:AddLine(entry.zone, 1, 1, 1, true) end
        if entry.priceText then GameTooltip_AddColoredLine(GameTooltip, entry.priceText, entry.priceColor, true) end
        GameTooltip:Show()
    elseif previousControl and GameTooltip:IsOwned(previousControl) then
        GameTooltip:Hide()
    end
end

local SortAndFilter, RefreshEntries

local function NewFavoriteButton(panel, row)
    local star = CreateFrame("Button", nil, row)
    star:SetSize(20, 18)
    star:SetPoint("TOPRIGHT", -3, 0)
    star:RegisterForClicks("LeftButtonUp")
    star:SetScript("OnEnter", function(self) EnterRow(panel, row, self) end)
    star:SetScript("OnLeave", function(self)
        self.pressedEntry = nil
        LeaveControl(panel, self, row)
    end)
    star:SetScript("OnHide", function(self)
        self.pressedEntry = nil
        if panel.hoveredControl == self then LeaveRow(panel) end
    end)
    star:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then self.pressedEntry = row.entry end
    end)
    star:SetScript("OnClick", function(self)
        local entry, pressed = row.entry, self.pressedEntry
        self.pressedEntry = nil
        if not SameDestination(pressed, entry) or not entry.favoriteKey or pressed.favoriteKey ~= entry.favoriteKey then return end
        local char = ns.CharDB()
        char.favoriteFlightDestinations = char.favoriteFlightDestinations or {}
        local favorites = char.favoriteFlightDestinations
        favorites[entry.favoriteKey] = not favorites[entry.favoriteKey] or nil
        SortAndFilter(panel)
    end)
    return star
end

local function NewRow(panel, index)
    local row = CreateFrame("Button", nil, panel.content)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:SetPoint("TOPRIGHT", 0, -(index - 1) * ROW_HEIGHT)
    row:RegisterForClicks("LeftButtonUp")
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row:GetHighlightTexture():SetAlpha(0.45)

    row.favorite = NewFavoriteButton(panel, row)
    row.time = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.time:SetPoint("TOPRIGHT", row.favorite, "TOPLEFT", -3, -3)
    row.fare = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.fare:SetPoint("BOTTOMRIGHT", -5, 5)
    row.fare:SetJustifyH("RIGHT")
    row.fare:SetWordWrap(false)
    row.fare:SetMaxLines(1)
    row.place = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.place:SetPoint("TOPLEFT", 5, -3)
    row.place:SetPoint("TOPRIGHT", row.time, "TOPLEFT", -5, 0)
    row.place:SetJustifyH("LEFT")
    row.place:SetWordWrap(false)
    row.zone = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.zone:SetPoint("BOTTOMLEFT", 5, 5)
    row.zone:SetPoint("BOTTOMRIGHT", row.fare, "BOTTOMLEFT", -5, 0)
    row.zone:SetJustifyH("LEFT")
    row.zone:SetWordWrap(false)
    row.zone:SetTextColor(0.75, 0.72, 0.65)
    row:SetScript("OnEnter", function(self) EnterRow(panel, self, self) end)
    row:SetScript("OnLeave", function(self)
        panel.pressedEntry = nil
        LeaveControl(panel, self, self.favorite)
    end)
    row:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then panel.pressedEntry = self.entry end
    end)
    row:SetScript("OnClick", function(self)
        local pressed, current = panel.pressedEntry, self.entry
        panel.pressedEntry = nil
        -- Both the row binding and the live quote must still match the press.
        if not SameDestination(pressed, current) or not SameFare(pressed, current.cost, current.priceText, current.priceColor) then return end
        if not Destinations.Fly(panel.map, pressed) then RefreshEntries(panel) end
    end)
    return row
end

local function FilterRows(panel, resetScroll, checkPath)
    local offset = resetScroll and 0 or panel.scroll:GetVerticalScroll()
    local query, count = panel.search:GetText(), 0
    for _, entry in ipairs(panel.entries) do
        if Destinations.Matches(entry.searchText, query) then
            count = count + 1
            local row = panel.rows[count]
            if not row then
                row = NewRow(panel, count)
                panel.rows[count] = row
            end
            row.entry = entry
            local star = row.favorite
            star:SetShown(entry.favoriteKey ~= nil)
            if star.active ~= entry.isFavorite then
                local atlas = entry.isFavorite and "auctionhouse-icon-favorite" or "auctionhouse-icon-favorite-off"
                star:SetNormalAtlas(atlas)
                star:SetHighlightAtlas(atlas, "ADD")
                star.active = entry.isFavorite
            end
            row.place:SetText(entry.place)
            row.zone:SetText(entry.zone ~= entry.place and entry.zone or "")
            row.fare:SetText(entry.fare)
            row.fare:SetTextColor((entry.priceColor or HIGHLIGHT_FONT_COLOR):GetRGB())
            row.fare:SetWidth(entry.priceText and math.min(SPECIAL_FARE_MAX_WIDTH, math.ceil(row.fare:GetUnboundedStringWidth()) + 1) or 0)
            row.time:SetText(entry.time)
            row:Show()
        end
    end
    for i = count + 1, #panel.rows do
        panel.rows[i]:Hide()
        panel.rows[i].entry = nil
    end
    local height = math.max(1, count * ROW_HEIGHT)
    panel.content:SetHeight(height)
    panel.empty:SetShown(count == 0)
    panel.scroll:SetVerticalScroll(math.min(offset, math.max(0, height - panel.scroll:GetHeight())))
    -- Filtering can change a row's destination without moving the mouse.
    local focus = GetMouseFoci()[1]
    for i = 1, count do
        local row = panel.rows[i]
        if focus == row or focus == row.favorite then
            EnterRow(panel, row, focus, checkPath)
            return
        end
    end
    LeaveRow(panel)
end

-- A conflicting observation makes the locator permanently ambiguous. A different
-- master may later return only one of the overlapping points.
local function RememberUnique(index, locator, id)
    if not locator then return end
    local previous = index[locator]
    if previous == nil then index[locator] = id
    elseif previous ~= id then index[locator] = false end
end

local function MigrateFavorite(favorites, old, key)
    if old and old ~= key and favorites[old] then
        favorites[key], favorites[old] = true, nil
    end
end

-- A coordinate can belong to two differently named stops that never appear
-- together. Remember names in the client's language so a translation is safe.
local function FavoritePosition(known, favorites, entry, named, locale, oldKey)
    local position = entry.positionKey
    if not position then return end
    local point, id = known[position], entry.nodeID
    if entry.sharedPosition and type(point) ~= "table" then
        known[position] = false
        return
    end
    if point == false then return end
    if type(point) == "number" then
        -- An older numeric binding has no language. First verify its ID or its
        -- exact saved name before allowing matches by coordinates again.
        if id and point ~= id then known[position] = false return end
        if id ~= point and known[named] ~= point then return end
        point = { id = point }
        known[position] = point
    end
    if not point then
        local saved = favorites and favorites[position]
        if type(saved) == "string" and saved ~= entry.name then return end
        if not (id or saved or oldKey) then return position end
        point = {}
        known[position] = point
    end
    local previous, sameID = point[locale], id and id == point.id
    local differentID = id and point.id and id ~= point.id
    if entry.sharedPosition or differentID or (previous and previous ~= entry.name and not sameID) then
        point.shared = true
    end
    -- Preserve the identity (and translations) already witnessed at this spot.
    -- Other points at a shared position use their own named or native keys.
    if point.shared and (entry.ambiguousPoint or differentID or (previous ~= entry.name and not sameID)) then
        return
    end
    point.id, point[locale] = id or point.id, entry.name
    return point.id or position
end

local function RestoreFlightFavorites(entries, char)
    local favorites = char.favoriteFlightDestinations
    char.flightDestinationIDs = char.flightDestinationIDs or {}
    local known = char.flightDestinationIDs
    local locale = GetLocale()
    -- Old name-only records did not store the language. Import them in one
    -- language only; a saved translation takes precedence over that guess.
    known.legacyLocale = known.legacyLocale or locale
    local oldByPosition = {}
    for key, value in pairs(favorites or {}) do
        -- Previous versions stored a classic locator inside a numbered favorite.
        -- Import it on either map, before a click can remove the favorite.
        if type(key) == "number" and type(value) == "string" then
            local named = value:match("^named:(.*)")
            local locator = named or value
            RememberUnique(known, "named:" .. locator, key)
            -- Old numeric records could lack the shared marker even for co-located
            -- points. The full locator remains usable until we learn a native ID.
            if named then
                local position = locator:match("^(%d+:[%d%.%-]+:[%d%.%-]+):")
                RememberUnique(known, position, false)
            end
            favorites[key] = true
        elseif type(key) == "string" then
            local shared = key:match("^named:%a*:?(%d+:[%d%.%-]+:[%d%.%-]+):")
            if shared then
                if type(known[shared]) == "table" then known[shared].shared = true else known[shared] = false end
            end
            RememberUnique(oldByPosition, key:match("^(%d+:[%d%.%-]+:[%d%.%-]+):"), key)
        end
    end
    for _, entry in ipairs(entries) do
        if not entry.oldFavoriteKey then return end -- Modern rows already have their native ID.
        local position = entry.positionKey
        local oldNamed = "named:" .. entry.oldFavoriteKey
        local named = "named:" .. locale .. ":" .. entry.oldFavoriteKey
        local point = known[position]
        local oldID = known[oldNamed]
        local useOldName = (entry.nodeID and entry.nodeID == oldID) or locale == known.legacyLocale and
            (type(point) ~= "table" or point[locale] == entry.name)
        if useOldName and not entry.nodeID and known[named] == nil and oldID
            and (type(point) ~= "table" or not point.id or point.id == oldID) then
            known[named] = oldID
        end
        if entry.ambiguousPoint then known[named] = false end
        if entry.nodeID then RememberUnique(known, named, entry.nodeID) end
        local positionKey = FavoritePosition(known, favorites, entry, named, locale, oldByPosition[position])
        entry.favoriteKey = entry.nodeID
        if known[named] ~= false then
            local key = entry.nodeID or known[named] or positionKey or named
            entry.favoriteKey = key
            if favorites then
                if useOldName then
                    MigrateFavorite(favorites, entry.oldFavoriteKey, key)
                    MigrateFavorite(favorites, oldNamed, key)
                end
                MigrateFavorite(favorites, named, key)
                if positionKey and locale == known.legacyLocale then MigrateFavorite(favorites, oldByPosition[position], key) end
                if positionKey or (useOldName and position and favorites[position] == entry.name) then
                    MigrateFavorite(favorites, position, key)
                end
                -- A positional fallback can become shared after discovering another point.
                if type(key) == "string" and favorites[key] then favorites[key] = entry.name end
            end
        end
    end
end

SortAndFilter = function(panel, resetScroll, checkPath)
    local char = ns.CharDB()
    local favorites = char.favoriteFlightDestinations
    RestoreFlightFavorites(panel.entries, char)
    for _, entry in ipairs(panel.entries) do
        entry.isFavorite = favorites and favorites[entry.favoriteKey] ~= nil or false
    end
    table.sort(panel.entries, function(a, b)
        if a.isFavorite ~= b.isFavorite then return a.isFavorite end
        local order = strcmputf8i(a.place, b.place)
        if order == 0 then order = strcmputf8i(a.zone or "", b.zone or "") end
        if order == 0 then return a.slot < b.slot end
        return order < 0
    end)
    FilterRows(panel, resetScroll, checkPath)
end

-- Only the flight-path provider owns the taxi pins and their slot index.
local function NativeFlightPins(map, nodes, justDrawn)
    if not map.dataProviders then return end
    for provider in pairs(map.dataProviders) do
        if provider.AddFlightNode and provider.slotIndexToPin then
            if not justDrawn then
                local count = 0
                local changed = false
                for _, node in ipairs(nodes) do
                    if provider.isMapLayerTransition or not node.isMapLayerTransition then
                        count = count + 1
                        local pin = provider.slotIndexToPin[node.slotIndex]
                        local shown = pin and pin.taxiNodeData
                        if not shown or shown.nodeID ~= node.nodeID or shown.state ~= node.state
                            or shown.name ~= node.name or shown.isMapLayerTransition ~= node.isMapLayerTransition
                            or shown.specialIconCostString ~= node.specialIconCostString or shown.useSpecialIcon ~= node.useSpecialIcon
                            or (IsFlightTarget(node) and not pin:IsShown()) then
                            changed = true
                            break
                        end
                    end
                end
                if changed or count ~= map:GetNumActivePinsByTemplate("FlightMap_FlightPointPinTemplate") then
                    local focus = GetMouseFoci()[1]
                    local focusedNode = focus and focus.taxiNodeData
                    local hadTooltip = focusedNode and provider.slotIndexToPin[focusedNode.slotIndex] == focus and GameTooltip:IsOwned(focus)
                    if hadTooltip then GameTooltip:Hide() end
                    provider:RefreshAllData()
                    if hadTooltip then
                        -- The pool can assign a different pin to the node under the cursor.
                        local pin = GetMouseFoci()[1]
                        local data = pin and pin.taxiNodeData
                        if data and provider.slotIndexToPin[data.slotIndex] == pin and pin:IsShown() and pin:IsMouseOver() then
                            pin:OnMouseEnter()
                        end
                    end
                    return provider.slotIndexToPin, true
                end
            end
            return provider.slotIndexToPin
        end
    end
end

local function RefreshHoveredFare(panel)
    local pin = GetMouseFoci()[1]
    if not pin or not GameTooltip:IsOwned(pin) then return end
    for _, previous in ipairs(panel.entries) do
        local slot = previous.slot
        local button = panel.legacyLayout and _G["TaxiButton" .. slot] or panel.routePins and panel.routePins[slot]
        if button == pin then
            if previous.cost ~= TaxiNodeCost(slot) then
                if panel.legacyLayout then
                    TaxiNodeOnButtonEnter(pin)
                else
                    pin.owner:RemoveRouteToPin(pin)
                    pin:OnMouseEnter()
                end
            end
            return
        end
    end
end

local function RedrawClassicMap(map)
    -- Forever only rebuilds its private route coordinates in OnShow, which also plays the opening sound.
    local sfx = GetCVar("Sound_EnableSFX")
    if sfx ~= "1" then
        TaxiFrame_OnShow(map)
        return
    end
    SetCVar("Sound_EnableSFX", "0")
    local ok, err = pcall(TaxiFrame_OnShow, map)
    SetCVar("Sound_EnableSFX", sfx)
    if not ok then error(err, 0) end
end

RefreshEntries = function(panel, resetScroll, nativeMapJustDrawn)
    if panel.map.GetMapID then
        local mapID = panel.map:GetMapID()
        resetScroll = resetScroll or panel.mapID ~= mapID
        panel.mapID = mapID
    end
    local layout = panel.legacyLayout
    local entries, originSlot, modernNodes = Destinations.GetDestinations(panel.map, layout)
    local pinsRedrawn
    if modernNodes then panel.routePins, pinsRedrawn = NativeFlightPins(panel.map, modernNodes, nativeMapJustDrawn) end
    if layout and layout.changed and not nativeMapJustDrawn then
        -- Only Blizzard's renderer updates both the TaxiButtons and their private route coordinates.
        if hoveredEntry and hoveredEntry.frame == panel.map then Destinations.Leave(true) end
        RedrawClassicMap(panel.map)
        if not panel.map:IsShown() then return end -- Blizzard closes a map that has lost all paths.
        local focus = GetMouseFoci()[1]
        if focus then
            for slot = 1, layout.count do
                if focus == _G["TaxiButton" .. slot] and focus:IsShown() and focus:IsMouseOver() then
                    TaxiNodeOnButtonEnter(focus)
                    break
                end
            end
        end
    elseif not nativeMapJustDrawn and not pinsRedrawn then
        RefreshHoveredFare(panel)
    end
    local flight = ns.ResourceBars and ns.ResourceBars.Flight
    local originName = flight and originSlot and TaxiNodeName(originSlot)
    local mapID = layout and layout.mapID or panel.mapID
    local times = panel.timeCache
    -- TimeTo looks up the current master for each call. Reuse its answers while this map stays open.
    if not times or times.mapID ~= mapID or times.originSlot ~= originSlot or times.originName ~= originName or times.flight ~= flight then
        times = { mapID = mapID, originSlot = originSlot, originName = originName, flight = flight }
        panel.timeCache = times
    end
    for _, entry in ipairs(entries) do
        entry.searchText = entry.name
        if entry.zone and entry.name == entry.place then entry.searchText = entry.name .. " " .. entry.zone end
        entry.fare = entry.priceText or (entry.cost and GetMoneyString(entry.cost, true)) or ""
        entry.time = ""
        if originName then
            local slot = entry.slot
            local name, cached = TaxiNodeName(slot), times[slot]
            if not cached or cached.name ~= name then
                local seconds = flight.TimeTo(slot)
                cached = { name = name, text = seconds and flight.Clock(seconds) or "" }
                times[slot] = cached
            end
            entry.time = cached.text
        end
    end
    panel.entries = entries
    SortAndFilter(panel, resetScroll, true)
end

-- A docked list shares one divider with the map. A floating list keeps all four sides.
local function SetPanelEdge(skin, side, opposite, joined)
    local top, bottom = skin["Top" .. side .. "Corner"], skin["Bottom" .. side .. "Corner"]
    top:SetShown(not joined)
    bottom:SetShown(not joined)
    skin[side .. "Edge"]:SetShown(not joined)
    local point = side:upper()
    if joined then
        local _, _, _, _, bottomY = bottom:GetPoint(1)
        skin.TopEdge:SetPoint("TOP" .. point, skin, "TOP" .. point)
        skin.BottomEdge:SetPoint("BOTTOM" .. point, skin, "BOTTOM" .. point, 0, bottomY)
    else
        skin.TopEdge:SetPoint("TOP" .. point, top, "TOP" .. opposite)
        skin.BottomEdge:SetPoint("BOTTOM" .. point, bottom, "BOTTOM" .. opposite)
    end
end

local function SetJoined(body, side)
    if body.joinedSide == side then return end
    body.joinedSide = side
    local inset = body.Inset
    for _, skin in ipairs({body.NineSlice, inset.NineSlice}) do
        SetPanelEdge(skin, "Left", "RIGHT", side == "LEFT")
        SetPanelEdge(skin, "Right", "LEFT", side == "RIGHT")
    end
    -- The stock simple panel reserves header and footer space. Keep just its metal rim.
    inset:SetPoint("TOPLEFT", body, "TOPLEFT", side == "LEFT" and -1 or 4, -4)
    inset:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", side == "RIGHT" and 1 or -4, 4)
end

local function SetTabNormal(toggle)
    toggle:SetNormalAtlas(toggle.atlas .. (toggle.hovered and "hover" or "normal"))
    toggle:GetNormalTexture():SetTexCoord(toggle.mirrored and 1 or 0, toggle.mirrored and 0 or 1, 0, 1)
end

local function SetTabArt(toggle, onRight)
    -- Both stock raid tabs have an open right edge. Mirror the whole texture
    -- on the right of the window so the open edge meets the frame.
    local atlas = expanded and "gm-btnforward-" or "gm-btnback-"
    if toggle.atlas == atlas and toggle.mirrored == onRight then return end
    toggle.atlas, toggle.mirrored = atlas, onRight
    SetTabNormal(toggle)
    toggle:SetPushedAtlas(atlas .. "pressed")
    toggle:GetPushedTexture():SetTexCoord(onRight and 1 or 0, onRight and 0 or 1, 0, 1)
end

local function VerticalInsets(top, bottom, scale)
    local screenTop, screenBottom = UIParent:GetTop() * scale, UIParent:GetBottom() * scale
    local inset = math.min(VERTICAL_INSET, (top - bottom) / 8)
    -- If only a sliver of the map is visible, keep the search field and one row on screen.
    local minHeight = math.min(45 + ROW_HEIGHT, screenTop - screenBottom)
    local panelBottom = math.min(math.max(bottom + inset, screenBottom), screenTop - minHeight)
    local panelTop = math.max(math.min(top - inset, screenTop), panelBottom + minHeight)
    return top - panelTop, panelBottom - bottom
end

local function Position(panel)
    local border = panel.map.BorderFrame or panel.map
    local left, right = border:GetLeft(), border:GetRight()
    local top, bottom = border:GetTop(), border:GetBottom()
    if not left or not right or not top or not bottom then return end
    local scale = UIParent:GetEffectiveScale() / border:GetEffectiveScale()
    local rightRoom, leftRoom = UIParent:GetRight() * scale - right, left - UIParent:GetLeft() * scale
    local onRight = rightRoom >= TAB_WIDTH or rightRoom >= leftRoom
    local room = onRight and rightRoom or leftRoom
    local topInset, bottomInset = VerticalInsets(top, bottom, scale)
    if panel.lastRoom == room and panel.topInset == topInset and panel.bottomInset == bottomInset
        and panel.onRight == onRight and panel.positionedOpen == expanded then return end
    panel.lastRoom, panel.topInset, panel.bottomInset = room, topInset, bottomInset
    panel.onRight, panel.positionedOpen = onRight, expanded

    local outer, inner = onRight and "RIGHT" or "LEFT", onRight and "LEFT" or "RIGHT"
    local direction = onRight and 1 or -1
    local available = room - TAB_WIDTH
    local edge, tabX = border, direction * math.min(0, available)
    if expanded then
        local joined = available >= 214
        local anchor = joined and inner or outer
        local x = joined and 0 or direction * available
        panel:ClearAllPoints()
        panel:SetPoint("TOP" .. anchor, border, "TOP" .. outer, x, -topInset)
        panel:SetPoint("BOTTOM" .. anchor, border, "BOTTOM" .. outer, x, bottomInset)
        local width = joined and math.min(WIDTH, available) or WIDTH
        panel:SetWidth(width)
        panel.content:SetWidth(width - LIST_LEFT - LIST_RIGHT)
        SetJoined(panel.body, joined and inner or false)
        edge, tabX = panel, 0
    end
    panel.toggle:ClearAllPoints()
    local tabY = expanded and 0 or (bottomInset - topInset) / 2
    panel.toggle:SetPoint(inner, edge, outer, tabX, tabY)
    SetTabArt(panel.toggle, onRight)
end

local function Display(panel, resetScroll, nativeMapJustDrawn)
    panel:SetShown(expanded)
    panel.body:SetShown(expanded)
    Position(panel)
    if expanded then
        RefreshEntries(panel, resetScroll, nativeMapJustDrawn)
    else
        panel.pressedEntry = nil
        panel.search:ClearFocus()
        LeaveRow(panel)
    end
end

local function NewPanel(map)
    local panel = CreateFrame("Frame", nil, map)
    panel.map, panel.rows, panel.entries = map, {}, {}
    local border = map.BorderFrame or map
    panel:SetFrameStrata(border:GetFrameStrata())
    panel:SetFrameLevel(border:GetFrameLevel() + 10)
    panel:EnableMouse(true)
    local body = CreateFrame("Frame", nil, panel, "SimplePanelTemplate")
    body:SetAllPoints()
    local controlsLevel = body.NineSlice:GetFrameLevel() + 2
    panel.body = body
    -- Use the same slim side tab as Blizzard's compact raid manager.
    local toggle = CreateFrame("Button", nil, map)
    toggle:SetSize(TAB_WIDTH, 35)
    toggle:SetFrameStrata(border:GetFrameStrata())
    toggle:SetFrameLevel(controlsLevel)
    panel.toggle = toggle
    toggle:SetScript("OnEnter", function(self)
        self.hovered = true
        SetTabNormal(self)
        if not expanded then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(SEARCH)
            GameTooltip:Show()
        end
    end)
    toggle:SetScript("OnLeave", function(self)
        self.hovered = false
        SetTabNormal(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    -- Dragging the title or changing the map scale can move its edge without resizing it.
    local elapsedSinceCheck = 0
    toggle:SetScript("OnUpdate", function(_, elapsed)
        if panel.pendingLeave then LeaveRow(panel) end
        elapsedSinceCheck = elapsedSinceCheck + elapsed
        if elapsedSinceCheck >= 0.1 then
            elapsedSinceCheck = 0
            Position(panel)
        end
    end)
    toggle:SetScript("OnClick", function()
        if GameTooltip:IsOwned(toggle) then GameTooltip:Hide() end
        expanded = not expanded
        Display(panel)
        if expanded then panel.search:SetFocus() end
    end)
    local search = CreateFrame("EditBox", nil, body, "SearchBoxTemplate")
    search:SetFrameLevel(controlsLevel)
    search:SetHeight(20)
    search:SetPoint("TOPLEFT", LIST_LEFT + 6, -9)
    search:SetPoint("TOPRIGHT", -9, -9)
    search:SetAutoFocus(false)
    panel.search = search
    local scroll = CreateFrame("ScrollFrame", nil, body)
    scroll:SetPoint("TOPLEFT", search, "BOTTOMLEFT", -6, -7)
    scroll:SetPoint("BOTTOMRIGHT", -LIST_RIGHT, 9)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(WIDTH - LIST_LEFT - LIST_RIGHT, 1)
    scroll:SetScrollChild(content)
    panel.scroll, panel.content = scroll, content
    ns.SettingsPanel.AttachScrollLine(scroll, body, ROW_HEIGHT)
    local empty = body:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    empty:SetPoint("TOPLEFT", scroll, "TOPLEFT", 4, -9)
    empty:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", -4, -9)
    empty:SetJustifyH("LEFT")
    empty:SetText(ns.L["Nothing matches your search."])
    panel.empty = empty
    search:HookScript("OnTextChanged", function() if body:IsVisible() then FilterRows(panel, true) end end)
    panels[map] = panel
    return panel
end

function Destinations:ShouldLoad()
    local tweaks = ns.db.profile.tweaks
    return tweaks.enabled ~= false and tweaks.flightDestinations == true
end

local function HideList(map)
    local panel = panels[map]
    if not panel or not panel.toggle:IsShown() then return end
    panel.pressedEntry = nil
    LeaveRow(panel)
    if GameTooltip:IsOwned(panel.toggle) then GameTooltip:Hide() end
    panel.toggle:Hide()
    panel:Hide()
    panel.search:ClearFocus()
    panel.search:SetText("")
    panel.entries, panel.routePins, panel.timeCache = {}, nil, nil
    for _, row in ipairs(panel.rows) do row.entry = nil end
end

local function UpdateMap(map, nativeMapJustDrawn)
    if not map then return end
    if map:IsShown() and Destinations:ShouldLoad() then
        local panel = panels[map]
        if panel and panel.toggle:IsShown() then return end
        panel = panel or NewPanel(map)
        if map == _G.TaxiFrame then panel.legacyLayout = {} end
        panel.toggle:Show()
        Display(panel, true, nativeMapJustDrawn)
    else
        HideList(map)
    end
end

local function AttachMap(map)
    if not map then return end
    map:HookScript("OnShow", function(self) UpdateMap(self, true) end)
    map:HookScript("OnHide", HideList)
    local function SizeChanged()
        local panel = panels[map]
        if panel and panel.toggle:IsVisible() then Position(panel) end
    end
    map:HookScript("OnSizeChanged", SizeChanged)
    map:HookScript("OnDragStop", SizeChanged)
    if map.SetMapID then
        local function MapRedrawn()
            local panel = panels[map]
            if panel and panel.body:IsVisible() then RefreshEntries(panel, false, true) end
        end
        hooksecurefunc(map, "SetMapID", MapRedrawn)
        hooksecurefunc(map, "RefreshAllDataProviders", MapRedrawn)
    end
    if map:IsShown() then UpdateMap(map) end
end

ns.modules.FlightDestinations = Destinations
function Destinations:Refresh()
    if not self.initialized then
        if self:ShouldLoad() then self:Init() end
        return
    end
    UpdateMap(_G.TaxiFrame)
    UpdateMap(_G.FlightMapFrame)
end

function Destinations:Init()
    if self.initialized then return end
    self.initialized = true
    EventUtil.ContinueOnAddOnLoaded("Blizzard_UIPanels_Game", function() AttachMap(_G.TaxiFrame) end)
    EventUtil.ContinueOnAddOnLoaded("Blizzard_FlightMap", function() AttachMap(_G.FlightMapFrame) end)
    local events = CreateFrame("Frame")
    events:RegisterEvent("TAXI_NODE_STATUS_CHANGED")
    events:RegisterEvent("DISPLAY_SIZE_CHANGED")
    events:SetScript("OnEvent", function(_, event)
        for _, panel in pairs(panels) do
            if panel.toggle:IsVisible() then
                if event == "DISPLAY_SIZE_CHANGED" then Position(panel)
                elseif panel.body:IsShown() then RefreshEntries(panel) end
            end
        end
    end)
end
