-- Exercise the same saved-variable and event sequence as FlareUI.toc.
local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local guid = "Player-1"
local messages, dialogs, errors = {}, {}, {}
function env.print(text) messages[#messages + 1] = text end
env.DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) env.print(text) end }
env.C_AddOns = { GetAddOnMetadata = function() return "7.0.4" end }
env.SlashCmdList = {}
env.GetLocale = function() return "enUS" end
env.GetBuildInfo = function() return "1.16", "12345" end
env.GetCurrentRegion = function() return 1 end
env.GetCurrentRegionName = function() return "US" end
env.GetRealmName = function() return "Forever" end
env.UnitFactionGroup = function() return "Alliance" end
env.UnitNameUnmodified = function() return "Alba" end
env.UnitClass = function() return "Mage", "MAGE" end
env.UnitRace = function() return "Human", "Human" end
env.strlenutf8 = string.len
env.UnitLevel = function() return 34 end
env.UnitGUID = function() return guid end
env.canaccessvalue = function(value) return value ~= "hidden-guid" end
env.securecallfunction = function(callback, ...) return callback(...) end
env.date = function() return "2026-01-01 12:00" end
env.geterrorhandler = function() return function(err) errors[#errors + 1] = err end end

local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    LoadedLocale = function() return "frFR" end,
    GameFonts = { OnLoad = function() error("font load failed") end },
    ShowDialog = function(key, _, data) dialogs[#dialogs + 1] = { key = key, data = data } end,
}
local function load(path)
    ui:load(path, ns)
end

load("LoadCheck.lua")
load("Libs/LibStub/LibStub.lua")
load("Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua")
load("Libs/AceDB-3.0/AceDB-3.0.lua")
env.LibStub:NewLibrary("FlareEditMode", 1).IsInEditMode = function() return false end

load("Core.lua")
local oldLayout = { point = "CENTER", x = 10, y = -4 }
local old = {
    global = { characters = { ["Player-1"] = { profileName = "Imported" } }, uiSync = { value = 12 }, junk = true },
    profileKeys = { ["Alba - Forever"] = "Default" },
    profiles = {
        Default = {},
        Imported = {
            chat = { enabled = true, opacity = "wrong type", autoHideEnabled = true, showOnCombat = true,
                fadeOutSpeed = 0.2, autoHideDelay = 12 },
            unitframes = { enabled = true, units = { player = { width = 150 } }, fontPower = { size = 15, unknown = 3 }, layouts = { Home = { player = oldLayout } } },
            minimap = { buttonBag = false },
            fcm = { enabled = false, bars = { bar1 = { enabled = true } } },
            notAnOption = true,
        },
        Another = { chat = { autoHideEnabled = true, fadeOutSpeed = 0.8, autoHideDelay = 28 } },
        Broken = 1,
    },
}
env.FlareUI_DB = old
env.FlareUI2_DB = { global = { useGameLanguage = false, textScale = 1.5, whatsNewSeen = "6.0" } }
load("Import.lua")
load("ProfileLayout.lua")

ui:emit("ADDON_LOADED", "OtherAddon")
assert(ns.db == nil, "The database waits for FlareUI's load event")
ui:emit("ADDON_LOADED", "FlareUI")
local saved = ns.db.sv
local imported = saved.profiles.Imported
assert(saved.imported == "1.x" and saved.profiles.Broken == nil)
assert(saved.global.junk == nil and saved.global.uiSync.value == 12 and saved.global.uiSync ~= old.global.uiSync)
assert(imported.chat.visibility == "combat" and imported.chat.fadeSpeed == "fast" and imported.chat.autoHideDelay == 10)
assert(imported.chat.opacity == nil and imported.unitframes.fontPower.size == 15 and imported.unitframes.fontPower.unknown == nil)
assert(imported.notAnOption == nil and imported.fcm.bars == nil)
assert(imported.unitframes.styleProfiles.usual.units.player.width == 150)
assert(imported.unitframes.layouts.Home.player ~= oldLayout and imported.unitframes.layouts.Home.player.x == 10)
assert(imported.minimap.drawerStyle == "disabled" and imported.minimap.buttonBag == nil)
assert(old.profiles.Imported.minimap.buttonBag == false, "Import should leave the old database intact")
assert(imported.objectivetracker.frameStyle == "flareui")
assert(saved.profiles.Another.chat.visibility == "interactions")
assert(saved.profiles.Another.chat.fadeSpeed == "slow" and saved.profiles.Another.chat.autoHideDelay == 30)
assert(ns.db.global.language == "frFR" and ns.TEXT_SCALE == 1.5)
assert(#errors == 1 and errors[1]:find("font load failed", 1, true))
assert(ns.CastGlowDefault() == false and ns.CastGlowOn(true) and not ns.CastGlowOn(false))

local initialized = {}
local function record(name) return function() initialized[name] = ns.db:GetCurrentProfile() end end
ns.modules.Chat = { Init = record("chat") }
ns.modules.Bags = { ShouldLoad = function() return false end, Init = record("bags") }
ns.modules.Minimap = { ShouldLoad = function() error("check failed") end, Init = record("minimap") }
ns.modules.Nameplates = { Init = record("nameplates") }
ns.modules.Optional = { Init = function() error("start failed") end }
local panelRefreshes = 0
ns.SettingsPanel = { IsShown = function() return true end, Refresh = function() panelRefreshes = panelRefreshes + 1 end }
-- The load check must see this library set before its deferred login callback.
for _, name in ipairs({ "AceEvent-3.0", "AceTimer-3.0", "AceHook-3.0", "LibSharedMedia-3.0" }) do
    env.LibStub:NewLibrary(name, 1)
end
ui:emit("PLAYER_LOGIN")
ui:flushTimers()
assert(initialized.chat == "Imported" and initialized.bags == nil and initialized.minimap == nil and initialized.nameplates == nil)
assert(ns.CharDB().profileName == "Imported" and ns.CharDB().offerLayout)
assert(panelRefreshes == 1 and #dialogs == 0, "Restoring a character's profile refreshes the panel without prompting")
assert(#ns.db.global.errors == 2 and #messages == 2 and env.SlashCmdList.FLAREUI == nil)

local results = { ns.SafeCall("sample", function() return nil, 17 end) }
assert(results[1] and results[2] == nil and results[3] == 17)
for i = 1, 24 do ns.SafeCall("case", function() error("line one\nline two " .. i, 0) end) end
assert(#ns.db.global.errors == 20 and ns.db.global.errors[1]:find("line one line two 5", 1, true))
local logTitle, logText
ns.Perf = { ShowText = function(title, text) logTitle, logText = title, text end }
ns.ErrorsCommand()
assert(logTitle == "FlareUI caught errors" and logText:find("7.0.4 | build 12345 | enUS | MAGE 34", 1, true))
ns.ErrorsCommand("clear")
assert(ns.db.global.errors == nil)
-- what the game refused in FlareUI's name is in the log too (11-23)
env.debugstack = function() return "[C]: in function 'UseAction'\n" .. string.rep("long ", 400) end
ui:emit("ADDON_ACTION_FORBIDDEN", "OtherAddon", "UseAction()")
assert(ns.db.global.errors == nil, "another addon's is its own")
ui:emit("ADDON_ACTION_FORBIDDEN", "FlareUI", "UseAction()")
local blocked = ns.db.global.errors
assert(#blocked == 1 and blocked[1]:find("action forbidden | UseAction(), no fight, keyboard and mouse | [C]: in function", 1, true))
assert(#blocked[1] < 1100 and blocked[1]:find("...", 1, true), "a long stack is cut")
ui:emit("ADDON_ACTION_FORBIDDEN", "FlareUI", "UseAction()")
ui:emit("ADDON_ACTION_FORBIDDEN", "FlareUI", "UseAction()")
assert(#blocked == 1 and blocked[1]:find(" | 3 times", 1, true) and not blocked[1]:find("2 times", 1, true), "once, with a count")
ui.combat = true
ui:emit("ADDON_ACTION_BLOCKED", "FlareUI", "Frame:Hide()")
ui.combat = false
assert(#blocked == 2 and blocked[2]:find("action blocked | Frame:Hide(), in a fight", 1, true))
ui:emit("ADDON_ACTION_BLOCKED", "FlareUI", "hidden-guid")
assert(#blocked == 3 and blocked[3]:find("action blocked | ?, no fight", 1, true), "a value it can't read")
ns.ErrorsCommand("clear")
-- and what in the bag and item-use code isn't Blizzard's own any more
do
    local button = { bagID = 0 }
    local secure = env.issecurevariable
    env.ContainerFrameSettingsManager = { bagSetupDirty = false }
    env.C_Container = env.C_Container or { UseContainerItem = function() end }
    env.ContainerFrameCombinedBags = { EnumerateValidItems = function() return ipairs({ button }) end }
    env._G = env._G or env
    env.issecurevariable = function(t, key)
        if key == "bagSetupDirty" or t == button then return false, "FlareUI" end
        return true
    end
    local text = ns.BlockedLog.Insecure()
    assert(text:find("bagSetupDirty by FlareUI", 1, true), text)
    env.issecurevariable = function() return true end
    assert(ns.BlockedLog.Insecure() == "")
    env.issecurevariable, env.ContainerFrameSettingsManager, env.ContainerFrameCombinedBags = secure, nil, nil
end
-- (11-24) the bank's type, the bags' own flags and the bag menu too
do
    local secure = env.issecurevariable
    local flags, portrait, panel = { [1] = 2 }, {}, {}
    env.ContainerFrameSettingsManager = { filterFlags = flags }
    env.ContainerFrameCombinedBags = { PortraitButton = portrait }
    env.BankFrame = { BankPanel = panel }
    env.issecurevariable = function(t, key)
        if t == flags or t == portrait and key == "menu" or t == panel and key == "bankType" then return false, "FlareUI" end
        return true
    end
    local text = ns.BlockedLog.Insecure()
    for _, name in ipairs({ "bankType", "filterFlags", "ContainerFrameCombinedBags menu" }) do
        assert(text:find(name .. " by FlareUI", 1, true), text)
    end
    env.issecurevariable, env.ContainerFrameSettingsManager, env.ContainerFrameCombinedBags, env.BankFrame = secure, nil, nil, nil
end
-- (11-24) a field is emptied and made Blizzard's again: the mark goes once the table is rebuilt
do
    local secure, writes, marked = env.issecurevariable, 0, true
    local t = setmetatable({}, { __newindex = function(_, key) if key ~= "bankType" then writes = writes + 1 end end })
    rawset(t, "bankType", 1)
    env.issecurevariable = function(target, key)
        assert(target == t and key == "bankType")
        if writes >= 20 and rawget(t, "bankType") == nil then marked = false end
        return not marked
    end
    assert(ns.CleanField(t, "bankType") and rawget(t, "bankType") == nil and writes == 20)
    rawset(t, "bankType", 2)
    assert(ns.CleanField(t, "bankType") and rawget(t, "bankType") == 2, "clean: left alone")
    -- a mark that never goes: gives up; not a table: nothing
    env.issecurevariable = function() return false end
    assert(ns.CleanField({}, "x") == false and ns.CleanField(nil, "x") == false)
    env.issecurevariable = secure
end
-- an error that comes again raises its own line's count, and pushes nothing out
do
    ns.db.global.errors = nil
    for _ = 1, 30 do ns.LogError("Painter", "same thing") end
    ns.LogError("Painter", "other thing")
    local list = ns.db.global.errors
    assert(#list == 2 and list[1]:find("same thing | 30 times", 1, true) and list[2]:find("other thing", 1, true))
    ns.ErrorsCommand("clear")
    ns.LogError("Painter", "same thing")
    assert(#ns.db.global.errors == 1, "written again after a clear")
    ns.db.global.errors = nil
end
-- you as the group's Master Looter: party index 0, or your own raid index
do
    local method, partyID, raidID, grouped, raid = 2, 0, nil, true, false
    local party, inGroup, inRaid, isUnit = env.C_PartyInfo, env.IsInGroup, env.IsInRaid, env.UnitIsUnit
    local enum = env.Enum
    env.Enum = { LootMethod = { Masterlooter = 2 } }
    env.C_PartyInfo = { GetLootMethod = function() return method, partyID, raidID end }
    env.IsInGroup, env.IsInRaid = function() return grouped end, function() return raid end
    env.UnitIsUnit = function(unit) return unit == "raid7" end
    assert(ns.IsMasterLooter())
    partyID = 2
    assert(not ns.IsMasterLooter(), "somebody else")
    partyID, raidID, raid = nil, 7, true
    assert(ns.IsMasterLooter())
    raidID = 8
    assert(not ns.IsMasterLooter())
    method, raidID = 3, 7
    assert(not ns.IsMasterLooter(), "Group Loot")
    method, grouped = 2, false
    assert(not ns.IsMasterLooter())
    env.C_PartyInfo, env.IsInGroup, env.IsInRaid, env.UnitIsUnit, env.Enum = party, inGroup, inRaid, isUnit, enum
end
env.debugstack = nil
ui:emit("ADDON_ACTION_FORBIDDEN", "FlareUI", "UseAction()")
assert(#ns.db.global.errors == 1, "written again after a clear")
ns.db.global.errors = nil
ns.ErrorsCommand()
assert(messages[#messages]:find("No errors caught", 1, true))

local stores = ns.db.profile.unitframes.layouts
assert(ns.HomeLayout() == "Home")
local elsewhere = ns.LayoutHome(stores, "Elsewhere")
assert(elsewhere.player.x == 10 and rawget(elsewhere, "player") == nil)
ns.SetLayoutValue(stores, "Home", "player", 1.5)
ns.SetLayoutValue(stores, "Elsewhere", "focus", 1.2)
assert(ns.LayoutValue(stores, "Elsewhere", "player", 1) == 1, "Scale is local to each layout")
elsewhere.target = { x = 40 }
env.LibStub("FlareEditMode").onAnyMove("Elsewhere")
assert(ns.HomeLayout() == "Elsewhere" and ns.db.profile.homeLayoutPrev == "Home")
assert(ns.LayoutHome(stores, "Elsewhere").player.x == 10, "A moved frame should keep other frames' old spots")
-- (11-24) a third layout keeps every spot the home or an earlier home has, the newest first
local blank = ns.LayoutHome(stores, "Blank")
assert(blank.target.x == 40 and blank.player.x == 10 and blank.nothing == nil and blank.values == nil and next(blank) == nil)
blank.focus = { x = 70 }
elsewhere.focus = { x = 80 }
local move = env.LibStub("FlareEditMode").onAnyMove
move("Blank")
assert(ns.LayoutHome(stores, "Fourth").focus.x == 70 and ns.LayoutHome(stores, "Fourth").target.x == 40
    and ns.LayoutHome(stores, "Fourth").player.x == 10)
assert(ns.LayoutHome(stores, "Blank").target.x == 40 and ns.LayoutHome(stores, "Blank").player.x == 10, "the home itself")
assert(table.concat(ns.db.profile.homeLayoutPast, ",") == "Elsewhere,Home" and ns.db.profile.homeLayoutPrev == "Elsewhere")
move("Elsewhere")
assert(table.concat(ns.db.profile.homeLayoutPast, ",") == "Blank,Home", "each home once")
assert(ns.LayoutHome(stores, "Fourth").focus.x == 80)
elsewhere.focus, stores.Blank, stores.Fourth = nil, nil, nil
-- saved before the list: the one earlier home it kept
ns.db.profile.homeLayoutPast, ns.db.profile.homeLayoutPrev = nil, "Home"
assert(ns.LayoutHome(stores, "Fifth").player.x == 10 and ns.LayoutHome(stores, "Fifth").target.x == 40)
stores.Fifth = nil
ns.UFRing = { ApplyPlateScale = function(settings, value) settings.plateScale = value end }
local plate = { plateScale = 0.9 }
ns.SetLayoutPlateScale(stores, "Elsewhere", "target", plate, 1.4)
assert(plate.plateScaleBase == 0.9 and plate.plateScale == 1.4)
assert(ns.ApplyLayoutPlateScale(stores, "Home", "target", plate) and plate.plateScale == 0.9)
assert(not ns.ApplyLayoutPlateScale(stores, "Home", "target", plate))

env.Enum = { EditModeLayoutType = { Account = 0, Character = 1 } }
env.CreateFrame("Frame", "EditModeManagerFrame", env.UIParent)
env.EditModeManagerFrame.layoutInfo = { activeLayout = 1, layouts = {
    { layoutName = "Modern", layoutType = 0 },
    { layoutName = "Elsewhere", layoutType = 1 },
    { layoutName = "Elsewhere", layoutType = 0 },
} }
ui.combat = true
ui:emit("EDIT_MODE_LAYOUTS_UPDATED")
ui:flushTimers()
assert(ns.CharDB().offerLayout and #dialogs == 0)
ui.combat = false
ui:emit("PLAYER_REGEN_ENABLED")
ui:flushTimers()
local offer = dialogs[#dialogs]
assert(offer.key == "FLAREUI_PROFILE_LAYOUT" and offer.data.index == 3 and not ns.CharDB().offerLayout)
assert(ns.Dialogs[offer.key].macro(offer.data) == "/run C_EditMode.SetActiveLayout(3)\n/reload")
ns.db.profile.homeLayout = "FlareUI Classic"
ns.CharDB().offerLayout = true
local copied = false
ns.EditModeLayout = { Has = function() return true end, Copy = function() copied = true end }
ui:emit("EDIT_MODE_LAYOUTS_UPDATED")
ui:flushTimers()
assert(dialogs[#dialogs].key == "FLAREUI_PROFILE_LAYOUT_MISSING_FLAREUI")
ns.Dialogs.FLAREUI_PROFILE_LAYOUT_MISSING_FLAREUI.OnAccept()
assert(copied)
ns.db.profile.homeLayout = "Missing"
ns.CharDB().offerLayout = true
ui:emit("EDIT_MODE_LAYOUTS_UPDATED")
ui:flushTimers()
assert(dialogs[#dialogs].key == "FLAREUI_PROFILE_LAYOUT_MISSING")

ns.db:SetProfile("Another")
assert(ns.CharDB().profileName == "Another" and ns.CharDB().offerLayout)
assert(dialogs[#dialogs].key == "FLAREUI_RELOAD")
ns.CharDB().forcedCVars = { autoLootDefault = "0" }
ns.db.global.hiddenBubbles = true
ns.db.global.unrelated = true
ns.db.global.nameplateZoomBackup, ns.db.global.uiScaleBack, ns.db.global.padStickKeysRestore = { a = 1 }, { use = "1" }, "1"
ns.reloading = true
ns.Dialogs.FLAREUI_RESET.OnAccept()
assert(ns.db.sv.imported == "1.x" and ns.db.global.hiddenBubbles and ns.db.global.unrelated == nil)
assert(ns.CharDB().forcedCVars.autoLootDefault == "0")
assert(ns.db.global.nameplateZoomBackup.a == 1 and ns.db.global.uiScaleBack.use == "1" and ns.db.global.padStickKeysRestore == "1",
    "what undoes FlareUI's own changes outlives the reset")
guid = "hidden-guid"
assert(ns.PlayerGUID() == nil and ns.CharDB() ~= ns.CharDB())

-- The first TOC file reports an incomplete installation even without any libraries.
load("LoadCheck.lua")
env.LibStub = nil
ui:emit("PLAYER_LOGIN")
ui:flushTimers()
assert(env.SLASH_FLAREUI2 == "/fui" and type(env.SlashCmdList.FLAREUI) == "function")
assert(messages[#messages]:find("Restart the game", 1, true))

-- Invalid pre-2.0 saved data is marked and logged once, so it does not repeatedly interrupt startup.
env.FlareUI2_DB = nil
env.FlareUI_DB = { profiles = true }
ns.ImportOldSettings(ns.defaults)
local failedImport = env.FlareUI2_DB
assert(failedImport.imported:find("^failed:") and #failedImport.global.errors == 1)
ns.ImportOldSettings(ns.defaults)
assert(#failedImport.global.errors == 1)

print("PASS: startup, legacy imports, profile changes, Edit Mode layouts and error handling")
