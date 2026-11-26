-- Banners: the queue. A more pressing banner cuts in, a lesser one waits, duplicates are dropped,
-- progress rewrites the banner showing, and a secret text is never compared.
local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local function noop() end
local callbacks, edit = {}, { SettingType = { Slider = "slider" } }
function edit:GetActiveLayoutName() return "Modern" end
function edit:AddFrame() end
function edit:AddFrameSettings(_, settings) self.scale = settings[1] end
function edit:RegisterCallback(event, fn) callbacks[event] = fn end
env.LibStub = function() return edit end
env.IsInInstance = function() return ui.inside or false, ui.instance or "none" end
env.unpack = unpack
local SECRET = "<secret>"
env.canaccessvalue = function(value) return value ~= SECRET end

local db = { enabled = true, zone = true, subzone = true, discovery = true, levelUp = true, bossEmote = true,
    achievement = true, questAccept = true, questComplete = true, questProgress = true, rare = true, scenario = true,
    achievementProgress = false, animate = true, enterTime = 0.7, exitTime = 0.8, hold = 1, icons = true,
    skipRaid = true }
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }), modules = {},
    db = { profile = { banners = db } },
    LayoutHome = function(layouts, key) layouts[key] = layouts[key] or {}; return layouts[key] end,
    EditSection = function(_, settings) return settings end,
    SetFont = noop, ApplyShadow = noop,
    GetFontPath = function(face) return "Fonts/" .. face end,
}
ui:load("Modules/Banners.lua", ns)
local B = ns.Banners
assert(ns.modules.Banners == B and B:ShouldLoad())
assert(B:Push{ kind = "zone", title = "Early" } == "dropped", "nothing shows before Init")
B:Init()
assert(env.FlareUI_Banners:GetWidth() == 800 and edit.scale.get() == 100)

local function reset() B:Clear() end

-- a lesser banner waits, a more pressing one cuts in
assert(B:Push{ kind = "zone", title = "Elwynn" } == "shown")
assert(B:Push{ kind = "subzone", title = "Goldshire" } == "queued")
assert(B:Push{ kind = "levelUp", title = "Level 5" } == "shown")
assert(B.active.kind == "levelUp" and #B.queue == 1)

-- the banner showing, sent again, is dropped
assert(B:Push{ kind = "levelUp", title = "Level 5" } == "dropped")
-- two quests taken at once are two banners: the title is shared, the line below isn't
assert(B:Push{ kind = "questAccept", title = "Quest Accepted", subtitle = "One" } == "queued")
assert(B:Push{ kind = "questAccept", title = "Quest Accepted", subtitle = "Two" } == "queued")

-- the hold over, the most pressing banner waiting comes next, the oldest of equals first
B:Push{ kind = "questComplete", title = "Quest Complete", subtitle = "One" }
B:Advance(0.7); B:Advance(5.0); B:Advance(0.8)
assert(B.active and B.active.kind == "questComplete", "priority 2 before the priority 1 banners")
B:Advance(0.7); B:Advance(4.0); B:Advance(0.8)
assert(B.active.kind == "subzone", "the oldest priority 1 banner")

-- the queue holds eight
reset()
B:Push{ kind = "levelUp", title = "Top" }
for i = 1, 8 do assert(B:Push{ kind = "subzone", title = "Place " .. i } == "queued") end
assert(B:Push{ kind = "subzone", title = "Place 9" } == "dropped")

-- progress rewrites the banner showing and takes its time again
reset()
assert(B:Push{ kind = "questProgress", title = "Wolves", subtitle = "1/8" } == "shown")
B:Advance(0.7); B:Advance(2.0)
assert(B:Push{ kind = "questProgress", title = "Wolves", subtitle = "2/8" } == "updated")
B:Advance(0.3)
assert(B.active.subtitle == "2/8")
assert(ui:find(function(w) return w.kind == "FontString" and w:IsVisible() and w:GetText() == "2/8" end), "the line is rewritten")
B:Advance(2.0)
assert(B.active, "the hold started again")
B:Advance(0.6); B:Advance(0.8)
assert(not B.active, "and ended")
-- waiting, it replaces its own entry
B:Push{ kind = "levelUp", title = "Top" }
assert(B:Push{ kind = "questProgress", title = "Wolves", subtitle = "3/8" } == "queued")
assert(B:Push{ kind = "questProgress", title = "Wolves", subtitle = "4/8" } == "updated")
assert(#B.queue == 1 and B.queue[1].subtitle == "4/8")

-- a secret text is shown as it is and never taken for a duplicate
reset()
assert(B:Push{ kind = "bossEmote", title = SECRET, subtitle = SECRET } == "shown")
assert(ui:find(function(w) return w.kind == "FontString" and w:IsVisible() and w:GetText() == SECRET end))
B:Clear()
B:Push{ kind = "levelUp", title = "Top" }
assert(B:Push{ kind = "bossEmote", title = SECRET, subtitle = SECRET } == "queued")
assert(B:Push{ kind = "bossEmote", title = SECRET, subtitle = SECRET } == "queued")

-- a kind switched off, and an instance picked under Don't Show In, show nothing; an example still does
reset()
db.zone = false
assert(B:Push{ kind = "zone", title = "Elwynn" } == "dropped")
assert(B:Sample("zone") and B.active.kind == "zone")
db.zone = true
reset()
ui.inside, ui.instance = true, "raid"
assert(B:Push{ kind = "zone", title = "Molten Core" } == "dropped")
ui.inside, ui.instance = false, "none"

-- a "Discovered" line joins the banner playing; with none playing, or one already leaving, it is refused
reset()
assert(B:Extra("Discovered: Westfall") == false)
B:Push{ kind = "zone", title = "Elwynn" }
assert(B:Extra("Discovered: Goldshire") == true and B.active.extra == "Discovered: Goldshire")
B:Advance(0.7); B:Advance(4.0)
assert(B.Phase() == "exit" and B:Extra("Discovered: Too Late") == false)

-- A banner cut in on, with another waiting: the one that cut in plays out, the next one plays out after it,
-- and the frame ends empty. (The first version left the waiting banner frozen on screen here.)
reset()
B:Push{ kind = "questAccept", title = "Quest Accepted", subtitle = "One" }
B:Advance(0.7)
assert(B:Push{ kind = "zone", title = "Elwynn" } == "shown" and B.Phase() == "crossfade")
assert(B:Push{ kind = "subzone", title = "Goldshire" } == "queued")
B:Advance(0.7)
assert(B.Phase() == "hold" and B.active.kind == "zone")
B:Advance(4.0); B:Advance(0.8)
assert(B.active and B.active.kind == "subzone" and B.Phase() == "entrance", "the next one starts playing")
B:Advance(0.7); B:Advance(3.0); B:Advance(0.8)
assert(not B.active and B.Phase() == "idle" and #B.queue == 0, "and plays out")

-- the zone banner showing goes at once when the zone changes again; the ones waiting too
reset()
B:Push{ kind = "levelUp", title = "Top" }
B:Push{ kind = "subzone", title = "Goldshire" }
B:Push{ kind = "questAccept", title = "Quest Accepted", subtitle = "One" }
B:CancelZone()
assert(#B.queue == 1 and B.queue[1].kind == "questAccept" and B.active.kind == "levelUp")
reset()
B:Push{ kind = "zone", title = "Elwynn" }
B:CancelZone()
assert(not B.active and B.Phase() == "idle")

-- animation off: a banner stands at once and leaves at once
reset()
db.animate = false
B:Push{ kind = "zone", title = "Elwynn" }
assert(B.Phase() == "hold")
B:Advance(4.1)
assert(not B.active)
db.animate = true

-- Edit Mode: a banner stands to be placed and none comes meanwhile
callbacks.enter()
assert(B:Push{ kind = "levelUp", title = "Level 6" } == "dropped")
callbacks.exit()
assert(B:Push{ kind = "levelUp", title = "Level 6" } == "shown")
print("PASS: banners-queue")
