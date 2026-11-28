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

local internal = lib.internal

local extensionMixin = {}
function extensionMixin:Update(systemID, subSystemID)
	self.systemID = systemID
	self.subSystemID = subSystemID

	internal.ReleaseAllPools()

	local numSettings = self:UpdateSettings()
	if numSettings == 0 then
		self.Buttons:ClearAllPoints()
		self.Buttons:SetPoint('TOP', 0, -20)
	else
		self.Buttons:ClearAllPoints()
		self.Buttons:SetPoint('TOP', self.Settings, 'BOTTOM', 0, -2)
	end

	self:UpdateButtons(numSettings)

	-- show and update layout
	self:Show()
	-- FlareUI: switches two to a line, as in FlareUI's own frames' dialog (dialog.lua PairCheckboxes; 11-28,
	-- the chat's Fade Old Lines | Keep Messages Shown)
	if internal.PairCheckboxes then internal.PairCheckboxes(self.Settings) end
	self:Layout()
end

-- after the layout pass has sized the box (never during it: re-anchoring mid-layout left the box with
-- no size, so its frame and background vanished)
function extensionMixin:PlaceSoon()
	if self.placePending then return end
	self.placePending = true
	C_Timer.After(0, function()
		self.placePending = nil
		self:Place()
	end)
end

-- (FlareUI) always right under Blizzard's dialog, so the two read as one panel; when
-- the pair would run off the bottom of the screen (a frame near the bottom, like the chat), Blizzard's
-- dialog moves up just enough for both to fit. The dialog is not protected and players drag it anyway.
function extensionMixin:Place()
	local dialog = EditModeSystemSettingsDialog
	if not (dialog and self:IsShown()) then return end
	local ds, s = dialog:GetEffectiveScale(), self:GetEffectiveScale()
	local top, bottom, left = dialog:GetTop(), dialog:GetBottom(), dialog:GetLeft()
	local h = self:GetHeight()
	if not (top and bottom and left and h and h > 0) then return end
	local short = h * s - bottom * ds          -- screen pixels missing below the dialog
	if short <= 0 then return end
	local screenTop = UIParent:GetTop() * UIParent:GetEffectiveScale()
	local newTop = math.min(top * ds + short, screenTop)
	dialog:ClearAllPoints()
	dialog:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', left, newTop / ds)
end

function extensionMixin:RefreshWidgets()
	for _, widget in next, self.Settings.widgets do
		if widget.Refresh then
			widget:Refresh()
		end
	end

	if self:IsShown() then
		if internal.PairCheckboxes then internal.PairCheckboxes(self.Settings) end
		self:Layout()
		self:PlaceSoon()   -- a section opened or closed: its height changed
	end
end

function extensionMixin:UpdateSettings()
	self.Settings.widgets = table.wipe(self.Settings.widgets or {})

	local settings, num = internal:GetSystemSettings(self.systemID, self.subSystemID)
	local isEmpty = num == 0
	if not isEmpty then
		local plan = internal.PlanSections(settings, self:MemoryKey())
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

	self.Settings.ignoreInLayout = isEmpty
	self.Settings.ResetButton:SetText(internal.ResetSettingsText())
	self.Settings.ResetButton.layoutIndex = num + 1
	self.Settings.ResetButton.ignoreInLayout = isEmpty
	self.Settings.ResetButton:SetEnabled(not isEmpty)

	return num
end

function extensionMixin:UpdateButtons(numSettings)
	local buttons, num = internal:GetSystemSettingsButtons(self.systemID, self.subSystemID)
	local isEmpty = num == 0
	if not isEmpty then
		if numSettings > 0 then
			local divider = internal:GetPool(lib.SettingType.Divider):Acquire(self.Settings)
			divider.layoutIndex = numSettings + 2 -- + 1 is for the reset button
			divider:Show()
		end

		for index, data in next, buttons do
			local button = internal:GetPool('button'):Acquire(self.Buttons)
			button.layoutIndex = index
			button:SetText(data.text)
			button:SetOnClickHandler(data.click)
			button:Show()
			button:SetEnabled(true) -- reset from pool
		end
	end

	self.Buttons.ignoreInLayout = isEmpty
end

-- FlareUI: the box's memory of the last open section, per Blizzard system
function extensionMixin:MemoryKey()
	return 'system:' .. tostring(self.systemID) .. ':' .. tostring(self.subSystemID)
end

function extensionMixin:SectionClicked(widget, expanded)
	internal.SectionClicked(self, widget, expanded, self:MemoryKey())
end

function extensionMixin:ResetSettings()
	local settings, num = internal:GetSystemSettings(self.systemID, self.subSystemID)
	if num > 0 then
		-- (FlareUI: redraws held until the last setter, as the frame dialog's: lib:Defer)
		internal.Batched(function()
			for _, data in next, settings do
				-- (FlareUI: section titles keep their open state)
				if data.set and data.kind ~= lib.SettingType.Expander then
					-- FlareUI: true = a reset, as the frame dialog's
					data.set(lib:GetActiveLayoutName(), data.default, true)
				end
			end
		end)
	end
end

-- (FlareUI) an Edit Mode dialog next to the frame it belongs to: to its right when there is
-- room, else to its left, else above or below it; its top level with the frame's; the whole of it on
-- screen. below: screen pixels that hang under the dialog (FlareUI's box under Blizzard's).
-- One spot for every settings dialog, FlareUI's and Blizzard's: a fixed start at the
-- top right, then wherever the player last dragged one. Kept in screen pixels (each dialog has its own
-- scale) in the table lib.GetDialogStore() hands over (FlareUI: the account-wide saved variables).
-- Dialogs used to open beside the selected frame, so a dialog dragged away came back each time.
local DEFAULT_RIGHT, DEFAULT_TOP = 250, 150
local function DialogStore()
	local get = lib.GetDialogStore
	local ok, store = pcall(get or function() end)
	return ok and type(store) == 'table' and store or nil
end
function internal.PlaceSaved(panel)
	if not panel then return end
	local ps = panel:GetEffectiveScale()
	local store = DialogStore()
	local pos = store and store.editDialogPos
	panel:ClearAllPoints()
	if pos and pos.left and pos.top then
		local us = UIParent:GetEffectiveScale()
		local sw, sh = UIParent:GetWidth() * us, UIParent:GetHeight() * us
		-- (a smaller screen since: kept on it)
		local left = math.max(0, math.min(pos.left, sw - 100 * us))
		local top = math.max(100 * us, math.min(pos.top, sh))
		panel:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', left / ps, top / ps)
	else
		panel:SetPoint('TOPRIGHT', UIParent, 'TOPRIGHT', -DEFAULT_RIGHT, -DEFAULT_TOP)
	end
end
function internal.SaveDialogPos(panel)
	local store = DialogStore()
	if not (store and panel) then return end
	local ps = panel:GetEffectiveScale()
	local left, top = panel:GetLeft(), panel:GetTop()
	if not (left and top) then return end
	store.editDialogPos = { left = left * ps, top = top * ps }
end

function internal.PlaceNear(panel, target, below)
	if not (panel and target and panel:IsShown()) then return end
	local ts, ps = target:GetEffectiveScale(), panel:GetEffectiveScale()
	local tl, tr, tt, tb = target:GetLeft(), target:GetRight(), target:GetTop(), target:GetBottom()
	local pw, ph = panel:GetWidth(), panel:GetHeight()
	if not (tl and tr and tt and tb and pw and ph and pw > 0) then return end
	tl, tr, tt, tb = tl * ts, tr * ts, tt * ts, tb * ts
	pw, ph = pw * ps, ph * ps + (below or 0)
	local us = UIParent:GetEffectiveScale()
	local sw, sh = UIParent:GetWidth() * us, UIParent:GetHeight() * us
	local gap = 12 * us
	local left, top
	if tr + gap + pw <= sw then
		left, top = tr + gap, tt
	elseif tl - gap - pw >= 0 then
		left, top = tl - gap - pw, tt
	else
		-- a frame as wide as the screen: above it when the room is there, else below it
		left = math.max(0, math.min(tl, sw - pw))
		top = (sh - tt >= ph + gap) and (tt + gap + ph) or (tb - gap)
	end
	top = math.max(ph, math.min(top, sh))
	panel:ClearAllPoints()
	panel:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', left / ps, top / ps)
end

function internal:CreateExtension()
	local extension = Mixin(CreateFrame('Frame', nil, UIParent, 'ResizeLayoutFrame'), extensionMixin)
	extension:SetSize(64, 64)
	extension:SetPoint('TOP', EditModeSystemSettingsDialog, 'BOTTOM', 0, 0)
	extension:SetFrameStrata('DIALOG')
	extension:SetFrameLevel(300)
	extension:EnableMouse(true)
	extension:Hide()
	extension.widthPadding = 40
	extension.heightPadding = 40

	local extensionBorder = CreateFrame('Frame', nil, extension, 'DialogBorderTranslucentTemplate')
	extensionBorder.ignoreInLayout = true
	extension.Border = extensionBorder

	local extensionSettings = CreateFrame('Frame', nil, extension, 'VerticalLayoutFrame')
	extensionSettings:SetPoint('TOP', 0, -15)
	extensionSettings.spacing = 2
	extension.Settings = extensionSettings

	local resetSettingsButton = CreateFrame('Button', nil, extensionSettings, 'EditModeSystemSettingsDialogButtonTemplate')
	resetSettingsButton:SetText(RESET_TO_DEFAULT)
	resetSettingsButton:SetOnClickHandler(GenerateClosure(extension.ResetSettings, extension))
	extensionSettings.ResetButton = resetSettingsButton

	local extensionButtons = CreateFrame('Frame', nil, extension, 'VerticalLayoutFrame')
	extensionButtons.spacing = 2
	extension.Buttons = extensionButtons

	return extension
end
