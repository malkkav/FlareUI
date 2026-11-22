-- Run from the repository root: luajit tools/tests/ring-portrait-frame.lua
-- The elite / rare / boss dragon (Ring.BossArtSpot): the target's on the right of its ring, the
-- player's (Look > Portrait Frame) mirrored round the player's ring on the left.
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

-- Blizzard's frames are 232 px wide and the player's is the target's, mirrored
local FRAME_W, ART_W = 232, 80
local function centreX(e, w)
    if e.point:find('LEFT') then return e.x + w / 2 end
    if e.point:find('RIGHT') then return e.x - w / 2 end
    return e.x
end

-- each Forever offset: the player's dragon is where the target's is, mirrored
for _, off in ipairs({ { 0, 1 }, { 11, -4 }, { 8, -7 } }) do
    local t = Ring.BossArtSpot('target', 'RIGHT', off[1], off[2])
    local p = Ring.BossArtSpot('player', 'LEFT', off[1], off[2])
    assert(math.abs(centreX(p, ART_W) - (FRAME_W - centreX(t, ART_W))) < 1e-9,
        'the player dragon must mirror the target dragon (offset ' .. off[1] .. ', ' .. off[2] .. ')')
    assert(p.y == t.y, 'the player dragon must sit at the target dragon height')
end

-- the art is drawn for a ring on the right: mirrored on any ring on the left
local _, flipped = Ring.BossArtSpot('target', 'RIGHT', 0, 1)
assert(flipped == false, 'the target dragon is drawn as the art is')
_, flipped = Ring.BossArtSpot('target', 'LEFT', 0, 1)
assert(flipped == true, 'a flipped target portrait mirrors its dragon')
_, flipped = Ring.BossArtSpot('player', 'LEFT', 0, 1)
assert(flipped == true, 'the player dragon is mirrored to the left')

-- Portrait Frame off draws nothing; each pick has Forever's art and offsets
assert(Ring.PortraitFrameArt(nil) == nil, 'no pick: no dragon')
assert(Ring.PortraitFrameArt('none') == nil, 'None: no dragon')
for _, pick in ipairs({ 'elite', 'rareelite', 'worldboss' }) do
    local atlas, ox, oy = Ring.PortraitFrameArt(pick)
    assert(type(atlas) == 'string' and atlas:find('^UI%-HUD%-UnitFrame%-Target%-PortraitOn%-Boss%-'),
        pick .. ' must use the target dragon art')
    assert(type(ox) == 'number' and type(oy) == 'number', pick .. ' must have offsets')
end

print('ring-portrait-frame: ok')
