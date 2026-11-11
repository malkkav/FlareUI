local _, ns = ...
local L = ns.L

--------------------------------------------------
-- TOTEMS
-- Blizzard's TotemFrame lives in the parked PlayerFrame, so it moves onto FlareUI Totems, an Edit Mode
-- frame with a size and totems per row. Blizzard's code still runs it.
--------------------------------------------------

--------------------------------------------------
-- 1. MODULE REGISTRATION
--------------------------------------------------
ns.Totems = ns.Totems or {}
local TOT = ns.Totems
ns.modules["Totems"] = TOT

--------------------------------------------------
-- 2. UPVALUES / CONSTANTS
--------------------------------------------------
local LEM = LibStub("FlareEditMode")
local ipairs = ipairs
local math_floor, math_ceil, math_max, math_min = math.floor, math.ceil, math.max, math.min
local table_sort = table.sort

-- under the player frame, beside the pet frame
local DEFAULT_POSITION = { point = "BOTTOM", x = -361, y = 270 }
local DEFAULT_SIZE, DEFAULT_PER_ROW = 90, 4
-- Blizzard's totem button geometry (TotemButtonTemplate)
local BUTTON, ICON, RING = 37, 22, 30
local COL_STEP, ROW_STEP, TEXT_BELOW = 31, 42, 7
local MAX = _G.MAX_TOTEMS or 4
local PREVIEW_ICONS = { "Spell_Nature_StoneSkinTotem", "Spell_Fire_SearingTotem",
                        "Spell_Nature_ManaRegenTotem", "Spell_Nature_GroundingTotem" }
local PREVIEW_TIMES = { "1:45", "52", "4:10", "12" }

local holder

local function GetDb()
    return ns.db and ns.db.profile and ns.db.profile.unitframes
end

local function GetSettings()
    local db = GetDb()
    if not db then return DEFAULT_SIZE / 100, DEFAULT_PER_ROW end
    db.totems = db.totems or {}
    local size = db.totems.size or DEFAULT_SIZE
    local perRow = math_max(1, math_min(MAX, db.totems.perRow or DEFAULT_PER_ROW))
    return size / 100, perRow
end

--------------------------------------------------
-- 3. POSITION (per Edit Mode layout)
--------------------------------------------------
local function GetLayoutStore(layoutName)
    local db = GetDb()
    if not db then return nil end
    layoutName = layoutName or LEM:GetActiveLayoutName() or "Modern"
    db.totemLayouts = db.totemLayouts or {}
    -- (a layout with no spot of its own reads the profile's home layout's: ProfileLayout.lua)
    return ns.LayoutHome(db.totemLayouts, layoutName)
end

local function ApplyPosition(layoutName)
    if not holder then return end
    local store = GetLayoutStore(layoutName)
    local pos = (store and store.point) and store or DEFAULT_POSITION
    holder:ClearAllPoints()
    holder:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
end

local function OnFrameMoved(_, layoutName, point, x, y)
    local store = GetLayoutStore(layoutName)
    if not store then return end
    store.point, store.x, store.y = point, math_floor(x + 0.5), math_floor(y + 0.5)
end

--------------------------------------------------
-- 4. GRID (slot n, perRow to a row, rows going down; offsets in the scaled frame's units)
--------------------------------------------------
-- Rows keep room for the time only while it shows under the icons; otherwise they close up to the
-- columns' spacing
local function TimerBelow()
    local db = GetDb()
    local totems = db and db.totems
    return (totems and totems.timer or "none") == "below"
end

local function RowStep()
    return TimerBelow() and ROW_STEP or COL_STEP
end

local function SlotOffset(n, perRow)
    local col = (n - 1) % perRow
    local row = math_floor((n - 1) / perRow)
    return col * COL_STEP, -row * RowStep()
end

local function PlaceInGrid(buttons, parent, perRow)
    for n, button in ipairs(buttons) do
        local x, y = SlotOffset(n, perRow)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    end
end

local function ByLayoutIndex(a, b) return (a.layoutIndex or 0) < (b.layoutIndex or 0) end

-- Aura Swipe and Aura Timer, as on the Buffs & Debuffs icons (round): the swipe over the icon,
-- round the ring, both (one disc over icon and ring) or none; the time under the icon, along its
-- bottom, in its middle or not at all. On Blizzard's own buttons, and on the Edit Mode samples.
local MEDIA = "Interface\\AddOns\\FlareUI\\Media\\Auras\\"
local SWIPE_ROUND = MEDIA .. "BorderRoundThick"
local SWIPE_EDGE = MEDIA .. "Edge"
local SWIPE_DISC = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local function TotemLook()
    local db = GetDb()
    local t = db and db.totems or {}
    return t.swipe or "both", t.timer or "none"
end

-- button: the totem button; cd: its cooldown; text: its time; ring: its border art
local function StyleTotem(button, cd, text, ring)
    local swipe, timer = TotemLook()
    if cd then
        cd:ClearAllPoints()
        -- Blizzard draws the ring art 1 px right and 1.5 px down of the icon: only the ring swipe follows
        -- it. A disc stays on the icon at the icon's size, or it reads as a shadow growing bottom right.
        local onRing = swipe == "border"
        cd:SetPoint("CENTER", onRing and ring or button, "CENTER")
        cd:SetSize(onRing and RING or ICON, onRing and RING or ICON)
        cd:SetFrameLevel(button:GetFrameLevel() + ((onRing or swipe == "both") and 3 or 1))
        cd:SetUseCircularEdge(true)
        if swipe == "none" then
            cd:SetDrawSwipe(false)
            cd:SetDrawEdge(false)
        elseif swipe == "border" then
            cd:SetDrawSwipe(true)
            cd:SetDrawEdge(false)
            cd:SetSwipeTexture(SWIPE_ROUND)
            cd:SetSwipeColor(0, 0, 0, 0.7)
        else
            cd:SetDrawSwipe(true)
            cd:SetSwipeTexture(SWIPE_DISC)
            cd:SetSwipeColor(0, 0, 0, swipe == "both" and 0.7 or 0.82)
            cd:SetDrawEdge(true)
            cd:SetEdgeTexture(SWIPE_EDGE, 1, 1, 1, 1)
            if cd.SetEdgeScale then cd:SetEdgeScale(1.6) end
        end
    end
    if text then
        -- the time on a layer of its own, above the swipe (Blizzard keeps writing it)
        local layer = button.FlareUI_TextLayer
        if not layer then
            layer = CreateFrame("Frame", nil, button)
            layer:SetAllPoints(button)
            button.FlareUI_TextLayer = layer
        end
        layer:SetFrameLevel(button:GetFrameLevel() + 5)
        if text:GetParent() ~= layer then text:SetParent(layer) end
        text:SetDrawLayer("OVERLAY")
        text:ClearAllPoints()
        if timer == "middle" then
            text:SetPoint("CENTER", button, "CENTER", 0, 0)
        elseif timer == "bottom" then
            text:SetPoint("BOTTOM", ring or button, "BOTTOM", 0, 2)
        else
            text:SetPoint("TOP", button, "BOTTOM", 0, 5)
        end
        text:SetAlpha(timer == "none" and 0 or 1)
    end
end

-- After Blizzard's Layout the shown buttons go back into the grid
local active = {}
local function ArrangeTotems()
    local frame = _G.TotemFrame
    if not (frame and frame.totemPool and holder) then return end
    local _, perRow = GetSettings()
    for i = #active, 1, -1 do active[i] = nil end
    for button in frame.totemPool:EnumerateActive() do
        if button:IsShown() then active[#active + 1] = button end
    end
    table_sort(active, ByLayoutIndex)
    PlaceInGrid(active, frame, perRow)
    for _, button in ipairs(active) do
        StyleTotem(button, button.Icon and button.Icon.Cooldown, button.Duration, button.Border)
    end
end

--------------------------------------------------
-- 5. BLIZZARD'S TOTEM FRAME, REHOMED
-- A managed frame: Blizzard re-parents it into PlayerFrame on every show, so it is pulled back
--------------------------------------------------
local anchoring = false
local function AnchorTotemFrame()
    local frame = _G.TotemFrame
    if anchoring or not (frame and holder) then return end
    anchoring = true
    if frame:GetParent() ~= holder then frame:SetParent(holder) end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    anchoring = false
end

local function AdoptTotemFrame()
    local frame = _G.TotemFrame
    if not frame then return end
    AnchorTotemFrame()
    hooksecurefunc(frame, "SetParent", AnchorTotemFrame)
    hooksecurefunc(frame, "SetPoint", AnchorTotemFrame)
    if frame.Layout then hooksecurefunc(frame, "Layout", ArrangeTotems) end
end

--------------------------------------------------
-- 6. EDIT MODE PREVIEW (four sample totems in the same grid and size)
--------------------------------------------------
local function CreatePreview()
    local preview = CreateFrame("Frame", nil, holder)
    preview:SetSize(1, 1)
    preview:SetPoint("TOPLEFT")
    preview:Hide()
    preview.buttons = {}
    for i = 1, #PREVIEW_ICONS do
        local b = CreateFrame("Frame", nil, preview)
        b:SetSize(BUTTON, BUTTON)

        local icon = b:CreateTexture(nil, "BACKGROUND", nil, 2)
        icon:SetSize(ICON, ICON)
        icon:SetPoint("CENTER")
        icon:SetTexture("Interface\\Icons\\" .. PREVIEW_ICONS[i])
        local mask = b:CreateMaskTexture()
        mask:SetAtlas("CircleMask")
        mask:SetAllPoints(icon)
        icon:AddMaskTexture(mask)

        local ring = b:CreateTexture(nil, "OVERLAY")
        ring:SetAtlas("UI-HUD-UnitFrame-TotemFrame")
        ring:SetSize(RING, RING)
        ring:SetPoint("CENTER", 1, -1.5)

        local text = b:CreateFontString(nil, "BACKGROUND", "GameFontNormalSmall")
        text:SetPoint("TOP", b, "BOTTOM", 0, 5)
        text:SetText(PREVIEW_TIMES[i])
        local cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
        cd:SetHideCountdownNumbers(true)
        cd:SetReverse(true)
        b.Cooldown, b.Duration, b.Ring = cd, text, ring

        preview.buttons[i] = b
    end
    holder.preview = preview
end

-- shown: Edit Mode; a fight in it brings the live totems back (ns.OnEditFight)
local function SetPreview(shown)
    if not holder then return end
    shown = shown and ns.EditPreviewing()
    holder.preview:SetShown(shown)
    -- live totems step aside while the samples show, and can't be right-clicked away unseen
    local frame = _G.TotemFrame
    if frame then
        frame:SetAlpha(shown and 0 or 1)
        for _, button in ipairs({ frame:GetChildren() }) do
            if button.EnableMouse then pcall(button.EnableMouse, button, not shown) end
        end
    end
end

--------------------------------------------------
-- 7. SIZE AND GRID
-- The holder is sized to the grid and the totems scaled inside it, so its position stays put
--------------------------------------------------
local function ApplyLayout()
    if not holder then return end
    local scale, perRow = GetSettings()
    local rows = math_ceil(MAX / perRow)
    local width = BUTTON + (perRow - 1) * COL_STEP
    local height = BUTTON + (rows - 1) * RowStep() + (TimerBelow() and TEXT_BELOW or 0)
    holder:SetSize(width * scale, height * scale)

    holder.preview:SetScale(scale)
    PlaceInGrid(holder.preview.buttons, holder.preview, perRow)
    for i, b in ipairs(holder.preview.buttons) do
        StyleTotem(b, b.Cooldown, b.Duration, b.Ring)
        b.Cooldown:SetCooldown(GetTime() - 12 * i, 60)   -- a running sample swipe
    end

    local frame = _G.TotemFrame
    if frame then
        frame:SetScale(scale)
        ArrangeTotems()
    end
end

local function BuildSettings()
    local function get(key, default)
        return function()
            local db = GetDb()
            return db and db.totems and db.totems[key] or default
        end
    end
    local function set(key)
        return function(_, value)
            local db = GetDb()
            if not db then return end
            db.totems = db.totems or {}
            db.totems[key] = value
            ApplyLayout()
        end
    end
    -- the ring styles have their own defaults
    local style = ns.UFRing and ns.UFRing.On() and ns.UFRing.DefaultTotems() or {}
    local size, perRow = style.size or DEFAULT_SIZE, style.perRow or DEFAULT_PER_ROW
    -- one Frame section (dropdowns, sliders, switches); Fading comes after it (Visibility.lua)
    return ns.EditSection("Frame", {
        { name = L["Size"], kind = LEM.SettingType.Slider, default = size, minValue = 50, maxValue = 200, valueStep = 5,
          get = get("size", size), set = set("size") },
        { name = L["Totems per Row"], kind = LEM.SettingType.Slider, default = perRow, minValue = 1, maxValue = MAX, valueStep = 1,
          get = get("perRow", perRow), set = set("perRow") },
        { name = L["Aura Swipe"], kind = LEM.SettingType.Dropdown, default = "both", get = get("swipe", "both"), set = set("swipe"),
          values = {
              { text = L["Over the Icon"], value = "icon", isRadio = true },
              { text = L["Around the Border"], value = "border", isRadio = true },
              { text = L["Both"], value = "both", isRadio = true },
              { text = L["Off"], value = "none", isRadio = true },
          } },
        { name = L["Aura Timer"], kind = LEM.SettingType.Dropdown, default = "none", get = get("timer", "none"), set = set("timer"),
          values = {
              { text = L["Under the Icon"], value = "below", isRadio = true },
              { text = L["Bottom of the Icon"], value = "bottom", isRadio = true },
              { text = L["Middle of the Icon"], value = "middle", isRadio = true },
              { text = L["Off"], value = "none", isRadio = true },
          } },
    })
end

--------------------------------------------------
-- 8. SETUP
--------------------------------------------------
-- Only with FlareUI's player frame on
function TOT:ShouldLoad()
    local db = GetDb()
    if not (db and db.enabled) then return false end
    local player = db.units and db.units.player
    return not (player and player.enabled == false)
end

function TOT:Init()
    if self.initialized or not _G.TotemFrame then return end
    self.initialized = true

    -- the ring styles have their own default position (a style switch reloads)
    if ns.UFRing and ns.UFRing.On() then
        local _, totemPosition = ns.UFRing.DefaultPositions()
        for key, value in pairs(totemPosition) do DEFAULT_POSITION[key] = value end
    end
    holder = CreateFrame("Frame", "FlareUI_Totems", UIParent)
    holder:SetFrameStrata("LOW")
    holder:SetClampedToScreen(true)
    CreatePreview()
    ApplyPosition()
    LEM:AddFrame(holder, OnFrameMoved, DEFAULT_POSITION, "FlareUI Totems")
    LEM:AddFrameSettings(holder, BuildSettings())

    AdoptTotemFrame()
    ApplyLayout()

    LEM:RegisterCallback("layout", function(layoutName) ApplyPosition(layoutName) end)
    LEM:RegisterCallback("enter", function() SetPreview(true) end)
    LEM:RegisterCallback("exit", function() SetPreview(false) end)
    ns.OnEditFight(function() SetPreview(LEM:IsInEditMode()) end)
end
