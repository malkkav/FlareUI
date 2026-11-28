-- (Malkkav 11-28) a new install starts on Blizzard's Classic chat style; an old account keeps its own.
-- Loads the real Core.lua and Import.lua and runs FlareUI's load event, as the TOC does.
local function start(saved, cvar)
    local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
    local env = ui.env
    env.print = function() end
    env.DEFAULT_CHAT_FRAME = { AddMessage = function() end }
    env.C_AddOns = { GetAddOnMetadata = function() return "7.1.3" end }
    env.SlashCmdList = {}
    env.GetLocale = function() return "enUS" end
    env.GetBuildInfo = function() return "1.16", "12345" end
    env.GetRealmName = function() return "Forever" end
    env.UnitFactionGroup = function() return "Alliance" end
    env.UnitRace = function() return "Human", "Human" end
    env.UnitLevel = function() return 1 end
    env.GetCurrentRegion = function() return 1 end
    env.GetCurrentRegionName = function() return "US" end
    env.strlenutf8 = string.len
    env.UnitNameUnmodified = function() return "Alba" end
    env.UnitClass = function() return "Mage", "MAGE" end
    env.UnitGUID = function() return "Player-1" end
    env.canaccessvalue = function() return true end
    env.securecallfunction = function(callback, ...) return callback(...) end
    env.date = function() return "2026-11-28 12:00" end
    env.C_CVar = { GetCVar = function(name) return name == "chatStyle" and cvar or nil end }
    local ns = { L = setmetatable({}, { __index = function(_, key) return key end }), ShowDialog = function() end }
    for _, path in ipairs({ "LoadCheck.lua", "Libs/LibStub/LibStub.lua", "Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua",
        "Libs/AceDB-3.0/AceDB-3.0.lua" }) do
        ui:load(path, ns)
    end
    env.LibStub:NewLibrary("FlareEditMode", 1).IsInEditMode = function() return false end
    ui:load("Core.lua", ns)
    env.FlareUI2_DB = saved
    ui:load("Import.lua", ns)
    ui:emit("ADDON_LOADED", "FlareUI")
    return ns.db.global
end

assert(start(nil, "im").chatStyleWanted == "classic", "a new install asks for Classic")
assert(start(nil, "classic").chatStyleWanted == nil, "already Classic: nothing to write")
local old = { global = { whatsNewSeen = "7.1.2" }, profileKeys = { ["Alba - Forever"] = "Default" }, profiles = { Default = { chat = { enabled = true } } } }
assert(start(old, "im").chatStyleWanted == nil, "an old account keeps IM")
print("PASS: new installs start on Classic chat style, old accounts keep theirs")
