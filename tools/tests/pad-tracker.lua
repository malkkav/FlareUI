-- Run from the repository root: luajit tools/tests/pad-tracker.lua
-- PadTracker.lua: in the Gamepad UI, LB + RB and D-pad Up gives the pad to FlareUI's quest tracker (the
-- quest log with none on screen), instead of to Blizzard's invisible one.
local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local state = { gamepad = true, keys = {}, refs = {}, inFight = false }
local function noop() end
local Widget = getmetatable(env.UIParent)

-- the tracker's pieces, by hand
local clicked, tooltips, focusToggles, highlighted, wakes, linked = {}, {}, {}, nil, 0, {}
local content = env.CreateFrame("Frame", nil, env.UIParent)
local scroll = env.CreateFrame("ScrollFrame", nil, env.UIParent)
content.top, content.height = 400, 300
scroll.height, scroll.offset = 100, 0
function scroll:GetVerticalScroll() return self.offset end
function scroll:SetVerticalScroll(value) self.offset = value; env.drawn() end
local holder = env.CreateFrame("Frame", nil, env.UIParent)
holder.bottom, holder.top = 200, 440
local header = {}
for i, name in ipairs({ "zone", "sort", "autoAccept", "autoTurnIn", "minimize" }) do
    local b = env.CreateFrame("Button", nil, holder)
    b.left = i * 20
    b:SetScript("OnClick", function() clicked[#clicked + 1] = name end)
    b:SetScript("OnEnter", function() tooltips[#tooltips + 1] = name end)
    b:SetScript("OnLeave", function() tooltips[#tooltips + 1] = "left " .. name end)
    header[name] = b
end
header.autoAccept:Hide()
local lines, items, groups = {}, {}, {}
local function line(data)
    local l = env.CreateFrame("Button", nil, content)
    for k, v in pairs(data) do l[k] = v end
    l.top, l.height, l.left = 400 - #lines * 20, 18, 100
    lines[#lines + 1] = l
    return l
end
local zone = line({ zone = "Westfall", kind = "header", group = "z1" })
local q1 = line({ questID = 21, kind = "title", logIndex = 4, group = "q21" })
line({ questID = 21, kind = "objective", group = "q21" })
local q2 = line({ questID = 22, kind = "title", logIndex = 5, group = "q22" })
local popup = line({ popupQuestID = 30, kind = "title" })
local leaving = line({ questID = 99, kind = "title", leaving = true })
local far = line({ questID = 40, kind = "title", group = "q40" })
far.top = 150
local recipe = line({ recipeID = 101, kind = "title", group = "r101" })
recipe.top = 130
groups.q21 = { first = q1, last = lines[3] }
local voice = env.CreateFrame("Button", nil, q1)
voice.left = 300
voice:SetScript("OnClick", function() clicked[#clicked + 1] = "voice" end)
q1.playButton = voice
local function item(i, logIndex)
    local b = env.CreateFrame("Button", "FlareUI_TrackerItem" .. i, env.UIParent)
    b.logIndex, b.left = logIndex, 60
    b:SetAttribute("item", "item:" .. (1000 + i))
    items[i] = b
    return b
end
local item1, item2, item3 = item(1, 4), item(2, 5), item(3, 77)
local parts = { holder = holder, header = header, scroll = scroll, content = content, lines = lines,
    itemButtons = items, state = { groups = groups } }
local details, icons, collapsed, pinned = {}, {}, {}, {}
local tracker = {
    initialized = true,
    Side = function() return state.right end,
    HighlightGroup = function(_, group) highlighted = group end,
    KeepFocusManual = function() state.manual = true end,
    SetWatched = function(id, on) linked[#linked + 1] = (on and "+" or "-") .. id end,
    AddQuestieIconsButton = function(root) root:CreateButton("Questie", noop) end,
    Pad = {
        Parts = function() return parts end,
        TEXT = { share = "Share", track = "Track", untrack = "Untrack" },
        LineClick = function(l) clicked[#clicked + 1] = l end,
        Tooltip = function(l) tooltips[#tooltips + 1] = l end,
        ToggleFocus = function(id) focusToggles[#focusToggles + 1] = id end,
        IsCollapsed = function(id) return collapsed[id] end,
        ToggleCollapsed = function(id) collapsed[id] = not collapsed[id] end,
        IsPinned = function(id) return pinned[id] end,
        TogglePinned = function(id) pinned[id] = not pinned[id] end,
        QuestIcon = function(id) return icons[id] end,
        AimDetails = function(button, id)
            if not details[id] then return false end
            button:SetAttribute("type", "click")
            button:SetAttribute("clickbutton", details[id])
            return true
        end,
    },
}
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    IsGamepadUI = function() return state.gamepad end,
    OtherControllerAddon = function() return state.otherAddon end,
    IgnorePadNav = noop,
    KeyText = function(key) return key end,
    BORDER_COLOR = env.CreateColor(1, 1, 1, 1),
    Visibility = { Wake = function() wakes = wakes + 1 end },
    ObjectiveTracker = tracker,
}

-- the restricted environment
local function runSecure(code, args, ...)
    local sandbox = { PlayerInCombat = function() return state.inFight end }
    return setfenv(assert(loadstring("local " .. args .. " = ... " .. code)), sandbox)(...)
end
function Widget:SetBindingClick(priority, key, target, button)
    assert(priority and key)
    state.keys[key] = { owner = self, target = target, button = button }
end
function Widget:ClearBindings()
    for key, bind in pairs(state.keys) do if bind.owner == self then state.keys[key] = nil end end
end
env.ClearOverrideBindings = function(owner)
    assert(not ui.combat, "bindings are protected in a fight")
    owner:ClearBindings()
end
function Widget:CallMethod(key, ...) self[key](self, ...) end
function Widget:GetFrameRef(label) return state.refs[label] end
function Widget:SetAttribute(key, value)
    assert(not ui.combat or state.secure, "attributes are protected in a fight")
    self.attributes[key] = value
end
env.SecureHandlerSetFrameRef = function(_, label, frame) state.refs[label] = frame end
env.SecureHandlerWrapScript = function(button, script, owner, body)
    assert(script == "OnClick")
    state.nav, state.navOwner, state.body = button, owner, body
end
env.C_KeyBindings = { GetBindingContextForAction = function() return "Shortcuts" end }
env.GetBindingKey = function(_, _, context)
    if context == "Shortcuts" then return state.key1, state.key2 end
end
env.EventRegistry = { RegisterCallback = function(_, name, callback)
    assert(name == "Gamepad.RefreshFrameFocus")
    state.focusChanged = callback
end }
local superTracked = 22
env.C_SuperTrack = { GetSuperTrackedQuestID = function() return superTracked end }
env.IsInGroup = function() return state.grouped end
env.QuestUtil = { CanRemoveQuestWatch = function() return true end, ShareQuest = function(id) linked[#linked + 1] = "share" .. id end }
env.C_QuestLog = {
    IsPushableQuest = function() return true end,
    GetQuestWatchType = function(id) return id ~= 40 and 1 or nil end,
}
env.C_TradeSkillUI = { SetRecipeTracked = function(id) linked[#linked + 1] = "recipe" .. id end }

ui:load("Modules/PadTracker.lua", ns)
local PT = ns.PadTracker
env.drawn = function() PT.OnTrackerDrawn() end
local function start()
    ui:emit("PLAYER_ENTERING_WORLD")
    ui:flushTimers()
end
-- a press the bindings send on: the nav button's snippet, or a secure button (on its release)
local function press(key, down)
    local bind = state.keys[key]
    if not bind then return false end
    if bind.target == PT.NAV then
        state.secure = true
        runSecure(state.body, "self, control, button, down", state.nav, state.navOwner, bind.button, down)
        state.secure = nil
    elseif not down then
        env[bind.target]:Click("LeftButton")
    end
    return true
end
local function tap(key)
    local hit = press(key, true)
    press(key, false)
    return hit
end

start()
assert(not PT.watcher, "no quest log button, nothing to open")
PT.OnTrackerDrawn()
PT.Close()
env.QuestLogMicroButton = env.CreateFrame("Button", "QuestLogMicroButton", env.UIParent)
start()
assert(not PT.watcher, "Blizzard's Shortcuts bar must exist")
local bar = env.CreateFrame("Frame", nil, env.UIParent)
env.GamepadMainActionBarFrame = { PageUnit = { ShortcutsActionBar = bar } }
state.otherAddon = true
start()
assert(not PT.watcher, "another controller addon owns the bindings")
state.otherAddon, state.gamepad = nil, false
start()
assert(not PT.watcher, "keyboard and mouse")
state.gamepad, ui.combat = true, true
start()
assert(not PT.watcher and PT.pending, "secure frames wait for the fight's end")
ui.combat = false
holder:Hide()
ui:emit("PLAYER_REGEN_ENABLED")
local w = assert(PT.watcher)
assert(w:GetParent() == bar and PT.button:GetAttribute("macrotext") == "/click QuestLogMicroButton")
assert(PT.button:GetAttribute("type") == "macro" and PT.button:GetAttribute("useOnKeyDown") == true)
assert(PT.buttonA:GetAttribute("useOnKeyDown") == false)
for _, snippet in ipairs({ PT.SHOW_SNIPPET, PT.HIDE_SNIPPET, PT.NAV_SNIPPET }) do
    assert(not snippet:find("function", 1, true) and not snippet:find("[{}]"), "neither may appear in restricted Lua")
end
local function holdBumpers() runSecure(w:GetAttribute("_onshow"), "self", w) end
local function releaseBumpers() runSecure(w:GetAttribute("_onhide"), "self", w) end

-- LB + RB held: D-pad Up is ours; let go: the game's again. No tracker on screen: the quest log
holdBumpers()
assert(state.keys.PADDUP.target == PT.BUTTON and PT.bound, "the fallback key when none is bound")
state.key1, state.key2 = "PAD4", "PADDUP"
ui:emit("UPDATE_BINDINGS")
assert(w:GetAttribute("flare-key1") == "PADDUP", "our own override isn't a change of binding")
releaseBumpers()
assert(not next(state.keys) and not PT.bound)
ui:emit("UPDATE_BINDINGS")
holdBumpers()
assert(state.keys.PAD4 and state.keys.PADDUP)
releaseBumpers()
state.key2 = "PAD4"
ui:emit("UPDATE_BINDINGS")
assert(w:GetAttribute("flare-key2") == nil)
ui.combat = true
state.key1 = "PADDUP"
ui:emit("UPDATE_BINDINGS")
assert(PT.pending and w:GetAttribute("flare-key1") == "PAD4")
ui.combat = false
ui:emit("PLAYER_REGEN_ENABLED")
assert(w:GetAttribute("flare-key1") == "PADDUP")

-- the tracker is on screen: it gets the pad, on the focused quest
holder:Show()
PT.OnTrackerDrawn()
local function open()
    holdBumpers()
    press("PADDUP", true)
    releaseBumpers()
    press("PADDUP", false)
end
open()
assert(PT.open == "list" and PT.key == "quest:22" and PT.mark:IsShown() and wakes == 1)
assert(select(2, PT.mark:GetPoint()) == q2 and tooltips[#tooltips] == q2 and highlighted == "q22")
assert(PT.hints.text:GetText():find("PAD3", 1, true) and state.keys.PAD2.target == PT.NAV)
assert(state.keys.PAD1.target == PT.A and state.keys.PAD3.target == PT.X)
ui:emit("UPDATE_BINDINGS")

-- along the rows: an objective line and a quest sliding off are no stops
tap("PADDUP")
assert(PT.key == "quest:21")
tap("PADDUP")
assert(PT.key == "zone:Westfall")
tap("PADDUP")
assert(PT.key == "head:zone" and tooltips[#tooltips] == "zone", "the header's buttons are a row")
tap("PADDUP")
assert(PT.key == "head:zone", "the first row is the end")
tap("PADDRIGHT")
tap("PADDRIGHT")
assert(PT.key == "head:autoTurnIn" and tooltips[#tooltips - 1] == "left sort", "a hidden button is skipped")
tap("PAD1")
assert(clicked[#clicked] == "autoTurnIn")
tap("PADDDOWN")
assert(PT.key == "zone:Westfall")
tap("PAD1")
assert(clicked[#clicked] == zone and PT.open == "list")
tap("PAD3")
tap("PADDDOWN")
assert(PT.key == "quest:21")
tap("PADDRIGHT")
tap("PAD1")
assert(PT.key == "voice:21" and clicked[#clicked] == "voice")
tap("PADDLEFT")
tap("PADDLEFT")
assert(PT.key == "item:21")
PT.AimA(PT.buttonA)
assert(PT.buttonA:GetAttribute("type") == "item" and PT.buttonA:GetAttribute("item") == "item:1001")
tap("PADDDOWN")
assert(PT.key == "item:22", "from an item to the next quest's item")
tap("PADDRIGHT")
tap("PADDDOWN")
assert(PT.key == "popup:30")
tap("PAD1")
assert(clicked[#clicked] == popup)
tap("PAD4")
assert(not PT.entries, "no options for an offered quest")

-- held: it repeats, and stops at the end; a long list scrolls to what is chosen
press("PADDDOWN", true)
assert(PT.key == "quest:40" and PT.ticker:IsShown() and scroll.offset > 0)
local at = scroll.offset
assert(at == 400 - far:GetBottom() + PT.REVEAL - 100)
PT.ticker:RunScript("OnUpdate", 0.2)
assert(PT.key == "quest:40")
PT.ticker:RunScript("OnUpdate", 0.2)
assert(PT.key == "recipe:101")
PT.ticker:RunScript("OnUpdate", 0.2)
assert(not PT.ticker:IsShown(), "the list's end stops it")
press("PADDDOWN", false)

-- a recipe: through Blizzard's own header, when it has one
tap("PAD1")
assert(PT.open and not PT.buttonA:GetAttribute("type"))
env.ProfessionsRecipeTracker = { GetExistingBlock = function(_, id) return id == 101 and { HeaderButton = bar } end }
PT.UpdateHints()
assert(PT.hints.text:GetText():find("PAD1", 1, true))
tap("PAD4")
assert(PT.entries and PT.entries[1][1] == "Untrack")
tap("PAD1")
assert(linked[#linked] == "recipe101" and not PT.entries)
tap("PAD1")
assert(PT.buttonA:GetAttribute("clickbutton") == bar and not PT.open and not next(state.keys), "the window it opens gets the pad")

-- focus: Blizzard's own button when it has one, else ours
open()
assert(PT.key == "quest:22")
tap("PAD1")
assert(focusToggles[1] == 22)
icons[22] = bar
tap("PAD1")
assert(#focusToggles == 1 and state.manual and PT.buttonA:GetAttribute("clickbutton") == bar and PT.open == "list")

-- details: the pad is given back before the map opens
tap("PAD3")
assert(clicked[#clicked] == q2 and PT.open == "list", "none of Blizzard's buttons: the line's own click")
details[22] = header.zone
tap("PAD3")
assert(PT.buttonX:GetAttribute("clickbutton") == header.zone and not PT.open and not next(state.keys))
assert(not PT.mark:IsShown() and not PT.hints:IsShown() and highlighted == nil)

-- the options list: Up and Down move in it, B closes it only
open()
state.grouped, state.right = true, true
tap("PAD4")
assert(#PT.entries == 5 and PT.menu:IsShown() and state.nav:GetAttribute("flare-menu"))
tap("PAD3")
assert(PT.open == "list" and PT.entries, "X does nothing over it")
tap("PADDUP")
assert(PT.entryAt == 1)
tap("PADDDOWN")
tap("PADDDOWN")
assert(PT.entryAt == 3 and PT.entries[3][1] == "Pin to Top")
tap("PAD2")
assert(not PT.entries and PT.open == "list" and not state.nav:GetAttribute("flare-menu"))
tap("PAD4")
tap("PAD4")
assert(not PT.entries, "Y again closes it")
tap("PAD4")
tap("PADDDOWN")
tap("PADDDOWN")
tap("PAD1")
assert(pinned[22] and PT.open == "list" and not PT.entries)
state.grouped, state.right = false, false
tap("PAD4")
assert(#PT.entries == 4 and PT.entries[2][1] == "Unpin" and not PT.menu.lines[5]:IsShown())
for _ = 1, 3 do tap("PADDDOWN") end
tap("PAD1")
assert(linked[#linked] == "-22")

-- a redraw keeps the place; what is gone hands it to the row that took its place
q2:Hide()
PT.OnTrackerDrawn()
assert(PT.open == "list" and PT.key == "popup:30")
q2:Show()
PT.OnTrackerDrawn()
assert(PT.key == "popup:30")

-- the B press: closed on its release
press("PAD2", true)
assert(PT.open == "list")
press("PAD2", false)
assert(not PT.open and not next(state.keys))

-- LB + RB and D-pad Up again closes it too
open()
holdBumpers()
press("PADDUP", true)
assert(not PT.open)
releaseBumpers()

-- minimized to its button; hidden; Edit Mode
parts.miniButton = env.CreateFrame("Button", nil, env.UIParent)
open()
assert(PT.key == "mini" and not PT.Move("Right"))
parts.miniButton:Hide()
PT.Refresh()
assert(PT.key == "head:zone")
scroll:Hide()
PT.Refresh()
assert(#PT.rows == 1)
scroll:Show()
holder:Hide()
PT.OnTrackerDrawn()
assert(not PT.open and not next(state.keys) and not w:GetAttribute("flare-nav"))
holder:Show()
PT.OnTrackerDrawn()
open()
parts.state.editMode = true
PT.OnTrackerDrawn()
assert(not PT.open)
parts.state.editMode = nil

-- a window of the game's took the pad; a loading screen
open()
state.focusChanged()
ui:flushTimers()
assert(PT.open, "no window has it")
env.GamepadMode = { FrameControlsManager = { isUIFocused = true } }
state.focusChanged()
ui:flushTimers()
assert(not PT.open)
state.focusChanged()
open()
ui:emit("PLAYER_LEAVING_WORLD")
assert(not PT.open)

-- a fight gives the pad back just before the lockdown; in it, only the quest items
open()
tap("PAD4")
ui:emit("PLAYER_REGEN_DISABLED")
assert(not PT.open and not PT.entries and not next(state.keys))
ui.combat, state.inFight = true, true
item1:Hide()
open()
assert(PT.open == "items" and PT.buttonA:GetAttribute("item") == "item:1002" and not state.keys.PAD3 and not state.keys.PAD4)
assert(select(2, PT.mark:GetPoint()) == item2)
tap("PADDDOWN")
assert(PT.buttonA:GetAttribute("item") == "item:1003")
tap("PADDDOWN")
assert(PT.buttonA:GetAttribute("item") == "item:1003", "the last item is the end")
tap("PADDUP")
tap("PAD1")
assert(PT.buttonA:GetAttribute("item") == "item:1002" and PT.buttonA:GetAttribute("type") == "item")
PT.Close()
assert(PT.open == "items", "only the secure side closes it in a fight")
PT.OnTrackerDrawn()
tap("PAD2")
assert(not PT.open and not next(state.keys))
item2:Hide()
item3:Hide()
holdBumpers()
assert(state.keys.PADDUP.target == PT.BUTTON, "no quest item: the quest log")
releaseBumpers()
item2:Show()
open()
ui.combat, state.inFight = false, false
ui:emit("PLAYER_REGEN_ENABLED")
assert(not PT.open and not next(state.keys), "the fight's end gives the pad back")

-- near the screen's bottom the legend goes over the tracker
holder.bottom = 10
superTracked = 0
open()
assert(PT.hints:GetPoint() == "BOTTOM" and PT.key == "quest:21", "nothing focused: the first quest")
tap("PAD2")

-- Blizzard's tracker in Gamepad mode (FlareUI's didn't start): the press is Blizzard's
tracker.initialized = nil
start()
holdBumpers()
assert(not next(state.keys))
print("PASS: the Gamepad UI's quest shortcut walks FlareUI's tracker, its options and its quest items")
