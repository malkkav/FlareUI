-- A small WoW UI double for settings interactions. Geometry can be assigned by tests.
-- Drawing calls without an effect on interaction are accepted by a fixed allowlist.
local Fixture = {}
local Widget = {}
Widget.__index = Widget

local function noop() end
local function show(self, value)
    if self.shown ~= value then
        self.shown = value
        self:RunScript(value and "OnShow" or "OnHide")
    end
end

function Widget:Show() show(self, true) end
function Widget:Hide() show(self, false) end
function Widget:SetShown(value) show(self, not not value) end
function Widget:IsShown() return self.shown end
function Widget:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function Widget:GetObjectType() return self.kind end
function Widget:IsObjectType(kind)
    if self.kind == kind then return true end
    if kind == "Button" then return self.kind == "CheckButton" or self.kind == "DropdownButton" end
    return kind == "Frame" and not self.region
end

function Widget:SetParent(parent)
    local list = self.region and "regions" or "children"
    if self.parent then
        for i, child in ipairs(self.parent[list]) do
            if child == self then table.remove(self.parent[list], i) break end
        end
    end
    self.parent = parent
    if parent then table.insert(parent[list], self) end
end
function Widget:GetParent() return self.parent end
function Widget:GetChildren() return unpack(self.children) end
function Widget:GetRegions() return unpack(self.regions) end
function Widget:GetName() return self.name end

function Widget:SetScript(key, callback) self.scripts[key] = callback end
function Widget:GetScript(key) return self.scripts[key] end
function Widget:HookScript(key, callback)
    self.hooks[key] = self.hooks[key] or {}
    table.insert(self.hooks[key], callback)
end
function Widget:RunScript(key, ...)
    if self.scripts[key] then self.scripts[key](self, ...) end
    for _, callback in ipairs(self.hooks[key] or {}) do callback(self, ...) end
end
function Widget:RegisterEvent(event) self.events[event] = true end
function Widget:RegisterUnitEvent(event) self.events[event] = true end
function Widget:UnregisterEvent(event) self.events[event] = nil end
function Widget:UnregisterAllEvents() self.events = {} end
function Widget:IsEventRegistered(event) return self.events[event] == true end
function Widget:RegisterCallback(event, callback, owner)
    self.callbacks[event] = self.callbacks[event] or {}
    table.insert(self.callbacks[event], { callback = callback, owner = owner })
end
function Widget:TriggerEvent(event, ...)
    for _, entry in ipairs(self.callbacks[event] or {}) do entry.callback(entry.owner, ...) end
end

function Widget:SetPoint(point, ...)
    for i, old in ipairs(self.points) do
        if old[1] == point then self.points[i] = { point, ... }; return end
    end
    self.points[#self.points + 1] = { point, ... }
end
function Widget:ClearAllPoints() self.points = {} end
function Widget:SetAllPoints(target) self.allPoints = target or self.parent end
function Widget:GetPoint(index) return unpack(self.points[index or 1] or {}) end
function Widget:GetNumPoints() return #self.points end
function Widget:SetSize(width, height) self.width, self.height = width, height end
function Widget:SetWidth(width) self.width = width end
function Widget:SetHeight(height) self.height = height end
function Widget:GetWidth() return self.width or (self.allPoints and self.allPoints:GetWidth()) or 400 end
function Widget:GetHeight() return self.height or (self.allPoints and self.allPoints:GetHeight()) or 400 end
function Widget:GetSize() return self:GetWidth(), self:GetHeight() end
function Widget:GetTop() return self.top or 500 end
function Widget:GetBottom() return self.bottom or (self:GetTop() - self:GetHeight()) end
function Widget:GetLeft() return self.left or 0 end
function Widget:GetRight() return self.right or (self:GetLeft() + self:GetWidth()) end
function Widget:GetCenter() return (self:GetLeft() + self:GetRight()) / 2, (self:GetBottom() + self:GetTop()) / 2 end
function Widget:SetScale(value) self.scale = value end
function Widget:GetScale() return self.scale or 1 end
function Widget:GetEffectiveScale() return self:GetScale() * (self.parent and self.parent:GetEffectiveScale() or 1) end
function Widget:SetFrameLevel(value) self.frameLevel = value end
function Widget:GetFrameLevel() return self.frameLevel or ((self.parent and self.parent:GetFrameLevel() or 0) + 1) end
function Widget:SetFrameStrata(value) self.strata = value end
function Widget:GetFrameStrata() return self.strata or "MEDIUM" end
function Widget:SetAlpha(value) self.alpha = value end
function Widget:GetAlpha() return self.alpha or 1 end
function Widget:IsForbidden() return false end
function Widget:EnableMouse(value) self.mouseEnabled = value end
function Widget:IsMouseEnabled() return self.mouseEnabled ~= false end
function Widget:IsMouseOver() return self.mouseOver == true end
function Widget:EnableKeyboard(value) self.keyboardEnabled = value end
function Widget:EnableGamePadButton(value) self.gamepadEnabled = value end
function Widget:SetPropagateKeyboardInput(value) self.propagate = value end
function Widget:SetEnabled(value)
    local old = self:IsEnabled()
    self.enabled = not not value
    if old ~= self.enabled then self:RunScript(self.enabled and "OnEnable" or "OnDisable") end
end
function Widget:IsEnabled() return self.enabled ~= false end
function Widget:Disable() self:SetEnabled(false) end
function Widget:Enable() self:SetEnabled(true) end
function Widget:SetChecked(value) self.checked = not not value end
function Widget:GetChecked() return self.checked == true end
function Widget:Click(button)
    if not self:IsEnabled() then return end
    if self.kind == "CheckButton" then self:SetChecked(not self:GetChecked()) end
    self:RunScript("PreClick", button or "LeftButton")
    self:RunScript("OnClick", button or "LeftButton")
    self:RunScript("PostClick", button or "LeftButton")
end

function Widget:SetText(value)
    self.textValue = value == nil and "" or tostring(value)
    if self.textObject then self.textObject:SetText(self.textValue) end
    if self.kind == "EditBox" then self:RunScript("OnTextChanged", false) end
end
function Widget:GetText() return self.textValue or (self.textObject and self.textObject:GetText()) or "" end
function Widget:SetFormattedText(format, ...) self:SetText(format:format(...)) end
function Widget:SetFont(path, size, flags) self.font = { path, size, flags }; return true end
function Widget:GetFont() return unpack(self.font or { "Fonts\\FRIZQT__.TTF", 12, "" }) end
function Widget:SetFontObject(value) self.fontObject = value end
function Widget:GetFontObject() return self.fontObject end
function Widget:SetFontString(font) self.textObject = font end
function Widget:GetFontString()
    if not self.textObject then
        self.textObject = self:CreateFontString()
        self.textObject:SetText(self:GetText())
    end
    return self.textObject
end
function Widget:GetUnboundedStringWidth() return #self:GetText() * 6 end
function Widget:GetStringWidth() return self:GetUnboundedStringWidth() end
function Widget:GetNumLines() return math.max(1, math.ceil(self:GetStringWidth() / math.max(1, self:GetWidth()))) end
function Widget:GetStringHeight() return self:GetText() == "" and 0 or self:GetNumLines() * 12 end
function Widget:SetTextColor(...) self.textColor = { ... } end
function Widget:GetTextColor() return unpack(self.textColor or { 1, 1, 1, 1 }) end
function Widget:SetFocus() self.focus = true; self:RunScript("OnEditFocusGained") end
function Widget:ClearFocus()
    if self.focus then self.focus = false; self:RunScript("OnEditFocusLost") end
end
function Widget:HasFocus() return self.focus == true end

function Widget:SetScrollChild(child) self.scrollChild = child end
function Widget:GetScrollChild() return self.scrollChild end
function Widget:GetVerticalScrollRange()
    return self.scrollChild and math.max(0, self.scrollChild:GetHeight() - self:GetHeight()) or 0
end
function Widget:GetVerticalScroll() return self.verticalScroll or 0 end
function Widget:SetVerticalScroll(offset)
    local old = self:GetVerticalScroll()
    self.verticalScroll = math.max(0, math.min(offset, self:GetVerticalScrollRange()))
    if old ~= self.verticalScroll then self:RunScript("OnVerticalScroll", self.verticalScroll) end
end
function Widget:UpdateScrollChildRect() self:RunScript("OnScrollRangeChanged", 0, self:GetVerticalScrollRange()) end
function Widget:SetScrollPercentage(value, silent)
    self.scrollPercentage = value
    if not silent then self:TriggerEvent("OnScroll", value) end
end

function Widget:SetValue(value)
    local old = self.value
    self.value = value
    if old ~= value then self:RunScript("OnValueChanged", value) end
end
function Widget:GetValue() return self.value or 0 end
function Widget:SetMinMaxValues(low, high) self.minValue, self.maxValue = low, high end
function Widget:GetMinMaxValues() return self.minValue or 0, self.maxValue or 1 end
function Widget:SetTexture(path) self.texture = path; return true end
function Widget:GetTexture() return self.texture end
function Widget:SetAtlas(atlas) self.atlas = atlas; return true end
function Widget:GetAtlas() return self.atlas end
function Widget:SetCooldown(start, duration) self.cooldown = { start, duration } end
function Widget:SetStatusBarTexture(path)
    if not self.barTexture then self.barTexture = self:CreateTexture() end
    self.barTexture:SetTexture(path)
end
function Widget:GetStatusBarTexture() return self.barTexture end
function Widget:SetStatusBarColor(...) self.barColor = { ... } end
function Widget:GetStatusBarColor() return unpack(self.barColor or { 1, 1, 1, 1 }) end
function Widget:SetReverseFill(value) self.reverseFill = value end
function Widget:GetReverseFill() return self.reverseFill == true end
function Widget:SetBackdrop(value) self.backdrop = value end
function Widget:GetBackdrop() return self.backdrop end
function Widget:SetBackdropColor(...) self.backdropColor = { ... } end
function Widget:GetBackdropColor() return unpack(self.backdropColor or { 1, 1, 1, 1 }) end
function Widget:SetBackdropBorderColor(...) self.backdropBorderColor = { ... } end
function Widget:GetBackdropBorderColor() return unpack(self.backdropBorderColor or { 1, 1, 1, 1 }) end
function Widget:SetAttribute(key, value) self.attributes[key] = value end
function Widget:GetAttribute(key) return self.attributes[key] end

for _, state in ipairs({ "Normal", "Highlight", "Pushed", "Disabled", "Checked", "DisabledChecked" }) do
    Widget["Set" .. state .. "Texture"] = function(self, value)
        if type(value) == "string" then
            local texture = self:CreateTexture()
            texture:SetTexture(value)
            value = texture
        end
        self[state .. "Texture"] = value
    end
    Widget["Get" .. state .. "Texture"] = function(self) return self[state .. "Texture"] end
    Widget["Set" .. state .. "FontObject"] = function(self, value) self[state .. "Font"] = value end
    Widget["Get" .. state .. "FontObject"] = function(self) return self[state .. "Font"] end
end

local function widget(ui, kind, name, parent, template, region)
    local result = setmetatable({
        ui = ui, kind = kind, name = name, template = template, region = region, shown = true,
        children = {}, regions = {}, scripts = {}, hooks = {}, events = {}, callbacks = {}, points = {}, attributes = {},
    }, Widget)
    result:SetParent(parent)
    table.insert(ui.widgets, result)
    if name then ui.env[name] = result end
    return result
end

function Widget:CreateTexture(name) return widget(self.ui, "Texture", name, self, nil, true) end
function Widget:CreateMaskTexture(name) return widget(self.ui, "MaskTexture", name, self, nil, true) end
function Widget:CreateFontString(name, _, font)
    local label = widget(self.ui, "FontString", name, self, font, true)
    label:SetFontObject(font)
    return label
end
function Widget:CreateAnimationGroup() return widget(self.ui, "AnimationGroup", nil, self, nil, true) end
function Widget:CreateAnimation(kind) return widget(self.ui, kind, nil, self, nil, true) end
function Widget:Play() self.playing = true end
function Widget:Stop() self.playing = false end
function Widget:IsPlaying() return self.playing == true end
function Widget:SetupMenu(build) self.menuBuilder = build end
function Widget:OverrideText(text) self:SetText(text) end
function Widget:SetDefaultText(text) self:SetText(text) end
function Widget:SetOwner(owner, anchor) self.owner, self.anchor = owner, anchor end
function Widget:GetOwner() return self.owner end
function Widget:AddLine(text) self.lines = self.lines or {}; table.insert(self.lines, text) end

for method in ([[
AddMaskTexture Clear EnableMouseMotion EnableMouseWheel HighlightText LockHighlight Lower Raise RegisterForClicks RegisterForDrag
SetAutoFocus SetBlendMode SetClampRectInsets SetClampedToScreen SetClipsChildren SetColorTexture SetDesaturated
SetDrawBling SetDrawEdge SetDrawLayer SetDuration SetFromAlpha SetGradient SetHideCountdownNumbers SetHighlightFontObject
SetHideIfUnscrollable SetHitRectInsets SetHorizTile SetHyperlinksEnabled SetJustifyH SetJustifyV SetMaxLetters SetMaxLines SetClipsChildren
SetMotionScriptsWhileDisabled SetMovable SetNormalAtlas SetObeyStepOnDrag SetOrder SetPanExtentPercentage
SetPropagateKeyboardInput SetPushedAtlas SetRotation SetShadowColor SetShadowOffset SetSpacing SetSwipeColor SetSwipeTexture
SetTexCoord SetTextScale SetTextureSliceMargins SetTextureSliceMode SetToAlpha SetToplevel SetValueStep SetVertTile
SetVertexColor SetVisibleExtentPercentage SetWordWrap StartMoving StopMovingOrSizing UpdateStepperStates
SetSnapToPixelGrid SetTexelSnappingBias SetSmoothing SetOffset SetOrigin SetEndDelay UnlockHighlight
]]):gmatch("%S+") do
    if not Widget[method] then Widget[method] = noop end
end

local Menu = {}
Menu.__index = Menu
function Menu:CreateButton(text, pick, data)
    local entry = setmetatable({ text = text, pick = pick, data = data, entries = {} }, Menu)
    self.entries[#self.entries + 1] = entry
    return entry
end
function Menu:CreateRadio(text, selected, pick, data)
    local entry = self:CreateButton(text, pick, data)
    entry.selected = selected
    return entry
end
Menu.CreateCheckbox = Menu.CreateRadio
function Menu:CreateDivider() self.entries[#self.entries + 1] = { divider = true } end
function Menu:CreateTitle(text) self.entries[#self.entries + 1] = { title = text } end
function Menu:SetOnEnter(callback) self.onEnter = callback end
function Menu:SetOnLeave(callback) self.onLeave = callback end
function Menu:SetScrollMode(height) self.scrollHeight = height end
function Menu:AddInitializer(callback) self.initializer = callback end

function Widget:GenerateMenu()
    self.menu = setmetatable({ entries = {} }, Menu)
    if self.menuBuilder then self.menuBuilder(self, self.menu) end
    if not self.disableSelectionText then
        for _, entry in ipairs(self.menu.entries) do
            if entry.selected and entry.selected(entry.data) then self:SetText(entry.text); break end
        end
    end
    return self.menu
end

function Widget:OpenMenu() self.menuOpen = true; return self:GenerateMenu() end
function Widget:CloseMenu() self.menuOpen = false; self:TriggerEvent("OnMenuClose") end
function Widget:IsMenuOpen() return self.menuOpen == true end

local UI = {}
UI.__index = UI
function UI:load(path, ns) return setfenv(assert(loadfile(path)), self.env)("FlareUI", ns) end
function UI:find(predicate)
    for _, frame in ipairs(self.widgets) do if predicate(frame) then return frame end end
end
function UI:emit(event, ...)
    for _, frame in ipairs(self.widgets) do
        if frame.events[event] then frame:RunScript("OnEvent", event, ...) end
    end
end
function UI:flushTimers()
    local pending = self.timers
    self.timers = {}
    for _, timer in ipairs(pending) do if not timer.cancelled then timer.callback() end end
end

function Fixture.new()
    local ui = setmetatable({ widgets = {}, timers = {}, sounds = {}, errors = {} }, UI)
    local env = setmetatable({}, { __index = _G })
    ui.env = env
    env._G, env.UISpecialFrames = env, {}
    env.UIParent = widget(ui, "Frame", "UIParent")
    env.UIParent:SetSize(1920, 1080)
    env.CreateFrame = function(kind, name, parent, template)
        local frame = widget(ui, kind, name, parent, template)
        if template and template:find("NewFeatureLabel", 1, true) then
            frame.Label, frame.BGLabel, frame.Glow = frame:CreateFontString(), frame:CreateFontString(), frame:CreateTexture()
            frame.Label:SetText("New")
        end
        if template and template:find("UIPanelButtonTemplate", 1, true) then
            for _, state in ipairs({ "Normal", "Highlight", "Pushed", "Disabled" }) do frame["Set" .. state .. "Texture"](frame, state) end
        end
        if kind == "DropdownButton" then
            frame.Arrow = frame:CreateTexture()
            frame.Text = frame:CreateFontString()
            frame:SetFontString(frame.Text)
        end
        if template == "MinimalSliderWithSteppersTemplate" then
            frame.Slider = widget(ui, "Slider", nil, frame)
            frame.Back = widget(ui, "Button", nil, frame)
            frame.Forward = widget(ui, "Button", nil, frame)
        end
        if template == "SearchBoxTemplate" then
            frame.Instructions = frame:CreateFontString()
        end
        if template == "UIRadioButtonTemplate" then
            frame.text = frame:CreateFontString()
        end
        if template == "ScrollFrameTemplate" then
            frame.ScrollBar = widget(ui, "EventFrame", nil, frame)
        end
        return frame
    end
    env.CreateFont = function(name) return widget(ui, "Font", name) end
    env.C_AddOns = { GetAddOnMetadata = function() return "7.0.4" end }
    env.CreateColor = function(r, g, b, a)
        return {
            r = r, g = g, b = b, a = a,
            GetRGB = function() return r, g, b end,
            GetRGBA = function() return r, g, b, a end,
            WrapTextInColorCode = function(_, text) return text end,
        }
    end
    env.GRAY_FONT_COLOR = env.CreateColor(0.5, 0.5, 0.5, 1)
    env.NORMAL_FONT_COLOR = env.CreateColor(1, 0.82, 0, 1)
    env.HIGHLIGHT_FONT_COLOR = env.CreateColor(1, 1, 1, 1)
    env.GameTooltip = widget(ui, "GameTooltip", "GameTooltip", env.UIParent)
    env.GameTooltip:Hide()
    env.GameTooltip_Hide = function() env.GameTooltip:Hide() end
    env.GameTooltip_SetTitle = function(tooltip, title) tooltip:SetText(title) end
    env.GameTooltip_AddNormalLine = function(tooltip, line) tooltip:AddLine(line) end
    env.UIErrorsFrame = { AddMessage = function(_, message) table.insert(ui.errors, message) end }
    env.InCombatLockdown = function() return ui.combat == true end
    env.IsShiftKeyDown = function() return ui.shift == true end
    env.IsControlKeyDown = function() return ui.control == true end
    env.IsAltKeyDown = function() return ui.alt == true end
    env.GetTime = function() return ui.time or 100 end
    env.GetCursorPosition = function() return ui.cursorX or 0, ui.cursorY or 0 end
    env.ExecuteFrameScript = function(frame, key, ...) frame:RunScript(key, ...) end
    env.PlaySound = function(id, channel) table.insert(ui.sounds, { id, channel }) end
    env.SOUNDKIT = setmetatable({}, { __index = function(_, key) return key end })
    env.DropdownButtonMixin = { Event = { OnMenuClose = "OnMenuClose" } }
    env.geterrorhandler = function() return function(err) error(err, 0) end end
    env.tinsert, env.tremove, env.sort = table.insert, table.remove, table.sort
    env.wipe = function(t) for key in pairs(t) do t[key] = nil end; return t end
    local function CopyTable(t)
        local copy = {}
        for key, value in pairs(t) do copy[key] = type(value) == "table" and CopyTable(value) or value end
        return copy
    end
    env.CopyTable = CopyTable
    env.strtrim = function(s) return (s:gsub("^%s*(.-)%s*$", "%1")) end
    env.strsplit = function(separator, value)
        local result, start = {}, 1
        while true do
            local found = value:find(separator, start, true)
            if not found then result[#result + 1] = value:sub(start); break end
            result[#result + 1] = value:sub(start, found - 1)
            start = found + #separator
        end
        return unpack(result)
    end
    env.hooksecurefunc = function(target, key, callback)
        if type(target) == "string" then target, key, callback = env, target, key end
        local original = assert(target[key], key)
        target[key] = function(...)
            local results = { original(...) }
            callback(...)
            return unpack(results)
        end
    end
    env.C_Timer = {
        After = function(_, callback) table.insert(ui.timers, { callback = callback }) end,
        NewTicker = function(_, callback)
            local timer = { callback = callback, Cancel = function(self) self.cancelled = true end }
            table.insert(ui.timers, timer)
            return timer
        end,
    }
    return ui
end

return Fixture
