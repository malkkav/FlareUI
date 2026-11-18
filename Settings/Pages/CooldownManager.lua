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
}

-- off needs a reload to give Blizzard's look back
S:Row{ key = "cdm.skin", section = "cdm.look", path = "cooldownmanager.skin", reload = true, disabled = BlizzardOff }
