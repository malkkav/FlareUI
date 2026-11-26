-- FlareUI's own DoT tracker: the engine (Does It Die Advanced's tracking, Modules/DotEngine) loads in its own
-- namespace, reads spell descriptions in English and Russian, tracks a cast, and FlareUI draws its estimate.
local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local function noop() end
local Widget = getmetatable(env.UIParent).__index
for _, method in ipairs({ "SetStatusBarColor", "SetReverseFill", "SetFrameStrata", "SetLooping", "SetClipsChildren" }) do
    if not Widget[method] then Widget[method] = noop end
end
function Widget:SetValue(value) self.value = value end
function Widget:GetReverseFill() return false end
function Widget:SetFrameLevel(value) self.frameLevel = value end
env._G = env
env.unpack = unpack
env.GetBuildInfo = function() return "1.60.1", "70170", "Nov 1 2026", 16001 end
env.DEFAULT_CHAT_FRAME = { AddMessage = noop }
env.issecretvalue = function(value) return value == "<secret>" end
env.canaccessvalue = function(value) return value ~= "<secret>" end
env.canaccesstable = function() return true end
env.LibStub = function() return { RegisterCallback = noop } end
local SPELLS = {
    [172] = { "Corruption", "Corrupts the target, causing 222 Shadow damage over 18 sec." },
    [348] = { "Immolate", "Burns the enemy for 90 Fire damage and then an additional 160 Fire damage over 15 sec." },
    [686] = { "Shadow Bolt", "Sends a shadowy bolt at the enemy, causing 150 to 170 Shadow damage." },
    [9493] = { "Rip", "Finishing move that causes damage over time. 1 point : 111 damage over 12 sec. 2 points: 174 damage over 12 sec. 3 points: 237 damage over 12 sec. 4 points: 300 damage over 12 sec. 5 points: 363 damage over 12 sec." },
}
env.C_Spell = {
    GetSpellName = function(id) return SPELLS[id] and SPELLS[id][1] end,
    GetSpellDescription = function(id) return SPELLS[id] and SPELLS[id][2] end,
    RequestLoadSpellData = noop,
}
env.GetSpellBonusDamage = function() return 0 end
env.UnitAttackPower = function() return 0, 0, 0 end
env.GetSpellCritChance = function() return 0 end
local combo = 0
env.GetComboPoints = function() return combo end
local guids = { target = "Creature-0-1-1-1-100-0000000001", player = "Player-1-00000001" }
env.UnitGUID = function(unit) return guids[unit] end
env.UnitExists = function(unit) return guids[unit] ~= nil end
env.UnitIsDead = function() return false end
env.UnitIsPlayer = function(unit) return unit == "player" end
env.UnitName = function(unit) return unit == "target" and "Defias Thug" or "Me" end
env.UnitHealth = function() return "<secret>" end
env.UnitHealthMax = function() return "<secret>" end
env.UnitCanAttack = function() return true end
env.UnitClass = function() return "Warlock", "WARLOCK" end
env.InCombatLockdown = function() return false end
env.C_UnitAuras = { GetDebuffDataByIndex = function() return nil end, GetBuffDataByIndex = function() return nil end }
env.C_AddOns = { IsAddOnLoaded = function(name) return ui.loaded and ui.loaded[name] or false end }

local profile = { dots = { enabled = true, target = true, focus = true, plates = "icon", marker = true, colors = "each",
    opacity = 55, smooth = true, position = "start", icon = "cross", iconSize = 100, pulse = true, waitFirstTick = "off",
    estimateDuringCast = true, trackChannels = true } }
local char = {}
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }), modules = {},
    db = { profile = profile },
    CharDB = function() return char end,
    EditPreviewing = function() return false end, OnEditFight = noop,
}
for _, file in ipairs({ "Namespace", "Locale", "Locale_deDE", "Locale_esES", "Locale_frFR", "Locale_koKR", "Locale_ruRU",
    "Locale_zhCN", "Locale_ptBR", "Engine", "Shields" }) do
    ui:load("Modules/DotEngine/" .. file .. ".lua", ns)
end
local E = ns.DotEngine
assert(E and E.parseDot and E.shielded and E.start, "the engine keeps to its own table")
assert(ns.parseDot == nil and ns.locale == nil and env.DoesItDieAdvancedDB == nil, "and leaves FlareUI's namespace and the globals alone")
assert(not E.isStarted(), "nothing runs until FlareUI starts it")

-- descriptions, in English and on a Russian client
local total, school, duration = E.parseDot("Corrupts the target, causing 222 Shadow damage over 18 sec.")
assert(total == 222 and school == 32 and duration == 18)
total, school, duration = E.parseDot("Burns the enemy for 90 Fire damage and then an additional 160 Fire damage over 15 sec.")
assert(total == 160 and school == 4 and duration == 15, "the periodic part, not the direct hit")
assert(E.parseDot("Sends a shadowy bolt at the enemy, causing 150 to 170 Shadow damage.") == nil)
total, school, duration = E.locale.parseDot("Поражает цель порчей, нанося 222 ед. урона от темной магии за 18 сек.")
assert(total == 222 and school == 32 and duration == 18, "ruRU Corruption")
total, school, duration = E.locale.parseDot("Обжигает противника, нанося 90 ед. урона от огня и еще 1 160 ед. урона от огня за 15 сек.")
assert(total == 1160 and school == 4 and duration == 15, "ruRU Immolate, with a thousands space")

-- the hit dealt at once, ahead of the DoT, on a Russian client: without it no tick size was ever learned there
assert(E.locale.directPart("Поражает цель порчей, нанося 222 ед. урона от темной магии за 18 сек.") == 0)
assert(E.locale.directPart("Обжигает противника, нанося 90 ед. урона от огня и еще 160 ед. урона от огня за 15 сек.") == 90)
assert(E.locale.directPart("Раздирает цель. Противник теряет 27 и дополнительно 60 здоровья за 9 сек. Длина серии приемов увеличивается на 1.") == 27)
assert(E.locale.directPart("Наносит от 100 до 120 ед. урона от огня и еще 40 ед. урона от огня за 8 сек.") == 110)
assert(E.locale.directPart("Ослабляет броню на 285 ед. на 40 сек.") == nil, "not a DoT: nothing is claimed")

ui:load("Modules/DotMarker.lua", ns)
ui:load("Modules/DotTracker.lua", ns)
local frame = env.CreateFrame("Frame", "FlareUI_UF_Target", env.UIParent)
frame.Health = env.CreateFrame("StatusBar", nil, frame)
frame.Health:SetStatusBarTexture("bar")
frame.Portrait = env.CreateFrame("Frame", nil, frame)
ui:load("Modules/UnitFramesDoesItDie.lua", ns)
-- a nameplate FlareUI drew: the bar Nameplates.lua lays over its health bar
local plate = env.CreateFrame("Frame", nil, env.UIParent)
plate.FlareUI_DieHealth = env.CreateFrame("StatusBar", nil, plate)
plate.FlareUI_DieHealth:SetStatusBarTexture("bar")
env.C_NamePlate = { GetNamePlateForUnit = function(unit) return unit == "nameplate1" and plate or nil end }
ui:load("Modules/NameplateDots.lua", ns)
local D = ns.Dots
assert(ns.modules.Dots == D and D:ShouldLoad())

-- another tracker loaded: FlareUI's own stands down
ui.loaded = { DoesItDieAdvanced = true }
D:Init()
assert(not D.Active() and D.OtherAddon() == "Does It Die Advanced")
ui.loaded = nil
D:Init()
assert(D.Active() and E.isStarted() and char.dots.ticks, "learned tick sizes are the character's")
assert(char.dots.waitFirstTick == "off" and char.dots.trackChannels == true, "the accuracy options reach the engine")

-- a cast: Corruption on the target, six ticks of 37 still to come
local dmg, count = D.API.GetRemainingDamage("target")
assert(dmg == 0 and count == 0)
ui:emit("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 172)
local list
dmg, count, list = D.API.GetRemainingDamage("target")
assert(count == 1 and dmg == 222 and list[1].school == 32, "remaining " .. tostring(dmg))
ui:emit("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 686)
assert(select(2, D.API.GetRemainingDamage("target")) == 1, "a direct spell is no DoT")
ui:emit("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3", 348)
dmg, count, list = D.API.GetRemainingDamage("target")
assert(count == 2 and dmg == 382 and list[2].school == 4)

-- FlareUI draws it: a piece per DoT on the health's scale (the health itself unread), the cross on the portrait
local function gauges()
    local found = {}
    for _, w in ipairs(ui.widgets) do
        -- (the pieces' bars live in a clip the size of the health bar)
        local holder = w:GetParent()
        if w.kind == "StatusBar" and holder and holder:GetParent() == frame and holder ~= frame.Health and w.width ~= 10000 and w:IsVisible() and w.value then found[#found + 1] = w end
    end
    return found
end
ns.UFDoesItDie:Refresh()
local bars = gauges()
assert(#bars == 2 and bars[1].value == 222 and bars[2].value == 382, "Corruption's end, then Immolate's")
assert(bars[1].maxValue == "<secret>", "the maximum health goes to the bar unread")
-- a ring style, the bar starting under the portrait's ring: that stretch of the mark is drawn again above it
assert(ns.UFDoesItDie.Describe("target"):find("over the ring nil", 1, true))
ns.UFRing = { Applies = function() return true end, Side = function() return "LEFT" end, TextPad = function() return 13 end }
ns.UFDoesItDie:Refresh()
local cap = ui:find(function(w) return w.kind == "Frame" and w:GetParent() == frame and w.width == 13 end)
assert(cap and cap:IsShown() and cap:GetFrameLevel() == frame:GetFrameLevel() + 11, "over the ring")
assert(ns.UFDoesItDie.Describe("target"):find("over the ring 13", 1, true))
ns.UFRing.Side = function() return "RIGHT" end   -- the ring on the bar's far end: nothing is covered
ns.UFDoesItDie:Refresh()
assert(not cap:IsShown())
ns.UFRing = nil

-- Mark Position > At the Health's End (the default): the pieces hang on the health's own fill and run back
-- from it, each as long as the bar, so the ring over the bar's start hides nothing and no cap is needed
profile.dots.position = "health"
ns.UFRing = { Applies = function() return true end, Side = function() return "LEFT" end, TextPad = function() return 13 end }
frame.Health:SetWidth(192)
D:Refresh()
bars = gauges()
local fill = frame.Health:GetStatusBarTexture()
assert(#bars == 2 and bars[1].value == 222 and bars[2].value == 382)
assert(select(2, bars[1]:GetPoint(1)) == fill and bars[1]:GetWidth() == 192, "on the health's end, the bar's length")
assert(not cap:IsShown(), "nothing drawn over the ring")
ns.UFRing = nil
profile.dots.position = "start"
D:Refresh()
assert(select(2, gauges()[1]:GetPoint(1)) ~= fill)

-- One Colour: a single piece for the lot
profile.dots.colors = "single"
D:Refresh()
bars = gauges()
assert(#bars == 1 and bars[1].value == 382)
-- the target frame switched off in the settings: nothing there
profile.dots.target = false
D:Refresh()
assert(#gauges() == 0)
profile.dots.target, profile.dots.colors = true, "each"

-- the same mob's nameplate: the mark there too, and gone with Nameplates > Off
local function plateGauges()
    local n = 0
    for _, w in ipairs(ui.widgets) do
        local holder = w:GetParent()
        if w.kind == "StatusBar" and holder and holder:GetParent() == plate and w.width ~= 10000 and w:IsVisible() and w.value then n = n + 1 end
    end
    return n
end
guids.nameplate1 = guids.target
ui:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
D:Refresh()
assert(plateGauges() == 2, "a piece per DoT on the plate")
profile.dots.plates = "off"
D:Refresh()
assert(plateGauges() == 0)
profile.dots.plates = "icon"

-- the fight is noted in the character's saved log, to be read back after a /reload
D.Note()
local noted = table.concat(char.dots.log, "\n")
assert(noted:find("CAST Corruption", 1, true) and noted:find("ESTIMATE target 382 from 2 DoT(s): Corruption 222, Immolate 160", 1, true), noted)

-- /fui dots says what the tracker sees; a drawing that fails is named there and the others go on
local said = {}
env.print = function(text) said[#said + 1] = text end
D.Report()
assert(#said >= 5 and table.concat(said, "\n"):find("target: exists true, shown in settings true, DoTs 2, damage 382", 1, true))
D.API.RegisterCallback("broken", function() error("boom") end)
D:Refresh()
assert(plateGauges() == 2 and D.errors.broken:find("boom"), "the plates still draw")
D.API.RegisterCallback("broken", function() end)

-- Reset Learned Ticks, and a new target: its DoTs are its own
D:ResetLearned()
guids.target = "Creature-0-1-1-1-100-0000000002"
ui:emit("PLAYER_TARGET_CHANGED")
assert(select(2, D.API.GetRemainingDamage("target")) == 0)

-- A finisher's tick size is learned per combo point count. A count not learned yet borrows the ratio of the nearest
-- learned one to its tooltip, not the bare tooltip (which leaves out attack power: about 1.7x in game).
local function rip(points, cast)
    combo = points
    ui:emit("UNIT_SPELLCAST_SENT", "player", "Defias Thug", cast, 9493)
    ui:emit("UNIT_SPELLCAST_SUCCEEDED", "player", cast, 9493)
    return (D.API.GetRemainingDamage("target"))
end
guids.target = "Creature-0-1-1-1-100-0000000003"
ui:emit("PLAYER_TARGET_CHANGED")
assert(rip(3, "Cast-10") == 237, "nothing learned: the tooltip's 237 at 3 points")
char.dots.ticks["9493x4"] = 88                       -- learned at 4 points: 88 a tick against the tooltip's 50
guids.target = "Creature-0-1-1-1-100-0000000004"
ui:emit("PLAYER_TARGET_CHANGED")
local borrowed = rip(3, "Cast-11")
assert(borrowed == 417, "3 points: 39.5 a tick x 1.76 = 69.5, six ticks: " .. tostring(borrowed))
guids.target = "Creature-0-1-1-1-100-0000000005"
ui:emit("PLAYER_TARGET_CHANGED")
assert(rip(4, "Cast-12") == 528, "its own learned size where there is one")
print("PASS: dot-tracker")
