-- Run from the repository root: luajit tools/tests/settings-previews.lua
local ns = { L = setmetatable({}, { __index = function(_, k) return k end }) }
local values = { ['unitframes.palette'] = 'flareui' }
ns.Settings = { GetPath = function(_, key) return values[key] end }
assert(loadfile('Settings/Preview.lua'))('FlareUI', ns)
local P = assert(ns.SettingsPreview)
local function row(key) return { key = key, module = key:match('^([^.]+)'), Get = function() return key == 'uf.frameStyle' and 'forever' or nil end } end
assert(P.Resolve(row('uf.frameStyle')).kind == 'unit')
assert(P.Resolve(row('uf.frameStyle'), 'addon').value == 'addon')
assert(P.Resolve(row('mm.style'), 'round').value == 'round')
assert(P.Resolve(row('qol.autoAcceptQuests')) == nil)
assert(P.Resolve(row('qol.bagGaps')).kind == 'bags')
assert(P.Resolve(row('qol.npLevel')).kind == 'nameplate')
assert(P.Resolve(row('au.timer')).kind == 'auras')
assert(P.Resolve(row('uf.auraShape')).kind == 'unitAuras')
assert(P.Resolve(row('ch.editBox')).kind == 'chat')
assert(P.Resolve(row('tt.healthBar')).kind == 'tooltip')
assert(P.Resolve(row('qt.wrap')).kind == 'tracker')
assert(P.Resolve(row('dm.pullLine')).kind == 'meter')
assert(P.Resolve(row('ab.buttonArt')).kind == 'actions')
assert(P.Resolve(row('rb.combo')).kind == 'resources')
assert(P.Resolve(row('rm.names')).kind == 'radial')
local font = row('ch.font.text.size'); font.previewFont = 'chat.chatFont'
assert(P.Resolve(font).kind == 'font')
assert(P.Resolve(font).font == 'chat.chatFont')
assert(P.Resolve(row('qol.fastLoot')) == nil)
assert(P.Resolve(row('ab.autoRanks')) == nil)
assert(values['unitframes.palette'] == 'flareui')
print('PASS: visual routing, font metadata, style overrides and behavioural exclusions')

-- A small WoW widget double records rendering, visibility, allocation and animation lifecycle.
-- It intentionally errors on unknown methods instead of silently accepting misspelled APIs.
local allocated = 0
local Widget = {}; Widget.__index = Widget
local function widget(parent)
    allocated = allocated + 1
    return setmetatable({ parent = parent, shown = true, scripts = {}, points = {}, level = 1 }, Widget)
end
function Widget:CreateTexture() return widget(self) end
function Widget:CreateMaskTexture() return widget(self) end
function Widget:CreateFontString() return widget(self) end
function Widget:SetScript(key, fn) self.scripts[key] = fn end
function Widget:RegisterEvent(key) self.event = key end
function Widget:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
function Widget:Show() self.shown = true end
function Widget:IsShown() return self.shown end
function Widget:SetShown(v) if v then self:Show() else self:Hide() end end
function Widget:ClearAllPoints() self.points = {} end
function Widget:SetPoint(...) self.points[#self.points + 1] = { ... } end
function Widget:SetAllPoints(v) self.allPoints = v end
function Widget:SetAlpha(v) self.alpha = v end
function Widget:SetSize(w, h) assert(w > 0 and h > 0); self.width, self.height = w, h end
function Widget:SetWidth(w) self.width = w end
function Widget:SetHeight(h) self.height = h end
function Widget:SetParent(v) self.parent = v end
function Widget:SetFrameLevel(v) self.level = v end
function Widget:GetFrameLevel() return self.level end
function Widget:SetText(v) self.text = v end
function Widget:GetStringHeight() return 14 end
function Widget:SetTextColor(...) self.textColor = { ... } end
function Widget:SetJustifyH(v) self.justify = v end
function Widget:SetWordWrap(v) self.wrap = v end
function Widget:SetMaxLines(v) self.maxLines = v end
function Widget:SetRotation(v) self.rotation = v end
function Widget:SetScale(v) self.scale = v end
function Widget:SetTexture(v) self.texture = v end
function Widget:SetAtlas(v) self.atlas = v end
function Widget:SetTexCoord(...) self.crop = { ... } end
function Widget:SetVertexColor(...) self.tint = { ... } end
function Widget:SetDesaturated(v) self.desaturated = v end
function Widget:SetDrawLayer(...) self.layer = { ... } end
function Widget:SetBlendMode(v) self.blend = v end
function Widget:AddMaskTexture(v) self.mask = v end
function Widget:EnableMouse(v) self.mouse = v end
function Widget:SetBackdrop(v) self.backdrop = v end
function Widget:SetBackdropColor(...) self.bgColor = { ... } end
function Widget:SetBackdropBorderColor(...) self.borderColor = { ... } end
function Widget:SetStatusBarTexture(v) self.texture = v end
function Widget:SetMinMaxValues(a, b) self.min, self.max = a, b end
function Widget:SetValue(v) self.value = v end
function Widget:SetStatusBarColor(...) self.tint = { ... } end
function Widget:SetCooldown(a, b) self.cooldown = { a, b } end
CreateFrame = function(_, _, parent, template)
    local f = widget(parent)
    if template == 'ActionButtonSpellAlertTemplate' then
        local function animation() return { Play = function(self) self.playing = true end, Stop = function(self) self.playing = false end } end
        f.ProcStartAnim, f.ProcLoop = animation(), animation()
    end
    return f
end
LibStub = function() return { Fetch = function(_, kind, name) return kind .. '/' .. name end, RegisterCallback = function() end } end
C_Texture = { GetAtlasInfo = function() return { file = 'client-atlas', leftTexCoord = 0, rightTexCoord = 1,
    topTexCoord = 0, bottomTexCoord = 1, width = 194, height = 68 } end }
GetTime = function() return 100 end
ns.SetFontFamily = function(t, path, size, flags) t.font = { path, size, flags } end
ns.GetFontPath = function(face) return face end
ns.ApplyShadow = function(t, cfg) t.shadow = cfg.enableShadow end
ns.BorderEdgeSize = function() return 16 end
ns.BORDER_COLOR = { r = 0.65, g = 0.49, b = 0.27, a = 1 }
ns.HEALTH_GREEN, ns.MANA_BLUE = { 0.15, 0.82, 0.15 }, { 0.18, 0.48, 1 }
ns.UnitFrames = { PALETTES = { flareui = { health = ns.HEALTH_GREEN, mana = ns.MANA_BLUE }, blizzard = { health = { 0, 1, 0 }, mana = { 0, 0, 1 } } } }
ns.CreateComboPoint = function(parent) return widget(parent) end
ns.SetComboPoint = function(p, n) p.value = n end
ns.AuraLook = { Style = function(b, look)
    b.look = look
    for _, key in ipairs({ 'Icon', 'Border', 'Count', 'Duration', 'PreviewTimer', 'Cooldown' }) do
        b['FlareUI_' .. key] = b['FlareUI_' .. key] or widget(b)
    end
end }
assert(loadfile('Modules/UnitFramesRing.lua'))('FlareUI', ns)
local trackerSourceFile = assert(io.open('Modules/ObjectiveTracker.lua', 'r'))
local trackerSource = trackerSourceFile:read('*a'); trackerSourceFile:close()
local trackerConstants = assert(loadstring(assert(trackerSource:match('(local C = %b{})')) .. '\nreturn C'))()
ns.ObjectiveTracker = { SampleColors = trackerConstants }
assert(loadfile('Settings/PreviewSamples.lua'))('FlareUI', ns)
local canvas = P.Create(widget(), 226, 226)
for _, styleName in ipairs({ 'addon', 'flareui', 'forever' }) do
    P.Show(canvas, P.Resolve(row('uf.frameStyle'), styleName))
    local sample = canvas.units.playerSample
    if styleName == 'forever' then
        assert(sample.objects.plateArt.texture == 'client-atlas')
        assert(sample.objects.plateArt.parent == sample.frame, 'Plate art must stay behind the health bars')
        assert(sample.objects.plateArt.crop[1] == 1 and sample.objects.plateArt.crop[2] == 0, 'Player plate mirrors the native target atlas')
    elseif styleName == 'flareui' then
        assert(sample.objects.ringArt.mask and sample.objects.portrait.mask, 'Portrait and ring must have transparent round edges')
    end
end
local cases = { 'uf.frameStyle', 'uf.palette', 'uf.simplePet', 'mm.style',
    'au.timer', 'uf.auraShape', 'ch.editBox', 'tt.healthBar', 'tt.ids', 'qt.wrap', 'qt.minimizeButton',
    'dm.pullLine', 'ab.buttonArt', 'ab.xpNumbers', 'rb.combo', 'rb.health', 'qol.bagGaps', 'qol.npLevel', 'rm.names' }
for _, key in ipairs(cases) do
    local spec = P.Resolve(row(key))
    assert(P.Show(canvas, spec), key)
    local before = allocated
    assert(P.Show(canvas, spec), key)
    assert(allocated == before, 'Repeated hover allocated widgets: ' .. key)
end
P.Show(canvas, P.Resolve(row('mm.style'), 'round'))
local before = allocated
P.Show(canvas, P.Resolve(row('mm.style'), 'round'))
assert(allocated == before)
P.Show(canvas, P.Resolve(row('au.timer')))
assert(canvas.frame.scripts.OnUpdate)
canvas.frame:Hide()
assert(canvas.frame.scripts.OnUpdate == nil, 'Hidden previews must stop updating')
P.Show(canvas, P.Resolve(row('au.timer')))
P.Show(canvas, nil)
assert(not canvas.frame.shown and canvas.frame.scripts.OnUpdate == nil)
values['chat.editBoxPosition'] = 'above'
P.Show(canvas, P.Resolve(row('ch.editBox')))
assert(canvas.objects.editBox.points[1][3] == -16, 'Input box above the chat')
values['chat.editBoxPosition'] = 'below'
P.Show(canvas, P.Resolve(row('ch.editBox')))
assert(canvas.objects.editBox.points[1][3] == -172, 'Input box below the chat')
values['chat.chatFont'] = { face = 'Fira Condensed', size = 19, flags = 'OUTLINE' }
P.Show(canvas, P.Resolve(font))
assert(canvas.objects.fontName.font[1] == 'Fira Condensed' and canvas.objects.fontName.font[2] == 19)
assert(canvas.frame.mouse == false)
print('PASS: all renderers, cached widgets, fonts, input placement and animation teardown')

local variants = {
    { 'uf.palette', 'unitframes.palette', { 'flareui', 'blizzard' } },
    { 'ch.editBox', 'chat.editBoxPosition', { 'inside', 'above', 'below' } },
    { 'tt.scale', 'tooltips.scale', { 0.5, 1, 1.5 } },
    { 'tt.anchor', 'tooltips.anchor', { 'default', 'cursorOffset' } },
    { 'qt.minimizeButton', 'objectivetracker.minimizeStyle', { 'button', 'header' } },
    { 'au.shape', 'auras.style', { 'round', 'square' } },
    { 'au.timer', 'auras.timer', { 'below', 'bottom', 'middle', 'none' } },
    { 'au.swipe', 'auras.swipe', { 'icon', 'border', 'both', 'none' } },
    { 'qol.bagColumns', 'tweaks.bagColumns', { 0, 6, 20 } },
    { 'dm.threatValue', 'damagemeter.threatValueDisplay', { 'both', 'percent', 'value' } },
    { 'rm.scale', 'radialmenu.scale', { 0.7, 1, 1.5 } },
}
local toggles = {
    ['au.arrive'] = 'auras.arrive', ['ab.skinCDM'] = 'auras.skinCDM', ['au.timerColor'] = 'auras.timerColor',
    ['ch.social'] = 'chat.socialHide', ['ch.channels'] = 'chat.channelHide', ['ch.menu'] = 'chat.menuHide',
    ['ch.volume'] = 'chat.showVolume', ['ch.copyButton'] = 'chat.copyButton', ['ch.combatLog'] = 'chat.hideCombatLog',
    ['ch.formatPlayer'] = 'chat.formatPlayer', ['ch.formatNPC'] = 'chat.formatNPC', ['ch.levels'] = 'chat.showLevel',
    ['tt.healthBar'] = 'tooltips.hideHealthBar', ['tt.borders'] = 'tooltips.borderByClass', ['tt.showGuild'] = 'tooltips.showGuild',
    ['tt.showGuildRank'] = 'tooltips.showGuildRank', ['tt.showTarget'] = 'tooltips.showTarget', ['tt.showThreat'] = 'tooltips.showThreat',
    ['qt.wrap'] = 'objectivetracker.wrapText', ['qt.zoneHeaders'] = 'objectivetracker.zoneHeaders',
    ['qt.focusButtons'] = 'objectivetracker.focusButtons', ['qt.playButtons'] = 'objectivetracker.playButtons',
    ['dm.pullLine'] = 'damagemeter.threatPullLine', ['dm.pullFlash'] = 'damagemeter.threatPullFlash',
    ['dm.tankLead'] = 'damagemeter.threatTankLead', ['dm.chatTab'] = 'damagemeter.chatTab',
    ['dm.combatTimer'] = 'damagemeter.combatTimer', ['dm.readyCheck'] = 'damagemeter.readyCheckButton', ['dm.countdown'] = 'damagemeter.countdownButton',
    ['ab.procGlow'] = 'actionbars.procGlow', ['ab.buttonArt'] = 'actionbars.buttonArt', ['ab.dimOnCooldown'] = 'actionbars.dimOnCooldown',
    ['ab.statusColours'] = 'actionbars.colors.enableRange', ['ab.gryphonsBehind'] = 'actionbars.gryphonsBehind', ['ab.hideGryphons'] = 'visibility.hideEndCaps',
    ['ab.xpQuest'] = 'actionbars.xpbar.questXP', ['qol.bagGaps'] = 'tweaks.bagGaps', ['qol.bagButtons'] = 'tweaks.bagButtons',
    ['qol.bagRarityBorders'] = 'tweaks.bagRarityBorders', ['qol.bagThickBorders'] = 'tweaks.bagThickBorders',
    ['qol.bagJunkIcon'] = 'tweaks.bagJunkIcon', ['qol.bagUpgradeArrow'] = 'tweaks.bagUpgradeArrow',
    ['qol.npCombo'] = 'tweaks.nameplateCombo', ['qol.npQuest'] = 'tweaks.nameplateQuest', ['qol.npNames'] = 'tweaks.nameplateHideNames',
    ['qol.npLevel'] = 'tweaks.nameplateHideLevel', ['qol.npLevelName'] = 'tweaks.nameplateLevelName', ['rm.names'] = 'radialmenu.showNames',
    ['mm.coordsHover'] = 'minimap.coordsOnHover',
}
for key, path in pairs(toggles) do variants[#variants + 1] = { key, path, { true, false } } end
local count = 0
for _, variant in ipairs(variants) do
    for _, value in ipairs(variant[3]) do
        values[variant[2]] = value
        assert(P.Show(canvas, P.Resolve(row(variant[1]))), variant[1])
        if canvas.frame.scripts.OnUpdate then canvas.frame.scripts.OnUpdate(canvas.frame, 0.5) end
        assert(values[variant[2]] == value, 'Preview changed saved setting: ' .. variant[2])
        count = count + 1
    end
end
values['unitframes.palette'] = 'blizzard'
P.Show(canvas, P.Resolve(row('uf.palette')))
assert(canvas.units.playerSample.objects.health.tint[1] == 0 and canvas.units.playerSample.objects.health.tint[2] == 1)
assert(canvas.units.playerSample.objects.power.tint[3] == 1 and canvas.units.playerSample.objects.power.tint[2] == 0)
values['tooltips.scale'] = 0.5
P.Show(canvas, P.Resolve(row('tt.scale')))
assert(canvas.tooltipCanvas.frame.scale == 1 / 3)
values['tooltips.scale'] = 1.5
P.Show(canvas, P.Resolve(row('tt.scale')))
assert(canvas.tooltipCanvas.frame.scale == 1)
values['radialmenu.scale'] = 1
P.Show(canvas, P.Resolve(row('rm.scale'))); local small = canvas.objects.wheelBackground.width
values['radialmenu.scale'] = 1.5
P.Show(canvas, P.Resolve(row('rm.scale'))); assert(canvas.objects.wheelBackground.width > small)
P.Show(canvas, P.Resolve(row('dm.pullFlash')))
P.Show(canvas, P.Resolve(row('ch.editBox')))
assert(canvas.frame.scripts.OnUpdate == nil, 'Changing preview must stop animation')
print('PASS: ' .. count .. ' setting variants, read-only rendering, production palettes and scale ranges')

values['actionbars.procGlow'] = true
P.Show(canvas, P.Resolve(row('ab.procGlow')))
canvas.actionCanvas.objects.procGlow.ProcLoop:Play()
canvas.frame:Hide()
assert(not canvas.actionCanvas.objects.procGlow.ProcStartAnim.playing and not canvas.actionCanvas.objects.procGlow.ProcLoop.playing)
values['minimap.coordsOnHover'] = false
P.Show(canvas, P.Resolve(row('mm.coordsHover')))
assert(canvas.mapCanvas.objects.coords.shown)
values['minimap.coordsOnHover'] = true
P.Show(canvas, P.Resolve(row('mm.coordsHover')))
assert(not canvas.mapCanvas.objects.coords.shown)
values['tweaks.bagColumns'], values['tweaks.bagThickBorders'] = 20, true
P.Show(canvas, P.Resolve(row('qol.bagColumns')))
assert(canvas.objects.bagBorder1.backdrop.edgeSize <= canvas.objects.bagItem1.width / 2)
print('PASS: hidden proc loops, coordinate visibility and scaled bag borders')

C_Texture.GetAtlasInfo = function() return nil end
P.Show(canvas, P.Resolve(row('mm.style'), 'round'))
assert(canvas.mapCanvas.objects.mapRing.texture == P.MEDIA .. 'Previews\\Ring.tga')
print('PASS: missing-atlas fallback')

-- Exercise the real registry: card choices keep existing get/set, pending-reload and change events.
local real = { L = ns.L, Dialogs = {}, db = { profile = { unitframes = { enabled = true }, minimap = { enabled = true, style = 'square' } }, global = {} } }
local style = 'flareui'
real.UFRing = { Style = function() return style end, SetStyle = function(v) style = v end }
assert(loadfile('Settings/Copy.lua'))('FlareUI', real)
assert(loadfile('Settings/Registry.lua'))('FlareUI', real)
assert(loadfile('Settings/Fonts.lua'))('FlareUI', real)
assert(loadfile('Settings/Pages/UnitFrames.lua'))('FlareUI', real)
assert(loadfile('Settings/Pages/Minimap.lua'))('FlareUI', real)
local settings = real.Settings
local frameStyle, mapStyle = settings.rows['uf.frameStyle'], settings.rows['mm.style']
assert(frameStyle.kind == 'styles' and mapStyle.kind == 'styles')
assert(#frameStyle:Choices() == 3 and #mapStyle:Choices() == 2)
local changed
settings:On('RowChanged', function(r) changed = r.key end)
frameStyle:Set('forever')
assert(style == 'forever' and settings.pending['uf.frameStyle'] and changed == 'uf.frameStyle')
frameStyle:Set('flareui')
assert(not settings.pending['uf.frameStyle'])
mapStyle:Set('round')
assert(real.db.profile.minimap.style == 'round' and settings.pending['mm.style'])
mapStyle:Set('square')
assert(not settings.pending['mm.style'])
assert(settings.rows['uf.font.names.face'].previewFont == 'unitframes.font')
print('PASS: real registry integration, card choices, reload undo and font metadata')

-- A dropdown hover changes only the specimen, including false/zero values and nested fonts.
local borderRow = row('qt.border'); borderRow.path = 'objectivetracker.borderTexture'
values[borderRow.path] = 'FlareUI Frames'
P.Show(canvas, P.Resolve(borderRow, 'None'))
assert(canvas.objects.trackerBox.backdrop.edgeFile == nil)
assert(values[borderRow.path] == 'FlareUI Frames', 'Hover must not save a border')
local opacityRow = row('qt.opacity'); opacityRow.path = 'objectivetracker.opacity'
values[opacityRow.path] = 0.5
P.Show(canvas, P.Resolve(opacityRow, 0))
assert(canvas.objects.trackerBox.bgColor[4] == 0 and values[opacityRow.path] == 0.5)
local faceRow = row('ch.font.text.face'); faceRow.previewFont = 'chat.chatFont'; faceRow.path = 'chat.chatFont.face'
P.Show(canvas, P.Resolve(faceRow, 'Morpheus'))
assert(canvas.objects.fontName.font[1] == 'Morpheus')
assert(values['chat.chatFont'].face == 'Fira Condensed', 'Font hover changed the saved table')
P.Show(canvas, P.Resolve(row('uf.simplePet'), true))
assert(canvas.units.companionSample.objects.name.text == 'Wolf')
assert(canvas.units.companionSample.frame.scale < canvas.units.playerSample.frame.scale)
P.Show(canvas, P.Resolve(row('uf.simpleTargetOf'), true))
assert(canvas.units.companionSample.objects.name.text == 'Thorne')
assert(not canvas.units.companionSample.objects.power.shown, 'Plain target-of-target has no power bar')
values['tweaks.nameplateCombo'] = true
P.Show(canvas, P.Resolve(row('qol.npCombo')))
assert(canvas.objects.plateCombo5.shown and canvas.objects.comboLabel.text:find('3/5', 1, true))
values['tweaks.nameplateQuest'] = true
P.Show(canvas, P.Resolve(row('qol.npQuest')))
assert(canvas.objects.questBadge.shown and canvas.objects.questObjective.shown and not canvas.objects.comboLabel.shown)
values['tooltips.showItemID'] = true
P.Show(canvas, P.Resolve(row('tt.ids')))
assert(canvas.tooltipCanvas.objects.tooltipTitle.text:find('Robes of the Archmage', 1, true))
assert(canvas.tooltipCanvas.objects.tooltipText.text:find('ID: 14152', 1, true))
assert(canvas.tooltipCanvas.objects.tooltipText.text:find('Cloth', 1, true))
assert(P.Resolve(row('rm.position')) == nil, 'Position is not an appearance change')
print('PASS: unsaved border/opacity/font choices, distinct small units, nameplate details and full tooltips')

local sourceFile = assert(io.open('Settings/Panel.lua', 'r'))
local panelSource = sourceFile:read('*a'); sourceFile:close()
-- Exercise the production menu wiring with a menu-description double (no copy of its logic).
local menuCode = assert(panelSource:match('(local function SetupChoiceMenu.-)\n%-%- toggle'))
local hovered, chosen, description, initializer
local menu = { CreateRadio = function(_, _, _, pick, choice)
    chosen = function() pick(choice) end
    description = {
        SetOnEnter = function(self, fn) self.enter = fn end,
        SetOnLeave = function(self, fn) self.leave = fn end,
        AddInitializer = function(_, fn) initializer = fn end,
    }
    return description
end }
local dd = { callbacks = {}, RegisterCallback = function(self, _, fn) self.callbacks[#self.callbacks + 1] = fn end,
    SetupMenu = function(self, fn) fn(self, menu) end }
local menuRow = row('ch.font.text.face'); menuRow.previewFont = 'chat.chatFont'
function menuRow:Choices() return { { text = 'Morpheus', value = 'Morpheus' } } end
local writes = 0
function menuRow:Set() writes = writes + 1 end
local setup = assert(loadstring('local ns, ShowRowPreview, DropdownButtonMixin, OnToggleMenuClosed, IsChoice, PickChoice = ...\n' .. menuCode .. '\nreturn SetupChoiceMenu'))(
    ns, function(r, v) hovered = { r, v } end, { Event = { OnMenuClose = 'close' } }, function() end,
    function() return false end, function(choice) choice.row:Set(choice.value) end)
setup(dd, { row = menuRow })
description.enter(); assert(hovered[2] == 'Morpheus' and writes == 0)
description.leave(); assert(hovered[2] == nil and writes == 0)
local button = { fontString = widget() }; initializer(button)
assert(button.fontString.font[1] == 'Morpheus', 'Menu labels must use the actual font')
dd.callbacks[2](); assert(hovered[2] == nil and writes == 0)
chosen(); assert(writes == 1, 'Only selection may write settings')

-- The actual right-column functions keep the specimen through nonvisual rows, then reset by page.
local columnCode = assert(panelSource:match('(local preview = {}.-)\n%-%- 3%. ROWS'))
local columnS = { Format = function(_, t) return t end, WindowText = function(_, _, fallback) return fallback end,
    Text = function() return nil end }
local column = assert(loadstring('local ns, S, L, Panel = ...; local current = "ch"; local currentTab = {}; local PAD = 12\n' .. columnCode ..
    '\nreturn { state = preview, module = ShowModulePreview, row = ShowRowPreview, switch = function(v) current = v end }'))(ns, columnS, ns.L, {})
for _, name in ipairs({ 'picture', 'title', 'desc', 'tip' }) do column.state[name] = widget() end
column.state.canvas = P.Create(widget(), 226, 226)
column.module(); assert(column.state.spec.kind == 'chat' and not column.state.picture.shown)
local behavior = row('ch.behavior')
function behavior:Label() return 'Behavior' end
function behavior:Description() return '' end
function behavior:Tip() return nil end
column.row(behavior); column.module()
assert(column.state.spec.kind == 'chat' and not column.state.picture.shown)
column.switch('rm'); column.module(); assert(column.state.spec.kind == 'radial')
column.switch('profiles'); column.module(); assert(column.state.spec == nil and column.state.picture.shown)
print('PASS: actual dropdown callbacks, font menu labels, selection-only writes and persistent section previews')

-- Minimap cards scale a canonical layout; buttons must render above the border, not behind it.
values['minimap.buttonBag'] = true
local mapCard = P.Create(widget(), 226, 62)
P.Show(mapCard, P.Resolve(row('mm.style'), 'square'))
local map = mapCard.mapCanvas
assert(map.frame.scale <= 58 / 280)
assert(map.objects.squareTerrain.crop[1] == 35 / 512 and map.objects.squareTerrain.crop[4] == 247 / 512)
assert(not map.objects.mapButton1, 'Style cards keep the drawer closed')
local allocations = allocated
P.Show(mapCard, P.Resolve(row('mm.style'), 'square'))
assert(allocated == allocations)
P.Show(mapCard, P.Resolve(row('mm.style'), 'round'))
assert(map.objects.roundTerrain.mask and map.objects.mapRing.mask)

values['actionbars.gryphonsBehind'], values['visibility.hideEndCaps'] = true, false
P.Show(canvas, P.Resolve(row('ab.gryphonsBehind')))
local action = canvas.actionCanvas
assert(action.objects.endCaps.level < action.overlay.level)
values['actionbars.gryphonsBehind'] = false
P.Show(canvas, P.Resolve(row('ab.gryphonsBehind')))
assert(action.objects.endCaps.level > action.overlay.level, 'Changing layer must affect cached caps')
assert(canvas.objects.xp.shown, 'Action preview keeps XP in the same composition')
values['visibility.hideEndCaps'] = true
P.Show(canvas, P.Resolve(row('ab.hideGryphons')))
assert(not action.objects.endCaps.shown)

local draws, drawActions = 0, P.renderers.actions
P.renderers.actions = function(...) draws = draws + 1; return drawActions(...) end
column.switch('ab'); column.module()
local firstDraw = draws
for _, key in ipairs({ 'ab.hideGryphons', 'ab.xpNumbers', 'ab.procGlow', 'ab.autoRanks' }) do
    behavior.key = key
    column.row(behavior); column.module()
end
assert(draws == firstDraw, 'Hovering action options must not reset the scene or proc animation')
column.state.dirty = true; column.module()
assert(draws == firstDraw + 1, 'A settings refresh must redraw the composition')
P.renderers.actions = drawActions

for _, key in ipairs({ 'main', 'castbar', 'party', 'raid', 'boss', 'tot', 'tof' }) do
    local frameRow = settings.rows['uf.' .. key]
    assert(frameRow.kind == 'framecard' and frameRow.tab == 'frames')
    local specimen = P.Create(widget(), 210, 84)
    P.Show(specimen, P.Resolve(frameRow))
    if key == 'raid' then assert(specimen.objects.groupHealth20.shown) end
    if key == 'party' then assert(specimen.objects.groupHealth4.shown) end
    if key == 'boss' then assert(specimen.objects.groupHealth3.shown) end
    local before = frameRow:Get() and true or false
    frameRow:Set(not before)
    assert(frameRow:Get() == not before and settings.pending[frameRow.key])
    frameRow:Set(before)
    -- nil and false both mean disabled; the first change preserves the original reload baseline.
end
print('PASS: scaled map cards, overlay layers, cached gryphon layering, stable action scene and seven frame-group toggles')

-- Changes ported from the web review retain native rendering and never save hover values.
P.Show(canvas, { kind = 'actions', key = 'ab.xpQuest', value = 'done' })
local doneWidth = canvas.objects.questXp.width
P.Show(canvas, { kind = 'actions', key = 'ab.xpQuest', value = 'all' })
assert(canvas.objects.questXp.width > doneWidth)
P.Show(canvas, { kind = 'actions', key = 'ab.xpQuest', value = 'zone' })
assert(canvas.objects.questXp.width > doneWidth)
P.Show(canvas, { kind = 'actions', key = 'ab.xpQuest', value = 'off' })
assert(not canvas.objects.questXp.shown)
P.Show(canvas, { kind = 'unitAuras', key = 'uf.auraTimer', path = 'unitframes.auraTimer', value = 'middle' })
assert(canvas.units.auraPlayer.frame.shown and canvas.objects.aura1.look.timer == 'middle')
P.Show(canvas, P.Module('uf'))
assert(canvas.units.petOverview.objects.name.text == 'Wolf')
assert(canvas.units.targetOfOverview.objects.name.text == 'Thorne')
values['minimap.clockStats'] = true
P.Show(canvas, { kind = 'minimap', key = 'mm.clockStats' })
assert(canvas.mapCanvas.objects.stats.text == '17:49')
assert(canvas.mapCanvas.objects.clockFPS.text:find('60 fps'))
P.Show(canvas, { kind = 'minimap', key = 'mm.bag' })
assert(canvas.mapCanvas.objects.mapButton1.parent == canvas.mapCanvas.objects.drawer)
P.Show(canvas, { kind = 'tracker', key = 'qt.focusButtons', path = 'objectivetracker.focusButtons', value = true })
assert(canvas.objects.questFocus1.shown and canvas.objects.questFocus2.shown)
P.Show(canvas, { kind = 'chat', key = 'ch.social', value = false })
assert(not canvas.objects.chatHeader1.shown)
P.Show(canvas, { kind = 'chat', key = 'ch.social', value = true })
assert(canvas.objects.chatHeader1.shown)
P.Show(canvas, { kind = 'resources', key = 'rb.swingMain' })
assert(canvas.frame.scripts.OnUpdate)
canvas.frame.scripts.OnUpdate(canvas.frame, 0.5)
assert(canvas.objects.resource.value > 0 and canvas.objects.resource.value < 1)
P.Show(canvas, P.Module('rm'))
assert(canvas.frame.scripts.OnUpdate and canvas.objects.wheelPointer.shown)
canvas.frame.scripts.OnUpdate(canvas.frame, 1.8)
canvas.frame:Hide()
assert(not canvas.frame.scripts.OnUpdate)
print('PASS: contextual unit auras, small frames, quest XP choices, native map overlays, quest/chat controls and animation cleanup')
-- A dirty persistent preview must discard a previously explored dropdown value.
local bagRow = { key = 'qol.bagColumns', path = 'tweaks.bagColumns', Get = function() return values['tweaks.bagColumns'] end,
    Label = function() return 'Columns' end, Description = function() return '' end, Tip = function() end }
columnS.rows = { ['qol.bagColumns'] = bagRow }
column.switch('qol'); values['tweaks.bagColumns'] = 6
column.row(bagRow, 20)
assert(column.state.canvas.objects.bagItem60.shown)
values['tweaks.bagColumns'] = 8; column.state.dirty = true; column.module()
assert(column.state.spec.value == 8 and not column.state.canvas.objects.bagItem25.shown)
local bag = column.state.canvas
assert(bag.objects.bagItem1.parent == bag.overlay and bag.objects.bagsPanel.level < bag.overlay.level)
for _, option in ipairs({ 'bagButtons', 'bagJunkIcon', 'bagUpgradeArrow' }) do
    local key = ({bagButtons='bagButton1', bagJunkIcon='junk', bagUpgradeArrow='upgrade'})[option]
    values['tweaks.' .. option] = true; P.Show(bag, {kind='bags',key='qol.' .. option}); assert(bag.objects[key].shown)
    values['tweaks.' .. option] = false; P.Show(bag, {kind='bags',key='qol.' .. option}); assert(not bag.objects[key].shown)
end
P.Show(canvas, {kind='minimap',key='mm.clockStats'})
assert(canvas.mapCanvas.objects.clockTooltip.level > canvas.mapCanvas.frame.level)
assert(canvas.mapCanvas.objects.dayNight.texture == P.MEDIA .. 'Previews\\Sun.tga')
P.Show(canvas, {kind='radial',key='rm.overview'})
assert(canvas.objects.wheelBackground.texture == P.MEDIA .. 'Previews\\Wheel.tga')
canvas.frame.scripts.OnUpdate(canvas.frame, 0.3)
assert(canvas.objects.wheelSector.rotation ~= nil)
P.Show(canvas, {kind='bags',key='qol.bagColumns'})
assert(canvas.frame.scripts.OnUpdate == nil and not canvas.objects.wheelSector.shown)
print('PASS: stale dropdown regression, bag toggles/layering, portable map art and animated radial sector cleanup')

-- Native OnHide also fires when an ancestor is temporarily hidden during layout.
-- A late visibility notification must stop motion without erasing freshly drawn artwork.
values['visibility.hideEndCaps'] = false
column.switch('ab'); column.module()
local nested = column.state.canvas.actionCanvas
nested.frame.scripts.OnHide(nested.frame)
assert(nested.objects.action1.shown, 'Inherited OnHide must not erase action artwork')
column.state.canvas.frame.scripts.OnHide(column.state.canvas.frame)
column.module()
assert(column.state.canvas.actionCanvas.objects.action1.shown, 'Cached scene must recover after inherited hide')
for _, kind in ipairs({ 'actions', 'minimap', 'unit', 'tooltip', 'bags', 'tracker', 'radial', 'auras', 'chat', 'resources', 'meter' }) do
    local scene = P.Create(widget(), 226, 226)
    P.Show(scene, {kind=kind, key='test.overview'})
    scene.frame.scripts.OnHide(scene.frame)
    assert(scene.invalidated and scene.frame.scripts.OnUpdate == nil)
    P.Show(scene, {kind=kind, key='test.overview'})
    assert(not scene.invalidated and scene.frame.shown)
end
print('PASS: inherited visibility changes preserve artwork and invalidate every cached specimen')

local originalAura = P.renderers.unitAuras
local reported
geterrorhandler = function() return function(err) reported = err end end
P.renderers.unitAuras = function(c)
    c:Text('partial', 'partial', 10, 10)
    error('simulated client aura API failure')
end
assert(not P.Show(canvas, {kind='unitAuras',key='uf.auraSwipe'}))
assert(P.activeSpec == nil and not canvas.frame.shown and not canvas.objects.partial.shown)
assert(reported:find('simulated client aura API failure', 1, true))
P.renderers.unitAuras = originalAura
assert(P.Show(canvas, {kind='unitAuras',key='uf.auraSwipe'}), 'Next render recovers without reload')
print('PASS: preview API failures are contained, override state restored and rendering can recover')

-- Regression: 0 is the actual default for both unit aura fonts, meaning Auto.
local oldStyle = ns.AuraLook.Style
ns.AuraLook.Style = function(b, look)
    assert(look.font.size > 0 and look.countFont.size > 0 and look.timerSize > 0, 'Native SetFont rejects zero')
    oldStyle(b, look)
end
values['unitframes.auraFont'] = {size=0}
values['unitframes.auraCountFont'] = {size=0}
for _, swipe in ipairs({'none','border','icon','both'}) do
    assert(P.Show(canvas, {kind='unitAuras',key='uf.auraSwipe',path='unitframes.auraSwipe',value=swipe}))
    assert(canvas.objects.aura1.look.countFont.size == 12 and canvas.objects.aura1.look.timerSize == 11)
end
assert(values['unitframes.auraFont'].size == 0 and values['unitframes.auraCountFont'].size == 0)
values['unitframes.auraFont'] = {size=16}; values['unitframes.auraCountFont'] = {size=14}
assert(P.Show(canvas, {kind='unitAuras',key='uf.auraSwipe'}))
assert(canvas.objects.aura1.look.timerSize == 16 and canvas.objects.aura1.look.countFont.size == 14)
values['objectivetracker.zoneHeaders'] = true
P.Show(canvas, {kind='tracker',key='qt.overview'})
for id, color in pairs({trackerTitle='TITLE',zone='ZONE',quest1='TITLE_FOCUS',quest2='TITLE',objective1='OBJECTIVE'}) do
    for i=1,3 do assert(canvas.objects[id].textColor[i] == trackerConstants[color][i]) end
end
print('PASS: real Auto font defaults, all aura swipe styles, explicit fonts and production tracker palette')

for _, key in ipairs({'party', 'raid', 'boss', 'castbar'}) do
    local card = P.Create(widget(), 210, 84)
    assert(P.Show(card, {kind='frames',key='uf.' .. key}))
    local border = card.objects[key == 'castbar' and 'castBorder' or 'groupBorder1']
    local fill = card.objects[key == 'castbar' and 'cast' or 'groupHealth1']
    assert(border.level > fill.level and border.backdrop.edgeSize == 8)
    assert(fill.width == border.width - 8)
    assert(fill.points[1][2] == border.points[1][2] + 4)
    assert(fill.points[1][3] == border.points[1][3] - 4)
    for _, object in pairs(card.objects) do
        if object.height and object.points[1] then
            local y = -object.points[1][3]
            assert(y >= 0 and y + object.height <= 84, 'Card content must stay inside its preview area')
        end
    end
end
print('PASS: card border layering, inset fill bounds and specimen layout containment')

P.Show(canvas, {kind='unit',key='uf.frameStyle',value='forever'})
local portrait = canvas.units.playerSample.objects.portrait
assert(portrait.mask and portrait.crop[1] == 0.08 and portrait.crop[2] == 0.92)
P.Show(canvas, {kind='unit',key='uf.frameStyle',value='flareui'})
portrait = canvas.units.playerSample.objects.portrait
assert(portrait.mask and portrait.crop[1] == 0 and portrait.crop[2] == 1, 'Character portrait must reset the icon crop')
print('PASS: icon bevel cropped inside circular portrait mask; character crop restored on style switch')

local largeMapCard = P.Create(widget(), 162, 148)
largeMapCard.isStyleCard = true
for _, style in ipairs({'square','round'}) do
    assert(P.Show(largeMapCard, {kind='minimap',key='mm.style',value=style}))
    assert(largeMapCard.mapCanvas.frame.scale > 0.5, 'Map card should use the enlarged image area')
    assert(largeMapCard.mapCanvas.frame.scale * 280 <= 148)
    assert(not largeMapCard.objects.note, 'Style card must not reserve space for the info-panel caption')
end
print('PASS: larger minimap cards fill the image area without caption or clipping')

local centered = P.Create(widget(), 226, 226)
local centerY
for _, style in ipairs({'addon','flareui','forever'}) do
    P.Show(centered, {kind='unit',key='uf.frameStyle',value=style})
    local unit = centered.units.playerSample
    local nativeTop = style == 'forever' and 0 or style == 'addon' and 21 or 10
    local nativeHeight = style == 'forever' and 68 or style == 'addon' and 63 or 80
    local y = (-unit.frame.points[1][5] + nativeTop + nativeHeight / 2) * unit.frame.scale
    if centerY then assert(math.abs(y - centerY) < 0.001) end
    centerY = y
    assert(not centered.objects.note, 'No generic sample caption')
end
print('PASS: shared visual centers across unit styles and no generic sample caption')

values['minimap.buttonBag'] = true
for _, style in ipairs({'round','square','round'}) do
    values['minimap.style'] = style
    assert(P.Show(canvas, {kind='minimap',key='mm.bag'}))
    local map = canvas.mapCanvas
    assert(map.objects.drawer.level > map.overlay.level, 'Drawer background must cover the rim')
    for i=1,3 do
        local icon = map.objects['mapButton' .. i]
        assert(icon.parent == map.objects.drawer and icon.shown)
        assert(icon.points[1][2] == map.frame, 'Reparented buttons retain map-relative anchors')
    end
end
print('PASS: drawer background and all icons render above the rim across cached style changes')

-- Registry integration: every existing option stays on a reachable tab.
real.Conditions = {BAR_TOKENS={}, BAR_LEGACY={}}
assert(loadfile('Settings/Pages/ActionBars.lua'))('FlareUI', real)
assert(loadfile('Settings/Pages/QualityOfLife.lua'))('FlareUI', real)
assert(settings.rows['ab.hideGryphons'].tab == 'visibility')
assert(settings.rows['ab.hideMacroText'].section == 'ab.buttonText')
assert(settings.rows['qol.bagColumns'].tab == 'bags' and settings.rows['qol.bagColumns'].kind == 'range')
assert(settings.rows['qol.npCombo'].tab == 'nameplates')
for _, key in ipairs({'ab','qol','uf'}) do
    local module = settings.modules[key]; local tabs = {}
    for _, tab in ipairs(module.tabs) do tabs[tab.key] = true end
    for _, section in ipairs(module.sections) do for _, r in ipairs(section.rows) do
        assert(not r.tab or tabs[r.tab], 'Unreachable tab for ' .. r.key)
    end end
end
-- Execute the actual range callbacks, including programmatic fill, drag and keyboard change.
local rangeCode = assert(panelSource:match('(Build.range = function.-)\n%-%- Only the two major'))
function Widget:SetValueStep(v) self.step = v end
function Widget:SetObeyStepOnDrag(v) self.obey = v end
function Widget:SetValue(v) self.value = v; if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,v) end end
local builds, fills, rangePreview = {}, {}, nil
assert(loadstring('local Build, Fill, Text, ForwardHover, ShowRowPreview, ROW_H = ...\n' .. rangeCode))(
    builds, fills, function(parent) return widget(parent) end, function() end, function(_,value) rangePreview=value end, 30)
local rangeRow = {Get=function() return 0 end, Choices=function() return {{value=0,text='Default'},{value=6,text='6'},{value=7,text='7'}} end, IsDisabled=function() return false end}
local rangeWrites, rangeValue = 0, nil
function rangeRow:Set(value) rangeWrites=rangeWrites+1; rangeValue=value end
local rangeFrame=widget(); rangeFrame.row=rangeRow
builds.range(rangeFrame); fills.range(rangeFrame,rangeRow)
assert(rangeWrites==0 and rangeFrame.value.text=='Default')
rangeFrame.control.scripts.OnMouseDown(); rangeFrame.control:SetValue(2); rangeFrame.control:SetValue(3)
assert(rangeWrites==0 and rangePreview==7)
rangeFrame.control.scripts.OnMouseUp(); assert(rangeWrites==1 and rangeValue==7)
rangeFrame.control:SetValue(2); assert(rangeWrites==2 and rangeValue==6)
values['radialmenu.showNames']=true
P.paused=true
P.Show(canvas,{kind='radial',key='rm.overview'})
local name=canvas.objects.radialName.text
canvas.frame.scripts.OnUpdate(canvas.frame,3)
assert(canvas.objects.radialName.text==name)
P.paused=false; canvas.frame.scripts.OnUpdate(canvas.frame,3)
assert(canvas.objects.radialName.text~=name)
print('PASS: redesigned tabs retain all rows, sliders preview/commit correctly and motion pauses')

-- Every requested tweak has a reversible hover specimen, including custom getter rows.
for _, key in ipairs({'tt.healthBar','tt.borders','tt.classNames','tt.showThreat','tt.showTarget','tt.showGuild','tt.showGuildRank','tt.hideFaction','tt.shortItemStats','tt.ids','tt.compareShift','qol.bagGaps','qol.bagButtons','qol.bagRarityBorders','qol.bagThickBorders','qol.bagJunkIcon','qol.bagUpgradeArrow','qol.petFood','qol.npCombo','qol.npQuest','qol.npNames','qol.npLevel','qol.npLevelName','qol.npCombat'}) do
    for _, saved in ipairs({false,true}) do
        local row = {key=key,kind='toggle',Get=function() return saved end}
        local spec = assert(P.Resolve(row,P.HoverValue(row)))
        assert(spec.value==not saved and spec.temporary)
        assert(P.Show(canvas,spec), key)
        assert(canvas.objects.previewChange.shown)
        assert(row:Get()==saved)
        assert(P.Show(canvas,P.Resolve(row)))
        assert(not canvas.objects.previewChange.shown)
    end
end
for _, key in ipairs({'tt.showWorld','tt.showFrames','tt.showBars'}) do
    for _, mode in ipairs({'always','combat','never'}) do
        assert(P.Show(canvas,{kind='tooltip',key=key,value=mode}))
        assert(canvas.objects.visibilityExample.shown)
    end
end
local cardBuild = assert(panelSource:match('(Build.framecard = function.-)\n%-%- legend:'))
assert(not cardBuild:find('f.edit',1,true), 'Frame cards must use the single page edit button')
print('PASS: tooltip, bag and nameplate hover specimens are reversible; visibility choices render; frame cards have no duplicate edit buttons')

-- Section reset is scoped, preserves false defaults and follows normal row setters.
real.defaults = {profile={unitframes={units={player={showLevel=true},target={showLevel=true}}},minimap={style='square'},tweaks={bagGaps=false}}}
settings:SetPath('unitframes.units.player.portrait','class')
settings:SetPath('unitframes.units.player.showLevel',false)
settings:SetPath('unitframes.units.target.portrait','class')
settings:ResetSection('uf','uf.appearance.player','settings')
assert(settings:GetPath('unitframes.units.player.portrait')=='none')
assert(settings:GetPath('unitframes.units.player.showLevel')==true)
assert(settings:GetPath('unitframes.units.target.portrait')=='class')
settings:SetPath('tweaks.bagGaps',true)
local bagRow=settings.rows['qol.bagGaps']
settings:ResetSection('qol',bagRow.section,'nameplates')
assert(settings:GetPath('tweaks.bagGaps')==true)
settings:ResetSection('qol',bagRow.section,'bags')
assert(settings:GetPath('tweaks.bagGaps')==false)
assert(settings.rows['tt.healthBar']==nil) -- independent section reset does not need other modules loaded
for _, key in ipairs({'party','raid','boss'}) do
    local compact=P.Create(widget(),210,68)
    assert(P.Show(compact,{kind='frames',key='uf.'..key}))
    for id, obj in pairs(compact.objects) do
        if id:match('^groupBorder%d+$') then
            local y=-obj.points[1][3]
            assert(y>=0 and y+obj.height<=68, 'Compact specimen stays inside its card')
        end
    end
end
print('PASS: per-unit appearance controls, isolated section resets, false defaults and compact group specimens')

settings:Module{key='resetTest',tabs={{key='frame'},{key='fonts'}}}
settings:Row{key='resetTest.main',path='resetTest.main',section='resetTest.shared'}
settings:Row{key='resetTest.font',path='resetTest.font',section='resetTest.shared',tab='fonts'}
real.defaults.profile.resetTest={main=false,font=10}
settings:SetPath('resetTest.main',true); settings:SetPath('resetTest.font',20)
settings:ResetSection('resetTest','resetTest.shared','frame')
assert(settings:GetPath('resetTest.main')==false and settings:GetPath('resetTest.font')==20)
print('PASS: first-tab resets respect implicit tabs and leave other tabs untouched')

local ringFile=assert(io.open('Modules/UnitFramesRing.lua','r')); local ringSource=ringFile:read('*a'); ringFile:close()
local levelCode=assert(ringSource:match('(function Ring.LayoutLevel.-)\n%-%-+\n%-%- 5b'))
function Widget:SetFont(face,size) assert(size>0); self.fontSize=size end
function Widget:SetShadowOffset() end
function Widget:SetShadowColor() end
function Widget:GetSize() return self.width,self.height end
local ringAPI, levelDb, hole = {}, {showLevel=true}, nil
local lf={RingFrame={Disc=widget(),DiscHit=widget(),Skull=widget()},Level=widget()}
assert(loadstring('local Ring, Geometry, BLIZZ, Kind, PlaceRegion, LEVEL_SCALE, SetAtlasSafe, SKULL, Db, SetDiscHole, Place, PlaceHitButton, LEVEL_FONT, LEVEL_FONT_SIZE = ...\n' .. levelCode))(
    ringAPI, function() return {D=1} end, {player={D=1,level={}}}, function() return 'player' end,
    function(_,_,disc) disc:SetSize(20,20); disc:Show(); return true end, 1, function() return false end, '',
    function() return levelDb end, function(_,_,on) hole=on end, function() return 1,2,20,20 end, function() end, 'font', 10)
for _, on in ipairs({true,false,true,false}) do
    levelDb.showLevel=on; ringAPI.LayoutLevel(lf)
    assert(lf.RingFrame.Disc:IsShown()==on and lf.RingFrame.DiscHit:IsShown()==on and hole==on)
end
print('PASS: level badge, hit region and portrait cutout switch off and back on together')

UnitClass=function() return 'Mage','MAGE' end
UnitExists=function() return true end
UnitLevel=function() return 60 end
SetPortraitTexture=function(texture,unit) texture.livePortrait=unit end
for _, unit in ipairs({'player','target','focus','pet','targettarget','focustarget'}) do
    for _, on in ipairs({true,false}) do
        assert(P.Show(canvas,{kind='unitDetail',key='uf.'..unit..'Level',path='unitframes.units.'..unit..'.showLevel',value=on}))
        assert((canvas.objects.detailLevel and canvas.objects.detailLevel.shown or false)==on)
    end
end
for _, mode in ipairs({'3d','class','none'}) do
    assert(P.Show(canvas,{kind='unitDetail',key='uf.playerPortrait',path='unitframes.units.player.portrait',value=mode}))
end
print('PASS: new portrait and level controls render their unsaved appearance values')

-- Upstream 5.1.1 registry and renderer integration.
for _,page in ipairs({'Chat','Auras','QuestTracker','Tooltips','ResourceBars'}) do
    assert(loadfile('Settings/Pages/'..page..'.lua'))('FlareUI',real)
end
assert(settings.rows['uf.hidePlayer']==nil and P.Resolve(row('uf.hidePlayer'))==nil)
assert(settings.rows['au.skinCDM']==nil and P.Resolve(row('ab.skinCDM')).kind=='auras')
for _,key in ipairs({'ch.channelNames','ch.classIcons','ch.raceIcons','ch.linkIcons','ch.whisperMarkers','ch.nameColon','au.reminders','au.reminderPets','qol.mouseRingShow','qol.lootFeed','qol.bagKeyring','qol.bagReagent','qol.uiScale','qol.uiScaleCustom','qt.colorNames','mm.bagHover','ab.skinCDM'}) do
    assert(settings.rows[key],key..' retained from upstream')
end
for _,module in pairs(settings.modules) do
    local tabs={}; for _,tab in ipairs(module.tabs or {}) do tabs[tab.key]=true end
    local seen={}
    for _,section in ipairs(module.sections) do for _,r in ipairs(section.rows) do
        assert(not seen[r.key], 'Duplicate setting: '..r.key); seen[r.key]=true
        assert(not r.tab or tabs[r.tab], 'Unreachable tab for '..r.key)
    end end
end
local newChoices={
 ['ch.channelNames']={'full','short','number'},['ch.classIcons']={true,false},['ch.raceIcons']={true,false},['ch.linkIcons']={true,false},['ch.whisperMarkers']={true,false},['ch.nameColon']={true,false},
 ['ab.skinCDM']={true,false},['qt.colorNames']={true,false},['qol.bagKeyring']={true,false},['qol.bagReagent']={true,false},
 ['au.reminders']={true,false},['au.reminderPets']={true,false},['au.reminderGlow']={true,false},['au.reminderGlowExpiring']={true,false},['au.reminderConsumables']={'off','instance','always'},['au.reminderBefore']={0,3,10},['au.reminderGroup']={'self','party','all'},
 ['qol.mouseRingShow']={'off','always','combat','rightclick'},['qol.mouseRingSize']={20,40,120},['qol.mouseRingThickness']={1,3,10},['qol.mouseRingClassColor']={true,false},['qol.mouseRingCast']={true,false},['qol.mouseRingGCD']={true,false},['qol.mouseRingSwing']={true,false},['qol.mouseRingRange']={true,false},['qol.mouseRingHideTurning']={true,false},
 ['qol.lootFeed']={true,false},['qol.lootFeedQuality']={0,1,2,3,4},['qol.lootFeedMoney']={true,false},['qol.lootFeedPosition']={'cursor','placed'},['mm.bagHover']={true,false}
}
local prior=P.lastError
for key,choices in pairs(newChoices) do
    for _,value in ipairs(choices) do
        local r=settings.rows[key]; local spec=P.Resolve(r,value)
        assert(P.Show(canvas,spec),key..': '..tostring(P.lastError))
        if canvas.frame.scripts.OnUpdate then canvas.frame.scripts.OnUpdate(canvas.frame,0.3) end
        local count=allocated
        assert(P.Show(canvas,spec),key)
        assert(allocated==count,key..' leaks widgets')
    end
end
assert(P.lastError==prior)
assert(settings.rows['ch.channelNames']:ResetValue()=='full')
assert(settings.rows['qol.uiScale']:ResetValue()=='blizzard' and settings.rows['qol.uiScaleCustom']:ResetValue()==100)
print('PASS: upstream 5.1.1 rows, tab reachability, new visual variants, cached animations and custom reset defaults')

values['minimap.buttonBag']=true
for _,on in ipairs({false,true,false}) do
    assert(P.Show(canvas,P.Resolve(settings.rows['mm.bagHover'],on)))
    assert(canvas.mapCanvas.objects.drawerPointer.shown)
    assert((canvas.mapCanvas.objects.drawer and canvas.mapCanvas.objects.drawer.shown or false)==on)
end
values['tweaks.bagKeyring']=true; values['tweaks.bagReagent']=true; values['tweaks.bagButtons']=true; values['tweaks.bagGaps']=true
for _,columns in ipairs({6,10,20}) do
    values['tweaks.bagColumns']=columns
    assert(P.Show(canvas,{kind='bags',key='qol.bagsOverview'}))
    local last=canvas.objects['bagItem'..columns*3]
    local keyring=canvas.objects['tweaks.bagKeyring1']
    local reagent=canvas.objects['tweaks.bagReagent1']
    local button=canvas.objects.bagButton1
    assert(-last.points[1][3]+last.height <= -keyring.points[1][3])
    assert(-keyring.points[1][3]+keyring.height <= -reagent.points[1][3])
    assert(-reagent.points[1][3]+reagent.height <= -button.points[1][3])
    assert(-button.points[1][3]+button.height <= -canvas.objects.bagMoney.points[1][3])
end
Enum={EditModeSystem={Minimap=1}}
C_AddOns={GetAddOnMetadata=function() return '5.1.1' end}
local fontLink, wrongLink=false,false
for _,r in ipairs(settings:Search('Fonts')) do
    if r.key=='link:uf:fonts' then fontLink=true end
    if r.key=='link:uf:frames' then wrongLink=true end
end
assert(fontLink and not wrongLink,'Search must use the actual tab labels, not old positional labels')
print('PASS: drawer hover changes, compact bag groups remain separated, and Fonts search targets the correct tab')
