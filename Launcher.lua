local ADDON_NAME, ns = ...
local L = ns.L

--------------------------------------------------
-- LAUNCHER
-- The ways into the settings panel (Settings/Panel.lua): /fui, the key binding, the radial menu,
-- the addon compartment and FlareUI's page in Options > AddOns. Also /rl.
--------------------------------------------------

--------------------------------------------------
-- 1. SLASH COMMANDS
--------------------------------------------------
-- Lists only the commands that currently do something
local function PrintCommands()
    local function Line(command, text) print("  |cffffff00" .. command .. "|r - " .. text) end
    print("|cff00ccffFlareUI:|r " .. L["commands"])
    Line("/flareui, /fui", L["Open configuration."])
    if ns.FCMActive() then Line("/fui cm", L["Toggle Fake CM setup mode."]) end
    Line("/fui pad", L["Switch Gamepad mode on or off."])
    Line("/fui tour", L["Run the setup tour."])
    Line("/fui perf", L["Measure FlareUI's performance (type it alone for the commands)."])
    Line("/fui errors", L["Errors FlareUI caught, to copy into a bug report (\"/fui errors clear\" empties the list)."])
    local qol = ns.db and ns.db.profile.tweaks
    if qol and qol.enabled and qol.way then Line("/way", L["Place a map pin (type it alone for the formats)."]) end
    Line("/rl", L["Reload UI shortcut."])
end

--------------------------------------------------
-- 2. KEY BINDING
--------------------------------------------------
-- Bindings.xml and the radial menu's FlareUI Settings panel
BINDING_HEADER_FLAREUI = "FlareUI"
BINDING_NAME_FLAREUI_SETTINGS = L["Open Settings"]
function FlareUI_ToggleSettings()
    if ns.SettingsPanel then ns.SettingsPanel:Toggle() end
end

--------------------------------------------------
-- 3. BLIZZARD'S OPTIONS > ADDONS
--------------------------------------------------
-- A NEW tag beside FlareUI in Blizzard's AddOns list, while one of FlareUI's own pages still has one.
-- Blizzard's tag only follows list-style pages, and this one is a canvas: so a tag of our own over the
-- row, which only reads Blizzard's list and writes nothing to it. The list recycles and scrolls its rows,
-- so the row is looked up again while the window is open. Not in the Gamepad UI (see below).
local TAG_SCALE, TAG_GAP, TAG_CHECK = 0.75, 4, 0.1
local function AddListTag(category)
    local list = SettingsPanel and SettingsPanel.GetCategoryList and SettingsPanel:GetCategoryList()
    if not (list and list.ScrollBox and list.FindCategoryElementData and ns.SettingsPanel) then return end

    local watcher = CreateFrame("Frame", nil, SettingsPanel)
    local tag = ns.SettingsPanel.NewBadge(watcher)
    tag:SetScale(TAG_SCALE)
    tag:SetFrameStrata("HIGH")
    tag:Hide()

    local wanted, elapsed, placedOn = false, 0, nil
    local function FindRow()
        local data = list:FindCategoryElementData(category)
        return data and list.ScrollBox:FindFrame(data)
    end
    watcher:SetScript("OnShow", function()
        wanted = ns.Settings:AnyNew()
        elapsed, placedOn = TAG_CHECK, nil
        tag:Hide()
    end)
    watcher:SetScript("OnUpdate", function(_, delta)
        if not wanted then return end
        elapsed = elapsed + delta
        if elapsed < TAG_CHECK then return end
        elapsed = 0
        local ok, row = pcall(FindRow)
        local label = ok and row and row:IsVisible() and row.Label
        if not label then
            tag:Hide()
            placedOn = nil
            return
        end
        if placedOn ~= row then
            placedOn = row
            tag:ClearAllPoints()
            tag:SetPoint("LEFT", label, "LEFT", (label:GetStringWidth() + TAG_GAP) / TAG_SCALE, 0)
        end
        tag:Show()
    end)
end

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

    -- In the Gamepad UI a button here (or /fui) runs FlareUI code inside Blizzard's controller
    -- navigation and hangs the client: the other ways in are named instead
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
        -- a family: GameFontNormal's file alone draws Russian as boxes on an English client
        ns.SetFontFamily(open:GetFontString(), (GameFontNormal:GetFont()), 14, "OUTLINE")
        -- (11-11 Marcus) Blizzard's Options closes as FlareUI's window opens: its own Close, which keeps
        -- the settings (asking first if some are unapplied) and skips going back to the game menu
        open:SetScript("OnClick", function()
            ns.SettingsPanel:Open()
            if SettingsPanel and SettingsPanel:IsShown() and SettingsPanel.Close then pcall(SettingsPanel.Close, SettingsPanel, true) end
        end)
    end

    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
    if not ns.IsGamepadUI() then AddListTag(category) end
end

--------------------------------------------------
-- 4. LOGIN
--------------------------------------------------
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
        local raw = msg:match("^%s*(.-)%s*$")
        msg = raw:lower()
        if msg == "" then
            ns.SettingsPanel:Toggle()
        elseif msg == "cm" then
            ns.ToggleFCMSetupMode()
        elseif msg == "pad" or msg == "gamepad" then
            ns.ToggleGamepadMode()
        elseif msg == "tour" then
            ns.ShowTour()
        elseif msg == "perf" or msg:find("^perf%s") then
            ns.Perf.Command(raw:sub(5))   -- keeps the recording name's case
        elseif msg == "errors" or msg:find("^errors%s") then
            ns.ErrorsCommand(msg:sub(8))
        elseif msg == "taint" or msg:find("^taint%s") then
            ns.TaintWatch.Command(msg:sub(6))   -- a developer's Gamepad UI probe (TaintWatch.lua)
        elseif msg == "range" then
            -- a developer's probe for target / focus range fading (UnitFrames.lua), for bug reports
            if ns.UnitFrames and ns.UnitFrames.RangeReport then ns.UnitFrames.RangeReport() end
        else
            PrintCommands()
        end
    end
end)

--------------------------------------------------
-- 5. ADDON COMPARTMENT (## AddonCompartmentFunc* in the TOC)
--------------------------------------------------
function FlareUI_OnAddonCompartmentClick(_, buttonName)
    if buttonName == "RightButton" then ns.ToggleFCMSetupMode() else ns.SettingsPanel:Toggle() end
end

function FlareUI_OnAddonCompartmentEnter(_, menuButtonFrame)
    ns.OwnGameTooltip(menuButtonFrame, "ANCHOR_LEFT")
    GameTooltip:AddLine(L["FlareUI"])
    GameTooltip:AddLine(L["Left-click: open settings"], 1, 1, 1)
    if ns.FCMActive() then GameTooltip:AddLine(L["Right-click: toggle Fake CM setup mode"], 1, 1, 1) end
    GameTooltip:Show()
end

function FlareUI_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end
