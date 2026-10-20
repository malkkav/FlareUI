local _, ns = ...
local L = ns.L

--------------------------------------------------
-- WELCOME
-- Shown once per account on first load: every module ships off, so it points to the settings.
--------------------------------------------------

--------------------------------------------------
-- 1. THE WINDOW
--------------------------------------------------
local LSM = LibStub("LibSharedMedia-3.0")

local WIDTH, HEIGHT = 400, 330
local BANNER = "Interface\\AddOns\\FlareUI\\Media\\Art\\Banner.png"
local SUBTITLE = L["Your friendly UI overhowl"]
local TEXT = L["Every module of this addon starts switched off.\nTo begin, open the settings and enable the modules you want to use."]

local welcome

-- an account with any module on has no need for it
local function AnyModuleEnabled()
    local S = ns.Settings
    if not (S and ns.db and ns.db.profile) then return false end
    for _, module in pairs(S.modules) do
        if module.enabled and module:IsOn() then return true end
    end
    return false
end

local function RedButton(text, width, onClick)
    local b = CreateFrame("Button", nil, welcome, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(text)
    b:SetScript("OnClick", function()
        ns.ButtonSound()
        onClick()
    end)
    return b
end

local function OpenSettings()
    welcome:Hide()
    ns.SettingsPanel:Open()
end

local function Build()
    local style = ns.WINDOW_STYLE
    welcome = CreateFrame("Frame", "FlareUI_Welcome", UIParent, "BackdropTemplate")
    welcome:SetSize(WIDTH, HEIGHT)
    welcome:SetPoint("CENTER", 0, 80)
    welcome:SetFrameStrata("FULLSCREEN_DIALOG")
    welcome:SetToplevel(true)
    welcome:EnableMouse(true)
    welcome:SetMovable(true)
    welcome:RegisterForDrag("LeftButton")
    welcome:SetScript("OnDragStart", welcome.StartMoving)
    welcome:SetScript("OnDragStop", welcome.StopMovingOrSizing)
    welcome:SetBackdrop({ edgeFile = LSM:Fetch("border", "Blizzard Tooltip"), edgeSize = 16 })
    welcome:SetBackdropBorderColor(style.border[1], style.border[2], style.border[3], 1)
    ns.Fade(welcome, 5, style.top, style.bottom)
    welcome:Hide()
    tinsert(UISpecialFrames, "FlareUI_Welcome")

    welcome:SetScript("OnShow", ns.WindowOpenSound)
    -- seen however it closes (either button or Escape)
    welcome:SetScript("OnHide", function()
        ns.WindowCloseSound()
        if ns.db and ns.db.global then ns.db.global.welcomeSeen = true end
    end)

    local banner = welcome:CreateTexture(nil, "ARTWORK")
    banner:SetTexture(BANNER)
    banner:SetSize(120, 120)
    banner:SetPoint("TOP", 0, -22)

    local title = welcome:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", banner, "BOTTOM", 0, -14)
    title:SetText(L["Welcome to FlareUI!"])

    local subtitle = welcome:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -6)
    subtitle:SetText(SUBTITLE)

    local body = welcome:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body:SetPoint("TOP", subtitle, "BOTTOM", 0, -14)
    body:SetWidth(WIDTH - 60)
    body:SetJustifyH("CENTER")
    body:SetSpacing(2)
    body:SetText(TEXT)

    local open = RedButton(L["Open Settings"], 140, OpenSettings)
    open:SetPoint("BOTTOMRIGHT", welcome, "BOTTOM", -4, 20)
    local close = RedButton(CLOSE or "Close", 140, function() welcome:Hide() end)
    close:SetPoint("BOTTOMLEFT", welcome, "BOTTOM", 4, 20)
end

--------------------------------------------------
-- 2. FIRST LOGIN
--------------------------------------------------
local function ShowWelcome()
    if not welcome then Build() end
    welcome:Show()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    local global = ns.db and ns.db.global
    if not global or global.welcomeSeen then return end
    if AnyModuleEnabled() then
        global.welcomeSeen = true
        return
    end
    -- after the loading screen has cleared
    C_Timer.After(2, ShowWelcome)
end)
