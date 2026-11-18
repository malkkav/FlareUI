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
    -- Map (Style, Info Bar, Map Tools), Addon Buttons, Fonts
    tabs = { { key = "settings" }, { key = "buttons" }, { key = "fonts" } },
    -- the minimap's fade settings sit in Blizzard's minimap dialog
    editSystems = function()
        return Enum.EditModeSystem and { { system = Enum.EditModeSystem.Minimap, name = _G.MINIMAP_LABEL or "Minimap" } } or {}
    end }

-- Style: two cards, the square map (its frame look is the Border below, live) or Forever's own round
-- map (minimap.style, a reload to or from it)
local startRound
local function StyleNow()
    return S:GetPath("minimap.style") == "round" and "round" or "square"
end
S:Row{ key = "mm.style", kind = "styles", choices = { "square", "round" }, hideLabel = true,
    get = StyleNow,
    set = function(value)
        if startRound == nil then startRound = S:GetPath("minimap.style") == "round" end
        local round = value == "round"
        S:SetPath("minimap.style", round and "round" or "square")
        -- only the round map needs a reload (the square one changes its frame live)
        S:TrackReload("mm.style", round, startRound)
        if not round and not startRound then Refresh() end
    end,
    resetValue = function() return "square" end }
-- Border: the square map's frame. Header is the metal frame with its title bar (minimap.squareHeader
-- "art"); the others frame the map with no title bar (squareHeader "headerless"), in the heavy bronze
-- or a FlareUI border (minimap.squareBorder). Live; the addon buttons move onto the new edge too.
S:Row{ key = "mm.squareBorder", kind = "choice", section = "mm.styleSection",
    choices = { "bronze", "header", "thick", "thin" },
    get = function()
        if S:GetPath("minimap.squareHeader") == "art" then return "header" end
        local value = S:GetPath("minimap.squareBorder")
        return (value == "thick" or value == "thin") and value or "bronze"
    end,
    set = function(value)
        S:SetPath("minimap.squareHeader", value == "header" and "art" or "headerless")
        if value ~= "header" then S:SetPath("minimap.squareBorder", value) end
    end,
    resetValue = function() return "bronze" end,
    hidden = function() return StyleNow() ~= "square" end,
    apply = function()
        Refresh()
        if ns.Minimap and ns.Minimap.PlaceAllButtons then ns.Minimap.PlaceAllButtons() end
    end }
S:Row{ key = "mm.zoom", kind = "choice", path = "minimap.autoZoom", choices = { 0, 5, 10, 30 }, apply = Refresh }
-- the Info Bar
-- (the Info Bar shows under the round map too)
local BAR_VALUES = { "none", "gold", "bags", "durability", "fps", "latency", "coords", "coordsSimple" }
-- the three cells on one line with no labels, laid out as the bar itself; pointing at
-- one shows its Left / Center / Right text
-- the round map shows the Center cell only, inside the circle: Left and Right greyed there
local function RoundMap() return S:GetPath("minimap.style") == "round" end
for _, side in ipairs({ "Left", "Center", "Right" }) do
    S:Row{ key = "mm.bar" .. side, kind = "choice", third = true, bare = true,
        path = "minimap.infoBar." .. side:lower(), choices = BAR_VALUES, apply = Refresh,
        disabled = side ~= "Center" and RoundMap or nil }
end
-- On Mouseover (off): the bar shows only while you point at the minimap
-- Show Box (on): the plates behind the cells; off, the text alone
S:Row{ key = "mm.barBox", path = "minimap.infoBarBox", apply = Refresh, half = true }
S:Row{ key = "mm.barHover", path = "minimap.infoBarHover", apply = Refresh, half = true }
-- Map Tools' switches in two columns (half rows)
S:Row{ key = "mm.microMenu", path = "minimap.microMenu", half = true,
    apply = function() if ns.Minimap and ns.Minimap.UpdateMapMouse then ns.Minimap.UpdateMapMouse() end end }
-- FPS/Ping on Clock (in Map Tools, under Middle-Click Menu)
S:Row{ key = "mm.clockStats", path = "minimap.clockStats", half = true }
-- FlareUI Minimap Button: FlareUI's own button, on the minimap or in the drawer
-- (live; its right-click turns it off)
-- Drawer Style: Disabled / Sundial / Blizzard, first in Addon Buttons; Disabled greys the
-- section's other rows (reload: the drawer and its button are made as the game loads)
local function DrawerOff() return S:GetPath("minimap.drawerStyle") == "disabled" end
-- Sundial off (Map Tools): no Sundial choice, and a saved Sundial shows as Blizzard
S:Row{ key = "mm.drawerStyle", kind = "choice", tab = "buttons", reload = true,
    get = function()
        local style = S:GetPath("minimap.drawerStyle")
        if style ~= "disabled" and style ~= "blizzard" then style = "sundial" end
        if style == "sundial" and S:GetPath("minimap.sundial") == false then style = "blizzard" end
        return style
    end,
    set = function(value) S:SetPath("minimap.drawerStyle", value) end,
    choices = function()
        if S:GetPath("minimap.sundial") == false then
            return { { "disabled", L["Disabled"] }, { "blizzard", L["Blizzard"] } }
        end
        return { "disabled", "sundial", "blizzard" }
    end }
S:Row{ key = "mm.flareButton", path = "minimap.flareButton", tab = "buttons", disabled = DrawerOff,
    apply = function() if ns.MinimapBag and ns.MinimapBag.FlareChanged then ns.MinimapBag.FlareChanged() end end }
-- the four icons in the order they stack on the map, bottom to top: Sundial Icon,
-- Group Finder Icon, Vehicle Exit Button, Durability Warning
-- Sundial: the day/night badge. Off moves a drawer opened from it to
-- Blizzard (the little button under the calendar); a reload hides or shows it
S:Row{ key = "mm.sundial", reload = true, half = true,
    get = function() return S:GetPath("minimap.sundial") ~= false end,
    set = function(on)
        S:SetPath("minimap.sundial", on)
        if not on then
            local style = S:GetPath("minimap.drawerStyle")
            if style ~= "disabled" and style ~= "blizzard" then S:SetPath("minimap.drawerStyle", "blizzard") end
        end
    end }
-- Group Finder Icon: a small icon in place of Blizzard's queue eye (live, MinimapEye.lua)
S:Row{ key = "mm.finderEye", path = "minimap.finderEye", half = true,
    apply = function() if ns.MinimapEye and ns.MinimapEye.Update then ns.MinimapEye.Update() end end }
-- Vehicle Exit Button: the vehicle exit button on the map's left edge (live, MinimapVehicle.lua)
S:Row{ key = "mm.vehicleExit", path = "minimap.vehicleExit", half = true,
    apply = function() if ns.MinimapVehicle and ns.MinimapVehicle.Update then ns.MinimapVehicle.Update() end end }
-- Durability Warning (off): Blizzard's durability figure as one icon above the others (live)
S:Row{ key = "mm.durability", path = "minimap.durability", half = true,
    apply = function() if ns.MinimapDurability and ns.MinimapDurability.Update then ns.MinimapDurability.Update() end end }
-- the icons on the map's edge (sundial, Group Finder, Vehicle Exit, Durability) slide along it and
-- resize with Shift and Ctrl held, always on (Minimap.lua MM.Moves): how, and a button that puts
-- every one back
S:Row{ key = "mm.resetButtonMoves", kind = "button", center = true, section = "mm.mapTools",
    apply = function() if ns.Minimap and ns.Minimap.ResetButtonMoves then ns.Minimap.ResetButtonMoves() end end }
-- (None in Addons in the Drawer turns the drawer off)
-- the drawer opens on the pointer instead of a click (live)
S:Row{ key = "mm.bagHover", path = "minimap.bagHover", tab = "buttons",
    disabled = function() return DrawerOff() or not S:GetPath("minimap.buttonBag") end }
-- which addons go in it (ticked) and which are left alone on the minimap; a reload puts a
-- button back where its addon keeps it. None is the drawer off (minimap.buttonBag): ticking an
-- addon turns it back on. The list itself is kept while it is off.
local bagTokens = {}
S:Row{ key = "mm.bagAddons", kind = "dropdown", reload = true, tab = "buttons", disabled = DrawerOff,
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
    get = function()
        if not S:GetPath("minimap.buttonBag") then return "none" end
        return ns.MinimapBag and ns.MinimapBag.InDrawer and ns.MinimapBag.InDrawer() or "none"
    end,
    set = function(value)
        local on = value ~= nil and value ~= "" and value ~= "none"
        S:SetPath("minimap.buttonBag", on)
        if on and ns.MinimapBag and ns.MinimapBag.SetInDrawer then ns.MinimapBag.SetInDrawer(value) end
    end }
-- the drawer's buttons bigger, 100% to 150%; the drawer grows to fit (live)
local BAG_SIZES = {}
for pct = 100, 150, 10 do BAG_SIZES[#BAG_SIZES + 1] = { pct, pct .. "%" } end
S:Row{ key = "mm.bagButtonSize", kind = "range", path = "minimap.bagButtonSize", choices = BAG_SIZES, tab = "buttons",
    disabled = function() return DrawerOff() or not S:GetPath("minimap.buttonBag") end,
    apply = function() if ns.MinimapBag and ns.MinimapBag.SizeChanged then ns.MinimapBag.SizeChanged() end end }

-- while a gathering addon that moves the map to scan is loaded: the flashing is its own (Minimap.lua)
S:Row{ key = "mm.nodeScanNote", kind = "text",
    hidden = function() return not (ns.Minimap and ns.Minimap.LoadedScanners and #ns.Minimap.LoadedScanners() > 0) end }
-- while a farming HUD that takes the minimap is loaded (ForeverFarmHUD, FarmHud)
S:Row{ key = "mm.hudNote", kind = "text",
    hidden = function() return not (ns.Minimap and ns.Minimap.LoadedHUDs and #ns.Minimap.LoadedHUDs() > 0) end }

-- FONTS (back from Edit Mode)
S:FontRows{ module = "mm", tab = "fonts", section = "mm.fonts",
    apply = function() if ns.Minimap and ns.Minimap.ApplyFonts then ns.Minimap:ApplyFonts() end end, fonts = {
    { key = "zone", path = "minimap.zoneFont" },
    { key = "clock", path = "minimap.clockFont" },
    { key = "info", path = "minimap.infoFont" },
    { key = "bar", path = "minimap.barFont" },
} }
