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
    -- (XP Bar and Hide Bars in one Other Bars tab, "xp")
    tabs = { { key = "settings" }, { key = "xp" }, { key = "fcm" }, { key = "fonts" } },
    -- Blizzard's bars: no FlareUI frame to select, so plain Edit Mode
    editMode = function() return nil end,
    -- the XP bar is FlareUI's own frame; each bar's fade settings sit in Blizzard's bar dialogs
    editFrames = { function() return _G.FlareUI_XPBar end },
    editSystems = function() return ns.Visibility and ns.Visibility.EditSystems and ns.Visibility:EditSystems() or {} end,
}

-- BAR APPEARANCE: the bars as a whole, above the buttons' own look
S:Row{ key = "ab.flareBorders", section = "ab.barAppearance", path = "actionbars.flareBorders", apply = Refresh, half = true }
-- every button's scale
local SCALES = {}
-- in half-percent steps; kept as tenths of a percent so no float drifts
for tenths = 700, 1500, 5 do
    local percent = tenths / 10
    SCALES[#SCALES + 1] = { tenths / 1000, (percent % 1 == 0 and ("%d"):format(percent) or ("%.1f"):format(percent)) .. "%" }
end
S:Row{ key = "ab.buttonScale", kind = "range", section = "ab.barAppearance", choices = SCALES, apply = Refresh,
    get = function()
        local v = tonumber(S:GetPath("actionbars.buttonScale")) or 1.11
        return math.floor(v * 200 + 0.5) * 5 / 1000
    end,
    set = function(v) S:SetPath("actionbars.buttonScale", v) end }

-- the micro menu and the bag bar
S:Row{ key = "ab.borderlessMenu", section = "ab.barAppearance", path = "actionbars.borderlessMenu", apply = Refresh, half = true }
-- (a folded bar needs the frame gone anyway)
S:Row{ key = "ab.collapsibleBags", section = "ab.barAppearance", path = "actionbars.collapsibleBags", apply = Refresh, half = true }

-- in pairs (half rows): Show Button Art | Proc Glow, Status Colouring | Active Highlight
-- (Dim on Cooldown is part of Status Colouring); then the text (Show Keybind Text | Show
-- Macro Text), the spells, paging
S:Row{ key = "ab.buttonArt", section = "ab.buttonAppearance", path = "actionbars.buttonArt", apply = Refresh, half = true }
-- Equipped Item Border: beside Show Button Art
S:Row{ key = "ab.equippedBorder", section = "ab.buttonAppearance", path = "actionbars.equippedBorder", apply = Refresh, half = true }
S:Row{ key = "ab.procGlow", section = "ab.buttonAppearance", path = "actionbars.procGlow", half = true,
    apply = function() if ns.ProcGlow then ns.ProcGlow:Refresh() end end }
-- (Pick Your Colours' Disabled palette turns Status Colouring off)
S:Row{ key = "ab.activeHighlight", section = "ab.buttonAppearance", path = "actionbars.activeHighlight", apply = Refresh, half = true }
-- Show Keybind Text / Show Macro Text: on by default, saved inverted as the hide values
S:Row{ key = "ab.hideKeybinds", section = "ab.buttonAppearance",
    path = "actionbars.hideHotkeys", invert = true, apply = Refresh, half = true }
S:Row{ key = "ab.hideMacroText", section = "ab.buttonAppearance", path = "actionbars.hideMacroText", invert = true, apply = Refresh, half = true }
-- Status Colouring's colours and their strength, in the colour window
S:Row{ key = "ab.statusPick", section = "ab.buttonAppearance", kind = "button", lead = true, buttonText = L["Pick Your Colours"],
    apply = function() if ns.ColorPicker then ns.ColorPicker.Open("ab") end end }
S:Row{ key = "ab.autoRanks", section = "ab.spellBehavior", path = "actionbars.autoRanks", half = true,
    apply = function() if ns.ActionBars.CatchUpRanks then ns.ActionBars:CatchUpRanks() end end }
S:Row{ key = "ab.stopAutoAdd", section = "ab.spellBehavior", path = "actionbars.stopAutoAddSpells", apply = Refresh, half = true }
S:Row{ key = "ab.keepStealthPage", section = "ab.spellBehavior", path = "actionbars.keepStealthPage", apply = Refresh, half = true }
S:Row{ key = "ab.noStancePaging", section = "ab.spellBehavior", path = "actionbars.noStancePaging", apply = Refresh, half = true }

-- the FlareUI XP Bar. One Style choice over the saved switch: Off (Blizzard's bars,
-- saved as enabled = false), Single, Split (the default) or Double (XPBar.lua XPB.Style).
-- Off leaves Blizzard's bars alone, so going to or from Off asks for a reload; the other three change
-- at once. The rows below grey out while it's Off (no indent).
local function XPRefresh() if ns.XPBar and ns.XPBar.Refresh then ns.XPBar:Refresh() end end
local function XPOff() return S:GetPath("actionbars.xpbar.enabled") == false end
local xpStartOff   -- Off at the session's start (the first change records it), for the reload footer
S:Row{ key = "ab.xpBar", tab = "xp", kind = "choice", lead = true, choices = { "off", "single", "split", "double" }, noReset = true,
    get = function()
        if XPOff() then return "off" end
        local v = S:GetPath("actionbars.xpbar.style")
        return (v == "single" or v == "double") and v or "split"
    end,
    set = function(v)
        if xpStartOff == nil then xpStartOff = XPOff() end
        S:SetPath("actionbars.xpbar.enabled", v ~= "off")
        if v ~= "off" then S:SetPath("actionbars.xpbar.style", v) end
    end,
    apply = function(v)
        S:TrackReload("ab.xpBar", v == "off", xpStartOff)
        if v ~= "off" then XPRefresh() end
    end }
-- Order (11-20, Malkkav): Bar Style, Bar Texture, Border, Separators, then the text rows
-- Bar Texture and Border (11-20, from its Edit Mode dialog): the bar's fill and its frame
S:Row{ key = "ab.xpTexture", tab = "xp", kind = "choice", path = "actionbars.xpbar.texture", disabled = XPOff,
    choices = function() return ns.XPBar and ns.XPBar.LookChoices and ns.XPBar.LookChoices("texture") or {} end,
    resetValue = function() return ns.XPBar and ns.XPBar.DEFAULT_TEXTURE end,
    apply = function() if ns.XPBar and ns.XPBar.Refresh then ns.XPBar:Refresh() end end }
S:Row{ key = "ab.xpBorder", tab = "xp", kind = "choice", path = "actionbars.xpbar.border", disabled = XPOff,
    choices = function() return ns.XPBar and ns.XPBar.LookChoices and ns.XPBar.LookChoices("border") or {} end,
    resetValue = function() return ns.XPBar and ns.XPBar.DEFAULT_BORDER end,
    apply = function() if ns.XPBar and ns.XPBar.Refresh then ns.XPBar:Refresh() end end }
-- Separators (saved as bubbles): Off, 10 or 20; the old switch saved true for 20, so true still reads as 20
S:Row{ key = "ab.xpBubbles", tab = "xp", kind = "choice", choices = { "off", "10", "20" }, disabled = XPOff,
    get = function()
        local v = S:GetPath("actionbars.xpbar.bubbles")
        if v == true or v == 20 then return "20" end
        if v == 10 then return "10" end
        return "off"
    end,
    set = function(v) S:SetPath("actionbars.xpbar.bubbles", tonumber(v) or false) end,
    apply = function() if ns.XPBar and ns.XPBar.Refresh then ns.XPBar:Refresh() end end }
-- every colour the XP bar paints, in the colour window
S:Row{ key = "ab.xpColors", tab = "xp", kind = "button", rank = 1,   -- (11-20: after Separators, with the other look rows; a button would sink to the end)
    buttonText = L["Pick Your Colours"], disabled = XPOff,
    apply = function() if ns.ColorPicker then ns.ColorPicker.Open("xp") end end }

-- XP Text: one dropdown, as the unit frames' Bar Text with one spot in the middle.
-- Show Always or Show On Mouseover (one of the two, ticking one unticks the other), then any of
-- Percent, Value, Max and Remaining, joined by " / ". It took over XP Text Visibility and the old
-- one-choice XP Text (XPBar.lua XPB.TextValue reads them until this is set).
S:Row{ key = "ab.xpText", tab = "xp", kind = "dropdown", disabled = XPOff,
    choices = { "always", "hover", { divider = true }, "percent", "value", "max", "remaining" },
    toggles = ns.XPBar and ns.XPBar.TEXT_SPEC,
    get = function() return ns.XPBar and ns.XPBar.TextValue() or "hover,value,max" end,
    set = function(v) if ns.XPBar then ns.XPBar.SetTextValue(v) end end,
    resetValue = function() return "hover,value,max" end,
    apply = XPRefresh }
-- one choice for both settings: Off clears questXP, the rest set it and pick the quests counted
S:Row{ key = "ab.xpQuest", tab = "xp", kind = "choice", choices = { "off", "all", "done", "zone" }, disabled = XPOff,
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
    S:Row{ key = "ab." .. key, path = "visibility." .. path, apply = Refresh, tab = "xp", section = "ab.hideBlizzardElements", half = true }
end
Hide("hideMicroMenu", "hideMicroMenu")
Hide("hideBagBar", "hideBagBar")
Hide("hidePetBar", "hidePetBar")
Hide("hideStanceBar", "hideStanceBar")
Hide("hideTotemBar", "hideTotemBar")
Hide("hidePossessBar", "hidePossessBar")

-- Fake Cooldown Manager tab: no switch, it is on while any bar is picked. First a note on what it is and
-- how to fill it, a section of its own above the bars
S:Row{ key = "ab.fcmNote", kind = "text", noTitle = true, tab = "fcm", section = "ab.fcmAbout" }
for i = 1, 8 do
    S:Row{ key = "ab.fcmBar" .. i, tab = "fcm", path = "fcm.bars.bar" .. i .. ".enabled", apply = Refresh,
        section = "ab.fakeCooldownManager", half = true }
end
S:Row{
    -- toggles as on the bars (ns.Conditions), Mouseover one of them: nothing ticked is Always
    key = "ab.fcmShow", kind = "dropdown", tab = "fcm", path = "fcm.show", section = "ab.fakeCooldownManager",
    choices = { "always", { divider = true }, "mouseover", "combat", "hastarget", "attackable", "ingroup", "unmounted" }, apply = Refresh,
    toggles = { exclusive = { "always" }, tokens = ns.Conditions.MOUSE_TOKENS, legacy = ns.Conditions.BAR_LEGACY, empty = "always" },
    -- above the bar switches: as a dropdown it leads, the bars and Setup Mode follow
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
-- the XP bar's numbers in a section of their own
S:FontRows{ module = "ab", tab = "fonts", section = "ab.fontsXp",
    apply = function() if ns.XPBar and ns.XPBar.Refresh then ns.XPBar:Refresh() end end, fonts = {
    { key = "xp", path = "actionbars.xpFont" },
} }
