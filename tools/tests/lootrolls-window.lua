local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local Widget = getmetatable(env.UIParent)
local function noop() end
function Widget:SetHighlightAtlas(atlas) self:SetHighlightTexture(atlas) end
function Widget:SetLooping(value) self.looping = value end
function Widget:SetDuration(value) self.duration = value end
function Widget:GetDuration() return self.duration end
function Widget:IsOwned(owner) return self:GetOwner() == owner end
env.GameTooltip.SetLootRollItem = function(self, id) self.rollID = id end
env.GameTooltip.SetHyperlink = function(self, link) self.link = link end
env.GameTooltip.AddDoubleLine = function(self, left, right) self:AddLine(left .. "=" .. right) end
env.GameTooltip_Hide = function() env.GameTooltip:Hide() end
env.IsModifiedClick = function(action) return action == "COMPAREITEMS" and env.shiftDown == true end
env.HandleModifiedItemClick = function(link) ui.modifiedLink = link end
env.NEED, env.GREED, env.PASS = "Need", "Greed", "Pass"
env.INVTYPE_WAIST = "Waist"
env.RETRIEVING_ITEM_INFO = "Retrieving"
env.LOOT_ROLL_INELIGIBLE_REASON1 = "Cannot equip this item"
env.ITEM_QUALITY_COLORS = { [3] = env.CreateColor(0, 0.5, 1, 1) }
local restricted = {}
env.canaccessvalue = function(value) return value ~= restricted end
env.UnitClass = function() return "Mage", "MAGE" end
env.UnitName = function() return "Frost" end
env.GetNumGroupMembers = function() return 3 end
env.C_ClassColor = { GetClassColor = function() return env.CreateColor(0, 0.5, 1, 1) end }
env.GameEvent = { UnregisterInternalEvent = function(event) ui.mutedEvent = event end }
env.ToggleLootHistoryFrame = function() ui.historyToggled = true end

local callbacks, edit = {}, {}
function edit:AddFrame(holder, move) self.holder, self.move = holder, move end
function edit:AddFrameSettings(_, settings) self.scale, self.rows = settings[1], settings end
function edit:RefreshFrameSettings(frame) assert(frame == self.holder) self.refreshed = true end
function edit:RegisterCallback(event, callback) callbacks[event] = callback end
function edit:GetActiveLayoutName() return "Modern" end
edit.SettingType = { Slider = "slider", Checkbox = "checkbox" }
env.LibStub = function(name)
    if name == "FlareEditMode" then return edit end
    assert(name == "LibSharedMedia-3.0")
    return { Fetch = function(_, kind, value) return kind .. "/" .. value end }
end
local clock, timers = 100, {}
env.GetTime = function() return clock end
local function queue(delay, callback, repeating)
    local timer = { at = clock + delay, delay = repeating and delay, callback = callback }
    function timer:Cancel() self.cancelled = true end
    timers[#timers + 1] = timer
    return timer
end
env.C_Timer.After = function(delay, callback) queue(delay, callback) end
env.C_Timer.NewTicker = function(delay, callback) return queue(delay, callback, true) end
local function advance(delta)
    local target = clock + delta
    local runs = 0
    while true do
        local index, due
        for i, timer in ipairs(timers) do
            if not timer.cancelled and timer.at <= target + 1e-6 and (not due or timer.at < due.at) then index, due = i, timer end
        end
        if not due then break end
        assert(runs < 1000, "unexpected timer loop")
        runs = runs + 1
        clock = due.at
        table.remove(timers, index)
        due.callback()
        if due.delay and not due.cancelled then
            due.at = due.at + due.delay
            timers[#timers + 1] = due
        end
    end
    clock = target
end

local native = env.CreateFrame("Frame", "GroupLootFrame1", env.UIParent)
native.IconFrame = env.CreateFrame("Frame", nil, native)
native.LootButtonContainer = { NeedButton = env.CreateFrame("Button", nil, native) }
local nativeContainer = env.CreateFrame("Frame", "GroupLootContainer", env.UIParent)
nativeContainer:SetHeight(40)

local links = {
    [21] = "|Hitem:101:0|h[Silver Belt]|h", [22] = "|Hitem:101:0|h[Silver Belt]|h", [23] = "|Hitem:102:0|h[Boots]|h",
    [24] = "|Hitem:103:0|h[Ring]|h", [25] = "|Hitem:104:0|h[Staff]|h",
}
local names = { [21] = "Silver Belt", [22] = "Silver Belt", [23] = "Boots", [24] = "Ring", [25] = "Staff" }
env.GetActiveLootRollIDs = function() return { 21 } end
env.C_Loot = { GetLootRollDuration = function() return 30000 end }
local ready, timeLeft = false, 30000
env.GetLootRollItemInfo = function(id)
    if id == 21 and not ready then return end
    return id + 1000, names[id], id == 21 and 2 or 1, 3, id == 21, id ~= 23, true, nil, id == 23 and 1 or nil
end
env.GetLootRollItemLink = function(id) return links[id] end
env.GetLootRollTimeLeft = function() return timeLeft end
env.C_Item = {
    GetItemInfoInstant = function() return 101, "Armor", "Cloth", "INVTYPE_WAIST", nil, 4, 1 end,
    GetDetailedItemLevelInfo = function() return 31 end,
    GetItemInfo = function(id) return "Sample " .. id, "|Hitem:" .. id .. "|h[Sample]|h", 3 end,
    GetItemIconByID = function(id) return 100 + id end,
}
local drops = {}
env.C_LootHistory = {
    GetLootHistoryTime = function() return 1000 end,
    GetAllEncounterInfos = function() return { { encounterID = 5 } } end,
    GetSortedDropsForEncounter = function(id) assert(id == 5); return drops end,
    GetSortedInfoForDrop = function(id, index) assert(id == 5); return drops[index] end,
}
local rollClicks, confirms, popup = {}, {}, nil
env.RollOnLoot = function(id, choice) rollClicks[#rollClicks + 1] = { id, choice } end
env.ConfirmLootRoll = function(id) confirms[#confirms + 1] = id end
env.StaticPopup_FindVisible = function(name)
    assert(name == "CONFIRM_LOOT_ROLL")
    return popup
end
env.StaticPopup_Hide = function(name, id)
    assert(name == "CONFIRM_LOOT_ROLL")
    if popup and popup.data == id then popup = nil end
end
local tweaks = { lootRolls = true, lootRollsOpacity = 0.75, lootRollFont = { size = 14, flags = "NONE" } }
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }), modules = {},
    db = { profile = { tweaks = tweaks } }, PALETTE = { warmGrey = { 0.5, 0.45, 0.4 } },
    BORDER_COLOR = env.CreateColor(0.6, 0.5, 0.4, 1),
    IsGamepadUI = function() return ui.gamepad == true end,
    BagModuleOn = function() return true end,
    GetFontPath = function(face) return "Fonts/" .. (face or "Default") end,
    SetFont = function(widget, ...) widget:SetFont(...) end,
    SetFontFamily = function(widget, ...) widget:SetFont(...) end,
    ApplyShadow = noop,
    BorderEdgeSize = function(_, size) return size end,
    OwnGameTooltip = function(owner, anchor)
        env.GameTooltip:SetOwner(owner, anchor)
        env.GameTooltip.lines = nil
    end,
    BronzeIcon = { Apply = function(icon, file) icon:SetTexture(file) end, Paint = noop },
    LayoutHome = function(layouts, key)
        layouts[key] = layouts[key] or {}
        return layouts[key]
    end,
    EditSections = function()
        local all = {}
        return function(key, rows)
            for _, row in ipairs(rows) do row.section = key all[#all + 1] = row end
        end, all
    end,
    DamageMeter = { HeaderFontDb = function() return { face = "Medieval", size = 16 } end },
}
ui:load("Modules/LootRolls.lua", ns)
local lr = ns.LootRolls
assert(lr:ShouldLoad())
ui.gamepad = true
assert(not lr:ShouldLoad())
ui.gamepad = false
lr:Init()
local win = assert(ui:find(function(w) return w.title and w.title:GetText() == "Loot Rolls" end))
assert(ui.mutedEvent == "START_LOOT_ROLL" and native:IsShown() and native:GetAlpha() == 0)
assert(not native.IconFrame:IsMouseEnabled() and not native.LootButtonContainer.NeedButton:IsMouseEnabled())
nativeContainer:SetHeight(70)
assert(nativeContainer:GetHeight() == 1)
assert(not win:IsShown() and edit.holder:GetPoint() == "TOP")
-- (11-23: no Background Opacity; an old saved value no longer applies, the rock is always full)
assert(select(2, win.title:GetFont()) == 16 and win.skin[1]:GetAlpha() == 1)
local history = ui:find(function(w) return w:GetParent() == win and w:IsObjectType("Button") and w ~= win.close end)
history:RunScript("OnEnter")
assert(env.GameTooltip:GetText() == "Loot History")
history:Click()
assert(ui.historyToggled)
history:RunScript("OnLeave")

local function visible(id, big)
    return ui:find(function(w) return w.big == big and w:IsVisible() and w.session and w.session.rollID == id end)
end
ui:emit("PLAYER_ENTERING_WORLD")
local first = assert(visible(21, true))
assert(first.name:GetText() == "Retrieving" and not first.need:IsShown())
ready = true
advance(0.26)
assert(first.name:GetText() == "Silver Belt" and first.count:GetText() == "2")
assert(first.mine:GetText():find("31", 1, true) and first.mine:GetText():find("Waist, Cloth", 1, true))
first.icon:RunScript("OnEnter")
assert(env.GameTooltip.rollID == 21)
first.icon:Click()
assert(ui.modifiedLink == links[21])
first.icon:RunScript("OnLeave")
timeLeft = 4900
first:RunScript("OnUpdate", 0.02)
assert(first.timer.pulse:IsPlaying() and first.timeText:GetText() == "5")
first.need:Click()
assert(rollClicks[1][1] == 21 and rollClicks[1][2] == 1 and first.mine:GetText() == "You: Need")
ui:emit("CONFIRM_LOOT_ROLL", 21)
popup = { data = 21 }
advance(0.11)
popup = nil
advance(0.11)
assert(not first.mine:GetText():find("You:", 1, true), "cancelled bind confirmation clears the tentative choice")
first.greed:Click()
ui:emit("CONFIRM_LOOT_ROLL", 21)
popup = { data = 21 }
env.ConfirmLootRoll(21)
advance(0.11)
assert(first.mine:GetText() == "You: Greed" and confirms[1] == 21)

timeLeft = 25000
for id = 22, 25 do ui:emit("START_LOOT_ROLL", id, 30000) end
assert(win.count:GetText() == "(5)" and not visible(25, true))
local unable = assert(visible(23, true))
assert(not unable.need:IsEnabled() and unable.need.reason == "Cannot equip this item")
unable.need:RunScript("OnEnter")
assert(env.GameTooltip.lines[1] == unable.need.reason)
unable.need:RunScript("OnLeave")
unable.pass:Click()
assert(#rollClicks == 2, "a freshly placed card cannot roll under the pointer")
advance(0.21)
unable.pass:Click()
assert(rollClicks[3][1] == 23 and rollClicks[3][2] == 0)
ui:emit("CANCEL_LOOT_ROLL", 23)
assert(visible(25, true) and not visible(23, false), "passing opens the next queued card")

local leader = { playerName = "Needle", playerClass = "MAGE", state = 0, roll = 82 }
local me = { playerName = "Frost", playerClass = "MAGE", state = 3, roll = 95, isSelf = true }
local waiting = { playerName = "Skald", state = 4, roll = restricted }
drops[1] = { lootListKey = 11, itemHyperlink = links[21], startTime = 997, playerRollState = 3,
    currentLeader = leader, rollInfos = { me, waiting, leader, { playerName = restricted } } }
ui:emit("LOOT_HISTORY_UPDATE_DROP", 5, 1)
assert(not first.session.key, "identical drops stay unbound before one's choice is finalized")
ui:emit("CANCEL_LOOT_ROLL", 21)
local lost = assert(visible(21, false))
assert(lost:GetAlpha() == 0.6 and lost.result:GetText():find("Needle", 1, true))
assert(lost.roll:GetText() == "95", "Need beats a higher Greed roll")
lost:RunScript("OnEnter")
assert(env.GameTooltip.lines[2]:find("Needle=Need  82", 1, true))
assert(env.GameTooltip.lines[3]:find("Frost", 1, true) and env.GameTooltip.lines[4] == "Skald=...")
lost:RunScript("OnLeave")
lost.close:Click()
assert(not visible(21, false))

local second = assert(visible(22, true))
advance(0.25)
second.need:Click()
ui:emit("CANCEL_LOOT_ROLL", 22)
local winner = { playerName = "Frost", playerClass = "MAGE", state = 0, roll = 99, isSelf = true, isWinner = true }
drops[2] = { lootListKey = 12, itemHyperlink = links[22], startTime = 1000, playerRollState = 0, winner = winner,
    rollInfos = { winner, leader, { playerName = "Skald", state = 5 } } }
ui:emit("LOOT_HISTORY_UPDATE_ENCOUNTER", 5)
local won = assert(visible(22, false))
assert(won.won:IsShown() and won.result:GetText():find("99", 1, true) and not won.chosen:IsShown())
won.mouseOver = true
advance(6.1)
assert(visible(22, false), "settled row waits until the pointer leaves")
won.mouseOver = false
advance(1.1)
assert(not visible(22, false))

ui.gamepad = true
ui:emit("INPUT_DEVICE_INTERFACE_TRANSITION")
advance(0)
assert(not win:IsShown())
ui.gamepad = false
ui:emit("INPUT_DEVICE_INTERFACE_TRANSITION")
advance(0)
assert(win:IsShown())
ui:emit("CANCEL_ALL_LOOT_ROLLS")
assert(win.out:IsPlaying())
win.out:RunScript("OnFinished")
assert(not win:IsShown())

callbacks.enter()
assert(lr.previewing and win:IsShown() and edit.holder:GetHeight() > 26)
assert(win:GetFrameStrata() == "HIGH", "behind Blizzard's Edit Mode dialog (11-27)")
assert(ui:find(function(w) return w.session and w.session.sample and w:IsVisible() end))
edit.scale.set(nil, 125)
assert(edit.scale.get() == 125 and win:GetScale() == 1.25)
edit.move(nil, "Modern", "TOP", 17, -129)
assert(tweaks.moverLayouts.Modern.loot.x == 17)
callbacks.exit()
assert(not lr.previewing and edit.holder:GetHeight() == 26 * 1.25)
assert(win:GetFrameStrata() == "DIALOG", "out of Edit Mode: above every window again")
assert(lr.ApplyOpacity == nil and win.skin[1]:GetAlpha() == 1)
-- Fade in Combat (11-24): off until picked, back under the pointer, in a roll's last seconds and after the fight
do
    local opacity, switch
    for _, row in ipairs(edit.rows) do
        if row.name == "Faded Opacity" then opacity = row elseif row.name == "Fade in Combat" then switch = row end
    end
    assert(opacity.section == "Fading" and switch.section == "Fading" and edit.scale.section == "Frame")
    assert(switch.get() == false and opacity.hidden() and opacity.get() == 30 and opacity.formatter(30) == 30)
    timeLeft = 30000
    names[31], names[32], links[31], links[32] = "Cloak", "Wand", "|Hitem:131:0|h[Cloak]|h", "|Hitem:132:0|h[Wand]|h"
    ui:emit("START_LOOT_ROLL", 31, 30000)
    assert(win:IsShown())
    ui:emit("PLAYER_REGEN_DISABLED")
    assert(win:GetAlpha() == 1 and not win.fader:IsShown(), "off: nothing fades")
    switch.set(nil, true)
    assert(edit.refreshed and not opacity.hidden() and win.fader:IsShown() and math.abs(win:GetAlpha() - 0.3) < 0.001)
    local function tick(elapsed) win.fader:RunScript("OnUpdate", elapsed) end
    -- the pointer brings it back, with the click guard; then it fades again, over FADE_TIME
    win.mouseOver = true
    tick(0.2)
    assert(win:GetAlpha() == 1)
    local clicks = #rollClicks
    visible(31, true).need:Click()
    assert(#rollClicks == clicks, "a click as it comes back rolls nothing")
    win.mouseOver = false
    tick(0.1)
    tick(0.05)
    assert(win:GetAlpha() < 1 and win:GetAlpha() > 0.3)
    tick(0.5)
    assert(math.abs(win:GetAlpha() - 0.3) < 0.001)
    -- the last seconds of an undecided roll
    timeLeft = 4000
    tick(0.2)
    assert(win:GetAlpha() == 1)
    timeLeft = 30000
    tick(0.2)
    tick(0.5)
    assert(win:GetAlpha() < 0.31)
    opacity.set(nil, 0)
    assert(opacity.get() == 0 and tweaks.lootRollFadeOpacity == 0 and win:GetAlpha() == 0)
    opacity.set(nil, 30)
    assert(tweaks.lootRollFadeOpacity == nil)
    -- the samples show at full
    callbacks.enter()
    assert(win:GetAlpha() == 1 and not win.fader:IsShown())
    callbacks.exit()
    assert(win.fader:IsShown())
    -- it opens faded in a fight, and leaves from there
    ui:emit("CANCEL_ALL_LOOT_ROLLS")
    assert(win.out:IsPlaying())
    win.out:RunScript("OnFinished")
    assert(not win:IsShown())
    ui:emit("START_LOOT_ROLL", 32, 30000)
    assert(win:IsShown() and math.abs(win:GetAlpha() - 0.3) < 0.001)
    ui:emit("PLAYER_REGEN_ENABLED")
    assert(win:GetAlpha() == 1 and not win.fader:IsShown())
    switch.set(nil, false)
    assert(tweaks.lootRollFade == nil and opacity.hidden())
end
-- (11-24) a roll past its time stays while the game still lists it, with no nonsense time, and goes once it doesn't
do
    local active, open = env.GetActiveLootRollIDs, true
    env.GetActiveLootRollIDs = function() return open and { 41 } or {} end
    ui:emit("START_LOOT_ROLL", 41, 10000)
    local card = assert(visible(41, true))
    timeLeft = 69812000
    card:RunScript("OnUpdate", 0.02)
    assert(tonumber(card.timeText:GetText()) <= 10, "our own clock")
    advance(21)
    assert(card.session and card.session.status == "rolling" and card.session.choice == nil)
    -- (siiloquin, 11-27) Shift over the row: the item (Blizzard adds the comparison), else everyone's rolls;
    -- pressing or letting go of Shift while pointing makes the tooltip again
    env.GameTooltip.rollID = nil
    env.shiftDown = false
    card:RunScript("OnEnter")
    assert(env.GameTooltip.rollID == nil, "no Shift: the rolls")
    env.shiftDown = true
    card.IsMouseOver = function() return true end
    card.icon.IsMouseOver = function() return false end
    card:RunScript("OnEvent", "MODIFIER_STATE_CHANGED")
    assert(env.GameTooltip.rollID == 41, "Shift: the item, with its comparison")
    card:RunScript("OnLeave")
    env.shiftDown = false
    card:RunScript("OnUpdate", 0.02)
    assert(card.timeText:GetText() == 0 or card.timeText:GetText() == "0")
    open = false
    local session = card.session
    advance(5.1)
    assert(session.status ~= "rolling")
    -- one the game never drops from its list is let go in the end
    open = true
    env.GetActiveLootRollIDs = function() return { 42 } end
    ui:emit("START_LOOT_ROLL", 42, 10000)
    local stuck = assert(visible(42, true)).session
    for _ = 1, 30 do advance(10) end
    assert(stuck.status == "rolling")
    advance(20)
    assert(stuck.status ~= "rolling")
    env.GetActiveLootRollIDs, timeLeft = active, 30000
end
tweaks.lootRollFont.size = 17
lr:ApplyFont()
assert(select(2, first.name:GetFont()) == 17)
-- (11-27) the header's Close: rolls that ended go, as with their own x; one still waiting for your choice stays
do
    local active = env.GetActiveLootRollIDs
    links[71], names[71], links[72], names[72] = "|Hitem:171:0|h[Gem]|h", "Gem", "|Hitem:172:0|h[Cloak]|h", "Cloak"
    env.GetActiveLootRollIDs = function() return { 71, 72 } end
    ui:emit("START_LOOT_ROLL", 71, 30000)
    ui:emit("START_LOOT_ROLL", 72, 30000)
    advance(0.3)
    -- (the history knows who took it: the roll ends as a row of its own, as roll 21's did)
    local taker = { playerName = "Needle", playerClass = "MAGE", state = 0, roll = 70, isWinner = true }
    drops[#drops + 1] = { lootListKey = 71, itemHyperlink = links[71], startTime = 1000, playerRollState = 0, winner = taker,
        rollInfos = { taker } }
    ui:emit("LOOT_HISTORY_UPDATE_DROP", 5, #drops)
    env.GetActiveLootRollIDs = function() return { 72 } end
    ui:emit("CANCEL_LOOT_ROLL", 71)
    ui:emit("LOOT_HISTORY_UPDATE_ENCOUNTER", 5)
    advance(0.1)
    local ended = ui:find(function(w) return w:IsVisible() and w.session and w.session.rollID == 71 end)
    local endedSession = ended and ended.session
    win.close:Click()
    assert(endedSession and endedSession.status ~= "rolling", "the roll ended as a row of its own")
    assert(endedSession.dismissed, "an ended roll goes")
    assert(not ui:find(function(w) return w:IsVisible() and w.session and w.session.rollID == 71 end))
    assert(ui:find(function(w) return w:IsVisible() and w.session and w.session.rollID == 72 end), "a roll waiting for your choice stays")
    env.GetActiveLootRollIDs = active
end

print("PASS: loot rolls, bind confirmation, duplicate drops, outcomes, keyboard/gamepad and Edit Mode")
