local _, ns = ...
local S = ns.Settings

--------------------------------------------------
-- TOOLTIPS (Modules/Tooltips.lua). Fixed, no option: background colour, level line colour,
-- classification prefix, PvP line and right-click hint hidden, Shift to reveal, no anchor offset;
-- items, spells, auras and interface tips always show; names in class colour or none.
--------------------------------------------------
local function Refresh()
    if ns.Tooltips and ns.Tooltips.Refresh then ns.Tooltips:Refresh() end
end

-- one value written to several saved keys
local function Both(keys)
    return {
        get = function() return S:GetPath(keys[1]) end,
        set = function(value) for _, key in ipairs(keys) do S:SetPath(key, value) end end,
    }
end

S:Module{ key = "tt", group = "Info", order = 30, enabled = "tooltips.enabled", tabs = { { key = "settings" }, { key = "fonts" } } }

-- Look: size of every tooltip (50% to 150%), where it appears, the health bar
local SCALES = {}
for i = 5, 15 do SCALES[#SCALES + 1] = { i / 10, (i * 10) .. "%" } end
S:Row{ key = "tt.scale", kind = "choice", path = "tooltips.scale", choices = SCALES, apply = Refresh }

local anchor = Both({ "tooltips.anchor", "tooltips.anchorFrames" })
S:Row{ key = "tt.anchor", kind = "choice", choices = { "default", "cursorOffset" },
    get = anchor.get, set = anchor.set, apply = Refresh }

-- the health bar under a unit's tooltip (hidden by default)
S:Row{ key = "tt.healthBar", apply = Refresh,
    get = function() return not S:GetPath("tooltips.hideHealthBar") end,
    set = function(on) S:SetPath("tooltips.hideHealthBar", not on) end }

-- Tweaks
local borders = Both({ "tooltips.borderByReaction", "tooltips.borderByClass", "tooltips.borderByQuality" })
S:Row{ key = "tt.borders", get = borders.get, set = borders.set, apply = Refresh }

S:Row{
    key = "tt.classNames", apply = Refresh,
    get = function() return S:GetPath("tooltips.nameColor") == "class" end,
    set = function(on) S:SetPath("tooltips.nameColor", on and "class" or "none") end,
}
-- Blizzard's threat line ("Threat: 85%") on an enemy's tooltip
S:Row{ key = "tt.showThreat", path = "tooltips.showThreat" }
-- "Target: <name>" on a unit's tooltip
S:Row{ key = "tt.showTarget", path = "tooltips.showTarget", apply = Refresh }

local ids = Both({ "tooltips.showItemID", "tooltips.showSpellID" })
S:Row{ key = "tt.ids", get = ids.get, set = ids.set, apply = Refresh }

-- Show tooltips: in the world (units and objects), on unit frames, on action bars
local SHOW = { "always", "combat", "never" }
local world = Both({ "tooltips.visibility.worldUnits", "tooltips.visibility.worldObjects" })
S:Row{ key = "tt.showWorld", kind = "choice", choices = SHOW, get = world.get, set = world.set, apply = Refresh }
S:Row{ key = "tt.showFrames", kind = "choice", choices = SHOW, path = "tooltips.visibility.frameUnits", apply = Refresh }
S:Row{ key = "tt.showBars", kind = "choice", choices = SHOW, path = "tooltips.visibility.actionBars", apply = Refresh }

S:FontRows{ module = "tt", tab = "fonts", section = "tt.fonts", apply = Refresh, fonts = {
    { key = "title", path = "tooltips.titleFont" },
    { key = "text", path = "tooltips.contentFont" },
} }
