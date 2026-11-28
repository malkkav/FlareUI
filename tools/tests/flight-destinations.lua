-- Run from the repository root with LuaJIT.
local H = dofile("tools/tests/perf-helpers.lua")
local noOp = function() end
local function frame()
    return {
        shown = false, IsShown = function(self) return self.shown end,
        RegisterEvent = noOp, SetScript = noOp, HookScript = noOp,
    }
end

local state = { Current = 0, Reachable = 1, Unreachable = 2 }
local nodes = {
    { name = "Стальгорн",        kind = "CURRENT",     cost = 0 },
    { name = "Штормград, Элвинн", kind = "REACHABLE",   cost = 540 },
    { name = "Дальний пункт",    kind = "DISTANT",     cost = 400 },
    { name = "Закрытый пункт",   kind = "UNREACHABLE", cost = 400 },
    { name = "Каранос",          kind = "REACHABLE",   cost = 0 },
}
local mapID = 42
local staticMapNodes = {}
local pin = {
    name = "Гавань", nodeID = 90, slotIndex = 2, state = state.Reachable,
    position = { GetXY = function() return 0.4, 0.6 end },
}
local modernNodes = {
    pin,
    { name = "Здесь", nodeID = 91, slotIndex = 1, state = state.Current },
    { name = "Переход", nodeID = 92, slotIndex = 3, state = state.Reachable, isMapLayerTransition = true },
    { name = "Закрыт", nodeID = 93, slotIndex = 4, state = state.Unreachable },
}
local departures = {}
local function fold(text)
    -- Client double for the native case-insensitive UTF-8 comparator, for the letters in our queries.
    return (text:lower():gsub("Ш", "ш"):gsub("Т", "т"):gsub("О", "о"):gsub("Р", "р")
        :gsub("М", "м"):gsub("Э", "э"):gsub("Л", "л"):gsub("В", "в"):gsub("И", "и")
        :gsub("Н", "н"))
end
local env = setmetatable({
    CreateFrame = frame, EventUtil = { ContinueOnAddOnLoaded = noOp },
    SetCVar = function() error("the flight list changed a game setting") end,
    GetLocale = function() return "enUS" end,
    NumTaxiNodes = function() return #nodes end,
    TaxiNodeName = function(slot) return nodes[slot].name end,
    TaxiNodeGetType = function(slot) return nodes[slot].kind end,
    TaxiNodeCost = function(slot) return nodes[slot].cost end,
    TaxiNodePosition = function(slot) return nodes[slot].x, nodes[slot].y end,
    TakeTaxiNode = function(slot) departures[#departures + 1] = slot end,
    Enum = { FlightPathState = state, UIMapType = { Continent = 2, Zone = 3, Dungeon = 4, Micro = 5 } },
    GetTaxiMapID = function() return mapID end,
    C_Map = {
        GetMapInfo = function(id) return { mapID = id, mapType = 2 } end,
        GetMapInfoAtPosition = function(id, x, y)
            assert(id == mapID and x == 0.4 and y == 0.6)
            return { name = "Побережье", mapType = 3 }
        end,
    },
    C_TaxiMap = {
        GetAllTaxiNodes = function(id) return id == mapID and modernNodes or {} end,
        GetTaxiNodesForMap = function(id) return staticMapNodes[id] or {} end,
    },
    GetCoinTextureString = tostring, GetMoneyString = tostring,
    HIGHLIGHT_FONT_COLOR = { GetRGB = function() return 1, 1, 1 end },
    RED_FONT_COLOR = { GetRGB = function() return 1, 0.1, 0.1 end },
    strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end,
    strlenutf8 = function(s) return select(2, s:gsub("[^\128-\191]", "")) end,
    strcmputf8i = function(a, b)
        a, b = fold(a), fold(b)
        return a == b and 0 or (a < b and -1 or 1)
    end,
}, { __index = _G })
env._G = env
local ns = { L = setmetatable({}, { __index = function(_, key) return key end }), modules = {} }
local activeGUID = "Player-1"
local characters = { ["Player-1"] = {}, ["Player-2"] = {} }
ns.CharDB = function() return characters[activeGUID] end
local tweaks = {}
ns.db = { profile = { tweaks = tweaks } }
local chunk = assert(loadstring(H.read("Modules/FlightDestinations.lua"), "@Modules/FlightDestinations.lua"))
setfenv(chunk, env)("FlareUI", ns)

local D = assert(ns.FlightDestinations)
local classic, modern = frame(), frame()
env.TaxiFrame, env.FlightMapFrame = classic, modern
modern.GetMapID = function() return mapID end
classic.shown = true
local entries = D.GetDestinations(classic, true)
assert(#entries == 2, "legacy list includes only reachable destinations")
local city = entries[1].slot == 2 and entries[1] or entries[2]
assert(city.name == nodes[2].name and city.cost == 540, "legacy destination keeps its native price and name")
assert(city.place == "Штормград" and city.zone == "Элвинн", "legacy localized place and zone suffix")
assert(D.Matches(city.name, "шторм") and D.Matches(city.name, "ТОРМ") and D.Matches(city.name, "элви"))
assert(D.Matches(city.name, "") and not D.Matches(city.name, "[") and not D.Matches(city.name, "Танарис"))
assert(D.CanFly(classic, city))
local classicPin = frame()
classicPin.shown = true
classicPin.LockHighlight = function(self) self.lit = true end
classicPin.UnlockHighlight = function(self) self.lit = false end
env.TaxiButton2 = classicPin
local highlighted, cleared
env.TaxiNodeOnButtonEnter = function(button) highlighted = button end
env.DrawOneHopLines = function() cleared = true end
env.TaxiFrame_OnShow = function() error("the flight list forced the native map to open") end
env.GameTooltip = { IsOwned = function(_, owner) return owner == classicPin end, Hide = noOp }
assert(D.Hover(classic, city) and highlighted == classicPin and classicPin.lit and #departures == 0)
D.Leave()
assert(not classicPin.lit and cleared, "leaving the row restores the native map routes")
D.Fly(classic, city)
assert(#departures == 1 and departures[1] == 2, "selection dispatches the destination's native slot")
nodes[2].kind = "UNREACHABLE"
D.Fly(classic, city)
nodes[2].kind, nodes[2].name = "REACHABLE", "Другой город"
D.Fly(classic, city)
nodes[2].name = city.name
classic.shown = false
D.Fly(classic, city)
assert(#departures == 1, "unreachable, reassigned and closed routes must not dispatch")

modern.shown = true
entries = D.GetDestinations(modern)
assert(#entries == 1, "modern list excludes transitions, current location and unreachable nodes")
local harbor = entries[1]
assert(harbor.name == pin.name and harbor.nodeID == pin.nodeID and harbor.slot == pin.slotIndex)
assert(harbor.zone == "Побережье", "modern position provides the zone for a name without a suffix")
local modernPin = frame()
modernPin.shown, modernPin.taxiNodeData = true, pin
modernPin.atlasFormat, modernPin.Icon, modernPin.SetFlightPathStyle = "%s", {SetAtlas = noOp}, noOp
modernPin.owner = {
    slotIndexToPin = {[pin.slotIndex] = modernPin},
    HighlightRouteToPin = function(_, p) highlighted = p end,
    RemoveRouteToPin = function(_, p) cleared = p end,
}
function modern:EnumeratePinsByTemplate()
    return function(_, previous) if not previous then return modernPin end end
end
assert(D.Hover(modern, harbor) and highlighted == modernPin and #departures == 1)
D.Leave()
assert(cleared == modernPin)
D.Hover(modern, harbor)
cleared = nil
modernPin.taxiNodeData = modernNodes[2]
D.Leave()
assert(not cleared, "a recycled pin must not lose its new highlight")
D.Fly(modern, harbor)
assert(#departures == 2 and departures[2] == pin.slotIndex)
pin.nodeID = 94
D.Fly(modern, harbor)
pin.nodeID = 90
mapID = 43
D.Fly(modern, harbor)
mapID = 42
pin.isMapLayerTransition = true
D.Fly(modern, harbor)
assert(#departures == 2, "stale node identity, changed map and layer transitions must not dispatch")
pin.isMapLayerTransition = false
print("PASS: reachable flight destinations, Cyrillic search and safe native selection on both flight maps")

-- Exercise the registered hooks with the anchor points from the two native map templates.
local Widget = {}
Widget.__index = Widget
local panel
local mouseTarget
local eventFrames = {}
env.GetMouseFoci = function() return { mouseTarget } end
local function widget(kind, _, parent, template)
    local w = setmetatable({ parent = parent, template = template, shown = true, scripts = {}, points = {}, value = "" }, Widget)
    if kind == "Frame" and parent and (parent == env.TaxiFrame or parent == env.FlightMapFrame) then
        panel, parent.destinationPanel = w, w
    end
    local metal = template == "SimplePanelTemplate"
    if metal or template == "InsetFrameTemplate" then
        w.Bg, w.NineSlice = widget(nil, nil, w), widget(nil, nil, w)
        w.Bg:SetPoint("TOPLEFT", 0, metal and -6 or 0)
        w.Bg:SetPoint("BOTTOMRIGHT", metal and -2 or 0, metal and 3 or 0)
        if metal then
            w.Inset = widget("Frame", nil, w, "InsetFrameTemplate")
            w.Inset:SetPoint("TOPLEFT", 4, -26)
            w.Inset:SetPoint("BOTTOMRIGHT", -6, 26)
        end
        local skin = w.NineSlice
        for _, side in ipairs({ "Left", "Right" }) do
            local point = side:upper()
            local x = metal and (side == "Left" and -5 or 2) or 0
            skin["Top" .. side .. "Corner"] = widget(nil, nil, skin)
            skin["Bottom" .. side .. "Corner"] = widget(nil, nil, skin)
            skin["Top" .. side .. "Corner"]:SetPoint("TOP" .. point, x, 0)
            skin["Bottom" .. side .. "Corner"]:SetPoint("BOTTOM" .. point, x, metal and -3 or -1)
            skin[side .. "Edge"] = widget(nil, nil, skin)
        end
        skin.TopEdge, skin.BottomEdge = widget(nil, nil, skin), widget(nil, nil, skin)
        skin.TopEdge:SetPoint("TOPLEFT", skin.TopLeftCorner, "TOPRIGHT")
        skin.TopEdge:SetPoint("TOPRIGHT", skin.TopRightCorner, "TOPLEFT")
        skin.BottomEdge:SetPoint("BOTTOMLEFT", skin.BottomLeftCorner, "BOTTOMRIGHT")
        skin.BottomEdge:SetPoint("BOTTOMRIGHT", skin.BottomRightCorner, "BOTTOMLEFT")
    end
    return w
end
function Widget:SetScript(event, fn) self.scripts[event] = fn end
Widget.HookScript = Widget.SetScript
function Widget:Fire(event, ...) if self.scripts[event] then self.scripts[event](self, ...) end end
function Widget:RegisterEvent(event) eventFrames[event] = self end
function Widget:IsShown() return self.shown end
function Widget:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function Widget:IsMouseOver()
    local focus = mouseTarget
    while focus do
        if focus == self then return true end
        focus = focus.parent
    end
    return false
end
function Widget:SetShown(shown)
    if self.shown ~= shown then self.shown = shown; self:Fire(shown and "OnShow" or "OnHide") end
end
function Widget:Show() self:SetShown(true) end
function Widget:Hide() self:SetShown(false) end
function Widget:SetText(text) self.value = text; self:Fire("OnTextChanged") end
function Widget:GetText() return self.value end
function Widget:SetFocus() self.focused = true end
function Widget:ClearFocus() self.focused = false end
function Widget:SetSize(w, h) self.width, self.height = w, h end
function Widget:SetWidth(w) self.width = w end
function Widget:SetHeight(h) self.height = h end
function Widget:GetWidth() return self.width or (self.parent and self.parent:GetWidth()) or 0 end
function Widget:GetHeight() return self.height or (self.parent and self.parent:GetHeight()) or 0 end
function Widget:GetRight() return self.right or (self.parent and self.parent:GetRight()) end
function Widget:GetLeft() return self:GetRight() - self:GetWidth() end
function Widget:GetBottom() return self.bottom or (self.parent and self.parent:GetBottom()) or 0 end
function Widget:GetTop() return self:GetBottom() + self:GetHeight() end
function Widget:GetFrameStrata() return "MEDIUM" end
function Widget:GetFrameLevel() return 1 end
function Widget:GetEffectiveScale() return self.scale or (self.parent and self.parent:GetEffectiveScale()) or 1 end
function Widget:GetStringWidth() return #self.value * 6 end
Widget.GetUnboundedStringWidth = Widget.GetStringWidth
function Widget:SetMaxLines(lines) self.maxLines = lines end
function Widget:IsTruncated()
    return self.truncated or (self.maxLines == 1 and self.width and self.width > 0 and self:GetStringWidth() > self.width) or false
end
function Widget:SetTexCoord(left, right, top, bottom) self.uv = { left, right, top, bottom } end
function Widget:GetNormalTexture() return self.normalTexture end
function Widget:GetPushedTexture() return self.pushedTexture end
function Widget:SetHighlightAtlas(atlas) self.highlightAtlas = atlas end
function Widget:SetNormalAtlas(atlas)
    self.normalAtlas = atlas
    self.normalTexture = self.normalTexture or widget(nil, nil, self)
    self.normalTexture:SetTexCoord(0, 1, 0, 1)
end
function Widget:SetPushedAtlas(atlas)
    self.pushedAtlas = atlas
    self.pushedTexture = self.pushedTexture or widget(nil, nil, self)
    self.pushedTexture:SetTexCoord(0, 1, 0, 1)
end
function Widget:GetVerticalScroll() return self.offset or 0 end
function Widget:SetVerticalScroll(offset) self.offset = offset end
function Widget:SetPoint(anchor, relative, relativePoint, x, y)
    if type(relative) ~= "table" then
        x, y, relative, relativePoint = relative, relativePoint, self.parent, anchor
    end
    self.points[anchor] = { relative = relative, point = relativePoint, x = x or 0, y = y or 0 }
end
function Widget:GetPoint()
    local key, p = next(self.points)
    if p then return key, p.relative, p.point, p.x, p.y end
end
function Widget:ClearAllPoints() self.points = {} end
function Widget:CreateFontString() return widget(nil, nil, self) end
Widget.CreateTexture = Widget.CreateFontString
Widget.GetHighlightTexture = Widget.CreateFontString
for _, method in ipairs({ "SetFrameStrata",
    "SetFrameLevel", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "EnableMouse",
    "SetAllPoints", "SetAutoFocus", "SetScrollChild", "SetJustifyH", "SetWordWrap",
    "SetTexture", "SetAlpha", "SetVertexColor", "SetHighlightTexture",
    "RegisterForClicks" }) do Widget[method] = noOp end
env.CreateFrame, env.UIParent, env.SEARCH = widget, widget(), "Поиск"
env.BATTLE_PET_FAVORITE, env.BATTLE_PET_UNFAVORITE = "Add to Favorites", "Remove from Favorites"
env.UIParent.right, env.UIParent.width = 1280, 1280
env.UIParent.height = 768
local tooltip = { lines = {} }
function tooltip:SetOwner(owner) self.owner, self.lines = owner, {} end
function tooltip:IsOwned(owner) return self.owner == owner end
function tooltip:SetText(text) self.lines = { text } end
function tooltip:AddLine(text) self.lines[#self.lines + 1] = text end
function tooltip:Show() self.shown = true end
function tooltip:Hide() self.shown, self.owner = false, nil end
env.GameTooltip = tooltip
function Widget:SetTextColor(r, g, b) self.textColor = { r, g, b } end
env.GameTooltip_AddColoredLine = function(tip, text, color, wrap)
    tip:AddLine(text)
    tip.specialColor, tip.specialWrap = color, wrap
end
env.EventUtil.ContinueOnAddOnLoaded = function(_, callback) callback() end
ns.SettingsPanel = { AttachScrollLine = function(scroll, _, step) scroll.lineStep = step end }
-- Looking up a fare or drawing a row must never depend on the flight timer.
ns.ResourceBars = setmetatable({}, { __index = function() error("the flight list accessed the flight timer") end })
local routeLookups = 0
env.TaxiNodeGetType = function(slot)
    routeLookups = routeLookups + 1
    return nodes[slot].kind
end
local map = widget()
map.right, map.shown, map.height, map.width = 800, false, 580, 590
local modernMap = widget()
modernMap.right, modernMap.shown, modernMap.height, modernMap.width = 900, false, 689, 620
modernMap.BorderFrame = widget(nil, nil, modernMap)
modernMap.GetMapID = function() return mapID end
modernMap.SetMapID = function(_, id) mapID = id end
modernMap.RefreshAllDataProviders = function(self)
    if self.redrawFlightPins then self:redrawFlightPins() end
end
env.hooksecurefunc = function(object, key, hook)
    local original = object[key]
    object[key] = function(self, ...)
        original(self, ...)
        hook(self, ...)
    end
end
env.TaxiFrame, env.FlightMapFrame = map, modernMap
local function checkTab(handle, edge, side, expanded)
    local right = side == "RIGHT"
    local anchor = assert(handle.points[right and "LEFT" or "RIGHT"], "the tab attaches by its inner edge")
    assert(anchor.relative == edge and anchor.point == side and anchor.x == 0 and anchor.y == 0,
        "the tab sits entirely outside, centered on the edge")
    assert(handle:IsVisible() and handle:GetWidth() == 16 and handle:GetHeight() == 35)
    local atlas = expanded and "gm-btnforward-" or "gm-btnback-"
    local function checkArt(suffix)
        assert(handle.normalAtlas == atlas .. suffix and handle.pushedAtlas == atlas .. "pressed")
        for _, texture in ipairs({handle:GetNormalTexture(), handle:GetPushedTexture()}) do
            local uv = texture.uv
            assert(uv[1] == (right and 1 or 0) and uv[2] == (right and 0 or 1) and uv[3] == 0 and uv[4] == 1,
                "the native arrow points along travel and its open edge faces the panel")
        end
    end
    checkArt("normal")
    handle:Fire("OnEnter")
    checkArt("hover")
    handle:Fire("OnLeave")
    checkArt("normal")
end

local function checkBorder(chrome, joined)
    assert(chrome.template == "SimplePanelTemplate" and not chrome.CloseButton and not chrome.TitleBg
        and chrome.Inset.template == "InsetFrameTemplate", "the list has Blizzard's outer metal frame and marble inset")
    local top, bottom = chrome.Inset.points.TOPLEFT, chrome.Inset.points.BOTTOMRIGHT
    assert(top.x == (joined == "LEFT" and -1 or 4) and bottom.x == (joined == "RIGHT" and 1 or -4)
        and top.y == -4 and bottom.y == 4, "the inset fills the panel up to the shared map divider")
    for _, skin in ipairs({chrome.NineSlice, chrome.Inset.NineSlice}) do
        for _, side in ipairs({"Left", "Right"}) do
            local point = side:upper()
            local docked = point == joined
            local upper, lower = skin["Top" .. side .. "Corner"], skin["Bottom" .. side .. "Corner"]
            assert(skin[side .. "Edge"]:IsShown() == (not docked) and upper:IsShown() == (not docked)
                and lower:IsShown() == (not docked), "both borders stay visible on every free edge")
            local topEdge, bottomEdge = skin.TopEdge.points["TOP" .. point], skin.BottomEdge.points["BOTTOM" .. point]
            if docked then
                assert(topEdge.relative == skin and topEdge.y == 0 and bottomEdge.relative == skin
                    and bottomEdge.y == (skin == chrome.NineSlice and -3 or -1),
                    "each horizontal border meets the divider at its native height")
            else
                assert(topEdge.relative == upper and bottomEdge.relative == lower, "free edges retain their native corners")
            end
        end
    end
end

local function checkOpenExtension(drawer, owner, opensLeft)
    local near, far = opensLeft and "RIGHT" or "LEFT", opensLeft and "LEFT" or "RIGHT"
    local top = assert(drawer.points["TOP" .. near])
    local bottom = assert(drawer.points["BOTTOM" .. near])
    local margin = math.min(64, owner:GetHeight() / 8)
    assert(top.relative == (owner.BorderFrame or owner) and top.point == "TOP" .. far and top.x == 0 and top.y == -margin,
        "the list must dock against the " .. far .. " edge of the map")
    assert(bottom.relative == top.relative and bottom.point == "BOTTOM" .. far and bottom.x == 0 and bottom.y == margin,
        "the docked list has equal upper and lower margins against the native map")
    local chrome = drawer.body
    checkBorder(chrome, near)
    local search = drawer.search
    local searchLeft, searchRight = search.points.TOPLEFT, search.points.TOPRIGHT
    assert(search:IsVisible() and search.template == "SearchBoxTemplate" and search:GetHeight() == 20)
    assert(searchLeft.relative == chrome and searchRight.relative == chrome and searchLeft.y == -9
        and searchRight.y == searchLeft.y, "the search field starts just inside the upper border")
    local listTop = drawer.scroll.points.TOPLEFT
    assert(listTop.relative == search and listTop.point == "BOTTOMLEFT" and listTop.y == -7)
    assert(drawer.content:GetWidth() == drawer:GetWidth() + drawer.scroll.points.BOTTOMRIGHT.x - (searchLeft.x + listTop.x),
        "the row layout fits the viewport")
    checkTab(drawer.toggle, drawer, far, true)
end
assert(not D:ShouldLoad(), "profiles without a saved flight list setting default to disabled")
if D:ShouldLoad() then D:Init() end
map:Show()
assert(map:IsVisible() and (not panel or (not panel:IsVisible() and not panel.toggle:IsVisible())) and routeLookups == 0,
    "a disabled profile opens the native map without the list or any route lookups")
tweaks.flightDestinations = false
assert(not D:ShouldLoad(), "a saved disabled setting stays disabled")
tweaks.flightDestinations = true
assert(D:ShouldLoad(), "explicitly enabling the flight list opts into the panel")
D:Refresh()
assert(panel:IsVisible() and panel.body:IsVisible() and #panel.entries == 2)
map:Hide()
map:Show()
checkOpenExtension(panel, map)
assert(map:GetHeight() == 580 and map:GetWidth() == 590 and next(map.points) == nil, "laying out the list preserves the map")
assert(panel.rows[1].entry.place == "Каранос" and panel.rows[2].entry.place == "Штормград",
    "destinations are sorted by their localized place names")
assert(panel.rows[2].fare:GetText() == "540" and panel.rows[2].time == nil and panel.rows[2].entry.time == nil,
    "destination rows show the fare without a flight duration")
assert(panel.rows[1].fare:GetText() ~= "" and D.CanFly(map, panel.rows[1].entry))

local function checkDrawerBounds(expectedTop, expectedBottom)
    panel.toggle:Fire("OnUpdate", 0.2)
    local upper = panel.points.TOPLEFT or panel.points.TOPRIGHT
    local lower = panel.points.BOTTOMLEFT or panel.points.BOTTOMRIGHT
    assert(map:GetTop() + upper.y == expectedTop and map:GetBottom() + lower.y == expectedBottom,
        "the scroll viewport must follow the visible part of the scaled map")
end
-- At 200%, the 768-unit screen spans only 384 units in the map's coordinates.
map.height, map.scale, map.bottom = 608, 2, -112
checkDrawerBounds(384, 0)
map.height, map.bottom = 320, -60
checkDrawerBounds(220, 0)
map.bottom = 200
checkDrawerBounds(384, 240)
map.bottom = 370
checkDrawerBounds(384, 302)
panel.toggle:Fire("OnClick")
local tabAnchor = panel.toggle.points.LEFT or panel.toggle.points.RIGHT
assert(map:GetBottom() + map:GetHeight() / 2 + tabAnchor.y == 343,
    "the collapsed tab remains at the visible list's center when the map center is off-screen")
panel.toggle:Fire("OnClick")
map.height, map.scale, map.bottom = 580, 1, 0
panel.toggle:Fire("OnUpdate", 0.2)
checkOpenExtension(panel, map)

map.right = env.UIParent.right - 230
panel.toggle:Fire("OnUpdate", 0.2)
checkOpenExtension(panel, map)
assert(panel:GetWidth() == 214, "minimum docked width reserves the remaining 16 units for the outside tab")
map.right = 1250
panel.toggle:Fire("OnUpdate", 0.2)
checkOpenExtension(panel, map, true)
panel.toggle:Fire("OnClick")
checkTab(panel.toggle, map, "LEFT", false)
panel.toggle:Fire("OnClick")
checkOpenExtension(panel, map, true)

-- With only 30 units on the right, 230 on the left fits both the list and its tab.
map.width = map.right - 230
map:Fire("OnSizeChanged")
checkOpenExtension(panel, map, true)
assert(panel:GetWidth() == 214)
map.width = map.width + 1
map:Fire("OnSizeChanged")
local fallback = assert(panel.points.TOPRIGHT)
assert(map.right + fallback.x + panel.toggle:GetWidth() <= env.UIParent.right
    and panel.points.BOTTOMRIGHT.x == fallback.x and fallback.y == -64 and panel.points.BOTTOMRIGHT.y == 64,
    "the overlay leaves the tab visible and keeps both margins")
checkBorder(panel.body)
checkTab(panel.toggle, panel, "RIGHT", true)
map.height = 360
map:Fire("OnSizeChanged")
assert(panel.points.BOTTOMRIGHT.y == 45 and panel.points.TOPRIGHT.y == -45, "shorter maps keep a usable list height")
map.width, map.right = 590, 800
panel.toggle:Fire("OnUpdate", 0.2)
checkOpenExtension(panel, map)
panel.toggle:Fire("OnClick")
assert(not panel:IsVisible() and not panel.body:IsVisible() and panel.toggle:IsVisible())
checkTab(panel.toggle, map, "RIGHT", false)
panel.toggle:Fire("OnEnter")
assert(tooltip:IsOwned(panel.toggle))
tweaks.flightDestinations = false
D:Refresh()
assert(map:IsVisible() and not panel:IsVisible() and not panel.toggle:IsVisible() and not tooltip.shown,
    "disabling a collapsed drawer removes the standalone tab and its tooltip")
tweaks.flightDestinations = true
D:Refresh()
assert(not panel:IsVisible() and panel.toggle:IsVisible(), "re-enabling a collapsed drawer restores only its tab")
panel.toggle:Fire("OnLeave")
map:Hide()
map:Show()
map.width, map.right = 1280, 1280
panel.toggle:Fire("OnUpdate", 0.2)
local rightAnchor = panel.toggle.points.LEFT
local leftAnchor = panel.toggle.points.RIGHT
local tabLeft = rightAnchor and (map:GetRight() + rightAnchor.x)
    or (map:GetLeft() + leftAnchor.x - panel.toggle:GetWidth())
assert(tabLeft >= 0 and tabLeft + panel.toggle:GetWidth() <= env.UIParent:GetRight(),
    "when the map fills the screen, the complete toggle remains reachable")
map.width = 590
map.right = env.UIParent.right + 20
panel.toggle:Fire("OnUpdate", 0.2)
checkTab(panel.toggle, map, "LEFT", false)
panel.toggle:Fire("OnClick")
checkOpenExtension(panel, map, true)
assert(panel.body:IsVisible() and panel.search.focused, "reopening the tab focuses search")
panel.rows[2]:Fire("OnEnter")
assert(classicPin.lit, "opening the map with the list collapsed still captures the native draw")
panel.rows[2]:Fire("OnLeave")
panel.scroll:SetHeight(35)
panel.scroll:SetVerticalScroll(12)
D:Refresh()
assert(panel.scroll:GetVerticalScroll() == 12, "reapplying an unchanged setting preserves the player's scroll position")
eventFrames.TAXI_NODE_STATUS_CHANGED:Fire("OnEvent", "TAXI_NODE_STATUS_CHANGED")
assert(panel.scroll:GetVerticalScroll() == 12, "refreshing route availability preserves the current scroll position")
assert(panel.content:GetHeight() > panel.scroll:GetHeight() and panel.scroll.lineStep == panel.rows[1]:GetHeight(),
    "an overflowing destination list uses the shared scrollbar with a one-row step")
local row = panel.rows[1]
assert(row.entry.slot == 5 and row.entry.cost == 0)
row:Fire("OnMouseDown", "LeftButton")
nodes[5].kind = "UNREACHABLE"
eventFrames.TAXI_NODE_STATUS_CHANGED:Fire("OnEvent", "TAXI_NODE_STATUS_CHANGED")
assert(row.entry.slot == 2 and row.entry.cost == 540, "the other reachable destination moved into the pressed row")
row:Fire("OnClick", "LeftButton")
assert(#departures == 2, "releasing a recycled row must not buy a different flight")
assert(panel.scroll:GetVerticalScroll() == panel.content:GetHeight() - panel.scroll:GetHeight(),
    "when routes disappear, scroll position clamps to the new bottom of the list")
nodes[5].kind = "REACHABLE"
eventFrames.TAXI_NODE_STATUS_CHANGED:Fire("OnEvent", "TAXI_NODE_STATUS_CHANGED")
panel.search:SetText("элви шторм")
assert(panel.scroll:GetVerticalScroll() == 0, "a new search starts at the top")
assert(row:IsVisible() and row.place:GetText() == "Штормград" and row.fare:GetText() == "540")
assert(not panel.rows[2]:IsVisible() and not panel.empty:IsVisible(), "query searches zone and place together")
row:Fire("OnEnter")
assert(classicPin.lit and #departures == 2, "pointing at a row highlights without flying")
assert(not tooltip.shown, "a full row needs no additional tooltip")
row:Fire("OnLeave")
row.zone.truncated = true
row:Fire("OnEnter")
assert(tooltip.shown and tooltip:IsOwned(row) and table.concat(tooltip.lines, " "):find("Элвинн", 1, true),
    "hovering a clipped zone reveals its full name")
mouseTarget = row
D:Refresh()
mouseTarget = nil
assert(panel.search.focused and panel.search:GetText() == "элви шторм" and tooltip:IsOwned(row) and classicPin.lit,
    "reapplying an unchanged setting leaves the player's search and route hover intact")
row:Fire("OnMouseDown", "LeftButton")
tweaks.flightDestinations = false
D:Refresh()
assert(map:IsVisible() and not panel:IsVisible() and not panel.toggle:IsVisible(), "disabling leaves the native map usable")
assert(not panel.search.focused and not tooltip.shown and not classicPin.lit, "disabling releases focus, tooltip and route highlight")
local lookupsWhileDisabled = routeLookups
map:Hide()
map:Show()
eventFrames.TAXI_NODE_STATUS_CHANGED:Fire("OnEvent", "TAXI_NODE_STATUS_CHANGED")
row:Fire("OnClick", "LeftButton")
assert(not panel:IsVisible() and not panel.toggle:IsVisible() and routeLookups == lookupsWhileDisabled and #departures == 2,
    "reopening a disabled map and receiving route updates cannot revive the list or a stale selection")
tweaks.flightDestinations = true
D:Refresh()
assert(panel:IsVisible() and panel.toggle:IsVisible() and #panel.entries == 2 and panel.search:GetText() == "",
    "live enabling on an open map restores the searchable list")
panel.rows[2]:Fire("OnEnter")
assert(not classicPin.lit, "live enabling cannot assume that the classic map's current pins match live data")
panel.rows[2]:Fire("OnLeave")
map:Hide()
map:Show()
row.zone.truncated = false
panel.search:SetText("нет такого места")
assert(panel.empty:IsVisible() and not row:IsVisible() and not classicPin.lit and not tooltip.shown,
    "empty search clears the route and clipped-name tooltip from the previous row")
row:Fire("OnClick", "LeftButton")
assert(#departures == 2, "recycled hidden rows cannot dispatch a flight")
panel.search:SetText("ТОРМ")
mouseTarget = row
panel.search:SetText("Штормград, Элвинн")
assert(classicPin.lit, "filtering restores the hovered destination even when the pointer does not move")
row:Fire("OnMouseDown", "LeftButton")
eventFrames.TAXI_NODE_STATUS_CHANGED:Fire("OnEvent", "TAXI_NODE_STATUS_CHANGED")
row:Fire("OnClick", "LeftButton")
assert(#departures == 3 and departures[3] == 2, "refreshing the same destination during a click preserves the selection")
map:Hide()
assert(not panel:IsVisible() and panel.search:GetText() == "" and not panel.search.focused)
map:Show()
assert(panel.rows[2]:IsVisible() and not panel.empty:IsVisible(), "a fresh visit starts with the full list")
assert(next(characters[activeGUID]) == nil, "browsing, filtering and flying do not create favorites data")
mouseTarget = nil
local originalNodes = nodes
nodes = {}
for i = 1, 50 do
    nodes[i] = { name = ("Stop %02d, Zone"):format(i), kind = "REACHABLE", cost = 1 }
end
nodes[51] = { name = "Origin, Zone", kind = "CURRENT", cost = 0 }
map:Hide()
routeLookups = 0
map:Show()
assert(routeLookups == #nodes, "opening the list reads each taxi slot's type once")
routeLookups = 0
eventFrames.TAXI_NODE_STATUS_CHANGED:Fire("OnEvent", "TAXI_NODE_STATUS_CHANGED")
assert(#panel.entries == 50 and routeLookups == #nodes, "the list enumerates all 50 destinations in one pass")
print(("PASS: the list refreshed 50 destinations with %d slot checks"):format(routeLookups))
do
    local firstPin = frame()
    firstPin.shown = true
    firstPin.LockHighlight, firstPin.UnlockHighlight = classicPin.LockHighlight, classicPin.UnlockHighlight
    env.TaxiButton1 = firstPin
    mouseTarget = panel.rows[1]
    mouseTarget:Fire("OnEnter")
    assert(firstPin.lit)
    do
        local first, second = panel.rows[1], panel.rows[2]
        cleared = nil
        mouseTarget = second
        first:Fire("OnLeave")
        second:Fire("OnEnter")
        panel.toggle:Fire("OnUpdate", 0)
        assert(not firstPin.lit and classicPin.lit and not cleared,
            "crossing to another route skips drawing all direct flights in between")
        mouseTarget = panel.rows[3] -- no native pin available for this row
        second:Fire("OnLeave")
        mouseTarget:Fire("OnEnter")
        assert(cleared and not classicPin.lit, "a missing destination pin restores the native map")
        mouseTarget = first
        first:Fire("OnEnter")
        cleared, mouseTarget = nil, panel.scroll
        first:Fire("OnLeave")
        panel.toggle:Fire("OnUpdate", 0)
        assert(cleared and not firstPin.lit, "moving to empty list space restores the native map")
        mouseTarget = first
        first:Fire("OnEnter")
    end
    highlighted, cleared, routeLookups = nil, nil, 0
    eventFrames.TAXI_NODE_STATUS_CHANGED:Fire("OnEvent", "TAXI_NODE_STATUS_CHANGED")
    assert(routeLookups == #nodes and firstPin.lit and not highlighted and not cleared,
        "a status refresh with the same hovered route scans each node once and preserves native route lines")
    routeLookups = 0
    panel.search:SetText("Stop")
    assert(routeLookups == 0 and firstPin.lit and not highlighted and not cleared,
        "refining a search without changing the hovered destination does not redraw its route")
    local row = panel.rows[1]
    mouseTarget = row.favorite
    row:Fire("OnLeave")
    mouseTarget:Fire("OnEnter")
    panel.toggle:Fire("OnUpdate", 0)
    assert(firstPin.lit and not highlighted and not cleared and tooltip:IsOwned(row.favorite),
        "moving to the star keeps the route and shows the star's action")
    routeLookups = 0
    eventFrames.TAXI_NODE_STATUS_CHANGED:Fire("OnEvent", "TAXI_NODE_STATUS_CHANGED")
    assert(routeLookups == #nodes and firstPin.lit and not highlighted and not cleared and tooltip:IsOwned(row.favorite),
        "refreshing beneath a stationary star preserves both its route and tooltip")
    mouseTarget = row
    row:Fire("OnEnter")
    row.favorite:Fire("OnLeave")
    panel.toggle:Fire("OnUpdate", 0)
    assert(firstPin.lit and not highlighted and not cleared and not tooltip:IsOwned(row.favorite),
        "returning to the row preserves its route even when the star's leave fires last")
    panel.search:SetText("Stop 02")
    assert(mouseTarget.entry.slot == 2 and not firstPin.lit and highlighted == classicPin and classicPin.lit,
        "filtering to a different destination under the pointer transfers the native highlight")
    mouseTarget = row.favorite
    row:Fire("OnLeave")
    mouseTarget:Fire("OnEnter")
    panel.search:SetText("Stop 01")
    assert(firstPin.lit and not classicPin.lit and tooltip:IsOwned(row.favorite) and tooltip.lines[2] == nodes[1].name,
        "filtering beneath a stationary star transfers both the route and its tooltip to the new point")
    mouseTarget = nil
    row.favorite:Fire("OnLeave")
    assert(not firstPin.lit and not tooltip.shown, "leaving the star for empty space releases the route and tooltip")
    panel.search:SetText("")
    local secondStar = panel.rows[2].favorite
    mouseTarget = secondStar
    secondStar:Fire("OnEnter")
    assert(classicPin.lit, "entering a star directly previews its flight")
    secondStar:Fire("OnMouseDown", "LeftButton")
    secondStar:Fire("OnClick", "LeftButton")
    assert(panel.rows[2].entry.slot == 1 and firstPin.lit and not classicPin.lit
        and tooltip:IsOwned(secondStar) and tooltip.lines[2] == nodes[1].name,
        "favoriting rebinds both the route and the tooltip beneath the stationary star")
    mouseTarget = nil
    secondStar:Fire("OnLeave")
    local marked = panel.rows[1].favorite
    marked:Fire("OnMouseDown", "LeftButton")
    marked:Fire("OnClick", "LeftButton")
    env.TaxiButton1 = nil
end
nodes = originalNodes
map:Hide()
modernMap:Show()
checkOpenExtension(panel, modernMap)
assert(panel.rows[1].entry.name == pin.name and panel.rows[1].fare:GetText() == "540")
do
    local oldPin = modernPin
    modernMap.EnumeratePinsByTemplate = modern.EnumeratePinsByTemplate
    oldPin.taxiNodeData = pin
    mouseTarget = panel.rows[1]
    mouseTarget:Fire("OnEnter")
    assert(highlighted == oldPin)
    highlighted, cleared = nil, nil
    eventFrames.TAXI_NODE_STATUS_CHANGED:Fire("OnEvent", "TAXI_NODE_STATUS_CHANGED")
    assert(not highlighted and not cleared, "an unchanged modern pin keeps its native highlight")
    local row = panel.rows[1]
    mouseTarget = row.favorite
    row:Fire("OnLeave")
    row.favorite:Fire("OnEnter")
    oldPin.taxiNodeData = modernNodes[2]
    modernPin = setmetatable({ taxiNodeData = pin }, { __index = oldPin })
    modernPin.owner.slotIndexToPin = {[pin.slotIndex] = modernPin}
    eventFrames.TAXI_NODE_STATUS_CHANGED:Fire("OnEvent", "TAXI_NODE_STATUS_CHANGED")
    assert(highlighted == modernPin and not cleared and tooltip:IsOwned(row.favorite),
        "a recycled modern pin is left alone and its replacement takes the route while the star keeps its tooltip")
    mouseTarget = nil
    row.favorite:Fire("OnLeave")
    assert(cleared == modernPin and not tooltip.shown, "leaving the modern star releases the replacement pin")
end
do
    local row = panel.rows[1]
    local oldCost = nodes[pin.slotIndex].cost
    nodes[pin.slotIndex].cost = 0
    pin.specialIconCostString, pin.useSpecialIcon = "A long explanation supplied by the flight map", false
    mouseTarget = row
    eventFrames.TAXI_NODE_STATUS_CHANGED:Fire("OnEvent", "TAXI_NODE_STATUS_CHANGED")
    assert(row.fare:IsTruncated() and row.fare:GetWidth() < panel.content:GetWidth() / 2,
        "a long special fare leaves space for the zone")
    assert(row.fare.textColor[2] == 0.1 and tooltip:IsOwned(row) and tooltip.lines[#tooltip.lines] == pin.specialIconCostString
        and tooltip.specialColor == env.RED_FONT_COLOR and tooltip.specialWrap, "the full warning appears in red and wraps in the tooltip")
    pin.useSpecialIcon = true
    eventFrames.TAXI_NODE_STATUS_CHANGED:Fire("OnEvent", "TAXI_NODE_STATUS_CHANGED")
    assert(row.fare.textColor[2] == 1 and tooltip.specialColor == env.HIGHLIGHT_FONT_COLOR, "informational fares use the native highlight color")
    pin.useSpecialIcon, nodes[pin.slotIndex].cost = false, oldCost
    eventFrames.TAXI_NODE_STATUS_CHANGED:Fire("OnEvent", "TAXI_NODE_STATUS_CHANGED")
    assert(row.fare:GetText() == tostring(oldCost) and row.fare:GetWidth() == 0 and row.fare.textColor[2] == 1
        and not tooltip:IsOwned(row), "a money price takes precedence and clears the special fare layout and tooltip")
    pin.specialIconCostString, pin.useSpecialIcon = nil, nil
    mouseTarget:Fire("OnLeave")
    mouseTarget = nil
end
do
    local provider, slot = modernPin.owner, pin.slotIndex
    local originalSlots = provider.slotIndexToPin
    provider.AddFlightNode = noOp
    provider.RefreshAllData = function() error("the list rebuilt Blizzard's pins") end
    modernMap.dataProviders = {[provider] = true}
    modernMap.GetNumActivePinsByTemplate = function() return 0 end
    provider.slotIndexToPin = {}
    highlighted, mouseTarget = nil, panel.rows[1]
    eventFrames.TAXI_NODE_STATUS_CHANGED:Fire("OnEvent", "TAXI_NODE_STATUS_CHANGED")
    assert(mouseTarget.entry.name == pin.name and not highlighted, "a destination remains listed until its native pin appears")
    panel.search:SetText(pin.name)
    local extra = {name = pin.name .. " Annex", slotIndex = 5, nodeID = 1634, state = state.Reachable}
    modernMap.redrawFlightPins = function()
        provider.slotIndexToPin = {[slot] = modernPin}
        modernNodes[#modernNodes + 1] = extra
    end
    modernMap:RefreshAllDataProviders()
    assert(panel.search:GetText() == pin.name and panel.rows[2].entry.name == extra.name and highlighted == modernPin,
        "Blizzard's own redraw refreshes the filtered list and supplies a highlightable pin")
    modernMap.redrawFlightPins = nil
    mouseTarget:Fire("OnLeave")
    mouseTarget = modernPin
    tooltip:SetOwner(modernPin)
    tooltip:SetText("Native quote")
    local price = nodes[slot].cost
    nodes[slot].cost = 250
    eventFrames.TAXI_NODE_STATUS_CHANGED:Fire("OnEvent", "TAXI_NODE_STATUS_CHANGED")
    assert(panel.rows[1].fare:GetText() == "250" and tooltip:IsOwned(modernPin) and tooltip.lines[1] == "Native quote",
        "a price update refreshes the row and leaves the native tooltip to Blizzard")
    tooltip:Hide()
    mouseTarget = nil
    modernNodes[#modernNodes], nodes[slot].cost = nil, price
    provider.slotIndexToPin, provider.AddFlightNode, provider.RefreshAllData = originalSlots, nil, nil
    modernMap.dataProviders = nil
    modernMap:RefreshAllDataProviders()
    panel.search:SetText("")
end
panel.scroll:SetHeight(10)
panel.scroll:SetVerticalScroll(12)
modernMap:SetMapID(mapID)
assert(panel.scroll:GetVerticalScroll() == 12, "reapplying the current map ID after opening keeps the scroll position")
local modernRow = panel.rows[1]
modernRow:Fire("OnMouseDown", "LeftButton")
modernMap:SetMapID(43)
assert(panel.rows[1].entry.mapID == 43 and panel.scroll:GetVerticalScroll() == 0,
    "switching map layers refreshes live slots and starts the new list at the top")
modernRow:Fire("OnClick", "LeftButton")
assert(#departures == 3, "changing map layers cancels a press even when the new layer uses the same slot and name")
modernRow:Fire("OnMouseDown", "LeftButton")
pin.nodeID = 94
eventFrames.TAXI_NODE_STATUS_CHANGED:Fire("OnEvent", "TAXI_NODE_STATUS_CHANGED")
modernRow:Fire("OnClick", "LeftButton")
assert(#departures == 3, "changing node identity cancels a press even when its map, slot and name match")
modernMap.height = 570
modernMap:Fire("OnSizeChanged")
checkOpenExtension(panel, modernMap)
modernMap.scale = 1.35
panel.toggle:Fire("OnUpdate", 0.2)
checkOpenExtension(panel, modernMap, true)
tweaks.enabled = false
D:Refresh()
assert(not D:ShouldLoad() and modernMap:IsVisible() and not panel:IsVisible() and not panel.toggle:IsVisible(),
    "disabling Quality of Life takes precedence over the individual switch on the modern map")
modernMap:Hide()
modernMap:Show()
assert(not panel.toggle:IsVisible() and not panel:IsVisible())
tweaks.enabled = true
D:Refresh()
assert(D:ShouldLoad() and panel.toggle:IsVisible() and panel:IsVisible())
print("PASS: flight panel opens, fits the screen, collapses, filters and clears on close")

do
    local function releaseAfterChange(row, change, notify, reason)
        local before = #departures
        row:Fire("OnMouseDown", "LeftButton")
        change()
        if notify then eventFrames.TAXI_NODE_STATUS_CHANGED:Fire("OnEvent", "TAXI_NODE_STATUS_CHANGED") end
        row:Fire("OnClick", "LeftButton")
        assert(#departures == before, reason)
    end

    local modernRow = modernMap.destinationPanel.rows[1]
    releaseAfterChange(modernRow, function()
        nodes[pin.slotIndex].cost = 0
        pin.specialIconCostString, pin.useSpecialIcon = "One token", true
    end, false, "a silent change from coins to a special price cancels departure")
    assert(modernRow.fare:GetText() == "One token", "cancelling updates the quote for the next press")
    releaseAfterChange(modernRow, function() pin.specialIconCostString = "Two tokens" end, true,
        "a changed special price cancels departure even when the row has already refreshed")
    releaseAfterChange(modernRow, function() pin.useSpecialIcon = false end, false,
        "a special price that becomes a warning cancels departure even if its text is unchanged")
    assert(modernRow.entry.priceColor == env.RED_FONT_COLOR)
    modernMap:Hide()

    mapID = 170
    nodes = {
        { name = "Origin", kind = "CURRENT", cost = 0 },
        { name = "Landing, Coast", kind = "REACHABLE", cost = 100, x = 0.2, y = 0.3 },
        { name = "Landing, Coast", kind = "REACHABLE", cost = 100, x = 0.7, y = 0.8 },
    }
    staticMapNodes[mapID] = { { name = nodes[2].name, nodeID = 301 } }
    modernNodes = {}
    map:Show()
    local classicRow = map.destinationPanel.rows[1]
    local function swapSlots() nodes[2], nodes[3] = nodes[3], nodes[2] end
    releaseAfterChange(classicRow, swapSlots, true, "same-name, same-price points swapped during refresh cannot dispatch")
    releaseAfterChange(classicRow, swapSlots, false, "same-name live slot replacement is detected without a refresh event")
    assert(classicRow.entry.x == nodes[2].x, "a stale slot refreshes to the live point")
    releaseAfterChange(classicRow, function() nodes[2].cost = 900 end, true, "a rebound row with a new coin price cannot dispatch")
    releaseAfterChange(classicRow, function() nodes[2].cost = 450 end, false, "a silent coin price change cannot dispatch")
    assert(classicRow.fare:GetText() == "450")
    local before = #departures
    classicRow:Fire("OnMouseDown", "LeftButton")
    classicRow:Fire("OnClick", "LeftButton")
    assert(#departures == before + 1 and departures[#departures] == 2, "a new press accepts the updated quote")

    nodes[3].x, nodes[3].y, nodes[3].cost = nodes[2].x, nodes[2].y, nodes[2].cost
    modernNodes = {
        { name = nodes[2].name, nodeID = 301, slotIndex = 2, state = state.Reachable },
        { name = nodes[3].name, nodeID = 302, slotIndex = 3, state = state.Reachable },
    }
    eventFrames.TAXI_NODE_STATUS_CHANGED:Fire("OnEvent", "TAXI_NODE_STATUS_CHANGED")
    local function swapNativeIDs()
        modernNodes[1].slotIndex, modernNodes[2].slotIndex = modernNodes[2].slotIndex, modernNodes[1].slotIndex
    end
    releaseAfterChange(classicRow, swapNativeIDs, true, "a rebound classic slot must preserve its known native node ID")
    releaseAfterChange(classicRow, swapNativeIDs, false, "identical classic labels and positions cannot conceal a live node ID change")
    before = #departures
    classicRow:Fire("OnMouseDown", "LeftButton")
    classicRow:Fire("OnClick", "LeftButton")
    assert(#departures == before + 1, "a verified native node ID distinguishes co-located classic points")
    releaseAfterChange(classicRow, function() modernNodes = {} end, false, "losing the expected native ID cancels the press")
    before = #departures
    classicRow:Fire("OnMouseDown", "LeftButton")
    classicRow:Fire("OnClick", "LeftButton")
    assert(#departures == before, "an unnamed identity collision cannot buy either indistinguishable flight")
    releaseAfterChange(classicRow, function() nodes[3].x = 0.9 end, false,
        "a press on an ambiguous point cannot dispatch even if the collision disappears before release")
    releaseAfterChange(classicRow, function() nodes[3].x = nodes[2].x end, false,
        "a newly overlapping point without a native ID invalidates the original press")
    map:Hide()
end
print("PASS: flight selection rechecks the destination and fare and refreshes a stale quote")

-- Exercise the star through the UI across route reordering, different masters, maps and logins.
do
    modernMap:Hide()
    mapID = 73
    nodes = {
        { name = "First Master", kind = "CURRENT", cost = 0 },
        { name = "Alpha, Coast", kind = "REACHABLE", cost = 10, x = 0.2, y = 0.4 },
        { name = "Bravo, Forest", kind = "REACHABLE", cost = 20, x = 0.39, y = 0.45 },
        { name = "Charlie, Forest", kind = "REACHABLE", cost = 30, x = 0.39, y = 0.45 },
        { name = "Delta, Coast", kind = "REACHABLE", cost = 40, x = 0.5, y = 0.6 },
    }
    local delta = { name = nodes[5].name, nodeID = 806, slotIndex = 5, state = state.Reachable }
    staticMapNodes[mapID] = {
        { name = delta.name, nodeID = delta.nodeID },
        { name = nodes[3].name, nodeID = 901 },
        { name = nodes[3].name, nodeID = 902 },
    }
    modernNodes = { delta }
    local previousDepartures = #departures
    local function visiblePlaces()
        local places = {}
        for _, result in ipairs(panel.rows) do
            if result:IsVisible() then places[#places + 1] = result.entry.place end
        end
        return table.concat(places, ",")
    end
    local function press(button)
        button:Fire("OnMouseDown", "LeftButton")
        button:Fire("OnClick", "LeftButton")
    end
    local function open(owner)
        owner:Show()
        panel = assert(owner.destinationPanel)
    end
    do
        local previousGUID = activeGUID
        activeGUID = "Player-Browsing"
        local char = {}
        characters[activeGUID] = char
        open(map)
        assert(next(char) == nil, "visiting a classic master with native IDs does not record unstarred stops")
        press(panel.rows[4].favorite)
        assert(char.favoriteFlightDestinations[delta.nodeID], "the first star is saved on this character")

        -- Count saved fields, including nested coordinate and locale records.
        local function savedFields(data)
            local count = 0
            for _, value in pairs(data) do
                count = count + 1
                if type(value) == "table" then count = count + savedFields(value) end
            end
            return count
        end
        local function browseAnother(slot)
            local count = savedFields(char)
            local name = "New stop " .. slot
            nodes[slot] = {name = name, kind = "REACHABLE", cost = 5, x = slot / 10, y = 0.8}
            modernNodes[#modernNodes + 1] = {name = name, nodeID = 990 + slot, slotIndex = slot, state = state.Reachable}
            eventFrames.TAXI_NODE_STATUS_CHANGED:Fire("OnEvent", "TAXI_NODE_STATUS_CHANGED")
            assert(savedFields(char) == count, "browsing unrelated stops leaves saved favorites data alone")
        end
        browseAnother(6)
        press(panel.rows[1].favorite)
        assert(not next(char.favoriteFlightDestinations or {}))
        browseAnother(7)
        nodes[7], nodes[6], modernNodes[3], modernNodes[2] = nil, nil, nil, nil
        map:Hide()
        activeGUID = previousGUID
    end
    open(map)
    local deltaStar = panel.rows[4].favorite
    assert(deltaStar.parent == panel.rows[4] and deltaStar.normalAtlas == "auctionhouse-icon-favorite-off")
    mouseTarget = deltaStar
    deltaStar:Fire("OnEnter")
    assert(tooltip:IsOwned(deltaStar) and tooltip.lines[1] == env.BATTLE_PET_FAVORITE and tooltip.lines[2] == delta.name)
    press(deltaStar)
    assert(tooltip.lines[2] == panel.rows[4].entry.name, "the star tooltip follows its row after reordering")
    mouseTarget = nil
    deltaStar:Fire("OnLeave")
    local bravoKey = panel.rows[3].entry.favoriteKey
    press(panel.rows[3].favorite)
    assert(visiblePlaces() == "Bravo,Delta,Alpha,Charlie", "favorites and other reachable destinations each sort alphabetically")
    assert(bravoKey and type(bravoKey) == "string" and ns.CharDB().favoriteFlightDestinations[bravoKey]
        and ns.CharDB().favoriteFlightDestinations[delta.nodeID], "legacy coordinates and native node IDs identify destinations")
    assert(panel.rows[4].entry.favoriteKey ~= bravoKey and not panel.rows[4].entry.isFavorite,
        "two differently named classic points at identical coordinates keep independent stars when native IDs are ambiguous or absent")
    assert(panel.rows[1].favorite.normalAtlas == "auctionhouse-icon-favorite" and panel.rows[1].entry.isFavorite)
    assert(#departures == previousDepartures, "marking a destination must not purchase a flight")

    local pressedStar = panel.rows[1].favorite
    pressedStar:Fire("OnMouseDown", "LeftButton")
    panel.search:SetText("Coast")
    assert(visiblePlaces() == "Delta,Alpha", "zone search covers both favorites and ordinary destinations")
    pressedStar:Fire("OnClick", "LeftButton")
    assert(panel.rows[1].entry.isFavorite and ns.CharDB().favoriteFlightDestinations[bravoKey],
        "releasing a star after its row changes must not toggle either destination")
    press(panel.rows[1])
    assert(#departures == previousDepartures + 1 and departures[#departures] == 5,
        "the row of a favorite still dispatches its normal flight")
    map:Hide()

    nodes[1].name = "Second Master"
    nodes[3], nodes[5] = nodes[5], nodes[3]
    delta.slotIndex = 3
    modernNodes = {}
    open(map)
    assert(visiblePlaces() == "Bravo,Delta,Alpha,Charlie" and panel.rows[1].entry.slot == 5
        and panel.rows[2].entry.slot == 3 and panel.rows[2].entry.favoriteKey == delta.nodeID,
        "changing flight master and slot keeps the same favorites even if the master's API omits the node ID")
    map:Hide()
    modernNodes = { delta }
    open(modernMap)
    assert(visiblePlaces() == "Delta" and panel.rows[1].entry.isFavorite and panel.rows[1].entry.favoriteKey == delta.nodeID,
        "the same Blizzard node shares its favorite between the classic and modern maps")
    press(panel.rows[1].favorite)
    assert(not panel.rows[1].entry.isFavorite and not ns.CharDB().favoriteFlightDestinations[delta.nodeID],
        "clicking a filled star on the modern map removes the destination from favorites")
    modernMap:Hide()
    open(map)
    assert(visiblePlaces() == "Bravo,Alpha,Charlie,Delta"
        and #departures == previousDepartures + 1, "unmarking restores the ordinary alphabetical position without flying")
    map:Hide()

    activeGUID = "Player-2"
    open(map)
    assert(visiblePlaces() == "Alpha,Bravo,Charlie,Delta" and not panel.rows[2].entry.isFavorite,
        "a second character starts without the first character's favorites")
    press(panel.rows[3].favorite)
    assert(visiblePlaces() == "Charlie,Alpha,Bravo,Delta")
    map:Hide()

    -- Reload the module with a fresh map, hooks and addon namespace, retaining the saved character data.
    activeGUID = "Player-1"
    local newMap = widget()
    newMap.right, newMap.shown, newMap.height, newMap.width = 800, false, 580, 590
    env.TaxiFrame, env.FlightMapFrame = newMap, nil
    local login = { db = ns.db, CharDB = ns.CharDB, SettingsPanel = ns.SettingsPanel, L = ns.L, modules = {} }
    setfenv(chunk, env)("FlareUI", login)
    login.FlightDestinations:Refresh()
    open(newMap)
    assert(visiblePlaces() == "Bravo,Alpha,Charlie,Delta" and panel.rows[1].entry.isFavorite
        and not panel.rows[3].entry.isFavorite, "a fresh addon load restores just the logged-in character's choices")
end
print("PASS: safe favorite stars, sorted search, stable destination identity and per-character persistence")

do
    local owner = env.TaxiFrame
    owner:Hide()
    mapID = 291
    nodes = {
        {name = "Master", kind = "CURRENT", cost = 0},
        {name = "Twin, Coast", kind = "REACHABLE", x = 0.20, y = 0.30, cost = 10},
        {name = "Twin, Coast", kind = "REACHABLE", x = 0.65, y = 0.70, cost = 10},
        {name = "Port, Valley", kind = "REACHABLE", x = 0.84, y = 0.52, cost = 10},
        {name = "North, Hills", kind = "REACHABLE", x = 0.30, y = 0.45, cost = 10},
        {name = "South, Hills", kind = "REACHABLE", x = 0.30, y = 0.45, cost = 10},
    }
    local twin = {name = nodes[2].name, slotIndex = 2, nodeID = 752, state = state.Reachable}
    staticMapNodes[mapID], modernNodes = {{name = twin.name, nodeID = twin.nodeID}}, {}
    local oldPort = "291:0.840000:0.520000:Порт, Долина"
    local ambiguous = "291:0.300000:0.450000:Другой язык"
    local saved = {[752] = true, [oldPort] = true, [ambiguous] = true}
    ns.CharDB().favoriteFlightDestinations = saved
    local function rowFor(slot)
        for _, row in ipairs(owner.destinationPanel.rows) do
            if row.entry and row.entry.slot == slot then return row end
        end
    end
    local function pressStar(slot)
        local star = rowFor(slot).favorite
        star:Fire("OnMouseDown", "LeftButton")
        star:Fire("OnClick", "LeftButton")
    end
    owner:Show()
    assert(saved[752] and not rowFor(2).entry.isFavorite and not rowFor(3).entry.isFavorite,
        "an existing numeric favorite waits for native identity when legacy twins cannot be distinguished by name")
    modernNodes = {twin}
    eventFrames.TAXI_NODE_STATUS_CHANGED:Fire("OnEvent", "TAXI_NODE_STATUS_CHANGED")
    assert(rowFor(2).entry.isFavorite and not rowFor(3).entry.isFavorite,
        "a partial native catalog cannot give both same-named classic points the same favorite")
    modernNodes = {}
    eventFrames.TAXI_NODE_STATUS_CHANGED:Fire("OnEvent", "TAXI_NODE_STATUS_CHANGED")
    assert(rowFor(2).entry.isFavorite and not rowFor(3).entry.isFavorite,
        "a confirmed native favorite remains visible with its classic position at another master")
    assert(rowFor(4).entry.isFavorite and not saved[oldPort],
        "the previous release's translated key migrates by unique classic coordinates")
    assert(not rowFor(5).entry.isFavorite and not rowFor(6).entry.isFavorite and saved[ambiguous],
        "an old translated favorite shared by two overlapping pins waits for an exact match")
    pressStar(2)
    pressStar(3)
    assert(not rowFor(2).entry.isFavorite and rowFor(3).entry.isFavorite and not saved[752])
    owner:Hide()
    nodes[2].name, nodes[3].name, nodes[4].name = "Близнец, Берег", "Близнец, Берег", "Порт, Долина"
    env.GetLocale = function() return "ruRU" end
    modernNodes = {}
    owner:Show()
    assert(not rowFor(2).entry.isFavorite and rowFor(3).entry.isFavorite and rowFor(4).entry.isFavorite,
        "a change of client language and flight master retains each distinct fallback point")
    pressStar(3)
    assert(not rowFor(3).entry.isFavorite and rowFor(4).entry.isFavorite,
        "unmarking a translated favorite affects just that point")
    nodes[3].x, nodes[3].y = nodes[2].x, nodes[2].y
    twin.name, modernNodes = nodes[2].name, {twin}
    eventFrames.TAXI_NODE_STATUS_CHANGED:Fire("OnEvent", "TAXI_NODE_STATUS_CHANGED")
    pressStar(2)
    assert(rowFor(2).entry.isFavorite and not rowFor(3).favorite:IsShown() and not rowFor(3).entry.isFavorite,
        "matching name and coordinates allow only the point with a confirmed native ID to be starred")
    pressStar(3)
    assert(saved[752] and rowFor(2).entry.isFavorite and not rowFor(3).entry.isFavorite)
end
print("PASS: independent same-name flights, locale-stable favorites and migration of saved marks")

-- Node data can change while Blizzard still displays the pins from the last map opening.
do
    local owner = env.TaxiFrame
    owner:Hide()
    mapID, modernNodes = 401, {}
    nodes = {
        {name = "Origin", kind = "CURRENT", cost = 0, x = 0.1, y = 0.1},
        {name = "Alpha, Coast", kind = "REACHABLE", cost = 10, x = 0.2, y = 0.3},
        {name = "Beta, Coast", kind = "REACHABLE", cost = 20, x = 0.7, y = 0.8},
    }
    for i = 2, 3 do
        local native = widget("Button")
        native.LockHighlight, native.UnlockHighlight = classicPin.LockHighlight, classicPin.UnlockHighlight
        env["TaxiButton" .. i] = native
    end
    owner:Show()
    local list = owner.destinationPanel
    mouseTarget = list.rows[2]
    mouseTarget:Fire("OnEnter")
    assert(env.TaxiButton3.lit)
    -- The hovered destination is unchanged, but another slot has moved before Blizzard sends its status event.
    nodes[2].x = 0.25
    highlighted, cleared, mouseTarget = nil, nil, nil
    list.rows[2]:Fire("OnLeave")
    assert(not cleared and not env.TaxiButton3.lit, "leaving a stale classic route cannot draw native lines")
    mouseTarget = list.rows[2]
    mouseTarget:Fire("OnEnter")
    assert(not highlighted and not env.TaxiButton3.lit, "entering before the status event cannot draw from stale geometry")
    nodes[2], nodes[3] = nodes[3], nodes[2]
    highlighted = nil
    eventFrames.TAXI_NODE_STATUS_CHANGED:Fire("OnEvent", "TAXI_NODE_STATUS_CHANGED")
    assert(list.rows[2].entry.slot == 2 and not env.TaxiButton2.lit and not highlighted,
        "a changed classic slot updates the list without highlighting a stale pin")
    mouseTarget:Fire("OnLeave")
    mouseTarget = env.TaxiButton2
    tooltip:SetOwner(mouseTarget)
    tooltip:SetText("Native quote")
    nodes[2].cost = 50
    eventFrames.TAXI_NODE_STATUS_CHANGED:Fire("OnEvent", "TAXI_NODE_STATUS_CHANGED")
    assert(list.rows[2].fare:GetText() == "50" and tooltip:IsOwned(mouseTarget) and tooltip.lines[1] == "Native quote")
    tooltip:Hide()
    mouseTarget = nil
    owner:Hide()
    owner:Show()
    mouseTarget = list.rows[2]
    mouseTarget:Fire("OnEnter")
    assert(env.TaxiButton2.lit, "the next native map opening makes the refreshed pin available")
    mouseTarget:Fire("OnLeave")
    mouseTarget = nil
end
print("PASS: classic list updates preserve Blizzard's rendered map and tooltip")

do
    env.TaxiFrame:Hide()
    env.TaxiFrame, env.FlightMapFrame = map, modernMap
    activeGUID, mapID = "Player-2", 377
    local char = ns.CharDB()
    char.favoriteFlightDestinations, char.flightDestinationIDs = {}, nil
    local master = {name = "Master", kind = "CURRENT", x = 0.1, y = 0.1, cost = 0}
    local north = {name = "North, Hills", kind = "REACHABLE", x = 0.45, y = 0.55, cost = 10}
    local south = {name = "South, Hills", kind = "REACHABLE", x = north.x, y = north.y, cost = 10}
    local native = {name = north.name, slotIndex = 2, state = state.Reachable, nodeID = 7302}
    local function first(owner)
        owner:Show()
        return owner.destinationPanel.rows[1]
    end
    local function toggle(row)
        row.favorite:Fire("OnMouseDown", "LeftButton")
        row.favorite:Fire("OnClick", "LeftButton")
    end
    nodes, modernNodes = {master, north, south}, {native}
    local row = first(map)
    assert(row.entry.name == north.name)
    toggle(row)
    map:Hide()
    nodes, modernNodes = {master, south}, {}
    row = first(map)
    assert(not row.entry.isFavorite and row.entry.favoriteKey ~= native.nodeID,
        "a master with only the co-located peer cannot transfer the first destination's star")
    toggle(row)
    toggle(row)
    assert(char.favoriteFlightDestinations[native.nodeID], "toggling the peer leaves the first favorite intact")
    map:Hide()

    nodes, modernNodes = {master, north}, {native}
    row = first(modernMap)
    toggle(row)
    assert(not row.entry.isFavorite)
    toggle(row)
    modernMap:Hide()
    modernNodes = {}
    row = first(map)
    assert(row.entry.favoriteKey == native.nodeID and row.entry.isFavorite,
        "removing and re-adding on the modern map retains the known classic identity at an ID-less master")
    toggle(row)
    map:Hide()
    modernNodes = {native}
    assert(not first(modernMap).entry.isFavorite, "removing on the ID-less map removes the same modern favorite")
    modernMap:Hide()

    -- Even when the first interaction after updating happens on the modern map,
    -- import the old ID's locator before the first click can erase its value.
    char.flightDestinationIDs = nil
    char.favoriteFlightDestinations = {[native.nodeID] = "named:377:0.450000:0.550000:North, Hills"}
    row = first(modernMap)
    toggle(row)
    toggle(row)
    modernMap:Hide()
    nodes, modernNodes = {master, south}, {}
    assert(not first(map).entry.isFavorite)
    map:Hide()
    nodes = {master, north}
    assert(first(map).entry.isFavorite, "legacy ID metadata survives updating and toggling on a modern map first")
    map:Hide()

    char.flightDestinationIDs = nil
    char.favoriteFlightDestinations = {[native.nodeID] = "377:0.450000:0.550000:North, Hills"}
    nodes = {master, south}
    assert(not first(map).entry.isFavorite, "an old numeric favorite missing its shared marker cannot mark a different name")
    map:Hide()
    nodes = {master, north}
    assert(first(map).entry.isFavorite, "the old numeric favorite is retained for its exact classic locator")
    map:Hide()

    mapID = 0
    nodes = {master, north, north}
    row = first(map)
    assert(not row.favorite:IsShown() and not map.destinationPanel.rows[2].favorite:IsShown(),
        "an invalid legacy map ID must not expose an inert star for indistinguishable points")
end
print("PASS: shared positions, durable links between flight maps and usable favorite buttons")

do
    map:Hide()
    mapID = 402
    local char = ns.CharDB()
    local master = {name = "Master", kind = "CURRENT", cost = 0, x = .1, y = .1}
    local function open(name, id)
        map:Hide()
        nodes = {master, {name = name, x = .4, y = .5, kind = "REACHABLE", cost = 10}}
        modernNodes = id and {{name = name, slotIndex = 2, nodeID = id, state = state.Reachable}} or {}
        map:Show()
        return map.destinationPanel.rows[1]
    end
    local function toggle(row)
        row.favorite:Fire("OnMouseDown", "LeftButton")
        row.favorite:Fire("OnClick", "LeftButton")
    end
    for _, ids in ipairs({{}, {7302}, {false, 7303}, {7302, 7303}}) do
        char.favoriteFlightDestinations, char.flightDestinationIDs = nil, nil
        toggle(open("North", ids[1]))
        local south = open("South", ids[2])
        assert(not south.entry.isFavorite, "a separately seen point cannot inherit a favorite by coordinates")
        toggle(south)
        local north = open("North")
        assert(north.entry.isFavorite and open("South").entry.isFavorite)
        toggle(open("South"))
        assert(not open("South").entry.isFavorite and open("North").entry.isFavorite,
            "unmarking the peer at another master preserves the original favorite, even without IDs")
    end
    local pos = "402:0.400000:0.500000"
    char.favoriteFlightDestinations = nil
    char.flightDestinationIDs = {
        [pos] = {id = 7302, enUS = "North", shared = true}, ["named:" .. pos .. ":North"] = 7302,
    }
    toggle(open("South"))
    assert(open("South").entry.isFavorite and not open("North").entry.isFavorite,
        "a new star at previously shared coordinates cannot inherit an old point's identity")
    toggle(open("South"))
    assert(not open("North").entry.isFavorite and not open("South").entry.isFavorite)
    char.flightDestinationIDs = {[pos] = 7302, ["named:" .. pos .. ":North"] = 7302}
    char.favoriteFlightDestinations = {[7302] = true}
    assert(not open("South").entry.isFavorite and open("North").entry.isFavorite,
        "upgrading an existing coordinate-to-ID binding waits for its matching name or ID")
    char.flightDestinationIDs, char.favoriteFlightDestinations = nil, {[pos] = "North"}
    assert(not open("South", 7303).entry.isFavorite and open("North").entry.isFavorite,
        "an older positional favorite retains its original name when first visited from the other master")
    char.flightDestinationIDs, char.favoriteFlightDestinations = nil, nil
    env.GetLocale = function() return "enUS" end
    toggle(open("North"))
    env.GetLocale = function() return "frFR" end
    assert(open("Nord").entry.isFavorite)
    env.GetLocale = function() return "enUS" end
    assert(not open("South").entry.isFavorite)
    toggle(open("South"))
    env.GetLocale = function() return "frFR" end
    assert(open("Nord").entry.isFavorite and not open("Sud").entry.isFavorite,
        "a newly discovered overlap keeps earlier translations of the original starred point")
    -- Same literal text can identify two different stops in different client languages.
    env.GetLocale = function() return "enUS" end
    char.flightDestinationIDs, char.favoriteFlightDestinations = nil, nil
    toggle(open("Port", 7302))
    open("Harbor", 7303)
    env.GetLocale = function() return "frFR" end
    assert(open("Port du Nord", 7302).entry.isFavorite)
    local peer = open("Port")
    assert(not peer.entry.isFavorite, "a translated peer cannot inherit a different locale's name-to-ID binding")
    toggle(peer)
    toggle(open("Port"))
    assert(open("Port du Nord").entry.isFavorite, "unmarking the translated peer preserves the original favorite")
    open("Port", 7303)
    assert(open("Port").entry.favoriteKey == 7303)
    env.GetLocale = function() return "enUS" end
    assert(open("Port").entry.isFavorite and open("Harbor").entry.favoriteKey == 7303,
        "conflicting translations cannot disable confirmed aliases in the original locale")

    -- Upgrade a character who had already visited the same two stops before
    -- name-to-ID bindings gained a language. The old "Port" belongs to 7302.
    char.flightDestinationIDs = {
        [pos] = {id = 7302, enUS = "Port", frFR = "Port du Nord", shared = true},
        ["named:" .. pos .. ":Port"] = 7302, ["named:" .. pos .. ":Harbor"] = 7303,
    }
    char.favoriteFlightDestinations = {[7302] = true}
    env.GetLocale = function() return "frFR" end
    peer = open("Port")
    assert(not peer.entry.isFavorite, "the saved French name rules out the old unscoped ID for Port")
    toggle(peer)
    assert(open("Port", 7303).entry.isFavorite, "a newly identified French favorite keeps its star")
    toggle(open("Port"))
    env.GetLocale = function() return "enUS" end
    assert(open("Port").entry.isFavorite and not open("Harbor", 7303).entry.isFavorite,
        "removing the identified French peer preserves the English Port after upgrading")
    map:Hide()
end
print("PASS: favorites stay with their destination across separate masters at the same coordinates")
