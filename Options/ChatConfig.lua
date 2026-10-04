local _, ns = ...

--------------------------------------------------
-- 1. UPVALUES
--------------------------------------------------

--------------------------------------------------
-- 2. HELPERS
--------------------------------------------------
local function Get(key)
    return ns.db.profile.chat[key]
end

-- every border registered with LibSharedMedia, FlareUI's and other addons'
local function BorderList()
    local t = {}
    for _, name in ipairs(LibStub("LibSharedMedia-3.0"):List("border")) do t[name] = name end
    return t
end

local function Set(key, val, reload)
    ns.db.profile.chat[key] = val
    if reload then
        ns.ShowDialog("FLAREUI_RELOAD")
    elseif ns.Chat and ns.Chat.RefreshAll then
        ns.Chat:RefreshAll()
    end
end

--------------------------------------------------
-- 3. CHAT OPTIONS
--------------------------------------------------
ns.Options.args.chat = {
    type = "group", name = "Chat", order = 20,
    hidden = function() return not ns.db.profile.chat.enabled end,
    childGroups = "tab",
    args = {
        header = { type = "header", name = "Chat Settings", order = 0 },

        --------------------------------------------------
        -- TAB 1: General (Features)
        --------------------------------------------------
        generalTab = {
            type = "group", name = "General", order = 10,
            args = {
                improvementsGroup = {
                    type = "group", name = "Improvements", order = 10, inline = true,
                    args = {
                        enableTT = {
                            type = "toggle", name = "Enable /tt Command", desc = "Allows you to use /tt to whisper your current target.", order = 10,
                            get = function() return Get("enableTT") end,
                            set = function(_, val) Set("enableTT", val, true) end
                        },
                        spacer1 = { type = "description", name = "", width = 0.1, order = 11 },
                        enableWay = {
                            type = "toggle", name = "Enable /way Map Pins", desc = "/way <x> <y> or /way <zone> <x> <y> places a map pin and tracks it.", order = 15,
                            get = function() return Get("enableWay") end,
                            set = function(_, val) Set("enableWay", val, true) end
                        },
                        spacer2 = { type = "description", name = "", width = 0.1, order = 16 },
                        copyLinks = {
                            type = "toggle", name = "Copy Chat Links", desc = "Makes web addresses in chat clickable; clicking one opens a box with the link ready to copy.", order = 25,
                            get = function() return Get("copyLinks") end,
                            set = function(_, val) Set("copyLinks", val); if ns.Chat and ns.Chat.SetupCopyLinks then ns.Chat:SetupCopyLinks() end end
                        },
                        spacer5 = { type = "description", name = "", width = 0.1, order = 26 },
                        hideCombatLog = {
                            type = "toggle", name = "Hide Combat Log", desc = "Completely hides the Combat Log tab.", order = 45,
                            get = function() return Get("hideCombatLog") end,
                            set = function(_, val) Set("hideCombatLog", val, true) end
                        },
                        spacer6 = { type = "description", name = "", width = 0.1, order = 46 },
                        hideBubblesInInstance = {
                            type = "toggle", name = "No Bubbles in Instances", desc = "Turns chat bubbles off inside dungeons, raids and battlegrounds.", order = 50,
                            get = function() return Get("hideBubblesInInstance") end,
                            set = function(_, val) Set("hideBubblesInInstance", val); if ns.Chat and ns.Chat.UpdateInstanceBubbles then ns.Chat:UpdateInstanceBubbles() end end
                        },
                        spacer7 = { type = "description", name = "", width = 0.1, order = 51 },
                        shiftInvite = {
                            type = "toggle", name = "Shift-Click to Invite", desc = "Shift-clicking a player's name in chat also invites them to your group (Blizzard's shift-click still looks them up).", order = 55,
                            get = function() return Get("shiftInvite") end,
                            set = function(_, val) Set("shiftInvite", val) end
                        },
                        extendHistory = {
                            type = "toggle", name = "Extend Chat History", desc = "Increases chat history capacity to 4096 lines.", order = 30,
                            get = function() return Get("extendHistory") end,
                            set = function(_, val) Set("extendHistory", val) end
                        },
                        spacer3 = { type = "description", name = "", width = 0.1, order = 31 },
                        saveHistory = {
                            type = "toggle", name = "Save Chat History", desc = "Restores the last 128 messages between sessions.", order = 40,
                            get = function() return Get("saveHistory") end,
                            set = function(_, val) Set("saveHistory", val) end
                        },
                        spacer4 = { type = "description", name = "", width = 0.1, order = 41 },
                    }
                },

                formattingGroup = {
                    type = "group", name = "Message Formatting (outside instances only)", order = 20, inline = true,
                    args = {
                        formatNPC = {
                            type = "toggle", name = "Better NPC Names", desc = "Removes the colon and colors NPC names.\nExample: '|cffFFB033[Thrall]|r Message'", order = 10,
                            get = function() return Get("formatNPC") end,
                            set = function(_, val) Set("formatNPC", val) end
                        },
                        spacer1 = { type = "description", name = "", width = 0.1, order = 11 },
                        formatPlayer = {
                            type = "toggle", name = "Better Player Names", desc = "Removes the colon and colors player names by class.\nExample: '|cffC41F3B[Player]|r Message'", order = 20,
                            get = function() return Get("formatPlayer") end,
                            set = function(_, val) Set("formatPlayer", val) end
                        },
                        spacer2 = { type = "description", name = "", width = 0.1, order = 21 },
                        betterTimestamps = {
                            type = "toggle", name = "Better Timestamps", desc = "Adds a colored timestamp inside brackets.\nExample: '|cff00B2FF<12:00>|r Message'", order = 30,
                            get = function() return Get("betterTimestamps") end,
                            set = function(_, val) Set("betterTimestamps", val) end
                        },
                        spacer3 = { type = "description", name = "", width = 0.1, order = 31 },
                        shortChannels = {
                            type = "toggle", name = "Short Channel Names", desc = "Shortens channel names on new messages.\nExample: [2. Trade - City] becomes [2]", order = 40,
                            get = function() return Get("shortChannels") end,
                            set = function(_, val) Set("shortChannels", val) end
                        },
                    }
                },

                frameGroup = {
                    type = "group", name = "Frame", order = 40, inline = true,
                    args = {
                        opacity        = { type = "range", name = "Background Opacity", min = 0, max = 1, step = 0.05, order = 10, get = function() return Get("opacity") end, set = function(_, val) Set("opacity", val) end },
                        spacer1        = { type = "description", name = "", width = 0.1, order = 11 },
                        borderTexture  = { type = "select", name = "Border", order = 15, values = BorderList, get = function() return Get("borderTexture") end, set = function(_, val) Set("borderTexture", val) end },
                        break0         = { type = "description", name = " ", order = 17, width = "full" },
                        editBoxOpacity = { type = "range", name = "Edit Box Opacity", min = 0, max = 1, step = 0.05, order = 20, get = function() return Get("editBoxOpacity") end, set = function(_, val) Set("editBoxOpacity", val) end },
                        spacer3        = { type = "description", name = "", width = 0.1, order = 21 },
                        editBoxPosition = { type = "select", name = "Edit Box Position", order = 30,
                            values = { below = "Below the chat frame", above = "Above the chat frame", inside = "Inside the chat frame" },
                            sorting = { "below", "above", "inside" },
                            get = function() return Get("editBoxPosition") or "inside" end, set = function(_, val) Set("editBoxPosition", val) end },
                    }
                },

                headerGroup = {
                    type = "group", name = "Header Buttons", order = 45, inline = true,
                    args = {
                        social = {
                            type = "toggle", name = "Social", order = 10, desc = "The friends and Quick Join button.",
                            get = function() return not Get("socialHide") end,
                            set = function(_, val) Set("socialHide", not val) end
                        },
                        spacer1 = { type = "description", name = "", width = 0.1, order = 11 },
                        channel = {
                            type = "toggle", name = "Chat Channels", order = 20, desc = "Join and leave chat channels.",
                            get = function() return not Get("channelHide") end,
                            set = function(_, val) Set("channelHide", not val) end
                        },
                        spacer2 = { type = "description", name = "", width = 0.1, order = 21 },
                        menu = {
                            type = "toggle", name = "Chat Menu", order = 30, desc = "Emotes, languages and voice commands.",
                            get = function() return not Get("menuHide") end,
                            set = function(_, val) Set("menuHide", not val) end
                        },
                        volume = {
                            type = "toggle", name = "Volume", order = 40, desc = "Master volume: click to mute, scroll to change.",
                            get = function() return Get("showVolume") end,
                            set = function(_, val) Set("showVolume", val) end
                        },
                    }
                },

                howToGroup = {
                    type = "group", name = "How to Use", order = 90, inline = true,
                    args = {
                        text = {
                            type = "description", fontSize = "medium", order = 10,
                            name = "Right click a tab in the chat to open the options and create or close tabs. "
                                .. "You can drag and drop tabs to reorder them. You can do the same with the header buttons.\n\n"
                                .. "If you use a lot of tabs, use the mouse scroll wheel in the chat header to scroll between them.",
                        },
                    }
                },
            }
        },

        --------------------------------------------------
        -- TAB 2: Fonts
        --------------------------------------------------
        fontsTab = {
            type = "group", name = "Fonts", order = 60,
            args = {
                chatFont = ns.CreateFontOptions(10, "Message Font",  "chat", "chatFont", false),
                editFont = ns.CreateFontOptions(20, "Edit Box Font", "chat", "editBoxFont", false),
            }
        },

        --------------------------------------------------
        -- TAB 5: Visibility
        --------------------------------------------------
        visibilityTab = {
            type = "group", name = "Visibility", order = 50,
            args = {
                autoHideGroup = {
                    type = "group", name = "Auto-Hiding", order = 10, inline = true,
                    args = {
                        autoHideEnabled = { type = "toggle", name = "Enable Auto-Hide", width = 0.9, order = 10, get = function() return Get("autoHideEnabled") ~= false end, set = function(_, val) Set("autoHideEnabled", val) end },
                        spacer1 = { type = "description", name = "", width = 0.1, order = 11 },
                        autoHideDelay = { type = "range", name = "Hide Delay", min = 0, max = 60, step = 1, order = 20, disabled = function() return Get("autoHideEnabled") == false end, get = function() return Get("autoHideDelay") end, set = function(_, val) Set("autoHideDelay", val) end },
                    }
                },
                animGroup = {
                    type = "group", name = "Animation", order = 20, inline = true,
                    disabled = function() return Get("autoHideEnabled") == false end,
                    args = {
                        fadeInSpeed = { type = "range", name = "Fade In Speed", min = 0, max = 2, step = 0.1, order = 10, get = function() return Get("fadeInSpeed") or 0.2 end, set = function(_, val) Set("fadeInSpeed", val) end },
                        spacer1 = { type = "description", name = "", width = 0.1, order = 11 },
                        fadeOutSpeed = { type = "range", name = "Fade Out Speed", min = 0, max = 2, step = 0.1, order = 20, get = function() return Get("fadeOutSpeed") or 1.0 end, set = function(_, val) Set("fadeOutSpeed", val) end },
                        spacer2 = { type = "description", name = "", width = 0.1, order = 21 },
                        alphaMin = { type = "range", name = "Min Alpha", min = 0, max = 1, step = 0.05, order = 30, get = function() return Get("alphaMin") or 0 end, set = function(_, val) Set("alphaMin", val) end },
                        spacer3 = { type = "description", name = "", width = 0.1, order = 31 },
                        alphaMax = { type = "range", name = "Max Alpha", min = 0, max = 1, step = 0.05, order = 40, get = function() return Get("alphaMax") or 1 end, set = function(_, val) Set("alphaMax", val) end },
                    }
                },
                triggerGroup = {
                    type = "group", name = "Show Conditions", order = 30, inline = true,
                    disabled = function() return Get("autoHideEnabled") == false end,
                    args = {
                        showOnMessage = { type = "toggle", name = "New Message", order = 10, get = function() return Get("showOnMessage") end, set = function(_, val) Set("showOnMessage", val) end },
                        spacer1 = { type = "description", name = "", width = 0.1, order = 11 },
                        showOnEdit    = { type = "toggle", name = "Edit Box Active", order = 20, get = function() return Get("showOnEdit") end, set = function(_, val) Set("showOnEdit", val) end },
                        spacer2 = { type = "description", name = "", width = 0.1, order = 21 },
                        showOnMouse   = { type = "toggle", name = "Mouseover", order = 30, get = function() return Get("showOnMouse") end, set = function(_, val) Set("showOnMouse", val) end },
                        spacer3 = { type = "description", name = "", width = 0.1, order = 31 },
                        showOnCombat  = { type = "toggle", name = "Combat", order = 40, get = function() return Get("showOnCombat") end, set = function(_, val) Set("showOnCombat", val) end },
                    }
                }
            }
        },

    },
}
