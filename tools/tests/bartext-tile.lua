-- Bar Text on raid tiles (style "tile", 11-23): the Centre slot only, no names; an old Health / Power
-- Text choice converts into the Centre once; nothing saved starts empty, as the old default (None).
local f = assert(io.open("Modules/BarText.lua", "rb"))
local src = f:read("*a")
f:close()
local ns = { L = setmetatable({}, { __index = function(_, k) return k end }), ShortNumber = function(n) return tostring(n) end }
_G.canaccessvalue = function() return true end
_G.unpack = _G.unpack or table.unpack
assert(loadstring(src, "BarText.lua"))("FlareUI", ns)
local BT = ns.BarText

local function text(set)
    local fs = { SetAlpha = function() end, SetText = function(self, t) self.t = t end,
                 SetFormattedText = function(self, fmt, ...) self.t = string.format(fmt, ...) end }
    BT.Fill(fs, set, { cur = 1800, max = 2000, percent = 90, lost = 200 })
    return fs.t
end
local function count(set) local n = 0 for _ in pairs(set) do n = n + 1 end return n end

-- nothing saved: empty Centre (the old default was None), no name anywhere
local fresh = BT.Slots({}, "health", "tile", nil, nil, "raid")
assert(count(fresh.middle) == 0 and count(fresh.left) == 0 and count(fresh.right) == 0, "fresh tile not empty")

-- an old choice goes to the Centre, once, and is stored
local old = { healthText = "percent" }
local slots = BT.Slots(old, "health", "tile", nil, nil, "party")
assert(text(slots.middle) == "90%", "percent: " .. tostring(text(slots.middle)))
assert(old.barText and old.barText.health, "conversion not stored")
assert(count(slots.left) == 0 and count(slots.right) == 0, "old choice leaked into a side slot")

local split = BT.Slots({ healthText = "split" }, "health", "tile", nil, nil, "raid")
assert(text(split.middle) == "90% / 1800", "split: " .. tostring(text(split.middle)))

local power = BT.Slots({ powerText = "value" }, "power", "tile", nil, nil, "raid")
assert(text(power.middle) == "1800", "power value: " .. tostring(text(power.middle)))

-- no names offered or kept on a tile
for _, v in ipairs(BT.Values("health", "tile")) do
    assert(not BT.NAMES[v.value], "tile offers a name pick")
end

-- the summary of the one slot: its picks, or None
assert(BT.Summary(fresh, BT.STYLE_SLOTS.tile) == "None", BT.Summary(fresh, BT.STYLE_SLOTS.tile))
assert(BT.Summary(slots, BT.STYLE_SLOTS.tile) == "%", BT.Summary(slots, BT.STYLE_SLOTS.tile))

-- a pick bumps the stamp (tiles re-read their cached slot)
local before = BT.stamp
BT.Toggle(old, "health", "middle", "tile", "value", false, nil, nil, "party")
assert(BT.stamp == before + 1, "stamp not bumped")
assert(text(BT.Slots(old, "health", "tile", nil, nil, "party").middle) == "90% / 1800", "pick order")

print("bartext-tile: ok")
