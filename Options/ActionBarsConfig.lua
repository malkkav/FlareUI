local _, ns = ...

--------------------------------------------------
-- 1. UPVALUES
--------------------------------------------------
local InCombatLockdown = InCombatLockdown

--------------------------------------------------
-- 2. HELPERS
--------------------------------------------------
local function CreateScaleSlider(key, label, order)
    return {
        type = "range", name = label, order = order,
        min = 0.5, max = 1.5, step = 0.01, width = "normal",
        get = function() return ns.db.profile.actionbars.scales[key] end,
        set = function(_, val) ns.db.profile.actionbars.scales[key] = val; ns.ActionBars:Refresh() end,
    }
end

--------------------------------------------------
-- 3. ACTION BARS OPTIONS
--------------------------------------------------
ns.Options.args.actionbars = {
    type = "group", name = "Action Bars", order = 50,
    hidden = function() return not ns.db.profile.actionbars.enabled end,
    childGroups = "tab",
    args = {
        header = { type = "header", name = "Action Bars Settings", order = 10 },

        --------------------------------------------------
        -- TAB 1: General & Colors
        --------------------------------------------------
        generalTab = {
            type = "group", name = "General", order = 10,
            args = {
                generalGroup = {
                    type = "group", name = "Functionality", order = 10, inline = true,
                    args = {
                        cleanKeybinds = {
                            type = "toggle", name = "Clean Keybind Text", order = 20,
                            get = function() return ns.db.profile.actionbars.cleanKeybinds end,
                            set = function(_, val) ns.db.profile.actionbars.cleanKeybinds = val; if ns.ActionBars then ns.ActionBars:Refresh() end end
                        },
                        spacer2 = { type = "description", name = "", width = 0.1, order = 21 },
                        hideHotkeys = {
                            type = "toggle", name = "Hide Keybind Text", order = 30,
                            get = function() return ns.db.profile.actionbars.hideHotkeys end,
                            set = function(_, val) ns.db.profile.actionbars.hideHotkeys = val; ns.ActionBars:Refresh() end
                        },
                        spacer3 = { type = "description", name = "", width = 0.1, order = 31 },
                        hideMacroText = {
                            type = "toggle", name = "Hide Macro Text", order = 40,
                            get = function() return ns.db.profile.actionbars.hideMacroText end,
                            set = function(_, val) ns.db.profile.actionbars.hideMacroText = val; ns.ActionBars:Refresh() end
                        },
                        spacer4 = { type = "description", name = "", width = 0.1, order = 41 },
                        gryphonsAboveButtons = {
                            type = "toggle", name = "Gryphons Above Text", order = 62,
                            get = function() return ns.db.profile.actionbars.gryphonsAboveButtons end,
                            set = function(_, val) ns.db.profile.actionbars.gryphonsAboveButtons = val; ns.ActionBars:Refresh() end
                        },
                        spacer7 = { type = "description", name = "", width = 0.1, order = 63 },
                        buttonArt = {
                            type = "toggle", name = "Button Art", order = 64,
                            get = function() return ns.db.profile.actionbars.buttonArt end,
                            set = function(_, val) ns.db.profile.actionbars.buttonArt = val; ns.ActionBars:Refresh() end
                        },
                        spacer8 = { type = "description", name = "", width = 0.1, order = 65 },
                        stopAutoAddSpells = {
                            type = "toggle", name = "Stop Auto-Add Spells", order = 66,
                            get = function() return ns.db.profile.actionbars.stopAutoAddSpells end,
                            set = function(_, val) ns.db.profile.actionbars.stopAutoAddSpells = val; ns.ActionBars:Refresh() end
                        },
                    }
                },
                colorsGroup = {
                    type = "group", name = "Status Coloring", order = 20, inline = true,
                    args = {
                        enableRange = {
                            type = "toggle", name = "Enable Status Colors", order = 10, width = "full",
                            get = function() return ns.db.profile.actionbars.colors.enableRange end,
                            set = function(_, val) ns.db.profile.actionbars.colors.enableRange = val; ns.ActionBars:Refresh(); ns.ShowDialog("FLAREUI_RELOAD") end
                        },

                        range    = { type = "color", name = "Out of Range", order = 20, hasAlpha = true, get = function() local c = ns.db.profile.actionbars.colors.range; return c.r, c.g, c.b, c.a or 1 end, set = function(_, r, g, b, a) ns.db.profile.actionbars.colors.range = {r=r, g=g, b=b, a=a}; ns.ActionBars:Refresh() end },
                        mana     = { type = "color", name = "Out of Resource", order = 30, hasAlpha = true, get = function() local c = ns.db.profile.actionbars.colors.mana; return c.r, c.g, c.b, c.a or 1 end, set = function(_, r, g, b, a) ns.db.profile.actionbars.colors.mana = {r=r, g=g, b=b, a=a}; ns.ActionBars:Refresh() end },

                        unusable = { type = "toggle", name = "Desaturate Unusable", order = 40, get = function() return ns.db.profile.actionbars.colors.unusable.desaturate end, set = function(_, val) ns.db.profile.actionbars.colors.unusable.desaturate = val; ns.ActionBars:Refresh() end }
                    }
                },
                xpGroup = {
                    type = "group", name = "XP / Honor Bars", order = 30, inline = true,
                    args = {
                        enabled = {
                            type = "toggle", name = "Reskin", order = 10, width = 1.2,
                            desc = "Gives Blizzard's XP, honor and reputation bars the FlareUI look.",
                            get = function() return ns.db.profile.actionbars.xpbar.enabled end,
                            set = function(_, val) ns.db.profile.actionbars.xpbar.enabled = val; ns.ShowDialog("FLAREUI_RELOAD") end,
                        },
                    }
                }
            }
        },

        --------------------------------------------------
        -- TAB 2: Scaling
        --------------------------------------------------
        scalingTab = {
            type = "group", name = "Bar Scaling", order = 20,
            args = {
                mainBars = {
                    type = "group", name = "Main Bars", order = 10, inline = true,
                    args = {
                        bar1 = CreateScaleSlider("bar1", "Action Bar 1", 10),
                        spacer1 = { type = "description", name = "", width = 0.1, order = 11 },
                        bar2 = CreateScaleSlider("bar2", "Action Bar 2", 20),
                        spacer2 = { type = "description", name = "", width = 0.1, order = 21 },
                        bar3 = CreateScaleSlider("bar3", "Action Bar 3", 30),
                        spacer3 = { type = "description", name = "", width = 0.1, order = 31 },
                        bar4 = CreateScaleSlider("bar4", "Action Bar 4", 40),
                        spacer4 = { type = "description", name = "", width = 0.1, order = 41 },
                        bar5 = CreateScaleSlider("bar5", "Action Bar 5", 50),
                        spacer5 = { type = "description", name = "", width = 0.1, order = 51 },
                        bar6 = CreateScaleSlider("bar6", "Action Bar 6", 60),
                        spacer6 = { type = "description", name = "", width = 0.1, order = 61 },
                        bar7 = CreateScaleSlider("bar7", "Action Bar 7", 70),
                        spacer7 = { type = "description", name = "", width = 0.1, order = 71 },
                        bar8 = CreateScaleSlider("bar8", "Action Bar 8", 80),
                    }
                },
                extraBars = {
                    type = "group", name = "Side Bars", order = 20, inline = true,
                    args = {
                        pet    = CreateScaleSlider("pet",  "Pet Bar",      10),
                        spacer1 = { type = "description", name = "", width = 0.1, order = 11 },
                        stance = CreateScaleSlider("stance", "Stance Bar", 20),
                    }
                }
            }
        },

        --------------------------------------------------
        -- TAB 3: Fake Cooldown Manager (FCM)
        --------------------------------------------------
        fakeCMTab = {
            type = "group", name = "Fake CM", order = 30,
            args = {
                header = { type = "header", name = "Fake Cooldown Manager", order = 10 },

                -- Instructions
                instructions = {
                    type = "group", name = "How It Works", order = 20, inline = true,
                    args = {
                        desc = {
                            type = "description",
                            name = "Repurpose action bars as cooldown trackers: selected bars become "
                                .. "clickthrough and show only on their visibility conditions, and "
                                .. "dragging a spell or item onto one turns clickthrough back off.",
                            fontSize = "medium",
                            order = 10,
                        }
                    }
                },

                -- Global Hiding
                globalHiding = {
                    type = "group", name = "Hide Blizzard Cooldown Manager", order = 30, inline = true,
                    args = {
                        hideUtility = {
                            type = "toggle", name = "Hide Utility Tracker",
                            order = 10,
                            get = function() return ns.db.profile.fcm.hideUtilityCooldownViewer end,
                            set = function(_, val)
                                ns.db.profile.fcm.hideUtilityCooldownViewer = val
                                if ns.ActionBars then ns.ActionBars:Refresh() end
                                ns.ShowDialog("FLAREUI_RELOAD")
                            end
                        },
                        spacer1 = { type = "description", name = "", width = 0.1, order = 11 },
                        hideEssential = {
                            type = "toggle", name = "Hide Essential Tracker",
                            order = 20,
                            get = function() return ns.db.profile.fcm.hideEssentialCooldownViewer end,
                            set = function(_, val)
                                ns.db.profile.fcm.hideEssentialCooldownViewer = val
                                if ns.ActionBars then ns.ActionBars:Refresh() end
                                ns.ShowDialog("FLAREUI_RELOAD")
                            end
                        },
                    }
                },

                -- Bar Selection (8 checkboxes in 4x2 grid)
                barSelection = {
                    type = "group", name = "Bar Selection", order = 40, inline = true,
                    args = {
                        bar1 = {
                            type = "toggle", name = "Action Bar 1", order = 10,
                            get = function() return ns.db.profile.fcm.bars.bar1.enabled end,
                            set = function(_, val)
                                ns.db.profile.fcm.bars.bar1.enabled = val
                                if ns.ActionBars then ns.ActionBars:Refresh() end
                            end
                        },
                        spacer1 = { type = "description", name = "", width = 0.1, order = 11 },
                        bar2 = {
                            type = "toggle", name = "Action Bar 2", order = 20,
                            get = function() return ns.db.profile.fcm.bars.bar2.enabled end,
                            set = function(_, val)
                                ns.db.profile.fcm.bars.bar2.enabled = val
                                if ns.ActionBars then ns.ActionBars:Refresh() end
                            end
                        },
                        spacer2 = { type = "description", name = "", width = 0.1, order = 21 },
                        bar3 = {
                            type = "toggle", name = "Action Bar 3", order = 30,
                            get = function() return ns.db.profile.fcm.bars.bar3.enabled end,
                            set = function(_, val)
                                ns.db.profile.fcm.bars.bar3.enabled = val
                                if ns.ActionBars then ns.ActionBars:Refresh() end
                            end
                        },
                        spacer3 = { type = "description", name = "", width = 0.1, order = 31 },
                        bar4 = {
                            type = "toggle", name = "Action Bar 4", order = 40,
                            get = function() return ns.db.profile.fcm.bars.bar4.enabled end,
                            set = function(_, val)
                                ns.db.profile.fcm.bars.bar4.enabled = val
                                if ns.ActionBars then ns.ActionBars:Refresh() end
                            end
                        },
                        break1 = { type = "description", name = "", order = 45, width = "full" },
                        bar5 = {
                            type = "toggle", name = "Action Bar 5", order = 50,
                            get = function() return ns.db.profile.fcm.bars.bar5.enabled end,
                            set = function(_, val)
                                ns.db.profile.fcm.bars.bar5.enabled = val
                                if ns.ActionBars then ns.ActionBars:Refresh() end
                            end
                        },
                        spacer5 = { type = "description", name = "", width = 0.1, order = 51 },
                        bar6 = {
                            type = "toggle", name = "Action Bar 6", order = 60,
                            get = function() return ns.db.profile.fcm.bars.bar6.enabled end,
                            set = function(_, val)
                                ns.db.profile.fcm.bars.bar6.enabled = val
                                if ns.ActionBars then ns.ActionBars:Refresh() end
                            end
                        },
                        spacer6 = { type = "description", name = "", width = 0.1, order = 61 },
                        bar7 = {
                            type = "toggle", name = "Action Bar 7", order = 70,
                            get = function() return ns.db.profile.fcm.bars.bar7.enabled end,
                            set = function(_, val)
                                ns.db.profile.fcm.bars.bar7.enabled = val
                                if ns.ActionBars then ns.ActionBars:Refresh() end
                            end
                        },
                        spacer7 = { type = "description", name = "", width = 0.1, order = 71 },
                        bar8 = {
                            type = "toggle", name = "Action Bar 8", order = 80,
                            get = function() return ns.db.profile.fcm.bars.bar8.enabled end,
                            set = function(_, val)
                                ns.db.profile.fcm.bars.bar8.enabled = val
                                if ns.ActionBars then ns.ActionBars:Refresh() end
                            end
                        },
                    }
                },

                -- Visibility Conditions
                visibility = {
                    type = "group", name = "Show Conditions", order = 50, inline = true,
                    args = {

                        break1 = { type = "description", name = "", order = 10, width = "full" },

                        condAlways = {
                            type = "toggle", name = "Always Show",
                            order = 15,
                            get = function()
                                return ns.db.profile.fcm.bars.bar1.condAlways
                            end,
                            set = function(_, val)
                                for i = 1, 8 do
                                    ns.db.profile.fcm.bars["bar"..i].condAlways = val
                                end
                                if ns.Visibility then ns.Visibility:Refresh() end
                            end
                        },

                        spacer0 = { type = "description", name = "", width = 0.1, order = 16 },

                        condCombat = {
                            type = "toggle", name = "Combat",
                            order = 20,
                            get = function()
                                return ns.db.profile.fcm.bars.bar1.condCombat
                            end,
                            set = function(_, val)
                                for i = 1, 8 do
                                    ns.db.profile.fcm.bars["bar"..i].condCombat = val
                                end
                                if ns.Visibility then ns.Visibility:Refresh() end
                            end
                        },

                        spacer1 = { type = "description", name = "", width = 0.1, order = 21 },

                        condTarget = {
                            type = "toggle", name = "Target",
                            order = 30,
                            get = function()
                                return ns.db.profile.fcm.bars.bar1.condTarget
                            end,
                            set = function(_, val)
                                for i = 1, 8 do
                                    ns.db.profile.fcm.bars["bar"..i].condTarget = val
                                end
                                if ns.Visibility then ns.Visibility:Refresh() end
                            end
                        },

                        spacer2 = { type = "description", name = "", width = 0.1, order = 31 },

                        condHarm = {
                            type = "toggle", name = "Attackable",
                            order = 40,
                            get = function()
                                return ns.db.profile.fcm.bars.bar1.condHarm
                            end,
                            set = function(_, val)
                                for i = 1, 8 do
                                    ns.db.profile.fcm.bars["bar"..i].condHarm = val
                                end
                                if ns.Visibility then ns.Visibility:Refresh() end
                            end
                        },
                    }
                },

                setupSpacer = { type = "description", name = " ", order = 55, width = "full" },

                setupMode = {
                    type = "execute", name = "Setup Mode (|cffffff00/fui cm|r)", order = 60, width = "full",
                    desc = "When enabled, selected bars become interactible. Use it to reorder or "
                        .. "remove spells.",
                    func = function()
                        if InCombatLockdown() then
                            print("|cffff0000FlareUI:|r Cannot toggle setup mode in combat!")
                            return
                        end
                        local newState = not ns.db.profile.fcm.setupModeEnabled
                        ns.db.profile.fcm.setupModeEnabled = newState
                        if ns.ActionBars then ns.ActionBars:SetFCM_UnlockMode(newState) end
                        print("|cff00ff00FlareUI:|r FCM Setup Mode "
                            .. (newState and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"))
                    end,
                },
            }
        },

        --------------------------------------------------
        -- TAB 5: Typography
        --------------------------------------------------
        typoTab = {
            type = "group", name = "Fonts", order = 50,
            args = {
                hotkey = ns.CreateFontOptions(10, "Keybind Text", "actionbars", "hotkeyFont", false, true),
                count  = ns.CreateFontOptions(20, "Stack/Charges Count", "actionbars", "countFont", false, true),
                macro  = ns.CreateFontOptions(30, "Macro Name", "actionbars", "macroFont", false, true),
            }
        }
    }
}
