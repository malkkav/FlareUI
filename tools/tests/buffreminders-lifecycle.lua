local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local ns = { L = setmetatable({}, { __index = function(_, key) return key end }) }
local edit = { SettingType = { Dropdown = 1, Slider = 2, Checkbox = 3, Expander = 4 }, callbacks = {} }
function edit:IsInEditMode() return ui.editing == true end
function edit:GetActiveLayoutName() return "Modern" end
function edit:AddFrame(frame, moved) frame.moved = moved end
function edit:AddFrameSettings(frame, rows) frame.settings = rows end
function edit:RegisterCallback(event, callback) self.callbacks[event] = callback end
function edit:Defer() return false end
function edit:RefreshFrameSettings(frame) self.refreshed = frame end
env.LibStub = function(name) return name == "FlareEditMode" and edit or {} end
env.GetLocale = function() return "enUS" end
env.canaccessvalue = function(value) return value ~= "hidden" end
env.UnitGUID = function(unit) return "Unit-" .. unit end
env.RegisterStateDriver = function(frame, attribute, rule) frame.driver = { attribute, rule } end
env.C_Timer.NewTimer = env.C_Timer.NewTicker
env.GameTooltip_Hide = function() env.GameTooltip:Hide() end
env.GameTooltip.SetSpellByID = function(self, id) self.spell = id end
env.GameTooltip.SetItemByID = function(self, id) self.item = id end
env.tContains = function(list, value)
    for _, item in ipairs(list) do if item == value then return true end end
    return false
end
local widget = getmetatable(env.UIParent)
if not widget.SetLooping then function widget:SetLooping(mode) self.looping = mode end end

local class, role = "PRIEST", "HEALER"
local group, rested, mounted, secret = true, false, false, false
local pet, petDead, passive, petHealth = false, false, false, 100
local instance, outOfSpellRange
local auras, known, cooldowns, bag, gear, menus = {}, {}, {}, {}, {}, {}
local names = {
    [10938] = "Fortitude", [1243] = "Fortitude", [10952] = "Inner Fire",
    [883] = "Call Pet", [982] = "Revive Pet", [136] = "Mend Pet", [13165] = "Aspect of the Hawk",
    [19705] = "Well Fed", [688] = "Summon Imp", [697] = "Summon Voidwalker",
    [11730] = "Create Healthstone", [10054] = "Conjure Mana Ruby", [19746] = "Concentration Aura",
}
env.UnitName = function(unit) return unit == "party1" and "Mira" or "Alba" end
env.UnitClass = function(unit)
    local token = unit == "party1" and "WARRIOR" or class
    return token, token
end
env.UnitGroupRolesAssigned = function(unit) return unit == "party1" and "TANK" or role end
env.UnitExists = function(unit) return unit == "player" or unit == "pet" and pet or unit == "party1" and group end
env.UnitIsDeadOrGhost = function() return false end
env.UnitIsConnected = function() return true end
env.UnitIsVisible = function() return true end
env.UnitIsUnit = function(a, b) return a == b end
env.UnitIsDead = function(unit) return unit == "pet" and petDead end
env.UnitHealth = function() return petHealth end
env.UnitHealthMax = function() return 100 end
env.UnitOnTaxi = function() return false end
env.UnitLevel = function(unit) return unit == "party1" and 10 or 60 end
env.IsInGroup = function() return group end
env.IsInRaid = function() return false end
env.IsResting = function() return rested end
env.IsMounted = function() return mounted end
env.IsInInstance = function() return instance ~= nil, instance end
env.GetInventoryItemID = function(_, slot) return gear[slot] end
env.GetInventoryItemDurability = function(slot) if slot == 1 then return 4, 40 end end
env.GetPetActionInfo = function(slot)
    if slot == 1 and passive then return "PET_MODE_PASSIVE", 132311, false, true end
end
env.C_Secrets = { ShouldAurasBeSecret = function() return secret end }
env.C_SpellBook = { IsSpellKnown = function(id) return known[id] end }
env.C_Spell = {
    GetSpellName = function(id) return names[id] or "Spell " .. id end,
    GetSpellTexture = function(id) return id + 1000000 end,
    GetSpellLevelLearned = function(id) return id == 10938 and 60 or 1 end,
    GetSpellCooldown = function(id) return cooldowns[id] end,
    IsSpellInRange = function(_, unit) return unit ~= outOfSpellRange end,
}
env.C_UnitAuras = {
    GetAuraDataBySpellName = function(unit, name)
        local value = auras[unit] and auras[unit][name]
        if value and (value.expirationTime == 0 or value.expirationTime > env.GetTime()) then return value end
    end,
    GetAuraDataByIndex = function(unit, index)
        local name, value = next(auras[unit] or {})
        if index == 1 and value then return { name = name, sourceUnit = value.sourceUnit } end
    end,
    GetPlayerAuraBySpellID = function(id)
        return env.C_UnitAuras.GetAuraDataBySpellName("player", env.C_Spell.GetSpellName(id))
    end,
}
env.C_Item = {
    GetItemCount = function(id) return bag[id] or 0 end,
    GetItemIconByID = function(id) return id + 2000000 end,
    GetItemNameByID = function(id) return "Item " .. id end,
    GetItemSpell = function(id)
        local name = id == 123 and "Well Fed" or id == 124 and "Custom Buff" or id == 125 and "Drink" or nil
        return name, name and id + 1000
    end,
    GetItemInfoInstant = function(id)
        if id == 123 or id == 125 or id == 126 then return id, nil, nil, nil, nil, 0, 5 end
        return id, nil, nil, nil, nil, 2, 1
    end,
    GetWeaponEnchantInfo = function() return {} end,
}
-- one bag slot per item
env.C_Container = {
    GetContainerNumSlots = function(index) return index == 0 and 3 or 0 end,
    GetContainerItemID = function(_, slot)
        local id = slot == 1 and 123 or slot == 2 and 125 or 126
        return (bag[id] or 0) > 0 and id or nil
    end,
    GetContainerItemInfo = function(_, slot)
        local id = env.C_Container.GetContainerItemID(0, slot)
        return id and { itemID = id, stackCount = bag[id] }
    end,
}
env.MenuUtil = { CreateContextMenu = function(_, build)
    local menu = {
        CreateTitle = function() end,
        CreateDivider = function() end,
        CreateButton = function(_, text, pick) menus[text] = pick end,
        CreateRadio = function(_, text, selected, pick) menus[text] = { selected = selected, pick = pick } end,
    }
    build(nil, menu)
end }
ui:load("Core.lua", ns)
local db = { classScope = "always", petScope = "always", sound = "alarm", glowMissing = true, glowExpiring = true }
ns.db = { profile = { auras = { enabled = true, reminders = true, reminder = db } }, global = {} }
known[10938], known[1243], known[10952] = true, true, true
auras.player = { Fortitude = { expirationTime = 1000 }, ["Inner Fire"] = { expirationTime = 1000 } }
auras.party1 = {}
ui:load("Modules/BuffReminders.lua", ns)
local br = ns.BuffReminders
assert(br:ShouldLoad())
br:Init()
local holder = br:GetFrame()
assert(holder.driver[2] == "[combat] hide; show")
local function iconFor(key)
    for _, icon in ipairs(br.iconList or {}) do
        if icon:IsShown() and icon.entry and (icon.entry.key or icon.entry.def.key) == key then return icon end
    end
end
local fort = assert(iconFor("fortitude"))
assert(fort:GetAttribute("unit") == "party1" and fort:GetAttribute("spell") == 1243 and fort.count:GetText() == "1/2")
assert(fort.glow:IsShown() and ui.sounds[1][2] == "Master")
assert(not iconFor("innerFire"))
fort:RunScript("OnMouseUp", "RightButton")
menus["Snooze Until Recast"]()
assert(not iconFor("fortitude"))
auras.party1.Fortitude = { expirationTime = 1000 }
ui:emit("UNIT_AURA", "party1")
ui:flushTimers()
auras.party1.Fortitude = nil
ui:emit("UNIT_AURA", "party1")
ui:flushTimers()
assert(iconFor("fortitude") == fort, "A snoozed reminder comes back after the buff was applied and lost again")

auras.player["Inner Fire"] = { expirationTime = 140 }
ui:emit("UNIT_AURA", "player")
ui:flushTimers()
local fire = assert(iconFor("innerFire"))
assert(fire.time:GetText() == "40s" and fire.glow:IsShown())
ui.time = 110
fire.expires = 140
local watch = ui:find(function(frame) return frame:GetScript("OnUpdate") == br.TimeTick end)
watch:RunScript("OnUpdate", 0.5)
assert(fire.time:GetText() == "30s")
cooldowns[10952] = { startTime = 100, duration = 20 }
br.Update()
assert(not iconFor("innerFire"))
cooldowns[10952] = nil
db.classScope = "mouseover"
br.Update()
assert(fort:GetAlpha() == 0)
fort:RunScript("OnEnter")
assert(fort:GetAlpha() == 1 and env.GameTooltip.spell == 1243)
fort:RunScript("OnLeave")
ui:flushTimers()
assert(fort:GetAlpha() == 0)
db.classScope = "always"
fort:RunScript("OnMouseUp", "RightButton")
menus["Never Remind Me"]()
assert(not iconFor("fortitude") and #br.HiddenChoices() == 1)
br.SetHidden("none")
assert(iconFor("fortitude") and #br.HiddenChoices() == 0)

db.hideRested, rested = true, true
br.Update()
assert(br.shownCount == 0)
rested, secret = false, true
br.Update()
assert(br.shownCount == 0)
secret, db.hideHealer = false, true
br.Update()
assert(not iconFor("fortitude") and iconFor("innerFire"))
db.hideHealer = false
ui.combat = true
auras.player["Inner Fire"] = nil
br.Update()
assert(fire.time:GetText() == "30s", "A combat-locked refresh leaves secure item state alone")
ui.combat = false

local settings = {}
for _, option in ipairs(holder.settings) do settings[option.name] = option end
settings.Orientation.set("Modern", "VERTICAL")
settings.Growth.set("Modern", "BACK")
assert(settings.Growth.values()[1].text == "Down" and edit.refreshed == holder)
settings["Icon Size"].set("Modern", 42)
assert(holder:GetWidth() == 42 and iconFor("fortitude"):GetPoint() == "BOTTOMLEFT")
holder.moved(holder, "Other", "TOP", 15.6, -30.5)
edit.callbacks.layout("Other")
local point, _, _, x, y = holder:GetPoint()
assert(point == "TOP" and x == 16 and y == -30)
local sample = br.CreateSample(env.UIParent)
br.DrawSample(sample)
assert(#sample.icons == 3 and sample.icons[1].count:GetText() == "2/5" and sample.icons[1]:GetAttribute("type") == nil)

br.AddCustom(" 10952, item:124 ")
br.AddCustom(" item:124 ")
assert(#br.CustomChoices() == 2 and br.CustomChoices()[1][2] == "Inner Fire / Item 124")
assert(br.CustomValue() == "c1,c2")
br.SetCustom("c2")
bag[124] = 3
br.Update()
local custom = assert(iconFor("custom2"), "what is remembered about one follows it, not its place in the list")
assert(custom:GetAttribute("item") == "item:124" and custom.count:GetText() == "3")
custom:RunScript("OnMouseUp", "RightButton")
menus["Remove This Reminder"]()
assert(#br.CustomChoices() == 0)
-- (11-24) Never Remind Me stays with its own reminder when another is removed, and goes with it
br.AddCustom("Alpha Buff")
br.AddCustom("Beta Buff")
br.AddCustom("Gamma Buff")
assert(iconFor("custom1") and iconFor("custom2") and iconFor("custom3"))
iconFor("custom2"):RunScript("OnMouseUp", "RightButton")
menus["Never Remind Me"]()
assert(not iconFor("custom2") and db.hidden["PRIEST:custom2"])
br.SetCustom("c2,c3")
assert(#br.CustomChoices() == 2 and not iconFor("custom2") and iconFor("custom3"))
-- (11-25) the ticks stand for the reminders, not their places: the open menu's others stay theirs
assert(br.CustomValue() == "c2,c3" and br.CustomChoices()[1][1] == "c2" and br.CustomChoices()[1][2] == "Beta Buff")
br.SetCustom("c2,c3")
assert(#br.CustomChoices() == 2, "a second click removes nothing it didn't untick")
br.AddCustom("Delta Buff")
assert(iconFor("custom4") and not iconFor("custom2"))
br.SetCustom("c3,c4")
assert(br.CustomChoices()[1][2] == "Gamma Buff" and iconFor("custom3") and iconFor("custom4"))
assert(db.hidden["PRIEST:custom2"] == nil, "removed: no longer remembered as hidden")
br.SetCustom("none")
assert(#br.CustomChoices() == 0)
-- saved before the ids: each gets its place
db.custom.PRIEST = { { spells = { "Old One" } }, { spells = { "Old Two" } } }
br.Resolve()
br.Update()
assert(iconFor("custom1") and iconFor("custom2") and db.custom.PRIEST[2].id == 2)
br.SetCustom("none")

bag[123], bag[125], bag[126] = 3, 5, 2
names[432] = "Drink"
-- eaten: one less in the bags, and the spell it casts (either may come first)
local function use(id)
    bag[id] = bag[id] - 1
    ui:emit("BAG_UPDATE_DELAYED")
    ui:emit("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", id + 1000)
end
ui:emit("BAG_UPDATE_DELAYED")
bag[126] = 1
ui:emit("BAG_UPDATE_DELAYED")
assert(not br.pendingFood, "gone from the bags with nothing cast: not eaten")
ui.time = ui.time + 5
bag[123] = 1
ui:emit("BAG_UPDATE_DELAYED")
ui:emit("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 9999)
assert(not br.pendingFood, "more than one gone: sold or mailed")
bag[123], bag[126] = 9, 9
ui:emit("BAG_UPDATE_DELAYED")
ui.time = ui.time + 5
use(125)
assert(not br.pendingFood)
auras.player["Well Fed"] = { expirationTime = env.GetTime() + 500, duration = 900 }
use(126)
ui:emit("UNIT_AURA", "player")
ui:flushTimers()
assert(ns.CharDB().buffFood == nil and br.pendingFood.item == 126)
use(123)
use(125)
auras.player["Well Fed"] = { expirationTime = env.GetTime() + 900, duration = 900 }
ui:emit("UNIT_AURA", "player")
ui:flushTimers()
assert(ns.CharDB().buffFood == 123 and not br.pendingFood)
-- (11-23, Tride) a drink whose use isn't loaded yet doesn't take the food's place
local loadedSpell = env.C_Item.GetItemSpell
local requested
auras.player["Well Fed"] = nil
env.C_Item.RequestLoadItemDataByID = function(id) requested = id end
use(123)
env.C_Item.GetItemSpell = function(id) if id ~= 125 then return loadedSpell(id) end end
use(125)
assert(requested == 125 and br.pendingFood.item == 123)
env.C_Item.GetItemSpell = loadedSpell
ui:flushTimers()
assert(br.pendingFood.item == 123, "the drink is known by then")
env.C_Item.GetItemSpell = function(id) if id ~= 126 then return loadedSpell(id) end end
use(126)
ui:flushTimers()
assert(br.pendingFood.item == 126, "a food that never says what it does still counts")
br.pendingFood = nil
env.C_Item.GetItemSpell = loadedSpell
auras.player["Well Fed"] = nil
ns.CharDB().buffFood = 125
instance, db.consumables, db.flask = "party", "instance", false
br.Update()
assert(ns.CharDB().buffFood == nil, "a drink saved as the food is forgotten")
ns.CharDB().buffFood = 123
instance, db.consumables, db.flask, db.durability = "party", "instance", false, true
br.Update()
assert(iconFor("food"):GetAttribute("item") == "item:123")
assert(not iconFor("flask"), "food without flask")
assert(iconFor("durability").count:GetText() == "10%")

class, role, group = "HUNTER", "DAMAGER", false
known = { [883] = true, [982] = true, [136] = true, [13165] = true }
br.Resolve()
br.Update()
assert(iconFor("pet"):GetAttribute("spell") == "Call Pet" and iconFor("aspect"):GetAttribute("spell") == "Aspect of the Hawk")
pet, petDead = true, true
br.Update()
assert(iconFor("pet"):GetAttribute("spell") == "Revive Pet")
-- (a hurt pet can't be told: its health is hidden from addons)
petDead, petHealth = false, 20
br.Update()
assert(not iconFor("pet"))
-- a short buff runs out in its last quarter at the earliest
assert(br.Before({ duration = 120 }, 120) == 30 and br.Before({ duration = 1800 }, 120) == 120 and br.Before({}, 60) == 60)
passive = true
br.Update()
assert(iconFor("pet"):GetAttribute("macrotext") == "/petdefensive")
mounted = true
br.Update()
assert(not iconFor("pet"))
mounted, passive, petHealth = false, false, 100
auras.player = { ["Aspect of the Hawk"] = { expirationTime = 0, sourceUnit = "player" } }
br.Update()
assert(not iconFor("pet") and not iconFor("aspect"))

class, pet = "WARLOCK", false
known = { [688] = true, [697] = true, [11730] = true }
auras.player = {}
br.Resolve()
br.Update()
assert(iconFor("pet"):GetAttribute("spell") == "Summon Voidwalker")
ui:emit("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 688)
br.Update()
assert(iconFor("pet"):GetAttribute("spell") == "Summon Imp")
assert(iconFor("healthstone"):GetAttribute("spell") == "Create Healthstone")
-- (11-25) the pet that's out is the last one used too, however it was summoned
do
    local family = 16
    env.UnitCreatureFamily = function(unit) if unit == "pet" then return "Demon", family end end
    pet = true
    br.Update()
    pet = false
    br.Update()
    assert(ns.CharDB().lastSummon == 697 and iconFor("pet"):GetAttribute("spell") == "Summon Voidwalker")
    -- a hidden or unknown kind keeps what was known
    for _, kind in ipairs({ "hidden", 4 }) do
        family, pet = kind, true
        br.Update()
        pet = false
        br.Update()
        assert(ns.CharDB().lastSummon == 697)
    end
    env.UnitCreatureFamily = nil
    ns.CharDB().lastSummon = 688
    br.Update()
end
-- Demonic Sacrifice: only with Demonic Pact known too (a click on it costs the pet otherwise)
pet, known[18788] = true, true
br.Resolve()
br.Update()
assert(not iconFor("sacrifice"))
known[425464] = true
br.Resolve()
br.Update()
assert(iconFor("sacrifice"))
pet, known[18788], known[425464] = false, nil, nil

-- a mage with no mana gem in the bags: a click conjures the best one known
do
    class, known = "MAGE", { [10054] = true }
    br.Resolve()
    br.Update()
    assert(iconFor("manaGem"):GetAttribute("spell") == "Conjure Mana Ruby")
    bag[5513] = 1                     -- a Mana Jade counts too
    br.Update()
    assert(not iconFor("manaGem"))
    bag[5513], known = nil, {}        -- no Conjure spell known: no reminder
    br.Resolve()
    br.Update()
    assert(not iconFor("manaGem"))
end

class = "ROGUE"
gear[16], gear[17], bag[8928], bag[8985], known = 100, 200, 2, 3, { [2842] = true }
br.Resolve()
br.Update()
local onMain, onOff = assert(iconFor("poison")), assert(iconFor("poisonOff"))
assert(onMain:GetAttribute("macrotext"):find("/use 16", 1, true) and onOff:GetAttribute("macrotext"):find("/use 17", 1, true))
env.C_Item.GetWeaponEnchantInfo = function(slot)
    if slot == 0 then return { { hasEnchant = true, enchantType = 3, enchantID = 625, timeLeft = 300000, charges = 3 } } end
    return {}
end
br.Update()
assert(iconFor("poison").time:GetText() == "3x")
assert(ns.CharDB().lastWeapon.poisonMain == "instant")
db.before = 0
br.Update()
assert(not iconFor("poison"), "Only When Missing ignores low poison charges")
gear[17] = nil
br.Update()
assert(not iconFor("poisonOff"))
db.before = 2

class, role, group = "PALADIN", "TANK", true
known = { [19740] = true, [19742] = true, [465] = true, [19746] = true, [25780] = true }
names[19740], names[19742], names[465], names[25780] = "Blessing of Might", "Blessing of Wisdom", "Devotion Aura", "Righteous Fury"
auras.player, auras.party1 = {}, {}
br.Resolve()
br.Update()
local blessing = assert(iconFor("blessing"))
assert(blessing:GetAttribute("spell") == "Blessing of Wisdom" and blessing.count:GetText() == "2/2")
assert(iconFor("aura"):GetAttribute("spell") == "Devotion Aura")
assert(iconFor("fury"):GetAttribute("spell") == "Righteous Fury")
outOfSpellRange = "player"
br.Update()
assert(blessing:GetAttribute("spell") == "Blessing of Might" and blessing:GetAttribute("unit") == "party1")
outOfSpellRange = nil
auras.player["Blessing of Wisdom"] = { expirationTime = 1000 }
br.Update()
assert(blessing:GetAttribute("spell") == "Blessing of Might" and blessing:GetAttribute("unit") == "party1")
db.blessingPlayer = { ["Unit-party1"] = { key = "wisdom" } }
br.Update()
assert(blessing:GetAttribute("spell") == "Blessing of Wisdom")
db.blessingPlayer = nil
db.blessingClass = { WARRIOR = "wisdom" }
br.Update()
assert(blessing:GetAttribute("spell") == "Blessing of Wisdom")
-- (11-25, #196) Greater Blessings: the greater rank you know, for a member whose class all get the same one
do
    known[25782], names[25782] = true, "Greater Blessing of Might"
    db.blessingClass = { WARRIOR = "might" }
    auras.player["Blessing of Wisdom"] = { expirationTime = 1000 }
    br.Resolve()
    br.Update()
    assert(blessing:GetAttribute("spell") == "Blessing of Might", "off: the normal one")
    db.greaterBlessings = true
    br.Update()
    assert(blessing:GetAttribute("spell") == "Greater Blessing of Might" and blessing:GetAttribute("unit") == "party1")
    -- one of the class is picked for another blessing: the normal one for this member
    db.blessingPlayer = { ["Unit-player"] = { key = "wisdom" } }
    local was = env.UnitClass
    env.UnitClass = function(unit) if unit == "player" then return "Warrior", "WARRIOR" end return was(unit) end
    br.Update()
    assert(blessing:GetAttribute("spell") == "Blessing of Might")
    env.UnitClass, db.blessingPlayer, db.greaterBlessings, db.blessingClass = was, nil, nil, nil
    known[25782] = nil
    auras.player = {}
    br.Resolve()
end
auras.player = { ["Concentration Aura"] = { expirationTime = 0, sourceUnit = "player" } }
br.Update()
assert(not iconFor("aura") and ns.CharDB().lastPaladinAura)
auras.player = {}
br.Update()
assert(iconFor("aura"):GetAttribute("spell") == "Concentration Aura")
assert(#br.PaladinAuraChoices() == 2 and br.BlessingChoices()[2][1] == "might")

-- One elixir reminder can stand for the whole watch list and use an available member.
bag[13452], bag[9206] = 0, 2
db.elixirs, db.elixirMode = "mongoose,giants", "any"
br.Update()
assert(iconFor("mongoose"):GetAttribute("item") == "item:9206" and not iconFor("giants"))
auras.player["Spell 11405"] = { expirationTime = 1000 }
br.Update()
assert(not iconFor("mongoose") and not iconFor("giants"))
auras.player = {}
bag[9206], db.elixirSource = 0, "bags"
br.Update()
assert(iconFor("elixirStock").tipText == "No elixir in your bags.")
bag[3383] = 19
br.Update()
assert(iconFor("greaterIntellect"):GetAttribute("item") == "item:3383")
for _, buff in ipairs({ 3223, 3222, 3219, 1250984, 3164, 2367, 11328, 3160, 2374, 11390, 1250971, 439959, 1245244,
                        1250931, 1250928, 1250989, 1250988, 1250948, 1250944, 1250942 }) do
    auras.player = { ["Spell " .. buff] = { expirationTime = 1000 } }
    br.Update()
    assert(not iconFor("greaterIntellect") and not iconFor("elixirStock"), "lower elixir rank " .. buff .. " counts")
end
auras.player, bag[3383], bag[2454] = {}, 0, 4
br.Update()
assert(iconFor("giants"):GetAttribute("item") == "item:2454")
bag[2454] = 0
auras.player, bag[3383] = {}, 0
-- (11-25) the elixir families by what they give, in the game's words where it has them; every key stays pickable
do
    env.SPELL_STAT2_NAME = "Beweglichkeit"
    local list, keys, at = br.ElixirChoices(), {}, {}
    for i, c in ipairs(list) do if c[1] then keys[c[1]], at[c[1]] = c[2], i end end
    env.SPELL_STAT2_NAME = nil
    assert(list[1][1] == "none" and keys.greaterAgility == "Beweglichkeit" and keys.giants == "Strength" and keys.superiorDefense == "Armour")
    assert(keys.mongoose == "Item 13452" and at.mongoose > at.greaterAgility, "the ones of a kind by name, after the families")
    local n = 0
    for _, key in ipairs(br.ElixirKeys()) do assert(keys[key], key) n = n + 1 end
    assert(#list == n + 3, "none and two dividers")
end
assert(br.ExtraChoices()[3][1] == br.ExtraKeys()[1])

class, role = "SHAMAN", "HEALER"
known = { [8024] = true }
names[8024] = "Flametongue Weapon"
gear[17] = 200
env.C_Item.GetWeaponEnchantInfo = function() return {} end
br.Resolve()
br.Update()
assert(br.Playstyle() == "healer")
assert(iconFor("imbue"):GetAttribute("spell") == "Flametongue Weapon")
assert(iconFor("imbueOff"):GetAttribute("macrotext") == "/cast Flametongue Weapon\n/use 17")

local fades = {}
env.UIFrameFadeIn = function(frame, duration, from, to) fades[#fades + 1] = { frame, duration, from, to } end
env.UIFrameFadeOut = env.UIFrameFadeIn
db.fadeIn, db.fadeOut, db.showParty = "fast", "slow", false
br.Update()
assert(fades[1][2] == 0.4 and fades[1][4] == 0)
ui:flushTimers()
assert(br.shownCount == 0 and not iconFor("imbue"))
db.showParty, db.readyCheck = true, true
br.Update()
assert(fades[2][2] == 0.2 and fades[2][4] == 1)
ui:emit("READY_CHECK")
assert(br.readyUntil == env.GetTime() + 8 and iconFor("imbue").glow:IsShown())
ui:flushTimers()
assert(br.readyUntil == nil)
-- (.zbee, 11-27) Soulstone, Keep It On: Healers by default, Tanks when picked (the tank in party1)
do
    class, role, group = "WARLOCK", "HEALER", true
    known = { [693] = true }
    auras.player, auras.party1 = {}, {}
    bag[5232] = 1
    db.soulstone = nil
    br.Resolve()
    br.Update()
    local icon = iconFor("soulstone")
    assert(icon and icon:GetAttribute("unit") == "player", "Healers: the healer, here you")
    db.soulstone = "tank"
    br.Update()
    assert(iconFor("soulstone"):GetAttribute("unit") == "party1", "Tanks: the tank")
    db.soulstone, bag[5232] = nil, nil
end

print("PASS: buff reminders for group ranks, melee weapons, pets, consumables, dialogs and Edit Mode")
