local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local db = {
    enabled = true, units = { player = { enabled = true } },
    totems = { size = 110, perRow = 2, swipe = "border", timer = "below" },
}
local ns = {
    modules = {}, L = setmetatable({}, { __index = function(_, key) return key end }),
    db = { profile = { unitframes = db } },
    LayoutHome = function(layouts, name) layouts[name] = layouts[name] or {}; return layouts[name] end,
    EditPreviewing = function() return ui.editing and not ui.combat end,
    OnEditFight = function(callback) ui.editFight = callback end,
    EditSection = function(section, rows) assert(section == "Frame"); return rows end,
    UnitFrames = { Font = function() return { face = "Timer", size = 0, flags = "NONE" } end },
    SetFont = function(widget, ...) widget:SetFont(...) end,
    GetFontPath = function(face) return "Fonts/" .. face end,
    ApplyShadow = function() end,
}
local edit = { SettingType = { Slider = 1 } }
function edit:GetActiveLayoutName() return "Modern" end
function edit:Defer() return false end
function edit:IsInEditMode() return ui.editing end
function edit:AddFrame(holder, moved) holder.moved = moved end
function edit:AddFrameSettings(holder, rows) holder.settings = rows end
function edit:RegisterCallback(event, callback) self[event] = callback end
env.LibStub = function(name) assert(name == "FlareEditMode"); return edit end
local Widget = getmetatable(env.UIParent)
function Widget:SetUseCircularEdge(value) self.circular = value end
function Widget:SetDrawSwipe(value) self.drawSwipe = value end
function Widget:SetDrawEdge(value) self.drawEdge = value end
function Widget:SetSwipeTexture(value) self.swipeTexture = value end
function Widget:SetEdgeTexture(value) self.edgeTexture = value end
function Widget:SetReverse(value) self.reverse = value end
Widget.RemoveMaskTexture = Widget.RemoveMaskTexture or function() end

local parent = env.CreateFrame("Frame", "PlayerFrame", env.UIParent)
local gameTotems = env.CreateFrame("Frame", "TotemFrame", parent)
function gameTotems:Layout() end
local all = {}
for i, layoutIndex in ipairs({ 3, 1, 2, 4 }) do
    local button = env.CreateFrame("Button", nil, gameTotems)
    button.Icon, button.Border = button:CreateTexture(), button:CreateTexture()
    button.Icon.Cooldown = env.CreateFrame("Cooldown", nil, button)
    button.Duration = button:CreateFontString()
    button.layoutIndex = layoutIndex
    all[i] = button
end
gameTotems.totemPool = { EnumerateActive = function()
    local index = 0
    return function() index = index + 1; return all[index] end
end }
all[4]:Hide()

ui:load("Modules/Totems.lua", ns)
db.units.player.enabled = false
assert(not ns.Totems:ShouldLoad())
db.units.player.enabled = true
assert(ns.Totems:ShouldLoad())
ns.Totems:Init()
local holder = env.FlareUI_Totems
assert(holder and gameTotems:GetParent() == holder and gameTotems:GetScale() == 1.1)
assert(select(4, all[2]:GetPoint()) == 0 and select(4, all[3]:GetPoint()) == 31)
assert(select(5, all[1]:GetPoint()) == -42 and all[4]:GetNumPoints() == 0)
local cooldown, duration = all[1].Icon.Cooldown, all[1].Duration
assert(select(2, cooldown:GetPoint()) == all[1].Border and cooldown:GetWidth() == 30)
assert(cooldown.drawSwipe and not cooldown.drawEdge and duration:GetParent() == all[1].FlareUI_TextLayer)
local font, size, flags = duration:GetFont()
assert(font == "Fonts/Timer" and size == 10 and flags == "")
gameTotems:SetParent(parent)
gameTotems:SetPoint("BOTTOM", parent, "BOTTOM", 10, 20)
assert(gameTotems:GetParent() == holder and gameTotems:GetPoint() == "TOPLEFT")

holder.settings[2].set(nil, 3)
db.totems.timer, db.totems.swipe = "middle", "icon"
gameTotems:Layout()
assert(select(4, all[1]:GetPoint()) == 62 and select(5, all[1]:GetPoint()) == 0)
assert(cooldown:GetWidth() == 22 and select(2, cooldown:GetPoint()) == all[1] and cooldown.drawEdge)
assert(duration:GetPoint() == "CENTER")
db.totems.timer, db.totems.swipe = "none", "none"
ns.Totems.ApplyLayout()
-- (the layer is hidden: Blizzard colours the text every frame, which shows the text itself again)
duration:SetAlpha(1)
assert(duration:GetEffectiveAlpha() == 0 and not cooldown.drawSwipe)
assert(not holder.preview:IsShown())
ns.Totems.SetFaded(true)
assert(not all[1]:IsMouseEnabled())
ns.Totems.SetFaded(false)
assert(all[1]:IsMouseEnabled())

-- (11-25) Aura Icon Shape: Square swaps the round mask and the ring for the square border, and back
do
    local button = all[1]
    local frame = env.CreateFrame("Frame", nil, button)
    frame.Cooldown = cooldown
    frame.Texture, frame.TextureMask = frame:CreateTexture(), frame:CreateMaskTexture()
    local masks = { [frame.TextureMask] = true }
    function frame.Texture:AddMaskTexture(m) masks[m] = true end
    function frame.Texture:RemoveMaskTexture(m) masks[m] = nil end
    local old = button.Icon
    button.Icon = frame
    frame:SetSize(22, 22)
    ns.Totems.ApplyLayout()
    assert(not button.FlareUI_Square and masks[frame.TextureMask], "Round to start: Blizzard's button untouched")
    db.totems.shape, db.totems.swipe, db.totems.timer = "square", "both", "bottom"
    ns.Totems.ApplyLayout()
    local p = button.FlareUI_Square
    assert(p.border:IsShown() and button.Border:GetAlpha() == 0 and masks[p.mask] and not masks[frame.TextureMask])
    assert(p.border:GetTexture():find("IconBorder", 1, true) and frame:GetWidth() > 22 and frame:GetWidth() < p.border:GetWidth())
    assert(cooldown:GetWidth() == p.border:GetWidth() and cooldown.circular == false and cooldown.swipeTexture:find("IconMask", 1, true))
    assert(select(2, duration:GetPoint()) == p.border)
    db.totems.swipe = "icon"
    ns.Totems.ApplyLayout()
    assert(cooldown:GetWidth() == frame:GetWidth() and cooldown.drawEdge)
    db.totems.swipe = "border"
    ns.Totems.ApplyLayout()
    assert(cooldown.swipeTexture:find("BorderThick", 1, true) and not cooldown.drawEdge and cooldown.drawSwipe)
    db.totems.swipe = "none"
    ns.Totems.ApplyLayout()
    assert(not cooldown.drawSwipe and not cooldown.drawEdge)
    db.totems.shape, db.totems.swipe = nil, "both"
    ns.Totems.ApplyLayout()
    assert(not p.border:IsShown() and button.Border:GetAlpha() == 1 and masks[frame.TextureMask] and not masks[p.mask])
    assert(frame:GetWidth() == 22 and cooldown.circular == true)
    button.Icon = old
    db.totems.swipe, db.totems.timer = "none", "none"
    ns.Totems.ApplyLayout()
end

ui.editing = true
edit.enter()
assert(holder.preview:IsShown() and #holder.preview.buttons == 4 and gameTotems:GetAlpha() == 0)
assert(not all[1]:IsMouseEnabled() and holder.preview.buttons[3].Duration:GetText() == "4:10")
ui.combat = true
ui.editFight()
assert(not holder.preview:IsShown() and gameTotems:GetAlpha() == 1 and all[1]:IsMouseEnabled())
ui.editing, ui.combat = false, false
edit.exit()
holder.moved(holder, "Modern", "RIGHT", -11.5, 14.7)
edit.layout("Modern")
assert(holder:GetPoint() == "RIGHT" and select(5, holder:GetPoint()) == 15)
print("PASS: totems keep Blizzard's buttons, layout and clicks in sync with their settings and preview")
