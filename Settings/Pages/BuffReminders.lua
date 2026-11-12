local _, ns = ...
local S = ns.Settings
local L = ns.L

--------------------------------------------------
-- BUFF REMINDERS (11-12: its own page, out of Buffs & Debuffs; 6.2: the Reminders tab is a picture)
-- Modules/BuffReminders.lua. Three tabs: what it watches (Reminders: the bar, a spellbook to pick from
-- and the picked reminder's own choices, drawn by Settings/BuffRemindersEditor.lua), the values a
-- reminder takes until it has its own (Defaults), how it warns you (Alerts). What is judged by eye
-- lives in its Edit Mode window instead: size, direction, count text, the glows, the time left, and
-- when the frame shows (Fading). The saved values stay in auras.reminder.*; the switch is
-- auras.reminders.
--------------------------------------------------
local function Refresh() if ns.BuffReminders and ns.BuffReminders.Update then ns.BuffReminders.Update() end end
local function BR() return ns.BuffReminders end
local function Editor() return ns.BuffRemindersEditor end

S:Module{
    key = "br", group = "combat", order = 51, enabled = "auras.reminders",
    tabs = {
        {
            -- the bar and the spellbook in the middle, the picked reminder in the info panel's column
            key = "reminders", preview = true,
            custom = function(host, column) if Editor() then Editor().Build(host, column) end end,
            refresh = function() if Editor() then Editor().Refresh() end end,
        },
        { key = "defaults" },
        { key = "alerts" },
    },
    editMode = function() return BR() and BR().GetFrame and BR():GetFrame() end,
}

local function Row(def)
    def.apply = def.apply or Refresh
    S:Row(def)
end

-- REMINDERS: search-only rows (the tab draws its own controls); their button opens the tab
local function OpenReminders() ns.SettingsPanel:Open("br", "reminders") end
for _, key in ipairs({ "br.pick", "br.weaponOil", "br.consumables", "br.elixirs", "br.supplies", "br.durability",
                       "br.trinkets", "br.camping", "br.gathering", "br.custom" }) do
    S:Row{ key = key, kind = "button", tab = "reminders", buttonText = L["Open"], apply = OpenReminders }
end

-- DEFAULTS: what a reminder takes until it has its own (its Check On, Remind Me and Show)
-- Group Buffs: who a group buff is checked on
Row{ key = "br.group", kind = "choice", tab = "defaults", path = "auras.reminder.group", choices = { "all", "party", "self" } }
-- Timing: before it ends, and apart for dungeons and raids ("same": the main one)
local BEFORE = { { 0, L["Only When Missing"] }, { 1, "1 min" }, { 2, "2 min" }, { 3, "3 min" }, { 5, "5 min" }, { 10, "10 min" } }
Row{ key = "br.before", kind = "choice", tab = "defaults", path = "auras.reminder.before", choices = BEFORE }
local function BeforeFor(key, path)
    local choices = { { "same", L["Same as Above"] } }
    for _, c in ipairs(BEFORE) do choices[#choices + 1] = c end
    Row{ key = key, kind = "choice", half = true, tab = "defaults", parent = "br.before", choices = choices,
        get = function() return S:GetPath(path) or "same" end,
        set = function(v) S:SetPath(path, v ~= "same" and v or nil) end }
end
BeforeFor("br.beforeDungeon", "auras.reminder.beforeDungeon")
BeforeFor("br.beforeRaid", "auras.reminder.beforeRaid")
-- Where: four kinds, the same three choices, in two columns
local WHERE = { "always", "instance", "raid" }
Row{ key = "br.classScope", kind = "choice", half = true, tab = "defaults", path = "auras.reminder.classScope", choices = WHERE }
Row{ key = "br.weaponScope", kind = "choice", half = true, tab = "defaults", path = "auras.reminder.weaponScope", choices = WHERE }
Row{ key = "br.petScope", kind = "choice", half = true, tab = "defaults", path = "auras.reminder.petScope", choices = WHERE }
Row{ key = "br.consumablesWhere", kind = "choice", half = true, tab = "defaults", choices = WHERE,
    get = function() return S:GetPath("auras.reminder.consumablesWhere") or "instance" end,
    set = function(v) S:SetPath("auras.reminder.consumablesWhere", v) end }
-- Group Buffs: only the one who gives it, and the roles that hide them (one list for the four switches)
Row{ key = "br.provider", tab = "defaults", path = "auras.reminder.onlyProvider" }
local ROLE_KEYS = { tank = "hideTank", healer = "hideHealer", damage = "hideDamage", norole = "hideNoRole" }
local ROLE_ORDER = { "tank", "healer", "damage", "norole" }
Row{ key = "br.hideRoles", kind = "dropdown", tab = "defaults",
    choices = { "none", { divider = true }, "tank", "healer", "damage", "norole" },
    toggles = { exclusive = { "none" }, tokens = ROLE_ORDER, empty = "none" },
    get = function()
        local list = {}
        for _, role in ipairs(ROLE_ORDER) do
            if S:GetPath("auras.reminder." .. ROLE_KEYS[role]) then list[#list + 1] = role end
        end
        return #list > 0 and table.concat(list, ",") or "none"
    end,
    set = function(value)
        local set = ns.Conditions.Set(value)
        for _, role in ipairs(ROLE_ORDER) do S:SetPath("auras.reminder." .. ROLE_KEYS[role], set[role] == true) end
    end }
-- Weapons: which oil or stone comes first
Row{ key = "br.playstyle", kind = "choice", tab = "defaults", path = "auras.reminder.playstyle",
    choices = { "auto", "melee", "caster", "healer", "tank" } }

-- ALERTS --------------------------------------
Row{ key = "br.sound", kind = "choice", tab = "alerts", path = "auras.reminder.sound", choices = { "off", "raidwarning", "alarm", "whisper" },
    apply = function() Refresh(); if BR() and BR().PlayAlert then BR().PlayAlert(true) end end }
Row{ key = "br.readyCheck", tab = "alerts", path = "auras.reminder.readyCheck" }
