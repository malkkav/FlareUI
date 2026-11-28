-- (Malkkav 11-27) Edit Mode's merged Show dropdown lists Centred Spell Name last, wherever it shows: it
-- moves the text, the other choices add parts.
local ui, ns = dofile("tools/tests/fixtures/core.lua")()
local T = { Dropdown = 1, Checkbox = 2 }
local saved = {}
local function Switch(name)
    return { name = name, kind = T.Checkbox, default = false,
        get = function() return saved[name] end, set = function(_, v) saved[name] = v end }
end
local items = { Switch("Center Spell Name"), Switch("Show Icon"), Switch("Show Spell Timer"), Switch("Edge Glow") }
ns.MergeEditToggles("Cast Bar", items)
assert(#items == 1 and items[1].name == "Show", "one Show dropdown")
local texts = {}
for _, v in ipairs(items[1].values()) do texts[#texts + 1] = v.text end
assert(table.concat(texts, ",") == "Icon,Spell Timer,Edge Glow,Centred Spell Name", table.concat(texts, ","))
-- nothing ticked: an empty pick (the box then shows Blizzard's "None": FlareEditMode dropdown.lua, in game)
assert(#items[1].get() == 0)
print("PASS: Edit Mode's merged Show dropdown order")
