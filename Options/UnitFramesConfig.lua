local _, ns = ...
local L = ns.L

--------------------------------------------------
-- UNIT FRAMES OPTIONS
-- Which frames exist, which icons and overlays they show, the shared font and the visibility rules.
-- Everything else (size, look, texts, cast bars, auras) is tuned per frame in Edit Mode (click a frame
-- while Edit Mode is open); positions save per layout.
--------------------------------------------------
-- Fonts > Aura Text: face, outline and shadow; the size follows each frame's Aura Size
local function AuraTextOptions(order)
    local group = ns.CreateFontOptions(order, L["Aura Text"], "unitframes", "auraFont")
    group.args.size = nil
    group.args.spacerH = nil
    return group
end

local function UnitToggle(unit, label, order)
    return {
        type = "toggle", name = label, order = order,
        get = function() return ns.db.profile.unitframes.units[unit].enabled end,
        set = function(_, val) ns.db.profile.unitframes.units[unit].enabled = val; ns.ShowDialog("FLAREUI_RELOAD") end,
    }
end


--------------------------------------------------
-- Visibility tab: one settings set per group of frames
--------------------------------------------------
local function VisGet(set)
    return function(info) return ns.db.profile.unitframes.visibility[set][info[#info]] end
end
local function VisSet(set)
    return function(info, val)
        ns.db.profile.unitframes.visibility[set][info[#info]] = val
        if ns.UnitFrames and ns.UnitFrames.RefreshVisibility then ns.UnitFrames:RefreshVisibility() end
    end
end

-- conditions: list of { key, label, width }
local function VisibilityGroup(set, label, order, conditions)
    local get, setter = VisGet(set), VisSet(set)
    local args = {
        condHeader = { type = "description", order = 5, name = L["|cffffd100Show when|r"] },
    }
    for i, cond in ipairs(conditions) do
        args[cond[1]] = { type = "toggle", name = cond[2], width = cond[3] or 0.7, order = 10 + i * 2, get = get, set = setter }
        args["condSpacer" .. i] = { type = "description", name = "", width = 0.1, order = 11 + i * 2 }
    end
    args.break1      = { type = "description", name = " ", order = 29, width = "full" }
    args.alphaHeader = { type = "description", order = 30, name = L["|cffffd100Alpha|r"] }
    args.alphaMin    = { type = "range", name = L["Min Alpha"], min = 0, max = 1, step = 0.05, order = 31, get = get, set = setter }
    args.spacer1     = { type = "description", name = "", width = 0.1, order = 32 }
    args.alphaMax    = { type = "range", name = L["Max Alpha"], min = 0, max = 1, step = 0.05, order = 33, get = get, set = setter }
    return { type = "group", name = label, order = order, inline = true, args = args }
end

ns.Options.args.unitframes = {
    type = "group", name = L["Unit Frames"], order = 40,
    hidden = function() return not ns.db.profile.unitframes.enabled end,
    childGroups = "tab",
    args = {
        header = { type = "header", name = L["Unit Frames Settings"], order = 0 },

        generalTab = {
            type = "group", name = L["General"], order = 10,
            args = {
                framesGroup = {
                    type = "group", name = L["Frames"], order = 10, inline = true,
                    args = {
                        player       = UnitToggle("player", L["Player"], 10),
                        spacer1 = { type = "description", name = "", width = 0.1, order = 11 },
                        target       = UnitToggle("target", L["Target"], 20),
                        spacer2 = { type = "description", name = "", width = 0.1, order = 21 },
                        focus        = UnitToggle("focus", L["Focus"], 30),
                        spacer3 = { type = "description", name = "", width = 0.1, order = 31 },
                        pet          = UnitToggle("pet", L["Pet"], 40),
                        spacer4 = { type = "description", name = "", width = 0.1, order = 41 },
                        targettarget = UnitToggle("targettarget", L["Target of Target"], 50),
                        spacer5 = { type = "description", name = "", width = 0.1, order = 51 },
                        focustarget = UnitToggle("focustarget", L["Target of Focus"], 52),
                        spacer5b = { type = "description", name = "", width = 0.1, order = 53 },
                        party = {
                            type = "toggle", name = L["Party"], order = 55,
                            desc = L["FlareUI's party frames, Classic or Raid-Style. Placed and tuned in Edit Mode (FlareUI Party Frames). They replace Blizzard's party frames."],
                            get = function() return ns.db.profile.unitframes.party.enabled end,
                            set = function(_, val) ns.db.profile.unitframes.party.enabled = val; ns.ShowDialog("FLAREUI_RELOAD") end,
                        },
                        spacer6 = { type = "description", name = "", width = 0.1, order = 56 },
                        playerCastbar = {
                            type = "toggle", name = L["Player Cast Bar"], order = 60,
                            get = function() return ns.db.profile.unitframes.playerCastbar.enabled end,
                            set = function(_, val) ns.db.profile.unitframes.playerCastbar.enabled = val; ns.ShowDialog("FLAREUI_RELOAD") end,
                        },
                    }
                },
                resourceGroup = {
                    type = "group", name = L["Resource Bars"], order = 20, inline = true,
                    args = (function()
                        local list = {
                            { "health", L["Health Bar"] }, { "power", L["Power Bar"] }, { "mana", L["Mana Bar"] },
                            { "combo", L["Combo Points"] }, { "swingMain", L["Main-Hand Swing"] },
                            { "swingOff", L["Off-Hand Swing"] }, { "swingRanged", L["Ranged Swing"] },
                        }
                        local args = {}
                        for i, entry in ipairs(list) do
                            local key = entry[1]
                            args[key] = {
                                type = "toggle", name = entry[2], order = 10 + i * 2,
                                get = function() return ns.db.profile.unitframes.resource.bars[key].enabled end,
                                set = function(_, val) ns.db.profile.unitframes.resource.bars[key].enabled = val; ns.ShowDialog("FLAREUI_RELOAD") end,
                            }
                            args["spacer" .. i] = { type = "description", name = "", width = 0.1, order = 11 + i * 2 }
                        end
                        return args
                    end)(),
                },
            },
        },

        fontsTab = {
            type = "group", name = L["Fonts"], order = 30,
            args = {
                main  = ns.CreateFontOptions(10, L["Level / Name / Health"], "unitframes", "font"),
                power = ns.CreateFontOptions(20, L["Power Text"], "unitframes", "fontPower"),
                cast  = ns.CreateFontOptions(30, L["Spell Name / Timer"], "unitframes", "fontCast"),
                auraText = AuraTextOptions(40),
            },
        },

        visibilityTab = {
            type = "group", name = L["Visibility"], order = 20,
            args = {
                player = VisibilityGroup("player", L["Player & Pet"], 10, {
                    { "condMouseover", L["Mouseover"], 0.7 },
                    { "condCombat",    L["Combat"], 0.6 },
                    { "condTarget",    L["Target"], 0.6 },
                    { "condHarm",      L["Attackable Target"], 0.9 },
                    { "condHealth",    L["Health Missing"], 0.8 },
                }),
                target = VisibilityGroup("target", L["Target"], 20, {
                    { "condCombat", L["Combat"], 0.6 },
                    { "condHarm",   L["Attackable"], 0.7 },
                }),
                focus = VisibilityGroup("focus", L["Focus"], 30, {
                    { "condCombat", L["Combat"], 0.6 },
                    { "condHarm",   L["Attackable"], 0.7 },
                }),
            },
        },
    },
}
