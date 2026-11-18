local _, ns = ...
local S = ns.Settings
local L = ns.L

--------------------------------------------------
-- COOLDOWN MANAGER (its own page)
-- Modules/CooldownManager.lua: FlareUI's changes to Blizzard's own Cooldown Manager, all off until the
-- page is switched on (cooldownmanager.enabled).
-- What is set for each bar sits in its viewer's Edit Mode dialog (Visibility.lua): fading.
--------------------------------------------------
local function CM() return ns.CooldownManager end
local function Refresh() if CM() and CM().Refresh then CM():Refresh() end end
-- (greyed while Blizzard's own Cooldown Manager is off in the game's options: it is left alone then)
local function BlizzardOff() return not (CM() and CM().BlizzardOn()) end

S:Module{
    key = "cdm", group = "combat", order = 15, enabled = "cooldownmanager.enabled",
    tabs = { { key = "settings" }, { key = "fonts" } },
    -- Blizzard's viewers: no FlareUI frame to select, so plain Edit Mode
    editMode = function() return nil end,
    editSystems = function() return ns.Visibility and ns.Visibility.EditSystems and ns.Visibility:EditSystems("cdm") or {} end,
}

-- off needs a reload to give Blizzard's look back
S:Row{ key = "cdm.skin", section = "cdm.look", path = "cooldownmanager.skin", reload = true, disabled = BlizzardOff }
-- the Tracked Bars' colour, in Blizzard's colour picker; Cancel gives the colour before back
local function SetBarColor(r, g, b)
    S:SetPath("cooldownmanager.barColor", { r, g, b })
    Refresh()
    if ns.SettingsPanel and ns.SettingsPanel.Refresh then pcall(ns.SettingsPanel.Refresh, ns.SettingsPanel) end
end
S:Row{ key = "cdm.barColor", section = "cdm.look", kind = "button", buttonText = L["Pick Colour"],
    disabled = function() return BlizzardOff() or not S:GetPath("cooldownmanager.skin") end,
    apply = function()
        if not (ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow) then return end
        local before = S:GetPath("cooldownmanager.barColor")
        ColorPickerFrame:SetupColorPickerAndShow({
            r = before[1], g = before[2], b = before[3], hasOpacity = false,
            swatchFunc = function() SetBarColor(ColorPickerFrame:GetColorRGB()) end,
            cancelFunc = function() SetBarColor(before[1], before[2], before[3]) end,
        })
    end }
S:Row{ key = "cdm.softOverlay", section = "cdm.icons", path = "cooldownmanager.softOverlay", apply = Refresh, disabled = BlizzardOff }
S:Row{ key = "cdm.effectCooldown", section = "cdm.icons", path = "cooldownmanager.effectCooldown", apply = Refresh, disabled = BlizzardOff }

-- with Skin Cooldown Manager on; Auto keeps Blizzard's size
S:FontRows{ module = "cdm", tab = "fonts", section = "cdm.fonts", apply = Refresh,
    disabled = function() return BlizzardOff() or not S:GetPath("cooldownmanager.skin") end, fonts = {
    { key = "stacks", path = "cooldownmanager.stackFont", autoSize = true },
    { key = "cooldown", path = "cooldownmanager.cooldownFont", autoSize = true },
    { key = "bar", path = "cooldownmanager.barFont", autoSize = true },
} }
