local _, ns = ...
local S = ns.Settings
local L = ns.L

--------------------------------------------------
-- DAMAGE METER
-- Settings for Modules/DamageMeter.lua.
--------------------------------------------------
local function Refresh()
    if ns.DamageMeter and ns.DamageMeter.Refresh then ns.DamageMeter:Refresh() end
end

local function BlizzardMeterOn()
    return C_CVar.GetCVarBool("damageMeterEnabled") and true or false
end

S:Module{
    key = "dm", group = "combat", order = 60, enabled = "damagemeter.enabled",
    tabs = { { key = "settings" }, { key = "tweaks" }, { key = "fonts" } },   -- "settings" is the Frame tab
    -- FlareUI's meter restyles Blizzard's, which needs "Enable Damage Meter" on
    banner = function()
        if not BlizzardMeterOn() then
            return S:ModuleText("dm", "banner"), S:ModuleText("dm", "bannerButton"), function()
                pcall(C_CVar.SetCVar, "damageMeterEnabled", "1")
                Refresh()
            end
        end
        -- Blizzard's own Edit Mode visibility re-applies itself when a fight starts, and an addon can't
        -- show the meter again in a fight (it would taint Blizzard's meter). In Combat is no trouble:
        -- Blizzard shows it in fights then.
        local meter, kinds = _G.DamageMeter, Enum.DamageMeterVisibility
        local visibility = meter and meter.visibility
        if kinds and (visibility == kinds.Hidden or visibility == kinds.InGroup) then
            return S:ModuleText("dm", "banner2"), S:ModuleText("dm", "banner2Button"), function()
                if not S:OpenEditMode("dm") and InCombatLockdown() then
                    print("|cffff9900FlareUI:|r " .. L["Edit Mode can't open during a fight."])
                end
            end
        end
    end,
}

-- the meter stays shown on this page so Frame Opacity can be seen
S:On("PageShown", function(key)
    if ns.DamageMeter and ns.DamageMeter.SetSettingsPreview then ns.DamageMeter:SetSettingsPreview(key == "dm") end
end)

S:Row{ key = "dm.opacity", kind = "range", path = "damagemeter.opacity", choices = S:OpacityChoices(), apply = Refresh, section = "dm.frame" }

local function ApplyVisibility()
    if ns.DamageMeter and ns.DamageMeter.ApplyVisibility then ns.DamageMeter:ApplyVisibility() end
end
-- Meter Tab in the Chat needs the Chat module; the meter then has the chat's size, the tab shows
-- it and Open the Meter Tab picks it, so Visibility, Match Chat Size and Show on Mouseover wait
local function ChatOff() return not S:GetPath("chat.enabled") end
local function InChat() return S:GetPath("damagemeter.chatTab") and not ChatOff() or false end
local function NotInChat() return not InChat() end

S:Row{ key = "dm.visibility", kind = "choice", path = "damagemeter.visibility",
    choices = { "always", "combat", "group", "hidden" }, apply = ApplyVisibility, disabled = InChat, section = "dm.frame" }
local function AlwaysVisible() return (S:GetPath("damagemeter.visibility") or "always") == "always" end
-- in the chat the tab fades the meter in and out at this speed
S:Row{ key = "dm.fadeSpeed", kind = "choice", path = "damagemeter.fadeSpeed", choices = { "instant", "fast", "slow" },
    apply = ApplyVisibility, disabled = function() return AlwaysVisible() and not InChat() end, section = "dm.frame" }
-- how far it fades: 0% to 90%. Not in the chat, where the meter tab takes the chat's fade
S:Row{ key = "dm.minAlpha", kind = "choice", path = "damagemeter.minAlpha", choices = S:MinAlphaChoices(),
    apply = ApplyVisibility, disabled = function() return AlwaysVisible() or InChat() end, section = "dm.frame" }
S:Row{ key = "dm.border", kind = "choice", path = "damagemeter.borderTexture", choices = S.BorderChoices,
    apply = Refresh, section = "dm.frame" }

S:Row{ key = "dm.chatTab", path = "damagemeter.chatTab", apply = Refresh, section = "dm.meterTab", hidden = ChatOff }
-- the two below sit under the Meter Tab switch (parent): its options, greyed while it is off
S:Row{ key = "dm.chatTabIgnoreFade", path = "damagemeter.chatTabIgnoreFade", apply = Refresh, section = "dm.meterTab", parent = "dm.chatTab",
    hidden = ChatOff, disabled = NotInChat }
S:Row{ key = "dm.chatTabOpen", kind = "choice", path = "damagemeter.chatTabOpen", choices = { "click", "combat", "group", "login" },
    apply = ApplyVisibility, section = "dm.meterTab", parent = "dm.chatTab", hidden = ChatOff, disabled = NotInChat }

S:Row{ key = "dm.mouseover", path = "damagemeter.showOnMouseover", apply = ApplyVisibility,
    disabled = function() return AlwaysVisible() or InChat() end, tab = "tweaks", section = "dm.tweaks", half = true }
S:Row{ key = "dm.matchChat", path = "damagemeter.matchChatSize", apply = Refresh, tab = "tweaks", section = "dm.tweaks", half = true,
    hidden = ChatOff, disabled = InChat }
S:Row{ key = "dm.resetOnInstance", path = "damagemeter.resetOnInstance", tab = "tweaks", section = "dm.tweaks", half = true }
S:Row{ key = "dm.combatTimer", path = "damagemeter.combatTimer", apply = Refresh, tab = "tweaks", section = "dm.tweaks", half = true }
S:Row{ key = "dm.readyCheck", path = "damagemeter.readyCheckButton", apply = Refresh, tab = "tweaks", section = "dm.tweaks", half = true }
S:Row{ key = "dm.countdown", path = "damagemeter.countdownButton", apply = Refresh, tab = "tweaks", section = "dm.tweaks", half = true }
-- Threat tab options: a change shows the Threat tab, with sample rows when nothing is targeted
local function PreviewThreat()
    if ns.DamageMeter and ns.DamageMeter.PreviewThreat then ns.DamageMeter.PreviewThreat() end
end
S:Row{ key = "dm.threatValue", kind = "choice", path = "damagemeter.threatValueDisplay",
    choices = { "both", "percent", "value" }, apply = PreviewThreat, tab = "tweaks", section = "dm.threat" }
S:Row{ key = "dm.threatCombat", path = "damagemeter.autoThreat", apply = Refresh, tab = "tweaks", section = "dm.threat", half = true }
S:Row{ key = "dm.pullLine", path = "damagemeter.threatPullLine", apply = PreviewThreat, tab = "tweaks", section = "dm.threat", half = true }
S:Row{ key = "dm.pullFlash", path = "damagemeter.threatPullFlash", apply = PreviewThreat, tab = "tweaks", section = "dm.threat", half = true }
S:Row{ key = "dm.tankLead", path = "damagemeter.threatTankLead", apply = PreviewThreat, tab = "tweaks", section = "dm.threat", half = true }

S:FontRows{ module = "dm", tab = "fonts", section = "dm.fonts", apply = Refresh, fonts = {
    { key = "header", path = "damagemeter.headerFont" },
    { key = "bars", path = "damagemeter.barFont" },
} }

