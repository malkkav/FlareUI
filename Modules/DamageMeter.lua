local _, ns = ...
local L = ns.L

--------------------------------------------------
-- DAMAGE METER
-- Blizzard's damage meter in FlareUI's look: skinned windows, header and fonts, group buttons
-- (ready check, countdown), a Threat tab, a live combat timer, the chat's size, and FlareUI's own
-- visibility with show on mouseover.
--------------------------------------------------

--------------------------------------------------
-- 1. MODULE REGISTRATION
--------------------------------------------------
ns.DamageMeter = ns.DamageMeter or {}
local DamageMeter = ns.DamageMeter
ns.modules["DamageMeter"] = DamageMeter

LibStub("AceEvent-3.0"):Embed(DamageMeter)

--------------------------------------------------
-- 2. UPVALUES
--------------------------------------------------
local _G = _G
local pairs, ipairs = pairs, ipairs
local pcall = pcall
local math_max = math.max
local math_min = math.min
local InCombatLockdown = InCombatLockdown
local C_Timer = C_Timer
local LSM = LibStub("LibSharedMedia-3.0")

-- The border picked in the options, or the default when LibSharedMedia does not know it
local DEFAULT_BORDER = "FlareUI Frames"
local function GetBorderFile(db)
    local name = db and db.borderTexture
    if not (name and LSM:IsValid("border", name)) then name = DEFAULT_BORDER end
    return LSM:Fetch("border", name)
end

--------------------------------------------------
-- 3. CONSTANTS
--------------------------------------------------
local SEPARATOR = "Interface\\Common\\UI-TooltipDivider-Transparent"

local ICON_SEGMENTS = "Interface\\AddOns\\FlareUI\\Media\\Icons\\DMSegments.tga"
local ICON_SETTINGS = "Interface\\AddOns\\FlareUI\\Media\\Icons\\DMSettings.tga"
local ICON_READY     = "Interface\\AddOns\\FlareUI\\Media\\Icons\\DMReadyCheck.tga"
local ICON_COUNTDOWN = "Interface\\AddOns\\FlareUI\\Media\\Icons\\DMCountdown.tga"

-- Fixed look, matching the chat header
local HEADER_HEIGHT   = 24
local CONTENT_TOP     = 34
local ROW_CENTER_Y    = -15
local TITLE_LEFT      = 17   -- chat: 10 px tab-bar offset + 7 px button padding
local ICON_SIZE       = 13   -- nominal box, used for layout maths
-- draw sizes that make each glyph ~10-11 px tall, like the chat header icons (the art has padding)
local ICON_DRAW_SIZE  = { settings = 16, segments = 11, ready = 16, countdown = 12 }
-- the gear sits high in its texture
local ICON_DRAW_YOFS  = { settings = -2.5, segments = 0 }
local ICON_RIGHT      = 15
local ICON_SPACING    = 21
local TITLE_COLOR     = { r = 0.80, g = 0.60, b = 0.34, a = 1 }   -- #CC9957 (chat active tab)
local ICON_COLOR      = { r = 0.61, g = 0.48, b = 0.29, a = 1 }   -- #9C7A4A (chat header icons)
local BORDER_TINT     = ns.BORDER_COLOR
local SEPARATOR_COLOR = { r = 1, g = 1, b = 1, a = 1 }

local function LightenColor(r, g, b, factor)
    return math_min(1, r + factor), math_min(1, g + factor), math_min(1, b + factor)
end

--------------------------------------------------
-- 4. HELPERS
-- Never hook SetSessionDuration, the window's SetMinimized or the entries' Init / UpdateValue: they
-- run in secure code with secret values, and styling there taints it. Everything is applied from
-- Refresh(), out of combat and outside Edit Mode.
--------------------------------------------------
local function GetDb()
    if not ns.db or not ns.db.profile or not ns.db.profile.damagemeter then
        return nil
    end
    return ns.db.profile.damagemeter
end

local function SafeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then geterrorhandler()(err) end
    return ok
end

local function GetFontData(fontDB)
    if not fontDB then return "Fonts\\FRIZQT__.TTF", 12, "" end
    local face = fontDB.face or "Friz Quadrata TT"
    local size = fontDB.size or 12
    local flags = fontDB.flags or "OUTLINE"
    if flags == "NONE" then flags = "" end
    local path = LSM:Fetch("font", face) or "Fonts\\FRIZQT__.TTF"
    return path, size, flags
end

local function ApplyFontEffects(fontString, dbEntry)
    if not fontString or not dbEntry then return end
    ns.ApplyShadow(fontString, dbEntry)
    if dbEntry.useCustomColor and dbEntry.color then
        local c = dbEntry.color
        fontString:SetTextColor(c.r, c.g, c.b, c.a or 1)
    end
end

local function IsEditModeActive()
    return _G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown()
end

-- Settings > Damage Meter open: the meter shows whatever its visibility (Frame Opacity can be seen).
-- Blizzard re-checks its visibility on combat and group changes, so it is kept shown after each.
function DamageMeter:SetSettingsPreview(on)
    local meter = _G.DamageMeter
    on = on and true or false
    if not meter or self.settingsPreview == on then return end
    self.settingsPreview = on
    if not self.previewHooked and type(meter.UpdateShownState) == "function" then
        self.previewHooked = true
        hooksecurefunc(meter, "UpdateShownState", function(m)
            if DamageMeter.settingsPreview and not InCombatLockdown() then m:Show() end
        end)
    end
    if InCombatLockdown() then return end
    if on then
        meter:Show()
    elseif type(meter.UpdateShownState) == "function" then
        meter:UpdateShownState()
    end
end

-- A session window part through its getter, or its key
local function GetWindowPart(window, getterName, fallbackKey)
    if not window then return nil end
    local getter = window[getterName]
    if type(getter) == "function" then
        local ok, value = pcall(getter, window)
        if ok and value then
            return value
        end
    end
    return window[fallbackKey]
end

local function GetWindowHeader(window) return GetWindowPart(window, "GetHeader", "Header") end
local function GetWindowBackground(window) return GetWindowPart(window, "GetBackground", "Background") end
local function GetWindowScrollBox(window) return GetWindowPart(window, "GetScrollBox", "ScrollBox") end
local function GetWindowScrollBar(window) return GetWindowPart(window, "GetScrollBar", "ScrollBar") end
local function GetWindowSourceWindow(window) return GetWindowPart(window, "GetSourceWindow", "SourceWindow") end
local function GetWindowTypeDropdown(window) return GetWindowPart(window, "GetDamageMeterTypeDropdown", "DamageMeterTypeDropdown") end
local function GetWindowSessionDropdown(window) return GetWindowPart(window, "GetSessionDropdown", "SessionDropdown") end
local function GetWindowSettingsDropdown(window) return GetWindowPart(window, "GetSettingsDropdown", "SettingsDropdown") end
local function GetWindowSessionTimer(window) return GetWindowPart(window, "GetSessionTimerFontString", "SessionTimer") end
local function GetWindowMinimizeButton(window) return GetWindowPart(window, "GetMinimizeButton", "MinimizeButton") end

local function ApplyMinimizeCompatibility(window)
    local btn = GetWindowMinimizeButton(window)
    if btn and not btn:IsForbidden() then
        btn:Hide()
        btn:SetAlpha(0)
        btn:EnableMouse(false)
        if not btn.FlareUI_HideHooked then
            btn.FlareUI_HideHooked = true
            btn:HookScript("OnShow", function(self)
                self:Hide()
                self:SetAlpha(0)
                self:EnableMouse(false)
            end)
        end
    end
    -- never window:SetMinimized(): it taints isMinimized, which Blizzard reads with secret values
end

--------------------------------------------------
-- 5. GET SESSION WINDOWS
--------------------------------------------------
local function GetSessionWindows()
    local list = {}
    for i = 1, 10 do
        local w = _G["DamageMeterSessionWindow" .. i]
        if w then list[#list + 1] = w end
    end
    if #list == 0 then
        local dm = _G.DamageMeter
        if dm then
            for i = 1, dm:GetNumChildren() do
                local w = select(i, dm:GetChildren())
                if w and w.Header and w.DamageMeterTypeDropdown then
                    list[#list + 1] = w
                end
            end
        end
    end
    return list
end

--------------------------------------------------
-- 6. SKIN FRAME (backdrop and border, textPadding outside the window)
--------------------------------------------------
local function CreateOrGetSkinFrame(window)
    local skin = window.FlareUI_DMSkin
    if not skin then
        skin = CreateFrame("Frame", nil, window, "BackdropTemplate")
        window.FlareUI_DMSkin = skin
    end
    if not skin.Separator then
        skin.Separator = skin:CreateTexture(nil, "OVERLAY")
    end
    return skin
end

local function UpdateSkinFrame(window, db)
    if not window or window:IsForbidden() then return end
    local skin = CreateOrGetSkinFrame(window)
    local padding = db.textPadding or 0
    local header = GetWindowHeader(window)

    skin:ClearAllPoints()
    skin:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", -padding, -padding)
    skin:SetPoint("TOPRIGHT", window, "TOPRIGHT", padding, padding)
    ns.CopyStrata(skin, window)
    skin:SetFrameLevel(math_max((window:GetFrameLevel() or 1) - 1, 0))

    -- the chat frame's look: Blizzard's dark dialog background inside the chosen border
    local bgTexture     = LSM:Fetch("background", "Blizzard Dialog Background Dark") or "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"
    local borderTexture = GetBorderFile(db)
    skin:SetBackdrop({ bgFile = bgTexture, edgeFile = borderTexture, tile = false, tileSize = 0, edgeSize = ns.BorderEdgeSize(borderTexture, 16), insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    skin:SetBackdropColor(1, 1, 1, db.opacity or 0.85)
    skin:SetBackdropBorderColor(BORDER_TINT.r, BORDER_TINT.g, BORDER_TINT.b, BORDER_TINT.a)

    -- the skin replaces Blizzard's background and header bar
    local bg = GetWindowBackground(window)
    if bg and bg.SetAlpha then bg:SetAlpha(0) end
    if header and header.SetAlpha then header:SetAlpha(0) end
    if window.UpdateBackground and not window.FlareUI_BgHooked then
        window.FlareUI_BgHooked = true
        hooksecurefunc(window, "UpdateBackground", function(w)
            local d = GetDb()
            if not d or not d.enabled then return end
            local b = GetWindowBackground(w)
            if b and b.SetAlpha then b:SetAlpha(0) end
        end)
    end

    if header and not db.hideHeader then
        skin.Separator:Show()
        skin.Separator:SetColorTexture(0, 0, 0, 0)
        skin.Separator:SetTexture(SEPARATOR)
        skin.Separator:SetVertexColor(SEPARATOR_COLOR.r, SEPARATOR_COLOR.g, SEPARATOR_COLOR.b, SEPARATOR_COLOR.a)
        skin.Separator:SetHeight(8)
        skin.Separator:SetTexCoord(0, 1, 0, 1)
        skin.Separator:ClearAllPoints()
        skin.Separator:SetPoint("TOPLEFT", skin, "TOPLEFT", 3, -HEADER_HEIGHT)
        skin.Separator:SetPoint("TOPRIGHT", skin, "TOPRIGHT", -3, -HEADER_HEIGHT)
    else
        skin.Separator:Hide()
    end
end

--------------------------------------------------
-- 7. SOURCE WINDOW SKIN (the per-spell breakdown a bar click opens)
--------------------------------------------------
local function UpdateSourceWindowSkin(window, db)
    local sw = GetWindowSourceWindow(window)
    if not sw or sw:IsForbidden() then return end

    local skin = sw.FlareUI_DMSkin
    if not skin then
        skin = CreateFrame("Frame", nil, sw, "BackdropTemplate")
        sw.FlareUI_DMSkin = skin
    end

    local padding = db.textPadding or 0
    skin:ClearAllPoints()
    skin:SetPoint("BOTTOMLEFT", sw, "BOTTOMLEFT", -padding, -padding)
    skin:SetPoint("TOPRIGHT", sw, "TOPRIGHT", padding, padding)
    ns.CopyStrata(skin, sw)
    skin:SetFrameLevel(math_max((sw:GetFrameLevel() or 1) - 1, 0))

    local bgTexture     = LSM:Fetch("background", "Blizzard Dialog Background Dark") or "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"
    local borderTexture = GetBorderFile(db)
    skin:SetBackdrop({ bgFile = bgTexture, edgeFile = borderTexture, tile = false, tileSize = 0, edgeSize = ns.BorderEdgeSize(borderTexture, 16), insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    skin:SetBackdropColor(1, 1, 1, db.opacity or 0.85)
    skin:SetBackdropBorderColor(BORDER_TINT.r, BORDER_TINT.g, BORDER_TINT.b, BORDER_TINT.a)

    local bg = GetWindowBackground(sw)
    if bg and bg.SetAlpha then bg:SetAlpha(0) end
end

--------------------------------------------------
-- 7b. GROUP BUTTONS
-- Ready Check (group leader or assistant) and Countdown (in a group; right-click cancels), left of
-- the segments icon.
--------------------------------------------------
local GROUP_BUTTONS = {
    order = { "countdown", "ready" },   -- right to left, after the segments icon
    ready = { option = "readyCheckButton", icon = ICON_READY },
    countdown = { option = "countdownButton", icon = ICON_COUNTDOWN, seconds = 10 },
    buttons = {},   -- window -> { key = button }
}

function GROUP_BUTTONS.CanReadyCheck()
    if not IsInGroup() then return false end
    local leader, assist = UnitIsGroupLeader("player"), UnitIsGroupAssistant("player")
    if not canaccessvalue(leader) then leader = false end
    if not canaccessvalue(assist) then assist = false end
    return (leader or assist) and true or false
end

-- The keys switched on that apply right now, right to left
function GROUP_BUTTONS.Shown(db)
    local list = {}
    local applies = { countdown = IsInGroup(), ready = GROUP_BUTTONS.CanReadyCheck() }
    for _, key in ipairs(GROUP_BUTTONS.order) do
        if db and db[GROUP_BUTTONS[key].option] ~= false and applies[key] then list[#list + 1] = key end
    end
    return list
end

function GROUP_BUTTONS.Paint(btn, hover)
    ns.BronzeIcon.Paint(btn.FlareUI_Icon, ICON_COLOR, hover)
end

function GROUP_BUTTONS.Get(window, key)
    local set = GROUP_BUTTONS.buttons[window]
    if not set then set = {}; GROUP_BUTTONS.buttons[window] = set end
    if set[key] then return set[key] end
    local def = GROUP_BUTTONS[key]
    local btn = CreateFrame("Button", nil, window)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local icon = btn:CreateTexture(nil, "OVERLAY", nil, 7)
    icon:SetSize(ICON_DRAW_SIZE[key], ICON_DRAW_SIZE[key])
    icon:SetPoint("CENTER")
    ns.BronzeIcon.Apply(icon, def.icon, ICON_COLOR)
    btn.FlareUI_Icon = icon
    btn:SetScript("OnEnter", function(self) GROUP_BUTTONS.Paint(self, true) end)
    btn:SetScript("OnLeave", function(self) GROUP_BUTTONS.Paint(self, false) end)
    btn:SetScript("OnMouseDown", function(self) self.FlareUI_Icon:SetPoint("CENTER", 1, -1) end)
    btn:SetScript("OnMouseUp", function(self) self.FlareUI_Icon:SetPoint("CENTER", 0, 0) end)
    btn:SetScript("OnClick", function(_, button)
        if key == "ready" then
            C_PartyInfo.DoReadyCheck()
        elseif button == "RightButton" then
            C_PartyInfo.DoCountdown(0)
        else
            C_PartyInfo.DoCountdown(def.seconds)
        end
    end)
    GROUP_BUTTONS.Paint(btn, false)
    set[key] = btn
    return btn
end

-- The header is laid out again after a group change (once per burst; registered in Init)
GROUP_BUTTONS.events = CreateFrame("Frame")
GROUP_BUTTONS.events:SetScript("OnEvent", function()
    if GROUP_BUTTONS.pending then return end
    GROUP_BUTTONS.pending = true
    C_Timer.After(0.2, function()
        GROUP_BUTTONS.pending = nil
        local db = GetDb()
        if db and db.enabled and DamageMeter.Refresh then DamageMeter:Refresh() end
    end)
end)

-- Lays out the buttons that show, left of the segments icon; returns how many show
function GROUP_BUTTONS.Layout(window, db, ref, box, levelOf)
    local shown = (db and not db.hideHeader) and GROUP_BUTTONS.Shown(db) or {}
    local isShown = {}
    for slot, key in ipairs(shown) do
        isShown[key] = true
        local btn = GROUP_BUTTONS.Get(window, key)
        btn:SetSize(box, box)
        btn:ClearAllPoints()
        -- slots 0 and 1 are the settings and segments icons
        btn:SetPoint("CENTER", ref, "TOPRIGHT", -(ICON_RIGHT + ICON_SIZE / 2 + (slot + 1) * ICON_SPACING), ROW_CENTER_Y)
        if levelOf then
            ns.CopyStrata(btn, levelOf)
            btn:SetFrameLevel(levelOf:GetFrameLevel())
        end
        btn:Show()
    end
    for key, btn in pairs(GROUP_BUTTONS.buttons[window] or {}) do
        if not isShown[key] then btn:Hide() end
    end
    return #shown
end

--------------------------------------------------
-- 8. HEADER
--------------------------------------------------
local AttachHeaderButtonHooks   -- defined in section 9

local function ApplyHeader(window, db)
    if not window or window:IsForbidden() then return end
    local header = GetWindowHeader(window)
    if not header then return end

    local hideHeader = db.hideHeader

    if hideHeader then
        header:Hide()
        header:SetAlpha(0)
        header:SetHeight(1)
        -- the header's parts stay hidden when Blizzard shows them
        local function ForceHide(frame)
            if frame and not frame:IsForbidden() and GetDb() and GetDb().hideHeader then
                frame:Hide()
            end
        end
        for _, btn in pairs(GROUP_BUTTONS.buttons[window] or {}) do btn:Hide() end
        for _, f in ipairs({ GetWindowSessionTimer(window), GetWindowTypeDropdown(window), GetWindowSessionDropdown(window), GetWindowSettingsDropdown(window) }) do
            if f then
                f:Hide()
                if not f.FlareUI_HideHeaderHooked then
                    f.FlareUI_HideHeaderHooked = true
                    f:HookScript("OnShow", ForceHide)
                end
            end
        end
    else
        header:Show()
        header:SetAlpha(0)   -- the skin is the header background; the frame stays for anchoring
        header:SetHeight(HEADER_HEIGHT)
        -- Blizzard's "[mm:ss]" session timer, with Combat Timer on
        local sessionTimer = GetWindowSessionTimer(window)
        if sessionTimer then
            if not sessionTimer.FlareUI_HideTimerHooked then
                sessionTimer.FlareUI_HideTimerHooked = true
                sessionTimer:HookScript("OnShow", function(self)
                    local d = GetDb()
                    if not (d and d.combatTimer) then self:Hide() end
                end)
            end
            sessionTimer:SetShown(db.combatTimer and true or false)
        end
        local typeDropdown = GetWindowTypeDropdown(window)
        local sessionDropdown = GetWindowSessionDropdown(window)
        local settingsDropdown = GetWindowSettingsDropdown(window)
        if typeDropdown then typeDropdown:Show() end
        if sessionDropdown then sessionDropdown:Show() end
        if settingsDropdown then settingsDropdown:Show() end

        -- laid out like the chat header
        if not InCombatLockdown() then
            SafeCall(function()
                local dd = GetWindowTypeDropdown(window)
                local sd = GetWindowSettingsDropdown(window)
                local sdd = GetWindowSessionDropdown(window)
                local box = ICON_SIZE + 9   -- click area a little larger than the icon
                local ref = window.FlareUI_DMSkin or header   -- lay out against the skin, like the chat header
                if sd and sd.ClearAllPoints then
                    sd:SetSize(box, box)
                    sd:ClearAllPoints()
                    sd:SetPoint("CENTER", ref, "TOPRIGHT", -(ICON_RIGHT + ICON_SIZE / 2), ROW_CENTER_Y)
                end
                if sdd and sdd.ClearAllPoints then
                    sdd:SetSize(box, box)
                    sdd:ClearAllPoints()
                    sdd:SetPoint("CENTER", ref, "TOPRIGHT", -(ICON_RIGHT + ICON_SIZE / 2 + ICON_SPACING), ROW_CENTER_Y)
                end
                -- Ready Check / Countdown left of the segments icon; the title and timer make room
                local extra = GROUP_BUTTONS.Layout(window, db, ref, box, sdd or sd)
                local iconsWidth = ICON_SIZE + (1 + extra) * ICON_SPACING
                if dd and dd.ClearAllPoints then
                    dd:ClearAllPoints()
                    dd:SetPoint("TOPLEFT", ref, "TOPLEFT", 0, 0)
                    dd:SetPoint("BOTTOMRIGHT", ref, "TOPRIGHT", -(ICON_RIGHT + iconsWidth + 8), -HEADER_HEIGHT)
                end
                -- the timer sits at the right end of the title row, just left of the icons
                local timer = GetWindowSessionTimer(window)
                if timer and timer.ClearAllPoints then
                    timer:ClearAllPoints()
                    timer:SetPoint("RIGHT", ref, "TOPRIGHT", -(ICON_RIGHT + iconsWidth + 10), ROW_CENTER_Y)
                    timer:SetJustifyH("RIGHT")
                end
                if dd and dd.TypeName and dd.TypeName.ClearAllPoints then
                    dd.TypeName:ClearAllPoints()
                    dd.TypeName:SetPoint("LEFT", ref, "TOPLEFT", TITLE_LEFT, ROW_CENTER_Y)
                    dd.TypeName:SetPoint("RIGHT", dd, "RIGHT", -4, 0)
                    dd.TypeName:SetJustifyH("LEFT")
                end
            end)
        end
    end

    -- the list fills the skin below the header
    local function ApplyScrollBoxAnchors()
        local sb = GetWindowScrollBox(window)
        if sb and not InCombatLockdown() and GetDb() then
            local skinRef = window.FlareUI_DMSkin or window
            sb:ClearAllPoints()
            sb:SetPoint("TOPLEFT", skinRef, "TOPLEFT", 6, -CONTENT_TOP)
            sb:SetPoint("BOTTOMRIGHT", skinRef, "BOTTOMRIGHT", -6, 6)
        end
    end
    if not InCombatLockdown() then
        SafeCall(ApplyScrollBoxAnchors)
    end
    -- Blizzard re-anchors the list when its scroll bar shows or hides
    local scrollBar = GetWindowScrollBar(window)
    if scrollBar and not scrollBar.FlareUI_ScrollBoxAnchorHooked then
        scrollBar.FlareUI_ScrollBoxAnchorHooked = true
        scrollBar:HookScript("OnShow", ApplyScrollBoxAnchors)
        scrollBar:HookScript("OnHide", ApplyScrollBoxAnchors)
    end

    if not hideHeader then
        AttachHeaderButtonHooks(window)
    end
end

--------------------------------------------------
-- 9. HEADER BUTTON STYLE
--------------------------------------------------
local function HideBlizzardButtonVisuals(btn, hideSessionName)
    if not btn then return end
    if btn.Arrow then btn.Arrow:SetAlpha(0) end
    if btn.Icon and btn.Icon.SetAlpha then btn.Icon:SetAlpha(0) end
    if btn.Background and btn.Background.SetAlpha then btn.Background:SetAlpha(0) end
    if hideSessionName and btn.SessionName and btn.SessionName.SetAlpha then
        btn.SessionName:SetAlpha(0)
    end
    local nr = btn.GetNumRegions and btn:GetNumRegions() or 0
    for i = 1, nr do
        local r = select(i, btn:GetRegions())
        if r and r.IsObjectType and r:IsObjectType("Texture") and r.SetAlpha then
            r:SetAlpha(0)
        end
    end
end

local function SetupCustomIcon(btn, iconPath, hideSessionName, drawSize, yOfs)
    if not btn then return end
    btn:Show()
    HideBlizzardButtonVisuals(btn, hideSessionName)

    if not btn.FlareUI_Icon then
        btn.FlareUI_Icon = btn:CreateTexture(nil, "OVERLAY")
        btn.FlareUI_Icon:SetDrawLayer("OVERLAY", 7)
    end
    btn.FlareUI_Icon:ClearAllPoints()
    btn.FlareUI_Icon:SetPoint("CENTER", btn, "CENTER", 0, yOfs or 0)
    btn.FlareUI_Icon:SetSize(drawSize or ICON_SIZE, drawSize or ICON_SIZE)
    ns.BronzeIcon.Apply(btn.FlareUI_Icon, iconPath, ICON_COLOR)
    btn.FlareUI_Icon:Show()

    if not btn.FlareUI_IconHoverHooked then
        btn.FlareUI_IconHoverHooked = true
        btn:HookScript("OnEnter", function(self)
            local db = GetDb()
            if not db or db.hideHeader then return end
            if self.FlareUI_Icon then ns.BronzeIcon.Paint(self.FlareUI_Icon, ICON_COLOR, true) end
        end)
        btn:HookScript("OnLeave", function(self)
            local db = GetDb()
            if not db or db.hideHeader then return end
            if self.FlareUI_Icon then ns.BronzeIcon.Paint(self.FlareUI_Icon, ICON_COLOR, false) end
        end)
    end
end

local function ApplyHeaderButtonStyle(window, db)
    if not window or window:IsForbidden() then return end
    if not db or db.hideHeader then return end

    -- the type dropdown is the title itself, like a chat tab
    local dd = GetWindowTypeDropdown(window)
    if dd then HideBlizzardButtonVisuals(dd, false) end

    local sdd = GetWindowSessionDropdown(window)
    if sdd then SetupCustomIcon(sdd, ICON_SEGMENTS, true, ICON_DRAW_SIZE.segments, ICON_DRAW_YOFS.segments) end

    local sd = GetWindowSettingsDropdown(window)
    if sd then SetupCustomIcon(sd, ICON_SETTINGS, false, ICON_DRAW_SIZE.settings, ICON_DRAW_YOFS.settings) end
end

function AttachHeaderButtonHooks(window)
    if not window or window.FlareUI_HeaderBtnHooked then return end
    window.FlareUI_HeaderBtnHooked = true

    local function Reapply()
        local db = GetDb()
        if db and db.enabled and not db.hideHeader then
            SafeCall(ApplyHeaderButtonStyle, window, db)
        end
    end

    window:HookScript("OnShow", function()
        C_Timer.After(0, Reapply)
    end)

    for _, btn in ipairs({ GetWindowTypeDropdown(window), GetWindowSessionDropdown(window), GetWindowSettingsDropdown(window) }) do
        if btn and not btn.FlareUI_BtnStyleHooked then
            btn.FlareUI_BtnStyleHooked = true
            btn:HookScript("OnShow", Reapply)
        end
    end
end

--------------------------------------------------
-- 10. SCROLL BAR
--------------------------------------------------
local function ApplyScrollBarVisibility(window, db)
    if not window or window:IsForbidden() then return end
    local sb = GetWindowScrollBar(window)
    if not sb then return end

    sb:Hide()
    sb:SetAlpha(0)
    sb:EnableMouse(false)
    if not sb.FlareUI_HideScrollBarHooked then
        sb.FlareUI_HideScrollBarHooked = true
        sb:HookScript("OnShow", function(self) self:Hide() end)
    end
    local scrollBox = GetWindowScrollBox(window)
    if scrollBox and scrollBox.EnableMouseWheel then
        scrollBox:EnableMouseWheel(true)
    end

    local sw = GetWindowSourceWindow(window)
    if sw and sw.ScrollBar then
        local srcSb = sw.ScrollBar
        srcSb:Hide()
        srcSb:SetAlpha(0)
        srcSb:EnableMouse(false)
        if not srcSb.FlareUI_HideScrollBarHooked then
            srcSb.FlareUI_HideScrollBarHooked = true
            srcSb:HookScript("OnShow", function(self) self:Hide() end)
        end
        if sw.ScrollBox and sw.ScrollBox.EnableMouseWheel then
            sw.ScrollBox:EnableMouseWheel(true)
        end
    end
end

--------------------------------------------------
-- 11. HEADER FONTS
--------------------------------------------------
local HEADER_FONT = { face = "Friz Quadrata TT", size = 12, flags = "NONE", enableShadow = true, shadowX = 1, shadowY = -1, useCustomColor = true, color = TITLE_COLOR }

local function ApplyHeaderFonts(window, db)
    if not window or window:IsForbidden() then return end
    local fontDb = HEADER_FONT

    local path, size, flags = GetFontData(fontDb)

    local function ApplyToFontString(fs)
        if not fs or not fs.SetFont then return end
        fs:SetFont(path, size, flags)
        ApplyFontEffects(fs, fontDb)
    end

    local dd = GetWindowTypeDropdown(window)
    if dd and dd.TypeName then
        ApplyToFontString(dd.TypeName)
    end

    local sd = GetWindowSessionDropdown(window)
    if sd and sd.SessionName then
        ApplyToFontString(sd.SessionName)
    end

    local sessionTimer = GetWindowSessionTimer(window)
    if sessionTimer then
        ApplyToFontString(sessionTimer)
    end

    if dd and dd.GetRegions then
        for _, region in pairs({ dd:GetRegions() }) do
            if region and region.IsObjectType and region:IsObjectType("FontString") then
                ApplyToFontString(region)
            end
        end
    end
end

--------------------------------------------------
-- 12. BAR FONTS
--------------------------------------------------
local function ApplyBarFont(entry, db)
    if not entry or entry:IsForbidden() then return end
    local fontDb = db.barFont
    if not fontDb then return end

    local path, size, flags = GetFontData(fontDb)
    local statusBar = entry.GetStatusBar and entry:GetStatusBar() or entry.StatusBar
    local nameFs = statusBar and statusBar.Name or entry.Name
    local valueFs = statusBar and statusBar.Value or entry.Value

    local function ApplyToFS(fs)
        if fs and fs.SetFont then
            fs:SetFont(path, size, flags)
            ApplyFontEffects(fs, fontDb)
        end
    end

    ApplyToFS(nameFs)
    ApplyToFS(valueFs)

    if entry.GetRegions then
        for _, region in pairs({ entry:GetRegions() }) do
            if region and region.IsObjectType and region:IsObjectType("FontString") then
                ApplyToFS(region)
            end
        end
    end
end

-- the bar fill stays Blizzard's; only the font is FlareUI's
local StyleEntry = ApplyBarFont

--------------------------------------------------
-- 13. SCROLL BOX FONT REFRESH (Refresh only: see HELPERS)
--------------------------------------------------
local function ApplyFontsToScrollBox(scrollBox, db)
    if not scrollBox or not db then return end
    if scrollBox.ForEachFrame then
        scrollBox:ForEachFrame(function(frame)
            StyleEntry(frame, db)
        end)
    elseif scrollBox.EnumerateFrames then
        for frame in scrollBox:EnumerateFrames() do
            StyleEntry(frame, db)
        end
    end
end

--------------------------------------------------
-- 14. UNCLAMP
--------------------------------------------------
-- The window can be dragged past the screen edge, like the chat. Something re-clamps it in Edit
-- Mode, so later clamps are undone, and the Edit Mode selection is unclamped too.
local function Unclamp(frame)
    if not frame or frame:IsForbidden() then return end
    frame:SetClampedToScreen(false)
    frame:SetClampRectInsets(-50, -50, -50, -50)
    if not frame.FlareUI_ClampHooked then
        frame.FlareUI_ClampHooked = true
        hooksecurefunc(frame, "SetClampedToScreen", function(f, clamped)
            if clamped and not f.FlareUI_Unclamping then
                f.FlareUI_Unclamping = true
                f:SetClampedToScreen(false)
                f.FlareUI_Unclamping = nil
            end
        end)
    end
end

local function ApplyUnclamp(window)
    Unclamp(window)
    Unclamp(window.Selection)
end

--------------------------------------------------
-- 14b. THREAT TAB
-- A second view beside Blizzard's meter type in the title row. Left-click picks a tab; a hit area
-- over Blizzard's title passes right-clicks through, so Blizzard's own code opens its type menu.
-- The list is FlareUI's (Blizzard's is secure code): the group sorted by threat on your target, in
-- rows from Blizzard's entry template. You always keep a row. Where threat is secret, the view
-- says so.
--------------------------------------------------
local TAB_GAP       = 14
local TAB_INACTIVE  = { r = 0.56, g = 0.51, b = 0.46, a = 1 }   -- #8F8275, the chat's unselected tab
local THREAT_TICK   = 0.2    -- seconds between redraws while threat events keep coming
local THREAT_EVENTS = { "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE", "PLAYER_TARGET_CHANGED",
    "UNIT_TARGET", "GROUP_ROSTER_UPDATE", "UNIT_PET", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }

local views = {}                 -- session window -> its threat tab, hit area, list and state
local UpdateThreatViews          -- defined below the list code

local function Readable(value)
    return value ~= nil and canaccessvalue(value)
end

-- The mob whose threat is shown: a hostile target, or the hostile target of a friendly one
local function IsHostile(unit)
    if not UnitExists(unit) or UnitIsDeadOrGhost(unit) then return false end
    local attackable = UnitCanAttack("player", unit)
    return Readable(attackable) and attackable
end

local function ThreatMob()
    if IsHostile("target") then return "target" end
    if UnitExists("target") and IsHostile("targettarget") then return "targettarget" end
end

-- A player's spec icon (own spec, or an inspected one); nil falls back to the class icon
local function SpecIconOf(unit, isMe)
    local specID
    if isMe then
        local index = GetSpecialization and GetSpecialization()
        specID = index and GetSpecializationInfo(index)
    else
        specID = GetInspectSpecialization and GetInspectSpecialization(unit)
    end
    if specID and specID ~= 0 then return select(4, GetSpecializationInfoByID(specID)) end
end

local function SpecIcon(unit, isMe)
    local ok, icon = pcall(SpecIconOf, unit, isMe)
    return ok and icon or nil
end

-- Every group member and pet with threat on the mob, highest first. secret = the client hid it.
local function CollectThreat(mob)
    local list, secret = {}, false
    local function Add(unit)
        if not UnitExists(unit) then return end
        local isTanking, _, scaled, _, value = UnitDetailedThreatSituation(unit, mob)
        if value == nil then return end
        if not (Readable(value) and Readable(scaled)) then secret = true; return end
        local name = UnitName(unit)
        local _, class = UnitClass(unit)
        local isMe = UnitIsUnit(unit, "player")
        list[#list + 1] = {
            unit = unit, value = value, scaled = scaled or 0,
            tanking = Readable(isTanking) and isTanking,
            name = Readable(name) and name or "?",
            class = Readable(class) and class or nil,
            isPlayer = Readable(isMe) and isMe or false,
        }
        list[#list].specIcon = UnitIsPlayer(unit) and SpecIcon(unit, list[#list].isPlayer) or nil
    end
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do Add("raid" .. i); Add("raidpet" .. i) end
    else
        Add("player"); Add("pet")
        for i = 1, GetNumSubgroupMembers() do Add("party" .. i); Add("partypet" .. i) end
    end
    table.sort(list, function(a, b) return a.value > b.value end)
    for i, data in ipairs(list) do data.rank = i end
    return list, secret
end

local function ColorTab(fontString, active)
    local c = active and TITLE_COLOR or TAB_INACTIVE
    fontString:SetTextColor(c.r, c.g, c.b, c.a or 1)
end

local function LayoutTabs(window, view)
    local dd = GetWindowTypeDropdown(window)
    local ref = window.FlareUI_DMSkin or GetWindowHeader(window)
    if not (dd and dd.TypeName and ref) then return end
    local path, size, flags = dd.TypeName:GetFont()
    if path then view.tab.Text:SetFont(path, size, flags) end
    view.tab.Text:SetShadowOffset(dd.TypeName:GetShadowOffset())
    view.tab.Text:SetShadowColor(dd.TypeName:GetShadowColor())
    view.tab:ClearAllPoints()
    view.tab:SetPoint("LEFT", ref, "TOPLEFT", TITLE_LEFT + dd.TypeName:GetUnboundedStringWidth() + TAB_GAP - 4, ROW_CENTER_Y)
    view.tab:SetSize(view.tab.Text:GetUnboundedStringWidth() + 8, HEADER_HEIGHT)
    ColorTab(dd.TypeName, not view.showing)
    ColorTab(view.tab.Text, view.showing)
end

-- Blizzard's list (and its pinned own row) is invisible while Threat is up
local function SetBlizzardListShown(window, shown)
    local alpha = shown and 1 or 0
    local scrollBox = GetWindowScrollBox(window)
    if scrollBox then scrollBox:SetAlpha(alpha) end
    local own = window.GetLocalPlayerEntry and window:GetLocalPlayerEntry()
    if own then own:SetAlpha(alpha) end
end

local function GetRow(view, index)
    local row = view.rows[index]
    if not row then
        row = CreateFrame("Button", nil, view.frame, "DamageMeterEntryTemplate")
        row:EnableMouse(false)
        view.rows[index] = row
    end
    return row
end

local function FillRow(row, data, top, window, db, index, height, spacing)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", row:GetParent(), "TOPLEFT", 0, -(index - 1) * (height + spacing))
    row:SetPoint("TOPRIGHT", row:GetParent(), "TOPRIGHT", 0, -(index - 1) * (height + spacing))
    row:SetBarHeight(height)
    row:SetTextScale(window.GetTextScale and window:GetTextScale() or 1)
    row:SetShowBarIcons(window.ShouldShowBarIcons and window:ShouldShowBarIcons() or false)
    row:SetStyle(window.GetStyle and window:GetStyle() or Enum.DamageMeterStyle.Default)
    StyleEntry(row, db)

    local bar = row:GetStatusBar()
    bar:SetMinMaxValues(0, top > 0 and top or 1)
    bar:SetValue(data.value)
    -- Blizzard's colour rule: the class colour when the window asks for it, else the ally colour
    row.classFilename = data.class
    row.sourceDisplayType = Enum.DamageMeterSourceDisplayType and Enum.DamageMeterSourceDisplayType.Ally
    row:SetUseClassColor(window.ShouldUseClassColor and window:ShouldUseClassColor() or false)
    local icon = row:GetIcon()
    -- rows are reused, so each kind of icon sets its own coordinates
    if data.specIcon then
        icon:SetTexture(data.specIcon)
        icon:SetTexCoord(0.0625, 0.9, 0.0626, 0.9)
    elseif data.class then
        icon:SetAtlas(GetClassAtlas(data.class), false, nil, true)
    else
        icon:SetTexture(nil)
    end
    row:GetName():SetText(("%d. %s"):format(data.rank, data.name))
    row:GetValue():SetText(("%s  %d%%"):format(AbbreviateNumbers(data.value / 100), math.floor(data.scaled + 0.5)))
    row:Show()
end

local function UpdateThreatView(window, view)
    local db = GetDb()
    if not db then return end
    local frame = view.frame
    local height = window.GetBarHeight and window:GetBarHeight() or 24
    local spacing = window.GetBarSpacing and window:GetBarSpacing() or 2
    local capacity = math_max(1, math.floor((frame:GetHeight() + spacing) / (height + spacing)))

    local list, message = {}, nil
    local mob = ThreatMob()
    if not mob then
        message = L["No hostile target"]
    else
        local secret
        list, secret = CollectThreat(mob)
        if secret then
            message, list = L["Threat is hidden here"], {}
        elseif #list == 0 then
            message = L["No threat yet"]
        end
    end

        -- past the last row, the last row is yours
    local shown = {}
    for i = 1, math_min(#list, capacity) do shown[i] = list[i] end
    if #list > capacity then
        local inView = false
        for i = 1, capacity do if shown[i].isPlayer then inView = true end end
        if not inView then
            for i = capacity + 1, #list do
                if list[i].isPlayer then shown[capacity] = list[i] end
            end
        end
    end

    local top = list[1] and list[1].value or 0
    for i, data in ipairs(shown) do FillRow(GetRow(view, i), data, top, window, db, i, height, spacing) end
    for i = #shown + 1, #view.rows do view.rows[i]:Hide() end
    frame.Empty:SetText(message or "")
    frame.Empty:SetShown(message ~= nil)
end

-- Threat events arrive in bursts: the list is redrawn at most every THREAT_TICK
local threatDriver = CreateFrame("Frame")
local threatDirty, threatElapsed, threatWatching = false, 0, false
threatDriver:Hide()   -- runs only while a Threat tab is up; see WatchThreat
threatDriver:SetScript("OnEvent", function() threatDirty = true end)
threatDriver:SetScript("OnUpdate", function(_, elapsed)
    threatElapsed = threatElapsed + elapsed
    if threatElapsed < THREAT_TICK then return end
    threatElapsed = 0
    if threatDirty then
        threatDirty = false
        UpdateThreatViews()
    end
end)

local function WatchThreat()
    local any = false
    for _, view in pairs(views) do if view.showing then any = true end end
    if any == threatWatching then return end
    threatWatching = any
    for _, event in ipairs(THREAT_EVENTS) do
        if any then threatDriver:RegisterEvent(event) else threatDriver:UnregisterEvent(event) end
    end
    threatDriver:SetShown(any)
end

function UpdateThreatViews()
    for window, view in pairs(views) do
        if view.showing then SafeCall(UpdateThreatView, window, view) end
    end
end

local function SetView(window, showThreat)
    local view = views[window]
    if not view then return end
    view.showing = showThreat and true or false
    view.frame:SetShown(view.showing)
    SetBlizzardListShown(window, not view.showing)
    LayoutTabs(window, view)
    if view.showing then UpdateThreatView(window, view) end
    WatchThreat()
end

-- The Threat Toggle Keybind flips every window (an override binding clicks a plain button)
local function ToggleThreatViews()
    for window, view in pairs(views) do SetView(window, not view.showing) end
end

-- The radial menu's "Toggle Threat Meter" and the key binding (Bindings.xml) run this
BINDING_NAME_FLAREUI_THREAT = L["Toggle Threat Meter"]
function FlareUI_ToggleThreatMeter()
    if next(views) then
        ToggleThreatViews()
    else
        print("|cff00ff00FlareUI:|r " .. L["turn on Threat Meter Tab in the Damage Meter settings to use the threat view."])
    end
end

local threatToggle
local function ApplyThreatKey()
    if InCombatLockdown() then return end   -- Refresh comes back after the fight
    if not threatToggle then
        threatToggle = CreateFrame("Button", "FlareUI_DamageMeterThreatToggle", UIParent)
        threatToggle:SetSize(1, 1)
        threatToggle:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -500, 500)
        threatToggle:RegisterForClicks("AnyDown")
        threatToggle:SetScript("OnClick", ToggleThreatViews)
    end
    ClearOverrideBindings(threatToggle)
    local db = GetDb()
    local key = db and db.enabled and db.threatTab and db.threatKey
    if key and key ~= "" then SetOverrideBindingClick(threatToggle, true, key, threatToggle:GetName()) end
end

local function CreateThreatView(window)
    local dd = GetWindowTypeDropdown(window)
    local scrollBox = GetWindowScrollBox(window)
    if not (dd and dd.TypeName and scrollBox) then return nil end
    local view = { rows = {}, showing = false }

    -- over Blizzard's title: left-click picks its tab, right-click reaches Blizzard's menu
    local hit = CreateFrame("Button", nil, window)
    hit:SetAllPoints(dd)
    hit:SetFrameLevel(dd:GetFrameLevel() + 2)
    hit:RegisterForClicks("LeftButtonUp")
    hit:SetPassThroughButtons("RightButton")
    hit:SetScript("OnClick", function() SetView(window, false) end)
    view.hit = hit

    local tab = CreateFrame("Button", nil, window)
    tab:SetFrameLevel(dd:GetFrameLevel() + 3)
    tab.Text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tab.Text:SetPoint("LEFT", tab, "LEFT", 4, 0)
    tab.Text:SetText(L["Threat"])
    tab:RegisterForClicks("LeftButtonUp")
    tab:SetScript("OnClick", function() SetView(window, true) end)
    -- the idle tab lifts a little under the mouse, like the chat's
    tab:SetScript("OnEnter", function(self)
        if view.showing then return end
        local r, g, b = LightenColor(TAB_INACTIVE.r, TAB_INACTIVE.g, TAB_INACTIVE.b, 0.2)
        self.Text:SetTextColor(r, g, b)
    end)
    tab:SetScript("OnLeave", function(self) ColorTab(self.Text, view.showing) end)
    view.tab = tab

    local frame = CreateFrame("Frame", nil, window)
    frame:SetFrameLevel(scrollBox:GetFrameLevel() + 20)
    frame:EnableMouse(true)                          -- Blizzard's invisible rows stay unclickable
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function() end)
    frame.Empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.Empty:SetPoint("CENTER")
    frame:Hide()
    view.frame = frame

    -- a new meter type renames the title: the Threat tab follows the new width
    hooksecurefunc(dd.TypeName, "SetText", function()
        if view.tab:IsShown() then LayoutTabs(window, view) end
    end)

    views[window] = view
    return view
end

--------------------------------------------------
-- 14c. LIVE COMBAT TIMER
-- Blizzard's session timer only moves every two seconds or so, so in combat FlareUI counts the
-- fight in its place. Out of combat Blizzard's timer shows a past segment's (secret) length.
--------------------------------------------------
local liveTimers = {}            -- session window -> FlareUI's timer text
local combatStart
local timerDriver = CreateFrame("Frame")
timerDriver:Hide()
local timerElapsed = 0
timerDriver:SetScript("OnUpdate", function(_, elapsed)
    timerElapsed = timerElapsed + elapsed
    if timerElapsed < 0.1 then return end
    timerElapsed = 0
    local text = ("[%s] "):format(SecondsToClock(GetTime() - (combatStart or GetTime())))
    for _, fs in pairs(liveTimers) do fs:SetText(text) end
end)

local function UpdateLiveTimers()
    local db = GetDb()
    local live = db and db.enabled and db.combatTimer and not db.hideHeader and combatStart ~= nil
    for window, fs in pairs(liveTimers) do
        local blizzard = GetWindowSessionTimer(window)
        fs:SetShown(live)
        if blizzard then blizzard:SetAlpha(live and 0 or 1) end
    end
    timerElapsed = 1
    timerDriver:SetShown(live)
end

-- registered in Init
local timerEvents = CreateFrame("Frame")
timerEvents:SetScript("OnEvent", function(_, event)
    combatStart = event == "PLAYER_REGEN_DISABLED" and GetTime() or nil
    UpdateLiveTimers()
    -- Threat View in Combat. Back to the damage view after a fight: if the meter is fading out by
    -- then, only once it has faded (the emptied threat view fades, not a flash of damage bars)
    local db = GetDb()
    if not (db and db.enabled and db.threatTab and db.autoThreat) then return end
    DamageMeter.viewBackPending = nil
    if combatStart then
        for window in pairs(views) do SetView(window, true) end
        return
    end
    -- the meter's own check for the fight's end runs on this event too: decided a frame later
    C_Timer.After(0, function()
        if combatStart then return end
        if DamageMeter.FadingOut and DamageMeter.FadingOut() then
            DamageMeter.viewBackPending = true
        else
            DamageMeter.ShowDamageViews()
        end
    end)
end)

function DamageMeter.ShowDamageViews()
    DamageMeter.viewBackPending = nil
    for window in pairs(views) do SetView(window, false) end
end

local function ApplyLiveTimer(window, db)
    local blizzard = GetWindowSessionTimer(window)
    if not blizzard then return end
    local fs = liveTimers[window]
    if not fs then
        fs = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetJustifyH("RIGHT")
        liveTimers[window] = fs
    end
    local path, size, flags = blizzard:GetFont()
    if path then fs:SetFont(path, size, flags) end
    fs:SetShadowOffset(blizzard:GetShadowOffset())
    fs:SetShadowColor(blizzard:GetShadowColor())
    fs:SetTextColor(TITLE_COLOR.r, TITLE_COLOR.g, TITLE_COLOR.b, TITLE_COLOR.a or 1)
    fs:ClearAllPoints()
    fs:SetPoint("RIGHT", blizzard, "RIGHT", 0, 0)
    if UnitAffectingCombat("player") and not combatStart then combatStart = GetTime() end
    UpdateLiveTimers()
end

local function ApplyThreatTab(window, db)
    local dd = GetWindowTypeDropdown(window)
    if not dd then return end
    local view = views[window]
    if db.threatTab and not db.hideHeader then
        view = view or CreateThreatView(window)
        if not view then return end
        dd:RegisterForMouse("LeftButtonDown", "LeftButtonUp", "RightButtonDown", "RightButtonUp")
        local skin = window.FlareUI_DMSkin or window
        view.frame:ClearAllPoints()
        view.frame:SetPoint("TOPLEFT", skin, "TOPLEFT", 6, -CONTENT_TOP)
        view.frame:SetPoint("BOTTOMRIGHT", skin, "BOTTOMRIGHT", -6, 6)
        view.hit:Show()
        view.tab:Show()
        SetView(window, view.showing)
    elseif view then
        SetView(window, false)
        view.hit:Hide()
        view.tab:Hide()
        dd:RegisterForMouse("LeftButtonDown", "LeftButtonUp")
        if dd.TypeName then ColorTab(dd.TypeName, true) end
    end
end

--------------------------------------------------
-- 15. APPLY TO SINGLE WINDOW
--------------------------------------------------
function DamageMeter:ApplyToWindow(window)
    local db = GetDb()
    if not db or not db.enabled then return end

    -- never while Edit Mode's preview data is up
    if IsEditModeActive() then return end
    SafeCall(ApplyUnclamp, window)
    SafeCall(ApplyMinimizeCompatibility, window)
    SafeCall(UpdateSkinFrame, window, db)
    SafeCall(UpdateSourceWindowSkin, window, db)
    SafeCall(ApplyHeader, window, db)
    SafeCall(ApplyScrollBarVisibility, window, db)
    SafeCall(ApplyHeaderFonts, window, db)
    if not (db.hideHeader) then
        SafeCall(ApplyHeaderButtonStyle, window, db)
    end
    SafeCall(ApplyThreatTab, window, db)
    SafeCall(ApplyLiveTimer, window, db)

    local sb = GetWindowScrollBox(window)
    if sb then
        SafeCall(ApplyFontsToScrollBox, sb, db)
    end
    local localPlayerEntry = (window.GetLocalPlayerEntry and window:GetLocalPlayerEntry()) or window.LocalPlayerEntry
    if localPlayerEntry then
        SafeCall(StyleEntry, localPlayerEntry, db)
    end

    local sw = GetWindowSourceWindow(window)
    local swScrollBox = sw and ((sw.GetScrollBox and sw:GetScrollBox()) or sw.ScrollBox)
    if swScrollBox then
        SafeCall(ApplyFontsToScrollBox, swScrollBox, db)
    end
end

--------------------------------------------------
-- 15b. MATCH CHAT FRAME SIZE
-- Blizzard's DamageMeter frame takes the chat skin's size, again after every Edit Mode sizing and
-- every chat resize. FlareUI's chat only; out of combat only.
--------------------------------------------------
local matchSizing = false
local hookedChatSource

local function ChatSizeSource()
    local chat = _G.ChatFrame1
    return chat and (chat.FlareUI_Skin or chat)
end

local function ChatModuleOn()
    local chat = ns.db and ns.db.profile and ns.db.profile.chat
    return chat ~= nil and chat.enabled == true
end

local function MatchChatSize()
    local db = GetDb()
    local meter = _G.DamageMeter
    if matchSizing or not (db and db.enabled and db.matchChatSize and meter) or InCombatLockdown() then return end
    if not ChatModuleOn() then return end
    local source = ChatSizeSource()
    local width, height = source and source:GetSize()
    if not (width and height and width > 0 and height > 0) then return end
    matchSizing = true
    meter:SetSize(width, height)
    matchSizing = false
end

local function HookChatSize()
    local meter, source = _G.DamageMeter, ChatSizeSource()
    if not (meter and source) then return end
    if not meter.FlareUI_SizeHooked then
        meter.FlareUI_SizeHooked = true
        hooksecurefunc(meter, "SetSize", MatchChatSize)
    end
    -- the chat's skin arrives with the Chat module, after ChatFrame1 itself
    if source ~= hookedChatSource then
        hookedChatSource = source
        source:HookScript("OnSizeChanged", MatchChatSize)
    end
end

-- Switched off: Edit Mode's own Frame Width / Height again
function DamageMeter:RestoreEditModeSize()
    local meter = _G.DamageMeter
    if meter and not InCombatLockdown() and meter.UpdateSystemSettingFrameWidth then
        meter:UpdateSystemSettingFrameWidth()
        meter:UpdateSystemSettingFrameHeight()
    end
end

--------------------------------------------------
-- 16. REFRESH ALL
--------------------------------------------------
function DamageMeter:Refresh()
    if InCombatLockdown() then
        self._pendingRefresh = true
        return
    end

    local db = GetDb()
    if not db or not db.enabled then return end
    self:SetupMouseover()
    -- several events can ask in the same frame
    local now = GetTime()
    if self._lastRefresh == now then return end
    self._lastRefresh = now

    for _, window in ipairs(GetSessionWindows()) do
        self:ApplyToWindow(window)
    end
    HookChatSize()
    -- Match chat size switched off: Edit Mode's own Frame Width / Height again
    if db.matchChatSize then
        MatchChatSize()
        self.sizeMatched = true
    elseif self.sizeMatched then
        self.sizeMatched = nil
        self:RestoreEditModeSize()
    end
    ApplyThreatKey()

    self._pendingRefresh = false
end

--------------------------------------------------
-- 17. EVENT HANDLERS
--------------------------------------------------
function DamageMeter:PLAYER_REGEN_ENABLED()
    if self._pendingRefresh then
        C_Timer.After(0, function() self:Refresh() end)
    end
end

function DamageMeter:EDIT_MODE_LAYOUTS_UPDATED()
    C_Timer.After(0.25, function() self:Refresh() end)
end

function DamageMeter:ADDON_LOADED(event, addonName)
    if addonName == "Blizzard_DamageMeter" then
        C_Timer.After(0, function() self:Refresh() end)
        C_Timer.After(0.5, function() self:Refresh() end)
    end
end

function DamageMeter:PLAYER_ENTERING_WORLD()
    C_Timer.After(0.5, function() self:Refresh() end)
end

--------------------------------------------------
-- 17b. VISIBILITY AND SHOW ON MOUSEOVER (Settings > Damage Meter)
-- FlareUI's own visibility, applied after each of Blizzard's checks: it overrules the meter's Edit Mode
-- dropdown (a preset layout, such as the one Blizzard picks when gamepad mode ends, cannot save that
-- one). Show on Mouseover: while the visibility hides the meter, it stays up but invisible and shows
-- under the mouse. Every show and hide fades at the Fade Speed (instant, fast, slow): one driver moves
-- the meter's alpha to its target and hides the meter once a fade out ends. Blizzard's own switch for
-- the meter (off) still hides it at once.
--------------------------------------------------
local VISIBILITY = {
    always = function() return true end,
    combat = function(meter) return meter:IsPlayerInCombat() end,
    hidden = function() return false end,
    group  = function(meter) return meter:IsPlayerInGroup() end,
}
local fadeDriver = CreateFrame("Frame")
fadeDriver:Hide()
local fadeTarget, hideWhenFaded = 1, false

local function MeterUnderMouse(meter)
    if meter:IsMouseOver() then return true end
    local over = false
    if type(meter.ForEachSessionWindow) == "function" then
        meter:ForEachSessionWindow(function(window) if window:IsMouseOver() then over = true end end)
    end
    return over
end

-- The bags or the quest log (the world map on Forever) open over the meter's place: no reveal then
local function PanelsInTheWay()
    if _G.WorldMapFrame and _G.WorldMapFrame:IsShown() then return true end
    if _G.ContainerFrameCombinedBags and _G.ContainerFrameCombinedBags:IsShown() then return true end
    for i = 1, _G.NUM_CONTAINER_FRAMES or 0 do
        local bag = _G["ContainerFrame" .. i]
        if bag and bag:IsShown() then return true end
    end
    return false
end

local applying = false

local function FadeStep(self, meter, elapsed)
    local target = fadeTarget
    if meter.FlareUI_MouseHidden then target = (MeterUnderMouse(meter) and not PanelsInTheWay()) and 1 or 0 end
    local db = GetDb()
    local time = ns.FadeTime(db and db.fadeSpeed)
    local alpha = meter:GetAlpha()
    if time <= 0 then
        alpha = target
    elseif alpha < target then
        alpha = math.min(target, alpha + elapsed / time)
    else
        alpha = math.max(target, alpha - elapsed / time)
    end
    meter:SetAlpha(alpha)
    if alpha ~= target then return end
    if target == 0 and DamageMeter.viewBackPending then DamageMeter.ShowDamageViews() end
    if hideWhenFaded and target == 0 then
        hideWhenFaded = false
        local wasApplying = applying
        applying = true
        meter:Hide()
        applying = wasApplying
    end
    if not meter.FlareUI_MouseHidden then self:Hide() end
end

-- runs while a fade is under way, or while the mouse decides (Show on Mouseover)
fadeDriver:SetScript("OnUpdate", function(self, elapsed)
    local meter = _G.DamageMeter
    if not meter then self:Hide() return end
    FadeStep(self, meter, elapsed)
end)

-- true while the meter is on screen and on its way out
function DamageMeter.FadingOut()
    local meter = _G.DamageMeter
    if not (meter and meter:IsShown() and fadeDriver:IsShown() and meter:GetAlpha() > 0) then return false end
    if meter.FlareUI_MouseHidden then return not (MeterUnderMouse(meter) and not PanelsInTheWay()) end
    return fadeTarget == 0
end

-- toward 1 or 0 at the Fade Speed; hide: once it reaches 0
-- the first step now: an instant change lands before the meter draws
local function FadeMeter(meter, target, hide)
    fadeTarget, hideWhenFaded = target, hide and true or false
    fadeDriver:Show()
    FadeStep(fadeDriver, meter, 0)
end

-- Blizzard's switch for the meter is on and the meter can be used here
local function MeterAllowed()
    if C_CVar.GetCVarBool and not C_CVar.GetCVarBool("damageMeterEnabled") then return false end
    if C_DamageMeter and C_DamageMeter.IsDamageMeterAvailable and not C_DamageMeter.IsDamageMeterAvailable() then return false end
    return true
end

local function ApplyVisibility(meter)
    local db = GetDb()
    if applying or not (db and db.enabled) then return end
    applying = true
    -- whether the meter was up (shown, not faded out) before Blizzard's check: a fade starts from there
    local wasUp = meter.FlareUI_Up
    local editing = type(meter.IsEditing) == "function" and meter:IsEditing()
    meter.FlareUI_MouseHidden = nil
    if editing or DamageMeter.settingsPreview then
        hideWhenFaded = false
        meter:Show()
        meter:SetAlpha(1)
        meter.FlareUI_Up = true
    elseif not MeterAllowed() then
        hideWhenFaded = false
        meter:Hide()
        if DamageMeter.viewBackPending then DamageMeter.ShowDamageViews() end
        meter.FlareUI_Up = false
    elseif (VISIBILITY[db.visibility] or VISIBILITY.always)(meter) then
        -- from where a fade out left it, or from nothing when it was hidden
        if not wasUp and not meter:IsShown() then meter:SetAlpha(0) end
        meter:Show()
        meter.FlareUI_Up = true
        FadeMeter(meter, 1)
    elseif db.showOnMouseover then
        if not wasUp and not meter:IsShown() then meter:SetAlpha(0) end
        meter:Show()
        meter.FlareUI_MouseHidden = true
        meter.FlareUI_Up = false
        FadeMeter(meter, 0)
    elseif wasUp then
        -- it was up: back on screen for its fade out, hidden at the end
        meter:Show()
        meter.FlareUI_Up = false
        FadeMeter(meter, 0, true)
    else
        hideWhenFaded = false
        meter:Hide()
    end
    applying = false
end

function DamageMeter:SetupMouseover()
    local meter = _G.DamageMeter
    if not meter or self.mouseoverHooked or type(meter.UpdateShownState) ~= "function" then return end
    self.mouseoverHooked = true
    hooksecurefunc(meter, "UpdateShownState", ApplyVisibility)
    meter:UpdateShownState()
end

-- the settings page changed the visibility or the mouseover
function DamageMeter:ApplyVisibility()
    local meter = _G.DamageMeter
    if meter and type(meter.UpdateShownState) == "function" then meter:UpdateShownState() end
end

--------------------------------------------------
-- 18. INIT
--------------------------------------------------
function DamageMeter:Init()
    -- EDIT_MODE_LAYOUTS_UPDATED fires while Edit Mode is open, where Refresh does nothing
    if _G.EditModeManagerFrame and not self._editModeHooked then
        self._editModeHooked = true
        _G.EditModeManagerFrame:HookScript("OnHide", function()
            C_Timer.After(0, function() DamageMeter:Refresh() end)
        end)
    end

    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    self:RegisterEvent("ADDON_LOADED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    GROUP_BUTTONS.events:RegisterEvent("GROUP_ROSTER_UPDATE")
    GROUP_BUTTONS.events:RegisterEvent("PARTY_LEADER_CHANGED")
    timerEvents:RegisterEvent("PLAYER_REGEN_DISABLED")
    timerEvents:RegisterEvent("PLAYER_REGEN_ENABLED")

    C_Timer.After(0, function() self:Refresh() end)
    C_Timer.After(1, function() self:Refresh() end)
end
