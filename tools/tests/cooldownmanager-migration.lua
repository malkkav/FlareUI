-- Run from the repository root with Lua 5.1 or LuaJIT.
-- Skin Cooldown Manager was a Buffs & Debuffs option (auras.skinCDM): moved once into the Cooldown
-- Manager's own settings (Modules/CooldownManager.lua).
local ns = { modules = {}, L = setmetatable({}, { __index = function(_, key) return key end }) }
assert(loadfile("Modules/CooldownManager.lua"))("FlareUI", ns)
ns.IsGamepadUI = function() return false end

local function migrate(auras, db)
    db = db or { enabled = false, skin = false }
    ns.db = { profile = { auras = auras, cooldownmanager = db } }
    ns.CooldownManager:ShouldLoad()
    return db
end

-- on with Buffs & Debuffs on: it stays on, behind the new switch
local auras = { enabled = true, skinCDM = true }
local db = migrate(auras)
assert(db.enabled and db.skin, "the skin stays on")
assert(auras.skinCDM == nil, "the old setting is gone")

-- Buffs & Debuffs off: the skin was not showing, it stays off
auras = { enabled = false, skinCDM = true }
db = migrate(auras)
assert(not db.enabled and not db.skin, "a skin that was not showing stays off")
assert(auras.skinCDM == nil, "the old setting is gone")

-- never on
db = migrate({ enabled = true })
assert(not db.enabled and not db.skin, "off stays off")

-- only once: a choice made since is kept
db = migrate({ enabled = true, skinCDM = true }, { enabled = false, skin = false, movedFromAuras = true })
assert(not db.enabled and not db.skin, "a profile already moved is left alone")
print("PASS: Cooldown Manager settings migration")
