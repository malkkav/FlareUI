local _, ns = ...
local L = ns.L

--------------------------------------------------
-- BAGS
-- Quality of Life > Bags and Looting, on Blizzard's own bag windows:
--   * Columns and Gaps between bags: the combined backpack's grid, laid out again after Blizzard's
--     (hooksecurefunc on its UpdateFrameSize / UpdateItemLayout, so Blizzard's code runs untouched)
--   * Integrated bag buttons: the four bag slots down the combined backpack's side
--   * Thicker borders, Rarity colours, Junk coin and Upgrade arrow: drawn on an overlay of each item
-- Every option is off by default, and off leaves Blizzard's windows as they are, except the slot
-- borders: FlareUI Thin round every slot always. When another bag addon owns the windows, nothing
-- here runs.
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
    -- the empty slot's art (Blizzard draws it behind its own buttons)
    b.flareSlot = b:CreateTexture(nil, "BACKGROUND", nil, -1)
    b.flareSlot:SetAtlas("bags-item-slot64")
    b.flareSlot:SetAllPoints()
    e.buttons[slot] = b
    return b
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
                b:ClearAllPoints()
                b:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", -col * stepX, 4 + row * stepY + gapCount * BAG_GAP)
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
        button:ClearAllPoints()
        button:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", -col * stepX, 4 + row * stepY + gapCount * BAG_GAP)
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
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    if GetInventoryItemTexture("player", self.slotID) then
        GameTooltip:SetInventoryItem("player", self.slotID)
    else
        GameTooltip_SetTitle(GameTooltip, _G.EQUIP_CONTAINER or _G.BAGSLOT or "")
    end
    GameTooltip:Show()
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

local function CreateBagButtons(frame)
    if bagButtons[1] then return end
    local ids = {}
    for i = 1, (NUM_BAG_FRAMES or 4) do ids[#ids + 1] = i end
    local reagents = Constants.InventoryConstants and Constants.InventoryConstants.NumReagentBagSlots or 0
    if reagents > 0 and Enum.BagIndex.ReagentBag then ids[#ids + 1] = Enum.BagIndex.ReagentBag end
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
-- (grey to orange; empty slots stay bronze).
-- Junk coin: grey items worth money show Blizzard's coin always, not only at a vendor.
-- Upgrade arrow: gear that beats what you wear shows Blizzard's green arrow in the bottom right.
--------------------------------------------------
-- edge size and outset per border: each art's bright band lands on the slot's edge
local BORDERS = { thin = { "FlareUI Thin", 8, 3 }, thick = { "FlareUI Thick", 16, 2 } }
local function GetOverlay(button)
    local ov = overlays[button]
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
    overlays[button] = ov
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

-- Upgrade arrow: Forever has no "is an upgrade" check (Blizzard's flyout asks for one that is never
-- filled), so FlareUI scores items itself with light stat weights: your main stat counts 1, Stamina 0.5,
-- secondary ratings 0.4, armour a tie-breaker. Only gear the tooltip doesn't mark red (wrong armour
-- type, level, class) counts, and it is compared with what you wear there (the weaker of two rings,
-- trinkets or dual-wielded weapons; both hands against a two-hander).
local Upgrade = { score = {}, usable = {} }
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
    link = BaseLink(link)
    local cached = self.score[link]
    if cached then return cached end
    -- an uncached item has no stats yet: asked for, and scored on a later pass
    local itemID = C_Item.GetItemInfoInstant(link)
    if itemID and not C_Item.IsItemDataCachedByID(itemID) then C_Item.RequestLoadItemDataByID(itemID) return nil end
    local stats = C_Item.GetItemStats(link)
    if not stats then return nil end
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
    return Upgrade:Score(link) or math.huge, false   -- not loaded yet: no arrow this pass
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
    local worst, empty
    for _, slot in ipairs(slots) do
        local s, isEmpty = EquippedScore(slot)
        if isEmpty then empty = true end
        if not worst or s < worst then worst = s end
    end
    return empty or score > worst
end

-- talents, level and new gear change the answers
function Upgrade:Reset(full)
    self.mainStat = nil
    if full then wipe(self.usable) end
    wipe(self.score)
end

local function ShowUpgrade(ov, bagID, slotID, link)
    if Upgrade:Is(bagID, slotID, link) then ov.upgrade:Show() end
end

function UpdateButton(button, db)
    local thick, rarity = db.bagThickBorders, db.bagRarityBorders
    local junk, upgrade = db.bagJunkIcon, db.bagUpgradeArrow
    local ov = GetOverlay(button)
    ov:Show()
    ov.border:Hide()
    ov.junk:Hide()
    ov.upgrade:Hide()

    local bagID, slotID = button:GetBagID(), button:GetID()
    local info = bagID and slotID and C_Container.GetContainerItemInfo(bagID, slotID)
    local quality = info and info.quality

    if button.IconBorder then button.IconBorder:SetAlpha(0) end
    local style = thick and "thick" or "thin"
    if rarity and quality then
        local r, g, b = C_Item.GetItemQualityColor(quality)
        ShowBorder(ov, style, r, g, b)
    else
        local c = ns.BORDER_COLOR
        ShowBorder(ov, style, c.r, c.g, c.b)
    end

    if not info then return end
    if junk and quality == Enum.ItemQuality.Poor and not info.hasNoValue then ov.junk:Show() end
    if upgrade and info.hyperlink then
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

function Bags:ShouldLoad()
    local db = GetDb()
    return not (db and db.enabled == false)
end

function Bags:Init()
    if self.initialized then return end
    self.initialized = true
    for _, frame in ipairs(BagFrames()) do
        if frame.UpdateItems then hooksecurefunc(frame, "UpdateItems", UpdateFrameItems) end
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
    for _, event in ipairs({ "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "ITEM_LOCK_CHANGED", "INVENTORY_SEARCH_UPDATE",
                             "BAG_CONTAINER_UPDATE", "PLAYER_REGEN_ENABLED" }) do
        pcall(bagEvents.RegisterEvent, bagEvents, event)
    end
    bagEvents:SetScript("OnEvent", function(_, event)
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
    for _, frame in ipairs(BagFrames()) do
        if frame:IsShown() then
            if frame == Combined() then Relayout(frame) end
            UpdateFrameItems(frame)
        end
    end
    self:PlaceBagButtons()
    ParkReagentWindow()
end
