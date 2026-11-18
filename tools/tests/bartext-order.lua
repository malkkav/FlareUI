-- Bar Text: numbers in a slot show in the order they were ticked; older saves keep the old order.
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
print("bartext-order: ok")
