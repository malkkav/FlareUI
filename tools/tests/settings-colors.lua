-- Pick Your Colours reproduces in-game color picker callbacks against a live preview.
local setup = dofile("tools/tests/fixtures/settings-addon.lua")
local ui, ns = setup()
local E = ui.env
local profile = ns.db.profile
profile.actionbars = { colors = { palette = "flareui", custom = {} }, xpbar = {} }
profile.unitframes = { resource = { palette = "flareui" } }
profile.cooldownmanager, profile.nameplates = {}, {}
local ab = profile.actionbars.colors
local function createSample(parent)
    local frame = E.CreateFrame("Frame", nil, parent)
    frame:SetSize(96, 30)
    return frame
end
local function color(db, key) return (db.customColors or {})[key] or { 0.25, 0.5, 1 } end
local function painted(frame, key) frame.painted = key end
local function drawSample(frame) frame:SetSize(120, 30) end
local changes = 0
ns.ActionBars = {
    StatusColor = function(key) return ab.custom[key] or { 0.25, 0.5, 1, 0.75 } end,
    StatusPalette = function() return ab.palette end,
    SetStatusPalette = function(palette, base) ab.palette, ab.customBase = palette, base end,
    RepaintStatus = function() changes = changes + 1 end,
    CreateSampleButton = function(parent)
        local frame = createSample(parent)
        frame.icon = frame:CreateTexture()
        return frame
    end,
    DrawSampleButton = function(frame, icon) frame.icon:SetTexture(icon); frame:SetSize(48, 48) end,
    PaintStatus = painted,
}
ns.XPBar = { Palette = function() return profile.actionbars.xpbar.palette or "flareui" end,
    Color = function(key) return color(profile.actionbars.xpbar, key) end,
    CreateSample = createSample, DrawSample = drawSample }
ns.CooldownManager = { Palette = function() return profile.cooldownmanager.palette or "flareui" end,
    Color = function(key) return color(profile.cooldownmanager, key) end,
    CreateSample = createSample, DrawSample = drawSample }
ns.Nameplates = { Palette = function() return profile.nameplates.palette or "flareui" end,
    Color = function(key) return color(profile.nameplates, key) end,
    CreateSample = createSample, DrawSample = painted }
ns.ResourceBars = { PaletteName = function() return profile.unitframes.resource.palette end,
    ApplyPalette = function() end, colors = {}, CreateSample = createSample, DrawSample = drawSample }
ns.UnitFrames = {
    CLASSES = { "MAGE", "DRUID" },
    HEAL_COLOR = { 0.1, 0.6, 0.2 }, ABSORB_COLOR = { 1, 1, 0 },
    Color = function(key) return color(profile.unitframes, key) end,
    ApplyPalette = function() changes = changes + 1 end,
    CreateSample = function(parent, kind)
        local frame = createSample(parent)
        frame.kindName = kind
        frame.Health = E.CreateFrame("StatusBar", nil, frame)
        frame.Health:SetSize(120, 16)
        frame.Health:SetStatusBarTexture("FlareUI Flat")
        frame.Power = E.CreateFrame("StatusBar", nil, frame)
        return frame
    end,
    DrawSample = function() return { left = 0, top = 0, width = 120, height = 30 } end,
}
local picker = E.CreateFrame("Frame", "ColorPickerFrame")
picker:Hide()
function picker:SetupColorPickerAndShow(info) self.info = info; self:Show() end
function picker:GetColorRGB() return 0.1, 0.2, 0.3 end
function picker:GetColorAlpha() return 0.5 end

ui:load("Settings/Panel.lua", ns)
ui:load("Settings/ColorPicker.lua", ns)
local open = ns.ColorPicker.Open
open("ab")
local window = assert(E.FlareUI_ColorPickerWindow)
local function colorRow(key)
    for _, row in ipairs(window.rows) do if row.key == key then return row end end
    error(key)
end
local function choosePalette(text)
    for _, choice in ipairs(window.palette:OpenMenu().entries) do if choice.text == text then choice.pick(); return end end
    error(text)
end
local range = colorRow("range")
assert(window:IsShown() and window.sub:GetText() == "Action Bars" and range.hex:GetText():find("75%", 1, true))
assert(ui:find(function(w) return w.painted == "range" and w:IsVisible() end), "the live preview paints the out-of-range sample")
choosePalette("Disabled")
assert(ab.palette == "disabled" and not window.reset:IsShown())
range:Click()
assert(picker.info.hasOpacity and picker.info.opacity == 0.75)
picker.info.swatchFunc()
assert(ab.palette == "custom" and ab.customBase == "flareui" and ab.custom.range[4] == 0.5 and range.own:IsShown(),
    "changing a color switches from Disabled to a custom palette with opacity")
assert(range.hex:GetText():find("50%", 1, true) and window.reset:IsShown())
picker.info.cancelFunc()
assert(ab.custom.range == nil and not range.own:IsShown(), "canceling the game color picker removes the candidate")
range:Click()
picker.info.opacityFunc()
window:Hide()
assert(not picker:IsShown(), "closing FlareUI also closes the game picker")
ui:flushTimers()
assert(window:IsShown() and ui.dialogs[#ui.dialogs].key == "FLAREUI_COLORS_UNSAVED")
ns.Dialogs.FLAREUI_COLORS_UNSAVED.OnCancel()
assert(not window:IsShown() and ab.palette == "flareui" and ab.custom.range == nil,
    "Discard restores the palette and color overrides from before opening")

open("ab")
range = colorRow("range")
range:Click()
picker.info.swatchFunc()
window.apply:Click()
assert(not window:IsShown() and ab.custom.range[4] == 0.5, "Apply retains the override")
open("ab")
range = colorRow("range")
range:Click("RightButton")
assert(not range.own:IsShown() and ab.custom.range == nil)
open("uf")
assert(window.sub:GetText() == "Action Bars" and window:IsShown(), "a dirty window must be resolved before changing categories")
ns.Dialogs.FLAREUI_COLORS_UNSAVED.OnCancel()
assert(ab.custom.range[4] == 0.5)
open("ab")
window.reset:Click()
assert(next(ab.custom) == nil and not window.reset:IsShown() and changes > 4)
window.apply:Click()

open("uf")
assert(colorRow("class:MAGE").label:GetText() == "MAGE" and colorRow("heal").label:GetText() == "Incoming Heals")
local health = colorRow("health")
health:Click()
assert(not picker.info.hasOpacity, "unit frame colors expose RGB only")
picker.info.swatchFunc()
local player = assert(ui:find(function(w) return w.kindName == "player" and w:IsVisible() end))
local r, g, b = player.Health:GetStatusBarColor()
assert(r == 0.1 and g == 0.2 and b == 0.3 and player.fuiPickHeals.heal:IsShown())
window.apply:Click()
open("rb")
assert(colorRow("swingMain").label:GetText() == "Main-Hand Swing")
open("xp")
assert(colorRow("quest").label:GetText() == "Quest XP")
open("np")
assert(colorRow("offtank").label:GetText() == "Another Tank Has It")
assert(ui:find(function(w) return w.painted == "nokick" and w:IsVisible() end))
open("cdm")
assert(colorRow("bar").label:GetText() == "Bar" and #window.palette:OpenMenu().entries == 2)
window.apply:Click()

print("PASS: color palettes, opacity, cancel, discard, apply and live samples")
