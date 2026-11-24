-- Switching the Frame Style away and back keeps the frames' sizes without a reload. A style's
-- stored setup holds only its changes, so the values it leaves at their defaults must come back too.
local db = {
    styleStart = true, frameFontsSeeded = true, castTimeSeeded = true, foreverStyle = true,
    units = {
        -- (AceDB has copied the defaults in at load)
        player = { enabled = true, width = 190, height = 60, powerHeight = 15, portrait = "3d" },
        target = { enabled = true, width = 220, height = 60, powerHeight = 15, portrait = "3d" },
    },
    layouts = { Main = {} },
    party = { size = {}, auras = {}, enabled = false },
    boss = { enabled = true },
}
local _, ns = dofile("tools/tests/fixtures/unitframes-ui.lua")(db)
ns.defaults.profile.unitframes = {
    units = {
        player = { enabled = true, width = 240, height = 60, powerHeight = 15 },
        target = { enabled = true, width = 220, height = 60, powerHeight = 15 },
    },
}
local Ring = ns.UFRing
assert(Ring.Style() == "flareui")

Ring.SetStyle("forever")
assert(Ring.Style() == "forever")
Ring.SetStyle("flareui")
assert(Ring.Style() == "flareui")
local player, target = db.units.player, db.units.target
assert(player.width == 190 and player.portrait == "3d", "the style's own values come back")
assert(player.height == 60 and player.powerHeight == 15, "the player frame keeps its default height and power height")
assert(target and target.width == 220 and target.height == 60 and target.powerHeight == 15,
    "a frame left entirely at its defaults comes back whole")
assert(player.enabled and target.enabled, "the frames stay on")
print("PASS: switching the frame style away and back keeps the values left at their defaults")
