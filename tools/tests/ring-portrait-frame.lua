-- Run from the repository root: luajit tools/tests/ring-portrait-frame.lua
-- Portrait Frame (Ring.PortraitFrameArt): the player's dragon is the target's, mirrored round the
-- player's ring on the left; None draws nothing.
local ns = { L = setmetatable({}, { __index = function(_, k) return k end }) }
local function noop() end
local env = setmetatable({
    LibStub = function() return { SettingType = {}, RegisterCallback = noop } end,
    -- the module's event frames, built when it loads
    CreateFrame = function()
        return { RegisterEvent = noop, RegisterUnitEvent = noop, SetScript = noop }
    end,
}, { __index = _G })
setfenv(assert(loadfile('Modules/UnitFramesRing.lua')), env)('FlareUI', ns)
local Ring = ns.UFRing

-- Blizzard's frames are 232 px wide and the player's is the target's, mirrored. The target's dragon
-- (Ring.Update): TOPRIGHT at the frame's top-right corner plus Forever's offsets.
local FRAME_W, ART_W = 232, 80
local function centreX(e, w)
    if e.point:find('LEFT') then return e.x + w / 2 end
    if e.point:find('RIGHT') then return e.x - w / 2 end
    return e.x
end

for pick, art in pairs(Ring.PORTRAIT_FRAME_ART) do
    local atlas, e = Ring.PortraitFrameArt(pick)
    assert(atlas == art[1], pick .. ' must use its dragon art')
    local target = { point = 'TOPRIGHT', x = FRAME_W + art[2], y = art[3] }
    assert(math.abs(centreX(e, ART_W) - (FRAME_W - centreX(target, ART_W))) < 1e-9,
        pick .. ': the player dragon must mirror the target dragon')
    assert(e.y == target.y, pick .. ': the player dragon must sit at the target dragon height')
end
for _, pick in ipairs({ 'elite', 'rareelite', 'worldboss' }) do
    assert(Ring.PortraitFrameArt(pick), pick .. ' must have a dragon')
end

-- Portrait Frame off draws nothing
assert(Ring.PortraitFrameArt(nil) == nil, 'no pick: no dragon')
assert(Ring.PortraitFrameArt('none') == nil, 'None: no dragon')

print('ring-portrait-frame: ok')
