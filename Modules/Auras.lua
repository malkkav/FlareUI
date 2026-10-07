local _, ns = ...
local L = ns.L

--------------------------------------------------
-- 1. MODULE REGISTRATION
-- The player's buffs and debuffs, in place of Blizzard's BuffFrame / DebuffFrame: two Edit Mode
-- frames, each holding a CustomAuraContainer. Blizzard picks, sorts and times the auras and drives
-- our textures, so it works with secret aura data; right-click cancels. FlareUI draws the look:
--   * square (classic icon bevel) or round (the spellbook passive ring)
--   * borders tinted by Blizzard through a colour map (dispel colours for debuffs, never read by Lua)
--   * the cooldown swipe on the border, over the icon, or none; timer and stacks
-- Weapon enchants lead the buffs (FlareUI's own buttons); private auras get anchors beside the debuffs. Stands aside in the
-- Gamepad UI (Blizzard's frames are part of its navigation).
--------------------------------------------------
ns.Auras = ns.Auras or {}
local AU = ns.Auras
ns.modules["Auras"] = AU

--------------------------------------------------
-- 2. UPVALUES
--------------------------------------------------
local _G = _G
local pairs, ipairs, pcall = pairs, ipairs, pcall
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
-- Square: the classic icon bevel (grey, wtf-tools/buildborder.js), the icon in its opening. Round:
-- the Radial Menu's rim, the icon under its mask. Both tinted bronze for buffs.
local SQUARE_BORDER = MEDIA .. "IconBorder"
local SQUARE_INSET  = 6 / 128     -- the icon starts this far in, under the bevel's inner line
local SQUARE_MASK   = MEDIA .. "IconMask"   -- the icon clipped to the bevel's 45 degree corners
-- the minimap frame's bronze, lifted a little as the tint multiplies the grey art
local SQUARE_TINT   = { 0.72, 0.56, 0.38 }
local ROUND_BORDER  = "talents-node-circle-gray"
local ROUND_MASK    = "talents-node-circle-mask"
local ROUND_TINT    = { 0.72, 0.56, 0.38 }   -- the same bronze on the silver ring
-- White outlines for the Border swipe (a swipe takes a file, not an atlas); never drawn as art
local SWIPE_SQUARE  = MEDIA .. "Border"
local SWIPE_ROUND   = MEDIA .. "BorderRound"
local SWIPE_DISC    = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local TEMPLATE      = "CustomAuraContainerTemplate"
local TIMER_SPACE   = 13      -- room under the icon for a timer placed below it
local SWIPE_ALPHA   = 0.7     -- how much the spent part of the border dims (Border swipe)
local ICON_SWIPE_ALPHA = 0.7  -- how dark the overlay over the icon is (Icon swipe)
local SWIPE_EDGE    = MEDIA .. "Edge"   -- the sweeping edge line of the Icon swipe
local PRIVATE_COUNT = 4       -- private aura anchors beside the debuffs

-- The dispel type names Blizzard keys its colour maps by ("None" = no dispel type)
local DISPEL_KEYS = { "None", "Magic", "Curse", "Disease", "Poison", "Bleed", "Enrage" }
-- Debuff borders by dispel type (bright, as they multiply the grey art)
local DEBUFF_COLORS = {
    None    = { 0.95, 0.32, 0.28 },
    Magic   = { 0.38, 0.65, 1.00 },
    Curse   = { 0.76, 0.42, 1.00 },
    Disease = { 0.92, 0.70, 0.30 },
    Poison  = { 0.45, 0.85, 0.38 },
}

-- Edit Mode preview: sample icons for every slot
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
    buffs   = { label = L["FlareUI Buffs"],   filter = "HELPFUL", isDebuff = false,
                default = { point = "TOPRIGHT", x = -290, y = -12 } },
    debuffs = { label = L["FlareUI Debuffs"], filter = "HARMFUL", isDebuff = true,
                default = { point = "TOPRIGHT", x = -290, y = -150 } },
}
local KIND_ORDER = { "buffs", "debuffs" }

--------------------------------------------------
-- 4. STATE
--------------------------------------------------
local frames = {}           -- kind -> holder frame (the Edit Mode frame)
local pendingLayout = false
local UpdatePreview         -- section 6
local hiddenParent = CreateFrame("Frame", nil, UIParent)
hiddenParent:Hide()

local function KindDb(kind)
    local db = GetDb()
    return db and db[kind]
end

-- Blizzard applies the map's colours with SetVertexColor(color:GetRGBA()). Four maps in all, cached.
local colorMaps = {}
local function ColorMap(isDebuff, round)
    local cacheKey = (isDebuff and "d" or "b") .. (round and "r" or "s")
    local map = colorMaps[cacheKey]
    if map then return map end
    map = {}
    for _, key in ipairs(DISPEL_KEYS) do
        local c = isDebuff and (DEBUFF_COLORS[key] or DEBUFF_COLORS.None) or (round and ROUND_TINT or SQUARE_TINT)
        map[key] = CreateColor(c[1], c[2], c[3], 1)
    end
    colorMaps[cacheKey] = map
    return map
end

-- The cell a frame's icons take: the icon, plus the timer's room when it sits under it
local function CellHeight(size)
    local db = GetDb()
    return size + ((db and db.timer == "below") and TIMER_SPACE or 0)
end

--------------------------------------------------
-- 5. AURA BUTTONS
-- initializeFrame: Blizzard calls it for every pooled button; the look is built once and restyled
-- on later calls (a new group generation passes the new settings).
--------------------------------------------------
local function StyleButton(button, look)
    local size, round = look.size, look.style == "round"
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

        -- layers, bottom up: icon (area), then border and cooldown in the order the swipe needs
        -- (StyleButton), then the text on top
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
        cd:SetReverse(true)     -- the spent part grows as the aura runs out
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

    -- square: the icon in the border's opening, clipped to its cut corners; round: under the ring's mask
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
    -- crop the icon's own built-in border away; ours is drawn over the edge
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    bg:ClearAllPoints()
    bg:SetAllPoints(icon)

    -- the swipe: a darkening sweep along the border's outline, over the whole icon, or none. Over
    -- the border it must draw above the border art; over the icon, below it.
    local base = area:GetFrameLevel()
    if look.swipe == "border" then
        button.FlareUI_BorderFrame:SetFrameLevel(base + 1)
        cd:SetFrameLevel(base + 2)
    else
        cd:SetFrameLevel(base + 1)
        button.FlareUI_BorderFrame:SetFrameLevel(base + 2)
    end
    button.FlareUI_Overlay:SetFrameLevel(base + 4)
    -- square with the Icon swipe: the sweep covers only the opening, in its cut shape
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
    else
        -- over the icon: a darker overlay, with a bright sweeping edge (Media/Auras/Edge.tga)
        cd:SetDrawSwipe(true)
        cd:SetSwipeTexture(round and SWIPE_DISC or SQUARE_MASK)
        cd:SetSwipeColor(0, 0, 0, ICON_SWIPE_ALPHA)
        cd:SetDrawEdge(true)
        cd:SetEdgeTexture(SWIPE_EDGE)
    end

    -- text: stacks top right on the icon, the timer under it or along its bottom edge
    local fontPath = ns.GetFontPath(look.font and look.font.face or "Friz Quadrata TT")
    local fontSize = (look.font and look.font.size) or 11
    local flags = (look.font and look.font.flags) or "OUTLINE"
    local countText, durationText = button.FlareUI_Count, button.FlareUI_Duration
    countText:SetFont(fontPath, fontSize, flags)
    durationText:SetFont(fontPath, math_max(8, fontSize - 1), flags)
    ns.ApplyShadow(countText, look.font)
    ns.ApplyShadow(durationText, look.font)
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
    -- No Timer: Blizzard still shows and fills the text, so it is hidden by alpha
    durationText:SetAlpha(look.timer == "none" and 0 or 1)
end

-- Hands our regions to Blizzard's aura button, which drives them from its aura
local function HookButton(button, look)
    local icon, cd, border = button.FlareUI_Icon, button.FlareUI_Cooldown, button.FlareUI_Border
    local countText, durationText = button.FlareUI_Count, button.FlareUI_Duration
    pcall(button.SetIcon, button, icon)
    pcall(button.SetDurationCooldown, button, cd)
    pcall(button.SetApplicationCount, button, countText, {})
    pcall(button.SetDurationText, button, durationText, {})
    pcall(button.ClearDispelTypeTextures, button)
    -- Blizzard tints the border from the colour map, whatever the (possibly secret) dispel type.
    -- Once handed over it is only restyled out of combat, before being handed over again.
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

-- A snapshot of one frame's settings, handed to every button Blizzard initialises
local function Look(kind)
    local db, kdb = GetDb(), KindDb(kind)
    return {
        size = kdb.size or 30,
        style = db.style or "square",
        swipe = db.swipe or "border",
        timer = db.timer or "below",
        font = db.font,
        isDebuff = KINDS[kind].isDebuff,
        colors = ColorMap(KINDS[kind].isDebuff, db.style == "round"),
    }
end

-- The same buttons for the unit and party frames' auras (whether or not this module is on), in each
-- frame's own look and the Aura Text font, sized to the icon
ns.AuraLook = {
    Style = StyleButton,
    Hook = HookButton,
    ForUnit = function(size, isDebuff, canCancel, style, swipe, timer)
        local uf = ns.db and ns.db.profile and ns.db.profile.unitframes or {}
        style, timer = style or "square", timer or "below"
        local fontSize = math_max(7, math_floor(size * 0.4 + 0.5))
        local font = setmetatable({ size = fontSize }, { __index = uf.auraFont or {} })
        return {
            size = size,
            style = style,
            swipe = swipe or "icon",
            timer = timer,
            font = font,
            isDebuff = isDebuff,
            cancel = canCancel,
            colors = ColorMap(isDebuff, style == "round"),
            cellHeight = size + ((timer == "below") and (fontSize + 3) or 0),
        }
    end,
}

--------------------------------------------------
-- 6. LAYOUT
-- The holder is as big as the grid can grow, so the Edit Mode box shows the full reach; the
-- container fills it from its starting corner.
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

-- Edit Mode: samples in every slot up to Max Icons, in the chosen look (plain frames, not Blizzard's)
function UpdatePreview(kind)
    local holder, kdb = frames[kind], KindDb(kind)
    if not (holder and kdb) then return end
    local editing = LEM:IsInEditMode()
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
            -- a long running cooldown, each slot at a different point, to show the swipe
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

-- Private auras: a row just outside the holder, on the side the grid wraps towards
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
-- WEAPON ENCHANTS
-- Poisons, oils, stones and shaman imbues live on the weapon, not on the player, so no aura API
-- returns them. Blizzard's aura container reads them from C_PaperDollInfo.GetTemporaryEnchantmentInfo,
-- which Forever leaves empty; Forever's own buff frame reads C_Item.GetWeaponEnchantInfo, and so do
-- these buttons. They are FlareUI's frames, in the buffs' look, at the start of the first row: the
-- container is moved along by as many cells (out of combat; in combat a new enchant sits just
-- before the first row until combat ends).
--------------------------------------------------
-- Enum.WeaponSlot (0 main hand, 1 off hand, 2 ranged) -> the inventory slot the tooltip shows
local WEAPON_SLOTS = { { slot = 0, inv = 16 }, { slot = 1, inv = 17 }, { slot = 2, inv = 18 } }
local enchantDurations = {}   -- "slot:type" -> the full duration, snapshot when the enchant is seen first

-- the timed enchants on the weapons now, in slot order
local function ActiveEnchants()
    local list = {}
    if not (C_Item and C_Item.GetWeaponEnchantInfo) then return list end
    local db = GetDb()
    if not db or db.weaponEnchants == false then return list end
    local now = GetTime()
    for _, weapon in ipairs(WEAPON_SLOTS) do
        local ok, enchants = pcall(C_Item.GetWeaponEnchantInfo, weapon.slot)
        for _, e in ipairs(ok and enchants or {}) do
            -- a permanent enchant (no time left) is part of the item, not a buff
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
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetInventoryItem("player", self.enchant.weapon.inv)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- no right-click cancel: removing a weapon enchant is a Blizzard-only action in Forever (blocked for
    -- addons, and the secure cancelaura route reads a CANCELABLE_ITEMS table Forever never defines)
    holder.enchants[i] = b
    return b
end

local function EnchantTimer(holder)
    local now = GetTime()
    for _, b in ipairs(holder.enchants or {}) do
        if b:IsShown() and b.enchant then
            local left = math_max(0, b.enchant.expires - now)
            b.FlareUI_Duration:SetFormattedText(SecondsToTimeAbbrev(left))
        end
    end
end

-- the cells the container is moved along by (set by LayoutKind, out of combat)
local function PlaceContainer(holder, kdb, corner, width)
    local container = holder.container
    local n = (not LEM:IsInEditMode() and holder.activeEnchants) or 0
    local step = (kdb.size or 30) + (kdb.spacing or 6)
    holder.enchantShift = n
    container:ClearAllPoints()
    container:SetPoint(corner, holder, corner, n * step * ((kdb.grow == "RIGHT") and 1 or -1), 0)
    pcall(container.SetFlowLayoutMaximumLineSize, container, math_max(step, width - n * step))
end

local function UpdateEnchants(kind)
    local holder, kdb = frames[kind], KindDb(kind)
    if not (holder and kdb) or KINDS[kind].isDebuff then return end
    local list = LEM:IsInEditMode() and {} or ActiveEnchants()
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
    holder:SetScript("OnUpdate", #list > 0 and function(self, elapsed)
        self.enchantTick = (self.enchantTick or 0) + elapsed
        if self.enchantTick < 0.5 then return end
        self.enchantTick = 0
        EnchantTimer(self)
    end or nil)
    EnchantTimer(holder)
    -- the container makes room for them once combat allows
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
    -- retire the previous generation of groups (keys must be unique per container)
    for _, key in ipairs(holder.groups) do
        pcall(container.SetAuraGroupEnabled, container, key, false)
        pcall(container.SetAuraGroupMaxFrameCount, container, key, 0)
    end
    holder.groups = {}
    holder.generation = holder.generation + 1

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
    local key = kind .. holder.generation
    local ok, err = pcall(container.AddAuraGroup, container, key, KINDS[kind].filter, {
        maxFrameCount = kdb.max or 32,
        -- in the order they were gained; the container compares the ids, never our code
        sortMethod = AuraContainerSortMethod and AuraContainerSortMethod.AuraInstanceIDOnly,
        initializeFrame = function(button) StyleButton(button, look); HookButton(button, look) end,
        layout = layout,
    })
    if ok then
        holder.groups[#holder.groups + 1] = key
    else
        print("|cffff0000FlareUI:|r aura frame failed: " .. tostring(err))
    end

    if KINDS[kind].isDebuff then LayoutPrivateAnchors(holder, kdb) end

    pcall(container.SetEnabled, container, true)
    UpdatePreview(kind)
    UpdateEnchants(kind)
    pcall(container.UpdateAllAuras, container)
end

--------------------------------------------------
-- 7. POSITION (per Edit Mode layout)
--------------------------------------------------
local function GetLayoutStore(layoutName)
    local db = GetDb()
    if not db then return nil end
    layoutName = layoutName or LEM:GetActiveLayoutName() or "Modern"
    db.layouts = db.layouts or {}
    db.layouts[layoutName] = db.layouts[layoutName] or {}
    return db.layouts[layoutName]
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
-- 8. EDIT MODE SETTINGS
--------------------------------------------------
local GROW_VALUES = {
    { text = L["Left"],  value = "LEFT",  isRadio = true },
    { text = L["Right"], value = "RIGHT", isRadio = true },
}
local WRAP_VALUES = {
    { text = L["Down"], value = "DOWN", isRadio = true },
    { text = L["Up"],   value = "UP",   isRadio = true },
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
    return {
        { name = L["Icon Size"], kind = LEM.SettingType.Slider, default = defaults.size or 30, minValue = 16, maxValue = 64, valueStep = 1,
          get = get("size"), set = set("size") },
        { name = L["Icons per Row"], kind = LEM.SettingType.Slider, default = defaults.perRow or 12, minValue = 1, maxValue = 40, valueStep = 1,
          get = get("perRow"), set = set("perRow") },
        { name = L["Max Icons"], kind = LEM.SettingType.Slider, default = defaults.max or 32, minValue = 1, maxValue = 40, valueStep = 1,
          get = get("max"), set = set("max") },
        { name = L["Spacing"], kind = LEM.SettingType.Slider, default = defaults.spacing or 6, minValue = 0, maxValue = 20, valueStep = 1,
          get = get("spacing"), set = set("spacing") },
        { name = L["Grow"], kind = LEM.SettingType.Dropdown, default = defaults.grow or "LEFT", values = GROW_VALUES,
          get = get("grow"), set = set("grow") },
        { name = L["Wrap"], kind = LEM.SettingType.Dropdown, default = defaults.wrap or "DOWN", values = WRAP_VALUES,
          get = get("wrap"), set = set("wrap") },
    }
end

--------------------------------------------------
-- 9. BLIZZARD'S FRAMES (parked for the session)
--------------------------------------------------
local function HideBlizzard(name)
    local frame = _G[name]
    if not frame or frame.FlareUI_Hidden then return end
    frame.FlareUI_Hidden = true
    pcall(frame.UnregisterAllEvents, frame)
    if not InCombatLockdown() then
        pcall(ns.RawHide, frame)
        pcall(frame.SetParent, frame, hiddenParent)
    end
    hooksecurefunc(frame, "Show", function(f) if not InCombatLockdown() then ns.RawHide(f) end end)
end

--------------------------------------------------
-- 10. SETUP
--------------------------------------------------
local function CreateHolder(kind)
    local info = KINDS[kind]
    local holder = CreateFrame("Frame", "FlareUI_" .. (info.isDebuff and "Debuffs" or "Buffs"), UIParent)
    holder.kind = kind
    holder:SetFrameStrata("LOW")
    holder:SetSize(1, 1)
    holder.groups = {}
    holder.generation = 0

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

    for _, kind in ipairs(KIND_ORDER) do
        ApplyPosition(kind)
        LayoutKind(kind)
    end

    LEM:RegisterCallback("layout", function(layoutName)
        for _, kind in ipairs(KIND_ORDER) do ApplyPosition(kind, layoutName) end
    end)
    LEM:RegisterCallback("enter", function() SetPreview() AU:Refresh() end)
    LEM:RegisterCallback("exit", function() SetPreview() AU:Refresh() end)

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    for _, event in ipairs({ "WEAPON_ENCHANT_CHANGED", "WEAPON_SLOT_CHANGED", "PLAYER_EQUIPMENT_CHANGED" }) do
        pcall(events.RegisterEvent, events, event)
    end
    pcall(events.RegisterUnitEvent, events, "UNIT_INVENTORY_CHANGED", "player")
    events:SetScript("OnEvent", function(_, event)
        if event ~= "PLAYER_REGEN_ENABLED" then
            UpdateEnchants("buffs")
            return
        end
        if not pendingLayout then return end
        pendingLayout = false
        for _, kind in ipairs(KIND_ORDER) do
            ApplyPosition(kind)
            LayoutKind(kind)
        end
    end)
end
