-- Run through Bags:Init so the test uses the handlers installed on the bag bar.
-- The client doubles cover mouse clicks, key bindings and bank window ownership.
-- In WoW, repeat each case from /reload. After the second bank visit, open the
-- backpack and right-click a usable item. Verify the actual use and check for
-- ADDON_ACTION_BLOCKED/FORBIDDEN (UseContainerItem) in the same session.
local H = dofile('tools/tests/perf-helpers.lua')
local function noop() end
local function no() return false end
local function yes() return true end
local frames, cursor, combat = {}, nil, false
local Frame = {
    SetHitRectInsets = noop, SetMouseMotionEnabled = noop, SetPropagateMouseMotion = noop,
    SetPassThroughButtons = noop, HasAccessConstraints = no, HasAnyForbiddenAspects = no,
}
function Frame:GetHitRectInsets() return 0, 0, 0, 0 end
function Frame:GetName() return self.name end
function Frame:SetID(id) self.id = id end
function Frame:GetID() return self.id end
function Frame:SetAllPoints(anchor) self.anchor = anchor end
function Frame:SetMouseClickEnabled(enabled) self.mouseClicks = enabled end
function Frame:RegisterForClicks(...) self.clicks = {...} end
function Frame:RegisterForDrag(button) self.dragButton = button end
function Frame:RegisterEvent(event) self.events[event] = true end
function Frame:SetAttribute(key, value) self.attributes[key] = value end
function Frame:GetScript(script) return self.scripts[script] end
function Frame:SetScript(script, handler) self.scripts[script] = handler end
function Frame:Click(button, down)
    for _, script in ipairs({'PreClick', 'OnClick', 'PostClick'}) do
        local handler = self:GetScript(script)
        if handler then handler(self, button, down) end
    end
end
function Frame:HookScript(script, handler)
    local previous = self.scripts[script]
    self.scripts[script] = function(...)
        if previous then previous(...) end
        handler(...)
    end
end
function Frame:IsShown() return self.shown end
function Frame:SetShown(shown)
    if self.shown == shown then return end
    self.shown = shown
    local handler = self:GetScript(shown and 'OnShow' or 'OnHide')
    if handler then handler(self) end
end
function Frame:Hide() self:SetShown(false) end

local function createFrame(_, name, parent, template)
    local frame = setmetatable({ name = name, parent = parent, template = template, shown = true,
        events = {}, scripts = {}, attributes = {}, BagIndicator = { SetShown = noop } }, { __index = Frame })
    if template and template:find('SecureActionButtonTemplate', 1, true) then
        -- Stand in for the template's own OnClick. An addon replacing its
        -- script must go through the replacement, just as in the client.
        frame:SetScript('OnClick', function(self, button, down)
            local attributes = self.attributes
            assert(attributes.type == 'click' and attributes.clickbutton, 'missing native click target')
            assert(attributes.useOnKeyDown == false and not down, 'expected a mouse-up action')
            local target = attributes.clickbutton
            target:Click(button, down)
        end)
    end
    frames[#frames + 1] = frame
    return frame
end

local combined = createFrame('Frame', 'ContainerFrameCombinedBags')
function combined:EnumerateValidItems() return noop end
local bank = createFrame('Frame', 'BankFrame')
local backpack = createFrame('Button', 'MainMenuBarBackpackButton')
local keyring = createFrame('Button', 'KeyRingButton')
local reagent = createFrame('Button', 'CharacterReagentBag0Slot')
reagent:SetID(24) -- An equipment slot, distinct from container 5.
local reagentWindow = createFrame('Frame', 'ContainerFrame1')
reagentWindow:SetID(5)
reagentWindow:Hide()
combined:Hide()
bank:Hide()
local bankOpenedBags
bank:SetScript('OnShow', function()
    bankOpenedBags = not combined:IsShown()
    if bankOpenedBags then combined:SetShown(true) end
end)
bank:SetScript('OnHide', function() if bankOpenedBags then combined:Hide() end end)
for _, slot in ipairs({keyring, reagent}) do
    slot:SetScript('OnClick', function(self)
        assert(cursor, 'empty-cursor click opened the separate ' .. self.name .. ' window')
        self.received = cursor
    end)
end

local allBagsKeys = {'F8', 'CTRL-J'}
local overrides, callbacks, drivers = {}, {}, {}
local function applyDriver(frame, state, rule)
    -- The fixture has no held modifier. The first [combat] group wins if present.
    local value = combat and rule:match('^%[combat%][^%s;]*%s+([^%s;]+)')
    value = value or rule:match('([^; ]+)%s*$')
    if state == 'visibility' then
        assert(value == 'show' or value == 'hide')
        frame:SetShown(value == 'show')
    else
        assert(state == 'combat' and frame.template == 'SecureHandlerStateTemplate')
        local body = assert(frame.attributes['_onstate-' .. state])
        local handler = assert(loadstring('local self, stateid, newstate = ...; ' .. body))
        setfenv(handler, {})(frame, state, tonumber(value) or value)
    end
end
local env = setmetatable({
    Enum = { BagIndex = {Backpack = 0, Keyring = -1, ReagentBag = 5}, ForbiddenAspect = {ScriptedInput = 1} },
    CreateFrame = createFrame, InCombatLockdown = function() return combat end, KeybindFrames_InQuickKeybindMode = no,
    IsModifiedClick = no, ContainerFrame_AllowedToOpenBags = yes,
    GetCursorInfo = function() return cursor and 'item' end,
    C_AddOns = { IsAddOnLoaded = no }, C_CVar = { GetCVarBool = yes },
    C_Timer = {After = noop},
    C_Container = { GetContainerNumSlots = function() return 1 end },
    EventRegistry = {RegisterCallback = function(_, event, handler, owner)
        callbacks[event] = callbacks[event] or {}
        callbacks[event][owner] = handler
    end}, UpdateContainerFrameAnchors = noop,
    ToggleBackpack_Combined = function() combined:SetShown(not combined:IsShown()) end,
    ContainerFrameUtil_GetShownFrameForID = function(id)
        if id == 0 and combined:IsShown() then return combined end
        if id == 5 and reagentWindow:IsShown() then return reagentWindow end
    end,
    ContainerFrameCombinedBags = combined, BankFrame = bank, MainMenuBarBackpackButton = backpack,
    KeyRingButton = keyring, CharacterReagentBag0Slot = reagent,
    RegisterStateDriver = function(frame, state, rule)
        drivers[frame] = {state, rule}
        applyDriver(frame, state, rule)
    end,
    UnregisterStateDriver = function(frame) drivers[frame] = nil end,
}, {__index = _G})
env._G = env
reagentWindow:HookScript('OnShow', function(window)
    for owner, handler in pairs(callbacks['ContainerFrame.OpenBag'] or {}) do handler(owner, window) end
end)
env.IsBagOpen = function(id) return env.ContainerFrameUtil_GetShownFrameForID(id) ~= nil end
env.GetBindingKey = function(action)
    if action == 'OPENALLBAGS' then return unpack(allBagsKeys) end
end
env.GetBindingAction = function(key, checkOverrides)
    if checkOverrides and overrides[key] then return overrides[key].action end
    for _, bound in ipairs(allBagsKeys) do if key == bound then return 'OPENALLBAGS' end end
    return ''
end
env.SetOverrideBinding = function(owner, _, key, action)
    assert(not combat, 'addon changed a protected binding in combat')
    overrides[key] = action and {owner = owner, action = action} or nil
end
local function clearBindings(owner)
    for key, binding in pairs(overrides) do
        if binding.owner == owner then overrides[key] = nil end
    end
end
function Frame:ClearBindings() clearBindings(self) end -- Restricted state-driver method.
env.ClearOverrideBindings = function(owner)
    assert(not combat, 'addon cleared protected bindings in combat')
    clearBindings(owner)
end
env.ToggleBackpack = function() env.ToggleBackpack_Combined() end
env.ToggleAllBags = function()
    -- Forever's ToggleAllBags counts the backpack and the equipped reagent bag
    -- separately in combined mode. It reopens both if either one was closed.
    local allOpen = combined:IsShown() and reagentWindow:IsShown()
    combined:Hide()
    reagentWindow:Hide()
    if not allOpen then
        combined:SetShown(true)
        reagentWindow:SetShown(true)
    end
end
env.hooksecurefunc = function(name, after)
    local original = assert(env[name], name)
    env[name] = function(...) original(...); after(...) end
end
local backpackClicks = 0
backpack:SetScript('OnClick', function()
    assert(not cursor, 'an item on the cursor was sent to the backpack')
    backpackClicks = backpackClicks + 1
    env.ToggleBackpack_Combined()
end)
for _, fn in ipairs({'OpenBackpack', 'CloseBackpack', 'OpenBag', 'CloseBag', 'OpenAllBags', 'CloseAllBags'}) do
    env[fn] = function() error('FlareUI called ' .. fn .. ' directly during the bank scenario') end
end

local ns = {L = {}, modules = {}, BagModuleOn = yes, db = {profile = {tweaks = {bagKeyring = true, bagReagent = true}}}}
setfenv(assert(loadstring(H.read('Modules/Bags.lua'), '@Modules/Bags.lua')), env)('FlareUI', ns)
ns.Bags.AddSlotArt = noop
ns.Bags:Init()

local function hit(slot)
    for i = #frames, 1, -1 do
        local child = frames[i]
        if child.parent == slot and child.anchor == slot and child.mouseClicks and child:IsShown() then return child end
    end
    return slot
end

local function click(slot)
    local target = hit(slot)
    if target ~= slot then
        assert(target.clicks and table.concat(target.clicks, ' '):find('LeftButtonUp', 1, true),
            'the overlay must accept a physical left-button release')
    end
    target:Click('LeftButton', false)
end

local function bankScenario(slot)
    click(slot)
    assert(combined:IsShown() and backpackClicks == 1, 'slot failed to open the combined backpack exactly once')
    bank:SetShown(true)
    bank:Hide()
    assert(combined:IsShown(), 'first bank visit closed bags opened by the player')
    combined:Hide() -- Close the backpack with its X before the second visit.
    bank:SetShown(true)
    assert(combined:IsShown(), 'second bank visit failed to open the closed backpack')
    bank:Hide()
    assert(not combined:IsShown(), 'second bank visit left its bags open')
    click(backpack)
    click(slot)
    assert(not combined:IsShown() and backpackClicks == 3, 'slot failed to close the combined backpack exactly once')
end

local function allBagsKeyScenario(slot)
    local actions = {
        OPENALLBAGS = function() env.ToggleAllBags() end,
        TOGGLEBACKPACK = function() env.ToggleBackpack() end,
    }
    local function pressKey(key)
        local binding = env.GetBindingAction(key, true)
        local action = assert(actions[binding], 'unhandled binding ' .. binding)
        action()
    end
    local function fireEvent(event)
        for _, frame in ipairs(frames) do
            if frame.events[event] then frame:GetScript('OnEvent')(frame, event) end
        end
    end
    local function setCombat(inCombat)
        combat = inCombat
        for frame, driver in pairs(drivers) do applyDriver(frame, unpack(driver)) end
        fireEvent(inCombat and 'PLAYER_REGEN_DISABLED' or 'PLAYER_REGEN_ENABLED')
    end

    local first, second = unpack(allBagsKeys)
    click(slot)
    assert(combined:IsShown(), slot:GetName() .. ' did not open the combined backpack')
    pressKey(first)
    assert(not combined:IsShown(), 'first Open All Bags keypress after ' .. slot:GetName() .. ' left the backpack open')
    assert(not reagentWindow:IsShown(), 'closing the backpack left the reagent bag open')
    pressKey(first)
    assert(combined:IsShown() and reagentWindow:IsShown(), 'second Open All Bags keypress must reopen both bags')
    pressKey(first)

    click(backpack)
    pressKey(second)
    assert(combined:IsShown() and reagentWindow:IsShown(), 'a native backpack click must keep the native Open All Bags action')
    pressKey(second)

    click(slot)
    combined:Hide() -- The X closes the combined frame without another click on the slot.
    assert(env.GetBindingAction(first, true) == 'OPENALLBAGS', 'closing with X left a stale override')

    local otherOwner = {}
    env.SetOverrideBinding(otherOwner, false, first, 'TOGGLEWORLDMAP')
    click(slot)
    assert(env.GetBindingAction(first, true) == 'TOGGLEWORLDMAP', 'slot stole a key from another override')
    pressKey(second)
    assert(not combined:IsShown(), 'the second assigned key failed to close the window')
    assert(env.GetBindingAction(first, true) == 'TOGGLEWORLDMAP', 'closing removed another override')
    env.ClearOverrideBindings(otherOwner)

    click(slot)
    allBagsKeys[1] = 'ALT-K'
    fireEvent('UPDATE_BINDINGS')
    assert(env.GetBindingAction(first, true) == '', 'the old key remained overridden after rebinding')
    pressKey('ALT-K')
    assert(not combined:IsShown(), 'the newly assigned key failed to close the window')

    click(slot)
    reagentWindow:SetShown(true)
    pressKey(second)
    assert(not combined:IsShown() and not reagentWindow:IsShown(), 'opening the separate bag must restore native closure of both')

    click(slot)
    setCombat(true)
    assert(env.GetBindingAction(second, true) == 'OPENALLBAGS', 'temporary override survived entering combat')
    setCombat(false)
    pressKey(second)
    assert(not combined:IsShown(), 'the still-open window failed to close after leaving combat')
end

local function checkItemOnCursor(slot, item)
    cursor = item
    for _, frame in ipairs(frames) do
        if frame.events.CURSOR_CHANGED then frame:GetScript('OnEvent')(frame, 'CURSOR_CHANGED') end
    end
    click(slot)
    assert(slot.received == item, 'the native bag slot must receive the item on the cursor')
end

return { bankScenario = bankScenario, allBagsKeyScenario = allBagsKeyScenario,
    checkItemOnCursor = checkItemOnCursor, hit = hit, keyring = keyring, reagent = reagent }
