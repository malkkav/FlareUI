-- Run from the repository root with Lua 5.1 or LuaJIT.
-- Soften Active Overlay (Modules/CooldownManager.lua): the swipe of an Essential icon while an
-- ability's effect runs, and Blizzard's own colour back afterwards.
local SECRET = {}
issecretvalue = function(value) return value == SECRET end
InCombatLockdown = function() return false end
wipe = function(t) for key in pairs(t) do t[key] = nil end end
hooksecurefunc = function(object, method, hook)
    local original = object[method]
    object[method] = function(...)
        original(...)
        hook(...)
    end
end
C_CooldownViewer = {}
GetCVarBool = function() return true end
CooldownViewerConstants = {
    ITEM_AURA_COLOR = { r = 1, g = 0.95, b = 0.57, a = 0.7 },
    ITEM_COOLDOWN_COLOR = { r = 0, g = 0, b = 0, a = 0.7 },
}

local ns = { modules = {}, L = setmetatable({}, { __index = function(_, key) return key end }) }
assert(loadfile("Modules/CooldownManager.lua"))("FlareUI", ns)
ns.IsGamepadUI = function() return false end
ns.CooldownManager.initialized = true
local db = { enabled = true, movedFromAuras = true, softOverlay = true }
ns.db = { profile = { cooldownmanager = db } }

local cooldown = {}
function cooldown:SetSwipeColor(r, g, b, a) self.color = { r, g, b, a } end
local item = { Cooldown = cooldown, wasSetFromAura = true }
-- Blizzard's pass over the icon's cooldown: its own swipe colour for what the icon shows
function item:RefreshSpellCooldownInfo()
    local color = self.wasSetFromAura == false and CooldownViewerConstants.ITEM_COOLDOWN_COLOR
        or CooldownViewerConstants.ITEM_AURA_COLOR
    cooldown:SetSwipeColor(color.r, color.g, color.b, color.a)
end
function item:IsProtected() return false end
function item:GetWidth() return 50 end
EssentialCooldownViewer = { itemFramePool = { EnumerateActive = function()
    local done = false
    return function() if not done then done = true; return item end end
end } }

local function alpha(expected, label)
    assert(cooldown.color and math.abs(cooldown.color[4] - expected) < 0.001,
        label .. ": alpha " .. tostring(cooldown.color and cooldown.color[4]))
end

ns.CooldownManager:Refresh()
alpha(0.2, "an effect running")
assert(cooldown.color[1] == 1, "the swipe keeps Blizzard's colour")

-- Blizzard paints its strong swipe again: faint again
item:RefreshSpellCooldownInfo()
alpha(0.2, "after Blizzard's own colour")

-- an unreadable state: Blizzard's swipe stays as painted
item.wasSetFromAura = SECRET
item:RefreshSpellCooldownInfo()
alpha(0.7, "unreadable state")

-- the effect ends: the cooldown's own swipe
item.wasSetFromAura = false
item:RefreshSpellCooldownInfo()
alpha(0.7, "the effect ended")
assert(cooldown.color[1] == 0, "the cooldown's swipe is Blizzard's dark one")

-- and starts again
item.wasSetFromAura = true
item:RefreshSpellCooldownInfo()
alpha(0.2, "a second effect")

-- switched off while the effect runs: Blizzard's strong swipe back
db.softOverlay = false
ns.CooldownManager:Refresh()
alpha(0.7, "option off")
assert(cooldown.color[1] == 1, "option off gives the effect's colour back")
print("PASS: Cooldown Manager Soften Active Overlay")
