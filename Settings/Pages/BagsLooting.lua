local _, ns = ...
local L = ns.L
local S = ns.Settings

--------------------------------------------------
-- BAGS & LOOTING (out of Quality of Life)
-- Bags tab: the bag window (Modules/Bags.lua's layout), what is drawn on the item slots, and the
-- tools. Looting tab: Faster Auto Loot, Skip Loot Confirmations (Tweaks.lua), the Loot Roll Window
-- (LootRolls.lua), the Loot Window (LootWindow.lua) and the Loot Feed (LootFeed.lua). Fonts tab: the bags' texts, Loot Rolls and Loot Feed. The saved values stay in tweaks.*; the module's
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
S:Row{ key = "bl.bagCombined", lead = true, tab = "bags", disabled = BagAddon,   -- (lead: every row below reads it)
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
-- Reverse Bag Fill (11-22): the grid from the top left, the combined empty slot last (Bags.lua Bags.Reverse);
-- not with Category Rows, whose headers sit above their sections
S:Row{ key = "bl.bagReverse", half = true, tab = "bags", path = "tweaks.bagReverse", apply = RefreshBags,
    disabled = function() return NotCombined() or (ns.Bags and ns.Bags.View and (ns.Bags.View() == "rows" or ns.Bags.View() == "rowsSets")) end }
-- one empty slot with the free count in place of every empty slot (Bags.lua 1c)
S:Row{ key = "bl.bagCombineEmpty", half = true, tab = "bags", path = "tweaks.bagCombineEmpty", apply = RefreshBags, disabled = NotCombined }
-- Bag View (one question: how the bags sort your items): All Items, Category Filters (Bags.lua 4b:
-- a row of buttons by the search box where there's room, else a filter button and drawer; separate
-- bags too), Category Rows, Category Rows + Sets (Bags.lua 1: the combined backpack in sections, +
-- one per equipment set). Bags.View carries the older Category Filters choice over.
S:Row{ key = "bl.bagView", kind = "choice", tab = "bags", path = "tweaks.bagView", disabled = BagAddon,
    choices = { "all", "filters", "rows", "rowsSets" },
    get = function() return ns.Bags and ns.Bags.View and ns.Bags.View() or S:GetPath("tweaks.bagView") or "all" end,
    set = function(v) S:SetPath("tweaks.bagView", v) end,
    resetValue = function() return "all" end,
    apply = function()
        RefreshBags()
        if ns.Bags and ns.Bags.Filter then ns.Bags.Filter.Refresh() end
    end }

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
-- Skin Item Slots: Off, Thin or Thick Borders, and under a line Colour by Rarity (11-20; tweaks.bagRarity,
-- on). Saved as before: tweaks.bagSkinSlots and tweaks.bagThickBorders.
local SKIN_SPEC = { exclusive = { "off" }, tokens = { "thin", "thick", "rarity" }, rivals = { thin = "thick", thick = "thin" }, empty = "off" }
S:Row{ key = "bl.bagSkinSlots", kind = "dropdown", tab = "bags", toggles = SKIN_SPEC,
    choices = { "off", "thin", "thick", { divider = true }, "rarity" },
    apply = RefreshBags, disabled = BagAddon,
    get = function()
        if S:GetPath("tweaks.bagSkinSlots") == false then return "off" end
        local list = { S:GetPath("tweaks.bagThickBorders") and "thick" or "thin" }
        if S:GetPath("tweaks.bagRarity") ~= false then list[#list + 1] = "rarity" end
        return table.concat(list, ",")
    end,
    set = function(value)
        if value == nil or value == "off" or value == "" then S:SetPath("tweaks.bagSkinSlots", false) return end
        local set = ns.Conditions.Set(value, SKIN_SPEC)
        S:SetPath("tweaks.bagSkinSlots", true)
        -- (Colour by Rarity alone keeps a border: thin, the default)
        S:SetPath("tweaks.bagThickBorders", set.thick and true or false)
        S:SetPath("tweaks.bagRarity", set.rarity and true or false)
    end,
    resetValue = function() return "thin,rarity" end }
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
S:Row{ key = "bl.delete", half = true, tab = "bags", path = "tweaks.autoDelete", apply = Refresh }
-- the bags open and close with the character window (Bags.lua 4c; the bank and guild bank always do)
S:Row{ key = "bl.bagWithCharacter", half = true, tab = "bags", path = "tweaks.bagWithCharacter" }
-- Blizzard's clean-up each time the bags open: a tool, so in Tools
S:Row{ key = "bl.bagAutoSort", half = true, tab = "bags", path = "tweaks.bagAutoSort", disabled = BagAddon }
-- clams, loot bags and opened lockboxes open themselves (Bags.lua 1d; not beside another bag addon)
S:Row{ key = "bl.bagAutoOpen", half = true, tab = "bags", path = "tweaks.bagAutoOpen", disabled = BagAddon,
    apply = function() if ns.Bags and ns.Bags.AutoOpen then ns.Bags.AutoOpen.Next() end end }

-- VENDOR (from Quality of Life, 11-20): selling, repairing and buying; the switches stay in tweaks.*
S:Row{ key = "qol.repair", half = true, module = "bl", tab = "bags", section = "qol.vendor", path = "tweaks.autoRepair", apply = Refresh }
-- the guild bank pays Auto Repair first; greyed with Auto Repair off
S:Row{ key = "qol.repairGuild", half = true, module = "bl", tab = "bags", section = "qol.vendor", path = "tweaks.repairGuild",
    disabled = function() return not S:GetPath("tweaks.autoRepair") end }
S:Row{ key = "qol.sellJunk", half = true, module = "bl", tab = "bags", section = "qol.vendor", path = "tweaks.sellJunk", apply = Refresh }
S:Row{ key = "qol.merchantKnown", half = true, module = "bl", tab = "bags", section = "qol.vendor", path = "tweaks.merchantKnown", apply = Refresh }
S:Row{ key = "qol.bulkBuy", half = true, module = "bl", tab = "bags", section = "qol.vendor", path = "tweaks.bulkBuy", apply = Refresh }
S:Row{ key = "qol.merchantWide", half = true, module = "bl", tab = "bags", section = "qol.vendor", path = "tweaks.merchantWide", reload = true }

-- LOOTING ----------------------------------------
S:Row{ key = "bl.fastLoot", half = true, tab = "looting", path = "tweaks.fasterLoot", apply = Refresh }
S:Row{ key = "bl.skipLoot", half = true, tab = "looting", path = "tweaks.skipLootConfirm" }
-- Loot Roll Window: FlareUI's roll window in place of Blizzard's roll frames (LootRolls.lua);
-- placed in Edit Mode. Its own section, alone, so a full row. On and off take a reload.
S:Row{ key = "bl.lootRolls", tab = "looting", path = "tweaks.lootRolls", reload = true }
-- (11-23, Malkkav: no Background Opacity: the window reads badly see-through)
-- Loot Window (PR #146 by Xentinus; 11-23 Malkkav: built like the loot roll window, no look options of
-- its own): FlareUI's loot window in place of Blizzard's (LootWindow.lua). Its item marks follow the
-- Bags options; Show Free Bag Slots is its one extra. On and off take a reload.
S:Row{ key = "bl.lootWindow", half = true, tab = "looting", path = "tweaks.lootWindow", reload = true }
S:Row{ key = "bl.lootWindowFreeSlots", half = true, tab = "looting", path = "tweaks.lootWindowFreeSlots",
    disabled = function() return not S:GetPath("tweaks.lootWindow") end,
    apply = function() if ns.LootWindow and ns.LootWindow.Refresh then ns.LootWindow:Refresh() end end }
-- Loot Feed: what you loot floats up beside you (LootFeed.lua); placed in Edit Mode
-- Loot Feed (11-20, was a switch): Off, Square Icons or Round Icons. Saved as before: tweaks.lootFeed,
-- and the shape in tweaks.lootFeedIcons (square unset). Turning it on or off asks for a reload; the shape is live.
local startFeed
S:Row{ key = "bl.lootFeed", kind = "choice", tab = "looting", choices = { "off", "square", "round" },
    get = function()
        if not S:GetPath("tweaks.lootFeed") then return "off" end
        return S:GetPath("tweaks.lootFeedIcons") == "round" and "round" or "square"
    end,
    set = function(value)
        if startFeed == nil then startFeed = S:GetPath("tweaks.lootFeed") and true or false end
        local on = value == "square" or value == "round"
        S:SetPath("tweaks.lootFeed", on)
        if on then S:SetPath("tweaks.lootFeedIcons", value) end
        S:TrackReload("bl.lootFeed", on, startFeed)
    end,
    resetValue = function() return "off" end }
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
    -- Item Level's numbers, in the bags, on the character sheet and in the loot window: shown while
    -- it's on
    { key = "itemLevel", path = "tweaks.bagItemLevelFont", optional = true,
      hidden = function() return not S:GetPath("tweaks.bagItemLevel") end },
    -- the free bag slots on the backpack button (too small to read)
    { key = "freeSlots", path = "tweaks.bagFreeSlotsFont", optional = true },
    -- the gold, silver and copper at the bags' foot
    { key = "money", path = "tweaks.bagMoneyFont", optional = true, disabled = BagAddon },
}, apply = function()
    if ns.Bags and ns.Bags.Refresh then ns.Bags:Refresh() end
    if ns.Bags and ns.Bags.StyleFreeSlots then ns.Bags.StyleFreeSlots() end
    -- (the loot window's item levels take the Item Level font too)
    if ns.LootWindow and ns.LootWindow.ApplyFont then ns.LootWindow:ApplyFont() end
end }
-- the loot roll window (and the loot window, which takes its font) and the loot feed in a section of
-- their own (Loot Rolls)
S:FontRows{ module = "bl", tab = "fonts", section = "bl.fontsLoot", fonts = {
    { key = "lootRolls", path = "tweaks.lootRollFont" },
    { key = "lootFeed", path = "tweaks.lootFeedFont" },
}, apply = function()
    if ns.LootWindow and ns.LootWindow.ApplyFont then ns.LootWindow:ApplyFont() end
    if ns.LootRolls and ns.LootRolls.ApplyFont then ns.LootRolls:ApplyFont() end
    if ns.LootFeed and ns.LootFeed.ApplyFont then ns.LootFeed:ApplyFont() end
end }
