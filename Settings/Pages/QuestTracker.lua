local _, ns = ...
local S = ns.Settings

--------------------------------------------------
-- QUEST TRACKER (Modules/ObjectiveTracker.lua). Fixed, no option: quest count, hide when empty, zone
-- headings, completed last, quest level, long text wrapped, tracked recipes; no quest tags; no
-- change in the open world or in cities. The border.
--------------------------------------------------
local function Refresh()
    if ns.ObjectiveTracker and ns.ObjectiveTracker.Refresh then ns.ObjectiveTracker:Refresh() end
end

local function Holder() return _G.FlareUI_ObjectiveTracker end

S:Module{ key = "qt", group = "Info", order = 25, enabled = "objectivetracker.enabled", editMode = Holder }

-- on this page the tracker shows (Edit Mode's sample quests when nothing is tracked), so Frame
-- Opacity can be seen
S:On("PageShown", function(key)
    if ns.ObjectiveTracker and ns.ObjectiveTracker.SetSettingsPreview then ns.ObjectiveTracker:SetSettingsPreview(key == "qt") end
end)

-- how dark the background is (0.5 by default)
S:Row{ key = "qt.opacity", kind = "choice", path = "objectivetracker.opacity", choices = S:OpacityChoices(), apply = Refresh }

-- By zone: the zone you are in first, the other zones by their nearest quest.
-- By distance: the nearest quest first, whatever its zone.
-- By level: the lowest level quest first, whatever its zone.
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

-- Minimize in: instances (dungeon, raid, battleground, arena) and combat
local INSTANCES = { "dungeon", "raid", "pvp", "arena" }
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

-- the key that minimizes and expands it (Bindings.xml), under Combat
local trackerKey = S:BindingAccessors("FLAREUI_TRACKER")
S:Row{ key = "qt.minimizeKey", kind = "keybind", get = trackerKey.get, set = trackerKey.set, section = "qt.minimizeIn" }
