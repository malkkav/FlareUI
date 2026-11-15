local _, ns = ...
local L = ns.L

--------------------------------------------------
-- FLAG CARRIERS
-- Edit Mode frame "FlareUI Flag Carriers" (Unit Frames > Flag Carrier Frames, off; 11-15, a player's
-- request: "the pvp target frames"). In a battleground Blizzard shows the flag carriers on its old
-- arena frames (Blizzard_Deprecated_ArenaUI: ArenaEnemyFramesContainer > ArenaEnemyMatchFrame1-5),
-- in its right-hand column under the minimap. Forever's Edit Mode has no system for them (Camelot
-- hides its Arena Frames checkbox; CompactArenaFrame isn't loaded there).
-- Hooks only: ArenaEnemyFramesContainer is a right-hand managed frame with secure unit buttons in it.
-- Whenever Blizzard hands it back to its column (SetParent in ManagedFrameContainerMixin:UpdateFrame)
-- it goes on our holder instead, out of combat only (it is protected through its buttons); a
-- placement held back by combat waits for the fight to end. On the holder it is no longer a child of
-- the column, so the column leaves no gap for it.
--------------------------------------------------

--------------------------------------------------
-- 1. MODULE REGISTRATION
--------------------------------------------------
ns.FlagCarriers = ns.FlagCarriers or {}
local FC = ns.FlagCarriers
ns.modules["FlagCarriers"] = FC

--------------------------------------------------
-- 2. UPVALUES / CONSTANTS
--------------------------------------------------
local _G = _G
local math_floor = math.floor
local CreateFrame, InCombatLockdown = CreateFrame, InCombatLockdown
local LEM = LibStub("FlareEditMode")

-- Blizzard's geometry (Deprecated_ArenaUI.xml): a carrier frame is 112 x 32, 10 apart, its right edge
-- 28 in from the container's (the column's -10 plus the faction icon's -18); the faction icon reaches
-- the container's right edge, the name sits a few pixels over the frame's top
local FRAME_W, FRAME_H, SPACING, NAME_H = 112, 32, 10, 4
local RIGHT_IN = 28
local CARRIERS = 2   -- the holder and the sample: two carriers, one per side
local HOLDER_W = FRAME_W + RIGHT_IN
local HOLDER_H = NAME_H + CARRIERS * FRAME_H + (CARRIERS - 1) * SPACING

-- Edit Mode keeps a reference to this table: ApplyPosition refills it (the boss frames' spot)
local DEFAULT_POSITION = { point = "RIGHT", x = -3, y = -11 }

local holder
local pending = false   -- a placement held back by combat

local function GetDb()
    local uf = ns.db and ns.db.profile and ns.db.profile.unitframes
    return uf and uf.flagCarriers
end

--------------------------------------------------
-- 3. POSITION (per Edit Mode layout), by default where the boss frames start
--------------------------------------------------
local function RefillDefault()
    local point, x, y, bossH = "RIGHT", -3, -11, nil
    if ns.BossFrames and ns.BossFrames.DefaultSpot then
        local ok, p, bx, by, h = pcall(ns.BossFrames.DefaultSpot)
        if ok and p then point, x, y, bossH = p, bx or 0, by or 0, h end
    end
    -- the same top as the first boss frame
    if bossH and bossH > 0 and not point:find("TOP") then
        if point:find("BOTTOM") then
            y = y + bossH - HOLDER_H
        else
            y = y + (bossH - HOLDER_H) / 2
        end
    end
    DEFAULT_POSITION.point, DEFAULT_POSITION.x, DEFAULT_POSITION.y = point, math_floor(x + 0.5), math_floor(y + 0.5)
end

local function LayoutStore(layoutName)
    local db = GetDb()
    if not db then return nil end
    layoutName = layoutName or LEM:GetActiveLayoutName() or "Modern"
    db.layouts = db.layouts or {}
    -- (a layout with no spot of its own reads the profile's home layout's: ProfileLayout.lua)
    return ns.LayoutHome(db.layouts, layoutName)
end

local function ApplyPosition(layoutName)
    if not holder then return end
    -- Blizzard's protected buttons hang from the holder once it carries them
    if InCombatLockdown() then pending = true return end
    RefillDefault()
    local store = LayoutStore(layoutName)
    local pos = (store and store.point) and store or DEFAULT_POSITION
    holder:ClearAllPoints()
    holder:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
end

local function OnFrameMoved(_, layoutName, point, x, y)
    local store = LayoutStore(layoutName)
    if store then store.point, store.x, store.y = point, math_floor(x + 0.5), math_floor(y + 0.5) end
end

--------------------------------------------------
-- 4. BLIZZARD'S FRAMES ON THE HOLDER
--------------------------------------------------
local placing = false
local function Place()
    local container = _G.ArenaEnemyFramesContainer
    if placing or not (container and holder) then return end
    if InCombatLockdown() then pending = true return end
    pending = false
    placing = true
    if container:GetParent() ~= holder then container:SetParent(holder) end
    container:ClearAllPoints()
    container:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, -NAME_H)
    placing = false
end

--------------------------------------------------
-- 5. EDIT MODE SAMPLE: two carriers in Blizzard's art, shown while no real one is up
--------------------------------------------------
local SAMPLES = {
    { class = "WARRIOR", faction = "Alliance", health = 0.72, power = 0.35, powerColor = { 1, 0, 0 } },
    { class = "ROGUE",   faction = "Horde",    health = 0.41, power = 0.80, powerColor = { 1, 1, 0 } },
}

local function CreateSampleFrame(parent, index, data)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -RIGHT_IN, -(NAME_H + (index - 1) * (FRAME_H + SPACING)))

    local portrait = f:CreateTexture(nil, "BACKGROUND")
    portrait:SetSize(30, 30)
    portrait:SetPoint("TOPRIGHT", -11, -4)
    portrait:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    local coords = _G.CLASS_ICON_TCOORDS and _G.CLASS_ICON_TCOORDS[data.class]
    if coords then portrait:SetTexCoord(coords[1], coords[2], coords[3], coords[4]) end

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(72, 17)
    bg:SetPoint("TOPLEFT", 2, -10)
    bg:SetColorTexture(0, 0, 0, 0.5)

    local function Bar(y, value, r, g, b)
        local bar = CreateFrame("StatusBar", nil, f)
        bar:SetSize(70, 8)
        bar:SetPoint("TOPLEFT", 2, y)
        bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        bar:SetStatusBarColor(r, g, b)
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(value)
        return bar
    end
    Bar(-12, data.health, 0, 1, 0)
    Bar(-20, data.power, data.powerColor[1], data.powerColor[2], data.powerColor[3])

    -- the frame art over the bars (Blizzard's nested frames do the same)
    local over = CreateFrame("Frame", nil, f)
    over:SetAllPoints()
    over:SetFrameLevel(f:GetFrameLevel() + 5)
    local art = over:CreateTexture(nil, "BACKGROUND")
    art:SetSize(102, 32)
    art:SetPoint("TOPLEFT", 0, -2)
    art:SetTexture("Interface\\ArenaEnemyFrame\\UI-ArenaTargetingFrame")
    art:SetTexCoord(0, 0.796, 0, 0.5)

    local name = over:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    name:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 3, 24)
    name:SetJustifyH("LEFT")
    name:SetText((_G.LOCALIZED_CLASS_NAMES_MALE and _G.LOCALIZED_CLASS_NAMES_MALE[data.class]) or data.class)

    local icon = over:CreateTexture(nil, "OVERLAY")
    icon:SetSize(40, 40)
    icon:SetPoint("LEFT", f, "RIGHT", -12, -10)
    icon:SetTexture("Interface\\TargetingFrame\\UI-PVP-" .. data.faction)
    return f
end

local function CreatePreview()
    holder.preview = CreateFrame("Frame", nil, holder)
    holder.preview:SetAllPoints()
    holder.preview:Hide()
    for i, data in ipairs(SAMPLES) do CreateSampleFrame(holder.preview, i, data) end
end

-- a real carrier on show: no sample over it
local function RealCarrierShown()
    local container = _G.ArenaEnemyMatchFramesContainer
    if not (container and container:IsVisible()) then return false end
    for i = 1, (_G.MAX_ARENA_ENEMIES or 5) do
        local f = _G["ArenaEnemyMatchFrame" .. i]
        if f and f:IsShown() then return true end
    end
    return false
end

local function ShowPreview()
    if holder then holder.preview:SetShown(not RealCarrierShown()) end
end

local function HidePreview()
    if holder then holder.preview:Hide() end
end

--------------------------------------------------
-- 6. SETUP
--------------------------------------------------
function FC:ShouldLoad()
    local uf = ns.db and ns.db.profile and ns.db.profile.unitframes
    return uf and uf.enabled and uf.flagCarriers and uf.flagCarriers.enabled and true or false
end

function FC:Init()
    if self.initialized then return end
    local container = _G.ArenaEnemyFramesContainer
    if not container then return end
    self.initialized = true

    holder = CreateFrame("Frame", "FlareUI_FlagCarriers", UIParent)
    holder:SetSize(HOLDER_W, HOLDER_H)
    holder:SetClampedToScreen(true)
    holder.editModeName = "FlareUI Flag Carriers"
    CreatePreview()

    RefillDefault()
    LEM:AddFrame(holder, OnFrameMoved, DEFAULT_POSITION, "FlareUI Flag Carriers")
    if not pcall(ApplyPosition) then
        holder:ClearAllPoints()
        holder:SetPoint(DEFAULT_POSITION.point, UIParent, DEFAULT_POSITION.point, DEFAULT_POSITION.x, DEFAULT_POSITION.y)
    end
    -- the selection box over the sample
    local selection = LEM.frameSelections and LEM.frameSelections[holder]
    if selection then selection:SetFrameLevel(holder.preview:GetFrameLevel() + 10) end

    -- Blizzard hands the container back to its column on every show (and when the UI comes back)
    hooksecurefunc(container, "SetParent", Place)
    Place()

    local regen = CreateFrame("Frame")
    regen:RegisterEvent("PLAYER_REGEN_ENABLED")
    regen:SetScript("OnEvent", function()
        if not pending then return end
        ApplyPosition()
        Place()
    end)

    LEM:RegisterCallback("layout", function(layoutName) ApplyPosition(layoutName) end)
    LEM:RegisterCallback("enter", ShowPreview)
    LEM:RegisterCallback("exit", HidePreview)
    -- the boss frames' spot can change after login (frame style, their layout)
    C_Timer.After(0, function() ApplyPosition() end)
end
