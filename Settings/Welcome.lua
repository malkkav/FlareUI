local _, ns = ...
local L = ns.L

--------------------------------------------------
-- WELCOME
-- Every module ships off. The first login with none on opens the setup tour: nine pages that show
-- each module and collect the player's choices, written only by the last page's reload. Closing the
-- tour changes nothing. The Gamepad UI keeps a small pop-up instead (its navigation is still alpha).
--------------------------------------------------
local LSM = LibStub("LibSharedMedia-3.0")

local BANNER = "Interface\\AddOns\\FlareUI\\Media\\Art\\Banner.png"
local WHITE = "Interface\\Buttons\\WHITE8x8"

-- an account with any module on has no need for it
local function AnyModuleEnabled()
    local S = ns.Settings
    if not (S and ns.db and ns.db.profile) then return false end
    for _, module in pairs(S.modules) do
        if module.enabled and module:IsOn() then return true end
    end
    return false
end

local function WindowBase(name, width, height)
    local style = ns.WINDOW_STYLE
    local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    f:SetSize(width, height)
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetBackdrop({ edgeFile = LSM:Fetch("border", "Blizzard Tooltip"), edgeSize = 16 })
    f:SetBackdropBorderColor(style.border[1], style.border[2], style.border[3], 1)
    ns.Fade(f, 4, style.top, style.bottom)
    f:Hide()
    tinsert(UISpecialFrames, name)
    return f
end

local function PanelButton(parent, text, width, height, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, height)
    b:SetText(text)
    b:SetScript("OnClick", function()
        ns.ButtonSound()
        onClick()
    end)
    return b
end

--------------------------------------------------
-- 1. THE SMALL POP-UP (Gamepad UI)
--------------------------------------------------
local small

local function ShowSmallWelcome()
    if small then small:Show() return end
    small = WindowBase("FlareUI_Welcome", 400, 330)
    small:SetPoint("CENTER", 0, 80)
    small:SetFrameStrata("FULLSCREEN_DIALOG")
    small:SetMovable(true)
    small:RegisterForDrag("LeftButton")
    small:SetScript("OnDragStart", small.StartMoving)
    small:SetScript("OnDragStop", small.StopMovingOrSizing)
    small:SetScript("OnShow", ns.WindowOpenSound)
    -- seen however it closes (either button or Escape)
    small:SetScript("OnHide", function()
        ns.WindowCloseSound()
        if ns.db and ns.db.global then ns.db.global.welcomeSeen = true end
    end)

    local banner = small:CreateTexture(nil, "ARTWORK")
    banner:SetTexture(BANNER)
    banner:SetSize(120, 120)
    banner:SetPoint("TOP", 0, -22)

    local title = small:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", banner, "BOTTOM", 0, -14)
    title:SetText(L["Welcome to FlareUI!"])

    local subtitle = small:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -6)
    subtitle:SetText(L["Your friendly UI overhowl"])

    local body = small:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body:SetPoint("TOP", subtitle, "BOTTOM", 0, -14)
    body:SetWidth(340)
    body:SetJustifyH("CENTER")
    body:SetSpacing(2)
    body:SetText(L["Every module of this addon starts switched off.\nTo begin, open the settings and enable the modules you want to use."])

    local open = PanelButton(small, L["Open Settings"], 140, 22, function()
        small:Hide()
        ns.SettingsPanel:Open()
    end)
    open:SetPoint("BOTTOMRIGHT", small, "BOTTOM", -4, 20)
    local close = PanelButton(small, CLOSE or "Close", 140, 22, function() small:Hide() end)
    close:SetPoint("BOTTOMLEFT", small, "BOTTOM", 4, 20)
    small:Show()
end

--------------------------------------------------
-- 2. TOUR: THE PIECES
--------------------------------------------------
local WIDTH, HEIGHT = 640, 500
local SIDE = 24                 -- the window's left and right margin
local BODY_W = WIDTH - 2 * SIDE
local BODY_TOP = -96            -- from the window's top to a page's content
local BODY_H = 348              -- a page's content height, above the footer
local GAP = 12                  -- between cards
local CARD_PAD = 10
local CARD_W2 = (BODY_W - GAP) / 2
local CARD_W3 = (BODY_W - 2 * GAP) / 3

-- The store art, cropped into power-of-two files: the picture is the top left w x h of the file
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

local function Say(parent, font, text, width)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetJustifyH("LEFT")
    fs:SetSpacing(2)
    if width then fs:SetWidth(width) end
    fs:SetText(text or "")
    return fs
end

local function Title(key)
    return ns.Settings.modules[key]:Title()
end

local function Bullets(lines)
    local parts = {}
    for i, line in ipairs(lines) do parts[i] = "\226\128\162 " .. line end
    return table.concat(parts, "\n")
end

-- A picture fitted inside a dark box
local function Picture(parent, name, width, height)
    local box = CreateFrame("Frame", nil, parent)
    box:SetSize(width, height)
    local bg = box:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.075, 0.13, 1)
    local a = ART[name]
    local scale = math.min(width / a[1], height / a[2])
    local tex = box:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(ART_PATH .. name .. ".png")
    tex:SetTexCoord(0, a[1] / a[3], 0, a[2] / a[4])
    tex:SetSize(a[1] * scale, a[2] * scale)
    tex:SetPoint("CENTER")
    return box
end

local function Card(parent, x, y, width, height)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetPoint("TOPLEFT", x, y)
    card:SetSize(width, height)
    card:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    card:SetBackdropColor(0.05, 0.045, 0.035, 1)
    card:SetBackdropBorderColor(0.29, 0.24, 0.17, 1)
    card.inner = width - 2 * CARD_PAD
    return card
end

-- Puts a region under the card's last one
local function Stack(card, region, gap)
    if card.last then
        region:SetPoint("TOPLEFT", card.last, "BOTTOMLEFT", 0, -(gap or 8))
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
        tick:SetAlpha(on and 1 or 0.4)
    end
    if tour.RefreshStyles then tour.RefreshStyles() end
end

-- A tick for tour.choices[key]; needs: greyed while that other choice is off
local function Tick(parent, key, label, needs)
    local tick = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    tick:SetSize(24, 24)
    tick.key, tick.needs = key, needs
    local text = tick:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", tick, "RIGHT", 2, 0)
    text:SetText(label)
    tick:SetHitRectInsets(0, -(text:GetStringWidth() + 6), 0, 0)
    tick:SetScript("OnClick", function(self)
        ns.ButtonSound()
        tour.choices[key] = self:GetChecked() and true or false
        RefreshTicks()
    end)
    tour.ticks[#tour.ticks + 1] = tick
    return tick
end

-- The "Use it" tick at a card's bottom
local function CardTick(card, key)
    local tick = Tick(card, key, L["Use it"])
    tick:SetPoint("BOTTOMLEFT", CARD_PAD - 3, 6)
    return tick
end

-- A picture, a module's name, a few lines and its tick
local function ModuleCard(page, x, key, art, artHeight, lines)
    local card = Card(page, x, 0, CARD_W2, BODY_H)
    Stack(card, Picture(card, art, card.inner, artHeight))
    Stack(card, Say(card, "GameFontNormalLarge", Title(key), card.inner))
    Stack(card, Say(card, "GameFontHighlight", Bullets(lines), card.inner))
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
    local banner = page:CreateTexture(nil, "ARTWORK")
    banner:SetTexture(BANNER)
    banner:SetSize(128, 128)
    banner:SetPoint("TOP", 0, -28)

    local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOP", banner, "BOTTOM", 0, -14)
    title:SetText(L["Welcome to FlareUI!"])

    local subtitle = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -6)
    subtitle:SetText(L["Your friendly UI overhowl"])

    local body = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    body:SetPoint("TOP", subtitle, "BOTTOM", 0, -18)
    body:SetWidth(480)
    body:SetJustifyH("CENTER")
    body:SetSpacing(3)
    body:SetText(L["Everything starts switched off. This short tour shows you what each part does, and you choose the ones you want as you go."])

    local start = PanelButton(page, L["Show me around"], 240, 34, NextStep)
    start:SetPoint("BOTTOM", 0, 72)

    local skip = PanelButton(page, L["Skip, I know what I'm doing"], 240, 24, CloseTour)
    skip:SetPoint("TOP", start, "BOTTOM", 0, -8)

    local hint = page:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    hint:SetPoint("TOP", skip, "BOTTOM", 0, -8)
    hint:SetText(L["Settings are always on /fui."])
end

-- 2: unit frames and their style
function BuildPage.unitFrames(page)
    local tick = Tick(page, "uf", L["Use FlareUI's unit frames"])
    tick:SetPoint("TOPLEFT", -3, 0)

    local ask = Say(page, "GameFontHighlight", L["Which style do you like best?"])
    ask:SetPoint("TOPLEFT", 0, -30)

    local styles = {
        { value = "flareui", art = "StyleFlareUI", name = L["FlareUI Style"], text = L["The bronze ring beside FlareUI's bars."] },
        { value = "forever", art = "StyleForever", name = L["Forever Style"], text = L["Blizzard's bronze frame and portrait ring."] },
        { value = "addon",   art = "StyleAddon",   name = L["Addon Style"],   text = L["Plain frames, the most options."] },
    }
    local cards = {}
    for i, style in ipairs(styles) do
        local card = CreateFrame("Button", nil, page, "BackdropTemplate")
        card:SetPoint("TOPLEFT", (i - 1) * (CARD_W3 + GAP), -52)
        card:SetSize(CARD_W3, 196)
        card:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 2 })
        card:SetBackdropColor(0.05, 0.045, 0.035, 1)
        card.inner = CARD_W3 - 2 * CARD_PAD
        card.value = style.value
        Stack(card, Picture(card, style.art, card.inner, 80))
        Stack(card, Say(card, "GameFontNormal", style.name, card.inner))
        Stack(card, Say(card, "GameFontHighlight", style.text, card.inner), 6)
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
            local picked = tour.choices.style == card.value
            card:SetBackdropBorderColor(picked and 1 or 0.29, picked and 0.82 or 0.24, picked and 0 or 0.17, 1)
            card:SetEnabled(on and true or false)
            card:SetAlpha(on and 1 or 0.4)
        end
    end

    local note = Say(page, "GameFontHighlight", L["You can switch any time, and each style keeps its own setup. Party and raid frames are switched on in /fui."], BODY_W)
    note:SetPoint("TOPLEFT", 0, -260)
    note:SetTextColor(0.72, 0.68, 0.61)
end

-- 3: the three small modules of the HUD
function BuildPage.bars(page)
    local art = Picture(page, "ActionBars", BODY_W, 112)
    art:SetPoint("TOPLEFT")
    local entries = {
        { key = "ab", text = L["Blizzard's bars, sharpened: red when out of range, blue with no mana, glows on procs."] },
        { key = "au", text = L["Your buffs and debuffs in FlareUI's style, with clear timers."] },
        { key = "rb", text = L["Extra health, power, combo point and swing bars to place anywhere. Off to begin with: choose your bars in /fui."] },
    }
    for i, entry in ipairs(entries) do
        local card = Card(page, (i - 1) * (CARD_W3 + GAP), -124, CARD_W3, BODY_H - 124)
        Stack(card, Say(card, "GameFontNormal", Title(entry.key), card.inner))
        Stack(card, Say(card, "GameFontHighlight", entry.text, card.inner))
        CardTick(card, entry.key)
    end
end

-- 4: nothing to choose: the two places options live
function BuildPage.editMode(page)
    local left = Card(page, 0, 0, CARD_W2, BODY_H)
    Stack(left, Say(left, "GameFontNormalLarge", L["Edit Mode"], left.inner))
    local scene = CreateFrame("Frame", nil, left)
    scene:SetSize(left.inner, 104)
    Stack(left, scene)
    local sceneBg = scene:CreateTexture(nil, "BACKGROUND")
    sceneBg:SetAllPoints()
    sceneBg:SetColorTexture(0.04, 0.075, 0.13, 1)
    -- Blizzard's blue selection on a frame, and its settings dialog beside it
    local selected = CreateFrame("Frame", nil, scene, "BackdropTemplate")
    selected:SetSize(122, 46)
    selected:SetPoint("CENTER", -46, 0)
    selected:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 2 })
    selected:SetBackdropColor(0.24, 0.59, 1, 0.28)
    selected:SetBackdropBorderColor(0.29, 0.64, 1, 1)
    local selectedText = selected:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    selectedText:SetPoint("CENTER")
    selectedText:SetText(L["Player Frame"])
    local dialog = CreateFrame("Frame", nil, scene, "BackdropTemplate")
    dialog:SetSize(84, 62)
    dialog:SetPoint("LEFT", selected, "RIGHT", 12, 0)
    dialog:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    dialog:SetBackdropColor(0.08, 0.066, 0.047, 1)
    dialog:SetBackdropBorderColor(0.65, 0.49, 0.27, 1)
    for i = 1, 4 do
        local bar = dialog:CreateTexture(nil, "ARTWORK")
        bar:SetPoint("TOPLEFT", 8, -8 - (i - 1) * 12)
        bar:SetSize(68, 5)
        if i == 1 then bar:SetColorTexture(0.8, 0.6, 0.34, 1) else bar:SetColorTexture(0.42, 0.35, 0.26, 1) end
    end
    Stack(left, Say(left, "GameFontHighlight", L["Press |cffffd100Esc|r, then choose |cffffd100Edit Mode|r. Click anything on your screen to move it and change its size and look."], left.inner))
    Stack(left, Say(left, "GameFontNormal", L["Unit frames and bars are set up here."], left.inner))

    local right = Card(page, CARD_W2 + GAP, 0, CARD_W2, BODY_H)
    Stack(right, Say(right, "GameFontNormalLarge", L["FlareUI Settings"], right.inner))
    local command = CreateFrame("Frame", nil, right)
    command:SetSize(right.inner, 104)
    Stack(right, command)
    local commandBg = command:CreateTexture(nil, "BACKGROUND")
    commandBg:SetAllPoints()
    commandBg:SetColorTexture(0.04, 0.075, 0.13, 1)
    local commandText = command:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    commandText:SetPoint("CENTER")
    commandText:SetText("/fui")
    Stack(right, Say(right, "GameFontHighlight", L["Type |cffffd100/fui|r in chat. Turn parts of FlareUI on or off, and find everything that isn't a frame on your screen: chat options, tooltips, the radial menu."], right.inner))
    Stack(right, Say(right, "GameFontNormal", L["The rest is set up here."], right.inner))
end

-- 5: the FlareUI Edit Mode layout, imported by the player in Blizzard's own dialog
function BuildPage.layout(page)
    local left = Card(page, 0, 0, CARD_W2, BODY_H)
    Stack(left, Say(left, "GameFontNormalLarge", L["Use our layout"], left.inner))
    Stack(left, Say(left, "GameFontHighlight", L["Want your screen set up like ours? Import the FlareUI layout into Edit Mode:"], left.inner))
    Stack(left, Say(left, "GameFontHighlight", table.concat({
        "|cffffd1001.|r " .. L["Click |cffffd100Copy layout code|r and press |cffffd100Ctrl+C|r."],
        "|cffffd1002.|r " .. L["Press |cffffd100Esc|r and choose |cffffd100Edit Mode|r."],
        "|cffffd1003.|r " .. L["Open the |cffffd100Layout|r menu and choose |cffffd100Import|r."],
        "|cffffd1004.|r " .. L["Paste with |cffffd100Ctrl+V|r, name it and click |cffffd100Import|r."],
    }, "\n"), left.inner), 10)
    local copy = ns.EditModeLayout.Button(left, 170)
    copy:SetPoint("BOTTOMLEFT", CARD_PAD, CARD_PAD)

    local right = Card(page, CARD_W2 + GAP, 0, CARD_W2, BODY_H)
    Stack(right, Say(right, "GameFontNormalLarge", L["Good to know"], right.inner))
    Stack(right, Say(right, "GameFontHighlight", Bullets({
        L["It's saved and switched on right away"],
        L["Your old layout stays: switch back any time from the Layout menu"],
        L["FlareUI's own frames already sit where the layout expects them"],
        L["Made for the default UI scale. Wider screens just get more room at the sides"],
    }), right.inner), 10)
    Stack(right, Say(right, "GameFontNormal", L["It's also at the bottom of the About page in /fui."], right.inner), 14)
end

-- 6: the two windows
function BuildPage.chatMeter(page)
    ModuleCard(page, 0, "ch", "Chat", 130, {
        L["A header with your tabs and buttons"],
        L["Saved history, so a reload keeps your chat"],
        L["Tooltips when you hover links"],
    })
    ModuleCard(page, CARD_W2 + GAP, "dm", "Meter", 130, {
        L["Blizzard's meter in a FlareUI frame"],
        L["A Threat tab, so you know when to stop"],
        L["Moves and resizes in Edit Mode"],
    })
end

-- 7: where you are, what you're doing
function BuildPage.mapQuests(page)
    ModuleCard(page, 0, "mm", "Minimap", 160, {
        L["A square map with Forever's day and night cycle"],
        L["Zone, clock and coordinates on the map"],
        L["All your addon buttons tucked into one bag"],
    })
    ModuleCard(page, CARD_W2 + GAP, "qt", "Quests", 160, {
        L["Your quests grouped by zone"],
        L["Colours show how hard each quest is"],
        L["Gets out of the way in combat"],
    })
end

-- 8: the radial, and the key it still needs
function BuildPage.radial(page)
    local art = Picture(page, "Radial", 270, 270)
    art:SetPoint("TOPLEFT")
    local x = 270 + GAP
    local card = Card(page, x, 0, BODY_W - x, BODY_H)
    Stack(card, Say(card, "GameFontNormalLarge", L["Hold, point, release"], card.inner))
    Stack(card, Say(card, "GameFontHighlight", L["Hold your key and a ring of buttons opens at your cursor. Point at one, let go, and it fires. It even works in combat."], card.inner))
    Stack(card, Say(card, "GameFontHighlight", Bullets({
        L["Spells, items, mounts, macros and raid markers"],
        L["Radials inside radials"],
        L["Or open it with a press instead of a hold"],
    }), card.inner))
    Stack(card, Say(card, "GameFontNormal", L["It needs a key. After the reload, FlareUI opens the page where you choose one."], card.inner))
    CardTick(card, "rm")
end

-- 9: the helpers
function BuildPage.qol(page)
    local tick = Tick(page, "qol", L["Use Quality of Life"])
    tick:SetPoint("TOPLEFT", -3, 0)
    local height = BODY_H - 34

    local left = Card(page, 0, -34, CARD_W2, height)
    Stack(left, Say(left, "GameFontNormal", L["Move any window"], left.inner))
    Stack(left, Say(left, "GameFontHighlight", L["Drag a Blizzard window by its header to move it. |cffffd100Ctrl|r + mouse wheel resizes it, and |cffffd100Shift|r + right-click puts it back."], left.inner), 6)
    local move = Tick(left, "move", L["Use it"], "qol")
    Stack(left, move, 4)
    local syncName = Say(left, "GameFontNormal", L["Sync Blizz UI"], left.inner)
    syncName:SetPoint("TOPLEFT", move, "BOTTOMLEFT", 0, -10)
    local syncText = Say(left, "GameFontHighlight", L["Got alts? Copies one character's interface options, Edit Mode layout, chat and bag settings to your others."], left.inner)
    syncText:SetPoint("TOPLEFT", syncName, "BOTTOMLEFT", 0, -6)
    local sync = Tick(left, "sync", L["Use it"], "qol")
    sync:SetPoint("TOPLEFT", syncText, "BOTTOMLEFT", 0, -4)

    local right = Card(page, CARD_W2 + GAP, -34, CARD_W2, height)
    Stack(right, Say(right, "GameFontNormal", L["Also in there"], right.inner))
    Stack(right, Say(right, "GameFontHighlight", Bullets({
        L["Faster auto loot"],
        L["A Train All button at trainers"],
        L["A camera that zooms out further"],
        L["Map pins with /way"],
        L["Alert sounds for ready checks and invites"],
    }), right.inner), 6)
    local pick = Stack(right, Say(right, "GameFontHighlight", L["Pick them in /fui, Quality of Life."], right.inner), 6)
    pick:SetTextColor(0.72, 0.68, 0.61)
    Stack(right, Say(right, "GameFontNormal", Title("tt"), right.inner), 14)
    Stack(right, Say(right, "GameFontHighlight", L["Cleaner tooltips with coloured borders."], right.inner), 6)
    CardTick(right, "tt")
end

-- 10: the choices, and what to try after the reload
function BuildPage.finish(page)
    local banner = page:CreateTexture(nil, "ARTWORK")
    banner:SetTexture(BANNER)
    banner:SetSize(60, 60)
    banner:SetPoint("TOPLEFT", tour.window, "TOPLEFT", SIDE, -34)

    local summary = Card(page, 0, 0, BODY_W, 170)
    Stack(summary, Say(summary, "GameFontNormal", L["What you turned on"], summary.inner))
    local rows = {}
    local columnW = summary.inner / 2
    for i, key in ipairs(MODULE_KEYS) do
        local row = Say(summary, "GameFontHighlight", "", columnW)
        row:SetWordWrap(false)
        row:SetPoint("TOPLEFT", (i - 1) % 2 * columnW + CARD_PAD, -30 - math.floor((i - 1) / 2) * 21)
        rows[key] = row
    end
    local nothing = Say(summary, "GameFontHighlight", L["Nothing is on yet. Go back and tick something, or open the settings later with /fui."], summary.inner)
    nothing:SetPoint("TOPLEFT", CARD_PAD, -30)

    local after = Card(page, 0, -182, BODY_W, BODY_H - 182)
    Stack(after, Say(after, "GameFontNormal", L["Try these next"], after.inner))
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
            if c[key] then
                any = true
                row:SetText("|TInterface\\Buttons\\UI-CheckBox-Check:16:16|t " .. name)
                row:SetTextColor(1, 1, 1)
            else
                row:SetText("|TInterface\\Buttons\\UI-CheckBox-Up:16:16|t " .. name)
                row:SetTextColor(0.55, 0.52, 0.47)
            end
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
    { build = "finish", title = L["Good dog. All done!"], lead = L["One reload and your choices take effect."], titleX = SIDE + 72 },
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
        if info.bare then
            info.page:SetAllPoints()
        else
            info.page:SetPoint("TOPLEFT", SIDE, BODY_TOP)
            info.page:SetSize(BODY_W, BODY_H)
        end
        BuildPage[info.build](info.page)
    end
    info.page:Show()

    tour.header:SetShown(not info.bare)
    tour.footer:SetShown(not info.bare)
    if not info.bare then
        tour.stepText:SetFormattedText(L["Step %d of %d"], step, #PAGES)
        for i, dot in ipairs(tour.dots) do
            if i <= step then dot:SetColorTexture(0.8, 0.6, 0.34, 1) else dot:SetColorTexture(0.24, 0.21, 0.16, 1) end
        end
        local title = info.title
        if type(title) == "function" then title = title() end
        tour.title:SetText(title)
        tour.lead:SetText(info.lead)
        tour.title:ClearAllPoints()
        tour.title:SetPoint("TOPLEFT", tour.window, "TOPLEFT", info.titleX or SIDE, -36)
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
    w:SetClampedToScreen(true)
    w:SetScript("OnShow", ns.WindowOpenSound)
    w:SetScript("OnHide", function()
        ns.WindowCloseSound()
        if ns.db and ns.db.global then ns.db.global.welcomeSeen = true end
        PlaceSecureReload()
    end)
    local close = CreateFrame("Button", nil, w, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    w:RegisterEvent("PLAYER_REGEN_ENABLED")
    w:SetScript("OnEvent", PlaceSecureReload)

    local header = CreateFrame("Frame", nil, w)
    header:SetAllPoints()
    tour.header = header
    tour.stepText = header:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    tour.stepText:SetPoint("TOPLEFT", SIDE, -16)
    tour.dots = {}
    for i = 1, #PAGES do
        local dot = header:CreateTexture(nil, "ARTWORK")
        dot:SetSize(18, 4)
        dot:SetPoint("TOPRIGHT", -(SIDE + 24) - (#PAGES - i) * 23, -21)
        tour.dots[i] = dot
    end
    tour.title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    tour.lead = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    tour.lead:SetPoint("TOPLEFT", tour.title, "BOTTOMLEFT", 0, -6)

    local footer = CreateFrame("Frame", nil, w)
    footer:SetAllPoints()
    tour.footer = footer
    local back = PanelButton(footer, BACK or "Back", 104, 26, function() tour.Show(tour.step - 1) end)
    back:SetPoint("BOTTOMLEFT", SIDE, 16)
    tour.next = PanelButton(footer, NEXT or "Next", 104, 26, NextStep)
    tour.next:SetPoint("BOTTOMRIGHT", -SIDE, 16)
    tour.skip = PanelButton(footer, L["Skip the rest"], 130, 26, function() tour.Show(#PAGES) end)
    tour.skip:SetPoint("BOTTOM", 0, 16)
    -- reached only while the secure button can't cover it: in combat
    tour.finish = PanelButton(footer, L["Reload and finish"], 220, 30, function()
        if ERR_NOT_IN_COMBAT and UIErrorsFrame then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1) end
    end)
    tour.finish:SetPoint("BOTTOMRIGHT", -SIDE, 14)
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
