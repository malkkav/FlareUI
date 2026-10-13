local _, ns = ...
local S = ns.Settings

--------------------------------------------------
-- CHAT (Modules/Chat.lua). Fixed, no option: what brings chat back (new message, typing, mouse).
-- Tabs: Frame (Frame, Edit Box, Header Buttons), Tweaks (Tweaks, Formatting), Fonts.
--------------------------------------------------
local function Refresh()
    if ns.Chat and ns.Chat.RefreshAll then ns.Chat:RefreshAll() end
end

S:Module{ key = "ch", group = "Info", order = 10, enabled = "chat.enabled", tabs = { { key = "frame" }, { key = "tweaks" }, { key = "fonts" } } }

-- on this page the windows stay fully shown, so Frame Opacity can be seen
S:On("PageShown", function(key)
    if ns.Chat and ns.Chat.SetSettingsPreview then ns.Chat:SetSettingsPreview(key == "ch") end
end)

-- Frame: how dark the background is (0.5 by default), where you type, and when the chat shows.
-- Visibility: when the chat stays up (pointing at it always shows it); Fade Speed: how fast it goes
-- and comes; Fade Delay: how long it stays after showing.
local function AlwaysVisible() return (S:GetPath("chat.visibility") or "always") == "always" end
S:Row{ key = "ch.opacity", kind = "choice", path = "chat.opacity", choices = S:OpacityChoices(), apply = Refresh, section = "ch.frame" }
S:Row{ key = "ch.visibility", kind = "choice", path = "chat.visibility",
    choices = { "always", "interactions", "combat" }, apply = Refresh, section = "ch.frame" }
S:Row{ key = "ch.fade", kind = "choice", path = "chat.fadeSpeed", choices = { "instant", "fast", "slow" },
    apply = Refresh, disabled = AlwaysVisible, section = "ch.frame" }
S:Row{ key = "ch.fadeDelay", kind = "choice", path = "chat.autoHideDelay", choices = { 0, 5, 10, 15, 30 },
    apply = Refresh, disabled = AlwaysVisible, section = "ch.frame" }
S:Row{ key = "ch.border", kind = "choice", path = "chat.borderTexture", choices = S.BorderChoices,
    apply = Refresh, section = "ch.frame" }

-- Edit Box: how dark it is, and where it sits
S:Row{ key = "ch.editBoxOpacity", kind = "choice", path = "chat.editBoxOpacity", choices = S:OpacityChoices(), apply = Refresh, section = "ch.editBoxSection" }
S:Row{ key = "ch.editBox", kind = "choice", path = "chat.editBoxPosition",
    choices = { "inside", "below", "above" }, apply = Refresh, section = "ch.editBoxSection" }

-- Tweaks tab: switches two to a line
S:Row{ key = "ch.history", tab = "tweaks", path = "chat.saveHistory", apply = Refresh, section = "ch.tweaks", half = true }
S:Row{ key = "ch.copyLinks", tab = "tweaks", path = "chat.copyLinks", apply = Refresh, section = "ch.tweaks", half = true }
S:Row{ key = "ch.noBubbles", tab = "tweaks", path = "chat.hideBubblesInInstance", apply = Refresh, section = "ch.tweaks", half = true }
S:Row{ key = "ch.combatLog", tab = "tweaks", path = "chat.hideCombatLog", reload = true, section = "ch.tweaks", half = true }

-- Formatting: how messages read, in two columns (never in instances, where Blizzard keeps chat
-- lines out of reach)
local function Format(key, path)
    S:Row{ key = "ch." .. key, tab = "tweaks", path = "chat." .. path, apply = Refresh, section = "ch.formatting", half = true }
end
Format("formatNPC", "formatNPC")
Format("formatPlayer", "formatPlayer")
Format("timestamps", "betterTimestamps")
Format("shortChannels", "shortChannels")
Format("levels", "showLevel")

-- Fonts tab
S:FontRows{ module = "ch", tab = "fonts", section = "ch.fonts", apply = Refresh, fonts = {
    { key = "text", path = "chat.chatFont" },
    { key = "tabs", path = "chat.tabFont" },
    { key = "editBox", path = "chat.editBoxFont" },
} }

-- Header buttons: on = the button shows, two to a line
local function Shown(key, hideKey)
    S:Row{ key = "ch." .. key, apply = Refresh, section = "ch.header", half = true,
        get = function() return not S:GetPath(hideKey) end,
        set = function(on) S:SetPath(hideKey, not on) end }
end
Shown("social", "chat.socialHide")
Shown("channels", "chat.channelHide")
Shown("menu", "chat.menuHide")
S:Row{ key = "ch.volume", path = "chat.showVolume", apply = Refresh, section = "ch.header", half = true }
