-- Exercise full-module chat post-hooks and the per-character conversation history.
local function noop() end
local env = setmetatable({}, { __index = _G })
env._G = env

local timestamps = "[%M:%S] "
local now, dateReads = 1000, 0
local secret = {}
env.time = function() return now end
env.GetTime = function() return now - 900 end
env.canaccessvalue = function(value) return value ~= secret end
env.canaccesstable = env.canaccessvalue
env.canaccessallvalues = function(...)
    for i = 1, select("#", ...) do
        if select(i, ...) == secret then return false end
    end
    return true
end
env.TimeUtil = {
    BetterDate = function(format, at)
        dateReads = dateReads + 1
        return os.date("!" .. format, at)
    end,
}
env.Constants = { ChatFrameConstants = { MaxChatWindows = 3 } }
env.LibStub = function() return { Embed = noop } end
env.geterrorhandler = function() return error end

local cvars = { showTimestamps = "%M:%S ", chatBubbles = "1", chatBubblesParty = "0", chatStyle = "classic" }
local cvarCallbacks = {}
env.C_CVar = {
    GetCVar = function(name) return cvars[name] end,
    SetCVar = function(name, value)
        cvars[name] = value
        if cvarCallbacks[name] then cvarCallbacks[name]() end
    end,
}
env.CVarCallbackRegistry = {
    RegisterCallback = function(_, event, cb) cvarCallbacks[event] = cb end,
}
local linkHandler, events = nil, {}
local timers = {}
env.C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
local function runTimers()
    local due = timers
    timers = {}
    for _, callback in ipairs(due) do callback() end
end
env.ChatFrameUtil = {
    GetTimestampFormat = function() return timestamps end,
    -- nothing of ours goes into Blizzard's handler: what a filter hands back, it goes on with
    AddSenderNameFilter = function() error("no sender name filter") end,
    AddMessageEventFilter = function() error("no message filter") end,
}
env.EventRegistry = {
    RegisterCallback = function(_, event, cb)
        assert(not events[event], "register each hover callback once")
        events[event] = cb
    end,
}
env.LinkUtil = {
    IsLinkHandlerRegistered = function(kind) return kind == "flareurl" and linkHandler ~= nil end,
    RegisterLinkHandler = function(kind, cb)
        assert(kind == "flareurl" and not linkHandler)
        linkHandler = cb
    end,
}
env.CreateFrame = function()
    local frame = { events = {}, scripts = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterAllEvents() self.events = {} end
    function frame:SetScript(event, callback) self.scripts[event] = callback end
    return frame
end
env.hooksecurefunc = function(target, method, callback)
    if type(target) == "string" then target, method, callback = env, target, method end
    local original = assert(target[method], method)
    target[method] = function(...)
        original(...)
        callback(...)
    end
end

local function window()
    local frame = { history = {}, name = "General" }
    frame.historyBuffer = {
        GetEntryAtIndex = function(_, index) return frame.history[#frame.history - index + 1] end,
    }
    function frame:AddMessage(message, r, g, b, id, _, _, event, args)
        self.history[#self.history + 1] = {
            message = message, r = r, g = g, b = b, id = id, event = event, args = args, timestamp = env.GetTime(),
            extraData = { id, nil, nil, event, args, n = 5 },
        }
    end
    function frame:BackFillMessage(message, r, g, b, id)
        table.insert(self.history, 1, { message = message, r = r, g = g, b = b, id = id })
    end
    function frame:GetNumMessages() return #self.history end
    function frame:GetMessageInfo(index)
        local line = self.history[index]
        return line.message, line.r, line.g, line.b, line.id, nil, nil, line.event
    end
    function frame:IsForbidden() return false end
    function frame:LastLine() return self.history[#self.history].message end
    return frame
end
env.ChatFrame1, env.ChatFrame2, env.ChatFrame3 = window(), window(), window()
local general, combat, guild = env.ChatFrame1, env.ChatFrame2, env.ChatFrame3
env.CHAT_FRAMES = { "ChatFrame1", "ChatFrame2", "ChatFrame3" }
env.FCF_OpenTemporaryWindow = function()
    env.ChatFrame11 = window()
    env.ChatFrame11.isTemporary, env.ChatFrame11.chatType = true, "BN_WHISPER"
    table.insert(env.CHAT_FRAMES, "ChatFrame11")
end
env.CHAT_SAY_GET = "%s says: "
env.CHAT_WHISPER_GET = "%s whispers: "
env.CHAT_WHISPER_INFORM_GET = "To %s: "
env.CHAT_MONSTER_SAY_GET = "%s says: "
env.CHAT_MONSTER_WHISPER_GET = "%s whispers: "
env.CHAT_MSG_RAID_WARNING = "Raid Warning"
env.ChatTypeInfo = { SAY = { colorNameByClass = false }, SYSTEM = { id = 1 } }

local playerReads, levelReads = 0, 0
env.GetPlayerInfoByGUID = function(guid)
    playerReads = playerReads + 1
    if guid == "Player-1" then return "Mage", "MAGE", "Human", "Human", 3, "Frost", "Realm" end
    if guid == "Player-2" then return "Mage", "MAGE", "Human", "Human", 3, "Ember", "", 52 end
    if guid == "Player-3" then return "Mage", "MAGE", "Human", "Human", 3, "Hush", "", secret end
end
local uncensored
env.C_ChatInfo = { UncensorChatLine = function(lineID) uncensored = lineID end }
env.UnitTokenFromGUID = function(guid) if guid == "Player-1" then return "party1" end end
env.UnitExists = function(unit) return unit == "party1" end
env.UnitIsPlayer = env.UnitExists
env.UnitGUID = function() return "Player-1" end
env.UnitName = function() return "Frost" end
env.UnitLevel = function() levelReads = levelReads + 1; return 47 end
env.C_ClassColor = {
    GetClassColor = function(class)
        if class == "MAGE" then
            return { WrapTextInColorCode = function(_, value) return "|cff66bbee" .. value .. "|r" end }
        end
    end,
}
env.GetQuestDifficultyColor = function() return { r = 1, g = 0, b = 0 } end
env.C_Item = { GetItemIconByID = function(id) if id == 2589 then return 100 end end }
env.C_Spell = { GetSpellTexture = function(id) if id == 116 then return 200 end end }
env.C_Texture = { GetAtlasInfo = function(atlas) return atlas ~= "unavailable" and {} or nil end }
env.GetRaceAtlas = function(race, sex) return race .. "-" .. sex end
env.GetClassAtlas = function(class) return class == "MAGE" and "mage" or "unavailable" end

local instance, pad, otherAddon, clashing = false, false, false, nil
env.IsInInstance = function() return instance end
env.C_AddOns = {
    IsAddOnLoaded = function(name) return name == "Chattynator" and otherAddon or name == clashing end,
    GetAddOnMetadata = function(_, key) if key == "Title" then return "Another chat" end end,
}
local profile = { enabled = true, saveHistory = true }
local character = {}
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    modules = {},
    db = { profile = { chat = profile }, global = {} },
    CharDB = function() return character end,
    IsGamepadUI = function() return pad end,
}
setfenv(assert(loadfile("Modules/Chat.lua")), env)("FlareUI", ns)
local chat = ns.Chat
assert(ns.modules.Chat == chat and chat:ShouldLoad())
chat:SetupImprovements()
chat:SetupImprovements()

local say = "|Hplayer:Frost-Realm:0:SAY|h[Frost-Realm]|h"
local args = { [2] = "Frost-Realm", [12] = "Player-1" }
local function add(frame, message, kind, eventArgs)
    frame:AddMessage(message, 0.2, 0.3, 0.4, 8, nil, nil, "CHAT_MSG_" .. kind, eventArgs)
    return frame:LastLine()
end

local plainSay = say .. " says: hello"
local rawSay = say
assert(add(general, plainSay, "SAY", args) == plainSay, "options off preserve Blizzard's line")
profile.formatPlayer, profile.showLevel = true, true
-- the name is dressed inside the line's own player link, brackets and link kept
local head = "|Hplayer:Frost-Realm:0:SAY|h"
local dressed = head .. "[|cffff0000(47)|r |cff66bbeeFrost|r]|h"
assert(add(general, "|Hchannel:channel:3|h[3. World]|h " .. say .. ": yo", "CHANNEL", args):find(dressed, 1, true))
local colored = add(general, head .. "[|cff00ffffFrost-Realm|r]|h whispers: hey", "WHISPER", args)
assert(colored:find(head .. "[|cffff0000(47)|r |cff00ffffFrost|r]|h", 1, true), "preserve existing class color while stripping realm")
assert(levelReads == 1, "known player levels use the session cache")
assert(add(general, say .. " did a thing", "SYSTEM", args) == say .. " did a thing")
-- no link, a hidden name, hidden arguments: the line stays
assert(add(general, "no link: yo", "YELL", args) == "no link: yo")
assert(add(general, say .. " yells: yo", "YELL", secret) == say .. " yells: yo")
-- the level comes with the player's info; a hidden or missing one falls back to what was seen
profile.formatPlayer = false
local function levelOf(name, guid)
    return add(general, "|Hplayer:" .. name .. ":9:SAY|h[" .. name .. "]|h yells: yo", "YELL", { [2] = name, [12] = guid })
end
assert(levelOf("Ember", "Player-2"):find("[|cffff0000(52)|r Ember]", 1, true), "the info's level, never seen before")
assert(not levelOf("Hush", "Player-3"):find("(", 1, true), "a hidden level is left out")
assert(not levelOf("Nobody", "Player-4"):find("(", 1, true))
profile.formatPlayer = true
-- from here the dressed name is what the windows show
say = dressed

local nativeStamp = os.date("!" .. timestamps, now - 1)
local oldStampLine = nativeStamp .. plainSay
local labeled = nativeStamp .. "|Hchannel:SAY|h[Say]|h " .. say .. " hello"
assert(add(general, oldStampLine, "SAY", args) == labeled, "keep Blizzard's timestamp ahead of clickable Say")
local firstReads = dateReads
assert(add(guild, oldStampLine, "SAY", args) == labeled and dateReads == firstReads)

profile.shortChannels, profile.channelNames = true, "short"
now = now + 1
assert(add(general, plainSay, "SAY", args) == "|Hchannel:SAY|h[S]|h " .. say .. " hello")
local trade = "|Hchannel:channel:2|h[2. Trade - City]|h offer"
assert(add(general, trade, "CHANNEL") == "|Hchannel:channel:2|h[2. Trade]|h offer")
profile.channelNames = "number"
now = now + 1
assert(add(general, trade, "CHANNEL") == "|Hchannel:channel:2|h[2]|h offer")
assert(add(general, "[Raid Warning] move", "RAID_WARNING") == "[RW] move")
assert(add(guild, "|Hchannel:GUILD|h[Guild]|h hey", "GUILD") == "|Hchannel:GUILD|h[G]|h hey")

profile.formatNPC, profile.whisperMarkers = true, true
assert(add(general, "Guard says: move along", "MONSTER_SAY", { [2] = "Guard" })
    == "|cffFFB033[Guard]|r move along")
assert(add(general, "An unknown NPC says: hi", "MONSTER_SAY", { [2] = secret })
    == "An unknown NPC says: hi")
local ally = " |A:alliance:12:12|a"
assert(add(general, rawSay .. ally .. " whispers: hi", "WHISPER", args)
    == "|cff40ff40>|r " .. say .. ally .. ": hi")
assert(add(general, "To " .. rawSay .. ": hi", "WHISPER_INFORM", args)
    == "|cffff6060<|r " .. say .. ": hi")
assert(add(general, secret, "SAY", args) == secret)
assert(add(general, rawSay .. " whispers: hi", "WHISPER", secret) == rawSay .. " whispers: hi")

profile.betterTimestamps, profile.raceIcons, profile.classIcons, profile.linkIcons = true, true, true, true
local item = "|Hitem:2589::::::::|h[Linen Cloth]|h"
local spell = "|Hspell:116|h[Frostbolt]|h"
local existingItem = "|Hitem:2589|h|T888:8:8|t[Linen Cloth]|h"
local decoratedLine = add(general, rawSay .. " says: " .. item .. " " .. spell .. " " .. existingItem, "SAY", args)
assert(decoratedLine:find("|cff00B2FF<" .. os.date("!%M:%S", now) .. ">|r ", 1, true) == 1)
assert(decoratedLine:find("|A:human-female:14:14:0:-1|a|A:mage:14:14:0:-1|a " .. say, 1, true))
assert(decoratedLine:find("|h|T100:14:14:0:-1|t[Linen Cloth]|h", 1, true))
assert(decoratedLine:find("|h|T200:14:14:0:-1|t[Frostbolt]|h", 1, true))
assert(decoratedLine:find(existingItem, 1, true), "retain an existing item icon")
local previousReads = playerReads
profile.formatPlayer, profile.showLevel = false, false   -- (the name and level read it too)
add(general, rawSay .. " says: another line", "SAY", args)
assert(playerReads == previousReads, "reuse known sender icon markup")
profile.formatPlayer, profile.showLevel = true, true
timestamps = nil
env.C_CVar.SetCVar("showTimestamps", "none")
assert(add(general, "unknown icon", "SYSTEM"):find("<" .. os.date("!%H:%M", now) .. ">", 1, true))
local sample = chat.SampleLine(profile, { "SAY", "Healbot", "50% ready", ago = 2 }, 12)
assert(sample:find("|A:nightelf-female:12:12:0:-1|a", 1, true) and sample:find("50% ready", 1, true))
assert(not sample:find("unavailable", 1, true) and #chat.SampleLines(true) == 2 and #chat.SampleLines(false) == 7)

-- web addresses become links in the window's own line, every option off included
local options = { "formatPlayer", "showLevel", "shortChannels", "formatNPC", "whisperMarkers", "betterTimestamps", "raceIcons", "classIcons", "linkIcons" }
local kept = {}
for _, key in ipairs(options) do kept[key], profile[key] = profile[key], nil end
local function links(text, kind) return add(general, text, kind or "SAY") end
assert(links("say hello") == "say hello")
local url = "[https://example.com/path],"
local linked = "[|cff00b2ff|Hflareurl:https://example.com/path|h[https://example.com/path]|h|r],"
assert(links(url .. " " .. item) == linked .. " " .. item)
assert(links("|Hitem:2589|h[www.example.com]|h " .. url) == "|Hitem:2589|h[www.example.com]|h " .. linked)
for _, kind in ipairs({ "GUILD_DISCORD", "COMMUNITIES_CHANNEL", "PARTY_GUIDE", "WHISPER" }) do
    assert(links(url, kind) == linked, kind)
end
assert(links(url, "MONSTER_SAY") == url, "not on lines no person wrote")
assert(links("|TIcon:14|thttps://a.example/x") == "|TIcon:14|t|cff00b2ff|Hflareurl:https://a.example/x|h[https://a.example/x]|h|r", "after an icon")
-- the game's system lines have no event; an addon's print has no chat type either and stays
general:AddMessage(url, 1, 1, 0, 1)
assert(general:LastLine() == linked)
general:AddMessage(url, 1, 1, 1)
assert(general:LastLine() == url)
-- a censored line shown: Blizzard's own text is rewritten, with the time it came
profile.formatPlayer, profile.betterTimestamps = true, true
local censoredArgs = { [2] = "Frost-Realm", [11] = 77, [12] = "Player-1" }
add(general, rawSay .. " says: |Hcensoredmessage:77|h[Show]|h", "SAY", censoredArgs)
local cameAt = now
now = now + 300
env.C_ChatInfo.UncensorChatLine(77)
assert(uncensored == 77)
general.history[#general.history].message = rawSay .. " says: shown"
runTimers()
assert(general:LastLine():find("<" .. os.date("!%H:%M", cameAt) .. ">", 1, true) and general:LastLine():find("66bbeeFrost", 1, true)
    and general:LastLine():find("shown", 1, true))
env.C_ChatInfo.UncensorChatLine(78)
env.C_ChatInfo.UncensorChatLine(secret)
runTimers()
for _, key in ipairs(options) do profile[key] = kept[key] end
assert(chat.PlainLine("|cnNORMAL_FONT_COLOR:" .. linked .. " |A:test:12:12|a|| |K1|k") == "[[https://example.com/path]], | ???")
assert(chat.PlainLine("|K1|k: ||World |Wwrapped text|w", { ["|K1|k"] = "BattleFriend" }) == "BattleFriend: |World wrapped text")

local tooltip = { visible = false }
function tooltip:SetOwner(owner, anchor) self.owner, self.anchor = owner, anchor end
function tooltip:SetHyperlink(link)
    assert(link ~= "item:bad")
    self.link = link
end
function tooltip:IsOwned(owner) return self.owner == owner end
function tooltip:Show() self.visible = true end
function tooltip:Hide() self.visible = false end
env.GameTooltip = tooltip
local enter, leave = events["ChatFrame.OnHyperlinkEnter"], events["ChatFrame.OnHyperlinkLeave"]
enter(nil, general, secret)
enter(nil, general, "flareurl:https://example.com")
assert(not tooltip.visible)
enter(nil, general, "item:2589")
assert(tooltip.visible and tooltip.link == "item:2589" and tooltip.anchor == "ANCHOR_CURSOR")
tooltip.owner = guild
leave()
assert(tooltip.visible, "leave doesn't hide a different window's tooltip")
enter(nil, general, "spell:116")
leave()
assert(not tooltip.visible)
enter(nil, general, "item:bad")
assert(not tooltip.visible, "invalid tooltip links are handled without escaping the hook")

-- Conversation-only history merges open pop-out whispers and normalizes session-local Battle.net names.
general.history, guild.history, combat.history = {}, {}, {}
env.FCF_OpenTemporaryWindow()
local whisper = env.ChatFrame11
cvars.whisperMode = "popout"
env.BNGetNumFriends = function() return 1 end
env.C_BattleNet = {
    GetFriendAccountInfo = function() return { accountName = "|K1|k", battleTag = "BattleFriend#1234" } end,
}
local firstAt = now
add(general, "First message", "GUILD")
add(general, "First message", "GUILD")
add(general, "Got two silver", "MONEY")
add(general, secret, "PARTY")
add(combat, "Skip the Combat Log", "PARTY")
now = now + 2
local knownWhisper = "hello |HBNplayer:123|h[|K1|k]|h"
assert(add(whisper, knownWhisper, "BN_WHISPER") ~= knownWhisper, "new temporary windows receive the line hook")
add(whisper, "skip |K99|k", "BN_WHISPER")
now = now + 2
add(general, "Last message", "GUILD")
chat:SaveHistory()
local saved = character.chatHistory
assert(#saved[1] == 3 and saved[2] == nil and saved[3] == nil)
assert(saved[1][1][1] == "First message" and saved[1][1][6] == firstAt and saved[1][1][7] == "CHAT_MSG_GUILD")
assert(saved[1][2][1] == "hello [BattleFriend]" and saved[1][2][6] == firstAt + 2)
assert(saved[1][3][1] == "Last message" and saved[1][3][6] == firstAt + 4)

general.history = {}
saved[3] = { "legacy plain text", false }
now = now + 20
add(general, "Current message", "GUILD")
chat:RestoreHistory()
assert(#general.history == 5 and general.history[1].message:find("First message", 1, true))
assert(general.history[4].message:find("Saved history ends here", 1, true))
assert(general.history[5].message:find("Current message", 1, true))
assert(guild.history[1].message == "legacy plain text")
whisper.inUse = false
chat:SaveHistory()
-- links that mean something only this session don't come back: line numbers, censored buttons, Discord users
do
    local before = general.history
    local wasSaved = character.chatHistory
    general.history = {}
    for _, key in ipairs(options) do kept[key], profile[key] = profile[key], nil end
    now = now + 5
    add(general, "|Hplayer:Frost:4321:GUILD:|h[Frost]|h: hi", "GUILD")
    now = now + 1
    add(general, "|Hplayer:Frost:4322:SAY:|h[Frost]|h: |Hcensoredmessage:4322|h[Show]|h |Hreportcensoredmessage:4322|h[Report]|h", "SAY")
    now = now + 1
    add(general, "|Hdiscorduser:5:6:7:GUILD:|h[Pal]|h: yo", "GUILD_DISCORD")
    chat:SaveHistory()
    local lines = character.chatHistory[1]
    assert(#lines == 3 and lines[1][1] == "|Hplayer:Frost:0:GUILD:|h[Frost]|h: hi")
    assert(lines[2][1] == "|Hplayer:Frost:0:SAY:|h[Frost]|h: [Show] [Report]")
    assert(lines[3][1] == "[Pal]: yo" and lines[3][7] == "CHAT_MSG_GUILD_DISCORD", "Discord guild chat is saved")
    -- lines saved by an older version are settled as they come back
    general.history = {}
    character.chatHistory = { { { "|Hplayer:Old:99:SAY:|h[Old]|h: hey", 1, 1, 1, false, now, "CHAT_MSG_SAY" }, "|Hplayer:Older:98:SAY:|h[Older]|h" } }
    chat:RestoreHistory()
    assert(general.history[1].message:find("|Hplayer:Old:0:SAY:", 1, true) and general.history[2].message == "|Hplayer:Older:0:SAY:|h[Older]|h")
    for _, key in ipairs(options) do profile[key] = kept[key] end
    general.history, character.chatHistory = before, wasSaved
end
assert(#character.chatHistory[1] == 4 and character.chatHistory[1][1][6] == firstAt,
    "saving restored lines preserves their event and original server time")
profile.saveHistory = false
chat:SaveHistory()
assert(not character.chatHistory)

instance, profile.hideBubblesInInstance = true, true
chat:UpdateInstanceBubbles()
chat:UpdateInstanceBubbles()
assert(cvars.chatBubbles == "0" and cvars.chatBubblesParty == "0")
assert(ns.db.global.hiddenBubbles.chatBubbles == "1")
pad = true
chat:ApplyGamepadChatStyle()
chat:ApplyGamepadChatStyle()
assert(cvars.chatStyle == "im" and ns.db.global.chatStyleBeforeGamepad == "classic")
instance, pad = false, false
chat:UpdateInstanceBubbles()
chat:ApplyGamepadChatStyle()
assert(cvars.chatBubbles == "1" and cvars.chatBubblesParty == "0" and not ns.db.global.hiddenBubbles)
assert(cvars.chatStyle == "classic" and not ns.db.global.chatStyleBeforeGamepad)
instance, pad = true, true
chat:UpdateInstanceBubbles()
chat:ApplyGamepadChatStyle()
chat.otherAddon, otherAddon = nil, true
assert(not chat:ShouldLoad() and chat:GetOtherChatAddon() == "Another chat")
assert(cvars.chatStyle == "classic" and cvars.chatBubbles == "1", "competing chat addon restores original settings")

-- Chat Style picked in the panel: written once as the session ends, never live
ns.db.global.chatStyleWanted = "im"
chat.ApplyWantedChatStyle()
assert(cvars.chatStyle == "im" and not ns.db.global.chatStyleWanted)
ns.db.global.chatStyleWanted = "bogus"
chat.ApplyWantedChatStyle()
assert(cvars.chatStyle == "im" and not ns.db.global.chatStyleWanted)
-- in the Gamepad UI the pick becomes the keyboard style kept for after it
ns.db.global.chatStyleBeforeGamepad, ns.db.global.chatStyleWanted = "im", "classic"
chat.ApplyWantedChatStyle()
assert(cvars.chatStyle == "im" and ns.db.global.chatStyleBeforeGamepad == "classic")
ns.db.global.chatStyleBeforeGamepad, cvars.chatStyle = nil, "classic"

chat.otherAddon, otherAddon = nil, false
-- a hidden line: the time in front (Better Timestamps, Blizzard's own stamps off), the text never read
do
    local hiddenText = setmetatable({}, { __concat = function(a, b) return { stamp = a, text = b } end })
    local readable = env.canaccessvalue
    env.canaccessvalue = function(value) return value ~= hiddenText and not (type(value) == "table" and value.stamp) and readable(value) end
    local function hidden(kind)
        general:AddMessage(hiddenText, 1, 1, 1, 8, nil, nil, kind)
        return general:LastLine()
    end
    profile.betterTimestamps, timestamps = true, nil
    env.C_CVar.SetCVar("showTimestamps", "none")
    local line = hidden("CHAT_MSG_PARTY")
    assert(type(line) == "table" and line.text == hiddenText and line.stamp:find("<" .. os.date("!%H:%M", now) .. ">", 1, true))
    assert(hidden("OTHER") == hiddenText and hidden(nil) == hiddenText and hidden(secret) == hiddenText, "chat lines only")
    profile.betterTimestamps = false
    assert(hidden("CHAT_MSG_PARTY") == hiddenText)
    profile.betterTimestamps, timestamps = true, "[%M:%S] "
    env.C_CVar.SetCVar("showTimestamps", "%M:%S ")
    assert(hidden("CHAT_MSG_PARTY") == hiddenText, "Blizzard's stamp is in it already")
    timestamps = nil
    env.C_CVar.SetCVar("showTimestamps", "none")
    getmetatable(hiddenText).__concat = function() error("attempt to concatenate a secret value") end
    assert(hidden("CHAT_MSG_PARTY") == hiddenText, "refused: the line stays")
    env.canaccessvalue = readable
end

-- the last conversation is kept through a lot of loot
do
    for _, key in ipairs(options) do profile[key] = nil end
    general.history = {}
    add(general, "before the loot", "GUILD")
    for i = 1, 200 do add(general, "You loot " .. i, "LOOT") end
    profile.saveHistory = true
    chat:SaveHistory()
    assert(#character.chatHistory[1] == 1 and character.chatHistory[1][1][1] == "before the loot")
    for i = 1, 200 do now = now + 1; add(general, "line " .. i, "GUILD") end
    chat:SaveHistory()
    assert(#character.chatHistory[1] == 128 and character.chatHistory[1][128][1] == "line 200")
    profile.saveHistory = false
    chat:SaveHistory()
end

-- an addon that changes the same windows: named in the settings, said once in the chat
do
    local said = {}
    env.print = function(text) said[#said + 1] = text end
    assert(not chat:GetClashingChatAddon())
    chat:WarnOfClash()
    clashing = "Prat-3.0"
    assert(chat:GetClashingChatAddon() == "Another chat")
    chat:WarnOfClash()
    chat:WarnOfClash()
    assert(#said == 1 and said[1]:find("Another chat changes the chat too", 1, true) and ns.db.global.chatClashSaid["Prat-3.0"])
    clashing = "Chatter"
    chat:WarnOfClash()
    assert(#said == 2, "once for each addon")
end

print("PASS: chat rewrites, safe link filters, saved conversations and CVar restoration")
