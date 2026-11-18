-- Run from the repository root with Lua 5.1 or LuaJIT.
-- Show Cooldown During Effect (Modules/CooldownManager.lua): the ability's own cooldown in the corner
-- of an Essential icon while Blizzard shows its effect's time.
local SECRET = {}
issecretvalue = function(value) return value == SECRET end
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

-- spells 100 and 301 are on cooldown, 200 and 300 are ready
local active = { [100] = true, [301] = true }
local asked
C_Spell = {
    GetSpellCooldown = function(id) return { isActive = active[id] or false } end,
    GetSpellCooldownDuration = function(id, ignoreGCD)
        asked = ignoreGCD
        return { spell = id }
    end,
}

local timers, fonts = {}, 0
CreateFrame = function(kind, _, parent)
    local frame = {}
    function frame:ClearAllPoints() end
    function frame:SetPoint() end
    function frame:SetFrameLevel() end
    function frame:SetDrawSwipe() end
    function frame:SetDrawEdge() end
    function frame:SetDrawBling() end
    function frame:SetHideCountdownNumbers() end
    function frame:EnableMouse() end
    function frame:GetCountdownFontString() return { GetFont = function() return "font", 10 end } end
    -- the worst case: hidden once cleared, and not shown again by a new duration
    function frame:Show() self.shown = true end
    function frame:SetCooldownFromDurationObject(duration) self.duration = duration end
    function frame:Clear() self.duration, self.shown = nil, false end
    if kind == "Cooldown" then timers[parent] = frame end
    return frame
end

local ns = { modules = {}, L = setmetatable({}, { __index = function(_, key) return key end }) }
assert(loadfile("Modules/CooldownManager.lua"))("FlareUI", ns)
ns.IsGamepadUI = function() return false end
ns.CooldownManager.initialized = true
ns.GetFontPath = function(face) return face end
ns.SetFont = function() fonts = fonts + 1 end
ns.SetFontUnscaled = ns.SetFont
ns.ApplyShadow = function() end
local db = { enabled = true, movedFromAuras = true, effectCooldown = true }
ns.db = { profile = { cooldownmanager = db } }

local function Item(spell, override)
    local item = { Cooldown = {}, cooldownInfo = { spellID = spell, overrideSpellID = override }, wasSetFromAura = false }
    -- Blizzard's pass over the icon's cooldown; it paints nothing when the icon has nothing to show
    function item:RefreshSpellCooldownInfo() end
    function item:GetWidth() return 50 end
    function item:GetFrameLevel() return 1 end
    return item
end
local busy, ready, swapped = Item(100), Item(200), Item(300, 301)
local items = { busy, ready, swapped }
EssentialCooldownViewer = { itemFramePool = { EnumerateActive = function()
    local i = 0
    return function() i = i + 1; return items[i] end
end } }
local function corner(item) return timers[item] and timers[item].shown and timers[item].duration end

ns.CooldownManager:Refresh()
assert(not corner(busy), "a cooldown alone is Blizzard's own display")

-- the effect starts while the ability is on cooldown
for _, item in ipairs(items) do
    item.wasSetFromAura = true
    item:RefreshSpellCooldownInfo()
end
assert(corner(busy) and corner(busy).spell == 100, "the ability's cooldown in the corner")
assert(asked == true, "the global cooldown is left out")
assert(not corner(ready), "an ability that is ready shows nothing")
assert(corner(swapped) and corner(swapped).spell == 301, "the override's cooldown, as Blizzard shows it")

-- the font is set once, not on every pass
local before = fonts
busy:RefreshSpellCooldownInfo()
assert(fonts == before, "the font was set again")

-- an unreadable state changes nothing
busy.wasSetFromAura = SECRET
busy:RefreshSpellCooldownInfo()
assert(corner(busy), "unreadable state")

-- the cooldown ends during the effect, and starts again
busy.wasSetFromAura = true
active[100] = nil
busy:RefreshSpellCooldownInfo()
assert(not corner(busy), "the cooldown ended")
active[100] = true
busy:RefreshSpellCooldownInfo()
assert(corner(busy), "on cooldown again")

-- Blizzard gives the frame another spell in place, one that is ready
busy.cooldownInfo = { spellID = 200 }
busy:RefreshSpellCooldownInfo()
assert(not corner(busy), "another spell on the frame")
busy.cooldownInfo = { spellID = 100 }
busy:RefreshSpellCooldownInfo()
assert(corner(busy), "the first spell again")

-- the effect ends: Blizzard shows the cooldown itself
busy.wasSetFromAura = false
busy:RefreshSpellCooldownInfo()
assert(not corner(busy), "the effect ended")

-- switched off while it shows
busy.wasSetFromAura = true
busy:RefreshSpellCooldownInfo()
assert(corner(busy), "shown again")
db.effectCooldown = false
ns.CooldownManager:Refresh()
assert(not corner(busy), "option off")
print("PASS: Cooldown Manager Show Cooldown During Effect")
