local _, ns = ...
local S = ns.Settings
local L = ns.L

--------------------------------------------------
-- RESOURCE BARS
-- One switch + Edit row per bar (Modules/ResourceBars.lua); bars are made at login, so switching
-- asks for a reload. Druid mana and Seals are on every class (11-15), for Edit Mode.
--------------------------------------------------
local function Bar(key, extra)
    local row = {
        key = "rb." .. key, kind = "frame", reload = true, half = true,
        path = "unitframes.resource.bars." .. key .. ".enabled",
        frame = function() return _G["FlareUI_Resource_" .. key] end,
    }
    for k, v in pairs(extra or {}) do row[k] = v end
    S:Row(row)
end

local BARS = { "health", "power", "mana", "combo", "swingMain", "swingOff", "swingRanged", "seal", "flight", "timer" }

-- the header button opens Edit Mode on the first bar that exists
S:Module{
    key = "rb", group = "combat", order = 30, enabled = "unitframes.resource.enabled",
    tabs = { { key = "settings" }, { key = "fonts" } },
    editMode = function()
        for _, key in ipairs(BARS) do
            if _G["FlareUI_Resource_" .. key] then return _G["FlareUI_Resource_" .. key] end
        end
    end,
}

Bar("health")
Bar("power")
Bar("mana")   -- every class (11-15): its Edit Mode frame can be placed without a druid
Bar("combo")
Bar("swingMain")
Bar("swingOff")
Bar("swingRanged")
Bar("seal")   -- every class (11-15): its Edit Mode frame can be placed without a paladin
Bar("flight")
-- Timer Bars (11-14): off works at once (Blizzard's timers come back); on needs the reload
Bar("timer", {
    set = function(value)
        S:SetPath("unitframes.resource.bars.timer.enabled", value)
        if ns.ResourceBars and ns.ResourceBars.SetTimerBars then ns.ResourceBars.SetTimerBars(value) end
    end,
})

local function Refresh()
    if ns.ResourceBars and ns.ResourceBars.Refresh then ns.ResourceBars:Refresh() end
end

-- Colour Palette, Resource Bars' own (11-11): until set, the unit frames' (ResourceBars.lua RB.PaletteName)
-- (11-11) only the button, always shown; the palettes are picked in its window (Settings/ColorPicker.lua)
S:Row{
    key = "rb.pickColors", kind = "button", buttonText = L["Pick Your Colours"],
    apply = function() if ns.ColorPicker then ns.ColorPicker.Open("rb") end end,
}

-- FONTS (11-13, back from Edit Mode): each bar's text font under the bar's name
local BAR_NAMES = { health = L["Health Bar"], power = L["Power Bar"], mana = L["Druid Mana"],
    swingMain = L["Main-Hand Swing"], swingOff = L["Off-Hand Swing"], swingRanged = L["Ranged Swing"],
    seal = L["Paladin Seals"], flight = L["Flight Timer"], timer = L["Duration Bars"] }
local BAR_HIDDEN = {}   -- (11-15) no bar is hidden by class any more
local barFonts = {}
for _, key in ipairs(BARS) do
    -- (the combo points have no text)
    if BAR_NAMES[key] then barFonts[#barFonts + 1] = {
        key = key .. "_text", label = function() return BAR_NAMES[key] end, hidden = BAR_HIDDEN[key],
        font = function() return ns.ResourceBars.BarFont(key) end,
        default = function() return S:DefaultPath("unitframes.resource.bars." .. key .. ".font") end,
    } end
end
S:FontRows{ module = "rb", tab = "fonts", section = "rb.fonts", apply = Refresh, fonts = barFonts }
