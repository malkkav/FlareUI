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
    end,
}

-- chat windows stay shown on this page so Frame Opacity can be seen
S:On("PageShown", function(key)
    if ns.Chat and ns.Chat.SetSettingsPreview then ns.Chat:SetSettingsPreview(key == "ch") end
end)

S:Row{ key = "ch.opacity", kind = "range", path = "chat.opacity", choices = S:OpacityChoices(), apply = Refresh, section = "ch.frame" }
-- (the chat's fading is set in its Edit Mode dialog)
S:Row{ key = "ch.border", kind = "choice", path = "chat.borderTexture", choices = S.BorderChoices,
    apply = Refresh, section = "ch.frame" }
-- Tab Glow: which kinds of lines light an unseen tab; None (or nothing ticked) lights
-- none. Mute Tab on a tab's right click keeps one tab dark (Modules/Chat.lua TAB GLOW).
S:Row{ key = "ch.unreadGlow", kind = "dropdown", path = "chat.unreadGlow", apply = Refresh, section = "ch.frame",
    choices = { "none", { divider = true }, "say", "yell", "party", "raid", "guild", "whisper", "channel" },
    toggles = { exclusive = { "none" }, tokens = { "say", "yell", "party", "raid", "guild", "whisper", "channel" }, empty = "none" } }
-- Tab Sets Channel (Haisen): picking a tab that shows one kind of chat makes it the kind you
-- type in (Modules/Chat.lua TAB SETS CHANNEL). Read on each tab pick, so no apply needed.

S:Row{ key = "ch.editBoxOpacity", kind = "range", path = "chat.editBoxOpacity", choices = S:OpacityChoices(), apply = Refresh, section = "ch.editBoxSection" }
S:Row{ key = "ch.editBox", kind = "choice", path = "chat.editBoxPosition",
    choices = { "inside", "below", "above" }, apply = Refresh, section = "ch.editBoxSection" }

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
-- in pairs: names | NPCs, whispers | time, ...;
-- the level last
Format("formatPlayer", "formatPlayer")
Format("formatNPC", "formatNPC")
Format("whisperMarkers", "whisperMarkers")
Format("timestamps", "betterTimestamps")
Format("linkIcons", "linkIcons")
Format("raceIcons", "raceIcons")
Format("classIcons", "classIcons")
Format("levels", "showLevel")

S:FontRows{ module = "ch", tab = "fonts", section = "ch.fonts", apply = Refresh, fonts = {
    { key = "text", path = "chat.chatFont" },
    { key = "tabs", path = "chat.tabFont" },
    { key = "editBox", path = "chat.editBoxFont" },
} }

-- Header buttons: stored as hide flags, shown as "on = visible"
local function Shown(key, hideKey)
    S:Row{ key = "ch." .. key, apply = Refresh, section = "ch.header", half = true,
        get = function() return not S:GetPath(hideKey) end,
        set = function(on) S:SetPath(hideKey, not on) end }
end
Shown("social", "chat.socialHide")
Shown("channels", "chat.channelHide")
Shown("menu", "chat.menuHide")
S:Row{ key = "ch.volume", path = "chat.showVolume", apply = Refresh, section = "ch.header", half = true }
