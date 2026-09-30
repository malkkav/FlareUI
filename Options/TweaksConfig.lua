local _, ns = ...

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
        StaticPopup_Show("FLAREUI_RELOAD")
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

ns.Options.args.tweaks = {
    type = "group", name = "Tweaks", order = 80,
    hidden = function() return not ns.db.profile.tweaks.enabled end,
    args = {
        header = { type = "header", name = "Tweaks", order = 0 },

        windowsGroup = {
            type = "group", name = "Windows & Settings", order = 10, inline = true,
            args = {
                moveAnyFrame = Toggle("moveAnyFrame", "Move Any Frame", 10,
                    "Drag a window by its title bar.\nCtrl + mouse wheel - scale\nShift + right click - reset position\nCtrl + right click - reset scale\nRight click (bags) - sorting menu\n\nOff while the gamepad UI is on. Your saved positions come back with keyboard mode.", true, 1.2, GamepadUI),
                spacer1 = SP(11),
                syncUI = Toggle("syncUI", "Sync Blizz UI", 20,
                    "Syncs character specific UI settings between all characters.", true, 1.2),
                spacer2 = SP(21),
                -- Pressed on the character everyone should copy, which is why nothing here has
                -- to list characters. Greyed out on the source itself, which says so.
                syncSource = {
                    type = "execute", order = 30, width = 1.2,
                    name = function()
                        return (ns.Tweaks and ns.Tweaks:IsSyncSource()) and "This Character Is the Source"
                            or "Make This Character the Source"
                    end,
                    desc = function()
                        local label = ns.Tweaks and ns.Tweaks:GetSyncSourceLabel()
                        return (label and ("Current source: " .. label) or "No source yet.")
                            .. "\n\nEvery other character copies its settings from the source."
                    end,
                    disabled = function()
                        return not Get("syncUI") or (ns.Tweaks and ns.Tweaks:IsSyncSource())
                    end,
                    func = function() StaticPopup_Show("FLAREUI_SYNC_SOURCE") end,
                },
            }
        },

        vendorGroup = {
            type = "group", name = "Vendor", order = 20, inline = true,
            args = {
                sellJunk   = Toggle("sellJunk", "Sell Junk Automatically", 10, nil, false, 1.2),
                spacer1    = SP(11),
                autoRepair = Toggle("autoRepair", "Repair Automatically", 20, nil, false, 1.2),
                break1     = { type = "description", name = " ", order = 25, width = "full" },
                durabilityWarning = Toggle("durabilityWarning", "Durability Warning", 30, nil, false, 1.2),
                spacer2    = SP(31),
                durabilityThreshold = {
                    type = "range", name = "Warning Threshold", min = 5, max = 60, step = 5, order = 40, width = 1.2,
                    disabled = function() return not Get("durabilityWarning") end,
                    get = function() return Get("durabilityThreshold") end, set = SetLive("durabilityThreshold"),
                },
            }
        },

        convenienceGroup = {
            type = "group", name = "Convenience", order = 25, inline = true,
            args = {
                fasterLoot = Toggle("fasterLoot", "Faster Auto Loot", 5, nil, false, 1.2),
                spacer0    = SP(6),
                autoDelete = Toggle("autoDelete", "Auto-Type DELETE", 10,
                    "Fills in DELETE when you try to destroy a rare or better item.", false, 1.2),
                spacer1    = SP(11),
                trainAll   = Toggle("trainAll", "Train All Button", 20,
                    "Adds a Train All button to class and profession trainers.", false, 1.2),
            }
        },

        cameraGroup = {
            type = "group", name = "Camera", order = 30, inline = true,
            args = {
                maxCameraZoom    = Toggle("maxCameraZoom", "Max Camera Zoom", 10, nil, false, 1.2),
                spacer1          = SP(11),
                fasterCameraZoom = Toggle("fasterCameraZoom", "Faster Camera Zoom", 20, nil, false, 1.2),
            }
        },

        nameplateGroup = {
            type = "group", name = "Nameplates", order = 15, inline = true,
            args = {
                nameplateCombo = Toggle("nameplateCombo", "Combo Points", 10,
                    "Shows Blizzard's classic combo points under the middle of your target's nameplate.", false, 1.2),
                spacer1        = SP(11),
                nameplateQuest = Toggle("nameplateQuest", "Tag Quest Objectives", 20,
                    "Show a small quest symbol on the nameplate of enemies that are quest objectives or drop quest objective items.", false, 1.2),
            }
        },

        hideGroup = {
            type = "group", name = "Hide", order = 40, inline = true,
            args = {
                hideErrors          = Toggle("hideErrors", "Error Messages", 10, nil, true, 1.2),
                spacer1             = SP(11),
                hideZoneText        = Toggle("hideZoneText", "Zone Text", 20, nil, true, 1.2),
                spacer2             = SP(21),
                hideWorldRefresh    = Toggle("hideWorldRefresh", "World Refresh Dialog", 22, nil, false, 1.2),
                break1              = { type = "description", name = " ", order = 25, width = "full" },
                hidePartyTitle      = Toggle("hidePartyTitle", "Party Title", 30, nil, false, 1.2),
                spacer3             = SP(31),
                hideTips            = Toggle("hideTips", "Contextual Tips", 40, nil, false, 1.2),
                spacer4             = SP(41),
                hideTrackerInBoss   = Toggle("hideTrackerInBoss", "Quest Tracker in Boss Fights", 42,
                    "Hides the quest tracker from the pull to the end of a boss encounter.", false, 1.2),
                break2              = { type = "description", name = " ", order = 45, width = "full" },
                hidePortraitNumbers = Toggle("hidePortraitNumbers", "Portrait Numbers", 50, nil, false, 1.2),
                spacer5             = SP(51),
                hideAddonDrawer     = Toggle("hideAddonDrawer", "Addon Drawer", 60, nil, false, 1.2),
            }
        },
    },
}

-- portrait numbers only exist on Blizzard's player / pet frames, which the Unit Frames module replaces
ns.Options.args.tweaks.args.hideGroup.args.hidePortraitNumbers.hidden = function()
    return ns.db.profile.unitframes and ns.db.profile.unitframes.enabled
end
ns.Options.args.tweaks.args.hideGroup.args.spacer5.hidden = ns.Options.args.tweaks.args.hideGroup.args.hidePortraitNumbers.hidden

-- the Minimap module hides the addon drawer itself while it is on
ns.Options.args.tweaks.args.hideGroup.args.hideAddonDrawer.hidden = function()
    return ns.db.profile.minimap and ns.db.profile.minimap.enabled
end
