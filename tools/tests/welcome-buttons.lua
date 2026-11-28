-- Run from the repository root with Lua 5.1/LuaJIT (or through Lupa):
--   dofile("tools/tests/welcome-buttons.lua")
-- Extract the production helper before the WoW-only frame code and exercise its
-- language-selection/fallback behaviour without pretending to run WoW.

local sourceFile = assert(io.open("Settings/Welcome.lua", "r"))
local source = sourceFile:read("*a")
sourceFile:close()

local marker = "\n--------------------------------------------------\n-- 1. THE SMALL POP-UP"
local markerAt = assert(source:find(marker, 1, true), "could not isolate Welcome.lua prefix")
local prefix = source:sub(1, markerAt - 1)

local function compile(clientLocale, selectedLocale, translations, globals, loadedLocaleAvailable)
    local ns = { L = setmetatable(translations or {}, { __index = function(_, key) return key end }) }
    if loadedLocaleAvailable then
        ns.LoadedLocale = function() return selectedLocale end
    end
    local gameGlobals = globals or {}
    local env = setmetatable({
        _G = gameGlobals,
        GetLocale = function() return clientLocale end,
    }, { __index = _G })
    local chunk = assert(loadstring(prefix .. "\nreturn WelcomeButtonText"))
    setfenv(chunk, env)
    local choose = assert(chunk(nil, ns))
    return function(key, globalName, fallback)
        return choose(key, ns.L[key], globalName, fallback)
    end, ns
end

local function check(actual, expected, label)
    assert(actual == expected, ("%s: expected %q, got %q"):format(label, expected, actual))
end

local zh = { Back = "返回", Next = "下一步", Close = "关闭" }
local en = { Back = "Back", Next = "Next", Close = "Close" }

do
    local choose = compile("enUS", "zhCN", zh, { BACK = "Back", NEXT = "Next", CLOSE = "Close" }, true)
    check(choose("Back", "BACK", "Back"), "返回", "English client with zhCN selected uses addon text")
    check(choose("Next", "NEXT", "Next"), "下一步", "English client with zhCN selected uses addon text")
    check(choose("Close", "CLOSE", "Close"), "关闭", "English client with zhCN selected uses addon text")
end

do
    local choose, ns = compile("zhCN", "enUS", en, { BACK = "返回", NEXT = "下一步", CLOSE = "关闭" }, true)
    assert(ns.LoadedLocale() == "enUS", "test selected locale setup failed")
    check(choose("Back", "BACK", "Back"), "Back", "Chinese client with enUS selected uses addon text")
    check(choose("Next", "NEXT", "下一步"), "Next", "Chinese client with enUS selected uses addon text")
    check(choose("Close", "CLOSE", "关闭"), "Close", "Chinese client with enUS selected uses addon text")
end

do
    local choose = compile("zhCN", "zhCN", zh, { BACK = "返回", NEXT = "下一步", CLOSE = "关闭" }, true)
    check(choose("Back", "BACK", "Back"), "返回", "same locale keeps Blizzard Back text")
    check(choose("Next", "NEXT", "下一步"), "下一步", "same locale keeps Blizzard Next text")
    check(choose("Close", "CLOSE", "关闭"), "关闭", "same locale keeps Blizzard Close text")
end

do
    local choose = compile("zhCN", "zhCN", zh, { BACK = "返回", NEXT = "下一步", CLOSE = "关闭" }, false)
    check(choose("Back", "BACK", "Back"), "返回", "missing LoadedLocale keeps Blizzard fallback")
end

do
    local choose = compile("enUS", "zhCN", {}, { BACK = "Back", NEXT = "Next", CLOSE = "Close" }, true)
    check(choose("Back", "BACK", "Back"), "Back", "missing translation falls back to Blizzard text")
end

print("PASS: Welcome button locale selection and fallback")
