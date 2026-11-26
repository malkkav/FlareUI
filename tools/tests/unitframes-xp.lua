-- XP on Frame: the shares drawn, the look each frame style can give, max level, a level-up mid-move,
-- and Hide XP Bars.
local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local function noop() end
local Widget = getmetatable(env.UIParent).__index
for _, method in ipairs({ "SetReverse", "SetStatusBarColor", "Pause", "SetFrameLevel", "SetHeight" }) do
    if not Widget[method] then Widget[method] = noop end
end
function Widget:SetValue(value) self.value = value end
function Widget:SetSwipeColor(r, g, b, a) self.tint = { self.ui.lastColor, a } end
env._G = env
env.LibStub = function() return nil end
env.unpack = unpack
local xp, xpMax, rested, level, maxed = 300, 1000, 400, 10, false
env.UnitXP = function() return xp end
env.UnitXPMax = function() return xpMax end
env.UnitLevel = function() return level end
env.GetXPExhaustion = function() return rested end
env.IsPlayerAtEffectiveMaxLevel = function() return maxed end
env.UnitExists = function() return false end
env.GetQuestLogRewardXP = function(id) return id == 7 and 500 or 90 end
env.C_QuestLog = {
    GetNumQuestLogEntries = function() return 3 end,
    GetInfo = function(i) return ({ { isHeader = true }, { questID = 7, title = "Seven" }, { questID = 8, title = "Eight" } })[i] end,
    ReadyForTurnIn = function(id) return id == 7 end,
    IsComplete = function() return false end,
    IsOnMap = function(id) return id == 8 end,
}
local faction
local tipCall
env.Enum = { TooltipDataType = { Unit = 2 } }
env.TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) assert(kind == 2); tipCall = fn end }
env.C_Reputation = { GetWatchedFactionData = function() return faction end }

local db = { mode = "ring", rested = true, quest = true, repAtMax = true, pet = true, animate = true,
    levelText = "level", tooltip = true, hideBars = "" }
local style = "flareui"          -- the frame style: forever, flareui or addon (no ring)
local frame = env.CreateFrame("Frame", "FlareUI_UF_Player", env.UIParent)
frame.Health = env.CreateFrame("StatusBar", nil, frame)
frame.Level = frame:CreateFontString()
frame.Level.GetFont = function() return "Fonts/Level", 12, "" end
local ring = env.CreateFrame("Frame", nil, frame)
ring.Centre = env.CreateFrame("Frame", nil, ring); ring.Centre:SetSize(60, 60)
ring.Disc = env.CreateFrame("Frame", nil, ring); ring.Disc:SetSize(20, 20)
ring.Hit = env.CreateFrame("Button", nil, frame); ring.DiscHit = env.CreateFrame("Button", nil, frame)
-- the disc below and left of the portrait, as on the player frame
function ring.Centre:GetCenter() return 100, 100 end
function ring.Disc:GetCenter() return 80, 80 end
frame.RingFrame = ring
local nameBox = env.CreateFrame("Frame", nil, frame)
local barRefreshes = 0
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }), modules = {},
    db = { profile = { unitframes = { xp = db } } },
    SetFontUnscaled = noop,
    UFRing = {
        Applies = function() return style ~= "addon" end,
        NameBox = function() return style == "forever" and nameBox or nil end,
        Layout = noop, Reset = noop, LayoutLevel = noop, Update = noop,
    },
    XPBar = { Color = function(key) ui.lastColor = key; return { 1, 1, 1, key = key } end, GetFrame = function() return true end,
        Refresh = function() barRefreshes = barRefreshes + 1 end },
}
ui:load("Modules/UnitFramesXP.lua", ns)
local XP = ns.UFXP
XP:Init()
ui:emit("PLAYER_ENTERING_WORLD")

-- the shares of the level: XP, XP with the rested bonus, XP with the quests ready
-- (as the FlareUI XP bar paints them: the rested bonus reaches past the quest XP)
local state = XP.State()
assert(state.kind == "xp" and state.xp == 0.3 and state.quest == 0.8 and state.open == 0 and state.rested == 1)
rested = 100
assert(XP.State().rested == 0.9, "300 XP + 500 quest + 100 rested")
-- Quest XP > All Quests: the ones in progress too; This Zone: only the zone's
db.quest = "all"
state = XP.State()
assert(state.quest == 0.8 and math.abs(state.open - 0.89) < 1e-9 and math.abs(state.rested - 0.99) < 1e-9)
db.quest = "zone"
state = XP.State()
assert(state.quest == 0 and math.abs(state.open - 0.39) < 1e-9)
db.quest, rested = true, 400
state = XP.State()
assert(state.color == "rested" and state.questCount == 1 and state.questReady == 500 and state.questOpen == 90)
rested = 5000
assert(XP.State().rested == 1, "never past the end of the level")
db.rested, db.quest = false, false
state = XP.State()
assert(state.rested == 0 and state.quest == 0 and state.color == "xp")
assert(state.questReady == 500, "the tooltip knows the quests' XP without the layer")
db.rested, db.quest, rested = true, true, 400
-- the game not ready yet: nothing, and no division by zero
xpMax = 0
assert(XP.State() == nil)
xpMax = 1000

-- each frame style gives the nearest look it has
style = "flareui"
assert(XP.Resolve(frame, "disc") == "disc" and XP.Resolve(frame, "ring") == "ring" and XP.Resolve(frame, "levelRing") == "levelRing")
assert(XP.Resolve(frame, "name") == "levelRing", "the name box look is gone: its setups get the level ring")
ring.Disc:Hide()
assert(XP.Resolve(frame, "disc") == "ring", "Show Level off: no disc")
assert(XP.Resolve(frame, "levelRing") == "ring", "nor a ring round it")
ring.Disc:Show()
style = "addon"
for _, mode in ipairs({ "ring", "levelRing", "disc", "name" }) do assert(XP.Resolve(frame, mode) == "line") end

-- every look draws without an error, and the one in use is the only one shown
local function arcs() return ui:find(function(w) return w.kind == "Cooldown" and w:GetParent():GetParent() == frame end) end
style = "flareui"
XP:Refresh()
local arc = arcs()
assert(arc and arc:GetParent():IsShown(), "the ring look")
db.mode = "disc"; XP:Refresh()
assert(not arc:GetParent():IsShown(), "the ring look goes when the disc takes over")
db.mode = "levelRing"; XP:Refresh()
local small = ui:find(function(w) return w.kind == "Cooldown" and w:GetParent():GetParent() == frame and w:GetParent() ~= arc:GetParent() end)
-- the band's inner edge just off the disc's own edge (0.42 of the 20 px frame), whatever its thickness
local function innerEdge(inner) return small:GetParent():GetWidth() / 2 * inner / 128 end
assert(small and small:GetParent():IsShown() and math.abs(innerEdge(105) - 8.4) < 0.001, "medium, the default")
db.thickness = "thick"; XP:Refresh()
assert(math.abs(innerEdge(98) - 8.4) < 0.001, "thick grows outward")
db.thickness = nil; XP:Refresh()
-- under the portrait, which stands up and to the right and covers that side: the fill starts where the
-- ring comes out from under it and has only the part in sight to cross
local start, span = XP.SightArc(frame, small:GetParent():GetWidth() / 2 * (105 + 122) / 256)
assert(start > 45 / 360 and start < 0.5 and math.abs(start * 360 - 45 - (1 - span) * 180) < 0.001)
assert(small:GetFrameLevel() < frame:GetFrameLevel() + 9, "under the portrait")
local drawn = small.cooldown and nil
for _, w in ipairs(ui.widgets) do
    if w.kind == "Cooldown" and w:GetParent() == small:GetParent() and w:IsShown() and w.cooldown then drawn = w end
end
-- XP 0.3: 30% of the part in sight, past the start
assert(drawn and math.abs((100 - drawn.cooldown[1]) / 1000 - (start + 0.3 * span)) < 0.001)
-- the XP bar's colours and strengths: rested bonus, quests in progress, quests ready, XP
local tints = {}
for _, w in ipairs(ui.widgets) do
    if w.kind == "Cooldown" and w:GetParent() == small:GetParent() then tints[#tints + 1] = w.tint end
end
assert(#tints == 4 and tints[1][1] == "restBonus" and tints[2][1] == "quest" and tints[3][1] == "quest" and tints[4][1] == "rested")
assert(tints[1][2] == 0.55 and tints[2][2] == 0.25 and tints[3][2] == 0.55 and tints[4][2] == 1)

-- the tooltip's lines are added each time the game builds the unit's tooltip, with the mouse on the frame
assert(tipCall, "a post call on unit tooltips")
env.GameTooltip.lines = nil
local rights = {}
function env.GameTooltip:AddDoubleLine(left, right) self.lines = self.lines or {}; table.insert(self.lines, left); rights[left] = right end
tipCall(env.GameTooltip)
assert(env.GameTooltip.lines == nil, "the mouse is elsewhere")
frame.mouseOver = true
tipCall(env.GameTooltip)
assert(env.GameTooltip.lines == nil, "on the frame, but not on the XP")
-- the disc's square click area reaches over the portrait: in its corner, off the round ring, still nothing
frame.mouseOver, ring.DiscHit.mouseOver = false, true
ui.cursorX, ui.cursorY = 92, 92
tipCall(env.GameTooltip)
assert(env.GameTooltip.lines == nil, "in the click area's corner, off the ring")
-- moving onto the level builds the frame's tooltip again, with the lines; moving off again, without
local rebuilt = 0
frame:SetScript("OnEnter", function() rebuilt = rebuilt + 1 end)
env.GameTooltip:Show()
XP.WatchTooltip(0.2)
ui.cursorX, ui.cursorY = 80, 80
XP.WatchTooltip(0.2)
assert(rebuilt == 1, "onto the level")
ui.cursorX, ui.cursorY = 92, 92
XP.WatchTooltip(0.2)
assert(rebuilt == 2, "and off it")
ui.cursorX, ui.cursorY = 86, 80   -- on the ring round the disc
tipCall(env.GameTooltip)
assert(env.GameTooltip.lines[2] == "XP" and rights["XP"] == "300 / 1000 (30%)" and rights["To next level"] == "700")
-- the quest ready, by name, and where handing it in would leave you; then with the one in progress
assert(rights["Quests ready to hand in"] == "500" and rights["   Seven"] == "500")
assert(rights["After handing in"] == "800 / 1000 (80%)" and rights["Quests in progress"] == "90")
assert(rights["After all quests"] == "890 / 1000 (89%)")
xp = 600; XP:Refresh(); XP.Advance(1)
tipCall(env.GameTooltip)
assert(rights["After handing in"] == "Level 11 + 100 XP", "past the level's end")
xp = 300; XP:Refresh(); XP.Advance(1)
ring.DiscHit.mouseOver = false
ui.cursorX, ui.cursorY = 0, 0
style = "addon"; XP:Refresh()
db.mode = "off"; XP:Refresh()

-- a level-up while the fill is moving: it sweeps to the end, then lands on the new level's share
style, db.mode = "flareui", "ring"
XP:Refresh()
xp = 600
ui:emit("PLAYER_XP_UPDATE")
XP.Advance(0.1)                         -- part of the way to 0.6
level, xp, xpMax = 11, 120, 1200
ui:emit("PLAYER_LEVEL_UP", 11)
ui:emit("PLAYER_XP_UPDATE")
XP.Advance(0.35)                        -- the sweep to the end of the old level
XP.Advance(0.45)                        -- and up from nothing
local shown
for _, w in ipairs(ui.widgets) do
    if w.kind == "Cooldown" and w:GetParent():GetParent() == frame and w.cooldown then shown = w.cooldown end
end
assert(shown and math.abs(shown[2] - 1000) < 0.001)
assert(math.abs(XP.State().xp - 0.1) < 1e-9)

-- Level Disc Text > Percent: the level's number steps aside
db.levelText = "percent"
XP:Refresh()
local percent = ui:find(function(w) return w.kind == "FontString" and w:GetParent() == ring.Disc and w:GetText() == "10%" end)
assert(percent and percent:IsShown() and frame.Level:GetAlpha() == 0)
db.levelText = "level"
XP:Refresh()
assert(not percent:IsShown() and frame.Level:GetAlpha() == 1)

-- max level: the watched reputation, or nothing without one
maxed = true
assert(XP.State() == nil, "no faction watched")
XP:Refresh()
faction = { name = "Stormwind", reaction = 5, currentReactionThreshold = 3000, nextReactionThreshold = 9000, currentStanding = 4500 }
state = XP.State()
assert(state.kind == "rep" and state.xp == 0.25 and state.color == "repFriendly")
db.repAtMax = false
assert(XP.State() == nil)
maxed, db.repAtMax = false, true

-- Hide XP Bars: Blizzard's go see-through and stay so, and come back with the tick gone
local main = env.CreateFrame("Frame", "MainStatusTrackingBarContainer", env.UIParent)
local bar = env.CreateFrame("Frame", nil, main)
function main:SetAlpha(value) self.alpha = value end
env.hooksecurefunc = function(target, key, callback)
    local original = target[key]
    target[key] = function(...) original(...); callback(...) end
end
assert(not XP.Hides("flare"))
db.hideBars = "flare,blizzard"
local before = barRefreshes
XP:Refresh()
assert(XP.Hides("flare") and XP.Hides("blizzard") and not XP.Hides("blizzard2"))
assert(barRefreshes == before + 1, "FlareUI's bar is told")
assert(main:GetAlpha() == 0 and not bar:IsMouseEnabled())
main:SetAlpha(1)
assert(main:GetAlpha() == 0, "Blizzard fading it back in changes nothing")
db.hideBars = ""
XP:Refresh()
assert(main:GetAlpha() == 1 and bar:IsMouseEnabled())
main:SetAlpha(0.5)
assert(main:GetAlpha() == 0.5, "no longer held")
print("PASS: unitframes-xp")
