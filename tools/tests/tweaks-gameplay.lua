local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local texts, opened, loot, confirmations, hidden = {}, {}, {}, {}, {}
local addons = {}
local combatUnits = {}
local guid = "Player-Test"
local cv = {
    cameraDistanceMaxZoomFactor = "1.7", cameraZoomSpeed = "20", mapFade = "0", ActionButtonUseKeyDown = "0",
    showTutorials = "1", showNPETutorials = "0", nameplateShowEnemies = "1",
    nameplateShowFriendlyPlayers = "1", nameplateShowFriendlyNpcs = "0", nameplateShowFriendlyPlayerMinions = "1",
    useUiScale = "0", uiscale = "0.75", Sound_EnableSFX = "1",
}
env.GetCVar = function(key) return cv[key] end
env.GetCVarBool = function(key) return cv[key] == "1" end
env.SetCVar = function(key, value) cv[key] = tostring(value) end
env.C_CVar = {
    GetCVarDefault = function(key) return key == "cameraZoomSpeed" and "20" or nil end,
    GetCVarInfo = function(key) return cv[key], nil, nil, key == "ActionButtonUseKeyDown" end,
}
env.securecallfunction = function(callback, ...) return callback(...) end
env.GetLocale = function() return "enUS" end
env.GetRealmName = function() return "Forever" end
env.UnitName = function() return "Marin", "Reed" end
env.UnitGUID = function() return guid end
env.UnitFactionGroup = function() return "Alliance" end
env.UnitClass = function() return "Hunter", "HUNTER" end
env.UnitIsUnit = function(a, b) return a == b end
env.UnitAffectingCombat = function(unit) return combatUnits[unit] == true end
env.UnitExists = function(unit) return unit == "player" or unit == "pet" end
env.canaccessvalue = function(value) return value ~= "unreadable" end
env.C_AddOns.IsAddOnLoaded = function(name) return addons[name] == true end
env.C_NamePlate = { GetNamePlates = function() return {} end }
env.print = function(text) texts[#texts + 1] = text end
env.ERR_INV_FULL, env.RED_FONT_COLOR = "Inventory is full", env.CreateColor(1, 0, 0)
env.NUM_CHAT_WINDOWS = 1
env.SlashCmdList = {}
env.CameraZoomIn = function(step) return step end
env.CameraZoomOut = env.CameraZoomIn
env.UIErrorsFrame = env.CreateFrame("Frame", nil, env.UIParent)
env.UIErrorsFrame.TryDisplayMessage = function(_, _, text) texts[#texts + 1] = text end
env.ZoneTextFrame = env.CreateFrame("Frame", nil, env.UIParent)
env.SubZoneTextFrame = env.CreateFrame("Frame", nil, env.UIParent)
env.PetHitIndicator = env.CreateFrame("Frame", nil, env.UIParent)
env.PetFrameHealthBar = env.CreateFrame("StatusBar", nil, env.UIParent)
env.PetFrameHealthBar.TextString = env.PetFrameHealthBar:CreateFontString()
env.GetPhysicalScreenSize = function() return 2560, 1440 end
env.StaticPopup_Show = function() end
env.StaticPopup_Hide = function(key) hidden[#hidden + 1] = key end
env.ConfirmLootSlot = function(id) confirmations[#confirmations + 1] = { "bind", id } end
env.ConfirmLootRoll = function(id, rollType) confirmations[#confirmations + 1] = { "roll", id, rollType } end
env.EventUtil = { ContinueOnAddOnLoaded = function(addon, callback)
    if addons[addon] then callback() end
end }

local ns = { L = setmetatable({}, { __index = function(_, key) return key end }) }
ui:load("Libs/LibStub/LibStub.lua", ns)
ui:load("Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua", ns)
ui:load("Libs/AceEvent-3.0/AceEvent-3.0.lua", ns)
env.LibStub:NewLibrary("AceDB-3.0", 1)
env.LibStub:NewLibrary("FlareEditMode", 1).IsInEditMode = function() return false end
ui:load("Core.lua", ns)
local db = {
    enabled = true, bagModule = true, bagModuleSeeded = true, autoRepair = true, repairGuild = false,
    fasterCameraZoom = true, maxCameraZoom = true, mapFade = true, keyDown = true, hideTips = true,
    hideErrors = true, hideZoneText = true, hidePortraitNumbers = true, hideLootAlerts = true,
    fasterLoot = true, skipLootConfirm = true, combatPlates = true, combatFriendly = true, alertSounds = true,
    sellJunk = true, acceptRes = true, acceptSummon = true, merchantWide = true, petFood = true,
}
ns.db = { profile = { tweaks = db }, global = { forcedCVars = { keyDown = "0" } } }
ns.ShowDialog = function(key, text) opened[#opened + 1] = { key, text }; return true end
ns.CancelDialog = function(key)
    if opened[#opened] and opened[#opened][1] == key then
        local last = table.remove(opened)
        ns.Dialogs[last[1]].OnCancel()
    end
end

local vendor = env.CreateFrame("Frame", "MerchantFrame", env.UIParent)
vendor.selectedTab = 1
for i = 1, 12 do env.CreateFrame("Button", "MerchantItem" .. i, vendor) end
env.CreateFrame("Button", "MerchantNextPageButton", vendor)
env.CreateFrame("Button", "MerchantSellAllJunkButton", vendor)
env.MerchantFrame_UpdateMerchantInfo = function() env.MerchantSellAllJunkButton:Show() end
env.MerchantFrame_UpdateBuybackInfo = function() end
local money, junk, repair, sales, guild = 20, 2, 50, 0, false
env.GetMoney = function() return money end
env.CanMerchantRepair = function() return repair > 0 end
env.GetRepairAllCost = function() return repair, repair > 0 end
env.RepairAllItems = function(fromGuild)
    if fromGuild then
        guild = true
    else
        assert(money >= repair)
        money, repair = money - repair, 0
    end
end
env.CanGuildBankRepair = function() return true end
env.GetGuildBankWithdrawMoney = function() return -1 end
env.C_CurrencyInfo = { GetCoinText = function(value) return value .. " copper" end }
env.C_MerchantFrame = {
    IsSellAllJunkEnabled = function() return true end,
    GetNumJunkItems = function() return junk end,
    SellAllJunkItems = function() sales = sales + 1; junk = 0 end,
}
env.LootAlertSystem = {
    shouldIgnoreAlertsFunc = function(item) return item == "Blizzard ignores it" end,
    SetShouldIgnoreAlertsFunction = function(self, callback) self.shouldIgnoreAlertsFunc = callback end,
}
local slots = 0
env.GetNumLootItems = function() return slots end
env.LootSlot = function(slot) loot[#loot + 1] = slot end
local resurrected, summoned, summonTime = 0, 0, 75
env.AcceptResurrect = function() resurrected = resurrected + 1 end
env.PlayerCanTeleport = function() return not combatUnits.player end
env.C_SummonInfo = {
    GetSummonConfirmTimeLeft = function() return summonTime end,
    GetSummonConfirmAreaName = function() return "Westfall" end,
    ConfirmSummon = function() summoned = summoned + 1 end,
}
local bag = env.CreateFrame("Frame", "ContainerFrameCombinedBags", env.UIParent)
local food = env.CreateFrame("Button", nil, bag)
food.GetBagID = function() return 0 end
food.GetID = function() return 1 end
bag.EnumerateValidItems = function() return ipairs({ food }) end
bag.UpdateItems = function() end
env.C_Container = { GetContainerItemID = function() return 123 end }
env.C_PetInfo = { CanPetEatItem = function(id) return id == 123 end }

ui:load("Modules/TweaksCVars.lua", ns)
ui:load("Modules/Tweaks.lua", ns)
local tweaks = ns.Tweaks
assert(tweaks:ShouldLoad())
tweaks:Init()
assert(cv.cameraDistanceMaxZoomFactor == "2.6" and cv.cameraZoomSpeed == "50")
assert(env.CameraZoomIn(1) == 4 and env.CameraZoomOut(0.5) == 0.5)
assert(cv.mapFade == "1" and cv.ActionButtonUseKeyDown == "1" and cv.showTutorials == "0")
assert(ns.CharDB().forcedCVars.keyDown == "0" and ns.db.global.forcedCVars.keyDown == nil)
assert(ns.CharDB().mailName == "Marin Reed")
assert(cv.nameplateShowEnemies == "0" and tweaks.FriendlyPicks() == "000" and tweaks.FriendlyHeld() == "101")
assert(tweaks.FriendlyIndex("NamePlateShowFriendlyNpcs") == 2)

ui:emit("PLAYER_REGEN_DISABLED")
assert(cv.nameplateShowEnemies == "1" and tweaks.FriendlyPicks() == "101")
ui:emit("PLAYER_REGEN_ENABLED")
assert(cv.nameplateShowEnemies == "0" and tweaks.FriendlyPicks() == "000")
ui:emit("UI_ERROR_MESSAGE", 1, "Out of range")
assert(#texts == 0)
ui:emit("UI_ERROR_MESSAGE", 1, env.ERR_INV_FULL)
assert(texts[#texts] == "Inventory is full")
env.ZoneTextFrame:Hide()
env.ZoneTextFrame:Show()
assert(not env.ZoneTextFrame:IsShown())
env.PetHitIndicator:Show()
assert(not env.PetHitIndicator:IsShown() and env.PetFrameHealthBar.TextString:GetAlpha() == 0)
assert(env.LootAlertSystem.shouldIgnoreAlertsFunc("test"))

env.MerchantFrame_UpdateMerchantInfo()
assert(vendor:GetWidth() == 666 and env.MerchantItem20:IsShown() and env.MERCHANT_ITEMS_PER_PAGE == 20)
env.MerchantFrame_UpdateBuybackInfo()
assert(vendor:GetWidth() == 336 and not env.MerchantItem20:IsShown())
env.MerchantSellAllJunkButton:Hide()
env.MerchantSellAllJunkButton:Show()
assert(not env.MerchantSellAllJunkButton:IsShown())
ui.shift = true
ui:emit("MERCHANT_SHOW")
assert(sales == 0)
ui.shift = false
ui:emit("MERCHANT_SHOW")
assert(sales == 1 and repair == 50)
money, junk = 100, 1
ui:emit("PLAYER_MONEY")
assert(repair == 0 and money == 50)
ui:flushTimers()
assert(sales == 2)
money = 150
ui:flushTimers()
assert(texts[#texts]:find("Sold 3 junk items for 180 copper", 1, true))
db.repairGuild = true
repair = 25
ui:emit("MERCHANT_SHOW")
assert(guild)
ui:flushTimers()
assert(repair == 0 and money == 125, "A failed guild payment falls back to personal funds")

ui:emit("LOOT_READY", true)
slots = 3
ui:emit("LOOT_OPENED", true)
ui:emit("LOOT_READY", true)
assert(table.concat(loot, ",") == "3,2,1", "A second event for the same loot window does not loot twice")
ui:emit("LOOT_CLOSED")
slots = 1
ui:emit("LOOT_READY", true)
assert(loot[4] == 1)
ui:emit("LOOT_BIND_CONFIRM", 4)
ui:emit("CONFIRM_DISENCHANT_ROLL", 5, 3)
assert(#confirmations == 0)
ui:flushTimers()
assert(confirmations[1][1] == "bind" and confirmations[1][2] == 4 and hidden[1] == "LOOT_BIND")
assert(confirmations[2][3] == 3 and hidden[2] == "CONFIRM_LOOT_ROLL")

ui:emit("READY_CHECK", "player")
ui:emit("READY_CHECK", "party1")
assert(#ui.sounds == 0)
cv.Sound_EnableSFX = "0"
ui:emit("READY_CHECK", "party1")
assert(ui.sounds[1][2] == "Master")
combatUnits.party1 = true
ui:emit("RESURRECT_REQUEST", "party1")
assert(resurrected == 0)
combatUnits.party1 = false
ui:emit("RESURRECT_REQUEST", "party1")
assert(resurrected == 1)

ui:emit("CONFIRM_SUMMON")
assert(opened[#opened][2]:find("Westfall", 1, true))
local countdown = tweaks.summon.ticker
combatUnits.player = true
for _ = 1, 10 do countdown.callback() end
assert(countdown.cancelled and summoned == 0)
combatUnits.player = false
ui:emit("PLAYER_REGEN_ENABLED")
ui:flushTimers()
assert(summoned == 1 and hidden[#hidden] == "CONFIRM_SUMMON" and not tweaks.summon.pending)
ui:emit("CONFIRM_SUMMON")
ns.CancelDialog("FLAREUI_ACCEPT_SUMMON")
assert(not tweaks.summon.pending and summoned == 1)

bag:UpdateItems()
assert(food.FlareUI_PetFood:IsShown())
db.petFood = false
ui:emit("UNIT_PET", "player")
assert(not food.FlareUI_PetFood:IsShown())

local scale = tweaks.UIScale
scale.Remember()
ns.db.global.uiScale = "auto"
scale.Apply()
assert(math.abs(env.UIParent:GetScale() - 768 / 1440) < 0.00001 and cv.useUiScale == "1")
scale.AskToKeep()
assert(opened[#opened][1] == "FLAREUI_KEEP_SCALE")
ui:flushTimers()
assert(ns.db.global.uiScale == nil and cv.useUiScale == "0" and cv.uiscale == "0.75")
ns.db.global.uiScale, ns.db.global.uiScaleCustom = "custom", 0.2
assert(scale.Value() == scale.CUSTOM_MIN)

db.cameraZoomSpeed, db.cameraMaxZoom, db.hideTips, db.hidePortraitNumbers = nil, nil, false, false
db.hideLootAlerts, db.combatFriendly, db.combatPlates, db.mapFade, db.keyDown = false, false, false, false, false
tweaks:Refresh()
assert(cv.cameraZoomSpeed == "20" and cv.cameraDistanceMaxZoomFactor == "1.7" and env.CameraZoomIn(1) == 1)
assert(cv.showTutorials == "1" and cv.showNPETutorials == "0" and env.PetFrameHealthBar.TextString:GetAlpha() == 1)
assert(not env.LootAlertSystem.shouldIgnoreAlertsFunc("test") and env.LootAlertSystem.shouldIgnoreAlertsFunc("Blizzard ignores it"))
assert(tweaks.FriendlyPicks() == "101" and cv.nameplateShowEnemies == "1" and cv.ActionButtonUseKeyDown == "0")
-- Quest automation leaves repeatable quests, manual reward choices and the Shift override alone.
db.autoAcceptQuests, db.autoTurnInQuests, db.skipGossip = true, true, true
env.Enum = { InputDeviceInterfaceType = { Mkb = 0, Gamepad = 1 } }
local repeated, trivial, cost, choices, marks = false, false, 0, 0, false
env.C_QuestLog = {
    IsRepeatableQuest = function(id) return repeated or id == 3 end,
    IsQuestTrivial = function(id) return trivial or id == 4 end,
}
local available, active, options = {
    { questID = 3 }, { questID = 4 }, { questID = 5 },
}, { { questID = 3, isComplete = true }, { questID = 2, isComplete = true } }, {}
local picked = {}
env.C_GossipInfo = {
    GetAvailableQuests = function() return available end,
    GetActiveQuests = function() return active end,
    GetOptions = function() return options end,
    SelectActiveQuest = function(id) picked[#picked + 1] = "active:" .. id end,
    SelectAvailableQuest = function(id) picked[#picked + 1] = "available:" .. id end,
    SelectOption = function(id) picked[#picked + 1] = "option:" .. id end,
}
env.IsInInstance = function() return false end
env.QuestIsFromAdventureMap = function() return false end
env.QuestFlagsPVP = function() return false end
env.QuestGetAutoAccept = function() return false end
env.GetQuestID = function() return 5 end
env.AcceptQuest = function() picked[#picked + 1] = "accepted" end
env.IsQuestCompletable = function() return true end
env.GetQuestMoneyToGet = function() return cost end
env.GetNumQuestItems = function() return marks and 1 or 0 end
env.GetQuestItemLink = function() return "battleground mark" end
env.C_Item = { GetItemInfoInstant = function() return 20558 end }
env.CompleteQuest = function() picked[#picked + 1] = "completed" end
env.GetNumQuestChoices = function() return choices end
env.GetQuestReward = function(choice) picked[#picked + 1] = "reward:" .. choice end
ui:emit("GOSSIP_SHOW")
active = {}
ui:emit("GOSSIP_SHOW")
available, options = {}, { { gossipOptionID = 11, icon = 132057 } }
ui:emit("GOSSIP_SHOW")
ui:emit("GOSSIP_SHOW")
ui:emit("GOSSIP_CLOSED")
ui:emit("GOSSIP_SHOW")
ui.shift = true
ui:emit("QUEST_DETAIL")
ui.shift = false
ui:emit("QUEST_DETAIL", 7)
trivial = true
ui:emit("QUEST_DETAIL")
trivial = false
ui:emit("QUEST_DETAIL")
marks = true
ui:emit("QUEST_PROGRESS")
marks = false
cost = 100
ui:emit("QUEST_PROGRESS")
cost = 0
ui:emit("QUEST_PROGRESS")
choices = 2
ui:emit("QUEST_COMPLETE")
choices = 1
ui:emit("QUEST_COMPLETE")
assert(table.concat(picked, " ") == "active:2 available:5 option:11 option:11 accepted completed reward:1")

-- An unchanged source snapshot keeps its original timestamp. A recipient applies changed fields once.
db.enabled, db.syncUI = false, true
local now, filters, channels, bank, guildInvites = 1000, { "SAY" }, { "General", 1 }, true, true
local chatName, chatSize, updated, actionBar = "Main", 14, 0, true
env.Constants = { ChatFrameConstants = { MaxChatWindows = 1 } }
env.Enum.BagSlotFlags = { Ignore = 10 }
env.NUM_BAG_SLOTS = 1
env.GetServerTime = function() return now end
env.GetChatWindowInfo = function() return chatName, chatSize, 1, 1, 1, 0.8, true, false, true, false end
env.GetChatWindowSavedPosition = function() return "BOTTOMLEFT", 12, 24 end
env.GetChatWindowSavedDimensions = function() return 400, 200 end
env.GetChatWindowMessages = function() return unpack(filters) end
env.GetChatWindowChannels = function() return unpack(channels) end
env.SetChatWindowName = function(_, name) chatName = name end
env.SetChatWindowSize = function(_, size) chatSize = size end
env.RemoveChatWindowMessages = function() filters = {} end
env.AddChatWindowMessages = function(_, group) filters[#filters + 1] = group end
env.RemoveChatWindowChannel = function() channels = {} end
env.AddChatWindowChannel = function(_, channel) channels[#channels + 1] = channel end
env.FloatingChatFrame_Update = function() updated = updated + 1 end
env.GetAutoDeclineGuildInvites = function() return guildInvites end
env.SetAutoDeclineGuildInvites = function(value) guildInvites = value end
env.GetActionBarToggles = function() return actionBar, false end
env.SetActionBarToggles = function(value) actionBar = value end
env.ChatTypeInfo = { SAY = { colorNameByClass = true } }
env.GetMessageTypeColor = function() return 0.1, 0.2, 0.3 end
env.SetChatColorNameByClass = function(chatType, value) env.ChatTypeInfo[chatType].colorNameByClass = value end
env.C_Container.GetSortBagsRightToLeft = function() return bank end
env.C_Container.SetSortBagsRightToLeft = function(value) bank = value end
for _, suffix in ipairs({ "InsertItemsLeftToRight", "BankAutosortDisabled", "BackpackSellJunkDisabled", "BackpackAutosortDisabled" }) do
    env.C_Container["Get" .. suffix] = function() return false end
end
local ignored = true
env.C_Container.GetBagSlotFlag = function() return ignored end
env.C_Container.SetBagSlotFlag = function(_, _, value) ignored = value end
local function newTimer(delay, callback)
    return env.C_Timer.NewTicker(delay, callback)
end
env.C_Timer.NewTimer = newTimer
env.EditModeManagerFrame = env.CreateFrame("Frame", nil, env.UIParent)
env.EditModeManagerFrame.layoutInfo = {
    activeLayout = 1, layouts = { { layoutName = "Source Edit Mode", layoutType = 0 }, { layoutName = "Modern", layoutType = 0 } },
}
function env.EditModeManagerFrame:GetActiveLayoutInfo() return self.layoutInfo.layouts[self.layoutInfo.activeLayout] end
cv.autoLootDefault = "1"
tweaks:MakeSyncSource()
local store = ns.db.global.uiSync
local initial = store.snapshot
assert(initial.savedAt == 1000 and initial.cvars.autoLootDefault == "1")
assert(tweaks:IsSyncSource() and tweaks:GetSyncSourceLabel() == "Marin Reed")
tweaks:MakeSyncSource()
assert(store.snapshot == initial, "An identical snapshot does not request another sync")
cv.autoLootDefault, now, chatSize = "0", 1001, 15
ui:emit("ADDON_LOADED", "AnotherAddon")
tweaks:MakeSyncSource()
assert(store.snapshot.savedAt == 1001 and store.snapshot.stamps.chat == 1001)
assert(store.snapshot.stamps.chatFilters == 1000 and store.snapshot.cvarStamps.autoLootDefault == 1001)

guid, cv.autoLootDefault, chatName, chatSize = "Player-Other", "1", "Old", 11
filters, channels, bank, ignored, guildInvites, actionBar = { "YELL" }, { "Trade" }, false, false, false, false
env.ChatTypeInfo.SAY.colorNameByClass = false
env.EditModeManagerFrame.layoutInfo.activeLayout = 2
assert(tweaks:ShouldLoad() and not tweaks:IsSyncSource())
ui:flushTimers()
assert(ns.CharDB().syncApplied == 1001 and chatName == "Main" and chatSize == 15 and cv.autoLootDefault == "0")
assert(ignored and bank and guildInvites and env.ChatTypeInfo.SAY.colorNameByClass)
assert(filters[1] == "SAY" and channels[1] == "General")
ui:flushTimers()
assert(actionBar and updated == 1 and opened[#opened][1] == "FLAREUI_SYNC_RELOAD")

print("PASS: Quality of Life vendor, quests, sync, loot, visibility and CVar behavior")
