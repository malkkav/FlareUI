local _, ns = ...
local L = ns.L

--------------------------------------------------
-- TWEAKS OPTIONS
-- Five groups of toggles. Options that replace Blizzard scripts ask for a reload; the rest apply
-- live through Tweaks:Refresh().
--------------------------------------------------
local function Get(key) return ns.db.profile.tweaks[key] end

local function SetLive(key)
    return function(_, val)
        ns.db.profile.tweaks[key] = val
        if ns.Tweaks then ns.Tweaks:Refresh() end
    end
end

local function SetReload(key)
    return function(_, val)
        ns.db.profile.tweaks[key] = val
        ns.ShowDialog("FLAREUI_RELOAD")
    end
end

local function Toggle(key, label, order, desc, reload, width, disabled)
    return {
        type = "toggle", name = label, desc = desc, order = order, width = width, disabled = disabled,
        get = function() return Get(key) end,
        set = reload and SetReload(key) or SetLive(key),
    }
end

-- the gamepad UI drives Blizzard's windows itself; see StartMoveAnyFrame in Modules/Tweaks.lua
local function GamepadUI() return ns.IsGamepadUI() end

local SP = function(order) return { type = "description", name = "", width = 0.1, order = order } end

-- another nameplate addon switches the Nameplates options off; see Modules/Tweaks.lua
local function NameplateAddon() return ns.Tweaks and ns.Tweaks.GetNameplateAddon and ns.Tweaks:GetNameplateAddon() end

ns.Options.args.tweaks = {
    type = "group", name = L["Tweaks"], order = 80,
    hidden = function() return not ns.db.profile.tweaks.enabled end,
    childGroups = "tab",
    args = {
        header = { type = "header", name = L["Tweaks"], order = 0 },

        -- what the interface shows and how it is laid out
        interfaceTab = {
            type = "group", name = L["Interface"], order = 10,
            args = {
                windowsGroup = {
                    type = "group", name = L["Windows & Settings"], order = 10, inline = true,
                    args = {
                        moveAnyFrame = Toggle("moveAnyFrame", L["Move Any Frame"], 10,
                            L["Drag a window by its title bar.\nCtrl + mouse wheel - scale\nShift + right click - reset position\nCtrl + right click - reset scale\nRight click (bags) - sorting menu\n\nOff while the gamepad UI is on. Your saved positions come back with keyboard mode."], true, 1.2, GamepadUI),
                        spacer1 = SP(11),
                        syncUI = Toggle("syncUI", L["Sync Blizz UI"], 20,
                            L["Syncs character specific UI settings between all characters."], true, 1.2),
                        spacer2 = SP(21),
                        -- Pressed on the character everyone should copy, which is why nothing here has
                        -- to list characters. Greyed out on the source itself, which says so.
                        syncSource = {
                            type = "execute", order = 30, width = 1.2,
                            name = function()
                                return (ns.Tweaks and ns.Tweaks:IsSyncSource()) and L["This Character Is the Source"]
                                    or L["Make This Character the Source"]
                            end,
                            desc = function()
                                local label = ns.Tweaks and ns.Tweaks:GetSyncSourceLabel()
                                return (label and L["Current source: %s"]:format(label) or L["No source yet."])
                                    .. "\n\n" .. L["Every other character copies its settings from the source."]
                            end,
                            disabled = function()
                                return not Get("syncUI") or (ns.Tweaks and ns.Tweaks:IsSyncSource())
                            end,
                            func = function() ns.ShowDialog("FLAREUI_SYNC_SOURCE") end,
                        },
                        break1 = { type = "description", name = " ", order = 35, width = "full" },
                        moveLootToasts = Toggle("moveLootToasts", L["Move Loot Rolls & Toasts"], 40,
                            L["Adds FlareUI Loot Rolls and FlareUI Toasts to Edit Mode, to place the Need / Greed / Pass frames and Blizzard's pop-up toasts (new recipe learned, achievements, loot won).\n\nOff while the gamepad UI is on."], true, 1.2, GamepadUI),
                        spacer3 = SP(41),
                        layoutPerMode = Toggle("layoutPerMode", L["Remember Layout per Mode"], 50,
                            L["Switching Blizzard's Gamepad UI on or off resets Edit Mode to its default layout. With this on, each mode gets back the Edit Mode layout you last used in it."], false, 1.2),
                        spacer4 = SP(51),
                        offerGamepad = Toggle("offerGamepad", L["Offer Gamepad Mode"], 60,
                            L["With keyboard and mouse, the first press on a controller asks whether to switch to Gamepad mode (Blizzard's Gamepad UI). Type /fui pad to switch at any time."], false, 1.2),
                        spacer5 = SP(61),
                        bagTooltip = Toggle("bagTooltip", L["Bag Header Tooltip"], 70,
                            L["Shows Blizzard's tooltip (the bag's name and \"click for bag settings\") when you point at a bag window's header."], false, 1.2),
                    }
                },

                nameplateGroup = {
                    type = "group", name = L["Nameplates"], order = 20, inline = true,
                    args = {
                        nameplateCombo = Toggle("nameplateCombo", L["Combo Points"], 10,
                            L["Shows classic combo point gems under the middle of your target's nameplate."], false, 1.2, NameplateAddon),
                        spacer1        = SP(11),
                        nameplateQuest = Toggle("nameplateQuest", L["Tag Quest Objectives"], 20,
                            L["Show a small quest symbol on the nameplate of enemies that are quest objectives or drop quest objective items."], false, 1.2, NameplateAddon),
                        nameplateNote  = {
                            type = "description", order = 30, width = "full", fontSize = "medium",
                            name = function()
                                return "|cffffd100Off while " .. (NameplateAddon() or "") .. " handles your nameplates.|r"
                            end,
                            hidden = function() return not NameplateAddon() end,
                        },
                    }
                },

                hideGroup = {
                    type = "group", name = L["Hide"], order = 30, inline = true,
                    args = {
                        hideErrors          = Toggle("hideErrors", L["Error Messages"], 10, nil, true, 1.2),
                        spacer1             = SP(11),
                        hideZoneText        = Toggle("hideZoneText", L["Zone Text"], 20, nil, true, 1.2),
                        spacer2             = SP(21),
                        hideTrackerInBoss   = Toggle("hideTrackerInBoss", L["Quest Tracker in Boss Fights"], 22,
                            L["Hides the quest tracker from the pull to the end of a boss encounter."], false, 1.2),
                        break1              = { type = "description", name = " ", order = 25, width = "full" },
                        hidePartyTitle      = Toggle("hidePartyTitle", L["Party Title"], 30, nil, false, 1.2),
                        spacer3             = SP(31),
                        hideTips            = Toggle("hideTips", L["Contextual Tips"], 40, nil, false, 1.2),
                        spacer4             = SP(41),
                        hideAddonDrawer     = Toggle("hideAddonDrawer", L["Addon Drawer"], 42, nil, false, 1.2),
                        break2              = { type = "description", name = " ", order = 45, width = "full" },
                        hidePortraitNumbers = Toggle("hidePortraitNumbers", L["Portrait Numbers"], 50, nil, false, 1.2),
                    }
                },
            },
        },

        -- what happens for you while you play
        gameplayTab = {
            type = "group", name = L["Gameplay"], order = 20,
            args = {
                vendorGroup = {
                    type = "group", name = L["Vendor"], order = 10, inline = true,
                    args = {
                        sellJunk   = Toggle("sellJunk", L["Sell Junk Automatically"], 10, nil, false, 1.2),
                        spacer1    = SP(11),
                        autoRepair = Toggle("autoRepair", L["Repair Automatically"], 20, nil, false, 1.2),
                        break1     = { type = "description", name = " ", order = 25, width = "full" },
                        durabilityWarning = Toggle("durabilityWarning", L["Durability Warning"], 30, nil, false, 1.2),
                        spacer2    = SP(31),
                        durabilityThreshold = {
                            type = "range", name = L["Warning Threshold"], min = 5, max = 60, step = 5, order = 40, width = 1.2,
                            disabled = function() return not Get("durabilityWarning") end,
                            get = function() return Get("durabilityThreshold") end, set = SetLive("durabilityThreshold"),
                        },
                    }
                },

                convenienceGroup = {
                    type = "group", name = L["Convenience"], order = 20, inline = true,
                    args = {
                        fasterLoot = Toggle("fasterLoot", L["Faster Auto Loot"], 5, nil, false, 1.2),
                        spacer0    = SP(6),
                        autoDelete = Toggle("autoDelete", L["Auto-Type DELETE"], 10,
                            L["Fills in DELETE when you try to destroy a rare or better item."], false, 1.2),
                        spacer1    = SP(11),
                        trainAll   = Toggle("trainAll", L["Train All Button"], 20,
                            L["Adds a Train All button to class and profession trainers."], false, 1.2),
                    }
                },

                cameraGroup = {
                    type = "group", name = L["Camera"], order = 30, inline = true,
                    args = {
                        maxCameraZoom    = Toggle("maxCameraZoom", L["Max Camera Zoom"], 10, nil, false, 1.2),
                        spacer1          = SP(11),
                        fasterCameraZoom = Toggle("fasterCameraZoom", L["Faster Camera Zoom"], 20, nil, false, 1.2),
                    }
                },
            },
        },
    },
}

local hideArgs = ns.Options.args.tweaks.args.interfaceTab.args.hideGroup.args

-- portrait numbers only exist on Blizzard's player / pet frames, which the Unit Frames module replaces
hideArgs.hidePortraitNumbers.hidden = function()
    return ns.db.profile.unitframes and ns.db.profile.unitframes.enabled
end
hideArgs.break2.hidden = hideArgs.hidePortraitNumbers.hidden

-- the Minimap module hides the addon drawer itself while it is on
hideArgs.hideAddonDrawer.hidden = function()
    return ns.db.profile.minimap and ns.db.profile.minimap.enabled
end
