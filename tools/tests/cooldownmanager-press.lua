-- Run from the repository root with Lua 5.1 or LuaJIT.
-- Show Button Presses (Modules/CooldownManager.lua): an Essential icon lit while its spell's key is held.
issecretvalue = function() return false end
InCombatLockdown = function() return false end
wipe = function(t) for key in pairs(t) do t[key] = nil end end
hooksecurefunc = function(object, method, hook)
    if type(object) == "string" then object, method, hook = _G, object, method end
    local original = object[method]
    object[method] = function(...)
        original(...)
        hook(...)
    end
end
C_CooldownViewer = {}
GetCVarBool = function() return true end
C_Spell = { GetSpellName = function(id) return "Spell " .. id end }
GetActionInfo = function(slot) return "spell", slot * 100 end

ActionButton1 = { action = 1 }
MultiBarBottomLeft = { actionButtons = { { action = 2 } } }
GetActionButtonForID = function(id) return _G["ActionButton" .. id] end
ActionButtonDown, ActionButtonUp = function() end, function() end
MultiActionButtonDown, MultiActionButtonUp = function() end, function() end

-- the mock keeps each icon's holder frame on the icon, to find its texture
CreateFrame = function(_, _, parent)
    local frame = {}
    if parent then parent.holder = frame end
    function frame:SetAllPoints() end
    function frame:SetFrameLevel() end
    function frame:SetScript() end
    function frame:UnregisterAllEvents() end
    function frame:CreateTexture()
        local texture = { shown = false }
        function texture:SetAllPoints() end
        function texture:SetAtlas() end
        function texture:Show() self.shown = true end
        function texture:Hide() self.shown = false end
        self.push = texture
        return texture
    end
    return frame
end

local ns = { modules = {}, L = setmetatable({}, { __index = function(_, key) return key end }) }
assert(loadfile("Modules/CooldownManager.lua"))("FlareUI", ns)
ns.IsGamepadUI = function() return false end
ns.CooldownManager.initialized = true
local db = { enabled = true, movedFromAuras = true, press = true }
ns.db = { profile = { cooldownmanager = db } }

local function Item(spell)
    local item = { cooldownInfo = { spellID = spell }, Cooldown = {} }
    function item:IsProtected() return false end
    function item:IsShown() return true end
    function item:GetWidth() return 50 end
    function item:GetFrameLevel() return 1 end
    return item
end
local items = { Item(100), Item(200) }
EssentialCooldownViewer = { itemFramePool = { EnumerateActive = function()
    local i = 0
    return function() i = i + 1; return items[i] end
end } }
local function lit(index)
    local holder = items[index].holder
    return holder and holder.push and holder.push.shown or false
end

ns.CooldownManager:Refresh()

-- press and hold the main bar's key: only the icon of that spell lights
ActionButtonDown(1)
assert(lit(1) and not lit(2), "the pressed spell's icon lights")
-- a second key held at the same time
MultiActionButtonDown("MultiBarBottomLeft", 1)
assert(lit(1) and lit(2), "two keys held light two icons")
ActionButtonUp(1)
assert(not lit(1) and lit(2), "a release ends only its own icon")
MultiActionButtonUp("MultiBarBottomLeft", 1)
assert(not lit(2), "released")

-- an unknown button or bar does nothing
ActionButtonDown(9)
MultiActionButtonDown("NoSuchBar", 1)

-- Blizzard hands a lit frame to another spell: the light goes
ActionButtonDown(1)
ns.CooldownManager:Refresh()
assert(not lit(1), "a refreshed frame is not left lit")
ActionButtonUp(1)

-- off: a press lights nothing
db.press = false
ActionButtonDown(1)
assert(not lit(1), "option off")
print("PASS: Cooldown Manager Show Button Presses")
