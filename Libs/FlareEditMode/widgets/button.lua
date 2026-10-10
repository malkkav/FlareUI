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
