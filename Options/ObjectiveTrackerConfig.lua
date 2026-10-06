local _, ns = ...
local L = ns.L

--------------------------------------------------
-- QUEST TRACKER OPTIONS (the ObjectiveTracker module)
-- Width and maximum height are set in Edit Mode (FlareUI Quest Tracker), with its position.
--------------------------------------------------
local function DB() return ns.db.profile.objectivetracker end
local function Get(key) return DB()[key] end

local function Set(key)
    return function(_, val)
        DB()[key] = val
        if ns.ObjectiveTracker then ns.ObjectiveTracker:Refresh() end
    end
end

local function Toggle(key, name, order, desc)
    return { type = "toggle", name = name, desc = desc, order = order, width = 1.1,
             get = function() return Get(key) end, set = Set(key) }
end

local SP = function(order) return { type = "description", name = "", width = 0.1, order = order } end
local BR = function(order) return { type = "description", name = " ", order = order, width = "full" } end

local function BorderList()
    local t = {}
    for _, name in ipairs(LibStub("LibSharedMedia-3.0"):List("border")) do t[name] = name end
    return t
end

-- one dropdown per kind of place, in the module's order
local RULES = { none = L["No Change"], minimize = L["Minimize"], expand = L["Expand"] }
local RULE_ORDER = { "none", "minimize", "expand" }
local CONTEXT_NAMES = {
    world = L["Open World"], resting = L["City or Inn"], dungeon = L["Dungeon"], raid = L["Raid"],
    pvp = L["Battleground"], arena = L["Arena"], combat = L["Combat"],
}

local function AutoMinimizeArgs()
    local args = {
        help = { type = "description", order = 1, fontSize = "medium", width = "full",
            name = L["Each rule applies once, when you get there, so you can still open or close the tracker by hand while you stay."] },
    }
    local contexts = (ns.ObjectiveTracker and ns.ObjectiveTracker.CONTEXTS)
        or { "world", "resting", "dungeon", "raid", "pvp", "arena", "combat" }
    for i, context in ipairs(contexts) do
        args[context] = {
            type = "select", name = CONTEXT_NAMES[context], order = i * 10, width = 0.8,
            values = RULES, sorting = RULE_ORDER,
            get = function() return (Get("autoMinimize") or {})[context] or "none" end,
            set = function(_, val)
                local db = DB()
                db.autoMinimize = db.autoMinimize or {}
                db.autoMinimize[context] = val
            end,
        }
        args[context .. "Spacer"] = SP(i * 10 + 1)
    end
    return args
end

ns.Options.args.objectivetracker = {
    type = "group", name = L["Quest Tracker"], order = 57,
    hidden = function() return not ns.db.profile.objectivetracker.enabled end,
    childGroups = "tab",
    args = {
        generalTab = {
            type = "group", name = L["General"], order = 10,
            args = {
                lookGroup = {
                    type = "group", name = L["Frame"], order = 10, inline = true,
                    args = {
                        borderTexture = { type = "select", name = L["Border"], order = 10, width = 1.1, values = BorderList,
                            get = function() return Get("borderTexture") end, set = Set("borderTexture") },
                        spacer1 = SP(11),
                        opacity = { type = "range", name = L["Background Opacity"], order = 20, width = 1.1, min = 0, max = 1, step = 0.05,
                            get = function() return Get("opacity") end, set = Set("opacity") },
                        break1 = BR(25),
                        minimizeStyle = {
                            type = "select", name = L["Minimize Style"], order = 30, width = 1.1,
                            desc = L["What stays on screen while the tracker is minimized."],
                            values = { header = L["Header"], button = L["Button Only"] }, sorting = { "header", "button" },
                            get = function() return Get("minimizeStyle") end, set = Set("minimizeStyle"),
                        },
                        spacer2 = SP(31),
                        showCount = Toggle("showCount", L["Quest Count"], 40, L["Shows how many quests are in your quest log, out of the most you can have, in the header."]),
                        break2 = BR(45),
                        hideEmpty = Toggle("hideEmpty", L["Hide When Empty"], 50, L["Hides the tracker while no quests or recipes are tracked."]),
                    },
                },
                autoGroup = {
                    type = "group", name = L["Auto-Minimize"], order = 20, inline = true,
                    args = AutoMinimizeArgs(),
                },
                contentGroup = {
                    type = "group", name = L["Quests"], order = 30, inline = true,
                    args = {
                        zoneHeaders = Toggle("zoneHeaders", L["Zone Headings"], 10, L["Groups the quests under their zone, as in the quest log."]),
                        spacer1 = SP(11),
                        zoneFirst = Toggle("zoneFirst", L["Current Zone First"], 20, L["Quests of the zone you are in go to the top."]),
                        break1 = BR(25),
                        sortByDistance = Toggle("sortByDistance", L["Nearest First"], 30, L["Orders the quests by distance, nearest first, as you move."]),
                        spacer2 = SP(31),
                        completedLast = Toggle("completedLast", L["Completed Last"], 40, L["Quests ready to turn in move to the bottom of their group."]),
                        break2 = BR(45),
                        showLevel = Toggle("showLevel", L["Quest Level"], 50, L["Shows the quest level in front of its name, colored by difficulty."]),
                        spacer3 = SP(51),
                        showTags = Toggle("showTags", L["Quest Tags"], 60, L["Adds the quest's kind after its level: + elite, g3 group of three, d dungeon, r raid, pvp."]),
                        break3 = BR(65),
                        numbersLast = Toggle("numbersLast", L["Numbers Last"], 70, L["Shows objectives as \"Boar Tusks: 3/8\" instead of \"3/8 Boar Tusks\"."]),
                        spacer4 = SP(71),
                        wrapText = Toggle("wrapText", L["Wrap Long Text"], 80, L["Long quest names and objectives go on to more lines. Off, they are cut to one line."]),
                        break4 = BR(85),
                        showRecipes = Toggle("showRecipes", L["Tracked Recipes"], 90, L["Lists the recipes you track in the profession window, with the reagents you carry."]),
                    },
                },
                highLevelGroup = {
                    type = "group", name = L["High-Level Quests"], order = 40, inline = true,
                    args = {
                        untrackHighLevel = Toggle("untrackHighLevel", L["Untrack High-Level Quests"], 10,
                            L["Quests this many levels above you are untracked when you accept them, and tracked again once you are close enough."]),
                        spacer1 = SP(11),
                        highLevelDiff = { type = "range", name = L["Levels Above You"], order = 20, width = 1.1, min = 1, max = 10, step = 1,
                            disabled = function() return not Get("untrackHighLevel") end,
                            get = function() return Get("highLevelDiff") end, set = Set("highLevelDiff") },
                    },
                },
            },
        },
        fontsTab = {
            type = "group", name = L["Fonts"], order = 20,
            args = {
                headerFont = ns.CreateFontOptions(10, L["Header and Zone Font"], "objectivetracker", "headerFont"),
                titleFont = ns.CreateFontOptions(20, L["Quest Title Font"], "objectivetracker", "titleFont"),
                objectiveFont = ns.CreateFontOptions(30, L["Objective Font"], "objectivetracker", "objectiveFont"),
            },
        },
    },
}
