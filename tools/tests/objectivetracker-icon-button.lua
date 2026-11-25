local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local Widget = getmetatable(env.UIParent)
function Widget:SetDesaturated(on) self.desaturated = on end
function Widget:SetVertexColor(r, g, b) self.vertex = { r, g, b } end
function Widget:SetGradient(axis, bottom, top) self.gradient = { axis, bottom, top } end

env.LibStub = function() return {} end

local applied, painted = {}, {}
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    BronzeIcon = {
        Apply = function(icon, path, color)
            applied[#applied + 1] = { icon = icon, path = path, color = { r = color.r, g = color.g, b = color.b } }
            icon.FlareUI_Light = icon.FlareUI_Light or icon:GetParent():CreateTexture()
        end,
        Paint = function(icon, color, lit)
            painted[#painted + 1] = { icon = icon, color = { r = color.r, g = color.g, b = color.b }, lit = lit }
        end,
    },
    modules = {},
    PALETTE = { bronze4 = { 0.7, 0.4, 0.2 }, bronze5 = { 0.8, 0.6, 0.3 } },
    SoftColor = function(r, g, b) return (r + 0.5) / 2, (g + 0.5) / 2, (b + 0.5) / 2 end,
}
ui:load("Modules/ObjectiveTracker.lua", ns)
local OT = ns.ObjectiveTracker
local Build, C = OT.Build, OT.C
local function check(ok, message) assert(ok, message) end
local function near(a, b) return math.abs(a - b) < 1e-9 end

for name, file in pairs(Build.GLYPHS) do
    local f = io.open("Media/Icons/" .. file .. ".tga", "rb")
    check(f, name .. " has no icon file")
    local head = f:read(18)
    f:close()
    check(head:byte(3) == 2 and head:byte(13) == 24 and head:byte(15) == 24 and head:byte(17) == 32,
        file .. " is not an uncompressed 24 x 24, 32-bit TGA")
end

local flare, blizzard = { frameStyle = "custom" }, { frameStyle = "blizzard" }
OT.ApplyColorScheme(flare)

local fold = Build.IconButton(env.UIParent, 14)
check(fold.icon:GetAtlas() == C.FOLD_COLLAPSE and fold.icon:GetPoint() == "CENTER", "a button with no glyph shows the collapse arrow, centred")
check(near(fold.icon:GetWidth(), 14 * C.FOLD_SCALE) and near(fold.icon:GetHeight(), 14 * C.FOLD_SCALE), "the arrow is scaled by FOLD_SCALE")
fold:SetPlus(true)
check(fold.icon:GetAtlas() == C.FOLD_EXPAND, "SetPlus(true) shows the expand arrow")
fold:SetPlus(false)
check(fold.icon:GetAtlas() == C.FOLD_COLLAPSE, "SetPlus(false) goes back to the collapse arrow")
fold:Paint(false)
check(#applied == 0 and #painted == 0, "an arrow is never painted in bronze")
-- (11-23, Malkkav) FlareUI scheme: the arrow greyed and tinted to the header's light bronze
check(fold.icon.desaturated == true and fold.icon.vertex[1] == 0.8 and fold.icon.vertex[3] == 0.3, "FlareUI: a bronze arrow")
OT.ApplyColorScheme(blizzard)
fold:Paint(false)
check(fold.icon.desaturated == false and fold.icon.vertex[1] == 1, "Blizzard: its own gold arrow")
OT.ApplyColorScheme(flare)

local b = Build.IconButton(env.UIParent, 14)
b.glyph = Build.GLYPHS.exclaim
b:Layout()
check(#applied == 1 and applied[1].path == C.ICON_PATH .. "QTExclaim.tga", "a glyph is applied through BronzeIcon from its file")
check(applied[1].color.r == C.BOX_COLOR[1] and applied[1].color.g == C.BOX_COLOR[2] and applied[1].color.b == C.BOX_COLOR[3],
    "at rest: the box bronze")
check(b.icon.allPoints == b, "a glyph fills its button")
check(painted[#painted].lit == nil and b.icon.FlareUI_Light:IsShown() == true, "at rest: bronze, with its light edge")

b:Layout()
check(#applied == 1, "the same file is not applied twice")

b:RunScript("OnEnter")
check(painted[#painted].lit == true, "pointing at it lights it")
b:RunScript("OnLeave")
check(painted[#painted].lit == false, "leaving it puts it back")

local paints = #painted
b.active = true
b:Paint(false)
local gradient = b.icon.gradient
check(#painted == paints, "a switched-on glyph is not painted in bronze")
check(gradient and gradient[2].r == gradient[3].r and gradient[2].r == 0.8 and gradient[2].g == 0.6 and gradient[2].b == 0.3,
    "a switched-on glyph is plain, in the scheme header colour")
check(b.icon.FlareUI_Light:IsShown() == false, "a switched-on glyph has no light edge")

b.active = nil
b:Paint(false)
check(#painted == paints + 1 and b.icon.FlareUI_Light:IsShown() == true, "switched off: bronze again, with its light edge")

-- Blizzard scheme: Blizzard's header gold (C.HEADING holds it then), dimmer at rest
OT.ApplyColorScheme(blizzard)
b:Paint(false)
local rest = painted[#painted].color
check(near(rest.r, 0.75) and near(rest.g, 0.615) and rest.b == 0, "Blizzard: dim gold at rest")
b.active = true
b:Paint(false)
check(b.icon.gradient[2].r == 1 and b.icon.gradient[2].g == 0.82, "Blizzard: a switch that is on in full gold")

print("PASS: quest tracker icon buttons")
