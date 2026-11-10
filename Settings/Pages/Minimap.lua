local _, ns = ...
local S = ns.Settings

--------------------------------------------------
-- MINIMAP
-- Settings for Modules/Minimap.lua and MinimapBag.lua.
--------------------------------------------------
local function Refresh()
    if ns.Minimap and ns.Minimap.Refresh then ns.Minimap:Refresh() end
end

S:Module{ key = "mm", group = "HUD", order = 75, enabled = "minimap.enabled",
    tabs = { { key = "settings" }, { key = "fonts" } },
    -- the minimap's fade settings sit in Blizzard's minimap dialog
    editSystems = function()
        return Enum.EditModeSystem and { { system = Enum.EditModeSystem.Minimap, name = _G.MINIMAP_LABEL or "Minimap" } } or {}
    end }

S:Row{ key = "mm.style", kind = "choice", path = "minimap.style", choices = { "square", "round" }, reload = true }
S:Row{ key = "mm.zoom", kind = "choice", path = "minimap.autoZoom", choices = { 0, 5, 10, 30 }, apply = Refresh }
-- the two for the pointer on the map together, then the clock, then the drawer
S:Row{ key = "mm.coordsHover", path = "minimap.coordsOnHover", apply = Refresh }
S:Row{ key = "mm.microMenu", path = "minimap.microMenu" }
S:Row{ key = "mm.clockStats", path = "minimap.clockStats" }
S:Row{ key = "mm.bag", path = "minimap.buttonBag", reload = true }
-- under the drawer: it opens on the pointer instead of a click (live)
S:Row{ key = "mm.bagHover", path = "minimap.bagHover", parent = "mm.bag",
    disabled = function() return not S:GetPath("minimap.buttonBag") end }

-- while a gathering addon that moves the map to scan is loaded: the flashing is its own (Minimap.lua)
S:Row{ key = "mm.nodeScanNote", kind = "text",
    hidden = function() return not (ns.Minimap and ns.Minimap.LoadedScanners and #ns.Minimap.LoadedScanners() > 0) end }

S:FontRows{ module = "mm", tab = "fonts", section = "mm.fonts", apply = Refresh, fonts = {
    { key = "zone", path = "minimap.zoneFont" },
    { key = "clock", path = "minimap.clockFont" },
} }
