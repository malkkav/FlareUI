local _, ns = ...
local S = ns.Settings

--------------------------------------------------
-- DAMAGE METER (Modules/DamageMeter.lua). Always on, with no switch: combat timer, Threat
-- tab, Ready Check and Countdown buttons; the border. The threat toggle
-- key is a key binding (Bindings.xml), bound here or in Blizzard's Key Bindings.
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
    -- FlareUI's meter shows Blizzard's: it needs Blizzard's "Enable Damage Meter" on
    banner = function()
        if BlizzardMeterOn() then return nil end
        return S:ModuleText("dm", "banner"), S:ModuleText("dm", "bannerButton"), function()
            pcall(C_CVar.SetCVar, "damageMeterEnabled", "1")
            Refresh()
        end
    end,
}

-- on this page the meter shows, whatever its visibility, so Frame Opacity can be seen
S:On("PageShown", function(key)
    if ns.DamageMeter and ns.DamageMeter.SetSettingsPreview then ns.DamageMeter:SetSettingsPreview(key == "dm") end
end)

-- how dark the background is (0.5 by default)
S:Row{ key = "dm.opacity", kind = "choice", path = "damagemeter.opacity", choices = S:OpacityChoices(), apply = Refresh, section = "dm.frame" }

-- when the meter shows (FlareUI's, over Blizzard's Edit Mode one), and the mouseover while it hides
local function ApplyVisibility()
    if ns.DamageMeter and ns.DamageMeter.ApplyVisibility then ns.DamageMeter:ApplyVisibility() end
end
S:Row{ key = "dm.visibility", kind = "choice", path = "damagemeter.visibility",
    choices = { "always", "combat", "hidden", "group" }, apply = ApplyVisibility, section = "dm.frame" }
local function AlwaysVisible() return (S:GetPath("damagemeter.visibility") or "always") == "always" end
S:Row{ key = "dm.fadeSpeed", kind = "choice", path = "damagemeter.fadeSpeed", choices = { "instant", "fast", "slow" },
    apply = ApplyVisibility, disabled = AlwaysVisible, section = "dm.frame" }

-- Tweaks, two to a line; the threat key on a line of its own below
S:Row{ key = "dm.mouseover", path = "damagemeter.showOnMouseover", apply = ApplyVisibility,
    disabled = AlwaysVisible, section = "dm.tweaks", half = true }
S:Row{ key = "dm.matchChat", path = "damagemeter.matchChatSize", apply = Refresh, section = "dm.tweaks", half = true,
    hidden = function() return not S:GetPath("chat.enabled") end }
S:Row{ key = "dm.threatCombat", path = "damagemeter.autoThreat", apply = Refresh, section = "dm.tweaks", half = true }
S:Row{ key = "dm.combatTimer", path = "damagemeter.combatTimer", apply = Refresh, section = "dm.tweaks", half = true }
S:Row{ key = "dm.readyCheck", path = "damagemeter.readyCheckButton", apply = Refresh, section = "dm.tweaks", half = true }
S:Row{ key = "dm.countdown", path = "damagemeter.countdownButton", apply = Refresh, section = "dm.tweaks", half = true }
local threatKey = S:BindingAccessors("FLAREUI_THREAT")
S:Row{ key = "dm.threatKey", kind = "keybind", get = threatKey.get, set = threatKey.set, section = "dm.tweaks" }

S:FontRows{ module = "dm", tab = "fonts", section = "dm.fonts", apply = Refresh, fonts = {
    { key = "bars", path = "damagemeter.barFont" },
} }

