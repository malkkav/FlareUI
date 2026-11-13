local _, ns = ...
local S = ns.Settings
local L = ns.L

--------------------------------------------------
-- MINIMAP
-- Settings for Modules/Minimap.lua and MinimapBag.lua.
--------------------------------------------------
local function Refresh()
    if ns.Minimap and ns.Minimap.Refresh then ns.Minimap:Refresh() end
end

S:Module{ key = "mm", group = "map", order = 10, enabled = "minimap.enabled",
    tabs = { { key = "settings" }, { key = "fonts" } },
    -- the minimap's fade settings sit in Blizzard's minimap dialog
    editSystems = function()
        return Enum.EditModeSystem and { { system = Enum.EditModeSystem.Minimap, name = _G.MINIMAP_LABEL or "Minimap" } } or {}
    end }

-- Style (11-13 Marcus): three cards. Headerless and Bordered are the square map's two tops
-- (minimap.squareHeader, live); Round is Forever's own map (minimap.style, a reload to or from it)
local startRound
local function StyleNow()
    if S:GetPath("minimap.style") == "round" then return "round" end
    return S:GetPath("minimap.squareHeader") == "art" and "bordered" or "headerless"
end
S:Row{ key = "mm.style", kind = "styles", choices = { "headerless", "bordered", "round" }, hideLabel = true,
    get = StyleNow,
    set = function(value)
        if startRound == nil then startRound = S:GetPath("minimap.style") == "round" end
        local round = value == "round"
        S:SetPath("minimap.style", round and "round" or "square")
        if not round then S:SetPath("minimap.squareHeader", value == "bordered" and "art" or "headerless") end
        -- only the round map needs a reload (the square one changes its top live)
        S:TrackReload("mm.style", round, startRound)
        if not round and not startRound then Refresh() end
    end,
    resetValue = function() return "headerless" end }
S:Row{ key = "mm.zoom", kind = "choice", path = "minimap.autoZoom", choices = { 0, 5, 10, 30 }, apply = Refresh }
-- Coordinates, one with Blizzard's own option (Minimap.lua MM.CoordsMode), then the framerate at
-- the map's corner (MM.SetupFps); then the clock's tooltip, the middle-click menu, the drawer
S:Row{ key = "mm.coords", kind = "choice", choices = { "off", "always", "hover" },
    get = function() return ns.Minimap and ns.Minimap.CoordsMode and ns.Minimap.CoordsMode() or "hover" end,
    set = function(value) if ns.Minimap and ns.Minimap.SetCoordsMode then ns.Minimap.SetCoordsMode(value) end end,
    resetValue = function() return "hover" end, apply = Refresh }
S:Row{ key = "mm.fps", kind = "choice", path = "minimap.fps", choices = { "off", "always", "hover" },
    apply = function() if ns.Minimap and ns.Minimap.SetupFps then ns.Minimap.SetupFps() end end }
-- Latency (11-13 Marcus): home over world, under the framerate or in its place (MM.SetupFps)
S:Row{ key = "mm.latency", kind = "choice", path = "minimap.latency", choices = { "off", "always", "hover" },
    apply = function() if ns.Minimap and ns.Minimap.SetupFps then ns.Minimap.SetupFps() end end }
S:Row{ key = "mm.clockStats", path = "minimap.clockStats" }
S:Row{ key = "mm.microMenu", path = "minimap.microMenu",
    apply = function() if ns.Minimap and ns.Minimap.UpdateMapMouse then ns.Minimap.UpdateMapMouse() end end }
S:Row{ key = "mm.bag", path = "minimap.buttonBag", reload = true }
-- under the drawer: it opens on the pointer instead of a click (live)
S:Row{ key = "mm.bagHover", path = "minimap.bagHover", parent = "mm.bag",
    disabled = function() return not S:GetPath("minimap.buttonBag") end }
-- which addons go in it (ticked) and which are left alone on the minimap (11-13); a reload puts a
-- button back where its addon keeps it
local bagTokens = {}
S:Row{ key = "mm.bagAddons", kind = "dropdown", path = "minimap.bagLeave", parent = "mm.bag", reload = true,
    disabled = function() return not S:GetPath("minimap.buttonBag") end,
    choices = function()
        local list = ns.MinimapBag and ns.MinimapBag.AddonChoices and ns.MinimapBag.AddonChoices() or {}
        wipe(bagTokens)
        for _, c in ipairs(list) do bagTokens[#bagTokens + 1] = c[1] end
        -- None first (no addon in the drawer), as the other toggle lists
        table.insert(list, 1, { divider = true })
        table.insert(list, 1, { "none", L["None"] })
        return list
    end,
    toggles = { exclusive = { "none" }, tokens = bagTokens, empty = "none" },
    get = function() return ns.MinimapBag and ns.MinimapBag.InDrawer and ns.MinimapBag.InDrawer() or "" end,
    set = function(value) if ns.MinimapBag and ns.MinimapBag.SetInDrawer then ns.MinimapBag.SetInDrawer(value) end end }

-- while a gathering addon that moves the map to scan is loaded: the flashing is its own (Minimap.lua)
S:Row{ key = "mm.nodeScanNote", kind = "text",
    hidden = function() return not (ns.Minimap and ns.Minimap.LoadedScanners and #ns.Minimap.LoadedScanners() > 0) end }
-- while a farming HUD that takes the minimap is loaded (ForeverFarmHUD, FarmHud)
S:Row{ key = "mm.hudNote", kind = "text",
    hidden = function() return not (ns.Minimap and ns.Minimap.LoadedHUDs and #ns.Minimap.LoadedHUDs() > 0) end }

-- FONTS (11-13, back from Edit Mode)
S:FontRows{ module = "mm", tab = "fonts", section = "mm.fonts",
    apply = function() if ns.Minimap and ns.Minimap.ApplyFonts then ns.Minimap:ApplyFonts() end end, fonts = {
    { key = "zone", path = "minimap.zoneFont" },
    { key = "clock", path = "minimap.clockFont" },
    { key = "info", path = "minimap.infoFont" },
} }
