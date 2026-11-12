local _, ns = ...
local L = ns.L

--------------------------------------------------
-- CLASS BUFF REMINDERS (Buffs & Debuffs > Buff Reminders, off)
-- After EnhanceQoL's class buff reminder: an icon for each of your class's buffs that is missing (or
-- running out) on you or your group, in FlareUI's buff look. Click an icon to cast it. Out of a fight
-- only: the row hides itself as a fight starts (a state driver), and it reads auras only while the
-- game lets addons read them. Known spells only, at your highest rank. Also (11-10, after EnhanceQoL's
-- reminder, the idea only): paladin blessings, picked per member (Blessing: Automatic gives warriors,
-- rogues and hunters Might and everyone else Wisdom, or one for all); a hunter's or warlock's pet
-- missing, dead or hurt (Pet Reminders, on); food and flask buffs (Food and Flask: off, in dungeons and
-- raids, or always; icons only, nothing to click). When It Shows: Solo / Party / Raid, Hide in Rested
-- Areas, Only When You're the Only Provider (a group buff no one else of your class gives). Alerts: a
-- sound when a reminder appears, a gold glow on missing buffs, an orange one on buffs running out.
-- The bar (6.2): what is watched is an ordered list per class (db.bar[CLASS]), picked on the settings
-- page from a spellbook (Settings/BuffRemindersEditor.lua); who, when and where can be set per
-- reminder (db.opts[CLASS][id]), else the Defaults tab's values count.
--------------------------------------------------
local BR = {}
ns.BuffReminders = BR
ns.modules["BuffReminders"] = BR

local ipairs, pairs, wipe = ipairs, pairs, wipe
local math_floor, math_max = math.floor, math.max
local CreateFrame, InCombatLockdown, GetTime = CreateFrame, InCombatLockdown, GetTime
local LEM = LibStub("FlareEditMode")

local function AurasDb()
    return ns.db and ns.db.profile and ns.db.profile.auras
end
local function GetDb()
    local db = AurasDb()
    return db and db.reminder
end

--------------------------------------------------
-- 1. THE BUFFS
-- cast: the spell the icon casts, highest rank first; buffs: every aura that counts (ranks, the
-- group versions, look-alikes). group: checked on the group too; casters: only on mana users.
-- weapon: a temporary weapon enchant on the main hand instead of an aura (cast = nil: no click).
--------------------------------------------------
local FORTITUDE = { 10938, 10937, 2791, 1245, 1244, 1243 }
local INTELLECT = { 10157, 10156, 1461, 1460, 1459 }
local WILD      = { 9885, 9884, 8907, 5234, 6756, 5232, 1126 }
local function Join(a, b) local t = {} for _, v in ipairs(a) do t[#t + 1] = v end for _, v in ipairs(b) do t[#t + 1] = v end return t end

local REMINDERS = {
    PRIEST = {
        { key = "fortitude", cast = FORTITUDE, buffs = Join(FORTITUDE, { 21564, 21562 }), group = true },
        { key = "innerFire", cast = { 10952, 10951, 1006, 602, 7128, 588 } },
        -- talent spells (11-12, a player asked): once the talent teaches the spell, it is known.
        -- Divine Spirit as a group buff on mana users; Shadowform not while your role is healer
        { key = "spirit", cast = { 27841, 14819, 14818, 14752 }, buffs = { 27841, 14819, 14818, 14752, 27681 },
          group = true, casters = true },
        { key = "shadowform", cast = { 15473 }, notRole = "HEALER" },
        -- Shadow Protection on the group: only when ticked in Extra Buffs (11-12)
        { key = "shadowProt", cast = { 10958, 10957, 976 }, buffs = { 10958, 10957, 976, 27683 }, group = true, optIn = true },
    },
    MAGE = {
        { key = "intellect", cast = INTELLECT, buffs = Join(INTELLECT, { 23028 }), group = true, casters = true },
        -- one armor of any kind
        { key = "armor", cast = { 22783, 22782, 6117, 10220, 10219, 7320, 7302, 7301, 7300, 168 } },
    },
    DRUID = {
        { key = "wild", cast = WILD, buffs = Join(WILD, { 21850, 21849 }), group = true },
        -- Thorns (11-10, a druid asked): kept on whoever the Thorns setting picks, tanks by default
        { key = "thorns", cast = { 9910, 9756, 8914, 1075, 782, 467 }, group = true, pick = "thorns" },
        { key = "omen", cast = { 16864 } },   -- Omen of Clarity (talent)
        -- Moonkin Form (talent): only when ticked in Extra Buffs (druids leave it to heal)
        { key = "moonkin", cast = { 24858 }, optIn = true },
    },
    WARLOCK = {
        { key = "armor", cast = { 11735, 11734, 11733, 1086, 706, 696, 687 } },
        -- Firestone / Spellstone on the weapon (11-11, a warlock asked)
        { key = "stone", weapon = "stone" },
    },
    SHAMAN = {
        -- Water Shield and Earth Shield count too
        { key = "shield", cast = { 10432, 10431, 8134, 945, 905, 325, 324 }, buffs = { 10432, 10431, 8134, 945, 905, 325, 324, 408510, 408514 } },
        { key = "imbue", weapon = "imbue" },
    },
    ROGUE = {
        { key = "poison", weapon = "poison" },
    },
    PALADIN = {
        { key = "blessing", blessing = true, group = true },
        -- a tank's threat buff, only while your group role is tank
        { key = "fury", cast = { 25780 }, role = "TANK" },
        -- any aura on (Devotion, Retribution, Concentration, the resistances, Sanctity): Devotion to cast
        { key = "aura", cast = { 10293, 10292, 1032, 10291, 643, 10290, 465 },
          buffs = { 10293, 10292, 1032, 10291, 643, 10290, 465, 10301, 10300, 10299, 10298, 7294, 19746, 19896, 19895,
                    19876, 19898, 19897, 19888, 19900, 19899, 19891, 20218 } },
    },
    WARRIOR = {
        -- no stance at all (Battle Stance to cast)
        { key = "stance", stance = true, cast = { 2457 } },
        -- Battle Shout: you and your party (it reaches no further)
        { key = "shout", cast = { 25289, 11551, 11550, 11549, 6192, 5242, 6673 }, group = true, party = true },
    },
    HUNTER = {
        { key = "pet", pet = "HUNTER" },
        { key = "trueshot", cast = { 20906, 20905, 19506 } },   -- Trueshot Aura (talent)
        -- no aspect up (any counts); a click casts the last fighting aspect seen, else Hawk (11-12)
        { key = "aspect", aspect = true, cast = { 25296, 14322, 14321, 14320, 14319, 14318, 13165, 13163 },
          buffs = { 25296, 14322, 14321, 14320, 14319, 14318, 13165, 13163, 5118, 13159, 20190, 20043, 13161 } },
    },
}
-- the warlock's pet joins its armor, then a healthstone in the bags (Create Healthstone, best rank)
table.insert(REMINDERS.WARLOCK, { key = "pet", pet = "WARLOCK" })
table.insert(REMINDERS.WARLOCK, { key = "healthstone", healthstone = true, cast = { 11730, 11729, 5699, 6202, 6201 } })
-- a Soulstone on a healer (or on yourself; the icon's right-click menu), in a group (11-12)
table.insert(REMINDERS.WARLOCK, { key = "soulstone", soulstone = true, cast = { 20757, 20756, 20755, 20752, 693 } })
-- Soul Link (talent): only while a pet is out
table.insert(REMINDERS.WARLOCK, { key = "soulLink", cast = { 19028 }, needPet = true })
-- a class's own reminder (its Where default is Class Buffs')
for _, defs in pairs(REMINDERS) do
    for _, def in ipairs(defs) do def.classDef = true end
end
-- Demonic Sacrifice's buffs (Imp, Voidwalker, Succubus, Felhunter): one up, no pet is wanted
local SACRIFICE_BUFFS = { 18789, 18790, 18791, 18792 }
local SOULSTONES = { 16896, 16895, 16893, 16892, 5232 }                -- Major to Minor
local SOULSTONE_BUFFS = { 20707, 20762, 20763, 20764, 20765 }          -- Soulstone Resurrection
-- trinkets for the open world, still worn in a dungeon or raid (11-12): the Argent Dawn ones, Carrot on a Stick
local WORLD_TRINKETS = { 12846, 13209, 19812, 11122 }
-- the aspects a click may put back (Cheetah and Pack are never remembered: they daze)
local FIGHT_ASPECTS = { { 25296, 14322, 14321, 14320, 14319, 14318, 13165 }, { 13163 }, { 20190, 20043 }, { 13161 } }
local HEALTHSTONES = { 5512, 5511, 5509, 5510, 9421, 19004, 19005, 19006, 19007, 19008, 19009, 19010, 19011, 19012, 19013 }
-- Camping and Rest (Forever, off): Camp Benefits from a campfire, and while levelling with a Cozy
-- Sleeping Bag in the bags, three Well-Rested stacks (click to use the bag). Gathering Tracking (off):
-- Find Herbs or Find Minerals off while you know one. (IDs from EnhanceQoL's Forever data.)
local CAMP_BUFF, SLEEPING_BAG, WELL_RESTED = 1229741, 211527, 429959
local EXTRAS = {
    { key = "camp", camp = true, buffs = { CAMP_BUFF }, icon = CAMP_BUFF },
    { key = "sleepingBag", bag = true },
    { key = "gathering", gathering = true, cast = { 2383, 8387, 2580, 8388 } },
    -- Weapon Oil / Stone (off, every class; 11-12): an oil or stone on each hand
    { key = "oil", weapon = "oil" },
}
-- food and flask, for every class
local CONSUMABLES = {
    -- Well Fed, and the foods whose buff has its own name (Grilled Squid, Nightfin Soup, Runn Tum Tuber
    -- Surprise, Dirge's Chimaerok Chops, Blessed Sunfruit and its juice)
    { key = "food", consumable = true, buffs = { 19705, 18192, 18194, 22730, 25661, 18125, 18141 }, icon = 19705 },
    { key = "flask", consumable = true, buffs = { 17626, 17627, 17628, 17629 }, icon = 17626 },  -- the four flasks
}

-- Elixirs and More (11-12): the raid consumables a player ticks in the settings. Item (best first), and
-- the buff it gives (Classic IDs, unverified on Forever; the item's own spell name counts too)
local ELIXIRS = {
    { key = "mongoose", items = { 13452 }, buff = 17538 }, { key = "giants", items = { 9206 }, buff = 11405 },
    { key = "greaterAgility", items = { 9187 }, buff = 11334 }, { key = "bruteForce", items = { 13453 }, buff = 17537 },
    { key = "greaterArcane", items = { 13454 }, buff = 17539 }, { key = "shadowPower", items = { 9264 }, buff = 11474 },
    { key = "greaterFirepower", items = { 21546 }, buff = 26276 }, { key = "frostPower", items = { 17708 }, buff = 21920 },
    { key = "fortitude", items = { 3825 }, buff = 3593 }, { key = "superiorDefense", items = { 13445 }, buff = 11348 },
    { key = "sages", items = { 13447 }, buff = 17535 }, { key = "mageblood", items = { 20007 }, buff = 24363 },
    { key = "trollsBlood", items = { 20004 }, buff = 24361 }, { key = "zanzaSpirit", items = { 20079 }, buff = 24382 },
    { key = "zanzaSwiftness", items = { 20081 }, buff = 24383 }, { key = "jujuPower", items = { 12451 }, buff = 16323 },
    { key = "jujuMight", items = { 12460 }, buff = 16329 }, { key = "firewater", items = { 12820 }, buff = 17038 },
    { key = "roids", items = { 8410 }, buff = 10667 }, { key = "scorpok", items = { 8412 }, buff = 10669 },
    { key = "lungJuice", items = { 8411 }, buff = 10668 }, { key = "cerebral", items = { 8423 }, buff = 10692 },
    { key = "gizzard", items = { 8424 }, buff = 10693 }, { key = "rumsey", items = { 21151 }, buff = 25804 },
}
for _, def in ipairs(ELIXIRS) do def.elixir = true end

-- Low Supplies (11-12, off): a reagent below its minimum, once you know the spell that needs it
-- (item, minimum, the spells that use it); a hunter's ammo is counted on its own
local SUPPLIES = {
    WARLOCK = { { item = 6265, min = 3, spells = { 693, 20752, 20755, 20756, 20757, 698, 6201, 11730 } } },   -- Soul Shard
    MAGE    = { { item = 17020, min = 10, spells = { 23028 } } },              -- Arcane Powder (Arcane Brilliance)
    PRIEST  = { { item = 17029, min = 10, spells = { 21562, 21564 } },         -- Sacred Candle (Prayer of Fortitude)
                { item = 17028, min = 10, spells = { 27681 } } },             -- Holy Candle (Prayer of Spirit)
    DRUID   = { { item = 17026, min = 10, spells = { 21849, 21850 } } },       -- Wild Thornroot (Gift of the Wild)
    PALADIN = { { item = 21177, min = 20, spells = { 25782, 25916, 25894, 25918, 25898, 25890, 25895, 25899 } } },   -- Symbol of Kings
    SHAMAN  = { { item = 17030, min = 1, spells = { 20608 } } },               -- Ankh (Reincarnation)
    ROGUE   = { { item = 5140, min = 5, spells = { 1856, 1857 } } },           -- Flash Powder (Vanish)
}
local AMMO_MIN = 200
local AMMO_WEAPONS = { [2] = true, [3] = true, [18] = true }   -- bows, guns, crossbows
local DURABILITY_BELOW = 0.2
local DURABILITY_ICON = "Interface\\Icons\\INV_Hammer_20"   -- a repair hammer

-- Paladin blessings: ranks (highest first) and their Greater versions, which count as covered too
local BLESSINGS = {
    might     = { cast = { 25291, 19838, 19837, 19836, 19835, 19834, 19740 }, greater = { 25916, 25782 } },
    wisdom    = { cast = { 25290, 19854, 19853, 19852, 19850, 19742 }, greater = { 25918, 25894 } },
    kings     = { cast = { 20217 }, greater = { 25898 } },
    salvation = { cast = { 1038 }, greater = { 25895 } },
    light     = { cast = { 19979, 19978, 19977 }, greater = { 25890 } },
    sanctuary = { cast = { 20914, 20913, 20912, 20911 }, greater = { 25899 } },
}
local BLESSING_ORDER = { "might", "wisdom", "kings", "salvation", "light", "sanctuary" }
-- Automatic: the fighters without much use for mana get Might
local MIGHT_CLASSES = { WARRIOR = true, ROGUE = true, HUNTER = true }
-- pets: hunters call, revive and mend; warlocks summon (the last one they summoned, else the first known)
local CALL_PET, REVIVE_PET, MEND_PET = 883, 982, 136
local WARLOCK_SUMMONS = { 691, 697, 712, 688 }   -- Felhunter, Voidwalker, Succubus, Imp
local MEND_BELOW = 0.5
local GLOW_MISSING, GLOW_EXPIRING = { 1, 0.82, 0.25 }, { 1, 0.45, 0.1 }

-- classes that never use mana
local NO_MANA = { WARRIOR = true, ROGUE = true }

-- WEAPON BUFFS (11-11, after a warlock's report): a shaman's imbue, a rogue's poison, a warlock's
-- Firestone / Spellstone, each checked on the main hand and on an off-hand weapon (shields and held
-- items skipped). Only the class's own enchants count (a sharpening stone or a permanent enchant never
-- does). Forever's enchant IDs, by family: the shaman and rogue ones after EnhanceQoL's Forever data
-- (game IDs only), the stones from PrettyTooltip's data (MIT). Click: the imbue (the off-hand: cast, then
-- the off-hand), a poison or stone from the bags (use it, then the weapon), or Create Firestone /
-- Spellstone when none is in the bags. Which one: the icon's right-click menu, per hand; Last Used
-- (the default) is the one last seen on that hand.
local WEAPON_FAMILIES = {
    imbue = {
        rockbiter = { 1, 6, 29, 503, 683, 1663, 1664, 7568 }, flametongue = { 3, 4, 5, 523, 1665, 1666, 7567 },
        frostbrand = { 2, 12, 524, 1667, 1668, 7566 }, windfury = { 283, 284, 525, 1669, 7569 }, earthliving = { 6910, 6985 },
    },
    poison = {
        deadly = { 7, 8, 626, 627, 2630 }, instant = { 323, 324, 325, 623, 624, 625 }, crippling = { 22, 603 },
        mindNumbing = { 23, 35, 643 }, wound = { 703, 704, 705, 706 },
        leeching = { 6912 }, sebacious = { 7254 }, numbing = { 7255 }, atrophic = { 7256 }, occult = { 7542, 7651 },
    },
    stone = { firestone = { 1803, 1823, 1824, 1825 }, spellstone = { 8059, 8060, 8061 } },
}
-- enchant ID -> family, per kind
local WEAPON_ENCHANTS = {}
for kind, families in pairs(WEAPON_FAMILIES) do
    WEAPON_ENCHANTS[kind] = {}
    for family, ids in pairs(families) do
        for _, id in ipairs(ids) do WEAPON_ENCHANTS[kind][id] = family end
    end
end
-- what a click can put on: imbues by their first rank (cast by name: your best rank), poisons and
-- stones by their items, best first (rank 1's item carries the plain name, for the menu)
local WEAPON_OPTIONS = {
    imbue = {
        { key = "windfury", cast = 8232 }, { key = "flametongue", cast = 8024 },
        { key = "rockbiter", cast = 8017 }, { key = "frostbrand", cast = 8033 },
    },
    poison = {
        { key = "instant", items = { 8928, 8927, 8926, 6950, 6949, 6947 } },
        { key = "deadly", items = { 20844, 8985, 8984, 2893, 2892 } },
        { key = "crippling", items = { 3776, 3775 } },
        { key = "mindNumbing", items = { 9186, 6951, 5237 } },
        { key = "wound", items = { 10922, 10921, 10920, 10918 } },
    },
    stone = {
        { key = "firestone", items = { 13701, 13700, 13699, 1254 }, create = { 17953, 17952, 17951, 6366 }, name = 13699 },
        { key = "spellstone", items = { 13603, 13602, 5522 }, create = { 17728, 17727, 2362 }, name = 5522 },
    },
}
-- Oils and stones (11-12, a warlock used wizard oil): offered on every weapon reminder's menu while
-- they are in the bags, and seen as that hand's buff. Item, then Forever's enchant ID (PrettyTooltip's
-- Forever data, via the 11-12 buff reminders research).
local WEAPON_OILS = {
    { 20749, 2628, nil, "wizard" }, { 20750, 2627, nil, "wizard" }, { 20746, 2626, nil, "wizard" }, { 20744, 2623, nil, "wizard" },
    { 20748, 2629, nil, "mana" }, { 20747, 2625, nil, "mana" }, { 20745, 2624, nil, "mana" },
    { 23123, 2685, nil, "wizard" }, { 3824, 25 }, { 3829, 26 },           -- Blessed Wizard, Shadow, Frost Oil
    { 18262, 2506, nil, "stone" }, { 23122, 2684, nil, "stone" },         -- Elemental, Consecrated stone
    { 12404, 1643, "blade", "stone" }, { 7964, 483, "blade", "stone" }, { 2871, 14, "blade", "stone" }, { 2863, 13, "blade", "stone" },
    { 2862, 40, "blade", "stone" },
    { 12643, 1703, "blunt", "stone" }, { 7965, 484, "blunt", "stone" }, { 3241, 21, "blunt", "stone" }, { 3240, 20, "blunt", "stone" },
    { 3239, 19, "blunt", "stone" },
}
local OIL_OPTIONS, OIL_ENCHANTS = {}, {}
for _, o in ipairs(WEAPON_OILS) do
    local key = "oil" .. o[1]
    OIL_OPTIONS[#OIL_OPTIONS + 1] = { key = key, items = { o[1] }, name = o[1], oil = true, edge = o[3], group = o[4] }
    OIL_ENCHANTS[o[2]] = key
end
-- a kind's menu: its own options, then the oils and stones
local WEAPON_CHOICES = {}
for kind, list in pairs(WEAPON_OPTIONS) do WEAPON_CHOICES[kind] = Join(list, OIL_OPTIONS) end
-- the Weapon Oil / Stone reminder (any class, off): its own kind, the oils and stones alone
WEAPON_OPTIONS.oil, WEAPON_CHOICES.oil, WEAPON_ENCHANTS.oil = OIL_OPTIONS, OIL_OPTIONS, OIL_ENCHANTS
-- maces and staves take weightstones, the rest sharpening stones (Enum.ItemWeaponSubclass)
local BLUNT = { [4] = true, [5] = true, [10] = true }
-- Playstyle (11-12): which oils the Weapon Oil / Stone reminder reaches for first; Automatic goes by class
local PLAYSTYLE_OILS = { caster = { "wizard", "mana" }, healer = { "mana", "wizard" }, melee = { "stone" }, tank = { "stone" } }
local CLASS_PLAYSTYLE = { WARRIOR = "melee", ROGUE = "melee", HUNTER = "melee", PALADIN = "melee",
                          MAGE = "caster", WARLOCK = "caster", PRIEST = "caster", DRUID = "caster", SHAMAN = "caster" }
local LOW_CHARGES = 15   -- a poison with this few charges left counts as running out
local POISONS = 2842             -- the rogue's Poisons skill: the reminder waits for it
local PERMANENT = Enum and Enum.ItemEnchantType and Enum.ItemEnchantType.Permanent or 1
local WEAPON_SLOT = { [16] = 0, [17] = 1 }   -- Enum.WeaponSlot MainHand / OffHand

--------------------------------------------------
-- 2. STATE
--------------------------------------------------
local holder, row          -- holder: the Edit Mode frame (hidden in a fight); row: the icons' parent
local icons = {}           -- [i] = secure button
local active = {}          -- this class's reminders, spell names resolved
local DEFAULTS = { point = "CENTER", x = -423, y = -140 }   -- Marcus's own spot (11-11)

local function Readable(v) return canaccessvalue == nil or canaccessvalue(v) end

local function AurasLocked()
    if not (C_Secrets and C_Secrets.ShouldAurasBeSecret) then return false end
    local ok, secret = pcall(C_Secrets.ShouldAurasBeSecret)
    return not ok or not Readable(secret) or secret == true
end

local function Known(id) return id and ns.IsPlayerSpell(id) end
local ClassOption   -- below: a key of the kind's own options

local function SpellName(id)
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
    return name
end

local function SpellIcon(id)
    return C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id) or 134400
end

local function ItemCount(id) return C_Item.GetItemCount and C_Item.GetItemCount(id) or 0 end
local function ItemIcon(id) return C_Item.GetItemIconByID and C_Item.GetItemIconByID(id) or 134400 end
local function ItemName(id)
    local name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
    if not name and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
    return name
end
local function PlayerClass() local _, class = UnitClass("player"); return class end

-- a reminder's id on the bar: its key; an elixir's and your own carry a prefix (an elixir's key can be
-- a class buff's: Fortitude)
function BR.BarId(def)
    if not def then return nil end
    if def.elixir then return "elixir:" .. def.key end
    if def.custom then return "custom:" .. tostring(def.stored and def.stored.uid or def.key) end
    return def.key
end

-- a weapon option you can put on: an imbue you know, a stone you can make or have, any poison
local function BestCreate(o)
    for _, id in ipairs(o.create or {}) do if Known(id) then return id end end
end
local function OptionKnown(kind, o)
    if o.oil then return ItemCount(o.items[1]) > 0 end
    if kind == "imbue" then return Known(o.cast) end
    if kind == "stone" then
        if BestCreate(o) then return true end
        for _, id in ipairs(o.items) do if ItemCount(id) > 0 then return true end end
        return false
    end
    return true
end
function BR.WeaponOptionLabel(kind, o)
    if kind == "imbue" and not o.oil then return SpellName(o.cast) or o.key end
    local id = o.name or o.items[#o.items]
    return C_Item.GetItemNameByID and C_Item.GetItemNameByID(id) or o.key
end

-- an off-hand that takes a weapon buff: a weapon (not a shield or a held item)
local function OffHandWeapon()
    local id = GetInventoryItemID("player", 17)
    if not id or not C_Item.GetItemInfoInstant then return false end
    local classID = select(6, C_Item.GetItemInfoInstant(id))
    return classID == (Enum and Enum.ItemClass and Enum.ItemClass.Weapon or 2)
end

-- the menu's choice for a hand ("imbueMain", "poisonOff", ...), and the remembered one for Last Used
local function WeaponField(entry) return entry.def.weapon .. (entry.slot == 17 and "Off" or "Main") end
local function LastWeapons()
    local me = ns.CharDB and ns.CharDB()
    if not me then return {} end
    me.lastWeapon = me.lastWeapon or {}
    return me.lastWeapon
end

-- the option a click puts on that hand: the menu's pick, else the last one seen there, else the
-- first you can (a rogue: Instant on the main hand, Deadly on the off-hand)
local function PickWeapon(entry)
    local kind = entry.def.weapon
    local db = GetDb() or {}
    local wanted = db[WeaponField(entry)]
    if not wanted or wanted == "auto" or wanted == "any" then
        wanted = LastWeapons()[WeaponField(entry)]
        if not wanted and kind == "poison" then wanted = entry.slot == 17 and "deadly" or "instant" end
    end
    -- the oil reminder with nothing picked or seen: the playstyle's oils first, in its order
    if kind == "oil" and (not wanted or not ClassOption(kind, wanted)) then
        for _, group in ipairs(PLAYSTYLE_OILS[BR.Playstyle()] or {}) do
            for _, o in ipairs(OIL_OPTIONS) do
                if o.group == group and OptionKnown(kind, o) and BR.OilSuits(o, entry.slot) then return o end
            end
        end
    end
    local first
    for _, o in ipairs(WEAPON_CHOICES[kind]) do
        if OptionKnown(kind, o) then
            if o.key == wanted then return o end
            -- the first of the class's own (an oil only when picked or last used); the oil reminder:
            -- the first that suits the weapon
            if not o.oil or (kind == "oil" and BR.OilSuits(o, entry.slot)) then first = first or o end
        end
    end
    return first
end

-- the playstyle: the setting, else your group role, else your class
function BR.Playstyle()
    local style = (GetDb() or {}).playstyle or "auto"
    if style ~= "auto" then return style end
    local ok, role = pcall(UnitGroupRolesAssigned, "player")
    if ok and Readable(role) then
        if role == "HEALER" then return "healer" end
        if role == "TANK" then return "tank" end
    end
    local _, class = UnitClass("player")
    return CLASS_PLAYSTYLE[class] or "melee"
end

-- a stone for the edge of the weapon in that hand (oils suit any)
function BR.OilSuits(o, slot)
    if not o.edge then return true end
    local id = GetInventoryItemID("player", slot)
    if not id or not C_Item.GetItemInfoInstant then return true end
    local sub = select(7, C_Item.GetItemInfoInstant(id))
    if not Readable(sub) or sub == nil then return true end
    return (o.edge == "blunt") == (BLUNT[sub] == true)
end

-- the kind's own option with this key (a Firestone, a poison, an imbue), not an oil
function ClassOption(kind, key)
    for _, o in ipairs(WEAPON_OPTIONS[kind]) do if o.key == key then return o end end
end

-- the class's reminders with the spell to cast (highest known rank) and the aura names that count
local function Resolve()
    wipe(active)
    local _, class = UnitClass("player")
    local classStart = #active + 1
    for _, def in ipairs(REMINDERS[class] or {}) do
        local castID
        for _, id in ipairs(def.cast or {}) do
            if Known(id) then castID = id break end
        end
        local usable = castID
        local entry
        if def.weapon then
            -- one reminder per hand, once something can go on (a rogue: once Poisons is known)
            local kind, any = def.weapon, nil
            for _, o in ipairs(WEAPON_OPTIONS[kind]) do
                if C_Item.RequestLoadItemDataByID then
                    local nameID = o.name or (o.items and o.items[#o.items])
                    if nameID then C_Item.RequestLoadItemDataByID(nameID) end
                end
                if not any and OptionKnown(kind, o) then any = o end
            end
            if kind == "poison" and not Known(POISONS) then any = nil end
            if C_Item.RequestLoadItemDataByID then
                for _, o in ipairs(OIL_OPTIONS) do C_Item.RequestLoadItemDataByID(o.name) end
            end
            if any then
                local icon = kind == "imbue" and SpellIcon(any.cast)
                    or kind == "poison" and SpellIcon(POISONS)
                    or ItemIcon(any.name)
                for _, slot in ipairs({ 16, 17 }) do
                    active[#active + 1] = { def = def, slot = slot, key = def.key .. (slot == 17 and "Off" or ""),
                                            names = {}, icon = icon, tipSpell = kind == "poison" and POISONS or nil }
                end
            end
            usable = false
        elseif def.blessing then
            -- each known blessing: its best rank and the names that cover it
            local known = {}
            for _, key in ipairs(BLESSING_ORDER) do
                local b = BLESSINGS[key]
                local id
                for _, rank in ipairs(b.cast) do if Known(rank) then id = rank break end end
                if id then
                    local names = {}
                    for _, list in ipairs({ b.cast, b.greater }) do
                        for _, rank in ipairs(list) do
                            local name = SpellName(rank)
                            if name then names[name] = true end
                        end
                    end
                    known[key] = { castID = id, names = names, icon = SpellIcon(id) }
                end
            end
            if next(known) then
                local first = known[BLESSING_ORDER[1]] or select(2, next(known))
                entry = { def = def, blessings = known, castID = first.castID, icon = first.icon, names = first.names }
            end
            usable = false
        elseif def.pet then
            local any = def.pet == "HUNTER" and (Known(CALL_PET) or Known(REVIVE_PET))
            if def.pet == "WARLOCK" then
                for _, id in ipairs(WARLOCK_SUMMONS) do if Known(id) then any = true end end
            end
            if any then entry = { def = def, names = {}, icon = SpellIcon(def.pet == "HUNTER" and CALL_PET or 688) } end
            usable = false
        end
        if entry then active[#active + 1] = entry end
        if usable then
            local names = {}
            for _, id in ipairs(def.buffs or def.cast or {}) do
                local name = SpellName(id)
                if name then names[name] = true end
            end
            active[#active + 1] = { def = def, castID = castID, names = names,
                                    icon = SpellIcon(castID or def.icon) }
        end
    end
    -- the class's own (Where > Class Buffs)
    for i = classStart, #active do active[i].classBuff = true end
    for _, def in ipairs(EXTRAS) do
      if def.weapon then
        for _, slot in ipairs({ 16, 17 }) do
            active[#active + 1] = { def = def, slot = slot, key = def.key .. (slot == 17 and "Off" or ""),
                                    names = {}, icon = ItemIcon(20749) }
        end
      else
        local castID
        for _, id in ipairs(def.cast or {}) do
            if Known(id) then castID = id break end
        end
        -- gathering needs a known tracking spell; the camp and the bag are checked as they come
        if castID or not def.cast then
            local names = {}
            for _, id in ipairs(def.buffs or def.cast or {}) do
                local name = SpellName(id)
                if name then names[name] = true end
            end
            local icon = def.bag and (C_Item.GetItemIconByID and C_Item.GetItemIconByID(SLEEPING_BAG)) or SpellIcon(castID or def.icon)
            active[#active + 1] = { def = def, castID = castID, names = names, icon = icon }
        end
      end
    end
    BR.CustomEntries(active)
    -- Low Supplies: the class's reagents, a hunter's ammo
    for _, s in ipairs(SUPPLIES[class] or {}) do
        local needed = false
        for _, id in ipairs(s.spells) do if Known(id) then needed = true break end end
        if needed then
            active[#active + 1] = { def = { key = "supply" .. s.item, supply = s }, names = {}, icon = ItemIcon(s.item),
                                    tipItem = s.item }
        end
    end
    if class == "HUNTER" then
        active[#active + 1] = { def = { key = "ammo", ammo = true }, names = {}, icon = "Interface\\Icons\\INV_Ammo_Arrow_02" }
    end
    active[#active + 1] = { def = { key = "durability", durability = true }, names = {}, icon = DURABILITY_ICON }
    active[#active + 1] = { def = { key = "trinket", trinket = true }, names = {}, icon = ItemIcon(12846) }
    for _, def in ipairs(ELIXIRS) do
        local names = {}
        local name = SpellName(def.buff)
        if name then names[name] = true end
        if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(def.items[1]) end
        active[#active + 1] = { def = def, names = names, icon = ItemIcon(def.items[1]) }
    end
    for _, def in ipairs(CONSUMABLES) do
        local names = {}
        for _, id in ipairs(def.buffs) do
            local name = SpellName(id)
            if name then names[name] = true end
        end
        active[#active + 1] = { def = def, names = names, icon = SpellIcon(def.icon) }
    end
    -- each one's place on the bar (a weapon kind's two hands share one), and its place in this list
    for i, entry in ipairs(active) do
        entry.barId, entry.pos = BR.BarId(entry.def), i
    end
end

BR.Resolve = function() Resolve() end

-- Right-click an icon: hide that reminder until reload, snooze it, or take it off the bar ("CLASS:key",
-- so a mage's and a warlock's armour stay apart). db.hidden (6.1's Never Remind Me) is read once, by
-- BR.DefaultBar.
local dismissed = {}
local snoozed = {}   -- Snooze Until Recast: hidden until the buff is seen again
function BR.HideKey(entry)
    return (PlayerClass() or "") .. ":" .. (entry.key or entry.def and entry.def.key or "")
end

-- where a kind of reminder shows: "always", "instance" (dungeons and raids) or "raid"
local function InScope(mode)
    if not mode or mode == "always" or ns.EditPreviewing() then return true end
    local inInstance, kind = IsInInstance()
    if mode == "raid" then return inInstance and kind == "raid" or false end
    return inInstance and (kind == "party" or kind == "raid") or false
end

-- Your own reminders (11-12; 6.2: picked from the spellbook or the bags), per class (db.custom[class]):
-- { uid, spells = { IDs or names }, items = { IDs } }, any one of them counts. A click casts the first
-- spell you know, else uses the first item in your bags. The uid is its id on the bar ("custom:uid").
local function CustomList(create)
    local db = GetDb()
    if not db then return nil end
    local class = PlayerClass()
    if create then
        db.custom = db.custom or {}
        db.custom[class] = db.custom[class] or {}
    end
    local list = db.custom and db.custom[class]
    for _, c in ipairs(list or {}) do
        if not c.uid then
            db.customSeq = (db.customSeq or 0) + 1
            c.uid = db.customSeq
        end
    end
    return list
end
-- your own reminder that is exactly this one spell (any rank: by name) or this one item, if there is one
function BR.FindOwn(spellID, itemID)
    local name = spellID and SpellName(spellID)
    for _, c in ipairs(CustomList() or {}) do
        local s, i = c.spells or {}, c.items or {}
        if spellID and #s == 1 and #i == 0 then
            local mine = type(s[1]) == "number" and SpellName(s[1]) or s[1]
            if s[1] == spellID or (name and mine == name) then return "custom:" .. c.uid, c end
        elseif itemID and #i == 1 and #s == 0 and i[1] == itemID then
            return "custom:" .. c.uid, c
        end
    end
end
function BR.CustomEntries(out)
    for i, c in ipairs(CustomList() or {}) do
        local def = { key = "custom" .. i, custom = true, stored = c, items = c.items or {} }
        local names, castID, icon = {}, nil, nil
        for _, s in ipairs(c.spells or {}) do
            local id = type(s) == "number" and s or nil
            if not id and C_Spell.GetSpellInfo then
                local info = C_Spell.GetSpellInfo(s)
                id = info and info.spellID
            end
            local name = id and SpellName(id) or (type(s) == "string" and s)
            if name then names[name] = true end
            if id and not castID and Known(id) then castID = id end
            icon = icon or (id and SpellIcon(id))
        end
        for _, item in ipairs(def.items) do
            if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(item) end
            icon = icon or ItemIcon(item)
        end
        out[#out + 1] = { def = def, names = names, castID = castID, icon = icon or 134400 }
    end
end

--------------------------------------------------
-- THE BAR (6.2)
-- db.bar[CLASS]: the reminders that are on, in the order they show. Made once per class from the 6.1
-- settings (BR.DefaultBar), so an update shows what showed before. Changes tell the settings page.
--------------------------------------------------
local listeners = {}
function BR.OnChanged(fn) listeners[#listeners + 1] = fn end
local function Changed()
    for _, fn in ipairs(listeners) do
        local ok, err = pcall(fn)
        if not ok then geterrorhandler()(err) end
    end
end

-- what 6.1 showed: the class's buffs (less the ones never to remind of, plus the ticked Extra Buffs),
-- then the old Reminders tab's switches, then your own
function BR.DefaultBar(class)
    local db = GetDb() or {}
    local hidden = db.hidden or {}
    local list, seen = {}, {}
    local function Add(id, hideKey)
        if seen[id] or hidden[class .. ":" .. (hideKey or id)] then return end
        seen[id] = true
        list[#list + 1] = id
    end
    local extras = ns.Conditions.Set(db.extras or "")
    for _, def in ipairs(REMINDERS[class] or {}) do
        if not def.optIn or extras[def.key] then Add(def.key) end
    end
    if db.camping then Add("camp"); Add("sleepingBag") end
    if db.gathering then Add("gathering") end
    if db.weaponOil then Add("oil") end
    if (db.consumables or "off") ~= "off" then
        Add("food"); Add("flask")
        local ticked = ns.Conditions.Set(db.elixirs or "")
        for _, def in ipairs(ELIXIRS) do
            if ticked[def.key] then Add("elixir:" .. def.key, def.key) end
        end
    end
    if db.supplies then
        for _, s in ipairs(SUPPLIES[class] or {}) do Add("supply" .. s.item) end
        if class == "HUNTER" then Add("ammo") end
    end
    if db.durability then Add("durability") end
    if db.trinkets then Add("trinket") end
    for i, c in ipairs(db.custom and db.custom[class] or {}) do
        if c.uid then Add("custom:" .. c.uid, "custom" .. i) end
    end
    return list
end

function BR.Bar()
    local db = GetDb()
    if not db then return {} end
    local class = PlayerClass()
    db.bar = db.bar or {}
    if not db.bar[class] then
        CustomList()   -- (gives your own their uids first)
        db.bar[class] = BR.DefaultBar(class)
    end
    return db.bar[class]
end

-- id -> place on the bar, rebuilt when the bar is edited or another profile's is read
local barIndex, barFor = {}, nil
local function BarIndex()
    local list = BR.Bar()
    if list ~= barFor then
        barFor = list
        wipe(barIndex)
        for i, id in ipairs(list) do barIndex[id] = i end
    end
    return barIndex
end
function BR.OnBar(id) return id ~= nil and BarIndex()[id] ~= nil end
local function BarEdited()
    barFor = nil
    BR.Update()
    Changed()
end

function BR.AddToBar(id)
    if not id then return end
    if not BR.OnBar(id) then
        local list = BR.Bar()
        list[#list + 1] = id
        BarEdited()
    end
    return id
end

-- your own from a spell or an item (the one you already have for it, else a new one)
function BR.AddOwn(spellID, itemID)
    local id = BR.FindOwn(spellID, itemID)
    if not id then
        local list = CustomList(true)
        if not list then return end
        local db = GetDb()
        db.customSeq = (db.customSeq or 0) + 1
        list[#list + 1] = { uid = db.customSeq, spells = { spellID }, items = { itemID } }
        id = "custom:" .. db.customSeq
        Resolve()
    end
    return BR.AddToBar(id)
end

function BR.RemoveFromBar(id)
    if not id then return end
    local list = BR.Bar()
    for i, have in ipairs(list) do
        if have == id then table.remove(list, i) break end
    end
    local db = GetDb()
    local class = PlayerClass()
    if db and db.opts and db.opts[class] then db.opts[class][id] = nil end
    -- your own goes for good (picking it again makes it anew)
    local uid = tonumber(id:match("^custom:(%d+)$") or "")
    if uid then
        local custom = CustomList()
        for i, c in ipairs(custom or {}) do
            if c.uid == uid then table.remove(custom, i) break end
        end
        Resolve()
    end
    BarEdited()
end

function BR.MoveOnBar(id, delta)
    local list = BR.Bar()
    for i, have in ipairs(list) do
        if have == id then
            local j = i + delta
            if j < 1 or j > #list then return end
            list[i], list[j] = list[j], list[i]
            BarEdited()
            return
        end
    end
end

--------------------------------------------------
-- PER REMINDER: WHO, WHEN, WHERE (6.2)
-- db.opts[CLASS][id] = { who = "all"|"party"|"self", before = minutes, where = "always"|"instance"|"raid" };
-- a field not set takes the Defaults tab's value (Group Buffs, Remind Before It Ends, Where)
--------------------------------------------------
local function DefaultBefore()
    local db = GetDb() or {}
    local minutes = db.before or 2
    local inInstance, kind = IsInInstance()
    local special = inInstance and ((kind == "party" and db.beforeDungeon) or (kind == "raid" and db.beforeRaid))
    if type(special) == "number" then minutes = special end
    return minutes
end
local function DefaultWhere(def)
    local db = GetDb() or {}
    if def.weapon then return db.weaponScope or "always" end
    if def.pet then return db.petScope or "always" end
    if def.elixir or def.consumable then return db.consumablesWhere or "instance" end
    if def.classDef then return db.classScope or "always" end
    return "always"
end
local function OptsFor(id, create)
    local db = GetDb()
    if not (db and id) then return nil end
    local class = PlayerClass()
    if create then
        db.opts = db.opts or {}
        db.opts[class] = db.opts[class] or {}
        db.opts[class][id] = db.opts[class][id] or {}
    end
    return db.opts and db.opts[class] and db.opts[class][id]
end
-- the value, and true when it is the reminder's own (not the default)
function BR.Opt(def, id, field)
    local o = OptsFor(id)
    if o and o[field] ~= nil then return o[field], true end
    if field == "who" then return (GetDb() or {}).group or "all", false end
    if field == "before" then return DefaultBefore(), false end
    return DefaultWhere(def or {}), false
end
local function Opt(entry, field) return BR.Opt(entry.def, entry.barId, field) end
function BR.SetOpt(id, field, value)
    local o = OptsFor(id, true)
    if not o then return end
    o[field] = value
    BR.Update()
    Changed()
end
function BR.ResetOpts(id)
    local db = GetDb()
    local class = PlayerClass()
    if db and db.opts and db.opts[class] then db.opts[class][id] = nil end
    BR.Update()
    Changed()
end
function BR.HasOwnOpts(id)
    local o = OptsFor(id)
    return o ~= nil and next(o) ~= nil
end
-- which of the three a reminder takes: who for group buffs (not Battle Shout's party), when for the
-- ones that run out, where for all
function BR.OptFields(def)
    def = def or {}
    local who = (def.group or def.blessing or def.soulstone) and not def.party
    local untimed = def.supply or def.ammo or def.durability or def.trinket or def.pet or def.healthstone
        or def.stance or def.bag or def.camp or def.gathering or def.soulstone or def.aspect
    return { who = who and true or false, before = not untimed, where = true }
end

local Enabled, Ordered
-- the reminders the settings leave on, for From the Middle's room
function BR.EnabledCount()
    local n = 0
    for _, entry in ipairs(active) do if Enabled(entry) then n = n + 1 end end
    return math.min(n, 12)
end

function Enabled(entry)
    if dismissed[BR.HideKey(entry)] then return false end
    if not BarIndex()[entry.barId] then return false end
    -- the off-hand's reminder: only with a weapon there
    if entry.slot == 17 and not OffHandWeapon() then return false end
    if not InScope(Opt(entry, "where")) then return false end
    if entry.def.notRole and not ns.EditPreviewing() then
        local ok, role = pcall(UnitGroupRolesAssigned, "player")
        if ok and Readable(role) and role == entry.def.notRole then return false end
    end
    if entry.def.role and not ns.EditPreviewing() then
        local ok, role = pcall(UnitGroupRolesAssigned, "player")
        return ok and Readable(role) and role == entry.def.role or false
    end
    return true
end

--------------------------------------------------
-- 3. WHO IS MISSING WHAT
--------------------------------------------------
-- scope: the reminder's Check On ("all", "party" or "self")
local function GroupUnits(out, scope)
    wipe(out)
    scope = scope or "all"
    if scope ~= "self" and IsInRaid() then
        if scope == "all" then
            for i = 1, GetNumGroupMembers() do out[#out + 1] = "raid" .. i end
            return out
        end
    end
    out[1] = "player"
    if scope ~= "self" and IsInGroup() then
        for i = 1, 4 do out[#out + 1] = "party" .. i end
    end
    return out
end

-- someone a buff can reach: there, alive, online, seen and in your phase
local function Reachable(unit)
    if not UnitExists(unit) or UnitIsDeadOrGhost(unit) or not UnitIsConnected(unit) then return false end
    if unit ~= "player" and not UnitIsUnit(unit, "player") then
        if not UnitIsVisible(unit) then return false end
        if UnitPhaseReason and UnitPhaseReason(unit) then return false end
    end
    return true
end

-- true when the unit has one of the names with more than `before` seconds left; second: it has it,
-- but it is running out (Remind Before It Ends)
local function HasBuff(unit, names, before)
    local now = GetTime()
    for i = 1, 40 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
        if not ok or not aura then return false, false end
        local name = aura.name
        if Readable(name) and names[name] then
            local expires = aura.expirationTime
            if not Readable(expires) or not expires or expires == 0 then return true, false end
            local fine = expires - now > before
            return fine, not fine, expires - now
        end
    end
    return false, false
end

-- a hand's weapon buff of one kind (Forever's C_Item.GetWeaponEnchantInfo): missing, running out, and
-- the family seen there. Anything the game hides from addons, or can't tell, counts as there (quiet).
-- mode: "auto" (the class's own or an oil / stone), "any" (any timed enchant) or "class" (the class's own)
local function WeaponMissing(slot, kind, before, mode)
    -- nothing to coat: no weapon in that hand
    if not GetInventoryItemID("player", slot) then return false end
    if slot == 17 and not OffHandWeapon() then return false end
    if not (C_Item and C_Item.GetWeaponEnchantInfo) then return false end
    local ok, enchants = pcall(C_Item.GetWeaponEnchantInfo, WEAPON_SLOT[slot])
    if not ok or not Readable(enchants) or type(enchants) ~= "table" then return false end
    local families = WEAPON_ENCHANTS[kind]
    local some, family, soonest, lowCharges = false, nil, nil, nil
    for _, e in ipairs(enchants) do
        if not Readable(e) or type(e) ~= "table" then return false end
        local has, enchantType, id, left = e.hasEnchant, e.enchantType, e.enchantID, e.timeLeft
        if not (Readable(has) and Readable(enchantType) and Readable(id) and Readable(left)) then return false end
        -- a timed enchant of this kind (no ID: can't tell, so it counts), an oil or stone (not when the
        -- class's own was picked), or any at all (Any Weapon Buff)
        local counts = id == nil or families[id] or (mode ~= "class" and OIL_ENCHANTS[id]) or mode == "any"
        if has and enchantType ~= PERMANENT and counts then
            family = family or (id and (families[id] or OIL_ENCHANTS[id]))
            local seconds = (left or 0) / 1000
            -- a poison running low on charges counts as running out
            local charges = e.charges
            local low = Readable(charges) and charges and charges > 0 and charges <= LOW_CHARGES
            if seconds > before and not low then return false, false, family end
            if seconds > 0 then
                some = true
                soonest = seconds
                lowCharges = low and charges or nil
            end
        end
    end
    return true, some, family, soonest, lowCharges
end

-- what a click puts on a bare hand: the spell (an imbue, Create Firestone), its icon, and a macro
-- for an item from the bags (use it, then the weapon) or an off-hand imbue (cast, then the off-hand)
local function WeaponFix(entry)
    local kind, slot = entry.def.weapon, entry.slot
    local o = PickWeapon(entry)
    -- (the oil reminder with no oil or stone in the bags)
    if not o then return nil, nil, { none = true } end
    if kind == "imbue" and not o.oil then
        if slot == 17 then
            return o.cast, SpellIcon(o.cast), { macro = "/cast " .. (SpellName(o.cast) or "") .. "\n/use 17" }
        end
        return o.cast, SpellIcon(o.cast)
    end
    -- the picked one from the bags, best first; a rogue: else any poison there
    local tries = { o }
    if kind == "poison" then for _, other in ipairs(WEAPON_OPTIONS.poison) do tries[#tries + 1] = other end end
    for _, t in ipairs(tries) do
        for _, item in ipairs(t.items) do
            if ItemCount(item) > 0 then
                return nil, ItemIcon(item), { macro = "/use item:" .. item .. "\n/use " .. slot, tipItem = item }
            end
        end
    end
    -- a stone you can make
    local create = BestCreate(o)
    if create then return create, SpellIcon(create) end
    return nil, nil, { none = true }
end

-- the blessing a member should have, among the ones you know
local function BlessingFor(entry, unit)
    local db = GetDb() or {}
    local wanted = db.blessing or "auto"
    if wanted == "auto" then
        local _, class = UnitClass(unit)
        wanted = MIGHT_CLASSES[class] and "might" or "wisdom"
    end
    if entry.blessings[wanted] then return entry.blessings[wanted] end
    for _, key in ipairs(BLESSING_ORDER) do
        if entry.blessings[key] then return entry.blessings[key] end
    end
end

local function Readable2(a, b) return Readable(a) and Readable(b) end

-- the pet's state: the spell that fixes it and the unit to cast on, or nil when all is well
-- the pet set to Passive (the pet bar's mode button lit): its icon
local function PetPassive()
    if not GetPetActionInfo then return nil end
    for i = 1, (NUM_PET_ACTION_SLOTS or 10) do
        local name, texture, isToken, isActive = GetPetActionInfo(i)
        if (name == "PET_MODE_PASSIVE" or name == "PET_ACTION_MODE_PASSIVE") and isActive then
            return (isToken and _G[texture]) or texture or 132311
        end
    end
end

-- the pet's state: the spell that fixes it and the unit to cast on, or nil when all is well; a pet
-- left on Passive answers with a macro (/petdefensive) and the mode's icon
local function PetFix(entry)
    if IsMounted() then return nil end
    local exists = UnitExists("pet")
    if exists and not UnitIsDead("pet") then
        local passive = PetPassive()
        if passive then return nil, "pet", "/petdefensive", passive end
    end
    if entry.def.pet == "HUNTER" then
        if exists and UnitIsDead("pet") then return Known(REVIVE_PET) and REVIVE_PET, "player" end
        if not exists then return Known(CALL_PET) and CALL_PET, "player" end
        local ok, health, max = pcall(function() return UnitHealth("pet"), UnitHealthMax("pet") end)
        if ok and Readable2(health, max) and max and max > 0 and health / max < MEND_BELOW and Known(MEND_PET) then
            return MEND_PET, "pet"
        end
        return nil
    end
    if exists then return nil end
    -- a pet given up for Demonic Sacrifice: its buff stands in for it (unreadable: quiet)
    for _, id in ipairs(SACRIFICE_BUFFS) do
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
        if not ok or not Readable(aura) or aura then return nil end
    end
    local me = ns.CharDB and ns.CharDB()
    local last = me and me.lastSummon
    if last and Known(last) then return last, "player" end
    for _, id in ipairs(WARLOCK_SUMMONS) do
        if Known(id) then return id, "player" end
    end
end

-- a tank: by group role (the group finder's), or a raid's main tank
local function IsTank(unit)
    local ok, role = pcall(UnitGroupRolesAssigned, unit)
    if ok and Readable(role) and role == "TANK" then return true end
    if GetPartyAssignment then
        local okA, main = pcall(GetPartyAssignment, "MAINTANK", unit)
        if okA and Readable(main) and main then return true end
    end
    return false
end

-- Only When You're the Only Provider: someone else in the group of your class gives it already
local function OtherProvider()
    local _, mine = UnitClass("player")
    local list = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do list[#list + 1] = "raid" .. i end
    elseif IsInGroup() then
        for i = 1, 4 do list[#list + 1] = "party" .. i end
    end
    for _, unit in ipairs(list) do
        if UnitExists(unit) and not UnitIsUnit(unit, "player") and UnitIsConnected(unit) then
            local _, class = UnitClass(unit)
            if class == mine then return true end
        end
    end
    return false
end

-- Hunter Aspect: the aspect up now (remembered when it's one to fight with), and the one a click casts
local function AspectNames()
    if BR.aspectNames then return BR.aspectNames end
    local names = {}
    for i, ranks in ipairs(FIGHT_ASPECTS) do
        for _, id in ipairs(ranks) do
            local n = SpellName(id)
            if n then names[n] = i end
        end
    end
    BR.aspectNames = names
    return names
end
function BR.AspectUp(entry)
    local fight = AspectNames()
    for i = 1, 40 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not ok or not aura then return false end
        local name = aura.name
        if not Readable(name) then return true end
        if entry.names[name] then
            local me = ns.CharDB and ns.CharDB()
            if me and fight[name] then me.lastAspect = fight[name] end
            return true
        end
    end
    return false
end
function BR.AspectToCast()
    local me = ns.CharDB and ns.CharDB()
    local wanted = me and me.lastAspect
    for _, i in ipairs({ wanted or 1, 1, 2 }) do
        for _, id in ipairs(FIGHT_ASPECTS[i] or {}) do
            if Known(id) then return id, SpellIcon(id) end
        end
    end
end

local units = {}
-- each active reminder's missing / total, the first unit to cast on, the spell (when it is not the
-- reminder's own: a blessing or a pet's), and whether nothing is missing, only running out
local function Check(entry, before)
    local def = entry.def
    local who = Opt(entry, "who")
    if (def.group or def.blessing) and (GetDb() or {}).onlyProvider and OtherProvider() then return 0, 0 end
    -- the role filters (When It Shows): your group role hides the group buffs, never your own
    if def.group or def.blessing then
        local db = GetDb() or {}
        local ok, role = pcall(UnitGroupRolesAssigned, "player")
        role = ok and Readable(role) and role or "NONE"
        if (role == "TANK" and db.hideTank) or (role == "HEALER" and db.hideHealer)
                or (role == "DAMAGER" and db.hideDamage) or (role == "NONE" and db.hideNoRole) then
            return 0, 0
        end
    end
    if def.weapon then
        local pick = (GetDb() or {})[WeaponField(entry)] or "auto"
        local mode = pick == "any" and "any" or (ClassOption(def.weapon, pick) and "class") or "auto"
        local missing, running, family, seconds, charges = WeaponMissing(entry.slot, def.weapon, before, mode)
        -- remembered for Last Used (only the ones a click can put on)
        if family then
            for _, o in ipairs(WEAPON_CHOICES[def.weapon]) do
                if o.key == family then LastWeapons()[WeaponField(entry)] = family end
            end
        end
        if not missing then return 0, 1 end
        local castID, icon, action = WeaponFix(entry)
        return 1, 1, "player", castID, icon, running, action, running and seconds or nil, running and charges or nil
    end
    if def.custom then
        -- the item's spell name counts too, once the item has loaded
        if not entry.itemNames and C_Item.GetItemSpell then
            local all = true
            for _, item in ipairs(def.items) do
                local spellName = C_Item.GetItemSpell(item)
                if spellName then entry.names[spellName] = true else all = false end
            end
            entry.itemNames = all or nil
        end
        if not next(entry.names) then return 0, 0 end
        local fine, running, left = HasBuff("player", entry.names, before)
        if fine then return 0, 1 end
        if entry.castID then return 1, 1, "player", nil, nil, running, nil, running and left or nil end
        for _, item in ipairs(def.items) do
            if ItemCount(item) > 0 then
                return 1, 1, "player", nil, ItemIcon(item), running, { item = "item:" .. item, tipItem = item }, running and left or nil
            end
        end
        return 1, 1, "player", nil, nil, running, def.items[1] and { none = true, tipItem = def.items[1] } or nil,
            running and left or nil
    end
    if def.soulstone then
        if not IsInGroup() and (GetDb() or {}).soulstone ~= "self" then return 0, 0 end
        -- one soulstone at a time: anyone with its buff from anyone counts
        local names = BR.soulstoneNames
        if not names then
            names = {}
            for _, id in ipairs(SOULSTONE_BUFFS) do local n = SpellName(id) if n then names[n] = true end end
            BR.soulstoneNames = names
        end
        local target
        local wanted = (GetDb() or {}).soulstone or "healer"
        for _, unit in ipairs(GroupUnits(units, who)) do
            if Reachable(unit) then
                if HasBuff(unit, names, 0) then return 0, 1 end
                if not target then
                    if wanted == "self" then
                        if unit == "player" or UnitIsUnit(unit, "player") then target = unit end
                    else
                        local ok, role = pcall(UnitGroupRolesAssigned, unit)
                        if ok and Readable(role) and role == "HEALER" then target = unit end
                    end
                end
            end
        end
        if not target then return 0, 0 end
        for _, item in ipairs(SOULSTONES) do
            if ItemCount(item) > 0 then
                -- used recently: the stone is on its cooldown, nothing to do yet
                local start = C_Container and C_Container.GetItemCooldown and C_Container.GetItemCooldown(item)
                if Readable(start) and start and start > 0 then return 0, 1 end
                return 1, 1, target, nil, ItemIcon(item), false, { item = "item:" .. item, tipItem = item, unit = target }
            end
        end
        return 1, 1, "player", entry.castID
    end
    if def.trinket then
        local inInstance, kind = IsInInstance()
        if not (inInstance and (kind == "party" or kind == "raid")) and not ns.EditPreviewing() then return 0, 1 end
        for _, slot in ipairs({ 13, 14 }) do
            local id = GetInventoryItemID("player", slot)
            if id and tContains(WORLD_TRINKETS, id) then
                return 1, 1, "player", nil, ItemIcon(id), false, { tipItem = id }
            end
        end
        return 0, 1
    end
    if def.supply then
        local n = ItemCount(def.supply.item)
        if n >= def.supply.min then return 0, 1 end
        return 1, 1, "player", nil, nil, false, { tipItem = def.supply.item }
    end
    if def.ammo then
        local ranged = GetInventoryItemID("player", 18)
        if not ranged or not C_Item.GetItemInfoInstant then return 0, 1 end
        local _, _, _, _, _, classID, subID = C_Item.GetItemInfoInstant(ranged)
        if classID ~= 2 or not AMMO_WEAPONS[subID] then return 0, 1 end
        local ammo = GetInventoryItemID("player", 0)
        local n = ammo and ItemCount(ammo) or 0
        if n >= AMMO_MIN then return 0, 1 end
        return 1, 1, "player", nil, ammo and ItemIcon(ammo) or nil, false, ammo and { tipItem = ammo } or nil
    end
    if def.durability then
        local lowest = 1
        for slot = 1, 19 do
            local cur, max = GetInventoryItemDurability(slot)
            if Readable2(cur, max) and cur and max and max > 0 then lowest = math.min(lowest, cur / max) end
        end
        if lowest >= DURABILITY_BELOW then return 0, 1 end
        return 1, 1, "player", nil, nil, false, { durability = math_floor(lowest * 100) }
    end
    if def.elixir then
        -- the item's own spell name counts too (once the item has loaded)
        if not entry.itemNames and C_Item.GetItemSpell then
            local spellName = C_Item.GetItemSpell(def.items[1])
            if spellName then entry.names[spellName] = true; entry.itemNames = true end
        end
        local fine, running, left = HasBuff("player", entry.names, before)
        if fine then return 0, 1 end
        for _, item in ipairs(def.items) do
            if ItemCount(item) > 0 then
                return 1, 1, "player", nil, ItemIcon(item), running, { item = "item:" .. item, tipItem = item },
                    running and left or nil
            end
        end
        return 1, 1, "player", nil, nil, running, { none = true, tipItem = def.items[1] }, running and left or nil
    end
    if def.aspect then
        local up = BR.AspectUp(entry)
        if up then return 0, 1 end
        return 1, 1, "player", BR.AspectToCast()
    end
    if def.pet then
        local fix, unit, macro, icon = PetFix(entry)
        if macro then return 1, 1, unit, nil, icon, false, { macro = macro } end
        if not fix then return 0, 1 end
        return 1, 1, unit, fix, SpellIcon(fix)
    end
    if def.needPet and not UnitExists("pet") then return 0, 0 end
    if def.stance then
        local form = GetShapeshiftForm and GetShapeshiftForm() or 1
        return (Readable(form) and form == 0) and 1 or 0, 1, "player"
    end
    if def.healthstone then
        for _, id in ipairs(HEALTHSTONES) do
            if (C_Item.GetItemCount and C_Item.GetItemCount(id) or 0) > 0 then return 0, 1 end
        end
        return 1, 1, "player"
    end
    if def.bag then
        -- while levelling, with the bag on you: fewer than three Well-Rested stacks
        if UnitLevel("player") >= 60 or (C_Item.GetItemCount and C_Item.GetItemCount(SLEEPING_BAG) or 0) == 0 then return 0, 1 end
        local stacks = 0
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, WELL_RESTED)
        if ok and aura and Readable(aura.applications) then stacks = aura.applications or 0 end
        if stacks >= 3 then return 0, 1 end
        return 1, 1, "player", nil, nil, false, { item = "item:" .. SLEEPING_BAG }
    end
    if def.gathering then
        -- the minimap's tracking list where the client has one, else the tracking buff
        if C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo then
            for i = 1, C_Minimap.GetNumTrackingTypes() do
                local info = C_Minimap.GetTrackingInfo(i)
                if info and info.active and info.spellID and tContains(def.cast, info.spellID) then return 0, 1 end
            end
        end
        return HasBuff("player", entry.names, 0) and 0 or 1, 1, "player"
    end
    if def.blessing then
        local missing, total, first, firstBlessing, gone = 0, 0, nil, nil, false
        for _, unit in ipairs(GroupUnits(units, who)) do
            if Reachable(unit) then
                local b = BlessingFor(entry, unit)
                if b then
                    total = total + 1
                    local fine, running = HasBuff(unit, b.names, before)
                    if not fine then
                        missing = missing + 1
                        if not running then gone = true end
                        if not first then first, firstBlessing = unit, b end
                    end
                end
            end
        end
        return missing, total, first, firstBlessing and firstBlessing.castID, firstBlessing and firstBlessing.icon, not gone
    end
    if not def.group then
        local fine, running, left = HasBuff("player", entry.names, before)
        return fine and 0 or 1, 1, "player", nil, nil, running, nil, running and left or nil
    end
    local missing, total, first, gone = 0, 0, nil, false
    -- Thorns: tanks (their group role, or the raid's main tanks; alone, yourself), you, or everyone
    local pick = def.pick and ((GetDb() or {})[def.pick] or "tank")
    local grouped = IsInGroup()
    local list = GroupUnits(units, who)
    -- a party-wide buff (Battle Shout): you and your party, in a raid too
    if def.party and #list > 5 then
        wipe(list)
        list[1] = "player"
        for i = 1, 4 do list[#list + 1] = "party" .. i end
    end
    for _, unit in ipairs(list) do
        local wanted = true
        if pick == "self" then
            wanted = unit == "player" or UnitIsUnit(unit, "player")
        elseif pick == "tank" then
            wanted = (not grouped and (unit == "player" or UnitIsUnit(unit, "player"))) or IsTank(unit)
        end
        if wanted and Reachable(unit) then
            local _, class = UnitClass(unit)
            if not (def.casters and NO_MANA[class]) then
                total = total + 1
                local fine, running = HasBuff(unit, entry.names, before)
                if not fine then
                    missing = missing + 1
                    if not running then gone = true end
                    first = first or unit
                end
            end
        end
    end
    return missing, total, first, nil, nil, not gone
end

--------------------------------------------------
-- 4. ICONS
--------------------------------------------------
-- an icon's look (icon, count, pulse, glow), on the secure button or a settings preview's plain frame
function BR.BuildIcon(b)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.pieces = {}
    -- the count sits over the icon's border (a frame two levels up)
    local over = CreateFrame("Frame", nil, b)
    over:SetAllPoints()
    over:SetFrameLevel(b:GetFrameLevel() + 5)
    b.count = over:CreateFontString(nil, "OVERLAY")
    b.count:SetPoint("BOTTOM", b, "BOTTOM", 0, 2)
    -- time left on a buff running out (or a poison's charges), at the top
    b.time = over:CreateFontString(nil, "OVERLAY")
    b.time:SetPoint("TOP", b, "TOP", 0, -2)
    -- a slow pulse says "missing"
    local pulse = b.icon:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.45)
    fade:SetDuration(0.8)
    fade:SetSmoothing("IN_OUT")
    b.pulse = pulse
    -- Alerts: the glow (gold for missing, orange for running out), the button border's light, pulsing
    b.glow = b:CreateTexture(nil, "BACKGROUND", nil, -1)
    b.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    b.glow:SetBlendMode("ADD")
    b.glow:SetPoint("CENTER")
    b.glow:Hide()
    local glowPulse = b.glow:CreateAnimationGroup()
    glowPulse:SetLooping("BOUNCE")
    local glowFade = glowPulse:CreateAnimation("Alpha")
    glowFade:SetFromAlpha(1)
    glowFade:SetToAlpha(0.35)
    glowFade:SetDuration(0.6)
    glowFade:SetSmoothing("IN_OUT")
    b.glowPulse = glowPulse
    return b
end

local function Icon(i)
    local b = icons[i]
    if b then return b end
    b = CreateFrame("Button", "FlareUI_BuffReminder" .. i, row, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp", "AnyDown")
    BR.BuildIcon(b)
    -- right-click: no cast (an empty macro), the hide menu instead
    b:SetAttribute("type2", "macro")
    b:SetAttribute("macrotext2", "")
    b:HookScript("OnMouseUp", function(self, button) if button == "RightButton" then BR.Menu(self) end end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        if self.tipItem then GameTooltip:SetItemByID(self.tipItem)
        elseif self.spellID or self.tipSpell then GameTooltip:SetSpellByID(self.spellID or self.tipSpell) end
        -- a weapon buff: which hand, and nothing to put on
        if self.hand then GameTooltip:AddLine(self.hand, 1, 0.82, 0) end
        if self.none then GameTooltip:AddLine(L["None in your bags."], 1, 0.3, 0.3) end
        GameTooltip:AddLine(L["Right-click to hide this reminder."], 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    icons[i] = b
    return b
end

function BR.Menu(owner)
    local entry = owner.entry
    if not (entry and entry.def and MenuUtil and MenuUtil.CreateContextMenu) or InCombatLockdown() then return end
    local key = BR.HideKey(entry)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(owner.spellID and SpellName(owner.spellID) or L["Buff Reminders"])
        root:CreateButton(L["Hide Until Reload"], function()
            dismissed[key] = true
            BR.Update()
        end)
        -- (a buff only: something to see come back)
        if next(entry.names or {}) or entry.def.weapon or entry.def.blessing then
            root:CreateButton(L["Snooze Until Recast"], function()
                snoozed[key] = true
                BR.Update()
            end)
        end
        root:CreateButton(L["Never Remind Me"], function() BR.RemoveFromBar(entry.barId) end)
        -- the reminder's own choices (the settings page's inspector shows the same: BR.Choices)
        for _, g in ipairs(BR.Choices(entry.def, entry.slot)) do
            root:CreateDivider()
            root:CreateTitle(g.title)
            for _, o in ipairs(g.options) do
                root:CreateRadio(o.text, function() return BR.GetChoice(g) == o.value end,
                    function() BR.SetChoice(g, o.value) end)
            end
        end
    end)
end

-- a reminder's own choices, as groups of radios: { title, field, default, options = { { value, text } } }
-- (the blessing, each hand's weapon buff, who keeps the Soulstone or Thorns); slot: one hand only
function BR.Choices(def, slot)
    local out = {}
    if not def then return out end
    local function Group(title, field, default, options)
        local g = { title = title, field = field, default = default, options = {} }
        for _, o in ipairs(options) do g.options[#g.options + 1] = { value = o[1], text = o[2] } end
        out[#out + 1] = g
        return g
    end
    if def.blessing then
        Group(L["Blessing"], "blessing", "auto", BR.BlessingChoices())
    elseif def.weapon then
        -- per hand: Last Used, Any, or one you can put on
        local kind = def.weapon
        local db = GetDb() or {}
        for _, s in ipairs(slot and { slot } or { 16, 17 }) do
            local field = kind .. (s == 17 and "Off" or "Main")
            local options = { { "auto", L["Last Used"] }, { "any", L["Any Weapon Buff"] } }
            for _, o in ipairs(WEAPON_CHOICES[kind]) do
                if OptionKnown(kind, o) or db[field] == o.key then
                    options[#options + 1] = { o.key, BR.WeaponOptionLabel(kind, o) }
                end
            end
            Group(s == 17 and (INVTYPE_WEAPONOFFHAND or "Off Hand") or (INVTYPE_WEAPONMAINHAND or "Main Hand"),
                field, "auto", options)
        end
    elseif def.soulstone then
        Group(L["Keep It On"], "soulstone", "healer", { { "healer", L["Healers"] }, { "self", L["Only Me"] } })
    elseif def.pick == "thorns" then
        Group(L["Keep It On"], "thorns", "tank", { { "tank", L["Tanks Only"] }, { "self", L["Only Me"] }, { "all", L["Everyone"] } })
    end
    return out
end
function BR.GetChoice(g)
    local db = GetDb() or {}
    return db[g.field] or g.default
end
function BR.SetChoice(g, value)
    local db = GetDb()
    if not db then return end
    db[g.field] = value
    BR.Update()
    Changed()
end

local function StyleIcon(b, size)
    b:SetSize(size, size)
    local db = AurasDb()
    local AU = ns.Auras
    if AU and AU.StyleIcon then
        AU.StyleIcon(b, b.icon, b.pieces, (db and db.style or "round") == "round")
        AU.StackFont(b.count)
        AU.StackFont(b.time)
    else
        b.icon:SetAllPoints()
        b.count:SetFontObject(NumberFontNormal)
        b.time:SetFontObject(NumberFontNormal)
    end
end

-- shows: { { entry, missing, total, unit }, ... }
-- sample: a settings preview's plain frame, which holds its own icons (no clicks, no attributes)
local function Show(shows, sample)
    local db = GetDb() or {}
    local size = db.size or 36
    local spacing = db.spacing or 6
    local vertical = db.orientation == "VERTICAL"
    local back = db.grow == "BACK"   -- left in a row, up in a column
    local list, parentRow, frame = icons, row, holder
    if sample then list, parentRow, frame = sample.icons, sample, sample end
    -- From the Middle: the frame keeps room for every reminder that could show, and the icons sit in
    -- its middle, so a placed frame grows both ways from its centre
    local slots = #shows
    if db.grow == "CENTER" and not sample then slots = math_max(slots, BR.EnabledCount()) end
    local offset = (slots - #shows) * (size + spacing) / 2
    if sample or not BR.fading then frame:SetAlpha((db.alpha or 100) / 100) end
    for i, s in ipairs(shows) do
        local b
        if sample then
            b = list[i]
            if not b then
                b = BR.BuildIcon(CreateFrame("Frame", nil, sample))
                b:EnableMouse(false)
                list[i] = b
            end
        else
            b = Icon(i)
        end
        StyleIcon(b, size)
        local castID = s.castID or s.entry.castID
        b.icon:SetTexture(s.icon or s.entry.icon)
        b.spellID = castID
        b.tipSpell, b.tipItem = s.entry.tipSpell, s.action and s.action.tipItem
        b.none = s.action and s.action.none
        b.hand = s.entry.slot and (s.entry.slot == 17 and (INVTYPE_WEAPONOFFHAND or "Off Hand") or (INVTYPE_WEAPONMAINHAND or "Main Hand"))
        if sample then
            -- a picture only
        elseif s.action and s.action.macro then
            b:SetAttribute("type", "macro")
            b:SetAttribute("macrotext", s.action.macro)
        elseif s.action and s.action.item then
            b:SetAttribute("type", "item")
            b:SetAttribute("item", s.action.item)
            b:SetAttribute("unit", s.action.unit)
        elseif castID then
            b:SetAttribute("type", "spell")
            -- by name: the game casts your highest rank (imbues list only their first rank's ID)
            b:SetAttribute("spell", SpellName(castID) or castID)
            b:SetAttribute("unit", s.unit or "player")
        else
            b:SetAttribute("type", nil)
        end
        -- Count Text: missing / total, the missing alone, or none
        local countMode = db.countText or "both"
        local countText = ""
        if s.total > 1 and countMode == "both" then countText = s.missing .. "/" .. s.total
        elseif s.total > 1 and countMode == "missing" then countText = tostring(s.missing) end
        -- a click that uses an item from the bags: how many are left (11-12)
        local item = s.action and s.action.tipItem
        if countText == "" and item and not sample then
            local n = ItemCount(item)
            if n > 0 or (s.entry.def and s.entry.def.supply) then countText = tostring(n) end
        end
        if s.action and s.action.durability then countText = s.action.durability .. "%" end
        b.count:SetText(countText)
        b.expires = (s.left and not sample) and (GetTime() + s.left) or nil
        b.charges = s.charges
        BR.TimeText(b)
        b.entry = s.entry.def and s.entry or nil   -- for the right-click menu (not on Edit Mode's samples)
        -- Orientation and Growth: the first icon at the edge the row grows away from
        local step = offset + (i - 1) * (size + spacing)
        b:ClearAllPoints()
        if vertical then
            if back then b:SetPoint("BOTTOMLEFT", parentRow, "BOTTOMLEFT", 0, step) else b:SetPoint("TOPLEFT", parentRow, "TOPLEFT", 0, -step) end
        else
            if back then b:SetPoint("TOPRIGHT", parentRow, "TOPRIGHT", -step, 0) else b:SetPoint("TOPLEFT", parentRow, "TOPLEFT", step, 0) end
        end
        b:Show()
        if not b.pulse:IsPlaying() then b.pulse:Play() end
        -- Alerts: the glow
        local glow = (s.running and db.glowExpiring) and GLOW_EXPIRING or ((not s.running) and db.glowMissing) and GLOW_MISSING
        -- a ready check (Ready Check Alert): every reminder glows for a few seconds
        if not sample and BR.readyUntil and GetTime() < BR.readyUntil then glow = GLOW_MISSING end
        if glow then
            b.glow:SetSize(size * 1.9, size * 1.9)
            b.glow:SetVertexColor(glow[1], glow[2], glow[3])
            b.glow:Show()
            if not b.glowPulse:IsPlaying() then b.glowPulse:Play() end
        else
            b.glowPulse:Stop()
            b.glow:Hide()
        end
    end
    if not sample then BR.WatchTimes() end
    for i = #shows + 1, #list do
        list[i].expires, list[i].charges = nil, nil
        list[i].pulse:Stop()
        list[i].glowPulse:Stop()
        list[i]:Hide()
    end
    local n = math_max(slots, 1)
    local length = n * size + (n - 1) * spacing
    if vertical then frame:SetSize(size, length) else frame:SetSize(length, size) end
    return frame:GetWidth(), frame:GetHeight()
end

-- the time left (or a poison's charges) on a running-out icon, kept counting while any is shown
function BR.TimeText(b)
    -- Time Left (Edit Mode > Alerts, on)
    if (GetDb() or {}).timeLeft == false then b.time:SetText("") return end
    if b.charges then
        b.time:SetText(b.charges .. "x")
    elseif b.expires then
        b.time:SetText(ns.FormatAuraTime(math_max(0, b.expires - GetTime())) or "")
    else
        b.time:SetText("")
    end
end
local timeWatch
function BR.WatchTimes()
    local any = false
    for _, b in ipairs(icons) do if b:IsShown() and b.expires and not b.charges then any = true end end
    if not timeWatch then
        timeWatch = CreateFrame("Frame")
        timeWatch.elapsed = 0
    end
    timeWatch:SetScript("OnUpdate", any and function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed < 0.5 then return end
        self.elapsed = 0
        for _, b in ipairs(icons) do if b:IsShown() and b.expires then BR.TimeText(b) end end
    end or nil)
end

-- a settings preview's row: Edit Mode's samples (Fortitude missing on 2 of 5, Arcane Intellect running
-- out) and a pet reminder, in the current look; kind is unused
function BR.CreateSample(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.fuiSample = true
    f.icons = {}
    f:EnableMouse(false)
    f:SetFrameLevel(parent:GetFrameLevel() + 1)
    f:SetSize(36, 36)
    return f
end

function BR.DrawSample(f)
    local _, class = UnitClass("player")
    local pet = SpellIcon(class == "WARLOCK" and 688 or CALL_PET)
    local shows = {
        { entry = { icon = SpellIcon(1243) }, missing = 2, total = 5, unit = "player", running = false },
        { entry = { icon = SpellIcon(1459) }, missing = 1, total = 5, unit = "player", running = true },
        { entry = { icon = pet }, missing = 1, total = 1, unit = "player", running = false },
    }
    local w, h = Show(shows, f)
    f:Show()
    return w, h
end

--------------------------------------------------
-- 5. UPDATE (out of a fight only)
--------------------------------------------------
local shows, pool = {}, {}
local function Entry(i)
    local s = pool[i] or {}
    pool[i] = s
    return s
end

-- When It Shows: alone, in a party, in a raid, and not in a rested area
local function ShowsHere(db)
    if db.hideRested and IsResting() then return false end
    if IsInRaid() then return db.showRaid ~= false end
    if IsInGroup() then return db.showParty ~= false end
    return db.showSolo ~= false
end

-- Alerts: a sound as a reminder appears (once per new one, not more than every 10 seconds)
local SOUNDS = { raidwarning = "RAID_WARNING", alarm = "ALARM_CLOCK_WARNING_3", whisper = "TELL_MESSAGE" }
local shownKeys, lastSound = {}, 0
function BR.PlayAlert(sample)
    local db = GetDb() or {}
    local kit = SOUNDS[db.sound or "off"]
    local id = kit and SOUNDKIT and SOUNDKIT[kit]
    if not id then return end
    if not sample then
        if GetTime() - lastSound < 10 then return end
        lastSound = GetTime()
    end
    PlaySound(id, "Master")
end

-- the reminders on the bar, in its order (a weapon's main hand before its off-hand)
local ordered = {}
function Ordered()
    local index = BarIndex()
    wipe(ordered)
    for _, entry in ipairs(active) do
        if index[entry.barId] then ordered[#ordered + 1] = entry end
    end
    table.sort(ordered, function(a, b)
        local ia, ib = index[a.barId], index[b.barId]
        if ia ~= ib then return ia < ib end
        return a.pos < b.pos
    end)
    return ordered
end

function BR.Update()
    if not holder or InCombatLockdown() then return end
    wipe(shows)
    local db = GetDb() or {}
    if ns.EditPreviewing and ns.EditPreviewing() then
        -- Edit Mode: every reminder on the bar, so the row can be placed
        for _, entry in ipairs(Ordered()) do
            if Enabled(entry) then
                local s = Entry(#shows + 1)
                s.entry, s.missing, s.total, s.unit = entry, entry.def.group and 2 or 1, entry.def.group and 5 or 1, "player"
                s.castID, s.icon, s.running, s.action = nil, nil, false, nil
                s.left, s.charges = nil, nil
                shows[#shows + 1] = s
            end
        end
        -- at least two, so Orientation and Growth can be seen: Fortitude and Arcane Intellect as samples
        local samples = { 1243, 1459 }
        while #shows < 2 do
            local s = Entry(#shows + 1)
            s.entry, s.missing, s.total, s.unit = { icon = SpellIcon(samples[#shows + 1]) }, 2, 5, "player"
            s.castID, s.icon, s.running, s.action = nil, nil, false, nil
            s.left, s.charges = nil, nil
            shows[#shows + 1] = s
        end
    elseif ShowsHere(db) and not UnitIsDeadOrGhost("player") and not AurasLocked() and not UnitOnTaxi("player")
            and not (db.hideMounted and IsMounted()) then
        for _, entry in ipairs(Ordered()) do
            if Enabled(entry) then
                -- Remind Me (the reminder's own, else Remind Before It Ends or its dungeon / raid choice)
                local before = (Opt(entry, "before") or 0) * 60
                local missing, total, unit, castID, icon, running, action, left, charges = Check(entry, before)
                -- snoozed: quiet until the buff is back
                local snoozeKey = BR.HideKey(entry)
                if snoozed[snoozeKey] then
                    if missing == 0 then snoozed[snoozeKey] = nil end
                    missing = 0
                end
                if missing > 0 then
                    local s = Entry(#shows + 1)
                    s.entry, s.missing, s.total, s.unit = entry, missing, total, unit
                    s.castID, s.icon, s.running, s.action = castID, icon, running and true or false, action
                    s.left, s.charges = left, charges
                    shows[#shows + 1] = s
                end
            end
        end
    end
    -- a reminder that was not there before plays the sound (not in Edit Mode)
    if not (ns.EditPreviewing and ns.EditPreviewing()) then
        local fresh = false
        local now = {}
        for _, s in ipairs(shows) do
            local key = s.entry.def and (s.entry.key or s.entry.def.key)
            if key then
                now[key] = true
                if not shownKeys[key] then fresh = true end
            end
        end
        shownKeys = now
        if fresh then BR.PlayAlert() end
    end
    BR.ShowFaded(shows, db)
    Changed()
end

-- Fade Speed (Fading section): the row fades in as reminders appear where there were none, and out
-- as the last goes. The icons are secure buttons: the empty row is drawn after the fade, out of a fight
-- only (a fight starting meanwhile leaves it to PLAYER_REGEN_ENABLED's update).
local fadeTimer
function BR.ShowFaded(list, db)
    local t = ns.FadeTime and ns.FadeTime(db.fadeSpeed) or 0
    local target = (db.alpha or 100) / 100
    local had = BR.shownCount or 0
    BR.shownCount = #list
    if fadeTimer then fadeTimer:Cancel(); fadeTimer = nil end
    if t <= 0 or (ns.EditPreviewing and ns.EditPreviewing()) then
        BR.fading = nil
        Show(list)
        return
    end
    if #list > 0 then
        Show(list)
        if had == 0 then
            BR.fading = true
            UIFrameFadeIn(holder, t, 0, target)
            fadeTimer = C_Timer.NewTimer(t, function() fadeTimer = nil; BR.fading = nil end)
        end
    elseif had > 0 then
        BR.fading = true
        UIFrameFadeOut(holder, t, holder:GetAlpha(), 0)
        fadeTimer = C_Timer.NewTimer(t, function()
            fadeTimer = nil
            BR.fading = nil
            if InCombatLockdown() then return end
            Show(list)
        end)
    else
        Show(list)
    end
end

-- UNIT_AURA comes often: one check a moment later
local pending = false
local function Soon()
    if pending then return end
    pending = true
    C_Timer.After(0.3, function()
        pending = false
        BR.Update()
    end)
end

--------------------------------------------------
-- 6. POSITION (per Edit Mode layout)
--------------------------------------------------
local function GetLayoutStore(layoutName)
    local db = GetDb()
    if not db then return nil end
    layoutName = layoutName or LEM:GetActiveLayoutName() or "Modern"
    db.layouts = db.layouts or {}
    -- (a layout with no spot of its own reads the profile's home layout's: ProfileLayout.lua)
    return ns.LayoutHome(db.layouts, layoutName)
end

local function ApplyPosition(layoutName)
    if not holder or InCombatLockdown() then return end
    local store = GetLayoutStore(layoutName)
    local pos = (store and store.point) and store or DEFAULTS
    holder:ClearAllPoints()
    holder:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
end

local function OnMoved(_, layoutName, point, x, y)
    local store = GetLayoutStore(layoutName)
    if not store then return end
    store.point, store.x, store.y = point, math_floor(x + 0.5), math_floor(y + 0.5)
end

--------------------------------------------------
-- 6b. THE SETTINGS PAGE'S PICTURE (Settings/BuffRemindersEditor.lua, 6.2)
-- Each reminder's name, icon and what counts; its state now (for the bar's picture); and the
-- spellbook to pick from: the class's own, a tab per spellbook line, the bags, upkeep.
--------------------------------------------------
local function FindDef(list, id)
    for _, def in ipairs(list or {}) do if def.key == id then return def end end
end
-- the reminder with this id, and its resolved entry when the character has it
function BR.DefById(id)
    if not id then return nil end
    for _, entry in ipairs(active) do
        if entry.barId == id then return entry.def, entry end
    end
    local elixir = id:match("^elixir:(.+)$")
    if elixir then return FindDef(ELIXIRS, elixir) end
    local def = FindDef(REMINDERS[PlayerClass()], id) or FindDef(EXTRAS, id) or FindDef(CONSUMABLES, id)
    if def then return def end
    local item = tonumber(id:match("^supply(%d+)$") or "")
    if item then
        for _, s in ipairs(SUPPLIES[PlayerClass()] or {}) do
            if s.item == item then return { key = id, supply = s } end
        end
    end
    if id == "ammo" then return { key = id, ammo = true } end
    if id == "durability" then return { key = id, durability = true } end
    if id == "trinket" then return { key = id, trinket = true } end
end

local function CustomName(def)
    local c = def.stored or {}
    local s = c.spells and c.spells[1]
    if type(s) == "number" then return SpellName(s) end
    if type(s) == "string" then return s end
    local item = c.items and c.items[1]
    return item and ItemName(item)
end

local function DefName(def, entry)
    if def.weapon == "imbue" then return L["Weapon Imbue"] end
    if def.weapon == "poison" then return SpellName(POISONS) or L["Poisons"] end
    if def.weapon == "stone" then return L["Firestone / Spellstone"] end
    if def.weapon == "oil" then return L["Weapon Oil / Stone"] end
    if def.blessing then return L["Blessing"] end
    if def.pet then return L["Pet"] end
    if def.healthstone then return L["Healthstone"] end
    if def.soulstone then return SpellName(693) or L["Soulstone"] end
    if def.stance then return L["Stance"] end
    if def.aspect then return L["Aspect"] end
    if def.camp then return SpellName(CAMP_BUFF) or L["Camp Benefits"] end
    if def.bag then return ItemName(SLEEPING_BAG) or L["Sleeping Bag"] end
    if def.gathering then return L["Gathering Tracking"] end
    if def.key == "food" then return SpellName(19705) or L["Well Fed"] end
    if def.key == "flask" then return L["Flask"] end
    if def.elixir then return ItemName(def.items[1]) or def.key end
    if def.supply then return ItemName(def.supply.item) or L["Low Supplies"] end
    if def.ammo then return L["Ammo"] end
    if def.durability then return L["Low Durability"] end
    if def.trinket then return L["Worn Trinkets"] end
    if def.custom then return CustomName(def) or L["Your Own"] end
    -- (your best rank's name: a mage's armour is whichever you know best)
    local id = entry and entry.castID or (def.cast and def.cast[#def.cast])
    return id and SpellName(id) or def.key
end

local function DefIcon(def, entry)
    if entry and entry.icon then return entry.icon end
    if def.weapon == "imbue" then return SpellIcon(8017) end
    if def.weapon == "poison" then return SpellIcon(POISONS) end
    if def.weapon == "stone" then return ItemIcon(1254) end
    if def.weapon == "oil" then return ItemIcon(20749) end
    if def.blessing then return SpellIcon(19740) end
    if def.pet then return SpellIcon(PlayerClass() == "WARLOCK" and 688 or CALL_PET) end
    if def.healthstone then return ItemIcon(5512) end
    if def.elixir then return ItemIcon(def.items[1]) end
    if def.supply then return ItemIcon(def.supply.item) end
    if def.ammo then return "Interface\\Icons\\INV_Ammo_Arrow_02" end
    if def.durability then return DURABILITY_ICON end
    if def.trinket then return ItemIcon(12846) end
    if def.bag then return ItemIcon(SLEEPING_BAG) end
    if def.camp then return SpellIcon(CAMP_BUFF) end
    if def.icon then return SpellIcon(def.icon) end
    if def.cast then return SpellIcon(def.cast[1]) end
    return 134400
end

-- what counts as kept up, in a few words
local function DefCounts(def)
    if def.weapon then return L["A weapon buff on each hand"] end
    if def.blessing then return L["A blessing on each group member"] end
    if def.pet then return L["Your pet: out, alive and well"] end
    if def.healthstone then return L["A Healthstone in your bags"] end
    if def.soulstone then return L["A Soulstone on someone in your group"] end
    if def.stance then return L["Any stance"] end
    if def.aspect then return L["Any aspect"] end
    if def.camp then return L["Camp Benefits from a campfire"] end
    if def.bag then return L["Three Well-Rested stacks while levelling"] end
    if def.gathering then return L["Herb or mineral tracking on"] end
    if def.key == "food" then return L["Any Well Fed buff"] end
    if def.key == "flask" then return L["Any of the four flasks"] end
    if def.elixir then return L["Its buff on you"] end
    if def.supply then return L["At least %d in your bags"]:format(def.supply.min) end
    if def.ammo then return L["At least %d in your bags"]:format(AMMO_MIN) end
    if def.durability then return L["Every item above 20% durability"] end
    if def.trinket then return L["No open-world trinket worn in a dungeon or raid"] end
    if def.custom then return L["A buff with its name on you"] end
    if def.party then return L["On you and your party"] end
    if def.casters then return L["On the mana users in your group"] end
    if def.group then return L["On you and your group"] end
    return L["On you"]
end

-- { def, entry, name, icon, counts, known }
function BR.Display(id)
    local def, entry = BR.DefById(id)
    if not def then return { name = tostring(id), icon = 134400, counts = "", known = false } end
    return { def = def, entry = entry, name = DefName(def, entry), icon = DefIcon(def, entry),
             counts = DefCounts(def), known = entry ~= nil }
end

-- the reminder's state now, for the bar's picture: status "missing", "expiring", "up" or "unknown" (not
-- learned), and a caption (2/5, 1:42, 64%); where it shows is not asked (the picture shows them all)
local STATUS_RANK = { unknown = 0, up = 1, expiring = 2, missing = 3 }
function BR.PreviewState(id)
    local best
    for _, entry in ipairs(active) do
        if entry.barId == id and not (entry.slot == 17 and not OffHandWeapon()) then
            local ok, missing, total, _, _, _, running, action, left = pcall(Check, entry, (Opt(entry, "before") or 0) * 60)
            if ok and missing then
                local state
                if missing > 0 and running then
                    state = { status = "expiring", caption = left and ns.FormatAuraTime(math_max(0, left)) or L["Running Out"] }
                elseif missing > 0 then
                    local caption = (action and action.durability and (action.durability .. "%"))
                        or ((total or 0) > 1 and (missing .. "/" .. total)) or L["Missing"]
                    state = { status = "missing", caption = caption }
                else
                    state = { status = "up", caption = (total or 0) == 0 and "-" or L["Up"] }
                end
                if not best or STATUS_RANK[state.status] > STATUS_RANK[best.status] then best = state end
            end
        end
    end
    return best or { status = "unknown", caption = L["Not Learned"] }
end

local function Harmful(spellID)
    if C_Spell.IsSpellHarmful then return C_Spell.IsSpellHarmful(spellID) and true or false end
    if IsHarmfulSpell then
        local ok, harmful = pcall(IsHarmfulSpell, SpellName(spellID))
        return ok and harmful and true or false
    end
    return false
end

-- the spellbook to pick from: { { key, label, icon, classIcon, items = { entry } } }; an entry is a
-- built-in reminder ({ id }) or a spell or item to make your own of ({ spell | item, id when you have
-- it }), with name, icon, sub and state: "add", "none" (not a buff) or "locked" (not learned)
function BR.Catalog()
    local class = PlayerClass()
    local tabs = {}
    local function Built(id)
        local d = BR.Display(id)
        return { id = id, name = d.name, icon = d.icon, sub = d.counts, state = d.known and "add" or "locked" }
    end
    local function Tab(key, label, icon)
        local t = { key = key, label = label, icon = icon, items = {} }
        tabs[#tabs + 1] = t
        return t
    end

    -- the class's own, all of them (the ones not learned yet greyed)
    local classTab = Tab("class", LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] or class)
    classTab.classIcon = class
    for _, def in ipairs(REMINDERS[class] or {}) do classTab.items[#classTab.items + 1] = Built(def.key) end

    -- the spellbook, a tab per line: a built-in reminder's spell stands for it; any other spell that
    -- isn't harmful can be your own (a buff with its name is watched for)
    local builtIn = {}
    for _, def in ipairs(REMINDERS[class] or {}) do
        for _, list in ipairs({ def.cast or {}, def.buffs or {} }) do
            for _, sid in ipairs(list) do
                local n = SpellName(sid)
                if n then builtIn[n] = def.key end
            end
        end
    end
    for _, sid in ipairs(FindDef(EXTRAS, "gathering").cast) do
        local n = SpellName(sid)
        if n then builtIn[n] = "gathering" end
    end
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
        local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
        for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
            local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
            if info and not info.shouldHide and not info.offSpecID then
                local tab = Tab("line" .. line, info.name, info.iconID)
                local at = {}   -- name or id -> its place (ranks: the last one, your best, stays)
                for offset = 1, info.numSpellBookItems or 0 do
                    local item = C_SpellBook.GetSpellBookItemInfo(info.itemIndexOffset + offset, bank)
                    local sid = item and item.spellID
                    if sid and not item.isPassive and item.itemType ~= Enum.SpellBookItemType.FutureSpell then
                        local name = SpellName(sid)
                        if name then
                            local e
                            if builtIn[name] then
                                e = Built(builtIn[name])
                            else
                                local harmful = Harmful(sid)
                                e = { spell = sid, id = BR.FindOwn(sid), name = name, icon = SpellIcon(sid),
                                      sub = harmful and L["Not a buff"] or L["A buff with its name on you"],
                                      state = harmful and "none" or "add" }
                            end
                            local key = e.id or name
                            if at[key] then tab.items[at[key]] = e else
                                tab.items[#tab.items + 1] = e
                                at[key] = #tab.items
                            end
                        end
                    end
                end
                if #tab.items == 0 then tabs[#tabs] = nil end
            end
        end
    end

    -- the bags: oils, food and flasks, the elixirs (the ones you carry first), then any other
    -- consumable that gives a buff
    local bags = Tab("bags", L["Bags"], 133633)
    local listed = {}
    for _, id in ipairs({ "oil", "food", "flask" }) do bags.items[#bags.items + 1] = Built(id) end
    for pass = 1, 2 do
        for _, def in ipairs(ELIXIRS) do
            local n = ItemCount(def.items[1])
            if (pass == 1) == (n > 0) then
                local e = Built("elixir:" .. def.key)
                if n > 0 then e.sub = L["%d in your bags"]:format(n) end
                bags.items[#bags.items + 1] = e
            end
            listed[def.items[1]] = true
        end
    end
    if C_Container and C_Container.GetContainerNumSlots then
        local consumable = Enum.ItemClass and Enum.ItemClass.Consumable or 0
        for bag = 0, 4 do
            for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                local itemID = info and info.itemID
                if itemID and not listed[itemID] then
                    listed[itemID] = true
                    local spellName = C_Item.GetItemSpell and C_Item.GetItemSpell(itemID)
                    local classID = C_Item.GetItemInfoInstant and select(6, C_Item.GetItemInfoInstant(itemID))
                    if spellName and classID == consumable then
                        bags.items[#bags.items + 1] = { item = itemID, id = BR.FindOwn(nil, itemID),
                            name = ItemName(itemID) or spellName, icon = ItemIcon(itemID),
                            sub = L["%d in your bags"]:format(ItemCount(itemID)), state = "add" }
                    end
                end
            end
        end
    end

    -- upkeep: what isn't a buff
    local upkeep = Tab("upkeep", L["Upkeep"], DURABILITY_ICON)
    for _, s in ipairs(SUPPLIES[class] or {}) do upkeep.items[#upkeep.items + 1] = Built("supply" .. s.item) end
    local rest = { "durability", "trinket", "camp", "sleepingBag", "gathering" }
    if class == "HUNTER" then table.insert(rest, 1, "ammo") end
    for _, id in ipairs(rest) do upkeep.items[#upkeep.items + 1] = Built(id) end
    return tabs
end

function BR.BlessingChoices()
    local list = { { "auto", L["Automatic"] } }
    for _, key in ipairs(BLESSING_ORDER) do
        local ranks = BLESSINGS[key].cast
        list[#list + 1] = { key, SpellName(ranks[#ranks]) or key }
    end
    return list
end

local function BuildSettings()
    local function get(key, default) return function() local db = GetDb(); return db and db[key] or default end end
    local function set(key)
        return function(_, value)
            local db = GetDb()
            if not db then return end
            db[key] = value
            BR.Update()
        end
    end
    local function Vertical() local db = GetDb(); return db and db.orientation == "VERTICAL" end
    -- the layout and where it shows: what it watches is in Settings > Buffs & Debuffs > Buff Reminders
    local Section, settings = ns.EditSections()
    Section("Frame", {
        { name = L["Orientation"], kind = LEM.SettingType.Dropdown, default = "HORIZONTAL",
          values = { { text = L["Horizontal"], value = "HORIZONTAL", isRadio = true }, { text = L["Vertical"], value = "VERTICAL", isRadio = true } },
          get = get("orientation", "HORIZONTAL"),
          set = function(layoutName, value) set("orientation")(layoutName, value); LEM:RefreshFrameSettings(holder) end },
        -- in a column, Right / Left read as Down / Up
        { name = L["Growth"], kind = LEM.SettingType.Dropdown, default = "FORWARD",
          values = function()
              if Vertical() then
                  return { { text = L["Down"], value = "FORWARD", isRadio = true }, { text = L["Up"], value = "BACK", isRadio = true },
                           { text = L["From the Middle"], value = "CENTER", isRadio = true } }
              end
              return { { text = L["Right"], value = "FORWARD", isRadio = true }, { text = L["Left"], value = "BACK", isRadio = true },
                       { text = L["From the Middle"], value = "CENTER", isRadio = true } }
          end,
          desc = L["Which way the icons go from the first one."],
          get = get("grow", "FORWARD"), set = set("grow") },
        { name = L["Count Text"], kind = LEM.SettingType.Dropdown, default = "both",
          values = { { text = L["Missing / Total"], value = "both", isRadio = true },
                     { text = L["Missing Only"], value = "missing", isRadio = true },
                     { text = L["Off"], value = "none", isRadio = true } },
          desc = L["The number on a group buff's icon: how many are missing, of how many."],
          get = get("countText", "both"), set = set("countText") },
        { name = L["Icon Size"], kind = LEM.SettingType.Slider, default = 36, minValue = 20, maxValue = 64, valueStep = 1,
          get = get("size", 36), set = set("size") },
        { name = L["Spacing"], kind = LEM.SettingType.Slider, default = 6, minValue = 0, maxValue = 20, valueStep = 1,
          get = get("spacing", 6), set = set("spacing") },
    })
    -- FADING (11-11, from the settings page's When It Shows and Hiding, as the other frames' Fading):
    -- Visibility ticks where it shows (Solo / In a Party / In a Raid, any of them), and In Combat off
    -- hides it in a fight (as the fight starts: its icons are secure buttons). Only Provider and the
    -- role switches stay on the settings page: they pick group buffs, not where the frame shows.
    local SHOW = { { "solo", "showSolo" }, { "party", "showParty" }, { "raid", "showRaid" }, { "combat", "showCombat" } }
    local function On(field) local db = GetDb(); return not (db and db[field] == false) end
    -- Alerts you see on the icons (11-12, from the settings page): the glows and the time left
    local function Bool(key, default)
        return function() local db = GetDb(); if not db or db[key] == nil then return default end; return db[key] == true end
    end
    local function SetBool(key)
        return function(_, value) local db = GetDb(); if db then db[key] = value and true or false end; BR.Update() end
    end
    Section("Alerts", {
        { name = L["Glow When Missing"], kind = LEM.SettingType.Checkbox, default = false,
          desc = L["A gold glow round a missing buff."], get = Bool("glowMissing", false), set = SetBool("glowMissing") },
        { name = L["Glow When Running Out"], kind = LEM.SettingType.Checkbox, default = false,
          desc = L["An orange glow round a buff about to run out."], get = Bool("glowExpiring", false), set = SetBool("glowExpiring") },
        { name = L["Time Left"], kind = LEM.SettingType.Checkbox, default = true,
          desc = L["The time left on a buff about to run out, at the top of its icon."],
          get = Bool("timeLeft", true), set = SetBool("timeLeft") },
    })
    Section("Fading", {
        { name = L["Visibility"], kind = LEM.SettingType.Dropdown, multiple = true,
          values = { { text = L["Solo"], value = "solo" }, { text = L["In a Party"], value = "party" },
                     { text = L["In a Raid"], value = "raid" }, { text = L["In Combat"], value = "combat" } },
          desc = L["Where the reminders show: alone, in a party, in a raid. In Combat off hides them in fights."],
          get = function()
              local list = {}
              for _, s in ipairs(SHOW) do if On(s[2]) then list[#list + 1] = s[1] end end
              return list
          end,
          set = function(_, value)
              local db = GetDb()
              if not db then return end
              for _, s in ipairs(SHOW) do
                  if s[1] == value then db[s[2]] = not On(s[2]) end
              end
              BR.Update()
          end },
        { name = L["Hide in Rested Areas"], kind = LEM.SettingType.Checkbox, default = false,
          desc = L["Nothing shows in towns and inns."],
          get = function() local db = GetDb(); return db and db.hideRested or false end, set = set("hideRested") },
        -- (from the settings page, 11-12: when the frame shows belongs here)
        { name = L["Hide While Mounted"], kind = LEM.SettingType.Checkbox, default = false,
          desc = L["No reminders while you ride."],
          get = function() local db = GetDb(); return db and db.hideMounted or false end, set = set("hideMounted") },
        { name = L["Fade Speed"], kind = LEM.SettingType.Dropdown, default = "instant",
          values = { { text = L["Instant"], value = "instant", isRadio = true }, { text = L["Fast"], value = "fast", isRadio = true },
                     { text = L["Slow"], value = "slow", isRadio = true } },
          desc = L["How fast it appears and disappears.\n* Fast: 0.2 seconds\n* Slow: 0.4 seconds"],
          get = get("fadeSpeed", "instant"), set = set("fadeSpeed") },
        { name = L["Opacity"], kind = LEM.SettingType.Slider, default = 100, minValue = 20, maxValue = 100, valueStep = 5,
          -- plain numbers, as Faded Opacity: "100%" ran past the dialog's edge (11-10)
          get = get("alpha", 100), set = set("alpha") },
    })
    return settings
end

--------------------------------------------------
-- 7. SETUP
--------------------------------------------------
function BR:GetFrame() return holder end

-- its own page and switch since 11-12, no longer under Buffs & Debuffs' switch: anyone who had the
-- reminders on with Buffs & Debuffs off (so never saw them) keeps them off, once
function BR:ShouldLoad()
    local db = AurasDb()
    if not db then return false end
    if db.remindersOwnSwitch == nil then
        db.remindersOwnSwitch = true
        if db.reminders and not db.enabled then db.reminders = false end
    end
    return db.reminders and not ns.IsGamepadUI() or false
end

function BR:Init()
    if holder then return end
    local db = AurasDb()
    if not db then return end
    db.reminder = db.reminder or {}
    -- Pet Reminders off and Thorns Off (their settings rows, gone 11-10) become hidden reminders
    local r = db.reminder
    if r.pets == false or r.thorns == "off" then
        r.hidden = r.hidden or {}
        if r.pets == false then r.hidden["HUNTER:pet"], r.hidden["WARLOCK:pet"] = true, true end
        if r.thorns == "off" then r.hidden["DRUID:thorns"] = true; r.thorns = nil end
        r.pets = nil
    end
    -- 6.2: Food and Flask's on / off is the bar's now; where it showed is the consumables' default
    if r.consumablesWhere == nil and r.consumables and r.consumables ~= "off" then r.consumablesWhere = r.consumables end
    Resolve()

    holder = CreateFrame("Frame", "FlareUI_BuffReminders", UIParent)
    holder:SetClampedToScreen(true)
    holder:SetSize(36, 36)
    row = CreateFrame("Frame", nil, holder)
    row:SetAllPoints()
    -- gone in a fight (the icons are secure and can't be changed then)
    RegisterStateDriver(holder, "visibility", "[combat] hide; show")
    ApplyPosition()
    LEM:AddFrame(holder, OnMoved, DEFAULTS, L["Buff Reminders"])
    LEM:AddFrameSettings(holder, BuildSettings())
    LEM:RegisterCallback("layout", function(layoutName) ApplyPosition(layoutName) end)
    LEM:RegisterCallback("enter", BR.Update)
    LEM:RegisterCallback("exit", BR.Update)

    local events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE", "SPELLS_CHANGED",
                             "PLAYER_LEVEL_UP", "UNIT_INVENTORY_CHANGED", "PLAYER_UNGHOST", "PLAYER_ALIVE", "PLAYER_DEAD",
                             "UNIT_CONNECTION", "UNIT_PHASE", "PLAYER_CONTROL_GAINED" }) do
        pcall(events.RegisterEvent, events, event)
    end
    pcall(events.RegisterEvent, events, "WEAPON_ENCHANT_CHANGED")
    pcall(events.RegisterEvent, events, "READY_CHECK")
    for _, event in ipairs({ "ZONE_CHANGED_NEW_AREA", "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_UPDATE_RESTING",
                             "UPDATE_SHAPESHIFT_FORM", "PET_BAR_UPDATE", "BAG_UPDATE_DELAYED", "MINIMAP_UPDATE_TRACKING",
                             "PLAYER_EQUIPMENT_CHANGED" }) do
        pcall(events.RegisterEvent, events, event)
    end
    pcall(events.RegisterUnitEvent, events, "UNIT_PET", "player")
    pcall(events.RegisterUnitEvent, events, "UNIT_HEALTH", "pet")
    pcall(events.RegisterUnitEvent, events, "UNIT_SPELLCAST_SUCCEEDED", "player")
    events:RegisterEvent("UNIT_AURA")
    -- Visibility without In Combat: hidden as a fight starts (the last moment its secure icons can be)
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:SetScript("OnEvent", function(_, event, unit, _, spellID)
        if event == "PLAYER_REGEN_DISABLED" then
            local db = GetDb()
            if db and db.showCombat == false and not (ns.EditPreviewing and ns.EditPreviewing()) then holder:Hide() end
            return
        end
        if event == "PLAYER_REGEN_ENABLED" and not holder:IsShown() then holder:Show() end
        -- Ready Check Alert: the row glows for 8 seconds and the sound plays once
        if event == "READY_CHECK" then
            local db = GetDb()
            if not (db and db.readyCheck) then return end
            BR.readyUntil = GetTime() + 8
            BR.Update()
            if row and next(shownKeys) then BR.PlayAlert(true) end
            C_Timer.After(8.1, function() BR.readyUntil = nil; BR.Update() end)
            return
        end
        if event == "SPELLS_CHANGED" or event == "PLAYER_LEVEL_UP" then Resolve() end
        -- a warlock's summon is remembered for the next time the pet is gone
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            if Readable(spellID) and tContains(WARLOCK_SUMMONS, spellID) then
                local me = ns.CharDB and ns.CharDB()
                if me then me.lastSummon = spellID end
            end
            return
        end
        if event == "UNIT_AURA" and unit and not (unit == "player" or unit == "pet" or unit:find("^party") or unit:find("^raid")) then return end
        if event == "PLAYER_REGEN_ENABLED" then ApplyPosition() end
        Soon()
    end)
    -- buffs running out cross the reminder line without an event
    C_Timer.NewTicker(10, Soon)
    BR.Update()
end

-- Buffs & Debuffs' look changed (Aura Icon Shape, the stack font)
function BR:Refresh()
    BR.Update()
end
