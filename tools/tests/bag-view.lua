-- Run from the repository root:  luajit tools/tests/bag-view.lua
-- Bag View (Bags.lua, 11-20): one dropdown for All Items, Category Filters, Category Rows and Category
-- Rows + Sets. The older Category Filters dropdown (Off / Drawer / Buttons, or the switch's true) is
-- carried over once: any filter becomes Category Filters; Off leaves All Items.
local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local ns = { L = setmetatable({}, { __index = function(_, key) return key end }), modules = {} }
ui.env.Enum = { ItemBind = {}, ItemClass = {} }
ui:load("Modules/Bags.lua", ns)
local View = assert(ns.Bags.View)

local function check(ok, message) assert(ok, message) end

check(View(nil) == "all", "no profile yet: All Items")
-- AceDB fills bagView with its default "all"; a saved old filter carries over
for _, old in ipairs({ true, "drawer", "buttons" }) do
    local db = { bagView = "all", bagFilters = old }
    check(View(db) == "filters" and db.bagFilters == nil, "old filter " .. tostring(old) .. " -> Category Filters")
end
for _, old in ipairs({ "off", false }) do
    local db = { bagView = "all", bagFilters = old }
    check(View(db) == "all" and db.bagFilters == nil, "old " .. tostring(old) .. " -> All Items")
end
-- a Bag View already picked wins over a leftover old value
local picked = { bagView = "rowsSets", bagFilters = "drawer" }
check(View(picked) == "rowsSets" and picked.bagFilters == nil, "a picked Bag View stays")
check(View({ bagView = "rows" }) == "rows", "plain read")

print("PASS: bag view")
