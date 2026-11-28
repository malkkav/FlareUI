-- Run from the repository root: luajit tools/tests/cast-edge-glow-flash.lua
-- A cast bar's Edge Glow sits on the fill's front. The red "Interrupted" / "Failed" overlay and the
-- finish flash hide the fill, so the glow goes with it, and comes back for the next cast (Kelvan, 11-26:
-- the glow stayed in the middle of the red bar).
local db = {
    styleStart = true, frameFontsSeeded = true, castTimeSeeded = true,
    units = { player = { enabled = true } }, layouts = { Modern = {} },
    party = { size = {}, auras = {}, enabled = false }, boss = { enabled = false },
}
local ui, ns = dofile("tools/tests/fixtures/unitframes-ui.lua")(db)
local env = ui.env
local UF = ns.UnitFrames
local timers = {}
env.C_Timer = env.C_Timer or {}
env.C_Timer.NewTimer = function(_, fn)
    local t = { fn = fn }
    function t:Cancel() self.cancelled = true end
    timers[#timers + 1] = t
    return t
end

local function region()
    local r = { shown = true, alpha = 1 }
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:SetShown(v) self.shown = v and true or false end
    function r:IsShown() return self.shown end
    function r:SetAlpha(a) self.alpha = a end
    function r:SetText(t) self.text = t end
    function r:SetFormattedText(f, ...) self.text = f:format(...) end
    function r:SetTexture() end
    function r:SetVertexColor() end
    function r:SetAllPoints() end
    function r:GetTexture() return "bar" end
    return r
end
local function newCast()
    local cast = region()
    cast.Text, cast.Time, cast.fill = region(), region(), region()
    cast.fuiLook = { edge = region() }
    function cast:CreateTexture() return region() end
    function cast:GetStatusBarTexture() return self.fill end
    function cast:GetStatusBarColor() return 1, 0.7, 0 end
    function cast:CreateAnimationGroup()
        local g = region()
        g.playing = false
        function g:CreateAnimation()
            local a = {}
            function a:SetFromAlpha() end
            function a:SetToAlpha() end
            function a:SetDuration() end
            return a
        end
        function g:SetScript(_, fn) self.onFinished = fn end
        function g:Play() self.playing = true end
        function g:Stop() self.playing = false end
        function g:IsPlaying() return self.playing end
        return g
    end
    return cast
end

-- interrupted: the glow hides with the fill, and the end of the flash brings it back
local cast = newCast()
UF.FlashInterrupted(cast, nil)
assert(cast.fill.alpha == 0 and cast.FlashFill.shown, "the red overlay replaces the fill")
assert(not cast.fuiLook.edge.shown, "no Edge Glow on an interrupted cast")
timers[#timers].fn()
assert(cast.fuiLook.edge.shown and cast.fill.alpha == 1, "back for the next cast")

-- failed (your own cast), and a new cast that starts during the red hold
cast = newCast()
UF.FlashInterrupted(cast, nil, true)
assert(not cast.fuiLook.edge.shown, "no Edge Glow on a failed cast")
UF.EndCastFlash(cast)
assert(cast.fuiLook.edge.shown, "a new cast shows it again")

-- a finished cast: the full overlay fades out without the glow; a channel keeps its fill, and its glow
cast = newCast()
UF.FinishCast(cast, false)
assert(not cast.fuiLook.edge.shown, "no Edge Glow on the finish flash")
cast.FadeAnim.onFinished()
assert(cast.fuiLook.edge.shown, "back after the fade")
cast = newCast()
UF.FinishCast(cast, true)
assert(cast.fuiLook.edge.shown, "a channel fades with its own fill and glow")

-- a cast bar without Edge Glow (never made): nothing to hide
cast = newCast()
cast.fuiLook = nil
UF.FlashInterrupted(cast, nil)
UF.EndCastFlash(cast)
print("PASS: cast bar Edge Glow hides with the interrupted, failed and finish flashes")
