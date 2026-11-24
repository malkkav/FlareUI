local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local function noop() end
local Widget = getmetatable(env.UIParent)
function Widget:SetID(id) self.id = id end
function Widget:SetHighlightAtlas(atlas) self:SetHighlightTexture(atlas) end

function Widget:GetID() return self.id end
function Widget:GetBagID() return self.bagID end
function Widget:GetItemButtonIconTexture() return self.Icon end
function Widget:SetDesaturated(value) self.desaturated = value end
function Widget:IsProtected() return self.protected == true end
function Widget:IsClampedToScreen() return true end

local createFrame = env.CreateFrame
env.CreateFrame = function(kind, name, parent, template)
    local frame = createFrame(kind, name, parent, template)
    if kind == "ItemButton" then
        frame.Icon, frame.IconBorder = frame:CreateTexture(), frame:CreateTexture()
        frame.Count = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        frame.BagIndicator = frame:CreateTexture()
    end
    return frame
end
env.Mixin = function(target, source) for key, value in pairs(source) do target[key] = value end end
env.SetItemButtonTexture = function(button, texture) button.Icon:SetTexture(texture) end
env.SetItemButtonCount = function(button, count) button.Count:SetText(count) end
env.SetItemButtonDesaturated = function(button, value) button.Icon:SetDesaturated(value) end
env.GameTooltip.IsOwned = function(self, owner) return self:GetOwner() == owner end
env.GameTooltip.SetInventoryItem = function(self, unit, slot) self.inventory = { unit, slot } end
env.GameTooltip.AddDoubleLine = function(self, key, value) self:AddLine(key .. "=" .. value) end
env.GameTooltip_Hide = function() env.GameTooltip:Hide() end
env.GameTooltip_SetTitle = function(tooltip, label) tooltip.lines = { label } end
env.GameTooltip_AddNormalLine = function(tooltip, label) tooltip:AddLine(label) end
env.GameTooltip_AddColoredLine = env.GameTooltip_AddNormalLine
env.NumberFontNormal = "Native Counts"
env.GetMoney = function() return 12345 end
env.GetMoneyString = function(value) return value .. "c" end
env.RAID_CLASS_COLORS = { MAGE = { colorStr = "ff55aaff" } }
env.GetCursorInfo = function() return ui.cursor ~= nil and "item" or nil end
env.CursorHasItem = function() return ui.cursor ~= nil end
env.ResetCursor = function() ui.resetCursor = true end
env.PutItemInBag = function(slot) ui.putInBag = slot end
env.PickupBagFromSlot = function(slot) ui.pickedBag = slot end
env.GetInventoryItemTexture = function(_, id) if id == 21 then return 123 end end
env.GetInventorySlotInfo = function() return 21, 345 end
env.UnitExists = function(unit) return unit == "target" end
env.UnitIsDeadOrGhost = function() return ui.dead == true end
env.canaccessvalue = function() return true end
env.NUM_BAG_SLOTS, env.NUM_CONTAINER_FRAMES, env.NUM_BAG_FRAMES = 2, 1, 2
env.Constants = { InventoryConstants = { NumReagentBagSlots = 1 } }
env.Enum = {
    BagIndex = { Keyring = -1, ReagentBag = 5 }, ItemQuality = { Poor = 0 },
    ItemBind = { OnEquip = 2 }, ItemClass = { Weapon = 2, Armor = 4, Consumable = 0, Tradegoods = 7, Reagent = 5 },
    InventoryType = { IndexNonEquipType = 0, IndexBagType = 18, IndexQuiverType = 27, IndexAmmoType = 24 },
    ItemReagentSubclass = { Reagent = 1 },
}
env.GetKeyRingSize = function() return 0 end
env.C_AddOns.IsAddOnLoaded = function(name) return name == ui.bagAddon end
env.C_CVar = { GetCVarBool = function(key) return key == "combinedBags" end }
env.InputUtil = { IsGamepadUIEnabled = function() return ui.gamepad == true end }
env.C_Bank = { ShouldUsePlayerBagsInBank = function() return true end }
env.EventRegistry = env.CreateFrame("Frame")
env.UpdateContainerFrameAnchors = noop
local addonLoaded = {}
env.EventUtil = { ContinueOnAddOnLoaded = function(name, callback) addonLoaded[name] = callback end }
local sorts, opens = 0, {}
local contents = {
    [1] = { itemID = 11, hyperlink = "item:11", quality = 3, stackCount = 1 },
    [2] = { itemID = 12, hyperlink = "item:12", quality = 0, stackCount = 1 },
    [3] = { itemID = 13, hyperlink = "item:13", quality = 1, stackCount = 3 },
    [4] = { itemID = 14, hyperlink = "item:14", quality = 1, stackCount = 1 },
}
env.C_Container = {
    GetContainerNumSlots = function(id) return id == 0 and 8 or 0 end,
    GetContainerItemInfo = function(bag, slot) if bag == 0 then return contents[slot] end end,
    GetContainerItemQuestInfo = function(_, slot) return { isQuestItem = slot == 4 } end,
    ContainerIDToInventoryID = function(id) return 20 + id end,
    SortBags = function() sorts = sorts + 1 end,
    UseContainerItem = function(bag, slot)
        assert(bag == 0)
        opens[#opens + 1] = contents[slot].itemID
        if slot == 3 then contents[slot] = nil end
    end,
}
local function itemID(value) return tonumber(tostring(value):match("%d+")) end
env.C_Item = {
    GetItemInfoInstant = function(value)
        local id = itemID(value)
        return id, nil, nil, id == 11 and "INVTYPE_CHEST" or "", nil,
            id == 11 and 4 or id == 13 and 7 or id == 14 and 0 or 12
    end,
    GetItemInventoryTypeByID = function(id) return id == 11 and 5 or 0 end,
    IsItemDataCachedByID = function() return true end,
    GetDetailedItemLevelInfo = function(value) return itemID(value) == 11 and 39 or nil end,
    GetItemQualityColor = function(q) return q == 3 and 0 or 0.6, 0.4, 1 end,
    GetItemInfo = function(value)
        return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, itemID(value) == 11 and 2 or nil
    end,
}
env.C_TransmogCollection = {
    GetItemInfo = function(link) assert(link == "item:11"); return 100, 500 end,
    GetSourceInfo = function(id) assert(id == 500); return { isCollected = ui.collected } end,
    GetAppearanceInfoBySource = function() return { appearanceIsCollected = false } end,
    PlayerCanCollectSource = function() return true, true end,
}

local combined = env.CreateFrame("Frame", "ContainerFrameCombinedBags", env.UIParent)
combined:SetSize(460, 200)
combined.left = 300
combined.MoneyFrame = env.CreateFrame("Frame", nil, combined)
for _, key in ipairs({ "GoldButton", "SilverButton", "CopperButton" }) do
    local coin = env.CreateFrame("Button", nil, combined.MoneyFrame)
    coin.Text = coin:CreateFontString(nil, "OVERLAY", "Native Coin Font")
    combined.MoneyFrame[key] = coin
end
local items = {}
for slot = 1, 5 do
    local button = env.CreateFrame("ItemButton", nil, combined)
    button:SetID(slot)
    button.bagID = 0
    button:SetSize(37, 37)
    items[slot] = button
end
combined.UpdateItems = noop
function combined:EnumerateValidItems() return ipairs(items) end
local search = env.CreateFrame("EditBox", "BagItemSearchBox", combined)
local sort = env.CreateFrame("Button", "BagItemAutoSortButton", combined)
sort:SetSize(26, 18)
function combined:UpdateSearchBox()
    search:ClearAllPoints()
    search:SetPoint("TOPLEFT", self, "TOPLEFT", 62, -37)
    search:SetWidth(330)
end
combined:UpdateSearchBox()
local separ = env.CreateFrame("Frame", "ContainerFrame1", env.UIParent)
separ.EnumerateValidItems = function() return noop end
separ:Hide()
local bank = env.CreateFrame("Frame", "BankFrame", env.UIParent)
local bankPanel = env.CreateFrame("Frame", nil, bank)
bank.BankPanel = bankPanel
bankPanel:SetSize(560, 480)
bankPanel.purchasedBankTabData = { { ID = 102 }, { ID = 101 } }
bankPanel.GenerateItemSlotsForSelectedTab = noop
local bankItems = {}
for i, data in ipairs({ { 101, 2 }, { 102, 1 }, { 101, 1 } }) do
    local item = env.CreateFrame("ItemButton", nil, bankPanel)
    item:SetSize(40, 40)
    item.GetBankTabID = function() return data[1] end
    item.GetContainerSlotID = function() return data[2] end
    bankItems[i] = item
end
function bankPanel:EnumerateValidItems()
    local index = 0
    return function()
        index = index + 1
        return bankItems[index]
    end
end
bank:Hide()
local character = env.CreateFrame("Frame", "CharacterFrame", env.UIParent)
local head = env.CreateFrame("ItemButton", "CharacterHeadSlot", character)
head:SetID(1)
character:Hide()
env.GetInventoryItemLink = function(_, slot) if slot == 1 then return "item:11" end end
env.GetInventoryItemID = function(_, slot) if slot == 1 then return 11 end end
env.GetInventoryItemQuality = function() return 3 end
env.OpenAllBags = function(owner) ui.openOwner = owner end
env.CloseAllBags = function(owner) ui.closeOwner = owner end
local inspect = env.CreateFrame("Frame", "InspectFrame", env.UIParent)
inspect.unit = "target"
local inspectSlot = env.CreateFrame("ItemButton", "InspectHeadSlot", inspect)
inspectSlot:SetID(1)
env.InspectLevelText = inspect:CreateFontString()
env.C_PaperDollInfo = { GetInspectItemLevel = function(unit) assert(unit == "target"); return 33.6 end }

local db = {
    bagView = "all", bagFilters = "buttons", bagAutoSort = true, bagAutoOpen = true, bagButtons = true,
    bagJunkIcon = true, bagItemLevel = true, bagUncollected = true, bagBoE = true, bagPlainEmpty = true,
    bagWithCharacter = true, bankColumns = 10, bankGaps = true, bankTight = true,
    bagItemFont = { face = "Test", flags = "NONE", size = 15 },
    bagMoneyFont = { face = "Test", size = 13 },
}
local char = {}
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    modules = {}, db = { profile = { tweaks = db } },
    IsGamepadUI = env.InputUtil.IsGamepadUIEnabled,
    BagModuleOn = function() return true end,
    CharDB = function() return char end,
    GetFontPath = function(face) return "Fonts/" .. face end,
    SetFont = function(font, ...) font:SetFont(...) end,
    ApplyShadow = noop,
    BORDER_COLOR = env.CreateColor(0.7, 0.5, 0.3, 1),
}
env.LibStub = function(name)
    assert(name == "LibSharedMedia-3.0")
    return { Fetch = function(_, _, value) return "Media/" .. value end }
end
ui:load("Modules/Bags.lua", ns)
local bags = ns.Bags
assert(bags:ShouldLoad())
bags:Init()
bags:Refresh()
assert(db.bagView == "filters" and db.bagFilters == nil, "legacy category options migrate once")
local function overlay(slot)
    return assert(ui:find(function(w) return w:GetParent() == items[slot] and w.ilvl end))
end
local weapon, junk, empty = overlay(1), overlay(2), overlay(5)
assert(weapon.ilvl:GetText() == "39" and weapon.ilvl:IsShown() and weapon.eye:IsShown() and weapon.boe:IsShown())
assert(junk.junk:IsShown() and not junk.ilvl:IsShown() and empty.plain:IsShown())
-- (11-24) ... and a locked slot keeps its padlock
do
    local secured, extended = env.IsAccountSecured, items[5].IsExtended
    items[5].IsExtended = function() return true end
    env.IsAccountSecured = function() return false end
    bags:Refresh()
    assert(not empty.plain:IsShown())
    env.IsAccountSecured = function() return true end
    bags:Refresh()
    assert(empty.plain:IsShown())
    env.IsAccountSecured, items[5].IsExtended = secured, extended
    bags:Refresh()
end
assert(items[1].IconBorder:GetAlpha() == 0 and weapon.border:GetBackdrop().edgeSize == 8)
assert(items[1].Count:GetFont() == "Fonts/Test")
assert(combined.MoneyFrame.GoldButton.Text:GetFont() == "Fonts/Test")

local function filter(key)
    return ui:find(function(w) return w.key == key and w:IsVisible() end)
end
assert(filter("equipment") and filter("resources"), "wide backpacks use inline filters")
filter("equipment"):Click()
assert(not items[1].Icon.desaturated and items[2].Icon.desaturated and overlay(2).filterShade:IsShown())
env.SetItemButtonDesaturated(items[2], false)
assert(items[2].Icon.desaturated, "native unlock keeps an active category dim")
filter("equipment"):Click("RightButton")
assert(not items[2].Icon.desaturated and not overlay(2).filterShade:IsShown())
combined:SetWidth(230)
combined:UpdateSearchBox()
assert(not filter("equipment"))
local mainFilter = ui:find(function(w) return w:GetParent() == combined and w.edge and w:IsShown() end)
mainFilter:Click()
assert(filter("resources"), "narrow backpacks use a filter drawer")
filter("resources"):Click()
assert(items[1].Icon.desaturated and not items[3].Icon.desaturated)
db.bagView = "all"
bags:Refresh()
assert(not mainFilter:IsShown() and not items[1].Icon.desaturated)
db.bagThickBorders, db.bagSkinSlots = true, false
bags:Refresh()
assert(items[1].IconBorder:GetAlpha() == 1 and not weapon.border:IsShown())
db.bagSkinSlots = true
ui.collected = true
ui:emit("TRANSMOG_COLLECTION_UPDATED")
ui:emit("TRANSMOG_COLLECTION_SOURCE_ADDED")
ui:flushTimers()
assert(not weapon.eye:IsShown() and weapon.border:GetBackdrop().edgeSize == 16)

local firstBag = env.FlareUI_BagButton1
assert(firstBag:GetPoint() == "TOPRIGHT" and firstBag.Icon:GetTexture() == 123)
firstBag:RunScript("OnEnter")
assert(env.GameTooltip.inventory[2] == 21)
firstBag:RunScript("OnLeave")
assert(not env.GameTooltip:IsShown() and ui.resetCursor)
firstBag:Click()
assert(ui.pickedBag == 21)
ui.cursor = true
firstBag:Click()
assert(ui.putInBag == 21)
ui.cursor = nil

combined:Hide()
combined:Show()
separ:Show()
ui:flushTimers()
assert(sorts == 1, "multiple opened bags coalesce their cleanup")
combined:Hide()
combined:Show()
ui:flushTimers()
assert(sorts == 1, "rapid reopen is throttled")
ui.time = 102
bank:Show()
combined:Hide()
combined:Show()
ui:flushTimers()
assert(sorts == 1, "open bank inhibits sorting")
bankPanel:GenerateItemSlotsForSelectedTab()
local _, _, _, x, y = bankItems[2]:GetPoint()
local _, _, _, nextX, nextY = bankItems[3]:GetPoint()
assert(x == nextX and y == -63 and nextY == -120)
assert(select(4, bankItems[1]:GetPoint()) == x + 45)
db.bankColumns, db.bankTight, db.bankGaps = 0, false, false
bags.Bank.Refresh()
assert(select(4, bankItems[3]:GetPoint()) == select(4, bankItems[2]:GetPoint()) + 53)
assert(not bags.Bank.owned)
bank:Hide()

env.UnitCastingInfo, env.UnitChannelInfo = function() end, function() end
contents[2].hasLoot, contents[3].hasLoot = true, true
ui.combat = true
bags.AutoOpen.Next()
assert(#opens == 0)
ui.combat = false
env.SpellIsTargeting = function() return true end
bags.AutoOpen.Next()
assert(#opens == 0, "a kit waiting for its item")
env.SpellIsTargeting = nil
bags.AutoOpen.Next()
bags.AutoOpen.Next()
assert(#opens == 1 and opens[1] == 12)
ui:flushTimers()
ui:flushTimers()
assert(#opens == 2 and opens[2] == 13 and bags.AutoOpen.skip[12])
ui:flushTimers()
ui:flushTimers()
assert(#opens == 2, "a locked or unchanged item is skipped for the session")

ui:emit("PLAYER_LOGIN")
-- opens the bags and closes them again, without Blizzard's own note of who did (the bank reads that one)
env.OpenAllBags = function(...) assert(select("#", ...) == 0) ui.openOwner = character end
env.CloseAllBags = function() error("CloseAllBags writes Blizzard's note") end
local closeBackpack, closeBag, anyOpen = env.CloseBackpack, env.CloseBag, env.IsAnyBagOpen
local cleaned, closed = {}, {}
env.ContainerFrameSettingsManager = { bagSetupDirty = false, bagsShown = {} }
ns.CleanField = function(t, key) assert(t == env.ContainerFrameSettingsManager) cleaned[key] = true end
env.IsAnyBagOpen = function() return true end
character:Show()
ui:flushTimers()
assert(not ui.openOwner, "bags already open stay the player's")
env.CloseBackpack = function() ui.closeOwner = character end
env.CloseBag = function(id) closed[id] = true end
character:Hide()
assert(not ui.closeOwner)
env.IsAnyBagOpen = function() return false end
character:Show()
ui:flushTimers()
assert(ui.openOwner == character)
assert(cleaned.bagSetupDirty and cleaned.bagsShown)
-- a flag that is up (the bags need setting up again) stays
cleaned, env.ContainerFrameSettingsManager.bagSetupDirty = {}, true
bags.CleanFlags()
assert(not cleaned.bagSetupDirty and cleaned.bagsShown)
local headLabel = ui:find(function(w) return w:GetParent() == head and w:GetText() == "39" end)
assert(headLabel and headLabel:IsShown())
character:Hide()
assert(ui.closeOwner == character and closed[1] and closed[5])
env.CloseBackpack, env.CloseBag, env.IsAnyBagOpen = closeBackpack, closeBag, anyOpen
env.ContainerFrameSettingsManager, ns.CleanField = nil, nil
addonLoaded.Blizzard_InspectUI()
ui:emit("INSPECT_READY")
ui:flushTimers()
local average = ui:find(function(w) return w:GetParent() == inspect and w:GetText() == "Item Level 34" end)
assert(average and average:IsShown())
assert(ui:find(function(w) return w:GetParent() == inspectSlot and w:GetText() == "39" and w:IsShown() end))
db.bagItemLevel = false
bags.UpdateInspectLevels()
assert(not average:IsShown())

db.bagItemLevel, db.bagView, db.bagColumns = true, "rows", 8
db.bagKeyring, db.bagReagent, db.petFood = true, true, true
local sample = bags.CreateSample(env.UIParent)
local width, height = bags.DrawSample(sample)
assert(width > sample.panel:GetWidth() and height > sample.panel:GetHeight() and #sample.bagButtons == 3)
assert(sample.sectionHeaders.equipment:IsShown() and sample.sectionHeaders[-1]:IsShown())
assert(ui:find(function(w) return w.ilvl and w.ilvl:IsShown() and w.ilvl:GetText() == "31" end))
db.bagView, db.bagButtons, db.bagReagent, db.bagKeyring = "filters", false, false, false
bags.DrawSample(sample)
assert(not sample.bagButtons[1]:IsShown() and not sample.sectionHeaders.equipment:IsShown())

local gold = combined.MoneyFrame.GoldButton
env.Syndicator = {
    API = {
        GetAllCharacters = function() return { "One", "Two", "Away" } end,
        GetCharacter = function(name)
            return { details = { character = name, realmNormalized = name == "Away" and "other" or "home", className = "MAGE" },
                money = name == "Two" and 20 or 10 }
        end,
        GetAllGuilds = function() return { "Guild" } end,
        GetGuild = function() return { details = { realmNormalized = "home", guild = "Guild", show = { gold = true } }, money = 100 } end,
    },
    Utilities = { GetConnectedRealms = function() return { "home" } end },
}
env.GameTooltip.lines = {}
gold:RunScript("OnEnter")
assert(env.GameTooltip:IsShown() and env.GameTooltip.lines[1] == "Gold on This Realm=130c")
assert(env.GameTooltip.lines[3] == "<Guild>=100c" and env.GameTooltip.lines[4]:find("Two", 1, true))
gold:RunScript("OnLeave")
assert(not env.GameTooltip:IsShown())
-- (11-24) Combine Empty Slots: a special bag's free slots are counted apart, locked slots aren't free at all
do
    local container, secured = env.C_Container, env.IsAccountSecured
    local family = { [0] = 0, [1] = 4, [2] = 0 }
    env.C_Container = setmetatable({
        GetContainerItemInfo = function(bag, slot) if bag == 0 and slot == 1 then return { itemID = 1 } end end,
        GetContainerNumFreeSlots = function(bag) return 9, family[bag] end,
    }, { __index = container })
    env.IsAccountSecured = function() return false end
    local function slot(bag, id, locked)
        local b = env.CreateFrame("Button", nil, combined)
        b.GetBagID, b.GetID, b.IsExtended = function() return bag end, function() return id end, function() return locked end
        b.IsProtected = function() return false end
        return b
    end
    local soul1, filled, free1, locked, soul2, free2 = slot(1, 1), slot(0, 1), slot(0, 2), slot(0, 17, true), slot(1, 2), slot(2, 1)
    local kept = bags.CombineEmpty({ soul1, filled, free1, locked, soul2, free2 }, true)
    assert(#kept == 3 and kept[1] == filled and kept[2] == soul1 and kept[3] == free1, "the item, the soul bag's slot, the ordinary one")
    assert(tostring(soul1.fuiFreeCount:GetText()) == "2" and tostring(free1.fuiFreeCount:GetText()) == "2")
    assert(not locked:IsShown() and not soul2:IsShown() and not free2:IsShown())
    bags.CombineEmpty({}, false)
    assert(locked:IsShown() and soul2:IsShown() and free2:IsShown())
    env.C_Container, env.IsAccountSecured = container, secured
end
bags.otherAddon, ui.bagAddon = nil, "Bagnon"
assert(not bags:ShouldLoad())
print("PASS: bag filters and overlays, bank layout, safe sorting and opening, item levels and previews")
