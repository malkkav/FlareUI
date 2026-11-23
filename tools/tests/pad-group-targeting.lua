local UI = dofile("tools/tests/fixtures/settings-ui.lua")
local ui = UI.new()
local env = ui.env
local state = { gamepad = false, group = "solo", keys = {} }
local ns = {
    IsGamepadUI = function() return state.gamepad end,
    OtherControllerAddon = function() return state.otherAddon end,
}
local secure = setmetatable({ floor = math.floor, abs = math.abs }, { __index = env })
local function runSecure(code, widget, control, button)
    secure.self, secure.control, secure.button = widget, control, button
    return setfenv(assert(loadstring(code)), secure)()
end
function secure.SecureCmdOptionParse(condition)
    if condition:find("group:raid", 1, true) then return state.group == "raid" and "1" or "0" end
    if condition:find("group:party", 1, true) then return state.group == "party" and "1" or "0" end
    error("unexpected group condition " .. condition)
end
function env.UnitExists(unit) return unit == "target" and state.target ~= nil or state.units[unit] == true end
function env.UnitIsUnit(unit, other) return other == "target" and unit == state.target end
function env.canaccessvalue() return true end
env.C_CVar = { GetCVarBool = function(key) return state[key] == true end }
env.C_KeyBindings = { GetBindingContextForAction = function(action)
    if action == "GAMEPADACTIONBUTTON1" then return "FriendlyTargeting" end
end }
function env.GetBindingKey(action, index, context)
    if context == "FriendlyTargeting" and index == nil then return "PADDLEFT", "PADLEFTSHOULDER" end
    if state.duplicateKeys and action == "GAMEPADACTIONBUTTON2" then return "PADDUP", "PADDUP" end
end

local refs, wrapped = {}, nil
function env.SecureHandlerSetFrameRef(frame, name, target)
    assert(not ui.combat, "frame refs cannot change in combat")
    refs[frame] = refs[frame] or {}
    refs[frame][name] = target
end
function env.SecureHandlerExecute(frame, code)
    assert(not ui.combat, "the selected unit cannot be seeded in combat")
    runSecure(code, frame)
end
function env.SecureHandlerWrapScript(button, script, control, code)
    assert(not ui.combat and script == "OnClick")
    wrapped = function(direction) return runSecure(code, button, control, direction) end
end

local Widget = getmetatable(env.UIParent)
function Widget:GetFrameRef(key) return refs[self] and refs[self][key] end
function Widget:SetBindingClick(priority, key, target, button)
    assert(priority and target == "FlareUIPadGroupNav")
    state.keys[key] = button
end
function Widget:ClearBindings() state.keys = {} end
function Widget:CallMethod(key, ...) self[key](self, ...) end
function Widget:GetRect()
    if not self.unplaced then return self:GetLeft(), self:GetBottom(), self:GetWidth(), self:GetHeight() end
end

ui:load("Modules/PadGroupTargeting.lua", ns)
local pgt = ns.PadGroupTargeting
ui:emit("PLAYER_LOGIN")
assert(not pgt.watcher)
state.gamepad, state.otherAddon = true, true
ui:emit("PLAYER_LOGIN")
assert(not pgt.watcher, "another controller addon owns the bindings")
state.otherAddon = false
ui:emit("PLAYER_LOGIN")
assert(not pgt.watcher, "Blizzard's targeting bar must exist")
local bar = env.CreateFrame("Frame", nil, env.UIParent)
env.GamepadMainActionBarFrame = { PageUnit = { FriendlyTargetingActionBar = bar } }
ui.combat = true
ui:emit("PLAYER_LOGIN")
assert(pgt.setupPending and not pgt.watcher)
ui.combat = false
state.units = { party1 = true, party2 = true, party3 = true, party4 = true, party5 = true }
local function member(unit, x, y)
    local frame = env.CreateFrame("Button", nil, env.UIParent)
    frame:SetSize(30, 20)
    frame.left, frame.bottom = x, y
    frame:SetAttribute("unit", unit)
    pgt.Add(frame)
    return frame
end
local a = member("party1", 0, 50)
local b = member("party2", 40, 50)
local c = member("party3", 0, 20)
local d = member("party4", 40, 20)
pgt.Add(a)
ui:emit("PLAYER_REGEN_ENABLED")
assert(not pgt.setupPending and pgt.watcher:GetParent() == bar and pgt.refCount == 4)
assert(pgt.nav:GetAttribute("type") == "target" and pgt.highlight:GetParent() == env.UIParent)
assert(#pgt.highlight.regions == 8 and not pgt.highlight:IsShown())

local function hold() runSecure(pgt.watcher:GetAttribute("_onshow"), pgt.watcher) end
local function release() runSecure(pgt.watcher:GetAttribute("_onhide"), pgt.watcher) end
local function pick(direction, memberFrame)
    assert(wrapped(direction) == "LeftButton")
    assert(pgt.nav:GetAttribute("unit") == memberFrame:GetAttribute("unit"))
    assert(pgt.highlight:IsShown() and pgt.highlight.owner == memberFrame)
end
hold()
assert(not next(state.keys) and wrapped("PadRight") == false, "the D-pad stays free while solo")
state.group, state.GamepadUsePartyTargeting = "party", true
ui:emit("CVAR_UPDATE", "GamepadUsePartyTargeting")
hold()
assert(not next(state.keys), "party direct targeting keeps Blizzard's bindings")
state.group = "raid"
hold()
assert(pgt.bound and state.keys.PADDLEFT == "PadLeft" and state.keys.PADLEFTSHOULDER == "PadLeft")
assert(wrapped("unexpected") == false)
pick("PadRight", a) -- no target starts at the upper-left
pick("PadRight", b)
pick("PadRight", a) -- wrap on the same row
pick("PadDown", c)
pick("PadRight", d)
pick("PadUp", b)
b:Hide()
assert(not pgt.highlight:IsShown())
pick("PadDown", a) -- a hidden selection is discarded
release()
assert(not pgt.bound and not next(state.keys) and not pgt.highlight:IsShown())

state.target = "party4"
ui:emit("PLAYER_TARGET_CHANGED")
hold()
pick("PadLeft", c)
release()

-- Key updates and new secure frame references are deferred during lockdown.
ui.combat, state.GamepadSwapFriendlyTargetActions = true, true
local e = member("party5", 100, 60)
assert(pgt.dirty and pgt.refCount == 4)
ui:emit("UPDATE_BINDINGS")
assert(pgt.keysDirty)
ui.combat = false
ui:emit("PLAYER_REGEN_ENABLED")
assert(pgt.refCount == 5 and pgt.watcher:GetFrameRef("b5") == e and not pgt.dirty)
assert(pgt.watcher:GetAttribute("flare-key1-1") == "PAD3" and not pgt.keysDirty)
state.GamepadSwapFriendlyTargetActions, state.duplicateKeys = false, true
ui:emit("CVAR_UPDATE", "GamepadSwapFriendlyTargetActions")
assert(pgt.watcher:GetAttribute("flare-key2-1") == "PADDUP")
assert(not pgt.watcher:GetAttribute("flare-key2-2"))
for _, frame in ipairs({ a, b, c, d, e }) do frame:Hide() end
hold()
assert(not next(state.keys), "a group with no visible frame does not take over the D-pad")
print("PASS: gamepad targeting follows visible group frames, wraps directions and defers secure changes")
