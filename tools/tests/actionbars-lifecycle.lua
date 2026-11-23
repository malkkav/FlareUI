local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local noop = function() end
local fonts = { face = "Test Font", size = 12, flags = "OUTLINE" }
local db = {
    enabled = true, buttonArt = true, flareBorders = true, activeHighlight = true, equippedBorder = true,
    hotkeyFont = fonts, countFont = fonts, macroFont = fonts, buttonScale = 1.2,
    colors = { enableRange = true }, autoPagingBar = 2, stopAutoAddSpells = true, autoRanks = true,
}
local fcm = { bars = { bar1 = { enabled = true } } }
local character, dbCallbacks, moduleEvents = {}, {}, {}
local ns = {
    modules = {},
    L = setmetatable({}, { __index = function(_, key) return key end }),
    db = { profile = { actionbars = db, fcm = fcm }, global = {} },
    BORDER_COLOR = { r = 0.6, g = 0.5, b = 0.3, a = 1 },
    SetFont = function(widget, ...) widget:SetFont(...) end,
    GetFontPath = function(face) return "Fonts/" .. face end,
    ApplyShadow = noop,
    BorderEdgeSize = function(_, size) return size end,
    FCMActive = function() return fcm.bars.bar1.enabled end,
    CharDB = function() return character end,
    IsGamepadUI = function() return false end,
    SetSystemScale = function(frame, scale) frame:SetScale(scale) frame.keptPlace = true end,
}
function ns.db.RegisterCallback(_, event, callback) dbCallbacks[event] = callback end
local refresh, wakes = 0, 0
ns.Visibility = {
    Refresh = function() refresh = refresh + 1 end,
    Wake = function() wakes = wakes + 1 end,
}
local ace = { Embed = noop }
local media = { Fetch = function(_, kind, name) return kind .. "/" .. name end }
local editMode = { SettingType = { Slider = 1 } }
function env.LibStub(name)
    if name == "LibSharedMedia-3.0" then return media end
    if name == "FlareEditMode" then return editMode end
    if name == "AceEvent-3.0" or name == "AceTimer-3.0" or name == "AceHook-3.0" then return ace end
    error("unexpected library " .. name)
end
local spellNames = { [11] = "Smite", [12] = "Smite", [13] = "Smite", [78] = "Heroic Strike", [71] = "Defensive Stance" }
local slot = {
    { kind = "spell", id = 78, usable = true, current = true, range = true },
    { kind = "item", id = 23, usable = true, equipped = true, range = true },
    [20] = { kind = "spell", id = 11 }, -- lower rank intentionally assigned
    [21] = { kind = "spell", id = 12 },
}
local cursor, picked, spellCount = nil, nil, 2
local function info(action) return slot[action] or {} end
local cvar = "1"
env.C_CVar = {
    GetCVar = function(name) assert(name == "AutoPushSpellToActionBar"); return cvar end,
    SetCVar = function(name, value) assert(name == "AutoPushSpellToActionBar"); cvar = value end,
}
env.C_AddOns.IsAddOnLoaded = function() return false end
env.EventUtil = { ContinueOnAddOnLoaded = noop }
env.canaccessvalue = function() return true end
env.UnitClass = function() return "Warrior", "WARRIOR" end
env.UnitFactionGroup = function() return "Alliance" end
env.PetHasActionBar = function() return false end
env.C_Spell = {
    GetSpellName = function(id) return spellNames[id] end,
    GetSpellSubtext = function(id) return id >= 11 and id <= 13 and "Rank " .. (id - 10) or nil end,
    GetSpellCooldown = function() return { isActive = true, startTime = 10, duration = 1.5 } end,
    PickupSpell = function(id) assert(not ui.combat); cursor, picked = "spell", id end,
}
env.C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return { numSpellBookItems = spellCount, itemIndexOffset = 0 } end,
    GetSpellBookItemInfo = function(i) return { spellID = 10 + i } end,
    IsSpellKnown = function() return true end,
}
env.C_ActionBar = {
    HasAction = function(action) return slot[action] ~= nil end,
    IsAutoRepeatAction = function(action) return info(action).repeatAttack end,
    IsCurrentAction = function(action) return info(action).current end,
    IsAttackAction = function(action) return info(action).attack end,
    IsEquippedAction = function(action) return info(action).equipped end,
    IsUsableAction = function(action) local record = info(action); return record.usable, record.noMana end,
    IsActionInRange = function(action) return info(action).range end,
    GetActionCooldown = function(action) return info(action).cooldown end,
}
env.C_LevelLink = { IsActionLocked = function(action) return info(action).locked end }
env.C_Item = { GetItemQualityByID = function() return 4 end, GetItemQualityColor = function() return 0.6, 0.2, 0.8 end }
function env.GetActionInfo(action) local record = info(action); return record.kind, record.id end
function env.GetCursorInfo() return cursor end
function env.PlaceAction(action) assert(cursor == "spell"); slot[action].id = picked end
function env.ClearCursor() cursor, picked = nil, nil end
env.ActionButton_UpdateCooldown = noop
env.ActionButton_UpdateRangeIndicator = noop
env.RANGE_INDICATOR = "●"
env.Enum = { EditModeBagsSetting = { Size = 1 }, SpellBookSpellBank = { Player = 1 } }
local bindings = { ACTIONBUTTON1 = "SHIFT-NUMPADPLUS", ["CLICK ActionButton2:LeftButton"] = "BUTTON5" }
env.GetBindingKey = function(action) return bindings[action] end
env.IsBindingForGamePad = function(key) return key == "PAD1" end
env.GetBindingText = function() return "<Pad>" end
env.print = noop

local Widget = getmetatable(env.UIParent)
function Widget:GetDrawLayer() return self.layer or "BACKGROUND" end
function Widget:SetDrawLayer(layer) self.layer = layer end
function Widget:SetVertexColor(...) self.color = { ... } end
function Widget:SetDesaturation(amount) self.desaturation = amount end
function Widget:SetLooping(value) self.looping = value end
function Widget:SetSmoothing(value) self.smoothing = value end
function Widget:SetFrameRef(key, frame) self.refs = self.refs or {}; self.refs[key] = frame end
function Widget:IsProtected() return self.protected == true end
function env.RegisterStateDriver(frame, key, value) frame:SetAttribute(key, value) end

local create = env.CreateFrame
function env.CreateFrame(kind, name, parent, template)
    local frame = create(kind, name, parent, template)
    if template == "ActionButtonSpellAlertTemplate" then frame.ProcStartAnim = frame:CreateAnimationGroup() end
    return frame
end
local function actionButton(name, number)
    local btn = env.CreateFrame("CheckButton", name, env.UIParent)
    btn.action = number
    btn:SetSize(45, 45)
    btn.icon = btn:CreateTexture()
    btn.icon:SetSize(45, 45)
    btn.NormalTexture, btn.PushedTexture = btn:CreateTexture(), btn:CreateTexture()
    btn.HighlightTexture, btn.CheckedTexture = btn:CreateTexture(), btn:CreateTexture()
    btn.SlotArt, btn.SlotBackground, btn.Border = btn:CreateTexture(), btn:CreateTexture(), btn:CreateTexture()
    btn.NormalTexture:SetAtlas("Default Normal")
    btn.NormalTexture:SetSize(47, 46)
    btn.PushedTexture:SetAtlas("Default Pushed")
    btn.SlotArt:Hide()
    btn.HotKey, btn.Count, btn.Name = btn:CreateFontString(), btn:CreateFontString(), btn:CreateFontString()
    btn.cooldown = env.CreateFrame("Cooldown", nil, btn)
    local countdown = btn.cooldown:CreateFontString()
    function btn.cooldown:GetCountdownFontString() return countdown end
    function btn:SetNormalAtlas(atlas) self.NormalTexture:SetAtlas(atlas) end
    function btn:SetPushedAtlas(atlas) self.PushedTexture:SetAtlas(atlas) end
    btn.UpdateHotkeys, btn.UpdateUsable, btn.UpdateAction, btn.Update, btn.UpdateButtonArt = noop, noop, noop, noop, noop
    return btn
end
local a, b = actionButton("ActionButton1", 1), actionButton("ActionButton2", 2)
a.bindingAction, b.bindingAction = "ACTIONBUTTON1", "ACTIONBUTTON2"
local main = env.CreateFrame("Frame", "MainActionBar", env.UIParent)
local caps = env.CreateFrame("Frame", nil, main)
caps.LeftEndCap, caps.RightEndCap = env.CreateFrame("Frame", nil, caps), env.CreateFrame("Frame", nil, caps)
main.EndCaps = caps
function main:UpdateEndCaps() self.EndCaps:Hide() end
env.MAIN_ACTION_BAR_MANAGE_END_CAPS = false
local bag = env.CreateFrame("Frame", "BagsBar", env.UIParent)
bag.protected = true
function bag:GetSettingValue(setting) assert(setting == 1); return 75 end
function bag:UpdateSystemSettingSize() self:SetScale(0.75) end
local totem = env.CreateFrame("Frame", "MultiCastActionBarFrame", env.UIParent)

ui:load("Modules/ActionBars.lua", ns)
local bars = ns.ActionBars
function bars:RegisterEvent(event, callback) moduleEvents[event] = callback end
function bars:SecureHook(...) return env.hooksecurefunc(...) end
function bars:ScheduleTimer(callback, delay) return env.C_Timer.After(delay, callback) end
local function send(event, ...)
    local cb = assert(moduleEvents[event], event)
    if type(cb) == "string" then bars[cb](bars, event, ...) else cb(event, ...) end
end
ui:emit("PLAYER_LOGIN")
assert(cvar == "0" and ns.db.global.autoPushSet)
bars:Init()
assert(a.SlotArt:IsShown() and not a.SlotBackground:IsShown() and a.NormalTexture:GetAlpha() == 0)
assert(a:GetScale() == 1.2 and a.FlareUI_Border:IsShown() and a.FlareUI_CountdownLift == a.cooldown:GetCountdownFontString():GetParent())
assert(a.HotKey:GetText() == "SN+" and b.HotKey:GetText() == "M5")
assert(a.FlareUI_Active:IsShown() and a.FlareUI_Active.pulse:IsPlaying() and not a:IsMouseEnabled())
assert(b.FlareUI_EquipGlow:IsShown() and not a.FlareUI_EquipGlow)
assert(db.noStancePaging and db.autoPagingBar == nil and caps:GetFrameLevel() == 501)
local pager = ui:find(function(frame) return frame.template == "SecureHandlerStateTemplate" end)
assert(pager and pager:GetAttribute("page"):find("bonusbar", 1, true) and pager.refs.b2 == b)
main:UpdateEndCaps()
assert(caps:IsShown())

-- Status precedence and both kinds of cooldown.
env.ActionButton_UpdateRangeIndicator(a, true, false)
assert(a.FlareUI_ColorState == "range" and a.icon.desaturation == 1)
slot[1].usable, slot[1].noMana = false, true
a:UpdateUsable()
assert(a.FlareUI_ColorState == "mana")
slot[1].usable, slot[1].noMana = true, false
a:UpdateUsable()
env.ActionButton_UpdateRangeIndicator(a, true, true)
slot[1].cooldown = { isActive = true, duration = 1.5, startTime = 10 }
env.ActionButton_UpdateCooldown(a)
assert(not a.FlareUI_OnCD and a.icon.desaturation == 0)
slot[1].cooldown = { isActive = true, duration = 8, startTime = 90 }
env.ActionButton_UpdateCooldown(a)
assert(a.FlareUI_OnCD and a.icon.desaturation == 0.25)
slot[1].cooldown, ui.time = nil, 108
a.cooldown:RunScript("OnCooldownDone")
assert(a.FlareUI_ReadyBurst.ProcStartAnim:IsPlaying() and a.icon.desaturation == 0)
a.FlareUI_ReadyBurst.ProcStartAnim:RunScript("OnFinished")
assert(not a.FlareUI_ReadyBurst:IsShown())
slot[1].range = false
a:UpdateAction()
assert(a.FlareUI_ColorState == "range")
bars.SetStatusPalette("custom", "blizzard")
db.colors.custom = { range = { 0.5, 0, 0, 0.5 } }
bars.RepaintStatus()
assert(a.icon.color[1] == 0.75 and a.icon.desaturation == 0.5)
bars.SetStatusPalette("disabled")
bars:Refresh()
assert(a.icon.color[1] == 1 and a.icon.desaturation == 0 and not a.FlareUI_ColorState)

-- Click-through is suspended while dragging or in Setup Mode.
cursor = "item"
send("CURSOR_CHANGED")
assert(a:IsMouseEnabled() and bars.fcm.wasDragging and wakes == 1)
cursor = nil
send("CURSOR_CHANGED")
ui:flushTimers()
assert(not a:IsMouseEnabled() and not bars.fcm.wasDragging and wakes == 2)
ns.ToggleFCMSetupMode()
assert(a:IsMouseEnabled() and refresh == 1)
ns.ToggleFCMSetupMode()
assert(not a:IsMouseEnabled() and refresh == 2)

-- Settings can be saved in combat and applied when the secure widgets can change again.
ui.combat = true
bars.TotemSizeSetting().set(nil, 125)
bars.CapSizeSetting("capLeft").set(nil, 150)
bars.BagBarSizeSetting().set(nil, 55)
assert(totem:GetScale() == 1 and caps.LeftEndCap:GetScale() == 1 and bag:GetScale() == 1)
assert(not bars:SetFCM_UnlockMode(true))
ui.combat = false
send("PLAYER_REGEN_ENABLED")
assert(totem:GetScale() == 1.25 and caps.LeftEndCap:GetScale() == 1.5 and bag:GetScale() == 0.55)
assert(caps.LeftEndCap.keptPlace, "the gryphon keeps its place on screen")
bag:UpdateSystemSettingSize()
assert(bag:GetScale() == 0.55, "the custom bag scale follows Blizzard's layout")
bars.BagBarSizeSetting().set(nil, 45)
assert(bag:GetScale() == 0.75)

-- Keep Page 1 in Stealth (druids): the prowl bar is held too, and a button written over comes back
do
    local class, db, register = env.UnitClass, ns.db.profile.actionbars, env.RegisterStateDriver
    env.UnitClass = function() return "Druid", "DRUID" end
    local drivers = {}
    env.RegisterStateDriver = function(frame, key, value)
        if key ~= "page" then return register(frame, key, value) end
        drivers[#drivers + 1] = value
        frame:SetAttribute("state-page", value == "default" and "default" or 7)
    end
    db.keepStealthPage = true
    bars:Refresh()
    assert(drivers[1]:find("bonusbar:2] 7", 1, true), drivers[1])
    assert(bars.pageCheck)
    a:SetAttribute("actionpage", 8)
    bars.CheckClassPage()
    assert(#drivers == 2, "written again")
    ui.combat = true
    bars.CheckClassPage()
    assert(#drivers == 2, "not in a fight")
    ui.combat = false
    env.UnitClass, env.RegisterStateDriver = class, register
    db.keepStealthPage = false
    bars:Refresh()
end

spellCount = 3
cursor = "item"
send("LEARNED_SPELL_IN_SKILL_LINE", 13)
ui:flushTimers()
assert(slot[21].id == 12 and cursor == "item")
cursor = nil
ui:emit("CURSOR_CHANGED")
assert(slot[21].id == 13 and slot[20].id == 11 and character.topRanks.Smite == 3)

-- Turning off the cosmetic options gives native art/text ownership back.
bindings.ACTIONBUTTON1, db.activeHighlight = "PAD1", false
db.flareBorders, db.buttonArt, db.equippedBorder, db.stopAutoAddSpells = false, false, false, false
bars:Refresh()
assert(a.NormalTexture:GetAlpha() == 1 and a.NormalTexture:GetAtlas() == "Default Normal" and a.NormalTexture:GetWidth() == 47)
assert(not a.SlotArt:IsShown() and a.SlotBackground:IsShown() and a.cooldown:GetCountdownFontString():GetParent() == a.cooldown)
assert(a.HotKey:GetText() == "<Pad>" and not a.FlareUI_Active:IsShown() and not b.FlareUI_EquipGlow:IsShown())
assert(cvar == "1" and not ns.db.global.autoPushSet)
assert(dbCallbacks.OnDatabaseReset)
print("PASS: action bar skins, bindings, status, cooldowns, click-through, deferred settings and spell ranks")
