local _, ns = ...
local L = ns.L
local S = ns.Settings

--------------------------------------------------
-- BAGS & LOOTING (out of Quality of Life)
-- Bags tab: the bag window (Modules/Bags.lua's layout), what is drawn on the item slots, and the
-- tools. Looting tab: Faster Auto Loot, Skip Loot Confirmations (Tweaks.lua), the Loot Roll Window
-- (LootRolls.lua) and the Loot Feed (LootFeed.lua). Fonts tab: the bags' texts, Loot Rolls and Loot Feed. The saved values stay in tweaks.*; the module's
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
-- a note says why the options are greyed, above them:
-- another bag addon in charge (named), or Blizzard's combined bags off
S:Row{ key = "bl.bagAddonNote", kind = "text", noTitle = true, tab = "bags", section = "bl.bagWindow",
    hidden = function() return not BagAddon() end,
    textFn = function()
        local name = ns.Bags and ns.Bags.GetOtherBagAddon and ns.Bags:GetOtherBagAddon() or "?"
        return L["%s is handling your bags: turn it off to use these options."]:format(name)   -- (one line)
    end }
S:Row{ key = "bl.combinedNote", kind = "text", noTitle = true, tab = "bags", section = "bl.bagWindow",
    hidden = function() return BagAddon() or (ns.Bags and ns.Bags.IsCombined and ns.Bags:IsCombined()) or false end }
-- Combined Backpack (it explains why the rows below are greyed): Blizzard's own Use
-- Combined Bags, switched from here. FlareUI saves nothing: Blizzard's checkbox and this one always agree.
S:Row{ key = "bl.bagCombined", half = true, tab = "bags", disabled = BagAddon,
    get = function() return GetCVarBool("combinedBags") and true or false end,
    set = function(on) SetCVar("combinedBags", on and 1 or 0) end,
    apply = function()
        -- the rows below follow once Blizzard has switched (USE_COMBINED_BAGS_CHANGED, Bags.lua)
        C_Timer.After(0, function()
            if ns.SettingsPanel and ns.SettingsPanel.Refresh then ns.SettingsPanel:Refresh() end
        end)
    end }
local BAG_COLUMNS = { { 0, L["Default"] } }
for n = 6, 20 do BAG_COLUMNS[#BAG_COLUMNS + 1] = { n, tostring(n) } end
S:Row{ key = "bl.bagColumns", kind = "range", tab = "bags", path = "tweaks.bagColumns", choices = BAG_COLUMNS,
    apply = RefreshBags, disabled = NotCombined }
S:Row{ key = "bl.bagGaps", half = true, tab = "bags", path = "tweaks.bagGaps", apply = RefreshBags, disabled = NotCombined }
S:Row{ key = "bl.bagButtons", half = true, tab = "bags", path = "tweaks.bagButtons", apply = RefreshBags, disabled = NotCombined }
-- the keyring and the crafting bag as sections of the combined backpack (Bags.lua 0)
S:Row{ key = "bl.bagKeyring", half = true, tab = "bags", path = "tweaks.bagKeyring", apply = RefreshBags, disabled = NotCombined }
S:Row{ key = "bl.bagReagent", half = true, tab = "bags", path = "tweaks.bagReagent", apply = RefreshBags, disabled = NotCombined }
-- one empty slot with the free count in place of every empty slot (Bags.lua 1c)
S:Row{ key = "bl.bagCombineEmpty", half = true, tab = "bags", path = "tweaks.bagCombineEmpty", apply = RefreshBags, disabled = NotCombined }

-- BAGS: the bank window (Bags.lua 4e). Forever's bank is one window
-- whatever Combined Bags says, so only another bag addon greys these.
local BANK_COLUMNS = { { 0, L["Default"] } }
for n = 6, 20 do BANK_COLUMNS[#BANK_COLUMNS + 1] = { n, tostring(n) } end
S:Row{ key = "bl.bankColumns", kind = "range", tab = "bags", path = "tweaks.bankColumns", choices = BANK_COLUMNS,
    apply = RefreshBags, disabled = BagAddon }
S:Row{ key = "bl.bankGaps", half = true, tab = "bags", path = "tweaks.bankGaps", apply = RefreshBags, disabled = BagAddon }
S:Row{ key = "bl.bankTight", half = true, tab = "bags", path = "tweaks.bankTight", apply = RefreshBags, disabled = BagAddon }

-- BAGS: the item slots --------------------------
-- Skin Item Slots (one choice): Off (Blizzard's slots), Thin Borders or Thick
-- Borders. A skinned slot always takes its item's quality colour.
S:Row{ key = "bl.bagSkinSlots", kind = "choice", tab = "bags", choices = { "off", "thin", "thick" },
    apply = RefreshBags, disabled = BagAddon,
    get = function()
        if S:GetPath("tweaks.bagSkinSlots") == false then return "off" end
        return S:GetPath("tweaks.bagThickBorders") and "thick" or "thin"
    end,
    set = function(value)
        S:SetPath("tweaks.bagSkinSlots", value ~= "off")
        if value ~= "off" then S:SetPath("tweaks.bagThickBorders", value == "thick") end
    end }
S:Row{ key = "bl.bagJunkIcon", half = true, tab = "bags", path = "tweaks.bagJunkIcon", apply = RefreshBags, disabled = BagAddon }
-- (not greyed beside a bag addon: the character sheet's item levels are its own, Bags.lua)
S:Row{ key = "bl.bagItemLevel", half = true, tab = "bags", path = "tweaks.bagItemLevel",
    apply = function() RefreshBags(); if ns.Bags and ns.Bags.UpdateCharacterLevels then ns.Bags.UpdateCharacterLevels() end end }
S:Row{ key = "bl.bagUncollected", half = true, tab = "bags", path = "tweaks.bagUncollected", apply = RefreshBags, disabled = BagAddon }
-- (Tweaks.lua's, so no bag addon greys it)
S:Row{ key = "bl.petFood", half = true, tab = "bags", path = "tweaks.petFood", apply = Refresh }
-- the last pair of Item Slots
S:Row{ key = "bl.bagBoE", half = true, tab = "bags", path = "tweaks.bagBoE", apply = RefreshBags, disabled = BagAddon }
S:Row{ key = "bl.bagPlainEmpty", half = true, tab = "bags", path = "tweaks.bagPlainEmpty", apply = RefreshBags, disabled = BagAddon }

-- BAGS: tools ------------------------------------
-- Category Filters (issue #26): Off, Drawer (a filter button and drawer by the search box) or
-- Buttons (the four in a row in a wide combined backpack, else the drawer); Bags.lua 4b. A dropdown,
-- so a full row on top; the two switches below pair up. The old switch saved true: read as Drawer.
S:Row{ key = "bl.bagFilters", kind = "choice", tab = "bags", path = "tweaks.bagFilters", disabled = BagAddon,
    choices = { "off", "drawer", "buttons" },
    get = function()
        local v = S:GetPath("tweaks.bagFilters")
        if v == true or v == "drawer" then return "drawer" end
        if v == "buttons" then return "buttons" end
        return "off"
    end,
    set = function(v) S:SetPath("tweaks.bagFilters", v) end,
    resetValue = function() return "off" end,
    apply = function() if ns.Bags and ns.Bags.Filter then ns.Bags.Filter.Refresh() end end }
S:Row{ key = "bl.delete", half = true, tab = "bags", path = "tweaks.autoDelete", apply = Refresh }
-- the bags open and close with the character window (Bags.lua 4c; the bank and guild bank always do)
S:Row{ key = "bl.bagWithCharacter", half = true, tab = "bags", path = "tweaks.bagWithCharacter" }
-- Blizzard's clean-up each time the bags open: a tool, so in Tools
S:Row{ key = "bl.bagAutoSort", half = true, tab = "bags", path = "tweaks.bagAutoSort", disabled = BagAddon }
-- clams, loot bags and opened lockboxes open themselves (Bags.lua 1d; not beside another bag addon)
S:Row{ key = "bl.bagAutoOpen", half = true, tab = "bags", path = "tweaks.bagAutoOpen", disabled = BagAddon,
    apply = function() if ns.Bags and ns.Bags.AutoOpen then ns.Bags.AutoOpen.Next() end end }

-- LOOTING ----------------------------------------
S:Row{ key = "bl.fastLoot", half = true, tab = "looting", path = "tweaks.fasterLoot", apply = Refresh }
S:Row{ key = "bl.skipLoot", half = true, tab = "looting", path = "tweaks.skipLootConfirm" }
-- Loot Roll Window: FlareUI's roll window in place of Blizzard's roll frames (LootRolls.lua);
-- placed in Edit Mode. Its own section, alone, so a full row. On and off take a reload.
S:Row{ key = "bl.lootRolls", tab = "looting", path = "tweaks.lootRolls", reload = true }
S:Row{ key = "bl.lootRollsOpacity", kind = "range", tab = "looting", path = "tweaks.lootRollsOpacity", choices = S:OpacityChoices(),
    parent = "bl.lootRolls", apply = function() if ns.LootRolls and ns.LootRolls.ApplyOpacity then ns.LootRolls:ApplyOpacity() end end }
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
    choices = { "left", "center", "right" }, disabled = NoFeed }

-- FONTS: the bag icons' text and the loot feed's lines (live)
S:FontRows{ module = "bl", tab = "fonts", section = "bl.fonts", fonts = {
    -- the stack counts and cooldown numbers on the bag icons (Bags.lua StyleIconTexts)
    { key = "bagItems", path = "tweaks.bagItemFont", optional = true, disabled = BagAddon },
    -- Item Level's numbers, in the bags and on the character sheet: shown while it's on
    { key = "itemLevel", path = "tweaks.bagItemLevelFont", optional = true,
      hidden = function() return not S:GetPath("tweaks.bagItemLevel") end },
    -- the free bag slots on the backpack button (too small to read)
    { key = "freeSlots", path = "tweaks.bagFreeSlotsFont", optional = true },
    -- the gold, silver and copper at the bags' foot
    { key = "money", path = "tweaks.bagMoneyFont", optional = true, disabled = BagAddon },
}, apply = function()
    if ns.Bags and ns.Bags.Refresh then ns.Bags:Refresh() end
    if ns.Bags and ns.Bags.StyleFreeSlots then ns.Bags.StyleFreeSlots() end
end }
-- the loot roll window and the loot feed in a section of their own (Loot Rolls)
S:FontRows{ module = "bl", tab = "fonts", section = "bl.fontsLoot", fonts = {
    { key = "lootRolls", path = "tweaks.lootRollFont" },
    { key = "lootFeed", path = "tweaks.lootFeedFont" },
}, apply = function()
    if ns.LootRolls and ns.LootRolls.ApplyFont then ns.LootRolls:ApplyFont() end
    if ns.LootFeed and ns.LootFeed.ApplyFont then ns.LootFeed:ApplyFont() end
end }
