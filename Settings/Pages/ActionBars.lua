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
    key = "ab", group = "HUD", order = 10, enabled = "actionbars.enabled",
    tabs = { { key = "settings" }, { key = "visibility" }, { key = "fcm" }, { key = "fonts" } },
    -- Blizzard's bars: no FlareUI frame to select, so plain Edit Mode
    editMode = function() return nil end,
    -- the XP bar is FlareUI's own frame; each bar's fade settings sit in Blizzard's bar dialogs
    editFrames = { function() return _G.FlareUI_XPBar end },
    editSystems = function() return ns.Visibility and ns.Visibility.EditSystems and ns.Visibility:EditSystems() or {} end,
}

-- in pairs (half rows): the button's state, its art, its text, the spells, paging
S:Row{
    key = "ab.statusColours", section = "ab.buttonAppearance", apply = Refresh, half = true,
    get = function() return S:GetPath("actionbars.colors.enableRange") end,
    set = function(on)
        S:SetPath("actionbars.colors.enableRange", on)
        S:SetPath("actionbars.colors.unusable.desaturate", on)
    end,
}
S:Row{ key = "ab.dimOnCooldown", section = "ab.buttonAppearance", path = "actionbars.dimOnCooldown", apply = Refresh, half = true }
S:Row{ key = "ab.procGlow", section = "ab.buttonAppearance", path = "actionbars.procGlow", half = true,
    apply = function() if ns.ProcGlow then ns.ProcGlow:Refresh() end end }
S:Row{ key = "ab.buttonArt", section = "ab.buttonAppearance", path = "actionbars.buttonArt", apply = Refresh, half = true }
S:Row{ key = "ab.hideKeybinds", section = "ab.buttonText", path = "actionbars.hideHotkeys", apply = Refresh, half = true }
S:Row{ key = "ab.cleanKeybinds", section = "ab.buttonText", path = "actionbars.cleanKeybinds", apply = Refresh, half = true }
S:Row{ key = "ab.hideMacroText", section = "ab.buttonText", path = "actionbars.hideMacroText", apply = Refresh, half = true }
S:Row{ key = "ab.gryphonsBehind", section = "ab.buttonAppearance", path = "actionbars.gryphonsBehind", apply = Refresh, half = true }
S:Row{ key = "ab.autoRanks", section = "ab.spellBehavior", path = "actionbars.autoRanks", half = true,
    apply = function() if ns.ActionBars.CatchUpRanks then ns.ActionBars:CatchUpRanks() end end }
S:Row{ key = "ab.stopAutoAdd", section = "ab.spellBehavior", path = "actionbars.stopAutoAddSpells", apply = Refresh, half = true }
S:Row{ key = "ab.stealthPaging", section = "ab.spellBehavior", path = "actionbars.stealthPaging", apply = Refresh, half = true }
S:Row{ key = "ab.noStancePaging", section = "ab.spellBehavior", path = "actionbars.noStancePaging", apply = Refresh, half = true }
-- last in Tweaks: Blizzard's Cooldown Manager restyled (Auras.lua 9b, so it needs Buffs & Debuffs on);
-- off needs a reload to give Blizzard's look back
S:Row{ key = "ab.skinCDM", section = "ab.buttonAppearance", path = "auras.skinCDM", reload = true,
    disabled = function() return not S:GetPath("auras.enabled") end }

-- the FlareUI XP Bar: off leaves Blizzard's bars alone, so turning it on or off reloads; its options sit
-- under it and grey out while it's off

S:Row{ key = "ab.xpBar", path = "actionbars.xpbar.enabled", reload = true }
S:Row{ key = "ab.xpText", kind = "choice", path = "actionbars.xpbar.textMode", choices = { "HOVER", "ALWAYS" }, parent = "ab.xpBar",
    apply = function() if ns.XPBar and ns.XPBar.Refresh then ns.XPBar:Refresh() end end }
S:Row{ key = "ab.xpNumbers", kind = "choice", path = "actionbars.xpbar.textFormat", choices = { "VALUES", "PERCENT", "BOTH", "REMAINING" }, parent = "ab.xpBar",
    apply = function() if ns.XPBar and ns.XPBar.Refresh then ns.XPBar:Refresh() end end }
-- one choice for both settings: Off clears questXP, the rest set it and pick the quests counted
S:Row{ key = "ab.xpQuest", kind = "choice", choices = { "off", "done", "all", "zone" }, parent = "ab.xpBar",
    get = function()
        if not S:GetPath("actionbars.xpbar.questXP") then return "off" end
        return S:GetPath("actionbars.xpbar.questXPMode") or "done"
    end,
    set = function(v)
        S:SetPath("actionbars.xpbar.questXP", v ~= "off")
        if v ~= "off" then S:SetPath("actionbars.xpbar.questXPMode", v) end
    end,
    apply = function() if ns.XPBar and ns.XPBar.Refresh then ns.XPBar:Refresh() end end }

-- Hide Blizzard elements (also removed from Edit Mode)
local function Hide(key, path)
    S:Row{ key = "ab." .. key, path = "visibility." .. path, apply = Refresh, tab = "visibility", section = "ab.hideBlizzardElements", half = true }
end
Hide("hideMicroMenu", "hideMicroMenu")
Hide("hideBagBar", "hideBagBar")
Hide("hidePetBar", "hidePetBar")
Hide("hideStanceBar", "hideStanceBar")
Hide("hideTotemBar", "hideTotemBar")
Hide("hidePossessBar", "hidePossessBar")
Hide("hideGryphons", "hideEndCaps")
Hide("hideRaidManager", "hideRaidManager")

-- Fake Cooldown Manager tab: no switch, it is on while any bar is picked
for i = 1, 8 do
    S:Row{ key = "ab.fcmBar" .. i, tab = "fcm", path = "fcm.bars.bar" .. i .. ".enabled", apply = Refresh,
        section = "ab.fakeCooldownManager", half = true }
end
S:Row{
    -- toggles as on the bars (ns.Conditions), with no Mouseover: nothing ticked is Always
    key = "ab.fcmShow", kind = "dropdown", tab = "fcm", path = "fcm.show", section = "ab.fakeCooldownManager",
    choices = { "always", { divider = true }, "combat", "hastarget", "attackable", "ingroup", "unmounted" }, apply = Refresh,
    toggles = { exclusive = { "always" }, tokens = ns.Conditions.BAR_TOKENS, legacy = ns.Conditions.BAR_LEGACY, empty = "always" },
    -- under the bar switches (pick the bars, then when they show, then set them up), a line's space
    -- from the switches and from the button below
    rank = 3.5, gapAbove = 12,
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
