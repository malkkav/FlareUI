local _, ns = ...
local L = ns.L
local S = ns.Settings

--------------------------------------------------
-- ABOUT
-- A custom page: thanks and links, credits, and the slash commands. Its text rows are never drawn;
-- the page reads their copy.
--------------------------------------------------
local CREDIT_LINKS = {
    clari = "https://clariturela.itch.io/",
    sampconrad = "https://www.curseforge.com/members/sampconrad/projects",
    jeor = "https://github.com/Jeor",
    parchinskiy = "https://github.com/parchinskiy",
}

-- the buttons under the thanks
local NETWORKS = {
    { name = "CurseForge", url = "https://www.curseforge.com/wow/addons/flareui" },
    { name = "Wago.io", url = "https://addons.wago.io/addons/flareui" },
    { name = "GitHub", url = "https://github.com/malkkav/FlareUI" },
    { name = "Discord", url = "https://discord.com/invite/x4ugMQwMCR" },
}

local function CopyLink(url)
    if ns.Chat and ns.Chat.ShowCopyText then
        ns.Chat.ShowCopyText(url)
    else
        print("|cff00ccffFlareUI:|r " .. url)
    end
end

-- 11-10 rework: the page as bronze cards in the window's fonts; highlights in WoW yellow (11-13),
-- names that copy a link too
local GOLD = "|cffffd100"   -- (11-13, Malkkav: WoW's yellow, as the window's titles; was e9c46a)
local LINK = "|cffffd100"   -- (11-13: yellow too)
local function Gold(text) return (text or ""):gsub("|cffffd100", GOLD) end
local function Link(text, url) return "|Hurl:" .. url .. "|h" .. LINK .. text .. "|r|h" end

local CARD_PAD, CARD_GAP, PAGE_PAD = 14, 10, 2
local TITLE_Y = -12

local function Card(host, title, text)
    local card = CreateFrame("Frame", nil, host, "BackdropTemplate")
    ns.SettingsPanel.Box(card, 0.34)
    local t = card:CreateFontString(nil, "OVERLAY", "FlareUI_PanelTitle")
    t:SetPoint("TOPLEFT", CARD_PAD, TITLE_Y)
    t:SetJustifyH("LEFT")
    t:SetWordWrap(true)
    t:SetTextColor(1, 0.82, 0)   -- card titles in WoW yellow (11-13)
    t:SetText(title or "")
    card.title = t
    local rule = card:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(0.47, 0.36, 0.22, 0.8)
    rule:SetHeight(1)
    card.rule = rule
    -- (11-11 Malkkav: a little smaller than the rows' text)
    local body = card:CreateFontString(nil, "OVERLAY", "FlareUI_PanelTextSmall")
    body:SetJustifyH("LEFT")
    body:SetSpacing(4)
    body:SetText(text or "")
    card.body = body
    card:SetHyperlinksEnabled(true)
    card:SetScript("OnHyperlinkClick", function(_, link)
        local url = link:match("^url:(.+)$")
        if url then ns.ButtonSound() CopyLink(url) end
    end)
    return card
end

-- Rewrap both strings at the new width and return the bottom of the body.
local function LayoutCard(card, width)
    card:SetWidth(width)
    local textWidth = width - 2 * CARD_PAD
    card.title:SetWidth(textWidth)
    local ruleY = math.min(-38, TITLE_Y - math.ceil(card.title:GetStringHeight()) - 8)
    card.rule:ClearAllPoints()
    card.rule:SetPoint("TOPLEFT", CARD_PAD, ruleY)
    card.rule:SetPoint("TOPRIGHT", -CARD_PAD, ruleY)
    local bodyY = ruleY - 12
    card.body:ClearAllPoints()
    card.body:SetPoint("TOPLEFT", CARD_PAD, bodyY)
    card.body:SetWidth(textWidth)
    return bodyY - math.ceil(card.body:GetStringHeight() or 0)
end

local function Build(host)
    local panel = ns.SettingsPanel
    local scroll = CreateFrame("ScrollFrame", nil, host)
    scroll:SetPoint("TOPLEFT", host, "TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT")
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    -- thanks and the links
    local note = S:Text("about.links", "text", true) or ""
    -- the links' note on a line of its own (11-11)
    local thanks = Card(content, S:SectionText("about.yourFriendlyUiOverhowl"),
        (S:Text("about.thanks", "text", true) or "") .. ".\n"
        .. GRAY_FONT_COLOR:WrapTextInColorCode("(" .. note .. ")"))
    thanks:SetPoint("TOPLEFT", 0, -PAGE_PAD)
    local first, previous
    for _, net in ipairs(NETWORKS) do
        local b = CreateFrame("Button", nil, thanks, "UIPanelButtonTemplate")
        ns.SkinButton(b)
        b:SetSize(112, 26)
        b:SetText(net.name)
        b:SetScript("OnClick", function()
            ns.ButtonSound()
            CopyLink(net.url)
        end)
        -- centred in the card (11-11 Malkkav)
        if previous then b:SetPoint("LEFT", previous, "RIGHT", 8, 0)
        else first = b end
        previous = b
    end
    local buttonsWidth = #NETWORKS * 112 + (#NETWORKS - 1) * 8

    -- credits (left) and the Edit Mode layout (right), side by side
    local text = Gold(S:Text("about.credits", "text", true))
    text = text:gsub(GOLD .. "Clari Turela|r", Link("Clari Turela", CREDIT_LINKS.clari))
    text = text:gsub(GOLD .. "sampconrad|r", Link("sampconrad", CREDIT_LINKS.sampconrad))
    text = text:gsub(GOLD .. "Jeor|r", Link("Jeor", CREDIT_LINKS.jeor))
    text = text:gsub(GOLD .. "parchinskiy|r", Link("parchinskiy", CREDIT_LINKS.parchinskiy))
    local credits = Card(content, S:SectionText("about.credits"), text)
    credits:SetPoint("TOPLEFT", thanks, "BOTTOMLEFT", 0, -CARD_GAP)

    local layout = Card(content, S:SectionText("about.editModeLayout"),
        Gold(S:Format(S:Text("about.layout", "text", true))))
    layout:SetPoint("TOPLEFT", credits, "TOPRIGHT", CARD_GAP, 0)
    local copy = ns.EditModeLayout.Button(layout)

    -- slash commands
    local commands = Card(content, S:Text("about.commands", "label"),
        Gold(S:Format(S:Text("about.commands", "text", true))))
    commands:SetPoint("TOPLEFT", credits, "BOTTOMLEFT", 0, -CARD_GAP)

    local function RenderCards(width)
        local y = LayoutCard(thanks, width) - 14
        first:ClearAllPoints()
        first:SetPoint("TOPLEFT", (width - buttonsWidth) / 2, y)
        local thanksHeight = -(y - 26) + CARD_PAD
        thanks:SetHeight(thanksHeight)

        local half = math.floor((width - CARD_GAP) / 2)
        local creditsEnd = LayoutCard(credits, half)
        local layoutEnd = LayoutCard(layout, width - half - CARD_GAP)
        copy:ClearAllPoints()
        copy:SetPoint("TOP", layout, "TOP", 0, layoutEnd - 14)
        layoutEnd = layoutEnd - 14 - 24
        local pairH = math.max(-creditsEnd, -layoutEnd) + CARD_PAD
        credits:SetHeight(pairH)
        layout:SetHeight(pairH)

        local commandsHeight = -LayoutCard(commands, width) + CARD_PAD
        commands:SetHeight(commandsHeight)
        return thanksHeight + pairH + commandsHeight + 2 * (CARD_GAP + PAGE_PAD)
    end

    panel.AttachScrollLine(scroll, host)
    function host:RefreshAboutLayout()
        local width, height = self:GetSize()
        if not self:IsVisible() or width <= 0 or height <= 0 then return end
        local inset = panel.LayoutScrollContent(scroll, width, RenderCards)
        scroll:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -inset, 0)
    end
    host:HookScript("OnSizeChanged", host.RefreshAboutLayout)
end

S:Module{
    key = "about", group = "top", order = 1,
    navIcon = "Interface\\AddOns\\FlareUI\\Media\\Art\\Icon.png",
    custom = { key = "main", custom = Build, refresh = function(host) host:RefreshAboutLayout() end },
    -- the setup tour again (the Gamepad UI has no tour)
    headerButton = function()
        if ns.IsGamepadUI() then return nil end
        return L["Start Tour"], function() ns.ShowTour() end
    end,
}

S:Row{ key = "about.thanks", kind = "text" }
S:Row{ key = "about.links", kind = "text" }
S:Row{ key = "about.credits", kind = "text" }
S:Row{ key = "about.commands", kind = "text" }
S:Row{ key = "about.layout", kind = "text" }
