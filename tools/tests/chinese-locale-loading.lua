-- Run from the repository root with Lua 5.1 or LuaJIT.
-- Exercise the real locale loader and both Chinese files, including a game
-- client whose language differs from the addon's chosen language.
local function check(gameLocale, selectedLocale, expectedLocale)
    GetLocale = function() return gameLocale end
    FlareUI2_DB = selectedLocale and {
        global = { useGameLanguage = false, language = selectedLocale },
    } or nil
    local ns = {}
    for _, file in ipairs({ "Locale.lua", "zhCN.lua", "zhTW.lua" }) do
        assert(loadfile("Locales/" .. file))("FlareUI", ns)
    end
    assert(ns.LoadedLocale() == expectedLocale, "wrong loaded locale")
    if expectedLocale ~= "enUS" then
        local welcome = ns.L["Welcome to FlareUI!"]
        assert(welcome ~= "Welcome to FlareUI!", "welcome text fell back to English")
    else
        assert(ns.L["Welcome to FlareUI!"] == "Welcome to FlareUI!", "Chinese leaked into English")
    end
    assert(ns.L["Untranslated sentinel"] == "Untranslated sentinel", "fallback changed")
end

check("enUS", "zhTW", "zhTW")
check("enUS", "zhCN", "zhCN")
check("zhCN", nil, "zhCN")
check("zhTW", nil, "zhTW")
check("zhCN", "zhTW", "zhTW")
check("zhTW", "zhCN", "zhCN")
check("enUS", nil, "enUS")
print("PASS: Chinese locale loading and fallback")
