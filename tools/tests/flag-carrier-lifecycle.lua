-- Flag carriers follow the arena unit slots with stable clicks and a combat-safe replacement.
local ui, ns, unit, edit = dofile("tools/tests/fixtures/party-world.lua")
local E = ui.env
ui:load("ProfileLayout.lua", ns)
local db = ns.db.profile.unitframes.flagCarriers
unit.arena2 = { name = "Runner", class = "ROGUE", level = 60, health = 66, power = 12, hostile = true, mark = 2 }
E.UnitFactionGroup = function(token) return token == "arena2" and "Horde" or "Alliance" end
local arenaEnemy = E.CreateFrame("Frame", "ArenaEnemyFramesContainer", E.UIParent)
ui:load("Modules/FlagCarriers.lua", ns)
local fc = ns.FlagCarriers
assert(not fc:ShouldLoad(), "the optional frames start disabled")
db.enabled = true
assert(fc:ShouldLoad())
ui.combat = true
fc:Init()
assert(not fc.initialized)
ui.combat = false
ui:emit("PLAYER_REGEN_ENABLED")
local holder, a, b = E.FlareUI_FlagCarriers, E.FlareUI_FlagCarrier1, E.FlareUI_FlagCarrier2
local function option(label)
    for _, row in ipairs(holder.settings) do if row.name == label then return row end end
    error("Missing setting " .. label)
end
local parking = arenaEnemy:GetParent()
assert(fc.initialized and parking ~= E.UIParent and not parking:IsShown())
arenaEnemy:SetParent(E.UIParent)
assert(arenaEnemy:GetParent() == parking, "Blizzard reparenting is immediately corrected out of combat")
assert(not a:IsShown() and b:IsShown() and b.unitWatched and b.Name:GetText() == "Runner")
assert(b:GetAttribute("*type1") == "target" and b:GetAttribute("*type2") == "focus" and E.ClickCastFrames[b])
assert(b.RoleIcon:IsShown() and not b.RaidIcon:IsShown(), "the carrier displays its faction crest without a raid marker")
ui.targetUnit = "arena2"
ui:emit("PLAYER_TARGET_CHANGED")
assert(b.TargetHighlight:GetAlpha() == 1)
local height = holder:GetHeight()
option("Growth").set("Modern", "UP")
assert(select(5, a:GetPoint()) < select(5, b:GetPoint()))
option("Cast Bar").set("Modern", false)
assert(holder:GetHeight() < height)
holder.moved(holder, "Modern", "LEFT", 9.6, -88.5)
edit.callbacks.layout("Modern")
assert(select(4, holder:GetPoint()) == 10 and select(5, holder:GetPoint()) == -88)

ui.editing = true
edit.callbacks.enter()
assert(a:IsShown() and not a.unitWatched and a.Name:GetText() == "Kaelith" and b.Name:GetText() == "Zorgath")
assert(holder:GetFrameStrata() == "HIGH" and b:GetFrameStrata() == "HIGH")
ui.editing = false
edit.callbacks.exit()
assert(not a:IsShown() and b.unitWatched and holder:GetFrameStrata() == "LOW")

ui.combat = true
arenaEnemy:SetParent(E.UIParent)
option("Width").set("Modern", 209)
assert(arenaEnemy:GetParent() == E.UIParent and holder:GetWidth() ~= 209, "combat defers reparenting and layout")
ui.combat = false
ui:emit("PLAYER_REGEN_ENABLED")
assert(arenaEnemy:GetParent() == parking and holder:GetWidth() == 209)

unit.arena2.health = 43
ui:emit("ARENA_OPPONENT_UPDATE", "arena2", "seen")
assert(b.Health:GetValue() == 43)
unit.arena2.name, unit.arena2.guid = "New Runner", "Player-9"
ui:flushTimers()
assert(b.Name:GetText() == "New Runner", "the periodic check detects changes to a carrier GUID")

assert(not a.AuraPos and not b.AuraPos, "their auras are always off: no containers")
print("PASS: flag carriers follow unit slots, park Blizzard frames and respect combat")
