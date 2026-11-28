local UI = dofile("tools/tests/fixtures/settings-ui.lua")
local ui = UI.new()
local env = ui.env
local db = { enabled = true }
local sent, messages = {}, {}
local unreadable = {}
local function noop() end
local ns = {
    modules = {},
    Dialogs = {}, ShowDialog = function() end,   -- (the Blizzard Visibility warning, 11-22)
    L = setmetatable({}, { __index = function(_, key) return key end }),
    db = { profile = { damagemeter = db } },
    ShortNumber = tostring,
}
local media, ace, editMode = {}, { Embed = noop }, { RegisterCallback = noop }
function env.LibStub(name)
    if name == "LibSharedMedia-3.0" then return media end
    if name == "AceEvent-3.0" then return ace end
    if name == "FlareEditMode" then return editMode end
    error("unexpected library " .. name)
end
function env.canaccessvalue(value) return value ~= unreadable end
function env.UnitAffectingCombat(unit) assert(unit == "player"); return ui.fighting end
function env.print(line) messages[#messages + 1] = line end

env.Enum = {
    DamageMeterType = { DamageDone = 1, Interrupts = 2, Deaths = 3 },
    DamageMeterSessionType = { Overall = 1, Current = 2 },
}
env.DAMAGE_METER_TYPE_INTERRUPTS = "Interrupts"
env.DAMAGE_METER_COMBAT_NUMBER = "Combat #%d"
local id, kind, title, selected, chatLocked = 9, 1, "Damage Done", nil, false
local active = { name = "Forest Troll", durationSeconds = 90.6 }
local window = {
    GetDamageMeterType = function() return kind end,
    GetDamageMeterTypeName = function() return { GetText = function() return title end } end,
    GetSessionID = function() return id end,
    GetSessionType = function() return env.Enum.DamageMeterSessionType.Overall end,
}
active.combatSources = {
    { name = unreadable, totalAmount = 500, amountPerSecond = 10 },
    { name = "Hush", totalAmount = unreadable, amountPerSecond = 8 },
    { name = "Ash", totalAmount = 233.4, amountPerSecond = 3.6 },
    { name = "Lime", totalAmount = 120, amountPerSecond = unreadable },
    { name = string.rep("N", 300), totalAmount = 100, amountPerSecond = 1.2 },
    { name = "Marsh", totalAmount = 50, amountPerSecond = 0.5 },
    { name = "Fern", totalAmount = 15, amountPerSecond = 0.3 },
}
env.C_DamageMeter = {
    GetAvailableCombatSessions = function() return {{ sessionID = 9, name = active.name }} end,
    GetCombatSessionFromID = function(sessionID, meterType)
        selected = { sessionID, meterType }
        return active
    end,
    GetCombatSessionFromType = function(sessionType, meterType)
        selected = { sessionType, meterType }
        return active
    end,
    GetSessionDurationSeconds = function(sessionType)
        assert(sessionType == env.Enum.DamageMeterSessionType.Overall)
        return 121
    end,
}
env.C_ChatInfo = {
    SendChatMessage = function(...) sent[#sent + 1] = { ... } end,
    InChatMessagingLockdown = function() return chatLocked end,
}
ui:load("Modules/DamageMeter.lua", ns)
local report = ns.DamageMeter.Report

db.reportLines = "3"
local rows = report.Build(window)
assert(selected[1] == 9 and selected[2] == kind and #rows == 4)
assert(rows[1] == "FlareUI: Damage Done – Forest Troll (1:31)")
assert(rows[2] == "1. Ash  233 (4/s)" and rows[4] == "3. Marsh  50 (1/s)")
assert(#rows[3] == 254 and rows[3]:sub(1, 3) == "2. ", "long lines need to fit the chat limit")
active.name = ""
assert(report.Build(window)[1] == "FlareUI: Damage Done – Combat #9 (1:31)")
db.reportLines = 4
assert(report.Lines() == 5)

id, kind, title = nil, 2, unreadable
active.durationSeconds = unreadable
rows = report.Build(window)
assert(selected[1] == env.Enum.DamageMeterSessionType.Overall and selected[2] == kind)
assert(rows[1] == "FlareUI: Interrupts – Overall (2:01)" and #rows == 6)
assert(rows[2] == "1. Ash  233" and rows[3] == "2. Lime  120", "counts do not require a per-second rate")

-- (11-24) Deaths: one line per death, at its time, in order; no time (Overall): the client's order, names only
do
    local sources = active.combatSources
    kind, title, db.reportLines = 3, "Deaths", "3"
    active.combatSources = {
        { name = "Ash", totalAmount = 1, deathTimeSeconds = 202 },
        { name = "Lime", totalAmount = 1, deathTimeSeconds = 65.4 },
        { name = unreadable, totalAmount = 1, deathTimeSeconds = 10 },
        { name = "Ash", totalAmount = 1, deathTimeSeconds = 65.4 },
        { name = "Fern", totalAmount = 1, deathTimeSeconds = 300 },
    }
    rows = report.Build(window)
    assert(#rows == 4 and rows[2] == "1. Lime  1:05" and rows[3] == "2. Ash  1:05" and rows[4] == "3. Ash  3:22")
    active.combatSources[1].deathTimeSeconds = -1
    rows = report.Build(window)
    assert(rows[2] == "1. Ash" and rows[3] == "2. Lime  1:05")
    active.combatSources, kind, title, db.reportLines = sources, 2, unreadable, 4
end

ui.combat = true
report.Send(window, "PARTY")
ui.combat, ui.fighting = false, unreadable
report.Send(window, "PARTY")
ui.fighting, chatLocked = false, true
report.Send(window, "PARTY")
chatLocked = unreadable
report.Send(window, "PARTY")
assert(#sent == 0 and #messages == 0, "both combat and chat lockdown must prevent a send")
chatLocked = false

local targetExists, friendly, same, realm = false, true, false, "Realm"
function env.UnitExists(unit) return unit == "target" and targetExists end
function env.UnitIsPlayer(unit) return unit == "target" end
function env.UnitIsUnit(unit, other) return unit == "target" and other == "player" and same end
function env.UnitCanCooperate(unit, other) return unit == "player" and other == "target" and friendly end
function env.UnitName() return "Juniper", realm end
assert(not report.WhisperTarget())
targetExists, same = true, true
assert(not report.WhisperTarget())
same, friendly = false, false
assert(not report.WhisperTarget())
friendly = true
assert(report.WhisperTarget() == "Juniper-Realm")
realm = unreadable
assert(report.WhisperTarget() == "Juniper")

local function menu()
    local root = { entries = {}, dividers = 0 }
    function root:CreateButton(name, action)
        local child = menu()
        child.action = action
        self.entries[name] = child
        return child
    end
    function root:CreateRadio(name, selectedFn, action)
        self.entries[name] = { selected = selectedFn, action = action }
    end
    function root:CreateTitle(name) self.title = name end
    function root:CreateDivider() self.dividers = self.dividers + 1 end
    function root:SetEnabled(enabled) self.disabled = not enabled end
    function root:SetTooltip(tooltip) self.tooltip = tooltip end
    return root
end
env.LE_PARTY_CATEGORY_HOME, env.LE_PARTY_CATEGORY_INSTANCE = 1, 2
env.IsInInstance = function() return false end
env.IsInGroup = function(category) return category == env.LE_PARTY_CATEGORY_HOME end
env.IsInRaid = function() return false end
env.IsInGuild = function() return true end
env.MenuResponse = { Refresh = {} }
local root = menu()
report.AddMenu(root, window)
local sub = root.entries["Report to Chat"]
assert(root.dividers == 1 and sub.title == "Lines")
assert(sub.entries.Say.disabled and sub.entries.Say.tooltip and sub.entries.Raid.disabled and sub.entries.Instance.disabled)
assert(not sub.entries.Party.disabled and not sub.entries.Guild.disabled and not sub.entries["Whisper Target"].disabled)
assert(sub.entries["Top 5"].selected())
assert(sub.entries["Top 3"].action() == env.MenuResponse.Refresh and sub.entries["Top 3"].selected())
sub.entries["Whisper Target"].action()
assert(#sent == 4 and sent[1][2] == "WHISPER" and sent[1][4] == "Juniper")

ui.combat = true
root = menu()
report.AddMenu(root, window)
assert(root.entries["Report to Chat"].disabled and next(root.entries["Report to Chat"].entries) == nil)
ui.combat = false
active.combatSources = {}
report.Send(window, "GUILD")
assert(#messages == 1 and messages[1]:find("Nothing to report.", 1, true) and #sent == 4)
print("PASS: damage meter report filters unreadable values, caps rows, resolves sessions and respects chat locks")
