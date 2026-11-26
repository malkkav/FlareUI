-- The DoT Tracker page: every row has its text, the switches reach the module, another tracker is named.
local setup = dofile("tools/tests/fixtures/settings-addon.lua")
local ui, ns = setup()
local S = ns.Settings
local refreshed, resets, other = 0, 0, nil
ns.Dots = {
    Refresh = function() refreshed = refreshed + 1 end,
    ResetLearned = function() resets = resets + 1 end,
    OtherAddon = function() return other end,
}
ns.db.profile.dots = { enabled = true, marker = true, icon = "skull", plates = "icon" }
ui:load("Settings/Pages/DotTracker.lua", ns)

local module = S.modules.dt
assert(module and module.group == "combat" and module.enabled == "dots.enabled")
assert(S:ModuleText("dt", "title") == "DoT Tracker")
local count = 0
for key, row in pairs(S.rows) do
    if key:find("^dt%.") then
        count = count + 1
        assert(row:Label() ~= key, key .. " has no label")
        assert(row:Description(), key .. " has no description")
        assert(S:SectionText(row.section) ~= row.section, key .. ": section " .. row.section .. " has no title")
    end
end
assert(count == 15, "rows: " .. count)

S.rows["dt.plates"]:Set("marker")
assert(ns.db.profile.dots.plates == "marker" and refreshed == 1)
assert(not S.rows["dt.colors"]:IsDisabled() and not S.rows["dt.pulse"]:IsDisabled())
ns.db.profile.dots.marker, ns.db.profile.dots.icon = false, "off"
assert(S.rows["dt.colors"]:IsDisabled() and S.rows["dt.pulse"]:IsDisabled())
S.rows["dt.reset"].apply()
assert(resets == 1)
-- another tracker loaded: the page says which
assert(module.banner() == nil)
other = "DoesItDie"
assert(module.banner():find("DoesItDie", 1, true))
print("PASS: settings-dot-tracker")
