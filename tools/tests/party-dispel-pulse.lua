-- Run from the repository root: luajit tools/tests/party-dispel-pulse.lua
local onUpdate
local function noop() end

-- Blizzard can lock a region inside an aura button while the debuff is secret.
-- Both looking up SetAlpha on that region and calling the native setter can fail.
local lockedPiece
local function setAlpha(frame)
    if frame == lockedPiece then error('cannot set alpha on a locked aura region') end
    frame.alphaUpdates = frame.alphaUpdates + 1
end

local function auraPiece()
    return setmetatable({ alphaUpdates = 0 }, {
        __index = function(frame, key)
            if key ~= 'SetAlpha' then return end
            if frame == lockedPiece then error('cannot index a locked aura region') end
            return setAlpha
        end,
    })
end

local function createFrame()
    local frame = { RegisterEvent = noop, SetAlpha = setAlpha }
    function frame:SetScript(script, callback)
        if script == 'OnUpdate' then
            onUpdate = function(elapsed) callback(self, elapsed) end
        end
    end
    return frame
end

local ns = { L = {}, modules = {} }
local env = setmetatable({
    CreateFrame = createFrame,
    GetTime = function() return 0 end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    LibStub = function() return { Embed = noop } end,
}, { __index = _G })
setfenv(assert(loadfile('Modules/PartyFrames.lua')), env)('FlareUI', ns)

local asked, visible = 0, true
local owner = { IsVisible = function() asked = asked + 1 return visible end }
local first, second = auraPiece(), auraPiece()
local partyFrames = ns.PartyFrames
partyFrames.DispelPulse(first, owner)
partyFrames.DispelPulse(second, owner)

local function tick()
    local ok, err = pcall(onUpdate, 0.05)
    assert(ok, 'Dispel Highlight update failed: ' .. tostring(err))
end

local function checkLocked(locked, readable)
    lockedPiece = locked
    local lockedUpdates, readableUpdates = locked.alphaUpdates, readable.alphaUpdates
    tick()
    assert(locked.alphaUpdates == lockedUpdates, 'the locked aura region must be skipped')
    assert(readable.alphaUpdates > readableUpdates, 'the readable highlight must still pulse')
end

-- Try both roles so the readable region is checked on either side of the locked one.
checkLocked(first, second)
checkLocked(second, first)

lockedPiece = nil
local updatesBeforeUnlock = second.alphaUpdates
tick()
assert(second.alphaUpdates > updatesBeforeUnlock, 'the aura highlight must resume pulsing after it unlocks')

-- the tile is looked up four times a second, once for all its pieces, and a hidden one stands still
asked = 0
for _ = 1, 20 do tick() end
assert(asked >= 3 and asked <= 5, 'a second of beats looks the tile up about four times: ' .. asked)
visible = false
for _ = 1, 6 do tick() end
local still = first.alphaUpdates
for _ = 1, 6 do tick() end
assert(first.alphaUpdates == still, 'nothing pulses on a tile that is not on screen')
visible = true
for _ = 1, 6 do tick() end
assert(first.alphaUpdates > still)
-- a piece that stops is dropped before the next beat
partyFrames.DispelSteady(first)
local steady, other = first.alphaUpdates, second.alphaUpdates
tick()
assert(first.alphaUpdates == steady and second.alphaUpdates > other)

print('PASS: Dispel Highlight skips a locked aura region and resumes after it unlocks')
