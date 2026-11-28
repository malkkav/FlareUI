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
    key = "dm", group = "interface", order = 15, enabled = "damagemeter.enabled",
    tabs = { { key = "settings" }, { key = "threat" }, { key = "fonts" } },   -- "settings" is the Damage tab
    -- its Fading rows sit in Blizzard's meter dialog and the threat window's dialog in Edit Mode
    -- (Modules/Visibility.lua): found by search
    editSystems = function() return ns.Visibility and ns.Visibility.EditSystems and ns.Visibility:EditSystems("dm") or {} end,
    editFrames = { function() return _G.FlareUI_ThreatMeter end },
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

-- Frame Style: Modern (default) or FlareUI, as the chat's; first in Frame, Border hides with FlareUI
S:Row{ key = "dm.frameStyle", kind = "choice", path = "damagemeter.frameStyle", choices = { "flareui", "modern" },
    apply = Refresh, section = "dm.frame" }
S:Row{ key = "dm.opacity", kind = "range", path = "damagemeter.opacity", choices = S:OpacityChoices(), apply = Refresh, section = "dm.frame" }

local function ApplyVisibility()
    if ns.DamageMeter and ns.DamageMeter.ApplyVisibility then ns.DamageMeter:ApplyVisibility() end
end
-- Meter Tab in the Chat needs the Chat module; the meter then has the chat's size, the tab shows
-- it and Open the Meter Tab picks it, so Match Chat Size waits (and the meter's Edit Mode Fading)
local function ChatOff() return not S:GetPath("chat.enabled") end
local function InChat() return S:GetPath("damagemeter.chatTab") and not ChatOff() or false end
local function NotInChat() return not InChat() end

-- (the meter's and the threat window's fading is set in their Edit Mode dialogs)
S:Row{ key = "dm.border", kind = "choice", path = "damagemeter.borderTexture", choices = S.BorderChoices,
    apply = Refresh, section = "dm.frame", hidden = function() return S:GetPath("damagemeter.frameStyle") == "flareui" end }
-- Bar Texture: Blizzard's own bar first (the default), then the unit frames' list
local function BarTextures()
    local list = { { "", L["Blizzard"] }, { divider = true } }
    local values = ns.UnitFrames and ns.UnitFrames.Kit and ns.UnitFrames.Kit.BuildTextureValues
    local made = values and values()
    if type(made) == "function" then made = made() end
    for _, v in ipairs(made or {}) do
        if v.isDivider then list[#list + 1] = { divider = true }
        elseif v.value then list[#list + 1] = { v.value, v.text } end
    end
    return list
end
S:Row{ key = "dm.barTexture", kind = "choice", path = "damagemeter.barTexture", choices = BarTextures,
    apply = Refresh, section = "dm.frame" }

-- Auto Reset: Reset on Entering a Dungeon and Reset on Leaving a Group as toggles
local RESETS = { { "dungeon", "resetOnInstance" }, { "group", "resetOnGroupLeave" } }
local RESET_SPEC = { exclusive = { "none" }, tokens = { "dungeon", "group" }, empty = "none" }
local function ResetValue(read)
    local on = {}
    for _, r in ipairs(RESETS) do if read("damagemeter." .. r[2]) then on[#on + 1] = r[1] end end
    return #on > 0 and table.concat(on, ",") or "none"
end
S:Row{ key = "dm.autoReset", kind = "dropdown", section = "dm.tweaks", toggles = RESET_SPEC,
    choices = { "none", { divider = true }, "dungeon", "group" },
    get = function() return ResetValue(function(p) return S:GetPath(p) end) end,
    set = function(v)
        local on = ns.Conditions.Set(v, RESET_SPEC)
        for _, r in ipairs(RESETS) do S:SetPath("damagemeter." .. r[2], on[r[1]] and true or false) end
    end,
    resetValue = function() return ResetValue(function(p) return S:DefaultPath(p) end) end }
S:Row{ key = "dm.matchChat", path = "damagemeter.matchChatSize", apply = Refresh, section = "dm.tweaks", half = true,
    disabled = function() return ChatOff() or InChat() end }   -- (greyed with Chat off: turning Chat on makes it work)
S:Row{ key = "dm.combatTimer", path = "damagemeter.combatTimer", apply = Refresh, section = "dm.tweaks", half = true }

-- Meter Tab in the Chat: one dropdown of toggles over the old switch (chatTab) and Open the
-- Meter Tab (chatTabOpen). Disable (the default) or Open When Clicked stand alone; In Combat, In a Group and
-- At Login can be ticked together (DamageMeter.lua ApplyChatTab reads them as a set).
local TAB_OPEN = { "combat", "group", "login" }
S:Row{ key = "dm.chatTab", kind = "dropdown", section = "dm.meterTab", disabled = ChatOff,
    choices = { "off", { divider = true }, "click", "combat", "group", "login" },
    toggles = { exclusive = { "off", "click" }, tokens = TAB_OPEN, empty = "off" },
    get = function()
        if not S:GetPath("damagemeter.chatTab") then return "off" end
        return S:GetPath("damagemeter.chatTabOpen") or "combat"
    end,
    set = function(value)
        local on = value ~= nil and value ~= "" and value ~= "off"
        S:SetPath("damagemeter.chatTab", on)
        if on then S:SetPath("damagemeter.chatTabOpen", value) end
    end,
    resetValue = function() return "off" end,
    apply = function() Refresh(); ApplyVisibility() end }
-- greyed while the tab is off (no indent)
S:Row{ key = "dm.chatTabIgnoreFade", path = "damagemeter.chatTabIgnoreFade", apply = Refresh, section = "dm.meterTab",
    disabled = function() return ChatOff() or NotInChat() end }

-- Threat tab options: a change shows the Threat tab, with sample rows when nothing is targeted
local function PreviewThreat()
    if ns.DamageMeter and ns.DamageMeter.PreviewThreat then ns.DamageMeter.PreviewThreat() end
end
-- Threat Meter: Threat Text, then Separate Window | Threat View in Combat, side by side
-- and exclusive: turning one on turns the other off (no indent, no greying). Threat Bars, a section
-- of their own: Tank's Lead | Pull Warning, Pull Aggro Line
-- Threat Window (where threat shows) first, Threat Text second: one choice over
-- damagemeter.threatWindow and damagemeter.autoThreat. Separate Window appears right above or below
-- the meter (DamageMeter.PlaceThreatWindow)
S:Row{ key = "dm.threatMode", kind = "choice", tab = "threat", section = "dm.threat", choices = { "off", "window", "combat" },
    get = function()
        if S:GetPath("damagemeter.threatWindow") then return "window" end
        return S:GetPath("damagemeter.autoThreat") and "combat" or "off"
    end,
    set = function(value)
        S:SetPath("damagemeter.threatWindow", value == "window")
        S:SetPath("damagemeter.autoThreat", value == "combat")
    end,
    resetValue = function() return "off" end,
    apply = function(value)
        Refresh()
        if value == "window" and ns.DamageMeter and ns.DamageMeter.PlaceThreatWindow then ns.DamageMeter.PlaceThreatWindow() end
    end }
S:Row{ key = "dm.threatValue", kind = "choice", path = "damagemeter.threatValueDisplay",
    choices = { "both", "percent", "value" }, apply = PreviewThreat, tab = "threat", section = "dm.threat" }
S:Row{ key = "dm.tankLead", path = "damagemeter.threatTankLead", apply = PreviewThreat, tab = "threat", section = "dm.threatBars", half = true }
S:Row{ key = "dm.pullLine", path = "damagemeter.threatPullLine", apply = PreviewThreat, tab = "threat", section = "dm.threatBars", half = true }
-- Pull Warning: Flash (threatPullFlash) and Sound (threatPullSound) as toggles, each on its own
local PULL = { { "flash", "threatPullFlash" }, { "sound", "threatPullSound" } }
local PULL_SPEC = { exclusive = { "none" }, tokens = { "flash", "sound" }, empty = "none" }
local function PullValue(read)
    local on = {}
    for _, p in ipairs(PULL) do if read("damagemeter." .. p[2]) then on[#on + 1] = p[1] end end
    return #on > 0 and table.concat(on, ",") or "none"
end
S:Row{ key = "dm.pullWarning", kind = "dropdown", tab = "threat", section = "dm.threatBars", toggles = PULL_SPEC,
    choices = { "none", { divider = true }, "flash", "sound" }, apply = PreviewThreat,
    get = function() return PullValue(function(p) return S:GetPath(p) end) end,
    set = function(v)
        local on = ns.Conditions.Set(v, PULL_SPEC)
        for _, p in ipairs(PULL) do S:SetPath("damagemeter." .. p[2], on[p[1]] and true or false) end
    end,
    resetValue = function() return PullValue(function(p) return S:DefaultPath(p) end) end }

S:FontRows{ module = "dm", tab = "fonts", section = "dm.fonts", apply = Refresh, fonts = {
    { key = "header", path = "damagemeter.headerFont" },
    { key = "bars", path = "damagemeter.barFont" },
} }

