local ADDON_NAME, ns = ...
local L = ns.L
local S = ns.Settings

--------------------------------------------------
-- SETTINGS PANEL
-- The window built from the registry (Settings/Registry.lua): modules down the left, the page's
-- rows in the middle, a picture and the hovered row's text on the right, the reload footer along
-- the bottom. Built on first open; Blizzard's own templates and textures, in FlareUI's bronze.
--------------------------------------------------
local WIDTH, HEIGHT = 960, 680   -- the reload bar hangs below the window when it shows
local HEADER_H, FOOTER_H = 34, 34
local LEFT_W, RIGHT_W = 190, 250
local PAD = 12
local ROW_H, SECTION_H = 26, 30
local INDENT = 18
-- the scrolling page: window minus borders, both side columns, their padding and the scroll bar
local CONTENT_W = WIDTH - 12 - LEFT_W - RIGHT_W - 2 * PAD - 14
local PICTURE_DIR = "Interface\\AddOns\\FlareUI\\Media\\Settings\\"
local FALLBACK_PICTURE = "Interface\\AddOns\\FlareUI\\Media\\Art\\Banner.png"

local BRONZE_MUTED = { 0.61, 0.48, 0.29 }

local Panel = {}
ns.SettingsPanel = Panel

local frame             -- the window
local current           -- module key on show
local searchText = ""
local navButtons = {}   -- module key -> left list button
local pools = {}        -- row kind -> list of row frames
local used = {}         -- row frames on the page now
local currentTab = {}   -- module key -> its tab on show
local customHosts = {}  -- "module.tab" -> the frame a custom tab drew into

--------------------------------------------------
-- 1. SMALL HELPERS
--------------------------------------------------
-- A thin scroll line, like the quest tracker's: a faint track and a bronze thumb, shown only when
-- there is something to scroll. Drag the thumb or click the track; the wheel scrolls the list.
-- line:SetValues(visible, position): the share in view and the scroll position, both 0..1.
-- line.onScroll(position) is called when the player drags it.
function Panel.ScrollLine(parent)
    local line = CreateFrame("Frame", nil, parent)
    line:SetWidth(10)
    line:EnableMouse(true)
    line.track = line:CreateTexture(nil, "ARTWORK")
    line.track:SetWidth(2)
    line.track:SetPoint("TOP")
    line.track:SetPoint("BOTTOM")
    line.track:SetColorTexture(0.61, 0.48, 0.29, 0.25)
    line.thumb = line:CreateTexture(nil, "OVERLAY")
    line.thumb:SetWidth(2)
    line.thumb:SetColorTexture(0.80, 0.60, 0.34, 1)
    line.visible, line.position = 1, 0
    function line:SetValues(visible, position)
        self.visible, self.position = visible or 1, math.max(0, math.min(1, position or 0))
        if self.visible >= 0.999 then self:Hide() return end
        self:Show()
        local h = self:GetHeight() or 0
        local th = math.max(16, h * self.visible)
        self.thumb:SetHeight(th)
        self.thumb:ClearAllPoints()
        self.thumb:SetPoint("TOP", self, "TOP", 0, -(h - th) * self.position)
    end
    -- the cursor's place on the track, as a scroll position
    local function CursorPosition(self)
        local _, y = GetCursorPosition()
        y = y / self:GetEffectiveScale()
        local top, h = self:GetTop(), self:GetHeight()
        local th = self.thumb:GetHeight()
        if not (top and h and h > th) then return 0 end
        return (top - y - th / 2) / (h - th)
    end
    line:SetScript("OnMouseDown", function(self)
        self.dragging = true
        self.thumb:SetWidth(4)
        if self.onScroll then self.onScroll(math.max(0, math.min(1, CursorPosition(self)))) end
    end)
    line:SetScript("OnMouseUp", function(self)
        self.dragging = nil
        self.thumb:SetWidth(self:IsMouseOver() and 4 or 2)
    end)
    line:SetScript("OnEnter", function(self) self.thumb:SetWidth(4) end)
    line:SetScript("OnLeave", function(self) if not self.dragging then self.thumb:SetWidth(2) end end)
    line:SetScript("OnUpdate", function(self)
        if self.dragging and self.onScroll then self.onScroll(math.max(0, math.min(1, CursorPosition(self)))) end
    end)
    line:SetScript("OnSizeChanged", function(self) self:SetValues(self.visible, self.position) end)
    return line
end

-- A scroll line beside a ScrollFrame, in the gutter on its right, with mouse wheel scrolling
function Panel.AttachScrollLine(scroll, parent, step)
    local line = Panel.ScrollLine(parent)
    line:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 2, 0)
    line:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 2, 0)
    local function Update()
        local range = scroll:GetVerticalScrollRange() or 0
        local h = scroll:GetHeight() or 0
        if not scroll:IsShown() or range <= 0.5 or h <= 0 then line:Hide() return end
        line:SetValues(h / (h + range), (scroll:GetVerticalScroll() or 0) / range)
    end
    line.onScroll = function(position)
        scroll:SetVerticalScroll(position * (scroll:GetVerticalScrollRange() or 0))
    end
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange() or 0
        self:SetVerticalScroll(math.max(0, math.min(range, (self:GetVerticalScroll() or 0) - delta * (step or 40))))
    end)
    scroll:HookScript("OnVerticalScroll", Update)
    scroll:HookScript("OnScrollRangeChanged", Update)
    scroll:HookScript("OnSizeChanged", Update)
    scroll:HookScript("OnShow", Update)
    scroll:HookScript("OnHide", Update)
    line.Update = Update
    Update()
    return line
end

-- Tooltips over the settings panel and over FlareUI's Edit Mode settings are opaque black, with
-- the Tooltips module on or off: whatever paints the background afterwards (Blizzard's layout, the
-- Tooltips module) is painted over again. Other tooltips get the game's colour back.
local function WantsDark(owner)
    local panel = _G.FlareUI_SettingsPanel
    while owner do
        if owner == panel or owner.FlareUI_DarkTooltips then return true end
        owner = owner.GetParent and owner:GetParent()
    end
    return false
end
local function DarkTooltips(tooltip)
    local nine = tooltip and tooltip.NineSlice
    if not nine then return end
    local painting = false
    local function Paint()
        if painting then return end
        painting = true
        if tooltip.FlareUI_Dark then
            pcall(nine.SetCenterColor, nine, 0, 0, 0, 1)
        end
        painting = false
    end
    if nine.SetCenterColor then hooksecurefunc(nine, "SetCenterColor", Paint) end
    if nine.Center and nine.Center.SetVertexColor then hooksecurefunc(nine.Center, "SetVertexColor", Paint) end
    tooltip:HookScript("OnShow", function(self)
        local ok, owner = pcall(self.GetOwner, self)
        local dark = ok and WantsDark(owner) or false
        if dark then
            self.FlareUI_Dark = true
            Paint()
        elseif self.FlareUI_Dark then
            self.FlareUI_Dark = nil
            local c = TOOLTIP_DEFAULT_BACKGROUND_COLOR
            if c then pcall(nine.SetCenterColor, nine, c.r, c.g, c.b, c.a or 1) end
        end
    end)
end
DarkTooltips(GameTooltip)
DarkTooltips(SettingsTooltip)

local function Line(parent, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetColorTexture(BRONZE_MUTED[1], BRONZE_MUTED[2], BRONZE_MUTED[3], 0.6)
    t:SetHeight(1)
    return t
end

local function Text(parent, font, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetJustifyH(justify or "LEFT")
    return fs
end

-- the picture for a row: Settings/Pictures.lua lists the files that exist; otherwise the module's,
-- otherwise FlareUI's banner
local function PictureFor(rowKey, moduleKey)
    local have = ns.SettingsPictures or {}
    if rowKey and have[rowKey] then return PICTURE_DIR .. rowKey .. ".png", have[rowKey] end
    if moduleKey and have[moduleKey] then return PICTURE_DIR .. moduleKey .. ".png", have[moduleKey] end
    return FALLBACK_PICTURE, 1
end

--------------------------------------------------
-- 2. RIGHT COLUMN: picture and text
--------------------------------------------------
local preview = {}

local function ShowPreview(title, desc, tip, rowKey, moduleKey)
    local file, ratio = PictureFor(rowKey, moduleKey)
    preview.picture:SetTexture(file)
    local w = RIGHT_W - 2 * PAD
    preview.picture:SetSize(w, ratio == 2 and w / 2 or w)
    preview.title:SetText(title or "")
    preview.desc:SetText(S:Format(desc) or "")
    preview.tip:SetText(tip and (L["Tip:"] .. " " .. S:Format(tip)) or "")
end

-- Nothing hovered: the dog and a hint (the module's own text is in its header already)
local function ShowModulePreview()
    ShowPreview(S:WindowText("infoPanelNothingHovered", L["Info Panel"]),
        S:WindowText("infoPanelNothingHovered2", L["Hover any option to see how it works!"]))
end

-- The title: the row's own info title, else its label; a text block or a chip set (no label of
-- its own) takes its section's title. A text block with no description shows its text.
local function ShowRowPreview(row)
    local title = S:Text(row.key, "info")
    local section = row.section and ns.Copy and ns.Copy.sections and ns.Copy.sections[row.section]
    if not title and (row.kind == "text" or row.kind == "chips") then title = section end
    if not title or title == "" then title = row:Label() end
    if (not title or title == "") and section then title = section end
    local desc = row:Description()
    if not desc and row.kind == "text" then desc = S:Text(row.key, "text") end
    ShowPreview(title, desc, row:Tip(), row.key, row.module)
end

-- for custom tabs: their own controls fill the right column on hover, and give it back after
function Panel:ShowPreview(title, desc, tip, rowKey, moduleKey)
    if preview.picture then ShowPreview(title, desc, tip, rowKey, moduleKey) end
end
function Panel:ShowModulePreview()
    if preview.picture then ShowModulePreview() end
end

--------------------------------------------------
-- 3. ROWS
-- One pool per kind. A row frame spans the page width: label on the left, its control on the
-- right. Hovering it fills the right column.
--------------------------------------------------
local Build = {}     -- kind -> function(row frame) adds the control once
local Fill = {}      -- kind -> function(row frame, row) shows the row's values

local function RowEnter(self)
    if self.row then ShowRowPreview(self.row) end
    self.hover:Show()
end

local function RowLeave(self)
    self.hover:Hide()
    ShowModulePreview()
end

local function NewRowFrame(parent, kind)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(ROW_H)
    f:EnableMouse(true)
    f:SetScript("OnEnter", RowEnter)
    f:SetScript("OnLeave", RowLeave)
    f.hover = f:CreateTexture(nil, "BACKGROUND")
    f.hover:SetAllPoints()
    f.hover:SetColorTexture(1, 0.82, 0, 0.06)
    f.hover:Hide()
    f.crumb = Text(f, "GameFontDisableSmall")
    f.label = Text(f, "GameFontHighlight")
    f.label:SetPoint("LEFT", 6, 0)
    f.crumb:SetPoint("BOTTOMLEFT", f.label, "TOPLEFT", 0, 1)
    f.kind = kind
    if Build[kind] then Build[kind](f) end
    return f
end

local function Acquire(parent, kind)
    pools[kind] = pools[kind] or {}
    local f = table.remove(pools[kind]) or NewRowFrame(parent, kind)
    f:SetParent(parent)
    f:Show()
    used[#used + 1] = f
    return f
end

local function ReleaseAll()
    for _, f in ipairs(used) do
        f:Hide()
        f:ClearAllPoints()
        f.row = nil
        table.insert(pools[f.kind], f)
    end
    wipe(used)
end

-- a control's mouse-over also fills the preview
local function ForwardHover(control, rowFrame)
    control:HookScript("OnEnter", function() RowEnter(rowFrame) end)
    control:HookScript("OnLeave", function() RowLeave(rowFrame) end)
end

-- toggle
Build.toggle = function(f)
    local check = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    check:SetSize(26, 26)
    check:SetPoint("RIGHT", -4, 0)
    check:SetScript("OnClick", function(self)
        local on = self:GetChecked() and true or false
        PlaySound(on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        f.row:Set(on)
    end)
    ForwardHover(check, f)
    f.control = check
end
Fill.toggle = function(f, row)
    f.control:SetChecked(row:Get() and true or false)
end

-- choice: Blizzard's stepper from its Settings (a dark box in the middle, arrows each side);
-- the box opens the list, the arrows step through it
Build.choice = function(f)
    local stepper = CreateFrame("Frame", nil, f, "SettingsDropdownWithButtonsTemplate")
    stepper:SetPoint("RIGHT", 4, 0)
    if stepper.Label then stepper.Label:Hide() end
    stepper.Dropdown:SetWidth(180)
    -- the template lays its arrows out past its own right edge: they are placed from the row's
    -- right edge instead, so the right arrow is never clipped
    stepper.IncrementButton:ClearAllPoints()
    stepper.IncrementButton:SetPoint("RIGHT", f, "RIGHT", -6, 0)
    stepper.Dropdown:ClearAllPoints()
    stepper.Dropdown:SetPoint("RIGHT", stepper.IncrementButton, "LEFT", -5, 0)
    stepper.DecrementButton:ClearAllPoints()
    stepper.DecrementButton:SetPoint("RIGHT", stepper.Dropdown, "LEFT", -5, 0)
    ForwardHover(stepper.Dropdown, f)
    ForwardHover(stepper.IncrementButton, f)
    ForwardHover(stepper.DecrementButton, f)
    f:SetHeight(ROW_H + 8)
    f.stepper = stepper
    f.control = stepper
end
Fill.choice = function(f, row)
    -- narrower two to a line
    f.stepper.Dropdown:SetWidth(row.half and 96 or 180)
    f.stepper.Dropdown:SetupMenu(function(_, root)
        for _, c in ipairs(row:Choices()) do
            root:CreateRadio(c.text, function() return row:Get() == c.value end, function() row:Set(c.value) end)
        end
    end)
    f:SetHeight(ROW_H + 8)
end

-- dropdown (long lists)
-- row.sideButtons = { left = def, right = def }, def = { text, width, onClick(button), disabled() }:
-- buttons on one line with the dropdown (Profiles: New | profiles | Delete; Create macro)
local function SideButton(f, side)
    local key = side .. "Button"
    if not f[key] then
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetHeight(22)
        b:SetScript("OnClick", function(self)
            ns.ButtonSound()
            local def = f.row and f.row.sideButtons and f.row.sideButtons[side]
            if def and def.onClick then def.onClick(self) end
        end)
        ForwardHover(b, f)
        f[key] = b
    end
    return f[key]
end
Build.dropdown = function(f)
    local dd = CreateFrame("DropdownButton", nil, f, "WowStyle1DropdownTemplate")
    dd:SetWidth(200)
    dd:SetPoint("RIGHT", -4, 0)
    ForwardHover(dd, f)
    f.control = dd
end
local function PlaceSideButtons(f, row)
    local sides = row.sideButtons or {}
    local dd = f.control
    dd:ClearAllPoints()
    dd:SetWidth(row.dropdownWidth or 200)
    for _, side in ipairs({ "right", "left" }) do
        local def = sides[side]
        local b = (def or f[side .. "Button"]) and SideButton(f, side)
        if def then
            b:SetText(def.text or "")
            b:SetWidth(def.width or 130)
            b:SetEnabled(not (def.disabled and def.disabled()))
            b:ClearAllPoints()
            b:Show()
        elseif b then
            b:Hide()
        end
    end
    if sides.right then
        f.rightButton:SetPoint("RIGHT", -4, 0)
        dd:SetPoint("RIGHT", f.rightButton, "LEFT", -8, 0)
    else
        dd:SetPoint("RIGHT", -4, 0)
    end
    if sides.left then f.leftButton:SetPoint("RIGHT", dd, "LEFT", -8, 0) end
end
Fill.dropdown = function(f, row)
    PlaceSideButtons(f, row)
    f.control:SetupMenu(function(_, root)
        for _, c in ipairs(row:Choices()) do
            root:CreateRadio(c.text, function() return row:Get() == c.value end, function() row:Set(c.value) end)
        end
    end)
end

-- button
Build.button = function(f)
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(200, 22)
    b:SetPoint("RIGHT", -4, 0)
    b:SetScript("OnClick", function()
        ns.ButtonSound()
        local row = f.row
        if row.apply then row.apply() end
    end)
    ForwardHover(b, f)
    f.control = b
end
-- the label is the button text, unless the row has its own (then the label stays on the left)
Fill.button = function(f, row)
    f.control:ClearAllPoints()
    if row.center then
        -- alone in the middle of the page (Reset FlareUI, FCM Setup Mode)
        f.control:SetPoint("CENTER")
        f.control:SetWidth(row.buttonWidth or 260)
        f.control:SetText(row.buttonText or row:Label())
        f.label:SetText("")
        f:SetHeight(ROW_H + 10)
        return
    end
    f.control:SetPoint("RIGHT", -4, 0)
    f.control:SetWidth(row.buttonWidth or 200)
    if row.buttonText then
        f.control:SetText(row.buttonText)
    else
        f.control:SetText(row:Label())
        f.label:SetText("")
    end
end

-- Click, then press a key (Alt, Ctrl and Shift combinations too). Escape cancels; right-click
-- clears. The button is Blizzard's Key Bindings one. onSet(key) gets "" for cleared.
local MOD_KEYS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, LMETA = true, RMETA = true }
local MOUSE_KEYS = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }

function Panel.KeyButton(parent, onSet)
    local b = CreateFrame("Button", nil, parent, "UIMenuButtonStretchTemplate")
    b:SetSize(170, 24)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local function Stop()
        b.waiting = nil
        b:EnableKeyboard(false)
        b:UnlockHighlight()
    end
    local function Finish(key)
        local mods = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "")
        Stop()
        onSet(mods .. key)
    end
    b:SetScript("OnClick", function(self, mouse)
        if mouse == "RightButton" then
            if not self.waiting then onSet("") end
            Stop()
            return
        end
        if self.waiting then Stop() Panel:Refresh() return end
        self.waiting = true
        self:SetText(L["Press a key"])
        self:LockHighlight()
        self:EnableKeyboard(true)
        if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
    end)
    b:SetScript("OnKeyDown", function(self, key)
        if not self.waiting or MOD_KEYS[key] then return end
        if key == "ESCAPE" then Stop() Panel:Refresh() return end
        Finish(key)
    end)
    b:SetScript("OnMouseDown", function(self, mouse)
        if self.waiting and MOUSE_KEYS[mouse] then Finish(MOUSE_KEYS[mouse]) end
    end)
    b:SetScript("OnHide", Stop)
    -- the key as the game names it ("Shift-V"), or Not Bound
    function b:ShowKey(key)
        if key and key ~= "" then
            self:SetText(GetBindingText and GetBindingText(key) or key)
        else
            self:SetText("|cff808080" .. (NOT_BOUND or L["Not bound"]) .. "|r")
        end
    end
    return b
end

-- keybind row: get() returns the key ("" for none), set(key)
Build.keybind = function(f)
    f.control = Panel.KeyButton(f, function(key) f.row:Set(key) end)
    f.control:SetPoint("RIGHT", -4, 0)
    ForwardHover(f.control, f)
end
Fill.keybind = function(f, row)
    if not f.control.waiting then f.control:ShowKey(row:Get()) end
end

-- buttons: several side by side on the right (row.buttons = { { text, onClick(button) } })
Build.buttons = function(f)
    f.buttons = {}
end
Fill.buttons = function(f, row)
    f.label:SetText(row:Label() or "")
    local previous
    local defs = row.buttons or {}
    for n = #defs, 1, -1 do
        local i, def = n, defs[n]
        local b = f.buttons[i]
        if not b then
            b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            b:SetHeight(22)
            b:SetScript("OnClick", function(self)
                ns.ButtonSound()
                local d = f.row and f.row.buttons[self.index]
                if d and d.onClick then d.onClick(self) end
            end)
            ForwardHover(b, f)
            f.buttons[i] = b
        end
        b.index = i
        b:SetText(def.text)
        b:SetWidth(def.width or 140)
        b:ClearAllPoints()
        b:SetPoint("RIGHT", previous or f, previous and "LEFT" or "RIGHT", previous and -(row.buttonGap or 6) or -4, 0)
        b:SetEnabled(not (def.disabled and def.disabled()))
        b:Show()
        previous = b
    end
    for i = #(row.buttons or {}) + 1, #f.buttons do f.buttons[i]:Hide() end
end

-- Edit: opens Edit Mode on the row's frame (greyed in combat)
local function EditButton(f, onClick)
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(80, 22)
    b:SetText(S:WindowText("editModeButtonOnAFrameRow", L["Edit"]))
    b:SetScript("OnClick", function()
        ns.ButtonSound()
        onClick(f.row)
    end)
    b:SetMotionScriptsWhileDisabled(true)
    b:HookScript("OnEnter", function(self)
        if not self:IsEnabled() then
            ns.OwnGameTooltip(self, "ANCHOR_TOP")
            GameTooltip:SetText(L["Edit Mode can't open in combat."], 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    b:HookScript("OnLeave", function() GameTooltip:Hide() end)
    ForwardHover(b, f)
    return b
end

-- frame: on/off switch and Edit (unit frames, resource bars)
Build.frame = function(f)
    f.edit = EditButton(f, function(row) S:EditFrame(row.frame and row.frame(), row.module) end)
    f.edit:SetPoint("RIGHT", -4, 0)
    Build.toggle(f)
    f.control:ClearAllPoints()
    f.control:SetPoint("RIGHT", f.edit, "LEFT", -8, 0)
end
Fill.frame = function(f, row)
    f.edit:SetWidth(row.half and 60 or 80)
    f.control:SetChecked(row:Get() and true or false)
    f.edit:SetEnabled(S:CanEditFrames() and row:Get() and row.frame and row.frame() ~= nil or false)
end

-- expander: a heading that opens and closes the rows under it (each font's controls)
Build.expander = function(f)
    local b = CreateFrame("Button", nil, f)
    b:SetAllPoints()
    b.sign = Text(b, "GameFontNormal")
    b.sign:SetPoint("RIGHT", -10, 0)
    b:SetScript("OnClick", function()
        ns.ButtonSound()
        local row = f.row
        if row and row.toggle then row.toggle() end
        Panel:Refresh()
    end)
    ForwardHover(b, f)
    f.control = b
end
Fill.expander = function(f, row)
    local open = row.isOpen and row.isOpen()
    f.control.sign:SetText(open and "-" or "+")
end

-- an Edit Mode setting found by search: Edit takes you to it
Build.editmode = function(f)
    f.edit = EditButton(f, function(row)
        if row.frame then S:EditFrame(row.frame, row.module) else S:OpenEditMode(row.module) end
    end)
    f.edit:SetPoint("RIGHT", -4, 0)
end
Fill.editmode = function(f, row)
    f.edit:SetEnabled(S:CanEditFrames() and true or false)
end

-- text block
Build.text = function(f)
    f.body = Text(f, "GameFontHighlight")
    f.body:SetPoint("TOPLEFT", 6, -4)
    f.body:SetSpacing(3)
end
Fill.text = function(f, row)
    f.label:SetText("")
    f.body:SetWidth(f.width - 12)
    f.body:SetText(S:Format(S:Text(row.key, "text") or S:Text(row.key, "intro") or ""))
    f:SetHeight(math.max(ROW_H, (f.body:GetStringHeight() or 0) + 10))
end

-- chips: a grid of check boxes, two per line
local CHIP_W, CHIP_H = 0.5, 24
Build.chips = function(f)
    f.chips = {}
end
Fill.chips = function(f, row)
    f.label:SetText("")
    local items = row:Items()
    local width = f.width
    for i, item in ipairs(items) do
        local chip = f.chips[i]
        if not chip then
            chip = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
            chip:SetSize(24, 24)
            chip.Text:SetFontObject("GameFontHighlight")
            chip:SetScript("OnClick", function(self)
                local on = self:GetChecked() and true or false
                PlaySound(on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
                f.row:SetItem(self.index, on)
            end)
            ForwardHover(chip, f)
            f.chips[i] = chip
        end
        chip.index = item.index
        chip.Text:SetText(item.text)
        chip:SetChecked(row:GetItem(item.index))
        chip:Show()
    end
    for i = #items + 1, #f.chips do f.chips[i]:Hide() end
    -- two columns, each centred in its half of the row
    local colWidth = { 0, 0 }
    for i = 1, #items do
        local col = (i - 1) % 2 + 1
        local w = 28 + (f.chips[i].Text:GetStringWidth() or 100)
        if w > colWidth[col] then colWidth[col] = w end
    end
    local half = width * CHIP_W
    for i = 1, #items do
        local col, line = (i - 1) % 2, math.floor((i - 1) / 2)
        local x = col * half + math.max(0, (half - colWidth[col + 1]) / 2)
        f.chips[i]:ClearAllPoints()
        f.chips[i]:SetPoint("TOPLEFT", x, -2 - line * CHIP_H)
    end
    f:SetHeight(math.ceil(#items / 2) * CHIP_H + 6)
end

-- enable / disable the control with the row
local function SetRowEnabled(f, enabled)
    -- a heading that opens rows (each font) is gold, like the section titles
    local color = enabled and (f.kind == "expander" and NORMAL_FONT_COLOR or HIGHLIGHT_FONT_COLOR) or GRAY_FONT_COLOR
    f.label:SetTextColor(color:GetRGB())
    local controls = { f.control, f.prev, f.next }
    -- the Edit button follows combat and the frame, not the row (Fill set it)
    for _, chip in ipairs(f.chips or {}) do controls[#controls + 1] = chip end
    for _, c in ipairs(controls) do
        if c and c.SetEnabled then c:SetEnabled(enabled) end
    end
end

local function FillRow(f, row, crumb)
    f.row = row
    f.label:SetText(row:Label() or "")
    f.crumb:SetText(crumb or "")
    f:SetHeight(crumb and ROW_H + 12 or ROW_H)
    if Fill[row.kind] then Fill[row.kind](f, row) end
    SetRowEnabled(f, not row:IsDisabled())
end

--------------------------------------------------
-- 4. MIDDLE COLUMN: the page
--------------------------------------------------
local page = {}

-- A section's heading closes and opens it (a click); every section starts open, and what is
-- closed is kept for the session
local closedSections = {}   -- section key -> closed

local function SectionClick(h)
    if not h.sectionKey then return end
    ns.ButtonSound()
    closedSections[h.sectionKey] = not closedSections[h.sectionKey] or nil
    Panel:Refresh()
end

local function SectionHeader(parent, text, y, sectionKey)
    local key = "section"
    pools[key] = pools[key] or {}
    local h = table.remove(pools[key])
    if not h then
        h = CreateFrame("Frame", nil, parent)
        h:SetHeight(SECTION_H)
        h.kind = key
        h.text = Text(h, "GameFontNormal")
        h.text:SetPoint("BOTTOMLEFT", 6, 6)
        h.sign = Text(h, "GameFontNormal")
        h.sign:SetPoint("BOTTOMRIGHT", -10, 6)
        h.line = Line(h)
        h.line:SetPoint("BOTTOMLEFT", 0, 2)
        h.line:SetPoint("BOTTOMRIGHT", 0, 2)
        h.hover = h:CreateTexture(nil, "BACKGROUND")
        h.hover:SetAllPoints()
        h.hover:SetColorTexture(1, 0.82, 0, 0.06)
        h.hover:Hide()
        h:EnableMouse(true)
        h:SetScript("OnEnter", function(self) self.hover:Show() end)
        h:SetScript("OnLeave", function(self) self.hover:Hide() end)
        h:SetScript("OnMouseUp", SectionClick)
    end
    h:SetParent(parent)
    h.sectionKey = sectionKey
    h.sign:SetText(sectionKey and (closedSections[sectionKey] and "+" or "-") or "")
    h.text:SetText(text)
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", 0, y)
    h:SetWidth(CONTENT_W)
    h:Show()
    used[#used + 1] = h
    return SECTION_H
end

-- lays rows out from y downwards; returns the new y. Rows marked half go two to a line (not in
-- search results, which show each row's place above it)
local function PlaceRows(parent, rows, y, crumbOf)
    local col, lineH = 0, 0
    for _, row in ipairs(rows) do
        local f = Acquire(parent, row.kind)
        f:ClearAllPoints()
        if row.half and not crumbOf then
            local indent = row.parent and INDENT or 0
            local w = math.floor((CONTENT_W - indent) / 2)
            f:SetPoint("TOPLEFT", indent + col * w, y)
            f.width = w - (col == 0 and 8 or 0)
            f:SetWidth(f.width)
            FillRow(f, row)
            lineH = math.max(lineH, f:GetHeight())
            if col == 1 then y, col, lineH = y - lineH, 0, 0 else col = 1 end
        else
            if col == 1 then y, col, lineH = y - lineH, 0, 0 end
            local indent = row.parent and INDENT or 0
            f:SetPoint("TOPLEFT", indent, y)
            f.width = CONTENT_W - indent
            f:SetWidth(f.width)
            FillRow(f, row, crumbOf and crumbOf(row))
            y = y - f:GetHeight()
        end
    end
    if col == 1 then y = y - lineH end
    return y
end

local function UpdateHeader(module)
    page.title:SetText(module:Title())
    page.desc:SetText(module:Description() or "")
    page.switch:SetShown(module.enabled ~= nil)
    page.switch:SetChecked(module:IsOn())
    page.title:ClearAllPoints()
    if module.enabled then
        page.title:SetPoint("LEFT", page.switch, "RIGHT", 4, 0)
    else
        page.title:SetPoint("TOPLEFT", 4, -4)
    end
    -- a header button: Edit Mode, or the module's own
    local editText = (module.editMode or module.headerButton) and module:IsOn() and S:ModuleText(module.key, "editButton")
    page.editMode:SetShown(editText and true or false)
    if editText then
        page.editMode:SetText(editText)
        page.editMode:SetWidth((page.editMode:GetTextWidth() or 120) + 30)
        page.editMode:SetEnabled(module.headerButton ~= nil or S:CanEditFrames() and true or false)
    end
    page.banner:Hide()
    local height = 64
    if module.banner and module:IsOn() then
        local text, button, onClick = module.banner()
        if text then
            page.banner.text:SetText(text)
            page.banner.button:SetText(button or "")
            page.banner.button:SetShown(button ~= nil)
            page.banner.onClick = onClick
            page.banner:Show()
            height = height + 36
        end
    end
    -- the module's tabs, along the bottom of the header
    local names = module.tabs and S:ModuleText(module.key, "tabs") or {}
    local active = Panel:ActiveTab(module)
    for i, b in ipairs(page.tabButtons) do
        local tab = module.tabs and module:IsOn() and module.tabs[i]
        b:SetShown(tab and true or false)
        if tab then
            b.tabKey = tab.key
            b.Text:SetText(names[i] or tab.key)
            b:SetWidth((b.Text:GetStringWidth() or 60) + 40)
            if b.SetSelected then b:SetSelected(tab == active) end
        end
    end
    local tabbed = module.tabs and module:IsOn()
    page.tabLine:SetShown(tabbed and true or false)
    if tabbed then height = height + 40 end
    page.header:SetHeight(height)
end

-- The tab a module shows: the last one picked, or its first
function Panel:ActiveTab(module)
    if not module.tabs then return nil end
    local key = currentTab[module.key]
    for _, tab in ipairs(module.tabs) do
        if tab.key == key then return tab end
    end
    return module.tabs[1]
end

local function HideCustom()
    for _, host in pairs(customHosts) do host:Hide() end
    if preview.host then preview.host:Hide() end
    for _, region in ipairs({ preview.picture, preview.title, preview.desc, preview.tip }) do region:Show() end
end

-- A custom tab draws into its own frame, made once, below the header; with tab.preview it also
-- takes the right column
local function ShowCustom(module, tab)
    local id = module.key .. "." .. tab.key
    local host = customHosts[id]
    if not host then
        host = CreateFrame("Frame", nil, page.root)
        host:SetPoint("TOPLEFT", page.header, "BOTTOMLEFT", 0, -4)
        host:SetPoint("BOTTOMRIGHT", page.root, "BOTTOMRIGHT", 0, 0)
        customHosts[id] = host
        tab.custom(host, preview.host)
    end
    host:Show()
    if tab.preview then
        for _, region in ipairs({ preview.picture, preview.title, preview.desc, preview.tip }) do region:Hide() end
        preview.host:Show()
    end
    if tab.refresh then tab.refresh(host, preview.host) end
end

function Panel:Refresh()
    if not frame or not frame:IsShown() then return end
    ReleaseAll()
    HideCustom()
    page.scroll:Show()
    local content = page.content
    content:SetWidth(CONTENT_W)
    local y = 0
    if searchText ~= "" then
        page.header:Hide()
        page.scroll:SetPoint("TOPLEFT", page.root, "TOPLEFT", 0, 0)
        local results = S:Search(searchText)
        page.searchTitle:SetText(L["Results for \"%s\""]:format(searchText))
        page.searchTitle:Show()
        y = -24
        if #results == 0 then
            page.empty:SetText(S:WindowText("noResults", L["No settings match."]))
            page.empty:Show()
        else
            page.empty:Hide()
            y = PlaceRows(content, results, y, function(row)
                local module = S.modules[row.module]
                if row.kind == "editmode" then
                    return module:Title() .. "  ›  " .. row.frameName .. "  ·  " .. L["Edit Mode"]
                end
                local section = row.section and ns.Copy.sections[row.section]
                return module:Title() .. (section and ("  ›  " .. section) or "")
            end)
        end
    else
        page.searchTitle:Hide()
        page.empty:Hide()
        page.header:Show()
        page.scroll:SetPoint("TOPLEFT", page.header, "BOTTOMLEFT", 0, -4)
        local module = S.modules[current]
        if not module then return end
        UpdateHeader(module)
        if module.enabled and not module:IsOn() then
            page.offCard.text:SetText((S:WindowText("moduleOffCard", L["{Module} is off. Its settings appear here once it's on."])):gsub("{Module}", module:Title()))
            page.offCard:Show()
        else
            page.offCard:Hide()
            local tab = self:ActiveTab(module) or module.custom
            for _, section in ipairs(module:Sections(tab and tab.key)) do
                if section.title then y = y - SectionHeader(content, section.title, y, section.key) end
                if not (section.title and closedSections[section.key]) then
                    y = PlaceRows(content, section.rows, y)
                end
                y = y - 6
            end
            ShowModulePreview()
            if tab and tab.custom then
                page.scroll:Hide()
                ShowCustom(module, tab)
            end
            content:SetHeight(math.max(1, -y + 8))
            return
        end
        ShowModulePreview()
    end
    content:SetHeight(math.max(1, -y + 8))
end

--------------------------------------------------
-- 5. LEFT COLUMN: search and modules
--------------------------------------------------
local function UpdateNav()
    for key, b in pairs(navButtons) do
        local module = S.modules[key]
        local on = module:IsOn()
        b.selected:SetShown(key == current and searchText == "")
        if module.navIcon then
            b.dot:SetTexture(module.navIcon)
            -- a game icon: cropped to a circle, its own border gone
            if module.navIconRound and not b.dotMask then
                b.dotMask = b:CreateMaskTexture()
                b.dotMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                b.dotMask:SetAllPoints(b.dot)
                b.dot:AddMaskTexture(b.dotMask)
                b.dot:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end
            b.dot:SetDesaturated(false)
            b.dot:SetVertexColor(1, 1, 1)
            b.dot:Show()
        else
            b.dot:SetShown(module.enabled ~= nil)
            b.dot:SetVertexColor(on and 0.35 or 0.4, on and 0.85 or 0.4, on and 0.35 or 0.4)
        end
        b.text:SetTextColor((on and HIGHLIGHT_FONT_COLOR or GRAY_FONT_COLOR):GetRGB())
    end
end

function Panel:Select(key)
    if not S.modules[key] then return end
    current = key
    -- the module of the page shown can preview itself (chat, damage meter, quest tracker)
    S:Fire("PageShown", key)
    if ns.db and ns.db.global then ns.db.global.settingsPage = key end
    if searchText ~= "" then
        searchText = ""
        frame.search:SetText("")
    end
    page.scroll:SetVerticalScroll(0)
    UpdateNav()
    self:Refresh()
end

local function BuildNav(left)
    local y = -PAD + 4
    local GROUP_LABEL = { HUD = L["HUD"], Info = L["Info"], Tools = L["Tools"] }
    for _, group in ipairs(S:Groups()) do
        local label = GROUP_LABEL[group.group]
        if label then
            local g = Text(left, "GameFontDisableSmall")
            g:SetPoint("TOPLEFT", PAD + 4, y - 8)
            g:SetText(label)
            y = y - 24
        elseif group.group == "bottom" then
            y = y - 10
        end
        for _, module in ipairs(group.modules) do
            local b = CreateFrame("Button", nil, left)
            b:SetSize(LEFT_W - 2 * PAD, 24)
            b:SetPoint("TOPLEFT", PAD, y)
            b.selected = b:CreateTexture(nil, "BACKGROUND")
            b.selected:SetAllPoints()
            b.selected:SetColorTexture(1, 0.82, 0, 0.12)
            b:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
            b:GetHighlightTexture():SetAlpha(0.25)
            b.dot = b:CreateTexture(nil, "ARTWORK")
            b.dot:SetTexture("Interface\\COMMON\\Indicator-Green")
            b.dot:SetDesaturated(true)
            b.dot:SetSize(14, 14)
            b.dot:SetPoint("LEFT", 2, 0)
            b.text = Text(b, "GameFontHighlight")
            b.text:SetPoint("LEFT", 20, 0)
            b.text:SetText(module:Title())
            b:SetScript("OnClick", function()
                PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
                Panel:Select(module.key)
            end)
            navButtons[module.key] = b
            y = y - 24
        end
    end
end

--------------------------------------------------
-- 6. FOOTER: reload
--------------------------------------------------
-- "Reload now" reloads at once. ReloadUI is protected on Forever, so the click lands on a secure
-- /reload button laid over it: parented to UIParent (the window stays unprotected) and placed by
-- screen position, out of combat only. In combat the plain button asks, as the dialog shows /reload.
local secureReload
local function PlaceSecureReload()
    if not frame or InCombatLockdown() then return end
    if not secureReload then
        secureReload = CreateFrame("Button", "FlareUI_SettingsReload", UIParent, "SecureActionButtonTemplate, UIPanelButtonTemplate")
        secureReload:SetFrameStrata("FULLSCREEN_DIALOG")
        secureReload:RegisterForClicks("AnyUp", "AnyDown")
        secureReload:SetAttribute("type", "macro")
        secureReload:SetAttribute("macrotext", "/reload")
        secureReload:SetScript("PreClick", function()
            ns.reloading = true
            ns.ButtonSound()
        end)
        local waiter = CreateFrame("Frame")
        waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
        waiter:SetScript("OnEvent", PlaceSecureReload)
    end
    local button = frame.reload
    local x, y = button:GetCenter()
    if frame:IsShown() and button:IsVisible() and x then
        local scale = button:GetEffectiveScale() / UIParent:GetEffectiveScale()
        secureReload:SetSize(button:GetWidth() * scale, button:GetHeight() * scale)
        secureReload:ClearAllPoints()
        secureReload:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x * scale, y * scale)
        secureReload:SetText(button:GetText())
        secureReload:Show()
    else
        secureReload:Hide()
    end
end

-- The red bar under the window: changes that need a reload (with the button), or else a page's
-- notice (Panel:SetNotice), which stays until another page shows or the window closes
local notice, noticePage
local function UpdateFooter()
    if not frame then return end
    local n = S:PendingCount()
    if n > 0 then
        local text = S:WindowText("reloadFooter", L["{n} change(s) need a reload"])
        frame.footerText:SetText(text:gsub("{n}", n))
        frame.reload:Show()
        frame.footer:Show()
    elseif notice then
        frame.footerText:SetText(notice)
        frame.reload:Hide()
        frame.footer:Show()
    else
        frame.footerText:SetText("")
        frame.footer:Hide()
    end
    PlaceSecureReload()
end

function Panel:SetNotice(text)
    notice, noticePage = text, current
    UpdateFooter()
end

S:On("PageShown", function(key)
    if notice and key ~= noticePage then
        notice, noticePage = nil, nil
        UpdateFooter()
    end
end)

--------------------------------------------------
-- 7. THE WINDOW
--------------------------------------------------
local function BuildWindow()
    local style = ns.WINDOW_STYLE
    frame = CreateFrame("Frame", "FlareUI_SettingsPanel", UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
        if secureReload and not InCombatLockdown() then secureReload:Hide() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        PlaceSecureReload()
    end)
    frame:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16 })
    frame:SetBackdropBorderColor(style.border[1], style.border[2], style.border[3], 1)
    -- Blizzard's Collections tile under a black wash (picked in game)
    local art = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    art:SetPoint("TOPLEFT", 5, -5)
    art:SetPoint("BOTTOMRIGHT", -5, 5)
    art:SetTexture("Interface\\Collections\\CollectionsBackgroundTile", "REPEAT", "REPEAT")
    art:SetHorizTile(true)
    art:SetVertTile(true)
    local wash = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    wash:SetAllPoints(art)
    wash:SetColorTexture(0, 0, 0, 0.5)
    frame:Hide()
    tinsert(UISpecialFrames, "FlareUI_SettingsPanel")
    frame:SetScript("OnShow", function()
        ns.WindowOpenSound()
        UpdateNav()
        UpdateFooter()
        Panel:Refresh()
    end)
    frame:SetScript("OnHide", function()
        S:Fire("PageShown", nil)
        ns.WindowCloseSound()
        PlaceSecureReload()
        if S:PendingCount() > 0 and not Panel.quietHide then ns.ShowDialog("FLAREUI_RELOAD") end
    end)

    -- header
    local title = Text(frame, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", PAD + 4, -12)
    title:SetText(L["FlareUI"])
    local version = Text(frame, "GameFontDisableSmall")
    version:SetPoint("LEFT", title, "RIGHT", 8, -1)
    version:SetText(C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "")
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    local headerLine = Line(frame)
    headerLine:SetPoint("TOPLEFT", 6, -HEADER_H)
    headerLine:SetPoint("TOPRIGHT", -6, -HEADER_H)

    -- columns
    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", 6, -HEADER_H - 1)
    body:SetPoint("BOTTOMRIGHT", -6, 6)
    frame.body = body

    -- Settings | What's new, along the top
    frame.topTabs = {}
    for i, mode in ipairs({ "settings", "whatsnew" }) do
        local b = CreateFrame("Button", nil, frame, "MinimalTabTemplate")
        b:SetHeight(30)
        b.Text:SetText(S:WindowText(i == 1 and "tabs" or "tabs2", i == 1 and L["Settings"] or L["What's new"]))
        b:SetWidth((b.Text:GetStringWidth() or 80) + 40)
        b.mode = mode
        b:SetScript("OnClick", function(self)
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            Panel:SetMode(self.mode)
        end)
        frame.topTabs[i] = b
    end
    frame.topTabs[2]:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -40, -HEADER_H)
    frame.topTabs[1]:SetPoint("BOTTOMRIGHT", frame.topTabs[2], "BOTTOMLEFT", -5, 0)

    -- What's new: every kept version's notes, newest first, in one scrolling column
    local news = CreateFrame("Frame", nil, frame)
    news:SetAllPoints(body)
    news:Hide()
    local newsScroll = CreateFrame("ScrollFrame", nil, news)
    newsScroll:SetPoint("TOPLEFT", PAD + 6, -PAD)
    newsScroll:SetPoint("BOTTOMRIGHT", -PAD - 16, PAD)
    local newsContent = CreateFrame("Frame", nil, newsScroll)
    newsContent:SetSize(WIDTH - 2 * PAD - 40, 1)
    newsScroll:SetScrollChild(newsContent)
    Panel.AttachScrollLine(newsScroll, news)
    local y = 0
    for _, entry in ipairs(ns.WhatsNew or {}) do
        local title = Text(newsContent, "GameFontNormalHuge")
        title:SetPoint("TOPLEFT", 0, y)
        title:SetText(L["FlareUI"] .. " " .. entry.version)
        y = y - 34
        local body = Text(newsContent, "GameFontHighlight")
        body:SetPoint("TOPLEFT", 0, y)
        body:SetWidth(WIDTH - 2 * PAD - 40)
        body:SetSpacing(4)
        body:SetText(entry.text)
        y = y - (body:GetStringHeight() or 0) - 30
    end
    newsContent:SetHeight(math.max(1, -y))
    frame.news = news

    local left = CreateFrame("Frame", nil, body)
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(LEFT_W)
    local leftLine = Line(body)
    leftLine:SetSize(1, 1)
    leftLine:SetPoint("TOPLEFT", left, "TOPRIGHT")
    leftLine:SetPoint("BOTTOMLEFT", left, "BOTTOMRIGHT")

    local right = CreateFrame("Frame", nil, body)
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(RIGHT_W)
    local rightBg = right:CreateTexture(nil, "BACKGROUND")
    rightBg:SetAllPoints()
    rightBg:SetColorTexture(0, 0, 0, 0.25)
    local rightLine = Line(body)
    rightLine:SetSize(1, 1)
    rightLine:SetPoint("TOPRIGHT", right, "TOPLEFT")
    rightLine:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")

    local middle = CreateFrame("Frame", nil, body)
    middle:SetPoint("TOPLEFT", left, "TOPRIGHT", PAD, -PAD)
    middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", -PAD, PAD)
    page.root = middle

    -- search
    local search = CreateFrame("EditBox", nil, left, "SearchBoxTemplate")
    search:SetSize(LEFT_W - 2 * PAD - 4, 22)
    search:SetPoint("BOTTOMLEFT", PAD + 4, PAD - 2)
    search.Instructions:SetText(S:WindowText("searchPlaceholder", L["Search settings"]))
    search:HookScript("OnTextChanged", function(self)
        searchText = strtrim(self:GetText() or "")
        page.scroll:SetVerticalScroll(0)
        UpdateNav()
        Panel:Refresh()
    end)
    frame.search = search
    BuildNav(left)

    -- page header: title, switch, description, banner
    local header = CreateFrame("Frame", nil, middle)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(64)
    page.header = header
    page.switch = CreateFrame("CheckButton", nil, header, "UICheckButtonTemplate")
    page.switch:SetSize(30, 30)
    page.switch:SetPoint("TOPLEFT", -2, 2)
    page.title = Text(header, "GameFontNormalHuge")
    page.title:SetPoint("LEFT", page.switch, "RIGHT", 4, 0)
    page.switch:SetScript("OnClick", function(self)
        local on = self:GetChecked() and true or false
        PlaySound(on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        S.modules[current]:SetOn(on)
        UpdateNav()
        Panel:Refresh()
    end)
    -- "Edit in Edit Mode": the module's main frame, or Edit Mode itself for Blizzard's bars
    page.editMode = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    page.editMode:SetHeight(22)
    page.editMode:SetPoint("TOPRIGHT", 0, -2)
    page.editMode:SetScript("OnClick", function()
        ns.ButtonSound()
        local module = S.modules[current]
        if module.headerButton then module.headerButton() return end
        local target = module.editMode and module.editMode()
        if target then
            S:EditFrame(target, module.key)
        else
            S:OpenEditMode(module.key)
        end
    end)
    page.editMode:Hide()
    page.desc = Text(header, "GameFontHighlightSmall")
    page.desc:SetPoint("TOPLEFT", 4, -36)
    page.desc:SetPoint("RIGHT", -4, 0)
    page.desc:SetTextColor(0.62, 0.62, 0.62)

    local banner = CreateFrame("Frame", nil, header, "BackdropTemplate")
    banner:SetHeight(30)
    banner:SetPoint("TOPLEFT", page.desc, "BOTTOMLEFT", -4, -6)
    banner:SetPoint("RIGHT")
    banner:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    banner:SetBackdropColor(0.5, 0.35, 0, 0.35)
    banner.text = Text(banner, "GameFontNormal")
    banner.text:SetPoint("LEFT", 8, 0)
    banner.button = CreateFrame("Button", nil, banner, "UIPanelButtonTemplate")
    banner.button:SetSize(110, 22)
    banner.button:SetPoint("RIGHT", -4, 0)
    banner.button:SetScript("OnClick", function()
        ns.ButtonSound()
        if banner.onClick then banner.onClick() end
        Panel:Refresh()
    end)
    banner:Hide()
    page.banner = banner

    -- module tabs (Radial Menu: Buttons, Keybinds, Options)
    page.tabButtons = {}
    for i = 1, 4 do
        local b = CreateFrame("Button", nil, header, "MinimalTabTemplate")
        b:SetHeight(37)
        if i == 1 then b:SetPoint("BOTTOMLEFT", 8, 0) else b:SetPoint("BOTTOMLEFT", page.tabButtons[i - 1], "BOTTOMRIGHT", 5, 0) end
        b:SetScript("OnClick", function(self)
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            currentTab[current] = self.tabKey
            page.scroll:SetVerticalScroll(0)
            Panel:Refresh()
        end)
        b:Hide()
        page.tabButtons[i] = b
    end
    page.tabLine = Line(header)
    page.tabLine:SetPoint("BOTTOMLEFT", 0, 0)
    page.tabLine:SetPoint("BOTTOMRIGHT", 0, 0)
    page.tabLine:Hide()

    -- scrolling rows
    local scroll = CreateFrame("ScrollFrame", nil, middle)
    scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    scroll:SetPoint("BOTTOMRIGHT", -14, 0)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    page.scrollLine = Panel.AttachScrollLine(scroll, middle)
    page.scroll, page.content = scroll, content

    page.searchTitle = Text(middle, "GameFontNormal")
    page.searchTitle:SetPoint("TOPLEFT", 4, -2)
    page.empty = Text(middle, "GameFontDisable")
    page.empty:SetPoint("TOPLEFT", 4, -30)

    -- module-off card
    local off = CreateFrame("Frame", nil, middle)
    off:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -20)
    off:SetPoint("RIGHT")
    off:SetHeight(120)
    off.text = Text(off, "GameFontHighlight", "CENTER")
    off.text:SetPoint("TOP", 0, -10)
    off.text:SetWidth(380)
    local turnOn = CreateFrame("Button", nil, off, "UIPanelButtonTemplate")
    turnOn:SetSize(160, 26)
    turnOn:SetPoint("TOP", off.text, "BOTTOM", 0, -16)
    turnOn:SetText(S:WindowText("moduleOffCard2", L["Turn on"]))
    turnOn:SetScript("OnClick", function()
        ns.ButtonSound()
        S.modules[current]:SetOn(true)
        UpdateNav()
        Panel:Refresh()
    end)
    off:Hide()
    page.offCard = off

    -- right column: a custom tab (the radial's live preview) can take it over
    preview.host = CreateFrame("Frame", nil, right)
    preview.host:SetAllPoints()
    preview.host:Hide()
    preview.picture = right:CreateTexture(nil, "ARTWORK")
    preview.picture:SetPoint("TOP", 0, -PAD)
    preview.title = Text(right, "GameFontNormalLarge")
    preview.title:SetPoint("TOPLEFT", preview.picture, "BOTTOMLEFT", 0, -12)
    preview.title:SetPoint("RIGHT", -PAD, 0)
    preview.desc = Text(right, "GameFontHighlight")
    preview.desc:SetPoint("TOPLEFT", preview.title, "BOTTOMLEFT", 0, -8)
    preview.desc:SetPoint("RIGHT", -PAD, 0)
    preview.desc:SetSpacing(3)
    preview.desc:SetTextColor(0.85, 0.85, 0.85)
    preview.tip = Text(right, "GameFontNormalSmall")
    preview.tip:SetPoint("TOPLEFT", preview.desc, "BOTTOMLEFT", 0, -10)
    preview.tip:SetPoint("RIGHT", -PAD, 0)
    preview.tip:SetSpacing(2)

    -- the reload bar: hangs below the window, in a red wash, only while a change waits for a reload
    local footer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    footer:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 4)
    footer:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, 4)
    footer:SetHeight(FOOTER_H + 8)
    footer:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16 })
    footer:SetBackdropBorderColor(style.border[1], style.border[2], style.border[3], 1)
    ns.Fade(footer, 4, { 0.42, 0.09, 0.06, 0.97 }, { 0.24, 0.04, 0.03, 0.97 })
    footer:Hide()
    frame.footer = footer
    -- the window stays on screen with its bar
    frame:SetClampRectInsets(0, 0, 0, -(FOOTER_H + 4))
    frame.footerText = Text(footer, "GameFontHighlight")
    frame.footerText:SetPoint("LEFT", PAD + 4, -1)
    frame.reload = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    frame.reload:SetSize(130, 22)
    frame.reload:SetPoint("RIGHT", -PAD, -1)
    frame.reload:SetText(S:WindowText("reloadFooter2", L["Reload now"]))
    frame.reload:SetScript("OnClick", function()
        ns.ButtonSound()
        ns.ShowDialog("FLAREUI_RELOAD")
    end)

    S:On("RowChanged", function() Panel:Refresh() end)
    S:On("ReloadChanged", UpdateFooter)
end

--------------------------------------------------
-- 8. OPENING
--------------------------------------------------
-- "settings" (the pages) or "whatsnew"
function Panel:SetMode(mode)
    if not frame then return end
    local news = mode == "whatsnew"
    if news then S:Fire("PageShown", nil) elseif current then S:Fire("PageShown", current) end
    frame.body:SetShown(not news)
    frame.news:SetShown(news)
    for _, b in ipairs(frame.topTabs) do if b.SetSelected then b:SetSelected(b.mode == mode) end end
    if not news then self:Refresh() end
end

function Panel:Open(key, tabKey)
    if not frame then BuildWindow() end
    if key and tabKey then currentTab[key] = tabKey end
    if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    key = key or current or (ns.db and ns.db.global and ns.db.global.settingsPage) or "about"
    if not S.modules[key] then key = "about" end
    current = key
    frame:Show()
    self:SetMode("settings")
    self:Select(key)
end

function Panel:OpenWhatsNew()
    self:Open()
    self:SetMode("whatsnew")
end

-- What's new opens by itself once after an update (a fresh install gets the welcome instead)
do
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("PLAYER_LOGIN")
    loader:SetScript("OnEvent", function()
        local global = ns.db and ns.db.global
        local version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
        if not (global and version) or global.whatsNewSeen == version then return end
        local update = global.welcomeSeen and global.whatsNewSeen ~= nil
        global.whatsNewSeen = version
        if update and ns.WhatsNew and ns.WhatsNew[1] then
            C_Timer.After(4, function()
                if not InCombatLockdown() then Panel:OpenWhatsNew() end
            end)
        end
    end)
end

function Panel:Toggle(key)
    if frame and frame:IsShown() then frame:Hide() else self:Open(key) end
end

-- Going to Edit Mode closes the panel without the reload reminder: it comes back afterwards
function Panel:Hide()
    if not frame then return end
    Panel.quietHide = true
    frame:Hide()
    Panel.quietHide = nil
end

function Panel:IsShown()
    return frame and frame:IsShown() or false
end
