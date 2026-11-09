local _, ns = ...

--------------------------------------------------
-- TAINT WATCH (/fui taint), for chasing Gamepad UI bugs
-- The game's taint log breaks post-hooks on Forever, so this watches instead: while it runs, the
-- fields of Blizzard's controller managers are checked with issecurevariable twice a second, in
-- and out of fights, and the first time a field turns insecure it is noted with the addon the game
-- blames and what was going on (a fight starting or ending, a blocked action). Blocked and forbidden
-- actions are noted too. It only reads, and runs only for the session it is started in.
--   /fui taint          start or stop watching
--   /fui taint report   what was noted (kept across sessions, the last 100)
--   /fui taint clear    forget it
--------------------------------------------------
local TW = {}
ns.TaintWatch = TW

local MAX_NOTES = 100
local INTERVAL = 0.5

-- name -> the table, looked up each time (their addons load on demand)
local WATCHED = {
    { "FrameControlsManager", function() return GamepadMode and GamepadMode.FrameControlsManager end },
    { "InputBindingManager", function() return GamepadSharedUtility and GamepadSharedUtility.InputBindingManager end },
    { "GamepadMainActionBarFrame", function() return _G.GamepadMainActionBarFrame end },
    { "PageUnit", function() return _G.GamepadMainActionBarFrame and _G.GamepadMainActionBarFrame.PageUnit end },
    { "SmartNavigation", function() return _G.SmartNavigation end },
    { "GamepadTargetLogic", function() return _G.GamepadTargetLogic end },
    { "GroupTargeting", function() return _G.GroupTargeting end },
    { "GamepadRadial", function() return _G.GamepadRadial end },
    { "GamepadPersistentInputLegend", function() return _G.GamepadPersistentInputLegend end },
}

local running, ticker, events
local seen = {}   -- "Table.field" -> true once noted this session

local function Say(text) print("|cff00ccffFlareUI taint:|r " .. text) end

local function Notes()
    local global = ns.db and ns.db.global
    if not global then return {} end
    global.taintWatch = global.taintWatch or {}
    return global.taintWatch
end

local function Note(text)
    local notes = Notes()
    notes[#notes + 1] = date("%m-%d %H:%M:%S") .. (InCombatLockdown() and " [combat] " or " ") .. text
    while #notes > MAX_NOTES do table.remove(notes, 1) end
    Say(text)
end

local function Scan(trigger)
    for _, watched in ipairs(WATCHED) do
        local name, get = watched[1], watched[2]
        local t = get()
        if type(t) == "table" then
            for key in pairs(t) do
                if type(key) == "string" then
                    local secure, blamed = issecurevariable(t, key)
                    local id = name .. "." .. key
                    if not secure and not seen[id] then
                        seen[id] = true
                        Note(("%s is tainted (by %s)%s"):format(id, tostring(blamed or "?"),
                            trigger and (", after " .. trigger) or ""))
                    end
                end
            end
        end
    end
end

local function Start()
    if running then return end
    running = true
    wipe(seen)
    events = events or CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ADDON_ACTION_BLOCKED",
                             "ADDON_ACTION_FORBIDDEN", "GAME_PAD_ACTIVE_CHANGED" }) do
        pcall(events.RegisterEvent, events, event)
    end
    events:SetScript("OnEvent", function(_, event, addon, func)
        if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
            Note(("%s: %s by %s"):format(event == "ADDON_ACTION_BLOCKED" and "blocked" or "forbidden",
                tostring(func or "?"), tostring(addon or "?")))
        end
        Scan(event)
    end)
    ticker = C_Timer.NewTicker(INTERVAL, function() Scan(nil) end)
    Scan("start")
    Say("watching (" .. (ns.IsGamepadUI() and "Gamepad mode" or "keyboard and mouse") .. "). /fui taint again stops.")
end

local function Stop()
    if not running then return end
    running = false
    if ticker then ticker:Cancel() ticker = nil end
    if events then events:UnregisterAllEvents() end
    Say("stopped. /fui taint report lists what was noted.")
end

function TW.Command(arg)
    arg = (arg or ""):match("^%s*(.-)%s*$"):lower()
    if arg == "report" then
        local notes = Notes()
        if #notes == 0 then Say("nothing noted.") return end
        for _, line in ipairs(notes) do print("  " .. line) end
    elseif arg == "clear" then
        wipe(Notes())
        Say("cleared.")
    elseif running then
        Stop()
    else
        Start()
    end
end
