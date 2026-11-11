local _, ns = ...
local S = ns.Settings

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

local BARS = { "health", "power", "mana", "combo", "swingMain", "swingOff", "swingRanged" }

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
Bar("mana", { hidden = NotDruid })
Bar("combo")
Bar("swingMain")
Bar("swingOff")
Bar("swingRanged")

local function Refresh()
    if ns.ResourceBars and ns.ResourceBars.Refresh then ns.ResourceBars:Refresh() end
end

-- Colour Palette, Resource Bars' own (11-11): until set, the unit frames' (ResourceBars.lua RB.PaletteName)
S:Row{
    key = "rb.palette", kind = "choice", choices = { "flareui", "blizzard", "custom" },
    get = function() return ns.ResourceBars and ns.ResourceBars.PaletteName and ns.ResourceBars.PaletteName() or "flareui" end,
    set = function(value)
        local before = ns.ResourceBars and ns.ResourceBars.PaletteName and ns.ResourceBars.PaletteName() or "flareui"
        if value == "custom" and before ~= "custom" then S:SetPath("unitframes.resource.customBase", before) end
        S:SetPath("unitframes.resource.palette", value)
    end,
    apply = Refresh,
}
S:Row{
    key = "rb.pickColors", kind = "button", parent = "rb.palette",
    hidden = function() return not (ns.ResourceBars and ns.ResourceBars.PaletteName and ns.ResourceBars.PaletteName() == "custom") end,
    apply = function() if ns.ColorPicker then ns.ColorPicker.Open("rb") end end,
}

S:FontRows{ module = "rb", tab = "fonts", section = "rb.fonts", apply = Refresh, fonts = {
    { key = "text", path = "unitframes.resource.font" },
} }
