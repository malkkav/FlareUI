local _, ns = ...
local L = ns.L

--------------------------------------------------
-- 1. MODULE REGISTRATION
-- Blizzard's totem frame (TotemFrame.lua: timers, a right-click on a totem dismisses it) is a child
-- of PlayerFrame, which FlareUI's unit frames hide - so with FlareUI's player frame on, a shaman lost
-- the totem timers. The frame is kept as Blizzard's own, running on Blizzard's code, and only given
-- a new home: FlareUI Totems, a frame placed in Edit Mode, with a size and a number of totems per
-- row (4 = Blizzard's single row, 2 = a 2 x 2 grid). In Edit Mode it shows four sample totems so it
-- can be seen while it is placed.
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

-- under the left half of FlareUI's player frame, beside the pet frame (UnitFrames.lua DEFAULT_POSITIONS)
local DEFAULT_POSITION = { point = "BOTTOM", x = -392, y = 256 }
local DEFAULT_SIZE, DEFAULT_PER_ROW = 95, 4
-- Blizzard's totem button geometry (TotemFrame.xml TotemButtonTemplate): a 37 button, buttons 6
-- apart from overlapping (spacing -6); the timer hangs 5 into the button and ~7 below it
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
-- 3. POSITION (per Edit Mode layout, like the unit frames)
--------------------------------------------------
local function GetLayoutStore(layoutName)
    local db = GetDb()
    if not db then return nil end
    layoutName = layoutName or LEM:GetActiveLayoutName() or "Modern"
    db.totemLayouts = db.totemLayouts or {}
    db.totemLayouts[layoutName] = db.totemLayouts[layoutName] or {}
    return db.totemLayouts[layoutName]
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
-- 4. GRID
-- Slot n (1-based, in Blizzard's totem order) goes perRow to a row, rows going down. Offsets are
-- in the scaled frame's own units, from its top-left corner.
--------------------------------------------------
local function SlotOffset(n, perRow)
    local col = (n - 1) % perRow
    local row = math_floor((n - 1) / perRow)
    return col * COL_STEP, -row * ROW_STEP
end

local function PlaceInGrid(buttons, parent, perRow)
    for n, button in ipairs(buttons) do
        local x, y = SlotOffset(n, perRow)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    end
end

local function ByLayoutIndex(a, b) return (a.layoutIndex or 0) < (b.layoutIndex or 0) end

-- Blizzard lays its buttons out in one row (TotemFrameMixin:Update -> Layout); each time, the
-- shown ones are put back in the grid
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
end

--------------------------------------------------
-- 5. BLIZZARD'S TOTEM FRAME, REHOMED
-- The totem frame is one of the player frame's managed frames: each time it shows, Blizzard
-- clears its anchors, parents it to PlayerBottomManagedFrameContainer (inside the parked
-- PlayerFrame, so never seen) and lays that out (ManagedFrameSystem.lua UpdateFrame). Each
-- time it comes straight back to the holder, parent and anchor. Nothing here is protected.
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
-- 6. EDIT MODE PREVIEW
-- Four sample totems in Blizzard's totem button look (round icon, ring, timer under it), in the
-- same grid and size as the real ones.
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

        preview.buttons[i] = b
    end
    holder.preview = preview
end

local function SetPreview(shown)
    if not holder then return end
    holder.preview:SetShown(shown)
    -- live totems step aside while the samples show, so the two do not overlap
    if _G.TotemFrame then _G.TotemFrame:SetAlpha(shown and 0 or 1) end
end

--------------------------------------------------
-- 7. SIZE AND GRID (Edit Mode settings)
-- The holder is sized to the whole grid at the chosen scale; the totems and the samples are scaled
-- inside it, so its saved position never moves with the size.
--------------------------------------------------
local function ApplyLayout()
    if not holder then return end
    local scale, perRow = GetSettings()
    local rows = math_ceil(MAX / perRow)
    local width = BUTTON + (perRow - 1) * COL_STEP
    local height = BUTTON + (rows - 1) * ROW_STEP + TEXT_BELOW
    holder:SetSize(width * scale, height * scale)

    holder.preview:SetScale(scale)
    PlaceInGrid(holder.preview.buttons, holder.preview, perRow)

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
    return {
        { name = L["Size"], kind = LEM.SettingType.Slider, default = DEFAULT_SIZE, minValue = 50, maxValue = 200, valueStep = 5,
          get = get("size", DEFAULT_SIZE), set = set("size") },
        { name = L["Totems per Row"], kind = LEM.SettingType.Slider, default = DEFAULT_PER_ROW, minValue = 1, maxValue = MAX, valueStep = 1,
          get = get("perRow", DEFAULT_PER_ROW), set = set("perRow") },
    }
end

--------------------------------------------------
-- 8. SETUP
--------------------------------------------------
-- only with FlareUI's player frame on: otherwise Blizzard's player frame keeps its own totems
function TOT:ShouldLoad()
    local db = GetDb()
    if not (db and db.enabled) then return false end
    local player = db.units and db.units.player
    return not (player and player.enabled == false)
end

function TOT:Init()
    if self.initialized or not _G.TotemFrame then return end
    self.initialized = true

    holder = CreateFrame("Frame", "FlareUI_Totems", UIParent)
    holder:SetFrameStrata("LOW")
    CreatePreview()
    ApplyPosition()
    LEM:AddFrame(holder, OnFrameMoved, DEFAULT_POSITION, "FlareUI Totems")
    LEM:AddFrameSettings(holder, BuildSettings())

    AdoptTotemFrame()
    ApplyLayout()

    LEM:RegisterCallback("layout", function(layoutName) ApplyPosition(layoutName) end)
    LEM:RegisterCallback("enter", function() SetPreview(true) end)
    LEM:RegisterCallback("exit", function() SetPreview(false) end)
end
