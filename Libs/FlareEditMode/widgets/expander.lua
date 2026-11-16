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

lib.SettingType.Expander = 'expander'

local ARROW_UP = ' |A:editmode-up-arrow:16:11:0:3|a'
local ARROW_DOWN = ' |A:editmode-down-arrow:16:11:0:-4|a'

-- FlareUI (11-16, Malkkav): the dialog decides which section is open before the widgets are set up
-- (one at a time, dialog.lua / extension.lua OpenSections). A section that is the only one in its box
-- (self.single) is a plain title, always open. A line runs above every title but the first.
local function Value(data)
	local value = data.get(lib:GetActiveLayoutName())
	if value == nil then value = data.default end
	return not not value
end

local expanderMixin = {}
function expanderMixin:Setup(data)
	self.setting = data
	self:ShowState(Value(data))
	self:Refresh()
end

function expanderMixin:Refresh()
	local data = self.setting
	if type(data.hidden) == 'function' then
		self:SetShown(not data.hidden(lib:GetActiveLayoutName()))
	else
		self:SetShown(not data.hidden)
	end
	-- another section opened: this one closed without being clicked
	local value = Value(data)
	if value ~= self.expanded then self:ShowState(value) end
end

function expanderMixin:ShowState(expanded)
	local data = self.setting
	self.expanded = expanded

	local text = data.name
	if data.expandedLabel and data.collapsedLabel then
		text = expanded and data.expandedLabel or data.collapsedLabel
	end

	if not (data.hideArrow or self.single) then
		text = text .. (expanded and ARROW_UP or ARROW_DOWN)
	end

	self.Label:SetText(text)
	self.Divider:SetShown(not self.first)
end

-- a click: open this section (and close the others), or close it
function expanderMixin:SetExpandedState(expanded)
	local data = self.setting
	data.set(lib:GetActiveLayoutName(), expanded, false)
	self:ShowState(expanded)

	local dialog = lib.internal:GetDialogOf(self)
	if dialog.SectionClicked then dialog:SectionClicked(self, expanded) end
	dialog:RefreshWidgets()
end

function expanderMixin:OnMouseUp()
	-- FlareUI: a section title that always stays open
	if self.setting.static or self.single then return end
	self:SetExpandedState(not self.expanded)
end

lib.internal:CreatePool(lib.SettingType.Expander, function()
	local frame = Mixin(CreateFrame('Frame', nil, UIParent), expanderMixin)
	frame:SetScript('OnMouseUp', frame.OnMouseUp)
	frame:SetSize(350, 34)
	frame.align = 'center'

	local texture = frame:CreateTexture(nil, 'ARTWORK')
	texture:SetTexture([[Interface\FriendsFrame\UI-FriendsFrame-OnlineDivider]])
	texture:SetSize(350, 16)
	texture:SetPoint('TOP', 0, 0)
	frame.Divider = texture

	local label = frame:CreateFontString(nil, nil, 'GameFontHighlightMedium')
	label:SetJustifyH('CENTER')
	label:SetJustifyV('MIDDLE')
	label:SetPoint('TOP', 0, -11)
	frame.Label = label

	return frame
end, function(_, frame)
	frame:Hide()
	frame.Label:SetText()
	frame.layoutIndex = nil
	frame.single, frame.first, frame.expanded = nil, nil, nil
end)
