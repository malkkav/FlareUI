local ui, ns, unit, edit = dofile("tools/tests/fixtures/party-world.lua")
local env = ui.env
env.BreakUpLargeNumbers = tostring
env.GetXPExhaustion = function() return 90 end
env.MAX_REPUTATION_REACTION = 8
env.REPUTATION, env.HONOR, env.LEVEL, env.HONOR_LEVEL_LABEL = "Reputation", "Honor", "Level", "Honor %d"
env.PLAYER_FACTION_COLOR_ALLIANCE = env.CreateColor(0.25, 0.3, 0.8)
env.FACTION_GREEN_COLOR = env.CreateColor(0, 1, 0)
env.UnitHonorLevel = function() return 5 end
env.UnitHonor = function() return 200 end
env.UnitHonorMax = function() return 400 end
env.UnitSex = function() return 2 end
env.GetText = function(key) return key == "FACTION_STANDING_LABEL5" and "Friendly" or key end
env.SecondsToTime = function(seconds) return seconds .. "s" end
local xp, xpMax, tracksXP, tracksHonor = 300, 1000, true, false
env.UnitXP = function() return xp end
env.UnitXPMax = function() return xpMax end
env.GameRulesUtil = { CanShowExperienceBar = function() return tracksXP end }
env.C_PvP = { IsActiveBattlefield = function() return tracksHonor end }
local faction = { name = "Stormwind", factionID = 72, reaction = 5, currentReactionThreshold = 100, nextReactionThreshold = 500, currentStanding = 200 }
local friend, paragon, major
env.C_Reputation = {
    GetWatchedFactionData = function() return faction end,
    IsFactionParagonForCurrentPlayer = function() return paragon end,
    GetFactionParagonInfo = function() return 150, 100, nil, true end,
    IsMajorFaction = function() return major ~= nil end,
}
env.C_MajorFactions = { GetMajorFactionData = function() return major end }
env.C_GossipInfo = { GetFriendshipReputation = function() return friend end }
local quest = {
    { isHeader = true },
    { questID = 1, title = "Ready quest", ready = true, onMap = true, xp = 200 },
    { questID = 2, title = "Other zone", xp = 100 },
    { questID = 3, title = "Local quest", onMap = true, xp = 50 },
}
local scans = 0
local function questByID(id) return quest[id + 1] end
env.C_QuestLog = {
    GetNumQuestLogEntries = function() scans = scans + 1; return #quest end,
    GetInfo = function(i) return quest[i] end,
    IsOnMap = function(id) return questByID(id).onMap end,
    ReadyForTurnIn = function(id) return questByID(id).ready end,
    IsComplete = function() return false end,
}
env.GetQuestLogRewardXP = function(id) return questByID(id).xp end
env.GameTooltip.IsOwned = function(self, owner) return self.owner == owner end
env.GameTooltip.AddDoubleLine = function(self, left, right)
    self:AddLine(left .. " " .. right)
end
env.CreateFrame("Frame", "MainStatusTrackingBarContainer")
env.CreateFrame("Frame", "StatusTrackingBarManager"):RegisterEvent("PLAYER_XP_UPDATE")
ns.AddonMedia = function() return { "External bar" } end
local refreshes = 0
ns.Visibility = { Refresh = function() refreshes = refreshes + 1 end }
ui:load("Modules/XPBar.lua", ns)
local bar = ns.XPBar
local ab = ns.db.profile.actionbars
local db = ab.xpbar
ab.enabled, db.enabled, db.questXP, db.tooltip = true, true, true, true
db.textMode, db.textFormat, db.questXPMode = "HOVER", "BOTH", "zone"
db.bubbles = true
assert(bar:ShouldLoad() and bar.TextValue() == "hover,percent,value,max")
local textureChoices = bar.LookChoices("texture")
assert(textureChoices[#textureChoices][1] == "External bar")
bar:Init()
ui:flushTimers()
local frame = bar:GetFrame()
local left, right = frame.Left, frame.Right
assert(not env.MainStatusTrackingBarContainer:IsShown() and not env.StatusTrackingBarManager:IsEventRegistered("PLAYER_XP_UPDATE"))
assert(refreshes == 1 and frame.Pip:IsShown())
assert(left:GetValue() == 0.3 and right:GetValue() == 0.25)
assert(left.info.quest == 200 and left.info.questOpen == 50 and left.info.rested == 90 and scans == 1)
assert(left.Quest:IsShown() and left.QuestOpen:IsShown() and left.Rested:GetWidth() > left.Quest:GetWidth())
assert(left.Bubbles[19][1]:IsShown() and not left.Text:IsShown())
left:RunScript("OnEnter")
assert(left.Text:IsShown() and env.GameTooltip:IsShown())
assert(table.concat(env.GameTooltip.lines, "\n"):find("Ready quest 200", 1, true))
left:RunScript("OnLeave")
assert(not left.Text:IsShown() and not env.GameTooltip:IsShown())

xp, ui.time = 400, 175
ui:emit("CVAR_UPDATE", "unrelated")
assert(#ui.timers == 0)
ui:emit("PLAYER_XP_UPDATE", "player")
ui:emit("UPDATE_EXHAUSTION")
assert(#ui.timers == 1)
ui:flushTimers()
assert(left:GetValue() == 0.4 and left.Flash.anim:IsPlaying() and scans == 1)
left:RunScript("OnEnter")
assert(table.concat(env.GameTooltip.lines, "\n"):find("XP per hour 4800", 1, true))
left:RunScript("OnLeave")
db.questXPMode, db.style = "all", "double"
bar:Refresh()
assert(left.info.questOpen == 150 and scans == 2 and not frame.Pip:IsShown())
assert(select(2, right:GetPoint()) == left and right:GetWidth() == left:GetWidth())
bar.SetTextValue("remaining")
bar:Refresh()
assert(bar.TextAlways() and left.Text:GetText():find("XP  600 to go", 1, true))
assert(frame:GetFrameStrata() == "MEDIUM", "above the minimap, which a click raises in LOW (11-25)")
frame:SetAlpha(0.01)
assert(not left:IsMouseEnabled())
frame:SetAlpha(1)
assert(left:IsMouseEnabled())

tracksXP, tracksHonor = false, true
ui:emit("PLAYER_LEVEL_UP")
ui:flushTimers()
assert(left.info.kind == "rep" and right.info.kind == "honor")
paragon = true
ui:emit("UPDATE_FACTION")
ui:flushTimers()
assert(left.info.value == 150 and left.Text:GetText():find("0 to go", 1, true))
paragon, major = false, { renownLevelThreshold = 1000, renownReputationEarned = 350 }
bar:Refresh()
assert(left:GetValue() == 0.35)
major, friend = nil, { friendshipFactionID = 1, reaction = "Best Friend" }
bar:Refresh()
assert(left.info.capped and left.Text:GetText() == "Stormwind")
friend, faction = nil, nil
bar:Refresh()
assert(left.info.kind == "honor" and not right:IsShown())
tracksHonor = false
bar:Refresh()
assert(not frame:IsShown())
ui.editing = true
edit.callbacks.enter()
assert(frame:IsShown() and left:GetValue() == 0.6 and right:GetValue() == 0.4)
-- (11-24) a fight in Edit Mode shows the live bar, and the sample again after it
ui:emit("PLAYER_REGEN_DISABLED")
assert(not frame:IsShown())
ui:emit("PLAYER_REGEN_ENABLED")
assert(frame:IsShown())
frame.moved(frame, "Custom", "BOTTOM", 18.2, 23.7)
edit.callbacks.layout("Custom")
local point, _, _, x, y = frame:GetPoint()
assert(point == "BOTTOM" and x == 18 and y == 24)
local sample = bar.CreateSample(env.UIParent)
local width = bar.DrawSample(sample)
assert(width == 248 and not sample.Left:IsMouseEnabled())
print("PASS: XP/reputation/honor tracking, XP overlays, and layout controls")
