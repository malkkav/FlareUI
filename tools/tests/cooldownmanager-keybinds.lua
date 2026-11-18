-- Run from the repository root with Lua 5.1 or LuaJIT.
-- Show Keybinds (Modules/CooldownManager.lua): the action button's key on an Essential icon.
local SECRET = {}
issecretvalue = function(value) return value == SECRET end
InCombatLockdown = function() return false end
wipe = function(t) for key in pairs(t) do t[key] = nil end end
hooksecurefunc = function() end
C_CooldownViewer = {}
GetCVarBool = function() return true end

local NAMES = { [100] = "Fireball", [101] = "Fireball", [200] = "Frost Nova", [300] = "Blink" }
C_Spell = {
    GetSpellName = function(id) return NAMES[id] end,
    GetOverrideSpell = function(id) return id == 200 and 201 or id end,
}
C_SpellBook = { FindBaseSpellByID = function(id) return id end }

-- slot -> kind, id, subType
local slots = {
    [1] = { "spell", 100 },             -- Fireball, another rank than the icon's
    [2] = { "macro", 200, "spell" },    -- a macro casting Frost Nova
    [3] = { "item", 300 },
    [13] = { "spell", 100 },            -- Fireball again on the second bar
    [14] = { SECRET, SECRET },
}
GetActionInfo = function(slot) return unpack(slots[slot] or {}) end
local bound = { ActionButton1 = "SHIFT-1", ActionButton2 = "F", ActionButton3 = "G",
                MultiBarBottomLeftButton1 = "X", MultiBarBottomLeftButton2 = "Y" }
ActionButton1 = { name = "ActionButton1", action = 1 }
ActionButton2 = { name = "ActionButton2", action = 2 }
ActionButton3 = { name = "ActionButton3", action = 3 }
ActionButton4 = { name = "ActionButton4", action = 4 }
MultiBarBottomLeftButton1 = { name = "MultiBarBottomLeftButton1", action = 13 }
MultiBarBottomLeftButton2 = { name = "MultiBarBottomLeftButton2", action = 14 }

local function FontString()
    local text = { shown = true }
    function text:GetFont() return "font", 10 end
    function text:SetPoint() end
    function text:SetText(value) self.text = value end
    function text:Show() self.shown = true end
    function text:Hide() self.shown = false end
    return text
end
local created = {}
CreateFrame = function()
    local frame = {}
    created[#created + 1] = frame
    function frame:SetAllPoints() end
    function frame:SetFrameLevel() end
    function frame:CreateFontString()
        self.text = FontString()
        return self.text
    end
    function frame:SetScript() end
    function frame:RegisterEvent() end
    function frame:UnregisterAllEvents() end
    return frame
end

local ns = { modules = {}, L = setmetatable({}, { __index = function(_, key) return key end }) }
assert(loadfile("Modules/CooldownManager.lua"))("FlareUI", ns)
ns.IsGamepadUI = function() return false end
ns.CooldownManager.initialized = true
ns.GetFontPath = function(face) return face end
ns.SetFont = function() end
ns.SetFontUnscaled = function() end
ns.ApplyShadow = function() end
ns.ActionBars = {
    BindingKey = function(button) return bound[button.name] end,
    ShortenKey = function(key) return (key:gsub("SHIFT%-", "S")) end,
}
local db = { enabled = true, movedFromAuras = true, keybinds = true, keybindFont = { size = 0 } }
ns.db = { profile = { cooldownmanager = db } }

local function Item(info)
    local item = { cooldownInfo = info, Cooldown = {} }
    function item:IsProtected() return false end
    function item:GetWidth() return 50 end
    function item:GetFrameLevel() return 1 end
    return item
end
local items = {
    Item({ spellID = 101 }),                            -- matched by name: the bar holds another rank
    Item({ spellID = 999, overrideSpellID = 201 }),     -- matched by the bar spell's override
    Item({ spellID = 300 }),                            -- an item on the bar is not a spell
    Item({ spellID = SECRET }),
    Item(nil),
}
EssentialCooldownViewer = { itemFramePool = { EnumerateActive = function()
    local i = 0
    return function() i = i + 1; return items[i] end
end } }

local function key(index)
    -- the holders are made in the items' order, after the event frame
    local count = 0
    for _, frame in ipairs(created) do
        if frame.text then
            count = count + 1
            if count == index then return frame.text end
        end
    end
end

ns.CooldownManager:Refresh()
assert(key(1).text == "S1" and key(1).shown, "the first bar's key, shortened: " .. tostring(key(1).text))
assert(key(2).text == "F", "a macro's spell, by its override: " .. tostring(key(2).text))
assert(key(3) == nil, "only the two spells on a bar get a key")

-- the binding changes: the new key on the next refresh
bound.ActionButton1 = nil
ns.CooldownManager:Refresh()
assert(key(1).text == "X", "the second bar's key once the first has none: " .. tostring(key(1).text))

-- off: the texts go
db.keybinds = false
ns.CooldownManager:Refresh()
assert(not key(1).shown and not key(2).shown, "option off hides the keys")
print("PASS: Cooldown Manager Show Keybinds")
