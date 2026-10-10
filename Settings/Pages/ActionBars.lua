local _, ns = ...
local L = ns.L
local S = ns.Settings

--------------------------------------------------
-- ACTION BARS (Modules/ActionBars.lua, Visibility.lua, XPBar.lua). Fixed, no option: clean keybind
-- text, gryphons above the text, button art, no spells added to the bars, one button scale (1.06),
-- the status colours themselves; the XP bar's text on mouseover and no tooltip. When each bar
-- shows and its fade group are set per bar in Edit Mode.
--------------------------------------------------
local function Refresh()
    if ns.ActionBars and ns.ActionBars.Refresh then ns.ActionBars:Refresh() end
    if ns.Visibility and ns.Visibility.Refresh then ns.Visibility:Refresh() end
end

local function FCMOff() return not S:GetPath("fcm.enabled") end

S:Module{
    key = "ab", group = "HUD", order = 10, enabled = "actionbars.enabled",
    -- Blizzard's bars: the button opens Edit Mode itself (no FlareUI frame to select)
    editMode = function() return nil end,
}

-- Buttons
S:Row{
    key = "ab.statusColours", apply = Refresh,
    get = function() return S:GetPath("actionbars.colors.enableRange") end,
    set = function(on)
        S:SetPath("actionbars.colors.enableRange", on)
        S:SetPath("actionbars.colors.unusable.desaturate", on)
    end,
}
S:Row{ key = "ab.procGlow", path = "actionbars.procGlow",
    apply = function() if ns.ProcGlow then ns.ProcGlow:Refresh() end end }
S:Row{ key = "ab.hideMacroText", path = "actionbars.hideMacroText", apply = Refresh }
S:Row{ key = "ab.hideKeybinds", path = "actionbars.hideHotkeys", apply = Refresh }


-- Experience
S:Row{ key = "ab.xpBar", path = "actionbars.xpbar.enabled", reload = true }

-- Hiding (also gone from Edit Mode)
S:Row{
    key = "ab.hideBlizzardElements", kind = "chips", apply = Refresh,
    items = {
        { path = "visibility.hideMicroMenu" }, { path = "visibility.hideBagBar" },
        { path = "visibility.hidePetBar" }, { path = "visibility.hideStanceBar" },
        { path = "visibility.hideTotemBar" }, { path = "visibility.hidePossessBar" },
        { path = "visibility.hideEndCaps" }, { path = "visibility.hideRaidManager" },
    },
}

-- Fade Options: set per bar in Edit Mode; the row opens it
S:Row{ key = "ab.fade", kind = "editmode", section = "ab.fadeOptions", sectionTitle = L["Fade Options"] }

-- Fake Cooldown Manager: its options show once it is on
S:Row{ key = "ab.fcmEnable", path = "fcm.enabled", apply = Refresh, section = "ab.fakeCooldownManager" }
local fcmBars = {}
for i = 1, 8 do fcmBars[i] = { path = "fcm.bars.bar" .. i .. ".enabled", text = L["Action Bar %d"]:format(i) } end
S:Row{ key = "ab.fcmBars", kind = "chips", items = fcmBars, apply = Refresh, hidden = FCMOff, section = "ab.fakeCooldownManager" }
S:Row{
    key = "ab.fcmShow", kind = "choice", path = "fcm.show", hidden = FCMOff, section = "ab.fakeCooldownManager",
    choices = { "combat", "target", "harm", "always" }, apply = Refresh,
}
S:Row{
    key = "ab.fcmSetup", kind = "button", center = true, hidden = FCMOff, section = "ab.fakeCooldownManager",
    apply = function() if ns.ToggleFCMSetupMode then ns.ToggleFCMSetupMode() end end,
}
