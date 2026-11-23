local H = dofile('tools/tests/perf-helpers.lua')
local source = H.read('Modules/ObjectiveTracker.lua')

local T = H.load([[
local applied, painted = {}, {}
local function Texture()
    local t = { points = {} }
    function t:ClearAllPoints() self.points = {} end
    function t:SetAllPoints() self.points = { 'ALL' } end
    function t:SetPoint(point) self.points = { point } end
    function t:SetSize(w, h) self.w, self.h = w, h end
    function t:SetAtlas(atlas) self.atlas = atlas end
    function t:SetGradient(axis, bottom, top) self.gradient = { axis, bottom, top } end
    function t:SetShown(shown) self.shown = shown end
    function t:SetDesaturated(on) self.desaturated = on end
    function t:SetVertexColor(r, g, b) self.vertex = { r, g, b } end
    return t
end
local function CreateFrame()
    local f = { scripts = {} }
    function f:SetSize(w, h) self.w, self.h = w, h end
    function f:CreateTexture() return Texture() end
    function f:HookScript(name, fn) self.scripts[name] = fn end
    return f
end
local function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
local ns = { BronzeIcon = {} }
function ns.BronzeIcon.Apply(icon, path, color)
    applied[#applied + 1] = { icon = icon, path = path, color = color }
    icon.FlareUI_Light = icon.FlareUI_Light or Texture()
end
function ns.BronzeIcon.Paint(icon, color, lit)
    painted[#painted + 1] = { icon = icon, color = color, lit = lit }
end
local math_min = math.min
local C = {
    BOX_COLOR = { 0.50, 0.38, 0.21 },
    HEADING = { 0.8, 0.6, 0.3 },   -- (the scheme's header colour: FlareUI's light bronze here)
    ICON_PATH = 'Icons\\',
    FOLD_SCALE = 2,
    FOLD_EXPAND = 'expand',
    FOLD_COLLAPSE = 'collapse',
}
local OT = { blizzColors = { HEADING = { 1, 0.82, 0 } } }
local Build = {}
]] .. H.section(source, 'Build.GLYPHS = {', '-- Auto Quest Buttons: with the switch on') .. [[
return { Build = Build, C = C, OT = OT, applied = applied, painted = painted }
]])

local Build, C, OT, applied, painted = T.Build, T.C, T.OT, T.applied, T.painted
local function check(ok, message) assert(ok, message) end

for name, file in pairs(Build.GLYPHS) do
    local f = io.open('Media/Icons/' .. file .. '.tga', 'rb')
    check(f, name .. ' has no icon file')
    local head = f:read(18)
    f:close()
    check(head:byte(3) == 2 and head:byte(13) == 24 and head:byte(15) == 24 and head:byte(17) == 32,
        file .. ' is not an uncompressed 24 x 24, 32-bit TGA')
end

local fold = Build.IconButton({}, 14)
check(fold.icon.atlas == 'collapse' and fold.icon.points[1] == 'CENTER', 'a button with no glyph shows the collapse arrow, centred')
check(fold.icon.w == 28 and fold.icon.h == 28, 'the arrow is scaled by FOLD_SCALE')
fold:SetPlus(true)
check(fold.icon.atlas == 'expand', 'SetPlus(true) shows the expand arrow')
fold:SetPlus(false)
check(fold.icon.atlas == 'collapse', 'SetPlus(false) goes back to the collapse arrow')
fold:Paint(false)
check(#applied == 0 and #painted == 0, 'an arrow is never painted in bronze')
-- (11-23, Malkkav) FlareUI scheme: the arrow greyed and tinted to the header's light bronze
check(fold.icon.desaturated == true and fold.icon.vertex[1] == 0.8 and fold.icon.vertex[3] == 0.3, 'FlareUI: a bronze arrow')
OT.soft = false
fold:Paint(false)
check(fold.icon.desaturated == false and fold.icon.vertex[1] == 1, 'Blizzard: its own gold arrow')
OT.soft = nil

local b = Build.IconButton({}, 14)
b.glyph = Build.GLYPHS.exclaim
b:Layout()
check(#applied == 1 and applied[1].path == 'Icons\\QTExclaim.tga', 'a glyph is applied through BronzeIcon from its file')
check(applied[1].color.r == 0.50 and applied[1].color.g == 0.38 and applied[1].color.b == 0.21, 'at rest: the box bronze')
check(b.icon.points[1] == 'ALL', 'a glyph fills its button')
check(painted[#painted].lit == nil and b.icon.FlareUI_Light.shown == true, 'at rest: bronze, with its light edge')

b:Layout()
check(#applied == 1, 'the same file is not applied twice')

b.scripts.OnEnter(b)
check(painted[#painted].lit == true, 'pointing at it lights it')
b.scripts.OnLeave(b)
check(painted[#painted].lit == false, 'leaving it puts it back')

local paints = #painted
b.active = true
b:Paint(false)
local gradient = b.icon.gradient
check(#painted == paints, 'a switched-on glyph is not painted in bronze')
check(gradient and gradient[2].r == gradient[3].r and gradient[2].r == 0.8 and gradient[2].g == 0.6 and gradient[2].b == 0.3,
    'a switched-on glyph is plain, in the scheme header colour')
check(b.icon.FlareUI_Light.shown == false, 'a switched-on glyph has no light edge')

b.active = nil
b:Paint(false)
check(#painted == paints + 1 and b.icon.FlareUI_Light.shown == true, 'switched off: bronze again, with its light edge')

-- Blizzard scheme: Blizzard's header gold (C.HEADING holds it then), dimmer at rest
C.HEADING[1], C.HEADING[2], C.HEADING[3] = 1, 0.82, 0
OT.soft = false
b:Paint(false)
local rest = painted[#painted].color
check(math.abs(rest.r - 0.75) < 1e-9 and math.abs(rest.g - 0.615) < 1e-9 and rest.b == 0, 'Blizzard: dim gold at rest')
b.active = true
b:Paint(false)
check(b.icon.gradient[2].r == 1 and b.icon.gradient[2].g == 0.82, 'Blizzard: a switch that is on in full gold')

print('PASS: quest tracker icon buttons')
