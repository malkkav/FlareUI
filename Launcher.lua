local ADDON_NAME, ns = ...
local L = ns.L

--------------------------------------------------
-- LAUNCHER
-- The ways into FlareUI's settings panel (Settings/Panel.lua): /fui, the key binding and the radial
-- menu's panel (FlareUI_ToggleSettings), the addon compartment on the minimap, and FlareUI's page in
-- Blizzard's Options > AddOns. Also /rl.
--------------------------------------------------

--------------------------------------------------
-- 1. SLASH COMMANDS
--------------------------------------------------
-- Only the commands that do something right now
local function PrintCommands()
    local function Line(command, text) print("  |cffffff00" .. command .. "|r - " .. text) end
    print("|cff00ccffFlareUI:|r " .. L["commands"])
    Line("/flareui, /fui", L["Open configuration."])
    if ns.FCMActive() then Line("/fui cm", L["Toggle Fake CM setup mode."]) end
    Line("/fui pad", L["Switch Gamepad mode on or off."])
    local qol = ns.db and ns.db.profile.tweaks
    if qol and qol.enabled and qol.way then Line("/way", L["Place a map pin (type it alone for the formats)."]) end
    Line("/rl", L["Reload UI shortcut."])
end

--------------------------------------------------
-- 2. KEY BINDING
--------------------------------------------------
-- the key binding (Bindings.xml) and the radial menu's FlareUI Settings panel
BINDING_HEADER_FLAREUI = "FlareUI"
BINDING_NAME_FLAREUI_SETTINGS = L["Open Settings"]
function FlareUI_ToggleSettings()
    if ns.SettingsPanel then ns.SettingsPanel:Toggle() end
end

--------------------------------------------------
-- 3. BLIZZARD'S OPTIONS > ADDONS
--------------------------------------------------
-- FlareUI's page there: the banner and a way into the panel
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
        msg = msg:match("^%s*(.-)%s*$"):lower()
        if msg == "" then
            ns.SettingsPanel:Toggle()
        elseif msg == "cm" then
            ns.ToggleFCMSetupMode()
        elseif msg == "pad" or msg == "gamepad" then
            ns.ToggleGamepadMode()
        elseif msg:match("^art") then
            ns.ArtDump(tonumber(msg:match("^art%s*(%d)")) or 1)   -- TEMPORARY (frame-plate branch): remove before release
        else
            PrintCommands()
        end
    end
end)

--------------------------------------------------
-- TEMPORARY (frame-plate branch): /fui art draws Blizzard's unit frame atlases at 3 screen pixels
-- per art pixel, unfiltered, on black and on white, with their atlas data, for a screenshot to
-- measure the plate from. /fui art: the target; art 2: the player; art 3: the bars, their masks and
-- the name strip. Click to close.
--------------------------------------------------
local artDump
function ns.ArtDump(page)
    if artDump then artDump:Hide() end
    local ZOOM = 3
    local sets = {
        { "UI-HUD-UnitFrame-Target-PortraitOn" },
        { "UI-HUD-UnitFrame-Player-PortraitOn" },
        { "UI-HUD-UnitFrame-Target-PortraitOn-Type", "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health",
          "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health-Mask", "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Mana",
          "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Mana-Mask", "UI-HUD-UnitFrame-Target-PortraitOn-Bar-TempHPLoss" },
    }
    local f = CreateFrame("Button", nil, UIParent)
    artDump = f
    f:SetFrameStrata("TOOLTIP")
    -- frame units = physical pixels
    f:SetScale(1 / UIParent:GetEffectiveScale())
    f:SetAllPoints(UIParent)
    f:SetScript("OnClick", function(self) self:Hide() end)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.25, 0.25, 0.25, 1)
    local y, lines = -10, {}
    local screenW = f:GetWidth()
    for _, atlas in ipairs(sets[page] or sets[1]) do
        local info = C_Texture.GetAtlasInfo(atlas)
        if info then
            local w, h = info.width * ZOOM, info.height * ZOOM
            -- black and white side by side when they fit, else one above the other
            local across = 2 * w + 30 <= screenW
            for col, shade in ipairs({ 0, 1 }) do
                local x = across and 10 + (col - 1) * (w + 20) or 10
                local yy = across and y or y - (col - 1) * (h + 10)
                local back = f:CreateTexture(nil, "BORDER")
                back:SetColorTexture(shade, shade, shade, 1)
                back:SetPoint("TOPLEFT", x, yy)
                back:SetSize(w, h)
                local t = f:CreateTexture(nil, "ARTWORK")
                t:SetAtlas(atlas, false, "NEAREST")
                t:SetTexelSnappingBias(0)
                t:SetSnapToPixelGrid(false)
                t:SetPoint("TOPLEFT", x, yy)
                t:SetSize(w, h)
            end
            lines[#lines + 1] = string.format("%s  %dx%d  file %s  coords %.6f %.6f %.6f %.6f  tile %s/%s",
                atlas, info.width, info.height, tostring(info.file), info.leftTexCoord, info.rightTexCoord,
                info.topTexCoord, info.bottomTexCoord, tostring(info.tilesHorizontally), tostring(info.tilesVertically))
            y = y - h - 16 - (across and 0 or h + 10)
        else
            lines[#lines + 1] = atlas .. "  (no atlas)"
        end
    end
    local text = f:CreateFontString(nil, "OVERLAY")
    text:SetFont("Fonts\\ARIALN.TTF", 16, "")
    text:SetTextColor(1, 1, 0.4)
    text:SetJustifyH("LEFT")
    text:SetPoint("BOTTOMLEFT", 10, 10)
    text:SetText(table.concat(lines, "\n") .. "\nclick to close")
    f:Show()
end

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
    GameTooltip:AddLine(L["Right-click: toggle Fake CM setup mode"], 1, 1, 1)
    GameTooltip:Show()
end

function FlareUI_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end
