-- Run from the repository root: luajit tools/tests/class-icon-portrait.lua
-- Portrait > Class Icon shows on every player, enemies too: the game hides an enemy player's class from
-- addons, and the hidden class still reaches SetAtlas as a hidden atlas name (ns.PaintClassIcon).
local isPlayer, class = true, "MAGE"
local SECRET = {}
local function secret(value) return setmetatable({ value = value }, SECRET) end
SECRET.__concat = function(a, b)
    local left = getmetatable(a) == SECRET and a.value or a
    local right = getmetatable(b) == SECRET and b.value or b
    return secret(left .. right)
end
local fixture, ns = dofile("tools/tests/fixtures/core.lua")(nil, function(env)
    env.UnitIsPlayer = function() return isPlayer end
    env.UnitClass = function() return "Class", class end
    env.GetClassAtlas = function(name) return ("classicon-%s"):format(name) end
    env.canaccessvalue = function(value) return getmetatable(value) ~= SECRET and type(value) ~= "userdata" end
end)

local function texture()
    local t = {}
    function t:SetAtlas(atlas, _, _, reset) self.atlas, self.reset = atlas, reset end
    function t:SetTexCoord(...) self.coords = { ... } end
    return t
end

-- a readable class: Blizzard's class atlas
local tex = texture()
assert(ns.PaintClassIcon(tex, "target") == true)
assert(tex.atlas == "classicon-MAGE" and tex.reset == true)

-- an enemy player: the hidden class still makes the icon, never read in Lua
class = secret("WARRIOR")
tex = texture()
assert(ns.PaintClassIcon(tex, "target") == true, "enemy players get their class icon too")
assert(getmetatable(tex.atlas) == SECRET and tex.atlas.value == "classicon-WARRIOR", "a hidden atlas name")
assert(tex.coords[1] == 0 and tex.coords[2] == 1, "a 2D picture's flip is cleared first")

-- a hidden value the client won't join: the caller shows the 2D picture
class = newproxy and newproxy(false) or secret(nil)
tex = texture()
assert(ns.PaintClassIcon(tex, "target") == false and tex.atlas == nil)

-- not a player, or no class: the 2D picture
isPlayer, class = false, "MAGE"
assert(ns.PaintClassIcon(texture(), "target") == false)
isPlayer, class = true, nil
assert(ns.PaintClassIcon(texture(), "target") == false)
print("PASS: Class Icon portraits show on enemy players too")
