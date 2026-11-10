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
    key = "au", group = "HUD", order = 50, enabled = "auras.enabled",
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
-- first under the switch (rank 0.5: ahead of the dropdowns), Marcus 11-10
Reminder{ key = "au.reminderPets", path = "auras.reminder.pets", parent = "au.reminders", rank = 0.5 }
Reminder{ key = "au.reminderGroup", kind = "choice", path = "auras.reminder.group", parent = "au.reminders",
    choices = { "all", "party", "self" } }
Reminder{ key = "au.reminderBefore", kind = "choice", path = "auras.reminder.before", parent = "au.reminders",
    choices = { { 0, L["Only When Missing"] }, { 1, "1 min" }, { 2, "2 min" }, { 3, "3 min" }, { 5, "5 min" }, { 10, "10 min" } } }
-- the blessings' names come from the game, in your language
Reminder{ key = "au.reminderBlessing", kind = "choice", path = "auras.reminder.blessing", parent = "au.reminders",
    choices = function()
        local names = ns.BuffReminders and ns.BuffReminders.BlessingChoices and ns.BuffReminders.BlessingChoices()
        return names or { { "auto", L["Automatic"] } }
    end }
Reminder{ key = "au.reminderConsumables", kind = "choice", path = "auras.reminder.consumables", parent = "au.reminders",
    choices = { "off", "instance", "always" } }
-- When It Shows: alone, in a party, in a raid (in pairs), then the rested areas and the only provider
Reminder{ key = "au.reminderSolo", half = true, path = "auras.reminder.showSolo" }
Reminder{ key = "au.reminderParty", half = true, path = "auras.reminder.showParty" }
Reminder{ key = "au.reminderRaid", half = true, path = "auras.reminder.showRaid" }
Reminder{ key = "au.reminderRested", half = true, path = "auras.reminder.hideRested" }
Reminder{ key = "au.reminderProvider", path = "auras.reminder.onlyProvider" }
-- Alerts: the sound, then the two glows
Reminder{ key = "au.reminderSound", kind = "choice", path = "auras.reminder.sound", choices = { "off", "raidwarning", "alarm", "whisper" },
    apply = function() RefreshReminders(); if ns.BuffReminders and ns.BuffReminders.PlayAlert then ns.BuffReminders.PlayAlert(true) end end }
Reminder{ key = "au.reminderGlow", half = true, path = "auras.reminder.glowMissing" }
Reminder{ key = "au.reminderGlowExpiring", half = true, path = "auras.reminder.glowExpiring" }

S:FontRows{ module = "au", tab = "fonts", section = "au.fonts", apply = Refresh, fonts = {
    { key = "timer", path = "auras.font" },
    { key = "count", path = "auras.countFont" },
} }
