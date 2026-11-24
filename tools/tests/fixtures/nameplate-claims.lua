local H = dofile('tools/tests/perf-helpers.lua')
local F = dofile('tools/tests/fixtures/doesitdie-frames.lua')
UIParent = F.frame()
function canaccessvalue() return true end
-- Exercise the real Claim/Release lifecycle, mocking layout/client operations outside this boundary.
local env = setmetatable({ F = F }, { __index = _G })
local code = [[
local NP = { ready = true }
local queue = { plates = {}, processing = {} }
function NP.ClearAuras() end
function NP.QueueAuras() end
function NP.ResetPendingCast(p) p.pendingCast, p.castEventGUID = nil, nil end
local byPlate, spare, state, stats, retries = {}, {}, {}, { secret=0, forbidden=0, given=0, claimed=0, failed=0 }, {}
local hidden = F.frame(); hidden:Hide()
local ns = { LogError = function(_, err) NP.lastError = err end }
local units = {}
local C_NamePlate = { GetNamePlateForUnit = function(unit) return units[unit] end }
local function Retry() end
local function SetClickArea() end
local function HideBlizzard(p, frame) p.blizz = frame; frame:SetAlpha(0) end
local function ShowBlizzard(p) if p.blizz then p.blizz:SetAlpha(1); p.blizz=nil end end
local function RegisterUnit() end
function NP.WantsPlate() return true, 'enemy' end
function NP.Peaceful() return false end
function NP.CombatFull() return true end
function NP.TypeDB() return {} end
function NP.UnitHidden() return false end
function NP.QuestieHasIcons() return false end
function NP.StopScale() end
function NP.Layout(p) p.layKind, p.layFull = 'enemy', true end
function NP.UpdateAll() if NP.fail then error('injected update failure') end end
local Release
]] .. H.section(H.read('Modules/Nameplates.lua'), 'function NP.Claim(unit)', '-- A unit swap with no event') .. [[
return { NP=NP, byPlate=byPlate, spare=spare, hidden=hidden, units=units, stats=stats }
]]
local chunk = assert(loadstring(code)); setfenv(chunk, env)
local ctx = chunk()
local function pooled()
    local holder = F.frame('Frame', ctx.hidden)
    local root = F.frame('Frame', holder)
    local box = F.frame('Frame', root)
    box:SetFrameLevel(10)
    local health = F.frame('StatusBar', box); health:SetFrameLevel(11)
    local p = { holder=holder, root=root, box=box, health=health, highlight=F.frame('Texture', health) }
    root:Hide()
    ctx.spare[#ctx.spare+1] = p
    return p
end
local function plate(unit)
    local p = F.frame('Frame', UIParent)
    p.UnitFrame = F.frame('Frame', p)
    p.UnitFrame.healthBar = F.frame('StatusBar', p.UnitFrame)
    p.unitToken = unit
    ctx.units[unit] = p
    return p
end
return { ctx=ctx, F=F, pooled=pooled, plate=plate }
