local _, ns = ...
local L = ns.L

--------------------------------------------------
-- MOVERS
-- Edit Mode frames "FlareUI Loot Rolls" (GroupLootContainer), "FlareUI Toasts" (AlertFrame) and
-- "FlareUI Battleground Objectives" (UIWidgetTopCenterContainerFrame), each with a sample in Edit Mode. Hooks only: the loot rolls share a layout with protected frames,
-- so they are re-anchored after Blizzard places them.
--------------------------------------------------

--------------------------------------------------
-- 1. MODULE REGISTRATION
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

-- Blizzard's geometry: the first roll frame sits 16.5 above the container's bottom, the first
-- toast 20 above AlertFrame's
local ROLL_W, ROLL_H, ROLL_BOTTOM = 277, 67, 16.5
local TOAST_W, TOAST_H, TOAST_BOTTOM = 312, 89, 20
-- the battleground scores: Blizzard's container sits at TOP 0,-15 and grows down from its top
local OBJ_W, OBJ_H = 180, 36   -- (the sample's size: only the scores, 11-11)
-- FlareUI Thick round the scores (the sample and the real ones), PAD out from what they show
local OBJ_BORDER, OBJ_EDGE, OBJ_PAD = "FlareUI Thick", 16, 6

local DEFAULTS = {
    loot  = { point = "BOTTOM", x = 0, y = 173 },   -- between the player cast bar and the action bars
    toast = { point = "TOP", x = 0, y = -158 },
    objectives = { point = "TOP", x = 0, y = -15 },   -- Blizzard's own spot
}

local holders = {}   -- key -> holder frame

local function GetDb()
    return ns.db and ns.db.profile and ns.db.profile.tweaks
end

-- FLAG CARRIER FRAMES (Quality of Life > Hide Clutter, off; 11-11, a player's question): in a
-- battleground Blizzard's old arena frames show the two flag carriers under the minimap
-- (Deprecated_ArenaUI). They are protected unit buttons in Blizzard's right-hand layout, so they are
-- hidden through Blizzard's own CVar, out of combat (its change shows or hides them), not moved.
-- Switching off gives the CVar back once; it is the player's again after that (quiet defaults).
function ns.ApplyFlagCarriers()
    local global = ns.db and ns.db.global
    if not global then return end
    if InCombatLockdown() then
        local wait = CreateFrame("Frame")
        wait:RegisterEvent("PLAYER_REGEN_ENABLED")
        wait:SetScript("OnEvent", function(self) self:UnregisterAllEvents(); ns.ApplyFlagCarriers() end)
        return
    end
    local db = GetDb()
    if db and db.hideFlagCarriers then
        if C_CVar.GetCVar("showArenaEnemyFrames") ~= "0" then C_CVar.SetCVar("showArenaEnemyFrames", "0") end
        global.flagCarriersSet = true
    elseif global.flagCarriersSet then
        global.flagCarriersSet = nil
        C_CVar.SetCVar("showArenaEnemyFrames", "1")
    end
end
do
    local login = CreateFrame("Frame")
    login:RegisterEvent("PLAYER_LOGIN")
    login:SetScript("OnEvent", function() ns.ApplyFlagCarriers() end)
end

--------------------------------------------------
-- 3. POSITION (per Edit Mode layout)
--------------------------------------------------
local function GetLayoutStore(key, layoutName)
    local db = GetDb()
    if not db then return nil end
    layoutName = layoutName or LEM:GetActiveLayoutName() or "Modern"
    db.moverLayouts = db.moverLayouts or {}
    -- (a layout with no spot of its own starts from the profile's home layout's: ProfileLayout.lua)
    local store = ns.LayoutHome(db.moverLayouts, layoutName)
    if rawget(store, key) == nil then
        local home = store[key]
        store[key] = type(home) == "table" and CopyTable(home) or {}
    end
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
    holder:SetClampedToScreen(true)
    -- MEDIUM (UIParent's), under Edit Mode's selection box (MEDIUM, level 1000)
    holder.preview = CreateFrame("Frame", nil, holder)
    holder.preview:SetAllPoints()
    holder.preview:Hide()
    holders[key] = holder
    ApplyPosition(key)
    LEM:AddFrame(holder, Mover(key), DEFAULTS[key], label)
    -- the selection box over the sample panel
    local selection = LEM.frameSelections and LEM.frameSelections[holder]
    if selection then selection:SetFrameLevel(holder.preview:GetFrameLevel() + 10) end
    return holder
end

--------------------------------------------------
-- 4. LOOT ROLLS
-- GroupLootContainer goes back on the holder after every placement; its height stays 1 so the
-- bottom managed frames leave no room for it.
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

-- Blizzard's grey roll-frame edge in the frames' bronze (11-11 Marcus): greyed, then tinted, so the
-- art keeps its shading. The sample's and every real roll frame's (GroupLootFrame1-4, made at load).
local function BronzeLootBorder(texture)
    if not texture then return end
    local c = ns.BORDER_COLOR
    texture:SetDesaturated(true)
    texture:SetVertexColor(c.r * 1.25, c.g * 1.25, c.b * 1.25)
end

local function BronzeLootFrames()
    for i = 1, (_G.NUM_GROUP_LOOT_FRAMES or 4) do
        local frame = _G["GroupLootFrame" .. i]
        if frame then BronzeLootBorder(frame.Border) end
    end
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
    BronzeLootBorder(border)

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
    name:SetText(L["|cff1eff00Sample Item|r"])

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
-- AlertFrame is the base every toast stacks from. The loot rolls are part of that stack, so while
-- they show elsewhere the stack is walked again without them.
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
    name:SetText(L["Sample Recipe"])
end

--------------------------------------------------
-- 5b. SCALE (Edit Mode, 11-11 Marcus): the loot rolls' and the toasts' size. Blizzard's frames hang
-- from UIParent, so each one takes the scale as it shows; the holder and its sample grow with it.
--------------------------------------------------
local function Scale(key)
    local db = GetDb()
    local v = db and tonumber(db[key == "loot" and "lootScale" or "toastScale"]) or 1
    return math.max(0.5, math.min(2, v))
end

local function ScaleHolder(key, w, h)
    local holder = holders[key]
    if not holder then return end
    local scale = Scale(key)
    holder:SetSize(w * scale, h * scale)
    holder.preview:SetScale(scale)
end

local function ScaleLootFrames()
    local scale = Scale("loot")
    for i = 1, (_G.NUM_GROUP_LOOT_FRAMES or 4) do
        local frame = _G["GroupLootFrame" .. i]
        if frame and not (InCombatLockdown() and frame:IsProtected()) then frame:SetScale(scale) end
    end
end

-- every toast as Blizzard shows it: the queued kinds as each comes out of its pool, the single ones now
local function ScaleToast(frame)
    if frame and frame.SetScale then frame:SetScale(Scale("toast")) end
end
local function ScaleToasts()
    local base = _G.AlertFrame
    for _, sub in ipairs(base and base.alertFrameSubSystems or {}) do
        if sub.alertFramePool and sub.alertFramePool.EnumerateActive then
            for frame in sub.alertFramePool:EnumerateActive() do ScaleToast(frame) end
        elseif sub.alertFrame then
            ScaleToast(sub.alertFrame)
        end
    end
end
local function HookToastScale()
    local base = _G.AlertFrame
    for _, sub in ipairs(base and base.alertFrameSubSystems or {}) do
        if sub.ShowAlert and not sub.FlareUI_Scaled then
            sub.FlareUI_Scaled = true
            hooksecurefunc(sub, "ShowAlert", function(self)
                if self.alertFramePool and self.alertFramePool.EnumerateActive then
                    for frame in self.alertFramePool:EnumerateActive() do ScaleToast(frame) end
                end
            end)
        end
    end
    ScaleToasts()
end

-- the Edit Mode dialogs' Scale (11-11: a Toast Sample dropdown with Blizzard's other toasts was tried and
-- removed, Forever lacks their pieces)
local function ScaleSetting(key, w, h, apply)
    local field = key == "loot" and "lootScale" or "toastScale"
    return { name = L["Scale"], kind = LEM.SettingType.Slider, default = 100, minValue = 50, maxValue = 200, valueStep = 5,
        formatter = function(value) return value .. "%" end,
        get = function() return math.floor(Scale(key) * 100 + 0.5) end,
        set = function(_, value)
            local db = GetDb()
            if not db then return end
            db[field] = value ~= 100 and value / 100 or nil
            ScaleHolder(key, w, h)
            apply()
        end }
end

--------------------------------------------------
-- 6. BATTLEGROUND OBJECTIVES
-- The top-centre widget container (flag and base scores, resources, timers). A plain frame, not an
-- Edit Mode system or a managed frame: it goes back on the holder after anything places it.
--------------------------------------------------
-- EnhanceQoL Mover's own "Top Center Widgets" entry (off by default): turned on, it moves them, not us
local function EQoLMovesObjectives()
    local eqol = _G.EnhanceQoL
    local fns = type(eqol) == "table" and type(eqol.Mover) == "table" and eqol.Mover.functions
    if type(fns) ~= "table" or type(fns.IsFrameEnabled) ~= "function" then return false end
    local ok, on = pcall(fns.IsFrameEnabled, "UIWidgetTopCenterContainerFrame")
    return ok and on == true
end

local placingObjectives = false
local function PlaceObjectives()
    local container, holder = _G.UIWidgetTopCenterContainerFrame, holders.objectives
    if placingObjectives or not (container and holder) or EQoLMovesObjectives() then return end
    if InCombatLockdown() and container:IsProtected() then return end
    placingObjectives = true
    container:ClearAllPoints()
    container:SetPoint("TOP", holder, "TOP", 0, 0)
    placingObjectives = false
end

-- The dark plate in FlareUI Thick (11-11 Marcus): the sample's, and the one behind the real scores
local function ObjectivesBox(frame)
    local file = LibStub("LibSharedMedia-3.0"):Fetch("border", OBJ_BORDER)
    local inset = 4
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = file, edgeSize = ns.BorderEdgeSize(file, OBJ_EDGE),
        insets = { left = inset, right = inset, top = inset, bottom = inset } })
    frame:SetBackdropColor(0, 0, 0, 0.6)
    local c = ns.BORDER_COLOR
    frame:SetBackdropBorderColor(c.r, c.g, c.b, c.a or 1)
end

-- a faction emblem and its score, twice, each pair centred in its half, icon and text on one line
-- (the old target-frame emblems sat off-centre in their art: the PvP currency ones are square)
local function CreateObjectivesPreview(holder)
    local p = holder.preview
    local box = CreateFrame("Frame", nil, p, "BackdropTemplate")
    box:SetAllPoints()
    ObjectivesBox(box)
    local ICON, GAP = 22, 5
    local function Side(icon, score, half)
        local t = box:CreateTexture(nil, "ARTWORK")
        t:SetSize(ICON, ICON)
        t:SetTexture(icon)
        local n = box:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
        n:SetText(score)
        local width = ICON + GAP + (n:GetUnboundedStringWidth() or 30)
        t:SetPoint("LEFT", box, "CENTER", half * OBJ_W / 4 - width / 2, 0)
        n:SetPoint("LEFT", t, "RIGHT", GAP, 0)
    end
    Side("Interface\\PVPFrame\\PVP-Currency-Alliance", "2 / 3", -1)
    Side("Interface\\PVPFrame\\PVP-Currency-Horde", "1 / 3", 1)
end

-- the real scores' plate: behind Blizzard's container, as large as what it shows, only while it shows
-- something (a frame of its own: the container's widgets are Blizzard's)
local objectivesBox
local function UpdateObjectivesBox()
    local container = _G.UIWidgetTopCenterContainerFrame
    if not (container and objectivesBox) then return end
    local w, h = container:GetSize()
    local showing = container:IsVisible() and (container.numWidgetsShowing or 1) > 0 and (w or 0) > 2 and (h or 0) > 2
    objectivesBox:SetShown(showing and true or false)
end

local function CreateObjectivesBox(container)
    objectivesBox = CreateFrame("Frame", "FlareUI_BattlegroundObjectivesBox", UIParent, "BackdropTemplate")
    objectivesBox:SetPoint("TOPLEFT", container, "TOPLEFT", -OBJ_PAD, OBJ_PAD)
    objectivesBox:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", OBJ_PAD, -OBJ_PAD)
    ObjectivesBox(objectivesBox)
    ns.CopyStrata(objectivesBox, container)
    objectivesBox:SetFrameLevel(math.max(0, container:GetFrameLevel() - 1))
    objectivesBox:EnableMouse(false)
    container:HookScript("OnShow", UpdateObjectivesBox)
    container:HookScript("OnHide", UpdateObjectivesBox)
    container:HookScript("OnSizeChanged", UpdateObjectivesBox)
    UpdateObjectivesBox()
end

--------------------------------------------------
-- 7. SETUP
--------------------------------------------------
-- The Gamepad UI shows its own loot rolls and toasts
function MOV:ShouldLoad()
    local db = GetDb()
    return db and db.enabled and db.moveLootToasts ~= false and not ns.IsGamepadUI() or false
end

function MOV:Init()
    if self.initialized then return end
    self.initialized = true

    local loot = _G.GroupLootContainer
    if loot then
        local holder = CreateHolder("loot", "FlareUI_LootRolls", "FlareUI Loot Rolls", ROLL_W, ROLL_H)
        CreateLootPreview(holder)
        ScaleHolder("loot", ROLL_W, ROLL_H)
        ScaleLootFrames()
        LEM:AddFrameSettings(holder, ns.EditSection("Frame", { ScaleSetting("loot", ROLL_W, ROLL_H, ScaleLootFrames) }))
        hooksecurefunc(loot, "SetPoint", PlaceLoot)
        hooksecurefunc(loot, "SetHeight", FlattenLoot)
        PlaceLoot()
        BronzeLootFrames()
    end

    local base = _G.AlertFrame
    if base then
        local holder = CreateHolder("toast", "FlareUI_Toasts", "FlareUI Toasts", TOAST_W, TOAST_H)
        CreateToastPreview(holder)
        ScaleHolder("toast", TOAST_W, TOAST_H)
        HookToastScale()
        LEM:AddFrameSettings(holder, ns.EditSection("Frame", { ScaleSetting("toast", TOAST_W, TOAST_H, ScaleToasts) }))
        PlaceToasts()
        hooksecurefunc(base, "UpdateAnchors", RewalkToasts)
    end

    local objectives = _G.UIWidgetTopCenterContainerFrame
    if objectives then
        CreateObjectivesPreview(CreateHolder("objectives", "FlareUI_BattlegroundObjectives",
            "FlareUI Battleground Objectives", OBJ_W, OBJ_H))
        hooksecurefunc(objectives, "SetPoint", PlaceObjectives)
        PlaceObjectives()
        CreateObjectivesBox(objectives)
        -- a placement held back by combat
        local regen = CreateFrame("Frame")
        regen:RegisterEvent("PLAYER_REGEN_ENABLED")
        regen:SetScript("OnEvent", PlaceObjectives)
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
