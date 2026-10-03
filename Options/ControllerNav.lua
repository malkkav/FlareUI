local _, ns = ...

--------------------------------------------------
-- CONTROLLER NAVIGATION FOR FLAREUI'S WINDOWS
-- With Blizzard's Gamepad UI on, FlareUI's settings window (AceConfigDialog) and its radial editor
-- are driven by the pad. Blizzard's own navigation (SmartNavigation) is never involved: it clicks a
-- button by running its mouse scripts in place (SmartNavigationMixin:Click), so FlareUI code would
-- run inside Blizzard's gamepad focus manager, the taint that hangs the client (see Dialog.lua). A
-- frame reads the pad itself while one of the windows is open.
--
-- Both windows:
--   D-pad     moves a highlight to the nearest control in that direction, scrolling to it (a list
--             scrolls when the highlight would leave it)
--   A         toggles a checkbox or presses a button. A dropdown opens: up / down pick, A chooses,
--             B closes it. A slider is grabbed: left / right change it, A or B let go
--   B         closes the window (the radial editor asks about unsaved edits first)
--   LB / RB   the previous / next tab (settings: the section's tabs; editor: the browser's categories)
-- Settings:   LT / RT  the previous / next section in the list on the left
-- Editor, on a button of the radial being edited:
--   X         removes it
--   Y         grabs it: up / down move it in the list, A or Y let go
-- The highlighted control shows its tooltip, and icons by the tabs show the shoulder buttons.
-- Colour pickers, keybinds and text boxes stay with the mouse and keyboard. The navigation pauses
-- while a FlareUI dialog or the editor's name box is up (the dialog reads the pad itself).
-- Getting there: the "FlareUI Settings" radial panel, the FlareUI > Open Settings keybinding, /fui;
-- the editor from the settings' Radial Menu page.
--------------------------------------------------
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local APP = "FlareUI"

local PAD_UP, PAD_DOWN = GAMEPAD_DPAD_TOP or "PADDUP", GAMEPAD_DPAD_BOTTOM or "PADDDOWN"
local PAD_LEFT, PAD_RIGHT = GAMEPAD_DPAD_LEFT or "PADDLEFT", GAMEPAD_DPAD_RIGHT or "PADDRIGHT"
local PAD_A, PAD_B = GAMEPAD_FACE_BOTTOM or "PAD1", GAMEPAD_FACE_RIGHT or "PAD2"
local PAD_X, PAD_Y = GAMEPAD_FACE_LEFT or "PAD3", GAMEPAD_FACE_TOP or "PAD4"
local PAD_LB, PAD_RB = GAMEPAD_SHOULDER_LEFT or "PADLSHOULDER", GAMEPAD_SHOULDER_RIGHT or "PADRSHOULDER"
local PAD_LT, PAD_RT = GAMEPAD_TRIGGER_LEFT or "PADLTRIGGER", GAMEPAD_TRIGGER_RIGHT or "PADRTRIGGER"

local DIRECTIONS = { [PAD_UP] = "up", [PAD_DOWN] = "down", [PAD_LEFT] = "left", [PAD_RIGHT] = "right" }

local RING_NAVIGATE = { 0.80, 0.60, 0.34 }   -- #CC9957, the tooltip / XP bar border bronze
local RING_GRABBED  = { 1.00, 0.82, 0.00 }   -- gold: something grabbed, or an open dropdown's choice

local REPEAT_DELAY, REPEAT_RATE = 0.35, 0.07   -- a held D-pad direction repeats
local FAST_AFTER = 1.0                          -- held this long, a slider moves five steps a press

-- What the pad does with each control. "list": an AceGUI dropdown, opened and walked; "cycle": a
-- dropdown with its own list (LibSharedMedia's font picker), grabbed and stepped with up / down;
-- "mouse": highlighted but left to the mouse and keyboard; "radialbutton": a button of the radial
-- being edited. A widget type not listed with a list and SetValue counts as "cycle"; a stand-in for
-- a plain frame carries its own kind.
local KINDS = {
    CheckBox = "toggle", Button = "button", Slider = "slider", Dropdown = "list",
    ColorPicker = "mouse", Keybinding = "mouse", EditBox = "mouse", MultiLineEditBox = "mouse",
}

local function KindOf(widget)
    if widget.kind then return widget.kind end
    local kind = KINDS[widget.type]
    if not kind and type(widget.list) == "table" and widget.SetValue then kind = "cycle" end
    if (kind == "list" or kind == "cycle") and widget.multiselect then kind = "mouse" end
    return kind
end

-- what identifies a control across redraws: its option table (AceConfigDialog's InjectInfo), or the
-- frame a stand-in wraps
local function KeyOf(widget)
    if widget.flareKey then return widget.flareKey end
    local user = widget.GetUserDataTable and widget:GetUserDataTable()
    return user and user.option
end

-- Plain frames (the settings window's own buttons, everything in the radial editor) get a stand-in the
-- navigation treats like an AceGUI widget; its "events" run the frame's own mouse-over scripts.
local standIns = {}
local function StandIn(frame, kind)
    local entry = standIns[frame]
    if not entry then
        entry = {
            frame = frame, flareKey = frame,
            Fire = function(self, event)
                local script = self.frame:GetScript(event)
                if script then script(self.frame) end
            end,
        }
        standIns[frame] = entry
    end
    entry.kind = kind
    return entry
end

-- every AceGUI control under a widget the pad can land on
local function CollectWidgets(widget, out)
    if not widget then return out end
    if widget.frame and widget.frame:IsVisible() and not widget.disabled and KindOf(widget) then
        out[#out + 1] = widget
    end
    if widget.children then
        for _, child in ipairs(widget.children) do CollectWidgets(child, out) end
    end
    return out
end

-- the first visible AceGUI widget of a type, depth first
local function Find(widget, widgetType)
    if not widget then return nil end
    if widget.type == widgetType and widget.frame and widget.frame:IsVisible() then return widget end
    if widget.children then
        for _, child in ipairs(widget.children) do
            local found = Find(child, widgetType)
            if found then return found end
        end
    end
end

local function Usable(frame)
    return frame and frame:IsVisible() and (not frame.IsEnabled or frame:IsEnabled())
end

--------------------------------------------------
-- Button icons (LB / RB, LT / RT): Blizzard's own InputIconTextureFrameTemplate, which draws the
-- glyph of the controller in use. TOOLTIP strata: the settings window is a toplevel frame in
-- FULLSCREEN_DIALOG and rises over anything there.
--------------------------------------------------
local icons = {}

local function Icon(key)
    local icon = icons[key]
    if not icon then
        icon = CreateFrame("Frame", nil, UIParent, "InputIconTextureFrameTemplate")
        icon:SetSize(22, 22)
        icon:SetFrameStrata("TOOLTIP")
        icon:SetInputKey(key)
        icons[key] = icon
    end
    return icon
end

local function HideIcons()
    for _, icon in pairs(icons) do icon:Hide() end
end

-- LB and RB side by side to the right of a frame (the last tab)
local function PlaceShoulderIcons(lastTab)
    local lb, rb = Icon(PAD_LB), Icon(PAD_RB)
    if lastTab then
        lb:ClearAllPoints()
        lb:SetPoint("LEFT", lastTab, "RIGHT", 8, -2)
        rb:ClearAllPoints()
        rb:SetPoint("LEFT", lb, "RIGHT", 2, 0)
        lb:Show()
        rb:Show()
    else
        lb:Hide()
        rb:Hide()
    end
end

local function CycleIndex(count, index, direction)
    return (index - 1 + direction) % count + 1
end

--------------------------------------------------
-- Context: the settings window
--------------------------------------------------
local Settings = {}

function Settings.Root()
    return AceConfigDialog.OpenFrames[APP]
end

function Settings.IsOpen()
    return Settings.Root() ~= nil
end

function Settings.Collect()
    local root = Settings.Root()
    local list = CollectWidgets(root, {})
    local f = root and root.frame
    if f then
        for _, button in ipairs({ f.flareResetButton, f.flareCloseButton }) do
            if Usable(button) then list[#list + 1] = StandIn(button, "button") end
        end
    end
    return list
end

function Settings.Close()
    AceConfigDialog:Close(APP)
end

function Settings.CycleTab(direction)
    local tabs = Find(Settings.Root(), "TabGroup")
    if not (tabs and tabs.tablist) then return end
    local status = tabs.status or tabs.localstatus
    local values, index = {}, 0
    for _, entry in ipairs(tabs.tablist) do
        if not entry.disabled then
            values[#values + 1] = entry.value
            if entry.value == status.selected then index = #values end
        end
    end
    if #values < 2 then return end
    tabs:SelectTab(values[CycleIndex(#values, index, direction)])
    PlaySound(841)   -- SOUNDKIT.IG_CHARACTER_INFO_TAB
end

function Settings.CycleSection(direction)
    local tree = Find(Settings.Root(), "TreeGroup")
    if not (tree and tree.tree) then return end
    local status = tree.status or tree.localstatus
    local current = status.selected and tostring(status.selected):match("^[^\001]+")
    local values, index = {}, 0
    for _, node in ipairs(tree.tree) do
        if node.visible ~= false and not node.disabled then
            values[#values + 1] = node.value
            if node.value == current then index = #values end
        end
    end
    if #values < 2 then return end
    tree:SelectByValue(values[CycleIndex(#values, index, direction)])
    PlaySound(841)
end

function Settings.PlaceIcons()
    local root = Settings.Root()
    local tabs = Find(root, "TabGroup")
    local lastTab
    if tabs and tabs.tabs then
        for _, tab in ipairs(tabs.tabs) do
            if tab:IsShown() then lastTab = tab end
        end
    end
    PlaceShoulderIcons(lastTab)
    local tree = Find(root, "TreeGroup")
    local lt, rt = Icon(PAD_LT), Icon(PAD_RT)
    if tree and tree.treeframe and tree.treeframe:IsVisible() then
        lt:ClearAllPoints()
        lt:SetPoint("BOTTOMRIGHT", tree.treeframe, "TOP", -1, 0)
        rt:ClearAllPoints()
        rt:SetPoint("BOTTOMLEFT", tree.treeframe, "TOP", 1, 0)
        lt:Show()
        rt:Show()
    else
        lt:Hide()
        rt:Hide()
    end
end

--------------------------------------------------
-- Context: the radial editor (Options/RadialEditor.lua, ns.RadialEditorPad)
--------------------------------------------------
local Editor = {}
local listOf = {}   -- a list cell -> the editor list it belongs to

function Editor.Frame()
    local pad = ns.RadialEditorPad
    return pad and pad.Frame()
end

function Editor.IsOpen()
    local editor = Editor.Frame()
    return editor ~= nil and editor:IsShown()
end

function Editor.Paused()
    local pad = ns.RadialEditorPad
    return pad and pad.NamePopupShown()
end

local function AddCells(list, kind, out)
    if not list then return end
    for _, cell in ipairs(list.cells) do
        listOf[cell] = list
        if cell:IsVisible() and cell.dataIndex then out[#out + 1] = StandIn(cell, kind) end
    end
end

function Editor.Collect()
    local editor = Editor.Frame()
    local out = {}
    if not editor then return out end
    if editor.radialDrop and editor.radialDrop.frame:IsVisible() then out[#out + 1] = editor.radialDrop end
    for _, button in ipairs({ editor.renameButton, editor.newButton, editor.deleteButton,
                              editor.confirmButton, editor.cancelButton }) do
        if Usable(button) then out[#out + 1] = StandIn(button, "button") end
    end
    for _, tab in ipairs(editor.tabs or {}) do
        if Usable(tab) then out[#out + 1] = StandIn(tab, "button") end
    end
    if editor.search and editor.search:IsVisible() then out[#out + 1] = StandIn(editor.search, "mouse") end
    AddCells(editor.buttonList, "radialbutton", out)
    AddCells(editor.browseList, "button", out)
    return out
end

-- like Escape: with unsaved edits the editor asks first (FLAREUI_RADIAL_UNSAVED)
function Editor.Close()
    local editor = Editor.Frame()
    if editor then editor:Hide() end
end

-- the browser's category tabs, in order; the active one is disabled, so it is found by its category
function Editor.CycleTab(direction)
    local editor, pad = Editor.Frame(), ns.RadialEditorPad
    local tabs = editor and editor.tabs
    if not (tabs and #tabs > 1) then return end
    local active, index = pad.ActiveCategory(), 1
    for i, tab in ipairs(tabs) do
        if tab.category and tab.category.key == active then index = i end
    end
    tabs[CycleIndex(#tabs, index, direction)]:Click()
end

function Editor.PlaceIcons()
    local editor = Editor.Frame()
    local tabs = editor and editor.tabs
    PlaceShoulderIcons(tabs and tabs[#tabs])
    Icon(PAD_LT):Hide()
    Icon(PAD_RT):Hide()
end

-- a list scrolls one row when the highlight is on its first / last row and would leave it
function Editor.ScrollList(widget, direction)
    local cell = widget.frame
    local list = listOf[cell]
    if not (list and list.slider and list.slider:IsShown()) then return false end
    if direction ~= "up" and direction ~= "down" then return false end
    local position
    for i, c in ipairs(list.cells) do
        if c == cell then position = i break end
    end
    if not position then return false end
    local columns = list.columns or 1
    local min, max = list.slider:GetMinMaxValues()
    local value = math.floor(list.slider:GetValue() or 0)
    if direction == "down" and position > #list.cells - columns and value < max then
        list.slider:SetValue(value + 1)
        return true
    elseif direction == "up" and position <= columns and value > min then
        list.slider:SetValue(value - 1)
        return true
    end
    return false
end

-- the editor's own verbs, on a button of the radial being edited
function Editor.Extra(button, widget)
    if not (widget and KindOf(widget) == "radialbutton" and widget.frame.dataIndex) then return false end
    local pad = ns.RadialEditorPad
    if button == PAD_X then
        pad.Remove(widget.frame.dataIndex)
        return true
    end
    return false
end

--------------------------------------------------
-- The engine
--------------------------------------------------
local nav, ring, context
local focused, focusKey, grabbed
local openList, listItems, listIndex   -- an AceGUI dropdown opened with A, and where in it we are
local reorderIndex                     -- the radial button grabbed with Y, by its place in the radial

local function PaintRing()
    local color = (grabbed or openList) and RING_GRABBED or RING_NAVIGATE
    ring:SetBackdropBorderColor(color[1], color[2], color[3], 1)
end

local function RingOn(frame, inset)
    inset = inset or 3
    ring:SetParent(frame)
    ring:ClearAllPoints()
    ring:SetPoint("TOPLEFT", frame, "TOPLEFT", -inset, inset)
    ring:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", inset, -inset)
    ring:SetFrameLevel(frame:GetFrameLevel() + 10)
    PaintRing()
    ring:Show()
end

local function TopLeft(list)
    local best, bestTop, bestLeft
    for _, widget in ipairs(list) do
        local left, top = widget.frame:GetLeft(), widget.frame:GetTop()
        if left and top and (not best or top > bestTop + 4 or (math.abs(top - bestTop) <= 4 and left < bestLeft)) then
            best, bestTop, bestLeft = widget, top, left
        end
    end
    return best
end

-- The nearest control in a direction: it has to lie that way, and being off to the side costs twice
-- as much as being far, so a row or column is followed before a jump across.
local function Neighbour(from, direction, list)
    local fx, fy = from.frame:GetCenter()
    if not fx then return nil end
    local best, bestScore
    for _, widget in ipairs(list) do
        if widget ~= from then
            local x, y = widget.frame:GetCenter()
            if x then
                local dx, dy = x - fx, y - fy
                local along, across
                if direction == "up" then along, across = dy, dx
                elseif direction == "down" then along, across = -dy, dx
                elseif direction == "left" then along, across = -dx, dy
                else along, across = dx, dy end
                if along > 4 then
                    local score = along + math.abs(across) * 2
                    if not bestScore or score < bestScore then best, bestScore = widget, score end
                end
            end
        end
    end
    return best
end

-- Moves a scroll area so a frame inside it is in view. offset is how far the content is pushed up;
-- setValue takes the 0-1000 scroll value the area's own scroll bar uses.
local function Reveal(frame, view, range, offset, setValue)
    local viewTop, viewBottom = view:GetTop(), view:GetBottom()
    local top, bottom = frame:GetTop(), frame:GetBottom()
    if not (viewTop and viewBottom and top and bottom) or range <= 0 then return end
    if top > viewTop - 4 then
        offset = offset - (top - viewTop) - 12
    elseif bottom < viewBottom + 4 then
        offset = offset + (viewBottom - bottom) + 12
    else
        return
    end
    setValue(math.max(0, math.min(range, offset)) / range * 1000)
end

-- an AceGUI page: the ScrollFrame above the widget
local function ScrollIntoView(widget)
    local scroll = widget.parent
    while scroll and scroll.type ~= "ScrollFrame" do scroll = scroll.parent end
    if not (scroll and scroll.scrollbar and scroll.scrollbar:IsShown()) then return end
    local status = scroll.status or scroll.localstatus
    Reveal(widget.frame, scroll.scrollframe, scroll.content:GetHeight() - scroll.scrollframe:GetHeight(),
        status.offset or 0, function(value) scroll.scrollbar:SetValue(value) end)
end

local function SetFocus(widget)
    if focused and focused ~= widget and focused.Fire then focused:Fire("OnLeave") end
    grabbed, reorderIndex = nil, nil
    focused = widget
    focusKey = widget and KeyOf(widget) or nil
    if not widget then
        ring:Hide()
        return
    end
    ScrollIntoView(widget)
    RingOn(widget.frame)
    widget:Fire("OnEnter")
end

-- The windows are redrawn after most changes (AceConfigDialog redraws on NotifyChange, the editor on
-- Refresh), so the focus is found again by its key every time, and lands top left when it is gone.
local function Controls()
    local list = context and context.Collect() or {}
    if focused and focused.frame and focused.frame:IsVisible() and KeyOf(focused) == focusKey then
        for _, widget in ipairs(list) do
            if widget == focused then return list end
        end
    end
    local found
    if focusKey then
        for _, widget in ipairs(list) do
            if KeyOf(widget) == focusKey then found = widget break end
        end
    end
    local wasGrabbed, wasReorder = grabbed, reorderIndex
    SetFocus(found or TopLeft(list))
    if found and wasGrabbed then grabbed, reorderIndex = wasGrabbed, wasReorder; PaintRing() end
    return list
end

--------------------------------------------------
-- An opened dropdown: its pullout's items, walked with up / down
--------------------------------------------------
local function CloseList()
    if openList and openList.open and openList.button then openList.button:Click() end
    openList, listItems, listIndex = nil, nil, nil
    if focused then RingOn(focused.frame) end
end

local function ShowListItem()
    local item = listItems[listIndex]
    if not item then return end
    local pullout = openList.pullout
    if pullout.slider and pullout.slider:IsShown() then
        local status = pullout.scrollStatus or {}
        Reveal(item.frame, pullout.scrollFrame, pullout.itemFrame:GetHeight() - pullout.scrollFrame:GetHeight(),
            status.offset or 0, function(value) pullout.slider:SetValue(value) end)
    end
    RingOn(item.frame, 1)
end

local function OpenList(widget)
    if not (widget.button and widget.pullout) then return end
    if not widget.open then widget.button:Click() end
    if not widget.open then return end
    openList, listItems, listIndex = widget, {}, 1
    for _, item in widget.pullout:IterateItems() do
        if item.userdata and item.userdata.value ~= nil and not item.disabled then
            listItems[#listItems + 1] = item
            if item.userdata.value == widget.value then listIndex = #listItems end
        end
    end
    if #listItems == 0 then return CloseList() end
    ShowListItem()
end

local function MoveInList(direction)
    if not (openList and openList.open) then return CloseList() end
    if direction == "up" and listIndex > 1 then listIndex = listIndex - 1
    elseif direction == "down" and listIndex < #listItems then listIndex = listIndex + 1 end
    ShowListItem()
end

local function ChooseFromList()
    local item = listItems and listItems[listIndex]
    local widget = openList
    openList, listItems, listIndex = nil, nil, nil
    if widget and widget.open and item then
        item.frame:Click()   -- the item's own handler sets the value and closes the pullout
    end
    if focused then RingOn(focused.frame) end
end

--------------------------------------------------
-- Changing controls
--------------------------------------------------
local function CycleValues(widget)
    local values = {}
    if type(widget.list) == "table" then
        for key in pairs(widget.list) do values[#values + 1] = key end
        table.sort(values, function(a, b) return tostring(widget.list[a]) < tostring(widget.list[b]) end)
    end
    return values
end

local function Step(widget, direction, fast)
    local kind = KindOf(widget)
    if kind == "slider" then
        local min, max = widget.min or 0, widget.max or 100
        local step = (widget.step and widget.step > 0) and widget.step or (max - min) / 100
        if fast then step = step * 5 end
        local value = math.max(min, math.min(max, (widget:GetValue() or min) + direction * step))
        widget:SetValue(value)
        widget:Fire("OnValueChanged", value)
        widget:Fire("OnMouseUp", value)
    elseif kind == "cycle" then
        local values = CycleValues(widget)
        if #values == 0 then return end
        local index = 0
        for i, value in ipairs(values) do
            if value == widget.value then index = i break end
        end
        local value = values[CycleIndex(#values, index, direction)]
        widget:SetValue(value)
        widget:Fire("OnValueChanged", value)
    end
end

-- after a reorder the grabbed button shows in another cell: follow it, scrolling the list to it
local function FollowReorder()
    if not reorderIndex then return end
    local editor = Editor.Frame()
    local list = editor and editor.buttonList
    if not list then return end
    for _ = 1, 50 do
        for _, cell in ipairs(list.cells) do
            if cell:IsVisible() and cell.dataIndex == reorderIndex then
                local index = reorderIndex
                SetFocus(StandIn(cell, "radialbutton"))
                grabbed, reorderIndex = "reorder", index
                PaintRing()
                return
            end
        end
        local first = list.cells[1].dataIndex or 0
        local value = math.floor(list.slider:GetValue() or 0)
        local nextValue = value + (reorderIndex < first and -1 or 1)
        local min, max = list.slider:GetMinMaxValues()
        if nextValue < min or nextValue > max then return end
        list.slider:SetValue(nextValue)
    end
end

local function Activate(widget)
    local kind = KindOf(widget)
    if kind == "toggle" then
        widget:ToggleChecked()
        PlaySound(widget.checked and 856 or 857)   -- SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON / _OFF
        widget:Fire("OnValueChanged", widget.checked)
    elseif kind == "button" then
        widget.frame:Click()
    elseif kind == "radialbutton" then
        widget.frame:Click("LeftButton")   -- selects it, as a left click does
    elseif kind == "list" then
        OpenList(widget)
    elseif kind == "slider" or kind == "cycle" then
        grabbed = not grabbed
        PlaySound(852)   -- SOUNDKIT.IG_MAINMENU_OPTION
        PaintRing()
    else
        UIErrorsFrame:AddMessage("Use the mouse or keyboard for this.", 1, 0.82, 0)
    end
end

--------------------------------------------------
-- Pad input
--------------------------------------------------
local held, heldFor, nextRepeat

local function Move(direction, repeating)
    if openList then return MoveInList(direction) end
    local list = Controls()
    if not focused then return end
    if grabbed then
        local kind = KindOf(focused)
        if grabbed == "reorder" and (direction == "up" or direction == "down") then
            local to = reorderIndex + (direction == "down" and 1 or -1)
            ns.RadialEditorPad.Move(reorderIndex, to)
            local radialSize = 0
            local editor = Editor.Frame()
            if editor and editor.buttonList then radialSize = #editor.buttonList.data end
            reorderIndex = math.max(1, math.min(radialSize, to))
            FollowReorder()
        elseif kind == "slider" and (direction == "left" or direction == "right") then
            Step(focused, direction == "right" and 1 or -1, repeating and heldFor >= FAST_AFTER)
        elseif kind == "cycle" and (direction == "up" or direction == "down") then
            Step(focused, direction == "down" and 1 or -1)
        end
        return   -- A (or B, or Y for a reorder) lets go before the highlight moves on
    end
    if context.ScrollList and context.ScrollList(focused, direction) then
        focused:Fire("OnEnter")   -- the same cell now shows another entry
        return
    end
    local target = Neighbour(focused, direction, list)
    if target then SetFocus(target) end
end

local function Paused()
    return ns.AnyDialogShown and ns.AnyDialogShown() or (context and context.Paused and context.Paused())
end

local function OnButtonDown(self, button)
    if Paused() then
        if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
        return
    end
    local direction = DIRECTIONS[button]
    local handled = true
    if direction then
        Move(direction)
        held, heldFor, nextRepeat = direction, 0, REPEAT_DELAY
    elseif button == PAD_A then
        if openList then
            ChooseFromList()
        elseif grabbed == "reorder" then
            grabbed, reorderIndex = nil, nil
            PaintRing()
        else
            Controls()
            if focused then Activate(focused) end
        end
    elseif button == PAD_B then
        if openList then
            CloseList()
        elseif grabbed then
            grabbed, reorderIndex = nil, nil
            PaintRing()
        else
            context.Close()
        end
    elseif button == PAD_Y and context == Editor then
        Controls()
        if grabbed == "reorder" then
            grabbed, reorderIndex = nil, nil
        elseif focused and KindOf(focused) == "radialbutton" and focused.frame.dataIndex then
            grabbed, reorderIndex = "reorder", focused.frame.dataIndex
            PlaySound(852)
        end
        PaintRing()
    elseif button == PAD_X and context.Extra then
        Controls()
        handled = context.Extra(button, focused)
    elseif button == PAD_LB or button == PAD_RB then
        if openList then CloseList() end
        SetFocus(nil)   -- the new page starts top left (the upkeep finds it once drawn)
        context.CycleTab(button == PAD_RB and 1 or -1)
    elseif (button == PAD_LT or button == PAD_RT) and context.CycleSection then
        if openList then CloseList() end
        SetFocus(nil)
        context.CycleSection(button == PAD_RT and 1 or -1)
    else
        handled = false
    end
    if not InCombatLockdown() then self:SetPropagateKeyboardInput(not handled) end
end

local function OnButtonUp(_, button)
    if DIRECTIONS[button] == held then held = nil end
end

--------------------------------------------------
-- Upkeep and starting
--------------------------------------------------
-- the window the pad drives: the editor while it is open (it puts the settings window away), else
-- the settings
local function CurrentContext()
    if Editor.IsOpen() then return Editor end
    if Settings.IsOpen() then return Settings end
end

local function Stop()
    if focused and focused.Fire then focused:Fire("OnLeave") end
    focused, focusKey, grabbed, held, reorderIndex = nil, nil, nil, nil, nil
    openList, listItems, listIndex = nil, nil, nil
    context = nil
    if ring then
        ring:SetParent(UIParent)
        ring:Hide()
    end
    HideIcons()
    if nav then nav:Hide() end
end

local upkeep = 0
local function OnUpdate(_, elapsed)
    local current = CurrentContext()
    if not current then return Stop() end
    if current ~= context then
        -- the other window took over (the editor opened from the settings, or closed back to them)
        if focused and focused.Fire then focused:Fire("OnLeave") end
        focused, focusKey, grabbed, reorderIndex = nil, nil, nil, nil
        openList, listItems, listIndex = nil, nil, nil
        context = current
    end
    if held then
        heldFor = heldFor + elapsed
        nextRepeat = nextRepeat - elapsed
        if nextRepeat <= 0 then
            nextRepeat = REPEAT_RATE
            if not Paused() then Move(held, true) end
        end
    end
    upkeep = upkeep + elapsed
    if upkeep >= 0.1 then
        upkeep = 0
        if Paused() then
            if ring then ring:Hide() end
            return
        end
        context.PlaceIcons()
        -- a dropdown closed by the mouse, or a redraw (another tab, a changed setting) that took the
        -- highlighted control away
        if openList and not openList.open then CloseList() end
        if not openList and not (focused and focused.frame and focused.frame:IsVisible()) then Controls() end
        if focused and ring and not ring:IsShown() and not openList then RingOn(focused.frame) end
    end
end

local function Start()
    if not ns.IsGamepadUI() or InCombatLockdown() then return end
    if not nav then
        nav = CreateFrame("Frame", "FlareUISettingsPad", UIParent)
        nav:SetScript("OnGamePadButtonDown", OnButtonDown)
        nav:SetScript("OnGamePadButtonUp", OnButtonUp)
        nav:SetScript("OnUpdate", OnUpdate)
        ring = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        ring:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
        ring:EnableMouse(false)
        ring:Hide()
    end
    if nav:IsShown() then return end
    context = CurrentContext()
    nav:EnableGamePadButton(true)
    nav:SetPropagateKeyboardInput(true)
    nav:Show()
    C_Timer.After(0, function() if context then Controls(); context.PlaceIcons() end end)
end

-- every Open (refreshes included) of FlareUI's settings, and every opening of the radial editor
hooksecurefunc(AceConfigDialog, "Open", function(_, app)
    if app == APP then Start() end
end)
hooksecurefunc(ns, "ShowRadialEditor", Start)

--------------------------------------------------
-- Getting there: the keybinding (Bindings.xml) and the radial panel call this
--------------------------------------------------
BINDING_HEADER_FLAREUI = "FlareUI"
BINDING_NAME_FLAREUI_SETTINGS = "Open Settings"

function FlareUI_ToggleSettings()
    if Settings.IsOpen() then
        AceConfigDialog:Close(APP)
    else
        AceConfigDialog:Open(APP)
    end
end
