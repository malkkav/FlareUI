local _, ns = ...
local S = ns.Settings

--------------------------------------------------
-- QUALITY OF LIFE
-- Settings for Modules/Tweaks.lua in Gameplay, Nameplates, Interface and Systems (Camera, Gamepad)
-- tabs (Bags & Looting is its own module, BagsLooting.lua). Options that replace Blizzard scripts
-- ask for a reload; the rest apply live.
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
    tabs = { { key = "gameplay" }, { key = "nameplates" }, { key = "interface" }, { key = "systems" }, { key = "fonts" } },
}


-- GAMEPLAY ---------------------------------------
-- three sections, in pairs: Quests & NPCs, Map & Mail, Convenience; a section shows where its first row registers, so keep this order
S:Row{ key = "qol.autoAcceptQuests", half = true, tab = "gameplay", path = "tweaks.autoAcceptQuests" }
S:Row{ key = "qol.autoTurnInQuests", half = true, tab = "gameplay", path = "tweaks.autoTurnInQuests" }
-- the lone banker / vendor / trainer option, and room for loot when the bags are full
S:Row{ key = "qol.skipGossip", half = true, tab = "gameplay", path = "tweaks.skipGossip" }
S:Row{ key = "qol.trainAll", half = true, tab = "gameplay", path = "tweaks.trainAll", apply = Refresh }
-- Map & Mail (back from Interface), above Convenience
S:Row{ key = "qol.way", half = true, tab = "gameplay", section = "qol.mapMail", path = "tweaks.way", reload = true, disabled = WayTaken }
S:Row{ key = "qol.mapFade", half = true, tab = "gameplay", section = "qol.mapMail", path = "tweaks.mapFade", apply = Refresh }
S:Row{ key = "qol.mailBook", half = true, tab = "gameplay", section = "qol.mapMail", path = "tweaks.mailBook", apply = Refresh }
S:Row{ key = "qol.taxiMap", half = true, tab = "gameplay", section = "qol.mapMail", path = "tweaks.taxiMap" }
S:Row{ key = "qol.flightDestinations", half = true, tab = "gameplay", section = "qol.mapMail", path = "tweaks.flightDestinations",
    apply = function() if ns.FlightDestinations then ns.FlightDestinations:Refresh() end end }
S:Row{ key = "qol.zoneLevels", half = true, tab = "gameplay", section = "qol.mapMail", path = "tweaks.zoneLevels" }
-- Coordinates on the World Map: Blizzard's own two options (your position and the
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
-- Convenience, in pairs: accepting for you, casting, fishing, bags and sounds
S:Row{ key = "qol.acceptRes", half = true, tab = "gameplay", section = "qol.other", path = "tweaks.acceptRes" }
S:Row{ key = "qol.acceptSummon", half = true, tab = "gameplay", section = "qol.other", path = "tweaks.acceptSummon" }
S:Row{ key = "qol.keyDown", half = true, tab = "gameplay", section = "qol.other", path = "tweaks.keyDown", apply = Refresh }
S:Row{ key = "qol.craftTotal", half = true, tab = "gameplay", section = "qol.other", path = "tweaks.craftTotal" }
S:Row{ key = "qol.fishCast", half = true, tab = "gameplay", section = "qol.other", path = "tweaks.fishCast", apply = Refresh }
S:Row{ key = "qol.fishSound", half = true, tab = "gameplay", section = "qol.other", path = "tweaks.fishSound", apply = Refresh }
S:Row{ key = "qol.deleteJunkFull", half = true, tab = "gameplay", section = "qol.other", path = "tweaks.deleteJunkWhenFull" }
S:Row{ key = "qol.alerts", half = true, tab = "gameplay", section = "qol.other", path = "tweaks.alertSounds" }
-- The camera: two sliders. Each starts at Blizzard's own value; back on it,
-- FlareUI leaves the game's setting alone (nil). Better Camera's old switch carried over as 2.6 and 50.
local function CameraSlider(key, path, cvar, choices)
    local default = ns.Tweaks and ns.Tweaks.CameraDefault and ns.Tweaks.CameraDefault(cvar)
    S:Row{ key = key, kind = "range", tab = "systems", choices = choices,
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
-- FONTS: Zone Text (the bag and loot feed fonts went with Bags & Looting)
S:FontRows{ module = "qol", tab = "fonts", section = "qol.fonts", fonts = {
    { key = "zoneText", path = "tweaks.zoneTextFont", faceOnly = true },
}, apply = function()
    if ns.ZoneText then ns.ZoneText:Apply() end
end }

-- Controller: the Gamepad mode prompt and rumble (GamepadMode.lua)
S:Row{ key = "qol.gamepadPrompt", half = true, tab = "systems", path = "tweaks.gamepadPrompt" }
-- the quest tracker's own switch (ObjectiveTracker.lua OT.WantedInMode), with the other gamepad ones;
-- greyed while FlareUI's tracker is off, since then Blizzard's shows anyway
S:Row{ key = "qol.padTracker", half = true, tab = "systems", path = "objectivetracker.padBlizzard", reload = true,
    disabled = function() return not S:GetPath("objectivetracker.enabled") end }
S:Row{ key = "qol.rumbleAlerts", half = true, tab = "systems", path = "tweaks.rumbleAlerts" }
S:Row{ key = "qol.rumbleProcs", half = true, tab = "systems", path = "tweaks.rumbleProcs" }

-- INTERFACE --------------------------------------
-- whether enemy plates show at all first, then what goes on them, then their text
-- (Blizzard's own enemy plates, so another nameplate addon does not grey it out)
-- (combat plates, combo points and quest marks move to the Nameplates page while that module is on)
local function NameplatesOn() return ns.Nameplates ~= nil and S:GetPath("nameplates.enabled") and true or false end   -- (the module may be absent)
S:Row{ key = "qol.npCombat", tab = "nameplates", path = "tweaks.combatPlates", apply = Refresh, hidden = NameplatesOn }
-- friendly players' plates only in a fight (Blizzard's plates too)
S:Row{ key = "qol.npCombatFriendly", tab = "nameplates", path = "tweaks.combatFriendly", apply = Refresh, hidden = NameplatesOn }
S:Row{ key = "qol.npCombo", tab = "nameplates", path = "tweaks.nameplateCombo", apply = Refresh, disabled = NameplateAddon, hidden = NameplatesOn }
S:Row{ key = "qol.npQuest", tab = "nameplates", path = "tweaks.nameplateQuest", apply = Refresh, disabled = QuestBadgeTaken, hidden = NameplatesOn }
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

S:Row{ key = "qol.hideErrors", half = true, tab = "interface", path = "tweaks.hideErrors", reload = true }
S:Row{ key = "qol.hideZoneText", half = true, tab = "interface", path = "tweaks.hideZoneText", reload = true }
S:Row{ key = "qol.hideTips", half = true, tab = "interface", path = "tweaks.hideTips", apply = Refresh }
S:Row{ key = "qol.hideLootAlerts", half = true, tab = "interface", path = "tweaks.hideLootAlerts", apply = Refresh }
S:Row{ key = "qol.hideFrameNumbers", half = true, tab = "interface", path = "tweaks.hidePortraitNumbers", apply = Refresh }
-- (from Action Bars, they aren't bars) the main bar's gryphons and the raid manager. Their
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
    end,
    resetValue = function() return "shown" end }
S:Row{ key = "ab.hideRaidManager", module = "qol", tab = "interface", section = "qol.hideClutter", ignoreModule = true, half = true,
    path = "visibility.hideRaidManager", apply = BarsRefresh }
