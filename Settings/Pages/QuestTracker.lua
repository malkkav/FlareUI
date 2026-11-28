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
local function Style() return S:GetPath("objectivetracker.frameStyle") or "custom" end
S:Row{ key = "qt.frameStyle", kind = "choice", path = "objectivetracker.frameStyle",
    choices = { "blizzard", "flareui", "custom" }, apply = Refresh }
-- Colour Scheme, under Frame Style: FlareUI and Custom only, FlareUI's by default;
-- the Blizzard style always has Blizzard's (ObjectiveTracker.lua OT.ColorScheme)
S:Row{ key = "qt.colorScheme", kind = "choice", choices = { "blizzard", "flareui" }, apply = Refresh,
    get = function() return S:GetPath("objectivetracker.colorScheme") or "flareui" end,
    set = function(value) S:SetPath("objectivetracker.colorScheme", value) end,
    resetValue = function() return "flareui" end,
    hidden = function() return Style() == "blizzard" end }
S:Row{ key = "qt.opacity", kind = "range", path = "objectivetracker.opacity", choices = S:OpacityChoices(), apply = Refresh,
    hidden = function() return Style() == "blizzard" end }
S:Row{ key = "qt.border", kind = "choice", path = "objectivetracker.borderTexture", choices = S.BorderChoices,
    apply = Refresh, hidden = function() return Style() ~= "custom" end }
-- Hide Scroll Bar (off), last in Frame: FlareUI and Custom only (Blizzard has none)
S:Row{ key = "qt.hideScrollBar", path = "objectivetracker.hideScrollBar", apply = Refresh,
    hidden = function() return Style() == "blizzard" end }

-- one choice over the saved flags: zone (current zone first), zone and level (by level inside each zone),
-- distance, level, progress
S:Row{
    key = "qt.sort", kind = "choice", choices = { "zone", "zonelevel", "distance", "level", "progress" }, apply = Refresh,
    tab = "behaviour", section = "qt.quests",
    get = function()
        if S:GetPath("objectivetracker.sortByLevel") then return "level" end
        if S:GetPath("objectivetracker.sortByProgress") then return "progress" end
        return S:GetPath("objectivetracker.zoneFirst") and (S:GetPath("objectivetracker.zoneLevel") and "zonelevel" or "zone") or "distance"
    end,
    set = function(mode)
        S:SetPath("objectivetracker.sortByLevel", mode == "level")
        S:SetPath("objectivetracker.sortByProgress", mode == "progress")
        S:SetPath("objectivetracker.zoneFirst", mode == "zone" or mode == "zonelevel")
        S:SetPath("objectivetracker.zoneLevel", mode == "zonelevel")
        S:SetPath("objectivetracker.sortByDistance", mode == "distance")
    end,
}

-- invert: a Show switch over a saved "hide" value (Show Quest Level)
local function Display(key, path, invert, disabled)
    S:Row{ key = "qt." .. key, path = "objectivetracker." .. path, invert = invert, apply = Refresh, section = "qt.display", half = true,
        disabled = disabled }
end
-- Zone Headings: a full row, never greyed (Malkkav 11-26: the headings are part of the frame; its
-- description says they show only when sorting by zone). Then in pairs: Show Quest Level | Colour by
-- Difficulty, Quest Tags | Tracked Recipes; Quest Buttons on its own row. (Show Complete Tag is always on.)
S:Row{ key = "qt.zoneHeaders", path = "objectivetracker.zoneHeaders", apply = Refresh, section = "qt.display" }
Display("hideLevel", "hideLevel", true)
Display("colorNames", "colorNames")
Display("tags", "showTags")
Display("recipes", "showRecipes")
-- Header Buttons: the header's filter, sort and the "!" / "?" for Quality of Life's Auto
-- Accept / Auto Turn-In Quests, each its own saved switch; above Quest Buttons. Filter unticked shows
-- every quest again (no button left to switch Zone off).
-- (Auto Accept and Auto Turn-In each their own; both start from the old shared autoButtons)
local HEADER_BUTTONS = { { "filter", "headerFilter" }, { "sort", "headerSort" }, { "accept", "autoAcceptButton" }, { "turnin", "autoTurnInButton" } }
S:Row{ key = "qt.headerButtons", kind = "dropdown", section = "qt.frame",   -- (in Frame, as on Chat)
    choices = { "none", { divider = true }, "filter", "sort", "accept", "turnin" },
    toggles = { exclusive = { "none" }, tokens = { "filter", "sort", "accept", "turnin" }, empty = "none" },
    get = function()
        local list = {}
        for _, b in ipairs(HEADER_BUTTONS) do
            local v = S:GetPath("objectivetracker." .. b[2])
            if v == nil and (b[1] == "accept" or b[1] == "turnin") then v = S:GetPath("objectivetracker.autoButtons") == true end
            if v == true or v == nil then list[#list + 1] = b[1] end
        end
        return #list > 0 and table.concat(list, ",") or "none"
    end,
    set = function(value)
        local on = {}
        for token in tostring(value or ""):gmatch("[^,]+") do on[token] = true end
        for _, b in ipairs(HEADER_BUTTONS) do S:SetPath("objectivetracker." .. b[2], on[b[1]] and true or false) end
        if not on.filter then S:SetPath("objectivetracker.zoneOnly", false) end
    end,
    resetValue = function() return "filter,sort" end,
    apply = Refresh }
-- those two switches changed on the Quality of Life page: the header buttons follow
S:On("RowChanged", function(row)
    if row and (row.key == "qol.autoAcceptQuests" or row.key == "qol.autoTurnInQuests") then Refresh() end
end)
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
-- (Malkkav 11-27) in pairs by job: the order (Completed Last | Focused Quest First), what the tracker lists
-- (Show Untracked Quests | Show Completed Objectives), how quests behave (Collapse Completed | Keep Quest Focus)
Quests("completedLast", "completedLast")
Quests("focusedFirst", "focusedFirst")
S:Row{ key = "qt.untracked", path = "objectivetracker.showUntracked", apply = Refresh, section = "qt.quests", half = true, tab = "behaviour" }
Quests("hideFinished", "hideFinished", true)   -- Show Completed Objectives
Quests("collapseCompleted", "collapseCompleted")
-- (Archy) a newly accepted quest gives the focus back
Quests("keepFocus", "keepFocus")
-- Minimize: one switch sets every instance type
local INSTANCES = { "dungeon", "raid", "pvp", "arena" }
S:Row{
    key = "qt.minimizeButton", apply = Refresh, tab = "behaviour",
    get = function() return S:GetPath("objectivetracker.minimizeStyle") == "button" end,
    set = function(on) S:SetPath("objectivetracker.minimizeStyle", on and "button" or "header") end,
}
-- Auto Minimize: one dropdown of toggles over the same saved values,
-- objectivetracker.autoMinimize.<place> = "minimize" / "none"; In Instances sets every instance type
local MIN_PLACES = { "instances", "combat", "taxi" }
local MIN_SPEC = { exclusive = { "none" }, tokens = MIN_PLACES, empty = "none" }
local function MinOn(place)
    local key = place == "instances" and "dungeon" or place
    return S:GetPath("objectivetracker.autoMinimize." .. key) == "minimize"
end
S:Row{
    key = "qt.autoMinimize", kind = "dropdown", apply = Refresh, tab = "behaviour", toggles = MIN_SPEC,
    choices = { "none", { divider = true }, "instances", "combat", "taxi" },
    get = function()
        local on = {}
        for _, place in ipairs(MIN_PLACES) do if MinOn(place) then on[#on + 1] = place end end
        return #on > 0 and table.concat(on, ",") or "none"
    end,
    set = function(value)
        local set = ns.Conditions.Set(value, MIN_SPEC)
        for _, place in ipairs(INSTANCES) do
            S:SetPath("objectivetracker.autoMinimize." .. place, set.instances and "minimize" or "none")
        end
        S:SetPath("objectivetracker.autoMinimize.combat", set.combat and "minimize" or "none")
        S:SetPath("objectivetracker.autoMinimize.taxi", set.taxi and "minimize" or "none")
    end,
    resetValue = function() return "none" end,
}

local trackerKey = S:BindingAccessors("FLAREUI_TRACKER")
S:Row{ key = "qt.minimizeKey", kind = "keybind", get = trackerKey.get, set = trackerKey.set, section = "qt.minimizeIn", tab = "behaviour" }

-- FONTS (back from Edit Mode)
S:FontRows{ module = "qt", tab = "fonts", section = "qt.fonts", apply = Refresh, fonts = {
    { key = "header", path = "objectivetracker.headerFont" },
    { key = "titles", path = "objectivetracker.titleFont" },
    { key = "objectives", path = "objectivetracker.objectiveFont" },
} }
