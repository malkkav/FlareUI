local _, ns = ...

--------------------------------------------------
-- DURABILITY ICON (11-17, Malkkav)
-- With Durability Icon on (minimap.durability), Blizzard's equipment durability figure as one small
-- round icon on the minimap, dressed like the Group Finder Icon (MinimapEye.lua): dark ground, the
-- minimap's repair icon cut round and tinted, FlareUI's bronze ring. Yellow while any piece is about to
-- break, red while any is broken (the game's own alert levels and colours, DurabilityFrame.lua); hidden
-- while nothing is. Pointing at it shows Blizzard's own tooltip text.
-- Square style: on the map's left edge, the next spot up the stack the Group Finder Icon starts (above
-- it and the Vehicle Exit Icon, each only while shown; MinimapEye.lua SquareSpot / STEP). Round style:
-- centred on the map's bottom edge, a step up while the Vehicle Exit Icon shows.
-- Blizzard's figure stays where it is, unseen and without the mouse (its Edit Mode mover too, so its
-- Edit Mode dialog can't open) while the option is on. A plain button: it may move in a fight.
--------------------------------------------------

ns.MinimapDurability = ns.MinimapDurability or {}
local Dur = ns.MinimapDurability

local BUTTON_SIZE = 31
local GROUND_SIZE = 24
local ICON_SIZE   = 20
local RING_SIZE   = 50
local ROUND_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local ICON = "Interface\\Minimap\\Tracking\\Repair"
local SLOTS = 11   -- DurabilityFrame.lua INVENTORY_ALERT_STATUS_SLOTS

local function GetDb()
    return ns.db and ns.db.profile and ns.db.profile.minimap
end

local function Wanted()
    local db = GetDb()
    return Dur.initialized and db and db.durability and true or false
end

local function Editing()
    return EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()
end

--------------------------------------------------
-- THE BUTTON
--------------------------------------------------
local button = CreateFrame("Button", "FlareUIDurability", UIParent)
button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:Hide()

do
    local ground = button:CreateTexture(nil, "BACKGROUND")
    ground:SetSize(GROUND_SIZE, GROUND_SIZE)
    ground:SetPoint("CENTER")
    ground:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local mask = button:CreateMaskTexture()
    mask:SetTexture(ROUND_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetSize(ICON_SIZE, ICON_SIZE)
    mask:SetPoint("CENTER")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("CENTER")
    icon:SetTexture(ICON)
    -- one colour, the alert's: greyed, then tinted
    icon:SetDesaturated(true)
    icon:AddMaskTexture(mask)
    local ring = button:CreateTexture(nil, "OVERLAY")
    ring:SetSize(RING_SIZE, RING_SIZE)
    ring:SetPoint("TOPLEFT")
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    ring:SetDesaturated(true)
    local c = ns.BORDER_COLOR
    ring:SetVertexColor(math.min(1, c.r * 1.35), math.min(1, c.g * 1.35), math.min(1, c.b * 1.35))
    button.Icon = icon
end

-- the worst alert of the equipped pieces: 0 none, 1 about to break, 2 broken
local function Alert()
    if C_GameRules and C_GameRules.IsGameRuleActive and Enum.GameRule and Enum.GameRule.RepairArmorDisabled
        and C_GameRules.IsGameRuleActive(Enum.GameRule.RepairArmorDisabled) then
        return 0
    end
    local worst = 0
    for slot = 1, SLOTS do
        local status = GetInventoryAlertStatus(slot) or 0
        if status > worst then worst = status end
    end
    return worst
end

local COLORS = { { r = 1, g = 0.82, b = 0.18 }, { r = 0.93, g = 0.07, b = 0.07 } }   -- INVENTORY_ALERT_COLORS
local function Colour(level)
    local c = (_G.INVENTORY_ALERT_COLORS and _G.INVENTORY_ALERT_COLORS[level]) or COLORS[level] or COLORS[1]
    button.Icon:SetVertexColor(c.r, c.g, c.b)
end

-- Blizzard's tooltip (DurabilityFrame.lua OnEnter)
button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip_SetTitle(GameTooltip, REPAIR_ARMOR_TOOLTIP_TITLE, WHITE_FONT_COLOR, true)
    GameTooltip_AddNormalLine(GameTooltip, (self.level or 1) >= 2 and REPAIR_ARMOR_TOOLTIP_BROKEN or REPAIR_ARMOR_TOOLTIP_BREAKING, true)
    GameTooltip:Show()
end)
local function Leave(self)
    if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end
button:SetScript("OnLeave", Leave)
button:SetScript("OnHide", Leave)

--------------------------------------------------
-- PLACE, SHOWN, FADE
--------------------------------------------------
local function Shown(name)
    local f = _G[name]
    return f and f:IsShown() and true or false
end

local function Place()
    local eyeMod = ns.MinimapEye
    button:SetScale(eyeMod and eyeMod.IconScale and eyeMod.IconScale() or (Minimap:GetEffectiveScale() / UIParent:GetEffectiveScale()))
    local own = button:GetEffectiveScale()
    local eye = ns.MinimapEye
    local x, y
    if ns.Minimap and ns.Minimap.IsSquare and ns.Minimap.IsSquare() and eye and eye.SquareSpot then
        x, y = eye.SquareSpot(own)
        -- a step up for each icon below it that shows
        local below = (Shown("FlareUIFinderEye") and 1 or 0) + (Shown("FlareUIVehicleExit") and 1 or 0)
        if y then y = y + below * eye.STEP * own end
    else
        -- (11-17, Malkkav) round: up the circle, above the icons below it that show
        local below = (Shown("FlareUIFinderEye") and 1 or 0) + (Shown("FlareUIVehicleExit") and 1 or 0)
        if eye and eye.RoundSpot then x, y = eye.RoundSpot(own, below) end
    end
    if not (x and y) then return end
    button:ClearAllPoints()
    button:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / own, y / own)
end

local function Fade()
    button:SetAlpha(MinimapCluster:GetAlpha())
end

local function Update()
    local level = Alert()
    local show = Wanted() and MinimapCluster:IsShown() and Minimap:IsShown() and (level > 0 or Editing())
    button.level = level > 0 and level or 1
    if show then
        Colour(button.level)
        Fade()
        Place()
    end
    button:SetShown(show and true or false)
end

-- Blizzard's figure: unseen while ours is on, Edit Mode included (its mover too: the Selection is a
-- child, so the alpha hides it, and it loses the mouse so its dialog can't open). Only a figure this
-- file took is given back.
local taken = false
local function KeepHidden()
    local game = _G.DurabilityFrame
    if not (taken and game) then return end
    if game:GetAlpha() ~= 0 then game:SetAlpha(0) end
    if game:IsMouseEnabled() then game:EnableMouse(false) end
    -- (11-17) the Edit Mode box ignores its button's opacity (ignoreParentAlpha): its own, then
    local selection = game.Selection
    if selection then
        if selection:GetAlpha() ~= 0 then selection:SetAlpha(0) end
        if selection:IsMouseEnabled() then selection:EnableMouse(false) end
    end
end
local function UpdateGameFrame()
    local game = _G.DurabilityFrame
    if not game then return end
    if not Dur.gameHooked then
        Dur.gameHooked = true
        hooksecurefunc(game, "SetAlpha", KeepHidden)
        hooksecurefunc(game, "EnableMouse", KeepHidden)
        game:HookScript("OnShow", KeepHidden)
        if game.Selection then
            game.Selection:HookScript("OnShow", KeepHidden)
            hooksecurefunc(game.Selection, "EnableMouse", KeepHidden)
            hooksecurefunc(game.Selection, "SetAlpha", KeepHidden)
        end
    end
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
-- Settings > Minimap > Durability Icon (live)
function Dur.Update()
    UpdateGameFrame()
    Update()
end

-- the map moved, or an icon below it came or went
function Dur.Place()
    C_Timer.After(0, function() if button:IsShown() then Place() end end)
end

-- from Minimap.lua MM:Init
function Dur.Init()
    if Dur.initialized then return end
    Dur.initialized = true
    local events = CreateFrame("Frame")
    events:RegisterEvent("UPDATE_INVENTORY_ALERTS")
    events:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("UI_SCALE_CHANGED")
    events:RegisterEvent("DISPLAY_SIZE_CHANGED")
    events:SetScript("OnEvent", Update)
    EventRegistry:RegisterCallback("EditMode.Enter", Dur.Update)
    EventRegistry:RegisterCallback("EditMode.Exit", Dur.Update)
    MinimapCluster:HookScript("OnShow", Update)
    MinimapCluster:HookScript("OnHide", Update)
    Minimap:HookScript("OnShow", Update)
    Minimap:HookScript("OnHide", Update)
    hooksecurefunc(MinimapCluster, "SetAlpha", Fade)
    -- the icons below it coming or going move it up or down
    for _, name in ipairs({ "FlareUIFinderEye", "FlareUIVehicleExit" }) do
        local f = _G[name]
        if f then
            f:HookScript("OnShow", Dur.Place)
            f:HookScript("OnHide", Dur.Place)
        end
    end
    -- Blizzard's figure lives in its own addon: hide it once it's there too
    if EventUtil and EventUtil.ContinueOnAddOnLoaded then
        EventUtil.ContinueOnAddOnLoaded("Blizzard_DurabilityFrame", Dur.Update)
    end
    Dur.Update()
end
