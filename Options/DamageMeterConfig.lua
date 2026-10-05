local _, ns = ...
local L = ns.L

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
    type = "group", name = L["Damage Meter"], order = 30,
    hidden = function() return not ns.db.profile.damagemeter.enabled end,
    args = {
        header = { type = "header", name = L["Damage Meter Settings"], order = 0 },
        frameGroup = {
            type = "group", name = L["Frame"], order = 10, inline = true,
            args = {
                opacity = {
                    type = "range", name = L["Background Opacity"], min = 0, max = 1, step = 0.05, order = 10,
                    get = function() return ns.db.profile.damagemeter.opacity end,
                    set = function(_, val) ns.db.profile.damagemeter.opacity = val; if ns.DamageMeter then ns.DamageMeter:Refresh() end end,
                },
                spacer1 = { type = "description", name = "", width = 0.1, order = 11 },
                borderTexture = {
                    type = "select", name = L["Border"], order = 20,
                    values = function() return MediaList("border") end,
                    get = function() return ns.db.profile.damagemeter.borderTexture end,
                    set = function(_, val) ns.db.profile.damagemeter.borderTexture = val; if ns.DamageMeter then ns.DamageMeter:Refresh() end end,
                },
                spacer2 = { type = "description", name = "", width = 0.1, order = 25 },
                matchChatSize = {
                    type = "toggle", name = L["Match Chat Frame Size"], order = 40, width = 1.2,
                    desc = L["The meter takes the size of FlareUI's chat frame, in place of the size set in Edit Mode. Needs the Chat module."],
                    disabled = function() return not (ns.db.profile.chat and ns.db.profile.chat.enabled) end,
                    get = function() return ns.db.profile.damagemeter.matchChatSize end,
                    set = function(_, val)
                        ns.db.profile.damagemeter.matchChatSize = val
                        if not val and ns.DamageMeter then ns.DamageMeter:RestoreEditModeSize() end
                        if ns.DamageMeter then ns.DamageMeter:Refresh() end
                    end,
                },
            }
        },
        featuresGroup = {
            type = "group", name = L["Features"], order = 20, inline = true,
            args = {
                threatTab = {
                    type = "toggle", name = L["Threat Meter Tab"], order = 20, width = 1.2,
                    desc = L["Adds a Threat tab next to the meter's title: your group's threat on your target. Left-click a tab to switch; right-click the title for Blizzard's meter types."],
                    get = function() return ns.db.profile.damagemeter.threatTab end,
                    set = function(_, val) ns.db.profile.damagemeter.threatTab = val; if ns.DamageMeter then ns.DamageMeter:Refresh() end end,
                },
                spacer1 = { type = "description", name = "", width = 0.1, order = 11 },
                combatTimer = {
                    type = "toggle", name = L["Combat Timer"], order = 10, width = 1.2,
                    desc = L["Shows how long the fight has lasted in the meter's title row."],
                    get = function() return ns.db.profile.damagemeter.combatTimer end,
                    set = function(_, val) ns.db.profile.damagemeter.combatTimer = val; if ns.DamageMeter then ns.DamageMeter:Refresh() end end,
                },
                spacer2 = { type = "description", name = "", width = 0.1, order = 21 },
                threatKey = {
                    type = "keybinding", name = L["Threat Toggle Keybind"], order = 30, width = 1.2,
                    desc = L["Press it to switch the meter between Blizzard's view and the Threat tab."],
                    disabled = function() return not ns.db.profile.damagemeter.threatTab end,
                    get = function() return ns.db.profile.damagemeter.threatKey or "" end,
                    set = function(_, val)
                        ns.db.profile.damagemeter.threatKey = (val ~= "" and val) or nil
                        if ns.DamageMeter then ns.DamageMeter:Refresh() end
                    end,
                },
                readyCheckButton = {
                    type = "toggle", name = L["Ready Check Button"], order = 40, width = 1.2,
                    desc = L["A button in the meter's header that starts a ready check. It shows only when you lead or assist a group."],
                    get = function() return ns.db.profile.damagemeter.readyCheckButton ~= false end,
                    set = function(_, val) ns.db.profile.damagemeter.readyCheckButton = val; if ns.DamageMeter then ns.DamageMeter:Refresh() end end,
                },
                spacer3 = { type = "description", name = "", width = 0.1, order = 41 },
                countdownButton = {
                    type = "toggle", name = L["Countdown Button"], order = 50, width = 1.2,
                    desc = L["A button in the meter's header that starts a 10-second pull countdown; right-click it to cancel. It shows only while you are in a group."],
                    get = function() return ns.db.profile.damagemeter.countdownButton ~= false end,
                    set = function(_, val) ns.db.profile.damagemeter.countdownButton = val; if ns.DamageMeter then ns.DamageMeter:Refresh() end end,
                },
                spacer4 = { type = "description", name = "", width = 0.1, order = 51 },
                autoThreat = {
                    type = "toggle", name = L["Threat View in Combat"], order = 60, width = 1.2,
                    desc = L["The meter switches to the Threat tab when combat starts and back to Blizzard's view when it ends."],
                    disabled = function() return not ns.db.profile.damagemeter.threatTab end,
                    get = function() return ns.db.profile.damagemeter.autoThreat end,
                    set = function(_, val) ns.db.profile.damagemeter.autoThreat = val end,
                },
            }
        },
        howToGroup = {
            type = "group", name = L["How to Use"], order = 90, inline = true,
            args = {
                text = {
                    type = "description", fontSize = "medium", order = 10,
                    name = L["|cffff4040The Damage Meter only shows with \"Enable Damage Meter\" switched on in Blizzard's Settings, under Advanced Options.|r\n\nClick between Blizzard's damage meter and Threat tabs in the header to select and show one of them.\n\nRight click the Damage Meter title in the header to select what to track (Damage Done, DPS, HPS etc)."],
                },
            }
        },
    },
}
