local _, ns = ...

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
local ChatTypeInfo = ChatTypeInfo
local BetterDate = TimeUtil.BetterDate
local canaccessallvalues = canaccessallvalues
local LSM = LibStub("LibSharedMedia-3.0")

-- The border picked in the options; a name LibSharedMedia no longer knows falls back to the default.
local DEFAULT_BORDER = "FlareUI Thin"
local function GetBorderFile(db)
    local name = db and db.borderTexture
    if not (name and LSM:IsValid("border", name)) then name = DEFAULT_BORDER end
    return LSM:Fetch("border", name)
end
local MenuUtil = MenuUtil
local FCF_DockUpdate = FCF_DockUpdate
local PanelTemplates_TabResize = PanelTemplates_TabResize

--------------------------------------------------
-- 3. CONSTANTS & ASSETS
--------------------------------------------------
local NUM_CHAT_WINDOWS = Constants.ChatFrameConstants.MaxChatWindows
local NPC_COLOR = "|cffFFB033"
local TIMESTAMP_COLOR = "|cff00B2FF"

local ICON_MUTE   = "Interface\\AddOns\\FlareUI\\Media\\Icons\\Volume-Speaker-Mute.tga"
local ICON_LOW    = "Interface\\AddOns\\FlareUI\\Media\\Icons\\Volume-Speaker-Low.tga"
local ICON_MEDIUM = "Interface\\AddOns\\FlareUI\\Media\\Icons\\Volume-Speaker-Medium.tga"
local ICON_HIGH   = "Interface\\AddOns\\FlareUI\\Media\\Icons\\Volume-Speaker-High.tga"

local ICON_CHANNELS = "Interface\\AddOns\\FlareUI\\Media\\Icons\\ChatChannels.tga"
local ICON_MENU     = "Interface\\AddOns\\FlareUI\\Media\\Icons\\ChatOptions.tga"
local ICON_SOCIAL   = "Interface\\AddOns\\FlareUI\\Media\\Icons\\ChatSocial.tga"

local SEPARATORS = {
    ["Solid"]    = nil,
    ["Blizzard"] = "Interface\\Common\\UI-TooltipDivider-Transparent",
}

--------------------------------------------------
-- 4. HELPERS
--------------------------------------------------

local function GetDb()
    if not ns.db or not ns.db.profile or not ns.db.profile.chat then
        return nil
    end
    return ns.db.profile.chat
end

local function GetTimestamp()
    local db = GetDb()
    if not db then return "" end
    local format = C_CVar.GetCVar("showTimestamps")

    if format == "none" and not db.betterTimestamps then return "" end
    if format == "none" then format = "%H:%M" end

    local timeStr = BetterDate(format, time())

    if db.betterTimestamps then
        return string_format("%s<%s>|r ", TIMESTAMP_COLOR, timeStr)
    else
        return string_format("[%s] ", timeStr)
    end
end

local function GetFontData(fontDB)
    local face  = fontDB and fontDB.face or "Friz Quadrata TT"
    local size  = fontDB and fontDB.size or 14
    local flags = fontDB and fontDB.flags or "OUTLINE"
    if flags == "NONE" then flags = "" end
    local path = LSM:Fetch("font", face) or "Fonts\\FRIZQT__.TTF"
    return path, size, flags
end

local function ApplyFontEffects(fontString, dbEntry)
    if not fontString then return end
    if dbEntry.enableShadow then
        fontString:SetShadowColor(0, 0, 0, 1)
        fontString:SetShadowOffset(1, -1)
    else
        fontString:SetShadowColor(0, 0, 0, 0)
        fontString:SetShadowOffset(0, 0)
    end
    if dbEntry.useCustomColor and dbEntry.color then
        local c = dbEntry.color
        fontString:SetTextColor(c.r, c.g, c.b, c.a)
    end
end

local function LightenColor(r, g, b, factor)
    return math_min(1, r + factor), math_min(1, g + factor), math_min(1, b + factor)
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

    -- Hide the ButtonFrame (contains minimize/close buttons on docked frames)
    if chatFrame.buttonFrame then
        chatFrame.buttonFrame:Hide()
        chatFrame.buttonFrame:SetAlpha(0)
        if chatFrame.buttonFrame.SetScript then
            chatFrame.buttonFrame:SetScript("OnShow", function(self) self:Hide() end)
        end
    end

    -- Also hide individual button frame textures
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

local function UpdateScrollToBottomVisibility(chatFrame)
    if not chatFrame or chatFrame:IsForbidden() then return end
    local btn = chatFrame.ScrollToBottomButton
    if not btn then return end
    local offset = chatFrame.GetScrollOffset and chatFrame:GetScrollOffset() or 0
    if offset == 0 then btn:Hide() else btn:Show() end
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
    -- NOTE: AddMessage hook is in SetupAutoHide() to avoid double-hooking
    UpdateScrollToBottomVisibility(chatFrame)
end

local function StyleButtonFrame()
    if not NUM_CHAT_WINDOWS then return end
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

local function DisableQuickJoinToasts()
    if QuickJoinToastButton then
        QuickJoinToastButton:UnregisterAllEvents()
        if QuickJoinToastButton.Toast then
            QuickJoinToastButton.Toast:Hide()
            QuickJoinToastButton.Toast:SetAlpha(0)
            QuickJoinToastButton.Toast:EnableMouse(false)
            hooksecurefunc(QuickJoinToastButton, "ShowToast", function(self) self.Toast:Hide() end)
        end
    end
end

--------------------------------------------------
-- 5. FILTERS
--------------------------------------------------
-- Shortened channel names: chat type -> the short tag and the channel link keyword Blizzard
-- uses for it (raid warnings have no link). Numbered channels become just their number.
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

-- The tag Better Player Names puts in front of the name, or "" when Shortened Channel Names is off
local function ShortTag(chatType)
    local db = GetDb()
    local tag = db and db.shortChannels and SHORT_TAGS[chatType]
    if not tag then return "" end
    if tag[2] then return string_format("|Hchannel:%s|h[%s]|h ", tag[2], tag[1]) end
    return "[" .. tag[1] .. "] "
end

local function NPCFilter(self, event, msg, sender, ...)
    if sender and canaccessallvalues(msg, sender) then
        local timestamp = GetTimestamp()
        local formatted = string_format("%s" .. NPC_COLOR .. "[%s]|r %s", timestamp, sender, msg)
        if event == "CHAT_MSG_MONSTER_WHISPER" then
             formatted = string_format("%s" .. NPC_COLOR .. "[%s] whispers|r %s", timestamp, sender, msg)
        end
        local info = ChatTypeInfo["MONSTER_SAY"]
        if event == "CHAT_MSG_MONSTER_YELL" then info = ChatTypeInfo["MONSTER_YELL"] end
        if event == "CHAT_MSG_MONSTER_WHISPER" then info = ChatTypeInfo["MONSTER_WHISPER"] end
        self:AddMessage(formatted, info.r, info.g, info.b)
        return true
    end
end

local function PlayerFilter(self, event, msg, sender, ...)
    -- Exclude whispers: WHISPER_INFORM uses recipient as sender, so our formatting shows wrong name.
    if event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_WHISPER_INFORM" then
        return false
    end
    if sender and canaccessallvalues(msg, sender) then
        local lineID = select(9, ...)
        local guid = select(10, ...)
        local classColorHex = "ffffffff"

        -- Protected API call - may fail during Midnight beta restrictions
        if guid then
            local success, _, classFilename = pcall(GetPlayerInfoByGUID, guid)
            if success and classFilename then
                local c = C_ClassColor.GetClassColor(classFilename)
                if c then
                    local colorSuccess, hexColor = pcall(c.GenerateHexColor, c)
                    if colorSuccess and hexColor then
                        classColorHex = hexColor
                    end
                end
            end
        end

        local displayName = string_gsub(sender, "%-[^|]+", "")
        local link = string_format("|Hplayer:%s:%s|h[%s]|h", sender, lineID or "0", displayName)
        local infoType = "SAY"
        if event == "CHAT_MSG_YELL" then infoType = "YELL"
        elseif event == "CHAT_MSG_GUILD" then infoType = "GUILD"
        elseif event == "CHAT_MSG_OFFICER" then infoType = "OFFICER"
        elseif event == "CHAT_MSG_PARTY" then infoType = "PARTY"
        elseif event == "CHAT_MSG_PARTY_LEADER" then infoType = "PARTY_LEADER"
        elseif event == "CHAT_MSG_RAID" then infoType = "RAID"
        elseif event == "CHAT_MSG_RAID_LEADER" then infoType = "RAID_LEADER"
        elseif event == "CHAT_MSG_RAID_WARNING" then infoType = "RAID_WARNING"
        elseif event == "CHAT_MSG_WHISPER" then infoType = "WHISPER"
        elseif event == "CHAT_MSG_WHISPER_INFORM" then infoType = "WHISPER_INFORM"
        end

        local formatted = string_format("%s%s|c%s%s|r %s", GetTimestamp(), ShortTag(infoType), classColorHex, link, msg)
        local info = ChatTypeInfo[infoType]
        if not info then info = { r=1, g=1, b=1 } end
        self:AddMessage(formatted, info.r, info.g, info.b)
        return true
    end
end

--------------------------------------------------
-- 6. IMPROVEMENTS
--------------------------------------------------
-- Shortened channel names on the lines Blizzard formats itself: "[2. Trade - City]" -> "[2]",
-- "[Guild]" -> "[G]". Blizzard adds the channel after the message filters run, so the line is
-- changed once it is stored: a post-hook on AddMessage rewrites the newest history entry, the way
-- ScrollingMessageFrame's own TransformMessages does. Replacing AddMessage or the CHAT_*_GET
-- strings instead would taint Blizzard's handler and break whispers. Secret lines pass untouched.
local function ShortenStoredLine(chatFrame, message, _, _, _, _, _, _, event)
    local db = GetDb()
    if not (db and db.shortChannels and event) or not canaccessallvalues(message) then return end
    local chatType = event:sub(10)   -- after "CHAT_MSG_"
    local short
    if chatType == "CHANNEL" or chatType == "COMMUNITIES_CHANNEL" then
        short = string_gsub(message, "(|Hchannel:channel:(%d+)|h)%[[^%]]*%]|h", "%1[%2]|h", 1)
    elseif SHORT_TAGS[chatType] then
        local tag = SHORT_TAGS[chatType][1]
        if SHORT_TAGS[chatType][2] then
            short = string_gsub(message, "(|Hchannel:[^|]+|h)%[[^%]]*%]|h", "%1[" .. tag .. "]|h", 1)
        elseif CHAT_MSG_RAID_WARNING then
            local long = "[" .. CHAT_MSG_RAID_WARNING .. "]"
            local s, e = message:find(long, 1, true)
            if s then short = message:sub(1, s - 1) .. "[" .. tag .. "]" .. message:sub(e + 1) end
        end
    end
    if not short or short == message then return end

    local entry = chatFrame.historyBuffer and chatFrame.historyBuffer:GetEntryAtIndex(1)
    if entry and canaccessallvalues(entry.message) and entry.message == message then
        entry.message = short
        chatFrame:MarkDisplayDirty()
    end
end

local shortHooked = {}   -- kept here, not as a field on Blizzard's frames
local function HookChannelNames()
    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame" .. i]
        if frame and not shortHooked[frame] then
            hooksecurefunc(frame, "AddMessage", ShortenStoredLine)
            shortHooked[frame] = true
        end
    end
end

-- Chat bubbles off inside instances and back outside. The player's own values are kept in the
-- account data while hidden, so a reload or logout inside the instance still restores them.
local BUBBLE_CVARS = { "chatBubbles", "chatBubblesParty" }

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
        for cvar, value in pairs(saved) do C_CVar.SetCVar(cvar, value) end
        global.hiddenBubbles = nil
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

-- Blizzard hides these three buttons together with ChatFrame1ButtonFrame, which we keep hidden. An
-- OnHide hook re-shows them. Never replace their Hide method instead: every Blizzard call to :Hide()
-- would then run addon code and carry our taint into whatever called it.
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
                if db[entry.key] then return end          -- the user asked for it to be hidden
                if InCombatLockdown() then return end
                self:Show()
            end)
        end
    end
    DisableQuickJoinToasts()
end

-- ChatFrameMenuButton, ChatFrameChannelButton and QuickJoinToastButton are one set of frames shared
-- by every chat window, so they can only ever sit on one skin: the one being looked at. The selected
-- frame is the usual answer, but a window that has just been opened is selected before it is shown,
-- and parenting the buttons to a hidden skin is what made them vanish until a tab was clicked.
local function VisibleSkinHost()
    local function Usable(cf)
        return cf and not cf:IsForbidden() and cf.FlareUI_Skin and cf:IsShown() and cf
    end

    local host = Usable(SELECTED_CHAT_FRAME) or Usable(ChatFrame1)
    if host then return host end
    for i = 1, NUM_CHAT_WINDOWS do
        host = Usable(_G["ChatFrame" .. i])
        if host then return host end
    end
    return ChatFrame1
end

-- Header buttons sit right to left in this order, packed: a hidden one leaves no gap, so the tab bar
-- (UpdateCustomTabsImmediate) gets its room. The Gamepad UI hides them all: Blizzard hides its own
-- button bar there and its footer prompts replace them.
local HEADER_ORDER = { "volume", "social", "menu", "channel" }
local HEADER_FIRST_X, HEADER_STEP = -25, -35

local function HeaderButtonShown(db, name)
    if ns.IsGamepadUI() then return false end
    if name == "volume" then return db.showVolume and true or false end
    return not db[name .. "Hide"]
end

-- the player's order (dragged on the header), right to left; any key missing from it goes on the end
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
-- HEADER BUTTON ORDER
-- A header button is dragged to another's place, the way the tabs are: a bronze bar under the button
-- it will take the place of follows the cursor, and the drop saves the new order. Blizzard's Chat
-- Menu opens on mouse down, so that press closes it again as the drag starts.
--------------------------------------------------
local HEADER_BLIZZARD = { social = "QuickJoinToastButton", menu = "ChatFrameMenuButton", channel = "ChatFrameChannelButton" }
local headerDrag = { key = nil, header = nil, button = nil, marker = nil, driver = CreateFrame("Frame") }

-- the header's button for key: Blizzard's shared ones sit on the visible skin, the volume button is
-- the skin's own
local function HeaderButtonOf(header, key)
    if key == "volume" then
        for i = 1, NUM_CHAT_WINDOWS do
            local cf = _G["ChatFrame" .. i]
            if cf and cf.FlareUI_Skin == header then return cf.FlareUI_VolumeBtn end
        end
        return nil
    end
    local btn = _G[HEADER_BLIZZARD[key]]
    if btn and btn:GetParent() == header then return btn end
    return nil
end

-- the visible button nearest the cursor along the header
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
        local order = {}
        for _, k in ipairs(old) do if k ~= key then order[#order + 1] = k end end
        local at = tIndexOf(order, target)
        table.insert(order, from < to and at + 1 or at, key)
        db.headerOrder = order
        for i = 1, NUM_CHAT_WINDOWS do
            local cf = _G["ChatFrame" .. i]
            if cf and cf.FlareUI_Skin then Chat:SetupVolumeButton(cf, db) end
        end
        Chat:StyleHeaderButtons()
    end
end

-- plain drag, on the button itself (done once per button)
local function EnableHeaderDrag(btn, key)
    if btn.FlareUI_DragKey then return end
    btn.FlareUI_DragKey = key
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self) StartHeaderDrag(self.FlareUI_DragKey, self:GetParent()) end)
    btn:SetScript("OnDragStop", StopHeaderDrag)
end


function Chat:StyleHeaderButtons(chatFrame)
    if self.isStyling then return end
    self.isStyling = true

    local db = GetDb()
    local target = chatFrame or VisibleSkinHost()
    if not target or not target.FlareUI_Skin then
        target = ChatFrame1
    end
    if not target or not target.FlareUI_Skin then
        self.isStyling = false
        return
    end
    local header = target.FlareUI_Skin

    local function SetupBtn(btn, iconPath, hide, x, y, scale, color, isSocial, key)
        if not btn then return end
        EnableHeaderDrag(btn, key)

        -- Blizzard's own OnShow stays in place: the social button registers for clicks there (and drops
        -- them again in OnHide), so replacing it left the button dead after its first hide / show.
        -- "Hide" is a post-hook instead.
        if not btn.FlareUI_ShowHooked then
            btn.FlareUI_ShowHooked = true
            btn:HookScript("OnShow", function(s) if s.FlareUI_ForceHidden then s:Hide() end end)
        end
        btn.FlareUI_ForceHidden = hide and true or false
        if hide then
            btn:Hide()
            return
        end

        btn:Show()
        -- Parented to the skin rather than UIParent so alpha is inherited: the skin is what
        -- SetChatFrameAlpha fades, and a child follows its parent's effective alpha automatically.
        -- Strata and level are still set explicitly, so this does not change what draws on top.
        btn:SetParent(header)
        btn:ClearAllPoints()
        btn:SetPoint("TOPRIGHT", header, "TOPRIGHT", x or 0, y or 0)
        btn:SetScale(scale or 1)
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

        if not btn.FlareUI_Icon then
            btn.FlareUI_Icon = btn:CreateTexture(nil, "ARTWORK")
            btn.FlareUI_Icon:SetAllPoints()
        end

        btn.FlareUI_Icon:SetTexture(iconPath)
        btn.FlareUI_Icon:SetVertexColor(color.r, color.g, color.b, color.a)
        btn.FlareUI_Icon:Show()

        if not btn.FlareUI_TextureHooked then
            btn.FlareUI_TextureHooked = true
            local function KillTexture(tex) if tex then tex:SetAlpha(0) end end
            Chat:SecureHook(btn, "SetNormalTexture", function(frameParam) KillTexture(frameParam:GetNormalTexture()) end)
            Chat:SecureHook(btn, "SetPushedTexture", function(frameParam) KillTexture(frameParam:GetPushedTexture()) end)
            Chat:SecureHook(btn, "SetHighlightTexture", function(frameParam) KillTexture(frameParam:GetHighlightTexture()) end)
            KillTexture(btn:GetNormalTexture())
            KillTexture(btn:GetPushedTexture())
            KillTexture(btn:GetHighlightTexture())

            -- Hook state changes (like flashing/glowing) to trigger chat fade-in
            if btn.Flash then
                Chat:SecureHookScript(btn.Flash, "OnShow", function()
                    local db = GetDb()
                    if db and db.showOnMessage ~= false then
                        local frameWithButtons = SELECTED_CHAT_FRAME or ChatFrame1
                        if frameWithButtons then
                            Chat:ShowChatFrame(frameWithButtons, db)
                        end
                    end
                end)
            end
        end

        if isSocial then
            if btn.FriendsButton then btn.FriendsButton:SetAlpha(0) end
            if btn.QueueButton then btn.QueueButton:SetAlpha(0) end
            local count = _G[btn:GetName().."FriendCount"] or btn.FriendCount
            if count then count:SetAlpha(0) end
        end

        -- Highlight Logic
        local hR, hG, hB = LightenColor(color.r, color.g, color.b, 0.3)

        btn:SetScript("OnEnter", function()
            btn.FlareUI_Icon:SetVertexColor(hR, hG, hB, color.a)
            if GameTooltip then GameTooltip:Hide() end
            -- Trigger chat frame fade-in when hovering button
            local db = GetDb()
            if db and db.showOnMouse ~= false then
                local frameWithButtons = SELECTED_CHAT_FRAME or ChatFrame1
                if frameWithButtons then
                    Chat:ShowChatFrame(frameWithButtons, db)
                end
            end
        end)

        btn:SetScript("OnLeave", function()
            btn.FlareUI_Icon:SetVertexColor(color.r, color.g, color.b, color.a)
        end)

        btn:SetScript("OnMouseDown", function() btn.FlareUI_Icon:SetPoint("TOPLEFT", 1, -1) end)
        btn:SetScript("OnMouseUp", function() btn.FlareUI_Icon:SetPoint("TOPLEFT", 0, 0) end)
    end

    local cSocial = db.socialColor or {r=1,g=1,b=1,a=1}
    local cChannel = db.channelColor or {r=1,g=1,b=1,a=1}
    local cMenu = db.menuColor or {r=1,g=1,b=1,a=1}

    SetupBtn(_G.QuickJoinToastButton,   ICON_SOCIAL,   not HeaderButtonShown(db, "social"),  HeaderButtonX(db, "social"),  db.socialY,  db.socialScale,  cSocial, true, "social")
    SetupBtn(_G.ChatFrameChannelButton, ICON_CHANNELS, not HeaderButtonShown(db, "channel"), HeaderButtonX(db, "channel"), db.channelY, db.channelScale, cChannel, false, "channel")
    SetupBtn(_G.ChatFrameMenuButton,    ICON_MENU,     not HeaderButtonShown(db, "menu"),    HeaderButtonX(db, "menu"),    db.menuY,    db.menuScale,    cMenu, false, "menu")

    -- The buttons are children of the skin, so their alpha (and their icons' and Flash glows') follows it.
    self.isStyling = false
end

--------------------------------------------------
-- 7. /way MAP PINS
-- "/way 52.3 48.1 [note]" pins the current map; "/way Zone Name 52 48" looks the zone up by name.
--------------------------------------------------
local mapNameCache
local function GetMapIDByName(targetName)
    local target = targetName:lower():match("^%s*(.-)%s*$")
    if target == "" then return nil end
    if not mapNameCache then
        mapNameCache = {}
        for mapID = 1, 4000 do
            local info = C_Map.GetMapInfo(mapID)
            if info and info.name then
                local key = info.name:lower()
                if not mapNameCache[key] then mapNameCache[key] = mapID end
            end
        end
    end
    return mapNameCache[target]
end

local function HandleWay(msg)
    local db = GetDb()
    if not db or not db.enableWay then
        print("|cffff0000FlareUI:|r /way is disabled in the chat options.")
        return
    end

    msg = (msg or ""):match("^%s*(.-)%s*$")
    if msg == "" then
        print("|cff00ff00FlareUI /way usage:|r")
        print("  /way 50.5 40.2            (current zone)")
        print("  /way Elwynn Forest 40 50   (named zone)")
        print("  /way #1429 40 50           (map ID)")
        return
    end

    local zonePart, xStr, yStr = msg:match("^(.*%S)%s+(%d+%.?%d*)%s*[,%s]%s*(%d+%.?%d*)$")
    if not zonePart then xStr, yStr = msg:match("^(%d+%.?%d*)%s*[,%s]%s*(%d+%.?%d*)$") end
    if not xStr or not yStr then
        print("|cffff0000FlareUI:|r Invalid coordinates. Try |cffffff00/way|r for usage.")
        return
    end

    local mapID
    if zonePart then
        if zonePart:match("^#%d+$") then
            mapID = tonumber(zonePart:sub(2))
        else
            mapID = GetMapIDByName(zonePart)
            if not mapID then print("|cffff0000FlareUI:|r Could not find a map named '" .. zonePart .. "'.") return end
        end
    else
        mapID = C_Map.GetBestMapForUnit("player")
    end
    if not mapID then print("|cffff0000FlareUI:|r Could not determine the current map.") return end
    if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(mapID) then
        print("|cffff0000FlareUI:|r Map pins are not allowed on this map.")
        return
    end

    local x, y = tonumber(xStr) / 100, tonumber(yStr) / 100
    if x > 1 or y > 1 then print("|cffff0000FlareUI:|r Coordinates must be between 0 and 100.") return end

    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)

    local mapInfo = C_Map.GetMapInfo(mapID)
    local mapName = mapInfo and mapInfo.name or ("Map #" .. mapID)
    print(string_format("|cff00ff00FlareUI:|r Pin set for %s at %.1f, %.1f", mapName, tonumber(xStr), tonumber(yStr)))
end

--------------------------------------------------
-- 8. COPY CHAT LINKS
-- Web addresses in chat become clickable; clicking opens a small box with the link selected so it
-- can be copied. Chat text can be a secret value in 12.x, so the filter bails out when it is.
--------------------------------------------------
local URL_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_CHANNEL",
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM",
    "CHAT_MSG_SYSTEM",
}

-- %f[%S] is a frontier pattern: it only matches at a non-space boundary, so an address has to start
-- a word rather than being picked up out of the middle of one. Patterns are Chattynator's.
local URL_PATTERNS = {
    "%f[%S](%a[%w+.-]+://%S+)",                  -- http://, https://, ftp://
    "%f[%S](www%.[-%w_%%]+%.%a%a+/%S+)",         -- www.domain.tld/path
    "%f[%S](www%.[-%w_%%]+%.%a%a+)",             -- www.domain.tld
}

local copyFrame

local function ShowCopyBox(url)
    if not copyFrame then
        local f = CreateFrame("Frame", "FlareUI_CopyLink", UIParent, "BackdropTemplate")
        f:SetSize(420, 70)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
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
        label:SetText("Ctrl+C to copy, Esc to close")

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
    copyFrame:Show()
end

-- Blizzard wraps every registered filter in "if canaccessvalue(...) then callback(...) end"
-- (ChatFrameFilters.lua), so a secret message never reaches this function at all and no guard of our
-- own is needed. A message that already carries a hyperlink is left alone.
local function URLFilter(self, event, msg, ...)
    if type(msg) ~= "string" or msg:find("|H") then return false, msg, ... end
    for _, pattern in ipairs(URL_PATTERNS) do
        local replaced = msg:gsub(pattern, "|cff00b2ff|Hflareurl:%1|h[%1]|h|r")
        if replaced ~= msg then msg = replaced end
    end
    return false, msg, ...
end

-- LinkUtil.RegisterLinkHandler asserts if the same link type is registered twice, so this happens
-- once for the session rather than every time the option is switched back on.
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

function Chat:SetupImprovements()
    local db = GetDb()
    if not db then return end

    if db.enableTT and not SLASH_FLARETT1 then
        SLASH_FLARETT1 = "/tt"
        SlashCmdList["FLARETT"] = function(msg)
            if UnitExists("target") and (UnitIsPlayer("target") or UnitCanCooperate("player", "target")) then
                local name, realm = UnitName("target")
                -- Unit identity can be a secret value in restricted content; skip rather than error
                if not canaccessvalue(name) or not name then return end
                if realm and canaccessvalue(realm) and realm ~= "" then name = name .. "-" .. realm end
                ChatFrameUtil.OpenChat("/w " .. name .. " " .. msg)
            end
        end
    end

    if db.enableWay and not SLASH_FLAREWAY1 then
        SLASH_FLAREWAY1 = "/way"
        SlashCmdList["FLAREWAY"] = HandleWay
    end

    if db.extendHistory then
        for i = 1, NUM_CHAT_WINDOWS do if _G["ChatFrame"..i] then _G["ChatFrame"..i]:SetMaxLines(4096) end end
    end

    Chat:SetupCopyLinks()
    HookChannelNames()
    Chat:UpdateInstanceBubbles()
    Chat:StyleHeaderButtons()
    DisableQuickJoinToasts()
    if _G.TextToSpeechButton then _G.TextToSpeechButton:Hide(); _G.TextToSpeechButton:SetScript("OnShow", function(s) s:Hide() end) end
end

function Chat:OpenContextMenu(tabButton, chatFrame)
    -- With the Gamepad UI on, a menu opened from our code registers with Blizzard's gamepad focus
    -- manager in a tainted call and hangs the client; Tab Settings (Y) has the same entries there.
    if ns.IsGamepadUI() then return end

    -- With the gamepad UI on, ShowUIPanel from FlareUI code registers the window with Blizzard's
    -- gamepad focus manager in a tainted call and hangs the client (see Dialog.lua), so the two
    -- entries that open Blizzard windows are left out there; the game menu has both.
    local gamepad = ns.IsGamepadUI()
    MenuUtil.CreateContextMenu(tabButton, function(owner, rootDescription)
        if not gamepad then
            rootDescription:CreateButton(EDIT_MODE or "Edit Mode", function()
                if EditModeManagerFrame then
                    ShowUIPanel(EditModeManagerFrame)
                end
            end)
        end

        rootDescription:CreateButton(RENAME_CHAT_WINDOW, function()
            ns.ShowDialog("FLAREUI_RENAME_CHAT", nil, chatFrame)
        end)

        rootDescription:CreateButton(NEW_CHAT_WINDOW, function()
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

        rootDescription:CreateDivider()

        rootDescription:CreateButton("Chat Settings", function()
            local ACD = LibStub("AceConfigDialog-3.0", true)
            if ACD then
                ACD:SelectGroup("FlareUI", "chat")
                ACD:Open("FlareUI")
            end
        end)

        if not gamepad then
            rootDescription:CreateButton("Filter Settings", function()
                if ChatConfigFrame then ShowUIPanel(ChatConfigFrame) end
            end)
        end

        if chatFrame:GetID() ~= 1 then
            rootDescription:CreateDivider()
            rootDescription:CreateButton(CLOSE_CHAT_WINDOW, function() FCF_Close(chatFrame) end)
        end
    end)
end

-- Blizzard's tab dock stays alive but out of sight: our tab bar replaces it. Off screen with the
-- mouse; in the gamepad UI Blizzard opens the tab settings menu (Y) on the real tab, so there it
-- lies across the chat header instead, full size so Blizzard lays out every tab (the ones past
-- General and Combat Log sit in its scroll strip), invisible and with its tabs deaf to the mouse.
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
        self:SetHorizontalScroll(new)
    end)

    scrollFrame.buttons = {}
    scrollFrame.FlareUI_Child = scrollChild
    chatFrame.FlareUI_TabBar = scrollFrame
    chatFrame.FlareUI_TabChild = scrollChild
end

-- Reordering tabs by drag. The header's tabs are drawn in the order of Blizzard's dock list
-- (GeneralDockManager.DOCKED_CHAT_FRAMES), so a drop moves the window in that list and FCF_SaveDock
-- stores every docked window's position in the game's chat settings - the order survives a reload.
-- The fixed windows cannot move and nothing lands in front of them: General (the dock's primary),
-- which Blizzard requires first, and while it is shown the Combat Log, second - immovable in
-- Blizzard's own chat, whose order the Gamepad UI's LB / RB follow.
local TAB_MARKER_WIDTH, TAB_MARKER_HEIGHT = 2, 16

-- how many windows lead the dock list and stay put
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

-- an order saved before the rule (a tab dragged in front of the Combat Log) is put right
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
-- an unselected tab's text at rest; hovering lifts it to 1
local TAB_IDLE_ALPHA = 0.6

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

-- moves a docked window in front of `before` (or to the end) and saves the new order
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

local function OnTabDragStart(self)
    local scrollFrame = self.scrollFrame
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

    Chat:UpdateCustomTabsImmediate(chatFrame, db)
end

function Chat:UpdateCustomTabsImmediate(chatFrame, db)
    local scrollFrame = chatFrame.FlareUI_TabBar
    local scrollChild = chatFrame.FlareUI_TabChild
    if not scrollFrame or not scrollChild then return end

    -- Count visible buttons for margin calculation
    -- Don't call Show() here - SetupChatButtons handles visibility
    local btnCount = 0
    for _, key in ipairs(HEADER_ORDER) do
        if HeaderButtonShown(db, key) then btnCount = btnCount + 1 end
    end

    local margin = -20 - (btnCount * 30)
    scrollFrame:SetPoint("TOPRIGHT", chatFrame.FlareUI_Skin, "TOPRIGHT", margin, 0)

    for _, btn in ipairs(scrollFrame.buttons) do btn:Hide() end

    local dock = _G.GeneralDockManager
    local dockedFrames = dock and dock.DOCKED_CHAT_FRAMES
    if not dockedFrames then return end

    local prevBtn = nil
    local fontPath, fontSize, fontFlags = GetFontData(db.tabFont)
    local colorDef = db.tabFont.color or {r=1, g=0.8, b=0, a=1}
    local yOffset = db.tabOffsetY or 0
    local totalWidth = 0

    local buttonIndex = 0
    for i, frame in ipairs(dockedFrames) do
        -- Skip combat log if hidden
        if frame == _G.ChatFrame2 and db.hideCombatLog then
            -- skip
        else
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
                    else
                        -- Call Blizzard's tab click handler to switch frames
                        _G.FCF_Tab_OnClick(self.realTab, button)

                        -- Update tabs and smart scroll to show selected tab
                        C_Timer.After(0.01, function()
                            Chat:UpdateCustomTabs(_G.ChatFrame1, db)

                            -- Smart scroll: only adjust if tab is cut off
                            C_Timer.After(0.02, function()
                                if not self:IsShown() or not scrollFrame then return end

                                local left = self:GetLeft()
                                local right = self:GetRight()
                                local scrollLeft = scrollFrame:GetLeft()
                                local scrollRight = scrollFrame:GetRight()

                                if left and right and scrollLeft and scrollRight then
                                    local scroll = scrollFrame:GetHorizontalScroll()
                                    local scrollWidth = scrollFrame:GetWidth()

                                    -- Calculate tab position in scroll child coordinates
                                    local tabLeft = left - scrollLeft + scroll
                                    local tabRight = right - scrollLeft + scroll

                                    -- Only scroll if tab is not fully visible
                                    if tabRight > scroll + scrollWidth then
                                        -- Tab cut off on right - scroll to show it
                                        scrollFrame:SetHorizontalScroll(tabRight - scrollWidth + 10)
                                    elseif tabLeft < scroll then
                                        -- Tab cut off on left - scroll to show it
                                        scrollFrame:SetHorizontalScroll(math.max(0, tabLeft - 10))
                                    end
                                    -- Otherwise keep current scroll position
                                end
                            end)
                        end)
                    end
                end)

                btn:SetScript("OnEnter", function(self)
                    self.Text:SetAlpha(1)
                    if GameTooltip then GameTooltip:Hide() end
                    Chat:ShowChatFrame(chatFrame, db)
                end)

                btn:SetScript("OnLeave", function(self) if not (self.isSelected or self.isFlashing) then self.Text:SetAlpha(TAB_IDLE_ALPHA) end end)
                scrollFrame.buttons[buttonIndex] = btn
            end

            btn.realTab = realTab
            btn.chatFrame = frame

            btn.Text:SetFont(fontPath, fontSize, fontFlags)
            ApplyFontEffects(btn.Text, db.tabFont)

            local tabText = realTab:GetText() or ("Chat " .. tabID)
            btn.Text:SetText(tabText)
            local w = btn.Text:GetStringWidth() + 14
            btn:SetWidth(w)
            btn.Text:ClearAllPoints()
            btn.Text:SetPoint("CENTER", btn, "CENTER", 0, yOffset)

            -- Get the actual selected frame from the dock
            local dock = _G.GeneralDockManager
            local actualSelectedFrame = dock and FCFDock_GetSelectedWindow(dock)
            local isSelected = (actualSelectedFrame == frame)
            btn.isSelected = isSelected

            if isSelected then
                btn.Text:SetTextColor(colorDef.r, colorDef.g, colorDef.b, colorDef.a)
                btn.Text:SetAlpha(1)
            else
                local ic = db.tabInactiveColor or { r = 0.56, g = 0.51, b = 0.46, a = 1 }
                btn.Text:SetTextColor(ic.r, ic.g, ic.b, 1)
                btn.Text:SetAlpha(TAB_IDLE_ALPHA)
                btn.isFlashing = realTab.glow and realTab.glow:IsShown() or nil
                if btn.isFlashing then
                    btn.Text:SetTextColor(1, 0, 0, 1)
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

    scrollChild:SetWidth(math_max(1, totalWidth))
end

function Chat:HideBlizzardTabs()
    if not NUM_CHAT_WINDOWS then return end

    -- Hide Blizzard's tab scroll frame container. In the gamepad UI it stays shown: every tab past
    -- General and Combat Log lives in it, and Tab Settings (Y) opens on the real tab (the dock itself
    -- is invisible there, see ParkDock).
    local dock = _G.GeneralDockManager
    if dock and dock.scrollFrame then
        if not ns.IsGamepadUI() then dock.scrollFrame:Hide() end
        dock.scrollFrame:SetAlpha(0)
    end

    -- Hide overflow button
    if dock and dock.overflowButton then
        dock.overflowButton:Hide()
        dock.overflowButton:SetAlpha(0)
    end

    -- Hide individual tabs. In the gamepad UI they stay shown, only invisible and deaf to the mouse:
    -- Blizzard opens the Tab Settings menu (Y) on the real tab, and a hidden one opens nothing.
    local gamepad = ns.IsGamepadUI()
    for i = 1, NUM_CHAT_WINDOWS do
        local chatFrame = _G["ChatFrame"..i]
        local tab = _G["ChatFrame"..i.."Tab"]
        if tab and chatFrame then
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

function Chat:UpdateTabFonts()
    local db = ns.db.profile.chat
    local font = db.tabFont
    local fontPath, fontSize, fontFlags = GetFontData(font)

    for i = 1, NUM_CHAT_WINDOWS do
        local tab = _G["ChatFrame"..i.."Tab"]
        if tab then
            -- Set Font
            local fs = tab:GetFontString()
            if fs then
                fs:SetFont(fontPath, fontSize, fontFlags)
                if font.enableShadow then
                    fs:SetShadowColor(0, 0, 0, 1)
                    fs:SetShadowOffset(font.shadowX, font.shadowY)
                else
                    fs:SetShadowColor(0, 0, 0, 0)
                end

                if font.useCustomColor then
                    fs:SetTextColor(font.color.r, font.color.g, font.color.b, font.color.a)
                end
            end

            -- Force Resize & Layout
            -- 10 is the padding value Blizzard typically uses
            PanelTemplates_TabResize(tab, 10)
        end
    end

    -- Force Dock Update to rearrange tabs
    FCF_DockUpdate()
end

local EDIT_BOX_GAP = 1   -- px between the chat window's border and an edit box below / above it

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

    -- IM style parks the edit box at 35% alpha between messages (ChatFrameEditBoxMixin:Deactivate);
    -- keep it invisible instead. It lies over the chat's last lines, so while idle it also goes
    -- beneath the chat window (Blizzard parks it at LOW): a click on a link there reaches the link
    -- instead of opening the chat. ActivateChat lifts it back to DIALOG and puts the alpha back.
    -- Never touch its mouse or hook ActivateChat: both stopped Enter from opening the chat. The
    -- Gamepad UI drives the edit box itself and is left alone.
    if not eb.FlareUI_IMHooked then
        eb.FlareUI_IMHooked = true
        local gamepad = ns.IsGamepadUI()
        hooksecurefunc(eb, "Deactivate", function(self)
            if GetCVar("chatStyle") == "im" and not self.isGM then
                self:SetAlpha(0)
                if not gamepad then self:SetFrameStrata("BACKGROUND") end
            end
        end)
        if GetCVar("chatStyle") == "im" and eb ~= ACTIVE_CHAT_EDIT_BOX then
            eb:SetAlpha(0)
            if not gamepad then eb:SetFrameStrata("BACKGROUND") end
        end
    end

    -- Chat > Frame > Edit Box Position. Outside the window the box is as wide as the window's
    -- border and EDIT_BOX_GAP away from it (its backdrop reaches 2 px past the box itself).
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
        -- DIALOG, where the opened box draws (ActivateChat), whatever strata the idle box is parked at
        bg:SetFrameStrata("DIALOG")
        bg:SetFrameLevel(math_max((eb:GetFrameLevel() or 1) - 1, 0))
        bg:SetPoint("TOPLEFT", eb, "TOPLEFT", -2, 2)
        bg:SetPoint("BOTTOMRIGHT", eb, "BOTTOMRIGHT", 2, -2)
    end

    -- Black background inside the chat frame's border (the Border option), in FlareUI's border bronze
    local bgFile   = "Interface\\Buttons\\WHITE8x8"
    local edgeFile = GetBorderFile(db)
    local opacity  = db.editBoxOpacity or 1

    -- the fill stops inside the border, as on the chat window's skin: the Blizzard Tooltip border's
    -- line sits a few px in from the frame edge, and a fill to the edge showed square past it
    local inset = db.borderInset or 4
    bg:SetBackdrop({ bgFile = bgFile, edgeFile = edgeFile, tile = true, tileSize = 16, edgeSize = 16, insets = { left = inset, right = inset, top = inset, bottom = inset } })
    bg:SetBackdropColor(0, 0, 0, opacity)
    bg:SetBackdropBorderColor(ns.BORDER_COLOR.r, ns.BORDER_COLOR.g, ns.BORDER_COLOR.b, 1)

    eb:SetHistoryLines(100)
    eb:SetAltArrowKeyMode(false)

    local path, size, flags = GetFontData(db.editBoxFont)
    eb:SetFont(path, size, flags)
    ApplyFontEffects(eb, db.editBoxFont)
    if eb.header then eb.header:SetFont(path, size, flags); ApplyFontEffects(eb.header, db.editBoxFont) end
end

function Chat:SetupVolumeButton(chatFrame, db)
    if not chatFrame.FlareUI_Skin then return end
    if not HeaderButtonShown(db, "volume") then
        if chatFrame.FlareUI_VolumeBtn then chatFrame.FlareUI_VolumeBtn:Hide() end
        return
    end

    local btn = chatFrame.FlareUI_VolumeBtn
    local function UpdateIcon()
        local vol = tonumber(C_CVar.GetCVar("Sound_MasterVolume")) or 0
        local color = db.volumeColor or { r=1, g=0.82, b=0, a=1 }

        local r, g, b, a = color.r, color.g, color.b, color.a

        -- Highlighting logic:
        if btn and btn:IsMouseOver() then
            r, g, b = LightenColor(r, g, b, 0.3)
        end

        local tex
        if vol <= 0 then tex = ICON_MUTE elseif vol <= 0.3 then tex = ICON_LOW elseif vol <= 0.7 then tex = ICON_MEDIUM else tex = ICON_HIGH end
        if btn then
            btn:SetNormalTexture(tex)
            btn:SetPushedTexture(tex)
            if btn:GetNormalTexture() then btn:GetNormalTexture():SetBlendMode("BLEND"); btn:GetNormalTexture():SetVertexColor(r, g, b, a) end
            if btn:GetPushedTexture() then btn:GetPushedTexture():SetBlendMode("BLEND"); btn:GetPushedTexture():SetVertexColor(r, g, b, a) end
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

            -- Color Interpolation: Red -> Orange -> Green
            local r, g, b
            if vol <= 0.5 then
                -- 0% to 50%: Red (1,0,0) -> Orange (1, 0.5, 0)
                r = 1
                g = vol -- 0 to 0.5
                b = 0
            else
                local t = (vol - 0.5) * 2
                r = 1 - t             -- 1 down to 0
                g = 0.5 + (0.5 * t)   -- 0.5 up to 1.0
                b = 0
            end

            GameTooltip:AddLine(string.format("%d%%", vol * 100), r, g, b)
            GameTooltip:Show()
            if SELECTED_CHAT_FRAME then Chat:ShowChatFrame(SELECTED_CHAT_FRAME, db) end
            UpdateIcon() -- Re-trigger to apply highlight color
        end)

        btn:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
            UpdateIcon() -- Re-trigger to remove highlight
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
            if SELECTED_CHAT_FRAME then Chat:ShowChatFrame(SELECTED_CHAT_FRAME, db) end
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
    local x = HeaderButtonX(db, "volume")
    local y = db.volumeY or 0
    local scale = db.volumeScale or 1.0
    btn:SetScale(scale)
    btn:SetPoint("TOPRIGHT", chatFrame.FlareUI_Skin, "TOPRIGHT", x, y)

    btn:SetFrameStrata("DIALOG")
    btn:SetFrameLevel(210)
    EnableHeaderDrag(btn, "volume")

    UpdateIcon()
end

local function CreateOrGetSkinFrame(chatFrame, db)
    local skin = chatFrame.FlareUI_Skin
    if not skin then
        skin = CreateFrame("Frame", nil, chatFrame, "BackdropTemplate")
        chatFrame.FlareUI_Skin = skin
        -- In the gamepad UI Blizzard's cursor would walk from the edit box onto our tabs and header
        -- buttons, where it can click nothing (and a pad click would run our code inside its
        -- navigation). Ignored here means ignored for everything inside the skin, so the D-pad
        -- stays on the edit box, as it does in Blizzard's own chat. The UI reloads on a switch.
        if ns.IsGamepadUI() then skin.smartNavigationIgnored = true end
    end
    if not skin.Separator then skin.Separator = skin:CreateTexture(nil, "OVERLAY") end

    local padding = db.textPadding or 6
    local headerHeight = db.headerHeight or 24

    skin:ClearAllPoints()
    skin:SetPoint("BOTTOMLEFT", chatFrame, "BOTTOMLEFT", -padding, -padding)
    skin:SetPoint("BOTTOMRIGHT", chatFrame, "BOTTOMRIGHT", padding, -padding)
    skin:SetPoint("TOPLEFT", chatFrame, "TOPLEFT", -padding, padding + headerHeight)
    skin:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", padding, padding + headerHeight)
    skin:SetFrameStrata(chatFrame:GetFrameStrata())
    local level = chatFrame:GetFrameLevel() or 1
    skin:SetFrameLevel(math_max(level - 1, 0))
    return skin
end

local function UpdateSkinFramePoints(chatFrame, db)
    local skin = chatFrame and chatFrame.FlareUI_Skin
    if not skin then return end
    local padding = db.textPadding or 6
    local headerHeight = db.headerHeight or 24
    skin:ClearAllPoints()
    skin:SetPoint("BOTTOMLEFT", chatFrame, "BOTTOMLEFT", -padding, -padding)
    skin:SetPoint("BOTTOMRIGHT", chatFrame, "BOTTOMRIGHT", padding, -padding)
    skin:SetPoint("TOPLEFT", chatFrame, "TOPLEFT", -padding, padding + headerHeight)
    skin:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", padding, padding + headerHeight)
end

function Chat:StyleChatFrame(chatFrame, db)
    if not chatFrame or chatFrame:IsForbidden() then return end
    UnclampChatFrame(chatFrame)

    StripBlizzardChatBackground(chatFrame)
    KillScrollBar(chatFrame)
    HideButtonFrame(chatFrame)
    RepositionScrollToBottomButton(chatFrame)

    if not chatFrame.FlareUI_ScriptHooked then
        chatFrame.FlareUI_ScriptHooked = true
        -- Cleared once: nothing sets OnUpdate on the chat frame itself later (the dock and the tabs
        -- use their own), so there is no need to intercept SetScript.
        chatFrame:SetScript("OnUpdate", nil)
    end

    chatFrame:SetFading(false)
    chatFrame:SetTimeVisible(9999)

    if not chatFrame.FlareUI_AlphaHooked then
        Chat:SecureHook(chatFrame, "SetAlpha", function(frameParam, alpha)
            if frameParam.FlareUI_IgnoreAlpha then return end

            if ns.db.profile.chat.autoHideEnabled == false then
               local target = ns.db.profile.chat.alphaMax or 1
               if math_abs(alpha - target) > 0.05 then
                   frameParam.FlareUI_IgnoreAlpha = true
                   frameParam:SetAlpha(target)
                   frameParam.FlareUI_IgnoreAlpha = false
               end
               return
            end

            local target = frameParam.FlareUI_TargetAlpha
            if target and math_abs(alpha - target) > 0.05 then
                frameParam.FlareUI_IgnoreAlpha = true
                frameParam:SetAlpha(target)
                frameParam.FlareUI_IgnoreAlpha = false
            end
        end)
        chatFrame.FlareUI_AlphaHooked = true
    end

    local skin = CreateOrGetSkinFrame(chatFrame, db)
    UpdateSkinFramePoints(chatFrame, db)

    -- Blizzard's dialog background inside the border picked in the options
    local bgTexture     = LSM:Fetch("background", "Blizzard Dialog Background Dark") or "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"
    local borderTexture = GetBorderFile(db)
    local borderSize    = db.borderSize or 16
    local inset         = db.borderInset or 4
    local opacity       = db.opacity or 1
    local backdrop      = { bgFile = bgTexture, edgeFile = borderTexture, tile = false, tileSize = 0, edgeSize = borderSize, insets = { left = inset, right = inset, top = inset, bottom = inset } }

    if skin then
        skin:SetBackdrop(backdrop)
        skin:SetBackdropColor(1, 1, 1, opacity)
        local c = ns.BORDER_COLOR
        skin:SetBackdropBorderColor(c.r, c.g, c.b, c.a)

        if db.showSeparator then
            skin.Separator:Show()
            local c = db.separatorColor or {r=1, g=0.82, b=0, a=0.5}
            local tex = SEPARATORS[db.separatorStyle] or SEPARATORS["Solid"]
            local yOffset = 6
            local pad = db.textPadding or 6
            if tex then
                skin.Separator:SetColorTexture(0,0,0,0); skin.Separator:SetTexture(tex); skin.Separator:SetVertexColor(c.r, c.g, c.b, c.a)
                skin.Separator:SetHeight(8); skin.Separator:SetTexCoord(0, 1, 0, 1)
                skin.Separator:ClearAllPoints()
                skin.Separator:SetPoint("TOPLEFT", chatFrame, "TOPLEFT", -pad + inset + 2, 4 + yOffset)
                skin.Separator:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", pad - inset - 2, 4 + yOffset)
            else
                skin.Separator:SetTexture(nil); skin.Separator:SetColorTexture(c.r, c.g, c.b, c.a); skin.Separator:SetHeight(1)
                skin.Separator:ClearAllPoints()
                skin.Separator:SetPoint("TOPLEFT", chatFrame, "TOPLEFT", -pad + inset, 4 + yOffset)
                skin.Separator:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", pad - inset, 4 + yOffset)
            end
        else
            skin.Separator:Hide()
        end
    end

    local path, size, flags = GetFontData(db.chatFont)
    if not chatFrame.FlareUI_FontHooked then
        chatFrame.FlareUI_FontHooked = true
        Chat:SecureHook(chatFrame, "SetFont", function(frameParam, font, size, flags)
            if frameParam.FlareUI_SettingFont then return end
            local dbRoot = ns.db
            if not dbRoot or not dbRoot.profile or not dbRoot.profile.chat then return end
            local db = dbRoot.profile.chat
            if not db.enabled then return end
            local myPath, mySize, myFlags = GetFontData(db.chatFont)
            if math_abs(size - mySize) > 0.1 or font ~= myPath then
                frameParam.FlareUI_SettingFont = true
                frameParam:SetFont(myPath, mySize, myFlags)
                ApplyFontEffects(frameParam, db.chatFont)
                frameParam.FlareUI_SettingFont = false
            end
        end)
    end
    chatFrame.FlareUI_SettingFont = true
    chatFrame:SetFont(path, size, flags)
    chatFrame.FlareUI_SettingFont = false
    ApplyFontEffects(chatFrame, db.chatFont)

    Chat:CreateCustomTabBar(chatFrame)
    Chat:UpdateCustomTabs(chatFrame, db)
    Chat:HideBlizzardTabs()

    Chat:SetupVolumeButton(chatFrame, db)
    Chat:StyleHeaderButtons()
end

function Chat:SetChatFrameAlpha(chatFrame, alpha)
    if not chatFrame or chatFrame:IsForbidden() then return end

    chatFrame.FlareUI_TargetAlpha = alpha
    chatFrame.FlareUI_IgnoreAlpha = true
    chatFrame:SetAlpha(alpha)
    chatFrame.FlareUI_IgnoreAlpha = false

    -- The skin carries the volume button and the three header buttons, so one SetAlpha here fades
    -- the whole header with the frame.
    if chatFrame.FlareUI_Skin then chatFrame.FlareUI_Skin:SetAlpha(alpha) end
end

function Chat:CheckChatVisibility(chatFrame, db)
    local checkMouse = (db.showOnMouse ~= false)
    local checkEdit  = (db.showOnEdit ~= false)

    if checkMouse then
        if chatFrame:IsMouseOver() then return true end
        if chatFrame.FlareUI_Skin and chatFrame.FlareUI_Skin:IsMouseOver() then return true end
        if chatFrame.FlareUI_VolumeBtn and chatFrame.FlareUI_VolumeBtn:IsMouseOver() then return true end
        if chatFrame.FlareUI_TabBar and chatFrame.FlareUI_TabBar:IsMouseOver() then return true end

        -- Check if header buttons are being hovered (only for the selected chat frame)
        local frameWithButtons = SELECTED_CHAT_FRAME or ChatFrame1
        if chatFrame == frameWithButtons then
            if _G.QuickJoinToastButton and _G.QuickJoinToastButton:IsMouseOver() then return true end
            if _G.ChatFrameChannelButton and _G.ChatFrameChannelButton:IsMouseOver() then return true end
            if _G.ChatFrameMenuButton and _G.ChatFrameMenuButton:IsMouseOver() then return true end
        end
    end

    if checkEdit then
        local editBox = _G[chatFrame:GetName().."EditBox"]
        if editBox and editBox:HasFocus() then return true end
    end

    if db.showOnCombat and InCombatLockdown() then return true end
    return false
end

function Chat:ShowChatFrame(chatFrame, db)
    if not chatFrame or chatFrame:IsForbidden() then return end
    if not db then return end
    self._autoHideState = self._autoHideState or {}
    local state = self._autoHideState[chatFrame]
    if not state then state = {}; self._autoHideState[chatFrame] = state end
    if state.fadeTicker then self:CancelTimer(state.fadeTicker); state.fadeTicker = nil end
    if state.delayTimer then self:CancelTimer(state.delayTimer); state.delayTimer = nil end

    local alphaMax = db.alphaMax or 1
    local fadeInTime = db.fadeInSpeed or 0

    if fadeInTime > 0 then
        local currentAlpha = chatFrame:GetAlpha()
        local steps = 10; local step = 0; local diff = alphaMax - currentAlpha
        if math_abs(diff) > 0.05 then
            state.fadeTicker = self:ScheduleRepeatingTimer(function()
                step = step + 1
                local newAlpha = currentAlpha + (diff * (step / steps))
                if step >= steps then
                    Chat:SetChatFrameAlpha(chatFrame, alphaMax)
                    self:CancelTimer(state.fadeTicker); state.fadeTicker = nil
                    if db.showOnCombat and InCombatLockdown() then return end
                    Chat:StartHoldTimer(chatFrame, db)
                    return
                end
                Chat:SetChatFrameAlpha(chatFrame, newAlpha)
            end, fadeInTime / steps)
            return
        end
    end
    Chat:SetChatFrameAlpha(chatFrame, alphaMax)
    if db.showOnCombat and InCombatLockdown() then return end
    Chat:StartHoldTimer(chatFrame, db)
end

function Chat:StartHoldTimer(chatFrame, db)
    -- In Edit Mode, always keep chat visible and do not start the hide timer.
    if _G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown() then
        Chat:SetChatFrameAlpha(chatFrame, db.alphaMax or 1)
        return
    end

    local enabled = (db.autoHideEnabled ~= false)
    if not enabled then
        Chat:SetChatFrameAlpha(chatFrame, db.alphaMax or 1)
        return
    end

    local state = self._autoHideState[chatFrame]
    local delay = db.autoHideDelay or 10
    if Chat:CheckChatVisibility(chatFrame, db) then
        -- Use a shorter retry delay when autoHideDelay is very short
        local retryDelay = delay > 0.5 and 1 or 0.1
        state.delayTimer = self:ScheduleTimer(function() Chat:StartHoldTimer(chatFrame, db) end, retryDelay)
        return
    end

    -- Function to execute fade logic
    local function ExecuteFade()
        state.delayTimer = nil
        if Chat:CheckChatVisibility(chatFrame, db) then Chat:ShowChatFrame(chatFrame, db); return end

        local fadeOutTime = db.fadeOutSpeed or 1.0
        local alphaMin = db.alphaMin or 0
        if fadeOutTime <= 0 then Chat:SetChatFrameAlpha(chatFrame, alphaMin); return end

        local startAlpha = chatFrame:GetAlpha()
        local steps = 20; local step = 0
        local tickTime = fadeOutTime / steps
        if tickTime < 0.02 then tickTime = 0.02; steps = fadeOutTime / 0.02 end

        state.fadeTicker = self:ScheduleRepeatingTimer(function()
            step = step + 1
            if Chat:CheckChatVisibility(chatFrame, db) then
                self:CancelTimer(state.fadeTicker); state.fadeTicker = nil; Chat:ShowChatFrame(chatFrame, db); return
            end
            if steps <= 0 then steps = 1 end
            local progress = step / steps
            local newAlpha = startAlpha - ((startAlpha - alphaMin) * progress)
            if step >= steps then
                Chat:SetChatFrameAlpha(chatFrame, alphaMin); self:CancelTimer(state.fadeTicker); state.fadeTicker = nil; return
            end
            Chat:SetChatFrameAlpha(chatFrame, newAlpha)
        end, tickTime)
    end

    -- If delay is 0, execute immediately without timer
    if delay <= 0 then
        ExecuteFade()
    else
        state.delayTimer = self:ScheduleTimer(ExecuteFade, delay)
    end
end

--------------------------------------------------
-- 9. EVENT HANDLERS
--------------------------------------------------

-- Event: Combat state change (auto-hide visibility)
function Chat:OnCombatStateChange(event)
    local db = ns.db.profile.chat
    if not db or not db.enabled or not db.autoHideEnabled then return end

    -- If Combat Visibility is disabled, stop here
    if not db.showOnCombat then return end

    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        if cf and cf:IsShown() and not cf:IsForbidden() then
            self:ShowChatFrame(cf, db)
        end
    end
end

function Chat:RefreshForEditMode()
    local db = ns.db.profile.chat
    if not db or not db.enabled then return end

    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        -- Check if the frame exists and has been styled by us
        if cf and cf.FlareUI_Skin and not cf:IsForbidden() then
            self:ShowChatFrame(cf, db)
        end
    end
end

-- Event: NPC interaction end (show chat after quest/gossip)
function Chat:OnNPCInteractionEnd()
    if SELECTED_CHAT_FRAME then
        local db = ns.db.profile.chat
        if db then
            self:ShowChatFrame(SELECTED_CHAT_FRAME, db)
        end
    end
end

--------------------------------------------------
-- 10. AUTO-HIDE SETUP
--------------------------------------------------

function Chat:SetupAutoHide(db)
    if not NUM_CHAT_WINDOWS or not db then return end
    self._autoHideState = self._autoHideState or {}

    -- Register combat events with AceEvent (only once)
    if not Chat.autoHideEventsRegistered then
        self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatStateChange")
        self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatStateChange")
        Chat.autoHideEventsRegistered = true
    end

    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame" .. i]
        if frame and not frame:IsForbidden() then
            self._autoHideState[frame] = self._autoHideState[frame] or {}
            if not frame.FlareUI_AutoHideHooked then
                frame.FlareUI_AutoHideHooked = true
                Chat:SecureHookScript(frame, "OnEnter", function(frameParam) if db.showOnMouse ~= false then Chat:ShowChatFrame(frameParam, db) end end)
                -- Combined hook for both auto-hide and scroll-to-bottom button visibility
                Chat:SecureHook(frame, "AddMessage", function(frameParam)
                    UpdateScrollToBottomVisibility(frameParam)  -- Update scroll button
                    if db.showOnMessage ~= false then Chat:ShowChatFrame(frameParam, db) end  -- Auto-hide logic
                end)
                local editBox = _G[frame:GetName() .. "EditBox"]
                if editBox and not editBox.FlareUI_AutoHideHooked then
                    editBox.FlareUI_AutoHideHooked = true
                    Chat:SecureHookScript(editBox, "OnEditFocusGained", function() if db.showOnEdit ~= false then Chat:ShowChatFrame(frame, db) end end)
                end
            end
            local a = db.alphaMax or 1
            frame.FlareUI_TargetAlpha = a
            frame:SetAlpha(a)
            Chat:ShowChatFrame(frame, db)
        end
    end
end

function Chat:UpdateFilters()
    local db = ns.db.profile.chat
    if not db then return end

    if db.formatNPC then
        ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_MONSTER_SAY", NPCFilter)
        ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_MONSTER_YELL", NPCFilter)
        ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_MONSTER_WHISPER", NPCFilter)
    else
        ChatFrameUtil.RemoveMessageEventFilter("CHAT_MSG_MONSTER_SAY", NPCFilter)
        ChatFrameUtil.RemoveMessageEventFilter("CHAT_MSG_MONSTER_YELL", NPCFilter)
        ChatFrameUtil.RemoveMessageEventFilter("CHAT_MSG_MONSTER_WHISPER", NPCFilter)
    end

    if db.formatPlayer then
        ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_SAY", PlayerFilter)
        ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_YELL", PlayerFilter)
        ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_GUILD", PlayerFilter)
        ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_OFFICER", PlayerFilter)
        ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_PARTY", PlayerFilter)
        ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_PARTY_LEADER", PlayerFilter)
        ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_RAID", PlayerFilter)
        ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_RAID_LEADER", PlayerFilter)
        ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_RAID_WARNING", PlayerFilter)
        ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_WHISPER", PlayerFilter)
        ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", PlayerFilter)
    else
        ChatFrameUtil.RemoveMessageEventFilter("CHAT_MSG_SAY", PlayerFilter)
        ChatFrameUtil.RemoveMessageEventFilter("CHAT_MSG_YELL", PlayerFilter)
        ChatFrameUtil.RemoveMessageEventFilter("CHAT_MSG_GUILD", PlayerFilter)
        ChatFrameUtil.RemoveMessageEventFilter("CHAT_MSG_OFFICER", PlayerFilter)
        ChatFrameUtil.RemoveMessageEventFilter("CHAT_MSG_PARTY", PlayerFilter)
        ChatFrameUtil.RemoveMessageEventFilter("CHAT_MSG_PARTY_LEADER", PlayerFilter)
        ChatFrameUtil.RemoveMessageEventFilter("CHAT_MSG_RAID", PlayerFilter)
        ChatFrameUtil.RemoveMessageEventFilter("CHAT_MSG_RAID_LEADER", PlayerFilter)
        ChatFrameUtil.RemoveMessageEventFilter("CHAT_MSG_RAID_WARNING", PlayerFilter)
        ChatFrameUtil.RemoveMessageEventFilter("CHAT_MSG_WHISPER", PlayerFilter)
        ChatFrameUtil.RemoveMessageEventFilter("CHAT_MSG_WHISPER_INFORM", PlayerFilter)
    end
end

function Chat:Apply(db)
    if not NUM_CHAT_WINDOWS or not db then return end

    -- 1. General Settings (From the top function)
    if db.hideCombatLog then
        if ChatFrame2 then
            ChatFrame2:UnregisterAllEvents()
            ChatFrame2:SetScript("OnEvent", nil)
        end
    end

    -- 2. Dock & Frame Styling
    KeepCombatLogSecond()
    Chat:KillGeneralDockManager()
    StyleButtonFrame()

    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame" .. i]
        if frame and not frame:IsForbidden() then
            Chat:StyleChatFrame(frame, db)
            Chat:StyleEditBox(frame, db)
        end
    end
    -- the gamepad UI parks the dock at ChatFrame1's skin, which only now exists
    if ns.IsGamepadUI() then Chat:KillGeneralDockManager() end

    Chat:SetupAutoHide(db)

    -- 3. Update Fonts & Layout
    self:UpdateTabFonts()
end

-- Blizzard's gamepad chat only works in IM chat style: in Classic the edit box stays hidden until
-- Enter, so FocusGamepad's SetFocus on it fails and the footer prompts tied to it (X channels, Y tab
-- settings, A send) do nothing - with no addon loaded too. So while the gamepad UI is on, chat runs
-- in IM style, and the player's own style is put back the next time the UI loads with keyboard and
-- mouse (switching the Gamepad UI setting reloads the UI). The style is an account-wide CVar, so
-- the one it replaced is kept account-wide too.
function Chat:ApplyGamepadChatStyle()
    local global = ns.db.global
    local current = GetCVar("chatStyle")
    if ns.IsGamepadUI() then
        if current ~= "im" then
            global.chatStyleBeforeGamepad = current
            SetCVar("chatStyle", "im")
        end
    elseif global.chatStyleBeforeGamepad then
        if current == "im" then SetCVar("chatStyle", global.chatStyleBeforeGamepad) end
        global.chatStyleBeforeGamepad = nil
    end
end

-- Gamepad UI: while a chat window has the pad (FloatingChatFrameMixin:HasGamepadFocus - its edit box
-- focused), LB and RB icons sit above its header's ends, the way Blizzard's own tab bars show them.
-- Polled rather than hooked: a hook on Blizzard's focus calls would run our code inside its gamepad
-- focus manager (see Dialog.lua).
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

function Chat:Init()
    local db = ns.db.profile.chat
    Chat:ApplyGamepadChatStyle()
    SetupGamepadTabHints()
    -- Blizzard's chat fading is turned off per frame in StyleChatFrame (SetFading(false) and
    -- SetTimeVisible). Do not blank the FCF_Fade* globals for it: their callers would run our
    -- tainted code, and they are not what does the fading.

    -- Protect buttons from being hidden
    Chat:ProtectButtons()

    if QuickJoinToastButton then
        Chat:SecureHook(QuickJoinToastButton, "SetPoint", function()
            if Chat.isStyling then return end
            C_Timer.After(0.05, function()
                Chat:StyleHeaderButtons()
            end)
        end)

        Chat:SecureHook(QuickJoinToastButton, "Show", function(frameParam)
            if Chat.isStyling then return end
            C_Timer.After(0.05, function()
                Chat:StyleHeaderButtons()
            end)
        end)
    end

    Chat:SecureHook("FCF_SelectDockFrame", function(view)
        Chat:StyleHeaderButtons(view)
    end)

    Chat:KillGeneralDockManager()

    ns.Dialogs["FLAREUI_RENAME_CHAT"] = {
        text = "Rename Chat Window",
        button1 = ACCEPT,
        button2 = CANCEL,
        hasEditBox = true,
        maxLetters = 31,
        editText = function(chatFrame) return chatFrame and chatFrame.name or "" end,
        OnAccept = function(chatFrame, text)
            if text and text ~= "" and chatFrame then
                FCF_SetWindowName(chatFrame, text)
                if ns.Chat and ns.Chat.UpdateCustomTabs then
                    ns.Chat:UpdateCustomTabs(chatFrame, ns.db.profile.chat)
                end
            end
        end,
        hideOnEscape = true,
    }

    self:ScheduleTimer(function()
        Chat:Apply(db)
        HandleCombatLog(db)
        Chat:SetupImprovements()
        Chat:UpdateFilters()
        Chat:RefreshAll()
    end, 0.2)

    -- URL linking lives in SetupCopyLinks (section "COPY CHAT LINKS"), behind the Copy Chat Links
    -- option; nothing here may filter URLs unconditionally, or the option could not turn it off.
    Chat:SecureHook("SetItemRef", function(link, text, button, chatFrame)
        if not ns.db.profile.chat.shiftInvite then return end
        if IsShiftKeyDown() and button == "LeftButton" and link:sub(1, 6) == "player" then
            local name = link:match("player:([^:]+)")
            if name then C_PartyInfo.InviteUnit(name) end
        end
    end)

    self:ScheduleTimer(function() Chat:RestoreHistory() end, 1)

    -- Register NPC interaction events with AceEvent (only once)
    if not Chat.npcEventsRegistered then
        self:RegisterEvent("GOSSIP_CLOSED", "OnNPCInteractionEnd")
        self:RegisterEvent("QUEST_FINISHED", "OnNPCInteractionEnd")
        self:RegisterEvent("QUEST_GREETING", "OnNPCInteractionEnd")
        self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateInstanceBubbles")
        Chat.npcEventsRegistered = true
    end

    if not Chat._tabsHooked then
        Chat._tabsHooked = true

        -- Hook FCF_OpenNewWindow to handle new chat window creation
        Chat:SecureHook("FCF_OpenNewWindow", function(name)
            C_Timer.After(0.2, function()
                local db = ns.db.profile.chat
                if not db then return end

                -- Style any new frames (same as whisper logic)
                for i = 1, NUM_CHAT_WINDOWS do
                    local cf = _G["ChatFrame"..i]
                    if cf and not cf:IsForbidden() and not cf.FlareUI_Skin then
                        Chat:StyleChatFrame(cf, db)
                        Chat:StyleEditBox(cf, db)
                    end
                end

                -- Hide Blizzard tabs for new frame
                Chat:HideBlizzardTabs()

                -- Update FlareUI custom tabs to include the new frame
                if _G.ChatFrame1 then
                    Chat:UpdateCustomTabs(_G.ChatFrame1, db)
                end

                -- Once when the frames exist, and again once the new window has been shown and
                -- selected - the first pass can land while it is still neither.
                Chat:StyleHeaderButtons()
                C_Timer.After(0.4, function() Chat:StyleHeaderButtons() end)
            end)
        end)

        -- Hook FCF_Close to handle chat window closure
        Chat:SecureHook("FCF_Close", function(frame, fallback)
            C_Timer.After(0.2, function()
                local db = ns.db.profile.chat
                if not db then return end

                -- Update tabs after closure
                if _G.ChatFrame1 then
                    Chat:UpdateCustomTabs(_G.ChatFrame1, db)
                end

                -- Force button refresh
                Chat:StyleHeaderButtons()
            end)
        end)

        Chat:SecureHook("FCFDock_UpdateTabs", function()
            if ns.db.profile.chat then HandleCombatLog(ns.db.profile.chat) end
            -- Update custom tabs immediately (no delay)
            C_Timer.After(0, function()
                for i = 1, NUM_CHAT_WINDOWS do
                    local cf = _G["ChatFrame"..i]
                    if cf and cf.FlareUI_TabBar then
                        Chat:UpdateCustomTabs(cf, ns.db.profile.chat)
                    end
                end
                Chat:StyleHeaderButtons()
            end)
        end)

        Chat:SecureHook("FCFTab_UpdateAlpha", function(tab)
            if not tab or tab:IsForbidden() then return end
            tab:SetAlpha(0)
        end)

        -- Hook to prevent Blizzard from hiding the selected chat frame
        hooksecurefunc("FCFDock_UpdateTabs", function()
            C_Timer.After(0, function()
                local dock = _G.GeneralDockManager
                if not dock then return end

                local selectedFrame = FCFDock_GetSelectedWindow(dock)
                if selectedFrame and not selectedFrame:IsForbidden() then
                    -- Only show the selected frame
                    selectedFrame:Show()

                    -- If it's a temporary frame without styling, style it now
                    if selectedFrame.isTemporary and not selectedFrame.FlareUI_Skin then
                        local db = ns.db.profile.chat
                        if db then
                            Chat:StyleChatFrame(selectedFrame, db)
                            Chat:StyleEditBox(selectedFrame, db)
                        end
                    end
                end
            end)
        end)

        -- Hook temporary window creation (whispers)
        local preventAutoSelect = false

        Chat:SecureHook("FCF_OpenTemporaryWindow", function(chatType, chatTarget, sourceChatFrame, selectWindow)
            preventAutoSelect = true

            -- Store current selection before whisper window is created
            local dock = _G.GeneralDockManager
            local currentSelected = dock and FCFDock_GetSelectedWindow(dock)

            C_Timer.After(0.15, function()
                preventAutoSelect = false
                local db = ns.db.profile.chat
                if not db then return end

                -- Style any new frames
                for i = 1, NUM_CHAT_WINDOWS do
                    local cf = _G["ChatFrame"..i]
                    if cf and not cf:IsForbidden() and not cf.FlareUI_Skin then
                        Chat:StyleChatFrame(cf, db)
                        Chat:StyleEditBox(cf, db)
                    end
                end

                -- Hide all Blizzard tabs (including the new temporary one)
                Chat:HideBlizzardTabs()

                -- Restore previous selection (don't auto-switch to whisper)
                if dock and currentSelected and not currentSelected:IsForbidden() then
                    FCFDock_SelectWindow(dock, currentSelected)
                    currentSelected:Show()
                    _G.SELECTED_CHAT_FRAME = currentSelected
                end

                -- Update FlareUI custom tabs to include the new temporary frame
                if _G.ChatFrame1 then
                    Chat:UpdateCustomTabs(_G.ChatFrame1, db)
                end
            end)
        end)

        -- Hook FCFDock_SelectWindow to prevent auto-selection during whisper creation
        hooksecurefunc("FCFDock_SelectWindow", function(dock, chatFrame)
            if preventAutoSelect and chatFrame and chatFrame.isTemporary then
                -- Prevent the temporary frame from being selected during creation
                -- Restore to the previous selection immediately
                C_Timer.After(0, function()
                    if dock then
                        local currentlySelected = FCFDock_GetSelectedWindow(dock)
                        if currentlySelected and currentlySelected.isTemporary and _G.ChatFrame1 then
                            FCFDock_SelectWindow(dock, _G.ChatFrame1)
                            _G.ChatFrame1:Show()
                            _G.SELECTED_CHAT_FRAME = _G.ChatFrame1
                        end
                    end
                end)
            end
        end)
    end

    -- Hook into Edit Mode to handle visibility
    if _G.EditModeManagerFrame and not Chat.editModeHooksAttached then
        Chat:SecureHookScript(_G.EditModeManagerFrame, "OnShow", function() Chat:RefreshForEditMode() end)
        Chat:SecureHookScript(_G.EditModeManagerFrame, "OnHide", function() Chat:RefreshForEditMode() end)
        Chat.editModeHooksAttached = true
    end

    -- Register history save events with AceEvent (only once)
    if not Chat.historyEventsRegistered then
        self:RegisterEvent("PLAYER_LOGOUT", "SaveHistory")
        self:RegisterEvent("PLAYER_LEAVING_WORLD", "SaveHistory")
        Chat.historyEventsRegistered = true
    end
end

function Chat:SaveHistory()
    local db = GetDb()
    if not db or not db.saveHistory then
        ns.CharDB().chatHistory = nil
        return
    end

    local success, err = pcall(function()
        local history = {}
        for i = 1, NUM_CHAT_WINDOWS do
            local cf = _G["ChatFrame"..i]
            if cf then
                local messages = {}
                local num = cf:GetNumMessages()
                local start = math_max(1, num - 128)
                for j = start, num do
                    local msg, r, g, b = cf:GetMessageInfo(j)
                    -- a protected line cannot be read or written to SavedVariables; skip it.
                    -- canaccessvalue comes first: nothing else may touch a secret, not even a
                    -- truthiness test.
                    if canaccessvalue(msg) and type(msg) == "string" then
                        local rHex = string_format("%02x", (r or 1)*255)
                        local gHex = string_format("%02x", (g or 1)*255)
                        local bHex = string_format("%02x", (b or 1)*255)
                        table.insert(messages, "|cff" .. rHex .. gHex .. bHex .. msg .. "|r")
                    end
                end
                if #messages > 0 then history[i] = messages end
            end
        end
        ns.CharDB().chatHistory = history
    end)

    if not success then
        print(string.format("|cffff0000FlareUI Chat:|r Failed to save chat history: %s", tostring(err)))
    end
end

function Chat:RestoreHistory()
    -- kept with the character's own state; see CHARACTER IDENTITY in Core.lua
    local history = ns.CharDB().chatHistory
    if not ns.db.profile.chat.saveHistory or not history then return end
    for i, msgs in pairs(history) do
        local cf = _G["ChatFrame"..i]
        if cf then for _, msg in ipairs(msgs) do cf:AddMessage(msg) end end
    end
end

function Chat:RefreshAll()
    local db = ns.db.profile.chat
    if not db or not db.enabled then return end
    Chat:Apply(db)
    HandleCombatLog(db)
    Chat:SetupImprovements()
    Chat:UpdateFilters()

    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame"..i]
        if cf then
            local a = db.alphaMax or 1
            if cf.FlareUI_AlphaHooked then cf.FlareUI_TargetAlpha = a end
            cf:SetAlpha(a)
            Chat:ShowChatFrame(cf, db)
        end
    end
end
