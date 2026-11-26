-- Banner sources, after Horizon Suite's Presence: Blizzard's announcements are put away per kind and handed
-- back, zone and subzone changes, "Discovered", quest progress read from the objectives, levels and bosses.
local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local function noop() end
local Widget = getmetatable(env.UIParent).__index
function Widget:SetParent(parent) self.parent = parent end
local edit = { SettingType = { Slider = "slider" } }
function edit:GetActiveLayoutName() return "Modern" end
edit.AddFrame, edit.AddFrameSettings, edit.RegisterCallback = noop, noop, noop
env.LibStub = function() return edit end
env.unpack = unpack
env._G = env
env.IsInInstance = function() return ui.inside or false, ui.instance or "none" end
env.canaccessvalue = function(value) return value ~= "<secret>" end
env.UnitLevel = function() return 7 end
local zone, sub = "Elwynn Forest", ""
env.GetZoneText = function() return zone end
env.GetSubZoneText = function() return sub end
env.ERR_ZONE_EXPLORED = "Discovered: %s"
env.ERR_ZONE_EXPLORED_XP = "Discovered %s: %d experience gained"
env.ERR_QUEST_ADD_KILL_SII = "%s slain: %d/%d"
env.ERR_QUEST_OBJECTIVE_COMPLETE_S = "%s (Complete)"
env.ERR_QUEST_ACCEPTED_S = "Quest accepted: %s"
env.OBJECTIVE_COMPLETE = "Objective Complete."
-- the quest log: one watched quest with two objectives
local objectives = { { text = "Prowlers slain", numFulfilled = 1, numRequired = 8 }, { text = "Find the den", finished = false } }
local onQuest = { [11] = true }
env.C_QuestLog = {
    GetTitleForQuestID = function(id) return ({ [11] = "Wolves at the Door", [12] = "[DNT] Test Quest" })[id] end,
    GetQuestObjectives = function(id) return id == 11 and objectives or {} end,
    IsOnQuest = function(id) return onQuest[id] == true end,
    IsComplete = function() return false end,
    GetNumQuestWatches = function() return 1 end,
    GetQuestIDForQuestWatchIndex = function() return 11 end,
    GetNumQuestLogEntries = function() return 1 end,
    GetInfo = function() return { questID = 11 } end,
    GetLogIndexForQuestID = function() return 1 end,
}
-- (this client has no scenarios, rares or achievements: the sources stay silent)
env.C_Scenario, env.C_ScenarioInfo, env.C_VignetteInfo, env.GetAchievementInfo = nil, nil, nil, nil
-- Blizzard's own announcements
local function blizzard(name, ...)
    local frame = env.CreateFrame("Frame", name, env.UIParent)
    for _, event in ipairs({ ... }) do frame:RegisterEvent(event) end
    frame:Hide()
    return frame
end
local zoneText = blizzard("ZoneTextFrame", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA")
local subZoneText = blizzard("SubZoneTextFrame", "ZONE_CHANGED")
local levelUp = blizzard("LevelUpDisplay")
local toasts = blizzard("EventToastManagerFrame", "DISPLAY_EVENT_TOASTS")
function toasts:DisplayToast() self:Show() end
local warnings = blizzard("RaidWarningFrame", "RAID_BOSS_EMOTE", "CHAT_MSG_RAID_WARNING")
local alerts = blizzard("AlertFrame", "ACHIEVEMENT_EARNED", "CRITERIA_EARNED", "QUEST_TURNED_IN", "LOOT_ITEM_ROLL_WON")
alerts.alertQueue = { "an old toast" }
local cleared = 0
env.UIErrorsFrame = { AddMessage = noop, Clear = function() cleared = cleared + 1 end }

local db = { enabled = true, zone = true, subzone = true, discovery = true, levelUp = true, bossEmote = true,
    achievement = true, questAccept = true, questComplete = true, questProgress = true, rare = true, scenario = true,
    achievementProgress = false, animate = false, hold = 1, icons = true }
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }), modules = {},
    db = { profile = { banners = db } },
    LayoutHome = function(layouts, key) layouts[key] = layouts[key] or {}; return layouts[key] end,
    EditSection = function(_, settings) return settings end,
    SetFont = noop, ApplyShadow = noop,
    GetFontPath = function(face) return face end,
}
ui:load("Modules/Banners.lua", ns)
ui:load("Modules/BannerSources.lua", ns)
local B, S = ns.Banners, ns.BannerSources
ui.time = 100
B:Init()
-- timers queue more timers (debounces, retries): run them until none is left
local function settle()
    for _ = 1, 10 do
        if #ui.timers == 0 then break end
        ui:flushTimers()
    end
end
local function clear() settle(); B:Clear() end
local function later(seconds) ui.time = ui.time + seconds end

-- format strings as patterns, positional ones too; quest lines in one shape
assert(("Bandits slain: 3/8"):match(S.ToPattern("%s slain: %d/%d")) == "Bandits")
assert(("8 of Bandits"):match(S.ToPattern("%2$d of %1$s")) == "8")
assert(S.Normalize("Prowlers slain: 2/8") == "2/8 Prowlers slain" and S.Normalize("Prowlers slain (2/8)") == "2/8 Prowlers slain")
assert(S.Normalize("1/1 Find the den") == "Find the den")

-- BLIZZARD'S FRAMES: each kind's frame is killed while the kind is on
assert(not zoneText:IsEventRegistered("ZONE_CHANGED") and zoneText:GetParent() ~= env.UIParent, "events off, under a hidden parent")
zoneText:Show()
assert(not zoneText:IsShown(), "and hidden as it shows")
assert(not subZoneText:IsEventRegistered("ZONE_CHANGED") and levelUp:GetParent() ~= env.UIParent)
toasts:DisplayToast()
assert(not toasts:IsShown(), "the event toasts, while a quest or achievement banner is on")
assert(not warnings:IsEventRegistered("RAID_BOSS_EMOTE") and warnings:IsEventRegistered("CHAT_MSG_RAID_WARNING"), "only the boss emote is taken")
assert(not alerts:IsEventRegistered("ACHIEVEMENT_EARNED") and not alerts:IsEventRegistered("QUEST_TURNED_IN"))
assert(alerts:IsEventRegistered("CRITERIA_EARNED"), "Achievement Progress is off: its alert stays Blizzard's")
assert(alerts:IsEventRegistered("LOOT_ITEM_ROLL_WON"), "what we don't replace is left alone")
-- a kind switched off: its frame comes back, with its events
db.zone, db.bossEmote, db.achievement = false, false, false
B:Refresh()
assert(zoneText:GetParent() == env.UIParent and zoneText:IsEventRegistered("ZONE_CHANGED_NEW_AREA"))
zoneText:Show()
assert(zoneText:IsShown())
assert(warnings:IsEventRegistered("RAID_BOSS_EMOTE") and alerts:IsEventRegistered("ACHIEVEMENT_EARNED"))
assert(not subZoneText:IsEventRegistered("ZONE_CHANGED"), "the subzone banner is still on")
db.zone, db.bossEmote, db.achievement = true, true, true
B:Refresh()
assert(not zoneText:IsEventRegistered("ZONE_CHANGED"))
-- after a login the alert backlog is cleared only while every alert we replace is muted
ui:emit("PLAYER_ENTERING_WORLD")
assert(#alerts.alertQueue == 1, "Achievement Progress is Blizzard's: its queue is not ours to wipe")
db.achievementProgress = true
B:Refresh()
ui:emit("PLAYER_ENTERING_WORLD")
assert(#alerts.alertQueue == 0)
db.achievementProgress = false
B:Refresh()
settle()

-- ZONES: a border fires three events: one banner, the zone's
B:Clear()
ui:emit("ZONE_CHANGED_NEW_AREA"); ui:emit("ZONE_CHANGED"); ui:emit("ZONE_CHANGED_INDOORS")
settle()
assert(B.active.kind == "zone" and B.active.title == "Elwynn Forest" and B.active.subtitle == nil and #B.queue == 0)
-- a subzone: its name above, the zone's below; a new one replaces the banner showing at once
sub = "Goldshire"
later(10); ui:emit("ZONE_CHANGED"); settle()
assert(B.active.kind == "subzone" and B.active.title == "Goldshire" and B.active.subtitle == "Elwynn Forest" and #B.queue == 0)
-- the same one again within two seconds says nothing
B:Clear()
later(1); ui:emit("ZONE_CHANGED"); settle()
assert(not B.active)
-- out of it into the open zone: no banner (the zone's name was shown on the way in)
sub = ""
later(10); ui:emit("ZONE_CHANGED"); settle()
assert(not B.active)
-- Subzone Name Only: the zone's name is left out inside the zone you are in
db.hideZoneInSub, sub = true, "Crystal Lake"
later(10); ui:emit("ZONE_CHANGED"); settle()
assert(B.active.title == "Crystal Lake" and B.active.subtitle == nil)
db.hideZoneInSub = false
-- an instance picked under Don't Show In: nothing
B:Clear()
db.skipDungeon, ui.inside, ui.instance, sub = true, true, "party", "The Deadmines"
later(10); ui:emit("ZONE_CHANGED"); settle()
assert(not B.active)
db.skipDungeon, ui.inside, ui.instance = false, false, "none"

-- "DISCOVERED": read off the error text, shown under the zone banner playing, and cleared from the error text
sub = "Stone Cairn Lake"
later(10); ui:emit("ZONE_CHANGED"); settle()
env.UIErrorsFrame:AddMessage("Discovered Stone Cairn Lake: 120 experience gained")
assert(B.active.extra == "Discovered Stone Cairn Lake: 120 experience gained" and cleared == 1)
-- before its banner: kept, and joined to it; on its own it makes no banner
B:Clear()
sub = "Ridgepoint Tower"
env.UIErrorsFrame:AddMessage("Discovered: Ridgepoint Tower")
assert(not B.active and cleared == 2)
later(1); ui:emit("ZONE_CHANGED"); settle()
assert(B.active.title == "Ridgepoint Tower" and B.active.extra == "Discovered: Ridgepoint Tower")
-- kept only a few seconds: a later zone banner doesn't inherit it
B:Clear()
env.UIErrorsFrame:AddMessage("Discovered: Nowhere")
sub = "Eastvale"
later(30); ui:emit("ZONE_CHANGED"); settle()
assert(B.active.title == "Eastvale" and B.active.extra == nil)
-- other error text is left alone
env.UIErrorsFrame:AddMessage("You are too far away.")
assert(cleared == 3)

-- QUESTS: taken (not Blizzard's test quests)
clear()
ui:emit("QUEST_ACCEPTED", 11)
assert(B.active.kind == "questAccept" and B.active.title == "Quest Accepted" and B.active.subtitle == "Wolves at the Door")
clear()
ui:emit("QUEST_ACCEPTED", 12)
assert(not B.active, "[DNT]")
-- progress: read from the objectives and compared with what they were; the line that changed is shown
ui.time = 1000   -- (past the quiet seconds after starting)
ui:emit("QUEST_WATCH_UPDATE", 11); settle()
-- (the first look at a quest with several objectives has nothing to compare with: which one moved can't be told)
assert(B.active.kind == "questProgress" and B.active.title == "Wolves at the Door" and B.active.subtitle == "Objective updated")
objectives[1].numFulfilled = 2
ui:emit("QUEST_WATCH_UPDATE", 11)
env.UIErrorsFrame:AddMessage("Prowlers slain: 2/8")
ui:emit("UI_INFO_MESSAGE", 1, "Prowlers slain: 2/8")
settle()
assert(B.active.subtitle == "2/8 Prowlers slain" and #B.queue == 0, "the events of one kill are one banner")
assert(cleared == 4, "and the yellow line is cleared")
-- nothing changed: nothing shown
clear()
ui:emit("QUEST_LOG_UPDATE"); settle()
assert(not B.active)
-- the second objective done: its own line
objectives[2].finished = true
ui:emit("QUEST_LOG_UPDATE"); settle()
assert(B.active.subtitle == "Find the den")
-- "Objective Complete." on its own and "Quest accepted" are not progress
clear()
ui:emit("UI_INFO_MESSAGE", 1, "Objective Complete."); ui:emit("UI_INFO_MESSAGE", 1, "Quest accepted: Wolves at the Door"); settle()
assert(not B.active)
-- handed in: its banner, and its progress is left alone for a moment after
ui:emit("QUEST_TURNED_IN", 11, 0, 0)
assert(B.active.kind == "questComplete" and B.active.subtitle == "Wolves at the Door")
objectives[1].numFulfilled = 8
ui:emit("QUEST_WATCH_UPDATE", 11); settle()
assert(B.active.kind == "questComplete" and #B.queue == 0)
-- a quest whose name the game no longer knows still gets its banner
clear()
ui:emit("QUEST_TURNED_IN", 99, 0, 0)
assert(B.active.kind == "questComplete" and B.active.subtitle == nil)

-- LEVELS AND BOSSES
clear()
ui:emit("PLAYER_LEVEL_UP", 8)
assert(B.active.kind == "levelUp" and B.active.title == "Level Up" and B.active.subtitle == "You have reached level 8")
clear()
ui:emit("RAID_BOSS_EMOTE", "|cffff0000%s begins to cast!|r", "Ragnaros")
assert(B.active.title == "Ragnaros" and B.active.subtitle == "Ragnaros begins to cast!")
clear()
ui:emit("RAID_BOSS_EMOTE", "<secret>", "<secret>")
assert(B.active.subtitle == "<secret>", "a secret text goes to the banner as it is")

-- no achievement, scenario or rare API here: their events do nothing
clear()
ui:emit("ACHIEVEMENT_EARNED", 6); ui:emit("TRACKED_ACHIEVEMENT_UPDATE", 6, 1); ui:emit("CRITERIA_EARNED", 6, "x")
ui:emit("SCENARIO_UPDATE"); ui:emit("SCENARIO_CRITERIA_UPDATE"); ui:emit("SCENARIO_COMPLETED"); ui:emit("VIGNETTES_UPDATED")
settle()
assert(not B.active or B.active.kind == "scenarioComplete")
print("PASS: banners-sources")
