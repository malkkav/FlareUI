local _, ns = ...
local S = ns.Settings

--------------------------------------------------
-- ABOUT: top of the list. A page of its own (module.custom): the thank-you and the links, the
-- credits, and the slash commands in a box at the bottom. The header button runs the welcome
-- guide again. The rows below are not drawn; they keep the text findable in search.
--------------------------------------------------
local CREDIT_LINKS = {
    clari = "https://clariturela.itch.io/",
    sampconrad = "https://www.curseforge.com/members/sampconrad/projects",
    sampconradGitHub = "https://github.com/sampconrad",
}

-- the networks under the thank-you. icon: a texture, grey until pointed at; without one the
-- button shows the name. A link that is not known yet (nil) is left out.
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

local function Link(text, url)
    return "|Hurl:" .. url .. "|h|cff4fb8ff" .. text .. "|r|h"
end

local function Section(host, text, anchor, y)
    local title = host:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", anchor or host, anchor and "BOTTOMLEFT" or "TOPLEFT", anchor and 0 or 6, y)
    title:SetText(text)
    local line = host:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.61, 0.48, 0.29, 0.6)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -6, -4)
    line:SetPoint("RIGHT", host, "RIGHT", 0, 0)
    return title
end

local function Body(host, text, anchor, y, font)
    local fs = host:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y)
    fs:SetPoint("RIGHT", host, "RIGHT", -6, 0)
    fs:SetJustifyH("LEFT")
    fs:SetSpacing(3)
    fs:SetText(text or "")
    return fs
end

local function NetworkButton(host, net)
    local b
    if net.icon then
        b = CreateFrame("Button", nil, host)
        b:SetSize(36, 36)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        b.icon:SetTexture(net.icon)
        b.icon:SetDesaturated(true)
        b.icon:SetAlpha(0.75)
        b:SetScript("OnEnter", function(self)
            self.icon:SetDesaturated(false)
            self.icon:SetAlpha(1)
            ns.OwnGameTooltip(self, "ANCHOR_TOP")
            GameTooltip:SetText(net.name, 1, 1, 1)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function(self)
            self.icon:SetDesaturated(true)
            self.icon:SetAlpha(0.75)
            GameTooltip:Hide()
        end)
    else
        b = CreateFrame("Button", nil, host, "UIPanelButtonTemplate")
        b:SetSize(100, 24)
        b:SetText(net.name)
    end
    b:SetScript("OnClick", function()
        ns.ButtonSound()
        CopyLink(net.url)
    end)
    return b
end

local function Build(host)
    -- thank you, and where to write
    local thanksTitle = Section(host, S:SectionText("about.yourFriendlyUiOverhowl"), nil, -8)
    local thanks = Body(host, S:Text("about.thanks", "text", true), thanksTitle, -12)
    -- the link note: grey and small, in brackets, right under the thank-you
    local linksNote = Body(host, "(" .. (S:Text("about.links", "text", true) or "") .. ")", thanks, -4, "GameFontDisableSmall")

    local first, previous
    for _, net in ipairs(NETWORKS) do
        if net.url then
            local b = NetworkButton(host, net)
            if previous then
                b:SetPoint("LEFT", previous, "RIGHT", 8, 0)
            else
                b:SetPoint("TOPLEFT", linksNote, "BOTTOMLEFT", 0, -16)
            end
            first, previous = first or b, b
        end
    end

    -- credits: the names are links, a click shows them to copy
    local creditsTitle = Section(host, S:SectionText("about.credits"), first or linksNote, -22)
    local credits = S:Text("about.credits", "text", true) or ""
    credits = credits:gsub("|cffffd100Clari Turela|r", Link("Clari Turela", CREDIT_LINKS.clari))
    credits = credits:gsub("|cffffd100sampconrad|r", Link("sampconrad", CREDIT_LINKS.sampconrad)
        .. " (" .. Link("GitHub", CREDIT_LINKS.sampconradGitHub) .. ")")
    Body(host, credits, creditsTitle, -12)
    host:SetHyperlinksEnabled(true)
    host:SetScript("OnHyperlinkClick", function(_, link)
        local url = link:match("^url:(.+)$")
        if url then CopyLink(url) end
    end)

    -- slash commands, in a small box at the bottom
    local box = CreateFrame("Frame", nil, host)
    box:SetPoint("BOTTOMLEFT", 0, 8)
    box:SetPoint("BOTTOMRIGHT", 0, 8)
    local bg = box:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.35)
    local edge = box:CreateTexture(nil, "ARTWORK")
    edge:SetColorTexture(0.61, 0.48, 0.29, 0.6)
    edge:SetHeight(1)
    edge:SetPoint("TOPLEFT")
    edge:SetPoint("TOPRIGHT")
    local label = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 10, -8)
    label:SetText(S:Text("about.commands", "label") or "")
    local commands = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    commands:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)
    commands:SetPoint("RIGHT", -10, 0)
    commands:SetJustifyH("LEFT")
    commands:SetSpacing(2)
    commands:SetText(S:Format(S:Text("about.commands", "text", true)) or "")
    box:SetHeight((commands:GetStringHeight() or 24) + (label:GetStringHeight() or 12) + 24)
end

S:Module{
    key = "about", group = "top", order = 1,
    navIcon = "Interface\\AddOns\\FlareUI\\Media\\Art\\Icon.png",   -- the dog
    custom = { key = "main", custom = Build },
}

S:Row{ key = "about.thanks", kind = "text" }
S:Row{ key = "about.links", kind = "text" }
S:Row{ key = "about.credits", kind = "text" }
S:Row{ key = "about.commands", kind = "text" }
