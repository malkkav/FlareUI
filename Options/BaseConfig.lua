local ADDON_NAME, ns = ...
local L = ns.L
local LSM = LibStub("LibSharedMedia-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0", true)

--------------------------------------------------
-- 1. UPVALUES
--------------------------------------------------
local ipairs = ipairs
local HideUIPanel = HideUIPanel
local SettingsPanel = SettingsPanel
local CreateFrame = CreateFrame

--------------------------------------------------
-- 2. HELPERS
--------------------------------------------------
-- Options window skin: solid black, outer border in the UI bronze (#CC9957), every inner AceGUI
-- border (inline groups, tabs, tree, status bar) in a muted bronze (#9C7A4A).
local OUTER_BORDER = { 0.80, 0.60, 0.34 }
local INNER_BORDER = { 0.61, 0.48, 0.29 }
local ACEGUI_DEFAULT_BORDER = { 0.4, 0.4, 0.4 }
-- the same two stops the radial editor fades between, so both windows read as one piece of UI
local BG_TOP    = { 0.085, 0.075, 0.060, 1 }
local BG_BOTTOM = { 0.015, 0.015, 0.015, 1 }

-- Shared with FlareUI windows built outside AceGUI (Welcome.lua), so they wear the same skin.
ns.WINDOW_STYLE = { border = OUTER_BORDER, top = BG_TOP, bottom = BG_BOTTOM }

local function IsOptionsOpen()
    return AceConfigDialog.OpenFrames["FlareUI"] ~= nil
end

-- tints every backdrop border below the given frame (not the frame itself)
local function TintInnerBorders(frame, color)
    for _, child in ipairs({ frame:GetChildren() }) do
        if child.GetBackdrop and child.SetBackdropBorderColor then
            local backdrop = child:GetBackdrop()
            if backdrop and backdrop.edgeFile then
                child:SetBackdropBorderColor(color[1], color[2], color[3], 1)
            end
        end
        TintInnerBorders(child, color)
    end
end

-- The Ace tooltips are MEDIUM strata, below the options window: raised to GameTooltip's strata
for _, name in ipairs({ "AceConfigDialogTooltip", "AceGUITooltip" }) do
    local tip = _G[name]
    if tip and tip.SetFrameStrata then tip:SetFrameStrata("TOOLTIP") end
end

-- A vertical gradient from a warm dark at the top to near black at the bottom
local function Fade(frame, inset, top, bottom)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", inset, -inset)
    bg:SetPoint("BOTTOMRIGHT", -inset, inset)
    if bg.SetGradient and CreateColor then
        bg:SetColorTexture(1, 1, 1)
        bg:SetGradient("VERTICAL", CreateColor(bottom[1], bottom[2], bottom[3], bottom[4]),
                                   CreateColor(top[1], top[2], top[3], top[4]))
    else
        bg:SetColorTexture(bottom[1], bottom[2], bottom[3], bottom[4])
    end
    return bg
end
ns.Fade = Fade

-- AceGUI's frames are pooled and shared with other addons, so our pieces show only while this
-- window is open. The Frame widget hides its status bar and close button: the status bar is found
-- through its font string, and the Reset button is placed by the close button's numbers.
local function GetStatusBar(widget)
    local text = widget.statustext
    return text and text.GetParent and text:GetParent() or nil
end

-- Stands in for AceGUI's close handler while the frame is ours; see BuildChrome.
local function CloseClick(button)
    ns.ButtonSound()
    button.obj:Hide()
end

local function BuildChrome(widget, f)
    if not f.flareChrome then
        f.flareChrome = {
            Fade(f, 5, BG_TOP, BG_BOTTOM),
        }

        local reset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        reset:SetSize(140, 20)
        -- red on the label rather than the button art, so it survives the button's own state changes
        reset:SetText(L["|cffff4040Reset to Defaults|r"])
        reset:SetPoint("BOTTOMRIGHT", -135, 17)
        reset:SetScript("OnClick", function()
            ns.ButtonSound()
            ns.ShowDialog("FLAREUI_RESET")
        end)
        f.flareChrome[#f.flareChrome + 1] = reset
        f.flareResetButton = reset   -- for the controller navigation (ControllerNav.lua)

        -- AceGUI's close button, found by its label
        for _, child in ipairs({ f:GetChildren() }) do
            if child:GetObjectType() == "Button" and child.GetText and child:GetText() == CLOSE then
                f.flareCloseButton, f.flareCloseOriginal = child, child:GetScript("OnClick")
            end
        end

        f:HookScript("OnHide", function(self)
            for _, piece in ipairs(self.flareChrome) do piece:Hide() end
            if self.flareStatusBg then self.flareStatusBg:Show() end
            -- only when it was our window closing: the pooled frame also serves other addons
            if self.flareSounded then
                self.flareSounded = nil
                ns.WindowCloseSound()
            end
            if self.flareCloseButton and self.flareCloseOriginal then
                self.flareCloseButton:SetScript("OnClick", self.flareCloseOriginal)
            end
        end)
    end

    for _, piece in ipairs(f.flareChrome) do piece:Show() end

    -- Once per real opening: AceConfigDialog runs Open again on every refresh.
    if not f.flareSounded then
        f.flareSounded = true
        ns.WindowOpenSound()
    end
    -- the close button clicks like every red button (its own handler goes back on hide)
    if f.flareCloseButton then f.flareCloseButton:SetScript("OnClick", CloseClick) end
    -- the empty status bar is hidden
    local statusbg = GetStatusBar(widget)
    if statusbg then
        f.flareStatusBg = statusbg
        statusbg:Hide()
    end
end

function ns.ForceOpacity()
    local widget = AceConfigDialog.OpenFrames["FlareUI"]
    if widget and widget.frame then
        local f = widget.frame

        if f.SetBackdrop then
            -- edge only: the gradient below carries the fill
            f:SetBackdrop({
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 16,
                insets = { left = 4, right = 4, top = 4, bottom = 4 }
            })
            f:SetBackdropBorderColor(OUTER_BORDER[1], OUTER_BORDER[2], OUTER_BORDER[3], 1)
        end
        BuildChrome(widget, f)
        TintInnerBorders(f, INNER_BORDER)
    end
end

-- Group containers and sliders tint themselves as they are acquired while our window is open (and
-- go back to AceGUI's grey for another addon)
do
    local AceGUI = LibStub("AceGUI-3.0", true)
    if AceGUI and AceGUI.WidgetRegistry then
        -- AceGUI's buttons play their own click; noting it keeps a window they open quiet
        local buttonConstructor = AceGUI.WidgetRegistry.Button
        if buttonConstructor then
            AceGUI.WidgetRegistry.Button = function(...)
                local widget = buttonConstructor(...)
                widget.frame:HookScript("PreClick", ns.NoteClick)
                return widget
            end
        end

        for _, widgetType in ipairs({ "InlineGroup", "TabGroup", "TreeGroup", "DropdownGroup" }) do
            local constructor = AceGUI.WidgetRegistry[widgetType]
            if constructor then
                AceGUI.WidgetRegistry[widgetType] = function(...)
                    local widget = constructor(...)
                    local acquire = widget.OnAcquire
                    widget.OnAcquire = function(self, ...)
                        if acquire then acquire(self, ...) end
                        TintInnerBorders(self.frame, IsOptionsOpen() and INNER_BORDER or ACEGUI_DEFAULT_BORDER)
                    end
                    return widget
                end
            end
        end

        -- sliders too, and their value box's hover (AceGUI greys it again on every hover)
        local sliderConstructor = AceGUI.WidgetRegistry.Slider
        if sliderConstructor then
            AceGUI.WidgetRegistry.Slider = function(...)
                local widget = sliderConstructor(...)
                local acquire = widget.OnAcquire
                widget.OnAcquire = function(self, ...)
                    if acquire then acquire(self, ...) end
                    TintInnerBorders(self.frame, IsOptionsOpen() and INNER_BORDER or ACEGUI_DEFAULT_BORDER)
                end
                local box = widget.editbox
                if box then
                    box:HookScript("OnEnter", function(b)
                        if IsOptionsOpen() then b:SetBackdropBorderColor(OUTER_BORDER[1], OUTER_BORDER[2], OUTER_BORDER[3], 1) end
                    end)
                    box:HookScript("OnLeave", function(b)
                        if IsOptionsOpen() then b:SetBackdropBorderColor(INNER_BORDER[1], INNER_BORDER[2], INNER_BORDER[3], 1) end
                    end)
                end
                return widget
            end
        end
    end
end

-- refreshes (NotifyChange) re-run Open; re-apply the skin every time
hooksecurefunc(AceConfigDialog, "Open", function(_, app)
    if app == "FlareUI" then ns.ForceOpacity() end
end)

-- AceDBOptions' page without its prose, on the settings' 1.0 / 0.1 grid
local function TidyProfileOptions(opts)
    local a = opts and opts.args
    if not a then return end
    for _, key in ipairs({ "desc", "descreset", "current", "choosedesc", "copydesc", "deldesc" }) do
        a[key] = nil
    end

    a.choose.order,   a.choose.width   = 10, 1.0
    a.spacerChoose = { type = "description", name = "", width = 0.1, order = 11 }
    a.new.order,      a.new.width, a.new.name = 20, 1.0, L["New Profile"]
    a.breakNew = { type = "description", name = " ", order = 25, width = "full" }

    a.copyfrom.order, a.copyfrom.width = 30, 1.0
    a.spacerCopy = { type = "description", name = "", width = 0.1, order = 31 }
    a.delete.order,   a.delete.width   = 40, 1.0
    a.breakCopy = { type = "description", name = " ", order = 45, width = "full" }

    a.reset.order,    a.reset.width    = 50, 1.0
end

local function RefreshConfig()
    if LibStub("AceConfigRegistry-3.0") then
        LibStub("AceConfigRegistry-3.0"):NotifyChange("FlareUI")
    end
end

local function CleanFontName(name)
    if name:find("\\") or name:find("/") then
        local clean = name:match("([^\\/]+)$") or name
        clean = clean:gsub("%.[Tt][Tt][Ff]$", ""):gsub("%.[Oo][Tt][Ff]$", "")
        clean = clean:gsub("_", " ")
        return clean
    end
    return name
end

--------------------------------------------------
-- 3. MAIN OPTIONS TABLE (Standalone Window)
--------------------------------------------------
-- The module list, in the tree's order. A module loads at PLAYER_LOGIN, so a toggle asks for a reload.
local MODULE_TOGGLES = {
    { key = "chat",        label = L["Chat"] },
    { key = "damagemeter", label = L["Damage Meter"] },
    { key = "radialmenu",  label = L["Radial Menu"] },
    { key = "unitframes",  label = L["Unit Frames"] },
    { key = "actionbars",  label = L["Action Bars"] },
    { key = "auras",       label = L["Buffs / Debuffs"] },
    { key = "objectivetracker", label = L["Quest Tracker"] },
    { key = "minimap",     label = L["Minimap"] },
    { key = "tooltips",    label = L["Tooltips"] },
    { key = "tweaks",      label = L["Tweaks"] },
}
-- the welcome reads it to tell a fresh install from one that already has modules on
ns.MODULE_TOGGLES = MODULE_TOGGLES

-- Fake CM is in use when at least one bar has been handed over to it
local function FakeCMInUse()
    local bars = ns.db and ns.db.profile.fcm and ns.db.profile.fcm.bars
    if not bars then return false end
    for i = 1, 8 do
        local bar = bars["bar" .. i]
        if bar and bar.enabled then return true end
    end
    return false
end

-- Fake CM Setup Mode: the FCM bars take clicks (session only)
function ns.ToggleFCMSetupMode()
    if InCombatLockdown() then
        print("|cffff0000FlareUI:|r " .. L["Cannot toggle setup mode in combat."])
        return
    end
    local fcm = ns.db.profile.fcm
    fcm.setupModeEnabled = not fcm.setupModeEnabled
    if ns.ActionBars then ns.ActionBars:SetFCM_UnlockMode(fcm.setupModeEnabled) end
    print("|cff00ff00FlareUI:|r " .. (fcm.setupModeEnabled and L["Fake CM setup mode on."] or L["Fake CM setup mode off."]))
end

-- Only the commands that currently do something
local function BuildCommandList()
    local function Line(command, text) return "|cffffff00" .. command .. "|r - " .. text end
    local lines = { Line("/flareui, /fui", L["Open configuration."]) }
    if FakeCMInUse() then lines[#lines + 1] = Line("/fui cm", L["Toggle Fake CM setup mode."]) end
    if ns.db and ns.db.profile.radialmenu and ns.db.profile.radialmenu.enabled then
        lines[#lines + 1] = Line("/fui re", L["Open the radial editor."])
    end
    lines[#lines + 1] = Line("/fui pad", L["Switch Gamepad mode on or off."])
    local chat = ns.db and ns.db.profile.chat
    if chat and chat.enabled then
        if chat.enableWay then lines[#lines + 1] = Line("/way", L["Place a map pin (type it alone for the formats)."]) end
    end
    lines[#lines + 1] = Line("/rl", L["Reload UI shortcut."])
    return table.concat(lines, "\n") .. "\n"
end

local function BuildModuleToggles()
    local args = {}
    for index, entry in ipairs(MODULE_TOGGLES) do
        local key = entry.key
        args["enable_" .. key] = {
            type = "toggle", name = entry.label, order = index * 10, width = 0.9,
            get = function() return ns.db.profile[key].enabled end,
            set = function(_, val)
                ns.db.profile[key].enabled = val
                RefreshConfig()
                ns.ShowDialog("FLAREUI_RELOAD")
            end,
        }
        -- keeps two toggles per row instead of three
        args["spacer_" .. key] = { type = "description", name = "", width = 0.1, order = index * 10 + 1 }
    end
    return args
end

ns.Options = {
    type = "group",
    name = L["FlareUI"],
    childGroups = "tree",
    args = {
        modules = {
            type = "group", name = L["Modules"], order = 10,
            args = {
                selectionGroup = {
                    type = "group", name = L["Module Selection"], order = 10, inline = true,
                    args = BuildModuleToggles(),
                },

                spacer1 = { type = "description", name = " ", order = 25 },

                cmdList = {
                    type = "group", name = L["Console Commands"], order = 60, inline = true,
                    args = {
                        list = {
                            type = "description",
                            name = BuildCommandList,
                            fontSize = "medium",
                            order = 10
                        }
                    }
                },

            },
        },

        profiles = nil,
    },
}

--------------------------------------------------
-- 4. CUSTOM BLIZZARD OPTIONS PANEL
--------------------------------------------------
local function CreateBlizzardOptionsPanel()
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
    subtitle:SetTextColor(1, 1, 1)

    local versionText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    versionText:SetPoint("TOP", subtitle, "BOTTOM", 0, -10)
    local version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "Dev"
    versionText:SetText(L["Version: %s"]:format(version))
    versionText:SetTextColor(0.6, 0.6, 0.6)

    local artCredit = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    artCredit:SetPoint("TOP", versionText, "BOTTOM", 0, -6)
    artCredit:SetText(L["Doggie art by Clari Turela"])
    artCredit:SetTextColor(0.6, 0.6, 0.6)

    -- in the Gamepad UI a button here would run our code inside Blizzard's navigation: point to /fui
    if ns.IsGamepadUI() then
        local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
        hint:SetPoint("TOP", artCredit, "BOTTOM", 0, -40)
        hint:SetText(L["Type |cffffff00/fui|r in chat to access FlareUI settings while in gamepad mode"])
    else
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetSize(220, 40)
        btn:SetPoint("TOP", artCredit, "BOTTOM", 0, -40)
        btn:SetText(L["Open Configuration"])
        btn:GetFontString():SetFont(GameFontNormal:GetFont(), 14, "OUTLINE")
        btn:SetScript("OnClick", function()
            if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
            AceConfigDialog:Open("FlareUI")
            ns.ForceOpacity()
        end)
    end

    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
end

--------------------------------------------------
-- 5. INITIALIZATION
--------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    if AceDBOptions and ns.db then
        local profileOpts = AceDBOptions:GetOptionsTable(ns.db)
        TidyProfileOptions(profileOpts)

        ns.Options.args.profiles = profileOpts
        ns.Options.args.profiles.order = 999
    end

    if AceConfig and AceConfigDialog then
        AceConfig:RegisterOptionsTable("FlareUI", ns.Options)
        AceConfigDialog:SetDefaultSize("FlareUI", 1050, 650)
    end

    CreateBlizzardOptionsPanel()

    -- [[ GLOBAL SLASH COMMANDS ]]
    SLASH_FLARERL1 = "/rl"
    SlashCmdList.FLARERL = ns.Reload

    SLASH_FLAREUI1 = "/flareui"
    SLASH_FLAREUI2 = "/fui"

    SlashCmdList.FLAREUI = function(msg)
        msg = msg:match("^%s*(.-)%s*$"):lower()

        if msg == "" then
            if AceConfigDialog then
                AceConfigDialog:Open("FlareUI")
                ns.ForceOpacity()
            end
        elseif msg == "cm" then
            ns.ToggleFCMSetupMode()
        elseif msg == "re" or msg == "radialeditor" then
            ns.ToggleRadialEditor()
        elseif msg == "pad" or msg == "gamepad" then
            ns.ToggleGamepadMode()
        else
            print("|cff00ccffFlareUI:|r " .. L["commands"])
            for line in BuildCommandList():gmatch("[^\n]+") do print("  " .. line) end
        end
    end

    -- [[ MINIMAP ADDON COMPARTMENT ]] (declared via ## AddonCompartmentFunc* in the TOC)
    function FlareUI_OnAddonCompartmentClick(addonName, buttonName)
        if buttonName == "RightButton" then
            SlashCmdList.FLAREUI("cm")
        else
            SlashCmdList.FLAREUI("")
        end
    end

    function FlareUI_OnAddonCompartmentEnter(addonName, menuButtonFrame)
        ns.OwnGameTooltip(menuButtonFrame, "ANCHOR_LEFT")
        GameTooltip:AddLine(L["FlareUI"])
        GameTooltip:AddLine(L["Left-click: open settings"], 1, 1, 1)
        GameTooltip:AddLine(L["Right-click: toggle Fake CM setup mode"], 1, 1, 1)
        GameTooltip:Show()
    end

    function FlareUI_OnAddonCompartmentLeave()
        GameTooltip:Hide()
    end
end)

--------------------------------------------------
-- 6. FONT OPTION GENERATOR
--------------------------------------------------
function ns.CreateFontOptions(order, label, path, dbKey, showColor, showPos)
    local fontWidget = nil
    if LibStub("AceGUI-3.0").WidgetRegistry["LSM30_Font"] then
        fontWidget = "LSM30_Font"
    end

    local function GetFontList()
        local t = {}
        for _, name in ipairs(LSM:List("font")) do
            local cleanName = CleanFontName(name)
            local isPath = name:find("\\") or name:find("/")
            local duplicateExists = false

            if isPath then
                 if LSM:Fetch("font", cleanName) and cleanName ~= name then duplicateExists = true end
                 if cleanName:find("FRIZQT") or cleanName:find("Friz") then
                     if LSM:Fetch("font", "Friz Quadrata TT") then duplicateExists = true end
                 end
            end

            if not duplicateExists then
                if fontWidget then t[name] = cleanName else t[name] = name end
            end
        end
        return t
    end

    local function GetDBVal(key)
        local group = ns.db.profile[path] and ns.db.profile[path][dbKey]
        if group and group[key] ~= nil then return group[key] end
        local defGroup = ns.defaults.profile[path] and ns.defaults.profile[path][dbKey]
        if defGroup then return defGroup[key] end
    end

    local function SetDBVal(key, val)
        if ns.db.profile[path] and ns.db.profile[path][dbKey] then
            ns.db.profile[path][dbKey][key] = val

            if path == "chat" and ns.Chat then ns.Chat:RefreshAll()
            elseif path == "damagemeter" and ns.DamageMeter then ns.DamageMeter:Refresh()
            elseif path == "actionbars" and ns.ActionBars then ns.ActionBars:Refresh()
            elseif path == "unitframes" and ns.UnitFrames then ns.UnitFrames:Refresh()
            elseif path == "auras" and ns.Auras then ns.Auras:Refresh()
            elseif path == "tooltips" and ns.Tooltips then ns.Tooltips:Refresh()
            elseif path == "objectivetracker" and ns.ObjectiveTracker then ns.ObjectiveTracker:Refresh()
            end
        end
    end

    local group = {
        type = "group", name = label, order = order, inline = true,
        args = {
            face = {
                type = "select", dialogControl = fontWidget, name = L["Font Face"], order = 10, width = 1.0,
                values = GetFontList,
                get = function() return GetDBVal("face") end,
                set = function(_, val) SetDBVal("face", val) end,
            },

            spacerH = { type = "description", name = "", width = 0.1, order = 15 },

            size = {
                type = "range", name = L["Font Size"], min = 8, max = 32, step = 1, order = 20, width = 1.0,
                get = function() return GetDBVal("size") end,
                set = function(_, val) SetDBVal("size", val) end,
            },

            break1 = { type = "description", name = " ", order = 25, width = "full" },

            flags = {
                type = "select", name = L["Font Outline"], order = 30, width = 1.0,
                values = { ["NONE"] = L["None"], ["OUTLINE"] = L["Outline"], ["THICKOUTLINE"] = L["Thick Outline"], ["MONOCHROME"] = L["Monochrome"] },
                get = function() return GetDBVal("flags") end,
                set = function(_, val) SetDBVal("flags", val) end,
            },

            spacerH2 = { type = "description", name = "", width = 0.1, order = 35 },

            enableShadow = {
                type = "toggle", name = L["Enable Shadow"], order = 40,
                get = function() return GetDBVal("enableShadow") end,
                set = function(_, val)
                    SetDBVal("enableShadow", val)
                    if val then SetDBVal("shadowX", 1); SetDBVal("shadowY", -1) end
                end
            },
            shadowBreak1 = { type = "description", name = " ", order = 41, width = "full" },
            shadowX = { type = "range", name = L["Shadow X"], min = -5, max = 5, step = 1, order = 42, width = 1.0,
                disabled = function() return not GetDBVal("enableShadow") end,
                get = function() return GetDBVal("shadowX") or 1 end,
                set = function(_, val) SetDBVal("shadowX", val) end,
            },
            spacerShadow = { type = "description", name = "", width = 0.1, order = 42.5 },   -- lines Shadow Y up under Font Size
            shadowY = { type = "range", name = L["Shadow Y"], min = -5, max = 5, step = 1, order = 43, width = 1.0,
                disabled = function() return not GetDBVal("enableShadow") end,
                get = function() return GetDBVal("shadowY") or -1 end,
                set = function(_, val) SetDBVal("shadowY", val) end,
            },
            shadowBreak2 = { type = "description", name = " ", order = 44, width = "full" },
        }
    }

    if showPos then
        group.args.break2 = { type = "description", name = " ", order = 50, width = "full" }
        group.args.offsetX = { type = "range", name = L["X Offset"], min = -20, max = 20, step = 1, order = 60, get = function() return GetDBVal("x") or 0 end, set = function(_, val) SetDBVal("x", val) end }
        group.args.spacerPosH = { type = "description", name = "", width = 0.1, order = 65 }
        group.args.offsetY = { type = "range", name = L["Y Offset"], min = -20, max = 20, step = 1, order = 70, get = function() return GetDBVal("y") or 0 end, set = function(_, val) SetDBVal("y", val) end }
    end

    if showColor then
        group.args.breakColor = { type = "description", name = " ", order = 80, width = "full" }

        group.args.useCustomColor = {
            type = "toggle", name = L["Override Text Color"], order = 90, width = 1.0,
            get = function() return GetDBVal("useCustomColor") end,
            set = function(_, val) SetDBVal("useCustomColor", val) end
        }

        group.args.spacerColorH = { type = "description", name = "", width = 0.1, order = 95 }

        group.args.mainColor = {
            type = "color", name = L["Text Color"], order = 100, hasAlpha = false,
            disabled = function() return not GetDBVal("useCustomColor") end,
            get = function() local c = GetDBVal("color"); if c then return c.r, c.g, c.b else return 1, 1, 1 end end,
            set = function(_, r, g, b) SetDBVal("color", {r=r, g=g, b=b, a=1}) end
        }
    end

    return group
end
