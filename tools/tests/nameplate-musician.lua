-- Run from FlareUI's root: luajit tools/tests/nameplate-musician.lua
local client = dofile("tools/tests/fixtures/nameplate-musician.lua")
local plate = client.newPlate("Alice")

-- An older Musician has no integration API. The level and name still render normally.
Musician = { NamePlates = {} }
client.claim(plate)
client.draw(plate)
assert(plate.name.text == "60 Alice", "legacy Musician should leave the label alone")

-- Musician becomes available while Alice's plate is already visible.
local musician = client.enableMusician(plate)
assert(plate.name.text == "NOTE 60 Alice", "the note should precede the level and name")

musician.showIcon = false
musician.redraw()
assert(plate.name.text == "60 Alice", "turning the icon off should remove it immediately")

musician.showIcon = true
plate.levelFollow = false
musician.redraw()
assert(plate.name.text == "NOTE Alice", "hiding the level should keep one note")

-- Release Alice, then use the very same label for Bob, who isn't a musician.
client.release(plate)
assert(musician.released, "Musician should receive the handback")
plate.unit = "Bob"
client.claim(plate)
assert(plate.name.text == "Bob", "a pooled label should not keep Alice's icon")

-- Blizzard still exposes Bob's token and unit frame during the removal event.
client.remove(plate)
assert(musician.released == false, "a departure must not restore Musician's replacement")
