-- Run from the repository root with a Lua 5.1/LuaJIT runtime:
--   luajit tools/tests/font-families.lua
--
-- The WoW client is not available here.  These tests execute the production
-- FontFamiliesAlways/SetFont decision code in a small Lua 5.1 harness and
-- leave CreateFontFamily absent for the fallback case.
local H = dofile("tools/tests/perf-helpers.lua")
local source = H.read("Core.lua")

local function compile(body)
    local loader = loadstring or load
    return assert(loader(body))
end

local familyStart = assert(source:find("local FONT_FAMILY_LOCALES"))
local familyEnd = assert(source:find("\nfunction ns.SetFont%(", familyStart))
local familyFactory = compile([[return function(ns, GetLocale)
]] .. source:sub(familyStart, familyEnd - 1) .. [[
return ns.FontFamiliesAlways
end]])()

local function check(actual, expected, message)
    assert(actual == expected,
        ("%s (expected %s, got %s)"):format(message, tostring(expected), tostring(actual)))
end

local function decision(clientLocale, selectedLocale, cached)
    local ns = { LoadedLocale = function() return selectedLocale end }
    if cached ~= nil then ns.fontFamiliesAlways = cached end
    local localeReads = 0
    local getLocale = function()
        localeReads = localeReads + 1
        return clientLocale
    end
    local fn = familyFactory(ns, getLocale)
    local first = fn()
    local second = fn()
    return first, second, localeReads, ns
end

-- A selected language with Cyrillic/CJK letters needs a family when the game
-- client itself does not provide that alphabet.  Same-language and Western
-- selections keep the existing plain-font path.
local cases = {
    { "enUS", "zhCN", true },
    { "deDE", "zhTW", true },
    { "enUS", "koKR", true },
    { "enUS", "ruRU", true },
    { "ruRU", "ruRU", false },
    { "zhCN", "zhCN", false },
    { "zhCN", "zhTW", true },
    { "zhTW", "zhCN", true },
    { "koKR", "koKR", false },
    { "enUS", "deDE", false },
    { "zhCN", "deDE", false },
    { "ruRU", "zhCN", true },
}
for _, case in ipairs(cases) do
    local client, selected, expected = case[1], case[2], case[3]
    local first, second, reads = decision(client, selected)
    check(first, expected, client .. " client / " .. selected .. " selected")
    check(second, expected, "cached result for " .. client .. " / " .. selected)
    local expectedReads = ({ koKR = true, ruRU = true, zhCN = true, zhTW = true })[selected] and 1 or 0
    check(reads, expectedReads, "locale read count for " .. client .. " / " .. selected)
end

-- A value already cached by the addon must remain authoritative; the locale
-- callback is not consulted again.
local first, second, reads = decision("enUS", "zhCN", false)
check(first, false, "preloaded false cache")
check(second, false, "preloaded false cache stays false")
check(reads, 0, "preloaded cache avoids locale reads")

-- If the family API is unavailable, ns.SetFont must take the ordinary raw
-- path even when the selected language asks for families.
local rawStart = assert(source:find("local RETRY_SECONDS"))
local rawEnd = assert(source:find("\n-- Font families for text other players", rawStart, true))
local rawFactory = compile([[return function(ns, GetLocale, CreateFontFamily, C_Timer, BaseFont)
]] .. source:sub(rawStart, rawEnd - 1) .. [[
return ns
end]])()
local ns = { LoadedLocale = function() return "zhCN" end, TEXT_SCALE = 1 }
local timer = { NewTicker = function() error("raw SetFont should not schedule a retry") end }
ns = rawFactory(ns, function() return "enUS" end, nil, timer, function() return "base" end)
local calls = 0
local fontString = {
    SetFont = function(self, path, size, flags)
        calls = calls + 1
        check(path, "chosen.ttf", "raw fallback path")
        check(size, 12, "raw fallback size")
        check(flags, "OUTLINE", "raw fallback flags")
        return true
    end,
    SetFontObject = function() error("family API must not be called") end,
}
ns.SetFont(fontString, "chosen.ttf", 12, "OUTLINE")
check(calls, 1, "raw fallback call count")

-- Inspect the family supplied to Blizzard's API.  The chosen Latin face must
-- coexist with the stock Chinese faces on an English client, and selecting
-- Traditional Chinese on a Simplified Chinese client must keep both faces.
local membersStart = assert(source:find("ns.FontFamily = {", 1, true))
local membersEnd = assert(source:find("\n-- Blizzard's own font objects", membersStart, true))
local membersFactory = compile([[return function(ns, GetLocale, CreateFontFamily)
]] .. source:sub(membersStart, membersEnd - 1) .. [[
return ns
end]])()
for _, client in ipairs({ "enUS", "zhCN" }) do
    local captured, attached
    local family = {}
    local actual = membersFactory({ TEXT_SCALE = 1 }, function() return client end, function(_, members)
        captured = members
        return family
    end)
    actual.SetFontFamily({ SetFontObject = function(_, object) attached = object end }, "chosen.ttf", 12, "")
    local files = {}
    for _, member in ipairs(captured) do files[member.alphabet] = member.file end
    check(attached, family, client .. " attaches the created family")
    check(files.roman, "chosen.ttf", client .. " retains the chosen Roman face")
    check(files.simplifiedchinese, client == "zhCN" and "chosen.ttf" or "Fonts\\ARKai_T.ttf", client .. " Simplified Chinese face")
    check(files.traditionalchinese, "Fonts\\blei00d.TTF", client .. " Traditional Chinese face")
    check(files.korean, "Fonts\\2002.TTF", client .. " Korean face")
end

-- This test must fail against the old ruRU-only decision and pass once CJK
-- locales participate in the same family selection.
print("PASS: font family locale decisions, members, and API fallback")
