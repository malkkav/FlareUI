local _, ns = ...
local L = ns.L

--------------------------------------------------
-- DAMAGE METER
-- Blizzard's damage meter in FlareUI's look: skin, header, fonts, group buttons, a Threat tab, a
-- live combat timer, chat-size matching, a Meter tab in the chat and FlareUI's own visibility with
-- show on mouseover.
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

--------------------------------------------------
-- 3. CONSTANTS
--------------------------------------------------
local SEPARATOR = "Interface\\Common\\UI-TooltipDivider-Transparent"
local DEFAULT_BORDER = "FlareUI Frames"

local ICON_SEGMENTS = "Interface\\AddOns\\FlareUI\\Media\\Icons\\DMSegments.tga"
local ICON_SETTINGS = "Interface\\AddOns\\FlareUI\\Media\\Icons\\DMSettings.tga"
local ICON_READY     = "Interface\\AddOns\\FlareUI\\Media\\Icons\\DMReadyCheck.tga"
local ICON_COUNTDOWN = "Interface\\AddOns\\FlareUI\\Media\\Icons\\DMCountdown.tga"

-- Fixed look, matching the chat header
local SKIN_PADDING    = 2    -- the skin reaches this far past the window
local HEADER_HEIGHT   = 24
local CONTENT_TOP     = 34
local ROW_CENTER_Y    = -15
local TITLE_LEFT      = 17   -- chat: 10 px tab-bar offset + 7 px button padding
local ICON_SIZE       = 13   -- nominal box, used for layout maths
-- draw sizes giving ~10-11 px glyphs like the chat header icons (the art has padding)
local ICON_DRAW_SIZE  = { settings = 16, segments = 11, ready = 16, countdown = 12 }
-- the gear sits high in its texture
local ICON_DRAW_YOFS  = { settings = -2.5, segments = 0 }
local ICON_RIGHT      = 15
local ICON_SPACING    = 21
local CHAT_TAB_ROW    = 28   -- Meter tab: the chat's tab row and its separator line, above the meter's header
local TITLE_COLOR     = { r = 0.80, g = 0.60, b = 0.34, a = 1 }   -- #CC9957 (chat active tab)
local ICON_COLOR      = { r = 0.61, g = 0.48, b = 0.29, a = 1 }   -- #9C7A4A (chat header icons)
local BORDER_TINT     = ns.BORDER_COLOR

local function LightenColor(r, g, b, factor)
    return math_min(1, r + factor), math_min(1, g + factor), math_min(1, b + factor)
end

--------------------------------------------------
-- 4. HELPERS
-- Never hook SetSessionDuration, SetMinimized or the entries' Init / UpdateValue: secure code with
-- secret values that styling taints. Styling is applied from Refresh(), out of combat (only the list's
-- anchors and the group buttons also follow changes in a fight).
--------------------------------------------------
local function GetDb()
    if not ns.db or not ns.db.profile or not ns.db.profile.damagemeter then
        return nil
    end
    return ns.db.profile.damagemeter
end

-- Meter Tab in the Chat: the option on (section 19), Blizzard's switch (22), its rule and strata (23)
local ChatTabOn, MeterAllowed, ApplyChatTab, ApplyChatTabStrata

-- The border picked in the options, or the default when LibSharedMedia does not know it
local function GetBorderFile(db)
    local name = db and db.borderTexture
    if name == "None" then return nil end   -- Frame Border: None
    if not (name and LSM:IsValid("border", name)) then name = DEFAULT_BORDER end
    return LSM:Fetch("border", name)
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
    local path = ns.GetFontPath(face)
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

-- Showing the meter runs Blizzard's refresh, which in a fight compares the secret session duration
-- and throws from addon code. The player is in combat a moment before lockdown begins.
local function InFight()
    if InCombatLockdown() then return true end
    local busy = UnitAffectingCombat("player")
    return not canaccessvalue(busy) or busy and true or false
end

-- Settings > Damage Meter open: the meter stays shown whatever its visibility, also after Blizzard's
-- re-checks on combat and group changes. With the module off Blizzard's meter is left alone.
function DamageMeter:SetSettingsPreview(on)
    local meter = _G.DamageMeter
    on = on and true or false
    if not meter or (self.settingsPreview or false) == on then return end
    local db = GetDb()
    if on and not (db and db.enabled) then return end
    self.settingsPreview = on
    if not self.previewHooked and type(meter.UpdateShownState) == "function" then
        self.previewHooked = true
        hooksecurefunc(meter, "UpdateShownState", function(m)
            if DamageMeter.settingsPreview and not InFight() and not m:IsShown() then m:Show() end
        end)
    end
    -- the Threat tab's sample rows come and go with the page (a Threat option shown there goes back
    -- to the player's own tab pick)
    if DamageMeter.EndThreatPreview then
        if not on then DamageMeter.EndThreatPreview() end
        DamageMeter.RedrawThreat()
    end
    -- with the Meter tab in the chat, the page opens that tab, and leaving it goes back to the chat
    -- tab that was up (unless a tab was clicked meanwhile)
    if self:ChatTabAvailable() then
        if on then
            self.previewTabWas = self.chatTabActive or false
            self:SetChatTab(true)
        else
            if self.previewTabWas == false and self.chatTabActive then self:SetChatTab(false) end
            self.previewTabWas = nil
        end
    end
    if InFight() then return end
    -- both ways through ApplyVisibility: its preview branch stops any fade and sets alpha 1 (a plain
    -- Show would leave a faded-out meter at alpha 0)
    DamageMeter:ApplyVisibility()
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
        -- hidden, unless Blizzard restored a collapsed window: its button is the way back, in the
        -- middle of the empty window (the skin's own buttons hold the top right)
        -- never window:SetMinimized(): it taints isMinimized, which Blizzard reads with secret values
        local function Update()
            local collapsed = window.IsMinimized and window:IsMinimized() and true or false
            btn:SetShown(collapsed)
            btn:SetAlpha(collapsed and 1 or 0)
            btn:EnableMouse(collapsed)
        end
        if not btn.FlareUI_HideHooked then
            btn.FlareUI_HideHooked = true
            btn:ClearAllPoints()
            btn:SetPoint("CENTER", window, "CENTER")
            btn:SetFrameLevel(btn:GetFrameLevel() + 10)
            btn:HookScript("OnShow", Update)
            -- Blizzard shows the list exactly while the window isn't collapsed
            local container = window.GetMinimizeContainer and window:GetMinimizeContainer()
            if container then
                container:HookScript("OnShow", Update)
                container:HookScript("OnHide", Update)
            end
        end
        Update()
    end
end

--------------------------------------------------
-- 5. GET SESSION WINDOWS
--------------------------------------------------
local function GetSessionWindows()
    local list = {}
    for i = 1, 3 do   -- Blizzard's maximum
        local w = _G["DamageMeterSessionWindow" .. i]
        if w then list[#list + 1] = w end
    end
    return list
end

--------------------------------------------------
-- 6. SKIN FRAME (backdrop, border and the line under the header)
--------------------------------------------------
local function CreateOrGetSkinFrame(window)
    local skin = window.FlareUI_DMSkin
    if not skin then
        skin = CreateFrame("Frame", nil, window, "BackdropTemplate")
        window.FlareUI_DMSkin = skin
        local line = skin:CreateTexture(nil, "OVERLAY")
        line:SetTexture(SEPARATOR)
        line:SetHeight(8)
        line:SetPoint("TOPLEFT", skin, "TOPLEFT", 3, -HEADER_HEIGHT)
        line:SetPoint("TOPRIGHT", skin, "TOPRIGHT", -3, -HEADER_HEIGHT)
        skin.Separator = line
    end
    return skin
end

-- In the chat window (Meter tab) the chat's skin is the background: the meter's goes clear, its
-- separator line stays. Back in Edit Mode, where the meter may sit elsewhere.
local function SetSkinInChat(window, db, inChat)
    local skin = window.FlareUI_DMSkin
    if not skin then return end
    inChat = inChat and true or false
    skin.FlareUI_InChat = inChat
    skin:SetBackdropColor(1, 1, 1, inChat and 0 or db.opacity or 0.85)
    skin:SetBackdropBorderColor(BORDER_TINT.r, BORDER_TINT.g, BORDER_TINT.b, inChat and 0 or BORDER_TINT.a)
end

local function UpdateSkinFrame(window, db)
    if not window or window:IsForbidden() then return end
    local skin = CreateOrGetSkinFrame(window)
    local header = GetWindowHeader(window)

    skin:ClearAllPoints()
    skin:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", -SKIN_PADDING, -SKIN_PADDING)
    skin:SetPoint("TOPRIGHT", window, "TOPRIGHT", SKIN_PADDING, SKIN_PADDING)
    ns.CopyStrata(skin, window)
    skin:SetFrameLevel(math_max((window:GetFrameLevel() or 1) - 1, 0))

    local bgTexture     = LSM:Fetch("background", "Blizzard Dialog Background Dark") or "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"
    local borderTexture = GetBorderFile(db)
    skin:SetBackdrop({ bgFile = bgTexture, edgeFile = borderTexture, tile = false, tileSize = 0, edgeSize = ns.BorderEdgeSize(borderTexture, 16), insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    SetSkinInChat(window, db, ChatTabOn())

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

    skin.Separator:SetShown(header ~= nil)
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

    skin:ClearAllPoints()
    skin:SetPoint("BOTTOMLEFT", sw, "BOTTOMLEFT", -SKIN_PADDING, -SKIN_PADDING)
    skin:SetPoint("TOPRIGHT", sw, "TOPRIGHT", SKIN_PADDING, SKIN_PADDING)
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
-- 8. GROUP BUTTONS
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
    -- a raid counts down from its leader or an assistant, like Blizzard's raid manager; a party from anyone
    local canReady = GROUP_BUTTONS.CanReadyCheck()
    local applies = { countdown = IsInGroup() and (not IsInRaid() or canReady), ready = canReady }
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
        if not (db and db.enabled and DamageMeter.Refresh) then return end
        -- only when another set of buttons applies now (Layout notes the last one laid out)
        if table.concat(GROUP_BUTTONS.Shown(db), ",") == GROUP_BUTTONS.laidOut then return end
        -- in a fight the buttons are FlareUI's own: laid out now, the rest of the header after the fight
        if InCombatLockdown() then GROUP_BUTTONS.LayoutAll(db) end
        DamageMeter:Refresh()
    end)
end)

-- Lays out the buttons that show, left of the segments icon; returns how many show
function GROUP_BUTTONS.Layout(window, db, ref, box, levelOf)
    local shown = GROUP_BUTTONS.Shown(db)
    GROUP_BUTTONS.laidOut = table.concat(shown, ",")
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

-- A roster change in a fight: the buttons only, against the header as it was laid out
function GROUP_BUTTONS.LayoutAll(db)
    for _, window in ipairs(GetSessionWindows()) do
        local header = GetWindowHeader(window)
        if header and window.FlareUI_DMSkin then
            local levelOf = GetWindowSessionDropdown(window) or GetWindowSettingsDropdown(window)
            SafeCall(GROUP_BUTTONS.Layout, window, db, window.FlareUI_DMSkin, ICON_SIZE + 9, levelOf)
        end
    end
end

--------------------------------------------------
-- 9. HEADER
--------------------------------------------------
local AttachHeaderButtonHooks   -- defined in section 10

local function ApplyHeader(window, db)
    if not window or window:IsForbidden() then return end
    local header = GetWindowHeader(window)
    if not header then return end

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

    -- The list sits inside FlareUI's skin. Neither the meter nor its list is protected, so this also
    -- runs in a fight.
    local function AnchorScrollBox(sb)
        local skinRef = window.FlareUI_DMSkin or window
        sb:ClearAllPoints()
        sb:SetPoint("TOPLEFT", skinRef, "TOPLEFT", 6, -CONTENT_TOP)
        sb:SetPoint("BOTTOMRIGHT", skinRef, "BOTTOMRIGHT", -6, 6)
    end
    local function ApplyScrollBoxAnchors()
        local sb = GetWindowScrollBox(window)
        local d = GetDb()
        if not (sb and d and d.enabled) or sb.FlareUI_Anchoring then return end
        sb.FlareUI_Anchoring = true
        SafeCall(AnchorScrollBox, sb)
        sb.FlareUI_Anchoring = nil
    end
    ApplyScrollBoxAnchors()
    -- Blizzard re-anchors the list after its scroll bar shows or hides: put back right after it
    local scrollBox = GetWindowScrollBox(window)
    if scrollBox and not scrollBox.FlareUI_ScrollBoxAnchorHooked then
        scrollBox.FlareUI_ScrollBoxAnchorHooked = true
        hooksecurefunc(scrollBox, "SetPoint", ApplyScrollBoxAnchors)
    end

    AttachHeaderButtonHooks(window)
end

--------------------------------------------------
-- 10. HEADER BUTTON STYLE
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
            if self.FlareUI_Icon then ns.BronzeIcon.Paint(self.FlareUI_Icon, ICON_COLOR, true) end
        end)
        btn:HookScript("OnLeave", function(self)
            if self.FlareUI_Icon then ns.BronzeIcon.Paint(self.FlareUI_Icon, ICON_COLOR, false) end
        end)
    end
end

local function ApplyHeaderButtonStyle(window)
    if not window or window:IsForbidden() then return end

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

    -- the window and its three buttons all show together: one pass per frame
    local function Reapply()
        local db = GetDb()
        local now = GetTime()
        if db and db.enabled and window.FlareUI_ButtonsStyledAt ~= now then
            window.FlareUI_ButtonsStyledAt = now
            SafeCall(ApplyHeaderButtonStyle, window)
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
-- 11. SCROLL BAR
--------------------------------------------------
-- The bar stays Blizzard's to show or hide (every layout of the list shows it again); FlareUI only
-- makes its parts invisible and click-through. Blizzard's hover animation fades the bar
-- itself, which has nothing left to show. The mouse wheel still scrolls the list.
local function MuteScrollBar(bar)
    if bar.FlareUI_Muted then return end
    bar.FlareUI_Muted = true
    bar:EnableMouse(false)
    for _, region in ipairs({ bar:GetRegions() }) do region:SetAlpha(0) end
    for _, child in ipairs({ bar:GetChildren() }) do
        child:SetAlpha(0)
        child:EnableMouse(false)
        for _, part in ipairs({ child:GetChildren() }) do part:EnableMouse(false) end
    end
end

local function ApplyScrollBarVisibility(window)
    if not window or window:IsForbidden() then return end
    local sb = GetWindowScrollBar(window)
    if not sb then return end

    MuteScrollBar(sb)
    local scrollBox = GetWindowScrollBox(window)
    if scrollBox and scrollBox.EnableMouseWheel then
        scrollBox:EnableMouseWheel(true)
    end

    local sw = GetWindowSourceWindow(window)
    if sw and sw.ScrollBar then
        MuteScrollBar(sw.ScrollBar)
        if sw.ScrollBox and sw.ScrollBox.EnableMouseWheel then
            sw.ScrollBox:EnableMouseWheel(true)
        end
    end
end

--------------------------------------------------
-- 12. HEADER FONTS
--------------------------------------------------
-- Settings > Damage Meter > Fonts > Header, always in the header's gold
local HEADER_FONT = { face = "Friz Quadrata TT", size = 12, flags = "NONE", enableShadow = true, shadowX = 1, shadowY = -1 }

local function ApplyHeaderFonts(window)
    if not window or window:IsForbidden() then return end
    local db = GetDb()
    local fontDb = setmetatable({ useCustomColor = true, color = TITLE_COLOR },
        { __index = (db and db.headerFont) or HEADER_FONT })
    local path, size, flags = GetFontData(fontDb)

    local function ApplyToFontString(fs)
        if not fs or not fs.SetFont then return end
        ns.SetFont(fs, path, size, flags)
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
-- 13. BAR FONTS
--------------------------------------------------
-- the bar fill stays Blizzard's; only the font is FlareUI's. Blizzard sets a row up again on every
-- rebuild of the list but never touches its font, so a row is styled once per pass of Refresh (a
-- changed setting brings a new pass) and skipped after that.
local barFontPass = 0

local function ApplyBarFont(entry, db)
    if not entry or entry:IsForbidden() then return end
    local fontDb = db.barFont
    if not fontDb or entry.FlareUI_FontPass == barFontPass then return end
    entry.FlareUI_FontPass = barFontPass

    local path, size, flags = GetFontData(fontDb)
    local statusBar = entry.GetStatusBar and entry:GetStatusBar() or entry.StatusBar
    local nameFs = statusBar and statusBar.Name or entry.Name
    local valueFs = statusBar and statusBar.Value or entry.Value

    -- a family: other players' names keep their Cyrillic and Chinese / Korean letters
    local function ApplyToFS(fs)
        if fs and fs.SetFont then
            ns.SetFontFamily(fs, path, size, flags)
            ApplyFontEffects(fs, fontDb)
        end
    end

    -- the row's only texts, both on its status bar
    ApplyToFS(nameFs)
    ApplyToFS(valueFs)
end

-- Blizzard calls SetTextScale on every row it sets up, so the bar font is re-applied there: hooked
-- on the row mixin (rows made later) and on each row styled before.
local function RestyleEntry(entry)
    local db = GetDb()
    if db and db.enabled and db.barFont then ApplyBarFont(entry, db) end
end

local function HookEntryFonts()
    local mixin = _G.DamageMeterEntryMixin
    if mixin and not DamageMeter.FlareUI_EntryHooked and type(mixin.SetTextScale) == "function" then
        DamageMeter.FlareUI_EntryHooked = true
        hooksecurefunc(mixin, "SetTextScale", RestyleEntry)
    end
end

local function HookEntry(entry)
    -- a row made after the mixin's hook carries it already
    if entry and DamageMeter.FlareUI_EntryHooked and entry.SetTextScale == _G.DamageMeterEntryMixin.SetTextScale then return end
    if entry and not entry.FlareUI_FontHooked and type(entry.SetTextScale) == "function" then
        entry.FlareUI_FontHooked = true
        hooksecurefunc(entry, "SetTextScale", RestyleEntry)
    end
end

--------------------------------------------------
-- 14. SCROLL BOX FONT REFRESH (Refresh only: see HELPERS)
--------------------------------------------------
local function ApplyFontsToScrollBox(scrollBox, db)
    if not scrollBox or not db then return end
    if scrollBox.ForEachFrame then
        scrollBox:ForEachFrame(function(frame)
            HookEntry(frame)
            ApplyBarFont(frame, db)
        end)
    elseif scrollBox.EnumerateFrames then
        for frame in scrollBox:EnumerateFrames() do
            HookEntry(frame)
            ApplyBarFont(frame, db)
        end
    end
end

--------------------------------------------------
-- 15. UNCLAMP
--------------------------------------------------
-- The window may be dragged past the screen edge, like the chat. Edit Mode re-clamps it, so later
-- clamps are undone.
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
-- 16. THREAT TAB
-- A second view beside Blizzard's meter type in the title row. A hit area over Blizzard's title
-- passes right-clicks through to its type menu. Blizzard's list is secure code, so the threat list
-- is FlareUI's own, in rows from Blizzard's entry template; the player always keeps a row.
--------------------------------------------------
local TAB_GAP       = 14
local TAB_INACTIVE  = { r = 0.56, g = 0.51, b = 0.46, a = 1 }   -- #8F8275, the chat's unselected tab
local THREAT_TICK   = 0.2    -- seconds between redraws while threat events keep coming
local THREAT_EVENTS = { "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE", "PLAYER_TARGET_CHANGED",
    "GROUP_ROSTER_UPDATE", "UNIT_PET", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }

local views = {}                 -- session window -> its threat tab, hit area, list and state
local UpdateThreatViews          -- defined below the list code

-- canaccessvalue first: a secret is never compared, not even with nil
local function Readable(value)
    return canaccessvalue(value) and value ~= nil
end

-- The mob whose threat is shown: a hostile target, or the hostile target of a friendly one
local function IsHostile(unit)
    if not UnitExists(unit) then return false end
    local dead = UnitIsDeadOrGhost(unit)
    if Readable(dead) and dead then return false end
    local attackable = UnitCanAttack("player", unit)
    return Readable(attackable) and attackable
end

local function ThreatMob()
    if IsHostile("target") then return "target" end
    if UnitExists("target") and IsHostile("targettarget") then return "targettarget" end
end

-- The threat list, its entries and the shown rows are reused: they are redrawn up to five times a
-- second in a fight. Each redraw fills them anew before reading them.
-- classOf / isMe: per unit token, until the group or a pet changes (a hidden answer is not kept)
local threatScratch = { list = {}, pool = {}, shown = {}, classOf = {}, isMe = {} }

-- A pet row takes its owner's class colour (a pet's own class belongs to nobody in the group)
local function PetOwner(unit)
    if unit == "pet" then return "player" end
    local n = unit:match("^partypet(%d+)$")
    if n then return "party" .. n end
    n = unit:match("^raidpet(%d+)$")
    if n then return "raid" .. n end
end

local function AddThreat(unit)
    local s = threatScratch
    -- once the client hides a value the whole list is dropped: no need to read the rest
    if s.secret or not UnitExists(unit) then return end
    local tanking, _, scaled, _, value = UnitDetailedThreatSituation(unit, s.mob)
    if not canaccessallvalues(value, scaled, tanking) then s.secret = true; return end
    -- no row for a member with no threat on the mob
    if value == nil or value <= 0 then return end
    local owner = PetOwner(unit)
    local name = UnitName(unit)
    local class = s.classOf[unit]
    if class == nil then
        local _, read = UnitClass(owner or unit)
        if Readable(read) then class = read; s.classOf[unit] = read end
    end
    local isMe = s.isMe[unit]
    if isMe == nil then
        local read = UnitIsUnit(unit, "player")
        if Readable(read) then isMe = read and true or false; s.isMe[unit] = isMe end
    end
    local n = #s.list + 1
    local data = s.pool[n] or {}
    s.pool[n] = data
    data.value, data.scaled = value, scaled or 0
    data.order = n
    data.name = Readable(name) and name or "?"
    data.class = class
    data.isPet = owner ~= nil
    data.isPlayer = isMe or false
    data.tanking = tanking and true or false
    s.list[n] = data
end

-- equal threat keeps the order the group was read in, so rows never swap places between redraws
local function ByThreat(a, b)
    if a.value ~= b.value then return a.value > b.value end
    return a.order < b.order
end

-- Every group member and pet with threat on the mob, highest first. secret = the client hid it.
local function CollectThreat(mob)
    local s = threatScratch
    local list = s.list
    wipe(list)
    s.mob, s.secret = mob, false
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do AddThreat("raid" .. i); AddThreat("raidpet" .. i) end
    else
        AddThreat("player"); AddThreat("pet")
        for i = 1, GetNumSubgroupMembers() do AddThreat("party" .. i); AddThreat("partypet" .. i) end
    end
    table.sort(list, ByThreat)
    for i, data in ipairs(list) do data.rank = i end
    return list, s.secret
end

local function ColorTab(fontString, active)
    local c = active and TITLE_COLOR or TAB_INACTIVE
    fontString:SetTextColor(c.r, c.g, c.b, c.a or 1)
end

local function LayoutTabs(window, view)
    local dd = GetWindowTypeDropdown(window)
    local ref = window.FlareUI_DMSkin or GetWindowHeader(window)
    if not (dd and dd.TypeName and ref) then return end
    local path, size, flags = ns.GetWantedFont(dd.TypeName)
    if path then ns.SetFont(view.tab.Text, path, size, flags) end
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
    -- this runs several times a second in a fight: each setter only when its value changed
    if row.ftHeight ~= height or row.ftSpacing ~= spacing then
        row.ftHeight, row.ftSpacing = height, spacing
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", row:GetParent(), "TOPLEFT", 0, -(index - 1) * (height + spacing))
        row:SetPoint("TOPRIGHT", row:GetParent(), "TOPRIGHT", 0, -(index - 1) * (height + spacing))
        row:SetBarHeight(height)
    end
    local scale = window.GetTextScale and window:GetTextScale() or 1
    if row.ftScale ~= scale then
        row.ftScale = scale
        row:SetTextScale(scale)
        -- the SetTextScale hook has already restyled the font
        if not DamageMeter.FlareUI_EntryHooked then ApplyBarFont(row, db) end
    end
    local icons = window.ShouldShowBarIcons and window:ShouldShowBarIcons() or false
    if row.ftIcons ~= icons then
        row.ftIcons = icons
        row:SetShowBarIcons(icons)
    end
    local style = window.GetStyle and window:GetStyle() or Enum.DamageMeterStyle.Default
    if row.ftStyle ~= style then
        row.ftStyle = style
        row:SetStyle(style)
    end

    local bar = row:GetStatusBar()
    bar:SetMinMaxValues(0, top > 0 and top or 1)
    bar:SetValue(data.value)
    -- Blizzard's colour rule: the class colour when the window asks for it, else the ally colour
    row.classFilename = data.class
    row.sourceDisplayType = Enum.DamageMeterSourceDisplayType and Enum.DamageMeterSourceDisplayType.Ally
    row:SetUseClassColor(window.ShouldUseClassColor and window:ShouldUseClassColor() or false)
    -- a pet shows no class icon: it is not a member of that class
    local iconKey = data.isPet and "pet" or data.class
    if row.ftClass ~= iconKey then
        row.ftClass = iconKey
        local icon = row:GetIcon()
        if data.class and not data.isPet then
            icon:SetAtlas(GetClassAtlas(data.class), false, nil, true)
        else
            icon:SetTexture(nil)
        end
    end
    -- the texts only when what they show changed
    if row.ftRank ~= data.rank or row.ftName ~= data.name then
        row.ftRank, row.ftName = data.rank, data.name
        row:GetName():SetText(("%d. %s"):format(data.rank, data.name))
    end
    -- Tank's Lead: the tank's row shows how far it is ahead of second place, as "+25%"
    local percent = data.lead or math.floor(data.scaled + 0.5)
    local display = db.threatValueDisplay or "percent"
    if row.ftValue ~= data.value or row.ftPercent ~= percent or row.ftLead ~= (data.lead ~= nil) or row.ftDisplay ~= display then
        row.ftValue, row.ftPercent, row.ftLead, row.ftDisplay = data.value, percent, data.lead ~= nil, display
        local pct = (data.lead and "+%d%%" or "%d%%"):format(percent)
        local amount = AbbreviateNumbers(data.value / 100)
        if display == "percent" then
            row:GetValue():SetText(pct)
        elseif display == "value" then
            row:GetValue():SetText(amount)
        else
            row:GetValue():SetText(amount .. "  " .. pct)
        end
    end
    -- Pull Warning: your bar flashes as you near the point where you pull the mob
    if data.warn then
        if not row.FlareUI_Flash then
            local flash = bar:CreateTexture(nil, "OVERLAY", nil, 6)
            flash:SetAllPoints(bar)
            flash:SetColorTexture(1, 0.15, 0.1, 1)
            flash:SetBlendMode("ADD")
            flash:SetAlpha(0)
            local anim = flash:CreateAnimationGroup()
            anim:SetLooping("BOUNCE")
            local fade = anim:CreateAnimation("Alpha")
            fade:SetFromAlpha(0)
            fade:SetToAlpha(0.55)
            fade:SetDuration(0.4)
            fade:SetSmoothing("IN_OUT")
            flash.anim = anim
            row.FlareUI_Flash = flash
        end
        if not row.FlareUI_Flash.anim:IsPlaying() then row.FlareUI_Flash.anim:Play() end
    elseif row.FlareUI_Flash and row.FlareUI_Flash.anim:IsPlaying() then
        row.FlareUI_Flash.anim:Stop()
        row.FlareUI_Flash:SetAlpha(0)
    end
    row:Show()
end

-- Settings > Damage Meter open with no enemy targeted: sample rows, so the Threat tab's options can
-- be seen. A tank, you closing in on the pull line, and two more.
local PULL_WARN = 85   -- Pull Warning starts here (100 = you pull the mob)

local function SampleThreat()
    local s = threatScratch
    wipe(s.list)
    local names = LOCALIZED_CLASS_NAMES_MALE or {}
    local me = UnitName("player")
    local _, myClass = UnitClass("player")
    local samples = {
        { names.WARRIOR or "Warrior", "WARRIOR", 1000000, 100, true },
        { Readable(me) and me or "?", Readable(myClass) and myClass or nil, 960000, 87, false, true },
        { names.MAGE or "Mage", "MAGE", 720000, 55 },
        { names.PRIEST or "Priest", "PRIEST", 310000, 22 },
    }
    for n, sample in ipairs(samples) do
        local data = s.pool[n] or {}
        s.pool[n] = data
        data.name, data.class, data.value, data.scaled = sample[1], sample[2], sample[3], sample[4]
        data.tanking, data.isPlayer, data.isPet = sample[5] or false, sample[6] or false, false
        data.order, data.rank = n, n
        s.list[n] = data
    end
    return s.list
end

local function UpdateThreatView(window, view)
    local db = GetDb()
    if not db then return end
    local frame = view.frame
    local height = window.GetBarHeight and window:GetBarHeight() or 24
    local spacing = window.GetBarSpacing and window:GetBarSpacing() or 2
    local capacity = math_max(1, math.floor((frame:GetHeight() + spacing) / (height + spacing)))

    local list, message = threatScratch.list, nil
    local mob = ThreatMob()
    if not mob and DamageMeter.settingsPreview then
        threatScratch.mob = nil
        list = SampleThreat()
    elseif not mob then
        wipe(list)
        threatScratch.mob = nil
        message = L["No hostile target"]
    else
        local secret
        list, secret = CollectThreat(mob)
        if secret then
            message = L["Threat is hidden here"]
            wipe(list)
        elseif #list == 0 then
            message = L["No threat yet"]
        end
    end

    -- the tank's lead, your pull point and the warning
    local tank, second, me
    for _, data in ipairs(list) do
        data.lead, data.warn = nil, nil
        if data.tanking and not tank then
            tank = data
        elseif not second then
            second = data
        end
        if data.isPlayer then me = data end
    end
    if db.threatTankLead and tank and second and second.value > 0 then
        tank.lead = math_max(0, math.floor((tank.value / second.value - 1) * 100 + 0.5))
    end
    -- the scaled percent is your threat against the point you pull at (110% of the tank's in melee,
    -- 130% at range), so that point is your threat over it
    local pull
    if me and not me.tanking and me.scaled > 0 then
        pull = me.value * 100 / me.scaled
        if db.threatPullFlash and me.scaled >= PULL_WARN then me.warn = true end
    end
    local top = list[1] and list[1].value or 0
    local showPull = db.threatPullLine and pull and true or false
    if showPull and pull > top then top = pull end

    -- the mouse wheel scrolls a list longer than the window; at the top, past capacity, the last row
    -- shows the player
    local offset = math_max(0, math_min(view.offset or 0, #list - capacity))
    view.offset = offset
    local shown = threatScratch.shown
    wipe(shown)
    for i = 1, math_min(#list - offset, capacity) do shown[i] = list[offset + i] end
    if offset == 0 and #list > capacity then
        local inView = false
        for i = 1, capacity do if shown[i].isPlayer then inView = true end end
        if not inView then
            for i = capacity + 1, #list do
                if list[i].isPlayer then shown[capacity] = list[i] end
            end
        end
    end

    for i, data in ipairs(shown) do FillRow(GetRow(view, i), data, top, window, db, i, height, spacing) end
    for i = #shown + 1, #view.rows do view.rows[i]:Hide() end

    -- Pull Aggro Line: across the shown bars, where you would pull the mob
    local line = view.pullLine
    if showPull and #shown > 0 then
        local firstBar = view.rows[1]:GetStatusBar()
        local lastBar = view.rows[#shown]:GetStatusBar()
        local width = firstBar:GetWidth()
        if width and width > 0 then
            view.lineRetry = nil
            line:ClearAllPoints()
            line:SetPoint("TOP", firstBar, "TOPLEFT", width * pull / top, 1)
            line:SetPoint("BOTTOM", lastBar, "BOTTOMLEFT", width * pull / top, -1)
            line:Show()
        else
            -- a new row has no size yet: placed a frame later (once; a meter that never gets a size
            -- would otherwise redraw every frame)
            line:Hide()
            if not view.lineRetry then
                view.lineRetry = true
                C_Timer.After(0, function() if view.showing then SafeCall(UpdateThreatView, window, view) end end)
            end
        end
    elseif line then
        line:Hide()
    end
    frame.Empty:SetText(message or "")
    frame.Empty:SetShown(message ~= nil)
end

-- Threat events arrive in bursts: the list is redrawn at most every THREAT_TICK
local threatDriver = CreateFrame("Frame")
local threatDirty, threatElapsed, threatWatching = false, 0, false
local threatSafety = 0
threatDriver:Hide()   -- runs only while a Threat tab is up; see WatchThreat

-- The group's own units: their threat situation is the only one that matters here
local GROUP_TOKENS = { player = true, pet = true }
for i = 1, 4 do GROUP_TOKENS["party" .. i] = true; GROUP_TOKENS["partypet" .. i] = true end
for i = 1, 40 do GROUP_TOKENS["raid" .. i] = true; GROUP_TOKENS["raidpet" .. i] = true end

-- In a raid threat events come for every mob and member nearby: only the shown mob's list and the
-- group's own situation mark the list for a redraw
threatDriver:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_THREAT_LIST_UPDATE" then
        local mob = threatScratch.mob
        if not (mob and unit) then return end
        local same = UnitIsUnit(unit, mob)
        if canaccessvalue(same) and not same then return end
    elseif event == "UNIT_THREAT_SITUATION_UPDATE" then
        if not GROUP_TOKENS[unit] then return end
    elseif event == "GROUP_ROSTER_UPDATE" or event == "UNIT_PET" then
        wipe(threatScratch.classOf)
        wipe(threatScratch.isMe)
    end
    threatDirty = true
end)
threatDriver:SetScript("OnUpdate", function(self, elapsed)
    threatElapsed = threatElapsed + elapsed
    if threatElapsed < THREAT_TICK then return end
    -- a list skipped while nobody could see it is redrawn as soon as it can be seen again
    if self.stale then UpdateThreatViews(true) end
    threatSafety = threatSafety + threatElapsed
    threatElapsed = 0
    -- a mob that is only your target's target (no nameplate, no boss frame) sends no threat event
    -- of its own: in a fight its list is redrawn twice a second anyway
    if threatSafety >= 0.5 then
        threatSafety = 0
        if not threatDirty and InCombatLockdown() and ThreatMob() == "targettarget" then threatDirty = true end
    end
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
    -- the group may have changed while no tab listened
    wipe(threatScratch.classOf)
    wipe(threatScratch.isMe)
    for _, event in ipairs(THREAT_EVENTS) do
        if any then threatDriver:RegisterEvent(event) else threatDriver:UnregisterEvent(event) end
    end
    -- only the target's target matters (the target-of-target fallback), not every raid member's
    if any then threatDriver:RegisterUnitEvent("UNIT_TARGET", "target") else threatDriver:UnregisterEvent("UNIT_TARGET") end
    threatDriver:SetShown(any)
end

-- Whether the list can be seen: shown, and the meter (the session windows' parent) not faded to
-- nothing (Show on Mouseover, the end of a fade out)
local function ViewSeen(view)
    if not view.frame:IsVisible() then return false end
    local meter = _G.DamageMeter
    if not meter then return true end
    local alpha = meter:GetAlpha()
    return not (canaccessvalue(alpha) and alpha <= 0)
end

-- A list nobody can see is not redrawn, only marked stale; staleOnly redraws just those once seen
function UpdateThreatViews(staleOnly)
    threatDriver.stale = nil
    for window, view in pairs(views) do
        if view.showing and (view.stale or not staleOnly) then
            if ViewSeen(view) then
                view.stale = nil
                SafeCall(UpdateThreatView, window, view)
            else
                view.stale = true
                threatDriver.stale = true
            end
        end
    end
end

local function SetView(window, showThreat)
    local view = views[window]
    if not view then return end
    view.showing = showThreat and true or false
    view.frame:SetShown(view.showing)
    SetBlizzardListShown(window, not view.showing)
    LayoutTabs(window, view)
    if view.showing then
        view.stale = nil
        UpdateThreatView(window, view)
    end
    WatchThreat()
end

-- The player's pick is kept in the profile; only Threat View in Combat switches on its own, and
-- goes back to the pick after the fight.
local function ThreatPicked()
    local db = GetDb()
    return db and db.threatView and true or false
end

local function PickView(window, showThreat)
    local db = GetDb()
    if db then db.threatView = showThreat and true or nil end
    SetView(window, showThreat)
end

-- Settings: a changed Threat option shows the Threat tab (with sample rows when nothing is targeted)
-- until the page closes; the player's own pick is not changed
function DamageMeter.PreviewThreat()
    if not DamageMeter.settingsPreview then return end
    DamageMeter.threatPreviewing = true
    for window, view in pairs(views) do
        if view.showing then SafeCall(UpdateThreatView, window, view) else SetView(window, true) end
    end
end

function DamageMeter.EndThreatPreview()
    if not DamageMeter.threatPreviewing then return end
    DamageMeter.threatPreviewing = nil
    local threat = ThreatPicked()
    for window in pairs(views) do SetView(window, threat) end
end

function DamageMeter.RedrawThreat()
    for window, view in pairs(views) do
        if view.showing then SafeCall(UpdateThreatView, window, view) end
    end
end

-- The toggle flips every window from what is on screen, not from the saved pick
local function ToggleThreatViews()
    local showing = false
    for _, view in pairs(views) do if view.showing then showing = true end end
    for window in pairs(views) do PickView(window, not showing) end
end

-- The radial menu's "Toggle Threat Meter" runs this
function FlareUI_ToggleThreatMeter()
    if next(views) then
        ToggleThreatViews()
    else
        print("|cff00ff00FlareUI:|r " .. L["turn on the Damage Meter in the FlareUI settings (and Blizzard's damage meter) to use the threat view."])
    end
end

local function CreateThreatView(window)
    local dd = GetWindowTypeDropdown(window)
    local scrollBox = GetWindowScrollBox(window)
    if not (dd and dd.TypeName and scrollBox) then return nil end
    local view = { rows = {}, showing = ThreatPicked() }

    -- over Blizzard's title: left-click picks its tab, right-click reaches Blizzard's menu
    local hit = CreateFrame("Button", nil, window)
    hit:SetAllPoints(dd)
    hit:SetFrameLevel(dd:GetFrameLevel() + 2)
    hit:RegisterForClicks("LeftButtonUp")
    hit:SetPassThroughButtons("RightButton")
    hit:SetScript("OnClick", function() PickView(window, false) end)
    view.hit = hit

    local tab = CreateFrame("Button", nil, window)
    tab:SetFrameLevel(dd:GetFrameLevel() + 3)
    tab.Text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tab.Text:SetPoint("LEFT", tab, "LEFT", 4, 0)
    tab.Text:SetText(L["Threat"])
    tab:RegisterForClicks("LeftButtonUp")
    tab:SetScript("OnClick", function() PickView(window, true) end)
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
    -- a list longer than the window scrolls a row per notch
    frame:SetScript("OnMouseWheel", function(_, delta)
        local offset = math_max(0, (view.offset or 0) - delta)
        if offset == (view.offset or 0) then return end
        view.offset = offset
        SafeCall(UpdateThreatView, window, view)
    end)
    frame.Empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.Empty:SetPoint("CENTER")
    frame:Hide()
    view.frame = frame

    -- Pull Aggro Line, over the rows
    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(frame:GetFrameLevel() + 30)
    local line = overlay:CreateTexture(nil, "OVERLAY", nil, 7)
    line:SetColorTexture(1, 0.2, 0.15, 0.95)
    line:SetWidth(2)
    line:Hide()
    view.pullLine = line

    -- a new meter type renames the title: the Threat tab follows the new width
    hooksecurefunc(dd.TypeName, "SetText", function() LayoutTabs(window, view) end)

    views[window] = view
    return view
end

--------------------------------------------------
-- 17. LIVE COMBAT TIMER
-- Blizzard's session timer only moves every two seconds or so, so in a fight FlareUI shows each
-- window's segment length in its place, read from the meter itself (it matches the bars, follows
-- Overall, survives a /reload). It keeps running while your group fights on after you die. A past
-- fight keeps Blizzard's timer, which shows that fight's fixed length.
--------------------------------------------------
local liveTimers = {}            -- session window -> FlareUI's timer text
local combatStart
local timerDriver = CreateFrame("Frame")
timerDriver:Hide()
local timerElapsed = 0

-- The length of the segment the window shows, or nil for a past fight (or a hidden value)
local function LiveSeconds(window)
    if window.GetSessionID and window:GetSessionID() ~= nil then return nil end
    local kind = window.GetSessionType and window:GetSessionType()
    if kind == nil then return nil end
    if C_DamageMeter and C_DamageMeter.GetSessionDurationSeconds then
        local ok, seconds = pcall(C_DamageMeter.GetSessionDurationSeconds, kind)
        if ok and canaccessvalue(seconds) and type(seconds) == "number" then return math.floor(seconds) end
    end
    -- fallback: FlareUI's own count, for the current fight only
    if kind == Enum.DamageMeterSessionType.Current and combatStart then return math.floor(GetTime() - combatStart) end
end

-- You, or anyone in your group, still in a fight
local function GroupInCombat()
    local mine = UnitAffectingCombat("player")
    if canaccessvalue(mine) and mine then return true end
    if not IsInGroup() then return false end
    local prefix, count = "party", GetNumSubgroupMembers()
    if IsInRaid() then prefix, count = "raid", GetNumGroupMembers() end
    for i = 1, count do
        local fighting = UnitAffectingCombat(prefix .. i)
        if canaccessvalue(fighting) and fighting then return true end
    end
    return false
end

local UpdateLiveTimers

-- Each window's text, when its second changed; Blizzard's timer shows where FlareUI's has nothing
local function PaintLiveTimers()
    for window, fs in pairs(liveTimers) do
        local seconds = LiveSeconds(window)
        if seconds ~= fs.FlareUI_Second then
            fs.FlareUI_Second = seconds
            if seconds then fs:SetText(("[%s] "):format(SecondsToClock(seconds))) end
            fs:SetShown(seconds ~= nil)
            local blizzard = GetWindowSessionTimer(window)
            if blizzard then blizzard:SetAlpha(seconds and 0 or 1) end
        end
    end
end

timerDriver:SetScript("OnUpdate", function(_, elapsed)
    timerElapsed = timerElapsed + elapsed
    if timerElapsed < 0.1 then return end
    timerElapsed = 0
    -- after your own fight ends, the group's fight keeps the clock going
    if not combatStart and not GroupInCombat() then
        UpdateLiveTimers()
        return
    end
    PaintLiveTimers()
end)

function UpdateLiveTimers()
    local db = GetDb()
    local live = db and db.enabled and db.combatTimer and (combatStart ~= nil or GroupInCombat())
    for window, fs in pairs(liveTimers) do
        fs.FlareUI_Second = false   -- repaint
        if not live then
            fs:Hide()
            local blizzard = GetWindowSessionTimer(window)
            if blizzard then blizzard:SetAlpha(1) end
        end
    end
    timerElapsed = 1
    timerDriver:SetShown(live and true or false)
    if live then PaintLiveTimers() end
end

-- registered in Init
local timerEvents = CreateFrame("Frame")
timerEvents:SetScript("OnEvent", function(_, event)
    combatStart = event == "PLAYER_REGEN_DISABLED" and GetTime() or nil
    UpdateLiveTimers()
    -- Threat View in Combat. After a fight a fading meter switches back only once faded (no flash of
    -- damage bars)
    local db = GetDb()
    if not (db and db.enabled and db.autoThreat) then return end
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

-- after a fight (Threat View in Combat): back to the player's pick
function DamageMeter.ShowDamageViews()
    DamageMeter.viewBackPending = nil
    local threat = ThreatPicked()
    for window in pairs(views) do SetView(window, threat) end
end

local function ApplyLiveTimer(window)
    local blizzard = GetWindowSessionTimer(window)
    if not blizzard then return end
    local fs = liveTimers[window]
    if not fs then
        fs = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetJustifyH("RIGHT")
        liveTimers[window] = fs
    end
    local path, size, flags = ns.GetWantedFont(blizzard)
    if path then ns.SetFont(fs, path, size, flags) end
    fs:SetShadowOffset(blizzard:GetShadowOffset())
    fs:SetShadowColor(blizzard:GetShadowColor())
    fs:SetTextColor(TITLE_COLOR.r, TITLE_COLOR.g, TITLE_COLOR.b, TITLE_COLOR.a or 1)
    fs:ClearAllPoints()
    fs:SetPoint("RIGHT", blizzard, "RIGHT", 0, 0)
    local inCombat = UnitAffectingCombat("player")
    if canaccessvalue(inCombat) and inCombat and not combatStart then combatStart = GetTime() end
    UpdateLiveTimers()
end

local function ApplyThreatTab(window)
    local dd = GetWindowTypeDropdown(window)
    if not dd then return end
    local view = views[window] or CreateThreatView(window)
    if not view then return end
    dd:RegisterForMouse("LeftButtonDown", "LeftButtonUp", "RightButtonDown", "RightButtonUp")
    local skin = window.FlareUI_DMSkin or window
    view.frame:ClearAllPoints()
    view.frame:SetPoint("TOPLEFT", skin, "TOPLEFT", 6, -CONTENT_TOP)
    view.frame:SetPoint("BOTTOMRIGHT", skin, "BOTTOMRIGHT", -6, 6)
    -- a changed bar font: FillRow only restyles a row when the text scale changes
    local db = GetDb()
    if db then
        for _, row in ipairs(view.rows) do ApplyBarFont(row, db) end
    end
    SetView(window, view.showing)
end

--------------------------------------------------
-- 18. APPLY TO SINGLE WINDOW
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
    SafeCall(ApplyScrollBarVisibility, window)
    SafeCall(ApplyHeaderFonts, window)
    SafeCall(ApplyHeaderButtonStyle, window)
    SafeCall(ApplyThreatTab, window)
    SafeCall(ApplyLiveTimer, window)

    local sb = GetWindowScrollBox(window)
    if sb then
        SafeCall(ApplyFontsToScrollBox, sb, db)
    end
    local localPlayerEntry = (window.GetLocalPlayerEntry and window:GetLocalPlayerEntry()) or window.LocalPlayerEntry
    if localPlayerEntry then
        HookEntry(localPlayerEntry)
        SafeCall(ApplyBarFont, localPlayerEntry, db)
    end

    local sw = GetWindowSourceWindow(window)
    local swScrollBox = sw and ((sw.GetScrollBox and sw:GetScrollBox()) or sw.ScrollBox)
    if swScrollBox then
        SafeCall(ApplyFontsToScrollBox, swScrollBox, db)
    end
end

--------------------------------------------------
-- 19. MATCH CHAT FRAME SIZE
-- Blizzard's DamageMeter frame takes the chat skin's size, again after every Edit Mode sizing and
-- every chat resize. FlareUI's chat only; out of combat only. With Meter Tab in the Chat it also
-- takes its place: the window inside the chat skin, under the chat's tab row.
--------------------------------------------------
local matchSizing = false

local function ChatSizeSource()
    local chat = _G.ChatFrame1
    return chat and (chat.FlareUI_Skin or chat)
end

local function ChatSkin()
    local chat = _G.ChatFrame1
    return chat and chat.FlareUI_Skin
end

local function ChatModuleOn()
    local chat = ns.db and ns.db.profile and ns.db.profile.chat
    return chat ~= nil and chat.enabled == true
end

-- Meter Tab in the Chat: both modules on, the main chat window skinned. Not in the Gamepad UI, where
-- the meter keeps its own place
function ChatTabOn()
    local db = GetDb()
    if ns.IsGamepadUI() then return false end
    return (db ~= nil and db.enabled and db.chatTab and ChatModuleOn() and ChatSkin() ~= nil) and true or false
end

local MatchChatSize
local function MatchChatSizeBody()
    local db = GetDb()
    local meter = _G.DamageMeter
    local inChat = ChatTabOn()
    if matchSizing or not (db and db.enabled and (db.matchChatSize or inChat) and meter) or InCombatLockdown() then return end
    if not ChatModuleOn() then return end
    local source = inChat and ChatSkin() or ChatSizeSource()
    if not source then return end
    local width, height = source:GetSize()
    -- the meter's own skin reaches SKIN_PADDING past the window on every side: the window is that much
    -- smaller, so the skin is the chat skin's size. In the chat it also sits under the chat's tab row.
    width, height = width - 2 * SKIN_PADDING, height - 2 * SKIN_PADDING
    if inChat then height = height - CHAT_TAB_ROW end
    if not (width and height and width > 0 and height > 0) then return end
    matchSizing = true
    meter:SetSize(width, height)
    -- not while Edit Mode is open: the meter is dragged there, and keeps its own place for the tab off
    if inChat and not IsEditModeActive() then
        -- Edit Mode wraps SetPoint / ClearAllPoints on its frames: the base setters, when it keeps
        -- them, place the frame without telling Edit Mode about a position change
        local clear = meter.ClearAllPointsBase or meter.ClearAllPoints
        local set = meter.SetPointBase or meter.SetPoint
        clear(meter)
        set(meter, "TOPLEFT", source, "TOPLEFT", SKIN_PADDING, -(CHAT_TAB_ROW + SKIN_PADDING))
        DamageMeter.chatAnchored = true
    end
    matchSizing = false
end

-- an error inside (reported) must not leave the guard up
function MatchChatSize()
    if not SafeCall(MatchChatSizeBody) then matchSizing = false end
end

local function HookChatSize()
    local meter, source = _G.DamageMeter, ChatSizeSource()
    if not (meter and source) then return end
    if not meter.FlareUI_SizeHooked then
        meter.FlareUI_SizeHooked = true
        hooksecurefunc(meter, "SetSize", MatchChatSize)
        -- Edit Mode re-anchors the meter (its layouts at login, a layout change), by SetPoint or by
        -- the base setter it keeps: back into the chat a frame later, once every point Blizzard sets is in
        local pending = false
        local function Reanchor()
            if pending or matchSizing or IsEditModeActive() or not ChatTabOn() then return end
            pending = true
            C_Timer.After(0, function()
                pending = false
                MatchChatSize()
            end)
        end
        hooksecurefunc(meter, "SetPoint", Reanchor)
        if type(meter.SetPointBase) == "function" then hooksecurefunc(meter, "SetPointBase", Reanchor) end
    end
    -- the chat's skin arrives with the Chat module, after ChatFrame1 itself
    if not source.FlareUI_DMSizeHooked then
        source.FlareUI_DMSizeHooked = true
        source:HookScript("OnSizeChanged", MatchChatSize)
    end
end

-- Switched off: Edit Mode's own Frame Width / Height again
function DamageMeter:RestoreEditModeSize()
    local meter = _G.DamageMeter
    if not meter or InCombatLockdown() or type(meter.GetSettingValue) ~= "function" then return end
    -- the size Edit Mode has saved, read and set from here: Blizzard's own setters stay out of addon code
    local setting = Enum.EditModeDamageMeterSetting
    local width, height = meter:GetSettingValue(setting.FrameWidth), meter:GetSettingValue(setting.FrameHeight)
    if width and height and width > 0 and height > 0 then meter:SetSize(width, height) end
end

-- Out of the chat (Meter Tab in the Chat off): the place Edit Mode has saved, read and set from here
-- like the size above
function DamageMeter:RestoreEditModeAnchor()
    local meter = _G.DamageMeter
    if not (meter and self.chatAnchored) or InCombatLockdown() then return end
    local info = meter.systemInfo and meter.systemInfo.anchorInfo
    if not (info and info.point) then return end   -- Edit Mode's next layout puts it back
    self.chatAnchored = nil
    local clear, set = meter.ClearAllPointsBase or meter.ClearAllPoints, meter.SetPointBase or meter.SetPoint
    clear(meter)
    set(meter, info.point, info.relativeTo, info.relativePoint, info.offsetX, info.offsetY)
end

--------------------------------------------------
-- 20. REFRESH ALL
--------------------------------------------------
function DamageMeter:Refresh()
    if InCombatLockdown() then
        self._pendingRefresh = true
        return
    end

    local db = GetDb()
    if not db or not db.enabled then return end
    self:SetupMouseover()
    -- several events can ask in the same frame: one pass now, and one more a frame later for what
    -- the rest brought (at login the loading screen holds every timer, then lands them all in one
    -- frame: the chat's skin arrives there after the first pass)
    local now = GetTime()
    if self._lastRefresh == now then
        if not self._refreshQueued then
            self._refreshQueued = true
            C_Timer.After(0, function()
                self._refreshQueued = nil
                self:Refresh()
            end)
        end
        return
    end
    self._lastRefresh = now

    barFontPass = barFontPass + 1   -- every row takes the bar font again
    for _, window in ipairs(GetSessionWindows()) do
        self:ApplyToWindow(window)
    end
    HookChatSize()
    local inChat = ChatTabOn()
    if db.matchChatSize or inChat then
        MatchChatSize()
        self.sizeMatched = true
    elseif self.sizeMatched then
        self.sizeMatched = nil
        self:RestoreEditModeSize()
    end
    -- Meter Tab in the Chat switched on or off: the visibility rules change hands (ApplyVisibility)
    if (inChat and MeterAllowed()) ~= (self.chatTabApplied or false) then self:ApplyVisibility() end
    -- the chat draws or drops its Meter tab (Blizzard's switch may have changed too)
    if ns.Chat and ns.Chat.RefreshMeterTab then SafeCall(ns.Chat.RefreshMeterTab, ns.Chat) end

    self._pendingRefresh = false
end

--------------------------------------------------
-- 21. EVENT HANDLERS
--------------------------------------------------
function DamageMeter:PLAYER_REGEN_ENABLED()
    if self.chatTabLeavePending then self:LeaveChatTab() end
    if self._pendingRefresh then
        C_Timer.After(0, function() self:Refresh() end)
    end
end

function DamageMeter:EDIT_MODE_LAYOUTS_UPDATED()
    C_Timer.After(0.25, function() self:Refresh() end)
end

function DamageMeter:ADDON_LOADED(event, addonName)
    if addonName == "Blizzard_DamageMeter" then
        HookEntryFonts()
        C_Timer.After(0, function() self:Refresh() end)
        C_Timer.After(0.5, function() self:Refresh() end)
    end
end

function DamageMeter:PLAYER_ENTERING_WORLD(_, _, isReload)
    C_Timer.After(0.5, function() self:Refresh() end)
    C_Timer.After(2, function() self:CheckInstanceReset(isReload) end)   -- once the zone has settled
end

-- Reset on Entering a Dungeon: a new dungeon or raid clears the meter. Coming back into the same one
-- (a ghost run, a hearth back in, a relog) keeps it, unless you were away more than ten minutes; a
-- /reload never clears it. The dungeon is kept with the character, so it outlives a reload or relog.
local INSTANCE_AWAY = 600

local function CurrentInstance()
    local inInstance, kind = IsInInstance()
    return inInstance and (kind == "party" or kind == "raid") and select(8, GetInstanceInfo()) or nil
end

-- every loading screen (zoning out, a logout, a reload) stamps when you left the remembered dungeon
function DamageMeter:PLAYER_LEAVING_WORLD()
    local saved = ns.CharDB()
    local id = CurrentInstance()
    if id and id == saved.meterInstance then saved.meterLeftAt = time() end
end

function DamageMeter:CheckInstanceReset(isReload)
    local saved = ns.CharDB()
    local instanceID = CurrentInstance()
    if not instanceID then
        if saved.meterInstance and not saved.meterLeftAt then saved.meterLeftAt = time() end
        return
    end
    local away = saved.meterLeftAt and time() - saved.meterLeftAt > INSTANCE_AWAY
    local isNew = instanceID ~= saved.meterInstance or away
    saved.meterLeftAt = nil
    if not isNew then return end
    saved.meterInstance = instanceID
    if isReload then return end
    local db = GetDb()
    if not (db and db.enabled and db.resetOnInstance) then return end
    if C_DamageMeter and C_DamageMeter.ResetAllCombatSessions then pcall(C_DamageMeter.ResetAllCombatSessions) end
end

--------------------------------------------------
-- 22. VISIBILITY AND SHOW ON MOUSEOVER (Settings > Damage Meter)
-- Applied after each of Blizzard's checks, overruling the Edit Mode dropdown (preset layouts cannot
-- save it). Show on Mouseover keeps a hidden meter up at alpha 0 until hovered. One driver fades the
-- alpha at the Fade Speed and hides the meter after a fade out.
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

-- runs every frame under Show on Mouseover, so the window callback is made once
local mouseOverWindow = false
local function CheckWindowMouse(window) if window:IsMouseOver() then mouseOverWindow = true end end

local function MeterUnderMouse(meter)
    if meter:IsMouseOver() then return true end
    mouseOverWindow = false
    if type(meter.ForEachSessionWindow) == "function" then
        meter:ForEachSessionWindow(CheckWindowMouse)
    end
    return mouseOverWindow
end

-- The bags or the world map (Forever's quest log) open over the meter's place: no reveal then
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

-- Shown only out of a fight (see InFight), FlareUI's rule re-applied after it.
local showPending = false

local function ShowMeter(meter)
    if meter:IsShown() then return true end
    if InFight() then
        showPending = true
        return false
    end
    meter:Show()
    return true
end

local showRetry = CreateFrame("Frame")
showRetry:RegisterEvent("PLAYER_REGEN_ENABLED")
showRetry:SetScript("OnEvent", function()
    if not showPending then return end
    showPending = false
    -- a moment after the fight, once the session's values are readable again
    C_Timer.After(0.5, function() DamageMeter:ApplyVisibility() end)
end)

-- Min Alpha: how far the meter fades out (0 = gone). Not for the Meter tab in the chat, where the
-- tab decides and a faded meter sits under the chat.
local function DownAlpha()
    local db = GetDb()
    local v = db and tonumber(db.minAlpha) or 0
    return math_max(0, math_min(0.9, v))
end

local function FadeStep(self, meter, elapsed)
    -- at rest under Show on Mouseover it stays on watch: a check every 0.1 s is enough (the bags and
    -- map are only looked at once the pointer is over the meter)
    self.restWait = (self.restWait or 0) + elapsed
    if self.atRest and self.restWait < 0.1 then return end
    elapsed = self.restWait
    self.restWait = 0
    local target = fadeTarget
    if meter.FlareUI_MouseHidden then target = (MeterUnderMouse(meter) and not PanelsInTheWay()) and 1 or DownAlpha() end
    local db = GetDb()
    local time = ns.FadeTime(db and db.fadeSpeed)
    local alpha = meter:GetAlpha()
    if time <= 0 then
        alpha = target
    elseif alpha < target then
        alpha = math_min(target, alpha + elapsed / time)
    else
        alpha = math_max(target, alpha - elapsed / time)
    end
    self.atRest = alpha == target and meter:GetAlpha() == target
    if not self.atRest then meter:SetAlpha(alpha) end
    if alpha ~= target then return end
    if target < 1 and DamageMeter.viewBackPending then DamageMeter.ShowDamageViews() end
    if hideWhenFaded and target == 0 then
        hideWhenFaded = false
        local wasApplying = applying
        applying = true
        meter:Hide()
        applying = wasApplying
    end
    -- on a chat tab (Meter Tab in the Chat): faded out, it drops under the chat, which gets the mouse
    if target == 0 and not DamageMeter.chatTabActive and DamageMeter.chatTabApplied then ApplyChatTabStrata(meter, false) end
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
    return fadeTarget < 1
end

-- Fades toward target (hide: once at 0); the first step runs now, so an instant change lands first
local function FadeMeter(meter, target, hide)
    fadeTarget, hideWhenFaded = target, hide and true or false
    fadeDriver:Show()
    FadeStep(fadeDriver, meter, 0)
end

-- Blizzard's switch for the meter is on and the meter can be used here
function MeterAllowed()
    if C_CVar.GetCVarBool and not C_CVar.GetCVarBool("damageMeterEnabled") then return false end
    if C_DamageMeter and C_DamageMeter.IsDamageMeterAvailable and not C_DamageMeter.IsDamageMeterAvailable() then return false end
    return true
end

local function ApplyVisibilityBody(meter)
    local db = GetDb()
    if applying or not (db and db.enabled) then return end
    applying = true
    -- in the chat the tab decides (Blizzard's switch off: hidden below, as ever). Switching in or
    -- out of the chat is noted here, whichever check brings it: Refresh, a click, Blizzard's own
    local inChat = ChatTabOn() and MeterAllowed()
    if inChat ~= (DamageMeter.chatTabApplied or false) then
        DamageMeter.chatTabApplied = inChat or nil
        if not inChat then DamageMeter:LeaveChatTab() end
        -- the chat draws or drops its tab; a frame later, as this can be Blizzard's own check
        if ns.Chat and ns.Chat.RefreshMeterTab then C_Timer.After(0, function() ns.Chat:RefreshMeterTab() end) end
    end
    if inChat then
        ApplyChatTab(meter, db)
        applying = false
        return
    end
    -- whether the meter was up (shown, not faded out) before Blizzard's check: a fade starts from there
    local wasUp = meter.FlareUI_Up
    -- Edit Mode open: always up, its "Damage Meter" box ticked or not; Blizzard's switch off stays off
    local editing = (type(meter.IsEditing) == "function" and meter:IsEditing()) or (IsEditModeActive() and MeterAllowed())
    meter.FlareUI_MouseHidden = nil
    if editing or DamageMeter.settingsPreview then
        -- a fade under way (or Show on Mouseover's driver) would take it down again
        fadeTarget, hideWhenFaded = 1, false
        fadeDriver:Hide()
        ShowMeter(meter)
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
        -- held back in a fight (ShowMeter): it stays down, and comes up with its fade after it
        local shown = ShowMeter(meter)
        meter.FlareUI_Up = shown
        if shown then FadeMeter(meter, 1) end
    elseif db.showOnMouseover then
        if not wasUp and not meter:IsShown() then meter:SetAlpha(0) end
        if ShowMeter(meter) then
            meter.FlareUI_MouseHidden = true
            FadeMeter(meter, DownAlpha())
        end
        meter.FlareUI_Up = false
    elseif DownAlpha() > 0 then
        -- Min Alpha: faded, not gone (held back in a fight like any show, ShowMeter)
        meter.FlareUI_Up = false
        if not wasUp and not meter:IsShown() then meter:SetAlpha(0) end
        if ShowMeter(meter) then FadeMeter(meter, DownAlpha()) end
    elseif wasUp then
        -- it was up: on screen for its fade out, hidden at the end (already hidden: nothing to fade)
        meter.FlareUI_Up = false
        if meter:IsShown() then
            FadeMeter(meter, 0, true)
        else
            hideWhenFaded = false
        end
    else
        hideWhenFaded = false
        meter:Hide()
    end
    applying = false
end

-- an error inside (reported) must not leave the guard up: every later check would be skipped
local function ApplyVisibility(meter)
    local ok, err = pcall(ApplyVisibilityBody, meter)
    if not ok then
        applying = false
        geterrorhandler()(err)
    end
end

function DamageMeter:SetupMouseover()
    local meter = _G.DamageMeter
    if not meter or self.mouseoverHooked or type(meter.UpdateShownState) ~= "function" then return end
    self.mouseoverHooked = true
    hooksecurefunc(meter, "UpdateShownState", ApplyVisibility)
    -- a window opened from Blizzard's settings menu gets the skin too
    if type(meter.SetupSessionWindow) == "function" then
        hooksecurefunc(meter, "SetupSessionWindow", function()
            C_Timer.After(0, function() DamageMeter:Refresh() end)
        end)
    end
    -- Blizzard re-checks the meter on entering Edit Mode only when its "Damage Meter" box is ticked
    EventRegistry:RegisterCallback("EditMode.Enter", function() DamageMeter:ApplyVisibility() end, DamageMeter)
    EventRegistry:RegisterCallback("EditMode.Exit", function() C_Timer.After(0, function() DamageMeter:ApplyVisibility() end) end, DamageMeter)
    DamageMeter:ApplyVisibility()
end

-- Blizzard's verdict, then FlareUI's. Never meter:UpdateShownState() from here: run by addon code it
-- taints the session timer, and Blizzard's next combat check trips over the secret fight length.
function DamageMeter:ApplyVisibility()
    local meter = _G.DamageMeter
    if not meter then return end
    -- in the chat the tab decides, not Blizzard's verdict (the meter is never hidden there)
    if not self:ChatTabAvailable() and not InCombatLockdown() and type(meter.ShouldBeShown) == "function" then
        local ok, should = pcall(meter.ShouldBeShown, meter)
        if ok and (not should or not InFight()) then meter:SetShown(should and true or false) end
    end
    ApplyVisibility(meter)
end

--------------------------------------------------
-- 23. METER TAB IN THE CHAT (Settings > Damage Meter)
-- The meter as a tab of FlareUI's chat: in the main chat window under its tab row (MatchChatSize),
-- its own skin clear over the chat's. The tab sets its alpha, up on the Meter tab and 0 on a chat
-- tab: alpha is allowed in a fight where Show is not, so the frame is never hidden. Faded out it
-- drops under the chat (strata), so the chat's links and wheel get the mouse. The chat draws the
-- tab, hides its text under the meter and lends the meter its fades (Chat.lua, METER TAB).
-- Visibility picks the tab when its rule changes: In Combat and In Group switch to the meter and
-- back, Always starts on it; a click holds until the rule next changes.
--------------------------------------------------
local CHAT_TAB_LOWERED = "BACKGROUND"   -- the chat windows are LOW
-- Open the Meter Tab -> the VISIBILITY rule that picks it: When Clicked never switches on its own
local CHAT_TAB_OPEN = { click = "hidden", combat = "combat", group = "group", login = "always" }
local STRATA_ORDER = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }

-- Both modules on, the chat skinned and Blizzard's meter allowed, as last applied (ApplyVisibility
-- notes it on every check): the chat draws the tab. Asked on every alpha step and every chat line,
-- so no CVar or API call here.
function DamageMeter:ChatTabAvailable()
    return self.chatTabApplied == true
end

-- The meter's own strata, or the one above the chat window's when its own is not (the chat is
-- toplevel: in the same strata it climbs over the meter on a click)
local function ChatTabRaisedStrata(meter)
    local own = meter.FlareUI_Strata or "MEDIUM"
    local chat = _G.ChatFrame1
    local ownIndex = tIndexOf(STRATA_ORDER, own) or 3
    local chatIndex = tIndexOf(STRATA_ORDER, chat and chat:GetFrameStrata() or "LOW") or 2
    if ownIndex > chatIndex then return own end
    return STRATA_ORDER[math_min(chatIndex + 1, #STRATA_ORDER)]
end

-- The meter, its windows and FlareUI's frames on them with a strata of their own (the skin, the
-- group buttons): raised on the Meter tab, lowered under the chat on a chat tab. Frames made later
-- copy the meter's strata of the moment, so an unchanged strata is left alone.
function ApplyChatTabStrata(meter, raised)
    if not meter.FlareUI_Strata then meter.FlareUI_Strata = meter:GetFrameStrata() or "MEDIUM" end
    local strata = raised and ChatTabRaisedStrata(meter) or CHAT_TAB_LOWERED
    if meter.FlareUI_ChatStrata == strata then return end
    meter.FlareUI_ChatStrata = strata
    local function Set(frame)
        if frame and not frame:IsForbidden() and frame:GetFrameStrata() ~= strata then frame:SetFrameStrata(strata) end
    end
    Set(meter)
    for _, window in ipairs(GetSessionWindows()) do
        Set(window)
        Set(window.FlareUI_DMSkin)
        for _, btn in pairs(GROUP_BUTTONS.buttons[window] or {}) do Set(btn) end
    end
end

-- The chat's alpha (its own fading), which the meter shares on the Meter tab
local function ChatAlpha()
    local dock = _G.GeneralDockManager
    local frame = (dock and FCFDock_GetSelectedWindow(dock)) or _G.ChatFrame1
    return frame and frame.FlareUI_TargetAlpha or 1
end

-- FlareUI's rule in the chat, from ApplyVisibility after each of Blizzard's checks
function ApplyChatTab(meter, db)
    -- into the chat when Refresh has not placed it yet, or a fight held it back
    if not DamageMeter.chatAnchored then MatchChatSize() end
    -- Open the Meter Tab picks the tab when its answer changes (Visibility is left for the tab off)
    local rule = (VISIBILITY[CHAT_TAB_OPEN[db.chatTabOpen] or "combat"])(meter) and true or false
    if rule ~= DamageMeter.chatTabRule then
        DamageMeter.chatTabRule = rule
        if (DamageMeter.chatTabActive or false) ~= rule then
            DamageMeter.chatTabActive = rule
            -- from Blizzard's own check: the chat follows a frame later
            if ns.Chat and ns.Chat.RefreshMeterTab then C_Timer.After(0, function() ns.Chat:RefreshMeterTab() end) end
        end
    end
    local active = DamageMeter.chatTabActive or false
    -- Edit Mode shows it whatever the tab, with its own skin: it may sit away from the chat there.
    -- Not Settings > Damage Meter: the chat's skin is its background here
    local editing = ((type(meter.IsEditing) == "function" and meter:IsEditing()) or IsEditModeActive()) and true or false
    if editing then active = true end
    if editing ~= (DamageMeter.chatTabEditing or false) then
        DamageMeter.chatTabEditing = editing or nil
        for _, window in ipairs(GetSessionWindows()) do
            local skin = window.FlareUI_DMSkin
            if skin and skin.FlareUI_InChat == editing then SetSkinInChat(window, db, not editing) end
        end
    end
    meter.FlareUI_MouseHidden = nil
    hideWhenFaded = false
    -- never hidden (a fight allows alpha, not Show); its first showing starts from nothing
    if not meter:IsShown() then meter:SetAlpha(0) end
    if not ShowMeter(meter) then
        meter.FlareUI_Up = false
        return
    end
    if active then
        ApplyChatTabStrata(meter, true)
        meter.FlareUI_Up = true
        FadeMeter(meter, ChatAlpha())
    else
        meter.FlareUI_Up = false
        FadeMeter(meter, 0)   -- lowered once faded (FadeStep)
    end
end

-- The Meter tab clicked (true) or a chat tab (false)
function DamageMeter:SetChatTab(active)
    active = active and true or false
    if (self.chatTabActive or false) == active then return end
    self.chatTabActive = active
    self:ApplyVisibility()
    if ns.Chat and ns.Chat.RefreshMeterTab then ns.Chat:RefreshMeterTab() end
end

-- The chat fades (its Visibility): on the Meter tab the meter goes with the window it stands in
function DamageMeter:SetChatTabAlpha(alpha)
    local meter = _G.DamageMeter
    if not (meter and self.chatTabActive and self:ChatTabAvailable()) or fadeDriver:IsShown() then return end
    if meter:IsShown() then meter:SetAlpha(alpha) end
end

-- Ignore Chat Fade: the chat's own fading waits while the tab is selected
function DamageMeter:ChatTabIgnoresFade()
    local db = GetDb()
    return db ~= nil and db.chatTabIgnoreFade == true
end

-- The mouse is over the meter or one of its windows: keeps a fading chat up
function DamageMeter:ChatTabMouseOver()
    local meter = _G.DamageMeter
    return meter ~= nil and meter:IsShown() and MeterUnderMouse(meter)
end

-- Out of the chat (the option or Blizzard's switch off): its own strata back now, its Edit Mode
-- place after a fight (PLAYER_REGEN_ENABLED)
function DamageMeter:LeaveChatTab()
    self.chatTabActive, self.chatTabRule, self.chatTabEditing = nil, nil, nil
    local meter = _G.DamageMeter
    if meter then ApplyChatTabStrata(meter, true) end
    if InCombatLockdown() then
        self.chatTabLeavePending = true
        return
    end
    self.chatTabLeavePending = nil
    self:RestoreEditModeAnchor()
end

--------------------------------------------------
-- 24. INIT
--------------------------------------------------
function DamageMeter:Init()
    -- EDIT_MODE_LAYOUTS_UPDATED fires while Edit Mode is open, where Refresh does nothing
    if _G.EditModeManagerFrame and not self._editModeHooked then
        self._editModeHooked = true
        _G.EditModeManagerFrame:HookScript("OnHide", function()
            C_Timer.After(0, function() DamageMeter:Refresh() end)
        end)
    end

    HookEntryFonts()
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    self:RegisterEvent("ADDON_LOADED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_LEAVING_WORLD")
    GROUP_BUTTONS.events:RegisterEvent("GROUP_ROSTER_UPDATE")
    GROUP_BUTTONS.events:RegisterEvent("PARTY_LEADER_CHANGED")
    timerEvents:RegisterEvent("PLAYER_REGEN_DISABLED")
    timerEvents:RegisterEvent("PLAYER_REGEN_ENABLED")

    -- the meter's gear menu gets FlareUI's settings (its own "Open Settings" goes to a page this
    -- client doesn't have). Menu.ModifyMenu adds to Blizzard's menu without touching it.
    if Menu and Menu.ModifyMenu and not self.gearMenuHooked then
        self.gearMenuHooked = true
        Menu.ModifyMenu("MENU_DAMAGE_METER_WINDOW_SETTINGS", function(_, rootDescription)
            local db = GetDb()
            if not (db and db.enabled and ns.SettingsPanel) then return end
            rootDescription:CreateDivider()
            rootDescription:CreateButton(L["FlareUI Settings"], function() ns.SettingsPanel:Open("dm") end)
        end)
    end

    C_Timer.After(0, function() self:Refresh() end)
    C_Timer.After(1, function() self:Refresh() end)
end
