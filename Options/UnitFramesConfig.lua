local _, ns = ...

--------------------------------------------------
-- UNIT FRAMES OPTIONS
-- Which frames exist, which icons and overlays they show, the shared font and the visibility rules.
-- Everything else (size, look, texts, cast bars, auras) is tuned per frame in Edit Mode (click a frame
-- while Edit Mode is open); positions save per layout.
--------------------------------------------------
local function UnitToggle(unit, label, order)
    return {
        type = "toggle", name = label, order = order,
        get = function() return ns.db.profile.unitframes.units[unit].enabled end,
        set = function(_, val) ns.db.profile.unitframes.units[unit].enabled = val; StaticPopup_Show("FLAREUI_RELOAD") end,
    }
end

-- one icon or overlay, switched for every frame that has it
local function ElementToggle(key, label, order)
    return {
        type = "toggle", name = label, order = order, width = 1.1,
        get = function() return ns.db.profile.unitframes.elements[key] end,
        set = function(_, val)
            ns.db.profile.unitframes.elements[key] = val
            if ns.UnitFrames then ns.UnitFrames:Refresh() end
        end,
    }
end

-- three to a row
local function ElementsGroup(order, list)
    local args = {}
    for i, entry in ipairs(list) do
        args[entry[1]] = ElementToggle(entry[1], entry[2], i * 10)
        if i % 3 ~= 0 then args["spacer" .. i] = { type = "description", name = "", width = 0.1, order = i * 10 + 1 } end
    end
    args.break1 = { type = "description", name = " ", order = 900, width = "full" }
    -- Blizzard's own combo points in the target frame's health bar corner instead of FlareUI's strip
    args.classicCombo = {
        type = "toggle", name = "Classic Combo Points", order = 910, width = 1.1,
        get = function() return ns.db.profile.unitframes.units.target.classicCombo end,
        set = function(_, val)
            ns.db.profile.unitframes.units.target.classicCombo = val
            if ns.UnitFrames then ns.UnitFrames:Refresh() end
        end,
    }
    return { type = "group", name = "Elements", order = order, inline = true, args = args }
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
        condHeader = { type = "description", order = 5, name = "|cffffd100Show when|r" },
    }
    for i, cond in ipairs(conditions) do
        args[cond[1]] = { type = "toggle", name = cond[2], width = cond[3] or 0.7, order = 10 + i * 2, get = get, set = setter }
        args["condSpacer" .. i] = { type = "description", name = "", width = 0.1, order = 11 + i * 2 }
    end
    args.break1      = { type = "description", name = " ", order = 29, width = "full" }
    args.alphaHeader = { type = "description", order = 30, name = "|cffffd100Alpha|r" }
    args.alphaMin    = { type = "range", name = "Min Alpha", min = 0, max = 1, step = 0.05, order = 31, get = get, set = setter }
    args.spacer1     = { type = "description", name = "", width = 0.1, order = 32 }
    args.alphaMax    = { type = "range", name = "Max Alpha", min = 0, max = 1, step = 0.05, order = 33, get = get, set = setter }
    return { type = "group", name = label, order = order, inline = true, args = args }
end

ns.Options.args.unitframes = {
    type = "group", name = "Unit Frames", order = 40,
    hidden = function() return not ns.db.profile.unitframes.enabled end,
    childGroups = "tab",
    args = {
        header = { type = "header", name = "Unit Frames Settings", order = 0 },

        generalTab = {
            type = "group", name = "General", order = 10,
            args = {
                framesGroup = {
                    type = "group", name = "Frames", order = 10, inline = true,
                    args = {
                        player       = UnitToggle("player", "Player", 10),
                        spacer1 = { type = "description", name = "", width = 0.1, order = 11 },
                        target       = UnitToggle("target", "Target", 20),
                        spacer2 = { type = "description", name = "", width = 0.1, order = 21 },
                        focus        = UnitToggle("focus", "Focus", 30),
                        spacer3 = { type = "description", name = "", width = 0.1, order = 31 },
                        pet          = UnitToggle("pet", "Pet", 40),
                        spacer4 = { type = "description", name = "", width = 0.1, order = 41 },
                        targettarget = UnitToggle("targettarget", "Target of Target", 50),
                        spacer5 = { type = "description", name = "", width = 0.1, order = 51 },
                        playerCastbar = {
                            type = "toggle", name = "Player Cast Bar", order = 60,
                            get = function() return ns.db.profile.unitframes.playerCastbar.enabled end,
                            set = function(_, val) ns.db.profile.unitframes.playerCastbar.enabled = val; StaticPopup_Show("FLAREUI_RELOAD") end,
                        },
                    }
                },
                elementsGroup = ElementsGroup(20, {
                    { "rest",           "Resting Indicator" },
                    { "leader",         "Leader Crown" },
                    { "pvp",            "PvP Flag" },
                    { "classification", "Elite & Rare Icon" },
                    { "questBoss",      "Quest Icon" },
                    { "raidIcon",       "Raid Target Icon" },
                }),
            },
        },

        fontsTab = {
            type = "group", name = "Fonts", order = 30,
            args = {
                main  = ns.CreateFontOptions(10, "Level / Name / Health", "unitframes", "font"),
                power = ns.CreateFontOptions(20, "Power Text", "unitframes", "fontPower"),
                cast  = ns.CreateFontOptions(30, "Spell Name / Timer", "unitframes", "fontCast"),
            },
        },

        visibilityTab = {
            type = "group", name = "Visibility", order = 20,
            args = {
                player = VisibilityGroup("player", "Player & Pet", 10, {
                    { "condMouseover", "Mouseover", 0.7 },
                    { "condCombat",    "Combat", 0.6 },
                    { "condTarget",    "Target", 0.6 },
                    { "condHarm",      "Attackable Target", 0.9 },
                    { "condHealth",    "Health Missing", 0.8 },
                }),
                target = VisibilityGroup("target", "Target", 20, {
                    { "condCombat", "Combat", 0.6 },
                    { "condHarm",   "Attackable", 0.7 },
                }),
                focus = VisibilityGroup("focus", "Focus", 30, {
                    { "condCombat", "Combat", 0.6 },
                    { "condHarm",   "Attackable", 0.7 },
                }),
            },
        },
    },
}
