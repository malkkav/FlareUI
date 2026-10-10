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
-- It lives in the settings panel's Radial Menu page (BuildEmbedded).
--------------------------------------------------
local LSM = LibStub("LibSharedMedia-3.0")

local BRONZE       = { 0.80, 0.60, 0.34 }
local BRONZE_MUTED = { 0.61, 0.48, 0.29 }
local FALLBACK_ICON = 134400

-- the settings panel's gradient
local BG_TOP       = { 0.085, 0.075, 0.060, 0.95 }
local BG_BOTTOM    = { 0.015, 0.015, 0.015, 0.95 }

local editor, editingID, selectedButton, dragging, activeCategory
local browseCache = {}   -- category -> its entries, built once per opening
local snapshot, dirty

local function RM() return ns.RadialMenu end

local function Sound(key)
    if SOUNDKIT and SOUNDKIT[key] then PlaySound(SOUNDKIT[key]) end
end

--------------------------------------------------
-- PIECES
--------------------------------------------------
local Fade = ns.Fade   -- Core.lua

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

-- minimal: the settings panel's thin scroll line instead of the classic slider (the Gamepad UI's
-- window)
local function CreateList(parent, width, columns, rows, cellHeight, buildCell, fillCell, minimal)
    local list = CreateFrame("Frame", nil, parent)
    local cellWidth = (width - (minimal and 12 or 22)) / columns
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

    list.offset, list.maxOffset = 0, 0

    function list:Update()
        local offset = self.offset * columns
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

    local bar, slider
    -- the scroll bar follows list.offset (rows scrolled), and moves it when dragged
    local function SetOffset(offset)
        offset = math.max(0, math.min(list.maxOffset, math.floor(offset + 0.5)))
        if offset == list.offset then return end
        list.offset = offset
        list:Update()
    end

    if minimal then
        bar = ns.SettingsPanel.ScrollLine(list)
        bar:SetPoint("TOPRIGHT", 0, 0)
        bar:SetPoint("BOTTOMRIGHT", 0, 0)
        bar.onScroll = function(position)
            SetOffset(position * list.maxOffset)
            bar:SetValues(bar.visible, list.maxOffset > 0 and list.offset / list.maxOffset or 0)
        end
    else
        scrollBars = scrollBars + 1
        slider = CreateFrame("Slider", "FlareUI_RadialEditorScroll" .. scrollBars, list, "UIPanelScrollBarTemplate")
        slider:SetOrientation("VERTICAL")
        -- the arrow buttons sit outside the track, so the track is inset to leave room for them
        slider:SetPoint("TOPRIGHT", 0, -18)
        slider:SetPoint("BOTTOMRIGHT", 0, 18)
        slider:SetWidth(16)
        slider:SetValueStep(1)
        slider:SetObeyStepOnDrag(true)
        -- the template's own handlers drive a ScrollFrame parent, which this is not
        slider:SetScript("OnValueChanged", function(_, value) SetOffset(value or 0) end)
        local function Step(delta)
            slider:SetValue((slider:GetValue() or 0) + delta)
            Sound("U_CHAT_SCROLL_BUTTON")
        end
        -- the arrows come from the template, so they are not assumed to be there
        if slider.ScrollUpButton then
            slider.ScrollUpButton:SetScript("OnClick", function() Step(-1) end)
            slider.ScrollDownButton:SetScript("OnClick", function() Step(1) end)
        end
    end
    list.slider = slider

    local function SyncBar()
        if bar then
            local total = math.max(rows, math.ceil(#list.data / columns))
            bar:SetValues(rows / total, list.maxOffset > 0 and list.offset / list.maxOffset or 0)
        else
            slider:SetMinMaxValues(0, list.maxOffset)
            slider:SetValue(list.offset)
            slider:SetShown(list.maxOffset > 0)
        end
    end

    function list:SetData(data)
        self.data = data or {}
        self.maxOffset = math.max(0, math.ceil(#self.data / columns) - rows)
        if self.offset > self.maxOffset then self.offset = self.maxOffset end
        SyncBar()
        self:Update()
    end

    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        SetOffset(list.offset - delta)
        SyncBar()
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

AddCategory("emotes", L["Emotes"], function()
    local out = {}
    for _, e in ipairs(RM().EMOTES or {}) do out[#out + 1] = { kind = "emote", emote = e.token } end
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
    for _, id in ipairs(RM():GetRadialsByName()) do
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

-- Picking a radial here only chooses what is edited: the bar under the panel says where the key's
-- radial is chosen
local function RemindKeybinds()
    if ns.SettingsPanel and ns.SettingsPanel.SetNotice then
        ns.SettingsPanel:SetNotice(L["Make sure to select what radial you want to use in the Keybind tab!"])
    end
end

local function Changed()
    dirty = true
    RM():RadialChanged(editingID)
    RemindKeybinds()
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
end

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
-- BUILD, INSIDE THE SETTINGS PANEL
-- The Radial Menu page's Buttons tab: the radial picker along the top, the radial's buttons, then
-- the browser; the live preview takes the panel's right column. Edits are live, as in the window;
-- Undo changes puts back what the radials were when the tab was opened.
--------------------------------------------------
local EMBED_WIDTH = 484          -- the panel's middle column
local EMBED_LIST_W = 70          -- the radial's buttons: a column of icons and numbers down the left
local EMBED_ICON_ROW_H = 40      -- its rows (icons 32 px)
local EMBED_ROW_H = 26

local function BuildEmbedded(host, previewHost)
    editor = host
    host.embedded = true
    local height = host:GetHeight() > 0 and host:GetHeight() or 390

    -- the radial picker and its buttons, across the top
    local pickerLabel = host:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pickerLabel:SetPoint("TOPLEFT", 4, -12)
    pickerLabel:SetText(L["Radial"])
    local picker = CreateFrame("DropdownButton", nil, host, "WowStyle1DropdownTemplate")
    picker:SetWidth(180)
    picker:SetPoint("LEFT", pickerLabel, "RIGHT", 8, 0)
    host.UpdatePicker = function(list, order, value)
        picker:SetupMenu(function(_, root)
            for _, id in ipairs(order) do
                root:CreateRadio(list[id], function() return editingID == id end, function()
                    editingID, selectedButton = id, nil
                    Refresh()
                    RemindKeybinds()
                end)
            end
        end)
        picker:SetEnabled(value ~= nil)
        if not value and picker.OverrideText then picker:OverrideText(L["No radials"]) end
    end
    host.deleteButton = RedButton(host, L["Delete"], 70, function()
        local radial = editingID and RM():GetRadial(editingID)
        if not radial then return end
        ns.ShowDialog("FLAREUI_RADIAL_DELETE", radial.name or "", { id = editingID })
    end)
    host.deleteButton:SetPoint("TOPRIGHT", -2, -8)
    host.renameButton = RedButton(host, L["Rename"], 70, function() ShowNamePopup(true) end)
    host.renameButton:SetPoint("RIGHT", host.deleteButton, "LEFT", -4, 0)
    host.newButton = RedButton(host, L["New"], 60, function() ShowNamePopup(false) end)
    host.newButton:SetPoint("RIGHT", host.renameButton, "LEFT", -4, 0)

    local top = 54   -- below the picker row and its line, with room on both sides of the line
    local line = host:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(BRONZE_MUTED[1], BRONZE_MUTED[2], BRONZE_MUTED[3], 0.6)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 0, -top + 12)
    line:SetPoint("TOPRIGHT", 0, -top + 12)

    -- the radial's buttons: a narrow list to the bottom, Undo changes under it
    local buttonsTitle = host:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    buttonsTitle:SetPoint("TOPLEFT", 4, -top - 4)
    buttonsTitle:SetText(L["Buttons"])
    local listTop = top + 24
    local listRows = math.max(4, math.floor((height - listTop - 4) / EMBED_ICON_ROW_H))
    local buttonList = CreateList(host, EMBED_LIST_W, 1, listRows, EMBED_ICON_ROW_H,
        function(cell)
            cell:SetScript("OnEnter", function(self)
                if not self.item then return end
                ns.OwnGameTooltip(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine((EntryDisplay(self.item)), 1, 1, 1)
                GameTooltip:AddLine(L["Drag to reorder, right-click to remove."], 0.6, 0.6, 0.6, true)
                GameTooltip:Show()
            end)
            cell.Text:SetFontObject("GameFontHighlight")
            -- the number first, then the icon
            cell.Text:ClearAllPoints()
            cell.Text:SetPoint("LEFT", 0, 0)
            cell.Text:SetWidth(16)
            cell.Text:SetJustifyH("RIGHT")
            cell.Icon:ClearAllPoints()
            cell.Icon:SetPoint("LEFT", cell.Text, "RIGHT", 6, 0)
            cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
            local _, icon = EntryDisplay(entry)
            ApplyIcon(cell, icon)
            cell.Text:SetText(index)
            cell.Highlight:SetShown(index == selectedButton)
        end, true)
    buttonList:SetPoint("TOPLEFT", 0, -listTop)
    host.buttonList = buttonList

    local dropZone = CreateFrame("Frame", nil, host)
    dropZone:SetPoint("TOPLEFT", buttonList, "TOPLEFT")
    dropZone:SetPoint("BOTTOMRIGHT", buttonList, "BOTTOMRIGHT", 0, -6)
    dropZone:SetFrameLevel(math.max(0, buttonList:GetFrameLevel() - 1))
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
    host.dropZone = dropZone

    local divider = host:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(BRONZE_MUTED[1], BRONZE_MUTED[2], BRONZE_MUTED[3], 0.6)
    divider:SetWidth(1)
    divider:SetPoint("TOPLEFT", EMBED_LIST_W + 8, -top - 4)
    divider:SetPoint("BOTTOMLEFT", EMBED_LIST_W + 8, 4)

    -- the browser: a category menu and search, then two columns of things to drag, to the bottom
    local rightX = EMBED_LIST_W + 18
    local rightW = EMBED_WIDTH - rightX
    -- "Catalog" and its category menu across the top; the search sits at the bottom, beside Undo
    local catalogTitle = host:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    catalogTitle:SetPoint("TOPLEFT", rightX + 4, -top - 4)
    catalogTitle:SetText(L["Catalog"])
    local category = CreateFrame("DropdownButton", nil, host, "WowStyle1DropdownTemplate")
    category:SetWidth(170)
    category:SetPoint("TOPRIGHT", host, "TOPRIGHT", -2, -top + 2)
    host.categoryDrop = category
    local search = CreateFrame("EditBox", nil, host, "SearchBoxTemplate")
    search:SetHeight(20)
    search:SetPoint("BOTTOMLEFT", rightX + 8, 8)
    search:SetPoint("RIGHT", host, "RIGHT", -152, 0)
    search:HookScript("OnTextChanged", function() Refresh() end)
    host.search = search
    local note = host:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", rightX, -top - 32)
    note:SetPoint("RIGHT", -2, 0)
    note:SetJustifyH("LEFT")
    host.note = note
    local browseRows = math.max(4, math.floor((height - top - 52 - 34) / EMBED_ROW_H))
    local browseList = CreateList(host, rightW, 2, browseRows, EMBED_ROW_H,
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
        end, true)
    browseList:SetPoint("TOPLEFT", rightX, -top - 46)
    host.browseList = browseList
    host.undoButton = RedButton(host, L["Undo changes"], 140, function()
        RestoreSnapshot()
        TakeSnapshot()
        Refresh()
        RemindKeybinds()
    end)
    host.undoButton:SetPoint("BOTTOMRIGHT", -2, 6)
    -- the embedded editor picks its category from the menu, not from tab buttons
    host.tabs = {}
    host.UpdateCategory = function()
        category:SetupMenu(function(_, root)
            for _, c in ipairs(CATEGORIES) do
                root:CreateRadio(c.label, function() return activeCategory == c.key end, function()
                    activeCategory = c.key
                    Refresh()
                end)
            end
        end)
    end

    -- the live preview, in the right column
    local previewLabel = previewHost:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    previewLabel:SetPoint("TOP", 0, -14)
    previewLabel:SetText(L["Live Preview"])
    local previewArea = CreateFrame("Frame", nil, previewHost)
    previewArea:SetPoint("TOPLEFT", 8, -40)
    previewArea:SetPoint("TOPRIGHT", -8, -40)
    previewArea:SetHeight(230)
    host.previewArea = previewArea
    local hint = previewHost:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", previewArea, "BOTTOMLEFT", 4, -10)
    hint:SetPoint("RIGHT", -12, 0)
    hint:SetJustifyH("LEFT")
    hint:SetSpacing(2)
    hint:SetText(L["Search the Catalog for whatever you want and drag it to the Buttons section.\nDrag buttons to reorder and right-click to remove."])
    local tip = previewHost:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tip:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -10)
    tip:SetPoint("RIGHT", -12, 0)
    tip:SetJustifyH("LEFT")
    tip:SetText(L["Tip:"] .. " " .. L["Set a binding for your radial on the Keybinds tab."])

    -- the tab opening takes the snapshot Undo goes back to; leaving it keeps the edits
    host:SetScript("OnShow", function()
        browseCache = {}
        if not dirty then TakeSnapshot() end
    end)
    host:SetScript("OnHide", function()
        dirty, snapshot = false, nil
        if popup then popup:Hide() end
        if RM() then RM():HidePreview() end
        StopDrag()
    end)
    browseCache = {}
    TakeSnapshot()
end

--------------------------------------------------
-- REFRESH
--------------------------------------------------

function Refresh()
    if not (editor and editor:IsShown()) then return end
    local rm = RM()
    local radial = CurrentRadial()

    -- the list is rebuilt only when a radial was added, renamed or removed
    local list, order, signature = {}, {}, ""
    for _, id in ipairs(rm:GetRadialsByName()) do
        local data = rm:GetRadial(id)
        if data then
            list[id], order[#order + 1] = data.name, id
            signature = signature .. id .. "=" .. data.name .. ";"
        end
    end
    editor.UpdatePicker(list, order, radial and editingID or nil)
    editor.deleteButton:SetEnabled(radial ~= nil)
    editor.renameButton:SetEnabled(radial ~= nil)
    editor.buttonList:SetData(radial and radial.buttons or {})

    -- nothing to keep and nothing to throw away until something has actually been edited
    editor.undoButton:SetEnabled(dirty == true)

    activeCategory = activeCategory or CATEGORIES[1].key
    local category
    for _, c in ipairs(CATEGORIES) do
        if c.key == activeCategory then category = c end
    end
    for _, tab in ipairs(editor.tabs) do
        tab:SetEnabled(tab.category.key ~= activeCategory)
    end
    if editor.UpdateCategory then editor.UpdateCategory() end
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
-- The settings panel's Radial Menu page (Settings/Pages/RadialMenu.lua)
ns.RadialEditorEmbed = {
    Build = BuildEmbedded,
    Refresh = function() if editor then Refresh() end end,
}
