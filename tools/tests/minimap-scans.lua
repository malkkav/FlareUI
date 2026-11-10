-- Run from the repository root: luajit tools/tests/minimap-scans.lua
-- Exercise the real scan hooks with a deterministic clock and minimal frame doubles.
local now, timers = 10, {}
function GetTime() return now end
function canaccessvalue() return true end
C_Timer = { NewTimer = function(delay, fn)
    timers[#timers + 1] = { at = now + delay, fn = fn }
end }
local function advance(seconds)
    local target = now + seconds
    while true do
        table.sort(timers, function(a, b) return a.at < b.at end)
        if not timers[1] or timers[1].at > target then break end
        local timer = table.remove(timers, 1)
        now = timer.at
        timer.fn()
    end
    now = target
end
local Frame = {}; Frame.__index = Frame
function CreateFrame() return setmetatable({ shown = true, hooks = {} }, Frame) end
function Frame:SetPoint() end
function Frame:SetSize() end
function Frame:SetFrameStrata() end
function Frame:GetFrameStrata() return 'LOW' end
function Frame:SetFrameLevel() end
function Frame:GetFrameLevel() return 2 end
function Frame:SetColorTexture() end
function Frame:SetMaskTexture(mask) self.mask = mask end
function Frame:SetShown(shown) self.shown = shown end
function Frame:IsShown() return self.shown end
function Frame:Hide() self.shown = false; if self.hooks.OnHide then self.hooks.OnHide() end end
function Frame:Show() self.shown = true; if self.hooks.OnShow then self.hooks.OnShow() end end
function Frame:HookScript(event, fn) self.hooks[event] = fn end
function Frame:CreateTexture() self.texture = CreateFrame(); return self.texture end
function Frame:AdjustPointsOffset() end
function Frame:SetMouseClickEnabled() end
function hooksecurefunc(object, method, callback)
    local original = object[method]
    object[method] = function(self, ...)
        original(self, ...)
        callback(self, ...)
    end
end
function LibStub() return { Embed = function() end } end
NineSliceUtil = { GetLayout = function() return {} end, ApplyLayout = function() end }
Minimap, MinimapCluster, UIParent = CreateFrame(), CreateFrame(), CreateFrame()
local ns = { L = {}, modules = {} }
assert(loadfile('Modules/Minimap.lua'))('FlareUI', ns)
local function upvalue(fn, wanted)
    for i = 1, 100 do
        local name, value = debug.getupvalue(fn, i)
        if name == wanted then return value end
        if not name then break end
    end
    error('Missing upvalue: ' .. wanted)
end
local init = ns.Minimap.Init
upvalue(upvalue(init, 'InitSquare'), 'CreateMapArt')()
local scan = upvalue(init, 'Scan')
scan.Watch()
local back = MinimapCluster.texture
assert(back:IsShown(), 'Normal map needs its backing')
Minimap:SetMouseClickEnabled(false)
Minimap:AdjustPointsOffset(100, 50)
assert(not back:IsShown(), 'Scan must not leave an opaque black rectangle behind')
assert(ns.Minimap.Frame:IsShown(), 'Stationary border should remain visible')
Minimap:Hide(); Minimap:Show()
assert(not back:IsShown(), 'OnShow must not restore the backing mid-scan')
Minimap:AdjustPointsOffset(-100, -50)
advance(1)
assert(not back:IsShown(), 'A scan paused at home still owns the map')
Minimap:SetMouseClickEnabled(true)
assert(back:IsShown(), 'Completed scan should restore the backing')
Minimap:AdjustPointsOffset(20, 0)
Minimap:AdjustPointsOffset(-20, 0)
assert(not back:IsShown(), 'Backing stays hidden during the scan quiet period')
advance(0.5)
assert(back:IsShown(), 'Quiet-period completion restores backing')
Minimap:SetMouseClickEnabled(false)
Minimap:Hide()
advance(6)
assert(not back:IsShown(), 'Scan timeout must not reveal a manually hidden map')
assert(not ns.Minimap.Frame:IsShown())
Minimap:Show()
assert(back:IsShown(), 'Normal show restores backing after timeout')
print('PASS: minimap scan backing, pause, quiet period, timeout and show/hide lifecycle')
