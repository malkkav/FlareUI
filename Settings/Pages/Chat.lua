local _, ns = ...
local S = ns.Settings
local L = ns.L

--------------------------------------------------
-- CHAT
-- Settings for Modules/Chat.lua in three tabs: Frame, Tweaks and Fonts.
--------------------------------------------------
local function Refresh()
    if ns.Chat and ns.Chat.RefreshAll then ns.Chat:RefreshAll() end
end

S:Module{ key = "ch", group = "interface", order = 10, enabled = "chat.enabled", tabs = {
    { key = "frame" }, { key = "tweaks" }, { key = "fonts" },
    { key = "builder", label = L["Windows"], spanRight = true,
        custom = function(host, side) ns.ChatBuilderEditor.Build(host, side) end,
        refresh = function() ns.ChatBuilderEditor.Refresh() end },
} }

-- Search entry for the custom editor; text lives here rather than generated panel copy.
S:Row{ key = "ch.builder", tab = "builder", kind = "button", labelFn = function() return L["Chat windows, channels, filters and presets"] end,
    buttonText = L["Open"], apply = function() ns.SettingsPanel:Open("ch", "builder") end }

-- chat windows stay shown on this page so Frame Opacity can be seen
S:On("PageShown", function(key)
    if ns.Chat and ns.Chat.SetSettingsPreview then ns.Chat:SetSettingsPreview(key == "ch") end
end)

local function AlwaysVisible() return (S:GetPath("chat.visibility") or "always") == "always" end
S:Row{ key = "ch.opacity", kind = "range", path = "chat.opacity", choices = S:OpacityChoices(), apply = Refresh, section = "ch.frame" }
S:Row{ key = "ch.visibility", kind = "choice", path = "chat.visibility",
    choices = { "always", "interactions", "combat" }, apply = Refresh, section = "ch.frame" }
S:Row{ key = "ch.fade", kind = "choice", path = "chat.fadeSpeed", choices = { "instant", "fast", "slow" },
    apply = Refresh, disabled = AlwaysVisible, section = "ch.frame" }
S:Row{ key = "ch.minAlpha", kind = "choice", path = "chat.minAlpha", choices = S:MinAlphaChoices(),
    apply = Refresh, disabled = AlwaysVisible, section = "ch.frame" }
S:Row{ key = "ch.fadeDelay", kind = "choice", path = "chat.autoHideDelay", choices = { 0, 5, 10, 15, 30 },
    apply = Refresh, disabled = AlwaysVisible, section = "ch.frame" }
S:Row{ key = "ch.border", kind = "choice", path = "chat.borderTexture", choices = S.BorderChoices,
    apply = Refresh, section = "ch.frame" }

S:Row{ key = "ch.editBoxOpacity", kind = "range", path = "chat.editBoxOpacity", choices = S:OpacityChoices(), apply = Refresh, section = "ch.editBoxSection" }
S:Row{ key = "ch.editBox", kind = "choice", path = "chat.editBoxPosition",
    choices = { "inside", "below", "above" }, apply = Refresh, section = "ch.editBoxSection" }

-- in pairs: copying, links and history, what's hidden, the lines
S:Row{ key = "ch.copyButton", tab = "tweaks", path = "chat.copyButton", apply = Refresh, section = "ch.tweaks", half = true }
S:Row{ key = "ch.copyLinks", tab = "tweaks", path = "chat.copyLinks", apply = Refresh, section = "ch.tweaks", half = true }
S:Row{ key = "ch.hoverTooltips", tab = "tweaks", path = "chat.hoverTooltips", section = "ch.tweaks", half = true }
S:Row{ key = "ch.history", tab = "tweaks", path = "chat.saveHistory", apply = Refresh, section = "ch.tweaks", half = true }
S:Row{ key = "ch.combatLog", tab = "tweaks", path = "chat.hideCombatLog", reload = true, section = "ch.tweaks", half = true }
S:Row{ key = "ch.noBubbles", tab = "tweaks", path = "chat.hideBubblesInInstance", apply = Refresh, section = "ch.tweaks", half = true }
S:Row{ key = "ch.lineHeight", tab = "tweaks", path = "chat.increaseLineHeight", apply = Refresh, section = "ch.tweaks", half = true }

-- Formatting (never applied in instances, where chat lines are unreadable)
local function Format(key, path)
    S:Row{ key = "ch." .. key, tab = "tweaks", path = "chat." .. path, apply = Refresh, section = "ch.formatting", half = true }
end
-- Channel Names (the old Short Channel Names switch: on was Number)
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
-- in pairs (Marcus, 11-10): names | colon, NPCs | whispers, time | link icons, race | class icons;
-- the level last
Format("formatPlayer", "formatPlayer")
Format("nameColon", "nameColon")
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
