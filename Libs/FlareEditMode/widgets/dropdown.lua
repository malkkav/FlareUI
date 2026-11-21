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

local function get(data)
	local value = data.get(lib:GetActiveLayoutName())
	if value then
		if data.multiple then
			assert(type(value) == 'table', "multiple choice dropdowns expects a table from 'get'")

			for _, v in next, value do
				if v == data.value then
					return true
				end
			end
		else
			return value == data.value
		end
	end
end

local function set(data)
	data.set(lib:GetActiveLayoutName(), data.value, false)

	lib.internal:GetDialogOf(data.widget):RefreshWidgets()
end

local dropdownMixin = {}
-- FlareUI: the menu (and the box's text) is built only when the box can be seen. A hidden row (a
-- closed section) or a dialog not shown yet builds it as the box shows: the dropdown's own OnShow
-- runs GenerateMenu. Saves building long lists (textures, fonts) that are never looked at.
function dropdownMixin:SetupMenu(generator)
	if self.Dropdown:IsVisible() then
		self.Dropdown:SetupMenu(generator)
	else
		self.Dropdown.menuGenerator = generator
	end
end

function dropdownMixin:Setup(data)
	self.setting = data
	-- FlareUI: a pooled box showing again (Refresh) runs its OnShow, which would build the previous
	-- setting's menu first
	if data.generator or data.values then self.Dropdown.menuGenerator = nil end
	self.Label:SetWidth(lib.internal.LabelWidth(self))   -- FlareUI (dialog.lua LabelWidth)
	self.Label:SetText(data.name)
	self:Refresh()
	-- FlareUI: pooled boxes drop a text another setting fixed with OverrideText (Bar Text's
	-- summaries), so they show their own selection again
	self.Dropdown.disableSelectionText = nil

	if data.generator then
		-- let the user have full control
		self:SetupMenu(function(owner, rootDescription)
			pcall(data.generator, owner, rootDescription, data)
		end)
	elseif data.values then
		self:SetupMenu(function(_, rootDescription)
			local values = data.values
			if type(values) == 'function' then
				values = values()
			end

			if data.height then
				rootDescription:SetScrollMode(data.height)
			elseif #values > 20 then
				-- FlareUI: a long list (media packs: hundreds of textures or fonts) scrolls, 20 entries tall
				rootDescription:SetScrollMode(20 * 20)
			end

			for _, value in next, values do
				if value.isDivider then
					-- FlareUI: { isDivider = true } draws a line between groups of choices
					rootDescription:CreateDivider()
				elseif data.multiple then
					rootDescription:CreateCheckbox(value.text, get, set, {
						get = data.get,
						set = data.set,
						value = value.value or value.text,
						multiple = data.multiple,
						widget = self,
					})
				else
					local radio = rootDescription:CreateRadio(value.text, get, set, {
						get = data.get,
						set = data.set,
						value = value.value or value.text,
						multiple = data.multiple,
						widget = self,
					})
					-- FlareUI: { fontFace = "Name" } draws the choice in that font
					if value.fontFace and radio and radio.AddInitializer and ns.SetFontFamily and ns.GetFontPath then
						radio:AddInitializer(function(button)
							if button.fontString then ns.SetFontFamily(button.fontString, ns.GetFontPath(value.fontFace), 13, '') end
						end)
					end
				end
			end
		end)
	end
end

-- FlareUI (11-21): in the Gamepad UI a Blizzard menu opened from these boxes hands the controller's
-- focus manager an addon call; closing Edit Mode later ends in a forbidden SetPreferredGamepadInteractTarget
-- blamed on FlareUI. Every box opens FlareUI's own list instead (PadNav, as the settings panel does),
-- built from the same choices. A box that builds its own menu (data.generator) runs it against a
-- stand-in that records what it adds: radios and checkboxes with their own get and set, a submenu as
-- a heading with its choices under it, a disabled choice greyed out.
local PAD_INDENT = '    '
local function MenuRecorder(entries, depth, parentEntry)
	local rec = {}
	local function Add(entry)
		if parentEntry then parentEntry.isHeader = true end
		entry.depth = depth
		entries[#entries + 1] = entry
		local child = MenuRecorder(entries, depth + 1, entry)
		child.SetEnabled = function(_, on) entry.disabled = not on end
		return child
	end
	function rec:CreateRadio(text, isSelected, setSelected, data)
		return Add({ text = text, checked = function() return isSelected(data) end, pick = function() setSelected(data) end })
	end
	function rec:CreateCheckbox(text, isSelected, setSelected, data)
		return Add({ text = text, multi = true, checked = function() return isSelected(data) end, pick = function() setSelected(data) end })
	end
	function rec:CreateButton(text, callback, data)
		return Add({ text = text, pick = callback and function() callback(data) end })
	end
	function rec:CreateTitle(text)
		return Add({ text = text, isHeader = true })
	end
	function rec:CreateDivider()
		entries[#entries + 1] = { divider = true }
		return rec
	end
	-- anything else (scroll mode, initializers, tooltips) does nothing here
	return setmetatable(rec, { __index = function() return function() end end })
end

local function PadFromGenerator(dropdown, data)
	local recorded = {}
	pcall(data.generator, dropdown, MenuRecorder(recorded, 0), data)
	local entries = {}
	for _, e in ipairs(recorded) do
		if e.divider then
			entries[#entries + 1] = e
		else
			local text = PAD_INDENT:rep(e.depth or 0) .. tostring(e.text or '')
			if e.isHeader then
				-- a submenu's name: a heading, nothing to pick
				entries[#entries + 1] = { text = '|cffffd100' .. text .. '|r', multi = true }
			elseif e.disabled then
				entries[#entries + 1] = { text = '|cff808080' .. text .. '|r', multi = true }
			else
				local pick = e.pick
				entries[#entries + 1] = {
					text = text, multi = e.multi, checked = e.checked,
					-- (the box's other rows follow, as after Blizzard's menu)
					pick = function()
						pick()
						lib.internal:GetDialogOf(dropdown:GetParent()):RefreshWidgets()
					end,
				}
			end
		end
	end
	return entries
end

function dropdownMixin:PadEntries()
	local data = self.setting
	if data and data.generator then return PadFromGenerator(self.Dropdown, data) end
	local values = data and data.values
	if type(values) == 'function' then values = values() end
	local entries = {}
	for _, value in next, values or {} do
		if value.isDivider then
			entries[#entries + 1] = { divider = true }
		else
			local opt = { get = data.get, set = data.set, value = value.value or value.text, multiple = data.multiple, widget = self }
			local fontFace = value.fontFace
			entries[#entries + 1] = {
				text = value.text,
				multi = data.multiple and true or nil,
				checked = function() return get(opt) end,
				pick = function() set(opt) end,
				font = fontFace and ns.SetFontFamily and ns.GetFontPath and function(fs)
					ns.SetFontFamily(fs, ns.GetFontPath(fontFace), 13, '')
				end or nil,
			}
		end
	end
	return entries
end

function dropdownMixin:Refresh()
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

function dropdownMixin:SetEnabled(enabled)
	self.Dropdown:SetEnabled(enabled)
	self.Label:SetTextColor((enabled and WHITE_FONT_COLOR or DISABLED_FONT_COLOR):GetRGB())
end

lib.internal:CreatePool(lib.SettingType.Dropdown, function()
	local frame = CreateFrame('Frame', nil, UIParent, 'ResizeLayoutFrame')
	frame:SetScript('OnLeave', DefaultTooltipMixin.OnLeave)
	frame:SetScript('OnEnter', showTooltip)
	frame.FlareUI_DarkTooltips = true -- FlareUI: opaque tooltip (Settings/Panel.lua)
	frame.fixedHeight = 32
	Mixin(frame, dropdownMixin)

	local label = frame:CreateFontString(nil, nil, 'GameFontHighlightMedium')
	label:SetPoint('LEFT')
	label:SetWidth(100)
	label:SetJustifyH('LEFT')
	frame.Label = label

	local dropdown = CreateFrame('DropdownButton', nil, frame, 'WowStyle1DropdownTemplate')
	dropdown:SetPoint('LEFT', label, 'RIGHT', 5, 0)
	dropdown:SetSize(200, 30)
	frame.Dropdown = dropdown
	-- FlareUI: the Gamepad UI's plain list (PadEntries); only in the Gamepad UI
	if ns.PadNav and ns.PadNav.GuardDropdown then
		ns.PadNav.GuardDropdown(dropdown, function() return frame:PadEntries() end)
	end

	return frame
end, function(_, frame)
	frame:Hide()
	frame.layoutIndex = nil
end)
