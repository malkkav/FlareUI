local _, ns = ...

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
    type = "group", name = "Tooltips", order = 70,
    hidden = function() return not ns.db.profile.tooltips.enabled end,
    childGroups = "tab",
    args = {
        header = { type = "header", name = "Tooltip Settings", order = 0 },

        --------------------------------------------------
        -- TAB 1: General
        --------------------------------------------------
        generalTab = {
            type = "group", name = "General", order = 10,
            args = {
                lookGroup = {
                    type = "group", name = "Look", order = 10, inline = true,
                    args = {
                        scale = {
                            type = "range", name = "Scale", min = 0.5, max = 2, step = 0.05, order = 10, width = 1.2,
                            get = function() return Get("scale") end, set = Set("scale"),
                        },
                        spacer1 = SP(11),
                        background = {
                            type = "color", name = "Background Color", hasAlpha = true, order = 20,
                            get = function() local c = Get("background"); return c.r, c.g, c.b, c.a or 1 end,
                            set = function(_, r, g, b, a)
                                ns.db.profile.tooltips.background = { r = r, g = g, b = b, a = a }
                                if ns.Tooltips then ns.Tooltips:Refresh() end
                            end,
                        },
                        break1 = { type = "description", name = " ", order = 25, width = "full" },
                        borderByReaction = Toggle("borderByReaction", "Border by Reaction", 30, nil, 1.2),
                        spacer2 = SP(31),
                        borderByClass = Toggle("borderByClass", "Border by Class", 40, nil, 1.2),
                        break2 = { type = "description", name = " ", order = 45, width = "full" },
                        borderByQuality = Toggle("borderByQuality", "Border by Item Quality", 50, nil, 1.2),
                        spacer3 = SP(51),
                        hideHealthBar = Toggle("hideHealthBar", "Hide Health Bar", 60, nil, 1.2),
                    }
                },
                contentGroup = {
                    type = "group", name = "Content", order = 20, inline = true,
                    args = {
                        nameColor = {
                            type = "select", name = "Name Color", order = 10, width = 1.2,
                            values = { none = "Default", reaction = "By Reaction", class = "By Class" },
                            sorting = { "none", "reaction", "class" },
                            get = function() return Get("nameColor") end, set = Set("nameColor"),
                        },
                        spacer1 = SP(11),
                        colorLevelLine = Toggle("colorLevelLine", "Color Level Line", 20, "Tints the \"Level X\" line by reaction.", 1.2),
                        break1 = { type = "description", name = " ", order = 25, width = "full" },
                        classification = Toggle("classification", "Classification Prefixes", 30, "Marks elites as +Name and adds (Rare) / (Boss).", 1.2),
                        spacer2 = SP(31),
                        showTarget = Toggle("showTarget", "Show Unit's Target", 40, "Adds a line with whatever the unit is targeting.", 1.2),
                        break2 = { type = "description", name = " ", order = 45, width = "full" },
                        hidePvpLine = Toggle("hidePvpLine", "Hide PvP Line", 50, "Removes the \"PvP\" line from unit tooltips.", 1.2),
                        spacer3 = SP(51),
                        hideRightClick = Toggle("hideRightClick", "Hide Right Click Hint", 60, "Removes the \"<Right click for Frame Settings>\" line.", 1.2),
                        break3 = { type = "description", name = " ", order = 65, width = "full" },
                        showItemID = Toggle("showItemID", "Item IDs", 70, "Adds the item's ID at the bottom of item tooltips.", 1.2),
                        spacer4 = SP(71),
                        showSpellID = Toggle("showSpellID", "Spell IDs", 80, "Adds the spell's ID at the bottom of spell and buff tooltips.", 1.2),
                    }
                },
            },
        },

        --------------------------------------------------
        -- TAB 2: Anchor
        --------------------------------------------------
        anchorTab = {
            type = "group", name = "Anchor", order = 20,
            args = {
                anchorGroup = {
                    type = "group", name = "Placement", order = 10, inline = true,
                    args = {
                        anchor = {
                            type = "select", name = "World", order = 10, width = 1.2,
                            values = { default = "Default", cursorOffset = "Cursor" },
                            sorting = { "default", "cursorOffset" },
                            get = function() return Get("anchor") end, set = Set("anchor"),
                        },
                        spacer1 = SP(11),
                        anchorFrames = {
                            type = "select", name = "UI Frames", order = 20, width = 1.2,
                            values = { default = "Default", cursorOffset = "Cursor" },
                            sorting = { "default", "cursorOffset" },
                            get = function() return Get("anchorFrames") end, set = Set("anchorFrames"),
                        },
                        break1 = { type = "description", name = " ", order = 25, width = "full" },
                        anchorX = {
                            type = "range", name = "X Offset", min = -128, max = 128, step = 1, order = 30, width = 1.2,
                            disabled = function() return Get("anchor") == "default" and Get("anchorFrames") == "default" end,
                            get = function() return Get("anchorX") end, set = Set("anchorX"),
                        },
                        spacer2 = SP(31),
                        anchorY = {
                            type = "range", name = "Y Offset", min = -128, max = 128, step = 1, order = 40, width = 1.2,
                            disabled = function() return Get("anchor") == "default" and Get("anchorFrames") == "default" end,
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
            type = "group", name = "Visibility", order = 30,
            args = {
                worldGroup = {
                    type = "group", name = "World", order = 10, inline = true,
                    args = {
                        worldUnits   = Category("worldUnits", "Units", 10),
                        spacer1      = SP(11),
                        worldObjects = Category("worldObjects", "Objects", 20),
                    }
                },
                frameGroup = {
                    type = "group", name = "Interface", order = 20, inline = true,
                    args = {
                        frameUnits = Category("frameUnits", "Unit Frames", 10),
                        spacer1    = SP(11),
                        frameTips  = Category("frameTips", "Other Frames", 20),
                        spacer2    = SP(21),
                        actionBars = Category("actionBars", "Action Bars & Keybinds", 30),
                    }
                },
                contentGroup = {
                    type = "group", name = "Content", order = 30, inline = true,
                    args = {
                        items  = Category("items", "Items", 10),
                        spacer1 = SP(11),
                        spells = Category("spells", "Spells", 20),
                        spacer2 = SP(21),
                        auras  = Category("auras", "Auras", 30),
                    }
                },
                overrideGroup = {
                    type = "group", name = "Override", order = 40, inline = true,
                    args = {
                        shiftReveal = Toggle("shiftReveal", "Show with Shift", 10,
                            "Hold Shift to see tooltips that would otherwise be hidden.", nil, 1.6),
                    }
                },
            },
        },
    },
}
