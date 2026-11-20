-- Run from the repository root with Lua 5.1 or LuaJIT.
-- Icon Shape (Modules/CooldownManager.lua): Blizzard's square icon, or a rectangle with the art cut
-- to its shape.
local SECRET = {}
issecretvalue = function(value) return value == SECRET end
hooksecurefunc = function() end
C_CooldownViewer = {}
GetCVarBool = function() return true end

local ns = { modules = {}, L = setmetatable({}, { __index = function(_, key) return key end }) }
assert(loadfile("Modules/CooldownManager.lua"))("FlareUI", ns)
ns.IsGamepadUI = function() return false end
ns.CooldownManager.initialized = true
local shape = { essential = "blizzard" }
ns.db = { profile = { cooldownmanager = { enabled = true, movedFromAuras = true, shape = shape } } }

local item = { width = 50, height = 50, Cooldown = {}, Icon = {} }
function item:GetWidth() return self.width end
function item:SetSize(width, height) self.width, self.height, self.sized = width, height, true end
function item.Icon:SetTexCoord(...) self.coords = { ... } end
EssentialCooldownViewer = { itemFramePool = { EnumerateActive = function()
    local done = false
    return function() if not done then done = true; return item end end
end } }

local function near(a, b) return math.abs(a - b) < 0.001 end
local function size(width, height, label)
    assert(near(item.width, width) and near(item.height, height), label .. ": " .. item.width .. " x " .. item.height)
end
local function cut(top, label)
    local c = item.Icon.coords
    assert(c and near(c[1], 0) and near(c[2], 1) and near(c[3], top) and near(c[4], 1 - top),
        label .. ": " .. (c and table.concat(c, " ") or "untouched"))
end
local function set(value)
    shape.essential = value
    ns.CooldownManager:Refresh()
end

-- Default: the icon is left as Blizzard made it
ns.CooldownManager:Refresh()
assert(not item.sized and not item.Icon.coords, "an icon on Default was touched")

-- a width that cannot be read: nothing yet, and the shape comes at the next pass
item.width = SECRET
set("rect")
assert(not item.sized, "an icon with an unreadable width was resized")
item.width = 50
ns.CooldownManager:Refresh()

-- Rectangle: Blizzard's width, three quarters of the height, the art cut top and bottom
size(50, 37.5, "Rectangle")
cut(0.125, "Rectangle")

-- a second pass changes nothing
item.sized = nil
ns.CooldownManager:Refresh()
assert(not item.sized, "an icon already in shape was resized again")

-- Default again: Blizzard's square, the whole art
set("blizzard")
size(50, 50, "Default")
cut(0, "Default")
print("PASS: Cooldown Manager Icon Shape")
