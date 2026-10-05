local _, ns = ...
local L = ns.L

--------------------------------------------------
-- AURAS OPTIONS
-- The look of the player's buff and debuff frames. Size, icons per row, spacing and growth are set
-- per frame in Edit Mode (FlareUI Buffs, FlareUI Debuffs).
--------------------------------------------------
local function Get(key) return ns.db.profile.auras[key] end

local function Set(key)
    return function(_, val)
        ns.db.profile.auras[key] = val
        if ns.Auras then ns.Auras:Refresh() end
    end
end

local SP = function(order) return { type = "description", name = "", width = 0.1, order = order } end

ns.Options.args.auras = {
    type = "group", name = L["Buffs / Debuffs"], order = 55,
    hidden = function() return not ns.db.profile.auras.enabled end,
    childGroups = "tab",
    args = {
        generalTab = {
            type = "group", name = L["General"], order = 10,
            args = {
                lookGroup = {
                    type = "group", name = L["Look"], order = 10, inline = true,
                    args = {
                        style = {
                            type = "select", name = L["Shape"], order = 10, width = 1.1,
                            values = { square = L["Square"], round = L["Round"] }, sorting = { "square", "round" },
                            get = function() return Get("style") end, set = Set("style"),
                        },
                        spacer1 = SP(11),
                        swipe = {
                            type = "select", name = L["Cooldown Swipe"], order = 20, width = 1.1,
                            values = { border = L["Border"], icon = L["Icon"], none = L["None"] }, sorting = { "border", "icon", "none" },
                            get = function() return Get("swipe") end, set = Set("swipe"),
                        },
                        spacer2 = SP(21),
                        timer = {
                            type = "select", name = L["Timer"], order = 30, width = 1.1,
                            values = { below = L["Under the Icon"], bottom = L["Bottom of the Icon"], middle = L["Middle of the Icon"], none = L["No Timer"] },
                            sorting = { "below", "bottom", "middle", "none" },
                            get = function() return Get("timer") end, set = Set("timer"),
                        },
                        break1 = { type = "description", name = " ", order = 35, width = "full" },
                        weaponEnchants = {
                            type = "toggle", name = L["Weapon Enchants"], order = 40, width = 1.1,
                            desc = L["Shows poisons, oils and other temporary weapon enchants before your buffs."],
                            get = function() return Get("weaponEnchants") ~= false end, set = Set("weaponEnchants"),
                        },
                    },
                },
                font = ns.CreateFontOptions(20, L["Timer & Stacks Font"], "auras", "font"),
                warningGroup = {
                    type = "group", name = L["Warning"], order = 100, inline = true,
                    args = {
                        gamepadNote = {
                            type = "description", order = 10, width = "full", fontSize = "medium",
                            name = L["|cffff4040Does not work in Gamepad mode: Blizzard restricts it, as its own buff frame is part of the controller navigation there. Gamepad mode keeps Blizzard's buffs and debuffs.|r"],
                        },
                    },
                },
            },
        },
    },
}
