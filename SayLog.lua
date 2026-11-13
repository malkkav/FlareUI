local _, ns = ...

--------------------------------------------------
-- SAY LOG (/fui saylog), for chasing "a Say line never showed" reports (11-13)
-- While on, every Say and Yell the game sends is noted, and a moment later every chat window that
-- shows that chat type is checked for the line. A line the game sent that no such window shows is
-- printed at once in red, so the player knows when to report it. It only reads, stays on across
-- reloads until stopped, and keeps the last 100 lines.
--   /fui saylog          start or stop
--   /fui saylog report   what was noted (missing lines first)
--   /fui saylog clear    forget it
--------------------------------------------------
local SL = {}
ns.SayLog = SL

local MAX_NOTES = 100
local CHECK_DELAY = 0.5     -- the chat windows add the line on the same event; a moment is plenty
local SEARCH_LINES = 40     -- how far back each window is searched
local WATCHED = { CHAT_MSG_SAY = "SAY", CHAT_MSG_YELL = "YELL" }

local events

local function Say(text) print("|cff00ccffFlareUI saylog:|r " .. text) end

local function Store()
    local global = ns.db and ns.db.global
    if not global then return nil end
    global.sayLog = global.sayLog or { on = false, notes = {} }
    return global.sayLog
end

local function Note(entry)
    local store = Store()
    if not store then return end
    store.notes[#store.notes + 1] = entry
    while #store.notes > MAX_NOTES do table.remove(store.notes, 1) end
end

-- each chat window that is set to show this chat type: its name and frame
local function WindowsFor(group)
    local list = {}
    local max = (Constants and Constants.ChatFrameConstants and Constants.ChatFrameConstants.MaxChatWindows) or 10
    for i = 1, max do
        local frame = _G["ChatFrame" .. i]
        if frame and frame.ContainsMessageGroup then
            local ok, has = pcall(frame.ContainsMessageGroup, frame, group)
            if ok and has then
                local name = FCF_GetChatWindowInfo and FCF_GetChatWindowInfo(i)
                list[#list + 1] = { name = (type(name) == "string" and name ~= "" and name) or ("Window " .. i), frame = frame }
            end
        end
    end
    return list
end

-- whether this window's last lines hold the text (lines another addon can't read are skipped)
local function WindowHas(frame, text)
    local num = frame.GetNumMessages and frame:GetNumMessages() or 0
    for j = num, math.max(1, num - SEARCH_LINES + 1), -1 do
        local msg = frame:GetMessageInfo(j)
        if canaccessvalue(msg) and type(msg) == "string" and msg:find(text, 1, true) then return true end
    end
    return false
end

local function Check(group, sender, text)
    local windows = WindowsFor(group)
    local shown, missing = {}, {}
    for _, w in ipairs(windows) do
        if WindowHas(w.frame, text) then shown[#shown + 1] = w.name else missing[#missing + 1] = w.name end
    end
    local result
    if #windows == 0 then
        result = "no chat window is set to show " .. group
    elseif #missing == 0 then
        result = "shown in " .. table.concat(shown, ", ")
    else
        result = "MISSING from " .. table.concat(missing, ", ")
            .. (#shown > 0 and ("; shown in " .. table.concat(shown, ", ")) or "")
    end
    local short = #text > 60 and (text:sub(1, 57) .. "...") or text
    local line = ("%s %s %s: \"%s\" -> %s"):format(date("%m-%d %H:%M:%S"), group, sender, short, result)
    Note({ line = line, missing = #missing > 0 or #windows == 0 })
    if #missing > 0 or #windows == 0 then Say("|cffff4040" .. line .. "|r") end
end

local function OnEvent(_, event, text, sender)
    local group = WATCHED[event]
    if not group then return end
    -- in a fight or an instance the game can keep chat text from addons: noted, not checked
    if not (canaccessvalue(text) and canaccessvalue(sender) and type(text) == "string") then
        Note({ line = date("%m-%d %H:%M:%S") .. " " .. group .. " (text hidden from addons, not checked)" })
        return
    end
    local who = type(sender) == "string" and sender or "?"
    C_Timer.After(CHECK_DELAY, function() Check(group, who, text) end)
end

local function Start(quiet)
    local store = Store()
    if not store then return end
    store.on = true
    events = events or CreateFrame("Frame")
    for event in pairs(WATCHED) do events:RegisterEvent(event) end
    events:SetScript("OnEvent", OnEvent)
    if not quiet then Say("on: every Say and Yell is checked. A line that never reached your chat shows here in red. /fui saylog again stops.") end
end

local function Stop()
    local store = Store()
    if store then store.on = false end
    if events then events:UnregisterAllEvents() end
    Say("off. /fui saylog report lists what was noted.")
end

function SL.Command(arg)
    arg = (arg or ""):match("^%s*(.-)%s*$"):lower()
    local store = Store()
    if not store then return end
    if arg == "report" then
        if #store.notes == 0 then Say("nothing noted yet.") return end
        local missing = 0
        for _, note in ipairs(store.notes) do if note.missing then missing = missing + 1 end end
        Say(("%d lines noted, %d missing:"):format(#store.notes, missing))
        for _, note in ipairs(store.notes) do if note.missing then print("  |cffff4040" .. note.line .. "|r") end end
        for _, note in ipairs(store.notes) do if not note.missing then print("  " .. note.line) end end
    elseif arg == "clear" then
        wipe(store.notes)
        Say("cleared.")
    elseif store.on then
        Stop()
    else
        Start()
    end
end

-- still on from an earlier session: back on, quietly
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    local store = Store()
    if store and store.on then Start(true) end
end)
