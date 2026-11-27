-- (Malkkav 11-27, after .t0m03) Aura timers as Blizzard's: the buff frame keeps s, m, h; unit frames show
-- seconds as a bare number; nameplates show bare seconds and nothing on an aura longer than a minute.

local rules, curves = {}, {}
local ui, ns = dofile("tools/tests/fixtures/core.lua")(nil, function(env)
    env.Enum = env.Enum or {}
    env.Enum.NumericRuleFormatRounding = { Up = 1 }
    env.Enum.DurationTextBindingProperty = { RemainingDuration = 0, TotalDuration = 4 }
    env.Enum.LuaCurveType = { Step = 1 }
    -- a rule formatter that follows its breakpoints: the last rule at or below the value, rounded up
    env.C_StringUtil = { CreateNumericRuleFormatter = function()
        local f = {}
        function f:SetBreakpoints(list) self.list = list; rules[#rules + 1] = list end
        function f:FormatNumber(value)
            local pick
            for _, rule in ipairs(self.list) do if value >= rule.threshold then pick = rule end end
            return (pick.format:gsub("%%%.0f", tostring(math.ceil(value / pick.components[1].div))))
        end
        return f
    end }
    env.C_CurveUtil = { CreateColorCurve = function()
        local c = { points = {} }
        function c:SetType() end
        function c:AddPoint(x, color) self.points[#self.points + 1] = { x, color } end
        curves[#curves + 1] = c
        return c
    end }
    env.CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
end)

-- times Lua can read (samples, weapon enchants)
assert(ns.FormatAuraTime(30) == "30s" and ns.FormatAuraTime(300) == "5m", "the buff frame keeps its units")
assert(ns.FormatAuraTime(30, "unit") == "30" and ns.FormatAuraTime(300, "unit") == "5m"
    and ns.FormatAuraTime(7200, "unit") == "2h", "unit frames: bare seconds, m and h above")
assert(ns.FormatAuraTime(42, "plate") == "42" and ns.FormatAuraTime(60, "plate") == "60", "plates: bare seconds")
assert(ns.FormatAuraTime(75, "plate") == "", "plates: nothing past a minute")
assert(ns.AuraTimeSample("24s", "unit") == "24" and ns.AuraTimeSample("2m", "unit") == "2m")
assert(ns.AuraTimeSample("2m", "plate") == "" and ns.AuraTimeSample("9s", "plate") == "9")
assert(ns.AuraTimeSample("24s") == "24s")

-- the client's formatter, per style
local function Bind(colour, kind)
    local got
    local button = { SetDurationText = function(_, _, options) got = options end }
    local text = { SetTextColor = function(self, r, g, b) self.colour = { r, g, b } end }
    ns.SetAuraDurationText(button, text, colour, kind)
    return got, text
end
local buffs = Bind(false)
assert(buffs.textFormatter:FormatNumber(30) == "30s" and not buffs.textColor)
local unit = Bind(false, "unit")
assert(unit.textFormatter:FormatNumber(30) == "30" and unit.textFormatter:FormatNumber(300) == "5m")
local unitColour = Bind(true, "unit")
assert(unitColour.textColor.property == 0, "unit frames colour by the time left, as before")

local plate, plateText = Bind(false, "plate")
assert(plate.textFormatter:FormatNumber(30) == "30")
assert(plate.textColor and plate.textColor.property == 4, "plates: the colour reads the aura's full length")
local last = plate.textColor.curve.points[#plate.textColor.curve.points]
assert(last[1] > 60 and last[1] < 61 and last[2].a == 0, "clear on an aura longer than a minute")
assert(not plateText.colour, "the hiding colour is left in place")
local plateColour = Bind(true, "plate")
assert(plateColour.textColor.property == 4, "Timer Colour on keeps the hiding")
assert(plateColour.textFormatter:FormatNumber(3) == "|cffff4033" .. "3|r", "red under 5 seconds, in the text")
assert(plateColour.textFormatter:FormatNumber(7) == "|cffffd100" .. "7|r", "yellow under 10")
assert(plateColour.textFormatter:FormatNumber(30) == "30", "white above")

print("PASS: aura timer styles (buff frame, unit frames, nameplates)")
