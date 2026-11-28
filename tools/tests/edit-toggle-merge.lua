-- (11-26 settings audit E1-E4) related Edit Mode switches become one dropdown of toggles, and an Icons
-- section's switches join the Look section as one Icons dropdown.
local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local T = { Expander = "expander", Dropdown = "dropdown", Slider = "slider", Checkbox = "check" }
local editMode = { SettingType = T, IsInEditMode = function() return false end, GetActiveLayoutName = function() return "Modern" end }
env.LibStub = function(name) return name == "FlareEditMode" and editMode or {} end
env.securecallfunction = function(func, ...) return func(...) end
env.GetLocale = function() return "enUS" end
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    db = { profile = { unitframes = {}, tweaks = { enabled = true } }, global = {} },
}
ui:load("Core.lua", ns)

local saved = { smoothBars = false, barEdgeGlow = true, damageTrail = true, rest = true, leader = false }
local function switch(name, key, default, hidden)
    return { name = name, kind = T.Checkbox, default = default, hidden = hidden,
        get = function() return saved[key] end, set = function(_, v) saved[key] = v end, desc = name .. " desc" }
end
local function find(list, name)
    for _, item in ipairs(list) do if item.name == name then return item end end
end

local Section, settings = ns.EditSections()
local trailHidden = false
Section("Look", {
    { name = "Bar Texture", kind = T.Dropdown, get = function() return "x" end, set = function() end },
    switch("Bar Animations", "smoothBars", false),
    switch("Bar Edge Glow", "barEdgeGlow", false),
    switch("Damage Trail", "damageTrail", true, function() return trailHidden end),
    switch("Class Colours", "classColor", true),
})
Section("Icons", {
    switch("Resting", "rest", true),
    switch("Leader", "leader", true),
})

-- one Bar Effects dropdown in place of the three switches; Class Colours stays a switch
local effects = assert(find(settings, "Bar Effects"), "Bar Effects")
assert(effects.kind == T.Dropdown and effects.multiple)
assert(not find(settings, "Bar Animations") and not find(settings, "Damage Trail") and find(settings, "Class Colours"))
local values = effects.values()
assert(#values == 3 and values[1].text == "Bar Animations")
local picked = effects.get("Modern")
assert(#picked == 2 and picked[1] == 2 and picked[2] == 3, "Bar Edge Glow and Damage Trail ticked")
effects.set("Modern", 1)
assert(saved.smoothBars == true, "a tick turns its own switch on")
effects.set("Modern", nil, true)
assert(saved.smoothBars == false and saved.barEdgeGlow == false and saved.damageTrail == true, "Reset: each its own default")
-- a hidden switch leaves the list
trailHidden = true
assert(#effects.values() == 2)
trailHidden = false

-- the Icons section went into Look: no Icons title, one Icons dropdown after Look's dropdowns
for _, item in ipairs(settings) do assert(item.editSection ~= "Icons", "no Icons section") end
local icons = assert(find(settings, "Icons"), "Icons dropdown")
local lookTitle, iconsAt, textureAt
for i, item in ipairs(settings) do
    if item.editSection == "Look" then lookTitle = item end
    if item == icons then iconsAt = i end
    if item.name == "Bar Texture" then textureAt = i end
end
assert(iconsAt > textureAt, "after Look's dropdowns")
assert(icons.hidden("Modern"), "hidden while Look is closed")
lookTitle.set("Modern", true)
assert(not icons.hidden("Modern"), "shown with Look open")
icons.set("Modern", 2)
assert(saved.leader == true)

-- a single member stays a switch
local Section2, settings2 = ns.EditSections()
Section2("Look", { switch("Bar Edge Glow", "barEdgeGlow", false) })
assert(find(settings2, "Bar Edge Glow") and not find(settings2, "Bar Effects"))

-- the cast bar's Show list, its own words in the menu
local Section3, settings3 = ns.EditSections()
Section3("Cast Bar", { switch("Show Icon", "icon", true), switch("Show Spell Timer", "timer", true) })
local show = assert(find(settings3, "Show"))
assert(show.values()[1].text == "Icon" and show.values()[2].text == "Spell Timer")

print("PASS: Edit Mode switches merge into toggle dropdowns, and Icons joins Look")
