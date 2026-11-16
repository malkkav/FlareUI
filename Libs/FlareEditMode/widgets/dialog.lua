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
-- FlareUI: the settings list scrolls once it grows past this height. Unset (the default since 11-16,
-- Malkkav): the whole dialog takes up to about 65% of the screen's height, the list never under 420.
function lib:SetDialogMaxHeight(height)
	lib.dialogMaxHeight = height
end
function internal.DialogMaxHeight()
	if lib.dialogMaxHeight then return lib.dialogMaxHeight end
	local screen = UIParent:GetHeight() or 768
	return math.max(420, math.floor(screen * 0.65) - 150)
end

-- FlareUI (11-16, Malkkav): one section open at a time. Before the widgets are set up, the sections
-- (Expander rows) are put in order: a box with one section shows it open, as a plain title; otherwise
-- the first section starts open until the player opens or closes one in that box, which is then
-- remembered for the session (the open state itself lives in the settings, Core.lua EditSections).
internal.sectionsTouched = internal.sectionsTouched or {}
local function IsHiddenData(data, layout)
	if type(data.hidden) == 'function' then return data.hidden(layout) and true or false end
	return data.hidden and true or false
end
function internal.PlanSections(settings, memoryKey)
	local layout = lib:GetActiveLayoutName()
	-- (a static Expander is a note line, like "Bar Visible above also hides this bar": not a section)
	local first
	local visible = {}
	for _, data in next, settings do
		if data.kind == lib.SettingType.Expander and not IsHiddenData(data, layout) then
			first = first or data
			if not data.static then visible[#visible + 1] = data end
		end
	end
	local plan = { first = first, single = #visible == 1 and visible[1] or nil }
	if plan.single then
		plan.single.set(layout, true, false)
	elseif #visible > 1 then
		local touched = memoryKey ~= nil and internal.sectionsTouched[memoryKey]
		local seen = false
		for i, data in ipairs(visible) do
			local open
			if touched then
				open = data.get(layout) and not seen
			else
				open = i == 1
			end
			if open then seen = true end
			if (not not data.get(layout)) ~= open then data.set(layout, open, false) end
		end
	end
	return plan
end
function internal.MarkSection(widget, data, plan)
	if data.kind ~= lib.SettingType.Expander then return end
	widget.single = plan.single == data or nil
	widget.first = plan.first == data or nil
end
-- a section title clicked in a box (dialog or extension): opening it closes the others
function internal.SectionClicked(box, clicked, expanded, memoryKey)
	if memoryKey ~= nil then internal.sectionsTouched[memoryKey] = true end
	if not expanded then return end
	local layout = lib:GetActiveLayoutName()
	for _, widget in next, box.Settings.widgets do
		if widget ~= clicked and widget.setting and widget.setting.kind == lib.SettingType.Expander
			and not widget.setting.static and widget.setting.get(layout) then
			widget.setting.set(layout, false, false)
		end
	end
end

-- FlareUI (11-16, Malkkav): the label column of FlareUI's own dialogs is 120 px (100 in Blizzard's),
-- so labels like "Absorb Texture" or "Group Spacing" stay on one line. The box under Blizzard's own
-- dialog (the extension) keeps 100, to stay as wide as the dialog above it.
internal.LABEL_WIDTH, internal.LABEL_WIDTH_BLIZZARD = 120, 100
function internal.LabelWidth(widget)
	return internal:GetDialogOf(widget) == internal.dialog and internal.LABEL_WIDTH or internal.LABEL_WIDTH_BLIZZARD
end

function dialogMixin:SectionClicked(widget, expanded)
	internal.SectionClicked(self, widget, expanded, self.selection and self.selection.parent)
end

function dialogMixin:UpdateScroll(resetScroll, offset)
	local settings = self.Settings
	local width, height
	if #(settings.widgets or {}) == 0 then
		-- (11-16) no settings: an empty list as wide as the buttons under it
		settings:SetSize(330, 1)
		width, height = 330, 1
	else
		settings:Layout()
		width, height = settings:GetSize()
	end
	local maxHeight = internal.DialogMaxHeight()
	local scrolling = height > maxHeight
	-- leave room for the scroll bar inside the dialog's border when it is needed
	self.Scroll:SetSize(width + (scrolling and 22 or 0), scrolling and maxHeight or height)
	if resetScroll or not scrolling then
		self.Scroll:SetVerticalScroll(0)
	else
		-- keep the user's place, clamped in case the list just got shorter
		local range = math.max(0, height - maxHeight)
		self.Scroll:SetVerticalScroll(math.min(offset or self.Scroll:GetVerticalScroll(), range))
	end
	if self.Scroll.ScrollBar then
		self.Scroll.ScrollBar:SetShown(scrolling)
	end
end

function dialogMixin:Update(selection)
	-- FlareUI: the same frame's dialog rebuilt (a setting that changes the list, a nudge) keeps its
	-- scroll position; another frame's starts at the top
	local sameFrame = self.selection == selection and self:IsShown()
	-- read before the rebuild: releasing the widgets empties the list, and the scroll frame drops to
	-- the top on its own before the new list is measured
	local offset = sameFrame and self.Scroll:GetVerticalScroll() or nil
	self.selection = selection

	self.Title:SetText(selection.system:GetSystemName())
	self:UpdateSettings()
	self:UpdateButtons()

	-- show and update layout
	self:Show()
	self:UpdateScroll(not sameFrame, offset)
	self:Layout()
	-- and once more next frame, when the scroll frame has taken the new list's height
	if offset and offset > 0 then
		C_Timer.After(0, function()
			if self.selection == selection and self:IsShown() then self:UpdateScroll(false, offset) end
		end)
	end
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
		local plan = internal.PlanSections(settings, self.selection.parent)
		for index, data in next, settings do
			local pool = internal:GetPool(data.kind)
			if pool then
				local widget = pool:Acquire(self.Settings)
				widget.layoutIndex = index
				internal.MarkSection(widget, data, plan)
				widget:Setup(data)

				table.insert(self.Settings.widgets, widget)
			end
		end
	end

	-- FlareUI (11-16): Reset Settings sits in the button bar under the list (UpdateButtons)
	self.numSettings = num
	self.Settings.ResetButton:Hide()
	self.Settings.ResetButton.ignoreInLayout = true
	self.Settings.Divider.layoutIndex = num + 2
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

	-- FlareUI (11-16, Malkkav): one pinned bar under the list: FlareUI Settings, Reset Settings, Reset
	-- Position. Reset Settings used to scroll at the end of the list.
	local resetSettings = internal:GetPool('button'):Acquire(self.Buttons)
	resetSettings.layoutIndex = num + 1
	resetSettings:SetText(internal.ResetSettingsText())
	resetSettings:SetOnClickHandler(GenerateClosure(self.ResetSettings, self))
	resetSettings:Show()
	resetSettings:SetEnabled((self.numSettings or 0) > 0)

	local resetPosition = internal:GetPool('button'):Acquire(self.Buttons)
	resetPosition.layoutIndex = num + 2
	resetPosition:SetText(HUD_EDIT_MODE_RESET_POSITION)
	resetPosition:SetOnClickHandler(GenerateClosure(self.ResetPosition, self))
	resetPosition:Show()
	resetPosition:SetEnabled(not isDefaultPosition(parent))
	self.Buttons.ResetPositionButton = resetPosition
end

-- FlareUI: "Reset Settings" in FlareUI's language, set by EditModeOverlays.lua (lib.resetSettingsText);
-- Blizzard's "Reset To Default" otherwise
function internal.ResetSettingsText()
	return lib.resetSettingsText or RESET_TO_DEFAULT
end

function dialogMixin:ResetSettings()
	local settings, num = internal:GetFrameSettings(self.selection.parent)
	if num > 0 then
		for _, data in next, settings do
			-- (FlareUI: section titles keep their open state)
			if data.set and data.kind ~= lib.SettingType.Expander then
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
	divider:Hide() -- FlareUI: no line between Reset To Default and Reset To Default Position
	dialogSettings.Divider = divider

	local dialogButtons = CreateFrame('Frame', nil, dialog, 'VerticalLayoutFrame')
	dialogButtons:SetPoint('TOP', dialogScroll, 'BOTTOM', 0, -12)
	dialogButtons.spacing = 2
	dialog.Buttons = dialogButtons

	return dialog
end
