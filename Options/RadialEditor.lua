local _, ns = ...
local L = ns.L

--------------------------------------------------
-- RADIAL EDITOR
-- The radial's buttons down the left, a live preview beside them, and a browser along the bottom to
-- drag new buttons from. Edits land on the saved radial as they are made (the preview shows them);
-- a copy of the library taken on open lets Cancel put it back.
-- Two kinds of drag:
--   * from Blizzard's windows something is on the game's cursor: OnReceiveDrag and GetCursorInfo
--     (a spell's ID is its FOURTH return)
--   * inside this window the floating icon is ours, so the drop is resolved in OnDragStop by asking
--     each row whether the mouse is over it (FinishDrag)
-- Lists are a fixed pool of cells over a scroll bar, as in the icon picker.
--------------------------------------------------
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

local WINDOW_W, WINDOW_H = 660, 710
local PAD       = 14
local GAP       = 10
local HEADER_H  = 44
local FOOTER_H  = 36
local LEFT_W    = 250
local PREVIEW_W = 368
local BODY_H    = 320
local BROWSE_H  = 248
local BUTTON_ROW_H, BUTTON_ROWS = 32, 9
local BROWSE_ROW_H, BROWSE_ROWS, BROWSE_COLS = 28, 6, 3
local TAB_W, TAB_GAP = 84, 3

local BRONZE       = { 0.80, 0.60, 0.34 }
local BRONZE_MUTED = { 0.61, 0.48, 0.29 }
local FALLBACK_ICON = 134400

-- the settings window's gradient, and a fainter one for the panels
local BG_TOP       = { 0.085, 0.075, 0.060, 0.95 }
local BG_BOTTOM    = { 0.015, 0.015, 0.015, 0.95 }
local PANEL_TOP    = { 0.130, 0.110, 0.085, 0.55 }
local PANEL_BOTTOM = { 0.030, 0.030, 0.030, 0.20 }

local editor, editingID, selectedButton, dragging, activeCategory
local snapshot, dirty

local function RM() return ns.RadialMenu end

local function Sound(key)
    if SOUNDKIT and SOUNDKIT[key] then PlaySound(SOUNDKIT[key]) end
end

--------------------------------------------------
-- PIECES
--------------------------------------------------
local Fade = ns.Fade   -- BaseConfig.lua

-- A bordered box with an optional heading, matching the inline groups in the settings window.
local function Panel(parent, heading)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetBackdrop({ edgeFile = LSM:Fetch("border", "Blizzard Tooltip"), edgeSize = 16 })
    f:SetBackdropBorderColor(BRONZE_MUTED[1], BRONZE_MUTED[2], BRONZE_MUTED[3], 1)
    Fade(f, 5, PANEL_TOP, PANEL_BOTTOM)
    if heading then
        f.Heading = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.Heading:SetPoint("TOPLEFT", 10, -8)
        f.Heading:SetText(heading)
    end
    return f
end

-- Every red button clicks like the Game Menu's. sound replaces that click where a button has a sound
-- of its own, such as the confirm; false leaves the sound to onClick.
local function RedButton(parent, text, width, onClick, sound)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(text)
    b:SetScript("OnClick", function(...)
        if sound ~= false then ns.ButtonSound(sound) end
        onClick(...)
    end)
    return b
end

--------------------------------------------------
-- SCROLLING LIST (1 or more columns)
--------------------------------------------------
-- UIPanelScrollBarTemplate names its two arrow buttons after the bar, so the bars are numbered.
local scrollBars = 0

local function CreateList(parent, width, columns, rows, cellHeight, buildCell, fillCell)
    local list = CreateFrame("Frame", nil, parent)
    local cellWidth = (width - 22) / columns
    list.cells, list.data, list.columns = {}, {}, columns
    list:SetSize(width, rows * cellHeight)

    for i = 1, columns * rows do
        local col, row = (i - 1) % columns, math.floor((i - 1) / columns)
        local cell = CreateFrame("Button", nil, list)
        cell:SetSize(cellWidth, cellHeight)
        cell:SetPoint("TOPLEFT", col * cellWidth, -row * cellHeight)

        cell.Highlight = cell:CreateTexture(nil, "BACKGROUND")
        cell.Highlight:SetAllPoints()
        cell.Highlight:SetColorTexture(BRONZE[1], BRONZE[2], BRONZE[3], 0.25)
        cell.Highlight:Hide()

        cell.Icon = cell:CreateTexture(nil, "ARTWORK")
        cell.Icon:SetSize(cellHeight - 8, cellHeight - 8)
        cell.Icon:SetPoint("LEFT", 4, 0)
        cell.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        cell.Text = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        cell.Text:SetPoint("LEFT", cell.Icon, "RIGHT", 6, 0)
        cell.Text:SetPoint("RIGHT", -6, 0)
        cell.Text:SetJustifyH("LEFT")
        cell.Text:SetWordWrap(false)

        -- a quiet bronze wash, rather than Blizzard's blue square, which fought everything here
        cell:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
        cell:GetHighlightTexture():SetColorTexture(BRONZE[1], BRONZE[2], BRONZE[3], 0.18)

        if buildCell then buildCell(cell) end
        list.cells[i] = cell
    end

    scrollBars = scrollBars + 1
    local slider = CreateFrame("Slider", "FlareUI_RadialEditorScroll" .. scrollBars, list,
        "UIPanelScrollBarTemplate")
    slider:SetOrientation("VERTICAL")
    -- the arrow buttons sit outside the track, so the track is inset to leave room for them
    slider:SetPoint("TOPRIGHT", 0, -18)
    slider:SetPoint("BOTTOMRIGHT", 0, 18)
    slider:SetWidth(16)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    list.slider = slider

    function list:Update()
        local offset = math.floor(slider:GetValue() or 0) * columns
        for i, cell in ipairs(self.cells) do
            local index = offset + i
            local item = self.data[index]
            cell.item, cell.dataIndex = item, item and index or nil
            if item then
                fillCell(cell, item, index)
                cell:Show()
            else
                cell:Hide()
            end
        end
    end

    function list:SetData(data)
        self.data = data or {}
        local maxOffset = math.max(0, math.ceil(#self.data / columns) - rows)
        slider:SetMinMaxValues(0, maxOffset)
        if (slider:GetValue() or 0) > maxOffset then slider:SetValue(maxOffset) end
        slider:SetShown(maxOffset > 0)
        self:Update()
    end

    local function Step(delta)
        slider:SetValue((slider:GetValue() or 0) + delta)
        Sound("U_CHAT_SCROLL_BUTTON")
    end

    -- the template's own handlers drive a ScrollFrame parent, which this is not
    slider:SetScript("OnValueChanged", function() list:Update() end)
    -- the arrows come from the template, so they are not assumed to be there
    if slider.ScrollUpButton then
        slider.ScrollUpButton:SetScript("OnClick", function() Step(-1) end)
        slider.ScrollDownButton:SetScript("OnClick", function() Step(1) end)
    end

    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        slider:SetValue((slider:GetValue() or 0) - delta)
    end)
    return list
end

--------------------------------------------------
-- ENTRIES
--------------------------------------------------
local function EntryFromCursor()
    local cursorType, info1, _, info3 = GetCursorInfo()
    local entry
    if cursorType == "spell" then
        entry = { kind = "spell", id = info3 or info1 }
    elseif cursorType == "item" then
        entry = { kind = "item", id = info1 }
    elseif cursorType == "mount" then
        entry = { kind = "mount", id = info1 }
    elseif cursorType == "macro" then
        local name, icon, body = GetMacroInfo(info1)
        entry = { kind = "macro", name = name, icon = icon, text = body }
    end
    -- only accept it if it actually resolves, so nothing unusable reaches the radial
    if entry and RM():ResolveEntry(entry) then
        ClearCursor()
        return entry
    end
    return nil
end

-- the guillemet that marks a sub-radial in every list, written as bytes so the file stays ASCII
local CHEVRON = "\194\187 "

local function EntryDisplay(entry)
    local info = entry and RM():ResolveEntry(entry)
    -- A sub-radial reads as the radial, so the list stays stable whichever child happens to be armed.
    -- It keeps its name even when it resolves to nothing, otherwise an empty radial would look broken
    -- rather than simply empty.
    if entry and entry.kind == "subradial" then
        local data = RM():GetRadial(entry.radial)
        if data then
            return CHEVRON .. data.name, info and info.icon or { texture = FALLBACK_ICON }
        end
    end
    if info then return info.name, info.icon end
    return "|cff808080unavailable|r", { texture = FALLBACK_ICON }
end

local function ApplyIcon(owner, icon)
    if icon and icon.atlas then
        owner.Icon:SetTexCoord(0, 1, 0, 1)
        owner.Icon:SetAtlas(icon.atlas)
    else
        owner.Icon:SetTexture((icon and icon.texture) or FALLBACK_ICON)
        owner.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end
end

--------------------------------------------------
-- CATEGORY BROWSERS
-- Listed in the order they are declared, which is the order they appear along the bottom.
--------------------------------------------------
local CATEGORIES = {}

local function AddCategory(key, label, build, note)
    CATEGORIES[#CATEGORIES + 1] = { key = key, label = label, build = build, note = note }
end

AddCategory("panels", L["Panels"], function()
    local panels, out = RM().MICRO_PANELS, {}
    for key in pairs(panels) do out[#out + 1] = { kind = "micromenu", panel = key } end
    table.sort(out, function(a, b) return panels[a.panel].order < panels[b.panel].order end)
    return out
end)

AddCategory("spells", L["Spells"], function()
    local out = {}
    local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(line)
        if lineInfo and not lineInfo.shouldHide then
            for offset = 1, lineInfo.numSpellBookItems do
                local info = C_SpellBook.GetSpellBookItemInfo(lineInfo.itemIndexOffset + offset, bank)
                if info and info.spellID and not info.isPassive then
                    out[#out + 1] = { kind = "spell", id = info.spellID }
                end
            end
        end
    end
    return out
end)

AddCategory("items", L["Items"], function()
    local out, seen = {}, {}
    if not C_Container then return out end
    for bag = 0, 5 do
        for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local itemID = info and info.itemID
            if itemID and not seen[itemID] then
                seen[itemID] = true
                out[#out + 1] = { kind = "item", id = itemID }
            end
        end
    end
    return out
end)

AddCategory("macros", L["Macros"], function()
    local out = {}
    local global, perChar = GetNumMacros()
    -- per-character macros are indexed after the account block, whose size lives in Constants
    local accountMax = Constants.MacroConsts.MAX_ACCOUNT_MACROS
    for i = 1, (global or 0) do
        local name, icon, body = GetMacroInfo(i)
        if name then out[#out + 1] = { kind = "macro", name = name, icon = icon, text = body } end
    end
    for i = 1, (perChar or 0) do
        local name, icon, body = GetMacroInfo(accountMax + i)
        if name then out[#out + 1] = { kind = "macro", name = name, icon = icon, text = body } end
    end
    return out
end)

AddCategory("markers", L["Markers"], function()
    local out = {}
    for i = 1, 8 do out[#out + 1] = { kind = "targetmarker", marker = i } end
    out[#out + 1] = { kind = "targetmarker", marker = 0 }
    for i = 1, 8 do out[#out + 1] = { kind = "worldmarker", marker = i } end
    out[#out + 1] = { kind = "worldmarker", marker = 0 }
    return out
end)

AddCategory("mounts", L["Mounts"], function()
    local out = {}
    for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
        local _, _, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
        if isCollected then out[#out + 1] = { kind = "mount", id = mountID } end
    end
    return out
end)

-- A radial must never end up inside itself, directly or through a chain. Resolution already refuses
-- to follow the loop, but a radial that could only ever be a dead end is better left out of the list.
local function ContainsRadial(radialID, targetID, depth)
    depth = depth or 0
    if radialID == targetID then return true end
    if depth > 6 then return true end
    local data = RM():GetRadial(radialID)
    if not data then return false end
    for _, button in ipairs(data.buttons) do
        if button.kind == "subradial" and ContainsRadial(button.radial, targetID, depth + 1) then return true end
    end
    return false
end

AddCategory("radials", L["Radials"], function()
    local out = {}
    for _, id in ipairs(RM():GetRadialOrder()) do
        if not ContainsRadial(id, editingID) then out[#out + 1] = { kind = "subradial", radial = id } end
    end
    return out
end, L["Creates sub-radials. Use the mouse wheel while hovering it in the radial menu to flip through its buttons."])

--------------------------------------------------
-- DRAG
--------------------------------------------------
local ghost

local function StopDrag()
    dragging = nil
    if ghost then ghost:Hide() end
end

local function StartDrag(payload)
    dragging = payload
    if not ghost then
        ghost = CreateFrame("Frame", nil, UIParent)
        ghost:SetSize(32, 32)
        ghost:SetFrameStrata("TOOLTIP")
        ghost.Icon = ghost:CreateTexture(nil, "OVERLAY")
        ghost.Icon:SetAllPoints()
        ghost:SetScript("OnUpdate", function(self)
            local scale = UIParent:GetEffectiveScale()
            local x, y = GetCursorPosition()
            self:ClearAllPoints()
            self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
        end)
    end
    local _, icon = EntryDisplay(payload.entry)
    ApplyIcon(ghost, icon)
    ghost:Show()
end

--------------------------------------------------
-- EDITING
--------------------------------------------------
local Refresh   -- forward declaration; rebuilds every part of the window

local function CurrentRadial()
    local rm = RM()
    if not rm then return nil end
    local radial = editingID and rm:GetRadial(editingID)
    if radial then return radial end
    editingID = rm:GetAssignedRadialID() or rm:GetRadialOrder()[1]
    return editingID and rm:GetRadial(editingID) or nil
end

local function Changed()
    dirty = true
    RM():RadialChanged(editingID)
    if ns.RefreshRadialOptions then ns.RefreshRadialOptions() end
end

local function InsertEntry(entry, atIndex)
    local radial = CurrentRadial()
    if not (radial and entry) then return end
    if #radial.buttons >= RM().MAX_BUTTONS then
        print("|cffff9900FlareUI:|r " .. L["that radial is full (%d buttons)."]:format(RM().MAX_BUTTONS))
        return
    end
    atIndex = atIndex or (#radial.buttons + 1)
    table.insert(radial.buttons, atIndex, entry)
    selectedButton = atIndex
    Changed()
    Refresh()
end

local function MoveButton(from, to)
    local radial = CurrentRadial()
    if not radial then return end
    to = math.max(1, math.min(#radial.buttons, to))
    if from == to then return end
    table.insert(radial.buttons, to, table.remove(radial.buttons, from))
    selectedButton = to
    Changed()
    Refresh()
end

local function RemoveButton(index)
    local radial = CurrentRadial()
    if not (radial and radial.buttons[index]) then return end
    table.remove(radial.buttons, index)
    if selectedButton and selectedButton > #radial.buttons then selectedButton = #radial.buttons end
    Changed()
    Refresh()
end

-- The drop target is worked out here rather than in OnReceiveDrag, because nothing is on the game's
-- cursor during an internal drag and so OnReceiveDrag never fires.
local function FinishDrag()
    local payload = dragging
    StopDrag()
    if not (payload and editor) then return end

    local target
    for _, cell in ipairs(editor.buttonList.cells) do
        if cell:IsShown() and cell.dataIndex and cell:IsMouseOver() then
            target = cell.dataIndex
            break
        end
    end
    local overList = editor.buttonList:IsMouseOver() or editor.dropZone:IsMouseOver()

    if payload.from then
        if target then
            MoveButton(payload.from, target)
        elseif overList then
            MoveButton(payload.from, #(CurrentRadial() or { buttons = {} }).buttons)
        else
            RemoveButton(payload.from)   -- dragged off the list entirely
        end
    elseif payload.entry then
        if target then
            InsertEntry(payload.entry, target)
        elseif overList then
            InsertEntry(payload.entry)
        end
    end
end

--------------------------------------------------
-- UNDOING CHANGES
-- Only the four fields the editor can touch are copied; the key binding and the character roster
-- are not its business and are left alone.
--------------------------------------------------
local function TakeSnapshot()
    local store = RM().GetStore()
    dirty = false
    if not store then snapshot = nil return end
    snapshot = {
        radials      = CopyTable(store.radials),
        radialOrder  = CopyTable(store.radialOrder),
        nextRadialID = store.nextRadialID,
    }
end

local function RestoreSnapshot()
    local store = RM().GetStore()
    if not (store and snapshot and dirty) then return end
    -- the store table itself is kept, because other things hold a reference to it
    store.radials      = CopyTable(snapshot.radials)
    store.radialOrder  = CopyTable(snapshot.radialOrder)
    store.nextRadialID = snapshot.nextRadialID
    dirty = false
    RM():RadialChanged()
    if ns.RefreshRadialOptions then ns.RefreshRadialOptions() end
end

-- Closing the window any way but Confirm or Cancel - Escape, /fui re again, anything else that hides
-- it - with edits pending asks what to do with them rather than throwing them away unasked. The edits
-- stay in place while the question is open (they are already live), and Escape cannot answer it.
local unsavedPending = false

ns.Dialogs["FLAREUI_RADIAL_UNSAVED"] = {
    text = L["You have unsaved changes to your radials."],
    button1 = L["Save"],
    button2 = L["Discard"],
    OnAccept = function()
        unsavedPending, dirty, snapshot = false, false, nil
    end,
    OnCancel = function()
        unsavedPending = false
        RestoreSnapshot()
    end,
    hideOnEscape = false,
}

-- Delete asks first. The answer acts on the radial the question named, even if the dropdown moved on.
ns.Dialogs["FLAREUI_RADIAL_DELETE"] = {
    text = L["Delete the radial |cffffff00%s|r?"],
    button1 = L["Delete"],
    button2 = L["Cancel"],
    OnAccept = function(data)
        if not (data and data.id and RM():GetRadial(data.id)) then return end
        RM():DeleteRadial(data.id)
        if editingID == data.id then editingID, selectedButton = nil, nil end
        Changed()
        Refresh()
    end,
    hideOnEscape = true,
    showAlert = true,
}

--------------------------------------------------
-- NAME POPUP
-- The name is asked for up front rather than left in a box on the toolbar to be found. The same
-- popup names a new radial and renames the current one; popup.renaming says which.
--------------------------------------------------
local popup

local function ShowNamePopup(renaming)
    if not popup then
        popup = CreateFrame("Frame", "FlareUI_RadialEditorNewRadial", UIParent, "BackdropTemplate")
        popup:SetSize(320, 116)
        popup:SetFrameStrata("FULLSCREEN_DIALOG")
        popup:SetToplevel(true)
        popup:EnableMouse(true)
        popup:SetBackdrop({ edgeFile = LSM:Fetch("border", "Blizzard Tooltip"), edgeSize = 16 })
        popup:SetBackdropBorderColor(BRONZE[1], BRONZE[2], BRONZE[3], 1)
        Fade(popup, 5, BG_TOP, BG_BOTTOM)
        popup:Hide()
        tinsert(UISpecialFrames, "FlareUI_RadialEditorNewRadial")
        popup:SetScript("OnShow", ns.WindowOpenSound)
        popup:SetScript("OnHide", ns.WindowCloseSound)

        local label = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOP", 0, -16)
        popup.label = label

        local box = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
        box:SetSize(250, 20)
        box:SetPoint("TOP", label, "BOTTOM", 6, -12)
        box:SetAutoFocus(true)
        popup.box = box

        local function Accept()
            local name = strtrim(box:GetText())
            if name == "" then return end
            if popup.renaming then
                RM():RenameRadial(editingID, name)
            else
                editingID, selectedButton = RM():CreateRadial(name), nil
            end
            ns.ButtonSound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            popup:Hide()
            Changed()
            Refresh()
        end

        local accept = RedButton(popup, L["Create"], 90, Accept, false)
        accept:SetPoint("BOTTOMRIGHT", popup, "BOTTOM", -4, 14)
        popup.accept = accept
        local cancel = RedButton(popup, L["Cancel"], 90, function() popup:Hide() end)
        cancel:SetPoint("BOTTOMLEFT", popup, "BOTTOM", 4, 14)

        box:SetScript("OnEnterPressed", Accept)
        box:SetScript("OnEscapePressed", function() popup:Hide() end)
    end

    local radial = renaming and editingID and RM():GetRadial(editingID)
    if renaming and not radial then return end
    popup.renaming = renaming and true or nil
    popup.label:SetText(renaming and "Rename the radial" or "Name the new radial")
    popup.accept:SetText(renaming and "Rename" or "Create")

    popup:ClearAllPoints()
    popup:SetPoint("CENTER", editor or UIParent, "CENTER", 0, 60)
    popup.box:SetText(renaming and radial.name or "New Radial")
    popup.box:HighlightText()
    popup:Show()
    popup.box:SetFocus()
end

--------------------------------------------------
-- BUILD
--------------------------------------------------
local function BuildWindow()
    if editor then return end

    editor = CreateFrame("Frame", "FlareUI_RadialEditor", UIParent, "BackdropTemplate")
    editor:SetSize(WINDOW_W, WINDOW_H)
    editor:SetPoint("CENTER")
    editor:SetFrameStrata("HIGH")
    editor:SetToplevel(true)
    editor:EnableMouse(true)
    editor:SetMovable(true)
    editor:RegisterForDrag("LeftButton")
    editor:SetScript("OnDragStart", editor.StartMoving)
    editor:SetScript("OnDragStop", editor.StopMovingOrSizing)
    editor:SetBackdrop({ edgeFile = LSM:Fetch("border", "Blizzard Tooltip"), edgeSize = 16 })
    editor:SetBackdropBorderColor(BRONZE[1], BRONZE[2], BRONZE[3], 1)
    Fade(editor, 5, BG_TOP, BG_BOTTOM)
    editor:Hide()
    tinsert(UISpecialFrames, "FlareUI_RadialEditor")

    -- There is no close button: the footer's two buttons are the way out. Anything else that hides
    -- the window - Escape, or /fui re a second time - asks whether to keep the edits (see
    -- FLAREUI_RADIAL_UNSAVED above).
    editor:SetScript("OnShow", ns.WindowOpenSound)
    editor:SetScript("OnHide", function(self)
        ns.WindowCloseSound()
        if self.confirmed then
            dirty, snapshot = false, nil
        elseif self.cancelled or not dirty then
            RestoreSnapshot()
        else
            -- a frame later, so the prompt is not caught up in the Escape that closed the window
            unsavedPending = true
            C_Timer.After(0, function()
                if unsavedPending then ns.ShowDialog("FLAREUI_RADIAL_UNSAVED") end
            end)
        end
        self.confirmed, self.cancelled = nil, nil
        if popup then popup:Hide() end
        if RM() then RM():HidePreview() end
        StopDrag()
        -- Put the settings window back if opening this one displaced it - a frame later. On Esc this
        -- runs inside CloseSpecialWindows, which AceConfigDialog wraps to close all of its own windows
        -- straight afterwards (AceConfigDialog-3.0.lua:1852), so reopening now would be undone at
        -- once. Quietly: this window closing has already made the sound.
        if self.reopenSettings then
            self.reopenSettings = nil
            C_Timer.After(0, function()
                ns.quietWindows = true
                pcall(AceConfigDialog.Open, AceConfigDialog, "FlareUI")
                if ns.ForceOpacity then ns.ForceOpacity() end
                ns.quietWindows = nil
            end)
        end
    end)

    ---------------- header ----------------
    local header = Panel(editor)
    header:SetPoint("TOPLEFT", PAD, -PAD)
    header:SetPoint("TOPRIGHT", -PAD, -PAD)
    header:SetHeight(HEADER_H)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", 12, 0)
    title:SetText(L["Radial Editor"])

    -- The controls sit at the right, so the header reads title on one side, controls on the other,
    -- and a long radial name grows away from the title rather than into it.
    -- The same dropdown the FlareUI settings use, so the radial picker looks alike in both places.
    -- Made once and never released, so AceGUI's pool never hands it on to anyone else.
    local radialDrop = AceGUI:Create("Dropdown")
    radialDrop:SetLabel("")
    radialDrop:SetWidth(180)
    radialDrop.frame:SetParent(header)
    radialDrop.frame:Show()
    radialDrop:SetCallback("OnValueChanged", function(_, _, id)
        editingID, selectedButton = id, nil
        Refresh()
    end)
    editor.radialDrop = radialDrop

    editor.deleteButton = RedButton(header, L["Delete"], 80, function()
        local radial = editingID and RM():GetRadial(editingID)
        if not radial then return end
        ns.ShowDialog("FLAREUI_RADIAL_DELETE", radial.name or "", { id = editingID })
    end)
    editor.deleteButton:SetPoint("RIGHT", -12, 0)

    local newButton = RedButton(header, L["New Radial"], 90, function() ShowNamePopup(false) end)
    newButton:SetPoint("RIGHT", editor.deleteButton, "LEFT", -8, 0)
    editor.newButton = newButton

    editor.renameButton = RedButton(header, L["Rename"], 80, function() ShowNamePopup(true) end)
    editor.renameButton:SetPoint("RIGHT", newButton, "LEFT", -8, 0)
    radialDrop.frame:ClearAllPoints()
    radialDrop.frame:SetPoint("RIGHT", editor.renameButton, "LEFT", -8, 0)

    ---------------- buttons ----------------
    local buttonPanel = Panel(editor,
        "Buttons  |cff808080(drag to reorder, right-click to remove)|r")
    buttonPanel:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -GAP)
    buttonPanel:SetSize(LEFT_W, BODY_H)

    local buttonList = CreateList(buttonPanel, LEFT_W - 16, 1, BUTTON_ROWS, BUTTON_ROW_H,
        function(cell)
            cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            cell:RegisterForDrag("LeftButton")
            cell:SetScript("OnDragStart", function(self)
                if self.dataIndex then StartDrag({ from = self.dataIndex, entry = self.item }) end
            end)
            cell:SetScript("OnDragStop", FinishDrag)
            cell:SetScript("OnClick", function(self, mouseButton)
                if not self.dataIndex then return end
                if mouseButton == "RightButton" then
                    RemoveButton(self.dataIndex)
                else
                    selectedButton = self.dataIndex
                    Refresh()
                end
            end)
        end,
        function(cell, entry, index)
            local name, icon = EntryDisplay(entry)
            ApplyIcon(cell, icon)
            cell.Text:SetText(index .. ".  " .. name)
            cell.Highlight:SetShown(index == selectedButton)
        end)
    buttonList:SetPoint("TOPLEFT", 8, -26)
    editor.buttonList = buttonList

    -- Sits behind the rows and catches drops onto empty space, plus real cursor drops from
    -- Blizzard's windows (those do fire OnReceiveDrag, because the game's cursor is loaded).
    local dropZone = CreateFrame("Frame", nil, buttonPanel)
    dropZone:SetPoint("TOPLEFT", buttonList, "TOPLEFT")
    dropZone:SetPoint("BOTTOMRIGHT", buttonList, "BOTTOMRIGHT", 0, -6)
    dropZone:SetFrameLevel(buttonList:GetFrameLevel() - 1)
    dropZone:EnableMouse(true)
    dropZone:RegisterForDrag("LeftButton")
    dropZone:SetScript("OnReceiveDrag", function()
        local entry = EntryFromCursor()
        if entry then InsertEntry(entry) end
    end)
    dropZone:SetScript("OnMouseUp", function()
        local entry = EntryFromCursor()
        if entry then InsertEntry(entry) end
    end)
    editor.dropZone = dropZone

    ---------------- preview ----------------
    local previewPanel = Panel(editor)
    previewPanel:SetPoint("TOPLEFT", buttonPanel, "TOPRIGHT", GAP, 0)
    previewPanel:SetSize(PREVIEW_W, BODY_H)

    local previewLabel = previewPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    previewLabel:SetPoint("TOP", 0, -8)
    previewLabel:SetText(L["Live Preview"])

    -- the radial centres in what is left below the title, not in the panel as a whole
    local previewArea = CreateFrame("Frame", nil, previewPanel)
    previewArea:SetPoint("TOPLEFT", 8, -26)
    previewArea:SetPoint("BOTTOMRIGHT", -8, 8)
    editor.previewArea = previewArea

    ---------------- browser ----------------
    local browsePanel = Panel(editor,
        "Add Buttons  |cff808080(drag one onto the list, or click to append)|r")
    browsePanel:SetPoint("TOPLEFT", buttonPanel, "BOTTOMLEFT", 0, -GAP)
    browsePanel:SetPoint("TOPRIGHT", previewPanel, "BOTTOMRIGHT", 0, -GAP)
    browsePanel:SetHeight(BROWSE_H)

    editor.tabs = {}
    local previous
    for _, category in ipairs(CATEGORIES) do
        local tab = RedButton(browsePanel, category.label, TAB_W, function()
            activeCategory = category.key
            Refresh()
        end)
        if previous then
            tab:SetPoint("LEFT", previous, "RIGHT", TAB_GAP, 0)
        else
            tab:SetPoint("TOPLEFT", 8, -26)
        end
        tab.category = category
        editor.tabs[#editor.tabs + 1] = tab
        previous = tab
    end

    -- Always present, so switching category never shifts the list out from under the cursor. Only
    -- the Radials category currently has anything to say.
    local note = browsePanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", editor.tabs[1], "BOTTOMLEFT", 0, -5)
    note:SetJustifyH("LEFT")
    editor.note = note

    local browseList = CreateList(browsePanel, WINDOW_W - 2 * PAD - 16, BROWSE_COLS, BROWSE_ROWS,
        BROWSE_ROW_H,
        function(cell)
            cell:RegisterForDrag("LeftButton")
            cell:SetScript("OnDragStart", function(self)
                if self.item then StartDrag({ entry = self.item }) end
            end)
            cell:SetScript("OnDragStop", FinishDrag)
            cell:SetScript("OnClick", function(self)
                if self.item then InsertEntry(self.item) end
            end)
        end,
        function(cell, entry)
            local name, icon = EntryDisplay(entry)
            ApplyIcon(cell, icon)
            cell.Text:SetText(name)
        end)
    browseList:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -5)
    editor.browseList = browseList

    ---------------- footer ----------------
    local footer = Panel(editor)
    footer:SetPoint("BOTTOMLEFT", PAD, PAD)
    footer:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    footer:SetHeight(FOOTER_H)

    -- SearchBoxTemplate brings its own magnifying glass, placeholder text and clear button
    local search = CreateFrame("EditBox", nil, footer, "SearchBoxTemplate")
    search:SetSize(220, 20)
    search:SetPoint("LEFT", 12, 0)
    search:HookScript("OnTextChanged", function() Refresh() end)
    editor.search = search

    editor.confirmButton = RedButton(footer, L["Confirm"], 100, function()
        editor.confirmed = true
        editor:Hide()
    end, SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    editor.confirmButton:SetPoint("RIGHT", -12, 0)

    editor.cancelButton = RedButton(footer, L["Cancel"], 100, function()
        editor.cancelled = true
        editor:Hide()
    end)
    editor.cancelButton:SetPoint("RIGHT", editor.confirmButton, "LEFT", -8, 0)
end

--------------------------------------------------
-- REFRESH
--------------------------------------------------
local browseCache = {}

function Refresh()
    if not (editor and editor:IsShown()) then return end
    local rm = RM()
    local radial = CurrentRadial()

    -- the list is rebuilt only when a radial was added, renamed or removed
    local list, order, signature = {}, {}, ""
    for _, id in ipairs(rm:GetRadialOrder()) do
        local data = rm:GetRadial(id)
        if data then
            list[id], order[#order + 1] = data.name, id
            signature = signature .. id .. "=" .. data.name .. ";"
        end
    end
    if signature ~= editor.radialSignature then
        editor.radialSignature = signature
        editor.radialDrop:SetList(list, order)
    end
    editor.radialDrop:SetValue(radial and editingID or nil)
    if not radial then editor.radialDrop:SetText(L["No radials"]) end
    editor.radialDrop:SetDisabled(radial == nil)
    editor.deleteButton:SetEnabled(radial ~= nil)
    editor.renameButton:SetEnabled(radial ~= nil)
    editor.buttonList:SetData(radial and radial.buttons or {})

    -- nothing to keep and nothing to throw away until something has actually been edited
    editor.cancelButton:SetEnabled(dirty == true)
    editor.confirmButton:SetEnabled(dirty == true)

    activeCategory = activeCategory or CATEGORIES[1].key
    local category
    for _, tab in ipairs(editor.tabs) do
        tab:SetEnabled(tab.category.key ~= activeCategory)
        if tab.category.key == activeCategory then category = tab.category end
    end
    editor.note:SetText((category and category.note) or "")

    -- The cache is not cleared per refresh: enumerating the spellbook on every click would be
    -- wasteful. It is cleared when the window opens, which is often enough - except for Radials,
    -- which depends on which radial is being edited and so is rebuilt each time.
    if activeCategory == "radials" then browseCache.radials = nil end
    local entries = browseCache[activeCategory]
    if not entries then
        entries = (category and category.build()) or {}
        browseCache[activeCategory] = entries
    end

    local filter = editor.search:GetText():lower()
    if filter ~= "" then
        local shown = {}
        for _, entry in ipairs(entries) do
            if EntryDisplay(entry):lower():find(filter, 1, true) then shown[#shown + 1] = entry end
        end
        entries = shown
    end
    editor.browseList:SetData(entries)

    if rm and editingID then rm:ShowPreview(editingID, editor.previewArea) end
end

--------------------------------------------------
-- PUBLIC
--------------------------------------------------
function ns.ShowRadialEditor()
    if not RM() or not RM().initialized then
        print("|cffff4040FlareUI:|r " .. L["the Radial Menu module is not enabled."])
        return
    end
    BuildWindow()
    browseCache = {}
    if unsavedPending then
        -- back to the edits the prompt was asking about: carry on with them and the same snapshot
        unsavedPending = false
        ns.HideDialog("FLAREUI_RADIAL_UNSAVED")
    else
        TakeSnapshot()
    end
    -- the settings window would sit on top of this one, so it stands aside and comes back after
    if AceConfigDialog.OpenFrames["FlareUI"] then
        editor.reopenSettings = true
        -- quietly: the editor opening is the one sound this hand-over makes
        ns.quietWindows = true
        pcall(AceConfigDialog.Close, AceConfigDialog, "FlareUI")
        ns.quietWindows = nil
    end
    editor:Show()
    Refresh()
end

function ns.ToggleRadialEditor()
    if editor and editor:IsShown() then editor:Hide() else ns.ShowRadialEditor() end
end

-- For the controller navigation (ControllerNav.lua): the window and the two verbs a pad needs that
-- the mouse gets from dragging and right-clicking.
ns.RadialEditorPad = {
    Frame = function() return editor end,
    NamePopupShown = function() return popup ~= nil and popup:IsShown() end,
    Move = function(from, to) MoveButton(from, to) end,
    Remove = function(index) RemoveButton(index) end,
    ActiveCategory = function() return activeCategory end,
}
