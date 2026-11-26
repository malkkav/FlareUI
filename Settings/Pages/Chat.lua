local _, ns = ...
local S = ns.Settings

--------------------------------------------------
-- CHAT
-- Settings for Modules/Chat.lua in three tabs: Frame, Tweaks and Fonts.
--------------------------------------------------
local function Refresh()
    if ns.Chat and ns.Chat.RefreshAll then ns.Chat:RefreshAll() end
end

S:Module{ key = "ch", group = "interface", order = 10, enabled = "chat.enabled", tabs = { { key = "frame" }, { key = "tweaks" }, { key = "fonts" } },
    -- its Fading rows sit in Blizzard's chat frame dialog in Edit Mode (Modules/Visibility.lua): found by search
    editSystems = function() return ns.Visibility and ns.Visibility.EditSystems and ns.Visibility:EditSystems("ch") or {} end,
    -- another chat addon is loaded: FlareUI's chat stays off and says why
    banner = function()
        local other = ns.Chat and ns.Chat.GetOtherChatAddon and ns.Chat:GetOtherChatAddon()
        if other then return S:ModuleText("ch", "banner"):format(other, other) end
        -- one that changes the same windows: FlareUI's chat runs beside it
        local clash = ns.Chat and ns.Chat.GetClashingChatAddon and ns.Chat:GetClashingChatAddon()
        if clash then return S:ModuleText("ch", "banner2"):format(clash) end
    end,
}

-- chat windows stay shown on this page so Frame Opacity can be seen
S:On("PageShown", function(key)
    if ns.Chat and ns.Chat.SetSettingsPreview then ns.Chat:SetSettingsPreview(key == "ch") end
end)

-- Frame Style: Modern (default) or FlareUI, the quest tracker's look (Chat.lua
-- Chat.ApplyFrameStyleArt); first in Frame. FlareUI brings its own border, so Border hides
S:Row{ key = "ch.frameStyle", kind = "choice", path = "chat.frameStyle", choices = { "flareui", "modern" },
    apply = Refresh, section = "ch.frame" }
S:Row{ key = "ch.opacity", kind = "range", path = "chat.opacity", choices = S:OpacityChoices(), apply = Refresh, section = "ch.frame" }
-- (the chat's fading is set in its Edit Mode dialog)
S:Row{ key = "ch.border", kind = "choice", path = "chat.borderTexture", choices = S.BorderChoices,
    apply = Refresh, section = "ch.frame", hidden = function() return S:GetPath("chat.frameStyle") == "flareui" end }
-- Header Buttons (one dropdown under Border): Social, Chat Channels and Chat Menu are
-- saved as hide flags, Volume as a show flag; each its own saved switch
local HEADER_BUTTONS = { { "social", "chat.socialHide", true }, { "channels", "chat.channelHide", true },
                         { "menu", "chat.menuHide", true }, { "volume", "chat.showVolume" } }
S:Row{ key = "ch.headerButtons", kind = "dropdown", section = "ch.frame", apply = Refresh,
    choices = { "none", { divider = true }, "social", "channels", "menu", "volume" },
    toggles = { exclusive = { "none" }, tokens = { "social", "channels", "menu", "volume" }, empty = "none" },
    get = function()
        local list = {}
        for _, b in ipairs(HEADER_BUTTONS) do
            local v = S:GetPath(b[2])
            if (b[3] and not v) or (not b[3] and v) then list[#list + 1] = b[1] end
        end
        return #list > 0 and table.concat(list, ",") or "none"
    end,
    set = function(value)
        local on = {}
        for token in tostring(value or ""):gmatch("[^,]+") do on[token] = true end
        for _, b in ipairs(HEADER_BUTTONS) do
            if b[3] then S:SetPath(b[2], not on[b[1]]) else S:SetPath(b[2], on[b[1]] and true or false) end
        end
    end,
    resetValue = function() return "social,channels,menu,volume" end }
-- Tab Sets Channel (Haisen): picking a tab that shows one kind of chat makes it the kind you
-- type in (Modules/Chat.lua TAB SETS CHANNEL). Read on each tab pick, so no apply needed.

S:Row{ key = "ch.editBoxOpacity", kind = "range", path = "chat.editBoxOpacity", choices = S:OpacityChoices(), apply = Refresh, section = "ch.editBoxSection" }
-- Edit Box Style: FlareUI (Blizzard's own art, always) or Modern (default, a dark
-- box). Edit Box Border: Modern's edge only, hidden with FlareUI; unset, it reads the edge the box had
-- from the chat's Border (Chat.lua Chat.EditBoxBorder)
S:Row{ key = "ch.editBoxStyle", kind = "choice", path = "chat.editBoxStyle", choices = { "flareui", "modern" },
    apply = Refresh, section = "ch.editBoxSection" }
S:Row{ key = "ch.editBoxBorder", kind = "choice", choices = { "none", "thin", "thick" }, apply = Refresh, section = "ch.editBoxSection",
    get = function() return ns.Chat and ns.Chat.EditBoxBorder(S:GetPath("chat")) or "thin" end,
    set = function(v) S:SetPath("chat.editBoxBorder", v) end,
    resetValue = function() return "thin" end,
    hidden = function() return S:GetPath("chat.editBoxStyle") == "flareui" end }
S:Row{ key = "ch.editBox", kind = "choice", path = "chat.editBoxPosition",
    choices = { "inside", "below", "above" }, apply = Refresh, section = "ch.editBoxSection" }
-- Notifications: Tab Glow and Whisper Sound, a section of their own below Edit Box
-- Tab Glow: which kinds of lines light an unseen tab; None (or nothing ticked) lights
-- none. Mute Tab on a tab's right click keeps one tab dark (Modules/Chat.lua TAB GLOW).
S:Row{ key = "ch.unreadGlow", kind = "dropdown", path = "chat.unreadGlow", apply = Refresh, section = "ch.notifications",
    choices = { "none", { divider = true }, "say", "yell", "party", "raid", "guild", "whisper", "channel" },
    toggles = { exclusive = { "none" }, tokens = { "say", "yell", "party", "raid", "guild", "whisper", "channel" }, empty = "none" } }
-- Whisper Sound (Notifications, under Tab Glow); picking one plays it
S:Row{ key = "ch.whisperSound", kind = "choice", path = "chat.whisperSound", section = "ch.notifications",
    choices = { "off", "raidwarning", "alarm", "whisper" }, soundPreview = function(v) S:PlayAlertSound(v) end,
    apply = function() if ns.Chat and ns.Chat.PlayWhisperSound then ns.Chat.PlayWhisperSound(true) end end }

-- in pairs: copying and history, what's hidden, the lines (Copy Chat Links and Link Tooltips on
-- Mouseover are always on)
S:Row{ key = "ch.copyButton", tab = "tweaks", path = "chat.copyButton", apply = Refresh, section = "ch.tweaks", half = true }
S:Row{ key = "ch.history", tab = "tweaks", path = "chat.saveHistory", apply = Refresh, section = "ch.tweaks", half = true }
S:Row{ key = "ch.combatLog", tab = "tweaks", path = "chat.hideCombatLog", reload = true, section = "ch.tweaks", half = true }
S:Row{ key = "ch.noBubbles", tab = "tweaks", path = "chat.hideBubblesInInstance", apply = Refresh, section = "ch.tweaks", half = true }
S:Row{ key = "ch.lineHeight", tab = "tweaks", path = "chat.increaseLineHeight", apply = Refresh, section = "ch.tweaks", half = true }
-- Tab Sets Channel lives here, with the other chat tweaks
S:Row{ key = "ch.tabChannel", tab = "tweaks", path = "chat.tabChannel", section = "ch.tweaks", half = true }

-- Formatting (never applied in instances, where chat lines are unreadable)
local function Format(key, path)
    S:Row{ key = "ch." .. key, tab = "tweaks", path = "chat." .. path, apply = Refresh, section = "ch.formatting", half = true }
end
-- Channel Names (the old Short Channel Names switch: on was Number)
-- (a note row: red text in the section title reads as an error)
S:Row{ key = "ch.formattingNote", kind = "text", noTitle = true, tab = "tweaks", section = "ch.formatting" }
S:Row{ key = "ch.channelNames", kind = "choice", tab = "tweaks", section = "ch.formatting", choices = { "full", "short", "number" },
    get = function()
        local mode = S:GetPath("chat.channelNames")
        if mode then return mode end
        return S:GetPath("chat.shortChannels") and "number" or "full"
    end,
    set = function(mode)
        S:SetPath("chat.channelNames", mode)
        S:SetPath("chat.shortChannels", mode ~= "full")
    end,
    apply = Refresh }
-- Icons: one dropdown of toggles over chat.linkIcons / raceIcons / classIcons
local CHAT_ICONS = { "linkIcons", "raceIcons", "classIcons" }
local ICON_SPEC = { exclusive = { "none" }, tokens = CHAT_ICONS, empty = "none" }
S:Row{ key = "ch.icons", kind = "dropdown", tab = "tweaks", section = "ch.formatting", toggles = ICON_SPEC, apply = Refresh,
    choices = { "none", { divider = true }, "linkIcons", "raceIcons", "classIcons" },
    get = function()
        local on = {}
        for _, key in ipairs(CHAT_ICONS) do if S:GetPath("chat." .. key) then on[#on + 1] = key end end
        return #on > 0 and table.concat(on, ",") or "none"
    end,
    set = function(value)
        local set = ns.Conditions.Set(value, ICON_SPEC)
        for _, key in ipairs(CHAT_ICONS) do S:SetPath("chat." .. key, set[key] and true or false) end
    end,
    resetValue = function() return "none" end }
-- Names: Better Player Names (formatPlayer), Better NPC Names (formatNPC) and Level Before Names
-- (showLevel) as toggles, beside Icons; then Whisper Markers | Better Timestamps
local NAMES = { { "player", "formatPlayer" }, { "npc", "formatNPC" }, { "level", "showLevel" } }
local NAMES_SPEC = { exclusive = { "none" }, tokens = { "player", "npc", "level" }, empty = "none" }
local function NamesValue(read)
    local on = {}
    for _, n in ipairs(NAMES) do if read("chat." .. n[2]) then on[#on + 1] = n[1] end end
    return #on > 0 and table.concat(on, ",") or "none"
end
S:Row{ key = "ch.names", kind = "dropdown", tab = "tweaks", section = "ch.formatting", toggles = NAMES_SPEC, apply = Refresh,
    choices = { "none", { divider = true }, "player", "npc", "level" },
    get = function() return NamesValue(function(p) return S:GetPath(p) end) end,
    set = function(value)
        local on = ns.Conditions.Set(value, NAMES_SPEC)
        for _, n in ipairs(NAMES) do S:SetPath("chat." .. n[2], on[n[1]] and true or false) end
    end,
    resetValue = function() return NamesValue(function(p) return S:DefaultPath(p) end) end }
Format("whisperMarkers", "whisperMarkers")
Format("timestamps", "betterTimestamps")

S:FontRows{ module = "ch", tab = "fonts", section = "ch.fonts", apply = Refresh, fonts = {
    { key = "text", path = "chat.chatFont" },
    { key = "tabs", path = "chat.tabFont" },
    { key = "editBox", path = "chat.editBoxFont" },
} }

