local _, ns = ...
local L = ns.L
local S = ns.Settings

--------------------------------------------------
-- DOT TRACKER
-- Settings for Modules/DotTracker.lua: where the mark shows (target, focus, nameplates), its look,
-- the kill icon and how careful the estimate is. The module's switch asks for a reload (the tracking
-- starts at login); everything else applies at once.
--------------------------------------------------
local function Refresh()
    if ns.Dots then ns.Dots:Refresh() end
end

S:Module{
    key = "dt", group = "combat", order = 6, enabled = "dots.enabled",
    -- another tracker is loaded: FlareUI's own stays off and says why
    banner = function()
        local other = ns.Dots and ns.Dots.OtherAddon and ns.Dots.OtherAddon()
        if other then return S:ModuleText("dt", "banner"):format(other, other) end
    end,
}

-- WHERE ------------------------------------------
S:Row{ key = "dt.target", half = true, section = "dt.where", path = "dots.target", apply = Refresh }
S:Row{ key = "dt.focus", half = true, section = "dt.where", path = "dots.focus", apply = Refresh }
S:Row{ key = "dt.plates", kind = "choice", section = "dt.where", path = "dots.plates",
    choices = { "off", "marker", "icon" }, apply = Refresh }

-- THE MARK ---------------------------------------
local function NoMarker() return S:GetPath("dots.marker") == false end
local OPACITY, SIZES = {}, {}
for n = 20, 100, 5 do OPACITY[#OPACITY + 1] = { n, n .. "%" } end
for n = 50, 200, 10 do SIZES[#SIZES + 1] = { n, n .. "%" } end
S:Row{ key = "dt.marker", lead = true, section = "dt.mark", path = "dots.marker", apply = Refresh }
S:Row{ key = "dt.position", kind = "choice", section = "dt.mark", path = "dots.position",
    choices = { "health", "start" }, apply = Refresh, disabled = NoMarker }
S:Row{ key = "dt.colors", kind = "choice", half = true, section = "dt.mark", path = "dots.colors",
    choices = { "each", "single" }, apply = Refresh, disabled = NoMarker }
S:Row{ key = "dt.opacity", kind = "range", half = true, section = "dt.mark", path = "dots.opacity",
    choices = OPACITY, apply = Refresh, disabled = NoMarker }
S:Row{ key = "dt.smooth", section = "dt.mark", path = "dots.smooth", apply = Refresh, disabled = NoMarker }

-- THE KILL ICON ----------------------------------
local function NoIcon() return S:GetPath("dots.icon") == "off" end
S:Row{ key = "dt.icon", kind = "choice", lead = true, section = "dt.kill", path = "dots.icon",
    choices = { "off", "skull", "cross" }, apply = Refresh }
S:Row{ key = "dt.iconSize", kind = "range", half = true, section = "dt.kill", path = "dots.iconSize",
    choices = SIZES, apply = Refresh, disabled = NoIcon }
S:Row{ key = "dt.pulse", half = true, section = "dt.kill", path = "dots.pulse", apply = Refresh, disabled = NoIcon }

-- ACCURACY ---------------------------------------
S:Row{ key = "dt.waitFirstTick", kind = "choice", section = "dt.accuracy", path = "dots.waitFirstTick",
    choices = { "off", "unsure", "always" }, apply = Refresh }
S:Row{ key = "dt.duringCast", half = true, section = "dt.accuracy", path = "dots.estimateDuringCast", apply = Refresh }
S:Row{ key = "dt.channels", half = true, section = "dt.accuracy", path = "dots.trackChannels", apply = Refresh }
S:Row{ key = "dt.reset", kind = "button", center = true, section = "dt.accuracy", buttonText = L["Reset Learned Ticks"],
    apply = function() if ns.Dots then ns.Dots:ResetLearned() end end }
