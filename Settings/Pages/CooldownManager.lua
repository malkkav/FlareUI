local _, ns = ...
local S = ns.Settings
local L = ns.L

--------------------------------------------------
-- COOLDOWN MANAGER (its own page)
-- Modules/CooldownManager.lua: FlareUI's changes to Blizzard's own Cooldown Manager, all off until the
-- page is switched on (cooldownmanager.enabled).
-- What is set for each bar sits in its viewer's Edit Mode dialog (Visibility.lua): icon shape, growth and fading.
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

-- LOOK: the skin (its master, on top) and its colour. Off needs a reload to give Blizzard's look back.
S:Row{ key = "cdm.skin", section = "cdm.look", path = "cooldownmanager.skin", lead = true, reload = true, half = true,
    apply = function() if ns.SettingsPanel and ns.SettingsPanel.Refresh then pcall(ns.SettingsPanel.Refresh, ns.SettingsPanel) end end,
    disabled = BlizzardOff }
-- the Tracked Bars' colour in FlareUI's colour window (Settings/ColorPicker.lua, kind "cdm"), as the XP
-- bar's and the nameplates'; greyed without the skin, which is what paints the bars
S:Row{ key = "cdm.barColor", section = "cdm.look", kind = "button", half = true, buttonText = L["Pick Your Colours"],
    disabled = function() return BlizzardOff() or not S:GetPath("cooldownmanager.skin") end,
    apply = function() if ns.ColorPicker then ns.ColorPicker.Open("cdm") end end }

-- ICONS: the Essential and Utility icons, in pairs: the action buttons' two (keys and presses), then
-- the two about a running effect
S:Row{ key = "cdm.keybinds", section = "cdm.icons", path = "cooldownmanager.keybinds", half = true, apply = Refresh, disabled = BlizzardOff }
S:Row{ key = "cdm.press", section = "cdm.icons", path = "cooldownmanager.press", half = true, apply = Refresh, disabled = BlizzardOff }
S:Row{ key = "cdm.softOverlay", section = "cdm.icons", path = "cooldownmanager.softOverlay", half = true, apply = Refresh, disabled = BlizzardOff }
S:Row{ key = "cdm.effectCooldown", section = "cdm.icons", path = "cooldownmanager.effectCooldown", half = true, apply = Refresh, disabled = BlizzardOff }

-- FONTS: two titled sections, as the Action Bars' (Keybinds, Counts first, the order of the action
-- buttons' fonts). Keybinds greys with Show Keybinds, the rest with the skin; Auto keeps Blizzard's size.
S:FontRows{ module = "cdm", tab = "fonts", section = "cdm.fontsIcons", apply = Refresh,
    disabled = function() return BlizzardOff() or not S:GetPath("cooldownmanager.keybinds") end, fonts = {
    { key = "keybinds", path = "cooldownmanager.keybindFont", autoSize = true },
} }
S:FontRows{ module = "cdm", tab = "fonts", section = "cdm.fontsIcons", apply = Refresh,
    disabled = function() return BlizzardOff() or not S:GetPath("cooldownmanager.skin") end, fonts = {
    { key = "stacks", path = "cooldownmanager.stackFont", autoSize = true },
    { key = "cooldown", path = "cooldownmanager.cooldownFont", autoSize = true },
} }
S:FontRows{ module = "cdm", tab = "fonts", section = "cdm.fontsBars", apply = Refresh,
    disabled = function() return BlizzardOff() or not S:GetPath("cooldownmanager.skin") end, fonts = {
    { key = "bar", path = "cooldownmanager.barFont", autoSize = true },
} }
