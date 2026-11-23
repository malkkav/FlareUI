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
local C = {
    BOX_COLOR = { 0.50, 0.38, 0.21 },
    ICON_PATH = 'Icons\\',
    FOLD_SCALE = 2,
    FOLD_EXPAND = 'expand',
    FOLD_COLLAPSE = 'collapse',
}
local OT = { blizzColors = { HEADING = { 1, 0.82, 0 } } }
local Build = {}
]] .. H.section(source, 'Build.GLYPHS = {', '-- Auto Quest Buttons: with the switch on') .. [[
return { Build = Build, C = C, applied = applied, painted = painted }
]])

local Build, C, applied, painted = T.Build, T.C, T.applied, T.painted
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
fold:Paint(true)
check(#applied == 0 and #painted == 0, 'an arrow is never painted in bronze')

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
check(gradient and gradient[2] == gradient[3] and gradient[2].r == 1 and gradient[2].g == 0.82 and gradient[2].b == 0,
    'a switched-on glyph is plain gold')
check(b.icon.FlareUI_Light.shown == false, 'a switched-on glyph has no light edge')

b.active = nil
b:Paint(false)
check(#painted == paints + 1 and b.icon.FlareUI_Light.shown == true, 'switched off: bronze again, with its light edge')

print('PASS: quest tracker icon buttons')
