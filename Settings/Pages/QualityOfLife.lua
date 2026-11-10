local _, ns = ...
local L = ns.L
local S = ns.Settings

--------------------------------------------------
-- QUALITY OF LIFE
-- Settings for Modules/Tweaks.lua in Gameplay, Interface and Advanced tabs. Options that replace
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
    key = "qol", group = "Tools", order = 20, enabled = "tweaks.enabled",
    tabs = { { key = "gameplay" }, { key = "interface" }, { key = "advanced" } },
}

-- ADVANCED ---------------------------------------
-- Sync Blizz UI: copies one character's Blizzard settings to the others
S:Row{ key = "qol.sync", tab = "advanced", path = "tweaks.syncUI", reload = true, section = "qol.syncBlizzUi" }
S:Row{
    key = "qol.source", kind = "button", tab = "advanced", parent = "qol.sync", section = "qol.syncBlizzUi",
    labelFn = function()
        local label = ns.Tweaks and ns.Tweaks.GetSyncSourceLabel and ns.Tweaks:GetSyncSourceLabel()
        return label and L["Current source: %s"]:format(label) or L["No source yet."]
    end,
    buttonText = L["Make This Character the Source"],
    disabled = function() return ns.Tweaks and ns.Tweaks.IsSyncSource and ns.Tweaks:IsSyncSource() or false end,
    apply = function() ns.ShowDialog("FLAREUI_SYNC_SOURCE") end,
}

-- one switch for moving windows and placing loot rolls / toasts
S:Row{
    key = "qol.move", tab = "advanced", reload = true,
    get = function() return S:GetPath("tweaks.moveAnyFrame") end,
    set = function(on)
        S:SetPath("tweaks.moveAnyFrame", on)
        S:SetPath("tweaks.moveLootToasts", on)
    end,
}

-- GAMEPLAY ---------------------------------------
-- Bags and Looting: the bag rows first (Modules/Bags.lua). Another bag addon greys them all; the
-- layout rows also need Blizzard's Combined Bags.
local function RefreshBags() if ns.Bags then ns.Bags:Refresh() end end
local function BagAddon() return ns.Bags and ns.Bags.GetOtherBagAddon and ns.Bags:GetOtherBagAddon() and true or false end
local function NotCombined() return BagAddon() or not (ns.Bags and ns.Bags:IsCombined()) end
local BAG_COLUMNS = { { 0, L["Default"] } }
for n = 6, 20 do BAG_COLUMNS[#BAG_COLUMNS + 1] = { n, tostring(n) } end
S:Row{ key = "qol.bagColumns", kind = "choice", tab = "gameplay", path = "tweaks.bagColumns", choices = BAG_COLUMNS,
    apply = RefreshBags, disabled = NotCombined }
S:Row{ key = "qol.bagGaps", half = true, tab = "gameplay", path = "tweaks.bagGaps", apply = RefreshBags, disabled = NotCombined }
S:Row{ key = "qol.bagButtons", half = true, tab = "gameplay", path = "tweaks.bagButtons", apply = RefreshBags, disabled = NotCombined }
S:Row{ key = "qol.bagRarityBorders", half = true, tab = "gameplay", path = "tweaks.bagRarityBorders", apply = RefreshBags, disabled = BagAddon }
S:Row{ key = "qol.bagThickBorders", half = true, tab = "gameplay", path = "tweaks.bagThickBorders", apply = RefreshBags, disabled = BagAddon }
S:Row{ key = "qol.bagJunkIcon", half = true, tab = "gameplay", path = "tweaks.bagJunkIcon", apply = RefreshBags, disabled = BagAddon }
S:Row{ key = "qol.bagUpgradeArrow", half = true, tab = "gameplay", path = "tweaks.bagUpgradeArrow", apply = RefreshBags, disabled = BagAddon }
-- two more on what is in your bags (no bag addon greys them: they are not Bags.lua's)
S:Row{ key = "qol.petFood", half = true, tab = "gameplay", path = "tweaks.petFood", apply = Refresh }
S:Row{ key = "qol.delete", half = true, tab = "gameplay", path = "tweaks.autoDelete", apply = Refresh }
S:Row{ key = "qol.fastLoot", half = true, tab = "gameplay", path = "tweaks.fasterLoot", apply = Refresh }
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
-- Convenience, in pairs: quests, the map, NPCs, then fishing
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
S:Row{ key = "qol.skipLoot", half = true, tab = "gameplay", path = "tweaks.skipLootConfirm" }
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
S:Row{ key = "qol.npCombat", tab = "interface", path = "tweaks.combatPlates", apply = Refresh }
S:Row{ key = "qol.npCombo", tab = "interface", path = "tweaks.nameplateCombo", apply = Refresh, disabled = NameplateAddon }
S:Row{ key = "qol.npQuest", tab = "interface", path = "tweaks.nameplateQuest", apply = Refresh, disabled = QuestBadgeTaken }
S:Row{ key = "qol.npNames", tab = "interface", path = "tweaks.nameplateHideNames", apply = Refresh, disabled = NameplateAddon }
-- live when switched on; switching off leaves visible plates' bars wide until Blizzard re-lays
-- them, so the reload bar offers a reload
S:Row{ key = "qol.npLevel", tab = "interface", path = "tweaks.nameplateHideLevel", disabled = NameplateAddon,
    apply = function(on)
        Refresh()
        S:TrackReload("qol.npLevel", on and "on" or "off", "on")
    end }
-- the level moves in front of the name: needs the box hidden and the names shown
S:Row{ key = "qol.npLevelName", tab = "interface", path = "tweaks.nameplateLevelName", parent = "qol.npLevel", apply = Refresh,
    disabled = function()
        return NameplateAddon() or not S:GetPath("tweaks.nameplateHideLevel") or S:GetPath("tweaks.nameplateHideNames") and true or false
    end }

S:Row{ key = "qol.sellJunk", tab = "interface", path = "tweaks.sellJunk", apply = Refresh }
S:Row{ key = "qol.repair", tab = "interface", path = "tweaks.autoRepair", apply = Refresh }
S:Row{ key = "qol.durability", tab = "interface", path = "tweaks.durabilityWarning", apply = Refresh }
S:Row{ key = "qol.merchantKnown", tab = "interface", path = "tweaks.merchantKnown", apply = Refresh }
S:Row{ key = "qol.bulkBuy", tab = "interface", path = "tweaks.bulkBuy", apply = Refresh }

S:Row{ key = "qol.hideErrors", tab = "interface", path = "tweaks.hideErrors", reload = true }
S:Row{ key = "qol.hideZoneText", tab = "interface", path = "tweaks.hideZoneText", reload = true }
S:Row{ key = "qol.hideTips", tab = "interface", path = "tweaks.hideTips", apply = Refresh }
S:Row{ key = "qol.hideFrameNumbers", tab = "interface", path = "tweaks.hidePortraitNumbers", apply = Refresh }
