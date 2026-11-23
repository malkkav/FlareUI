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
    [11730] = "Create Healthstone", [19746] = "Concentration Aura",
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
    GetItemSpell = function(id) return id == 123 and "Well Fed" or id == 124 and "Custom Buff" or nil end,
    GetItemInfoInstant = function(id)
        if id == 123 then return id, nil, nil, nil, nil, 0, 5 end
        return id, nil, nil, nil, nil, 2, 1
    end,
    GetWeaponEnchantInfo = function() return {} end,
    UseItemByName = function() end,
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
assert(not iconFor("fortitude") and br.HiddenCount() == 1)
br.ShowHidden()
assert(iconFor("fortitude") and br.HiddenCount() == 0)

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
assert(br.CustomCount() == 2 and br.CustomChoices()[1][2] == "Inner Fire / Item 124")
assert(br.CustomValue() == "c1,c2")
br.SetCustom("c2")
bag[124] = 3
br.Update()
local custom = assert(iconFor("custom1"))
assert(custom:GetAttribute("item") == "item:124" and custom.count:GetText() == "3")
custom:RunScript("OnMouseUp", "RightButton")
menus["Remove This Reminder"]()
assert(br.CustomCount() == 0)

bag[123] = 3
env.C_Item.UseItemByName(123)
auras.player["Well Fed"] = { expirationTime = 1000 }
ui:emit("UNIT_AURA", "player")
ui:flushTimers()
assert(ns.CharDB().buffFood == 123 and not br.pendingFood)
auras.player["Well Fed"] = nil
instance, db.consumables, db.flask, db.durability = "party", "instance", false, true
br.Update()
assert(iconFor("food"):GetAttribute("item") == "item:123")
assert(iconFor("durability").count:GetText() == "10%")

class, role, group = "HUNTER", "DAMAGER", false
known = { [883] = true, [982] = true, [136] = true, [13165] = true }
br.Resolve()
br.Update()
assert(iconFor("pet"):GetAttribute("spell") == "Call Pet" and iconFor("aspect"):GetAttribute("spell") == "Aspect of the Hawk")
pet, petDead = true, true
br.Update()
assert(iconFor("pet"):GetAttribute("spell") == "Revive Pet")
petDead, petHealth = false, 20
br.Update()
assert(iconFor("pet"):GetAttribute("spell") == "Mend Pet" and iconFor("pet"):GetAttribute("unit") == "pet")
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
assert(br.ElixirChoices()[3][1] == br.ElixirKeys()[1] and br.ExtraChoices()[3][1] == br.ExtraKeys()[1])

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
print("PASS: buff reminders for group ranks, melee weapons, pets, consumables, dialogs and Edit Mode")
