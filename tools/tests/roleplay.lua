-- The optional integration must stay dormant without TRP3 or enabled options.
local loadModule = assert(loadfile("Modules/Roleplay.lua"))
local events, queued, id, secret, records = {}, nil, "A", false, {}
local np = { enabled = true, rpColours = false, rpNames = false }
local uf = { enabled = true, rpHealth = false, rpNames = false }
local frameRefreshes, isPlayer = 0, true
local ns = { modules = {}, db = { profile = { nameplates = np, unitframes = uf } },
    RefreshNameplateText = function() end, RefreshUnitFrameHealthColor = function() end,
    RefreshUnitFrameNames = function() frameRefreshes = frameRefreshes + 1 end }
loadModule("FlareUI", ns)
assert(ns.Roleplay.Hidden() and not ns.Roleplay:ShouldLoad())
TRP3_Addon = {}
TRP3_API = { GameEvents = {}, RegisterCallback = function(_, event, cb)
    events[event] = cb
    return { Unregister = function() events[event] = nil end }
end }
function wipe(t) for k in pairs(t) do t[k] = nil end end
function UnitNameUnmodified() return id end
function UnitIsPlayer() return isPlayer end
function canaccessvalue() return not secret end
function canaccessallvalues() return not secret end
TRP3_NameUtil = { GetQualifiedName = function() assert(not secret); return id end }
AddOn_TotalRP3 = { Player = { CreateFromCharacterID = function(key)
    local record = records[key] or {}
    return { GetFirstName = function() return record.first end, GetFullName = function() return record.name end,
        GetCustomColor = function() return record.color end,
        GetCustomColorForDisplay = function() return { GetRGB = function() return 0.8, 1, 1 end } end }
end } }
C_Timer = { After = function(_, f) assert(not queued); queued = f end }
loadModule("FlareUI", ns)
ns.Roleplay:Init()
events.WORKFLOW_ON_LOADED()
assert(not ns.Roleplay.Hidden() and not events.REGISTER_DATA_UPDATED and not ns.NameplateTextProvider)
np.rpColours, uf.rpHealth = true, true
ns.Roleplay.Refresh()
records.A = { first = "Lady Aster", name = "Lady Aster Moonfall", color = { GetRGB = function() return 0.2, 0, 0 end } }
local name, r = ns.NameplateTextProvider("nameplate1")
assert(not name and r == 0.8 and ns.UnitFrameHealthColorProvider("target") == 0.2)
np.rpNames = true
ns.Roleplay.Refresh()
assert(ns.NameplateTextProvider("nameplate1", false) == "Lady Aster")
assert(ns.NameplateTextProvider("nameplate1", true) == "Lady Aster Moonfall")
np.rpNames, np.rpColours, uf.rpHealth, uf.rpNames = false, false, false, true
ns.Roleplay.Refresh()
assert(not ns.NameplateTextProvider and not ns.UnitFrameHealthColorProvider)
assert(ns.UnitFrameNameProvider("player", false) == "Lady Aster")
assert(ns.UnitFrameNameProvider("target", true) == "Lady Aster Moonfall")
assert(not ns.UnitFrameNameProvider("focus", true))
isPlayer = false
assert(not ns.UnitFrameNameProvider("target", true))
isPlayer = true
id = "B"
assert(not ns.UnitFrameNameProvider("target", true))
records.B = { first = "", name = "Birch" }
events.REGISTER_DATA_UPDATED(nil, "Other")
assert(not queued)
events.REGISTER_DATA_UPDATED(nil, "B")
events.REGISTER_PROFILES_LOADED()
queued()
assert(frameRefreshes == 2 and ns.UnitFrameNameProvider("target", true) == "Birch")
np.rpNames, uf.rpHealth = true, true
ns.Roleplay.Refresh()
assert(ns.UnitFrameHealthColorProvider("target") == "class")
assert(ns.NameplateTextProvider("nameplate1", false) == nil, "empty given name must use the game's first name")
assert(ns.NameplateTextProvider("nameplate1", true) == "Birch")
secret = true
assert(not ns.NameplateTextProvider("nameplate1"))
assert(not ns.UnitFrameNameProvider("target", true))
np.enabled, uf.enabled = false, false
ns.Roleplay.Refresh()
assert(not ns.NameplateTextProvider and not ns.UnitFrameHealthColorProvider and not ns.UnitFrameNameProvider and not events.REGISTER_DATA_UPDATED)
print("PASS: optional RP integration, settings, recycled units and late profiles")
