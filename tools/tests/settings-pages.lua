-- Settings page callbacks bridge saved settings, game CVars and running modules.
local setup = dofile("tools/tests/fixtures/settings-addon.lua")
local ui, ns = setup()
local E, S = ui.env, ns.Settings
local calls, cvars, bits = {}, { combinedBags = "1", WorldTextScale = "1" }, {}
local function record(name) return function() calls[name] = (calls[name] or 0) + 1 end end
local function getCVar(key) return cvars[key] end
local function getBool(key) return cvars[key] == "1" end
local function setCVar(key, value) cvars[key] = tostring(value) end
E.GetCVar, E.GetCVarBool, E.SetCVar = getCVar, getBool, setCVar
E.C_CVar = { GetCVar = getCVar, GetCVarBool = getBool, SetCVar = setCVar,
    GetCVarInfo = getCVar, GetCVarBitfield = function(_, index) return bits[index] end,
    SetCVarBitfield = function(_, index, value) bits[index] = value end }
local fonts = {}
ns.UnitFrames = {
    FontElements = function(unit) return unit == "player" and { "names", "auras", "level" } or { "names" } end,
    FontDb = function(unit, element)
        fonts[unit] = fonts[unit] or {}
        fonts[unit][element] = fonts[unit][element] or { face = "Custom", size = 12 }
        return fonts[unit][element]
    end,
    Refresh = record("unit"),
}
ns.ResourceBars = { SetTimerBars = record("timers") }
ns.UFFontDefault = function() return { face = "Custom", size = 12, enableShadow = false } end
ns.Bags = {
    GetOtherBagAddon = function() return ui.otherBag end,
    IsCombined = function() return getBool("combinedBags") end,
    View = function() return S:GetPath("tweaks.bagView") or "all" end,
    Refresh = record("bags"), Filter = { Refresh = record("bag filter") },
}
ns.Chat = { RefreshAll = record("chat"), GetOtherChatAddon = function() return ui.otherChat end, GetClashingChatAddon = function() return ui.clash end,
    EditBoxBorder = function(db) return db.editBoxBorder or "thick" end }
ns.Tweaks = {
    CameraDefault = function(name) return name == "cameraZoomSpeed" and 20 or 1.9 end,
    Refresh = record("tweaks"), UIScale = { Remember = record("scale") },
}
ns.Minimap = { Refresh = record("map"), PlaceAllButtons = record("buttons"), LoadedScanners = function() return { "Scanner" } end }
local inDrawer = "none"
ns.MinimapBag = {
    AddonChoices = function() return { { "A", "Addon A" }, { "B", "Addon B" } } end,
    SetInDrawer = function(value) inDrawer = value == "" and "none" or value end,
    InDrawer = function() return inDrawer end,
}
local mouseAll, mouseKinds
ns.Tooltips = {
    Mouseover = function(kind) return mouseAll or mouseKinds and mouseKinds[kind] end,
    SetMouseover = function(value) mouseAll, mouseKinds = value, {} end,
    SetKindMouseover = function(kind, value) mouseKinds[kind] = value end,
    Refresh = record("tips"),
}
ns.DamageMeter = { Refresh = record("meter"), ApplyVisibility = record("meter visibility"), PlaceThreatWindow = record("threat placement") }
ns.BuffReminders = {
    Update = record("reminders"), ExtraKeys = function() return {} end,
    ElixirKeys = function() return {} end, ExtraChoices = function() return {} end, ElixirChoices = function() return {} end,
}
ns.OtherControllerAddon = function() return ui.otherController end
local hiddenAuras, shownAuras = { [101] = "target" }, { [102] = "party" }
ns.HiddenAuras = {
    PLACES = { "auras", "target", "party" }, stamp = 0,
    Saved = function(list) return list == "shown" and shownAuras or hiddenAuras end,
    ListOf = function(id) return hiddenAuras[id] and "hidden" or shownAuras[id] and "shown" end,
    Changed = function() ns.HiddenAuras.stamp = ns.HiddenAuras.stamp + 1 end,
    Add = function(id) hiddenAuras[id] = ""; ns.HiddenAuras.Changed() end,
}
E.C_Spell = { GetSpellName = function(id) return ({ [101] = "Shield", [102] = "Blessing", [103] = "Renew" })[id] end,
    GetSpellTexture = function(id) return id + 1000 end, IsSpellHarmful = function() return false end }
E.C_UnitAuras = { GetAuraDataByIndex = function(_, index, filter) if index == 1 and filter == "HELPFUL" then return { spellId = 103 } end end,
    GetPlayerAuraBySpellID = function() return nil end }
E.C_Secrets = { GetSpellAuraSecrecy = function() return 0 end }
E.canaccessvalue = function() return true end
for _, file in ipairs({
    "About", "ActionBars", "CooldownManager", "UnitFrames", "ResourceBars", "Nameplates", "Chat", "DamageMeter",
    "Tooltips", "Auras", "BuffReminders", "Minimap", "QuestTracker", "RadialMenu", "QualityOfLife", "BagsLooting", "Advanced", "Language",
}) do
    ui:load("Settings/Pages/" .. file .. ".lua", ns)
end
for _, module in pairs(S.modules) do
    if module.enabled then S:SetPath(module.enabled, true) end
end

local function row(key) return assert(S.rows[key], key) end
local function setting(path) return S:GetPath(path) end
local function set(key, value) row(key):Set(value) end

assert(S:Groups()[1].modules[1].key == "about" and S:Groups()[2].modules[1].key == "np")
assert(#S:Search("transparency") > 0 and #S:Search("!nothing-to-match") == 0)
assert(row("ch.editBoxBorder"):Get() == "thick")
set("ch.editBoxStyle", "flareui")
assert(row("ch.editBoxBorder"):IsHidden())
set("ch.headerButtons", "channels,volume")
assert(row("ch.headerButtons"):Get() == "channels,volume" and setting("chat.socialHide") and not setting("chat.channelHide"))
set("ch.icons", "raceIcons,classIcons")
assert(row("ch.icons"):Get() == "raceIcons,classIcons" and setting("chat.linkIcons") == false)
set("ch.channelNames", "short")
assert(row("ch.channelNames"):Get() == "short" and setting("chat.shortChannels"))
ui.otherChat = "Prat"
assert(S.modules.ch.banner():find("Prat", 1, true) and calls.chat == 4)
ui.otherChat, ui.clash = nil, "Chatter"
assert(S.modules.ch.banner():find("Chatter changes the chat too", 1, true))
ui.clash = nil
assert(S.modules.ch.banner() == nil)
ui.otherChat = "Prat"

local pending = S:PendingCount()
assert(row("ab.xpBar"):Get() == "split")
set("ab.xpBar", "off")
assert(row("ab.xpText"):IsDisabled() and S:PendingCount() == pending + 1)
set("ab.xpBar", "double")
assert(row("ab.xpBar"):Get() == "double" and S:PendingCount() == pending)
S:SetPath("actionbars.xpbar.bubbles", true)
assert(row("ab.xpBubbles"):Get() == "20", "old separator switch reads as 20")
set("ab.xpBubbles", "10")
assert(row("ab.xpBubbles"):Get() == "10" and setting("actionbars.xpbar.bubbles") == 10)
set("ab.xpQuest", "zone")
assert(row("ab.xpQuest"):Get() == "zone" and setting("actionbars.xpbar.questXP"))
set("ab.hideKeybinds", false)
assert(setting("actionbars.hideHotkeys") == true and row("ab.hideKeybinds"):Get() == false)

assert(not row("bl.bagColumns"):IsDisabled() and row("bl.combinedNote"):IsHidden())
set("bl.bagCombined", false)
assert(row("bl.bagColumns"):IsDisabled() and not row("bl.bankColumns"):IsDisabled())
assert(not row("bl.combinedNote"):IsHidden())
ui.otherBag = "Bagnon"
assert(row("bl.bankColumns"):IsDisabled() and row("bl.bagAddonNote").textFn():find("Bagnon", 1, true))
assert(not row("bl.bankAddonNote"):IsHidden() and row("bl.bankAddonNote").textFn():find("Bagnon", 1, true))
assert(row("bl.bankColumns").tab == "bank" and row("qol.repair").tab == "bank" and row("bl.delete").tab == "bags")
ui.otherBag = nil
set("bl.bagView", "rowsSets")
assert(row("bl.bagView"):Get() == "rowsSets" and calls["bag filter"] == 1)
set("bl.bagSkinSlots", "thick,rarity")
assert(row("bl.bagSkinSlots"):Get() == "thick,rarity" and setting("tweaks.bagThickBorders") and setting("tweaks.bagRarity"))
set("bl.bagSkinSlots", "off")
assert(row("bl.bagSkinSlots"):Get() == "off" and setting("tweaks.bagSkinSlots") == false)
set("bl.lootFeed", "round")
assert(row("bl.lootFeed"):Get() == "round" and not row("bl.lootFeedQuality"):IsDisabled())
set("bl.lootFeed", "off")
assert(row("bl.lootFeedQuality"):IsDisabled() and setting("tweaks.lootFeedIcons") == "round")

assert(row("qol.cameraMaxZoom"):Get() == 1.9)
set("qol.cameraMaxZoom", 2.4)
assert(setting("tweaks.cameraMaxZoom") == 2.4)
set("qol.cameraMaxZoom", 1.9)
assert(setting("tweaks.cameraMaxZoom") == nil and row("qol.cameraMaxZoom"):Get() == 1.9)
-- (11-23: the flight list took Coordinates on the World Map's place)
assert(S.rows["qol.mapCoords"] == nil)
set("qol.flightDestinations", true)
assert(setting("tweaks.flightDestinations") == true and row("qol.flightDestinations"):Get())
set("qol.gryphons", "behind")
assert(row("qol.gryphons"):Get() == "behind" and not setting("visibility.hideEndCaps"))
set("qol.gryphons", "hidden")
assert(row("qol.gryphons"):Get() == "hidden" and not setting("actionbars.gryphonsBehind"))

set("mm.style", "round")
assert(row("mm.squareBorder"):IsHidden() and row("mm.barLeft"):IsDisabled() and not row("mm.barCenter"):IsDisabled())
set("mm.style", "square")
set("mm.squareBorder", "header")
assert(row("mm.squareBorder"):Get() == "header" and setting("minimap.squareHeader") == "art" and calls.buttons == 1)
set("mm.squareBorder", "thick")
assert(row("mm.squareBorder"):Get() == "thick" and setting("minimap.squareHeader") == "headerless")
set("mm.icons", "vehicleExit,durability")
assert(row("mm.icons"):Get() == "vehicleExit,durability" and row("mm.drawerStyle"):Get() == "blizzard")
assert(#row("mm.drawerStyle"):Choices() == 2 and row("mm.bagAddons"):Choices()[3].value == "A")
set("mm.bagAddons", "B")
assert(row("mm.bagAddons"):Get() == "B" and not row("mm.nodeScanNote"):IsHidden())

assert(row("tt.cursorX"):IsDisabled())
set("tt.mouseover", "world,auras")
assert(row("tt.mouseover"):Get() == "world,auras" and not row("tt.cursorX"):IsDisabled())
set("tt.mouseover", "all")
assert(row("tt.mouseover"):Get() == "all" and ns.Tooltips.Mouseover("other"))
set("tt.showWorld", "combat")
assert(setting("tooltips.visibility.worldUnits") == "combat" and setting("tooltips.visibility.worldObjects") == "combat")
set("tt.ids", true)
assert(setting("tooltips.showItemID") and setting("tooltips.showSpellID"))
set("tt.healthBar", "inside")
set("tt.healthBar", "off")
assert(row("tt.healthBar"):Get() == "off" and setting("tooltips.healthBarPlace") == "inside")
ui.gamepad = true
assert(row("tt.mouseover"):IsDisabled() and row("au.shape"):IsDisabled())
ui.gamepad = false

local _, _, enableMeter = S.modules.dm.banner()
assert(enableMeter and not getBool("damageMeterEnabled"))
enableMeter()
assert(getBool("damageMeterEnabled") and calls.meter == 1)
set("dm.chatTab", "group,login")
assert(row("dm.chatTab"):Get() == "group,login" and row("dm.matchChat"):IsDisabled() and calls["meter visibility"] == 1)
set("dm.threatMode", "window")
assert(calls["threat placement"] == 1 and row("dm.threatMode"):Get() == "window" and not setting("damagemeter.autoThreat"))
set("dm.threatMode", "combat")
assert(row("dm.threatMode"):Get() == "combat" and not setting("damagemeter.threatWindow"))

set("qt.autoMinimize", "instances,taxi")
assert(row("qt.autoMinimize"):Get() == "instances,taxi" and setting("objectivetracker.autoMinimize.raid") == "minimize"
    and setting("objectivetracker.autoMinimize.combat") == "none")
set("br.upkeepPick", "camping,durability")
assert(row("br.upkeepPick"):Get() == "durability,camping" and setting("auras.reminder.gathering") == false)
set("br.consumables", true)
assert(row("br.consumables"):Get() and setting("auras.reminder.consumables") == "instance")
set("br.elixirSource", "bags")
assert(row("br.elixirs"):IsDisabled() and calls.reminders == 3)
local owned = row("au.hidePick"):Choices()
assert(#owned == 3 and owned[2].divider and owned[3].value == 103)
row("au.hidePick"):Set(103)
assert(hiddenAuras[103] == "" and #row("au.hidePick"):Choices() == 1)
assert(row("au.1.filterOn"):Label():find("Blessing", 1, true) and #row("au.1.filterOn"):Choices() == 4)
row("au.1.filterOn"):Set("target")
assert(shownAuras[102] == "target" and hiddenAuras[101] == "target")

set("uf.main", true)
assert(row("uf.main"):Get() and setting("unitframes.units.focus.enabled") and setting("unitframes.units.pet.enabled"))
set("rb.timer", true)
assert(row("rb.timer"):Get() and calls.timers == 1)
assert(row("uf.font.target_names").pageHidden())
row("uf.font.target_names").beforeJump()
assert(not row("uf.font.target_names").pageHidden() and row("uf.font.player_names").pageHidden())
ns.UnitFrames.FontDb("target", "names").size = 17
set("uf.fontCopyAll", true)
local copy = ui.dialogs[#ui.dialogs]
assert(copy.key == "FLAREUI_UF_FONT_COPYALL" and copy.data.frame == "target")
ns.Dialogs[copy.key].OnAccept(copy.data)
assert(ns.UnitFrames.FontDb("player", "names").size == 17 and ns.UnitFrames.FontDb("player", "auras").size == 12)
local shadow = row("uf.font.player_auras.shadow")
shadow:Set("strong")
assert(shadow:Get() == "strong" and ns.UnitFrames.FontDb("player", "auras").shadowY == -2 and S:AnyFontChanged())
S:ResetAllFonts()
assert(shadow:Get() == "none" and not S:AnyFontChanged(), "reset restores path and per-frame font defaults")

assert(row("language.override"):IsDisabled())
set("language.useGame", false)
set("language.override", "frFR")
assert(not row("language.override"):IsDisabled() and ns.db.global.language == "frFR" and S.pending.language)
set("language.useGame", true)
assert(not S.pending.language, "returning to the game's language clears the reload")
set("qol.move", true)
assert(setting("tweaks.moveAnyFrame") and setting("tweaks.moveLootToasts"))
set("qol.uiScale", "custom")
assert(row("qol.uiScale"):Get() == "custom" and calls.scale == 1)
set("fonts.combatSize", 130)
assert(cvars.WorldTextScale == "1.3" and row("fonts.combatSize"):Get() == 130)

set("rm.names", "always")
assert(row("rm.names"):Get() == "always" and setting("radialmenu.showNames"))
set("rm.spellRank", "both")
assert(setting("radialmenu.spellRank") == "both" and row("rm.spellRank"):Get() == "both")
set("rm.names", "off")
assert(row("rm.names"):Get() == "off" and not setting("radialmenu.showNames"))
ui.otherController = "ConsolePort"
assert(row("rm.pad"):IsDisabled())

-- (11-24) Blizzard's Cooldown Manager switch: refused in a fight, kept from a character, or not kept by the game
do
    local errors, logged, access = {}, {}, nil
    E.UIErrorsFrame, E.ERR_NOT_IN_COMBAT = { AddMessage = function(_, text) errors[#errors + 1] = text end }, "Not in combat"
    E.C_CooldownViewer = { IsCooldownViewerAvailable = function() return access == nil, access end }
    local log, cm = ns.LogError, ns.CooldownManager
    ns.LogError = function(where, err) logged[#logged + 1] = where .. ": " .. err end
    ns.CooldownManager = { BlizzardOn = function() return getBool("cooldownViewerEnabled") end }
    cvars.cooldownViewerEnabled = "0"
    ui.combat = true
    set("cdm.blizzard", true)
    ui:flushTimers()
    assert(cvars.cooldownViewerEnabled == "0" and errors[1] == "Not in combat" and #logged == 0)
    ui.combat = false
    set("cdm.blizzard", true)
    ui:flushTimers()
    assert(row("cdm.blizzard"):Get() == true and #errors == 1 and #logged == 0)
    set("cdm.blizzard", false)
    access = "Available at level 10"
    set("cdm.blizzard", true)
    ui:flushTimers()
    assert(errors[2] == "Available at level 10" and #logged == 0)
    access = nil
    cvars.cooldownViewerEnabled = "0"
    E.SetCVar = function() end
    set("cdm.blizzard", true)
    ui:flushTimers()
    assert(#logged == 1 and logged[1] == "Cooldown Manager switch: stayed off")
    E.SetCVar, ns.LogError, ns.CooldownManager = setCVar, log, cm
end

print("PASS: settings pages preserve saved values, dependencies and live callbacks")
