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
    { name = "Discord", url = "https://discord.gg/AHqeck4VNS" },
}

local function CopyLink(url)
    if ns.Chat and ns.Chat.ShowCopyText then
        ns.Chat.ShowCopyText(url)
    else
        print("|cff00ccffFlareUI:|r " .. url)
    end
end

-- 11-10 rework: the page as bronze cards in the window's fonts; highlights in the window's gold,
-- names that copy a link in light gold
local GOLD = "|cffe9c46a"
local LINK = "|cffffd479"
local function Gold(text) return (text or ""):gsub("|cffffd100", GOLD) end
local function Link(text, url) return "|Hurl:" .. url .. "|h" .. LINK .. text .. "|r|h" end

local CARD_PAD, CARD_GAP, PAGE_PAD = 14, 10, 2

-- a box with a gold title and a rule; returns it and the y where its content starts
local function Card(host, title, width)
    local card = CreateFrame("Frame", nil, host, "BackdropTemplate")
    ns.SettingsPanel.Box(card, 0.34)
    card:SetWidth(width)
    local t = card:CreateFontString(nil, "OVERLAY", "FlareUI_PanelTitle")
    local titleY = -12
    t:SetPoint("TOPLEFT", CARD_PAD, titleY)
    t:SetWidth(width - 2 * CARD_PAD)
    t:SetJustifyH("LEFT")
    t:SetWordWrap(true)
    t:SetTextColor(0.91, 0.77, 0.42)
    t:SetText(title or "")
    local ruleY = math.min(-38, titleY - math.ceil(t:GetStringHeight()) - 8)
    local rule = card:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(0.47, 0.36, 0.22, 0.8)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", CARD_PAD, ruleY)
    rule:SetPoint("TOPRIGHT", -CARD_PAD, ruleY)
    card:SetHyperlinksEnabled(true)
    card:SetScript("OnHyperlinkClick", function(_, link)
        local url = link:match("^url:(.+)$")
        if url then ns.ButtonSound() CopyLink(url) end
    end)
    return card, ruleY - 12
end

local function Body(card, text, y, font)
    -- (11-11 Marcus: a little smaller than the rows' text)
    local fs = card:CreateFontString(nil, "OVERLAY", font or "FlareUI_PanelTextSmall")
    fs:SetPoint("TOPLEFT", CARD_PAD, y)
    fs:SetWidth(card:GetWidth() - 2 * CARD_PAD)
    fs:SetJustifyH("LEFT")
    fs:SetSpacing(4)
    fs:SetText(text or "")
    return fs, y - math.ceil(fs:GetStringHeight() or 0)
end

local function Build(host)
    local panel = ns.SettingsPanel
    local width = panel.MIDDLE_W or host:GetWidth()
    local half = math.floor((width - CARD_GAP) / 2)

    local scroll = CreateFrame("ScrollFrame", nil, host)
    scroll:SetAllPoints(host)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(width)
    scroll:SetScrollChild(content)

    -- thanks and the links
    local thanks, y = Card(content, S:SectionText("about.yourFriendlyUiOverhowl"), width)
    thanks:SetPoint("TOPLEFT", 0, -PAGE_PAD)
    local note = S:Text("about.links", "text", true) or ""
    -- the links' note on a line of its own (11-11)
    local _, after = Body(thanks, (S:Text("about.thanks", "text", true) or "") .. ".\n"
        .. GRAY_FONT_COLOR:WrapTextInColorCode("(" .. note .. ")"), y)
    y = after - 14
    local previous
    for _, net in ipairs(NETWORKS) do
        local b = CreateFrame("Button", nil, thanks, "UIPanelButtonTemplate")
        ns.SkinButton(b)
        b:SetSize(112, 26)
        b:SetText(net.name)
        b:SetScript("OnClick", function()
            ns.ButtonSound()
            CopyLink(net.url)
        end)
        -- centred in the card (11-11 Marcus)
        if previous then b:SetPoint("LEFT", previous, "RIGHT", 8, 0)
        else b:SetPoint("TOPLEFT", (width - (#NETWORKS * 112 + (#NETWORKS - 1) * 8)) / 2, y) end
        previous = b
    end
    thanks:SetHeight(-(y - 26) + CARD_PAD)

    -- credits (left) and the Edit Mode layout (right), side by side
    local credits, cy = Card(content, S:SectionText("about.credits"), half)
    credits:SetPoint("TOPLEFT", thanks, "BOTTOMLEFT", 0, -CARD_GAP)
    local text = Gold(S:Text("about.credits", "text", true))
    text = text:gsub(GOLD .. "Clari Turela|r", Link("Clari Turela", CREDIT_LINKS.clari))
    text = text:gsub(GOLD .. "sampconrad|r", Link("sampconrad", CREDIT_LINKS.sampconrad))
    text = text:gsub(GOLD .. "Jeor|r", Link("Jeor", CREDIT_LINKS.jeor))
    text = text:gsub(GOLD .. "parchinskiy|r", Link("parchinskiy", CREDIT_LINKS.parchinskiy))
    local _, creditsEnd = Body(credits, text, cy)

    local layout, ly = Card(content, S:SectionText("about.editModeLayout"), width - half - CARD_GAP)
    layout:SetPoint("TOPLEFT", credits, "TOPRIGHT", CARD_GAP, 0)
    local _, layoutEnd = Body(layout, Gold(S:Format(S:Text("about.layout", "text", true))), ly)
    local copy = ns.EditModeLayout.Button(layout)
    copy:SetPoint("TOP", layout, "TOP", 0, layoutEnd - 14)
    layoutEnd = layoutEnd - 14 - 24

    local pairH = math.max(-creditsEnd, -layoutEnd) + CARD_PAD
    credits:SetHeight(pairH)
    layout:SetHeight(pairH)

    -- slash commands
    local commands, sy = Card(content, S:Text("about.commands", "label") or "", width)
    commands:SetPoint("TOPLEFT", credits, "BOTTOMLEFT", 0, -CARD_GAP)
    local _, commandsEnd = Body(commands, Gold(S:Format(S:Text("about.commands", "text", true))), sy, "FlareUI_PanelTextSmall")
    commands:SetHeight(-commandsEnd + CARD_PAD)

    content:SetHeight(thanks:GetHeight() + pairH + commands:GetHeight() + 2 * (CARD_GAP + PAGE_PAD))
    panel.AttachScrollLine(scroll, host)
end

S:Module{
    key = "about", group = "top", order = 1,
    navIcon = "Interface\\AddOns\\FlareUI\\Media\\Art\\Icon.png",
    custom = { key = "main", custom = Build },
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
