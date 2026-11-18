local _, ns = ...
local S = ns.Settings
local L = ns.L

--------------------------------------------------
-- COOLDOWN MANAGER (its own page)
-- Modules/CooldownManager.lua: FlareUI's changes to Blizzard's own Cooldown Manager, all off until the
-- page is switched on (cooldownmanager.enabled).
--------------------------------------------------
local function CM() return ns.CooldownManager end
local function Refresh() if CM() and CM().Refresh then CM():Refresh() end end
-- (greyed while Blizzard's own Cooldown Manager is off in the game's options: it is left alone then)
local function BlizzardOff() return not (CM() and CM().BlizzardOn()) end

S:Module{
    key = "cdm", group = "combat", order = 15, enabled = "cooldownmanager.enabled",
    tabs = { { key = "settings" }, { key = "fonts" } },
}

-- off needs a reload to give Blizzard's look back
S:Row{ key = "cdm.skin", section = "cdm.look", path = "cooldownmanager.skin", reload = true, disabled = BlizzardOff }

-- with Skin Cooldown Manager on; Auto keeps Blizzard's size
S:FontRows{ module = "cdm", tab = "fonts", section = "cdm.fonts", apply = Refresh,
    disabled = function() return BlizzardOff() or not S:GetPath("cooldownmanager.skin") end, fonts = {
    { key = "stacks", path = "cooldownmanager.stackFont", autoSize = true },
    { key = "cooldown", path = "cooldownmanager.cooldownFont", autoSize = true },
    { key = "bar", path = "cooldownmanager.barFont", autoSize = true },
} }
