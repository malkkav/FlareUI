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

S:Module{ key = "qt", group = "map", order = 20, enabled = "objectivetracker.enabled", editMode = Holder,
    -- Look (Frame, Display) and Behaviour (Quests with Sort By, Minimize)
    tabs = { { key = "settings" }, { key = "behaviour" }, { key = "fonts" } } }

-- the tracker stays shown on this page (sample quests when empty) so Frame Opacity can be seen
S:On("PageShown", function(key)
    if ns.ObjectiveTracker and ns.ObjectiveTracker.SetSettingsPreview then ns.ObjectiveTracker:SetSettingsPreview(key == "qt") end
end)

-- (Blizzard's Tracker in Gamepad Mode is on the Quality of Life page, under Gamepad)
-- Frame Style first: Blizzard (strips, no background or border), FlareUI (strips on FlareUI's frame,
-- the default) or Custom (Frame Opacity and Border as chosen). Opacity hides with Blizzard, Border with
-- both Blizzard and FlareUI.
local function Style() return S:GetPath("objectivetracker.frameStyle") or "flareui" end
S:Row{ key = "qt.frameStyle", kind = "choice", path = "objectivetracker.frameStyle",
    choices = { "blizzard", "flareui", "custom" }, apply = Refresh }
S:Row{ key = "qt.opacity", kind = "range", path = "objectivetracker.opacity", choices = S:OpacityChoices(), apply = Refresh,
    hidden = function() return Style() == "blizzard" end }
S:Row{ key = "qt.border", kind = "choice", path = "objectivetracker.borderTexture", choices = S.BorderChoices,
    apply = Refresh, hidden = function() return Style() ~= "custom" end }

-- one choice over four saved flags: zone (current zone first), distance, level, progress
S:Row{
    key = "qt.sort", kind = "choice", choices = { "zone", "distance", "level", "progress" }, apply = Refresh,
    tab = "behaviour", section = "qt.quests",
    get = function()
        if S:GetPath("objectivetracker.sortByLevel") then return "level" end
        if S:GetPath("objectivetracker.sortByProgress") then return "progress" end
        return S:GetPath("objectivetracker.zoneFirst") and "zone" or "distance"
    end,
    set = function(mode)
        S:SetPath("objectivetracker.sortByLevel", mode == "level")
        S:SetPath("objectivetracker.sortByProgress", mode == "progress")
        S:SetPath("objectivetracker.zoneFirst", mode == "zone")
        S:SetPath("objectivetracker.sortByDistance", mode == "distance")
    end,
}

-- invert: a Show switch over a saved "hide" value (Show Quest Level)
local function Display(key, path, invert)
    S:Row{ key = "qt." .. key, path = "objectivetracker." .. path, invert = invert, apply = Refresh, section = "qt.display", half = true }
end
-- in pairs:
-- Zone Headings | Show Quest Level, Colour by Difficulty | Quest Tags, Tracked Recipes | Show Complete
-- Tag; then Quest Buttons on its own row
Display("zoneHeaders", "zoneHeaders")
Display("hideLevel", "hideLevel", true)
Display("colorNames", "colorNames")
Display("tags", "showTags")
Display("recipes", "showRecipes")
-- on by default: off, finished quests look like any other
Display("completeTag", "showCompleteTag")
-- Quest Buttons: the buttons before each title, as many as you like; each its own saved switch
local QUEST_BUTTONS = { { "icon", "questIcons" }, { "focus", "focusButtons" }, { "voice", "playButtons" } }
S:Row{ key = "qt.questButtons", kind = "dropdown", section = "qt.display",
    choices = { "none", { divider = true }, "icon", "focus", "voice" },
    -- (Quest Icon and Focus Button both focus the quest: ticking one unticks the other)
    toggles = { exclusive = { "none" }, tokens = { "icon", "focus", "voice" }, empty = "none",
        rivals = { icon = "focus", focus = "icon" } },
    get = function()
        local list = {}
        for _, b in ipairs(QUEST_BUTTONS) do
            if S:GetPath("objectivetracker." .. b[2]) then list[#list + 1] = b[1] end
        end
        return #list > 0 and table.concat(list, ",") or "none"
    end,
    set = function(value)
        local on = {}
        for token in tostring(value or ""):gmatch("[^,]+") do on[token] = true end
        for _, b in ipairs(QUEST_BUTTONS) do S:SetPath("objectivetracker." .. b[2], on[b[1]] and true or false) end
    end,
    resetValue = function() return "none" end,
    apply = Refresh }

local function Quests(key, path, invert)
    S:Row{ key = "qt." .. key, path = "objectivetracker." .. path, invert = invert, apply = Refresh, section = "qt.quests", half = true,
        tab = "behaviour" }
end
-- the order (Completed Last | Focused Quest First), then the two about completed quests
Quests("completedLast", "completedLast")
Quests("focusedFirst", "focusedFirst")
Quests("collapseCompleted", "collapseCompleted")
Quests("hideFinished", "hideFinished", true)   -- Show Completed Objectives
-- Show Untracked Quests needs zone headings (none by level or by progress either).
local function NoHeadings()
    return not S:GetPath("objectivetracker.zoneHeaders") or S:GetPath("objectivetracker.sortByLevel")
        or S:GetPath("objectivetracker.sortByProgress")
end
S:Row{ key = "qt.untracked", path = "objectivetracker.showUntracked", apply = Refresh, section = "qt.quests", half = true, tab = "behaviour",
    disabled = NoHeadings }
-- (Archy) a newly accepted quest gives the focus back; paired with Show Untracked Quests
Quests("keepFocus", "keepFocus")
-- Minimize: one switch sets every instance type
local INSTANCES = { "dungeon", "raid", "pvp", "arena" }
S:Row{
    key = "qt.minimizeButton", apply = Refresh, tab = "behaviour",
    get = function() return S:GetPath("objectivetracker.minimizeStyle") == "button" end,
    set = function(on) S:SetPath("objectivetracker.minimizeStyle", on and "button" or "header") end,
}
S:Row{
    key = "qt.minInstances", apply = Refresh, tab = "behaviour",
    get = function() return S:GetPath("objectivetracker.autoMinimize.dungeon") == "minimize" end,
    set = function(on)
        for _, place in ipairs(INSTANCES) do
            S:SetPath("objectivetracker.autoMinimize." .. place, on and "minimize" or "none")
        end
    end,
}
S:Row{
    key = "qt.minCombat", apply = Refresh, tab = "behaviour",
    get = function() return S:GetPath("objectivetracker.autoMinimize.combat") == "minimize" end,
    set = function(on) S:SetPath("objectivetracker.autoMinimize.combat", on and "minimize" or "none") end,
}

local trackerKey = S:BindingAccessors("FLAREUI_TRACKER")
S:Row{ key = "qt.minimizeKey", kind = "keybind", get = trackerKey.get, set = trackerKey.set, section = "qt.minimizeIn", tab = "behaviour" }

-- FONTS (back from Edit Mode)
S:FontRows{ module = "qt", tab = "fonts", section = "qt.fonts", apply = Refresh, fonts = {
    { key = "header", path = "objectivetracker.headerFont" },
    { key = "titles", path = "objectivetracker.titleFont" },
    { key = "objectives", path = "objectivetracker.objectiveFont" },
} }
