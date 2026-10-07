local _, ns = ...
local L = ns.L

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

-- The border picked in the options, or the default when LibSharedMedia does not know it
local DEFAULT_BORDER = "FlareUI Frames"
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

-- separator styles drawn with a texture; any other style is a solid line
local SEPARATORS = {
    Blizzard = "Interface\\Common\\UI-TooltipDivider-Transparent",
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

-- A window popped out of the dock (see POP-OUT WINDOWS)
local function IsPopped(chatFrame)
    local dock = _G.GeneralDockManager
    return chatFrame ~= nil and dock ~= nil and chatFrame ~= dock.primary and not chatFrame.isDocked
end

local function GetTimestamp()
    local db = GetDb()
    if not db then return "" end
    local format = C_CVar.GetCVar("showTimestamps")

    if format == "none" and not db.betterTimestamps then return "" end
    if format == "none" then format = "%H:%M" end

    -- Blizzard's formats end in a space, which belongs outside the brackets
    local timeStr = string_gsub(BetterDate(format, time()), "%s+$", "")

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
    ns.ApplyShadow(fontString, dbEntry)
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

-- Forever's "Refreshing your world" notice sits just above the chat, its minimize button (5 px to
-- its left) lined up with the chat's left edge. Re-placed on every SetPoint and show.
local SHARD_GAP = 4   -- between the chat's top edge and the notice
local function AnchorShardNotice()
    local frame = _G.ShardTransferImminentFrame
    if not frame or frame.FlareUI_Anchored then return end
    frame.FlareUI_Anchored = true

    local placing
    local function Place()
        if placing then return end
        local chat = _G.ChatFrame1
        local anchor = (chat and chat.FlareUI_Skin) or chat
        if not anchor then return end
        local button = _G.ShardTransferImminentMinimizeButton
        local shift = button and (button:GetWidth() + 5) or 0
        placing = true
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", shift, SHARD_GAP)
        placing = false
    end

    hooksecurefunc(frame, "SetPoint", Place)
    frame:HookScript("OnShow", Place)
    Place()
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
-- 5. LINE REWRITING
-- A post-hook on each window's AddMessage rewrites the newest history entry in place, so Blizzard's
-- own line (player link, report ID, flash, censoring) stays. Replacing AddMessage or the CHAT_*_GET
-- strings would taint Blizzard's handler. Secret lines pass untouched.
--   Short Channel Names   [2. Trade - City] -> [2], [Guild] -> [G]
--   Better Player Names   "[Name] says:" -> the class-coloured [Name] without realm or "says:"
--   Better NPC Names      "Thrall says:" -> an orange [Thrall]
--   Level Before Names    "(42)" in front of a player's name
--   Better Timestamps     Blizzard's timestamp in FlareUI's colour, or one added where it has none
--   Copy Line             the timestamp is a link: shift-click puts the line in the chat box
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

-- Links the server accepts in a sent message; Copy Line reduces any other link to its text
local KEEP_LINKS = {
    item = true, spell = true, quest = true, achievement = true, enchant = true,
    trade = true, talent = true, currency = true,
}

local Lines = {
    copies = {},        -- copy link id -> the line as plain chat text, this session only
    copySerial = 0,
    COPY_KEEP = 500,    -- the newest this many lines can be copied
    levels = {},        -- GUID or lower-case name -> level, this session only
    hooked = {},        -- chat frames carrying the AddMessage post-hook (not a field on Blizzard's)
}

-- Splits off Blizzard's timestamp: the line was just formatted, so this second or the one before
-- reproduces it.
function Lines.SplitStamp(message)
    local fmt = ChatFrameUtil.GetTimestampFormat and ChatFrameUtil.GetTimestampFormat()
    if not fmt then return "", message end
    local now = time()
    for t = now, now - 1, -1 do
        local stamp = BetterDate(fmt, t)
        if message:sub(1, #stamp) == stamp then return stamp, message:sub(#stamp + 1) end
    end
    return "", message
end

function Lines.ShortenChannel(body, chatType)
    local short
    if chatType == "CHANNEL" or chatType == "COMMUNITIES_CHANNEL" then
        short = string_gsub(body, "(|Hchannel:channel:(%d+)|h)%[[^%]]*%]|h", "%1[%2]|h", 1)
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
    if v ~= nil and canaccessvalue(v) and type(v) == kind then return v end
    return nil
end

local function NameKey(name)
    return name and (name:gsub("%-.*$", "")):lower() or nil
end

function Lines.Remember(guid, name, level)
    if not (canaccessvalue(level) and type(level) == "number" and level > 0) then return end
    if guid and canaccessvalue(guid) and type(guid) == "string" then Lines.levels[guid] = level end
    if name and canaccessvalue(name) and type(name) == "string" then Lines.levels[NameKey(name)] = level end
end

function Lines.RememberUnit(unit)
    local ok, exists = pcall(UnitExists, unit)
    if not (ok and canaccessvalue(exists) and exists) then return end
    local okP, isPlayer = pcall(UnitIsPlayer, unit)
    if not (okP and canaccessvalue(isPlayer) and isPlayer) then return end
    local okG, guid = pcall(UnitGUID, unit)
    local okN, name = pcall(UnitName, unit)
    local okL, level = pcall(UnitLevel, unit)
    if okL then Lines.Remember(okG and guid or nil, okN and name or nil, level) end
end

-- The sender's level, from a unit token or from what was seen this session; nil when unknown
function Lines.LevelFor(guid, sender)
    if guid then
        local ok, unit = pcall(UnitTokenFromGUID, guid)
        if ok and unit and canaccessvalue(unit) then Lines.RememberUnit(unit) end
        if Lines.levels[guid] then return Lines.levels[guid] end
    end
    return sender and Lines.levels[NameKey(sender)] or nil
end

local function ColorCode(r, g, b)
    return string_format("|cff%02x%02x%02x", (r or 1) * 255, (g or 1) * 255, (b or 1) * 255)
end

-- Better Player Names: the link's text becomes the class-coloured name and "says:" goes.
-- Level Before Names: the level goes inside the link, in front of the name.
function Lines.RewriteSender(body, chatType, args, mode, db)
    local s, e, open, display = body:find("(|Hplayer:[^|]*|h)(.-)|h")
    if not s then return body end
    local sender, guid = Arg(args, 2, "string"), Arg(args, 12, "string")
    if not sender or sender == "" then return body end
    if guid == "" then guid = nil end

    local class
    if guid then
        local ok, _, classFile = pcall(GetPlayerInfoByGUID, guid)
        if ok and canaccessvalue(classFile) and type(classFile) == "string" then class = classFile end
    end

    if db.formatPlayer then
        local name = string_gsub(sender, "%-[^|]+", "")
        local color = class and C_ClassColor.GetClassColor(class)
        display = color and (color:GenerateHexColorMarkup() .. "[" .. name .. "]|r") or ("[" .. name .. "]")
    end

    local prefix = ""
    if db.showLevel then
        local level = Lines.LevelFor(guid, sender)
        if level then
            local c = GetQuestDifficultyColor and GetQuestDifficultyColor(level)
            prefix = (c and ColorCode(c.r, c.g, c.b) or "|cffffffff") .. "(" .. level .. ")|r "
        end
    end

    local after = body:sub(e + 1)
    if db.formatPlayer and mode == "full" then
        -- after the link comes the rest of CHAT_<type>_GET (" says: "), maybe behind an ally icon
        local key = _G["CHAT_" .. chatType .. "_GET"]
        local suffix = type(key) == "string" and key:match("%%s(.*)$")
        local ally, rest = after:match("^( |A[^|]*|a)(.*)$")
        local tail = rest or after
        if suffix and suffix ~= "" and tail:sub(1, #suffix) == suffix then
            after = (ally or "") .. " " .. tail:sub(#suffix + 1)
        end
    end
    return body:sub(1, s - 1) .. open .. prefix .. display .. "|h" .. after
end

-- NPC lines have no link: the CHAT_MONSTER_<type>_GET header becomes the orange name
function Lines.RewriteNPC(body, chatType, args)
    local sender = Arg(args, 2, "string")
    local key = _G["CHAT_" .. chatType .. "_GET"]
    if not sender or sender == "" or type(key) ~= "string" then return body end
    local ok, header = pcall(string_format, key, sender, sender)
    if not ok or body:sub(1, #header) ~= header then return body end
    local verb = chatType == "MONSTER_WHISPER" and key:match("%%s(.-):?%s*$") or ""
    return NPC_COLOR .. "[" .. sender .. "]" .. verb .. "|r " .. body:sub(#header + 1)
end

-- The line as text the chat box accepts: no textures or colours, links reduced to their text
-- except KEEP_LINKS
function Lines.ChatSafeText(text)
    local kept = {}
    local function Keep(whole, kind)
        if KEEP_LINKS[kind] then
            kept[#kept + 1] = whole
            return "\001" .. #kept .. "\002"
        end
    end
    text = text:gsub("(|c%x%x%x%x%x%x%x%x|H(%w+):[^|]*|h.-|h|r)", Keep)
    text = text:gsub("(|cn[^:|]*:|H(%w+):[^|]*|h.-|h|r)", Keep)
    text = text:gsub("|T.-|t", ""):gsub("|A.-|a", "")
    text = text:gsub("|H.-|h(.-)|h", "%1")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:|]*:", ""):gsub("|r", "")
    text = text:gsub("\001(%d+)\002", function(i) return kept[tonumber(i)] end)
    return strtrim(text)
end

-- The copy is Blizzard's own line (without its timestamp), not FlareUI's rewrite
function Lines.CopyStamp(stamp, original)
    local shown = stamp:gsub("%s+$", "")
    Lines.copySerial = Lines.copySerial + 1
    local id = Lines.copySerial
    Lines.copies[id] = (Lines.ChatSafeText(original):gsub("  +", " "))
    Lines.copies[id - Lines.COPY_KEEP] = nil
    -- a coloured stamp keeps its colour outside the link, as item links do
    local color, text = shown:match("^(|c%x%x%x%x%x%x%x%x)(.-)|r$")
    if not color then color, text = "", shown end
    return color .. "|Hflarecopy:" .. id .. "|h" .. text .. "|h" .. (color ~= "" and "|r" or "")
        .. stamp:sub(#shown + 1)
end

-- Registered once (LinkUtil asserts on a second registration). Shift-click puts the line in the chat
-- box; a line too long for a message goes to the copy box.
function Lines.RegisterCopyHandler()
    if LinkUtil.IsLinkHandlerRegistered("flarecopy") then return end
    LinkUtil.RegisterLinkHandler("flarecopy", function(link)
        if not IsShiftKeyDown() then return end
        local id = tonumber(link and link:match("^flarecopy:(%d+)"))
        local text = id and Lines.copies[id]
        if not text or text == "" then return end
        if #text > 255 then
            Chat.ShowCopyText(text)
            return
        end
        local editBox = ChatFrameUtil.GetActiveWindow()
        if editBox then
            editBox:Insert(text)
        else
            ChatFrameUtil.OpenChat(text)
        end
    end)
end

local function RewriteStoredLine(chatFrame, message, _, _, _, _, _, _, event, eventArgs)
    local db = GetDb()
    if not (db and event) then return end
    if not (db.shortChannels or db.formatPlayer or db.formatNPC or db.betterTimestamps
            or db.copyLine or db.showLevel) then return end
    if not canaccessallvalues(message, event) or type(message) ~= "string" or type(event) ~= "string"
            or event:sub(1, 9) ~= "CHAT_MSG_" then return end
    local args = type(eventArgs) == "table" and canaccesstable(eventArgs) and eventArgs or nil
    local chatType = event:sub(10)

    local stamp, body = Lines.SplitStamp(message)
    local original = body
    if db.shortChannels then body = Lines.ShortenChannel(body, chatType) end
    if args then
        if NPC_EVENTS[chatType] then
            if db.formatNPC then body = Lines.RewriteNPC(body, chatType, args) end
        elseif NAME_EVENTS[chatType] and (db.formatPlayer or db.showLevel) then
            body = Lines.RewriteSender(body, chatType, args, NAME_EVENTS[chatType], db)
        end
    end
    if db.betterTimestamps then stamp = GetTimestamp() end
    if db.copyLine and stamp ~= "" and not ns.IsGamepadUI() then
        Lines.RegisterCopyHandler()
        stamp = Lines.CopyStamp(stamp, original)
    end

    local line = stamp .. body
    if line == message then return end
    local entry = chatFrame.historyBuffer and chatFrame.historyBuffer:GetEntryAtIndex(1)
    if entry and canaccessallvalues(entry.message) and entry.message == message then
        entry.message = line
        chatFrame:MarkDisplayDirty()
    end
end

-- Every chat window, temporary whisper windows included
local function HookLineRewrite()
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
                for i = 1, GetNumGuildMembers() do
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
            elseif event == "NAME_PLATE_UNIT_ADDED" then
                Lines.RememberUnit(unit)
            end
        end)
        Lines.events = f
    end
    local f = Lines.events
    if want then
        for _, event in ipairs({ "GUILD_ROSTER_UPDATE", "FRIENDLIST_UPDATE", "WHO_LIST_UPDATE",
                "GROUP_ROSTER_UPDATE", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED" }) do
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

-- Blizzard hides these buttons with ChatFrame1ButtonFrame, which we keep hidden, so an OnHide hook
-- re-shows them. Never replace their Hide method: that taints every caller.
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
                if db[entry.key] or InCombatLockdown() then return end
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
-- HEADER BUTTON ORDER
-- A header button is dragged onto another's place; a bronze bar marks the target. Blizzard's Chat
-- Menu opens on mouse down, so the drag closes it again.
--------------------------------------------------
local HEADER_BLIZZARD = { social = "QuickJoinToastButton", menu = "ChatFrameMenuButton", channel = "ChatFrameChannelButton" }
local headerDrag = { key = nil, header = nil, button = nil, marker = nil, driver = CreateFrame("Frame") }

-- The header's button for key (the volume button is each skin's own)
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
    local c = btn.FlareUI_Color
    local r, g, b = LightenColor(c.r, c.g, c.b, 0.3)
    btn.FlareUI_Icon:SetVertexColor(r, g, b, c.a)
    GameTooltip:Hide()
    local db = GetDb()
    if db and db.showOnMouse ~= false then
        Chat:ShowChatFrame(SELECTED_CHAT_FRAME or ChatFrame1, db)
    end
end

local function HeaderButtonLeave(btn)
    local c = btn.FlareUI_Color
    btn.FlareUI_Icon:SetVertexColor(c.r, c.g, c.b, c.a)
end

local function HeaderButtonDown(btn) btn.FlareUI_Icon:SetPoint("TOPLEFT", 1, -1) end
local function HeaderButtonUp(btn) btn.FlareUI_Icon:SetPoint("TOPLEFT", 0, 0) end

-- a flashing button (a new invite, say) fades the chat in
local function HeaderFlashShown()
    local db = GetDb()
    if db and db.showOnMessage ~= false then
        Chat:ShowChatFrame(SELECTED_CHAT_FRAME or ChatFrame1, db)
    end
end

local function KillTexture(tex) if tex then tex:SetAlpha(0) end end

function Chat:StyleHeaderButtons(chatFrame)
    if self.isStyling then return end
    self.isStyling = true

    local db = GetDb()
    local target = chatFrame or VisibleSkinHost()
    if target and IsPopped(target) then target = VisibleSkinHost() end   -- the buttons stay on the dock
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

        -- a post-hook: the social button registers for clicks in Blizzard's own OnShow
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
        -- on the skin, so it fades with it
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

        btn.FlareUI_Color = color
        btn.FlareUI_Icon:SetTexture(iconPath)
        btn.FlareUI_Icon:SetVertexColor(color.r, color.g, color.b, color.a)
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

        if isSocial then
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

    local cSocial = db.socialColor or {r=1,g=1,b=1,a=1}
    local cChannel = db.channelColor or {r=1,g=1,b=1,a=1}
    local cMenu = db.menuColor or {r=1,g=1,b=1,a=1}

    SetupBtn(_G.QuickJoinToastButton,   ICON_SOCIAL,   not HeaderButtonShown(db, "social"),  HeaderButtonX(db, "social"),  db.socialY,  db.socialScale,  cSocial, true, "social")
    SetupBtn(_G.ChatFrameChannelButton, ICON_CHANNELS, not HeaderButtonShown(db, "channel"), HeaderButtonX(db, "channel"), db.channelY, db.channelScale, cChannel, false, "channel")
    SetupBtn(_G.ChatFrameMenuButton,    ICON_MENU,     not HeaderButtonShown(db, "menu"),    HeaderButtonX(db, "menu"),    db.menuY,    db.menuScale,    cMenu, false, "menu")
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
        print("|cffff0000FlareUI:|r " .. L["/way is disabled in the chat options."])
        return
    end

    msg = (msg or ""):match("^%s*(.-)%s*$")
    if msg == "" then
        print("|cff00ff00FlareUI:|r " .. L["/way usage:"])
        print("  /way 50.5 40.2  " .. L["(current zone)"])
        print("  /way Elwynn Forest 40 50  " .. L["(named zone)"])
        print("  /way #1429 40 50  " .. L["(map ID)"])
        return
    end

    local zonePart, xStr, yStr = msg:match("^(.*%S)%s+(%d+%.?%d*)%s*[,%s]%s*(%d+%.?%d*)$")
    if not zonePart then xStr, yStr = msg:match("^(%d+%.?%d*)%s*[,%s]%s*(%d+%.?%d*)$") end
    if not xStr or not yStr then
        print("|cffff0000FlareUI:|r " .. L["Invalid coordinates. Try |cffffff00/way|r for usage."])
        return
    end

    local mapID
    if zonePart then
        if zonePart:match("^#%d+$") then
            mapID = tonumber(zonePart:sub(2))
        else
            mapID = GetMapIDByName(zonePart)
            if not mapID then print("|cffff0000FlareUI:|r " .. L["Could not find a map named '%s'."]:format(zonePart)) return end
        end
    else
        mapID = C_Map.GetBestMapForUnit("player")
    end
    if not mapID then print("|cffff0000FlareUI:|r " .. L["Could not determine the current map."]) return end
    if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(mapID) then
        print("|cffff0000FlareUI:|r " .. L["Map pins are not allowed on this map."])
        return
    end

    local x, y = tonumber(xStr) / 100, tonumber(yStr) / 100
    if x > 1 or y > 1 then print("|cffff0000FlareUI:|r " .. L["Coordinates must be between 0 and 100."]) return end

    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)

    local mapInfo = C_Map.GetMapInfo(mapID)
    local mapName = mapInfo and mapInfo.name or ("Map #" .. mapID)
    print(string_format("|cff00ff00FlareUI:|r " .. L["Pin set for %s at %.1f, %.1f"], mapName, tonumber(xStr), tonumber(yStr)))
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

-- %f[%S]: an address has to start a word. Patterns from Chattynator.
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
    copyFrame:Show()
end

-- Copy Line's box for a line too long for a chat message
function Chat.ShowCopyText(text) ShowCopyBox(text) end

-- Blizzard only calls filters with accessible values, so no secret check is needed. A message that
-- already carries a hyperlink is left alone.
local function URLFilter(self, event, msg, ...)
    if type(msg) ~= "string" or msg:find("|H") then return false, msg, ... end
    for _, pattern in ipairs(URL_PATTERNS) do
        msg = msg:gsub(pattern, "|cff00b2ff|Hflareurl:%1|h[%1]|h|r")
    end
    return false, msg, ...
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

function Chat:SetupImprovements()
    local db = GetDb()
    if not db then return end

    if db.enableTT and not SLASH_FLARETT1 then
        SLASH_FLARETT1 = "/tt"
        SlashCmdList["FLARETT"] = function(msg)
            if UnitExists("target") and (UnitIsPlayer("target") or UnitCanCooperate("player", "target")) then
                local name, realm = UnitName("target")
                if not canaccessvalue(name) or not name then return end   -- secret in restricted content
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
    HookLineRewrite()
    Chat:UpdateInstanceBubbles()
    Chat:StyleHeaderButtons()
    DisableQuickJoinToasts()
    AnchorShardNotice()
    if _G.TextToSpeechButton then _G.TextToSpeechButton:Hide(); _G.TextToSpeechButton:SetScript("OnShow", function(s) s:Hide() end) end
end

function Chat:OpenContextMenu(tabButton, chatFrame)
    -- in the Gamepad UI a menu opened from addon code hangs the client; Tab Settings (Y) has these
    if ns.IsGamepadUI() then return end

    MenuUtil.CreateContextMenu(tabButton, function(owner, rootDescription)
        rootDescription:CreateButton(EDIT_MODE or "Edit Mode", function()
            if EditModeManagerFrame then ShowUIPanel(EditModeManagerFrame) end
        end)

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

        rootDescription:CreateButton(L["Chat Settings"], function()
            local ACD = LibStub("AceConfigDialog-3.0", true)
            if ACD then
                ACD:SelectGroup("FlareUI", "chat")
                ACD:Open("FlareUI")
            end
        end)

        rootDescription:CreateButton(L["Filter Settings"], function()
            if ChatConfigFrame then ShowUIPanel(ChatConfigFrame) end
        end)

        if IsPopped(chatFrame) then
            rootDescription:CreateDivider()
            rootDescription:CreateButton(L["Dock"], function() Chat:DockWindow(chatFrame) end)
            rootDescription:CreateButton(chatFrame.isLocked and UNLOCK_WINDOW or LOCK_WINDOW, function()
                FCF_SetLocked(chatFrame, not chatFrame.isLocked)
            end)
        elseif chatFrame:GetID() ~= 1 and chatFrame ~= _G.ChatFrame2 then
            rootDescription:CreateDivider()
            rootDescription:CreateButton(L["Pop Out"], function() Chat:PopOutWindow(chatFrame) end)
        end

        if chatFrame:GetID() ~= 1 then
            rootDescription:CreateDivider()
            rootDescription:CreateButton(CLOSE_CHAT_WINDOW, function() FCF_Close(chatFrame) end)
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

    -- room for the header buttons
    local btnCount = 0
    for _, key in ipairs(HEADER_ORDER) do
        if HeaderButtonShown(db, key) then btnCount = btnCount + 1 end
    end

    if IsPopped(chatFrame) then btnCount = 0 end   -- the header buttons stay on the dock
    local margin = -20 - (btnCount * 30)
    scrollFrame:SetPoint("TOPRIGHT", chatFrame.FlareUI_Skin, "TOPRIGHT", margin, 0)

    for _, btn in ipairs(scrollFrame.buttons) do btn:Hide() end

    local dock = _G.GeneralDockManager
    local dockedFrames = dock and dock.DOCKED_CHAT_FRAMES
    if not dockedFrames then return end
    local popped = IsPopped(chatFrame)
    if popped then dockedFrames = { chatFrame } end

    local prevBtn = nil
    local fontPath, fontSize, fontFlags = GetFontData(db.tabFont)
    local colorDef = db.tabFont.color or {r=1, g=0.8, b=0, a=1}
    local yOffset = db.tabOffsetY or 0
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
                    elseif not IsPopped(self.chatFrame) then   -- a popped window has only its own tab
                        _G.FCF_Tab_OnClick(self.realTab, button)
                        C_Timer.After(0.01, function()
                            Chat:UpdateCustomTabs(_G.ChatFrame1, db)
                            -- scroll the selected tab into view if it is cut off
                            C_Timer.After(0.02, function()
                                if not self:IsShown() then return end
                                local left, right = self:GetLeft(), self:GetRight()
                                local scrollLeft = scrollFrame:GetLeft()
                                if not (left and right and scrollLeft) then return end
                                local scroll = scrollFrame:GetHorizontalScroll()
                                local scrollWidth = scrollFrame:GetWidth()
                                local tabLeft = left - scrollLeft + scroll
                                local tabRight = right - scrollLeft + scroll
                                if tabRight > scroll + scrollWidth then
                                    scrollFrame:SetHorizontalScroll(tabRight - scrollWidth + 10)
                                elseif tabLeft < scroll then
                                    scrollFrame:SetHorizontalScroll(math_max(0, tabLeft - 10))
                                end
                            end)
                        end)
                    end
                end)

                btn:SetScript("OnEnter", function(self)
                    self.Text:SetAlpha(1)
                    GameTooltip:Hide()
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

            local isSelected = popped or FCFDock_GetSelectedWindow(dock) == frame
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
                ApplyFontEffects(fs, font)
            end
            PanelTemplates_TabResize(tab, 10)
        end
    end
    FCF_DockUpdate()
end

local EDIT_BOX_GAP = 1   -- px between the chat window's border and an edit box below / above it

--------------------------------------------------
-- EDIT BOX EXTRAS (on, no options)
-- * Sent history: the last lines you sent (all channels, kept per character). Up and Down, with or
--   without Shift or Alt, step through them one at a time; Down past the newest gives back what
--   you were typing. Blizzard's own list is emptied after each line, so Alt+Up doesn't fight ours.
-- * Inside: while the box is open over the chat's last lines, the lines move up above it, and drop
--   back when it closes. The chat lays its lines out from the bottom up; the first is moved.
--------------------------------------------------
local EditExtras = { SENT_MAX = 50, PUSH_GAP = 2 }

function EditExtras.Sent()
    local char = ns.CharDB()
    char.sentHistory = char.sentHistory or {}
    return char.sentHistory
end

function EditExtras.OnLineSent(eb, text)
    if canaccessvalue(text) and type(text) == "string" and text ~= "" then
        local list = EditExtras.Sent()
        if list[#list] ~= text then
            list[#list + 1] = text
            while #list > EditExtras.SENT_MAX do table.remove(list, 1) end
        end
    end
    eb.FlareUI_HistoryPos, eb.FlareUI_Draft = 0, nil
    pcall(eb.ClearHistory, eb)
end

function EditExtras.OnKeyDown(eb, key)
    if (key ~= "UP" and key ~= "DOWN") or IsControlKeyDown() then return end
    -- the name list under a half-typed whisper uses the arrows itself
    if AutoCompleteBox and AutoCompleteBox:IsShown() and AutoCompleteBox.parent == eb then return end
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

function EditExtras.Setup(eb)
    if eb.FlareUI_EditExtras then return end
    eb.FlareUI_EditExtras = true
    if eb.AddHistoryLine then hooksecurefunc(eb, "AddHistoryLine", EditExtras.OnLineSent) end
    eb:HookScript("OnKeyDown", EditExtras.OnKeyDown)
    eb:HookScript("OnEditFocusGained", function(self)
        local db = GetDb()
        if db and (db.editBoxPosition or "inside") == "inside" then
            local frame = self.chatFrame
            local top = select(5, self:GetPoint(1))
            self.FlareUI_PushedFrame = frame
            EditExtras.Push(frame, (top or 30) + EditExtras.PUSH_GAP)
        end
    end)
    eb:HookScript("OnEditFocusLost", function(self)
        self.FlareUI_HistoryPos, self.FlareUI_Draft = 0, nil
        if self.FlareUI_PushedFrame then
            EditExtras.Push(self.FlareUI_PushedFrame, 0)
            self.FlareUI_PushedFrame = nil
        end
    end)
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

    -- black fill inside the chat's border
    local bgFile   = "Interface\\Buttons\\WHITE8x8"
    local edgeFile = GetBorderFile(db)
    local opacity  = db.editBoxOpacity or 1
    local inset = db.borderInset or 4
    bg:SetBackdrop({ bgFile = bgFile, edgeFile = edgeFile, tile = true, tileSize = 16, edgeSize = ns.BorderEdgeSize(edgeFile, 16), insets = { left = inset, right = inset, top = inset, bottom = inset } })
    bg:SetBackdropColor(0, 0, 0, opacity)
    bg:SetBackdropBorderColor(ns.BORDER_COLOR.r, ns.BORDER_COLOR.g, ns.BORDER_COLOR.b, 1)

    eb:SetHistoryLines(100)
    eb:SetAltArrowKeyMode(false)
    EditExtras.Setup(eb)

    local path, size, flags = GetFontData(db.editBoxFont)
    eb:SetFont(path, size, flags)
    ApplyFontEffects(eb, db.editBoxFont)
    if eb.header then eb.header:SetFont(path, size, flags); ApplyFontEffects(eb.header, db.editBoxFont) end
end

function Chat:SetupVolumeButton(chatFrame, db)
    if not chatFrame.FlareUI_Skin then return end
    if not HeaderButtonShown(db, "volume") or IsPopped(chatFrame) then
        if chatFrame.FlareUI_VolumeBtn then chatFrame.FlareUI_VolumeBtn:Hide() end
        return
    end

    local btn = chatFrame.FlareUI_VolumeBtn
    local function UpdateIcon()
        local vol = tonumber(C_CVar.GetCVar("Sound_MasterVolume")) or 0
        local color = db.volumeColor or { r=1, g=0.82, b=0, a=1 }

        local r, g, b, a = color.r, color.g, color.b, color.a
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
            if SELECTED_CHAT_FRAME then Chat:ShowChatFrame(SELECTED_CHAT_FRAME, db) end
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
        -- keeps Blizzard's gamepad cursor on the edit box, off our tabs and buttons
        if ns.IsGamepadUI() then skin.smartNavigationIgnored = true end
        skin.Separator = skin:CreateTexture(nil, "OVERLAY")
    end

    local padding = db.textPadding or 6
    local headerHeight = db.headerHeight or 24
    skin:ClearAllPoints()
    skin:SetPoint("BOTTOMLEFT", chatFrame, "BOTTOMLEFT", -padding, -padding)
    skin:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", padding, padding + headerHeight)
    skin:SetFrameStrata(chatFrame:GetFrameStrata())
    skin:SetFrameLevel(math_max((chatFrame:GetFrameLevel() or 1) - 1, 0))
    return skin
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
        chatFrame:SetScript("OnUpdate", nil)
    end

    chatFrame:SetFading(false)
    chatFrame:SetTimeVisible(9999)

    -- Blizzard's own alpha changes are overruled by ours
    if not chatFrame.FlareUI_AlphaHooked then
        Chat:SecureHook(chatFrame, "SetAlpha", function(frameParam, alpha)
            if frameParam.FlareUI_IgnoreAlpha then return end
            local chatDb = GetDb()
            local target = chatDb and not chatDb.autoHideEnabled and (chatDb.alphaMax or 1)
                or frameParam.FlareUI_TargetAlpha
            if target and math_abs(alpha - target) > 0.05 then
                frameParam.FlareUI_IgnoreAlpha = true
                frameParam:SetAlpha(target)
                frameParam.FlareUI_IgnoreAlpha = false
            end
        end)
        chatFrame.FlareUI_AlphaHooked = true
    end

    local skin = CreateOrGetSkinFrame(chatFrame, db)

    -- Blizzard's dialog background inside the border picked in the options
    local bgTexture     = LSM:Fetch("background", "Blizzard Dialog Background Dark") or "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"
    local borderTexture = GetBorderFile(db)
    local borderSize    = db.borderSize or 16
    local inset         = db.borderInset or 4
    local opacity       = db.opacity or 1
    local backdrop      = { bgFile = bgTexture, edgeFile = borderTexture, tile = false, tileSize = 0, edgeSize = ns.BorderEdgeSize(borderTexture, borderSize), insets = { left = inset, right = inset, top = inset, bottom = inset } }

    if skin then
        skin:SetBackdrop(backdrop)
        skin:SetBackdropColor(1, 1, 1, opacity)
        local border = ns.BORDER_COLOR
        skin:SetBackdropBorderColor(border.r, border.g, border.b, border.a)

        if db.showSeparator then
            skin.Separator:Show()
            local c = db.separatorColor or {r=1, g=0.82, b=0, a=0.5}
            local tex = SEPARATORS[db.separatorStyle]
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
        -- Blizzard's font size changes are overruled by the chat font option
        Chat:SecureHook(chatFrame, "SetFont", function(frameParam, font, size)
            if frameParam.FlareUI_SettingFont then return end
            local chatDb = GetDb()
            if not (chatDb and chatDb.enabled) then return end
            local myPath, mySize, myFlags = GetFontData(chatDb.chatFont)
            if math_abs(size - mySize) > 0.1 or font ~= myPath then
                frameParam.FlareUI_SettingFont = true
                frameParam:SetFont(myPath, mySize, myFlags)
                ApplyFontEffects(frameParam, chatDb.chatFont)
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
    Chat:ApplyPopState(chatFrame)
    Chat:StyleHeaderButtons()
end

--------------------------------------------------
-- POP-OUT WINDOWS
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
    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
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
    local pad, header = db.textPadding or 6, db.headerHeight or 24
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
-- AUTO-HIDE
-- A window stays up autoHideDelay seconds after the last message, hover, edit or combat, then fades
-- to alphaMin. A message only moves hideAt; one timer per window waits for it. Fades run on one
-- shared OnUpdate that stops when nothing is fading.
--------------------------------------------------
local autoHide = {}   -- chat frame -> { frame, hideAt, timer, expire, fadeFrom, fadeTo, fadeStart, fadeTime }
local fadeDriver = CreateFrame("Frame")
fadeDriver:Hide()

function Chat:SetChatFrameAlpha(chatFrame, alpha)
    if not chatFrame or chatFrame:IsForbidden() then return end
    if chatFrame.FlareUI_TargetAlpha == alpha and chatFrame:GetAlpha() == alpha then return end
    chatFrame.FlareUI_TargetAlpha = alpha
    chatFrame.FlareUI_IgnoreAlpha = true
    chatFrame:SetAlpha(alpha)
    chatFrame.FlareUI_IgnoreAlpha = false
    -- the skin carries the tabs and header buttons
    if chatFrame.FlareUI_Skin then chatFrame.FlareUI_Skin:SetAlpha(alpha) end
end

-- true while something keeps the window up: the mouse, a focused edit box, combat, Edit Mode
function Chat:CheckChatVisibility(chatFrame, db)
    if db.showOnMouse ~= false then
        if chatFrame:IsMouseOver() then return true end
        if chatFrame.FlareUI_Skin and chatFrame.FlareUI_Skin:IsMouseOver() then return true end
        if chatFrame == (SELECTED_CHAT_FRAME or ChatFrame1) then
            for _, name in pairs(HEADER_BLIZZARD) do
                local btn = _G[name]
                if btn and btn:IsMouseOver() then return true end
            end
        end
    end
    if db.showOnEdit ~= false then
        local editBox = chatFrame.editBox
        if editBox and editBox:HasFocus() then return true end
    end
    if db.showOnCombat and InCombatLockdown() then return true end
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
    if not (db and db.enabled and db.autoHideEnabled) then return end
    local remaining = state.hideAt - GetTime()
    if remaining <= 0 and Chat:CheckChatVisibility(state.frame, db) then
        remaining = (db.autoHideDelay or 10) > 0.5 and 1 or 0.1
    end
    if remaining > 0 then
        state.timer = C_Timer.NewTimer(remaining, state.expire)
    else
        FadeTo(state, db.alphaMin or 0, db.fadeOutSpeed or 0)
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
    local alphaMax = db.alphaMax or 1
    if not db.autoHideEnabled then
        if autoHide[chatFrame] then autoHide[chatFrame].fadeTo = nil end
        Chat:SetChatFrameAlpha(chatFrame, alphaMax)
        return
    end
    local state = AutoHideState(chatFrame)
    if state.fadeTo ~= alphaMax and not (state.fadeTo == nil and chatFrame.FlareUI_TargetAlpha == alphaMax) then
        FadeTo(state, alphaMax, db.fadeInSpeed or 0)
    end
    local delay = math_max(0, db.autoHideDelay or 10)
    state.hideAt = GetTime() + (state.fadeTo and state.fadeTime or 0) + delay
    if not state.timer then
        state.timer = C_Timer.NewTimer(state.hideAt - GetTime(), state.expire)
    end
end

--------------------------------------------------
-- 9. EVENT HANDLERS
--------------------------------------------------
function Chat:OnCombatStateChange()
    local db = GetDb()
    if not (db and db.enabled and db.autoHideEnabled and db.showOnCombat) then return end
    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        if cf and cf:IsShown() and not cf:IsForbidden() then
            self:ShowChatFrame(cf, db)
        end
    end
end

function Chat:RefreshForEditMode()
    local db = GetDb()
    if not db or not db.enabled then return end
    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        if cf and cf.FlareUI_Skin and not cf:IsForbidden() then
            self:ShowChatFrame(cf, db)
        end
    end
end

-- the chat comes back after a quest or gossip window
function Chat:OnNPCInteractionEnd()
    if SELECTED_CHAT_FRAME then self:ShowChatFrame(SELECTED_CHAT_FRAME, GetDb()) end
end

--------------------------------------------------
-- 10. AUTO-HIDE SETUP
--------------------------------------------------
-- every message (combat log lines included) lands here, so it returns early when auto-hide is off
local function OnChatMessage(chatFrame)
    UpdateScrollToBottomVisibility(chatFrame)
    local db = GetDb()
    if db and db.autoHideEnabled and db.showOnMessage ~= false then Chat:ShowChatFrame(chatFrame, db) end
end

local function OnChatEnter(chatFrame)
    local db = GetDb()
    if db and db.showOnMouse ~= false then Chat:ShowChatFrame(chatFrame, db) end
end

function Chat:SetupAutoHide(db)
    if not NUM_CHAT_WINDOWS or not db then return end
    if not Chat.autoHideEventsRegistered then
        self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatStateChange")
        self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatStateChange")
        Chat.autoHideEventsRegistered = true
    end

    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame" .. i]
        if frame and not frame:IsForbidden() then
            if not frame.FlareUI_AutoHideHooked then
                frame.FlareUI_AutoHideHooked = true
                Chat:SecureHookScript(frame, "OnEnter", OnChatEnter)
                Chat:SecureHook(frame, "AddMessage", OnChatMessage)
                local editBox = frame.editBox
                if editBox and not editBox.FlareUI_AutoHideHooked then
                    editBox.FlareUI_AutoHideHooked = true
                    Chat:SecureHookScript(editBox, "OnEditFocusGained", function()
                        local chatDb = GetDb()
                        if chatDb and chatDb.showOnEdit ~= false then Chat:ShowChatFrame(frame, chatDb) end
                    end)
                end
            end
            Chat:ShowChatFrame(frame, db)
        end
    end
end

-- Formatting lives in the line rewriter, which reads the options on every line
function Chat:UpdateFilters()
    HookLineRewrite()
    Lines.UpdateLevelEvents()
end

function Chat:Apply(db)
    if not NUM_CHAT_WINDOWS or not db then return end

    if db.hideCombatLog and ChatFrame2 then
        ChatFrame2:UnregisterAllEvents()
        ChatFrame2:SetScript("OnEvent", nil)
    end

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
    self:UpdateTabFonts()
end

-- Blizzard's gamepad chat only works in IM style, so the Gamepad UI switches to it; the player's
-- style comes back in keyboard mode. The CVar is account-wide, so the saved style is too.
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

-- Gamepad UI: LB / RB icons above the header of the chat window that has the pad. Polled: a hook on
-- Blizzard's focus calls would run our code inside its gamepad focus manager.
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

    Chat:KillGeneralDockManager()

    ns.Dialogs["FLAREUI_RENAME_CHAT"] = {
        text = L["Rename Chat Window"],
        button1 = ACCEPT,
        button2 = CANCEL,
        hasEditBox = true,
        maxLetters = 31,
        editText = function(chatFrame) return chatFrame and chatFrame.name or "" end,
        OnAccept = function(chatFrame, text)
            if text and text ~= "" and chatFrame then
                FCF_SetWindowName(chatFrame, text)
                Chat:UpdateCustomTabs(chatFrame, GetDb())
            end
        end,
        hideOnEscape = true,
    }

    self:ScheduleTimer(function() Chat:RefreshAll() end, 0.2)

    -- Shift-Click to Invite
    Chat:SecureHook("SetItemRef", function(link, text, button)
        if not ns.db.profile.chat.shiftInvite then return end
        if IsShiftKeyDown() and button == "LeftButton" and link:sub(1, 6) == "player" then
            local name = link:match("player:([^:]+)")
            if name then C_PartyInfo.InviteUnit(name) end
        end
    end)

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
            end)
        end)

        -- the tab bars follow the dock; the selected window stays shown (and styled, if temporary)
        local function AfterDockTabs()
            local db = GetDb()
            if not db then return end
            for i = 1, NUM_CHAT_WINDOWS do
                local cf = _G["ChatFrame" .. i]
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
                end
            end
        end
        Chat:SecureHook("FCFDock_UpdateTabs", function()
            local db = GetDb()
            if db then HandleCombatLog(db) end
            C_Timer.After(0, AfterDockTabs)
        end)

        Chat:SecureHook("FCFTab_UpdateAlpha", function(tab)
            if not tab or tab:IsForbidden() then return end
            tab:SetAlpha(0)
        end)

        -- A new whisper window does not take the selection from the window being read
        local preventAutoSelect = false

        Chat:SecureHook("FCF_OpenTemporaryWindow", function()
            preventAutoSelect = true
            local dock = _G.GeneralDockManager
            local currentSelected = dock and FCFDock_GetSelectedWindow(dock)

            C_Timer.After(0.15, function()
                preventAutoSelect = false
                local db = GetDb()
                if not db then return end
                StyleNewWindows(db)
                if dock and currentSelected and not currentSelected:IsForbidden() then
                    FCFDock_SelectWindow(dock, currentSelected)
                    currentSelected:Show()
                    _G.SELECTED_CHAT_FRAME = currentSelected
                end
                if _G.ChatFrame1 then Chat:UpdateCustomTabs(_G.ChatFrame1, db) end
            end)
        end)

        hooksecurefunc("FCFDock_SelectWindow", function(dock, chatFrame)
            if preventAutoSelect and chatFrame and chatFrame.isTemporary then
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

    -- Edit Mode keeps the chat shown
    if _G.EditModeManagerFrame and not Chat.editModeHooksAttached then
        Chat:SecureHookScript(_G.EditModeManagerFrame, "OnShow", function() Chat:RefreshForEditMode() end)
        Chat:SecureHookScript(_G.EditModeManagerFrame, "OnHide", function() Chat:RefreshForEditMode() end)
        Chat.editModeHooksAttached = true
    end

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
                    -- secret lines are skipped; canaccessvalue first, before any other test
                    if canaccessvalue(msg) and type(msg) == "string" then
                        messages[#messages + 1] = ColorCode(r, g, b) .. msg .. "|r"
                    end
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

function Chat:RestoreHistory()
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
        local cf = _G["ChatFrame" .. i]
        if cf then Chat:ShowChatFrame(cf, db) end
    end
end
