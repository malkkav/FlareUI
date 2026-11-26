-- Run from the repository root:  luajit tools/tests/font-redraw.lua
-- ns.FontRedraw (Core.lua, 11-20): text drawn before its font file loaded is drawn anew with a size
-- change and back; only while the string still holds the font asked for; never for the game's files.
local ui, ns = dofile("tools/tests/fixtures/core.lua")()
local R = assert(ns.FontRedraw)

local function check(ok, message) assert(ok, message) end

local function FakeString(path, size, flags)
    local fs = { path = path, size = size, flags = flags, calls = {} }
    function fs:GetFont() return self.path, self.size, self.flags end
    function fs:SetFont(p, sz, fl)
        self.calls[#self.calls + 1] = sz
        self.path, self.size, self.flags = p, sz, fl
        return true
    end
    return fs
end

-- the game's own files never need it; FlareUI's and other addons' do
check(not R.Wanted("Fonts\\FRIZQT__.TTF"), "Friz is always in")
check(not R.Wanted("fonts/arialn.ttf"), "forward slashes and case")
check(R.Wanted("Interface\\AddOns\\FlareUI\\Media\\Fonts\\Roboto.ttf"), "an addon font is redrawn")
check(not R.Wanted(nil), "no path")

-- a string still on the wanted font: size + 1, then back
local want = { path = "X.ttf", size = 13, flags = "OUTLINE" }
local fs = FakeString("X.ttf", 13, "OUTLINE")
R.String(fs, want)
check(#fs.calls == 2 and fs.calls[1] == 14 and fs.calls[2] == 13 and fs.size == 13, "redraw bumps and returns")

-- another setter changed it since: left alone
local other = FakeString("X.ttf", 20, "")
R.String(other, want)
check(#other.calls == 0, "a string with another size is left alone")

-- R.All: every remembered string, after each loading screen at the set delays
local a, b = FakeString("X.ttf", 13, ""), FakeString("Y.ttf", 9, "")
R.strings[a] = { path = "X.ttf", size = 13, flags = "" }
R.strings[b] = { path = "Y.ttf", size = 9, flags = "" }
local waiting = #ui.timers
ui:emit("PLAYER_ENTERING_WORLD")
local passes = 0
for i = waiting + 1, #ui.timers do
    if ui.timers[i].callback == R.All then passes = passes + 1 end
end
check(passes > 0 and passes == #R.AFTER_LOAD, "one pass per delay")
ui:flushTimers()
check(#a.calls == 2 * #R.AFTER_LOAD and #b.calls == 2 * #R.AFTER_LOAD, "every string redrawn each pass")

-- an object with its own redraw (the chat windows)
local used = false
local chat = FakeString("X.ttf", 14, "")
R.Object(chat, { path = "X.ttf", size = 14, flags = "", redraw = function() used = true end })
check(used and #chat.calls == 0, "own redraw used")

local function Refuse(fontString, method)
    fontString[method] = function()
        error("calling '" .. method .. "' on bad self (Attempt to access forbidden object from code tainted by an AddOn)")
    end
end

local locked = FakeString("X.ttf", 13, "")
Refuse(locked, "GetFont")
R.strings[locked] = { path = "X.ttf", size = 13, flags = "" }
local before = #a.calls
check(pcall(R.All), "a text the client refuses doesn't stop the pass")
check(#locked.calls == 0 and #a.calls == before + 2 and #b.calls == before + 2, "the other texts are still redrawn")
R.strings[locked] = nil

local late, waitingToo = FakeString("Base.ttf", 13, ""), FakeString("Base.ttf", 13, "")
function late:SetFont() return false end
function waitingToo:SetFont() return false end
local tickers = #ui.timers
ns.SetFontUnscaled(late, "Late.ttf", 13, "")
ns.SetFontUnscaled(waitingToo, "Late.ttf", 13, "")
check(#ui.timers == tickers + 1, "a font that isn't in yet is asked for again")
local retry = ui.timers[#ui.timers]
Refuse(late, "SetFont")
check(pcall(retry.callback) and not retry.cancelled, "a refused text doesn't stop the retries of the others")
local asked = 0
function waitingToo:SetFont() asked = asked + 1; return true end
retry.callback()
check(asked > 0 and retry.cancelled, "the refused text is dropped: the retries end once the others have their font")

print("PASS: font redraw rules")
