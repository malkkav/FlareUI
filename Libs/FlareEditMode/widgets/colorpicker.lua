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

local function onColorChanged(self)
	local r, g, b = ColorPickerFrame:GetColorRGB()
	if self.colorInfo.hasOpacity then
		local a = ColorPickerFrame:GetColorAlpha()
		self:OnColorChanged(CreateColor(r, g, b, a))
	else
		self:OnColorChanged(CreateColor(r, g, b))
	end
end

local function onColorCancel(self)
	self:OnColorChanged(self.oldValue)
end

local colorPickerMixin = {}
function colorPickerMixin:Setup(data)
	self.setting = data
	self.Label:SetWidth(lib.internal.LabelWidth(self))   -- FlareUI (dialog.lua LabelWidth)
	self.Label:SetText(data.name)
	self:Refresh()

	local value = data.get(lib:GetActiveLayoutName())
	if value == nil then
		value = data.default
	end

	local r, g, b, a = value:GetRGBA()
	self.colorInfo = {
		swatchFunc = GenerateClosure(onColorChanged, self),
		opacityFunc = GenerateClosure(onColorChanged, self),
		cancelFunc = GenerateClosure(onColorCancel, self),
		r = r,
		g = g,
		b = b,
		opacity = a,
		hasOpacity = data.hasOpacity
	}

	self.Swatch:SetColorRGB(r, g, b)
end

function colorPickerMixin:Refresh()
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

function colorPickerMixin:OnColorChanged(color)
	self.setting.set(lib:GetActiveLayoutName(), color, false)

	local r, g, b, a = color:GetRGBA()
	self.Swatch:SetColorRGB(r, g, b)

	-- update colorInfo for next run
	self.colorInfo.r = r
	self.colorInfo.g = g
	self.colorInfo.b = b
	self.colorInfo.opacity = a

	lib.internal:GetDialogOf(self):RefreshWidgets()
end

function colorPickerMixin:SetEnabled(enabled)
	self.Swatch:SetEnabled(enabled)
	self.Label:SetTextColor((enabled and WHITE_FONT_COLOR or DISABLED_FONT_COLOR):GetRGB())
end

-- FlareUI: in the Gamepad UI Blizzard's colour picker reports itself to the controller's focus
-- manager as it shows (GamepadMode.FrameControlsManager:FrameShown); opened from addon code that taints
-- the manager, and closing Edit Mode later ends in a forbidden SetPreferredGamepadInteractTarget blamed
-- on FlareUI. A swatch there opens FlareUI's own list (PadNav) of ready colours instead: the setting's
-- Default and the class colours, named by the game's own class names. The opacity stays as it is.
local PAD_CLASSES = { 'WARRIOR', 'PALADIN', 'HUNTER', 'ROGUE', 'PRIEST', 'DEATHKNIGHT', 'SHAMAN', 'MAGE',
	'WARLOCK', 'MONK', 'DRUID', 'DEMONHUNTER', 'EVOKER' }
local function padColorEntries(parent)
	local data, info = parent.setting, parent.colorInfo
	local a = info.opacity
	local entries = {}
	local function Add(text, r, g, b)
		entries[#entries + 1] = {
			text = text,
			checked = function()
				local cur = parent.colorInfo
				return math.abs(cur.r - r) < 0.005 and math.abs(cur.g - g) < 0.005 and math.abs(cur.b - b) < 0.005
			end,
			pick = function()
				parent.oldValue = CreateColor(info.r, info.g, info.b, info.opacity)
				parent:OnColorChanged(info.hasOpacity and CreateColor(r, g, b, a) or CreateColor(r, g, b))
			end,
			font = function(fs)
				fs:SetFontObject('GameFontHighlight')
				fs:SetTextColor(r, g, b)
			end,
		}
	end
	if data.default and data.default.GetRGB then
		local r, g, b = data.default:GetRGB()
		Add(_G.DEFAULT or (ns.L and ns.L['Default']) or 'Default', r, g, b)
		entries[#entries + 1] = { divider = true }
	end
	local names = _G.LOCALIZED_CLASS_NAMES_MALE or {}
	for _, class in ipairs(PAD_CLASSES) do
		local c = _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[class]
		if c and names[class] then Add(names[class], c.r, c.g, c.b) end
	end
	return entries
end

local function onSwatchClick(self)
	local parent = self:GetParent()
	if ns.IsGamepadUI and ns.IsGamepadUI() and ns.PadNav and ns.PadNav.OpenList then
		ns.PadNav.OpenList(self, padColorEntries(parent))
		return
	end
	local info = parent.colorInfo

	-- store current/previous colors for reset capabilities
	parent.oldValue = CreateColor(info.r, info.g, info.b, info.opacity)

	ColorPickerFrame:SetupColorPickerAndShow(info)
end

lib.internal:CreatePool(lib.SettingType.ColorPicker, function()
	local frame = CreateFrame('Frame', nil, UIParent, 'ResizeLayoutFrame')
	frame.fixedHeight = 32 -- default attribute
	frame:Hide() -- default state
	frame:SetScript('OnLeave', DefaultTooltipMixin.OnLeave)
	frame:SetScript('OnEnter', showTooltip)
	frame.FlareUI_DarkTooltips = true -- FlareUI: opaque tooltip (Settings/Panel.lua)

	-- recreate EditModeSetting* widgets
	local Label = frame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightMedium')
	Label:SetPoint('LEFT')
	Label:SetSize(100, 32)   -- (FlareUI: set per box in Setup, dialog.lua LabelWidth)
	Label:SetJustifyH('LEFT')
	frame.Label = Label

	local Swatch = CreateFrame('Button', nil, frame, 'ColorSwatchTemplate')
	Swatch:SetSize(32, 32)
	Swatch:SetPoint('LEFT', Label, 'RIGHT', 5, 0)
	Swatch:SetScript('OnClick', onSwatchClick)
	frame.Swatch = Swatch

	return Mixin(frame, colorPickerMixin)
end, function(_, frame)
	frame:Hide()
	frame.layoutIndex = nil
end)
