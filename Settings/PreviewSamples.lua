local _, ns = ...
local P, S, L = ns.SettingsPreview, ns.Settings, ns.L
local R = P.renderers
local WF = P.WF

-- The Info Panel's pictures, one per kind of option (Preview.lua routes rows here). 11-10 batch E:
-- all drawn with the wireframe kit (Preview.lua) in the mock-up's look, so they read as one set;
-- each still reads the settings it shows, and only a font option shows a real font.

local aliases = { ['ch.channelNames'] = 'chat.channelNames', ['tt.anchor'] = 'tooltips.anchor', ['tt.ids'] = 'tooltips.showItemID', ['tt.showWorld'] = 'tooltips.visibility.worldUnits' }
-- a setting, or the value being tried on the hovered row (never saved)
local function Get(path, default)
    local spec = P.activeSpec
    if spec and spec.value ~= nil then
        if spec.key == 'tt.healthBar' and path == 'tooltips.hideHealthBar' then return not spec.value end
        if spec.key == 'tt.classNames' and path == 'tooltips.nameColor' then return spec.value and 'class' or 'none' end
        if spec.key == 'tt.borders' and path:match('^tooltips.borderBy') then return spec.value end
        if spec.key == 'tt.showGuildRank' and path == 'tooltips.showGuild' then return true end
        if spec.key == 'qol.npLevelName' then
            if path == 'tweaks.nameplateHideLevel' then return true end
            if path == 'tweaks.nameplateHideNames' then return false end
        end
        if spec.key == 'ab.xpQuest' then
            if path == 'actionbars.xpbar.questXP' then return spec.value ~= 'off' end
            if path == 'actionbars.xpbar.questXPMode' then return spec.value end
        end
        local hide = ({ ['ch.social'] = 'chat.socialHide', ['ch.channels'] = 'chat.channelHide', ['ch.menu'] = 'chat.menuHide' })[spec.key]
        if hide == path then return not spec.value end
    end
    if spec and spec.value ~= nil and (spec.path or aliases[spec.key]) == path then return spec.value end
    local v = S:GetPath(path)
    if v == nil then return default end
    return v
end
-- a font setting, with the hovered dropdown's value tried on
local function Font(path)
    local cfg = Get(path, {})
    local spec = P.activeSpec
    if spec and spec.font == path and spec.value ~= nil then
        local copy = {}; for k, v in pairs(cfg) do copy[k] = v end
        local field = spec.key:match('%.([^%.]+)$')
        if field == 'shadow' then
            copy.enableShadow = spec.value ~= 'none'
            copy.shadowX = spec.value == 'strong' and 2 or 1; copy.shadowY = -copy.shadowX
        elseif field == 'face' or field == 'size' or field == 'flags' then copy[field] = spec.value end
        return copy
    end
    return cfg
end
local function Note(c, text)
    if text then c:Text('note', text, 8, c.height - 26, c.width - 16, { size = 10 }) end
end
local function Heading(c, text)
    local t = c:Text('heading', text, 8, 8, c.width - 16, { size = 12 })
    t:SetTextColor(WF.gold[1], WF.gold[2], WF.gold[3])
end
local function Centre(t) t:SetJustifyH('CENTER'); return t end
local function Palette()
    return ns.UnitFrames.PALETTES[Get('unitframes.palette', 'flareui')] or ns.UnitFrames.PALETTES.flareui
end
-- a small coloured square inside chat text, standing in for an icon
local function Chip(r, g, b) return ('|T%s:11:11:0:0:8:8:0:8:0:8:%d:%d:%d|t'):format(P.WHITE, math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)) end

--------------------------------------------------
-- UNIT FRAMES
-- FlareUI: a round portrait over the end of the bars; Forever: a plate holding portrait and bars;
-- Simple ('addon'): the bars alone. The player and pet have the portrait on the left.
--------------------------------------------------
local function UnitHeight(style, width)
    if style == 'forever' then return math.floor(width * 0.36 + 0.5) end
    if style == 'addon' then return math.floor(width * 0.17 + 0.5) + math.max(3, math.floor(width * 0.055 + 0.5)) + 1 end
    return math.floor(width * 0.34 + 0.5)
end
local function Unit(c, id, style, unit, y, width, palette, x)
    x = x or (c.width - width) / 2
    local W = width
    local left = unit == 'player' or unit == 'pet'
    local color = palette.health
    if unit ~= 'pet' and ns.ClassColorsOn and ns.ClassColorsOn(Get('unitframes.units.' .. unit, {})) then color = WF.mage end
    local powerColor = unit == 'pet' and WF.orange or palette.mana
    local height = UnitHeight(style, W)
    local hh = math.floor(W * (style == 'addon' and 0.17 or 0.135) + 0.5)
    local ph = math.max(3, math.floor(W * (style == 'addon' and 0.055 or 0.045) + 0.5))
    local bx, bw, by, vx0, vx1
    if style == 'addon' then
        if unit == 'targettarget' then hh, ph = hh + ph + 1, 0 end
        bx, bw, by = x, W, y
        vx0, vx1 = bx, bx + bw
    elseif style == 'forever' then
        local d = height - 8
        c:Frame(id .. 'Plate', x, y, W, height, nil, { line = WF.gold, thick = 2, fill = WF.dark, fillAlpha = 0.75, z = 1 })
        local px = left and x + 4 or x + W - 4 - d
        c:Disc(id .. 'Face', px, y + 4, d, WF.wash, 0.16, 4)
        c:Ring(id .. 'Rim', px, y + 4, d, 2, WF.gold, 5)
        bw = W - d - 14
        bx = left and px + d + 5 or x + 6
        by = y + (height - hh - ph - 1) / 2
        vx0, vx1 = bx, bx + bw
    else
        local d = height
        local px = left and x or x + W - d
        -- an opaque back, so the bars run under the portrait
        c:Disc(id .. 'Back', px, y, d, WF.dark, 1, 4)
        c:Disc(id .. 'Face', px, y, d, WF.wash, 0.16, 5)
        c:Ring(id .. 'Rim', px, y, d, 2, WF.gold, 6)
        bw = W - d * 0.8
        bx = left and x + d * 0.8 or x
        by = y + (d - hh - ph - 1) / 2
        vx0, vx1 = left and px + d + 2 or bx, left and bx + bw or px - 2
    end
    c:Bar(id .. 'Health', bx, by, bw, hh, 0.82, color, { z = 2 })
    if ph > 0 then c:Bar(id .. 'Power', bx, by + hh + 1, bw, ph, 0.65, powerColor, { z = 2 }) end
    local fs = math.max(8, math.floor(W * 0.062 + 0.5))
    local name = unit == 'pet' and L["Wolf"] or unit ~= 'player' and 'Thorne' or (Get('unitframes.fullNames') and 'Aeloria Dawnwhisper' or 'Aeloria')
    local textY = by + (hh - fs) / 2 - 1
    local valueW = fs * 2.4
    c:Text(id .. 'Name', name, vx0 + 4, textY, math.max(10, vx1 - vx0 - 8 - valueW), { size = fs }):SetWordWrap(false)
    if not (style == 'addon' and unit == 'targettarget') then
        c:Text(id .. 'Value', '82%', vx1 - 4 - valueW, textY, valueW, { size = fs }):SetJustifyH('RIGHT')
    end
    return height
end

function R.unit(c, spec)
    local style = spec.key == 'uf.frameStyle' and spec.value or (ns.UFRing and ns.UFRing.Style() or 'addon')
    local palette = Palette()
    -- a style card: the player alone, as large as the card allows
    if c.height < 120 then
        local width = math.min(c.width - 8, (c.height - 6) / 0.36)
        Unit(c, 'card', style, 'player', (c.height - UnitHeight(style, width)) / 2, width, palette)
        return
    end
    local width = math.min(c.width - 16, 190)
    c:Text('playerLabel', L["Player"], 8, 8)
    Unit(c, 'player', style, 'player', 30, width, palette)
    local function Small(path) return (Get(path, true) or style == 'addon') and 'addon' or style end
    if spec.key == 'uf.overview' or spec.key == 'uf.frameStyle' or spec.key == 'uf.palette' then
        local w = math.min(110, (c.width - 24) / 2)
        c:Text('petLabel', L["Pet"], 8, 118, w)
        c:Text('targetOfLabel', L["Target of Target"], c.width / 2 + 4, 118, w, { size = 10 })
        Unit(c, 'pet', Small('unitframes.simplePet'), 'pet', 140, w, palette, 8)
        Unit(c, 'tot', Small('unitframes.simpleTargetOf'), 'targettarget', 140, w, palette, c.width / 2 + 4)
        return
    end
    local pet, tot = spec.key == 'uf.simplePet', spec.key == 'uf.simpleTargetOf'
    c:Text('smallLabel', pet and L["Pet"] or tot and L["Target of Target"] or L["Target"], 8, 118)
    local companion = style
    if pet or tot then companion = (spec.value == true or style == 'addon') and 'addon' or style end
    Unit(c, 'companion', companion, pet and 'pet' or tot and 'targettarget' or 'target', 140,
        (pet or tot) and width * 0.55 or math.min(width, 170), palette)
end

-- the unit frame rows: the frame itself, or a group of tiles
function R.frames(c, spec)
    local key = spec.key:match('uf%.(.+)')
    local palette = Palette()
    if key == 'main' or key == 'tot' or key == 'tof' then
        local style = ns.UFRing and ns.UFRing.Style() or 'addon'
        if key ~= 'main' and Get('unitframes.simpleTargetOf', true) then style = 'addon' end
        Unit(c, 'frameUnit', style, key == 'main' and 'player' or 'targettarget', 24, math.min(c.width - 24, 180), palette)
    elseif key == 'castbar' then
        local width, height = math.min(210, c.width - 20), 22
        local x, y = (c.width - width) / 2, 40
        c:Icon('castIcon', x, y, height, WF.blue)
        local bx, bw = x + height + 4, width - height - 4
        c:Bar('cast', bx, y, bw, height, 0.65, palette.playerCast or WF.blue)
        c:Text('castLabel', L["Frostbolt"], bx + 6, y + 5, bw - 60, { size = 10 }):SetWordWrap(false)
        c:Text('castTime', '1.6 / 2.5', bx + bw - 54, y + 5, 48, { size = 10 }):SetJustifyH('RIGHT')
    else
        local raid, boss = key == 'raid', key == 'boss'
        local colors = { WF.mage, { 0.77, 0.12, 0.23 }, WF.orange, { 0.67, 0.83, 0.45 }, { 0.8, 0.8, 0.82 } }
        local columns, rows = raid and 5 or 1, raid and 4 or boss and 3 or 4
        local width = raid and math.floor((c.width - 24) / 5 - 4) or math.min(170, c.width - 32)
        local height, gap = raid and 26 or 24, 4
        local left = (c.width - columns * (width + gap) + gap) / 2
        for i = 1, columns * rows do
            local x, y = left + ((i - 1) % columns) * (width + gap), 24 + math.floor((i - 1) / columns) * (height + gap)
            local color = boss and WF.red or colors[(i - 1) % #colors + 1]
            c:Frame('tile' .. i, x, y, width, height, nil, { fill = WF.dark, fillAlpha = 0.6, z = 1 })
            c:Bar('tileHealth' .. i, x + 2, y + 2, width - 4, height - 8, 0.95 - (i % 4) * 0.12, color, { z = 2, noLine = true })
            c:Bar('tilePower' .. i, x + 2, y + height - 5, width - 4, 3, 0.7, palette.mana, { z = 2, noLine = true })
            if not raid then
                c:Text('tileName' .. i, (boss and L["Boss"] or L["Party"]) .. ' ' .. i, x + 6, y + 4, width - 12, { size = 10 }):SetWordWrap(false)
            end
        end
    end
end

--------------------------------------------------
-- MINIMAP: square (with its header strip) or round; the badge, drawer, clock and menu on top
--------------------------------------------------
function R.minimap(c, spec)
    local card = c.isStyleCard or c.height < 120
    local style = spec.key == 'mm.style' and spec.value or Get('minimap.style', 'square')
    local round = style == 'round'
    local size = math.floor(math.min(c.width - 16, c.height - (card and 8 or 48)))
    local x, y = (c.width - size) / 2, card and (c.height - size) / 2 or 10
    local fs = card and 8 or 11
    if round then
        c:Disc('mapFace', x, y, size, WF.wash, 0.1, 2)
        c:Ring('mapRim', x, y, size, 2, WF.gold, 4)
    else
        c:Frame('mapFace', x, y, size, size, nil, { line = WF.gold, thick = 2, fillAlpha = 0.1, z = 2 })
    end
    -- a lake and a road, so it reads as a map; the player's arrow in the middle
    c:Disc('mapLake', x + size * 0.56, y + size * 0.5, size * 0.22, WF.blue, 0.3, 3)
    c:Fill('mapRoad', x + size * 0.14, y + size * 0.64, size * 0.5, math.max(2, size * 0.02), WF.dim, 0.5, 3)
    c:Glyph('mapPlayer', 'Cursor', x + size / 2 - size * 0.04, y + size / 2 - size * 0.05, size * 0.08, size * 0.1, WF.gold, 5)
    local zone, clock
    if round then
        zone = Centre(c:Text('zoneName', L["Deathknell"], x, y + size * 0.1, size, { size = fs }))
        clock = Centre(c:Text('stats', '17:49', x, y + size * 0.84, size, { size = fs }))
    else
        local header = math.floor(size * 0.12)
        c:Frame('mapHeader', x + 3, y + 3, size - 6, header, nil, { fill = WF.dark, fillAlpha = 0.85, z = 3 })
        zone = c:Text('zoneName', L["Deathknell"], x + 8, y + 3 + (header - fs) / 2 - 1, size - 60, { size = fs })
        clock = c:Text('stats', '17:49', x + size - 52, y + 3 + (header - fs) / 2 - 1, 44, { size = fs })
        clock:SetJustifyH('RIGHT')
    end
    zone:SetWordWrap(false)
    if not Get('minimap.coordsOnHover') then
        Centre(c:Text('coords', '48.2, 36.7', x, y + size * (round and 0.72 or 0.86), size, { size = fs }))
    end
    -- the day / night badge, bottom left
    local d = math.floor(size * 0.13)
    local dx, dy = x - d * 0.15, y + size - d * 0.85
    c:Disc('dayNight', dx, dy, d, WF.gold, 0.85, 6)
    c:Ring('dayNightRim', dx, dy, d, 1, WF.lit, 7)
    if card then return end
    if spec.key == 'mm.bagHover' then c:Glyph('drawerPointer', 'Cursor', dx + d * 0.6, dy + d * 0.5, 16, 20, WF.text, 10) end
    if Get('minimap.buttonBag') and (spec.key == 'mm.bag' or (spec.key == 'mm.bagHover' and Get('minimap.bagHover'))) then
        local icon = d - 4
        c:Frame('drawer', dx + d + 4, dy, 3 * (icon + 4) + 4, d, nil, { fill = WF.dark, fillAlpha = 0.92, z = 8 })
        for i, tint in ipairs({ WF.orange, WF.blue, WF.green }) do
            c:Icon('drawerButton' .. i, dx + d + 8 + (i - 1) * (icon + 4), dy + 2, icon, tint, false, 9)
        end
    end
    if spec.key == 'mm.clockStats' then
        local stats = Get('minimap.clockStats')
        c:Frame('clockTooltip', x + size * 0.18, y + size * 0.16, size * 0.78, stats and 86 or 28, nil, { fill = WF.dark, fillAlpha = 0.95, z = 9 })
        c:Text('clockTime', '17:49', x + size * 0.18 + 8, y + size * 0.16 + 7, size * 0.7)
        if stats then
            c:Text('clockFPS', L["Framerate"] .. ': 60 fps', x + size * 0.18 + 8, y + size * 0.16 + 27, size * 0.7, { size = 10 })
            c:Text('clockHome', L["Latency (Home)"] .. ': 32 ms', x + size * 0.18 + 8, y + size * 0.16 + 45, size * 0.7, { size = 10 })
            c:Text('clockWorld', L["Latency (World)"] .. ': 36 ms', x + size * 0.18 + 8, y + size * 0.16 + 63, size * 0.7, { size = 10 })
        end
    end
    if spec.key == 'mm.microMenu' and Get('minimap.microMenu') then
        c:Frame('microPanel', x + size * 0.2, y + size * 0.26, size * 0.6, 66, nil, { line = WF.gold, fill = WF.dark, fillAlpha = 0.95, z = 9 })
        c:Text('microText', L["Character"] .. '\n' .. L["Spellbook"] .. '\n' .. L["Game Menu"], x + size * 0.2 + 10, y + size * 0.26 + 9, size * 0.5, { size = 11 })
    end
end

--------------------------------------------------
-- BUFFS & DEBUFFS: three auras with the shape, sweep, timer and fonts set
--------------------------------------------------
local AURA_TINTS = { WF.green, WF.blue, WF.purple }
-- one aura on its own small canvas, so the arrival can slide it in
local function AuraIcon(c, i, x, y, size, look)
    c.auraCanvas = c.auraCanvas or {}
    local w, h = size + 8, size + 24
    local a = c.auraCanvas[i]
    if not a then
        a = P.Create(c.frame, w, h)
        c.auraCanvas[i] = a
        c.objects['auraHolder' .. i] = a.frame
    end
    a:Reset()
    a.width, a.height = w, h
    a.frame:SetSize(w, h)
    a.frame:SetAlpha(1)
    a.frame:Show()
    a.frame:ClearAllPoints()
    a.frame:SetPoint('TOPLEFT', x - 4, -(y - 4))
    local round = look.style == 'round'
    local sweeps = {}
    if look.swipe == 'border' or look.swipe == 'both' then
        sweeps[#sweeps + 1] = a:Sweep('borderSweep', 1, 1, size + 6, round, { WF.lit[1], WF.lit[2], WF.lit[3], 0.95 }, false, 2)
        -- an opaque back, so the sweep shows on the rim only
        if round then a:Disc('back', 4, 4, size, WF.dark, 1, 3) else a:Fill('back', 4, 4, size, size, WF.dark, 1, 3) end
    end
    a:Icon('icon', 4, 4, size, AURA_TINTS[i], round, 4)
    if look.swipe == 'icon' or look.swipe == 'both' then
        sweeps[#sweeps + 1] = a:Sweep('iconSweep', 4, 4, size, round, { 0, 0, 0, 0.6 }, false, 7)
    end
    for _, cd in ipairs(sweeps) do if cd.SetCooldown then cd:SetCooldown(GetTime() - i * 2, 12) end end
    local font = {}; for k, v in pairs(look.font) do font[k] = v end
    font.size = look.timerSize
    local ty = look.timer == 'below' and size + 6 or look.timer == 'bottom' and 4 + size - look.timerSize - 2 or 4 + (size - look.timerSize) / 2 - 1
    local timer = Centre(a:Text('timer', '', 0, ty, w, font))
    timer:SetShown(look.timer ~= 'none')
    if look.colored and i == 1 then timer:SetTextColor(1, 0.2, 0.2) else timer:SetTextColor(1, 1, 1) end
    if i == 2 then
        local count = a:Text('count', '3', 4, 4 + size - look.countFont.size - 1, size - 2, look.countFont)
        count:SetJustifyH('RIGHT'); count:SetTextColor(1, 1, 1)
    end
    return a, timer, sweeps
end

local function Auras(c, unit, spec)
    Heading(c, unit and L["Player"] or L["Buffs & Debuffs"])
    if unit then
        Unit(c, 'auraPlayer', ns.UFRing and ns.UFRing.Style() or 'addon', 'player', 34, math.min(190, c.width - 16), Palette())
    end
    local prefix = unit and 'unitframes.' or 'auras.'
    local fontConfig = Font(prefix .. (unit and 'auraFont' or 'font'))
    local countConfig = Font(prefix .. (unit and 'auraCountFont' or 'countFont'))
    -- unit aura fonts use 0 for Auto, as AuraLook.ForUnit does
    local size = unit and 30 or 46
    local autoSize = math.max(7, math.floor(size * 0.4 + 0.5))
    local font, countFont = {}, {}
    for k, v in pairs(fontConfig) do font[k] = v end
    for k, v in pairs(countConfig) do countFont[k] = v end
    font.size = (font.size or 0) > 0 and font.size or autoSize
    countFont.size = (countFont.size or 0) > 0 and countFont.size or autoSize
    local look = {
        style = Get(prefix .. (unit and 'auraStyle' or 'style'), 'round'),
        swipe = Get(prefix .. (unit and 'auraSwipe' or 'swipe'), 'border'),
        timer = Get(prefix .. (unit and 'auraTimer' or 'timer'), 'below'),
        colored = Get(prefix .. (unit and 'auraTimerColor' or 'timerColor'), false),
        font = font, countFont = countFont,
        timerSize = (fontConfig.size or 0) > 0 and fontConfig.size or math.max(8, autoSize - 1),
    }
    local timers, sweeps, holders = {}, {}, {}
    local step = unit and 42 or 66
    local x0, y = unit and 48 or (c.width - (2 * step + size)) / 2, unit and 112 or 46
    for i = 1, 3 do
        local a, timer, list = AuraIcon(c, i, x0 + (i - 1) * step, y, size, look)
        holders[i], timers[i] = a, timer
        for _, cd in ipairs(list) do sweeps[#sweeps + 1] = { cd, i } end
    end
    if spec.key == 'ab.skinCDM' then
        local on = Get('auras.skinCDM')
        c:Text('cdmTitle', L["Cooldown Manager"], 12, 140)
        c:Icon('cdmIcon', 12, 162, 20, WF.orange, false, 3)
        c:Bar('cdmBar', 36, 162, c.width - 48, 20, 0.65, WF.orange, { line = on and WF.gold or nil, noLine = not on, alpha = on and 0.6 or 0.4 })
    end
    local arrive = spec.key == 'au.arrive' and Get('auras.arrive')
    local elapsed = 0
    c:Animate(function(_, dt)
        elapsed = elapsed + dt
        if arrive then
            local progress = math.min(1, (elapsed % 4) * 2)
            local f = holders[3].frame
            f:SetAlpha(progress)
            f:ClearAllPoints(); f:SetPoint('TOPLEFT', x0 + 2 * step - 4, -(y - 4) + (1 - progress) * 12)
        end
        for i = 1, 3 do timers[i]:SetText(math.max(1, math.ceil(12 - ((elapsed + i * 2) % 12))) .. 's') end
        if elapsed < 12 then return end
        elapsed = 0
        for _, s in ipairs(sweeps) do if s[1].SetCooldown then s[1]:SetCooldown(GetTime() - s[2] * 2, 12) end end
    end)
end
function R.auras(c, spec) Auras(c, false, spec) end
function R.unitAuras(c, spec) Auras(c, true, spec) end

--------------------------------------------------
-- CHAT: the window with its lines in the chat font, its header buttons and the input box
--------------------------------------------------
function R.chat(c, spec)
    local top, height = 43, 125
    c:Box('chatBox', 4, top, c.width - 8, height, Get('chat.borderTexture'), Get('chat.opacity', 0.5))
    c:Text('chatTab', L["General"], 12, top + 8, c.width - 24, Font('chat.tabFont'))
    local stamp = Get('chat.betterTimestamps') and '[12:30] ' or ''
    local channelMode = Get('chat.channelNames', Get('chat.shortChannels') and 'number' or 'full')
    local channel = channelMode == 'number' and '[2] ' or channelMode == 'short' and '[2. Trade] ' or '[2. Trade - City] '
    local name = Get('chat.formatPlayer') and '[|cff69ccf0Flareui|r]' or '[Flareui-Realm]'
    if Get('chat.showLevel') then name = '(60) ' .. name end
    local spacing = math.max(Get('chat.increaseLineHeight') and 24 or 19, (Font('chat.chatFont').size or 12) + 4)
    local sampleName = name
    if Get('chat.classIcons') then sampleName = Chip(WF.mage[1], WF.mage[2], WF.mage[3]) .. ' ' .. sampleName end
    if Get('chat.raceIcons') then sampleName = Chip(WF.dim[1], WF.dim[2], WF.dim[3]) .. ' ' .. sampleName end
    local colon = Get('chat.nameColon') and ': ' or ' '
    local lines = {}
    for i, line in ipairs({ '|cff40ff40' .. stamp .. channel .. sampleName .. colon .. L["Ready?"] .. '|r',
        '|cff40ff40' .. stamp .. channel .. '[Aeloria]: ' .. L["Ready!"] .. '|r',
        '|cffffd100' .. (Get('chat.formatNPC') and L["Innkeeper"] .. ': ' or L["Innkeeper says: "]) .. L["Welcome!"] .. '|r' }) do
        if i * spacing <= height - 54 then
            lines[i] = c:Text('chatLine' .. i, line, 12, top + 30 + (i - 1) * spacing, c.width - 24, Font('chat.chatFont'))
            lines[i]:SetWordWrap(false)
        end
    end
    if lines[1] and spec.key == 'ch.linkIcons' then
        lines[1]:SetText((Get('chat.linkIcons') and Chip(WF.blue[1], WF.blue[2], WF.blue[3]) .. ' ' or '') .. '|cff71d5ff[' .. L["Frostbolt"] .. ']|r')
    end
    if lines[1] and spec.key == 'ch.whisperMarkers' then
        lines[1]:SetText((Get('chat.whisperMarkers') and '|cff40ff40> |r' or '') .. '|cffff80ff[Aeloria]: ' .. L["Ready?"] .. '|r')
    end
    local position = Get('chat.editBoxPosition', 'inside')
    local editY = position == 'above' and top - 27 or position == 'below' and top + height + 4 or top + height - 24
    c:Box('editBox', 8, editY, c.width - 16, 23, 'FlareUI Thin', Get('chat.editBoxOpacity', 1))
    c:Text('editText', L["Say:"] .. ' ...', 14, editY + 5, c.width - 28, Font('chat.editBoxFont')):SetWordWrap(false)
    -- the header's buttons: our own icons, in the wireframe's text colour
    local buttonX = 12
    for i, def in ipairs({ { 'chat.socialHide', 'ChatSocial', true }, { 'chat.channelHide', 'ChatChannels', true },
        { 'chat.menuHide', 'ChatOptions', true }, { 'chat.showVolume', 'Volume-Speaker-High', false } }) do
        if Get(def[1], not def[3]) ~= def[3] then
            c:Frame('chatHeaderBox' .. i, buttonX - 2, 11, 22, 22, nil, { z = 2 })
            c:Texture('chatHeader' .. i, P.MEDIA .. 'Icons\\' .. def[2], buttonX, 13, 18, 18, true):SetVertexColor(WF.text[1], WF.text[2], WF.text[3])
            buttonX = buttonX + 26
        end
    end
    if Get('chat.copyButton') then
        c:Frame('copyBox', c.width - 52, 11, 46, 22, nil, { z = 2 })
        Centre(c:Text('copyButton', L["Copy"], c.width - 52, 15, 46, { size = 10 }))
    end
    if not Get('chat.hideCombatLog', false) and spec.key == 'ch.combatLog' then
        c:Text('combatTab', L["Combat Log"], 85, top + 8, c.width - 97, Font('chat.tabFont'))
    end
    if spec.key == 'ch.minAlpha' then c.frame:SetAlpha(Get('chat.minAlpha', 0)) end
end

--------------------------------------------------
-- TOOLTIPS: a unit or an item; the border tints by class or quality
--------------------------------------------------
function R.tooltip(outer, spec)
    if not outer.tooltipCanvas then
        outer.tooltipCanvas = P.Create(outer.frame, outer.width, outer.height)
        outer.objects.tooltipCanvasFrame = outer.tooltipCanvas.frame
    end
    local c = outer.tooltipCanvas
    c:Reset()
    local scale = spec.key == 'tt.scale' and Get('tooltips.scale', 1) / 1.5 or 1
    if spec.key == 'tt.compareShift' then scale = 0.72 end
    c.scale = scale
    c.frame:SetScale(scale)
    c.frame:ClearAllPoints()
    c.frame:SetPoint('TOPLEFT', spec.key == 'tt.compareShift' and 0 or (outer.width - c.width * scale) / (2 * scale), 0)
    c.frame:Show()
    local item = spec.key == 'tt.shortItemStats' or spec.key == 'tt.ids' or spec.key == 'tt.compareShift'
    local line = WF.gold
    if Get(item and 'tooltips.borderByQuality' or 'tooltips.borderByClass') then line = item and WF.purple or WF.mage end
    local box = c:Frame('tooltip', 8, 8, c.width - 16, 182, nil, { line = line, fill = { 0.05, 0.05, 0.06 }, fillAlpha = 0.92, z = 2 })
    local title = c:Text('tooltipTitle', item and '|cffa335ee' .. L["Robes of the Archmage"] .. '|r' or (Get('tooltips.nameColor') == 'class' and '|cff69ccf0Aeloria|r' or 'Aeloria'), 16, 18, c.width - 32, Font('tooltips.titleFont'))
    title:SetWordWrap(false)
    local lines = {}
    if item then
        lines = { L["Binds when picked up"], L["Chest"] .. ' · ' .. L["Cloth"], '96 ' .. L["Armor"],
            Get('tooltips.shortItemStats') and '+12 ' .. L["Intellect"] or L["Increases Intellect by 12."],
            '+10 ' .. L["Stamina"], L["Requires Level 57"], '|cff1eff00' .. L["Increases spell damage by 40."] .. '|r' }
        if Get('tooltips.showItemID') then lines[#lines + 1] = 'ID: 14152' end
    else
        if Get('tooltips.showGuild') then lines[#lines + 1] = '<Dawnwatch>' .. (Get('tooltips.showGuildRank') and ' · ' .. L["Member"] or '') end
        lines[#lines + 1] = L["Level 60 Mage"]
        if not Get('tooltips.hideFaction') then lines[#lines + 1] = L["Horde"] end
        if Get('tooltips.showTarget') then lines[#lines + 1] = L["Target"] .. ': Aeloria' end
        if Get('tooltips.showThreat') then lines[#lines + 1] = L["Threat"] .. ': 65%' end
    end
    local font = Font('tooltips.contentFont')
    local displayFont = {}; for k, v in pairs(font) do displayFont[k] = v end
    displayFont.size = math.min(font.size or 12, 116 / math.max(1, #lines))
    local content = c:Text('tooltipText', table.concat(lines, '\n'), 16, 42, c.width - 32, displayFont)
    while content:GetStringHeight() > 124 and displayFont.size > 8 do
        displayFont.size = math.max(8, displayFont.size - 1)
        content = c:Text('tooltipText', table.concat(lines, '\n'), 16, 42, c.width - 32, displayFont)
    end
    local bottom = 48 + math.max(content:GetStringHeight(), #lines * (displayFont.size + 1))
    local healthBar = not item and not Get('tooltips.hideHealthBar')
    box:SetHeight(bottom + (healthBar and 20 or 4))
    local health
    if healthBar then
        health = c:Bar('tooltipHealth', 14, bottom, c.width - 28, 11, 0.8, WF.green)
        c:Text('tooltipHealthText', '3,840 / 4,800', 20, bottom, c.width - 40, { size = 9 })
    end
    if spec.key == 'tt.compareShift' then
        local compare = Get('tooltips.compareShift', true)
        outer:Text('compareHint', compare and L["Hold Shift to compare"] or L["Comparison shown automatically"], 8, 186, outer.width - 16, { size = 10 })
        if not compare then
            outer:Frame('comparison', outer.width * 0.58, 90, outer.width * 0.4, 72, nil, { line = WF.gold, fill = { 0.05, 0.05, 0.06 }, fillAlpha = 0.95, z = 25 })
            outer:Text('comparisonText', L["Equipped"] .. '\n' .. L["Cloth"] .. '\n+8 ' .. L["Intellect"], outer.width * 0.58 + 6, 98, outer.width * 0.4 - 12, { size = 9 })
        end
    end
    local visibilityPath = ({ ['tt.showWorld'] = 'tooltips.visibility.worldUnits', ['tt.showFrames'] = 'tooltips.visibility.frameUnits', ['tt.showBars'] = 'tooltips.visibility.actionBars' })[spec.key]
    if visibilityPath then
        local mode = Get(visibilityPath, 'always')
        if mode == 'never' then c.frame:Hide() end
        outer:Text('visibilityExample', mode == 'never' and L["Tooltip hidden"] or mode == 'combat' and L["Out of combat: tooltip visible"] or L["Tooltip visible in and out of combat"], 8, 183, outer.width - 16, { size = 10 })
        if spec.key == 'tt.showBars' and mode ~= 'never' then
            title:SetText(L["Frostbolt"])
            content:SetText('60 ' .. L["Mana"] .. '\n2.5 ' .. L["Seconds"])
            box:SetHeight(90)
            if health then health:Hide(); c.objects.tooltipHealthText:Hide() end
        end
    end
    if spec.key == 'tt.anchor' then
        local atCursor = Get('tooltips.anchor') == 'cursorOffset'
        c:Glyph('cursor', 'Cursor', atCursor and 6 or c.width - 26, 182, 16, 20, WF.text, 10)
        c:Text('anchorLabel', atCursor and L["At the cursor"] or L["Default position"], 26, 186, c.width - 52, { size = 10 })
    end
end

--------------------------------------------------
-- QUEST TRACKER
--------------------------------------------------
function R.tracker(c, spec)
    local colors = ns.ObjectiveTracker.SampleColors
    local box = c:Box('trackerBox', 4, 12, c.width - 8, 184, Get('objectivetracker.borderTexture'), Get('objectivetracker.opacity', 0.5))
    local title = c:Text('trackerTitle', L["Quests"] .. (Get('objectivetracker.showCount') and ' (2)' or ''), 12, 22, c.width - 24, Font('objectivetracker.headerFont'))
    title:SetTextColor(unpack(colors.TITLE))
    if spec.key == 'qt.minimizeButton' then
        box:SetHeight(35)
        title:SetText(Get('objectivetracker.minimizeStyle') == 'button' and '+' or L["Quests"])
        Note(c, L["Minimized appearance"]); return
    end
    local y = 48
    if Get('objectivetracker.zoneHeaders') then c:Text('zone', L["Elwynn Forest"], 12, y, c.width - 24):SetTextColor(unpack(colors.ZONE)); y = y + 22 end
    for i, name in ipairs({ L["A Threat Within"], L["Kobold Camp Cleanup"] }) do
        local text = (Get('objectivetracker.hideLevel') and '' or '[5] ') .. name .. (Get('objectivetracker.showTags') and ' [G]' or '')
        local indent = 12
        if Get('objectivetracker.playButtons') then
            c:Glyph('questVoice' .. i, 'Chevron', indent - 1, y + 1, 12, 12, WF.text, 8, math.pi / 2)
            indent = indent + 14
        end
        if Get('objectivetracker.focusButtons') then
            c:Ring('questFocus' .. i, indent, y + 2, 10, 1, WF.gold, 8)
            indent = indent + 14
        end
        local t = c:Text('quest' .. i, text, indent, y, c.width - indent - 12, Font('objectivetracker.titleFont'))
        t:SetTextColor(unpack(i == 1 and colors.TITLE_FOCUS or Get('objectivetracker.colorNames') and { 1, 0.5, 0.25 } or colors.TITLE))
        t:SetWordWrap(Get('objectivetracker.wrapText', true)); t:SetMaxLines(2)
        local h = math.max(18, t:GetStringHeight())
        if y + h + (Font('objectivetracker.objectiveFont').size or 12) > 190 then t:Hide(); break end
        local objective = c:Text('objective' .. i, i == 1 and L["Speak to the Marshal"] or '4/8 ' .. L["Kobolds defeated"], 20, y + h, c.width - 32, Font('objectivetracker.objectiveFont'))
        objective:SetWordWrap(false)
        objective:SetTextColor(unpack(colors.OBJECTIVE))
        y = y + h + 30
    end
    box:SetHeight(math.min(184, y - 10))
end

--------------------------------------------------
-- METERS: damage or threat bars, the pull line and flash, the header's buttons
--------------------------------------------------
function R.meter(c, spec)
    c:Box('meterBox', 4, 25, c.width - 8, 151, Get('damagemeter.borderTexture'), Get('damagemeter.opacity', 0.5))
    local threat = spec.key:find('threat') or spec.key:find('pull') or spec.key == 'dm.tankLead'
    c:Text('meterTitle', threat and L["Threat"] or L["Damage"], 12, 34, c.width - 24, Font('damagemeter.headerFont'))
    local mode = Get('damagemeter.threatValueDisplay', 'both')
    for i, name in ipairs({ 'Flareui', 'Aeloria', 'Thorne' }) do
        local y = 61 + (i - 1) * 33
        c:Bar('meterBar' .. i, 10, y, c.width - 20, 27, 1 - (i - 1) * 0.22, ({ WF.mage, { 0.77, 0.12, 0.23 }, WF.orange })[i])
        local value = threat and (mode == 'percent' and '75%' or mode == 'value' and '12.5k' or '12.5k (75%)') or '12.5k'
        if threat and i == 1 and Get('damagemeter.threatTankLead') then value = value:gsub('75%%', '+25%%') end
        c:Text('meterName' .. i, name .. '  ' .. value, 15, y + 6, c.width - 30, Font('damagemeter.barFont')):SetWordWrap(false)
    end
    if threat and Get('damagemeter.threatPullLine') then c:Fill('pullLine', c.width - 42, 58, 2, 98, WF.red, 1, 5) end
    if spec.key == 'dm.pullFlash' and Get('damagemeter.threatPullFlash') then
        local flash = c:Fill('pullFlash', 11, 62, c.width - 22, 25, WF.red, 0.5, 4)
        local elapsed = 0
        c:Animate(function(_, dt)
            elapsed = elapsed + dt
            flash:SetAlpha(math.abs(math.sin(elapsed * math.pi / 0.8)))
        end)
    end
    if threat and Get('damagemeter.threatTankLead') then c:Text('tankLead', L["Tank lead"] .. ': +25%', 12, 180, c.width - 24, { size = 10 }) end
    if spec.key == 'dm.chatTab' and Get('damagemeter.chatTab') then c:Text('meterChatTab', L["General"] .. '  |cffffd100' .. L["Damage"] .. '|r', 12, 7) end
    if Get('damagemeter.combatTimer') then c:Text('combatTime', '01:24', c.width - 52, 34, 46, { size = 10 }):SetJustifyH('RIGHT') end
    for i, def in ipairs({ { 'damagemeter.readyCheckButton', 'DMReadyCheck', 151 }, { 'damagemeter.countdownButton', 'DMCountdown', 176 } }) do
        if Get(def[1]) then
            c:Texture('meterButton' .. i, P.MEDIA .. 'Icons\\' .. def[2], def[3], 6, 18, 18, true):SetVertexColor(WF.text[1], WF.text[2], WF.text[3])
        end
    end
    if spec.key == 'dm.minAlpha' then c.frame:SetAlpha(Get('damagemeter.minAlpha', 0)) end
end

--------------------------------------------------
-- ACTION BARS: four buttons between the gryphons, the XP bar below
--------------------------------------------------
function R.actions(c, spec)
    Heading(c, L["Action Bars"])
    local size, gap, count = 40, 6, 4
    local total = count * size + (count - 1) * gap
    local x0, y = (c.width - total) / 2, 72
    -- the gryphons: over the ends of the bar, or behind it
    if not Get('visibility.hideEndCaps') then
        local z = Get('actionbars.gryphonsBehind') and 1 or 9
        for i = 1, 2 do
            local cx = i == 1 and x0 - 28 or x0 + total - 12
            c:Frame('cap' .. i, cx, y - 14, 40, size + 22, nil, { line = WF.gold, fill = WF.dark, fillAlpha = 0.95, z = z })
            c:Disc('capHead' .. i, cx + 6, y - 38, 28, WF.dark, 1, z)
            c:Ring('capHeadRim' .. i, cx + 6, y - 38, 28, 1, WF.gold, z + 1)
        end
    end
    local range = Get('actionbars.colors.enableRange')
    for i = 1, count do
        local x = x0 + (i - 1) * (size + gap)
        local tint
        if i == 2 and Get('actionbars.dimOnCooldown') then tint = WF.grey end
        if i == 3 and range then tint = WF.red end
        if i == 4 and range then tint = WF.blue end
        if Get('actionbars.buttonArt') then
            c:Frame('art' .. i, x - 4, y - 4, size + 8, size + 8, nil, { line = WF.dim, fill = WF.dark, fillAlpha = 0.7, z = 3 })
        end
        c:Icon('action' .. i, x, y, size, tint, false, 5)
        if not Get('actionbars.hideHotkeys') then
            c:Text('hotkey' .. i, Get('actionbars.cleanKeybinds') and 'S' .. i or 'SHIFT-' .. i, x + 2, y + 3, size - 4, Font('actionbars.hotkeyFont')):SetJustifyH('RIGHT')
        end
        if not Get('actionbars.hideMacroText') then
            local macro = Font('actionbars.macroFont')
            Centre(c:Text('macro' .. i, L["Spell"], x, y + size - (macro.size or 10) - 3, size, macro)):SetWordWrap(false)
        end
    end
    if Get('actionbars.procGlow') then
        local glow = c:Frame('procGlow', x0 - 3, y - 3, size + 6, size + 6, nil, { line = WF.lit, thick = 2, noFill = true, z = 7 })
        local elapsed = 0
        c:Animate(function(_, dt)
            elapsed = elapsed + dt
            glow:SetAlpha(0.45 + 0.55 * math.abs(math.sin(elapsed * 2.2)))
        end)
    end
    -- the XP bar, with quest XP after it
    local barW = c.width - 24
    c:Bar('xp', 12, 156, barW, 16, 0.65, WF.purple)
    if Get('actionbars.xpbar.questXP') then
        local share = ({ done = 0.12, all = 0.30, zone = 0.19 })[Get('actionbars.xpbar.questXPMode', 'done')] or 0.12
        c:Fill('questXp', 13 + (barW - 2) * 0.65, 157, (barW - 2) * share, 14, WF.gold, 0.55, 3)
    end
    local mode = Get('actionbars.xpbar.textFormat', 'VALUES')
    c:Text('xpText', ({ VALUES = '6,500 / 10,000', PERCENT = '65%', BOTH = '6,500 / 10,000 (65%)', REMAINING = '3,500' })[mode] or '', 18, 158, barW - 12, { size = 10 })
end

--------------------------------------------------
-- RESOURCE BARS: one bar (swing bars run) or the combo points
--------------------------------------------------
function R.resources(c, spec)
    Heading(c, L["Resource Bars"])
    local key = spec.key:match('^rb%.(.+)$') or 'health'
    if key == 'overview' then key = 'health' end
    local db = Get('unitframes.resource.bars.' .. key, {})
    local enabled = Get('unitframes.resource.bars.' .. key .. '.enabled', true)
    if key == 'combo' then
        local d, step = 22, 32
        local x0 = (c.width - (4 * step + d)) / 2
        for i = 1, 5 do
            local x = x0 + (i - 1) * step
            if i <= 3 then c:Disc('combo' .. i, x, 82, d, WF.orange, 0.8, 2) end
            c:Ring('comboRim' .. i, x, 82, d, 1, i <= 3 and WF.orange or WF.line, 3)
        end
    else
        local color = key == 'health' and ns.HEALTH_GREEN or key:find('swing') and { 0.86, 0.65, 0.39 } or ns.MANA_BLUE
        local bar = c:Bar('resource', 10, 85, c.width - 20, 24, 0.65, color, { noLine = db.border == 'None' })
        local text = c:Text('resourceText', key:find('swing') and '1.8 / 2.6' or '65%', 16, 90, c.width - 32, Font('unitframes.resource.font'))
        if key:find('swing') and enabled then
            local elapsed = 0
            local duration = key == 'swingMain' and 2.6 or key == 'swingOff' and 1.8 or 2.4
            c:Animate(function(_, dt)
                elapsed = (elapsed + dt) % duration
                bar:SetFraction(elapsed / duration)
                text:SetText(string.format('%.1f / %.1f', elapsed, duration))
            end)
        end
    end
    if not enabled then c.frame:SetAlpha(0.4) end
end

--------------------------------------------------
-- BAGS: the grid with columns, gaps, borders and markers; the extra bags and buttons under it
--------------------------------------------------
function R.bags(c)
    c:Frame('bagsPanel', 3, 8, c.width - 6, c.height - 16, nil, { line = WF.gold, thick = 2, fill = WF.dark, fillAlpha = 0.6, z = 1 })
    local heading = c:Text('heading', L["Bags"], 13, 17, c.width - 26, { size = 12 })
    heading:SetTextColor(WF.gold[1], WF.gold[2], WF.gold[3])
    c:Text('bagMoney', '|cffffd56b128g  42s  16c|r', c.width - 110, c.height - 30, 100, { size = 10 }):SetJustifyH('RIGHT')
    local columns = Get('tweaks.bagColumns', 0); if columns == 0 then columns = 10 end
    local groupGap = Get('tweaks.bagGaps') and 9 or 0
    local gap = 2
    local extras = (Get('tweaks.bagKeyring') and 1 or 0) + (Get('tweaks.bagReagent') and 1 or 0)
    local available = c.height - 45 - 40 - extras * 25 - (Get('tweaks.bagButtons') and 24 or 0)
    local scale = math.min(1, (c.width - 16) / (columns * 32 + (columns - 1) * gap), available / (100 + groupGap))
    groupGap = groupGap * scale
    local size = 32 * scale
    gap = gap * scale
    local thick = Get('tweaks.bagThickBorders') and 2 or 1
    local rarity = Get('tweaks.bagRarityBorders')
    for i = 1, columns * 3 do
        local x, y = 8 + ((i - 1) % columns) * (size + gap), 45 + math.floor((i - 1) / columns) * (size + gap) + (i > columns and groupGap or 0)
        local line = rarity and (i % 2 == 0 and WF.green or WF.purple) or WF.line
        c:Frame('bagItem' .. i, x, y, size, size, nil, { line = line, thick = thick, fillAlpha = 0.12, z = 3 })
        if i == 4 and Get('tweaks.petFood') then c:Disc('petFood', x + 2, y + 2, size * 0.36, WF.green, 1, 5) end
        if i == 3 then c:Text('bagStack', '5', x + size * 0.45, y + size * 0.5, size * 0.5, { size = math.max(8, size * 0.4) }):SetJustifyH('RIGHT') end
        if i == 1 and Get('tweaks.bagJunkIcon') then c:Disc('junk', x + 2, y + 2, size * 0.4, WF.gold, 1, 5) end
        if i == 2 and Get('tweaks.bagUpgradeArrow') then c:Glyph('upgrade', 'Chevron', x + size * 0.48, y + size * 0.48, size * 0.5, size * 0.5, WF.green, 6, math.pi) end
    end
    local extraY = 45 + 3 * size + 2 * gap + groupGap + 7
    for _, group in ipairs({ { 'tweaks.bagKeyring', L["Keyring"] }, { 'tweaks.bagReagent', L["Crafting Bag"] } }) do
        if Get(group[1]) then
            c:Text(group[1] .. 'Title', group[2], 8, extraY + 2, 90, { size = 10 })
            for i = 1, 4 do c:Icon(group[1] .. i, 100 + (i - 1) * 24, extraY - 2, 20, nil, false, 3) end
            extraY = extraY + 25
        end
    end
    if Get('tweaks.bagButtons') then
        for i = 1, 4 do c:Icon('bagButton' .. i, 12 + (i - 1) * 24, extraY, 20, nil, false, 3) end
    end
end

--------------------------------------------------
-- NAMEPLATES
--------------------------------------------------
function R.nameplate(c, spec)
    Heading(c, L["Nameplates"])
    if spec.key == 'qol.npCombat' and not Get('tweaks.combatPlates') then
        c:Text('combatExample', L["In combat: enemy nameplates hidden"], 16, 90, c.width - 32); return
    elseif spec.key == 'qol.npCombat' then
        c:Text('combatExample', L["In combat: enemy nameplates visible"], 16, 158, c.width - 32)
    end
    if not Get('tweaks.nameplateHideNames') then
        c:Text('nameplateName', (Get('tweaks.nameplateHideLevel') and Get('tweaks.nameplateLevelName') and '12 ' or '') .. L["Forest Spider"], 22, 72)
    end
    c:Bar('nameplate', 16, 94, c.width - 32, 17, 0.72, WF.red)
    if not Get('tweaks.nameplateHideLevel') then c:Text('nameplateLevel', '12', c.width - 44, 96, 24):SetJustifyH('RIGHT') end
    if Get('tweaks.nameplateQuest') then
        local badge = c:Text('questBadge', '!', c.width - 14, 90, 12, { size = 18 })
        badge:SetTextColor(WF.gold[1], WF.gold[2], WF.gold[3])
    end
    if Get('tweaks.nameplateCombo') then
        local d, step = 12, 18
        local x0 = (c.width - (4 * step + d)) / 2
        for i = 1, 5 do
            local x = x0 + (i - 1) * step
            if i <= 3 then c:Disc('plateCombo' .. i, x, 120, d, WF.orange, 0.8, 2) end
            c:Ring('plateComboRim' .. i, x, 120, d, 1, i <= 3 and WF.orange or WF.line, 3)
        end
    end
    if spec.key == 'qol.npQuest' then
        c:Text('questObjective', L["Quest objective"] .. ': 4/8', 16, 158, c.width - 32, { size = 11 })
    elseif spec.key == 'qol.npCombo' then
        c:Text('comboLabel', L["Combo Points"] .. ': ' .. (Get('tweaks.nameplateCombo') and '3/5' or L["Hidden"]), 16, 158, c.width - 32, { size = 11 })
    end
end

--------------------------------------------------
-- RADIAL MENU: the wheel picking each slice in turn
--------------------------------------------------
function R.radial(c, spec)
    local size = math.min(c.width - 24, c.height - 48) * math.min(1.5, Get('radialmenu.scale', 1)) / 1.5
    local x, top = (c.width - size) / 2, 12
    local cx, cy = c.width / 2, top + size / 2
    c:Disc('wheelFace', x, top, size, WF.dark, 0.7, 2)
    c:Ring('wheelRim', x, top, size, 2, WF.gold, 3)
    c:Ring('wheelHub', cx - size * 0.09, cy - size * 0.09, size * 0.18, 1, WF.line, 3)
    local s = size * 0.2
    local fills, rims = {}, {}
    for i = 1, 4 do
        local a = (i - 1) * math.pi / 2
        local px, py = cx + math.sin(a) * size * 0.31 - s / 2, cy - math.cos(a) * size * 0.31 - s / 2
        fills[i] = c:Disc('slice' .. i, px, py, s, WF.wash, 0.15, 4)
        rims[i] = c:Ring('sliceRim' .. i, px, py, s, 1, WF.line, 5)
    end
    local names = { L["Frostbolt"], L["Heal"], L["Bags"], L["Mount"] }
    local showNames = Get('radialmenu.showNames', true)
    local label = showNames and Centre(c:Text('radialName', names[1], 12, top + size + 4, c.width - 24, { size = 11 }))
    local pointer = c:Glyph('wheelPointer', 'Cursor', cx, cy, 14, 18, WF.text, 10)
    local elapsed = 0
    c:Animate(function(_, dt)
        elapsed = elapsed + dt
        local phase = (elapsed / 1.6) % 4
        local selected = math.floor(phase) + 1
        local blend = math.min(1, (phase % 1) / 0.35)
        blend = blend * blend * (3 - 2 * blend)
        local angle = (math.floor(phase) - 1 + blend) * math.pi / 2
        pointer:ClearAllPoints()
        pointer:SetPoint('TOPLEFT', cx + math.sin(angle) * size * 0.17 - 4, -(cy - math.cos(angle) * size * 0.17 - 6))
        for i = 1, 4 do
            local on = i == selected
            local tint = on and WF.lit or WF.line
            rims[i].tex:SetVertexColor(tint[1], tint[2], tint[3], 1)
            local fill = on and WF.gold or WF.wash
            fills[i].tex:SetVertexColor(fill[1], fill[2], fill[3], on and 0.35 or 0.15)
        end
        if label then label:SetText(names[selected]) end
    end)
end

-- a font setting: three lines in that font
function R.font(c, spec)
    local cfg = Font(spec.font)
    Heading(c, L["Font Preview"])
    c:Text('fontName', 'Flareui · Aeloria', 12, 53, c.width - 24, cfg)
    c:Text('fontNumbers', '12,345 / 20,000  65%', 12, 98, c.width - 24, cfg)
    c:Text('fontTime', '9s  24s  1m  12:30', 12, 143, c.width - 24, cfg)
end

--------------------------------------------------
-- BUFF REMINDERS, LOOT FEED, MOUSE RING
--------------------------------------------------
function R.reminders(c, spec)
    Heading(c, L["Buff Reminders"])
    if spec.key == 'au.reminders' and not Get('auras.reminders') then
        c:Text('remindersOff', L["Disabled"], 12, 90); return
    end
    -- pets and the blessing are picked in the icon's right-click menu, so a pet always shows
    local tints = { WF.blue, WF.gold, WF.green }
    if Get('auras.reminder.consumables', 'off') ~= 'off' then tints[#tints + 1] = WF.purple end
    if Get('auras.reminder.camping', false) then tints[#tints + 1] = WF.orange end
    if Get('auras.reminder.gathering', false) then tints[#tints + 1] = { 0.67, 0.83, 0.45 } end
    -- as many as fit the picture
    for i = #tints, math.max(1, math.floor((c.width - 12) / 48)) + 1, -1 do tints[i] = nil end
    local glows = {}
    for i, tint in ipairs(tints) do
        local x = 12 + (i - 1) * 48
        c:Icon('reminderIcon' .. i, x, 65, 38, tint, false, 3)
        if Get(i == 2 and 'auras.reminder.glowExpiring' or 'auras.reminder.glowMissing', false) then
            glows[#glows + 1] = c:Frame('reminderGlow' .. i, x - 3, 62, 44, 44, nil, { line = i == 2 and WF.orange or WF.lit, thick = 2, noFill = true, z = 5 })
        end
    end
    c:Text('reminderState', L["Missing"] .. ' / ' .. tostring(Get('auras.reminder.before', 2)) .. ' min', 12, 114, c.width - 24)
    c:Text('reminderGroup', ({ self = L["Player"], party = L["Party"], all = L["Raid"] })[Get('auras.reminder.group', 'all')] or '', 12, 140, c.width - 24)
    local elapsed = 0
    c:Animate(function(_, dt)
        elapsed = elapsed + dt
        for _, glow in ipairs(glows) do glow:SetAlpha(0.6 + 0.4 * math.sin(elapsed * 3)) end
    end)
end

function R.lootFeed(c, spec)
    Heading(c, L["Loot Feed"])
    if spec.key == 'qol.lootFeed' and not Get('tweaks.lootFeed') then c:Text('feedOff', L["Disabled"], 12, 90); return end
    local atCursor = Get('tweaks.lootFeedPosition', 'cursor') == 'cursor'
    local x = atCursor and 36 or 12
    if atCursor then c:Glyph('feedCursor', 'Cursor', 10, 100, 18, 22, WF.text, 10) end
    local entries = {}
    local quality = Get('tweaks.lootFeedQuality', 0)
    if quality <= 1 then entries[#entries + 1] = { WF.text, '|cffffffff' .. L["Linen Cloth"] .. ' x2|r' } end
    if quality <= 2 then entries[#entries + 1] = { WF.green, '|cff1eff00' .. L["Sword"] .. '|r' } end
    if quality >= 3 then entries[#entries + 1] = { WF.purple, '|cffa335ee' .. L["Robes of the Archmage"] .. '|r' } end
    if Get('tweaks.lootFeedMoney', true) then entries[#entries + 1] = { WF.gold, '12 |cffffd700' .. L["Gold"] .. '|r' } end
    local icons, texts = {}, {}
    for i, e in ipairs(entries) do
        icons[i] = c:Icon('feedIcon' .. i, x, 65 + i * 28, 20, e[1], false, 3)
        texts[i] = c:Text('feedText' .. i, e[2], x + 26, 68 + i * 28, c.width - x - 30, { size = 11 })
    end
    local elapsed = 0
    c:Animate(function(_, dt)
        elapsed = (elapsed + dt) % 3
        local alpha = math.min(1, (3 - elapsed) * 2)
        for i = 1, #entries do
            icons[i]:ClearAllPoints(); icons[i]:SetPoint('TOPLEFT', x, -(65 + i * 28 - elapsed * 12))
            texts[i]:ClearAllPoints(); texts[i]:SetPoint('TOPLEFT', x + 26, -(68 + i * 28 - elapsed * 12))
            icons[i]:SetAlpha(alpha); texts[i]:SetAlpha(alpha)
        end
    end)
end

function R.mouseRing(c, spec)
    Heading(c, L["Mouse Ring"])
    local cx, cy = c.width / 2, 105
    c:Glyph('mouseCursor', 'Cursor', cx - 3, cy - 4, 18, 22, WF.text, 10)
    local mode = Get('tweaks.mouseRingShow', 'off')
    if mode == 'off' and spec.key == 'qol.mouseRingShow' then c:Text('mouseOff', L["Disabled"], 12, 155); return end
    local size = math.max(20, math.min(120, Get('tweaks.mouseRingSize', 40)))
    local thick = Get('tweaks.mouseRingThickness', 3)
    local color = Get('tweaks.mouseRingRange') and { 1, 0.15, 0.1 } or Get('tweaks.mouseRingClassColor') and WF.mage or { 0.83, 0.68, 0.43 }
    c:Ring('mouseRing', cx - size / 2, cy - size / 2, size, thick, color, 4)
    local arcs = {}
    for i, def in ipairs({ { 'Cast', { 1, 0.85, 0.3 } }, { 'GCD', { 0.4, 0.8, 1 } }, { 'Swing', { 1, 0.5, 0.2 } } }) do
        if Get('tweaks.mouseRing' .. def[1]) then
            local d = size + 8 * i
            local arc = c:Ring('mouseArc' .. i, cx - d / 2, cy - d / 2, d, 2, def[2], 4)
            if not arc.half then
                arc.half = arc:CreateMaskTexture()
                arc.half:SetTexture(P.MEDIA .. 'Radial\\HalfMask.tga', 'CLAMPTOBLACKADDITIVE', 'CLAMPTOBLACKADDITIVE')
                arc.half:SetAllPoints(arc.tex)
                arc.tex:AddMaskTexture(arc.half)
            end
            arcs[#arcs + 1] = arc.half
        end
    end
    c:Text('mouseContext', mode == 'combat' and L["In Combat"] or mode == 'rightclick' and L["While Right-Clicking"] or L["Always"], 12, 180, c.width - 24, { size = 10 })
    if Get('tweaks.mouseRingHideTurning') then c:Text('mouseTurning', L["Hidden while turning"], 12, 198, c.width - 24, { size = 9 }) end
    local elapsed = 0
    c:Animate(function(_, dt)
        elapsed = elapsed + dt
        for i, mask in ipairs(arcs) do mask:SetRotation(elapsed * (i + 1)) end
    end)
end
