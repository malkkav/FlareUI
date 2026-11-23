-- The "Slower" Hide Speed: ns.StagedFall fades to the resting opacity in 2 s, rests 2 s, then finishes
-- in 0.4 s. Only the real Core.lua section runs; the client is not needed.
local H = dofile("tools/tests/perf-helpers.lua")
local ns = {}
H.loadSections("Core.lua", {
    { '-- "Show Speed" / "Hide Speed" choices', "-- Numbers on the bars" },
}, { ns = ns, math = math })

assert(ns.FadeTime("slower") == 4 and ns.FadeTime("slow") == 0.4 and ns.FadeTime("nope") == 0)
local stage = ns.FADE_STAGES
assert(stage.alpha == 0.55 and stage.time == 2 and stage.hold == 2 and stage.finish == 0.4)

local STEP = 0.05
local function near(a, b, tolerance) return math.abs(a - b) <= (tolerance or 0.02) end

-- Plays a fade from `from` to `target`; returns the alpha at each whole step, in seconds
local function Play(from, target, seconds, state)
    local alpha, at = from, {}
    for step = 1, math.floor(seconds / STEP + 0.5) do
        alpha = ns.StagedFall(state, alpha, target, STEP)
        at[#at + 1] = alpha
        if step * STEP > seconds then break end
    end
    return alpha, at
end
local function At(samples, seconds) return samples[math.floor(seconds / STEP + 0.5)] end

-- Faded Opacity 0: down to 55% at 2 s, still there at 4 s, gone by 4.4 s
local state = {}
local _, samples = Play(1, 0, 5, state)
assert(near(At(samples, 1), 1 - 0.45 / 2), "halfway through the first stage")
assert(near(At(samples, 2), 0.55), "resting opacity after 2 s")
assert(near(At(samples, 3), 0.55) and near(At(samples, 3.9), 0.55), "rests while the hold runs")
assert(At(samples, 4.2) < 0.55 and At(samples, 4.2) > 0, "finishing after the rest")
assert(At(samples, 4.5) == 0, "fully faded by about 4.4 s")
for i = 2, #samples do assert(samples[i] <= samples[i - 1] + 1e-9, "never rises") end

-- A fade that the caller cleared (it rose, or settled) rests again from the start
state.stageHold = nil
local alpha = Play(1, 0, 2.5, state)
assert(near(alpha, 0.55))
assert(state.stageHold and state.stageHold > 0 and state.stageHold < stage.hold, "the rest counts down")

-- Faded Opacity above the resting one: one stage, no rest, straight to it
alpha = Play(1, 0.7, 2, {})
assert(near(alpha, 0.7) and alpha >= 0.7)
alpha = Play(0.7, 0.7, 1, {})
assert(alpha == 0.7)

-- Starting below the resting opacity (a fade that was cut short): no first stage, straight down
alpha = Play(0.3, 0, 1, {})
assert(alpha == 0)

print("PASS: staged Slower fade")
