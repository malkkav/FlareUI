-- The Info Panel's wireframe pictures (11-10 batch E), outside the game: every routed option and
-- every value it can take is drawn on a mock canvas, a style card size is drawn for the two style
-- rows, animations are stepped, and drawing the same picture twice must not make new widgets.
-- Run from the repository root with any Lua 5.1+:  lua tools/tests/settings-wireframes.lua
loadstring = loadstring or load
unpack = unpack or table.unpack

local made = 0
local Widget = {}
local function New(parent, kind)
    made = made + 1
    return setmetatable({ parent = parent, kind = kind, shown = true, level = parent and (parent.level or 0) + 1 or 1, scripts = {} }, Widget)
end
local known = {
    GetFrameLevel = function(self) return self.level end,
    SetFrameLevel = function(self, v) self.level = v end,
    IsShown = function(self) return self.shown end,
    Show = function(self) self.shown = true end,
    Hide = function(self) self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end,
    SetShown = function(self, v) if v then self:Show() else self:Hide() end end,
    SetScript = function(self, k, fn) self.scripts[k] = fn end,
    HookScript = function(self, k, fn) self.scripts[k] = fn end,
    GetScript = function(self, k) return self.scripts[k] end,
    SetText = function(self, v) self.text = v end,
    GetText = function(self) return self.text end,
    GetStringHeight = function() return 14 end,
    SetSize = function(self, w, h) assert(w > 0 and h > 0, 'size must be positive'); self.width, self.height = w, h end,
    SetWidth = function(self, w) assert(w > 0, 'width must be positive'); self.width = w end,
    SetHeight = function(self, h) assert(h > 0, 'height must be positive'); self.height = h end,
    CreateTexture = function(self) return New(self, 'Texture') end,
    CreateMaskTexture = function(self) return New(self, 'Mask') end,
    CreateFontString = function(self) return New(self, 'FontString') end,
    SetColorTexture = function(self, r, g, b, a) assert(type(r) == 'number' and type(g) == 'number' and type(b) == 'number', 'colour'); self.color = { r, g, b, a } end,
    SetVertexColor = function(self, r, g, b, a) assert(type(r) == 'number' and type(g) == 'number' and type(b) == 'number', 'colour'); self.color = { r, g, b, a } end,
    SetTextColor = function(self, r, g, b) assert(type(r) == 'number' and type(g) == 'number' and type(b) == 'number', 'text colour') end,
    SetPoint = function(self, point, a, b, c, d)
        for _, v in ipairs({ a, b, c, d }) do if type(v) == 'number' then assert(v == v, 'NaN point') end end
    end,
}
-- an API method we do not track does nothing; our own fields (FlareUI*, Proc*) stay nil
Widget.__index = function(_, k)
    if known[k] then return known[k] end
    if type(k) == 'string' and k:match('^[A-Z]') and not k:match('^FlareUI') and not k:match('^Proc') then return function() end end
end

CreateFrame = function(kind, _, parent) return New(parent, kind) end
LibStub = function() return { Fetch = function(_, kind, name) return kind .. '/' .. tostring(name) end } end
C_Texture = { GetAtlasInfo = function() return nil end }
GetTime = function() return 100 end
local errors = 0
geterrorhandler = function() return function(err) errors = errors + 1; print('ERROR ' .. tostring(err)) end end

local values = {}
local ns = { L = setmetatable({}, { __index = function(_, k) return k end }) }
ns.Settings = { GetPath = function(_, path) return values[path] end }
ns.SetFontFamily = function(t, path, size) assert(type(size) == 'number' and size > 0, 'font size'); t.font = { path, size } end
ns.GetFontPath = function(face) return face end
ns.ApplyShadow = function() end
ns.HEALTH_GREEN, ns.MANA_BLUE = { 0.15, 0.82, 0.15 }, { 0.18, 0.48, 1 }
ns.UnitFrames = { PALETTES = { flareui = { health = ns.HEALTH_GREEN, mana = ns.MANA_BLUE, playerCast = { 0.36, 0.56, 0.78 } },
    blizzard = { health = { 0, 1, 0 }, mana = { 0, 0, 1 } } } }
local frameStyle = 'flareui'
ns.UFRing = { Style = function() return frameStyle end }
ns.ClassColorsOn = function(settings) return settings and settings.classColor end
ns.ObjectiveTracker = { SampleColors = { TITLE = { 1, 0.82, 0 }, TITLE_FOCUS = { 1, 1, 1 }, ZONE = { 1, 1, 1 }, OBJECTIVE = { 0.8, 0.8, 0.8 } } }

assert(loadfile('Settings/Preview.lua'))('FlareUI', ns)
assert(loadfile('Settings/PreviewSamples.lua'))('FlareUI', ns)
local P = ns.SettingsPreview

local function Row(key, current) return { key = key, Get = function() return current end } end
local canvas = P.Create(New(nil, 'Frame'), 256, 256)
local function Draw(key, value, c)
    c = c or canvas
    local spec = P.Resolve(Row(key, value), value)
    assert(spec, 'not routed: ' .. key)
    assert(P.Show(c, spec), 'failed: ' .. key .. ' = ' .. tostring(value))
    local tick = c.frame.scripts.OnUpdate
    if tick then for _ = 1, 30 do tick(c.frame, 0.37) end end
end

-- every routed row, at its current value (nothing set) and at true / false
local keys = {
    'uf.frameStyle', 'uf.palette', 'uf.fullNames', 'uf.simplePet', 'uf.simpleTargetOf',
    'uf.auraShape', 'uf.auraSwipe', 'uf.auraTimer', 'uf.auraTimerColor', 'ab.skinCDM',
    'au.shape', 'au.swipe', 'au.timer', 'au.timerColor', 'au.arrive',
    'mm.style', 'mm.bag', 'mm.clockStats', 'mm.microMenu', 'mm.coordsHover', 'mm.bagHover',
    'ch.opacity', 'ch.border', 'ch.editBoxOpacity', 'ch.editBox', 'ch.lineHeight', 'ch.formatNPC', 'ch.formatPlayer',
    'ch.timestamps', 'ch.channelNames', 'ch.raceIcons', 'ch.classIcons', 'ch.linkIcons', 'ch.whisperMarkers', 'ch.nameColon',
    'ch.levels', 'ch.social', 'ch.channels', 'ch.menu', 'ch.volume', 'ch.copyButton', 'ch.combatLog', 'ch.minAlpha',
    'tt.scale', 'tt.anchor', 'tt.healthBar', 'tt.borders', 'tt.classNames', 'tt.showThreat', 'tt.showTarget', 'tt.showGuild',
    'tt.showGuildRank', 'tt.hideFaction', 'tt.shortItemStats', 'tt.ids', 'tt.compareShift', 'tt.showWorld', 'tt.showFrames', 'tt.showBars',
    'qt.opacity', 'qt.border', 'qt.zoneHeaders', 'qt.tags', 'qt.wrap', 'qt.count', 'qt.hideLevel', 'qt.focusButtons',
    'qt.playButtons', 'qt.minimizeButton', 'qt.colorNames',
    'dm.opacity', 'dm.border', 'dm.minAlpha', 'dm.chatTab', 'dm.combatTimer', 'dm.readyCheck', 'dm.countdown',
    'dm.threatValue', 'dm.pullLine', 'dm.pullFlash', 'dm.tankLead',
    'ab.statusColours', 'ab.procGlow', 'ab.gryphonsBehind', 'ab.hideMacroText', 'ab.hideKeybinds', 'ab.cleanKeybinds',
    'ab.buttonArt', 'ab.dimOnCooldown', 'ab.hideGryphons', 'ab.xpBar', 'ab.xpText', 'ab.xpNumbers', 'ab.xpQuest',
    'uf.main', 'uf.party', 'uf.raid', 'uf.boss', 'uf.castbar', 'uf.tot', 'uf.tof',
    'rb.health', 'rb.power', 'rb.mana', 'rb.combo', 'rb.swingMain', 'rb.swingOff', 'rb.swingRanged',
    'qol.bagColumns', 'qol.bagGaps', 'qol.bagButtons', 'qol.bagRarityBorders', 'qol.bagThickBorders', 'qol.bagJunkIcon',
    'qol.bagUpgradeArrow', 'qol.petFood', 'qol.bagKeyring', 'qol.bagReagent',
    'qol.npCombo', 'qol.npQuest', 'qol.npNames', 'qol.npLevel', 'qol.npLevelName', 'qol.npCombat',
    'au.reminders', 'au.reminderGroup', 'au.reminderBefore', 'au.reminderConsumables', 'au.reminderCamping',
    'au.reminderGathering', 'au.reminderGlow', 'au.reminderGlowExpiring',
    'qol.lootFeed', 'qol.lootFeedPosition', 'qol.lootFeedQuality', 'qol.lootFeedMoney',
    'qol.mouseRingShow', 'qol.mouseRingSize', 'qol.mouseRingThickness', 'qol.mouseRingClassColor', 'qol.mouseRingCast',
    'qol.mouseRingGCD', 'qol.mouseRingSwing', 'qol.mouseRingRange', 'qol.mouseRingHideTurning',
    'rm.scale', 'rm.names',
}
local drawn = 0
for _, key in ipairs(keys) do
    for _, v in ipairs({ false, true }) do Draw(key, v); drawn = drawn + 1 end
end

-- every setting the pictures read, through its values (on, off, each choice)
local settings = {
    ['unitframes.palette'] = { 'flareui', 'blizzard' }, ['unitframes.fullNames'] = { true, false },
    ['unitframes.simplePet'] = { true, false }, ['unitframes.simpleTargetOf'] = { true, false },
    ['unitframes.units.player'] = { { classColor = true }, {} },
    ['auras.style'] = { 'round', 'square' }, ['auras.swipe'] = { 'icon', 'border', 'both', 'none' },
    ['auras.timer'] = { 'below', 'bottom', 'middle', 'none' }, ['auras.timerColor'] = { true, false },
    ['auras.arrive'] = { true, false }, ['auras.skinCDM'] = { true, false },
    ['unitframes.auraStyle'] = { 'round', 'square' }, ['unitframes.auraSwipe'] = { 'icon', 'border', 'both', 'none' },
    ['unitframes.auraTimer'] = { 'below', 'bottom', 'middle', 'none' },
    ['auras.font'] = { { face = 'Roboto Condensed', size = 14 }, { size = 0 } },
    ['minimap.style'] = { 'square', 'round' }, ['minimap.buttonBag'] = { true, false }, ['minimap.bagHover'] = { true, false },
    ['minimap.clockStats'] = { true, false }, ['minimap.microMenu'] = { true, false }, ['minimap.coordsOnHover'] = { true, false },
    ['chat.borderTexture'] = { 'None', 'FlareUI Thick', 'FlareUI Thin' }, ['chat.opacity'] = { 0, 0.5, 1 },
    ['chat.editBoxPosition'] = { 'inside', 'above', 'below' }, ['chat.channelNames'] = { 'number', 'short', 'full' },
    ['chat.chatFont'] = { { size = 22 }, { size = 10 } }, ['chat.classIcons'] = { true, false }, ['chat.raceIcons'] = { true, false },
    ['chat.linkIcons'] = { true, false }, ['chat.showVolume'] = { true, false }, ['chat.copyButton'] = { true, false },
    ['tooltips.scale'] = { 0.5, 1, 1.5 }, ['tooltips.anchor'] = { 'default', 'cursorOffset' },
    ['tooltips.borderByClass'] = { true, false }, ['tooltips.borderByQuality'] = { true, false },
    ['tooltips.visibility.worldUnits'] = { 'always', 'combat', 'never' }, ['tooltips.visibility.actionBars'] = { 'always', 'never' },
    ['tooltips.compareShift'] = { true, false }, ['tooltips.hideHealthBar'] = { true, false },
    ['objectivetracker.minimizeStyle'] = { 'button', 'header' }, ['objectivetracker.wrapText'] = { true, false },
    ['objectivetracker.borderTexture'] = { 'None', 'FlareUI Thin' }, ['objectivetracker.zoneHeaders'] = { true, false },
    ['damagemeter.threatValueDisplay'] = { 'both', 'percent', 'value' }, ['damagemeter.threatPullFlash'] = { true, false },
    ['damagemeter.threatPullLine'] = { true, false }, ['damagemeter.threatTankLead'] = { true, false },
    ['damagemeter.readyCheckButton'] = { true, false }, ['damagemeter.countdownButton'] = { true, false },
    ['actionbars.procGlow'] = { true, false }, ['actionbars.buttonArt'] = { true, false }, ['actionbars.gryphonsBehind'] = { true, false },
    ['visibility.hideEndCaps'] = { true, false }, ['actionbars.colors.enableRange'] = { true, false },
    ['actionbars.xpbar.questXP'] = { true, false }, ['actionbars.xpbar.questXPMode'] = { 'done', 'all', 'zone' },
    ['actionbars.xpbar.textFormat'] = { 'VALUES', 'PERCENT', 'BOTH', 'REMAINING' },
    ['unitframes.resource.bars.health'] = { { border = 'None' }, {} }, ['unitframes.resource.bars.swingMain.enabled'] = { true, false },
    ['tweaks.bagColumns'] = { 0, 6, 20 }, ['tweaks.bagGaps'] = { true, false }, ['tweaks.bagThickBorders'] = { true, false },
    ['tweaks.bagRarityBorders'] = { true, false }, ['tweaks.bagKeyring'] = { true, false }, ['tweaks.bagReagent'] = { true, false },
    ['tweaks.bagButtons'] = { true, false }, ['tweaks.petFood'] = { true, false },
    ['tweaks.nameplateCombo'] = { true, false }, ['tweaks.nameplateQuest'] = { true, false }, ['tweaks.combatPlates'] = { true, false },
    ['auras.reminders'] = { true, false }, ['auras.reminder.consumables'] = { 'off', 'raid' }, ['auras.reminder.camping'] = { true, false },
    ['auras.reminder.gathering'] = { true, false }, ['auras.reminder.glowMissing'] = { true, false }, ['auras.reminder.glowExpiring'] = { true, false },
    ['tweaks.lootFeed'] = { true, false }, ['tweaks.lootFeedPosition'] = { 'cursor', 'fixed' }, ['tweaks.lootFeedQuality'] = { 0, 2, 4 },
    ['tweaks.mouseRingShow'] = { 'off', 'always', 'combat', 'rightclick' }, ['tweaks.mouseRingSize'] = { 20, 120 },
    ['tweaks.mouseRingCast'] = { true, false }, ['tweaks.mouseRingGCD'] = { true, false }, ['tweaks.mouseRingSwing'] = { true, false },
    ['radialmenu.scale'] = { 0.7, 1, 1.5 }, ['radialmenu.showNames'] = { true, false },
}
for path, list in pairs(settings) do
    for _, value in ipairs(list) do
        values[path] = value
        for _, key in ipairs(keys) do Draw(key); drawn = drawn + 1 end
    end
    values[path] = nil
end

-- the style cards: unit frames 3 styles at card size, minimap 2 styles at card size
local card = P.Create(New(nil, 'Frame'), 190, 62); card.isStyleCard = true
local mapCard = P.Create(New(nil, 'Frame'), 156, 148); mapCard.isStyleCard = true
for _, style in ipairs({ 'flareui', 'forever', 'addon' }) do
    frameStyle = style
    Draw('uf.frameStyle', style, card); Draw('uf.frameStyle', style); Draw('uf.main'); Draw('uf.auraShape')
end
for _, style in ipairs({ 'square', 'round' }) do Draw('mm.style', style, mapCard); Draw('mm.style', style) end

-- a font row
local fontRow = Row('ch.font.text.size', 14); fontRow.previewFont = 'chat.chatFont'
assert(P.Show(canvas, P.Resolve(fontRow)))

-- drawing the same picture again reuses its widgets
for _, key in ipairs(keys) do
    Draw(key, true)
    local before = made
    Draw(key, true)
    assert(made == before, 'new widgets on a second draw: ' .. key)
end

-- a hidden picture stops animating; no settings were written
Draw('rm.names', true)
assert(canvas.frame.scripts.OnUpdate)
canvas.frame:Hide()
assert(canvas.frame.scripts.OnUpdate == nil, 'hidden pictures must stop')
assert(next(values) == nil, 'a picture wrote a setting')
assert(errors == 0, errors .. ' renderer errors')
print(('PASS: %d pictures drawn, style cards, reuse and teardown'):format(drawn))
