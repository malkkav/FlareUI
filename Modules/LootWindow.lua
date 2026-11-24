local _, ns = ...
local L = ns.L

--------------------------------------------------
-- LOOT WINDOW (Bags & Looting > Looting > Loot Window, off; PR #146 by Xentinus)
-- FlareUI's loot window in place of Blizzard's corpse and chest loot window. (11-23, Malkkav) built
-- like the loot roll window: its border and rock at full strength, its font; the item marks follow the
-- Bags options (Item Level, Junk, BoE, Uncollected, Skin Item Slots), the owned count always shows, and
-- the only option of its own is Show Free Bag Slots. Items stay in the order they dropped.
--------------------------------------------------
local LW = {}
ns.LootWindow = LW
ns.modules["LootWindow"] = LW

local ipairs, pairs = ipairs, pairs
local LSM = LibStub("LibSharedMedia-3.0")

-- after the loot roll window's (LootRolls.lua): side padding, the rows below its header separator
-- (11-23, Kelvan) TOP 34: the first row as far below the header line as the rows are from the sides
local W, PAD, TOP = 260, 8, 34
local ROW_H, ROW_GAP, ICON, BOX_PAD = 48, 4, 36, 6
local ROW_W = W - 2 * PAD
local FOOT = 26             -- the footer: a 22 px line and a gap above it
local MORE = 15             -- the "+N more" line under rows that scroll (LootRolls.lua's ROW)
local BAG_ICON = "Interface\\Buttons\\Button-Backpack-Up"

local win, current          -- the window; the rows it shows, in shown order
local pool, texts = {}, {}  -- row frames by position; name font strings
local offset = 0            -- rows of current scrolled past (the mouse wheel)

local function GetDb()
    return ns.db and ns.db.profile and ns.db.profile.tweaks
end

-- the open loot window's slots in loot order, empty ones left out
function LW.ReadSlots()
    local rows = {}
    local noneType = Enum.LootSlotType.None
    local itemLevelOf = ns.Bags and ns.Bags.ItemLevelOf
    for slot = 1, GetNumLootItems() do
        local slotType = GetLootSlotType(slot)
        if slotType ~= noneType then
            local texture, name, quantity, currencyID, quality, locked, isQuestItem, questID, isActive = GetLootSlotInfo(slot)
            local row = {
                slot = slot, type = slotType, texture = texture, name = name, quantity = quantity,
                quality = quality, locked = locked, isQuestItem = isQuestItem, questID = questID,
                isActive = isActive,
            }
            if currencyID then
                row.name, row.texture, row.quantity, row.quality =
                    CurrencyContainerUtil.GetCurrencyContainerInfo(currencyID, quantity, name, texture, quality)
            else
                row.link = GetLootSlotLink(slot)
                row.ilvl = row.link and itemLevelOf and itemLevelOf(row.link) or nil
            end
            rows[#rows + 1] = row
        end
    end
    return rows
end

-- the junk coin as on the bags (Bags.lua: grey with a sell value). GetItemInfo's 11th value, after
-- pcall's status; nil while the item isn't cached.
function LW.IsJunk(data)
    if data.type ~= Enum.LootSlotType.Item or data.quality ~= 0 or not data.link then return false end
    local price = select(12, pcall(C_Item.GetItemInfo, data.link))
    return type(price) == "number" and price > 0
end

-- how many of an item row's item the player carries, bank included; 0 for anything else
function LW.OwnedCount(data)
    if data.type ~= Enum.LootSlotType.Item or not data.link or not (C_Item and C_Item.GetItemCount) then return 0 end
    local ok, count = pcall(C_Item.GetItemCount, data.link, true)
    return ok and type(count) == "number" and count or 0
end

-- the item name with its owned count as a grey suffix: only when the count is above 0
function LW.NameWithCount(name, count)
    if type(name) == "string" and type(count) == "number" and count > 0 then
        return name .. " |cff999999(" .. count .. ")|r"
    end
    return name
end

function LW:ShouldLoad()
    local db = GetDb()
    return db and ns.BagModuleOn() and db.lootWindow and _G.LootFrame and not ns.IsGamepadUI() and true or false
end

--------------------------------------------------
-- THE WINDOW AND ITS ROWS
-- Built on first use. Rows are pooled by position; a looted row leaves and the ones below move up
-- without moving. Names in the loot roll window's font (tweaks.lootRollFont, small lines two sizes
-- smaller), the title in the Damage Meter's header font, as on the loot roll window.
--------------------------------------------------
local function StyleText(fs, small)
    local db = GetDb()
    local font = db and db.lootRollFont or {}
    local size = font.size or 12
    if small then size = math.max(6, size - 2) end
    local flags = font.flags or ""
    if flags == "NONE" then flags = "" end
    ns.SetFontFamily(fs, ns.GetFontPath(font.face or ns.GLOBAL_FONT), size, flags)
    ns.ApplyShadow(fs, font)
end

-- the item level in the bags' Item Level font (tweaks.bagItemLevelFont, Bags.lua StyleIconText)
local function StyleItemLevel(fs)
    local style, db = ns.Bags and ns.Bags.StyleIconText, GetDb()
    if style and db then style(fs, db.bagItemLevelFont) end
end

local function StyleTitle()
    local title = win and win.title
    local DM = ns.DamageMeter
    local dm = ns.db and ns.db.profile and ns.db.profile.damagemeter
    local font = title and DM and DM.HeaderFontDb and DM.HeaderFontDb(dm)
    if not font then return end
    local flags = font.flags or "NONE"
    if flags == "NONE" then flags = "" end
    ns.SetFont(title, ns.GetFontPath(font.face or "Friz Quadrata TT"), font.size or 12, flags)
    ns.ApplyShadow(title, font)
    local c = font.color or { r = 0.80, g = 0.60, b = 0.34 }
    title:SetTextColor(c.r, c.g, c.b, c.a or 1)
end

-- the bags' quality colours (Bags.lua), so the borders match; no quality counts as Common, as in
-- Blizzard's loot window
local function QualityColor(quality)
    local r, g, b
    if C_Item and C_Item.GetItemQualityColor then r, g, b = C_Item.GetItemQualityColor(quality or 1) end
    return r or 1, g or 1, b or 1
end

-- the bags' item border (Bags.ITEM_BORDERS: file, edge size, outset)
local function IconEdge(icon, style, r, g, b)
    local def = ns.Bags and ns.Bags.ITEM_BORDERS and ns.Bags.ITEM_BORDERS[style]
    local edge = icon.edge
    if not def then edge:Hide() return end
    if edge.style ~= style then
        edge.style = style
        edge:ClearAllPoints()
        edge:SetPoint("TOPLEFT", -def[3], def[3])
        edge:SetPoint("BOTTOMRIGHT", def[3], -def[3])
        edge:SetBackdrop({ edgeFile = LSM:Fetch("border", def[1]), edgeSize = def[2] })
    end
    edge:SetBackdropBorderColor(r, g, b, 1)
    edge:Show()
end

local function ShowTip(row)
    local data = row.data
    local types = Enum.LootSlotType
    if not data or (data.type ~= types.Item and data.type ~= types.Currency) then
        -- (a row that scrolled or moved up under the mouse may have had an item's tooltip)
        if GameTooltip:IsOwned(row) then GameTooltip:Hide() end
        return
    end
    ns.OwnGameTooltip(row, "ANCHOR_RIGHT")
    if data.type == types.Item then
        GameTooltip:SetLootItem(data.slot)
    else
        GameTooltip:SetLootCurrency(data.slot)
    end
end

-- Blizzard's loot window refreshes the tooltip while it is shown (LootFrame.lua's OnUpdate)
local function TipUpdate(row)
    if GameTooltip:IsOwned(row) then ShowTip(row) end
end

local function RowClick(row)
    local slot = row.data and row.data.slot
    if not slot then return end
    if IsModifiedClick() then
        HandleModifiedItemClick(GetLootSlotLink(slot))
        return
    end
    local JD = ns.JunkDelete
    if JD and JD.BeforeLootSlot then JD.BeforeLootSlot(slot) end
    LootSlot(slot)
end

local function NewRow(i)
    local row = CreateFrame("Button", nil, win, "BackdropTemplate")
    row:SetSize(ROW_W, ROW_H)
    row:SetPoint("TOPLEFT", PAD, -(TOP + (i - 1) * (ROW_H + ROW_GAP)))
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    -- the loot roll window's row box
    row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = LSM:Fetch("border", "FlareUI Thin"), edgeSize = 8,
        insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    row:SetBackdropColor(0, 0, 0, 0.3)
    row.wash = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.wash:SetPoint("TOPLEFT", 4, -4)
    row.wash:SetPoint("BOTTOMRIGHT", -4, 4)
    row.wash:SetColorTexture(1, 1, 1)
    row.wash:Hide()
    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints(row.wash)
    hover:SetColorTexture(1, 1, 1, 0.08)

    -- the icon: a plain frame, so the whole row takes the click
    local icon = CreateFrame("Frame", nil, row)
    icon:SetSize(ICON, ICON)
    icon:SetPoint("LEFT", BOX_PAD, 0)
    local black = icon:CreateTexture(nil, "BACKGROUND")
    black:SetPoint("TOPLEFT", -1, 1)
    black:SetPoint("BOTTOMRIGHT", 1, -1)
    black:SetColorTexture(0, 0, 0, 1)
    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints()
    icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon.edge = CreateFrame("Frame", nil, icon, "BackdropTemplate")
    row.icon = icon

    -- the marks above the edge, where the bags have them (Bags.lua GetOverlay)
    local marks = CreateFrame("Frame", nil, icon)
    marks:SetAllPoints()
    marks:SetFrameLevel(icon:GetFrameLevel() + 3)
    row.quest = marks:CreateTexture(nil, "OVERLAY")
    row.quest:SetAllPoints()
    row.junk = marks:CreateTexture(nil, "OVERLAY", nil, 7)
    row.junk:SetAtlas("bags-junkcoin", true)
    row.junk:SetPoint("TOPLEFT", 1, 0)
    row.boe = marks:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    row.boe:SetPoint("TOPLEFT", 2, -2)
    row.boe:SetText(L["BoE"])
    row.boe:SetTextColor(0.12, 1, 0.12)
    row.ilvl = marks:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    row.ilvl:SetPoint("BOTTOMLEFT", 2, 2)
    row.eye = marks:CreateTexture(nil, "OVERLAY", nil, 7)
    row.eye:SetAtlas("transmog-icon-hidden")
    row.eye:SetSize(14, 14)
    row.eye:SetPoint("TOPRIGHT", -1, -1)
    row.count = marks:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    row.count:SetPoint("BOTTOMRIGHT", -2, 2)

    local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    name:SetPoint("RIGHT", -BOX_PAD - 2, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(true)
    if name.SetMaxLines then name:SetMaxLines(2) end
    texts[name] = false
    StyleText(name)
    row.name = name

    row:SetScript("OnClick", RowClick)
    row:SetScript("OnEnter", function(self)
        ShowTip(self)
        self:SetScript("OnUpdate", TipUpdate)
    end)
    row:SetScript("OnLeave", function(self)
        self:SetScript("OnUpdate", nil)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    pool[i] = row
    return row
end

local function PaintRow(row, data, db)
    row.data = data
    local isMoney = data.type == Enum.LootSlotType.Money
    local icon = row.icon
    icon.texture:SetTexture(data.texture)
    if data.locked then
        icon.texture:SetVertexColor(0.9, 0, 0)
    else
        icon.texture:SetVertexColor(1, 1, 1)
    end
    local name = data.name
    -- the money text has a line per coin
    if isMoney and type(name) == "string" then name = name:gsub("\n", " ") end
    name = LW.NameWithCount(name, LW.OwnedCount(data))
    row.name:SetText(name)
    local r, g, b = QualityColor(data.quality)
    row.name:SetTextColor(r, g, b)
    local quantity = data.quantity
    row.count:SetText(quantity)
    row.count:SetShown(not isMoney and quantity and quantity > 1 or false)

    -- the icon border as the bags' Skin Item Slots: thin or thick, coloured by rarity when that is on
    -- (money keeps FlareUI's bronze: it has no quality)
    local c = ns.BORDER_COLOR
    local er, eg, eb = r, g, b
    if isMoney or db.bagRarity == false then er, eg, eb = c.r, c.g, c.b end
    IconEdge(icon, db.bagThickBorders and "thick" or "thin", er, eg, eb)
    row:SetBackdropBorderColor(c.r, c.g, c.b, c.a)

    -- Blizzard's quest marks (LootFrame.lua's element Init)
    if data.questID and not data.isActive then
        row.quest:SetTexture(TEXTURE_ITEM_QUEST_BANG)
        row.quest:Show()
    elseif data.questID or data.isQuestItem then
        row.quest:SetTexture(TEXTURE_ITEM_QUEST_BORDER)
        row.quest:Show()
    else
        row.quest:Hide()
    end

    local link = data.link
    local Bags = ns.Bags
    -- (the bags' own switches: Bags & Looting > Bags)
    row.junk:SetShown(db.bagJunkIcon and LW.IsJunk(data) or false)
    row.boe:SetShown(db.bagBoE and link and Bags and Bags.IsBoE(link) or false)
    row.eye:SetShown(db.bagUncollected and link and Bags and Bags.Uncollected(link) or false)
    if db.bagItemLevel and data.ilvl then
        StyleItemLevel(row.ilvl)
        row.ilvl:SetText(data.ilvl)
        row.ilvl:SetTextColor(r, g, b)
        row.ilvl:Show()
    else
        row.ilvl:Hide()
    end
end

-- the free slots in the normal bags (general bags only: a profession or reagent bag takes only its own)
function LW.FreeBagSlots()
    local free = 0
    for bag = _G.BACKPACK_CONTAINER or 0, _G.NUM_BAG_SLOTS or 4 do
        local n, family = C_Container.GetContainerNumFreeSlots(bag)
        if (family or 0) == 0 then free = free + (n or 0) end
    end
    return free
end

-- the footer (Free Bag Slots): its height only while it is on
local function FootH()
    local db = GetDb()
    return db and db.lootWindowFreeSlots and FOOT or 0
end

local function PaintFreeSlots()
    local footer = win and win.footer
    if not footer then return end
    local free = LW.FreeBagSlots()
    footer.count:SetText(free)
    -- (full: the minimap bar's full-bags red, Minimap.lua Bar.ALERT)
    if free > 0 then footer.count:SetTextColor(1, 1, 1) else footer.count:SetTextColor(1, 0.25, 0.25) end
end

local function LayoutFooter()
    local db = GetDb() or {}
    local footer = win.footer
    if not footer then
        if FootH() == 0 then return end
        footer = {}
        footer.count = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        footer.count:SetPoint("RIGHT", win, "BOTTOMRIGHT", -(PAD + 4), PAD + 11)
        texts[footer.count] = false
        StyleText(footer.count)
        footer.bag = win:CreateTexture(nil, "OVERLAY")
        footer.bag:SetSize(16, 16)
        footer.bag:SetTexture(BAG_ICON)
        footer.bag:SetPoint("RIGHT", footer.count, "LEFT", -4, 0)
        win.footer = footer
    end
    local slots = db.lootWindowFreeSlots and true or false
    footer.count:SetShown(slots)
    footer.bag:SetShown(slots)
    if slots then PaintFreeSlots() end
end

-- How many of total rows show in space px (at least one), and whether they scroll: rows that don't
-- all fit leave room under them for the "+N more" line.
function LW.FitRows(space, total)
    local function Fit(room) return math.max(1, math.floor((room + ROW_GAP) / (ROW_H + ROW_GAP))) end
    if total <= Fit(space) then return total, false end
    return Fit(space - MORE), true
end

-- the scroll thumb beside shown rows of total, offset rows down, over area px: its top and height
-- (as LootRolls.lua's)
function LW.ScrollThumb(total, shown, scrolled, area)
    return area * scrolled / total, area * shown / total
end

-- as many rows as fit the screen at the window's scale; the rest are reached with the mouse wheel
local function ShownRows(total)
    local screen = UIParent:GetHeight() * UIParent:GetEffectiveScale() / win:GetEffectiveScale()
    return LW.FitRows(screen - TOP - FootH() - PAD, total)
end

-- the loot roll window's scroll marks: a 2 px bronze thumb right of the rows, the rows still below
-- in a small grey line under them
local function PaintScroll(total, n, scrolls, area)
    win.thumb:SetShown(scrolls)
    local extra = 0
    if scrolls then
        local top, h = LW.ScrollThumb(total, n, offset, area)
        win.thumb:ClearAllPoints()
        win.thumb:SetPoint("TOPRIGHT", -5, -(TOP + top))
        win.thumb:SetHeight(h)
        -- (looted gaps below don't count)
        for i = offset + n + 1, total do
            if not current[i].looted then extra = extra + 1 end
        end
    end
    win.more:SetShown(extra > 0)
    if extra > 0 then
        win.more:ClearAllPoints()
        win.more:SetPoint("TOPLEFT", PAD + BOX_PAD, -(TOP + area + ROW_GAP + 2))
        win.more:SetText(L["+%d more"]:format(extra))
    end
end

local function Render()
    local db = GetDb() or {}
    local total = current and #current or 0
    local n, scrolls = ShownRows(total)
    offset = math.max(0, math.min(offset, total - n))
    local function Empty(row)
        row.data = nil
        row:SetScript("OnUpdate", nil)
        if GameTooltip:IsOwned(row) then GameTooltip:Hide() end
        row:Hide()
    end
    for i = 1, n do
        local row = pool[i] or NewRow(i)
        local data = current[offset + i]
        if data.looted then
            -- a looted row stays a gap, as Blizzard's: the rows below keep their place
            Empty(row)
        else
            PaintRow(row, data, db)
            row:Show()
            -- the hovered row's tooltip follows its new item (OnUpdate is set only while hovered)
            if row:GetScript("OnUpdate") then ShowTip(row) end
        end
    end
    for i = n + 1, #pool do Empty(pool[i]) end
    local area = n * ROW_H + math.max(0, n - 1) * ROW_GAP
    PaintScroll(total, n, scrolls, area)
    LayoutFooter()
    win:SetHeight(TOP + area + (scrolls and MORE or 0) + FootH() + PAD)
end

-- FlareUI's panel, as the loot roll window's: the thick border a little darker than its bronze, on
-- the plain rock with a shade toward the bottom, always at full strength
local function Panel(frame)
    local file = LSM:Fetch("border", "FlareUI Thick")
    frame:SetBackdrop({ edgeFile = file, edgeSize = ns.BorderEdgeSize(file, 16) })
    local c, dim = ns.BORDER_COLOR, 0.75
    frame:SetBackdropBorderColor(c.r * dim, c.g * dim, c.b * dim, c.a)
    if not frame.skin then
        local rock = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
        rock:SetPoint("TOPLEFT", 3, -3)
        rock:SetPoint("BOTTOMRIGHT", -3, 3)
        rock:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock", "REPEAT", "REPEAT")
        rock:SetHorizTile(true)
        rock:SetVertTile(true)
        local shade = frame:CreateTexture(nil, "BACKGROUND", nil, 3)
        shade:SetAllPoints(rock)
        shade:SetColorTexture(1, 1, 1)
        shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.45), CreateColor(0, 0, 0, 0))
        frame.skin = { rock, shade }
    end
end

function LW:Build()
    if win then return win end
    win = CreateFrame("Frame", "FlareUI_LootWindow", UIParent, "BackdropTemplate")
    win:SetSize(W, TOP + PAD)
    win:SetPoint("CENTER")
    win:SetFrameStrata("HIGH")
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    win:EnableMouseWheel(true)
    win:SetScript("OnMouseWheel", function(_, delta) LW:Scroll(delta) end)
    win:Hide()
    tinsert(UISpecialFrames, "FlareUI_LootWindow")
    LW.frame = win

    -- the loot roll window's header: title 17 px in, the button 21.5 px from the right, both 15 px
    -- down, the separator at 24 px
    local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", win, "TOPLEFT", 17, -15)
    title:SetText(L["Loot"])
    win.title = title
    -- the drag handle: the header strip, ending 4 px left of the close button (the scripts: Init)
    local grip = CreateFrame("Frame", nil, win)
    grip:SetHeight(26)
    grip:SetPoint("TOPLEFT")
    grip:SetPoint("TOPRIGHT", -37, 0)
    grip:EnableMouse(true)
    grip:RegisterForDrag("LeftButton")
    win.grip = grip
    -- Blizzard's red close button, as FlareUI's other closable windows (Settings/Panel.lua), sized
    -- to the low header where the loot roll window has its history button; win is no UI panel, so it
    -- hides itself rather than through HideUIPanel
    local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    close:SetSize(22, 22)
    close:SetPoint("CENTER", win, "TOPRIGHT", -21.5, -15)
    close:SetScript("OnClick", function() win:Hide() end)
    win.close = close
    local line = win:CreateTexture(nil, "OVERLAY")
    line:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
    line:SetHeight(8)
    line:SetPoint("TOPLEFT", 3, -24)
    line:SetPoint("TOPRIGHT", -3, -24)
    -- the scroll marks (PaintScroll), in the loot roll window's bronze
    win.thumb = win:CreateTexture(nil, "OVERLAY")
    win.thumb:SetWidth(2)
    win.thumb:SetColorTexture(0.61, 0.48, 0.29, 0.8)
    win.thumb:Hide()
    win.more = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    texts[win.more] = true
    StyleText(win.more, true)
    win.more:Hide()

    StyleTitle()
    Panel(win)
    return win
end

-- rows from LW.ReadSlots, in the order they dropped
function LW:Show(rows)
    LW:Build()
    current = rows or {}
    offset = 0
    Render()
    win:Show()
end

-- the mouse wheel: delta 1 is up, toward the first row
function LW:Scroll(delta)
    local total = current and #current or 0
    local new = math.max(0, math.min(offset - delta, total - ShownRows(total)))
    if new == offset then return end
    offset = new
    Render()
end

-- a looted slot: its row becomes an empty gap, so no row moves under a click
function LW:RemoveSlot(slot)
    if not (win and current) then return end
    for _, data in ipairs(current) do
        if data.slot == slot then
            data.looted = true
            Render()
            return
        end
    end
end

-- a slot whose contents changed: its row repainted where it is, not re-sorted
function LW:UpdateSlot(slot)
    if not (win and current) then return end
    for i, data in ipairs(current) do
        if data.slot == slot then
            if data.looted then return end
            local fresh
            for _, row in ipairs(LW.ReadSlots()) do
                if row.slot == slot then fresh = row break end
            end
            if fresh then current[i] = fresh else data.looted = true end
            Render()
            return
        end
    end
end

-- item data that came in after the window opened (item level, the marks): repainted in place, never
-- re-sorted, so no row moves under a click
function LW:RefreshItemData()
    if not (win and win:IsShown() and current) then return end
    local itemLevelOf = ns.Bags and ns.Bags.ItemLevelOf
    for _, data in ipairs(current) do
        if data.link and itemLevelOf then data.ilvl = itemLevelOf(data.link) end
    end
    Render()
end

-- the settings changed (Show Free Bag Slots, the Bags marks): the shown rows again
function LW:Refresh()
    if not win then return end
    StyleTitle()
    if current then Render() end
end

-- the window's font (the loot roll window's) and the item levels' (tweaks.bagItemLevelFont), live
function LW:ApplyFont()
    for fs, small in pairs(texts) do StyleText(fs, small) end
    StyleTitle()
    for _, row in ipairs(pool) do StyleItemLevel(row.ilvl) end
end

--------------------------------------------------
-- OPENING, CLOSING AND THE SPOT
-- Blizzard's LootFrame only loses its LOOT_OPENED and LOOT_CLOSED; it is never hidden (its OnHide
-- closes the loot) and none of its fields are written. The Gamepad UI gives it the two back, and so does
-- being the Master Looter: Blizzard's assign menu and window belong to its own loot window (11-24).
--------------------------------------------------
local LEM = LibStub("FlareEditMode")
local MOVER_KEY = "lootWindow"   -- tweaks.moverLayouts[layout].lootWindow
local DEFAULTS = { point = "LEFT", x = 20, y = 80 }
local HOLDER_H = TOP + ROW_H + PAD   -- the Edit Mode box: the window with one row
local holder, events

local function Scale()
    local db = GetDb()
    return math.max(0.5, math.min(2, db and tonumber(db.lootWindowScale) or 1))
end

-- (as LootRolls.lua GetLayoutStore: a layout with no spot of its own starts from the home layout's)
local function GetLayoutStore(layoutName)
    local db = GetDb()
    if not db then return nil end
    layoutName = layoutName or LEM:GetActiveLayoutName() or "Modern"
    db.moverLayouts = db.moverLayouts or {}
    local store = ns.LayoutHome(db.moverLayouts, layoutName)
    if rawget(store, MOVER_KEY) == nil then
        local home = store[MOVER_KEY]
        store[MOVER_KEY] = type(home) == "table" and CopyTable(home) or {}
    end
    return store[MOVER_KEY]
end

-- the window hangs from the holder's top left and grows down
local function ApplyPosition(layoutName)
    local store = GetLayoutStore(layoutName)
    local pos = (store and store.point) and store or DEFAULTS
    local scale = Scale()
    holder:SetSize(W * scale, HOLDER_H * scale)
    holder:ClearAllPoints()
    holder:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
end

local function ApplyScale()
    win:SetScale(Scale())
    ApplyPosition()
    -- (how many rows fit the screen depends on the scale)
    if win:IsShown() then Render() end
end

local function OnMoved(_, layoutName, point, x, y)
    local store = GetLayoutStore(layoutName)
    if not store then return end
    store.point, store.x, store.y = point, math.floor(x + 0.5), math.floor(y + 0.5)
end

local function ScaleSetting()
    return { name = L["Scale"], kind = LEM.SettingType.Slider, default = 100, minValue = 50, maxValue = 200, valueStep = 5,
        get = function() return math.floor(Scale() * 100 + 0.5) end,
        set = function(_, value)
            local db = GetDb()
            if not db then return end
            db.lootWindowScale = value ~= 100 and value / 100 or nil
            ApplyScale()
        end }
end

-- Loot Under Mouse opens it at the cursor, as Blizzard's (LootFrame.lua Open: the offsets in the
-- window's own scale); otherwise it hangs from the Edit Mode spot
local function Place()
    win:ClearAllPoints()
    if GetCVarBool("lootUnderMouse") then
        local scale = win:GetEffectiveScale()
        local x, y = GetCursorPosition()
        win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale - 30, math.max(y / scale + 50, 350))
    else
        win:SetPoint("TOPLEFT", holder, "TOPLEFT")
    end
end

-- The holder's anchor offsets (point to the same point of UIParent) that put the holder's top left at
-- left/top, all in UIParent units: the window is scaled, so the holder's box is w by h there.
local ANCHOR_H = { LEFT = 0, TOPLEFT = 0, BOTTOMLEFT = 0, CENTER = 0.5, TOP = 0.5, BOTTOM = 0.5, RIGHT = 1, TOPRIGHT = 1, BOTTOMRIGHT = 1 }
local ANCHOR_V = { TOP = 1, TOPLEFT = 1, TOPRIGHT = 1, CENTER = 0.5, LEFT = 0.5, RIGHT = 0.5, BOTTOM = 0, BOTTOMLEFT = 0, BOTTOMRIGHT = 0 }
function LW.HolderOffset(point, left, top, w, h, parentW, parentH)
    local fx, fy = ANCHOR_H[point] or 0.5, ANCHOR_V[point] or 0.5
    -- (the point's spot on the box is left + fx * w, top - (1 - fy) * h; on UIParent fx * parentW, fy * parentH)
    return left + fx * w - fx * parentW, top - (1 - fy) * h - fy * parentH
end

-- A drag of the header ends: the new spot is the saved one (what Edit Mode writes), unless Loot Under
-- Mouse puts the window at the cursor each time, when it only moves for this loot.
local function OnDragStop()
    win:StopMovingOrSizing()
    if GetCVarBool("lootUnderMouse") then return end
    local left, top = win:GetLeft(), win:GetTop()
    local store = GetLayoutStore()
    if not (left and top and store) then return Place() end
    local point = store.point or DEFAULTS.point
    local k = win:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local scale = Scale()
    local x, y = LW.HolderOffset(point, left * k, top * k, W * scale, HOLDER_H * scale, UIParent:GetWidth(), UIParent:GetHeight())
    OnMoved(nil, nil, point, x, y)
    ApplyPosition()
    Place()
end

-- A window that fails to show must not leave the loot open with nothing on screen: Blizzard's window
-- takes the loot again for the rest of the session, and this one closes.
local function ShowSlots(rows)
    local ok, err = pcall(function()
        Place()
        LW:Show(rows or LW.ReadSlots())
    end)
    if ok then return end
    ns.LogError("LootWindow", err)
    LW.blizzard = true
    LootFrame:RegisterEvent("LOOT_OPENED")
    LootFrame:RegisterEvent("LOOT_CLOSED")
    CloseLoot()
end

-- Blizzard's sounds for a loot that opens (LootFrame.lua OnEvent)
local function OpenSound(fromItem)
    local kit = SOUNDKIT
    if not kit then return end
    local sound
    if fromItem then
        sound = kit.UI_CONTAINER_ITEM_OPEN
    elseif IsFishingLoot and IsFishingLoot() then
        sound = kit.FISHING_REEL_IN
    elseif GetNumLootItems() == 0 then
        sound = kit.LOOT_WINDOW_OPEN_EMPTY
    end
    if sound then PlaySound(sound) end
end

-- into or out of the Gamepad UI or the Master Looter's place, where Blizzard's window takes the loot
-- (LW.gamepad: either). Never in the middle of a loot: the window that opened it also closes it.
local function ApplyInputStyle()
    if LW.looting then
        LW.styleDue = true
        return
    end
    LW.styleDue = nil
    if LW.blizzard then return end
    local gamepad = ns.IsGamepadUI() or ns.IsMasterLooter()
    if gamepad == LW.gamepad then return end
    LW.gamepad = gamepad
    if gamepad then
        LootFrame:RegisterEvent("LOOT_OPENED")
        LootFrame:RegisterEvent("LOOT_CLOSED")
    else
        LootFrame:UnregisterEvent("LOOT_OPENED")
        LootFrame:UnregisterEvent("LOOT_CLOSED")
    end
end

-- LW.looting: a loot is open (whichever window shows it). Cleared before the window hides on
-- LOOT_CLOSED, so that hide doesn't close the loot again.
local function OnEvent(_, event, a, b)
    if event == "LOOT_OPENED" then
        LW.looting = true
        LW.session = (LW.session or 0) + 1
        if LW.gamepad or LW.blizzard then return end
        OpenSound(b)
        -- a new loot while the window is still up: its rows, not the old ones
        if win:IsShown() then
            ShowSlots()
            return
        end
        -- auto loot too: Blizzard's window opens for every loot (LootFrame.lua OnEvent) and its rows
        -- go as the items are taken, until LOOT_CLOSED hides it (11-23, Kelvan)
        ShowSlots()
    elseif event == "BAG_UPDATE_DELAYED" then
        if win:IsShown() then
            -- the owned counts follow the bags: the rows repainted in place (Render repaints the footer too)
            Render()
        end
    elseif event == "LOOT_SLOT_CLEARED" then
        if win:IsShown() then LW:RemoveSlot(a) end
    elseif event == "LOOT_SLOT_CHANGED" then
        if win:IsShown() then LW:UpdateSlot(a) end
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        -- (one repaint for a burst)
        if not LW.itemDataDue then
            LW.itemDataDue = true
            C_Timer.After(0, function()
                LW.itemDataDue = nil
                LW:RefreshItemData()
            end)
        end
    elseif event == "LOOT_CLOSED" then
        LW.looting = nil
        win:Hide()
        -- the "will bind to you" question goes with the loot (as Blizzard's, LootFrame.lua OnHideAnimFinished)
        StaticPopup_Hide("LOOT_BIND")
        -- next frame: Blizzard's window gets this LOOT_CLOSED before it may lose the event
        if LW.styleDue then C_Timer.After(0, ApplyInputStyle) end
    elseif event == "PARTY_LOOT_METHOD_CHANGED" or event == "GROUP_ROSTER_UPDATE" then
        ApplyInputStyle()
    elseif event == "INPUT_DEVICE_INTERFACE_TRANSITION" then
        -- (once the style is set, as LootRolls.lua)
        C_Timer.After(0, ApplyInputStyle)
    end
end

function LW:Init()
    if holder then return end
    LW:Build()
    holder = CreateFrame("Frame", "FlareUI_LootWindowHolder", UIParent)
    holder:SetClampedToScreen(true)
    ApplyScale()   -- (and the spot: ApplyPosition)
    LEM:AddFrame(holder, OnMoved, DEFAULTS, L["FlareUI Loot Window"])
    LEM:AddFrameSettings(holder, ns.EditSection("Frame", { ScaleSetting() }))
    LEM:RegisterCallback("layout", function(layoutName) ApplyPosition(layoutName) end)
    -- Loot Under Mouse: nothing to place, so Edit Mode leaves the frame out (as LootFeed.lua's At the Cursor)
    LEM:RegisterCallback("enter", function() holder:SetShown(not GetCVarBool("lootUnderMouse")) end)
    LEM:RegisterCallback("exit", function() holder:Show(); ApplyPosition() end)

    win.grip:SetScript("OnDragStart", function() win:StartMoving() end)
    win.grip:SetScript("OnDragStop", OnDragStop)

    -- closed by ESC or its button: the loot closes too (as Blizzard's, LootFrame.lua OnHide)
    win:SetScript("OnHide", function()
        events:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
        events:UnregisterEvent("BAG_UPDATE_DELAYED")
        if LW.looting then CloseLoot() end
    end)
    -- uncached items' level and marks and the free bag slots, while there is a window to repaint
    win:SetScript("OnShow", function()
        events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        events:RegisterEvent("BAG_UPDATE_DELAYED")
    end)
    events = CreateFrame("Frame")
    for _, event in ipairs({ "LOOT_OPENED", "LOOT_SLOT_CLEARED", "LOOT_SLOT_CHANGED", "LOOT_CLOSED",
                             "PARTY_LOOT_METHOD_CHANGED", "GROUP_ROSTER_UPDATE" }) do
        events:RegisterEvent(event)
    end
    pcall(events.RegisterEvent, events, "INPUT_DEVICE_INTERFACE_TRANSITION")
    events:SetScript("OnEvent", OnEvent)

    -- last, once FlareUI's window is ready to take the loot
    LW.gamepad = false
    LootFrame:UnregisterEvent("LOOT_OPENED")
    LootFrame:UnregisterEvent("LOOT_CLOSED")
    ApplyInputStyle()   -- (a reload as the group's Master Looter)
end
