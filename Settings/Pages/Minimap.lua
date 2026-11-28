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
    -- Map (Look, Info Bar, Tweaks, Minimap Icons), Addon Buttons, Fonts
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
-- (11-26, SupS) then a line and every Shared Media border: laid out as Thick, they may not line up
S:Row{ key = "mm.squareBorder", kind = "choice", section = "mm.styleSection",
    choices = function()
        local list = { "bronze", "header", "thin", "thick" }
        -- FlareUI Frames, then other addons' borders (ns.AddonMedia: never Blizzard's, Malkkav 11-27)
        local LSM = LibStub("LibSharedMedia-3.0", true)
        local extra = {}
        if LSM and LSM:IsValid("border", "FlareUI Frames") then extra[1] = { "FlareUI Frames", "FlareUI Frames" } end
        for _, name in ipairs(ns.AddonMedia and ns.AddonMedia("border") or {}) do extra[#extra + 1] = { name, name } end
        if #extra > 0 then
            list[#list + 1] = { divider = true }
            for _, c in ipairs(extra) do list[#list + 1] = c end
        end
        return list
    end,
    get = function()
        if S:GetPath("minimap.squareHeader") == "art" then return "header" end
        local value = S:GetPath("minimap.squareBorder")
        if value == "thick" or value == "thin" then return value end
        if ns.Minimap and ns.Minimap.CustomBorderSpec and ns.Minimap.CustomBorderSpec(value) then return value end
        return "bronze"
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
-- the Info Bar
-- (the Info Bar shows under the round map too)
local BAR_VALUES = { "none", "gold", "bags", "durability", "fps", "latency", "coords", "coordsSimple", "xp", "friends", "guild" }
-- the three cells on one line with no labels, laid out as the bar itself; pointing at
-- one shows its Left / Center / Right text
-- the round map shows the Center cell only, inside the circle: Left and Right greyed there until
-- Below the Map puts the bar under the map, where all three fit
local function RoundMap()
    return S:GetPath("minimap.style") == "round" and not S:GetPath("minimap.infoBarBelow")
end
for _, side in ipairs({ "Left", "Center", "Right" }) do
    S:Row{ key = "mm.bar" .. side, kind = "choice", third = true, bare = true,
        path = "minimap.infoBar." .. side:lower(), choices = BAR_VALUES, apply = Refresh,
        disabled = side ~= "Center" and RoundMap or nil }
end
-- On Mouseover (off): the bar shows only while you point at the minimap
-- Show Box (on): the plates behind the cells; off, the text alone
S:Row{ key = "mm.barBox", path = "minimap.infoBarBox", apply = Refresh, half = true }
S:Row{ key = "mm.barHover", path = "minimap.infoBarHover", apply = Refresh, half = true }
-- Position { On the Map · Below the Map } (was the Below the Map switch, Malkkav 11-27; same saved
-- minimap.infoBarBelow): below, the bar hangs under the map's frame, clear of the quest arrow (Minimap.lua
-- Bar.Below). A whole row, so Show Box and Only on Mouseover pair below it
S:Row{ key = "mm.barBelow", kind = "choice", choices = { "map", "below" }, apply = Refresh,
    get = function() return S:GetPath("minimap.infoBarBelow") == true and "below" or "map" end,
    set = function(v) S:SetPath("minimap.infoBarBelow", v == "below") end,
    resetValue = function() return "map" end }
-- Tweaks: Auto Zoom Out, then the two switches in two columns
S:Row{ key = "mm.zoom", kind = "choice", path = "minimap.autoZoom", choices = { 0, 5, 10, 30 }, apply = Refresh }
-- FPS/Latency on Clock, then Middle-Click Menu (Malkkav 11-27)
S:Row{ key = "mm.clockStats", path = "minimap.clockStats", half = true }
S:Row{ key = "mm.microMenu", path = "minimap.microMenu", half = true,
    apply = function() if ns.Minimap and ns.Minimap.UpdateMapMouse then ns.Minimap.UpdateMapMouse() end end }
-- FlareUI Minimap Button: FlareUI's own button, on the minimap or in the drawer
-- (live; its right-click turns it off)
-- Drawer Style: Disabled / Sundial / Blizzard, first in Addon Buttons; Disabled greys the
-- section's other rows (reload: the drawer and its button are made as the game loads)
local function DrawerOff() return S:GetPath("minimap.drawerStyle") == "disabled" end
-- Sundial off (Minimap Icons): no Sundial choice, and a saved Sundial shows as Blizzard
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
            return { { "disabled", L["Off"] }, { "blizzard", L["Blizzard"] } }
        end
        return { "disabled", "sundial", "blizzard" }
    end }
-- (not greyed with the drawer Off: the button then sits on the minimap). A whole row, the two
-- mouseover switches paired below it (Malkkav 11-27)
S:Row{ key = "mm.flareButton", path = "minimap.flareButton", tab = "buttons",
    apply = function() if ns.MinimapBag and ns.MinimapBag.FlareChanged then ns.MinimapBag.FlareChanged() end end }
-- Minimap Icons: one dropdown of toggles for the four icons, in the order they stack on the map,
-- bottom to top. Saved as before: minimap.sundial (off = false; a reload hides or shows it, and off
-- moves a drawer opened from it to Blizzard), minimap.finderEye, minimap.vehicleExit, minimap.durability.
local ICONS = { "sundial", "finderEye", "vehicleExit", "durability" }
local ICON_SPEC = { exclusive = { "none" }, tokens = ICONS, empty = "none" }
local function IconOn(key)
    if key == "sundial" then return S:GetPath("minimap.sundial") ~= false end
    return S:GetPath("minimap." .. key) and true or false
end
local startSundial
S:Row{ key = "mm.icons", kind = "dropdown", toggles = ICON_SPEC,
    choices = { "none", { divider = true }, "sundial", "finderEye", "vehicleExit", "durability" },
    get = function()
        local on = {}
        for _, key in ipairs(ICONS) do if IconOn(key) then on[#on + 1] = key end end
        return #on > 0 and table.concat(on, ",") or "none"
    end,
    set = function(value)
        local set = ns.Conditions.Set(value, ICON_SPEC)
        if startSundial == nil then startSundial = IconOn("sundial") end
        local sundial = set.sundial and true or false
        S:SetPath("minimap.sundial", sundial)
        if not sundial then
            local style = S:GetPath("minimap.drawerStyle")
            if style ~= "disabled" and style ~= "blizzard" then S:SetPath("minimap.drawerStyle", "blizzard") end
        end
        S:TrackReload("mm.icons", sundial, startSundial)
        for i = 2, #ICONS do S:SetPath("minimap." .. ICONS[i], set[ICONS[i]] and true or false) end
    end,
    apply = function()
        if ns.MinimapEye and ns.MinimapEye.Update then ns.MinimapEye.Update() end
        if ns.MinimapVehicle and ns.MinimapVehicle.Update then ns.MinimapVehicle.Update() end
        if ns.MinimapDurability and ns.MinimapDurability.Update then ns.MinimapDurability.Update() end
    end,
    resetValue = function() return "sundial" end }
-- the icons on the map's edge (sundial, Group Finder, Vehicle Exit, Durability) slide along it and
-- resize with Shift and Ctrl held, always on (Minimap.lua MM.Moves): how, and a button that puts
-- every one back
S:Row{ key = "mm.resetButtonMoves", kind = "button", center = true, section = "mm.iconsSection",
    apply = function() if ns.Minimap and ns.Minimap.ResetButtonMoves then ns.Minimap.ResetButtonMoves() end end }
-- the drawer opens on the pointer instead of a click (live)
S:Row{ key = "mm.bagHover", path = "minimap.bagHover", tab = "buttons", half = true,
    disabled = DrawerOff }
-- (deroostr 11-27) the addon buttons on the map's edge only while you point at the map (Minimap.lua
-- MM.ButtonsHover), Open Drawer on Mouseover's partner. Not greyed with the drawer Off: then every button
-- is on the edge.
S:Row{ key = "mm.buttonsHover", path = "minimap.buttonsHover", tab = "buttons", half = true, apply = Refresh }
-- which addons go in it (ticked) and which are left alone on the minimap; a reload puts a
-- button back where its addon keeps it. None: every button on the minimap's edge.
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
        return ns.MinimapBag and ns.MinimapBag.InDrawer and ns.MinimapBag.InDrawer() or "none"
    end,
    set = function(value)
        -- None: every addon's button stays on the minimap's edge (the drawer is turned off by Drawer Style Off only)
        if value == nil or value == "none" then value = "" end
        if ns.MinimapBag and ns.MinimapBag.SetInDrawer then ns.MinimapBag.SetInDrawer(value) end
    end }
-- the drawer's buttons bigger, 100% to 150%; the drawer grows to fit (live)
local BAG_SIZES = {}
for pct = 100, 150, 10 do BAG_SIZES[#BAG_SIZES + 1] = { pct, pct .. "%" } end
S:Row{ key = "mm.bagButtonSize", kind = "range", path = "minimap.bagButtonSize", choices = BAG_SIZES, tab = "buttons",
    disabled = DrawerOff,
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
