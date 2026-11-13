local _, ns = ...
local S = ns.Settings
local L = ns.L

--------------------------------------------------
-- RESOURCE BARS
-- One switch + Edit row per bar (Modules/ResourceBars.lua); bars are made at login, so switching
-- asks for a reload. Druid mana shows for druids only.
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

local function NotDruid()
    local _, class = UnitClass("player")
    return class ~= "DRUID"
end
local function NotPaladin()
    local _, class = UnitClass("player")
    return class ~= "PALADIN"
end

local BARS = { "health", "power", "mana", "combo", "swingMain", "swingOff", "swingRanged", "seal", "flight" }

-- the header button opens Edit Mode on the first bar that exists
S:Module{
    key = "rb", group = "combat", order = 30, enabled = "unitframes.resource.enabled",
    editMode = function()
        for _, key in ipairs(BARS) do
            if _G["FlareUI_Resource_" .. key] then return _G["FlareUI_Resource_" .. key] end
        end
    end,
}

Bar("health")
Bar("power")
Bar("mana", { hidden = NotDruid })
Bar("combo")
Bar("swingMain")
Bar("swingOff")
Bar("swingRanged")
Bar("seal", { hidden = NotPaladin })
Bar("flight")

local function Refresh()
    if ns.ResourceBars and ns.ResourceBars.Refresh then ns.ResourceBars:Refresh() end
end

-- Colour Palette, Resource Bars' own (11-11): until set, the unit frames' (ResourceBars.lua RB.PaletteName)
-- (11-11) only the button, always shown; the palettes are picked in its window (Settings/ColorPicker.lua)
S:Row{
    key = "rb.pickColors", kind = "button", buttonText = L["Pick Your Colours"],
    apply = function() if ns.ColorPicker then ns.ColorPicker.Open("rb") end end,
}

-- Fonts (11-13): each frame's are in its Edit Mode dialog, the last section there
S:Row{ key = "rb.fontsEditMode", kind = "button", section = "rb.fonts", buttonText = L["Open Edit Mode"],
    apply = function() S:OpenEditMode("rb") end }
