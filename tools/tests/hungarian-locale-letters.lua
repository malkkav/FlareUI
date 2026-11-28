-- Run from the repository root with Lua 5.1 or LuaJIT.
-- The game fonts have no ő, ű, Ő or Ű, so the Hungarian text must use õ, û, Õ and Û in their place.
-- Loads the real locale loader and huHU.lua as a player who picked Hungarian.
GetLocale = function() return "enUS" end
FlareUI2_DB = { global = { useGameLanguage = false, language = "huHU" } }
local ns = {}
for _, file in ipairs({ "Locale.lua", "huHU.lua" }) do
    assert(loadfile("Locales/" .. file))("FlareUI", ns)
end
assert(ns.LoadedLocale() == "huHU", "Hungarian did not load")

-- UTF-8 bytes of the letters the fonts can't draw
local MISSING = { ["\197\145"] = "ő", ["\197\177"] = "ű", ["\197\144"] = "Ő", ["\197\176"] = "Ű" }
local bad, count = {}, 0
for key, text in pairs(ns.L) do
    count = count + 1
    for bytes, letter in pairs(MISSING) do
        if text:find(bytes, 1, true) then bad[#bad + 1] = letter .. " in: " .. key end
    end
end
assert(count > 0, "no Hungarian phrases loaded")
table.sort(bad)
assert(#bad == 0, "use õ/û/Õ/Û instead:\n" .. table.concat(bad, "\n"))
print("PASS: Hungarian text uses only letters the game fonts draw")
