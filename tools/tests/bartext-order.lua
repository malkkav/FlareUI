-- Bar Text: numbers in a slot show in the order they were ticked; older saves keep the old order.
local ns = { L = setmetatable({}, { __index = function(_, k) return k end }), ShortNumber = function(n) return tostring(n) end }
_G.canaccessvalue = function() return true end
_G.unpack = _G.unpack or table.unpack
assert(loadfile("Modules/BarText.lua"))("FlareUI", ns)
local BT = ns.BarText

local function text(set)
    local fs = { SetAlpha = function() end, SetText = function(self, t) self.t = t end,
                 SetFormattedText = function(self, fmt, ...) self.t = string.format(fmt, ...) end }
    BT.Fill(fs, set, { cur = 1800, max = 2000, percent = 90, lost = 200 })
    return fs.t
end
local function tick(udb, ...)
    for _, v in ipairs({ ... }) do BT.Toggle(udb, "health", "right", "plain", v, false, nil, nil, "player") end
    return BT.Slots(udb, "health", "plain", nil, nil, "player").right
end

-- Percent then Value
local a = {}
tick(a, "value")                          -- default right = { value }: untick it first
assert(text(tick(a, "percent", "value")) == "90% / 1800", text(tick(a)))
-- Value then Percent
local b = {}
tick(b, "value")
assert(text(tick(b, "value", "percent")) == "1800 / 90%")
-- untick the first: the rest moves up, a new tick goes last
assert(text(tick(b, "value")) == "90%")
assert(text(tick(b, "max", "value")) == "90% / 2000 / 1800")
assert(BT.Place(BT.Slots(b, "health", "plain").right, "value") == 3)
-- older saves (true) keep the fixed order; an old "Value | Percent" choice converts as Value first
assert(text({ percent = true, value = true }) == "90% / 1800")
local old = { healthText = "valuepct" }
assert(text(BT.Slots(old, "health", "plain").right) == "1800 / 90%")
-- the closed box follows the same order
assert(BT.Summary(BT.Slots(b, "health", "plain")):find("% / Max / Value", 1, true))
-- Last Name (11-24): a name of its own, as First Name and Full Name
local n = {}
tick(n, "value", "lastname")
assert(BT.NameOf(BT.Slots(n, "health", "plain").right) == "lastname" and BT.FullOf("lastname") == "lastname")
assert(not tick(n, "firstname").lastname and BT.NameOf(tick(n, "fullname")) == "fullname")
local one = {}
BT.Toggle(one, "health", "left", "plain", "lastname")
local left = BT.Slots(one, "health", "plain").left
assert(left.lastname and not left.fullname and not left.firstname, "one name at a time")
BT.Toggle(one, "health", "left", "plain", "percent")
left = BT.Slots(one, "health", "plain").left
assert(left.percent and not left.lastname, "a number clears it")
assert(BT.FullOf("fullname") == true and BT.FullOf("firstname") == false and BT.FullOf(nil) == false)
assert(BT.SampleName("Elysande", "Brightvale", "lastname") == "Brightvale" and BT.SampleName("Wolf", "", "lastname") == "Wolf")
assert(BT.SampleName("Elysande", "Brightvale", true) == "Elysande Brightvale" and BT.SampleName("Elysande", "Brightvale", false) == "Elysande")
-- the plate and the tiles offer no name in their slots
assert(not BT.Slots({ barText = { health = { left = { lastname = 1 } } } }, "health", "plate").left.lastname)
-- Name Above Frames
local NA = ns.NameAbove
assert(select(2, NA.Get({ nameAbove = "left:lastname" })) == "lastname" and NA.Get({ nameAbove = "left:nickname" }) == nil)
local above = { NameAboveText = { SetText = function(self, t) self.t = t end } }
NA.SetSample(above, { nameAbove = "right:lastname" }, "Elysande", "Brightvale")
assert(above.NameAboveText.t == "Brightvale")
-- ... with the sample's level
ns.HIGH_LEVEL_SKULL = "SKULL"
NA.SetSample(above, { nameAbove = "right:firstname" }, "Elysande", "Brightvale", 42)
assert(above.NameAboveText.t == "|cffffd10042|r Elysande")
NA.SetSample(above, { nameAbove = "right:firstname" }, "Onyxia", nil, -1)
assert(above.NameAboveText.t == "SKULL Onyxia")
NA.SetSample(above, { nameAbove = "right:firstname" }, "Onyxia", nil, -1, { highSkull = { shown = false } })
assert(above.NameAboveText.t == "|cffff1a1a??|r Onyxia", "High Level Skull off: ??")
-- Show Name (the raid tiles): Off and which name
_G.LibStub = function() return { SettingType = { Dropdown = 1 } } end
local frame, changes, first = { showName = false }, 0, false
local row = BT.ShowNameSetting({ db = function() return frame end, changed = function() changes = changes + 1 end, first = function() return first end })
assert(row.get() == "off" and row.values[1].value == "off", "the old switch's off stays Off, first in the list")
row.set(nil, "lastname")
assert(frame.showName == true and frame.nameShown == "lastname" and row.get() == "lastname" and changes == 1)
row.set(nil, "off")
assert(frame.showName == false and frame.nameShown == "lastname", "the pick is kept while off")
row.set(nil, "fullname", true)
assert(frame.showName == true and frame.nameShown == nil and row.get() == "fullname")
first = true
assert(row.get() == "firstname", "a setup that had Full Player Names off starts as First Name")
ns.db = { profile = { unitframes = { fullNames = false } } }
assert(BT.OldFirstOnly())
ns.db.profile.unitframes.fullNames = nil
assert(not BT.OldFirstOnly())
-- the unit's own name (Core.lua)
do
    local H = dofile("tools/tests/perf-helpers.lua")
    local units = { player = { "Juniper", "Vale" }, wolf = { "Wolf" }, hidden = { "Secret", "Hush" } }
    local env = setmetatable({ ns = ns, UnitName = function(u) return units[u][1], units[u][2] end,
        canaccessvalue = function(v) return v ~= "Hush" end }, { __index = _G })
    H.loadSections("Core.lua", { { "function ns.UnitDisplayName(", "-- Class colours on a frame's health bar" } }, env)
    assert(ns.UnitDisplayName("player", nil, "lastname") == "Vale" and ns.UnitDisplayName("player", nil, true) == "Juniper Vale")
    assert(ns.UnitDisplayName("player", nil, false) == "Juniper" and ns.UnitDisplayName("player", "targetof", "lastname") == "Juniper")
    assert(ns.UnitDisplayName("wolf", nil, "lastname") == "Wolf", "no surname: the name")
    assert(ns.UnitDisplayName("hidden", nil, "lastname") == "Secret", "a hidden surname: the name")
end
print("bartext-order: ok")
