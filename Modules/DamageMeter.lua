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
    -- Frame Style FlareUI: FlareUI Thick, as the chat's and the quest tracker's (its Border choice hides)
    local name = db and (db.frameStyle == "flareui" and "FlareUI Thick" or db.borderTexture)
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

-- A text's width, or nil. The game hides a region's measures (a secret value) while its anchoring is
-- secret, also out of a fight: then the last width read stands in, and nil means none was ever read.
local lastWidth = setmetatable({}, { __mode = "k" })
local function TextWidth(fontString)
    local width = fontString:GetUnboundedStringWidth()
    if canaccessvalue(width) and type(width) == "number" then
        lastWidth[fontString] = width
        return width
    end
    return lastWidth[fontString]
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
    -- the separate threat window shows on the page whatever its Visibility (IsSettingsPreview, read by
    -- the Visibility module's fader)
    if DamageMeter.ApplyThreatWindow then DamageMeter.ApplyThreatWindow() end
    if ns.Visibility and ns.Visibility.Wake then ns.Visibility:Wake() end
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

-- Settings > Meters open (the Visibility module shows the separate threat window then)
function DamageMeter:IsSettingsPreview() return self.settingsPreview or false end

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
-- (PaintSkin and SkinBackdrop also dress the settings preview's sample)
function DamageMeter.PaintSkin(skin, db, inChat)
    inChat = inChat and true or false
    skin.FlareUI_InChat = inChat
    skin:SetBackdropColor(1, 1, 1, inChat and 0 or db.opacity or 0.85)
    skin:SetBackdropBorderColor(BORDER_TINT.r, BORDER_TINT.g, BORDER_TINT.b, inChat and 0 or BORDER_TINT.a)
    -- Frame Style FlareUI (11-20): the chat's FlareUI strips (same 24 px header), none inside the chat
    -- (the chat's skin is the frame there)
    if ns.Chat and ns.Chat.ApplyFrameStyleArt then ns.Chat.ApplyFrameStyleArt(skin, db, inChat) end
end

local function SetSkinInChat(window, db, inChat)
    local skin = window.FlareUI_DMSkin
    if not skin then return end
    DamageMeter.PaintSkin(skin, db, inChat)
end

function DamageMeter.SkinBackdrop(skin, db)
    local bgTexture     = LSM:Fetch("background", "Blizzard Dialog Background Dark") or "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"
    local borderTexture = GetBorderFile(db)
    skin:SetBackdrop({ bgFile = bgTexture, edgeFile = borderTexture, tile = false, tileSize = 0, edgeSize = ns.BorderEdgeSize(borderTexture, 16), insets = { left = 3, right = 3, top = 3, bottom = 3 } })
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

    DamageMeter.SkinBackdrop(skin, db)
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

    skin.Separator:SetShown(header ~= nil and not (db.frameStyle == "flareui" and not skin.FlareUI_InChat))
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

    DamageMeter.SkinBackdrop(skin, db)
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
    ready = { icon = ICON_READY },
    countdown = { icon = ICON_COUNTDOWN, seconds = 10 },
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
        if db and applies[key] then list[#list + 1] = key end
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
    DamageMeter.HeaderIcon(btn, def.icon, ICON_DRAW_SIZE[key])
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

-- The title's click area ends at its text: stretched over the header it would open its menu on every
-- press, and leave a second window (which moves outside Edit Mode) a 3 px drag spot. The rest of the
-- header stays Blizzard's own drag.
local function FitTitleButton(window)
    local dd = GetWindowTypeDropdown(window)
    local ref = window.FlareUI_DMSkin or GetWindowHeader(window)
    if not (dd and dd.TypeName and ref and dd.FlareUI_TitleReserve) then return end
    -- a docked window's title sits further right, after the tabs before it (section 23b)
    local textX = dd.FlareUI_TextX or TITLE_LEFT
    local left = DamageMeter.TitleButtonLeft(textX)
    local refWidth, textWidth = ref:GetWidth(), TextWidth(dd.TypeName)
    if not (canaccessvalue(refWidth) and refWidth and textWidth) then return end
    local room = refWidth - dd.FlareUI_TitleReserve - left
    local width = textX + textWidth + 8 - left
    dd:SetSize(math_max(math_min(width, room), 1), HEADER_HEIGHT)
end

-- where the title's click area starts: at the header's edge for the first tab, else just before its text
function DamageMeter.TitleButtonLeft(textX)
    if textX == TITLE_LEFT then return 0 end
    return textX - 4
end

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
                dd:SetPoint("TOPLEFT", ref, "TOPLEFT", DamageMeter.TitleButtonLeft(dd.FlareUI_TextX or TITLE_LEFT), 0)
                -- as wide as the title, never past the icons
                dd.FlareUI_TitleReserve = ICON_RIGHT + iconsWidth + 8
                FitTitleButton(window)
                if dd.TypeName and not dd.FlareUI_FitHooked then
                    dd.FlareUI_FitHooked = true
                    hooksecurefunc(dd.TypeName, "SetText", function() SafeCall(FitTitleButton, window) end)
                    window:HookScript("OnSizeChanged", function() SafeCall(FitTitleButton, window) end)
                end
            end
            local timer = GetWindowSessionTimer(window)
            if timer and timer.ClearAllPoints then
                timer:ClearAllPoints()
                timer:SetPoint("RIGHT", ref, "TOPRIGHT", -(ICON_RIGHT + iconsWidth + 10), ROW_CENTER_Y)
                timer:SetJustifyH("RIGHT")
            end
            if dd and dd.TypeName and dd.TypeName.ClearAllPoints then
                dd.TypeName:ClearAllPoints()
                dd.TypeName:SetPoint("LEFT", ref, "TOPLEFT", dd.FlareUI_TextX or TITLE_LEFT, ROW_CENTER_Y)
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
    if not btn.GetRegions then return end
    for _, r in ipairs({ btn:GetRegions() }) do
        if r and r.IsObjectType and r:IsObjectType("Texture") and r.SetAlpha then
            r:SetAlpha(0)
        end
    end
end

-- A header icon in struck bronze, centred on its button (also the settings preview's sample)
function DamageMeter.HeaderIcon(btn, iconPath, drawSize, yOfs)
    if not btn.FlareUI_Icon then
        btn.FlareUI_Icon = btn:CreateTexture(nil, "OVERLAY")
        btn.FlareUI_Icon:SetDrawLayer("OVERLAY", 7)
    end
    btn.FlareUI_Icon:ClearAllPoints()
    btn.FlareUI_Icon:SetPoint("CENTER", btn, "CENTER", 0, yOfs or 0)
    btn.FlareUI_Icon:SetSize(drawSize or ICON_SIZE, drawSize or ICON_SIZE)
    ns.BronzeIcon.Apply(btn.FlareUI_Icon, iconPath, ICON_COLOR)
end

local function SetupCustomIcon(btn, iconPath, hideSessionName, drawSize, yOfs)
    if not btn then return end
    btn:Show()
    HideBlizzardButtonVisuals(btn, hideSessionName)

    DamageMeter.HeaderIcon(btn, iconPath, drawSize, yOfs)
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

-- The header font with its gold (also the settings preview's sample)
function DamageMeter.HeaderFontDb(db)
    return setmetatable({ useCustomColor = true, color = TITLE_COLOR },
        { __index = (db and db.headerFont) or HEADER_FONT })
end

local function ApplyHeaderFonts(window)
    if not window or window:IsForbidden() then return end
    local fontDb = DamageMeter.HeaderFontDb(GetDb())
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
    -- a new font, a new title width
    FitTitleButton(window)
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

    -- a family: other players' names keep their Cyrillic and Chinese / Korean letters. A row reads
    -- "1. Имя": the "1." makes the game pick the Latin member, so that member is the font's Cyrillic
    -- twin where there is one (ns.CyrillicTwin, Core.lua), which has both alphabets
    local rowPath = ns.CyrillicTwin(path)
    local function ApplyToFS(fs)
        if fs and fs.SetFont then
            ns.SetFontFamily(fs, rowPath, size, flags)
            ApplyFontEffects(fs, fontDb)
        end
    end

    -- the row's only texts, both on its status bar
    ApplyToFS(nameFs)
    ApplyToFS(valueFs)
    DamageMeter.ApplyBarTexture(statusBar, db)
end

-- Bar Texture: a unit frame texture on the fill (its colour stays the row's); "" keeps Blizzard's
-- atlas, put back once when the choice goes back to Blizzard
function DamageMeter.ApplyBarTexture(bar, db)
    local fill = bar and bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if not fill then return end
    local want = db and db.barTexture or ""
    if bar.fuiBarTexture == want then return end
    if want == "" then
        if bar.fuiBarTexture and bar.fuiAtlas then fill:SetAtlas(bar.fuiAtlas) end
    else
        if bar.fuiBarTexture == nil then bar.fuiAtlas = fill.GetAtlas and fill:GetAtlas() or nil end
        local Kit = ns.UnitFrames and ns.UnitFrames.Kit
        local path = Kit and Kit.GetBarTexture and Kit.GetBarTexture(want)
        if not path then return end
        fill:SetTexture(path)
    end
    bar.fuiBarTexture = want
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
local Dock = {}                  -- extra meter windows as tabs of the first (23b)
local Solo = {}                  -- Threat > Separate Window (16b): frame, view, proxy, hidden
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
-- party / partypet / raid / raidpet: the unit tokens by index, built once; owner: pet token -> its owner
local threatScratch = { list = {}, pool = {}, shown = {}, classOf = {}, isMe = {},
    party = {}, partypet = {}, raid = {}, raidpet = {}, owner = { pet = "player" } }
for i = 1, 40 do
    threatScratch.raid[i], threatScratch.raidpet[i] = "raid" .. i, "raidpet" .. i
    threatScratch.owner["raidpet" .. i] = "raid" .. i
end
for i = 1, 4 do
    threatScratch.party[i], threatScratch.partypet[i] = "party" .. i, "partypet" .. i
    threatScratch.owner["partypet" .. i] = "party" .. i
end

-- A pet row takes its owner's class colour (a pet's own class belongs to nobody in the group)
local function PetOwner(unit)
    return threatScratch.owner[unit]
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
        for i = 1, math_min(GetNumGroupMembers(), 40) do AddThreat(s.raid[i]); AddThreat(s.raidpet[i]) end
    else
        AddThreat("player"); AddThreat("pet")
        for i = 1, math_min(GetNumSubgroupMembers(), 4) do AddThreat(s.party[i]); AddThreat(s.partypet[i]) end
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
    -- a family: a Latin-only header font keeps Blizzard's Cyrillic face for the Russian title
    local function Style(fs)
        if path then ns.SetFontFamily(fs, path, size, flags) end
        fs:SetShadowOffset(dd.TypeName:GetShadowOffset())
        fs:SetShadowColor(dd.TypeName:GetShadowColor())
    end
    Style(view.tab.Text)
    -- The window's own title is drawn by FlareUI too, as every other tab, so it doesn't move a few
    -- pixels as its tab is picked: Blizzard's title text goes invisible and its button stays the click
    -- area (and the type menu). It is placed exactly as the other tabs and Threat: a box from 4 px
    -- before the text, the text 4 px in (a text placed straight on the header lands a pixel or two off).
    -- The settings preview's sample window is a stand-in table, not a frame, with a plain title text:
    -- it keeps drawing that title itself.
    local realWindow = type(window.GetObjectType) == "function" and type(dd.GetFrameLevel) == "function"
    local own = realWindow and view.ownTitle or dd.TypeName
    if realWindow and not view.ownTitle then
        local host = CreateFrame("Frame", nil, window)
        host:SetFrameLevel(dd:GetFrameLevel() + 3)
        host:EnableMouse(false)
        view.ownHost = host
        own = host:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        own:SetPoint("LEFT", host, "LEFT", 4, 0)
        own:SetJustifyH("LEFT")
        own:SetWordWrap(false)
        view.ownTitle = own
        -- the text follows at once (the relayout is CreateThreatView's own SetText hook)
        hooksecurefunc(dd.TypeName, "SetText", function(fs) own:SetText(fs:GetText()) end)
    end
    if own ~= dd.TypeName then
        Style(own)
        own:SetText(dd.TypeName:GetText())
        dd.TypeName:SetAlpha(0)
    end
    -- left to right: the meter windows' tabs (this window's own title where its tab belongs, the
    -- others as FlareUI tabs, section 23b), then Threat, always last
    local row = Dock.Row(window)
    local x, ownX = TITLE_LEFT, TITLE_LEFT   -- where the next tab's text starts
    -- a width never read (secret since the start) leaves the tabs where they are
    local titleWidth, threatWidth = TextWidth(own), TextWidth(view.tab.Text)
    if not (titleWidth and threatWidth) then return end
    if row then
        for _, other in ipairs(row) do
            if other == window then
                ownX = x
                x = x + titleWidth + TAB_GAP
            else
                local label = Dock.Label(window, other)
                Style(label.Text)
                label.Text:SetText(Dock.TitleOf(other))
                local labelWidth = TextWidth(label.Text)
                if not labelWidth then return end
                label:ClearAllPoints()
                label:SetPoint("LEFT", ref, "TOPLEFT", x - 4, ROW_CENTER_Y)
                label:SetSize(labelWidth + 8, HEADER_HEIGHT)
                ColorTab(label.Text, false)
                label:Show()
                x = x + labelWidth + TAB_GAP
            end
        end
    else
        x = x + titleWidth + TAB_GAP
    end
    Dock.HideLabels(window, row)
    Dock.PlaceTitle(window, dd, ref, ownX)
    if own ~= dd.TypeName and view.ownHost then
        view.ownHost:ClearAllPoints()
        view.ownHost:SetPoint("LEFT", ref, "TOPLEFT", ownX - 4, ROW_CENTER_Y)
        view.ownHost:SetSize(titleWidth + 8, HEADER_HEIGHT)
    end
    view.tab:ClearAllPoints()
    view.tab:SetPoint("LEFT", ref, "TOPLEFT", x - 4, ROW_CENTER_Y)
    view.tab:SetSize(threatWidth + 8, HEADER_HEIGHT)
    -- a window on its own has no Threat tab: the threat list stays with the first window
    -- (only a real meter window's view: the settings sample has no hit area and keeps its own tab)
    if views[window] == view and view.hit then
        local db = GetDb()
        local noTab = (db and db.threatWindow) or (window ~= _G.DamageMeterSessionWindow1 and not row)
        view.tab:SetShown(not noTab)
        -- a docked window that is down keeps it: it is the left-click of its tab (Dock.LiftTitle)
        view.hit:SetShown(not noTab or window.FlareUI_DockUp == false)
    end
    -- docked, the threat list lives on the first window: every row colours from it
    local threatUp = view.showing
    if row then threatUp = Dock.ThreatShown() end
    ColorTab(own, not threatUp)
    ColorTab(view.tab.Text, threatUp)
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
        -- the settings preview's sample brings its own (a stand-in when Blizzard's meter isn't loaded)
        row = view.newRow and view.newRow(view.frame) or CreateFrame("Button", nil, view.frame, "DamageMeterEntryTemplate")
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
    -- Tank's Lead: after the tank's own numbers, how far it is ahead of second place, as "(+25%)"
    local percent = math.floor(data.scaled + 0.5)
    local display = db.threatValueDisplay or "percent"
    if row.ftValue ~= data.value or row.ftPercent ~= percent or row.ftLead ~= data.lead or row.ftDisplay ~= display then
        row.ftValue, row.ftPercent, row.ftLead, row.ftDisplay = data.value, percent, data.lead, display
        local pct = ("%d%%"):format(percent)
        local amount = ns.ShortNumber(data.value / 100)
        local text
        if display == "percent" then
            text = pct
        elseif display == "value" then
            text = amount
        else
            text = amount .. "  " .. pct
        end
        if data.lead then text = text .. (" (+%d%%)"):format(data.lead) end
        row:GetValue():SetText(text)
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
    -- the settings preview's sample view always shows the sample rows, and leaves the live mob alone
    local mob = not view.sample and ThreatMob()
    if not mob and (view.sample or DamageMeter.settingsPreview) then
        if not view.sample then threatScratch.mob = nil end
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
    -- Pull Warning Sound: once as the warning starts, in a fight only (not for the settings' sample
    -- rows); never while you hold the mob, as the warning itself. The combat flag may be secret (InFight).
    local fighting = UnitAffectingCombat("player")
    local warning = me and me.warn and canaccessvalue(fighting) and fighting or false
    if warning and not DamageMeter.pullWarned and db.threatPullSound then
        PlaySound(SOUNDKIT.RAID_WARNING or 8959, "Master")
    end
    DamageMeter.pullWarned = warning and true or nil
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
    local any = Solo.view and Solo.view.showing or false
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
local function UpdateOne(window, view, staleOnly)
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
function UpdateThreatViews(staleOnly)
    threatDriver.stale = nil
    for window, view in pairs(views) do UpdateOne(window, view, staleOnly) end
    if Solo.view then UpdateOne(Solo.proxy, Solo.view, staleOnly) end
end

local function SetView(window, showThreat)
    local view = views[window]
    if not view then return end
    local db = GetDb()
    if db and db.threatWindow then showThreat = false end
    -- a docked window shows no threat list: the first window has it, on top (23b); nor does a window
    -- on its own (23c)
    if window ~= _G.DamageMeterSessionWindow1 then showThreat = false end
    view.showing = showThreat and true or false
    view.frame:SetShown(view.showing)
    SetBlizzardListShown(window, not view.showing)
    if Dock.Row(window) or window.FlareUI_DockLabels then Dock.Stack() else LayoutTabs(window, view) end
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
    if Solo.view and Solo.view.showing then SafeCall(UpdateThreatView, Solo.proxy, Solo.view) end
end

function DamageMeter.EndThreatPreview()
    if not DamageMeter.threatPreviewing then return end
    DamageMeter.threatPreviewing = nil
    local threat = ThreatPicked()
    for window in pairs(views) do SetView(window, threat) end
    if Solo.view and Solo.view.showing then SafeCall(UpdateThreatView, Solo.proxy, Solo.view) end
end

-- Settings: Separate Window just switched on
function DamageMeter.PlaceThreatWindow()
    if Solo.Apply then Solo.Apply() end
    if Solo.PlaceBesideMeter then SafeCall(Solo.PlaceBesideMeter) end
end

-- The Threat tab's Move to Own Window (true) and the threat window's Dock as a Tab (false, 23c):
-- Threat > Separate Window, as if ticked in the settings, which show it. In a fight the meter waits
-- for its end, as the settings' tick does; the new window is placed then.
function DamageMeter.SetThreatWindow(on)
    local db = GetDb()
    if not db then return end
    db.threatWindow = on and true or false
    if InFight() then
        DamageMeter._pendingRefresh = true
        if on then DamageMeter.threatPlacePending = true end
    else
        DamageMeter:Refresh()
        if on then DamageMeter.PlaceThreatWindow() end
    end
    if ns.SettingsPanel and ns.SettingsPanel.Refresh then ns.SettingsPanel:Refresh() end
end

function DamageMeter.RedrawThreat()
    for window, view in pairs(views) do
        if view.showing then SafeCall(UpdateThreatView, window, view) end
    end
    if Solo.view and Solo.view.showing then SafeCall(UpdateThreatView, Solo.proxy, Solo.view) end
end

-- The toggle flips every window from what is on screen, not from the saved pick
local function ToggleThreatViews()
    local showing = false
    for _, view in pairs(views) do if view.showing then showing = true end end
    for window in pairs(views) do PickView(window, not showing) end
end

-- The radial menu's "Toggle Threat Meter" runs this
function FlareUI_ToggleThreatMeter()
    local db = GetDb()
    if db and db.threatWindow and Solo.Apply then
        Solo.hidden = not Solo.hidden
        Solo.Apply()
        return
    end
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
    hit:SetScript("OnClick", function()
        if Dock.Row(window) then Dock.Select(window) else PickView(window, false) end
    end)
    -- a docked window that isn't up lends its title to the tab in the shown window's row
    -- (Dock.LiftTitle): pointing at it lights that tab, as pointing at the tab itself did
    hit:SetScript("OnEnter", function()
        local label = Dock.ShownLabel(window)
        if label then
            local r, g, b = LightenColor(TAB_INACTIVE.r, TAB_INACTIVE.g, TAB_INACTIVE.b, 0.2)
            label.Text:SetTextColor(r, g, b)
        end
    end)
    hit:SetScript("OnLeave", function()
        local label = Dock.ShownLabel(window)
        if label then ColorTab(label.Text, false) end
    end)
    view.hit = hit

    local tab = CreateFrame("Button", nil, window)
    tab:SetFrameLevel(dd:GetFrameLevel() + 3)
    tab.Text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tab.Text:SetPoint("LEFT", tab, "LEFT", 4, 0)
    tab.Text:SetText(L["Threat"])
    tab:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    tab:SetScript("OnClick", function(self, button)
        -- right-click: Move to Own Window (Threat > Separate Window, 23c)
        if button == "RightButton" then Dock.OpenThreatMenu(self, true); return end
        if Dock.Row(window) then Dock.PickThreat() else PickView(window, true) end
    end)
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
    -- docked, the other windows' tabs show this title too
    hooksecurefunc(dd.TypeName, "SetText", function()
        if Dock.Row(window) then SafeCall(Dock.Stack) else LayoutTabs(window, view) end
    end)

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

-- Group combat has no single reliable end event. Keep the fallback, but a full roster
-- scan twice a second is enough; player transitions and roster changes invalidate it at once.
local groupCombat, groupCheckAt = false, -math.huge
local function GroupInCombat()
    local now = GetTime()
    if now - groupCheckAt < 0.5 then return groupCombat end
    groupCheckAt, groupCombat = now, false
    local mine = UnitAffectingCombat("player")
    if canaccessvalue(mine) and mine then groupCombat = true; return true end
    if not IsInGroup() then return false end
    local prefix, count = "party", GetNumSubgroupMembers()
    if IsInRaid() then prefix, count = "raid", GetNumGroupMembers() end
    for i = 1, count do
        local fighting = UnitAffectingCombat(prefix .. i)
        if canaccessvalue(fighting) and fighting then groupCombat = true; return true end
    end
    return false
end

local UpdateLiveTimers

-- Each window's text, when its second changed; Blizzard's timer shows where FlareUI's has nothing
local function PaintLiveTimers()
    for window, fs in pairs(liveTimers) do
        if window:IsVisible() then
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
    groupCheckAt = -math.huge
    if event == "GROUP_ROSTER_UPDATE" then UpdateLiveTimers(); return end
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
    -- Separate Window: no Threat tab on the meter (its list has a window of its own)
    local separate = db and db.threatWindow and true or false
    -- nor on a window on its own: the threat list stays with the first window
    local noTab = separate or (window ~= _G.DamageMeterSessionWindow1 and not Dock.Row(window))
    view.tab:SetShown(not noTab)
    view.hit:SetShown(not noTab)
    SetView(window, (not separate) and (view.showing or ThreatPicked()))
end

--------------------------------------------------
-- 16b. SEPARATE THREAT WINDOW (Threat > Separate Window)
-- The threat list in a window of its own, in the meter's look: moved and sized in Edit Mode, with
-- sample rows there. On Same as Meter (its Edit Mode Fading) a child of Blizzard's meter, so it shows,
-- hides and fades with it; on its own otherwise (AttachThreatWindow). Its bars follow the first meter
-- window's bar settings (height, spacing, icons, style, class colours); its size starts as that
-- window's.
--------------------------------------------------
do
    local LEM = LibStub("FlareEditMode")
    local DEFAULTS = { point = "CENTER", x = 320, y = -160 }
    local MIN_W, MAX_W, MIN_H, MAX_H = 150, 600, 60, 500

    local function Source() return _G.DamageMeterSessionWindow1 end
    -- what the rows ask the window for (FillRow, UpdateThreatView)
    Solo.proxy = {
        GetBarHeight = function() local w = Source(); return w and w.GetBarHeight and w:GetBarHeight() or 24 end,
        GetBarSpacing = function() local w = Source(); return w and w.GetBarSpacing and w:GetBarSpacing() or 2 end,
        GetTextScale = function() local w = Source(); return w and w.GetTextScale and w:GetTextScale() or 1 end,
        ShouldShowBarIcons = function() local w = Source(); return w and w.ShouldShowBarIcons and w:ShouldShowBarIcons() or false end,
        GetStyle = function() local w = Source(); return w and w.GetStyle and w:GetStyle() or Enum.DamageMeterStyle.Default end,
        ShouldUseClassColor = function() local w = Source(); return w and w.ShouldUseClassColor and w:ShouldUseClassColor() or false end,
    }

    local function Redraw()
        if Solo.view and Solo.view.showing then SafeCall(UpdateThreatView, Solo.proxy, Solo.view) end
    end

    -- per Edit Mode layout, as every FlareUI frame
    local function Store(layoutName)
        local db = GetDb()
        if not db then return nil end
        layoutName = layoutName or LEM:GetActiveLayoutName() or "Modern"
        db.threatWindowLayouts = db.threatWindowLayouts or {}
        return ns.LayoutHome(db.threatWindowLayouts, layoutName)
    end
    local function Place(layoutName)
        local f = Solo.frame
        if not f then return end
        local store = Store(layoutName)
        local pos = (store and store.point) and store or DEFAULTS
        f:ClearAllPoints()
        f:SetPoint(pos.point, f:GetParent(), pos.point, pos.x or 0, pos.y or 0)
    end
    local function OnMoved(_, layoutName, point, x, y)
        local store = Store(layoutName)
        if not store then return end
        store.point, store.x, store.y = point, math.floor(x + 0.5), math.floor(y + 0.5)
    end

    local function Size()
        local db, f = GetDb(), Solo.frame
        if not (db and f) then return end
        if not db.threatWindowWidth then
            local w = Source()
            local width, height = w and w:GetWidth(), w and w:GetHeight()
            -- a size the game hides (see TextWidth) is never compared: the defaults stand in
            if not canaccessvalue(width) then width = nil end
            if not canaccessvalue(height) then height = nil end
            db.threatWindowWidth = (width and width > 0) and math.floor(width + 0.5) or 300
            db.threatWindowHeight = (height and height > 0) and math.floor(height + 0.5) or 150
        end
        f:SetSize(math.max(MIN_W, math.min(MAX_W, db.threatWindowWidth)),
                  math.max(MIN_H, math.min(MAX_H, db.threatWindowHeight or 150)))
    end

    local function Look()
        local db, f = GetDb(), Solo.frame
        if not (db and f) then return end
        DamageMeter.SkinBackdrop(f.skin, db)
        DamageMeter.PaintSkin(f.skin, db, false)
        local fontDb = DamageMeter.HeaderFontDb(db)
        local path, size, flags = GetFontData(fontDb)
        ns.SetFont(f.title, path, size, flags)
        ApplyFontEffects(f.title, fontDb)
        for _, row in ipairs(Solo.view.rows) do ApplyBarFont(row, db) end
    end

    local function Settings()
        local Section, settings = ns.EditSections()
        local function get(key, default) return function() local db = GetDb(); return db and db[key] or default end end
        local function set(key) return function(_, value) local db = GetDb(); if db then db[key] = value; Size() end end end
        Section("Frame", {
            { name = L["Width"], kind = LEM.SettingType.Slider, default = 300, minValue = MIN_W, maxValue = MAX_W, valueStep = 1,
              get = get("threatWindowWidth", 300), set = set("threatWindowWidth") },
            { name = L["Height"], kind = LEM.SettingType.Slider, default = 150, minValue = MIN_H, maxValue = MAX_H, valueStep = 1,
              get = get("threatWindowHeight", 150), set = set("threatWindowHeight") },
        })
        return settings
    end

    -- Edit Mode: sample rows (a tank, you near the pull line, two more), whatever is targeted
    local function EditMode(editing)
        if not Solo.view then return end
        Solo.view.sample = editing and true or nil
        -- (its Visibility lets it show in Edit Mode, and takes over again after)
        if Solo.Apply then Solo.Apply() end
        if Solo.view then Solo.view.sample = editing and true or nil end
        Redraw()
    end

    local function Create()
        local meter = _G.DamageMeter
        if Solo.frame then return true end
        if not (meter and Source()) then return false end
        -- Edit Mode measures and anchors a frame against its parent, and the meter is far smaller than
        -- the screen it is placed on (it would snap with Snap off, move diagonally with the arrow keys
        -- and move after /reload). A screen-sized holder under the meter keeps it hiding with the meter
        -- and gives Edit Mode the whole screen.
        local holder = CreateFrame("Frame", nil, meter)
        holder:SetAllPoints(UIParent)
        Solo.holder = holder
        local f = CreateFrame("Frame", "FlareUI_ThreatMeter", holder)
        f:SetClampedToScreen(true)
        local skin = CreateFrame("Frame", nil, f, "BackdropTemplate")
        skin:SetPoint("TOPLEFT", f, "TOPLEFT", -SKIN_PADDING, SKIN_PADDING)
        skin:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", SKIN_PADDING, -SKIN_PADDING)
        skin:SetFrameLevel(math_max(f:GetFrameLevel() - 1, 0))
        local line = skin:CreateTexture(nil, "OVERLAY")
        line:SetTexture(SEPARATOR)
        line:SetHeight(8)
        line:SetPoint("TOPLEFT", skin, "TOPLEFT", 3, -HEADER_HEIGHT)
        line:SetPoint("TOPRIGHT", skin, "TOPRIGHT", -3, -HEADER_HEIGHT)
        skin.Separator = line   -- (Frame Style FlareUI hides it, Chat.ApplyFrameStyleArt)
        f.skin = skin
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")   -- (a font before SetText; Look sets the header font)
        f.title:SetPoint("LEFT", skin, "TOPLEFT", TITLE_LEFT, ROW_CENTER_Y)
        f.title:SetText(L["Threat"])
        -- right-click the header: Dock as a Tab (Separate Window off, 23c)
        local head = CreateFrame("Button", nil, f)
        head:SetPoint("TOPLEFT", skin, "TOPLEFT", 0, 0)
        head:SetPoint("BOTTOMRIGHT", skin, "TOPRIGHT", 0, -HEADER_HEIGHT)
        head:RegisterForClicks("RightButtonUp")
        head:SetScript("OnClick", function(self) Dock.OpenThreatMenu(self, false) end)

        -- the list, as the tab's
        local list = CreateFrame("Frame", nil, f)
        list:SetPoint("TOPLEFT", skin, "TOPLEFT", 6, -CONTENT_TOP)
        list:SetPoint("BOTTOMRIGHT", skin, "BOTTOMRIGHT", -6, 6)
        list:EnableMouseWheel(true)
        list.Empty = list:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        list.Empty:SetPoint("CENTER")
        local view = { rows = {}, showing = false, frame = list, solo = true }
        list:SetScript("OnMouseWheel", function(_, delta)
            local offset = math_max(0, (view.offset or 0) - delta)
            if offset == (view.offset or 0) then return end
            view.offset = offset
            Redraw()
        end)
        local overlay = CreateFrame("Frame", nil, list)
        overlay:SetAllPoints()
        overlay:SetFrameLevel(list:GetFrameLevel() + 30)
        local pull = overlay:CreateTexture(nil, "OVERLAY", nil, 7)
        pull:SetColorTexture(1, 0.2, 0.15, 0.95)
        pull:SetWidth(2)
        pull:Hide()
        view.pullLine = pull
        Solo.frame, Solo.view = f, view
        -- a new size fits a new number of rows
        f:SetScript("OnSizeChanged", Redraw)

        Size()
        Place()
        LEM:AddFrame(f, OnMoved, DEFAULTS, L["Threat Meter"])
        LEM:AddFrameSettings(f, Settings())
        LEM:RegisterCallback("layout", function(layoutName) Place(layoutName) end)
        LEM:RegisterCallback("enter", function() EditMode(true) end)
        LEM:RegisterCallback("exit", function() EditMode(false) end)
        -- its Fading (on its own or with the meter) as soon as it exists
        if ns.Visibility and ns.Visibility.Refresh then
            C_Timer.After(0, function()
                if ns.Visibility.AddEditModeSettings then ns.Visibility.AddEditModeSettings() end
                ns.Visibility:Refresh()
            end)
        end
        return true
    end

    -- Separate Window switched on: the window right above the meter's first window
    -- when that sits in the lower half of the screen, else right below it; saved as its spot in this
    -- Edit Mode layout, so Edit Mode can move it from there
    local BESIDE_GAP = 8   -- between the two windows' borders (each reaches 2 px out)
    function Solo.PlaceBesideMeter()
        local f, src = Solo.frame, Source()
        if not (f and src) then return end
        local left, bottom, _, height = src:GetRect()
        if not (left and bottom and height) then return end
        local srcScale, fScale = src:GetEffectiveScale(), f:GetEffectiveScale()
        local uiScale = UIParent:GetEffectiveScale()
        left, bottom = left * srcScale, bottom * srcScale
        local top = bottom + height * srcScale
        local screenHeight = UIParent:GetHeight() * uiScale
        local gap = BESIDE_GAP * uiScale
        local newBottom
        if (bottom + top) / 2 < screenHeight / 2 then
            newBottom = top + gap                                -- the meter low: above it
        else
            newBottom = bottom - gap - f:GetHeight() * fScale    -- the meter high: below it
        end
        local store = Store()
        if not store then return end
        store.point, store.x, store.y = "BOTTOMLEFT", math.floor(left / fScale + 0.5), math.floor(newBottom / fScale + 0.5)
        Place()
    end

    -- Visibility (in its Edit Mode dialog's Fading, Modules/Visibility.lua element "threat"). Same as
    -- Meter: the holder sits under the meter, so the window shows, hides and fades with it. Any other
    -- choice or a fade group:
    -- the holder sits on UIParent and the Visibility module fades the window on its own (an addon
    -- frame: re-parented in a fight too).
    function DamageMeter.AttachThreatWindow(withMeter)
        local holder, meter = Solo.holder, _G.DamageMeter
        local parent = (withMeter and meter) or UIParent
        if holder and holder:GetParent() ~= parent then
            holder:SetParent(parent)
            holder:SetAllPoints(UIParent)
        end
    end
    function DamageMeter.ApplyThreatWindow() if Solo.Apply then Solo.Apply() end end

    -- shown with Separate Window on (and not hidden by the radial's Toggle Threat Meter); its
    -- Visibility fades it
    function Solo.Apply()
        local db = GetDb()
        local want = db and db.enabled and db.threatWindow and true or false
        if want and not Create() then return end
        if not Solo.frame then return end
        local shown = want and not Solo.hidden
        Solo.frame:SetShown(shown)
        Solo.view.showing = shown
        if want then
            Size()
            Look()
            Solo.view.sample = IsEditModeActive() or nil
        end
        Redraw()
        WatchThreat()
    end
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
    if InFight() then
        self._pendingRefresh = true
        return
    end
    self._refreshes = (self._refreshes or 0) + 1

    local db = GetDb()
    if not db or not db.enabled then return end
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
    self:SetupMouseover()
    SafeCall(Dock.Update)
    SafeCall(Solo.Apply)
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
    -- the Threat tab's Move to Own Window, picked in the fight (23c): placed after that Refresh
    if self.threatPlacePending then
        self.threatPlacePending = nil
        C_Timer.After(0, function()
            local db = GetDb()
            if db and db.enabled and db.threatWindow then DamageMeter.PlaceThreatWindow() end
        end)
    end
end

-- (leaving Edit Mode saves the layout too: skip when a refresh already ran after this event)
function DamageMeter:EDIT_MODE_LAYOUTS_UPDATED()
    local seen = self._refreshes
    C_Timer.After(0.25, function()
        if self._refreshes ~= seen then return end
        self:Refresh()
    end)
end

function DamageMeter:ADDON_LOADED(event, addonName)
    if addonName == "Blizzard_DamageMeter" then
        HookEntryFonts()
        SafeCall(self.Refresh, self)
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

-- Reset on Leaving a Group: leaving a party or raid clears the meter, as entering a new
-- dungeon does (Reset on Entering a Dungeon)
function DamageMeter:GROUP_LEFT()
    local db = GetDb()
    if not (db and db.enabled and db.resetOnGroupLeave) then return end
    if C_DamageMeter and C_DamageMeter.ResetAllCombatSessions then pcall(C_DamageMeter.ResetAllCombatSessions) end
end

--------------------------------------------------
-- 22. VISIBILITY AND MOUSEOVER (the meter's Edit Mode Fading, Modules/Visibility.lua)
-- Applied after each of Blizzard's checks, overruling the Edit Mode dropdown (preset layouts cannot
-- save it). Mouseover keeps a hidden meter up at alpha 0 until hovered. One driver fades the
-- alpha at the Fade Speed and hides the meter after a fade out.
--------------------------------------------------
-- the Meter tab's Open the Meter Tab rules (ApplyChatTab)
local VISIBILITY = {
    combat = function(meter) return meter:IsPlayerInCombat() end,
    group  = function(meter) return meter:IsPlayerInGroup() end,
}
local fadeDriver = CreateFrame("Frame")
fadeDriver:Hide()
local fadeTarget, hideWhenFaded = 1, false
local autoFading = false

-- runs every frame under Show on Mouseover, so the window callback is made once
local mouseOverWindow = false
local function CheckWindowMouse(window) if window:IsShown() and window:IsMouseOver() then mouseOverWindow = true end end

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

-- The meter's Visibility, fade speeds, Faded Opacity, fade group and Fade Delay are set in its Edit
-- Mode dialog (Modules/Visibility.lua, element "meter"). The meter fades itself here; Visibility only
-- says when it is wanted, in its fade group too, and tells ApplyVisibility when that changes. (The
-- old damagemeter.* fade keys are copied over once by Visibility.lua MigrateMovedFades.)

-- Faded Opacity: how far the meter fades out (0 = gone). Not for the Meter tab in the chat, where the
-- tab decides and a faded meter sits under the chat.
local function DownAlpha()
    local V = ns.Visibility
    local v = V and V.GetMinAlpha and V:GetMinAlpha("meter") or 0
    return math_max(0, math_min(1, (tonumber(v) or 0) / 100))
end

-- Show Speed (coming back) / Hide Speed (fading away): the meter's, in its group the group's.
-- On the Meter tab in the chat they still fade it in and out as the tabs switch.
function DamageMeter.FadeSpeed(_, field)
    local V = ns.Visibility
    if not V then return "instant" end
    if field == "fadeIn" then return V:GetFadeIn("meter") end
    return V:GetFadeOut("meter")
end

-- Wanted by its Visibility (or its fade group) now; Mouseover ticked (its own driver then shows it
-- under the pointer). Edit Mode and the settings page are handled in ApplyVisibility.
function DamageMeter.HideUntilGroup()
    DamageMeter.hiddenUntilGroup = true
    if not DamageMeter.groupWatch then
        local watch = CreateFrame("Frame")
        watch:RegisterEvent("GROUP_JOINED")
        watch:SetScript("OnEvent", function()
            if not DamageMeter.hiddenUntilGroup then return end
            DamageMeter.hiddenUntilGroup = nil
            DamageMeter:ApplyVisibility()
        end)
        DamageMeter.groupWatch = watch
    end
    DamageMeter:ApplyVisibility()
end
function DamageMeter.Wanted()
    local V = ns.Visibility
    if not (V and V.ElementShown) then return true end
    return V:ElementShown("meter")
end
function DamageMeter.MouseShows()
    local V = ns.Visibility
    return V and V.HasToken and V:HasToken("meter", "mouseover") or false
end
-- the pointer on the meter (in a fade group, it brings the group back)
function DamageMeter.FadeMouse()
    local meter = _G.DamageMeter
    if not (meter and meter:IsVisible()) then return false end
    return MeterUnderMouse(meter) and not PanelsInTheWay()
end

local function FadeStep(self, meter, elapsed)
    -- While waiting for the cursor, a check every 0.1 s is enough.
    self.restWait = (self.restWait or 0) + elapsed
    if self.atRest and self.restWait < 0.1 then return end
    elapsed = self.restWait
    self.restWait = 0
    local target = fadeTarget
    if meter.FlareUI_MouseHidden then target = (MeterUnderMouse(meter) and not PanelsInTheWay()) and 1 or DownAlpha() end
    local alpha = meter:GetAlpha()
    -- Hold a visible meter during auto-hide. Once it reaches its faded opacity, only Show on Mouseover can reveal it.
    if autoFading and meter:IsShown() and alpha > target and MeterUnderMouse(meter) then
        -- Discard this frame's time so the fade resumes smoothly on the next frame.
        self.atRest = false
        return
    end
    -- Show Speed while coming back, Hide Speed while fading away (at rest there is nothing to time)
    local speed = alpha == target and "instant" or DamageMeter.FadeSpeed(GetDb(), alpha < target and "fadeIn" or "fadeOut")
    local time = ns.FadeTime(speed)
    if alpha ~= target and (alpha < target or speed ~= "slower") then self.stageHold = nil end
    if speed == "slower" and alpha > target then
        -- Slower: down to the resting opacity, rest, then finish (ns.StagedFall, Core.lua)
        alpha = ns.StagedFall(self, alpha, target, elapsed)
    elseif time <= 0 then
        alpha = target
    elseif alpha < target then
        alpha = math_min(target, alpha + elapsed / time)
    else
        alpha = math_max(target, alpha - elapsed / time)
    end
    self.atRest = alpha == target and meter:GetAlpha() == target
    if not self.atRest then meter:SetAlpha(alpha) end
    if alpha ~= target then return end
    autoFading = false
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
local function FadeMeter(meter, target, hide, autoHide)
    fadeTarget, hideWhenFaded = target, hide and true or false
    autoFading = autoHide and true or false
    fadeDriver.atRest, fadeDriver.restWait = false, 0
    fadeDriver:Show()
    FadeStep(fadeDriver, meter, 0)
end

-- Blizzard's switch for the meter is on and the meter can be used here
function MeterAllowed()
    if C_CVar.GetCVarBool and not C_CVar.GetCVarBool("damageMeterEnabled") then return false end
    if C_DamageMeter and C_DamageMeter.IsDamageMeterAvailable and not C_DamageMeter.IsDamageMeterAvailable() then return false end
    return true
end

-- Fade Delay (as the chat's): the meter stays up this many seconds after its Visibility stops
-- showing it, then fades. Back to showing in the meantime: the wait is dropped.
local function CancelFadeDelay()
    if DamageMeter.fadeDelayTimer then DamageMeter.fadeDelayTimer:Cancel() end
    DamageMeter.fadeDelayTimer = nil
end
local function FadeDelay()
    local V = ns.Visibility
    return V and V.GetFadeDelay and V:GetFadeDelay("meter") or 0
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
    local wasUp = meter.FlareUI_Up or autoFading
    -- Edit Mode open: always up, its "Damage Meter" box ticked or not; Blizzard's switch off stays off
    local editing = (type(meter.IsEditing) == "function" and meter:IsEditing()) or (IsEditModeActive() and MeterAllowed())
    meter.FlareUI_MouseHidden = nil
    if editing or DamageMeter.settingsPreview then
        CancelFadeDelay()
        -- a fade under way (or Show on Mouseover's driver) would take it down again
        fadeTarget, hideWhenFaded = 1, false
        autoFading = false
        fadeDriver:Hide()
        ShowMeter(meter)
        meter:SetAlpha(1)
        meter.FlareUI_Up = true
    elseif not MeterAllowed() or DamageMeter.hiddenUntilGroup then
        hideWhenFaded = false
        autoFading = false
        meter:Hide()
        if DamageMeter.viewBackPending then DamageMeter.ShowDamageViews() end
        meter.FlareUI_Up = false
    elseif DamageMeter.Wanted() then
        CancelFadeDelay()
        -- from where a fade out left it, or from nothing when it was hidden
        if not wasUp and not meter:IsShown() then meter:SetAlpha(0) end
        -- held back in a fight (ShowMeter): it stays down, and comes up with its fade after it
        local shown = ShowMeter(meter)
        meter.FlareUI_Up = shown
        if shown then FadeMeter(meter, 1) end
    elseif wasUp and not meter:IsShown() and not (meter:GetAlpha() > DownAlpha()
        and MeterUnderMouse(meter) and not PanelsInTheWay() and ShowMeter(meter)) then
        -- Blizzard already hid it. Start at the faded opacity if the settings keep the frame up.
        CancelFadeDelay()
        autoFading, hideWhenFaded = false, false
        fadeDriver:Hide()
        if DamageMeter.viewBackPending then DamageMeter.ShowDamageViews() end
        meter.FlareUI_Up = false
        local down = DownAlpha()
        local mouseShows = DamageMeter.MouseShows()
        if mouseShows or down > 0 then
            meter:SetAlpha(down)
            if ShowMeter(meter) and mouseShows then
                meter.FlareUI_MouseHidden = true
                FadeMeter(meter, down)
            end
        end
    elseif wasUp and not autoFading and FadeDelay() > 0 and not DamageMeter.fadeDelayDone then
        -- Fade Delay: it stays up for a while, then this check runs again and lets it go
        if not DamageMeter.fadeDelayTimer then
            DamageMeter.fadeDelayTimer = C_Timer.NewTimer(FadeDelay(), function()
                DamageMeter.fadeDelayTimer = nil
                DamageMeter.fadeDelayDone = true
                DamageMeter:ApplyVisibility()
                DamageMeter.fadeDelayDone = nil
            end)
        end
    elseif DamageMeter.MouseShows() then
        if not wasUp and not meter:IsShown() then meter:SetAlpha(0) end
        if ShowMeter(meter) then
            meter.FlareUI_MouseHidden = true
            FadeMeter(meter, DownAlpha())
        end
        meter.FlareUI_Up = false
    elseif DownAlpha() > 0 then
        -- Faded Opacity: faded, not gone (held back in a fight like any show, ShowMeter)
        meter.FlareUI_Up = false
        if not wasUp and not meter:IsShown() then meter:SetAlpha(0) end
        if ShowMeter(meter) then FadeMeter(meter, DownAlpha(), false, wasUp) end
    elseif wasUp then
        -- it was up: on screen for its fade out, hidden at the end (already hidden: nothing to fade)
        meter.FlareUI_Up = false
        if ShowMeter(meter) then
            FadeMeter(meter, 0, true, true)
        else
            hideWhenFaded = false
            autoFading = false
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
        hooksecurefunc(meter, "SetupSessionWindow", function(_, _, windowData)
            local window = windowData and windowData.sessionWindow
            -- Blizzard placed it on its own again: docked by the next Refresh (23b)
            if window then
                Dock.lastSetup = window
                SafeCall(Dock.Release, window)
            end
            -- Style the initialized session even when the meter itself is hidden.
            if window and not InFight() then
                SafeCall(DamageMeter.ApplyToWindow, DamageMeter, window)
            end
            C_Timer.After(0, function() DamageMeter:Refresh() end)
        end)
    end
    Dock.Hook(meter)
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
    -- An expired fade delay starts the fade from the currently shown frame.
    if not (self.fadeDelayDone and meter:IsShown()) and not self:ChatTabAvailable()
        and not InCombatLockdown() and type(meter.ShouldBeShown) == "function" then
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
-- Open the Meter Tab: When Clicked ("click") never switches on its own; In Combat and In Group ticked as
-- toggles (ns.Conditions) switch to the meter while either holds; At Login opens it on the first check
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
    -- docked tabs that aren't shown go one strata under again (23b)
    if Dock.List() then SafeCall(Dock.Stack) end
    -- the chat's header (its tabs and buttons) stays over the meter, in its strata
    if ns.Chat and ns.Chat.ApplyHeaderStrata then SafeCall(ns.Chat.ApplyHeaderStrata) end
end

--------------------------------------------------
-- 23b. METER WINDOWS AS TABS (like the chat's tabs)
-- Blizzard's extra meter windows (the gear menu's "Show New Window") sit in the first window's place
-- as tabs in its title row, before the Threat tab, which stays last. Two meter windows at most: at
-- two the gear menu's "Show New Window" is greyed out (Blizzard allows three; a third window that
-- is already open stays, as a tab). Windows open and close only through Blizzard's own menu entries
-- ("Show New Window", "Hide Window"): run from addon code they would taint the window, whose list
-- reads secret values in a fight. The first window can't be closed (Blizzard's rule).
-- Each docked window covers the first. The one shown is up (Blizzard's window alpha, the meter's
-- strata, the mouse); the others are invisible one strata lower, under it. Every docked window draws
-- the same tab row: its own title (left-click shows it, right-click is Blizzard's type menu) where
-- its tab belongs, the other windows as FlareUI tabs, then Threat. Threat lives on the first window.
--------------------------------------------------
Dock.MAX = 2

-- Blizzard's count: the meter windows open now
function Dock.Count()
    local n = 0
    for _, w in ipairs(GetSessionWindows()) do
        if w:IsShown() then n = n + 1 end
    end
    return n
end

-- the windows in the tab row, in Blizzard's order (nil: one window, or the module off)
function Dock.List()
    local db = GetDb()
    if not (db and db.enabled) then return nil end
    local primary = _G.DamageMeterSessionWindow1
    if not (primary and primary:IsShown()) then return nil end
    local list
    for _, w in ipairs(GetSessionWindows()) do
        if w ~= primary and w.FlareUI_Docked and w:IsShown() then
            list = list or { primary }
            list[#list + 1] = w
        end
    end
    return list
end

function Dock.Row(window)
    local list = Dock.List()
    if list and tContains(list, window) then return list end
end

-- the threat list is up (on the first window)
function Dock.ThreatShown()
    local view = views[_G.DamageMeterSessionWindow1]
    return view and view.showing or false
end

-- the window on top: the first while Threat is up, else the picked tab
function Dock.Top(list)
    if Dock.ThreatShown() then return list[1] end
    if Dock.current and tContains(list, Dock.current) then return Dock.current end
    return list[1]
end

-- Blizzard's window opacity (its Edit Mode setting)
function Dock.WindowAlpha()
    local meter = _G.DamageMeter
    local alpha = meter and type(meter.GetWindowAlpha) == "function" and meter:GetWindowAlpha()
    if canaccessvalue(alpha) and type(alpha) == "number" then return alpha end
    return 1
end

-- a docked window up (seen, takes the mouse) or down (invisible, a strata under the one up)
function Dock.Raise(window, up)
    local meter = _G.DamageMeter
    local base = meter and meter:GetFrameStrata()
    if not (canaccessvalue(base) and base) then base = "MEDIUM" end
    local strata = base
    if not up then strata = STRATA_ORDER[math_max((tIndexOf(STRATA_ORDER, base) or 3) - 1, 1)] end
    local function Set(frame)
        if frame and not frame:IsForbidden() and frame:GetFrameStrata() ~= strata then frame:SetFrameStrata(strata) end
    end
    Set(window)
    Set(window.FlareUI_DMSkin)
    for _, btn in pairs(GROUP_BUTTONS.buttons[window] or {}) do Set(btn) end
    window:SetAlpha(up and Dock.WindowAlpha() or 0)
    local locked = window.IsNonInteractive and window:IsNonInteractive()
    window:EnableMouse((up and not locked) and true or false)
    window.FlareUI_DockUp = up and true or false
end

-- A docked window that isn't up keeps its own title (Blizzard's type button, placed where its tab is,
-- Dock.PlaceTitle) and its left-click area (view.hit) above the tab in the shown window's row:
-- invisible (the window is at alpha 0) but there for the mouse. Left-click picks the tab;
-- right-click reaches Blizzard's own type menu from Blizzard's own button, so nothing of the meter is
-- opened or set by FlareUI (taint). Only the strata and frame levels change, and they go back when it
-- is up again.
function Dock.LiftTitle(window, lift, top)
    local dd = GetWindowTypeDropdown(window)
    if not dd or dd:IsForbidden() then return end
    local view = views[window]
    local hit = view and view.hit
    if lift then
        local meter = _G.DamageMeter
        local strata = meter and meter:GetFrameStrata()
        if not (canaccessvalue(strata) and strata) then strata = "MEDIUM" end
        dd.FlareUI_LevelWas = dd.FlareUI_LevelWas or dd:GetFrameLevel()
        local topDD = top and GetWindowTypeDropdown(top)
        local level = math_max(dd.FlareUI_LevelWas, topDD and topDD:GetFrameLevel() or 0) + 10
        dd:SetFrameStrata(strata)
        dd:SetFrameLevel(level)
        if hit then
            hit:SetFrameStrata(strata)
            hit:SetFrameLevel(level + 2)
        end
    elseif dd.FlareUI_LevelWas then
        local strata = window:GetFrameStrata()
        dd:SetFrameStrata(strata)
        dd:SetFrameLevel(dd.FlareUI_LevelWas)
        if hit then
            hit:SetFrameStrata(strata)
            hit:SetFrameLevel(dd.FlareUI_LevelWas + 2)
        end
        dd.FlareUI_LevelWas = nil
    end
end

-- the tab for this window in the row of the window that is up (nil while it is up itself)
function Dock.ShownLabel(window)
    local list = Dock.List()
    if not (list and tContains(list, window)) then return nil end
    local top = Dock.Top(list)
    if top == window then return nil end
    return top.FlareUI_DockLabels and top.FlareUI_DockLabels[window]
end

-- into the first window's place (out of a fight, from Refresh)
function Dock.Attach(window, primary)
    window.FlareUI_Docked = true
    window.FlareUI_FreePlaced = nil
    window:ClearAllPoints()
    window:SetAllPoints(primary)
    window:RegisterForDrag()   -- dragging its header would pull it out
    local resize = window.GetResizeButton and window:GetResizeButton()
    if resize then resize:Hide() end   -- and so would its sizing corner
end

-- out of the row (closed, or set up again by Blizzard): Blizzard's own window again
function Dock.Release(window)
    window.FlareUI_FreePlaced = nil   -- a window on its own takes its saved spot again (Dock.Free)
    if not window.FlareUI_Docked then return end
    window.FlareUI_Docked = nil
    window:RegisterForDrag("LeftButton")
    local resize = window.GetResizeButton and window:GetResizeButton()
    if resize then resize:Show() end
    if window.FlareUI_DockUp == false then Dock.Raise(window, true) end
    window.FlareUI_DockUp = nil
    Dock.LiftTitle(window, false)
end

-- the shown tab up, the rest down, and every tab row laid out again
function Dock.Stack()
    local list = Dock.List()
    for _, w in ipairs(GetSessionWindows()) do
        if w.FlareUI_Docked and not (list and tContains(list, w)) then Dock.Release(w) end
    end
    local primary = _G.DamageMeterSessionWindow1
    if list then
        -- a window's own threat list (from before it docked) gives way to its meter list
        for i = 2, #list do
            local view = views[list[i]]
            if view and view.showing then
                view.showing = false
                view.frame:Hide()
                SetBlizzardListShown(list[i], true)
                WatchThreat()
            end
        end
        local top = Dock.Top(list)
        for _, w in ipairs(list) do SafeCall(Dock.Raise, w, w == top) end
        -- the windows down lend their titles to their tabs (Dock.LiftTitle)
        for _, w in ipairs(list) do SafeCall(Dock.LiftTitle, w, w ~= top, top) end
    elseif primary and primary.FlareUI_DockUp ~= nil then
        if primary.FlareUI_DockUp == false then Dock.Raise(primary, true) end
        primary.FlareUI_DockUp = nil
    end
    for _, w in ipairs(GetSessionWindows()) do
        if views[w] then SafeCall(LayoutTabs, w, views[w]) end
    end
end

-- Refresh, out of a fight: every open extra window into the first one's place
function Dock.Update()
    local primary = _G.DamageMeterSessionWindow1
    local db = GetDb()
    if primary and primary:IsShown() and db and db.enabled then
        for _, w in ipairs(GetSessionWindows()) do
            if w ~= primary and w:IsShown() then
                -- a window the player moved to its own window stays out of the row (Dock.Free)
                if Dock.IsFree(w) then
                    if Dock.current == w then Dock.current = nil end
                    SafeCall(Dock.Free, w)
                else
                    SafeCall(Dock.Attach, w, primary)
                end
            end
        end
    end
    -- a window just opened from the gear menu shows at once, as a new chat tab does
    local new = Dock.newWindow
    Dock.newWindow = nil
    if new and Dock.Row(new) then
        Dock.Select(new)
    else
        Dock.Stack()
    end
end

-- a meter tab clicked: that window up (Threat, if it was up, goes down)
function Dock.Select(window)
    Dock.current = window
    local primary = _G.DamageMeterSessionWindow1
    if views[primary] and views[primary].showing then
        PickView(primary, false)   -- stacks again through SetView
    else
        Dock.Stack()
    end
end

function Dock.PickThreat()
    local primary = _G.DamageMeterSessionWindow1
    if views[primary] then PickView(primary, true) end
end

-- another window's tab in this window's row: FlareUI's, as the Threat tab
function Dock.Label(window, other)
    window.FlareUI_DockLabels = window.FlareUI_DockLabels or {}
    local label = window.FlareUI_DockLabels[other]
    if label then return label end
    local dd = GetWindowTypeDropdown(window)
    label = CreateFrame("Button", nil, window)
    label:SetFrameLevel(dd:GetFrameLevel() + 3)
    label.Text = label:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label.Text:SetPoint("LEFT", label, "LEFT", 4, 0)
    label:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    label:SetScript("OnClick", function(self, button)
        -- right-click: Move to Own Window (the first window is the row's home: it has no menu)
        if button == "RightButton" then
            if other ~= _G.DamageMeterSessionWindow1 then Dock.OpenMenu(self, other) end
            return
        end
        Dock.Select(other)
    end)
    label:SetScript("OnEnter", function(self)
        local r, g, b = LightenColor(TAB_INACTIVE.r, TAB_INACTIVE.g, TAB_INACTIVE.b, 0.2)
        self.Text:SetTextColor(r, g, b)
    end)
    label:SetScript("OnLeave", function(self) ColorTab(self.Text, false) end)
    window.FlareUI_DockLabels[other] = label
    return label
end

-- the tabs of windows no longer in this window's row
function Dock.HideLabels(window, row)
    for other, label in pairs(window.FlareUI_DockLabels or {}) do
        if not (row and tContains(row, other)) then label:Hide() end
    end
end

function Dock.TitleOf(window)
    local dd = GetWindowTypeDropdown(window)
    local text = dd and dd.TypeName and dd.TypeName:GetText()
    if canaccessvalue(text) and type(text) == "string" then return text end
    return "?"
end

-- the window's own title (Blizzard's type button) where its tab belongs; out of a fight, as the header
function Dock.PlaceTitle(window, dd, ref, textX)
    if (dd.FlareUI_TextX or TITLE_LEFT) == textX or InCombatLockdown() then return end
    dd.FlareUI_TextX = textX ~= TITLE_LEFT and textX or nil
    if dd.TypeName and dd.TypeName.ClearAllPoints then
        dd.TypeName:ClearAllPoints()
        dd.TypeName:SetPoint("LEFT", ref, "TOPLEFT", textX, ROW_CENTER_Y)
        dd.TypeName:SetPoint("RIGHT", dd, "RIGHT", -4, 0)
    end
    if dd.ClearAllPoints then
        dd:ClearAllPoints()
        dd:SetPoint("TOPLEFT", ref, "TOPLEFT", DamageMeter.TitleButtonLeft(textX), 0)
        FitTitleButton(window)
    end
end

-- the gear menu: "Show New Window" greyed out at two windows (Blizzard's entry, only disabled)
function Dock.LimitMenu(rootDescription)
    if Dock.Count() < Dock.MAX then return end
    local label = _G.DAMAGE_METER_SHOW_NEW_WINDOW
    if not label then return end
    for _, desc in rootDescription:EnumerateElementDescriptions() do
        if MenuUtil.GetElementText(desc) == label then
            desc:SetEnabled(false)
            if desc.SetTooltip then
                desc:SetTooltip(function(tooltip)
                    GameTooltip_SetTitle(tooltip, label)
                    GameTooltip_AddNormalLine(tooltip, L["You can have two meter windows. Close one to open another."])
                end)
            end
        end
    end
end

-- Blizzard opens and closes the windows; FlareUI follows
function Dock.Hook(meter)
    if Dock.hooked then return end
    Dock.hooked = true
    if type(meter.ShowNewSecondarySessionWindow) == "function" then
        hooksecurefunc(meter, "ShowNewSecondarySessionWindow", function()
            Dock.newWindow = Dock.lastSetup
        end)
    end
    if type(meter.HideSessionWindow) == "function" then
        hooksecurefunc(meter, "HideSessionWindow", function(_, window)
            if Dock.current == window then Dock.current = nil end
            -- closed: the next window opened in its place starts as a tab again
            if window then Dock.SetFree(window, nil) end
            SafeCall(Dock.Stack)
        end)
    end
    -- Blizzard's window opacity sets every window: the hidden tabs go invisible again
    if type(meter.OnWindowAlphaChanged) == "function" then
        hooksecurefunc(meter, "OnWindowAlphaChanged", function()
            if Dock.List() then SafeCall(Dock.Stack) end
        end)
    end
end

--------------------------------------------------
-- 23c. A METER WINDOW ON ITS OWN
-- Right-click another window's tab (or a window's own title, or its gear menu): Move to Own Window.
-- The window leaves the row and is Blizzard's own again (dragged by its header, sized by its corner),
-- first placed beside the first window, inside the screen. Kept per window number with its spot and
-- size (damagemeter.freeWindows), so it stays on its own after a /reload; its title's right-click and
-- its gear menu then offer Dock as a Tab. Closing it (Blizzard's "Hide Window") forgets it: the next
-- window opened in its place starts as a tab. Moving waits for the end of a fight, as the row's own
-- placing does (Refresh). The Threat tab's Move to Own Window is Threat > Separate Window; the
-- separate threat window's Dock as a Tab (right-click its header) turns that off.
--------------------------------------------------
Dock.FREE_GAP = 8   -- between the two windows, past their skins

-- Blizzard's window number (DamageMeterSessionWindow<n>)
function Dock.Index(window)
    local index = window.GetSessionWindowIndex and window:GetSessionWindowIndex()
    if type(index) ~= "number" then index = tonumber((window:GetName() or ""):match("(%d+)$")) end
    return index
end

-- its saved spot while it is on its own (a table, empty until first placed), else nil
function Dock.FreeSpot(window)
    local db = GetDb()
    local index = Dock.Index(window)
    return db and index and type(db.freeWindows) == "table" and db.freeWindows[index] or nil
end

function Dock.IsFree(window)
    return window ~= _G.DamageMeterSessionWindow1 and Dock.FreeSpot(window) ~= nil
end

function Dock.SetFree(window, free)
    local db = GetDb()
    local index = Dock.Index(window)
    if not (db and index) then return end
    if free then
        if type(db.freeWindows) ~= "table" then db.freeWindows = {} end
        db.freeWindows[index] = db.freeWindows[index] or {}
    elseif type(db.freeWindows) == "table" then
        db.freeWindows[index] = nil
        if next(db.freeWindows) == nil then db.freeWindows = nil end
    end
end

function Dock.Num(value)
    return canaccessvalue(value) and type(value) == "number" and value or nil
end

-- where it is now (left and top on the screen, in its own scale) and its size
function Dock.SaveSpot(window)
    local spot = Dock.FreeSpot(window)
    if not spot or window.FlareUI_Docked then return end
    local left, top = Dock.Num(window:GetLeft()), Dock.Num(window:GetTop())
    local width, height = Dock.Num(window:GetWidth()), Dock.Num(window:GetHeight())
    if not (left and top and width and height) or width <= 0 or height <= 0 then return end
    spot.x, spot.y = math.floor(left + 0.5), math.floor(top + 0.5)
    spot.w, spot.h = math.floor(width + 0.5), math.floor(height + 0.5)
end

-- first time on its own: the first window's size, under it when the first window sits in the top half
-- of the screen, else above it; the other side when there's no room, then inside the screen
function Dock.SpotBeside(window, spot)
    local primary = _G.DamageMeterSessionWindow1
    if not primary then return end
    local pl, pb, pw, ph = primary:GetRect()
    pl, pb, pw, ph = Dock.Num(pl), Dock.Num(pb), Dock.Num(pw), Dock.Num(ph)
    if not (pl and pb and pw and ph) or pw <= 0 or ph <= 0 then return end
    local k = primary:GetEffectiveScale() / window:GetEffectiveScale()   -- the first window's units to this one's
    local ui = UIParent:GetEffectiveScale() / window:GetEffectiveScale()
    local screenW, screenH = UIParent:GetWidth() * ui, UIParent:GetHeight() * ui
    local width, height = pw * k, ph * k
    local gap = Dock.FREE_GAP + 2 * SKIN_PADDING
    local bottomEdge, topEdge = pb * k, (pb + ph) * k
    local below = (bottomEdge + topEdge) / 2 > screenH / 2
    local top = below and (bottomEdge - gap) or (topEdge + gap + height)
    if below and top - height < 0 then
        top = topEdge + gap + height
    elseif not below and top > screenH then
        top = bottomEdge - gap
    end
    top = math_max(height, math_min(top, screenH))
    local left = math_max(0, math_min(pl * k, screenW - width))
    spot.x, spot.y = math.floor(left + 0.5), math.floor(top + 0.5)
    spot.w, spot.h = math.floor(width + 0.5), math.floor(height + 0.5)
end

-- its moves and new sizes are kept (only while it is on its own: docked, it can't be dragged)
function Dock.HookFree(window)
    if window.FlareUI_FreeHooked then return end
    window.FlareUI_FreeHooked = true
    window:HookScript("OnDragStop", function(self) SafeCall(Dock.SaveSpot, self) end)
    local resize = window.GetResizeButton and window:GetResizeButton()
    if resize then resize:HookScript("OnMouseUp", function() SafeCall(Dock.SaveSpot, window) end) end
end

-- out of the row, on its saved spot (out of a fight, from Dock.Update)
function Dock.Free(window)
    if window.FlareUI_Docked then Dock.Release(window) end
    Dock.HookFree(window)
    -- its own threat list (from before) gives way to its meter list, and its Threat tab goes
    if views[window] then SetView(window, false) end
    if window.FlareUI_FreePlaced then return end
    local spot = Dock.FreeSpot(window)
    if not spot then return end
    if not (spot.x and spot.y and spot.w and spot.h) then Dock.SpotBeside(window, spot) end
    if not (spot.x and spot.y and spot.w and spot.h) then return end
    window.FlareUI_FreePlaced = true
    window:ClearAllPoints()
    window:SetSize(spot.w, spot.h)
    window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", spot.x, spot.y)
end

-- the menu entries: saved now, placed now or when the fight ends
function Dock.MoveOut(window)
    if window == _G.DamageMeterSessionWindow1 then return end
    Dock.SetFree(window, true)
    if Dock.current == window then Dock.current = nil end
    if InFight() then DamageMeter._pendingRefresh = true; return end
    SafeCall(Dock.Update)
end

function Dock.MoveIn(window)
    Dock.SetFree(window, nil)
    window.FlareUI_FreePlaced = nil
    if InFight() then DamageMeter._pendingRefresh = true; return end
    Dock.newWindow = window   -- shown at once, as a window just opened
    SafeCall(Dock.Update)
end

-- in a fight the entry says it waits (no print)
function Dock.FightTip(desc, label)
    if not (InFight() and desc and desc.SetTooltip) then return end
    desc:SetTooltip(function(tooltip)
        GameTooltip_SetTitle(tooltip, label)
        GameTooltip_AddNormalLine(tooltip, L["Happens when the fight ends."])
    end)
end

-- Move to Own Window (a tab) or Dock as a Tab (on its own); the first window gets neither
function Dock.AddEntries(root, window, divider)
    if window == _G.DamageMeterSessionWindow1 or not window:IsShown() then return end
    local free = Dock.IsFree(window)
    if not free and not Dock.Row(window) then return end
    if divider then root:CreateDivider() end
    local label = free and L["Dock as a Tab"] or L["Move to Own Window"]
    local button = root:CreateButton(label, function()
        if free then Dock.MoveIn(window) else Dock.MoveOut(window) end
    end)
    Dock.FightTip(button, label)
    -- Close Tab / Close Window: Blizzard's Hide Window (in the window's gear menu,
    -- out of reach on a tab). Blizzard's call only hides the window and saves that it is hidden; the
    -- next window opened in its place starts as a tab again (Dock.Hook).
    local meter = _G.DamageMeter
    if meter and type(meter.HideSessionWindow) == "function" then
        root:CreateButton(free and L["Close Window"] or L["Close Tab"], function()
            SafeCall(meter.HideSessionWindow, meter, window)
        end)
    end
end

-- FlareUI's own small menu (another window's tab)
function Dock.OpenMenu(owner, window)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(owner, function(_, root) Dock.AddEntries(root, window, false) end)
end

-- Blizzard's title and gear menus (Menu.ModifyMenu, from Init): the window whose button opened it
function Dock.ModifyWindowMenu(owner, root, getPart)
    local db = GetDb()
    if not (db and db.enabled and owner) then return end
    for _, w in ipairs(GetSessionWindows()) do
        if getPart(w) == owner then
            Dock.AddEntries(root, w, true)
            return
        end
    end
end

-- the Threat tab (out = true) or the separate threat window's header (false)
function Dock.OpenThreatMenu(owner, out)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        local label = out and L["Move to Own Window"] or L["Dock as a Tab"]
        local button = root:CreateButton(label, function() DamageMeter.SetThreatWindow(out) end)
        Dock.FightTip(button, label)
    end)
end

-- Report to Chat: the window's top names sent to a chat channel from the menu click
-- itself (a hardware event, no timers). Out of a fight only: in a fight the meter's values are secret
-- and the chat may be locked down. A row whose name or number can't be read is left out.
-- Table fields, not main-chunk locals (near Lua's 200 limit).
DamageMeter.Report = {
    LINES = { 3, 5, 10 },
    MAX_LEN = 254,
    -- action types: a count, no per-second figure (as Blizzard's own list)
    NO_RATE = { Interrupts = true, Dispels = true, Deaths = true },
}

function DamageMeter.Report.Lines()
    local db = GetDb()
    local n = db and tonumber(db.reportLines)
    if n == 3 or n == 5 or n == 10 then return n end
    return 5
end

function DamageMeter.Report.Blocked()
    if InFight() then return true end
    local lockdown = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown
    if lockdown then
        local ok, locked = pcall(lockdown)
        if ok and (not canaccessvalue(locked) or locked) then return true end
    end
    return false
end

function DamageMeter.Report.Text(value)
    if canaccessvalue(value) and type(value) == "string" and value ~= "" then return value end
end

function DamageMeter.Report.TypeKey(meterType)
    if not (Enum and Enum.DamageMeterType) then return nil end
    for key, value in pairs(Enum.DamageMeterType) do
        if value == meterType then return key end
    end
end

-- what the window's title shows (Damage Done, Healing Done...)
function DamageMeter.Report.TypeName(window)
    local fs = window.GetDamageMeterTypeName and window:GetDamageMeterTypeName()
    local text = fs and fs.GetText and DamageMeter.Report.Text(fs:GetText())
    if text then return text end
    local key = DamageMeter.Report.TypeKey(window.GetDamageMeterType and window:GetDamageMeterType())
    local names = {
        DamageDone = _G.DAMAGE_METER_TYPE_DAMAGE_DONE, Dps = _G.DAMAGE_METER_TYPE_DPS,
        HealingDone = _G.DAMAGE_METER_TYPE_HEALING_DONE, Hps = _G.DAMAGE_METER_TYPE_HPS,
        Absorbs = _G.DAMAGE_METER_TYPE_ABSORBS, Interrupts = _G.DAMAGE_METER_TYPE_INTERRUPTS,
        Dispels = _G.DAMAGE_METER_TYPE_DISPELS, DamageTaken = _G.DAMAGE_METER_TYPE_DAMAGE_TAKEN,
        AvoidableDamageTaken = _G.DAMAGE_METER_TYPE_AVOIDABLE_DAMAGE_TAKEN,
        Deaths = _G.DAMAGE_METER_TYPE_DEATHS, EnemyDamageTaken = _G.DAMAGE_METER_TYPE_ENEMY_DAMAGE_TAKEN,
    }
    return key and names[key] or L["Damage Meter"]
end

-- Current / Overall, or the past fight's name (as Blizzard's session list names it)
function DamageMeter.Report.SessionName(window)
    local id = window.GetSessionID and window:GetSessionID()
    if id ~= nil then
        local ok, list = pcall(C_DamageMeter.GetAvailableCombatSessions)
        if ok and type(list) == "table" then
            for _, s in ipairs(list) do
                if s.sessionID == id then
                    local name = DamageMeter.Report.Text(s.name)
                    if name then return name end
                end
            end
        end
        local fmt = _G.DAMAGE_METER_COMBAT_NUMBER
        return fmt and fmt:format(id) or tostring(id)
    end
    local kind = window.GetSessionType and window:GetSessionType()
    local types = Enum and Enum.DamageMeterSessionType
    if types and kind == types.Overall then return _G.DAMAGE_METER_OVERALL_SESSION or L["Overall"] end
    return _G.DAMAGE_METER_CURRENT_SESSION or L["Current"]
end

function DamageMeter.Report.Session(window)
    if not C_DamageMeter then return nil end
    local meterType = window.GetDamageMeterType and window:GetDamageMeterType()
    if meterType == nil then return nil end
    local id = window.GetSessionID and window:GetSessionID()
    local ok, session
    if id ~= nil then
        ok, session = pcall(C_DamageMeter.GetCombatSessionFromID, id, meterType)
    else
        local kind = window.GetSessionType and window:GetSessionType()
        if kind == nil then return nil end
        ok, session = pcall(C_DamageMeter.GetCombatSessionFromType, kind, meterType)
    end
    if ok and type(session) == "table" then return session end
end

function DamageMeter.Report.Duration(window, session)
    local seconds = Dock.Num(session.durationSeconds)
    if not seconds then
        local kind = window.GetSessionType and window:GetSessionType()
        if kind ~= nil and C_DamageMeter.GetSessionDurationSeconds then
            local ok, s = pcall(C_DamageMeter.GetSessionDurationSeconds, kind)
            if ok then seconds = Dock.Num(s) end
        end
    end
    if not seconds then return nil end
    seconds = math.floor(seconds + 0.5)
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

function DamageMeter.Report.Fit(text)
    if #text > DamageMeter.Report.MAX_LEN then return text:sub(1, DamageMeter.Report.MAX_LEN) end
    return text
end

-- the header and up to 10 rows (11 lines at most), or nil when nothing can be read
function DamageMeter.Report.Build(window)
    local session = DamageMeter.Report.Session(window)
    local sources = session and session.combatSources
    if type(sources) ~= "table" then return nil end
    local noRate = DamageMeter.Report.NO_RATE[DamageMeter.Report.TypeKey(window:GetDamageMeterType()) or ""]
    local rows, rank = {}, 0
    local want = DamageMeter.Report.Lines()
    for _, source in ipairs(sources) do
        if rank >= want then break end
        local name = DamageMeter.Report.Text(source.name)
        local amount = Dock.Num(source.totalAmount)
        local rate = not noRate and Dock.Num(source.amountPerSecond)
        if name and amount and (noRate or rate) then
            rank = rank + 1
            local line = ("%d. %s  %s"):format(rank, name, ns.ShortNumber(math.floor(amount + 0.5)))
            if rate then line = line .. (" (%s/s)"):format(ns.ShortNumber(math.floor(rate + 0.5))) end
            rows[#rows + 1] = DamageMeter.Report.Fit(line)
        end
    end
    if #rows == 0 then return nil end
    local header = ("FlareUI: %s \226\128\147 %s"):format(DamageMeter.Report.TypeName(window), DamageMeter.Report.SessionName(window))
    local clock = DamageMeter.Report.Duration(window, session)
    if clock then header = header .. (" (%s)"):format(clock) end
    table.insert(rows, 1, DamageMeter.Report.Fit(header))
    return rows
end

function DamageMeter.Report.Send(window, chatType, target)
    if DamageMeter.Report.Blocked() then return end
    local lines = DamageMeter.Report.Build(window)
    if not lines then
        print("|cffCC9957FlareUI|r: " .. L["Nothing to report."])
        return
    end
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or _G.SendChatMessage
    for _, line in ipairs(lines) do
        send(line, chatType, nil, target)
    end
end

-- a player of your side as the target: their name with the realm (when it isn't yours)
function DamageMeter.Report.WhisperTarget()
    if not (UnitExists("target") and UnitIsPlayer("target")) or UnitIsUnit("target", "player") then return nil end
    if not UnitCanCooperate("player", "target") then return nil end
    local name, realm = UnitName("target")
    name, realm = DamageMeter.Report.Text(name), DamageMeter.Report.Text(realm)
    if not name then return nil end
    return realm and (name .. "-" .. realm) or name
end

-- the submenu: channels (only those usable now), Whisper Target, and Lines
function DamageMeter.Report.AddMenu(root, window)
    if not (window and window.GetDamageMeterType and C_DamageMeter) then return end
    root:CreateDivider()
    local sub = root:CreateButton(L["Report to Chat"])
    local blocked = DamageMeter.Report.Blocked()
    if blocked then
        sub:SetEnabled(false)
        if sub.SetTooltip then
            sub:SetTooltip(function(tooltip)
                GameTooltip_SetTitle(tooltip, L["Report to Chat"])
                GameTooltip_AddNormalLine(tooltip, L["Report after combat."])
            end)
        end
        return
    end
    local inInstance = IsInInstance()
    local channels = {
        { L["Say"], "SAY", inInstance and true or false },
        { L["Party"], "PARTY", IsInGroup(LE_PARTY_CATEGORY_HOME) },
        { L["Raid"], "RAID", IsInRaid(LE_PARTY_CATEGORY_HOME) },
        { L["Instance"], "INSTANCE_CHAT", IsInGroup(LE_PARTY_CATEGORY_INSTANCE) },
        { L["Guild"], "GUILD", IsInGuild() },
    }
    for _, c in ipairs(channels) do
        local chatType = c[2]
        local button = sub:CreateButton(c[1], function() DamageMeter.Report.Send(window, chatType) end)
        if not c[3] then
            button:SetEnabled(false)
            if chatType == "SAY" and button.SetTooltip then
                button:SetTooltip(function(tooltip)
                    GameTooltip_SetTitle(tooltip, L["Say"])
                    GameTooltip_AddNormalLine(tooltip, L["Say works only inside an instance."])
                end)
            end
        end
    end
    local whisper = sub:CreateButton(L["Whisper Target"], function()
        local who = DamageMeter.Report.WhisperTarget()
        if who then DamageMeter.Report.Send(window, "WHISPER", who) end
    end)
    if not DamageMeter.Report.WhisperTarget() then whisper:SetEnabled(false) end
    sub:CreateDivider()
    sub:CreateTitle(L["Lines"])
    for _, n in ipairs(DamageMeter.Report.LINES) do
        sub:CreateRadio(L["Top %d"]:format(n), function() return DamageMeter.Report.Lines() == n end, function()
            local db = GetDb()
            if db then db.reportLines = n end
            return MenuResponse and MenuResponse.Refresh
        end)
    end
end

-- Blizzard's title and gear menus: the window whose button opened it
function DamageMeter.Report.ModifyWindowMenu(owner, root, getPart)
    local db = GetDb()
    if not (db and db.enabled and owner) then return end
    for _, w in ipairs(GetSessionWindows()) do
        if getPart(w) == owner then
            DamageMeter.Report.AddMenu(root, w)
            return
        end
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
    local open = ns.Conditions.Set(db.chatTabOpen or "combat")
    local rule = ((open.combat and VISIBILITY.combat(meter)) or (open.group and VISIBILITY.group(meter))) and true or false
    if rule ~= DamageMeter.chatTabRule then
        local first = DamageMeter.chatTabRule == nil
        DamageMeter.chatTabRule = rule
        local want = rule or (first and open.login) or false
        if (DamageMeter.chatTabActive or false) ~= want then
            DamageMeter.chatTabActive = want
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
    autoFading = false
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
-- 23d. EDIT MODE DIALOG
-- Visibility, Transparency and Background leave the meter's Edit Mode dialog: FlareUI's own
-- Visibility overrules the first (section 22) and its skin replaces the other two, so they would do
-- nothing there. Done on the dialog's own rows after Blizzard builds them (as Minimap.lua trims the
-- minimap's), never in Blizzard's table: addon-written entries there would taint Edit Mode. Their
-- stored values are left as they are, unused.
--------------------------------------------------
local function TrimMeterDialog(dialog)
    local system = dialog and dialog.attachedToSystem
    if not (system and system.system == Enum.EditModeSystem.DamageMeter and dialog.Settings) then return end
    local db = GetDb()
    if not (db and db.enabled) then return end
    local setting = Enum.EditModeDamageMeterSetting
    -- (11-22) Blizzard's own Visibility stays in view while it is Hidden or In a Group: Blizzard
    -- applies it again as a fight starts and the meter can't come back until the fight ends, so the
    -- settings banner sends the player here to set it to Always (it was hidden, and they couldn't)
    local kinds, meter = Enum.DamageMeterVisibility, _G.DamageMeter
    local own = meter and meter.visibility
    local blocking = kinds and (own == kinds.Hidden or own == kinds.InGroup)
    local hidden = {
        [setting.Visibility] = not blocking,
        [setting.Transparency] = true,
        [setting.BackgroundTransparency] = true,
    }
    -- Text Size too: the meter's fonts are in FlareUI's settings (Meters › Fonts)
    if setting.TextSize then hidden[setting.TextSize] = true end
    local changed = false
    for _, row in ipairs({ dialog.Settings:GetChildren() }) do
        if row:IsShown() and row.setting and hidden[row.setting] then
            row:Hide()
            changed = true
        end
    end
    if changed then
        dialog.Settings:Layout()
        if dialog.Layout then dialog:Layout() end
    end
end

local function HookMeterDialog()
    local dialog = _G.EditModeSystemSettingsDialog
    if not (dialog and Enum.EditModeSystem.DamageMeter and Enum.EditModeDamageMeterSetting) or dialog.FlareUI_MeterTrim then return end
    dialog.FlareUI_MeterTrim = true
    hooksecurefunc(dialog, "UpdateSettings", TrimMeterDialog)
end

--------------------------------------------------
-- 24. INIT
--------------------------------------------------
-- BLIZZARD'S OWN VISIBILITY CHECK (11-22, Malkkav): Blizzard's meter Visibility on Hidden or In a
-- Group hides the meter as a fight starts, and no addon may show it again until the fight ends (nor
-- change Edit Mode's value: that taints Blizzard's meter). So once per session, out of a fight, a
-- small window says so and opens Edit Mode, where the row shows while it's wrong (TrimMeterDialog).
-- Don't Show Again: damagemeter.visibilityNoWarn.
ns.Dialogs["FLAREUI_METER_VISIBILITY"] = {
    text = L["Blizzard's own Visibility for the damage meter is set to In a Group or Hidden, so it will hide the meter when a fight starts.\n\nOpen Edit Mode, click the Damage Meter and set its Visibility to Always. FlareUI's own Visibility then decides when it shows."],
    button1 = L["Open Edit Mode"],
    button2 = L["Not Now"],
    button3 = L["Don't Show Again"],
    OnAccept = function() if ns.Settings and ns.Settings.OpenEditMode then ns.Settings:OpenEditMode("dm") end end,
    OnAlt = function()
        local db = GetDb()
        if db then db.visibilityNoWarn = true end
    end,
    hideOnEscape = true,
}
function DamageMeter.CheckBlizzardVisibility()
    local db = GetDb()
    if DamageMeter.visibilityWarned or not (db and db.enabled) or db.visibilityNoWarn then return end
    if InFight() or DamageMeter:ChatTabAvailable() or not MeterAllowed() then return end
    local kinds, meter = Enum.DamageMeterVisibility, _G.DamageMeter
    local own = meter and meter.visibility
    if not (kinds and (own == kinds.Hidden or own == kinds.InGroup)) then return end
    DamageMeter.visibilityWarned = true
    ns.ShowDialog("FLAREUI_METER_VISIBILITY")
end

function DamageMeter:Init()
    HookMeterDialog()
    -- (a moment after login, once Edit Mode has applied its layout)
    C_Timer.After(8, DamageMeter.CheckBlizzardVisibility)
    -- leaving Edit Mode restyles the windows (ApplyToWindow skips them while Edit Mode is open)
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
    self:RegisterEvent("GROUP_LEFT")
    GROUP_BUTTONS.events:RegisterEvent("GROUP_ROSTER_UPDATE")
    GROUP_BUTTONS.events:RegisterEvent("PARTY_LEADER_CHANGED")
    timerEvents:RegisterEvent("PLAYER_REGEN_DISABLED")
    timerEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
    timerEvents:RegisterEvent("GROUP_ROSTER_UPDATE")

    -- the meter's gear menu gets FlareUI's settings (its own "Open Settings" goes to a page this
    -- client doesn't have). Menu.ModifyMenu adds to Blizzard's menu without touching it.
    if Menu and Menu.ModifyMenu and not self.gearMenuHooked then
        self.gearMenuHooked = true
        -- a window's own title (right-click passes through to Blizzard's type menu): Move to Own Window
        -- or Dock as a Tab added under Blizzard's entries (23c)
        Menu.ModifyMenu("MENU_DAMAGE_METER_WINDOW_TRACKED_TYPE", function(owner, rootDescription)
            SafeCall(Dock.ModifyWindowMenu, owner, rootDescription, GetWindowTypeDropdown)
            -- Report to Chat
            SafeCall(DamageMeter.Report.ModifyWindowMenu, owner, rootDescription, GetWindowTypeDropdown)
        end)
        Menu.ModifyMenu("MENU_DAMAGE_METER_WINDOW_SETTINGS", function(owner, rootDescription)
            local db = GetDb()
            if not (db and db.enabled) then return end
            -- two meter windows at most (23b)
            SafeCall(Dock.LimitMenu, rootDescription)
            -- Move to Own Window / Dock as a Tab (23c)
            SafeCall(Dock.ModifyWindowMenu, owner, rootDescription, GetWindowSettingsDropdown)
            -- Report to Chat
            SafeCall(DamageMeter.Report.ModifyWindowMenu, owner, rootDescription, GetWindowSettingsDropdown)
            -- Hide Until Next Group (11-22, Malkkav, xjsc16x's idea): the meter away for this group
            -- (not in the chat, where it is a tab); it comes back when you join another group, or after
            -- a reload. Its Visibility stays as set.
            if not DamageMeter:ChatTabAvailable() then
                rootDescription:CreateDivider()
                rootDescription:CreateButton(L["Hide Until Next Group"], function() DamageMeter.HideUntilGroup() end)
            end
            if not ns.SettingsPanel then return end
            rootDescription:CreateDivider()
            rootDescription:CreateButton(L["FlareUI Settings"], function() ns.SettingsPanel:Open("dm") end)
        end)
    end

    SafeCall(self.Refresh, self)
    C_Timer.After(1, function() self:Refresh() end)
end

--------------------------------------------------
-- 25. SETTINGS PREVIEW SAMPLE
-- The meter for the settings panel's picture, drawn by the real meter's own functions: FlareUI's
-- skin, header, icons and Threat tab, with rows of fake players ("damage") or the Threat tab's
-- sample rows ("threat"). With Meter Tab in the Chat it stands in the chat's sample window under its
-- tab row. A plain frame: no events, no mouse, Blizzard's meter windows only read for their bar
-- settings.
--------------------------------------------------
DamageMeter.sampleLook = {
    WIDTH = 300, HEIGHT = 180,   -- the skin, out of the chat
    SECONDS = 95,                -- the fight's length: the per-second values and the timer
    -- name, class file, amount
    players = {
        { "Pyroblastoise", "MAGE", 1920000 },
        { "Stabbington", "ROGUE", 1750000 },
        { "Thrallbro", "WARRIOR", 1410000 },
        { "Dotsalot", "WARLOCK", 1260000 },
        { "Pewpew", "HUNTER", 980000 },
        { "Moonbeam", "DRUID", 610000 },
    },
}

-- A row standing in for Blizzard's entry template while Blizzard_DamageMeter isn't loaded: the same
-- bar art and texts, and the few methods FillRow and ApplyBarFont use
DamageMeter.SampleRowMixin = {}

function DamageMeter.SampleRowMixin:SetBarHeight(height) self:SetHeight(height) end
function DamageMeter.SampleRowMixin:SetTextScale() end
function DamageMeter.SampleRowMixin:SetStyle() end
function DamageMeter.SampleRowMixin:GetStatusBar() return self.StatusBar end
function DamageMeter.SampleRowMixin:GetIcon() return self.Icon.Icon end
function DamageMeter.SampleRowMixin:GetName() return self.StatusBar.Name end
function DamageMeter.SampleRowMixin:GetValue() return self.StatusBar.Value end

-- Blizzard's default style: the bar from the icon (or the row's left) to 4 px short of its right
function DamageMeter.SampleRowMixin:SetShowBarIcons(show)
    self.Icon:SetShown(show and true or false)
    local bar = self.StatusBar
    bar:ClearAllPoints()
    if show then bar:SetPoint("LEFT", self.Icon, "RIGHT", 0, 0) else bar:SetPoint("LEFT", self, "LEFT", 0, 0) end
    bar:SetPoint("TOP", self, "TOP", 0, -1)
    bar:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -4, 1)
end

-- Blizzard's colour rule: the class colour when asked for, else the ally colour
function DamageMeter.SampleRowMixin:SetUseClassColor(use)
    local c = use and self.classFilename and RAID_CLASS_COLORS[self.classFilename]
    c = c or _G.DAMAGE_METER_STATUS_BAR_ALLY_COLOR or { r = 0.3, g = 0.7, b = 0.3 }
    self.StatusBar:GetStatusBarTexture():SetVertexColor(c.r, c.g, c.b)
end

function DamageMeter.NewSampleRow(parent)
    if C_AddOns.IsAddOnLoaded("Blizzard_DamageMeter") and _G.DamageMeterEntryMixin then
        local ok, row = pcall(CreateFrame, "Button", nil, parent, "DamageMeterEntryTemplate")
        if ok and row then return row end
    end
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(24)
    local holder = CreateFrame("Frame", nil, row)
    holder:SetSize(24, 24)
    holder:SetPoint("LEFT")
    holder.Icon = holder:CreateTexture(nil, "ARTWORK")
    holder.Icon:SetAllPoints()
    holder.Icon:SetTexCoord(0.0625, 0.9, 0.0626, 0.9)
    local bar = CreateFrame("StatusBar", nil, row)
    local fill = bar:CreateTexture(nil, "ARTWORK")
    fill:SetAtlas("UI-HUD-CoolDownManager-Bar")
    -- a client that only takes a file here gets the plain bar
    if not pcall(bar.SetStatusBarTexture, bar, fill) then bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar") end
    for _, part in ipairs({ { "BACKGROUND", "ui-damagemeters-bar-shadowbg" }, { "OVERLAY", "ui-damagemeters-bar-shadowedge" } }) do
        local tex = bar:CreateTexture(nil, part[1])
        tex:SetAtlas(part[2])
        tex:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 2)
        tex:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -2)
    end
    bar.Value = bar:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    bar.Value:SetPoint("RIGHT", bar, "RIGHT", -3, 0)
    bar.Name = bar:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    bar.Name:SetJustifyH("LEFT")
    bar.Name:SetWordWrap(false)
    bar.Name:SetPoint("LEFT", bar, "LEFT", 2, 0)
    bar.Name:SetPoint("RIGHT", bar.Value, "LEFT", -25, 0)
    row.Icon, row.StatusBar = holder, bar
    Mixin(row, DamageMeter.SampleRowMixin)
    row:SetShowBarIcons(false)
    return row
end

-- Stands in for a session window where the meter's functions ask one: the bar settings are read
-- from Blizzard's first window when it exists (plain getters), Blizzard's defaults otherwise
function DamageMeter.SampleWindowFor(f)
    local real = _G.DamageMeterSessionWindow1
    local function Read(method, default)
        local fn = real and real[method]
        if type(fn) == "function" then
            local ok, v = pcall(fn, real)
            if ok and v ~= nil and canaccessvalue(v) then return v end
        end
        return default
    end
    local p = f.proxy
    if not p then
        p = { values = {} }
        function p:GetBarHeight() return self.values.height end
        function p:GetBarSpacing() return self.values.spacing end
        function p:GetTextScale() return self.values.textScale end
        function p:ShouldShowBarIcons() return self.values.icons end
        function p:GetStyle() return self.values.style end
        function p:ShouldUseClassColor() return self.values.classColor end
        f.proxy = p
    end
    local v = p.values
    v.height = Read("GetBarHeight", _G.DAMAGE_METER_DEFAULT_BAR_HEIGHT or 25)
    v.spacing = Read("GetBarSpacing", _G.DAMAGE_METER_DEFAULT_BAR_SPACING or 4)
    v.textScale = Read("GetTextScale", 1)
    v.icons = Read("ShouldShowBarIcons", false)
    v.style = Read("GetStyle", Enum.DamageMeterStyle and Enum.DamageMeterStyle.Default)
    v.classColor = Read("ShouldUseClassColor", true)
    v.numbers = Read("GetNumberDisplayType", Enum.DamageMeterNumbers and Enum.DamageMeterNumbers.Compact)
    p.DamageMeterTypeDropdown = f.TypeDropdown
    p.FlareUI_DMSkin = f.Skin
    return p
end

function DamageMeter.CreateSample(parent, kind)
    if kind ~= nil and kind ~= "damage" and kind ~= "threat" then return nil end
    local f = CreateFrame("Frame", nil, parent)
    f.fuiSample = true
    f:EnableMouse(false)
    if ns.Chat and ns.Chat.CreateSampleWindow then f.Chat = ns.Chat.CreateSampleWindow(f) end
    local skin = CreateFrame("Frame", nil, f, "BackdropTemplate")
    skin:SetFrameLevel(f:GetFrameLevel() + 10)   -- over the chat's window, as the meter is
    local line = skin:CreateTexture(nil, "OVERLAY")
    line:SetTexture(SEPARATOR)
    line:SetHeight(8)
    line:SetPoint("TOPLEFT", skin, "TOPLEFT", 3, -HEADER_HEIGHT)
    line:SetPoint("TOPRIGHT", skin, "TOPRIGHT", -3, -HEADER_HEIGHT)
    f.Skin = skin
    -- the title (Blizzard's type dropdown text) and the timer
    f.TypeDropdown = { TypeName = skin:CreateFontString(nil, "OVERLAY") }
    f.TypeDropdown.TypeName:SetJustifyH("LEFT")
    f.Timer = skin:CreateFontString(nil, "OVERLAY")
    f.Timer:SetJustifyH("RIGHT")
    f.Icons = {}
    for _, key in ipairs({ "settings", "segments", "countdown", "ready" }) do
        f.Icons[key] = CreateFrame("Frame", nil, skin)
    end
    -- the Threat tab and both lists, under Blizzard's content top
    local tab = CreateFrame("Frame", nil, skin)
    tab.Text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tab.Text:SetPoint("LEFT", tab, "LEFT", 4, 0)
    tab.Text:SetText(L["Threat"])
    local function List()
        local list = CreateFrame("Frame", nil, skin)
        list.Empty = list:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        list.Empty:SetPoint("CENTER")
        return list
    end
    f.DamageView = { rows = {}, frame = List(), newRow = DamageMeter.NewSampleRow }
    local threat = { rows = {}, frame = List(), tab = tab, sample = true, showing = true, newRow = DamageMeter.NewSampleRow }
    local overlay = CreateFrame("Frame", nil, threat.frame)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(threat.frame:GetFrameLevel() + 30)
    threat.pullLine = overlay:CreateTexture(nil, "OVERLAY", nil, 7)
    threat.pullLine:SetColorTexture(1, 0.2, 0.15, 0.95)
    threat.pullLine:SetWidth(2)
    threat.pullLine:Hide()
    f.ThreatView = threat
    f:Hide()
    return f
end

-- Blizzard's value text for a row (Number Display: minimal, compact, complete)
function DamageMeter.SampleValueText(amount, total, seconds, numbers)
    local E = Enum.DamageMeterNumbers
    local value, perSecond = AbbreviateLargeNumbers(amount), AbbreviateLargeNumbers(math.floor(amount / seconds))
    if E and numbers == E.Complete then
        return (_G.DAMAGE_METER_ENTRY_FORMAT_COMPLETE or "%s (%s, %s%%)"):format(value, perSecond, Round(amount / total * 100))
    elseif E and numbers == E.Minimal then
        return (_G.DAMAGE_METER_ENTRY_FORMAT_MINIMAL or "%s"):format(value)
    end
    return (_G.DAMAGE_METER_ENTRY_FORMAT_COMPACT or "%s (%s)"):format(value, perSecond)
end

function DamageMeter.DrawSample(f, kind)
    local db = GetDb()
    if not db then f:Hide() return 0, 0 end
    local look = DamageMeter.sampleLook
    local showThreat = kind == "threat"

    -- Meter Tab in the Chat: the chat's window around it, the Meter tab picked, the meter's own skin clear
    local chatDb = ns.db and ns.db.profile and ns.db.profile.chat
    local inChat = ChatTabOn() and f.Chat ~= nil and chatDb ~= nil and ns.Chat.DrawSampleWindow ~= nil
    local width, height, top
    if inChat then
        width, height = ns.Chat.SampleWindowSize()
        f.Chat:ClearAllPoints()
        f.Chat:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        ns.Chat.DrawSampleWindow(f.Chat, chatDb, width, height, ns.Chat.SampleTabs(chatDb, true))
        top = CHAT_TAB_ROW
    else
        if f.Chat then f.Chat:Hide() end
        width, height, top = look.WIDTH, look.HEIGHT, 0
    end
    local skin = f.Skin
    local skinWidth, skinHeight = width, height - top
    skin:ClearAllPoints()
    skin:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -top)
    skin:SetSize(skinWidth, skinHeight)
    DamageMeter.SkinBackdrop(skin, db)
    DamageMeter.PaintSkin(skin, db, inChat)

    -- the header as ApplyHeader and ApplyHeaderFonts lay it out
    local fontDb = DamageMeter.HeaderFontDb(db)
    local path, size, flags = GetFontData(fontDb)
    local title = f.TypeDropdown.TypeName
    for _, fs in ipairs({ title, f.Timer }) do
        ns.SetFont(fs, path, size, flags)
        ApplyFontEffects(fs, fontDb)
    end
    title:SetText(_G.DAMAGE_METER_TYPE_DAMAGE_DONE or L["Damage Done"])
    title:ClearAllPoints()
    title:SetPoint("LEFT", skin, "TOPLEFT", TITLE_LEFT, ROW_CENTER_Y)

    local box = ICON_SIZE + 9
    local function Place(btn, x)
        btn:SetSize(box, box)
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", skin, "TOPRIGHT", x, ROW_CENTER_Y)
        btn:Show()
    end
    Place(f.Icons.settings, -(ICON_RIGHT + ICON_SIZE / 2))
    DamageMeter.HeaderIcon(f.Icons.settings, ICON_SETTINGS, ICON_DRAW_SIZE.settings, ICON_DRAW_YOFS.settings)
    Place(f.Icons.segments, -(ICON_RIGHT + ICON_SIZE / 2 + ICON_SPACING))
    DamageMeter.HeaderIcon(f.Icons.segments, ICON_SEGMENTS, ICON_DRAW_SIZE.segments, ICON_DRAW_YOFS.segments)
    -- Ready Check and Countdown always (not by the group), so the picture shows them
    local extra = 0
    for _, key in ipairs(GROUP_BUTTONS.order) do
        local btn = f.Icons[key]
        if btn then
            extra = extra + 1
            Place(btn, -(ICON_RIGHT + ICON_SIZE / 2 + (extra + 1) * ICON_SPACING))
            DamageMeter.HeaderIcon(btn, GROUP_BUTTONS[key].icon, ICON_DRAW_SIZE[key])
        end
    end
    local iconsWidth = ICON_SIZE + (1 + extra) * ICON_SPACING
    f.Timer:SetText(("[%s] "):format(SecondsToClock(look.SECONDS)))
    f.Timer:ClearAllPoints()
    f.Timer:SetPoint("RIGHT", skin, "TOPRIGHT", -(ICON_RIGHT + iconsWidth + 10), ROW_CENTER_Y)
    f.Timer:SetShown(db.combatTimer and true or false)

    local window = DamageMeter.SampleWindowFor(f)
    local threat, damage = f.ThreatView, f.DamageView
    threat.showing = showThreat
    LayoutTabs(window, threat)
    threat.showing = true   -- its pull line's one retry (UpdateThreatView) runs for the sample too

    local listWidth, listHeight = skinWidth - 12, math_max(1, skinHeight - CONTENT_TOP - 6)
    for _, view in ipairs({ threat, damage }) do
        view.frame:ClearAllPoints()
        view.frame:SetPoint("TOPLEFT", skin, "TOPLEFT", 6, -CONTENT_TOP)
        view.frame:SetSize(listWidth, listHeight)
    end
    threat.frame:SetShown(showThreat)
    damage.frame:SetShown(not showThreat)

    local rows
    if showThreat then
        threat.lineRetry = nil
        SafeCall(UpdateThreatView, window, threat)
        rows = threat.rows
    else
        local barHeight, spacing = window:GetBarHeight(), window:GetBarSpacing()
        local capacity = math_max(1, math.floor((listHeight + spacing) / (barHeight + spacing)))
        local total, shown = 0, math_min(#look.players, capacity)
        for _, p in ipairs(look.players) do total = total + p[3] end
        local best = look.players[1][3]
        for i = 1, shown do
            local p = look.players[i]
            local row = GetRow(damage, i)
            local data = { name = p[1], class = p[2], value = p[3], scaled = 0, rank = i, order = i }
            row.ftValue = nil   -- FillRow's threat text is replaced below
            FillRow(row, data, best, window, db, i, barHeight, spacing)
            row:GetValue():SetText(DamageMeter.SampleValueText(p[3], total, look.SECONDS, window.values.numbers))
        end
        for i = shown + 1, #damage.rows do damage.rows[i]:Hide() end
        rows = damage.rows
    end
    -- the bar font, now (Refresh's pass mark would skip rows styled before)
    for _, row in ipairs(rows) do
        row.FlareUI_FontPass = nil
        ApplyBarFont(row, db)
    end

    f:SetSize(width, height)
    f:Show()
    return width, height
end

-- No sizing corner on the meter windows while Edit Mode is open (Blizzard fades it in
-- on mouseover, which there reads as a stray tab): back after, except on a window docked as a tab
do
    local LEM = LibStub("FlareEditMode")
    local function Corners(editing)
        local db = GetDb()
        if not (db and db.enabled) then return end
        for _, w in ipairs(GetSessionWindows()) do
            local resize = w.GetResizeButton and w:GetResizeButton()
            if resize then
                if editing then resize:Hide() elseif not w.FlareUI_Docked then resize:Show() end
            end
        end
    end
    LEM:RegisterCallback("enter", function() Corners(true) end)
    LEM:RegisterCallback("exit", function() Corners(false) end)
end
