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

local CENTER = {
	point = 'CENTER',
	x = 0,
	y = 0,
}

local internal = lib.internal

-- replica of EditModeSystemSettingsDialog
local dialogMixin = {}
-- FlareUI: the settings list scrolls once it grows past this height
lib.dialogMaxHeight = lib.dialogMaxHeight or 420
function lib:SetDialogMaxHeight(height)
	lib.dialogMaxHeight = height
end

function dialogMixin:UpdateScroll(resetScroll)
	local settings = self.Settings
	settings:Layout()
	local width, height = settings:GetSize()
	local maxHeight = lib.dialogMaxHeight or 420
	local scrolling = height > maxHeight
	-- leave room for the scroll bar inside the dialog's border when it is needed
	self.Scroll:SetSize(width + (scrolling and 22 or 0), scrolling and maxHeight or height)
	if resetScroll or not scrolling then
		self.Scroll:SetVerticalScroll(0)
	else
		-- keep the user's place, clamped in case the list just got shorter
		local range = math.max(0, height - maxHeight)
		self.Scroll:SetVerticalScroll(math.min(self.Scroll:GetVerticalScroll(), range))
	end
	if self.Scroll.ScrollBar then
		self.Scroll.ScrollBar:SetShown(scrolling)
	end
end

function dialogMixin:Update(selection)
	self.selection = selection

	self.Title:SetText(selection.system:GetSystemName())
	self:UpdateSettings()
	self:UpdateButtons()

	-- show and update layout
	self:Show()
	self:UpdateScroll(true)
	self:Layout()
end

function dialogMixin:RefreshWidgets()
	for _, widget in next, self.Settings.widgets do
		if widget.Refresh then
			widget:Refresh()
		end
	end

	if self:IsShown() then
		self:UpdateScroll()
		self:Layout()
	end
end

function dialogMixin:UpdateSettings()
	internal.ReleaseAllPools()

	self.Settings.widgets = table.wipe(self.Settings.widgets or {})

	local settings, num = internal:GetFrameSettings(self.selection.parent)
	if num > 0 then
		for index, data in next, settings do
			local pool = internal:GetPool(data.kind)
			if pool then
				local widget = pool:Acquire(self.Settings)
				widget.layoutIndex = index
				widget:Setup(data)

				table.insert(self.Settings.widgets, widget)
			end
		end
	end

	self.Settings.ResetButton.layoutIndex = num + 1
	self.Settings.Divider.layoutIndex = num + 2
	self.Settings.ResetButton:SetEnabled(num > 0)
end

function dialogMixin:Reset()
	self.selection = nil
	self:ClearAllPoints()
	self:SetPoint('BOTTOMRIGHT', UIParent, -250, 250)
end

local function closeEnough(a, b)
	return math.abs(a - b) < 0.01
end

local function isDefaultPosition(parent)
	local point, _, _, x, y = parent:GetPoint()
	local default = lib:GetFrameDefaultPosition(parent)
	if not default then
		default = CopyTable(CENTER)
	end

	return point == default.point and closeEnough(x, default.x) and closeEnough(y, default.y)
end

function dialogMixin:UpdateButtons()
	local parent = self.selection.parent
	local buttons, num = internal:GetFrameButtons(parent)
	if num > 0 then
		for index, data in next, buttons do
			local button = internal:GetPool('button'):Acquire(self.Buttons)
			button.layoutIndex = index
			button:SetText(data.text)
			button:SetOnClickHandler(data.click)
			button:Show()
			button:SetEnabled(true) -- reset from pool
		end
	end

	local resetPosition = internal:GetPool('button'):Acquire(self.Buttons)
	resetPosition.layoutIndex = num + 1
	resetPosition:SetText(HUD_EDIT_MODE_RESET_POSITION)
	resetPosition:SetOnClickHandler(GenerateClosure(self.ResetPosition, self))
	resetPosition:Show()
	resetPosition:SetEnabled(not isDefaultPosition(parent))
	self.Buttons.ResetPositionButton = resetPosition
end

function dialogMixin:ResetSettings()
	local settings, num = internal:GetFrameSettings(self.selection.parent)
	if num > 0 then
		for _, data in next, settings do
			if data.set then
				data.set(lib:GetActiveLayoutName(), data.default, true)
			end
		end

		self:Update(self.selection)
	end
end

function dialogMixin:ResetPosition()
	if InCombatLockdown() then
		-- TODO: maybe add a warning?
		return
	end

	local parent = self.selection.parent
	local pos = lib:GetFrameDefaultPosition(parent)
	if not pos then
		pos = CopyTable(CENTER)
	end

	parent:ClearAllPoints()
	parent:SetPoint(pos.point, pos.x, pos.y)
	self.Buttons.ResetPositionButton:SetEnabled(false)

	internal:TriggerCallback(parent, pos.point, pos.x, pos.y)
end

local BIG_STEP = 10
local SMALL_STEP = 1

function dialogMixin:OnKeyDown(key)
	if InCombatLockdown() then
		return
	end

	if self.selection then
		self:SetPropagateKeyboardInput(false) -- protected

		if key == 'LEFT' then
			internal:MoveParent(self.selection, IsShiftKeyDown() and -BIG_STEP or -SMALL_STEP)
		elseif key == 'RIGHT' then
			internal:MoveParent(self.selection, IsShiftKeyDown() and BIG_STEP or SMALL_STEP)
		elseif key == 'UP' then
			internal:MoveParent(self.selection, 0, IsShiftKeyDown() and BIG_STEP or SMALL_STEP)
		elseif key == 'DOWN' then
			internal:MoveParent(self.selection, 0, IsShiftKeyDown() and -BIG_STEP or -SMALL_STEP)
		else
			self:SetPropagateKeyboardInput(true) -- protected
		end
	else
		self:SetPropagateKeyboardInput(true) -- protected
	end
end

-- FlareUI: widgets used to reach the dialog with GetParent():GetParent(); the settings container
-- now sits inside a scroll frame, so walk up until a frame carrying the dialog mixin is found
function internal:GetDialogOf(widget)
	local frame = widget
	while frame do
		if frame.RefreshWidgets then return frame end
		frame = frame:GetParent()
	end
	return internal.dialog
end

function internal:CreateDialog()
	local dialog = Mixin(CreateFrame('Frame', nil, UIParent, 'ResizeLayoutFrame'), dialogMixin)
	dialog:SetSize(300, 350)
	dialog:SetFrameStrata('DIALOG')
	dialog:SetFrameLevel(200)
	dialog:Hide()
	dialog.widthPadding = 40
	dialog.heightPadding = 40

	dialog:Reset()

	-- make draggable
	dialog:EnableMouse(true)
	dialog:SetMovable(true)
	dialog:SetClampedToScreen(true)
	dialog:SetDontSavePosition(true)
	dialog:RegisterForDrag('LeftButton')
	dialog:SetScript('OnDragStart', dialog.StartMoving)
	dialog:SetScript('OnDragStop', dialog.StopMovingOrSizing)
	dialog:SetScript('OnKeyDown', dialog.OnKeyDown)

	local dialogTitle = dialog:CreateFontString(nil, nil, 'GameFontHighlightLarge')
	dialogTitle:SetPoint('TOP', 0, -15)
	dialog.Title = dialogTitle

	local dialogBorder = CreateFrame('Frame', nil, dialog, 'DialogBorderTranslucentTemplate')
	dialogBorder.ignoreInLayout = true
	dialog.Border = dialogBorder

	local dialogClose = CreateFrame('Button', nil, dialog, 'UIPanelCloseButton')
	dialogClose:SetPoint('TOPRIGHT')
	dialogClose.ignoreInLayout = true
	dialogClose:HookScript('OnClick', function()
		dialog:Reset()
	end)
	dialog.Close = dialogClose

	-- FlareUI: settings live in a scroll frame so long dialogs stay on screen
	local dialogScroll = CreateFrame('ScrollFrame', nil, dialog, 'ScrollFrameTemplate')
	dialogScroll:SetPoint('TOP', dialogTitle, 'BOTTOM', 0, -12)
	dialogScroll:SetSize(1, 1)
	if dialogScroll.ScrollBar then
		dialogScroll.ScrollBar:ClearAllPoints()
		dialogScroll.ScrollBar:SetPoint('TOPRIGHT', dialogScroll, 'TOPRIGHT', 0, 0)
		dialogScroll.ScrollBar:SetPoint('BOTTOMRIGHT', dialogScroll, 'BOTTOMRIGHT', 0, 0)
		dialogScroll.ScrollBar:SetHideIfUnscrollable(true)
	end
	dialog.Scroll = dialogScroll

	local dialogSettings = CreateFrame('Frame', nil, dialogScroll, 'VerticalLayoutFrame')
	dialogSettings:SetPoint('TOPLEFT')
	dialogSettings.spacing = 2
	dialogScroll:SetScrollChild(dialogSettings)
	dialog.Settings = dialogSettings

	local resetSettingsButton = CreateFrame('Button', nil, dialogSettings, 'EditModeSystemSettingsDialogButtonTemplate')
	resetSettingsButton:SetText(RESET_TO_DEFAULT)
	resetSettingsButton:SetOnClickHandler(GenerateClosure(dialog.ResetSettings, dialog))
	dialogSettings.ResetButton = resetSettingsButton

	local divider = dialogSettings:CreateTexture(nil, 'ARTWORK')
	divider:SetSize(330, 16)
	divider:SetTexture([[Interface\FriendsFrame\UI-FriendsFrame-OnlineDivider]])
	dialogSettings.Divider = divider

	local dialogButtons = CreateFrame('Frame', nil, dialog, 'VerticalLayoutFrame')
	dialogButtons:SetPoint('TOP', dialogScroll, 'BOTTOM', 0, -12)
	dialogButtons.spacing = 2
	dialog.Buttons = dialogButtons

	return dialog
end
