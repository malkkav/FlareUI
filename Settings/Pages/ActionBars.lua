local _, ns = ...
local L = ns.L
local S = ns.Settings

--------------------------------------------------
-- ACTION BARS (Modules/ActionBars.lua, Visibility.lua, XPBar.lua). Fixed, no option: gryphons above
-- the buttons, one button scale (1.06), the status colours themselves, no XP bar tooltip. When each
-- bar shows and its fade group are set per bar in Edit Mode.
--------------------------------------------------
local function Refresh()
    if ns.ActionBars and ns.ActionBars.Refresh then ns.ActionBars:Refresh() end
    if ns.Visibility and ns.Visibility.Refresh then ns.Visibility:Refresh() end
end

S:Module{
    key = "ab", group = "HUD", order = 10, enabled = "actionbars.enabled",
    tabs = { { key = "settings" }, { key = "fcm" }, { key = "fonts" } },
    -- Blizzard's bars: the button opens Edit Mode itself (no FlareUI frame to select)
    editMode = function() return nil end,
}

-- Buttons, two to a line
S:Row{
    key = "ab.statusColours", apply = Refresh, half = true,
    get = function() return S:GetPath("actionbars.colors.enableRange") end,
    set = function(on)
        S:SetPath("actionbars.colors.enableRange", on)
        S:SetPath("actionbars.colors.unusable.desaturate", on)
    end,
}
S:Row{ key = "ab.procGlow", path = "actionbars.procGlow", half = true,
    apply = function() if ns.ProcGlow then ns.ProcGlow:Refresh() end end }
S:Row{ key = "ab.hideMacroText", path = "actionbars.hideMacroText", apply = Refresh, half = true }
S:Row{ key = "ab.hideKeybinds", path = "actionbars.hideHotkeys", apply = Refresh, half = true }
S:Row{ key = "ab.autoRanks", path = "actionbars.autoRanks", half = true }
S:Row{ key = "ab.cleanKeybinds", path = "actionbars.cleanKeybinds", apply = Refresh, half = true }
S:Row{ key = "ab.buttonArt", path = "actionbars.buttonArt", apply = Refresh, half = true }
S:Row{ key = "ab.stopAutoAdd", path = "actionbars.stopAutoAddSpells", apply = Refresh, half = true }

-- Auto-paging, last in Tweaks: the bar that switches to the Stealth / form page (Forever's bar 1 doesn't by itself)
S:Row{ key = "ab.autoPagingBar", kind = "choice", path = "actionbars.autoPagingBar",
    choices = { 0, 1, 2, 3, 4, 5, 6, 7, 8 }, apply = Refresh }

-- XP Bar
S:Row{ key = "ab.xpBar", path = "actionbars.xpbar.enabled", reload = true }
-- its numbers: under the mouse, or always
S:Row{ key = "ab.xpText", kind = "choice", path = "actionbars.xpbar.textMode", choices = { "HOVER", "ALWAYS" },
    parent = "ab.xpBar", apply = function() if ns.XPBar and ns.XPBar.Refresh then ns.XPBar:Refresh() end end }

-- Hide Bars (also gone from Edit Mode), two to a line
local function Hide(key, path)
    S:Row{ key = "ab." .. key, path = "visibility." .. path, apply = Refresh, section = "ab.hideBlizzardElements", half = true }
end
Hide("hideMicroMenu", "hideMicroMenu")
Hide("hideBagBar", "hideBagBar")
Hide("hidePetBar", "hidePetBar")
Hide("hideStanceBar", "hideStanceBar")
Hide("hideTotemBar", "hideTotemBar")
Hide("hidePossessBar", "hidePossessBar")
Hide("hideGryphons", "hideEndCaps")
Hide("hideRaidManager", "hideRaidManager")

-- Fade Options: set per bar in Edit Mode; the row opens it
S:Row{ key = "ab.fade", kind = "editmode", section = "ab.fadeOptions", sectionTitle = L["Fade Options"] }
-- how fast the bars fade in and out (Modules/Visibility.lua)
S:Row{ key = "ab.fadeSpeed", kind = "choice", path = "visibility.fadeSpeed", choices = { "instant", "fast", "slow" },
    section = "ab.fadeOptions", apply = function() if ns.Visibility and ns.Visibility.Refresh then ns.Visibility:Refresh() end end }

-- FakeCM tab: no switch, it is on while a bar is picked (ns.FCMActive)
-- the bars it takes over, two to a line
for i = 1, 8 do
    S:Row{ key = "ab.fcmBar" .. i, tab = "fcm", path = "fcm.bars.bar" .. i .. ".enabled", apply = Refresh,
        section = "ab.fakeCooldownManager", half = true }
end
S:Row{
    key = "ab.fcmShow", kind = "choice", tab = "fcm", path = "fcm.show", section = "ab.fakeCooldownManager",
    choices = { "combat", "target", "harm", "always" }, apply = Refresh,
}
S:Row{
    key = "ab.fcmSetup", kind = "button", tab = "fcm", center = true, section = "ab.fakeCooldownManager",
    apply = function() if ns.ToggleFCMSetupMode then ns.ToggleFCMSetupMode() end end,
}

S:FontRows{ module = "ab", tab = "fonts", section = "ab.fonts", apply = Refresh, fonts = {
    { key = "keybinds", path = "actionbars.hotkeyFont" },
    { key = "count", path = "actionbars.countFont" },
    { key = "macro", path = "actionbars.macroFont" },
} }
