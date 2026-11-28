-- Independently authored integration harness. Run from FlareUI with an independent official Plus checkout:
-- luajit tools/verify-doesitdieplus.lua /absolute/path/to/UsefulPlatesAndTooltips
-- GPL source stays in that checkout and is loaded at runtime, never vendored into FlareUI.
local H = dofile('tools/tests/perf-helpers.lua')
local source = assert(arg[1], 'provide the official DoesItDiePlus 0.9.140 checkout')
assert(H.read(source..'/UsefulPlatesAndTooltips.toc'):find('## Version: 0.9.140\n',1,true), 'wrong Plus version')
local T = dofile('tools/tests/fixtures/nameplate-claims.lua')
local F,ctx=T.F,T.ctx
local now,enabled,total=0,true,31
function GetTime() return now end
function issecretvalue() return false end
function strtrim(s) return s:match('^%s*(.-)%s*$') end
function CreateFrame(kind,_,parent) return F.frame(kind,parent) end
function UnitExists() return true end
function UnitIsDead() return false end
function UnitHealth() return 50 end
function UnitHealthMax() return 100 end
function LibStub() return {RegisterCallback=function() end} end
UsefulPlatesAndTooltipsDB={frames={}}
UsefulPlatesAndTooltips_DoTInfoDB={showMarkers=true,showSkull=true,targetMarkers=true,focusMode='markerIcon'}
local dot={db=UsefulPlatesAndTooltips_DoTInfoDB,Internals={unitKey=function(unit) return unit end},
    dotBreakdownForUnit=function() return {{name='test',appliedAt=0,damage=total}},total end}
local BIT={name='UsefulPlatesAndTooltips',Module=function(name) assert(name=='DoTInfo'); return dot end,
    IsRunning=function() return enabled end,RegisterCommand=function() end,Say=function(message) error(message) end,
    DB=function() return UsefulPlatesAndTooltipsDB end}
for _,path in ipairs({'Core/PlateLayout.lua','Core/API.lua','Core/Frames.lua','Modules/DoTInfo/API.lua'}) do
    assert(loadfile(source..'/'..path))('UsefulPlatesAndTooltips',BIT)
end
assert(UsefulPlatesAndTooltips_API.Get('DoT')==UsefulPlatesAndTooltips_DoTAPI)
local p=T.pooled()
local a,b=T.plate('nameplate1'),T.plate('nameplate2')
C_NamePlate={GetNamePlateForUnit=function(unit) return ctx.units[unit] end}
local function added(unit)
    for _,f in ipairs(F.created) do
        local s=F.state[f]
        if s.events.NAME_PLATE_UNIT_ADDED and s.scripts.OnEvent then s.scripts.OnEvent(f,'NAME_PLATE_UNIT_ADDED',unit) end
    end
end
ctx.NP.Claim('nameplate1'); added('nameplate1')
local bar,path=BIT.Plate.HealthBar(a)
assert(bar==p.health and path=='auto FlareUIHealthBar', 'official Plus discovers the real FlareUI health bar')
assert(BIT.Plate.FillsReversed(bar)==false); bar:SetReverseFill(true)
assert(BIT.Plate.FillsReversed(bar)==true)
-- Load the actual native layering function without redistributing its source.
local native=H.read(source..'/Modules/DoTInfo/Nameplates.lua')
local layer=H.load(H.section(native,'local function isSecret(v)','-- "secret",')
    ..H.section(native,'local function keepAbove(w)','-- Nameplates have their own look')..'return keepAbove')
local w={healthBar=bar,marker=F.frame(),iconWindow=F.frame(),iconBar=F.frame()}
layer(w)
assert(w.marker:GetFrameLevel()==bar:GetFrameLevel()+5 and w.marker:GetFrameStrata()==bar:GetFrameStrata())
assert(w.iconWindow:GetFrameLevel()==bar:GetFrameLevel()+20)
-- Cross-plate reuse uses Plus's actual ancestry check. A live new unit also clears both native caches.
ctx.NP.ReleaseUnit('nameplate1'); ctx.NP.Claim('nameplate2'); added('nameplate2')
assert(b.FlareUIHealthBar==bar, 'normal pool reuse, no affinity')
a.UnitFrame:SetAlpha(0); now=now+1
assert(BIT.Plate.HealthBar(a)~=bar, 'old plate cannot retain the visible bar now under another plate')
assert(BIT.Plate.HealthBar(b)==bar)
p.health:Hide(); now=now+16; assert(BIT.Plate.HealthBar(b)==nil)
p.health:Show(); p.root:Hide(); now=now+16; assert(BIT.Plate.HealthBar(b)==nil)
p.root:Show(); now=now+16; assert(BIT.Plate.HealthBar(b)==bar)
ctx.NP.ReleaseUnit('nameplate2')
for i=1,80 do
    local live=T.plate('nameplate1')
    ctx.NP.Claim('nameplate1'); added('nameplate1')
    assert(BIT.Plate.HealthBar(live)==bar, 'event-driven cache invalidation and repeated pooled reuse')
    ctx.NP.ReleaseUnit('nameplate1')
end

-- Load the real FlareUI bridge against the real Plus API/callback bus.
for _,name in ipairs({'Target','Focus'}) do
    local frame=F.frame('Frame',UIParent); frame.Health=F.frame('StatusBar',frame); frame.Health:SetStatusBarTexture('test')
    _G['FlareUI_UF_'..name]=frame
    local blizzard=F.frame('Frame',UIParent); blizzard.HealthBar=F.frame('StatusBar',blizzard); blizzard:Hide()
    _G[name..'Frame']=blizzard
end
assert(select(2,BIT.Plate.UnitFrame('target'))==nil, 'Plus does not natively know FlareUI target without a custom path')
local ns={EditPreviewing=function() return false end,OnEditFight=function() end}
assert(loadfile('Modules/UnitFramesDoesItDie.lua'))('FlareUI',ns)
local loader=F.created[#F.created]; F.state[loader].scripts.OnEvent(loader,'PLAYER_LOGIN')
assert(BIT.API.HasListeners('DOTS_CHANGED'), 'registered on official callback bus')
local function marker(name)
    for _,f in ipairs(F.created) do if F.state[f].anchor==_G['FlareUI_UF_'..name].Health then return f end end
    error('missing marker')
end
local target,focus=marker('Target'),marker('Focus')
assert(target:IsShown() and focus:IsShown() and F.state[target].value==31)
total=47; dot.afterRefresh(); assert(F.state[target].value==47, 'official change notifications redraw FlareUI')
for _,unit in ipairs({'target','focus'}) do
    UsefulPlatesAndTooltipsDB.frames[unit]='FlareUI_UF_'..(unit=='target' and 'Target' or 'Focus')..'.Health'
    assert(select(2,BIT.Plate.UnitFrame(unit))==_G['FlareUI_UF_'..(unit=='target' and 'Target' or 'Focus')].Health)
end
ns.UFDoesItDie:Refresh(); assert(not target:IsShown() and not focus:IsShown(), 'native Plus owns valid manual paths')
UsefulPlatesAndTooltipsDB.frames.target='Missing.Health'; ns.UFDoesItDie:Refresh(); assert(target:IsShown())
enabled=false
assert(UsefulPlatesAndTooltips_API.Get('DoT')==nil and UsefulPlatesAndTooltips_DoTAPI~=nil)
ns.UFDoesItDie:Refresh(); assert(not target:IsShown() and not focus:IsShown())
assert(UsefulPlatesAndTooltips_DoTAPI.GetRemainingDamage('target')==0)
print('PASS: official Plus 0.9.140 discovery, ancestry/cache lifecycle, fill/layers, 80-plate reuse, API/bus, overrides and disabled module')
