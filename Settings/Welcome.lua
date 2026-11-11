local _, ns = ...
local L = ns.L

--------------------------------------------------
-- WELCOME
-- Every module ships off. The first login with none on opens the setup tour: ten pages that show
-- each module and collect the player's choices, written only by the last page's reload. Closing the
-- tour changes nothing. The Gamepad UI keeps a small pop-up instead (its navigation is still alpha).
-- 11-11 (Marcus): the settings window's look throughout: its stone and heavy bronze frame, Friz
-- Quadrata titles over Roboto Condensed, section boxes, stone switches, the real previews of the Info
-- Panel (each module's own sample) and the round game icons.
--------------------------------------------------
local BANNER = "Interface\\AddOns\\FlareUI\\Media\\Art\\Banner.png"
local LOGO = "Interface\\AddOns\\FlareUI\\Media\\Art\\Icon.png"
local CIRCLE = "Interface\\AddOns\\FlareUI\\Media\\Panel\\Circle.tga"
local WHITE = "Interface\\Buttons\\WHITE8x8"

local TITLE_GOLD = { 1, 0.83, 0.47 }      -- page titles (the settings window's)
local SECTION_GOLD = { 0.91, 0.77, 0.42 } -- card titles (its section titles)
local MUTED = { 0.72, 0.68, 0.61 }

local function Kit() return ns.SettingsPanel end

-- an account with any module on has no need for it
local function AnyModuleEnabled()
    local S = ns.Settings
    if not (S and ns.db and ns.db.profile) then return false end
    for _, module in pairs(S.modules) do
        if module.enabled and module:IsOn() then return true end
    end
    return false
end

-- the settings window's stone, frame and corner close button
local function WindowBase(name, width, height)
    local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    f:SetSize(width, height)
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f.close = Kit().DressWindow(f)
    f:Hide()
    tinsert(UISpecialFrames, name)
    return f
end

local function PanelButton(parent, text, width, height, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    if ns.SkinButton then ns.SkinButton(b) end
    b:SetSize(width, height)
    b:SetText(text)
    b:SetScript("OnClick", function()
        ns.ButtonSound()
        onClick()
    end)
    return b
end

-- the window's own fonts: Blizzard's names map to the settings window's (Panel.FONT)
local FONT_FOR = { GameFontHighlightMedium = "GameFontHighlight" }
local function Say(parent, font, text, width)
    font = font or "GameFontHighlight"
    font = FONT_FOR[font] or font
    local fs = parent:CreateFontString(nil, "OVERLAY", Kit().FONT[font] or font)
    fs:SetJustifyH("LEFT")
    fs:SetSpacing(3)
    if width then fs:SetWidth(width) end
    fs:SetText(text or "")
    return fs
end

-- the round dog with its bronze rim (the Info Panel's)
local function Banner(parent, size)
    local banner = parent:CreateTexture(nil, "ARTWORK")
    banner:SetTexture(BANNER)
    banner:SetSize(size, size)
    Kit().RimPicture(parent, banner, size >= 120 and -1 or 1)
    return banner
end

--------------------------------------------------
-- 1. THE SMALL POP-UP (Gamepad UI)
--------------------------------------------------
local small

local function ShowSmallWelcome()
    if small then small:Show() return end
    small = WindowBase("FlareUI_Welcome", 420, 360)
    small:SetPoint("CENTER", 0, 80)
    small:SetFrameStrata("FULLSCREEN_DIALOG")
    small:SetScript("OnShow", ns.WindowOpenSound)
    -- seen however it closes (either button or Escape)
    small:SetScript("OnHide", function()
        ns.WindowCloseSound()
        if ns.db and ns.db.global then ns.db.global.welcomeSeen = true end
    end)

    local banner = Banner(small, 120)
    banner:SetPoint("TOP", 0, -26)

    local title = Say(small, "GameFontNormalHuge", L["Welcome to FlareUI!"])
    title:SetTextColor(TITLE_GOLD[1], TITLE_GOLD[2], TITLE_GOLD[3])
    title:SetPoint("TOP", banner, "BOTTOM", 0, -16)

    local subtitle = Say(small, "GameFontHighlight", L["Your friendly UI overhowl"])
    subtitle:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -6)

    local body = Say(small, "GameFontHighlight", L["Every module of this addon starts switched off.\nTo begin, open the settings and enable the modules you want to use."], 350)
    body:SetPoint("TOP", subtitle, "BOTTOM", 0, -14)
    body:SetJustifyH("CENTER")

    local open = PanelButton(small, L["Open Settings"], 150, 28, function()
        small:Hide()
        ns.SettingsPanel:Open()
    end)
    open:SetPoint("BOTTOMRIGHT", small, "BOTTOM", -5, 24)
    local close = PanelButton(small, CLOSE or "Close", 150, 28, function() small:Hide() end)
    close:SetPoint("BOTTOMLEFT", small, "BOTTOM", 5, 24)
    -- the controller: D-pad between the two buttons, A presses, B closes (PadNav.lua)
    if ns.PadNav then ns.PadNav.Attach(small, { close = function() small:Hide() end }) end
    small:Show()
end

--------------------------------------------------
-- 2. TOUR: THE PIECES
--------------------------------------------------
local WIDTH, HEIGHT = 760, 560
local SIDE = 28                 -- the window's left and right margin
local BODY_W = WIDTH - 2 * SIDE
local BODY_TOP = -104           -- from the window's top to a page's content
local BODY_H = 382              -- a page's content height, above the footer
local GAP = 12                  -- between cards
local CARD_PAD = 14
local CARD_W2 = (BODY_W - GAP) / 2
local CARD_W3 = (BODY_W - 2 * GAP) / 3

-- The store art, cropped into power-of-two files: the picture is the top left w x h of the file. Shown
-- only where a module's own sample can't be drawn (a module that has never run).
local ART_PATH = "Interface\\AddOns\\FlareUI\\Media\\Art\\Tour\\"
local ART = {
    StyleFlareUI = { 432, 160, 512, 256 },
    StyleForever = { 480, 155, 512, 256 },
    StyleAddon   = { 355, 100, 512, 128 },
    ActionBars   = { 920, 195, 1024, 256 },
    Chat         = { 420, 205, 512, 256 },
    Meter        = { 425, 205, 512, 256 },
    Minimap      = { 280, 285, 512, 512 },
    Quests       = { 240, 335, 256, 512 },
    Radial       = { 500, 500, 512, 512 },
}

local tour = { step = 1, ticks = {}, choices = {} }

-- The module switches the tour sets, in the finish page's order
local MODULE_KEYS = { "uf", "ab", "au", "rb", "rm", "qol", "ch", "dm", "mm", "qt", "tt" }

local function Title(key)
    return ns.Settings.modules[key]:Title()
end

local function Bullets(lines)
    local parts = {}
    for i, line in ipairs(lines) do parts[i] = "\226\128\162 " .. line end
    return table.concat(parts, "\n")
end

-- A picture fitted inside its box (the fallback for a preview)
local function Picture(parent, name, width, height)
    local box = CreateFrame("Frame", nil, parent)
    box:SetSize(width, height)
    local a = ART[name]
    local scale = math.min(width / a[1], height / a[2])
    local tex = box:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(ART_PATH .. name .. ".png")
    tex:SetTexCoord(0, a[1] / a[3], 0, a[2] / a[4])
    tex:SetSize(a[1] * scale, a[2] * scale)
    tex:SetPoint("CENTER")
    return box
end

-- A module's own sample, as the settings' Info Panel draws it (Settings/Preview.lua), centred in its
-- box; the store picture when the module can't draw one. Drawn each time its page shows.
local function Preview(parent, kind, key, width, height, art)
    local box = CreateFrame("Frame", nil, parent)
    box:SetSize(width, height)
    local P = ns.SettingsPreview
    function box.Draw()
        local ok = false
        if P then
            if not box.canvas then
                box.canvas = P.Create(box, width, height)
                box.canvas.quiet = true   -- a failed sample falls back to the picture, unreported
            end
            ok = P.Show(box.canvas, { kind = kind, key = key })
            if ok then
                local used = box.canvas.used or height
                box.canvas.frame:ClearAllPoints()
                box.canvas.frame:SetPoint("TOP", box, "TOP", 0, -math.max(0, (height - used) / 2))
            end
        end
        if not ok and art and not box.picture then
            box.picture = Picture(box, art, width, height)
            box.picture:SetPoint("CENTER")
        end
        if box.picture then box.picture:SetShown(not ok) end
    end
    local list = parent.previews or (parent:GetParent() and parent:GetParent().previews)
    if list then list[#list + 1] = box end
    return box
end

-- A section box (the settings window's), with a gold Friz title when given
local function Card(parent, x, y, width, height, title)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetPoint("TOPLEFT", x, y)
    card:SetSize(width, height)
    Kit().Box(card, 0.34)
    card.inner = width - 2 * CARD_PAD
    card.previews = parent.previews
    if title then
        local t = Say(card, "GameFontNormalLarge", title, card.inner)
        t:SetTextColor(SECTION_GOLD[1], SECTION_GOLD[2], SECTION_GOLD[3])
        t:SetPoint("TOPLEFT", CARD_PAD, -CARD_PAD + 2)
        card.last = t
        local rule = card:CreateTexture(nil, "ARTWORK")
        rule:SetColorTexture(0.47, 0.36, 0.22, 0.8)
        rule:SetHeight(1)
        rule:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -7)
        rule:SetPoint("RIGHT", card, "RIGHT", -CARD_PAD, 0)
        card.last = rule
        card.lastGap = 10
    end
    return card
end

-- Puts a region under the card's last one
local function Stack(card, region, gap)
    if card.last then
        region:SetPoint("TOPLEFT", card.last, "BOTTOMLEFT", 0, -(gap or card.lastGap or 8))
        card.lastGap = nil
    else
        region:SetPoint("TOPLEFT", card, "TOPLEFT", CARD_PAD, -CARD_PAD)
    end
    card.last = region
    return region
end

local function RefreshTicks()
    for _, tick in ipairs(tour.ticks) do
        local on = not tick.needs or tour.choices[tick.needs]
        tick:SetChecked(tour.choices[tick.key] and true or false)
        tick:SetEnabled(on and true or false)
        tick:SetAlpha(on and 1 or 0.45)
        tick.label:SetAlpha(on and 1 or 0.45)
    end
    if tour.RefreshStyles then tour.RefreshStyles() end
end

-- A switch for tour.choices[key] (the settings window's stone switch), its label to the right; needs:
-- greyed while that other choice is off
local function Tick(parent, key, label, needs)
    local tick = Kit().Switch(parent)
    tick.key, tick.needs = key, needs
    local text = Say(parent, "GameFontNormal", label)
    text:SetTextColor(TITLE_GOLD[1], TITLE_GOLD[2], TITLE_GOLD[3])
    text:SetPoint("LEFT", tick, "RIGHT", 8, 0)
    tick.label = text
    tick:SetHitRectInsets(0, -(text:GetStringWidth() + 10), 0, 0)
    tick:SetScript("OnClick", function(self)
        local on = self:GetChecked() and true or false
        PlaySound(on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        tour.choices[key] = on
        RefreshTicks()
    end)
    tour.ticks[#tour.ticks + 1] = tick
    return tick
end

-- The "Use it" switch at a card's bottom
local function CardTick(card, key)
    local tick = Tick(card, key, L["Use It"])
    tick:SetPoint("BOTTOMLEFT", CARD_PAD, CARD_PAD)
    return tick
end

-- A module's card: its name, its sample, a few lines and its switch
local function ModuleCard(page, x, key, kind, sample, art, previewHeight, lines)
    local card = Card(page, x, 0, CARD_W2, BODY_H, Title(key))
    Stack(card, Preview(card, kind, sample, card.inner, previewHeight, art))
    Stack(card, Say(card, "GameFontHighlight", Bullets(lines), card.inner), 10)
    CardTick(card, key)
    return card
end

--------------------------------------------------
-- 3. TOUR: THE PAGES
--------------------------------------------------
local BuildPage = {}

local function NextStep() tour.Show(tour.step + 1) end

local function CloseTour() tour.window:Hide() end

-- 1: welcome and the way out
function BuildPage.welcome(page)
    local banner = Banner(page, 150)
    banner:SetPoint("TOP", 0, -46)

    local title = Say(page, "GameFontNormalHuge", L["Welcome to FlareUI!"])
    title:SetTextColor(TITLE_GOLD[1], TITLE_GOLD[2], TITLE_GOLD[3])
    title:SetPoint("TOP", banner, "BOTTOM", 0, -22)

    local subtitle = Say(page, "GameFontHighlight", L["Your friendly UI overhowl"])
    subtitle:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -6)

    local body = Say(page, "GameFontHighlight", L["Everything starts switched off. This short tour shows you what each part does, and you choose the ones you want as you go."], 500)
    body:SetPoint("TOP", subtitle, "BOTTOM", 0, -20)
    body:SetJustifyH("CENTER")

    local minWidth = 260
    local start = PanelButton(page, L["Show Me Around"], minWidth, 36, NextStep)
    start:SetPoint("BOTTOM", 0, 92)

    local skip = PanelButton(page, L["Skip, I know what I'm doing"], minWidth, 28, CloseTour)
    skip:SetPoint("TOP", start, "BOTTOM", 0, -10)

    local width = math.max(
        ns.Settings.ButtonWidthForText(start, minWidth),
        ns.Settings.ButtonWidthForText(skip, minWidth)
    )
    start:SetWidth(width)
    skip:SetWidth(width)

    local hint = Say(page, "GameFontDisableSmall", L["Settings are always on /fui."])
    hint:SetPoint("TOP", skip, "BOTTOM", 0, -12)
end

-- 2: unit frames and their style: the three styles drawn by the frames' own code
function BuildPage.unitFrames(page)
    local tick = Tick(page, "uf", L["Use FlareUI's unit frames"])
    tick:SetPoint("TOPLEFT", 0, -2)

    local ask = Say(page, "GameFontHighlight", L["Which style do you like best?"])
    ask:SetPoint("TOPLEFT", 0, -38)

    local styles = {
        { value = "flareui", art = "StyleFlareUI", name = L["FlareUI Style"], text = L["The bronze ring beside FlareUI's bars."] },
        { value = "forever", art = "StyleForever", name = L["Forever Style"], text = L["Blizzard's bronze frame and portrait ring."] },
        { value = "addon",   art = "StyleAddon",   name = L["Addon Style"],   text = L["Plain frames, the most options."] },
    }
    local cards = {}
    local row = ns.Settings.rows["uf.frameStyle"]
    for i, style in ipairs(styles) do
        -- the settings window's style card: a Thick edge, a bronze plate, lit when picked
        local card = CreateFrame("Button", nil, page)
        card:SetPoint("TOPLEFT", (i - 1) * (CARD_W3 + GAP), -64)
        card:SetSize(CARD_W3, 230)
        Kit().ThickEdge(card)
        card.plate = card:CreateTexture(nil, "BACKGROUND")
        card.plate:SetPoint("TOPLEFT", 4, -4)
        card.plate:SetPoint("BOTTOMRIGHT", -4, 4)
        card.plate:SetColorTexture(1, 1, 1)
        card.value = style.value
        -- the frame itself, in this style
        local well = CreateFrame("Frame", nil, card)
        well:SetPoint("TOPLEFT", CARD_PAD, -CARD_PAD)
        well:SetSize(CARD_W3 - 2 * CARD_PAD, 96)
        function well.Draw()
            local P = ns.SettingsPreview
            local ok = false
            if P and row then
                if not well.canvas then
                    well.canvas = P.Create(well, CARD_W3 - 2 * CARD_PAD, 96)
                    well.canvas.quiet, well.canvas.isStyleCard = true, true
                    well.canvas.frame:SetPoint("TOPLEFT")
                end
                ok = P.Style(well.canvas, row, style.value)
            end
            if not ok and not well.picture then
                well.picture = Picture(well, style.art, CARD_W3 - 2 * CARD_PAD, 80)
                well.picture:SetPoint("CENTER")
            end
            if well.picture then well.picture:SetShown(not ok) end
        end
        page.previews[#page.previews + 1] = well
        local name = Say(card, "GameFontNormalLarge", style.name, CARD_W3 - 2 * CARD_PAD)
        name:SetPoint("TOPLEFT", well, "BOTTOMLEFT", 0, -14)
        name:SetJustifyH("CENTER")
        card.name = name
        local text = Say(card, "GameFontHighlight", style.text, CARD_W3 - 2 * CARD_PAD)
        text:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -8)
        text:SetJustifyH("CENTER")
        text:SetTextColor(0.85, 0.82, 0.76)
        card.tick = card:CreateTexture(nil, "OVERLAY")
        card.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        card.tick:SetSize(22, 22)
        card.tick:SetPoint("TOPRIGHT", -6, -6)
        function card:Paint()
            local picked = tour.choices.style == self.value
            if picked then
                self.edge:SetBackdropBorderColor(1, 0.84, 0.5, 1)
                self.plate:SetGradient("VERTICAL", CreateColor(0.13, 0.095, 0.055, 1), CreateColor(0.29, 0.21, 0.12, 1))
            elseif self.hovered then
                self.edge:SetBackdropBorderColor(0.78, 0.6, 0.34, 1)
                self.plate:SetGradient("VERTICAL", CreateColor(0.1, 0.075, 0.045, 1), CreateColor(0.21, 0.155, 0.09, 1))
            else
                self.edge:SetBackdropBorderColor(0.55, 0.42, 0.24, 1)
                self.plate:SetGradient("VERTICAL", CreateColor(0.07, 0.055, 0.035, 1), CreateColor(0.15, 0.11, 0.065, 1))
            end
            self.name:SetTextColor(picked and 1 or 0.85, picked and 0.89 or 0.79, picked and 0.63 or 0.66)
            self.tick:SetShown(picked)
        end
        card:SetScript("OnEnter", function(self) self.hovered = true self:Paint() end)
        card:SetScript("OnLeave", function(self) self.hovered = nil self:Paint() end)
        card:SetScript("OnClick", function()
            ns.ButtonSound()
            tour.choices.style = style.value
            RefreshTicks()
        end)
        cards[i] = card
    end
    function tour.RefreshStyles()
        local on = tour.choices.uf
        for _, card in ipairs(cards) do
            card:Paint()
            card:SetEnabled(on and true or false)
            card:SetAlpha(on and 1 or 0.45)
        end
    end

    local note = Say(page, "GameFontHighlight", L["You can switch any time, and each style keeps its own setup. Party and raid frames are switched on in /fui."], BODY_W)
    note:SetPoint("TOPLEFT", 0, -312)
    note:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
end

-- 3: the three small modules of the HUD, each with its own sample
function BuildPage.bars(page)
    local top = Card(page, 0, 0, BODY_W, 110)
    local buttons = Preview(top, "actions", "ab.overview", BODY_W - 2 * CARD_PAD, 82, "ActionBars")
    buttons:SetPoint("TOPLEFT", CARD_PAD, -14)
    local entries = {
        { key = "ab", text = L["Blizzard's bars, sharpened: red when out of range, blue with no mana, glows on procs."] },
        { key = "au", kind = "auras", sample = "au.overview", height = 70, text = L["Your buffs and debuffs in FlareUI's style, with clear timers."] },
        { key = "rb", kind = "resources", sample = "rb.health", height = 40, text = L["Extra health, power, combo point and swing bars to place anywhere. Off to begin with: choose your bars in /fui."] },
    }
    for i, entry in ipairs(entries) do
        local card = Card(page, (i - 1) * (CARD_W3 + GAP), -122, CARD_W3, BODY_H - 122, Title(entry.key))
        if entry.kind then Stack(card, Preview(card, entry.kind, entry.sample, card.inner, entry.height)) end
        local text = Stack(card, Say(card, "GameFontHighlight", entry.text, card.inner), 10)
        text:SetTextColor(0.85, 0.82, 0.76)
        CardTick(card, entry.key)
    end
end

-- 4: nothing to choose: the two places options live
function BuildPage.editMode(page)
    local left = Card(page, 0, 0, CARD_W2, BODY_H, L["Edit Mode"])
    local scene = CreateFrame("Frame", nil, left, "BackdropTemplate")
    scene:SetSize(left.inner, 112)
    Kit().Box(scene, 0.6)
    Stack(left, scene)
    -- Blizzard's blue selection on a frame, and its settings dialog beside it
    local selected = CreateFrame("Frame", nil, scene, "BackdropTemplate")
    selected:SetSize(130, 48)
    selected:SetPoint("CENTER", -52, 0)
    selected:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 2 })
    selected:SetBackdropColor(0.24, 0.59, 1, 0.28)
    selected:SetBackdropBorderColor(0.29, 0.64, 1, 1)
    local selectedText = Say(selected, "GameFontHighlight", L["Player Frame"])
    selectedText:SetPoint("CENTER")
    local dialog = CreateFrame("Frame", nil, scene, "BackdropTemplate")
    dialog:SetSize(92, 68)
    dialog:SetPoint("LEFT", selected, "RIGHT", 14, 0)
    Kit().Box(dialog, 0.85)
    for i = 1, 4 do
        local bar = dialog:CreateTexture(nil, "ARTWORK")
        bar:SetPoint("TOPLEFT", 10, -10 - (i - 1) * 13)
        bar:SetSize(72, 5)
        if i == 1 then bar:SetColorTexture(0.8, 0.6, 0.34, 1) else bar:SetColorTexture(0.42, 0.35, 0.26, 1) end
    end
    Stack(left, Say(left, "GameFontHighlight", L["Press |cffffd100Esc|r, then choose |cffffd100Edit Mode|r. Click anything on your screen to move it and change its size and look."], left.inner), 12)
    local here = Stack(left, Say(left, "GameFontNormal", L["Unit frames and bars are set up here."], left.inner), 12)
    here:SetTextColor(TITLE_GOLD[1], TITLE_GOLD[2], TITLE_GOLD[3])

    local right = Card(page, CARD_W2 + GAP, 0, CARD_W2, BODY_H, L["FlareUI Settings"])
    local command = CreateFrame("Frame", nil, right, "BackdropTemplate")
    command:SetSize(right.inner, 112)
    Kit().Box(command, 0.6)
    Stack(right, command)
    local commandText = Say(command, "GameFontNormalHuge", "/fui")
    commandText:SetTextColor(TITLE_GOLD[1], TITLE_GOLD[2], TITLE_GOLD[3])
    commandText:SetPoint("CENTER")
    Stack(right, Say(right, "GameFontHighlight", L["Type |cffffd100/fui|r in chat. Turn parts of FlareUI on or off, and find everything that isn't a frame on your screen: chat options, tooltips, the radial menu."], right.inner), 12)
    local rest = Stack(right, Say(right, "GameFontNormal", L["The rest is set up here."], right.inner), 12)
    rest:SetTextColor(TITLE_GOLD[1], TITLE_GOLD[2], TITLE_GOLD[3])
end

-- 5: the FlareUI Edit Mode layout, imported by the player in Blizzard's own dialog
function BuildPage.layout(page)
    local left = Card(page, 0, 0, CARD_W2, BODY_H, L["Use Our Layout"])
    Stack(left, Say(left, "GameFontHighlight", L["Want your screen set up like ours? Import the FlareUI layout into Edit Mode:"], left.inner))
    Stack(left, Say(left, "GameFontHighlight", table.concat({
        "|cffffd1001.|r " .. L["Click |cffffd100Copy Layout Code|r and press |cffffd100Ctrl+C|r."],
        "|cffffd1002.|r " .. L["Press |cffffd100Esc|r and choose |cffffd100Edit Mode|r."],
        "|cffffd1003.|r " .. L["Open the |cffffd100Layout|r menu and choose |cffffd100Import|r."],
        "|cffffd1004.|r " .. L["Paste with |cffffd100Ctrl+V|r, name it and click |cffffd100Import|r."],
    }, "\n"), left.inner), 12)
    local copy = ns.EditModeLayout.Button(left, 190)
    copy:SetPoint("BOTTOM", left, "BOTTOM", 0, CARD_PAD)

    local right = Card(page, CARD_W2 + GAP, 0, CARD_W2, BODY_H, L["Good to Know"])
    Stack(right, Say(right, "GameFontHighlight", Bullets({
        L["It's saved and switched on right away"],
        L["Your old layout stays: switch back any time from the Layout menu"],
        L["FlareUI's own frames already sit where the layout expects them"],
        L["Made for the default UI scale. Wider screens just get more room at the sides"],
    }), right.inner))
    local about = Stack(right, Say(right, "GameFontHighlight", L["It's also at the bottom of the About page in /fui."], right.inner), 16)
    about:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
end

-- 6: the two windows
function BuildPage.chatMeter(page)
    ModuleCard(page, 0, "ch", "chat", "ch.overview", "Chat", 196, {
        L["A header with your tabs and buttons"],
        L["Saved history, so a reload keeps your chat"],
        L["Tooltips when you hover links"],
    })
    ModuleCard(page, CARD_W2 + GAP, "dm", "meter", "dm.overview", "Meter", 196, {
        L["Blizzard's meter in a FlareUI frame"],
        L["A Threat tab, so you know when to stop"],
        L["Moves and resizes in Edit Mode"],
    })
end

-- 7: where you are, what you're doing
function BuildPage.mapQuests(page)
    ModuleCard(page, 0, "mm", "minimap", "mm.overview", "Minimap", 196, {
        L["A square map with Forever's day and night cycle"],
        L["Zone, clock and coordinates on the map"],
        L["All your addon buttons tucked into one bag"],
    })
    ModuleCard(page, CARD_W2 + GAP, "qt", "tracker", "qt.overview", "Quests", 196, {
        L["Your quests grouped by zone"],
        L["Colours show how hard each quest is"],
        L["Gets out of the way in combat"],
    })
end

-- 8: the radial, and the key it still needs
function BuildPage.radial(page)
    local wheel = Card(page, 0, 0, 300, BODY_H)
    local art = Preview(wheel, "radial", "rm.overview", 300 - 2 * CARD_PAD, BODY_H - 2 * CARD_PAD, "Radial")
    art:SetPoint("TOPLEFT", CARD_PAD, -CARD_PAD)
    local x = 300 + GAP
    local card = Card(page, x, 0, BODY_W - x, BODY_H, L["Hold, point, release"])
    Stack(card, Say(card, "GameFontHighlight", L["Hold your key and a ring of buttons opens at your cursor. Point at one, let go, and it fires. It even works in combat."], card.inner))
    Stack(card, Say(card, "GameFontHighlight", Bullets({
        L["Spells, items, mounts, macros and raid markers"],
        L["Radials inside radials"],
        L["Or open it with a press instead of a hold"],
    }), card.inner), 12)
    local key = Stack(card, Say(card, "GameFontNormal", L["It needs a key. After the reload, FlareUI opens the page where you choose one."], card.inner), 14)
    key:SetTextColor(TITLE_GOLD[1], TITLE_GOLD[2], TITLE_GOLD[3])
    CardTick(card, "rm")
end

-- 9: the helpers
function BuildPage.qol(page)
    local tick = Tick(page, "qol", L["Use Quality of Life"])
    tick:SetPoint("TOPLEFT", 0, -2)
    local height = BODY_H - 38

    local left = Card(page, 0, -38, CARD_W2, height, L["Move Any Window"])
    Stack(left, Say(left, "GameFontHighlight", L["Drag a Blizzard window by its header to move it. |cffffd100Ctrl|r + mouse wheel resizes it, and |cffffd100Shift|r + right-click puts it back."], left.inner))
    local move = Tick(left, "move", L["Use It"], "qol")
    Stack(left, move, 10)
    local syncName = Say(left, "GameFontNormalLarge", L["Sync Blizz UI"], left.inner)
    syncName:SetTextColor(SECTION_GOLD[1], SECTION_GOLD[2], SECTION_GOLD[3])
    syncName:SetPoint("TOPLEFT", move, "BOTTOMLEFT", 0, -22)
    local syncText = Say(left, "GameFontHighlight", L["Got alts? Copies one character's interface options, Edit Mode layout, chat and bag settings to your others."], left.inner)
    syncText:SetPoint("TOPLEFT", syncName, "BOTTOMLEFT", 0, -10)
    local sync = Tick(left, "sync", L["Use It"], "qol")
    sync:SetPoint("TOPLEFT", syncText, "BOTTOMLEFT", 0, -10)

    local right = Card(page, CARD_W2 + GAP, -38, CARD_W2, height, L["Also in There"])
    Stack(right, Say(right, "GameFontHighlight", Bullets({
        L["Faster Auto Loot"],
        L["A Train All button at trainers"],
        L["A camera that zooms out further"],
        L["Map pins with /way"],
        L["Alert sounds for ready checks and invites"],
    }), right.inner))
    local pick = Stack(right, Say(right, "GameFontHighlight", L["Pick them in /fui, Quality of Life."], right.inner), 8)
    pick:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
    local tt = Stack(right, Say(right, "GameFontNormalLarge", Title("tt"), right.inner), 20)
    tt:SetTextColor(SECTION_GOLD[1], SECTION_GOLD[2], SECTION_GOLD[3])
    Stack(right, Say(right, "GameFontHighlight", L["Cleaner tooltips with coloured borders."], right.inner), 8)
    CardTick(right, "tt")
end

-- 10: the choices (each module with its round icon, lit when on), and what to try after the reload
function BuildPage.finish(page)
    local summary = Card(page, 0, 0, BODY_W, 214, L["What you turned on"])
    local rows = {}
    local columnW = summary.inner / 2
    for i, key in ipairs(MODULE_KEYS) do
        local holder = CreateFrame("Frame", nil, summary)
        holder:SetSize(columnW - 8, 26)
        holder:SetPoint("TOPLEFT", CARD_PAD + (i - 1) % 2 * columnW, -48 - math.floor((i - 1) / 2) * 27)
        holder.icon = Kit().ModuleIcon(holder, key, 22)
        holder.icon:SetPoint("LEFT", 0, 0)
        holder.text = Say(holder, "GameFontHighlight", "", columnW - 40)
        holder.text:SetPoint("LEFT", holder.icon, "RIGHT", 10, 0)
        holder.text:SetWordWrap(false)
        rows[key] = holder
    end
    local nothing = Say(summary, "GameFontHighlight", L["Nothing is on yet. Go back and tick something, or open the settings later with /fui."], summary.inner)
    nothing:SetPoint("TOPLEFT", CARD_PAD, -48)

    local after = Card(page, 0, -226, BODY_W, BODY_H - 226, L["Try These Next"])
    local tips = Stack(after, Say(after, "GameFontHighlight", "", after.inner))

    function page.Refresh()
        local c = tour.choices
        local any
        for _, key in ipairs(MODULE_KEYS) do
            local row = rows[key]
            local name = Title(key)
            if key == "uf" and c.uf then
                local styleNames = { flareui = L["FlareUI Style"], forever = L["Forever Style"], addon = L["Addon Style"] }
                name = name .. ": " .. (styleNames[c.style] or "")
            end
            row.text:SetText(name)
            local on = c[key] and true or false
            if on then any = true end
            row.text:SetTextColor(on and 1 or 0.55, on and 0.96 or 0.52, on and 0.88 or 0.47)
            row.icon:SetDesaturated(not on)
            row.icon:SetAlpha(on and 1 or 0.45)
            if row.icon.ftRing then row.icon.ftRing:SetAlpha(on and 1 or 0.45) end
        end
        for _, row in pairs(rows) do row:SetShown(any and true or false) end
        nothing:SetShown(not any)
        local lines = { L["Press |cffffd100Esc|r, then |cffffd100Edit Mode|r, and drag things where you want them"] }
        if c.rm then lines[#lines + 1] = L["Choose a key for your Radial Menu (the page opens after the reload)"] end
        lines[#lines + 1] = L["Type |cffffd100/fui|r whenever you want to change something"]
        tips:SetText(Bullets(lines))
    end
end

local PAGES = {
    { build = "welcome", bare = true },
    { build = "unitFrames", title = function() return Title("uf") end, lead = L["Your player, target, focus and pet frames, and the boss frames."] },
    { build = "bars", title = L["Bars and Buffs"], lead = L["The buttons and bars you look at all day."] },
    { build = "editMode", title = L["Where do the options live?"], lead = L["This is the one thing to remember: there are two places."] },
    { build = "layout", title = L["The FlareUI Layout"], lead = L["Your screen set up the way FlareUI is made to look."] },
    { build = "chatMeter", title = L["Chat and Damage Meter"], lead = L["Two windows that match, usually in the bottom corners of your screen."] },
    { build = "mapQuests", title = L["Minimap and Quests"], lead = L["Where you are, and what you're doing there."] },
    { build = "radial", title = function() return Title("rm") end, lead = L["Everything you need, one key away."] },
    { build = "qol", title = function() return Title("qol") end, lead = L["Small helpers that save you clicks."] },
    { build = "finish", title = L["Good dog. All done!"], lead = L["One reload and your choices take effect."] },
}

--------------------------------------------------
-- 4. TOUR: FINISHING
--------------------------------------------------
-- Writes the choices; the secure button's macro reloads right after
local function ApplyChoices()
    local S, c = ns.Settings, tour.choices
    local global = ns.db and ns.db.global
    if global then
        -- the reload skips the window's OnHide
        global.welcomeSeen = true
        -- newly on: the radial still has no key, so the first login opens the page for it
        if c.rm and not S.modules.rm:IsOn() then global.tourRadialKeys = true end
    end
    for _, key in ipairs(MODULE_KEYS) do
        local module = S.modules[key]
        if module then module:SetOn(c[key]) end
    end
    if c.uf then S.rows["uf.frameStyle"]:Set(c.style) end
    if c.qol then
        S.rows["qol.move"]:Set(c.move and true or false)
        S.rows["qol.sync"]:Set(c.sync and true or false)
    end
    -- FlareUI's meter restyles Blizzard's, which needs its own option on
    if c.dm and not C_CVar.GetCVarBool("damageMeterEnabled") then
        pcall(C_CVar.SetCVar, "damageMeterEnabled", "1")
    end
end

-- ReloadUI is protected on Forever: as on the settings panel, a secure /reload button on UIParent
-- covers the last page's button, placed out of combat only. In combat it can't hide or move: it
-- turns invisible, and its macro stops itself.
local secureReload
local function PlaceSecureReload()
    local show = tour.window and tour.window:IsShown() and tour.step == #PAGES
    if InCombatLockdown() then
        if secureReload and not show then secureReload:SetAlpha(0) end
        return
    end
    if not show then
        if secureReload then secureReload:Hide() end
        return
    end
    if not secureReload then
        secureReload = CreateFrame("Button", "FlareUI_TourReload", UIParent, "SecureActionButtonTemplate, UIPanelButtonTemplate")
        if ns.SkinButton then ns.SkinButton(secureReload) end
        secureReload:SetFrameStrata("FULLSCREEN_DIALOG")
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
            ApplyChoices()
            ns.ButtonSound()
        end)
    end
    local button = tour.finish
    local x, y = button:GetCenter()
    if not x then return end
    local scale = button:GetEffectiveScale() / UIParent:GetEffectiveScale()
    secureReload:SetSize(button:GetWidth() * scale, button:GetHeight() * scale)
    secureReload:ClearAllPoints()
    secureReload:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x * scale, y * scale)
    secureReload:SetText(button:GetText())
    secureReload:SetAlpha(1)
    secureReload:Show()
end

--------------------------------------------------
-- 5. TOUR: THE WINDOW
--------------------------------------------------
function tour.Show(step)
    tour.step = step
    local info = PAGES[step]
    for _, other in ipairs(PAGES) do
        if other.page then other.page:Hide() end
    end
    if not info.page then
        info.page = CreateFrame("Frame", nil, tour.window)
        info.page.previews = {}
        if info.bare then
            info.page:SetAllPoints()
        else
            info.page:SetPoint("TOPLEFT", SIDE, BODY_TOP)
            info.page:SetSize(BODY_W, BODY_H)
        end
        BuildPage[info.build](info.page)
    end
    info.page:Show()
    -- the samples, drawn now the page shows (and with the settings as they are now)
    for _, preview in ipairs(info.page.previews) do preview.Draw() end

    tour.header:SetShown(not info.bare)
    tour.footer:SetShown(not info.bare)
    if not info.bare then
        tour.stepText:SetFormattedText(L["Step %d of %d"], step, #PAGES)
        for i, dot in ipairs(tour.dots) do
            local size = i == step and 10 or 7
            dot:SetSize(size, size)
            if i == step then dot:SetVertexColor(1, 0.84, 0.5)
            elseif i < step then dot:SetVertexColor(0.78, 0.6, 0.34)
            else dot:SetVertexColor(0.27, 0.22, 0.16) end
        end
        local title = info.title
        if type(title) == "function" then title = title() end
        tour.title:SetText(title)
        tour.lead:SetText(info.lead)
        local last = step == #PAGES
        tour.next:SetShown(not last)
        tour.skip:SetShown(not last)
        tour.finish:SetShown(last)
    end
    if info.page.Refresh then info.page.Refresh() end
    RefreshTicks()
    PlaceSecureReload()
end

local function BuildTour()
    local w = WindowBase("FlareUI_Tour", WIDTH, HEIGHT)
    tour.window = w
    w:SetPoint("CENTER")
    -- under the secure reload button
    w:SetFrameStrata("DIALOG")
    w:SetScript("OnShow", ns.WindowOpenSound)
    w:SetScript("OnHide", function()
        ns.WindowCloseSound()
        if ns.db and ns.db.global then ns.db.global.welcomeSeen = true end
        PlaceSecureReload()
    end)
    w:RegisterEvent("PLAYER_REGEN_ENABLED")
    w:SetScript("OnEvent", PlaceSecureReload)

    -- the header: the round dog, the page's title and lead, the step and its dots
    local header = CreateFrame("Frame", nil, w)
    header:SetAllPoints()
    tour.header = header
    local logo = header:CreateTexture(nil, "ARTWORK", nil, 2)
    logo:SetTexture(LOGO)
    logo:SetSize(46, 46)
    logo:SetPoint("TOPLEFT", SIDE, -30)
    local logoMask = header:CreateMaskTexture()
    logoMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    logoMask:SetAllPoints(logo)
    logo:AddMaskTexture(logoMask)
    local logoRim = header:CreateTexture(nil, "ARTWORK", nil, 1)
    logoRim:SetTexture(CIRCLE)
    logoRim:SetSize(52, 52)
    logoRim:SetPoint("CENTER", logo)
    logoRim:SetVertexColor(0.78, 0.6, 0.34)
    local logoShade = header:CreateTexture(nil, "ARTWORK", nil, 0)
    logoShade:SetTexture(CIRCLE)
    logoShade:SetSize(56, 56)
    logoShade:SetPoint("CENTER", logo)
    logoShade:SetVertexColor(0, 0, 0, 0.6)
    tour.title = Say(header, "GameFontNormalHuge")
    tour.title:SetTextColor(TITLE_GOLD[1], TITLE_GOLD[2], TITLE_GOLD[3])
    tour.title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 14, -2)
    tour.lead = Say(header, "GameFontHighlight")
    tour.lead:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
    tour.lead:SetPoint("TOPLEFT", tour.title, "BOTTOMLEFT", 0, -6)
    tour.stepText = Say(header, "GameFontDisableSmall")
    tour.stepText:SetPoint("TOPRIGHT", -SIDE, -40)
    tour.dots = {}
    for i = 1, #PAGES do
        local dot = header:CreateTexture(nil, "ARTWORK")
        dot:SetTexture(CIRCLE)
        dot:SetPoint("CENTER", header, "TOPRIGHT", -SIDE - 5 - (#PAGES - i) * 15, -66)
        tour.dots[i] = dot
    end
    -- a line under the header, as the settings window's tab line
    local line = header:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.47, 0.36, 0.22, 0.8)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", SIDE, -88)
    line:SetPoint("TOPRIGHT", -SIDE, -88)

    local footer = CreateFrame("Frame", nil, w)
    footer:SetAllPoints()
    tour.footer = footer
    local back = PanelButton(footer, BACK or "Back", 112, 30, function() tour.Show(tour.step - 1) end)
    back:SetPoint("BOTTOMLEFT", SIDE, 24)
    tour.next = PanelButton(footer, NEXT or "Next", 112, 30, NextStep)
    tour.next:SetPoint("BOTTOMRIGHT", -SIDE, 24)
    tour.skip = PanelButton(footer, L["Skip the Rest"], 140, 30, function() tour.Show(#PAGES) end)
    tour.skip:SetPoint("BOTTOM", 0, 24)
    -- reached only while the secure button can't cover it: in combat
    tour.finish = PanelButton(footer, L["Reload and Finish"], 230, 32, function()
        if ERR_NOT_IN_COMBAT and UIErrorsFrame then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1) end
    end)
    tour.finish:SetPoint("BOTTOMRIGHT", -SIDE, 23)
end

-- A first run proposes every module but Resource Bars (all its bars start off, so it would show
-- nothing); a later run starts from what is on now.
local function StartChoices()
    local S = ns.Settings
    local fresh = not AnyModuleEnabled()
    local c = {}
    for _, key in ipairs(MODULE_KEYS) do
        if fresh then
            c[key] = key ~= "rb"
        else
            c[key] = S.modules[key] and S.modules[key]:IsOn() or false
        end
    end
    c.style = ns.UFRing and ns.UFRing.Style() or "addon"
    c.move = S.rows["qol.move"]:Get() and true or false
    c.sync = S.rows["qol.sync"]:Get() and true or false
    tour.choices = c
end

-- /fui tour and the About page's button
function ns.ShowTour()
    if ns.IsGamepadUI() then return end
    if not tour.window then BuildTour() end
    if ns.SettingsPanel then ns.SettingsPanel:Hide() end
    StartChoices()
    tour.window:Show()
    tour.Show(1)
end

--------------------------------------------------
-- 6. FIRST LOGIN
--------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    local global = ns.db and ns.db.global
    if not global then return end
    -- the login after the tour turned the radial on
    if global.tourRadialKeys then
        global.tourRadialKeys = nil
        C_Timer.After(2, function()
            if not InCombatLockdown() and not ns.IsGamepadUI() then ns.SettingsPanel:Open("rm", "radials") end
        end)
    end
    if global.welcomeSeen then return end
    if AnyModuleEnabled() then
        global.welcomeSeen = true
        return
    end
    -- after the loading screen has cleared
    C_Timer.After(2, function()
        if ns.IsGamepadUI() then ShowSmallWelcome() else ns.ShowTour() end
    end)
end)
