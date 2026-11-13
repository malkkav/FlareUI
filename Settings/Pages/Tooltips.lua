local _, ns = ...
local S = ns.Settings

--------------------------------------------------
-- TOOLTIPS
-- Settings for Modules/Tooltips.lua.
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

S:Module{ key = "tt", group = "interface", order = 20, enabled = "tooltips.enabled", tabs = { { key = "settings" }, { key = "visibility" }, { key = "fonts" } } }

local SCALES = {}
for i = 5, 15 do SCALES[#SCALES + 1] = { i / 10, (i * 10) .. "%" } end
S:Row{ key = "tt.scale", kind = "range", path = "tooltips.scale", choices = SCALES, apply = Refresh }
S:Row{ key = "tt.opacity", kind = "range", path = "tooltips.opacity", choices = S:OpacityChoices(), apply = Refresh }
-- Mouseover: every tooltip at the pointer, or none; the Visibility tab makes exceptions (11-12)
S:Row{ key = "tt.mouseover", apply = Refresh, resetValue = function() return false end,
    get = function() return ns.Tooltips and ns.Tooltips.Mouseover and ns.Tooltips.Mouseover() or false end,
    set = function(on) if ns.Tooltips and ns.Tooltips.SetMouseover then ns.Tooltips.SetMouseover(on) end end }


S:Row{ key = "tt.healthBar", apply = Refresh,
    get = function() return not S:GetPath("tooltips.hideHealthBar") end,
    set = function(on) S:SetPath("tooltips.hideHealthBar", not on) end }

local ids = Both({ "tooltips.showItemID", "tooltips.showSpellID" })
local borders = Both({ "tooltips.borderByReaction", "tooltips.borderByClass", "tooltips.borderByQuality" })
-- in pairs: units (borders, names, target and threat, guild, faction), then IDs, then items
S:Row{ half = true, key = "tt.borders", get = borders.get, set = borders.set, apply = Refresh }
S:Row{
    key = "tt.classNames", half = true, apply = Refresh,
    get = function() return S:GetPath("tooltips.nameColor") == "class" end,
    set = function(on) S:SetPath("tooltips.nameColor", on and "class" or "none") end,
}
S:Row{ half = true, key = "tt.showGuild", path = "tooltips.showGuild", apply = Refresh }
S:Row{ half = true, key = "tt.showGuildRank", path = "tooltips.showGuildRank", parent = "tt.showGuild", apply = Refresh }
S:Row{ half = true, key = "tt.showTarget", path = "tooltips.showTarget", apply = Refresh }
S:Row{ half = true, key = "tt.showThreat", path = "tooltips.showThreat" }
S:Row{ half = true, key = "tt.hideFaction", path = "tooltips.hideFaction", apply = Refresh }
S:Row{ half = true, key = "tt.ids", get = ids.get, set = ids.set, apply = Refresh }
S:Row{ half = true, key = "tt.shortItemStats", path = "tooltips.shortItemStats" }
S:Row{ half = true, key = "tt.itemLevel", path = "tooltips.itemLevel" }
S:Row{ half = true, key = "tt.compareShift", path = "tooltips.compareShift", apply = Refresh }

-- VISIBILITY TAB (11-12): when each kind of tooltip shows, then whether it sits at the pointer.
-- The Mouseover switches start as the Settings tab's Mouseover; one changed here is that kind's exception
-- (Tooltips.lua TIP.Mouseover), never greyed: Shift shows a hidden tooltip. Two columns, the same order in both.
local SHOW = { "always", "combat", "never" }
local function Show(key, path, apply)
    local row = { key = key, kind = "choice", half = true, tab = "visibility", choices = SHOW, apply = apply or Refresh }
    if type(path) == "table" then row.get, row.set = path.get, path.set else row.path = path end
    S:Row(row)
end
local world = Both({ "tooltips.visibility.worldUnits", "tooltips.visibility.worldObjects" })
Show("tt.showWorld", world)
Show("tt.showFrames", "tooltips.visibility.frameUnits")
Show("tt.showBars", "tooltips.visibility.actionBars")
Show("tt.showAuras", "tooltips.visibility.auras")
-- party and raid aura icons only take the mouse when this lets them (PartyFrames.lua)
Show("tt.showGroupAuras", "tooltips.visibility.groupAuras",
    function() if ns.PartyFrames and ns.PartyFrames.ApplyAuraMouse then ns.PartyFrames.ApplyAuraMouse() end end)
Show("tt.showOther", "tooltips.visibility.other")

local function Mouseover(key, kind)
    S:Row{ key = key, half = true, tab = "visibility", apply = Refresh,
        resetValue = function() return S:GetPath("tooltips.mouseover") == true end,
        get = function() return ns.Tooltips and ns.Tooltips.Mouseover and ns.Tooltips.Mouseover(kind) or false end,
        set = function(on) if ns.Tooltips and ns.Tooltips.SetKindMouseover then ns.Tooltips.SetKindMouseover(kind, on) end end }
end
Mouseover("tt.posWorld", "world")
Mouseover("tt.posFrames", "frames")
Mouseover("tt.posBars", "bars")
Mouseover("tt.posAuras", "auras")
Mouseover("tt.posGroupAuras", "groupAuras")
Mouseover("tt.posOther", "other")

S:FontRows{ module = "tt", tab = "fonts", section = "tt.fonts", apply = Refresh, fonts = {
    { key = "title", path = "tooltips.titleFont" },
    { key = "text", path = "tooltips.contentFont" },
} }
