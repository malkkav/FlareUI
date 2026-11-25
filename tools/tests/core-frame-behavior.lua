local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local T = { Expander = "expander", Dropdown = "dropdown", Slider = "slider", Checkbox = "check" }
local editMode = { SettingType = T, IsInEditMode = function() return ui.editing == true end }
env.LibStub = function(name) return name == "FlareEditMode" and editMode or {} end
env.securecallfunction = function(func, ...) return func(...) end
env.GetLocale = function() return "enUS" end
env.canaccessvalue = function(value) return value ~= "unreadable" end
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    db = { profile = { unitframes = { fullNames = true }, tweaks = { enabled = true } }, global = {} },
}
ui:load("Core.lua", ns)

local function frame(kind)
    local f = env.CreateFrame(kind or "Frame", nil, env.UIParent)
    f.IsProtected = function(self) return self.protected == true, self.explicit == true end
    return f
end

local function eq(actual, expected)
    assert(actual == expected, ("expected %s, got %s"):format(tostring(expected), tostring(actual)))
end

assert(ns.BagModuleOn())
ns.db.profile.tweaks.bagModule = nil
assert(not ns.BagModuleOn(), "The bag switch is seeded only once per profile")
assert(ns.CastGlowOn(nil))
ns.db.global.whatsNewSeen = "7.0"
assert(ns.CastGlowOn(nil), "The default stays fixed after the release notes are seen")
assert(ns.BorderEdgeSize("Interface\\FlareUI-Thin.tga", 12) == 6 and ns.BorderEdgeSize(nil) == 16)

local r, g, b = ns.SoftColor(0, 1, 0)
assert(g > r and g > b and g < 1)
env.PowerBarColor = { RAGE = env.CreateColor(0.9, 0.1, 0.1) }
eq(ns.PowerColor("RAGE"), 0.9)
eq(ns.PowerColor(nil, 0), ns.MANA_BLUE[1])
ns.POWER_OVERRIDE = { RAGE = { 0.4, 0.1, 0.7 } }
eq(ns.PowerColor("RAGE"), 0.4)
eq(ns.PowerColor("OTHER"), nil)

env.UnitName = function(unit) return "Marin", unit == "secret" and "unreadable" or "Reed" end
env.UnitEffectiveLevel = function(unit) return unit == "boss" and -1 or "unreadable" end
env.UnitLevel = function() return 42 end
env.UnitIsFriend = function(_, unit) return unit == "pet" end
env.C_PlayerInfo = { GetContentDifficultyCreatureForPlayer = function(unit) return unit == "target" and 3 or "unreadable" end }
env.GetDifficultyColor = function() return "challenging" end
env.GetQuestDifficultyColor = function(level) return "level " .. level end
eq(ns.UnitShownLevel("boss"), -1)
eq(ns.UnitShownLevel("target"), 42)
eq(ns.UnitLevelColor("pet", 12).g, 0.82)
eq(ns.UnitLevelColor("target", 42), "challenging")
eq(ns.UnitLevelColor("boss", 50), "level 50")
eq(ns.UnitDisplayName("party1"), "Marin Reed")
eq(ns.UnitDisplayName("party1", "targetof"), "Marin")
eq(ns.UnitDisplayName("secret"), "Marin")
local level = frame():CreateFontString()
ns.SetHighLevelText(level)
eq(level:GetText(), ns.HIGH_LEVEL_SKULL)
ns.SetHighLevelText(level, { highSkull = { shown = false } })
eq(level:GetText(), "??")
eq(ns.AuraSize({ buffSize = 22, auraSize = 18 }, true, 16), 18)
eq(ns.AuraSize({ buffSize = 22, auraSize = 18 }, false, 16), 22)
ns.db.profile.unitframes.classColor = false
assert(not ns.ClassColorsOn() and ns.ClassColorsOn({ classColor = true }))

env.PixelUtil = { GetPixelToUIUnitFactor = function() return 1.5 end }
local host = frame()
host:SetScale(0.75)
local x, w, pixel = ns.SegmentSpan(host, 100, 3, 2)
assert(x == 34 and w == 32 and pixel == 2)
local relayout = 0
ns.ResourceBars = { initialized = true, Refresh = function() relayout = relayout + 1 end }
ns.UnitFrames = { initialized = true, Refresh = function() relayout = relayout + 1 end }
ns.XPBar = { initialized = false, Refresh = function() error("uninitialized module refreshed") end }
ns.ObjectiveTracker = { initialized = true, RequestRender = function() relayout = relayout + 1 end }
ui.combat = true
ui:emit("UI_SCALE_CHANGED")
ui:flushTimers()
eq(relayout, 0)
ui.combat = false
ui:emit("PLAYER_REGEN_ENABLED")
eq(relayout, 3)

local makeFrame = env.CreateFrame
env.CreateFrame = function(kind, name, parent, template)
    local f = makeFrame(kind, name, parent, template)
    if template == "RogueComboPointTemplate" then
        function f:Setup() self.ready = true end
        function f:SetActive(lit) self.lit, self.animated = lit, true end
        function f:SetActiveNoAnimation(lit) self.lit, self.animated = lit, false end
    end
    return f
end
local point = ns.CreateComboPoint(host, 2, 22, true)
assert(point.blizz.ready and point.blizz:IsShown() and not point.blizz.lit and not point.gem:IsShown())
ns.SetComboPoint(point, 3, true)
assert(point.blizz.lit and point.blizz.animated)
ns.SetComboPoint(point, "unreadable", false)
assert(not point.blizz:IsShown() and point.gem:IsShown() and point.gem.lit:GetValue() == "unreadable")
ns.SizeComboPoint(point, 30)
assert(point.gem:GetWidth() == 30 and point.blizz:GetScale() == 1.5)

env.Enum = { StatusBarInterpolation = { ExponentialEaseOut = 4 }, PlayerSwingType = { MainHand = 1, Ranged = 2 } }
local bar = frame("StatusBar")
bar.SetValue = function(self, value, interpolation) self.value, self.interpolation = value, interpolation end
ns.SetBarValue(bar, "unreadable", true)
assert(bar.value == "unreadable" and bar.interpolation == 4)
bar:Hide()
ns.SetBarValue(bar, "unreadable", true)
assert(bar.interpolation == nil)

local protected = frame()
protected.protected, protected.explicit = true, true
local wraps = 0
env.SecureHandlerWrapScript = function(target, script, header, before, after)
    assert(target == protected and script == "OnShow" and header.template == "SecureHandlerBaseTemplate")
    assert(before:find("flareui-hide", 1, true) and after:find("self:Hide()", 1, true))
    wraps = wraps + 1
end
ui.combat = true
assert(ns.HideFrameSecurely(protected, true) and protected:IsShown())
ui.combat = false
ui:emit("PLAYER_REGEN_ENABLED")
assert(not protected:IsShown() and protected:GetAttribute("flareui-hide") and wraps == 1)
protected:Show()
assert(not protected:IsShown(), "A native show should re-hide an explicitly hidden frame")
ns.HideFrameSecurely(protected, false)
assert(protected:IsShown() and protected:GetAttribute("flareui-hide") == nil)

local container = frame()
local pet = env.CreateFrame("Frame", nil, container)
pet.IsProtected = function() return true, false end
pet.actionButtons = { frame("Button") }
pet.ShowBase, pet.SetShownBase = pet.Show, pet.SetShown
ns.HideFrameSecurely(pet, true)
assert(pet:GetParent() == env.FlareUI_HiddenBarParent and not pet:IsVisible())
pet:ShowBase()
assert(not pet:IsShown())
pet.isShownExternal = false
ns.HideFrameSecurely(pet, false)
assert(pet:GetParent() == container and not pet:IsShown())
assert(not ns.HideFrameSecurely({}, true))

-- the raid manager, protected through its buttons only: parked, so joining a group in a fight can't show it
local manager = env.CreateFrame("Frame", nil, container)
env.CompactRaidFrameManager = manager
manager.IsProtected = function() return true, false end
ns.HideFrameSecurely(manager, true)
assert(manager:GetParent() == env.FlareUI_HiddenBarParent)
ui.combat = true
manager:Show()
assert(not manager:IsVisible(), "nothing Blizzard shows in a fight is drawn")
ui.combat = false
ns.HideFrameSecurely(manager, false)
assert(manager:GetParent() == container and manager:IsVisible(), "switched off: back as Blizzard left it")

local resized = frame()
resized:SetSize(1, 1)
resized:SetScale(2)
local slotted = false
local function slot(left)
    local slotFrame = frame()
    function slotFrame:GetScaledRect()
        if slotted then return left, 40, 32, 36 end
    end
    return slotFrame
end
resized.shownButtonContainers = { slot(0), slot(40), slot(100) }
resized.shownButtonContainers[3]:Hide()
resized.minimumWidth = 42
resized.GetHeightPadding = function() return 3 end
ns.QueueBarSizeCheck(resized)
ui:flushTimers()
eq(resized:GetWidth(), 1)
slotted = true
ui:flushTimers()
assert(resized:GetWidth() == 42 and resized:GetHeight() == 21)

local system, reference = frame(), frame()
system.Selection = env.CreateFrame("Frame", nil, system)
system.Selection:SetScale(2)
reference:SetScale(1.5)
system.systemInfo = { anchorInfo = { point = "TOP", offsetX = 15, offsetY = -30 } }
system.SetClampRectInsets = function(self, ...) self.insets = { ... } end
local ready = false
ns.FitEditModeBox(system, function()
    if ready then return reference, 2, 4, 6, 8 end
end)
assert(system.Selection:GetNumPoints() == 0)
ready = true
ui:flushTimers()
local pointName, relativeTo, _, left, top = system.Selection:GetPoint(1)
-- on the system itself: Edit Mode's Snap reads these offsets as the distance from the system's edges
assert(pointName == "TOPLEFT" and relativeTo == system and left == system.insets[1] / 2 and top == system.insets[3] / 2)
local anchor, _, _, offsetX, offsetY = system:GetPoint(1)
assert(anchor == "TOP" and offsetX == 15 and offsetY == -30)
assert(system.insets[1] == 3 and system.insets[3] == 256)
system.SetScaleBase, system.SetPointBase = system.SetScale, system.SetPoint
ns.SetSystemScale(system, 0.5)
local _, _, _, movedX, movedY = system:GetPoint(1)
assert(movedX == 30 and movedY == -60, "Scaling preserves the offset in screen units")

local callbacks = 0
ns.OnEditFight(function() callbacks = callbacks + 1 end)
ui.editing = true
assert(ns.EditPreviewing())
ui:emit("PLAYER_REGEN_DISABLED")
assert(not ns.EditPreviewing() and callbacks == 1)
ui:emit("PLAYER_REGEN_ENABLED")
assert(ns.EditPreviewing() and callbacks == 2)
ui.editing = false
ui:emit("PLAYER_REGEN_DISABLED")
assert(callbacks == 2)

local sections, settings = ns.EditSections()
local sizes, texts, behaviors = ns.SplitFrameItems({
    { name = "Width", kind = T.Slider }, { name = "Health Text", kind = T.Dropdown },
    { name = "Portrait", kind = T.Dropdown }, { name = "Range Check", kind = T.Checkbox },
})
assert(sizes[1].name == "Width" and texts[1].name == "Health Text" and behaviors[1].name == "Range Check")
sections("Look", { { name = "Border", kind = T.Dropdown }, { name = "Texture", kind = T.Dropdown, hidden = true } })
assert(settings[1].editSection == "Look" and settings[2].name == "Portrait" and settings[2].hidden())
settings[1].set(nil, true)
assert(settings[1].get() and not settings[2].hidden() and settings[4].hidden())
settings[1].set(nil, false, true)
assert(settings[1].get(), "Reset settings keeps the current section open")

env.tContains = function(list, value)
    for _, found in ipairs(list) do if found == value then return true end end
    return false
end
local spec = {
    exclusive = { "always" }, tokens = { "combat", "city", "notcity" }, empty = "never",
    rivals = { city = "notcity", notcity = "city" }, legacy = { old = "combat,city" },
}
local C = ns.Conditions
assert(C.Ticked("old", "city", spec) and not C.Ticked("always", "city", spec))
eq(table.concat(C.Selection("old", spec), ","), "combat,city")
eq(C.Toggle("old", "notcity", spec), "combat,notcity")
eq(C.Toggle("always", "combat", spec), "combat")
eq(C.Toggle("combat", "combat", spec), "never")
eq(C.Toggle("combat,city", "always", spec), "always")

local known, answer, dead = {}, {}, false
env.UnitExists = function() return true end
env.UnitCanAttack = function() return true end
env.UnitIsDeadOrGhost = function() return dead end
env.UnitClass = function() return "Rogue", "ROGUE" end
env.canaccessallvalues = function() return true end
env.C_SpellBook = { IsSpellKnown = function(id) return known[id] end }
env.C_Spell = { IsSpellInRange = function(id) return answer[id] end }
env.C_SwingTimer = { IsTargetWithinSwingRange = function() return nil end }
env.CheckInteractDistance = function(_, distance) return distance == 3 end
assert(ns.TargetInRange(false))
known[1752], answer[1752] = true, false
eq(ns.TargetInRange(false), false)
assert(ns.TargetInRange(true) == nil)
env.C_SwingTimer.IsTargetWithinSwingRange = function(kind) return kind == 2 end
assert(ns.TargetInRange(true) and not ns.TargetInRange(false))
dead = true
eq(ns.TargetInRange(true), nil)

ui.time = 100
ns.WindowOpenSound()
ns.WindowCloseSound()
eq(#ui.sounds, 1)
ui.time = 101
ns.ButtonSound()
ns.WindowOpenSound()
assert(#ui.sounds == 2 and ui.sounds[2][1] == 852)
print("PASS: shared frame behavior, secure visibility decisions, Edit Mode and range checks")
