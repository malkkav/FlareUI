local ADDON_NAME, ns = ...
local S, L = ns.Settings, ns.L

-- A visual companion to the row's explanation. These are ordinary, mouse-free frames with sample
-- data: no unit buttons, saved-variable writes, live-frame reparenting or protected templates.
local P = { renderers = {} }
ns.SettingsPreview = P
local MEDIA = 'Interface\\AddOns\\' .. ADDON_NAME .. '\\Media\\'
P.MEDIA = MEDIA

local routes = {}
local function Route(kind, prefix, keys)
    for key in keys:gmatch('%S+') do routes[prefix .. '.' .. key] = kind end
end
Route('unit', 'uf', 'frameStyle palette fullNames simplePet simpleTargetOf')
Route('unitAuras', 'uf', 'auraShape auraSwipe auraTimer auraTimerColor')
Route('auras', 'au', 'shape swipe timer timerColor arrive')
Route('minimap', 'mm', 'style bag clockStats microMenu coordsHover bagHover')
Route('chat', 'ch', 'opacity border editBoxOpacity editBox lineHeight formatNPC formatPlayer timestamps channelNames raceIcons classIcons linkIcons whisperMarkers nameColon levels social channels menu volume copyButton combatLog minAlpha')
Route('tooltip', 'tt', 'scale anchor healthBar borders classNames showThreat showTarget showGuild showGuildRank hideFaction shortItemStats ids compareShift showWorld showFrames showBars')
Route('tracker', 'qt', 'opacity border zoneHeaders tags wrap count hideLevel focusButtons playButtons minimizeButton colorNames')
Route('meter', 'dm', 'opacity border minAlpha chatTab combatTimer readyCheck countdown threatValue pullLine pullFlash tankLead')
Route('actions', 'ab', 'skinCDM buttonScale')
Route('actionSkin', 'ab', 'flareBorders')
Route('actions', 'ab', 'statusColours procGlow gryphonsBehind hideMacroText hideKeybinds cleanKeybinds buttonArt dimOnCooldown hideGryphons')
Route('xp', 'ab', 'xpBar xpText xpNumbers xpQuest')
Route('frames', 'uf', 'main party raid boss castbar tot tof')
Route('resources', 'rb', 'health power mana combo swingMain swingOff swingRanged')
Route('bags', 'qol', 'bagColumns bagGaps bagButtons bagRarityBorders bagThickBorders bagJunkIcon bagUpgradeArrow petFood bagKeyring bagReagent')
Route('nameplate', 'qol', 'npCombo npQuest npNames npLevel npLevelName npCombat')
Route('reminders', 'au', 'reminders reminderGroup reminderBefore reminderConsumables reminderCamping reminderGathering reminderGlow reminderGlowExpiring')
Route('lootFeed', 'qol', 'lootFeed lootFeedPosition lootFeedQuality lootFeedMoney lootFeedSkills')
Route('mouseRing', 'qol', 'mouseRingShow mouseRingSize mouseRingThickness mouseRingClassColor mouseRingCast mouseRingGCD mouseRingSwing mouseRingRange mouseRingHideTurning')
Route('radial', 'rm', 'scale names')

-- How tall the drawn picture is, from the canvas's top to the lowest thing shown (the panel sizes
-- the picture to it). A sample unit frame's ring and plate hang past the frame itself.
function P.Measure(canvas)
    -- (the height is set while measuring: a picture taller than before still measures from the top)
    local top = canvas.frame:GetTop()
    if not top then return nil end
    local scale = canvas.frame:GetEffectiveScale()
    local bottom = top
    local function visit(region)
        if not (region and region:IsShown()) then return end
        if region.GetText and region:GetObjectType() == 'FontString' and (region:GetText() or '') == '' then return end
        local b = region:GetBottom()
        if b then
            b = b * region:GetEffectiveScale() / scale
            if b < bottom then bottom = b end
        end
    end
    local function walk(c)
        for _, object in pairs(c.objects) do
            local sub = object.FlareUIPreviewCanvas
            if sub and sub ~= c then
                if object:IsShown() then walk(sub) end
            else
                visit(object)
                if object.RingFrame then visit(object.RingFrame) end
                if object.PlateFrame then visit(object.PlateFrame) end
            end
        end
    end
    walk(canvas)
    return math.ceil(top - bottom)
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
    t:SetTextColor(0.9, 0.9, 0.9, 1)
    local cfg = font or {}
    ns.SetFontFamily(t, ns.GetFontPath(cfg.face or 'Friz Quadrata TT'), math.max(8, cfg.size or 11), cfg.flags == 'NONE' and '' or cfg.flags or '')
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
function Canvas:Box(id, x, y, w, h, border, opacity)
    local f = self:Object(id, 'Frame', 'BackdropTemplate')
    f:SetPoint('TOPLEFT', x, -y)
    f:SetSize(w, h)
    local lsm = LibStub('LibSharedMedia-3.0')
    local edge = border and border ~= 'None' and lsm:Fetch('border', border) or nil
    f:SetBackdrop({ bgFile = 'Interface\\DialogFrame\\UI-DialogBox-Background', edgeFile = edge,
        tile = true, tileSize = 16, edgeSize = edge and ns.BorderEdgeSize(edge, 16) or nil,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    f:SetBackdropColor(1, 1, 1, opacity or 0)
    local c = ns.BORDER_COLOR
    f:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
    -- Labels/textures on the canvas must stay above the sample background.
    f:SetFrameLevel(self.frame:GetFrameLevel() + 1)
    return f
end
function Canvas:Bar(id, x, y, w, h, fraction, color, texture)
    local bar = self:Object(id, 'StatusBar')
    bar:SetPoint('TOPLEFT', x, -y)
    bar:SetSize(w, h)
    bar:SetStatusBarTexture(LibStub('LibSharedMedia-3.0'):Fetch('statusbar', texture or 'FlareUI Flat'))
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(fraction)
    bar:SetStatusBarColor(unpack(color))
    bar:SetFrameLevel(self.frame:GetFrameLevel() + 2)
    return bar
end
function P.Create(parent, width, height)
    local f = CreateFrame('Frame', nil, parent)
    f:SetSize(width, height)
    f:EnableMouse(false)
    local canvas = setmetatable({ frame = f, width = width, height = height, objects = {}, owner = parent.FlareUIPreviewCanvas }, Canvas)
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
    canvas.used = nil   -- the height a sample takes (PreviewSamples' Sample and Unit set it)
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
        if not canvas.quiet and P.lastError ~= err then
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
