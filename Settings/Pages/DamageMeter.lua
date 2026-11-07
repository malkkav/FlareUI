local _, ns = ...
local S = ns.Settings

--------------------------------------------------
-- DAMAGE METER
-- Settings for Modules/DamageMeter.lua; the threat key is a Bindings.xml binding.
--------------------------------------------------
local function Refresh()
    if ns.DamageMeter and ns.DamageMeter.Refresh then ns.DamageMeter:Refresh() end
end

local function BlizzardMeterOn()
    return C_CVar.GetCVarBool("damageMeterEnabled") and true or false
end

S:Module{
    key = "dm", group = "Info", order = 20, enabled = "damagemeter.enabled",
    tabs = { { key = "settings" }, { key = "fonts" } },
    -- FlareUI's meter restyles Blizzard's, which needs "Enable Damage Meter" on
    banner = function()
        if BlizzardMeterOn() then return nil end
        return S:ModuleText("dm", "banner"), S:ModuleText("dm", "bannerButton"), function()
            pcall(C_CVar.SetCVar, "damageMeterEnabled", "1")
            Refresh()
        end
    end,
}

-- the meter stays shown on this page so Frame Opacity can be seen
S:On("PageShown", function(key)
    if ns.DamageMeter and ns.DamageMeter.SetSettingsPreview then ns.DamageMeter:SetSettingsPreview(key == "dm") end
end)

S:Row{ key = "dm.opacity", kind = "choice", path = "damagemeter.opacity", choices = S:OpacityChoices(), apply = Refresh, section = "dm.frame" }

local function ApplyVisibility()
    if ns.DamageMeter and ns.DamageMeter.ApplyVisibility then ns.DamageMeter:ApplyVisibility() end
end
-- Meter Tab in the Chat needs the Chat module; the meter then has the chat's size, the tab shows
-- it and Open the Meter Tab picks it, so Visibility, Match Chat Size and Show on Mouseover wait
local function ChatOff() return not S:GetPath("chat.enabled") end
local function InChat() return S:GetPath("damagemeter.chatTab") and not ChatOff() or false end
local function NotInChat() return not InChat() end

S:Row{ key = "dm.visibility", kind = "choice", path = "damagemeter.visibility",
    choices = { "always", "combat", "hidden", "group" }, apply = ApplyVisibility, disabled = InChat, section = "dm.frame" }
local function AlwaysVisible() return (S:GetPath("damagemeter.visibility") or "always") == "always" end
-- in the chat the tab fades the meter in and out at this speed
S:Row{ key = "dm.fadeSpeed", kind = "choice", path = "damagemeter.fadeSpeed", choices = { "instant", "fast", "slow" },
    apply = ApplyVisibility, disabled = function() return AlwaysVisible() and not InChat() end, section = "dm.frame" }
S:Row{ key = "dm.border", kind = "choice", path = "damagemeter.borderTexture", choices = S.BorderChoices,
    apply = Refresh, section = "dm.frame" }

S:Row{ key = "dm.chatTab", path = "damagemeter.chatTab", apply = Refresh, section = "dm.meterTab", half = true, hidden = ChatOff }
S:Row{ key = "dm.chatTabIgnoreFade", path = "damagemeter.chatTabIgnoreFade", apply = Refresh, section = "dm.meterTab", half = true,
    hidden = ChatOff, disabled = NotInChat }
S:Row{ key = "dm.chatTabOpen", kind = "choice", path = "damagemeter.chatTabOpen", choices = { "click", "combat", "group", "login" },
    apply = ApplyVisibility, section = "dm.meterTab", hidden = ChatOff, disabled = NotInChat }

S:Row{ key = "dm.mouseover", path = "damagemeter.showOnMouseover", apply = ApplyVisibility,
    disabled = function() return AlwaysVisible() or InChat() end, section = "dm.tweaks", half = true }
S:Row{ key = "dm.matchChat", path = "damagemeter.matchChatSize", apply = Refresh, section = "dm.tweaks", half = true,
    hidden = ChatOff, disabled = InChat }
S:Row{ key = "dm.threatCombat", path = "damagemeter.autoThreat", apply = Refresh, section = "dm.tweaks", half = true }
S:Row{ key = "dm.combatTimer", path = "damagemeter.combatTimer", apply = Refresh, section = "dm.tweaks", half = true }
S:Row{ key = "dm.readyCheck", path = "damagemeter.readyCheckButton", apply = Refresh, section = "dm.tweaks", half = true }
S:Row{ key = "dm.countdown", path = "damagemeter.countdownButton", apply = Refresh, section = "dm.tweaks", half = true }
local threatKey = S:BindingAccessors("FLAREUI_THREAT")
S:Row{ key = "dm.threatKey", kind = "keybind", get = threatKey.get, set = threatKey.set, section = "dm.tweaks" }

S:FontRows{ module = "dm", tab = "fonts", section = "dm.fonts", apply = Refresh, fonts = {
    { key = "header", path = "damagemeter.headerFont" },
    { key = "bars", path = "damagemeter.barFont" },
} }

