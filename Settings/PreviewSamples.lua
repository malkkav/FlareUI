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

-- 11-10 pilot: the unit frames' own code draws the frame (UnitFrames' UF.CreateSample and DrawSample),
-- in the style given, scaled to width (and to maxHeight); centred unless x is given. Returns the
-- frame and the height it takes. (palette: the live one is the frames' own)
local function Unit(c, id, style, unit, y, width, palette, x, maxHeight)
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
    local e = UF.DrawSample(f, style)
    if not e or e.width <= 0 or e.height <= 0 then f:Hide() return nil, 0 end
    local k = width / e.width
    if maxHeight then k = math.min(k, maxHeight / e.height) end
    f:SetScale(k)
    local left = x or (c.width - e.width * k) / 2
    f:ClearAllPoints()
    f:SetPoint('TOPLEFT', c.frame, 'TOPLEFT', (left + e.left * k) / k, -(y + e.top * k) / k)
    return f, e.height * k
end

function R.unit(c, spec)
    local style = spec.key == 'uf.frameStyle' and spec.value or (ns.UFRing and ns.UFRing.Style() or 'addon')
    local palette = ns.UnitFrames.PALETTES[Get('unitframes.palette', 'flareui')] or ns.UnitFrames.PALETTES.flareui
    local card = c.height < 120
    local width = c.width - (card and 8 or 16)
    Unit(c, 'playerSample', style, 'player', card and 3 or 30, width, palette, nil, card and c.height - 6 or 80)
    if card then return end
    if spec.key == 'uf.overview' or spec.key == 'uf.frameStyle' or spec.key == 'uf.palette' then
        c:Text('playerLabel', L["Player"], 8, 8)
        local w = math.min(100, (c.width - 24) / 2)
        c:Text('petLabel', L["Pet"], 8, 115, w)
        c:Text('targetOfLabel', L["Target of Target"], c.width / 2 + 4, 115, w, { size = 9 })
        Unit(c, 'petOverview', (Get('unitframes.simplePet', true) or style == 'addon') and 'addon' or style, 'pet', 140, w, palette, 8)
        Unit(c, 'targetOfOverview', (Get('unitframes.simpleTargetOf', true) or style == 'addon') and 'addon' or style, 'targettarget', 140, w, palette, c.width / 2 + 4)
        Note(c); return
    end
    c:Text('playerLabel', L["Player"], 8, 8)
    local pet = spec.key == 'uf.simplePet'
    local small = pet or spec.key == 'uf.simpleTargetOf'
    c:Text('smallLabel', pet and L["Pet"] or small and L["Target of Target"] or L["Target"], 8, 110)
    local simple = small and (spec.value == true or style == 'addon')
    local companion = Unit(c, 'companionSample', simple and 'addon' or style, pet and 'pet' or small and 'targettarget' or 'target', 128, small and width * 0.5 or math.min(width, 170), palette)
    Note(c)
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
        local style = ns.UFRing and ns.UFRing.Style() or 'addon'
        local width = math.min(c.width - 24, 168)
        local unit = key == 'main' and 'player' or 'targettarget'
        if key ~= 'main' and Get('unitframes.simpleTargetOf', true) then style = 'addon' end
        Unit(c, 'cardUnit', style, unit, 3, width, palette)
    elseif key == 'castbar' then
        local width, height = math.min(180, c.width - 20), 24
        local x, y = (c.width - width) / 2, 24
        local icon = Icon(c, 'castIcon', 'Spell_Frost_FrostBolt02', x + 2, y + 2, 20)
        CardBorder(c, 'castIconBorder', x, y, 24, 24)
        local bx, bw = x + 28, width - 28
        CardBorder(c, 'castBorder', bx, y, bw, height)
        c:Bar('cast', bx + 4, y + 4, bw - 8, height - 8, 0.65, { 0.36, 0.56, 0.78 }, 'FlareUI Flat')
        c:Text('castLabel', L["Frostbolt"], bx + 8, y + 7, bw - 60, { size = 10, flags = 'OUTLINE' }):SetWordWrap(false)
        c:Text('castTime', '1.6 / 2.5', bx + bw - 51, y + 7, 43, { size = 9, flags = 'OUTLINE' }):SetJustifyH('RIGHT')
    else
        local raid, boss = key == 'raid', key == 'boss'
        local columns, rows = raid and 5 or 1, raid and 4 or boss and 3 or 4
        local width = raid and math.min(34, (c.width - 24) / 5 - 4) or math.min(158, c.width - 32)
        local height, gap = math.min(18, math.floor((c.height - 9) / 4)), 3
        local left = (c.width - columns * (width + gap) + gap) / 2
        local top = (c.height - (rows * height + (rows - 1) * gap)) / 2
        for i = 1, columns * rows do
            local x, y = left + ((i - 1) % columns) * (width + gap), top + math.floor((i - 1) / columns) * (height + gap)
            local color = boss and { 0.77, 0.23, 0.23 } or colors[(i - 1) % #colors + 1]
            CardBorder(c, 'groupBorder' .. i, x, y, width, height)
            c:Bar('groupHealth' .. i, x + 4, y + 4, width - 8, height - 9, 0.95 - (i % 4) * 0.12, color, 'FlareUI Flat')
            c:Bar('groupPower' .. i, x + 4, y + height - 5, width - 8, 1, 0.7, palette.mana, 'FlareUI Flat')
            if not raid then
                c:Text('groupName' .. i, (boss and L["Boss"] or L["Party"]) .. ' ' .. i, x + 7, y + 4, width - 14, { size = 8, flags = 'OUTLINE' }):SetWordWrap(false)
            end
        end
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
    Heading(c, unit and L["Player"] or L["Buffs & Debuffs"])
    if unit then
        local style = ns.UFRing and ns.UFRing.Style() or 'addon'
        local palette = ns.UnitFrames.PALETTES[Get('unitframes.palette', 'flareui')] or ns.UnitFrames.PALETTES.flareui
        Unit(c, 'auraPlayer', style, 'player', 30, math.min(190, c.width - 16), palette)
    end
    local prefix = unit and 'unitframes.' or 'auras.'
    local style = Get(prefix .. (unit and 'auraStyle' or 'style'), 'round')
    local timer = Get(prefix .. (unit and 'auraTimer' or 'timer'), 'below')
    local swipe = Get(prefix .. (unit and 'auraSwipe' or 'swipe'), 'border')
    local fontConfig = Font(prefix .. (unit and 'auraFont' or 'font'))
    local countConfig = Font(prefix .. (unit and 'auraCountFont' or 'countFont'))
    -- Unit aura fonts use 0 for Auto. Match AuraLook.ForUnit without seeding or
    -- modifying saved variables, and retain dropdown overrides in the copied config.
    local size = unit and 30 or 46
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
        b:SetPoint('TOPLEFT', unit and 48 + (i - 1) * 42 or 16 + (i - 1) * 66, unit and -115 or -65)
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
    if spec.key == 'ab.skinCDM' then
        c:Text('cdmTitle', L["Cooldown Manager"], 12, 136)
        c:Bar('cdmBar', 12, 160, c.width - 24, 18, 0.65, { 1, 0.5, 0.25 }, Get('auras.skinCDM') and 'FlareUI Flat' or 'Blizzard')
        if Get('auras.skinCDM') then c:Box('cdmBorder', 12, 160, c.width - 24, 18, 'FlareUI Thin', 0) end
    end
    local arrive = Get('auras.arrive')
    local elapsed = 0
    c:Animate(function(_, dt)
        elapsed = elapsed + dt
        if spec.key == 'au.arrive' and arrive then
            local progress = math.min(1, (elapsed % 4) * 2)
            c.objects.aura3:SetAlpha(progress)
            c.objects.aura3:ClearAllPoints(); c.objects.aura3:SetPoint('TOPLEFT', 148, -65 + (1 - progress) * 12)
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
    box:SetHeight(bottom + (not item and not Get('tooltips.hideHealthBar') and 22 or 4))
    if not item and not Get('tooltips.hideHealthBar') then
        c:Bar('tooltipHealth', 13, bottom, c.width - 26, 12, 0.8, ns.HEALTH_GREEN)
        c:Text('tooltipHealthText', '3,840 / 4,800', 20, bottom, c.width - 40, { size = 9 })
    end
    if spec.key == 'tt.compareShift' then
        c.frame:SetScale(0.72)
        c.frame:ClearAllPoints(); c.frame:SetPoint('TOPLEFT', 0, 0)
        local compare = Get('tooltips.compareShift', true)
        outer:Text('compareHint', compare and L["Hold Shift to compare"] or L["Comparison shown automatically"], 8, 186, outer.width - 16, { size = 10 })
        if not compare then
            outer:Box('comparison', outer.width * 0.58, 90, outer.width * 0.4, 72, 'FlareUI Thin', 1)
            outer:Text('comparisonText', L["Equipped"] .. '\n' .. L["Cloth"] .. '\n+8 ' .. L["Intellect"], outer.width * 0.58 + 5, 98, outer.width * 0.4 - 10, { size = 9 })
        end
    end
    local visibilityPath = ({ ['tt.showWorld'] = 'tooltips.visibility.worldUnits', ['tt.showFrames'] = 'tooltips.visibility.frameUnits', ['tt.showBars'] = 'tooltips.visibility.actionBars' })[spec.key]
    if visibilityPath then
        local mode = Get(visibilityPath, 'always')
        if mode == 'never' then c.frame:Hide() end
        outer:Text('visibilityExample', mode == 'never' and L["Tooltip hidden"] or mode == 'combat' and L["Out of combat: tooltip visible"] or L["Tooltip visible in and out of combat"], 8, 183, outer.width - 16, { size = 10 })
        if spec.key == 'tt.showBars' and mode ~= 'never' then
            c.objects.tooltipTitle:SetText(L["Frostbolt"])
            c.objects.tooltipText:SetText('60 ' .. L["Mana"] .. '\n2.5 ' .. L["Seconds"])
            c.objects.tooltip:SetHeight(90)
            if c.objects.tooltipHealth then c.objects.tooltipHealth:Hide(); c.objects.tooltipHealthText:Hide() end
        end
    end
    if spec.key == 'tt.anchor' then
        c:Text('cursor', '+', Get('tooltips.anchor') == 'cursorOffset' and 4 or c.width - 24, 184, 20)
        c:Text('anchorLabel', Get('tooltips.anchor') == 'cursorOffset' and L["At the cursor"] or L["Default position"], 24, 184, c.width - 48, { size = 10 })
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

function R.actions(outer, spec)
    Heading(outer, L["Action Bars"])
    if not outer.actionCanvas then
        outer.actionCanvas = P.Create(outer.frame, 400, 180)
        outer.objects.actionCanvasFrame = outer.actionCanvas.frame
    end
    local c = outer.actionCanvas
    c:Reset(); c.frame:Show()
    local scale = (outer.width - 8) / 400
    c.frame:SetScale(scale); c.frame:ClearAllPoints()
    c.frame:SetPoint('TOPLEFT', outer.frame, 'TOPLEFT', 4 / scale, -38 / scale)
    local behind = Get('actionbars.gryphonsBehind')
    if not Get('visibility.hideEndCaps') then
        local caps = c:Object('endCaps', 'Frame')
        caps:SetAllPoints(c.frame)
        caps:SetFrameLevel(c.frame:GetFrameLevel() + (behind and 0 or 30))
        if not caps.left then
            caps.left = caps:CreateTexture(nil, 'ARTWORK'); caps.right = caps:CreateTexture(nil, 'ARTWORK')
        end
        for i, t in ipairs({ caps.left, caps.right }) do
            local atlas = 'ui-hud-actionbar-gryphon-' .. (i == 1 and 'left' or 'right')
            local info = C_Texture.GetAtlasInfo(atlas)
            local height = 100
            if info then
                t:SetAtlas(atlas)
                height = math.min(130, 100 * info.height / info.width)
            else
                -- The legacy Dwarf texture is the gryphon; Human is a different lion end cap.
                t:SetTexture('Interface\\MainMenuBar\\UI-MainMenuBar-EndCap-Dwarf')
                t:SetTexCoord(i == 1 and 0 or 1, i == 1 and 1 or 0, 0, 1)
            end
            t:ClearAllPoints(); t:SetPoint('TOPLEFT', i == 1 and 0 or 300, -(150 - height)); t:SetSize(100, height)
        end
    end
    for i, name in ipairs({ 'Spell_Frost_FrostBolt02', 'Spell_Fire_FireBolt02', 'Spell_Holy_Heal', 'INV_Misc_QuestionMark' }) do
        local x, y, size = 87 + (i - 1) * 56, 90, 52
        local icon = c:Texture('action' .. i, 'Interface\\Icons\\' .. name, x, y, size, size, true)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        if i == 2 and Get('actionbars.dimOnCooldown') then icon:SetDesaturated(true); icon:SetVertexColor(0.45, 0.45, 0.45) end
        if i == 3 and Get('actionbars.colors.enableRange') then icon:SetVertexColor(1, 0.2, 0.2) end
        if Get('actionbars.buttonArt') then
            local border = c:Texture('actionBorder' .. i, nil, x - 2, y - 2, size + 4, size + 4, true)
            if C_Texture.GetAtlasInfo('UI-HUD-ActionBar-IconFrame') then border:SetAtlas('UI-HUD-ActionBar-IconFrame') end
        end
        if not Get('actionbars.hideHotkeys') then c:Text('hotkey' .. i, Get('actionbars.cleanKeybinds') and 'S-' .. i or 'SHIFT-' .. i, x, y, size, Font('actionbars.hotkeyFont')) end
        if not Get('actionbars.hideMacroText') then c:Text('macro' .. i, L["Spell"], x, y + 37, size, Font('actionbars.macroFont')) end
    end
    if Get('actionbars.procGlow') then
        local glow = c:Object('procGlow', 'Frame', 'ActionButtonSpellAlertTemplate')
        glow:SetPoint('TOPLEFT', 77, -80); glow:SetSize(72, 72)
        glow:SetFrameLevel(c.frame:GetFrameLevel() + 25)
        if glow.ProcStartAnim then glow.ProcStartAnim:Play() end
    end
    local mode = Get('actionbars.xpbar.textFormat', 'VALUES')
    outer:Bar('xp', 12, 167, outer.width - 24, 16, 0.65, { 0.55, 0.25, 0.8 }, Get('actionbars.xpbar.texture'))
    if Get('actionbars.xpbar.questXP') then
        local share = ({ done = 0.12, all = 0.30, zone = 0.19 })[Get('actionbars.xpbar.questXPMode', 'done')] or 0.12
        outer:Bar('questXp', 12 + (outer.width - 24) * 0.65, 167, (outer.width - 24) * share, 16, 1, { 0.8, 0.65, 0.2 })
    end
    outer:Text('xpText', ({ VALUES = '6,500 / 10,000', PERCENT = '65%', BOTH = '6,500 / 10,000 (65%)', REMAINING = '3,500' })[mode], 16, 169, outer.width - 32, { size = 10 })
    Note(outer)
end

function R.xp(c)
    Heading(c, L["Experience"])
    c:Bar('xp', 10, 85, c.width - 20, 22, 0.65, { 0.55, 0.25, 0.8 }, Get('actionbars.xpbar.texture'))
    local mode = Get('actionbars.xpbar.textFormat', 'VALUES')
    c:Text('xpText', ({ VALUES = '6,500 / 10,000', PERCENT = '65%', BOTH = '6,500 / 10,000 (65%)', REMAINING = '3,500' })[mode], 14, 90, c.width - 28)
    if Get('actionbars.xpbar.questXP') then c:Bar('questXp', c.width * 0.65, 85, 30, 22, 1, { 0.8, 0.65, 0.2 }) end
    Note(c)
end

function R.resources(c, spec)
    Heading(c, L["Resource Bars"])
    local key = spec.key:match('^rb%.(.+)$') or 'health'
    if key == 'overview' then key = 'health' end
    local db = Get('unitframes.resource.bars.' .. key, {})
    if key == 'combo' then
        for i = 1, 5 do
            local point = c.objects['comboPoint' .. i]
            if not point then point = ns.CreateComboPoint(c.frame, i, 22, false); c.objects['comboPoint' .. i] = point end
            point:ClearAllPoints(); point:SetPoint('TOPLEFT', 18 + (i - 1) * 38, -83)
            ns.SetComboPoint(point, 3, false); point:Show()
        end
    else
        local color = key == 'health' and ns.HEALTH_GREEN or key:find('swing') and { 0.86, 0.65, 0.39 } or ns.MANA_BLUE
        c:Bar('resource', 10, 85, c.width - 20, 24, 0.65, color, db.texture)
        c:Box('resourceBorder', 10, 85, c.width - 20, 24, db.border, 0)
        c:Text('resourceText', key:find('swing') and '1.8 / 2.6' or '65%', 16, 91, c.width - 32, Font('unitframes.resource.font'))
    end
    local enabled = Get('unitframes.resource.bars.' .. key .. '.enabled', true)
    if not enabled then c.frame:SetAlpha(0.4) end
    if key:find('swing') and enabled then
        local elapsed = 0
        local duration = key == 'swingMain' and 2.6 or key == 'swingOff' and 1.8 or 2.4
        c:Animate(function(_, dt)
            elapsed = (elapsed + dt) % duration
            c.objects.resource:SetValue(elapsed / duration)
            c.objects.resourceText:SetText(string.format('%.1f / %.1f', elapsed, duration))
        end)
    end
    Note(c)
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

function R.font(c, spec)
    local cfg = Font(spec.font)
    Heading(c, L["Font Preview"])
    c:Text('fontName', 'Flareui · Aeloria', 12, 53, c.width - 24, cfg)
    c:Text('fontNumbers', '12,345 / 20,000  65%', 12, 98, c.width - 24, cfg)
    c:Text('fontTime', '9s  24s  1m  12:30', 12, 143, c.width - 24, cfg)
    Note(c)
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
