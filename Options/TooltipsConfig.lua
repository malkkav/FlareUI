local _, ns = ...
local L = ns.L

--------------------------------------------------
-- TOOLTIPS OPTIONS
-- General (look + content), Anchor, Visibility.
--------------------------------------------------
local function Get(key) return ns.db.profile.tooltips[key] end

local function Set(key)
    return function(_, val)
        ns.db.profile.tooltips[key] = val
        if ns.Tooltips then ns.Tooltips:Refresh() end
    end
end

local function Toggle(key, label, order, desc, width)
    return {
        type = "toggle", name = label, desc = desc, order = order, width = width,
        get = function() return Get(key) end, set = Set(key),
    }
end

local SP = function(order) return { type = "description", name = "", width = 0.1, order = order } end

-- one dropdown per visibility category
local VISIBILITY_MODES = { always = "Always Show", combat = "Hide in Combat", never = "Always Hide" }

local function Category(key, label, order)
    return {
        type = "select", name = label, order = order, width = 1.1,
        values = VISIBILITY_MODES,
        sorting = { "always", "combat", "never" },
        get = function() return ns.db.profile.tooltips.visibility[key] end,
        set = function(_, val) ns.db.profile.tooltips.visibility[key] = val end,
    }
end

ns.Options.args.tooltips = {
    type = "group", name = L["Tooltips"], order = 70,
    hidden = function() return not ns.db.profile.tooltips.enabled end,
    childGroups = "tab",
    args = {
        header = { type = "header", name = L["Tooltip Settings"], order = 0 },

        --------------------------------------------------
        -- TAB 1: General
        --------------------------------------------------
        fontsTab = {
            type = "group", name = L["Fonts"], order = 30,
            args = {
                title   = ns.CreateFontOptions(10, L["Title"], "tooltips", "titleFont"),
                content = ns.CreateFontOptions(20, L["Content"], "tooltips", "contentFont"),
            },
        },

        generalTab = {
            type = "group", name = L["General"], order = 10,
            args = {
                lookGroup = {
                    type = "group", name = L["Look"], order = 10, inline = true,
                    args = {
                        scale = {
                            type = "range", name = L["Scale"], min = 0.5, max = 2, step = 0.05, order = 10, width = 1.2,
                            get = function() return Get("scale") end, set = Set("scale"),
                        },
                        spacer1 = SP(11),
                        background = {
                            type = "color", name = L["Background Color"], hasAlpha = true, order = 20,
                            get = function() local c = Get("background"); return c.r, c.g, c.b, c.a or 1 end,
                            set = function(_, r, g, b, a)
                                ns.db.profile.tooltips.background = { r = r, g = g, b = b, a = a }
                                if ns.Tooltips then ns.Tooltips:Refresh() end
                            end,
                        },
                        break1 = { type = "description", name = " ", order = 25, width = "full" },
                        borderByReaction = Toggle("borderByReaction", L["Border by Reaction"], 30, nil, 1.2),
                        spacer2 = SP(31),
                        borderByClass = Toggle("borderByClass", L["Border by Class"], 40, nil, 1.2),
                        break2 = { type = "description", name = " ", order = 45, width = "full" },
                        borderByQuality = Toggle("borderByQuality", L["Border by Item Quality"], 50, nil, 1.2),
                        spacer3 = SP(51),
                        hideHealthBar = Toggle("hideHealthBar", L["Hide Health Bar"], 60, nil, 1.2),
                    }
                },
                contentGroup = {
                    type = "group", name = L["Content"], order = 20, inline = true,
                    args = {
                        nameColor = {
                            type = "select", name = L["Name Color"], order = 10, width = 1.2,
                            values = { none = L["Default"], reaction = L["By Reaction"], class = L["By Class"] },
                            sorting = { "none", "reaction", "class" },
                            get = function() return Get("nameColor") end, set = Set("nameColor"),
                        },
                        spacer1 = SP(11),
                        colorLevelLine = Toggle("colorLevelLine", L["Color Level Line"], 20, L["Tints the \"Level X\" line by reaction."], 1.2),
                        break1 = { type = "description", name = " ", order = 25, width = "full" },
                        classification = Toggle("classification", L["Classification Prefixes"], 30, L["Marks elites as +Name and adds (Rare) / (Boss)."], 1.2),
                        spacer2 = SP(31),
                        showTarget = Toggle("showTarget", L["Show Unit's Target"], 40, L["Adds a line with whatever the unit is targeting."], 1.2),
                        break2 = { type = "description", name = " ", order = 45, width = "full" },
                        hidePvpLine = Toggle("hidePvpLine", L["Hide PvP Line"], 50, L["Removes the \"PvP\" line from unit tooltips."], 1.2),
                        spacer3 = SP(51),
                        hideRightClick = Toggle("hideRightClick", L["Hide Right Click Hint"], 60, L["Removes the \"<Right click for Frame Settings>\" line."], 1.2),
                        break3 = { type = "description", name = " ", order = 65, width = "full" },
                        showItemID = Toggle("showItemID", L["Item IDs"], 70, L["Adds the item's ID at the bottom of item tooltips."], 1.2),
                        spacer4 = SP(71),
                        showSpellID = Toggle("showSpellID", L["Spell IDs"], 80, L["Adds the spell's ID at the bottom of spell and buff tooltips."], 1.2),
                    }
                },
            },
        },

        --------------------------------------------------
        -- TAB 2: Anchor
        --------------------------------------------------
        anchorTab = {
            type = "group", name = L["Anchor"], order = 40,
            args = {
                anchorGroup = {
                    type = "group", name = L["Placement"], order = 10, inline = true,
                    args = {
                        anchor = {
                            type = "select", name = L["World"], order = 10, width = 1.2,
                            disabled = function() return ns.IsGamepadUI() end,
                            values = { default = L["Default"], cursorOffset = L["Cursor"] },
                            sorting = { "default", "cursorOffset" },
                            get = function() return Get("anchor") end, set = Set("anchor"),
                        },
                        spacer1 = SP(11),
                        anchorFrames = {
                            type = "select", name = L["UI Frames"], order = 20, width = 1.2,
                            disabled = function() return ns.IsGamepadUI() end,
                            values = { default = L["Default"], cursorOffset = L["Cursor"] },
                            sorting = { "default", "cursorOffset" },
                            get = function() return Get("anchorFrames") end, set = Set("anchorFrames"),
                        },
                        break1 = { type = "description", name = " ", order = 25, width = "full" },
                        anchorX = {
                            type = "range", name = L["X Offset"], min = -128, max = 128, step = 1, order = 30, width = 1.2,
                            disabled = function() return ns.IsGamepadUI() or (Get("anchor") == "default" and Get("anchorFrames") == "default") end,
                            get = function() return Get("anchorX") end, set = Set("anchorX"),
                        },
                        spacer2 = SP(31),
                        anchorY = {
                            type = "range", name = L["Y Offset"], min = -128, max = 128, step = 1, order = 40, width = 1.2,
                            disabled = function() return ns.IsGamepadUI() or (Get("anchor") == "default" and Get("anchorFrames") == "default") end,
                            get = function() return Get("anchorY") end, set = Set("anchorY"),
                        },
                    }
                },
            },
        },

        --------------------------------------------------
        -- TAB 3: Visibility
        --------------------------------------------------
        visibilityTab = {
            type = "group", name = L["Visibility"], order = 20,
            args = {
                worldGroup = {
                    type = "group", name = L["World"], order = 10, inline = true,
                    args = {
                        worldUnits   = Category("worldUnits", L["Units"], 10),
                        spacer1      = SP(11),
                        worldObjects = Category("worldObjects", L["Objects"], 20),
                    }
                },
                frameGroup = {
                    type = "group", name = L["Interface"], order = 20, inline = true,
                    args = {
                        frameUnits = Category("frameUnits", L["Unit Frames"], 10),
                        spacer1    = SP(11),
                        frameTips  = Category("frameTips", L["Other Frames"], 20),
                        spacer2    = SP(21),
                        actionBars = Category("actionBars", L["Action Bars & Keybinds"], 30),
                    }
                },
                contentGroup = {
                    type = "group", name = L["Content"], order = 30, inline = true,
                    args = {
                        items  = Category("items", L["Items"], 10),
                        spacer1 = SP(11),
                        spells = Category("spells", L["Spells"], 20),
                        spacer2 = SP(21),
                        auras  = Category("auras", L["Auras"], 30),
                    }
                },
                overrideGroup = {
                    type = "group", name = L["Override"], order = 40, inline = true,
                    args = {
                        shiftReveal = Toggle("shiftReveal", L["Show with Shift"], 10,
                            L["Hold Shift to see tooltips that would otherwise be hidden."], 1.6),
                    }
                },
            },
        },
    },
}
