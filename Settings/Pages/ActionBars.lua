local _, ns = ...
local L = ns.L
local S = ns.Settings

--------------------------------------------------
-- ACTION BARS
-- Settings for Modules/ActionBars.lua, Visibility.lua and XPBar.lua; per-bar visibility and fading
-- live in Edit Mode.
--------------------------------------------------
local function Refresh()
    if ns.ActionBars and ns.ActionBars.Refresh then ns.ActionBars:Refresh() end
    if ns.Visibility and ns.Visibility.Refresh then ns.Visibility:Refresh() end
end

S:Module{
    key = "ab", group = "combat", order = 10, enabled = "actionbars.enabled",
    -- (11-16, Malkkav: XP Bar and Hide Bars in one Other Bars tab, "xp")
    tabs = { { key = "settings" }, { key = "xp" }, { key = "fcm" }, { key = "fonts" } },
    -- Blizzard's bars: no FlareUI frame to select, so plain Edit Mode
    editMode = function() return nil end,
    -- the XP bar is FlareUI's own frame; each bar's fade settings sit in Blizzard's bar dialogs
    editFrames = { function() return _G.FlareUI_XPBar end },
    editSystems = function() return ns.Visibility and ns.Visibility.EditSystems and ns.Visibility:EditSystems() or {} end,
}

-- BAR APPEARANCE (11-11): the bars as a whole, above the buttons' own look
S:Row{ key = "ab.flareBorders", section = "ab.barAppearance", path = "actionbars.flareBorders", apply = Refresh, half = true }
-- Blizzard's Cooldown Manager restyled (Auras.lua 9b, so it needs Buffs & Debuffs on); off needs a
-- reload to give Blizzard's look back
S:Row{ key = "ab.skinCDM", section = "ab.barAppearance", path = "auras.skinCDM", reload = true, half = true,
    -- (greyed while Blizzard's own Cooldown Manager is off: it is left alone then, 11-11)
    disabled = function() return not S:GetPath("auras.enabled") or not (ns.CooldownManagerOn and ns.CooldownManagerOn()) end }
-- every button's scale, as FlareUI 1.0's per-bar scales once (fixed at 106% since; 111% the default from 11-11)
local SCALES = {}
-- in half-percent steps (11-11 Malkkav: it is that precise); kept as tenths of a percent so no float drifts
for tenths = 700, 1500, 5 do
    local percent = tenths / 10
    SCALES[#SCALES + 1] = { tenths / 1000, (percent % 1 == 0 and ("%d"):format(percent) or ("%.1f"):format(percent)) .. "%" }
end
-- (11-16, Malkkav: "Button Scale"; 11-17 back in Bars Appearance, where Bar Scale was)
S:Row{ key = "ab.buttonScale", kind = "range", section = "ab.barAppearance", choices = SCALES, apply = Refresh,
    get = function()
        local v = tonumber(S:GetPath("actionbars.buttonScale")) or 1.11
        return math.floor(v * 200 + 0.5) * 5 / 1000
    end,
    set = function(v) S:SetPath("actionbars.buttonScale", v) end }

-- (Gryphons Behind Bars moved to Quality of Life > Hide Clutter as the Gryphons choice, 11-16)
-- the micro menu and the bag bar (11-13, a player's request)
S:Row{ key = "ab.borderlessMenu", section = "ab.barAppearance", path = "actionbars.borderlessMenu", apply = Refresh, half = true }
-- (11-16, Malkkav: Borderless Bag Bar merged in; a folded bar needs the frame gone anyway)
S:Row{ key = "ab.collapsibleBags", section = "ab.barAppearance", path = "actionbars.collapsibleBags", apply = Refresh, half = true }

-- in pairs (half rows, 11-11 Malkkav): Show Button Art | Proc Glow, Status Colouring | Active Highlight
-- (Dim on Cooldown is part of Status Colouring since 11-16); then the text (Show Keybind Text | Show
-- Macro Text), the spells, paging
S:Row{ key = "ab.buttonArt", section = "ab.buttonAppearance", path = "actionbars.buttonArt", apply = Refresh, half = true }
S:Row{ key = "ab.procGlow", section = "ab.buttonAppearance", path = "actionbars.procGlow", half = true,
    apply = function() if ns.ProcGlow then ns.ProcGlow:Refresh() end end }
S:Row{
    key = "ab.statusColours", section = "ab.buttonAppearance", apply = Refresh, half = true,
    get = function() return S:GetPath("actionbars.colors.enableRange") end,
    set = function(on)
        S:SetPath("actionbars.colors.enableRange", on)
        S:SetPath("actionbars.colors.unusable.desaturate", on)
    end,
}
S:Row{ key = "ab.activeHighlight", section = "ab.buttonAppearance", path = "actionbars.activeHighlight", apply = Refresh, half = true }
-- Show Keybind Text / Show Macro Text (11-13, were Hide ...): on by default, over the saved hide values
S:Row{ key = "ab.hideKeybinds", section = "ab.buttonAppearance",   -- (Button Text merged in, last two rows, 11-16 Malkkav)
    path = "actionbars.hideHotkeys", invert = true, apply = Refresh, half = true }
S:Row{ key = "ab.hideMacroText", section = "ab.buttonAppearance", path = "actionbars.hideMacroText", invert = true, apply = Refresh, half = true }
S:Row{ key = "ab.autoRanks", section = "ab.spellBehavior", path = "actionbars.autoRanks", half = true,
    apply = function() if ns.ActionBars.CatchUpRanks then ns.ActionBars:CatchUpRanks() end end }
S:Row{ key = "ab.stopAutoAdd", section = "ab.spellBehavior", path = "actionbars.stopAutoAddSpells", apply = Refresh, half = true }
S:Row{ key = "ab.keepStealthPage", section = "ab.spellBehavior", path = "actionbars.keepStealthPage", apply = Refresh, half = true }
S:Row{ key = "ab.noStancePaging", section = "ab.spellBehavior", path = "actionbars.noStancePaging", apply = Refresh, half = true }

-- the FlareUI XP Bar: off leaves Blizzard's bars alone, so turning it on or off reloads; its options sit
-- under it and grey out while it's off

S:Row{ key = "ab.xpBar", tab = "xp", path = "actionbars.xpbar.enabled", reload = true }
S:Row{ key = "ab.xpText", tab = "xp", kind = "choice", path = "actionbars.xpbar.textMode", choices = { "ALWAYS", "HOVER" }, parent = "ab.xpBar",   -- (Always first, 11-16 Malkkav)
    apply = function() if ns.XPBar and ns.XPBar.Refresh then ns.XPBar:Refresh() end end }
S:Row{ key = "ab.xpNumbers", tab = "xp", kind = "choice", path = "actionbars.xpbar.textFormat", choices = { "VALUES", "BOTH", "PERCENT", "REMAINING" }, parent = "ab.xpBar",   -- (Percent after Current / Max (Percent), 11-16 Malkkav)
    apply = function() if ns.XPBar and ns.XPBar.Refresh then ns.XPBar:Refresh() end end }
-- one choice for both settings: Off clears questXP, the rest set it and pick the quests counted
S:Row{ key = "ab.xpQuest", tab = "xp", kind = "choice", choices = { "off", "all", "done", "zone" }, parent = "ab.xpBar",   -- (All above Completed, 11-16 Malkkav)
    get = function()
        if not S:GetPath("actionbars.xpbar.questXP") then return "off" end
        return S:GetPath("actionbars.xpbar.questXPMode") or "done"
    end,
    set = function(v)
        S:SetPath("actionbars.xpbar.questXP", v ~= "off")
        if v ~= "off" then S:SetPath("actionbars.xpbar.questXPMode", v) end
    end,
    apply = function() if ns.XPBar and ns.XPBar.Refresh then ns.XPBar:Refresh() end end }
-- Bubbles: Off, 10 or 20; the old switch saved true for 20, so true still reads as 20
S:Row{ key = "ab.xpBubbles", tab = "xp", kind = "choice", choices = { "off", "10", "20" }, parent = "ab.xpBar",
    get = function()
        local v = S:GetPath("actionbars.xpbar.bubbles")
        if v == true or v == 20 then return "20" end
        if v == 10 then return "10" end
        return "off"
    end,
    set = function(v) S:SetPath("actionbars.xpbar.bubbles", tonumber(v) or false) end,
    apply = function() if ns.XPBar and ns.XPBar.Refresh then ns.XPBar:Refresh() end end }

-- Hide Blizzard elements (also removed from Edit Mode)
local function Hide(key, path)
    S:Row{ key = "ab." .. key, path = "visibility." .. path, apply = Refresh, tab = "xp", section = "ab.hideBlizzardElements", half = true }
end
Hide("hideMicroMenu", "hideMicroMenu")
Hide("hideBagBar", "hideBagBar")
Hide("hidePetBar", "hidePetBar")
Hide("hideStanceBar", "hideStanceBar")
Hide("hideTotemBar", "hideTotemBar")
Hide("hidePossessBar", "hidePossessBar")
-- (Gryphons and Raid Manager moved to Quality of Life > Hide Clutter, 11-16, Malkkav: not bars)

-- Fake Cooldown Manager tab: no switch, it is on while any bar is picked. First a note on what it is and
-- how to fill it (11-16, Malkkav: from what he told a player), a section of its own above the bars
S:Row{ key = "ab.fcmNote", kind = "text", noTitle = true, tab = "fcm", section = "ab.fcmAbout" }
for i = 1, 8 do
    S:Row{ key = "ab.fcmBar" .. i, tab = "fcm", path = "fcm.bars.bar" .. i .. ".enabled", apply = Refresh,
        section = "ab.fakeCooldownManager", half = true }
end
S:Row{
    -- toggles as on the bars (ns.Conditions), Mouseover one of them (11-12): nothing ticked is Always
    key = "ab.fcmShow", kind = "dropdown", tab = "fcm", path = "fcm.show", section = "ab.fakeCooldownManager",
    choices = { "always", { divider = true }, "mouseover", "combat", "hastarget", "attackable", "ingroup", "unmounted" }, apply = Refresh,
    toggles = { exclusive = { "always" }, tokens = ns.Conditions.MOUSE_TOKENS, legacy = ns.Conditions.BAR_LEGACY, empty = "always" },
    -- (11-16, Malkkav) above the bar switches: as a dropdown it leads, the bars and Setup Mode follow
}
S:Row{
    key = "ab.fcmSetup", kind = "button", tab = "fcm", center = true, section = "ab.fakeCooldownManager", gapAbove = 12,
    disabled = function() return not ns.FCMActive() end,
    apply = function() if ns.ToggleFCMSetupMode then ns.ToggleFCMSetupMode() end end,
}

S:FontRows{ module = "ab", tab = "fonts", section = "ab.fonts", apply = Refresh, fonts = {
    { key = "keybinds", path = "actionbars.hotkeyFont" },
    { key = "count", path = "actionbars.countFont" },
    { key = "macro", path = "actionbars.macroFont" },
} }
-- the XP bar's numbers in a section of their own (11-13)
S:FontRows{ module = "ab", tab = "fonts", section = "ab.fontsXp",
    apply = function() if ns.XPBar and ns.XPBar.Refresh then ns.XPBar:Refresh() end end, fonts = {
    { key = "xp", path = "actionbars.xpFont" },
} }
