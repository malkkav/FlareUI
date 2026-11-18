local _, ns = ...

--------------------------------------------------
-- VEHICLE EXIT ICON
-- With Vehicle Exit Icon on (minimap.vehicleExit), the vehicle exit button as a small round icon on
-- the minimap, dressed like the Group Finder Icon (MinimapEye.lua): dark ground, Blizzard's
-- red exit arrow cut round, FlareUI's bronze ring. It shows while you can leave a vehicle or cut a
-- flight short, as Blizzard's button does, and a click clicks Blizzard's button, which knows which one
-- to do (VehicleExit, or TaxiRequestEarlyLanding on a flight path).
-- Blizzard's button stays where it is, unseen and without the mouse (its Edit Mode mover too) while the
-- option is on, Edit Mode included; ours shows in Edit Mode, to be seen.
-- A secure button, shown by a state driver: a quest vehicle often comes mid-fight.
--------------------------------------------------

ns.MinimapVehicle = ns.MinimapVehicle or {}
local Exit = ns.MinimapVehicle

local InCombatLockdown = InCombatLockdown
local C_Timer = C_Timer

-- as the Group Finder Icon (MinimapEye.lua)
local BUTTON_SIZE = 31
local GROUND_SIZE = 24
local ICON_SIZE   = 20
local RING_SIZE   = 50
local ROUND_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
-- Blizzard's own art and crop (VehicleLeaveButton.xml)
local EXIT_UP   = "Interface\\Vehicles\\UI-Vehicles-Button-Exit-Up"
local EXIT_DOWN = "Interface\\Vehicles\\UI-Vehicles-Button-Exit-Down"
local CROP = { 0.140625, 0.859375, 0.140625, 0.859375 }
-- the arrow's red square fills the crop: a little larger, so the round cut keeps the arrow whole
local ICON_ZOOM = 1.15

local function GetDb()
    return ns.db and ns.db.profile and ns.db.profile.minimap
end

local function Wanted()
    local db = GetDb()
    return Exit.initialized and db and db.vehicleExit and true or false
end

local function Editing()
    return EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()
end

-- a secure button changes only out of combat: in combat, the change waits for its end
local waiting = {}
local combatEnd = CreateFrame("Frame")
combatEnd:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    local due = waiting
    waiting = {}
    for fn in pairs(due) do fn() end
end)
local function CanChange(fn)
    if not InCombatLockdown() then return true end
    waiting[fn] = true
    combatEnd:RegisterEvent("PLAYER_REGEN_ENABLED")
    return false
end

--------------------------------------------------
-- THE BUTTON (made while the addon loads: a secure button can't be made in combat)
--------------------------------------------------
-- (named ^FlareUI: the Addon Button Drawer never adopts it)
local button = CreateFrame("Button", "FlareUIVehicleExit", UIParent, "SecureActionButtonTemplate, SecureHandlerStateTemplate")
button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:Hide()
button:RegisterForClicks("AnyUp", "AnyDown")
button:SetAttribute("type1", "click")

local function Dress()
    local ground = button:CreateTexture(nil, "BACKGROUND")
    ground:SetSize(GROUND_SIZE, GROUND_SIZE)
    ground:SetPoint("CENTER")
    ground:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local mask = button:CreateMaskTexture()
    mask:SetTexture(ROUND_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetSize(ICON_SIZE, ICON_SIZE)
    mask:SetPoint("CENTER")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE * ICON_ZOOM, ICON_SIZE * ICON_ZOOM)
    icon:SetPoint("CENTER")
    icon:SetTexture(EXIT_UP)
    icon:SetTexCoord(CROP[1], CROP[2], CROP[3], CROP[4])
    icon:AddMaskTexture(mask)
    local ring = button:CreateTexture(nil, "OVERLAY")
    ring:SetSize(RING_SIZE, RING_SIZE)
    ring:SetPoint("TOPLEFT")
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    -- the Group Finder Icon's bronze (MinimapEye.lua Dress)
    ring:SetDesaturated(true)
    local c = ns.BORDER_COLOR
    ring:SetVertexColor(math.min(1, c.r * 1.35), math.min(1, c.g * 1.35), math.min(1, c.b * 1.35))
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(ICON_SIZE, ICON_SIZE)
    highlight:SetPoint("CENTER")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    button.Icon = icon
end
Dress()

-- pressed: Blizzard's pressed arrow
button:HookScript("OnMouseDown", function(self) self.Icon:SetTexture(EXIT_DOWN) end)
button:HookScript("OnMouseUp", function(self) self.Icon:SetTexture(EXIT_UP) end)

-- Blizzard's tooltip (VehicleLeaveButton.lua OnEnter)
button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    if UnitOnTaxi("player") then
        GameTooltip_SetTitle(GameTooltip, TAXI_CANCEL)
        GameTooltip:AddLine(TAXI_CANCEL_DESCRIPTION, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
    else
        GameTooltip_SetTitle(GameTooltip, LEAVE_VEHICLE)
    end
    GameTooltip:Show()
end)
local function Leave(self)
    if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    self.Icon:SetTexture(EXIT_UP)
end
button:SetScript("OnLeave", Leave)
button:SetScript("OnHide", Leave)

--------------------------------------------------
-- PLACE, SHOWN, FADE
--------------------------------------------------
-- Square style: on the map's left edge, in the Group Finder Icon's spot (above the sundial, or on the
-- bottom-left corner without it: MinimapEye.lua SquareSpot). While the Group Finder Icon shows, one
-- step higher, right above it; it comes down again when that icon hides (both move only out of combat,
-- the eye's own showing waits for that too). Round style: up the circle's lower left, the next spot
-- above the Group Finder Icon (MinimapEye.lua RoundSpot). A Group Finder Icon moved along the edge
-- leaves the stack; this one moved sits at its own angle on the edge (MinimapEye.lua Spot).
local function Place()
    if not CanChange(Place) then return end
    local eye = ns.MinimapEye
    if not (eye and eye.Spot) then return end
    button:SetScale(eye.ScaleFor("vehicle"))
    local own = button:GetEffectiveScale()
    local x, y = eye.Spot("vehicle", own)
    if not (x and y) then return end
    button:ClearAllPoints()
    button:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / own, y / own)
end

local function Fade()
    button:SetAlpha(MinimapCluster:GetAlpha())
end

-- [canexitvehicle] is Blizzard's CanExitVehicle (a flight path counts); [petbattle] keeps it off there.
-- Edit Mode shows it, to be seen; the option off, or the map hidden, never
local function Driver()
    if not (Wanted() and MinimapCluster:IsShown() and Minimap:IsShown()) then return "hide" end
    if Editing() then return "show" end
    return "[petbattle] hide; [canexitvehicle] show; hide"
end

local function UpdateShown()
    if not CanChange(UpdateShown) then return end
    RegisterStateDriver(button, "visibility", Driver())
    Fade()
    Place()
end

-- Blizzard's button: unseen while ours is on, back in Edit Mode or with the option off. Only a button
-- this file took is given back (quiet defaults: another addon's way with it is kept)
local taken = false
-- The game or its layout sets the button's opacity again after us: while taken, any show or new
-- opacity puts it straight back to unseen and without the mouse. In Edit Mode too, its mover with it:
-- it loses the mouse so an unseen mover can't be grabbed
local function KeepHidden()
    local game = MainMenuBarVehicleLeaveButton
    if not (taken and game) then return end
    if game:GetAlpha() ~= 0 then game:SetAlpha(0) end
    if game:IsMouseEnabled() then game:EnableMouse(false) end
    -- the Edit Mode box ignores its button's opacity (ignoreParentAlpha): its own, then
    local selection = game.Selection
    if selection then
        if selection:GetAlpha() ~= 0 then selection:SetAlpha(0) end
        if selection:IsMouseEnabled() then selection:EnableMouse(false) end
    end
end
local function UpdateGameButton()
    local game = MainMenuBarVehicleLeaveButton
    if not game then return end
    if not Exit.gameHooked then
        Exit.gameHooked = true
        hooksecurefunc(game, "SetAlpha", KeepHidden)
        hooksecurefunc(game, "EnableMouse", KeepHidden)
        game:HookScript("OnShow", KeepHidden)
        if game.Selection then
            game.Selection:HookScript("OnShow", KeepHidden)
            hooksecurefunc(game.Selection, "EnableMouse", KeepHidden)
            hooksecurefunc(game.Selection, "SetAlpha", KeepHidden)
        end
    end
    -- hidden in Edit Mode as well: with the option on, ours is the button
    local seen = not Wanted()
    if seen and not taken then return end
    taken = not seen
    game:SetAlpha(seen and 1 or 0)
    game:EnableMouse(seen)
    if game.Selection then
        game.Selection:SetAlpha(seen and 1 or 0)
        game.Selection:EnableMouse(seen)
    end
end

--------------------------------------------------
-- PUBLIC
--------------------------------------------------
-- Settings > Minimap > Vehicle Exit Icon (live)
function Exit.Update()
    if not CanChange(Exit.Update) then return end
    UpdateGameButton()
    UpdateShown()
end

-- the map's place or size changed (Minimap.lua MM:Refresh)
function Exit.Place()
    C_Timer.After(0, Place)
end

-- at once, while the player drags it along the edge (Minimap.lua MM.Moves)
function Exit.PlaceNow()
    Place()
end

-- from Minimap.lua MM:Init, after the map's layout
function Exit.Init()
    if Exit.initialized or not MainMenuBarVehicleLeaveButton then return end
    Exit.initialized = true
    button:SetAttribute("clickbutton1", MainMenuBarVehicleLeaveButton)
    EventRegistry:RegisterCallback("EditMode.Enter", Exit.Update)
    EventRegistry:RegisterCallback("EditMode.Exit", Exit.Update)
    MinimapCluster:HookScript("OnShow", UpdateShown)
    MinimapCluster:HookScript("OnHide", UpdateShown)
    Minimap:HookScript("OnShow", UpdateShown)
    Minimap:HookScript("OnHide", UpdateShown)
    hooksecurefunc(MinimapCluster, "SetAlpha", Fade)
    -- the Group Finder Icon coming or going moves this one (Place)
    if _G.FlareUIFinderEye then
        _G.FlareUIFinderEye:HookScript("OnShow", Exit.Place)
        _G.FlareUIFinderEye:HookScript("OnHide", Exit.Place)
    end
    local events = CreateFrame("Frame")
    events:RegisterEvent("UI_SCALE_CHANGED")
    events:RegisterEvent("DISPLAY_SIZE_CHANGED")
    events:SetScript("OnEvent", Exit.Place)
    Exit.Update()
end
