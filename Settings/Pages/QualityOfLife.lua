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
local function WayTaken()
    return ns.Tweaks and ns.Tweaks.TomTomOwnsWay and ns.Tweaks:TomTomOwnsWay() or false
end

S:Module{
    key = "qol", group = "interface", order = 40, enabled = "tweaks.enabled",
    tabs = { { key = "gameplay" }, { key = "nameplates" }, { key = "interface" }, { key = "fonts" } },
}

-- (Sync Blizz UI, Move Any Window and UI Scale moved to the Settings page, Language.lua, 11-11)

-- GAMEPLAY ---------------------------------------
-- (11-16, UX audit batch 4) three sections, in pairs: Quests & NPCs, Map & Mail, Other (junk, alerts,
-- fishing, key press); a section shows where its first row registers, so keep this order
-- (11-16, Malkkav) Automate Quests: Auto Accept Quests and Auto Turn-In Quests in one switch; both saved
-- flags follow it (Tweaks.lua reads them as before)
S:Row{ key = "qol.autoAcceptQuests", half = true, tab = "gameplay",
    get = function() return S:GetPath("tweaks.autoAcceptQuests") or S:GetPath("tweaks.autoTurnInQuests") or false end,
    set = function(on)
        S:SetPath("tweaks.autoAcceptQuests", on and true or false)
        S:SetPath("tweaks.autoTurnInQuests", on and true or false)
    end,
    resetValue = function() return false end }
-- (11-14, a player's request) the lone banker / vendor / trainer option, and room for loot when the bags are full
S:Row{ key = "qol.skipGossip", half = true, tab = "gameplay", path = "tweaks.skipGossip" }
S:Row{ key = "qol.way", half = true, tab = "gameplay", path = "tweaks.way", reload = true, disabled = WayTaken }
S:Row{ key = "qol.mapFade", half = true, tab = "gameplay", path = "tweaks.mapFade", apply = Refresh }
S:Row{ key = "qol.taxiMap", half = true, tab = "gameplay", path = "tweaks.taxiMap" }
S:Row{ key = "qol.trainAll", half = true, tab = "gameplay", path = "tweaks.trainAll", apply = Refresh }
S:Row{ key = "qol.mailBook", half = true, tab = "gameplay", path = "tweaks.mailBook", apply = Refresh }
-- (11-16, Malkkav) Coordinates on the World Map: Blizzard's own two options (your position and the
-- cursor's) behind one switch, nothing of FlareUI's drawn. Its Interface options show the same values.
local MAP_COORDS = { "worldMapShowPlayerCoords", "worldMapShowCursorCoords" }
S:Row{ key = "qol.mapCoords", half = true, tab = "gameplay", section = "qol.mapMail", ignoreModule = true,
    get = function()
        for _, cvar in ipairs(MAP_COORDS) do if C_CVar.GetCVarBool(cvar) then return true end end
        return false
    end,
    set = function(on)
        for _, cvar in ipairs(MAP_COORDS) do pcall(C_CVar.SetCVar, cvar, on and "1" or "0") end
    end,
    resetValue = function() return false end }
S:Row{ key = "qol.deleteJunkFull", half = true, tab = "gameplay", path = "tweaks.deleteJunkWhenFull" }
S:Row{ key = "qol.alerts", half = true, tab = "gameplay", path = "tweaks.alertSounds" }
S:Row{ key = "qol.fishCast", half = true, tab = "gameplay", path = "tweaks.fishCast", apply = Refresh }
S:Row{ key = "qol.fishSound", half = true, tab = "gameplay", path = "tweaks.fishSound", apply = Refresh }
S:Row{ key = "qol.keyDown", half = true, tab = "gameplay", path = "tweaks.keyDown", apply = Refresh }
-- (11-16) pairs with Cast on Key Press, last in Other
S:Row{ key = "qol.acceptRes", half = true, tab = "gameplay", section = "qol.other", path = "tweaks.acceptRes" }
-- (11-15, Malkkav) Better Camera became two sliders. Each starts at Blizzard's own value; back on it,
-- FlareUI leaves the game's setting alone (nil). Better Camera's old switch carried over as 2.6 and 50.
local function CameraSlider(key, path, cvar, choices)
    local default = ns.Tweaks and ns.Tweaks.CameraDefault and ns.Tweaks.CameraDefault(cvar)
    S:Row{ key = key, kind = "range", tab = "gameplay", choices = choices,
        get = function() return S:GetPath(path) or default or choices[1][1] end,
        set = function(value)
            if default and math.abs(value - default) < 0.001 then value = nil end
            S:SetPath(path, value)
        end,
        resetValue = function() return default end,
        apply = Refresh }
end
local ZOOM_CHOICES, SPEED_CHOICES = {}, {}
for n = 10, 26 do ZOOM_CHOICES[#ZOOM_CHOICES + 1] = { n / 10, ("%.1f"):format(n / 10) } end
for n = 5, 50, 5 do SPEED_CHOICES[#SPEED_CHOICES + 1] = { n, tostring(n) } end
CameraSlider("qol.cameraMaxZoom", "tweaks.cameraMaxZoom", "cameraDistanceMaxZoomFactor", ZOOM_CHOICES)
CameraSlider("qol.cameraZoomSpeed", "tweaks.cameraZoomSpeed", "cameraZoomSpeed", SPEED_CHOICES)
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

S:Row{ key = "qol.sellJunk", half = true, tab = "interface", path = "tweaks.sellJunk", apply = Refresh }
S:Row{ key = "qol.repair", half = true, tab = "interface", path = "tweaks.autoRepair", apply = Refresh }
-- (11-16) the guild bank pays Auto Repair first; greyed with Auto Repair off
S:Row{ key = "qol.repairGuild", half = true, tab = "interface", path = "tweaks.repairGuild",
    disabled = function() return not S:GetPath("tweaks.autoRepair") end }
S:Row{ key = "qol.merchantKnown", half = true, tab = "interface", path = "tweaks.merchantKnown", apply = Refresh }
S:Row{ key = "qol.bulkBuy", half = true, tab = "interface", path = "tweaks.bulkBuy", apply = Refresh }
S:Row{ key = "qol.merchantWide", half = true, tab = "interface", path = "tweaks.merchantWide", reload = true }

S:Row{ key = "qol.hideErrors", half = true, tab = "interface", path = "tweaks.hideErrors", reload = true }
S:Row{ key = "qol.hideZoneText", half = true, tab = "interface", path = "tweaks.hideZoneText", reload = true }
S:Row{ key = "qol.hideTips", half = true, tab = "interface", path = "tweaks.hideTips", apply = Refresh }
S:Row{ key = "qol.hideLootAlerts", half = true, tab = "interface", path = "tweaks.hideLootAlerts", apply = Refresh }
S:Row{ key = "qol.hideFrameNumbers", half = true, tab = "interface", path = "tweaks.hidePortraitNumbers", apply = Refresh }
-- (11-16, Malkkav: from Action Bars, they aren't bars) the main bar's gryphons and the raid manager. Their
-- own modules draw them, so they work with Quality of Life off (ignoreModule). Gryphons: one choice over
-- Hide Gryphons and Gryphons Behind Bars (Behind Bars needs FlareUI's action bars).
local function BarsRefresh()
    if ns.ActionBars and ns.ActionBars.Refresh then ns.ActionBars:Refresh() end
    if ns.Visibility and ns.Visibility.Refresh then ns.Visibility:Refresh() end
end
S:Row{ key = "qol.gryphons", kind = "choice", tab = "interface", section = "qol.hideClutter", ignoreModule = true,
    choices = { "shown", "behind", "hidden" }, apply = BarsRefresh,
    get = function()
        if S:GetPath("visibility.hideEndCaps") then return "hidden" end
        return S:GetPath("actionbars.gryphonsBehind") and "behind" or "shown"
    end,
    set = function(value)
        S:SetPath("visibility.hideEndCaps", value == "hidden")
        S:SetPath("actionbars.gryphonsBehind", value == "behind")
    end }
S:Row{ key = "ab.hideRaidManager", module = "qol", tab = "interface", section = "qol.hideClutter", ignoreModule = true, half = true,
    path = "visibility.hideRaidManager", apply = BarsRefresh }
