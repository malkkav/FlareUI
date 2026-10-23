local _, ns = ...
local L = ns.L

--------------------------------------------------
-- RADIAL MENU
-- Hold the binding, sweep the mouse, release to fire the aimed button; works in combat. The radial
-- is plain art; one SecureActionButton (the caster) fires, and a secure snippet picks the button
-- with the same maths and writes its attributes. Macros open radials in click mode (section 10).
--------------------------------------------------

--------------------------------------------------
-- 1. MODULE REGISTRATION
--------------------------------------------------
ns.RadialMenu = ns.RadialMenu or {}
local RM = ns.RadialMenu
ns.modules["RadialMenu"] = RM

LibStub("AceEvent-3.0"):Embed(RM)

--------------------------------------------------
-- 2. UPVALUES
--------------------------------------------------
local _G = _G
local ipairs = ipairs
local math_cos, math_sin, math_atan2, math_floor, math_max, math_min, math_pi =
      math.cos, math.sin, math.atan2, math.floor, math.max, math.min, math.pi
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local GetCursorPosition = GetCursorPosition
local GetTime = GetTime

--------------------------------------------------
-- 3. CONSTANTS
-- Geometry and selection follow Blizzard_RadialWheel.lua (the ping wheel): button one at the top, a
-- cancel dead zone in the middle, the pointer turned to the cursor angle.
--------------------------------------------------
local TAU = math_pi * 2
local QUARTER = math_pi / 2

local CASTER_NAME  = "FlareUI_RadialCaster"
local WHEEL_NAME   = "FlareUI_RadialWheel"
local CATCHER_NAME = "FlareUI_RadialCatcher"
local MACRO_NAME   = "FUIRadial"   -- the button macros /click; kept short, users type it
local PAD_NAME     = "FlareUI_RadialPad"   -- what the stick press clicks in controller mode
local PAD_CANCEL   = GAMEPAD_FACE_RIGHT or "PAD2"   -- B / Circle closes a controller radial
local PAD_PREV     = GAMEPAD_SHOULDER_LEFT or "PADLSHOULDER"    -- LB / RB: the aimed slot's previous /
local PAD_NEXT     = GAMEPAD_SHOULDER_RIGHT or "PADRSHOULDER"   -- next sub-radial button (the mouse wheel's job)
local PAD_DEAD_LEN = 0.5          -- a stick pushed less than this aims at nothing (the X)

local ATLAS_POINTER       = "Radial_Wheel_Select_Pointer"
local ATLAS_CIRCLE_MASK   = "CircleMaskScalable"
local ATLAS_CANCEL_ICON   = "Radial_Wheel_Icon_Close"
local ATLAS_CANCEL_PAD    = "gamepad-xb-32x-rstick"   -- the Gamepad UI: the aiming stick, as Blizzard's ping wheel
local ATLAS_CANCEL_SELECT = "Radial_Wheel_Select_Close"
local CANCEL_ICON_SIZE    = 24
local CANCEL_SELECT_SIZE  = 48
local CANCEL_ALPHA_IDLE   = 0.5
local POINTER_SIZE = 84   -- turned to the raw atan2 angle, as Blizzard's

local DEAD_ZONE_SQ = 500          -- cursor closer than this to the centre selects nothing
local ICON_SIZE    = 46
-- radius from the button count: 90 up to four buttons, then 7.5 more per button (150 at twelve)
local RADIUS_MIN, RADIUS_FLAT_BUTTONS, RADIUS_PER_BUTTON = 90, 4, 7.5
local ROUND_SIZE   = 52           -- outer diameter of a round button
local ROUND_BORDER = 3            -- rim thickness for the drawn fallback
local ROUND_ICON   = ROUND_SIZE - ROUND_BORDER * 2

-- The first rim style whose atlases the client has (they are not in the API export, so it is
-- checked in the client). The azerite rim has its own padding, hence the smaller icon.
local ROUND_STYLES = {
    {
        mask = "talents-node-circle-mask",
        idle = "talents-node-circle-gray",
        idleTint = { 0.92, 0.76, 0.52 },   -- warms the neutral silver towards the UI's bronze
        iconFactor = 1.00,
    },
    {
        mask = "CircleMaskScalable",
        idle = "Azerite-Trait-Ring",
        iconFactor = 0.74,
    },
}
local RIM_TINT_NONE = { 1, 1, 1 }
local BORDER_COLOR         = { 0.45, 0.33, 0.19 }   -- the drawn fallback rim, the panel frames' brown
local ICON_SCALE_IDLE      = 0.88   -- the hovered button is full size

-- tinted as Blizzard's action buttons; the portrait-mask swipe stays inside the round icon
local TINT_USABLE   = { 1, 1, 1 }
local TINT_UNUSABLE = { 0.4, 0.4, 0.4 }
local TINT_NO_MANA  = { 0.5, 0.5, 1 }
local SWIPE_TEXTURE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

-- Ping wheel look. Blizzard's divider and slice-light art exists for four slices only, so FlareUI
-- ships its own and cuts the light to any slice width with two rotated half-plane masks.
local MEDIA = "Interface\\AddOns\\FlareUI\\Media\\Radial\\"
local PING = {
    BG_ATLAS = "Radial_Wheel_BG",
    DIVIDER = MEDIA .. "Divider.tga", RING = MEDIA .. "Ring.tga",
    GLOW = MEDIA .. "SliceGlow.tga", MASK = MEDIA .. "HalfMask.tga",
    BG_FACTOR = 3.1, BG_MIN = 300,      -- backdrop size against the button radius
    RING_SIZE = 56, HUB = 24,           -- the hub ring, and where the dividers start
    GLOW_SIZE = 400,                    -- the light's inner edge meets the hub ring at this size
    DIVIDER_THICKNESS = 4,
    DIVIDER_COLOR = { 0.58, 0.44, 0.25, 0.85 },   -- frame bronze, dimmed
    RING_COLOR = { 0.45, 0.33, 0.19, 1 },
    LIT_COLOR = { 1, 0.80, 0.25 },
    GLOW_ALPHA = 0.5,
    LIT_DIVIDER_ALPHA = 0.7,
    -- Blizzard_RadialWheel.lua's timings: fade in / out while the icons glide SLIDE px
    INTRO = 0.2, OUTRO = 0.13, SLIDE = 20,
    LABEL_GAP = 4,
    LABEL_WRAP = 16,                    -- a name of several words this long goes on two lines
    -- a sub-radial's page dots along the bottom of the rim
    DOT = MEDIA .. "Dot.tga",
    DOT_SIZE = 6, DOT_SIZE_ON = 7,
    DOT_STEP = math.rad(13),           -- between two dots, round the rim
    DOT_GAP = 6,                       -- outside the rim
    DOT_COLOR = { 0.85, 0.85, 0.85, 0.55 },
    DOT_COLOR_ON = { 1, 0.80, 0.25, 1 },
}

local STUCK_OPEN_SECONDS = 20     -- see the guard in UpdateSelection

local MAX_BUTTONS = 12
local MAX_EXTRA_KEYS = 5           -- extra keybinds per character
local MAX_RADIAL_DEPTH = 4

local radial, caster, header, wheel, buttons = nil, nil, nil, nil, {}
local catcher, macroButton          -- click mode's full-screen catcher, and the button macros click
local padButton                     -- controller mode's button, clicked by the stick press
local padStickIndex = 2             -- the right stick in C_GamePad's mapped state (RightStickIndex)
local isOpen, selectedIndex, currentRadial = false, nil, nil
local currentID                     -- the radial id currentRadial belongs to
local openMode                      -- "hold" (the keybind), "click" (a macro) or "pad"
local resolved = {}               -- currentRadial resolved to names / icons / attributes
local resolvedCache = {}          -- every radial resolved, as the secure layer holds them
local syncedIDs = {}              -- radial ids written to the secure layer, to retire deleted ones
local syncedTags = {}             -- macro tags written to the secure layer, to retire renamed ones
local openedAt = 0
local previewID, previewAnchor     -- set while the radial editor is open
local CloseRadial                   -- section 9
local SyncSecure                  -- section 10
local layoutPending               -- a layout held back by combat

--------------------------------------------------
-- 4. HELPERS
--------------------------------------------------
local function RadialRadius(count)
    return RADIUS_MIN + math_max(0, count - RADIUS_FLAT_BUTTONS) * RADIUS_PER_BUTTON
end

-- false: no style available, the drawn rim takes over
local roundStyle
local function RoundStyle()
    if roundStyle ~= nil then return roundStyle or nil end
    local exists = C_Texture and (C_Texture.GetAtlasExists
        or (C_Texture.GetAtlasInfo and function(name) return C_Texture.GetAtlasInfo(name) ~= nil end))
    if exists then
        for _, style in ipairs(ROUND_STYLES) do
            if exists(style.mask) and exists(style.idle) then
                roundStyle = style
                return style
            end
        end
    end
    roundStyle = false
    return nil
end

-- profile options; the radials themselves are account-wide, in global
local function ShowNames()
    local db = ns.db and ns.db.profile and ns.db.profile.radialmenu
    return not (db and db.showNames == false)
end

-- the secure layer reads its own copy ("flare-center" / "flare-toggle", set by SyncSecure)
local function Option(key, default)
    local db = ns.db and ns.db.profile and ns.db.profile.radialmenu
    local value = db and db[key]
    if value == nil then return default end
    return value
end

local function CursorPosition()
    local scale = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    return x / scale, y / scale
end

--------------------------------------------------
-- 5. ACTIONS
-- A stored button ({ kind = "spell", id = 133 }) resolves to name, icon ({ atlas } or { texture })
-- and the attributes of one of Blizzard's SECURE_ACTIONS handlers.
--------------------------------------------------
local ACTIONS = {}
local ResolveEntry                -- ACTIONS.subradial recurses through it

-- Panels open through a macro on the secure button (a micro button /click or Blizzard's toggle):
-- opened from a tainted call, a panel taints its frames and secret comparisons there then fail.
local MICRO_PANELS = {
    bags        = { order = 1,  label = L["Bags"],         icon = 133633,  button = "MainMenuBarBackpackButton",
                    macrotext = "/run ToggleAllBags()" },
    character   = { order = 2,  label = L["Character"],    icon = 136047,  button = "CharacterMicroButton" },
    collections = { order = 3,  label = L["Collections"],  icon = 132261,  button = "CollectionsMicroButton" },
    groupfinder = { order = 4,  label = L["Group Finder"], icon = 132161,  button = "LFDMicroButton" },
    guild       = { order = 5,  label = L["Guild & Communities"],          button = "GuildMicroButton" },
    legacy      = { order = 6,  label = L["Legacy"],       icon = 4279397, button = "LegacyMicroButton" },
    macros      = { order = 6.5, label = L["Macros"],     icon = "Interface\\Icons\\INV_Misc_Note_06", macrotext = "/macro" },
    professions = { order = 7,  label = L["Professions"],  icon = 4202228, button = "ProfessionMicroButton" },
    quests      = { order = 8,  label = L["Quest Log"],    icon = 8197102, button = "QuestLogMicroButton" },
    social      = { order = 9,  label = L["Social"],       icon = "Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend",
                    button = "QuickJoinToastButton", macrotext = "/run ToggleFriendsFrame()" },
    spellbook   = { order = 10, label = L["Spellbook"],    icon = 133741,  button = "SpellbookMicroButton" },
    talents     = { order = 11, label = L["Talents"],      icon = 132222,  button = "TalentMicroButton" },
    flareui     = { order = 12, label = L["FlareUI Settings"], icon = "Interface\\AddOns\\FlareUI\\Media\\Art\\Icon.png",
                    macrotext = "/run FlareUI_ToggleSettings()" },
    threat      = { order = 13, label = L["Toggle Threat Meter"], icon = "Interface\\Icons\\Ability_Physical_Taunt",
                    macrotext = "/run FlareUI_ToggleThreatMeter()" },
}
RM.MICRO_PANELS = MICRO_PANELS

local GUILD_ICON = "Interface\\Icons\\INV_Shirt_GuildTabard_01"

-- the lookup APIs raise an error on a nil id, so id-based resolvers bail out first
ACTIONS.spell = function(entry)
    if not entry.id then return nil end
    local info = C_Spell.GetSpellInfo(entry.id)
    if not info then return nil end
    return info.name, { texture = info.iconID }, { type = "spell", spell = entry.id }
end

ACTIONS.mount = function(entry)
    if not (entry.id and C_MountJournal) then return nil end
    local name, spellID, icon = C_MountJournal.GetMountInfoByID(entry.id)
    if not (name and spellID) then return nil end
    return name, { texture = icon }, { type = "spell", spell = spellID }
end

-- Blizzard's "item" action needs a NAME (an ID parses as a bag slot); an uncached name leaves the
-- button out until ITEM_DATA_LOAD_RESULT
local awaitedItems = {}   -- item id -> true while a radial waits for its data
ACTIONS.item = function(entry)
    if not entry.id then return nil end
    local name = C_Item.GetItemNameByID(entry.id)
    if not name then
        awaitedItems[entry.id] = true
        C_Item.RequestLoadItemDataByID(entry.id)
        return nil
    end
    local icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(entry.id)
    return name, { texture = icon }, { type = "item", item = name }
end

ACTIONS.macro = function(entry)
    return entry.name or L["Macro"], { texture = entry.icon or 134400 },
        { type = "macro", macrotext = entry.text or "" }
end

-- marker 0 clears the target's mark instead of setting one
ACTIONS.targetmarker = function(entry)
    local m = entry.marker or 1
    if m == 0 then
        return _G.RAID_TARGET_NONE or "Clear Marker", { atlas = "GM-raidMarker-remove" },
            { type = "raidtarget", unit = "target", marker = 0, action = "clear" }
    end
    return (_G["RAID_TARGET_" .. m] or ("Marker " .. m)),
        { texture = ("Interface\\TargetingFrame\\UI-RaidTargetingIcon_%d"):format(m) },
        { type = "raidtarget", unit = "target", marker = m, action = "toggle" }
end

-- marker 0 clears every world marker (the secure handler treats a nil marker as "all")
ACTIONS.worldmarker = function(entry)
    local m = entry.marker or 1
    if m == 0 then
        return _G.REMOVE_WORLD_MARKERS or "Clear All", { atlas = "GM-raidMarker-remove" },
            { type = "worldmarker", action = "clear" }
    end
    return ((_G.WORLD_MARKER or "World Marker %d"):format(m)), { atlas = "GM-raidMarker" .. m },
        { type = "worldmarker", marker = m, action = "toggle" }
end

ACTIONS.micromenu = function(entry)
    local panel = MICRO_PANELS[entry.panel]
    if not panel then return nil end
    local icon = { texture = panel.icon or GUILD_ICON }

    -- Blizzard's own button first: /run is forced insecure, and a panel opened from it in the
    -- Gamepad UI is blocked (ForceTaint_Strong) when Blizzard hands it the controller
    if panel.button and _G[panel.button] then
        -- /click, not a clickbutton attribute: the secure layer copies plain values only
        return panel.label, icon, { type = "macro", macrotext = "/click " .. panel.button }
    end
    if panel.macrotext then
        return panel.label, icon, { type = "macro", macrotext = panel.macrotext }
    end
    return nil
end

-- the chat menu's animated emotes, run as their localised slash command; Blizzard has no icons
local EMOTES = {
    { token = "WAVE",    icon = "Achievement_Reputation_01" },
    { token = "BOW",     icon = "Spell_Holy_PrayerofSpirit" },
    { token = "DANCE",   icon = "Ability_Rogue_ShadowDance" },
    { token = "APPLAUD", icon = "Achievement_BG_winWSG" },
    { token = "BEG",     icon = "INV_Misc_Coin_02" },
    { token = "CHICKEN", icon = "INV_Chicken2_Brown" },
    { token = "CRY",     icon = "Spell_Misc_EmotionSad" },
    { token = "EAT",     icon = "INV_Misc_Food_95_Grainbread" },
    { token = "FLEX",    icon = "Ability_Warrior_StrengthOfArms" },
    { token = "KISS",    icon = "Spell_Shadow_SoothingKiss" },
    { token = "LAUGH",   icon = "Spell_Misc_EmotionHappy" },
    { token = "POINT",   icon = "Ability_Hunter_SniperShot" },
    { token = "ROAR",    icon = "Ability_Druid_ChallangingRoar" },
    { token = "RUDE",    icon = "Spell_Misc_EmotionAngry" },
    { token = "SALUTE",  icon = "Ability_Warrior_BattleShout" },
    { token = "SHY",     icon = "Ability_Druid_Cower" },
    { token = "TALK",    icon = "Spell_Holy_HolyGuidance" },
    { token = "STAND",   icon = "Achievement_Character_Human_Male" },
    { token = "SIT",     icon = "Spell_Misc_Drink" },
    { token = "SLEEP",   icon = "Spell_Nature_Sleep" },
    { token = "KNEEL",   icon = "Ability_Paladin_BlessedHands" },
    { token = "LEAN",    icon = "Ability_Rogue_Disguise" },
}
RM.EMOTES = EMOTES
local emoteByToken
local function EmoteInfo(token)
    if not emoteByToken then
        emoteByToken = {}
        for _, e in ipairs(EMOTES) do emoteByToken[e.token] = e end
    end
    return emoteByToken[token]
end

-- an emote token's slash command ("/wave"), found as Blizzard's chat menu does
local emoteCommands = {}
local function EmoteCommand(token)
    if emoteCommands[token] then return emoteCommands[token] end
    local command
    for i = 1, (MAXEMOTEINDEX or 1000) do
        local t = _G["EMOTE" .. i .. "_TOKEN"]
        if t == token then command = _G["EMOTE" .. i .. "_CMD1"] break end
    end
    command = command or ("/" .. token:lower())
    emoteCommands[token] = command
    return command
end

ACTIONS.emote = function(entry)
    local info = entry.emote and EmoteInfo(entry.emote)
    if not info then return nil end
    local command = EmoteCommand(info.token)
    -- "/wave" -> "Wave"
    local name = command:gsub("^/", "")
    name = name:sub(1, 1):upper() .. name:sub(2)
    return name, { texture = "Interface\\Icons\\" .. info.icon }, { type = "macro", macrotext = command }
end

-- A button standing for another radial: it shows one resolved child at a time and the mouse wheel
-- steps through them. seen holds the radials on the current path, so no radial contains itself.
ACTIONS.subradial = function(entry, depth, seen)
    local id = entry.radial
    if not id or depth >= MAX_RADIAL_DEPTH or seen[id] then return nil end
    local data = RM:GetRadial(id)
    if not data then return nil end

    seen[id] = true
    local children = {}
    for i = 1, #data.buttons do
        if #children >= MAX_BUTTONS then break end
        local child = ResolveEntry(data.buttons[i], depth + 1, seen)
        if child then children[#children + 1] = child end
    end
    seen[id] = nil
    if #children == 0 then return nil end

    local first = children[1]
    return first.name, first.icon, first.attributes,
        { children = children, childIndex = 1, radialName = data.name, radialID = id }
end

-- nil when unavailable (uncollected mount, missing item...): the radial closes up around it
local UNKNOWN_ICON = 134400

function ResolveEntry(entry, depth, seen)
    local resolver = entry and ACTIONS[entry.kind]
    if not resolver then return nil end
    local name, icon, attributes, extra = resolver(entry, depth or 0, seen or {})
    if not attributes then return nil end
    local info = { name = name, icon = icon or { texture = UNKNOWN_ICON }, attributes = attributes, entry = entry }
    if extra then
        for key, value in pairs(extra) do info[key] = value end
    end
    return info
end

-- a new account's first radial
local function MarkerButtons()
    local t = {}
    for i = 1, 8 do t[i] = { kind = "targetmarker", marker = i } end
    return t
end

RM.ResolveEntry = function(_, entry) return ResolveEntry(entry) end
RM.MAX_BUTTONS = MAX_BUTTONS

--------------------------------------------------
-- 6. RADIAL FRAME
--------------------------------------------------
local function CreateRadialButton(index)
    local button = CreateFrame("Frame", nil, radial)
    button:SetSize(ICON_SIZE, ICON_SIZE)

    local style = RoundStyle()

    -- fallback rim without rim art: a colour disc clipped to a circle (RimArt otherwise)
    button.Rim = button:CreateTexture(nil, "BACKGROUND")
    button.Rim:SetColorTexture(1, 1, 1)
    button.Rim:SetPoint("CENTER")
    button.Rim:SetSize(ROUND_SIZE, ROUND_SIZE)
    button.Rim:Hide()

    button.RimMask = button:CreateMaskTexture()
    button.RimMask:SetAtlas(ATLAS_CIRCLE_MASK)
    button.RimMask:SetAllPoints(button.Rim)
    button.Rim:AddMaskTexture(button.RimMask)

    -- anchored by ApplyButtonShape
    button.Icon = button:CreateTexture(nil, "ARTWORK")

    button.Mask = button:CreateMaskTexture()
    button.Mask:SetAtlas(style and style.mask or ATLAS_CIRCLE_MASK)
    button.Mask:SetAllPoints(button.Icon)

    button.RimArt = button:CreateTexture(nil, "OVERLAY", nil, 1)
    button.RimArt:SetPoint("CENTER")
    button.RimArt:SetSize(ROUND_SIZE, ROUND_SIZE)
    button.RimArt:Hide()

    button.Cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.Cooldown:SetAllPoints(button.Icon)
    button.Cooldown:SetSwipeTexture(SWIPE_TEXTURE)
    button.Cooldown:SetDrawEdge(false)
    button.Cooldown:SetDrawBling(false)

    -- the hovered button's name, on a frame above the cooldown swipe
    button.Front = CreateFrame("Frame", nil, button)
    button.Front:SetAllPoints()
    button.Front:SetFrameLevel(button.Cooldown:GetFrameLevel() + 2)
    button.Label = button.Front:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    button.Label:SetShadowColor(0, 0, 0, 1)
    button.Label:SetShadowOffset(1, -1)
    button.Label:Hide()

    button.Dots = {}   -- a sub-radial's page dots

    button.index = index
    return button
end

-- Blizzard_RadialWheel.lua's rule: the name sits on the button's outer side
local function PlaceLabel(button, angle)
    local a = angle % TAU
    local q, gap = math_pi / 4, PING.LABEL_GAP
    local label = button.Label
    label:ClearAllPoints()
    if a > q and a <= math_pi - q then
        label:SetPoint("BOTTOM", button, "TOP", 0, gap)
        label:SetJustifyH("CENTER")
    elseif a > math_pi - q and a <= math_pi + q then
        label:SetPoint("RIGHT", button, "LEFT", -gap, 0)
        label:SetJustifyH("RIGHT")
    elseif a > math_pi + q and a <= TAU - q then
        label:SetPoint("TOP", button, "BOTTOM", 0, -gap - 8)   -- clear of the page dots
        label:SetJustifyH("CENTER")
    else
        label:SetPoint("LEFT", button, "RIGHT", gap, 0)
        label:SetJustifyH("LEFT")
    end
end

-- A long multi-word name splits at the most even space. By length, not measured: the first layout
-- after a reload can run before the font is ready.
local function SetLabelText(button, text)
    text = text or ""
    if #text >= PING.LABEL_WRAP then
        local best, bestCost
        for pos in text:gmatch("() ") do
            local cost = math_max(pos - 1, #text - pos)
            if not bestCost or cost < bestCost then best, bestCost = pos, cost end
        end
        if best then text = text:sub(1, best - 1) .. "\n" .. text:sub(best + 1) end
    end
    button.Label:SetText(text)
end

-- one dot per child under the button, the current one lit; none for 0 or 1
local function SetPageDots(button, count, current)
    local dots = button.Dots
    local shown = count and count > 1 and count or 0
    local radius = ROUND_SIZE / 2 + PING.DOT_GAP
    for i = 1, math_max(shown, #dots) do
        local dot = dots[i]
        if i <= shown then
            if not dot then
                dot = button.Front:CreateTexture(nil, "OVERLAY")
                dot:SetTexture(PING.DOT)
                dots[i] = dot
            end
            -- straight down is -90 degrees; the row runs left to right, so the angle falls
            local a = -QUARTER - ((i - 1) - (shown - 1) / 2) * PING.DOT_STEP
            local on = i == current
            local c = on and PING.DOT_COLOR_ON or PING.DOT_COLOR
            local size = on and PING.DOT_SIZE_ON or PING.DOT_SIZE
            dot:ClearAllPoints()
            dot:SetPoint("CENTER", button, "CENTER", math_cos(a) * radius, math_sin(a) * radius)
            dot:SetSize(size, size)
            dot:SetVertexColor(c[1], c[2], c[3], c[4])
            dot:Show()
        elseif dot then
            dot:Hide()
        end
    end
end

local function ApplyButtonShape(button)
    local style = RoundStyle()
    button.Icon:ClearAllPoints()
    button.Icon:SetPoint("CENTER")
    local size = style and (ROUND_SIZE * style.iconFactor) or ROUND_ICON
    button.Icon:SetSize(size, size)
    if not button.masked then
        button.Icon:AddMaskTexture(button.Mask)
        button.masked = true
    end
    button.RimArt:SetShown(style ~= nil)
    button.Rim:SetShown(style == nil)
    if style then
        button.RimArt:SetAtlas(style.idle)
        local t = style.idleTint or RIM_TINT_NONE
        button.RimArt:SetVertexColor(t[1], t[2], t[3])
    else
        button.Rim:SetVertexColor(BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3])
    end
end

-- icon files get the border crop; atlases carry their own coordinates
local function SetButtonIcon(button, icon)
    if icon and icon.atlas then
        button.Icon:SetTexCoord(0, 1, 0, 1)
        button.Icon:SetAtlas(icon.atlas)
    else
        button.Icon:SetTexture((icon and icon.texture) or UNKNOWN_ICON)
        button.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end
end

local function SetButtonSelected(button, selected)
    button:SetScale(selected and 1 or ICON_SCALE_IDLE)
    button.Label:SetShown(selected and ShowNames() and (button.Label:GetText() or "") ~= "")
end

-- Cooldown swipe and usable tint for what a button fires now. Spell cooldowns go through a duration
-- object (works when secret, GCD left out); anything unreadable looks usable.
local function Readable(value)
    return value ~= nil and canaccessvalue(value)
end

local function ApplyButtonState(button, info)
    if not (button and info) then return end
    local action = info.children and info.children[info.childIndex or 1] or info
    local attributes, entry = action.attributes, action.entry
    local cooldown = button.Cooldown
    local usable, noMana = true, false

    if attributes and attributes.type == "spell" and attributes.spell then
        local id = attributes.spell
        local cd = C_Spell.GetSpellCooldown(id)
        local duration = cd and Readable(cd.isActive) and cd.isActive and C_Spell.GetSpellCooldownDuration(id, true)
        if duration then cooldown:SetCooldownFromDurationObject(duration) else cooldown:Clear() end
        local isUsable, isNoMana = C_Spell.IsSpellUsable(id)
        if Readable(isUsable) then usable, noMana = isUsable, Readable(isNoMana) and isNoMana end
    elseif attributes and attributes.type == "item" and entry and entry.id then
        local start, duration, enabled = C_Item.GetItemCooldown(entry.id)
        if Readable(start) and Readable(duration) and Readable(enabled) and enabled and duration > 0 then
            cooldown:SetCooldown(start, duration)
        else
            cooldown:Clear()
        end
        local isUsable, isNoMana = C_Item.IsUsableItem(entry.id)
        if Readable(isUsable) then usable, noMana = isUsable, Readable(isNoMana) and isNoMana end
    else
        cooldown:Clear()
    end

    local t = usable and TINT_USABLE or (noMana and TINT_NO_MANA or TINT_UNUSABLE)
    button.Icon:SetVertexColor(t[1], t[2], t[3])
end

local function RefreshButtonStates()
    for i, info in ipairs(resolved) do ApplyButtonState(buttons[i], info) end
end

-- registered only while the radial is up
local stateEvents = CreateFrame("Frame")
stateEvents:SetScript("OnEvent", RefreshButtonStates)
local STATE_EVENTS = { "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_USABLE", "BAG_UPDATE_COOLDOWN", "ACTIONBAR_UPDATE_USABLE" }

local function WatchButtonStates(watch)
    for _, event in ipairs(STATE_EVENTS) do
        if watch then stateEvents:RegisterEvent(event) else stateEvents:UnregisterEvent(event) end
    end
end

-- Called back by the secure wheel handler, which owns the child choice; the art only follows it
-- (no rebuild, so the sweep is not interrupted)
local function SetButtonChild(index, childIndex)
    local info, button = resolved[index], buttons[index]
    if not (info and button and info.children) then return end
    local child = info.children[childIndex]
    if not child then return end
    info.childIndex = childIndex
    info.name, info.icon, info.attributes = child.name, child.icon, child.attributes
    SetButtonIcon(button, child.icon)
    SetLabelText(button, child.name)
    SetPageDots(button, #info.children, childIndex)
    ApplyButtonState(button, info)
end

local function ResolveButtons(list)
    local out = {}
    for i = 1, #(list or {}) do
        if #out >= MAX_BUTTONS then break end
        local entry = ResolveEntry(list[i], 0, {})
        if entry then out[#out + 1] = entry end
    end
    return out
end

-- every radial: a macro may open any of them in combat
local function ResolveAll()
    wipe(resolvedCache)
    for _, id in ipairs(RM:GetRadialOrder()) do
        local data = RM:GetRadial(id)
        if data then resolvedCache[id] = ResolveButtons(data.buttons) end
    end
end

-- fromCache: draw the secure layer's copy without resolving or syncing (a nested radial opened in
-- place keeps the secure side's wheel choices)
function RM:LayoutRadial(fromCache)
    if not (radial and currentRadial) then return end
    -- the secure copy cannot be rewritten in combat: there the art draws it, so it matches what fires
    if fromCache and currentID and resolvedCache[currentID] then
        resolved = resolvedCache[currentID]
    elseif InCombatLockdown() then
        layoutPending = true
        resolved = (currentID and resolvedCache[currentID]) or resolved
    else
        layoutPending = nil
        ResolveAll()
        resolved = (currentID and resolvedCache[currentID]) or ResolveButtons(currentRadial)
    end

    local count = #resolved
    local interval = count > 0 and (TAU / count) or TAU
    local radius = RadialRadius(count)

    local diameter = (radius + ICON_SIZE) * 2
    radial:SetSize(diameter, diameter)

    for i = 1, math_max(count, #buttons) do
        local button = buttons[i]
        local entry = resolved[i]
        if entry and not button then
            button = CreateRadialButton(i)
            buttons[i] = button
        end
        if button then
            if entry then
                -- button 1 at the top, the rest clockwise
                local angle = QUARTER - (i - 1) * interval
                button.angle = angle
                button.baseX, button.baseY = math_cos(angle) * radius, math_sin(angle) * radius
                button:ClearAllPoints()
                button:SetPoint("CENTER", radial, "CENTER", button.baseX, button.baseY)
                ApplyButtonShape(button)
                SetButtonIcon(button, entry.icon)
                SetLabelText(button, entry.name)
                PlaceLabel(button, angle)
                SetPageDots(button, entry.children and #entry.children, entry.childIndex or 1)
                SetButtonSelected(button, false)
                button:Show()
            else
                button:Hide()
            end
        end
    end
    -- every button was just drawn unselected: an open radial picks its selection again next frame
    if isOpen then selectedIndex = nil end
    RM:LayoutPing(count, radius, interval)
    RefreshButtonStates()
    if not fromCache then SyncSecure() end
end

-- divider i runs between button i and button i + 1; one button has none
function RM:LayoutPing(count, radius, interval)
    local p = radial.Ping
    p.count, p.interval = count, interval
    local bg = math_max(PING.BG_MIN, radius * PING.BG_FACTOR)
    p.Background:SetSize(bg, bg)
    p.Background:SetShown(not previewID)   -- would spill out of the editor's box

    local sliced = count >= 2
    local outer = radius + ICON_SIZE * 0.9
    for i = 1, math_max(count, #p.Dividers) do
        local line = p.Dividers[i]
        if sliced and i <= count then
            if not line then
                line = radial:CreateLine(nil, "BORDER")
                line:SetTexture(PING.DIVIDER)
                line:SetThickness(PING.DIVIDER_THICKNESS)
                p.Dividers[i] = line
            end
            local a = QUARTER - (i - 1) * interval - interval / 2
            local c, s = math_cos(a), math_sin(a)
            line:SetStartPoint("CENTER", radial, c * PING.HUB, s * PING.HUB)
            line:SetEndPoint("CENTER", radial, c * outer, s * outer)
            line:Show()
        elseif line then
            line:Hide()
        end
    end
    self:LightSlice(nil)
end

-- Lights a slice (nil: none) and its two dividers: a full ring cut by two half-plane masks, one per
-- slice edge, whose overlap is the slice.
function RM:LightSlice(index)
    local p = radial and radial.Ping
    if not p then return end
    local d = PING.DIVIDER_COLOR
    for _, line in ipairs(p.Dividers) do line:SetVertexColor(d[1], d[2], d[3], d[4]) end
    if not (index and p.count and p.count >= 2) then
        p.Glow:Hide()
        return
    end
    local interval = p.interval
    local mid = QUARTER - (index - 1) * interval
    local low, high = mid - interval / 2, mid + interval / 2
    p.MaskLow:SetRotation(low + QUARTER)
    p.MaskHigh:SetRotation(high - QUARTER)
    p.Glow:Show()
    local lit = PING.LIT_COLOR
    local edgeLow, edgeHigh = p.Dividers[index], p.Dividers[(index - 2) % p.count + 1]
    local a = PING.LIT_DIVIDER_ALPHA
    if edgeLow then edgeLow:SetVertexColor(lit[1], lit[2], lit[3], a) end
    if edgeHigh then edgeHigh:SetVertexColor(lit[1], lit[2], lit[3], a) end
end

local function CreateRadial()
    if radial then return end
    radial = CreateFrame("Frame", "FlareUI_Radial", UIParent)
    radial:SetFrameStrata("DIALOG")
    radial:EnableMouse(false)          -- the cursor is polled; the secure wheel frame takes the wheel
    radial:Hide()

    -- the cancel X and its highlight; the pointer above all, hidden while the X is selected
    radial.CancelSelect = radial:CreateTexture(nil, "ARTWORK")
    radial.CancelSelect:SetAtlas(ATLAS_CANCEL_SELECT)
    radial.CancelSelect:SetSize(CANCEL_SELECT_SIZE, CANCEL_SELECT_SIZE)
    radial.CancelSelect:SetPoint("CENTER")
    radial.CancelSelect:Hide()

    radial.CancelIcon = radial:CreateTexture(nil, "OVERLAY", nil, 1)
    radial.CancelIcon:SetAtlas(ATLAS_CANCEL_ICON)
    radial.CancelIcon:SetSize(CANCEL_ICON_SIZE, CANCEL_ICON_SIZE)
    radial.CancelIcon:SetPoint("CENTER")

    radial.Pointer = radial:CreateTexture(nil, "OVERLAY", nil, 2)
    radial.Pointer:SetAtlas(ATLAS_POINTER)
    radial.Pointer:SetSize(POINTER_SIZE, POINTER_SIZE)
    radial.Pointer:SetPoint("CENTER")

    -- ping wheel art, drawn on the radial and so beneath the button frames
    local p = { Dividers = {} }
    radial.Ping = p
    p.Background = radial:CreateTexture(nil, "BACKGROUND", nil, 1)
    p.Background:SetAtlas(PING.BG_ATLAS)
    p.Background:SetPoint("CENTER")

    p.Glow = radial:CreateTexture(nil, "BACKGROUND", nil, 3)
    p.Glow:SetTexture(PING.GLOW)
    p.Glow:SetSize(PING.GLOW_SIZE, PING.GLOW_SIZE)
    p.Glow:SetPoint("CENTER")
    p.Glow:SetVertexColor(PING.LIT_COLOR[1], PING.LIT_COLOR[2], PING.LIT_COLOR[3], PING.GLOW_ALPHA)
    for _, key in ipairs({ "MaskLow", "MaskHigh" }) do
        local mask = radial:CreateMaskTexture()
        mask:SetTexture(PING.MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(p.Glow)
        p.Glow:AddMaskTexture(mask)
        p[key] = mask
    end
    p.Glow:Hide()

    p.Ring = radial:CreateTexture(nil, "BORDER", nil, 2)
    p.Ring:SetTexture(PING.RING)
    p.Ring:SetSize(PING.RING_SIZE, PING.RING_SIZE)
    p.Ring:SetPoint("CENTER")
    p.Ring:SetVertexColor(unpack(PING.RING_COLOR))
end

local function SetCancelSelected(selected)
    radial.CancelSelect:SetShown(selected)
    radial.CancelIcon:SetAlpha(selected and 1 or CANCEL_ALPHA_IDLE)
end

--------------------------------------------------
-- 7. SELECTION
-- The cursor (or stick) angle picks the button: measured clockwise from the top, plus half an
-- interval so each button owns the wedge centred on it.
--------------------------------------------------
-- the same table the secure snippet reads through GetGamePadState
local function PadStick()
    local state = C_GamePad.GetDeviceMappedState()
    return state and state.sticks and state.sticks[padStickIndex]
end

-- The camera holds still while a controller radial is open. A frame of the addon's own taking stick
-- input stops walking too, so this borrows Blizzard's gamepad axis listener (InputAxisBinding.lua,
-- the one its binding stack uses for camera axis bindings): its right-stick function takes the
-- "Camera" stick while the radial is open, and the left stick passes on as before. Only when
-- Blizzard has no camera function of its own there; its stick input is turned on out of combat.
local CAMERA_HOLD = function() return false end
local cameraHeld, cameraEnabledHere

local function AxisListener()
    local listener = _G.inputBindingAxisListener
    return listener and type(listener.right) == "table" and listener or nil
end

local function HoldCamera(on)
    local listener = AxisListener()
    if not listener then return end
    if on then
        if cameraHeld or listener.right.func ~= nil then return end
        listener.right.func = CAMERA_HOLD
        cameraHeld = true
        if not listener:IsGamePadStickEnabled() and not InCombatLockdown() then
            listener:EnableGamePadStick(true)
            cameraEnabledHere = true
        end
    elseif cameraHeld then
        if listener.right.func == CAMERA_HOLD then listener.right.func = nil end
        cameraHeld = false
        RM.ReleaseAxisListener()
    end
end

-- turns the listener's stick input back off when nothing of Blizzard's needs it (out of combat)
function RM.ReleaseAxisListener()
    local listener = AxisListener()
    if not (listener and cameraEnabledHere) or cameraHeld or InCombatLockdown() then return end
    local l, r = listener.left or {}, listener.right
    if not (l.func or r.func or l.waitForCentering or r.waitForCentering) then listener:EnableGamePadStick(false) end
    cameraEnabledHere = nil
end

-- an earlier build changed the controller config's camera stick while a radial was open: put back
-- whatever it left
local function RestoreCameraConfig()
    local global = ns.db and ns.db.global
    local saved = global and global.padCameraRestore
    if not (saved and C_GamePad and C_GamePad.SetConfig) then return end
    for _, old in ipairs(saved) do
        local got, config = pcall(C_GamePad.GetConfig, old.id)
        if got and type(config) == "table" and type(config.stickConfigs) == "table" then
            for _, stick in ipairs(config.stickConfigs) do
                if stick.stick == "Camera" then
                    stick.deadzone, stick.deadzoneX, stick.deadzoneY = old.deadzone, old.deadzoneX, old.deadzoneY
                    pcall(C_GamePad.SetConfig, config)
                    break
                end
            end
        end
    end
    global.padCameraRestore = nil
    pcall(C_GamePad.ApplyConfigs)
end

local function UpdateSelection()
    if not (isOpen and currentRadial) then return end

    -- safety net: a CLICK binding that never delivers its key-up would leave the radial stuck open
    if openMode == "hold" and GetTime() - openedAt > STUCK_OPEN_SECONDS then
        RM.EndHold()
        CloseRadial()
        return
    end

    local count = #resolved
    if count == 0 then return end

    local dx, dy, aimed
    if openMode == "pad" then
        local stick = PadStick()
        aimed = stick ~= nil and stick.len >= PAD_DEAD_LEN
        if aimed then dx, dy = stick.x, stick.y end
    else
        local cx, cy = CursorPosition()
        local centerX, centerY = radial:GetCenter()
        if not centerX then return end
        dx, dy = cx - centerX, cy - centerY
        aimed = (dx * dx + dy * dy) > DEAD_ZONE_SQ
    end
    local index
    if aimed then
        local angle = math_atan2(dy, dx)
        radial.Pointer:SetRotation(angle)
        radial.Pointer:Show()

        local interval = TAU / count
        index = math_floor(((QUARTER - angle) % TAU + interval / 2) / interval) % count + 1
        SetCancelSelected(false)
    else
        -- dead zone: releasing here cancels
        radial.Pointer:Hide()
        SetCancelSelected(true)
    end

    if index ~= selectedIndex then
        if selectedIndex and buttons[selectedIndex] then SetButtonSelected(buttons[selectedIndex], false) end
        if index and buttons[index] then SetButtonSelected(buttons[index], true) end
        selectedIndex = index
        RM:LightSlice(index)
    end
end

--------------------------------------------------
-- 8. OPEN / CLOSE ANIMATION
-- The ping wheel's fade and glide; plain art only, so it runs in combat too.
--------------------------------------------------
local animator = CreateFrame("Frame")
animator:Hide()

local function InOutCubic(t)
    return t < 0.5 and 4 * t * t * t or 1 - ((-2 * t + 2) ^ 3) / 2
end

local function PlaceButtons(slide)
    for i = 1, #resolved do
        local button = buttons[i]
        if button and button.angle then
            button:ClearAllPoints()
            button:SetPoint("CENTER", radial, "CENTER",
                button.baseX - math_cos(button.angle) * slide, button.baseY - math_sin(button.angle) * slide)
        end
    end
end

local function StopAnimation()
    if not animator:IsShown() then return end
    animator:Hide()
    radial:SetAlpha(1)
    PlaceButtons(0)
end

animator:SetScript("OnUpdate", function(self)
    local t = math_min(1, (GetTime() - self.started) / self.duration)
    local eased = InOutCubic(t)
    if self.outro then
        radial:SetAlpha(1 - t)
        PlaceButtons(PING.SLIDE * eased)
    else
        radial:SetAlpha(t)
        PlaceButtons(PING.SLIDE * (1 - eased))
    end
    if t >= 1 then
        local outro = self.outro
        StopAnimation()
        if outro then radial:Hide() end
    end
end)

local function Animate(outro)
    animator.outro = outro
    animator.duration = outro and PING.OUTRO or PING.INTRO
    animator.started = GetTime()
    animator:Show()
end

--------------------------------------------------
-- 9. OPEN / CLOSE
--------------------------------------------------
-- mode: "hold" (the keybind), "click" (a macro) or "pad" (the stick press)
local function OpenRadial(radialID, mode)
    if isOpen then CloseRadial() end
    StopAnimation()
    openMode = mode or "hold"
    -- laid out on every open so availability is current
    if radialID then
        RM:LoadRadial(radialID)
    else
        RM:LoadActiveRadial()
    end
    RM:LayoutRadial()
    if #resolved == 0 then return end
    WatchButtonStates(true)
    radial:SetScale(1)
    local padIcon = ns.IsGamepadUI() and C_Texture.GetAtlasInfo(ATLAS_CANCEL_PAD)
    radial.CancelIcon:SetAtlas(padIcon and ATLAS_CANCEL_PAD or ATLAS_CANCEL_ICON)

    -- the secure layer measures from the same point
    local x, y
    if openMode == "pad" then HoldCamera(true) end
    if openMode == "pad" or Option("position", "cursor") == "center" then
        x, y = UIParent:GetCenter()
    else
        x, y = CursorPosition()
    end
    radial:ClearAllPoints()
    radial:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    radial.Pointer:Hide()
    SetCancelSelected(true)

    selectedIndex = nil
    isOpen = true
    openedAt = GetTime()
    radial:Show()
    radial:SetScript("OnUpdate", UpdateSelection)
    UpdateSelection()
    radial:SetAlpha(0)
    PlaceButtons(PING.SLIDE)
    Animate(false)
end

function CloseRadial()
    if not isOpen then return end
    HoldCamera(false)
    isOpen = false
    openMode = nil
    radial:SetScript("OnUpdate", nil)
    WatchButtonStates(false)
    -- for closes other than the secure release; in combat PLAYER_REGEN_ENABLED does it
    if wheel and not InCombatLockdown() then wheel:Hide() end
    -- The released button keeps its light while the radial fades out, as the ping wheel's does; the
    -- next layout clears it.
    -- outside the editor the released button stays lit while fading out; the next layout clears it
    if previewID then
        if selectedIndex and buttons[selectedIndex] then SetButtonSelected(buttons[selectedIndex], false) end
        RM:LightSlice(nil)
    end
    selectedIndex = nil
    radial.Pointer:Hide()
    StopAnimation()
    -- the editor gets its preview back rather than an empty box
    if previewID then
        RM:ShowPreview(previewID, previewAnchor)
    else
        Animate(true)
    end
end

-- Called by the secure catcher (middle-click opens a nested radial, right-click goes back); the
-- art follows from the secure layer's copy
local function ShowNestedRadial(radialID)
    if not (isOpen and radialID) then return end
    StopAnimation()
    if selectedIndex and buttons[selectedIndex] then SetButtonSelected(buttons[selectedIndex], false) end
    selectedIndex = nil
    RM:LoadRadial(radialID)
    RM:LayoutRadial(true)
    UpdateSelection()
    radial:SetAlpha(0)
    PlaceButtons(PING.SLIDE)
    Animate(false)
end

--------------------------------------------------
-- 10. THE SECURE LAYER
-- The binding clicks the caster down on the press and up on the release; useOnKeyDown = false makes
-- the action run on the release. Snippets wrapped round its OnClick pick the button with the same
-- maths as UpdateSelection and write its attributes, which plain Lua cannot do in combat.
-- SyncSecure copies every radial onto the header out of combat as "<id>-count" and
-- "<id>-s<button>-<child>-<key>" (a plain button is a sub-radial of one child). ACTIVE is the open
-- radial; the wheel steps children in secure state (CHILD) and tells the art via CallMethod.
-- Click mode (macros "/click FUIRadial <tag>", or Activation "Toggle"): a /click sends no release,
-- so the full-screen catcher waits: left-click fires, middle-click opens a sub-radial in place
-- (STACK / DEPTH), right-click goes back or closes, Escape closes; pressing the same macro or key
-- again fires the aimed button. ROOT is the radial click mode opened.
-- Pad mode: L3 clicks PAD_NAME and opens; R3 (bound while open) fires what the right stick aims at
-- (GetGamePadState works in the restricted environment); LB / RB cycle the aimed slot; B, Escape or
-- L3 close.
-- OPENX / OPENY: where the radial opened (screen centre with "flare-center").
--------------------------------------------------
local ACTION_KEYS = "type spell item macro macrotext unit marker action"

-- self is the header. Returns the aimed button index, or nil in the dead zone.
local SELECT_SNIPPET = ([[
    local count = ACTIVE and self:GetAttribute(ACTIVE .. "-count") or 0
    if count == 0 then return nil end
    local dx, dy
    if MODE == "pad" then
        local state = GetGamePadState()
        local stick = state and state.sticks and state.sticks[self:GetAttribute("flare-padstick") or 2]
        if not stick or stick.len < %s then return nil end
        dx, dy = stick.x, stick.y
    else
        if not OPENX then return nil end
        local screen = self:GetFrameRef("wheel")
        local x, y = screen:GetMousePosition()
        if not x then return nil end
        dx, dy = x * screen:GetWidth() - OPENX, y * screen:GetHeight() - OPENY
        if dx * dx + dy * dy <= %d then return nil end
    end
    local tau = 2 * math.pi
    local interval = tau / count
    local angle = math.atan2(dy, dx)
    return math.floor(((math.pi / 2 - angle) %% tau + interval / 2) / interval) %% count + 1
]]):format(PAD_DEAD_LEN, DEAD_ZONE_SQ)

-- self is the header. The attribute prefix of the aimed button.
local AIMED_SNIPPET = [[
    local index = self:RunAttribute("flare-select")
    if not (index and ACTIVE) then return nil end
    local child = (CHILD[ACTIVE] and CHILD[ACTIVE][index]) or 1
    return ACTIVE .. "-s" .. index .. "-" .. child .. "-"
]]

-- self is the header. Sets OPENX / OPENY in the wheel frame's units; the wheel frame must be shown.
local OPEN_POINT_SNIPPET = [[
    local screen = self:GetFrameRef("wheel")
    if self:GetAttribute("flare-center") then
        OPENX, OPENY = screen:GetWidth() / 2, screen:GetHeight() / 2
        return
    end
    local x, y = screen:GetMousePosition()
    if x then
        OPENX, OPENY = x * screen:GetWidth(), y * screen:GetHeight()
    else
        OPENX, OPENY = nil, nil
    end
]]

-- self is the header; ... = quiet (the art is not told). Ends click mode.
local CLOSE_CLICK_SNIPPET = [[
    if MODE ~= "click" then return end
    MODE, ROOT, DEPTH = nil, nil, 0
    OPENX, OPENY = nil, nil
    self:GetFrameRef("catcher"):Hide()
    self:GetFrameRef("wheel"):Hide()
    self:ClearBindings()
    if not ... then self:CallMethod("OnSecureClose") end
]]

-- self is the header; ... = the radial id. Opens it in click mode.
local OPEN_CLICK_SNIPPET = [[
    local id = ...
    if (self:GetAttribute(id .. "-count") or 0) == 0 then return false end
    ACTIVE, MODE, ROOT, DEPTH = id, "click", id, 0
    self:GetFrameRef("wheel"):Show()
    self:RunAttribute("flare-openpoint")
    self:GetFrameRef("catcher"):Show()
    self:SetBindingClick(true, "ESCAPE", "]] .. CATCHER_NAME .. [[", "Escape")
    self:CallMethod("OnSecureOpen", id)
    return true
]]

-- self is the header; ... = quiet. Ends controller mode and its B / Escape bindings.
local CLOSE_PAD_SNIPPET = [[
    if MODE ~= "pad" then return end
    MODE = nil
    self:ClearBindings()
    if not ... then self:CallMethod("OnSecureClose") end
]]

-- self is the header; ... = the radial id. Opens it in controller mode.
local OPEN_PAD_SNIPPET = [[
    local id = ...
    ACTIVE, MODE = id, "pad"
    self:SetBindingClick(true, "]] .. PAD_CANCEL .. [[", "]] .. PAD_NAME .. [[", "RightButton")
    self:SetBindingClick(true, "ESCAPE", "]] .. PAD_NAME .. [[", "RightButton")
    self:SetBindingClick(true, "]] .. PAD_PREV .. [[", "]] .. PAD_NAME .. [[", "Button4")
    self:SetBindingClick(true, "]] .. PAD_NEXT .. [[", "]] .. PAD_NAME .. [[", "Button5")
    self:SetBindingClick(true, "PADRSTICK", "]] .. PAD_NAME .. [[", "MiddleButton")
    self:CallMethod("OnSecurePadOpen", id)
]]

-- self is the pad button, control the header. LeftButton (L3) opens, or closes an open one;
-- MiddleButton (R3, while open) fires the aimed button; RightButton (B, Escape) closes.
local PAD_SNIPPET = [[
    -- LB / RB: the aimed slot's previous / next sub-radial button, as the mouse wheel
    if button == "Button4" or button == "Button5" then
        if MODE ~= "pad" then return false end
        local index = control:RunAttribute("flare-select")
        if not (index and ACTIVE) then return false end
        local n = control:GetAttribute(ACTIVE .. "-s" .. index .. "-n") or 1
        if n < 2 then return false end
        CHILD[ACTIVE] = CHILD[ACTIVE] or newtable()
        local children = CHILD[ACTIVE]
        local child = ((children[index] or 1) - 1 + (button == "Button4" and -1 or 1)) % n + 1
        children[index] = child
        control:CallMethod("OnSecureChild", index, child)
        return false
    end
    if button == "MiddleButton" then
        if MODE ~= "pad" then return false end
        local prefix = control:RunAttribute("flare-aimed")
        control:RunAttribute("flare-closepad")
        if not prefix then return false end
        for key in gmatch(control:GetAttribute("flare-keys"), "%S+") do
            self:SetAttribute(key, control:GetAttribute(prefix .. key))
        end
        return nil, "fired"
    end
    if button ~= "LeftButton" or MODE == "pad" then
        control:RunAttribute("flare-closepad")
        return false
    end
    local id = control:GetAttribute("flare-assigned")
    if not id or (control:GetAttribute(id .. "-count") or 0) == 0 then return false end
    control:RunAttribute("flare-closeclick", true)
    control:RunAttribute("flare-openpad", id)
    return false
]]

-- self is the caster, control the header. Returning false cancels the click (a press, or a release
-- in the dead zone). Toggle's second press picks the button (FIRE) and fires it on the release.
local CLICK_SNIPPET = [[
    local screen = control:GetFrameRef("wheel")
    if down then
        -- an extra keybind clicks with its radial's id as the button; the main one with LeftButton
        local id = button
        if (control:GetAttribute(id .. "-count") or 0) < 1 then id = control:GetAttribute("flare-assigned") end
        local toggle = control:GetAttribute("flare-toggle")
        if toggle and MODE == "click" and ROOT == id then
            FIRE = control:RunAttribute("flare-aimed")
            control:RunAttribute("flare-closeclick")
            return false
        end
        FIRE = nil
        control:RunAttribute("flare-closeclick", true)
        control:RunAttribute("flare-closepad", true)
        for key in gmatch(control:GetAttribute("flare-keys"), "%S+") do self:SetAttribute(key, nil) end
        if toggle then
            control:RunAttribute("flare-openclick", id)
            return false
        end
        ACTIVE, MODE = id, "hold"
        screen:Show()
        control:RunAttribute("flare-openpoint")
        -- the catcher takes the mouse while the key is held: right-click cancels
        control:GetFrameRef("catcher"):Show()
        return false
    end
    if FIRE then
        local prefix = FIRE
        FIRE = nil
        for key in gmatch(control:GetAttribute("flare-keys"), "%S+") do
            self:SetAttribute(key, control:GetAttribute(prefix .. key))
        end
        return nil, "fired"
    end
    -- Toggle's release after opening: the radial stays up for its click
    if MODE == "click" then return false end
    local prefix = MODE == "hold" and control:RunAttribute("flare-aimed") or nil
    if MODE == "hold" then control:GetFrameRef("catcher"):Hide() end
    screen:Hide()
    MODE = nil
    OPENX, OPENY = nil, nil
    if not prefix then return false end
    for key in gmatch(control:GetAttribute("flare-keys"), "%S+") do
        self:SetAttribute(key, control:GetAttribute(prefix .. key))
    end
    return nil, "fired"
]]

-- self is the catcher, control the header
local CATCHER_SNIPPET = [[
    -- the key held (Hold): right-click cancels, the key's release then fires nothing; other
    -- buttons do nothing
    if MODE == "hold" then
        if button == "RightButton" then
            MODE = nil
            OPENX, OPENY = nil, nil
            self:Hide()
            control:GetFrameRef("wheel"):Hide()
            control:CallMethod("OnSecureHoldCancel")
        end
        return false
    end
    if button == "MiddleButton" then
        local index = control:RunAttribute("flare-select")
        local sub = index and ACTIVE and control:GetAttribute(ACTIVE .. "-s" .. index .. "-sub")
        if sub and (control:GetAttribute(sub .. "-count") or 0) > 0 then
            STACK = STACK or newtable()
            DEPTH = (DEPTH or 0) + 1
            STACK[DEPTH] = ACTIVE
            ACTIVE = sub
            control:CallMethod("OnSecureNested", sub)
        end
        return false
    end
    if button == "RightButton" and (DEPTH or 0) > 0 then
        ACTIVE = STACK[DEPTH]
        STACK[DEPTH] = nil
        DEPTH = DEPTH - 1
        control:CallMethod("OnSecureNested", ACTIVE)
        return false
    end
    if button ~= "LeftButton" then
        control:RunAttribute("flare-closeclick")
        return false
    end
    local prefix = control:RunAttribute("flare-aimed")
    control:RunAttribute("flare-closeclick")
    if not prefix then return false end
    for key in gmatch(control:GetAttribute("flare-keys"), "%S+") do
        self:SetAttribute(key, control:GetAttribute(prefix .. key))
    end
    return nil, "fired"
]]

-- self is the macro button, button the tag or id the macro named (a mouse button when none: the
-- keybind's radial). The restricted environment has no L: the message is baked into the snippet.
local MACRO_SNIPPET = [[
    local id = control:GetAttribute("tag-" .. strlower(button)) or button
    if (control:GetAttribute(id .. "-count") or -1) < 0 then
        if id == "LeftButton" or id == "RightButton" then
            id = control:GetAttribute("flare-assigned")
        else
            print(format(]] .. ("%q"):format("|cffff9900FlareUI:|r " .. L["no radial called \"%s\". Copy its macro from the Radial Menu settings."]) .. [[, tostring(id)))
            return false
        end
        if not id then return false end
    end
    if MODE == "click" and ROOT == id then
        local prefix = control:RunAttribute("flare-aimed")
        control:RunAttribute("flare-closeclick")
        if not prefix then return false end
        for key in gmatch(control:GetAttribute("flare-keys"), "%S+") do
            self:SetAttribute(key, control:GetAttribute(prefix .. key))
        end
        return nil, "fired"
    end
    control:RunAttribute("flare-closeclick", true)
    control:RunAttribute("flare-closepad", true)
    control:RunAttribute("flare-openclick", id)
    return false
]]

-- after the action has run, the button is left empty
local CLEAR_SNIPPET = [[
    for key in gmatch(control:GetAttribute("flare-keys"), "%S+") do self:SetAttribute(key, nil) end
]]

-- self is the wheel frame, offset the wheel delta. Scrolling up steps back through the children.
local WHEEL_SNIPPET = [[
    local index = control:RunAttribute("flare-select")
    if not (index and ACTIVE) then return end
    local n = control:GetAttribute(ACTIVE .. "-s" .. index .. "-n") or 1
    if n < 2 then return end
    CHILD[ACTIVE] = CHILD[ACTIVE] or newtable()
    local children = CHILD[ACTIVE]
    local child = ((children[index] or 1) - 1 + (offset > 0 and -1 or 1)) % n + 1
    children[index] = child
    control:CallMethod("OnSecureChild", index, child)
]]

-- Macro tag: the name without spaces or symbols (a /click passes one word), any case. On a clash
-- the first radial keeps the tag and the other is opened by its id.
local function MacroTags()
    local byTag, tagOf = {}, {}
    for _, id in ipairs(RM:GetRadialOrder()) do
        local data = RM:GetRadial(id)
        local tag = data and (data.name or ""):gsub("[^%w]", "") or ""
        if tag ~= "" and not byTag[tag:lower()] then
            byTag[tag:lower()], tagOf[id] = id, tag
        end
    end
    return byTag, tagOf
end

-- Out of combat only. Every key is written, nil included, so a slot that changed kind keeps no
-- stale key; a deleted radial is left with a count of 0.
function SyncSecure()
    if not header or InCombatLockdown() then return end
    for id in pairs(syncedIDs) do
        if not resolvedCache[id] then
            header:SetAttribute(id .. "-count", 0)
            syncedIDs[id] = nil
        end
    end
    for id, list in pairs(resolvedCache) do
        header:SetAttribute(id .. "-count", #list)
        for i, info in ipairs(list) do
            local children = info.children or { info }
            header:SetAttribute(id .. "-s" .. i .. "-n", #children)
            header:SetAttribute(id .. "-s" .. i .. "-sub", info.radialID)
            for c, child in ipairs(children) do
                local prefix = id .. "-s" .. i .. "-" .. c .. "-"
                for key in ACTION_KEYS:gmatch("%S+") do
                    header:SetAttribute(prefix .. key, child.attributes[key])
                end
            end
        end
        syncedIDs[id] = true
    end
    local byTag = MacroTags()
    for tag in pairs(syncedTags) do
        if not byTag[tag] then
            header:SetAttribute("tag-" .. tag, nil)
            syncedTags[tag] = nil
        end
    end
    for tag, id in pairs(byTag) do
        header:SetAttribute("tag-" .. tag, id)
        syncedTags[tag] = true
    end
    header:SetAttribute("flare-assigned", RM:GetAssignedRadialID())
    header:SetAttribute("flare-center", Option("position", "cursor") == "center")
    header:SetAttribute("flare-toggle", Option("activation", "hold") == "toggle")
    -- sub-radials restart on their first child, as the art does
    SecureHandlerExecute(header, "CHILD = newtable()")
end

-- with Toggle the secure snippet opens the art itself (OnSecureOpen)
local function OnPreClick(_, button, down)
    if down and not header:GetAttribute("flare-toggle") then OpenRadial(RM:GetRadial(button) and button or nil, "hold") end
end

-- hold mode only: a fired macro that opened a click-mode radial keeps that one up
local function OnPostClick(_, _, down)
    if not down and openMode == "hold" then CloseRadial() end
end

-- out of combat only; Init defers it otherwise
local function CreateSecureLayer()
    if caster then return end
    caster = CreateFrame("Button", CASTER_NAME, UIParent, "SecureActionButtonTemplate")
    -- parked off screen: a binding click needs no visible button
    caster:SetSize(1, 1)
    caster:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -500, 500)
    caster:RegisterForClicks("AnyDown", "AnyUp")
    caster:SetAttribute("useOnKeyDown", false)
    caster:SetAttribute("pressAndHoldAction", false)
    caster:SetScript("PreClick", OnPreClick)
    caster:SetScript("PostClick", OnPostClick)

    header = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
    header:SetAttribute("flare-keys", ACTION_KEYS)
    header:SetAttribute("flare-select", SELECT_SNIPPET)
    header:SetAttribute("flare-aimed", AIMED_SNIPPET)
    header:SetAttribute("flare-openclick", OPEN_CLICK_SNIPPET)
    header:SetAttribute("flare-closeclick", CLOSE_CLICK_SNIPPET)
    header:SetAttribute("flare-openpoint", OPEN_POINT_SNIPPET)
    header.OnSecureNested = function(_, radialID) ShowNestedRadial(radialID) end
    header.OnSecureHoldCancel = function() if openMode == "hold" then CloseRadial() end end
    header.OnSecureChild = function(_, index, child) SetButtonChild(index, child) end
    header.OnSecureOpen = function(_, radialID) OpenRadial(radialID, "click") end
    header.OnSecurePadOpen = function(_, radialID) OpenRadial(radialID, "pad") end
    header.OnSecureClose = function() if openMode == "click" or openMode == "pad" then CloseRadial() end end
    header:SetAttribute("flare-openpad", OPEN_PAD_SNIPPET)
    header:SetAttribute("flare-closepad", CLOSE_PAD_SNIPPET)

    -- Full screen: it is SELECT_SNIPPET's coordinate frame (GetMousePosition is nil outside the
    -- frame asked). Takes the wheel only, never clicks.
    wheel = CreateFrame("Frame", WHEEL_NAME, UIParent, "SecureFrameTemplate")
    wheel:SetAllPoints(UIParent)
    wheel:SetFrameStrata("FULLSCREEN_DIALOG")
    wheel:EnableMouse(false)
    wheel:EnableMouseWheel(true)
    wheel:Hide()
    SecureHandlerSetFrameRef(header, "wheel", wheel)

    -- above the wheel frame, so it takes the wheel too while up
    catcher = CreateFrame("Button", CATCHER_NAME, UIParent, "SecureActionButtonTemplate")
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:SetFrameLevel(wheel:GetFrameLevel() + 5)
    catcher:RegisterForClicks("AnyUp")
    catcher:SetAttribute("useOnKeyDown", false)
    catcher:SetAttribute("pressAndHoldAction", false)
    catcher:EnableMouseWheel(true)
    catcher:Hide()
    SecureHandlerSetFrameRef(header, "catcher", catcher)

    -- what macros click; never shown
    macroButton = CreateFrame("Button", MACRO_NAME, UIParent, "SecureActionButtonTemplate")
    macroButton:RegisterForClicks("AnyUp", "AnyDown")
    macroButton:SetAttribute("useOnKeyDown", false)
    macroButton:SetAttribute("pressAndHoldAction", false)

    SecureHandlerWrapScript(caster, "OnClick", header, CLICK_SNIPPET, CLEAR_SNIPPET)
    SecureHandlerWrapScript(wheel, "OnMouseWheel", header, WHEEL_SNIPPET)
    SecureHandlerWrapScript(catcher, "OnClick", header, CATCHER_SNIPPET, CLEAR_SNIPPET)
    SecureHandlerWrapScript(catcher, "OnMouseWheel", header, WHEEL_SNIPPET)
    SecureHandlerWrapScript(macroButton, "OnClick", header, MACRO_SNIPPET, CLEAR_SNIPPET)

    -- the stick press clicks this on its release
    padButton = CreateFrame("Button", PAD_NAME, UIParent, "SecureActionButtonTemplate")
    padButton:RegisterForClicks("AnyUp")
    padButton:SetAttribute("useOnKeyDown", false)
    padButton:SetAttribute("pressAndHoldAction", false)
    SecureHandlerWrapScript(padButton, "OnClick", header, PAD_SNIPPET, CLEAR_SNIPPET)
    SecureHandlerExecute(header, "CHILD = newtable(); STACK = newtable(); DEPTH = 0")
end

--------------------------------------------------
-- 11. LIVE PREVIEW
-- The radial editor parks the art in its box, scaled down to fit.
--------------------------------------------------
local PREVIEW_BOX = 220   -- fits the settings panel's right column

function RM:ShowPreview(radialID, anchor)
    if not radial then return end
    StopAnimation()
    previewID, previewAnchor = radialID, anchor
    self:LoadRadial(radialID)
    self:LayoutRadial()

    local diameter = radial:GetWidth()
    radial:SetScale(diameter > 0 and math_min(1, PREVIEW_BOX / diameter) or 1)
    radial:ClearAllPoints()
    radial:SetPoint("CENTER", anchor or UIParent, "CENTER", 0, 0)
    radial:SetScript("OnUpdate", nil)
    radial.Pointer:Hide()
    SetCancelSelected(false)
    -- above the settings panel (DIALOG)
    radial:SetFrameStrata("FULLSCREEN")
    radial:Show()
end

function RM:HidePreview()
    previewID, previewAnchor = nil, nil
    if radial then
        radial:SetScale(1)
        radial:SetFrameStrata("DIALOG")
        if not isOpen then radial:Hide() end
    end
    self:LoadActiveRadial()
    self:LayoutRadial()
end

function RM:RefreshPreview()
    if previewID then self:ShowPreview(previewID, previewAnchor) end
end

--------------------------------------------------
-- 12. RADIAL LIBRARY
-- Radials live in db.global, keyed by a stable id (renames orphan nothing) with an order list; which
-- radial a character opens is kept in that character's own state.
--------------------------------------------------
local function GetStore()
    if not (ns.db and ns.db.global) then return nil end
    local store = ns.db.global.radialmenu or {}
    ns.db.global.radialmenu = store
    -- an import can still carry the old "ring" key names: renamed once
    if store.rings then
        store.radials = store.radials or store.rings
        store.radialOrder = store.radialOrder or store.ringOrder
        store.nextRadialID = store.nextRadialID or store.nextRingID
        store.rings, store.ringOrder, store.nextRingID = nil, nil, nil
        for _, radial in pairs(store.radials) do
            if radial.slices then
                radial.buttons = radial.buttons or radial.slices
                radial.slices = nil
            end
            for _, entry in ipairs(radial.buttons or {}) do
                if entry.kind == "ring" then
                    entry.kind, entry.radial, entry.ring = "subradial", entry.ring, nil
                end
            end
        end
    end
    store.radials = store.radials or {}
    store.radialOrder = store.radialOrder or {}
    store.nextRadialID = store.nextRadialID or 1
    return store
end
RM.GetStore = function() return GetStore() end

function RM:GetRadialOrder()
    local store = GetStore()
    return store and store.radialOrder or {}
end

-- A to Z, any case
function RM:GetRadialsByName()
    local ids = {}
    for _, id in ipairs(self:GetRadialOrder()) do
        if self:GetRadial(id) then ids[#ids + 1] = id end
    end
    local function name(id) return (self:GetRadial(id).name or ""):lower() end
    table.sort(ids, function(a, b) return name(a) < name(b) end)
    return ids
end

function RM:GetRadial(id)
    local store = GetStore()
    return store and store.radials[id]
end

function RM:CreateRadial(name)
    local store = GetStore()
    if not store then return nil end
    local id = "r" .. store.nextRadialID
    store.nextRadialID = store.nextRadialID + 1
    store.radials[id] = { name = name or "New Radial", buttons = {} }
    store.radialOrder[#store.radialOrder + 1] = id
    return id
end

function RM:RenameRadial(id, name)
    local data = self:GetRadial(id)
    if data and name and name ~= "" then data.name = name end
end

function RM:DeleteRadial(id)
    local store = GetStore()
    if not (store and store.radials[id]) then return end
    store.radials[id] = nil
    for i, other in ipairs(store.radialOrder) do
        if other == id then table.remove(store.radialOrder, i) break end
    end
    -- a character that chose it falls back to the first radial
    self:LoadActiveRadial()
    self:LayoutRadial()
    self:ApplyBindings()
end

-- A character's setup (its radial and extra keybinds). A character without one starts from the
-- account's copy of the last setup changed (store.lastSetup).
local function CopyKeys(list)
    local out = {}
    for i, extra in ipairs(list or {}) do out[i] = { key = extra.key, radial = extra.radial } end
    return out
end

local function RememberSetup()
    local store, charDB = GetStore(), ns.CharDB()
    if not store then return end
    store.lastSetup = { radial = charDB.radial, keys = CopyKeys(charDB.radialKeys) }
end

local function CharacterSetup()
    local charDB = ns.CharDB()
    if charDB.ring ~= nil then   -- the old key name, as in GetStore
        if charDB.radial == nil then charDB.radial = charDB.ring end
        charDB.ring = nil
    end
    local store = GetStore()
    if charDB.radial == nil and charDB.radialKeys == nil then
        local last = store and store.lastSetup
        if last then
            charDB.radial = last.radial
            charDB.radialKeys = CopyKeys(last.keys)
        end
    elseif store and not store.lastSetup then
        RememberSetup()   -- a set-up character, but no account copy yet
    end
    return charDB
end

-- choice nil: never chose, gets the first radial; "": chose none
function RM:GetAssignedRadialID()
    local charDB = CharacterSetup()
    local choice = charDB.radial
    if choice == "" then return nil end
    if choice and self:GetRadial(choice) then return choice end
    return self:GetRadialOrder()[1]
end

function RM:SetAssignedRadialID(radialID)
    CharacterSetup().radial = radialID or ""
    RememberSetup()
    self:LoadActiveRadial()
    self:LayoutRadial()
end

-- currentRadial is the saved button list itself, so edits show without copying
function RM:LoadRadial(radialID)
    local data = self:GetRadial(radialID)
    currentID = data and radialID or nil
    currentRadial = data and data.buttons or {}
end

-- the macro line that opens this radial ("Radial Macros")
function RM:GetMacroText(radialID)
    if not radialID then return "" end
    local _, tagOf = MacroTags()
    return "/click " .. MACRO_NAME .. " " .. (tagOf[radialID] or radialID)
end

function RM:LoadActiveRadial()
    self:LoadRadial(self:GetAssignedRadialID())
end

--------------------------------------------------
-- 13. BINDING
-- The main key is account-wide, each character opening its own radial. Override bindings are
-- protected: a change in combat waits for the fight to end.
--------------------------------------------------
-- per character: { key = "F", radial = "r2" } each
local function ExtraBindings()
    local charDB = CharacterSetup()
    charDB.radialKeys = charDB.radialKeys or {}
    return charDB.radialKeys
end

-- StickIndexToConfigName counts from 0, the mapped state from 1
local function RightStickIndex()
    for i = 0, 7 do
        local ok, configName = pcall(C_GamePad.StickIndexToConfigName, i)
        if ok and configName == "Right" then return i + 1 end
    end
    return 2
end

local function ApplyBinding()
    if not (radial and caster) then return end
    if InCombatLockdown() then
        RM.bindingPending = true
        return
    end
    RM.bindingPending = nil
    ClearOverrideBindings(radial)
    local store = GetStore()
    local key = store and store.key
    if key and key ~= "" then
        SetOverrideBindingClick(radial, true, key, CASTER_NAME, "LeftButton")
    end
    -- an extra key clicks the caster with its radial's id as the mouse button
    for _, extra in ipairs(ExtraBindings()) do
        if extra.key and extra.key ~= "" and extra.radial and RM:GetRadial(extra.radial) then
            SetOverrideBindingClick(radial, true, extra.key, CASTER_NAME, extra.radial)
        end
    end
    -- Gamepad UI only: L3 runs the radial, aimed with the right stick (the camera holds still while
    -- it is open, section 7); R3 keeps the ping.
    if ns.IsGamepadUI() and store and store.controller and padButton then
        padStickIndex = RightStickIndex()
        header:SetAttribute("flare-padstick", padStickIndex)
        SetOverrideBindingClick(radial, true, "PADLSTICK", PAD_NAME, "LeftButton")
    end
end

function RM:IsControllerEnabled()
    local store = GetStore()
    return store and store.controller or false
end

function RM:SetControllerEnabled(enabled)
    local store = GetStore()
    if not store then return end
    store.controller = enabled and true or nil
    ApplyBinding()
end

function RM:ApplyBindings()
    ApplyBinding()
end

-- one key opens one radial: any other row holding it lets go; index 0 is the main keybind
local function ReleaseKey(key, keepIndex)
    if not key or key == "" then return end
    local store = GetStore()
    if keepIndex ~= 0 and store and store.key == key then store.key = nil end
    for i, extra in ipairs(ExtraBindings()) do
        if i ~= keepIndex and extra.key == key then extra.key = nil end
    end
end

RM.MAX_EXTRA_KEYS = MAX_EXTRA_KEYS

function RM:GetExtraBindings()
    return ExtraBindings()
end

-- a new row starts on the character's own radial, with no key
function RM:AddExtraBinding()
    local list = ExtraBindings()
    if #list >= MAX_EXTRA_KEYS then return end
    list[#list + 1] = { radial = self:GetAssignedRadialID() or self:GetRadialOrder()[1] }
    RememberSetup()
end

function RM:SetExtraKey(index, key)
    local extra = ExtraBindings()[index]
    if not extra then return end
    key = (key ~= "" and key) or nil
    ReleaseKey(key, index)
    extra.key = key
    RememberSetup()
    ApplyBinding()
end

function RM:SetExtraRadial(index, radialID)
    local extra = ExtraBindings()[index]
    if not extra then return end
    extra.radial = radialID
    RememberSetup()
    ApplyBinding()
end

function RM:RemoveExtraBinding(index)
    table.remove(ExtraBindings(), index)
    RememberSetup()
    ApplyBinding()
end

function RM:GetKey()
    local store = GetStore()
    return store and store.key or ""
end

function RM:SetKey(key)
    local store = GetStore()
    if not store then return end
    key = (key ~= "" and key) or nil
    ReleaseKey(key, 0)
    store.key = key
    ApplyBinding()
end

function RM:PLAYER_REGEN_ENABLED()
    if self.securePending then
        self.securePending = nil
        CreateSecureLayer()
        ApplyBinding()
    end
    if self.bindingPending then ApplyBinding() end
    RM.ReleaseAxisListener()
    if not isOpen then
        -- what the fight held back: a layout, or secure frames left up by a close other than a release
        if layoutPending then
            if previewID then self:RefreshPreview() else self:LayoutRadial() end
        end
        if wheel then wheel:Hide() end
        if catcher and catcher:IsShown() then
            SecureHandlerExecute(header, [[self:RunAttribute("flare-closeclick", true)]])
            RM.EndHold()
        end
    end
end

--------------------------------------------------
-- 14. PUBLIC
--------------------------------------------------
-- a Hold that never got its key release: the secure side lets go too, or its catcher keeps the
-- mouse; out of combat only
function RM.EndHold()
    if not header or InCombatLockdown() then return end
    SecureHandlerExecute(header, [[
        if MODE == "hold" then
            MODE = nil
            OPENX, OPENY = nil, nil
            self:GetFrameRef("catcher"):Hide()
            self:GetFrameRef("wheel"):Hide()
        end
    ]])
end

-- Menu Position / Activation changed
function RM:ApplyOpening()
    if not header then return end
    if InCombatLockdown() then layoutPending = true return end
    SyncSecure()
end

function RM:Refresh()
    if not radial then return end
    self:LayoutRadial()
end

function RM:Init()
    if self.initialized then return end
    self.initialized = true

    CreateRadial()
    -- a /reload in combat: the secure layer waits for the fight to end
    if InCombatLockdown() then
        self.securePending = true
    else
        CreateSecureLayer()
    end
    RestoreCameraConfig()

    -- first run: one radial, so the library is never empty
    local store = GetStore()
    if store and not next(store.radials) then
        local id = self:CreateRadial(L["Markers"])
        self:GetRadial(id).buttons = MarkerButtons()
    end

    self:LoadActiveRadial()
    self:LayoutRadial()

    ApplyBinding()
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    -- an item button resolves once its name is cached; the event fires for every item loaded
    local relayoutQueued = false
    self:RegisterEvent("ITEM_DATA_LOAD_RESULT", function(_, itemID)
        if not awaitedItems[itemID] then return end
        awaitedItems[itemID] = nil
        if relayoutQueued then return end
        relayoutQueued = true
        C_Timer.After(0.1, function()
            relayoutQueued = false
            if previewID then self:RefreshPreview() else self:LayoutRadial() end
        end)
    end)
end

-- called by the editor after any change
function RM:RadialChanged(radialID)
    if previewID and (radialID == nil or radialID == previewID) then
        self:RefreshPreview()
        return
    end
    if radialID == nil or radialID == self:GetAssignedRadialID() then
        self:LoadActiveRadial()
        self:LayoutRadial()
    end
end
