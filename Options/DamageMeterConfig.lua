local _, ns = ...

--------------------------------------------------
-- DAMAGE METER OPTIONS
-- The look matches the chat frame; background opacity, border and bar texture are user-facing.
--------------------------------------------------
-- every name LibSharedMedia has registered of one media type, FlareUI's and other addons'
local function MediaList(mediaType)
    local t = {}
    for _, name in ipairs(LibStub("LibSharedMedia-3.0"):List(mediaType)) do t[name] = name end
    return t
end

ns.Options.args.damagemeter = {
    type = "group", name = "Damage Meter", order = 30,
    hidden = function() return not ns.db.profile.damagemeter.enabled end,
    args = {
        header = { type = "header", name = "Damage Meter Settings", order = 0 },
        frameGroup = {
            type = "group", name = "Frame", order = 10, inline = true,
            args = {
                opacity = {
                    type = "range", name = "Background Opacity", min = 0, max = 1, step = 0.05, order = 10,
                    get = function() return ns.db.profile.damagemeter.opacity end,
                    set = function(_, val) ns.db.profile.damagemeter.opacity = val; if ns.DamageMeter then ns.DamageMeter:Refresh() end end,
                },
                spacer1 = { type = "description", name = "", width = 0.1, order = 11 },
                borderTexture = {
                    type = "select", name = "Border", order = 20,
                    values = function() return MediaList("border") end,
                    get = function() return ns.db.profile.damagemeter.borderTexture end,
                    set = function(_, val) ns.db.profile.damagemeter.borderTexture = val; if ns.DamageMeter then ns.DamageMeter:Refresh() end end,
                },
                spacer2 = { type = "description", name = "", width = 0.1, order = 25 },
                barTexture = {
                    type = "select", name = "Bar Texture", order = 30,
                    values = function()
                        local t = MediaList("statusbar")
                        t[""] = "Blizzard"
                        return t
                    end,
                    get = function() return ns.db.profile.damagemeter.barTexture or "" end,
                    set = function(_, val) ns.db.profile.damagemeter.barTexture = val; if ns.DamageMeter then ns.DamageMeter:Refresh() end end,
                },
            }
        },
        featuresGroup = {
            type = "group", name = "Features", order = 20, inline = true,
            args = {
                threatTab = {
                    type = "toggle", name = "Threat Meter Tab", order = 10, width = 1.2,
                    desc = "Adds a Threat tab next to the meter's title: your group's threat on your target. Left-click a tab to switch; right-click the title for Blizzard's meter types.",
                    get = function() return ns.db.profile.damagemeter.threatTab end,
                    set = function(_, val) ns.db.profile.damagemeter.threatTab = val; if ns.DamageMeter then ns.DamageMeter:Refresh() end end,
                },
                spacer1 = { type = "description", name = "", width = 0.1, order = 11 },
                combatTimer = {
                    type = "toggle", name = "Combat Timer", order = 20, width = 1.2,
                    desc = "Shows how long the fight has lasted in the meter's title row.",
                    get = function() return ns.db.profile.damagemeter.combatTimer end,
                    set = function(_, val) ns.db.profile.damagemeter.combatTimer = val; if ns.DamageMeter then ns.DamageMeter:Refresh() end end,
                },
            }
        },
        howToGroup = {
            type = "group", name = "How to Use", order = 90, inline = true,
            args = {
                text = {
                    type = "description", fontSize = "medium", order = 10,
                    name = "Click between Blizzard's damage meter and Threat tabs in the header to select and show one of them.\n\n"
                        .. "Right click the Damage Meter title in the header to select what to track (Damage Done, DPS, HPS etc).",
                },
            }
        },
    },
}
