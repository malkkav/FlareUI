local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local Widget = getmetatable(env.UIParent)
local function noop() end
local function isProtected(self) return self.protected == true end
local function isOwned(self, owner) return self:GetOwner() == owner end
Widget.IsProtected, Widget.IsOwned = isProtected, isOwned

function Widget:SetMultiLine(value) self.multiline = value end
function Widget:SetLooping(value) self.looping = value end

function Widget:GetHorizontalScroll() return self.horizontalScroll or 0 end
function Widget:GetHorizontalScrollRange()
    return math.max(0, self:GetScrollChild():GetWidth() - self:GetWidth())
end
function Widget:SetHorizontalScroll(value)
    local old = self:GetHorizontalScroll()
    self.horizontalScroll = value
    if old ~= value then self:RunScript("OnHorizontalScroll", value) end
end

local cv = {
    chatStyle = "classic", Sound_MasterVolume = 0.5, showTimestamps = "none", whisperMode = "inline",
}
env.C_CVar = {
    GetCVar = function(key) return cv[key] end,
    SetCVar = function(key, value) cv[key] = tostring(value); ui:emit("CVAR_UPDATE", key) end,
}
env.C_AddOns.IsAddOnLoaded = function(name) return name == "MisspelledForever" end
env.time = function() return 1000 end
env.TimeUtil = { BetterDate = function(format, at) return os.date("!" .. format, at) end }
env.Constants = { ChatFrameConstants = { MaxChatWindows = 3 } }
env.canaccessvalue = function() return true end
env.canaccessallvalues, env.canaccesstable = env.canaccessvalue, env.canaccessvalue
env.IsInInstance = function() return false, "none" end
env.IsInGuild = function() return true end
env.IsInGroup = function(category) return category == env.LE_PARTY_CATEGORY_HOME end
env.IsInRaid = function() return false end
env.LE_PARTY_CATEGORY_HOME, env.LE_PARTY_CATEGORY_INSTANCE = 1, 2
env.GetChannelName = function(name) return name == "Trade" and 2 or 0 end
env.IsSecureCmd = function(command) return command == "/cast" end
env.IsModifierKeyDown = function() return false end
env.tContains = function(array, value)
    for _, entry in ipairs(array) do if entry == value then return true end end
    return false
end
env.SLASH_SAY1, env.SLASH_GUILD1, env.SLASH_WHISPER1 = "/s", "/g", "/w"
env.CHAT_SAY_GET, env.CHAT_WHISPER_GET, env.CHAT_MONSTER_SAY_GET = "%s says: ", "%s whispers: ", "%s says: "
env.ChatTypeInfo = { SAY = { r = 1, g = 1, b = 1 }, PARTY = { r = 0.6, g = 0.85, b = 1, id = 2 } }
env.ChatTypeGroup = { SAY = { "CHAT_MSG_SAY" }, PARTY = { "CHAT_MSG_PARTY" } }
env.C_ClassColor = { GetClassColor = noop }
env.C_Item = { GetItemNameByID = function() return "Linen Cloth" end }
env.C_Spell = { GetSpellName = function() return "Frostbolt" end }
env.C_Texture = { GetAtlasInfo = noop }
env.GetCVarBool = function() return false end
env.GetQuestDifficultyColor = function() return env.CreateColor(1, 1, 0, 1) end

local hooks, listeners = {}, {}
local callbackRegistry = env.CreateFrame("Frame")
env.EventRegistry = callbackRegistry
env.LinkUtil = { IsLinkHandlerRegistered = function() return false end, RegisterLinkHandler = noop }
env.ChatFrameUtil = { GetTimestampFormat = noop }
local libraries = {
    ["LibSharedMedia-3.0"] = {
        IsValid = function(_, _, name) return name == "Test Border" end,
        Fetch = function(_, _, name) return "Media/" .. name end,
    },
    ["AceEvent-3.0"] = { Embed = function(_, mod)
        function mod:RegisterEvent(event, method) listeners[event] = method end
    end },
    ["AceTimer-3.0"] = { Embed = function(_, mod)
        function mod:ScheduleTimer(callback, delay) env.C_Timer.After(delay, callback) end
    end },
    ["AceHook-3.0"] = { Embed = function(_, mod)
        function mod:SecureHook(...) env.hooksecurefunc(...) end
        function mod:SecureHookScript(frame, script, callback) frame:HookScript(script, callback) end
    end },
}
env.LibStub = function(name) return libraries[name] end

local dock = env.CreateFrame("Frame", "GeneralDockManager", env.UIParent)
dock.DOCKED_CHAT_FRAMES = {}
dock.scrollFrame = env.CreateFrame("ScrollFrame", "GeneralDockManagerScrollFrame", dock)
dock.scrollFrame:SetScrollChild(env.CreateFrame("Frame", nil, dock.scrollFrame))
dock.overflowButton = env.CreateFrame("Button", nil, dock)
env.GENERAL_CHAT_DOCK = dock
env.FCFDock_GetSelectedWindow = function(self) return self.selected end
env.FCFDock_SelectWindow = function(self, frame)
    self.selected = frame
    env.SELECTED_CHAT_FRAME = frame
    for _, window in ipairs(self.DOCKED_CHAT_FRAMES) do window:SetShown(window == frame) end
end
env.FCF_GetChatFrameByID = function(id) return env["ChatFrame" .. id] end
env.FCF_SetWindowName = function(frame, name) frame.name = name; env["ChatFrame" .. frame.id .. "Tab"]:SetText(name) end
for _, name in ipairs({
    "FCF_SelectDockFrame", "FCF_Tab_OnClick", "FCF_OpenNewWindow", "FCF_DockFrame", "FCF_UnDockFrame", "FCF_Close",
    "FCFDock_UpdateTabs", "FCF_StartAlertFlash", "FCF_StopAlertFlash", "FCFTab_UpdateAlpha", "FCFTab_UpdateColors",
    "FCF_OpenTemporaryWindow", "FCF_DockUpdate", "PanelTemplates_TabResize",
}) do
    env[name] = function() hooks[name] = (hooks[name] or 0) + 1 end
end

env.FCF_UnDockFrame = function(frame)
    for i, candidate in ipairs(dock.DOCKED_CHAT_FRAMES) do
        if candidate == frame then table.remove(dock.DOCKED_CHAT_FRAMES, i); break end
    end
    frame.isDocked = false
end
env.FCF_DockFrame = function(frame, at)
    frame.isDocked = true
    table.insert(dock.DOCKED_CHAT_FRAMES, at, frame)
end
env.FCF_SetLocked = function(frame, locked) frame.isLocked = locked end
env.FCF_SavePositionAndDimensions = function(frame) frame.savedPosition = { frame:GetPoint() } end
env.FCF_CheckShowChatFrame = function(frame) frame:Show() end
env.FCF_CanOpenNewWindow = function() return true end
env.FCF_PopInWindow = function(frame) frame.poppedIn = true end
env.FCF_SetExpandedUninteractable = function(frame, state) frame.isUninteractable = state end
env.ShowUIPanel = function(panel) panel:Show() end
env.RENAME_CHAT_WINDOW, env.NEW_CHAT_WINDOW, env.CLOSE_CHAT_WINDOW = "Rename", "New Window", "Close"
env.LOCK_WINDOW, env.UNLOCK_WINDOW = "Lock", "Unlock"
env.MAKE_UNINTERACTABLE, env.MAKE_INTERACTABLE = "Disable Interaction", "Enable Interaction"
env.ChatConfigFrame = env.CreateFrame("Frame", nil, env.UIParent)
env.ChatConfigFrame:Hide()
local editMode = env.CreateFrame("Frame", "EditModeManagerFrame", env.UIParent)
editMode.CanEnterEditMode = function() return true end
editMode.IsEditModeActive = function(self) return self:IsShown() end
editMode:Hide()
local menu
env.MenuUtil = { CreateContextMenu = function(owner, build)
    menu = {}
    build(owner, {
        CreateDivider = noop,
        CreateButton = function(_, text, action)
            assert(text)
            local entry = { action = action, enabled = true }
            function entry:SetEnabled(enabled) self.enabled = enabled end
            menu[text] = entry
            return entry
        end,
    })
end }

env.CHAT_FRAMES = {}
local function window(id, title)
    local name = "ChatFrame" .. id
    local cf = env.CreateFrame("ScrollingMessageFrame", name, env.UIParent)
    cf.name, cf.id, cf.isDocked = title, id, true
    cf.GetName = function() return name end
    cf.left, cf.bottom = 200, 200
    cf:SetSize(300, 180)
    cf.offset, cf.spacing, cf.fadeResets = 0, 4, 0
    cf.messages = {}
    cf.GetID = function(self) return self.id end
    cf.GetMaxScrollRange = function() return 12 end
    cf.SetScrollOffset = function(self, value) self.offset = value end
    cf.GetScrollOffset = function(self) return self.offset end
    cf.AtBottom = function(self) return self.offset == 0 end
    cf.SetSpacing = function(self, value) self.spacing = value end
    cf.GetSpacing = function(self) return self.spacing end
    cf.SetTimeVisible = function(self, value) self.timeVisible = value end
    cf.maxLines = 128
    cf.GetMaxLines = function(self) return self.maxLines end
    cf.SetMaxLines = function(self, value) self.maxLines = value end
    cf.SetFadeDuration = function(self, value) self.fadeDuration = value end
    cf.SetFading = function(self, value) self.fading = value end
    cf.GetFading = function(self) return self.fading end
    cf.ResetAllFadeTimes = function(self) self.fadeResets = self.fadeResets + 1 end
    cf.AddMessage = function(self, msg, r, g, b, kind) self.messages[#self.messages + 1] = { msg, r, g, b, kind } end
    cf.GetNumMessages = function(self) return #self.messages end
    cf.GetMessageInfo = function(self, index) return unpack(self.messages[index]) end
    cf.RefreshLayout = noop
    cf.visibleLines = { cf:CreateFontString() }
    cf.ScrollToBottomButton = env.CreateFrame("Button", name .. "ScrollToBottomButton", cf)
    cf.ScrollToBottomButton:SetSize(20, 20)

    local eb = env.CreateFrame("EditBox", name .. "EditBox", cf)
    eb.chatFrame, eb.chatType = cf, "SAY"
    eb.header = eb:CreateFontString()
    eb.Deactivate, eb.SetHistoryLines, eb.UpdateHeader = noop, noop, noop
    eb.SetAltArrowKeyMode = function(_, value) error("the chat boxes keep Blizzard's Alt+arrows: " .. tostring(value)) end
    eb.SetCursorPosition = function(self, value) self.cursor = value end
    eb.ClearHistory = function(self) self.historyCleared = (self.historyCleared or 0) + 1 end
    eb.GetChatType = function(self) return self.chatType end
    eb.SetChatType = function(self, value) self.chatType = value end
    eb.SetStickyType = function(self, value) self.stickyType = value end
    eb.SetChannelTarget = function(self, value) self.channel = value end
    eb.GetChannelTarget = function(self) return self.channel end
    eb.GetTellTarget = function(self) return self.tellTarget end
    cf.editBox = eb

    local tab = env.CreateFrame("Button", name .. "Tab", dock)
    tab:SetText(title)
    env.CHAT_FRAMES[#env.CHAT_FRAMES + 1] = name
    dock.DOCKED_CHAT_FRAMES[#dock.DOCKED_CHAT_FRAMES + 1] = cf
    return cf
end

local general, combat, trade = window(1, "General"), window(2, "Combat Log"), window(3, "Trade")
env.DEFAULT_CHAT_FRAME = general
dock.primary = general
env.FCFDock_SelectWindow(dock, general)
trade.channelList, trade.zoneChannelList, trade.messageTypeList = { "Trade" }, { 2 }, {}
general.messageTypeList = { "SAY", "GUILD" }
combat.messageTypeList = { "COMBAT_MISC_INFO" }

local visibility, wakes = "always", 0
local tokens = {}
local char = {}
local db = {
    enabled = true, showVolume = true, copyButton = true, tabChannel = true, opacity = 0.55, fadeLines = true,
    increaseLineHeight = true, editBoxStyle = "modern", editBoxPosition = "inside", hideCombatLog = false,
    chatFont = { face = "Test Chat", size = 16, flags = "NONE" },
    tabFont = { face = "Test Tabs", size = 12, flags = "OUTLINE" },
}
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    modules = {}, Dialogs = {},
    Conditions = { Set = function(text)
        local set = {}
        for token in text:gmatch("[^,]+") do set[token] = true end
        return set
    end },
    db = { profile = { chat = db }, global = {} },
    BORDER_COLOR = env.CreateColor(0.6, 0.5, 0.4, 1),
    IsGamepadUI = function() return ui.gamepad == true end,
    CharDB = function() return char end,
    GetFontPath = function(face) return "Fonts/" .. face end,
    SetFont = function(widget, ...) widget:SetFont(...) end,
    ApplyShadow = noop,
    CyrillicPick = function(text, path)
        if text:find("[\208\209]") then return "Cyrillic/" .. path end
        return path
    end,
    BorderEdgeSize = function(_, size) return size end,
    CopyStrata = function(widget, reference) widget:SetFrameStrata(reference:GetFrameStrata()) end,
    BronzeIcon = { Apply = function(icon, file) icon:SetTexture(file) end, Paint = noop },
    OwnGameTooltip = function(owner, anchor)
        env.GameTooltip.lines = nil
        env.GameTooltip:SetOwner(owner, anchor)
    end,
    ShowDialog = function(key, _, frame) ui.dialogRequest = { key, frame } end,
    SettingsPanel = {
        AttachScrollLine = function(scroll) scroll.attached = true end,
        Open = function(_, section) ui.openSection = section end,
    },
    FadeTime = function(v) return v end,
    Visibility = {
        GetShow = function() return visibility end,
        GetFadeDelay = function() return 2 end,
        GetMinAlpha = function() return 20 end,
        GetFadeIn = function() return 0.5 end,
        GetFadeOut = function() return 1 end,
        HasToken = function(_, _, key) return tokens[key] end,
        Wake = function() wakes = wakes + 1 end,
    },
}
ui:load("Modules/Chat.lua", ns)
local chat = ns.Chat
chat:Init()
ui:flushTimers()
ui:flushTimers()
assert(listeners.PLAYER_LEAVING_WORLD == "SaveHistory" and listeners.PLAYER_ENTERING_WORLD == "UpdateInstanceBubbles")
assert(general.maxLines == 128 and trade.maxLines == 128 and combat.maxLines == 128, "Blizzard's history is never made anew (11-24)")
local skin, bar = general.FlareUI_Skin, general.FlareUI_TabBar
assert(skin and bar and #bar.buttons == 3 and bar.buttons[1].Text:GetText() == "General")
assert(bar.buttons[1].isSelected and not bar.buttons[2].isSelected)
assert(dock:GetAlpha() == 0 and select(4, dock:GetPoint()) == -10000)
assert(env.ChatFrame1Tab:IsShown() and env.ChatFrame1Tab:GetAlpha() == 0 and not env.ChatFrame1Tab:IsMouseEnabled())

local font, size, flags = general:GetFont()
assert(font == "Fonts/Test Chat" and size == 16 and flags == "")
general:SetFont("Fonts/Blizzard", 20, "")
assert(general:GetFont() == "Fonts/Test Chat", "a native font change keeps FlareUI's configured font")
assert(general:GetSpacing() == 6 and general.fading and general.timeVisible == 3 and general.fadeDuration == 3)
assert(not general.ScrollToBottomButton:IsShown())
general:RunScript("OnMouseWheel", 1)
assert(general:GetScrollOffset() == 3 and general.ScrollToBottomButton:IsShown())
ui.shift = true
general:RunScript("OnMouseWheel", -1)
ui.shift = false
assert(general:GetScrollOffset() == 0 and not general.ScrollToBottomButton:IsShown())
local resets = general.fadeResets
general.mouseOver = true
chat.lineWatcher:RunScript("OnUpdate", 0.3)
assert(not general.fading and general.fadeResets == resets + 1)
chat.lineWatcher:RunScript("OnUpdate", 0.3)
assert(general.fadeResets == resets + 1, "don't reset visible lines on every pointer poll")
general.mouseOver = false
chat.lineWatcher:RunScript("OnUpdate", 0.3)
assert(general.fading and general.fadeResets == resets + 2)

-- (11-23, BearAE) the tabs' secure click boxes follow the tab bar's layer: the Meter tab moves the
-- bar up, and a box left under it sent clicks to the FlareUI tab, whose switch waits out a fight
chat.SyncTabHits()
ui:flushTimers()
local hits = assert(bar.FlareUI_Hits and bar.FlareUI_Hits[1], "a click box over the first tab")
local over = { LOW = "MEDIUM", MEDIUM = "HIGH" }
assert(hits:GetFrameStrata() == over[bar:GetFrameStrata()] and hits:GetFrameLevel() == 0,
    "one layer up: a click on the chat raises its window over boxes on its own")
-- (11-23 again) a tab under its box lets the mouse through, so the box gets the click whichever is on top
assert(bar.buttons[1]:IsMouseEnabled() == false)
do
    local secureHits = {}
    for i, hit in ipairs(bar.FlareUI_Hits) do secureHits[i] = hit:GetAttribute("type1") end
    hits:SetAttribute("type1", nil)
    ui:emit("PLAYER_REGEN_DISABLED")
    assert(hits:GetAttribute("type1") == "click", "put right as a fight starts (a drag had emptied it)")
    for i, hit in ipairs(bar.FlareUI_Hits) do hit:SetAttribute("type1", secureHits[i]) end
end
-- a line under the pointer doesn't start fading again on a refresh
general.FlareUI_LinesHeld = true
chat.LineFadeOn(general, ns.db.profile.chat)
assert(not general.fading)
general.FlareUI_LinesHeld = nil
chat.LineFadeOn(general, ns.db.profile.chat)
assert(general.fading)
-- the line under the tabs goes with the frame: Border None and Background Opacity 0%
do
    local db = ns.db.profile.chat
    local style, border, opacity = db.frameStyle, db.borderTexture, db.opacity
    db.frameStyle, db.borderTexture, db.opacity = "modern", "None", 0
    assert(chat.NoFrame(db))
    chat.ApplyFrameStyleArt(skin, db)
    local line = skin.Separator
    assert(not line or not line:IsShown() or not ns.ObjectiveTracker)
    db.opacity = 0.5
    assert(not chat.NoFrame(db), "a background left: the line stays")
    db.borderTexture, db.opacity = "FlareUI Thin", 0
    assert(not chat.NoFrame(db), "a border left: the line stays")
    db.frameStyle, db.borderTexture = "flareui", "None"
    assert(not chat.NoFrame(db) and not chat.NoFrame(nil))
    db.frameStyle, db.borderTexture, db.opacity = style, border, opacity
    chat.ApplyFrameStyleArt(skin, db)
end
-- typing: a hidden answer falls back on Blizzard's active box
do
    local access, util = env.canaccessvalue, env.ChatFrameUtil
    local box = { HasFocus = function() return "secret" end }
    env.canaccessvalue = function(value) return value ~= "secret" end
    env.ChatFrameUtil = { GetActiveWindow = function() return box end }
    assert(chat.BoxFocused(box) and not chat.BoxFocused(nil))
    env.ChatFrameUtil = { GetActiveWindow = function() end }
    assert(not chat.BoxFocused(box))
    box.HasFocus = function() return true end
    assert(chat.BoxFocused(box))
    env.canaccessvalue, env.ChatFrameUtil = access, util
end
-- typing, from the frame with the keyboard: no window is asked unless something has it
do
    local focus, util, has = env.GetCurrentKeyBoardFocus, env.ChatFrameUtil, general.editBox.HasFocus
    local asked, now, active = 0, nil, nil
    env.GetCurrentKeyBoardFocus = function() return now end
    env.ChatFrameUtil = { GetActiveWindow = function() return active end }
    general.editBox.HasFocus = function() asked = asked + 1 return now == general.editBox end
    assert(not chat.Typing() and asked == 0, "nothing has the keyboard")
    now = general.editBox
    assert(chat.Typing() and asked == 1)
    now = {}
    assert(not chat.Typing(), "another addon's box")
    now, active = nil, { HasFocus = function() return true end }
    assert(chat.Typing(), "Blizzard's active box, when the keyboard's frame is hidden")
    env.GetCurrentKeyBoardFocus, active = nil, nil
    assert(not chat.Typing(), "a client without it asks every window")
    env.GetCurrentKeyBoardFocus, env.ChatFrameUtil, general.editBox.HasFocus = focus, util, has
end
-- a whisper wakes the chat for a tab that isn't on screen too; other lines only for a shown window
do
    local woken = {}
    local show = chat.ShowChatFrame
    chat.ShowChatFrame = function(_, frame) woken[#woken + 1] = frame end
    local registered, visible = general.IsEventRegistered, general.IsVisible
    general.IsEventRegistered = function(_, event) return event:find("CHAT_MSG") ~= nil end
    general.IsVisible = function() return false end
    local docked = general.isDocked
    general.isDocked = true
    chat.WakeForLine(ns.db.profile.chat, "CHAT_MSG_BN_WHISPER")
    assert(#woken == 1 and woken[1] == general)
    chat.WakeForLine(ns.db.profile.chat, "CHAT_MSG_SAY")
    assert(#woken == 1)
    general.isDocked = docked
    general.IsEventRegistered, general.IsVisible, chat.ShowChatFrame = registered, visible, show
end
env.DamageMeter = env.DamageMeter or {}
local oldStrata = env.DamageMeter.FlareUI_ChatStrata
env.DamageMeter.FlareUI_ChatStrata = "HIGH"
chat.ApplyHeaderStrata()
ui:flushTimers()
assert(bar:GetFrameStrata() == "HIGH" and hits:GetFrameStrata() == "DIALOG", "the box follows the bar up: " .. tostring(hits:GetFrameStrata()))
env.DamageMeter.FlareUI_ChatStrata = oldStrata
chat.ApplyHeaderStrata()
ui:flushTimers()

env.FCFDock_SelectWindow(dock, trade)
assert(general.editBox.chatType == "CHANNEL" and general.editBox.channel == 2, "classic uses the shared edit box")
trade.channelList = {}
trade.messageTypeList = { "GUILD", "OFFICER" }
cv.chatStyle = "im"
env.FCFDock_SelectWindow(dock, trade)
assert(trade.editBox.chatType == "GUILD" and trade.editBox.stickyType == "GUILD")
trade.messageTypeList = { "PARTY", "PARTY_LEADER", "INSTANCE_CHAT" }
assert(chat.TabChatTarget(trade) == "PARTY")
trade.messageTypeList = { "RAID", "RAID_LEADER" }
assert(chat.TabChatTarget(trade) == "SAY", "out-of-group raid tab falls back to Say")
assert(chat.TabChatTarget(general) == nil, "mixed tabs keep the selected chat target")

local eb = trade.editBox
eb.chatType = "WHISPER"
eb.tellTarget = "Aria"
eb:SetText("Ready?")
eb:RunScript("OnKeyDown", "ENTER")
env.EventRegistry:TriggerEvent("ChatFrame.OnEditBoxPreSendText", eb)
assert(#char.sentHistory == 1 and char.sentHistory[1] == "/w Aria Ready?")
ui.time = 101
eb.chatType = "CHANNEL"
eb.channel = 2
eb:SetText("Trade offer")
eb:RunScript("OnKeyDown", "NUMPADENTER")
assert(char.sentHistory[2] == "/2 Trade offer")
ui.time = 102
eb:SetText("/cast Frostbolt")
env.EventRegistry:TriggerEvent("ChatFrame.OnEditBoxPreSendText", eb)
assert(#char.sentHistory == 2, "secure commands aren't retained for addon recall")
eb:SetText("unsent draft")
-- the arrows alone leave the line be, as Blizzard's; Alt+Up / Alt+Down recall
eb:RunScript("OnKeyDown", "UP")
eb:RunScript("OnKeyDown", "DOWN")
assert(eb:GetText() == "unsent draft")
ui.alt = true
eb:RunScript("OnKeyDown", "UP")
assert(eb:GetText() == "/2 Trade offer")
eb:RunScript("OnKeyDown", "UP")
assert(eb:GetText() == "/w Aria Ready?")
eb:RunScript("OnKeyDown", "DOWN")
eb:RunScript("OnKeyDown", "DOWN")
assert(eb:GetText() == "unsent draft" and eb.cursor == #eb:GetText())
env.C_ChatInfo = { InChatMessagingLockdown = function() return true end }
eb:RunScript("OnKeyDown", "UP")
assert(eb:GetText() == "unsent draft")
ui.alt = nil
ui:flushTimers()
assert(eb.historyCleared == 3)
env.EventRegistry:TriggerEvent("ChatFrame.OnEditBoxFocusGained", eb)
assert(select(5, trade.visibleLines[1]:GetPoint()) == 32)
env.EventRegistry:TriggerEvent("ChatFrame.OnEditBoxFocusLost", eb)
assert(select(5, trade.visibleLines[1]:GetPoint()) == 0)
-- the idle IM box: hidden under the window's lines when Inside; Above or Below, Blizzard's faint
-- clickable box stays (GitHub #199), also after the box moves out
chat.IdleIMBox(eb, db)
assert(eb:GetAlpha() == 0 and eb:GetFrameStrata() == "BACKGROUND", "Inside: out of the links' way")
db.editBoxPosition = "below"
chat.IdleIMBox(eb, db)
assert(eb:GetAlpha() == chat.IM_IDLE_ALPHA and eb:GetFrameStrata() == "LOW", "Below: Blizzard's idle box")
eb:SetAlpha(1)
eb:Deactivate()
assert(eb:GetAlpha() == chat.IM_IDLE_ALPHA, "the Deactivate hook reads the position too")
eb.isGM = true
eb:SetAlpha(1)
chat.IdleIMBox(eb, db)
assert(eb:GetAlpha() == 1, "a GM whisper box is Blizzard's")
eb.isGM = nil
db.editBoxPosition = "inside"

cv.chatStyle = "classic"
db.fadeLines, db.increaseLineHeight, db.editBoxPosition, db.hideCombatLog = false, false, "above", true
local spellchecks = 0
env.Misspelled = { UpdateVisualHighlights = function(_, box) if box == eb then spellchecks = spellchecks + 1 end end }
chat:RefreshAll()
chat.ApplyLineFade()

ui:flushTimers()
assert(not general.fading and not chat.lineWatcher:IsShown() and general:GetSpacing() == 4)
assert(eb:GetPoint() == "BOTTOMLEFT" and spellchecks > 0)
assert(not bar.buttons[3]:IsShown() and bar.buttons[2].Text:GetText() == "Trade")
local _, _, _, opacity = skin:GetBackdropColor()
assert(opacity == 0.55)

local volume = general.FlareUI_VolumeBtn
volume:RunScript("OnEnter")
assert(env.GameTooltip.lines[1] == "50%")
volume:RunScript("OnMouseWheel", 2)
assert(tonumber(cv.Sound_MasterVolume) == 0.6 and env.GameTooltip.lines[1] == "60%")
volume:Click()
assert(cv.Sound_MasterVolume == "0" and volume.FlareUI_Icon:GetTexture():find("Mute", 1, true))
volume:Click()
assert(tonumber(cv.Sound_MasterVolume) == 0.6)
volume:RunScript("OnLeave")
assert(not env.GameTooltip:IsShown())

local sample = chat.CreateSample(env.UIParent, "chat")
assert(not chat.CreateSample(env.UIParent, "other"))
local width, height = chat.DrawSample(sample)
assert(width == 270 and height > chat.sampleLook.TEXT_HEIGHT and sample.Copy:IsShown())
assert(sample.Window.TabStrip.ftTabs[2].Text:GetText() == "Trade")
assert(sample.Edit:GetPoint() == "BOTTOMLEFT")
db.copyButton, db.editBoxPosition = false, "below"
chat.DrawSample(sample)
assert(not sample.Copy:IsShown() and sample.Edit:GetPoint() == "TOPLEFT")
chat.ShowCopyText("https://example.com")
assert(env.FlareUI_CopyLink.box:GetText() == "https://example.com" and env.FlareUI_CopyLink.box:HasFocus())
env.FlareUI_CopyLink.box:RunScript("OnEscapePressed")
assert(not env.FlareUI_CopyLink:IsShown())
general:AddMessage("|cffaabbccHello |Hitem:2589|h[Linen Cloth]|h|r", 1, 1, 1, 1)
chat:ShowCopyChat(general)
local copy = env.FlareUI_CopyChat
assert(copy.box:GetText() == "Hello [Linen Cloth]" and copy.scroll.attached)
copy.box:RunScript("OnTextChanged", true)
assert(copy.box:GetText() == "Hello [Linen Cloth]")
copy.box:RunScript("OnEscapePressed")
assert(not copy:IsShown() and not copy.box:HasFocus())

-- Real message hooks light hidden tabs, and context menus update the same settings as the dock.
db.copyButton = true
env.FCFDock_SelectWindow(dock, general)
env.FCFDock_UpdateTabs()
ui:flushTimers()
trade:AddMessage("Party line", 0.6, 0.7, 1, 2, nil, nil, "CHAT_MSG_PARTY")
ui:flushTimers()
assert(chat.unread[trade] and bar.buttons[2].FlareUI_UnreadGlow:IsShown())
bar.buttons[2]:Click("RightButton")
assert(menu["Mute Tab"] and menu["Pop Out"] and menu["New Window"].enabled)
menu["Mute Tab"].action()
ui:flushTimers()
assert(chat.TabMuted(trade, db) and not bar.buttons[2].FlareUI_UnreadGlow:IsShown())
bar.buttons[2]:Click("RightButton")
menu["Unmute Tab"].action()
menu["Rename"].action()
assert(ui.dialogRequest[1] == "FLAREUI_RENAME_CHAT" and ui.dialogRequest[2] == trade)
local rename = ns.Dialogs.FLAREUI_RENAME_CHAT
rename.OnAccept(trade, "Market")
assert(rename.editText(trade) == "Market")
menu["Chat Settings"].action()
assert(ui.openSection == "ch")
menu["Filter Settings"].action()
assert(env.CURRENT_CHAT_FRAME_ID == trade:GetID() and env.ChatConfigFrame:IsShown())
menu["Disable Interaction"].action()
assert(trade.isUninteractable)
menu["Edit Mode"].action()
assert(editMode:IsShown())
editMode:Hide()

menu["Pop Out"].action()
assert(not trade.isDocked and trade.FlareUI_Skin:IsMouseEnabled())
trade.FlareUI_Skin:RunScript("OnDragStart")
assert(trade.FlareUI_Moving)
trade.FlareUI_Skin:RunScript("OnDragStop")
assert(not trade.FlareUI_Moving and trade.savedPosition[1] == "BOTTOMLEFT")
chat:OpenContextMenu(bar.buttons[1], trade)
menu["Lock"].action()
assert(trade.isLocked)
menu["Dock"].action()
assert(trade.isDocked and not trade.FlareUI_Skin:IsMouseEnabled())
menu["Close"].action()
assert(trade.poppedIn)
ui:flushTimers()

-- Meter mode temporarily hides docked chat lines and the copy button, then restores them.
general.FontStringContainer = env.CreateFrame("Frame", nil, general)
ns.DamageMeter = {
    ChatTabAvailable = function() return true end,
    ChatTabIgnoresFade = function() return false end,
    SetChatTabAlpha = function(self, alpha) self.alpha = alpha end,
    SetChatTab = function(self, enabled)
        self.chatTabActive, self.chatTabApplied = enabled, enabled
        chat:RefreshMeterTab()
    end,
}
chat:RefreshMeterTab()
assert(bar.meterButton:IsShown() and bar.meterButton.Text:GetText() == "Meter")
bar.meterButton:Click()
assert(chat:MeterTabActive() and general.FontStringContainer:GetAlpha() == 0 and not general.FlareUI_CopyButton:IsShown())
general:AddMessage("Hidden under meter", 1, 0.7, 0.8, 2, nil, nil, "CHAT_MSG_PARTY")
ui:flushTimers()
assert(bar.buttons[1].isUnread and bar.buttons[1].FlareUI_UnreadGlow:IsShown())
chat:SelectMeterTab(false)
assert(general.FontStringContainer:GetAlpha() == 1 and general.FlareUI_CopyButton:IsShown())
-- (11-23) Keep Messages Shown: the lines ignore the window's fade; off again, they follow it
function Widget:SetIgnoreParentAlpha(value) self.ignoreParentAlpha = value end
db.keepMessages = true
chat.ApplyLineFade()
assert(general.FontStringContainer.ignoreParentAlpha == true, "the messages keep their alpha")
db.keepMessages = nil
chat.ApplyLineFade()
assert(general.FontStringContainer.ignoreParentAlpha == false, "off: they fade with the frame")
assert(not bar.buttons[1].FlareUI_UnreadGlow:IsShown())
ns.DamageMeter = nil

-- A popped window's own message hold does not keep the dock bright.
local popup = window(4, "Whisper")
popup.isDocked = false
table.remove(dock.DOCKED_CHAT_FRAMES)
dock.primary = general
chat:StyleChatFrame(popup, db)
chat:HookAutoHide(popup)
visibility, tokens.messages = "on", true
ui.time = 200
chat:FadeApply(1)
chat:ShowChatFrame(popup, db)
assert(chat.FadeHold(false, false) and wakes > 0)
chat.ApplyWindowFades(1)
assert(popup:GetAlpha() == 1 and math.abs(trade:GetAlpha() - 0.2) < 0.001)
ui.time = 203
assert(not chat.FadeHold(false, false))
chat:FadeApply(0.4)
assert(popup:GetAlpha() == 0.4)
local previous = wakes
tokens.chatonly = true
chat:OnNPCInteractionEnd()
assert(wakes == previous, "Only Chat Messages does not wake for NPC interactions")

ui.gamepad = true
chat:ApplyGamepadChatStyle()
chat:KillGeneralDockManager()
chat:HideBlizzardTabs()
chat:UpdateCustomTabs(general, db)
assert(cv.chatStyle == "im" and env.ChatFrame1Tab:GetAlpha() == 1 and env.ChatFrame1Tab:IsMouseEnabled())
assert(not bar:IsShown() and select(2, dock:GetPoint()) == skin)
-- nothing of Blizzard's dock is run from here, and the Copy button stays off the D-pad's way (11-23: both
-- broke the pad's focus until a /reload)
do
    local updates, resizes = hooks.FCF_DockUpdate, hooks.PanelTemplates_TabResize
    chat:UpdateTabFonts(db)
    assert(hooks.FCF_DockUpdate == updates and hooks.PanelTemplates_TabResize == resizes)
    db.copyButton = true
    chat:StyleChatFrame(general, db)
    assert(not general.FlareUI_CopyButton:IsShown())
    ui.gamepad = false
    chat:StyleChatFrame(general, db)
    chat:UpdateTabFonts(db)
    assert(general.FlareUI_CopyButton:IsShown() and (hooks.FCF_DockUpdate or 0) > (updates or 0))
    ui.gamepad = true
end
-- (aleksandr, 7.1) the edit box header takes the Cyrillic twin while it holds a Russian name, and
-- goes back to the chosen font for the next header
do
    local header = general.editBox.header
    local chosen = header:GetFont()
    header:SetFormattedText("Tell %s:", "Имя")
    assert(header:GetFont() == "Cyrillic/" .. chosen, "a Russian whisper name takes the twin")
    header:SetText("Say:")
    assert(header:GetFont() == chosen, "the next header goes back to the chosen font")
end
-- (inflowon, 11-27) a tab's Font Size menu: that window keeps its own size, the others the Fonts tab's;
-- picking the Fonts tab's size again makes it follow that one
do
    chat.WindowFontSizePicked(general, 10)
    assert(select(2, general:GetFont()) == 10 and db.windowFontSize[general:GetID()] == 10)
    assert(select(2, trade:GetFont()) == 16, "the other windows keep the Fonts tab's size")
    general:SetFont("Fonts/Other", 20, "")   -- anything else setting it gets the window's size back
    assert(select(2, general:GetFont()) == 10)
    chat.WindowFontSizePicked(general, 16)
    assert(db.windowFontSize == nil and select(2, general:GetFont()) == 16, "the shared size again: follows it")
end
print("PASS: chat window styling, dock tabs, edit box history, previews and independent fading")
