local _, ns = ...
local L = ns.L
local S = ns.Settings

--------------------------------------------------
-- BAGS & LOOTING (11-12, out of Quality of Life)
-- Bags tab: the bag window (Modules/Bags.lua's layout), what is drawn on the item slots, and the
-- tools. Looting tab: Faster Auto Loot, Skip Loot Confirmations (Tweaks.lua) and the Loot Feed
-- (LootFeed.lua). Fonts tab: Bag Items and Loot Feed. The saved values stay in tweaks.*; the module's
-- own switch is tweaks.bagModule (ns.BagModuleOn: on for anyone who had Quality of Life on).
--------------------------------------------------
local function Refresh() if ns.Tweaks then ns.Tweaks:Refresh() end end
local function RefreshBags() if ns.Bags then ns.Bags:Refresh() end end
-- another bag addon greys the bag rows; the layout rows also need Blizzard's Combined Bags
local function BagAddon() return ns.Bags and ns.Bags.GetOtherBagAddon and ns.Bags:GetOtherBagAddon() and true or false end
local function NotCombined() return BagAddon() or not (ns.Bags and ns.Bags:IsCombined()) end

S:Module{
    key = "bl", group = "interface", order = 35, enabled = "tweaks.bagModule",
    tabs = { { key = "bags" }, { key = "looting" }, { key = "fonts" } },
}

-- BAGS: the window ------------------------------
local BAG_COLUMNS = { { 0, L["Default"] } }
for n = 6, 20 do BAG_COLUMNS[#BAG_COLUMNS + 1] = { n, tostring(n) } end
S:Row{ key = "bl.bagColumns", kind = "range", tab = "bags", path = "tweaks.bagColumns", choices = BAG_COLUMNS,
    apply = RefreshBags, disabled = NotCombined }
S:Row{ key = "bl.bagGaps", half = true, tab = "bags", path = "tweaks.bagGaps", apply = RefreshBags, disabled = NotCombined }
S:Row{ key = "bl.bagButtons", half = true, tab = "bags", path = "tweaks.bagButtons", apply = RefreshBags, disabled = NotCombined }
-- the keyring and the crafting bag as sections of the combined backpack (Bags.lua 0)
S:Row{ key = "bl.bagKeyring", half = true, tab = "bags", path = "tweaks.bagKeyring", apply = RefreshBags, disabled = NotCombined }
S:Row{ key = "bl.bagReagent", half = true, tab = "bags", path = "tweaks.bagReagent", apply = RefreshBags, disabled = NotCombined }

-- BAGS: the item slots --------------------------
S:Row{ key = "bl.bagThickBorders", half = true, tab = "bags", path = "tweaks.bagThickBorders", apply = RefreshBags, disabled = BagAddon }
S:Row{ key = "bl.bagRarityBorders", half = true, tab = "bags", path = "tweaks.bagRarityBorders", apply = RefreshBags, disabled = BagAddon }
S:Row{ key = "bl.bagJunkIcon", half = true, tab = "bags", path = "tweaks.bagJunkIcon", apply = RefreshBags, disabled = BagAddon }
S:Row{ key = "bl.bagUpgradeArrow", half = true, tab = "bags", path = "tweaks.bagUpgradeArrow", apply = RefreshBags, disabled = BagAddon }
-- (not greyed beside a bag addon: the character sheet's item levels are its own, Bags.lua)
S:Row{ key = "bl.bagItemLevel", half = true, tab = "bags", path = "tweaks.bagItemLevel",
    apply = function() RefreshBags(); if ns.Bags and ns.Bags.UpdateCharacterLevels then ns.Bags.UpdateCharacterLevels() end end }
S:Row{ key = "bl.bagUncollected", half = true, tab = "bags", path = "tweaks.bagUncollected", apply = RefreshBags, disabled = BagAddon }
-- (Tweaks.lua's, so no bag addon greys it)
S:Row{ key = "bl.petFood", half = true, tab = "bags", path = "tweaks.petFood", apply = Refresh }

-- BAGS: tools ------------------------------------
-- Category Filters: the filter button and drawer by the search box (Bags.lua 4b)
S:Row{ key = "bl.bagFilters", half = true, tab = "bags", path = "tweaks.bagFilters", disabled = BagAddon,
    apply = function() if ns.Bags and ns.Bags.Filter then ns.Bags.Filter.Refresh() end end }
S:Row{ key = "bl.delete", half = true, tab = "bags", path = "tweaks.autoDelete", apply = Refresh }
-- the bags open and close with the character window (Bags.lua 4c; the bank and guild bank always do)
S:Row{ key = "bl.bagWithCharacter", half = true, tab = "bags", path = "tweaks.bagWithCharacter" }

-- LOOTING ----------------------------------------
S:Row{ key = "bl.fastLoot", half = true, tab = "looting", path = "tweaks.fasterLoot", apply = Refresh }
S:Row{ key = "bl.skipLoot", half = true, tab = "looting", path = "tweaks.skipLootConfirm" }
-- Loot Feed: what you loot floats up beside you (LootFeed.lua); placed in Edit Mode
S:Row{ key = "bl.lootFeed", tab = "looting", path = "tweaks.lootFeed", reload = true }
local LOOT_QUALITY = {}
-- Poor (0) is the lowest, so it lets every item through: named All Items (a player read it as grey only)
for quality = 0, 4 do
    LOOT_QUALITY[#LOOT_QUALITY + 1] = { quality, quality == 0 and L["All Items"] or _G["ITEM_QUALITY" .. quality .. "_DESC"] or tostring(quality) }
end
local function NoFeed() return not S:GetPath("tweaks.lootFeed") end
S:Row{ key = "bl.lootFeedQuality", kind = "choice", tab = "looting", parent = "bl.lootFeed", path = "tweaks.lootFeedQuality",
    choices = LOOT_QUALITY, disabled = NoFeed }
S:Row{ key = "bl.lootFeedMoney", tab = "looting", parent = "bl.lootFeed", path = "tweaks.lootFeedMoney", disabled = NoFeed }
S:Row{ key = "bl.lootFeedSkills", tab = "looting", parent = "bl.lootFeed", path = "tweaks.lootFeedSkills", disabled = NoFeed }
S:Row{ key = "bl.lootFeedPosition", kind = "choice", tab = "looting", parent = "bl.lootFeed", path = "tweaks.lootFeedPosition",
    choices = { "cursor", "placed" }, disabled = NoFeed,
    apply = function() if ns.LootFeed and ns.LootFeed.Refresh then ns.LootFeed:Refresh() end end }
S:Row{ key = "bl.lootFeedAlign", kind = "choice", tab = "looting", parent = "bl.lootFeed", path = "tweaks.lootFeedAlign",
    choices = { "left", "right" }, disabled = NoFeed }

-- FONTS: the bag icons' text and the loot feed's lines (live)
S:FontRows{ module = "bl", tab = "fonts", section = "bl.fonts", fonts = {
    -- the stack counts and cooldown numbers on the bag icons (Bags.lua StyleIconTexts)
    { key = "bagItems", path = "tweaks.bagItemFont", optional = true, disabled = BagAddon },
    -- the free bag slots on the backpack button (11-12, a player asked: too small to read)
    { key = "freeSlots", path = "tweaks.bagFreeSlotsFont", optional = true },
    -- the gold, silver and copper at the bags' foot (11-13, Marcus)
    { key = "money", path = "tweaks.bagMoneyFont", optional = true, disabled = BagAddon },
}, apply = function()
    if ns.Bags and ns.Bags.Refresh then ns.Bags:Refresh() end
    if ns.Bags and ns.Bags.StyleFreeSlots then ns.Bags.StyleFreeSlots() end
end }
-- the loot feed in a section of its own (11-13)
S:FontRows{ module = "bl", tab = "fonts", section = "bl.fontsLoot", fonts = {
    { key = "lootFeed", path = "tweaks.lootFeedFont" },
}, apply = function()
    if ns.LootFeed and ns.LootFeed.ApplyFont then ns.LootFeed:ApplyFont() end
end }
