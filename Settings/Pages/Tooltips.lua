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

-- SETTINGS TAB: Look, then Position (where each kind sits), then Visibility (when each
-- kind shows). The Tweaks tab holds the content switches.

-- LOOK first (above Position)
local SCALES = {}
for i = 5, 15 do SCALES[#SCALES + 1] = { i / 10, (i * 10) .. "%" } end
S:Row{ key = "tt.scale", kind = "range", path = "tooltips.scale", choices = SCALES, apply = Refresh }
S:Row{ key = "tt.opacity", kind = "range", path = "tooltips.opacity", choices = S:OpacityChoices(), apply = Refresh }
-- POSITION: Tooltip Corner (which corner of the HUD Tooltip box the tooltip grows from, ApplyAnchor),
-- registered after Look so its section comes second
S:Row{ key = "tt.corner", kind = "choice", path = "tooltips.corner", apply = Refresh,
    choices = { "auto", "BOTTOMRIGHT", "BOTTOMLEFT", "TOPRIGHT", "TOPLEFT" } }
-- (Health Bar is content: on the Content tab; see Tweak below)
-- Off, Below the tooltip or Inside it: over hideHealthBar + healthBarPlace
S:Row{ key = "tt.healthBar", kind = "choice", apply = Refresh, tab = "tweaks", choices = { "off", "below", "inside" },
    get = function()
        if S:GetPath("tooltips.hideHealthBar") then return "off" end
        return S:GetPath("tooltips.healthBarPlace") == "inside" and "inside" or "below"
    end,
    set = function(value)
        S:SetPath("tooltips.hideHealthBar", value == "off")
        if value ~= "off" then S:SetPath("tooltips.healthBarPlace", value) end
    end }

-- MOUSEOVER: one dropdown of toggles. All Tooltips or None clear the rest; ticking kinds
-- picks only those (each an exception to the main switch, Tooltips.lua TIP.SetKindMouseover); all six
-- ticked is All Tooltips again. Saved as before: tooltips.mouseover + tooltips.mouseoverKinds.
local KINDS = { "world", "frames", "bars", "auras", "groupAuras", "other" }
local MOUSE_SPEC = { exclusive = { "all", "none" }, tokens = KINDS, empty = "none" }
S:Row{ key = "tt.mouseover", kind = "dropdown", apply = Refresh, toggles = MOUSE_SPEC,
    choices = { "none", "all", { divider = true }, "world", "frames", "bars", "auras", "groupAuras", "other" },
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
-- how far from the pointer a mouseover tooltip sits, in pixels (TIP.CursorOffset)
local OFFSETS = {}
for i = -50, 50, 2 do OFFSETS[#OFFSETS + 1] = { i, tostring(i) } end
-- greyed while Mouseover is None: no tooltip sits at the pointer then
local function NoMouseover()
    local TIP = ns.Tooltips
    if not (TIP and TIP.Mouseover) then return true end
    for _, kind in ipairs(KINDS) do if TIP.Mouseover(kind) then return false end end
    return true
end
S:Row{ key = "tt.cursorX", kind = "range", half = true, path = "tooltips.cursorX", choices = OFFSETS, apply = Refresh, disabled = NoMouseover }
S:Row{ key = "tt.cursorY", kind = "range", half = true, path = "tooltips.cursorY", choices = OFFSETS, apply = Refresh, disabled = NoMouseover }

-- VISIBILITY: when each kind of tooltip shows; never greyed: Shift shows a hidden tooltip.
-- Two columns, the same order as the Mouseover switches.
local SHOW = { "never", "always", "combat" }   -- (Never first: Off first)
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

-- TWEAKS TAB: in pairs: units (borders, names, target and threat, guild, faction), then IDs, then items
local ids = Both({ "tooltips.showItemID", "tooltips.showSpellID" })
local borders = Both({ "tooltips.borderByReaction", "tooltips.borderByClass", "tooltips.borderByQuality" })
local function Tweak(row) row.half = true; row.tab = "tweaks"; S:Row(row) end
Tweak{ key = "tt.borders", get = borders.get, set = borders.set, apply = Refresh }
Tweak{ key = "tt.classNames", apply = Refresh,
    get = function() return S:GetPath("tooltips.nameColor") == "class" end,
    set = function(on) S:SetPath("tooltips.nameColor", on and "class" or "none") end }
Tweak{ key = "tt.showGuild", path = "tooltips.showGuild", apply = Refresh }
-- greyed while the guild line is off (no indent)
Tweak{ key = "tt.showGuildRank", path = "tooltips.showGuildRank", apply = Refresh,
    disabled = function() return S:GetPath("tooltips.showGuild") == false end }
Tweak{ key = "tt.showPvP", path = "tooltips.showPvP", apply = Refresh }
Tweak{ key = "tt.showFaction", path = "tooltips.showFaction", apply = Refresh }
Tweak{ key = "tt.showTarget", path = "tooltips.showTarget", apply = Refresh }
Tweak{ key = "tt.showThreat", path = "tooltips.showThreat" }
Tweak{ key = "tt.ids", get = ids.get, set = ids.set, apply = Refresh }
Tweak{ key = "tt.itemLevel", path = "tooltips.itemLevel" }
Tweak{ key = "tt.compareShift", path = "tooltips.compareShift", apply = Refresh }
Tweak{ key = "tt.shortItemStats", path = "tooltips.shortItemStats" }
-- after the switches (rank 3.5), beside Simplified Item Stats, greyed while it is off (no indent)
Tweak{ key = "tt.healingDamage", kind = "choice", path = "tooltips.healingDamage", rank = 3.5,
    choices = { "off", "damage", "power" },
    disabled = function() return not S:GetPath("tooltips.shortItemStats") end }

S:FontRows{ module = "tt", tab = "fonts", section = "tt.fonts", apply = Refresh, fonts = {
    { key = "title", path = "tooltips.titleFont" },
    { key = "text", path = "tooltips.contentFont" },
} }
