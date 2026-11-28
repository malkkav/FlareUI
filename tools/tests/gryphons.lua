-- Gryphons are a Quality of Life feature: they work with Action Bars off and stop with Quality of Life off.
local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local bars = { enabled = false, gryphonsBehind = true, capScale = { capLeft = 150 } }
local tweaks = { enabled = true }
local ns = {
    modules = {},
    L = setmetatable({}, { __index = function(_, key) return key end }),
    db = { profile = { actionbars = bars, tweaks = tweaks } },
    IsGamepadUI = function() return false end,
    SetSystemScale = function(frame, scale) frame:SetScale(scale) end,
}
function env.LibStub(name)
    assert(name == "FlareEditMode")
    return { SettingType = { Slider = 1 } }
end
local main = env.CreateFrame("Frame", "MainActionBar", env.UIParent)
local caps = env.CreateFrame("Frame", nil, main)
caps.LeftEndCap, caps.RightEndCap = env.CreateFrame("Frame", nil, caps), env.CreateFrame("Frame", nil, caps)
main.EndCaps = caps
caps:SetFrameLevel(10)
function main:UpdateEndCaps() self.EndCaps:Hide() end
-- Blizzard's Icon Size: the end caps only scale down (MainActionBar.lua EditModeSetScale)
function main:EditModeSetScale(newScale) self.EndCaps:SetScale(newScale < 1 and newScale or 1) end
env.MAIN_ACTION_BAR_MANAGE_END_CAPS = false
env.UnitFactionGroup = function() return "Alliance" end

ui:load("Modules/Gryphons.lua", ns)
local G = ns.Gryphons

-- Behind Bars and Scale with Action Bars off
ui:emit("PLAYER_ENTERING_WORLD")
assert(caps:GetFrameLevel() == G.LEVEL_BEHIND, "behind the bars without FlareUI's action bars")
assert(caps.LeftEndCap:GetScale() == 1.5 and caps.RightEndCap:GetScale() == 1)
main:Show()
main:UpdateEndCaps()
assert(caps:IsShown(), "the end caps come back with bar 1")

-- back above the text once Behind Bars is off (FlareUI moved it)
bars.gryphonsBehind = false
G.Refresh()
assert(caps:GetFrameLevel() == G.LEVEL_ABOVE)

-- Quality of Life off: the Scale row hides and a scaled gryphon goes back to 100%
tweaks.enabled = false
assert(G.SizeSetting("capLeft").hidden())
G.Refresh()
assert(caps.LeftEndCap:GetScale() == 1)

-- a change in combat waits for the fight's end
tweaks.enabled = true
ui.combat = true
G.SizeSetting("capRight").set(nil, 120)
assert(caps.RightEndCap:GetScale() == 1)
ui.combat = false
ui:emit("PLAYER_REGEN_ENABLED")
assert(caps.RightEndCap:GetScale() == 1.2 and bars.capScale.capRight == 120)

-- (Malkkav 11-27) bar 1's Icon Size under 100%: the container stays at 100% and the shrink goes on each
-- gryphon, with its Scale, so Blizzard's Edit Mode maths (its own scale only) place it right
main:EditModeSetScale(0.8)
ui:flushTimers()
assert(caps:GetScale() == 1, "the container stays at 100%")
assert(math.abs(caps.LeftEndCap:GetScale() - 0.8 * 1.5) < 0.0001 and math.abs(caps.RightEndCap:GetScale() - 0.8 * 1.2) < 0.0001,
    "the shrink on each gryphon, with its own Scale")
main:EditModeSetScale(1)
ui:flushTimers()
assert(caps:GetScale() == 1 and math.abs(caps.LeftEndCap:GetScale() - 1.5) < 0.0001, "back to the Scale alone")
-- Quality of Life off: Blizzard's container shrink again, the gryphons at 100%
main:EditModeSetScale(0.8)
ui:flushTimers()
tweaks.enabled = false
G.Refresh()
assert(math.abs(caps:GetScale() - 0.8) < 0.0001 and caps.LeftEndCap:GetScale() == 1, "Blizzard's again")
tweaks.enabled = true

print("PASS: gryphons work with Action Bars off, follow Quality of Life, and wait out a fight")
