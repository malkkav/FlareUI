-- (Malkkav 11-27) The defaults changed for new players only. Import.lua's NewPlayerDefaults runs on the raw
-- saved settings before AceDB opens them: an account that used FlareUI gets each old value written where it
-- has nothing saved, in every profile and every unit frame style's stored setup; a new install gets nothing.
local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local ns = { L = setmetatable({}, { __index = function(_, key) return key end }) }
ui:load("Import.lua", ns)
local OLD = assert(ns.OLD_DEFAULTS_V2)

-- a new install: nothing saved yet, nothing written
env.FlareUI2_DB = nil
assert(ns.NewPlayerDefaults() == true and env.FlareUI2_DB == nil, "a new install keeps the new defaults")

-- the second login of that install: Core.lua marked it, so it isn't taken for an old account
env.FlareUI2_DB = { global = { defaultsV2 = true, defaultsV3 = true, whatsNewSeen = "7.1.3" }, profiles = { Default = { chat = {} } } }
assert(ns.NewPlayerDefaults() == false and env.FlareUI2_DB.profiles.Default.chat.formatPlayer == nil,
    "a marked install is left alone")

-- an account from before: every profile gets the old values where nothing is saved; what the player
-- picked stays
env.FlareUI2_DB = {
    global = { whatsNewSeen = "7.1.2" },
    profiles = {
        Default = {
            chat = { formatPlayer = true },
            unitframes = { units = { player = { buffs = "BOTTOM" } },
                           styleProfiles = { usual = { units = { focus = { width = 150 } } }, plate = { party = {} } } },
        },
        Alt = {},
    },
}
assert(ns.NewPlayerDefaults() == false)
local sv = env.FlareUI2_DB
local main, alt = sv.profiles.Default, sv.profiles.Alt
assert(sv.global.defaultsV2, "it runs once")
assert(main.chat.formatPlayer == true and main.chat.formatNPC == false, "a pick stays; the rest gets the old default")
assert(main.unitframes.units.player.buffs == "BOTTOM" and main.unitframes.units.player.debuffs == "TOPRIGHT")
assert(main.unitframes.raid.powerHeight == 10 and main.unitframes.raid.mainTanks.enabled == false)
assert(main.unitframes.legacyStyle and main.nameplates.legacyBase, "the old frame style start and plate tables")
assert(alt.chat.formatNPC == false and alt.tweaks.lootFeed == false and alt.tooltips.corner == "auto", "every profile")
-- the other styles' stored setups: their own per-style values, never the shared ones
local usual, plate = main.unitframes.styleProfiles.usual, main.unitframes.styleProfiles.plate
assert(usual.units.player.buffs == "TOPLEFT" and usual.units.focus.width == 150 and plate.party.showPlayer == true)
assert(usual.raid == nil and usual.auraTimer == nil, "raid and Aura Timer are shared, not per style")
-- every old value written somewhere in the plain profile
local function At(t, path)
    for key in path:gmatch("[^%.]+") do
        if type(t) ~= "table" then return nil end
        t = t[key]
    end
    return t
end
for path, value in pairs(OLD) do
    assert(At(alt, path) == value, path)
end

-- once only: a second run changes nothing
alt.chat.formatNPC = true
assert(ns.NewPlayerDefaults() == false and alt.chat.formatNPC == true)

-- (11-28) pass 3 on an account that had pass 2 already: only its own table, once
env.FlareUI2_DB = { global = { defaultsV2 = true, whatsNewSeen = "7.1.2" },
    profiles = { Default = { chat = {}, objectivetracker = { width = 300 } } } }
assert(ns.NewPlayerDefaults() == false)
local p3 = env.FlareUI2_DB.profiles.Default
assert(env.FlareUI2_DB.global.defaultsV3 and p3.chat.formatNPC == nil, "pass 2 is not run again")
assert(p3.objectivetracker.width == 300 and p3.objectivetracker.maxHeight == 300 and p3.objectivetracker.questGap == 9)
assert(p3.unitframes.raid.spacing == 10 and p3.unitframes.raid.smoothBars == nil, "raid Bar Effects never changed")
assert(p3.unitframes.resource.bars.health.barEdgeGlow == false)
-- an account whose only trace is an empty profile (never set up) counts as new
env.FlareUI2_DB = { global = {}, profiles = { Default = {} } }
assert(ns.NewPlayerDefaults() == true and env.FlareUI2_DB.profiles.Default.chat == nil)
env.FlareUI2_DB = nil
print("PASS: new defaults reach new installs only; old accounts keep their old values")
