local ADDON_NAME, ns = ...
local L = ns.L
local S = ns.Settings

--------------------------------------------------
-- SETTINGS PANEL
-- The window built from the registry: modules on the left, the page's rows in the middle, the
-- hovered row's text on the right, the reload bar below. Built on first open.
--------------------------------------------------
-- 11-10 rework (Development/Research/Settings Panel Report): wider, after EnhanceQoL's layout.
-- With the reload bar below (42) it fits 768 units; a smaller screen scales it down (FitScale).
local WIDTH, HEIGHT = 1180, 700
local HEADER_H, FOOTER_H = 46, 34
local FOOTER_RISE = 8    -- the reload bar's extra height for the top the window's bronze frame covers
local LEFT_W, RIGHT_W = 200, 280
local PAD = 12
local EDGE, GAP, INNER = 14, 8, 10   -- body to window edge, between the three boxes, inside the middle box
local ROW_H, SECTION_H = 36, 34
-- 11-10 batch C: rows on dark plates with a gap between them, each section in its own box
local ROW_GAP, HALF_GAP = 4, 8
local SEC_X, SEC_TOP, SEC_BOTTOM, SEC_GAP = 10, 2, 10, 10   -- inside a section box; between boxes
local rowInset = 0   -- where rows start: SEC_X inside section boxes, 0 for search results
-- kinds drawn on a plate (text blocks, legends, style cards and headings are not)
local PLATED = { toggle = true, choice = true, dropdown = true, range = true, frame = true, button = true,
    keybind = true, buttons = true, editmode = true }
local INDENT = 18
-- the header row's middle: halfway down the band above the boxes, past the border's 4 px line
local HEADER_ROW_Y = math.floor((4 + HEADER_H + EDGE) / 2) + 1
-- the middle box's inside (the page) and, less the scroll line, the rows' width
local MIDDLE_W = WIDTH - 2 * EDGE - LEFT_W - RIGHT_W - 2 * GAP - 2 * INNER
local CONTENT_W = MIDDLE_W - 14
local LOGO = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Art\\Icon.png"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local PICTURE = "Interface\\AddOns\\FlareUI\\Media\\Art\\Banner.png"

local BRONZE_MUTED = { 0.61, 0.48, 0.29 }

-- Blizzard's NEW label, smaller and with its text at the frame's left. Its glow reaches 20 px past the
-- text: tightened, so it stays inside tabs and clear of checkboxes.
local NEW_SCALE, NEW_GAP, NEW_W = 0.65, 3, 20   -- gap and width on screen
local function NewBadge(parent)
    local badge = CreateFrame("Frame", nil, parent, "NewFeatureLabelNoAnimateTemplate")
    badge:SetScale(NEW_SCALE)
    badge.Label:ClearAllPoints()
    badge.Label:SetPoint("LEFT")
    badge.BGLabel:ClearAllPoints()
    badge.BGLabel:SetPoint("LEFT", 0.5, -0.5)
    badge.Glow:ClearAllPoints()
    badge.Glow:SetPoint("TOPLEFT", badge.Label, -6, 4)
    badge.Glow:SetPoint("BOTTOMRIGHT", badge.Label, 6, -4)
    -- room for the label in this language ("НОВИНКА" is wider than "NEW")
    local w = (badge.Label:GetUnboundedStringWidth() or 0) * NEW_SCALE
    if w > NEW_W then NEW_W = math.ceil(w) end
    return badge
end

-- a section's Reset, confirmed (the section's name in the question)
ns.Dialogs = ns.Dialogs or {}
ns.Dialogs["FLAREUI_RESET_SECTION"] = {
    text = L["Reset the %s options to their defaults?"],
    button1 = L["Reset"],
    button2 = L["Cancel"],
    OnAccept = function(data)
        if not data or InCombatLockdown() then return end
        -- one redraw for the whole section, not one per option
        local panel = ns.SettingsPanel
        panel.toggleHold = true
        S:ResetSection(data.module, data.section, data.tab)
        panel.toggleHold = nil
        if panel.toggleRefreshPending then panel.toggleRefreshPending = nil; panel:Refresh() end
    end,
    hideOnEscape = true,
}

local Panel = {}
Panel.NewBadge = NewBadge
ns.SettingsPanel = Panel

local frame             -- the window
local current           -- module key shown
local searchText = ""
local navButtons = {}   -- module key -> left list button
local pools = {}        -- row kind -> list of row frames
local used = {}         -- row frames on the page
local currentTab = {}   -- module key -> tab key shown, for the session (a reload opens each page on its first tab)
local scrollOf = {}     -- module key -> where its page was scrolled, for the session
local customHosts = {}  -- "module.tab" -> a custom tab's frame

--------------------------------------------------
-- 1. SMALL HELPERS
--------------------------------------------------
-- (11-13, Marcus) Blizzard's own scroll bar (MinimalScrollBar: the thin track, its thumb and the
-- up / down arrows), shown only when there is something to scroll. The API stays FlareUI's:
-- line:SetValues(visible, position) takes 0..1 shares; line.onScroll(position) fires when the player
-- drags it, clicks its track or arrows.
local SCROLL_SCALE = 0.7
function Panel.ScrollLine(parent)
    local line = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
    -- (11-13, Marcus: squished between the borders) drawn at 70%: thinner, arrows too
    line:SetScale(SCROLL_SCALE)
    line.visible, line.position = 1, 0
    local setting = false
    function line:SetValues(visible, position)
        self.visible, self.position = visible or 1, math.max(0, math.min(1, position or 0))
        if self.visible >= 0.999 then self:Hide() return end
        self:Show()
        setting = true
        self:SetVisibleExtentPercentage(self.visible)
        -- an arrow click moves a quarter of what shows
        self:SetPanExtentPercentage(math.max(0.01, self.visible * 0.25))
        self:SetScrollPercentage(self.position, true)
        setting = false
    end
    line:RegisterCallback("OnScroll", function(_, position)
        if setting or not line.onScroll then return end
        line.onScroll(math.max(0, math.min(1, position or 0)))
    end, line)
    return line
end

-- A scroll line in a ScrollFrame's right gutter, plus mouse wheel scrolling
function Panel.AttachScrollLine(scroll, parent, step)
    local line = Panel.ScrollLine(parent)
    -- (offsets in the bar's own, scaled, units)
    line:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 5 / SCROLL_SCALE, 0)
    line:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 5 / SCROLL_SCALE, 0)
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
    -- inside the settings window, Shift + wheel sizes the whole window (Panel.ScaleStep); other
    -- windows with a scroll line (chat copy, perf report) just scroll
    local inWindow
    scroll:SetScript("OnMouseWheel", function(self, delta)
        if inWindow == nil and frame then
            inWindow = false
            local region = self
            while region do
                if region == frame then inWindow = true break end
                region = region:GetParent()
            end
        end
        if inWindow and IsShiftKeyDown() then Panel.ScaleStep(delta) return end
        local range = self:GetVerticalScrollRange() or 0
        self:SetVerticalScroll(math.max(0, math.min(range, (self:GetVerticalScroll() or 0) - delta * (step or 40))))
    end)
    scroll:HookScript("OnVerticalScroll", Update)
    scroll:HookScript("OnScrollRangeChanged", Update)
    scroll:HookScript("OnSizeChanged", Update)
    scroll:HookScript("OnShow", Update)
    scroll:HookScript("OnHide", Update)
    Update()
end

-- Tooltips over the panel and FlareUI's Edit Mode settings stay opaque black: later background
-- paints (Blizzard, the Tooltips module) are painted over. Other tooltips get the default colour back.
local function WantsDark(owner)
    local panel = _G.FlareUI_SettingsPanel
    while owner do
        -- forbidden frames (nameplates) allow no method but IsForbidden
        if owner.IsForbidden and owner:IsForbidden() then return false end
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

-- The window's fonts (11-13, Marcus): Blizzard's Friz Quadrata for everything, as the 5.x window and
-- Forever's own windows, in full white with Blizzard's solid shadow. A Russian client takes Friz's
-- Cyrillic file. Roboto Condensed (11-10 to 11-13) read too sharp to players; it and Marcellus still
-- ship, for the players' font choices.
-- (6.3.1) The window's font objects are FlareUI's own, built from scratch: never copies of Blizzard's.
-- A copy (CopyFontObject) shares its letter sets with Blizzard's font, so setting the copy changed
-- GameFontNormal & co. for the whole game (6.3: buff timers, window titles and quest text resized
-- for every player). Each is a font family of its own: Friz for Latin letters, Friz's Cyrillic file
-- for Russian (FlareUI in Russian on any client), Blizzard's faces for Korean and Chinese.
local RUSSIAN = GetLocale() == "ruRU" or (ns.LoadedLocale and ns.LoadedLocale() == "ruRU")
local PANEL_FACE = RUSSIAN and "Fonts\\FRIZQT___CYR.TTF" or "Fonts\\FRIZQT__.TTF"
local BODY_FONT, TITLE_FONT = PANEL_FACE, PANEL_FACE
local TEXT_WHITE = { 1, 1, 1 }
local function Shade(font)
    font:SetShadowColor(0, 0, 0, 1)
    font:SetShadowOffset(1, -1)
end
-- one of the window's fonts: name, face, size, colour (white when nil: Blizzard's yellow is set after)
local function PanelFont(name, face, size, color)
    local F = ns.FontFamily
    local font
    if CreateFontFamily and F then
        local members = {}
        for _, alphabet in ipairs(F.alphabets) do
            local file = alphabet == "roman" and face or F.stock[alphabet]
            if alphabet == "russian" then file = "Fonts\\FRIZQT___CYR.TTF" end
            members[#members + 1] = { alphabet = alphabet, file = file, height = size, flags = "" }
        end
        local ok, made = pcall(CreateFontFamily, name, members)
        if ok then font = made end
    end
    if not font then
        font = CreateFont(name)
        font:SetFont(face, size, "")
    end
    Shade(font)
    local c = color or TEXT_WHITE
    font:SetTextColor(c[1], c[2], c[3])
    return font
end
local GOLD, GREY = { 1, 0.82, 0 }, { 0.5, 0.5, 0.5 }
local PANEL_FONT = {}   -- Blizzard font object name -> the window's own
for blizzard, def in pairs({
    GameFontHighlight      = { "Text",      BODY_FONT,  13, TEXT_WHITE },
    GameFontHighlightSmall = { "TextSmall", BODY_FONT,  12, TEXT_WHITE },
    GameFontNormal         = { "Gold",      BODY_FONT,  13, GOLD },
    GameFontNormalSmall    = { "GoldSmall", BODY_FONT,  12, GOLD },
    GameFontDisable        = { "Grey",      BODY_FONT,  13, GREY },
    GameFontDisableSmall   = { "GreySmall", BODY_FONT,  11, GREY },
    GameFontNormalLarge    = { "Title",     TITLE_FONT, 17, GOLD },
    GameFontNormalHuge     = { "TitleHuge", TITLE_FONT, 22, GOLD },
}) do
    local name = "FlareUI_Panel" .. def[1]
    PanelFont(name, def[2], def[3], def[4])
    PANEL_FONT[blizzard] = name
end
Panel.FONT = PANEL_FONT
-- the button text: Blizzard's yellow, as its buttons' (11-13)
local BUTTON_FONT = PanelFont("FlareUI_PanelButton", BODY_FONT, 13, GOLD)
local BUTTON_FONT_SMALL = PanelFont("FlareUI_PanelButtonSmall", BODY_FONT, 11, GOLD)
-- (kept for its callers: the titles are made at their sizes above)
local function ApplyTitleFont() end
-- at load too: the setup tour can show before the settings window is ever built
ApplyTitleFont()

local function Text(parent, font, justify)
    font = font or "GameFontHighlight"
    local fs = parent:CreateFontString(nil, "OVERLAY", PANEL_FONT[font] or font)
    fs:SetJustifyH(justify or "LEFT")
    return fs
end

-- LONG TRANSLATIONS (11-11, Russian ran past buttons, card titles and the left list): a text too
-- wide for its room first wraps onto up to maxLines lines, then shrinks, down to MIN_TEXT_SCALE.
-- width: the room it has; maxLines: 1 (the default) keeps it on one line. Call again after SetText.
local MIN_TEXT_SCALE = 0.7
local function FitText(fs, width, maxLines)
    if not (fs and width and width > 1) then return end
    maxLines = maxLines or 1
    fs:SetTextScale(1)
    local full = fs:GetUnboundedStringWidth() or 0
    if full <= width then return end
    if maxLines <= 1 then
        fs:SetTextScale(math.max(MIN_TEXT_SCALE, width / full))
        return
    end
    -- wrapped: smaller until it fits in maxLines and its longest word fits the width
    local longest = 0
    local text = fs:GetText() or ""
    for word in text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gmatch("%S+") do
        longest = math.max(longest, #word)
    end
    local scale = 1
    while scale > MIN_TEXT_SCALE do
        fs:SetTextScale(scale)
        local lines = fs:GetNumLines() or 1
        local wordW = full * longest / math.max(1, #text)   -- (roughly: the longest word's share)
        if lines <= maxLines and wordW * scale <= width then return end
        scale = scale - 0.05
    end
    fs:SetTextScale(MIN_TEXT_SCALE)
end

-- A dark box with a bronze edge: the left list, the page and the right column
-- FlareUI Thin (8 px edge) for every box, button and tab in the window (11-10, Marcus)
local THIN = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Borders\\FlareUI-Thin.tga"
local THIN_EDGE, THIN_INSET = 8, 4   -- fills start 4 px in: under the border's rounded corners
local EDGE_COLOR = { 0.55, 0.42, 0.24 }       -- resting
local EDGE_HOVER = { 0.98, 0.74, 0.36 }      -- under the pointer (11-13 brighter: was 0.78, 0.6, 0.34)
local EDGE_LIT = { 1, 0.86, 0.46 }            -- selected
local function ThinBackdrop(f, withFill)
    f:SetBackdrop({ bgFile = withFill and WHITE or nil, edgeFile = THIN, edgeSize = THIN_EDGE,
        insets = { left = THIN_INSET, right = THIN_INSET, top = THIN_INSET, bottom = THIN_INSET } })
    f:SetBackdropBorderColor(EDGE_COLOR[1], EDGE_COLOR[2], EDGE_COLOR[3], 1)
end

-- the Thin edge on its own frame over f, so f's fill textures sit under it; f.edge
local function ThinEdge(f)
    local edge = CreateFrame("Frame", nil, f, "BackdropTemplate")
    edge:SetAllPoints()
    edge:SetFrameLevel(f:GetFrameLevel() + 1)
    ThinBackdrop(edge)
    f.edge = edge
    return edge
end

-- FlareUI Thick (12 px edge), on its own frame over f as ThinEdge: tabs, buttons and dropdowns (11-11
-- Marcus: heavier, closer to Forever's own panels)
local THICK = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Borders\\FlareUI-Thick.tga"
local THICK_EDGE, THICK_INSET = 12, 3
local function ThickEdge(f)
    local edge = CreateFrame("Frame", nil, f, "BackdropTemplate")
    edge:SetAllPoints()
    edge:SetFrameLevel(f:GetFrameLevel() + 1)
    edge:SetBackdrop({ edgeFile = THICK, edgeSize = THICK_EDGE })
    edge:SetBackdropBorderColor(EDGE_COLOR[1], EDGE_COLOR[2], EDGE_COLOR[3], 1)
    f.edge = edge
    return edge
end

-- a highlight or a selection: the option rows' rounded box (our art, 8 px corners as a nine-slice)
local ROUND_RECT = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Panel\\RoundRect.tga"
local function Rounded(tex, r, g, b, a)
    tex:SetTexture(ROUND_RECT)
    if tex.SetTextureSliceMargins then
        tex:SetTextureSliceMargins(8, 8, 8, 8)
        if Enum.UITextureSliceMode then tex:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched) end
    end
    if r then tex:SetVertexColor(r, g, b, a or 1) end
    return tex
end
Panel.Rounded = Rounded
Panel.ThickEdge = function(f) return ThickEdge(f) end

local function Box(f, alpha)
    ThinBackdrop(f, true)
    f:SetBackdropColor(0, 0, 0, alpha or 0.28)
end
Panel.Box = Box

-- A bronze plate button: the page's tabs and the window's Settings / What's New. Lit when selected.
-- (11-13, Marcus: "all buttons in the grey Blizzard style, bronze borders on all") every button and tab
-- wears the face of Blizzard's own dropdown box (WowStyle2: common-dropdown-c-button), its grey with the
-- bronze rim, in Blizzard's states: hover, pressed, pressed under the pointer, disabled; a selected tab
-- (b.fSelected) takes the open box's. The art reaches 7 px past the button, as on the dropdown.
local FACE = "common-dropdown-c-button"
local function PaintFace(b)
    local atlas
    if not b:IsEnabled() then atlas = FACE .. "-disabled"
    elseif b.fDown and b.fOver then atlas = FACE .. "-pressedhover-1"
    elseif b.fDown then atlas = FACE .. "-pressed-1"
    elseif b.fOver then atlas = FACE .. "-hover-1"
    elseif b.fSelected then atlas = FACE .. "-open"
    else atlas = FACE end
    b.fFace:SetAtlas(atlas)
end
local function GreyFace(b)
    local face = b:CreateTexture(nil, "BACKGROUND", nil, 2)
    face:SetPoint("TOPLEFT", -7, 7)
    face:SetPoint("BOTTOMRIGHT", 7, -7)
    b.fFace = face
    b:HookScript("OnEnter", function(self) self.fOver = true; PaintFace(self) end)
    b:HookScript("OnLeave", function(self) self.fOver = nil; PaintFace(self) end)
    b:HookScript("OnMouseDown", function(self) if self:IsEnabled() then self.fDown = true; PaintFace(self) end end)
    b:HookScript("OnMouseUp", function(self) self.fDown = nil; PaintFace(self) end)
    b:HookScript("OnEnable", PaintFace)
    b:HookScript("OnDisable", function(self) self.fDown, self.fOver = nil, nil; PaintFace(self) end)
    b:HookScript("OnShow", PaintFace)
    PaintFace(b)
end
Panel.GreyFace = GreyFace

local function Plate(parent, font)
    local b = CreateFrame("Button", nil, parent)
    GreyFace(b)
    b.Text = Text(b, font or "GameFontHighlightSmall", "CENTER")
    b.Text:SetPoint("LEFT", 8, 0)
    b.Text:SetPoint("RIGHT", -8, 0)
    b.Text:SetWordWrap(false)
    -- Blizzard's yellow, white under the pointer or selected
    local function TextColor(self)
        if self.fSelected or self.fOver then self.Text:SetTextColor(1, 1, 1) else self.Text:SetTextColor(1, 0.82, 0) end
    end
    function b:SetSelected(selected)
        self.isSelected = selected and true or false
        self.fSelected = self.isSelected
        PaintFace(self)
        TextColor(self)
    end
    b:HookScript("OnEnter", TextColor)
    b:HookScript("OnLeave", TextColor)
    b:SetSelected(false)
    return b
end
Panel.Plate = Plate

-- The controls kit (11-10, batch B), drawn from one smooth disc (tools/panelart.js)
local CIRCLE = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Panel\\Circle.tga"
local GOLD = { 0.91, 0.77, 0.42 }
-- (11-13, Marcus: more Blizzard-like) titles in WoW's own yellow (NORMAL_FONT_COLOR): the window's name,
-- page titles, section headers and the Info Panel's titles; buttons and sliders keep the bronze gold
local TITLE_YELLOW = { 1, 0.82, 0 }
Panel.TITLE_YELLOW = TITLE_YELLOW

-- A pill of the disc: two half discs and a stretched middle, so the ends stay round at any width.
-- height is the frame's; inset draws it that much inside (a fill inside its rim).
local function Pill(parent, layer, sub, inset, height)
    local half = (height - 2 * inset) / 2
    local p = {}
    p.l = parent:CreateTexture(nil, layer, nil, sub)
    p.l:SetTexture(CIRCLE)
    p.l:SetTexCoord(0, 0.5, 0, 1)
    p.l:SetPoint("TOPLEFT", inset, -inset)
    p.l:SetPoint("BOTTOMLEFT", inset, inset)
    p.l:SetWidth(half)
    p.r = parent:CreateTexture(nil, layer, nil, sub)
    p.r:SetTexture(CIRCLE)
    p.r:SetTexCoord(0.5, 1, 0, 1)
    p.r:SetPoint("TOPRIGHT", -inset, -inset)
    p.r:SetPoint("BOTTOMRIGHT", -inset, inset)
    p.r:SetWidth(half)
    p.m = parent:CreateTexture(nil, layer, nil, sub)
    p.m:SetTexture(CIRCLE)
    p.m:SetTexCoord(0.49, 0.51, 0, 1)
    p.m:SetPoint("TOPLEFT", p.l, "TOPRIGHT")
    p.m:SetPoint("BOTTOMRIGHT", p.r, "BOTTOMLEFT")
    function p:SetColor(r, g, b, a)
        for _, t in ipairs({ self.l, self.m, self.r }) do t:SetVertexColor(r, g, b, a or 1) end
    end
    -- top and bottom colours, { r, g, b }
    function p:SetGradient(top, bottom)
        for _, t in ipairs({ self.l, self.m, self.r }) do
            t:SetGradient("VERTICAL", CreateColor(bottom[1], bottom[2], bottom[3], 1), CreateColor(top[1], top[2], top[3], 1))
        end
    end
    return p
end
Panel.Pill = Pill

-- The toggles (11-13, Marcus): Blizzard's checkbox with its gold checkmark, as players asked; the stone
-- switch (11-10 to 11-13) is retired. A plain CheckButton: SetChecked / GetChecked / Click as before.
-- (11-13, Marcus) the art of Blizzard's own settings checkbox (SettingsCheckboxTemplate): the
-- bronze-rimmed box and its tick, by atlas (the template's mixin wants Blizzard's setting data)
local function Switch(parent)
    local s = CreateFrame("CheckButton", nil, parent)
    s:SetSize(30, 29)
    s:SetNormalAtlas("checkbox-minimal")
    s:SetPushedAtlas("checkbox-minimal")
    local tick = s:CreateTexture(nil, "ARTWORK")
    tick:SetAtlas("checkmark-minimal", true)
    tick:SetPoint("CENTER")
    s:SetCheckedTexture(tick)
    local greyTick = s:CreateTexture(nil, "ARTWORK")
    greyTick:SetAtlas("checkmark-minimal-disabled", true)
    greyTick:SetPoint("CENTER")
    s:SetDisabledCheckedTexture(greyTick)
    s:SetMotionScriptsWhileDisabled(true)
    s:SetScript("OnDisable", function(self) self:SetAlpha(0.45) end)
    s:SetScript("OnEnable", function(self) self:SetAlpha(1) end)
    return s
end
Panel.Switch = Switch

-- Blizzard's panel button as a bronze plate (its own art hidden); gold text, white on hover
local function SkinButton(b)
    for _, r in ipairs({ b:GetRegions() }) do
        if r:IsObjectType("Texture") then r:SetAlpha(0) end
    end
    if b.NineSlice then b.NineSlice:Hide() end
    -- Blizzard's grey face with the bronze rim (GreyFace); no highlight of its own: the face lights
    b:SetHighlightTexture(b:CreateTexture())
    GreyFace(b)
    b:SetNormalFontObject(BUTTON_FONT)
    -- (the short ones, 22 px and under, a size smaller: 11-11 Marcus)
    local function FitFont(self)
        local small = (self:GetHeight() or 0) <= 22.5
        if self.ftSmallFont ~= small then
            self.ftSmallFont = small
            self:SetNormalFontObject(small and BUTTON_FONT_SMALL or BUTTON_FONT)
        end
    end
    b:HookScript("OnSizeChanged", FitFont)
    FitFont(b)
    -- a long label shrinks to fit the button (FitText)
    local function FitLabel(self)
        local label = self:GetFontString()
        if label then FitText(label, (self:GetWidth() or 0) - 2 * THICK_INSET - 6, 1) end
    end
    hooksecurefunc(b, "SetText", FitLabel)
    b:HookScript("OnSizeChanged", FitLabel)
    FitLabel(b)
    b:SetHighlightFontObject(_G[PANEL_FONT.GameFontHighlight])
    b:SetDisabledFontObject(_G[PANEL_FONT.GameFontDisable])
    return b
end
Panel.SkinButton = SkinButton
Panel.FitText = FitText
ns.SkinButton = SkinButton   -- FlareUI's other windows (dialogs, tour, About, radial editor)
local function PanelButton(parent)
    return SkinButton(CreateFrame("Button", nil, parent, "UIPanelButtonTemplate"))
end

-- Blizzard's dropdown button as a bronze-rimmed pill with a gold arrow
local function SkinDropdown(dd)
    for _, r in ipairs({ dd:GetRegions() }) do
        if r:IsObjectType("Texture") and r ~= dd.Arrow then r:SetAlpha(0) end
    end
    -- (11-11 Marcus: squared and heavier, its middle the buttons' brown, as Forever's own dropdowns)
    dd.fEdge = ThickEdge(dd)
    dd.fFill = dd:CreateTexture(nil, "BACKGROUND", nil, 2)
    dd.fFill:SetPoint("TOPLEFT", THICK_INSET, -THICK_INSET)
    dd.fFill:SetPoint("BOTTOMRIGHT", -THICK_INSET, THICK_INSET)
    Rounded(dd.fFill)
    dd.fFill:SetGradient("VERTICAL", CreateColor(0.09, 0.065, 0.04, 1), CreateColor(0.24, 0.17, 0.10, 1))
    if dd.Arrow then
        dd.Arrow:SetAlpha(0)
        dd.fChevron = dd:CreateTexture(nil, "OVERLAY")
        dd.fChevron:SetTexture("Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Panel\\Chevron.tga")
        dd.fChevron:SetSize(14, 14)
        dd.fChevron:SetPoint("RIGHT", -10, 0)
        dd.fChevron:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
        if dd.Text then
            dd.Text:ClearAllPoints()
            dd.Text:SetPoint("LEFT", 12, 0)
            dd.Text:SetPoint("RIGHT", dd.fChevron, "LEFT", -6, 0)
            dd.Text:SetJustifyH("LEFT")
        end
    end
    if dd.Text then
        dd.Text:SetFontObject(_G[PANEL_FONT.GameFontHighlightSmall])
        -- the buttons' gold (11-11 Marcus); Blizzard's template sets its own colour on each state change
        local function TextColor(self)
            if self:IsEnabled() then self.Text:SetTextColor(TITLE_YELLOW[1], TITLE_YELLOW[2], TITLE_YELLOW[3]) else self.Text:SetTextColor(0.5, 0.5, 0.5) end
        end
        if dd.OnButtonStateChanged then hooksecurefunc(dd, "OnButtonStateChanged", TextColor) end
        dd:HookScript("OnEnable", TextColor)
        dd:HookScript("OnDisable", TextColor)
        TextColor(dd)
    end
    dd:HookScript("OnEnter", function(self) self.fEdge:SetBackdropBorderColor(EDGE_HOVER[1], EDGE_HOVER[2], EDGE_HOVER[3], 1) end)
    dd:HookScript("OnLeave", function(self) self.fEdge:SetBackdropBorderColor(EDGE_COLOR[1], EDGE_COLOR[2], EDGE_COLOR[3], 1) end)
end
Panel.SkinDropdown = SkinDropdown

-- a stepper's arrows: gold, on small round bronze plates
local function SkinArrow(b)
    for _, r in ipairs({ b:GetRegions() }) do
        if r:IsObjectType("Texture") then
            r:SetDesaturated(true)
            r:SetVertexColor(TITLE_YELLOW[1], TITLE_YELLOW[2], TITLE_YELLOW[3])   -- (WoW yellow, 11-13)
        end
    end
    local rim = b:CreateTexture(nil, "BACKGROUND", nil, -2)
    rim:SetTexture(CIRCLE)
    rim:SetSize(22, 22)
    rim:SetPoint("CENTER")
    rim:SetVertexColor(0.47, 0.36, 0.22)
    local fill = b:CreateTexture(nil, "BACKGROUND", nil, -1)
    fill:SetTexture(CIRCLE)
    fill:SetSize(20, 20)
    fill:SetPoint("CENTER")
    fill:SetVertexColor(0.14, 0.10, 0.06)
end

--------------------------------------------------
-- 2. RIGHT COLUMN
--------------------------------------------------
local preview = {}
local previewRow

-- the page's own picture (its tab's), or nil for the page's art
local function PageSpec()
    local tab = currentTab[current]
    if current == 'qol' then
        tab = tab or 'gameplay'
        if tab == 'nameplates' then return { kind = 'nameplate', key = 'qol.npOverview' } end
        return nil
    end
    -- Bags & Looting: the bags picture, the loot feed's on Looting
    if current == 'bl' then
        tab = tab or 'bags'
        if tab == 'bags' then return { kind = 'bags', key = 'bl.bagsOverview' } end
        if tab == 'looting' then return { kind = 'lootFeed', key = 'bl.lootOverview' } end
        return nil
    end
    -- Buff Reminders (its own page since 11-12): the reminder row on every tab
    if current == 'br' then return { kind = 'reminders', key = 'br.remindersOverview' } end
    if current == 'ab' and tab == 'xp' then return { kind = 'xp', key = 'ab.xpOverview' } end
    if current == 'dm' and tab == 'threat' then return { kind = 'meter', key = 'dm.threatOverview' } end
    return ns.SettingsPreview.Module(current)
end

-- 11-10 (Marcus): a picture shows the current settings only; hovering never tries a value on
local function ShowVisual(row)
    if not preview.canvas then return end
    if preview.module ~= current or preview.tab ~= currentTab[current] then
        preview.spec = nil; preview.helpRow = nil; preview.module = current; preview.tab = currentTab[current]
    end
    if preview.dirty and not row and preview.spec and S.rows and S.rows[preview.spec.key] then
        preview.spec = ns.SettingsPreview.Resolve(S.rows[preview.spec.key]) or preview.spec
    end
    -- a row without a picture shows the page's
    local spec
    if row then spec = ns.SettingsPreview.Resolve(row) or PageSpec()
    else spec = preview.spec or PageSpec() end
    local value
    -- One stable composition for the whole Action Bars page. Only dropdown exploration carries
    -- a temporary value; ordinary hover changes the explanation, not the scene or animation.
    if spec and spec.kind == 'actions' and value == nil then spec = { kind = 'actions', key = 'ab.overview' } end
    local old = preview.spec
    local same = old and spec and old.kind == spec.kind and old.key == spec.key and old.value == spec.value
        and old.path == spec.path and old.font == spec.font
    preview.spec = spec
    local shown
    if same and not preview.dirty and not preview.canvas.invalidated and preview.canvas.frame:IsShown() then shown = true
    else shown = ns.SettingsPreview.Show(preview.canvas, spec) end
    preview.dirty = nil
    preview.picture:SetShown(not shown)
    -- as tall as what it shows; a frame shown this moment has no place on screen until the next
    -- frame, so it is measured again then
    if shown then
        local canvas = preview.canvas
        local function Fit()
            if not canvas.frame:IsShown() then return end
            -- what a sample says it takes, else measured on screen
            local h = canvas.used or ns.SettingsPreview.Measure(canvas)
            if h then canvas.frame:SetHeight(math.max(24, math.min(canvas.height, h + 8))) end
        end
        Fit()
        C_Timer.After(0, Fit)
    end
    preview.title:ClearAllPoints()
    preview.title:SetPoint("TOPLEFT", shown and preview.canvas.frame or preview.picture, "BOTTOMLEFT", 0, -12)
    preview.title:SetPoint("RIGHT", -PAD, 0)
end

local function ShowPreview(title, desc, tip)
    preview.title:SetText(title or "")
    preview.desc:SetText(S:Format(desc) or "")
    preview.tip:SetText(tip and (L["Tip:"] .. " " .. S:Format(tip)) or "")
end

-- nothing hovered: the picture and a hint
local function ShowModulePreview()
    previewRow = nil
    ShowVisual(nil)
    local help = preview.helpRow
    if help then
        local title = S:Text(help.key, "info")
        if not title or title == "" then title = help:Label() end
        ShowPreview(title, help:Description(), help:Tip())
        return
    end
    -- About: a word for the players
    if current == "about" then
        ShowPreview(L["Thank You!"], L["To everyone who downloaded FlareUI, sent feedback, reported bugs or helped a friend set it up: thank you. FlareUI gets better every week because of you."])
        return
    end
    ShowPreview(S:WindowText("infoPanelNothingHovered", L["Info Panel"]),
        S:WindowText("infoPanelNothingHovered2", L["Hover any option to see how it works!"]))
end

-- title: the row's info text, else its label, else its section title
local function ShowRowPreview(row, value)
    previewRow = row
    ShowVisual(row, value)
    preview.helpRow = row
    local title = S:Text(row.key, "info")
    if not title or title == "" then title = row:Label() end
    if not title or title == "" then
        title = row.section and ns.Copy and ns.Copy.sections and ns.Copy.sections[row.section]
    end
    ShowPreview(title, row:Description(), row:Tip())
end

-- for custom tabs' own controls
function Panel:ShowPreview(title, desc, tip)
    if preview.picture then previewRow = nil; ShowVisual(nil); ShowPreview(title, desc, tip) end
end
function Panel:ShowModulePreview()
    if preview.picture then ShowModulePreview() end
end

--------------------------------------------------
-- 3. ROWS
-- One frame pool per kind: label on the left, control on the right.
--------------------------------------------------
local Build = {}     -- kind -> function(f): adds the control once
local Fill = {}      -- kind -> function(f, row): shows the row's values

local function RowEnter(self)
    if self.row then ShowRowPreview(self.row) end
    -- (11-13, Marcus) the style cards light up on their own: no row highlight behind them
    if self.kind ~= "styles" then self.hover:Show() end
end

local function RowLeave(self)
    self.hover:Hide()
    -- Keep a visual row visible after hover; cards revert from the hovered variant to the saved
    -- selection. Behaviour-only rows retain the existing explanation/picture behaviour.
    if self.row and ns.SettingsPreview.Resolve(self.row) then ShowRowPreview(self.row)
    else ShowModulePreview() end
end

local function NewRowFrame(parent, kind)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(ROW_H)
    f:EnableMouse(true)
    f:SetScript("OnEnter", RowEnter)
    f:SetScript("OnLeave", RowLeave)
    f.plate = f:CreateTexture(nil, "BACKGROUND", nil, -1)
    f.plate:SetAllPoints()
    f.plate:SetColorTexture(0, 0, 0, 0.26)
    f.plate:SetAlpha(0)   -- (11-11 Marcus: no dark box at rest; only the hover shows the row)
    f.hover = f:CreateTexture(nil, "BACKGROUND")
    f.hover:SetAllPoints()
    -- a rounded box: our own 32 px art, 8 px corners kept as a nine-slice
    f.hover:SetTexture("Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Panel\\RoundRect.tga")
    if f.hover.SetTextureSliceMargins then
        f.hover:SetTextureSliceMargins(8, 8, 8, 8)
        if Enum.UITextureSliceMode then f.hover:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched) end
    end
    f.hover:SetVertexColor(0.98, 0.70, 0.30, 0.26)   -- (11-13 brighter bronze: was 0.79, 0.65, 0.35, 0.14)
    f.hover:Hide()
    -- a click anywhere on a switch's row flips it (the switch takes its own clicks)
    f:SetScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" or not (self.kind == "toggle" or self.kind == "frame") then return end
        local c = self.control
        if c and c:IsVisible() and c:IsEnabled() and self.row and not self.row:IsDisabled() then c:Click() end
    end)
    f.crumb = Text(f, "GameFontDisableSmall")
    f.crumb:SetWordWrap(true)
    f.label = Text(f, "GameFontHighlight")
    f.label:SetWordWrap(true)
    f.label:SetPoint("LEFT", 6, 0)
    f.crumb:SetPoint("BOTTOMLEFT", f.label, "TOPLEFT", 0, 1)
    -- in search results the path is a link: it opens the row's page and shows the row
    local link = CreateFrame("Button", nil, f)
    link:SetAllPoints(f.crumb)
    link:SetScript("OnEnter", function() f.crumb:SetTextColor(NORMAL_FONT_COLOR:GetRGB()) RowEnter(f) end)
    link:SetScript("OnLeave", function() f.crumb:SetTextColor(GRAY_FONT_COLOR:GetRGB()) RowLeave(f) end)
    link:SetScript("OnClick", function() if f.row then Panel:JumpTo(f.row) end end)
    link:Hide()
    f.crumbLink = link
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

-- the control's hover also fills the right column
local function ForwardHover(control, rowFrame)
    control:HookScript("OnEnter", function() RowEnter(rowFrame) end)
    control:HookScript("OnLeave", function() RowLeave(rowFrame) end)
end

-- choice and dropdown menus: set up once per frame, filled from the row it shows
local function IsChoice(c) return c.row:Get() == c.value end
local function PickChoice(c) c.row:Set(c.value) end
-- a row with toggles (row.toggles, an ns.Conditions spec): checkboxes that stay open. A full Refresh
-- would drop the open menu, so the page is redrawn once it closes (RowChanged in Panel:Init)
local function IsTicked(c) return ns.Conditions.Ticked(c.row:Get(), c.value, c.row.toggles) end
local function Tick(c)
    Panel.toggleHold = true
    c.row:Set(ns.Conditions.Toggle(c.row:Get(), c.value, c.row.toggles))
    Panel.toggleHold = nil
end
local function OnToggleMenuClosed()
    if Panel.toggleRefreshPending then
        Panel.toggleRefreshPending = nil
        Panel:Refresh()
    end
end
local function SetupChoiceMenu(dropdown, f)
    dropdown:RegisterCallback(DropdownButtonMixin.Event.OnMenuClose, OnToggleMenuClosed, dropdown)
    dropdown:RegisterCallback(DropdownButtonMixin.Event.OnMenuClose, function()
        if f.row then ShowRowPreview(f.row) end
    end, f)
    dropdown:SetupMenu(function(_, root)
        local row = f.row
        if not row then return end
        for _, c in ipairs(row:Choices()) do
            if c.divider then
                root:CreateDivider()
            elseif row.toggles then
                c.row = row
                root:CreateCheckbox(c.text, IsTicked, Tick, c)
            else
                c.row = row
                local option = root:CreateRadio(c.text, IsChoice, PickChoice, c)
                option:SetOnEnter(function() ShowRowPreview(row, c.value) end)
                option:SetOnLeave(function() ShowRowPreview(row) end)
                if row.previewFont and row.key:match('%.face$') then
                    option:AddInitializer(function(button)
                        if button.fontString then
                            ns.SetFontFamily(button.fontString, ns.GetFontPath(c.value), 13, '')
                        end
                    end)
                end
            end
        end
    end)
    -- the Gamepad UI: FlareUI's plain list in place of Blizzard's menu (PadNav.GuardDropdown)
    if ns.PadNav and ns.PadNav.GuardDropdown then
        ns.PadNav.GuardDropdown(dropdown, function()
            local row, entries = f.row, {}
            if not row then return entries end
            for _, c in ipairs(row:Choices()) do
                if c.divider then
                    entries[#entries + 1] = { divider = true }
                else
                    c.row = row
                    local e = { text = c.text, multi = row.toggles ~= nil }
                    if row.toggles then
                        e.checked, e.pick = function() return IsTicked(c) end, function() Tick(c) end
                    else
                        e.checked, e.pick = function() return IsChoice(c) end, function() PickChoice(c) end
                        e.onEnter = function() ShowRowPreview(row, c.value) end
                        e.onLeave = function() ShowRowPreview(row) end
                    end
                    if row.previewFont and row.key:match('%.face$') then
                        e.font = function(fs) ns.SetFontFamily(fs, ns.GetFontPath(c.value), 13, '') end
                    end
                    entries[#entries + 1] = e
                end
            end
            return entries
        end, function()
            OnToggleMenuClosed()
            if f.row then ShowRowPreview(f.row) end
        end)
    end
end

-- toggle
Build.toggle = function(f)
    local check = Switch(f)
    check:SetPoint("RIGHT", -6, 0)
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

-- choice: Blizzard's Settings stepper (dropdown with arrows)
Build.choice = function(f)
    local stepper = CreateFrame("Frame", nil, f, "SettingsDropdownWithButtonsTemplate")
    stepper:SetPoint("RIGHT", 4, 0)
    if stepper.Label then stepper.Label:Hide() end
    stepper.Dropdown:SetWidth(180)
    -- the template places its arrows past its right edge; anchor them to the row so none is clipped
    stepper.IncrementButton:ClearAllPoints()
    stepper.IncrementButton:SetPoint("RIGHT", f, "RIGHT", -6, 0)
    stepper.Dropdown:ClearAllPoints()
    -- (11-13, Marcus: the arrows close to the box)
    stepper.Dropdown:SetPoint("RIGHT", stepper.IncrementButton, "LEFT", -1, 0)
    stepper.DecrementButton:ClearAllPoints()
    stepper.DecrementButton:SetPoint("RIGHT", stepper.Dropdown, "LEFT", -1, 0)
    -- (11-13, Marcus) Blizzard's own look, colours and all: the box and its arrows are left unskinned
    ForwardHover(stepper.Dropdown, f)
    ForwardHover(stepper.IncrementButton, f)
    ForwardHover(stepper.DecrementButton, f)
    f:SetHeight(ROW_H)
    f.stepper = stepper
    f.control = stepper
    SetupChoiceMenu(stepper.Dropdown, f)
end
Fill.choice = function(f, row)
    -- narrower on half rows
    f.stepper.Dropdown:SetWidth(row.half and 96 or 180)
    f.stepper.Dropdown:GenerateMenu()
    f:SetHeight(ROW_H)
end


-- Discrete numeric settings keep their registered choices, including Default/Auto.
-- Dragging previews without writes; releasing commits once. Keyboard changes commit directly.
Build.range = function(f)
    -- (11-13, Marcus) Blizzard's own settings slider (MinimalSliderWithSteppersTemplate): its bar,
    -- diamond thumb and ‹ › steppers. FlareUI's handling stays: one step per choice, a live preview
    -- while dragging, saved on release, the value text on the right.
    local holder = CreateFrame("Frame", nil, f, "MinimalSliderWithSteppersTemplate")
    holder:SetSize(234, 20)   -- (11-13, Marcus: longer: as wide as a choice stepper or a dropdown)
    holder:SetPoint("RIGHT", -58, 0)
    local slider = holder.Slider
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    -- (the steppers dim at the ends)
    function slider:PaintFill() holder:UpdateStepperStates() end
    f.value = Text(f, "GameFontNormal", "RIGHT")
    f.value:SetPoint("RIGHT", -4, 0); f.value:SetWidth(48); f.value:SetWordWrap(false)
    -- (only a real change is written: a saved value off the list, say from an old import, stays until moved)
    local function Commit()
        if f.row and f.rangeChoice and not f.row:IsDisabled() and f.rangeChoice.value ~= f.row:Get() then
            f.row:Set(f.rangeChoice.value)
        end
    end
    slider:SetScript("OnMouseDown", function() f.rangeDragging = true end)
    slider:SetScript("OnMouseUp", function() f.rangeDragging = nil; Commit() end)
    slider:SetScript("OnValueChanged", function(self, value)
        self:PaintFill()
        if f.rangeFilling or not f.row then return end
        local choices = f.rangeChoices
        local choice = choices and choices[math.max(1, math.min(#choices, math.floor(value + 0.5)))]
        if not choice then return end
        f.rangeChoice = choice; f.value:SetText(choice.text); FitText(f.value, f.value:GetWidth())
        if f.rangeDragging then ShowRowPreview(f.row, choice.value) else Commit() end
    end)
    ForwardHover(slider, f)
    ForwardHover(holder.Back, f)
    ForwardHover(holder.Forward, f)
    -- the gamepad grabs it (A) and steps it with left / right (PadNav)
    slider.padCycle = function(delta)
        if not f.row or f.row:IsDisabled() then return end
        local lo, hi = slider:GetMinMaxValues()
        slider:SetValue(math.max(lo, math.min(hi, slider:GetValue() + delta)))
    end
    f.slider = slider
    f.control = holder   -- (its SetEnabled greys the steppers too)
end
Fill.range = function(f, row)
    f.rangeFilling = true; f.rangeDragging = nil
    f.rangeChoices = row:Choices()
    local selected = 1
    for i, choice in ipairs(f.rangeChoices) do if choice.value == row:Get() then selected = i end end
    f.rangeChoice = f.rangeChoices[selected]
    f.slider:SetMinMaxValues(1, math.max(1, #f.rangeChoices))
    f.slider:SetValue(selected)
    f.slider:PaintFill()
    -- (11-11) the value box as wide as the longest choice (Russian "По умолчанию" ran past 48 px),
    -- 48 to 96 px, the slider moving left to make room; past 96 the text shrinks
    local widest = 0
    for _, choice in ipairs(f.rangeChoices) do
        f.value:SetTextScale(1); f.value:SetText(choice.text)
        widest = math.max(widest, f.value:GetUnboundedStringWidth() or 0)
    end
    local valueW = math.min(96, math.max(48, math.ceil(widest) + 2))
    f.value:SetWidth(valueW)
    f.control:SetWidth(row.half and 150 or 234)   -- (a half row: as a half stepper)
    f.control:ClearAllPoints(); f.control:SetPoint("RIGHT", -(valueW + 10), 0)
    f.value:SetText(f.rangeChoice and f.rangeChoice.text or '')
    FitText(f.value, valueW)
    f.rangeFilling = nil
    f:SetHeight(ROW_H)
end

-- Only the two major style choices use cards. The remaining options keep their existing controls.
Build.styles = function(f)
    f.cards = {}
end
Fill.styles = function(f, row)
    local choices = row:Choices()
    local minimap = row.key == 'mm.style'
    local gap = minimap and 10 or 6
    local width = (f:GetWidth() - 12 - (#choices - 1) * gap) / #choices
    if minimap then width = math.min(168, width) end
    -- the row of cards is centred (the minimap's are narrower than the row)
    local startX = math.max(6, (f:GetWidth() - (#choices * width + (#choices - 1) * gap)) / 2)
    local cardHeight = minimap and 180 or 92
    local previewHeight = minimap and 148 or 62
    local crumbed = (f.crumb:GetText() or "") ~= ""
    local top = crumbed and 32 or 20
    if row.hideLabel and not crumbed then top = 6 end
    f.label:SetShown(not row.hideLabel or crumbed)
    f.label:ClearAllPoints(); f.label:SetPoint("TOPLEFT", 6, -(top - 20))
    f:SetHeight(top + cardHeight + 8)
    for i, choice in ipairs(choices) do
        local b = f.cards[i]
        if not b then
            b = CreateFrame("Button", nil, f, "BackdropTemplate")
            local edgeFile = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Borders\\FlareUI-Thick.tga"
            b:SetBackdrop({ edgeFile = edgeFile, edgeSize = ns.BorderEdgeSize(edgeFile, 12) })
            -- (11-13, Marcus) the window's natural stone, darkened; 5 px in, so its square corners stay
            -- under the border's round ones. Paint lightens it under the pointer and when chosen.
            b.plate = b:CreateTexture(nil, "BACKGROUND")
            b.plate:SetPoint("TOPLEFT", 5, -5)
            b.plate:SetPoint("BOTTOMRIGHT", -5, 5)
            b.plate:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock", "REPEAT", "REPEAT")
            b.plate:SetHorizTile(true)
            b.plate:SetVertTile(true)
            b.label = Text(b, "GameFontNormalSmall", "CENTER")
            b.label:SetPoint("BOTTOMLEFT", 6, 8); b.label:SetPoint("BOTTOMRIGHT", -6, 8)
            b.tick = Text(b, "GameFontNormal", "RIGHT")
            -- bottom right, beside the name: clear of the sample above
            b.tick:SetPoint("BOTTOMRIGHT", -7, 7); b.tick:SetText("|TInterface\\Buttons\\UI-CheckBox-Check:14|t")
            b.canvas = ns.SettingsPreview.Create(b, 100, 65)
            b.canvas.frame:SetPoint("TOPLEFT", 6, -6)
            b:SetScript("OnEnter", function(self)
                self.hovered = true
                if self.Paint then self:Paint() end
                if f.row then ShowRowPreview(f.row, self.value) end
            end)
            b:SetScript("OnLeave", function(self)
                self.hovered = nil
                if self.Paint then self:Paint() end
                if f.row then ShowRowPreview(f.row) end
            end)
            function b:Paint()
                local c = ns.BORDER_COLOR
                if self.selected then
                    self:SetBackdropBorderColor(1, 0.84, 0.5, 1)
                    self.plate:SetVertexColor(0.55, 0.49, 0.41)
                elseif self.hovered then
                    self:SetBackdropBorderColor(c.r * 1.2, c.g * 1.2, c.b * 1.2, 1)
                    self.plate:SetVertexColor(0.42, 0.39, 0.36)
                else
                    self:SetBackdropBorderColor(c.r * 0.8, c.g * 0.8, c.b * 0.8, 1)
                    self.plate:SetVertexColor(0.30, 0.28, 0.26)
                end
                self.label:SetTextColor(self.selected and 1 or 0.85, self.selected and 0.89 or 0.79, self.selected and 0.63 or 0.66)
            end
            b:SetScript("OnClick", function(self)
                if f.row and not f.row:IsDisabled() then ns.ButtonSound(); f.row:Set(self.value) end
            end)
            f.cards[i] = b
        end
        b.value = choice.value
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", startX + (i - 1) * (width + gap), -top)
        b:SetSize(width, cardHeight)
        b.label:SetText(choice.text)
        b.canvas.width, b.canvas.height = width - 12, previewHeight
        b.canvas.isStyleCard = true
        b.canvas.frame:SetSize(width - 12, previewHeight)
        ns.SettingsPreview.Style(b.canvas, row, choice.value)
        local selected = row:Get() == choice.value
        b.selected = selected
        b:Paint()
        b.tick:SetShown(selected)
        b:SetEnabled(not row:IsDisabled()); b:SetAlpha(row:IsDisabled() and 0.45 or 1)
        b:Show()
    end
    for i = #choices + 1, #f.cards do f.cards[i]:Hide() end
end

-- dropdown (long lists). row.sideButtons = { left = def, right = def } puts buttons beside it,
-- def = { text, width, onClick(button), disabled() }
local function SideButton(f, side)
    local key = side .. "Button"
    if not f[key] then
        local b = PanelButton(f)
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
    -- (11-13, Marcus) Blizzard's own box, as the choice steppers' (WowStyle2), unskinned
    local dd = CreateFrame("DropdownButton", nil, f, "WowStyle2DropdownTemplate")
    dd:SetWidth(234)
    dd:SetPoint("RIGHT", -4, 0)
    ForwardHover(dd, f)
    f.control = dd
    SetupChoiceMenu(dd, f)
end
local function PlaceSideButtons(f, row)
    local sides = row.sideButtons or {}
    local dd = f.control
    dd:ClearAllPoints()
    -- (11-13, Marcus) as wide as a choice stepper with its arrows (box 180 + two arrow buttons), and its
    -- right edge where theirs is; half rows as a half stepper
    dd:SetWidth(row.dropdownWidth or (row.half and 150 or 234))
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
        dd:SetPoint("RIGHT", -6, 0)
    end
    if sides.left then f.leftButton:SetPoint("RIGHT", dd, "LEFT", -8, 0) end
end
Fill.dropdown = function(f, row)
    PlaceSideButtons(f, row)
    f.control:GenerateMenu()
end

local ButtonWidthForText = S.ButtonWidthForText

-- button
Build.button = function(f)
    local b = PanelButton(f)
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
-- without row.buttonText the label becomes the button text
Fill.button = function(f, row)
    f.control:ClearAllPoints()
    if row.center then
        -- centred alone on the line
        f.control:SetPoint("CENTER")
        f.control:SetWidth(row.buttonWidth or 260)
        f.control:SetText(row.buttonText or row:Label())
        f.label:SetText("")
        f:SetHeight(ROW_H + 10)
        return
    end
    f.control:SetPoint("RIGHT", -4, 0)
    local width = row.buttonWidth or 200
    f.control:SetWidth(width)
    if row.buttonText then
        f.control:SetText(row.buttonText)
    else
        f.control:SetText(row:Label())
        f.label:SetText("")
    end
    if row.fitButtonText then
        -- Leave room for the status label to the left.
        local maxWidth = math.max(width, f:GetWidth() - 120)
        f.control:SetWidth(math.min(ButtonWidthForText(f.control, width), maxWidth))
    end
end

-- Click, then press a key (with modifiers); Escape cancels, right-click clears (onSet gets "")
local MOD_KEYS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, LMETA = true, RMETA = true }
local MOUSE_KEYS = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }

-- Controller buttons: with keyboard and mouse, a pad button is a key like any other (with Shift,
-- Ctrl or Alt held, or the pad's own emulated ones). In the Gamepad UI the game's controller bar owns
-- the pad, so only a button of the kind the row asks for counts there (padMode, the radials):
--   "stick": L3 or R3, alone or with LT, RT or both held (ns.PadComboKey)
--   "bar":   a face button or D-pad direction, alone or with LT, RT or both (ns.PadBarKey)
-- B alone cancels; LB / RB (the targeting) and other buttons are refused with a message.
local PAD_CANCEL_KEY = GAMEPAD_FACE_RIGHT or "PAD2"
local PAD_STICKS = { PADLSTICK = "L3", PADRSTICK = "R3" }
local PAD_BAR_BUTTONS = { PAD1 = true, PAD2 = true, PAD3 = true, PAD4 = true,
                          PADDUP = true, PADDDOWN = true, PADDLEFT = true, PADDRIGHT = true }

-- the buttons the pad uses as Shift, Ctrl and Alt outside the Gamepad UI: never a key of their own
local EMULATE_CVARS = { "GamePadEmulateShift", "GamePadEmulateCtrl", "GamePadEmulateAlt" }
local function EmulatedModifier(button)
    for _, cvar in ipairs(EMULATE_CVARS) do
        if GetCVar(cvar) == button then return true end
    end
    return false
end

-- onCancel: what a cancelled capture does (Escape, right-click, a second click); a full page refresh
-- when not given. padMode: in the Gamepad UI, take stick presses ("stick") or bar slots ("bar").
function Panel.KeyButton(parent, onSet, onCancel, padMode)
    local b = CreateFrame("Button", nil, parent, "UIMenuButtonStretchTemplate")
    b:SetSize(170, 24)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local held = {}
    local function Stop()
        if ns.keyCapturing == b then ns.keyCapturing = nil end
        b.waiting = nil
        b:EnableKeyboard(false)
        if b.EnableGamePadButton then b:EnableGamePadButton(false) end
        wipe(held)
        b:UnlockHighlight()
    end
    local function Finish(key)
        local mods = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "")
        Stop()
        onSet(mods .. key)
    end
    local function Cancel()
        Stop()
        if onCancel then onCancel(b) else Panel:Refresh() end
    end
    b:SetScript("OnClick", function(self, mouse)
        if mouse == "RightButton" then
            if self.waiting then Cancel() else onSet("") end
            return
        end
        if self.waiting then Cancel() return end
        self.waiting = true
        self:SetText(L["Press a key"])
        self:LockHighlight()
        self:EnableKeyboard(true)
        if self.SetPropagateKeyboardInput and not InCombatLockdown() then self:SetPropagateKeyboardInput(false) end
        if self.EnableGamePadButton then self:EnableGamePadButton(true) end
        -- the controller navigation waits while a key is being taken (PadNav.lua)
        ns.keyCapturing = self
    end)
    b:SetScript("OnKeyDown", function(self, key)
        if not self.waiting or MOD_KEYS[key] then return end
        if key == "ESCAPE" then Cancel() return end
        Finish(key)
    end)
    b:SetScript("OnGamePadButtonDown", function(self, button)
        if not self.waiting then return end
        held[button] = true
        if not ns.IsGamepadUI() then
            if button == PAD_CANCEL_KEY then Cancel() return end
            if not EmulatedModifier(button) then Finish(button) end
            return
        end
        local lt, rt = ns.PadTriggerKey("LT"), ns.PadTriggerKey("RT")
        if button == lt or button == rt then return end   -- a trigger alone: keep listening
        local function Down(key) return held[key] or IsKeyDown(key) end
        local l, r = Down(lt), Down(rt)
        -- B alone cancels (with a trigger held it is a bar slot)
        if button == PAD_CANCEL_KEY and not (l or r) then Cancel() return end
        local stick = padMode == "stick" and PAD_STICKS[button]
        local slot = padMode == "bar" and PAD_BAR_BUTTONS[button]
        local refusal
        if Down(GAMEPAD_SHOULDER_LEFT or "PADLSHOULDER") or Down(GAMEPAD_SHOULDER_RIGHT or "PADRSHOULDER") then
            refusal = L["LB and RB are for targeting. Hold LT, RT or both instead."]
        elseif padMode == "stick" and not stick then
            refusal = L["Press L3 or R3, alone or with LT, RT or both held."]
        elseif padMode == "bar" and not slot then
            refusal = L["Press A, B, X, Y or a D-pad direction, alone or with LT, RT or both held."]
        elseif not padMode then
            refusal = L["In Gamepad mode the controller's buttons belong to its action bar."]
        end
        if refusal then
            if UIErrorsFrame then UIErrorsFrame:AddMessage(refusal, 1, 0.25, 0.25) end
            return
        end
        local side = (l and r and "LTRT") or (l and "LT") or (r and "RT") or "TOP"
        Stop()
        onSet(stick and ns.PadComboKey(stick, side) or ns.PadBarKey(side, button))
    end)
    b:SetScript("OnGamePadButtonUp", function(_, button) held[button] = nil end)
    b:SetScript("OnMouseDown", function(self, mouse)
        if self.waiting and MOUSE_KEYS[mouse] then Finish(MOUSE_KEYS[mouse]) end
    end)
    b:SetScript("OnHide", Stop)
    function b:ShowKey(key)
        if key and key ~= "" then
            self:SetText(ns.KeyText(key))
        else
            self:SetText("|cff808080" .. (NOT_BOUND or L["Not bound"]) .. "|r")
        end
    end
    return b
end

-- keybind: get() returns the key ("" for none)
Build.keybind = function(f)
    f.control = Panel.KeyButton(f, function(key) f.row:Set(key) end)
    f.control:SetPoint("RIGHT", -4, 0)
    ForwardHover(f.control, f)
end
Fill.keybind = function(f, row)
    if not f.control.waiting then f.control:ShowKey(row:Get()) end
end

local BUTTON_HEIGHT, BUTTON_GAP = 22, 6

local function FitButtonGroup(f, groupWidth, count)
    local widths, total, widest = {}, 0, 0
    for i = 1, count do
        local width = ButtonWidthForText(f.buttons[i], 40)
        widths[i], total, widest = width, total + width, math.max(widest, width)
    end

    local available = groupWidth - BUTTON_GAP * (count - 1)
    if widest <= available / count then return end

    local split = total > available
    local perRow = split and math.ceil(count / 2) or count
    local rowStep = BUTTON_HEIGHT + BUTTON_GAP
    if split then f:SetHeight(f:GetHeight() + rowStep) end

    for first = 1, count, perRow do
        local last = math.min(first + perRow - 1, count)
        local slots = last - first + 1
        local lineWidth = groupWidth - BUTTON_GAP * (slots - 1)
        local equalWidth = lineWidth / slots
        local needed, largest = 0, 0
        for i = first, last do
            needed = needed + widths[i]
            largest = math.max(largest, widths[i])
        end
        local extra = (lineWidth - needed) / slots
        local redistribute = largest > equalWidth and extra >= 0
        local y = split and (first == 1 and rowStep / 2 or -rowStep / 2) or 0
        local previous
        for i = last, first, -1 do
            local button = f.buttons[i]
            button:SetWidth(redistribute and widths[i] + extra or equalWidth)
            button:ClearAllPoints()
            button:SetPoint("RIGHT", previous or f, previous and "LEFT" or "RIGHT", previous and -BUTTON_GAP or -4, previous and 0 or y)
            previous = button
        end
    end
end

-- buttons: row.buttons = { { text, width, onClick(button), disabled() } }, right-aligned
-- row.fitButtonsWidth keeps the group within a shared column, with two rows if needed
Build.buttons = function(f)
    f.buttons = {}
end
Fill.buttons = function(f, row)
    local previous
    local defs = row.buttons or {}
    for n = #defs, 1, -1 do
        local i, def = n, defs[n]
        local b = f.buttons[i]
        if not b then
            b = PanelButton(f)
            b:SetHeight(BUTTON_HEIGHT)
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
        b:SetPoint("RIGHT", previous or f, previous and "LEFT" or "RIGHT", previous and -BUTTON_GAP or -4, 0)
        b:SetEnabled(not (def.disabled and def.disabled()))
        b:Show()
        previous = b
    end
    for i = #defs + 1, #f.buttons do f.buttons[i]:Hide() end
    if row.fitButtonsWidth and #defs > 1 then FitButtonGroup(f, row.fitButtonsWidth, #defs) end
    -- centre = true: the group centred on the line; buttonGap widens the space between them
    if row.center or row.buttonGap then
        local gap, total = row.buttonGap or BUTTON_GAP, 0
        for i = 1, #defs do total = total + f.buttons[i]:GetWidth() end
        total = total + gap * (#defs - 1)
        local x = row.center and -total / 2 or nil
        for i = 1, #defs do
            local b = f.buttons[i]
            b:ClearAllPoints()
            if i == 1 then
                if x then b:SetPoint("LEFT", f, "CENTER", x, 0) else b:SetPoint("RIGHT", f, "RIGHT", -4 - (total - b:GetWidth()), 0) end
            else
                b:SetPoint("LEFT", f.buttons[i - 1], "RIGHT", gap, 0)
            end
        end
    end
end

-- Edit button, greyed in combat
local function EditButton(f, onClick)
    local b = CreateFrame("Button", nil, f)
    -- the panel buttons' look: Blizzard's grey face with the bronze rim (11-13)
    GreyFace(b)
    local label = Text(b, "FlareUI_PanelButton", "CENTER")   -- the titles' gold, like the panel buttons
    label:SetAllPoints(); b:SetFontString(label)
    b:HookScript("OnDisable", function(self) self:SetAlpha(0.4) end)   -- (hooked: GreyFace paints on these too)
    b:HookScript("OnEnable", function(self) self:SetAlpha(1) end)
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
            GameTooltip:SetText(ns.IsGamepadUI() and L["In Gamepad mode, open Edit Mode from the game menu."]
                or L["Edit Mode can't open in combat."], 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    b:HookScript("OnLeave", function() GameTooltip:Hide() end)
    ForwardHover(b, f)
    return b
end

-- frame: a switch and Edit
Build.frame = function(f)
    f.edit = EditButton(f, function(row) S:EditFrame(row.frame and row.frame(), row.module) end)
    f.edit:SetPoint("RIGHT", -4, 0)
    Build.toggle(f)
    f.control:ClearAllPoints()
    f.control:SetPoint("RIGHT", f.edit, "LEFT", -8, 0)
end
Fill.frame = function(f, row)
    f.edit:SetWidth(ButtonWidthForText(f.edit, row.half and 60 or 80))
    f.control:SetChecked(row:Get() and true or false)
    f.edit:SetEnabled(S:CanEditFrames() and row:Get() and row.frame and row.frame() ~= nil or false)
end

-- legend: a short block of lines under its label (row.lines() returns them), such as which
-- controller button does what; nothing to set
Build.legend = function(f)
    f.lines = Text(f, "GameFontHighlightSmall")
    f.lines:SetPoint("TOPLEFT", 18, -26)
    f.lines:SetPoint("RIGHT", -6, 0)
    f.lines:SetJustifyH("LEFT")
    f.lines:SetSpacing(4)
end
Fill.legend = function(f, row)
    -- in search results the path sits above the label
    local top = (f.crumb:GetText() or "") ~= "" and 18 or 6
    f.label:ClearAllPoints()
    f.label:SetPoint("TOPLEFT", 6, -top)
    f.lines:SetPoint("TOPLEFT", 18, -top - 20)
    local lines = row.lines and row.lines() or {}
    f.lines:SetText(table.concat(lines, "\n"))
    f:SetHeight(top + 26 + f.lines:GetStringHeight())
end

-- expander: a heading that opens and closes the rows under it
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

-- editmode: an Edit Mode setting found by search
Build.editmode = function(f)
    f.edit = EditButton(f, function(row)
        if row.frame then S:EditFrame(row.frame, row.module) else S:OpenEditMode(row.module) end
    end)
    f.edit:SetPoint("RIGHT", -4, 0)
end
Fill.editmode = function(f, row)
    f.edit:SetEnabled(S:CanEditFrames() and true or false)
end

local function SetRowEnabled(f, enabled)
    -- expanders are gold, like section titles
    -- (11-13) labels in full white (TEXT_WHITE)
    if enabled and f.kind ~= "expander" then
        f.label:SetTextColor(TEXT_WHITE[1], TEXT_WHITE[2], TEXT_WHITE[3])
    else
        local color = enabled and NORMAL_FONT_COLOR or GRAY_FONT_COLOR
        f.label:SetTextColor(color:GetRGB())
    end
    -- the Edit button is set by Fill (combat and frame), not by the row
    local control = f.control
    if control and control.SetEnabled then control:SetEnabled(enabled) end
end

local function RowLabelSpace(f, row)
    if row.kind == "styles" then return f:GetWidth() - 24 end
    -- Use the first visible control, not the width of its container.
    local control = f.control or f.edit
    if f.stepper then
        control = f.stepper.DecrementButton
    elseif row.kind == "dropdown" and row.sideButtons and row.sideButtons.left then
        control = f.leftButton
    elseif row.kind == "buttons" and row.buttons and #row.buttons > 0 then
        control = f.buttons[1]
    elseif row.kind == "expander" then
        control = f.control.sign
    end
    local left = f:GetLeft()
    local right = control and control:GetLeft() or f:GetRight()
    local width = left and right and right - left or f:GetWidth()
    return math.max(1, width - 12)
end

local function FillRow(f, row, crumb)
    f.row = row
    f.label:SetText(row:Label() or "")
    f.crumb:SetText(crumb or "")
    f.crumb:SetTextColor(GRAY_FONT_COLOR:GetRGB())
    f.crumbLink:SetShown(crumb ~= nil)
    f:SetHeight(crumb and ROW_H + 12 or ROW_H)
    f.plate:SetShown(PLATED[row.kind] and true or false)
    if f.flashAnim then f.flashAnim:Stop() end
    if Fill[row.kind] then Fill[row.kind](f, row) end
    SetRowEnabled(f, not row:IsDisabled())
    local isNew = row:IsNew()
    local space = RowLabelSpace(f, row)
    local labelWidth = math.max(1, space - (isNew and NEW_W + NEW_GAP or 0))
    f.label:SetWidth(labelWidth)
    local padding = 6
    if crumb then
        f.crumb:SetWidth(space)
        -- The crumb sits above the vertically centered label.
        padding = math.max(padding, 2 * (math.ceil(f.crumb:GetStringHeight()) + 2))
    end
    local height = math.ceil(f.label:GetStringHeight()) + padding
    f:SetHeight(math.max(f:GetHeight(), height))
    -- Blizzard's NEW label after the name (Settings.NEW)
    if isNew then
        if not f.newBadge then f.newBadge = NewBadge(f) end
        local x = math.min(f.label:GetStringWidth(), labelWidth) + NEW_GAP
        f.newBadge:ClearAllPoints()
        f.newBadge:SetPoint("LEFT", f.label, "LEFT", x / NEW_SCALE, 0)
        f.newBadge:Show()
    elseif f.newBadge then
        f.newBadge:Hide()
    end
end

-- A gold flash over a row that was jumped to: in, dip, in again, then a slow fade
local FLASH_STEPS = { { 0, 1, 0.15 }, { 1, 0.15, 0.35 }, { 0.15, 1, 0.15 }, { 1, 0, 0.8 } }
local function FlashRow(f)
    if not f.flashAnim then
        f.flash = f:CreateTexture(nil, "BACKGROUND", nil, 1)
        f.flash:SetAllPoints()
        f.flash:SetColorTexture(1, 0.72, 0.12, 0.3)
        f.flash:SetAlpha(0)
        f.flashAnim = f.flash:CreateAnimationGroup()
        for i, step in ipairs(FLASH_STEPS) do
            local a = f.flashAnim:CreateAnimation("Alpha")
            a:SetFromAlpha(step[1])
            a:SetToAlpha(step[2])
            a:SetDuration(step[3])
            a:SetOrder(i)
        end
    end
    f.flashAnim:Stop()
    f.flashAnim:Play()
end

--------------------------------------------------
-- 4. MIDDLE COLUMN
--------------------------------------------------
local page = {}

-- clicking a section heading folds it; kept for the session
local closedSections = {}   -- section key -> true

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
        h.text = Text(h, "GameFontNormalLarge")
        h.text:SetPoint("BOTTOMLEFT", 6, 8)
        h.text:SetTextColor(TITLE_YELLOW[1], TITLE_YELLOW[2], TITLE_YELLOW[3])
        h.sign = Text(h, "GameFontNormal")
        h.sign:SetPoint("BOTTOMRIGHT", -10, 6)
        h.reset = CreateFrame("Button", nil, h)
        h.reset:SetPoint("BOTTOMRIGHT", -30, 6)
        h.reset.label = Text(h.reset, "GameFontNormalSmall", "RIGHT")
        h.reset.label:SetPoint("RIGHT")
        h.reset.label:SetText(L["Reset"])
        h.reset:SetSize(math.ceil(h.reset.label:GetStringWidth() or 30) + 6, 18)
        h.reset:SetMotionScriptsWhileDisabled(true)
        function h.reset:Paint()
            if not self:IsEnabled() then self.label:SetTextColor(0.43, 0.40, 0.34)
            elseif self.hovered then self.label:SetTextColor(1, 1, 1)
            else self.label:SetTextColor(TITLE_YELLOW[1], TITLE_YELLOW[2], TITLE_YELLOW[3]) end   -- (as its header, 11-13)
        end
        h.reset:SetScript("OnEnter", function(self) self.hovered = true self:Paint() end)
        h.reset:SetScript("OnLeave", function(self) self.hovered = nil self:Paint() end)
        -- asks first: a section can hold many options
        h.reset:SetScript("OnClick", function(self)
            local owner = self:GetParent()
            ns.ShowDialog("FLAREUI_RESET_SECTION", owner.text:GetText() or "",
                { module = current, section = owner.sectionKey, tab = owner.resetTab })
        end)
        h.text:SetPoint("RIGHT", h.reset, "LEFT", -8, 0)
        h.line = Line(h)
        h.line:SetPoint("BOTTOMLEFT", 0, 2)
        h.line:SetPoint("BOTTOMRIGHT", 0, 2)
        h:EnableMouse(true)
        -- (11-13, Marcus: "headers should not have highlights on hover") no light; the click still folds it
        h:SetScript("OnMouseUp", SectionClick)
    end
    h:SetParent(parent)
    h.sectionKey = sectionKey
    local active = S.modules[current] and Panel:ActiveTab(S.modules[current])
    h.resetTab = active and active.key
    -- (pages marked noReset have none: Profiles, Settings)
    h.reset:SetShown(sectionKey ~= nil and not (S.modules[current] and S.modules[current].noReset))
    h.reset:SetEnabled(sectionKey and S:CanResetSection(current, sectionKey, h.resetTab) or false)
    h.reset:Paint()
    h.sign:SetText(sectionKey and (closedSections[sectionKey] and "+" or "-") or "")
    h.text:SetText(text)
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", rowInset, y)
    h:SetWidth(CONTENT_W - 2 * rowInset)
    FitText(h.text, CONTENT_W - 2 * rowInset - 6 - (h.reset:IsShown() and (h.reset:GetWidth() + 38) or 30), 1)
    h:Show()
    used[#used + 1] = h
    return SECTION_H
end

-- A red line: these settings do nothing in Gamepad mode (11-13, Marcus); returns its height
local function GamepadNote(parent, y)
    local key = "padnote"
    pools[key] = pools[key] or {}
    local n = table.remove(pools[key])
    if not n then
        n = CreateFrame("Frame", nil, parent)
        n.kind = key
        n.text = Text(n, "GameFontHighlightSmall")
        n.text:SetPoint("TOPLEFT", 6, 0)
        n.text:SetTextColor(1, 0.25, 0.2)
        n.text:SetWordWrap(true)
    end
    n:SetParent(parent)
    n:ClearAllPoints()
    n:SetPoint("TOPLEFT", rowInset, y)
    local width = CONTENT_W - 2 * rowInset - 12
    n:SetWidth(width)
    n.text:SetWidth(width)
    n.text:SetText(L["These settings are disabled in Gamepad mode due to Blizzard restrictions."])
    local h = math.ceil(n.text:GetStringHeight() or 14) + 8
    n:SetHeight(h)
    n:Show()
    used[#used + 1] = n
    return h
end

-- lays rows out from y down and returns the new y; half rows pair up except in search results.
-- row.gapAbove: extra space over a full-width row (not in search results)
-- a section's box: from its heading to its last row, under both (Thin edge, darker than the page)
local function SectionBox(parent, top, bottom)
    local key = "secbox"
    pools[key] = pools[key] or {}
    local b = table.remove(pools[key])
    if not b then
        b = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        b.kind = key
        Box(b, 0.25)
    end
    b:SetParent(parent)
    b:SetFrameLevel(parent:GetFrameLevel())
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", 0, top)
    b:SetSize(CONTENT_W, math.max(1, top - bottom))
    b:Show()
    used[#used + 1] = b
end

local function PlaceRows(parent, rows, y, crumbOf)
    local firstHalf
    for _, row in ipairs(rows) do
        local f = Acquire(parent, row.kind)
        f:ClearAllPoints()
        local width = CONTENT_W - 2 * rowInset
        if row.half and not crumbOf then
            local col = firstHalf and 1 or 0
            -- a half row keeps to its column even under a parent (the parent still greys it)
            local w = math.floor((width - HALF_GAP) / 2)
            f:SetPoint("TOPLEFT", rowInset + col * (w + HALF_GAP), y)
            f:SetWidth(w)
            FillRow(f, row)
            if row == page.jumpRow then page.jumpFrame, page.jumpTop = f, -y end
            if firstHalf then
                local height = math.max(firstHalf:GetHeight(), f:GetHeight())
                firstHalf:SetHeight(height)
                f:SetHeight(height)
                y = y - height - ROW_GAP
                firstHalf = nil
            else
                firstHalf = f
            end
        else
            if firstHalf then
                y = y - firstHalf:GetHeight() - ROW_GAP
                firstHalf = nil
            end
            if row.gapAbove and not crumbOf then y = y - row.gapAbove end
            local indent = row.parent and INDENT or 0
            f:SetPoint("TOPLEFT", rowInset + indent, y)
            f:SetWidth(width - indent)
            FillRow(f, row, crumbOf and crumbOf(row))
            if row == page.jumpRow and not crumbOf then page.jumpFrame, page.jumpTop = f, -y end
            y = y - f:GetHeight() - ROW_GAP
        end
    end
    if firstHalf then y = y - firstHalf:GetHeight() - ROW_GAP end
    return y
end

-- 11-11 (Marcus): the pages' icons as Blizzard's own, in the round aura look (the talent node mask and
-- ring, tinted bronze, as Auras.lua's round style); /fui icons switches back to the line icons
local GAME_ICONS = {
    about = "INV_Misc_Book_09", adv = "INV_Scroll_03", language = "Trade_Engineering",
    ab = "INV_Sword_04", uf = "INV_Misc_Head_Human_01", rb = "INV_Potion_54", au = "Spell_Holy_WordFortitude",
    mm = "INV_Misc_Map_01", qt = "INV_Misc_Note_06",
    ch = "INV_Letter_15", dm = "Ability_DualWield", tt = "INV_Misc_Spyglass_03", rm = "INV_Misc_Orb_05", qol = "INV_Misc_Wrench_01",
    bl = "INV_Misc_Bag_08",   -- (Quality of Life's bag went to Bags & Looting, 11-12)
    br = "INV_Misc_PocketWatch_01",   -- Buff Reminders, its own page (11-12)
}
local RING_MASK, RING_ART, RING_TINT = "talents-node-circle-mask", "talents-node-circle-gray", { 0.72, 0.56, 0.38 }
local function GameIcons()
    -- (the look tests' saved switch, 11-11, retired)
    if ns.db and ns.db.global then ns.db.global.panelLineIcons = nil end
    return true
end
-- an icon texture in the round look: masked to the circle, the ring over it (made once per texture)
local function RingIcon(tex, parent)
    if not tex.ftRingMask then
        tex.ftRingMask = parent:CreateMaskTexture()
        tex.ftRingMask:SetAtlas(RING_MASK, TextureKitConstants and TextureKitConstants.IgnoreAtlasSize)
        tex.ftRingMask:SetAllPoints(tex)
        tex:AddMaskTexture(tex.ftRingMask)
        tex.ftRing = parent:CreateTexture(nil, "OVERLAY")
        tex.ftRing:SetAtlas(RING_ART, TextureKitConstants and TextureKitConstants.IgnoreAtlasSize)
        tex.ftRing:SetAllPoints(tex)
        tex.ftRing:SetVertexColor(RING_TINT[1], RING_TINT[2], RING_TINT[3])
    end
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    tex.ftRing:Show()
end
-- a module's game icon in the round aura look, size x size, on parent (the tour's summary)
Panel.ModuleIcon = function(parent, key, size)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetSize(size, size)
    tex:SetTexture("Interface\\Icons\\" .. (GAME_ICONS[key] or "INV_Misc_QuestionMark"))
    RingIcon(tex, parent)
    return tex
end


local function UpdateHeader(module)
    page.title:SetText(module:Title())
    page.desc:SetText(module:Description() or "")
    page.plateIcon:SetTexture(module.navIcon or LOGO)
    if module.navIconTint then page.plateIcon:SetVertexColor(1, 0.83, 0.47) else page.plateIcon:SetVertexColor(1, 1, 1) end
    -- the game's icons: round and ringed on a plate of their own size, the square plate's edge hidden
    local ring = module.navIconRound == "ring"
    if ring then
        page.plateIcon:SetSize(40, 40)
        RingIcon(page.plateIcon, page.plateIcon:GetParent())
        page.plateIcon:GetParent():SetBackdropBorderColor(0, 0, 0, 0)
        page.plateIcon:GetParent():SetBackdropColor(0, 0, 0, 0)
    else
        page.plateIcon:SetSize(26, 26)
        page.plateIcon:SetTexCoord(0, 1, 0, 1)
        if page.plateIcon.ftRing then page.plateIcon.ftRing:Hide() end
        page.plateIcon:GetParent():SetBackdropBorderColor(EDGE_HOVER[1], EDGE_HOVER[2], EDGE_HOVER[3], 1)
        page.plateIcon:GetParent():SetBackdropColor(0.13, 0.095, 0.055, 1)
    end
    local hasSwitch = module.enabled ~= nil
    page.switch:SetShown(hasSwitch)
    page.switch:SetChecked(module:IsOn())
    local editText = module.editMode and module:IsOn() and S:ModuleText(module.key, "editButton")
    local customText, customClick
    if module.headerButton then customText, customClick = module.headerButton() end
    page.editMode.customClick = customClick
    page.editMode:SetShown((customText or editText) and true or false)
    local rightInset = 4
    if customText or editText then
        page.editMode:SetText(customText or editText)
        page.editMode:SetWidth(ButtonWidthForText(page.editMode, 0, 30))
        page.editMode:SetEnabled(customText ~= nil or (S:CanEditFrames() and true or false))
        rightInset = page.editMode:GetWidth() + 8
    end
    -- icon plate, the title with the module's switch after it, the description under both
    local room = math.max(1, (page.header:GetWidth() or CONTENT_W) - 54 - rightInset - (hasSwitch and page.switch:GetWidth() + 8 or 0))
    page.title:SetWidth(0)
    if page.title:GetUnboundedStringWidth() > room then page.title:SetWidth(room) end
    page.desc:SetPoint("RIGHT", page.header, "RIGHT", -rightInset, 0)
    page.banner:Hide()
    local textH = math.ceil((page.title:GetStringHeight() or 22) + 4 + (page.desc:GetStringHeight() or 0))
    local height = math.max(52, textH + 10)
    if module.banner and module:IsOn() then
        local text, button, onClick = module.banner()
        if text then
            page.banner.text:SetText(text)
            page.banner.button:SetText(button or "")
            page.banner.button:SetShown(button ~= nil)
            page.banner.onClick = onClick
            page.banner.button:SetEnabled(not module.bannerEditMode or S:CanEditFrames() and true or false)
            local buttonWidth = 0
            if button then
                buttonWidth = ButtonWidthForText(page.banner.button, 110)
                page.banner.button:SetWidth(buttonWidth)
            end
            page.banner.text:SetWidth(CONTENT_W - buttonWidth - 24)
            -- a longer text wraps, and the banner grows with it
            local bannerHeight = math.max(30, math.ceil(page.banner.text:GetStringHeight()) + 12)
            page.banner:SetHeight(bannerHeight)
            page.banner:ClearAllPoints()
            page.banner:SetPoint("TOPLEFT", page.header, "TOPLEFT", 0, -height)
            page.banner:SetPoint("RIGHT", page.header, "RIGHT")
            page.banner:Show()
            height = height + bannerHeight + 6
        end
    end
    -- tabs along the bottom of the header
    local names = module.tabs and S:ModuleText(module.key, "tabs") or {}
    local active = Panel:ActiveTab(module)
    -- the row must fit the page: each tab is its name and some padding; too wide, the padding shrinks
    -- (down to TAB_PAD_MIN). A tab's NEW badge sits on its top edge, centred, over the border (11-11
    -- Marcus: beside the name it looked bad), so it takes no width.
    local TAB_PAD, TAB_PAD_MIN, TAB_GAP, TAB_LEFT = 28, 12, 4, 4   -- (TAB_LEFT: the first tab sits 4 in, 11-13)
    local shown, textW, isNew = {}, {}, {}
    for i, b in ipairs(page.tabButtons) do
        local tab = module.tabs and module:IsOn() and module.tabs[i]
        b:SetShown(tab and true or false)
        if tab then
            b.tabKey = tab.key
            b.Text:SetText(tab.label or names[i] or tab.key)
            shown[#shown + 1] = i
            textW[i] = b.Text:GetStringWidth() or 60
            isNew[i] = module:HasNew(tab.key) and true or false
            if b.SetSelected then b:SetSelected(tab == active) end
        end
    end
    local room = (page.header:GetWidth() or 0) > 0 and page.header:GetWidth() or CONTENT_W
    local function RowWidth(pad, badges)
        local w = TAB_LEFT + TAB_GAP * math.max(0, #shown - 1)
        for _, i in ipairs(shown) do w = w + textW[i] + pad end
        return w
    end
    local pad = TAB_PAD
    if RowWidth(pad) > room and #shown > 0 then
        pad = math.max(TAB_PAD_MIN, TAB_PAD - (RowWidth(TAB_PAD) - room) / #shown)
    end
    for _, i in ipairs(shown) do
        local b = page.tabButtons[i]
        local new = isNew[i]
        if new and not b.newBadge then b.newBadge = NewBadge(b) end
        if b.newBadge then
            if new then
                -- centred on the top edge, over the tab's border (offsets in the badge's own scale)
                local badge = b.newBadge
                badge:SetFrameLevel(b:GetFrameLevel() + 20)
                badge:ClearAllPoints()
                badge:SetPoint("LEFT", b, "TOP", -(badge.Label:GetStringWidth() or 0) / 2, 1 / NEW_SCALE)
            end
            b.newBadge:SetShown(new)
        end
        b:SetWidth(textW[i] + pad)
    end
    local tabbed = module.tabs and module:IsOn()
    page.tabLine:SetShown(false)   -- (11-11 Marcus: no line between the tabs and the boxes)
    if tabbed then height = height + 32 end
    page.header:SetHeight(height)
end

-- the last tab picked, or the first
function Panel:ActiveTab(module)
    if not module.tabs then return nil end
    local key = currentTab[module.key]
    for _, tab in ipairs(module.tabs) do
        if tab.key == key then return tab end
    end
    return module.tabs[1]
end

-- A wide custom tab (tab.wide) grows the window by WIDE_EXTRA, about its centre; the middle column
-- gets all of it, the right column keeps its place
local WIDE_EXTRA = 150
local function SetWide(wide)
    if not page.right or (page.wide or false) == wide then return end
    page.wide = wide
    local x, y = frame:GetCenter()
    frame:SetWidth(WIDTH + (wide and WIDE_EXTRA or 0))
    if x then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    end
    if Panel.OnResize then Panel.OnResize() end
end
Panel.WIDE_W = MIDDLE_W + WIDE_EXTRA   -- a wide tab's middle width
Panel.MIDDLE_W = MIDDLE_W              -- a custom tab's middle width
Panel.RIGHT_W, Panel.PAD = RIGHT_W, PAD

local function HideCustom()
    for _, host in pairs(customHosts) do host:Hide() end
    if preview.host then preview.host:Hide() end
    for _, region in ipairs({ preview.picture, preview.title, preview.desc, preview.tip }) do region:Show() end
end

-- a custom tab draws once into its own frame below the header; tab.preview also takes the right column
local function ShowCustom(module, tab)
    local id = module.key .. "." .. tab.key
    local host = customHosts[id]
    if not host then
        host = CreateFrame("Frame", nil, page.root)
        host:SetPoint("TOPLEFT", page.header, "BOTTOMLEFT", 0, -14)
        host:SetPoint("BOTTOMRIGHT", page.root, "BOTTOMRIGHT", 0, 0)
        customHosts[id] = host
        tab.custom(host, preview.host)
    end
    host:Show()
    if tab.preview then
        if preview.canvas then preview.canvas:Reset(); preview.canvas.frame:Hide() end
        previewRow = nil
        if preview.pause then preview.pause:Hide() end
        for _, region in ipairs({ preview.picture, preview.title, preview.desc, preview.tip }) do region:Hide() end
        preview.host:Show()
    end
    if tab.refresh then tab.refresh(host, preview.host) end
end

local UpdateNav
local newVisit      -- the page and tab whose NEW badges are showing

function Panel:Refresh()
    if not frame or not frame:IsShown() or self.opening then return end
    preview.dirty = true
    ReleaseAll()
    HideCustom()
    ShowModulePreview()
    -- only a wide custom tab, shown (not search results or a module that is off), widens the window
    do
        local module = searchText == "" and S.modules[current]
        local tab = module and not (module.enabled and not module:IsOn()) and self:ActiveTab(module)
        SetWide(tab and tab.wide and true or false)
    end
    page.offCard:Hide()
    page.scroll:Show()
    local content = page.content
    content:SetWidth(CONTENT_W)
    local y = 0
    if searchText ~= "" then
        S:EndNewVisit()
        newVisit = nil
        page.header:Hide()
        page.scroll:SetPoint("TOPLEFT", page.root, "TOPLEFT", 0, 0)
        local results = S:Search(searchText)
        -- a word of one or two letters matches most rows: the first ones are shown
        local MAX_RESULTS = 60
        local found = #results
        for i = #results, MAX_RESULTS + 1, -1 do results[i] = nil end
        -- how many matched (11-11); Enter goes to the first
        page.searchTitle:SetText(L["%d found for \"%s\""]:format(found, searchText)
            .. (found > MAX_RESULTS and ("  " .. GRAY_FONT_COLOR:WrapTextInColorCode(L["(first %d shown)"]:format(MAX_RESULTS))) or "")
            .. (found > 0 and ("  " .. GRAY_FONT_COLOR:WrapTextInColorCode(L["Enter: go to the first"])) or ""))
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
        page.scroll:SetPoint("TOPLEFT", page.header, "BOTTOMLEFT", 0, -10)
        local module = S.modules[current]
        if not module then return end
        -- leaving a page or tab takes its seen badges away
        local activeTab = self:ActiveTab(module)
        local visit = module.key .. "/" .. (activeTab and activeTab.key or "")
        if visit ~= newVisit then
            S:EndNewVisit()
            newVisit = visit
            UpdateNav()
        end
        UpdateHeader(module)
        if module.enabled and not module:IsOn() then
            page.offCard.text:SetText((S:WindowText("moduleOffCard", L["{Module} is off. Its settings appear here once it's on."])):gsub("{Module}", module:Title()))
            page.offCard:Show()
        else
            local tab = activeTab or module.custom
            -- (not behind What's new, which opens by itself after an update)
            if not self.holdNewSeen and not frame.news:IsShown() then module:MarkNewSeen(activeTab and activeTab.key) end
            ShowModulePreview()
            if tab and tab.custom then
                -- a custom tab's rows exist only for search
                page.scroll:Hide()
                ShowCustom(module, tab)
            else
                rowInset = SEC_X
                -- Gamepad mode: a page whose module Blizzard's Gamepad UI keeps off says so once, on top;
                -- elsewhere each section with such rows says so under its title (S.GAMEPAD_OFF)
                local pad = ns.IsGamepadUI()
                local wholePage = pad and S.GAMEPAD_OFF_MODULES[module.key]
                if wholePage then y = y - GamepadNote(content, y) end
                for _, section in ipairs(module:Sections(tab and tab.key)) do
                    local top = y
                    y = y - SEC_TOP
                    if section.title then y = y - SectionHeader(content, section.title, y, section.key) - 4 end
                    if pad and not wholePage and S:SectionGamepadOff(section) then y = y - GamepadNote(content, y) end
                    if not (section.title and closedSections[section.key]) then
                        y = PlaceRows(content, section.rows, y)
                    end
                    y = y - SEC_BOTTOM + ROW_GAP
                    SectionBox(content, top, y)
                    y = y - SEC_GAP
                end
                rowInset = 0
            end
            content:SetHeight(math.max(1, -y + 8))
            return
        end
        ShowModulePreview()
    end
    content:SetHeight(math.max(1, -y + 8))
end

--------------------------------------------------
-- 5. LEFT COLUMN
--------------------------------------------------
local NAV_TEXT_INSET, NAV_RIGHT_INSET, NAV_H = 36, 6, 30

function UpdateNav()
    for key, b in pairs(navButtons) do
        local module = S.modules[key]
        local on = module:IsOn()
        if b.toggle then b.toggle:SetChecked(on) end
        local selected = key == current and searchText == ""
        b.selected:SetShown(selected)
        b.bar:SetShown(selected)
        b.edge:SetBackdropBorderColor(EDGE_COLOR[1], EDGE_COLOR[2], EDGE_COLOR[3], selected and 1 or 0)
        if module.navIcon then
            b.dot:SetTexture(module.navIcon)
            if module.navIconRound == "ring" then
                -- the round aura look, a little larger than the line icons
                b.dot:SetSize(24, 24)
                RingIcon(b.dot, b)
            -- game icon cropped to a circle
            elseif module.navIconRound and not b.dotMask then
                b.dotMask = b:CreateMaskTexture()
                b.dotMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                b.dotMask:SetAllPoints(b.dot)
                b.dot:AddMaskTexture(b.dotMask)
                b.dot:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end
            b.dot:SetDesaturated(false)
            if not module.navIconTint then b.dot:SetVertexColor(1, 1, 1)
            elseif selected then b.dot:SetVertexColor(1, 0.83, 0.47)
            elseif on then b.dot:SetVertexColor(0.69, 0.54, 0.31)
            else b.dot:SetVertexColor(0.45, 0.42, 0.38) end
            b.dot:Show()
        else
            b.dot:SetShown(module.enabled ~= nil)
            b.dot:SetVertexColor(on and 0.35 or 0.4, on and 0.85 or 0.4, on and 0.35 or 0.4)
        end
        if selected then b.text:SetTextColor(1, 0.89, 0.63)
        elseif on then b.text:SetTextColor(0.85, 0.80, 0.70)
        else b.text:SetTextColor(GRAY_FONT_COLOR:GetRGB()) end
        local showNew = on and module:HasNew()
        if b.showNew ~= showNew then
            b.showNew = showNew
            b.newBadge:SetShown(showNew)
            local badgeWidth = showNew and (NEW_W + NEW_GAP) or 0
            local room = b:GetWidth() - NAV_TEXT_INSET - (b.rightInset or NAV_RIGHT_INSET) - badgeWidth
            b.text:SetWidth(room)
            FitText(b.text, room, 2)
            b:SetHeight(math.max(NAV_H, math.ceil(b.text:GetStringHeight()) + 8))
        end
    end
end

function Panel:Select(key)
    if not S.modules[key] then return end
    if key ~= current then
        S:EndNewVisit()
        newVisit = nil
        if current and page.scroll then scrollOf[current] = page.scroll:GetVerticalScroll() end
    end
    current = key
    -- lets the shown module preview itself
    S:Fire("PageShown", key)
    if ns.db and ns.db.global then ns.db.global.settingsPage = key end
    if searchText ~= "" then
        searchText = ""
        frame.search:SetText("")
    end
    page.scroll:SetVerticalScroll(0)
    UpdateNav()
    self:Refresh()
    -- back where this page was left (the scroll range is known once the rows are placed)
    local back = scrollOf[key]
    if back and back > 0 then
        C_Timer.After(0, function()
            if current ~= key then return end
            page.scroll:SetVerticalScroll(math.min(back, page.scroll:GetVerticalScrollRange() or 0))
        end)
    end
end

-- From a search result: the row's page and tab, its section unfolded, scrolled to and flashed
function Panel:JumpTo(row)
    local module = S.modules[row.module]
    if not module then return end
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
    if row.kind ~= "editmode" then
        if module.tabs then currentTab[module.key] = row.tab or module.tabs[1].key end
        if row.section then closedSections[row.section] = nil end
        -- a row folded under a closed heading: the heading opens
        local heading = row.collapsedBy and S.rows[row.collapsedBy]
        if heading and heading.isOpen and heading.toggle and not heading.isOpen() then heading.toggle() end
        page.jumpRow = row
    end
    page.jumpFrame = nil
    self:Select(module.key)
    local f, top = page.jumpFrame, page.jumpTop
    page.jumpRow, page.jumpFrame = nil, nil
    if not f then return end
    -- the scroll range is known once the content has its height
    C_Timer.After(0, function()
        if f.row ~= row or not f:IsVisible() then return end
        local range = page.scroll:GetVerticalScrollRange() or 0
        page.scroll:SetVerticalScroll(math.max(0, math.min(range, top - 40)))
        FlashRow(f)
    end)
end

local function BuildNav(left)
    -- Anchor each row to the one above so badge changes can reflow the list.
    local anchor, anchorPoint, x, gap = left, "TOPLEFT", 6, 8
    local buttonWidth = LEFT_W - 12
    -- groups (11-10): About, Profiles and Language on top without a heading, then these
    local GROUP_LABEL = {
        combat = S:WindowText("leftListGroups", L["Combat"]),
        map = S:WindowText("leftListGroups2", L["Map & Quests"]),
        interface = S:WindowText("leftListGroups3", L["Interface"]),
    }
    for _, group in ipairs(S:Groups()) do
        local label = GROUP_LABEL[group.group]
        if label then
            local g = Text(left, "GameFontDisableSmall")
            g:SetPoint("TOPLEFT", anchor, anchorPoint, x + 8, -gap - 12)
            g:SetTextColor(0.66, 0.55, 0.36)
            g:SetText(label)
            gap = gap + 30
        elseif group.group == "bottom" then
            gap = gap + 10
        end
        for _, module in ipairs(group.modules) do
            local icons = { about=true, adv=true, language=true, ab=true, uf=true, rb=true, au=true, dm=true,
                mm=true, qt=true, ch=true, tt=true, rm=true, qol=true, bl=true }
            if GameIcons() and GAME_ICONS[module.key] then
                module.navIcon = "Interface\\Icons\\" .. GAME_ICONS[module.key]
                module.navIconRound = "ring"
                module.navIconTint = false
            elseif icons[module.key] then
                module.navIcon = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Panel\\Icons\\" .. module.key .. ".tga"
                module.navIconRound = false
                module.navIconTint = true
            end
            -- the open page sits on a warm plate with a gold bar at its left edge
            local b = CreateFrame("Button", nil, left)
            b:SetSize(buttonWidth, NAV_H)
            b:SetPoint("TOPLEFT", anchor, anchorPoint, x, -gap)
            ThinEdge(b)
            b.edge:SetBackdropBorderColor(EDGE_COLOR[1], EDGE_COLOR[2], EDGE_COLOR[3], 0)
            b.selected = b:CreateTexture(nil, "BACKGROUND")
            b.selected:SetPoint("TOPLEFT", THIN_INSET, -THIN_INSET)
            b.selected:SetPoint("BOTTOMRIGHT", -THIN_INSET, THIN_INSET)
            Rounded(b.selected)
            b.selected:SetGradient("HORIZONTAL", CreateColor(0.80, 0.54, 0.22, 0.75), CreateColor(0.46, 0.30, 0.11, 0.40))
            b.bar = b:CreateTexture(nil, "ARTWORK")
            b.bar:SetColorTexture(1, 0.80, 0.38)
            b.bar:SetPoint("TOPLEFT", 0, -5)
            b.bar:SetPoint("BOTTOMLEFT", 0, 5)
            b.bar:SetWidth(3)
            b:SetHighlightTexture(ROUND_RECT)
            Rounded(b:GetHighlightTexture(), 0.98, 0.70, 0.30, 0.22)
            b.dot = b:CreateTexture(nil, "ARTWORK")
            b.dot:SetTexture("Interface\\COMMON\\Indicator-Green")
            b.dot:SetDesaturated(true)
            b.dot:SetSize(18, 18)
            b.dot:SetPoint("LEFT", 10, 0)
            b.text = Text(b, "GameFontHighlight")
            b.text:SetPoint("LEFT", NAV_TEXT_INSET, 0)
            -- (room for the module's switch at the right, when it has one)
            b.rightInset = NAV_RIGHT_INSET   -- (no checkbox here since 11-13: the page title's turns a module on)
            b.text:SetWidth(buttonWidth - NAV_TEXT_INSET - b.rightInset)
            b.text:SetWordWrap(true)
            b.text:SetText(module:Title())
            FitText(b.text, buttonWidth - NAV_TEXT_INSET - b.rightInset, 2)
            b.newBadge = NewBadge(b)
            -- (11-13, Marcus) no quick checkbox in the list (11-11 to 11-13): a module is turned on or off
            -- by the checkbox beside its page title; an off one still shows greyed here
            b.newBadge:SetPoint("RIGHT", -NAV_RIGHT_INSET / NEW_SCALE, 0)
            b:SetScript("OnClick", function()
                PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
                Panel:Select(module.key)
            end)
            navButtons[module.key] = b
            anchor, anchorPoint, x, gap = b, "BOTTOMLEFT", 0, 0
        end
    end
end

--------------------------------------------------
-- 6. RELOAD BAR
--------------------------------------------------
-- ReloadUI is protected on Forever: "Reload now" is covered by a secure /reload button on UIParent
-- (keeps the window unprotected), placed out of combat only; in combat the plain button opens the dialog.
local secureReload
local function PlaceSecureReload()
    if not frame then return end
    -- it cannot hide or move in combat: its secure parent hides it then (ns.SecureReloadParent), and it
    -- is placed again when the fight ends
    if InCombatLockdown() then
        if secureReload and not (frame:IsShown() and frame.reload:IsVisible()) then secureReload:SetAlpha(0) end
        return
    end
    if not secureReload then
        secureReload = CreateFrame("Button", "FlareUI_SettingsReload", ns.SecureReloadParent(), "SecureActionButtonTemplate, UIPanelButtonTemplate")
        secureReload:SetFrameStrata("FULLSCREEN_DIALOG")
        SkinButton(secureReload)
        -- acts on the press, whatever ActionButtonUseKeyDown says, so PreClick runs once and in step
        secureReload:RegisterForClicks("AnyDown")
        secureReload:SetAttribute("useOnKeyDown", true)
        secureReload:SetAttribute("type", "macro")
        secureReload:SetAttribute("macrotext", "/stopmacro [combat]\n/reload")
        secureReload:SetScript("PreClick", function()
            if InCombatLockdown() then
                if ERR_NOT_IN_COMBAT and UIErrorsFrame then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1) end
                return
            end
            ns.reloading = true
            ns.ButtonSound()
        end)
    end
    local button = frame.reload
    local x, y = button:GetCenter()
    if frame:IsShown() and button:IsVisible() and x then
        local scale = button:GetEffectiveScale() / UIParent:GetEffectiveScale()
        secureReload:SetScale(scale)
        secureReload:SetSize(button:GetSize())
        secureReload:ClearAllPoints()
        secureReload:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
        secureReload:SetText(button:GetText())
        secureReload:SetAlpha(1)
        secureReload:Show()
    else
        secureReload:Hide()
    end
end
Panel.OnResize = PlaceSecureReload   -- a wide tab moved the reload button

-- Window scale: Shift + mouse wheel over the window, 70% to 130%, kept for the account. The window
-- keeps its centre. Out of combat only: the secure reload button can't follow it in a fight.
-- the player's scale, made smaller when the window wouldn't fit the screen (with its reload bar)
local function FitScale(scale)
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    if not (frame and w and h and w > 0 and h > 0) then return scale end
    return math.min(scale, w / (frame:GetWidth() + 16), h / (HEIGHT + FOOTER_H + FOOTER_RISE + 24))
end

local function ApplyPanelScale()
    if not frame then return end
    local global = ns.db and ns.db.global
    local scale = FitScale(global and global.panelScale or 1)
    local x, y = frame:GetCenter()
    local old = frame:GetScale()
    frame:SetScale(scale)
    if x and old and old > 0 then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x * old / scale, y * old / scale)
    end
    PlaceSecureReload()
end
function Panel.ScaleStep(delta)
    local global = ns.db and ns.db.global
    if not (frame and global) or InCombatLockdown() then return end
    local scale = math.max(0.7, math.min(1.3, (global.panelScale or 1) + (delta > 0 and 0.05 or -0.05)))
    global.panelScale = math.floor(scale * 100 + 0.5) / 100
    ApplyPanelScale()
end

-- pending reloads (with the button), else a page notice that lasts until another page shows
local notice, noticePage
local function UpdateFooter()
    if not frame then return end
    local n = S:PendingCount()
    if n > 0 then
        local text = S:WindowText("reloadFooter", L["{n} change(s) need a reload"])
        frame.footerText:SetText(text:gsub("{n}", n))
        frame.reload:Show()
        frame.footer.alert:Show()
        frame.footer:Show()
    elseif notice then
        frame.footerText:SetText(notice)
        frame.reload:Hide()
        frame.footer.alert:Hide()
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
-- The look for FlareUI's other windows (the setup tour): the same stone, glow and shade, the heavy bronze
-- frame with its rivets top left and bottom right, and a close button in its top right corner (returned).
-- Without the frame's art (a client that lacks it), the tooltip edge.
function Panel.DressWindow(f)
    f:SetBackdrop(nil)
    local art = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    art:SetPoint("TOPLEFT", 3, 8)
    art:SetPoint("BOTTOMRIGHT", -3, -8)
    art:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock", "REPEAT", "REPEAT")
    art:SetHorizTile(true)
    art:SetVertTile(true)
    local wash = f:CreateTexture(nil, "BACKGROUND", nil, 2)
    wash:SetAllPoints(art)
    wash:SetColorTexture(0.05, 0.038, 0.026, 0.35)
    local glow = f:CreateTexture(nil, "BACKGROUND", nil, 3)
    glow:SetPoint("TOPLEFT", art)
    glow:SetPoint("TOPRIGHT", art)
    glow:SetHeight(220)
    glow:SetColorTexture(1, 1, 1)
    glow:SetGradient("VERTICAL", CreateColor(0.55, 0.41, 0.22, 0), CreateColor(0.55, 0.41, 0.22, 0.20))
    local shade = f:CreateTexture(nil, "BACKGROUND", nil, 3)
    shade:SetPoint("BOTTOMLEFT", art)
    shade:SetPoint("BOTTOMRIGHT", art)
    shade:SetHeight(240)
    shade:SetColorTexture(1, 1, 1)
    shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.5), CreateColor(0, 0, 0, 0))
    local edge
    if C_Texture.GetAtlasInfo("heavybronze-frame-basic") then
        local b = CreateFrame("Frame", nil, f)
        b:SetAllPoints()
        b:SetFrameLevel(f:GetFrameLevel() + 30)
        -- the frame stands past the window: kept on screen with it
        f:SetClampRectInsets(-9, 9, 15, -15)
        edge = b:CreateTexture(nil, "BORDER")
        edge:SetAtlas("heavybronze-frame-basic")
        edge:SetPoint("TOPLEFT", -9, 15)
        edge:SetPoint("BOTTOMRIGHT", 9, -15)
        for _, c in ipairs({ { "TL", "TOPLEFT" }, { "BR", "BOTTOMRIGHT" } }) do
            local t = b:CreateTexture(nil, "ARTWORK")
            t:SetAtlas("heavybronze-horz-cornerbracket-" .. c[1], true)
            t:SetPoint(c[2], edge, c[2])
        end
    else
        art:SetPoint("TOPLEFT", 3, -3)
        art:SetPoint("BOTTOMRIGHT", -3, 3)
        f:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16 })
        local c = ns.WINDOW_STYLE.border
        f:SetBackdropBorderColor(c[1], c[2], c[3], 1)
    end
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    if edge then close:SetPoint("TOPRIGHT", edge, "TOPRIGHT", -2, -2) else close:SetPoint("TOPRIGHT", -4, -4) end
    close:SetFrameLevel(f:GetFrameLevel() + 40)
    return close
end

-- A picture's bronze rim and soft shade (the Info Panel dog's), behind tex on parent; pad: how much
-- larger than the picture the rim is drawn
function Panel.RimPicture(parent, tex, pad)
    local w, h = tex:GetSize()
    local rim = parent:CreateTexture(nil, "ARTWORK", nil, -2)
    rim:SetTexture("Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Panel\\PictureRim.tga")
    rim:SetPoint("CENTER", tex, "CENTER")
    rim:SetSize(w + pad, h + pad)
    rim:SetVertexColor(0.78, 0.6, 0.34)
    local shade = parent:CreateTexture(nil, "ARTWORK", nil, -3)
    shade:SetTexture("Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Panel\\PictureShade.tga")
    shade:SetPoint("CENTER", tex, "CENTER")
    shade:SetSize(w + pad + 14, h + pad + 14)
    shade:SetVertexColor(0, 0, 0, 1)
    return rim, shade
end

--------------------------------------------------
-- 6b. THE WINDOW'S STONE AND FRAME (11-11): Marcus picked the natural rock and the character select's
-- heavy bronze frame (rivets top left and bottom right), from look tests since retired
--------------------------------------------------
local LOOK_BG = {
    { "Rock, bronze tint", file = "Interface\\FrameGeneral\\UI-Background-Rock", tile = true, desat = true, tint = { 0.85, 0.68, 0.47 }, wash = 0.3 },
    -- (11-13 Marcus: plain, as previewed: no brown wash, no bronze glow; the wash was 0.35, then 0.12)
    { "Rock, natural", file = "Interface\\FrameGeneral\\UI-Background-Rock", tile = true, wash = 0, plain = true },
}
local LOOK_FRAME = { "Tooltip edge (now)", "FlareUI Thick", "Heavy bronze (character select)" }
local lookBg, lookFrame = 2, 3   -- the picks, drawn as the window is built

local function TryBackground(n)
    local o = LOOK_BG[n]
    local art, wash = frame.ftArt, frame.ftWash
    if o.atlas then
        if not C_Texture.GetAtlasInfo(o.atlas) then return false end
        art:SetHorizTile(false); art:SetVertTile(false)
        art:SetAtlas(o.atlas)
    else
        art:SetTexture(o.file, o.tile and "REPEAT" or nil, o.tile and "REPEAT" or nil)
        art:SetTexCoord(0, 1, 0, 1)
        art:SetHorizTile(o.tile and true or false); art:SetVertTile(o.tile and true or false)
    end
    art:SetDesaturated(o.desat and true or false)
    local t = o.tint or { 1, 1, 1 }
    art:SetVertexColor(t[1], t[2], t[3])
    wash:SetColorTexture(0.05, 0.038, 0.026, o.wash or 0.3)
    -- a plain ground: no bronze glow along the top either
    if frame.ftGlow then frame.ftGlow:SetShown(not o.plain) end
    return true
end

local function TryFrame(n)
    local style = ns.WINDOW_STYLE
    if frame.ftBronze then frame.ftBronze:Hide() end
    -- the stone reaches under the heavy bronze frame's top and bottom bars; the others sit on its edge
    local art, under = frame.ftArt, n == 3 and 8 or -3
    if art then
        art:ClearAllPoints()
        art:SetPoint("TOPLEFT", 3, under)
        art:SetPoint("BOTTOMRIGHT", -3, -under)
    end
    if n == 1 then
        frame:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16 })
        frame:SetBackdropBorderColor(style.border[1], style.border[2], style.border[3], 1)
    elseif n == 2 then
        local file = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Borders\\FlareUI-Thick.tga"
        frame:SetBackdrop({ edgeFile = file, edgeSize = ns.BorderEdgeSize(file, 16) })
        local c = ns.BORDER_COLOR
        frame:SetBackdropBorderColor(c.r, c.g, c.b, 1)
    else
        if not C_Texture.GetAtlasInfo("heavybronze-frame-basic") then return false end
        frame:SetBackdrop(nil)
        local b = frame.ftBronze
        if not b then
            -- as the character select list draws it: the frame stretched past the edges, brackets on the corners
            b = CreateFrame("Frame", nil, frame)
            b:SetAllPoints()
            b:SetFrameLevel(frame:GetFrameLevel() + 30)
            b.edge = b:CreateTexture(nil, "BORDER")
            b.edge:SetAtlas("heavybronze-frame-basic")
            -- where the character select list draws it, stretched (11-11: the nine-slice try broke it)
            b.edge:SetPoint("TOPLEFT", -9, 15)
            b.edge:SetPoint("BOTTOMRIGHT", 9, -15)
            -- the rivets top left and bottom right; the close button takes the top right corner (11-11 Marcus)
            for _, c in ipairs({ { "TL", "TOPLEFT" }, { "BR", "BOTTOMRIGHT" } }) do
                local t = b:CreateTexture(nil, "ARTWORK")
                t:SetAtlas("heavybronze-horz-cornerbracket-" .. c[1], true)
                t:SetPoint(c[2], b.edge, c[2])
            end
            b.edge.ftCorner = true
            frame.ftBronze = b
        end
        b:Show()
    end
    return true
end

local function BuildWindow()
    local style = ns.WINDOW_STYLE
    ApplyTitleFont()
    -- (11-11 Marcus: after a reload each page opens on its first tab; the tabs once kept go)
    if ns.db and ns.db.global then ns.db.global.settingsTabs = nil end
    frame = CreateFrame("Frame", "FlareUI_SettingsPanel", UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    -- the scale the player set (Shift + mouse wheel anywhere over the window)
    frame:SetScale(FitScale(ns.db and ns.db.global and ns.db.global.panelScale or 1))
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        if IsShiftKeyDown() then Panel.ScaleStep(delta) end
    end)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
        if secureReload then
            if InCombatLockdown() then secureReload:SetAlpha(0) else secureReload:Hide() end
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        PlaceSecureReload()
    end)
    frame:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16 })
    frame:SetBackdropBorderColor(style.border[1], style.border[2], style.border[3], 1)
    -- FlareUI's own ground (11-10): the game's rock tile in warm dark bronze, a glow under the header,
    -- a shade toward the bottom. 3 px in, under the border's line, so no gap shows between them.
    local BG_INSET = 3
    local art = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    -- (11-11) up and down under the frame's top and bottom bars, which sit further out than its sides
    art:SetPoint("TOPLEFT", BG_INSET, 8)
    art:SetPoint("BOTTOMRIGHT", -BG_INSET, -8)
    art:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock", "REPEAT", "REPEAT")
    art:SetHorizTile(true)
    art:SetVertTile(true)
    art:SetDesaturated(true)
    art:SetVertexColor(0.85, 0.68, 0.47)
    local wash = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    wash:SetAllPoints(art)
    wash:SetColorTexture(0.05, 0.038, 0.026, 0.3)
    local glow = frame:CreateTexture(nil, "BACKGROUND", nil, 3)
    glow:SetPoint("TOPLEFT", art)
    glow:SetPoint("TOPRIGHT", art)
    glow:SetHeight(260)
    glow:SetColorTexture(1, 1, 1)
    glow:SetGradient("VERTICAL", CreateColor(0.55, 0.41, 0.22, 0), CreateColor(0.55, 0.41, 0.22, 0.20))
    frame.ftArt, frame.ftWash, frame.ftGlow = art, wash, glow
    TryBackground(lookBg)
    if not TryFrame(lookFrame) then TryFrame(1) end   -- (the tooltip edge where the client lacks the art)
    local shade = frame:CreateTexture(nil, "BACKGROUND", nil, 3)
    shade:SetPoint("BOTTOMLEFT", art)
    shade:SetPoint("BOTTOMRIGHT", art)
    shade:SetHeight(300)
    shade:SetColorTexture(1, 1, 1)
    shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.5), CreateColor(0, 0, 0, 0))
    frame:Hide()
    tinsert(UISpecialFrames, "FlareUI_SettingsPanel")
    frame:SetScript("OnShow", function()
        ns.WindowOpenSound()
        UpdateNav()
        UpdateFooter()
        Panel:Refresh()
    end)
    frame:SetScript("OnHide", function()
        S:EndNewVisit()
        newVisit = nil
        S:Fire("PageShown", nil)
        ns.WindowCloseSound()
        PlaceSecureReload()
        -- a dialog already up (a profile name being typed) is left alone
        if S:PendingCount() > 0 and not Panel.quietHide and not ns.AnyDialogShown() then
            ns.ShowDialog("FLAREUI_RELOAD_ON_CLOSE")
        end
    end)

    -- header (56): the logo, name and version, the Settings / What's New plates; search and close right
    -- (11-13, Marcus: a colour line showed under the header) no header band of its own: the stone and
    -- its soft top glow run on under the header row
    local logo = frame:CreateTexture(nil, "ARTWORK", nil, 2)
    logo:SetTexture(LOGO)
    logo:SetSize(38, 38)
    -- centred on the header row; its rim's outer edge on the left list's border line (11-11 Marcus)
    logo:SetPoint("TOPLEFT", EDGE + 6, -(HEADER_ROW_Y - 19))
    local logoMask = frame:CreateMaskTexture()
    logoMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    logoMask:SetAllPoints(logo)
    logo:AddMaskTexture(logoMask)
    local logoRim = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    logoRim:SetTexture(CIRCLE)
    logoRim:SetSize(44, 44)
    logoRim:SetPoint("CENTER", logo)
    logoRim:SetVertexColor(0.78, 0.6, 0.34)
    local logoShade = frame:CreateTexture(nil, "ARTWORK", nil, 0)
    logoShade:SetTexture(CIRCLE)
    logoShade:SetSize(46, 46)
    logoShade:SetPoint("CENTER", logo)
    logoShade:SetVertexColor(0, 0, 0, 0.6)
    local title = Text(frame, "GameFontNormalHuge")
    title:SetPoint("LEFT", logo, "RIGHT", 10, 1)
    title:SetTextColor(TITLE_YELLOW[1], TITLE_YELLOW[2], TITLE_YELLOW[3])
    title:SetText(L["FlareUI"])
    local version = Text(frame, "GameFontDisableSmall")
    version:SetPoint("LEFT", title, "RIGHT", 8, -2)
    version:SetTextColor(0.64, 0.6, 0.54)
    version:SetText(C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "")
    -- on the frame's top right corner, above the frame art (11-11 Marcus)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    -- in the frame art's own top right corner (the heavy bronze frame), else the window's
    if frame.ftBronze and frame.ftBronze:IsShown() then
        close:SetPoint("TOPRIGHT", frame.ftBronze.edge, "TOPRIGHT", -2, -2)
    else
        close:SetPoint("CENTER", frame, "TOPRIGHT", -5, -3)
    end
    close:SetFrameLevel(frame:GetFrameLevel() + 40)

    -- columns
    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", EDGE, -HEADER_H - EDGE)
    body:SetPoint("BOTTOMRIGHT", -EDGE, EDGE)
    frame.body = body

    -- Settings | What's new, after the version
    frame.topTabs = {}
    for i, mode in ipairs({ "settings", "whatsnew" }) do
        local b = Plate(frame, "GameFontHighlight")
        b:SetHeight(28)
        b.Text:SetText(S:WindowText(i == 1 and "tabs" or "tabs2", i == 1 and L["Settings"] or L["What's New"]))
        b:SetWidth((b.Text:GetStringWidth() or 80) + 32)
        b.mode = mode
        b:SetScript("OnClick", function(self)
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            Panel:SetMode(self.mode)
        end)
        frame.topTabs[i] = b
    end
    -- Settings / What's New start at the middle box's left edge (11-11 Marcus)
    -- (+4, 11-13 Marcus: the grey face reaches past the button; its visible edge on the box's)
    frame.topTabs[1]:SetPoint("LEFT", frame, "TOPLEFT", EDGE + LEFT_W + GAP + 4, -HEADER_ROW_Y)
    frame.topTabs[2]:SetPoint("LEFT", frame.topTabs[1], "RIGHT", 6, 0)

    -- What's new: every version's notes, newest first
    local news = CreateFrame("Frame", nil, frame)
    news:SetAllPoints(body)
    news:Hide()
    -- (11-13, Marcus) the footer: Don't Show on Login (account-wide, off). Releases come often, and the
    -- notes opened at every login after an update
    local NEWS_FOOT = 20   -- the notes stop this far above the switch row
    local quiet = Switch(news)
    quiet:SetPoint("BOTTOMLEFT", PAD, PAD - 12)   -- (11-13 Marcus) low, near the frame's bottom edge
    quiet:SetScript("OnShow", function(self)
        local global = ns.db and ns.db.global
        self:SetChecked(global and global.whatsNewQuiet == true or false)
    end)
    quiet:SetScript("OnClick", function(self)
        local global = ns.db and ns.db.global
        if global then global.whatsNewQuiet = self:GetChecked() and true or nil end
        PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    end)
    local quietLabel = Text(news, "GameFontHighlight")
    quietLabel:SetPoint("LEFT", quiet, "RIGHT", 10, 0)
    quietLabel:SetText(L["Don't Show on Login"])
    local quietHint = Text(news, "GameFontDisableSmall")
    quietHint:SetPoint("LEFT", quietLabel, "RIGHT", 12, 0)
    quietHint:SetText(L["The notes stay here, under What's New."])
    local newsScroll = CreateFrame("ScrollFrame", nil, news)
    newsScroll:SetPoint("TOPLEFT", PAD, -PAD)
    newsScroll:SetPoint("BOTTOMRIGHT", -PAD - 28, PAD + NEWS_FOOT)
    -- (11-11 Marcus) each version in a box of its own, as the settings' sections, clear of the scroll line
    local NEWS_W, NEWS_PAD = WIDTH - 2 * EDGE - 2 * PAD - 40, 16
    local newsContent = CreateFrame("Frame", nil, newsScroll)
    newsContent:SetSize(NEWS_W, 1)
    newsScroll:SetScrollChild(newsContent)
    Panel.AttachScrollLine(newsScroll, news)
    local y = 0
    for _, entry in ipairs(ns.WhatsNew or {}) do
        local box = CreateFrame("Frame", nil, newsContent, "BackdropTemplate")
        Box(box, 0.40)
        box:SetPoint("TOPLEFT", 0, y)
        box:SetWidth(NEWS_W)
        local title = Text(box, "GameFontNormalHuge")
        title:SetPoint("TOPLEFT", NEWS_PAD, -NEWS_PAD + 2)
        title:SetText(L["FlareUI"] .. " " .. entry.version)
        local body = Text(box, "GameFontHighlight")
        body:SetPoint("TOPLEFT", NEWS_PAD, -NEWS_PAD - 34)
        body:SetWidth(NEWS_W - 2 * NEWS_PAD)
        body:SetSpacing(4)
        body:SetText(entry.text)
        local h = NEWS_PAD + 34 + (body:GetStringHeight() or 0) + NEWS_PAD
        box:SetHeight(h)
        y = y - h - 12
    end
    newsContent:SetHeight(math.max(1, -y))
    frame.news = news

    -- three boxes: the left list, the page, the right column
    local left = CreateFrame("Frame", nil, body, "BackdropTemplate")
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(LEFT_W)
    Box(left, 0.40)   -- (11-13, Marcus: the stone stays light, the boxes darker to read; were 0.18 / 0.18 / 0.10)

    local right = CreateFrame("Frame", nil, body, "BackdropTemplate")
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(RIGHT_W)
    Box(right, 0.40)
    local rightLine = right:CreateTexture(nil, "BACKGROUND")   -- kept for custom tabs; the box has the edge
    rightLine:SetSize(1, 1)
    rightLine:SetPoint("TOPRIGHT", right, "TOPLEFT")
    rightLine:SetAlpha(0)

    local middleBox = CreateFrame("Frame", nil, body, "BackdropTemplate")
    middleBox:SetPoint("TOPLEFT", left, "TOPRIGHT", GAP, 0)
    middleBox:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", -GAP, 0)
    Box(middleBox, 0.30)
    -- (a custom tab that draws its own boxes, the radial editor, hides these two while it shows)
    Panel.middleBox, Panel.rightBox, Panel.INNER = middleBox, right, INNER
    local middle = CreateFrame("Frame", nil, middleBox)
    middle:SetPoint("TOPLEFT", INNER, -INNER)
    middle:SetPoint("BOTTOMRIGHT", -INNER, INNER)
    page.root = middle
    page.body, page.right, page.rightLine = body, right, rightLine

    -- search
    local search = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
    search:SetSize(RIGHT_W - 6, 24)   -- the right column's width (the template's own left inset aside)
    -- where the close button was: the header row's right end
    search:SetPoint("RIGHT", frame, "TOPRIGHT", -EDGE, -HEADER_ROW_Y)
    search.Instructions:SetText(S:WindowText("searchPlaceholder", L["Search settings"]))
    -- the page redraws once typing pauses for a moment, not on every key
    local searchToken = 0
    search:HookScript("OnTextChanged", function(self)
        -- unchanged (Select clearing the box, a trailing space): no redraw, which would undo a jump's scroll
        local text = strtrim(self:GetText() or "")
        if text == searchText then return end
        searchText = text
        searchToken = searchToken + 1
        local token = searchToken
        C_Timer.After(0.15, function()
            if token ~= searchToken then return end
            page.scroll:SetVerticalScroll(0)
            UpdateNav()
            Panel:Refresh()
        end)
    end)
    -- Enter: straight to the first result, flashed
    search:HookScript("OnEnterPressed", function(self)
        local text = strtrim(self:GetText() or "")
        if text == "" then return end
        -- the redraw still waiting from the typing would undo the jump
        searchToken = searchToken + 1
        local first = S:Search(text)[1]
        if first then Panel:JumpTo(first) end
        self:ClearFocus()
    end)
    frame.search = search
    BuildNav(left)

    -- page header
    local header = CreateFrame("Frame", nil, middle)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(64)
    page.header = header
    -- icon plate, then the title (Marcellus) with the module's switch after it
    local plate = CreateFrame("Frame", nil, header, "BackdropTemplate")
    plate:SetSize(42, 42)
    plate:SetPoint("TOPLEFT", 0, -2)
    ThinBackdrop(plate, true)
    plate:SetBackdropColor(0.13, 0.095, 0.055, 1)
    plate:SetBackdropBorderColor(EDGE_HOVER[1], EDGE_HOVER[2], EDGE_HOVER[3], 1)
    page.plateIcon = plate:CreateTexture(nil, "ARTWORK")
    page.plateIcon:SetSize(26, 26)
    page.plateIcon:SetPoint("CENTER")
    page.plate = plate
    page.title = Text(header, "GameFontNormalHuge")
    page.title:SetTextColor(TITLE_YELLOW[1], TITLE_YELLOW[2], TITLE_YELLOW[3])
    page.title:SetWordWrap(true)
    page.title:SetPoint("TOPLEFT", plate, "TOPRIGHT", 12, -2)
    page.switch = Switch(header)
    page.switch:SetPoint("LEFT", page.title, "RIGHT", 10, 0)
    page.switch:SetScript("OnClick", function(self)
        local on = self:GetChecked() and true or false
        PlaySound(on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        S.modules[current]:SetOn(on)
        UpdateNav()
        Panel:Refresh()
    end)
    -- Edit Mode button: the module's main frame, or plain Edit Mode for Blizzard's bars
    page.editMode = PanelButton(header)
    page.editMode:SetHeight(22)
    page.editMode:SetPoint("TOPRIGHT", 0, -2)
    page.editMode:SetScript("OnClick", function(self)
        ns.ButtonSound()
        if self.customClick then
            self.customClick()
            return
        end
        local module = S.modules[current]
        local target = module.editMode and module.editMode()
        if target then
            S:EditFrame(target, module.key)
        else
            S:OpenEditMode(module.key)
        end
    end)
    page.editMode:Hide()
    page.desc = Text(header, "GameFontHighlightSmall")
    page.desc:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -4)
    page.desc:SetPoint("RIGHT", -4, 0)
    page.desc:SetTextColor(0.64, 0.6, 0.54)

    local banner = CreateFrame("Frame", nil, header, "BackdropTemplate")
    banner:SetHeight(30)
    banner:SetPoint("TOPLEFT", 0, -52)
    banner:SetPoint("RIGHT")
    banner:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    banner:SetBackdropColor(0.5, 0.35, 0, 0.35)
    banner.button = PanelButton(banner)
    banner.button:SetHeight(22)
    banner.text = Text(banner, "GameFontNormal")
    banner.text:SetPoint("LEFT", 8, 0)
    banner.text:SetJustifyH("LEFT")
    banner.text:SetWordWrap(true)
    banner.button:SetPoint("RIGHT", -4, 0)
    banner.button:SetScript("OnClick", function()
        ns.ButtonSound()
        if banner.onClick then banner.onClick() end
        Panel:Refresh()
    end)
    banner:Hide()
    page.banner = banner

    -- module tabs
    page.tabButtons = {}
    for i = 1, 5 do
        local b = Plate(header, "GameFontHighlight")
        b:SetHeight(26)
        if i == 1 then b:SetPoint("BOTTOMLEFT", 4, 0) else b:SetPoint("BOTTOMLEFT", page.tabButtons[i - 1], "BOTTOMRIGHT", 4, 0) end   -- (first +4, as the top tabs)
        b:SetScript("OnClick", function(self)
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            currentTab[current] = self.tabKey
            scrollOf[current] = nil
            page.scroll:SetVerticalScroll(0)
            Panel:Refresh()
        end)
        b:Hide()
        page.tabButtons[i] = b
    end
    page.tabLine = Line(header)
    page.tabLine:SetColorTexture(0.47, 0.36, 0.22, 1)
    page.tabLine:SetPoint("BOTTOMLEFT", 0, 0)
    page.tabLine:SetPoint("BOTTOMRIGHT", 0, 0)
    page.tabLine:Hide()

    -- scrolling rows
    local scroll = CreateFrame("ScrollFrame", nil, middle)
    scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -10)
    scroll:SetPoint("BOTTOMRIGHT", -14, 0)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    Panel.AttachScrollLine(scroll, middle)
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
    local turnOn = PanelButton(off)
    turnOn:SetSize(160, 26)
    turnOn:SetPoint("TOP", off.text, "BOTTOM", 0, -16)
    turnOn:SetText(S:WindowText("moduleOffCard2", L["Turn On"]))
    turnOn:SetScript("OnClick", function()
        ns.ButtonSound()
        S.modules[current]:SetOn(true)
        UpdateNav()
        Panel:Refresh()
    end)
    off:Hide()
    page.offCard = off

    -- right column; a custom tab with preview takes it over
    preview.host = CreateFrame("Frame", nil, right)
    preview.host:SetAllPoints()
    preview.host:Hide()
    preview.picture = right:CreateTexture(nil, "ARTWORK")
    preview.picture:SetPoint("TOP", 0, -PAD)
    preview.picture:SetTexture(PICTURE)
    preview.picture:SetSize(RIGHT_W - 2 * PAD, RIGHT_W - 2 * PAD)
    -- the dog's bronze rim and soft shade, as the header logo's (11-11 Marcus); they come and go with it
    local pictureRim = right:CreateTexture(nil, "ARTWORK", nil, -2)
    -- (our 256 px ring, shown near its own size: smooth, 11-11)
    pictureRim:SetTexture("Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Panel\\PictureRim.tga")
    pictureRim:SetPoint("CENTER", preview.picture, "CENTER")
    pictureRim:SetSize(RIGHT_W - 2 * PAD - 2, RIGHT_W - 2 * PAD - 2)   -- about 5 px of bronze past the art
    pictureRim:SetVertexColor(0.78, 0.6, 0.34)
    local pictureShade = right:CreateTexture(nil, "ARTWORK", nil, -3)
    pictureShade:SetTexture("Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Panel\\PictureShade.tga")
    pictureShade:SetPoint("CENTER", preview.picture, "CENTER")
    pictureShade:SetSize(RIGHT_W - 2 * PAD + 12, RIGHT_W - 2 * PAD + 12)
    pictureShade:SetVertexColor(0, 0, 0, 1)
    local function FollowPicture()
        local shown = preview.picture:IsShown()
        pictureRim:SetShown(shown)
        pictureShade:SetShown(shown)
    end
    hooksecurefunc(preview.picture, "Show", FollowPicture)
    hooksecurefunc(preview.picture, "Hide", FollowPicture)
    hooksecurefunc(preview.picture, "SetShown", FollowPicture)
    preview.canvas = ns.SettingsPreview.Create(right, RIGHT_W - 2 * PAD, RIGHT_W - 2 * PAD)   -- 256 square
    -- (11-10: no "Preview" label or Pause button; the picture starts at the top)
    preview.canvas.frame:SetPoint("TOP", 0, -PAD)
    preview.canvas.frame:Hide()
    -- the gamepad never stops on the pictures' sample buttons (they are only pictures)
    preview.canvas.frame.padSkip = true
    preview.title = Text(right, "GameFontNormalLarge")
    preview.title:SetTextColor(TITLE_YELLOW[1], TITLE_YELLOW[2], TITLE_YELLOW[3])
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

    -- reload bar, hanging below the window
    local footer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    footer:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 4)
    footer:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, 4)
    -- taller than the bar it shows: the window's bronze frame covers its top (FOOTER_RISE), and the
    -- frame's bottom right rivet hangs past it
    footer:SetHeight(FOOTER_H + 8 + FOOTER_RISE)
    footer:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16 })
    footer:SetBackdropBorderColor(style.border[1], style.border[2], style.border[3], 1)
    ns.Fade(footer, 4, { 0.16, 0.13, 0.08, 0.98 }, { 0.07, 0.06, 0.04, 0.98 })
    -- changes that need a reload: the bar turns red, as a warning should
    footer.alert = footer:CreateTexture(nil, "BACKGROUND", nil, 2)
    footer.alert:SetPoint("TOPLEFT", 4, -4)
    footer.alert:SetPoint("BOTTOMRIGHT", -4, 4)
    footer.alert:SetColorTexture(1, 1, 1)
    footer.alert:SetGradient("VERTICAL", CreateColor(0.32, 0.03, 0.02, 0.85), CreateColor(0.55, 0.07, 0.04, 0.85))
    footer.alert:Hide()
    footer:Hide()
    frame.footer = footer
    -- clamps the window with its bar
    frame:SetClampRectInsets(0, 0, 0, -(FOOTER_H + 4 + FOOTER_RISE))
    -- centred in the part below the bronze frame; the button clear of the rivet
    frame.footerText = Text(footer, "GameFontHighlight")
    frame.footerText:SetPoint("LEFT", PAD + 4, -FOOTER_RISE / 2 - 1)
    frame.reload = PanelButton(footer)
    frame.reload:SetPoint("RIGHT", -PAD - 10, -FOOTER_RISE / 2 - 1)
    frame.reload:SetText(S:WindowText("reloadFooter2", L["Reload Now"]))
    frame.reload:SetSize(ButtonWidthForText(frame.reload, 130), 22)
    frame.reload:SetScript("OnClick", function()
        ns.ButtonSound()
        ns.ShowDialog("FLAREUI_RELOAD")
    end)

    S:On("RowChanged", function(row)
        if Panel.toggleHold then Panel.toggleRefreshPending = true else Panel:Refresh() end
        -- Refresh recycles row controls; re-render only when this was a visual settings change.
        if frame:IsShown() and ns.SettingsPreview.Resolve(row) then ShowRowPreview(row) end
    end)
    S:On("ReloadChanged", UpdateFooter)

    -- combat decides the Edit buttons, and its end lets the secure reload button be placed. Only the
    -- buttons are touched: a full Refresh would drop an open menu, a key capture and the radial
    -- editor's Undo. They wait a frame on the way in: the lockdown may not have begun yet.
    local function UpdateEditButtons()
        if not frame:IsShown() then return end
        local canEdit = S:CanEditFrames() and true or false
        for _, f in ipairs(used) do
            local row = f.row
            if f.edit and row then
                local real = f.kind ~= "frame" or (row:Get() and row.frame and row.frame() ~= nil)
                f.edit:SetEnabled(canEdit and real and true or false)
            end
        end
        if page.editMode:IsShown() and not page.editMode.customClick then page.editMode:SetEnabled(canEdit) end
        local module = S.modules[current]
        if module and module.bannerEditMode then page.banner.button:SetEnabled(canEdit) end
    end
    local combat = CreateFrame("Frame")
    combat:RegisterEvent("PLAYER_REGEN_ENABLED")
    combat:RegisterEvent("PLAYER_REGEN_DISABLED")
    combat:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            PlaceSecureReload()
            UpdateEditButtons()
        else
            C_Timer.After(0, UpdateEditButtons)
        end
    end)

    -- Gamepad UI: the window with the controller (PadNav.lua). LB / RB step the page's tabs, LT / RT
    -- the pages in the list's order; focus starts on the page's content.
    local function Step(list, isCurrent, delta)
        local at
        for i, b in ipairs(list) do if isCurrent(b) then at = i end end
        if #list == 0 then return end
        local target = list[at and ((at - 1 + delta) % #list) + 1 or 1]
        target:Click()
    end
    ns.PadNav.Attach(frame, {
        close = function() frame:Hide() end,
        tab = function(delta)
            local tabs = {}
            for _, b in ipairs(page.tabButtons) do if b:IsShown() then tabs[#tabs + 1] = b end end
            Step(tabs, function(b) return b.tabKey == currentTab[current] or (not currentTab[current] and b == tabs[1]) end, delta)
        end,
        page = function(delta)
            local list = {}
            for _, b in pairs(navButtons) do list[#list + 1] = b end
            table.sort(list, function(a, b) return (a:GetTop() or 0) > (b:GetTop() or 0) end)
            local selected = navButtons[current]
            Step(list, function(b) return b == selected end, delta)
        end,
        start = function() return page.scroll:IsShown() and page.scroll or nil end,
    })
end

--------------------------------------------------
-- 8. OPENING
--------------------------------------------------
-- mode: "settings" or "whatsnew"
function Panel:SetMode(mode)
    if not frame then return end
    local news = mode == "whatsnew"
    if news then S:Fire("PageShown", nil) elseif current then S:Fire("PageShown", current) end
    if news then SetWide(false) end
    frame.body:SetShown(not news)
    frame.news:SetShown(news)
    for _, b in ipairs(frame.topTabs) do if b.SetSelected then b:SetSelected(b.mode == mode) end end
    if not news then self:Refresh() end
end

function Panel:Open(key, tabKey)
    if not frame then BuildWindow() end
    if key and tabKey then currentTab[key] = tabKey end
    -- Blizzard's options window (Options > AddOns > Open Configuration) is left open under FlareUI's:
    -- hiding it from here would skip its own close, where key bindings and Apply settings are saved,
    -- and closing it the proper way from addon code would run that save tainted
    key = key or current or (ns.db and ns.db.global and ns.db.global.settingsPage) or "about"
    if not S.modules[key] then key = "about" end
    current = key
    -- one redraw, by Select: showing the window and its mode would each draw the page first
    self.opening = true
    frame:Show()
    self:SetMode("settings")
    self.opening = nil
    self:Select(key)
end

function Panel:OpenWhatsNew()
    self.holdNewSeen = true
    self:Open()
    self.holdNewSeen = nil
    self:SetMode("whatsnew")
end

-- What's new opens once after an update (a fresh install gets the welcome instead)
do
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("PLAYER_LOGIN")
    loader:SetScript("OnEvent", function()
        local global = ns.db and ns.db.global
        local version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
        if not (global and version) or global.whatsNewSeen == version then return end
        local update = global.welcomeSeen and global.whatsNewSeen ~= nil
        -- a fresh install has no NEW badges
        if global.whatsNewSeen == nil then S:MarkAllNewSeen() end
        global.whatsNewSeen = version
        -- not in the Gamepad UI, where the window can't be used with the controller; it stays on the
        -- About page
        -- Don't Show on Login (the What's New footer) keeps it shut
        if update and not global.whatsNewQuiet and ns.WhatsNew and ns.WhatsNew[1] and not ns.IsGamepadUI() then
            C_Timer.After(4, function()
                if not InCombatLockdown() then Panel:OpenWhatsNew() return end
                -- logged in during a fight: the notes wait for its end instead of being skipped
                loader:RegisterEvent("PLAYER_REGEN_ENABLED")
                loader:SetScript("OnEvent", function()
                    loader:UnregisterEvent("PLAYER_REGEN_ENABLED")
                    if not ns.IsGamepadUI() then Panel:OpenWhatsNew() end
                end)
            end)
        end
    end)
end

function Panel:Toggle(key)
    if frame and frame:IsShown() then frame:Hide() else self:Open(key) end
end

-- closes without the reload reminder (for Edit Mode, which reopens the panel)
function Panel:Hide()
    if not frame then return end
    Panel.quietHide = true
    frame:Hide()
    Panel.quietHide = nil
end

function Panel:IsShown()
    return frame and frame:IsShown() or false
end
