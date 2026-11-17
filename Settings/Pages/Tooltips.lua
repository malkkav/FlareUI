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

S:Module{ key = "tt", group = "interface", order = 20, enabled = "tooltips.enabled", tabs = { { key = "settings" }, { key = "tweaks" }, { key = "fonts" } } }

-- SETTINGS TAB (11-14, Malkkav): Look, then Mouseover (where each kind sits), then Visibility (when each
-- kind shows). The Tweaks tab holds the content switches.

-- LOOK: Tooltip Corner first (which corner of the HUD Tooltip box the tooltip grows from, ApplyAnchor)
S:Row{ key = "tt.corner", kind = "choice", path = "tooltips.corner", apply = Refresh,
    choices = { "auto", "BOTTOMRIGHT", "BOTTOMLEFT", "TOPRIGHT", "TOPLEFT" } }
local SCALES = {}
for i = 5, 15 do SCALES[#SCALES + 1] = { i / 10, (i * 10) .. "%" } end
S:Row{ key = "tt.scale", kind = "range", path = "tooltips.scale", choices = SCALES, apply = Refresh }
-- Screen Corner (11-17): tooltips in Blizzard's spot go to the screen's corner (Tooltip Corner's, or the
-- bottom right) instead of the HUD Tooltip box
S:Row{ key = "tt.screenCorner", path = "tooltips.screenCorner", apply = Refresh }
S:Row{ key = "tt.opacity", kind = "range", path = "tooltips.opacity", choices = S:OpacityChoices(), apply = Refresh }
-- (Health Bar is content: on the Content tab since 11-16, Malkkav; see Tweak below)
-- Off, Below the tooltip or Inside it (11-16, Malkkav; a switch before): over hideHealthBar + healthBarPlace
S:Row{ key = "tt.healthBar", kind = "choice", apply = Refresh, tab = "tweaks", choices = { "off", "below", "inside" },
    get = function()
        if S:GetPath("tooltips.hideHealthBar") then return "off" end
        return S:GetPath("tooltips.healthBarPlace") == "inside" and "inside" or "below"
    end,
    set = function(value)
        S:SetPath("tooltips.hideHealthBar", value == "off")
        if value ~= "off" then S:SetPath("tooltips.healthBarPlace", value) end
    end }

-- MOUSEOVER (11-14, Malkkav): one dropdown of toggles. All Tooltips or None clear the rest; ticking kinds
-- picks only those (each an exception to the main switch, Tooltips.lua TIP.SetKindMouseover); all six
-- ticked is All Tooltips again. Saved as before: tooltips.mouseover + tooltips.mouseoverKinds.
local KINDS = { "world", "frames", "bars", "auras", "groupAuras", "other" }
local MOUSE_SPEC = { exclusive = { "all", "none" }, tokens = KINDS, empty = "none" }
S:Row{ key = "tt.mouseover", kind = "dropdown", apply = Refresh, toggles = MOUSE_SPEC,
    choices = { "all", "none", { divider = true }, "world", "frames", "bars", "auras", "groupAuras", "other" },
    resetValue = function() return "none" end,
    get = function()
        local TIP = ns.Tooltips
        if not (TIP and TIP.Mouseover) then return "none" end
        local on = {}
        for _, kind in ipairs(KINDS) do if TIP.Mouseover(kind) then on[#on + 1] = kind end end
        if #on == #KINDS then return "all" end
        return #on > 0 and table.concat(on, ",") or "none"
    end,
    set = function(value)
        local TIP = ns.Tooltips
        if not (TIP and TIP.SetMouseover) then return end
        local set = ns.Conditions.Set(value, MOUSE_SPEC)
        local count = 0
        for _, kind in ipairs(KINDS) do if set[kind] then count = count + 1 end end
        if value == "all" or count == #KINDS then TIP.SetMouseover(true) return end
        TIP.SetMouseover(false)
        for _, kind in ipairs(KINDS) do if set[kind] then TIP.SetKindMouseover(kind, true) end end
    end }
-- how far from the pointer a mouseover tooltip sits, in pixels (TIP.CursorOffset); rank: under the switches
local OFFSETS = {}
for i = -50, 50, 2 do OFFSETS[#OFFSETS + 1] = { i, tostring(i) } end
S:Row{ key = "tt.cursorX", kind = "range", half = true, rank = 3.5, path = "tooltips.cursorX", choices = OFFSETS, apply = Refresh }
S:Row{ key = "tt.cursorY", kind = "range", half = true, rank = 3.5, path = "tooltips.cursorY", choices = OFFSETS, apply = Refresh }
-- Off in Combat (11-17): greyed while no kind of tooltip follows the mouse
S:Row{ key = "tt.cursorCombat", path = "tooltips.cursorCombat", rank = 3.6,
    disabled = function()
        local TIP = ns.Tooltips
        if not (TIP and TIP.Mouseover) then return true end
        for _, kind in ipairs(KINDS) do if TIP.Mouseover(kind) then return false end end
        return true
    end }

-- VISIBILITY (11-12): when each kind of tooltip shows; never greyed: Shift shows a hidden tooltip.
-- Two columns, the same order as the Mouseover switches.
local SHOW = { "always", "combat", "never" }
local function Show(key, path, apply)
    local row = { key = key, kind = "choice", half = true, choices = SHOW, apply = apply or Refresh }
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

-- Coloured Borders is look: in Look, under Frame Opacity (11-17, was on the Content tab)
local borders = Both({ "tooltips.borderByReaction", "tooltips.borderByClass", "tooltips.borderByQuality" })
S:Row{ key = "tt.borders", get = borders.get, set = borders.set, apply = Refresh }

-- CONTENT TAB (11-17, sorted): Layout, Units, Items, then Details (IDs and when they show). The copy
-- gives each row its section.
-- Layout (11-17, after PrettyTooltip): the top of the tooltip (TooltipsLayout.lua), first on the Content tab
local function Layout(row) row.half = true; row.tab = "tweaks"; S:Row(row) end
Layout{ key = "tt.headerIcon", path = "tooltips.headerIcon" }
Layout{ key = "tt.badges", path = "tooltips.badges" }
Layout{ key = "tt.spellStrip", path = "tooltips.spellStrip" }
local ids = Both({ "tooltips.showItemID", "tooltips.showSpellID" })
local function Tweak(row) row.half = true; row.tab = "tweaks"; S:Row(row) end
Tweak{ key = "tt.classNames", apply = Refresh,
    get = function() return S:GetPath("tooltips.nameColor") == "class" end,
    set = function(on) S:SetPath("tooltips.nameColor", on and "class" or "none") end }
Tweak{ key = "tt.showGuild", path = "tooltips.showGuild", apply = Refresh }
Tweak{ key = "tt.showTarget", path = "tooltips.showTarget", apply = Refresh }
Tweak{ key = "tt.showThreat", path = "tooltips.showThreat" }
Tweak{ key = "tt.hideFaction", path = "tooltips.hideFaction", apply = Refresh }
Tweak{ key = "tt.ids", get = ids.get, set = ids.set, apply = Refresh }
Tweak{ key = "tt.shortItemStats", path = "tooltips.shortItemStats" }
Tweak{ key = "tt.itemLevel", path = "tooltips.itemLevel" }
Tweak{ key = "tt.compareShift", path = "tooltips.compareShift", apply = Refresh }
-- (11-17) after PrettyTooltip
Tweak{ key = "tt.gatheringLevels", path = "tooltips.gatheringLevels" }
Tweak{ key = "tt.auraCaster", path = "tooltips.auraCaster" }
Tweak{ key = "tt.disenchant", path = "tooltips.disenchant" }
Tweak{ key = "tt.stackPrice", path = "tooltips.stackPrice", disabled = function() return S:GetPath("tooltips.hideSellPrice") end }
Tweak{ key = "tt.hideSellPrice", path = "tooltips.hideSellPrice" }
Tweak{ key = "tt.detailsShift", path = "tooltips.detailsShift" }

S:FontRows{ module = "tt", tab = "fonts", section = "tt.fonts", apply = Refresh, fonts = {
    { key = "title", path = "tooltips.titleFont" },
    { key = "text", path = "tooltips.contentFont" },
} }
