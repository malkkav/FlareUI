local _, ns = ...
local S = ns.Settings

--------------------------------------------------
-- BUFFS & DEBUFFS
-- Settings for the player's buff and debuff frames (Modules/Auras.lua).
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
S:Row{ key = "au.swipe", kind = "choice", path = "auras.swipe", choices = { "icon", "border", "both", "none" }, apply = Refresh }
S:Row{ key = "au.timer", kind = "choice", path = "auras.timer", choices = { "below", "bottom", "middle", "none" }, apply = Refresh }

local function NoMineFirst()
    local sort = S:GetPath("auras.sort")
    return sort ~= "time" and sort ~= "name"
end
S:Row{ key = "au.sort", kind = "choice", path = "auras.sort", choices = { "default", "applied", "time", "name" }, apply = Refresh }
S:Row{ key = "au.reverse", path = "auras.reverse", apply = Refresh }
S:Row{ key = "au.mineFirst", path = "auras.mineFirst", apply = Refresh, disabled = NoMineFirst }

S:FontRows{ module = "au", tab = "fonts", section = "au.fonts", apply = Refresh, fonts = {
    { key = "timer", path = "auras.font" },
} }
