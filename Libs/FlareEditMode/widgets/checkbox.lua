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

local checkboxMixin = {}
function checkboxMixin:Setup(data)
	self.setting = data
	self.Label:SetText(data.name)
	self:Refresh()

	local value = data.get(lib:GetActiveLayoutName())
	if value == nil then
		value = data.default
	end

	self.checked = value
	self.Button:SetChecked(not not value) -- force boolean
end

function checkboxMixin:Refresh()
	local data = self.setting
	if type(data.disabled) == 'function' then
		self:SetEnabled(not data.disabled(lib:GetActiveLayoutName()))
	else
		self:SetEnabled(not data.disabled)
	end

	if type(data.hidden) == 'function' then
		self:SetShown(not data.hidden(lib:GetActiveLayoutName()))
	else
		self:SetShown(not data.hidden)
	end
end

function checkboxMixin:OnCheckButtonClick()
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	self.checked = not self.checked
	self.setting.set(lib:GetActiveLayoutName(), not not self.checked, false)

	lib.internal:GetDialogOf(self):RefreshWidgets()
end

function checkboxMixin:SetEnabled(enabled)
	self.Button:SetEnabled(enabled)
	self.Label:SetTextColor((enabled and WHITE_FONT_COLOR or DISABLED_FONT_COLOR):GetRGB())
end

lib.internal:CreatePool(lib.SettingType.Checkbox, function()
	local frame = CreateFrame('Frame', nil, UIParent, 'EditModeSettingCheckboxTemplate')
	frame:SetScript('OnLeave', DefaultTooltipMixin.OnLeave)
	frame:SetScript('OnEnter', showTooltip)
	frame.FlareUI_DarkTooltips = true -- FlareUI: opaque tooltip (Settings/Panel.lua)
	frame.Button:SetPropagateMouseMotion(true)
	return Mixin(frame, checkboxMixin)
end, function(_, frame)
	frame:Hide()
	frame.layoutIndex = nil
end)
