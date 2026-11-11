local _, ns = ...
local L = ns.L
local S = ns.Settings

--------------------------------------------------
-- QUALITY OF LIFE
-- Settings for Modules/Tweaks.lua in Gameplay, Bags, Nameplates and Interface tabs. Options that replace
-- Blizzard scripts ask for a reload; the rest apply live.
--------------------------------------------------
local function Refresh()
    if ns.Tweaks then ns.Tweaks:Refresh() end
end

-- greys the nameplate rows while another nameplate addon draws the plates
local function NameplateAddon()
    return ns.Tweaks and ns.Tweaks.GetNameplateAddon and ns.Tweaks:GetNameplateAddon() and true or false
end

-- greys the quest badge row too while Questie draws its own nameplate icons
local function QuestBadgeTaken()
    return NameplateAddon() or (ns.Tweaks and ns.Tweaks.QuestieHasNameplateIcons and ns.Tweaks:QuestieHasNameplateIcons()) or false
end

-- greys the /way row: TomTom keeps the command
local function WayTaken()
    return ns.Tweaks and ns.Tweaks.TomTomOwnsWay and ns.Tweaks:TomTomOwnsWay() or false
end

S:Module{
    key = "qol", group = "interface", order = 40, enabled = "tweaks.enabled",
    tabs = { { key = "gameplay" }, { key = "bags" }, { key = "nameplates" }, { key = "interface" }, { key = "fonts" } },
}

-- (Sync Blizz UI, Move Any Window and UI Scale moved to the Settings page, Language.lua, 11-11)

-- GAMEPLAY ---------------------------------------
-- Convenience first, in pairs: quests, the map, NPCs, then fishing
S:Row{ key = "qol.autoAcceptQuests", half = true, tab = "gameplay", path = "tweaks.autoAcceptQuests" }
S:Row{ key = "qol.autoTurnInQuests", half = true, tab = "gameplay", path = "tweaks.autoTurnInQuests" }
S:Row{ key = "qol.way", half = true, tab = "gameplay", path = "tweaks.way", reload = true, disabled = WayTaken }
S:Row{ key = "qol.mapFade", half = true, tab = "gameplay", path = "tweaks.mapFade", apply = Refresh }
S:Row{ key = "qol.taxiMap", half = true, tab = "gameplay", path = "tweaks.taxiMap" }
S:Row{ key = "qol.trainAll", half = true, tab = "gameplay", path = "tweaks.trainAll", apply = Refresh }
S:Row{ key = "qol.mailBook", half = true, tab = "gameplay", path = "tweaks.mailBook", apply = Refresh }
S:Row{ key = "qol.alerts", half = true, tab = "gameplay", path = "tweaks.alertSounds" }
S:Row{ key = "qol.fishCast", half = true, tab = "gameplay", path = "tweaks.fishCast", apply = Refresh }
S:Row{ key = "qol.fishSound", half = true, tab = "gameplay", path = "tweaks.fishSound", apply = Refresh }
-- one switch for further and faster camera zoom
S:Row{
    key = "qol.camera", tab = "gameplay",
    get = function() return S:GetPath("tweaks.maxCameraZoom") end,
    set = function(on)
        S:SetPath("tweaks.maxCameraZoom", on)
        S:SetPath("tweaks.fasterCameraZoom", on)
    end,
    apply = Refresh,
}
-- a bronze ring round the cursor (MouseRing.lua), live
local function RefreshRing() if ns.MouseRing then ns.MouseRing:Refresh() end end
local function NoRing() return (S:GetPath("tweaks.mouseRingShow") or "off") == "off" end
local RING_SIZES = {}
for size = 20, 120, 10 do RING_SIZES[#RING_SIZES + 1] = size end
-- one choice turns it on and says when it shows; the rest sit under it
S:Row{ key = "qol.mouseRingShow", kind = "choice", tab = "gameplay", path = "tweaks.mouseRingShow",
    choices = { "off", "always", "combat", "rightclick" }, apply = RefreshRing }
S:Row{ key = "qol.mouseRingSize", kind = "choice", tab = "gameplay", parent = "qol.mouseRingShow", path = "tweaks.mouseRingSize",
    choices = RING_SIZES, apply = RefreshRing, disabled = NoRing }
S:Row{ key = "qol.mouseRingThickness", kind = "choice", tab = "gameplay", parent = "qol.mouseRingShow", path = "tweaks.mouseRingThickness",
    choices = { 1, 2, 3, 4, 5, 6, 8, 10 }, apply = RefreshRing, disabled = NoRing }
S:Row{ key = "qol.mouseRingClassColor", half = true, tab = "gameplay", parent = "qol.mouseRingShow", path = "tweaks.mouseRingClassColor",
    apply = RefreshRing, disabled = NoRing }
-- no ring while turning: not with While Right-Clicking, which shows it then
S:Row{ key = "qol.mouseRingHideTurning", half = true, tab = "gameplay", parent = "qol.mouseRingShow", path = "tweaks.mouseRingHideTurning",
    apply = RefreshRing, disabled = function() return NoRing() or S:GetPath("tweaks.mouseRingShow") == "rightclick" end }
-- the arcs and the range colour, in pairs
S:Row{ key = "qol.mouseRingCast", half = true, tab = "gameplay", parent = "qol.mouseRingShow", path = "tweaks.mouseRingCast",
    apply = RefreshRing, disabled = NoRing }
S:Row{ key = "qol.mouseRingGCD", half = true, tab = "gameplay", parent = "qol.mouseRingShow", path = "tweaks.mouseRingGCD",
    apply = RefreshRing, disabled = NoRing }
S:Row{ key = "qol.mouseRingSwing", half = true, tab = "gameplay", parent = "qol.mouseRingShow", path = "tweaks.mouseRingSwing",
    apply = RefreshRing, disabled = NoRing }
S:Row{ key = "qol.mouseRingRange", half = true, tab = "gameplay", parent = "qol.mouseRingShow", path = "tweaks.mouseRingRange",
    apply = RefreshRing, disabled = NoRing }

-- BAGS AND LOOTING ------------------------------
-- Bags: the bag rows (Modules/Bags.lua). Another bag addon greys them all; the layout rows also need
-- Blizzard's Combined Bags.
local function RefreshBags() if ns.Bags then ns.Bags:Refresh() end end
local function BagAddon() return ns.Bags and ns.Bags.GetOtherBagAddon and ns.Bags:GetOtherBagAddon() and true or false end
local function NotCombined() return BagAddon() or not (ns.Bags and ns.Bags:IsCombined()) end
local BAG_COLUMNS = { { 0, L["Default"] } }
for n = 6, 20 do BAG_COLUMNS[#BAG_COLUMNS + 1] = { n, tostring(n) } end
S:Row{ key = "qol.bagColumns", kind = "range", tab = "bags", path = "tweaks.bagColumns", choices = BAG_COLUMNS,
    apply = RefreshBags, disabled = NotCombined }
S:Row{ key = "qol.bagGaps", half = true, tab = "bags", path = "tweaks.bagGaps", apply = RefreshBags, disabled = NotCombined }
S:Row{ key = "qol.bagButtons", half = true, tab = "bags", path = "tweaks.bagButtons", apply = RefreshBags, disabled = NotCombined }
-- the keyring and the crafting bag as sections of the combined backpack (Bags.lua 0)
S:Row{ key = "qol.bagKeyring", half = true, tab = "bags", path = "tweaks.bagKeyring", apply = RefreshBags, disabled = NotCombined }
S:Row{ key = "qol.bagReagent", half = true, tab = "bags", path = "tweaks.bagReagent", apply = RefreshBags, disabled = NotCombined }
S:Row{ key = "qol.bagCategoryFilters", tab = "bags", path = "tweaks.bagCategoryFilters", apply = RefreshBags, disabled = BagAddon }
S:Row{ key = "qol.bagRarityBorders", half = true, tab = "bags", path = "tweaks.bagRarityBorders", apply = RefreshBags, disabled = BagAddon }
S:Row{ key = "qol.bagThickBorders", half = true, tab = "bags", path = "tweaks.bagThickBorders", apply = RefreshBags, disabled = BagAddon }
S:Row{ key = "qol.bagJunkIcon", half = true, tab = "bags", path = "tweaks.bagJunkIcon", apply = RefreshBags, disabled = BagAddon }
S:Row{ key = "qol.bagUpgradeArrow", half = true, tab = "bags", path = "tweaks.bagUpgradeArrow", apply = RefreshBags, disabled = BagAddon }
-- two more on what is in your bags (no bag addon greys them: they are not Bags.lua's)
S:Row{ key = "qol.petFood", half = true, tab = "bags", path = "tweaks.petFood", apply = Refresh }
S:Row{ key = "qol.delete", half = true, tab = "bags", path = "tweaks.autoDelete", apply = Refresh }
-- Looting
S:Row{ key = "qol.fastLoot", half = true, tab = "bags", path = "tweaks.fasterLoot", apply = Refresh }
S:Row{ key = "qol.skipLoot", half = true, tab = "bags", path = "tweaks.skipLootConfirm" }
-- Loot Feed: what you loot floats up beside you (LootFeed.lua); placed in Edit Mode
S:Row{ key = "qol.lootFeed", tab = "bags", path = "tweaks.lootFeed", reload = true }
local LOOT_QUALITY = {}
-- Poor (0) is the lowest, so it lets every item through: named All Items (a player read it as grey only)
for quality = 0, 4 do
    LOOT_QUALITY[#LOOT_QUALITY + 1] = { quality, quality == 0 and L["All Items"] or _G["ITEM_QUALITY" .. quality .. "_DESC"] or tostring(quality) }
end
local function NoFeed() return not S:GetPath("tweaks.lootFeed") end
S:Row{ key = "qol.lootFeedQuality", kind = "choice", tab = "bags", parent = "qol.lootFeed", path = "tweaks.lootFeedQuality",
    choices = LOOT_QUALITY, disabled = NoFeed }
S:Row{ key = "qol.lootFeedMoney", tab = "bags", parent = "qol.lootFeed", path = "tweaks.lootFeedMoney", disabled = NoFeed }
S:Row{ key = "qol.lootFeedSkills", tab = "bags", parent = "qol.lootFeed", path = "tweaks.lootFeedSkills", disabled = NoFeed }
S:Row{ key = "qol.lootFeedPosition", kind = "choice", tab = "bags", parent = "qol.lootFeed", path = "tweaks.lootFeedPosition",
    choices = { "cursor", "placed" }, disabled = NoFeed,
    apply = function() if ns.LootFeed and ns.LootFeed.Refresh then ns.LootFeed:Refresh() end end }
-- FONTS: the loot feed's lines (live: lines already up and the Edit Mode samples take it too)
S:FontRows{ module = "qol", tab = "fonts", section = "qol.fonts", fonts = {
    { key = "lootFeed", path = "tweaks.lootFeedFont" },
}, apply = function() if ns.LootFeed and ns.LootFeed.ApplyFont then ns.LootFeed:ApplyFont() end end }

-- Controller: the Gamepad mode prompt and rumble (GamepadMode.lua)
S:Row{ key = "qol.gamepadPrompt", half = true, tab = "gameplay", path = "tweaks.gamepadPrompt" }
-- the quest tracker's own switch (ObjectiveTracker.lua OT.WantedInMode), with the other gamepad ones;
-- greyed while FlareUI's tracker is off, since then Blizzard's shows anyway
S:Row{ key = "qol.padTracker", half = true, tab = "gameplay", path = "objectivetracker.padBlizzard", reload = true,
    disabled = function() return not S:GetPath("objectivetracker.enabled") end }
S:Row{ key = "qol.rumbleAlerts", half = true, tab = "gameplay", path = "tweaks.rumbleAlerts" }
S:Row{ key = "qol.rumbleProcs", half = true, tab = "gameplay", path = "tweaks.rumbleProcs" }

-- INTERFACE --------------------------------------
-- whether enemy plates show at all first, then what goes on them, then their text
-- (Blizzard's own enemy plates, so another nameplate addon does not grey it out)
S:Row{ key = "qol.npCombat", tab = "nameplates", path = "tweaks.combatPlates", apply = Refresh }
S:Row{ key = "qol.npCombo", tab = "nameplates", path = "tweaks.nameplateCombo", apply = Refresh, disabled = NameplateAddon }
S:Row{ key = "qol.npQuest", tab = "nameplates", path = "tweaks.nameplateQuest", apply = Refresh, disabled = QuestBadgeTaken }
S:Row{ key = "qol.npNames", tab = "nameplates", path = "tweaks.nameplateHideNames", apply = Refresh, disabled = NameplateAddon }
-- live when switched on; switching off leaves visible plates' bars wide until Blizzard re-lays
-- them, so the reload bar offers a reload
S:Row{ key = "qol.npLevel", tab = "nameplates", path = "tweaks.nameplateHideLevel", disabled = NameplateAddon,
    apply = function(on)
        Refresh()
        S:TrackReload("qol.npLevel", on and "on" or "off", "on")
    end }
-- the level moves in front of the name: needs the box hidden and the names shown
S:Row{ key = "qol.npLevelName", tab = "nameplates", path = "tweaks.nameplateLevelName", parent = "qol.npLevel", apply = Refresh,
    disabled = function()
        return NameplateAddon() or not S:GetPath("tweaks.nameplateHideLevel") or S:GetPath("tweaks.nameplateHideNames") and true or false
    end }

S:Row{ key = "qol.sellJunk", tab = "interface", path = "tweaks.sellJunk", apply = Refresh }
S:Row{ key = "qol.repair", tab = "interface", path = "tweaks.autoRepair", apply = Refresh }
S:Row{ key = "qol.durability", tab = "interface", path = "tweaks.durabilityWarning", apply = Refresh }
S:Row{ key = "qol.merchantKnown", tab = "interface", path = "tweaks.merchantKnown", apply = Refresh }
S:Row{ key = "qol.bulkBuy", tab = "interface", path = "tweaks.bulkBuy", apply = Refresh }
S:Row{ key = "qol.merchantWide", tab = "interface", path = "tweaks.merchantWide", reload = true }

S:Row{ key = "qol.hideErrors", tab = "interface", path = "tweaks.hideErrors", reload = true }
S:Row{ key = "qol.hideZoneText", tab = "interface", path = "tweaks.hideZoneText", reload = true }
S:Row{ key = "qol.hideTips", tab = "interface", path = "tweaks.hideTips", apply = Refresh }
S:Row{ key = "qol.hideFrameNumbers", tab = "interface", path = "tweaks.hidePortraitNumbers", apply = Refresh }
