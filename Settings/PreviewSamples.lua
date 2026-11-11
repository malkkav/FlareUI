local _, ns = ...
local P, S, L = ns.SettingsPreview, ns.Settings, ns.L
local R = P.renderers
local aliases = { ['ch.channelNames'] = 'chat.channelNames', ['tt.anchor'] = 'tooltips.anchor', ['tt.ids'] = 'tooltips.showItemID', ['tt.showWorld'] = 'tooltips.visibility.worldUnits' }
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
local function Heading(c, text) c:Text('heading', text, 8, 8, c.width - 16) end
local function Icon(c, id, name, x, y, size)
    local t = c:Texture(id, 'Interface\\Icons\\' .. name, x, y, size, size, true)
    t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    return t
end
local function Atlas(c, id, name, x, y, w, h)
    local t = c:Texture(id, nil, x, y, w, h)
    if C_Texture.GetAtlasInfo(name) then t:SetAtlas(name) end
    return t
end

local function Round(c, id, texture)
    c.masks = c.masks or {}
    if not c.masks[id] then
        local mask = c.frame:CreateMaskTexture()
        mask:SetTexture('Interface\\CHARACTERFRAME\\TempPortraitAlphaMask', 'CLAMPTOBLACKADDITIVE', 'CLAMPTOBLACKADDITIVE')
        texture:AddMaskTexture(mask)
        c.masks[id] = mask
    end
    c.masks[id]:ClearAllPoints(); c.masks[id]:SetAllPoints(texture)
end

-- A module's own sample frame (made once per canvas): drawn by draw(f), which returns its size, then
-- scaled down to fit (never up) and centred at y. Returns the frame and the height it takes.
local function Sample(c, id, create, draw, y, width, maxHeight)
    c.samples = c.samples or {}
    local f = c.samples[id]
    if not f then
        f = create(c.frame)
        if not f then return nil, 0 end
        c.samples[id] = f
        c.objects[id] = f
    end
    f:SetScale(1)
    f:SetAlpha(1)
    f:Show()
    local w, h = draw(f)
    if not w or w <= 0 or not h or h <= 0 then f:Hide() return nil, 0 end
    local k = math.min(1, (width or c.width - 16) / w, (maxHeight or c.height - y - 4) / h)
    f:SetScale(k)
    f:ClearAllPoints()
    f:SetPoint('TOPLEFT', c.frame, 'TOPLEFT', (c.width - w * k) / 2 / k, -y / k)
    c.used = math.max(c.used or 0, y + h * k)
    return f, h * k
end

-- 11-10 pilot: the unit frames' own code draws the frame (UnitFrames' UF.CreateSample and DrawSample),
-- in the style given, scaled to width (and to maxHeight); centred unless x is given. Returns the
-- frame and the height it takes. (palette: the live one is the frames' own)
local function Unit(c, id, style, unit, y, width, palette, x, maxHeight, opts)
    local UF = ns.UnitFrames
    if not (UF and UF.CreateSample) then return nil, 0 end
    c.samples = c.samples or {}
    local key = id .. ':' .. unit
    local f = c.samples[key]
    if not f then
        f = UF.CreateSample(c.frame, unit)
        if not f then return nil, 0 end
        c.samples[key] = f
        c.objects[key] = f
    end
    f:SetScale(1)
    f:SetAlpha(1)
    f:Show()
    local e = UF.DrawSample(f, style, opts)
    if not e or e.width <= 0 or e.height <= 0 then f:Hide() return nil, 0 end
    -- never larger than the real frame
    local k = math.min(1, width / e.width)
    if maxHeight then k = math.min(k, maxHeight / e.height) end
    f:SetScale(k)
    local left = x or (c.width - e.width * k) / 2
    f:ClearAllPoints()
    f:SetPoint('TOPLEFT', c.frame, 'TOPLEFT', (left + e.left * k) / k, -(y + e.top * k) / k)
    c.used = math.max(c.used or 0, y + e.height * k)
    return f, e.height * k
end

-- 11-10 (Marcus): only what the option changes. Frame Style, Colour Palette, Full Player Names and
-- the page: the player. Simple Pet Frame: the pet. Simple "Target Of": target of target and of focus.
function R.unit(c, spec)
    local style = spec.key == 'uf.frameStyle' and spec.value or (ns.UFRing and ns.UFRing.Style() or 'addon')
    if c.height < 120 then
        -- a Frame Style card: the style's own look (not the setup in use), centred in the card
        local opts = { preset = true }
        local _, h = Unit(c, 'playerSample', style, 'player', 3, c.width - 8, nil, nil, c.height - 6, opts)
        if h and h > 0 and h < c.height - 6 then
            Unit(c, 'playerSample', style, 'player', (c.height - h) / 2, c.width - 8, nil, nil, c.height - 6, opts)
        end
        return
    end
    local function Small(path) return (Get(path, true) or style == 'addon') and 'addon' or style end
    if spec.key == 'uf.simplePet' then
        Unit(c, 'petSample', Small('unitframes.simplePet'), 'pet', 4, c.width - 16)
    elseif spec.key == 'uf.simpleTargetOf' then
        local s = Small('unitframes.simpleTargetOf')
        local _, h = Unit(c, 'totSample', s, 'targettarget', 4, c.width - 16)
        Unit(c, 'tofSample', s, 'focustarget', 4 + h + 12, c.width - 16)
    else
        local frame = Unit(c, 'playerSample', style, 'player', 4, c.width - 16)
        -- Colour Palette (11-11 Marcus): FlareUI's colours shown washed, Blizzard's bright
        if frame and spec.key == 'uf.palette' then
            local flare = Get('unitframes.palette', 'flareui') ~= 'blizzard'
            for _, bar in ipairs({ frame.Health, frame.Power }) do
                local r, g, b = bar:GetStatusBarColor()
                if flare then
                    local grey = (r + g + b) / 3
                    r, g, b = r + (grey - r) * 0.45, g + (grey - g) * 0.45, b + (grey - b) * 0.45
                else
                    local top = math.max(r, g, b, 0.01)
                    r, g, b = r / top, g / top, b / top
                end
                bar:SetStatusBarColor(r, g, b)
            end
        end
    end
end

-- Compact frame specimens: inset fills and a foreground border keep the art legible
-- at card size instead of laying full-size border pieces beneath tiny health bars.
local function CardBorder(c, id, x, y, width, height)
    local border = c:Box(id, x, y, width, height, 'FlareUI Thin', 0)
    border:SetBackdrop({ edgeFile = LibStub('LibSharedMedia-3.0'):Fetch('border', 'FlareUI Thin'), edgeSize = 8 })
    border:SetFrameLevel(c.frame:GetFrameLevel() + 4)
    local bg = c:Texture(id .. 'Background', 'Interface\\Buttons\\WHITE8X8', x + 4, y + 4, width - 8, height - 8)
    bg:SetVertexColor(0.035, 0.035, 0.04, 1)
    bg:SetDrawLayer('BACKGROUND')
end
function R.frames(c, spec)
    local key = spec.key:match('uf%.(.+)')
    local colors = { { 0.41, 0.8, 0.94 }, { 0.77, 0.12, 0.23 }, { 1, 0.49, 0.04 }, { 0.67, 0.83, 0.45 }, { 0.8, 0.8, 0.82 } }
    local palette = ns.UnitFrames.PALETTES[Get('unitframes.palette', 'flareui')] or ns.UnitFrames.PALETTES.flareui
    if key == 'main' or key == 'tot' or key == 'tof' then
        -- the real frames, in the style in use
        local style = ns.UFRing and ns.UFRing.Style() or 'addon'
        if key == 'main' then
            local _, h = Unit(c, 'framePlayer', style, 'player', 4, c.width - 16)
            Unit(c, 'frameTarget', style, 'target', 4 + h + 12, c.width - 16)
        else
            if Get('unitframes.simpleTargetOf', true) then style = 'addon' end
            Unit(c, 'frameSmall', style, key == 'tot' and 'targettarget' or 'focustarget', 4, c.width - 16)
        end
    elseif key == 'castbar' then
        local UF = ns.UnitFrames
        if UF and UF.CreateCastSample then Sample(c, 'castSample', UF.CreateCastSample, UF.DrawCastSample, 4) end
    else
        -- the tiles themselves (the tile kit's samples), in the style in use
        local PF = ns.PartyFrames
        if not (PF and PF.SampleTile) then return end
        local ctx, samples, count, columns
        if key == 'raid' then
            ctx, samples, count, columns = ns.RaidFrames and ns.RaidFrames.PreviewCtx, ns.RaidFrames and ns.RaidFrames.PreviewSamples, 25, 5
        elseif key == 'boss' then
            ctx, samples, count, columns = ns.BossFrames and ns.BossFrames.PreviewCtx, ns.BossFrames and ns.BossFrames.PreviewSamples, 3, 1
            if not ctx then return end
        else
            count, columns = 3, 1
        end
        if key == 'raid' and not ctx then return end
        Sample(c, 'tiles:' .. key, function(parent)
            local box = CreateFrame('Frame', nil, parent)
            box.tiles = {}
            for i = 1, count do box.tiles[i] = PF.SampleTile(box, ctx, samples and samples[i], i) end
            return box
        end, function(box)
            local gap, left, right, tw, th = 6, 0, 0, 0, 0
            for _, t in ipairs(box.tiles) do
                tw, th = PF.DrawSampleTile(t)
                -- the portrait ring stands out on its side
                if t.ringKind and ns.UFRing then
                    local over = ns.UFRing.Overhang(t)
                    if t.ringSide == 'RIGHT' then right = math.max(right, over) else left = math.max(left, over) end
                    gap = math.max(gap, (t.RingFrame and t.RingFrame:GetHeight() or 0) - th + 6)
                end
            end
            for i, t in ipairs(box.tiles) do
                local col, row = (i - 1) % columns, math.floor((i - 1) / columns)
                t:ClearAllPoints()
                t:SetPoint('TOPLEFT', box, 'TOPLEFT', left + col * (tw + 4), -(gap / 2 + row * (th + gap)))
            end
            local rows = math.ceil(count / columns)
            box:SetSize(left + right + columns * tw + (columns - 1) * 4, rows * th + rows * gap)
            return box:GetSize()
        end, 4)
    end
end

-- Build at the real map's size, then scale the entire specimen including border pieces.
-- Only terrain comes from the shipped sample; no captured frame, coordinates or buttons are used.
function R.minimap(outer, spec)
    if not outer.mapCanvas then
        outer.mapCanvas = P.Create(outer.frame, 280, 280)
        outer.objects.mapCanvasFrame = outer.mapCanvas.frame
    end
    local c = outer.mapCanvas
    c:Reset(); c.frame:Show()
    local card = outer.isStyleCard or outer.height < 120
    local scale = math.min((outer.width - 12) / 280, (outer.height - (card and 4 or 36)) / 280)
    c.frame:SetScale(scale); c.frame:ClearAllPoints()
    c.frame:SetPoint('TOPLEFT', outer.frame, 'TOPLEFT', (outer.width - 280 * scale) / (2 * scale), 0)
    local style = spec.key == 'mm.style' and spec.value or Get('minimap.style', 'square')
    local size, x, y = 244, 18, 18
    local terrain = c:Texture(style == 'round' and 'roundTerrain' or 'squareTerrain', P.MEDIA .. 'Art\\Tour\\Minimap.png', x, y, size, size)
    terrain:SetDrawLayer('BACKGROUND')
    terrain:SetTexCoord(35 / 512, 247 / 512, 35 / 512, 247 / 512)
    if style == 'square' then
        c:Box('mapBorder', x - 4, y - 4, size + 8, size + 8, 'FlareUI Frames', 0)
        c:Box('mapHeader', x + 2, y + 2, size - 4, 25, 'FlareUI Thin', 0.9)
    else
        Round(c, 'mapTerrain', terrain)
        local ring = c:Texture('mapRing', P.MEDIA .. 'Previews\\Ring.tga', x - 4, y - 4, size + 8, size + 8, true)
        Round(c, 'mapRim', ring)
    end
    local round = style == 'round'
    c:Text('zoneName', L["Deathknell"], round and 76 or x + 12, round and 48 or y + 8, round and 128 or size - 80, { size = 12 })
    c:Text('stats', '17:49', round and 108 or x + size - 60, round and 224 or y + 8, 65, { size = 11 })
    if not Get('minimap.coordsOnHover') then c:Text('coords', '48.2, 36.7', x + 65, y + size - 20, 130, { size = 12 }) end
    -- Icons live on the overlay frame, above every border/backdrop frame.
    c:Texture('dayNight', P.MEDIA .. 'Previews\\Sun.tga', 10, 237, 32, 32, true)
    if spec.key == 'mm.bagHover' and not card then c:Texture('drawerPointer',P.MEDIA..'Previews\\Cursor.tga',20,243,24,32,true) end
    if Get('minimap.buttonBag') and not card and (spec.key == 'mm.bag' or (spec.key == 'mm.bagHover' and Get('minimap.bagHover'))) then
        local drawer = c:Box('drawer', 46, 232, 111, 35, 'FlareUI Thin', 0.95)
        drawer:SetFrameLevel(c.overlay:GetFrameLevel() + 1)
        for i, name in ipairs({ 'INV_Misc_Bag_08', 'INV_Misc_Book_09', 'INV_Misc_Map_01' }) do
            local icon = c:Texture('mapButton' .. i, 'Interface\\Icons\\' .. name, 52 + (i - 1) * 35, 237, 25, 25, true)
            icon:SetParent(drawer)
            icon:ClearAllPoints()
            icon:SetPoint('TOPLEFT', c.frame, 'TOPLEFT', 52 + (i - 1) * 35, -237)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
    end
    if spec.key == 'mm.clockStats' and not card then
        c:Box('clockTooltip', 72, 56, 180, Get('minimap.clockStats') and 92 or 30, 'FlareUI Thin', 0.95)
        c:Text('clockTime', '17:49', 82, 64, 160)
        if Get('minimap.clockStats') then
            c:Text('clockFPS', L["Framerate"] .. ': 60 fps', 82, 84, 160, { size = 10 })
            c:Text('clockHome', L["Latency (Home)"] .. ': 32 ms', 82, 103, 160, { size = 10 })
            c:Text('clockWorld', L["Latency (World)"] .. ': 36 ms', 82, 122, 160, { size = 10 })
        end
    end
    if spec.key == 'mm.microMenu' and Get('minimap.microMenu') then
        c:Box('microPanel', x + 45, y + 65, 154, 72, 'FlareUI Frames', 0.95)
        c:Text('microText', L["Character"] .. '\n' .. L["Spellbook"] .. '\n' .. L["Game Menu"], x + 54, y + 74, 130, { size = 12 })
    end
    if not card then Note(outer) end
end

local auraIcons = { 'Spell_Holy_WordFortitude', 'Spell_Holy_DivineSpirit', 'Spell_Nature_Regeneration' }
local function Auras(c, unit, spec)
    local prefix = unit and 'unitframes.' or 'auras.'
    local style = Get(prefix .. (unit and 'auraStyle' or 'style'), 'round')
    local timer = Get(prefix .. (unit and 'auraTimer' or 'timer'), 'below')
    local swipe = Get(prefix .. (unit and 'auraSwipe' or 'swipe'), 'border')
    local fontConfig = Font(prefix .. (unit and 'auraFont' or 'font'))
    local countConfig = Font(prefix .. (unit and 'auraCountFont' or 'countFont'))
    -- Unit aura fonts use 0 for Auto. Match AuraLook.ForUnit without seeding or
    -- modifying saved variables, and retain dropdown overrides in the copied config.
    local size = unit and 30 or 46
    -- the icons, their timers below and a little room (the picture's height)
    c.used = 16 + size + 26
    local autoSize = math.max(7, math.floor(size * 0.4 + 0.5))
    local font, countFont = {}, {}
    for k, v in pairs(fontConfig) do font[k] = v end
    for k, v in pairs(countConfig) do countFont[k] = v end
    font.size = (font.size or 0) > 0 and font.size or autoSize
    countFont.size = (countFont.size or 0) > 0 and countFont.size or autoSize
    local timerSize = (fontConfig.size or 0) > 0 and fontConfig.size or math.max(8, autoSize - 1)
    local colored = Get(prefix .. (unit and 'auraTimerColor' or 'timerColor'), false)
    for i, name in ipairs(auraIcons) do
        local b = c:Object('aura' .. i, 'Frame')
        b:SetPoint('TOPLEFT', (c.width - (unit and 2 * 42 + 30 or 2 * 66 + 46)) / 2 + (i - 1) * (unit and 42 or 66), -16)
        -- Use the production aura renderer, including its masks, timer placement and swipe textures.
        ns.AuraLook.Style(b, { preview = true, size = unit and 30 or 46, style = style, swipe = swipe, timer = timer,
            font = font, countFont = countFont, timerSize = timerSize })
        b.FlareUI_Icon:SetTexture('Interface\\Icons\\' .. name)
        b.FlareUI_Border:SetVertexColor(1, 1, 1)
        b.FlareUI_Count:SetText(i == 2 and '3' or '')
        b.FlareUI_Duration:SetAlpha(0)
        b.FlareUI_PreviewTimer:SetShown(timer ~= 'none')
        b.FlareUI_PreviewTimer:SetText(({ '9s', '24s', '1m' })[i])
        b.FlareUI_PreviewTimer:SetTextColor(1, colored and i == 1 and 0.2 or 1, colored and i == 1 and 0.2 or 1)
        b.FlareUI_Cooldown:SetCooldown(GetTime() - i * 2, 12)
    end
    local arrive = Get('auras.arrive')
    local elapsed = 0
    c:Animate(function(_, dt)
        elapsed = elapsed + dt
        if spec.key == 'au.arrive' and arrive then
            local progress = math.min(1, (elapsed % 4) * 2)
            c.objects.aura3:SetAlpha(progress)
            c.objects.aura3:ClearAllPoints(); c.objects.aura3:SetPoint('TOPLEFT', (c.width - (2 * 66 + 46)) / 2 + 2 * 66, -16 + (1 - progress) * 12)
        end
        for i = 1, 3 do c.objects['aura' .. i].FlareUI_PreviewTimer:SetText(math.max(1, math.ceil(12 - ((elapsed + i * 2) % 12))) .. 's') end
        if elapsed < 12 then return end
        elapsed = 0
        for i = 1, 3 do c.objects['aura' .. i].FlareUI_Cooldown:SetCooldown(GetTime() - i * 2, 12) end
    end)
    Note(c)
end
function R.auras(c, spec) Auras(c, false, spec) end
function R.unitAuras(c, spec) Auras(c, true, spec) end

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
    if Get('chat.classIcons') then sampleName = '|TInterface\\Icons\\ClassIcon_Mage:12|t ' .. sampleName end
    if Get('chat.raceIcons') then sampleName = '|TInterface\\CHARACTERFRAME\\TEMPORARYPORTRAIT-MALE-SCOURGE:12|t ' .. sampleName end
    local colon = Get('chat.nameColon') and ': ' or ' '
    for i, line in ipairs({ '|cff40ff40' .. stamp .. channel .. sampleName .. colon .. L["Ready?"] .. '|r',
        '|cff40ff40' .. stamp .. channel .. '[Aeloria]: ' .. L["Ready!"] .. '|r',
        '|cffffd100' .. (Get('chat.formatNPC') and L["Innkeeper"] .. ': ' or L["Innkeeper says: "]) .. L["Welcome!"] .. '|r' }) do
        if i * spacing <= height - 54 then
            local t = c:Text('chatLine' .. i, line, 12, top + 30 + (i - 1) * spacing, c.width - 24, Font('chat.chatFont'))
            t:SetWordWrap(false)
        end
    end
    if spec.key == 'ch.linkIcons' then c.objects.chatLine1:SetText((Get('chat.linkIcons') and '|TInterface\\Icons\\Spell_Frost_FrostBolt02:12|t ' or '') .. '|cff71d5ff[' .. L["Frostbolt"] .. ']|r') end
    if spec.key == 'ch.whisperMarkers' then c.objects.chatLine1:SetText((Get('chat.whisperMarkers') and '|cff40ff40> |r' or '') .. '|cffff80ff[Aeloria]: ' .. L["Ready?"] .. '|r') end
    local position = Get('chat.editBoxPosition', 'inside')
    local editY = position == 'above' and top - 27 or position == 'below' and top + height + 4 or top + height - 24
    c:Box('editBox', 8, editY, c.width - 16, 23, 'FlareUI Thin', Get('chat.editBoxOpacity', 1))
    c:Text('editText', L["Say:"] .. ' ...', 14, editY + 5, c.width - 28, Font('chat.editBoxFont'))
    c.objects.editText:SetWordWrap(false)
    local buttonX = 12
    for i, def in ipairs({ { 'chat.socialHide', 'ChatSocial', true }, { 'chat.channelHide', 'ChatChannels', true },
        { 'chat.menuHide', 'ChatOptions', true }, { 'chat.showVolume', 'Volume-Speaker-High', false } }) do
        if Get(def[1], not def[3]) ~= def[3] then
            c:Texture('chatHeader' .. i, P.MEDIA .. 'Icons\\' .. def[2], buttonX, 13, 18, 18)
            buttonX = buttonX + 24
        end
    end
    if Get('chat.copyButton') then c:Text('copyButton', L["Copy"], c.width - 49, 13, 45, { size = 10 }) end
    if not Get('chat.hideCombatLog', false) and spec.key == 'ch.combatLog' then c:Text('combatTab', L["Combat Log"], 85, top + 8, c.width - 97, Font('chat.tabFont')) end
    if spec.key == 'ch.minAlpha' then c.frame:SetAlpha(Get('chat.minAlpha', 0)) end
    Note(c)
end

function R.tooltip(c, spec)
    local outer = c
    if not outer.tooltipCanvas then
        outer.tooltipCanvas = P.Create(outer.frame, outer.width, outer.height)
        outer.objects.tooltipCanvasFrame = outer.tooltipCanvas.frame
    end
    c = outer.tooltipCanvas
    c:Reset()
    local scale = spec.key == 'tt.scale' and Get('tooltips.scale', 1) / 1.5 or 1
    c.frame:SetScale(scale)
    c.frame:ClearAllPoints(); c.frame:SetPoint('TOPLEFT', (outer.width - c.width * scale) / 2, 0); c.frame:Show()
    local item = spec.key == 'tt.shortItemStats' or spec.key == 'tt.ids' or spec.key == 'tt.compareShift'
    local box = c:Object('tooltip', 'Frame', 'BackdropTemplate')
    box:SetPoint('TOPLEFT', 8, -8); box:SetSize(c.width - 16, 182)
    box:SetBackdrop({ bgFile = 'Interface\\Buttons\\WHITE8X8', edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border', edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    box:SetBackdropColor(0.05, 0.05, 0.06, 0.9)
    box:SetBackdropBorderColor(0.8, 0.6, 0.34, 1)
    if Get('tooltips.borderByClass') or Get('tooltips.borderByQuality') then box:SetBackdropBorderColor((item and 0.64 or 0.41) * 0.85, (item and 0.21 or 0.8) * 0.85, (item and 0.93 or 0.94) * 0.85, 1) end
    local layout = NineSliceUtil and NineSliceUtil.GetLayout('TooltipDefaultLayout')
    if layout then
        -- Use the client's tooltip art, as the production tooltip module does. The backdrop above
        -- is only for clients without this layout, not a replacement for their native NineSlice.
        box:SetBackdrop(nil)
        NineSliceUtil.ApplyLayout(box, layout)
        local r, g, b = 0.8, 0.6, 0.34
        if Get(item and 'tooltips.borderByQuality' or 'tooltips.borderByClass') then
            r, g, b = (item and 0.64 or 0.41) * 0.85, (item and 0.21 or 0.8) * 0.85, (item and 0.93 or 0.94) * 0.85
        end
        for _, name in ipairs({ 'TopLeftCorner', 'TopRightCorner', 'BottomLeftCorner', 'BottomRightCorner', 'TopEdge', 'BottomEdge', 'LeftEdge', 'RightEdge' }) do
            if box[name] then box[name]:SetVertexColor(r, g, b, 1) end
        end
        if box.Center then box.Center:SetVertexColor(0.05, 0.05, 0.06, 0.9) end
    end
    c:Text('tooltipTitle', item and '|cffa335ee' .. L["Robes of the Archmage"] .. '|r' or (Get('tooltips.nameColor') == 'class' and '|cff69ccf0Aeloria|r' or 'Aeloria'), 16, 18, c.width - 32, Font('tooltips.titleFont')):SetWordWrap(false)
    local lines = {}
    if item then
        lines = { L["Binds when picked up"], L["Chest"] .. ' · ' .. L["Cloth"], '96 ' .. L["Armor"],
            Get('tooltips.shortItemStats') and '+12 ' .. L["Intellect"] or L["Increases Intellect by 12."],
            '+10 ' .. L["Stamina"], L["Requires Level 57"], '|cff1eff00' .. L["Increases spell damage by 40."] .. '|r' }
        if Get('tooltips.showItemID') then lines[#lines + 1] = 'ID: 14152' end
    else
        if Get('tooltips.showGuild') then lines[#lines + 1] = '<Dawnwatch>' .. (Get('tooltips.showGuildRank') and ' · ' .. L["Member"] or '') end
        lines[#lines + 1] = L["Level 60 Mage"]
        -- in the faction's colour, as the tooltip shows it
        if not Get('tooltips.hideFaction') then lines[#lines + 1] = '|cffff3333' .. L["Horde"] .. '|r' end
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
    box:SetHeight(bottom + (not item and not Get('tooltips.hideHealthBar') and 22 or 4))
    if not item and not Get('tooltips.hideHealthBar') then
        -- the bar runs the tooltip's whole width, its empty part dark
        c:Bar('tooltipHealthBack', 11, bottom, c.width - 22, 12, 1, { 0.12, 0.12, 0.12 })
        c:Bar('tooltipHealth', 11, bottom, c.width - 22, 12, 0.8, ns.HEALTH_GREEN):SetFrameLevel(c.frame:GetFrameLevel() + 3)
        c:Text('tooltipHealthText', '3,840 / 4,800', 16, bottom, c.width - 32, { size = 9 })
    end
    -- Compare with Shift: the item and the one equipped, side by side, whichever way it is set
    if spec.key == 'tt.compareShift' then
        c.frame:SetScale(0.6)
        c.frame:ClearAllPoints(); c.frame:SetPoint('TOPLEFT', 0, 0)
        local x, w = outer.width * 0.6 - 2, outer.width * 0.4 - 4
        local box2 = outer:Object('comparison', 'Frame', 'BackdropTemplate')
        box2:SetPoint('TOPLEFT', x, -5); box2:SetSize(w, 70)
        box2:SetFrameLevel(outer.frame:GetFrameLevel() + 5)
        local layout = NineSliceUtil and NineSliceUtil.GetLayout('TooltipDefaultLayout')
        if layout then
            NineSliceUtil.ApplyLayout(box2, layout)
            for _, name in ipairs({ 'TopLeftCorner', 'TopRightCorner', 'BottomLeftCorner', 'BottomRightCorner', 'TopEdge', 'BottomEdge', 'LeftEdge', 'RightEdge' }) do
                if box2[name] then box2[name]:SetVertexColor(0.8, 0.6, 0.34, 1) end
            end
            if box2.Center then box2.Center:SetVertexColor(0.05, 0.05, 0.06, 0.9) end
        end
        outer:Text('comparisonText', '|cff999999' .. L["Equipped"] .. '|r\n|cff1eff00' .. L["Cloth"] .. '|r\n+8 ' .. L["Intellect"], x + 7, 12, w - 14, { size = 9 })
    end
    Note(outer)
end

function R.tracker(c, spec)
    local colors = ns.ObjectiveTracker.SampleColors
    c:Box('trackerBox', 4, 12, c.width - 8, 184, Get('objectivetracker.borderTexture'), Get('objectivetracker.opacity', 0.5))
    c:Text('trackerTitle', L["Quests"] .. (Get('objectivetracker.showCount') and ' (2)' or ''), 12, 22, c.width - 24, Font('objectivetracker.headerFont')):SetTextColor(unpack(colors.TITLE))
    if spec.key == 'qt.minimizeButton' then
        c.objects.trackerBox:SetHeight(35)
        c.objects.trackerTitle:SetText(Get('objectivetracker.minimizeStyle') == 'button' and '+' or L["Quests"])
        Note(c, L["Minimized appearance"]); return
    end
    local y = 48
    if Get('objectivetracker.zoneHeaders') then c:Text('zone', L["Elwynn Forest"], 12, y, c.width - 24):SetTextColor(unpack(colors.ZONE)); y = y + 22 end
    for i, title in ipairs({ L["A Threat Within"], L["Kobold Camp Cleanup"] }) do
        local text = (Get('objectivetracker.hideLevel') and '' or '[5] ') .. title .. (Get('objectivetracker.showTags') and ' [G]' or '')
        local indent = 12
        if Get('objectivetracker.playButtons') then
            c:Texture('questVoice' .. i, P.MEDIA .. 'Previews\\Voice.tga', indent, y + 2, 10, 10, true)
            indent = indent + 13
        end
        if Get('objectivetracker.focusButtons') then
            c:Texture('questFocus' .. i, P.MEDIA .. 'Previews\\Focus.tga', indent, y + 2, 10, 10, true)
            indent = indent + 13
        end
        local t = c:Text('quest' .. i, text, indent, y, c.width - indent - 12, Font('objectivetracker.titleFont'))
        t:SetTextColor(unpack(i == 1 and colors.TITLE_FOCUS or Get('objectivetracker.colorNames') and {1,0.5,0.25} or colors.TITLE))
        t:SetWordWrap(Get('objectivetracker.wrapText', true)); t:SetMaxLines(2)
        local h = math.max(18, t:GetStringHeight())
        if y + h + (Font('objectivetracker.objectiveFont').size or 12) > 190 then t:Hide(); break end
        c:Text('objective' .. i, i == 1 and L["Speak to the Marshal"] or '4/8 ' .. L["Kobolds defeated"], 20, y + h, c.width - 32, Font('objectivetracker.objectiveFont')):SetWordWrap(false)
        c.objects['objective' .. i]:SetTextColor(unpack(colors.OBJECTIVE))
        y = y + h + 30
    end
    c.objects.trackerBox:SetHeight(math.min(184, y - 10))
    Note(c)
end

function R.meter(c, spec)
    c:Box('meterBox', 4, 25, c.width - 8, 151, Get('damagemeter.borderTexture'), Get('damagemeter.opacity', 0.5))
    local threat = spec.key:find('threat') or spec.key:find('pull') or spec.key == 'dm.tankLead'
    c:Text('meterTitle', threat and L["Threat"] or L["Damage"], 12, 34, c.width - 24, Font('damagemeter.headerFont'))
    for i, name in ipairs({ 'Flareui', 'Aeloria', 'Thorne' }) do
        local y = 61 + (i - 1) * 33
        c:Bar('meterBar' .. i, 10, y, c.width - 20, 27, 1 - (i - 1) * 0.22, ({ { 0.41, 0.8, 0.94 }, { 0.77, 0.12, 0.23 }, { 1, 0.49, 0.04 } })[i])
        local mode = Get('damagemeter.threatValueDisplay', 'both')
        local value = threat and (mode == 'percent' and '75%' or mode == 'value' and '12.5k' or '12.5k (75%)') or '12.5k'
        if threat and i == 1 and Get('damagemeter.threatTankLead') then value = value:gsub('75%%', '+25%%') end
        c:Text('meterName' .. i, name .. '  ' .. value, 15, y + 6, c.width - 30, Font('damagemeter.barFont')):SetWordWrap(false)
    end
    if threat and Get('damagemeter.threatPullLine') then
        local line = c:Texture('pullLine', 'Interface\\Buttons\\WHITE8X8', c.width - 42, 60, 2, 94)
        line:SetVertexColor(1, 0.2, 0.1)
    end
    if spec.key == 'dm.pullFlash' and Get('damagemeter.threatPullFlash') then
        local flash = c:Texture('pullFlash', 'Interface\\Buttons\\WHITE8X8', 10, 61, c.width - 20, 27, true)
        flash:SetDrawLayer('OVERLAY', 6); flash:SetVertexColor(1, 0.15, 0.1); flash:SetBlendMode('ADD')
        local elapsed = 0
        c:Animate(function(_, dt)
            elapsed = elapsed + dt
            flash:SetAlpha(0.55 * math.abs(math.sin(elapsed * math.pi / 0.8)))
        end)
    end
    if threat and Get('damagemeter.threatTankLead') then c:Text('tankLead', L["Tank lead"] .. ': +25%', 12, 178, c.width - 24, { size = 10 }) end
    if spec.key == 'dm.chatTab' and Get('damagemeter.chatTab') then c:Text('meterChatTab', L["General"] .. '  |cffffd100' .. L["Damage"] .. '|r', 12, 7) end
    if Get('damagemeter.combatTimer') then c:Text('combatTime', '01:24', c.width - 52, 34, 46, { size = 10 }) end
    if Get('damagemeter.readyCheckButton') then c:Texture('readyCheck', P.MEDIA .. 'Icons\\DMReadyCheck', 151, 8, 18, 18) end
    if Get('damagemeter.countdownButton') then c:Texture('countdown', P.MEDIA .. 'Icons\\DMCountdown', 176, 8, 18, 18) end
    if spec.key == 'dm.minAlpha' then c.frame:SetAlpha(Get('damagemeter.minAlpha', 0)) end
    Note(c)
end

-- Action Bars (11-10 Marcus): a few real buttons, as FlareUI styles them, and an empty slot (Show
-- Button Art shows there). Status Colouring: out of range and out of mana; Dim on Cooldown; the proc glow.
local ACTION_ICONS = { 'Spell_Frost_FrostBolt02', 'Spell_Fire_FireBolt02', 'Spell_Holy_Heal', 'Spell_Nature_Lightning' }
function R.actions(c, spec)
    local AB = ns.ActionBars
    if not (AB and AB.CreateSampleButton) then return end
    Sample(c, 'actionRow', function(parent)
        local box = CreateFrame('Frame', nil, parent)
        box.buttons = {}
        for i = 1, 5 do box.buttons[#box.buttons + 1] = AB.CreateSampleButton(box, i) end
        if #box.buttons < 5 then return nil end
        return box
    end, function(box)
        local gap, size = 6, 45
        for i, b in ipairs(box.buttons) do
            local icon = ACTION_ICONS[i] and ('Interface\\Icons\\' .. ACTION_ICONS[i]) or nil
            local w = AB.DrawSampleButton(b, icon, L["Spell"])
            size = w or size
            b:ClearAllPoints()
            b:SetPoint('TOPLEFT', box, 'TOPLEFT', 8 + (i - 1) * (size + gap), -8)
            if b.cooldown then b.cooldown:Clear() end
        end
        local range = Get('actionbars.colors.enableRange')
        -- the second on cooldown (dimmed with Dim on Cooldown), the third out of range, the fourth out of mana
        local cd = box.buttons[2]
        if cd.cooldown then cd.cooldown:SetCooldown(GetTime() - 4, 12) end
        if Get('actionbars.dimOnCooldown') then cd.icon:SetDesaturated(true); cd.icon:SetVertexColor(0.5, 0.5, 0.5) end
        if range then
            box.buttons[3].icon:SetVertexColor(1, 0.25, 0.25)
            box.buttons[4].icon:SetVertexColor(0.35, 0.45, 1)
        end
        -- Proc Glow on the first
        local first = box.buttons[1]
        if Get('actionbars.procGlow') then
            if not box.glow then box.glow = CreateFrame('Frame', nil, first, 'ActionButtonSpellAlertTemplate') end
            local glow = box.glow
            glow:ClearAllPoints()
            glow:SetPoint('CENTER', first, 'CENTER')
            glow:SetSize(size * 1.4, size * 1.4)
            glow:Show()
            if glow.ProcLoop then glow.ProcLoop:Play() end
        elseif box.glow then
            if box.glow.ProcLoop then box.glow.ProcLoop:Stop() end
            box.glow:Hide()
        end
        box:SetSize(16 + 5 * size + 4 * gap, size + 16)
        return box:GetSize()
    end, 4)
end

-- the real XP bar (Edit Mode sample values)
function R.xp(c)
    local XPB = ns.XPBar
    if XPB and XPB.CreateSample then Sample(c, 'xpSample', XPB.CreateSample, XPB.DrawSample, 14) end
end

function R.resources(c, spec)
    local key = spec.key:match('^rb%.(.+)$') or 'health'
    if key == 'overview' then key = 'health' end
    local RB = ns.ResourceBars
    if not (RB and RB.CreateSample) then return end
    Sample(c, 'rb:' .. key, function(parent) return RB.CreateSample(parent, key) end, RB.DrawSample, 4)
end

function R.bags(c)
    c:Box('bagsPanel', 3, 8, c.width - 6, c.height - 16, 'FlareUI Frames', 0.95)
    c:Text('heading', L["Bags"], 13, 17, c.width - 26)
    c:Text('bagMoney', '|cffffd56b128g  42s  16c|r', c.width - 110, c.height - 28, 100, { size = 9 })
    local columns = Get('tweaks.bagColumns', 0); if columns == 0 then columns = 10 end
    local groupGap = Get('tweaks.bagGaps') and 9 or 0
    local gap = 2
    local extras = (Get('tweaks.bagKeyring') and 1 or 0) + (Get('tweaks.bagReagent') and 1 or 0)
    local available = c.height - 45 - 40 - extras * 25 - (Get('tweaks.bagButtons') and 24 or 0)
    local scale = math.min(1, (c.width - 16) / (columns * 32 + (columns - 1) * gap), available / (100 + groupGap))
    groupGap = groupGap * scale
    local size = 32 * scale
    gap = gap * scale
    for i = 1, columns * 3 do
        local x, y = 8 + ((i - 1) % columns) * (size + gap), 45 + math.floor((i - 1) / columns) * (size + gap) + (i > columns and groupGap or 0)
        Icon(c, 'bagItem' .. i, ({ 'INV_Potion_54', 'INV_Misc_Bag_08', 'INV_Sword_04', 'INV_Misc_LeatherScrap_01' })[(i - 1) % 4 + 1], x, y, size)
        local border = c:Box('bagBorder' .. i, x, y, size, size, Get('tweaks.bagThickBorders') and 'FlareUI Thick' or 'FlareUI Thin', 0)
        local thick = Get('tweaks.bagThickBorders')
        local outset = (thick and 2 or 3) * scale
        border:ClearAllPoints(); border:SetPoint('TOPLEFT', x - outset, -(y - outset)); border:SetSize(size + 2 * outset, size + 2 * outset)
        border:SetBackdrop({ edgeFile = LibStub('LibSharedMedia-3.0'):Fetch('border', thick and 'FlareUI Thick' or 'FlareUI Thin'), edgeSize = (thick and 16 or 8) * scale })
        border:SetFrameLevel(c.overlay:GetFrameLevel() + 1)
        if Get('tweaks.bagRarityBorders') then border:SetBackdropBorderColor(i % 2 == 0 and 0.1 or 0.64, i % 2 == 0 and 1 or 0.21, i % 2 == 0 and 0.1 or 0.93, 1) end
        if i == 4 and Get('tweaks.petFood') then
            c:Texture('petFood', P.MEDIA .. 'Previews\\Focus.tga', x, y, size * 0.45, size * 0.45, true)
        end
        if i == 3 then c:Text('bagStack', '5', x + size * 0.55, y + size * 0.5, size * 0.45, { size = math.max(8, size * 0.4) }) end
        if i == 1 and Get('tweaks.bagJunkIcon') then c:Texture('junk', P.MEDIA .. 'Previews\\Coin.tga', x, y, size * 0.5, size * 0.5, true) end
        if i == 2 and Get('tweaks.bagUpgradeArrow') then c:Texture('upgrade', P.MEDIA .. 'Previews\\Upgrade.tga', x + size * 0.5, y + size * 0.5, size * 0.5, size * 0.5, true) end
    end
    local extraY = 45 + 3 * size + 2 * gap + groupGap + 7
    for _, group in ipairs({{'tweaks.bagKeyring', L["Keyring"], 'INV_Misc_Key_01'}, {'tweaks.bagReagent', L["Crafting Bag"], 'INV_Fabric_Linen_01'}}) do
        if Get(group[1]) then
            c:Text(group[1] .. 'Title', group[2], 8, extraY, 100, {size=9})
            for i=1,4 do Icon(c,group[1]..i,group[3],100+(i-1)*24,extraY-3,20) end
            extraY = extraY + 25
        end
    end
    if Get('tweaks.bagButtons') then
        for i = 1, 4 do Icon(c, 'bagButton' .. i, 'INV_Misc_Bag_08', 12 + (i - 1) * 24, extraY, 20) end
    end
    Note(c)
end

function R.nameplate(c, spec)
    Heading(c, L["Nameplates"])
    if spec.key == 'qol.npCombat' and not Get('tweaks.combatPlates') then
        c:Text('combatExample', L["In combat: enemy nameplates hidden"], 16, 90, c.width - 32); return
    elseif spec.key == 'qol.npCombat' then
        c:Text('combatExample', L["In combat: enemy nameplates visible"], 16, 158, c.width - 32)
    end
    if not Get('tweaks.nameplateHideNames') then c:Text('nameplateName', (Get('tweaks.nameplateHideLevel') and Get('tweaks.nameplateLevelName') and '12 ' or '') .. L["Forest Spider"], 22, 69) end
    c:Bar('nameplate', 16, 94, c.width - 32, 17, 0.72, { 0.8, 0.15, 0.12 })
    if not Get('tweaks.nameplateHideLevel') then c:Text('nameplateLevel', '12', c.width - 35, 96, 30) end
    if Get('tweaks.nameplateQuest') then
        local badge = Atlas(c, 'questBadge', 'QuestNormal', c.width - 17, 92, 15, 19)
        if not C_Texture.GetAtlasInfo('QuestNormal') then badge:SetTexture('Interface\\GossipFrame\\AvailableQuestIcon') end
    end
    if Get('tweaks.nameplateCombo') then
        for i = 1, 5 do
            local p = c.objects['plateCombo' .. i]
            if not p then p = ns.CreateComboPoint(c.frame, i, 14, false); c.objects['plateCombo' .. i] = p end
            p:ClearAllPoints(); p:SetPoint('TOPLEFT', (c.width - 110) / 2 + (i - 1) * 24, -121); ns.SetComboPoint(p, 3, false); p:Show()
        end
    end
    if spec.key == 'qol.npQuest' then
        c:Text('questObjective', L["Quest objective"] .. ': 4/8', 16, 158, c.width - 32, { size = 11 })
    elseif spec.key == 'qol.npCombo' then
        c:Text('comboLabel', L["Combo Points"] .. ': ' .. (Get('tweaks.nameplateCombo') and '3/5' or L["Hidden"]), 16, 158, c.width - 32, { size = 11 })
    end
    Note(c)
end

function R.radial(c, spec)
    local size = math.min(c.width - 24, c.height - 48) * math.min(1.5, Get('radialmenu.scale', 1)) / 1.5
    local x = (c.width - size) / 2
    c:Texture('wheelBackground', P.MEDIA .. 'Previews\\Wheel.tga', x, 12, size, size)
    local sector = c:Texture('wheelSector', P.MEDIA .. 'Previews\\Sector.tga', x, 12, size, size)
    c:Texture('wheelHub', P.MEDIA .. 'Radial\\Ring.tga', c.width / 2 - size * 0.09, 12 + size * 0.41, size * 0.18, size * 0.18)
    for i, name in ipairs({ 'Spell_Frost_FrostBolt02', 'Spell_Holy_Heal', 'INV_Misc_Bag_08', 'Ability_Mount_RidingHorse' }) do
        local a = (i - 1) * math.pi / 2
        local s = size * 0.17
        local px, py = c.width / 2 + math.sin(a) * size * 0.30 - s / 2, 12 + size / 2 - math.cos(a) * size * 0.30 - s / 2
        local icon = Icon(c, 'radialIcon' .. i, name, px, py, s)
        Round(c, 'radial' .. i, icon)
        c:Texture('radialRim' .. i, P.MEDIA .. 'Previews\\Ring.tga', px - 2, py - 2, s + 4, s + 4, true)
    end
    local names = { L["Frostbolt"], L["Heal"], L["Bags"], L["Mount"] }
    local showNames = Get('radialmenu.showNames', true)
    if showNames then c:Text('radialName', names[1], 12, size + 15, c.width - 24, { size = 10 }):SetJustifyH('CENTER') end
    local pointer = c:Texture('wheelPointer', P.MEDIA .. 'Previews\\Cursor.tga', c.width / 2, 12 + size / 2, 20, 24, true)
    local elapsed = 0
    c:Animate(function(_, dt)
        elapsed = elapsed + dt
        local phase = (elapsed / 1.6) % 4
        local selected = math.floor(phase) + 1
        local blend = math.min(1, (phase % 1) / 0.35)
        blend = blend * blend * (3 - 2 * blend)
        local angle = (math.floor(phase) - 1 + blend) * math.pi / 2
        pointer:ClearAllPoints(); pointer:SetPoint('TOPLEFT', c.width / 2 + math.sin(angle) * size * 0.19 - 5, -(12 + size / 2 - math.cos(angle) * size * 0.19 - 7))
        sector:SetRotation(-angle)
        for i = 1, 4 do c.objects['radialRim' .. i]:SetVertexColor(1, i == selected and 0.8 or 1, i == selected and 0.3 or 1) end
        if showNames then c.objects.radialName:SetText(names[selected]) end
    end)
    Note(c)
end

-- a font setting: one line in that font, in a FlareUI border (11-10, Marcus)
function R.font(c, spec)
    local cfg = Font(spec.font)
    local text = c:Text('fontSample', L["The quick brown fox jumps over the lazy dog"], 16, 16, c.width - 32, cfg)
    text:SetJustifyH('CENTER')
    c:Box('fontBox', 4, 4, c.width - 8, text:GetStringHeight() + 24, 'FlareUI Thin', 0.9)
    c.used = text:GetStringHeight() + 32
end


-- Examples for the 5.1 visual additions; no protected actions or live settings are used.
function R.reminders(c, spec)
    Heading(c, L["Buff Reminders"])
    if spec.key == 'au.reminders' and not Get('auras.reminders') then
        c:Text('remindersOff', L["Disabled"], 12, 90); return
    end
    -- pets and the blessing are picked in the icon's right-click menu now, so a pet always shows
    local names = {'Spell_Holy_WordFortitude', 'Spell_Holy_MagicalSentry', 'Ability_Hunter_BeastCall'}
    if Get('auras.reminder.consumables', 'off') ~= 'off' then names[#names+1]='INV_Potion_41' end
    if Get('auras.reminder.camping', false) then names[#names+1]='Spell_Fire_Fire' end
    if Get('auras.reminder.gathering', false) then names[#names+1]='INV_Misc_Flower_02' end
    -- as many as fit the picture
    for i = #names, math.max(1, math.floor((c.width - 12) / 48)) + 1, -1 do names[i] = nil end
    for i, name in ipairs(names) do
        local x=12+(i-1)*48
        Icon(c,'reminderIcon'..i,name,x,65,38)
        local glow=Get(i==2 and 'auras.reminder.glowExpiring' or 'auras.reminder.glowMissing',false)
        if glow then
            local edge=c:Box('reminderGlow'..i,x-2,63,42,42,'FlareUI Thin',0)
            edge:SetBackdropBorderColor(1,i==2 and 0.5 or 0.85,0.1,1)
        end
    end
    c:Text('reminderState', L["Missing"] .. ' / ' .. tostring(Get('auras.reminder.before',2)) .. ' min',12,114,c.width-24)
    c:Text('reminderGroup', ({self=L["Player"],party=L["Party"],all=L["Raid"]})[Get('auras.reminder.group','all')],12,140,c.width-24)
    local elapsed=0
    c:Animate(function(_,dt)
        elapsed=elapsed+dt
        for i=1,#names do local edge=c.objects['reminderGlow'..i]; if edge and edge:IsShown() then edge:SetAlpha(0.65+0.35*math.sin(elapsed*3)) end end
    end)
end

function R.lootFeed(c, spec)
    Heading(c,L["Loot Feed"])
    if spec.key == 'qol.lootFeed' and not Get('tweaks.lootFeed') then c:Text('feedOff',L["Disabled"],12,90); return end
    local atCursor=Get('tweaks.lootFeedPosition','cursor')=='cursor'
    local x=atCursor and 36 or 12
    if atCursor then c:Texture('feedCursor',P.MEDIA..'Previews\\Cursor.tga',8,98,24,32,true) end
    local entries={}
    local quality=Get('tweaks.lootFeedQuality',0)
    if quality<=1 then entries[#entries+1]={icon='INV_Fabric_Linen_01',text='|cffffffff'..L["Linen Cloth"]..' x2|r'} end
    if quality<=2 then entries[#entries+1]={icon='INV_Sword_04',text='|cff1eff00'..L["Sword"]..'|r'} end
    if quality>=3 then entries[#entries+1]={icon='INV_Chest_Cloth_25',text='|cffa335ee'..L["Robes of the Archmage"]..'|r'} end
    if Get('tweaks.lootFeedMoney',true) then entries[#entries+1]={icon='INV_Misc_Coin_01',text='12 |cffffd700'..L["Gold"]..'|r'} end
    -- Show Skill-Ups: the game's own name for Mining
    if Get('tweaks.lootFeedSkills') then entries[#entries+1]={icon='Trade_Mining',text='|cff73bfff'..((C_Spell.GetSpellName and C_Spell.GetSpellName(2575)) or 'Mining')..' 76|r'} end
    for i,e in ipairs(entries) do Icon(c,'feedIcon'..i,e.icon,x,65+i*28,20); c:Text('feedText'..i,e.text,x+25,68+i*28,c.width-x-30,{size=10}) end
    local elapsed=0
    c:Animate(function(_,dt)
        elapsed=(elapsed+dt)%3
        for i=1,#entries do
            local icon,text=c.objects['feedIcon'..i],c.objects['feedText'..i]
            icon:ClearAllPoints(); icon:SetPoint('TOPLEFT',x,-(65+i*28-elapsed*12))
            text:ClearAllPoints(); text:SetPoint('TOPLEFT',x+25,-(68+i*28-elapsed*12))
            local alpha=math.min(1,(3-elapsed)*2); icon:SetAlpha(alpha); text:SetAlpha(alpha)
        end
    end)
end

function R.mouseRing(c,spec)
    Heading(c,L["Mouse Ring"])
    c:Texture('mouseCursor',P.MEDIA..'Previews\\Cursor.tga',c.width/2-6,95,24,32,true)
    local mode=Get('tweaks.mouseRingShow','off')
    if mode=='off' and spec.key=='qol.mouseRingShow' then c:Text('mouseOff',L["Disabled"],12,155); return end
    local size=math.max(20,math.min(120,Get('tweaks.mouseRingSize',40)))
    local thick=Get('tweaks.mouseRingThickness',3)
    local color=Get('tweaks.mouseRingRange') and {1,0.15,0.1} or Get('tweaks.mouseRingClassColor') and {0.41,0.8,0.94} or {0.83,0.68,0.43}
    local function ring(id,diameter,thickness,tint)
        local t=c:Texture(id,'Interface\\CharacterFrame\\TempPortraitAlphaMask',(c.width-diameter)/2,105-diameter/2,diameter,diameter,true)
        t:SetVertexColor(unpack(tint))
        c.mouseMasks=c.mouseMasks or {}
        local hole=c.mouseMasks[id]
        if not hole then hole=c.frame:CreateMaskTexture(); hole:SetTexture(P.MEDIA..'Masks\\RingHole.tga','CLAMPTOWHITE','CLAMPTOWHITE'); t:AddMaskTexture(hole); c.mouseMasks[id]=hole end
        hole:ClearAllPoints(); hole:SetPoint('CENTER',t,'CENTER'); hole:SetSize(math.max(1,diameter-2*thickness)/0.93,math.max(1,diameter-2*thickness)/0.93)
        return t
    end
    ring('mouseRing',size,thick,color)
    local arcs={}
    for i,def in ipairs({{'Cast',{1,0.85,0.3}},{'GCD',{0.4,0.8,1}},{'Swing',{1,0.5,0.2}}}) do
        if Get('tweaks.mouseRing'..def[1]) then
            local tex=ring('mouseArc'..i,size+8*i,2,def[2])
            local mask=c.mouseMasks['arc'..i]
            if not mask then mask=c.frame:CreateMaskTexture(); mask:SetTexture(P.MEDIA..'Radial\\HalfMask.tga','CLAMPTOBLACKADDITIVE','CLAMPTOBLACKADDITIVE'); tex:AddMaskTexture(mask); c.mouseMasks['arc'..i]=mask end
            mask:SetAllPoints(tex); arcs[#arcs+1]=mask
        end
    end
    c:Text('mouseContext',mode=='combat' and L["In Combat"] or mode=='rightclick' and L["While Right-Clicking"] or L["Always"],12,180,c.width-24,{size=10})
    if Get('tweaks.mouseRingHideTurning') then c:Text('mouseTurning',L["Hidden while turning"],12,198,c.width-24,{size=9}) end
    local elapsed=0
    c:Animate(function(_,dt) elapsed=elapsed+dt; for i,mask in ipairs(arcs) do mask:SetRotation(elapsed*(i+1)) end end)
end

--------------------------------------------------
-- MODULES' OWN SAMPLES (11-11)
-- A module that builds its own sample (M.CreateSample(parent, kind) / M.DrawSample(f, kind), as the
-- unit frames, bars and action buttons do) is shown that way; until it does, its drawing above stays.
--------------------------------------------------
local function ModuleSample(c, mod, kind)
    local M = ns[mod]
    if not (M and M.CreateSample and M.DrawSample) then return nil end
    return Sample(c, mod .. ':' .. kind, function(parent) return M.CreateSample(parent, kind) end,
        function(f) return M.DrawSample(f, kind) end, 4)
end

local ITEM_TOOLTIP = { ['tt.shortItemStats'] = true, ['tt.ids'] = true }
local THREAT_KEYS = { ['dm.threatValue'] = true, ['dm.pullLine'] = true, ['dm.pullFlash'] = true, ['dm.tankLead'] = true, ['dm.threatOverview'] = true }
local OWN = {
    tooltip = { 'Tooltips', function(spec) return spec.key == 'tt.compareShift' and 'compare' or ITEM_TOOLTIP[spec.key] and 'item' or 'unit' end },
    reminders = { 'BuffReminders', function() return 'reminders' end },
    radial = { 'RadialMenu', function() return 'radial' end },
    bags = { 'Bags', function() return 'bags' end },
    tracker = { 'ObjectiveTracker', function(spec) return spec.key == 'qt.minimizeButton' and 'header' or 'full' end },
    chat = { 'Chat', function() return 'chat' end },
    meter = { 'DamageMeter', function(spec) return THREAT_KEYS[spec.key] and 'threat' or 'damage' end },
    nameplate = { 'Tweaks', function() return 'plate' end },
    -- the style cards keep their drawing (they show a style that may not be the one in use)
    -- a style card shows its own style
    minimap = { 'Minimap', function(spec, c)
        if c.isStyleCard or c.height < 120 then return spec.value == 'round' and 'round' or 'square' end
        return spec.key == 'mm.microMenu' and 'menu' or 'map'
    end },
}
for kind, own in pairs(OWN) do
    local drawn = R[kind]
    R[kind] = function(c, spec)
        local sampleKind = own[2](spec, c)
        if sampleKind and ModuleSample(c, own[1], sampleKind) then return end
        return drawn(c, spec)
    end
end
