local _, ns = ...
local S = ns.Settings

--------------------------------------------------
-- BUFFS & DEBUFFS (Modules/Auras.lua): the player's buff and debuff frames. Fixed, no option: the
-- icon swipe, weapon enchants shown. Unit frame auras have their own shape and timer (Unit Frames).
--------------------------------------------------
local function Refresh()
    if ns.Auras and ns.Auras.Refresh then ns.Auras:Refresh() end
end

local function Holder(kind)
    return function() return ns.Auras and ns.Auras.GetFrame and ns.Auras:GetFrame(kind) end
end

S:Module{
    key = "au", group = "HUD", order = 50, enabled = "auras.enabled",
    tabs = { { key = "settings" }, { key = "fonts" } },
    editMode = Holder("buffs"),
    editFrames = { Holder("buffs"), Holder("debuffs") },
}

S:Row{ key = "au.shape", kind = "choice", path = "auras.style", choices = { "round", "square" }, apply = Refresh }
S:Row{ key = "au.timer", kind = "choice", path = "auras.timer", choices = { "below", "bottom", "middle", "none" }, apply = Refresh }

S:FontRows{ module = "au", tab = "fonts", section = "au.fonts", apply = Refresh, fonts = {
    { key = "timer", path = "auras.font" },
} }
