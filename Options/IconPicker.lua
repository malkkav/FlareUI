local _, ns = ...

--------------------------------------------------
-- ICON PICKER
-- A scrollable grid of every icon the client knows, with a search box. Blizzard's
-- IconSelectorPopupFrameTemplate exists but is wired to the macro frame's data provider and its own
-- okay/cancel plumbing; this is a smaller thing that takes a callback and gets out of the way.
-- The icon list comes from IconDataProviderMixin, the same source the macro UI uses.
--------------------------------------------------
local COLUMNS, ROWS = 10, 8
local CELL, PAD = 36, 4
local BORDER_COLOR = { 0.80, 0.60, 0.34 }   -- #CC9957

local picker, provider, icons, filtered, onPick

local function EnsureProvider()
    if provider then return true end
    local extra = IconDataProviderExtraType.Spellbook
    local ok, result = pcall(CreateAndInitFromMixin, IconDataProviderMixin, extra)
    if not ok or not result then return false end
    provider = result

    icons = {}
    local count = provider.GetNumIcons and provider:GetNumIcons() or 0
    for i = 1, count do
        icons[i] = provider:GetIconByIndex(i)
    end
    return #icons > 0
end

-- The provider hands back file IDs on this client and texture names on older ones, so the filter
-- matches against whichever it got. Typing a number narrows to matching IDs either way.
local function ApplyFilter(text)
    text = text and text:lower():match("^%s*(.-)%s*$") or ""
    if text == "" then
        filtered = icons
        return
    end
    filtered = {}
    for _, icon in ipairs(icons) do
        if tostring(icon):lower():find(text, 1, true) then
            filtered[#filtered + 1] = icon
        end
    end
end

local function UpdateGrid()
    local offset = picker.scroll:GetValue() or 0
    local row = math.floor(offset + 0.5)
    for index, cell in ipairs(picker.cells) do
        local i = row * COLUMNS + index
        local icon = filtered[i]
        if icon then
            cell.icon:SetTexture(icon)
            cell.value = icon
            cell:Show()
            cell.selected:SetShown(icon == picker.current)
        else
            cell:Hide()
        end
    end
    picker.count:SetText(("%d icons"):format(#filtered))
end

local function Rebuild(searchText)
    ApplyFilter(searchText)
    local rows = math.max(0, math.ceil(#filtered / COLUMNS) - ROWS)
    picker.scroll:SetMinMaxValues(0, rows)
    if (picker.scroll:GetValue() or 0) > rows then picker.scroll:SetValue(rows) end
    UpdateGrid()
end

local function CreatePicker()
    if picker then return end
    local width = COLUMNS * (CELL + PAD) + PAD + 20
    local height = ROWS * (CELL + PAD) + 84

    picker = CreateFrame("Frame", "FlareUI_IconPicker", UIParent, "BackdropTemplate")
    picker:SetSize(width, height)
    picker:SetPoint("CENTER")
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:SetToplevel(true)
    picker:EnableMouse(true)
    picker:SetMovable(true)
    picker:RegisterForDrag("LeftButton")
    picker:SetScript("OnDragStart", picker.StartMoving)
    picker:SetScript("OnDragStop", picker.StopMovingOrSizing)
    picker:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = LibStub("LibSharedMedia-3.0"):Fetch("border", "Blizzard Tooltip"),
        edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    picker:SetBackdropColor(0, 0, 0, 0.95)
    picker:SetBackdropBorderColor(BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3], 1)
    picker:Hide()
    tinsert(UISpecialFrames, "FlareUI_IconPicker")
    picker:SetScript("OnShow", ns.WindowOpenSound)
    picker:SetScript("OnHide", ns.WindowCloseSound)

    local title = picker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText("Choose an Icon")

    picker.count = picker:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    picker.count:SetPoint("TOPRIGHT", -14, -13)

    local search = CreateFrame("EditBox", nil, picker, "InputBoxTemplate")
    search:SetPoint("TOPLEFT", 18, -32)
    search:SetSize(width - 120, 20)
    search:SetAutoFocus(false)
    search:SetScript("OnTextChanged", function(self) Rebuild(self:GetText()) end)
    search:SetScript("OnEscapePressed", function() picker:Hide() end)
    picker.search = search

    local close = CreateFrame("Button", nil, picker, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() picker:Hide() end)

    -- grid
    picker.cells = {}
    for i = 1, COLUMNS * ROWS do
        local cell = CreateFrame("Button", nil, picker)
        cell:SetSize(CELL, CELL)
        local col, row = (i - 1) % COLUMNS, math.floor((i - 1) / COLUMNS)
        cell:SetPoint("TOPLEFT", PAD + 10 + col * (CELL + PAD), -(60 + row * (CELL + PAD)))

        cell.icon = cell:CreateTexture(nil, "ARTWORK")
        cell.icon:SetAllPoints()
        cell.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        cell.selected = cell:CreateTexture(nil, "OVERLAY")
        cell.selected:SetAllPoints()
        cell.selected:SetColorTexture(BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3], 0.35)
        cell.selected:Hide()

        cell:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        cell:SetScript("OnClick", function(self)
            if onPick and self.value then onPick(self.value) end
            picker:Hide()
        end)
        picker.cells[i] = cell
    end

    local scroll = CreateFrame("Slider", nil, picker, "UISliderTemplate")
    scroll:SetOrientation("VERTICAL")
    scroll:SetPoint("TOPRIGHT", -10, -60)
    scroll:SetSize(16, ROWS * (CELL + PAD) - PAD)
    scroll:SetValueStep(1)
    scroll:SetObeyStepOnDrag(true)
    scroll:SetScript("OnValueChanged", UpdateGrid)
    picker.scroll = scroll

    picker:EnableMouseWheel(true)
    picker:SetScript("OnMouseWheel", function(_, delta)
        scroll:SetValue((scroll:GetValue() or 0) - delta)
    end)
end

-- ns.ShowIconPicker(currentIcon, callback) - callback receives the chosen fileID
function ns.ShowIconPicker(current, callback)
    CreatePicker()
    if not EnsureProvider() then
        print("|cffff4040FlareUI:|r this client did not provide an icon list.")
        return
    end
    onPick = callback
    picker.current = current
    picker.search:SetText("")
    Rebuild("")
    picker:Show()
end
