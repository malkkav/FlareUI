local _, ns = ...

--------------------------------------------------
-- 1. MODULE REGISTRATION
-- Two Edit Mode frames for pop-ups Blizzard gives no place of their own:
--   FlareUI Loot Rolls  the Need / Greed / Pass frames (GroupLootContainer)
--   FlareUI Toasts      Blizzard's toast stack: new recipe learned, achievements, loot won...
-- Each shows a sample while Edit Mode is open. Part of Tweaks (Windows & Settings > Move Loot
-- Rolls & Toasts).
-- Hooks only: Blizzard's loot rolls share a layout with protected frames (the extra action
-- button), so nothing here writes onto Blizzard's frames or calls their layout code - the frames
-- are re-anchored after Blizzard has placed them.
--------------------------------------------------
ns.Movers = ns.Movers or {}
local MOV = ns.Movers
ns.modules["Movers"] = MOV

--------------------------------------------------
-- 2. UPVALUES / CONSTANTS
--------------------------------------------------
local _G = _G
local ipairs, pairs = ipairs, pairs
local math_floor = math.floor
local CreateFrame = CreateFrame
local LEM = LibStub("FlareEditMode")

-- Blizzard: a roll frame (277 x 67) is centred reservedSize (100) * (i - 0.5) above the
-- container's bottom (GroupLootContainer_Update), so the first one sits 16.5 above it
local ROLL_W, ROLL_H, ROLL_BOTTOM = 277, 67, 16.5
-- Blizzard: the first toast sits 10 above the top of AlertFrame (10 x 10), so 20 above its bottom
local TOAST_W, TOAST_H, TOAST_BOTTOM = 312, 89, 20

local DEFAULTS = {
    loot  = { point = "BOTTOM", x = 0, y = 173 },   -- between the player cast bar and the action bars
    toast = { point = "TOP", x = 0, y = -158 },     -- top centre, clear of the fight
}

local holders = {}   -- key -> holder frame

local function GetDb()
    return ns.db and ns.db.profile and ns.db.profile.tweaks
end

--------------------------------------------------
-- 3. POSITION (per Edit Mode layout)
--------------------------------------------------
local function GetLayoutStore(key, layoutName)
    local db = GetDb()
    if not db then return nil end
    layoutName = layoutName or LEM:GetActiveLayoutName() or "Modern"
    db.moverLayouts = db.moverLayouts or {}
    db.moverLayouts[layoutName] = db.moverLayouts[layoutName] or {}
    local store = db.moverLayouts[layoutName]
    store[key] = store[key] or {}
    return store[key]
end

local function ApplyPosition(key, layoutName)
    local holder = holders[key]
    if not holder then return end
    local store = GetLayoutStore(key, layoutName)
    local pos = (store and store.point) and store or DEFAULTS[key]
    holder:ClearAllPoints()
    holder:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
end

local function Mover(key)
    return function(_, layoutName, point, x, y)
        local store = GetLayoutStore(key, layoutName)
        if not store then return end
        store.point, store.x, store.y = point, math_floor(x + 0.5), math_floor(y + 0.5)
    end
end

local function CreateHolder(key, globalName, label, width, height)
    local holder = CreateFrame("Frame", globalName, UIParent)
    holder:SetSize(width, height)
    -- MEDIUM (UIParent's), under Edit Mode's selection box, which is MEDIUM at level 1000
    holder.preview = CreateFrame("Frame", nil, holder)
    holder.preview:SetAllPoints()
    holder.preview:Hide()
    holders[key] = holder
    ApplyPosition(key)
    LEM:AddFrame(holder, Mover(key), DEFAULTS[key], label)
    -- the sample is a full panel; the selection box goes over it, as on every other Edit Mode frame
    local selection = LEM.frameSelections and LEM.frameSelections[holder]
    if selection then selection:SetFrameLevel(holder.preview:GetFrameLevel() + 10) end
    return holder
end

--------------------------------------------------
-- 4. LOOT ROLLS
-- Blizzard lays GroupLootContainer out with the bottom managed frames (above the action bars) and
-- the roll frames hang off it. After each placement it goes back on the holder; its height is kept
-- at 1 so the frames that share that layout (cast bar, extra button) do not leave room for rolls
-- that are now elsewhere.
--------------------------------------------------
local placingLoot = false
local function PlaceLoot()
    local container, holder = _G.GroupLootContainer, holders.loot
    if placingLoot or not (container and holder) then return end
    placingLoot = true
    container:ClearAllPoints()
    container:SetPoint("BOTTOM", holder, "BOTTOM", 0, -ROLL_BOTTOM)
    placingLoot = false
end

local sizingLoot = false
local function FlattenLoot(container, height)
    if sizingLoot or height == 1 then return end
    sizingLoot = true
    container:SetHeight(1)
    sizingLoot = false
end

local function CreateLootPreview(holder)
    local p = holder.preview
    local bg = p:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\LootFrame\\LootToast")
    bg:SetTexCoord(0.28222656, 0.55273438, 0.30859375, 0.57031250)
    local border = p:CreateTexture(nil, "BORDER")
    border:SetSize(286, 76)
    border:SetPoint("CENTER")
    border:SetTexture("Interface\\LootFrame\\LootToast")
    border:SetTexCoord(0.00097656, 0.28027344, 0.43750000, 0.73437500)

    local icon = p:CreateTexture(nil, "ARTWORK")
    icon:SetSize(34, 34)
    icon:SetPoint("TOPLEFT", 10, -11)
    icon:SetTexture("Interface\\Icons\\INV_Sword_04")
    local ring = p:CreateTexture(nil, "OVERLAY")
    ring:SetAtlas("loottoast-itemborder-green")
    ring:SetSize(42, 42)
    ring:SetPoint("CENTER", icon, "CENTER", 0, -2)

    local name = p:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    name:SetSize(125, 30)
    name:SetPoint("TOPLEFT", 60, -15)
    name:SetJustifyH("LEFT")
    name:SetText("|cff1eff00Sample Item|r")

    local need = p:CreateTexture(nil, "ARTWORK")
    need:SetAtlas("lootroll-toast-icon-need-up")
    need:SetSize(32, 32)
    need:SetPoint("TOPLEFT", name, "TOPRIGHT", 17, 8)
    local pass = p:CreateTexture(nil, "ARTWORK")
    pass:SetAtlas("lootroll-toast-icon-pass-up")
    pass:SetSize(32, 32)
    pass:SetPoint("LEFT", need, "RIGHT", 6, 2)
    local greed = p:CreateTexture(nil, "ARTWORK")
    greed:SetAtlas("lootroll-toast-icon-greed-up")
    greed:SetSize(32, 32)
    greed:SetPoint("TOP", need, "BOTTOM", 0, 5)

    local timer = p:CreateTexture(nil, "ARTWORK")
    timer:SetSize(190, 8)
    timer:SetPoint("BOTTOMLEFT", 3, 2)
    timer:SetColorTexture(0, 0, 0)
    local fill = p:CreateTexture(nil, "ARTWORK", nil, 1)
    fill:SetSize(120, 8)
    fill:SetPoint("LEFT", timer, "LEFT")
    fill:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar")
    fill:SetVertexColor(1, 1, 0)
end

--------------------------------------------------
-- 5. TOASTS
-- AlertFrame is the base every toast stacks up from; Blizzard places it once and never again. The
-- loot rolls are part of the same stack (toasts climb over them), so while they are moved the
-- stack is walked again without them - as Blizzard does for a frame moved in Edit Mode.
--------------------------------------------------
local function PlaceToasts()
    local base, holder = _G.AlertFrame, holders.toast
    if not (base and holder) then return end
    base:ClearAllPoints()
    base:SetPoint("BOTTOM", holder, "BOTTOM", 0, -TOAST_BOTTOM)
end

local walking = false
local function RewalkToasts(container)
    local loot = _G.GroupLootContainer
    if walking or not (loot and holders.loot and loot:IsShown()) then return end
    walking = true
    local relative = container.baseAnchorFrame
    for _, subSystem in ipairs(container.alertFrameSubSystems or {}) do
        if subSystem.anchorFrame ~= loot then
            local result = subSystem:AdjustAnchors(relative)
            if not result or not result.IsInDefaultPosition or result:IsInDefaultPosition() then
                relative = result
            end
        end
    end
    walking = false
end

local function CreateToastPreview(holder)
    local p = holder.preview
    local bg = p:CreateTexture(nil, "BACKGROUND")
    bg:SetAtlas("recipetoast-bg", true)
    bg:SetPoint("CENTER")
    local icon = p:CreateTexture(nil, "BACKGROUND", nil, -1)
    icon:SetSize(64, 64)
    icon:SetPoint("LEFT", 18, 0)
    icon:SetTexture("Interface\\Icons\\INV_Scroll_03")
    local title = p:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    title:SetPoint("TOP", 31, -15)
    title:SetText(_G.NEW_RECIPE_LEARNED_TITLE or "New Recipe Learned!")
    local name = p:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    name:SetPoint("TOPLEFT", 98, -34)
    name:SetPoint("BOTTOMRIGHT", -32, 17)
    name:SetText("Sample Recipe")
end

--------------------------------------------------
-- 6. SETUP
--------------------------------------------------
-- the Gamepad UI shows its own loot rolls and toasts (switching it reloads the UI)
function MOV:ShouldLoad()
    local db = GetDb()
    return db and db.enabled and db.moveLootToasts ~= false and not ns.IsGamepadUI() or false
end

function MOV:Init()
    if self.initialized then return end
    self.initialized = true

    local loot = _G.GroupLootContainer
    if loot then
        CreateLootPreview(CreateHolder("loot", "FlareUI_LootRolls", "FlareUI Loot Rolls", ROLL_W, ROLL_H))
        hooksecurefunc(loot, "SetPoint", PlaceLoot)
        hooksecurefunc(loot, "SetHeight", FlattenLoot)
        PlaceLoot()
    end

    local base = _G.AlertFrame
    if base then
        CreateToastPreview(CreateHolder("toast", "FlareUI_Toasts", "FlareUI Toasts", TOAST_W, TOAST_H))
        PlaceToasts()
        hooksecurefunc(base, "UpdateAnchors", RewalkToasts)
    end

    LEM:RegisterCallback("layout", function(layoutName)
        for key in pairs(holders) do ApplyPosition(key, layoutName) end
    end)
    LEM:RegisterCallback("enter", function()
        for _, holder in pairs(holders) do holder.preview:Show() end
    end)
    LEM:RegisterCallback("exit", function()
        for _, holder in pairs(holders) do holder.preview:Hide() end
    end)
end
