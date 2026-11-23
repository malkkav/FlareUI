local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local tip = env.GameTooltip
local function noop() end
local secret = {}
env.issecretvalue = function(value) return value == secret end
env.canaccessvalue = function(value) return value ~= secret end
env.LEVEL, env.FACTION_ALLIANCE, env.FACTION_HORDE = "Level", "Alliance", "Horde"
env.PVP_ENABLED, env.UNIT_POPUP_RIGHT_CLICK = "PvP Enabled", "Right-click for frame settings"
env.UnitName = function(unit) return unit == "targettarget" and "Companion" or "Frost" end
env.UnitClass = function() return "Mage", "MAGE" end
env.UnitIsPlayer = function(unit) return unit == "target" end
env.UnitIsFriend = function() return not ui.hostile end
env.UnitReaction = function() return ui.hostile and 2 or 5 end
env.UnitExists = function(unit) return unit == "target" or unit == "targettarget" or unit == "mouseover" end
env.UnitIsUnit = function(unit, target) return ui.targetPlayer and unit == "targettarget" and target == "player" end
env.UnitClassification = function(unit) return unit == "mouseover" and "elite" or "normal" end
env.UnitLevel = function(unit) return unit == "mouseover" and -1 or unit == "player" and 43 or 48 end
env.UnitFactionGroup = function() return "Alliance" end
env.UnitAffectingCombat = function() return ui.combatReadable == false and secret or ui.combat end
env.GetGuildInfo = function() return "Dawnwatch", "Officer" end
env.C_ClassColor = { GetClassColor = function() return env.CreateColor(0.4, 0.7, 1, 1) end }

local HP = 0.6
env.UnitPercentHealthFromGUID = function(guid) assert(guid == "Player-31"); return HP end
env.WorldFrame = env.CreateFrame("Frame", "WorldFrame", env.UIParent)
env.WorldFrame.IsMouseMotionFocus = function() return ui.world == true end
env.GameTooltipStatusBar = env.CreateFrame("StatusBar", "GameTooltipStatusBar", tip)
env.GameTooltipStatusBar:SetAttribute("guid", "Player-31")
env.GameTooltipDefaultContainer = env.CreateFrame("Frame", "GameTooltipDefaultContainer", env.UIParent)
env.ItemRefTooltip = env.CreateFrame("GameTooltip", "ItemRefTooltip", env.UIParent)
for _, name in ipairs({ "GameTooltipHeaderText", "GameTooltipText", "GameTooltipTextSmall" }) do env.CreateFont(name) end

local function nineSlice(widget)
    local slice = { Center = widget:CreateTexture() }
    function slice:SetCenterColor(...) self.centerColor = { ... } end
    function slice:SetBorderColor(...) self.borderColor = { ... } end
    widget.NineSlice = slice
end
nineSlice(tip)
nineSlice(env.ItemRefTooltip)
local createFrame = env.CreateFrame
env.CreateFrame = function(kind, name, parent, template)
    local widget = createFrame(kind, name, parent, template)
    if template == "TooltipBackdropTemplate" then nineSlice(widget) end
    return widget
end
local Widget = getmetatable(tip)
function Widget:GetPadding() return unpack(self.padding or { 0, 0, 0, 0 }) end
function Widget:SetPadding(...) self.padding = { ... } end
function Widget:SetAnchorType(...) self.anchorType = { ... } end
function Widget:SetOwner(owner, anchor, x, y) self.owner, self.anchor, self.anchorX, self.anchorY = owner, anchor, x, y end
function Widget:IsTooltipType(kind) return self.tooltipType == kind end
function Widget:GetUnit() return self.unitName, self.unitToken end
function Widget:NumLines() return self.lineCount or 0 end
function Widget:AddDoubleLine(left, right) self:AddLine(left .. right) end
local function defaultUnitLines()
    tip.lineCount = 7
    for i, text in ipairs({ "Frost", "<Dawnwatch>", "Level 48 Human", "Mage", "Alliance", "PvP Enabled", "Right-click for frame settings" }) do
        local name = "GameTooltipTextLeft" .. i
        local font = env[name] or tip:CreateFontString(name)
        font:SetText(text)
    end
    tip.lines = {}
end
env.TooltipUtil = {
    GetDisplayedUnit = function(widget) return widget.unitName, widget.unitToken end,
    GetDisplayedItem = function() return "Cloth Cap", "|Hitem:128|h[Cloth Cap]|h" end,
}
local kinds = { Unit = 1, Item = 2, Spell = 3, UnitAura = 4 }
env.Enum = { TooltipDataType = kinds, TooltipDataLineType = { ItemLevel = 1, UnitThreat = 2 },
    ItemClass = { Armor = 4, Weapon = 2 } }
env.C_Item = {
    GetItemInfo = function() return "Cloth Cap", nil, 4 end,
    GetItemInfoInstant = function() return 128, nil, nil, nil, nil, 4 end,
    GetDetailedItemLevelInfo = function() return 42 end,
    GetItemQualityColor = function(q) return q == 4 and 0.8 or 0.2, 0.2, 1 end,
}
local callbacks, lineCalls = {}, {}
env.TooltipDataProcessor = {
    AllTypes = "all",
    AddTooltipPostCall = function(kind, callback) callbacks[kind] = callback end,
    AddLinePreCall = function(kind, callback) lineCalls[kind] = callback end,
}
env.GameTooltip_SetDefaultAnchor = function(widget, parent) widget:SetOwner(parent, "ANCHOR_NONE") end
env.SharedTooltip_SetBackdropStyle = noop
local onAddonLoaded
env.EventUtil = { ContinueOnAddOnLoaded = function(_, callback) onAddonLoaded = callback end }
local compare = "1"
env.GetCVar = function(name) assert(name == "alwaysCompareItems"); return compare end
env.SetCVar = function(name, value) assert(name == "alwaysCompareItems"); compare = tostring(value) end
env.LibStub = function(name)
    assert(name == "LibSharedMedia-3.0")
    return { Fetch = function(_, _, value) return "Media/" .. value end }
end
local db = {
    enabled = true, nameColor = "class", showGuildRank = true, showPvP = false, showThreat = false, showTarget = true,
    hideFaction = true, borderByClass = true, borderByReaction = true, borderByQuality = true, healthBarPlace = "inside",
    itemLevel = true, showItemID = true, showSpellID = true, compareShift = true,
    titleFont = { face = "Test", size = 17 }, contentFont = { size = 13, flags = "OUTLINE" }, opacity = 0.55, scale = 1.2,
    anchor = "cursorOffset", anchorFrames = "blizzard", anchorAuras = "cursorOffset", cursorX = 6, cursorY = -4,
}
local forced = {}
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }), modules = {},
    db = { profile = { tooltips = db } }, PALETTE = { ground = { 0.15, 0.1, 0.06 } },
    BORDER_COLOR = env.CreateColor(0.8, 0.6, 0.34, 1),
    Tweaks = { ForcedCVars = function(key) assert(key == "compare"); return forced end },
    auraTipKind = {}, IsGamepadUI = function() return ui.gamepad == true end,
    BorderEdgeSize = function(_, size) return size end,
    GetFontPath = function(face) return "Fonts/" .. face end,
    SetFontObjectFace = function(fs, ...) fs:SetFont(...) end,
    ApplyShadow = noop,
    LevelDifficultyColor = function() return env.CreateColor(1, 0.1, 0.1, 1) end,
}
ui:load("Modules/Tooltips.lua", ns)
local tooltips = ns.Tooltips
assert(tooltips:ShouldLoad())
tooltips:Init()
assert(db.hideFaction == nil and db.showFaction == false)
assert(compare == "0" and forced.compare == "1" and lineCalls[2]())
assert(tip:GetScale() == 1.2 and env.ItemRefTooltip:GetScale() == 1.2)
assert(env.GameTooltipHeaderText:GetFont() == "Fonts/Test" and select(2, env.GameTooltipTextSmall:GetFont()) == 11)
assert(tooltips.Mouseover("world") and not tooltips.Mouseover("frames") and tooltips.Mouseover("auras"))
db.compareShift = false
tooltips:Refresh()
assert(compare == "1" and forced.compare == nil)

local world, unitFrame = env.WorldFrame, env.CreateFrame("Frame", "PlayerFrame", env.UIParent)
unitFrame:SetAttribute("unit", "target")
ui.world = true
env.GameTooltip_SetDefaultAnchor(tip, world)
assert(tip.anchor == "ANCHOR_CURSOR_RIGHT" and tip.anchorX == 6 and tip.anchorY == -4)
ui.world = false
db.corner = "BOTTOMRIGHT"
env.GameTooltip_SetDefaultAnchor(tip, unitFrame)
assert(tip:GetPoint() == "BOTTOMRIGHT" and select(2, tip:GetPoint()) == env.GameTooltipDefaultContainer)
tooltips.SetKindMouseover("frames", true)
env.GameTooltip_SetDefaultAnchor(tip, unitFrame)
assert(tip.anchor == "ANCHOR_CURSOR_RIGHT" and db.mouseoverKinds.frames == nil)
tooltips.SetMouseover(false)
assert(not tooltips.Mouseover("world"))
local auraOwner = env.CreateFrame("Button", nil, unitFrame)
ns.auraTipKind[auraOwner] = "group"
env.AuraButtonTooltip = env.CreateFrame("GameTooltip", "AuraButtonTooltip", env.UIParent)
onAddonLoaded()
tooltips.SetKindMouseover("groupAuras", true)
env.AuraButtonTooltip:SetOwner(auraOwner, "ANCHOR_NONE")
assert(env.AuraButtonTooltip.anchorType[1] == "ANCHOR_CURSOR_RIGHT" and env.AuraButtonTooltip.anchorType[2] == 6)

defaultUnitLines()
tip.unitName, tip.unitToken = "Frost", secret
tip:SetOwner(unitFrame, "ANCHOR_NONE")
tip:Show()
ui.targetPlayer = true
callbacks[kinds.Unit](tip)
assert(env.GameTooltipTextLeft1:GetText():match("^|cff") and env.GameTooltipTextLeft1:GetText():find("Frost", 1, true))
assert(env.GameTooltipTextLeft2:GetText() == "<Dawnwatch> (Officer)")
assert(env.GameTooltipTextLeft3:GetText():find("Human Mage", 1, true))
assert(env.GameTooltipTextLeft4:GetText() == "" and env.GameTooltipTextLeft5:GetText() == "" and env.GameTooltipTextLeft6:GetText() == "")
assert(tip.lines[1] == "Target: |cffff4040You|r")
assert(tip.NineSlice.borderColor[1] == 0.4 and tip.NineSlice.Center:GetAlpha() == 0.55)
assert(not env.GameTooltipStatusBar:IsShown() and select(2, tip:GetPadding()) == tooltips.INSIDE_PAD)
local healthWatch = assert(ui:find(function(w) return w:GetParent() == tip and w:GetScript("OnUpdate") end))
healthWatch:RunScript("OnUpdate", 0.1)
local bar = tooltips.healthOverlay
assert(bar:IsShown() and bar:GetValue() == 0.6 and bar:GetPoint() == "BOTTOMLEFT")
HP = 0.3
healthWatch:RunScript("OnUpdate", 0.1)
local r, g = bar:GetStatusBarColor()
assert(r == 1 and g == 0.6)
db.healthBarPlace = "below"
tooltips:Refresh()
healthWatch:RunScript("OnUpdate", 0.1)
assert(bar:GetPoint() == "TOPLEFT" and select(2, tip:GetPadding()) == 0)
db.hideHealthBar = true
healthWatch:RunScript("OnUpdate", 0.1)
assert(not bar:IsShown())

defaultUnitLines()
db.showGuild, db.showFaction = false, true
ui.targetPlayer = false
callbacks[kinds.Unit](tip)
assert(env.GameTooltipTextLeft2:GetText() == "" and env.GameTooltipTextLeft5:GetText():find("|cff4a9eff", 1, true))
assert(tip.lines[1]:find("Companion", 1, true))
local hiddenWidgets = env.CreateFrame("Frame", nil, tip)
hiddenWidgets.shownWidgetCount = secret
defaultUnitLines()
callbacks[kinds.Unit](tip)
assert(env.GameTooltipTextLeft1:GetText() == "Frost", "a secret child prevents restyling")
hiddenWidgets.shownWidgetCount = 0

tip.unitName, tip.unitToken, tip.tooltipType, tip.lines = nil, nil, kinds.Item, {}
callbacks[kinds.Item](tip, { id = 128, lines = {} })
assert(tip.lines[1] == "Item Level 42" and tip.lines[2] == " Item ID 128")
assert(tip.NineSlice.borderColor[1] == 0.8 * 0.85)
tip.lines = {}
callbacks[kinds.Item](tip, { id = secret, lines = { { type = env.Enum.TooltipDataLineType.ItemLevel } } })
assert(#tip.lines == 0, "a native item level line is not duplicated")
callbacks[kinds.Spell](tip, { id = 168 })
assert(tip.lines[1] == " Spell ID 168")

db.visibility = { auras = "never", actionBars = "combat", worldObjects = "never", frameUnits = "never", other = "never" }
callbacks[kinds.UnitAura](tip, { id = 69 })
assert(not tip:IsShown())
ui.shift = true
tip:Show()
callbacks[kinds.UnitAura](tip, { id = 69 })
assert(tip:IsShown() and tip.lines[2] == " Spell ID 69")
ui.shift = false
local action = env.CreateFrame("Button", "ActionButton7", env.UIParent)
tip:SetOwner(action, "ANCHOR_NONE")
ui.combat, ui.combatReadable = true, false
assert(tooltips.BarTooltipHidden())
callbacks.all(tip)
assert(not tip:IsShown(), "combat fallback applies to action button tooltips")
ui.gamepad = true
tip:Show()
callbacks.all(tip)
assert(tip:IsShown() and not tooltips.BarTooltipHidden())
ui.gamepad, ui.combat = false, false
tip:Hide()
ui.world = true
tip:Show()
assert(not tip:IsShown(), "world object setting hides a tooltip only when it shows")
ui.world = false
env.GameTooltip_SetDefaultAnchor(tip, env.UIParent)
tip:Show()
assert(not tip:IsShown())
tip.unitName, tip.unitToken = "Frost", "target"
tip:Show()
callbacks[kinds.Unit](tip)
assert(not tip:IsShown())

db.shortItemStats, db.healingDamage = true, "power"
local sample = tooltips.CreateSample(env.UIParent, "healing")
local w, h = tooltips.DrawSample(sample)
assert(w > 0 and h > 0 and not sample.bar:IsShown())
assert(sample.left[7]:GetText():find("Spell Healing", 1, true) and sample.left[8]:GetText():find("Spell Power", 1, true))
do
    local item = tooltips.CreateSample(env.UIParent, "item")
    local function found()
        tooltips.DrawSample(item)
        for _, fs in ipairs(item.left) do
            if fs:IsShown() and (fs:GetText() or ""):find("Item Level 76", 1, true) then return true end
        end
    end
    local level = db.itemLevel
    db.itemLevel = true
    assert(found())
    db.itemLevel = false
    assert(not found())
    db.itemLevel = level
end
local comparison = tooltips.CreateSample(env.UIParent, "compare")
tooltips.DrawSample(comparison)
assert(comparison.item:IsShown() and comparison.equipped.left[1]:GetText() == "Currently Equipped")
assert(select(2, comparison.equipped:GetPoint()) == comparison.item)
db.compareShift = true
tooltips:Refresh()
db.enabled = false
tooltips:ShouldLoad()
assert(compare == "1" and not forced.compare)
print("PASS: tooltip content, visibility, anchors, health and item previews")
