local Fixture = dofile("tools/tests/fixtures/settings-ui.lua")
local function noop() end

local function setup(style, edgeIcons)
    local ui = Fixture.new()
    local env = ui.env
    local Widget = getmetatable(env.UIParent)
    function Widget:GetNumChildren() return #self.children end
    function Widget:IsProtected() return self.protected == true end
    function Widget:SetPassThroughButtons(...) self.passThrough = { ... } end
    function Widget:SetMaskTexture(mask) self.mask = mask end
    function Widget:SetIconScale(scale) self.iconScale = scale end
    function Widget:EnableMouseWheel(value) self.wheelEnabled = value end
    -- (as the client: EnableMouse is both channels)
    function Widget:EnableMouse(value) self.mouseEnabled, self.clickEnabled, self.motionEnabled = value, value, value end
    function Widget:SetMouseClickEnabled(value) self.clickEnabled = value end
    function Widget:SetMouseMotionEnabled(value) self.motionEnabled = value end

    local cluster = env.CreateFrame("Frame", "MinimapCluster", env.UIParent)
    local container = env.CreateFrame("Frame", nil, cluster)
    cluster.MinimapContainer = container
    container:SetSize(200, 200)
    local map = env.CreateFrame("Minimap", "Minimap", container)
    map:SetSize(200, 200)
    map:SetMaskTexture("NativeMask")
    map.SetQuestBlobRingScalar = function(self, value) self.questRing = value end
    map.SetTaskBlobRingScalar = function(self, value) self.taskRing = value end
    map.SetArchBlobRingScalar = function(self, value) self.archRing = value end
    function map:SetZoom(value) self.zoom = value; self.zoomChanges = self.zoomChanges + 1 end
    function map:GetZoom() return self.zoom end
    function map:GetZoomLevels() return 6 end
    map.zoom, map.zoomChanges = 0, 0
    function map:AdjustPointsOffset(x, y)
        local point, anchor, relative, oldX, oldY = self:GetPoint()
        self:SetPoint(point or "CENTER", anchor or container, relative or "CENTER", (oldX or 0) + x, (oldY or 0) + y)
    end
    function map:SetMouseClickEnabled(enabled) self.clickEnabled = enabled end
    function map:PingLocation(x, y) self.ping = { x, y } end
    local rotating = true
    env.GetCVarBool = function(key) return key == "rotateMinimap" and rotating end
    env.SetCVar = function(key, value) assert(key == "rotateMinimap"); rotating = value ~= "0" end
    cluster.SetRotateMinimap = function(_, enabled) rotating = enabled end
    cluster.SetEditModeScale, cluster.SetHeaderUnderneath = noop, noop
    cluster.SetIconScale = function(_, scale) env.Minimap:SetIconScale(scale) end
    cluster.HasSetting = function() return true end
    cluster.GetSettingValue = function() return 125 end

    cluster.ZoneTextButton = env.CreateFrame("Button", nil, cluster)
    cluster.Tracking = env.CreateFrame("Frame", nil, cluster)
    cluster.Tracking.Button = env.CreateFrame("Button", nil, cluster.Tracking)
    cluster.IndicatorFrame = env.CreateFrame("Frame", nil, cluster)
    cluster.DielFrame = env.CreateFrame("Frame", nil, container)
    cluster.DielFrame:SetSize(30, 30)
    container.PlayerCoords = env.CreateFrame("Frame", nil, container)
    container.PlayerCoords.CoordText = container.PlayerCoords:CreateFontString()
    env.MinimapCompassTexture = container:CreateTexture()
    env.MinimapCompassTextureUnderlay = container:CreateTexture()
    env.MinimapZoneText = cluster.ZoneTextButton:CreateFontString()
    env.GameTimeFrame = env.CreateFrame("Button", "GameTimeFrame", cluster)
    env.TimeManagerClockButton = env.CreateFrame("Button", "TimeManagerClockButton", cluster)
    env.TimeManagerClockTicker = env.TimeManagerClockButton:CreateFontString()
    env.TimeManagerClockTicker:SetText("12:00")
    env.GameTime_UpdateTooltip, env.TimeManagerClockButton_Update, env.TimeManagerClockButton_UpdateTooltip = noop, noop, noop
    env.MiniMapIndicatorFrame_UpdatePosition = noop
    env.GetMinimapShape = function() return "ROUND" end
    env.Minimap_ZoomIn = function() map:SetZoom(map:GetZoom() + 1) end
    env.Minimap_ZoomOut = function() map:SetZoom(map:GetZoom() - 1) end
    env.GameTooltip_Hide = function() env.GameTooltip:Hide() end
    env.GameTooltip.AddDoubleLine = function(self, label, value) self:AddLine(label .. ": " .. value) end
    env.GetFramerate = function() return 60 end
    env.GetNetStats = function() return 0, 0, 24, 38 end
    env.GetMoney = function() return ui.money or 10239 end
    env.GetInventoryItemDurability = function(slot) if slot == 1 then return 3, 20 elseif slot == 16 then return 20, 20 end end
    env.C_Container = {
        GetContainerNumSlots = function(bag) return ({ [0] = 16, [1] = 12, [2] = 6 })[bag] or 0 end,
        GetContainerNumFreeSlots = function(bag)
            if bag == 0 then return ui.free or 2, 0 end
            if bag == 1 then return 1, 4 end
            return 0, 0
        end,
    }
    env.C_Map = {
        GetBestMapForUnit = function() return 31 end,
        GetPlayerMapPosition = function() return { GetXY = function() return 0.453, 0.621 end } end,
    }
    env.UnitXP, env.UnitXPMax = function() return 75 end, function() return 150 end
    env.GetXPExhaustion, env.UnitLevel = function() return 15 end, function() return 27 end
    env.IsInInstance = function() return ui.pvp == true, ui.pvp and "pvp" or "none" end
    env.canaccessvalue = function() return true end

    local case = { epochs = {}, editCallbacks = {}, events = {}, dialogs = {}, settingsClicks = 0 }
    local nativeLayout = { TopLeftCorner = { x = 2, y = 3 }, TopRightCorner = { x = 0, y = 3 },
        BottomLeftCorner = {}, BottomRightCorner = {}, LeftEdge = {}, RightEdge = {}, TopEdge = {}, BottomEdge = {} }
    env.NineSliceUtil = {
        GetLayout = function(name) assert(name == "ButtonFrameTemplateNoPortrait"); return nativeLayout end,
        ApplyLayout = function(border, layout)
            case.layout = layout
            for key in pairs(layout) do
                border[key] = border[key] or border:CreateTexture()
            end
        end,
    }
    env.Enum = { EditModeSystem = { Minimap = 1 }, EditModeMinimapSetting = { Size = 1, RotateMinimap = 2, HeaderUnderneath = 3 },
        UITextureSliceMode = { Stretched = 0 } }
    env.C_Texture = { GetAtlasInfo = function() return { width = 24, height = 24 } end }
    env.C_AddOns.IsAddOnLoaded = function(name) return name == "NodeSight" or name == "FarmHud" end
env.C_AddOns.GetAddOnMetadata = function(name) return name end

    env.EventUtil = { ContinueOnAddOnLoaded = function(name, callback)
        local events = case.events
        events[name] = events[name] or {}
        events[name][#events[name] + 1] = callback
    end }
    function case:loadAddon(name)
        local callbacks = self.events[name] or {}
        self.events[name] = nil
        for _, callback in ipairs(callbacks) do callback() end
    end
    local clientTimers = env.C_Timer
    clientTimers.NewTimer = clientTimers.NewTicker
    local libButton = env.CreateFrame("Button", "RegisteredAddonMinimapButton", map)
    local pin = env.CreateFrame("Button", "MapNodePin", map)
    libButton:SetFrameStrata("BACKGROUND")
    pin:SetFrameStrata("BACKGROUND")
    local lib = {
        ["FlareEditMode"] = {
            AddSystemSettings = function(_, id, rows) assert(id == 1); case.editRows = rows end,
            RegisterCallback = function(_, event, callback) case.editCallbacks[event] = callback end,
        },
        ["AceEvent-3.0"] = { Embed = function(_, mod)
            function mod:RegisterEvent(event, method) case.epochs[event] = method end
        end },
        ["LibSharedMedia-3.0"] = { Fetch = function(_, _, name) return "Media/" .. name end },
        ["LibDBIcon-1.0"] = {
            GetButtonList = function() return { "RegisteredAddon" } end,
            GetMinimapButton = function(_, name) if name == "RegisteredAddon" then return libButton end end,
        },
        ["HereBeDragons-Pins-2.0"] = { activeMinimapPins = { [pin] = true } },
    }
    env.LibStub = function(name) return lib[name] end
    local db = {
        enabled = true, style = style, squareBorder = "thick", microMenu = true, autoZoom = 2,
        infoBar = { left = "gold", center = "bags", right = "durability" },
        infoBarHover = true, infoFont = { face = "Test", size = 15, flags = "NONE" },
        zoneFont = { size = 13 }, clockFont = { size = 12 },
        coords = "legacy", coordsOnHover = true, fps = "hover", latency = "always",
    }
    env.CharacterMicroButton = env.CreateFrame("Button", "CharacterMicroButton", env.UIParent)
    env.ObjectiveTrackerFrame = env.CreateFrame("Frame", nil, env.UIParent)
    local ns = {
        L = setmetatable({}, { __index = function(_, key) return key end }),
        db = { profile = { minimap = db }, global = {} }, modules = {},
        RadialMenu = { MICRO_PANELS = {
            character = { label = "Character", button = "CharacterMicroButton", icon = 100 },
            spellbook = { label = "Spellbook", button = "AbsentButton" },
            flareui = { label = "FlareUI", macrotext = "/flareui" },
        } },
        BORDER_COLOR = env.CreateColor(0.6, 0.5, 0.4, 1),
        BorderEdgeSize = function(_, size) return size end,
        SetFont = function(widget, ...) widget:SetFont(...) end,
        GetFontPath = function(face) return "Fonts/" .. face end,
        GetWantedFont = function(widget) return widget:GetFont() end,
        ApplyShadow = noop,
        PixelSize = function() return 1 end,
        SetSystemScale = function(widget, scale) widget:SetScale(scale) end,
        FitEditModeBox = function(_, callback) case.fitEditMode = callback end,
        OwnGameTooltip = function(owner, anchor) env.GameTooltip:SetOwner(owner, anchor) end,
        ShowDialog = function(key, label) case.dialogs[#case.dialogs + 1] = { key, label } end,
        SettingsPanel = { Toggle = function() case.settingsClicks = case.settingsClicks + 1 end },
    }
    if edgeIcons then
        local function decorateEye(eye)
            eye.texture = eye:CreateTexture()
            for key, texture in pairs({
                EyeInitial = "EyeInitialTexture", EyeSearchingLoop = "EyeSearchingTexture",
                EyeMouseOver = "EyeMouseOverTexture", EyeFoundInitial = "EyeFoundInitialTexture", EyeFoundLoop = "EyeFoundLoopTexture",
                EyePokeInitial = "EyePokeInitialTexture", EyePokeLoop = "EyePokeLoopTexture", EyePokeEnd = "EyePokeEndTexture",
            }) do
                local animation = env.CreateFrame("Frame", nil, eye)
                animation[texture] = animation:CreateTexture()
                eye[key] = animation
            end
            eye.StartInitialAnimation = function(self) self.animation = "initial" end
            eye.StartSearchingAnimation = function(self) self.animation = "searching" end
            eye.StartFoundAnimationInit = function(self) self.animation = "found" end
            eye.SetStaticMode = function(self, value) self.static = value end
            eye.IsStaticMode = function(self) return self.static end
            eye.OnEnter = function(self) self.hover = true end
            eye.OnLeave = function(self) self.hover = false end
        end
        local makeFrame = env.CreateFrame
        env.CreateFrame = function(kind, name, parent, template)
            local frame = makeFrame(kind, name, parent, template)
            if template == "LFGEyeTemplate" then decorateEye(frame) end
            return frame
        end
        local nativeEye = env.CreateFrame("Button", "QueueStatusButton", env.UIParent)
        nativeEye.Eye = env.CreateFrame("Frame", nil, nativeEye, "LFGEyeTemplate")
        nativeEye.Selection = env.CreateFrame("Frame", nil, nativeEye)
        nativeEye:Hide()
        local nativeExit = env.CreateFrame("Button", "MainMenuBarVehicleLeaveButton", env.UIParent)
        nativeExit.Selection = env.CreateFrame("Frame", nil, nativeExit)
        local nativeDurability = env.CreateFrame("Frame", "DurabilityFrame", env.UIParent)
        nativeDurability.Selection = env.CreateFrame("Frame", nil, nativeDurability)
        env.QueueStatusFrame = env.CreateFrame("Frame", "QueueStatusFrame", env.UIParent)
        env.QueueStatusFrame:Hide()
        env.LFDMicroButton = env.CreateFrame("Button", "LFDMicroButton", env.UIParent)
        env.EventRegistry = env.CreateFrame("Frame")
        env.EditModeManagerFrame = { IsEditModeActive = function() return ui.editing end }
        env.GameTooltip.IsOwned = function(self, owner) return self:GetOwner() == owner end
        env.GameTooltip_SetTitle = function(self, text) self.lines = { text } end
        env.GameTooltip_AddNormalLine = function(self, text) self:AddLine(text) end
        env.REPAIR_ARMOR_TOOLTIP_TITLE = "Repair armor"
        env.REPAIR_ARMOR_TOOLTIP_BROKEN, env.REPAIR_ARMOR_TOOLTIP_BREAKING = "Broken", "Breaking"
        env.LEAVE_VEHICLE, env.TAXI_CANCEL, env.TAXI_CANCEL_DESCRIPTION = "Leave vehicle", "Land early", "Exit at the next stop"
        env.UnitOnTaxi = function() return ui.onTaxi end
        env.GetInventoryAlertStatus = function(slot) return slot == 4 and ui.durability or 0 end
        env.RegisterStateDriver = function(button, event, condition)
            assert(event == "visibility" and not ui.combat)
            button.condition = condition
            button:SetShown(condition == "show" or (condition:find("canexitvehicle", 1, true) and ui.canExit and not ui.petBattle))
        end
        db.finderEye, db.vehicleExit, db.durability = true, true, true
        ui:load("Modules/MinimapEye.lua", ns)
        ui:load("Modules/MinimapVehicle.lua", ns)
        ui:load("Modules/MinimapDurability.lua", ns)
    end
    ui:load("Modules/Minimap.lua", ns)
    local minimap = ns.Minimap
    assert(not minimap:SetMapFaded(true))
    minimap:Init()
    case:loadAddon("Blizzard_TimeManager")
    case:loadAddon("Blizzard_ObjectiveTracker")
    ui:flushTimers()
    ui:flushTimers()
    case.ui, case.ns, case.db, case.map, case.minimap, case.cluster = ui, ns, db, map, minimap, cluster
    case.libButton, case.pin = libButton, pin
    case.surface = ui:find(function(w) return w:GetParent() == map and w:GetScript("OnMouseUp") end)
    case.bar = ui:find(function(w) return w.Plates ~= nil end)
    function case:barText(needle)
        for fs in pairs(minimap.infoTexts) do
            if fs:GetText():find(needle, 1, true) then return fs end
        end
    end
    return case
end

local square = setup("square")
local ui, minimap, map, db, cluster = square.ui, square.minimap, square.map, square.db, square.cluster
local env, bar, surface = ui.env, square.bar, square.surface
-- the Info Bar's values are white, as Blizzard's money and bag numbers (11-23)
for fs in pairs(minimap.infoTexts) do
    local r, g, b = fs:GetTextColor()
    assert(r == 1 and g == 1 and b == 1, "Info Bar text is white")
end
-- no "how to move" line in the icons' tooltips (11-23): the hint is gone
assert(minimap.Moves.AddHint == nil and minimap.Moves.hinted == nil)
assert(minimap.IsSquare() and map:GetWidth() == 243 and minimap.Frame:GetWidth() == 248)
assert(map:GetHeight() == map:GetWidth() and map.mask == minimap.SquareMask())
assert(map.questRing == 0 and map.taskRing == 0 and map.archRing == 0 and env.GetMinimapShape() == "SQUARE")
assert(not env.GetCVarBool("rotateMinimap") and not env.MinimapCompassTexture:IsShown())
assert(cluster:GetScale() == 1.25 and cluster:GetWidth() == 260)
assert(square.libButton:GetParent() == minimap.ButtonHolder and square.pin:GetFrameStrata() == "BACKGROUND")
assert(square.fitEditMode() == minimap.Frame and minimap.SquareBorder().edge == 16)
assert(env.ObjectiveTrackerFrame:GetScale() == (248 - 3) * 1.25 / 288)
assert(not db.coords and not db.coordsOnHover and not db.fps and not db.latency)
assert(square.dialogs[1][1] == "FLAREUI_NODE_SCAN" and square.dialogs[1][2] == "NodeSight")
minimap.NoticeScanners()
ui:flushTimers()
assert(square.dialogs[2][1] == "FLAREUI_MAP_HUD" and square.dialogs[2][2] == "FarmHud")
minimap.NoticeScanners()
ui:flushTimers()
assert(#square.dialogs == 2)
assert(square:barText("1|A:coin-gold:") and square:barText("20/22") and square:barText("|cffff993315%"))
assert(bar:GetAlpha() == 0 and cluster.MinimapContainer.PlayerCoords:GetAlpha() == 0)
cluster.mouseOver = true
cluster:RunScript("OnEnter")
assert(bar:GetAlpha() == 1 and bar.Plates[1]:IsShown() and not bar.Plates[2]:IsShown())
ui.free, ui.money = 0, 10005
ui:emit("BAG_UPDATE_DELAYED")
assert(square:barText("|cffff404022/22"))
db.infoBarBelow, db.infoBarBox = true, false
db.infoBar.left, db.infoBar.center, db.infoBar.right = "coords", "coordsSimple", "xp"
minimap:Refresh()
assert(bar:GetPoint() == "TOPLEFT" and not bar.Plates[1]:IsShown())
assert(square:barText("45.3, 62.1") and square:barText("45, 62") and square:barText("XP 50% |cff4d85e6+10%"))
cluster.mouseOver = false
ui:flushTimers()
assert(bar:GetAlpha() == 0)

db.squareHeader = "art"
minimap:Refresh()
assert(minimap.Frame:GetWidth() == 244 and map:GetWidth() == 236 and map.mask:find("WHITE8X8", 1, true))
assert(minimap.Border.TopEdge:GetParent() == minimap.BorderAbove and not minimap.BorderAbove.Flare:IsShown())
db.squareHeader = "headerless"
db.squareBorder = "thin"
minimap:Refresh()
assert(minimap.SquareBorder().edge == 8 and minimap.Frame:GetWidth() == 250 and map:GetWidth() == 243)
assert(minimap.BorderAbove.Flare:IsShown() and minimap.BorderAbove.Flare:GetBackdrop().edgeSize == 8)
minimap:SetMapFaded(true)
assert(map:IsShown() and map.mask:find("Empty", 1, true))
map:SetMaskTexture("Blizzard attempted a mask")
assert(map.mask:find("Empty", 1, true))
minimap:SetMapFaded(false)
assert(map.mask == minimap.SquareMask())
minimap:SetIconsFaded(true)
assert(map.iconScale == 0)
minimap:SetIconsFaded(false)
assert(map.iconScale == 1)
-- (11-24) Edit Mode's Icon Size comes back, and a layout applied while faded draws nothing
env.Enum.EditModeMinimapSetting.IconScale = 9
minimap:SetIconsFaded(true)
cluster:SetIconScale(1.5)
assert(map.iconScale == 0)
minimap:SetIconsFaded(false)
assert(map.iconScale == 1.25)
env.Enum.EditModeMinimapSetting.IconScale = nil

-- (11-24) it takes clicks, never the hover: the pointer's focus stays the map's
assert(surface.clickEnabled == true and surface.motionEnabled == false, "clicks without hover")
assert(surface.wheelEnabled and #surface.passThrough == 2)
surface:RunScript("OnMouseWheel", 1)
assert(map:GetZoom() == 1)
ui:flushTimers()
assert(map:GetZoom() == 0, "zoom resets after the configured delay")
ui.cursorX, ui.cursorY = map:GetCenter()
ui.cursorX, ui.cursorY = (ui.cursorX + 30) * map:GetEffectiveScale(), (ui.cursorY - 40) * map:GetEffectiveScale()
surface:RunScript("OnMouseUp", "LeftButton")
assert(math.abs(map.ping[1] - 30) < 0.01 and math.abs(map.ping[2] + 40) < 0.01)
ui.pvp = true
ui:emit("ZONE_CHANGED_NEW_AREA")
assert(#surface.passThrough == 4 and surface.passThrough[3] == "LeftButton")
map.ping = nil
surface:RunScript("OnMouseUp", "LeftButton")
assert(not map.ping, "battlegrounds leave pings to Blizzard")
surface:RunScript("OnMouseUp", "MiddleButton")
local menu = assert(env.FlareUI_MinimapMenu)
local rows = { menu:GetChildren() }
assert(menu:IsShown() and #rows == 2)
assert(rows[1]:GetAttribute("macrotext") == "/click CharacterMicroButton" and rows[2]:GetAttribute("macrotext") == "/flareui")
menu.mouseOver = true
ui:emit("GLOBAL_MOUSE_DOWN")
assert(menu:IsShown())
rows[1]:Click()
ui:flushTimers()
assert(not menu:IsShown())
ui.combat = true
surface:RunScript("OnMouseUp", "MiddleButton")
assert(not menu:IsShown() and #ui.errors == 1)
ui.combat = false

local flare = assert(minimap.flareButton)
flare:Click()
assert(square.settingsClicks == 1)
flare:RunScript("OnDragStart")
flare:RunScript("OnUpdate", 0.2)
flare:RunScript("OnDragStop")
assert(db.buttonSpots.FlareUI and not flare:GetScript("OnUpdate"))
flare:Click("RightButton")
assert(db.flareButton == false and not flare:IsShown())

local scanFinished = 0
local wantedMask = minimap.SquareMask()
map:AdjustPointsOffset(23, -17)
assert(map.mask:find("Empty", 1, true) and not minimap.Back:IsShown() and not surface.wheelEnabled)
assert(minimap.AfterScan("test", function() scanFinished = scanFinished + 1 end))
map:AdjustPointsOffset(-23, 17)
ui.time = env.GetTime() + 1
ui:flushTimers()
assert(scanFinished == 1 and map.mask == wantedMask and minimap.Back:IsShown() and surface.wheelEnabled)

local home = map:GetParent()
map:SetParent(env.CreateFrame("Frame", nil, env.UIParent))
ui:flushTimers()
assert(minimap.MapAway())
map:SetMaskTexture("FarmHud")
assert(map.mask == "FarmHud", "the HUD keeps its own terrain while borrowing the map")
map:SetParent(home)
ui:flushTimers()
ui:flushTimers()
assert(not minimap.MapAway() and map.mask == wantedMask)

db.style = "round"
minimap:Refresh()
assert(minimap.IsSquare(), "style changes wait for reload")
db.clockStats = true
env.GameTooltip:SetOwner(env.TimeManagerClockButton, "ANCHOR_TOP")
env.GameTime_UpdateTooltip()
assert(env.GameTooltip.lines[1] == "Framerate: 60 fps" and env.GameTooltip.lines[3] == "Latency (World): 38 ms")

local round = setup("round", true)
local roundMap, roundMinimap = round.map, round.minimap
assert(not roundMinimap.IsSquare() and not roundMinimap.Frame and roundMap:GetWidth() == 200)
assert(round.ui.env.GetCVarBool("rotateMinimap") and round.ui.env.GetMinimapShape() == "ROUND")
assert(round:barText("20/22") and not round:barText("1|A:coin-gold:") and not round:barText("15%"))
roundMap:SetMaskTexture("Player round mask")
roundMinimap:SetMapFaded(true)
roundMinimap:SetMapFaded(false)
assert(roundMap.mask == "Player round mask")
assert(round.ui.env.ObjectiveTrackerFrame:GetScale() == 200 / 288)
round.db.infoBar.center = "none"
roundMinimap:Refresh()
assert(not round.bar:IsShown())
local rui, renv = round.ui, round.ui.env
local finder, vehicle, durability = renv.FlareUIFinderEye, renv.FlareUIVehicleExit, renv.FlareUIDurability
local nativeEye, nativeExit = renv.QueueStatusButton, renv.MainMenuBarVehicleLeaveButton
assert(not finder:IsShown() and not vehicle:IsShown() and not durability:IsShown())
assert(nativeEye:GetAlpha() == 0 and nativeExit:GetAlpha() == 0 and renv.DurabilityFrame:GetAlpha() == 0)
assert(not nativeEye.Selection:IsMouseEnabled() and not nativeExit.Selection:IsMouseEnabled())
nativeEye:Show()
nativeEye.Eye:StartSearchingAnimation()
assert(finder:IsShown() and finder.Eye.animation == "searching" and finder:GetAttribute("clickbutton1") == nativeEye)
finder:RunScript("OnEnter")
assert(renv.QueueStatusFrame:IsShown() and select(2, renv.QueueStatusFrame:GetPoint()) == finder)
finder:RunScript("OnLeave")
assert(not renv.QueueStatusFrame:IsShown())

rui.canExit, rui.onTaxi = true, true
round.ns.MinimapVehicle.Update()
assert(vehicle:IsShown() and vehicle:GetAttribute("clickbutton1") == nativeExit)
assert(vehicle:GetScale() == round.ns.MinimapEye.ROUND_SCALE)
vehicle:RunScript("OnMouseDown")
assert(vehicle.Icon:GetTexture():find("Exit-Down", 1, true))
vehicle:RunScript("OnEnter")
assert(renv.GameTooltip.lines[1] == "Land early" and renv.GameTooltip.lines[2] == "Exit at the next stop")
vehicle:RunScript("OnLeave")
assert(not renv.GameTooltip:IsShown())

rui.durability = 2
rui:emit("UPDATE_INVENTORY_ALERTS")
assert(durability:IsShown() and durability.level == 2)
durability:RunScript("OnEnter")
assert(renv.GameTooltip.lines[2] == "Broken")
assert(select(4, finder:GetPoint()) ~= select(4, vehicle:GetPoint())
    and select(4, vehicle:GetPoint()) ~= select(4, durability:GetPoint()), "three visible icons use distinct spots")
round.cluster:SetAlpha(0.4)
assert(finder:GetAlpha() == 0.4 and vehicle:GetAlpha() == 0.4 and durability:GetAlpha() == 0.4)
nativeEye:Hide()
rui:flushTimers()
assert(not finder:IsShown() and finder:GetAttribute("clickbutton1") == renv.LFDMicroButton)
rui.combat = true
round.db.vehicleExit = false
round.ns.MinimapVehicle.Update()
assert(vehicle:IsShown() and nativeExit:GetAlpha() == 0, "combat defers the secure swap as a unit")
rui.combat = false
rui:emit("PLAYER_REGEN_ENABLED")
assert(not vehicle:IsShown() and nativeExit:GetAlpha() == 1 and nativeExit.Selection:IsMouseEnabled())
roundMap:Hide()
assert(not durability:IsShown())
roundMap:Show()
assert(durability:IsShown())
rui.durability, rui.editing = 0, true
renv.EventRegistry:TriggerEvent("EditMode.Enter")
assert(finder:IsShown() and durability:IsShown(), "Edit Mode previews inactive icons")
rui.editing = false
renv.EventRegistry:TriggerEvent("EditMode.Exit")
assert(not finder:IsShown() and not durability:IsShown())
round.db.durability, round.db.finderEye = false, false
round.ns.MinimapDurability.Update()
round.ns.MinimapEye.Update()
assert(renv.DurabilityFrame:GetAlpha() == 1 and nativeEye:GetAlpha() == 1)
print("PASS: minimap borders, info bar, pings, scanning, HUD handoff and edge icons")
