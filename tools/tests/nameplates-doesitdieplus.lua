local T = dofile('tools/tests/fixtures/nameplate-claims.lua')
local ctx, F = T.ctx, T.F
UsefulPlatesAndTooltips_API = {}
local pooled = T.pooled()
local a = T.plate('nameplate1')
ctx.NP.Claim('nameplate1')
assert(a.FlareUIHealthBar == pooled.health, 'Plus must find the live replacement through a health-named field')
pooled.health:Hide(); assert(not a.FlareUIHealthBar:IsVisible())
pooled.health:Show(); pooled.root:Hide(); assert(not a.FlareUIHealthBar:IsVisible())
pooled.root:Show(); a:Hide(); assert(not a.FlareUIHealthBar:IsVisible()); a:Show()
ctx.NP.ReleaseUnit('nameplate1')
assert(a.FlareUIHealthBar == nil and not pooled.health:IsVisible())
-- The same one-slot pool serves more than 40 distinct game plate objects over its lifetime.
for i = 1, 80 do
    local p = T.plate('nameplate2')
    ctx.NP.Claim('nameplate2')
    assert(p.FlareUIHealthBar == pooled.health and ctx.byPlate[p] == pooled, 'normal cross-plate reuse is preserved')
    ctx.NP.ReleaseUnit('nameplate2')
    assert(p.FlareUIHealthBar == nil)
end
local foreign = F.frame('StatusBar', a)
a.FlareUIHealthBar = foreign
ctx.NP.Claim('nameplate1'); assert(a.FlareUIHealthBar == foreign)
ctx.NP.ReleaseUnit('nameplate1'); assert(a.FlareUIHealthBar == foreign)
a.FlareUIHealthBar = nil
ctx.NP.Claim('nameplate1'); a.FlareUIHealthBar = foreign
ctx.NP.ReleaseUnit('nameplate1'); assert(a.FlareUIHealthBar == foreign)
a.FlareUIHealthBar = nil
ctx.NP.fail = true; ctx.NP.Claim('nameplate1')
assert(ctx.byPlate[a] == nil and a.FlareUIHealthBar == nil and not pooled.health:IsVisible())
ctx.NP.fail = false
DoesItDie = {}
ctx.NP.Claim('nameplate1')
assert(a.FlareUIHealthBar == nil, 'do not expose pooled bars to original DoesItDie\'s ancestry-blind cache')
ctx.NP.ReleaseUnit('nameplate1'); DoesItDie = nil
UsefulPlatesAndTooltips_API = nil
ctx.NP.Claim('nameplate1'); assert(a.FlareUIHealthBar == nil, 'unrelated addon configurations stay unchanged')
ctx.NP.ReleaseUnit('nameplate1')
local empty = F.frame('Frame', UIParent); ctx.units.nameplate3 = empty
ctx.NP.Claim('nameplate3'); assert(ctx.byPlate[empty] == nil and empty.FlareUIHealthBar == nil)
F.state[a].forbidden = true
ctx.NP.Claim('nameplate1'); assert(ctx.byPlate[a] == nil and a.FlareUIHealthBar == nil)
ctx.NP.ReleaseUnit('nameplate1'); assert(#ctx.spare == 1)
print('PASS: Plus health export, hidden/empty/forbidden plates, ownership, failed claim and 80-object normal pool reuse')
