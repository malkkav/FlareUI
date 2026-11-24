local H = dofile("tools/tests/perf-helpers.lua")
local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local noop = function() end
local db = {
    enabled = true, style = "square", swipe = "both", timer = "below", arrive = true, timerColor = true,
    font = { face = "Test Face", size = 11, flags = "NONE" }, countFont = {},
    buffs = { size = 30, perRow = 3, max = 5, spacing = 4, grow = "LEFT", wrap = "DOWN", font = {}, countFont = {} },
    debuffs = { size = 24, perRow = 4, max = 4, spacing = 3, grow = "RIGHT", wrap = "UP", font = {}, countFont = {} },
}
local wakes, reminders = 0, 0
local ns = {
    modules = {}, L = setmetatable({}, { __index = function(_, key) return key end }),
    db = { profile = { auras = db } }, defaults = { profile = { auras = { buffs = {}, debuffs = {} } } },
    IsGamepadUI = function() return ui.gamepad == true end,
    EditPreviewing = function() return ui.editing == true end,
    OnEditFight = function(callback) ui.editFight = callback end,
    GetFontPath = function(face) return "Fonts/" .. face end,
    SetFont = function(frame, ...) frame:SetFont(...) end,
    ApplyShadow = noop, RawHide = function(frame) frame:Hide() end,
    Visibility = { Wake = function() wakes = wakes + 1 end },
    BuffReminders = { Refresh = function() reminders = reminders + 1 end },
    OrderEditSettings = noop,
}
env.ns = ns
env.C_AddOns.DoesAddOnExist = function() return true end
env.C_AddOns.IsAddOnLoaded = function() return ui.auraLoaded == true end
env.C_AddOns.LoadAddOn = function(name) assert(name == "Blizzard_AuraContainer"); ui.auraLoaded = true end
env.C_StringUtil = { CreateNumericRuleFormatter = function() end }
env.Enum = { CustomAuraButtonDispelTypeTextureStyle = { PreserveAsset = 1, Icon = 2 } }
env.AuraUtil = { SetAuraDispelTypeIcon = function(texture, kind) texture:SetAtlas("Dispel/" .. kind) end }
local editMode = { SettingType = { Dropdown = 1, Slider = 2, Expander = 3 }, callbacks = {} }
function editMode:AddFrame(holder, moved) holder.moved = moved end
function editMode:AddFrameSettings(holder, settings) holder.settings = settings end
function editMode:GetActiveLayoutName() return "Modern" end
function editMode:Defer() return false end
function editMode:RegisterCallback(event, callback)
    self.callbacks[event] = self.callbacks[event] or {}
    table.insert(self.callbacks[event], callback)
end
env.LibStub = function(name) assert(name == "FlareEditMode"); return editMode end
local weapon = { hasEnchant = true, timeLeft = 100000, enchantType = 1, enchantID = 100, charges = 5, enchantIconID = 999 }
env.C_Item = { GetWeaponEnchantInfo = function(slot) return slot == 0 and { weapon } or {} end }
env.GetInventoryItemTexture = function() return 123 end
env.GetCVarBool = function(name) return name == "displayTemporaryEnchantIcon" end
local anchors, nextAnchor = {}, 0
env.C_UnitAuras = {
    AddPrivateAuraAnchor = function(opts) nextAnchor = nextAnchor + 1; anchors[nextAnchor] = opts; return nextAnchor end,
    RemovePrivateAuraAnchor = function(id) assert(anchors[id]); anchors[id] = nil end,
}
H.loadSections("Core.lua", {
    {"ns.AuraOrder = {}", "-- The Edit Mode \"Aura Ordering\" rows"},
    {"local AURA_TIME_BANDS =", "-- Bags & Looting's switch"},
    {"function ns.FormatAuraTime(", "-- GameTooltip for FlareUI's own buttons."},
    {"function ns.SeedFont(", "-- AURA POLICY: what every aura frame shows."},
    {"function ns.EditSections()", "-- A spell the player knows."},
}, env)
ns.AuraPolicy = { PlayerListLane = function(debuff) return { filter = debuff and "HARMFUL" or "HELPFUL" } end }

local Widget = getmetatable(env.UIParent)
function Widget:SetDrawSwipe(value) self.drawSwipe = value end
function Widget:SetDrawEdge(value) self.drawEdge = value end
function Widget:SetUseCircularEdge(value) self.circular = value end
function Widget:SetReverse(value) self.reverse = value end
function Widget:SetEdgeTexture(texture) self.edge = texture end
function Widget:SetOffset(x, y) self.offset = { x, y } end
function Widget:SetSmoothing(value) self.smoothing = value end
function Widget:SetVertexColor(...) self.color = { ... } end
function Widget:SetSwipeTexture(texture) self.swipeTexture = texture end
dofile("tools/tests/fixtures/aura-containers.lua")(env)

env.BuffFrame = env.CreateFrame("Frame", nil, env.UIParent)
env.DebuffFrame = env.CreateFrame("Frame", nil, env.UIParent)
ui:load("Modules/Auras.lua", ns)
local auras = ns.Auras
ui.gamepad = true
assert(not auras:ShouldLoad())
ui.gamepad = false
assert(auras:ShouldLoad())
auras:Init()
local buffs, debuffs = auras:GetFrame("buffs"), auras:GetFrame("debuffs")
local buffKey, debuffKey = buffs.groupKey, debuffs.groupKey
assert(ui.auraLoaded and not env.BuffFrame:IsShown() and not env.DebuffFrame:IsShown())
assert(buffs.container.unit[1] == "player" and buffs:GetWidth() == 98 and debuffs.container.corner[1] == "BOTTOMLEFT")
assert(buffs.container.groups.lead.enabled and buffs.container.groups.lead.layout.elementWidth == 30)
assert(buffs.container.groups[buffKey].maxFrameCount == 4 and debuffs.container.groups[debuffKey].filter == "HARMFUL")
assert(buffs.enchants[1].FlareUI_Icon:GetTexture() == 999 and buffs.enchants[1].FlareUI_Count:GetText() == "5")
assert(buffs.enchants[1].FlareUI_Duration:GetText() == "2m" and auras.KindFont("buffs", "countFont").face == "Test Face")
assert(anchors[debuffs.privateAnchors[4].anchorID].auraIndex == 4)

local function auraButton(holder)
    local frame = env.CreateFrame("Frame", nil, holder.container)
    holder.container.groups[holder.groupKey].opts.initializeFrame(frame)
    return frame
end
local buff, debuff = auraButton(buffs), auraButton(debuffs)
assert(buff.auraIcon == buff.FlareUI_Icon and buff.auraCooldown == buff.FlareUI_Cooldown)
assert(buff.arrival and buff.cancelClick == "RightButtonUp" and not debuff.cancelClick)
assert(debuff.dispelTextures[debuff.FlareUI_DispelIcon].style == env.Enum.CustomAuraButtonDispelTypeTextureStyle.Icon)
-- (11-24) a unit frame's type icons go while its unit is an enemy: Blizzard shows the icon, its frame hides it
do
    local owner, look = {}, ns.AuraLook.ForUnit(24, true, false, "square", "both", "none", "target")
    local first, second = env.CreateFrame("Frame", nil, env.UIParent), env.CreateFrame("Frame", nil, env.UIParent)
    first.FlareUI_AuraOwner = owner
    ns.AuraLook.Style(first, look)
    assert(first.FlareUI_DispelHolder:GetAlpha() == 1 and first.FlareUI_DispelIcon:GetParent() == first.FlareUI_DispelHolder)
    ns.AuraLook.DispelSide(owner, true)
    assert(first.FlareUI_DispelHolder:GetAlpha() == 0)
    second.FlareUI_AuraOwner = owner
    ns.AuraLook.Style(second, look)
    assert(second.FlareUI_DispelHolder:GetAlpha() == 0, "a button made while the unit is an enemy")
    ns.AuraLook.DispelSide(owner, false)
    assert(first.FlareUI_DispelHolder:GetAlpha() == 1 and second.FlareUI_DispelHolder:GetAlpha() == 1)
end
assert(ns.auraTipKind[debuff] == "solo" and buff.FlareUI_Cooldown.drawEdge)

weapon.timeLeft, weapon.charges = 15000, 1
ui:emit("WEAPON_ENCHANT_CHANGED")
assert(buffs.enchants[1].FlareUI_Duration:GetText() == "15s" and buffs.enchants[1].FlareUI_Count:GetText() == "")
assert(buffs.enchants[1].FlareUI_Cooldown.cooldown[2] == 100, "enchant swipe remembers its full duration")
weapon.hasEnchant = false
ui:emit("UNIT_INVENTORY_CHANGED", "player")
assert(not buffs.enchants[1]:IsShown() and not buffs.container.groups.lead.enabled)
assert(buffs.container.groups[buffKey].maxFrameCount == 5 and not buffs:GetScript("OnUpdate"))

local oldAnchor = debuffs.privateAnchors[1].anchorID
db.style, db.swipe, db.timer = "round", "border", "middle"
auras:SetSettingsPreview(true)
assert(auras:IsSettingsPreview() and not buffs.container:IsShown() and not debuffs.container:IsShown())
assert(#buffs.preview == 3 and #buffs.previewEnchants == 2 and #debuffs.preview == 4)
assert(buff.FlareUI_Cooldown.circular and not buff.FlareUI_Cooldown.drawEdge and buff.FlareUI_PreviewTimer:IsShown())
assert(buff.FlareUI_TimerFrame:GetAlpha() == 0 and not anchors[oldAnchor])
assert(debuffs.preview[1].FlareUI_DispelIcon:GetAtlas() == "Dispel/Magic")
assert(buffs.groupKey == buffKey and debuffs.groupKey == debuffKey and wakes == 1)

ui:emit("PLAYER_REGEN_DISABLED")
assert(not auras:IsSettingsPreview() and buffs.container:IsShown() and not buff.FlareUI_PreviewTimer:IsShown())
ui.combat = true
local size
for _, row in ipairs(debuffs.settings) do if row.name == "Icon Size" then size = row end end
assert(size)
size.set(nil, 17)
assert(debuff:GetWidth() == 24, "the existing button cannot be resized during combat")
ui.combat = false
ui:emit("PLAYER_REGEN_ENABLED")
assert(auras:IsSettingsPreview() and debuff:GetWidth() == 17 and not debuff.FlareUI_DispelIcon:IsShown())
auras:SetSettingsPreview(false)
assert(debuffs.container:IsShown() and not debuffs.preview[1]:IsShown() and reminders >= 3)
debuffs.moved(debuffs, "Modern", "BOTTOMLEFT", 15.3, -12.6)
for _, callback in ipairs(editMode.callbacks.layout) do callback("Modern") end
assert(debuffs:GetPoint() == "BOTTOMLEFT" and select(4, debuffs:GetPoint()) == 15)
print("PASS: aura container setup, enchant timing, icon restyles, private anchors and preview combat deferral")
