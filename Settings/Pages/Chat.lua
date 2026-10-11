local _, ns = ...
local S = ns.Settings

--------------------------------------------------
-- CHAT (Modules/Chat.lua). Fixed, no option: border, edit box opacity, the
-- auto-hide delay and what brings chat back (new message, typing, mouse). Extend Chat
-- History are gone; the message formatting options have no switch.
--------------------------------------------------
local function Refresh()
    if ns.Chat and ns.Chat.RefreshAll then ns.Chat:RefreshAll() end
end

S:Module{ key = "ch", group = "Info", order = 10, enabled = "chat.enabled", tabs = { { key = "settings" }, { key = "fonts" } } }

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

-- Edit Box: how dark it is, and where it sits
S:Row{ key = "ch.editBoxOpacity", kind = "choice", path = "chat.editBoxOpacity", choices = S:OpacityChoices(), apply = Refresh, section = "ch.editBoxSection" }
S:Row{ key = "ch.editBox", kind = "choice", path = "chat.editBoxPosition",
    choices = { "inside", "below", "above" }, apply = Refresh, section = "ch.editBoxSection" }

-- Tweaks, two to a line
S:Row{ key = "ch.history", path = "chat.saveHistory", apply = Refresh, section = "ch.tweaks", half = true }
S:Row{ key = "ch.copyLinks", path = "chat.copyLinks", apply = Refresh, section = "ch.tweaks", half = true }
S:Row{ key = "ch.noBubbles", path = "chat.hideBubblesInInstance", apply = Refresh, section = "ch.tweaks", half = true }
S:Row{ key = "ch.combatLog", path = "chat.hideCombatLog", reload = true, section = "ch.tweaks", half = true }



-- Fonts tab
S:FontRows{ module = "ch", tab = "fonts", section = "ch.fonts", apply = Refresh, fonts = {
    { key = "text", path = "chat.chatFont" },
    { key = "tabs", path = "chat.tabFont" },
    { key = "editBox", path = "chat.editBoxFont" },
} }

-- Header buttons: a chip on = the button shows
local function Shown(hideKey)
    return {
        get = function() return not S:GetPath(hideKey) end,
        set = function(on) S:SetPath(hideKey, not on) end,
    }
end
local social, channels, menu = Shown("chat.socialHide"), Shown("chat.channelHide"), Shown("chat.menuHide")
S:Row{
    key = "ch.headerButtons", kind = "chips", apply = Refresh,
    items = {
        { get = social.get, set = social.set },
        { get = channels.get, set = channels.set },
        { get = menu.get, set = menu.set },
        { path = "chat.showVolume" },
    },
}
