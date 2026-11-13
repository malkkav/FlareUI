local _, ns = ...
local lib
if ns.FlareEditMode then
	lib = ns.FlareEditMode
else
	local MINOR, prevMinor = 15
	lib, prevMinor = LibStub('FlareEditMode')
	if prevMinor > MINOR then
		return
	end
end

local function showTooltip(self)
	if self.setting and self.setting.desc then
		SettingsTooltip:SetOwner(self, 'ANCHOR_NONE')
		SettingsTooltip:SetPoint('BOTTOMRIGHT', self, 'TOPLEFT')
		SettingsTooltip:SetText(self.setting.name, 1, 1, 1)
		SettingsTooltip:AddLine(self.setting.desc, nil, nil, nil, true) -- FlareUI: wrapped
		SettingsTooltip:Show()
		-- FlareUI: an opaque background, easier to read over the game world
		if SettingsTooltip.NineSlice and SettingsTooltip.NineSlice.SetCenterColor then SettingsTooltip.NineSlice:SetCenterColor(0, 0, 0, 1) end
	end
end

local buttonMixin = {}
function buttonMixin:Setup(data)
	-- unsure if this has any effect
	self.setting = data
end

lib.internal:CreatePool('button', function()
	local button = CreateFrame('Button', nil, UIParent, 'EditModeSystemSettingsDialogExtraButtonTemplate')
	button:SetScript('OnLeave', DefaultTooltipMixin.OnLeave)
	button:SetScript('OnEnter', showTooltip)
	button.FlareUI_DarkTooltips = true -- FlareUI: opaque tooltip (Settings/Panel.lua)
	return Mixin(button, buttonMixin)
end, function(_, button)
	button:Hide()
	button.layoutIndex = nil
end)

-- FlareUI addition (11-13): a row of buttons inside the settings list, centred side by side.
-- data.buttons = { { text = "...", click = function() end, disabled = function() return bool end, desc = "..." } }
lib.SettingType.Buttons = 'buttons'

local GAP = 16
local HEIGHT = 32

local function showRowTooltip(self)
	local data = self.button
	if data and data.desc then
		SettingsTooltip:SetOwner(self, 'ANCHOR_NONE')
		SettingsTooltip:SetPoint('BOTTOMRIGHT', self, 'TOPLEFT')
		SettingsTooltip:SetText(data.text, 1, 1, 1)
		SettingsTooltip:AddLine(data.desc, nil, nil, nil, true)
		SettingsTooltip:Show()
		if SettingsTooltip.NineSlice and SettingsTooltip.NineSlice.SetCenterColor then SettingsTooltip.NineSlice:SetCenterColor(0, 0, 0, 1) end
	end
end

local buttonsMixin = {}
function buttonsMixin:Setup(data)
	self.setting = data
	local defs = data.buttons or {}
	local width = data.buttonWidth or 150
	local total = #defs * width + math.max(0, #defs - 1) * GAP
	for i, def in ipairs(defs) do
		local b = self.buttons[i]
		if not b then
			b = CreateFrame('Button', nil, self, 'EditModeSystemSettingsDialogButtonTemplate')
			b:SetHeight(22)
			b:SetScript('OnClick', function(button)
				if button.button and button.button.click then button.button.click() end
				lib.internal:GetDialogOf(self):RefreshWidgets()
			end)
			b:SetScript('OnEnter', showRowTooltip)
			b:SetScript('OnLeave', DefaultTooltipMixin.OnLeave)
			b:SetMotionScriptsWhileDisabled(true)
			self.buttons[i] = b
		end
		b.button = def
		b:SetText(def.text)
		b:SetWidth(width)
		b:ClearAllPoints()
		b:SetPoint('LEFT', self, 'CENTER', -total / 2 + (i - 1) * (width + GAP), 0)
		b:Show()
	end
	for i = #defs + 1, #self.buttons do self.buttons[i]:Hide() end
	self:Refresh()
end

function buttonsMixin:Refresh()
	local data = self.setting
	if type(data.hidden) == 'function' then
		self:SetShown(not data.hidden(lib:GetActiveLayoutName()))
	else
		self:SetShown(not data.hidden)
	end
	for _, b in ipairs(self.buttons) do
		local def = b.button
		if def and b:IsShown() then
			b:SetEnabled(not (def.disabled and def.disabled(lib:GetActiveLayoutName())))
		end
	end
end

lib.internal:CreatePool(lib.SettingType.Buttons, function()
	local frame = Mixin(CreateFrame('Frame', nil, UIParent), buttonsMixin)
	frame:SetSize(330, HEIGHT)
	frame.fixedHeight = HEIGHT
	frame.align = 'center'
	frame.buttons = {}
	return frame
end, function(_, frame)
	frame:Hide()
	frame.layoutIndex = nil
end)
