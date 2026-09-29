local _, ns = ...

--------------------------------------------------
-- MINIMAP OPTIONS
-- The look is fixed (square map in Blizzard's panel frame, fixed size); a couple of behaviours are
-- user-facing. Player coordinates are Blizzard's own option.
--------------------------------------------------
local function Get(key) return ns.db.profile.minimap[key] end
local function Set(key, val)
    ns.db.profile.minimap[key] = val
    if ns.Minimap then ns.Minimap:Refresh() end
end

ns.Options.args.minimap = {
    type = "group", name = "Minimap", order = 60,
    hidden = function() return not ns.db.profile.minimap.enabled end,
    args = {
        header = { type = "header", name = "Minimap Settings", order = 0 },
        frameGroup = {
            type = "group", name = "General", order = 10, inline = true,
            args = {
                autoZoom = {
                    type = "range", name = "Auto Zoom Out", min = 0, max = 30, step = 1, order = 10, width = 1.2,
                    desc = "Seconds before the map zooms back out after you zoom in. 0 turns it off.",
                    get = function() return Get("autoZoom") end,
                    set = function(_, val) Set("autoZoom", val) end,
                },
                spacer1 = { type = "description", name = "", width = 0.1, order = 11 },
                matchTrackerWidth = {
                    type = "toggle", name = "Match Objective Tracker Width", order = 30, width = 1.5,
                    desc = "Scales the whole objective tracker so its header bars are as wide as the minimap's frame.",
                    get = function() return Get("matchTrackerWidth") end,
                    set = function(_, val) Set("matchTrackerWidth", val) end,
                },
                showDayNight = {
                    type = "toggle", name = "Day/Night Badge", order = 20, width = 1.2,
                    desc = "Shows Blizzard's day/night badge on the map's bottom-left corner.",
                    get = function() return Get("showDayNight") end,
                    set = function(_, val) Set("showDayNight", val) end,
                },
            }
        },
    },
}
