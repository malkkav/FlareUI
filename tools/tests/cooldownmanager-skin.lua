-- Run from the repository root with Lua 5.1 or LuaJIT.
-- Skin Cooldown Manager on the icons (Modules/CooldownManager.lua): FlareUI's border in place of
-- Blizzard's ring, its edge following the icon's width, also on an icon with another Icon Shape.
issecretvalue = function() return false end
hooksecurefunc = function() end
C_CooldownViewer = {}
GetCVarBool = function() return true end
-- (the viewers here have no box: Icon Shape's reflow is cooldownmanager-shape.lua's)
InCombatLockdown = function() return true end
LibStub = function() return { Fetch = function(_, _, name) return name end } end
CreateFrame = function(_, _, parent)
    local frame = {}
    if parent then parent.border = frame end
    function frame:ClearAllPoints() end
    function frame:SetAllPoints() end
    function frame:SetFrameLevel() end
    function frame:SetBackdrop(backdrop) self.backdrop = backdrop end
    function frame:SetBackdropBorderColor() end
    function frame:RegisterEvent() end
    function frame:SetScript() end
    function frame:UnregisterAllEvents() end
    return frame
end

local ns = { modules = {}, L = setmetatable({}, { __index = function(_, key) return key end }) }
assert(loadfile("Modules/CooldownManager.lua"))("FlareUI", ns)
ns.IsGamepadUI = function() return false end
ns.CooldownManager.initialized = true
ns.BorderEdgeSize = function(_, size) return size end
ns.BORDER_COLOR = { r = 1, g = 1, b = 1 }
local shape = { essential = "rect", utility = "blizzard" }
ns.db = { profile = { cooldownmanager = { enabled = true, movedFromAuras = true, skin = true, shape = shape } } }

local function Item(width)
    local ring = { atlas = "UI-HUD-CoolDownManager-IconOverlay", alpha = 1 }
    function ring:GetAtlas() return self.atlas end
    function ring:SetAlpha(alpha) self.alpha = alpha end
    local item = { width = width, height = width, ring = ring, Cooldown = {}, Icon = {} }
    function item:GetWidth() return self.width end
    function item:GetHeight() return self.height end
    function item:GetFrameLevel() return 1 end
    function item:SetSize(w, h) self.width, self.height = w, h end
    function item:GetRegions() return self.Icon, ring end
    function item.Icon:SetTexCoord() end
    return item
end
local function Viewer(item)
    return { itemFramePool = { EnumerateActive = function()
        local done = false
        return function() if not done then done = true; return item end end
    end } }
end
local essential, utility = Item(50), Item(30)
EssentialCooldownViewer, UtilityCooldownViewer = Viewer(essential), Viewer(utility)

ns.CooldownManager:Refresh()
-- an Essential icon as a rectangle: the full edge for its width, Blizzard's ring gone
assert(essential.height == 37.5, "the shape was not applied with the skin on")
assert(essential.ring.alpha == 0, "Blizzard's ring still shows")
assert(essential.border and essential.border.backdrop.edgeSize == 16, "the border of a 50 px icon")
-- a Utility icon: a thinner edge for its 30 px
assert(utility.ring.alpha == 0 and utility.border.backdrop.edgeSize == 10, "the border of a 30 px icon")
print("PASS: Cooldown Manager icon skin")
