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
    tabs = { { key = "settings" }, { key = "fonts" } } }

S:Row{ key = "mm.bag", path = "minimap.buttonBag", reload = true }
S:Row{ key = "mm.clockStats", path = "minimap.clockStats" }
S:Row{ key = "mm.zoom", kind = "choice", path = "minimap.autoZoom", choices = { 0, 5, 10, 30 }, apply = Refresh }

S:FontRows{ module = "mm", tab = "fonts", section = "mm.fonts", apply = Refresh, fonts = {
    { key = "zone", path = "minimap.zoneFont" },
    { key = "clock", path = "minimap.clockFont" },
} }
