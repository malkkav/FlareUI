-- Hide/Show Auras: the Always Show list adds a row of only its spells after the frame's buffs or
-- debuffs, and the usual rows leave those spells out; the hidden list keeps working; one list per spell.
local profile = { auras = { hidden = {}, shown = {} } }
local _, ns = dofile("tools/tests/fixtures/core.lua")(profile)
local HA, AP = ns.HiddenAuras, ns.AuraPolicy

local fails = 0
local function check(ok, msg) if not ok then fails = fails + 1 print("FAIL: " .. msg) end end
local function lanes()
    return {
        { key = "debuffs", kind = "debuffs", place = "TOPLEFT", isDebuff = true, filter = "HARMFUL", enemyFilter = "HARMFUL|PLAYER" },
        { key = "purge", kind = "buffs", place = "BOTTOMLEFT", enemyOnly = true, filter = "HELPFUL|RAID_PLAYER_DISPELLABLE" },
        { key = "buffs", kind = "buffs", place = "BOTTOMLEFT", joinPrevious = true, filter = "HELPFUL" },
    }
end
local function keys(list) local t = {} for i, l in ipairs(list) do t[i] = l.key end return table.concat(t, ",") end

-- nothing listed: lanes as they were
check(keys(AP.ApplyHidden(lanes(), "target")) == "debuffs,purge,buffs", "empty lists change nothing")

-- an Always Show spell: a row after each kind, the usual rows leave it out, the purge row keeps it
HA.Add(7386, "shown")
local out = AP.ApplyHidden(lanes(), "target")
check(keys(out) == "debuffs,alwaysDebuffs,purge,buffs,alwaysBuffs", "always rows follow their kind: " .. keys(out))
check(out[2].candidates.includeSpellIDs[7386] and out[2].joinPrevious and out[2].place == "TOPLEFT", "debuff always row")
check(out[2].enemyFilter == nil and out[2].filter == "HARMFUL", "always debuffs: plain filter, no PLAYER")
check(out[1].candidates.excludeSpellIDs[7386], "usual debuff row leaves it out")
check(not (out[3].candidates and out[3].candidates.excludeSpellIDs), "purge row keeps it")
check(out[5].enemyFilter == "HELPFUL|!RAID_PLAYER_DISPELLABLE" and out[5].filter == "HELPFUL", "always buffs skip purgeable on enemies")
check(not AP.ApplyHidden(lanes(), "auras")[2] or AP.ApplyHidden(lanes(), "auras")[2].key ~= "alwaysDebuffs", "not on Buffs & Debuffs frames")
check(keys(AP.ApplyHidden(lanes(), "target", true)) == "debuffs,purge,buffs", "not in Edit Mode")

-- a hidden spell next to it: the usual rows leave out both, the purge row only the hidden one
HA.Add(6788)
out = AP.ApplyHidden(lanes(), "target")
check(out[1].candidates.excludeSpellIDs[6788] and out[1].candidates.excludeSpellIDs[7386], "usual rows leave out both lists")
check(out[3].candidates.excludeSpellIDs[6788] and not out[3].candidates.excludeSpellIDs[7386], "purge row: hidden only")

-- one list per spell: adding to the other list moves it
HA.Add(6788, "shown")
check(HA.ListOf(6788) == "shown" and not profile.auras.hidden[6788], "moved to Always Show")
-- Show On narrows it
profile.auras.shown[7386] = "party"
profile.auras.shown[6788] = "party"
HA.Changed()
check(keys(AP.ApplyHidden(lanes(), "target")) == "debuffs,purge,buffs", "Show On leaves the target out")
HA.Remove(7386, "shown")
check(profile.auras.shown[7386] == nil, "removed")

-- Hide / Show moves a listed spell and keeps its frames (Buffs & Debuffs off for Show)
HA.Add(1126)
profile.auras.hidden[1126] = "auras,target,party"
HA.SetList(1126, "shown")
check(profile.auras.shown[1126] == "target,party" and not profile.auras.hidden[1126], "to Show: " .. tostring(profile.auras.shown[1126]))
HA.SetList(1126, "hidden")
check(profile.auras.hidden[1126] == "auras,target,party" and not profile.auras.shown[1126], "back to Hide: " .. tostring(profile.auras.hidden[1126]))

-- (11-24) a place that mixes Blizzard's raid rules and plain ones splits in two
do
    local function names(list) return list and keys(list) or "none" end
    local function lane(key, policy, joins) return { key = key, policy = policy, joinPrevious = joins } end
    local first, rest, beside = AP.SplitPlace({ lane("buffs", "process"), lane("alwaysBuffs", "none", true) })
    check(names(first) == "buffs" and names(rest) == "alwaysBuffs" and beside == true, "an always row goes on beside")
    first, rest, beside = AP.SplitPlace({ lane("debuffs", "processDispellable"), lane("alwaysDebuffs", "none", true), lane("buffs", "none") })
    check(names(first) == "debuffs" and names(rest) == "alwaysDebuffs,buffs" and beside == false, "everyone's buffs: a line of their own")
    first, rest = AP.SplitPlace({ lane("buffs", "none"), lane("alwaysBuffs", "none", true) })
    check(names(first) == "buffs,alwaysBuffs" and rest == nil, "all plain: one container")
    first, rest = AP.SplitPlace({ lane("debuffs", "process"), lane("buffs", "process") })
    check(names(first) == "debuffs,buffs" and rest == nil, "all on Blizzard's rules: one container")
end

if fails > 0 then print(fails .. " failed") os.exit(1) end
print("PASS aura-show-list")
