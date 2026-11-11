local _, ns = ...
local L = ns.L

--------------------------------------------------
-- BUFFS & DEBUFFS
-- Replaces BuffFrame / DebuffFrame with two Edit Mode frames holding CustomAuraContainers: Blizzard
-- drives the auras (secret-safe), FlareUI draws the look. Also weapon enchants, private aura anchors
-- and the shared aura button look (ns.AuraLook). Stands aside in the Gamepad UI.
--------------------------------------------------

--------------------------------------------------
-- 1. MODULE REGISTRATION
--------------------------------------------------
ns.Auras = ns.Auras or {}
local AU = ns.Auras
ns.modules["Auras"] = AU

--------------------------------------------------
-- 2. UPVALUES
--------------------------------------------------
local _G = _G
local ipairs, pcall = ipairs, pcall
local math_ceil, math_min, math_max, math_floor = math.ceil, math.min, math.max, math.floor
local CreateFrame, InCombatLockdown = CreateFrame, InCombatLockdown
local LEM = LibStub("FlareEditMode")

local function GetDb()
    return ns.db and ns.db.profile and ns.db.profile.auras
end

--------------------------------------------------
-- 3. CONSTANTS
--------------------------------------------------
local MEDIA         = "Interface\\AddOns\\FlareUI\\Media\\Auras\\"
-- Square: the classic icon bevel; round: the radial menu's rim. Both grey art, tinted.
local SQUARE_BORDER = MEDIA .. "IconBorder"
local SQUARE_INSET  = 6 / 128     -- the icon starts this far in, under the bevel's inner line
local SQUARE_MASK   = MEDIA .. "IconMask"   -- the icon clipped to the bevel's 45 degree corners
-- bronze, lifted as the tint multiplies the grey art
local SQUARE_TINT   = { 0.72, 0.56, 0.38 }
local ROUND_BORDER  = "talents-node-circle-gray"
local ROUND_MASK    = "talents-node-circle-mask"
local ROUND_TINT    = { 0.72, 0.56, 0.38 }
-- Border swipe outlines: a swipe takes a file, not an atlas
local SWIPE_SQUARE  = MEDIA .. "BorderThick"         -- 5 px wider inward than the border art (thickened 11-09)
local SWIPE_ROUND   = MEDIA .. "BorderRoundThick"
local BORDER_SATURATION = 1.35   -- Border swipe: the tints a little richer
local SWIPE_DISC    = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local TEMPLATE      = "CustomAuraContainerTemplate"
local TIMER_SPACE   = 13      -- room for a timer below the icon
local SWIPE_ALPHA   = 0.7     -- Border swipe dimming
local ICON_SWIPE_ALPHA = 0.82 -- Icon swipe overlay darkness
local SWIPE_EDGE_SCALE = 1.6
local SWIPE_EDGE    = MEDIA .. "Edge"
local PRIVATE_COUNT = 4       -- private aura anchors beside the debuffs

-- The keys of Blizzard's dispel colour maps ("None" = no dispel type)
local DISPEL_KEYS = { "None", "Magic", "Curse", "Disease", "Poison", "Bleed", "Enrage" }
-- Debuff borders by dispel type (bright, as they multiply the grey art)
local DEBUFF_COLORS = {
    None    = { 0.95, 0.32, 0.28 },
    Magic   = { 0.38, 0.65, 1.00 },
    Curse   = { 0.76, 0.42, 1.00 },
    Disease = { 0.92, 0.70, 0.30 },
    Poison  = { 0.45, 0.85, 0.38 },
}

-- Edit Mode preview samples
local PREVIEW_ICONS = {
    buffs = { "Spell_Holy_WordFortitude", "Spell_Nature_Regeneration", "Spell_Holy_MagicalSentry",
              "Ability_Warrior_BattleShout", "Spell_Holy_GreaterBlessingofKings", "Spell_Nature_Rejuvenation",
              "Spell_Holy_Renew", "Spell_Frost_FrostArmor02", "Spell_Nature_Lightning" },
    debuffs = { "Spell_Shadow_ShadowWordPain", "Spell_Shadow_CurseOfTounges", "Spell_Nature_NullifyDisease",
                "Spell_Nature_CorrosiveBreath", "Ability_Gouge", "Ability_Rogue_Rupture", "Spell_Fire_Immolation" },
}
local PREVIEW_DEBUFF_TYPES = { "Magic", "Curse", "Disease", "Poison", "None" }
local PREVIEW_TIMES = { "5m", "32s", "1h", "12s", "2m", "45m", "8s" }

local KINDS = {
    buffs   = { label = L["FlareUI Buffs"],   isDebuff = false,
                default = { point = "TOPRIGHT", x = -260, y = -4 } },
    debuffs = { label = L["FlareUI Debuffs"], isDebuff = true,
                default = { point = "TOPRIGHT", x = -260, y = -166 } },
}
local KIND_ORDER = { "buffs", "debuffs" }

--------------------------------------------------
-- 4. STATE
--------------------------------------------------
local frames = {}           -- kind -> holder (the Edit Mode frame)
local pendingLayout = false
local UpdatePreview         -- section 6
local hiddenParent = CreateFrame("Frame", nil, UIParent)
hiddenParent:Hide()

local function KindDb(kind)
    local db = GetDb()
    return db and db[kind]
end

-- Blizzard applies the map with SetVertexColor(color:GetRGBA()); four maps, cached
local colorMaps = {}
local function ColorMap(isDebuff, round, saturate)
    local cacheKey = (isDebuff and "d" or "b") .. (round and "r" or "s") .. (saturate and "+" or "")
    local map = colorMaps[cacheKey]
    if map then return map end
    map = {}
    for _, key in ipairs(DISPEL_KEYS) do
        local c = isDebuff and (DEBUFF_COLORS[key] or DEBUFF_COLORS.None) or (round and ROUND_TINT or SQUARE_TINT)
        local r, g, b = c[1], c[2], c[3]
        if saturate then
            -- away from the grey of the same brightness
            local l = 0.3 * r + 0.59 * g + 0.11 * b
            r = math_min(1, math_max(0, l + (r - l) * BORDER_SATURATION))
            g = math_min(1, math_max(0, l + (g - l) * BORDER_SATURATION))
            b = math_min(1, math_max(0, l + (b - l) * BORDER_SATURATION))
        end
        map[key] = CreateColor(r, g, b, 1)
    end
    colorMaps[cacheKey] = map
    return map
end

-- Icon height plus the timer's room when it sits below
local function CellHeight(size)
    local db = GetDb()
    return size + ((db and db.timer == "below") and TIMER_SPACE or 0)
end

--------------------------------------------------
-- 5. AURA BUTTONS
-- Blizzard calls initializeFrame for every pooled button: the look is built once, restyled later
--------------------------------------------------
-- Blizzard's Edit Mode sample auras have no duration: a sample timer stands in for the timer text
local SAMPLE_TIMERS = { "9s", "24s", "1m", "3s", "45s", "2m", "17s", "6s" }
local styledButtons = setmetatable({}, { __mode = "k" })

-- The sample icons, with their timers where Timer puts them: in Edit Mode, and on this module's
-- settings page. Out of combat only: the real icons' container can't be shown again in a fight
local previewWanted, settingsPreview = false, false
local function Previewing() return ns.EditPreviewing() or settingsPreview end

local function ApplyPreviewTimerNow(button)
    local text, preview = button.FlareUI_Duration, button.FlareUI_PreviewTimer
    if not (text and preview) then return end
    local on = Previewing() and button.FlareUI_TimerShown
    preview:SetShown(on and true or false)
    text:SetAlpha((button.FlareUI_TimerShown and not on) and 1 or 0)
end

-- Blizzard locks its aura buttons against addon code while auras are secret (combat, instances:
-- DenyTaintedAccessWhenAurasAreSecret), and every call on them then errors. A locked button keeps
-- its timer as it was, so it is tried again each second until it lets go (a sample timer would
-- otherwise stay frozen on a real icon after Edit Mode ends in a fight)
local lockedButtons = setmetatable({}, { __mode = "k" })
local retryTicker
local function RetryLockedButtons()
    for button in pairs(lockedButtons) do
        if pcall(ApplyPreviewTimerNow, button) then lockedButtons[button] = nil end
    end
    if not next(lockedButtons) and retryTicker then
        retryTicker:Cancel()
        retryTicker = nil
    end
end
local function ApplyPreviewTimer(button)
    if pcall(ApplyPreviewTimerNow, button) then
        lockedButtons[button] = nil
        return
    end
    lockedButtons[button] = true
    if not retryTicker then retryTicker = C_Timer.NewTicker(1, RetryLockedButtons) end
end

local function StyleButton(button, look)
    local size, round = look.size, look.style == "round"
    -- the settings window's sample auras stay out: Edit Mode's preview timers are not theirs
    if not look.preview then styledButtons[button] = true end
    button:SetSize(size, look.cellHeight or CellHeight(size))

    if not button.FlareUI_Area then
        local area = CreateFrame("Frame", nil, button)
        button.FlareUI_Area = area

        local bg = area:CreateTexture(nil, "BACKGROUND")
        bg:SetColorTexture(0, 0, 0, 1)
        button.FlareUI_Bg = bg

        local icon = area:CreateTexture(nil, "ARTWORK")
        button.FlareUI_Icon = icon

        local mask = area:CreateMaskTexture()
        icon:AddMaskTexture(mask)
        bg:AddMaskTexture(mask)
        button.FlareUI_Mask = mask

        -- bottom up: icon, border and cooldown (ordered per swipe below), text
        local borderFrame = CreateFrame("Frame", nil, area)
        borderFrame:SetAllPoints(area)
        button.FlareUI_BorderFrame = borderFrame

        local border = borderFrame:CreateTexture(nil, "OVERLAY", nil, 1)
        button.FlareUI_Border = border

        local cd = CreateFrame("Cooldown", nil, area, "CooldownFrameTemplate")
        cd:SetAllPoints(area)
        cd:SetDrawEdge(false)
        cd:SetDrawBling(false)
        cd:SetHideCountdownNumbers(true)
        cd:SetReverse(true)
        button.FlareUI_Cooldown = cd

        local overlay = CreateFrame("Frame", nil, area)
        overlay:SetAllPoints(area)
        button.FlareUI_Overlay = overlay

        local count = overlay:CreateFontString(nil, "OVERLAY")
        count:SetDrawLayer("OVERLAY", 3)
        count:SetJustifyH("RIGHT")
        button.FlareUI_Count = count

        local duration = overlay:CreateFontString(nil, "OVERLAY")
        duration:SetDrawLayer("OVERLAY", 3)
        duration:SetJustifyH("CENTER")
        button.FlareUI_Duration = duration
    end

    local area, icon, bg, mask = button.FlareUI_Area, button.FlareUI_Icon, button.FlareUI_Bg, button.FlareUI_Mask
    local cd, border = button.FlareUI_Cooldown, button.FlareUI_Border
    area:ClearAllPoints()
    area:SetPoint("TOP", button, "TOP", 0, 0)
    area:SetSize(size, size)

    -- square: the icon in the bevel's opening, clipped to its cut corners; round: under the ring's mask
    icon:ClearAllPoints()
    mask:ClearAllPoints()
    border:ClearAllPoints()
    if round then
        icon:SetAllPoints(area)
        mask:SetAtlas(ROUND_MASK, TextureKitConstants and TextureKitConstants.IgnoreAtlasSize)
        mask:SetAllPoints(area)
        border:SetAtlas(ROUND_BORDER, TextureKitConstants and TextureKitConstants.IgnoreAtlasSize)
        border:SetAllPoints(area)
    else
        local inset = size * SQUARE_INSET
        icon:SetPoint("TOPLEFT", area, "TOPLEFT", inset, -inset)
        icon:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", -inset, inset)
        mask:SetTexture(SQUARE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(area)
        border:SetTexture(SQUARE_BORDER)
        border:SetAllPoints(area)
    end
    -- crop the icon's built-in border
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    bg:ClearAllPoints()
    bg:SetAllPoints(icon)

    -- the Border and Both swipes draw above the border art, the Icon swipe below it
    local base = area:GetFrameLevel()
    if look.swipe == "border" or look.swipe == "both" then
        button.FlareUI_BorderFrame:SetFrameLevel(base + 1)
        cd:SetFrameLevel(base + 2)
    else
        cd:SetFrameLevel(base + 1)
        button.FlareUI_BorderFrame:SetFrameLevel(base + 2)
    end
    button.FlareUI_Overlay:SetFrameLevel(base + 4)
    -- square Icon swipe: only the opening, in its cut shape
    local fitIcon = look.swipe == "icon" and not round
    cd:ClearAllPoints()
    cd:SetAllPoints(fitIcon and icon or area)
    if CreateVector2D then
        local edge = fitIcon and SQUARE_INSET or 0
        cd:SetTexCoordRange(CreateVector2D(edge, edge), CreateVector2D(1 - edge, 1 - edge))
    end
    cd:SetUseCircularEdge(round)
    if look.swipe == "none" then
        cd:SetDrawSwipe(false)
        cd:SetDrawEdge(false)
    elseif look.swipe == "border" then
        cd:SetDrawSwipe(true)
        cd:SetDrawEdge(false)
        cd:SetSwipeTexture(round and SWIPE_ROUND or SWIPE_SQUARE)
        cd:SetSwipeColor(0, 0, 0, SWIPE_ALPHA)
    elseif look.swipe == "both" then
        -- one swipe over the icon and its border together (Blizzard drives a single cooldown)
        cd:SetDrawSwipe(true)
        cd:SetSwipeTexture(round and SWIPE_DISC or SQUARE_MASK)
        cd:SetSwipeColor(0, 0, 0, SWIPE_ALPHA)
        cd:SetDrawEdge(true)
        cd:SetEdgeTexture(SWIPE_EDGE, 1, 1, 1, 1)
        if cd.SetEdgeScale then cd:SetEdgeScale(SWIPE_EDGE_SCALE) end
    else
        cd:SetDrawSwipe(true)
        cd:SetSwipeTexture(round and SWIPE_DISC or SQUARE_MASK)
        cd:SetSwipeColor(0, 0, 0, ICON_SWIPE_ALPHA)
        cd:SetDrawEdge(true)
        cd:SetEdgeTexture(SWIPE_EDGE, 1, 1, 1, 1)
        if cd.SetEdgeScale then cd:SetEdgeScale(SWIPE_EDGE_SCALE) end
    end

    local font, countFont = look.font or {}, look.countFont or look.font or {}
    local fontPath = ns.GetFontPath(font.face or "Friz Quadrata TT")
    local fontSize = font.size or 11
    local flags = font.flags or "OUTLINE"
    if flags == "NONE" then flags = "" end   -- not a valid client flag
    local countFlags = countFont.flags or "OUTLINE"
    if countFlags == "NONE" then countFlags = "" end
    local countText, durationText = button.FlareUI_Count, button.FlareUI_Duration
    local timerSize = look.timerSize or math_max(8, fontSize - 1)
    ns.SetFont(countText, ns.GetFontPath(countFont.face or "Friz Quadrata TT"), countFont.size or fontSize, countFlags)
    ns.SetFont(durationText, fontPath, timerSize, flags)
    ns.ApplyShadow(countText, countFont)
    ns.ApplyShadow(durationText, font)
    countText:ClearAllPoints()
    countText:SetPoint("TOPRIGHT", area, "TOPRIGHT", round and 1 or -1, round and 1 or -1)
    durationText:ClearAllPoints()
    if look.timer == "below" then
        durationText:SetPoint("TOP", area, "BOTTOM", 0, -1)
    elseif look.timer == "middle" then
        durationText:SetPoint("CENTER", area, "CENTER", 0, 0)
    else
        durationText:SetPoint("BOTTOM", area, "BOTTOM", 0, 2)
    end
    -- no timer: Blizzard still shows and fills the text, so it is hidden by alpha
    button.FlareUI_TimerShown = look.timer ~= "none"
    local preview = button.FlareUI_PreviewTimer
    if not preview then
        preview = durationText:GetParent():CreateFontString(nil, "OVERLAY")
        preview:SetDrawLayer("OVERLAY", 3)
        button.FlareUI_PreviewTimer = preview
        SAMPLE_TIMERS.next = (SAMPLE_TIMERS.next or 0) % #SAMPLE_TIMERS + 1
        preview.sample = SAMPLE_TIMERS[SAMPLE_TIMERS.next]
    end
    -- a font string takes no text without a font
    ns.SetFont(preview, fontPath, timerSize, flags)
    preview:SetText(preview.sample)
    -- never copied from the real timer: it sits at alpha 0 while previewing, and its colour reads back with that
    preview:SetTextColor(1, 1, 1, 1)
    ns.ApplyShadow(preview, look.font)
    preview:ClearAllPoints()
    for i = 1, durationText:GetNumPoints() do preview:SetPoint(durationText:GetPoint(i)) end
    ApplyPreviewTimer(button)

    -- Highlight Purgeable Buffs: Blizzard's stealable border round a buff that can be purged
    local glow = button.FlareUI_Stealable
    if look.stealable then
        if not glow then
            glow = button.FlareUI_BorderFrame:CreateTexture(nil, "OVERLAY", nil, 2)
            glow:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Stealable")
            glow:SetBlendMode("ADD")
            button.FlareUI_Stealable = glow
        end
        glow:ClearAllPoints()
        glow:SetPoint("CENTER", area, "CENTER")
        glow:SetSize(size * 1.4, size * 1.4)
        glow:Show()
    elseif glow then
        glow:Hide()
    end
end

LEM:RegisterCallback("enter", function() for button in pairs(styledButtons) do ApplyPreviewTimer(button) end end)
LEM:RegisterCallback("exit", function() for button in pairs(styledButtons) do ApplyPreviewTimer(button) end end)
ns.OnEditFight(function() for button in pairs(styledButtons) do ApplyPreviewTimer(button) end end)

-- Hands FlareUI's regions to Blizzard's aura button, which drives them
local function HookButton(button, look)
    local icon, cd, border = button.FlareUI_Icon, button.FlareUI_Cooldown, button.FlareUI_Border
    local countText, durationText = button.FlareUI_Count, button.FlareUI_Duration
    pcall(button.SetIcon, button, icon)
    pcall(button.SetDurationCooldown, button, cd)
    pcall(button.SetApplicationCount, button, countText, {})
    -- (a hidden timer, Timer None, stays uncoloured: the colour would bring its alpha back)
    ns.SetAuraDurationText(button, durationText, look.timerColor and look.timer ~= "none")
    pcall(button.ClearDispelTypeTextures, button)
    -- Blizzard tints the border from the colour map, so a secret dispel type is never read by Lua
    if Enum.CustomAuraButtonDispelTypeTextureStyle then
        local options = {
            style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
            showAlways = true,
            showWhenHelpful = true,
            showWhenHarmful = true,
            showWithoutDispelType = true,
            customDispelColorMap = look.colors,
        }
        pcall(button.AddDispelTypeTexture, button, border, options)
    end
    if not look.isDebuff and look.cancel ~= false and button.SetCancelAuraButtons then
        pcall(button.SetCancelAuraButtons, button, "RightButtonUp")
    end
end

-- Arrival Animation: the icon fades in while dropping into place. Handed to Blizzard's button, which
-- plays it as a hidden button is shown, in combat too. Moves and fades only: a scale would draw the
-- masked icon square
local ARRIVE_DROP, ARRIVE_TIME = 6, 0.25
local function SetArrival(button, on)
    pcall(button.ClearAuraShownAnimations, button)
    if not on then return end
    local g = button.FlareUI_Arrive
    if not g then
        g = button.FlareUI_Area:CreateAnimationGroup()
        local hide = g:CreateAnimation("Alpha")
        hide:SetFromAlpha(0)
        hide:SetToAlpha(0)
        hide:SetDuration(0)
        hide:SetOrder(1)
        local lift = g:CreateAnimation("Translation")
        lift:SetOffset(0, ARRIVE_DROP)
        lift:SetDuration(0)
        lift:SetOrder(1)
        local drop = g:CreateAnimation("Translation")
        drop:SetOffset(0, -ARRIVE_DROP)
        drop:SetDuration(ARRIVE_TIME)
        drop:SetOrder(2)
        drop:SetSmoothing("OUT")
        local fade = g:CreateAnimation("Alpha")
        fade:SetFromAlpha(0)
        fade:SetToAlpha(1)
        fade:SetDuration(ARRIVE_TIME)
        fade:SetOrder(2)
        button.FlareUI_Arrive = g
    end
    pcall(button.AddAuraShownAnimation, button, g)
end

-- A snapshot of one frame's settings for the buttons Blizzard initialises
local function Look(kind)
    local db, kdb = GetDb(), KindDb(kind)
    ns.SeedFont(db, "font", "countFont", "countFontSeeded")
    return {
        size = kdb.size or 30,
        style = db.style or "square",
        swipe = db.swipe or "both",
        timer = db.timer or "below",
        font = db.font,
        countFont = db.countFont,
        isDebuff = KINDS[kind].isDebuff,
        colors = ColorMap(KINDS[kind].isDebuff, db.style == "round", db.swipe == "border"),
        arrive = db.arrive and true or false,
        timerColor = db.timerColor and true or false,
    }
end

-- The same buttons for unit, party and raid frame auras (with or without this module), in the
-- unit frame fonts: Aura timers and Aura stacks, each sized to the icon on Auto (size 0)
ns.AuraLook = {
    Style = StyleButton,
    Hook = HookButton,
    ForUnit = function(size, isDebuff, canCancel, style, swipe, timer)
        local uf = ns.db and ns.db.profile and ns.db.profile.unitframes or {}
        ns.SeedFont(uf, "auraFont", "auraCountFont", "auraCountFontSeeded", true)
        style, timer = style or "square", timer or "below"
        -- Aura swipe (Unit Frames settings), for every unit, party, raid and boss frame
        swipe = uf.auraSwipe or swipe or "both"
        local autoSize = math_max(7, math_floor(size * 0.4 + 0.5))
        local timerFont, countFont = uf.auraFont or {}, uf.auraCountFont or uf.auraFont or {}
        local timerSize = (timerFont.size or 0) > 0 and timerFont.size or math_max(8, autoSize - 1)
        local countSize = (countFont.size or 0) > 0 and countFont.size or autoSize
        return {
            size = size,
            style = style,
            swipe = swipe,
            timer = timer,
            font = setmetatable({ size = autoSize }, { __index = timerFont }),
            countFont = setmetatable({ size = countSize }, { __index = countFont }),
            timerSize = timerSize,
            isDebuff = isDebuff,
            cancel = canCancel,
            timerColor = uf.auraTimerColor and true or false,
            colors = ColorMap(isDebuff, style == "round", swipe == "border"),
            -- room under the icon: autoSize + 3 on Auto, a chosen size gets its own
            cellHeight = size + ((timer == "below") and ((timerFont.size or 0) > 0 and timerSize + 4 or autoSize + 3) or 0),
        }
    end,
}

--------------------------------------------------
-- 6. LAYOUT
-- The holder is the grid's full size, so the Edit Mode box shows its reach
--------------------------------------------------
local function GridSize(kdb)
    local size, spacing = kdb.size or 30, kdb.spacing or 6
    local perRow = math_max(1, math_min(kdb.perRow or 12, kdb.max or 32))
    local rows = math_ceil((kdb.max or 32) / perRow)
    local width = perRow * size + (perRow - 1) * spacing
    local height = rows * CellHeight(size) + (rows - 1) * spacing
    return width, height
end

local function StartCorner(kdb)
    return ((kdb.wrap == "UP") and "BOTTOM" or "TOP") .. ((kdb.grow == "RIGHT") and "LEFT" or "RIGHT")
end

-- Edit Mode: plain sample frames in every slot up to "Max Icons"
function UpdatePreview(kind)
    local holder, kdb = frames[kind], KindDb(kind)
    if not (holder and kdb) then return end
    local editing = Previewing()
    holder.container:SetShown(not editing)
    holder.preview = holder.preview or {}
    local count = editing and (kdb.max or 32) or 0
    local look = editing and Look(kind)
    local size, spacing = kdb.size or 30, kdb.spacing or 6
    local perRow = math_max(1, kdb.perRow or 12)
    local corner = StartCorner(kdb)
    local stepX = (size + spacing) * (kdb.grow == "RIGHT" and 1 or -1)
    local stepY = (CellHeight(size) + spacing) * (kdb.wrap == "UP" and 1 or -1)
    local icons = PREVIEW_ICONS[kind]
    local now = GetTime()

    for i = 1, math_max(count, #holder.preview) do
        local sample = holder.preview[i]
        if i <= count then
            if not sample then
                sample = CreateFrame("Frame", nil, holder)
                holder.preview[i] = sample
            end
            StyleButton(sample, look)
            sample.FlareUI_Icon:SetTexture("Interface\\Icons\\" .. icons[(i - 1) % #icons + 1])
            local key = look.isDebuff and PREVIEW_DEBUFF_TYPES[(i - 1) % #PREVIEW_DEBUFF_TYPES + 1] or "None"
            sample.FlareUI_Border:SetVertexColor(look.colors[key]:GetRGBA())
            sample.FlareUI_Count:SetText(i % 4 == 0 and tostring(i % 9 + 1) or "")
            sample.FlareUI_Duration:SetText(PREVIEW_TIMES[(i - 1) % #PREVIEW_TIMES + 1])
            -- staggered long cooldowns show the swipe
            sample.FlareUI_Cooldown:SetCooldown(now - (i * 37) % 300, 300)
            local col, row = (i - 1) % perRow, math_floor((i - 1) / perRow)
            sample:ClearAllPoints()
            sample:SetPoint(corner, holder, corner, col * stepX, row * stepY)
            sample:Show()
        elseif sample then
            sample:Hide()
        end
    end
end

-- Private auras: a row just outside the holder, on the side the grid wraps to
local function LayoutPrivateAnchors(holder, kdb)
    if not (C_UnitAuras and C_UnitAuras.AddPrivateAuraAnchor) then return end
    holder.privateAnchors = holder.privateAnchors or {}
    local size, spacing = kdb.size or 30, kdb.spacing or 6
    local up, right = kdb.wrap == "UP", kdb.grow == "RIGHT"
    for i = 1, PRIVATE_COUNT do
        local slot = holder.privateAnchors[i]
        if not slot then
            slot = CreateFrame("Frame", nil, holder)
            slot.Icon = CreateFrame("Frame", nil, slot)
            slot.Duration = CreateFrame("Frame", nil, slot)
            holder.privateAnchors[i] = slot
        end
        if slot.anchorID then
            pcall(C_UnitAuras.RemovePrivateAuraAnchor, slot.anchorID)
            slot.anchorID = nil
        end
        slot:SetSize(size, CellHeight(size))
        slot:ClearAllPoints()
        local x = (i - 1) * (size + spacing) * (right and 1 or -1)
        local corner = (up and "BOTTOM" or "TOP") .. (right and "LEFT" or "RIGHT")
        local outer = (up and "TOP" or "BOTTOM") .. (right and "LEFT" or "RIGHT")
        slot:SetPoint(corner, holder, outer, x, up and spacing or -spacing)
        slot.Icon:SetSize(size, size)
        slot.Icon:ClearAllPoints()
        slot.Icon:SetPoint("TOP")
        slot.Duration:SetSize(size, TIMER_SPACE)
        slot.Duration:ClearAllPoints()
        slot.Duration:SetPoint("TOP", slot.Icon, "BOTTOM", 0, -1)
        local ok, id = pcall(C_UnitAuras.AddPrivateAuraAnchor, {
            unitToken = "player",
            auraIndex = i,
            parent = slot,
            showCooldownFrame = true,
            showCooldownEdge = false,
            showCountdownNumbers = false,
            showDispelIcon = false,
            isContainer = false,
            iconInfo = {
                iconAnchor = { point = "CENTER", relativeTo = slot.Icon, relativePoint = "CENTER", offsetX = 0, offsetY = 0 },
                iconWidth = size,
                iconHeight = size,
            },
            durationAnchor = { point = "CENTER", relativeTo = slot.Duration, relativePoint = "CENTER", offsetX = 0, offsetY = 0 },
        })
        if ok then slot.anchorID = id end
    end
end

--------------------------------------------------
-- 7. WEAPON ENCHANTS
-- The aura container reads C_PaperDollInfo.GetTemporaryEnchantmentInfo, which Forever leaves empty:
-- FlareUI's own buttons read C_Item.GetWeaponEnchantInfo and lead the first row, the container
-- shifted along (out of combat; until then a new enchant sits just before the row).
--------------------------------------------------
-- Enum.WeaponSlot -> inventory slot
local WEAPON_SLOTS = { { slot = 0, inv = 16 }, { slot = 1, inv = 17 }, { slot = 2, inv = 18 } }
local enchantDurations = {}   -- "slot:type" -> full duration, taken when first seen

-- The timed weapon enchants, in slot order
local function ActiveEnchants()
    local list = {}
    if not (C_Item and C_Item.GetWeaponEnchantInfo) then return list end
    local now = GetTime()
    for _, weapon in ipairs(WEAPON_SLOTS) do
        local ok, enchants = pcall(C_Item.GetWeaponEnchantInfo, weapon.slot)
        for _, e in ipairs(ok and enchants or {}) do
            -- a permanent enchant (no time left) is not a buff
            if e.hasEnchant and (e.timeLeft or 0) > 0 then
                local left = e.timeLeft / 1000
                local key = weapon.slot .. ":" .. (e.enchantType or 0)
                local known = enchantDurations[key]
                -- new, or refreshed: the time left is the full duration
                if not known or known.id ~= e.enchantID or left > known.left + 1 then
                    known = { id = e.enchantID, duration = left }
                    enchantDurations[key] = known
                end
                known.left = left
                list[#list + 1] = {
                    weapon = weapon, type = e.enchantType or 0, charges = e.charges or 0,
                    iconID = e.enchantIconID, expires = now + left, duration = known.duration,
                }
            end
        end
    end
    return list
end

local function EnchantButton(holder, i)
    holder.enchants = holder.enchants or {}
    local b = holder.enchants[i]
    if b then return b end
    b = CreateFrame("Frame", nil, holder)
    b:EnableMouse(true)
    b:SetScript("OnEnter", function(self)
        if not self.enchant then return end
        ns.OwnGameTooltip(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetInventoryItem("player", self.enchant.weapon.inv)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- no right-click cancel: blocked for addons on Forever, and the secure cancelaura route reads a
    -- CANCELABLE_ITEMS table Forever never defines
    holder.enchants[i] = b
    return b
end

local function EnchantTimer(holder)
    local now = GetTime()
    for _, b in ipairs(holder.enchants or {}) do
        if b:IsShown() and b.enchant then
            local left = math_max(0, b.enchant.expires - now)
            b.FlareUI_Duration:SetText(ns.FormatAuraTime(left))
        end
    end
end

local function EnchantOnUpdate(self, elapsed)
    self.enchantTick = (self.enchantTick or 0) + elapsed
    if self.enchantTick < 0.5 then return end
    self.enchantTick = 0
    EnchantTimer(self)
end

-- Shifts the container by one cell per enchant (out of combat only)
local function PlaceContainer(holder, kdb, corner, width)
    local container = holder.container
    local n = (not Previewing() and holder.activeEnchants) or 0
    local step = (kdb.size or 30) + (kdb.spacing or 6)
    holder.enchantShift = n
    container:ClearAllPoints()
    container:SetPoint(corner, holder, corner, n * step * ((kdb.grow == "RIGHT") and 1 or -1), 0)
    pcall(container.SetFlowLayoutMaximumLineSize, container, math_max(step, width - n * step))
end

local function UpdateEnchants(kind)
    local holder, kdb = frames[kind], KindDb(kind)
    if not (holder and kdb) or KINDS[kind].isDebuff then return end
    local list = Previewing() and {} or ActiveEnchants()
    local look = Look(kind)
    local step = (kdb.size or 30) + (kdb.spacing or 6)
    local corner = StartCorner(kdb)
    local dir = (kdb.grow == "RIGHT") and 1 or -1
    local shift = holder.enchantShift or 0
    for i = 1, math_max(#list, #(holder.enchants or {})) do
        local e = list[i]
        local b = e and EnchantButton(holder, i) or holder.enchants[i]
        if e then
            StyleButton(b, look)
            local icon = GetInventoryItemTexture("player", e.weapon.inv)
            if GetCVarBool and GetCVarBool("displayTemporaryEnchantIcon") and (e.iconID or 0) > 0 then icon = e.iconID end
            b.FlareUI_Icon:SetTexture(icon or 134400)
            b.FlareUI_Border:SetVertexColor(look.colors.None:GetRGBA())
            b.FlareUI_Count:SetText(e.charges > 1 and tostring(e.charges) or "")
            b.FlareUI_Cooldown:SetCooldown(e.expires - e.duration, e.duration)
            b.enchant = e
            -- cells shift - n .. shift - 1: inside the room the container left, or just before it
            b:ClearAllPoints()
            b:SetPoint(corner, holder, corner, (shift - #list + i - 1) * step * dir, 0)
            b:Show()
        elseif b then
            b.enchant = nil
            b:Hide()
        end
    end
    holder:SetScript("OnUpdate", #list > 0 and EnchantOnUpdate or nil)
    EnchantTimer(holder)
    -- the container makes room once combat allows
    if #list ~= (holder.activeEnchants or 0) then
        holder.activeEnchants = #list
        if InCombatLockdown() then
            pendingLayout = true
        else
            PlaceContainer(holder, kdb, corner, (GridSize(kdb)))
            UpdateEnchants(kind)
        end
    end
end

local function LayoutKind(kind)
    local holder, kdb = frames[kind], KindDb(kind)
    if not (holder and kdb) then return end
    if InCombatLockdown() then pendingLayout = true return end

    local width, height = GridSize(kdb)
    holder:SetSize(width, height)

    local container = holder.container
    -- one group per look, reused (ns.AuraGroups)
    holder.auraGroups = holder.auraGroups or {}
    ns.AuraGroups.Begin(holder.auraGroups)

    local look = Look(kind)
    local spacing = kdb.spacing or 6
    local corner = StartCorner(kdb)
    pcall(container.SetFlowLayoutAxis, container, AnchorUtil.FlowLayoutAxis.Horizontal)
    pcall(container.SetFlowLayoutAnchorPoint, container, corner)
    pcall(container.SetFlowLayoutGrowthDirection, container,
        kdb.grow == "RIGHT" and AnchorUtil.FlowDirection.Right or AnchorUtil.FlowDirection.Left,
        kdb.wrap == "UP" and AnchorUtil.FlowDirection.Up or AnchorUtil.FlowDirection.Down)
    PlaceContainer(holder, kdb, corner, width)
    pcall(container.SetFlowLayoutPadding, container, 0, 0, 0, 0)

    local layout = {
        elementWidth = look.size, elementHeight = CellHeight(look.size),
        elementSpacing = spacing, lineSpacing = spacing,
        groupSpacing = spacing, groupLineSpacing = spacing,
    }
    local adb = GetDb()
    local sortMethod, sortDirection = ns.AuraOrder.Options(adb and adb.sort or "applied", adb and adb.reverse, adb and adb.mineFirst)
    local lane = ns.AuraPolicy.PlayerListLane(KINDS[kind].isDebuff)
    local key, err = ns.AuraGroups.Add(container, holder.auraGroups, kind, ns.AuraGroups.Sig(look), lane.filter, {
        maxFrameCount = kdb.max or 32,
        -- Aura Ordering (Order Applied by default); the container compares, never addon code
        sortMethod = sortMethod, sortDirection = sortDirection,
        initializeFrame = function(button)
            StyleButton(button, look)
            HookButton(button, look)
            SetArrival(button, look.arrive)
        end,
        layout = layout,
    })
    if not key then print("|cffff0000FlareUI:|r aura frame failed: " .. tostring(err)) end
    ns.AuraGroups.Finish(container, holder.auraGroups)

    if KINDS[kind].isDebuff then LayoutPrivateAnchors(holder, kdb) end

    pcall(container.SetEnabled, container, true)
    UpdatePreview(kind)
    UpdateEnchants(kind)
    pcall(container.UpdateAllAuras, container)
end

--------------------------------------------------
-- 8. POSITION (per Edit Mode layout)
--------------------------------------------------
local function GetLayoutStore(layoutName)
    local db = GetDb()
    if not db then return nil end
    layoutName = layoutName or LEM:GetActiveLayoutName() or "Modern"
    db.layouts = db.layouts or {}
    -- (a layout with no spot of its own reads the profile's home layout's: ProfileLayout.lua)
    return ns.LayoutHome(db.layouts, layoutName)
end

local function ApplyPosition(kind, layoutName)
    local holder = frames[kind]
    if not holder then return end
    if InCombatLockdown() then pendingLayout = true return end
    local store = GetLayoutStore(layoutName)
    local pos = store and store[kind] or KINDS[kind].default
    holder:ClearAllPoints()
    holder:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or 0, pos.y or 0)
end

local function OnFrameMoved(holder, layoutName, point, x, y)
    local store = GetLayoutStore(layoutName)
    if not store then return end
    store[holder.kind] = { point = point, x = math_floor(x + 0.5), y = math_floor(y + 0.5) }
end

--------------------------------------------------
-- 9. EDIT MODE SETTINGS
--------------------------------------------------
local GROW_VALUES = {
    { text = L["Left"],  value = "LEFT",  isRadio = true },
    { text = L["Right"], value = "RIGHT", isRadio = true },
}
local WRAP_VALUES = {
    { text = L["Down"], value = "DOWN", isRadio = true },
    { text = L["Up"],   value = "UP",   isRadio = true },
}
local SWIPE_VALUES = {
    { text = L["Over the Icon"], value = "icon", isRadio = true },
    { text = L["Around the Border"], value = "border", isRadio = true },
    { text = L["Both"], value = "both", isRadio = true },
    { text = L["Off"], value = "none", isRadio = true },
}
local TIMER_VALUES = {
    { text = L["Under the Icon"], value = "below", isRadio = true },
    { text = L["Bottom of the Icon"], value = "bottom", isRadio = true },
    { text = L["Middle of the Icon"], value = "middle", isRadio = true },
    { text = L["Off"], value = "none", isRadio = true },
}

local function BuildSettings(kind)
    local defaults = ns.defaults and ns.defaults.profile.auras[kind] or {}
    local function get(key) return function() local k = KindDb(kind); return k and k[key] end end
    local function set(key)
        return function(_, value)
            local k = KindDb(kind)
            if not k then return end
            k[key] = value
            LayoutKind(kind)
        end
    end
    local function shared(key, default) return function() local db = GetDb(); return db and db[key] or default end end
    local function setShared(key)
        return function(_, value)
            local db = GetDb()
            if not db then return end
            db[key] = value
            AU:Refresh()
        end
    end
    -- dropdowns, sliders, switches (ns.OrderEditSettings)
    return ns.OrderEditSettings({
        { name = L["Icon Size"], kind = LEM.SettingType.Slider, default = defaults.size or 30, minValue = 16, maxValue = 64, valueStep = 1,
          get = get("size"), set = set("size") },
        { name = L["Icons per Row"], kind = LEM.SettingType.Slider, default = defaults.perRow or 12, minValue = 1, maxValue = 40, valueStep = 1,
          get = get("perRow"), set = set("perRow") },
        { name = L["Max Icons"], kind = LEM.SettingType.Slider, default = defaults.max or 32, minValue = 1, maxValue = 40, valueStep = 1,
          get = get("max"), set = set("max") },
        { name = L["Spacing"], kind = LEM.SettingType.Slider, default = defaults.spacing or 6, minValue = 0, maxValue = 20, valueStep = 1,
          get = get("spacing"), set = set("spacing") },
        { name = L["Growth"], kind = LEM.SettingType.Dropdown, default = defaults.grow or "LEFT", values = GROW_VALUES,
          get = get("grow"), set = set("grow") },
        { name = L["Wrap"], kind = LEM.SettingType.Dropdown, default = defaults.wrap or "DOWN", values = WRAP_VALUES,
          get = get("wrap"), set = set("wrap") },
        -- the look both bars share (Settings > Buffs & Debuffs too): the samples follow at once
        { name = L["Aura Swipe"], kind = LEM.SettingType.Dropdown, default = "both", values = SWIPE_VALUES,
          get = shared("swipe", "both"), set = setShared("swipe") },
        { name = L["Aura Timer"], kind = LEM.SettingType.Dropdown, default = "below", values = TIMER_VALUES,
          get = shared("timer", "below"), set = setShared("timer") },
    })
end

--------------------------------------------------
-- 9b. BLIZZARD'S COOLDOWN MANAGER (Skin Cooldown Manager, on with this module)
-- The Tracked Bars and Tracked Buffs icons in FlareUI's look: the bars as FlareUI's cast bars (the
-- unit frames' bar texture, a thin bronze border, the cast bar font), the icons as FlareUI's buffs
-- (Aura Icon Shape, Aura Swipe, the stack font). Blizzard keeps driving its own pooled frames; it sets
-- only values, text and the spark after a frame is made, so each one is styled once as it is
-- acquired. Its aura data is kept from addons (CooldownViewerSecure.lua): nothing here reads it,
-- writes onto its frames, re-parents them or calls their layout. FlareUI's pieces live in a weak table.
--------------------------------------------------
local CDM = { pieces = setmetatable({}, { __mode = "k" }), BAR_COLOR = { 1, 0.5, 0.25 }, BORDER = "FlareUI Thin",
              OVERLAY = "UI-HUD-CoolDownManager-IconOverlay" }

function CDM.On()
    local db = GetDb()
    return db and db.enabled and db.skinCDM ~= false and not ns.IsGamepadUI() or false
end

function CDM.Pieces(frame)
    local p = CDM.pieces[frame]
    if not p then p = {}; CDM.pieces[frame] = p end
    return p
end

-- An icon in FlareUI's buff look: Blizzard's rounded mask and thick ring go, FlareUI's bevel (or rim)
-- and its cut-corner mask come in. holder: the frame the icon fills.
function CDM.StyleIcon(holder, texture, p, round)
    for i = texture:GetNumMaskTextures(), 1, -1 do
        local mask = texture:GetMaskTexture(i)
        if mask and mask ~= p.mask then texture:RemoveMaskTexture(mask) end
    end
    for _, region in ipairs({ holder:GetRegions() }) do
        if region ~= p.border and region.GetAtlas and region:GetAtlas() == CDM.OVERLAY then region:SetAlpha(0) end
    end
    if not p.border then
        local frame = CreateFrame("Frame", nil, holder)
        frame:SetAllPoints(holder)
        frame:SetFrameLevel(holder:GetFrameLevel() + 2)
        p.border = frame:CreateTexture(nil, "OVERLAY", nil, 1)
        p.mask = holder:CreateMaskTexture()
        texture:AddMaskTexture(p.mask)
    end
    local border, mask = p.border, p.mask
    texture:ClearAllPoints()
    mask:ClearAllPoints()
    border:ClearAllPoints()
    if round then
        texture:SetAllPoints(holder)
        mask:SetAtlas(ROUND_MASK, TextureKitConstants and TextureKitConstants.IgnoreAtlasSize)
        border:SetAtlas(ROUND_BORDER, TextureKitConstants and TextureKitConstants.IgnoreAtlasSize)
        border:SetVertexColor(ROUND_TINT[1], ROUND_TINT[2], ROUND_TINT[3])
    else
        local inset = (holder:GetWidth() or 30) * SQUARE_INSET
        texture:SetPoint("TOPLEFT", holder, "TOPLEFT", inset, -inset)
        texture:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -inset, inset)
        mask:SetTexture(SQUARE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        border:SetTexture(SQUARE_BORDER)
        border:SetVertexColor(SQUARE_TINT[1], SQUARE_TINT[2], SQUARE_TINT[3])
    end
    mask:SetAllPoints(holder)
    border:SetAllPoints(holder)
    texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

function CDM.StackFont(fontString)
    local db = GetDb()
    ns.SeedFont(db, "font", "countFont", "countFontSeeded")
    local font = db.countFont or db.font or {}
    local flags = font.flags or "OUTLINE"
    if flags == "NONE" then flags = "" end
    ns.SetFont(fontString, ns.GetFontPath(font.face or "Friz Quadrata TT"), font.size or 11, flags)
    ns.ApplyShadow(fontString, font)
end

-- the same look for Buff Reminders (BuffReminders.lua)
AU.StyleIcon, AU.StackFont = CDM.StyleIcon, CDM.StackFont

-- A Tracked Buffs icon
function CDM.StyleBuffIcon(item)
    local db = GetDb()
    local round = db.style == "round"
    local p = CDM.Pieces(item)
    if item.Icon then CDM.StyleIcon(item, item.Icon, p, round) end
    local cd = item.Cooldown
    if cd then
        -- Blizzard sets the swipe's colour and edge on each refresh, its texture and drawing never
        local swipe = db.swipe or "both"
        cd:SetDrawSwipe(swipe ~= "none")
        if swipe == "border" then
            cd:SetSwipeTexture(round and SWIPE_ROUND or SWIPE_SQUARE)
        else
            cd:SetSwipeTexture(round and SWIPE_DISC or SQUARE_MASK)
        end
        cd:SetUseCircularEdge(round)
    end
    local count = item.Applications and item.Applications.Applications
    if count then CDM.StackFont(count) end
end

-- A Tracked Bar: the bar as a FlareUI cast bar, its icon as a buff
function CDM.StyleBar(item)
    local K = ns.UnitFrames and ns.UnitFrames.Kit
    local bar = item.Bar
    if not (K and bar) then return end
    local uf = ns.db.profile.unitframes or {}
    local player = uf.units and uf.units.player
    local p = CDM.Pieces(item)
    local texture = K.GetBarTexture(player and player.texture)
    bar:SetStatusBarTexture(texture)
    bar:SetStatusBarColor(CDM.BAR_COLOR[1], CDM.BAR_COLOR[2], CDM.BAR_COLOR[3])
    if bar.BarBG then bar.BarBG:SetAlpha(0) end
    if bar.Pip then bar.Pip:SetAlpha(0) end
    if not p.bg then
        p.bg = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
        p.bg:SetAllPoints(bar)
        p.backdrop = CreateFrame("Frame", nil, bar, "BackdropTemplate")
        p.backdrop:SetFrameLevel(math_max(0, bar:GetFrameLevel() - 1))
        p.barBorder = CreateFrame("Frame", nil, bar, "BackdropTemplate")
        p.barBorder:SetFrameLevel(bar:GetFrameLevel() + 3)
    end
    p.bg:SetTexture(texture)
    p.bg:SetVertexColor(0.15, 0.15, 0.15, K.BAR_BG_OPACITY / 100)
    -- the border wraps the bar, as on the cast bars (BorderFit's inset on a thin bar)
    local height = 19
    local edgeFile = K.GetBorderFile(CDM.BORDER)
    local _, wrap = K.BorderFit(height, edgeFile)
    p.backdrop:ClearAllPoints()
    p.backdrop:SetPoint("TOPLEFT", bar, "TOPLEFT", -wrap, wrap)
    p.backdrop:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", wrap, -wrap)
    p.backdrop:SetBackdrop({ bgFile = K.BACKDROP_FILE, insets = { left = wrap, right = wrap, top = wrap, bottom = wrap } })
    p.backdrop:SetBackdropColor(0, 0, 0, K.BG_OPACITY)
    p.barBorder:ClearAllPoints()
    p.barBorder:SetAllPoints(p.backdrop)
    K.ApplyBorderStyle(p.barBorder, edgeFile, height + 2 * K.INSET)
    local castFont = uf.fontCast or uf.font
    if bar.Name then K.ApplyFont(bar.Name, castFont) end
    if bar.Duration then K.ApplyFont(bar.Duration, castFont) end
    local icon = item.Icon
    if icon and icon.Icon then
        CDM.StyleIcon(icon, icon.Icon, CDM.Pieces(icon), GetDb().style == "round")
        if icon.Applications then CDM.StackFont(icon.Applications) end
    end
end

CDM.VIEWERS = { BuffBarCooldownViewer = CDM.StyleBar, BuffIconCooldownViewer = CDM.StyleBuffIcon }

-- every frame showing now (a settings change, or the viewer was already up)
function CDM.StyleAll()
    if not CDM.On() then return end
    for name, style in pairs(CDM.VIEWERS) do
        local viewer = _G[name]
        local pool = viewer and viewer.itemFramePool
        if pool and pool.EnumerateActive then
            for item in pool:EnumerateActive() do style(item) end
        end
    end
end

-- new frames as Blizzard acquires them (tracking another buff), in a fight too
function CDM.Hook()
    if CDM.hooked then return end
    for name, style in pairs(CDM.VIEWERS) do
        local viewer = _G[name]
        if viewer and viewer.OnAcquireItemFrame then
            CDM.hooked = true
            hooksecurefunc(viewer, "OnAcquireItemFrame", function(_, item)
                if CDM.On() then style(item) end
            end)
        end
    end
    CDM.StyleAll()
end

--------------------------------------------------
-- 10. BLIZZARD'S FRAMES (parked for the session)
--------------------------------------------------
local unparked = {}   -- frames a /reload in combat left in place, parked when it ends

local function ParkBlizzard(frame)
    pcall(ns.RawHide, frame)
    pcall(frame.SetParent, frame, hiddenParent)
end

local function HideBlizzard(name)
    local frame = _G[name]
    if not frame or frame.FlareUI_Hidden then return end
    frame.FlareUI_Hidden = true
    pcall(frame.UnregisterAllEvents, frame)
    if InCombatLockdown() then
        unparked[frame] = true
    else
        ParkBlizzard(frame)
    end
    hooksecurefunc(frame, "Show", function(f) if not InCombatLockdown() then ns.RawHide(f) end end)
end

--------------------------------------------------
-- 11. SETUP
--------------------------------------------------
local function CreateHolder(kind)
    local info = KINDS[kind]
    local holder = CreateFrame("Frame", "FlareUI_" .. (info.isDebuff and "Debuffs" or "Buffs"), UIParent)
    holder:SetClampedToScreen(true)
    holder.kind = kind
    holder:SetFrameStrata("LOW")
    holder:SetSize(1, 1)

    local ok, container = pcall(CreateFrame, "AuraContainer", nil, holder, TEMPLATE)
    if not (ok and container) then return nil end
    pcall(container.SetUnit, container, "player")
    container:SetFrameLevel(holder:GetFrameLevel() + 2)
    holder.container = container

    frames[kind] = holder
    LEM:AddFrame(holder, OnFrameMoved, info.default, info.label)
    LEM:AddFrameSettings(holder, BuildSettings(kind))
    return holder
end

local function SetPreview()
    for _, kind in ipairs(KIND_ORDER) do UpdatePreview(kind) end
end

function AU:Refresh()
    if not self.initialized then return end
    for _, kind in ipairs(KIND_ORDER) do LayoutKind(kind) end
    CDM.StyleAll()   -- Aura Icon Shape, Aura Swipe and the fonts reach the Cooldown Manager too
    if ns.BuffReminders and ns.BuffReminders.Refresh then ns.BuffReminders:Refresh() end
end

local function ApplySettingsPreview(on)
    settingsPreview = on
    SetPreview()
    for button in pairs(styledButtons) do ApplyPreviewTimer(button) end
    AU:Refresh()
    -- faded frames show while the page is open
    if ns.Visibility and ns.Visibility.Wake then ns.Visibility:Wake() end
end

function AU:IsSettingsPreview() return settingsPreview end

-- This module's settings page is open or closed
function AU:SetSettingsPreview(on)
    on = on and true or false
    previewWanted = on
    if not self.initialized or settingsPreview == on then return end
    -- a fight: PLAYER_REGEN_ENABLED picks it up
    if not InCombatLockdown() then ApplySettingsPreview(on) end
end

-- The Edit Mode holder of "buffs" or "debuffs" (the settings panel's Edit buttons)
function AU:GetFrame(kind)
    return frames[kind]
end

function AU:ShouldLoad()
    -- Blizzard's buff frames take part in the Gamepad UI's controller navigation
    return not ns.IsGamepadUI()
end

function AU:Init()
    if self.initialized then return end
    local db = GetDb()
    if not db then return end
    if C_AddOns.DoesAddOnExist("Blizzard_AuraContainer") and not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
    end
    for _, kind in ipairs(KIND_ORDER) do
        if not CreateHolder(kind) then
            print("|cffff0000FlareUI:|r Buffs / Debuffs could not create their frames.")
            return
        end
    end
    self.initialized = true

    HideBlizzard("BuffFrame")
    HideBlizzard("DebuffFrame")
    -- Skin Cooldown Manager (its addon can load after FlareUI)
    if CDM.On() then EventUtil.ContinueOnAddOnLoaded("Blizzard_CooldownViewer", CDM.Hook) end

    for _, kind in ipairs(KIND_ORDER) do
        ApplyPosition(kind)
        LayoutKind(kind)
    end

    LEM:RegisterCallback("layout", function(layoutName)
        for _, kind in ipairs(KIND_ORDER) do ApplyPosition(kind, layoutName) end
    end)
    LEM:RegisterCallback("enter", function() SetPreview() AU:Refresh() end)
    LEM:RegisterCallback("exit", function() SetPreview() AU:Refresh() end)
    ns.OnEditFight(function() SetPreview() AU:Refresh() end)

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    for _, event in ipairs({ "WEAPON_ENCHANT_CHANGED", "WEAPON_SLOT_CHANGED", "PLAYER_EQUIPMENT_CHANGED" }) do
        pcall(events.RegisterEvent, events, event)
    end
    pcall(events.RegisterUnitEvent, events, "UNIT_INVENTORY_CHANGED", "player")
    events:SetScript("OnEvent", function(_, event)
        -- a fight starting: the real icons come back while they still can (lockdown starts after this)
        if event == "PLAYER_REGEN_DISABLED" then
            if settingsPreview then ApplySettingsPreview(false) end
            return
        end
        if event == "PLAYER_REGEN_ENABLED" and previewWanted ~= settingsPreview then ApplySettingsPreview(previewWanted) end
        if event ~= "PLAYER_REGEN_ENABLED" then
            UpdateEnchants("buffs")
            return
        end
        for frame in pairs(unparked) do
            ParkBlizzard(frame)
            unparked[frame] = nil
        end
        if not pendingLayout then return end
        pendingLayout = false
        for _, kind in ipairs(KIND_ORDER) do
            ApplyPosition(kind)
            LayoutKind(kind)
        end
    end)
end
