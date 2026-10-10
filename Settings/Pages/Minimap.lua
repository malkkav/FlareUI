local _, ns = ...
local S = ns.Settings

--------------------------------------------------
-- MINIMAP (Modules/Minimap.lua, Modules/MinimapBag.lua). The day/night badge and the clock's FPS
-- and latency are always on.
--------------------------------------------------
local function Refresh()
    if ns.Minimap and ns.Minimap.Refresh then ns.Minimap:Refresh() end
end

S:Module{ key = "mm", group = "HUD", order = 75, enabled = "minimap.enabled" }

S:Row{ key = "mm.bag", path = "minimap.buttonBag", reload = true }
S:Row{ key = "mm.zoom", kind = "choice", path = "minimap.autoZoom", choices = { 0, 5, 10, 30 }, apply = Refresh }
