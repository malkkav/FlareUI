local _, ns = ...
local L = ns.L

--------------------------------------------------
-- CLASS BUFF REMINDERS (Buffs & Debuffs > Buff Reminders, off)
-- An icon for each of your class's buffs that is missing (or
-- running out) on you or your group, in FlareUI's buff look. Click an icon to cast it. Out of a fight
-- only: the row hides itself as a fight starts (a state driver), and it reads auras only while the
-- game lets addons read them. Known spells only, at your highest rank. Also: paladin blessings, picked per member (Blessing: Automatic gives warriors,
-- rogues and hunters Might and everyone else Wisdom, or one for all); a hunter's or warlock's pet
-- missing or dead (Pet Reminders, on); a mage's mana gem missing from the bags; food, flask and elixir buffs (Consumables: off, in dungeons
-- and raids, or always; Food and Flask each with a box; the elixirs ticked or those in your bags, each
-- or any one of them; a click drinks what you carry). When It Shows: Solo / Party / Raid, Hide in Rested
-- Areas, Only When You're the Only Provider (a group buff no one else of your class gives). Alerts: a
-- sound when a reminder appears, a gold glow on missing buffs, an orange one on buffs running out.
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
        -- Forever's camping First Aid Kit (item 279968): +34 Stamina, which can't stack
        -- with Fortitude, so it counts as having it; matched by the kit's name and its use spell's name
        { key = "fortitude", cast = FORTITUDE, buffs = Join(FORTITUDE, { 21564, 21562 }), group = true, alsoItems = { 279968 } },
        { key = "innerFire", cast = { 10952, 10951, 1006, 602, 7128, 588 } },
        -- talent spells: once the talent teaches the spell, it is known.
        -- Divine Spirit as a group buff on mana users; Shadowform not while your role is healer
        { key = "spirit", cast = { 27841, 14819, 14818, 14752 }, buffs = { 27841, 14819, 14818, 14752, 27681 },
          group = true, casters = true },
        { key = "shadowform", cast = { 15473 }, notRole = "HEALER" },
        -- Shadow Protection on the group: only when ticked in Extra Buffs
        { key = "shadowProt", cast = { 10958, 10957, 976 }, buffs = { 10958, 10957, 976, 27683 }, group = true, optIn = true },
    },
    MAGE = {
        { key = "intellect", cast = INTELLECT, buffs = Join(INTELLECT, { 23028 }), group = true, casters = true },
        -- one armor of any kind
        { key = "armor", cast = { 22783, 22782, 6117, 10220, 10219, 7320, 7302, 7301, 7300, 168 } },
        -- a mana gem in the bags, any of them (Ruby, Citrine, Jade, Agate); a click conjures the best one known
        { key = "manaGem", manaGem = true, cast = { 10054, 10053, 3552, 759 }, items = { 8008, 8007, 5513, 5514 } },
    },
    DRUID = {
        { key = "wild", cast = WILD, buffs = Join(WILD, { 21850, 21849 }), group = true },
        -- Thorns: kept on whoever the Thorns setting picks, tanks by default
        { key = "thorns", cast = { 9910, 9756, 8914, 1075, 782, 467 }, group = true, pick = "thorns" },
        -- no Omen of Clarity: on Forever it's a random proc, nothing to keep up
        -- Moonkin Form (talent): only when ticked in Extra Buffs (druids leave it to heal)
        { key = "moonkin", cast = { 24858 }, optIn = true },
    },
    WARLOCK = {
        -- (Fel Armor, Forever's, counts as the armor too)
        { key = "armor", cast = { 11735, 11734, 11733, 1086, 706, 696, 687 },
          buffs = { 403619, 11735, 11734, 11733, 1086, 706, 696, 687 } },
        -- Firestone / Spellstone on the weapon
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
        -- (own: another paladin's aura never stands in for yours)
        -- the right-click menu picks the aura a click casts: Last Used (the default) or one aura
        { key = "aura", own = true, paladinAura = true, cast = { 10293, 10292, 1032, 10291, 643, 10290, 465 },
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
        { key = "trueshot", cast = { 20906, 20905, 19506, 1299348, 1299346 } },   -- Trueshot Aura (talent; Forever's ranks too)
        -- no aspect up (any counts); a click casts the last fighting aspect seen, else Hawk
        { key = "aspect", aspect = true, cast = { 25296, 14322, 14321, 14320, 14319, 14318, 13165, 13163 },
          -- Forever's own aspects too: Viper (34074, 415423), 469145 and Beast's new ranks
          buffs = { 25296, 14322, 14321, 14320, 14319, 14318, 13165, 13163, 5118, 13159, 20190, 20043, 13161,
                    34074, 415423, 469145, 1299445, 1299446, 1299447 } },
    },
}
-- the warlock's pet joins its armor, then a healthstone in the bags (Create Healthstone, best rank)
table.insert(REMINDERS.WARLOCK, { key = "pet", pet = "WARLOCK" })
table.insert(REMINDERS.WARLOCK, { key = "healthstone", healthstone = true, cast = { 11730, 11729, 5699, 6202, 6201 } })
-- a Soulstone on a healer (or on yourself; the icon's right-click menu), in a group
table.insert(REMINDERS.WARLOCK, { key = "soulstone", soulstone = true, cast = { 20757, 20756, 20755, 20752, 693 } })
-- Soul Link (talent): only while a pet is out
table.insert(REMINDERS.WARLOCK, { key = "soulLink", cast = { 19028 }, needPet = true })
-- Demonic Sacrifice's buffs (Imp, Voidwalker, Succubus, Felhunter): one up, no pet is wanted, unless
-- Demonic Pact is known: with it the buff stays while another pet is
-- summoned, so the buff AND a pet (and Soul Link on it) are all wanted. needSpell: shown only once
-- that spell is known too.
local SACRIFICE_BUFFS = { 18789, 18790, 18791, 18792 }
local DEMONIC_PACT = 425464
table.insert(REMINDERS.WARLOCK, { key = "sacrifice", cast = { 18788 }, buffs = SACRIFICE_BUFFS,
    needSpell = DEMONIC_PACT, needPet = true })
local SOULSTONES = { 16896, 16895, 16893, 16892, 5232 }                -- Major to Minor
local SOULSTONE_BUFFS = { 20707, 20762, 20763, 20764, 20765 }          -- Soulstone Resurrection
-- trinkets for the open world, still worn in a dungeon or raid: the Argent Dawn ones, Carrot on a Stick
local WORLD_TRINKETS = { 12846, 13209, 19812, 11122 }
-- the aspects a click may put back (Cheetah and Pack are never remembered: they daze)
local FIGHT_ASPECTS = { { 25296, 14322, 14321, 14320, 14319, 14318, 13165 }, { 13163 }, { 20190, 20043 },
                        { 13161, 1299447, 1299446, 1299445 } }
-- the paladin auras a click may cast, each highest rank first: Devotion, Retribution,
-- Concentration, Shadow / Frost / Fire Resistance, Sanctity
local PALADIN_AURAS = {
    { key = "devotion", ranks = { 10293, 10292, 1032, 10291, 643, 10290, 465 } },
    { key = "retribution", ranks = { 10301, 10300, 10299, 10298, 7294 } },
    { key = "concentration", ranks = { 19746 } },
    { key = "shadow", ranks = { 19896, 19895, 19876 } },
    { key = "frost", ranks = { 19898, 19897, 19888 } },
    { key = "fire", ranks = { 19900, 19899, 19891 } },
    { key = "sanctity", ranks = { 20218 } },
}
local HEALTHSTONES = { 5512, 5511, 5509, 5510, 9421, 19004, 19005, 19006, 19007, 19008, 19009, 19010, 19011, 19012, 19013 }
-- Camping and Rest (Forever, off): Camp Benefits from a campfire, and while levelling with a Cozy
-- Sleeping Bag in the bags, three Well-Rested stacks (click to use the bag). Gathering Tracking (off):
-- Find Herbs or Find Minerals off while you know one.
local CAMP_BUFF, SLEEPING_BAG, WELL_RESTED = 1229741, 211527, 429959
local EXTRAS = {
    { key = "camp", camp = true, buffs = { CAMP_BUFF }, icon = CAMP_BUFF },
    { key = "sleepingBag", bag = true },
    { key = "gathering", gathering = true, cast = { 2383, 8387, 2580, 8388 } },
    -- Weapon Oil / Stone (off, every class): an oil or stone on each hand
    { key = "oil", weapon = "oil" },
}
-- food and flask, for every class
local CONSUMABLES = {
    -- Well Fed, and the foods whose buff has its own name (Grilled Squid, Nightfin Soup, Runn Tum Tuber
    -- Surprise, Dirge's Chimaerok Chops, Blessed Sunfruit and its juice)
    -- Well Fed by name; the six by ID, as their names are shared ("Mana Regeneration" is also
    -- Elixir of Mageblood's, which would hide this reminder)
    -- switch: its own box under Consumables
    { key = "food", consumable = true, switch = "food", buffs = { 19705 }, icon = 19705,
      ids = { 18192, 18194, 22730, 25661, 18125, 18141 } },
    -- the four flasks, and their items: a click drinks the one in your bags
    { key = "flask", consumable = true, switch = "flask", buffs = { 17626, 17627, 17628, 17629 }, icon = 17626,
      items = { 13510, 13511, 13512, 13513 } },
}

-- Elixirs and More: the raid consumables a player ticks in the settings. Items (best first) and
-- the buff each gives: buff, or buffs for an elixir with lower ranks: any rank counts, and a click
-- drinks the best one in your bags. Classic IDs, unverified on Forever but for the minor elixirs
-- (2378, 673 and 3166 measured there); the items' own spell names count too
local ELIXIRS = {
    { key = "mongoose", items = { 13452 }, buff = 17538 },
    { key = "giants", items = { 9206, 250349, 3391, 2454 }, buffs = { 11405, 1250984, 3164, 2367 } },
    { key = "greaterAgility", items = { 9187, 8949, 3390, 2457 }, buffs = { 11334, 11328, 3160, 2374 } },
    { key = "bruteForce", items = { 13453 }, buff = 17537 },
    { key = "greaterArcane", items = { 13454, 9155, 250342, 217398, 247754 },
      buffs = { 17539, 11390, 1250971, 439959, 1245244 } },
    { key = "shadowPower", items = { 9264 }, buff = 11474 },
    { key = "greaterFirepower", items = { 21546 }, buff = 1310077 }, { key = "frostPower", items = { 17708 }, buff = 21920 },
    { key = "fortitude", items = { 250335, 250334, 3825, 2458 }, buffs = { 1250931, 1250928, 3593, 2378 } },
    { key = "superiorDefense", items = { 13445, 8951, 3389, 5997 }, buffs = { 11348, 11349, 3220, 673 } },
    { key = "greaterIntellect", items = { 9179, 250354, 250353, 3383 }, buffs = { 11396, 1250989, 1250988, 3166 } },
    { key = "sages", items = { 13447 }, buff = 17535 },
    { key = "mageblood", items = { 250341, 20007, 250340, 250339 }, buffs = { 1250948, 24363, 1250944, 1250942 } },
    { key = "trollsBlood", items = { 20004, 3826, 3388, 3382 }, buffs = { 24361, 3223, 3222, 3219 } },
    { key = "zanzaSpirit", items = { 20079 }, buff = 24382 },
    { key = "zanzaSwiftness", items = { 20081 }, buff = 24383 }, { key = "jujuPower", items = { 12451 }, buff = 16323 },
    { key = "jujuMight", items = { 12460 }, buff = 16329 }, { key = "firewater", items = { 12820, 246948 }, buff = 17038 },
    { key = "roids", items = { 8410 }, buff = 10667 }, { key = "scorpok", items = { 8412 }, buff = 10669 },
    { key = "lungJuice", items = { 8411 }, buff = 10668 }, { key = "cerebral", items = { 8423 }, buff = 10692 },
    { key = "gizzard", items = { 8424 }, buff = 10693 }, { key = "rumsey", items = { 21151 }, buff = 25804 },
}

-- Low Supplies (off): a reagent below its minimum, once you know the spell that needs it
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
local CALL_PET, REVIVE_PET = 883, 982
local WARLOCK_SUMMONS = { 691, 697, 712, 688 }   -- Felhunter, Voidwalker, Succubus, Imp
-- the same by the pet's creature family (UnitCreatureFamily): the pet out is the last one summoned too,
-- one summoned before this module was on included (the idea after EllesmereUI)
BR.PET_FAMILIES = { [15] = 691, [16] = 697, [17] = 712, [23] = 688 }
function BR.NotePet()
    if not UnitCreatureFamily then return end
    local ok, _, family = pcall(UnitCreatureFamily, "pet")
    if not ok or (canaccessvalue and not canaccessvalue(family)) then return end
    local id = family and BR.PET_FAMILIES[family]
    local me = id and ns.CharDB and ns.CharDB()
    if me then me.lastSummon = id end
end
local GLOW_MISSING, GLOW_EXPIRING = { 1, 0.82, 0.25 }, { 1, 0.45, 0.1 }

-- classes that never use mana
local NO_MANA = { WARRIOR = true, ROGUE = true }

-- WEAPON BUFFS: a shaman's imbue, a rogue's poison, a warlock's
-- Firestone / Spellstone, each checked on the main hand and on an off-hand weapon (shields and held
-- items skipped). Only the class's own enchants count (a sharpening stone or a permanent enchant never
-- does). Forever's enchant IDs, by family (sources in LICENSES). Click: the imbue (the off-hand: cast, then
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
    -- every rank: knowing any one counts
    imbue = {
        { key = "windfury", cast = 8232, ranks = { 8232, 8235, 10486, 16362 } },
        { key = "flametongue", cast = 8024, ranks = { 8024, 8027, 8030, 16339, 16341, 16342 } },
        { key = "rockbiter", cast = 8017, ranks = { 8017, 8018, 8019, 10399, 16314, 16315, 16316 } },
        { key = "frostbrand", cast = 8033, ranks = { 8033, 8038, 10456, 16355, 16356 } },
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
-- Oils and stones: offered on every weapon reminder's menu while they are in the bags, and seen as
-- that hand's buff. Item, then Forever's enchant ID.
local WEAPON_OILS = {
    { 20749, 2628, nil, "wizard" }, { 20750, 2627, nil, "wizard" }, { 20746, 2626, nil, "wizard" }, { 20744, 2623, nil, "wizard" },
    { 20748, 2629, nil, "mana" }, { 20747, 2625, nil, "mana" }, { 20745, 2624, nil, "mana" },
    { 23123, 2685, nil, "wizard" }, { 3824, 25 }, { 3829, 26 },           -- Blessed Wizard, Shadow, Frost Oil
    { 287979, nil, nil, "wizard" },                                       -- (Forever's own wizard oil)
    { 287980, nil, nil, "stone" },                                        -- (Forever's own)
    { 18262, 2506, nil, "stone" }, { 23122, 2684, nil, "stone" },         -- Elemental, Consecrated stone
    { 12404, 1643, "blade", "stone" }, { 7964, 483, "blade", "stone" }, { 2871, 14, "blade", "stone" }, { 2863, 13, "blade", "stone" },
    { 287978, nil, "blade", "stone" },                                    -- (Forever's own sharpening stone)
    { 2862, 40, "blade", "stone" },
    { 12643, 1703, "blunt", "stone" }, { 7965, 484, "blunt", "stone" }, { 3241, 21, "blunt", "stone" }, { 3240, 20, "blunt", "stone" },
    { 3239, 19, "blunt", "stone" },
}
local OIL_OPTIONS, OIL_ENCHANTS = {}, {}
for _, o in ipairs(WEAPON_OILS) do
    local key = "oil" .. o[1]
    OIL_OPTIONS[#OIL_OPTIONS + 1] = { key = key, items = { o[1] }, name = o[1], oil = true, edge = o[3], group = o[4] }
    if o[2] then OIL_ENCHANTS[o[2]] = key end   -- (Forever's own items: no enchant ID known)
end
-- a kind's menu: its own options, then the oils and stones
local WEAPON_CHOICES = {}
for kind, list in pairs(WEAPON_OPTIONS) do WEAPON_CHOICES[kind] = Join(list, OIL_OPTIONS) end
-- the Weapon Oil / Stone reminder (any class, off): its own kind, the oils and stones alone
WEAPON_OPTIONS.oil, WEAPON_CHOICES.oil, WEAPON_ENCHANTS.oil = OIL_OPTIONS, OIL_OPTIONS, OIL_ENCHANTS
-- maces and staves take weightstones, the rest sharpening stones (Enum.ItemWeaponSubclass)
local BLUNT = { [4] = true, [5] = true, [10] = true }
-- Playstyle: which oils the Weapon Oil / Stone reminder reaches for first; Automatic goes by class
local PLAYSTYLE_OILS = { caster = { "wizard", "mana" }, healer = { "mana", "wizard" }, melee = { "stone" }, tank = { "stone" } }
local CLASS_PLAYSTYLE = { WARRIOR = "melee", ROGUE = "melee", HUNTER = "melee", PALADIN = "melee",
                          MAGE = "caster", WARLOCK = "caster", PRIEST = "caster", DRUID = "caster", SHAMAN = "caster" }
-- a poison with this few charges left counts as running out (kept low: a classic poison has 40-60
-- charges, and a higher line showed the reminder through most of every fight)
local LOW_CHARGES = 5
local POISONS = 2842             -- the rogue's Poisons skill: the reminder waits for it
local PERMANENT = Enum and Enum.ItemEnchantType and Enum.ItemEnchantType.Permanent or 1
-- Forever gives the class's own weapon buffs (poisons, imbues, Firestone / Spellstone) the Imbue type
-- and oils and stones the Temporary one: the type says whose a
-- buff is, so a poison counts whatever its enchant ID (new or reworked ones included). The IDs only
-- name the family (Last Used).
local IMBUE = Enum and Enum.ItemEnchantType and Enum.ItemEnchantType.Imbue or 3
local TEMPORARY = Enum and Enum.ItemEnchantType and Enum.ItemEnchantType.Temporary or 2
local WEAPON_SLOT = { [16] = 0, [17] = 1 }   -- Enum.WeaponSlot MainHand / OffHand

--------------------------------------------------
-- 2. STATE
--------------------------------------------------
local holder, row          -- holder: the Edit Mode frame (hidden in a fight); row: the icons' parent
local icons = {}           -- [i] = secure button
local active = {}          -- this class's reminders, spell names resolved
local DEFAULTS = { point = "CENTER", x = -423, y = -140 }

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
-- the best of an elixir family's items in your bags (ELIXIRS: items best first)
local function ElixirInBags(def)
    for _, item in ipairs(def.items) do
        if ItemCount(item) > 0 then return item end
    end
end
-- an elixir family the settings watch (Elixirs to Watch): ticked in Elixirs and More, or carried
local function ElixirWatched(def, db)
    if db.elixirSource == "bags" then return ElixirInBags(def) ~= nil end
    return ns.Conditions.Set(db.elixirs or "")[def.key] == true
end

-- a weapon option you can put on: an imbue you know, a stone you can make or have, any poison
local function BestCreate(o)
    for _, id in ipairs(o.create or {}) do if Known(id) then return id end end
end
local function OptionKnown(kind, o)
    if o.oil then return ItemCount(o.items[1]) > 0 end
    if kind == "imbue" then
        for _, id in ipairs(o.ranks or { o.cast }) do if Known(id) then return true end end
        return false
    end
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
        local usable = castID and not (def.needSpell and not Known(def.needSpell))
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
            if kind == "poison" and not Known(POISONS) then
                -- the Poisons skill, or a poison in the bags: Forever reworked poisons
                local inBags = false
                for _, o in ipairs(WEAPON_OPTIONS.poison) do
                    for _, item in ipairs(o.items or {}) do
                        if ItemCount(item) > 0 then inBags = true end
                    end
                end
                if not inBags then any = nil end
            end
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
                    -- cast: every rank, so each member gets the one their level can take
                    known[key] = { castID = id, cast = b.cast, greater = b.greater, names = names, icon = SpellIcon(id) }
                end
            end
            if next(known) then
                local first = known[BLESSING_ORDER[1]] or select(2, next(known))
                entry = { def = def, blessings = known, castID = first.castID, icon = first.icon, names = first.names }
            end
            usable = false
        elseif def.pet then
            -- a hunter with Forever's Lone Wolf talent (415370) fights without a pet on purpose
            local any = def.pet == "HUNTER" and (Known(CALL_PET) or Known(REVIVE_PET)) and not Known(415370)
            if def.pet == "WARLOCK" then
                for _, id in ipairs(WARLOCK_SUMMONS) do if Known(id) then any = true end end
            end
            if any then entry = { def = def, names = {}, icon = SpellIcon(def.pet == "HUNTER" and CALL_PET or BR.WarlockPick() or 688) } end
            usable = false
        end
        if entry then active[#active + 1] = entry end
        if usable then
            local names = {}
            for _, id in ipairs(def.buffs or def.cast or {}) do
                local name = SpellName(id)
                if name then names[name] = true end
            end
            -- items whose buff stands in for this one (their names once the game has loaded them)
            for _, item in ipairs(def.alsoItems or {}) do
                if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(item) end
                local itemName = C_Item.GetItemNameByID and C_Item.GetItemNameByID(item)
                if itemName then names[itemName] = true end
                local spellName = C_Item.GetItemSpell and C_Item.GetItemSpell(item)
                if spellName then names[spellName] = true end
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
        if (castID or not def.cast) and not (def.needSpell and not Known(def.needSpell)) then
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
        def.elixir = true
        def.buffs = def.buffs or { def.buff }
        local names = {}
        for _, id in ipairs(def.buffs) do
            local name = SpellName(id)
            if name then names[name] = true end
        end
        for _, item in ipairs(def.items) do
            if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(item) end
        end
        active[#active + 1] = { def = def, names = names, icon = ItemIcon(def.items[1]) }
    end
    -- Those in Your Bags with nothing to drink: one icon while no elixir is carried nor up
    active[#active + 1] = { def = { key = "elixirStock", elixirStock = true, label = L["No elixir in your bags."] },
        names = {}, icon = ItemIcon(3383) }
    for _, def in ipairs(CONSUMABLES) do
        local names = {}
        for _, id in ipairs(def.buffs) do
            local name = SpellName(id)
            if name then names[name] = true end
        end
        active[#active + 1] = { def = def, names = names, icon = SpellIcon(def.icon) }
    end
end

BR.Resolve = function() Resolve() end

-- the reminders the settings leave on
-- Right-click an icon: hide that reminder until reload, or for good (db.hidden, "CLASS:key", so a mage's
-- and a warlock's armour stay apart); the Buff Reminders tab shows them all again
local dismissed = {}
local snoozed = {}   -- Snooze Until Recast: hidden until the buff is seen again
function BR.HideKey(entry)
    local _, class = UnitClass("player")
    -- Any One of Them shows one icon on whichever elixir comes first: hiding or
    -- snoozing it means the whole elixir reminder, so it has a key of its own
    if entry.def and entry.def.elixir and (GetDb() or {}).elixirMode == "any" then
        return (class or "") .. ":elixirAny"
    end
    return (class or "") .. ":" .. (entry.key or entry.def and entry.def.key or "")
end
-- a reminder's name, kept with it when hidden so the Hidden Reminders list can show it
function BR.EntryLabel(entry, owner)
    local name = owner and owner.spellID and SpellName(owner.spellID)
        or (entry.castID and SpellName(entry.castID)) or next(entry.names or {})
        or (entry.def and entry.def.label)
    return name or (entry.key or (entry.def and entry.def.key)) or "?"
end
-- Hidden Reminders: every hidden one, ticked; unticking brings it back
local hiddenTokens = {}
function BR.HiddenTokens() return hiddenTokens end
function BR.HiddenChoices()
    local db = GetDb() or {}
    local list, seen = {}, {}
    wipe(hiddenTokens)
    local function Add(key, value)
        if seen[key] then return end
        seen[key] = true
        local label = type(value) == "string" and value or (key:match(":(.+)$") or key)
        hiddenTokens[#hiddenTokens + 1] = key
        list[#list + 1] = { key, label }
    end
    for key, value in pairs(db.hidden or {}) do Add(key, value) end
    for key, value in pairs(dismissed) do Add(key, value) end
    table.sort(list, function(a, b) return a[2]:lower() < b[2]:lower() end)
    return list
end
function BR.HiddenValue()
    local ticked = {}
    for _, key in ipairs(hiddenTokens) do ticked[#ticked + 1] = key end
    return #ticked > 0 and table.concat(ticked, ",") or "none"
end
function BR.SetHidden(value)
    local db = GetDb()
    local ticked = ns.Conditions.Set(value or "")
    for _, key in ipairs(hiddenTokens) do
        if not ticked[key] then
            if db and db.hidden then db.hidden[key] = nil end
            dismissed[key] = nil
        end
    end
    if db and db.hidden and not next(db.hidden) then db.hidden = nil end
    BR.Update()
end

-- where a kind of reminder shows: "always", "instance" (dungeons and raids), "raid", or "mouseover"
-- (everywhere, its icon unseen until you point at the row: BR.ApplyHover)
local function InScope(mode)
    if not mode or mode == "always" or mode == "mouseover" or ns.EditPreviewing() then return true end
    local inInstance, kind = IsInInstance()
    if mode == "raid" then return inInstance and kind == "raid" or false end
    return inInstance and (kind == "party" or kind == "raid") or false
end

-- On Mouseover (out of sight until wanted): the Where choice of this
-- reminder's kind
function BR.KindMode(entry, db)
    local def = entry and entry.def
    if not (def and db) then return nil end
    if def.weapon then return db.weaponScope end
    if def.pet then return db.petScope end
    if def.elixir or def.elixirStock or def.consumable then return db.consumables end
    if entry.classBuff then return db.classScope end
    return nil
end

-- The On Mouseover icons: unseen (alpha 0, still there to point at and click) until the pointer is
-- on any reminder icon; a moment after it leaves them all they go again
BR.hovered = false
function BR.ApplyHover()
    for _, b in ipairs(BR.iconList or {}) do
        if b.FlareUI_OnHover then b:SetAlpha(BR.hovered and 1 or 0) else b:SetAlpha(1) end
    end
end
function BR.HoverEnter()
    if BR.hoverTimer then BR.hoverTimer:Cancel(); BR.hoverTimer = nil end
    if not BR.hovered then BR.hovered = true; BR.ApplyHover() end
end
function BR.HoverLeave()
    if BR.hoverTimer then BR.hoverTimer:Cancel() end
    BR.hoverTimer = C_Timer.NewTimer(0.3, function()
        BR.hoverTimer = nil
        for _, b in ipairs(BR.iconList or {}) do
            if b:IsShown() and b:IsMouseOver() then return end
        end
        BR.hovered = false
        BR.ApplyHover()
    end)
end

-- Custom Reminders: your own, per class (db.custom[class]): spell IDs or names and item IDs,
-- any one of them counts. A click casts the first spell you know, else uses the first item in your bags.
local function CustomList(create)
    local db = GetDb()
    if not db then return nil end
    local _, class = UnitClass("player")
    if create then
        db.custom = db.custom or {}
        db.custom[class] = db.custom[class] or {}
    end
    return db.custom and db.custom[class]
end
-- "1459, 23028" / "Arcane Intellect" / "item:13452": spells (by ID or name) and items
function BR.AddCustom(text)
    if type(text) ~= "string" then return end
    local spells, items = {}, {}
    for raw in text:gmatch("[^,;]+") do
        local part = strtrim(raw)
        local itemID = tonumber(part:match("^item:(%d+)$"))
        local number = tonumber(part)
        if itemID then
            items[#items + 1] = itemID
        elseif number and C_Spell.GetSpellName(number) then
            spells[#spells + 1] = number
        elseif number and C_Item.GetItemInfoInstant and C_Item.GetItemInfoInstant(number) then
            items[#items + 1] = number
        elseif part ~= "" and not number then
            spells[#spells + 1] = part
            -- a food or potion typed by name: when it's an item the game knows (in your
            -- bags) and not a spell, it's kept as that item too, for its icon and a click to use it
            local spellInfo = C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(part)
            local nameItem = not spellInfo and C_Item.GetItemInfoInstant and C_Item.GetItemInfoInstant(part)
            if type(nameItem) == "number" then items[#items + 1] = nameItem end
        end
    end
    if #spells == 0 and #items == 0 then return end
    local list = CustomList(true)
    list[#list + 1] = { spells = spells, items = items }
    BR.CustomIds(list)
    BR.Resolve()
    BR.Update()
end
-- Custom Reminders, one by one: this class's own, ticked; unticking removes one. By id, not by place:
-- the menu stays open, and after one was removed its other ticks stood for the wrong reminders
local customTokens = {}
function BR.CustomTokens() return customTokens end
local function CustomLabel(c)
    local parts = {}
    for _, s in ipairs(c.spells or {}) do parts[#parts + 1] = type(s) == "number" and (SpellName(s) or tostring(s)) or tostring(s) end
    for _, id in ipairs(c.items or {}) do
        parts[#parts + 1] = (C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or ("item:" .. id)
    end
    return #parts > 0 and table.concat(parts, " / ") or "?"
end
function BR.CustomChoices()
    local list = {}
    wipe(customTokens)
    for _, c in ipairs(BR.CustomIds(CustomList())) do
        customTokens[#customTokens + 1] = "c" .. c.id
        list[#list + 1] = { "c" .. c.id, CustomLabel(c) }
    end
    return list
end
function BR.CustomValue()
    return #customTokens > 0 and table.concat(customTokens, ",") or "none"
end
function BR.SetCustom(value)
    local list = CustomList()
    if not list then return end
    local ticked = ns.Conditions.Set(value or "")
    BR.CustomIds(list)
    for i = #list, 1, -1 do
        if not ticked["c" .. list[i].id] then BR.ForgetCustom(table.remove(list, i)) end
    end
    BR.Resolve()
    BR.Update()
end
local function RemoveCustom(def)
    local list = CustomList()
    if not list then return end
    for i, c in ipairs(list) do
        if c == def.stored then BR.ForgetCustom(table.remove(list, i)) break end
    end
    BR.Resolve()
    BR.Update()
end
-- Never Remind Me, Hide Until Reload and Snooze remember a custom reminder by its id, not its place
-- in the list: removing one moved them onto the next. Older ones get their place as their id.
function BR.CustomIds(list)
    list = list or {}
    local last = 0
    for _, c in ipairs(list) do last = math.max(last, tonumber(c.id) or 0) end
    for i, c in ipairs(list) do
        if not c.id then
            c.id = math.max(i, last + 1)
            last = c.id
        end
    end
    return list
end
-- removed: what was kept about it goes too (its id may be given again)
function BR.ForgetCustom(c)
    local _, class = UnitClass("player")
    local key = (class or "") .. ":custom" .. tostring(c and c.id)
    local db = GetDb()
    if db and db.hidden then db.hidden[key] = nil end
    dismissed[key], snoozed[key] = nil, nil
end
function BR.CustomEntries(out)
    for _, c in ipairs(BR.CustomIds(CustomList())) do
        local def = { key = "custom" .. c.id, custom = true, stored = c, items = c.items or {} }
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

local Enabled
-- the reminders the settings leave on, for From the Middle's room
function BR.EnabledCount()
    local n = 0
    for _, entry in ipairs(active) do if Enabled(entry) then n = n + 1 end end
    return math.min(n, 12)
end

function Enabled(entry)
    local db = GetDb() or {}
    local hideKey = BR.HideKey(entry)
    if dismissed[hideKey] or (db.hidden and db.hidden[hideKey]) then return false end

    -- the off-hand's reminder: only with a weapon there
    if entry.slot == 17 and not OffHandWeapon() then return false end
    if entry.def.camp or entry.def.bag then return db.camping == true end
    if entry.def.gathering then return db.gathering == true end
    if (entry.def.supply or entry.def.ammo) and db.supplies ~= true then return false end
    if entry.def.durability and db.durability ~= true then return false end
    if entry.def.trinket and db.trinkets ~= true then return false end
    if entry.def.optIn and not ns.Conditions.Set(db.extras or "")[entry.def.key] then return false end
    if entry.def.weapon == "oil" and db.weaponOil ~= true then return false end
    -- Weapon Buffs, Pets and the class's own buffs: where they show
    if entry.def.weapon and not InScope(db.weaponScope) then return false end
    if entry.def.pet and not InScope(db.petScope) then return false end
    if entry.classBuff and not entry.def.weapon and not entry.def.pet and not InScope(db.classScope) then return false end
    -- an elixir: watched (ticked in Elixirs and More, or in your bags), and where food and flask show
    if entry.def.elixir then
        local mode = db.consumables or "off"
        if mode == "off" or db.elixirOn == false or not ElixirWatched(entry.def, db) then return false end
        return InScope(mode)
    end
    if entry.def.notRole and not ns.EditPreviewing() then
        local ok, role = pcall(UnitGroupRolesAssigned, "player")
        if ok and Readable(role) and role == entry.def.notRole then return false end
    end
    if entry.def.role and not ns.EditPreviewing() then
        local ok, role = pcall(UnitGroupRolesAssigned, "player")
        return ok and Readable(role) and role == entry.def.role or false
    end
    if entry.def.elixirStock then
        local mode = db.consumables or "off"
        if mode == "off" or db.elixirOn == false or db.elixirSource ~= "bags" then return false end
        return InScope(mode)
    end
    if entry.def.consumable then
        local mode = db.consumables or "off"
        if mode == "off" or db[entry.def.switch] == false then return false end
        return InScope(mode)
    end
    return true
end

--------------------------------------------------
-- 3. WHO IS MISSING WHAT
--------------------------------------------------
local scan = { auras = {}, reach = {}, roster = {}, dirty = {} }
local function BuildGroupUnits(out)
    wipe(out)
    local db = GetDb()
    local scope = db and db.group or "all"
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

-- A pass shares roster and reachability checks across all reminder kinds. Callers may
-- narrow/mutate their own list, so copy the roster rather than returning its shared buffer.
local function GroupUnits(out)
    if not scan.active then return BuildGroupUnits(out) end
    if not scan.rosterReady then BuildGroupUnits(scan.roster); scan.rosterReady = true end
    wipe(out)
    for i, unit in ipairs(scan.roster) do out[i] = unit end
    return out
end

-- someone a buff can reach: there, alive, online, seen and in your phase, and within the game's group
-- range check (one it can't make, or keeps secret, counts as in range). Always on.
local function IsReachable(unit)
    if not UnitExists(unit) or UnitIsDeadOrGhost(unit) or not UnitIsConnected(unit) then return false end
    if unit ~= "player" and not UnitIsUnit(unit, "player") then
        if not UnitIsVisible(unit) then return false end
        if UnitPhaseReason and UnitPhaseReason(unit) then return false end
        if UnitInRange then
            local ok, inRange, checked = pcall(UnitInRange, unit)
            if ok and Readable(inRange) and Readable(checked) then
                if checked and not inRange then return false end
            elseif CheckInteractDistance and not InCombatLockdown() then
                -- Forever keeps UnitInRange secret: the follow distance (about 28 yards,
                -- near a buff's 30) instead, out of a fight; an answer it hides still counts as in range
                local ok2, near = pcall(CheckInteractDistance, unit, 4)
                if ok2 and Readable(near) and near == false then return false end
            end
        end
    end
    return true
end

-- false only when the game says the spell can't reach the unit from here (out of its range); any
-- other answer (in range, can't tell, kept secret) is true. Picks who a click buffs, so one member
-- out of range doesn't hold up the rest.
-- a spell cooling down for longer than the global cooldown (an unreadable answer counts as ready)
function BR.OnCooldown(spellID)
    if not (spellID and C_Spell and C_Spell.GetSpellCooldown) then return false end
    local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
    if not (ok and type(info) == "table") then return false end
    local start, duration = info.startTime, info.duration
    if not (Readable(start) and Readable(duration) and start and duration) then return false end
    return start > 0 and duration > 1.5
end

function BR.SpellReaches(castID, unit)
    if not (castID and C_Spell and C_Spell.IsSpellInRange) or InCombatLockdown() then return true end
    local ok, inRange = pcall(C_Spell.IsSpellInRange, castID, unit)
    return not (ok and Readable(inRange) and inRange == false)
end

-- The rank of a buff a member can take. The game refuses a rank learned more than ten levels
-- above the target ("target too low level"), so a low-level friend needs a lower rank.
-- Takes a list of cast IDs (highest first) or something holding one (.cast or .def.cast).
-- Returns the highest known rank the unit can take, or nil when none fits. A level the game
-- hides or doesn't give (?? or secret) and a learn level it can't tell both count as able.
BR.learnLevel = {}   -- [spellID] = level the rank is learned at (spell data doesn't change)
BR.lowRank = {}      -- [spellID] = true: a known rank below the top known one (cast by ID, not name)
BR.auraUnits = {}   -- [unit token] = whether its UNIT_AURA is looked at (the event handler in Init)
function BR.RankFor(list, unit)
    if type(list) == "table" and list.def then list = list.def.cast
    elseif type(list) == "table" and list.cast then list = list.cast end
    local level = unit and UnitLevel and UnitLevel(unit)
    if not Readable(level) or type(level) ~= "number" or level <= 0 then level = nil end
    local top
    for _, id in ipairs(list or {}) do
        if Known(id) then
            if not level then return id end
            local learned = BR.learnLevel[id]
            if not learned then
                local ok, l = false, nil
                if C_Spell and C_Spell.GetSpellLevelLearned then ok, l = pcall(C_Spell.GetSpellLevelLearned, id) end
                learned = ok and Readable(l) and type(l) == "number" and l or 0
                -- keep only real answers: spell data that hasn't loaded yet may say 0 for now
                if learned > 0 then BR.learnLevel[id] = learned end
            end
            if learned <= 0 or level >= learned - 10 then
                if top then BR.lowRank[id] = true end
                return id
            end
            top = top or id
        end
    end
end

local function Reachable(unit)
    if not scan.active then return IsReachable(unit) end
    local value = scan.reach[unit]
    if value == nil then value = IsReachable(unit); scan.reach[unit] = value end
    return value
end

-- UNIT_AURA dirties only its unit (and aliases). Other events and direct updates rebuild
-- everything; the periodic full pass still covers missing events and changing aura access.
local function InvalidateAuraReads()
    if scan.fullDirty then
        wipe(scan.auras)
    else
        for cachedUnit in pairs(scan.auras) do
            local clear = scan.dirty[cachedUnit]
            if not clear then
                for unit in pairs(scan.dirty) do
                    local ok, same = pcall(UnitIsUnit, cachedUnit, unit)
                    if not ok or not canaccessvalue(same) or same then clear = true; break end
                end
            end
            if clear then scan.auras[cachedUnit] = nil end
        end
    end
    wipe(scan.dirty)
    scan.fullDirty = nil
end

-- true when the unit has one of the names with more than `before` seconds left; second: it has it,
-- but it is running out (Remind Before It Ends)
-- looked up by name, not walked: walking makes a table for every aura on every unit, up to 3 times
-- a second in a raid, and that garbage feeds periodic stutters
-- own: only a buff the player cast counts (a source the game hides counts as yours: quiet)
local function Mine(a)
    local source = a.sourceUnit
    if not Readable(source) or not source then return true end
    local ok, same = pcall(UnitIsUnit, source, "player")
    return not ok or not Readable(same) or same
end
-- "Running out" comes late on a short buff: in its last quarter at the earliest (a 2-minute Battle Shout would remind
-- from its cast on)
function BR.Before(aura, before)
    local duration = aura and aura.duration
    if Readable(duration) and type(duration) == "number" and duration > 0 then return math.min(before, duration / 4) end
    return before
end
local function HasBuff(unit, names, before, own)
    local now = scan.active and scan.now or GetTime()
    local aura
    local reads
    if scan.active then
        reads = scan.auras[unit]
        if not reads then reads = {}; scan.auras[unit] = reads end
    end
    for name in pairs(names) do
        local record = reads and reads[name]
        if record and record.aura then
            local expires = record.aura.expirationTime
            if Readable(expires) and type(expires) == "number" and expires > 0 and expires <= now then record = nil end
        end
        local ok, a
        if record then
            ok, a = record.ok, record.aura
        else
            ok, a = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, name, "HELPFUL")
            if reads and ok then reads[name] = { ok = ok, aura = a } end
        end
        if ok and a and (not own or not Readable(a) or Mine(a)) then aura = a break end
    end
    if not aura then return false, false end
    local expires = aura.expirationTime
    if not Readable(expires) or not expires or expires == 0 then return true, false end
    local fine = expires - now > BR.Before(aura, before)
    return fine, not fine, expires - now
end

-- an option of this kind whose icon is the enchant's (Forever's reworked poisons have enchant
-- IDs FlareUI doesn't list; their icon still says which one it is, for Last Used)
local iconFamilies = {}
local function FamilyByIcon(kind, iconID)
    if not (Readable(iconID) and iconID and iconID ~= 0 and WEAPON_OPTIONS[kind]) then return nil end
    local map = iconFamilies[kind]
    if not map then
        map = {}
        for _, o in ipairs(WEAPON_OPTIONS[kind]) do
            for _, item in ipairs(o.items or {}) do
                local icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(item)
                if icon then map[icon] = map[icon] or o.key end
            end
            if o.cast then
                local icon = C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(o.cast)
                if icon then map[icon] = map[icon] or o.key end
            end
        end
        iconFamilies[kind] = map
    end
    return map[iconID]
end

-- the player's buff by spell ID (names can be shared: Elixir of Mageblood and Nightfin Soup are both
-- "Mana Regeneration"). Unreadable: there (quiet)
local function HasBuffByID(ids, before)
    local now = GetTime()
    for _, id in ipairs(ids) do
        local ok, a = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
        if not ok or not Readable(a) then return true, false end
        if a then
            local expires = a.expirationTime
            if not Readable(expires) or not expires or expires == 0 then return true, false end
            local fine = expires - now > BR.Before(a, before)
            return fine, not fine, expires - now
        end
    end
    return false, false
end

-- a hand's weapon buff of one kind (Forever's C_Item.GetWeaponEnchantInfo): missing, running out, and
-- the family seen there. Anything the game hides from addons, or can't tell, counts as there (quiet).
-- mode: "auto" (the class's own or an oil / stone), "any" (any timed enchant) or "class" (the class's own)
local function WeaponMissing(slot, kind, before, mode)
    -- nothing to coat: no weapon in that hand, or a fishing pole
    local item = GetInventoryItemID("player", slot)
    if not item then return false end
    local _, _, _, _, _, classID, subID = C_Item.GetItemInfoInstant(item)
    if classID == 2 and subID == 20 then return false end
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
        -- a timed enchant of this kind (by its type, or a known ID; no ID: can't tell, so it counts), an
        -- oil or stone (not when the class's own was picked), or any at all (Any Weapon Buff)
        local own = families[id] or (kind == "oil" and enchantType == TEMPORARY) or (kind ~= "oil" and enchantType == IMBUE)
        local oil = OIL_ENCHANTS[id] or enchantType == TEMPORARY
        local counts = id == nil or own or (mode ~= "class" and oil) or mode == "any"
        if has and enchantType ~= PERMANENT and counts then
            family = family or (id and (families[id] or OIL_ENCHANTS[id])) or FamilyByIcon(kind, e.enchantIconID)
            local seconds = (left or 0) / 1000
            -- a poison nearly out of charges counts as running out, unless Remind Before It Ends is
            -- Only When Missing
            local charges = e.charges
            local low = before > 0 and Readable(charges) and charges and charges > 0 and charges <= LOW_CHARGES
            -- (no time given: it's on, and nothing says it ends soon)
            if (seconds > before or seconds <= 0) and not low then return false, false, family end
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

-- the blessing a member should have, among the ones you know: the one picked for that player (by
-- GUID, the right-click menu's Group Members), else for their class (By Class), else the one for
-- everyone (Automatic: Might for the fighters, Wisdom for the rest), else the first you know
-- (a pick you no longer know falls through to the next one)
local BlessingFor
-- Greater Blessings (the icon's menu, off; Elkren, #196): a click casts the greater rank you know on a
-- member, covering their class, unless someone else of that class should have another blessing (picked
-- per player or class): then that member gets the normal one. nil: the normal one.
function BR.GreaterRank(entry, b, unit, units)
    if not ((GetDb() or {}).greaterBlessings and b and b.greater) then return nil end
    local _, class = UnitClass(unit)
    if not (Readable(class) and class) then return nil end
    for _, other in ipairs(units) do
        if other ~= unit then
            local _, otherClass = UnitClass(other)
            if Readable(otherClass) and otherClass == class and BlessingFor(entry, other) ~= b then return nil end
        end
    end
    return BR.RankFor(b.greater, unit)
end
function BlessingFor(entry, unit)
    local db = GetDb() or {}
    local players, classes = db.blessingPlayer, db.blessingClass
    if players and next(players) then
        local guid = UnitGUID(unit)
        local pick = Readable(guid) and guid and players[guid]
        if pick and pick.key and entry.blessings[pick.key] then return entry.blessings[pick.key] end
    end
    local _, class = UnitClass(unit)
    if not Readable(class) then class = nil end
    local byClass = class and classes and classes[class]
    if byClass and entry.blessings[byClass] then return entry.blessings[byClass] end
    local wanted = db.blessing or "auto"
    if wanted == "auto" then
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
local PET_SETTLE = 2.5   -- seconds the pet's state is left alone after a dismount or a new pet
local function PetFix(entry)
    if IsMounted() then return nil end
    -- right after a dismount or a pet appearing the pet bar still reads Passive for a moment: quiet
    -- until it has caught up (the Passive Pet reminder would flash)
    if GetTime() - (BR.petSettleAt or 0) < PET_SETTLE then return nil end
    local exists = UnitExists("pet")
    if exists and entry.def.pet == "WARLOCK" then BR.NotePet() end
    if exists and not UnitIsDead("pet") then
        local passive = PetPassive()
        if passive then return nil, "pet", "/petdefensive", passive end
    end
    if entry.def.pet == "HUNTER" then
        if exists and UnitIsDead("pet") then return Known(REVIVE_PET) and REVIVE_PET, "player" end
        if not exists then return Known(CALL_PET) and CALL_PET, "player" end
        return nil
    end
    if exists then return nil end
    -- a pet given up for Demonic Sacrifice: its buff stands in for it (unreadable: quiet); with
    -- Demonic Pact the buff stays with a new pet out, so a pet is still wanted
    -- (by name, so a reworked buff still counts)
    if not Known(DEMONIC_PACT) then
        local names = {}
        for _, id in ipairs(SACRIFICE_BUFFS) do
            local name = SpellName(id)
            if name then names[name] = true end
        end
        if next(names) and HasBuff("player", names, 0) then return nil end
    end
    -- the pet picked in the icon's menu, else the last one summoned
    local picked = BR.WarlockPick()
    if picked then return picked, "player" end
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
-- (asked by every group buff: answered once per pass, in scan.provider)
local function OtherProvider()
    if scan.active and scan.provider ~= nil then return scan.provider end
    local _, mine = UnitClass("player")
    local list = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do list[#list + 1] = "raid" .. i end
    elseif IsInGroup() then
        for i = 1, 4 do list[#list + 1] = "party" .. i end
    end
    local found = false
    for _, unit in ipairs(list) do
        -- only one you can see: a member of your class in another zone gives you nothing
        if not UnitIsUnit(unit, "player") and Reachable(unit) then
            local _, class = UnitClass(unit)
            if class == mine then found = true break end
        end
    end
    if scan.active then scan.provider = found end
    return found
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
        -- another hunter's Aspect of the Pack is not yours
        if entry.names[name] and Mine(aura) then
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

-- Paladin Aura: one of yours up (remembered for Last Used), and the one a click casts
local function PaladinAuraOf(name)
    if not BR.paladinAuraNames then
        local names = {}
        for _, a in ipairs(PALADIN_AURAS) do
            for _, id in ipairs(a.ranks) do
                local n = SpellName(id)
                if n then names[n] = a.key end
            end
        end
        BR.paladinAuraNames = names
    end
    return BR.paladinAuraNames[name]
end
function BR.PaladinAuraUp(entry)
    for i = 1, 40 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not ok or not aura then return false end
        local name = aura.name
        if not Readable(name) then return true end
        -- another paladin's aura never stands in for yours
        if entry.names[name] and Mine(aura) then
            local key = PaladinAuraOf(name)
            local me = ns.CharDB and ns.CharDB()
            if me and key then me.lastPaladinAura = key end
            return true
        end
    end
    return false
end
local function AuraRank(key)
    for _, a in ipairs(PALADIN_AURAS) do
        if a.key == key then
            for _, id in ipairs(a.ranks) do
                if Known(id) then return id end
            end
        end
    end
end
-- the menu's pick, else the last one you had up, else Devotion (the first you know)
function BR.PaladinAuraToCast()
    local pick = (GetDb() or {}).paladinAura or "auto"
    local me = ns.CharDB and ns.CharDB()
    local id = (pick ~= "auto" and AuraRank(pick)) or (me and me.lastPaladinAura and AuraRank(me.lastPaladinAura))
    if not id then
        for _, a in ipairs(PALADIN_AURAS) do
            id = AuraRank(a.key)
            if id then break end
        end
    end
    if id then return id, SpellIcon(id) end
end
-- for the right-click menu: the auras you know (and the one picked, even if not known)
function BR.PaladinAuraChoices()
    local list, pick = {}, (GetDb() or {}).paladinAura
    for _, a in ipairs(PALADIN_AURAS) do
        local id = AuraRank(a.key)
        if id or pick == a.key then list[#list + 1] = { a.key, SpellName(id or a.ranks[#a.ranks]) or a.key } end
    end
    return list
end

local units = {}
-- an elixir family's buff on you: fine, running out, seconds left (as HasBuff)
local function ElixirUp(entry, before)
    local def = entry.def
    -- the items' own spell names count too (once every item has loaded)
    if not entry.itemNames and C_Item.GetItemSpell then
        local all = true
        entry.itemSpellIDs = entry.itemSpellIDs or {}
        for _, item in ipairs(def.items) do
            local spellName, spellID = C_Item.GetItemSpell(item)
            if spellName then entry.names[spellName] = true else all = false end
            if spellID and not tContains(entry.itemSpellIDs, spellID) then
                entry.itemSpellIDs[#entry.itemSpellIDs + 1] = spellID
            end
        end
        entry.itemNames = all or nil
    end
    -- by spell ID where the game knows one: a name can be another buff's too (Elixir of
    -- Mageblood and Nightfin Soup are both "Mana Regeneration"); by name only when no ID resolves.
    -- The list is kept once every item has loaded: Those in Your Bags checks
    -- every elixir on each pass
    local ids = entry.elixirIDs
    if not ids then
        ids = {}
        for _, id in ipairs(def.buffs) do
            if SpellName(id) then ids[#ids + 1] = id end
        end
        for _, id in ipairs(entry.itemSpellIDs or {}) do
            if not tContains(ids, id) then ids[#ids + 1] = id end
        end
        if entry.itemNames then entry.elixirIDs = ids end
    end
    if #ids > 0 then return HasBuffByID(ids, before) end
    return HasBuff("player", entry.names, before)
end
-- each active reminder's missing / total, the first unit to cast on, the spell (when it is not the
-- reminder's own: a blessing or a pet's), and whether nothing is missing, only running out
local function Check(entry, before)
    local def = entry.def
    -- never for blessings: two paladins split them, so another paladin doesn't make yours
    -- needless; the count below only takes members missing the one they should get from you
    if def.group and not def.blessing and (GetDb() or {}).onlyProvider and OtherProvider() then return 0, 0 end
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
        for _, unit in ipairs(GroupUnits(units)) do
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
        if UnitUsesAmmo and not UnitUsesAmmo("player") then return 0, 1 end
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
    if def.elixirStock then
        for _, e in ipairs(active) do
            if e.def.elixir and ElixirInBags(e.def) then return 0, 1 end
        end
        local running, left
        for _, e in ipairs(active) do
            if e.def.elixir then
                local fine, r, l = ElixirUp(e, before)
                if fine then return 0, 1 end
                if r and not running then running, left = true, l end
            end
        end
        return 1, 1, "player", nil, nil, running or false, { text = L["No elixir in your bags."] },
            running and left or nil
    end
    if def.elixir then
        local running, left, item
        -- Any One of Them: the watched elixirs make one
        -- reminder, on the first of them, fine while any is up, drinking whichever is in your bags
        local db = GetDb() or {}
        if db.elixirMode == "any" then
            local first
            for _, e in ipairs(active) do
                if e.def.elixir and ElixirWatched(e.def, db) then first = e break end
            end
            if entry ~= first then return 0, 0 end
            -- (Those in Your Bags: any elixir on you counts, the one you drank the last of too)
            local carried = db.elixirSource == "bags"
            for _, e in ipairs(active) do
                if e.def.elixir and (carried or ElixirWatched(e.def, db)) then
                    local fine, r, l = ElixirUp(e, before)
                    if fine then return 0, 1 end
                    if r and not running then running, left = true, l end
                    item = item or ElixirInBags(e.def)
                end
            end
        else
            local fine
            fine, running, left = ElixirUp(entry, before)
            if fine then return 0, 1 end
            item = ElixirInBags(def)
        end
        if item then
            return 1, 1, "player", nil, ItemIcon(item), running, { item = "item:" .. item, tipItem = item },
                running and left or nil
        end
        return 1, 1, "player", nil, nil, running, { none = true, tipItem = def.items[1] }, running and left or nil
    end
    if def.paladinAura then
        if BR.PaladinAuraUp(entry) then return 0, 1 end
        return 1, 1, "player", BR.PaladinAuraToCast()
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
    if def.manaGem then
        for _, id in ipairs(def.items) do
            if ItemCount(id) > 0 then return 0, 1 end
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
                -- Forever has one tracking slot for spells: a class tracker on (Track Beasts,
                -- Sense Undead...) leaves no room, so nothing to remind; Find Treasure stacks with it
                if info and info.active and info.type == "spell" and info.spellID and info.spellID ~= 2481 then return 0, 1 end
            end
        end
        return HasBuff("player", entry.names, 0) and 0 or 1, 1, "player"
    end
    if def.blessing then
        local missing, total, first, firstBlessing, firstRank, gone = 0, 0, nil, nil, nil, false
        local farUnit, farBlessing, farRank   -- the first missing member out of the spell's range, if no one closer
        local members = GroupUnits(units)
        for _, unit in ipairs(members) do
            if Reachable(unit) then
                local b = BlessingFor(entry, unit)
                -- the rank this member can take; none (Kings under level 10...) leaves them out
                local rank = b and (BR.GreaterRank(entry, b, unit, members) or BR.RankFor(b.cast, unit))
                if rank then
                    total = total + 1
                    local fine, running = HasBuff(unit, b.names, before)
                    if not fine then
                        missing = missing + 1
                        if not running then gone = true end
                        if not first then
                            if BR.SpellReaches(rank, unit) then
                                first, firstBlessing, firstRank = unit, b, rank
                            elseif not farUnit then
                                farUnit, farBlessing, farRank = unit, b, rank
                            end
                        end
                    end
                end
            end
        end
        if not first then first, firstBlessing, firstRank = farUnit, farBlessing, farRank end
        return missing, total, first, firstRank, firstBlessing and firstBlessing.icon, not gone
    end
    if not def.group then
        -- buffs that can only be told apart by ID (the foods with their own buff): on, or can't tell
        for _, id in ipairs(def.ids or {}) do
            local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
            if not ok or not Readable(aura) or aura then return 0, 1 end
        end
        local fine, running, left = HasBuff("player", entry.names, before, def.own)
        -- food: the last food you ate that gave the buff is remembered (BR.pendingFood; BR.ConfirmFood)
        if def.key == "food" and fine and BR.ConfirmFood then BR.ConfirmFood() end
        if fine then return 0, 1 end
        -- food: a click eats that one again while you have it
        local food = def.key == "food" and ns.CharDB().buffFood
        -- (a drink saved as the food, in older versions: forgotten)
        if food and BR.IsDrink and BR.IsDrink(food) then food, ns.CharDB().buffFood = nil, nil end
        if food and ItemCount(food) > 0 then
            return 1, 1, "player", nil, ItemIcon(food), running, { item = "item:" .. food, tipItem = food },
                running and left or nil
        end
        -- a flask: a click drinks the one in your bags
        local item = def.items and ElixirInBags(def)
        if item then
            return 1, 1, "player", nil, ItemIcon(item), running, { item = "item:" .. item, tipItem = item },
                running and left or nil
        end
        return 1, 1, "player", nil, nil, running, def.items and { text = L["Flask"], none = true } or nil,
            running and left or nil
    end
    local missing, total, first, firstRank, gone = 0, 0, nil, nil, false
    local far, farRank   -- the first missing member out of the spell's range, if no one closer
    -- Thorns: tanks (their group role, or the raid's main tanks; alone, yourself), you, or everyone
    local pick = def.pick and ((GetDb() or {})[def.pick] or "tank")
    local list = GroupUnits(units)
    -- Tanks Only with no tank in the group (invite groups have no roles): yourself, as alone
    local grouped = false
    if pick == "tank" and IsInGroup() then
        for _, unit in ipairs(list) do
            if UnitExists(unit) and IsTank(unit) then grouped = true break end
        end
    end
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
            local caster = true
            if def.casters then
                local _, class = UnitClass(unit)
                caster = not NO_MANA[class]
            end
            -- the rank this member can take; none (Divine Spirit under level 20...) leaves them
            -- out. A shout has no target, so every rank reaches everyone.
            local takes, rank = caster, entry.castID
            if caster and def.cast and not def.party then
                rank = BR.RankFor(def.cast, unit)
                takes = rank ~= nil
            end
            if takes then
                total = total + 1
                local fine, running = HasBuff(unit, entry.names, before)
                if not fine then
                    missing = missing + 1
                    if not running then gone = true end
                    if not first then
                        if BR.SpellReaches(rank, unit) then
                            first, firstRank = unit, rank
                        elseif not far then
                            far, farRank = unit, rank
                        end
                    end
                end
            end
        end
    end
    if not first then first, firstRank = far, farRank end
    return missing, total, first, firstRank, nil, not gone
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
    BR.iconList = BR.iconList or {}
    BR.iconList[#BR.iconList + 1] = b
    BR.BuildIcon(b)
    -- right-click: no cast (an empty macro), the hide menu instead
    b:SetAttribute("type2", "macro")
    b:SetAttribute("macrotext2", "")
    b:HookScript("OnMouseUp", function(self, button) if button == "RightButton" then BR.Menu(self) end end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        if self.tipItem then GameTooltip:SetItemByID(self.tipItem)
        elseif self.spellID or self.tipSpell then GameTooltip:SetSpellByID(self.spellID or self.tipSpell) end
        if self.tipText then GameTooltip:AddLine(self.tipText, 1, 0.82, 0) end
        -- a weapon buff: which hand, and nothing to put on
        if self.hand then GameTooltip:AddLine(self.hand, 1, 0.82, 0) end
        if self.none then GameTooltip:AddLine(L["None in your bags."], 1, 0.3, 0.3) end
        GameTooltip:AddLine(L["Right-click to hide this reminder."], 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    -- On Mouseover: pointing at any icon shows the hidden ones (BR.ApplyHover). After the two SetScripts:
    -- they throw away whatever was hooked before them.
    b:HookScript("OnEnter", function() BR.HoverEnter() end)
    b:HookScript("OnLeave", function() BR.HoverLeave() end)
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
            dismissed[key] = BR.EntryLabel(entry, owner)
            BR.Update()
        end)
        -- (a buff only: something to see come back; the elixir stock: an elixir drunk or picked up;
        -- the sleeping bag: its three Well-Rested stacks)
        if next(entry.names or {}) or entry.def.weapon or entry.def.blessing or entry.def.elixirStock
                or entry.def.bag then
            root:CreateButton(L["Snooze Until Recast"], function()
                snoozed[key] = true
                BR.Update()
            end)
        end
        if entry.def.custom then
            root:CreateButton(L["Remove This Reminder"], function() RemoveCustom(entry.def) end)
        end
        root:CreateButton(L["Never Remind Me"], function()
            local db = GetDb()
            if not db then return end
            db.hidden = db.hidden or {}
            db.hidden[key] = BR.EntryLabel(entry, owner)
            BR.Update()
        end)
        -- a reminder's own choice lives here, not in the settings
        local db = GetDb()
        if not db then return end
        local function Radio(text, field, value)
            root:CreateRadio(text, function() return (db[field] or (field == "thorns" and "tank" or field == "soulstone" and "healer" or "auto")) == value end,
                function() db[field] = value; BR.Update() end)
        end
        if entry.def.blessing then
            root:CreateDivider()
            root:CreateTitle(L["Blessing"])
            for _, choice in ipairs(BR.BlessingChoices()) do Radio(choice[2], "blessing", choice[1]) end
            BR.BlessingSubmenus(root, entry, db)
            root:CreateDivider()
            root:CreateCheckbox(L["Greater Blessings"], function() return db.greaterBlessings == true end,
                function() db.greaterBlessings = not db.greaterBlessings or nil; BR.Update() end)
        elseif entry.def.weapon then
            -- per hand: Last Used, or one you can put on
            local kind = entry.def.weapon
            root:CreateDivider()
            root:CreateTitle(entry.slot == 17 and (INVTYPE_WEAPONOFFHAND or "Off Hand") or (INVTYPE_WEAPONMAINHAND or "Main Hand"))
            Radio(L["Last Used"], WeaponField(entry), "auto")
            Radio(L["Any Weapon Buff"], WeaponField(entry), "any")
            for _, o in ipairs(WEAPON_CHOICES[kind]) do
                if OptionKnown(kind, o) or db[WeaponField(entry)] == o.key then
                    Radio(BR.WeaponOptionLabel(kind, o), WeaponField(entry), o.key)
                end
            end
        elseif entry.def.paladinAura then
            -- which aura a click casts
            root:CreateDivider()
            root:CreateTitle(L["Aura to Cast"])
            Radio(L["Last Used"], "paladinAura", "auto")
            for _, choice in ipairs(BR.PaladinAuraChoices()) do Radio(choice[2], "paladinAura", choice[1]) end
        elseif entry.def.soulstone then
            root:CreateDivider()
            root:CreateTitle(L["Keep It On"])
            Radio(L["Healers"], "soulstone", "healer")
            Radio(L["Only Me"], "soulstone", "self")
        elseif entry.def.pick == "thorns" then
            root:CreateDivider()
            root:CreateTitle(L["Keep It On"])
            Radio(L["Only Tanks"], "thorns", "tank")
            Radio(L["Only Me"], "thorns", "self")
            Radio(L["Everyone"], "thorns", "all")
        elseif entry.def.pet == "WARLOCK" then
            -- (Bremerton) which demon a click summons, as the weapon buffs pick theirs
            root:CreateDivider()
            root:CreateTitle(L["Pet to Summon"])
            Radio(L["Last Used"], "warlockPet", "auto")
            for _, id in ipairs(WARLOCK_SUMMONS) do
                local name = SpellName(id)
                if name and (Known(id) or db.warlockPet == id) then Radio(name, "warlockPet", id) end
            end
        end
        -- the Buff Reminders page
        root:CreateDivider()
        root:CreateButton(L["FlareUI Settings"], function()
            if ns.SettingsPanel then ns.SettingsPanel:Open("br") end
        end)
    end)
end

-- the demon picked in the warlock pet icon's menu, if you know it (nil: Last Used)
function BR.WarlockPick()
    local db = GetDb()
    local id = db and db.warlockPet
    if type(id) == "number" and Known(id) then return id end
end

-- the counts' and timers' fonts, for the page's Fonts tab (key "countFont" or "timeFont")
function BR.Font(key)
    BR.SeedFonts()
    local rdb = GetDb()
    return rdb and rdb[key]
end

-- Once per profile: the Counts and Timers fonts start as the Buffs frame's stack font
function BR.SeedFonts()
    local rdb = GetDb()
    if not rdb or rawget(rdb, "fontsSeeded") then return end
    rdb.fontsSeeded = true
    local au = AurasDb()
    local from = au and ((au.buffs and au.buffs.countFont) or au.countFont)
    if type(from) ~= "table" then return end
    for _, key in ipairs({ "countFont", "timeFont" }) do
        for _, field in ipairs({ "face", "size", "flags", "enableShadow", "shadowX", "shadowY" }) do
            if from[field] ~= nil then rdb[key][field] = from[field] end
        end
    end
end

local function StyleIcon(b, size)
    local db = AurasDb()
    -- only when the look changed: Show runs up to 3 times a second in a raid, and each restyle makes
    -- tables and sets fonts; BR:Refresh (every look or font change) bumps the stamp
    local round = (db and db.style or "round") == "round"
    if b.fuiSize == size and b.fuiRound == round and b.fuiStamp == BR.styleStamp then return end
    b.fuiSize, b.fuiRound, b.fuiStamp = size, round, BR.styleStamp
    b:SetSize(size, size)
    local AU = ns.Auras
    if AU and AU.StyleIcon then
        AU.StyleIcon(b, b.icon, b.pieces, round)
        -- the reminders' own Counts and Timers fonts (the page's Fonts tab)
        BR.SeedFonts()
        local rdb = GetDb()
        for _, part in ipairs({ { b.count, rdb and rdb.countFont }, { b.time, rdb and rdb.timeFont } }) do
            local fs, font = part[1], part[2]
            if font then
                local flags = font.flags or ""
                if flags == "NONE" then flags = "" end
                ns.SetFont(fs, ns.GetFontPath(font.face or ns.GLOBAL_FONT), font.size or 11, flags)
                ns.ApplyShadow(fs, font)
            else
                AU.StackFont(fs)
            end
        end
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
        b.tipText, b.none = s.action and s.action.text, s.action and s.action.none
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
            -- by name: the game casts your highest rank (imbues list only their first rank's ID);
            -- a lower rank picked for a low-level member goes by ID, since a name casts the top rank
            if BR.lowRank[castID] then
                b:SetAttribute("spell", castID)
            else
                b:SetAttribute("spell", SpellName(castID) or castID)
            end
            b:SetAttribute("unit", s.unit or "player")
        else
            b:SetAttribute("type", nil)
        end
        -- Count Text: missing / total, the missing alone, or none
        local countMode = db.countText or "both"
        local countText = ""
        if s.total > 1 and countMode == "both" then countText = s.missing .. "/" .. s.total
        elseif s.total > 1 and countMode == "missing" then countText = tostring(s.missing) end
        -- a click that uses an item from the bags: how many are left
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
        if b.fuiRow ~= parentRow or b.fuiStep ~= step or b.fuiVertical ~= vertical or b.fuiBack ~= back then
            b.fuiRow, b.fuiStep, b.fuiVertical, b.fuiBack = parentRow, step, vertical, back
            b:ClearAllPoints()
            if vertical then
                if back then b:SetPoint("BOTTOMLEFT", parentRow, "BOTTOMLEFT", 0, step) else b:SetPoint("TOPLEFT", parentRow, "TOPLEFT", 0, -step) end
            else
                if back then b:SetPoint("TOPRIGHT", parentRow, "TOPRIGHT", -step, 0) else b:SetPoint("TOPLEFT", parentRow, "TOPLEFT", step, 0) end
            end
        end
        b:Show()
        -- On Mouseover (not on Edit Mode's samples or a preview)
        if not sample then
            b.FlareUI_OnHover = BR.KindMode(s.entry, db) == "mouseover" and not (ns.EditPreviewing and ns.EditPreviewing()) or nil
            b:SetAlpha((b.FlareUI_OnHover and not BR.hovered) and 0 or 1)
        end
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
function BR.TimeTick(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed < 0.5 then return end
    self.elapsed = 0
    for _, b in ipairs(icons) do if b:IsShown() and b.expires then BR.TimeText(b) end end
end
function BR.WatchTimes()
    local any = false
    for _, b in ipairs(icons) do if b:IsShown() and b.expires and not b.charges then any = true break end end
    if not timeWatch then
        timeWatch = CreateFrame("Frame")
        timeWatch.elapsed = 0
    end
    timeWatch:SetScript("OnUpdate", any and BR.TimeTick or nil)
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

function BR.Update(context)
    if not holder or InCombatLockdown() then return end
    if context ~= scan then wipe(scan.auras) end
    wipe(scan.reach)
    scan.active, scan.rosterReady, scan.now, scan.provider = true, false, GetTime(), nil
    wipe(shows)
    local db = GetDb() or {}
    if ns.EditPreviewing and ns.EditPreviewing() then
        -- Edit Mode: every reminder of the class, so the row can be placed
        for _, entry in ipairs(active) do
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
        -- Remind Before It Ends, or its dungeon / raid choice when set ("same" or none: the main one)
        local minutes = db.before or 2
        local inInstance, kind = IsInInstance()
        local special = inInstance and ((kind == "party" and db.beforeDungeon) or (kind == "raid" and db.beforeRaid))
        if type(special) == "number" then minutes = special end
        local before = minutes * 60
        for _, entry in ipairs(active) do
            if Enabled(entry) then
                local missing, total, unit, castID, icon, running, action, left, charges = Check(entry, before)
                -- snoozed: quiet until the buff is back
                local snoozeKey = BR.HideKey(entry)
                if snoozed[snoozeKey] then
                    if missing == 0 then snoozed[snoozeKey] = nil end
                    missing = 0
                end
                -- its spell on cooldown (Fear Ward): nothing to do yet, back when it's ready (the
                -- ticker checks again).
                if missing > 0 and BR.OnCooldown(castID or entry.castID) then missing = 0 end
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
                -- (an On Mouseover reminder stays quiet: it is out of sight on purpose)
                if not shownKeys[key] and BR.KindMode(s.entry, db) ~= "mouseover" then fresh = true end
            end
        end
        shownKeys = now
        if fresh then BR.PlayAlert() end
    end
    scan.active = false
    BR.ShowFaded(shows, db)
end

-- Show Speed / Hide Speed (Fading section): the row fades in as reminders appear where there
-- were none, and out as the last goes. The icons are secure buttons: the empty row is drawn after the
-- fade, out of a fight only (a fight starting meanwhile leaves it to PLAYER_REGEN_ENABLED's update).
-- An unset fadeIn / fadeOut reads the single fadeSpeed of older profiles.
function BR.FadeSpeed(db, field)
    return (db and (db[field] or db.fadeSpeed)) or "instant"
end
local fadeTimer
-- The Slower fade-out runs on its own frame: ns.StagedFall steps the alpha, as it does everywhere else
local stageDriver = CreateFrame("Frame")
stageDriver:Hide()
function BR.ShowFaded(list, db)
    local had = BR.shownCount or 0
    -- a fade-out still running and nothing new to show: let it finish (its timers end it)
    if #list == 0 and had == 0 and BR.fadingOut then return end
    local rising = #list > 0 and had == 0
    local speed = BR.FadeSpeed(db, rising and "fadeIn" or "fadeOut")
    local t = ns.FadeTime and ns.FadeTime(speed) or 0
    -- Slower going out: down to the resting opacity, rest, then finish (ns.FADE_STAGES)
    local staged = speed == "slower" and not rising and ns.FADE_STAGES
    if staged then t = staged.time end
    local target = (db.alpha or 100) / 100
    BR.shownCount = #list
    if fadeTimer then fadeTimer:Cancel(); fadeTimer = nil end
    stageDriver:Hide()
    stageDriver.stageHold = nil
    BR.fadingOut = nil
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
        BR.fadingOut = true
        local function Finish()
            fadeTimer = nil
            BR.fading = nil
            BR.fadingOut = nil
            if InCombatLockdown() then return end
            Show(list)
        end
        if staged then
            stageDriver:SetScript("OnUpdate", function(self, elapsed)
                local alpha = ns.StagedFall(self, holder:GetAlpha(), 0, elapsed)
                holder:SetAlpha(alpha)
                if alpha <= 0 then
                    self:Hide()
                    self.stageHold = nil
                    Finish()
                end
            end)
            stageDriver:Show()
        else
            UIFrameFadeOut(holder, t, holder:GetAlpha(), 0)
            fadeTimer = C_Timer.NewTimer(t, Finish)
        end
    else
        Show(list)
    end
end

-- UNIT_AURA comes often: one check a moment later
local pending = false
local function Soon(unit)
    if InCombatLockdown() then return end
    if type(unit) == "string" then scan.dirty[unit] = true else scan.fullDirty = true end
    if pending then return end
    pending = true
    C_Timer.After(0.3, function()
        pending = false
        InvalidateAuraReads()
        BR.Update(scan)
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

-- Elixirs and More's list: None, then every item by its name in your language
-- what an elixir family gives: the game's own word for it, else ours
BR.ELIXIR_GIVES = {
    giants = { "SPELL_STAT1_NAME", L["Strength"] }, greaterAgility = { "SPELL_STAT2_NAME", L["Agility"] },
    greaterIntellect = { "SPELL_STAT4_NAME", L["Intellect"] }, greaterArcane = { "ITEM_MOD_SPELL_POWER_SHORT", L["Spell Power"] },
    fortitude = { "HEALTH", L["Health"] }, superiorDefense = { "ARMOR", L["Armour"] },
    mageblood = { "ITEM_MOD_MANA_REGENERATION_SHORT", L["Mana Regeneration"] },
    trollsBlood = { "ITEM_MOD_HEALTH_REGENERATION_SHORT", L["Health Regeneration"] },
}
function BR.ElixirLabel(def)
    local give = BR.ELIXIR_GIVES[def.key]
    if not give then return nil end
    local word = _G[give[1]]
    return type(word) == "string" and word ~= "" and word or give[2]
end
function BR.ElixirChoices()
    local list = { { "none", L["None"] }, { divider = true } }
    -- the families (any rank counts) by what they give, then the ones of a kind by name
    for _, def in ipairs(ELIXIRS) do
        local label = BR.ElixirLabel(def)
        if label then list[#list + 1] = { def.key, label } end
    end
    list[#list + 1] = { divider = true }
    for _, def in ipairs(ELIXIRS) do
        if not BR.ELIXIR_GIVES[def.key] then
            local id = def.items[1]
            if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
            list[#list + 1] = { def.key, C_Item.GetItemNameByID and C_Item.GetItemNameByID(id) or def.key }
        end
    end
    return list
end
-- Extra Buffs: the class reminders that are off until ticked, by their spell names
local OPT_IN = { { "shadowProt", 976 }, { "moonkin", 24858 } }
function BR.ExtraChoices()
    local list = { { "none", L["None"] }, { divider = true } }
    for _, o in ipairs(OPT_IN) do list[#list + 1] = { o[1], SpellName(o[2]) or o[1] } end
    return list
end
function BR.ExtraKeys()
    local keys = {}
    for _, o in ipairs(OPT_IN) do keys[#keys + 1] = o[1] end
    return keys
end
function BR.ElixirKeys()
    local keys = {}
    for _, def in ipairs(ELIXIRS) do keys[#keys + 1] = def.key end
    return keys
end

ns.Dialogs = ns.Dialogs or {}
ns.Dialogs["FLAREUI_BR_CUSTOM"] = {
    text = L["A spell or buff to keep up: its name or spell ID. Several, separated by commas, count as one (any of them). An item: item:ID."],
    button1 = L["Add"],
    button2 = L["Cancel"],
    hasEditBox = true,
    maxLetters = 200,
    OnAccept = function(_, text)
        BR.AddCustom(text)
        -- the open settings page shows the new one at once (its list would stay "None")
        if ns.SettingsPanel and ns.SettingsPanel.Refresh then ns.SettingsPanel:Refresh() end
    end,
    hideOnEscape = true,
}

-- the Blessing row's choices (Settings > Buffs & Debuffs): Automatic, then each blessing by its name
function BR.BlessingChoices()
    local list = { { "auto", L["Automatic"] } }
    for _, key in ipairs(BLESSING_ORDER) do
        local ranks = BLESSINGS[key].cast
        list[#list + 1] = { key, SpellName(ranks[#ranks]) or key }
    end
    return list
end

-- the blessing menu's By Class and Group Members: each class gets Default (the choice
-- above) or a blessing you know, each member Class Default or a blessing you know. Members are kept
-- by GUID (UnitName is the first name only) with the name they had, so a pick lasts across sessions.
function BR.BlessingSubmenus(root, entry, db)
    local names = {}
    for _, choice in ipairs(BR.BlessingChoices()) do names[choice[1]] = choice[2] end
    -- the blessings you know, plus one picked before that you no longer know (so it shows ticked)
    local function Picks(current)
        local list = {}
        for _, key in ipairs(BLESSING_ORDER) do
            if entry.blessings[key] or key == current then list[#list + 1] = key end
        end
        return list
    end
    local function Colored(class, text)
        local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if not c then return text end
        return ("|cff%02x%02x%02x%s|r"):format(math_floor(c.r * 255), math_floor(c.g * 255), math_floor(c.b * 255), text)
    end
    -- the pick, greyed after the name, so the list reads without opening each one
    local function Suffix(key) return key and ("  |cff999999" .. (names[key] or key) .. "|r") or "" end

    root:CreateDivider()
    -- By Class: every class, in the game's order
    local byClass = root:CreateButton(L["By Class"])
    local classes = CLASS_SORT_ORDER or { "WARRIOR", "PALADIN", "PRIEST", "SHAMAN", "DRUID", "ROGUE", "MAGE", "WARLOCK", "HUNTER" }
    for _, class in ipairs(classes) do
        local saved = db.blessingClass and db.blessingClass[class]
        local label = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] or class
        local sub = byClass:CreateButton(Colored(class, label) .. Suffix(saved))
        local function Is(value)
            return function() return (db.blessingClass and db.blessingClass[class]) == value end
        end
        local function Set(value)
            return function()
                db.blessingClass = db.blessingClass or {}
                db.blessingClass[class] = value
                BR.Update()
            end
        end
        sub:CreateRadio(L["Default"], Is(nil), Set(nil))
        for _, key in ipairs(Picks(saved)) do sub:CreateRadio(names[key] or key, Is(key), Set(key)) end
    end

    -- Group Members: the party or raid now (you too), each in its class colour
    local units = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do units[#units + 1] = "raid" .. i end
    elseif IsInGroup() then
        units[1] = "player"
        for i = 1, 4 do units[#units + 1] = "party" .. i end
    end
    local rows = {}
    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            local guid = UnitGUID(unit)
            local name = ns.UnitDisplayName and ns.UnitDisplayName(unit) or UnitName(unit)
            if Readable(guid) and guid and Readable(name) and type(name) == "string" then
                local _, class = UnitClass(unit)
                rows[#rows + 1] = { guid = guid, name = name, class = Readable(class) and class or nil }
            end
        end
    end
    local count = 0
    for _ in pairs(db.blessingPlayer or {}) do count = count + 1 end
    if #rows == 0 and count == 0 then return end
    local group = root:CreateButton(L["Group Members"])
    if #rows > 15 and group.SetScrollMode then group:SetScrollMode(400) end
    for _, r in ipairs(rows) do
        local pick = db.blessingPlayer and db.blessingPlayer[r.guid]
        if pick then pick.name = r.name end   -- the name kept current
        local sub = group:CreateButton(Colored(r.class, r.name) .. Suffix(pick and pick.key))
        local function Is(value)
            return function()
                local p = db.blessingPlayer and db.blessingPlayer[r.guid]
                return (p and p.key) == value
            end
        end
        local function Set(value)
            return function()
                if value then
                    db.blessingPlayer = db.blessingPlayer or {}
                    db.blessingPlayer[r.guid] = { key = value, name = r.name }
                elseif db.blessingPlayer then
                    db.blessingPlayer[r.guid] = nil
                end
                BR.Update()
            end
        end
        sub:CreateRadio(L["Class Default"], Is(nil), Set(nil))
        for _, key in ipairs(Picks(pick and pick.key)) do sub:CreateRadio(names[key] or key, Is(key), Set(key)) end
    end
    -- every player pick, those not in the group too
    if count > 0 then
        if #rows > 0 then group:CreateDivider() end
        group:CreateButton(L["Clear Player Choices (%d)"]:format(count), function()
            if db.blessingPlayer then wipe(db.blessingPlayer) end
            BR.Update()
        end)
    end
end

local function BuildSettings()
    -- (a Reset Settings redraws once, after its last setting: LEM:Defer)
    local function Redraw() if not LEM:Defer(BR.Update) then BR.Update() end end
    local function get(key, default) return function() local db = GetDb(); return db and db[key] or default end end
    local function set(key)
        return function(_, value)
            local db = GetDb()
            if not db then return end
            db[key] = value
            Redraw()
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
          values = { { text = L["Off"], value = "none", isRadio = true },
                     { text = L["Missing / Total"], value = "both", isRadio = true },
                     { text = L["Missing Only"], value = "missing", isRadio = true } },
          desc = L["The number on a group buff's icon: how many are missing it, out of how many."],
          get = get("countText", "both"), set = set("countText") },
        { name = L["Icon Size"], kind = LEM.SettingType.Slider, default = 36, minValue = 20, maxValue = 64, valueStep = 1,
          get = get("size", 36), set = set("size") },
        { name = L["Spacing"], kind = LEM.SettingType.Slider, default = 6, minValue = 0, maxValue = 20, valueStep = 1,
          get = get("spacing", 6), set = set("spacing") },
    })
    -- FADING, as the other frames' Fading: Visibility ticks where it shows (Solo / In a Party / In a
    -- Raid, any of them). It always hides in a fight (its icons are secure buttons, and buffs can't
    -- be read then). Only Provider and the role switches stay on the settings page: they pick group
    -- buffs, not where the frame shows.
    local SHOW = { { "solo", "showSolo" }, { "party", "showParty" }, { "raid", "showRaid" } }
    local function On(field) local db = GetDb(); return not (db and db[field] == false) end
    -- Alerts you see on the icons: the glows and the time left
    local function Bool(key, default)
        return function() local db = GetDb(); if not db or db[key] == nil then return default end; return db[key] == true end
    end
    local function SetBool(key)
        return function(_, value) local db = GetDb(); if db then db[key] = value and true or false end; Redraw() end
    end
    -- Look: Icon Alerts, one dropdown of toggles
    local ALERTS = { { "glowMissing", false }, { "glowExpiring", false }, { "timeLeft", true } }
    Section("Look", {
        { name = L["Icon Alerts"], kind = LEM.SettingType.Dropdown, multiple = true,
          values = { { text = L["Glow When Missing"], value = "glowMissing" }, { text = L["Glow When Running Out"], value = "glowExpiring" },
                     { text = L["Time Left"], value = "timeLeft" } },
          desc = L["What the icons show:\n* Glow When Missing: a gold glow round a missing buff\n* Glow When Running Out: an orange glow round a buff about to run out\n* Time Left: the time left on a buff about to run out, at the top of its icon"],
          get = function()
              local list = {}
              for _, a in ipairs(ALERTS) do if Bool(a[1], a[2])() then list[#list + 1] = a[1] end end
              return list
          end,
          set = function(_, value, fromReset)
              for _, a in ipairs(ALERTS) do
                  -- (Reset Settings: each back to its default)
                  if fromReset then SetBool(a[1])(nil, a[2])
                  elseif a[1] == value then SetBool(a[1])(nil, not Bool(a[1], a[2])()) end
              end
          end },
        -- the whole frame's opacity (out of Fading: it isn't a faded state)
        { name = L["Opacity"], kind = LEM.SettingType.Slider, default = 100, minValue = 20, maxValue = 100, valueStep = 5,
          -- plain numbers, as Faded Opacity: "100%" runs past the dialog's edge
          get = get("alpha", 100), set = set("alpha") },
    })
    Section("Fading", {
        { name = L["Visibility"], kind = LEM.SettingType.Dropdown, multiple = true,
          values = { { text = L["Solo"], value = "solo" }, { text = L["In a Party"], value = "party" },
                     { text = L["In a Raid"], value = "raid" } },
          desc = L["Where the reminders show: alone, in a party, in a raid. They always hide in fights."],
          get = function()
              local list = {}
              for _, s in ipairs(SHOW) do if On(s[2]) then list[#list + 1] = s[1] end end
              return list
          end,
          set = function(_, value, fromReset)
              local db = GetDb()
              if not db then return end
              for _, s in ipairs(SHOW) do
                  -- (Reset Settings: shown solo, in a party and in a raid, the default)
                  if fromReset then db[s[2]] = true
                  elseif s[1] == value then db[s[2]] = not On(s[2]) end
              end
              Redraw()
          end },
        { name = L["Hide in Rested Areas"], kind = LEM.SettingType.Checkbox, default = false,
          desc = L["Nothing shows in towns and inns."],
          get = function() local db = GetDb(); return db and db.hideRested or false end, set = set("hideRested") },
        { name = L["Hide While Mounted"], kind = LEM.SettingType.Checkbox, default = false,
          desc = L["No reminders while you ride."],
          get = function() local db = GetDb(); return db and db.hideMounted or false end, set = set("hideMounted") },
        -- Show Speed and Hide Speed (an unset one reads the single fadeSpeed of older profiles)
        { name = L["Show Speed"], kind = LEM.SettingType.Dropdown, default = "instant",
          values = { { text = L["Instant"], value = "instant", isRadio = true }, { text = L["Fast"], value = "fast", isRadio = true },
                     { text = L["Slow"], value = "slow", isRadio = true } },
          desc = L["How fast it comes back.\n* Fast: 0.2 seconds\n* Slow: 0.4 seconds"],
          get = function() return BR.FadeSpeed(GetDb(), "fadeIn") end, set = set("fadeIn") },
        { name = L["Hide Speed"], kind = LEM.SettingType.Dropdown, default = "instant",
          values = { { text = L["Instant"], value = "instant", isRadio = true }, { text = L["Fast"], value = "fast", isRadio = true },
                     { text = L["Slow"], value = "slow", isRadio = true }, { text = L["Slower"], value = "slower", isRadio = true } },
          desc = L["How fast it fades away.\n* Fast: 0.2 seconds\n* Slow: 0.4 seconds\n* Slower: fades to about half over 2 seconds, then 2 seconds later fades out"],
          get = function() return BR.FadeSpeed(GetDb(), "fadeOut") end, set = set("fadeOut") },
    })
    return settings
end

--------------------------------------------------
-- 7. SETUP
--------------------------------------------------
function BR:GetFrame() return holder end

-- its own switch, apart from Buffs & Debuffs': once, a profile that had the reminders on with
-- Buffs & Debuffs off (so never saw them) keeps them off
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
    -- Pet Reminders off and Thorns Off (from older profiles' settings rows) become hidden reminders
    local r = db.reminder
    if r.pets == false or r.thorns == "off" then
        r.hidden = r.hidden or {}
        if r.pets == false then r.hidden["HUNTER:pet"], r.hidden["WARLOCK:pet"] = true, true end
        if r.thorns == "off" then r.hidden["DRUID:thorns"] = true; r.thorns = nil end
        r.pets = nil
    end
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
    -- (a restyle too: the Buffs & Debuffs module leaves this frame's enter and exit to it)
    LEM:RegisterCallback("enter", function() BR:Refresh() end)
    LEM:RegisterCallback("exit", function() BR:Refresh() end)

    local events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE", "SPELLS_CHANGED",
                             "PLAYER_LEVEL_UP", "PLAYER_UNGHOST", "PLAYER_ALIVE", "PLAYER_DEAD",
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
    -- (only the player's own gear matters: a group member's would run a full check for nothing)
    pcall(events.RegisterUnitEvent, events, "UNIT_INVENTORY_CHANGED", "player")
    pcall(events.RegisterUnitEvent, events, "UNIT_PET", "player")
    pcall(events.RegisterUnitEvent, events, "UNIT_SPELLCAST_SUCCEEDED", "player")
    events:RegisterEvent("UNIT_AURA")
    -- food eaten, however it was used: held for 90 s; if the food buff comes in that time, the food
    -- reminder's click eats it next time (Check)
    local DRINK_SPELL = 432
    -- true a drink, false not one, nil not known yet
    function BR.IsDrink(itemID)
        local spellName = C_Item.GetItemSpell and C_Item.GetItemSpell(itemID)
        if not spellName then return nil end
        return spellName == C_Spell.GetSpellName(DRINK_SPELL)
    end
    local function NoteFood(itemID, when)
        if type(itemID) ~= "number" then return end
        local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
        if classID ~= 0 or subclassID ~= 5 then return end
        local drink = BR.IsDrink(itemID)
        if drink then return end
        local note = { item = itemID, at = when }
        if drink == false then BR.pendingFood = note return end
        -- what it does isn't loaded yet: a drink taken for food replaced the food eaten
        -- with it. Asked for, and looked at again
        if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
        C_Timer.After(1, function()
            if BR.IsDrink(itemID) then return end
            local pending = BR.pendingFood
            if not pending or pending.at <= note.at then BR.pendingFood = note end
            if BR.ConfirmFood then BR.ConfirmFood() end
        end)
    end
    -- A food is noticed as one leaves the bags together with a spell of yours it casts: never by hooking the
    -- game's own item use (zbee's blocked armor kit: the game's bag click ran through those hooks and
    -- the block was put on FlareUI). Counted only as the bags change.
    local eaten = { drops = {}, spells = {}, counts = nil }   -- drops: [item] = when; spells: [spell] = when
    BR.eaten = eaten
    local FOOD_WINDOW = 2
    local function Recent(list, now)
        for key, at in pairs(list) do
            if now - at > FOOD_WINDOW then list[key] = nil end
        end
        return list
    end
    local function MatchFood()
        local now = GetTime()
        local spells = Recent(eaten.spells, now)
        for item, at in pairs(Recent(eaten.drops, now)) do
            local _, itemSpell = C_Item.GetItemSpell(item)
            -- (what the item casts may not be loaded yet: the buff coming in decides then, as before)
            local spell = itemSpell or next(spells)
            if spell and spells[spell] then
                eaten.drops[item] = nil
                NoteFood(item, math.min(at, spells[spell]))
            end
        end
    end
    function BR.CountFood()
        local counts = {}
        for bag = 0, NUM_BAG_SLOTS or 4 do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local id = C_Container.GetContainerItemID(bag, slot)
                if Readable(id) and id then
                    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(id)
                    if classID == 0 and subclassID == 5 then
                        local info = C_Container.GetContainerItemInfo(bag, slot)
                        counts[id] = (counts[id] or 0) + (info and info.stackCount or 1)
                    end
                end
            end
        end
        local before = eaten.counts
        eaten.counts = counts
        local dropped
        for id, count in pairs(before or {}) do
            if count - (counts[id] or 0) == 1 then
                eaten.drops[id] = GetTime()
                dropped = true
            end
        end
        if dropped then MatchFood() end
    end
    function BR.FoodSpell(spellID)
        eaten.spells[spellID] = GetTime()
        if next(eaten.drops) then MatchFood() end
    end
    BR.CountFood()
    -- the food buff coming in confirms the food, wherever you are (Check only runs where the
    -- Consumables choice shows the reminder, so eating in the open world was never remembered)
    function BR.ConfirmFood()
        local pending = BR.pendingFood
        if not pending then return end
        if GetTime() - pending.at >= 90 then BR.pendingFood = nil return end
        local name = C_Spell.GetSpellName(19705)   -- Well Fed
        if not name then return end
        local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", name, "HELPFUL")
        if not (ok and Readable(aura) and aura) then return end
        local expires, duration = aura.expirationTime, aura.duration
        if not (Readable2(expires, duration) and type(expires) == "number" and type(duration) == "number") then return end
        if expires - duration >= pending.at then
            ns.CharDB().buffFood = pending.item
            BR.pendingFood = nil
        end
    end
    events:SetScript("OnEvent", function(_, event, unit, _, spellID)
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
        -- the pet's state settles a moment after these (PetFix); looked at again once it has
        if (event == "PLAYER_MOUNT_DISPLAY_CHANGED" and not IsMounted()) or event == "UNIT_PET" then
            BR.petSettleAt = GetTime()
            C_Timer.After(PET_SETTLE + 0.1, function() if BR.Update then BR.Update() end end)
        end
        -- a warlock's summon is remembered for the next time the pet is gone
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            if Readable(spellID) and tContains(WARLOCK_SUMMONS, spellID) then
                local me = ns.CharDB and ns.CharDB()
                if me then me.lastSummon = spellID end
            end
            if Readable(spellID) and spellID then BR.FoodSpell(spellID) end
            return
        end
        -- (party1..4 and raid1..40 only: their pets are never checked; each token's answer is kept,
        -- as nameplate units send many of these)
        if event == "UNIT_AURA" and unit then
            local watched = BR.auraUnits[unit]
            if watched == nil then
                watched = (unit == "player" or unit == "pet" or unit:find("^party%d") or unit:find("^raid%d")) and true or false
                BR.auraUnits[unit] = watched
            end
            if not watched then return end
        end
        if event == "PLAYER_REGEN_ENABLED" then ApplyPosition() end
        if event == "BAG_UPDATE_DELAYED" then BR.CountFood() end
        if event == "UNIT_AURA" and unit == "player" and BR.pendingFood then BR.ConfirmFood() end
        if event == "UNIT_AURA" then Soon(unit) else Soon() end
    end)
    -- buffs running out cross the reminder line without an event: a look every 10 seconds; in a group,
    -- every 2.5 (walking in or out of range has no event either)
    local ticks = 0
    C_Timer.NewTicker(2.5, function()
        ticks = ticks + 1
        if ticks >= 4 or (IsInGroup() and not InCombatLockdown()) then
            ticks = 0
            Soon()
        end
    end)
    BR.Update()
end

-- Buffs & Debuffs' look changed (Aura Icon Shape, the stack font)
function BR:Refresh()
    BR.styleStamp = (BR.styleStamp or 0) + 1   -- icons restyle once (StyleIcon)
    BR.Update()
end
