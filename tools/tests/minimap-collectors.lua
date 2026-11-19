-- Run from the repository root: luajit tools/tests/minimap-collectors.lua
-- Exercise the real drawer with minimap and collector frame doubles.
local function setup(options)
    options = options or {}
    local now, timers, frames, combat = 0, {}, {}, false
    function InCombatLockdown() return combat end
    C_Timer = { After = function(delay, fn) timers[#timers + 1] = { time = now + delay, fn = fn } end }
    local function advance(seconds)
        local limit = now + seconds
        while true do
            table.sort(timers, function(a, b) return a.time < b.time end)
            if not timers[1] or timers[1].time > limit then break end
            local timer = table.remove(timers, 1)
            now = timer.time
            timer.fn()
        end
        now = limit
    end

    local Frame = {}; Frame.__index = Frame
    function Frame:SetParent(parent)
        if self.parent then
            for i, child in ipairs(self.parent.children) do
                if child == self then table.remove(self.parent.children, i); break end
            end
        end
        self.parent = parent
        if parent then parent.children[#parent.children + 1] = self end
    end
    function Frame:GetParent() return self.parent end
    function Frame:GetChildren() return unpack(self.children) end
    function Frame:GetName() return self.name end
    function Frame:IsObjectType(kind) return self.kind == kind end
    function Frame:IsForbidden() return self.forbidden or false end
    function Frame:IsProtected() return self.protected or false end
    function Frame:GetRegions() end
    function Frame:GetSize() return self.width, self.height end
    function Frame:SetSize(w, h) self.width, self.height = w, h end
    function Frame:GetWidth() return self.width end
    function Frame:GetHeight() return self.height end
    function Frame:GetCenter() return 0, 0 end
    function Frame:GetScale() return 1 end
    function Frame:GetEffectiveScale() return 1 end
    function Frame:GetScript(event) return self.scripts[event] end
    function Frame:SetScript(event, fn) self.scripts[event] = fn end
    function Frame:GetFrameLevel() return self.level end
    function Frame:SetFrameLevel(level) self.level = level end
    function Frame:SetFrameStrata(strata) self.strata = strata end
    function Frame:SetClampedToScreen() end
    function Frame:EnableMouse() end
    function Frame:SetBackdrop() end
    function Frame:SetBackdropColor() end
    function Frame:SetBackdropBorderColor() end
    function Frame:SetAllPoints() end
    function Frame:SetPoint() end
    function Frame:ClearAllPoints() end
    function Frame:SetText(text) self.text = text end
    function Frame:RegisterForClicks() end
    function Frame:RegisterEvent(event) self.events[event] = true end
    function Frame:UnregisterEvent(event) self.events[event] = nil end
    function Frame:IsShown() return self.shown end
    function Frame:Show() self.shown = true end
    function Frame:Hide() self.shown = false end
    function Frame:SetShown(shown) self.shown = shown end
    function Frame:CreateFontString() return CreateFrame('FontString', nil, self) end
    function Frame:Click() if self.scripts.OnClick then self.scripts.OnClick(self, 'LeftButton') end end
    function CreateFrame(kind, name, parent)
        local frame = setmetatable({ kind = kind, name = name, shown = true, width = 32, height = 32,
            level = 1, children = {}, scripts = {}, events = {} }, Frame)
        frame:SetParent(parent)
        if name then _G[name] = frame end
        frames[#frames + 1] = frame
        return frame
    end
    function hooksecurefunc(object, method, callback)
        local original = assert(object[method], method)
        object[method] = function(...)
            local result = { original(...) }
            callback(...)
            return unpack(result)
        end
    end
    function wipe(t) for k in pairs(t) do t[k] = nil end return t end
    tinsert = table.insert
    UISpecialFrames = {}
    UIParent, Minimap = CreateFrame('Frame'), CreateFrame('Frame')
    MinimapBackdrop, MinimapCluster = CreateFrame('Frame'), CreateFrame('Frame')
    MinimapCluster.DielFrame = CreateFrame('Frame', nil, MinimapCluster)
    AddonCompartmentFrame = nil
    C_AddOns = { IsAddOnLoaded = function() return options.oneForAll or false end,
        GetAddOnTitle = function() return nil end }
    _G.OneForAllDB = options.oneForAll and { qol = { mmCollect = true } } or nil
    _G.EnhanceQoL = nil
    _G.HidingBarAddon = nil

    local iconFrames, objects = {}, {}
    local ldb = { GetDataObjectByName = function(_, name) return objects[name] end }
    local lib = {
        GetButtonList = function() local names = {}; for name in pairs(iconFrames) do names[#names + 1] = name end; return names end,
        GetMinimapButton = function(_, name) return iconFrames[name] end,
    }
    function LibStub(name)
        if name == 'LibDBIcon-1.0' then return lib end
        if name == 'LibDataBroker-1.1' then return ldb end
        if name == 'LibSharedMedia-3.0' then return { Fetch = function() end, IsValid = function() return false end } end
    end
    local ns = { L = setmetatable({}, { __index = function(_, k) return k end }),
        db = { profile = { minimap = { buttonBag = options.enabled ~= false, bagLeave = options.leave or {} } } },
        Minimap = {}, BORDER_COLOR = { r = 1, g = 1, b = 1, a = 1 }, BorderEdgeSize = function() return 16 end,
        CopyStrata = function() end }
    local function button(name, parent, onClick)
        local frame = CreateFrame('Button', name, parent or Minimap)
        frame:SetScript('OnClick', onClick or function() end)
        return frame
    end
    local function icon(name, parent)
        local frame = button('LibDBIcon10_' .. name, parent)
        iconFrames[name] = frame
        objects[name] = { label = name, icon = 1, type = 'launcher' }
        return frame
    end
    local function enhance()
        local eq = { db = { enableMinimapButtonBin = true, unrelatedSetting = 'preserved' },
            variables = { buttonSink = CreateFrame('Frame'), bagButtons = {}, bagButtonState = {}, bagButtonPoint = {} }, functions = {} }
        eq.variables.buttonSink:Hide()
        function eq.functions.gatherMinimapButtons()
            for _, child in ipairs({ Minimap:GetChildren() }) do
                if child:IsObjectType('Button') and child:GetName() and child:IsShown() then
                    local name = child:GetName():gsub('^LibDBIcon10_', '')
                    eq.variables.bagButtons[name], eq.variables.bagButtonState[name] = child, true
                    eq.variables.bagButtonPoint[name] = { point = 'CENTER' }
                end
            end
        end
        function eq.functions.LayoutButtons()
            for name, frame in pairs(eq.variables.bagButtons) do
                if eq.variables.bagButtonState[name] then frame:SetParent(eq.variables.buttonSink); frame:Show()
                else frame:Hide() end
            end
        end
        _G.EnhanceQoL = eq
        return eq
    end
    local function hidingBar()
        local hb = { minimapButtons = {}, btnParams = {}, manuallyButtons = {}, bar = CreateFrame('Frame') }
        function hb:addMButton(frame, manual)
            self.btnParams[frame] = { parent = frame:GetParent(), isShown = frame:IsShown() }
            self.minimapButtons[#self.minimapButtons + 1] = frame
            if manual then self.manuallyButtons[frame] = true end
            frame:SetParent(self.bar)
            -- HidingBar blocks SetParent on captured buttons until removeMButton restores it.
            frame.SetParent = function() end
        end
        function hb:removeMButton(frame)
            local params = assert(self.btnParams[frame])
            for i, button in ipairs(self.minimapButtons) do
                if frame == button then table.remove(self.minimapButtons, i); break end
            end
            frame.SetParent = nil
            frame:SetParent(params.parent)
            self.btnParams[frame] = nil
        end
        _G.HidingBarAddon = hb
        return hb
    end
    local function load()
        assert(loadfile('Modules/MinimapBag.lua'))('FlareUI', ns)
        ns.MinimapBag:Init()
        return ns.MinimapBag
    end
    local function event(name)
        for _, frame in ipairs(frames) do
            if frame.events[name] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, name) end
        end
    end
    local function hasChoice(bag, label)
        for _, choice in ipairs(bag.AddonChoices()) do if choice[2] == label then return true end end
        return false
    end
    return { advance = advance, button = button, icon = icon, enhance = enhance, hidingBar = hidingBar, load = load,
        event = event, hasChoice = hasChoice, ns = ns, setCombat = function(value) combat = value end }
end

-- EnhanceQoL loaded first and already gathered the buttons, including a LibDBIcon.
do
    local clicks = 0
    local s = setup({ leave = { ['frame:ExcludedButton'] = true, ['ldb:ExcludedLib'] = true } })
    local eq = s.enhance()
    local cast = s.button('NeonCastMinimapButton', nil, function() clicks = clicks + 1 end)
    local omen = s.button('NeonOmenRebornMinimapButton')
    local excluded = s.button('ExcludedButton')
    local protected = s.button('ProtectedButton'); protected.protected = true
    local pin = s.button('QuestiePin1')
    local icon = s.icon('TestLib')
    local excludedIcon = s.icon('ExcludedLib')
    eq.functions.gatherMinimapButtons(); eq.functions.LayoutButtons()
    local bag = s.load()
    local panel = _G.FlareUI_MinimapBag
    assert(cast:GetParent() == panel and omen:GetParent() == panel,
        'both Neon buttons already in EnhanceQoL must enter the FlareUI drawer')
    assert(s.hasChoice(bag, 'NeonCastMinimapButton') and s.hasChoice(bag, 'NeonOmenRebornMinimapButton'),
        'both Neon buttons must be offered in the drawer settings')
    assert(icon:GetParent() ~= eq.variables.buttonSink, 'a selected LibDBIcon must be held by FlareUI')
    assert(excluded:GetParent() == eq.variables.buttonSink and excludedIcon:GetParent() == eq.variables.buttonSink,
        'buttons excluded from the FlareUI drawer must remain with EnhanceQoL')
    assert(protected:GetParent() == eq.variables.buttonSink and pin:GetParent() == eq.variables.buttonSink,
        'protected frames and map pins must not be taken')
    eq.functions.LayoutButtons()
    assert(cast:GetParent() == panel and omen:GetParent() == panel and icon:GetParent() ~= eq.variables.buttonSink,
        'a later EnhanceQoL layout must not reclaim FlareUI buttons')
    cast:Click(); assert(clicks == 1, 'a transferred button must keep its click handler')
    assert(eq.db.enableMinimapButtonBin and eq.db.unrelatedSetting == 'preserved',
        'EnhanceQoL saved settings must stay unchanged')
end

-- A button collected after startup also needs to transfer, including when EnhanceQoL loads late.
do
    local s = setup()
    local bag = s.load()
    s.advance(5)
    local eq = s.enhance()
    s.event('ADDON_LOADED'); s.advance(0.5)
    bag.GetCatcher = function() end
    _G.FlareUI_MinimapBag:Show()
    local late = s.button('LateMinimapButton')
    eq.functions.gatherMinimapButtons(); eq.functions.LayoutButtons()
    s.advance(0)
    assert(late:GetParent() == _G.FlareUI_MinimapBag and s.hasChoice(bag, 'LateMinimapButton'),
        'a later EnhanceQoL gather must add newly created buttons to an already open FlareUI drawer')
    eq.functions.LayoutButtons()
    assert(late:GetParent() == _G.FlareUI_MinimapBag, 'later layouts must leave the transferred button alone')
end

-- HidingBar uses a different ownership mechanism: it blocks frame methods until it releases a button.
do
    local s = setup({ leave = { ['frame:ExcludedButton'] = true } })
    local hb = s.hidingBar()
    local ordinary = s.button('AnotherAddonMinimapButton')
    local libIcon = s.icon('AnotherLib')
    local excluded = s.button('ExcludedButton')
    local manual = s.button('ManuallyCapturedButton')
    local otherUI = s.button('OtherUIControl', UIParent)
    local hidden = s.button('HiddenButton'); hidden:Hide()
    hb:addMButton(ordinary); hb:addMButton(libIcon); hb:addMButton(excluded); hb:addMButton(manual, true)
    hb:addMButton(otherUI); hb:addMButton(hidden)
    local bag = s.load()
    assert(ordinary:GetParent() == _G.FlareUI_MinimapBag and s.hasChoice(bag, 'AnotherAddonMinimapButton'),
        'buttons captured by another collector must be released into the FlareUI drawer')
    assert(libIcon:GetParent() ~= hb.bar, 'a collected LibDBIcon must also be released into FlareUI')
    assert(excluded:GetParent() == hb.bar and manual:GetParent() == hb.bar and otherUI:GetParent() == hb.bar
        and hidden:GetParent() == hb.bar and not hidden:IsShown(),
        'excluded, manually captured, hidden and non-minimap buttons must remain with the other collector')
    assert(not hb.btnParams[ordinary] and not hb.btnParams[libIcon], 'released buttons must no longer be controlled by HidingBar')
end

do
    local s = setup()
    local bag = s.load()
    s.advance(5)
    local hb = s.hidingBar()
    s.event('ADDON_LOADED'); s.advance(0.5)
    local late = s.button('LateOtherButton')
    s.setCombat(true)
    hb:addMButton(late); s.advance(0)
    assert(late:GetParent() == hb.bar, 'handoff from HidingBar must wait until combat ends')
    s.setCombat(false); s.event('PLAYER_REGEN_ENABLED'); s.advance(0.5)
    assert(late:GetParent() == _G.FlareUI_MinimapBag and s.hasChoice(bag, 'LateOtherButton'),
        'a late collector must release its buttons after combat')
end

-- The compatibility behavior is inactive when the drawer is off or OneForAll owns buttons.
for _, options in ipairs({ { enabled = false }, { oneForAll = true } }) do
    local s = setup(options)
    local eq = s.enhance()
    local other = s.button('OtherButton')
    eq.functions.gatherMinimapButtons(); eq.functions.LayoutButtons()
    s.load(); s.advance(5)
    eq.functions.LayoutButtons()
    assert(other:GetParent() == eq.variables.buttonSink, 'other collectors must keep their buttons when FlareUI does not take them')
end

print('PASS: collectors hand minimap buttons to the FlareUI drawer without changing saved settings')
