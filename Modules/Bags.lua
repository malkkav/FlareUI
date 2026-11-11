local _, ns = ...
local L = ns.L

--------------------------------------------------
-- BAGS
-- Quality of Life > Bags and Looting, on Blizzard's own bag windows:
--   * Columns and Gaps between bags: the combined backpack's grid, laid out again after Blizzard's
--     (hooksecurefunc on its UpdateFrameSize / UpdateItemLayout, so Blizzard's code runs untouched)
--   * Integrated bag buttons: the four bag slots down the combined backpack's side
--   * Item filters beside the search box that desaturate icons outside the selected category
--   * Thicker borders, Rarity colours, Junk coin and Upgrade arrow: drawn on an overlay of each item
-- The filter buttons take space beside search even with no category selected. Slots use FlareUI
-- Thin borders by default. When another bag addon owns the windows, this module leaves them alone.
--------------------------------------------------
ns.Bags = ns.Bags or {}
local Bags = ns.Bags
ns.modules["Bags"] = Bags

local ipairs, pairs, type = ipairs, pairs, type
local math_max, table_sort = math.max, table.sort

local ITEM_SPACING = 5              -- Blizzard's ITEM_SPACING_X / _Y (ContainerFrame.lua)
local BAG_GAP = 12                  -- Gaps between bags: the extra space above each bag's first row
local DEFAULT_COLUMNS = 10          -- Blizzard's combined backpack
local BAG_BUTTON_SIZE = 26
local BAG_BUTTON_GAP  = 0           -- vertical offset between bag buttons: the rims touch
local OTHER_BAG_ADDONS = { "LiteBag", "Bagnon", "Baganator", "ArkInventory", "AdiBags", "BetterBags",
                           "EnhanceQoLBags", "EllesmereUIBags", "Inventorian", "Combuctor", "cargBags_Nivaya" }

local overlays = {}                 -- item button -> its overlay
local bagButtons = {}
local itemFilter
local dimmedIcons = {}

local function GetDb()
    return ns.db and ns.db.profile and ns.db.profile.tweaks
end

-- the name of a loaded bag addon, or nil
function Bags:GetOtherBagAddon()
    if self.otherAddon == nil then
        self.otherAddon = false
        for _, name in ipairs(OTHER_BAG_ADDONS) do
            if C_AddOns.IsAddOnLoaded(name) then
                self.otherAddon = C_AddOns.GetAddOnMetadata(name, "Title") or name
                break
            end
        end
    end
    return self.otherAddon or nil
end

function Bags:IsCombined()
    return C_CVar.GetCVarBool("combinedBags") and true or false
end

local function Combined()
    return _G.ContainerFrameCombinedBags
end

local function GamepadUI()
    return InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled() or false
end

-- The Gamepad UI lays its own bag buttons into the grid (and merges the keyring and crafting bag
-- itself): FlareUI's layout stands aside there
local function LayoutWanted()
    local db = GetDb()
    if not db or Bags:GetOtherBagAddon() then return false end
    if GamepadUI() then return false end
    return (db.bagColumns or 0) > 0 or db.bagGaps == true or db.bagKeyring == true or db.bagReagent == true
end

--------------------------------------------------
-- 0. KEYRING AND CRAFTING BAG IN THE BACKPACK (Keyring in Backpack, Crafting Bag in Backpack; off)
-- Blizzard's combined backpack holds bags 0-4 only; the keyring (-1) and the crafting bag (5) open
-- as their own windows. Each gets a section at the bottom of the combined backpack instead: FlareUI's
-- own item buttons from Blizzard's template, under a plain parent whose ID is the bag, and each
-- button's ID is its slot. Blizzard's GetBagID reads the parent's ID, so clicking, dragging, splitting
-- and using items run Blizzard's own code untainted (the bag list globals are never touched).
-- Blizzard still opens its crafting bag window with the others (the bag key counts it): it is kept
-- open but moved off the screen, so the key opens and closes everything as before.
--------------------------------------------------
local extras = {}   -- bagID -> { holder = frame, buttons = { [slot] = button } }

local function KeyringID() return Enum.BagIndex and Enum.BagIndex.Keyring end
local function ReagentID() return Enum.BagIndex and Enum.BagIndex.ReagentBag end

local function KeyringWanted()
    local db, id = GetDb(), KeyringID()
    if not (db and db.bagKeyring and id) then return false end
    -- the game shows a keyring once you have had a key
    if C_ActionBar and C_ActionBar.ShouldShowKeyring and not C_ActionBar.ShouldShowKeyring() then return false end
    if not C_CVar.GetCVarBool("showKeyring") then return false end
    return C_Container.GetContainerNumSlots(id) > 0
end

local function ReagentWanted()
    local db, id = GetDb(), ReagentID()
    return db and db.bagReagent and id and C_Container.GetContainerNumSlots(id) > 0 or false
end

-- from the bottom up: the keyring, then the crafting bag, then Blizzard's bags
local function ExtraBags()
    local list = {}
    if KeyringWanted() then list[#list + 1] = KeyringID() end
    if ReagentWanted() then list[#list + 1] = ReagentID() end
    return list
end

-- how many slots a section shows: all of the crafting bag; the keyring up to its last key, in full
-- rows, with room for one more (as Blizzard's keyring window grows)
local function ShownSlots(bagID, columns)
    local total = C_Container.GetContainerNumSlots(bagID)
    if bagID ~= KeyringID() then return total end
    local last = 0
    for slot = 1, total do
        if C_Container.GetContainerItemInfo(bagID, slot) then last = slot end
    end
    return math.min(total, math.max(columns, math.ceil((last + 1) / columns) * columns))
end

local function Extra(bagID, frame)
    local e = extras[bagID]
    if e then return e end
    e = { buttons = {} }
    e.holder = CreateFrame("Frame", nil, frame)
    e.holder:SetAllPoints(frame)
    e.holder:SetID(bagID)
    extras[bagID] = e
    return e
end

local function ExtraButton(e, slot)
    local b = e.buttons[slot]
    if b or InCombatLockdown() then return b end
    b = CreateFrame("ItemButton", nil, e.holder, "ContainerFrameItemButtonTemplate")
    b:SetID(slot)
    Bags.AddSlotArt(b)
    e.buttons[slot] = b
    return b
end

-- the empty slot's art (Blizzard draws it behind its own buttons)
function Bags.AddSlotArt(b)
    b.flareSlot = b:CreateTexture(nil, "BACKGROUND", nil, -1)
    b.flareSlot:SetAtlas("bags-item-slot64")
    b.flareSlot:SetAllPoints()
end

-- a slot's place in the combined backpack: filled from the bottom right, right to left, upwards
function Bags.GridPoint(b, anchor, col, row, gapCount, stepX, stepY)
    b:ClearAllPoints()
    b:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", -col * stepX, 4 + row * stepY + gapCount * BAG_GAP)
end

local UpdateButton   -- section 3

-- Blizzard's item update (ContainerFrameMixin:UpdateItems), for one of FlareUI's buttons
local function FillExtraButton(b)
    local bagID, slot = b:GetBagID(), b:GetID()
    local info = C_Container.GetContainerItemInfo(bagID, slot)
    local texture = info and info.iconFileID
    pcall(function()
        ClearItemButtonOverlay(b)
        b:SetHasItem(texture)
        b:SetItemButtonTexture(texture)
        b:SyncAppearanceWithHasItem()
        SetItemButtonQuality(b, info and info.quality, info and info.hyperlink, false, info and info.isBound)
        SetItemButtonCount(b, info and info.stackCount)
        SetItemButtonDesaturated(b, info and info.isLocked)
        b:UpdateCooldown(texture)
        b:SetReadable(info and info.isReadable)
        b:SetMatchesSearch(not (info and info.isFiltered))
    end)
    local db = GetDb()
    if db and UpdateButton then UpdateButton(b, db) end
end

local function HideExtras(except)
    for bagID, e in pairs(extras) do
        if not (except and except[bagID]) then e.holder:Hide() end
    end
end

-- refills the shown sections (bag updates, cooldowns, locks, the search box)
local function FillExtras()
    for _, e in pairs(extras) do
        if e.holder:IsShown() then
            for _, b in pairs(e.buttons) do
                if b:IsShown() then FillExtraButton(b) end
            end
        end
    end
end

-- Blizzard's own crafting bag window, while its section is in the backpack: open but off the screen
local parked = {}
local function ParkReagentWindow()
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local frame = _G["ContainerFrame" .. i]
        if type(frame) == "table" and frame.GetID then
            local park = frame:IsShown() and frame:GetID() == ReagentID() and ReagentWanted()
                and Bags:IsCombined() and LayoutWanted()
            if park then
                if parked[frame] == nil then parked[frame] = frame:IsClampedToScreen() end
                frame:SetClampedToScreen(false)
                frame:ClearAllPoints()
                frame:SetPoint("TOPRIGHT", UIParent, "TOPLEFT", -2000, 0)
                frame:SetAlpha(0)
            elseif parked[frame] ~= nil then
                -- the frame holds another bag now (Blizzard places it again)
                frame:SetClampedToScreen(parked[frame])
                parked[frame] = nil
                frame:SetAlpha(1)
            end
        end
    end
end

--------------------------------------------------
-- 1. COMBINED BACKPACK LAYOUT
-- Blizzard's order (bags from the last to the backpack, slots from the last; filled from the bottom
-- right, right to left, upwards), with its own column count. Gaps between bags start each bag on a new
-- row with a gap above. The frame's size follows, from Blizzard's own paddings.
--------------------------------------------------
-- Blizzard's sort (ContainerFrame.lua SortItems / SortItemsByExtendedState)
local function SortItems(a, b)
    local bagA, bagB = a:GetBagID(), b:GetBagID()
    if bagA ~= bagB then return bagA > bagB end
    return a:GetID() > b:GetID()
end
local function SortItemsExtended(a, b)
    local extA, extB = a:IsExtended(), b:IsExtended()
    if extA ~= extB then return not extA end
    return SortItems(a, b)
end

local layingOut = false
local function Relayout(frame)
    if layingOut or not frame or frame ~= Combined() or not frame:IsShown() then return end
    if not (Bags:IsCombined() and LayoutWanted()) then HideExtras() return end
    local db = GetDb()
    local items = {}
    for _, button in frame:EnumerateValidItems() do items[#items + 1] = button end
    if #items == 0 then return end
    local secured = not IsAccountSecured or IsAccountSecured()
    table_sort(items, secured and SortItems or SortItemsExtended)

    local columns = (db.bagColumns or 0) > 0 and db.bagColumns or DEFAULT_COLUMNS
    local gaps = db.bagGaps == true
    local w, h = items[1]:GetSize()
    local stepX, stepY = w + ITEM_SPACING, h + ITEM_SPACING
    local anchor = frame.MoneyFrame
    if not anchor then return end

    layingOut = true
    local col, row, gapCount, prevBag = 0, 0, 0, nil
    -- the keyring and crafting bag sections first (the bottom rows), each with a gap above it
    local shownBags = {}
    for _, bagID in ipairs(ExtraBags()) do
        local e = Extra(bagID, frame)
        local shown = ShownSlots(bagID, columns)
        -- the same order as Blizzard's bags: the last slot bottom right
        for slot = shown, 1, -1 do
            local b = ExtraButton(e, slot)
            if b then
                b:SetSize(w, h)
                Bags.GridPoint(b, anchor, col, row, gapCount, stepX, stepY)
                b:Show()
                FillExtraButton(b)
                col = col + 1
                if col >= columns then col, row = 0, row + 1 end
            end
        end
        for slot, b in pairs(e.buttons) do if slot > shown then b:Hide() end end
        if col > 0 then col, row = 0, row + 1 end
        gapCount = gapCount + 1
        e.holder:Show()
        shownBags[bagID] = true
    end
    HideExtras(shownBags)
    for _, button in ipairs(items) do
        local bag = button:GetBagID()
        if gaps and prevBag and bag ~= prevBag then
            if col > 0 then col, row = 0, row + 1 end
            gapCount = gapCount + 1
        end
        Bags.GridPoint(button, anchor, col, row, gapCount, stepX, stepY)
        col = col + 1
        if col >= columns then col, row = 0, row + 1 end
        prevBag = bag
    end
    local rows = row + (col > 0 and 1 or 0)

    local width = columns * w + (columns - 1) * ITEM_SPACING + frame:GetPaddingWidth()
    local height = rows * h + (rows - 1) * ITEM_SPACING + gapCount * BAG_GAP
        + frame:GetPaddingHeight() + frame:CalculateExtraHeight()
    frame:SetSize(width, height)
    if NineSliceUtil and NineSliceUtil.UpdateCornerCropping then NineSliceUtil.UpdateCornerCropping(frame, height) end
    layingOut = false
    Bags:PlaceBagButtons()
end

--------------------------------------------------
-- 2. INTEGRATED BAG BUTTONS
-- Round bag slots down the combined backpack's left side (its right side near the screen's left
-- edge): drag bags in and out, hover to light that bag's items (Blizzard's BagSlot events).
--------------------------------------------------
local EMPTY_BAG = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"

local BagButton = {}

function BagButton:Update()
    self.slotID = C_Container.ContainerIDToInventoryID(self:GetID())
    local texture = self.slotID and GetInventoryItemTexture("player", self.slotID)
    SetItemButtonTexture(self, texture or select(2, GetInventorySlotInfo("Bag0Slot")) or EMPTY_BAG)
end

function BagButton:GetBagID() return self:GetID() end
function BagButton:GetIsBarExpanded() return true end

function BagButton:OnEnter()
    if not self.slotID then self:Update() end
    EventRegistry:TriggerEvent("BagSlot.OnEnter", self)
    -- the bag's own tooltip; an empty slot shows none (11-11: no "Equip Container")
    if GetInventoryItemTexture("player", self.slotID) then
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetInventoryItem("player", self.slotID)
        GameTooltip:Show()
    end
end

function BagButton:OnLeave()
    GameTooltip:Hide()
    ResetCursor()
    EventRegistry:TriggerEvent("BagSlot.OnLeave", self)
end

function BagButton:OnClick()
    if not self.slotID then self:Update() end
    if CursorHasItem() then PutItemInBag(self.slotID) else PickupBagFromSlot(self.slotID) end
end

function BagButton:OnDragStart()
    if not self.slotID then self:Update() end
    PickupBagFromSlot(self.slotID)
end

-- the radial menu's round look (RadialMenu.lua RoundStyle): its rim atlas over a masked icon, or a
-- drawn bronze ring when the client lacks the atlases
function Bags.RoundBagButton(b)
    local rm = ns.RadialMenu
    local style = rm and rm.RoundStyle and rm.RoundStyle()
    local size = BAG_BUTTON_SIZE
    if b.ClearNormalTexture then b:ClearNormalTexture() end
    if b.ClearPushedTexture then b:ClearPushedTexture() end
    local icon = b.icon or b.Icon
    if not icon then return end
    if b.CircleMask then icon:RemoveMaskTexture(b.CircleMask) end
    local iconSize = style and size * style.iconFactor or size * (1 - 2 * (rm and rm.ROUND_BORDER_FRACTION or 0.06))
    icon:ClearAllPoints()
    icon:SetPoint("CENTER")
    icon:SetSize(iconSize, iconSize)
    local mask = b:CreateMaskTexture()
    mask:SetAtlas(style and style.mask or "CircleMaskScalable")
    mask:SetAllPoints(icon)
    icon:AddMaskTexture(mask)
    local rim
    if style then
        rim = b:CreateTexture(nil, "OVERLAY", nil, 1)
        rim:SetAtlas(style.idle)
        local t = style.idleTint
        if t then rim:SetVertexColor(t[1], t[2], t[3]) end
    else
        rim = b:CreateTexture(nil, "BACKGROUND")
        rim:SetColorTexture(1, 1, 1)
        local c = rm and rm.ROUND_BORDER_COLOR or { 0.45, 0.33, 0.19 }
        rim:SetVertexColor(c[1], c[2], c[3])
        local rimMask = b:CreateMaskTexture()
        rimMask:SetAtlas("CircleMaskScalable")
        rimMask:SetAllPoints(rim)
        rim:AddMaskTexture(rimMask)
    end
    rim:SetSize(size, size)
    rim:SetPoint("CENTER")
end

-- the bags the buttons hold: the four bag slots, and the crafting bag's where the client has one
function Bags.BagButtonIDs()
    local ids = {}
    for i = 1, (NUM_BAG_FRAMES or 4) do ids[#ids + 1] = i end
    local reagents = Constants.InventoryConstants and Constants.InventoryConstants.NumReagentBagSlots or 0
    if reagents > 0 and Enum.BagIndex.ReagentBag then ids[#ids + 1] = Enum.BagIndex.ReagentBag end
    return ids
end

local function CreateBagButtons(frame)
    if bagButtons[1] then return end
    local ids = Bags.BagButtonIDs()
    for i, bagID in ipairs(ids) do
        local b = CreateFrame("ItemButton", "FlareUI_BagButton" .. i, frame, "CircularItemButtonTemplate")
        Mixin(b, BagButton)
        b:SetID(bagID)
        b:SetSize(BAG_BUTTON_SIZE, BAG_BUTTON_SIZE)
        Bags.RoundBagButton(b)
        b:SetHighlightAtlas("bag-border-highlight")
        b:RegisterForDrag("LeftButton")
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnEnter", b.OnEnter)
        b:SetScript("OnLeave", b.OnLeave)
        b:SetScript("OnClick", b.OnClick)
        b:SetScript("OnReceiveDrag", b.OnClick)
        b:SetScript("OnDragStart", b.OnDragStart)
        if frame.TitleContainer then b:SetFrameLevel(frame.TitleContainer:GetFrameLevel() + 1) end
        b:Hide()
        bagButtons[i] = b
    end
    local events = CreateFrame("Frame")
    events:RegisterEvent("BAG_UPDATE_DELAYED")
    events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    events:SetScript("OnEvent", function()
        for _, b in ipairs(bagButtons) do if b:IsShown() then b:Update() end end
    end)
end

function Bags:PlaceBagButtons()
    local frame = Combined()
    if not frame then return end
    local db = GetDb()
    local show = db and db.bagButtons and Bags:IsCombined() and not Bags:GetOtherBagAddon()
        and not (InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled())
    if not show then
        for _, b in ipairs(bagButtons) do b:Hide() end
        return
    end
    CreateBagButtons(frame)
    -- outside the left edge, or the right one when the bags sit at the screen's left
    local left = frame:GetLeft()
    local point, relative, x = "TOPRIGHT", "TOPLEFT", 0
    if left and left < BAG_BUTTON_SIZE + 8 then point, relative, x = "TOPLEFT", "TOPRIGHT", 0 end
    -- the first one starts where the bag portrait ends
    local y = -34
    local portrait = frame.PortraitButton or frame.PortraitContainer
    local bottom, top = portrait and portrait:GetBottom(), frame:GetTop()
    if bottom and top then y = bottom * portrait:GetEffectiveScale() / frame:GetEffectiveScale() - top end
    for i, b in ipairs(bagButtons) do
        b:ClearAllPoints()
        if i == 1 then
            b:SetPoint(point, frame, relative, x, y)
        else
            b:SetPoint("TOP", bagButtons[i - 1], "BOTTOM", 0, BAG_BUTTON_GAP)
        end
        b:Update()
        b:Show()
    end
end

--------------------------------------------------
-- 3. ITEM OVERLAYS
-- Slot borders, always on: FlareUI Thin round each slot in place of Blizzard's glow; Thicker
-- borders swaps it for FlareUI Thick. Bronze, or with Rarity colours the item's exact quality colour
-- (grey to orange; empty slots and items dimmed by a filter stay bronze).
-- Junk coin: grey items worth money show Blizzard's coin always, not only at a vendor.
-- Upgrade arrow: gear that beats what you wear shows Blizzard's green arrow in the bottom right.
--------------------------------------------------
-- edge size and outset per border: each art's bright band lands on the slot's edge
local BORDERS = { thin = { "FlareUI Thin", 8, 3 }, thick = { "FlareUI Thick", 16, 2 } }

local function UpdateFilteredQuestBorder(button, ov, bagID, slotID, dimmed)
    local mark = button.IconQuestTexture
    if not mark then return end
    local quest = dimmed and mark:IsShown() and C_Container.GetContainerItemQuestInfo(bagID, slotID)
    local isBorder = quest and (quest.questID or quest.isQuestItem) and not (quest.questID and not quest.isActive)
    if isBorder then
        if ov.questBorderAlpha == nil then ov.questBorderAlpha = mark:GetAlpha() end
        mark:SetAlpha(0)
    elseif ov.questBorderAlpha ~= nil then
        mark:SetAlpha(ov.questBorderAlpha)
        ov.questBorderAlpha = nil
    end
end

local function UpdateItemFilter(button, ov, bagID, slotID, info)
    local dimmed
    if itemFilter and info and not GamepadUI() then
        if itemFilter == "quest" then
            local quest = C_Container.GetContainerItemQuestInfo(bagID, slotID)
            dimmed = quest and not (quest.isQuestItem or quest.questID)
        elseif info.itemID and itemFilter == "equipment" then
            local slotType = C_Item.GetItemInventoryTypeByID(info.itemID)
            local types = Enum.InventoryType
            dimmed = slotType == types.IndexNonEquipType or slotType == types.IndexBagType
                or slotType == types.IndexQuiverType or slotType == types.IndexAmmoType
        elseif info.itemID then
            local classID, subclassID = select(6, C_Item.GetItemInfoInstant(info.itemID))
            if classID ~= nil then
                local classes = Enum.ItemClass
                if itemFilter == "resources" then
                    dimmed = classID ~= classes.Tradegoods
                        and not (classID == classes.Reagent and subclassID == Enum.ItemReagentSubclass.Reagent)
                elseif itemFilter == "consumables" then
                    dimmed = classID ~= classes.Consumable
                end
            end
        end
    end
    if not (dimmed or dimmedIcons[button]) then return end
    dimmedIcons[button] = dimmed or nil
    local icon = button:GetItemButtonIconTexture()
    icon:SetDesaturated(dimmed or (info and info.isLocked) or false)

    if dimmed and not ov.filterShade then
        -- Above the icon on BORDER, below stack counts and other item indicators.
        local shade = button:CreateTexture(nil, "BORDER", nil, 1)
        shade:SetAllPoints(icon)
        shade:SetColorTexture(0, 0, 0, 0.52)
        if button.Mask then shade:AddMaskTexture(button.Mask) end
        ov.filterShade = shade
    end
    if ov.filterShade then ov.filterShade:SetShown(dimmed == true) end
    UpdateFilteredQuestBorder(button, ov, bagID, slotID, dimmed)
end

local function GetOverlay(button)
    -- a settings preview's button keeps its own (it never joins the overlays list)
    local ov = overlays[button] or button.fuiOverlay
    if ov then return ov end
    ov = CreateFrame("Frame", nil, button)
    ov:SetAllPoints()
    ov:SetFrameLevel(button:GetFrameLevel() + 2)
    ov.border = CreateFrame("Frame", nil, ov, "BackdropTemplate")
    ov.border:Hide()
    ov.junk = ov:CreateTexture(nil, "OVERLAY", nil, 7)
    ov.junk:SetAtlas("bags-junkcoin", true)
    ov.junk:SetPoint("TOPLEFT", 1, 0)
    ov.junk:Hide()
    ov.upgrade = ov:CreateTexture(nil, "OVERLAY", nil, 7)
    ov.upgrade:SetAtlas("bags-greenarrow", true)
    ov.upgrade:SetPoint("BOTTOMRIGHT", -1, 1)
    ov.upgrade:Hide()
    if button.fuiSample then button.fuiOverlay = ov else overlays[button] = ov end
    return ov
end

local function ShowBorder(ov, style, r, g, b)
    local border = ov.border
    if border.style ~= style then
        local def = BORDERS[style]
        border.style = style
        border:ClearAllPoints()
        border:SetPoint("TOPLEFT", -def[3], def[3])
        border:SetPoint("BOTTOMRIGHT", def[3], -def[3])
        border:SetBackdrop({ edgeFile = LibStub("LibSharedMedia-3.0"):Fetch("border", def[1]), edgeSize = def[2] })
    end
    border:SetBackdropBorderColor(r, g, b, 1)
    ov.border:Show()
end

local function UpdateItemBorder(ov, db, quality, dimmed)
    local style = db.bagThickBorders and "thick" or "thin"
    if db.bagRarityBorders and quality and not dimmed then
        local r, g, b = C_Item.GetItemQualityColor(quality)
        ShowBorder(ov, style, r, g, b)
    else
        local c = ns.BORDER_COLOR
        ShowBorder(ov, style, c.r, c.g, c.b)
    end
end

local function RefreshItemFilter()
    local db = GetDb()
    for button, ov in pairs(overlays) do
        local wasDimmed = dimmedIcons[button]
        if (itemFilter and button:IsVisible()) or wasDimmed then
            local bagID, slotID = button:GetBagID(), button:GetID()
            local info = bagID and slotID and C_Container.GetContainerItemInfo(bagID, slotID)
            UpdateItemFilter(button, ov, bagID, slotID, info)
            local dimmed = dimmedIcons[button]
            if db and db.bagRarityBorders and wasDimmed ~= dimmed then
                UpdateItemBorder(ov, db, info and info.quality, dimmed)
            end
        end
    end
end

-- Upgrade arrow: Forever has no "is an upgrade" check (Blizzard's flyout asks for one that is never
-- filled), so FlareUI scores items itself with light stat weights: your main stat counts 1, Stamina 0.5,
-- secondary ratings 0.4, armour a tie-breaker. Only gear the tooltip doesn't mark red (wrong armour
-- type, level, class) counts, and it is compared with what you wear there (the weaker of two rings,
-- trinkets or dual-wielded weapons; both hands against a two-hander).
-- 11-10 (a level 15 warrior saw the arrow on grey cloth bracers over green mail ones), after EnhanceQoL's
-- Forever rules (the idea only): a worn item whose stats can't be read blocks the arrow instead of
-- scoring 0; the game's own C_PlayerInfo.CanUseItem decides what can be worn (the red tooltip as a
-- fallback); and armour (cloth to plate, shields, cloaks) is only an upgrade when it loses no stat,
-- its armour included, against the piece it replaces.
local Upgrade = { score = {}, usable = {}, stats = {} }
Bags.Upgrade = Upgrade

local STAT_KEY = { [1] = "ITEM_MOD_STRENGTH_SHORT", [2] = "ITEM_MOD_AGILITY_SHORT", [4] = "ITEM_MOD_INTELLECT_SHORT" }
-- the main stats a class can use; hybrids take the one the character has most of
local CLASS_STATS = {
    WARRIOR = { 1 }, PALADIN = { 1, 4 }, DEATHKNIGHT = { 1 }, HUNTER = { 2 }, ROGUE = { 2 }, DEMONHUNTER = { 2 },
    SHAMAN = { 2, 4 }, DRUID = { 2, 4 }, MONK = { 2, 4 }, PRIEST = { 4 }, MAGE = { 4 }, WARLOCK = { 4 }, EVOKER = { 4 },
}
local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
    -- Forever keeps the ranged slot (18) apart from the hands
    INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}
-- off-hand items that are not weapons: a one-hander is never weighed against them
local OFF_HAND_GEAR = { INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true }

-- the item without its enchant or gems: what it is, not what was added to it (random suffixes stay)
local function BaseLink(link)
    return (link:gsub("(|Hitem:%d+):[^:|]*:[^:|]*:[^:|]*:[^:|]*:[^:|]*", "%1:::::"))
end

function Upgrade:MainStat()
    if self.mainStat then return self.mainStat end
    local spec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization and C_SpecializationInfo.GetSpecialization()
    if spec and spec > 0 then
        local primary = select(6, C_SpecializationInfo.GetSpecializationInfo(spec))
        if STAT_KEY[primary] then self.mainStat = primary return primary end
    end
    local best, bestValue = 4, -1
    for _, stat in ipairs(CLASS_STATS[select(2, UnitClass("player"))] or { 1, 2, 4 }) do
        local value = UnitStat("player", stat) or 0
        if value > bestValue then best, bestValue = stat, value end
    end
    self.mainStat = best
    return best
end

function Upgrade:Score(link)
    if not link then return nil end
    local original = link
    link = BaseLink(link)
    local cached = self.score[link]
    if cached then return cached end
    -- an uncached item has no stats yet: asked for, and scored on a later pass
    local itemID = C_Item.GetItemInfoInstant(link)
    if itemID and not C_Item.IsItemDataCachedByID(itemID) then C_Item.RequestLoadItemDataByID(itemID) return nil end
    -- the full link (a random suffix's stats come with it); none read yet is "unknown", not 0
    local stats = C_Item.GetItemStats(original)
    if not stats or next(stats) == nil then return nil end
    self.stats[link] = stats
    local main = self:MainStat()
    local physical = main ~= 4
    local score, damage, healing = 0, 0, 0
    for key, value in pairs(stats) do
        if type(value) == "number" then
            local w = 0
            if key == STAT_KEY[main] then w = 1
            elseif key == "ITEM_MOD_STAMINA_SHORT" then w = 0.5
            elseif key == "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" then w = physical and 2 or 0
            elseif key == "ITEM_MOD_ATTACK_POWER_SHORT" then w = physical and 0.5 or 0
            elseif key == "ITEM_MOD_SPELL_POWER_SHORT" then w = physical and 0 or 1
            elseif key == "RESISTANCE0_NAME" then w = 0.001
            elseif key:find("RATING", 1, true) or key:find("VERSATILITY", 1, true) then w = 0.4
            elseif not physical then
                -- caster gear: healing and spell damage (one school counts half), mana per 5 and Spirit
                if key:find("HEALING_DONE", 1, true) then healing = healing + value
                elseif key == "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT" then damage = damage + value
                elseif key:find("_DAMAGE_DONE", 1, true) then damage = damage + value * 0.5
                elseif key:find("POWER_REGEN0", 1, true) then w = 2
                elseif key == "ITEM_MOD_SPIRIT_SHORT" then w = 0.3
                end
            end
            score = score + value * w
        end
    end
    -- a healer and a damage caster each want one of the two: the bigger one counts
    score = score + math_max(damage, healing)
    self.score[link] = score
    return score
end

local function IsRed(color)
    return color and color.r and color.r > 0.95 and color.g < 0.2 and color.b < 0.2
end

-- the tooltip marks what this character can't wear in red
function Upgrade:CanWear(bagID, slotID, link)
    local known = self.usable[link]
    if known ~= nil then return known end
    -- the game's answer first: proficiency, level and class
    local itemID = C_Item.GetItemInfoInstant(link)
    if itemID and C_PlayerInfo and C_PlayerInfo.CanUseItem then
        local ok, can = pcall(C_PlayerInfo.CanUseItem, itemID)
        if ok and can == false then
            self.usable[link] = false
            return false
        end
    end
    local ok, data = pcall(C_TooltipInfo.GetBagItem, bagID, slotID)
    if not ok or not data or not data.lines then return nil end
    local wear = true
    for _, line in ipairs(data.lines) do
        if IsRed(line.leftColor) or IsRed(line.rightColor) then wear = false break end
    end
    self.usable[link] = wear
    return wear
end

local function EquippedScore(slot)
    local link = GetInventoryItemLink("player", slot)
    if not link then return 0, true end
    -- not loaded yet, or its stats unreadable: no arrow (it would count as an empty slot)
    return Upgrade:Score(link) or math.huge, false
end

-- armour: cloth, leather, mail, plate, shields (cloaks are cloth)
local ARMOUR = { [1] = true, [2] = true, [3] = true, [4] = true, [6] = true }
-- no stat lower than on the worn piece, its armour included (an upgrade, not a trade-off)
function Upgrade:LosesNothing(link, slot)
    local worn = GetInventoryItemLink("player", slot)
    if not worn then return true end
    local mine, theirs = self.stats[BaseLink(link)], self.stats[BaseLink(worn)]
    if not (mine and theirs) then return false end
    for stat, value in pairs(theirs) do
        if type(value) == "number" and value > (mine[stat] or 0) then return false end
    end
    return true
end

-- true when the bag item beats what is worn in its slot
function Upgrade:Is(bagID, slotID, link)
    local equipLoc = select(4, C_Item.GetItemInfoInstant(link))
    local slots = SLOTS[equipLoc]
    if not slots then return false end
    if not self:CanWear(bagID, slotID, link) then return false end
    local score = self:Score(link)
    if not score then return false end
    if equipLoc == "INVTYPE_2HWEAPON" then
        local main, mainEmpty = EquippedScore(16)
        local off = EquippedScore(17)
        return mainEmpty or score > main + off
    end
    if equipLoc == "INVTYPE_WEAPON" then
        -- a one-hander only weighs against the off hand when a weapon is held there (never a shield)
        local offLink = GetInventoryItemLink("player", 17)
        local offGear = offLink and OFF_HAND_GEAR[select(4, C_Item.GetItemInfoInstant(offLink))]
        if offGear or not (CanDualWield and CanDualWield()) then slots = { 16 } end
    end
    -- with a two-hander on, the off hand is not free
    local mainLink = GetInventoryItemLink("player", 16)
    local twoHanded = mainLink and select(4, C_Item.GetItemInfoInstant(mainLink)) == "INVTYPE_2HWEAPON"
    if twoHanded and slots[1] ~= 18 then
        if slots[1] == 17 then return false end
        slots = { 16 }
    end
    local worst, empty, worstSlot
    for _, slot in ipairs(slots) do
        local s, isEmpty = EquippedScore(slot)
        if isEmpty then empty = true end
        if not worst or s < worst then worst, worstSlot = s, slot end
    end
    if empty then return true end
    if not (score > worst) then return false end
    local classID, subclassID = select(6, C_Item.GetItemInfoInstant(link))
    if classID == 4 and ARMOUR[subclassID] and worstSlot and not self:LosesNothing(link, worstSlot) then return false end
    return true
end

-- talents, level and new gear change the answers
function Upgrade:Reset(full)
    self.mainStat = nil
    if full then wipe(self.usable) end
    wipe(self.score)
    wipe(self.stats)
end

local function ShowUpgrade(ov, bagID, slotID, link)
    if Upgrade:Is(bagID, slotID, link) then ov.upgrade:Show() end
end

function UpdateButton(button, db)
    local bagID, slotID = button:GetBagID(), button:GetID()
    local info = bagID and slotID and C_Container.GetContainerItemInfo(bagID, slotID)
    Bags.DecorateButton(button, db, info, bagID, slotID)
end

-- info: the slot's item (C_Container's, or a settings preview's made-up one, whose sampleUpgrade
-- stands for the upgrade check)
function Bags.DecorateButton(button, db, info, bagID, slotID)
    local junk, upgrade = db.bagJunkIcon, db.bagUpgradeArrow
    local ov = GetOverlay(button)
    ov:Show()
    ov.border:Hide()
    ov.junk:Hide()
    ov.upgrade:Hide()

    if not button.fuiSample then UpdateItemFilter(button, ov, bagID, slotID, info) end
    local quality = info and info.quality

    if button.IconBorder then button.IconBorder:SetAlpha(0) end
    UpdateItemBorder(ov, db, quality, dimmedIcons[button])

    if not info then return end
    if junk and quality == Enum.ItemQuality.Poor and not info.hasNoValue then ov.junk:Show() end
    if upgrade and info.sampleUpgrade then
        ov.upgrade:Show()
    elseif upgrade and info.hyperlink then
        local link = info.hyperlink
        if C_Item.IsItemDataCachedByID(info.itemID) then
            ShowUpgrade(ov, bagID, slotID, link)
        else
            -- the slot may hold something else by the time the data comes
            local item = Item:CreateFromItemLink(link)
            item:ContinueOnItemLoad(function()
                local now = C_Container.GetContainerItemInfo(bagID, slotID)
                if now and now.hyperlink == link and button:GetBagID() == bagID and button:GetID() == slotID then
                    ShowUpgrade(ov, bagID, slotID, link)
                end
            end)
        end
    end
end

local function UpdateFrameItems(frame)
    local db = GetDb()
    if not db or Bags:GetOtherBagAddon() or not frame.EnumerateValidItems then return end
    for _, button in frame:EnumerateValidItems() do UpdateButton(button, db) end
end

--------------------------------------------------
-- 4. HOOKS AND PUBLIC
--------------------------------------------------
local function BagFrames()
    local list = {}
    local combined = Combined()
    if combined then list[#list + 1] = combined end
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local frame = _G["ContainerFrame" .. i]
        if type(frame) == "table" and frame.EnumerateValidItems then list[#list + 1] = frame end
    end
    return list
end

local FILTER_BUTTON_GAP, FILTER_SEARCH_GAP = 2, 4
local FILTER_RIM_X_TRIM, FILTER_RIM_Y_TRIM = 0.10, 0.14
local FILTER_RIM_UP, FILTER_RIM_DOWN = "bags-button-autosort-up", "bags-button-autosort-down"
local FILTER_ICON_MASK_DIR = "Interface\\AddOns\\FlareUI\\Media\\Masks\\"
local FILTER_ICON_MASKS = {
    equipment = "BagFilterEquipment.tga",
    resources = "BagFilterResources.tga",
    consumables = "BagFilterConsumables.tga",
}
local filterButtons = {}
local overflowButton, splitFilterButton, normalSearchWidth
local filterLabels = {
    quest = L["Quest Items"],
    equipment = BAG_FILTER_EQUIPMENT or "Equipment",
    resources = BAG_FILTER_REAGENTS or "Resources",
    consumables = BAG_FILTER_CONSUMABLES or "Consumables",
}
local overflowFilterModes = { "resources", "consumables" }
local splitFilterModes = { "quest", "equipment", "resources", "consumables" }

local function SupportsBagFilters()
    return C_Container.GetContainerItemQuestInfo and C_Item.GetItemInventoryTypeByID
        and Enum.InventoryType and not Bags:GetOtherBagAddon()
end

local function BagFiltersEnabled()
    local db = GetDb()
    return not (db and db.bagCategoryFilters == false)
end

local function GetActiveMenuFilterLabel(button)
    for _, mode in ipairs(button.filterMenuModes) do
        if itemFilter == mode then return filterLabels[mode] end
    end
end

local function ShowFilterTooltip(button)
    local mode = button.filterMode
    local enabled = " (" .. (VIDEO_OPTIONS_ENABLED or "Enabled") .. ")"
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    if mode and mode == itemFilter then
        GameTooltip:SetText(button.filterTooltip .. enabled)
        local click = GetBindingText and GetBindingText("BUTTON1") or "Left Click"
        GameTooltip:AddLine(click .. " — " .. L["Reset"], 1, 1, 1)
    else
        GameTooltip:SetText(button.filterTooltip)
        local activeLabel = not mode and GetActiveMenuFilterLabel(button)
        if activeLabel then GameTooltip:AddLine(activeLabel .. enabled, 1, 1, 1) end
    end
    GameTooltip:Show()
end

local function SetCompactFilterRim(texture, atlas)
    local width = atlas.rightTexCoord - atlas.leftTexCoord
    local height = atlas.bottomTexCoord - atlas.topTexCoord
    texture:SetTexture(atlas.file or atlas.filename)
    -- Trim the clear margins in the sort artwork before covering its broom.
    texture:SetTexCoord(atlas.leftTexCoord + width * FILTER_RIM_X_TRIM, atlas.rightTexCoord - width * FILTER_RIM_X_TRIM,
        atlas.topTexCoord + height * FILTER_RIM_Y_TRIM, atlas.bottomTexCoord - height * FILTER_RIM_Y_TRIM)
end

local function SetFilterButtonActive(button, active)
    button:SetChecked(active)
    button.activeGlow:SetShown(active)
    if button.rimUp then
        SetCompactFilterRim(button.rim, active and button.rimDown or button.rimUp)
    elseif button.rim then
        button.rim:SetAtlas(active and FILTER_RIM_DOWN or FILTER_RIM_UP, false)
    else
        local color = active and NORMAL_FONT_COLOR or ns.BORDER_COLOR
        button:SetBackdropBorderColor(color.r, color.g, color.b, 1)
    end
    button.icon:SetAlpha(active and 1 or button.iconIdleAlpha)
    if GameTooltip:IsShown() and GameTooltip:IsOwned(button) then ShowFilterTooltip(button) end
end

local function UpdateMenuFilterButton(button)
    SetFilterButtonActive(button, GetActiveMenuFilterLabel(button) ~= nil)
end

local function SetItemFilter(mode)
    if itemFilter == mode then return end
    itemFilter = mode
    for filter, button in pairs(filterButtons) do SetFilterButtonActive(button, filter == itemFilter) end
    if overflowButton then UpdateMenuFilterButton(overflowButton) end
    if splitFilterButton then UpdateMenuFilterButton(splitFilterButton) end
    RefreshItemFilter()
end

local function ToggleItemFilter(mode)
    if BagFiltersEnabled() then SetItemFilter(itemFilter ~= mode and mode or nil) end
end

local function CreateFilterButton(frame, filter, tooltip, atlasName, textureFile, compact)
    local button = CreateFrame("CheckButton", nil, frame, "BackdropTemplate")
    local rimUp, rimDown = C_Texture.GetAtlasInfo(FILTER_RIM_UP), C_Texture.GetAtlasInfo(FILTER_RIM_DOWN)
    local rimFile = rimUp and (rimUp.file or rimUp.filename)
    if rimUp and rimDown and (not compact or (rimFile and (rimDown.file or rimDown.filename))) then
        button.rim = button:CreateTexture(nil, "BACKGROUND")
        if not compact then
            button.rim:SetAtlas(FILTER_RIM_UP, false)
            button.rim:SetPoint("CENTER")
        else
            button.rimUp, button.rimDown = rimUp, rimDown
            SetCompactFilterRim(button.rim, rimUp)
            button.rim:SetAllPoints()
        end
        -- The sort button's frame and broom share one atlas. Cover the center before drawing our icon.
        local center = button:CreateTexture(nil, "ARTWORK", nil, -1)
        if not compact and rimFile then
            -- Use the clean patch of background above and to the left of the broom.
            local width = rimUp.rightTexCoord - rimUp.leftTexCoord
            local height = rimUp.bottomTexCoord - rimUp.topTexCoord
            center:SetTexture(rimFile)
            center:SetTexCoord(rimUp.leftTexCoord + width * 0.25, rimUp.leftTexCoord + width * 0.34,
                rimUp.topTexCoord + height * 0.30, rimUp.topTexCoord + height * 0.41)
        else
            center:SetColorTexture(0.09, 0.065, 0.04, 1)
        end
        center:SetPoint("TOPLEFT", 3, -3)
        center:SetPoint("BOTTOMRIGHT", -3, 3)
    else
        button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        button:SetBackdropColor(0.09, 0.065, 0.04, 1)
        button:SetBackdropBorderColor(ns.BORDER_COLOR.r, ns.BORDER_COLOR.g, ns.BORDER_COLOR.b, 1)
    end
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local glow = button:CreateTexture(nil, "OVERLAY")
    glow:SetAtlas("UI-HUD-ActionBar-IconFrame-Mouseover", false)
    glow:SetAllPoints(button.rim or button)
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(1, 0.82, 0.42, 0.85)
    glow:Hide()
    button.activeGlow = glow
    local icon = button:CreateTexture(nil, "ARTWORK")
    if atlasName then
        local atlas = C_Texture.GetAtlasInfo(atlasName)
        if atlas then icon:SetAtlas(atlasName) else icon:SetTexture(textureFile) end
        local aspect = atlas and atlas.width > 0 and atlas.height > 0 and atlas.width / atlas.height or 1
        icon:SetSize(math.min(16, 16 * aspect), math.min(16, 16 / aspect))
    else
        local size, crop = 14, 0.07
        icon:SetTexture(textureFile)
        icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
        icon:SetSize(size, size)
        local maskFile = FILTER_ICON_MASKS[filter]
        if maskFile then
            local mask = button:CreateMaskTexture()
            mask:SetTexture(FILTER_ICON_MASK_DIR .. maskFile, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            -- The mask covers the full source texture. The icon samples only its cropped center.
            local maskSize = size / (1 - 2 * crop)
            mask:SetSize(maskSize, maskSize)
            mask:SetPoint("CENTER", icon, "CENTER")
            icon:AddMaskTexture(mask)
        end
    end
    icon:SetPoint("CENTER")
    button.iconIdleAlpha = atlasName and 0.7 or 1
    icon:SetAlpha(button.iconIdleAlpha)
    button.icon = icon
    button.filterMode = filter
    button.filterTooltip = tooltip
    button:SetScript("OnEnter", ShowFilterTooltip)
    button:SetScript("OnLeave", GameTooltip_Hide)
    if filter then button:SetScript("OnClick", function() ToggleItemFilter(filter) end) end
    return button
end

local function OpenFilterMenu(button)
    UpdateMenuFilterButton(button)
    MenuUtil.CreateContextMenu(button, function(_, root)
        local function IsActive(mode) return itemFilter == mode end
        for _, mode in ipairs(button.filterMenuModes) do
            root:CreateCheckbox(filterLabels[mode], IsActive, ToggleItemFilter, mode)
        end
    end)
end

local function CreateFilterMenuButton(frame, modes, compact)
    local atlas = "bags-icon-multiple"
    if not compact and C_Texture.GetAtlasInfo("Map-Filter-Button") then atlas = "Map-Filter-Button" end
    local button = CreateFilterButton(frame, nil, FILTERS or FILTER or "Filters", atlas,
        "Interface\\Buttons\\UI-ScrollDownButton-Up", compact)
    button.filterMenuModes = modes
    button:SetScript("OnClick", OpenFilterMenu)
    return button
end

local function HideCombinedFilterButtons()
    for _, button in pairs(filterButtons) do button:Hide() end
    if overflowButton then overflowButton:Hide() end
end

local function HideFilterButtons()
    HideCombinedFilterButtons()
    if splitFilterButton then splitFilterButton:Hide() end
end

local function SizeFilterButton(button, width, height, sortWidth, sortHeight, sortHighlight)
    button:SetSize(width, height)
    if button.rim then button.rim:SetSize(sortWidth, sortHeight) end
    if sortHighlight then
        local highlight = button:GetHighlightTexture()
        highlight:ClearAllPoints()
        highlight:SetPoint("CENTER")
        highlight:SetSize(sortHighlight:GetSize())
    end
end

local function PlaceFilterButtons(frame, searchUpdated)
    local search, sort = _G.BagItemSearchBox, _G.BagItemAutoSortButton
    if not (frame and search and sort and search:GetParent() == frame and sort:GetParent() == frame) then return end
    if GamepadUI() or not (search:IsShown() and sort:IsShown()) then
        HideFilterButtons()
        return
    end
    local searchPoint, searchParent, _, searchX = search:GetPoint(1)
    local sortPoint, sortParent, _, sortX = sort:GetPoint(1)
    if searchPoint ~= "TOPLEFT" or sortPoint ~= "TOPRIGHT" or searchParent ~= frame or sortParent ~= frame then return end
    if searchUpdated or not normalSearchWidth then normalSearchWidth = search:GetWidth() end
    if not BagFiltersEnabled() then
        HideFilterButtons()
        search:SetWidth(normalSearchWidth)
        return
    end
    local sortWidth, sortHeight = sort:GetSize()
    local sortHighlight = sort:GetHighlightTexture()
    -- Match the visible sort rim and keep the background patch inside it.
    local buttonWidth = sortWidth * (1 - 2 * FILTER_RIM_X_TRIM)
    local buttonHeight = sortHeight * (1 - 2 * FILTER_RIM_Y_TRIM)
    local sortLeft = frame:GetWidth() + sortX - sortWidth
    if frame:IsBackpack() then
        HideCombinedFilterButtons()
        local available = sortLeft - buttonWidth - FILTER_SEARCH_GAP - searchX
        if available <= 0 then
            if splitFilterButton then splitFilterButton:Hide() end
            return
        end
        if not splitFilterButton then
            splitFilterButton = CreateFilterMenuButton(frame, splitFilterModes)
            local iconWidth, iconHeight = splitFilterButton.icon:GetSize()
            splitFilterButton.icon:SetSize(iconWidth * 0.75, iconHeight * 0.75)
            splitFilterButton:SetPoint("RIGHT", sort, "LEFT", 0, 0)
        end
        SizeFilterButton(splitFilterButton, buttonWidth, buttonHeight, sortWidth, sortHeight, sortHighlight)
        UpdateMenuFilterButton(splitFilterButton)
        splitFilterButton:Show()
        search:SetWidth(math.min(normalSearchWidth, available))
        return
    end
    if splitFilterButton then splitFilterButton:Hide() end
    local available = sortLeft - buttonWidth - FILTER_SEARCH_GAP - searchX
    if available <= 0 then
        HideCombinedFilterButtons()
        return
    end
    if not filterButtons.quest then
        filterButtons.quest = CreateFilterButton(frame, "quest", filterLabels.quest, "QuestNormal",
            "Interface\\GossipFrame\\AvailableQuestIcon")
        filterButtons.quest:SetPoint("RIGHT", sort, "LEFT", 0, 0)
        filterButtons.equipment = CreateFilterButton(frame, "equipment", filterLabels.equipment,
            nil, "Interface\\Icons\\INV_Chest_Chain_05")
        filterButtons.resources = CreateFilterButton(frame, "resources", filterLabels.resources,
            nil, "Interface\\Icons\\INV_Ingot_02")
        filterButtons.consumables = CreateFilterButton(frame, "consumables", filterLabels.consumables,
            nil, "Interface\\Icons\\INV_Potion_49")
        if itemFilter then SetFilterButtonActive(filterButtons[itemFilter], true) end
    end
    for _, button in pairs(filterButtons) do
        if button:GetParent() ~= frame then button:SetParent(frame) end
        SizeFilterButton(button, buttonWidth, buttonHeight, sortWidth, sortHeight, sortHighlight)
    end
    filterButtons.quest:Show()
    local equipment = filterButtons.equipment
    local remaining = available - buttonWidth - FILTER_BUTTON_GAP
    local equipmentOnLeft = remaining < 70
    equipment:ClearAllPoints()
    if not equipmentOnLeft then
        equipment:SetPoint("RIGHT", filterButtons.quest, "LEFT", -FILTER_BUTTON_GAP, 0)
        available = remaining
    else
        -- Use the space below the portrait if a narrow frame leaves too little room beside search.
        equipment:SetPoint("RIGHT", search, "LEFT", -FILTER_SEARCH_GAP, -3)
    end
    equipment:Show()
    local inlineWidth = available - 2 * (buttonWidth + FILTER_BUTTON_GAP)
    local showInline = not equipmentOnLeft and inlineWidth >= 60
    filterButtons.resources:SetShown(showInline)
    filterButtons.consumables:SetShown(showInline)
    if showInline then
        if overflowButton then overflowButton:Hide() end
        filterButtons.resources:SetPoint("RIGHT", equipment, "LEFT", -FILTER_BUTTON_GAP, 0)
        filterButtons.consumables:SetPoint("RIGHT", filterButtons.resources, "LEFT", -FILTER_BUTTON_GAP, 0)
        available = inlineWidth
    else
        -- Leave the search box and the two primary buttons in place on the narrow backpack.
        if not overflowButton then
            overflowButton = CreateFilterMenuButton(frame, overflowFilterModes, true)
            overflowButton.icon:SetSize(10, 10)
        elseif overflowButton:GetParent() ~= frame then
            overflowButton:SetParent(frame)
        end
        overflowButton:SetSize(12, buttonHeight)
        overflowButton:SetPoint("RIGHT", equipmentOnLeft and equipment or search, "LEFT", -3, equipmentOnLeft and 0 or -3)
        UpdateMenuFilterButton(overflowButton)
        overflowButton:Show()
    end
    search:SetWidth(math.min(normalSearchWidth, available))
end

function Bags:ShouldLoad()
    local db = GetDb()
    return not (db and db.enabled == false)
end

function Bags:Init()
    if self.initialized then return end
    self.initialized = true
    local useFilterButtons = SupportsBagFilters()
    for _, frame in ipairs(BagFrames()) do
        if frame.UpdateItems then hooksecurefunc(frame, "UpdateItems", UpdateFrameItems) end
        if useFilterButtons and frame.UpdateSearchBox then
            hooksecurefunc(frame, "UpdateSearchBox", function(bag) PlaceFilterButtons(bag, true) end)
            frame:HookScript("OnSizeChanged", function(bag) PlaceFilterButtons(bag) end)
        end
    end
    if useFilterButtons then
        -- Blizzard also updates icon saturation on its own when a bag slot locks or unlocks.
        hooksecurefunc("SetItemButtonDesaturated", function(button, locked)
            if not locked and dimmedIcons[button] then button:GetItemButtonIconTexture():SetDesaturated(true) end
        end)
        local search = _G.BagItemSearchBox
        if search and search:IsVisible() then PlaceFilterButtons(search:GetParent(), true) end
    end
    local combined = Combined()
    if combined then
        if combined.UpdateFrameSize then hooksecurefunc(combined, "UpdateFrameSize", Relayout) end
        if combined.UpdateItemLayout then hooksecurefunc(combined, "UpdateItemLayout", Relayout) end
        combined:HookScript("OnShow", function() Bags:PlaceBagButtons() end)
    end
    -- the bags move when they open or the screen changes: the buttons pick their side again
    hooksecurefunc("UpdateContainerFrameAnchors", function()
        Bags:PlaceBagButtons()
        ParkReagentWindow()
    end)
    -- the keyring and crafting bag sections follow their items
    local bagEvents = CreateFrame("Frame")
    if useFilterButtons then bagEvents:RegisterEvent("QUEST_LOG_UPDATE") end
    for _, event in ipairs({ "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "ITEM_LOCK_CHANGED", "INVENTORY_SEARCH_UPDATE",
                             "BAG_CONTAINER_UPDATE", "PLAYER_REGEN_ENABLED" }) do
        pcall(bagEvents.RegisterEvent, bagEvents, event)
    end
    bagEvents:SetScript("OnEvent", function(_, event)
        if event == "QUEST_LOG_UPDATE" then
            if itemFilter == "quest" then RefreshItemFilter() end
            return
        end
        if not next(extras) and not (KeyringWanted() or ReagentWanted()) then return end
        local frame = Combined()
        if not (frame and frame:IsShown()) then return end
        -- a new bag, more keys or buttons held back by a fight: lay the backpack out again
        if event == "BAG_CONTAINER_UPDATE" or event == "BAG_UPDATE_DELAYED" or event == "PLAYER_REGEN_ENABLED" then
            Relayout(frame)
        else
            FillExtras()
        end
    end)
    -- new gear, a level or a talent change re-scores the Upgrade arrow; a level, a new weapon skill or
    -- a repair also asks again what can be worn
    local RE_ASK_WEAR = { PLAYER_LEVEL_UP = true, SKILL_LINES_CHANGED = true, UPDATE_INVENTORY_DURABILITY = true }
    local events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "PLAYER_SPECIALIZATION_CHANGED",
        "CHARACTER_POINTS_CHANGED", "SKILL_LINES_CHANGED", "UPDATE_INVENTORY_DURABILITY" }) do
        pcall(events.RegisterEvent, events, event)
    end
    events:SetScript("OnEvent", function(_, event)
        Upgrade:Reset(RE_ASK_WEAR[event])
        local db = GetDb()
        if db and db.bagUpgradeArrow then Bags:Refresh() end
    end)
end

-- Live from the options. Blizzard's layout code is never called from here (that would run it
-- tainted): a layout switched off goes back to Blizzard's the next time the bags open.
function Bags:Refresh()
    if not self.initialized then return end
    if not BagFiltersEnabled() then SetItemFilter(nil) end
    local search = _G.BagItemSearchBox
    if SupportsBagFilters() and search and search:IsVisible() then PlaceFilterButtons(search:GetParent()) end
    for _, frame in ipairs(BagFrames()) do
        if frame:IsShown() then
            if frame == Combined() then Relayout(frame) end
            UpdateFrameItems(frame)
        end
    end
    self:PlaceBagButtons()
    ParkReagentWindow()
end

--------------------------------------------------
-- 5. SETTINGS PREVIEW SAMPLE
-- A made-up combined backpack: Blizzard's bag frame art, plain item buttons with made-up items laid
-- out and decorated by the code above (columns, gaps, borders, junk coin, upgrade arrow), the
-- keyring and crafting bag sections, the round bag buttons down the side and the money line.
-- No secure buttons, no events, nothing in the module's lists.
--------------------------------------------------
do
    local ICON = "Interface\\Icons\\"
    -- by bag, from the last to the backpack (Blizzard's order); slot -> { icon, quality, count, ... }
    local SAMPLE_BAGS = {
        { bag = 1, slots = 8, items = {
            [1] = { icon = ICON .. "INV_Misc_Pelt_Wolf_01", quality = 1, count = 6 },
            [2] = { icon = ICON .. "INV_Misc_Bone_HumanSkull_01", quality = 0 },
            [4] = { icon = ICON .. "INV_Ore_Copper_01", quality = 1, count = 8 },
        } },
        { bag = 0, slots = 16, items = {
            [1] = { icon = ICON .. "INV_Misc_Rune_01", quality = 1 },
            [2] = { icon = ICON .. "INV_Sword_04", quality = 2, upgrade = true },
            [3] = { icon = ICON .. "INV_Chest_Cloth_17", quality = 3 },
            [4] = { icon = ICON .. "INV_Jewelry_Ring_15", quality = 4 },
            [5] = { icon = ICON .. "INV_Misc_Food_15", quality = 1, count = 20, petFood = true },
            [6] = { icon = ICON .. "INV_Potion_51", quality = 1, count = 5 },
            [7] = { icon = ICON .. "INV_Fabric_Linen_01", quality = 1, count = 12 },
            [9] = { icon = ICON .. "INV_Misc_Bone_HumanSkull_01", quality = 0 },
        } },
    }
    local KEYS = { [1] = { icon = ICON .. "INV_Misc_Key_03", quality = 1 }, [2] = { icon = ICON .. "INV_Misc_Key_11", quality = 1 } }
    local REAGENTS = { [1] = { icon = ICON .. "INV_Misc_Herb_10", quality = 1, count = 14 },
                       [2] = { icon = ICON .. "INV_Misc_Dust_01", quality = 1, count = 3 } }
    local PAW = "Interface\\Icons\\Ability_Hunter_BeastTraining"   -- Pet Food in Bags (Tweaks.lua)
    local SLOT_SIZE = 37                 -- an item button's own size
    -- Blizzard's combined backpack paddings (ContainerFrameCombinedBagsMixin), the money box's height
    local PAD_W, PAD_H, MONEY_H = 15, 75, 17
    -- the frame art spills past the frame: the portrait corner left and up, the metal edges
    local SPILL_L, SPILL_T, SPILL_R, SPILL_B = 13, 16, 4, 3
    local PORTRAIT_BOTTOM = -55          -- the portrait's bottom edge, where the bag buttons start

    local function NextName(kind)
        Bags.previewCount = (Bags.previewCount or 0) + 1
        return "FlareUI_Preview" .. kind .. Bags.previewCount
    end

    local function SampleButton(f, i)
        local b = f.items[i]
        if b then return b end
        -- named: the ItemButton's own regions are named after it
        b = CreateFrame("ItemButton", NextName("BagItem"), f.panel)
        b.fuiSample = true
        b:EnableMouse(false)
        b:SetFrameLevel(f.panel:GetFrameLevel() + 2)
        if b.ClearNormalTexture then b:ClearNormalTexture() end
        if b.ClearPushedTexture then b:ClearPushedTexture() end
        Bags.AddSlotArt(b)
        b.paw = b:CreateTexture(nil, "OVERLAY", nil, 2)
        b.paw:SetSize(14, 14)
        b.paw:SetPoint("TOPLEFT", 2, -2)
        b.paw:SetTexture(PAW)
        b.paw:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        f.items[i] = b
        return b
    end

    local function Fill(b, item, db)
        SetItemButtonTexture(b, item and item.icon)
        SetItemButtonCount(b, item and item.count)
        local info = item and { quality = item.quality, sampleUpgrade = item.upgrade } or nil
        Bags.DecorateButton(b, db, info)
        b.paw:SetShown(item and item.petFood and db.petFood and true or false)
        b:SetSize(SLOT_SIZE, SLOT_SIZE)
        b:Show()
    end

    function Bags.CreateSample(parent)
        local f = CreateFrame("Frame", nil, parent)
        f.fuiSample = true
        f:EnableMouse(false)
        f:SetFrameLevel(parent:GetFrameLevel() + 1)
        f.items, f.bagButtons = {}, {}

        local panel = CreateFrame("Frame", nil, f)
        panel:SetFrameLevel(f:GetFrameLevel() + 1)
        panel.layoutType = "HeldBagLayout"
        f.panel = panel
        local level = panel:GetFrameLevel()
        -- the combined backpack's art (PortraitFrameFlatTemplate), every level relative to the panel
        panel.Bg = CreateFrame("Frame", nil, panel, "FlatPanelBackgroundTemplate")
        panel.Bg:SetFrameLevel(level)
        panel.Bg:SetPoint("TOPLEFT", 2, -20)
        panel.Bg:SetPoint("BOTTOMRIGHT", -2, 3)
        panel.NineSlice = CreateFrame("Frame", nil, panel, "NineSlicePanelTemplate")
        panel.NineSlice:SetFrameLevel(level + 1)
        panel.NineSlice:SetAllPoints()
        if NineSliceUtil and NineSliceUtil.ApplyLayoutByName then
            pcall(NineSliceUtil.ApplyLayoutByName, panel.NineSlice, "HeldBagLayout")
        end
        local top = CreateFrame("Frame", nil, panel)
        top:SetAllPoints()
        top:SetFrameLevel(level + 3)
        panel.portrait = top:CreateTexture(nil, "OVERLAY")
        panel.portrait:SetSize(62, 62)
        panel.portrait:SetPoint("TOPLEFT", -5, 7)
        panel.portrait:SetTexture(ICON .. "INV_Misc_Bag_08")
        local mask = top:CreateMaskTexture()
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetPoint("TOPLEFT", panel.portrait, "TOPLEFT", 2, 0)
        mask:SetPoint("BOTTOMRIGHT", panel.portrait, "BOTTOMRIGHT", -2, 4)
        panel.portrait:AddMaskTexture(mask)
        panel.title = top:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        panel.title:SetPoint("TOPLEFT", 58, -6)
        panel.title:SetPoint("TOPRIGHT", -24, -6)
        panel.title:SetText(_G.COMBINED_BAG_TITLE or _G.BACKPACK_TOOLTIP or "")

        -- the money line in Blizzard's coin box
        local money = CreateFrame("Frame", nil, panel)
        money:SetHeight(MONEY_H)
        money:SetPoint("BOTTOMLEFT", 8, 8)
        money:SetPoint("BOTTOMRIGHT", -8, 8)
        money:SetFrameLevel(level + 2)
        local left = money:CreateTexture(nil, "BACKGROUND")
        left:SetAtlas("common-coinbox-left")
        left:SetSize(8, MONEY_H)
        left:SetPoint("LEFT")
        local right = money:CreateTexture(nil, "BACKGROUND")
        right:SetAtlas("common-coinbox-right")
        right:SetSize(8, MONEY_H)
        right:SetPoint("RIGHT")
        local center = money:CreateTexture(nil, "BACKGROUND")
        center:SetAtlas("_common-coinbox-center")
        center:SetPoint("TOPLEFT", left, "TOPRIGHT")
        center:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
        money.text = money:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        money.text:SetPoint("RIGHT", -6, 0)
        panel.money = money
        return f
    end

    function Bags.DrawSample(f)
        local db = GetDb() or {}
        local panel = f.panel
        local columns = (db.bagColumns or 0) > 0 and db.bagColumns or DEFAULT_COLUMNS
        local gaps = db.bagGaps == true
        local w, h = SLOT_SIZE, SLOT_SIZE
        local stepX, stepY = w + ITEM_SPACING, h + ITEM_SPACING
        local anchor = panel.money

        -- Relayout's walk: the keyring and crafting bag sections first (the bottom rows), then the bags
        local index, col, row, gapCount, prevBag = 0, 0, 0, 0, nil
        local sections = {}
        if db.bagKeyring and KeyringID() then sections[#sections + 1] = KEYS end
        if db.bagReagent and ReagentID() then sections[#sections + 1] = REAGENTS end
        for _, items in ipairs(sections) do
            for slot = columns, 1, -1 do
                index = index + 1
                local b = SampleButton(f, index)
                Fill(b, items[slot], db)
                Bags.GridPoint(b, anchor, col, row, gapCount, stepX, stepY)
                col = col + 1
                if col >= columns then col, row = 0, row + 1 end
            end
            if col > 0 then col, row = 0, row + 1 end
            gapCount = gapCount + 1
        end
        for _, bag in ipairs(SAMPLE_BAGS) do
            for slot = bag.slots, 1, -1 do
                if gaps and prevBag and bag.bag ~= prevBag then
                    if col > 0 then col, row = 0, row + 1 end
                    gapCount = gapCount + 1
                end
                index = index + 1
                local b = SampleButton(f, index)
                Fill(b, bag.items[slot], db)
                Bags.GridPoint(b, anchor, col, row, gapCount, stepX, stepY)
                col = col + 1
                if col >= columns then col, row = 0, row + 1 end
                prevBag = bag.bag
            end
        end
        for i = index + 1, #f.items do f.items[i]:Hide() end
        local rows = row + (col > 0 and 1 or 0)
        local width = columns * w + (columns - 1) * ITEM_SPACING + PAD_W
        local height = rows * h + (rows - 1) * ITEM_SPACING + gapCount * BAG_GAP + PAD_H + MONEY_H + 12
        panel:SetSize(width, height)
        if NineSliceUtil and NineSliceUtil.UpdateCornerCropping then pcall(NineSliceUtil.UpdateCornerCropping, panel, height) end

        local cash = GetMoney and GetMoney() or 0
        panel.money.text:SetText((GetMoneyString and GetMoneyString(cash, true))
            or (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString and C_CurrencyInfo.GetCoinTextureString(cash)) or "")

        -- Integrated bag buttons: round, down the left edge from the portrait's bottom (PlaceBagButtons)
        local showButtons = db.bagButtons and true or false
        local ids = showButtons and Bags.BagButtonIDs() or {}
        for i, bagID in ipairs(ids) do
            local b = f.bagButtons[i]
            if not b then
                b = CreateFrame("ItemButton", NextName("BagButton"), panel, "CircularItemButtonTemplate")
                Mixin(b, BagButton)
                b:EnableMouse(false)
                b:SetSize(BAG_BUTTON_SIZE, BAG_BUTTON_SIZE)
                Bags.RoundBagButton(b)
                b:SetFrameLevel(panel:GetFrameLevel() + 5)
                f.bagButtons[i] = b
            end
            b:SetID(bagID)
            b:ClearAllPoints()
            if i == 1 then
                b:SetPoint("TOPRIGHT", panel, "TOPLEFT", 0, PORTRAIT_BOTTOM)
            else
                b:SetPoint("TOP", f.bagButtons[i - 1], "BOTTOM", 0, BAG_BUTTON_GAP)
            end
            b:Update()
            b:Show()
        end
        for i = #ids + 1, #f.bagButtons do f.bagButtons[i]:Hide() end

        -- the whole picture: the art's spill and the buttons outside the left edge
        local spillLeft = showButtons and math_max(SPILL_L, BAG_BUTTON_SIZE) or SPILL_L
        local buttonsBottom = showButtons and (-PORTRAIT_BOTTOM + #ids * (BAG_BUTTON_SIZE - BAG_BUTTON_GAP)) or 0
        local fullH = math_max(height, buttonsBottom) + SPILL_T + SPILL_B
        local fullW = width + spillLeft + SPILL_R
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", f, "TOPLEFT", spillLeft, -SPILL_T)
        f:SetSize(fullW, fullH)
        f:Show()
        return fullW, fullH
    end
end
