-- Run from the repository root with a Lua 5.1/LuaJIT runtime:
--   luajit tools/tests/font-families.lua
--
-- The WoW client is not available here. Each case loads the whole of Core.lua on client doubles:
-- the client's language, and CreateFontFamily (left out for the fallback case).
local loadCore = dofile("tools/tests/fixtures/core.lua")

-- Core.lua for a client language; family(members) stands in for CreateFontFamily (nil: none)
local function Core(client, family, profile)
    local reads = { n = 0 }
    local _, ns = loadCore(profile, function(env)
        env.GetLocale = function() reads.n = reads.n + 1 return client end
        env.CreateFontFamily = family and function(_, members) return family(members) end or nil
        env.C_Timer.NewTicker = function() error("raw SetFont should not schedule a retry") end
        env.canaccessallvalues = function() return true end
    end)
    reads.n = 0
    return ns, reads
end

local function check(actual, expected, message)
    assert(actual == expected,
        ("%s (expected %s, got %s)"):format(message, tostring(expected), tostring(actual)))
end

local function decision(clientLocale, selectedLocale, cached)
    local ns, reads = Core(clientLocale)
    ns.LoadedLocale = function() return selectedLocale end
    ns.fontFamiliesAlways = cached
    local first = ns.FontFamiliesAlways()
    local second = ns.FontFamiliesAlways()
    return first, second, reads.n, ns
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
local ns = Core("enUS")
ns.LoadedLocale = function() return "zhCN" end
ns.fontFamiliesAlways = nil
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
for _, client in ipairs({ "enUS", "zhCN" }) do
    local captured, attached
    local family = {}
    local actual = Core(client, function(members)
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

-- Global Font > Outline: over every font's own, or left to each
do
    local host = Core("enUS", nil, { fonts = { outline = "" } })
    host.LoadedLocale = function() return "enUS" end
    host.fontFamiliesAlways = nil
    local flags
    local string = { SetFont = function(_, _, _, f) flags = f return true end, SetFontObject = function() end }
    host.SetFont(string, "chosen.ttf", 12, "THICKOUTLINE")
    check(flags, "THICKOUTLINE", "each font's own")
    host.db.profile.fonts.outline = "OUTLINE, SLUG"
    host.SetFont(string, "chosen.ttf", 12, "")
    check(flags, "OUTLINE, SLUG", "one outline over all")
    host.db.profile.fonts.outline = "NONE"
    host.SetFont(string, "chosen.ttf", 12, "OUTLINE")
    check(flags, "", "None over all")
end

-- Sharp Outline: the game's Slug flag reaches every alphabet's member, and the string scales smoothly only with it
do
    local captured
    local actual = Core("enUS", function(members) captured = members return {} end)
    local smooth, times
    times = 0
    local string = { SetFontObject = function() end, SetSmoothScaling = function(_, on) smooth, times = on, times + 1 end }
    actual.SetFontFamily(string, "chosen.ttf", 12, "OUTLINE")
    check(times, 0, "other outlines leave the scaling alone")
    actual.SetFontFamily(string, "chosen.ttf", 12, "OUTLINE, SLUG")
    check(smooth, true, "smooth with Sharp Outline")
    for _, member in ipairs(captured) do check(member.flags, "OUTLINE, SLUG", member.alphabet .. " flag") end
    actual.SetFontFamily(string, "chosen.ttf", 12, "OUTLINE")
    check(smooth, false, "put back once it's off")
    actual.SetFontFamily(string, "chosen.ttf", 12, "")
    check(times, 2, "and left alone again")
end

-- A family's text draws with its members' shadow: each shadow is a family of its own (11-23)
local made = {}
local function newFont()
    local font = { SetShadowColor = function(self, r, g, b, a) self.color = a end, SetShadowOffset = function(self, x, y) self.x, self.y = x, y end }
    return font
end
local shadowed = Core("enUS", function()
    local family = newFont()
    family.members = {}
    family.GetFontObjectForAlphabet = function(self, alphabet)
        self.members[alphabet] = self.members[alphabet] or newFont()
        return self.members[alphabet]
    end
    made[#made + 1] = family
    return family
end)
local text = newFont()
text.red, text.h = 1, "LEFT"
function text:SetFontObject(font) self.font, self.red, self.h, self.sets = font, 0, "CENTER", (self.sets or 0) + 1 end
function text:GetTextColor() return self.red, 0.5, 0.5, 1 end
function text:SetTextColor(r) self.red = r end
function text:GetJustifyH() return self.h end
function text:SetJustifyH(h) self.h = h end
function text:GetJustifyV() return "MIDDLE" end
function text:SetJustifyV() end
shadowed.SetFontFamily(text, "chosen.ttf", 12, "")
text.red, text.h = 0.25, "LEFT"
shadowed.ApplyShadow(text, { enableShadow = true, shadowX = 2, shadowY = -2 })
check(#made, 2, "the shadow has its own family")
check(text.font, made[2], "the text uses it")
check(made[2].members.russian.x, 2, "its members carry the shadow")
check(made[2].y, -2, "so does the family")
check(made[1].color, nil, "the plain family has none")
check(text.red, 0.25, "the colour is kept")
check(text.h, "LEFT", "the alignment is kept")
check(text.x, 2, "and the text's own shadow is set")
shadowed.SetFontFamily(text, "chosen.ttf", 12, "")
check(text.font, made[2], "styled again: the same family at once")
shadowed.ApplyShadow(text, { enableShadow = true, shadowX = 2, shadowY = -2 })
check(text.sets, 3, "nothing to change")
shadowed.ApplyShadow(text, { enableShadow = false })
check(text.font, made[1], "no shadow: the plain family")
check(text.color, 0, "and no shadow of its own")
check(#made, 2, "families are shared")

-- This test must fail against the old ruRU-only decision and pass once CJK
-- locales participate in the same family selection.
print("PASS: font family locale decisions, members, and API fallback")
