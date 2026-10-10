local ADDON_NAME, ns = ...
local L = ns.L

--------------------------------------------------
-- LAUNCHER
-- The ways into FlareUI's settings panel (Settings/Panel.lua): /fui, the key binding and the radial
-- menu's panel (FlareUI_ToggleSettings), the addon compartment on the minimap, and FlareUI's page in
-- Blizzard's Options > AddOns. Also /rl.
--------------------------------------------------

-- Fake CM is in use when at least one bar has been handed over to it
local function FakeCMInUse()
    local fcm = ns.db and ns.db.profile.fcm
    local bars = fcm and fcm.enabled and fcm.bars
    if not bars then return false end
    for i = 1, 8 do
        local bar = bars["bar" .. i]
        if bar and bar.enabled then return true end
    end
    return false
end

-- Only the commands that currently do something
local function PrintCommands()
    local function Line(command, text) print("  |cffffff00" .. command .. "|r - " .. text) end
    print("|cff00ccffFlareUI:|r " .. L["commands"])
    Line("/flareui, /fui", L["Open configuration."])
    if FakeCMInUse() then Line("/fui cm", L["Toggle Fake CM setup mode."]) end
    Line("/fui pad", L["Switch Gamepad mode on or off."])
    local qol = ns.db and ns.db.profile.tweaks
    if qol and qol.enabled and qol.way then Line("/way", L["Place a map pin (type it alone for the formats)."]) end
    Line("/rl", L["Reload UI shortcut."])
end

-- the key binding (Bindings.xml) and the radial menu's FlareUI Settings panel
BINDING_HEADER_FLAREUI = "FlareUI"
BINDING_NAME_FLAREUI_SETTINGS = L["Open Settings"]
function FlareUI_ToggleSettings()
    if ns.SettingsPanel then ns.SettingsPanel:Toggle() end
end

-- FlareUI's page in Blizzard's Options > AddOns: the banner and a way into the panel
local function RegisterOptionsPage()
    local panel = CreateFrame("Frame", "FlareUI_BlizzOptionsPanel", UIParent)
    panel.name = "FlareUI"

    local banner = panel:CreateTexture(nil, "ARTWORK")
    banner:SetTexture("Interface\\AddOns\\FlareUI\\Media\\Art\\Banner.png")
    banner:SetSize(256, 256)
    banner:SetPoint("CENTER", panel, "CENTER", 0, 60)
    banner:SetAlpha(0.9)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOP", banner, "BOTTOM", 0, -20)
    title:SetText(L["FlareUI"])
    title:SetTextColor(1, 0.82, 0)

    local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -5)
    subtitle:SetText(L["Your friendly UI overhowl"])

    local version = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    version:SetPoint("TOP", subtitle, "BOTTOM", 0, -10)
    version:SetText(L["Version: %s"]:format(C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "Dev"))
    version:SetTextColor(0.6, 0.6, 0.6)

    local credit = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    credit:SetPoint("TOP", version, "BOTTOM", 0, -6)
    credit:SetText(L["Doggie art by Clari Turela"])
    credit:SetTextColor(0.6, 0.6, 0.6)

    -- In the Gamepad UI a button here would run FlareUI code inside Blizzard's controller navigation
    -- (the client hangs), and so would /fui: the other ways in are named instead
    if ns.IsGamepadUI() then
        local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
        hint:SetPoint("TOP", credit, "BOTTOM", 0, -40)
        hint:SetWidth(420)
        hint:SetText(L["Open FlareUI's settings from the minimap's addon button or FlareUI's key binding."])
    else
        local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        open:SetSize(220, 40)
        open:SetPoint("TOP", credit, "BOTTOM", 0, -40)
        open:SetText(L["Open Configuration"])
        open:GetFontString():SetFont(GameFontNormal:GetFont(), 14, "OUTLINE")
        open:SetScript("OnClick", function() ns.SettingsPanel:Open() end)
    end

    Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(panel, panel.name))
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    RegisterOptionsPage()

    SLASH_FLARERL1 = "/rl"
    SlashCmdList.FLARERL = ns.Reload

    SLASH_FLAREUI1 = "/flareui"
    SLASH_FLAREUI2 = "/fui"
    SlashCmdList.FLAREUI = function(msg)
        msg = msg:match("^%s*(.-)%s*$"):lower()
        if msg == "" then
            ns.SettingsPanel:Toggle()
        elseif msg == "cm" then
            ns.ToggleFCMSetupMode()
        elseif msg == "pad" or msg == "gamepad" then
            ns.ToggleGamepadMode()
        else
            PrintCommands()
        end
    end
end)

-- The minimap's addon compartment (## AddonCompartmentFunc* in the TOC)
function FlareUI_OnAddonCompartmentClick(_, buttonName)
    if buttonName == "RightButton" then ns.ToggleFCMSetupMode() else ns.SettingsPanel:Toggle() end
end

function FlareUI_OnAddonCompartmentEnter(_, menuButtonFrame)
    ns.OwnGameTooltip(menuButtonFrame, "ANCHOR_LEFT")
    GameTooltip:AddLine(L["FlareUI"])
    GameTooltip:AddLine(L["Left-click: open settings"], 1, 1, 1)
    GameTooltip:AddLine(L["Right-click: toggle Fake CM setup mode"], 1, 1, 1)
    GameTooltip:Show()
end

function FlareUI_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end
