-- Run from the repository root: luajit tools/tests/unitframes-combat-flare.lua
-- Ring styles, the player in a fight: the ring's red tint flares as the fight starts (two quick bright
-- beats), then pulses without fading below 0.3. Resting keeps the soft pulse (Sorgrum 11-25).
-- Forever Style: your own name box turns red and pulses with it (Malkkav 11-25).
local db = {
    styleStart = true, frameFontsSeeded = true, castTimeSeeded = true,
    units = { player = { enabled = true, width = 220, height = 46, powerHeight = 12, showLevel = true, combatGlow = true } },
    layouts = { Main = {} }, party = { size = {}, auras = {}, enabled = false }, boss = { enabled = true },
}
local ui, ns = dofile("tools/tests/fixtures/unitframes-ui.lua")(db)
local env = ui.env
local UF, Ring = ns.UnitFrames, ns.UFRing
local combat, resting, threat = false, false, nil
env.UnitAffectingCombat = function() return combat end
env.IsResting = function() return resting end
env.UnitThreatSituation = function() return threat end
env.GetThreatStatusColor = function() return 1, 0.6, 0 end
env.UnitExists = function() return true end
ns.EditPreviewing = function() return false end

Ring.SetStyle("flareui")
local f = UF.CreateSample(env.UIParent, "player")
assert(UF.DrawSample(f, "flareui"))
f.fuiSample, ns.UFSample = nil, nil
local ring = assert(f.RingFrame)
local shapes = {}
local fade = ring.PulseFade
function fade:SetFromAlpha(a) self.from = a end
function fade:SetToAlpha(a) self.to = a end
function fade:SetDuration(s) self.secs = s end
local function update() Ring.Update(f) return ring.Tint:IsShown(), fade.from, fade.to, fade.secs end

-- resting: the soft pulse
resting = true
local shown, from, to = update()
assert(shown and from == nil and ring.pulseShape[1] == 0.12, "resting keeps the soft pulse")

-- the fight starts: the flare
resting, combat = false, true
ui.timers = {}
shown, from, to, secs = update()
assert(shown and from == 0.3 and to == 0.95 and secs == 0.2, "a quick bright flare first")
assert(#ui.timers == 1, "one timer ends the flare")
update()
assert(fade.to == 0.95 and #ui.timers == 1, "a second update in the same fight doesn't start it again")
ui:flushTimers()
assert(fade.from == 0.3 and fade.to == 0.6 and fade.secs == 1.2, "then the steady pulse, never below 0.3")
assert(ring.Pulse:IsPlaying())

-- threat in the fight: its colour, the same steady pulse, no new flare
threat = 2
update()
assert(fade.from == 0.3 and #ui.timers == 0)

-- out of the fight and in again: another flare
combat, threat = false, nil
update()
assert(not ring.Tint:IsShown())
combat = true
update()
assert(fade.to == 0.95 and #ui.timers == 1, "every new fight flares")

-- the fight ends during the flare: its timer does nothing
combat = false
update()
ui:flushTimers()
assert(not ring.Tint:IsShown() and not ring.flaring)

-- Combat Glow off: no tint and no flare
db.units.player.combatGlow = false
combat = true
ui.timers = {}
update()
assert(not ring.Tint:IsShown() and #ui.timers == 0)

-- Forever Style: the name box, red in a fight only
db.units.player.combatGlow = true
combat = false
Ring.SetStyle("forever")
local g = UF.CreateSample(env.UIParent, "player")
assert(UF.DrawSample(g, "forever"))
g.fuiSample, ns.UFSample = nil, nil
local plate = assert(g.PlateFrame)
function plate.Strip:SetVertexColor(...) self.rgb = { ... } end
plate:Show()
Ring.Update(g)
assert(not plate.Strip:IsShown(), "no name box colour out of a fight, as Blizzard's")
combat = true
Ring.Update(g)
assert(plate.Strip:IsShown() and plate.StripPulse:IsPlaying(), "red and pulsing in a fight")
local r, gg, b = unpack(plate.Strip.rgb)
assert(r == 1 and gg == 0 and b == 0, "a hostile unit's red")
db.units.player.combatGlow = false
Ring.Update(g)
assert(not plate.Strip:IsShown() and not plate.StripPulse:IsPlaying(), "Combat Glow off: none")
db.units.player.combatGlow = true
combat = false
Ring.Update(g)
assert(not plate.Strip:IsShown(), "gone once the fight ends")

print("PASS: ring combat tint flares as a fight starts, then pulses without fading out; Forever name box red in a fight")
