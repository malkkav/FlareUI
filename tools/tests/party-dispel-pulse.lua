-- Run from the repository root: luajit tools/tests/party-dispel-pulse.lua
local now = 0
local onUpdate
local function noop() end

-- Blizzard can lock a region inside an aura button while the debuff is secret.
-- Both looking up SetAlpha on that region and calling the native setter can fail.
local locked = true
local auraPiece = { alpha = 0.5 }
local function setAlpha(frame, alpha)
    if frame == auraPiece and locked then error('cannot set alpha on a locked aura region') end
    frame.alpha = alpha
end
setmetatable(auraPiece, {
    __index = function()
        if locked then error('cannot index a locked aura region') end
        return setAlpha
    end,
})

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
    GetTime = function() return now end,
    LibStub = function() return { Embed = noop } end,
}, { __index = _G })
setfenv(assert(loadfile('Modules/PartyFrames.lua')), env)('FlareUI', ns)

local owner = { IsVisible = function() return true end }
local readablePiece = { SetAlpha = setAlpha, alpha = 0.5 }
local partyFrames = ns.PartyFrames
partyFrames.DispelPulse(auraPiece, owner)
partyFrames.DispelPulse(readablePiece, owner)

local function tick(time)
    now = time
    local ok, err = pcall(onUpdate, 0.05)
    assert(ok, 'Dispel Highlight update failed: ' .. tostring(err))
end

local half = partyFrames.DISPEL_PULSE[3]
tick(half)
assert(auraPiece.alpha == 0.5, 'the locked aura region must be skipped')
assert(readablePiece.alpha > 0.5, 'the readable highlight must still pulse')

locked = false
tick(2 * half)
assert(auraPiece.alpha == readablePiece.alpha and auraPiece.alpha < 0.5,
    'the aura highlight must resume pulsing as soon as it unlocks')

print('PASS: Dispel Highlight skips a locked aura region and resumes after it unlocks')
