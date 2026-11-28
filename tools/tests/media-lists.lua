-- Run from the repository root: luajit tools/tests/media-lists.lua
-- Media.lua's dropdown lists, loaded whole on the real LibStub, CallbackHandler and LibSharedMedia:
-- other addons' entries are listed, Blizzard's never (Malkkav 11-27), whatever name they come under.
local env = setmetatable({}, { __index = _G })
env.GetLocale = function() return "enUS" end
env.LOCALE_enUS, env.LOCALE_koKR, env.LOCALE_ruRU, env.LOCALE_zhCN, env.LOCALE_zhTW = true, false, false, false, false
env._G = env
env.C_UIFileAsset = { IsKnownFile = function() return true end }
local function run(file, ...)
    local chunk = assert(loadfile(file))
    setfenv(chunk, env)
    return chunk(...)
end
run("Libs/LibStub/LibStub.lua")
run("Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua")
run("Libs/LibSharedMedia-3.0/LibSharedMedia-3.0.lua")
local ns = { L = setmetatable({}, { __index = function(_, k) return k end }) }
run("Media.lua", "FlareUI", ns)
local LSM = env.LibStub("LibSharedMedia-3.0")
LSM:Register("border", "Beautycase", [[Interface\AddOns\Beautycase\border.tga]])
LSM:Register("border", "Solid", [[Interface\Buttons\WHITE8X8]])
LSM:Register("border", "Game File", 130871)

local list = {}
for _, name in ipairs(ns.AddonMedia("border")) do list[name] = true end
assert(list["Beautycase"], "another addon's border is listed")
assert(not list["Solid"] and not list["Game File"], "Blizzard's art under another name is not")
assert(not list["Blizzard Tooltip"] and not list["Blizzard Dialog"], "Shared Media's own Blizzard borders are not")
assert(not list["FlareUI Frames"], "FlareUI's own come first in each dropdown, not here")
assert(ns.IsBlizzardMedia("border", "Solid") and not ns.IsBlizzardMedia("border", "FlareUI Frames"))
print("PASS: media lists leave out Blizzard's art")
