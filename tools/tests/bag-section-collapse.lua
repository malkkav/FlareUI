local H = dofile('tools/tests/perf-helpers.lua')
local function noop() end
local function no() return false end
local function yes() return true end
local frames = {}
local Widget = {}
Widget.__index = Widget
local function widget(kind, name, parent, templates)
    local f = setmetatable({parent = parent, shown = true, scripts = {}, events = {}}, Widget)
    local slotTemplate = templates and (',' .. templates .. ','):match(',%s*ContainerFrameItemButtonTemplate%s*,')
    f.itemSlot = kind == 'ItemButton' or (kind == 'Button' and slotTemplate ~= nil)
    if f.itemSlot then f.BagIndicator = widget('Texture', nil, f); f.BagIndicator:Hide() end
    if slotTemplate then
        f.fallbackSlot = true
        f.BattlepayItemTexture = widget('Texture', nil, f) -- Stock XML starts shown.
    end
    frames[#frames + 1] = f
    return f
end
function Widget:IsShown() return self.shown end
function Widget:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function Widget:SetShown(shown)
    if self.shown == shown then return end
    self.shown = shown
    local handler = self.scripts[shown and 'OnShow' or 'OnHide']
    if handler then handler(self) end
end
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
function Widget:SetHasItem(hasItem) self.hasItem = hasItem end
function Widget:SetBagID(id) self.bagID = id end
function Widget:Initialize(container, bag, slot)
    assert(self.fallbackSlot and bag == 5)
    self.container = container
    self:SetBagID(bag)
    self:SetID(slot)
    self:Show()
end
function Widget:GetBagID() return self.bagID or self.parent.id end
function Widget:GetBagSize() return #self.Items end
function Widget:SetPoint(...) self.point = {...} end
function Widget:GetPoint() if self.point then return unpack(self.point, 1, 5) end end
function Widget:ClearAllPoints() self.point = nil end
function Widget:SetScale(scale) self.scale = scale end
function Widget:GetScale() return self.scale or 1 end
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
for _, name in ipairs({'SetTexture', 'SetAtlas', 'SetTextColor',
        'SetAllPoints', 'SetTexCoord', 'SetRotation', 'SetJustifyH', 'SetFrameLevel', 'SetNormalTexture',
        'SetHighlightTexture', 'RegisterForClicks', 'SetVertexColor', 'SetWordWrap', 'EnableMouse', 'SetAlpha',
        'SetClampedToScreen'}) do Widget[name] = noop end
function Widget:IsClampedToScreen() return true end
function Widget:GetFrameLevel() return 1 end
Widget.IsProtected = no

local combined, items, Bags, native, windows
local db = {bagView = 'rows', bagKeyring = true, bagReagent = true}
local bagSizes = {[-1] = 2, [0] = 5, [5] = 2}
local contents = {[1] = {itemID = 101}, [2] = {itemID = 102}}
local keyringAvailable, secured = true, true
local lastKeySlot = 1
local env = setmetatable({
    CreateFrame = widget, InCombatLockdown = no,
    SetItemButtonTexture = noop, SetItemButtonCount = noop, SetItemButtonDesaturated = noop,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    C_AddOns = {IsAddOnLoaded = function(name) return name == 'Hide2FABagSlots' end},
    C_Timer = {After = function(_, callback) callback() end},
    C_NewItems = {RemoveNewItem = noop},
    C_CVar = {GetCVarBool = yes}, C_ActionBar = {ShouldShowKeyring = function() return keyringAvailable end},
    GetKeyRingSize = function() return math.min(4 * math.ceil(lastKeySlot / 4), bagSizes[-1]) end,
    IsAccountSecured = function() return secured end, EventRegistry = {RegisterCallback = noop},
    C_Container = {
        GetContainerNumSlots = function(id) return bagSizes[id] or 0 end,
        GetContainerItemInfo = function(id, slot)
            if id == 0 then return contents[slot] end
            if id == -1 and slot == lastKeySlot then return {itemID = 103} end
        end,
    },
    Enum = {BagIndex = {Keyring = -1, ReagentBag = 5}, ItemQuality = {Poor = 0},
        ItemClass = {Weapon = 2, Armor = 4, Consumable = 0, Tradegoods = 7}},
    C_Item = {GetItemInfoInstant = function(id) return id, nil, nil, nil, nil, id == 101 and 0 or 7 end},
}, {__index = _G})
env._G = env
env.UIParent = widget('Frame')
function env.ContainerFrameUtil_GetShownFrameForID(id)
    local window = windows[id]
    if window and window:IsShown() then return window end
end
function env.hooksecurefunc(target, method, hook)
    if type(target) == 'string' then target, method, hook = env, target, method end
    local previous = assert(target[method], method)
    target[method] = function(...) previous(...); hook(...) end
end
local function startSession(char, bagsClosed)
    frames, items, native, windows = {}, {}, {}, {}
    combined = widget('Frame', nil, env.UIParent)
    if bagsClosed then combined:Hide() end
    combined.MoneyFrame = widget('Frame', nil, combined)
    -- Capture each widget when the simulated client creates it, before loading FlareUI.
    for id = -1, 5 do
        local separate = id == -1 or id == 5
        local bag = combined
        native[id] = {}
        if separate then
            bag = widget('Frame', nil, env.UIParent)
            bag:SetID(id)
            bag:SetSize(178, 80)
            if bagsClosed then bag:Hide() end
            windows[id] = bag
            bag.Items = {}
            bag.ClearItems, bag.UpdateItemSlots, bag.UpdateItemLayout = noop, noop, noop
        end
        local count = id == -1 and env.GetKeyRingSize() or bagSizes[id] or 0
        for slot = 1, count do
            local button = widget('ItemButton', nil, bag)
            button.bagID = id
            button:SetID(slot)
            button:SetSize(36, 36)
            native[id][slot] = button
            if separate then bag.Items[slot] = button else items[#items + 1] = button end
        end
    end
    items[5].extended = true
    function combined:EnumerateValidItems() return ipairs(items) end
    combined.UpdateItemLayout = noop
    combined.SetItemsMatchingBagHighlighted = noop
    function combined:GetPaddingWidth() return 8 end
    function combined:GetPaddingHeight() return 20 end
    function combined:CalculateExtraHeight() return 30 end
    env.ContainerFrameCombinedBags, env.UpdateContainerFrameAnchors = combined, noop
    env.ContainerFrame1, env.ContainerFrame2 = windows[5], windows[-1]
    combined:SetScript('OnHide', function() env.UpdateContainerFrameAnchors() end)

    local ns = {L = setmetatable({}, {__index = function(_, key) return key end}), modules = {},
        db = {profile = {tweaks = db}}, CharDB = function() return char end, BagModuleOn = yes, IsGamepadUI = no}
    env.FlareTestNS = ns
    setfenv(assert(loadstring(H.read('Modules/Bags.lua'), '@Modules/Bags.lua')), env)('FlareUI', ns)
    Bags = ns.Bags
    Bags.DecorateButton, Bags.PlaceBagButtons, Bags.FollowWindows = noop, noop, noop
    Bags.StyleMoney, Bags.StyleFreeSlots, Bags.GoldList.Hook, Bags.Bank.Hook, Bags.Sort.Hook = noop, noop, noop, noop, noop
    Bags:Init()
    env.UpdateContainerFrameAnchors()
end
startSession({})

local function layout() env.UpdateContainerFrameAnchors(); combined:UpdateItemLayout() end
local function fireBagEvent(event)
    for _, f in ipairs(frames) do
        if f.events[event] then f.scripts.OnEvent(f, event) end
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
        if b.itemSlot and b:GetBagID() == id and b:IsVisible() then
            local parent = b:GetParent()
            if parent == combined or parent:GetParent() == combined then n = n + 1 end
        end
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
fireBagEvent('BAG_UPDATE_DELAYED')
assert(items[2]:IsShown() and not visibleHeader('Materials'), 'new contents moved into expanded Consumables')
contents[2] = {itemID = 102}
fireBagEvent('BAG_UPDATE_DELAYED')
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

-- The combined backpack owns bags 0-4. The keyring and crafting bag each have a separate native
-- window and button pool. An ordinary backpack click opens neither window. Open All Bags opens 5.
do
    for id = 1, 4 do bagSizes[id] = 2 end
    bagSizes[5] = 12 -- Catch prototypes that only create a few slots.
    bagSizes[-1] = 32 -- The keyring initially provides four actual buttons for these 32 possible slots.
    db.bagKeyring, db.bagReagent = true, true
    startSession({}, true)

    local pending, opens = {}, {[-1] = 0, [5] = 0}
    local keyPool = {unpack(native[-1])}
    env.C_Timer.After = function(_, callback) pending[#pending + 1] = callback end
    local function nextFrame()
        local callbacks = pending
        pending = {}
        for _, callback in ipairs(callbacks) do callback() end
    end
    local function openNative(id)
        windows[id]:Show()
        env.UpdateContainerFrameAnchors()
    end
    function env.OpenBag(id, force)
        assert(id ~= 5, 'FlareUI must not OpenBag(5): the next bank open can taint bankType')
        assert(windows[id] and not env.InCombatLockdown())
        opens[id] = opens[id] + 1
        if id == -1 and force then
            local window = windows[id]
            window:ClearItems()
            local count = env.GetKeyRingSize()
            for slot = #window.Items, count + 1, -1 do
                window.Items[slot]:Hide()
                window.Items[slot], native[id][slot] = nil, nil
            end
            for slot = 1, count do
                local b = keyPool[slot] or widget('ItemButton', nil, window)
                assert(b:GetParent() == window, 'pooled key slot not returned to its window')
                b.bagID = id
                b:SetID(slot)
                b:Show()
                keyPool[slot], window.Items[slot], native[id][slot] = b, b, b
            end
        end
        openNative(id)
    end
    function env.CloseBag(id)
        assert(windows[id] and not env.InCombatLockdown())
        windows[id]:Hide()
        env.UpdateContainerFrameAnchors()
    end
    local function closeBags()
        combined:Hide()
        for _, window in pairs(windows) do window:Hide() end
        env.UpdateContainerFrameAnchors()
    end
    local function openBackpack()
        combined:Show()
        layout()
    end
    local function checkSlots(keyringVisible, reagentVisible)
        -- A native window owns its pool even when fallback slots exist. The fallback
        -- section is only visible when the Blizzard reagent window is not open.
        local fallback = {}
        for _, b in ipairs(frames) do
            if b.itemSlot then
                local id, slot = b:GetBagID(), b:GetID()
                if b.fallbackSlot then
                    assert(id == 5 and b.container == combined and not fallback[slot] and slot <= bagSizes[5])
                    fallback[slot] = true
                    assert(b:IsVisible() == (reagentVisible and not windows[5]:IsShown()), 'duplicate or missing fallback slot')
                    assert(not b.BattlepayItemTexture:IsShown(), 'default blue overlay leaked into reagent slots')
                elseif id == -1 and not native[id][slot] and keyPool[slot] == b then
                    assert(not b:IsShown() and b:GetParent() == windows[id], 'released key slot still in use')
                else
                    assert(native[id] and native[id][slot] == b,
                        ('substitute item button for bag %s slot %s'):format(tostring(id), tostring(slot)))
                end
            end
        end
        for slot = 1, bagSizes[5] do assert(fallback[slot], 'missing template reagent slot ' .. slot) end
        for id = -1, 5 do
            local window = windows[id]
            local expected = id == -1 and keyringVisible or id == 5 and reagentVisible and windows[5]:IsShown()
            assert(#native[id] > 0, 'missing native fixture for bag ' .. id)
            for slot, b in ipairs(native[id]) do
                local parent = b:GetParent()
                assert(b:GetBagID() == id and b:GetID() == slot, 'native item button changed slot')
                if not window then
                    assert(parent == combined and b:IsVisible() == combined:IsShown())
                else
                    assert(window.Items[slot] == b)
                    local embedded = parent:GetParent() == combined
                    if embedded then assert(parent:GetID() == id, 'native slot in the wrong section') end
                    assert((embedded and b:IsVisible()) == expected,
                        ('unexpected backpack visibility for bag %d slot %d'):format(id, slot))
                    if not window:IsShown() then assert(parent == window, 'native button not returned') end
                end
            end
        end
    end

    for i = 1, 2 do
        closeBags()
        openBackpack()
        checkSlots(false, true)
        nextFrame()
        checkSlots(true, true)
        assert(opens[5] == 0 and opens[-1] == i, 'ordinary open must never open native bag 5')
    end
    -- (11-24) the fallback slots are dressed as the others: Blizzard's parts, then FlareUI's overlay
    do
        local slots, decorated, qualities, removed = {}, {}, {}, {}
        for _, b in ipairs(frames) do if b.fallbackSlot and b:IsVisible() then slots[b:GetID()] = b end end
        local first, decorate, remove = slots[1], Bags.DecorateButton, env.C_NewItems.RemoveNewItem
        local quest, cooldown, glow
        function first:UpdateQuestItem(isQuest, id) quest = isQuest and id end
        function first:UpdateCooldown(texture) cooldown = texture end
        function first:UpdateNewItem() error('a value the game hides') end
        function first:UpdateJunkItem(quality) glow = quality end
        local read = env.C_Container.GetContainerItemInfo
        env.C_Container.GetContainerItemInfo = function(id, slot)
            if id == 5 and slot == 1 then return {itemID = 500, iconFileID = 77, quality = 2, hyperlink = 'link'} end
            return read(id, slot)
        end
        env.C_Container.GetContainerItemQuestInfo = function() return {isQuestItem = true, questID = 9} end
        env.SetItemButtonQuality = function(b, quality, link) qualities[b] = {quality, link} end
        Bags.DecorateButton = function(b, config, info, bagID, slot) decorated[slot] = {b, config, info, bagID} end
        for _, event in ipairs({'BAG_NEW_ITEMS_UPDATED', 'INVENTORY_SEARCH_UPDATE'}) do
            decorated, cooldown = {}, nil
            fireBagEvent(event)
            assert(decorated[1][1] == first and decorated[1][2] == db and decorated[1][3].itemID == 500 and decorated[1][4] == 5)
            assert(decorated[12] and decorated[12][3] == nil, 'an empty slot keeps its look too')
            assert(qualities[first][1] == 2 and qualities[first][2] == 'link' and quest == 9 and cooldown == 77 and glow == 2)
        end
        -- a cooldown event (often in a fight) draws the cooldowns alone
        decorated, cooldown = {}, nil
        env.C_Container.HasContainerItem = function(id, slot) return id == 5 and slot == 1 end
        fireBagEvent('BAG_UPDATE_COOLDOWN')
        assert(cooldown == true and not next(decorated))
        env.C_Container.HasContainerItem = nil
        -- pointing aside, closing the backpack clears their new item glow, as for Blizzard's windows
        env.C_NewItems.RemoveNewItem = function(id, slot) removed[id .. ':' .. slot] = true end
        local scripts = combined.scripts.OnHide
        assert(scripts, 'the backpack clears new items as it closes')
        combined:Hide()
        assert(removed['5:1'] and removed['5:12'])
        env.C_NewItems.RemoveNewItem, Bags.DecorateButton = remove, decorate
        env.C_Container.GetContainerItemInfo, env.C_Container.GetContainerItemQuestInfo, env.SetItemButtonQuality = read, nil, nil
        nextFrame()
        openBackpack()
        nextFrame()
        checkSlots(true, true)
    end
    for _, highlight in ipairs({true, false}) do
        combined:SetItemsMatchingBagHighlighted(5, highlight)
        for _, b in ipairs(frames) do
            if b.fallbackSlot and b:IsVisible() then
                assert(b.BagIndicator:IsShown() == highlight, 'hover highlight must follow the reagent bag')
            end
        end
    end
    combined:Hide()
    assert(not windows[-1]:IsShown(), 'Toggle All Bags would count the automatically opened keyring')
    nextFrame()
    assert(not windows[-1]:IsShown() and not windows[5]:IsShown(), 'backpack left its own windows open')

    -- Each native window keeps its own owner even when the other one belongs to FlareUI.
    for _, id in ipairs({5, -1}) do
        closeBags()
        local before = opens[id]
        if id == 5 then
            openBackpack()
            openNative(id) -- Blizzard opens bag 5 after the backpack during Open All Bags.
        else
            openNative(id)
            assert(native[id][1]:IsVisible() and native[id][1]:GetParent() == windows[id],
                'opening the keyring on its own hid its buttons')
            openBackpack()
        end
        nextFrame()
        checkSlots(true, true)
        assert(opens[id] == before, 'reopened a native window already supplied by the game')
        combined:Hide()
        assert(windows[id]:IsShown(), 'hiding the backpack synchronously closed a player-owned bag')
        nextFrame()
        assert(windows[id]:IsShown() and not windows[id == 5 and -1 or 5]:IsShown(),
            'closing the backpack must close only the window it opened')
        if id == -1 then
            assert(native[id][1]:IsVisible() and native[id][1]:GetParent() == windows[id],
                'closing the backpack did not restore the independently opened keyring')
        end
    end

    openBackpack()
    nextFrame()
    checkSlots(true, true)
    for _, name in ipairs({keys, reagents}) do click(name) end
    checkSlots(false, false)
    closeBags()
    openBackpack()
    nextFrame()
    checkSlots(false, false)
    click(keys)
    nextFrame()
    checkSlots(true, false)
    click(reagents)
    nextFrame()
    checkSlots(true, true)

    -- Only the native bag API can rebuild the open keyring's pool after its contents change.
    local keyring = windows[-1]
    assert(#keyring.Items == 4)
    for _, last in ipairs({9, 1}) do
        lastKeySlot = last
        local before = opens[-1]
        fireBagEvent('BAG_UPDATE_DELAYED')
        nextFrame()
        nextFrame()
        assert(#keyring.Items == env.GetKeyRingSize(), 'native keyring did not resize after a bag update')
        assert(opens[-1] == before + 1, 'resizing should rebuild the native keyring once')
        checkSlots(true, true)
    end

    closeBags()
    openBackpack()
    closeBags()
    nextFrame()
    assert(not windows[-1]:IsShown() and not windows[5]:IsShown(), 'queued open ran after backpack closed')
    checkSlots(false, false)
    env.InCombatLockdown = yes
    openBackpack()
    nextFrame()
    checkSlots(false, true)
    env.InCombatLockdown = no
    fireBagEvent('PLAYER_REGEN_ENABLED')
    nextFrame()
    checkSlots(true, true)

    openNative(5)
    native[5][1].IsProtected, native[-1][1].IsProtected = yes, yes
    env.InCombatLockdown = yes
    closeBags()
    for id, window in pairs(windows) do
        assert(native[id][1]:GetParent() ~= window, 'protected button moved during combat')
    end
    env.InCombatLockdown = no
    fireBagEvent('PLAYER_REGEN_ENABLED')
    nextFrame()
    checkSlots(false, false)

    openBackpack()
    openNative(5)
    nextFrame()
    db.bagReagent, db.bagKeyring = false, false
    Bags:Refresh()
    nextFrame()
    assert(windows[5]:IsShown() and not keyring:IsShown(), 'disabling the options lost window ownership')
    checkSlots(false, false)

    db.bagReagent, db.bagKeyring = true, true
    Bags:Refresh()
    closeBags()
    openBackpack()
    nextFrame()
    checkSlots(true, true)
    openNative(5)
    -- (11-23, suorat4an) its buttons went back to a window still kept off screen: taken again
    Bags.ReturnExtraButtons(windows[5])
    Bags:Refresh()
    nextFrame()
    checkSlots(true, true)
    -- one window that fails never keeps the other from its section
    do
        local logged, hook = 0, Bags.HookBagWindow
        env.FlareTestNS.LogError = function() logged = logged + 1 end
        Bags.HookBagWindow = function(frame) if frame == keyring then error('broken window') end return hook(frame) end
        Bags.ReturnExtraButtons(windows[5])
        env.UpdateContainerFrameAnchors()
        nextFrame()
        assert(logged > 0)
        checkSlots(true, true)
        Bags.HookBagWindow = hook
    end
    db.bagReagent = false
    Bags:Refresh()
    nextFrame()
    assert(windows[5]:IsShown(), 'disabling the section must preserve the native window')
    checkSlots(true, false)

    -- In Blizzard's stacked layout the next window's right edge follows the one below it.
    openNative(5)
    local function rightOffset(frame)
        if frame == env.UIParent then return 0 end
        local _, relative, _, x = frame:GetPoint(1)
        return rightOffset(relative) + x
    end
    for i = 1, 2 do
        keyring:SetPoint('BOTTOMRIGHT', env.UIParent, 'BOTTOMRIGHT', -40, 10)
        windows[5]:SetPoint('BOTTOMRIGHT', keyring, 'TOPRIGHT', 0, 5)
        env.UpdateContainerFrameAnchors()
        assert(rightOffset(windows[5]) == -40, 'parking the keyring moved the separate crafting bag')
    end
    local anchor = select(2, windows[5]:GetPoint(1))
    windows[5].IsProtected, env.InCombatLockdown = yes, yes
    db.bagKeyring = false
    Bags:Refresh()
    assert(select(2, windows[5]:GetPoint(1)) == anchor, 'reanchored a protected separate bag in combat')
    env.InCombatLockdown = no
    fireBagEvent('PLAYER_REGEN_ENABLED')
    nextFrame()
    assert(rightOffset(windows[5]) == -40 and windows[5]:IsShown(), 'separate bag moved after combat')
    print('PASS: reagent fallback, native pool ownership, keyring, and combat transitions')
end
