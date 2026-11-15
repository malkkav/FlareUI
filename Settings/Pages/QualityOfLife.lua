local _, ns = ...
local L = ns.L
local S = ns.Settings

--------------------------------------------------
-- QUALITY OF LIFE
-- Settings for Modules/Tweaks.lua in Gameplay, Nameplates and Interface tabs (Bags and Looting became
-- its own module, BagsLooting.lua, 11-12). Options that replace
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
-- greys the world map rows while a map addon dresses the map itself
local function MapTaken()
    return ns.WorldMap and ns.WorldMap.Taken() and true or false
end

local function WayTaken()
    return ns.Tweaks and ns.Tweaks.TomTomOwnsWay and ns.Tweaks:TomTomOwnsWay() or false
end

S:Module{
    key = "qol", group = "interface", order = 40, enabled = "tweaks.enabled",
    tabs = { { key = "gameplay" }, { key = "nameplates" }, { key = "interface" }, { key = "fonts" } },
}

-- (Sync Blizz UI, Move Any Window and UI Scale moved to the Settings page, Language.lua, 11-11)

-- GAMEPLAY ---------------------------------------
-- Convenience first, in pairs: quests, the map, NPCs, then fishing
S:Row{ key = "qol.autoAcceptQuests", half = true, tab = "gameplay", path = "tweaks.autoAcceptQuests" }
S:Row{ key = "qol.autoTurnInQuests", half = true, tab = "gameplay", path = "tweaks.autoTurnInQuests" }
-- (11-14, a player's request) the lone banker / vendor / trainer option, and room for loot when the bags are full
S:Row{ key = "qol.skipGossip", half = true, tab = "gameplay", path = "tweaks.skipGossip" }
S:Row{ key = "qol.deleteJunkFull", half = true, tab = "gameplay", path = "tweaks.deleteJunkWhenFull" }
S:Row{ key = "qol.way", half = true, tab = "gameplay", path = "tweaks.way", reload = true, disabled = WayTaken }
S:Row{ key = "qol.mapFade", half = true, tab = "gameplay", path = "tweaks.mapFade", apply = Refresh }
-- the world map (WorldMap.lua); the grip sets Move Any Frame's saved scale, so it needs that on
S:Row{ key = "qol.mapGrip", half = true, tab = "gameplay", path = "tweaks.mapGrip", apply = Refresh,
    disabled = function() return MapTaken() or not S:GetPath("tweaks.moveAnyFrame") end }
S:Row{ key = "qol.mapCoords", half = true, tab = "gameplay", path = "tweaks.mapCoords", apply = Refresh, disabled = MapTaken }
S:Row{ key = "qol.mapNoBackdrop", half = true, tab = "gameplay", path = "tweaks.mapNoBackdrop", apply = Refresh, disabled = MapTaken }
S:Row{ key = "qol.mapZoneLevels", half = true, tab = "gameplay", path = "tweaks.mapZoneLevels", apply = Refresh, disabled = MapTaken }
S:Row{ key = "qol.taxiMap", half = true, tab = "gameplay", path = "tweaks.taxiMap" }
S:Row{ key = "qol.trainAll", half = true, tab = "gameplay", path = "tweaks.trainAll", apply = Refresh }
S:Row{ key = "qol.mailBook", half = true, tab = "gameplay", path = "tweaks.mailBook", apply = Refresh }
S:Row{ key = "qol.alerts", half = true, tab = "gameplay", path = "tweaks.alertSounds" }
S:Row{ key = "qol.fishCast", half = true, tab = "gameplay", path = "tweaks.fishCast", apply = Refresh }
S:Row{ key = "qol.fishSound", half = true, tab = "gameplay", path = "tweaks.fishSound", apply = Refresh }
S:Row{ key = "qol.keyDown", half = true, tab = "gameplay", path = "tweaks.keyDown", apply = Refresh }
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
-- FONTS: Zone Text (the bag and loot feed fonts went with Bags & Looting, 11-12)
S:FontRows{ module = "qol", tab = "fonts", section = "qol.fonts", fonts = {
    { key = "zoneText", path = "tweaks.zoneTextFont", faceOnly = true },
}, apply = function()
    if ns.ZoneText then ns.ZoneText:Apply() end
end }

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
S:Row{ key = "qol.hideLootAlerts", tab = "interface", path = "tweaks.hideLootAlerts", apply = Refresh }
S:Row{ key = "qol.hideFrameNumbers", tab = "interface", path = "tweaks.hidePortraitNumbers", apply = Refresh }
S:Row{ key = "qol.hideFlagCarriers", tab = "interface", path = "tweaks.hideFlagCarriers",
    apply = function() if ns.ApplyFlagCarriers then ns.ApplyFlagCarriers() end end }
