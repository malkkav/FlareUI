local _, ns = ...
local S = ns.Settings

--------------------------------------------------
-- TOOLTIPS (Modules/Tooltips.lua). Fixed, no option: scale, background colour, level
-- line colour, classification prefixes, the PvP line and right-click hint hidden, the health bar
-- hidden, Shift to reveal.
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

S:Module{ key = "tt", group = "Info", order = 30, enabled = "tooltips.enabled" }

local anchor = Both({ "tooltips.anchor", "tooltips.anchorFrames" })
S:Row{ key = "tt.anchor", kind = "choice", choices = { "default", "cursorOffset" },
    get = anchor.get, set = anchor.set, apply = Refresh }

local borders = Both({ "tooltips.borderByReaction", "tooltips.borderByClass", "tooltips.borderByQuality" })
S:Row{ key = "tt.borders", get = borders.get, set = borders.set, apply = Refresh }

S:Row{
    key = "tt.classNames", apply = Refresh,
    get = function() return S:GetPath("tooltips.nameColor") == "class" end,
    set = function(on) S:SetPath("tooltips.nameColor", on and "class" or "none") end,
}

local ids = Both({ "tooltips.showItemID", "tooltips.showSpellID" })
S:Row{ key = "tt.ids", get = ids.get, set = ids.set, apply = Refresh }

-- Show tooltips: in the world (units and objects), on unit frames, on action bars
local SHOW = { "always", "combat", "never" }
local world = Both({ "tooltips.visibility.worldUnits", "tooltips.visibility.worldObjects" })
S:Row{ key = "tt.showWorld", kind = "choice", choices = SHOW, get = world.get, set = world.set, apply = Refresh }
S:Row{ key = "tt.showFrames", kind = "choice", choices = SHOW, path = "tooltips.visibility.frameUnits", apply = Refresh }
S:Row{ key = "tt.showBars", kind = "choice", choices = SHOW, path = "tooltips.visibility.actionBars", apply = Refresh }
