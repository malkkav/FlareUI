-- Run from the repository root with Lua 5.1 or LuaJIT.
-- Icon Shape (Modules/CooldownManager.lua): Blizzard's square icon, or a rectangle with the art cut
-- to its shape. The viewer's rows and box follow a new shape at once, without Blizzard's layout.
local SECRET = {}
issecretvalue = function(value) return value == SECRET end
hooksecurefunc = function() end
C_CooldownViewer = {}
GetCVarBool = function() return true end
local inCombat = false
InCombatLockdown = function() return inCombat end

local ns = { modules = {}, L = setmetatable({}, { __index = function(_, key) return key end }) }
assert(loadfile("Modules/CooldownManager.lua"))("FlareUI", ns)
ns.IsGamepadUI = function() return false end
ns.CooldownManager.initialized = true
local shape = { essential = "blizzard" }
ns.db = { profile = { cooldownmanager = { enabled = true, movedFromAuras = true, shape = shape } } }

local item = { width = 50, height = 50, Cooldown = {}, Icon = {} }
function item:GetWidth() return self.width end
function item:GetHeight() return self.height end
function item:GetScale() return 0.8 end
function item:SetSize(width, height) self.width, self.height, self.sized = width, height, true end
function item:GetPoint() return unpack(self.point) end
function item:ClearAllPoints() self.point = nil end
function item:SetPoint(...) self.point = { ... } end
function item.Icon:SetTexCoord(...) self.coords = { ... } end
-- (as Blizzard lays them out: two rows of one icon, 50 high and 1 apart, at 80% Icon Size)
local second = setmetatable({ width = 50, height = 50, Cooldown = {}, Icon = { SetTexCoord = item.Icon.SetTexCoord } }, { __index = item })
local viewer = { childYPadding = 1, height = 101 * 0.8 }
function viewer:GetHeight() return self.height end
function viewer:SetHeight(height) self.height = height end
item.point, second.point = { "TOPLEFT", viewer, "TOPLEFT", 0, 0 }, { "TOPLEFT", viewer, "TOPLEFT", 0, -51 }
viewer.itemFramePool = { EnumerateActive = function()
    local items, i = { item, second }, 0
    return function() i = i + 1; return items[i] end
end }
EssentialCooldownViewer = viewer

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

-- the second row moves up and the box shrinks, as Blizzard's next layout would have it
assert(near(second.point[5], -38.5) and near(item.point[5], 0), "Rectangle: the rows were not moved")
assert(near(viewer.height, 76 * 0.8), "Rectangle: the box is " .. viewer.height)

-- a second pass changes nothing
item.sized = nil
ns.CooldownManager:Refresh()
assert(not item.sized, "an icon already in shape was resized again")

-- Default again: Blizzard's square, the whole art
set("blizzard")
size(50, 50, "Default")
cut(0, "Default")
assert(near(second.point[5], -51) and near(viewer.height, 101 * 0.8), "Default: the rows and the box are not Blizzard's again")

-- in a fight the box is left to Blizzard
inCombat = true
set("rect")
size(50, 37.5, "Rectangle in a fight")
assert(near(second.point[5], -51) and near(viewer.height, 101 * 0.8), "the box was touched in a fight")
print("PASS: Cooldown Manager Icon Shape")
