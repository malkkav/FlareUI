local ADDON_NAME, ns = ...

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

-- The border picked in the options; a name LibSharedMedia no longer knows falls back to the default.
local DEFAULT_BORDER = "FlareUI Thin"
local function GetBorderFile(db)
    local name = db and db.borderTexture
    if not (name and LSM:IsValid("border", name)) then name = DEFAULT_BORDER end
    return LSM:Fetch("border", name)
end

--------------------------------------------------
-- 3. CONSTANTS
--------------------------------------------------
local SEPARATORS = {
    ["Solid"] = nil,
    ["Blizzard"] = "Interface\\Common\\UI-TooltipDivider-Transparent",
}

local ICON_SEGMENTS = "Interface\\AddOns\\FlareUI\\Media\\Icons\\DMSegments.tga"
local ICON_SETTINGS = "Interface\\AddOns\\FlareUI\\Media\\Icons\\DMSettings.tga"
local ICON_READY     = "Interface\\AddOns\\FlareUI\\Media\\Icons\\DMReadyCheck.tga"
local ICON_COUNTDOWN = "Interface\\AddOns\\FlareUI\\Media\\Icons\\DMCountdown.tga"

-- Fixed look, mirrored from the chat frame so both headers read as one design:
-- 24 px header band, separator 24-32 px below the top, content from 34 px, title and icons centred
-- 15 px below the top, 13 px icons 15 px in from the right and 21 px apart, title 22 px from the left.
local HEADER_HEIGHT   = 24
local CONTENT_TOP     = 34
local ROW_CENTER_Y    = -15
local TITLE_LEFT      = 17   -- chat: 10 px tab-bar offset + 7 px button padding
local ICON_SIZE       = 13   -- nominal box, used for layout maths
-- Per-icon draw sizes so the *visible* glyph matches the chat header icons, which measure 9-11 px.
-- The segment bars fill their whole 24x24 texture, so the draw size is the visible size. The gear
-- only occupies rows 1.3-16.3 of its 24 (15/24 of the height), so 16 draws a ~10 px glyph.
-- the checkmark fills 42 of its 64 rows and the stopwatch 92 of 100: 16 and 12 draw both ~11 px tall, as the bars
local ICON_DRAW_SIZE  = { settings = 16, segments = 11, ready = 16, countdown = 12 }
-- Because the gear sits high in its texture, centring its glyph on the button needs an offset of
-- -0.13 * draw size; -2.5 is that plus a small nudge down so it settles against the bars icon.
local ICON_DRAW_YOFS  = { settings = -2.5, segments = 0 }
local ICON_RIGHT      = 15
local ICON_SPACING    = 21
local TITLE_COLOR     = { r = 0.80, g = 0.60, b = 0.34, a = 1 }   -- #CC9957 (chat active tab)
local ICON_COLOR      = { r = 0.61, g = 0.48, b = 0.29, a = 1 }   -- #9C7A4A (chat header icons)
local BORDER_TINT     = ns.BORDER_COLOR                            -- FlareUI's border bronze (as chat)
local SEPARATOR_COLOR = { r = 1, g = 1, b = 1, a = 1 }

local function LightenColor(r, g, b, factor)
    return math_min(1, r + factor), math_min(1, g + factor), math_min(1, b + factor)
end

--------------------------------------------------
-- 4. HELPERS
-- Three hooks that look tempting are deliberately absent: SetSessionDuration (receives secret
-- values), the session window's OnShow / SetMinimized (run inside the secure list init that
-- handles Edit Mode preview data) and the entry Init / UpdateValue (run inside the secure scroll
-- update). Styling from any of them taints a path that later compares secret values. Everything
-- below is applied from our own Refresh() instead, out of combat and outside Edit Mode.
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
    if dbEntry.enableShadow then
        fontString:SetShadowColor(0, 0, 0, 1)
        fontString:SetShadowOffset(dbEntry.shadowX or 1, dbEntry.shadowY or -1)
    else
        fontString:SetShadowColor(0, 0, 0, 0)
        fontString:SetShadowOffset(0, 0)
    end
    if dbEntry.useCustomColor and dbEntry.color then
        local c = dbEntry.color
        fontString:SetTextColor(c.r, c.g, c.b, c.a or 1)
    end
end

local function IsEditModeActive()
    return _G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown()
end

-- Session window internals moved behind getter methods in newer API.
-- Use getter-first access with legacy key fallbacks for cross-version compatibility.
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
    -- Never call window:SetMinimized() from here: it writes window.isMinimized under our taint, and
    -- every later Blizzard Refresh() that reads it runs tainted and trips over secret values in combat.
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
-- 6. SKIN FRAME (Backdrop + Border)
-- Anchored to Background texture for equal padding on all sides.
-- padding=0 => border exactly on Blizzard frame; padding>0 => extends outward evenly.
--------------------------------------------------
local function CreateOrGetSkinFrame(window, db)
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
    local skin = CreateOrGetSkinFrame(window, db)
    local padding = db.textPadding or 0
    local header = GetWindowHeader(window)

    -- Anchor to the full window so the skin matches the bounds Edit Mode uses
    skin:ClearAllPoints()
    skin:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", -padding, -padding)
    skin:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", padding, -padding)
    skin:SetPoint("TOPLEFT", window, "TOPLEFT", -padding, padding)
    skin:SetPoint("TOPRIGHT", window, "TOPRIGHT", padding, padding)
    skin:SetFrameStrata(window:GetFrameStrata())
    skin:SetFrameLevel(math_max((window:GetFrameLevel() or 1) - 1, 0))

    -- Same look as the chat frame: Blizzard's dark dialog background inside the border picked in the options
    local bgTexture     = LSM:Fetch("background", "Blizzard Dialog Background Dark") or "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"
    local borderTexture = GetBorderFile(db)
    skin:SetBackdrop({ bgFile = bgTexture, edgeFile = borderTexture, tile = false, tileSize = 0, edgeSize = 16, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    skin:SetBackdropColor(1, 1, 1, db.opacity or 0.85)
    skin:SetBackdropBorderColor(BORDER_TINT.r, BORDER_TINT.g, BORDER_TINT.b, BORDER_TINT.a)

    -- Blizzard draws its own background atlas (alpha from its "background transparency" setting)
    -- and a header bar; the skin is the only background now, so keep both at zero.
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

    -- Separator: same texture and placement as the chat frame (24-32 px below the top edge)
    if header and not db.hideHeader then
        skin.Separator:Show()
        skin.Separator:SetColorTexture(0, 0, 0, 0)
        skin.Separator:SetTexture(SEPARATORS["Blizzard"])
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
-- 7. SOURCE WINDOW SKIN
-- Clicking a bar opens Blizzard's SourceWindow with the per-spell breakdown (Shift-click pins it).
-- It is a sibling of the session window with its own dropdown-style background, so without this it
-- pops out of the side of the meter in raw Blizzard grey. Same backdrop as the session window, no
-- header band - the source window has no header.
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
    skin:SetFrameStrata(sw:GetFrameStrata())
    skin:SetFrameLevel(math_max((sw:GetFrameLevel() or 1) - 1, 0))

    local bgTexture     = LSM:Fetch("background", "Blizzard Dialog Background Dark") or "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"
    local borderTexture = GetBorderFile(db)
    skin:SetBackdrop({ bgFile = bgTexture, edgeFile = borderTexture, tile = false, tileSize = 0, edgeSize = 16, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    skin:SetBackdropColor(1, 1, 1, db.opacity or 0.85)
    skin:SetBackdropBorderColor(BORDER_TINT.r, BORDER_TINT.g, BORDER_TINT.b, BORDER_TINT.a)

    local bg = GetWindowBackground(sw)
    if bg and bg.SetAlpha then bg:SetAlpha(0) end
end

--------------------------------------------------
-- 7b. GROUP BUTTONS
-- Ready Check and Countdown, left of the segments icon: Blizzard's own C_PartyInfo calls, as its raid
-- manager makes them from its buttons. Each shows only where it applies: Countdown in a group, Ready
-- Check for a group's leader or assistants. The countdown starts a 10-second pull timer on a left-click
-- and cancels it on a right-click.
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

-- the keys switched on that apply right now, right to left
function GROUP_BUTTONS.Shown(db)
    local list = {}
    local applies = { countdown = IsInGroup(), ready = GROUP_BUTTONS.CanReadyCheck() }
    for _, key in ipairs(GROUP_BUTTONS.order) do
        if db and db[GROUP_BUTTONS[key].option] ~= false and applies[key] then list[#list + 1] = key end
    end
    return list
end

function GROUP_BUTTONS.Paint(btn, hover)
    local c = ICON_COLOR
    local r, g, b = c.r, c.g, c.b
    if hover then r, g, b = LightenColor(r, g, b, 0.3) end
    btn.FlareUI_Icon:SetVertexColor(r, g, b, c.a or 1)
end

function GROUP_BUTTONS.Get(window, key)
    local set = GROUP_BUTTONS.buttons[window]
    if not set then set = {}; GROUP_BUTTONS.buttons[window] = set end
    if set[key] then return set[key] end
    local def = GROUP_BUTTONS[key]
    local btn = CreateFrame("Button", nil, window)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local icon = btn:CreateTexture(nil, "OVERLAY", nil, 7)
    icon:SetTexture(def.icon)
    icon:SetSize(ICON_DRAW_SIZE[key], ICON_DRAW_SIZE[key])
    icon:SetPoint("CENTER")
    btn.FlareUI_Icon = icon
    -- no tooltip, like the header's other icons: the settings' toggles explain them
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

-- joining, leaving, or a new leader or assistant: the header is laid out again (once per burst of
-- events; Refresh itself waits for the end of combat)
GROUP_BUTTONS.events = CreateFrame("Frame")
GROUP_BUTTONS.events:RegisterEvent("GROUP_ROSTER_UPDATE")
GROUP_BUTTONS.events:RegisterEvent("PARTY_LEADER_CHANGED")
GROUP_BUTTONS.events:SetScript("OnEvent", function()
    if GROUP_BUTTONS.pending then return end
    GROUP_BUTTONS.pending = true
    C_Timer.After(0.2, function()
        GROUP_BUTTONS.pending = nil
        local db = GetDb()
        if db and db.enabled and DamageMeter.Refresh then DamageMeter:Refresh() end
    end)
end)

-- lays the switched-on buttons out left of the segments icon, hides the rest; returns how many show
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
            btn:SetFrameStrata(levelOf:GetFrameStrata())
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
-- Forward declaration: ApplyHeader calls this, but the body belongs with the rest of the button
-- styling in the next section. It must stay declared here - as a plain "local function" further
-- down, the call below would resolve to a nil global.
local AttachHeaderButtonHooks

local function ApplyHeader(window, db)
    if not window or window:IsForbidden() then return end
    local header = GetWindowHeader(window)
    if not header then return end

    local hideHeader = db.hideHeader

    if hideHeader then
        header:Hide()
        header:SetAlpha(0)
        header:SetHeight(1)
        -- Hide header elements so they don't overlap bars; prevent Blizzard from re-showing
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
        header:SetAlpha(0)   -- the skin provides the header background; keep the frame for anchoring
        header:SetHeight(HEADER_HEIGHT)
        -- Session timer: Blizzard's own "[mm:ss]" (live in combat, fixed on a past segment) with Combat
        -- Timer on; hidden otherwise
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

        -- Lay the header out like the chat header: icons 13 px, 15 px from the right, 21 px apart,
        -- title 22 px from the left, everything centred 15 px below the top edge.
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

    -- ScrollBox anchors: align with inner border (no clipping), full width within content area
    local function ApplyScrollBoxAnchors()
        local sb = GetWindowScrollBox(window)
        local ref = header
        if sb and ref and not InCombatLockdown() then
            local d = GetDb()
            if not d then return end
            local skinRef = window.FlareUI_DMSkin or window
            sb:ClearAllPoints()
            sb:SetPoint("TOPLEFT", skinRef, "TOPLEFT", 6, -CONTENT_TOP)
            sb:SetPoint("BOTTOMRIGHT", skinRef, "BOTTOMRIGHT", -6, 6)
        end
    end
    if not InCombatLockdown() then
        SafeCall(ApplyScrollBoxAnchors)
    end
    -- Re-apply when Blizzard's scrollbar visibility behavior overwrites our anchors
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
-- 9. HEADER BUTTON STYLE (Color + Scale, or Custom Icons)
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
    btn.FlareUI_Icon:SetTexture(iconPath)
    local c = ICON_COLOR
    btn.FlareUI_Icon:SetVertexColor(c.r, c.g, c.b, c.a or 1)
    btn.FlareUI_Icon:Show()

    if not btn.FlareUI_IconHoverHooked then
        btn.FlareUI_IconHoverHooked = true
        btn:HookScript("OnEnter", function(self)
            local db = GetDb()
            if not db or db.hideHeader then return end
            local hR, hG, hB = LightenColor(ICON_COLOR.r, ICON_COLOR.g, ICON_COLOR.b, 0.3)
            if self.FlareUI_Icon then self.FlareUI_Icon:SetVertexColor(hR, hG, hB, ICON_COLOR.a) end
        end)
        btn:HookScript("OnLeave", function(self)
            local db = GetDb()
            if not db or db.hideHeader then return end
            if self.FlareUI_Icon then self.FlareUI_Icon:SetVertexColor(ICON_COLOR.r, ICON_COLOR.g, ICON_COLOR.b, ICON_COLOR.a) end
        end)
    end
end

local function ApplyHeaderButtonStyle(window, db)
    if not window or window:IsForbidden() then return end
    if not db or db.hideHeader then return end

    -- The type dropdown is the title itself (clickable text, like a chat tab): no icon, Blizzard art off
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

-- The bar fill: Blizzard's own atlas unless a texture is picked. Blizzard sets it once, from the entry
-- template, and afterwards only tints it by class, so a texture set here stays put.
local BLIZZARD_BAR_ATLAS = "UI-HUD-CoolDownManager-Bar"
local texturedBars = setmetatable({}, { __mode = "k" })
local function ApplyBarTexture(entry, db)
    if not entry or entry:IsForbidden() then return end
    local statusBar = entry.GetStatusBar and entry:GetStatusBar() or entry.StatusBar
    if not statusBar then return end
    local name = db.barTexture
    if name and name ~= "" and LSM:IsValid("statusbar", name) then
        statusBar:SetStatusBarTexture(LSM:Fetch("statusbar", name))
        texturedBars[statusBar] = true
    elseif texturedBars[statusBar] then
        statusBar:SetStatusBarTexture(BLIZZARD_BAR_ATLAS)
        texturedBars[statusBar] = nil
    end
end

local function StyleEntry(entry, db)
    ApplyBarFont(entry, db)
    ApplyBarTexture(entry, db)
end

--------------------------------------------------
-- 13. SCROLL BOX FONT REFRESH
--------------------------------------------------
-- Fonts and bar textures are applied only during explicit Refresh() passes (out of combat, outside Edit Mode).
-- Hooking ScrollBox:Update or entry Init/UpdateValue instead would run inside Blizzard's secure
-- list updates, where touching the entries taints them (secret preview/combat data).
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
-- Let the window be dragged past the screen edge, like the chat frame. Blizzard's template clamps
-- it, and on Forever something re-clamps it while Edit Mode is active (the window reports
-- unclamped outside Edit Mode but still stops at the edge inside it), so besides unclamping once we
-- undo any later SetClampedToScreen(true) and also unclamp the Edit Mode selection frame.
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

local function ApplyUnclamp(window, db)
    Unclamp(window)
    Unclamp(window.Selection)
end

--------------------------------------------------
-- 14b. THREAT TAB
-- A second view in each meter window, switched like the chat tabs: the title row holds Blizzard's
-- meter type ("Damage Done") and "Threat" side by side, the one not shown in the chat's muted tab
-- colour. Left-click picks a tab. Blizzard's type menu moves to the right button: a hit area over
-- its title takes left-clicks for the tab and lets right-clicks through to Blizzard's own dropdown
-- underneath (SetPassThroughButtons), which is registered for the right button as well, so the
-- menu is still opened by Blizzard's untainted code and never by ours.
-- The list is FlareUI's, as Blizzard's meter has no threat type and its list is secure code: the
-- group sorted by threat on your target (or your friendly target's target), in rows made from
-- Blizzard's own entry template at the window's bar height, spacing, style and text scale, with the
-- meter's font and bar texture. The bar is threat against the top of the list, the text the threat
-- and how close it is to pulling (the tank reads 100%). You are always in the list: past the last
-- row, you take the last row. Threat is readable on Forever; where the client makes it secret the
-- view says so rather than guess. Blizzard's list is only made invisible while Threat is up.
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

-- The spec icon Blizzard's rows show for a player: our own spec, or an inspected one. nil falls back
-- to the class icon, as Blizzard's rows do.
local function SpecIcon(unit, isMe)
    local ok, icon = pcall(function()
        local specID
        if isMe then
            local index = GetSpecialization and GetSpecialization()
            specID = index and GetSpecializationInfo(index)
        else
            specID = GetInspectSpecialization and GetInspectSpecialization(unit)
        end
        if specID and specID ~= 0 then return select(4, GetSpecializationInfoByID(specID)) end
    end)
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

-- Blizzard's list (and its pinned own-row) fades out while Threat is up; nothing else is touched
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
    -- rows are reused for other players, so each kind of icon sets its own coordinates: the spec
    -- texture gets the entry template's crop, the class atlas its own
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
        message = "No hostile target"
    else
        local secret
        list, secret = CollectThreat(mob)
        if secret then
            message, list = "Threat is hidden here", {}
        elseif #list == 0 then
            message = "No threat yet"
        end
    end

    -- you keep a row: if the list runs past the window, the last row is yours
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

-- Redraws are batched: threat events arrive in bursts, the list is drawn at most every THREAT_TICK
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

-- One key (Features > Threat Toggle Keybind) flips every window that has the Threat tab. A plain
-- button the key clicks through an override binding; nothing about it is protected.
local function ToggleThreatViews()
    for window, view in pairs(views) do SetView(window, not view.showing) end
end

-- the "Toggle Threat Meter" radial panel (RadialMenu.lua MICRO_PANELS) runs this
function FlareUI_ToggleThreatMeter()
    if next(views) then
        ToggleThreatViews()
    else
        print("|cff00ff00FlareUI:|r turn on Threat Meter Tab in the Damage Meter settings to use the threat view.")
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

    -- over Blizzard's title: left-click = this tab, right-click falls through to Blizzard's menu
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
    tab.Text:SetText("Threat")
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
-- Blizzard's session timer only moves when the meter's data refreshes, about every two seconds.
-- In combat FlareUI counts the fight itself, from the moment combat started, in Blizzard's own
-- "[mm:ss]" form and place; Blizzard's timer steps aside meanwhile and is back out of combat,
-- where it shows the length of a past segment (a value FlareUI could not read anyway: it is secret).
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

local timerEvents = CreateFrame("Frame")
timerEvents:RegisterEvent("PLAYER_REGEN_DISABLED")
timerEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
timerEvents:SetScript("OnEvent", function(_, event)
    combatStart = event == "PLAYER_REGEN_DISABLED" and GetTime() or nil
    UpdateLiveTimers()
    -- Features > Threat View in Combat: the Threat tab for the fight, Blizzard's view after it
    local db = GetDb()
    if db and db.enabled and db.threatTab and db.autoThreat then
        for window in pairs(views) do SetView(window, combatStart ~= nil) end
    end
end)

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

    -- Never touch secure DamageMeter widgets while Edit Mode preview data is active.
    if IsEditModeActive() then return end
    SafeCall(ApplyUnclamp, window, db)
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
-- The primary window fills Blizzard's DamageMeter frame, an Edit Mode system Edit Mode sizes with
-- SetSize from its Frame Width / Height. With the option on, that frame takes the chat's size - its
-- FlareUI skin when the Chat module is on, ChatFrame1 otherwise - again after every Edit Mode sizing
-- and every chat resize. Out of combat only, like the rest of the meter's styling.
--------------------------------------------------
local matchSizing = false
local hookedChatSource

local function ChatSizeSource()
    local chat = _G.ChatFrame1
    return chat and (chat.FlareUI_Skin or chat)
end

-- FlareUI's chat only: matching Blizzard's own chat frame is not offered
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

-- switched off: Edit Mode's own Frame Width / Height again
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

    for _, window in ipairs(GetSessionWindows()) do
        self:ApplyToWindow(window)
    end
    HookChatSize()
    MatchChatSize()
    ApplyThreatKey()

    self._pendingRefresh = false
    -- No delayed re-apply here any more: AttachHeaderButtonHooks now actually installs, so the
    -- window's and the buttons' OnShow handlers re-style whenever Blizzard rebuilds them.
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
    if addonName == "Blizzard_DamageMeter" or addonName == "Blizzard_CombatLog" or addonName == ADDON_NAME then
        C_Timer.After(0, function() self:Refresh() end)
        C_Timer.After(0.5, function() self:Refresh() end)
    end
end

function DamageMeter:PLAYER_ENTERING_WORLD()
    C_Timer.After(0.5, function() self:Refresh() end)
end

--------------------------------------------------
-- 18. INIT
--------------------------------------------------
function DamageMeter:Init()
    -- EDIT_MODE_LAYOUTS_UPDATED fires while the panel is still open, and ApplyToWindow refuses to
    -- touch the secure widgets then, so that refresh does nothing. Re-run once the panel closes.
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
    self:RegisterEvent("VARIABLES_LOADED")

    C_Timer.After(0, function() self:Refresh() end)
    C_Timer.After(1, function() self:Refresh() end)
end

function DamageMeter:VARIABLES_LOADED()
    C_Timer.After(0.5, function() self:Refresh() end)
end
