local _, ns = ...
local L = ns.L

--------------------------------------------------
-- MINIMAP OPTIONS
-- The look is fixed (square map in Blizzard's panel frame, fixed size); a couple of behaviours are
-- user-facing. Player coordinates are Blizzard's own option.
--------------------------------------------------
local function Get(key) return ns.db.profile.minimap[key] end

-- FlareUI's Quest Tracker module is on: Blizzard's tracker is parked, nothing to match
local function OwnTrackerOn()
    local own = ns.db.profile.objectivetracker
    return own and own.enabled or false
end
local function Set(key, val)
    ns.db.profile.minimap[key] = val
    if ns.Minimap then ns.Minimap:Refresh() end
end

ns.Options.args.minimap = {
    type = "group", name = L["Minimap"], order = 60,
    hidden = function() return not ns.db.profile.minimap.enabled end,
    args = {
        header = { type = "header", name = L["Minimap Settings"], order = 0 },
        frameGroup = {
            type = "group", name = L["General"], order = 10, inline = true,
            args = {
                clockStats = {
                    type = "toggle", name = L["FPS & Latency on Clock"], order = 10, width = 1.2,
                    desc = L["Adds your framerate and latency to the clock's tooltip."],
                    get = function() return Get("clockStats") end,
                    set = function(_, val) Set("clockStats", val) end,
                },
                spacer1 = { type = "description", name = "", width = 0.1, order = 11 },
                showDayNight = {
                    type = "toggle", name = L["Day/Night Badge"], order = 20, width = 1.2,
                    desc = L["Shows Blizzard's day/night badge on the map's bottom-left corner."],
                    -- the badge is the Addon Button Bag's button, so it stays while the bag is on
                    disabled = function() return Get("buttonBag") ~= false end,
                    get = function() return Get("showDayNight") end,
                    set = function(_, val) Set("showDayNight", val) end,
                },
                spacer2 = { type = "description", name = "", width = 0.1, order = 21, hidden = OwnTrackerOn },
                matchTrackerWidth = {
                    type = "toggle", name = L["Match Objective Tracker Width"], order = 30, width = 1.5,
                    -- only for Blizzard's tracker: with FlareUI's on, Blizzard's is parked
                    hidden = OwnTrackerOn, disabled = OwnTrackerOn,
                    desc = L["Scales the whole objective tracker so its header bars are as wide as the minimap's frame."],
                    get = function() return Get("matchTrackerWidth") end,
                    set = function(_, val) Set("matchTrackerWidth", val) end,
                },
                break1 = { type = "description", name = " ", order = 35, width = "full" },
                buttonBag = {
                    type = "toggle", name = L["Addon Button Bag"], order = 37, width = 1.2,
                    desc = L["Gathers every addon's minimap button, and the addons of Blizzard's addon compartment, into a bag: click the day/night badge to open it."],
                    get = function() return Get("buttonBag") ~= false end,
                    set = function(_, val)
                        ns.db.profile.minimap.buttonBag = val
                        ns.ShowDialog("FLAREUI_RELOAD")
                    end,
                },
                spacer3 = { type = "description", name = "", width = 0.1, order = 38 },
                autoZoom = {
                    type = "range", name = L["Auto Zoom Out"], min = 0, max = 30, step = 1, order = 40, width = 1.2,
                    desc = L["Seconds before the map zooms back out after you zoom in. 0 turns it off."],
                    get = function() return Get("autoZoom") end,
                    set = function(_, val) Set("autoZoom", val) end,
                },
            }
        },
    },
}
