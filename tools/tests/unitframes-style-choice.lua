-- A Frame Style picked in the settings waits for the reload. Until the profile is saved, the setup
-- in use (what the frames draw on any refresh, Pick Your Colours' for one) stays as it is, and
-- picking the style in use back cancels the switch.
local function newDb()
    return {
        styleStart = true, frameFontsSeeded = true, castTimeSeeded = true, foreverStyle = true,
        units = {
            player = { enabled = true, width = 190, height = 60, powerHeight = 15, portrait = "3d" },
            target = { enabled = true, width = 220, height = 60, powerHeight = 15, portrait = "3d" },
        },
        layouts = { Main = { player = { point = "CENTER", x = -300, y = -200 } } },
        party = { size = {}, auras = {}, enabled = false },
        boss = { enabled = true },
    }
end
local db = newDb()
local _, ns = dofile("tools/tests/fixtures/unitframes-ui.lua")(db)
-- AceDB's callbacks: OnDatabaseShutdown fires as the profile is saved (a reload or a logout)
local callbacks = {}
function ns.db.RegisterCallback(owner, event, handler)
    callbacks[event] = callbacks[event] or {}
    callbacks[event][owner] = handler
end
local function save()
    for _, handler in pairs(callbacks.OnDatabaseShutdown or {}) do handler("OnDatabaseShutdown", ns.db) end
end
local Ring = ns.UFRing
assert(Ring.Style() == "flareui")

Ring.ChooseStyle("forever")
assert(Ring.ChosenStyle() == "forever", "the settings show the style picked")
assert(Ring.Style() == "flareui" and not db.plateStyle, "the frames keep the style they were loaded with")
assert(db.units.player.width == 190 and db.units.player.height == 60 and db.layouts.Main.player.x == -300,
    "the setup in use is untouched before the reload")

Ring.ChooseStyle("flareui")
assert(Ring.ChosenStyle() == "flareui")
save()
assert(Ring.Style() == "flareui" and not db.plateStyle and db.units.player.width == 190,
    "picking the style in use back cancels the switch")

Ring.ChooseStyle("forever")
save()
assert(Ring.Style() == "forever" and db.plateStyle, "saving the profile switches the style")
assert(db.styleProfiles.forever.units.player.width == 190, "the style left is stored")
assert(Ring.ChosenStyle() == "forever")

-- a pick made on another profile is not carried over to this one
Ring.ChooseStyle("addon")
local other = newDb()
ns.db.profile = { unitframes = other }
save()
assert(Ring.Style() == "flareui" and other.foreverStyle, "another profile keeps its own style")
print("PASS: a picked frame style waits for the reload and picking the style in use back cancels it")
