local H = dofile('tools/tests/perf-helpers.lua')
local function noop() end
local function no() return false end
local function yes() return true end
local frames = {}
local Widget = {}
Widget.__index = Widget
local function widget(kind, _, parent)
    local f = setmetatable({kind = kind, parent = parent, shown = true, scripts = {}, events = {}}, Widget)
    frames[#frames + 1] = f
    return f
end
function Widget:IsShown() return self.shown end
function Widget:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function Widget:SetShown(shown) self.shown = shown end
function Widget:Hide() self:SetShown(false) end
function Widget:Show() self:SetShown(true) end
function Widget:SetParent(parent) self.parent = parent end
function Widget:GetParent() return self.parent end
function Widget:SetSize(width, height) self.width, self.height = width, height end
function Widget:GetSize() return self.width, self.height end
function Widget:GetWidth() return self.width end
function Widget:GetHeight() return self.height end
function Widget:SetHeight(height) self.height = height end
function Widget:SetWidth(width) self.width = width end
function Widget:SetText(text) self.text = text end
function Widget:SetID(id) self.id = id end
function Widget:GetID() return self.id end
function Widget:GetBagID() return self.parent.id end
function Widget:IsExtended() return self.extended end
function Widget:CreateFontString() return widget('FontString', nil, self) end
function Widget:CreateTexture() return widget('Texture', nil, self) end
function Widget:SetScript(event, handler) self.scripts[event] = handler end
function Widget:RegisterEvent(event) self.events[event] = true end
function Widget:HookScript(event, callback)
    local previous = self.scripts[event]
    self.scripts[event] = function(...)
        if previous then previous(...) end
        callback(...)
    end
end
for _, name in ipairs({'SetPoint', 'ClearAllPoints', 'SetTexture', 'SetAtlas', 'SetTextColor',
        'SetAllPoints', 'SetTexCoord', 'SetRotation', 'SetJustifyH', 'SetFrameLevel', 'SetNormalTexture',
        'SetHighlightTexture', 'RegisterForClicks', 'SetVertexColor', 'SetWordWrap', 'EnableMouse', 'SetAlpha',
        'SetClampedToScreen'}) do Widget[name] = noop end
function Widget:IsClampedToScreen() return true end
function Widget:GetFrameLevel() return 1 end
Widget.IsProtected = no

local combined, items
local db = {bagView = 'rows', bagKeyring = true, bagReagent = true}
local bagSizes = {[-1] = 2, [5] = 2}
local contents = {[1] = {itemID = 101}, [2] = {itemID = 102}}
local keyringAvailable, secured = true, true
local env = setmetatable({
    CreateFrame = widget, InCombatLockdown = no,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    C_AddOns = {IsAddOnLoaded = function(name) return name == 'Hide2FABagSlots' end},
    C_Timer = {After = function(_, callback) callback() end},
    C_CVar = {GetCVarBool = yes}, C_ActionBar = {ShouldShowKeyring = function() return keyringAvailable end},
    IsAccountSecured = function() return secured end, EventRegistry = {RegisterCallback = noop},
    C_Container = {
        GetContainerNumSlots = function(id) return bagSizes[id] or 0 end,
        GetContainerItemInfo = function(id, slot) if id == 0 then return contents[slot] end end,
    },
    Enum = {BagIndex = {Keyring = -1, ReagentBag = 5}, ItemQuality = {Poor = 0},
        ItemClass = {Weapon = 2, Armor = 4, Consumable = 0, Tradegoods = 7}},
    C_Item = {GetItemInfoInstant = function(id) return id, nil, nil, nil, nil, id == 101 and 0 or 7 end},
}, {__index = _G})
env._G = env
function env.hooksecurefunc(target, method, hook)
    if type(target) == 'string' then target, method, hook = env, target, method end
    local previous = assert(target[method], method)
    target[method] = function(...) previous(...); hook(...) end
end
local function startSession(char)
    frames = {}
    combined = widget('Frame')
    combined.MoneyFrame = widget('Frame', nil, combined)
    local bag = widget('Frame', nil, combined)
    bag:SetID(0)
    items = {}
    for slot = 1, 5 do
        items[slot] = widget('ItemButton', nil, bag)
        items[slot]:SetID(slot)
        items[slot]:SetSize(36, 36)
    end
    items[5].extended = true
    function combined:EnumerateValidItems() return ipairs(items) end
    combined.UpdateItemLayout = noop
    function combined:GetPaddingWidth() return 8 end
    function combined:GetPaddingHeight() return 20 end
    function combined:CalculateExtraHeight() return 30 end
    env.ContainerFrameCombinedBags, env.UpdateContainerFrameAnchors = combined, noop

    local ns = {L = setmetatable({}, {__index = function(_, key) return key end}), modules = {},
        db = {profile = {tweaks = db}}, CharDB = function() return char end, BagModuleOn = yes, IsGamepadUI = no}
    setfenv(assert(loadstring(H.read('Modules/Bags.lua'), '@Modules/Bags.lua')), env)('FlareUI', ns)
    local Bags = ns.Bags
    Bags.DecorateButton, Bags.PlaceBagButtons, Bags.FollowWindows = noop, noop, noop
    Bags.StyleMoney, Bags.StyleFreeSlots, Bags.GoldList.Hook, Bags.Bank.Hook, Bags.Sort.Hook = noop, noop, noop, noop, noop
    Bags:Init()
    -- Blizzard's crafting bag window, parked off the screen: its own buttons go into the backpack
    local reagentWindow = widget('Frame')
    reagentWindow:SetID(5)
    reagentWindow.Items = {}
    for slot = 1, 2 do
        local b = widget('ItemButton', nil, reagentWindow)
        b:SetID(slot)
        reagentWindow.Items[slot] = b
    end
    reagentWindow.ClearItems, reagentWindow.UpdateItemSlots, reagentWindow.UpdateItemLayout = noop, noop, noop
    env.ContainerFrame1 = reagentWindow
    env.UpdateContainerFrameAnchors()
end
startSession({})

local function layout() env.UpdateContainerFrameAnchors(); combined:UpdateItemLayout() end
local function bagUpdate()
    for _, f in ipairs(frames) do
        if f.events.BAG_UPDATE_DELAYED then f.scripts.OnEvent(f, 'BAG_UPDATE_DELAYED') end
    end
end
local function visibleHeader(text)
    for _, label in ipairs(frames) do
        if label.text == text and label:IsVisible() then
            local header = label
            while header and not header.scripts.OnClick do header = header.parent end
            return header
        end
    end
end
local function click(text)
    local h = assert(visibleHeader(text), 'missing clickable header: ' .. text)
    h.scripts.OnClick(h, 'LeftButton')
end
local function slotsVisible(id)
    local n = 0
    for _, b in ipairs(frames) do
        if b.kind == 'ItemButton' and b:GetBagID() == id and b:IsVisible() then n = n + 1 end
    end
    return n
end

local keys, reagents = 'Keyring', 'Crafting Bag'
for _, view in ipairs({'rows', 'rowsSets'}) do
    db.bagView = view
    for _, keyring in ipairs({true, false}) do
        for _, reagent in ipairs({true, false}) do
            db.bagKeyring, db.bagReagent = keyring, reagent
            layout()
            assert((visibleHeader(keys) ~= nil) == keyring, 'keyring checkbox in ' .. view)
            assert((visibleHeader(reagents) ~= nil) == reagent, 'reagent checkbox in ' .. view)
        end
    end
end
db.bagKeyring, db.bagReagent = true, true
keyringAvailable, bagSizes[5] = false, 0
layout()
assert(not visibleHeader(keys) and not visibleHeader(reagents), 'absent containers have no headers')
keyringAvailable, bagSizes[5] = true, 2
layout()
local openHeight = combined:GetHeight()
for _, name in ipairs({'Other', 'Materials', 'Consumables', keys, reagents}) do
    local before = combined:GetHeight()
    click(name)
    assert(combined:GetHeight() < before, name .. ' still uses slot rows while collapsed')
end
assert(slotsVisible(0) == 0 and slotsVisible(-1) == 0 and slotsVisible(5) == 0, 'all sections collapsed')
layout()
for _, name in ipairs({'Other', 'Materials', 'Consumables', keys, reagents}) do click(name) end
assert(combined:GetHeight() == openHeight, 'expanding restores the original size')
assert(slotsVisible(0) == 5 and slotsVisible(-1) == 2 and slotsVisible(5) == 2, 'all sections reopened')

env.C_EquipmentSet = {GetEquipmentSetIDs = function() return {7} end,
    GetEquipmentSetInfo = function() return 'Fishing' end, GetItemLocations = function() return {19} end}
env.EquipmentManager_GetLocationData = function() return {isBags = true, bag = 0, slot = 2} end
layout()
click('Fishing')
assert(not items[2]:IsShown(), 'equipment set is collapsible in rows + sets')
db.bagView = 'rows'
db.bagCombineEmpty = true
secured = false
layout()
assert(not visibleHeader('Fishing') and items[2]:IsShown(), 'ordinary category recovers slot from a folded set')
assert(slotsVisible(0) == 3, 'two filled slots plus one free slot')
click('Other')
assert(slotsVisible(0) == 2, 'folded free-space row stays hidden')
click('Other')
assert(slotsVisible(0) == 3 and not items[5]:IsShown(), 'expansion must respect combined empty and locked slots')
click('Materials')
click(keys)
for _, view in ipairs({'filters', 'all'}) do
    db.bagView = view
    layout()
    for _, name in ipairs({'Other', 'Materials', 'Consumables', keys, reagents}) do
        assert(not visibleHeader(name), 'header leaked into ' .. view .. ': ' .. name)
    end
    assert(slotsVisible(0) == 3 and slotsVisible(-1) == 2 and slotsVisible(5) == 2, 'uncategorized items restored')
end
db.bagView, db.bagCombineEmpty, db.bagKeyring, db.bagReagent = 'rows', false, false, false
layout()
if items[2]:IsShown() then click('Materials') end
contents[2] = {itemID = 101}
bagUpdate()
assert(items[2]:IsShown() and not visibleHeader('Materials'), 'new contents moved into expanded Consumables')
contents[2] = {itemID = 102}
bagUpdate()
assert(not items[2]:IsShown(), 'material folded before leaving the custom layout')
db.bagView = 'all'
layout()
assert(items[2]:IsShown() and not items[5]:IsShown(), 'native layout restores only slots owned by collapse')
assert(not visibleHeader('Materials'), 'native layout keeps no clickable category header')
print('PASS: backpack sections fold, free their rows and respect both view and container visibility')

-- Reload the addon against each character's saved data, using the same settings profile.
local firstCharacter, secondCharacter = {profileName = 'Shared'}, {profileName = 'Shared'}
db.bagView, db.bagKeyring, db.bagReagent = 'rowsSets', true, true
secured = true
local function login(character)
    startSession(character)
    layout()
end
login(firstCharacter)
assert(items[1]:IsShown() and items[2]:IsShown() and slotsVisible(-1) == 2 and slotsVisible(5) == 2,
    'existing character without saved sections starts with all sections expanded')
for _, name in ipairs({'Consumables', 'Fishing', keys, reagents}) do click(name) end
login(firstCharacter)
assert(not items[1]:IsShown() and not items[2]:IsShown() and slotsVisible(-1) == 0 and slotsVisible(5) == 0,
    'reloading restores folded categories, equipment sets, keyring and crafting bag')
assert(items[3]:IsShown(), 'unfolded sections stay expanded after reload')
click('Fishing')
click(reagents)
login(secondCharacter)
assert(items[1]:IsShown() and items[2]:IsShown() and slotsVisible(-1) == 2 and slotsVisible(5) == 2,
    'characters with the same profile keep separate fold states')
click('Other')
login(firstCharacter)
assert(not items[1]:IsShown() and items[2]:IsShown() and items[3]:IsShown()
    and slotsVisible(-1) == 0 and slotsVisible(5) == 2,
    'logging back in preserves both folded and reopened sections')
login(secondCharacter)
assert(items[1]:IsShown() and not items[3]:IsShown(), 'another character retains its own folds')
print('PASS: backpack section folds survive reload and login per character')

-- 11-21: the crafting bag section shows Blizzard's own buttons (a spell aimed at a reagent in a
-- button made by FlareUI was blocked), and they go back to their window when it stops holding the bag
do
    local window = env.ContainerFrame1
    local own = {}
    for _, b in ipairs(window.Items) do own[b] = true end
    db.bagReagent = true
    layout()
    for _, b in ipairs(frames) do
        if b.kind == 'ItemButton' and b:GetBagID() == 5 then
            assert(own[b], 'a crafting bag button FlareUI made')
            assert(b:GetParent() ~= window, 'Blizzard crafting bag button not in the backpack')
        end
    end
    db.bagReagent = false
    layout()
    for _, b in ipairs(window.Items) do assert(b:GetParent() == window, 'button not given back to its window') end
    print('PASS: the crafting bag section uses Blizzard\'s own buttons and gives them back')
end
