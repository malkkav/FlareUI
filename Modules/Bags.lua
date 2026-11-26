local ADDON_NAME, ns = ...
local L = ns.L

--------------------------------------------------
-- BAGS
-- Quality of Life > Bags and Looting, on Blizzard's own bag windows:
--   * Columns and Gaps between bags: the combined backpack's grid, laid out again after Blizzard's
--     (hooksecurefunc on its UpdateFrameSize / UpdateItemLayout, so Blizzard's code runs untouched)
--   * Integrated bag buttons: the four bag slots down the combined backpack's side
--   * Bank Window: the bank's Columns, Gaps between bags and Tight spacing (section 4e)
--   * Hide 2FA Bag Slots and Syndicator work alongside (sections 1b and 3, the gold list)
--   * Sort Bags on Open: Blizzard's clean-up each time the bags open (section 4d)
--   * Category Filters: a button beside the cleanup button opens a drawer of categories; the one
--     picked dims every other item (section 4b)
--   * Thicker borders, Rarity colours and Junk coin: drawn on an overlay of each item
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
-- Bag addons FlareUI's bag code stands down for (Bags:ShouldLoad): their own layout and cleanup are
-- left alone
local OTHER_BAG_ADDONS = { "LiteBag", "Bagnon", "Bagnonium", "Baganator", "ArkInventory", "AdiBags", "BetterBags",
                           "EnhanceQoLBags", "EllesmereUIBags", "Inventorian", "Combuctor", "cargBags_Nivaya",
                           "BagSmith", "Sorted", "BaudBag", "OneBag3", "Bagshui", "DJBags" }

local overlays = {}                 -- item button -> its overlay
local bagButtons = {}
local itemFilter
local dimmedIcons = {}

local function GetDb()
    return ns.db and ns.db.profile and ns.db.profile.tweaks
end

-- Bag View: "all", "filters" (Category Filters), "rows" or "rowsSets" (Category Rows, + equipment sets).
-- The older Category Filters dropdown (Off / Drawer / Buttons) is carried over once: any filter
-- becomes Category Filters, which shows the buttons when there's room and the drawer otherwise.
function Bags.View(db)
    db = db or GetDb()
    if not db then return "all" end
    local old = db.bagFilters
    if old ~= nil then
        if old ~= "off" and old ~= false and db.bagView == "all" then db.bagView = "filters" end
        db.bagFilters = nil
    end
    return db.bagView or "all"
end
local function CategoryRows(db) local v = Bags.View(db) return v == "rows" or v == "rowsSets" end

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

-- Blizzard's bag windows opened and closed from here leave its setup flag ours, and the bank reads that
-- flag as it opens: its whole opening then ran as FlareUI. Both fields are only notes Blizzard
-- makes again (no flag: nothing to set up), so they are emptied; a flag that is up stays.
function Bags.CleanFlags()
    local manager = _G.ContainerFrameSettingsManager
    if type(manager) ~= "table" or not ns.CleanField then return end
    if not manager.bagSetupDirty then ns.CleanField(manager, "bagSetupDirty") end
    ns.CleanField(manager, "bagsShown")
end

function Bags.OpenWindow(id, force)
    OpenBag(id, force)
    Bags.CleanFlags()
end

function Bags.CloseWindow(id)
    CloseBag(id)
    Bags.CleanFlags()
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
        or db.bagCombineEmpty == true or db.bagReverse == true or CategoryRows(db)
end

--------------------------------------------------
-- 0. KEYRING AND CRAFTING BAG IN THE BACKPACK (Keyring in Backpack, Crafting Bag in Backpack; off)
-- Blizzard's combined backpack holds bags 0-4 only; the keyring (-1) and the crafting bag (5) open
-- as their own windows. The keyring borrows native buttons; crafting uses local template buttons
-- when the game has not opened its native window.
--------------------------------------------------
local extras = {}   -- bagID -> { holder = frame, buttons = { [slot] = button } }
local highlightedExtraBag

local function UpdateExtraBagHighlight(bagID, section)
    local highlighted = bagID == highlightedExtraBag and section.holder:IsShown()
    for _, button in pairs(section.buttons) do
        button.BagIndicator:SetShown(highlighted and button:IsShown())
    end
    for _, button in pairs(section.probe or {}) do
        button.BagIndicator:SetShown(not section.window and highlighted and button:IsShown())
    end
end

local function SetExtraBagHighlight(bagID)
    highlightedExtraBag = bagID
    for id, section in pairs(extras) do UpdateExtraBagHighlight(id, section) end
end

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

local function ExtraWanted(id)
    if id == KeyringID() then return KeyringWanted() end
    return id == ReagentID() and ReagentWanted()
end

local function ShownSlots(bagID)
    if bagID == KeyringID() then return GetKeyRingSize() end
    return C_Container.GetContainerNumSlots(bagID)
end

local function Extra(bagID, frame)
    local e = extras[bagID]
    if e then return e end
    e = { buttons = {} }
    e.holder = CreateFrame("Frame", nil, frame)
    e.holder:Hide()
    e.holder:SetAllPoints(frame)
    e.holder:SetID(bagID)
    extras[bagID] = e
    return e
end

-- Reserve the two sections' parents before combat. Blizzard creates the item buttons.
local function WarmExtraSections()
    if InCombatLockdown() or not ns.BagModuleOn() or not Bags:IsCombined() or not LayoutWanted() then return end
    local frame = Combined()
    if not frame then return end
    for _, bagID in ipairs(ExtraBags()) do
        local e = Extra(bagID, frame)
        if bagID == ReagentID() then Bags.WarmReagentProbe(e, frame, bagID) end
    end
end

-- the empty slot's art (Blizzard draws it behind its own buttons)
function Bags.AddSlotArt(b)
    b.flareSlot = b:CreateTexture(nil, "BACKGROUND", nil, -1)
    b.flareSlot:SetAtlas("bags-item-slot64")
    b.flareSlot:SetAllPoints()
end

-- Fallback slots for the combined backpack; the addon never opens the native reagent window.
function Bags.WarmReagentProbe(e, frame, bagID)
    if InCombatLockdown() then return end
    e.probe = e.probe or {}
    for slot = 1, ShownSlots(bagID) do
        if not e.probe[slot] then
            local b = CreateFrame("ItemButton", "FlareUIReagentProbeSlot" .. slot, e.holder, "ContainerFrameItemButtonTemplate")
            b:Hide()
            if not (b.Initialize and b.SetBagID) then return end
            b:Initialize(frame, bagID, slot)
            b:Hide()
            -- The template leaves this overlay shown until the native window's item update.
            -- These buttons are not in that window's pool. Reset the unused default overlay only.
            if b.BattlepayItemTexture then b.BattlepayItemTexture:Hide() end
            Bags.AddSlotArt(b)
            e.probe[slot] = b
        end
    end
end

-- Looks like the other slots: what Blizzard's own update draws on a slot (ContainerFrameMixin:UpdateItems:
-- quality, quest mark, new item glow, cooldown), then FlareUI's overlay (borders, fonts, the category filter).
-- These buttons are in no window's list, so neither reaches them otherwise.
function Bags.DressReagentProbe(button, bagID, slot, info)
    -- (a value the game hides in a fight, or a part this client lacks: the slot goes without that part)
    local function Draw(method, ...)
        local f = button[method]
        if f then pcall(f, button, ...) end
    end
    local texture = info and info.iconFileID
    local quality = info and info.quality
    Draw("SyncAppearanceWithHasItem")
    if SetItemButtonQuality then pcall(SetItemButtonQuality, button, quality, info and info.hyperlink, false, info and info.isBound) end
    Draw("UpdateExtended")
    local quest = C_Container.GetContainerItemQuestInfo and C_Container.GetContainerItemQuestInfo(bagID, slot)
    if quest then Draw("UpdateQuestItem", quest.isQuestItem, quest.questID, quest.isActive) end
    Draw("UpdateNewItem", quality)
    Draw("UpdateJunkItem", quality, info and info.hasNoValue)
    Draw("UpdateCooldown", texture)
    Draw("SetReadable", info and info.isReadable)
    local db = GetDb()
    if db and not Bags:GetOtherBagAddon() then Bags.DecorateButton(button, db, info, bagID, slot) end
end

function Bags.UpdateReagentProbe(button, bagID, slot)
    local info = C_Container.GetContainerItemInfo(bagID, slot)
    if canaccessvalue and not canaccessvalue(info) then return end
    local texture, count, locked, filtered
    if info then texture, count, locked, filtered = info.iconFileID, info.stackCount, info.isLocked, info.isFiltered end
    if canaccessvalue and not (canaccessvalue(texture) and canaccessvalue(count) and canaccessvalue(locked) and canaccessvalue(filtered)) then return end
    button:SetHasItem(texture ~= nil)
    SetItemButtonTexture(button, texture)
    SetItemButtonCount(button, count or 0)
    SetItemButtonDesaturated(button, locked == true)
    Bags.DressReagentProbe(button, bagID, slot, info)
    if button.SetMatchesSearch then button:SetMatchesSearch(not filtered) end
end

-- a slot's place in the combined backpack: filled from the bottom right, right to left, upwards
-- extra: more height below this row (By Category's section titles)
-- REVERSE BAG FILL (from zbee's idea; tweaks.bagReverse, off): the plain grid turned
-- round, so it starts at the top left and reads left to right, downwards; the Combine Empty Slots
-- slot ends it, at the bottom. Same order, same rows and gaps: each slot's spot is mirrored once the
-- grid is laid out (Bags.placedSlots, reused). With Category Rows each section is turned round on its own,
-- under its header: its last row is the short one, so an item that goes moves only the ones after it.
Bags.placedSlots = {}
function Bags.ReverseOn(db)
    return db and db.bagReverse == true or false
end
function Bags.Reverse(placed, count, anchor, stepX, h, columns)
    local top = 0
    for i = 1, count do top = math_max(top, placed[i].y + h) end
    for i = 1, count do
        local spot = placed[i]
        local b = spot.button
        if not (InCombatLockdown() and b:IsProtected()) then
            b:ClearAllPoints()
            b:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", -(columns - 1 - spot.col) * stepX, 4 + top - (spot.y + h))
        end
        spot.button = nil
    end
end
function Bags.ReverseSection(placed, from, to, anchor, stepX, columns)
    if to < from then return end
    local low, high = math.huge, -math.huge
    for i = from, to do low, high = math.min(low, placed[i].y), math_max(high, placed[i].y) end
    for i = from, to do
        local spot = placed[i]
        local b = spot.button
        if not (InCombatLockdown() and b:IsProtected()) then
            b:ClearAllPoints()
            b:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", -(columns - 1 - spot.col) * stepX, low + high - spot.y)
        end
        spot.button = nil
    end
end
function Bags.GridPoint(b, anchor, col, row, gapCount, stepX, stepY, extra)
    b:ClearAllPoints()
    b:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", -col * stepX, 4 + row * stepY + gapCount * BAG_GAP + (extra or 0))
end

local function HideExtras(except)
    for bagID, e in pairs(extras) do
        if not (except and except[bagID]) and not (InCombatLockdown() and e.holder:IsProtected()) then
            e.shownSlots = nil
            e.holder:Hide()
            if bagID == highlightedExtraBag then UpdateExtraBagHighlight(bagID, e) end
        end
    end
end

local function ClearExtraNewItems()
    -- OnHide runs after the backpack is hidden. IsShown still identifies its displayed slots.
    for bagID, e in pairs(extras) do
        if e.holder:IsShown() then
            for slot, b in pairs(e.buttons) do
                if b:IsShown() then C_NewItems.RemoveNewItem(bagID, slot) end
            end
            for slot, b in pairs(e.probe or {}) do
                if b:IsShown() then C_NewItems.RemoveNewItem(bagID, slot) end
            end
        end
    end
end

-- The native windows stay open so Blizzard can update their items.
local parked = {}
local openedForBackpack = {}
local openingForBackpack

function Bags:IsNativeBagWindowParked(frame)
    return parked[frame] ~= nil
end

-- Blizzard anchors the next bag to this one. Keep its place in that chain while the native
-- window is off screen. The anchor has the same parent, scale, size and point as the window.
local function RedirectBagAnchors(from, to)
    local function Redirect(region)
        if not region or region == from or region == to then return end
        local point, relative, relativePoint, x, y = region:GetPoint(1)
        if relative == from then
            region:ClearAllPoints()
            region:SetPoint(point, to, relativePoint, x, y)
        end
    end
    for i = 1, NUM_CONTAINER_FRAMES or 13 do
        local bag = _G["ContainerFrame" .. i]
        if bag then
            if bag:IsShown() then Redirect(bag) end
            Redirect(bag.fuiBagAnchor)
        end
    end
end

local function CanMoveWindow(frame, oldAnchor)
    if not InCombatLockdown() then return true end
    if frame:IsProtected() or (frame.fuiBagAnchor and frame.fuiBagAnchor:IsProtected()) then return false end
    if not oldAnchor then return true end
    local function AnchoredAndProtected(region)
        return region and region:IsProtected() and select(2, region:GetPoint(1)) == oldAnchor
    end
    for i = 1, NUM_CONTAINER_FRAMES or 13 do
        local other = _G["ContainerFrame" .. i]
        if other and ((other:IsShown() and AnchoredAndProtected(other)) or AnchoredAndProtected(other.fuiBagAnchor)) then
            return false
        end
    end
    return true
end

local function ParkWindow(frame)
    local point, relative, relativePoint, x, y = frame:GetPoint(1)
    if point and not (point == "TOPRIGHT" and relative == UIParent and relativePoint == "TOPLEFT" and x == -2000) then
        local anchor = frame.fuiBagAnchor
        if not anchor then
            anchor = CreateFrame("Frame", nil, frame:GetParent())
            anchor:Hide()
            frame.fuiBagAnchor = anchor
        end
        anchor:SetParent(frame:GetParent())
        anchor:SetScale(frame:GetScale())
        anchor:SetSize(frame:GetSize())
        anchor:ClearAllPoints()
        anchor:SetPoint(point, relative, relativePoint, x, y)
        RedirectBagAnchors(frame, anchor)
    end
    if parked[frame] == nil then parked[frame] = frame:IsClampedToScreen() end
    frame:SetClampedToScreen(false)
    frame:ClearAllPoints()
    frame:SetPoint("TOPRIGHT", UIParent, "TOPLEFT", -2000, 0)
    frame:SetAlpha(0)
end

local function UnparkWindow(frame)
    local anchor = frame.fuiBagAnchor
    if anchor then
        local point, relative, relativePoint, x = frame:GetPoint(1)
        if point == "TOPRIGHT" and relative == UIParent and relativePoint == "TOPLEFT" and x == -2000 then
            frame:ClearAllPoints()
            frame:SetPoint(anchor:GetPoint(1))
        end
        RedirectBagAnchors(anchor, frame)
    end
    frame:SetClampedToScreen(parked[frame])
    parked[frame] = nil
    frame:SetAlpha(1)
    if Bags.ReturnExtraButtons(frame) and frame:IsShown() and not InCombatLockdown() then frame:UpdateItemLayout() end
end

local function ParkOne(frame)
    local combined = Combined()
    Bags.HookBagWindow(frame)
    local id = frame:GetID()
    local park = frame:IsShown() and ExtraWanted(id) and Bags:IsCombined() and LayoutWanted()
        and (id == ReagentID() or (combined and combined:IsShown()))
    if park and not (CanMoveWindow(frame, frame) and Bags.AdoptExtraButtons(frame)) then park = false end
    if park then
        ParkWindow(frame)
    elseif parked[frame] ~= nil and CanMoveWindow(frame, frame.fuiBagAnchor) then
        UnparkWindow(frame)
    end
end
local function ParkExtraWindows()
    for id, owned in pairs(openedForBackpack) do
        if not owned:IsShown() or owned:GetID() ~= id then openedForBackpack[id] = nil end
    end
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local frame = _G["ContainerFrame" .. i]
        if type(frame) == "table" and frame.GetID then
            -- (one window that fails never keeps the next from its section)
            local ok, err = pcall(ParkOne, frame)
            if not ok then ns.LogError("Bags extra window " .. i, err) end
        end
    end
end

local function CloseParkedReagentWindow()
    local reagentID = ReagentID()
    local reagent = reagentID and ContainerFrameUtil_GetShownFrameForID(reagentID)
    if reagent and parked[reagent] ~= nil and ReagentWanted() then Bags.CloseWindow(reagentID) end
end

-- A native backpack click opens only the combined frame. With bag 5 equipped,
-- Blizzard's Open All Bags key would close it and immediately reopen both bags.
local closeKeyOwner, openedBy
local closeKeys = {}

local function ReleaseCloseKeys()
    if not openedBy then return end
    openedBy = nil
    for key in pairs(closeKeys) do closeKeys[key] = nil end
    if not InCombatLockdown() then ClearOverrideBindings(closeKeyOwner) end
end

local function RefreshCloseKeys()
    if not openedBy or InCombatLockdown() then return end
    local keys = ContainerFrameUtil_GetShownFrameForID(KeyringID())
    if not (ns.BagModuleOn() and Bags:IsCombined() and LayoutWanted() and openedBy() and ReagentWanted())
        or KeybindFrames_InQuickKeybindMode() or ContainerFrameUtil_GetShownFrameForID(ReagentID())
        or (keys and keys ~= openedForBackpack[KeyringID()]) then
        ReleaseCloseKeys()
        return
    end
    for key in pairs(closeKeys) do
        if GetBindingAction(key) ~= "OPENALLBAGS" then
            closeKeys[key] = nil
            SetOverrideBinding(closeKeyOwner, false, key, nil)
        end
    end
    for _, key in ipairs({ GetBindingKey("OPENALLBAGS") }) do
        if GetBindingAction(key, true) == "OPENALLBAGS" then
            closeKeys[key] = true
            SetOverrideBinding(closeKeyOwner, false, key, "TOGGLEBACKPACK")
        end
    end
end

local function WatchBackpackClick(proxy, slotWanted)
    local combined = Combined()
    if not closeKeyOwner then
        closeKeyOwner = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
        -- The binding owner can release its keys even if combat starts with the window open.
        closeKeyOwner:SetAttribute("_onstate-combat", [[if newstate == "combat" then self:ClearBindings() end]])
        RegisterStateDriver(closeKeyOwner, "combat", "[combat] combat; peace")
        closeKeyOwner:RegisterEvent("UPDATE_BINDINGS")
        closeKeyOwner:RegisterEvent("PLAYER_REGEN_ENABLED")
        closeKeyOwner:SetScript("OnEvent", RefreshCloseKeys)
        combined:HookScript("OnHide", ReleaseCloseKeys)
        EventRegistry:RegisterCallback("ContainerFrame.OpenBag", function(_, frame)
            if frame ~= combined and not (openingForBackpack == KeyringID() and frame:GetID() == openingForBackpack) then
                ReleaseCloseKeys()
            end
        end, closeKeyOwner)
    end

    local wasClosed
    proxy:HookScript("PreClick", function() wasClosed = not combined:IsShown() end)
    proxy:HookScript("PostClick", function()
        if wasClosed and combined:IsShown() then
            openedBy = slotWanted
            RefreshCloseKeys()
        end
    end)
end

local function ConfigureBackpackClick(proxy, slot, backpack)
    proxy:Hide()
    proxy:SetAllPoints(slot)
    proxy:SetHitRectInsets(slot:GetHitRectInsets())
    proxy:SetMouseClickEnabled(true)
    proxy:SetPassThroughButtons("MiddleButton", "Button4", "Button5")
    proxy:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    proxy:SetAttribute("useOnKeyDown", false)
    proxy:SetAttribute("type", "click")
    proxy:SetAttribute("clickbutton", backpack)
end

local keyringClickProxy, keyringClickActive

local function RefreshKeyringClickProxy()
    if InCombatLockdown() then return end

    local keyring, backpack = _G.KeyRingButton, _G.MainMenuBarBackpackButton
    local scriptedInput = Enum.ForbiddenAspect and Enum.ForbiddenAspect.ScriptedInput
    local enabled = keyring and backpack and scriptedInput and not GetCursorInfo()
        and not KeybindFrames_InQuickKeybindMode() and ns.BagModuleOn()
        and Combined() and Bags:IsCombined() and LayoutWanted() and KeyringWanted()
        and not backpack:HasAccessConstraints() and not backpack:HasAnyForbiddenAspects(scriptedInput)
    if not enabled then
        if keyringClickActive then
            UnregisterStateDriver(keyringClickProxy, "visibility")
            keyringClickProxy:Hide()
            keyringClickActive = false
        end
        return
    end
    if keyringClickActive then return end

    if not keyringClickProxy then
        local proxy = CreateFrame("Button", "FlareUIKeyringBackpackClick", keyring, "SecureActionButtonTemplate")
        ConfigureBackpackClick(proxy, keyring, backpack)
        proxy:SetMouseMotionEnabled(false)
        WatchBackpackClick(proxy, KeyringWanted)
        keyringClickProxy = proxy
    end
    -- The native keyring receives drops and clicks with an item on the cursor.
    -- In combat its native handler must stay available as the cursor changes.
    RegisterStateDriver(keyringClickProxy, "visibility", "[combat][mod] hide; show")
    keyringClickActive = true
end

local reagentClickProxy
local reagentClickDriver

local function RefreshReagentClickProxy()
    if InCombatLockdown() then return end

    local reagent = _G.CharacterReagentBag0Slot
    local backpack = _G.MainMenuBarBackpackButton
    local scriptedInput = Enum.ForbiddenAspect and Enum.ForbiddenAspect.ScriptedInput
    local enabled = reagent and backpack and scriptedInput
        and ns.BagModuleOn() and Combined() and Bags:IsCombined() and LayoutWanted() and ReagentWanted()
        and not backpack:HasAccessConstraints() and not backpack:HasAnyForbiddenAspects(scriptedInput)
    local driver
    if enabled then
        -- With an item on the cursor the native slot handles both clicks and drops.
        -- Keep the existing backpack shortcut in combat.
        if GetCursorInfo() or KeybindFrames_InQuickKeybindMode() then
            driver = "[combat] show; hide"
        else
            driver = "[combat] show; [mod] hide; show"
        end
    end
    if driver == reagentClickDriver then return end
    if not driver then
        UnregisterStateDriver(reagentClickProxy, "visibility")
        reagentClickProxy:Hide()
        reagentClickDriver = nil
        return
    end

    if not reagentClickProxy then
        local proxy = CreateFrame("Button", "FlareUIReagentBackpackClick", reagent,
            "SecureActionButtonTemplate, SecureHandlerDragTemplate")
        ConfigureBackpackClick(proxy, reagent, backpack)
        proxy:SetMouseMotionEnabled(true)
        proxy:SetPropagateMouseMotion(true)
        -- Blizzard's drag action takes the equipment slot, not the container ID (5).
        proxy:SetID(reagent:GetID())
        proxy:RegisterForDrag("LeftButton")
        proxy:SetAttribute("_ondragstart", "if not kind and not PlayerInCombat() then return 'bag', self:GetID() end")
        WatchBackpackClick(proxy, ReagentWanted)
        reagentClickProxy = proxy
    end
    RegisterStateDriver(reagentClickProxy, "visibility", driver)
    reagentClickDriver = driver
end

local function RefreshBagClickProxies()
    RefreshReagentClickProxy()
    RefreshKeyringClickProxy()
    RefreshCloseKeys()
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

local function LayoutColumns(db)
    return (db.bagColumns or 0) > 0 and db.bagColumns or DEFAULT_COLUMNS
end

-- The grid lays items upward from the bottom, so this is reverse of the visible alphabetical order.
local CATEGORY_ORDER = { "other", "quest", "materials", "junk", "equipment", "consumables" }
local CATEGORY_NAMES = {
    quest = L["Quest Items"], equipment = L["Equipment"], materials = L["Materials"],
    consumables = L["Consumables"], junk = L["Junk"], other = L["Other"],
}
local categoryHeaders = {}
local CATEGORY_HEADER_HEIGHT = 20
local categoryHidden = setmetatable({}, { __mode = "k" })

local function GetCollapsedSections()
    local char = ns.CharDB()
    char.collapsedBagSections = char.collapsedBagSections or {}
    return char.collapsedBagSections
end

-- Open All Bags supplies the reagent window itself. Wait until that operation finishes before
-- opening a missing window or closing one that FlareUI opened for the backpack.
local extraSyncQueued = false
local function SyncBackpackExtras()
    extraSyncQueued = false
    local backpack = Combined()
    if InCombatLockdown() or not backpack then return end
    local active = backpack:IsShown() and ns.BagModuleOn() and Bags:IsCombined() and LayoutWanted()
    for id, owned in pairs(openedForBackpack) do
        if not (active and ExtraWanted(id)) and ContainerFrameUtil_GetShownFrameForID(id) == owned then Bags.CloseWindow(id) end
    end
    if not active then return end
    local folded = CategoryRows(GetDb()) and GetCollapsedSections()
    local bags = ExtraBags()
    for i = #bags, 1, -1 do
        local id = bags[i]
        local native = ContainerFrameUtil_GetShownFrameForID(id)
        if native then
            if id == KeyringID() and native:GetBagSize() ~= GetKeyRingSize() then
                Bags.OpenWindow(id, true)
            elseif parked[native] == nil or not (extras[id] and extras[id].window == native) then
                -- (also one kept off screen whose buttons went back to it: its section stayed empty)
                ParkExtraWindows()
            end
        -- Do not open the reagent window here. Opening bag 5 from a deferred addon callback
        -- can taint the next bank open and block item use after the bank has closed.
        -- The combined backpack instead uses its own template buttons until Blizzard opens bag 5.
        elseif id ~= ReagentID() and not (folded and folded[id]) then
            openingForBackpack = id
            Bags.OpenWindow(id)
            openingForBackpack = nil
            openedForBackpack[id] = ContainerFrameUtil_GetShownFrameForID(id)
        end
    end
end

local function QueueBackpackExtraSync()
    if extraSyncQueued or InCombatLockdown() then return end
    extraSyncQueued = true
    C_Timer.After(0, SyncBackpackExtras)
end

-- Equipment sets as categories of their own (the Equipment Manager's sets, in its order), each just
-- after Equipment. An item in more than one set goes in the first. Read on each layout:
-- list: { key, name } per set; where: bag -> slot -> its set's key (bags only, not the bank)
Bags.SetCategories = {}

function Bags.SetCategories.Read()
    local list, where = {}, {}
    local api = C_EquipmentSet
    if not (api and api.GetEquipmentSetIDs and api.GetEquipmentSetInfo and api.GetItemLocations
        and EquipmentManager_GetLocationData) then return list, where end
    for _, setID in ipairs(api.GetEquipmentSetIDs() or {}) do
        local name = api.GetEquipmentSetInfo(setID)
        local locations = name and api.GetItemLocations(setID)
        if locations then
            local key = "set:" .. setID
            list[#list + 1] = { key = key, name = name }
            -- (empty, ignored and missing slots are small numbers without the bags bit)
            for _, location in pairs(locations) do
                local data = type(location) == "number" and EquipmentManager_GetLocationData(location)
                if data and data.isBags and not data.isBank and data.bag and data.slot then
                    local bag = where[data.bag] or {}
                    where[data.bag] = bag
                    bag[data.slot] = bag[data.slot] or key
                end
            end
        end
    end
    return list, where
end

-- the grid's category order (bottom first) with the sets between Junk and Equipment, so they read
-- just below Equipment
function Bags.SetCategories.Order(list)
    local order = {}
    for _, key in ipairs(CATEGORY_ORDER) do
        if key == "equipment" then
            for i = #list, 1, -1 do order[#order + 1] = list[i].key end
        end
        order[#order + 1] = key
    end
    return order
end

local function ItemCategory(button, setOf)
    if Bags.combinedEmpty and Bags.combinedEmpty[button] then return "other" end
    local bagID, slotID = button:GetBagID(), button:GetID()
    local info = C_Container.GetContainerItemInfo(bagID, slotID)
    if not info then return "other" end
    local set = setOf and setOf[bagID] and setOf[bagID][slotID]
    if set then return set end
    local quest = C_Container.GetContainerItemQuestInfo and C_Container.GetContainerItemQuestInfo(bagID, slotID)
    if quest and (quest.isQuestItem or quest.questID) then return "quest" end
    if info.quality == Enum.ItemQuality.Poor and info.itemID then
        local _, _, _, _, _, _, _, _, _, _, sellPrice = C_Item.GetItemInfo(info.itemID)
        if (sellPrice or 0) > 0 then return "junk" end
    end
    if info.itemID then
        local classID = select(6, C_Item.GetItemInfoInstant(info.itemID))
        local classes = Enum.ItemClass
        if classID == classes.Weapon or classID == classes.Armor then
            local slotType = C_Item.GetItemInventoryTypeByID(info.itemID)
            local types = Enum.InventoryType
            if slotType ~= types.IndexNonEquipType and slotType ~= types.IndexBagType
                and slotType ~= types.IndexQuiverType and slotType ~= types.IndexAmmoType then return "equipment" end
        elseif classID == classes.Tradegoods or (Enum.ItemClass.Reagent and classID == Enum.ItemClass.Reagent) then
            return "materials"
        elseif classID == classes.Consumable then
            return "consumables"
        end
    end
    return "other"
end

-- SOUL BAGS (with Crafting Bag in Backpack): a soul bag in one of the four bag slots gets a section of its own too, at
-- the bottom above the crafting bag. Its buttons are the backpack's own already: only their place changes.
Bags.SoulBags = { SUBCLASS = 1 }
function Bags.SoulBags.Is(bagID)
    if not (bagID and bagID >= 1 and bagID <= (_G.NUM_BAG_SLOTS or 4)) then return false end
    local toSlot = C_Container.ContainerIDToInventoryID
    local slot = toSlot and toSlot(bagID)
    local itemID = slot and GetInventoryItemID("player", slot)
    if not itemID then return false end
    local classID, subclassID = select(6, C_Item.GetItemInfoInstant(itemID))
    local container = Enum.ItemClass and Enum.ItemClass.Container or 1
    return classID == container and subclassID == Bags.SoulBags.SUBCLASS
end
-- items split: the rest, and { bag, label, items } per soul bag (the last bag first, as the grid fills)
function Bags.SoulBags.Split(items, db)
    if not (db and db.bagReagent) then return items, {} end
    local rest, list, of, is = {}, {}, {}, {}
    for _, button in ipairs(items) do
        local bag = button:GetBagID()
        if is[bag] == nil then is[bag] = Bags.SoulBags.Is(bag) end
        if is[bag] then
            local section = of[bag]
            if not section then
                local name = C_Container.GetBagName and C_Container.GetBagName(bag)
                section = { bag = bag, key = "soul" .. bag, label = name or L["Soul Bag"], items = {} }
                of[bag], list[#list + 1] = section, section
            end
            section.items[#section.items + 1] = button
        else
            rest[#rest + 1] = button
        end
    end
    -- (nothing but soul bags: the plain grid)
    if #rest == 0 then return items, {} end
    return rest, list
end

local function ExtraSectionLabel(bagID)
    return bagID == KeyringID() and L["Keyring"] or L["Crafting Bag"]
end

local function CreateCategoryHeader(frame, onClick)
    local header = CreateFrame("Button", nil, frame)
    header:SetHeight(CATEGORY_HEADER_HEIGHT)
    header.arrow = header:CreateTexture(nil, "ARTWORK")
    header.arrow:SetTexture("Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Panel\\Chevron.tga")
    header.arrow:SetSize(11, 11)
    header.arrow:SetPoint("LEFT")
    header.arrow:SetVertexColor(1, 0.82, 0.3)
    header.label = header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    header.label:SetPoint("LEFT", header.arrow, "RIGHT", 4, 0)
    header.label:SetPoint("RIGHT", header, "RIGHT")
    header.label:SetJustifyH("LEFT")
    header.label:SetWordWrap(false)
    header.label:SetTextColor(1, 0.82, 0.3)
    header:EnableMouse(onClick ~= nil)
    if onClick then header:SetScript("OnClick", onClick) end
    return header
end

local function SetCategoryHeader(header, label, collapsed)
    header.label:SetText(label)
    header.arrow:SetRotation(collapsed and math.pi / 2 or 0)
end

-- A pooled button can belong to another slot on the next layout. Only change the
-- visibility of currently enumerated slots, and only restore buttons we hid.
local function SetCategorySlotCollapsed(button, folded)
    if folded then
        if button:IsShown() then
            if InCombatLockdown() and button:IsProtected() then return false end
            button:Hide()
            categoryHidden[button] = true
        end
        return true
    elseif categoryHidden[button] then
        if not button:IsShown() then
            if InCombatLockdown() and button:IsProtected() then return true end
            button:Show()
        end
        categoryHidden[button] = nil
    end
    return false
end

local function ExtraSectionChanged(bagID, wanted)
    local section = bagID and extras[bagID]
    -- A folded section is still in the layout with its header above the money frame.
    local slots = section and section.shownSlots
    if not wanted then return slots ~= nil end
    return slots ~= ShownSlots(bagID)
end

-- Blizzard's "+" button for an account without an authenticator (ContainerFrameExtendedSlotPack:
-- LayoutAddSlots) sits on the left of the first locked slot. FlareUI's grid moves or hides that slot, so
-- with a FlareUI layout the button goes to the empty left end of the money bar, sized to fit it; without
-- one, Blizzard's own size and place come back. (A plain button, no secure template.)
-- OFFSET_X: over the money bar's rounded left end (8 px), so its edge doesn't show beside the button
Bags.AddSlots = { SIZE = 22, BLIZZARD_SIZE = 28, OFFSET_X = -4 }

function Bags.AddSlots.Place(frame, wanted)
    local button = frame and frame.AddSlotsButton
    if not button then return end
    local AddSlots = Bags.AddSlots
    if wanted and frame.MoneyFrame then
        button:SetSize(AddSlots.SIZE, AddSlots.SIZE)
        button:ClearAllPoints()
        button:SetPoint("LEFT", frame.MoneyFrame, "LEFT", AddSlots.OFFSET_X, 0)
        AddSlots.moved = true
    elseif AddSlots.moved then
        AddSlots.moved = nil
        button:SetSize(AddSlots.BLIZZARD_SIZE, AddSlots.BLIZZARD_SIZE)
        if frame.LayoutAddSlots then frame:LayoutAddSlots() end
    end
end

local layingOut = false
local extraButtonsDeferred = false
local lastLayoutColumns, lastLayoutGaps, lastLayoutSecured
local hadCategoryLayout = false
local function Relayout(frame)
    if layingOut or not frame or frame ~= Combined() or not frame:IsShown() then return end
    local wanted = Bags:IsCombined() and LayoutWanted()
    -- Restore the ordinary grid immediately when Category Rows was the last active layout option.
    local restoreGrid = hadCategoryLayout and Bags:IsCombined() and not GamepadUI() and not Bags:GetOtherBagAddon()
    if not (wanted or restoreGrid) then
        if hadCategoryLayout then
            for _, header in pairs(categoryHeaders) do header:Hide() end
            for _, button in frame:EnumerateValidItems() do SetCategorySlotCollapsed(button, false) end
            hadCategoryLayout = false
        end
        extraButtonsDeferred = false
        lastLayoutColumns = nil
        HideExtras()
        Bags.AddSlots.Place(frame, false)
        return
    end
    local db = GetDb()
    local categorized = CategoryRows(db)
    local collapsedSections = categorized and GetCollapsedSections()
    local items = {}
    for _, button in frame:EnumerateValidItems() do items[#items + 1] = button end
    if #items == 0 then return end
    local secured = not IsAccountSecured or IsAccountSecured()
    table_sort(items, secured and SortItems or SortItemsExtended)
    -- Hide 2FA Bag Slots: its hidden locked slots stay out of the grid (section 1b)
    local h2fa = not secured and Bags.H2FA.On()
    if h2fa then
        items = Bags.H2FA.Items(items)
        if #items == 0 then return end
    end

    -- Combine Empty Slots: the filled slots, then one empty slot showing how many are free
    local combine = Bags.CombineEmptyOn()
    layingOut = true   -- (its shows and hides must not lay out again)
    items = Bags.CombineEmpty(items, combine)
    layingOut = false
    if #items == 0 then return end

    local soulBags
    items, soulBags = Bags.SoulBags.Split(items, db)

    local groups, order, setNames
    if categorized then
        local sets, setOf = {}, nil
        if Bags.View(db) == "rowsSets" then sets, setOf = Bags.SetCategories.Read() end
        order = Bags.SetCategories.Order(sets)
        setNames = {}
        for _, set in ipairs(sets) do setNames[set.key] = set.name end
        groups = {}
        for _, key in ipairs(order) do groups[key] = {} end
        for _, button in ipairs(items) do
            local key = ItemCategory(button, setOf)
            local group = groups[key]
            group[#group + 1] = button
        end
    end

    local columns = LayoutColumns(db)
    local gaps = db.bagGaps == true and not (h2fa and Bags.H2FA.Compact()) and not combine
    local w, h = items[1]:GetSize()
    local stepX, stepY = w + ITEM_SPACING, h + ITEM_SPACING
    local anchor = frame.MoneyFrame
    if not anchor then return end

    layingOut = true
    hadCategoryLayout = categorized
    extraButtonsDeferred = false
    local col, row, gapCount, prevBag = 0, 0, 0, nil
    local headerSpace, visibleHeaders = 0, {}
    local gridWidth = columns * stepX - ITEM_SPACING
    local function FinishRow()
        if col > 0 then col, row = 0, row + 1 end
    end
    local placed, placedCount = Bags.placedSlots, 0
    local function PlaceSlot(button)
        Bags.GridPoint(button, anchor, col, row, gapCount, stepX, stepY, headerSpace)
        placedCount = placedCount + 1
        local spot = placed[placedCount] or {}
        placed[placedCount] = spot
        spot.button, spot.col, spot.y = button, col, 4 + row * stepY + gapCount * BAG_GAP + headerSpace
        col = col + 1
        if col == columns then col, row = 0, row + 1 end
    end
    local reverse, sectionFrom = Bags.ReverseOn(db), 1
    local function PlaceHeader(key, label)
        if reverse then Bags.ReverseSection(placed, sectionFrom, placedCount, anchor, stepX, columns) end
        sectionFrom = placedCount + 1
        local header = categoryHeaders[key]
        if not header then
            header = CreateCategoryHeader(frame, function()
                local sections = GetCollapsedSections()
                sections[key] = not sections[key] or nil
                Relayout(frame)
            end)
            categoryHeaders[key] = header
        end
        SetCategoryHeader(header, label, collapsedSections[key])
        header:SetWidth(gridWidth)
        header:ClearAllPoints()
        header:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 4 + row * stepY + gapCount * BAG_GAP + headerSpace)
        header:Show()
        visibleHeaders[key] = true
        headerSpace = headerSpace + CATEGORY_HEADER_HEIGHT
    end
    -- The bottom sections keep their usual gap outside the category views.
    local shownBags = {}
    for _, bagID in ipairs(ExtraBags()) do
        local e = Extra(bagID, frame)
        local shown = ShownSlots(bagID)
        e.shownSlots = shown
        local folded = categorized and collapsedSections[bagID]
        local expanded = not folded
        if e.probe then
            for slot, b in pairs(e.probe) do
                if (e.window or not expanded or slot > shown) and b:IsShown()
                    and not (InCombatLockdown() and b:IsProtected()) then b:Hide() end
            end
        end
        if (expanded and not e.window and bagID ~= ReagentID()) or (e.window and e.window:GetBagSize() ~= shown) then
            QueueBackpackExtraSync()
        end
        if expanded then
            -- The same order as Blizzard's bags: the last slot bottom right.
            for slot = shown, 1, -1 do
                local b = e.buttons[slot] or (not e.window and e.probe and e.probe[slot])
                if b and e.probe and e.probe[slot] == b then Bags.UpdateReagentProbe(b, bagID, slot) end
                if b and InCombatLockdown() and b:IsProtected() then
                    -- (Blizzard's button can't move in a fight: it keeps its place, its slot is counted)
                    col = col + 1
                    if col == columns then col, row = 0, row + 1 end
                elseif b then
                    b:SetSize(w, h)
                    PlaceSlot(b)
                    b:Show()
                else
                    extraButtonsDeferred = true
                end
            end
        end
        if e.holder:IsShown() ~= expanded then
            if InCombatLockdown() and e.holder:IsProtected() then
                extraButtonsDeferred = true
            else
                e.holder:SetShown(expanded)
            end
        end
        FinishRow()
        if categorized then
            PlaceHeader(bagID, ExtraSectionLabel(bagID))
        else
            gapCount = gapCount + 1
        end
        if bagID == highlightedExtraBag then UpdateExtraBagHighlight(bagID, e) end
        shownBags[bagID] = true
    end
    HideExtras(shownBags)
    for _, section in ipairs(soulBags) do
        for _, button in ipairs(section.items) do
            if not SetCategorySlotCollapsed(button, categorized and collapsedSections[section.key]) then PlaceSlot(button) end
        end
        FinishRow()
        if categorized then PlaceHeader(section.key, section.label) else gapCount = gapCount + 1 end
    end
    if categorized then
        for _, key in ipairs(order) do
            local group = groups[key]
            if #group > 0 then
                for _, button in ipairs(group) do
                    if not SetCategorySlotCollapsed(button, collapsedSections[key]) then PlaceSlot(button) end
                end
                FinishRow()
                PlaceHeader(key, setNames[key] or CATEGORY_NAMES[key])
            end
        end
    else
        -- Hide 2FA Bag Slots leaves the spare room at the bottom right in a plain grid.
        if h2fa and not gaps then col = (columns - #items % columns) % columns end
        for _, button in ipairs(items) do
            SetCategorySlotCollapsed(button, false)
            local bag = button:GetBagID()
            if gaps and prevBag and bag ~= prevBag then
                FinishRow()
                gapCount = gapCount + 1
            end
            PlaceSlot(button)
            prevBag = bag
        end
    end
    for key, header in pairs(categoryHeaders) do if not visibleHeaders[key] then header:Hide() end end
    local rows = row + (col > 0 and 1 or 0)
    if reverse and not categorized then Bags.Reverse(placed, placedCount, anchor, stepX, h, columns) end

    local width = gridWidth + frame:GetPaddingWidth()
    local height = rows * h + math_max(0, rows - 1) * ITEM_SPACING + gapCount * BAG_GAP + headerSpace
        + frame:GetPaddingHeight() + frame:CalculateExtraHeight()
    frame:SetSize(width, height)
    if NineSliceUtil and NineSliceUtil.UpdateCornerCropping then NineSliceUtil.UpdateCornerCropping(frame, height) end
    lastLayoutColumns, lastLayoutGaps, lastLayoutSecured = columns, gaps, secured
    layingOut = false
    Bags.AddSlots.Place(frame, wanted)
    Bags:PlaceBagButtons()
end

--------------------------------------------------
-- 3b. BLIZZARD'S ITEM BUTTONS IN THE TWO EXTRA SECTIONS
-- Each source window updates its own buttons. Blizzard's click handler uses their original bag
-- and slot IDs. The buttons go back to their source before it uses them for another bag.
--------------------------------------------------
Bags.adopted = {}   -- Blizzard's button -> the bag window it belongs to

-- false when a button can't move now (the caller leaves the window usable)
function Bags.AdoptExtraButtons(frame)
    local id, combined = frame:GetID(), Combined()
    if not (id and combined and type(frame.Items) == "table") then return false end
    local e = extras[id]
    if InCombatLockdown() then
        for _, button in ipairs(frame.Items) do
            if button:IsProtected() and (Bags.adopted[button] ~= frame or button.fuiBagSection ~= e) then return false end
        end
    end
    e = e or Extra(id, combined)
    e.window = frame
    local changed = false
    for _, button in ipairs(frame.Items) do
        if Bags.adopted[button] ~= frame or button.fuiBagSection ~= e then
            button:SetParent(e.holder)
            Bags.adopted[button] = frame
            button.fuiBagSection = e
        end
        local slot = button:GetID()
        if e.buttons[slot] ~= button then
            e.buttons[slot] = button
            changed = true
        end
    end
    if changed and not layingOut and combined:IsShown() then Bags.SafeRelayout(combined) end
    return true
end

-- a layout that fails ends (it would block every later one) and never stops the caller
function Bags.SafeRelayout(frame)
    local ok, err = pcall(Relayout, frame)
    if not ok then
        layingOut = false
        ns.LogError("Bags layout", err)
    end
end

-- every button taken from this window (all of them: owner nil) back to it
function Bags.ReturnExtraButtons(owner)
    local changed, done = false, true
    for button, from in pairs(Bags.adopted) do
        if not owner or from == owner then
            local e = button.fuiBagSection
            if e.window == from then e.window = nil end
            local slot = button:GetID()
            if e.buttons[slot] == button then
                e.buttons[slot] = nil
                changed = true
            end
            if InCombatLockdown() and button:IsProtected() then
                done = false
            else
                button:SetParent(from)
                button.fuiBagSection = nil
                Bags.adopted[button] = nil
            end
        end
    end
    local combined = Combined()
    if changed and combined and combined:IsShown() and not layingOut then Relayout(combined) end
    return done
end

-- once per Blizzard bag window: its buttons come home before it builds its slots again, and a
-- layout of its own (it anchors them to itself) is followed by the backpack's
function Bags.HookBagWindow(frame)
    if frame.fuiBagHooked or not (frame.UpdateItemSlots and frame.UpdateItemLayout) then return end
    frame.fuiBagHooked = true
    hooksecurefunc(frame, "ClearItems", function(f) Bags.ReturnExtraButtons(f) end)
    hooksecurefunc(frame, "UpdateItemLayout", function(f)
        for _, from in pairs(Bags.adopted) do
            if from == f then
                local combined = Combined()
                if combined and combined:IsShown() and not layingOut then Relayout(combined) end
                return
            end
        end
    end)
end

local function ExtraLayoutChanged(event)
    if event == "PLAYER_REGEN_ENABLED" and extraButtonsDeferred then return true end
    if not (Bags:IsCombined() and LayoutWanted()) then return true end
    local db = GetDb()
    local columns = LayoutColumns(db)
    local secured = not IsAccountSecured or IsAccountSecured()
    if columns ~= lastLayoutColumns or (db.bagGaps == true) ~= lastLayoutGaps or secured ~= lastLayoutSecured then
        return true
    end
    return ExtraSectionChanged(KeyringID(), KeyringWanted())
        or ExtraSectionChanged(ReagentID(), ReagentWanted())
end

--------------------------------------------------
-- 1b. HIDE 2FA BAG SLOTS
-- That addon hides the padlocked slots of an account without an authenticator and lays the rest out
-- again with Blizzard's grid, on the same Blizzard calls FlareUI's layout follows. With a FlareUI
-- layout on, FlareUI's grid leaves the locked slots out (hidden, as that addon wants), follows its
-- Compact View order (empty slots first from the bottom right, so the filled ones read first), and
-- its hooks run after that addon's, so FlareUI's grid is the one shown.
--------------------------------------------------
Bags.H2FA = {}

function Bags.H2FA.On()
    local H2FA = Bags.H2FA
    if H2FA.loaded == nil then
        H2FA.loaded = C_AddOns.IsAddOnLoaded("Hide2FABagSlots") and true or false
    end
    return H2FA.loaded
end

function Bags.H2FA.Compact()
    local db = _G.Hide2FABagSlotsDB
    return type(db) == "table" and db.compact == true
end

-- the slots without the locked ones (hidden here too: its own hide may come after this layout)
function Bags.H2FA.Items(items)
    local kept, filled = {}, {}
    local compact = Bags.H2FA.Compact()
    for _, button in ipairs(items) do
        if button.IsExtended and button:IsExtended() then
            if button:IsShown() and not (InCombatLockdown() and button:IsProtected()) then button:Hide() end
            categoryHidden[button] = nil
        elseif compact and C_Container.GetContainerItemInfo(button:GetBagID(), button:GetID()) then
            filled[#filled + 1] = button
        else
            kept[#kept + 1] = button
        end
    end
    for _, button in ipairs(filled) do kept[#kept + 1] = button end
    return kept
end

--------------------------------------------------
-- 1c. COMBINE EMPTY SLOTS
-- The backpack shows its filled slots, then a single empty slot with the number of free slots on it;
-- the other empty slots hide. Off (or the Gamepad UI), every slot shows again. Blizzard's item buttons
-- are no secure template, but a hide or show is skipped in a fight if one turns out protected: the
-- layout runs again as the fight ends. A slot filled or emptied re-lays the grid (BAG_UPDATE_DELAYED).
--------------------------------------------------
Bags.combineHidden = setmetatable({}, { __mode = "k" })
Bags.combinedEmpty = setmetatable({}, { __mode = "k" })

function Bags.CombineEmptyOn()
    local db = GetDb()
    return db and db.bagCombineEmpty and not ns.IsGamepadUI() or false
end

local function SetSlotShown(button, shown)
    if categoryHidden[button] then
        if shown then
            -- The category pass decides whether this eligible slot should be visible.
            Bags.combineHidden[button] = nil
            return
        end
        -- An empty slot now hidden by Combine Empty Slots no longer belongs to its old fold.
        categoryHidden[button] = nil
        Bags.combineHidden[button] = true
    end
    if button:IsShown() == shown then return end
    if InCombatLockdown() and button:IsProtected() then return end
    button:SetShown(shown)
    Bags.combineHidden[button] = (not shown) or nil
end

local function SetFreeCount(button, count)
    Bags.combinedEmpty[button] = count and true or nil
    local label = button.fuiFreeCount
    if not count then
        if label then label:Hide() end
        return
    end
    if not label then
        local layer = CreateFrame("Frame", nil, button)
        layer:SetAllPoints(button)
        layer:SetFrameLevel(button:GetFrameLevel() + 10)
        label = layer:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        label:SetPoint("CENTER")
        button.fuiFreeCount = label
    end
    label:SetText(count)
    label:Show()
end

function Bags.CombineEmpty(items, combine)
    if not combine then
        -- back to every slot: the ones this hid show again
        for button in pairs(Bags.combineHidden) do SetSlotShown(button, true) end
        for button in pairs(Bags.combinedEmpty) do SetFreeCount(button, nil) end
        return items
    end
    -- one slot per kind of bag: a soul, herb or other special bag's free slots take only
    -- its own items, so they are counted apart (with them in one count, the slot shown could be one nothing
    -- else fits in). The padlocked slots of an account without an authenticator are no free slots.
    local kept, spares, families = {}, {}, {}
    local secured = not IsAccountSecured or IsAccountSecured()
    local function FamilyOf(bag)
        local family = families[bag]
        if family == nil then
            family = C_Container.GetContainerNumFreeSlots and select(2, C_Container.GetContainerNumFreeSlots(bag)) or 0
            families[bag] = family
        end
        return family
    end
    local order = {}
    for _, button in ipairs(items) do
        local bag = button:GetBagID()
        local info = C_Container.GetContainerItemInfo(bag, button:GetID())
        if info then
            kept[#kept + 1] = button
            SetSlotShown(button, true)
            SetFreeCount(button, nil)
        elseif not secured and button.IsExtended and button:IsExtended() then
            SetSlotShown(button, false)
            SetFreeCount(button, nil)
        else
            local family = FamilyOf(bag)
            local spare = spares[family]
            if spare then
                spare.free = spare.free + 1
                SetSlotShown(button, false)
                SetFreeCount(button, nil)
            else
                spares[family] = { button = button, free = 1 }
                order[#order + 1] = family
            end
        end
    end
    -- the special bags' first, the ordinary free slots last, where they always were
    table_sort(order, function(a, b)
        if (a == 0) ~= (b == 0) then return b == 0 end
        return a < b
    end)
    for _, family in ipairs(order) do
        local spare = spares[family]
        kept[#kept + 1] = spare.button
        SetSlotShown(spare.button, true)
        SetFreeCount(spare.button, spare.free)
    end
    return kept
end

--------------------------------------------------
-- 1d. AUTO OPEN CONTAINERS
-- Clams, loot bags and opened lockboxes in your bags open themselves, one at a time with a short wait,
-- out of a fight and while no vendor, bank, mail, trade, auction or loot window is open. One that
-- doesn't open (a locked box) is left alone for the session, so it can't loop.
--------------------------------------------------
Bags.AutoOpen = { skip = {} }

function Bags.AutoOpen.Blocked()
    if InCombatLockdown() or UnitIsDeadOrGhost("player") or ns.IsGamepadUI() then return true end
    -- a spell or kit waiting for its item, something on the cursor or a cast: the use would be taken for that
    if (SpellIsTargeting and SpellIsTargeting()) or (SpellCanTargetItem and SpellCanTargetItem()) or GetCursorInfo()
        or UnitCastingInfo("player") or UnitChannelInfo("player") then return true end
    -- a loot open in FlareUI's loot window, where Blizzard's LootFrame stays hidden
    if ns.LootWindow and ns.LootWindow.looting then return true end
    for _, name in ipairs({ "MerchantFrame", "BankFrame", "MailFrame", "TradeFrame", "AuctionHouseFrame",
                            "AuctionFrame", "GuildBankFrame", "LootFrame" }) do
        local frame = _G[name]
        if frame and frame:IsShown() then return true end
    end
    return false
end

function Bags.AutoOpen.Next()
    local A = Bags.AutoOpen
    local db = GetDb()
    if A.busy or not (db and db.bagAutoOpen) or A.Blocked() then return end
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local id = info and info.itemID
            if id and info.hasLoot == true and not info.isLocked and not A.skip[id] then
                A.busy = true
                local count = info.stackCount or 1
                C_Container.UseContainerItem(bag, slot)
                C_Timer.After(0.6, function()
                    A.busy = nil
                    local after = C_Container.GetContainerItemInfo(bag, slot)
                    -- still there, as many: it didn't open
                    if after and after.itemID == id and (after.stackCount or 1) >= count then A.skip[id] = true end
                    C_Timer.After(0.2, Bags.AutoOpen.Next)
                end)
                return
            end
        end
    end
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
    -- the bag's own tooltip; an empty slot shows none (no "Equip Container")
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
    local show = db and db.bagButtons and Bags:IsCombined() and not Bags:GetOtherBagAddon() and not GamepadUI()
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
--------------------------------------------------
-- edge size and outset per border: each art's bright band lands on the slot's edge
local BORDERS = { thin = { "FlareUI Thin", 8, 3 }, thick = { "FlareUI Thick", 16, 2 } }
Bags.ITEM_BORDERS = BORDERS

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
                    local reagent = Enum.ItemReagentSubclass and Enum.ItemReagentSubclass.Reagent
                    dimmed = classID ~= classes.Tradegoods
                        and not (reagent and classID == classes.Reagent and subclassID == reagent)
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
    -- Item Level (bottom left) and Uncollected Appearance (top right, across from the junk coin)
    ov.ilvl = ov:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    ov.ilvl:SetPoint("BOTTOMLEFT", 2, 2)
    ov.ilvl:Hide()
    ov.eye = ov:CreateTexture(nil, "OVERLAY", nil, 7)
    ov.eye:SetAtlas("transmog-icon-hidden")
    ov.eye:SetSize(14, 14)
    ov.eye:SetPoint("TOPRIGHT", -1, -1)
    ov.eye:Hide()
    -- BoE Text, top left (the junk coin's corner: grey items don't bind), and Plain Empty Slots:
    -- Blizzard's plain slot over an empty one, so the combined backpack's slots don't show each bag's
    -- picture (drawn on FlareUI's overlay: Blizzard's buttons are left alone)
    ov.boe = ov:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    ov.boe:SetPoint("TOPLEFT", 2, -2)
    ov.boe:SetText(L["BoE"])
    ov.boe:Hide()
    ov.plain = ov:CreateTexture(nil, "BACKGROUND")
    ov.plain:SetAllPoints()
    ov.plain:SetAtlas("bags-item-slot64")
    ov.plain:Hide()
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
        border.r = nil
    end
    if border.r ~= r or border.g ~= g or border.b ~= b then
        border.r, border.g, border.b = r, g, b
        border:SetBackdropBorderColor(r, g, b, 1)
    end
    ov.border:Show()
end

Bags.RARITY_FROM = Enum.ItemQuality and Enum.ItemQuality.Uncommon or 2
local function UpdateItemBorder(ov, db, quality, dimmed)
    local style = db.bagThickBorders and "thick" or "thin"
    -- Colour by Rarity (in Skin Item Slots; tweaks.bagRarity, on): green and better; off, every border bronze
    if quality and quality >= Bags.RARITY_FROM and not dimmed and db.bagRarity ~= false then
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
            if db and db.bagSkinSlots ~= false and wasDimmed ~= dimmed then
                UpdateItemBorder(ov, db, info and info.quality, dimmed)
            end
        end
    end
end

-- ITEM LEVEL AND UNCOLLECTED APPEARANCE: read once per item link, the
-- appearances again when the collection changes (Bags:Init). Item level on weapons and armour only,
-- not on shirts and tabards (level 1). An appearance counts as collected when this item's source or
-- any other with the same look is; the eye shows only where this character could learn it.
local itemLevels, uncollected = {}, {}
function Bags.ForgetAppearances() wipe(uncollected) end

local function ItemLevelOf(link)
    local level = itemLevels[link]
    if level == nil then
        local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(link)
        level = false
        if classID == Enum.ItemClass.Weapon or classID == Enum.ItemClass.Armor then
            local ok, value = pcall(C_Item.GetDetailedItemLevelInfo, link)
            if not (ok and type(value) == "number") then return nil end   -- (not loaded yet: asked again)
            if value > 1 then level = value end
        end
        itemLevels[link] = level
    end
    return level or nil
end
Bags.ItemLevelOf = ItemLevelOf

-- only weapons and armour worn where it shows can have an appearance; Forever's appearance lookup
-- answers for anything (potions, scrolls), so the item's kind is checked first
local NO_APPEARANCE = { [""] = true, INVTYPE_NECK = true, INVTYPE_FINGER = true, INVTYPE_TRINKET = true,
    INVTYPE_BAG = true, INVTYPE_QUIVER = true, INVTYPE_AMMO = true, INVTYPE_RELIC = true, INVTYPE_NON_EQUIP_IGNORE = true }
local function Uncollected(link)
    local known = uncollected[link]
    if known ~= nil then return known end
    local _, _, _, equipLoc, _, classID = C_Item.GetItemInfoInstant(link)
    if not (classID == 2 or classID == 4) or NO_APPEARANCE[equipLoc or ""] then   -- 2 weapon, 4 armour
        uncollected[link] = false
        return false
    end
    local T = C_TransmogCollection
    if not (T and T.GetItemInfo) then return false end
    local ok, _, sourceID = pcall(T.GetItemInfo, link)
    if not (ok and sourceID) then
        uncollected[link] = false
        return false
    end
    local okS, source = pcall(T.GetSourceInfo, sourceID)
    local okA, appearance = pcall(T.GetAppearanceInfoBySource, sourceID)
    if (okS and source and source.isCollected) or (okA and appearance and appearance.appearanceIsCollected) then
        uncollected[link] = false
        return false
    end
    local okC, hasData, canCollect = pcall(T.PlayerCanCollectSource, sourceID)
    if not okC or hasData == false then return false end   -- (asked again next time)
    known = canCollect and true or false
    uncollected[link] = known
    return known
end
Bags.Uncollected = Uncollected

local function ShowItemLevel(ov, level, quality)
    ov.ilvl:SetText(level)
    local r, g, b = C_Item.GetItemQualityColor(quality or 1)
    ov.ilvl:SetTextColor(r or 1, g or 1, b or 1)
    ov.ilvl:Show()
end

-- what needs the item's data: its level, its appearance, its BoE text
local BIND_ON_EQUIP = Enum.ItemBind and Enum.ItemBind.OnEquip or 2
function Bags.IsBoE(link)
    -- GetItemInfo's 14th value, after pcall's status (nil if it failed): no closure per item
    return select(15, pcall(C_Item.GetItemInfo, link)) == BIND_ON_EQUIP
end
local function ShowItemData(ov, db, bagID, slotID, link, quality, isBound)
    if db.bagItemLevel then
        local level = ItemLevelOf(link)
        if level then ShowItemLevel(ov, level, quality) end
    end
    if db.bagUncollected and Uncollected(link) then ov.eye:Show() end
    if db.bagBoE and not isBound and Bags.IsBoE(link) then
        Bags.StyleBoE(ov.boe, db)
        ov.boe:Show()
    end
end

local function UpdateButton(button, db)
    local bagID, slotID = button:GetBagID(), button:GetID()
    local info = bagID and slotID and C_Container.GetContainerItemInfo(bagID, slotID)
    Bags.DecorateButton(button, db, info, bagID, slotID)
end

-- Bag Items font (Quality of Life > Fonts): the text on the bag icons, the stack count and
-- the cooldown's number. Default ("") keeps Blizzard's; going back to Default restores the font object
-- FlareUI replaced.
local blizzardFont = {}   -- font string -> Blizzard's font object
local function StyleIconText(fs, font)
    if not fs then return end
    local face = font and font.face or ""
    if face == "" then
        fs.fuiFont = nil
        local object = blizzardFont[fs]
        if object then
            fs:SetFontObject(object)
            blizzardFont[fs] = nil
        end
        return
    end
    if not blizzardFont[fs] then blizzardFont[fs] = fs:GetFontObject() or NumberFontNormal end
    local flags = font.flags or "OUTLINE"
    if flags == "NONE" then flags = "" end
    local size = font.size or 14
    -- the file, not the face: a Global face changes file with the Global Font
    local path = ns.GetFontPath(face)
    -- the same look on the same font (nothing reset it): nothing to do
    local c = fs.fuiFont
    if c and c.path == path and c.size == size and c.flags == flags and c.sh == font.enableShadow
        and c.x == font.shadowX and c.y == font.shadowY and c.got == fs:GetFont() then return end
    ns.SetFont(fs, path, size, flags)
    ns.ApplyShadow(fs, font)
    fs.fuiFont = { path = path, size = size, flags = flags, sh = font.enableShadow, x = font.shadowX, y = font.shadowY, got = fs:GetFont() }
end
Bags.StyleIconText = StyleIconText   -- (the loot window's item levels, LootWindow.lua)
-- the BoE mark (bags and loot window): the Item Level font, always green (a font object brings its own colour)
function Bags.StyleBoE(fs, db)
    StyleIconText(fs, db.bagItemLevelFont)
    fs:SetTextColor(0.12, 1, 0.12)
end
-- the money at the bags' foot (Bags and Looting > Fonts > Gold): Blizzard's gold, silver and copper
-- texts on the combined bags and the backpack; their widths follow the new text
function Bags.StyleMoney()
    local db = GetDb()
    if not db then return end
    for _, frame in ipairs({ _G.ContainerFrameCombinedBags, _G.ContainerFrame1 }) do
        local money = frame and (frame.MoneyFrame or _G[(frame:GetName() or "") .. "MoneyFrame"])
        if money then
            for _, key in ipairs({ "GoldButton", "SilverButton", "CopperButton" }) do
                local button = money[key]
                local text = button and (button.Text or (button.GetFontString and button:GetFontString()))
                if text then StyleIconText(text, db.bagMoneyFont) end
            end
            if money:IsVisible() and MoneyFrame_UpdateMoney then pcall(MoneyFrame_UpdateMoney, money) end
        end
    end
end

-- Your gold on other characters: with Syndicator installed, pointing at the money at the bags' foot
-- lists the gold of your characters on this realm (and connected ones), from Syndicator's saved data,
-- as Baganator does with it (Syndicator only keeps the data; the list is Baganator's). Blizzard's own
-- scripts still run first (a click still opens the currency tab); nothing shows without Syndicator.
Bags.GoldList = {}

function Bags.GoldList.Show(owner)
    local api = _G.Syndicator and _G.Syndicator.API
    if not (api and api.GetAllCharacters and api.GetCharacter and (not api.IsReady or api.IsReady())) then return end
    local util = _G.Syndicator.Utilities
    local realms
    if util and util.GetConnectedRealms then
        realms = {}
        for _, r in ipairs(util.GetConnectedRealms() or {}) do realms[r] = true end
        if not next(realms) then realms = nil end
    end
    local lines, total = {}, 0
    for _, fullName in ipairs(api.GetAllCharacters() or {}) do
        local data = api.GetCharacter(fullName)
        local d = data and data.details
        local shown = d and (d.show and d.show.gold or (not d.show and d.hidden ~= true))
        if shown and (not realms or realms[d.realmNormalized]) and type(data.money) == "number" then
            local name = d.character or fullName
            local colour = d.className and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[d.className]
            if colour and colour.colorStr then name = "|c" .. colour.colorStr .. name .. "|r" end
            lines[#lines + 1] = { name = name, money = data.money }
            total = total + data.money
        end
    end
    if api.GetAllGuilds and api.GetGuild then
        for _, fullName in ipairs(api.GetAllGuilds() or {}) do
            local data = api.GetGuild(fullName)
            local d = data and data.details
            if d and d.show and d.show.gold and (not realms or realms[d.realmNormalized]) and type(data.money) == "number" then
                lines[#lines + 1] = { name = "<" .. (d.guild or fullName) .. ">", money = data.money }
                total = total + data.money
            end
        end
    end
    if #lines == 0 then return end
    table_sort(lines, function(a, b) return a.money > b.money end)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:AddDoubleLine(L["Gold on This Realm"], GetMoneyString(total, true), nil, nil, nil, 1, 1, 1)
    GameTooltip:AddLine(" ")
    for _, line in ipairs(lines) do
        GameTooltip:AddDoubleLine(line.name, GetMoneyString(line.money, true), 1, 1, 1, 1, 1, 1)
    end
    GameTooltip:Show()
    Bags.GoldList.owner = owner
end

function Bags.GoldList.Hide(owner)
    if Bags.GoldList.owner == owner then
        Bags.GoldList.owner = nil
        if GameTooltip:GetOwner() == owner then GameTooltip:Hide() end
    end
end

-- the gold, silver and copper of the combined bags' and the backpack's money lines (hooked once)
function Bags.GoldList.Hook()
    for _, frame in ipairs({ _G.ContainerFrameCombinedBags, _G.ContainerFrame1 }) do
        local money = frame and (frame.MoneyFrame or _G[(frame:GetName() or "") .. "MoneyFrame"])
        if money and not money.fuiGoldList then
            money.fuiGoldList = true
            for _, key in ipairs({ "GoldButton", "SilverButton", "CopperButton" }) do
                local button = money[key]
                if button and button.HookScript then
                    button:HookScript("OnEnter", function(b) pcall(Bags.GoldList.Show, b) end)
                    button:HookScript("OnLeave", function(b) Bags.GoldList.Hide(b) end)
                end
            end
        end
    end
end

-- the free bag slots on the backpack button (Bags and Looting > Fonts > Free Bag Slots)
function Bags.StyleFreeSlots()
    local db = GetDb()
    local backpack = _G.MainMenuBarBackpackButton
    if db and backpack and backpack.FreeSlots then StyleIconText(backpack.FreeSlots, db.bagFreeSlotsFont) end
end
function Bags.StyleIconTexts(button, db)
    StyleIconText(button.Count, db.bagItemFont)
    local cooldown = button.Cooldown or (button.GetName and button:GetName() and _G[button:GetName() .. "Cooldown"])
    if cooldown and cooldown.GetCountdownFontString then
        local fs = cooldown:GetCountdownFontString()
        StyleIconText(fs, db.bagItemFont)
        Bags.LiftCountdown(button, cooldown, fs)
    end
end

-- The cooldown numbers are drawn by the cooldown frame, under our slot overlay (border, junk coin,
-- item level), which would hide them. They move to a frame of ours made on the cooldown frame (shown
-- and hidden with it), above every slot's overlay so long ones can spill over the next slot.
function Bags.LiftCountdown(button, cooldown, fs)
    if not fs then return end
    local ov = overlays[button] or button.fuiOverlay
    local lift = button.fuiCountdownLift
    if not lift then
        lift = CreateFrame("Frame", nil, cooldown)
        lift:SetAllPoints(cooldown)
        button.fuiCountdownLift = lift
    end
    local level = (ov and ov:GetFrameLevel() or button:GetFrameLevel() + 2) + 1
    if lift:GetFrameLevel() ~= level then lift:SetFrameLevel(level) end
    if fs:GetParent() ~= lift then fs:SetParent(lift) end
end

-- info: the slot's item (C_Container's, or a settings preview's made-up one)
function Bags.DecorateButton(button, db, info, bagID, slotID)
    Bags.StyleIconTexts(button, db)
    local junk = db.bagJunkIcon
    local ov = GetOverlay(button)
    ov.itemDataDb = db
    local pending = ov.itemLoad
    if pending and (button.fuiSample or not info or pending.link ~= info.hyperlink
        or pending.bagID ~= bagID or pending.slotID ~= slotID or not (db.bagItemLevel or db.bagUncollected or db.bagBoE)
        or GetTime() - pending.requestedAt >= 5) then
        ov.itemLoad = nil
    end
    ov:Show()
    ov.junk:Hide()
    ov.ilvl:Hide()
    ov.eye:Hide()
    ov.boe:Hide()
    -- (the padlock of an account without an authenticator stays)
    local locked = not info and button.IsExtended and button:IsExtended() and IsAccountSecured and not IsAccountSecured()
    ov.plain:SetShown(db.bagPlainEmpty and not info and not locked or false)

    if not button.fuiSample then UpdateItemFilter(button, ov, bagID, slotID, info) end
    local quality = info and info.quality

    -- Skin Item Slots (tweaks.bagSkinSlots, on): off, Blizzard's own quality border stays and FlareUI
    -- draws none
    -- (the border is shown here or hidden, never hidden first and shown again)
    if db.bagSkinSlots ~= false then
        if button.IconBorder then button.IconBorder:SetAlpha(0) end
        UpdateItemBorder(ov, db, quality, dimmedIcons[button])
    else
        ov.border:Hide()
        if button.IconBorder then button.IconBorder:SetAlpha(1) end
    end

    if not info then return end
    if junk and quality == Enum.ItemQuality.Poor and not info.hasNoValue then ov.junk:Show() end
    if button.fuiSample then
        if db.bagItemLevel and info.sampleItemLevel then
            StyleIconText(ov.ilvl, db.bagItemLevelFont)
            ShowItemLevel(ov, info.sampleItemLevel, quality)
        end
        if db.bagUncollected and info.sampleUncollected then ov.eye:Show() end
    elseif (db.bagItemLevel or db.bagUncollected or db.bagBoE) and info.hyperlink then
        if db.bagItemLevel then StyleIconText(ov.ilvl, db.bagItemLevelFont) end
        local link = info.hyperlink
        if C_Item.IsItemDataCachedByID(info.itemID) then
            ov.itemLoad = nil
            ShowItemData(ov, db, bagID, slotID, link, quality, info.isBound)
        elseif not ov.itemLoad then
            -- One request per slot generation: an older A -> B -> A callback cannot clear or
            -- paint a newer request, even when the hyperlink happens to match again.
            local request = { link = link, bagID = bagID, slotID = slotID, requestedAt = GetTime() }
            ov.itemLoad = request
            local item = Item:CreateFromItemLink(link)
            item:ContinueOnItemLoad(function()
                if ov.itemLoad ~= request then return end
                ov.itemLoad = nil
                local now = C_Container.GetContainerItemInfo(bagID, slotID)
                if now and now.hyperlink == link and button:GetBagID() == bagID and button:GetID() == slotID then
                    ShowItemData(ov, ov.itemDataDb, bagID, slotID, link, now.quality, now.isBound)
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

--------------------------------------------------
-- 4b. CATEGORY FILTERS (Bags and Looting > Category Filters, off)
-- Off, Drawer or Buttons. Drawer: one button left of Blizzard's cleanup button, in the cleanup
-- button's own frame. A click opens a drawer upward: Quest Items, Equipment, Materials and
-- Consumables, the same buttons stacked. Picking one dims every other item (section 3,
-- UpdateItemFilter) and the button takes that category's icon with a gold edge. Right-click clears
-- the filter. Buttons: the four category buttons in a row left of the cleanup button, one click to
-- pick, a click on the lit one clears; only in the combined backpack, and only while the search box
-- keeps at least Filter.MIN_SEARCH beside them; otherwise (narrow window, separate bags) the drawer.
-- Off, the cleanup button and the search box go back to Blizzard's spots.
-- The saved value: "off" | "drawer" | "buttons"; a saved true (the older switch) reads as "drawer".
--------------------------------------------------
local Filter = {
    W = 28, H = 26,         -- Blizzard's cleanup button
    ICON_W = 17, ICON_H = 16,   -- the broom's area inside its frame
    GAP = 2,                -- between the filter and cleanup buttons
    STACK = -5,             -- between the drawer's buttons: their frames' clear edges overlap, a sliver apart
    SORT_X = -9, SORT_Y = -34,  -- Blizzard's spot for the cleanup button (ContainerFrame.lua)
    SEARCH_GAP = 6,         -- the search box's right art reaches past its edge
    MIN_SEARCH = 120,       -- Buttons: the search box keeps at least this width, else the drawer (about 12 letters)
    MAIN_ICON = "Interface\\Icons\\INV_Misc_Spyglass_03",
    -- shapes that read at the small size: a quest scroll, a sword, a hammer, a green potion
    CATEGORIES = {
        { key = "quest", icon = "Interface\\Icons\\INV_Scroll_03", label = L["Quest Items"] },
        { key = "equipment", icon = "Interface\\Icons\\INV_Sword_27", label = L["Equipment"] },
        { key = "resources", icon = "Interface\\Icons\\INV_Hammer_20", label = L["Materials"] },
        { key = "consumables", icon = "Interface\\Icons\\INV_Potion_93", label = L["Consumables"] },
    },
    GOLD = { 1, 0.82, 0.3 },
    bases = {},             -- bag frame -> Blizzard's search box spot { x, y, width }
}
Bags.Filter = Filter

-- "off" or "buttons": Bag View's Category Filters, a row by the search box where there's room, else
-- the drawer (Filter.Place). "drawer" stays a mode for the narrow case.
function Filter.Mode()
    return Bags.View() == "filters" and "buttons" or "off"
end

function Filter.On()
    return Filter.Mode() ~= "off" and not Bags:GetOtherBagAddon() and not GamepadUI()
        and C_Container.GetContainerItemQuestInfo and C_Item.GetItemInventoryTypeByID and true or false
end

-- a button in the cleanup button's own frame, the icon over the broom in its middle
function Filter.NewButton(parent, iconFile)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(Filter.W, Filter.H)
    b:SetNormalAtlas("bags-button-autosort-up")
    b:SetPushedAtlas("bags-button-autosort-down")
    -- the same look as the cleanup button: the icon only fills the broom's area, rounded like it, so
    -- the frame's dark rim shows all round
    b.icon = b:CreateTexture(nil, "OVERLAY")
    b.icon:SetSize(Filter.ICON_W, Filter.ICON_H)
    b.icon:SetPoint("CENTER", 0, 0)
    b.icon:SetTexture(iconFile)
    b.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    local mask = b:CreateMaskTexture()
    mask:SetAtlas("UI-HUD-ActionBar-IconFrame-Mask", TextureKitConstants and TextureKitConstants.IgnoreAtlasSize)
    mask:SetAllPoints(b.icon)
    b.icon:AddMaskTexture(mask)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local hl = b:GetHighlightTexture()
    hl:ClearAllPoints()
    hl:SetPoint("CENTER")
    hl:SetSize(24, 23)
    -- pressed: the icon sinks with the frame
    b:SetScript("OnMouseDown", function(self) self.icon:SetPoint("CENTER", 1, -1) end)
    b:SetScript("OnMouseUp", function(self) self.icon:SetPoint("CENTER", 0, 0) end)
    -- the gold edge while its filter is on: Blizzard's item border glow, softly
    b.edge = b:CreateTexture(nil, "OVERLAY", nil, 2)
    b.edge:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    b.edge:SetBlendMode("ADD")
    b.edge:SetPoint("CENTER")
    b.edge:SetSize(Filter.W * 1.75, Filter.H * 1.75)
    b.edge:SetVertexColor(unpack(Filter.GOLD))
    b.edge:SetAlpha(0.75)
    b.edge:Hide()
    return b
end

function Filter.Close()
    if Filter.drawer then Filter.drawer:Hide() end
end

function Filter.Open()
    if not Filter.drawer then return end
    for _, b in ipairs(Filter.drawer.buttons) do b.edge:SetShown(b.key == itemFilter) end
    Filter.drawer:Show()
end

-- the main button: the active category's icon with the gold edge, else the spyglass
function Filter.Paint()
    local main = Filter.main
    if not main then return end
    local icon = Filter.MAIN_ICON
    for _, c in ipairs(Filter.CATEGORIES) do if c.key == itemFilter then icon = c.icon end end
    main.icon:SetTexture(icon)
    main.edge:SetShown(itemFilter ~= nil)
    -- Buttons: the picked one lit
    if Filter.row then
        for _, b in ipairs(Filter.row.buttons) do b.edge:SetShown(b.key == itemFilter) end
    end
end

function Filter.Set(mode)
    itemFilter = mode
    Filter.Paint()
    RefreshItemFilter()
end

function Filter.Tooltip(main)
    -- as the cleanup button's: a white title, yellow text (the active category in green)
    GameTooltip:SetOwner(main)
    GameTooltip_SetTitle(GameTooltip, L["Filter Items"], HIGHLIGHT_FONT_COLOR)
    for _, c in ipairs(Filter.CATEGORIES) do
        if c.key == itemFilter then GameTooltip_AddColoredLine(GameTooltip, c.label, GREEN_FONT_COLOR) end
    end
    GameTooltip_AddNormalLine(GameTooltip, L["Left-click: pick a category. Right-click: clear the filter."])
    GameTooltip:Show()
end

function Filter.Create(frame)
    local main = Filter.NewButton(frame, Filter.MAIN_ICON)
    main:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    main:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            Filter.Close()
            if itemFilter then Filter.Set(nil) end
        elseif Filter.drawer:IsShown() then
            Filter.Close()
        else
            Filter.Open()
        end
        if GameTooltip:IsOwned(self) then Filter.Tooltip(self) end
    end)
    main:SetScript("OnEnter", Filter.Tooltip)
    main:SetScript("OnLeave", GameTooltip_Hide)
    main:SetScript("OnHide", Filter.Close)
    Filter.main = main

    -- the drawer: the category buttons stacked upward from the main one, nothing round them
    local n = #Filter.CATEGORIES
    local drawer = CreateFrame("Frame", nil, main)
    drawer:SetSize(Filter.W, n * Filter.H + (n - 1) * Filter.STACK)
    drawer:SetPoint("BOTTOM", main, "TOP", 0, Filter.STACK)
    drawer:SetFrameStrata("DIALOG")
    drawer:Hide()
    drawer.buttons = {}
    for i, c in ipairs(Filter.CATEGORIES) do
        local b = Filter.NewButton(drawer, c.icon)
        b.key = c.key
        b:SetPoint("BOTTOM", drawer, "BOTTOM", 0, (i - 1) * (Filter.H + Filter.STACK))
        b:SetScript("OnClick", function()
            Filter.Close()
            Filter.Set(itemFilter ~= c.key and c.key or nil)
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip_SetTitle(GameTooltip, c.label, HIGHLIGHT_FONT_COLOR)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", GameTooltip_Hide)
        drawer.buttons[i] = b
    end
    Filter.drawer = drawer
    -- a click anywhere else closes the drawer
    local watch = CreateFrame("Frame", nil, drawer)
    watch:SetScript("OnEvent", function()
        if not (drawer:IsMouseOver() or main:IsMouseOver()) then Filter.Close() end
    end)
    drawer:SetScript("OnShow", function() watch:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
    drawer:SetScript("OnHide", function() watch:UnregisterEvent("GLOBAL_MOUSE_DOWN") end)

    -- Buttons: the same category buttons in a row, left to right, the last one beside the
    -- cleanup button. A click picks that category, a click on the lit one (or a right-click) clears.
    local row = CreateFrame("Frame", nil, frame)
    row:SetSize(n * Filter.W + (n - 1) * Filter.GAP, Filter.H)
    row:Hide()
    row.buttons = {}
    for i, c in ipairs(Filter.CATEGORIES) do
        local b = Filter.NewButton(row, c.icon)
        b.key = c.key
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                if itemFilter then Filter.Set(nil) end
            else
                Filter.Set(itemFilter ~= c.key and c.key or nil)
            end
            if GameTooltip:IsOwned(self) then self:GetScript("OnEnter")(self) end
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self)
            GameTooltip_SetTitle(GameTooltip, c.label, HIGHLIGHT_FONT_COLOR)
            if itemFilter == c.key then GameTooltip_AddNormalLine(GameTooltip, L["Click again to clear the filter."]) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", GameTooltip_Hide)
        row.buttons[i] = b
    end
    Filter.row = row
    Filter.Paint()
end

-- the row sized and laid out like the cleanup button (w, h), right edge just left of it
function Filter.LayoutRow(sort, w, h)
    local row = Filter.row
    local n = #row.buttons
    row:SetSize(n * w + (n - 1) * Filter.GAP, h)
    row:ClearAllPoints()
    row:SetPoint("TOPRIGHT", sort, "TOPLEFT", -Filter.GAP, 0)
    for i, b in ipairs(row.buttons) do
        b:SetSize(w, h)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", row, "TOPLEFT", (i - 1) * (w + Filter.GAP), 0)
    end
end

-- the cleanup button and the search box back where Blizzard put them, and the button away
function Filter.Restore()
    local search, sort = _G.BagItemSearchBox, _G.BagItemAutoSortButton
    local frame = Filter.moved
    local base = frame and Filter.bases[frame]
    if frame and search and search:GetParent() == frame and base then
        search:ClearAllPoints()
        search:SetPoint("TOPLEFT", frame, "TOPLEFT", base.x, base.y)
        search:SetWidth(base.width)
    end
    if frame and sort and sort:GetParent() == frame then
        sort:ClearAllPoints()
        sort:SetPoint("TOPRIGHT", frame, "TOPRIGHT", Filter.SORT_X, Filter.SORT_Y)
    end
    Filter.moved = nil
    if Filter.main then Filter.main:Hide() end
    if Filter.row then Filter.row:Hide() end
end

-- searchUpdated: Blizzard just placed the search box and the cleanup button (their spots are read again)
function Filter.Place(frame, searchUpdated)
    local search, sort = _G.BagItemSearchBox, _G.BagItemAutoSortButton
    if not (frame and search and sort and search:GetParent() == frame and sort:GetParent() == frame) then return end
    if not Filter.On() or not (search:IsShown() and sort:IsShown()) then
        Filter.Restore()
        return
    end
    if searchUpdated or not Filter.bases[frame] then
        local point, rel, _, x, y = search:GetPoint(1)
        -- (Blizzard's own spots are TOPLEFT on the bag; anything else is left alone)
        if point ~= "TOPLEFT" or rel ~= frame or search:GetNumPoints() > 1 then Filter.Restore() return end
        if Filter.moved == frame and not searchUpdated then return end
        Filter.bases[frame] = { x = x, y = y, width = search:GetWidth() }
    end
    local base = Filter.bases[frame]
    -- the cleanup button in Blizzard's spot, the filter button just left of it
    if not Filter.main then Filter.Create(frame) end
    local main = Filter.main
    if main:GetParent() ~= frame then main:SetParent(frame) end
    main:ClearAllPoints()
    main:SetPoint("TOPRIGHT", sort, "TOPLEFT", -Filter.GAP, 0)
    -- every button the cleanup button's own size, whatever Blizzard sets it to
    local w, h = sort:GetSize()
    if w and w > 0 then
        main:SetSize(w, h)
        for i, d in ipairs(Filter.drawer.buttons) do
            d:SetSize(w, h)
            d:SetPoint("BOTTOM", Filter.drawer, "BOTTOM", 0, (i - 1) * (h + Filter.STACK))
        end
        Filter.drawer:SetSize(w, #Filter.drawer.buttons * (h + Filter.STACK) - Filter.STACK)
    end
    sort:ClearAllPoints()
    sort:SetPoint("TOPRIGHT", frame, "TOPRIGHT", Filter.SORT_X, Filter.SORT_Y)
    -- Buttons: the row in the combined backpack when the search box still gets MIN_SEARCH beside it
    -- (the window's width less the cleanup button, the row and the gaps); else the drawer
    local bw = (w and w > 0) and w or Filter.W
    local bh = (h and h > 0) and h or Filter.H
    local n = #Filter.row.buttons
    local rowW = n * bw + (n - 1) * Filter.GAP
    local spare = frame:GetWidth() + Filter.SORT_X - bw - Filter.GAP - rowW - Filter.SEARCH_GAP - base.x
    local useRow = Filter.Mode() == "buttons" and frame == Combined() and spare >= Filter.MIN_SEARCH
    local room
    if useRow then
        Filter.Close()
        main:Hide()
        if Filter.row:GetParent() ~= frame then Filter.row:SetParent(frame) end
        Filter.LayoutRow(sort, bw, bh)
        Filter.row:Show()
        room = spare
    else
        Filter.row:Hide()
        main:Show()
        -- the search box ends before the filter button
        room = frame:GetWidth() + Filter.SORT_X - 2 * Filter.W - Filter.GAP - Filter.SEARCH_GAP - base.x
    end
    search:SetWidth(math_max(40, math.min(base.width, room)))
    Filter.moved = frame
    Filter.Paint()
end

-- The search box fitted to the window: Blizzard gives the combined backpack's a fixed 330 width, so
-- with fewer Columns it would run past the window, over the cleanup button. It keeps
-- Blizzard's width when there's room, else ends before the cleanup button. (Category Filters fit it
-- themselves, before their filter button: Filter.Place.) searchUpdated: Blizzard just placed it.
function Bags.FitSearchBox(frame, searchUpdated)
    local search, sort = _G.BagItemSearchBox, _G.BagItemAutoSortButton
    if not (frame and search and search:GetParent() == frame and search:IsShown()) then return end
    if Filter.On() then Filter.Place(frame, searchUpdated) return end
    -- (the filter just went off, e.g. Category View picked: its buttons go and nothing stays dimmed)
    if Filter.moved then
        Filter.Close()
        if itemFilter then Filter.Set(nil) end
        Filter.Restore()
    end
    -- (the Gamepad UI anchors both its edges: it fits already)
    if search:GetNumPoints() ~= 1 then return end
    local point, rel, _, x = search:GetPoint(1)
    if point ~= "TOPLEFT" or rel ~= frame then return end
    if searchUpdated or not frame.fuiSearchWidth then frame.fuiSearchWidth = search:GetWidth() end
    -- the cleanup button sits 9 from the right edge; the box's right art reaches a little past it
    local right = (sort and sort:IsShown() and sort:GetParent() == frame) and (sort:GetWidth() + 9) or 4
    local room = frame:GetWidth() - x - right - Filter.SEARCH_GAP - 4
    search:SetWidth(math_max(40, math.min(frame.fuiSearchWidth, room)))
end

-- Category Filters switched on or off in the settings
function Filter.Refresh()
    if not Filter.On() then
        Filter.Close()
        if itemFilter then Filter.Set(nil) end
        Filter.Restore()
        return
    end
    local search = _G.BagItemSearchBox
    if search and search:IsVisible() then
        -- (Blizzard's width back first, so switching Drawer and Buttons never reads our narrowed box)
        Filter.Close()
        Filter.Restore()
        Filter.Place(search:GetParent(), true)
    end
end

-- with Bags & Looting on, and no bag addon of another kind: then FlareUI never touches the bags, so the addon's own layout and cleanup are left alone. The looting
-- side (Fast Auto-Loot, Loot Feed, loot confirms) is elsewhere and keeps working.
function Bags:ShouldLoad()
    return ns.BagModuleOn() and not self:GetOtherBagAddon()
end

function Bags:Init()
    if self.initialized then return end
    self.initialized = true
    -- Init runs synchronously on PLAYER_LOGIN, which can still be outside lockdown on a combat reload.
    WarmExtraSections()
    RefreshBagClickProxies()
    EventRegistry:RegisterCallback("QuickKeybindFrame.QuickKeybindModeEnabled", RefreshBagClickProxies, self)
    EventRegistry:RegisterCallback("QuickKeybindFrame.QuickKeybindModeDisabled", RefreshBagClickProxies, self)
    Bags.Sort.Hook()       -- section 4d
    Bags.StyleFreeSlots()
    Bags.StyleMoney()
    Bags.GoldList.Hook()
    Bags.Bank.Hook()       -- section 4e
    local useFilterButtons = C_Container.GetContainerItemQuestInfo and C_Item.GetItemInventoryTypeByID
        and Enum.InventoryType and not self:GetOtherBagAddon()
    for _, frame in ipairs(BagFrames()) do
        if frame.UpdateItems then hooksecurefunc(frame, "UpdateItems", UpdateFrameItems) end
        -- the search box fits the window, whatever its Columns
        if frame.UpdateSearchBox then hooksecurefunc(frame, "UpdateSearchBox", function(bag) Bags.FitSearchBox(bag, true) end) end
        -- Category Filters: the button follows Blizzard's search box (it's placed again on each open)
        if useFilterButtons and frame.UpdateSearchBox then
            hooksecurefunc(frame, "UpdateSearchBox", function(bag) Filter.Place(bag, true) end)
        end
    end
    if useFilterButtons then
        -- Blizzard also updates icon saturation on its own when a bag slot locks or unlocks.
        hooksecurefunc("SetItemButtonDesaturated", function(button, locked)
            if not locked and dimmedIcons[button] then button:GetItemButtonIconTexture():SetDesaturated(true) end
        end)
        Filter.Refresh()
    end
    local combined = Combined()
    if combined then
        local function HookLayout()
            if combined.UpdateFrameSize then hooksecurefunc(combined, "UpdateFrameSize", Relayout) end
            if combined.UpdateItemLayout then hooksecurefunc(combined, "UpdateItemLayout", Relayout) end
            -- (after the re-layout: the window's new width)
            if combined.UpdateFrameSize then hooksecurefunc(combined, "UpdateFrameSize", function(f) Bags.FitSearchBox(f) end) end
            -- Hide 2FA Bag Slots' Compact View lays the slots out again on each item change (section 1b)
            if Bags.H2FA.On() and combined.UpdateItems then
                hooksecurefunc(combined, "UpdateItems", function(f) if Bags.H2FA.Compact() then Relayout(f) end end)
            end
        end
        -- Hide 2FA Bag Slots hooks the same calls at login: FlareUI's go on a frame later, so they run
        -- after its own and FlareUI's grid is the one shown
        if Bags.H2FA.On() then C_Timer.After(0, HookLayout) else HookLayout() end
        if combined.SetItemsMatchingBagHighlighted then
            hooksecurefunc(combined, "SetItemsMatchingBagHighlighted", function(_, bagID, highlight)
                if highlight and not GamepadUI() then
                    SetExtraBagHighlight(bagID)
                elseif bagID == highlightedExtraBag then
                    SetExtraBagHighlight(nil)
                end
            end)
        end
        -- The mouse keyring button shows its tooltip without firing Blizzard's bag hover events.
        local keyring = _G.KeyRingButton
        if keyring then
            keyring:HookScript("OnEnter", function()
                if combined:IsShown() and not GamepadUI() then SetExtraBagHighlight(KeyringID()) end
            end)
            local function ClearKeyringHighlight()
                if highlightedExtraBag == KeyringID() then SetExtraBagHighlight(nil) end
            end
            keyring:HookScript("OnLeave", ClearKeyringHighlight)
            keyring:HookScript("OnHide", ClearKeyringHighlight)
        end
        combined:HookScript("OnShow", function() Bags:PlaceBagButtons() end)
        combined:HookScript("OnHide", ClearExtraNewItems)
        combined:HookScript("OnHide", function()
            SetExtraBagHighlight(nil)
            -- ToggleAllBags checks the keyring immediately after hiding the backpack. A keyring
            -- we opened for its grid must not count as a separate window opened by the player.
            local id = KeyringID()
            local keys = openedForBackpack[id]
            if not combined:IsShown() and keys and keys:IsShown() and keys:GetID() == id
                and not InCombatLockdown() then Bags.CloseWindow(id) end
            if next(openedForBackpack) then QueueBackpackExtraSync() end
        end)
    end
    -- the bags move when they open or the screen changes: the buttons pick their side again
    hooksecurefunc("UpdateContainerFrameAnchors", function()
        Bags:PlaceBagButtons()
        ParkExtraWindows()
    end)
    if combined and ToggleBackpack_Combined then
        -- ToggleAllBags closes and counts the reagent bag itself.
        hooksecurefunc("ToggleBackpack_Combined", function()
            -- Let the deferred sync close our window after combat.
            if InCombatLockdown() then return end
            if not combined:IsShown() and Bags:IsCombined() and LayoutWanted() then
                CloseParkedReagentWindow()
            end
        end)
    end
    -- Blizzard's Use Combined Bags switched: it closes and reopens the bags with its own layout, so
    -- FlareUI's goes back on a frame later
    local combinedSwitch = CreateFrame("Frame")
    combinedSwitch:RegisterEvent("USE_COMBINED_BAGS_CHANGED")
    combinedSwitch:SetScript("OnEvent", function() C_Timer.After(0, function() Bags:Refresh() end) end)
    -- the keyring and crafting bag sections follow their items
    local bagEvents = CreateFrame("Frame")
    bagEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
    bagEvents:RegisterEvent("CVAR_UPDATE")
    bagEvents:RegisterEvent("CURSOR_CHANGED")
    bagEvents:RegisterEvent("GAME_PAD_ACTIVE_CHANGED")
    bagEvents:RegisterEvent("ITEM_LOCK_CHANGED")
    bagEvents:RegisterEvent("INVENTORY_SEARCH_UPDATE")
    -- (the crafting bag's own slots: the cooldowns and new item glows Blizzard's windows follow)
    for _, event in ipairs({ "BAG_UPDATE_COOLDOWN", "BAG_NEW_ITEMS_UPDATED" }) do pcall(bagEvents.RegisterEvent, bagEvents, event) end
    if useFilterButtons then bagEvents:RegisterEvent("QUEST_LOG_UPDATE") end
    for _, event in ipairs({ "BAG_UPDATE_DELAYED", "BAG_CONTAINER_UPDATE", "PLAYER_REGEN_ENABLED", "EQUIPMENT_SETS_CHANGED" }) do
        pcall(bagEvents.RegisterEvent, bagEvents, event)
    end
    bagEvents:SetScript("OnEvent", function(self, event, bagID, slotID)
        if event == "CURSOR_CHANGED" or event == "GAME_PAD_ACTIVE_CHANGED" or event == "CVAR_UPDATE" then
            RefreshBagClickProxies()
            return
        end
        if event == "ITEM_LOCK_CHANGED" or event == "INVENTORY_SEARCH_UPDATE"
            or event == "BAG_UPDATE_COOLDOWN" or event == "BAG_NEW_ITEMS_UPDATED" then
            local id = ReagentID()
            local e = id and extras[id]
            if e and e.probe and next(e.probe) and not e.window and e.holder:IsVisible() then
                if event == "BAG_UPDATE_COOLDOWN" then   -- (often in a fight: the cooldowns alone)
                    for slot, b in pairs(e.probe) do
                        if b:IsShown() and b.UpdateCooldown then
                            pcall(b.UpdateCooldown, b, C_Container.HasContainerItem and C_Container.HasContainerItem(id, slot))
                        end
                    end
                elseif event ~= "ITEM_LOCK_CHANGED" then
                    for slot, b in pairs(e.probe) do
                        if b:IsShown() then Bags.UpdateReagentProbe(b, id, slot) end
                    end
                elseif (not canaccessvalue or (canaccessvalue(bagID) and canaccessvalue(slotID)))
                    and bagID == id and slotID and e.probe[slotID] and e.probe[slotID]:IsShown() then
                    Bags.UpdateReagentProbe(e.probe[slotID], id, slotID)
                end
            end
            return
        end
        if event == "QUEST_LOG_UPDATE" then
            if itemFilter == "quest" then RefreshItemFilter() end
            return
        end
        -- By Category: a set saved, renamed or deleted moves its items between sections
        local db = GetDb()
        if event == "EQUIPMENT_SETS_CHANGED" then
            local backpack = db and Bags.View(db) == "rowsSets" and Combined()
            if backpack and backpack:IsShown() then Relayout(backpack) end
            return
        end
        local contentsChanged = event == "BAG_UPDATE_DELAYED" or event == "PLAYER_REGEN_ENABLED"
        if event == "PLAYER_REGEN_ENABLED" then
            ParkExtraWindows()
            -- A hidden or reused window may still own buttons that could not be returned in combat.
            for _, owner in pairs(Bags.adopted) do
                if parked[owner] == nil and Bags.ReturnExtraButtons(owner) and owner:IsShown() then owner:UpdateItemLayout() end
            end
            QueueBackpackExtraSync()
        end
        if contentsChanged then
            local id = ReagentID()
            local e = id and extras[id]
            if e and e.probe and next(e.probe) and not e.window and e.holder:IsVisible() then
                for slot, b in pairs(e.probe) do
                    if b:IsShown() then Bags.UpdateReagentProbe(b, id, slot) end
                end
            end
        end
        if contentsChanged and db and db.bagAutoOpen then C_Timer.After(0.3, Bags.AutoOpen.Next) end
        -- Slot counts can arrive after login or grow when a bag is replaced.
        if event == "PLAYER_ENTERING_WORLD" then self:UnregisterEvent(event) end
        local refreshLayout = event == "PLAYER_ENTERING_WORLD" or event == "BAG_CONTAINER_UPDATE" or contentsChanged
        if refreshLayout then
            WarmExtraSections()
            RefreshBagClickProxies()
        end
        -- Reclassify moved items even if the number of slots in the bags did not change.
        if contentsChanged and (CategoryRows(db) or Bags.CombineEmptyOn() or next(Bags.combineHidden)) then
            Relayout(Combined())
            return
        end
        if not next(extras) and not (KeyringWanted() or ReagentWanted()) then return end
        local frame = Combined()
        if refreshLayout and frame and frame:IsShown() and (not contentsChanged or ExtraLayoutChanged(event)) then
            Relayout(frame)
        end
    end)
    -- a newly learned appearance takes its eye off every item with that look
    local wardrobe = CreateFrame("Frame")
    for _, event in ipairs({ "TRANSMOG_COLLECTION_UPDATED", "TRANSMOG_COLLECTION_SOURCE_ADDED", "TRANSMOG_COLLECTION_SOURCE_REMOVED" }) do
        pcall(wardrobe.RegisterEvent, wardrobe, event)
    end
    local wardrobeQueued = false
    wardrobe:SetScript("OnEvent", function()
        Bags.ForgetAppearances()
        local db = GetDb()
        if not (db and db.bagUncollected) or wardrobeQueued then return end
        wardrobeQueued = true
        C_Timer.After(0.2, function()
            wardrobeQueued = false
            Bags:Refresh()
        end)
    end)
end

-- Live from the options. Blizzard's layout code is never called from here (that would run it
-- tainted): a layout switched off goes back to Blizzard's the next time the bags open.
function Bags:Refresh()
    if not self.initialized then return end
    WarmExtraSections()
    RefreshBagClickProxies()
    Bags.StyleFreeSlots()
    Bags.StyleMoney()
    for _, frame in ipairs(BagFrames()) do
        if frame:IsShown() then
            if frame == Combined() then Relayout(frame); Bags.FitSearchBox(frame) end
            UpdateFrameItems(frame)
        end
    end
    self:PlaceBagButtons()
    ParkExtraWindows()
    if next(openedForBackpack) then QueueBackpackExtraSync() end
    Bags.Bank.Refresh()
end

--------------------------------------------------
-- 4d. SORT ON OPEN (Bags and Looting > Sort Bags on Open, off)
-- Opening the bags runs Blizzard's own clean-up (C_Container.SortBags, the broom button), so its
-- rules hold: bags set to Ignore This Bag stay as they are. Bags already in order don't move.
-- Not in a fight, not with something on the cursor, and not at a vendor, the mailbox, the bank, the
-- auction house or in a trade, where slots moving under the pointer would be a nuisance. Opening
-- several bags at once sorts once.
--------------------------------------------------
local Sort = { EVERY = 1 }   -- seconds between two sorts at the least
Bags.Sort = Sort

function Sort.On()
    local db = GetDb()
    return db and db.bagAutoSort == true and not Bags:GetOtherBagAddon() or false
end

-- windows where the bags are open to be worked in
local BUSY_WINDOWS = { "MerchantFrame", "MailFrame", "BankFrame", "GuildBankFrame", "AuctionHouseFrame", "AuctionFrame", "TradeFrame" }
function Sort.Busy()
    if InCombatLockdown() or GetCursorInfo() then return true end
    for _, name in ipairs(BUSY_WINDOWS) do
        local frame = _G[name]
        if frame and frame:IsShown() then return true end
    end
    return false
end

-- A bag window has opened: one sort on the next frame (the other bags open in the same moment)
function Sort.Opened()
    if openingForBackpack then return end
    if Sort.queued or not Sort.On() then return end
    Sort.queued = true
    C_Timer.After(0, function()
        Sort.queued = false
        local now = GetTime()
        if not Sort.On() or Sort.Busy() or (Sort.last and now - Sort.last < Sort.EVERY) then return end
        if not (C_Container and C_Container.SortBags) then return end
        Sort.last = now
        pcall(C_Container.SortBags)
    end)
end

function Sort.Hook()
    for _, frame in ipairs(BagFrames()) do
        frame:HookScript("OnShow", Sort.Opened)
    end
end

--------------------------------------------------
-- 4e. BANK WINDOW (Bags and Looting > Bank Window)
-- Forever's bank is one window: every bank bag in one grid of 8 columns, in pages of 88 slots, with
-- wide spaces between the slots. Columns, Gaps Between Bags and Tight Spacing lay the shown page out
-- again after Blizzard's (hooksecurefunc on its GenerateItemSlotsForSelectedTab), and size the window
-- to fit; it never gets narrower than Blizzard's, so the bag slots and buttons at its foot keep their
-- room. Blizzard's pages stay as they are. All off (or in the Gamepad UI), Blizzard's grid is put back
-- once and left alone. The window grows to the right: Blizzard's window manager still thinks it 560 wide.
--------------------------------------------------
local Bank = {
    X = 47, Y = -63,             -- Blizzard's first slot (BankPanelMixin:GenerateItemSlotsForSelectedTab)
    GAP_X = 13, GAP_Y = 10,      -- Blizzard's space between slots (useUniformItemSlotSpacing)
    TIGHT = 5,                   -- the backpack's (ITEM_SPACING)
    SIDES = 93,                  -- left and right of the grid together
    BOTTOM = 125,                -- below the grid: the bag slots, the cost and the money
    COLUMNS = 8, MIN_HEIGHT = 460,
}
Bags.Bank = Bank

function Bank.Wanted(db)
    return db and ((db.bankColumns or 0) > 0 or db.bankGaps == true or db.bankTight == true) or false
end

function Bank.Layout(panel)
    local frame = _G.BankFrame
    if not (frame and panel and panel == frame.BankPanel and panel:IsShown()) then return end
    if Bags:GetOtherBagAddon() or not panel.EnumerateValidItems then return end
    if not (C_Bank and C_Bank.ShouldUsePlayerBagsInBank and C_Bank.ShouldUsePlayerBagsInBank()) then return end
    if InCombatLockdown() and frame:IsProtected() then return end
    local db = GetDb()
    -- (not in the Gamepad UI, as the backpack's layout)
    local wanted = Bank.Wanted(db) and not GamepadUI()
    if not (wanted or Bank.owned) then return end
    Bank.baseWidth = Bank.baseWidth or panel:GetWidth()

    -- Blizzard's order: the bank bags in turn, each from its first slot
    local order = {}
    for i, tab in ipairs(panel.purchasedBankTabData or {}) do order[tab.ID] = i end
    local items = {}
    for button in panel:EnumerateValidItems() do
        if button:IsShown() and button.GetBankTabID and button.GetContainerSlotID then items[#items + 1] = button end
    end
    if #items == 0 then return end
    table_sort(items, function(a, b)
        local ta, tb = order[a:GetBankTabID()] or 0, order[b:GetBankTabID()] or 0
        if ta ~= tb then return ta < tb end
        return a:GetContainerSlotID() < b:GetContainerSlotID()
    end)

    local columns = wanted and (db.bankColumns or 0) > 0 and db.bankColumns or Bank.COLUMNS
    local gaps = wanted and db.bankGaps == true
    local sx, sy = Bank.GAP_X, Bank.GAP_Y
    if wanted and db.bankTight == true then sx, sy = Bank.TIGHT, Bank.TIGHT end
    local w, h = items[1]:GetSize()
    local gridW = columns * w + (columns - 1) * sx
    local width = math_max(Bank.baseWidth, gridW + Bank.SIDES)
    -- a grid narrower than Blizzard's sits in the middle
    local x0 = Bank.X + math.floor((width - gridW - Bank.SIDES) / 2)

    local col, row, gapCount, prevTab = 0, 0, 0, nil
    for _, button in ipairs(items) do
        local tab = button:GetBankTabID()
        if gaps and prevTab and tab ~= prevTab then
            if col > 0 then col, row = 0, row + 1 end
            gapCount = gapCount + 1
        end
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", panel, "TOPLEFT", x0 + col * (w + sx), Bank.Y - row * (h + sy) - gapCount * BAG_GAP)
        col = col + 1
        if col >= columns then col, row = 0, row + 1 end
        prevTab = tab
    end
    local rows = row + (col > 0 and 1 or 0)
    local height = math_max(Bank.MIN_HEIGHT, -Bank.Y + rows * h + (rows - 1) * sy + gapCount * BAG_GAP + Bank.BOTTOM)
    panel:SetSize(width, height)
    frame:SetSize(width, height)
    Bank.owned = wanted
end

function Bank.Hook()
    local panel = _G.BankFrame and _G.BankFrame.BankPanel
    if not panel or Bank.hooked or not panel.GenerateItemSlotsForSelectedTab then return end
    Bank.hooked = true
    hooksecurefunc(panel, "GenerateItemSlotsForSelectedTab", Bank.Layout)
end

-- live from the options, while the bank is open
function Bank.Refresh()
    local panel = _G.BankFrame and _G.BankFrame.BankPanel
    if panel and panel:IsVisible() then Bank.Layout(panel) end
end

--------------------------------------------------
-- 5. SETTINGS PREVIEW SAMPLE
-- A made-up combined backpack: Blizzard's bag frame art, plain item buttons with made-up items laid
-- out and decorated by the code above (columns, gaps, borders, junk coin), the
-- keyring and crafting bag sections, the header tools, round bag buttons and the money line.
-- No secure buttons, no events, nothing in the module's lists.
--------------------------------------------------
do
    local ICON = "Interface\\Icons\\"
    -- by bag, from the last to the backpack (Blizzard's order); slot -> { icon, quality, count, ... }
    local SAMPLE_BAGS = {
        { bag = 1, slots = 8, items = {
            [1] = { icon = ICON .. "INV_Misc_Pelt_Wolf_01", category = "materials", quality = 1, count = 6 },
            [2] = { icon = ICON .. "INV_Misc_Bone_HumanSkull_01", category = "junk", quality = 0 },
            [4] = { icon = ICON .. "INV_Ore_Copper_01", category = "materials", quality = 1, count = 8 },
        } },
        { bag = 0, slots = 16, items = {
            [1] = { icon = ICON .. "INV_Misc_Rune_01", category = "quest", quality = 1 },
            [2] = { icon = ICON .. "INV_Sword_04", category = "equipment", quality = 2, ilvl = 24 },
            [3] = { icon = ICON .. "INV_Chest_Cloth_17", category = "equipment", quality = 3, ilvl = 31, uncollected = true },
            [4] = { icon = ICON .. "INV_Jewelry_Ring_15", category = "equipment", quality = 4, ilvl = 40 },
            [5] = { icon = ICON .. "INV_Misc_Food_15", category = "consumables", quality = 1, count = 20, petFood = true },
            [6] = { icon = ICON .. "INV_Potion_51", category = "consumables", quality = 1, count = 5 },
            [7] = { icon = ICON .. "INV_Fabric_Linen_01", category = "materials", quality = 1, count = 12 },
            [9] = { icon = ICON .. "INV_Misc_Bone_HumanSkull_01", category = "junk", quality = 0 },
        } },
    }
    local KEYS = { [1] = { icon = ICON .. "INV_Misc_Key_03", quality = 1 }, [2] = { icon = ICON .. "INV_Misc_Key_11", quality = 1 } }
    local REAGENTS = { [1] = { icon = ICON .. "INV_Misc_Herb_10", quality = 1, count = 14 },
                       [2] = { icon = ICON .. "INV_Misc_Dust_01", quality = 1, count = 3 } }
    local SAMPLE_CATEGORIES = {}
    for _, key in ipairs(CATEGORY_ORDER) do
        local section = { key = key, label = CATEGORY_NAMES[key], items = {}, slots = 0 }
        -- The draw loop walks each section backwards, like the real backpack.
        for i = #SAMPLE_BAGS, 1, -1 do
            local bag = SAMPLE_BAGS[i]
            for slot = 1, bag.slots do
                local item = bag.items[slot]
                if (item and item.category or "other") == key then
                    section.slots = section.slots + 1
                    section.items[section.slots] = item
                end
            end
        end
        if section.slots > 0 then SAMPLE_CATEGORIES[#SAMPLE_CATEGORIES + 1] = section end
    end
    local PAW = "Interface\\Icons\\Ability_Hunter_BeastTraining"   -- Pet Food in Bags (Tweaks.lua)
    local SLOT_SIZE = 37                 -- an item button's own size
    -- Blizzard's combined backpack paddings (ContainerFrameCombinedBagsMixin), the money box's height
    local PAD_W, PAD_H, MONEY_H = 15, 75, 17
    local SEARCH_X, SEARCH_WIDTH = 62, 330
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
        local info = item and { quality = item.quality,
                                sampleItemLevel = item.ilvl, sampleUncollected = item.uncollected } or nil
        Bags.DecorateButton(b, db, info)
        b.paw:SetShown(item and item.petFood and db.petFood and true or false)
        b:SetSize(SLOT_SIZE, SLOT_SIZE)
        b:Show()
    end

    local function DrawSampleTools(panel, width)
        local mode = Filter.On() and Filter.Mode() or "off"
        local step = Filter.W + Filter.GAP
        local room = width + Filter.SORT_X - Filter.W - Filter.SEARCH_GAP - SEARCH_X
        local showRow = mode == "buttons" and Bags:IsCombined()
            and room - #Filter.CATEGORIES * step >= Filter.MIN_SEARCH
        local count = showRow and #Filter.CATEGORIES or (mode == "off" and 0 or 1)
        local buttons = panel.filterButtons
        for i = 1, count do
            local icon = showRow and Filter.CATEGORIES[i].icon or Filter.MAIN_ICON
            local b = buttons[i]
            if not b then
                b = Filter.NewButton(panel.header, icon)
                b:EnableMouse(false)
                buttons[i] = b
            else
                b.icon:SetTexture(icon)
            end
            b:ClearAllPoints()
            b:SetPoint("TOPRIGHT", panel.sortButton, "TOPLEFT", -Filter.GAP - (count - i) * step, 0)
            b:Show()
        end
        for i = count + 1, #buttons do buttons[i]:Hide() end
        panel.searchBox:SetWidth(math_max(40, math.min(SEARCH_WIDTH, room - (count > 0 and count * step or 4))))
    end

    function Bags.CreateSample(parent)
        local f = CreateFrame("Frame", nil, parent)
        f.fuiSample = true
        f:EnableMouse(false)
        f:SetFrameLevel(parent:GetFrameLevel() + 1)
        f.items, f.bagButtons, f.sectionHeaders = {}, {}, {}

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
        panel.header = top
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

        local search = CreateFrame("EditBox", nil, top, "SearchBoxTemplate")
        search:EnableMouse(false)
        search:EnableKeyboard(false)
        search:SetHeight(18)
        search:SetPoint("TOPLEFT", SEARCH_X, -37)
        panel.searchBox = search

        local sort = CreateFrame("Button", nil, top)
        sort:EnableMouse(false)
        sort:SetNormalAtlas("bags-button-autosort-up")
        sort:SetSize(Filter.W, Filter.H)
        sort:SetPoint("TOPRIGHT", Filter.SORT_X, Filter.SORT_Y)
        panel.sortButton, panel.filterButtons = sort, {}

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
        local index, col, row, gapCount, headerSpace = 0, 0, 0, 0, 0
        local categorized = CategoryRows(db) and Bags:IsCombined()
        local collapsedSections = categorized and GetCollapsedSections()
        local sections = {}
        if db.bagKeyring and KeyringID() then
            sections[#sections + 1] = { key = KeyringID(), items = KEYS, slots = 4 }
        end
        if db.bagReagent and ReagentID() then
            sections[#sections + 1] = { key = ReagentID(), items = REAGENTS, slots = columns }
        end
        for _, section in ipairs(categorized and SAMPLE_CATEGORIES or SAMPLE_BAGS) do
            sections[#sections + 1] = section
        end
        for _, header in pairs(f.sectionHeaders) do header:Hide() end
        for i, section in ipairs(sections) do
            local collapsed = categorized and collapsedSections[section.key]
            if not collapsed then
                for slot = section.slots, 1, -1 do
                    index = index + 1
                    local b = SampleButton(f, index)
                    Fill(b, section.items[slot], db)
                    Bags.GridPoint(b, anchor, col, row, gapCount, stepX, stepY, headerSpace)
                    col = col + 1
                    if col >= columns then col, row = 0, row + 1 end
                end
            end
            if categorized then
                if col > 0 then col, row = 0, row + 1 end
                local header = f.sectionHeaders[section.key]
                if not header then
                    header = CreateCategoryHeader(panel)
                    f.sectionHeaders[section.key] = header
                end
                SetCategoryHeader(header, section.label or ExtraSectionLabel(section.key), collapsed)
                header:ClearAllPoints()
                header:SetWidth(columns * stepX - ITEM_SPACING)
                header:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 4 + row * stepY + gapCount * BAG_GAP + headerSpace)
                header:Show()
                headerSpace = headerSpace + CATEGORY_HEADER_HEIGHT
            elseif section.key or (gaps and i < #sections) then
                if col > 0 then col, row = 0, row + 1 end
                gapCount = gapCount + 1
            end
        end
        for i = index + 1, #f.items do f.items[i]:Hide() end
        local rows = row + (col > 0 and 1 or 0)
        local width = columns * w + (columns - 1) * ITEM_SPACING + PAD_W
        local height = rows * h + math_max(0, rows - 1) * ITEM_SPACING + gapCount * BAG_GAP + headerSpace + PAD_H + MONEY_H + 12
        panel:SetSize(width, height)
        if NineSliceUtil and NineSliceUtil.UpdateCornerCropping then pcall(NineSliceUtil.UpdateCornerCropping, panel, height) end
        DrawSampleTools(panel, width)

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

--------------------------------------------------
-- CHARACTER SHEET ITEM LEVEL: Item Level also puts each worn item's
-- level in the bottom left of its slot. On its own, outside Bags:Init, so it works beside a bag addon.
--------------------------------------------------
do
    local SLOTS = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist", "Hands", "Waist",
                    "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1", "MainHand", "SecondaryHand", "Ranged" }
    local labels = {}

    local function Wanted()
        local db = GetDb()
        return ns.BagModuleOn() and db and db.bagItemLevel and true or false
    end

    local function Label(button)
        local fs = labels[button]
        if not fs then
            fs = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
            fs:SetPoint("BOTTOMLEFT", 2, 2)
            fs:SetDrawLayer("OVERLAY", 7)
            labels[button] = fs
        end
        return fs
    end

    local function UpdateSlot(button)
        local slotID = button:GetID()
        local link = slotID and GetInventoryItemLink("player", slotID)
        local fs = Label(button)
        fs:Hide()
        if not (link and Wanted()) then return end
        StyleIconText(fs, GetDb().bagItemLevelFont)
        local itemID = GetInventoryItemID("player", slotID)
        if itemID and not C_Item.IsItemDataCachedByID(itemID) then
            -- not in the cache yet: once it is
            local item = Item:CreateFromItemLink(link)
            item:ContinueOnItemLoad(function()
                if GetInventoryItemLink("player", slotID) == link then UpdateSlot(button) end
            end)
            return
        end
        local level = ItemLevelOf(link)
        if not level then return end
        local quality = GetInventoryItemQuality("player", slotID)
        fs:SetText(level)
        local r, g, b = C_Item.GetItemQualityColor(quality or 1)
        fs:SetTextColor(r or 1, g or 1, b or 1)
        fs:Show()
    end

    function Bags.UpdateCharacterLevels()
        local frame = _G.CharacterFrame
        if not (frame and frame:IsShown()) and not next(labels) then return end
        for _, name in ipairs(SLOTS) do
            local button = _G["Character" .. name .. "Slot"]
            if button then UpdateSlot(button) end
        end
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_LOGIN")
    events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_LOGIN" then
            events:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
            events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
            if _G.CharacterFrame then _G.CharacterFrame:HookScript("OnShow", Bags.UpdateCharacterLevels) end
            return
        end
        local frame = _G.CharacterFrame
        if frame and frame:IsShown() then Bags.UpdateCharacterLevels() end
    end)

    -- THE INSPECT WINDOW (Ryder's idea): Item Level puts each item's level on the
    -- inspected player's slots too, and their average under the level line (Forever's inspect window
    -- shows none). The game sends another player's gear only after INSPECT_READY; an item not in the
    -- cache yet is asked again once it loads.
    local inspectAverage
    local function InspectUnit()
        local frame = _G.InspectFrame
        if not (frame and frame:IsShown()) then return nil end
        local unit = frame.GetInspectUnit and frame:GetInspectUnit() or frame.unit
        return unit and UnitExists(unit) and unit or nil
    end
    local function UpdateInspectSlot(button, unit)
        local slotID = button:GetID()
        local fs = Label(button)
        fs:Hide()
        local link = slotID and GetInventoryItemLink(unit, slotID)
        if not (link and Wanted()) then return end
        StyleIconText(fs, GetDb().bagItemLevelFont)
        local itemID = GetInventoryItemID(unit, slotID)
        if itemID and not C_Item.IsItemDataCachedByID(itemID) then
            Item:CreateFromItemLink(link):ContinueOnItemLoad(function()
                if InspectUnit() == unit and GetInventoryItemLink(unit, slotID) == link then UpdateInspectSlot(button, unit) end
            end)
            return
        end
        local level = ItemLevelOf(link)
        if not level then return end
        local r, g, b = C_Item.GetItemQualityColor(GetInventoryItemQuality(unit, slotID) or 1)
        fs:SetText(level)
        fs:SetTextColor(r or 1, g or 1, b or 1)
        fs:Show()
    end
    function Bags.UpdateInspectLevels()
        local unit = InspectUnit()
        if not unit then return end
        for _, name in ipairs(SLOTS) do
            local button = _G["Inspect" .. name .. "Slot"]
            if button then UpdateInspectSlot(button, unit) end
        end
        -- the average, under the name and level
        local anchor = _G.InspectLevelText
        if not anchor then return end
        if not inspectAverage then
            inspectAverage = anchor:GetParent():CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            inspectAverage:SetPoint("TOP", anchor, "BOTTOM", 0, -2)
        end
        local ok, average = false, nil
        if Wanted() and C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
            ok, average = pcall(C_PaperDollInfo.GetInspectItemLevel, unit)
        end
        if ok and canaccessvalue(average) and type(average) == "number" and average > 0 then
            inspectAverage:SetFormattedText(L["Item Level %d"], math.floor(average + 0.5))
            inspectAverage:Show()
        else
            inspectAverage:Hide()
        end
    end
    if EventUtil and EventUtil.ContinueOnAddOnLoaded then EventUtil.ContinueOnAddOnLoaded("Blizzard_InspectUI", function()
        local watch = CreateFrame("Frame")
        watch:RegisterEvent("INSPECT_READY")
        watch:RegisterEvent("UNIT_INVENTORY_CHANGED")
        -- (a moment after Blizzard's own handler, which shows the window)
        watch:SetScript("OnEvent", function()
            local frame = _G.InspectFrame
            if frame and frame:IsShown() then C_Timer.After(0.1, Bags.UpdateInspectLevels) end
        end)
        if _G.InspectFrame then _G.InspectFrame:HookScript("OnShow", function() C_Timer.After(0.1, Bags.UpdateInspectLevels) end) end
    end) end
end
