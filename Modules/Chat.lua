local _, ns = ...
local L = ns.L

--------------------------------------------------
-- CHAT
-- Blizzard's chat windows in FlareUI's look: a skin per window with tabs and header buttons,
-- rewritten lines, copyable links, hover tooltips, saved history, pop-out windows, fading and the
-- damage meter as a tab.
--------------------------------------------------

--------------------------------------------------
-- 1. MODULE REGISTRATION
--------------------------------------------------
ns.Chat = ns.Chat or {}
local Chat = ns.Chat
ns.modules["Chat"] = Chat

LibStub("AceEvent-3.0"):Embed(Chat)
LibStub("AceTimer-3.0"):Embed(Chat)
LibStub("AceHook-3.0"):Embed(Chat)

--------------------------------------------------
-- 2. UPVALUES
--------------------------------------------------
local _G = _G
local pairs, ipairs, select = pairs, ipairs, select
local pcall = pcall
local string_format = string.format
local string_gsub = string.gsub
local math_max = math.max
local math_min = math.min
local math_abs = math.abs
local tonumber = tonumber
local InCombatLockdown = InCombatLockdown
local C_Timer = C_Timer
local C_CVar = C_CVar
local GetPlayerInfoByGUID = GetPlayerInfoByGUID
local C_ClassColor = C_ClassColor
local BetterDate = TimeUtil.BetterDate
local canaccessallvalues = canaccessallvalues
local LSM = LibStub("LibSharedMedia-3.0")
local MenuUtil = MenuUtil
local FCF_DockUpdate = FCF_DockUpdate
local PanelTemplates_TabResize = PanelTemplates_TabResize

--------------------------------------------------
-- 3. CONSTANTS & ASSETS
--------------------------------------------------
local NUM_CHAT_WINDOWS = Constants.ChatFrameConstants.MaxChatWindows
local NPC_COLOR = "|cffFFB033"
local TIMESTAMP_COLOR = "|cff00B2FF"

-- Fixed look
local DEFAULT_BORDER = "FlareUI Frames"
local TEXT_PADDING   = 10   -- between the window's text and its skin's edge
local HEADER_HEIGHT  = 24   -- the tab row above the text
-- the Combat Log's filter bar, between the tab row's separator and the text
local COMBAT_BAR_HEIGHT   = 24
local COMBAT_BAR_TEXT_GAP = 3    -- between the bar and the text
local COMBAT_BAR_TOP_GAP  = -3   -- from the top of the other tabs' text down to the bar (negative: above it)
local COMBAT_BAR_SPACE    = COMBAT_BAR_HEIGHT + COMBAT_BAR_TEXT_GAP + COMBAT_BAR_TOP_GAP
local COMBAT_BAR_INSET    = 5    -- past the text on each side, in line with the separator
local BORDER_SIZE    = 16
local BORDER_INSET   = 3
local TAB_TEXT_Y     = -3
local TAB_ACTIVE_COLOR   = { r = 0.80, g = 0.60, b = 0.34, a = 1 }   -- #CC9957
local TAB_INACTIVE_COLOR = { r = 0.56, g = 0.51, b = 0.46, a = 1 }   -- #8F8275
local HEADER_ICON_COLOR  = { r = 0.61, g = 0.48, b = 0.29, a = 1 }   -- #9C7A4A
local HEADER_ICON_Y      = -14
local HEADER_ICON_SCALE  = 0.6
local SEPARATOR = "Interface\\Common\\UI-TooltipDivider-Transparent"

local ICON_MUTE   = "Interface\\AddOns\\FlareUI\\Media\\Icons\\Volume-Speaker-Mute.tga"
local ICON_LOW    = "Interface\\AddOns\\FlareUI\\Media\\Icons\\Volume-Speaker-Low.tga"
local ICON_MEDIUM = "Interface\\AddOns\\FlareUI\\Media\\Icons\\Volume-Speaker-Medium.tga"
local ICON_HIGH   = "Interface\\AddOns\\FlareUI\\Media\\Icons\\Volume-Speaker-High.tga"

local ICON_CHANNELS = "Interface\\AddOns\\FlareUI\\Media\\Icons\\ChatChannels.tga"
local ICON_MENU     = "Interface\\AddOns\\FlareUI\\Media\\Icons\\ChatOptions.tga"
local ICON_SOCIAL   = "Interface\\AddOns\\FlareUI\\Media\\Icons\\ChatSocial.tga"

--------------------------------------------------
-- 4. HELPERS
--------------------------------------------------

local function GetDb()
    if not ns.db or not ns.db.profile or not ns.db.profile.chat then
        return nil
    end
    return ns.db.profile.chat
end

-- The border picked in the options, or the default when LibSharedMedia does not know it
local function GetBorderFile(db)
    local name = db and db.borderTexture
    if name == "None" then return nil end   -- Frame Border: None
    if not (name and LSM:IsValid("border", name)) then name = DEFAULT_BORDER end
    return LSM:Fetch("border", name)
end

-- A window popped out of the dock (see POP-OUT WINDOWS)
local function IsPopped(chatFrame)
    local dock = _G.GeneralDockManager
    return chatFrame ~= nil and dock ~= nil and chatFrame ~= dock.primary and not chatFrame.isDocked
end

-- Every chat window, whisper windows (ChatFrame11 and up) included: for _, cf in Windows() do
local function NextWindow(names, i)
    i = i + 1
    local name = names[i]
    if name then return i, _G[name] end
end

local function Windows()
    return NextWindow, CHAT_FRAMES or {}, 0
end

-- BetterDate for one format, kept for the last two seconds: every chat line formats a timestamp
local stampCache = {}
local function CachedDate(fmt, t)
    local c = stampCache
    if c.fmt == fmt then
        if c.t1 == t then return c.s1 end
        if c.t2 == t then return c.s2 end
    else
        c.fmt, c.t1, c.t2 = fmt, nil, nil
    end
    local s = BetterDate(fmt, t)
    c.t2, c.s2 = c.t1, c.s1
    c.t1, c.s1 = t, s
    return s
end

-- Blizzard's timestamp setting, read once and again only when it changes (not on every line)
local stampFormats = {}
local function StampFormats()
    if not stampFormats.read then
        stampFormats.read = true
        stampFormats.blizzard = ChatFrameUtil.GetTimestampFormat and ChatFrameUtil.GetTimestampFormat()
        stampFormats.cvar = C_CVar.GetCVar("showTimestamps")
        if not stampFormats.watched and CVarCallbackRegistry and CVarCallbackRegistry.RegisterCallback then
            stampFormats.watched = true
            pcall(CVarCallbackRegistry.RegisterCallback, CVarCallbackRegistry, "showTimestamps", function()
                stampFormats.read = nil
            end, stampFormats)
        end
    end
    return stampFormats.blizzard, stampFormats.cvar
end

-- Better Timestamps: Blizzard's timestamp in FlareUI's colour, or one added where it has none
local function GetTimestamp(at)
    local _, format = StampFormats()
    if not format or format == "none" then format = "%H:%M" end

    -- Blizzard's formats end in a space, which belongs outside the brackets
    local timeStr = string_gsub(CachedDate(format, at or time()), "%s+$", "")
    return string_format("%s<%s>|r ", TIMESTAMP_COLOR, timeStr)
end

local function GetFontData(fontDB)
    local face  = fontDB and fontDB.face or "Friz Quadrata TT"
    local size  = fontDB and fontDB.size or 14
    local flags = fontDB and fontDB.flags or "OUTLINE"
    if flags == "NONE" then flags = "" end
    local path = ns.GetFontPath(face)
    return path, size, flags
end

local function StripBlizzardChatBackground(chatFrame)
    if not chatFrame or chatFrame:IsForbidden() then return end
    local name = chatFrame:GetName()
    if name then
        local bg = _G[name .. "Background"]
        if bg then if bg.Hide then bg:Hide() end; if bg.SetTexture then bg:SetTexture(nil) end; if bg.SetAlpha then bg:SetAlpha(0) end end
        local pieces = { "TopLeftTexture", "TopRightTexture", "BottomLeftTexture", "BottomRightTexture", "TopTexture", "BottomTexture", "LeftTexture", "RightTexture" }
        for _, piece in ipairs(pieces) do
            local tex = _G[name .. piece]
            if tex then if tex.SetTexture then tex:SetTexture(nil) end; if tex.Hide then tex:Hide() end end
        end
    end
    if chatFrame.SetBackdrop then chatFrame:SetBackdrop(nil) end
    if chatFrame.ScrollBar and chatFrame.ScrollBar.Background then
        chatFrame.ScrollBar.Background:SetAlpha(0); chatFrame.ScrollBar.Background:Hide()
    end
end

local function KillScrollBar(chatFrame)
    if not chatFrame or chatFrame:IsForbidden() then return end
    local sb = chatFrame.ScrollBar
    if not sb then return end
    sb:Hide()
    sb:UnregisterAllEvents()
    sb:EnableMouse(false)
    sb:SetScript("OnShow", function(self) self:Hide() end)
end

local function HideButtonFrame(chatFrame)
    if not chatFrame or chatFrame:IsForbidden() then return end

    -- the ButtonFrame holds the minimize / close buttons of docked frames
    if chatFrame.buttonFrame then
        chatFrame.buttonFrame:Hide()
        chatFrame.buttonFrame:SetAlpha(0)
        if chatFrame.buttonFrame.SetScript then
            chatFrame.buttonFrame:SetScript("OnShow", function(self) self:Hide() end)
        end
    end

    local name = chatFrame:GetName()
    if name then
        local elements = {
            "ButtonFrameBackground",
            "ButtonFrameTopLeftTexture",
            "ButtonFrameBottomLeftTexture",
            "ButtonFrameTopRightTexture",
            "ButtonFrameBottomRightTexture",
            "ButtonFrameLeftTexture",
            "ButtonFrameRightTexture",
            "ButtonFrameBottomTexture",
            "ButtonFrameTopTexture",
        }
        for _, elem in ipairs(elements) do
            local frame = _G[name .. elem]
            if frame then
                if frame.Hide then frame:Hide() end
                if frame.SetAlpha then frame:SetAlpha(0) end
            end
        end
    end
end

local function UnclampChatFrame(chatFrame)
    if not chatFrame or chatFrame:IsForbidden() then return end
    chatFrame:SetClampedToScreen(false)
    chatFrame:SetClampRectInsets(-50, -50, -50, -50)
end

-- runs on every message (the AddMessage hook), so it only touches the button when it changes
local function UpdateScrollToBottomVisibility(chatFrame)
    local btn = chatFrame and chatFrame.ScrollToBottomButton
    if not btn or chatFrame:IsForbidden() then return end
    local shown = (chatFrame.GetScrollOffset and chatFrame:GetScrollOffset() or 0) ~= 0
    if btn:IsShown() ~= shown then btn:SetShown(shown) end
end

-- Copy Chat Button: a faint note icon in the window's top right corner opens Copy Chat for that
-- window; full strength and bronze while pointed at
local COPY_ICON = "Interface\\Buttons\\UI-GuildButton-PublicNote-Up"
local COPY_ALPHA = 0.35
local COPY_HOVER = { 1.00, 0.78, 0.46 }   -- bright bronze
local function UpdateCopyButton(chatFrame, db)
    if not chatFrame or chatFrame:IsForbidden() then return end
    local btn = chatFrame.FlareUI_CopyButton
    if not db.copyButton then
        if btn then btn:Hide() end
        return
    end
    if not btn then
        btn = CreateFrame("Button", nil, chatFrame)
        btn:SetSize(18, 18)
        btn:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", -2, -2)
        btn:SetNormalTexture(COPY_ICON)
        btn:SetAlpha(COPY_ALPHA)
        btn:SetScript("OnEnter", function(self)
            self:SetAlpha(1)
            local icon = self:GetNormalTexture()
            icon:SetDesaturated(true)
            icon:SetVertexColor(COPY_HOVER[1], COPY_HOVER[2], COPY_HOVER[3])
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetAlpha(COPY_ALPHA)
            local icon = self:GetNormalTexture()
            icon:SetDesaturated(false)
            icon:SetVertexColor(1, 1, 1)
        end)
        btn:SetScript("OnClick", function() Chat:ShowCopyChat(chatFrame) end)
        chatFrame.FlareUI_CopyButton = btn
    end
    btn:SetFrameLevel((chatFrame:GetFrameLevel() or 0) + 3)
    -- a docked window under the Meter tab keeps it hidden (see SetDockedTextShown)
    btn:SetShown(not (chatFrame.isDocked and Chat:MeterTabActive()))
end

local function RepositionScrollToBottomButton(chatFrame)
    if not chatFrame or chatFrame:IsForbidden() then return end
    local btn = chatFrame.ScrollToBottomButton
    if not btn then return end
    btn:SetParent(chatFrame)
    btn:ClearAllPoints()
    btn:SetPoint("BOTTOMRIGHT", chatFrame, "BOTTOMRIGHT", -3, 3)
    local level = chatFrame:GetFrameLevel() or 0
    btn:SetFrameLevel(level + 3)
    btn:SetAlpha(0.8)
    if not btn.FlareUI_Styled then
        btn.FlareUI_Styled = true
        btn:SetNormalTexture("Interface\\Buttons\\UI-ScrollDown-Up")
        btn:SetPushedTexture("Interface\\Buttons\\UI-ScrollDown-Down")
        btn:SetHighlightTexture("Interface\\Buttons\\UI-ScrollDown-Highlight")
        local w, h = btn:GetSize()
        if (w or 0) < 10 or (h or 0) < 10 then btn:SetSize(8, 8) end
    end
    if not chatFrame.FlareUI_ScrollBottomHooked then
        chatFrame.FlareUI_ScrollBottomHooked = true
        Chat:SecureHook(chatFrame, "SetScrollOffset", UpdateScrollToBottomVisibility)
        Chat:SecureHookScript(chatFrame, "OnMouseWheel", function(frameParam) UpdateScrollToBottomVisibility(frameParam) end)
    end
    UpdateScrollToBottomVisibility(chatFrame)
end

local function StyleButtonFrame()
    for i = 1, NUM_CHAT_WINDOWS do
        local bf = _G["ChatFrame" .. i .. "ButtonFrame"]
        if bf then
            if bf.GetNumRegions then
                local nr = bf:GetNumRegions()
                for ri = 1, nr do
                    local region = select(ri, bf:GetRegions())
                    if region and region:GetObjectType() == "Texture" then
                        region:SetTexture(nil); region:SetAlpha(0)
                    end
                end
            end
            bf:EnableMouse(false)
        end
    end
end

-- Forever's "Refreshing your world" notice sits just above the chat, its minimize button (to its
-- left) lined up with the chat's left edge. Re-placed on every SetPoint and show.
local SHARD_GAP = 4   -- between the chat's top edge and the notice
-- the toasts' silver border in FlareUI bronze, kept when Blizzard re-applies the backdrop
local function TintToastBorder(frame)
    if not frame.SetBackdropBorderColor then return end
    local c = ns.BORDER_COLOR
    frame.backdropBorderColor = CreateColor(c.r, c.g, c.b, 1)
    frame:SetBackdropBorderColor(c.r, c.g, c.b, 1)
end

local function AnchorShardNotice()
    local frame = _G.ShardTransferImminentFrame
    if not frame or frame.FlareUI_Anchored then return end
    frame.FlareUI_Anchored = true
    TintToastBorder(frame)

    local placing
    local function Place()
        if placing then return end
        local chat = _G.ChatFrame1
        local anchor = (chat and chat.FlareUI_Skin) or chat
        if not anchor then return end
        local button = _G.ShardTransferImminentMinimizeButton
        local shift = button and (button:GetWidth() + 7) or 0
        placing = true
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", shift, SHARD_GAP)
        placing = false
    end

    hooksecurefunc(frame, "SetPoint", Place)
    frame:HookScript("OnShow", Place)
    Place()
end

-- Battle.net toasts: Forever never moves them from mid screen, so they go just above the chat.
-- Re-placed on every SetPoint and show; Blizzard_BNet can load after FlareUI.
local BN_TOAST_GAP = 4   -- between the chat's top edge and the toast
local function AnchorBNToast()
    local frame = _G.BNToastFrame
    if not frame then
        if not Chat.bnToastWait then
            Chat.bnToastWait = CreateFrame("Frame")
            Chat.bnToastWait:RegisterEvent("ADDON_LOADED")
            Chat.bnToastWait:SetScript("OnEvent", function(self)
                if not _G.BNToastFrame then return end
                self:UnregisterAllEvents()
                AnchorBNToast()
            end)
        end
        return
    end
    if frame.FlareUI_Anchored then return end
    frame.FlareUI_Anchored = true
    TintToastBorder(frame)

    local placing
    local function Place()
        if placing then return end
        local chat = _G.ChatFrame1
        local anchor = (chat and chat.FlareUI_Skin) or chat
        if not anchor then return end
        placing = true
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, BN_TOAST_GAP)
        placing = false
    end

    hooksecurefunc(frame, "SetPoint", Place)
    frame:HookScript("OnShow", Place)
    Place()
end

-- Voice chat: Blizzard's alerts (who is speaking) start from its hidden button column, and its mute
-- and deafen buttons hang below the channel button, which FlareUI moved to the chat's header. All go
-- above the chat: the alerts on the left, growing rightwards, and the buttons on the right.
local VOICE_GAP = 4          -- between the chat's top edge and the alerts or buttons
local VOICE_BUTTON_GAP = 2   -- between the two buttons

-- The social button is the first link in Blizzard's alert chain, and every alert change moves it to
-- the container and stacks the others on it. It lives in FlareUI's header, so the speakers sat on the
-- header and jumped whenever the button did. After each change the alerts stack without it, growing
-- rightwards, and it goes straight back. Only anchors are changed: writing the container's
-- justification or subsystems would taint it.
local function StackAlerts(container)
    local social = _G.QuickJoinToastButton
    local relative = container
    for _, system in ipairs(container.alertFrameSubSystems) do
        local frame = system.anchorFrame
        if frame and frame ~= social and frame:IsShown() then
            frame:ClearAllPoints()
            frame:SetPoint("BOTTOMLEFT", relative, relative == container and "BOTTOMLEFT" or "TOPLEFT", 0, 0)
            relative = frame
        end
    end
    if social and social:IsShown() then Chat:StyleHeaderButtons() end
end

local function AnchorVoiceChat()
    local chat = _G.ChatFrame1
    local anchor = chat and chat.FlareUI_Skin
    if not anchor then return end

    local alerts = _G.ChatAlertFrame
    if alerts then
        alerts:ClearAllPoints()
        alerts:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, VOICE_GAP)
        if not alerts.FlareUI_AnchorsHooked then
            alerts.FlareUI_AnchorsHooked = true
            hooksecurefunc(alerts, "UpdateAnchors", StackAlerts)
        end
        StackAlerts(alerts)
    end

    local deafen, mute = _G.ChatFrameToggleVoiceDeafenButton, _G.ChatFrameToggleVoiceMuteButton
    if deafen and mute then
        deafen:ClearAllPoints()
        deafen:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, VOICE_GAP)
        mute:ClearAllPoints()
        mute:SetPoint("RIGHT", deafen, "LEFT", -VOICE_BUTTON_GAP, 0)
    end
end

local function DisableQuickJoinToasts()
    if QuickJoinToastButton then
        QuickJoinToastButton:UnregisterAllEvents()
        if QuickJoinToastButton.Toast then
            QuickJoinToastButton.Toast:Hide()
            QuickJoinToastButton.Toast:SetAlpha(0)
            QuickJoinToastButton.Toast:EnableMouse(false)
            if not QuickJoinToastButton.FlareUI_ToastHooked then
                QuickJoinToastButton.FlareUI_ToastHooked = true
                hooksecurefunc(QuickJoinToastButton, "ShowToast", function(self) self.Toast:Hide() end)
            end
        end
    end
end

--------------------------------------------------
-- 5. LINE REWRITING
-- A post-hook on each window's AddMessage rewrites the newest history entry in place, so Blizzard's
-- own line (player link, report ID, flash, censoring) stays. Replacing AddMessage or the CHAT_*_GET
-- strings would taint Blizzard's handler. Secret lines pass untouched.
--   Channel Names         Full; Short: [2. Trade - City] -> [2. Trade], [Guild] -> [G], [Say] -> [S];
--                         Number: [2] (the old Short Channel Names switch, chat.shortChannels)
--   Better Player Names   "[Name] says:" -> the class-coloured [Name] without realm or "says:";
--                         a Say line also starts with a clickable [Say] (PR #17, parchinskiy)
--   Better NPC Names      "Thrall says:" -> an orange [Thrall]
--   Level Before Names    "(42)" in front of a player's name
--   Better Timestamps     Blizzard's timestamp in FlareUI's colour, or one added where it has none
--   Race / Class Icons    the sender's race and class icons before the name (from the line's GUID)
--   Item and Spell Icons  the icon inside item and spell links
--   Whisper Markers       a green ">" before whispers you get, a red "<" before ones you send
--   Colon After Names     "[Name]: text" where Better Player Names drops "says:"
-- (Race/class icons, link icons, markers and the colon after Better Forever Chat's: the ideas only.)
--------------------------------------------------
-- Chat type -> short tag and Blizzard's channel link keyword (raid warnings have no link).
-- Numbered channels become just their number.
local SHORT_TAGS = {
    GUILD = { "G", "GUILD" },
    OFFICER = { "O", "OFFICER" },
    PARTY = { "P", "PARTY" },
    PARTY_LEADER = { "PL", "PARTY" },
    PARTY_GUIDE = { "PG", "PARTY" },
    RAID = { "R", "RAID" },
    RAID_LEADER = { "RL", "RAID" },
    RAID_WARNING = { "RW" },
    INSTANCE_CHAT = { "I", "INSTANCE_CHAT" },
    INSTANCE_CHAT_LEADER = { "IL", "INSTANCE_CHAT" },
}

-- Say has no native prefix. The short tag uses the same Latin style as [G] and [P].
local SAY_TAG = "|Hchannel:SAY|h[" .. (SAY_MESSAGE or "Say") .. "]|h "
local SHORT_SAY_TAG = "|Hchannel:SAY|h[S]|h "

-- Lines whose sender is a player. "full": Better Player Names drops the "says:" too; "name": only the
-- name changes (whispers keep their direction).
local NAME_EVENTS = {
    SAY = "full", YELL = "full", GUILD = "full", OFFICER = "full",
    PARTY = "full", PARTY_LEADER = "full", PARTY_GUIDE = "full",
    RAID = "full", RAID_LEADER = "full", RAID_WARNING = "full",
    INSTANCE_CHAT = "full", INSTANCE_CHAT_LEADER = "full", CHANNEL = "full",
    WHISPER = "name", WHISPER_INFORM = "name",
}
local NPC_EVENTS = { MONSTER_SAY = true, MONSTER_YELL = true, MONSTER_WHISPER = true }

local Lines = {
    icons = {},         -- GUID .. size .. what -> the race/class icon markup
    iconCount = 0,
    atlases = {},       -- atlas name -> whether the client has it
    -- Whisper Markers: chat type -> its marker
    marks = { WHISPER = "|cff40ff40>|r ", WHISPER_INFORM = "|cffff6060<|r " },
    levels = {},        -- GUID or lower-case name -> level, this session only
    hooked = {},        -- chat frames carrying the AddMessage post-hook (not a field on Blizzard's)
    -- chat type -> its CHAT_<type>_GET global's name, built once per type
    getKeys = setmetatable({}, { __index = function(t, chatType)
        local key = "CHAT_" .. chatType .. "_GET"
        t[chatType] = key
        return key
    end }),
}

-- Splits off Blizzard's timestamp: the line was just formatted, so this second or the one before
-- reproduces it.
function Lines.SplitStamp(message)
    local fmt = StampFormats()
    if not fmt then return "", message end
    local now = time()
    for t = now, now - 1, -1 do
        local stamp = CachedDate(fmt, t)
        if message:sub(1, #stamp) == stamp then return stamp, message:sub(#stamp + 1) end
    end
    return "", message
end

-- Channel Names: "number" ([2]) or "short" ([2. Trade]); both shorten [Guild] to [G]
function Lines.ShortenChannel(body, chatType, mode)
    local short
    if chatType == "CHANNEL" or chatType == "COMMUNITIES_CHANNEL" then
        if mode == "short" then
            -- the zone after " - " goes
            short = string_gsub(body, "(|Hchannel:channel:%d+|h)%[([^%]]*)%]|h", function(head, text)
                return head .. "[" .. (text:gsub("%s+%-%s.*$", "")) .. "]|h"
            end, 1)
        else
            short = string_gsub(body, "(|Hchannel:channel:(%d+)|h)%[[^%]]*%]|h", "%1[%2]|h", 1)
        end
    elseif SHORT_TAGS[chatType] then
        local tag = SHORT_TAGS[chatType][1]
        if SHORT_TAGS[chatType][2] then
            short = string_gsub(body, "(|Hchannel:[^|]+|h)%[[^%]]*%]|h", "%1[" .. tag .. "]|h", 1)
        elseif CHAT_MSG_RAID_WARNING then
            local long = "[" .. CHAT_MSG_RAID_WARNING .. "]"
            local s, e = body:find(long, 1, true)
            if s then short = body:sub(1, s - 1) .. "[" .. tag .. "]" .. body:sub(e + 1) end
        end
    end
    return short or body
end

-- One event argument, or nil where it is secret or not the expected type
local function Arg(args, index, kind)
    local v = args[index]
    if canaccessvalue(v) and type(v) == kind then return v end
    return nil
end

local function NameKey(name)
    return name and (name:gsub("%-.*$", "")):lower() or nil
end

-- Past LEVELS_KEEP entries the list starts over (a long city session sees thousands of players)
local LEVELS_KEEP = 4000
local function Store(key, level)
    local levels = Lines.levels
    if levels[key] == nil then
        Lines.levelCount = (Lines.levelCount or 0) + 1
        if Lines.levelCount > LEVELS_KEEP then
            wipe(levels)
            Lines.levelCount = 1
        end
    end
    levels[key] = level
end

function Lines.Remember(guid, name, level)
    if not (canaccessvalue(level) and type(level) == "number" and level > 0) then return end
    if canaccessvalue(guid) and type(guid) == "string" then Store(guid, level) end
    if canaccessvalue(name) and type(name) == "string" then Store(NameKey(name), level) end
end

function Lines.RememberUnit(unit)
    local ok, exists = pcall(UnitExists, unit)
    if not (ok and canaccessvalue(exists) and exists) then return end
    local okP, isPlayer = pcall(UnitIsPlayer, unit)
    if not (okP and canaccessvalue(isPlayer) and isPlayer) then return end
    local okG, guid = pcall(UnitGUID, unit)
    local okN, name = pcall(UnitName, unit)
    local okL, level = pcall(UnitLevel, unit)
    -- no truth test on the name or GUID: either can be secret
    if okL then Lines.Remember(okG and guid, okN and name, level) end
end

-- The sender's level, from a unit token or from what was seen this session; nil when unknown
function Lines.LevelFor(guid, sender)
    -- what was seen first (group changes, level-ups and targets keep it current); the unit only for
    -- someone not seen yet
    local known = (guid and Lines.levels[guid]) or (sender and Lines.levels[NameKey(sender)])
    if known then return known end
    if guid then
        local ok, unit = pcall(UnitTokenFromGUID, guid)
        if ok and canaccessvalue(unit) and unit then Lines.RememberUnit(unit) end
        return Lines.levels[guid]
    end
end

local function ColorCode(r, g, b)
    return string_format("|cff%02x%02x%02x", (r or 1) * 255, (g or 1) * 255, (b or 1) * 255)
end

-- the icons' size: a little under the window's font
function Lines.IconSize(chatFrame)
    local ok, _, size = pcall(chatFrame.GetFont, chatFrame)
    size = ok and type(size) == "number" and size or 14
    return math.floor(size * 0.9 + 0.5)
end

function Lines.HasAtlas(name)
    local known = Lines.atlases[name]
    if known == nil then
        known = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil or false
        Lines.atlases[name] = known
    end
    return known
end

-- The race and class icon markup for a race file, sex (3 = female) and class file
function Lines.IconMarkup(raceFile, sex, classFile, size, race, class)
    local out = ""
    local function Add(atlas)
        if atlas and Lines.HasAtlas(atlas) then out = out .. "|A:" .. atlas .. ":" .. size .. ":" .. size .. "|a" end
    end
    if race and type(raceFile) == "string" and GetRaceAtlas then
        Add(GetRaceAtlas(raceFile:lower(), sex == 3 and "female" or "male"))
    end
    if class and GetClassAtlas then Add(GetClassAtlas(classFile)) end
    return out
end

-- Race and Class Icons for a GUID ("" when the game doesn't know the player yet)
function Lines.SenderIcons(guid, size, race, class)
    local key = guid .. size .. (race and "r" or "") .. (class and "c" or "")
    local cached = Lines.icons[key]
    if cached then return cached end
    local ok, _, classFile, _, raceFile, sex = pcall(GetPlayerInfoByGUID, guid)
    if not (ok and canaccessvalue(classFile) and canaccessvalue(raceFile) and canaccessvalue(sex)) then return "" end
    if type(classFile) ~= "string" then return "" end
    local out = Lines.IconMarkup(raceFile, sex, classFile, size, race, class)
    -- a city's worth of senders, then the list starts over
    Lines.iconCount = Lines.iconCount + 1
    if Lines.iconCount > 4000 then
        wipe(Lines.icons)
        Lines.iconCount = 1
    end
    Lines.icons[key] = out
    return out
end

-- Item and Spell Icons: the icon goes inside the link, before its [Name]; a link that already has
-- one (another addon's) is left alone
function Lines.LinkIcons(body, size)
    if not (body:find("|Hitem:", 1, true) or body:find("|Hspell:", 1, true)) then return body end
    return (string_gsub(body, "(|H(%a+):(%d+)[^|]*|h)(.)", function(head, kind, id, nextChar)
        if nextChar == "|" then return nil end
        local texture
        if kind == "item" then
            texture = C_Item.GetItemIconByID and C_Item.GetItemIconByID(tonumber(id))
        elseif kind == "spell" then
            texture = C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(tonumber(id))
        end
        if not texture then return nil end
        return head .. "|T" .. texture .. ":" .. size .. ":" .. size .. "|t" .. nextChar
    end))
end

-- Whisper Markers: "[Name] whispers: hi" -> "> [Name]: hi", "To [Name]: hi" -> "< [Name]: hi"
function Lines.RewriteWhisper(body, chatType)
    local key = _G[Lines.getKeys[chatType]]
    if type(key) ~= "string" then return body end
    local prefix, suffix = key:match("^(.-)%%s(.*)$")
    if not prefix then return body end
    local s, e = body:find("|Hplayer:[^|]*|h.-|h")
    if not s then return body end
    -- "To " (or nothing) right before the name's link
    local start = s - #prefix
    if start < 1 or body:sub(start, s - 1) ~= prefix then return body end
    local after = body:sub(e + 1)
    local ally, rest = after:match("^( |A[^|]*|a)(.*)$")
    local tail = rest or after
    if suffix ~= "" and tail:sub(1, #suffix) ~= suffix then return body end
    return body:sub(1, start - 1) .. Lines.marks[chatType] .. body:sub(s, e) .. (ally or "") .. ": "
        .. tail:sub(#suffix + 1)
end

-- Race and Class Icons go right before the name's link (and its colour)
function Lines.AddSenderIcons(body, icons)
    local s = body:find("|Hplayer:", 1, true)
    if not s then return body end
    if s > 10 and body:sub(s - 10, s - 1):match("^|c%x%x%x%x%x%x%x%x$") then s = s - 10 end
    return body:sub(1, s - 1) .. icons .. " " .. body:sub(s)
end

-- Better Player Names and Level Before Names change the name itself through Blizzard's own filter
-- for it. It keeps any icon Blizzard or another addon put on the name, and holds when a censored
-- line is revealed:
--   Better Player Names   the class-coloured name, without its realm
--   Level Before Names    "(42)" in front of the name
-- Blizzard skips the filter when the name is hidden, and puts the brackets and link round it.
function Lines.SenderName(event, decorated, _, sender, ...)
    local db = GetDb()
    if not (db and db.enabled and (db.formatPlayer or db.showLevel)) then return nil end
    if type(event) ~= "string" or type(decorated) ~= "string" then return nil end
    local chatType = event:sub(10)
    if chatType:sub(1, 7) == "CHANNEL" then chatType = "CHANNEL" end
    if not NAME_EVENTS[chatType] then return nil end
    local guid = select(10, ...)   -- the 12th message argument (the 3rd is the first in ...)
    if not (canaccessvalue(guid) and type(guid) == "string" and guid ~= "") then guid = nil end
    if not (canaccessvalue(sender) and type(sender) == "string" and sender ~= "") then sender = nil end
    local name = decorated
    if db.formatPlayer then
        if sender then
            -- the realm goes (Blizzard keeps it for other realms)
            local short = sender:gsub("%-.*$", "")
            local s, e = name:find(sender, 1, true)
            if s and short ~= sender then name = name:sub(1, s - 1) .. short .. name:sub(e + 1) end
        end
        -- the class colour, where Blizzard's own class colouring is off for this chat type
        if guid and not name:find("|c", 1, true) then
            local ok, _, classFile = pcall(GetPlayerInfoByGUID, guid)
            if ok and canaccessvalue(classFile) and type(classFile) == "string" then
                name = Lines.DressName(db, name, classFile, nil)
            end
        end
    end
    if db.showLevel then name = Lines.DressName(db, name, nil, Lines.LevelFor(guid, sender)) end
    return name
end

-- The class colour (Better Player Names, where the name has no colour yet) and the "(42)" in front
-- (Level Before Names); also the settings preview's fake senders
function Lines.DressName(db, name, classFile, level)
    if classFile and db.formatPlayer and not name:find("|c", 1, true) then
        local color = C_ClassColor.GetClassColor(classFile)
        if color then name = color:WrapTextInColorCode(name) end
    end
    if level and db.showLevel then
        local c = GetQuestDifficultyColor and GetQuestDifficultyColor(level)
        name = (c and ColorCode(c.r, c.g, c.b) or "|cffffffff") .. "(" .. level .. ")|r " .. name
    end
    return name
end

-- Better Player Names on "says" lines: the rest of CHAT_<type>_GET after the name (" says: ") goes
function Lines.RewriteSender(body, chatType)
    local s, e = body:find("|Hplayer:[^|]*|h.-|h")
    if not s then return body end
    -- after the link, maybe behind an ally icon
    local after = body:sub(e + 1)
    local key = _G[Lines.getKeys[chatType]]
    local suffix = type(key) == "string" and key:match("%%s(.*)$")
    local ally, rest = after:match("^( |A[^|]*|a)(.*)$")
    local tail = rest or after
    if suffix and suffix ~= "" and tail:sub(1, #suffix) == suffix then
        -- Colon After Names keeps a ":" after the name
        local db = GetDb()
        return body:sub(1, e) .. (ally or "") .. (db and db.nameColon and ": " or " ") .. tail:sub(#suffix + 1)
    end
    return body
end

-- NPC lines have no link: the CHAT_MONSTER_<type>_GET header becomes the orange name
function Lines.RewriteNPC(body, chatType, args)
    local sender = Arg(args, 2, "string")
    local key = _G[Lines.getKeys[chatType]]
    if not sender or sender == "" or type(key) ~= "string" then return body end
    local ok, header = pcall(string_format, key, sender, sender)
    if not ok or body:sub(1, #header) ~= header then return body end
    local verb = chatType == "MONSTER_WHISPER" and key:match("%%s(.-):?%s*$") or ""
    return NPC_COLOR .. "[" .. sender .. "]" .. verb .. "|r " .. body:sub(#header + 1)
end

-- One line rewritten: stamp is Blizzard's timestamp split off (or ""), body the rest. icons: the
-- sender's race / class icons when already known (the settings preview's fake senders), else read
-- from the line's GUID. at: the time Better Timestamps shows (now when nil).
function Lines.Build(db, stamp, body, chatType, args, size, sayTag, icons, at)
    local senderIcons = db.raceIcons or db.classIcons
    if sayTag then
        local rewritten = Lines.RewriteSender(body, chatType)
        if rewritten ~= body then body = sayTag .. rewritten end
    elseif db.shortChannels then
        body = Lines.ShortenChannel(body, chatType, db.channelNames == "short" and "short" or "number")
    end
    if args then
        if NPC_EVENTS[chatType] then
            if db.formatNPC then body = Lines.RewriteNPC(body, chatType, args) end
        elseif db.formatPlayer and not sayTag and NAME_EVENTS[chatType] == "full" then
            body = Lines.RewriteSender(body, chatType)
        end
        if db.whisperMarkers and Lines.marks[chatType] then body = Lines.RewriteWhisper(body, chatType) end
        if senderIcons and NAME_EVENTS[chatType] then
            if icons == nil then
                local guid = Arg(args, 12, "string")
                icons = guid and guid ~= "" and Lines.SenderIcons(guid, size, db.raceIcons, db.classIcons) or ""
            end
            if icons ~= "" then body = Lines.AddSenderIcons(body, icons) end
        end
    end
    if db.linkIcons then body = Lines.LinkIcons(body, size) end
    if db.betterTimestamps then stamp = GetTimestamp(at) end
    return stamp .. body
end

local function RewriteStoredLine(chatFrame, message, _, _, _, _, _, _, event, eventArgs)
    local db = GetDb()
    if not (db and event) then return end
    if not canaccessallvalues(message, event) or type(message) ~= "string" or type(event) ~= "string"
            or event:sub(1, 9) ~= "CHAT_MSG_" then return end
    local chatType = event:sub(10)
    -- with Better Player Names (which drops "says:"), a Say line gets its clickable label instead;
    -- off, the line stays Blizzard's. Short Channel Names picks [S] or [Say].
    local sayTag = chatType == "SAY" and db.formatPlayer and (db.shortChannels and SHORT_SAY_TAG or SAY_TAG)
    local senderIcons = db.raceIcons or db.classIcons
    if not (sayTag or db.shortChannels or db.formatPlayer or db.formatNPC or db.betterTimestamps or senderIcons
            or db.linkIcons or db.whisperMarkers) then return end
    -- icons follow each window's font
    local size = (senderIcons or db.linkIcons) and Lines.IconSize(chatFrame) or 0
    -- the same line shown in several windows (General and a Guild tab, say) is worked out once
    local line
    local now = time()
    if message == Lines.lastIn and event == Lines.lastEvent and now == Lines.lastAt and sayTag == Lines.lastSayTag
            and size == Lines.lastSize then
        line = Lines.lastOut
    else
        local args = type(eventArgs) == "table" and canaccesstable(eventArgs) and eventArgs or nil
        -- Keep Blizzard's timestamp ahead of the new Say prefix, even if it isn't replaced.
        local stamp, body = "", message
        if db.betterTimestamps or sayTag then stamp, body = Lines.SplitStamp(message) end
        line = Lines.Build(db, stamp, body, chatType, args, size, sayTag)
        Lines.lastIn, Lines.lastEvent, Lines.lastOut, Lines.lastAt = message, event, line, now
        Lines.lastSayTag, Lines.lastSize = sayTag, size
    end
    if line == message then return end
    local entry = chatFrame.historyBuffer and chatFrame.historyBuffer:GetEntryAtIndex(1)
    if entry and canaccessallvalues(entry.message) and entry.message == message then
        -- Blizzard's AddMessage has just marked the window for a redraw, which shows the new text
        entry.message = line
    end
end

-- Every chat window, temporary whisper windows included
local function HookLineRewrite()
    if not Lines.nameFilter and ChatFrameUtil and ChatFrameUtil.AddSenderNameFilter then
        Lines.nameFilter = true
        ChatFrameUtil.AddSenderNameFilter(Lines.SenderName)
    end
    for _, name in ipairs(CHAT_FRAMES or {}) do
        local frame = _G[name]
        if frame and not Lines.hooked[frame] then
            hooksecurefunc(frame, "AddMessage", RewriteStoredLine)
            Lines.hooked[frame] = true
        end
    end
    if not Lines.tempHooked and FCF_OpenTemporaryWindow then
        Lines.tempHooked = true
        hooksecurefunc("FCF_OpenTemporaryWindow", HookLineRewrite)
    end
end

-- GetGuildRosterInfo through pcall: name is its 1st return, level its 4th, GUID its 17th
local function RememberGuildMember(ok, name, _, _, level, ...)
    if ok then Lines.Remember(select(13, ...), name, level) end
end

-- Levels for the senders' names, collected while Level Before Names is on
function Lines.UpdateLevelEvents()
    local db = GetDb()
    local want = db and db.showLevel
    if not Lines.events then
        if not want then return end
        local f = CreateFrame("Frame")
        f:SetScript("OnEvent", function(_, event, unit)
            if event == "GUILD_ROSTER_UPDATE" then
                if not GetGuildRosterInfo then return end
                -- the event comes often and a big guild is a long walk
                local now = GetTime()
                if f.guildReadAt and now - f.guildReadAt < 30 then return end
                local count = GetNumGuildMembers()
                -- (empty at login: the full roster's event still gets through)
                if count > 0 then f.guildReadAt = now end
                for i = 1, count do
                    RememberGuildMember(pcall(GetGuildRosterInfo, i))
                end
            elseif event == "FRIENDLIST_UPDATE" then
                for i = 1, C_FriendList.GetNumFriends() do
                    local info = C_FriendList.GetFriendInfoByIndex(i)
                    if info then Lines.Remember(info.guid, info.name, info.level) end
                end
            elseif event == "WHO_LIST_UPDATE" then
                for i = 1, C_FriendList.GetNumWhoResults() do
                    local info = C_FriendList.GetWhoInfo(i)
                    if info then Lines.Remember(nil, info.fullName, info.level) end
                end
            elseif event == "GROUP_ROSTER_UPDATE" then
                local prefix = IsInRaid() and "raid" or "party"
                for i = 1, IsInRaid() and 40 or 4 do Lines.RememberUnit(prefix .. i) end
            elseif event == "PLAYER_TARGET_CHANGED" then
                Lines.RememberUnit("target")
            elseif event == "UPDATE_MOUSEOVER_UNIT" then
                Lines.RememberUnit("mouseover")
            elseif event == "NAME_PLATE_UNIT_ADDED" or event == "UNIT_LEVEL" then
                Lines.RememberUnit(unit)
            elseif event == "PLAYER_LEVEL_UP" then
                Lines.RememberUnit("player")
            end
        end)
        Lines.events = f
    end
    local f = Lines.events
    if want then
        for _, event in ipairs({ "GUILD_ROSTER_UPDATE", "FRIENDLIST_UPDATE", "WHO_LIST_UPDATE",
                "GROUP_ROSTER_UPDATE", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED",
                "UNIT_LEVEL", "PLAYER_LEVEL_UP" }) do
            f:RegisterEvent(event)
        end
        if IsInGuild() and C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
    else
        f:UnregisterAllEvents()
    end
end

--------------------------------------------------
-- 6. IMPROVEMENTS
--------------------------------------------------

-- Chat bubbles off inside instances. The player's values are saved account-wide while hidden, so a
-- reload or logout inside still restores them.
local BUBBLE_CVARS = { "chatBubbles", "chatBubblesParty" }

local function RestoreBubbles(global)
    for cvar, value in pairs(global.hiddenBubbles) do C_CVar.SetCVar(cvar, value) end
    global.hiddenBubbles = nil
end

function Chat:UpdateInstanceBubbles()
    local db, global = GetDb(), ns.db and ns.db.global
    if not global then return end
    local saved = global.hiddenBubbles
    if db and db.hideBubblesInInstance and IsInInstance() then
        if not saved then
            saved = {}
            for _, cvar in ipairs(BUBBLE_CVARS) do saved[cvar] = C_CVar.GetCVar(cvar) end
            global.hiddenBubbles = saved
        end
        for _, cvar in ipairs(BUBBLE_CVARS) do C_CVar.SetCVar(cvar, "0") end
    elseif saved then
        RestoreBubbles(global)
    end
end

local function HandleCombatLog(db)
    local tab2 = _G.ChatFrame2Tab
    if not tab2 then return end
    if db.hideCombatLog then
        tab2:Hide()
        tab2:SetWidth(0.001)
    end
end

-- Blizzard hides these buttons with ChatFrame1ButtonFrame, which stays hidden, so an OnHide hook
-- re-shows them. Never replace their Hide method: that taints every caller. A button FlareUI hides
-- itself stays hidden, or it would bounce between its OnShow and OnHide hooks.
local PROTECTED_BUTTONS = {
    { name = "ChatFrameMenuButton",    key = "menuHide" },
    { name = "ChatFrameChannelButton", key = "channelHide" },
    { name = "QuickJoinToastButton",   key = "socialHide" },
}

function Chat:ProtectButtons()
    for _, entry in ipairs(PROTECTED_BUTTONS) do
        local btn = _G[entry.name]
        if btn and not btn.FlareUI_Protected then
            btn.FlareUI_Protected = true
            btn:HookScript("OnHide", function(self)
                local db = GetDb()
                if not db or not db.enabled then return end
                if db[entry.key] or self.FlareUI_ForceHidden or InCombatLockdown() then return end
                self:Show()
            end)
        end
    end
    DisableQuickJoinToasts()
end

-- The shared header buttons sit on one skin: the visible one. A new window is selected before it is
-- shown, so the selected frame alone is not enough.
local function VisibleSkinHost()
    local function Usable(cf)
        return cf and not cf:IsForbidden() and cf.FlareUI_Skin and cf:IsShown() and not IsPopped(cf) and cf
    end

    local host = Usable(SELECTED_CHAT_FRAME) or Usable(ChatFrame1)
    if host then return host end
    for i = 1, NUM_CHAT_WINDOWS do
        host = Usable(_G["ChatFrame" .. i])
        if host then return host end
    end
    return ChatFrame1
end

-- Header buttons sit right to left, packed: a hidden one leaves no gap. The Gamepad UI hides them
-- all (its footer prompts replace them).
local HEADER_ORDER = { "volume", "social", "menu", "channel" }
local HEADER_FIRST_X, HEADER_STEP = -25, -35

local function HeaderButtonShown(db, name)
    if ns.IsGamepadUI() then return false end
    if name == "volume" then return db.showVolume and true or false end
    return not db[name .. "Hide"]
end

-- The player's order (dragged on the header), right to left; missing keys go on the end
local function HeaderOrder(db)
    local saved = db and db.headerOrder
    if type(saved) ~= "table" then return HEADER_ORDER end
    local order, seen = {}, {}
    for _, key in ipairs(saved) do
        if tContains(HEADER_ORDER, key) and not seen[key] then
            order[#order + 1] = key
            seen[key] = true
        end
    end
    for _, key in ipairs(HEADER_ORDER) do
        if not seen[key] then order[#order + 1] = key end
    end
    return order
end

local function HeaderButtonX(db, name)
    local slot = 0
    for _, key in ipairs(HeaderOrder(db)) do
        if key == name then return HEADER_FIRST_X + slot * HEADER_STEP end
        if HeaderButtonShown(db, key) then slot = slot + 1 end
    end
    return HEADER_FIRST_X
end

--------------------------------------------------
-- 7. HEADER BUTTONS
-- A header button is dragged onto another's place; a bronze bar marks the target. Blizzard's Chat
-- Menu opens on mouse down, so the drag closes it again.
--------------------------------------------------
local HEADER_BLIZZARD = { social = "QuickJoinToastButton", menu = "ChatFrameMenuButton", channel = "ChatFrameChannelButton" }
local headerDrag = { key = nil, header = nil, button = nil, marker = nil, driver = CreateFrame("Frame") }

-- The header's button for key (the volume button is each skin's own)
local function HeaderButtonOf(header, key)
    if key == "volume" then
        for _, cf in Windows() do
            if cf and cf.FlareUI_Skin == header then return cf.FlareUI_VolumeBtn end
        end
        return nil
    end
    local btn = _G[HEADER_BLIZZARD[key]]
    if btn and btn:GetParent() == header then return btn end
    return nil
end

-- The visible button nearest the cursor along the header
local function HeaderDropTarget(header)
    local x = GetCursorPosition() / header:GetEffectiveScale()
    local best, bestDistance
    for _, key in ipairs(HEADER_ORDER) do
        local btn = HeaderButtonOf(header, key)
        if btn and btn:IsVisible() then
            local left, right = btn:GetLeft(), btn:GetRight()
            if left and right then
                local scale = btn:GetEffectiveScale() / header:GetEffectiveScale()
                local distance = math_abs((left + right) / 2 * scale - x)
                if not bestDistance or distance < bestDistance then best, bestDistance = key, distance end
            end
        end
    end
    return best
end

local function UpdateHeaderMarker()
    local header = headerDrag.header
    local target = header and HeaderDropTarget(header)
    local btn = target and HeaderButtonOf(header, target)
    local marker = headerDrag.marker
    if not (btn and marker) then return end
    marker:ClearAllPoints()
    marker:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -1)
    marker:SetPoint("TOPRIGHT", btn, "BOTTOMRIGHT", 0, -1)
    marker:SetShown(target ~= headerDrag.key)
end

local function StartHeaderDrag(key, header)
    if headerDrag.key or not header then return end
    local btn = HeaderButtonOf(header, key)
    if not btn then return end
    -- the press that began this drag opened Blizzard's chat menu
    local menu = _G.ChatFrameMenuButton
    if key == "menu" and menu and menu.IsMenuOpen and menu:IsMenuOpen() then pcall(menu.CloseMenu, menu) end
    if not headerDrag.marker or headerDrag.marker:GetParent() ~= header then
        if headerDrag.marker then headerDrag.marker:Hide() end
        local holder = header.FlareUI_DragMarker
        if not holder then
            holder = CreateFrame("Frame", nil, header)
            holder:SetAllPoints()
            holder:SetFrameStrata("DIALOG")
            holder:SetFrameLevel(230)
            header.FlareUI_DragMarker = holder
        end
        local marker = holder.bar
        if not marker then
            marker = holder:CreateTexture(nil, "OVERLAY")
            marker:SetHeight(2)
            local c = ns.BORDER_COLOR
            marker:SetColorTexture(c.r, c.g, c.b, 1)
            holder.bar = marker
        end
        headerDrag.marker = marker
    end
    headerDrag.key, headerDrag.header, headerDrag.button = key, header, btn
    btn:SetAlpha(0.5)
    headerDrag.driver:SetScript("OnUpdate", UpdateHeaderMarker)
end

local function StopHeaderDrag()
    local key, header, btn = headerDrag.key, headerDrag.header, headerDrag.button
    if not key then return end
    headerDrag.driver:SetScript("OnUpdate", nil)
    if headerDrag.marker then headerDrag.marker:Hide() end
    headerDrag.key, headerDrag.header, headerDrag.button = nil, nil, nil
    btn:SetAlpha(1)
    local target = HeaderDropTarget(header)
    local db = GetDb()
    if db and target and target ~= key then
        -- the dragged button takes the target's slot; the ones between shift over by one
        local old = HeaderOrder(db)
        local from, to = tIndexOf(old, key), tIndexOf(old, target)
        if not (from and to) then return end   -- a button not in the saved order (hidden, or new)
        local order = {}
        for _, k in ipairs(old) do if k ~= key then order[#order + 1] = k end end
        local at = tIndexOf(order, target)
        table.insert(order, from < to and at + 1 or at, key)
        db.headerOrder = order
        for _, cf in Windows() do
            if cf and cf.FlareUI_Skin then Chat:SetupVolumeButton(cf, db) end
        end
        Chat:StyleHeaderButtons()
    end
end

local function OnHeaderDragStart(self) StartHeaderDrag(self.FlareUI_DragKey, self:GetParent()) end

local function EnableHeaderDrag(btn, key)
    if btn.FlareUI_DragKey then return end
    btn.FlareUI_DragKey = key
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", OnHeaderDragStart)
    btn:SetScript("OnDragStop", StopHeaderDrag)
end

-- a header button's hover fades the chat in; its icon lightens
local function HeaderButtonEnter(btn)
    ns.BronzeIcon.Paint(btn.FlareUI_Icon, btn.FlareUI_Color, true)
    GameTooltip:Hide()
    Chat:ShowChatFrame(SELECTED_CHAT_FRAME or ChatFrame1, GetDb())
end

local function HeaderButtonLeave(btn)
    ns.BronzeIcon.Paint(btn.FlareUI_Icon, btn.FlareUI_Color, false)
end

local function HeaderButtonDown(btn) btn.FlareUI_Icon:SetPoint("TOPLEFT", 1, -1) end
local function HeaderButtonUp(btn) btn.FlareUI_Icon:SetPoint("TOPLEFT", 0, 0) end

-- a flashing button (a new invite, say) fades the chat in
local function HeaderFlashShown()
    Chat:ShowChatFrame(SELECTED_CHAT_FRAME or ChatFrame1, GetDb())
end

local function KillTexture(tex) if tex then tex:SetAlpha(0) end end

-- A header button's icon in struck bronze (also the settings preview's sample buttons)
function Chat.HeaderIcon(btn, iconPath)
    if not btn.FlareUI_Icon then
        btn.FlareUI_Icon = btn:CreateTexture(nil, "ARTWORK")
        btn.FlareUI_Icon:SetAllPoints()
    end
    btn.FlareUI_Color = HEADER_ICON_COLOR
    ns.BronzeIcon.Apply(btn.FlareUI_Icon, iconPath, HEADER_ICON_COLOR)
end

-- An error inside (reported) must not leave the guard up: every later call would be skipped
function Chat:StyleHeaderButtons(chatFrame)
    if self.isStyling then return end
    self.isStyling = true
    local ok, err = pcall(self.StyleHeaderButtonsBody, self, chatFrame)
    self.isStyling = false
    if not ok then geterrorhandler()(err) end
end

function Chat:StyleHeaderButtonsBody(chatFrame)
    local db = GetDb()
    local target = chatFrame or VisibleSkinHost()
    if target and IsPopped(target) then target = VisibleSkinHost() end   -- the buttons stay on the dock
    if not target or not target.FlareUI_Skin then
        target = ChatFrame1
    end
    if not db or not target or not target.FlareUI_Skin then return end
    local header = target.FlareUI_Skin

    local function SetupBtn(btn, iconPath, key)
        if not btn then return end
        EnableHeaderDrag(btn, key)

        -- a post-hook: the social button registers for clicks in Blizzard's own OnShow
        if not btn.FlareUI_ShowHooked then
            btn.FlareUI_ShowHooked = true
            btn:HookScript("OnShow", function(s) if s.FlareUI_ForceHidden then s:Hide() end end)
        end
        local hide = not HeaderButtonShown(db, key)
        btn.FlareUI_ForceHidden = hide
        if hide then
            btn:Hide()
            return
        end

        btn:Show()
        -- on the skin, so it fades with it
        btn:SetParent(header)
        btn:ClearAllPoints()
        btn:SetPoint("TOPRIGHT", header, "TOPRIGHT", HeaderButtonX(db, key), HEADER_ICON_Y)
        btn:SetScale(HEADER_ICON_SCALE)
        btn:SetFrameStrata("DIALOG")
        btn:SetFrameLevel(210)

        btn:SetSize(22, 22)

        if btn.GetNumRegions then
            local nr = btn:GetNumRegions()
            for ri = 1, nr do
                local reg = select(ri, btn:GetRegions())
                if reg and reg:GetObjectType() == "Texture" then reg:SetAlpha(0) end
            end
        end

        Chat.HeaderIcon(btn, iconPath)
        btn.FlareUI_Icon:Show()

        if not btn.FlareUI_TextureHooked then
            btn.FlareUI_TextureHooked = true
            Chat:SecureHook(btn, "SetNormalTexture", function(frameParam) KillTexture(frameParam:GetNormalTexture()) end)
            Chat:SecureHook(btn, "SetPushedTexture", function(frameParam) KillTexture(frameParam:GetPushedTexture()) end)
            Chat:SecureHook(btn, "SetHighlightTexture", function(frameParam) KillTexture(frameParam:GetHighlightTexture()) end)
            KillTexture(btn:GetNormalTexture())
            KillTexture(btn:GetPushedTexture())
            KillTexture(btn:GetHighlightTexture())
            if btn.Flash then Chat:SecureHookScript(btn.Flash, "OnShow", HeaderFlashShown) end
        end

        if key == "social" then
            if btn.FriendsButton then btn.FriendsButton:SetAlpha(0) end
            if btn.QueueButton then btn.QueueButton:SetAlpha(0) end
            local count = _G[btn:GetName().."FriendCount"] or btn.FriendCount
            if count then count:SetAlpha(0) end
        end

        btn:SetScript("OnEnter", HeaderButtonEnter)
        btn:SetScript("OnLeave", HeaderButtonLeave)
        btn:SetScript("OnMouseDown", HeaderButtonDown)
        btn:SetScript("OnMouseUp", HeaderButtonUp)
    end

    SetupBtn(_G.QuickJoinToastButton,   ICON_SOCIAL,   "social")
    SetupBtn(_G.ChatFrameChannelButton, ICON_CHANNELS, "channel")
    SetupBtn(_G.ChatFrameMenuButton,    ICON_MENU,     "menu")
end

--------------------------------------------------
-- 8. COPY CHAT LINKS
-- Web addresses in chat become links that open a box to copy them from.
--------------------------------------------------
local URL_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_CHANNEL",
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM",
    "CHAT_MSG_SYSTEM",
}

-- A word is a web address when it starts with a scheme ("https://") or with "www." and a domain.
-- Brackets and punctuation around it stay outside the link.
local function LinkAddress(word)
    local head, address, tail = word:match("^([%(%[]*)(.-)([%.,;:!%?%)%]]*)$")
    if address:match("^%a%a+://%S") or address:match("^www%.[%w%-]+%.%a%a") then
        return head .. "|cff00b2ff|Hflareurl:" .. address .. "|h[" .. address .. "]|h|r" .. tail
    end
end

local copyFrame

local function ShowCopyBox(url)
    if not copyFrame then
        local f = CreateFrame("Frame", "FlareUI_CopyLink", UIParent, "BackdropTemplate")
        f:SetSize(420, 70)
        f:SetPoint("CENTER")
        -- above the settings panel (DIALOG, raised to the top when clicked), which opens it from its links
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetToplevel(true)
        f:SetScript("OnHide", function() PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE) end)
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = LSM:Fetch("border", "Blizzard Tooltip"),
                        edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
        f:SetBackdropColor(0, 0, 0, 0.95)
        f:SetBackdropBorderColor(ns.BORDER_COLOR.r, ns.BORDER_COLOR.g, ns.BORDER_COLOR.b, 1)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)

        local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", 14, -10)
        label:SetText(L["Ctrl+C to copy, Esc to close"])

        local box = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        box:SetPoint("BOTTOMLEFT", 16, 14)
        box:SetPoint("BOTTOMRIGHT", -14, 14)
        box:SetHeight(22)
        box:SetAutoFocus(true)
        box:SetScript("OnEscapePressed", function() f:Hide() end)
        box:SetScript("OnEnterPressed", function() f:Hide() end)
        f.box = box
        tinsert(UISpecialFrames, "FlareUI_CopyLink")
        copyFrame = f
    end
    copyFrame.box:SetText(url)
    copyFrame.box:HighlightText()
    copyFrame.box:SetFocus()
    if not copyFrame:IsShown() then PlaySound(SOUNDKIT.IG_MAINMENU_OPEN) end
    copyFrame:Show()
    copyFrame:Raise()
end

-- The copy box, for other modules and the settings panel's links
function Chat.ShowCopyText(text) ShowCopyBox(text) end

-- A chat line as plain text: colour, icon and link codes would paste as gibberish
function Chat.PlainLine(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:]*:", ""):gsub("|r", "")
        :gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|K.-|k", ""):gsub("||", "|")
    return text
end

-- Copy Chat (the copy button in each window): a read-only window with a chat window's lines, all selected.
-- Lines the game keeps secret can't be read, so they're left out and the window says so.
function Chat:ShowCopyChat(chatFrame)
    local f = self.copyChatFrame
    if not f then
        f = CreateFrame("Frame", "FlareUI_CopyChat", UIParent, "BackdropTemplate")
        f:SetSize(640, 440)
        f:SetPoint("CENTER")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetToplevel(true)
        f:SetClampedToScreen(true)
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = LSM:Fetch("border", "Blizzard Tooltip"),
                        edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
        f:SetBackdropColor(0, 0, 0, 0.95)
        f:SetBackdropBorderColor(ns.BORDER_COLOR.r, ns.BORDER_COLOR.g, ns.BORDER_COLOR.b, 1)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)

        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.title:SetPoint("TOPLEFT", 14, -12)
        f.title:SetPoint("RIGHT", -34, 0)
        f.title:SetJustifyH("LEFT")
        f.title:SetWordWrap(false)
        f.note = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        f.note:SetPoint("BOTTOMLEFT", 14, 10)
        f.note:SetPoint("RIGHT", -14, 0)
        f.note:SetJustifyH("LEFT")
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -2, -2)

        local scroll = CreateFrame("ScrollFrame", nil, f)
        scroll:SetPoint("TOPLEFT", 14, -34)
        scroll:SetPoint("BOTTOMRIGHT", -24, 28)
        f.scroll = scroll
        local box = CreateFrame("EditBox", nil, scroll)
        box:SetMultiLine(true)
        box:SetAutoFocus(false)
        box:SetMaxLetters(0)
        box:SetFontObject("ChatFontNormal")
        box:SetWidth(640 - 14 - 24)
        box:SetScript("OnEscapePressed", function() f:Hide() end)
        -- read-only: typing puts the lines back
        box:SetScript("OnTextChanged", function(self, userInput)
            if not userInput then return end
            self:SetText(f.text or "")
            self:HighlightText()
        end)
        scroll:SetScrollChild(box)
        f.box = box
        ns.SettingsPanel.AttachScrollLine(scroll, f)

        f:SetScript("OnHide", function()
            box:ClearFocus()
            PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
        end)
        tinsert(UISpecialFrames, "FlareUI_CopyChat")
        self.copyChatFrame = f
    end

    local lines, hidden = {}, 0
    for i = 1, chatFrame:GetNumMessages() do
        local msg = chatFrame:GetMessageInfo(i)
        -- canaccessvalue first, before any other test
        if not canaccessvalue(msg) then
            hidden = hidden + 1
        elseif type(msg) == "string" then
            lines[#lines + 1] = Chat.PlainLine(msg)
        end
    end
    f.text = table.concat(lines, "\n")
    -- a whisper window's name can be secret
    local windowName = canaccessvalue(chatFrame.name) and chatFrame.name or ""
    f.title:SetText(L["Copy Chat"] .. ": " .. windowName .. "  |cff808080" .. L["Ctrl+C to copy, Esc to close"] .. "|r")
    f.note:SetText(hidden > 0 and L["Some lines are left out: the game keeps them hidden."] or "")
    f.box:SetText(f.text)
    if not f:IsShown() then PlaySound(SOUNDKIT.IG_MAINMENU_OPEN) end
    f:Show()
    f:Raise()
    f.box:SetFocus()
    f.box:HighlightText()
    -- newest lines in view, once the box has its height
    C_Timer.After(0.05, function()
        if f:IsShown() then f.scroll:SetVerticalScroll(f.scroll:GetVerticalScrollRange() or 0) end
    end)
end

-- The plain stretches of a line get their addresses linked; a hyperlink (|H...|h...|h) is kept whole
local function LinkPlainText(msg)
    if not msg:find("|H", 1, true) then return (msg:gsub("%S+", LinkAddress)) end
    local out, pos = {}, 1
    while true do
        local s, e = msg:find("|H.-|h.-|h", pos)
        if not s then break end
        out[#out + 1] = msg:sub(pos, s - 1):gsub("%S+", LinkAddress)
        out[#out + 1] = msg:sub(s, e)
        pos = e + 1
    end
    out[#out + 1] = msg:sub(pos):gsub("%S+", LinkAddress)
    return table.concat(out)
end

-- Blizzard only calls filters with accessible values, so no secret check is needed
local function URLFilter(self, event, msg, ...)
    if type(msg) ~= "string" then return false, msg, ... end
    -- most lines hold no address: skip the per-word scan
    if not (msg:find("://", 1, true) or msg:find("www.", 1, true)) then return false, msg, ... end
    return false, LinkPlainText(msg), ...
end

-- Registered once for the session (LinkUtil asserts on a second registration)
local function RegisterURLHandler()
    if LinkUtil.IsLinkHandlerRegistered("flareurl") then return end
    LinkUtil.RegisterLinkHandler("flareurl", function(link, text)
        ShowCopyBox((link and link:match("^flareurl:(.+)$")) or text)
    end)
end

local urlFilterActive = false

function Chat:SetupCopyLinks()
    local db = GetDb()
    if not db then return end
    if db.copyLinks and not urlFilterActive then
        urlFilterActive = true
        RegisterURLHandler()
        for _, event in ipairs(URL_EVENTS) do
            ChatFrameUtil.AddMessageEventFilter(event, URLFilter)
        end
    elseif not db.copyLinks and urlFilterActive then
        urlFilterActive = false
        for _, event in ipairs(URL_EVENTS) do
            ChatFrameUtil.RemoveMessageEventFilter(event, URLFilter)
        end
    end
end

--------------------------------------------------
-- 9. HOVER TOOLTIPS
-- Hovering a chat link shows its tooltip until the mouse leaves. Blizzard's chat frames announce
-- link hovers through EventRegistry, so no frame script is touched. Only links the game tooltip can
-- draw; secret links are left alone.
--------------------------------------------------
local HOVER_LINKS = {
    item = true, spell = true, enchant = true, quest = true, talent = true,
    achievement = true, currency = true, instancelock = true,
}
local hover = { owner = nil, registered = false }

function hover.Enter(_, chatFrame, link)
    local db = GetDb()
    if not (db and db.enabled and db.hoverTooltips) then return end
    if not (canaccessvalue(link) and type(link) == "string") then return end
    local kind = link:match("^(%a+):")
    if not (kind and HOVER_LINKS[kind]) then return end
    GameTooltip:SetOwner(chatFrame, "ANCHOR_CURSOR")
    if pcall(GameTooltip.SetHyperlink, GameTooltip, link) then
        GameTooltip:Show()
        hover.owner = chatFrame
    else
        GameTooltip:Hide()
    end
end

function hover.Leave()
    if hover.owner and GameTooltip:IsOwned(hover.owner) then GameTooltip:Hide() end
    hover.owner = nil
end

-- Registered once for the session; the setting is read on every hover
function Chat:SetupHoverTooltips()
    if hover.registered or not (EventRegistry and EventRegistry.RegisterCallback) then return end
    hover.registered = true
    EventRegistry:RegisterCallback("ChatFrame.OnHyperlinkEnter", hover.Enter, hover)
    EventRegistry:RegisterCallback("ChatFrame.OnHyperlinkLeave", hover.Leave, hover)
end

--------------------------------------------------
-- 10. TAB MENU AND DOCK
--------------------------------------------------
function Chat:SetupImprovements()
    local db = GetDb()
    if not db then return end

    Chat:SetupCopyLinks()
    Chat:SetupHoverTooltips()
    HookLineRewrite()
    Chat:UpdateInstanceBubbles()
    Chat:StyleHeaderButtons()
    DisableQuickJoinToasts()
    AnchorShardNotice()
    AnchorBNToast()
    if _G.TextToSpeechButton then _G.TextToSpeechButton:Hide(); _G.TextToSpeechButton:SetScript("OnShow", function(s) s:Hide() end) end
end

function Chat:OpenContextMenu(tabButton, chatFrame)
    -- in the Gamepad UI a menu opened from addon code hangs the client; Tab Settings (Y) has these
    if ns.IsGamepadUI() then return end

    MenuUtil.CreateContextMenu(tabButton, function(owner, rootDescription)
        local editMode = rootDescription:CreateButton(EDIT_MODE or "Edit Mode", function()
            if EditModeManagerFrame and not InCombatLockdown() then ShowUIPanel(EditModeManagerFrame) end
        end)
        editMode:SetEnabled(EditModeManagerFrame ~= nil and EditModeManagerFrame:CanEnterEditMode() and not InCombatLockdown())

        rootDescription:CreateButton(RENAME_CHAT_WINDOW, function()
            ns.ShowDialog("FLAREUI_RENAME_CHAT", nil, chatFrame)
        end)

        -- greyed out with all ten windows in use, as in Blizzard's menu
        local newWindow = rootDescription:CreateButton(NEW_CHAT_WINDOW, function()
            local baseName = "New"
            local name = baseName
            local count = 1
            while true do
                local exists = false
                for i = 1, NUM_CHAT_WINDOWS do
                    local f = _G["ChatFrame"..i]
                    if f and f.name == name and f:IsShown() then
                        exists = true; break
                    end
                end
                if not exists then break end
                name = baseName .. " " .. count
                count = count + 1
            end
            FCF_OpenNewWindow(name)
        end)
        if _G.FCF_CanOpenNewWindow then newWindow:SetEnabled(FCF_CanOpenNewWindow()) end

        -- Blizzard's own toggle and text: links off and no resizing, for the docked windows together
        if _G.FCF_SetExpandedUninteractable and _G.MAKE_UNINTERACTABLE and _G.MAKE_INTERACTABLE then
            rootDescription:CreateButton(chatFrame.isUninteractable and MAKE_INTERACTABLE or MAKE_UNINTERACTABLE, function()
                FCF_SetExpandedUninteractable(chatFrame, not chatFrame.isUninteractable)
            end)
        end

        rootDescription:CreateDivider()

        rootDescription:CreateButton(L["Chat Settings"], function()
            if ns.SettingsPanel then ns.SettingsPanel:Open("ch") end
        end)

        rootDescription:CreateButton(L["Filter Settings"], function()
            if ChatConfigFrame then
                -- the window the dialog edits, as Blizzard's right click sets it (otherwise the dialog
                -- edits whichever window Blizzard last had; only this dialog reads it)
                _G.CURRENT_CHAT_FRAME_ID = chatFrame:GetID()
                ShowUIPanel(ChatConfigFrame)
            end
        end)

        if IsPopped(chatFrame) then
            rootDescription:CreateDivider()
            rootDescription:CreateButton(L["Dock"], function() Chat:DockWindow(chatFrame) end)
            -- not on a whisper window: Blizzard reuses those, and its own code reads the lock
            if not chatFrame.isTemporary then
                rootDescription:CreateButton(chatFrame.isLocked and UNLOCK_WINDOW or LOCK_WINDOW, function()
                    FCF_SetLocked(chatFrame, not chatFrame.isLocked)
                end)
            end
        elseif chatFrame:GetID() ~= 1 and chatFrame ~= _G.ChatFrame2 and not chatFrame.isTemporary then
            rootDescription:CreateDivider()
            rootDescription:CreateButton(L["Pop Out"], function() Chat:PopOutWindow(chatFrame) end)
        end

        if chatFrame:GetID() ~= 1 then
            rootDescription:CreateDivider()
            -- as Blizzard closes it: a window's channels (and a whisper window's person) go back to
            -- the main window first; only other temporary windows (the pet battle log) just close
            local whisper = chatFrame.chatType == "WHISPER" or chatFrame.chatType == "BN_WHISPER"
            local label = whisper and CLOSE_CHAT_WHISPER_WINDOW or CLOSE_CHAT_WINDOW
            rootDescription:CreateButton(label, function()
                if chatFrame.isTemporary and not whisper then FCF_Close(chatFrame) else FCF_PopInWindow(chatFrame) end
            end)
        end
    end)
end

-- Blizzard's tab dock stays alive but out of sight. In the Gamepad UI the tab menu (Y) opens on the
-- real tab, so the dock lies invisible across the chat header, its tabs deaf to the mouse.
local function ParkDock(dock)
    dock:ClearAllPoints()
    local host = _G.ChatFrame1 and _G.ChatFrame1.FlareUI_Skin
    if ns.IsGamepadUI() and host then
        dock:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
        dock:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, 0)
        for i = 1, NUM_CHAT_WINDOWS do
            local tab = _G["ChatFrame" .. i .. "Tab"]
            if tab then tab:EnableMouse(false) end
        end
    else
        dock:SetPoint("BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", -10000, -10000)
    end
end

function Chat:KillGeneralDockManager()
    local dock = _G.GeneralDockManager
    if dock then
        dock.FlareUI_Moving = true
        ParkDock(dock)
        dock.FlareUI_Moving = false
        if ns.IsGamepadUI() then
            if dock.overflowButton then dock.overflowButton:EnableMouse(false) end
        else
            dock:SetWidth(1); dock:SetHeight(1)
        end
        dock:SetAlpha(0)
        dock:EnableMouse(false)
        dock:SetScript("OnUpdate", nil); dock:SetScript("OnEnter", nil); dock:SetScript("OnLeave", nil)

        if not dock.FlareUI_Hooked then
            Chat:SecureHook(dock, "SetPoint", function(frameParam)
                if not frameParam.FlareUI_Moving and not InCombatLockdown() then
                    frameParam.FlareUI_Moving = true
                    ParkDock(frameParam)
                    frameParam.FlareUI_Moving = false
                end
            end)
            dock.FlareUI_Hooked = true
        end
    end

    local scroll = _G.GeneralDockManagerScrollFrame
    if scroll then
        if not ns.IsGamepadUI() then scroll:SetWidth(1); scroll:SetHeight(1) end
        scroll:EnableMouse(false)
    end
end

--------------------------------------------------
-- 11. METER TAB
-- Blizzard's damage meter as a tab of the bar (Settings > Damage Meter > Meter Tab in the Chat). The
-- Damage Meter module keeps the meter in the main window and sets its alpha (DamageMeter.lua, METER
-- TAB IN THE CHAT); the chat draws the tab after the windows' tabs, hides the shown window's text
-- under the meter, lends the meter its fades and lights a tab whose lines it hides.
--------------------------------------------------
local meterUnread = {}   -- chat frame -> true: a line arrived while the Meter tab hid it

local function MeterTabAvailable()
    local dm = ns.DamageMeter
    return dm ~= nil and dm.ChatTabAvailable ~= nil and dm:ChatTabAvailable() or false
end

-- asked on every alpha step and every line: two fields, no call
function Chat:MeterTabActive()
    local dm = ns.DamageMeter
    return dm ~= nil and dm.chatTabActive == true and dm.chatTabApplied == true
end

local function SelectedDocked()
    local dock = _G.GeneralDockManager
    return (dock and FCFDock_GetSelectedWindow(dock)) or _G.ChatFrame1
end

-- The docked windows' text, and what goes with it, under the meter or back
local function SetDockedTextShown(shown)
    local dock = _G.GeneralDockManager
    local alpha = shown and 1 or 0
    for _, frame in ipairs(dock and dock.DOCKED_CHAT_FRAMES or {}) do
        if not frame:IsForbidden() then
            if frame.FontStringContainer then frame.FontStringContainer:SetAlpha(alpha) end
            if frame.ScrollToBottomButton then frame.ScrollToBottomButton:SetAlpha(alpha) end
            -- under the meter the copy button would copy the hidden chat: it goes too
            if frame.FlareUI_CopyButton then frame.FlareUI_CopyButton:SetShown(shown and (GetDb() or {}).copyButton or false) end
        end
    end
    local bar = _G.CombatLogQuickButtonFrame_Custom
    if bar then bar:SetAlpha(alpha) end
end

-- With the chat fading (Visibility), the meter takes the mouse the window would see: a hover over it
-- brings a fading or faded window back, checked ten times a second while the Meter tab is selected.
-- A window fully up needs no check: its hold asks CheckChatVisibility when it runs out.
local meterHover = CreateFrame("Frame")
meterHover:Hide()
meterHover.elapsed = 0
meterHover:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed < 0.1 then return end
    self.elapsed = 0
    local frame = SelectedDocked()
    if not frame or (frame.FlareUI_TargetAlpha or 1) >= 1 then return end
    local dm, db = ns.DamageMeter, GetDb()
    if not (db and dm and dm.ChatTabMouseOver and dm:ChatTabMouseOver()) then return end
    Chat:ShowChatFrame(frame, db)
end)

-- Called by the Damage Meter module whenever the tab's state may have changed: a click, Visibility,
-- the options, Blizzard's switch. Its Refresh asks often, so an unchanged state is left alone.
function Chat:RefreshMeterTab()
    local db = GetDb()
    if not (db and db.enabled) then return end
    local dm = ns.DamageMeter
    local active = Chat:MeterTabActive()
    local fades = Chat.Fades(db)
    local ignore = dm ~= nil and dm.ChatTabIgnoresFade ~= nil and dm:ChatTabIgnoresFade()
    local state = (MeterTabAvailable() and 1 or 0) + (active and 2 or 0) + (fades and 4 or 0) + (ignore and 8 or 0)
    if state == self.meterTabState then return end
    self.meterTabState = state
    SetDockedTextShown(not active)
    if not active then wipe(meterUnread) end
    for _, cf in Windows() do
        if cf and cf.FlareUI_TabBar then Chat:UpdateCustomTabs(cf, db) end
    end
    meterHover:SetShown(active and fades and not ignore)
    -- Ignore Chat Fade: a faded window comes up with the tab (CheckChatVisibility holds it)
    if active and fades and ignore then Chat:ShowChatFrame(SelectedDocked(), db) end
end

-- The Meter tab clicked (true) or a chat tab (false)
function Chat:SelectMeterTab(active)
    local dm = ns.DamageMeter
    if not (dm and dm.SetChatTab) then return end
    dm:SetChatTab(active)   -- comes back through RefreshMeterTab
    Chat:ShowChatFrame(SelectedDocked(), GetDb())
end

-- A line into the window the meter hides: its tab lights up until the chat is back
local function MarkUnread(chatFrame)
    for _, cf in Windows() do
        local bar = cf and cf.FlareUI_TabBar
        for _, btn in ipairs(bar and bar.buttons or {}) do
            if btn.chatFrame == chatFrame and btn:IsShown() then
                btn.isUnread = true
                btn.Text:SetAlpha(1)
            end
        end
    end
end

--------------------------------------------------
-- 12. TAB BAR
-- FlareUI's own tabs on the skin, one per docked window (a popped window has only its own).
--------------------------------------------------
-- Every docked window has its own tab bar (on its own skin), but they show one strip: one scroll
-- value for all of them, so a tab switch never lands on a bar scrolled somewhere else
Chat.tabScroll = 0
Chat.tabStylePass = 1   -- bumped by Apply: the tab buttons take the font again

local function DockedTabBars()
    local bars = {}
    local dock = _G.GeneralDockManager
    for _, frame in ipairs(dock and dock.DOCKED_CHAT_FRAMES or {}) do
        if frame.FlareUI_TabBar then bars[#bars + 1] = frame.FlareUI_TabBar end
    end
    return bars
end

function Chat:SetTabScroll(value)
    Chat.tabScroll = math_max(0, value or 0)
    for _, bar in ipairs(DockedTabBars()) do
        local max = bar:GetHorizontalScrollRange() or 0
        bar:SetHorizontalScroll(math_min(Chat.tabScroll, math_max(0, max)))
    end
end

-- The selected window's tab into view, on the bar now shown
function Chat:ScrollTabIntoView(chatFrame)
    local dock = _G.GeneralDockManager
    local shown = dock and FCFDock_GetSelectedWindow(dock)
    local bar = shown and shown.FlareUI_TabBar
    if not bar then return end
    for _, btn in ipairs(bar.buttons or {}) do
        if btn.chatFrame == chatFrame and btn:IsShown() then
            local left, right, barLeft = btn:GetLeft(), btn:GetRight(), bar:GetLeft()
            if not (left and right and barLeft) then return end
            local scroll = bar:GetHorizontalScroll()
            local width = bar:GetWidth()
            local tabLeft, tabRight = left - barLeft + scroll, right - barLeft + scroll
            if tabRight > scroll + width then
                Chat:SetTabScroll(tabRight - width + 10)
            elseif tabLeft < scroll then
                Chat:SetTabScroll(tabLeft - 10)
            end
            return
        end
    end
end

function Chat:CreateCustomTabBar(chatFrame)
    if not chatFrame.FlareUI_Skin then return end
    if chatFrame.FlareUI_TabBar then return end

    local scrollFrame = CreateFrame("ScrollFrame", nil, chatFrame.FlareUI_Skin)
    scrollFrame:SetHeight(24)
    scrollFrame:SetPoint("TOPLEFT", chatFrame.FlareUI_Skin, "TOPLEFT", 10, 0)
    scrollFrame:SetPoint("TOPRIGHT", chatFrame.FlareUI_Skin, "TOPRIGHT", -20, 0)
    scrollFrame:SetFrameStrata("DIALOG")
    scrollFrame:SetFrameLevel(200)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetHeight(24)
    scrollChild:SetWidth(1)
    scrollFrame:SetScrollChild(scrollChild)

    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetHorizontalScroll()
        local max = self:GetHorizontalScrollRange()
        local step = 30
        local new = cur - (delta * step)
        if new < 0 then new = 0 end
        if new > max then new = max end
        -- a popped window's bar is its own; the docked bars move together
        if IsPopped(chatFrame) then self:SetHorizontalScroll(new) else Chat:SetTabScroll(new) end
    end)

    scrollFrame.buttons = {}
    scrollFrame.FlareUI_Child = scrollChild
    chatFrame.FlareUI_TabBar = scrollFrame
    chatFrame.FlareUI_TabChild = scrollChild
end

-- Reordering tabs by drag: a drop moves the window in Blizzard's dock list and FCF_SaveDock keeps
-- the order. General stays first and the shown Combat Log second, as in Blizzard's chat.
local TAB_MARKER_WIDTH, TAB_MARKER_HEIGHT = 2, 16

-- How many windows lead the dock list and stay put
local function FixedWindowCount()
    local db = GetDb()
    local list = GeneralDockManager and GeneralDockManager.DOCKED_CHAT_FRAMES
    local combatLog = _G.ChatFrame2
    if combatLog and list and tIndexOf(list, combatLog) and not (db and db.hideCombatLog) then return 2 end
    return 1
end

local function IsFixedWindow(frame)
    if frame == GeneralDockManager.primary then return true end
    return frame == _G.ChatFrame2 and FixedWindowCount() == 2
end

-- Puts a Combat Log dragged out of second place back
local function KeepCombatLogSecond()
    local dock = GeneralDockManager
    local list = dock and dock.DOCKED_CHAT_FRAMES
    local combatLog = _G.ChatFrame2
    if not (list and FixedWindowCount() == 2) then return end
    local index = tIndexOf(list, combatLog)
    if index == 2 or list[1] ~= dock.primary then return end
    table.remove(list, index)
    table.insert(list, 2, combatLog)
    dock.isDirty = true
    FCF_SaveDock()
    FCFDock_UpdateTabs(dock)
end

-- The Combat Log's filter buttons: a second header inside the window, under the tab row's separator,
-- with the text below it. Blizzard keeps them on the tab, which FlareUI hides, so they move to the
-- window. COMBAT_BAR_SPACE lowers the docked log and raises its skin by the same amount, so the skin
-- matches the other tabs' exactly.
local StyleCombatLogBar
function StyleCombatLogBar()
    local combatLog, bar = _G.ChatFrame2, _G.CombatLogQuickButtonFrame_Custom
    if not (combatLog and bar) then
        -- Blizzard_CombatLog loads on demand
        if not Chat.combatBarWait then
            Chat.combatBarWait = CreateFrame("Frame")
            Chat.combatBarWait:RegisterEvent("ADDON_LOADED")
            Chat.combatBarWait:SetScript("OnEvent", function(self)
                if not _G.CombatLogQuickButtonFrame_Custom then return end
                self:UnregisterAllEvents()
                StyleCombatLogBar()
            end)
        end
        return
    end
    if bar:GetParent() ~= combatLog then
        local shown = combatLog:IsShown()
        bar:SetParent(combatLog)
        bar:SetShown(shown)   -- shown and hidden with the window from here on (Blizzard's own hooks)
    end
    bar:SetHeight(COMBAT_BAR_HEIGHT)
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOMLEFT", combatLog, "TOPLEFT", -COMBAT_BAR_INSET, COMBAT_BAR_TEXT_GAP)
    bar:SetPoint("BOTTOMRIGHT", combatLog, "TOPRIGHT", COMBAT_BAR_INSET, COMBAT_BAR_TEXT_GAP)
    bar:SetFrameLevel((combatLog:GetFrameLevel() or 1) + 5)
    if ns.IsGamepadUI() then bar.smartNavigationIgnored = true end
    -- Blizzard's arrow for filters that don't fit: taller than the bar, so centred on it
    local more = _G.CombatLogQuickButtonFrame_CustomAdditionalFilterButton
    if more then
        more:ClearAllPoints()
        more:SetPoint("RIGHT", bar, "RIGHT", -2, 0)
    end

    -- the edit box's look, shorter: same border and black fill, in place of Blizzard's dark strip
    local db = GetDb()
    if not db then return end
    local strip = _G.CombatLogQuickButtonFrame_CustomTexture
    if strip then strip:SetAlpha(0) end
    local bg = bar.FlareUI_Backdrop
    if not bg then
        bg = CreateFrame("Frame", nil, bar, "BackdropTemplate")
        bar.FlareUI_Backdrop = bg
        bg:SetAllPoints()
    end
    bg:SetFrameLevel(bar:GetFrameLevel())   -- under the buttons
    local edgeFile = GetBorderFile(db)
    -- a thick border's corners would overlap at this height
    local edgeSize = math_min(ns.BorderEdgeSize(edgeFile, BORDER_SIZE), COMBAT_BAR_HEIGHT / 2)
    local inset = BORDER_INSET
    bg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = edgeFile, tile = true, tileSize = 16, edgeSize = edgeSize, insets = { left = inset, right = inset, top = inset, bottom = inset } })
    bg:SetBackdropColor(0, 0, 0, db.editBoxOpacity or 1)
    bg:SetBackdropBorderColor(ns.BORDER_COLOR.r, ns.BORDER_COLOR.g, ns.BORDER_COLOR.b, 1)
end

-- Blizzard re-lays a docked log on every dock update, by the bar's height: back to FlareUI's space
local function KeepCombatLogBelowBar()
    local combatLog = _G.ChatFrame2
    if not combatLog or combatLog:IsForbidden() then return end
    local target = -COMBAT_BAR_SPACE
    if not combatLog.FlareUI_HeightHooked then
        combatLog.FlareUI_HeightHooked = true
        local restoring
        hooksecurefunc(combatLog, "SetPoint", function(self, point, relativeTo, relativePoint, x, y)
            if restoring or point ~= "TOPLEFT" or not self.isDocked or type(y) ~= "number" or y == target then return end
            restoring = true
            self:SetPoint(point, relativeTo, relativePoint, x, target)
            restoring = false
        end)
    end
    if not combatLog.isDocked then return end
    for i = 1, combatLog:GetNumPoints() do
        local point, relativeTo, relativePoint, x, y = combatLog:GetPoint(i)
        if point == "TOPLEFT" then
            if y ~= target then combatLog:SetPoint(point, relativeTo, relativePoint, x, target) end
            return
        end
    end
end

-- an unselected tab's text at rest; hovering lifts it to 1
local TAB_IDLE_ALPHA = 0.6
local SECRET_TAB_WIDTH = 90   -- Blizzard's own docked width for these tabs

-- A tab's text, selected or at rest (also the settings previews' sample tabs)
function Chat.PaintTab(text, selected)
    local c = selected and TAB_ACTIVE_COLOR or TAB_INACTIVE_COLOR
    text:SetTextColor(c.r, c.g, c.b, c.a)
    text:SetAlpha(selected and 1 or TAB_IDLE_ALPHA)
end

local function CursorX(region)
    return GetCursorPosition() / region:GetEffectiveScale()
end

-- The visible tab the dragged one would land in front of (nil = after the last), for this cursor x
local function TabDropTarget(scrollFrame, x)
    for _, btn in ipairs(scrollFrame.buttons) do
        if btn:IsShown() then
            local left, right = btn:GetLeft(), btn:GetRight()
            if left and right and x < (left + right) / 2 then return btn end
        end
    end
end

local function LastShownTab(scrollFrame)
    local last
    for _, btn in ipairs(scrollFrame.buttons) do
        if btn:IsShown() then last = btn end
    end
    return last
end

local function UpdateTabMarker(scrollFrame)
    local marker, dragged = scrollFrame.dropMarker, scrollFrame.draggedTab
    if not (marker and dragged) then return end
    local target = TabDropTarget(scrollFrame, CursorX(scrollFrame))
    if target and IsFixedWindow(target.chatFrame) then
        target = nil
        for _, btn in ipairs(scrollFrame.buttons) do
            if btn:IsShown() and not IsFixedWindow(btn.chatFrame) then target = btn break end
        end
    end
    marker:ClearAllPoints()
    if target then
        marker:SetPoint("RIGHT", target, "LEFT", -1, 0)
    else
        marker:SetPoint("LEFT", LastShownTab(scrollFrame), "RIGHT", 1, 0)
    end
    marker:Show()
end

-- Moves a docked window in front of `before` (or to the end) and saves the new order
local function MoveDockedWindow(frame, before)
    local dock = GeneralDockManager
    local list = dock and dock.DOCKED_CHAT_FRAMES
    if not list or IsFixedWindow(frame) then return end
    local from = tIndexOf(list, frame)
    if not from then return end
    local first = FixedWindowCount() + 1       -- never in front of a fixed window
    table.remove(list, from)
    local to = before and tIndexOf(list, before) or (#list + 1)
    if to < first then to = first end
    table.insert(list, to, frame)
    if to == from then return end
    dock.isDirty = true
    FCF_SaveDock()
    FCFDock_UpdateTabs(dock)
end

-- Builder and drag-and-drop share the same ordering and persistence rules.
function Chat:MoveWindowBefore(frame, before)
    if InCombatLockdown() then return end
    MoveDockedWindow(frame, before)
end

local function OnTabDragStart(self)
    local scrollFrame = self.scrollFrame
    -- a popped window's tab is its handle
    if IsPopped(self.chatFrame) then
        Chat:StartMovingWindow(self.chatFrame)
        return
    end
    if not scrollFrame or IsFixedWindow(self.chatFrame) then return end
    if not scrollFrame.dropMarker then
        local marker = scrollFrame.FlareUI_Child:CreateTexture(nil, "OVERLAY")
        marker:SetSize(TAB_MARKER_WIDTH, TAB_MARKER_HEIGHT)
        local c = ns.BORDER_COLOR
        marker:SetColorTexture(c.r, c.g, c.b, 1)
        scrollFrame.dropMarker = marker
    end
    scrollFrame.draggedTab = self
    self:SetAlpha(0.5)
    scrollFrame:SetScript("OnUpdate", UpdateTabMarker)
end

local function OnTabDragStop(self)
    if self.chatFrame and self.chatFrame.FlareUI_Moving then
        Chat:StopMovingWindow(self.chatFrame)
        -- the release that ends a drag also clicks the tab
        self.justDragged = true
        C_Timer.After(0, function() self.justDragged = nil end)
        return
    end
    local scrollFrame = self.scrollFrame
    if not (scrollFrame and scrollFrame.draggedTab == self) then return end
    scrollFrame:SetScript("OnUpdate", nil)
    scrollFrame.dropMarker:Hide()
    scrollFrame.draggedTab = nil
    self:SetAlpha(1)
    -- the release that ends a drag also clicks the tab; that click is not a selection
    self.justDragged = true
    C_Timer.After(0, function() self.justDragged = nil end)
    local target = TabDropTarget(scrollFrame, CursorX(scrollFrame))
    if target == self then return end
    MoveDockedWindow(self.chatFrame, target and target.chatFrame)
end

function Chat:UpdateCustomTabs(chatFrame, db)
    local scrollFrame = chatFrame.FlareUI_TabBar
    local scrollChild = chatFrame.FlareUI_TabChild
    if not scrollFrame or not scrollChild then return end

    -- room for the header buttons, which stay on the dock
    local popped = IsPopped(chatFrame)
    local btnCount = 0
    if not popped then
        for _, key in ipairs(HEADER_ORDER) do
            if HeaderButtonShown(db, key) then btnCount = btnCount + 1 end
        end
    end
    local margin = -20 - (btnCount * 30)
    scrollFrame:SetPoint("TOPRIGHT", chatFrame.FlareUI_Skin, "TOPRIGHT", margin, 0)

    for _, btn in ipairs(scrollFrame.buttons) do btn:Hide() end
    if scrollFrame.meterButton then scrollFrame.meterButton:Hide() end

    local dock = _G.GeneralDockManager
    local dockedFrames = dock and dock.DOCKED_CHAT_FRAMES
    if not dockedFrames then return end
    if popped then dockedFrames = { chatFrame } end
    local meterActive = not popped and Chat:MeterTabActive()

    local prevBtn = nil
    local fontPath, fontSize, fontFlags = GetFontData(db.tabFont)
    local totalWidth = 0

    local buttonIndex = 0
    for _, frame in ipairs(dockedFrames) do
        if not (frame == _G.ChatFrame2 and db.hideCombatLog) then
            buttonIndex = buttonIndex + 1
            local tabID = frame:GetID()
            local realTab = _G["ChatFrame"..tabID.."Tab"]

            local btn = scrollFrame.buttons[buttonIndex]
            if not btn then
                btn = CreateFrame("Button", nil, scrollChild)
                btn:SetHeight(24)

                btn.Text = btn:CreateFontString(nil, "OVERLAY")
                btn.Text:SetPoint("CENTER", 0, 0)

                btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                btn:RegisterForDrag("LeftButton")
                btn.scrollFrame = scrollFrame
                btn:SetScript("OnDragStart", OnTabDragStart)
                btn:SetScript("OnDragStop", OnTabDragStop)
                btn:SetScript("OnClick", function(self, button)
                    if not self.realTab or self.justDragged then return end
                    if button == "RightButton" then
                        Chat:OpenContextMenu(self, self.chatFrame)
                    -- a popped window has only its own tab. In Edit Mode the main window stays shown:
                    -- its selection box and size options hide with it, and docked windows share its size
                    elseif not IsPopped(self.chatFrame) and not (_G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown()) then
                        _G.FCF_Tab_OnClick(self.realTab, button)
                        if Chat:MeterTabActive() then Chat:SelectMeterTab(false) end
                        local picked = self.chatFrame
                        C_Timer.After(0.01, function()
                            local chatDb = GetDb()
                            if chatDb then Chat:UpdateCustomTabs(_G.ChatFrame1, chatDb) end
                            -- the picked tab into view if it is cut off, on the bar now shown
                            C_Timer.After(0.02, function() Chat:ScrollTabIntoView(picked) end)
                        end)
                    end
                end)

                btn:SetScript("OnEnter", function(self)
                    self.Text:SetAlpha(1)
                    GameTooltip:Hide()
                    Chat:ShowChatFrame(chatFrame, GetDb())
                end)

                btn:SetScript("OnLeave", function(self) if not (self.isSelected or self.isFlashing or self.isUnread) then self.Text:SetAlpha(TAB_IDLE_ALPHA) end end)
                scrollFrame.buttons[buttonIndex] = btn
            end

            btn.realTab = realTab
            btn.chatFrame = frame

            -- the font only when the settings changed (a pass of Apply), the text and its width only
            -- when the name changed: the bars are redrawn on every dock change and whisper flash
            local fontChanged = btn.ftPass ~= Chat.tabStylePass
            if fontChanged then
                btn.ftPass = Chat.tabStylePass
                ns.SetFont(btn.Text, fontPath, fontSize, fontFlags)
                ns.ApplyShadow(btn.Text, db.tabFont)
            end

            -- A whisper tab's name can be secret: it is shown but never tested, at a fixed width
            local tabText = realTab:GetText()
            local readable = canaccessvalue(tabText)
            if readable and not tabText then tabText = "Chat " .. tabID end
            local w
            if readable and not fontChanged and btn.ftText == tabText and btn.ftWidth then
                w = btn.ftWidth
            else
                btn.Text:SetText(tabText)
                local textWidth = btn.Text:GetStringWidth()
                w = (readable and canaccessvalue(textWidth)) and (textWidth + 14) or SECRET_TAB_WIDTH
                btn.ftText = readable and tabText or nil
                btn.ftWidth = w
            end
            btn:SetWidth(w)
            btn.Text:ClearAllPoints()
            btn.Text:SetPoint("CENTER", btn, "CENTER", 0, TAB_TEXT_Y)

            -- on the Meter tab the window Blizzard has selected is shown as any other
            local isSelected = popped or (not meterActive and FCFDock_GetSelectedWindow(dock) == frame)
            btn.isSelected = isSelected
            btn.isUnread = meterUnread[frame] or nil

            Chat.PaintTab(btn.Text, isSelected)
            if not isSelected then
                btn.isFlashing = realTab.glow and realTab.glow:IsShown() or nil
                if btn.isFlashing then
                    -- the player's whisper colour, as set in Blizzard's chat settings. Only a whisper
                    -- window knows its type, so Battle.net whispers on a regular tab stay pink.
                    local whisper = ChatTypeInfo[frame.chatType == "BN_WHISPER" and "BN_WHISPER" or "WHISPER"]
                    btn.Text:SetTextColor(whisper.r or 1, whisper.g or 0.5, whisper.b or 1, 1)
                    btn.Text:SetAlpha(1)
                elseif btn.isUnread then
                    btn.Text:SetAlpha(1)
                end
            end

            btn:ClearAllPoints()
            if prevBtn then
                btn:SetPoint("LEFT", prevBtn, "RIGHT", 4, 0)
            else
                btn:SetPoint("LEFT", scrollChild, "LEFT", 0, 0)
            end

            btn:Show()
            prevBtn = btn
            totalWidth = totalWidth + w + 4
        end
    end

    -- the Meter tab (METER TAB), after the windows' tabs; a popped window has only its own
    local meterBtn = scrollFrame.meterButton
    if not popped and MeterTabAvailable() then
        if not meterBtn then
            meterBtn = CreateFrame("Button", nil, scrollChild)
            meterBtn:SetHeight(24)
            meterBtn.Text = meterBtn:CreateFontString(nil, "OVERLAY")
            meterBtn:RegisterForClicks("LeftButtonUp")
            meterBtn:SetScript("OnClick", function() Chat:SelectMeterTab(true) end)
            meterBtn:SetScript("OnEnter", function(self)
                self.Text:SetAlpha(1)
                GameTooltip:Hide()
                Chat:ShowChatFrame(chatFrame, GetDb())
            end)
            meterBtn:SetScript("OnLeave", function(self) if not self.isSelected then self.Text:SetAlpha(TAB_IDLE_ALPHA) end end)
            scrollFrame.meterButton = meterBtn
        end
        ns.SetFont(meterBtn.Text, fontPath, fontSize, fontFlags)
        ns.ApplyShadow(meterBtn.Text, db.tabFont)
        meterBtn.Text:SetText(L["Meter"])
        local w = meterBtn.Text:GetStringWidth() + 14
        meterBtn:SetWidth(w)
        meterBtn.Text:ClearAllPoints()
        meterBtn.Text:SetPoint("CENTER", meterBtn, "CENTER", 0, TAB_TEXT_Y)
        meterBtn.isSelected = meterActive
        Chat.PaintTab(meterBtn.Text, meterActive)
        meterBtn:ClearAllPoints()
        if prevBtn then
            meterBtn:SetPoint("LEFT", prevBtn, "RIGHT", 4, 0)
        else
            meterBtn:SetPoint("LEFT", scrollChild, "LEFT", 0, 0)
        end
        meterBtn:Show()
        totalWidth = totalWidth + w + 4
    end

    scrollChild:SetWidth(math_max(1, totalWidth))
    -- the docked bars share one scroll (see Chat:SetTabScroll)
    if not popped then
        local max = math_max(0, totalWidth - (scrollFrame:GetWidth() or 0))
        scrollFrame:SetHorizontalScroll(math_min(Chat.tabScroll or 0, max))
    end
end

function Chat:HideBlizzardTabs()

    -- In the Gamepad UI the dock's tabs stay shown but invisible: Tab Settings (Y) opens on them
    local dock = _G.GeneralDockManager
    if dock and dock.scrollFrame then
        if not ns.IsGamepadUI() then dock.scrollFrame:Hide() end
        dock.scrollFrame:SetAlpha(0)
    end

    if dock and dock.overflowButton then
        dock.overflowButton:Hide()
        dock.overflowButton:SetAlpha(0)
    end

    local gamepad = ns.IsGamepadUI()
    for _, chatFrame in Windows() do
        local tab = chatFrame and _G[chatFrame:GetName() .. "Tab"]
        if tab then
            tab:SetAlpha(0)
            tab:EnableMouse(false)
            if not tab.FlareUI_ModernKilled and not gamepad then
                tab:SetScript("OnShow", function(self)
                    self:Hide()
                end)
                tab:Hide()
                tab.FlareUI_ModernKilled = true
            end
        end
    end
end

-- Blizzard's hidden tabs get the same font, so their sizes match FlareUI's
function Chat:UpdateTabFonts(db)
    local font = db.tabFont
    local fontPath, fontSize, fontFlags = GetFontData(font)
    local c = TAB_ACTIVE_COLOR

    for i = 1, NUM_CHAT_WINDOWS do
        local tab = _G["ChatFrame"..i.."Tab"]
        if tab then
            local fs = tab:GetFontString()
            if fs then
                ns.SetFont(fs, fontPath, fontSize, fontFlags)
                ns.ApplyShadow(fs, font)
                fs:SetTextColor(c.r, c.g, c.b, c.a)
            end
            PanelTemplates_TabResize(tab, 10)
        end
    end
    FCF_DockUpdate()
end

--------------------------------------------------
-- 13. EDIT BOX
-- * Sent history: the last lines sent (all channels, per character). Up / Down, with or without
--   Shift or Alt, step through them; Down past the newest restores the draft. Blizzard's own list
--   is emptied after each line so Alt+Up does not fight this one.
-- * Inside: while the box is open over the chat's last lines, the lines move up above it. The chat
--   lays its lines out from the bottom up, so only the first is moved.
--------------------------------------------------
local EDIT_BOX_GAP = 1   -- px between the chat window's border and an edit box below / above it
local EditExtras = { SENT_MAX = 50, PUSH_GAP = 2 }

function EditExtras.Sent()
    local char = ns.CharDB()
    char.sentHistory = char.sentHistory or {}
    return char.sentHistory
end

-- The line as the game would keep it: "/w Name text", "/2 text", "/g text". A recalled line then goes
-- where it went the first time, not to the chat the box is on now.
function EditExtras.WithHeader(eb, text)
    local ok, chatType = pcall(eb.GetChatType, eb)
    if not (ok and canaccessvalue(chatType) and type(chatType) == "string") then return text end
    local header = _G["SLASH_" .. chatType .. "1"]
    header = type(header) == "string" and header or nil
    local target
    if chatType == "WHISPER" then
        local got, tell = pcall(eb.GetTellTarget, eb)
        target = got and canaccessvalue(tell) and type(tell) == "string" and tell ~= "" and tell or nil
        if not (header and target) then return text end
        return header .. " " .. target .. " " .. text
    elseif chatType == "CHANNEL" then
        local got, channel = pcall(eb.GetChannelTarget, eb)
        channel = got and canaccessvalue(channel) and channel or nil
        if not channel or channel == "" then return text end
        return "/" .. tostring(channel) .. " " .. text
    end
    return header and (header .. " " .. text) or text
end

-- The line about to be sent, read on the Enter key itself or as Blizzard announces the send, never
-- from inside Blizzard's send steps. Secure commands (/cast, /use, /target...) are not kept: put back
-- in the box by addon code they would not run.
function EditExtras.OnLineSent(eb)
    local now = GetTime()
    if eb.FlareUI_SentAt == now then return end
    eb.FlareUI_SentAt = now
    local text = eb:GetText()
    if canaccessvalue(text) and type(text) == "string" and text ~= "" then
        local command = text:match("^(/%S+)")
        local ok, secure = false, false
        if command and IsSecureCmd then ok, secure = pcall(IsSecureCmd, command) end
        if not (ok and secure) then
            if not command then text = EditExtras.WithHeader(eb, text) end
            local list = EditExtras.Sent()
            if list[#list] ~= text then
                list[#list + 1] = text
                while #list > EditExtras.SENT_MAX do table.remove(list, 1) end
            end
        end
    end
    eb.FlareUI_HistoryPos, eb.FlareUI_Draft = 0, nil
    -- Blizzard's own list stays empty (the arrows recall FlareUI's), emptied once the send is done
    C_Timer.After(0, function() pcall(eb.ClearHistory, eb) end)
end

-- In chat lockdown (boss fights, rated PvP) the game refuses text an addon put in the box
local function ChatLocked()
    if not (C_ChatInfo and C_ChatInfo.InChatMessagingLockdown) then return false end
    local ok, locked = pcall(C_ChatInfo.InChatMessagingLockdown)
    return ok and canaccessvalue(locked) and locked and true or false
end

function EditExtras.OnKeyDown(eb, key)
    -- the name list under a half-typed whisper uses the arrows and Enter itself
    local picking = AutoCompleteBox and AutoCompleteBox:IsShown() and AutoCompleteBox.parent == eb
    if key == "ENTER" or key == "NUMPADENTER" then
        if not picking then EditExtras.OnLineSent(eb) end
        return
    end
    if (key ~= "UP" and key ~= "DOWN") or IsControlKeyDown() or picking or ChatLocked() then return end
    local list = EditExtras.Sent()
    if #list == 0 then return end
    local pos = eb.FlareUI_HistoryPos or 0
    if key == "UP" then
        if pos == 0 then eb.FlareUI_Draft = eb:GetText() end
        pos = math_min(pos + 1, #list)
    elseif pos == 0 then
        return
    else
        pos = pos - 1
    end
    eb.FlareUI_HistoryPos = pos
    local text = (pos == 0) and (eb.FlareUI_Draft or "") or list[#list - pos + 1]
    eb:SetText(text)
    eb:SetCursorPosition(#eb:GetText())
end

-- the chat's newest line sits this far up (0: in place)
function EditExtras.PlaceLines(chatFrame)
    local first = chatFrame.visibleLines and chatFrame.visibleLines[1]
    if not first then return end
    if chatFrame.GetInsertMode and SCROLLING_MESSAGE_FRAME_INSERT_MODE_TOP
        and chatFrame:GetInsertMode() == SCROLLING_MESSAGE_FRAME_INSERT_MODE_TOP then return end
    first:SetPoint("BOTTOMLEFT", chatFrame, "BOTTOMLEFT", 0, chatFrame.FlareUI_LinesUp or 0)
end

function EditExtras.Push(chatFrame, up)
    if not chatFrame or chatFrame:IsForbidden() then return end
    if not chatFrame.FlareUI_LinesHooked and chatFrame.RefreshLayout then
        chatFrame.FlareUI_LinesHooked = true
        hooksecurefunc(chatFrame, "RefreshLayout", EditExtras.PlaceLines)
    end
    chatFrame.FlareUI_LinesUp = up
    EditExtras.PlaceLines(chatFrame)
end

-- The window the open box sits over: a docked box covers whichever docked window is shown, which
-- is not its own once a tab is picked with the box open (a whisper you start selects its new tab)
function EditExtras.Target(eb)
    local frame = eb.chatFrame
    local dock = _G.GeneralDockManager
    if frame and frame.isDocked and dock then
        local shown = FCFDock_GetSelectedWindow(dock)
        if shown and not shown:IsForbidden() then return shown end
    end
    return frame
end

-- Edit Box Position "inside": the shown window's lines move up over the open box
function EditExtras.PushFor(eb)
    local db = GetDb()
    if not (db and (db.editBoxPosition or "inside") == "inside") then return end
    local frame = EditExtras.Target(eb)
    if not frame or frame == eb.FlareUI_PushedFrame then return end
    if eb.FlareUI_PushedFrame then EditExtras.Push(eb.FlareUI_PushedFrame, 0) end
    local top = select(5, eb:GetPoint(1))
    eb.FlareUI_PushedFrame = frame
    EditExtras.Push(frame, (top or 30) + EditExtras.PUSH_GAP)
end

-- A tab picked while the box is open: the push moves to the window now shown
function EditExtras.FollowDock()
    local eb = _G.ACTIVE_CHAT_EDIT_BOX
    if eb and eb.FlareUI_EditExtras and eb:HasFocus() then EditExtras.PushFor(eb) end
end

function EditExtras.Setup(eb)
    if eb.FlareUI_EditExtras then return end
    eb.FlareUI_EditExtras = true
    eb:HookScript("OnKeyDown", EditExtras.OnKeyDown)
    -- focus and sends through Blizzard's own announcements (run apart from its chat steps), not
    -- hooks on the box: once, for every box set up here
    if EditExtras.callbacks then return end
    EditExtras.callbacks = true
    EventRegistry:RegisterCallback("ChatFrame.OnEditBoxFocusGained", function(_, box)
        if not (box and box.FlareUI_EditExtras) then return end
        EditExtras.PushFor(box)
        -- auto-hide: an open box keeps its window shown
        if box.chatFrame and box.chatFrame.FlareUI_AutoHideHooked then Chat:ShowChatFrame(box.chatFrame, GetDb()) end
    end, EditExtras)
    EventRegistry:RegisterCallback("ChatFrame.OnEditBoxFocusLost", function(_, box)
        if not (box and box.FlareUI_EditExtras) then return end
        box.FlareUI_HistoryPos, box.FlareUI_Draft = 0, nil
        if box.FlareUI_PushedFrame then
            EditExtras.Push(box.FlareUI_PushedFrame, 0)
            box.FlareUI_PushedFrame = nil
        end
    end, EditExtras)
    EventRegistry:RegisterCallback("ChatFrame.OnEditBoxPreSendText", function(_, box)
        if box and box.FlareUI_EditExtras then EditExtras.OnLineSent(box) end
    end, EditExtras)
end

-- The edit box's look on its backdrop frame: black fill inside the chat's border (also the settings
-- preview's sample box)
function Chat.EditBoxBackdrop(bg, db)
    local edgeFile = GetBorderFile(db)
    local inset = BORDER_INSET
    bg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = edgeFile, tile = true, tileSize = 16, edgeSize = ns.BorderEdgeSize(edgeFile, BORDER_SIZE), insets = { left = inset, right = inset, top = inset, bottom = inset } })
    bg:SetBackdropColor(0, 0, 0, db.editBoxOpacity or 1)
    bg:SetBackdropBorderColor(ns.BORDER_COLOR.r, ns.BORDER_COLOR.g, ns.BORDER_COLOR.b, 1)
end

function Chat:StyleEditBox(chatFrame, db)
    if not chatFrame or chatFrame:IsForbidden() then return end
    local eb = chatFrame.editBox or _G[chatFrame:GetName() .. "EditBox"]
    if not eb then return end
    local name = eb:GetName()
    if name then
        local texNames = { "Left", "Right", "Mid", "FocusLeft", "FocusRight", "FocusMid" }
        for _, tName in ipairs(texNames) do
            local tex = _G[name .. tName]
            if tex then tex:Hide(); if tex.SetAlpha then tex:SetAlpha(0) end; if tex.SetTexture then tex:SetTexture(nil) end end
        end
    end
    if eb.headerSuffix then eb.headerSuffix:Hide(); if eb.headerSuffix.SetAlpha then eb.headerSuffix:SetAlpha(0) end; if eb.headerSuffix.SetTexture then eb.headerSuffix:SetTexture(nil) end end

    -- In IM style the idle edit box is invisible and below the chat window, so a click on a link
    -- under it reaches the link; ActivateChat restores both. Never touch its mouse or hook
    -- ActivateChat: both stopped Enter from opening the chat. The Gamepad UI keeps its strata.
    if not eb.FlareUI_IMHooked then
        eb.FlareUI_IMHooked = true
        local gamepad = ns.IsGamepadUI()
        hooksecurefunc(eb, "Deactivate", function(self)
            if C_CVar.GetCVar("chatStyle") == "im" and not self.isGM then
                self:SetAlpha(0)
                if not gamepad then self:SetFrameStrata("BACKGROUND") end
            end
        end)
        if C_CVar.GetCVar("chatStyle") == "im" and eb ~= ACTIVE_CHAT_EDIT_BOX then
            eb:SetAlpha(0)
            if not gamepad then eb:SetFrameStrata("BACKGROUND") end
        end
    end

    -- Edit Box Position. Outside the window it is as wide as the border, EDIT_BOX_GAP away (its
    -- backdrop reaches 2 px past the box).
    eb:ClearAllPoints()
    local position = db.editBoxPosition or "inside"
    local skin = chatFrame.FlareUI_Skin
    if position == "below" and skin then
        eb:SetPoint("TOPLEFT", skin, "BOTTOMLEFT", 2, -(EDIT_BOX_GAP + 2))
        eb:SetPoint("TOPRIGHT", skin, "BOTTOMRIGHT", -2, -(EDIT_BOX_GAP + 2))
    elseif position == "above" and skin then
        eb:SetPoint("BOTTOMLEFT", skin, "TOPLEFT", 2, EDIT_BOX_GAP + 2)
        eb:SetPoint("BOTTOMRIGHT", skin, "TOPRIGHT", -2, EDIT_BOX_GAP + 2)
    else
        -- over the window's last lines
        eb:SetPoint("TOPLEFT", chatFrame, "BOTTOMLEFT", -2, 30)
        eb:SetPoint("TOPRIGHT", chatFrame, "BOTTOMRIGHT", 2, 30)
    end

    local bg = eb.FlareUI_Backdrop
    if not bg then
        bg = CreateFrame("Frame", nil, eb, "BackdropTemplate")
        eb.FlareUI_Backdrop = bg
        -- DIALOG, where the opened box draws
        bg:SetFrameStrata("DIALOG")
        bg:SetFrameLevel(math_max((eb:GetFrameLevel() or 1) - 1, 0))
        bg:SetPoint("TOPLEFT", eb, "TOPLEFT", -2, 2)
        bg:SetPoint("BOTTOMRIGHT", eb, "BOTTOMRIGHT", 2, -2)
    end

    Chat.EditBoxBackdrop(bg, db)

    eb:SetHistoryLines(100)
    eb:SetAltArrowKeyMode(false)
    EditExtras.Setup(eb)

    local path, size, flags = GetFontData(db.editBoxFont)
    ns.SetFont(eb, path, size, flags)
    ns.ApplyShadow(eb, db.editBoxFont)
    if eb.header then ns.SetFont(eb.header, path, size, flags); ns.ApplyShadow(eb.header, db.editBoxFont) end
end

--------------------------------------------------
-- 14. WINDOW SKIN
--------------------------------------------------

-- The speaker for the master volume now
function Chat.VolumeIcon()
    local vol = tonumber(C_CVar.GetCVar("Sound_MasterVolume")) or 0
    if vol <= 0 then return ICON_MUTE elseif vol <= 0.3 then return ICON_LOW elseif vol <= 0.7 then return ICON_MEDIUM end
    return ICON_HIGH
end

function Chat:SetupVolumeButton(chatFrame, db)
    if not chatFrame.FlareUI_Skin then return end
    if not HeaderButtonShown(db, "volume") or IsPopped(chatFrame) then
        if chatFrame.FlareUI_VolumeBtn then chatFrame.FlareUI_VolumeBtn:Hide() end
        return
    end

    local btn = chatFrame.FlareUI_VolumeBtn
    local function UpdateIcon()
        local color = HEADER_ICON_COLOR
        local tex = Chat.VolumeIcon()
        if btn then
            -- struck bronze, like the other header icons
            if not btn.FlareUI_Icon then
                btn.FlareUI_Icon = btn:CreateTexture(nil, "ARTWORK")
                btn.FlareUI_Icon:SetAllPoints()
                btn:HookScript("OnMouseDown", HeaderButtonDown)
                btn:HookScript("OnMouseUp", HeaderButtonUp)
            end
            ns.BronzeIcon.Apply(btn.FlareUI_Icon, tex, color)
            if btn:IsMouseOver() then ns.BronzeIcon.Paint(btn.FlareUI_Icon, color, true) end
        end
    end

    if not btn then
        btn = CreateFrame("Button", nil, chatFrame.FlareUI_Skin)
        chatFrame.FlareUI_VolumeBtn = btn
        btn:SetSize(28, 28)
        btn:RegisterForClicks("LeftButtonUp")
        btn:EnableMouseWheel(true)

        btn:SetScript("OnEnter", function(self)
            ns.OwnGameTooltip(self, "ANCHOR_TOP")
            local vol = tonumber(C_CVar.GetCVar("Sound_MasterVolume")) or 0

            -- red at 0%, orange at 50%, green at 100%
            local r, g
            if vol <= 0.5 then
                r, g = 1, vol
            else
                local t = (vol - 0.5) * 2
                r, g = 1 - t, 0.5 + 0.5 * t
            end
            GameTooltip:AddLine(string_format("%d%%", vol * 100), r, g, 0)
            GameTooltip:Show()
            if SELECTED_CHAT_FRAME then Chat:ShowChatFrame(SELECTED_CHAT_FRAME, GetDb()) end
            UpdateIcon()
        end)

        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
            UpdateIcon()
        end)

        btn:RegisterEvent("CVAR_UPDATE")
        btn:SetScript("OnEvent", function(self, event, cvar, value)
            if event == "CVAR_UPDATE" and cvar == "Sound_MasterVolume" then UpdateIcon() end
        end)

        btn:SetScript("OnMouseWheel", function(self, delta)
            local current = tonumber(C_CVar.GetCVar("Sound_MasterVolume")) or 0
            local new = current + (delta * 0.05)
            if new > 1 then new = 1 elseif new < 0 then new = 0 end
            C_CVar.SetCVar("Sound_MasterVolume", new)
            if GameTooltip:IsOwned(self) then self:GetScript("OnEnter")(self) end
            if SELECTED_CHAT_FRAME then Chat:ShowChatFrame(SELECTED_CHAT_FRAME, GetDb()) end
        end)

        btn:SetScript("OnClick", function(self)
            local current = tonumber(C_CVar.GetCVar("Sound_MasterVolume")) or 0
            if current > 0 then self.prevVolume = current; C_CVar.SetCVar("Sound_MasterVolume", 0)
            else local restore = self.prevVolume or 1; C_CVar.SetCVar("Sound_MasterVolume", restore) end
            if GameTooltip:IsOwned(self) then self:GetScript("OnEnter")(self) end
        end)
    end

    btn:Show()
    btn:ClearAllPoints()
    btn:SetScale(HEADER_ICON_SCALE)
    btn:SetPoint("TOPRIGHT", chatFrame.FlareUI_Skin, "TOPRIGHT", HeaderButtonX(db, "volume"), HEADER_ICON_Y)

    btn:SetFrameStrata("DIALOG")
    btn:SetFrameLevel(210)
    EnableHeaderDrag(btn, "volume")

    UpdateIcon()
end

-- The window's skin: dark dialog background at the chat's opacity, FlareUI's border (also the
-- settings previews' sample windows, here and in the damage meter's Meter tab)
function Chat.WindowBackdrop(skin, db)
    local bgTexture     = LSM:Fetch("background", "Blizzard Dialog Background Dark") or "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"
    local borderTexture = GetBorderFile(db)
    local inset         = BORDER_INSET
    skin:SetBackdrop({ bgFile = bgTexture, edgeFile = borderTexture, tile = false, tileSize = 0, edgeSize = ns.BorderEdgeSize(borderTexture, BORDER_SIZE), insets = { left = inset, right = inset, top = inset, bottom = inset } })
    skin:SetBackdropColor(1, 1, 1, db.opacity or 1)
    local border = ns.BORDER_COLOR
    skin:SetBackdropBorderColor(border.r, border.g, border.b, border.a)
end

local function CreateOrGetSkinFrame(chatFrame)
    local skin = chatFrame.FlareUI_Skin
    -- the Combat Log's text starts below its filter bar; its skin and separator stay where the others' are
    local raise = (chatFrame == _G.ChatFrame2) and COMBAT_BAR_SPACE or 0
    if not skin then
        skin = CreateFrame("Frame", nil, chatFrame, "BackdropTemplate")
        chatFrame.FlareUI_Skin = skin
        -- keeps Blizzard's gamepad cursor on the edit box, off FlareUI's tabs and buttons
        if ns.IsGamepadUI() then skin.smartNavigationIgnored = true end
        -- the line under the tab row
        local line = skin:CreateTexture(nil, "OVERLAY")
        line:SetTexture(SEPARATOR)
        line:SetHeight(8)
        line:SetPoint("TOPLEFT", chatFrame, "TOPLEFT", -TEXT_PADDING + BORDER_INSET + 2, 10 + raise)
        line:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", TEXT_PADDING - BORDER_INSET - 2, 10 + raise)
        skin.Separator = line
    end

    skin:ClearAllPoints()
    skin:SetPoint("BOTTOMLEFT", chatFrame, "BOTTOMLEFT", -TEXT_PADDING, -TEXT_PADDING)
    skin:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", TEXT_PADDING, TEXT_PADDING + HEADER_HEIGHT + raise)
    if chatFrame.Selection then
        ns.FitEditModeBox(chatFrame, function() return chatFrame.FlareUI_Skin, 0, 0, 0, 0 end)
        -- Edit Mode's resize grip in the corner stays hidden
        local grip = chatFrame.EditModeResizeButton
        if grip and not grip.FlareUI_Hidden then
            grip.FlareUI_Hidden = true
            hooksecurefunc(grip, "Show", grip.Hide)
            grip:Hide()
        end
    end
    ns.CopyStrata(skin, chatFrame)
    skin:SetFrameLevel(math_max((chatFrame:GetFrameLevel() or 1) - 1, 0))
    return skin
end

-- A window's message font: FlareUI's chat font (Settings > Chat > Fonts), the same in every window
function Chat:MessageFont(chatFrame, db)
    return GetFontData(db.chatFont)
end

-- Increase Line Height: this much over the window's own spacing. Off never touches a window it didn't change.
local EXTRA_LINE_SPACING = 2
local function ApplyLineSpacing(chatFrame, db)
    if db.increaseLineHeight then
        if not chatFrame.FlareUI_BaseSpacing then chatFrame.FlareUI_BaseSpacing = chatFrame:GetSpacing() or 0 end
        chatFrame:SetSpacing(chatFrame.FlareUI_BaseSpacing + EXTRA_LINE_SPACING)
    elseif chatFrame.FlareUI_BaseSpacing then
        chatFrame:SetSpacing(chatFrame.FlareUI_BaseSpacing)
        chatFrame.FlareUI_BaseSpacing = nil
    end
end

function Chat:ApplyMessageFont(chatFrame, db)
    local path, size, flags = self:MessageFont(chatFrame, db)
    chatFrame.FlareUI_SettingFont = true
    chatFrame:SetFont(path, size, flags)
    chatFrame.FlareUI_SettingFont = false
    ns.ApplyShadow(chatFrame, db.chatFont)
    ApplyLineSpacing(chatFrame, db)
end

function Chat:StyleChatFrame(chatFrame, db)
    if not chatFrame or chatFrame:IsForbidden() then return end
    -- the main window is Edit Mode's chat system: its box goes on the skin and keeps it on screen
    -- (ns.FitEditModeBox); the others may be dragged partly off screen
    if not chatFrame.Selection then UnclampChatFrame(chatFrame) end

    StripBlizzardChatBackground(chatFrame)
    KillScrollBar(chatFrame)
    HideButtonFrame(chatFrame)
    RepositionScrollToBottomButton(chatFrame)
    UpdateCopyButton(chatFrame, db)

    if not chatFrame.FlareUI_ScriptHooked then
        chatFrame.FlareUI_ScriptHooked = true
        chatFrame:SetScript("OnUpdate", nil)
    end

    chatFrame:SetFading(false)
    chatFrame:SetTimeVisible(9999)

    -- Blizzard's own alpha changes are overruled by FlareUI's target alpha
    if not chatFrame.FlareUI_AlphaHooked then
        Chat:SecureHook(chatFrame, "SetAlpha", function(frameParam, alpha)
            if frameParam.FlareUI_IgnoreAlpha then return end
            local chatDb = GetDb()
            local target = chatDb and not Chat.Fades(chatDb) and 1 or frameParam.FlareUI_TargetAlpha
            if target and math_abs(alpha - target) > 0.001 then
                frameParam.FlareUI_IgnoreAlpha = true
                frameParam:SetAlpha(target)
                frameParam.FlareUI_IgnoreAlpha = false
            end
        end)
        chatFrame.FlareUI_AlphaHooked = true
    end

    local skin = CreateOrGetSkinFrame(chatFrame)
    Chat.WindowBackdrop(skin, db)

    if not chatFrame.FlareUI_FontHooked then
        chatFrame.FlareUI_FontHooked = true
        -- anything else setting the font (Blizzard's font size) gets FlareUI's back
        Chat:SecureHook(chatFrame, "SetFont", function(frameParam, font, size)
            if frameParam.FlareUI_SettingFont then return end
            local chatDb = GetDb()
            if not (chatDb and chatDb.enabled) then return end
            local myPath, mySize = Chat:MessageFont(frameParam, chatDb)
            if not size or math_abs(size - mySize) > 0.1 or font ~= myPath then Chat:ApplyMessageFont(frameParam, chatDb) end
        end)
    end
    Chat:ApplyMessageFont(chatFrame, db)

    Chat:CreateCustomTabBar(chatFrame)
    Chat:UpdateCustomTabs(chatFrame, db)
    -- during Apply these run once after all windows (see Chat:Apply)
    if not Chat.applying then Chat:HideBlizzardTabs() end

    Chat:SetupVolumeButton(chatFrame, db)
    Chat:ApplyPopState(chatFrame)
    if not Chat.applying then Chat:StyleHeaderButtons() end
end

--------------------------------------------------
-- 15. POP-OUT WINDOWS
-- With Blizzard's tabs hidden, the tab menu's Pop Out undocks a window through Blizzard's functions,
-- which save its state, position and size. A popped window keeps the skin with only its own tab;
-- its tab and header drag it. The shared header buttons stay on the dock.
--------------------------------------------------
local POPOUT_GAP = 8   -- px between the main chat's skin and a popped window's, as first placed

function Chat:StartMovingWindow(chatFrame)
    if chatFrame.isLocked or not IsPopped(chatFrame) then return end
    chatFrame:SetMovable(true)
    chatFrame:StartMoving()
    chatFrame.FlareUI_Moving = true
end

function Chat:StopMovingWindow(chatFrame)
    if not chatFrame.FlareUI_Moving then return end
    chatFrame.FlareUI_Moving = nil
    chatFrame:StopMovingOrSizing()
    FCF_SavePositionAndDimensions(chatFrame)
end

-- The header of a popped window drags it; a docked window's skin takes no mouse
function Chat:ApplyPopState(chatFrame)
    local skin = chatFrame and chatFrame.FlareUI_Skin
    if not skin then return end
    local popped = IsPopped(chatFrame)
    if not skin.FlareUI_DragSetup then
        skin.FlareUI_DragSetup = true
        skin:RegisterForDrag("LeftButton")
        skin:SetScript("OnDragStart", function() Chat:StartMovingWindow(chatFrame) end)
        skin:SetScript("OnDragStop", function() Chat:StopMovingWindow(chatFrame) end)
    end
    skin:EnableMouse(popped)
end

-- Every window's tab bar, header buttons and drag state, after a window docks or pops out
function Chat:RefreshWindows()
    local db = GetDb()
    if not db then return end
    for _, cf in Windows() do
        if cf and cf.FlareUI_Skin and not cf:IsForbidden() then
            Chat:SetupVolumeButton(cf, db)
            Chat:UpdateCustomTabs(cf, db)
            Chat:ApplyPopState(cf)
        end
    end
    Chat:HideBlizzardTabs()
    Chat:StyleHeaderButtons()
end

-- Above the main chat at its size, the two skins POPOUT_GAP apart; beside it if that leaves the
-- screen, in the middle if that does too.
function Chat:PopOutWindow(chatFrame)
    local db = GetDb()
    local dock = _G.GeneralDockManager
    local host = dock and dock.primary
    if not (db and host) or not chatFrame.isDocked or chatFrame == host then return end
    local pad, header = TEXT_PADDING, HEADER_HEIGHT
    -- the main chat in UIParent's units (Edit Mode can scale it)
    local s = host:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local left, bottom = (host:GetLeft() or 0) * s, (host:GetBottom() or 0) * s
    local right, top = (host:GetRight() or 0) * s, (host:GetTop() or 0) * s
    local width, height = right - left, top - bottom
    local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()

    FCF_UnDockFrame(chatFrame)
    chatFrame:ClearAllPoints()
    local aboveY = top + pad + header + POPOUT_GAP + pad
    local besideX = right + pad + POPOUT_GAP + pad
    if aboveY + height + header + pad <= screenH then
        chatFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, aboveY)
    elseif besideX + width + pad <= screenW then
        chatFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", besideX, bottom)
    else
        chatFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    chatFrame:SetSize(width, height)
    FCF_CheckShowChatFrame(chatFrame)
    FCF_SetLocked(chatFrame, false)
    FCF_SavePositionAndDimensions(chatFrame)
    Chat:RefreshWindows()
    Chat:ShowChatFrame(chatFrame, db)
end

function Chat:DockWindow(chatFrame)
    local dock = _G.GeneralDockManager
    if not (dock and IsPopped(chatFrame)) then return end
    FCF_DockFrame(chatFrame, #dock.DOCKED_CHAT_FRAMES + 1, true)
    Chat:RefreshWindows()
end

--------------------------------------------------
-- 16. AUTO-HIDE
-- With a Visibility other than Always, a window stays up autoHideDelay seconds (Fade Delay) after
-- the last message, hover, edit (or combat), then fades out at the Fade Speed. A message only
-- moves hideAt; one timer per window waits for it. Fades run on one shared OnUpdate that stops when
-- nothing is fading.
--------------------------------------------------
local autoHide = {}   -- chat frame -> { frame, hideAt, timer, expire, fadeFrom, fadeTo, fadeStart, fadeTime }

-- Visibility: always | interactions (new messages and typing wake it) | combat (that, and up in a
-- fight). A test build saved ticked toggles ("messages,incombat"): read as the nearest choice.
Chat.VISIBILITY_SPEC = { exclusive = { "always", "mouseover" }, tokens = { "messages", "incombat" }, empty = "mouseover",
    legacy = { interactions = "messages", combat = "messages,incombat" } }
function Chat.VisibilityHas(db, token)
    if not db then return false end
    local v = db.visibility
    if v ~= nil and v ~= "always" and v ~= "interactions" and v ~= "combat" then
        db.visibility = ns.Conditions.Has(v, "incombat") and "combat" or "interactions"
    end
    return ns.Conditions.Has(db.visibility, token, Chat.VISIBILITY_SPEC)
end

-- The chat fades away with any Visibility but Always
local function Fades(db)
    return db and (db.visibility or "always") ~= "always" or false
end
Chat.Fades = Fades

local function FadeDuration(db) return ns.FadeTime(db and db.fadeSpeed) end
local fadeDriver = CreateFrame("Frame")
fadeDriver:Hide()

function Chat:SetChatFrameAlpha(chatFrame, alpha)
    if not chatFrame or chatFrame:IsForbidden() then return end
    if chatFrame.FlareUI_TargetAlpha == alpha and chatFrame:GetAlpha() == alpha then return end
    chatFrame.FlareUI_TargetAlpha = alpha
    chatFrame.FlareUI_IgnoreAlpha = true
    chatFrame:SetAlpha(alpha)
    chatFrame.FlareUI_IgnoreAlpha = false
    -- on the Meter tab the meter fades with the window it stands in
    if Chat:MeterTabActive() and chatFrame == SelectedDocked() then ns.DamageMeter:SetChatTabAlpha(alpha) end
end

-- true while something keeps the window up: the mouse, a focused edit box, combat, Edit Mode
function Chat:CheckChatVisibility(chatFrame, db)
    if chatFrame:IsMouseOver() then return true end
    if chatFrame.FlareUI_Skin and chatFrame.FlareUI_Skin:IsMouseOver() then return true end
    if chatFrame == (SELECTED_CHAT_FRAME or ChatFrame1) then
        for _, name in pairs(HEADER_BLIZZARD) do
            local btn = _G[name]
            if btn and btn:IsMouseOver() then return true end
        end
    end
    if Chat:MeterTabActive() and (ns.DamageMeter:ChatTabIgnoresFade() or ns.DamageMeter:ChatTabMouseOver()) then return true end
    local editBox = chatFrame.editBox
    if editBox and editBox:HasFocus() then return true end
    if Chat.VisibilityHas(db, "incombat") and InCombatLockdown() then return true end
    if Chat.settingsPreview then return true end
    return _G.EditModeManagerFrame ~= nil and _G.EditModeManagerFrame:IsShown()
end

local function FadeTo(state, alpha, duration)
    local from = state.frame:GetAlpha()
    if duration <= 0 or math_abs(alpha - from) <= 0.05 then
        state.fadeTo = nil
        Chat:SetChatFrameAlpha(state.frame, alpha)
        return
    end
    state.fadeFrom, state.fadeTo, state.fadeStart, state.fadeTime = from, alpha, GetTime(), duration
    fadeDriver:Show()
end

fadeDriver:SetScript("OnUpdate", function(self)
    local db, now, busy = GetDb(), GetTime(), false
    for frame, state in pairs(autoHide) do
        local to = state.fadeTo
        if to then
            if to < state.fadeFrom and db and Chat:CheckChatVisibility(frame, db) then
                Chat:ShowChatFrame(frame, db)   -- a fade-out interrupted
            else
                local t = (now - state.fadeStart) / state.fadeTime
                if t >= 1 then
                    state.fadeTo = nil
                    Chat:SetChatFrameAlpha(frame, to)
                else
                    Chat:SetChatFrameAlpha(frame, state.fadeFrom + (to - state.fadeFrom) * t)
                end
            end
            busy = busy or state.fadeTo ~= nil
        end
    end
    if not busy then self:Hide() end
end)

local function OnHoldExpired(state)
    state.timer = nil
    local db = GetDb()
    if not (db and db.enabled and Fades(db)) then return end
    local remaining = state.hideAt - GetTime()
    if remaining <= 0 and Chat:CheckChatVisibility(state.frame, db) then
        remaining = (db.autoHideDelay or 10) > 0.5 and 1 or 0.1
    end
    if remaining > 0 then
        state.timer = C_Timer.NewTimer(remaining, state.expire)
    else
        -- Faded Opacity: how far the window fades out (0 = gone)
        FadeTo(state, math_max(0, math_min(0.9, tonumber(db.minAlpha) or 0)), FadeDuration(db))
    end
end

local function AutoHideState(chatFrame)
    local state = autoHide[chatFrame]
    if not state then
        state = { frame = chatFrame }
        state.expire = function() OnHoldExpired(state) end
        autoHide[chatFrame] = state
    end
    return state
end

-- Shows the window (fading in) and restarts its hold
function Chat:ShowChatFrame(chatFrame, db)
    if not (chatFrame and db) or chatFrame:IsForbidden() then return end
    if not Fades(db) then
        if autoHide[chatFrame] then autoHide[chatFrame].fadeTo = nil end
        Chat:SetChatFrameAlpha(chatFrame, 1)
        return
    end
    local state = AutoHideState(chatFrame)
    if state.fadeTo ~= 1 and not (state.fadeTo == nil and chatFrame.FlareUI_TargetAlpha == 1) then
        FadeTo(state, 1, FadeDuration(db))
    end
    local delay = math_max(0, db.autoHideDelay or 10)
    state.hideAt = GetTime() + (state.fadeTo and state.fadeTime or 0) + delay
    if not state.timer then
        state.timer = C_Timer.NewTimer(state.hideAt - GetTime(), state.expire)
    end
end

-- Switching tabs: the window shown takes the opacity and hold of the one it replaces, at once. A hidden
-- tab's window fades out on its own timer, so it would show faded for an instant and fade back in.
function Chat:TakeOverFromDock(chatFrame)
    local db = GetDb()
    if not (db and chatFrame and chatFrame.FlareUI_Skin) or chatFrame:IsForbidden() then return end
    local from = self.shownDocked or _G.ChatFrame1
    self.shownDocked = chatFrame
    if not from or from == chatFrame or from:IsForbidden() then return end
    local state = AutoHideState(chatFrame)
    local src = autoHide[from]
    state.fadeTo = nil
    Chat:SetChatFrameAlpha(chatFrame, from.FlareUI_TargetAlpha or from:GetAlpha())
    if src and src.fadeTo then   -- mid fade: it carries on from where it is
        state.fadeFrom, state.fadeTo, state.fadeStart, state.fadeTime = src.fadeFrom, src.fadeTo, src.fadeStart, src.fadeTime
        fadeDriver:Show()
    end
    if Fades(db) then
        state.hideAt = (src and src.hideAt) or (GetTime() + math_max(0, db.autoHideDelay or 10))
        if not state.timer then state.timer = C_Timer.NewTimer(math_max(0, state.hideAt - GetTime()), state.expire) end
    end
end

--------------------------------------------------
-- 17. EVENT HANDLERS
--------------------------------------------------
function Chat:OnCombatStateChange()
    local db = GetDb()
    if not (db and db.enabled and Fades(db) and Chat.VisibilityHas(db, "incombat")) then return end
    for _, cf in Windows() do
        if cf and cf:IsShown() and not cf:IsForbidden() then
            self:ShowChatFrame(cf, db)
        end
    end
end

function Chat:RefreshForEditMode()
    local db = GetDb()
    if not db or not db.enabled then return end
    for _, cf in Windows() do
        if cf and cf.FlareUI_Skin and not cf:IsForbidden() then
            self:ShowChatFrame(cf, db)
        end
    end
end

-- Settings > Chat open: the windows stay fully shown (Frame Opacity can be seen); afterwards they
-- fade on their usual timer
function Chat:SetSettingsPreview(on)
    on = on and true or false
    if self.settingsPreview == on then return end
    self.settingsPreview = on
    self:RefreshForEditMode()   -- shown, their hold restarted
end

-- the chat comes back after a quest or gossip window
function Chat:OnNPCInteractionEnd()
    if SELECTED_CHAT_FRAME then self:ShowChatFrame(SELECTED_CHAT_FRAME, GetDb()) end
end

--------------------------------------------------
-- 18. APPLY
--------------------------------------------------
-- every message (combat log lines included) lands here, so it returns early when auto-hide is off
local function OnChatMessage(chatFrame)
    local db = GetDb()
    -- Hide Combat Log: the hidden log still gets every combat line, with nothing to show or wake
    if chatFrame == _G.ChatFrame2 and db and db.hideCombatLog then return end
    UpdateScrollToBottomVisibility(chatFrame)
    -- a line into a window that isn't shown (another tab) doesn't wake the chat: its tab lights up
    if db and Fades(db) and Chat.VisibilityHas(db, "messages") and chatFrame:IsVisible() then Chat:ShowChatFrame(chatFrame, db) end
    -- a line under the Meter tab lights its window's tab (not the Combat Log's, which never stops)
    if Chat:MeterTabActive() and not meterUnread[chatFrame] and chatFrame ~= _G.ChatFrame2 and chatFrame == SelectedDocked() then
        meterUnread[chatFrame] = true
        MarkUnread(chatFrame)
    end
end

local function OnChatEnter(chatFrame)
    Chat:ShowChatFrame(chatFrame, GetDb())
end

function Chat:SetupAutoHide(db)
    if not db then return end
    if not Chat.autoHideEventsRegistered then
        self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatStateChange")
        self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatStateChange")
        Chat.autoHideEventsRegistered = true
    end

    -- CHAT_FRAMES also lists the whisper windows (ChatFrame11 and up)
    for _, name in ipairs(CHAT_FRAMES or {}) do
        local frame = _G[name]
        if frame and not frame:IsForbidden() then
            Chat:HookAutoHide(frame)
            Chat:ShowChatFrame(frame, db)
        end
    end
end

function Chat:HookAutoHide(frame)
    if frame.FlareUI_AutoHideHooked then return end
    frame.FlareUI_AutoHideHooked = true
    Chat:SecureHookScript(frame, "OnEnter", OnChatEnter)
    Chat:SecureHook(frame, "AddMessage", OnChatMessage)
    -- its edit box keeps it shown while open: see EditExtras.Setup (Blizzard's focus announcement)
end

-- Formatting lives in the line rewriter, which reads the options on every line
function Chat:UpdateFilters()
    HookLineRewrite()
    Lines.UpdateLevelEvents()
end

function Chat:Apply(db)
    if not db then return end

    if db.hideCombatLog and ChatFrame2 then
        ChatFrame2:UnregisterAllEvents()
        ChatFrame2:SetScript("OnEvent", nil)
    end

    KeepCombatLogSecond()
    KeepCombatLogBelowBar()
    StyleCombatLogBar()
    Chat:KillGeneralDockManager()
    StyleButtonFrame()

    -- a whisper window is skinned when first selected (AfterDockTabs), and follows the settings after that.
    -- The header and Blizzard's tabs are done once after the loop, not once per window.
    Chat.tabStylePass = (Chat.tabStylePass or 0) + 1
    Chat.applying = true
    -- an error inside (reported) must not leave the flag up
    local ok, err = pcall(function()
        for _, frame in Windows() do
            if frame and not frame:IsForbidden() and (frame.FlareUI_Skin or not frame.isTemporary) then
                Chat:StyleChatFrame(frame, db)
                Chat:StyleEditBox(frame, db)
            end
        end
    end)
    Chat.applying = nil
    if not ok then geterrorhandler()(err) end
    Chat:HideBlizzardTabs()
    Chat:StyleHeaderButtons()
    -- again: the Gamepad UI parks the dock at ChatFrame1's skin, made in the loop above
    if ns.IsGamepadUI() then Chat:KillGeneralDockManager() end
    AnchorVoiceChat()

    Chat:SetupAutoHide(db)
    self:UpdateTabFonts(db)
end

--------------------------------------------------
-- 19. INIT
--------------------------------------------------
-- Blizzard's gamepad chat only works in IM style, so the Gamepad UI switches to it; the player's
-- style comes back in keyboard mode. The CVar is account-wide, so the saved style is too.
function Chat:ApplyGamepadChatStyle()
    local global = ns.db.global
    local current = C_CVar.GetCVar("chatStyle")
    if ns.IsGamepadUI() then
        if current ~= "im" then
            global.chatStyleBeforeGamepad = current
            C_CVar.SetCVar("chatStyle", "im")
        end
    elseif global.chatStyleBeforeGamepad then
        if current == "im" then C_CVar.SetCVar("chatStyle", global.chatStyleBeforeGamepad) end
        global.chatStyleBeforeGamepad = nil
    end
end

-- Gamepad UI: LB / RB icons above the header of the chat window that has the pad. Polled: a hook on
-- Blizzard's focus calls would run addon code inside its gamepad focus manager.
local function SetupGamepadTabHints()
    if not ns.IsGamepadUI() then return end
    local function MakeIcon(key)
        local icon = CreateFrame("Frame", nil, UIParent, "InputIconTextureFrameTemplate")
        icon:SetSize(26, 26)
        icon:SetFrameStrata("DIALOG")
        if icon.EnableDropShadow then icon:EnableDropShadow() end
        icon:SetInputKey(key)
        icon:Hide()
        return icon
    end
    local left = MakeIcon(GAMEPAD_SHOULDER_LEFT or "PADLSHOULDER")
    local right = MakeIcon(GAMEPAD_SHOULDER_RIGHT or "PADRSHOULDER")
    local shownFor, elapsed = nil, 0
    local poll = CreateFrame("Frame")
    poll:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < 0.1 then return end
        elapsed = 0
        local focused
        for i = 1, NUM_CHAT_WINDOWS do
            local cf = _G["ChatFrame" .. i]
            if cf and cf.HasGamepadFocus and cf:IsVisible() and cf:HasGamepadFocus() then
                focused = cf
                break
            end
        end
        if focused == shownFor then return end
        shownFor = focused
        local skin = focused and ((focused.FlareUI_Skin and focused.FlareUI_Skin:IsVisible() and focused.FlareUI_Skin)
            or (ChatFrame1 and ChatFrame1.FlareUI_Skin))
        if skin then
            left:ClearAllPoints()
            left:SetPoint("BOTTOMLEFT", skin, "TOPLEFT", 0, 2)
            right:ClearAllPoints()
            right:SetPoint("BOTTOMRIGHT", skin, "TOPRIGHT", 0, 2)
            left:Show()
            right:Show()
        else
            left:Hide()
            right:Hide()
        end
    end)
end

-- Runs at login even with Chat off (Core asks before it checks the switch): what FlareUI stored while
-- it was on goes back, as Init would otherwise never run to restore it.
function Chat:ShouldLoad()
    local db, global = GetDb(), ns.db and ns.db.global
    if global and db and not db.enabled then
        if global.hiddenBubbles then RestoreBubbles(global) end
        if global.chatStyleBeforeGamepad then
            if C_CVar.GetCVar("chatStyle") == "im" then C_CVar.SetCVar("chatStyle", global.chatStyleBeforeGamepad) end
            global.chatStyleBeforeGamepad = nil
        end
    end
    return true
end

function Chat:Init()
    Chat:ApplyGamepadChatStyle()
    SetupGamepadTabHints()
    -- Blizzard's own fading is off per frame (StyleChatFrame); never blank the FCF_Fade* globals
    Chat:ProtectButtons()

    if QuickJoinToastButton then
        local function Restyle()
            if Chat.isStyling then return end
            C_Timer.After(0.05, function() Chat:StyleHeaderButtons() end)
        end
        Chat:SecureHook(QuickJoinToastButton, "SetPoint", Restyle)
        Chat:SecureHook(QuickJoinToastButton, "Show", Restyle)
    end

    Chat:SecureHook("FCF_SelectDockFrame", function(view)
        Chat:StyleHeaderButtons(view)
    end)
    -- a tab switch shows the new window as the old one was
    hooksecurefunc("FCFDock_SelectWindow", function(dock, chatFrame)
        if dock == _G.GENERAL_CHAT_DOCK then Chat:TakeOverFromDock(chatFrame) end
    end)

    Chat:KillGeneralDockManager()

    ns.Dialogs["FLAREUI_RENAME_CHAT"] = {
        text = L["Rename Chat Window"],
        button1 = ACCEPT,
        button2 = CANCEL,
        hasEditBox = true,
        maxLetters = 31,
        editText = function(chatFrame)
            local name = chatFrame and chatFrame.name
            return canaccessvalue(name) and name or ""   -- a whisper window's name can be secret
        end,
        OnAccept = function(chatFrame, text)
            if text and text ~= "" and chatFrame then
                FCF_SetWindowName(chatFrame, text)
                Chat:UpdateCustomTabs(chatFrame, GetDb())
            end
        end,
        hideOnEscape = true,
    }

    self:ScheduleTimer(function() Chat:RefreshAll() end, 0.2)
    self:ScheduleTimer(function() Chat:RestoreHistory() end, 1)

    if not Chat.npcEventsRegistered then
        self:RegisterEvent("GOSSIP_CLOSED", "OnNPCInteractionEnd")
        self:RegisterEvent("QUEST_FINISHED", "OnNPCInteractionEnd")
        self:RegisterEvent("QUEST_GREETING", "OnNPCInteractionEnd")
        self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateInstanceBubbles")
        Chat.npcEventsRegistered = true
    end

    if not Chat._tabsHooked then
        Chat._tabsHooked = true

        -- styles windows that do not have a skin yet
        local function StyleNewWindows(db)
            for i = 1, NUM_CHAT_WINDOWS do
                local cf = _G["ChatFrame" .. i]
                if cf and not cf:IsForbidden() and not cf.FlareUI_Skin then
                    Chat:StyleChatFrame(cf, db)
                    Chat:StyleEditBox(cf, db)
                end
            end
            Chat:HideBlizzardTabs()
        end

        Chat:SecureHook("FCF_OpenNewWindow", function()
            C_Timer.After(0.2, function()
                local db = GetDb()
                if not db then return end
                StyleNewWindows(db)
                if _G.ChatFrame1 then Chat:UpdateCustomTabs(_G.ChatFrame1, db) end
                -- again once the new window has been shown and selected
                Chat:StyleHeaderButtons()
                C_Timer.After(0.4, function() Chat:StyleHeaderButtons() end)
            end)
        end)

        -- a window docked or undocked by Blizzard (at login, Reset Chat Windows) or by Pop Out / Dock
        local function RefreshSoon() C_Timer.After(0, function() Chat:RefreshWindows() end) end
        Chat:SecureHook("FCF_DockFrame", RefreshSoon)
        Chat:SecureHook("FCF_UnDockFrame", RefreshSoon)

        Chat:SecureHook("FCF_Close", function()
            C_Timer.After(0.2, function()
                local db = GetDb()
                if not db then return end
                if _G.ChatFrame1 then Chat:UpdateCustomTabs(_G.ChatFrame1, db) end
                Chat:StyleHeaderButtons()
                -- a closed tab leaves the bars scrolled past the tabs that remain: back to the first
                Chat:SetTabScroll(0)
            end)
        end)

        -- the tab bars follow the dock; the selected window stays shown (and styled, if temporary)
        local function AfterDockTabs()
            local db = GetDb()
            if not db then return end
            for _, cf in Windows() do
                if cf and cf.FlareUI_TabBar then Chat:UpdateCustomTabs(cf, db) end
            end
            Chat:StyleHeaderButtons()
            local dock = _G.GeneralDockManager
            local selectedFrame = dock and FCFDock_GetSelectedWindow(dock)
            if selectedFrame and not selectedFrame:IsForbidden() then
                selectedFrame:Show()
                if selectedFrame.isTemporary and not selectedFrame.FlareUI_Skin then
                    Chat:StyleChatFrame(selectedFrame, db)
                    Chat:StyleEditBox(selectedFrame, db)
                    Chat:HookAutoHide(selectedFrame)
                    Chat:ShowChatFrame(selectedFrame, db)
                end
            end
            -- Meter tab up and Blizzard selects another window (a new window, a whisper you start):
            -- that window wins, or its lines would draw under the meter
            if selectedFrame ~= Chat.lastDockSelected then
                if Chat.lastDockSelected and Chat:MeterTabActive() then Chat:SelectMeterTab(false) end
                Chat.lastDockSelected = selectedFrame
            end
            EditExtras.FollowDock()
        end
        Chat:SecureHook("FCFDock_UpdateTabs", function()
            local db = GetDb()
            if db then HandleCombatLog(db) end
            C_Timer.After(0, AfterDockTabs)
        end)

        -- a tab's alert colour starts and stops without a dock update
        local function AfterAlertFlash() C_Timer.After(0, AfterDockTabs) end
        Chat:SecureHook("FCF_StartAlertFlash", AfterAlertFlash)
        Chat:SecureHook("FCF_StopAlertFlash", AfterAlertFlash)

        -- Blizzard passes the chat frame, not its tab
        Chat:SecureHook("FCFTab_UpdateAlpha", function(chatFrame)
            local tab = chatFrame and _G[chatFrame:GetName() .. "Tab"]
            if not tab or tab:IsForbidden() then return end
            tab:SetAlpha(0)
        end)

        -- A new whisper window: Blizzard decides whether it takes the selection (a whisper you start
        -- selects its tab; one you receive only flashes it). FlareUI only styles it.
        Chat:SecureHook("FCF_OpenTemporaryWindow", function()
            C_Timer.After(0, function()
                local db = GetDb()
                if not db then return end
                StyleNewWindows(db)
                local dock = _G.GeneralDockManager
                for _, cf in ipairs(dock and dock.DOCKED_CHAT_FRAMES or {}) do
                    if cf.isTemporary and not cf.FlareUI_Skin and not cf:IsForbidden() then
                        Chat:StyleChatFrame(cf, db)
                        Chat:StyleEditBox(cf, db)
                        Chat:HookAutoHide(cf)
                    end
                end
                if _G.ChatFrame1 then Chat:UpdateCustomTabs(_G.ChatFrame1, db) end
            end)
        end)
    end

    -- Edit Mode keeps the chat shown
    if _G.EditModeManagerFrame and not Chat.editModeHooksAttached then
        Chat:SecureHookScript(_G.EditModeManagerFrame, "OnShow", function() Chat:RefreshForEditMode() end)
        Chat:SecureHookScript(_G.EditModeManagerFrame, "OnHide", function() Chat:RefreshForEditMode() end)
        Chat.editModeHooksAttached = true
    end

    -- Saved on leaving the world (it comes before a reload or logout), not at PLAYER_LOGOUT: AceDB
    -- strips the defaults there first, so saveHistory (on by default) would read as off and wipe it
    if not Chat.historyEventsRegistered then
        self:RegisterEvent("PLAYER_LEAVING_WORLD", "SaveHistory")
        Chat.historyEventsRegistered = true
    end
    self.started = true
end

--------------------------------------------------
-- 20. SAVED HISTORY AND REFRESH
--------------------------------------------------
local HISTORY_LINES = 128   -- kept per window

-- A Battle.net friend's name reaches chat as a token (|K...|k) the client only resolves this session:
-- saved as is, it could show another friend's name next time. Saved lines take the BattleTag
-- (without its number) instead, and a line with a token nobody matches is left out. BN links, which
-- point at this session's friend IDs, keep only their text.
local function BattleTagsByToken()
    local map = {}
    if not (C_BattleNet and C_BattleNet.GetFriendAccountInfo and BNGetNumFriends) then return map end
    local ok, count = pcall(BNGetNumFriends)
    if not (ok and canaccessvalue(count) and type(count) == "number") then return map end
    for i = 1, count do
        local got, info = pcall(C_BattleNet.GetFriendAccountInfo, i)
        local token, tag = got and info and info.accountName, got and info and info.battleTag
        if canaccessallvalues(token, tag) and type(token) == "string" and type(tag) == "string" then
            map[token] = tag:match("^[^#]+") or tag
        end
    end
    return map
end

local function SafeHistoryLine(msg, tags)
    if not msg:find("|K", 1, true) and not msg:find("|HBNplayer", 1, true) then return msg end
    local missing = false
    msg = msg:gsub("|K.-|k", function(token)
        local name = tags[token]
        if not name then missing = true end
        return name or ""
    end)
    if missing then return nil end
    return (msg:gsub("|HBNplayer:.-|h(.-)|h", "%1"))
end

-- Saved History keeps conversation only: lines from players (and your own), not loot, money, system
-- or addon lines, which have no chat event
local PLAYER_CHAT = {}
for _, kind in ipairs({ "SAY", "YELL", "EMOTE", "TEXT_EMOTE", "WHISPER", "WHISPER_INFORM", "BN_WHISPER",
        "BN_WHISPER_INFORM", "GUILD", "OFFICER", "PARTY", "PARTY_LEADER", "PARTY_GUIDE", "RAID", "RAID_LEADER",
        "RAID_WARNING", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER", "CHANNEL", "COMMUNITIES_CHANNEL" }) do
    PLAYER_CHAT["CHAT_MSG_" .. kind] = true
end

-- Lines put back from the last session: the text shown -> what was saved (the line without its
-- stamp, when it arrived, its event), so a later save keeps its first time and stays player chat
Chat.restoredLines = Chat.restoredLines or {}

-- The line without the timestamp in front: FlareUI's own (Better Timestamps) or Blizzard's, which
-- was made from when the line arrived (or the second before)
local function StripStamp(msg, at)
    local flare = msg:match("^" .. TIMESTAMP_COLOR .. "<[^>]*>|r (.*)$")
    if flare then return flare end
    local fmt = StampFormats()
    if fmt and at then
        for when = at, at - 1, -1 do
            local stamp = CachedDate(fmt, when)
            if msg:sub(1, #stamp) == stamp then return msg:sub(#stamp + 1) end
        end
    end
    return msg
end

-- A window's last HISTORY_LINES player-chat lines, added to out with when each arrived (server time)
local function ReadHistoryLines(cf, tags, out)
    local num = cf:GetNumMessages()
    local buffer = cf.historyBuffer
    local offset = time() - GetTime()   -- the buffer keeps GetTime(); saved lines keep the clock
    -- never earlier than the line before it, so the window's own order holds
    local last = 0
    for j = math_max(1, num - (HISTORY_LINES - 1)), num do
        local msg, r, g, b, id, _, _, event = cf:GetMessageInfo(j)
        -- secret lines are skipped; canaccessvalue first, before any other test
        if canaccessvalue(msg) and type(msg) == "string" then
            local back = Chat.restoredLines[msg]
            local raw, at
            if back then
                raw, at, event = back.raw, back.at, back.event
            elseif canaccessvalue(event) and PLAYER_CHAT[event] then
                -- GetMessageInfo counts from the oldest line, the buffer from the newest
                local entry = buffer and buffer:GetEntryAtIndex(num - j + 1)
                local when = entry and entry.timestamp
                at = (canaccessvalue(when) and type(when) == "number") and math.floor(when + offset + 0.5) or time()
                raw = StripStamp(msg, at)
            end
            if raw then raw = SafeHistoryLine(raw, tags) end
            if raw then
                if at < last then at = last end
                last = at
                if not canaccessallvalues(r, g, b) then r, g, b = 1, 1, 1 end
                -- the line, its colour, its chat type (Blizzard recolours by type), when, its event
                local line = { raw, r or 1, g or 1, b or 1, (canaccessvalue(id) and type(id) == "number") and id or false, at, event }
                out[#out + 1] = { line = line, at = at, order = #out + 1 }
            end
        end
    end
    return out
end

function Chat:SaveHistory()
    local db = GetDb()
    if not db or not db.saveHistory then
        ns.CharDB().chatHistory = nil
        return
    end

    local success, err = pcall(function()
        local history = {}
        local tags = BattleTagsByToken()
        for i = 1, NUM_CHAT_WINDOWS do
            local cf = _G["ChatFrame"..i]
            -- not the Combat Log: it rebuilds itself
            if cf and cf ~= _G.ChatFrame2 then
                local lines = ReadHistoryLines(cf, tags, {})
                -- the main window also keeps the open whisper windows' lines: those windows don't
                -- come back after a reload (Blizzard never saves them). In "both" mode the whispers
                -- are in the main window already.
                if i == 1 and C_CVar.GetCVar("whisperMode") == "popout" then
                    for _, name in ipairs(CHAT_FRAMES or {}) do
                        local wf = _G[name]
                        if wf and wf.isTemporary and wf.inUse ~= false and not wf:IsForbidden()
                                and (wf.chatType == "WHISPER" or wf.chatType == "BN_WHISPER") then
                            ReadHistoryLines(wf, tags, lines)
                        end
                    end
                    -- in the order they arrived, the newest HISTORY_LINES
                    table.sort(lines, function(x, y)
                        if x.at ~= y.at then return x.at < y.at end
                        return x.order < y.order
                    end)
                end
                -- the same line twice (same text, same second) is kept once
                local messages, prev = {}, nil
                for k = math_max(1, #lines - (HISTORY_LINES - 1)), #lines do
                    local line = lines[k].line
                    if not (prev and prev[1] == line[1] and prev[6] == line[6]) then messages[#messages + 1] = line end
                    prev = line
                end
                if #messages > 0 then history[i] = messages end
            end
        end
        ns.CharDB().chatHistory = history
    end)

    if not success then
        print(string_format("|cffff0000FlareUI Chat:|r Failed to save chat history: %s", tostring(err)))
    end
end

-- Filled in above what has arrived since login, newest saved line first, so the window reads in
-- order: the last session, then this one. (Older saves hold plain strings, coloured in the text.)
function Chat:RestoreHistory()
    local db = GetDb()
    local history = ns.CharDB().chatHistory
    if not (db and db.saveHistory and history) then return end
    for i, msgs in pairs(history) do
        local cf = _G["ChatFrame"..i]
        if cf and cf ~= _G.ChatFrame2 and cf.BackFillMessage then
            -- where the last session ends and this one begins: filled in first, so the saved lines go
            -- above it (it has no chat event, so it is never saved itself)
            if #msgs > 0 then
                cf:BackFillMessage("|cff808080---------- " .. L["Saved history ends here"] .. " ----------|r")
            end
            for j = #msgs, 1, -1 do
                local line = msgs[j]
                if type(line) == "table" and type(line[1]) == "string" then
                    local raw, at = line[1], tonumber(line[6])
                    local text = raw
                    if at then
                        -- stamped again, in today's format, with the time it arrived
                        local fmt = StampFormats()
                        if db.betterTimestamps then
                            text = GetTimestamp(at) .. raw
                        elseif fmt then
                            text = CachedDate(fmt, at) .. raw
                        end
                        Chat.restoredLines[text] = { raw = raw, at = at, event = line[7] }
                    end
                    cf:BackFillMessage(text, line[2], line[3], line[4], line[5] or nil)
                elseif type(line) == "string" then
                    cf:BackFillMessage(line)
                end
            end
        end
    end
end

function Chat:RefreshAll()
    local db = GetDb()
    if not db or not db.enabled then return end
    Chat:Apply(db)
    HandleCombatLog(db)
    Chat:SetupImprovements()
    Chat:UpdateFilters()

    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        if cf then Chat:ShowChatFrame(cf, db) end
    end
    Chat:RefreshMeterTab()   -- its hover watch follows a changed Visibility
    -- the meter takes the skin's size and place: its own pass at login may have come first
    if ns.DamageMeter and ns.DamageMeter.Refresh then ns.DamageMeter:Refresh() end
end

--------------------------------------------------
-- 21. SETTINGS PREVIEW SAMPLE
-- A chat window for the settings panel's picture, drawn by this module's own look: the skin, tab
-- row, header buttons and edit box, and lines from fake senders put through the same rewriting as
-- real ones. A plain frame: no events, no mouse, Blizzard's chat untouched.
--------------------------------------------------
Chat.sampleLook = {
    TEXT_WIDTH = 250, TEXT_HEIGHT = 190,   -- the window's text area (narrow and tall: the preview shows it near its real size)
    EDIT_HEIGHT = 32,                      -- Blizzard's edit box
    TAB_BAR_MARGIN = 20, TAB_BUTTON_ROOM = 30,
    COPY_SIZE = 18,
    -- race file, sex (2 male, 3 female), class file, level
    senders = {
        Thrallbro = { "Orc", 2, "WARRIOR", 60 },
        Mankrikfan = { "Tauren", 2, "DRUID", 24 },
        Tankyboi = { "Dwarf", 2, "PALADIN", 19 },
        Leeroy = { "Human", 2, "PALADIN", 60 },
        Healbot = { "NightElf", 3, "PRIEST", 58 },
    },
}

-- The tab row as UpdateCustomTabs draws it: tabs = { { text, selected }, ... } left to right on strip
function Chat.DrawSampleTabs(strip, tabs, db)
    strip.ftTabs = strip.ftTabs or {}
    local path, size, flags = GetFontData(db.tabFont)
    local prev
    for i, tab in ipairs(tabs) do
        local btn = strip.ftTabs[i]
        if not btn then
            btn = CreateFrame("Frame", nil, strip)
            btn:SetHeight(24)
            btn.Text = btn:CreateFontString(nil, "OVERLAY")
            strip.ftTabs[i] = btn
        end
        ns.SetFont(btn.Text, path, size, flags)
        ns.ApplyShadow(btn.Text, db.tabFont)
        btn.Text:SetText(tab[1])
        btn:SetWidth(btn.Text:GetStringWidth() + 14)
        btn.Text:ClearAllPoints()
        btn.Text:SetPoint("CENTER", btn, "CENTER", 0, TAB_TEXT_Y)
        Chat.PaintTab(btn.Text, tab[2])
        btn:ClearAllPoints()
        if prev then btn:SetPoint("LEFT", prev, "RIGHT", 4, 0) else btn:SetPoint("LEFT", strip, "LEFT", 0, 0) end
        btn:Show()
        prev = btn
    end
    for i = #tabs + 1, #strip.ftTabs do strip.ftTabs[i]:Hide() end
end

-- The sample window's size: its text area with the skin's padding and the tab row
function Chat.SampleWindowSize()
    local look = Chat.sampleLook
    return look.TEXT_WIDTH + 2 * TEXT_PADDING, look.TEXT_HEIGHT + 2 * TEXT_PADDING + HEADER_HEIGHT
end

-- The sample's tabs: General, the Combat Log unless hidden, Trade, and the Meter tab while it is
-- available. meterSelected: the damage meter's sample, on its Meter tab.
function Chat.SampleTabs(db, meterSelected)
    local tabs = { { L["General"], not meterSelected } }
    if not db.hideCombatLog then tabs[#tabs + 1] = { L["Combat Log"], false } end
    tabs[#tabs + 1] = { _G.TRADE or L["Trade"], false }
    if meterSelected or MeterTabAvailable() then tabs[#tabs + 1] = { L["Meter"], meterSelected and true or false } end
    return tabs
end

-- A skinned window with its tab row, separator and header buttons (CreateOrGetSkinFrame,
-- CreateCustomTabBar, StyleHeaderButtons). Also the damage meter's Meter tab sample.
function Chat.CreateSampleWindow(parent)
    local skin = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    skin:EnableMouse(false)
    local line = skin:CreateTexture(nil, "OVERLAY")
    line:SetTexture(SEPARATOR)
    line:SetHeight(8)
    -- where CreateOrGetSkinFrame puts it, measured from the skin rather than the text
    line:SetPoint("TOPLEFT", skin, "TOPLEFT", BORDER_INSET + 2, -HEADER_HEIGHT)
    line:SetPoint("TOPRIGHT", skin, "TOPRIGHT", -(BORDER_INSET + 2), -HEADER_HEIGHT)
    skin.Separator = line
    local strip = CreateFrame("Frame", nil, skin)
    strip:SetHeight(24)
    strip:SetClipsChildren(true)   -- the real bar is a scroll frame: what doesn't fit is cut off
    skin.TabStrip = strip
    skin.Buttons = {}
    for _, key in ipairs(HEADER_ORDER) do
        local btn = CreateFrame("Frame", nil, skin)
        local side = key == "volume" and 28 or 22
        btn:SetSize(side, side)
        btn:SetScale(HEADER_ICON_SCALE)
        skin.Buttons[key] = btn
    end
    return skin
end

-- Laid out at width x height with the chat's current settings; tabs as for Chat.DrawSampleTabs
function Chat.DrawSampleWindow(skin, db, width, height, tabs)
    skin:SetSize(width, height)
    Chat.WindowBackdrop(skin, db)
    local icons = { social = ICON_SOCIAL, channel = ICON_CHANNELS, menu = ICON_MENU, volume = Chat.VolumeIcon() }
    local shown = 0
    for key, btn in pairs(skin.Buttons) do
        if HeaderButtonShown(db, key) then
            shown = shown + 1
            Chat.HeaderIcon(btn, icons[key])
            btn:ClearAllPoints()
            btn:SetPoint("TOPRIGHT", skin, "TOPRIGHT", HeaderButtonX(db, key), HEADER_ICON_Y)
            btn:Show()
        else
            btn:Hide()
        end
    end
    -- room for the header buttons, as UpdateCustomTabs leaves it
    local look = Chat.sampleLook
    local strip = skin.TabStrip
    strip:ClearAllPoints()
    strip:SetPoint("TOPLEFT", skin, "TOPLEFT", 10, 0)
    strip:SetPoint("TOPRIGHT", skin, "TOPRIGHT", -look.TAB_BAR_MARGIN - shown * look.TAB_BUTTON_ROOM, 0)
    Chat.DrawSampleTabs(strip, tabs, db)
    skin:Show()
end

-- One fake line as Blizzard's chat would print it, then through FlareUI's rewriting (RewriteStoredLine
-- and the sender name filter), with the sender's icons known instead of read from a GUID
function Chat.SampleLine(db, spec, size)
    local look = Chat.sampleLook
    local chatType, who, text = spec[1], spec[2], spec[3]
    local at = time() - (spec.ago or 0)
    local sender = look.senders[who]
    local key = _G[Lines.getKeys[chatType]]
    if type(key) ~= "string" then key = "%s: " end
    text = text:gsub("%%", "%%%%")
    local body
    if NPC_EVENTS[chatType] or not sender then
        body = string_format(key .. text, who, who)
    else
        local name = who
        local info = ChatTypeInfo[spec.info or chatType]
        local color = C_ClassColor.GetClassColor(sender[3])
        if info and info.colorNameByClass and color then name = color:WrapTextInColorCode(name) end
        name = Lines.DressName(db, name, sender[3], sender[4])
        local link = "|Hplayer:" .. who .. ":0:" .. chatType .. "|h[" .. name .. "]|h"
        body = string_format(key .. text, link)
    end
    if spec.channel then
        body = "|Hchannel:channel:" .. spec.channel .. "|h[" .. spec.channel .. ". " .. spec.channelName .. "]|h " .. body
    end
    local fmt = StampFormats()
    local blizzardStamp = fmt and BetterDate(fmt, at) or ""

    -- the same switches RewriteStoredLine checks before it changes anything
    local sayTag = chatType == "SAY" and db.formatPlayer and (db.shortChannels and SHORT_SAY_TAG or SAY_TAG)
    local senderIcons = db.raceIcons or db.classIcons
    if not (sayTag or db.shortChannels or db.formatPlayer or db.formatNPC or db.betterTimestamps or senderIcons
            or db.linkIcons or db.whisperMarkers) then
        return blizzardStamp .. body
    end
    local stamp, rest = "", blizzardStamp .. body
    if db.betterTimestamps or sayTag then stamp, rest = blizzardStamp, body end
    local icons = ""
    if senderIcons and sender then
        icons = Lines.IconMarkup(sender[1], sender[2], sender[3], size, db.raceIcons, db.classIcons)
    end
    return Lines.Build(db, stamp, rest, chatType, { [2] = who }, size, sayTag, icons, at)
end

-- The lines, oldest first: chat type, sender, text; channels also their number, name and colour key
function Chat.SampleLines()
    local itemName = C_Item.GetItemNameByID and C_Item.GetItemNameByID(2589) or L["Linen Cloth"]
    local linen = "|cffffffff|Hitem:2589::::::::1:::::::::|h[" .. itemName .. "]|h|r"
    return {
        { "CHANNEL", "Thrallbro", L["WTB %s x20, paying well"]:format(linen), channel = 2, channelName = L["Trade - City"], info = "CHANNEL2", ago = 300 },
        { "SAY", "Mankrikfan", L["anyone know where Mankrik's wife is?"], ago = 240 },
        { "CHANNEL", "Tankyboi", L["LF1M tank for Deadmines, must bring snacks"], channel = 4, channelName = L["LookingForGroup"], info = "CHANNEL4", ago = 180 },
        { "MONSTER_SAY", L["Kobold Tunneler"], L["You no take candle!"], ago = 120 },
        { "GUILD", "Leeroy", L["Alright chums, let's do this."], ago = 60 },
        { "WHISPER", "Healbot", L["inv pls, I have water"], ago = 20 },
        { "WHISPER_INFORM", "Healbot", L["omw, don't pull yet"], ago = 0 },
    }
end

function Chat.CreateSample(parent, kind)
    if kind ~= nil and kind ~= "chat" then return nil end
    local f = CreateFrame("Frame", nil, parent)
    f.fuiSample = true
    f:EnableMouse(false)
    f.Window = Chat.CreateSampleWindow(f)
    f.Text = CreateFrame("Frame", nil, f.Window)
    f.Lines = {}
    for i = 1, 7 do
        local fs = f.Text:CreateFontString(nil, "ARTWORK")
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        f.Lines[i] = fs
    end
    f.Copy = f.Text:CreateTexture(nil, "OVERLAY")
    f.Copy:SetTexture(COPY_ICON)
    f.Copy:SetAlpha(COPY_ALPHA)
    -- the edit box: its backdrop under its text, as StyleEditBox has it
    f.Edit = CreateFrame("Frame", nil, f)
    f.Edit:SetFrameLevel(f:GetFrameLevel() + 10)   -- over the lines, as the opened box is
    f.Edit.Bg = CreateFrame("Frame", nil, f.Edit, "BackdropTemplate")
    f.Edit.Bg:SetPoint("TOPLEFT", f.Edit, "TOPLEFT", -2, 2)
    f.Edit.Bg:SetPoint("BOTTOMRIGHT", f.Edit, "BOTTOMRIGHT", 2, -2)
    f.Edit.Bg:SetFrameLevel(f.Edit:GetFrameLevel() + 1)
    local textHolder = CreateFrame("Frame", nil, f.Edit)
    textHolder:SetAllPoints()
    textHolder:SetFrameLevel(f.Edit:GetFrameLevel() + 2)
    f.Edit.Header = textHolder:CreateFontString(nil, "OVERLAY")
    f.Edit.Header:SetPoint("LEFT", f.Edit, "LEFT", 15, 0)   -- Blizzard's header inset
    f.Edit.Typed = textHolder:CreateFontString(nil, "OVERLAY")
    f.Edit.Typed:SetPoint("LEFT", f.Edit.Header, "RIGHT", 0, 0)
    f.Edit.Typed:SetPoint("RIGHT", f.Edit, "RIGHT", -10, 0)
    f.Edit.Typed:SetJustifyH("LEFT")
    f.Edit.Typed:SetWordWrap(false)
    f:Hide()
    return f
end

function Chat.DrawSample(f)
    local db = GetDb()
    if not db then f:Hide() return 0, 0 end
    local look = Chat.sampleLook
    local width, height = Chat.SampleWindowSize()

    -- Edit Box Position: outside the window it is EDIT_BOX_GAP away, its backdrop 2 px past it
    local position = db.editBoxPosition or "inside"
    local outside = (position == "above" or position == "below") and (EDIT_BOX_GAP + 2 + look.EDIT_HEIGHT + 2) or 0
    local top = position == "above" and outside or 0

    f.Window:ClearAllPoints()
    f.Window:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -top)
    Chat.DrawSampleWindow(f.Window, db, width, height, Chat.SampleTabs(db))

    local text = f.Text
    text:ClearAllPoints()
    text:SetPoint("TOPLEFT", f.Window, "TOPLEFT", TEXT_PADDING, -(TEXT_PADDING + HEADER_HEIGHT))
    text:SetSize(look.TEXT_WIDTH, look.TEXT_HEIGHT)

    f.Copy:SetShown(db.copyButton and true or false)
    f.Copy:ClearAllPoints()
    f.Copy:SetSize(look.COPY_SIZE, look.COPY_SIZE)
    f.Copy:SetPoint("TOPRIGHT", text, "TOPRIGHT", -2, -2)

    -- the lines, newest at the bottom, in the chat font; over an open edit box inside the window they
    -- move up as EditExtras.PushFor moves them
    local path, size, flags = Chat:MessageFont(nil, db)
    local spacing = db.increaseLineHeight and EXTRA_LINE_SPACING or 0
    local up = position == "inside" and (30 + EditExtras.PUSH_GAP) or 0
    for _, fs in ipairs(f.Lines) do
        ns.SetFont(fs, path, size, flags)
        ns.ApplyShadow(fs, db.chatFont)
        fs:SetWidth(look.TEXT_WIDTH)
    end
    local iconSize = Lines.IconSize(f.Lines[1])
    local specs = Chat.SampleLines()
    local used, prev = up, nil
    for i = #specs, 1, -1 do
        local fs, spec = f.Lines[i], specs[i]
        local info = ChatTypeInfo[spec.info or spec[1]] or ChatTypeInfo.SAY
        fs:SetText(Chat.SampleLine(db, spec, iconSize))
        if info then fs:SetTextColor(info.r, info.g, info.b) end
        fs:ClearAllPoints()
        if prev then
            fs:SetPoint("BOTTOMLEFT", prev, "TOPLEFT", 0, spacing)
        else
            fs:SetPoint("BOTTOMLEFT", text, "BOTTOMLEFT", 0, up)
        end
        used = used + fs:GetStringHeight() + (prev and spacing or 0)
        -- a line that would stick out of the top is left out, as the chat scrolls it away
        fs:SetShown(used <= look.TEXT_HEIGHT)
        prev = fs
    end

    local eb = f.Edit
    eb:ClearAllPoints()
    eb:SetHeight(look.EDIT_HEIGHT)
    if position == "below" then
        eb:SetPoint("TOPLEFT", f.Window, "BOTTOMLEFT", 2, -(EDIT_BOX_GAP + 2))
        eb:SetPoint("TOPRIGHT", f.Window, "BOTTOMRIGHT", -2, -(EDIT_BOX_GAP + 2))
    elseif position == "above" then
        eb:SetPoint("BOTTOMLEFT", f.Window, "TOPLEFT", 2, EDIT_BOX_GAP + 2)
        eb:SetPoint("BOTTOMRIGHT", f.Window, "TOPRIGHT", -2, EDIT_BOX_GAP + 2)
    else
        eb:SetPoint("TOPLEFT", text, "BOTTOMLEFT", -2, 30)
        eb:SetPoint("TOPRIGHT", text, "BOTTOMRIGHT", 2, 30)
    end
    Chat.EditBoxBackdrop(eb.Bg, db)
    local ePath, eSize, eFlags = GetFontData(db.editBoxFont)
    for _, fs in ipairs({ eb.Header, eb.Typed }) do
        ns.SetFont(fs, ePath, eSize, eFlags)
        ns.ApplyShadow(fs, db.editBoxFont)
    end
    local say = ChatTypeInfo.SAY
    eb.Header:SetText(_G.CHAT_SAY_SEND or L["Say: "])
    eb.Typed:SetText(L["brb, buying more snacks"])
    if say then
        eb.Header:SetTextColor(say.r, say.g, say.b)
        eb.Typed:SetTextColor(say.r, say.g, say.b)
    end
    eb:Show()

    f:SetSize(width, height + outside)
    f:Show()
    return width, height + outside
end
