local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local Widget = getmetatable(env.UIParent)
local function noop() end
Widget.GetRect = function(self) return self:GetLeft(), self:GetBottom(), self:GetWidth(), self:GetHeight() end

local le = { SettingType = { Slider = "slider", Dropdown = "dropdown" }, callbacks = {} }
function le:GetActiveLayoutName() return self.layout or "Modern" end
function le:AddFrame(holder, onMove) self.holder, self.onMove = holder, onMove end
function le:AddFrameSettings(_, settings) self.settings = settings end
function le:RegisterCallback(event, callback) self.callbacks[event] = callback end
env.LibStub = function(name)
    if name == "FlareEditMode" then return le end
    assert(name == "LibSharedMedia-3.0")
    return {
        IsValid = function(_, _, name) return name == "Test border" end,
        Fetch = function(_, kind, name) return kind .. "/" .. name end,
    }
end
local pad, instance, taxi, fight = false, "none", false, false
env.IsInInstance = function() return instance ~= "none", instance end
env.UnitAffectingCombat = function() return fight end
env.UnitOnTaxi = function() return taxi end
env.IsCursorVisible = function() return true end
env.IsInGroup = function() return true end
env.UnitExists = function() return false end
env.UnitLevel = function() return 35 end
env.GetQuestDifficultyColor = function(level)
    return level > 20 and env.CreateColor(1, 0.2, 0, 1) or env.CreateColor(0.3, 1, 0.2, 1)
end
env.HaveQuestData = function() return false end
env.GetRealZoneText = function() return "Westfall" end
env.GetZoneText = function() return "Westfall" end
env.GetSubZoneText = function() return "Moonbrook" end
env.GetQuestLogSpecialItemInfo = noop
env.GetQuestLogCompletionText = function() return "" end
env.GetQuestProgressBarPercent = function() return 75 end
env.GetQuestLink = function(id) return "|Hquest:" .. id .. "|h[Quest]|h" end
env.GetCurrentKeyBoardFocus = noop
env.C_Texture = { GetAtlasInfo = noop }
env.Enum = {
    QuestTag = { Group = 1, Dungeon = 2, Raid = 3, Raid10 = 4, Raid25 = 5, PvP = 6, Heroic = 7 },
    QuestFrequency = { Daily = 1, Weekly = 2 },
    CraftingReagentType = { Basic = 1 },
}
env.ELITE, env.COMPLETE = "Elite", "Complete"
env.GREEN_FONT_COLOR = env.CreateColor(0, 1, 0, 1)
env.canaccessvalue = function() return true end
env.canaccessallvalues = env.canaccessvalue
local money = 50
env.GetMoney = function() return money end
env.GetMoneyString = function(amount) return amount .. "c" end

local log = {
    { isHeader = true, title = "Elwynn Forest" },
    { questID = 11, title = "Guard Supplies", level = 14, frequency = 1 },
    { questID = 12, title = "Deliver the Note", level = 13 },
    { isHeader = true, title = "Westfall" },
    { questID = 21, title = "Patrol Moonbrook", level = 22, suggestedGroup = 3 },
    { questID = 22, title = "Collect the Oats", difficultyLevel = 19 },
    { questID = 23, title = "Local Untracked", level = 8 },
    { questID = 24, title = "Hidden Task", level = 8, isHidden = true, isTask = true },
}
local watched = { [11] = true, [12] = true, [21] = true, [22] = true }
local done, failed = { [22] = true }, { [12] = true }
local distances = { [11] = 80, [12] = 100, [21] = 30, [22] = 10, [23] = 5 }
local progress = { { text = "Clean up the camp", type = "progressbar", numFulfilled = 3, numRequired = 4 },
    { text = "Scout returned", finished = true } }
local objectives = { [11] = { { text = "1/4 Crates", numFulfilled = 1, numRequired = 4 } }, [21] = progress }
local questTimes, focused = { { questID = 11, questTimer = 75 } }, 21
local watchChanges, focusChanges = {}, {}
env.C_QuestLog = {
    GetNumQuestLogEntries = function() return #log end,
    GetMaxNumQuestsCanAccept = function() return 25 end,
    GetInfo = function(index)
        local result = {}
        for key, value in pairs(log[index]) do result[key] = value end
        return result
    end,
    GetTitleForQuestID = function(id)
        for _, quest in ipairs(log) do if quest.questID == id then return quest.title end end
    end,
    GetLogIndexForQuestID = function(id)
        for index, quest in ipairs(log) do if quest.questID == id then return index end end
    end,
    GetQuestWatchType = function(id) if watched[id] then return 1 end end,
    AddQuestWatch = function(id) watched[id] = true; watchChanges[#watchChanges + 1] = id end,
    RemoveQuestWatch = function(id) watched[id] = nil; watchChanges[#watchChanges + 1] = -id end,
    IsOnMap = function(id) return id >= 20 end,
    GetDistanceSqToQuest = function(id) return distances[id], true end,
    IsComplete = function(id) return done[id] or false end,
    IsFailed = function(id) return failed[id] or false end,
    GetQuestObjectives = function(id) return objectives[id] end,
    GetQuestTimers = function() return questTimes end,
    GetTimeAllowed = function() return 100 end,
    GetQuestTagInfo = function(id) if id == 11 then return { tagID = 1, tagName = "Elite" } end end,
    GetNextWaypointText = function(id) return id == 21 and "Investigate the inn" or "" end,
    GetRequiredMoney = function(id) return id == 21 and 100 or 0 end,
    IsPushableQuest = function(id) return id == 21 end,
}
env.C_SuperTrack = {
    GetSuperTrackedQuestID = function() return focused end,
    SetSuperTrackedQuestID = function(id) focused = id; focusChanges[#focusChanges + 1] = id end,
}
local allowUntrack, shared, abandoned, chatLink, chatActive = true
env.QuestUtil = {
    CanRemoveQuestWatch = function() return allowUntrack end,
    ShareQuest = function(id) shared = id end,
}
env.QuestMapQuestOptions_AbandonQuest = function(id) abandoned = id end
env.ChatFrameUtil = {
    GetActiveWindow = function() return chatActive end,
    InsertLink = function(link) chatLink = link; return true end,
}

local recipeTracked, openedRecipe = true, nil
env.C_TradeSkillUI = {
    GetRecipesTracked = function() return recipeTracked and { 101 } or {} end,
    GetRecipeSchematic = function()
        return { name = "Linen Boots", reagentSlotSchematics = {
            { reagentType = 1, quantityRequired = 3, reagents = { { itemID = 2589 } } },
            { reagentType = 2, quantityRequired = 7, reagents = { { itemID = 144 } } },
        } }
    end,
    SetRecipeTracked = function(id, track, recraft)
        assert(id == 101 and not track and not recraft)
        recipeTracked = track
    end,
    OpenRecipe = function(id) openedRecipe = id end,
}
env.C_Item = {
    GetItemCount = function(id) assert(id == 2589); return 2 end,
    GetItemNameByID = function(id) assert(id == 2589); return "Linen Cloth" end,
}

local menu, dialog
env.MenuUtil = {
    CreateContextMenu = function(owner, draw)
        menu = {}
        local root = {
            CreateTitle = function(_, title) menu.title = title end,
            CreateDivider = noop,
            CreateButton = function(_, label, callback)
                local button = { run = callback, enabled = true }
                function button:SetEnabled(enabled) self.enabled = enabled end
                menu[label] = button
                return button
            end,
        }
        draw(owner, root)
    end,
}

local char, tweaks = {}, {}
local db = {
    enabled = true, frameStyle = "custom", zoneHeaders = true, zoneFirst = true, showUntracked = true,
    showTags = true, colorNames = true, completedLast = true, focusButtons = true, autoButtons = true,
    hideFinished = true, showRecipes = true, maxHeight = 100, collapseCompleted = true,
    autoMinimize = { dungeon = "minimize", taxi = "minimize", combat = "minimize" },
}
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    -- (the header icons, #159: Core.lua ns.BronzeIcon)
    BronzeIcon = {
        Apply = function(icon, path) icon:SetTexture(path); icon.FlareUI_Light = icon.FlareUI_Light or icon:GetParent():CreateTexture() end,
        Paint = function(icon) icon.bronzePainted = true end,
    },
    modules = { Tweaks = { initialized = true } },
    db = { profile = { objectivetracker = db, tweaks = tweaks } },
    PALETTE = { bronze4 = { 0.7, 0.4, 0.2 }, bronze5 = { 0.8, 0.6, 0.3 } },
    BORDER_COLOR = env.CreateColor(0.7, 0.4, 0.2, 1),
    CharDB = function() return char end,
    IsGamepadUI = function() return pad end,
    SoftColor = function(r, g, b) return (r + 0.5) / 2, (g + 0.5) / 2, (b + 0.5) / 2 end,
    LayoutHome = function(layouts, key)
        layouts[key] = layouts[key] or {}
        return layouts[key]
    end,
    EditSections = function()
        local settings = {}
        return function(_, entries) for _, entry in ipairs(entries) do settings[#settings + 1] = entry end end, settings
    end,
    GetFontPath = function(name) return "Fonts/" .. name end,
    SetFont = function(widget, ...) widget:SetFont(...) end,
    GetWantedFont = function(widget) return widget:GetFont() end,
    ApplyShadow = noop,
    PixelSize = function() return 1 end,
    BorderEdgeSize = function(_, size) return size end,
    OwnGameTooltip = function(owner, anchor)
        env.GameTooltip.lines = nil
        env.GameTooltip:SetOwner(owner, anchor)
    end,
    ShowDialog = function(key, _, data) dialog = { key, data } end,
}
ui:load("Modules/ObjectiveTracker.lua", ns)
local ot = ns.ObjectiveTracker
env.ObjectiveTrackerFrame = env.CreateFrame("Frame", nil, env.UIParent)
assert(ot:ShouldLoad())
ot:Init()
local holder = env.FlareUI_ObjectiveTracker
local header = ui:find(function(w) return w:GetParent() == holder and w.zone and w.title end)
local scroll = ui:find(function(w) return w:GetParent() == holder and w:IsObjectType("ScrollFrame") end)
assert(ot:GetFrame() == holder and holder:IsShown())

local function lineContains(text)
    return ui:find(function(w)
        return w:GetParent() == scroll:GetScrollChild() and w:IsShown()
            and w.text and w.text:GetText():find(text, 1, true)
    end)
end
local function event(name, ...)
    ui:emit(name, ...)
    ui:flushTimers()
end
local function click(text, button)
    assert(lineContains(text), text):Click(button)
    ui:flushTimers()
end

assert(header.title:GetText():find("5/25", 1, true))
assert(lineContains("Westfall").ftY > lineContains("Elwynn Forest").ftY, "current zone sorts first")
assert(lineContains("Patrol Moonbrook").ftY > lineContains("Collect the Oats").ftY, "completed quests sort last in their zone")
assert(lineContains("Local Untracked").text:GetAlpha() == ot.C.UNTRACKED_ALPHA)
assert(not lineContains("Hidden Task") and not lineContains("Scout returned"))
assert(lineContains("[14+ !]") and lineContains("[22 g3]"))
assert(lineContains("(Complete)") and not lineContains("Ready to turn in"))
assert(lineContains("Clean up the camp (75%)") and lineContains("Investigate the inn"))
assert(lineContains("50c / 100c") and lineContains("2/3 Linen Cloth"))
assert(holder.ScrollThumb:IsShown())
scroll:RunScript("OnMouseWheel", -1)
assert(scroll:GetVerticalScroll() == 40)
scroll:RunScript("OnMouseWheel", 1)
assert(scroll:GetVerticalScroll() == 0)

header.zone:Click()
assert(db.zoneOnly and lineContains("Time Remaining: 1:15"), "active timers stay visible outside the current zone")
assert(not lineContains("Deliver the Note"))
questTimes[1].questTimer = 25
ui:flushTimers()
-- Tick explicitly via a stale-then-current quest log; the UI fixture only fires each ticker once.
event("QUEST_LOG_UPDATE")
local timed = assert(lineContains("Time Remaining: 0:25"))
assert(timed.timerBar:GetValue() == 0.25)
questTimes[1].questTimer = 0
event("QUEST_LOG_UPDATE")
assert(lineContains("Time's up!").timerBar:GetValue() == 0)
header.zone:Click()
assert(not db.zoneOnly and lineContains("Deliver the Note"))

-- (11-25) By Zone and Level: the zones stay, with their quests by level
header.sort:Click("LeftButton")
assert(db.zoneFirst and db.zoneLevel and ot.Build.SortMode(db) == "zonelevel" and lineContains("Westfall"))
header.sort:Click("LeftButton")
assert(db.sortByDistance and not db.zoneLevel and ot.Build.SortMode(db) == "distance")
header.sort:Click("LeftButton")
assert(db.sortByLevel and not lineContains("Westfall"))
header.sort:Click("LeftButton")
assert(db.sortByProgress and not lineContains("Elwynn Forest"))
header.sort:Click("RightButton")
assert(db.sortByLevel)
header.sort:Click("RightButton")
header.sort:Click("RightButton")
assert(db.zoneFirst and db.zoneLevel)
header.sort:Click("RightButton")
assert(db.zoneFirst and not db.zoneLevel and lineContains("Westfall"))

header.autoAccept:Click()
assert(tweaks.autoAcceptQuests and header.autoAccept.active)
header.autoTurnIn:Click()
assert(tweaks.autoTurnInQuests and header.autoTurnIn.active)
header.autoAccept:RunScript("OnLeave")
assert(not env.GameTooltip:IsShown())

click("Westfall", "LeftButton")
assert(char.objectiveTracker.collapsedZones.Westfall and not lineContains("Patrol Moonbrook"))
click("Westfall", "LeftButton")
assert(not char.objectiveTracker.collapsedZones.Westfall and lineContains("Patrol Moonbrook"))
click("Collect the Oats", "MiddleButton")
assert(lineContains("Ready to turn in"), "an explicit expansion overrides auto-collapse")
click("Collect the Oats", "MiddleButton")
assert(not lineContains("Ready to turn in"))

click("Patrol Moonbrook", "RightButton")
assert(menu.title == "Patrol Moonbrook" and menu["Share Quest"].enabled)
menu["Share Quest"].run()
menu["Wowhead Link"].run()
menu["|cffff4040Abandon Quest|r"].run()
assert(shared == 21 and abandoned == 21 and dialog[1] == "FLAREUI_QUEST_LINK" and dialog[2]:find("quest=21", 1, true))
menu["Pin to Top"].run()
ui:flushTimers()
assert(char.objectiveTracker.pinned[21])

ui.control = true
click("Patrol Moonbrook", "LeftButton")
ui.control = false
assert(focused == 0 and focusChanges[#focusChanges] == 0)
assert(lineContains("Patrol Moonbrook").focusButton:IsShown())
lineContains("Patrol Moonbrook").focusButton:Click()
assert(focused == 21)

ui.shift, chatActive = true, true
click("Patrol Moonbrook", "LeftButton")
assert(chatLink == "|Hquest:21|h[Quest]|h" and watched[21])
chatActive, allowUntrack = false, false
click("Patrol Moonbrook", "LeftButton")
assert(watched[21] and #watchChanges == 0)
allowUntrack, ui.combat = true, true
click("Patrol Moonbrook", "LeftButton")
click("Patrol Moonbrook", "LeftButton")
assert(watched[21] and #watchChanges == 0, "combat toggles are deferred")
click("Collect the Oats", "LeftButton")
ot.SetWatched(999, true)
ot.SetFocus(11)
ot.SetFocus(21)
assert(#focusChanges == 2)
ui.shift, ui.combat = false, false
event("PLAYER_REGEN_ENABLED")
assert(watched[21] and not watched[22] and not watched[999] and watchChanges[1] == -22)
assert(#focusChanges == 3 and focused == 21, "apply only the latest deferred focus")
event("PLAYER_REGEN_ENABLED")
assert(#watchChanges == 1 and #focusChanges == 3)
click("Local Untracked", "RightButton")
menu["Track Quest"].run()
assert(watched[23])

click("Linen Boots", "RightButton")
assert(menu.title == "Linen Boots")
menu["Open Recipe"].run()
assert(openedRecipe == 101)
ui.shift = true
click("Linen Boots", "LeftButton")
ui.shift = false
event("TRACKED_RECIPE_UPDATE")
assert(not recipeTracked and not lineContains("Linen Boots"))

money = 150
event("PLAYER_MONEY")
assert(not lineContains("50c / 100c"))
event("PLAYER_ENTERING_WORLD")
assert(env.ObjectiveTrackerFrame:IsShown() and env.ObjectiveTrackerFrame:GetScale() == 0.001
    and env.ObjectiveTrackerFrame:GetAlpha() == 0, "park Blizzard's tracker without hiding it")
instance = "party"
event("ZONE_CHANGED_NEW_AREA")
assert(char.objectiveTracker.minimized and not scroll:IsShown())
instance = "none"
event("ZONE_CHANGED_NEW_AREA")
assert(not char.objectiveTracker.minimized and scroll:IsShown())
taxi = true
event("PLAYER_CONTROL_LOST")
assert(char.objectiveTracker.minimized)
taxi = false
event("PLAYER_CONTROL_GAINED")
assert(not char.objectiveTracker.minimized)

db.minimizeStyle = "button"
env.FlareUI_ToggleObjectiveTracker()
local mini = env.FlareUI_ObjectiveTrackerButton
assert(mini:IsShown() and not holder:IsShown())
mini:Click()
assert(not mini:IsShown() and holder:IsShown())
ot:SetNever(true)
assert(not holder:IsShown())
ot:SetNever(false)
assert(holder:IsShown())
ot:SetFadeAlpha(0.4)
assert(mini:GetAlpha() == 0.4)

local width, anchor = le.settings[1], le.settings[4]
assert(width.get() == 250 and anchor.get() == "auto")
width.set(nil, 320)
assert(holder:GetWidth() == 320)
anchor.set(nil, "BOTTOM")
assert(ot:ListBottom() and db.layouts.Modern.corner == "BOTTOMLEFT")
le.callbacks.layout("Modern")
ui:flushTimers()
assert(holder:GetPoint() == "BOTTOMLEFT")
if le.callbacks.enter then le.callbacks.enter(); le.callbacks.exit() end

local sample = ot.CreateSample(env.UIParent)
local minimized = ot.CreateSample(env.UIParent, "header")
local sampleWidth, sampleHeight = ot.DrawSample(sample)
assert(sampleWidth == 320 and sampleHeight == ot.C.HEADER + 100 + ot.C.LIST_TOP + ot.C.LIST_BOTTOM)
assert(sample.Window.ScrollThumb:IsShown() and sample.Bars[1]:GetValue() == 285 / 300)
assert(not sample.Lines[1]:IsMouseEnabled())
ot.DrawSample(minimized)
assert(minimized.Lone:IsShown() and not minimized.Window:IsShown())
db.minimizeStyle, db.frameStyle = "header", "blizzard"
ot:Refresh()
ot.DrawSample(minimized)
assert(not minimized.Lone:IsShown() and minimized.Window:GetHeight() == ot.C.HEADER + 3)
local _, _, _, alpha = holder:GetBackdropColor()
assert(alpha == 0)

-- Exercise the native header click and the log picker when the native tracker has no header.
env.IsModifierKeyDown = function() return ui.shift or ui.control end
env.GetQuestLogQuestText = function() return "", "Patrol the road and report to the inn." end
env.GetNumSubgroupMembers = function() return 1 end
env.C_TooltipInfo = { GetQuestPartyProgress = function()
    return { lines = { { leftText = "Aria: 4/4", leftColor = env.CreateColor(0.5, 0.5, 0.5, 1) } } }
end }
env.BreakUpLargeNumbers = tostring
env.GetQuestLogRewardXP = function() return 120 end
env.GetQuestLogRewardMoney = function() return 40 end
env.GetNumQuestLogRewards = function() return 1 end
env.GetNumQuestLogChoices = function() return 1 end
local rewardReady = false
env.GetQuestLogRewardInfo = function() if rewardReady then return "Moonbrook Banner", 2289, 2 end end
env.GetQuestLogChoiceInfo = function() return "Hat", 1122, 1 end
env.GameTooltip.IsOwned = function(self, owner) return self:GetOwner() == owner end
local nativeHeader = env.CreateFrame("Button", nil, env.UIParent)
env.QuestObjectiveTracker = { GetExistingBlock = function(_, id) if id == 21 then return { HeaderButton = nativeHeader } end end }
local patrol = assert(lineContains("Patrol Moonbrook"))
patrol.mouseOver = true
patrol:RunScript("OnEnter")
assert(ot.secureClick:GetAttribute("type1") == "click" and ot.secureClick:GetAttribute("clickbutton1") == nativeHeader)
assert(ot.secureClick:IsShown() and scroll:GetScrollChild().Highlight:IsShown())
local rewards = table.concat(env.GameTooltip.lines, "\n")
assert(rewards:find("120 XP", 1, true) and rewards:find("Hat", 1, true) and rewards:find("Aria: 4/4", 1, true))
assert(not rewards:find("Moonbrook Banner", 1, true))
rewardReady = true
ui:flushTimers()
assert(table.concat(env.GameTooltip.lines, "\n"):find("Moonbrook Banner x2", 1, true))
-- (11-24) the list scrolls under the mouse: the click must not stay with the quest that was there
scroll:RunScript("OnVerticalScroll", 10)
assert(not ot.secureClick:IsShown())
patrol:RunScript("OnEnter")
assert(ot.secureClick:IsShown())
ot.secureClick:RunScript("OnLeave")
ui:flushTimers()
assert(not env.GameTooltip:IsShown() and not ot.secureClick:IsShown())
patrol.mouseOver = false

local questButton = env.CreateFrame("Button", nil, env.UIParent)
env.QuestLogMicroButton = env.CreateFrame("Button", nil, env.UIParent)
env.QuestLogQuests_GetQuestButton = function(id) if id == 11 then return questButton end end
env.WorldMapFrame = env.CreateFrame("Frame", nil, env.UIParent)
env.WorldMapFrame:Hide()
env.QuestMapFrame = env.CreateFrame("Frame", nil, env.WorldMapFrame)
env.QuestMapFrame.DetailsFrame = env.CreateFrame("Frame", nil, env.QuestMapFrame)
env.QuestMapFrame.DetailsFrame:Hide()
local back = env.CreateFrame("Button", nil, env.QuestMapFrame.DetailsFrame)
env.QuestMapFrame.DetailsFrame.BackFrame = { BackButton = back }
local guard = assert(lineContains("Guard Supplies"))
ot.ShowSecureClick(guard)
local secure, picker = ot.secureClick, env.FlareUIQuestPick
assert(secure:GetAttribute("type1") == "macro" and not secure:GetAttribute("clickbutton1"))
secure:RunScript("PreClick", "LeftButton")
assert(secure:GetAttribute("macrotext1"):find("^/click QuestLogMicroButton"))
env.WorldMapFrame:Show()
env.QuestMapFrame:Hide()
secure:RunScript("PreClick", "LeftButton")
assert(secure:GetAttribute("macrotext1"):find("^/click QuestLogMicroButton"), "the map open without its log")
env.QuestMapFrame:Show()
secure:RunScript("PreClick", "LeftButton")
assert(secure:GetAttribute("macrotext1") == "/click FlareUIQuestPick\n/click FlareUIQuestPick\n/click FlareUIQuestPick\n/click FlareUIQuestPick")
picker:RunScript("PreClick")
assert(picker:GetAttribute("useOnKeyDown") == false, "the macro's /click is a release")
assert(picker:GetAttribute("clickbutton") == questButton)
-- a title under a folded heading: the heading first, only while it is folded
do
    local info, headerOf = env.C_QuestLog.GetInfo, env.C_QuestLog.GetHeaderIndexForQuest
    local heading = env.CreateFrame("Button", nil, env.WorldMapFrame)
    heading.questLogIndex = 77
    local folded = true
    env.C_QuestLog.GetHeaderIndexForQuest = function(id) if id == 11 then return 77 end end
    env.C_QuestLog.GetInfo = function(index)
        if index == 77 then return { isHeader = true, isCollapsed = folded } end
        return info(index)
    end
    env.QuestScrollFrame = { headerFramePool = { EnumerateActive = function() return pairs({ [heading] = true }) end } }
    questButton:Hide()
    picker:RunScript("PreClick")
    assert(picker:GetAttribute("clickbutton") == heading)
    folded = false
    picker:RunScript("PreClick")
    assert(picker:GetAttribute("clickbutton") == back, "Back draws the list at once; Blizzard's own comes a frame later")
    picker:RunScript("PreClick")
    assert(picker:GetAttribute("clickbutton") == nil, "once, and never folds it again")
    questButton:Show()
    picker:RunScript("PreClick")
    assert(picker:GetAttribute("clickbutton") == questButton)
    -- a quest with no place on the map (a writ), from another quest's open details: every step, in order
    local details = env.QuestMapFrame.DetailsFrame
    local drawn, steps = false, {}
    folded = true
    details.questID = 21
    details:Show()
    for i = 1, 4 do
        if drawn and not folded then questButton:Show() else questButton:Hide() end
        picker:RunScript("PreClick")
        local step = picker:GetAttribute("clickbutton")
        steps[i] = step == back and "back" or step == heading and "heading" or step == questButton and "quest" or "none"
        if step == back then details:Hide() drawn = not folded end
        if step == heading then folded = false end
    end
    assert(table.concat(steps, " ") == "back heading back quest", table.concat(steps, " "))
    details.questID = nil
    env.C_QuestLog.GetInfo, env.C_QuestLog.GetHeaderIndexForQuest, env.QuestScrollFrame = info, headerOf, nil
end
env.QuestMapFrame.DetailsFrame.questID = 21
env.QuestMapFrame.DetailsFrame:Show()
picker:RunScript("PreClick")
assert(picker:GetAttribute("clickbutton") == back)
ui.combat = true
ot.HideSecureClick()
assert(secure:IsShown(), "a protected hover cannot hide in lockdown")
ui.combat = false
ot.HideSecureClick()
assert(not secure:IsShown())

-- the Gamepad UI: FlareUI only says to open the quest log. It never turns Blizzard's page itself, even once
-- the log is open (that ran Blizzard's controller focus in FlareUI's name; 11-23)
local details
env.QuestMapFrame_ShowQuestDetails = function(id) details = id end
pad = true
env.WorldMapFrame:Hide()
local before = #ui.errors
guard:Click()
assert(not details and #ui.errors == before + 1)
env.WorldMapFrame:Show()
ui:flushTimers()
assert(not details)
ui.combat = true
ot.PickForQuestLog()
ui.combat = false
assert(#ui.errors == before + 2)
pad = false

-- what the controller's navigation uses (PadTracker.lua; its own test: pad-tracker.lua)
local padded = env.CreateFrame("Button", nil, env.UIParent)
assert(ot.Pad.Parts().holder == holder and ot.Pad.Parts().scroll == scroll and #ot.Pad.Parts().lines > 0)
assert(ot.Pad.AimDetails(padded, 21) and padded:GetAttribute("clickbutton") == nativeHeader)
nativeHeader:SetParent(nil)
assert(not ot.Pad.QuestIcon(21) and not ot.Pad.QuestIcon(11))
local block = env.CreateFrame("Frame", nil, env.UIParent)
nativeHeader:SetParent(block)
block.poiButton = env.CreateFrame("Button", nil, block)
assert(ot.Pad.QuestIcon(21) == block.poiButton)
env.WorldMapFrame:Hide()
assert(ot.Pad.AimDetails(padded, 11) and padded:GetAttribute("type") == "macro" and picker.questID == 11)
assert(padded:GetAttribute("macrotext") == "/click QuestLogMicroButton\n/click FlareUIQuestPick\n/click FlareUIQuestPick\n/click FlareUIQuestPick\n/click FlareUIQuestPick")
env.WorldMapFrame:Show()
assert(ot.Pad.AimDetails(padded, 11) and padded:GetAttribute("macrotext") == "/click FlareUIQuestPick\n/click FlareUIQuestPick\n/click FlareUIQuestPick\n/click FlareUIQuestPick")
assert(not ot.Pad.AimDetails(padded, 999), "no such quest in the log")
local wasPinned = ot.Pad.IsPinned(11)
ot.Pad.TogglePinned(11)
ui:flushTimers()
assert((ot.Pad.IsPinned(11) and true or false) ~= (wasPinned and true or false))
ot.Pad.TogglePinned(11)
ui:flushTimers()
local drawn = 0
ns.PadTracker = { OnTrackerDrawn = function() drawn = drawn + 1 end }
ot:Render()
assert(drawn > 0 and not ot:IsSettingsPreview())
ns.PadTracker.open = "list"
assert(ot:IsSettingsPreview(), "a faded tracker shows while the controller is in it")
ns.PadTracker = nil

-- Quest items are assigned secure attributes outside combat and keep their slot during lockdown.
for _, state in ipairs({ "Normal", "Pushed", "Highlight" }) do
    Widget["Set" .. state .. "Atlas"] = function(self, atlas) self["Set" .. state .. "Texture"](self, atlas) end
end
local itemRange = 0
env.GetQuestLogSpecialItemInfo = function(logIndex)
    if logIndex == 2 then return "|Hitem:99|h[Beacon]|h", 2000, 2, false end
end
env.GetQuestLogSpecialItemCooldown = function() return 3, 5, true end
env.CooldownFrame_Set = function(widget, start, duration) widget:SetCooldown(start, duration) end
env.IsQuestLogSpecialItemInRange = function() return itemRange end
env.UnitExists = function() return true end
-- (11-25, #198) the public API: each row in view, where another addon's button goes beside it
local api, seen = assert(env.FlareUI_QuestTrackerAPI), nil
assert(api.version == 1 and api:IsActive())
api:RegisterCallback("Next", function(rows) seen = rows end)
api:RegisterCallback("Broken", function() error("theirs") end)
local caught = 0
env.geterrorhandler = function() return function() caught = caught + 1 end end
ot:UpdateItemButtons()
local item = assert(env.FlareUI_TrackerItem1)
assert(seen and #seen > 0 and seen == api:GetRows() and caught == 1, "every callback, one failing")
do
    local withItem, plain
    for _, row in ipairs(seen) do
        assert(type(row.questID) == "number" and row.size > 0 and row.point:find("^TOP") and row.line)
        if row.hasItem then withItem = row else plain = row end
    end
    assert(withItem and plain, "a row with the quest's item and one without")
    local _, _, _, itemX = item:GetPoint(1)
    local dir = withItem.point == "TOPRIGHT" and -1 or 1
    assert(withItem.x == itemX + dir * (withItem.size + 3), "past the item button")
end
api:UnregisterCallback("Broken")
api:UnregisterCallback("Next")
assert(not pcall(api.RegisterCallback, api, nil, nil))
assert(item:IsShown() and item:GetAttribute("item") == "item:99" and item.count:GetText() == "2")
assert(item.cooldown.cooldown[2] == 5 and item.out)
itemRange = 1
ui:emit("PLAYER_TARGET_CHANGED")
assert(not item.out)
-- the log's order moves: the button follows its quest, and its charges follow the bags
do
    local index, info = env.C_QuestLog.GetLogIndexForQuestID, env.GetQuestLogSpecialItemInfo
    assert(item.questID)
    env.C_QuestLog.GetLogIndexForQuestID = function(id) return id == item.questID and 7 or index(id) end
    assert(ot.ItemIndex(item) == 7)
    env.GetQuestLogSpecialItemInfo = function(logIndex) if logIndex == 7 then return "|Hitem:99|h[Beacon]|h", 2000, 5 end end
    ot:UpdateItemCounts()
    assert(item.count:GetText() == "5")
    env.C_QuestLog.GetLogIndexForQuestID, env.GetQuestLogSpecialItemInfo = index, info
    ot:UpdateItemCounts()
end
-- faded right out, its button takes no clicks; a fight's start gives them back
ot:SetFadeAlpha(0)
assert(not item:IsMouseEnabled())
ot.ItemMouse(true)
assert(item:IsMouseEnabled())
ot:SetFadeAlpha(1)
assert(item:IsMouseEnabled())
item.mouseOver = true
assert(ot:IsMouseOverExtras())
item.mouseOver = false
ui:emit("PLAYER_REGEN_DISABLED")
ui.combat = true
ot:SetMinimized(true)
assert(item:IsShown(), "combat keeps existing secure item positions")
ui.combat = false
event("PLAYER_REGEN_ENABLED")
assert(not item:IsShown())
ot:SetMinimized(false)
assert(item:IsShown())

-- Scenario criteria cover weighted, ordinary, and formatted progress.
env.C_Scenario = {
    IsInScenario = function() return true end,
    GetInfo = function() return "Trial at the Inn" end,
    GetStepInfo = function() return "Secure the Cellar", nil, 3 end,
}
env.C_ScenarioInfo = { GetCriteriaInfo = function(i)
    return ({
        { description = "Search crates", quantity = 40, totalQuantity = 100, isWeightedProgress = true },
        { description = "Rescue scouts", quantity = 2, totalQuantity = 5 },
        { description = "Signal sent", quantity = 1, totalQuantity = 1, completed = true, isFormatted = true },
    })[i]
end }
ot:Render()
assert(lineContains("Trial at the Inn") and lineContains("Secure the Cellar"))
assert(lineContains("Search crates (40%)") and lineContains("2/5 Rescue scouts") and lineContains("Signal sent"))
click("Trial at the Inn", "LeftButton")
assert(not lineContains("Search crates"))
click("Trial at the Inn", "LeftButton")
assert(lineContains("Search crates (40%)"))
env.C_Scenario = nil

-- Use the real quest button and Wayfarer's queue contract through the title-row controls.
local queue = { items = {} }
function queue:RemoveWhere(match)
    for i, row in ipairs(self.items) do if match(row) then table.remove(self.items, i); break end end
end
env.WayfarerRU = {
    Core = { QuestVoice = function(_, id) if id == 21 then return "Voice line" end end },
    QuestLog = { Play = function(_, id) queue.items[1] = { questID = id } end },
    Queue = queue,
}
db.playButtons, db.questIcons, db.focusButtons = true, true, false
ot:Render()
patrol = lineContains("Patrol Moonbrook")
assert(patrol.questIcon:IsShown() and patrol.questIcon.glow:IsShown())
patrol.questIcon:RunScript("OnMouseDown")
assert(patrol.questIcon.ring:GetAtlas():find("Pressed", 1, true))
patrol.questIcon:RunScript("OnMouseUp")
local voice = patrol.playButton
assert(voice:IsShown() and voice.ftVoice == "play")
voice:Click()
assert(voice.ftVoice == "stop" and queue.items[1].questID == 21)
voice:Click()
assert(voice.ftVoice == "replay" and #queue.items == 0)
assert(not (lineContains("Guard Supplies").playButton and lineContains("Guard Supplies").playButton:IsShown()))

-- Accepted quests slide in, and progress updates animate the matching line.
local newQuest = { questID = 26, title = "Fresh Orders", level = 23 }
log[#log + 1] = newQuest
watched[26] = true
db.keepFocus = true
ui.time = 150
ot.KeepFocusChanged()
event("QUEST_ACCEPTED", 26)
assert(lineContains("Fresh Orders").moveAnim:IsPlaying())
focused = 26
event("SUPER_TRACKING_CHANGED")
assert(focused == 21, "accepting a quest restores the player's existing focus")
objectives[21][1].numFulfilled = 4
event("QUEST_LOG_UPDATE")
local progressLine = assert(lineContains("Clean up the camp"))
assert(progressLine.sheen and progressLine.sheen.anim:IsPlaying())
progressLine.sheen.anim:RunScript("OnFinished")
assert(not progressLine.sheen:IsShown())

pad, db.padBlizzard = true, true
assert(not ot:ShouldLoad())
db.padBlizzard = false
assert(ot:ShouldLoad())
print("PASS: quest tracker sorting, watch and focus, timers, recipes, auto-minimize and preview")
