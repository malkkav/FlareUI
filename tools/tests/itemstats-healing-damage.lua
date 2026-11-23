-- Simplified Item Stats > Healing & Damage: "healing by up to X and damage by up to Y" lines.
local hook
_G.TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) hook = fn end }
_G.Enum = { TooltipDataType = { Item = 0 } }
_G.canaccessvalue = function() return true end
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
_G.ITEM_SPELL_TRIGGER_ONEQUIP = "Equip:"
_G.ITEM_SET_BONUS = "Set: %s"
_G.ITEM_MOD_SPELL_POWER_SHORT = "Spell Power"
_G.ITEM_MOD_SPELL_HEALING_DONE_SHORT = "Spell Healing"
_G.ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "Spell Damage"
_G.TOOLTIP_ITEM_STAT_SPELL_POWER_INCREASE = "Equip: Increases damage and healing done by magical spells and effects by up to %1$d."
_G.TOOLTIP_ITEM_STAT_SPELL_HEALING_INCREASE_DAMAGE_INCREASE =
    "Equip: Increases healing done by up to %1$d and damage done by up to %2$d for all magical spells and effects."
_G.TOOLTIP_ITEM_STAT_SPELL_HEALING_DECREASE_DAMAGE_INCREASE =
    "Equip: Decreases healing done by up to %1$d and increases damage done by up to %2$d for all magical spells and effects."
-- a language that names the damage first
_G.TOOLTIP_ITEM_STAT_SPELL_HEALING_INCREASE_DAMAGE_DECREASE = "Equip: Damage down by %2$d, healing up by %1$d."

local db = { enabled = true, shortItemStats = true, healingDamage = "off" }
local ns = { db = { profile = { tooltips = db } } }
assert(loadfile("Modules/ItemStats.lua"))("FlareUI", ns)
assert(hook, "no tooltip hook")

local function shorten(text)
    local line = { GetText = function(self) return self.t end, SetText = function(self, t) self.t = t end, t = text }
    _G.TipTextLeft2 = line
    hook({ GetName = function() return "Tip" end, NumLines = function() return 2 end })
    return line.t
end

local robe = "Equip: Increases healing done by up to 26 and damage done by up to 9 for all magical spells and effects."
local set = "Set: Increases healing done by up to 44 and damage done by up to 15 for all magical spells and effects."

-- Off: the long line stays; other stats still shorten
assert(shorten(robe) == robe)
assert(shorten("Equip: Increases damage and healing done by magical spells and effects by up to 12.") == "+12 Spell Power")

-- Spell Damage
db.healingDamage = "damage"
local s = shorten(robe)
assert(s == "+26 Spell Healing\n+9 Spell Damage", s)
s = shorten("Equip: Decreases healing done by up to 5 and increases damage done by up to 12 for all magical spells and effects.")
assert(s == "-5 Spell Healing\n+12 Spell Damage", s)
s = shorten("Equip: Damage down by 7, healing up by 30.")
assert(s == "+30 Spell Healing\n-7 Spell Damage", s)
s = shorten(set)
assert(s == "Set: +44 Spell Healing\n+15 Spell Damage", s)

-- Spell Power: the damage as Spell Power, the healing on top of it
db.healingDamage = "power"
s = shorten(robe)
assert(s == "+17 Spell Healing\n+9 Spell Power", s)
s = shorten("Equip: Decreases healing done by up to 5 and increases damage done by up to 12 for all magical spells and effects.")
assert(s == "-17 Spell Healing\n+12 Spell Power", s)
s = shorten(set)
assert(s == "Set: +29 Spell Healing\n+15 Spell Power", s)

-- Simplified Item Stats off: nothing changes
db.shortItemStats = false
assert(shorten(robe) == robe)
print("itemstats-healing-damage: ok")
