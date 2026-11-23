-- Exercise the Nameplates settings in the real panel while recording module and CVar effects.
local setup = dofile("tools/tests/fixtures/settings-addon.lua")
local ui, ns = setup()
local E, S = ui.env, ns.Settings
local db = { enabled = true, types = {}, smoothBars = true }
ns.db.profile.nameplates = db
ns.defaults.profile.nameplates = { noTargetScale = 1, targetScale = 1.2, notTargetScale = 0.9, targetAlpha = 1 }
local game = { nameplateShowEnemies = "1", nameplateOccludedAlphaMult = "0.37" }
local function setCVar(key, value) game[key] = tostring(value) end
E.SetCVar = setCVar
E.GetCVarBool = function(key) return game[key] == "1" end
local mask = 0
E.C_CVar = {
    GetCVar = function(key) return game[key] end,
    GetCVarBitfield = function(_, index) return math.floor(mask / 2 ^ (index - 1)) % 2 == 1 end,
}
E.CVarCallbackRegistry = {
    SetCVarBitfieldMask = function(_, key, value) assert(key == "nameplateStackingTypes"); mask = value end,
}
local friendly, held = "000", {}
ns.Tweaks = {
    Refresh = function() end,
    FriendlyHeld = function() return held.combatFriendly end,
    FriendlyPicks = function() return friendly end,
    SetFriendlyPicks = function(value) friendly = value end,
    ForcedCVars = function() return held end,
}
ns.CastGlowOn = function(value) return value ~= false end
ns.CastGlowDefault = function() return true end
ns.UnitFrames = { Kit = { BuildTextureValues = function()
    return function() return { { value = "FlareUI Flat", text = "Flat" }, { isDivider = true }, { value = "Custom", text = "Custom" } } end
end } }
local defaults = { width = 100, height = 20, plate = "bar", level = "box", levelSide = "left", castbar = true,
    castImportant = true, castTargetedFlash = true, kickReady = true, threat = "off", execute = "off", buffs = "all", debuffs = "all",
    groupColor = true, combo = true, auraTimer = "below", targetArrows = "off", nameOnlySize = 100, nameOnlyFull = true }
local types = {}
for key in pairs(defaults) do types[key] = true end
for _, key in ipairs({ "auraRows", "auraTimerColor", "texture", "colorBoss", "border" }) do types[key] = true end

local NP = { C = {
    TYPE_KEYS = types, DEFAULT_PRESET = { enemyNpc = "full", friendlyPlayer = "compact" },
    ARROW_ORDER = { "arrow" }, ARROWS = { arrow = { "TestArrow", "left", "Arrow" } }, ARROW_ANGLE = { left = 1.5 },
} }
ns.Nameplates = NP
function NP.TypeStore(kind)
    db.types[kind] = db.types[kind] or {}
    return db.types[kind]
end
function NP.PresetOf(kind) return NP.TypeStore(kind).preset or NP.C.DEFAULT_PRESET[kind] or "full" end
function NP.SetPreset(kind, preset)
    local own = NP.TypeStore(kind)
    own.preset = preset
    if preset ~= "custom" then own.custom = nil end
end
function NP.TypeSet(kind, key, value)
    local own = NP.TypeStore(kind)
    own.custom = own.custom or {}
    own.preset = "custom"
    own.custom[key] = value
end
function NP.TypeDB(kind)
    local own = NP.TypeStore(kind)
    local values = E.CopyTable(defaults)
    if own.preset == "name" then values.plate = "name" end
    for key, value in pairs(own.custom or {}) do values[key] = value end
    return values
end
function NP.PresetValue(_, key) return defaults[key] end
function NP.SameValue(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for key, value in pairs(a) do if not NP.SameValue(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
function NP.TextSlots(data) return data.barText and data.barText.health or { left = {}, middle = {}, right = {} } end
function NP.NameAbovePick(data) return data.nameAbove end
-- A pending profile can enable quest marks while the active plates still have them off.
local previewQuest
function NP.Refresh() previewQuest = S:GetPath("tweaks.nameplateQuest") end
function NP.QuestOn(preview) return preview and previewQuest or false end
function NP.CreateSample(parent) return E.CreateFrame("Frame", nil, parent) end
function NP.DrawSample(frame, states) frame.states = states; return 150, 60 end
function NP.SampleHit(frame) frame.hits = (frame.hits or 0) + 1 end
function NP.TestMode(active, kind, full) NP.testing, NP.testedKind, NP.fullTest = active, kind, full end

ui:load("Modules/BarText.lua", ns)
S:Module{ key = "about", group = "top" }
ui:load("Settings/Pages/Nameplates.lua", ns)
ui:load("Settings/PadNav.lua", ns)
ui:load("Settings/Panel.lua", ns)
local P = ns.SettingsPanel
P:Open("np")
-- (11-23, #165) the tab row in two labelled groups
local function label(text) return ui:find(function(w) return w.GetText and w:GetText() == text and w:IsShown() end) end
assert(label("This Unit Type") and label("All Nameplates"), "the two tab group labels")
local function row(key) return assert(S.rows["np." .. key], key) end
local function set(key, value) row(key):Set(value) end
local function widgetFor(key)
    return assert(ui:find(function(w) return w.row == row(key) and w:IsVisible() end), key)
end
local side = assert(ui:find(function(w) return w.unitGroup ~= nil end))
assert(side:IsVisible() and side.sample.kind == "enemyNpc" and side.sample.states.cast and side.sample.states.important)
assert(not side.sample.states.threat and not side.undo:IsEnabled() and not side.reset:IsEnabled())
side:RunScript("OnUpdate", 2)
assert(side.sample.hits == 1, "bar effects animate the preview through the module")
local barText = row("barText")
local dropdown = widgetFor("barText").control
local entries = dropdown:OpenMenu().entries
assert(#entries == 3 and entries[1].text == "Left")
entries[1].entries[4].pick()
dropdown:CloseMenu()
assert(barText.slotTicked("left", "fullname") and barText:Get() == "left=fullname;middle=;right=")
barText:Set(barText.slotToggle("left", "percent"))
barText:Set(barText.slotToggle("left", "max"))
assert(barText:Get() == "left=percent,max;middle=;right=" and barText.slotPlace("left", "max") == 2,
    "number choices replace the name and retain tick order")
barText:Set(barText.slotToggle("left", "percent"))
assert(barText:Get() == "left=max;middle=;right=" and barText.slotPlace("left", "max") == nil)

set("level", "discRight")
assert(row("level"):Get() == "discRight" and NP.TypeDB("enemyNpc").levelSide == "right")
set("nameAbove", "right:fullname")
assert(row("nameAbove"):Get() == "right:fullname")
set("nameOnlyMode", true)
assert(row("width"):IsDisabled() and not row("nameOnlySize"):IsDisabled())
set("combatPlates", "enemyNpc")
assert(not row("width"):IsDisabled() and row("combatPlates"):Get() == "enemyNpc")
assert(side.reset:IsEnabled() and side.undo:IsEnabled() and NP.PresetOf("enemyNpc") == "custom")
side.reset:Click()
assert(row("level"):Get() == "boxLeft" and not side.reset:IsEnabled())

local presets = side.presetDrop:OpenMenu().entries
assert(presets[1].selected() and presets[4].text == "Name Only")
presets[4].pick()
assert(row("nameOnlyMode"):Get() and side.undo:IsEnabled())
side.undo:Click()
assert(NP.PresetOf("enemyNpc") == "full" and not side.undo:IsEnabled())

P:Open("np", "extras")
assert(not row("questMarks"):IsHidden() and row("mobTypesWhere"):IsDisabled())
widgetFor("questMarks").control:Click()
widgetFor("questMarks"):RunScript("OnLeave")
assert(row("questMarks"):Get() and side.sample.states.quest and not side.sample.states.combo,
    "toggling Objective Icon refreshes the selected profile in the pinned preview")
set("comboPoints", true)
set("mobTypes", "boss,caster")
assert(not row("mobTypesWhere"):IsDisabled() and row("mobTypes"):Get() == "boss,caster")
assert(row("questProgress"):Get() and side.sample.states.quest and side.sample.states.combo)
widgetFor("threat"):RunScript("OnEnter")
assert(side.sample.states.threat and side.sample.states.target == false, "the Threat row previews a non-target threat plate")
ns.NameplatesPinned.Hover(nil)
assert(not side.sample.states.threat and side.sample.states.target)
-- (11-23, #164) Show Full Name only for player types
assert(row("nameOnlyFull"):IsHidden(), "an NPC type has no full name")
-- (11-23) the new rows: guild colour only for Friendly Player, titles on for NPC types, the cast bar's
-- own texture and border with their defaults, class-coloured names off
assert(row("guildColor"):IsHidden() and not row("showTitles"):IsHidden() and row("showTitles"):Get() == true)
assert(not row("nameClassColor"):Get())
assert(row("castTexture"):Get() == "FlareUI Dark" and row("castBorder"):Get() == "FlareUI Frames")
assert(row("mouseoverHighlight"):Get() == "border,bar", "Mouseover Highlight starts on Border and Bar")
side.unitGroup.cells[1]:Click()
assert(side.sample.kind == "enemyPlayer" and row("questMarks"):IsHidden()
    and NP.TypeDB("enemyPlayer").colorBoss ~= true)
assert(not row("nameOnlyFull"):IsHidden(), "a player type shows Show Full Name")
assert(row("showTitles"):Get() == false, "players start without titles")
side.unitGroup.cells[2]:Click()

P:Open("np", "targeting")
assert(S.modules.np.subtitle("targeting") == "Overall options for all plates")
set("plateState", "target")
set("stateScale", 1.35)
set("stateAlpha", 0.6)
set("plateState", "other")
set("stateScale", 0.75)
assert(db.targetScale == 1.35 and db.targetAlpha == 0.6 and db.notTargetScale == 0.75)
assert(row("obscuredAlpha"):Get() == 0.35, "the unsaved slider follows the client's 5% step")
set("obscuredAlpha", 0.65)
assert(db.obscuredAlpha == 0.65 and game.nameplateOccludedAlphaMult == "0.37")
assert(row("targetArrows"):Choices()[2].icon[2] == -1.5)

P:Open("np", "cast")
set("castbar", false)
assert(row("castHeight"):IsDisabled() and side.sample.states.cast, "the last edited row still explains the cast bar")
ns.NameplatesPinned.Hover(nil)
assert(not side.sample.states.cast, "clearing the row preview restores the selected type's states")
P:Open("np", "auras")
set("buffs", "off")
assert(row("auraRows"):IsHidden() and row("buffSize"):IsDisabled())
set("buffs", "all")
assert(not row("auraRows"):IsHidden())

P:Open("np", "visibility")
set("enemyShow", "combat")
assert(row("enemyShow"):Get() == "combat" and db.enabled)
set("enemyShow", "off")
assert(row("enemyShow"):Get() == "off" and game.nameplateShowEnemies == "0")
set("enemyTypes", "players,minions")
assert(row("enemyTypes"):Get() == "players,minions" and db.enemyNpcs == false)
set("friendlyShow", "always")
assert(friendly == "100" and row("friendlyShow"):Get() == "always")
set("friendlyTypes", "players,minions")
assert(friendly == "101" and row("friendlyTypes"):Get() == "players,minions")
held.combatFriendly = friendly
set("friendlyShow", "combat")
set("friendlyTypes", "npcs")
assert(held.combatFriendly == "010" and friendly == "101" and row("friendlyShow"):Get() == "combat")
set("stacking", "enemy,friendly")
assert(mask == 3 and row("stacking"):Get() == "enemy,friendly")
set("npcNames", "interactive")
assert(row("npcNames"):Get() == "interactive" and game.UnitNameNPC == "0" and game.ShowQuestUnitCircles == "1")
set("playerNames", "own,enemy")
assert(row("playerNames"):Get() == "own,enemy" and game.UnitNameOwn == "1")
ui.combat = true
set("npcNames", "all")
set("enemyShow", "always")
assert(row("npcNames"):IsDisabled() and row("npcNames"):Get() == "interactive" and game.nameplateShowEnemies == "0")
ui.combat = false
side.test:Click()
assert(NP.testing and NP.testedKind == "enemyNpc" and NP.fullTest and not P:IsShown())
local lastDraw = side.sample.states
ui:flushTimers()
assert(side.sample.states == lastDraw, "a queued panel redraw skips the preview while testing in game")
local stop = assert(ui:find(function(w) return w:IsObjectType("Button") and w:GetText() == "Stop Testing" and w:IsVisible() end))
stop:Click()
assert(not NP.testing and P:IsShown() and side.undo:IsEnabled(), "ending the live test keeps the original undo snapshot")

print("PASS: nameplate presets, preview states, text slots and game visibility settings")
