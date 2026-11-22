-- A Name Only player's format is independent of all three health slots.
local H = dofile("tools/tests/perf-helpers.lua")
local ns = { L = setmetatable({}, { __index = function(_, key) return key end }) }
local np, db, rows = {}, { kind = "friendlyPlayer", plate = "name" }, {}
function np.TypeDB() return db end
function np.TypeSet(_, key, value) db[key] = value end
function np.BlizzardHealthDefault() return { percent = 1 } end
ns.Nameplates = np
ns.Settings = { Module = function() end, FontRows = function() end,
    Row = function(_, def) rows[def.key] = def end }
assert(loadfile("Modules/BarText.lua"))("FlareUI", ns)
local logic = H.section(H.read("Modules/Nameplates.lua"), "function NP.FullPlayerNames", "-- Level: Box")
assert(loadstring("local NP, BT = ...\n" .. logic))(np, ns.BarText)
assert(loadfile("Settings/Pages/Nameplates.lua"))("FlareUI", ns)

local format, text = rows["np.fullPlayerNames"], rows["np.barText"]
assert(not format.disabled and not format.get())
format.set(true)
assert(format.get() and db.plate == "name" and not db.barText)
for _, kind in ipairs({ "enemyNpc", "friendlyNpc", "minor" }) do
    db.kind = kind
    assert(not np.FullPlayerNames(db))
end

-- Preserve old Full Name selections even after switching a slot back to numbers.
db.kind, db.fullPlayerNames = "enemyPlayer", nil
db.barText = { health = { left = { fullname = 1 } } }
assert(format.get() and text.slotTicked("left", "firstname"))
text.set(text.slotToggle("left", "max"))
assert(format.get() and text.slotTicked("left", "max") and not text.slotTicked("left", "firstname"))
format.set(false)
assert(not format.get() and text.slotTicked("left", "max"))
print("PASS: player name format works in Name Only mode and survives health slot edits")
