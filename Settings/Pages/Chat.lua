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

S:Module{ key = "ch", group = "Info", order = 10, enabled = "chat.enabled" }

-- on this page the windows stay fully shown, so Frame Opacity can be seen
S:On("PageShown", function(key)
    if ns.Chat and ns.Chat.SetSettingsPreview then ns.Chat:SetSettingsPreview(key == "ch") end
end)

-- how dark the background is (0.5 by default)
S:Row{ key = "ch.opacity", kind = "choice", path = "chat.opacity", choices = S:OpacityChoices(), apply = Refresh }

S:Row{ key = "ch.editBox", kind = "choice", path = "chat.editBoxPosition",
    choices = { "inside", "below", "above" }, apply = Refresh }

-- Fade chat: the chat fades out and comes back at once (no slow fade)
S:Row{ key = "ch.fade", path = "chat.autoHideEnabled", apply = Refresh }

S:Row{ key = "ch.history", path = "chat.saveHistory", apply = Refresh }
S:Row{ key = "ch.copyLinks", path = "chat.copyLinks", apply = Refresh }
S:Row{ key = "ch.noBubbles", path = "chat.hideBubblesInInstance", apply = Refresh }
S:Row{ key = "ch.combatLog", path = "chat.hideCombatLog", reload = true }

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
S:Row{ key = "ch.headerHelp", kind = "text", section = "ch.howTo" }
