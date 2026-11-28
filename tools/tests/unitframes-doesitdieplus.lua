local F = dofile('tools/tests/fixtures/doesitdie-frames.lua')
local enabled, callback, registrations = true, nil, 0
local plus = { GetRemainingDamage=function() return 25, 1 end,
    RegisterCallback=function(owner, fn) assert(owner == 'FlareUI'); callback=fn; registrations=registrations+1 end }
UsefulPlatesAndTooltips_API = { Get=function(name) assert(name == 'DoT'); if enabled then return plus end end }
UsefulPlatesAndTooltips_DoTAPI = plus -- This alias exists even when the module is disabled.
UsefulPlatesAndTooltips_DoTInfoDB = { showMarkers=true, showSkull=true, focusMode='markerIcon' }
UsefulPlatesAndTooltipsDB = { frames={} }
function canaccessvalue() return true end
function strtrim(s) return s:match('^%s*(.-)%s*$') end
function CreateFrame(kind, _, parent) return F.frame(kind, parent) end
function LibStub() return { RegisterCallback=function() end } end
function UnitExists() return true end
function UnitIsDead() return false end
function UnitHealth() return 30 end
function UnitHealthMax() return 100 end
for _, name in ipairs({'Target','Focus'}) do
    local f=F.frame(); f.Health=F.frame('StatusBar',f); f.Health:SetStatusBarTexture('test')
    _G['FlareUI_UF_'..name]=f
end
local ns={EditPreviewing=function() return false end,OnEditFight=function() end}
assert(loadfile('Modules/UnitFramesDoesItDie.lua'))('FlareUI',ns)
local loader=F.created[#F.created]
F.state[loader].scripts.OnEvent(loader,'PLAYER_LOGIN')
assert(callback and registrations==1, 'Plus public DoT API must register when original DoesItDie is absent')
local function widgets(name)
    local mark,window
    local frame=_G['FlareUI_UF_'..name]
    for _,f in ipairs(F.created) do
        if F.state[f].anchor==frame.Health then mark=f end
        if f:GetParent()==frame and f:GetObjectType()=='Frame' then window=f end
    end
    return assert(mark),assert(window)
end
local target, targetSkull=widgets('Target'); local focus,focusSkull=widgets('Focus')
assert(target:IsShown() and targetSkull:IsShown() and focus:IsShown() and focusSkull:IsShown())
assert(F.state[target].value==25)
local options=UsefulPlatesAndTooltips_DoTInfoDB
options.fillDirection='rtl'; options.plateFillDirection='rtl'; ns.UFDoesItDie:Refresh()
assert(target:GetReverseFill() and focus:GetReverseFill(), 'Plus explicit right-to-left fill is respected')
FlareUI_UF_Target.Health:SetReverseFill(true); options.fillDirection='ltr'; ns.UFDoesItDie:Refresh()
assert(not target:GetReverseFill(), 'Plus explicit left-to-right wins over mirrored health')
options.fillDirection='auto'; options.plateFillDirection='auto'; ns.UFDoesItDie:Refresh()
assert(target:GetReverseFill() and not focus:GetReverseFill(), 'auto follows each health bar')
local settings=UsefulPlatesAndTooltips_DoTInfoDB
settings.targetMarkers=false; ns.UFDoesItDie:Refresh()
assert(not target:IsShown() and targetSkull:IsShown() and focus:IsShown())
settings.showSkull=false; ns.UFDoesItDie:Refresh()
assert(not targetSkull:IsShown() and focusSkull:IsShown(), 'Plus showSkull controls target, focus follows its mode')
settings.focusMode='marker'; ns.UFDoesItDie:Refresh()
assert(focus:IsShown() and not focusSkull:IsShown())
settings.focusMode='off'; ns.UFDoesItDie:Refresh(); assert(not focus:IsShown())
settings.targetMarkers=true; settings.showSkull=true; settings.focusMode='markerIcon'; settings.showMarkers=false
ns.UFDoesItDie:Refresh()
assert(not target:IsShown() and targetSkull:IsShown() and not focus:IsShown() and not focusSkull:IsShown())
settings.showMarkers=true
Custom={ Health=F.frame('StatusBar'),Focus=F.frame('StatusBar') }
local paths=UsefulPlatesAndTooltipsDB.frames
paths.target='Custom.Health'; paths.focus='Custom.Focus'; ns.UFDoesItDie:Refresh()
assert(not target:IsShown() and not targetSkull:IsShown() and not focus:IsShown() and not focusSkull:IsShown())
Custom.Health=nil; ns.UFDoesItDie:Refresh()
assert(target:IsShown() and not focus:IsShown(), 'stale custom paths fall back independently')
assert(paths.target=='Custom.Health', 'custom setting is not rewritten')
paths.focus='Missing.Focus'; ns.UFDoesItDie:Refresh(); assert(focus:IsShown())
enabled=false; ns.UFDoesItDie:Refresh()
assert(not target:IsShown() and not focus:IsShown(), 'disabled root module must not fall back to its always-present alias')
enabled=true; callback('DOTS_CHANGED','target'); assert(target:IsShown())
DoesItDie={ GetRemainingDamage=function() return 7,1 end,RegisterCallback=function() end }
DoesItDieDB={ showMarkers=false }
ns.UFDoesItDie:Refresh(); assert(not target:IsShown(), 'original addon settings retain priority when present')
DoesItDieDB.showMarkers=true; ns.UFDoesItDie:Refresh()
assert(F.state[target].value==7, 'do not combine the two addons\' damage')
print('PASS: Plus API, disabled module, custom paths, target/focus flags, callbacks and original-addon precedence')
