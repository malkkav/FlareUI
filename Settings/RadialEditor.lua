local _, ns = ...
local L = ns.L

--------------------------------------------------
-- RADIAL EDITOR
-- The Radial Menu page's Radials tab: every radial with who gets it and its key, what opens on this
-- character, and the selected radial's buttons, a Catalog to drag from and a live preview. Edits are
-- live; a snapshot taken on open backs "Undo changes". Drags from Blizzard's windows use the game
-- cursor (OnReceiveDrag); internal drags are resolved in FinishDrag.
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

--------------------------------------------------
-- 1. PIECES
--------------------------------------------------
local Fade = ns.Fade

-- sound replaces the Game Menu click; false leaves the sound to onClick
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
-- 2. SCROLLING LIST (1 or more columns, the settings panel's thin scroll line)
--------------------------------------------------
local function CreateList(parent, width, columns, rows, cellHeight, buildCell, fillCell)
    local list = CreateFrame("Frame", nil, parent)
    local cellWidth = (width - 12) / columns
    list.cells, list.data = {}, {}
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

        -- a bronze wash instead of Blizzard's blue square
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

    -- list.offset is in rows
    local function SetOffset(offset)
        offset = math.max(0, math.min(list.maxOffset, math.floor(offset + 0.5)))
        if offset == list.offset then return end
        list.offset = offset
        list:Update()
    end

    local bar = ns.SettingsPanel.ScrollLine(list)
    bar:SetPoint("TOPRIGHT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", 0, 0)
    bar.onScroll = function(position)
        SetOffset(position * list.maxOffset)
        bar:SetValues(bar.visible, list.maxOffset > 0 and list.offset / list.maxOffset or 0)
    end

    local function SyncBar()
        local total = math.max(rows, math.ceil(#list.data / columns))
        bar:SetValues(rows / total, list.maxOffset > 0 and list.offset / list.maxOffset or 0)
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
-- 3. ENTRIES
--------------------------------------------------
-- a spell's ID is GetCursorInfo's fourth return
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
    -- only what resolves reaches the radial
    if entry and RM():ResolveEntry(entry) then
        ClearCursor()
        return entry
    end
    return nil
end

-- the guillemet marking a sub-radial, as bytes so the file stays ASCII
local CHEVRON = "\194\187 "

local function EntryDisplay(entry)
    local info = entry and RM():ResolveEntry(entry)
    -- a sub-radial shows the radial's name, even when it resolves to nothing
    if entry and entry.kind == "subradial" then
        local data = RM():GetRadial(entry.radial)
        if data then
            return CHEVRON .. data.name, info and info.icon or { texture = FALLBACK_ICON }
        end
    end
    if info then
        -- the editor names a spell's rank ("Frostbolt (Rank 3)"), so the ranks tell apart and search
        -- finds them; the radial itself keeps the short name
        if entry.kind == "spell" and entry.id and info.name then
            local subtext = C_Spell.GetSpellSubtext(entry.id)
            if type(subtext) == "string" and subtext:find("%d") then return info.name .. " (" .. subtext .. ")", info.icon end
        end
        return info.name, info.icon
    end
    return "|cff808080" .. L["unavailable"] .. "|r", { texture = FALLBACK_ICON }
end

-- Spells and items get the game's own tooltip (it shows the rank), the rest their name; hint below.
-- A macro gets the tooltip of what it casts now, under its own name.
local function EntryTooltip(owner, entry, hint)
    ns.OwnGameTooltip(owner, "ANCHOR_RIGHT")
    local macroKind, macroID
    if entry.kind == "macro" and RM() and RM().MacroAction then macroKind, macroID = RM().MacroAction(entry) end
    if entry.kind == "spell" and entry.id then
        GameTooltip:SetSpellByID(entry.id)
    elseif entry.kind == "item" and entry.id then
        GameTooltip:SetItemByID(entry.id)
    elseif macroKind == "spell" or macroKind == "item" then
        if macroKind == "spell" then GameTooltip:SetSpellByID(macroID) else GameTooltip:SetItemByID(macroID) end
        GameTooltip:AddLine(L["Macro"] .. ": " .. tostring(entry.name), 1, 0.82, 0)
    else
        GameTooltip:AddLine((EntryDisplay(entry)), 1, 1, 1)
    end
    if hint then GameTooltip:AddLine(hint, 0.6, 0.6, 0.6, true) end
    GameTooltip:Show()
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
-- 4. CATEGORY BROWSERS (menu order = declaration order)
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
                if info and info.spellID and not info.isPassive and info.itemType ~= Enum.SpellBookItemType.FutureSpell then
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
    -- per-character macros are indexed after the account block
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
    out[#out + 1] = { kind = "targetmarker", marker = -1 }
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
    if not C_MountJournal then return out end
    for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
        local _, _, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
        if isCollected then out[#out + 1] = { kind = "mount", id = mountID } end
    end
    return out
end)

-- a radial that contains the edited one, at any depth, is left out of the list
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
-- 5. DRAG
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
-- 6. EDITING
--------------------------------------------------
local Refresh, RefreshBrowse   -- rebuild the whole tab, or the Catalog alone

local function CurrentRadial()
    local rm = RM()
    if not rm then return nil end
    local radial = editingID and rm:GetRadial(editingID)
    if radial then return radial end
    editingID = rm:GetDefaultRadialID() or rm:GetRadialOrder()[1]
    return editingID and rm:GetRadial(editingID) or nil
end

local function Changed()
    dirty = true
    RM():RadialChanged(editingID)
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

-- nothing is on the game cursor during an internal drag, so OnReceiveDrag never fires
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
-- 7. UNDOING CHANGES
-- The radials (buttons, names, who gets them, shared keys) and this character's own keys.
--------------------------------------------------
local function TakeSnapshot()
    local store = RM().GetStore()
    dirty = false
    if not store then snapshot = nil return end
    snapshot = {
        radials      = CopyTable(store.radials),
        radialOrder  = CopyTable(store.radialOrder),
        nextRadialID = store.nextRadialID,
        ownKeys      = CopyTable(ns.CharDB().radialKeyOverride or {}),
    }
end

local function RestoreSnapshot()
    local store = RM().GetStore()
    if not (store and snapshot and dirty) then return end
    -- the store table itself is kept: others hold a reference to it
    store.radials      = CopyTable(snapshot.radials)
    store.radialOrder  = CopyTable(snapshot.radialOrder)
    store.nextRadialID = snapshot.nextRadialID
    ns.CharDB().radialKeyOverride = CopyTable(snapshot.ownKeys)
    dirty = false
    RM():RadialChanged()
    RM():AvailabilityChanged()
end

-- acts on the radial the question named, even if the selection moved on
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
-- 8. WHO GETS A RADIAL (scope words and icons)
--------------------------------------------------
local ICON_FACTION = { Alliance = "Interface\\FriendsFrame\\PlusManz-Alliance", Horde = "Interface\\FriendsFrame\\PlusManz-Horde" }
local ICON_CHAR    = "Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon"
local ICON_CLASSES = "Interface\\GLUES\\CHARACTERCREATE\\UI-CharacterCreate-Classes"
local FACTION_COLOR = { Alliance = "ff4a9eff", Horde = "ffff4030" }

local function ClassName(token)
    if select(2, UnitClass("player")) == token then return (UnitClass("player")) end
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]) or token
end

local function ColorClass(token, text)
    local color = C_ClassColor and C_ClassColor.GetClassColor(token)
    return color and color:WrapTextInColorCode(text) or text
end

local function FactionName(token)
    local mine, myName = UnitFactionGroup("player")
    if mine == token and myName then return myName end
    return _G["FACTION_" .. token:upper()] or token
end

-- "Only Hedgey": the character's name was kept when the scope was set
local function ScopeOwner(scope, data)
    local _, guid = RM().SplitScope(scope)
    if guid == ns.PlayerGUID() then return (UnitName("player")) end
    return (data and data.scopeName) or "?"
end

-- the dropdown's words for a scope; data names the character of a "char:" scope made elsewhere
local function ScopeText(scope, data)
    local kind, value = RM().SplitScope(scope)
    if kind == "faction" then
        return L["All %s characters"]:format("|c" .. (FACTION_COLOR[value] or "ffffffff") .. FactionName(value) .. "|r")
    elseif kind == "class" then
        return L["All %s characters"]:format(ColorClass(value, ClassName(value)))
    elseif kind == "char" then
        return L["Only %s"]:format("|cffffd100" .. ScopeOwner(scope, data) .. "|r")
    end
    return L["All characters"]
end

-- only a narrowed radial gets an icon (class, faction crest, a person); false for every character
local function ApplyScopeIcon(texture, scope)
    local kind, value = RM().SplitScope(scope)
    texture:SetDesaturated(false)
    if kind == "class" and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[value] then
        texture:SetTexture(ICON_CLASSES)
        texture:SetTexCoord(unpack(CLASS_ICON_TCOORDS[value]))
        return true
    end
    texture:SetTexCoord(0, 1, 0, 1)
    if kind == "faction" and ICON_FACTION[value] then
        texture:SetTexture(ICON_FACTION[value])
        return true
    elseif kind == "char" then
        texture:SetTexture(ICON_CHAR)
        texture:SetTexCoord(0.25, 0.75, 0.25, 0.75)
        return true
    end
    return false
end

local function KeyText(key)
    return key and (GetBindingText and GetBindingText(key) or key) or ""
end

--------------------------------------------------
-- 9. NAME POPUP (new radial with who gets it, or rename: popup.renaming)
--------------------------------------------------
local popup

local function ShowNamePopup(renaming)
    if not popup then
        popup = CreateFrame("Frame", "FlareUI_RadialEditorNewRadial", UIParent, "BackdropTemplate")
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

        -- who gets the new radial
        local scopeLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        scopeLabel:SetPoint("TOPLEFT", box, "BOTTOMLEFT", -6, -14)
        scopeLabel:SetText(L["Available to"])
        popup.scopeLabel = scopeLabel
        local scopeDrop = CreateFrame("DropdownButton", nil, popup, "WowStyle1DropdownTemplate")
        scopeDrop:SetWidth(256)
        scopeDrop:SetPoint("TOPLEFT", scopeLabel, "BOTTOMLEFT", 0, -4)
        scopeDrop:SetupMenu(function(_, root)
            for _, scope in ipairs(RM():GetScopeChoices()) do
                root:CreateRadio(ScopeText(scope), function() return popup.scope == scope end, function()
                    popup.scope = scope
                end)
            end
        end)
        popup.scopeDrop = scopeDrop

        local function Accept()
            local name = strtrim(box:GetText())
            if name == "" then return end
            if popup.renaming then
                RM():RenameRadial(editingID, name)
            else
                editingID, selectedButton = RM():CreateRadial(name, popup.scope), nil
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
    popup.label:SetText(renaming and L["Rename the radial"] or L["Name the new radial"])
    popup.accept:SetText(renaming and L["Rename"] or L["Create"])
    -- a new radial starts on this character only: nothing reaches the others unasked
    local choices = RM():GetScopeChoices()
    popup.scope = choices[#choices]
    popup.scopeLabel:SetShown(not renaming)
    popup.scopeDrop:SetShown(not renaming)
    popup.scopeDrop:GenerateMenu()
    popup:SetSize(320, renaming and 116 or 170)

    popup:ClearAllPoints()
    popup:SetPoint("CENTER", editor or UIParent, "CENTER", 0, 60)
    popup.box:SetText(renaming and radial.name or L["New Radial"])
    popup.box:HighlightText()
    popup:Show()
    popup.box:SetFocus()
end

--------------------------------------------------
-- 10. RADIAL MACROS
--------------------------------------------------
local function CreateRadialMacro()
    local data = editingID and RM():GetRadial(editingID)
    if not data then return end
    local S = ns.Settings
    if InCombatLockdown() then
        print("|cffff4040FlareUI:|r " .. (S:Text("rm.macroCreate", "errorInCombat", true) or L["You can't create macros in combat."]))
        return
    end
    local _, perCharacter = GetNumMacros()
    local maxPerCharacter = Constants.MacroConsts and Constants.MacroConsts.MAX_CHARACTER_MACROS or 30
    if perCharacter >= maxPerCharacter then
        print("|cffff4040FlareUI:|r " .. (S:Text("rm.macroCreate", "errorMacrosFull", true) or L["Your macro list is full. Delete one and try again."]))
        return
    end
    -- 16 bytes at most, without splitting a multi-byte letter
    local full, cut = "FUI " .. data.name, 16
    while cut < #full and full:byte(cut + 1) >= 128 and full:byte(cut + 1) < 192 do cut = cut - 1 end
    local name = full:sub(1, cut)
    local index = CreateMacro(name, "INV_MISC_QUESTIONMARK", RM():GetMacroText(editingID), true)
    if index then
        PickupMacro(index)
        local done = S:Text("rm.macroCreate", "done", true) or L["Macro \"{name}\" created and on your cursor. Drop it on a bar."]
        print("|cff00ccffFlareUI:|r " .. done:gsub("{name}", function() return name end))
    end
end

--------------------------------------------------
-- 11. BUILD
-- The tab is wide (a wider window). The right column: the radials and what opens on this
-- character. The middle: the selected radial's name and actions, one row for who gets it, its key
-- and a Create macro button, then the Catalog (a category menu over a two-column grid), its
-- buttons and a live preview.
--------------------------------------------------
local COLUMN_PAD = 12            -- the radials' inset in the panel's right column
local LIST_W = 226               -- the radials list: the right column (250) less its insets
local DETAIL_X = 0               -- the selected radial's column
local RADIAL_ROW_H = 22
local BUTTON_LIST_W = 64         -- the radial's buttons
local BUTTON_ROW_H = 36
local GRID_ROW_H = 30            -- the Catalog's two columns
local PREVIEW_W = 236            -- RadialMenu's PREVIEW_BOX and a margin
local FORM_TOP = 34              -- labels; their controls sit 14 lower
local LOWER_TOP = 88             -- Catalog, buttons and preview start here

-- a tooltip from the copy document: label, description, tip
local function Hover(control, rowKey)
    local S = ns.Settings
    control:HookScript("OnEnter", function(self)
        ns.OwnGameTooltip(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(S:Text(rowKey, "label"), 1, 1, 1)
        local desc, tip = S:Text(rowKey, "desc", true), S:Text(rowKey, "tip", true)
        if desc then GameTooltip:AddLine(S:Format(desc), nil, nil, nil, true) end
        if tip then GameTooltip:AddLine(L["Tip:"] .. " " .. S:Format(tip), 0.6, 0.6, 0.6, true) end
        GameTooltip:Show()
    end)
    control:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

local function Text(parent, font, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", font)
    if text then fs:SetText(text) end
    fs:SetJustifyH("LEFT")
    return fs
end

local function Divider(parent)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(BRONZE_MUTED[1], BRONZE_MUTED[2], BRONZE_MUTED[3], 0.45)
    return t
end

-- the panel's padding: the host ends this far above the window's bottom line
local PANEL_PAD = 12

-- a column divider from the line under the form down to the window's bottom line, closing the
-- sections as the panel's own column lines do
local function VLine(parent, x)
    local t = Divider(parent)
    t:SetWidth(1)
    t:SetPoint("TOPLEFT", x, -LOWER_TOP + 8)
    t:SetPoint("BOTTOMLEFT", x, -PANEL_PAD)
    return t
end

-- quiet text actions (Rename, Copy, Delete, + New, Undo) instead of big buttons
local function LinkButton(parent, text, onClick, danger)
    local b = CreateFrame("Button", nil, parent)
    b:SetNormalFontObject("GameFontNormalSmall")
    b:SetHighlightFontObject(danger and "GameFontRedSmall" or "GameFontHighlightSmall")
    b:SetDisabledFontObject("GameFontDisableSmall")
    b:SetText(text)
    b:SetSize(math.max(20, b:GetFontString():GetStringWidth() + 10), 20)
    b:SetScript("OnClick", function(...)
        ns.ButtonSound()
        onClick(...)
    end)
    return b
end

local function SelectRadial(id)
    if id == editingID then return end
    editingID, selectedButton = id, nil
    Refresh()
end

-- the radials and "On this character" fill the panel's right column, where other pages show their
-- info panel; host keeps the references
local function BuildRadialColumn(host, column)
    local col = CreateFrame("Frame", nil, column)
    col:SetPoint("TOPLEFT", COLUMN_PAD, -COLUMN_PAD)
    col:SetPoint("BOTTOMRIGHT", -COLUMN_PAD, COLUMN_PAD)
    host.column = col
    local height = column:GetHeight() > 0 and column:GetHeight() - 2 * COLUMN_PAD or 600
    local title = Text(col, "GameFontNormal", L["Radials"])
    title:SetPoint("TOPLEFT", 4, -4)
    host.newButton = LinkButton(col, L["+ New radial"], function() ShowNamePopup(false) end)
    host.newButton:SetPoint("TOPRIGHT", col, "TOPLEFT", LIST_W, 0)
    Hover(host.newButton, "rm.new")

    local rows = math.max(5, math.floor((height - 26 - 150) / RADIAL_ROW_H))
    local list = CreateList(col, LIST_W, 1, rows, RADIAL_ROW_H,
        function(cell)
            cell.Icon:SetSize(14, 14)
            cell.Key = cell:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            cell.Key:SetPoint("RIGHT", -6, 0)
            cell.Key:SetJustifyH("RIGHT")
            cell.Text:SetFontObject("GameFontHighlight")
            cell.Text:SetPoint("RIGHT", cell.Key, "LEFT", -4, 0)
            cell:SetScript("OnClick", function(self)
                if self.item and self.item.id then ns.ButtonSound() SelectRadial(self.item.id) end
            end)
            cell:SetScript("OnEnter", function(self)
                local id = self.item and self.item.id
                local data = id and RM():GetRadial(id)
                if not data then return end
                ns.OwnGameTooltip(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(data.name, 1, 1, 1)
                GameTooltip:AddLine(ScopeText(data.scope, data))
                if not RM():IsRadialAvailable(id) then GameTooltip:AddLine(L["Not available on this character."], 0.6, 0.6, 0.6) end
                local winner = self.item.beatenBy and RM():GetRadial(self.item.beatenBy)
                if winner then GameTooltip:AddLine(L["%s opens %s on this character."]:format(KeyText(self.item.key), winner.name), 1, 0.6, 0) end
                GameTooltip:Show()
            end)
            cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end,
        function(cell, item)
            if item.header then
                cell.Icon:Hide()
                cell.Key:SetText("")
                cell.Text:SetText("|cff9d8462" .. item.header .. "|r")
                cell.Highlight:Hide()
                cell:EnableMouse(false)
                return
            end
            cell:EnableMouse(true)
            local data = RM():GetRadial(item.id)
            cell.Icon:SetShown(ApplyScopeIcon(cell.Icon, data.scope))
            cell.Icon:SetDesaturated(not item.available)
            cell.Icon:SetAlpha(item.available and 1 or 0.5)
            cell.Text:SetText(item.available and data.name or ("|cff808080" .. data.name .. "|r"))
            local color = item.beaten and "|cffff9900" or (item.available and "|cffffd100" or "|cff808080")
            cell.Key:SetText(item.key and (color .. KeyText(item.key) .. "|r") or "")
            cell.Highlight:SetShown(item.id == editingID)
        end)
    list:SetPoint("TOPLEFT", 0, -26)
    host.radialList = list
    host.radialRows = rows

    -- placed under the list's last row on each refresh
    local overviewTitle = Text(col, "GameFontNormal", ns.Settings:Text("rm.overview", "label"))
    host.overviewTitle = overviewTitle
    local overview = Text(col, "GameFontHighlightSmall")
    overview:SetPoint("TOPLEFT", overviewTitle, "BOTTOMLEFT", 0, -6)
    overview:SetWidth(LIST_W - 8)
    overview:SetJustifyV("TOP")
    overview:SetSpacing(4)
    overview:SetMaxLines(6)
    host.overview = overview
    local overviewHover = CreateFrame("Frame", nil, col)
    overviewHover:SetPoint("TOPLEFT", overviewTitle, "TOPLEFT", -4, 4)
    overviewHover:SetSize(LIST_W, 18)
    overviewHover:EnableMouse(true)
    Hover(overviewHover, "rm.overview")
end

local function BuildDetails(host, width)
    local x = DETAIL_X
    local S = ns.Settings

    local name = Text(host, "GameFontNormalLarge")
    name:SetPoint("TOPLEFT", x, -6)
    name:SetWidth(width - 200)
    name:SetWordWrap(false)
    host.nameText = name
    host.deleteButton = LinkButton(host, L["Delete"], function()
        local radial = editingID and RM():GetRadial(editingID)
        if not radial then return end
        ns.ShowDialog("FLAREUI_RADIAL_DELETE", radial.name or "", { id = editingID })
    end, true)
    host.deleteButton:SetPoint("TOPRIGHT", 0, -2)
    host.copyButton = LinkButton(host, L["Copy"], function()
        local radial = editingID and RM():GetRadial(editingID)
        if not radial then return end
        editingID, selectedButton = RM():CopyRadial(editingID, L["%s (copy)"]:format(radial.name)), nil
        Changed()
        Refresh()
    end)
    host.copyButton:SetPoint("RIGHT", host.deleteButton, "LEFT", -6, 0)
    Hover(host.copyButton, "rm.copy")
    host.renameButton = LinkButton(host, L["Rename"], function() ShowNamePopup(true) end)
    host.renameButton:SetPoint("RIGHT", host.copyButton, "LEFT", -6, 0)

    -- the form: who gets it | its key
    host.scopeLabel = Text(host, "GameFontNormalSmall", S:Text("rm.scope", "label"))
    host.scopeLabel:SetPoint("TOPLEFT", x + 2, -FORM_TOP)
    local scope = CreateFrame("DropdownButton", nil, host, "WowStyle1DropdownTemplate")
    scope:SetWidth(220)
    scope:SetPoint("TOPLEFT", x, -FORM_TOP - 14)
    scope:SetupMenu(function(_, root)
        local data = editingID and RM():GetRadial(editingID)
        if not data then return end
        local choices = RM():GetScopeChoices()
        -- a scope set on another character stays listed, so it shows as chosen
        local listed = false
        for _, s in ipairs(choices) do if s == (data.scope or "") then listed = true end end
        if not listed and data.scope then table.insert(choices, data.scope) end
        for _, s in ipairs(choices) do
            root:CreateRadio(ScopeText(s, data), function() return (data.scope or "") == s end, function()
                RM():SetRadialScope(editingID, s)
                Changed()
                Refresh()
            end)
        end
    end)
    Hover(scope, "rm.scope")
    host.scopeDrop = scope

    local keyX = x + 236
    host.keyLabel = Text(host, "GameFontNormalSmall", S:Text("rm.key", "label"))
    host.keyLabel:SetPoint("TOPLEFT", keyX + 2, -FORM_TOP)
    host.keyButton = ns.SettingsPanel.KeyButton(host, function(key)
        if not editingID then return end
        RM():SetRadialKey(editingID, key)
        Changed()
        Refresh()
    end)
    host.keyButton:SetSize(130, 24)
    host.keyButton:SetPoint("TOPLEFT", keyX, -FORM_TOP - 15)
    Hover(host.keyButton, "rm.key")
    local own = CreateFrame("CheckButton", nil, host, "UICheckButtonTemplate")
    own:SetSize(22, 22)
    own:SetPoint("LEFT", host.keyButton, "RIGHT", 8, 0)
    own.text = Text(own, "GameFontHighlightSmall", S:Text("rm.ownKey", "label"))
    own.text:SetPoint("LEFT", own, "RIGHT", 2, 1)
    own:SetHitRectInsets(0, -(own.text:GetStringWidth() + 4), 0, 0)
    own:SetScript("OnClick", function(self)
        local on = self:GetChecked() and true or false
        PlaySound(on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        if editingID then RM():SetOwnKey(editingID, on) end
        Changed()
        Refresh()
    end)
    Hover(own, "rm.ownKey")
    host.ownKey = own

    -- a macro that opens it, made on the spot (the key row's right end)
    host.macroButton = RedButton(host, S:Text("rm.macroCreate", "label"), 110, CreateRadialMacro)
    host.macroButton:SetHeight(22)
    host.macroButton:SetPoint("TOPRIGHT", host, "TOPLEFT", x + width, -FORM_TOP - 16)
    Hover(host.macroButton, "rm.macroCreate")

    local line = Divider(host)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", x, -LOWER_TOP + 8)
    line:SetPoint("TOPRIGHT", 0, -LOWER_TOP + 8)

    -- nothing to show: every radial deleted
    local empty = Text(host, "GameFontDisable", L["No radials yet. Create one with + New radial."])
    empty:SetPoint("TOPLEFT", x + 2, -10)
    host.empty = empty
end

local function BuildLower(host, height, width)
    local x, top = DETAIL_X, LOWER_TOP
    -- left to right: the Catalog, the radial's buttons, the preview
    local previewX = x + width - PREVIEW_W
    local buttonsX = previewX - 14 - BUTTON_LIST_W
    local catX = x
    local gridW = buttonsX - 16 - catX

    -- the radial's buttons, in order
    VLine(host, buttonsX - 8)
    local buttonsTitle = Text(host, "GameFontNormal", L["Buttons"])
    buttonsTitle:SetPoint("TOPLEFT", buttonsX, -top)
    local listTop = top + 22
    local listRows = math.max(4, math.floor((height - listTop - 4) / BUTTON_ROW_H))
    local buttonList = CreateList(host, BUTTON_LIST_W, 1, listRows, BUTTON_ROW_H,
        function(cell)
            cell:SetScript("OnEnter", function(self)
                if not self.item then return end
                EntryTooltip(self, self.item, L["Drag to reorder, right-click to remove."])
            end)
            cell.Text:SetFontObject("GameFontDisableSmall")
            cell.Text:ClearAllPoints()
            cell.Text:SetPoint("LEFT", 0, 0)
            cell.Text:SetWidth(14)
            cell.Text:SetJustifyH("RIGHT")
            cell.Icon:ClearAllPoints()
            cell.Icon:SetPoint("LEFT", cell.Text, "RIGHT", 4, 0)
            cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
            cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            cell:RegisterForDrag("LeftButton")
            cell:SetScript("OnDragStart", function(self)
                if self.dataIndex then StartDrag({ from = self.dataIndex, entry = self.item }) end
            end)
            cell:SetScript("OnDragStop", FinishDrag)
            -- something on the game cursor goes in at this row
            cell:SetScript("OnReceiveDrag", function(self)
                local entry = EntryFromCursor()
                if entry then InsertEntry(entry, self.dataIndex) end
            end)
            cell:SetScript("OnClick", function(self, mouseButton)
                if not self.dataIndex then return end
                if mouseButton == "RightButton" then
                    RemoveButton(self.dataIndex)
                else
                    local entry = EntryFromCursor()
                    if entry then
                        InsertEntry(entry, self.dataIndex)
                        return
                    end
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
        end)
    buttonList:SetPoint("TOPLEFT", buttonsX, -listTop)
    host.buttonList = buttonList

    local dropZone = CreateFrame("Frame", nil, host)
    dropZone:SetPoint("TOPLEFT", buttonList, "TOPLEFT")
    dropZone:SetPoint("BOTTOMRIGHT", buttonList, "BOTTOMRIGHT", 0, -6)
    dropZone:SetFrameLevel(math.max(0, buttonList:GetFrameLevel() - 1))
    dropZone:EnableMouse(true)
    dropZone:SetScript("OnReceiveDrag", function()
        local entry = EntryFromCursor()
        if entry then InsertEntry(entry) end
    end)
    dropZone:SetScript("OnMouseUp", function()
        local entry = EntryFromCursor()
        if entry then InsertEntry(entry) end
    end)
    host.dropZone = dropZone

    -- the Catalog: its category menu beside the title, a two-column grid, search at the bottom right
    local catalogTitle = Text(host, "GameFontNormal", L["Catalog"])
    catalogTitle:SetPoint("TOPLEFT", catX + 4, -top)
    local category = CreateFrame("DropdownButton", nil, host, "WowStyle1DropdownTemplate")
    category:SetWidth(160)
    category:SetPoint("TOPRIGHT", host, "TOPLEFT", catX + gridW, -top + 4)
    category:SetupMenu(function(_, root)
        for _, c in ipairs(CATEGORIES) do
            root:CreateRadio(c.label, function() return activeCategory == c.key end, function()
                activeCategory = c.key
                host.search:SetText("")
                RefreshBrowse()
            end)
        end
    end)
    host.categoryDrop = category

    local gridRows = math.max(4, math.floor((height - top - 26 - 34) / GRID_ROW_H))
    local browseList = CreateList(host, gridW, 2, gridRows, GRID_ROW_H,
        function(cell)
            cell:RegisterForDrag("LeftButton")
            cell:SetScript("OnEnter", function(self)
                if not self.item then return end
                -- a category's note (Radials explains sub-radials) comes with every entry's tooltip
                local note = host.categoryNote
                EntryTooltip(self, self.item, (note and (note .. "\n\n") or "") .. L["Click or drag to add it."])
            end)
            cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
    browseList:SetPoint("TOPLEFT", catX, -top - 26)
    host.browseList = browseList

    local search = CreateFrame("EditBox", nil, host, "SearchBoxTemplate")
    -- level with the settings search in the left column
    search:SetSize(180, 22)
    search:SetPoint("BOTTOMRIGHT", host, "BOTTOMLEFT", catX + gridW, -2)
    search:HookScript("OnTextChanged", function() if host:IsShown() then RefreshBrowse() end end)
    host.search = search

    -- the live preview; how to edit and Undo below it
    VLine(host, previewX - 7)
    local previewLabel = Text(host, "GameFontNormal", L["Live Preview"])
    previewLabel:SetPoint("TOPLEFT", previewX + 4, -top)
    local previewArea = CreateFrame("Frame", nil, host)
    previewArea:SetPoint("TOPLEFT", previewX, -top - 22)
    previewArea:SetSize(PREVIEW_W, PREVIEW_W)
    host.previewArea = previewArea
    local hint = Text(host, "GameFontDisableSmall", L["Click or drag from the Catalog to add a button. Drag buttons to reorder, right-click to remove."])
    hint:SetPoint("TOPLEFT", previewArea, "BOTTOMLEFT", 4, -8)
    hint:SetWidth(PREVIEW_W - 8)
    hint:SetSpacing(2)
    -- greyed until something changed
    host.undoButton = RedButton(host, L["Undo changes"], 120, function()
        RestoreSnapshot()
        TakeSnapshot()
        Refresh()
    end)
    host.undoButton:SetPoint("BOTTOMRIGHT", 0, -2)
end

local function BuildEmbedded(host, column)
    editor = host
    local height = host:GetHeight() > 0 and host:GetHeight() or 530
    local width = (ns.SettingsPanel.WIDE_W or 634) - DETAIL_X

    BuildRadialColumn(host, column)
    BuildDetails(host, width)
    BuildLower(host, height, width)

    -- opening takes the Undo snapshot; leaving keeps the edits
    host:SetScript("OnShow", function()
        browseCache = {}
        host.column:Show()
        TakeSnapshot()
    end)
    host:SetScript("OnHide", function()
        host.column:Hide()
        dirty, snapshot = false, nil
        if popup then popup:Hide() end
        if RM() then RM():HidePreview() end
        StopDrag()
    end)
    browseCache = {}
    TakeSnapshot()
end

--------------------------------------------------
-- 12. REFRESH
--------------------------------------------------
-- the Catalog alone (categories, their note and the filtered grid)
function RefreshBrowse()
    activeCategory = activeCategory or CATEGORIES[1].key
    local category
    for _, c in ipairs(CATEGORIES) do
        if c.key == activeCategory then category = c end
    end
    editor.categoryDrop:GenerateMenu()
    editor.categoryNote = category and category.note

    -- cached per opening; Radials depends on the edited radial and is rebuilt each time
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
end

-- the radials column: the ones this character gets in list order, then the others under a header;
-- "On this character" follows the last row
local function RefreshRadialColumn(perRadial)
    local rm = RM()
    local here, other = {}, {}
    for _, id in ipairs(rm:GetRadialOrder()) do
        if rm:GetRadial(id) then
            local available = rm:IsRadialAvailable(id)
            local key = available and rm:GetRadialKey(id) or rm:GetSharedKey(id)
            local beatenBy = perRadial[id] and perRadial[id].beatenBy
            local item = { id = id, available = available, key = key, beaten = beatenBy ~= nil, beatenBy = beatenBy }
            if available then here[#here + 1] = item else other[#other + 1] = item end
        end
    end
    if #other > 0 then
        here[#here + 1] = { header = L["Not on this character"] }
        for _, item in ipairs(other) do here[#here + 1] = item end
    end
    editor.radialList:SetData(here)
    local shown = math.min(#here, editor.radialRows)
    editor.overviewTitle:ClearAllPoints()
    editor.overviewTitle:SetPoint("TOPLEFT", editor.column, "TOPLEFT", 4, -26 - shown * RADIAL_ROW_H - 18)

    -- what opens on this character: working keys in list order, then clashes
    local lines, clashes = {}, {}
    for _, id in ipairs(rm:GetRadialOrder()) do
        local info = perRadial[id]
        if info then
            local name = rm:GetRadial(id).name
            if not info.beatenBy then
                lines[#lines + 1] = "|cffffd100" .. KeyText(info.key) .. "|r  " .. name
            elseif info.tie then
                clashes[#clashes + 1] = "|cffff4040" .. KeyText(info.key) .. "  " .. name .. " (" .. L["clash"] .. ")|r"
            end
        end
    end
    for _, line in ipairs(clashes) do lines[#lines + 1] = line end
    if #lines == 0 then lines[1] = "|cff808080" .. L["No keys yet."] .. "|r" end
    editor.overview:SetText(table.concat(lines, "\n"))
end

function Refresh()
    if not (editor and editor:IsShown()) then return end
    local rm = RM()
    local radial = CurrentRadial()
    local _, perRadial = rm:ResolveKeys()

    RefreshRadialColumn(perRadial)

    local has = radial ~= nil
    for _, region in ipairs({ editor.nameText, editor.deleteButton, editor.copyButton, editor.renameButton,
        editor.scopeLabel, editor.scopeDrop, editor.keyLabel, editor.keyButton, editor.ownKey,
        editor.macroButton }) do
        region:SetShown(has)
    end
    editor.empty:SetShown(not has)

    if has then
        editor.nameText:SetText(radial.name)
        editor.scopeDrop:SetDefaultText(ScopeText(radial.scope, radial))
        editor.scopeDrop:GenerateMenu()
        editor.ownKey:SetChecked(rm:HasOwnKey(editingID))
        if not editor.keyButton.waiting then editor.keyButton:ShowKey(rm:GetRadialKey(editingID) or "") end
    end
    editor.buttonList:SetData(radial and radial.buttons or {})
    editor.undoButton:SetEnabled(dirty == true)

    RefreshBrowse()

    if rm and editingID then rm:ShowPreview(editingID, editor.previewArea) else rm:HidePreview() end
end

--------------------------------------------------
-- 13. PUBLIC
--------------------------------------------------
-- used by Settings/Pages/RadialMenu.lua
ns.RadialEditorEmbed = {
    Build = BuildEmbedded,
    Refresh = function() if editor then Refresh() end end,
}
