local _, ns = ...
local S = ns.Settings

--------------------------------------------------
-- QUEST TRACKER
-- Settings for Modules/ObjectiveTracker.lua.
--------------------------------------------------
local function Refresh()
    if ns.ObjectiveTracker and ns.ObjectiveTracker.Refresh then ns.ObjectiveTracker:Refresh() end
end

local function Holder() return _G.FlareUI_ObjectiveTracker end

S:Module{ key = "qt", group = "Info", order = 25, enabled = "objectivetracker.enabled", editMode = Holder, tabs = { { key = "settings" }, { key = "fonts" } } }

-- the tracker stays shown on this page (sample quests when empty) so Frame Opacity can be seen
S:On("PageShown", function(key)
    if ns.ObjectiveTracker and ns.ObjectiveTracker.SetSettingsPreview then ns.ObjectiveTracker:SetSettingsPreview(key == "qt") end
end)

S:Row{ key = "qt.opacity", kind = "choice", path = "objectivetracker.opacity", choices = S:OpacityChoices(), apply = Refresh }
S:Row{ key = "qt.border", kind = "choice", path = "objectivetracker.borderTexture", choices = S.BorderChoices,
    apply = Refresh }

-- one choice over three saved flags: zone (current zone first), distance, level
S:Row{
    key = "qt.sort", kind = "choice", choices = { "zone", "distance", "level" }, apply = Refresh,
    get = function()
        if S:GetPath("objectivetracker.sortByLevel") then return "level" end
        return S:GetPath("objectivetracker.zoneFirst") and "zone" or "distance"
    end,
    set = function(mode)
        S:SetPath("objectivetracker.sortByLevel", mode == "level")
        S:SetPath("objectivetracker.zoneFirst", mode == "zone")
        S:SetPath("objectivetracker.sortByDistance", mode ~= "level")
    end,
}

local function Display(key, path)
    S:Row{ key = "qt." .. key, path = "objectivetracker." .. path, apply = Refresh, section = "qt.display", half = true }
end
Display("zoneHeaders", "zoneHeaders")
Display("completedLast", "completedLast")
Display("tags", "showTags")
Display("wrap", "wrapText")
Display("recipes", "showRecipes")
Display("count", "showCount")
Display("hideEmpty", "hideEmpty")

-- Minimize: one switch sets every instance type
local INSTANCES = { "dungeon", "raid", "pvp", "arena" }
S:Row{
    key = "qt.minimizeButton", apply = Refresh,
    get = function() return S:GetPath("objectivetracker.minimizeStyle") == "button" end,
    set = function(on) S:SetPath("objectivetracker.minimizeStyle", on and "button" or "header") end,
}
S:Row{
    key = "qt.minInstances", apply = Refresh,
    get = function() return S:GetPath("objectivetracker.autoMinimize.dungeon") == "minimize" end,
    set = function(on)
        for _, place in ipairs(INSTANCES) do
            S:SetPath("objectivetracker.autoMinimize." .. place, on and "minimize" or "none")
        end
    end,
}
S:Row{
    key = "qt.minCombat", apply = Refresh,
    get = function() return S:GetPath("objectivetracker.autoMinimize.combat") == "minimize" end,
    set = function(on) S:SetPath("objectivetracker.autoMinimize.combat", on and "minimize" or "none") end,
}

local trackerKey = S:BindingAccessors("FLAREUI_TRACKER")
S:Row{ key = "qt.minimizeKey", kind = "keybind", get = trackerKey.get, set = trackerKey.set, section = "qt.minimizeIn" }

S:FontRows{ module = "qt", tab = "fonts", section = "qt.fonts", apply = Refresh, fonts = {
    { key = "header", path = "objectivetracker.headerFont" },
    { key = "titles", path = "objectivetracker.titleFont" },
    { key = "objectives", path = "objectivetracker.objectiveFont" },
} }
