local _, ns = ...
local L = ns.L

--------------------------------------------------
-- BUFF REMINDERS EDITOR (6.2)
-- The Buff Reminders page's Reminders tab: the reminder bar as it looks in game (missing in gold,
-- running out in orange, kept up dimmed), a spellbook to pick from (the class's own, a tab per
-- spellbook line, the bags, upkeep) and, in the info panel's column, the picked reminder: who it is
-- checked on, how early it warns, where it shows, its own choices, its place on the bar. Edits are
-- live (Modules/BuffReminders.lua: BR.Bar, BR.SetOpt, BR.Choices); the page redraws on BR.OnChanged.
--------------------------------------------------
local Ed = {}
ns.BuffRemindersEditor = Ed

local BRONZE       = { 0.80, 0.60, 0.34 }
local BRONZE_MUTED = { 0.61, 0.48, 0.29 }
local GOLD         = { 1, 0.82, 0.25 }   -- a missing buff (the module's glow)
local ORANGE       = { 1, 0.45, 0.10 }   -- running out
local WHITE        = "Interface\\Buttons\\WHITE8X8"
local CHECK        = "Interface\\RaidFrame\\ReadyCheck-Ready"
local FALLBACK_ICON = 134400

local BAR_ICON, BAR_SLOT = 36, 52        -- the bar's icons and the room each takes
local BAR_H = 76
local CELL_H, RAIL_W = 40, 44            -- the spellbook's rows and its tab rail
local COLUMN_PAD = 12

local editor                             -- the middle host
local inspector, inspectorFrame          -- the picked reminder's controls, in the right column (shared
                                         -- with other pages' custom tabs: shown with the host only)
local selected                           -- the picked reminder's id
local activeTab = "class"
local catalog                            -- BR.Catalog(), made on show and when spells or bags change

local function BR() return ns.BuffReminders end

--------------------------------------------------
-- 1. PIECES
--------------------------------------------------
local function Text(parent, font, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", font)
    if text then fs:SetText(text) end
    fs:SetJustifyH("LEFT")
    return fs
end

local function Bordered(parent, edge)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = edge or 1 })
    return f
end

-- quiet text actions (Use Defaults), as the radial editor's
local function LinkButton(parent, text, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetNormalFontObject("GameFontNormalSmall")
    b:SetHighlightFontObject("GameFontHighlightSmall")
    b:SetDisabledFontObject("GameFontDisableSmall")
    b:SetText(text)
    b:SetSize(math.max(20, b:GetFontString():GetStringWidth() + 10), 20)
    b:SetScript("OnClick", function(...)
        ns.ButtonSound()
        onClick(...)
    end)
    return b
end

local function PanelButton(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    if ns.SkinButton then ns.SkinButton(b) end
    b:SetSize(width, 24)
    b:SetText(text)
    b:SetScript("OnClick", function(...)
        ns.ButtonSound()
        onClick(...)
    end)
    return b
end

local function ArrowButton(parent, dir, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(24, 24)
    local name = dir < 0 and "Prev" or "Next"
    b:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. name .. "Page-Up")
    b:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. name .. "Page-Down")
    b:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. name .. "Page-Disabled")
    b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    b:SetScript("OnClick", function()
        ns.ButtonSound()
        onClick()
    end)
    return b
end

local function Tip(owner, title, lines)
    ns.OwnGameTooltip(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(title, 1, 1, 1)
    for _, line in ipairs(lines or {}) do
        if line[1] then GameTooltip:AddLine(line[1], line[2] or 1, line[3] or 0.82, line[4] or 0, true) end
    end
    GameTooltip:Show()
end

local function SetIcon(tex, icon)
    tex:SetTexture(icon or FALLBACK_ICON)
    tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
end

-- a spellbook entry's id on the bar: a built-in's, or your own made of that spell or item (if any)
local function EntryId(item)
    if item.spell then return (BR().FindOwn(item.spell)) end
    if item.item then return (BR().FindOwn(nil, item.item)) end
    return item.id
end

--------------------------------------------------
-- 2. THE BAR
--------------------------------------------------
local function BarButton(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(BAR_SLOT, BAR_H - 12)
    b.edge = Bordered(b, 2)
    b.edge:SetPoint("TOP", 0, 0)
    b.icon = b.edge:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    b.caption = Text(b, "GameFontHighlightSmall")
    b.caption:SetJustifyH("CENTER")
    b.caption:SetPoint("TOP", b.edge, "BOTTOM", 0, -3)
    b.caption:SetWidth(BAR_SLOT + 4)
    b.caption:SetWordWrap(false)
    b.underline = b:CreateTexture(nil, "ARTWORK")
    b.underline:SetColorTexture(1, 0.9, 0.7, 1)
    b.underline:SetSize(24, 2)
    b.underline:SetPoint("TOP", b.caption, "BOTTOM", 0, -3)
    b:SetScript("OnClick", function(self)
        ns.ButtonSound()
        Ed.Select(self.id)
    end)
    b:SetScript("OnEnter", function(self)
        if not self.id then return end
        local d = BR().Display(self.id)
        Tip(self, d.name, { { d.counts, 0.8, 0.8, 0.8 }, { self.state and self.state.caption, 1, 0.82, 0 },
                            { L["Click to change it."], 0.6, 0.6, 0.6 } })
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    return b
end

local function RefreshBar()
    local bar = BR().Bar()
    local strip = editor.strip
    local width = strip:GetWidth() > 0 and strip:GetWidth() or ((ns.SettingsPanel.MIDDLE_W or 636) - 24)
    -- more than fit: each takes less room, the icons get smaller
    local slot = math.min(BAR_SLOT, math.floor((width - 16) / math.max(1, #bar)))
    local icon = math.max(18, math.min(BAR_ICON, slot - 12))
    for i, id in ipairs(bar) do
        local b = editor.barButtons[i]
        if not b then
            b = BarButton(strip)
            editor.barButtons[i] = b
        end
        local d = BR().Display(id)
        local state = BR().PreviewState(id)
        b.id, b.state = id, state
        b:SetWidth(slot)
        b.edge:SetSize(icon + 4, icon + 4)
        b.caption:SetWidth(slot + 4)
        SetIcon(b.icon, d.icon)
        b.caption:SetText(state.caption)
        b.icon:SetDesaturated(state.status == "unknown")
        if state.status == "missing" then
            b.edge:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
            b.caption:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
            b.edge:SetAlpha(1)
        elseif state.status == "expiring" then
            b.edge:SetBackdropBorderColor(ORANGE[1], ORANGE[2], ORANGE[3], 1)
            b.caption:SetTextColor(1, 0.6, 0.3)
            b.edge:SetAlpha(1)
        else
            -- kept up (hidden in game) or not learned: dimmed
            b.edge:SetBackdropBorderColor(0, 0, 0, 1)
            b.caption:SetTextColor(0.6, 0.56, 0.48)
            b.edge:SetAlpha(0.55)
        end
        b.edge:SetBackdropColor(0, 0, 0, 0.6)
        b.underline:SetShown(id == selected)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", strip, "TOPLEFT", 8 + (i - 1) * slot, -8)
        b:Show()
    end
    for i = #bar + 1, #editor.barButtons do editor.barButtons[i]:Hide() end
    editor.barEmpty:SetShown(#bar == 0)
end

--------------------------------------------------
-- 3. THE SPELLBOOK
--------------------------------------------------
local function ItemsShown()
    local filter = editor.search:GetText():lower()
    if filter == "" then
        for _, tab in ipairs(catalog) do
            if tab.key == activeTab then return tab.items, tab end
        end
        activeTab = catalog[1] and catalog[1].key
        return catalog[1] and catalog[1].items or {}, catalog[1]
    end
    -- every tab's matches, each reminder once
    local out, seen = {}, {}
    for _, tab in ipairs(catalog) do
        for _, item in ipairs(tab.items) do
            local key = item.id or item.name
            if not seen[key] and (item.name or ""):lower():find(filter, 1, true) then
                seen[key] = true
                out[#out + 1] = item
            end
        end
    end
    return out
end

local function PickItem(item)
    if not item or item.state ~= "add" then return end
    local id = EntryId(item)
    if not (id and BR().OnBar(id)) then
        if item.spell or item.item then
            id = BR().AddOwn(item.spell, item.item)
        else
            id = BR().AddToBar(item.id)
        end
    end
    if id then Ed.Select(id) end
end

local function FillCell(cell, item)
    local id = EntryId(item)
    local onBar = id and BR().OnBar(id)
    SetIcon(cell.icon, item.icon)
    local usable = item.state == "add"
    cell.icon:SetDesaturated(not usable)
    cell.icon:SetAlpha(usable and 1 or 0.5)
    cell.name:SetText(item.name)
    cell.name:SetTextColor(usable and 1 or 0.5, usable and 0.92 or 0.5, usable and 0.8 or 0.5)
    local sub
    if item.state == "locked" then sub = L["Not learned yet"]
    elseif item.state == "none" then sub = L["Not a buff"]
    elseif onBar then sub = id == selected and L["On the bar: editing"] or L["On the bar: click to change it"]
    else sub = item.sub end
    cell.sub:SetText(sub or "")
    if onBar then cell.sub:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) else cell.sub:SetTextColor(0.6, 0.58, 0.52) end
    cell.check:SetShown(onBar and true or false)
    cell.selected:SetShown(onBar and id == selected or false)
end

local function BuildBook(host, top, width, height)
    local title = Text(host, "GameFontNormal", L["Spellbook"])
    title:SetPoint("TOPLEFT", 4, -top)
    local search = CreateFrame("EditBox", nil, host, "SearchBoxTemplate")
    search:SetSize(200, 22)
    search:SetPoint("TOPRIGHT", host, "TOPLEFT", width - RAIL_W, -top + 4)
    search:HookScript("OnTextChanged", function() if host:IsShown() then Ed.RefreshBook(true) end end)
    host.search = search

    local gridTop = top + 26
    local gridW = width - RAIL_W - 8
    local rows = math.max(4, math.floor((height - gridTop - 24) / CELL_H))
    local box = Bordered(host)
    box:SetBackdropColor(0, 0, 0, 0.25)
    box:SetBackdropBorderColor(BRONZE_MUTED[1], BRONZE_MUTED[2], BRONZE_MUTED[3], 0.45)
    box:SetPoint("TOPLEFT", 0, -gridTop + 4)
    box:SetSize(gridW + 4, rows * CELL_H + 8)

    local list = CreateFrame("Frame", nil, host)
    list:SetPoint("TOPLEFT", 4, -gridTop)
    list:SetSize(gridW - 4, rows * CELL_H)
    list.rows, list.columns, list.offset, list.maxOffset, list.data, list.cells = rows, 2, 0, 0, {}, {}
    local cellW = (gridW - 18) / 2
    for i = 1, rows * 2 do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        local cell = CreateFrame("Button", nil, list)
        cell:SetSize(cellW, CELL_H - 2)
        cell:SetPoint("TOPLEFT", col * (cellW + 4), -row * CELL_H)
        cell.selected = cell:CreateTexture(nil, "BACKGROUND")
        cell.selected:SetAllPoints()
        ns.SettingsPanel.Rounded(cell.selected, BRONZE[1], BRONZE[2], BRONZE[3], 0.25)
        cell:SetHighlightTexture(WHITE)
        ns.SettingsPanel.Rounded(cell:GetHighlightTexture(), BRONZE[1], BRONZE[2], BRONZE[3], 0.15)
        cell.icon = cell:CreateTexture(nil, "ARTWORK")
        cell.icon:SetSize(CELL_H - 10, CELL_H - 10)
        cell.icon:SetPoint("LEFT", 4, 0)
        cell.check = cell:CreateTexture(nil, "OVERLAY")
        cell.check:SetTexture(CHECK)
        cell.check:SetSize(14, 14)
        cell.check:SetPoint("BOTTOMRIGHT", cell.icon, "BOTTOMRIGHT", 4, -4)
        cell.name = Text(cell, "GameFontHighlight")
        cell.name:SetPoint("TOPLEFT", cell.icon, "TOPRIGHT", 8, -1)
        cell.name:SetPoint("RIGHT", -4, 0)
        cell.name:SetWordWrap(false)
        cell.sub = Text(cell, "GameFontHighlightSmall")
        cell.sub:SetPoint("BOTTOMLEFT", cell.icon, "BOTTOMRIGHT", 8, 1)
        cell.sub:SetPoint("RIGHT", -4, 0)
        cell.sub:SetWordWrap(false)
        cell:SetScript("OnClick", function(self)
            if not self.item or self.item.state ~= "add" then return end
            ns.ButtonSound()
            PickItem(self.item)
        end)
        cell:SetScript("OnEnter", function(self)
            local item = self.item
            if not item then return end
            ns.OwnGameTooltip(self, "ANCHOR_RIGHT")
            if item.spell then GameTooltip:SetSpellByID(item.spell)
            elseif item.item then GameTooltip:SetItemByID(item.item)
            else
                GameTooltip:AddLine(item.name, 1, 1, 1)
                if item.sub then GameTooltip:AddLine(item.sub, 0.8, 0.8, 0.8, true) end
            end
            local id = EntryId(item)
            local hint = item.state == "none" and L["It leaves no buff to watch."]
                or item.state == "locked" and L["You haven't learned it yet."]
                or (id and BR().OnBar(id)) and L["On the bar. Click to change it."]
                or L["Click to put it on the bar."]
            GameTooltip:AddLine(hint, 0.6, 0.6, 0.6, true)
            GameTooltip:Show()
        end)
        cell:SetScript("OnLeave", GameTooltip_Hide)
        list.cells[i] = cell
    end
    list.empty = Text(list, "GameFontDisableSmall")
    list.empty:SetPoint("TOPLEFT", 8, -14)
    list.empty:SetPoint("TOPRIGHT", -8, -14)
    list.empty:SetJustifyH("CENTER")

    -- scrolling: the wheel and the settings panel's thin line
    local line = ns.SettingsPanel.ScrollLine(list)
    line:SetPoint("TOPRIGHT", list, "TOPRIGHT", 4, 0)
    line:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", 4, 0)
    local function Sync()
        local total = math.max(rows, math.ceil(#list.data / 2))
        line:SetValues(rows / total, list.maxOffset > 0 and list.offset / list.maxOffset or 0)
    end
    function list:Update()
        for i, cell in ipairs(self.cells) do
            local item = self.data[self.offset * 2 + i]
            cell.item = item
            if item then FillCell(cell, item); cell:Show() else cell:Hide() end
        end
    end
    local function SetOffset(offset)
        offset = math.max(0, math.min(list.maxOffset, math.floor(offset + 0.5)))
        if offset == list.offset then return end
        list.offset = offset
        list:Update()
        Sync()
    end
    function list:SetData(data, keepOffset)
        self.data = data or {}
        self.maxOffset = math.max(0, math.ceil(#self.data / 2) - rows)
        if not keepOffset then self.offset = 0 end
        if self.offset > self.maxOffset then self.offset = self.maxOffset end
        Sync()
        self:Update()
    end
    line.onScroll = function(position) SetOffset(position * list.maxOffset) end
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta) SetOffset(list.offset - delta) end)
    host.book = list

    local hint = Text(host, "GameFontDisableSmall", L["Click a buff to put it on the bar. Greyed spells leave no buff to watch."])
    hint:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 4, -6)
    hint:SetPoint("RIGHT", box, "RIGHT", -4, 0)

    -- the tabs, down the book's right edge as the game's spellbook
    local rail = CreateFrame("Frame", nil, host)
    rail:SetPoint("TOPLEFT", box, "TOPRIGHT", 4, -6)
    rail:SetSize(RAIL_W - 8, rows * CELL_H)
    host.rail, host.tabButtons = rail, {}
end

local function TabButton(rail)
    local b = CreateFrame("Button", nil, rail)
    b:SetSize(34, 34)
    b.edge = Bordered(b)
    b.edge:SetAllPoints()
    b.edge:SetBackdropColor(0, 0, 0, 0.5)
    b.icon = b.edge:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetScript("OnClick", function(self)
        ns.ButtonSound()
        activeTab = self.key
        editor.search:SetText("")
        Ed.RefreshBook()
    end)
    b:SetScript("OnEnter", function(self) Tip(self, self.label) end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    return b
end

local function RefreshTabs(searching)
    local rail = editor.rail
    local step = math.min(40, math.floor(rail:GetHeight() / math.max(1, #catalog)))
    for i, tab in ipairs(catalog) do
        local b = editor.tabButtons[i]
        if not b then
            b = TabButton(rail)
            editor.tabButtons[i] = b
        end
        b.key, b.label = tab.key, tab.label
        b:SetSize(math.min(34, step - 4), math.min(34, step - 4))
        local coords = tab.classIcon and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[tab.classIcon]
        if coords then
            b.icon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
            b.icon:SetTexCoord(unpack(coords))
        else
            SetIcon(b.icon, tab.icon)
        end
        local on = not searching and tab.key == activeTab
        b.icon:SetDesaturated(not on)
        b.icon:SetAlpha(on and 1 or 0.7)
        if on then
            b.edge:SetBackdropBorderColor(BRONZE[1], BRONZE[2], BRONZE[3], 1)
        else
            b.edge:SetBackdropBorderColor(BRONZE_MUTED[1], BRONZE_MUTED[2], BRONZE_MUTED[3], 0.4)
        end
        b:ClearAllPoints()
        b:SetPoint("TOP", rail, "TOP", 0, -(i - 1) * step)
        b:Show()
    end
    for i = #catalog + 1, #editor.tabButtons do editor.tabButtons[i]:Hide() end
end

-- keep: the same tab and search, only the states changed (keeps the scroll place)
function Ed.RefreshBook(keep)
    if not (editor and catalog) then return end
    local searching = editor.search:GetText() ~= ""
    local items = ItemsShown()
    editor.book:SetData(items, keep)
    RefreshTabs(searching)
    local why = #items == 0 and (searching and L["Nothing matches your search."] or L["Nothing here yet."]) or nil
    editor.book.empty:SetText(why or "")
    editor.book.empty:SetShown(why ~= nil)
end

--------------------------------------------------
-- 4. THE PICKED REMINDER (the right column)
--------------------------------------------------
local GROUPS = {
    { field = "who", label = L["Check On"],
      options = { { "self", L["Me"] }, { "party", L["Party"] }, { "all", L["Raid"] } } },
    { field = "before", label = L["Remind Me"],
      options = { { 0, L["Missing"] }, { 1, "1m" }, { 2, "2m" }, { 3, "3m" }, { 5, "5m" }, { 10, "10m" } } },
    { field = "where", label = L["Show"],
      options = { { "always", L["Always"] }, { "instance", L["Instances"] }, { "raid", L["Raids"] } } },
}

local function SegButton(parent)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    b:SetHeight(24)
    b.text = Text(b, "GameFontHighlightSmall")
    b.text:SetJustifyH("CENTER")
    b.text:SetPoint("CENTER")
    b:SetScript("OnClick", function(self)
        ns.ButtonSound()
        if self.onPick then self.onPick() end
    end)
    return b
end

local function PaintSeg(b, on)
    if on then
        b:SetBackdropColor(BRONZE[1], BRONZE[2], BRONZE[3], 0.35)
        b:SetBackdropBorderColor(BRONZE[1], BRONZE[2], BRONZE[3], 0.9)
        b.text:SetTextColor(1, 0.9, 0.7)
    else
        b:SetBackdropColor(0, 0, 0, 0.35)
        b:SetBackdropBorderColor(BRONZE_MUTED[1], BRONZE_MUTED[2], BRONZE_MUTED[3], 0.45)
        b.text:SetTextColor(0.75, 0.72, 0.66)
    end
end

-- a row of choices, each as wide as its word needs, filling the column
local function LayoutSegs(group, width)
    local total, n = 0, #group.buttons
    for _, b in ipairs(group.buttons) do total = total + b.text:GetStringWidth() + 10 end
    local spare = math.max(0, width - total - (n - 1) * 2)
    local x = 0
    for _, b in ipairs(group.buttons) do
        local w = math.floor(b.text:GetStringWidth() + 10 + spare / n)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", group.frame, "TOPLEFT", x, -16)
        b:SetWidth(w)
        x = x + w + 2
    end
end

local function BuildInspector(col, width)
    local ins = { width = width }
    ins.icon = col:CreateTexture(nil, "ARTWORK")
    ins.icon:SetSize(36, 36)
    ins.icon:SetPoint("TOPLEFT", 0, 0)
    ins.name = Text(col, "GameFontNormal")
    ins.name:SetPoint("TOPLEFT", ins.icon, "TOPRIGHT", 8, -1)
    ins.name:SetWidth(width - 44)
    ins.name:SetWordWrap(false)
    ins.counts = Text(col, "GameFontHighlightSmall")
    ins.counts:SetPoint("TOPLEFT", ins.name, "BOTTOMLEFT", 0, -3)
    ins.counts:SetWidth(width - 44)
    ins.counts:SetTextColor(0.75, 0.72, 0.66)

    ins.place = Text(col, "GameFontNormalSmall")
    ins.prev = ArrowButton(col, -1, function() BR().MoveOnBar(selected, -1) end)
    ins.next = ArrowButton(col, 1, function() BR().MoveOnBar(selected, 1) end)
    ins.prev:SetScript("OnEnter", function(self) Tip(self, L["Move Left"]) end)
    ins.prev:SetScript("OnLeave", GameTooltip_Hide)
    ins.next:SetScript("OnEnter", function(self) Tip(self, L["Move Right"]) end)
    ins.next:SetScript("OnLeave", GameTooltip_Hide)

    ins.groups = {}
    for i, g in ipairs(GROUPS) do
        local frame = CreateFrame("Frame", nil, col)
        frame:SetSize(width, 42)
        local group = { def = g, frame = frame, buttons = {} }
        group.label = Text(frame, "GameFontNormalSmall")
        group.label:SetPoint("TOPLEFT", 0, 0)
        for j, o in ipairs(g.options) do
            local b = SegButton(frame)
            b.text:SetText(o[2])
            b.value = o[1]
            b.onPick = function() BR().SetOpt(selected, g.field, o[1]) end
            group.buttons[j] = b
        end
        LayoutSegs(group, width)
        ins.groups[i] = group
    end
    ins.defaults = LinkButton(col, L["Use Defaults"], function() BR().ResetOpts(selected) end)
    ins.defaults:SetScript("OnEnter", function(self)
        Tip(self, L["Use Defaults"], { { L["Its Check On, Remind Me and Show go back to the Defaults tab's."], 0.8, 0.8, 0.8 } })
    end)
    ins.defaults:SetScript("OnLeave", GameTooltip_Hide)
    ins.defaultsNote = Text(col, "GameFontDisableSmall", L["Using the Defaults tab"])

    -- its own choices (blessing, each hand's weapon buff, who keeps the Soulstone or Thorns): a button
    -- showing the pick, opening the radios
    ins.choices = {}
    for i = 1, 2 do
        local frame = CreateFrame("Frame", nil, col)
        frame:SetSize(width, 42)
        local c = { frame = frame }
        c.label = Text(frame, "GameFontNormalSmall")
        c.label:SetPoint("TOPLEFT", 0, 0)
        c.button = PanelButton(frame, "", width, function(self)
            local g = c.group
            if not (g and MenuUtil and MenuUtil.CreateContextMenu) then return end
            MenuUtil.CreateContextMenu(self, function(_, root)
                root:CreateTitle(g.title)
                for _, o in ipairs(g.options) do
                    root:CreateRadio(o.text, function() return BR().GetChoice(g) == o.value end,
                        function() BR().SetChoice(g, o.value) end)
                end
            end)
        end)
        c.button:SetPoint("TOPLEFT", 0, -16)
        ins.choices[i] = c
    end

    ins.remove = PanelButton(col, L["Take Off the Bar"], width, function()
        local id = selected
        local bar = BR().Bar()
        -- the next one along is picked after
        local nextId
        for i, have in ipairs(bar) do
            if have == id then nextId = bar[i + 1] or bar[i - 1] end
        end
        selected = nextId
        BR().RemoveFromBar(id)
    end)
    ins.remove:SetPoint("BOTTOMLEFT", col, "BOTTOMLEFT", 0, 0)

    ins.empty = Text(col, "GameFontHighlightSmall", L["Pick an icon on the bar, or a buff in the spellbook, to set who it checks, how early it warns you and where it shows."])
    ins.empty:SetPoint("TOPLEFT", 0, -4)
    ins.empty:SetWidth(width)
    ins.empty:SetTextColor(0.75, 0.72, 0.66)
    ins.emptyTitle = Text(col, "GameFontNormal", L["Nothing Picked"])
    ins.emptyTitle:SetPoint("BOTTOMLEFT", ins.empty, "TOPLEFT", 0, 6)
    return ins
end

local function RefreshInspector()
    local ins = inspector
    if not ins then return end
    local bar = BR().Bar()
    local place
    for i, id in ipairs(bar) do if id == selected then place = i end end
    if not place then selected = nil end
    local has = selected ~= nil
    for _, region in ipairs({ ins.icon, ins.name, ins.counts, ins.place, ins.prev, ins.next, ins.remove, ins.defaults, ins.defaultsNote }) do
        region:SetShown(has)
    end
    ins.empty:SetShown(not has)
    ins.emptyTitle:SetShown(not has)
    for _, g in ipairs(ins.groups) do g.frame:SetShown(has) end
    for _, c in ipairs(ins.choices) do c.frame:SetShown(false) end
    if not has then return end

    local d = BR().Display(selected)
    SetIcon(ins.icon, d.icon)
    ins.name:SetText(d.name)
    ins.counts:SetText(d.counts)
    local y = -math.max(40, 6 + ins.name:GetStringHeight() + ins.counts:GetStringHeight()) - 10

    ins.place:SetText(L["Place on the bar: %d of %d"]:format(place, #bar))
    ins.place:ClearAllPoints()
    ins.place:SetPoint("TOPLEFT", inspectorFrame, "TOPLEFT", 0, y - 6)
    ins.next:ClearAllPoints()
    ins.next:SetPoint("TOPRIGHT", inspectorFrame, "TOPRIGHT", 0, y)
    ins.prev:ClearAllPoints()
    ins.prev:SetPoint("RIGHT", ins.next, "LEFT", -2, 0)
    ins.prev:SetEnabled(place > 1)
    ins.next:SetEnabled(place < #bar)
    y = y - 34

    local fields = BR().OptFields(d.def)
    local own = false
    for _, g in ipairs(ins.groups) do
        local field = g.def.field
        local shown = fields[field] and true or false
        g.frame:SetShown(shown)
        if shown then
            local value, mine = BR().Opt(d.def, selected, field)
            own = own or mine
            g.label:SetText(g.def.label .. (mine and "" or ("  |cff808080" .. L["(default)"] .. "|r")))
            for _, b in ipairs(g.buttons) do PaintSeg(b, b.value == value) end
            g.frame:ClearAllPoints()
            g.frame:SetPoint("TOPLEFT", inspectorFrame, "TOPLEFT", 0, y)
            y = y - 48
        end
    end
    ins.defaults:SetShown(own)
    ins.defaultsNote:SetShown(not own)
    ins.defaults:ClearAllPoints()
    ins.defaults:SetPoint("TOPLEFT", inspectorFrame, "TOPLEFT", -4, y + 2)
    ins.defaultsNote:ClearAllPoints()
    ins.defaultsNote:SetPoint("TOPLEFT", inspectorFrame, "TOPLEFT", 0, y - 2)
    y = y - 26

    for i, g in ipairs(BR().Choices(d.def)) do
        local c = ins.choices[i]
        if c then
            c.group = g
            c.label:SetText(g.title)
            local current = BR().GetChoice(g)
            local text = current
            for _, o in ipairs(g.options) do if o.value == current then text = o.text end end
            c.button:SetText(text or "")
            c.frame:ClearAllPoints()
            c.frame:SetPoint("TOPLEFT", inspectorFrame, "TOPLEFT", 0, y)
            c.frame:Show()
            y = y - 48
        end
    end
end

--------------------------------------------------
-- 5. BUILD AND REFRESH
--------------------------------------------------
local function Rebuild()
    catalog = BR().Catalog()
end

function Ed.Select(id)
    selected = id
    Ed.Refresh(true)
end

function Ed.Build(host, col)
    editor = host
    host.barButtons = {}
    local width = host:GetWidth() > 0 and host:GetWidth() or ((ns.SettingsPanel.MIDDLE_W or 636) - 4)
    local height = host:GetHeight() > 0 and host:GetHeight() or 480

    -- the bar
    local title = Text(host, "GameFontNormal", L["Your Bar, as It Looks in Game"])
    title:SetPoint("TOPLEFT", 4, 0)
    local legend = Text(host, "GameFontHighlightSmall",
        "|cffffd140" .. L["Missing"] .. "|r   |cffff7319" .. L["Running Out"] .. "|r   |cff9c9480" .. L["Kept Up (hidden in game)"] .. "|r")
    legend:SetPoint("TOPRIGHT", host, "TOPLEFT", width - 8, -1)
    local strip = Bordered(host)
    strip:SetBackdropColor(0, 0, 0, 0.45)
    strip:SetBackdropBorderColor(BRONZE_MUTED[1], BRONZE_MUTED[2], BRONZE_MUTED[3], 0.45)
    strip:SetPoint("TOPLEFT", 0, -20)
    strip:SetSize(width - 8, BAR_H)
    host.strip = strip
    host.barEmpty = Text(strip, "GameFontDisableSmall", L["Empty. Pick buffs from the spellbook below."])
    host.barEmpty:SetPoint("CENTER")

    BuildBook(host, 20 + BAR_H + 14, width - 8, height)

    -- the picked reminder, in the right column
    local inner = CreateFrame("Frame", nil, col)
    inner:SetPoint("TOPLEFT", COLUMN_PAD, -COLUMN_PAD)
    inner:SetPoint("BOTTOMRIGHT", -COLUMN_PAD, COLUMN_PAD)
    inspectorFrame = inner
    local colW = col:GetWidth() > 0 and col:GetWidth() - 2 * COLUMN_PAD or ((ns.SettingsPanel.RIGHT_W or 280) - 2 * COLUMN_PAD)
    inspector = BuildInspector(inner, colW)
    inner:SetShown(host:IsShown())

    -- live: the bar's states, edits from the icons' menu; spells and bags change the spellbook
    BR().OnChanged(function()
        if editor and editor:IsVisible() then Ed.Refresh(true) end
    end)
    local events = CreateFrame("Frame", nil, host)
    events:SetScript("OnEvent", function()
        if not host:IsVisible() then return end
        -- (bags change in bursts: once, a moment later)
        if events.pending then return end
        events.pending = true
        C_Timer.After(0.5, function()
            events.pending = nil
            if host:IsVisible() then
                Rebuild()
                Ed.Refresh(true)
            end
        end)
    end)
    host:SetScript("OnShow", function()
        inner:Show()
        for _, e in ipairs({ "SPELLS_CHANGED", "BAG_UPDATE_DELAYED", "LEARNED_SPELL_IN_TAB" }) do pcall(events.RegisterEvent, events, e) end
        Rebuild()
    end)
    host:SetScript("OnHide", function()
        inner:Hide()
        events:UnregisterAllEvents()
    end)
    if host:IsShown() then
        for _, e in ipairs({ "SPELLS_CHANGED", "BAG_UPDATE_DELAYED", "LEARNED_SPELL_IN_TAB" }) do pcall(events.RegisterEvent, events, e) end
    end
    Rebuild()
end

-- keep: only states changed (the spellbook keeps its scroll place)
function Ed.Refresh(keep)
    if not (editor and BR() and BR().Bar) then return end
    if not catalog then Rebuild() end
    if not selected then selected = BR().Bar()[1] end
    RefreshBar()
    Ed.RefreshBook(keep)
    RefreshInspector()
end
