local ADDON_NAME, ns = ...
local S, L = ns.Settings, ns.L

-- A visual companion to the row's explanation. These are ordinary, mouse-free frames with sample
-- data: no unit buttons, saved-variable writes, live-frame reparenting or protected templates.
local P = { renderers = {} }
ns.SettingsPreview = P
local MEDIA = 'Interface\\AddOns\\' .. ADDON_NAME .. '\\Media\\'
P.MEDIA = MEDIA

-- 11-10 batch E: every picture is a wireframe in the mock-up's look, so they all read as one set:
-- 1 px bronze lines over a faint gold wash; a state is a tinted fill with its line in the same
-- colour. Real fonts stay where the option is about a font; no game art is drawn.
local WHITE = 'Interface\\Buttons\\WHITE8X8'
local CIRCLE = MEDIA .. 'Panel\\Circle.tga'
local HOLE = MEDIA .. 'Masks\\RingHole.tga'
local HOLE_SHARE = 0.93          -- the hole's diameter, of RingHole.tga's width (as MouseRing.lua)
local WF = {
    line = { 0.54, 0.42, 0.24 },  -- resting line (#8a6a3e)
    lit = { 1, 0.84, 0.5 },       -- selected, glowing
    wash = { 0.79, 0.65, 0.35 },  -- the faint fill under a plain shape
    washA = 0.06, tintA = 0.35,
    dark = { 0.059, 0.047, 0.031 },
    text = { 0.88, 0.82, 0.70 }, dim = { 0.64, 0.58, 0.48 },
    gold = { 0.91, 0.77, 0.42 }, red = { 0.82, 0.28, 0.23 }, blue = { 0.31, 0.5, 0.88 },
    grey = { 0.55, 0.55, 0.55 }, green = { 0.38, 0.72, 0.36 }, purple = { 0.64, 0.33, 0.93 },
    orange = { 0.95, 0.55, 0.2 }, mage = { 0.41, 0.8, 0.94 },
}
P.WF, P.WHITE, P.CIRCLE = WF, WHITE, CIRCLE

local routes = {}
local function Route(kind, prefix, keys)
    for key in keys:gmatch('%S+') do routes[prefix .. '.' .. key] = kind end
end
Route('unit', 'uf', 'frameStyle palette fullNames simplePet simpleTargetOf')
Route('unitAuras', 'uf', 'auraShape auraSwipe auraTimer auraTimerColor')
Route('auras', 'ab', 'skinCDM')
Route('auras', 'au', 'shape swipe timer timerColor arrive')
Route('minimap', 'mm', 'style bag clockStats microMenu coordsHover bagHover')
Route('chat', 'ch', 'opacity border editBoxOpacity editBox lineHeight formatNPC formatPlayer timestamps channelNames raceIcons classIcons linkIcons whisperMarkers nameColon levels social channels menu volume copyButton combatLog minAlpha')
Route('tooltip', 'tt', 'scale anchor healthBar borders classNames showThreat showTarget showGuild showGuildRank hideFaction shortItemStats ids compareShift showWorld showFrames showBars')
Route('tracker', 'qt', 'opacity border zoneHeaders tags wrap count hideLevel focusButtons playButtons minimizeButton colorNames')
Route('meter', 'dm', 'opacity border minAlpha chatTab combatTimer readyCheck countdown threatValue pullLine pullFlash tankLead')
Route('actions', 'ab', 'statusColours procGlow gryphonsBehind hideMacroText hideKeybinds cleanKeybinds buttonArt dimOnCooldown hideGryphons')
Route('actions', 'ab', 'xpBar xpText xpNumbers xpQuest')
Route('frames', 'uf', 'main party raid boss castbar tot tof')
Route('resources', 'rb', 'health power mana combo swingMain swingOff swingRanged')
Route('bags', 'qol', 'bagColumns bagGaps bagButtons bagRarityBorders bagThickBorders bagJunkIcon bagUpgradeArrow petFood bagKeyring bagReagent')
Route('nameplate', 'qol', 'npCombo npQuest npNames npLevel npLevelName npCombat')
Route('reminders', 'au', 'reminders reminderGroup reminderBefore reminderConsumables reminderCamping reminderGathering reminderGlow reminderGlowExpiring')
Route('lootFeed', 'qol', 'lootFeed lootFeedPosition lootFeedQuality lootFeedMoney')
Route('mouseRing', 'qol', 'mouseRingShow mouseRingSize mouseRingThickness mouseRingClassColor mouseRingCast mouseRingGCD mouseRingSwing mouseRingRange mouseRingHideTurning')
Route('radial', 'rm', 'scale names')

-- Only the named visual toggle groups demonstrate the opposite state on hover.
function P.HoverValue(row)
    local kind = routes[row.key]
    if row.kind == 'toggle' and (kind == 'tooltip' or kind == 'bags' or kind == 'nameplate') then
        return not row:Get()
    end
end
function P.Resolve(row, value)
    if not row then return nil end
    local kind = row.previewFont and 'font' or routes[row.key]
    if not kind then return nil end
    if value == nil then value = row:Get() end
    return { kind = kind, key = row.key, value = value, path = row.path, font = row.previewFont, temporary = row.kind == 'toggle' and value ~= row:Get() }
end

local defaults = { uf = 'unit', mm = 'minimap', ch = 'chat', tt = 'tooltip', qt = 'tracker',
    dm = 'meter', ab = 'actions', rb = 'resources', au = 'auras', rm = 'radial' }
function P.Module(module)
    local kind = defaults[module]
    return kind and { kind = kind, key = module .. '.overview' } or nil
end

-- Cached by the owning canvas, so moving between controls never leaks anonymous WoW frames.
local Canvas = {}
Canvas.__index = Canvas
function Canvas:StopAnimations()
    self.frame:SetScript('OnUpdate', nil)
    for _, object in pairs(self.objects) do
        if object.FlareUIPreviewCanvas then object.FlareUIPreviewCanvas:StopAnimations() end
        if object.ProcStartAnim then object.ProcStartAnim:Stop() end
        if object.ProcLoop then object.ProcLoop:Stop() end
    end
end
function Canvas:Animate(callback)
    self.frame:SetScript('OnUpdate', function(frame, elapsed)
        if not P.paused then callback(frame, elapsed) end
    end)
end
function Canvas:SetMotionPaused(paused)
    for _, object in pairs(self.objects) do
        if object.FlareUIPreviewCanvas then object.FlareUIPreviewCanvas:SetMotionPaused(paused) end
        local cd = object.FlareUI_Cooldown
        if cd then
            if paused and cd.Pause then cd:Pause()
            elseif not paused and cd.Resume then cd:Resume() end
        end
        if paused and object.ProcStartAnim then object.ProcStartAnim:Stop() end
        if paused and object.ProcLoop then object.ProcLoop:Stop() end
    end
end
function Canvas:Reset()
    self:StopAnimations()
    for _, object in pairs(self.objects) do object:Hide() end
end
function Canvas:Invalidate()
    self.invalidated = true
    if self.owner then self.owner:Invalidate() end
end
function Canvas:Object(id, kind, template)
    local object = self.objects[id]
    if not object then
        if kind == 'Texture' then object = self.frame:CreateTexture(nil, 'ARTWORK')
        elseif kind == 'OverlayTexture' then object = self.overlay:CreateTexture(nil, 'OVERLAY')
        elseif kind == 'FontString' then object = self.overlay:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
        else object = CreateFrame(kind or 'Frame', nil, self.frame, template) end
        self.objects[id] = object
    end
    object:ClearAllPoints()
    object:SetAlpha(1)
    object:Show()
    return object
end
function Canvas:Text(id, text, x, y, width, font)
    local t = self:Object(id, 'FontString')
    t:SetPoint('TOPLEFT', x, -y)
    t:SetWidth(width or self.width - x - 8)
    t:SetJustifyH('LEFT')
    t:SetWordWrap(true)
    t:SetMaxLines(0)
    t:SetTextColor(WF.text[1], WF.text[2], WF.text[3], 1)
    -- the panel's own text face unless the picture is showing a font setting
    local cfg = font or {}
    ns.SetFontFamily(t, ns.GetFontPath(cfg.face or 'Roboto Condensed'), math.max(8, cfg.size or 11), cfg.flags == 'NONE' and '' or cfg.flags or '')
    ns.ApplyShadow(t, cfg)
    t:SetText(text)
    return t
end
function Canvas:Texture(id, path, x, y, w, h, overlay)
    local t = self:Object(id, overlay and 'OverlayTexture' or 'Texture')
    t:SetPoint('TOPLEFT', x, -y)
    t:SetSize(w, h)
    t:SetTexture(path)
    t:SetTexCoord(0, 1, 0, 1)
    t:SetVertexColor(1, 1, 1, 1)
    t:SetDesaturated(false)
    return t
end
-- WIREFRAME KIT. x, y from the canvas's top left; z is the frame level over the canvas (text is always
-- on top). A line stays 1 screen pixel on a scaled canvas (canvas.scale).
function Canvas:Frame(id, x, y, w, h, tint, opts)
    opts = opts or {}
    id = 'F:' .. id
    local f = self.objects[id]
    if not f then
        f = CreateFrame('Frame', nil, self.frame)
        f.fill = f:CreateTexture(nil, 'BACKGROUND')
        f.fill:SetAllPoints()
        f.edges = {}
        for i = 1, 4 do f.edges[i] = f:CreateTexture(nil, 'BORDER') end
        f.edges[1]:SetPoint('TOPLEFT'); f.edges[1]:SetPoint('TOPRIGHT')
        f.edges[2]:SetPoint('BOTTOMLEFT'); f.edges[2]:SetPoint('BOTTOMRIGHT')
        f.edges[3]:SetPoint('TOPLEFT'); f.edges[3]:SetPoint('BOTTOMLEFT')
        f.edges[4]:SetPoint('TOPRIGHT'); f.edges[4]:SetPoint('BOTTOMRIGHT')
        self.objects[id] = f
    end
    f:ClearAllPoints()
    f:SetPoint('TOPLEFT', x, -y)
    f:SetSize(math.max(1, w), math.max(1, h))
    f:SetAlpha(1)
    f:Show()
    f:SetFrameLevel(self.frame:GetFrameLevel() + (opts.z or 2))
    if f.bar then f.bar:Hide() end
    local line = opts.line or tint or WF.line
    local thick = (opts.thick or 1) / (self.scale or 1)
    for i, e in ipairs(f.edges) do
        e:SetColorTexture(line[1], line[2], line[3], opts.lineAlpha or 1)
        if i <= 2 then e:SetHeight(thick) else e:SetWidth(thick) end
        e:SetShown(not opts.noLine)
    end
    local fill = opts.fill or tint or WF.wash
    f.fill:SetColorTexture(fill[1], fill[2], fill[3], opts.fillAlpha or (tint and WF.tintA or WF.washA))
    f.fill:SetShown(not opts.noFill)
    return f
end
-- a solid block (no line)
function Canvas:Fill(id, x, y, w, h, color, alpha, z)
    return self:Frame(id, x, y, w, h, color, { noLine = true, fillAlpha = alpha or 1, z = z })
end
-- a stand-in for text the option does not change
function Canvas:Line(id, x, y, w, h)
    return self:Fill(id, x, y, w, h or 4, WF.dim, 0.4)
end
-- a box with an option's border and opacity (chat, tracker, meter): opacity darkens the fill,
-- None drops the line, Thick doubles it
function Canvas:Box(id, x, y, w, h, border, opacity)
    return self:Frame(id, x, y, w, h, nil, { fill = { 0, 0, 0 }, fillAlpha = math.max(WF.washA, (opacity or 0) * 0.8),
        noLine = border == 'None', thick = border and border:find('Thick') and 2 or 1 })
end
-- a bar: its line and fill in the bar's colour; f:SetFraction(v) moves it
local function SetFraction(f, v)
    f.bar:SetWidth(math.max(0.01, (f.innerWidth or 1) * math.max(0, math.min(1, v))))
    f.bar:SetShown(v > 0)
end
function Canvas:Bar(id, x, y, w, h, fraction, color, opts)
    opts = opts or {}
    local f = self:Frame(id, x, y, w, h, color, { fillAlpha = 0.08, z = opts.z, noLine = opts.noLine, line = opts.line })
    if not f.bar then
        f.bar = f:CreateTexture(nil, 'ARTWORK')
        f.SetFraction = SetFraction
    end
    local inset = opts.noLine and 0 or 1 / (self.scale or 1)
    f.bar:ClearAllPoints()
    f.bar:SetPoint('TOPLEFT', inset, -inset)
    f.bar:SetPoint('BOTTOMLEFT', inset, inset)
    f.bar:SetColorTexture(color[1], color[2], color[3], opts.alpha or 0.6)
    f.innerWidth = math.max(1, w - 2 * inset)
    f:SetFraction(fraction)
    return f
end
-- a filled circle (x, y its top left)
function Canvas:Disc(id, x, y, d, color, alpha, z)
    id = 'D:' .. id
    local f = self.objects[id]
    if not f then
        f = CreateFrame('Frame', nil, self.frame)
        f.tex = f:CreateTexture(nil, 'ARTWORK')
        f.tex:SetAllPoints()
        f.tex:SetTexture(CIRCLE)
        self.objects[id] = f
    end
    f:ClearAllPoints(); f:SetPoint('TOPLEFT', x, -y); f:SetSize(math.max(1, d), math.max(1, d))
    f:SetAlpha(1); f:Show()
    f:SetFrameLevel(self.frame:GetFrameLevel() + (z or 2))
    color = color or WF.wash
    f.tex:SetVertexColor(color[1], color[2], color[3], alpha or 1)
    return f
end
-- a circle's line: a disc with a round hole (the Mouse Ring's way)
function Canvas:Ring(id, x, y, d, thickness, color, z)
    id = 'R:' .. id
    local f = self.objects[id]
    if not f then
        f = CreateFrame('Frame', nil, self.frame)
        f.tex = f:CreateTexture(nil, 'ARTWORK')
        f.tex:SetAllPoints()
        f.tex:SetTexture(CIRCLE)
        f.hole = f:CreateMaskTexture()
        f.hole:SetTexture(HOLE, 'CLAMPTOWHITE', 'CLAMPTOWHITE')
        f.hole:SetPoint('CENTER')
        f.tex:AddMaskTexture(f.hole)
        self.objects[id] = f
    end
    f:ClearAllPoints(); f:SetPoint('TOPLEFT', x, -y); f:SetSize(math.max(1, d), math.max(1, d))
    f:SetAlpha(1); f:Show()
    f:SetFrameLevel(self.frame:GetFrameLevel() + (z or 3))
    local inner = math.max(1, d - 2 * (thickness or 1) / (self.scale or 1)) / HOLE_SHARE
    f.hole:SetSize(inner, inner)
    color = color or WF.line
    f.tex:SetVertexColor(color[1], color[2], color[3], 1)
    return f
end
-- an icon's place: a tinted square, or a tinted circle with its line
function Canvas:Icon(id, x, y, size, tint, round, z)
    tint = tint or WF.wash
    if round then
        self:Disc(id .. 'Fill', x, y, size, tint, tint == WF.wash and 0.12 or WF.tintA, z)
        return self:Ring(id, x, y, size, 1, tint == WF.wash and WF.line or tint, (z or 2) + 1)
    end
    return self:Frame(id, x, y, size, size, tint ~= WF.wash and tint or nil, { z = z, fillAlpha = tint == WF.wash and 0.12 or nil })
end
-- one of the panel's glyphs (Media/Panel), tinted; rotation in radians
function Canvas:Glyph(id, name, x, y, w, h, color, z, rotation)
    id = 'G:' .. id
    local f = self.objects[id]
    if not f then
        f = CreateFrame('Frame', nil, self.frame)
        f.tex = f:CreateTexture(nil, 'ARTWORK')
        f.tex:SetAllPoints()
        self.objects[id] = f
    end
    f:ClearAllPoints(); f:SetPoint('TOPLEFT', x, -y); f:SetSize(w, h)
    f:SetAlpha(1); f:Show()
    f:SetFrameLevel(self.frame:GetFrameLevel() + (z or 8))
    f.tex:SetTexture(MEDIA .. 'Panel\\' .. name .. '.tga')
    f.tex:SetRotation(rotation or 0)
    color = color or WF.text
    f.tex:SetVertexColor(color[1], color[2], color[3], 1)
    return f
end
-- a sweep over a shape (Blizzard's cooldown frame with a plain swipe); reverse lights what is left
function Canvas:Sweep(id, x, y, size, round, color, reverse, z)
    id = 'S:' .. id
    local cd = self.objects[id]
    if not cd then
        cd = CreateFrame('Cooldown', nil, self.frame, 'CooldownFrameTemplate')
        cd.FlareUI_Cooldown = cd
        if cd.SetDrawEdge then cd:SetDrawEdge(false) end
        if cd.SetDrawBling then cd:SetDrawBling(false) end
        if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
        self.objects[id] = cd
    end
    cd:ClearAllPoints(); cd:SetPoint('TOPLEFT', x, -y); cd:SetSize(size, size)
    cd:SetAlpha(1); cd:Show()
    cd:SetFrameLevel(self.frame:GetFrameLevel() + (z or 6))
    if cd.SetSwipeTexture then cd:SetSwipeTexture(round and CIRCLE or WHITE) end
    if cd.SetSwipeColor then cd:SetSwipeColor(color[1], color[2], color[3], color[4] or 0.7) end
    if cd.SetReverse then cd:SetReverse(reverse and true or false) end
    return cd
end
function P.Create(parent, width, height)
    local f = CreateFrame('Frame', nil, parent)
    f:SetSize(width, height)
    f:EnableMouse(false)
    local canvas = setmetatable({ frame = f, width = width, height = height, objects = {}, owner = parent.FlareUIPreviewCanvas, scale = 1 }, Canvas)
    f.FlareUIPreviewCanvas = canvas
    canvas.overlay = CreateFrame('Frame', nil, f)
    canvas.overlay:SetAllPoints()
    canvas.overlay:SetFrameLevel(f:GetFrameLevel() + 20)
    -- OnHide can be inherited from layout/ancestor visibility changes. Clearing the
    -- objects here destroys a cached composition after it has just been rendered.
    f:SetScript('OnHide', function()
        canvas:StopAnimations()
        canvas:Invalidate()
    end)
    return canvas
end
function P.Show(canvas, spec)
    canvas:Reset()
    canvas.frame:SetAlpha(1)
    local draw = spec and P.renderers[spec.kind]
    if not draw then canvas.frame:Hide() return false end
    canvas.frame:Show()
    local previous = P.activeSpec
    P.activeSpec = spec
    local ok, err = pcall(draw, canvas, spec)
    P.activeSpec = previous
    canvas.invalidated = false
    if not ok then
        -- A specimen must never abort Panel:Refresh after its controls were released.
        canvas:Reset()
        canvas.frame:Hide()
        if P.lastError ~= err then
            P.lastError = err
            if geterrorhandler then pcall(geterrorhandler(), err) end
        end
        return false
    end
    if spec.temporary then
        canvas:Text('previewChange', L["Preview only — click to apply"], 8, canvas.height - 14, canvas.width - 16, { size = 9 })
    end
    canvas:SetMotionPaused(P.paused)
    return true
end

-- Source-rendered specimens are shared between cards and the large Info Panel.
function P.Style(canvas, row, value)
    return P.Show(canvas, P.Resolve(row, value))
end
