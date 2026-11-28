local F = dofile('tools/tests/fixtures/doesitdie-frames.lua')
local callbacks, registrations = {}, 0
local secret = setmetatable({}, { __add = function() error('secret arithmetic') end,
    __lt = function() error('secret comparison') end })
function canaccessvalue(v) return v ~= secret end
function strtrim(s) return s:match('^%s*(.-)%s*$') end
function CreateFrame(kind, _, parent) return F.frame(kind, parent) end
local lem = { RegisterCallback = function() end }
function LibStub() return lem end
local exists, dead, count = true, false, 1
function UnitExists() return exists end
function UnitIsDead() return dead end
function UnitHealth() return secret end
function UnitHealthMax() return secret end
DoesItDie = {
    GetRemainingDamage = function() return 25, count end,
    RegisterCallback = function(owner, fn) registrations=registrations+1; callbacks[owner]=fn end,
}
DoesItDieDB = {}
for _, name in ipairs({'Target', 'Focus'}) do
    local f = F.frame()
    f.Health = F.frame('StatusBar', f); f.Health:SetStatusBarTexture('test')
    _G['FlareUI_UF_' .. name] = f
end
local ns = { EditPreviewing=function() return false end, OnEditFight=function() end }
assert(loadfile('Modules/UnitFramesDoesItDie.lua'))('FlareUI', ns)
local loader = F.created[#F.created]
F.state[loader].scripts.OnEvent(loader, 'PLAYER_LOGIN')
assert(registrations == 1 and callbacks.FlareUI, 'normal startup registers the available API')
local function mark(unit)
    local frame = _G['FlareUI_UF_' .. unit]
    for _, f in ipairs(F.created) do
        if F.state[f].anchor == frame.Health then return f end
    end
    error('no marker for ' .. unit)
end
local target, focus = mark('Target'), mark('Focus')
assert(target:IsShown() and focus:IsShown())
assert(F.state[target].max == secret and F.state[target].value == 25, 'health passes unread to the widget')

-- The custom path survived an addon update, but its frame did not. It must not suppress FlareUI.
DoesItDieDB.customHealthBar = 'RemovedAddon.Target.Health'
DoesItDieDB.customFocusHealthBar = 'RemovedAddon.Focus.Health'
ns.UFDoesItDie:Refresh()
assert(target:IsShown() and focus:IsShown(), 'stale target/focus overrides must fall back to FlareUI')
assert(DoesItDieDB.customHealthBar == 'RemovedAddon.Target.Health', 'saved override stays intact')

-- Valid region paths are still owned by DoesItDie (including textures, as its resolver allows).
Custom = { Health=F.frame('StatusBar'), Focus=F.frame('Texture') }
DoesItDieDB.customHealthBar = ' Custom.Health '
DoesItDieDB.customFocusHealthBar = 'Custom.Focus'
ns.UFDoesItDie:Refresh()
assert(not target:IsShown() and not focus:IsShown(), 'valid overrides retain exclusive rendering')
Custom.Health = nil
ns.UFDoesItDie:Refresh()
assert(target:IsShown() and not focus:IsShown(), 'late removal falls back independently')
Custom.Health = F.frame('StatusBar')
ns.UFDoesItDie:Refresh()
assert(not target:IsShown(), 'late creation restores handoff')

local function fallback(path)
    DoesItDieDB.customHealthBar = path
    ns.UFDoesItDie:Refresh()
    assert(target:IsShown(), 'invalid or inaccessible path must not suppress renderer')
end
fallback('   '); fallback('Custom'); fallback('Custom.nope.Health'); fallback('Custom.Number.Health')
Custom.Number = 3; fallback('Custom.Number.Health')
Custom.Bad = setmetatable({}, {__index=function() error('unreadable field') end})
fallback('Custom.Bad.Health')
Custom.Secret = secret; fallback('Custom.Secret.Health')
fallback(false)

DoesItDieDB.customFocusHealthBar = ''
DoesItDieDB.showMarkers = false
ns.UFDoesItDie:Refresh()
assert(not target:IsShown() and not focus:IsShown())
DoesItDieDB.showMarkers = true; DoesItDieDB.focusMode = 'off'
ns.UFDoesItDie:Refresh()
assert(target:IsShown() and not focus:IsShown())
DoesItDieDB.focusMode = 'markerIcon'
FlareUI_UF_Target.Health:SetReverseFill(true)
ns.UFDoesItDie:Refresh()
assert(target:GetReverseFill() == true and focus:IsShown())
count = 0; callbacks.FlareUI('DOTS_CHANGED', 'target')
assert(not target:IsShown(), 'zero DoTs hide old marker')
count = 1; exists = false; ns.UFDoesItDie:Refresh()
assert(not target:IsShown() and not focus:IsShown())
exists = true; dead = true; ns.UFDoesItDie:Refresh()
assert(not target:IsShown())
print('PASS: unit-frame stale/valid/late overrides, settings, API callback, fill and unread health passthrough')
