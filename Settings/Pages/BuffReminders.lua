local _, ns = ...
local S = ns.Settings
local L = ns.L

--------------------------------------------------
-- BUFF REMINDERS (11-12: its own page, out of Buffs & Debuffs)
-- Modules/BuffReminders.lua. Three tabs: what it watches (Reminders), when and where (When and Where),
-- how it warns you (Alerts). What is judged by eye lives in its Edit Mode window instead: size,
-- direction, count text, the glows, the time left, and when the frame shows (Fading). The saved values
-- stay in auras.reminder.*; the switch is auras.reminders.
--------------------------------------------------
local function Refresh() if ns.BuffReminders and ns.BuffReminders.Update then ns.BuffReminders.Update() end end
local function BR() return ns.BuffReminders end

S:Module{
    key = "br", group = "combat", order = 51, enabled = "auras.reminders",
    tabs = { { key = "reminders" }, { key = "when" }, { key = "alerts" } },
    editMode = function() return BR() and BR().GetFrame and BR():GetFrame() end,
}

local function Row(def)
    def.apply = def.apply or Refresh
    S:Row(def)
end

-- REMINDERS: what it watches ------------------
-- Class Buffs
Row{ key = "br.group", kind = "choice", tab = "reminders", path = "auras.reminder.group", choices = { "all", "party", "self" } }
Row{ key = "br.extras", kind = "dropdown", half = true, tab = "reminders", path = "auras.reminder.extras",
    choices = function() return BR() and BR().ExtraChoices() or {} end,
    toggles = { exclusive = { "none" }, tokens = BR() and BR().ExtraKeys() or {}, empty = "none" } }
Row{ key = "br.playstyle", kind = "choice", half = true, tab = "reminders", path = "auras.reminder.playstyle",
    choices = { "auto", "melee", "caster", "healer", "tank" } }
-- Weapons
Row{ key = "br.weaponOil", tab = "reminders", path = "auras.reminder.weaponOil" }
-- Consumables: Food and Flask on or off (where it shows is on the When and Where tab), then the elixirs
local function ConsumablesOn() return (S:GetPath("auras.reminder.consumables") or "off") ~= "off" end
Row{ key = "br.consumables", tab = "reminders",
    get = ConsumablesOn,
    set = function(on)
        S:SetPath("auras.reminder.consumables", on and (S:GetPath("auras.reminder.consumablesWhere") or "instance") or "off")
    end }
Row{ key = "br.elixirs", kind = "dropdown", tab = "reminders", path = "auras.reminder.elixirs", parent = "br.consumables",
    choices = function() return BR() and BR().ElixirChoices() or {} end,
    toggles = { exclusive = { "none" }, tokens = BR() and BR().ElixirKeys() or {}, empty = "none" },
    disabled = function() return not ConsumablesOn() end }
-- Upkeep, in pairs
Row{ key = "br.supplies", half = true, tab = "reminders", path = "auras.reminder.supplies" }
Row{ key = "br.durability", half = true, tab = "reminders", path = "auras.reminder.durability" }
Row{ key = "br.trinkets", half = true, tab = "reminders", path = "auras.reminder.trinkets" }
Row{ key = "br.camping", half = true, tab = "reminders", path = "auras.reminder.camping" }
Row{ key = "br.gathering", half = true, tab = "reminders", path = "auras.reminder.gathering" }
-- Your Own: add a custom reminder, remove this class's, bring back the hidden ones
Row{ key = "br.custom", kind = "button", half = true, center = true, tab = "reminders",
    apply = function() ns.ShowDialog("FLAREUI_BR_CUSTOM") end }
Row{ key = "br.customClear", kind = "button", half = true, center = true, tab = "reminders",
    labelFn = function()
        local n = BR() and BR().CustomCount and BR().CustomCount() or 0
        return n > 0 and L["Remove %d Custom Reminders"]:format(n) or L["No Custom Reminders"]
    end,
    disabled = function() return not (BR() and BR().CustomCount and BR().CustomCount() > 0) end,
    apply = function()
        if BR() and BR().ClearCustom then BR().ClearCustom() end
        if ns.SettingsPanel and ns.SettingsPanel.Refresh then ns.SettingsPanel:Refresh() end
    end }
Row{ key = "br.hidden", kind = "button", center = true, tab = "reminders",
    labelFn = function()
        local n = BR() and BR().HiddenCount and BR().HiddenCount() or 0
        return n > 0 and L["Show %d Hidden Reminders"]:format(n) or L["No Hidden Reminders"]
    end,
    disabled = function() return not (BR() and BR().HiddenCount and BR().HiddenCount() > 0) end,
    apply = function()
        if BR() and BR().ShowHidden then BR().ShowHidden() end
        if ns.SettingsPanel and ns.SettingsPanel.Refresh then ns.SettingsPanel:Refresh() end
    end }

-- WHEN AND WHERE ------------------------------
-- Timing: before it ends, and apart for dungeons and raids ("same": the main one)
local BEFORE = { { 0, L["Only When Missing"] }, { 1, "1 min" }, { 2, "2 min" }, { 3, "3 min" }, { 5, "5 min" }, { 10, "10 min" } }
Row{ key = "br.before", kind = "choice", tab = "when", path = "auras.reminder.before", choices = BEFORE }
local function BeforeFor(key, path)
    local choices = { { "same", L["Same as Above"] } }
    for _, c in ipairs(BEFORE) do choices[#choices + 1] = c end
    Row{ key = key, kind = "choice", half = true, tab = "when", parent = "br.before", choices = choices,
        get = function() return S:GetPath(path) or "same" end,
        set = function(v) S:SetPath(path, v ~= "same" and v or nil) end }
end
BeforeFor("br.beforeDungeon", "auras.reminder.beforeDungeon")
BeforeFor("br.beforeRaid", "auras.reminder.beforeRaid")
-- Where: four kinds, the same three choices, in two columns
local WHERE = { "always", "instance", "raid" }
Row{ key = "br.classScope", kind = "choice", half = true, tab = "when", path = "auras.reminder.classScope", choices = WHERE }
Row{ key = "br.weaponScope", kind = "choice", half = true, tab = "when", path = "auras.reminder.weaponScope", choices = WHERE }
Row{ key = "br.petScope", kind = "choice", half = true, tab = "when", path = "auras.reminder.petScope", choices = WHERE }
-- Consumables' place: kept while Food and Flask is off, and used again when it comes back on
Row{ key = "br.consumablesWhere", kind = "choice", half = true, tab = "when", choices = WHERE,
    get = function()
        local mode = S:GetPath("auras.reminder.consumables") or "off"
        if mode ~= "off" then return mode end
        return S:GetPath("auras.reminder.consumablesWhere") or "instance"
    end,
    set = function(v)
        S:SetPath("auras.reminder.consumablesWhere", v)
        if ConsumablesOn() then S:SetPath("auras.reminder.consumables", v) end
    end }
-- Group Buffs: only the one who gives it, and the roles that hide them (one list for the four switches)
Row{ key = "br.provider", tab = "when", path = "auras.reminder.onlyProvider" }
local ROLE_KEYS = { tank = "hideTank", healer = "hideHealer", damage = "hideDamage", norole = "hideNoRole" }
local ROLE_ORDER = { "tank", "healer", "damage", "norole" }
Row{ key = "br.hideRoles", kind = "dropdown", tab = "when",
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

-- ALERTS --------------------------------------
Row{ key = "br.sound", kind = "choice", tab = "alerts", path = "auras.reminder.sound", choices = { "off", "raidwarning", "alarm", "whisper" },
    apply = function() Refresh(); if BR() and BR().PlayAlert then BR().PlayAlert(true) end end }
Row{ key = "br.readyCheck", tab = "alerts", path = "auras.reminder.readyCheck" }
