local _, ns = ...
local S = ns.Settings
local L = ns.L

--------------------------------------------------
-- BUFFS & DEBUFFS
-- Settings for the player's buff and debuff frames (Modules/Auras.lua).
--------------------------------------------------
local function Refresh()
    if ns.Auras and ns.Auras.Refresh then ns.Auras:Refresh() end
end

local function Holder(kind)
    return function() return ns.Auras and ns.Auras.GetFrame and ns.Auras:GetFrame(kind) end
end

S:Module{
    key = "au", group = "combat", order = 50, enabled = "auras.enabled",
    tabs = { { key = "settings" }, { key = "reminders" }, { key = "fonts" } },
    editMode = Holder("buffs"),
    editFrames = { Holder("buffs"), Holder("debuffs"),
                   function() return ns.BuffReminders and ns.BuffReminders.GetFrame and ns.BuffReminders:GetFrame() end },
}

-- the sample icons show on this page, so Timer, Icon Shape and Swipe can be seen
S:On("PageShown", function(key)
    if ns.Auras and ns.Auras.SetSettingsPreview then ns.Auras:SetSettingsPreview(key == "au") end
end)

S:Row{ key = "au.shape", kind = "choice", path = "auras.style", choices = { "round", "square" }, apply = Refresh }
S:Row{ key = "au.swipe", kind = "choice", path = "auras.swipe", choices = { "icon", "border", "both", "none" }, apply = Refresh }
S:Row{ key = "au.timer", kind = "choice", path = "auras.timer", choices = { "below", "bottom", "middle", "none" }, apply = Refresh }
S:Row{ key = "au.timerColor", path = "auras.timerColor", apply = Refresh,
    disabled = function() return S:GetPath("auras.timer") == "none" end }
S:Row{ key = "au.arrive", path = "auras.arrive", apply = Refresh }

local function NoMineFirst()
    local sort = S:GetPath("auras.sort")
    return sort ~= "time" and sort ~= "name"
end
S:Row{ key = "au.sort", kind = "choice", path = "auras.sort", choices = { "default", "applied", "time", "name" }, apply = Refresh }
S:Row{ key = "au.reverse", path = "auras.reverse", apply = Refresh }
S:Row{ key = "au.mineFirst", path = "auras.mineFirst", apply = Refresh, disabled = NoMineFirst }

-- BUFF REMINDERS TAB (BuffReminders.lua): what it watches, when it shows, how it alerts; its place,
-- size and direction are in Edit Mode. All live once it runs (the switch needs a reload).
local function RefreshReminders() if ns.BuffReminders and ns.BuffReminders.Update then ns.BuffReminders.Update() end end
local function NoReminders() return not S:GetPath("auras.reminders") end
local function Reminder(def)
    def.tab = "reminders"
    def.apply = def.apply or RefreshReminders
    if def.key ~= "au.reminders" then def.disabled = def.disabled or NoReminders end
    S:Row(def)
end
Reminder{ key = "au.reminders", path = "auras.reminders", reload = true, apply = false }
Reminder{ key = "au.reminderGroup", kind = "choice", path = "auras.reminder.group", parent = "au.reminders",
    choices = { "all", "party", "self" } }
Reminder{ key = "au.reminderBefore", kind = "choice", path = "auras.reminder.before", parent = "au.reminders",
    choices = { { 0, L["Only When Missing"] }, { 1, "1 min" }, { 2, "2 min" }, { 3, "3 min" }, { 5, "5 min" }, { 10, "10 min" } } }
-- the same warning, set apart for dungeons and raids ("same": the one above)
local function BeforeFor(key)
    return {
        key = key, kind = "choice", parent = "au.reminders",
        choices = { { "same", L["Same as Above"] }, { 0, L["Only When Missing"] }, { 1, "1 min" }, { 2, "2 min" }, { 3, "3 min" },
                    { 5, "5 min" }, { 10, "10 min" } },
    }
end
local dungeon = BeforeFor("au.reminderBeforeDungeon")
dungeon.get = function() return S:GetPath("auras.reminder.beforeDungeon") or "same" end
dungeon.set = function(v) S:SetPath("auras.reminder.beforeDungeon", v ~= "same" and v or nil) end
Reminder(dungeon)
local raid = BeforeFor("au.reminderBeforeRaid")
raid.get = function() return S:GetPath("auras.reminder.beforeRaid") or "same" end
raid.set = function(v) S:SetPath("auras.reminder.beforeRaid", v ~= "same" and v or nil) end
Reminder(raid)
-- a reminder's own choice (the blessing, Thorns' target) is in its icon's right-click menu
Reminder{ key = "au.reminderConsumables", kind = "choice", path = "auras.reminder.consumables", parent = "au.reminders",
    choices = { "off", "instance", "always" } }
-- Forever's camp and sleeping bag, and gathering tracking (both off), in a pair
Reminder{ key = "au.reminderCamping", half = true, path = "auras.reminder.camping", parent = "au.reminders" }
Reminder{ key = "au.reminderGathering", half = true, path = "auras.reminder.gathering", parent = "au.reminders" }
-- When It Shows: alone, in a party, in a raid (in pairs), then the rested areas and the only provider
Reminder{ key = "au.reminderSolo", half = true, path = "auras.reminder.showSolo" }
Reminder{ key = "au.reminderParty", half = true, path = "auras.reminder.showParty" }
Reminder{ key = "au.reminderRaid", half = true, path = "auras.reminder.showRaid" }
Reminder{ key = "au.reminderRested", path = "auras.reminder.hideRested" }   -- first in Hiding, a row of its own
Reminder{ key = "au.reminderProvider", half = true, path = "auras.reminder.onlyProvider" }   -- beside In a Raid
-- your group role hides the group buffs (in pairs)
Reminder{ key = "au.reminderHideTank", half = true, path = "auras.reminder.hideTank" }
Reminder{ key = "au.reminderHideHealer", half = true, path = "auras.reminder.hideHealer" }
Reminder{ key = "au.reminderHideDamage", half = true, path = "auras.reminder.hideDamage" }
Reminder{ key = "au.reminderHideNoRole", half = true, path = "auras.reminder.hideNoRole" }
-- Alerts: the sound, then the two glows
Reminder{ key = "au.reminderSound", kind = "choice", path = "auras.reminder.sound", choices = { "off", "raidwarning", "alarm", "whisper" },
    apply = function() RefreshReminders(); if ns.BuffReminders and ns.BuffReminders.PlayAlert then ns.BuffReminders.PlayAlert(true) end end }
Reminder{ key = "au.reminderGlow", half = true, path = "auras.reminder.glowMissing" }
Reminder{ key = "au.reminderGlowExpiring", half = true, path = "auras.reminder.glowExpiring" }
-- last on the page, centred: the button says how many reminders a right-click hid, and brings them back
Reminder{ key = "au.reminderHidden", kind = "button", center = true,
    labelFn = function()
        local n = ns.BuffReminders and ns.BuffReminders.HiddenCount and ns.BuffReminders.HiddenCount() or 0
        return n > 0 and L["Show %d Hidden Reminders"]:format(n) or L["No Hidden Reminders"]
    end,
    disabled = function()
        return NoReminders() or not (ns.BuffReminders and ns.BuffReminders.HiddenCount and ns.BuffReminders.HiddenCount() > 0)
    end,
    apply = function()
        if ns.BuffReminders and ns.BuffReminders.ShowHidden then ns.BuffReminders.ShowHidden() end
        if ns.SettingsPanel and ns.SettingsPanel.Refresh then ns.SettingsPanel:Refresh() end
    end }

S:FontRows{ module = "au", tab = "fonts", section = "au.fonts", apply = Refresh, fonts = {
    { key = "timer", path = "auras.font" },
    { key = "count", path = "auras.countFont" },
} }
