-- The Banners page: every row has its text, the switches reach the module, Don't Show In is one
-- dropdown over four saved switches.
local setup = dofile("tools/tests/fixtures/settings-addon.lua")
local ui, ns = setup()
local S = ns.Settings
local refreshed, fonts, examples = 0, 0, 0
ns.Banners = {
    Refresh = function() refreshed = refreshed + 1 end,
    ApplyFont = function() fonts = fonts + 1 end,
    SampleNext = function() examples = examples + 1 end,
}
ns.db.profile.banners = { enabled = true, zone = true, subzone = true, questProgress = true, animate = true,
    titleFont = { face = "Custom", flags = "OUTLINE" }, textFont = { face = "Custom", flags = "OUTLINE" } }
ui:load("Settings/Pages/Banners.lua", ns)

local module = S.modules.bn
assert(module and module.group == "interface" and module.enabled == "banners.enabled")
assert(S:ModuleText("bn", "title") == "Banners" and #S:ModuleText("bn", "tabs") == 3)

local count = 0
for key, row in pairs(S.rows) do
    if key:find("^bn%.") and row.kind ~= "expander" and not key:find("%.font%.[^.]+%.") then
        count = count + 1
        assert(row:Label() ~= key, key .. " has no label")
        assert(row:Description(), key .. " has no description")
        assert(S:SectionText(row.section) ~= row.section, key .. ": section " .. row.section .. " has no title")
    end
end
assert(count >= 22, "rows: " .. count)

-- a switch saves and tells the module
S.rows["bn.levelUp"]:Set(true)
assert(ns.db.profile.banners.levelUp == true and refreshed == 1)
-- rows that depend on another grey out with it
assert(not S.rows["bn.discovery"]:IsDisabled())
ns.db.profile.banners.zone, ns.db.profile.banners.subzone = false, false
assert(S.rows["bn.discovery"]:IsDisabled() and S.rows["bn.hideZoneInSub"]:IsDisabled())
ns.db.profile.banners.animate = false
assert(S.rows["bn.enterTime"]:IsDisabled())

-- Don't Show In
local skip = S.rows["bn.skip"]
assert(skip:Get() == "none")
skip:Set("raid,arena")
local db = ns.db.profile.banners
assert(db.skipRaid == true and db.skipArena == true and db.skipDungeon == false and db.skipBattleground == false)
assert(skip:Get() == "raid,arena")

S.rows["bn.example"].apply()
assert(examples == 1)
print("PASS: settings-banners")
