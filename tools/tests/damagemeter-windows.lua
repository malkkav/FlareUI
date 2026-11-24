local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local noop = function() end
local db = {
    enabled = true, combatTimer = true, threatTankLead = true, threatPullFlash = true, threatPullLine = true,
    threatValueDisplay = "both", resetOnInstance = true, resetOnGroupLeave = true,
    barTexture = "Custom", barFont = { size = 13 }, headerFont = { size = 14, flags = "NONE" },
}
local saved, resetCount = {}, 0
local visibility = { wanted = true }
local function applyFont(frame, ...) frame:SetFont(...) end
local ns = {
    Dialogs = {}, ShowDialog = function() end,   -- (the Blizzard Visibility warning, 11-22)
    modules = {}, L = setmetatable({}, { __index = function(_, key) return key end }),
    db = { profile = { damagemeter = db } }, ShortNumber = tostring, THREAT_MAX = 999,
    BORDER_COLOR = { r = 0.6, g = 0.5, b = 0.4, a = 1 },
    BorderEdgeSize = function(_, size) return size end,
    BronzeIcon = {
        Apply = function(texture, file) texture:SetTexture(file) end,
        Paint = function(texture, _, hover) texture.highlighted = hover end,
    },
    UnitFrames = { Kit = { GetBarTexture = function(name) return "Bars/" .. name end } },
    SetFont = applyFont, SetFontFamily = applyFont,
    GetWantedFont = function(frame) return frame:GetFont() end,
    GetFontPath = function(face) return "Fonts/" .. face end,
    CyrillicTwin = function(face) return "Cyrillic/" .. face end,
    CopyStrata = function(frame, other) frame:SetFrameStrata(other:GetFrameStrata()) end,
    ApplyShadow = noop, FadeTime = function(speed) return speed == "fast" and 0.2 or 0 end,
    CharDB = function() return saved end,
    Visibility = visibility,
    IsGamepadUI = function() return false end,
}
function visibility:ElementShown() return self.wanted end
function visibility:HasToken(_, token) return token == "mouseover" and self.mouseover end
function visibility:GetMinAlpha() return self.min or 0 end
function visibility:GetFadeDelay() return self.delay or 0 end
function visibility:GetFadeIn() return "fast" end
function visibility:GetFadeOut() return "fast" end
local media = { IsValid = function() return true end, Fetch = function(_, kind, name) return kind .. "/" .. name end }
local edit = { callbacks = {}, SettingType = { Slider = 1 } }
function edit:RegisterCallback(event, callback) self.callbacks[event] = callback end
function edit:AddFrame(frame, moved) frame.testMoved = moved end
function edit:AddFrameSettings(frame, settings) frame.testSettings = settings end
function edit:GetActiveLayoutName() return "Modern" end
function env.LibStub(name)
    if name == "LibSharedMedia-3.0" then return media end
    if name == "AceEvent-3.0" then return { Embed = noop } end
    if name == "FlareEditMode" then return edit end
    error("unexpected library " .. name)
end
ns.EditSections = function()
    local rows = {}
    return function(_, settings) for _, setting in ipairs(settings) do rows[#rows + 1] = setting end end, rows
end
ns.LayoutHome = function(layouts, name) layouts[name] = layouts[name] or {}; return layouts[name] end
env.canaccessvalue = function() return true end
env.canaccessallvalues = function() return true end
env.C_CVar = { GetCVarBool = function() return ui.enabled ~= false end }
env.C_AddOns.IsAddOnLoaded = function() return false end
env.C_DamageMeter = {
    IsDamageMeterAvailable = function() return true end,
    GetSessionDurationSeconds = function() return 50 end,
    ResetAllCombatSessions = function() resetCount = resetCount + 1 end,
}
env.Enum = {
    DamageMeterStyle = { Default = 1 },
    DamageMeterSessionType = { Current = 1, Overall = 2 },
    DamageMeterNumbers = { Minimal = 1, Compact = 2, Complete = 3 },
}
env.C_Timer.NewTimer = env.C_Timer.NewTicker
env.EventRegistry = env.CreateFrame("Frame")
env.EditModeManagerFrame = env.CreateFrame("Frame", nil, env.UIParent)
env.EditModeManagerFrame:Hide()
env.UnitAffectingCombat = function() return ui.combat == true end
env.UnitName = function() return "Juniper" end
env.UnitClass = function() return "Mage", "MAGE" end
env.UnitExists = function() return false end
env.IsInGroup = function() return false end
env.IsInRaid = env.IsInGroup
env.IsInInstance = function() return ui.instance ~= nil, "party" end
env.GetInstanceInfo = function() return nil, nil, nil, nil, nil, nil, nil, ui.instance end
env.time = function() return ui.epoch or 1000 end
env.GetNumSubgroupMembers = function() return 0 end
env.GetNumGroupMembers = env.GetNumSubgroupMembers
env.RAID_CLASS_COLORS = { MAGE = { r = 0.3, g = 0.7, b = 1 } }
env.GetClassAtlas = function(class) return "Class/" .. class end
env.AbbreviateLargeNumbers = tostring
env.Round = function(value) return math.floor(value + 0.5) end
env.SecondsToClock = function(value) return ("%d:%02d"):format(math.floor(value / 60), value % 60) end
env.Mixin = function(frame, mixin) for key, method in pairs(mixin) do frame[key] = method end; return frame end
env.tIndexOf = function(values, want)
    for i, value in ipairs(values) do if value == want then return i end end
end
env.tContains = function(values, want) return env.tIndexOf(values, want) ~= nil end
local menus, menuHooks = {}, {}
local function menu()
    local root = { entries = {} }
    function root:CreateButton(label, action)
        local button = { label = label, action = action }
        function button:SetEnabled(enabled) self.disabled = not enabled end
        function button:SetTooltip(callback) self.tooltip = callback end
        self.entries[label] = button
        return button
    end
    function root:CreateDivider() end
    function root:EnumerateElementDescriptions() return pairs(self.entries) end
    return root
end
env.MenuUtil = {
    CreateContextMenu = function(owner, build)
        local root = menu()
        menus[owner] = root
        build(owner, root)
    end,
    GetElementText = function(desc) return desc.label end,
}
env.Menu = { ModifyMenu = function(name, build) menuHooks[name] = build end }
env.DAMAGE_METER_SHOW_NEW_WINDOW = "Show New Window"

local Widget = getmetatable(env.UIParent)
local setTexture = Widget.SetStatusBarTexture
function Widget:SetStatusBarTexture(value)
    if type(value) == "table" then self.barTexture = value else setTexture(self, value) end
end
function Widget:SetVertexColor(...) self.color = { ... } end
function Widget:SetLooping(value) self.looping = value end
function Widget:SetSmoothing(value) self.smoothing = value end
function Widget:GetShadowOffset() return 1, -1 end
function Widget:GetShadowColor() return 0, 0, 0, 1 end
function Widget:SetPassThroughButtons(button) self.passThrough = button end
function Widget:RegisterForMouse(...) self.mouseButtons = { ... } end
function Widget:GetRect() return self:GetLeft(), self:GetBottom(), self:GetSize() end

local function field(parent, key, kind)
    local frame = env.CreateFrame(kind or "Frame", nil, parent)
    parent[key] = frame
    return frame
end
local meter = env.CreateFrame("Frame", "DamageMeter", env.UIParent)
function meter:UpdateShownState() self:SetShown(ui.nativeShow ~= false) end
function meter:ShouldBeShown() return ui.nativeShow ~= false end
function meter:ForEachSessionWindow(callback)
    callback(env.DamageMeterSessionWindow1)
    if env.DamageMeterSessionWindow2 then callback(env.DamageMeterSessionWindow2) end
end
function meter:HideSessionWindow(frame) frame:Hide() end
function meter:OnWindowAlphaChanged(alpha)
    self.windowAlpha = alpha
    self:ForEachSessionWindow(function(frame) frame:SetAlpha(alpha) end)
end
function meter:GetWindowAlpha() return self.windowAlpha or 1 end
function meter:SetupSessionWindow(_, data) data.sessionWindow:Show() end
function meter:ShowNewSecondarySessionWindow() self:SetupSessionWindow(nil, { sessionWindow = env.DamageMeterSessionWindow2 }) end
local function sessionWindow(index, name)
    local window = env.CreateFrame("Frame", "DamageMeterSessionWindow" .. index, meter)
    window:SetSize(320, 190)
    window.left, window.bottom = 40, 60
    field(window, "Background")
    field(window, "Header")
    field(window, "ScrollBar")
    field(window.ScrollBar, "Thumb")
    field(window, "ScrollBox")
    local title = field(window, "DamageMeterTypeDropdown", "Button")
    title.TypeName = title:CreateFontString()
    title.TypeName:SetText(name)
    field(window, "SettingsDropdown", "Button")
    local segments = field(window, "SessionDropdown", "Button")
    segments.SessionName = segments:CreateFontString()
    window.SessionTimer = window:CreateFontString()
    window.SessionTimer:SetText("[0:12]")
    field(window, "MinimizeButton", "Button")
    field(window, "ResizeButton", "Button")
    function window:IsMinimized() return ui.minimized end
    function window:GetBarHeight() return ui.barHeight or 25 end
    function window:GetBarSpacing() return 4 end
    function window:GetTextScale() return 1 end
    function window:ShouldShowBarIcons() return true end
    function window:ShouldUseClassColor() return true end
    function window:GetNumberDisplayType() return ui.numberType or env.Enum.DamageMeterNumbers.Compact end
    function window:GetSessionType() return env.Enum.DamageMeterSessionType.Current end
    function window:GetResizeButton() return self.ResizeButton end
    return window
end
local window = sessionWindow(1, "Healing Done")
local scroll, title = window.ScrollBox, window.DamageMeterTypeDropdown

ui:load("Modules/DamageMeter.lua", ns)
local meterUI = ns.DamageMeter
function meterUI:RegisterEvent(event) self.loggedEvents = self.loggedEvents or {}; self.loggedEvents[event] = true end
local row = meterUI.NewSampleRow(scroll)
window.LocalPlayerEntry = row
function scroll:ForEachFrame(callback) callback(row) end
meterUI:Init()
assert(window.FlareUI_DMSkin and window.Header:GetAlpha() == 0 and window.Background:GetAlpha() == 0)
assert(not window.ScrollBar:IsMouseEnabled() and window.ScrollBar.Thumb:GetAlpha() == 0)
assert(select(2, scroll:GetPoint()) == window.FlareUI_DMSkin)
assert(window.SettingsDropdown.FlareUI_Icon:GetTexture():find("DMSettings", 1, true))
assert(not window.MinimizeButton:IsShown() and meterUI.loggedEvents.GROUP_LEFT)
-- (11-23, #163) only a name with Russian letters takes the Cyrillic twin; the row is reused, so a
-- new name picks again
row:GetName():SetText("1. Tester")
assert(not row:GetName():GetFont():find("Cyrillic/", 1, true) and row:GetStatusBar():GetStatusBarTexture():GetTexture() == "Bars/Custom")
row:GetName():SetText("2. Имя")
assert(row:GetName():GetFont():find("Cyrillic/", 1, true), "a Russian name takes the twin")
row:GetName():SetText("3. Aeloria")
assert(not row:GetName():GetFont():find("Cyrillic/", 1, true), "a Latin name goes back")
title.TypeName:SetText("Damage Done to Enemy")
assert(title:GetWidth() >= #title.TypeName:GetText() * 6)
local settings = window.SettingsDropdown
settings:RunScript("OnEnter")
assert(settings.FlareUI_Icon.highlighted)
settings:RunScript("OnLeave")
assert(not settings.FlareUI_Icon.highlighted)

local sample = meterUI.CreateSample(env.UIParent, "damage")
local width, height = meterUI.DrawSample(sample, "damage")
assert(width == 300 and height == 180 and sample.Timer:IsShown())
assert(sample.DamageView.rows[1]:GetName():GetText():find("Pyroblastoise", 1, true))
local damageRow = sample.DamageView.rows[1]
assert(damageRow.Icon:IsShown() and damageRow:GetStatusBar():GetValue() == 1920000)
ui.numberType, ui.barHeight = env.Enum.DamageMeterNumbers.Complete, 55
meterUI.DrawSample(sample, "damage")
assert(damageRow:GetValue():GetText():find("%%") and not sample.DamageView.rows[3]:IsShown())
ui.numberType, ui.barHeight = env.Enum.DamageMeterNumbers.Minimal, 25
meterUI.DrawSample(sample, "damage")
assert(damageRow:GetValue():GetText() == "1920000")
meterUI.DrawSample(sample, "threat")
assert(sample.ThreatView.frame:IsShown() and not sample.DamageView.frame:IsShown())
assert(sample.ThreatView.rows[1]:GetValue():GetText():find("  104%", 1, true), "the tank's percent is its threat against second place")
db.threatTankLead = false
meterUI.DrawSample(sample, "threat")
assert(sample.ThreatView.rows[1]:GetValue():GetText():find("  100%", 1, true))
db.threatTankLead = true
meterUI.DrawSample(sample, "threat")
assert(sample.ThreatView.rows[2].FlareUI_Flash.anim:IsPlaying() and sample.ThreatView.pullLine:IsShown())

local function tick(dt)
    for _, widget in ipairs(ui.widgets) do
        if widget:IsShown() and widget:GetScript("OnUpdate") then widget:RunScript("OnUpdate", dt) end
    end
end
visibility.wanted, visibility.mouseover, visibility.min = false, true, 25
meterUI:ApplyVisibility()
tick(0.25)
assert(meter:IsShown() and meter:GetAlpha() == 0.25)
meter.mouseOver = true
tick(0.25)
assert(meter:GetAlpha() == 1)
env.WorldMapFrame = field(env.UIParent, "testMap")
tick(0.25)
assert(meter:GetAlpha() == 0.25)
env.WorldMapFrame:Hide()
meter.mouseOver = false
meterUI.HideUntilGroup()
assert(not meter:IsShown())
visibility.wanted = true
ui:emit("GROUP_JOINED")
tick(0.25)
assert(meter:IsShown() and meter:GetAlpha() == 1)

ui.combat = true
meterUI.SetThreatWindow(true)
assert(not env.FlareUI_ThreatMeter and meterUI.threatPlacePending)
ui.combat, ui.time = false, 101
meterUI:PLAYER_REGEN_ENABLED()
ui:flushTimers()
local solo = assert(env.FlareUI_ThreatMeter)
assert(solo:IsShown() and solo:GetWidth() == 320 and solo:GetPoint() == "BOTTOMLEFT")
meterUI.AttachThreatWindow(false)
assert(solo:GetParent():GetParent() == env.UIParent)
-- (11-24) on its own it is drawn whatever the meter's alpha, and held back only by its own
do
    local driver = assert(ui:find(function(f) return f:IsEventRegistered("UNIT_THREAT_LIST_UPDATE") and f:GetScript("OnUpdate") end))
    local function redraw()
        driver.stale = true
        driver:RunScript("OnUpdate", 1)
        for _, event in ipairs({ "PLAYER_TARGET_CHANGED" }) do driver:RunScript("OnEvent", event) end
        driver:RunScript("OnUpdate", 1)
        return not driver.stale
    end
    local alpha = meter:GetAlpha()
    meter:SetAlpha(0)
    assert(redraw(), "the meter faded out: still drawn")
    solo:SetAlpha(0)
    assert(not redraw(), "faded out itself: only marked")
    solo:SetAlpha(1)
    assert(redraw())
    meter:SetAlpha(alpha)
end
env.FlareUI_ToggleThreatMeter()
assert(not solo:IsShown())
env.FlareUI_ToggleThreatMeter()
assert(solo:IsShown())

-- A second window opens as the active tab. Its native title retains right-click,
-- while moving it out keeps its own saved position and size on subsequent refreshes.
ui.time = 102
meterUI.SetThreatWindow(false)
local second = sessionWindow(2, "Damage Taken")
second:Hide()
meter:ShowNewSecondarySessionWindow()
ui.time = 103
ui:flushTimers()
assert(second.FlareUI_Docked and second:GetAlpha() == 1 and window:GetAlpha() == 0)
assert(not second.ResizeButton:IsShown() and second:IsMouseEnabled() and not window:IsMouseEnabled())
local firstTab = second.FlareUI_DockLabels[window]
firstTab:Click()
assert(window:GetAlpha() == 1 and second:GetAlpha() == 0)
local secondTab = window.FlareUI_DockLabels[second]
assert(secondTab.Text:GetText() == "Damage Taken")
secondTab:RunScript("OnEnter")
secondTab:RunScript("OnLeave")
meter:OnWindowAlphaChanged(0.8)
assert(window:GetAlpha() == 0.8 and second:GetAlpha() == 0)
local gearMenu = menu()
local newWindow = gearMenu:CreateButton("Show New Window")
menuHooks.MENU_DAMAGE_METER_WINDOW_SETTINGS(second.SettingsDropdown, gearMenu)
assert(newWindow.disabled and newWindow.tooltip, "the gear menu enforces the window limit")
ns.IsGamepadUI = function() return true end
secondTab:Click("RightButton")
assert(not menus[secondTab], "no addon menu in the Gamepad UI: it breaks the pad's focus")
ns.IsGamepadUI = function() return false end
ui.combat = true
secondTab:Click("RightButton")
local moveOut = menus[secondTab].entries["Move to Own Window"]
assert(moveOut.tooltip)
moveOut.action()
assert(second.FlareUI_Docked and db.freeWindows[2])
ui.combat, ui.time = false, 104
meterUI:PLAYER_REGEN_ENABLED()
ui:flushTimers()
assert(not second.FlareUI_Docked and second.ResizeButton:IsShown() and second:GetPoint() == "TOPLEFT")
assert(db.freeWindows[2].x == 40 and db.freeWindows[2].w == 320)
second.left, second.top = 550.7, 302.1
second:SetSize(290.6, 189.4)
second:RunScript("OnDragStop")
assert(db.freeWindows[2].x == 551 and db.freeWindows[2].y == 302 and db.freeWindows[2].w == 291)
local typeMenu = menu()
menuHooks.MENU_DAMAGE_METER_WINDOW_TRACKED_TYPE(second.DamageMeterTypeDropdown, typeMenu)
typeMenu.entries["Dock as a Tab"].action()
assert(second.FlareUI_Docked and second:GetAlpha() == 0.8 and not db.freeWindows)
meter:HideSessionWindow(second)
assert(not second:IsShown() and not second.FlareUI_Docked and window:IsMouseEnabled())

ui.instance = 5
meterUI:CheckInstanceReset(false)
assert(saved.meterInstance == 5 and resetCount == 1)
meterUI:PLAYER_LEAVING_WORLD()
meterUI:CheckInstanceReset(false)
assert(resetCount == 1, "a short return to the same instance keeps the meter")
meterUI:PLAYER_LEAVING_WORLD()
ui.epoch = 1601
meterUI:CheckInstanceReset(false)
assert(resetCount == 2)
ui.instance = 6
meterUI:CheckInstanceReset(true)
assert(saved.meterInstance == 6 and resetCount == 2, "a reload keeps the meter")
meterUI:GROUP_LEFT()
assert(resetCount == 3)
print("PASS: damage meter windows, preview bars, fades, separate threat and instance resets")
