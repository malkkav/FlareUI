local _, ns = ...
local S, L = ns.Settings, ns.L

--------------------------------------------------
-- RESOURCE BARS
-- One switch per bar, with a shared page Edit button (Modules/ResourceBars.lua); bars are made at login, so switching
-- asks for a reload. Druid mana shows for druids only.
--------------------------------------------------
local function Bar(key, extra)
    local row = {
        key = "rb." .. key, kind = "toggle", reload = true, half = true,
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

local editTargets = {}
for _, key in ipairs(BARS) do
    editTargets[#editTargets + 1] = {
        key=key, rowKey="rb." .. key, name="FlareUI_Resource_" .. key,
        path="unitframes.resource.bars." .. key .. ".enabled", hidden=key == "mana" and NotDruid or nil,
    }
end
-- The page menu selects a specific bar; the fallback still supports ordinary Edit Mode links.
S:Module{
    key = "rb", group = "HUD", order = 30, enabled = "unitframes.resource.enabled",
    editTargets = editTargets, editMenuLabel = L["Edit Bars"],
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

S:FontRows{ module = "rb", tab = "fonts", section = "rb.fonts", apply = Refresh, fonts = {
    { key = "text", path = "unitframes.resource.font" },
} }
