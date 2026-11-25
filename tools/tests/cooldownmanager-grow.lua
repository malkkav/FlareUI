-- Run from the repository root with Lua 5.1 or LuaJIT.
-- Grow From (Modules/CooldownManager.lua): where each shown frame of a Cooldown Manager viewer goes.
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
C_AddOns = { IsAddOnLoaded = function() return true end }
C_Timer = { After = function() end }
EventUtil = { ContinueOnAddOnLoaded = function(_, callback) callback() end }
GetCVarBool = function() return true end
CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end

local ns = { modules = {}, L = setmetatable({}, { __index = function(_, key) return key end }) }
assert(loadfile("Modules/CooldownManager.lua"))("FlareUI", ns)
local GrowPoint = ns.CooldownManager.GrowPoint

local function check(args, point, x, y)
    local gotPoint, gotX, gotY = GrowPoint(unpack(args))
    local label = table.concat({ tostring(args[1]), tostring(args[2]), tostring(args[5]), tostring(args[6]) }, " ")
    assert(gotPoint == point, label .. ": point " .. tostring(gotPoint))
    assert(math.abs(gotX - x) < 0.001 and math.abs(gotY - y) < 0.001, label .. ": offset " .. gotX .. ", " .. gotY)
end

-- (grow, i, count, step, horizontal, reversed); three frames, 40 wide with a gap of 4
-- a row: Blizzard's first frame is the left one
check({ "START", 1, 3, 44, true, false }, "TOPLEFT", 0, 0)
check({ "START", 3, 3, 44, true, false }, "TOPLEFT", 88, 0)
check({ "END", 1, 3, 44, true, false }, "TOPRIGHT", -88, 0)
check({ "END", 3, 3, 44, true, false }, "TOPRIGHT", 0, 0)
check({ "CENTER", 1, 3, 44, true, false }, "TOP", -44, 0)
check({ "CENTER", 2, 3, 44, true, false }, "TOP", 0, 0)
check({ "CENTER", 1, 2, 44, true, false }, "TOP", -22, 0)
-- reversed: the same places, the first frame on the right
check({ "START", 1, 3, 44, true, true }, "TOPLEFT", 88, 0)
check({ "END", 1, 3, 44, true, true }, "TOPRIGHT", 0, 0)
check({ "CENTER", 1, 3, 44, true, true }, "TOP", 44, 0)
-- a column: Blizzard's first frame is the bottom one
check({ "START", 1, 3, 44, false, false }, "TOPLEFT", 0, -88)
check({ "START", 3, 3, 44, false, false }, "TOPLEFT", 0, 0)
check({ "END", 1, 3, 44, false, false }, "BOTTOMLEFT", 0, 0)
check({ "CENTER", 1, 3, 44, false, false }, "LEFT", 0, -44)
-- the Tracked Bars (reversed on Top): the first bar at the chosen edge
check({ "START", 1, 3, 44, false, true }, "TOPLEFT", 0, 0)
check({ "START", 3, 3, 44, false, true }, "TOPLEFT", 0, -88)
check({ "END", 3, 3, 44, false, false }, "BOTTOMLEFT", 0, 88)
-- one frame alone sits on the edge
check({ "CENTER", 1, 1, 44, true, false }, "TOP", 0, 0)

-- The frames themselves, in Blizzard's order (CooldownViewer.lua RefreshLayout): every frame released
-- (its points cleared), acquired again, then one layout that gives each its slot, shown or hidden.
-- Icon Size 50%: Blizzard's padding is in the frames' own units, so the step stays 40 + 4.
ns.IsGamepadUI = function() return false end
local grow = { buffs = "CENTER" }
ns.db = { profile = { cooldownmanager = { enabled = true, movedFromAuras = true, grow = grow } } }

local viewer = { iconScale = 0.5, childXPadding = 4, isHorizontal = true, iconDirection = 1 }
local function Item(want)
    local item = { want = want, shown = want, point = {} }
    function item:IsShown() return self.shown end
    function item:UpdateShownState() self.shown = self.want end
    function item:GetWidth() return 40 end
    function item:GetHeight() return 40 end
    function item:GetPoint() return unpack(self.point) end
    function item:GetNumPoints() return self.point[1] and 1 or 0 end
    function item:ClearAllPoints() self.point = {} end
    function item:SetPoint(...) self.point = { ... } end
    return item
end
local a, b, c = Item(true), Item(false), Item(true)
local order = { a, b, c }
viewer.itemFramePool = { EnumerateActive = function()
    local i = 0
    return function() i = i + 1; return order[i] end
end }
function viewer:OnAcquireItemFrame() end
function viewer:Layout()
    for _, item in ipairs(order) do
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", self, "TOPLEFT", (item.layoutIndex - 1) * 44, 0)
    end
end
function viewer:RefreshLayout()
    for _, item in ipairs(order) do
        item:ClearAllPoints()
        item.layoutIndex = nil
    end
    for i, item in ipairs(order) do
        item.layoutIndex = i
        self:OnAcquireItemFrame(item)
    end
    for _, item in ipairs(order) do item:UpdateShownState() end   -- (RefreshData)
    self:Layout()
end
BuffIconCooldownViewer = viewer

local function at(item, point, x, label)
    assert(item.point[1] == point and math.abs(item.point[4] - x) < 0.001,
        label .. ": " .. tostring(item.point[1]) .. " " .. tostring(item.point[4]))
end
ns.CooldownManager:Init()
viewer:RefreshLayout()
at(a, "TOP", -22, "packed, first")
at(b, "TOPLEFT", 44, "hidden frame left alone")
at(c, "TOP", 22, "packed, second")

-- Blizzard shows a frame without a layout (its settings window opens): packed again
b.want = true
b:UpdateShownState()
at(a, "TOP", -44, "three shown, first")
at(b, "TOP", 0, "three shown, second")
at(c, "TOP", 44, "three shown, third")

-- all shown from the left: Blizzard's own slots, at any Icon Size
grow.buffs = "START"
viewer:RefreshLayout()
at(a, "TOPLEFT", 0, "Left, first")
at(c, "TOPLEFT", 88, "Left, third")

-- a frame whose point cannot be read is not moved: it could not be given back
c.point = { SECRET, viewer, SECRET, SECRET, SECRET }
ns.CooldownManager:Refresh()
assert(c.point[1] == SECRET, "a frame with an unreadable point was moved")

-- Blizzard hands the frames out in another order: the only shown one, packed to the left edge from
-- slot 3, comes back in slot 1. Default then gives it slot 1, not the slot kept from before.
a.want, b.want = false, false
viewer:RefreshLayout()
at(c, "TOPLEFT", 0, "alone, packed left")
order = { c, a, b }
viewer:RefreshLayout()
grow.buffs = "blizzard"
ns.CooldownManager:Refresh()
at(c, "TOPLEFT", 0, "Default after a reshuffle")

-- back on Default: Blizzard's point again, but not over a place Blizzard has given since
grow.buffs = "CENTER"
viewer:RefreshLayout()
at(c, "TOP", 0, "packed again")
c:SetPoint("TOPLEFT", viewer, "TOPLEFT", 100, 0)
grow.buffs = "blizzard"
ns.CooldownManager:Refresh()
at(c, "TOPLEFT", 100, "Blizzard's newer place kept")

-- Essential and Utility: lines of Blizzard's length, each line that isn't full centred
local function line(args, point, x, y)
    local p, gx, gy = ns.CooldownManager.LinePoint(unpack(args))
    assert(p == point and math.abs(gx - x) < 0.001 and math.abs(gy - y) < 0.001, table.concat({ p, gx, gy }, " "))
end
-- five icons, four to a line: the fifth alone in the middle under them
line({ 1, 5, 4, 44, 44, true, false }, "TOP", -66, 0)
line({ 4, 5, 4, 44, 44, true, false }, "TOP", 66, 0)
line({ 5, 5, 4, 44, 44, true, false }, "TOP", 0, -44)
line({ 1, 4, 4, 44, 44, true, true }, "TOP", 66, 0)
-- columns: the next one to the right, centred in height
line({ 5, 6, 4, 44, 50, false, false }, "LEFT", 50, -22)
print("PASS: Cooldown Manager Grow From")
