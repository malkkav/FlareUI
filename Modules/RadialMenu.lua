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
local AIM_NAME     = "FlareUI_RadialAim"   -- what the right stick's directions click while a controller radial is open
local PAD_AIM_LEN  = 0.15         -- a stick event this far out moves the kept aim (STICKY)
-- The right stick's directions arrive as these keys only while this CVar is on: on while a
-- controller radial is open, the player's own value back after
local STICK_KEYS_CVAR = "GamePadStickAxisButtons"
local PAD_COMBO_STICKS = { "L3", "R3" }                  -- a controller key's stick press ...
local PAD_COMBO_SIDES = { "TOP", "LT", "RT", "LTRT" }    -- ... and the triggers held (ns.ParsePadCombo)

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
local TINT_OUT_OF_RANGE = { 0.8, 0.1, 0.1 }
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
local MAX_RADIAL_DEPTH = 4

local radial, caster, header, wheel, buttons = nil, nil, nil, nil, {}
local catcher, macroButton          -- click mode's full-screen catcher, and the button macros click
local padButton                     -- controller mode's button, clicked by the stick press
local aimButton, padSticky          -- clicked by the right stick's directions; the aim it keeps (art side)
local padLast = {}                  -- radial id -> the button a controller open used last (art side)
local padStickIndex = 2             -- the right stick in C_GamePad's mapped state (RightStickIndex)
local isOpen, selectedIndex, currentRadial = false, nil, nil
local currentID                     -- the radial id currentRadial belongs to
local openMode                      -- "hold" (the keybind), "click" (a macro) or "pad"
local resolved = {}               -- currentRadial resolved to names / icons / attributes
local resolvedCache = {}          -- every radial resolved, as the secure layer holds them
local syncedIDs = {}              -- radial ids written to the secure layer, to retire deleted ones
local syncedTags = {}             -- macro tags written to the secure layer, to retire renamed ones
local syncDirty = true           -- the secure copy is out of date: the next open resolves and syncs again
local mouseKeyed = {}             -- radial id -> true: "<id>-mousekey" written (a radial on a mouse button)
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
    guild       = { order = 5,  label = L["Guild & Communities"], icon = "Interface\\Icons\\INV_Shirt_GuildTabard_01", button = "GuildMicroButton" },
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
    loothistory = { order = 14, label = L["Loot History"], icon = "Interface\\Icons\\INV_Box_02",
                    macrotext = "/run FlareUI_ToggleLootHistory()" },
}
RM.MICRO_PANELS = MICRO_PANELS

local GUILD_ICON = "Interface\\Icons\\INV_Shirt_GuildTabard_01"

-- the player's own spells, and the pet's
local function Known(spellID)
    if ns.IsPlayerSpell(spellID) then return true end
    if C_SpellBook.IsSpellKnownOrInSpellBook then
        return C_SpellBook.IsSpellKnownOrInSpellBook(spellID, Enum.SpellBookSpellBank.Pet) == true
    end
    return C_SpellBook.IsSpellKnown(spellID, Enum.SpellBookSpellBank.Pet) == true
end

-- The best rank of each spell in the player's book, by name; read again after the book changes
local bestByName
local function RankOf(spellID)
    local subtext = C_Spell.GetSpellSubtext(spellID)
    return type(subtext) == "string" and tonumber(subtext:match("(%d+)")) or 0
end
function RM.BestRank(name)
    if not name then return nil end
    if not bestByName then
        bestByName = {}
        local rankOf = {}
        local bank = Enum.SpellBookSpellBank.Player
        for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
            local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(line)
            local count = (lineInfo and not lineInfo.offSpecID) and lineInfo.numSpellBookItems or 0
            for offset = 1, count do
                local item = C_SpellBook.GetSpellBookItemInfo(lineInfo.itemIndexOffset + offset, bank)
                local id = item and item.spellID
                local spellName = id and ns.IsPlayerSpell(id) and C_Spell.GetSpellName(id)
                if spellName then
                    local rank = RankOf(id)
                    if not rankOf[spellName] or rank > rankOf[spellName] then
                        bestByName[spellName], rankOf[spellName] = id, rank
                    end
                end
            end
        end
    end
    return bestByName[name]
end
function RM.ForgetRanks() bestByName = nil end

-- Update Spell Ranks (Action Bars) switches the radials' rank following on too
local function FollowsRanks()
    local bars = ns.db and ns.db.profile and ns.db.profile.actionbars
    return bars and bars.autoRanks and true or false
end

-- A spell put on a radial at a lower rank than the best one known was picked on purpose: pinned to
-- that rank. Run when a button is added, and once for buttons saved before ranks were followed.
function RM.MarkRank(entry)
    if not (entry and entry.kind == "spell" and entry.id) then return end
    local name = C_Spell.GetSpellName(entry.id)
    local best = name and RM.BestRank(name)
    -- the book isn't read yet: asked again later
    if not best then return end
    entry.pinned = (best ~= entry.id and Known(entry.id) and RankOf(entry.id) < RankOf(best)) or nil
    entry.rankChecked = true
end

-- the lookup APIs raise an error on a nil id, so id-based resolvers bail out first
ACTIONS.spell = function(entry)
    if not entry.id then return nil end
    local info = C_Spell.GetSpellInfo(entry.id)
    if not info then return nil end
    local spellID = entry.id
    -- Radials are shared, so the rank is worked out per character: with Update Spell Ranks on, the
    -- best rank this character knows, unless a lower one was put there on purpose (pinned). A
    -- character who doesn't know the stored rank casts its best; one that knows no rank at all
    -- (another class, a spell not learned yet) leaves the button out.
    local best = RM.BestRank(info.name)
    if not entry.rankChecked then RM.MarkRank(entry) end
    if best and ((FollowsRanks() and not entry.pinned) or not Known(spellID)) then
        spellID = best
    elseif not Known(spellID) then
        return nil
    end
    return info.name, { texture = info.iconID }, { type = "spell", spell = spellID }
end

ACTIONS.mount = function(entry)
    if not (entry.id and C_MountJournal) then return nil end
    local name, spellID, icon, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(entry.id)
    if not (name and spellID) then return nil end
    -- radials are shared: a mount this character doesn't have is left out
    if isCollected == false then return nil end
    -- by name, as /cast does: a mount's summon spell isn't in the spellbook, and casting it by id
    -- may do nothing
    local spellName = C_Spell.GetSpellName(spellID) or name
    return name, { texture = icon }, { type = "spell", spell = spellName }
end

-- Blizzard's "item" action needs a NAME (an ID parses as a bag slot); an uncached name leaves the
-- button out until ITEM_DATA_LOAD_RESULT
local awaitedItems = {}   -- item id -> true while a radial waits for its data
ACTIONS.item = function(entry)
    if not entry.id then return nil end
    -- an item this character neither carries nor wears is left out (it comes back with the item)
    if C_Item.GetItemCount(entry.id) == 0 and not (C_Item.IsEquippedItem and C_Item.IsEquippedItem(entry.id)) then
        return nil
    end
    -- the secure action takes "item:<id>", so the button works before the item's data is loaded;
    -- only its label waits (the radial is laid out again when the data arrives)
    local name = C_Item.GetItemNameByID(entry.id)
    if not name then
        awaitedItems[entry.id] = true
        C_Item.RequestLoadItemDataByID(entry.id)
    end
    local icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(entry.id)
    return name or L["Item"], { texture = icon }, { type = "item", item = "item:" .. entry.id }
end

-- What a saved macro casts right now, read from the player's macro of that name: the game works out
-- #showtooltip and conditions such as [mod] or [@focus], as it does for action bars. The slice still
-- runs that macro (ACTIONS.macro); this lends it the cooldown, the editor's tooltip and the icon.
-- Answers "spell", id or "item", id, then the macro's current icon; nothing when no macro has the name.
function RM.MacroAction(entry)
    local name = entry and entry.name
    if type(name) ~= "string" or name == "" then return nil end
    local index = GetMacroIndexByName(name)
    if not (canaccessvalue(index) and index and index > 0) then return nil end
    local _, icon = GetMacroInfo(index)
    if not canaccessvalue(icon) then icon = nil end
    local spellID = GetMacroSpell(index)
    if canaccessvalue(spellID) and spellID then return "spell", spellID, icon end
    local itemName, itemLink = GetMacroItem(index)
    local item = (canaccessvalue(itemLink) and itemLink) or (canaccessvalue(itemName) and itemName) or nil
    local itemID = item and C_Item.GetItemInfoInstant(item)
    if canaccessvalue(itemID) and itemID then return "item", itemID, icon end
    return nil, nil, icon
end

-- The player's macro of that name runs as it is now (edited since it was added, or another
-- character's own version); the copy taken when it was added runs only where no macro has the name
ACTIONS.macro = function(entry)
    local name = entry.name
    if type(name) == "string" and name ~= "" then
        local index = GetMacroIndexByName(name)
        if canaccessvalue(index) and index and index > 0 then
            local _, icon = GetMacroInfo(index)
            if not canaccessvalue(icon) then icon = nil end
            return name, { texture = icon or entry.icon or 134400 }, { type = "macro", macro = name }
        end
    end
    return name or L["Macro"], { texture = entry.icon or 134400 },
        { type = "macro", macrotext = entry.text or "" }
end

-- marker 0 clears the target's mark instead of setting one, -1 every mark in the group (Forever has
-- neither RAID_TARGET_NONE nor REMOVE_WORLD_MARKERS: FlareUI names them)
ACTIONS.targetmarker = function(entry)
    local m = entry.marker or 1
    if m == 0 then
        return L["Clear Target's Marker"], { atlas = "GM-raidMarker-remove" },
            { type = "raidtarget", unit = "target", marker = 0, action = "clear" }
    end
    if m == -1 then
        return L["Clear All Markers"], { atlas = "GM-raidMarker-remove" },
            { type = "raidtarget", action = "clear-all" }
    end
    return (_G["RAID_TARGET_" .. m] or ("Marker " .. m)),
        { texture = ("Interface\\TargetingFrame\\UI-RaidTargetingIcon_%d"):format(m) },
        { type = "raidtarget", unit = "target", marker = m, action = "toggle" }
end

-- marker 0 clears every world marker (the secure handler treats a nil marker as "all")
ACTIONS.worldmarker = function(entry)
    local m = entry.marker or 1
    if m == 0 then
        return L["Clear World Markers"], { atlas = "GM-raidMarker-remove" },
            { type = "worldmarker", action = "clear" }
    end
    -- the game numbers world markers in its own order (blue square first); the raid icon each one
    -- shows is the one Blizzard's raid manager pairs with it
    local icon = RM.WorldMarkerIcon(m)
    local name = _G["WORLD_MARKER" .. m]
    if type(name) ~= "string" then
        local iconName = icon and _G["RAID_TARGET_" .. icon]
        name = iconName and L["%s World Marker"]:format(iconName) or (_G.WORLD_MARKER or "World Marker %d"):format(m)
    end
    return name, icon and { texture = ("Interface\\TargetingFrame\\UI-RaidTargetingIcon_%d"):format(icon) } or { atlas = "GM-raidMarker" .. m },
        { type = "worldmarker", marker = m, action = "toggle" }
end

-- world marker (the game's number) -> its raid icon (1 star ... 8 skull), as Blizzard's raid manager
-- pairs them: icon button k places world marker WORLD_RAID_MARKER_ORDER[9 - k]
local WORLD_ORDER = { 8, 4, 1, 7, 2, 3, 6, 5 }
function RM.WorldMarkerIcon(marker)
    local order = _G.WORLD_RAID_MARKER_ORDER or WORLD_ORDER
    for k = 1, 8 do
        if order[k] == marker then return 9 - k end
    end
end
function RM.WorldMarkerForIcon(icon)
    local order = _G.WORLD_RAID_MARKER_ORDER or WORLD_ORDER
    return order[9 - icon]
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
    -- a radial this character doesn't get leaves no button behind
    if not data or not RM:IsRadialAvailable(id) then return nil end

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

-- Quest Items: the usable items of the quests in your log, tracked quests first, as one button whose
-- choices are the items (LB / RB or the mouse wheel step through them, as a sub-radial's). It is gone
-- while no quest has an item, and comes back with one.
-- (the scroll the bags' Quest Items filter uses; the gossip "!" looked bad in the round frame, 11-12)
RM.QUEST_ITEMS_ICON = "Interface\\Icons\\INV_Scroll_03"
ACTIONS.questitems = function(entry)
    local children, taken = {}, {}
    local function Add(logIndex)
        if not logIndex or #children >= MAX_BUTTONS then return end
        local link, texture = GetQuestLogSpecialItemInfo(logIndex)
        local itemID = type(link) == "string" and tonumber(link:match("item:(%d+)"))
        if not itemID or taken[itemID] then return end
        taken[itemID] = true
        local name = C_Item.GetItemNameByID(itemID) or link:match("%[(.-)%]") or L["Item"]
        -- each child is an item of its own, so it shows its cooldown and count like one
        children[#children + 1] = { name = name, icon = { texture = texture }, entry = { kind = "item", id = itemID },
            attributes = { type = "item", item = "item:" .. itemID } }
    end
    for i = 1, C_QuestLog.GetNumQuestWatches() do
        local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
        Add(questID and C_QuestLog.GetLogIndexForQuestID(questID))
    end
    for logIndex = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(logIndex)
        if info and not info.isHeader then Add(logIndex) end
    end
    if #children == 0 then return nil end
    local first = children[1]
    return first.name, first.icon, first.attributes, { children = children, childIndex = 1 }
end

-- Party spell: one helpful spell spread over the group, a button for you and each party member
-- (party1-4; in a raid, your own group), so you aim at a person and cast on them without changing
-- your target. Units, not names, sit in the secure attributes; names are only drawn. The buttons
-- follow the group out of combat (a change in a fight shows after it).
ACTIONS.partycast = function(entry)
    local name, icon, attributes = ACTIONS.spell(entry)
    if not attributes then return nil end
    local spread = {}
    for _, unit in ipairs({ "player", "party1", "party2", "party3", "party4" }) do
        if UnitExists(unit) then
            local who = UnitName(unit)
            local _, class = UnitClass(unit)
            local color = canaccessvalue(class) and class and C_ClassColor.GetClassColor(class)
            local label = (canaccessvalue(who) and who) or unit
            if color then label = color:WrapTextInColorCode(label) end
            spread[#spread + 1] = { name = label, icon = icon, entry = { kind = "spell", id = entry.id },
                attributes = { type = "spell", spell = attributes.spell, unit = unit } }
        end
    end
    if #spread == 0 then return nil end
    -- alone there is no one to aim at: the spell's own name, not yours (11-11, Marcus)
    if #spread == 1 then spread[1].name = name end
    local first = spread[1]
    return name, first.icon, first.attributes, { spread = spread }
end

-- nil when unavailable (unknown spell, uncached item, emptied sub-radial...): the radial closes up around it
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
    t[9] = { kind = "targetmarker", marker = -1 }
    return t
end

RM.ResolveEntry = function(_, entry) return ResolveEntry(entry) end
-- the radial's round button look, for the editor's icons (RadialEditor.lua)
RM.RoundStyle = function() return RoundStyle() end
RM.ROUND_BORDER_FRACTION = ROUND_BORDER / ROUND_SIZE
RM.ROUND_BORDER_COLOR = BORDER_COLOR
RM.MAX_BUTTONS = MAX_BUTTONS

--------------------------------------------------
-- 6. RADIAL FRAME
--------------------------------------------------
-- parent: a settings preview's wheel (the radial otherwise)
-- Radial Menu > Fonts (11-13): the hovered button's name (a family: spell names in any alphabet) and
-- the counts. Table fields, not locals: this file is near Lua's 200-locals limit.
RM.fontButtons = setmetatable({}, { __mode = "k" })
function RM.StyleButtonFonts(button)
    RM.fontButtons[button] = true
    local db = ns.db and ns.db.profile and ns.db.profile.radialmenu
    if not db then return end
    for _, part in ipairs({ { button.Label, db.labelFont, 16, true }, { button.Count, db.countFont, 14 } }) do
        local fontString, font, size, family = part[1], part[2], part[3], part[4]
        if fontString and font then
            local flags = font.flags or ""
            if flags == "NONE" then flags = "" end
            local path = ns.GetFontPath(font.face or ns.GLOBAL_FONT)
            if family then ns.SetFontFamily(fontString, path, font.size or size, flags)
            else ns.SetFont(fontString, path, font.size or size, flags) end
            ns.ApplyShadow(fontString, font)
        end
    end
end
function RM:ApplyFonts()
    for button in pairs(RM.fontButtons) do RM.StyleButtonFonts(button) end
end

local function CreateRadialButton(index, parent)
    local button = CreateFrame("Frame", nil, parent or radial)
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
    -- a stackable item's count, or a spell's charges, in the corner
    button.Count = button.Front:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.Count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    button.Count:Hide()
    -- a world marker that is on the ground
    button.Placed = button.Front:CreateTexture(nil, "OVERLAY")
    button.Placed:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    button.Placed:SetSize(14, 14)
    button.Placed:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    button.Placed:Hide()
    button.Label = button.Front:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    button.Label:SetShadowColor(0, 0, 0, 1)
    button.Label:SetShadowOffset(1, -1)
    button.Label:Hide()
    RM.StyleButtonFonts(button)

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
    return canaccessvalue(value) and value ~= nil
end

local function ApplyButtonState(button, info)
    if not (button and info) then return end
    local action = info.children and info.children[info.childIndex or 1] or info
    local attributes, entry = action.attributes, action.entry
    local cooldown = button.Cooldown
    local usable, noMana = true, false

    -- a macro shows what it would cast now (RM.MacroAction), with that one's icon
    local kind, id
    if attributes and attributes.type == "spell" and attributes.spell then
        kind, id = "spell", attributes.spell
    elseif attributes and attributes.type == "item" and entry and entry.id then
        kind, id = "item", entry.id
    elseif attributes and attributes.type == "macro" and entry and entry.kind == "macro" then
        local icon
        kind, id, icon = RM.MacroAction(entry)
        if icon and button.Icon:GetTexture() ~= icon then SetButtonIcon(button, { texture = icon }) end
    end

    -- a mount: the Mount Journal's own check (indoors included); the spell check says no to every mount
    if kind == "spell" and entry and entry.kind == "mount" and entry.id and C_MountJournal.GetMountUsabilityByID then
        local isUsable = C_MountJournal.GetMountUsabilityByID(entry.id, true)
        cooldown:Clear()
        if Readable(isUsable) then usable = isUsable end
        kind = nil
    end
    if kind == "spell" then
        local cd = C_Spell.GetSpellCooldown(id)
        local duration = cd and Readable(cd.isActive) and cd.isActive and C_Spell.GetSpellCooldownDuration(id, true)
        if duration then cooldown:SetCooldownFromDurationObject(duration) else cooldown:Clear() end
        local isUsable, isNoMana = C_Spell.IsSpellUsable(id)
        if Readable(isUsable) then usable, noMana = isUsable, Readable(isNoMana) and isNoMana end
    elseif kind == "item" then
        local start, duration, enabled = C_Item.GetItemCooldown(id)
        if Readable(start) and Readable(duration) and Readable(enabled) and enabled and duration > 0 then
            cooldown:SetCooldown(start, duration)
        else
            cooldown:Clear()
        end
        local isUsable, isNoMana = C_Item.IsUsableItem(id)
        if Readable(isUsable) then usable, noMana = isUsable, Readable(isNoMana) and isNoMana end
    else
        cooldown:Clear()
    end

    -- out of range of the target comes first, as on action bars (nil: no target, or no range)
    local outOfRange = false
    if kind == "spell" then
        -- a party spell measures to its own person
        local inRange = C_Spell.IsSpellInRange(id, (attributes and attributes.unit) or "target")
        outOfRange = Readable(inRange) and inRange == false
    elseif kind == "item" and not InCombatLockdown() and C_Item.IsItemInRange then
        local ok, inRange = pcall(C_Item.IsItemInRange, id, "target")
        outOfRange = ok and Readable(inRange) and inRange == false
    end

    -- the count: a stackable item's, or a spell's charges (shown as it comes, never compared)
    local count
    if kind == "item" then
        local stack = C_Item.GetItemMaxStackSizeByID and C_Item.GetItemMaxStackSizeByID(id)
        if Readable(stack) and stack and stack > 1 then count = C_Item.GetItemCount(id) end
    elseif kind == "spell" and C_Spell.GetSpellCharges then
        local charges = C_Spell.GetSpellCharges(id)
        if charges and Readable(charges.maxCharges) and charges.maxCharges > 1 then count = charges.currentCharges end
    end
    if count then
        button.Count:SetText(count)
        button.Count:Show()
    else
        button.Count:Hide()
    end

    -- a world marker already placed: the button picks it up again
    local marker = entry and entry.kind == "worldmarker" and entry.marker
    button.Placed:SetShown(marker and marker > 0 and IsRaidMarkerActive and IsRaidMarkerActive(marker) or false)

    local t = (outOfRange and TINT_OUT_OF_RANGE) or (usable and TINT_USABLE) or (noMana and TINT_NO_MANA or TINT_UNUSABLE)
    button.Icon:SetVertexColor(t[1], t[2], t[3])
end

local function RefreshButtonStates()
    for i, info in ipairs(resolved) do ApplyButtonState(buttons[i], info) end
end

-- registered only while the radial is up
local stateEvents = CreateFrame("Frame")
stateEvents:SetScript("OnEvent", RefreshButtonStates)
-- (a modifier, target, focus or macro edit can change what a macro casts)
local STATE_EVENTS = { "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_USABLE", "BAG_UPDATE_COOLDOWN", "ACTIONBAR_UPDATE_USABLE",
                       "MODIFIER_STATE_CHANGED", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UPDATE_MACROS",
                       "BAG_UPDATE_DELAYED", "SPELL_UPDATE_CHARGES", "RAID_TARGET_UPDATE" }

-- range has no event: read every 0.2 s while the radial is up
local stateTicker
local function WatchButtonStates(watch)
    for _, event in ipairs(STATE_EVENTS) do
        if watch then stateEvents:RegisterEvent(event) else stateEvents:UnregisterEvent(event) end
    end
    if stateTicker then stateTicker:Cancel(); stateTicker = nil end
    if watch then stateTicker = C_Timer.NewTicker(0.2, RefreshButtonStates) end
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
        -- a party spell takes a button per person (ACTIONS.partycast)
        if entry and entry.spread then
            for _, person in ipairs(entry.spread) do
                if #out >= MAX_BUTTONS then break end
                out[#out + 1] = person
            end
        elseif entry then
            out[#out + 1] = entry
        end
    end
    return out
end

-- every radial this character gets: a macro may open any of them in combat (the others are left
-- with a count of 0 in the secure layer, so their keys and macros open nothing)
local function ResolveAll()
    wipe(resolvedCache)
    for _, id in ipairs(RM:GetRadialOrder()) do
        local data = RM:GetRadial(id)
        if data and RM:IsRadialAvailable(id) then resolvedCache[id] = ResolveButtons(data.buttons) end
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
        syncDirty = false
        ResolveAll()
        resolved = (currentID and resolvedCache[currentID]) or ResolveButtons(currentRadial)
    end

    local count, radius, interval = RM.PlaceRadialButtons(radial, buttons, resolved)
    -- every button was just drawn unselected: an open radial picks its selection again next frame
    if isOpen then selectedIndex = nil end
    RM:LayoutPing(count, radius, interval)
    RefreshButtonStates()
    if not fromCache then SyncSecure() end
end

-- The buttons of `entries` on `frame` (the radial, or a settings preview's wheel), kept in `list`
function RM.PlaceRadialButtons(frame, list, entries)
    local count = #entries
    local interval = count > 0 and (TAU / count) or TAU
    local radius = RadialRadius(count)

    local diameter = (radius + ICON_SIZE) * 2
    frame:SetSize(diameter, diameter)

    for i = 1, math_max(count, #list) do
        local button = list[i]
        local entry = entries[i]
        if entry and not button then
            button = CreateRadialButton(i, frame)
            list[i] = button
        end
        if button then
            if entry then
                -- button 1 at the top, the rest clockwise
                local angle = QUARTER - (i - 1) * interval
                button.angle = angle
                button.baseX, button.baseY = math_cos(angle) * radius, math_sin(angle) * radius
                button:ClearAllPoints()
                button:SetPoint("CENTER", frame, "CENTER", button.baseX, button.baseY)
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
    return count, radius, interval
end

-- divider i runs between button i and button i + 1; one button has none
-- frame: a settings preview's wheel (the radial otherwise)
function RM:LayoutPing(count, radius, interval, frame)
    frame = frame or radial
    local p = frame.Ping
    p.count, p.interval = count, interval
    local bg = math_max(PING.BG_MIN, radius * PING.BG_FACTOR)
    p.Background:SetSize(bg, bg)
    p.Background:SetShown(not (previewID or frame.fuiSample))   -- would spill out of the editor's box

    local sliced = count >= 2
    local outer = radius + ICON_SIZE * 0.9
    for i = 1, math_max(count, #p.Dividers) do
        local line = p.Dividers[i]
        if sliced and i <= count then
            if not line then
                line = frame:CreateLine(nil, "BORDER")
                line:SetTexture(PING.DIVIDER)
                line:SetThickness(PING.DIVIDER_THICKNESS)
                p.Dividers[i] = line
            end
            local a = QUARTER - (i - 1) * interval - interval / 2
            local c, s = math_cos(a), math_sin(a)
            line:SetStartPoint("CENTER", frame, c * PING.HUB, s * PING.HUB)
            line:SetEndPoint("CENTER", frame, c * outer, s * outer)
            line:Show()
        elseif line then
            line:Hide()
        end
    end
    self:LightSlice(nil, frame)
end

-- Lights a slice (nil: none) and its two dividers: a full ring cut by two half-plane masks, one per
-- slice edge, whose overlap is the slice.
function RM:LightSlice(index, frame)
    local target = frame or radial
    local p = target and target.Ping
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
    RM.BuildRadialArt(radial)
end

-- The wheel's art (cancel X, pointer, ping wheel), on the radial or a settings preview's wheel
function RM.BuildRadialArt(radial)
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

-- While the controller radial is open the right stick aims it, so the camera holds still. A frame
-- of FlareUI's own takes the camera stick's input while a radial is aimed (returning false: handled)
-- and passes the rest on. It listens ONLY while a controller radial is open, as Blizzard's radial
-- wheel does: left on for good, it took both sticks from the game on some setups (5.0 report: "can't
-- use the joysticks"). Turning stick input on is protected, so the secure open / close snippets do
-- it (frame ref "stickguard"), which works in a fight too. Made with the secure layer, out of combat.
local cameraHeld = false
local stickGuard

local function GuardStick()
    if stickGuard or InCombatLockdown() then return stickGuard end
    stickGuard = CreateFrame("Frame", nil, UIParent, "SecureFrameTemplate")
    stickGuard:SetScript("OnGamepadStick", function(_, stick)
        if cameraHeld and stick == "Camera" then return false end
        return true
    end)
    stickGuard:EnableGamePadStick(false)
    return stickGuard
end

-- out of a fight, the listener goes off with the radial whatever closed it
local function ReleaseStickGuard()
    if stickGuard and not InCombatLockdown() then pcall(stickGuard.EnableGamePadStick, stickGuard, false) end
end

local function HoldCamera(on)
    cameraHeld = on and true or false
end

-- The right stick's directions come as keys (the aim button's clicks) only with the CVar on: on
-- while a controller radial is open, the player's value back on close. The value to put back is
-- saved too, so a crash or reload while open restores it at the next login (Init).
local function SetStickKeys(on)
    local global = ns.db and ns.db.global
    if not global then return end
    if on then
        if global.padStickKeysRestore ~= nil then return end
        local value = C_CVar.GetCVar(STICK_KEYS_CVAR)
        if value == nil or value == "1" then return end
        if pcall(C_CVar.SetCVar, STICK_KEYS_CVAR, "1") then global.padStickKeysRestore = value end
    elseif global.padStickKeysRestore ~= nil then
        if pcall(C_CVar.SetCVar, STICK_KEYS_CVAR, global.padStickKeysRestore) then global.padStickKeysRestore = nil end
    end
end

-- Older settings may hold the camera stick's dead zones, saved when a radial changed them: put
-- them back
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

    local dx, dy, aimed, kept
    if openMode == "pad" then
        local stick = PadStick()
        aimed = stick ~= nil and stick.len >= PAD_DEAD_LEN
        if aimed then
            dx, dy = stick.x, stick.y
        elseif padSticky and padSticky <= count then
            -- the stick let go: the button it last pointed at stays lit (what R3 or a release uses)
            kept = padSticky
        elseif RM:IsPadRepeatOn() and padLast[currentID] and padLast[currentID] <= count then
            -- nothing aimed yet: the last button used, which pressing again uses
            kept = padLast[currentID]
        end
    else
        local cx, cy = CursorPosition()
        -- the radial's own coordinates are in its scale (Radial Scale): back to the screen's
        local centerX, centerY = radial:GetCenter()
        if not centerX then return end
        local s = radial:GetScale()
        centerX, centerY = centerX * s, centerY * s
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
    elseif kept then
        index = kept
        radial.Pointer:Hide()
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
    -- Sub-Radials, Reset on Close: the art starts on each first button too, as the secure layer does
    if Option("subRadials", "reset") ~= "remember" then
        for _, list in pairs(resolvedCache) do
            for _, info in ipairs(list) do
                if info.children then info.childIndex = 1 end
            end
        end
    end
    StopAnimation()
    openMode = mode or "hold"
    if radialID then
        RM:LoadRadial(radialID)
    else
        RM:LoadActiveRadial()
    end
    -- the secure copy is rewritten only after something changed (RM.MarkDirty); otherwise the press
    -- draws what it already holds
    RM:LayoutRadial(not syncDirty and currentID ~= nil and resolvedCache[currentID] ~= nil and not InCombatLockdown())
    if #resolved == 0 then return end
    WatchButtonStates(true)
    local scale = tonumber(Option("scale", 1)) or 1
    radial:SetScale(scale)
    local padIcon = ns.IsGamepadUI() and C_Texture.GetAtlasInfo(ATLAS_CANCEL_PAD)
    radial.CancelIcon:SetAtlas(padIcon and ATLAS_CANCEL_PAD or ATLAS_CANCEL_ICON)

    -- the secure layer measures from the same point
    local x, y
    padSticky = nil
    if openMode == "pad" then
        HoldCamera(true)
        SetStickKeys(true)
    end
    -- the secure layer's own copy of Menu Position: a change made in a fight reaches it only after
    -- the fight, and both sides must measure from the same point
    local centered = header and header:GetAttribute("flare-center")
    if centered == nil then centered = Option("position", "cursor") == "center" end
    if openMode == "pad" or centered then
        x, y = UIParent:GetCenter()
    else
        x, y = CursorPosition()
    end
    radial:ClearAllPoints()
    -- offsets are in the radial's own (scaled) units
    radial:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
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
    ReleaseStickGuard()
    SetStickKeys(false)
    padSticky = nil
    isOpen = false
    openMode = nil
    radial:SetScript("OnUpdate", nil)
    WatchButtonStates(false)
    -- for closes other than the secure release; in combat PLAYER_REGEN_ENABLED does it
    if wheel and not InCombatLockdown() then wheel:Hide() end
    -- outside the editor the released button stays lit while fading out, as the ping wheel's does;
    -- the next layout clears it
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
-- Pad mode: a radial's controller key (L3 or R3, alone or with LT / RT held) clicks PAD_NAME as
-- PadL3 / PadR3 and opens it; R3 (bound while open) fires what the right stick aims at, or the aim it
-- kept once let go (STICKY, from the aim button: the stick's directions arrive as keys while open);
-- with Release the stick to use, letting go fires it. GetGamePadState works in the restricted
-- environment. LB / RB cycle the aimed slot; B, Escape or L3 close.
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
        -- let go: the button the stick last pointed at (kept by the aim button, AIM_SNIPPET)
        if not stick or stick.len < %s then return STICKY end
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
    -- no radial assigned (Toggle with every radial deleted)
    if not id then return false end
    if (self:GetAttribute(id .. "-count") or 0) == 0 then return false end
    if self:GetAttribute("flare-subreset") then CHILD = newtable() end
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
    MODE, STICKY = nil, nil
    self:ClearBindings()
    local guard = self:GetFrameRef("stickguard")
    if guard then guard:EnableGamePadStick(false) end
    if not ... then self:CallMethod("OnSecureClose") end
]]

-- self is the header; ... = the radial id. Opens it in controller mode.
local OPEN_PAD_SNIPPET = [[
    local id = ...
    if self:GetAttribute("flare-subreset") then CHILD = newtable() end
    ACTIVE, MODE, STICKY = id, "pad", nil
    HELD = newtable()
    -- the camera stick is held only while open (see GuardStick)
    local guard = self:GetFrameRef("stickguard")
    if guard then guard:EnableGamePadStick(true) end
    -- the right stick's directions (keys while the CVar is on) keep the aim
    self:SetBindingClick(true, "PADRSTICKUP", "]] .. AIM_NAME .. [[", "AimUp")
    self:SetBindingClick(true, "PADRSTICKDOWN", "]] .. AIM_NAME .. [[", "AimDown")
    self:SetBindingClick(true, "PADRSTICKLEFT", "]] .. AIM_NAME .. [[", "AimLeft")
    self:SetBindingClick(true, "PADRSTICKRIGHT", "]] .. AIM_NAME .. [[", "AimRight")
    self:SetBindingClick(true, "]] .. PAD_CANCEL .. [[", "]] .. PAD_NAME .. [[", "RightButton")
    self:SetBindingClick(true, "ESCAPE", "]] .. PAD_NAME .. [[", "RightButton")
    self:SetBindingClick(true, "]] .. PAD_PREV .. [[", "]] .. PAD_NAME .. [[", "Button4")
    self:SetBindingClick(true, "]] .. PAD_NEXT .. [[", "]] .. PAD_NAME .. [[", "Button5")
    self:SetBindingClick(true, "PADRSTICK", "]] .. PAD_NAME .. [[", "MiddleButton")
    self:CallMethod("OnSecurePadOpen", id)
]]

-- self is the pad button, control the header. PadL3 / PadR3 (a stick press) open the radial of the
-- triggers held, or close an open one; MiddleButton (R3, while open) fires the aimed button;
-- RightButton (B, Escape) closes.
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
    -- R3 while open: the header's binding (MiddleButton), or the radial's own R3 binding when
    -- that one wins the key. With nothing aimed, Press again to repeat uses the last button.
    if button == "MiddleButton" or (button == "PadR3" and MODE == "pad") then
        if MODE ~= "pad" then return false end
        local prefix = control:RunAttribute("flare-aimed")
        if not prefix and control:GetAttribute("flare-padrepeat") then prefix = LAST[ACTIVE] end
        control:RunAttribute("flare-closepad")
        if not prefix then return false end
        LAST[ACTIVE] = prefix
        control:CallMethod("OnSecureLast", ACTIVE, prefix)
        for key in gmatch(control:GetAttribute("flare-keys"), "%S+") do
            self:SetAttribute(key, control:GetAttribute(prefix .. key))
        end
        return nil, "fired"
    end
    -- B or Escape
    if button == "RightButton" then
        control:RunAttribute("flare-closepad")
        return false
    end
    -- what this press opens: a stick press, the radial of the triggers held with it (LT / RT are the
    -- bar's crossbar modifiers, so they are read here rather than bound); anything else is a gamepad
    -- bar macro ("/click FlareUI_RadialPad <radial id>")
    local id
    if button == "PadL3" or button == "PadR3" then
        local state = GetGamePadState()
        local held = state and state.buttons
        local lt, rt = control:GetAttribute("flare-ltindex"), control:GetAttribute("flare-rtindex")
        local l, r = held and lt and held[lt], held and rt and held[rt]
        local side = (l and r and "LTRT") or (l and "LT") or (r and "RT") or "TOP"
        id = control:GetAttribute("flare-pad-" .. (button == "PadL3" and "L3" or "R3") .. "-" .. side)
    else
        id = control:GetAttribute("tag-" .. strlower(button)) or button
    end
    if id and (control:GetAttribute(id .. "-count") or 0) == 0 then id = nil end
    -- pressed again while its radial is open: with nothing aimed and Press again to repeat on, the
    -- last button; otherwise it closes. Another radial's button switches to that radial.
    if MODE == "pad" then
        if not id or id == ACTIVE then
            local prefix = control:GetAttribute("flare-padrepeat") and not control:RunAttribute("flare-select") and LAST[ACTIVE]
            control:RunAttribute("flare-closepad")
            if not prefix then return false end
            control:CallMethod("OnSecureLast", ACTIVE, prefix)
            for key in gmatch(control:GetAttribute("flare-keys"), "%S+") do
                self:SetAttribute(key, control:GetAttribute(prefix .. key))
            end
            return nil, "fired"
        end
        control:RunAttribute("flare-closepad", true)
    end
    if not id then return false end
    control:RunAttribute("flare-closeclick", true)
    control:RunAttribute("flare-openpad", id)
    return false
]]

-- self is the aim button, control the header; button is the direction (AimUp ...), down its
-- press or release. Each direction key the right stick sends keeps the button it points at
-- (STICKY), so letting go of the stick still knows the aim. With Release the stick to use on, the
-- last direction let go with the stick back near the middle uses that button.
local AIM_SNIPPET = ([[
    if MODE ~= "pad" or not ACTIVE then return false end
    HELD = HELD or newtable()
    HELD[button] = down or nil
    local count = control:GetAttribute(ACTIVE .. "-count") or 0
    if count == 0 then return false end
    local state = GetGamePadState()
    local stick = state and state.sticks and state.sticks[control:GetAttribute("flare-padstick") or 2]
    if not stick then return false end
    if control:GetAttribute("flare-padlog") then control:CallMethod("OnSecureAimLog", button, down, stick.len, next(HELD) or "", STICKY or 0) end
    if stick.len >= %s then
        local interval = 2 * math.pi / count
        local angle = math.atan2(stick.y, stick.x)
        local index = math.floor(((math.pi / 2 - angle) %% (2 * math.pi) + interval / 2) / interval) %% count + 1
        if index ~= STICKY then
            STICKY = index
            control:CallMethod("OnSecureSticky", index)
        end
    end
    if down or not control:GetAttribute("flare-padrelease") or next(HELD) or not STICKY then return false end
    local prefix = control:RunAttribute("flare-aimed")
    control:RunAttribute("flare-closepad")
    if not prefix then return false end
    LAST[ACTIVE] = prefix
    control:CallMethod("OnSecureLast", ACTIVE, prefix)
    for key in gmatch(control:GetAttribute("flare-keys"), "%%S+") do
        self:SetAttribute(key, control:GetAttribute(prefix .. key))
    end
    return nil, "fired"
]]):format(PAD_AIM_LEN)

-- self is the caster, control the header. Returning false cancels the click (a press, or a release
-- in the dead zone). Toggle's second press closes the radial without using anything: only a click
-- uses a button.
local CLICK_SNIPPET = [[
    local screen = control:GetFrameRef("wheel")
    if down then
        -- an extra keybind clicks with its radial's id as the button; the main one with LeftButton
        local id = button
        if id == "LeftButton" then id = control:GetAttribute("flare-assigned") end
        local toggle = control:GetAttribute("flare-toggle")
        if toggle and MODE == "click" and ROOT == id then
            FIRE = nil
            control:RunAttribute("flare-closeclick")
            return false
        end
        FIRE = nil
        control:RunAttribute("flare-closeclick", true)
        control:RunAttribute("flare-closepad", true)
        for key in gmatch(control:GetAttribute("flare-keys"), "%S+") do self:SetAttribute(key, nil) end
        if toggle then
            -- nothing to open: the art of the radial just closed quietly goes too
            if not control:RunAttribute("flare-openclick", id) then control:CallMethod("OnSecureClose") end
            return false
        end
        if control:GetAttribute("flare-subreset") then CHILD = newtable() end
        ACTIVE, MODE, HOLD = id, "hold", id
        -- for the length of the hold: the key with a modifier pressed since still lets go of it,
        -- and Escape cancels
        local variants = control:GetAttribute(id .. "-holdkeys")
        if variants then
            for key in gmatch(variants, "%S+") do
                control:SetBindingClick(true, key, "]] .. CASTER_NAME .. [[", id)
            end
        end
        control:SetBindingClick(true, "ESCAPE", "]] .. CATCHER_NAME .. [[", "RightButton")
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
    -- two keys held: the first one's release belongs to the radial it opened, which another key
    -- has since replaced, so it does nothing
    if MODE == "hold" then
        local id = button
        if id == "LeftButton" then id = control:GetAttribute("flare-assigned") end
        if id ~= HOLD then return false end
    end
    local prefix = MODE == "hold" and control:RunAttribute("flare-aimed") or nil
    if MODE == "hold" then
        control:GetFrameRef("catcher"):Hide()
        control:ClearBindings()
    end
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
    -- the key held (Hold): right-click, left-click or Escape cancels, and the key's release then
    -- fires nothing (left-click too, so a hold whose key-up never came can't keep the mouse, even in
    -- a fight); other buttons do nothing
    if MODE == "hold" then
        if button == "RightButton" or button == "LeftButton" then
            MODE = nil
            OPENX, OPENY = nil, nil
            self:Hide()
            control:GetFrameRef("wheel"):Hide()
            control:ClearBindings()
            control:CallMethod("OnSecureHoldCancel")
        end
        return false
    end
    -- Toggle on a mouse button: pressing that button again closes the radial, as the key does (the
    -- catcher takes every mouse press while the radial is open). The middle button keeps opening
    -- sub-radials.
    local mouseKey = (button == "Button4" and "BUTTON4") or (button == "Button5" and "BUTTON5")
        or (button == "MiddleButton" and "BUTTON3") or nil
    if mouseKey and ROOT and control:GetAttribute(ROOT .. "-mousekey") == mouseKey then
        local index = control:RunAttribute("flare-select")
        local sub = button == "MiddleButton" and index and ACTIVE and control:GetAttribute(ACTIVE .. "-s" .. index .. "-sub")
        if not sub then
            control:RunAttribute("flare-closeclick")
            return false
        end
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
    -- the same macro again closes the radial it opened, as Toggle's key does
    if MODE == "click" and ROOT == id then
        control:RunAttribute("flare-closeclick")
        return false
    end
    control:RunAttribute("flare-closeclick", true)
    control:RunAttribute("flare-closepad", true)
    -- nothing to open: the art of the radial just closed quietly goes too
    if not control:RunAttribute("flare-openclick", id) then control:CallMethod("OnSecureClose") end
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
-- the first radial keeps the tag and the other is opened by its id. A renamed radial keeps its old
-- tags too, so macros typed with the old name still open it, unless a radial now has that name.
local function TagOf(name)
    return (name or ""):gsub("[^%w]", "")
end

local function MacroTags()
    local byTag, tagOf = {}, {}
    local order = RM:GetRadialOrder()
    for _, id in ipairs(order) do
        local data = RM:GetRadial(id)
        local tag = data and TagOf(data.name) or ""
        if tag ~= "" and not byTag[tag:lower()] then
            byTag[tag:lower()], tagOf[id] = id, tag
        end
    end
    for _, id in ipairs(order) do
        local data = RM:GetRadial(id)
        for old in pairs(data and data.oldTags or {}) do
            if not byTag[old] then byTag[old] = id end
        end
    end
    return byTag, tagOf
end

-- Out of combat only. Every key is written, nil included, so a slot that changed kind keeps no
-- stale key; a deleted radial is left with a count of 0.
function SyncSecure()
    if not header or InCombatLockdown() then return end
    -- only what changed: a full rewrite is hundreds of attributes
    local function Set(k, v) if header:GetAttribute(k) ~= v then header:SetAttribute(k, v) end end
    for id in pairs(syncedIDs) do
        if not resolvedCache[id] then
            Set(id .. "-count", 0)
            syncedIDs[id] = nil
        end
    end
    for id, list in pairs(resolvedCache) do
        Set(id .. "-count", #list)
        for i, info in ipairs(list) do
            local children = info.children or { info }
            Set(id .. "-s" .. i .. "-n", #children)
            Set(id .. "-s" .. i .. "-sub", info.radialID)
            for c, child in ipairs(children) do
                local prefix = id .. "-s" .. i .. "-" .. c .. "-"
                for key in ACTION_KEYS:gmatch("%S+") do
                    Set(prefix .. key, child.attributes[key])
                end
            end
        end
        syncedIDs[id] = true
    end
    local byTag = MacroTags()
    for tag in pairs(syncedTags) do
        if not byTag[tag] then
            Set("tag-" .. tag, nil)
            syncedTags[tag] = nil
        end
    end
    for tag, id in pairs(byTag) do
        Set("tag-" .. tag, id)
        syncedTags[tag] = true
    end
    Set("flare-assigned", RM:GetDefaultRadialID())
    Set("flare-center", Option("position", "cursor") == "center")
    Set("flare-toggle", Option("activation", "hold") == "toggle")
    -- Sub-Radials: Reset on Close starts every sub-radial on its first button at each open
    Set("flare-subreset", Option("subRadials", "reset") ~= "remember")
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
    -- a stick bound only with a trigger held stays bound while its radial is open: L3 closes it
    header.OnSecurePadOpen = function(_, radialID)
        OpenRadial(radialID, "pad")
        RM.padRadialOpen = true
        RM.UpdateTriggerSticks()
    end
    header.OnSecureClose = function()
        if openMode == "click" or openMode == "pad" then CloseRadial() end
        if RM.padRadialOpen then
            RM.padRadialOpen = nil
            RM.UpdateTriggerSticks()
        end
    end
    header:SetAttribute("flare-openpad", OPEN_PAD_SNIPPET)
    header:SetAttribute("flare-closepad", CLOSE_PAD_SNIPPET)
    SecureHandlerSetFrameRef(header, "stickguard", GuardStick())

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

    -- the right stick's directions click this, on their press and their release, while a
    -- controller radial is open; a release can use the kept aim (AIM_SNIPPET)
    aimButton = CreateFrame("Button", AIM_NAME, UIParent, "SecureActionButtonTemplate")
    aimButton:RegisterForClicks("AnyDown", "AnyUp")
    aimButton:SetAttribute("useOnKeyDown", false)
    aimButton:SetAttribute("pressAndHoldAction", false)
    SecureHandlerWrapScript(aimButton, "OnClick", header, AIM_SNIPPET, CLEAR_SNIPPET)
    header.OnSecureSticky = function(_, index) padSticky = index end
    -- /fui padlog (11-14): each right-stick direction event while a controller radial is open, for
    -- "Release the stick to use" reports: which key, press or release, how far out, what is still held
    header.OnSecureAimLog = function(_, button, down, len, held, sticky)
        print(("FlareUI pad: %s %s  stick %.2f  held %s  aim %s  release-to-use %s"):format(tostring(button),
            down and "down" or "up", len or 0, held ~= "" and tostring(held) or "-", tostring(sticky),
            header:GetAttribute("flare-padrelease") and "on" or "off"))
    end
    -- the button a controller radial used last (Press again to repeat lights it when nothing is aimed)
    header.OnSecureLast = function(_, radialID, prefix)
        local index = prefix and tonumber(prefix:match("%-s(%d+)%-%d+%-$"))
        if radialID and index then padLast[radialID] = index end
    end
    SecureHandlerExecute(header, "CHILD = newtable(); STACK = newtable(); DEPTH = 0; LAST = newtable()")
end

--------------------------------------------------
-- 11. LIVE PREVIEW
-- The radial editor parks the art in its box, scaled down to fit.
--------------------------------------------------
local PREVIEW_BOX = 200   -- fits the bottom of the settings panel's right column (RadialEditor.lua)

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

-- A settings preview's wheel, apart from the radial and the editor's preview: the first radial this
-- character gets (else six target markers, as a new account's first radial), laid out by the radial's
-- own code with button one aimed at (its slice lit, its name per Show Names). Plain art only.
-- (the wheel sits in a holder with room round it: its slice glow and name hang past the wheel)
function RM.CreateSample(parent)
    local holder = CreateFrame("Frame", nil, parent)
    holder:EnableMouse(false)
    local f = CreateFrame("Frame", nil, holder)
    f.fuiSample = true
    f.buttons = {}
    f:EnableMouse(false)
    f:SetFrameLevel(holder:GetFrameLevel() + 1)
    f:SetPoint("CENTER", holder, "CENTER")
    RM.BuildRadialArt(f)
    holder.wheel = f
    return holder
end

function RM.DrawSample(holder)
    local w, h = RM.DrawWheelSample(holder.wheel)
    local pad = math.ceil(math.max(w, h) * 0.2)
    holder:SetSize(w + 2 * pad, h + 2 * pad)
    return holder:GetWidth(), holder:GetHeight()
end

function RM.DrawWheelSample(f)
    -- read straight from the saved radials: GetStore would create them
    local list
    local store = ns.db and ns.db.global and ns.db.global.radialmenu
    if store and store.radials and store.radialOrder then
        for _, id in ipairs(store.radialOrder) do
            local data = store.radials[id]
            if data and data.buttons and #data.buttons > 0 and RM:IsRadialAvailable(id) then
                list = data.buttons
                break
            end
        end
    end
    local entries = list and ResolveButtons(list) or {}
    if #entries == 0 then
        local markers = {}
        for i = 1, 6 do markers[i] = { kind = "targetmarker", marker = i } end
        entries = ResolveButtons(markers)
    end
    local count, radius, interval = RM.PlaceRadialButtons(f, f.buttons, entries)
    RM:LayoutPing(count, radius, interval, f)
    for i, info in ipairs(entries) do ApplyButtonState(f.buttons[i], info) end
    if count > 0 and f.buttons[1] then
        SetButtonSelected(f.buttons[1], true)
        RM:LightSlice(1, f)
        f.Pointer:SetRotation(QUARTER)
        f.Pointer:Show()
    else
        f.Pointer:Hide()
    end
    f.CancelSelect:Hide()
    f.CancelIcon:SetAlpha(CANCEL_ALPHA_IDLE)
    f:Show()
    return f:GetWidth(), f:GetHeight()
end

--------------------------------------------------
-- 12. GAMEPAD BAR (the Gamepad UI)
-- A radial on a slot of Blizzard's controller bar (LT + A, a D-pad direction ...): an account macro
-- "/click FlareUI_RadialPad <radial id>" (PAD_SNIPPET opens it as the stick press does), placed with
-- Blizzard's own GamepadActionBarBindingUtil, out of combat, on this character
-- (CharDB().padBar[id] = the slot, ns.PadBarKey). The macro's first line marks it as FlareUI's, so no
-- other macro is ever touched. A slot is a crossbar (none, LT, RT or both held) and the button its
-- GAMEPADACTIONBUTTON1-8 binding is on; Blizzard keeps some slots (jump, interact ...) for itself.
--------------------------------------------------
local PAD_MACRO_MARK = "#flareui-radial"
local PAD_BARS = { TOP = "topBar", LT = "leftBar", RT = "rightBar", LTRT = "bottomBar" }

local function PadMacroBody(id)
    return PAD_MACRO_MARK .. "\n/click " .. PAD_NAME .. " " .. id
end

-- the account macro that opens this radial, or nil
local function FindPadMacro(id)
    local body = PadMacroBody(id)
    local accountCount = GetNumMacros()
    for index = 1, accountCount or 0 do
        local _, _, text = GetMacroInfo(index)
        if text and strtrim(text) == body then return index end
    end
end

-- the radial's name cut to a macro name's 16 bytes, never mid-letter
local function PadMacroName(name)
    local out = ""
    for char in (name or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        if #out + #char > 16 then break end
        out = out .. char
    end
    return out ~= "" and out or "Radial"
end

-- every storage slot of the controller bar, on every page
local function ForEachBarSlot(callback)
    local ui = _G.C_GamepadUI
    if not (ui and ui.GetFirstGamepadActionStorageSlotIndex and ui.IsValidGamepadActionStorageSlotIndex) then return end
    local slot = ui.GetFirstGamepadActionStorageSlotIndex()
    while slot and ui.IsValidGamepadActionStorageSlotIndex(slot) do
        callback(slot)
        slot = slot + 1
    end
end

-- the storage slot a bar key presses on the bar's current page, or nil and why
local function BarStorageSlot(key)
    local side, button = ns.ParsePadBar(key)
    local util = _G.GamepadActionBarBindingUtil
    local frame = _G.GamepadMainActionBarFrame
    local pageUnit = frame and frame.PageUnit
    if not (side and util and pageUnit and pageUnit.actionBars) then return nil, "nobar" end
    local slotIndex
    for n = 1, 8 do
        local ok, a, b = pcall(GetBindingKey, "GAMEPADACTIONBUTTON" .. n, 1)
        if ok and (a == button or b == button) then slotIndex = n break end
    end
    local bar = slotIndex and pageUnit.actionBars[PAD_BARS[side]]
    local slotButton = bar and bar.GetActionButtonByIndex and bar:GetActionButtonByIndex(slotIndex)
    local slotID = slotButton and slotButton.GetGamepadPageUnitSlotID and slotButton:GetGamepadPageUnitSlotID()
    if not slotID or not util.IsBindablePageUnitSlotID(slotID) then return nil, "reserved" end
    local storage = util.GetGamepadStorageSlotIndexFromPageAndPageUnitSlotID(pageUnit:GetCurrentPage(), slotID)
    if not storage then return nil, "reserved" end
    return storage
end

-- what a slot holds now, by name, or nil when it is empty
local function SlotContents(slot)
    if not HasAction(slot) then return nil end
    local kind, actionID = GetActionInfo(slot)
    if kind == "spell" then return C_Spell.GetSpellName(actionID) or kind end
    if kind == "item" then return C_Item.GetItemNameByID(actionID) or kind end
    if kind == "macro" then return (GetMacroInfo(actionID)) or kind end
    return GetActionText(slot) or kind or "?"
end

local function PadBarStore()
    local charDB = ns.CharDB()
    charDB.padBar = charDB.padBar or {}
    return charDB.padBar
end

-- where this radial is on this character's controller bar (a bar key), or nil; a slot the player
-- emptied or filled since is forgotten
function RM:GetBarKey(id)
    local key = PadBarStore()[id]
    if not key then return nil end
    local macro = FindPadMacro(id)
    local found = false
    if macro then
        ForEachBarSlot(function(slot)
            local kind, actionID = GetActionInfo(slot)
            if kind == "macro" and actionID == macro then found = true end
        end)
    end
    if not found and _G.C_GamepadUI then PadBarStore()[id] = nil return nil end
    return key
end

-- Puts the radial on the slot `key` presses (this page). Returns true, or false and why: "combat",
-- "nobar", "reserved", "full", or "occupied" plus what is there (force replaces it).
function RM:PlaceOnBar(id, key, force)
    if InCombatLockdown() then return false, "combat" end
    if not self:GetRadial(id) then return false, "nobar" end
    local slot, why = BarStorageSlot(key)
    if not slot then return false, why end
    local macro = FindPadMacro(id)
    local occupant = SlotContents(slot)
    local kind, actionID = GetActionInfo(slot)
    if occupant and not force and not (macro and kind == "macro" and actionID == macro) then
        return false, "occupied", occupant
    end
    if not macro then
        if (GetNumMacros() or 0) >= (MAX_ACCOUNT_MACROS or 120) then return false, "full" end
        local first = resolvedCache[id] and resolvedCache[id][1]
        local texture = first and first.icon and first.icon.texture
        local icon = (type(texture) == "number" or type(texture) == "string") and texture or UNKNOWN_ICON
        macro = CreateMacro(PadMacroName(self:GetRadial(id).name), icon, PadMacroBody(id), false)
        if not macro then return false, "full" end
    end
    -- one place per radial: off any other slot first
    local util = _G.GamepadActionBarBindingUtil
    ForEachBarSlot(function(other)
        local otherKind, otherID = GetActionInfo(other)
        if other ~= slot and otherKind == "macro" and otherID == macro then util.ClearActionFromGamepadSlot(other) end
    end)
    util.AssignActionToGamepadStandardSlot(slot, PickupMacro, macro)
    ClearCursor()
    PadBarStore()[id] = key
    return true
end

-- off this character's controller bar (the macro stays for the other characters)
function RM:RemoveFromBar(id)
    if InCombatLockdown() then return false end
    local macro = FindPadMacro(id)
    local util = _G.GamepadActionBarBindingUtil
    if macro and util then
        ForEachBarSlot(function(slot)
            local kind, actionID = GetActionInfo(slot)
            if kind == "macro" and actionID == macro then util.ClearActionFromGamepadSlot(slot) end
        end)
    end
    PadBarStore()[id] = nil
    return true
end

--------------------------------------------------
-- 13. RADIAL LIBRARY
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

-- GROUPS (11-12, Marcus): radials gathered under a named, foldable row in the editor's list. A
-- radial's group is radial.group (store.groups[gid] = { name }); a group's radials stay next to each
-- other in radialOrder, where its first one is, so the list order (and which radial a shared key
-- opens) is the order seen. A group with no radial left is gone. Folded or open: per character
-- (CharDB().radialGroupsClosed).
local function NormalizeGroups(store)
    store.groups = store.groups or {}
    local order, radials = store.radialOrder, store.radials
    local used = {}
    for _, id in ipairs(order) do
        local r = radials[id]
        if r and r.group and not store.groups[r.group] then r.group = nil end
        if r and r.group then used[r.group] = true end
    end
    for gid in pairs(store.groups) do if not used[gid] then store.groups[gid] = nil end end
    local out, done = {}, {}
    for _, id in ipairs(order) do
        if not done[id] then
            local gid = radials[id] and radials[id].group
            if gid then
                for _, other in ipairs(order) do
                    if not done[other] and radials[other] and radials[other].group == gid then
                        out[#out + 1], done[other] = other, true
                    end
                end
            else
                out[#out + 1], done[id] = id, true
            end
        end
    end
    wipe(order)
    for i, id in ipairs(out) do order[i] = id end
end

local function GroupsChanged(self)
    syncDirty = true
    NormalizeGroups(GetStore())
    self:LoadActiveRadial()
end

function RM:GetGroup(gid)
    local store = GetStore()
    return store and store.groups and store.groups[gid]
end

function RM:GetGroups()
    local store = GetStore()
    return store and store.groups or {}
end

-- a group's first and last place in radialOrder
local function GroupSpan(order, radials, gid)
    local first, last
    for i, id in ipairs(order) do
        if radials[id] and radials[id].group == gid then first = first or i; last = i end
    end
    return first, last
end

-- a new group holding the radial, where the radial is
function RM:CreateGroupWith(id, name)
    local store = GetStore()
    if not (store and store.radials[id]) then return nil end
    store.groups = store.groups or {}
    store.nextGroupID = store.nextGroupID or 1
    local gid = "g" .. store.nextGroupID
    store.nextGroupID = store.nextGroupID + 1
    store.groups[gid] = { name = name }
    store.radials[id].group = gid
    GroupsChanged(self)
    return gid
end

function RM:RenameGroup(gid, name)
    local group = self:GetGroup(gid)
    if group and name and name ~= "" then group.name = name; syncDirty = true end
end

-- its radials stay where they are, out of any group
function RM:Ungroup(gid)
    local store = GetStore()
    if not store then return end
    for _, data in pairs(store.radials) do
        if data.group == gid then data.group = nil end
    end
    if store.groups then store.groups[gid] = nil end
    GroupsChanged(self)
end

-- into a group (at its end) or, gid nil, out of its group (just under it)
function RM:SetRadialGroup(id, gid)
    local store = GetStore()
    local data = store and store.radials[id]
    if not data or data.group == gid then return end
    local order = store.radialOrder
    local anchor = gid or data.group
    data.group = gid
    for i, other in ipairs(order) do if other == id then table.remove(order, i) break end end
    local _, last = GroupSpan(order, store.radials, anchor)
    table.insert(order, last and (last + 1) or (#order + 1), id)
    GroupsChanged(self)
end

-- the radials list's drag (11-12, Marcus): id moves to where target is, and into target's group
-- (or out of its own, onto a radial outside one)
function RM:MoveRadial(id, target)
    local store = GetStore()
    local order = self:GetRadialOrder()
    local from, to
    for i, other in ipairs(order) do
        if other == id then from = i end
        if other == target then to = i end
    end
    if not (from and to) or from == to then return false end
    local data, targetData = store.radials[id], store.radials[target]
    if data and targetData then data.group = targetData.group end
    table.remove(order, from)
    table.insert(order, to, id)
    GroupsChanged(self)
    return true
end

-- a whole group to where target is (a radial id, or a group's "group:gid")
function RM:MoveGroup(gid, target)
    local store = GetStore()
    if not store then return false end
    local order, radials = store.radialOrder, store.radials
    local targetGroup = target and target:match("^group:(.+)$")
    if targetGroup == gid then return false end
    -- dropped on one of its own radials: nowhere to go
    if not targetGroup and radials[target] and radials[target].group == gid then return false end
    -- the unit the target belongs to: its group, or the radial alone
    local function UnitOf()
        if targetGroup then return GroupSpan(order, radials, targetGroup) end
        local tg = radials[target] and radials[target].group
        if tg then return GroupSpan(order, radials, tg) end
        for i, id in ipairs(order) do if id == target then return i, i end end
    end
    local blockFirst = GroupSpan(order, radials, gid)
    local tFirst = UnitOf()
    if not (blockFirst and tFirst) then return false end
    local down = blockFirst < tFirst
    local block = {}
    for i = #order, 1, -1 do
        local id = order[i]
        if radials[id] and radials[id].group == gid then table.insert(block, 1, table.remove(order, i)) end
    end
    local first, last = UnitOf()
    if not first then return false end
    local at = down and (last + 1) or first
    for i, id in ipairs(block) do table.insert(order, at + i - 1, id) end
    GroupsChanged(self)
    return true
end

-- folded or open, per character
function RM:IsGroupOpen(gid)
    local me = ns.CharDB and ns.CharDB()
    return not (me and me.radialGroupsClosed and me.radialGroupsClosed[gid])
end
function RM:SetGroupOpen(gid, open)
    local me = ns.CharDB and ns.CharDB()
    if not me then return end
    me.radialGroupsClosed = me.radialGroupsClosed or {}
    me.radialGroupsClosed[gid] = (not open) or nil
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

-- scope: who gets it (see AVAILABILITY below); a new radial has no key yet
function RM:CreateRadial(name, scope)
    syncDirty = true
    local store = GetStore()
    if not store then return nil end
    local id = "r" .. store.nextRadialID
    store.nextRadialID = store.nextRadialID + 1
    store.radials[id] = { name = name or "New Radial", buttons = {} }
    store.radialOrder[#store.radialOrder + 1] = id
    if scope then self:SetRadialScope(id, scope) end
    return id
end

-- a copy keeps the buttons and who gets it, but no key (it would only clash with the original)
function RM:CopyRadial(id, name)
    syncDirty = true
    local data = self:GetRadial(id)
    if not data then return nil end
    local copy = self:CreateRadial(name or data.name)
    local new = self:GetRadial(copy)
    new.buttons = CopyTable(data.buttons)
    new.scope, new.scopeName = data.scope, data.scopeName
    return copy
end

function RM:RenameRadial(id, name)
    syncDirty = true
    local data = self:GetRadial(id)
    if not (data and name and name ~= "") then return end
    local old = TagOf(data.name):lower()
    if old ~= "" and old ~= TagOf(name):lower() then
        data.oldTags = data.oldTags or {}
        data.oldTags[old] = true
    end
    if data.oldTags then data.oldTags[TagOf(name):lower()] = nil end
    if data.oldTags and not next(data.oldTags) then data.oldTags = nil end
    data.name = name
    -- its gamepad bar macro is named after it
    local macro = not InCombatLockdown() and FindPadMacro(id)
    if macro then
        local _, icon, body = GetMacroInfo(macro)
        EditMacro(macro, PadMacroName(name), icon, body)
    end
end

function RM:DeleteRadial(id)
    syncDirty = true
    local store = GetStore()
    if not (store and store.radials[id]) then return end
    store.radials[id] = nil
    for i, other in ipairs(store.radialOrder) do
        if other == id then table.remove(store.radialOrder, i) break end
    end
    NormalizeGroups(store)   -- a group left empty goes
    local charDB = ns.CharDB()
    if charDB.radialKeyOverride then charDB.radialKeyOverride[id] = nil end
    -- its gamepad bar macro goes too (deleting a macro empties its bar slots)
    local macro = not InCombatLockdown() and FindPadMacro(id)
    if macro then DeleteMacro(macro) end
    if charDB.padBar then charDB.padBar[id] = nil end
    self:LoadActiveRadial()
    self:LayoutRadial()
    self:ApplyBindings()
end

-- the macro line that opens this radial ("Radial Macros")
function RM:GetMacroText(radialID)
    if not radialID then return "" end
    local _, tagOf = MacroTags()
    return "/click " .. MACRO_NAME .. " " .. (tagOf[radialID] or radialID)
end

-- currentRadial is the saved button list itself, so edits show without copying
function RM:LoadRadial(radialID)
    local data = self:GetRadial(radialID)
    currentID = data and radialID or nil
    currentRadial = data and data.buttons or {}
end

function RM:LoadActiveRadial()
    self:LoadRadial(self:GetDefaultRadialID())
end

--------------------------------------------------
-- 14. AVAILABILITY AND KEYS
-- Each radial says who gets it (radial.scope) and has its own key (radial.key), which every
-- character it is available to shares. A character can keep its own key for a radial instead
-- (CharDB().radialKeyOverride[id]: a key, or false for none). Override bindings are protected: a
-- change in combat waits for the fight to end.
--------------------------------------------------
-- radial.scope: nil (every character), "faction:Horde", "class:DRUID" or "char:<GUID>";
-- radial.scopeName keeps that character's name for the settings. More specific wins a shared key.
local SCOPE_RANK = { faction = 1, class = 2, char = 3 }
local OWN_KEY_RANK = 4

local function SplitScope(scope)
    if type(scope) ~= "string" then return nil end
    return scope:match("^(%a+):(.+)$")
end
RM.SplitScope = SplitScope

-- Alliance or Horde; nil before a faction is chosen
local function PlayerFaction()
    local faction = UnitFactionGroup("player")
    return (faction == "Alliance" or faction == "Horde") and faction or nil
end

-- the scopes this character can give a radial, widest first
function RM:GetScopeChoices()
    local _, class = UnitClass("player")
    local list = { "" }
    local faction = PlayerFaction()
    if faction then list[#list + 1] = "faction:" .. faction end
    if class then list[#list + 1] = "class:" .. class end
    local guid = ns.PlayerGUID()
    if guid then list[#list + 1] = "char:" .. guid end
    return list
end

function RM:IsRadialAvailable(id)
    local data = self:GetRadial(id)
    if not data then return false end
    local kind, value = SplitScope(data.scope)
    if kind == "faction" then return value == PlayerFaction() end
    if kind == "class" then return value == select(2, UnitClass("player")) end
    if kind == "char" then return value == ns.PlayerGUID() end
    return true
end

-- scope "" or nil: every character
function RM:SetRadialScope(id, scope)
    syncDirty = true
    local data = self:GetRadial(id)
    if not data then return end
    scope = (scope ~= "" and scope) or nil
    data.scope = scope
    data.scopeName = (SplitScope(scope) == "char") and UnitName("player") or nil
    self:AvailabilityChanged()
end

-- what a character can open changed: relayout (the secure copy drops what is not available) and rebind
function RM:AvailabilityChanged()
    self:LoadActiveRadial()
    if previewID then self:RefreshPreview() else self:LayoutRadial() end
    self:ApplyBindings()
end

local function KeyOverrides()
    local charDB = ns.CharDB()
    charDB.radialKeyOverride = charDB.radialKeyOverride or {}
    return charDB.radialKeyOverride
end

-- the key a radial has on this character (nil for none), and true when it is this character's own
function RM:GetRadialKey(id)
    local data = self:GetRadial(id)
    if not data then return nil, false end
    local own = KeyOverrides()[id]
    if own ~= nil then return own or nil, true end
    return data.key, false
end

-- the key every character with the radial shares
function RM:GetSharedKey(id)
    local data = self:GetRadial(id)
    return data and data.key
end

-- sets the key for every character with the radial, or only for this one while it keeps its own
function RM:SetRadialKey(id, key)
    syncDirty = true
    local data = self:GetRadial(id)
    if not data then return end
    key = (key and key ~= "") and key or nil
    local overrides = KeyOverrides()
    if overrides[id] ~= nil then
        overrides[id] = key or false
    else
        data.key = key
    end
    self:ApplyBindings()
end

function RM:HasOwnKey(id)
    return KeyOverrides()[id] ~= nil
end

-- on: this character starts from the shared key and keeps its own from then on; off: back to the
-- shared key
function RM:SetOwnKey(id, on)
    local data = self:GetRadial(id)
    if not data then return end
    local overrides = KeyOverrides()
    if on then
        if overrides[id] == nil then overrides[id] = data.key or false end
    else
        overrides[id] = nil
    end
    self:ApplyBindings()
end

-- Every key on this character. Returns key -> the radial it opens, and per available radial with a
-- key { key, own, rank, beatenBy, tie }: a character's own key beats This character, class,
-- faction and every character, in that order; a tie goes to the radial listed first.
function RM:ResolveKeys()
    local winner, perRadial = {}, {}
    for _, id in ipairs(self:GetRadialOrder()) do
        if self:IsRadialAvailable(id) then
            local key, own = self:GetRadialKey(id)
            if key then
                local rank = own and OWN_KEY_RANK or SCOPE_RANK[SplitScope(self:GetRadial(id).scope) or ""] or 0
                perRadial[id] = { key = key, own = own, rank = rank }
                local holder = winner[key]
                if not holder or rank > perRadial[holder].rank then winner[key] = id end
            end
        end
    end
    for id, info in pairs(perRadial) do
        local holder = winner[info.key]
        if holder ~= id then
            info.beatenBy = holder
            info.tie = perRadial[holder].rank == info.rank
        end
    end
    return winner, perRadial
end

-- A radial's controller button (radial.padKey): a stick press, alone or with LT / RT held
-- (ns.PadComboKey), shared by every character that gets the radial. It is kept apart from the key, so
-- switching between keyboard and Gamepad mode keeps both.
function RM:GetPadKey(id)
    local data = self:GetRadial(id)
    return data and data.padKey
end

function RM:SetPadKey(id, key)
    syncDirty = true
    local data = self:GetRadial(id)
    if not data then return end
    data.padKey = (key and ns.ParsePadCombo(key)) and key or nil
    self:ApplyBindings()
end

-- controller button -> the radial it opens on this character: the narrower scope wins (This
-- character, class, faction, every character), a tie goes to the radial listed first
function RM:ResolvePadKeys()
    local winner, rankOf = {}, {}
    for _, id in ipairs(self:GetRadialOrder()) do
        local key = self:IsRadialAvailable(id) and self:GetPadKey(id)
        if key then
            local rank = SCOPE_RANK[SplitScope(self:GetRadial(id).scope) or ""] or 0
            rankOf[id] = rank
            local holder = winner[key]
            if not holder or rank > rankOf[holder] then winner[key] = id end
        end
    end
    return winner
end

-- what the controller, a bare macro and a reset open: the first radial with a working key here,
-- else the first radial available here
function RM:GetDefaultRadialID()
    local _, perRadial = self:ResolveKeys()
    local first
    for _, id in ipairs(self:GetRadialOrder()) do
        if self:IsRadialAvailable(id) then
            local info = perRadial[id]
            if info and not info.beatenBy then return id end
            first = first or id
        end
    end
    return first
end

-- StickIndexToConfigName counts from 0, the mapped state from 1
local function RightStickIndex()
    for i = 0, 7 do
        local ok, configName = pcall(C_GamePad.StickIndexToConfigName, i)
        if ok and configName == "Right" then return i + 1 end
    end
    return 2
end

-- The key with every modifier set that keeps its own (F: SHIFT-F, CTRL-F, ALT-SHIFT-F ...; SHIFT-F:
-- CTRL-SHIFT-F ...), leaving out any that another radial uses. A modifier pressed during a hold
-- changes which binding the key's release goes to; these catch it.
local MODIFIERS = { "ALT", "CTRL", "SHIFT" }
function RM.HoldVariants(key, taken)
    local own, base = {}, key
    while true do
        local mod, rest = base:match("^(%u+)%-(.+)$")
        if not (mod and (mod == "ALT" or mod == "CTRL" or mod == "SHIFT")) then break end
        own[mod], base = true, rest
    end
    local out = {}
    for mask = 1, 7 do
        local parts, keeps, adds = {}, true, false
        for i, mod in ipairs(MODIFIERS) do
            local on = mask % (2 ^ i) >= 2 ^ (i - 1)
            if on then parts[#parts + 1] = mod; if not own[mod] then adds = true end
            elseif own[mod] then keeps = false end
        end
        if keeps and adds then
            parts[#parts + 1] = base
            local variant = table.concat(parts, "-")
            if not taken[variant] then out[#out + 1] = variant end
        end
    end
    return table.concat(out, " ")
end

-- each key clicks the caster with its radial's id as the mouse button
local function ApplyBinding()
    if not (radial and caster) then return end
    if InCombatLockdown() then
        RM.bindingPending = true
        return
    end
    RM.bindingPending = nil
    ClearOverrideBindings(radial)
    local winner = RM:ResolveKeys()
    -- a radial on a mouse button: the catcher needs to know it (Toggle's "press again to close")
    -- and the key with each modifier added, bound only while it's held (HoldVariants)
    if header then
        for id in pairs(mouseKeyed) do
            header:SetAttribute(id .. "-mousekey", nil)
            header:SetAttribute(id .. "-holdkeys", nil)
        end
        wipe(mouseKeyed)
    end
    local padOn = ns.IsGamepadUI() and RM:IsControllerEnabled() and padButton ~= nil and not ns.OtherControllerAddon()
    local padSticks = {}
    if header then
        for _, stick in ipairs(PAD_COMBO_STICKS) do
            for _, side in ipairs(PAD_COMBO_SIDES) do header:SetAttribute("flare-pad-" .. stick .. "-" .. side, nil) end
        end
    end
    -- controller buttons: the pad button reads the triggers held with the stick press (PAD_SNIPPET);
    -- only in the Gamepad UI
    if padOn then
        for key, id in pairs(RM:ResolvePadKeys()) do
            local stick, side = ns.ParsePadCombo(key)
            if stick then
                header:SetAttribute("flare-pad-" .. stick .. "-" .. side, id)
                padSticks[stick] = padSticks[stick] or {}
                padSticks[stick][side] = true
            end
        end
    end
    for key, id in pairs(winner) do
        -- a controller combo saved as a key is never bound as one
        if not ns.ParsePadCombo(key) then
            SetOverrideBindingClick(radial, true, key, CASTER_NAME, id)
            if header then
                if key == "BUTTON3" or key == "BUTTON4" or key == "BUTTON5" then
                    header:SetAttribute(id .. "-mousekey", key)
                end
                local variants = RM.HoldVariants(key, winner)
                if variants ~= "" then
                    local before = header:GetAttribute(id .. "-holdkeys")
                    header:SetAttribute(id .. "-holdkeys", before and (before .. " " .. variants) or variants)
                end
                mouseKeyed[id] = true
            end
        end
    end
    local store = GetStore()
    local default = RM:GetDefaultRadialID()
    if header then header:SetAttribute("flare-assigned", default) end
    if not padOn then
        RM.triggerSticks = nil
        RM.UpdateTriggerSticks()
        return
    end
    -- Settings that switched controller support on by hand (store.controller == true) keep L3 opening
    -- the first radial until a radial gets a controller button; everyone else keeps L3 for Auto Run.
    if not next(padSticks) and store and store.controller == true and default then
        header:SetAttribute("flare-pad-L3-TOP", default)
        padSticks.L3 = { TOP = true }
    end
    -- the right stick aims (the camera holds still while it is open, section 7) whatever opened the
    -- radial (a stick press or a gamepad bar macro); LT and RT are read as the mapped state's buttons
    -- by the keys the controller bar put them on
    padStickIndex = RightStickIndex()
    header:SetAttribute("flare-padstick", padStickIndex)
    header:SetAttribute("flare-padrelease", RM:IsPadReleaseOn() or nil)
    header:SetAttribute("flare-padrepeat", RM:IsPadRepeatOn() or nil)
    for attribute, side in pairs({ ["flare-ltindex"] = "LT", ["flare-rtindex"] = "RT" }) do
        local index = C_GamePad.ButtonBindingToIndex and C_GamePad.ButtonBindingToIndex(ns.PadTriggerKey(side))
        header:SetAttribute(attribute, index and index + 1 or nil)
    end
    RM.triggerSticks = {}
    for stick, sides in pairs(padSticks) do
        if sides.TOP then
            SetOverrideBindingClick(radial, true, ns.PadStickKey(stick), PAD_NAME, "Pad" .. stick)
        else
            RM.triggerSticks[stick] = sides
        end
    end
    RM.UpdateTriggerSticks()
end

-- A stick whose radials all need a trigger held (LT + L3) leaves the stick's own press to the game
-- (L3 Auto Run, R3 ping): LT and RT are the crossbar's modifiers, not keys a binding can carry, so the
-- stick is bound only while a trigger with a radial on it is held, as the game reports the crossbar
-- (GamepadMode.RegisterCrossBarModifierStateChanged). Bindings can't change in a fight: the stick is
-- bound for the whole of it, so its own press waits for the fight's end.
RM.triggerHeld = { left = false, right = false }
function RM.UpdateTriggerSticks()
    if InCombatLockdown() then return end
    local owner = RM.triggerOwner
    if not owner then
        owner = CreateFrame("Frame")
        RM.triggerOwner = owner
        owner:SetScript("OnEvent", function(_, event)
            if event == "PLAYER_REGEN_DISABLED" then RM.inFight = true
            elseif event == "PLAYER_REGEN_ENABLED" then RM.inFight = nil end
            RM.UpdateTriggerSticks()
        end)
        -- (the event comes before the lockdown: a binding can still change here)
        owner:RegisterEvent("PLAYER_REGEN_DISABLED")
        owner:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
    ClearOverrideBindings(owner)
    local sticks = RM.triggerSticks
    if not (sticks and next(sticks)) then return end
    if not RM.crossbarWatched and GamepadMode and GamepadMode.RegisterCrossBarModifierStateChanged then
        RM.crossbarWatched = true
        GamepadMode.RegisterCrossBarModifierStateChanged(function(_, side, down)
            if side ~= "left" and side ~= "right" then return end
            RM.triggerHeld[side] = down and true or false
            RM.UpdateTriggerSticks()
        end, RM)
    end
    local held = RM.triggerHeld
    local side = (held.left and held.right and "LTRT") or (held.left and "LT") or (held.right and "RT") or nil
    for stick, sides in pairs(sticks) do
        if RM.inFight or RM.padRadialOpen or (side and sides[side]) then
            SetOverrideBindingClick(owner, true, ns.PadStickKey(stick), PAD_NAME, "Pad" .. stick)
        end
    end
end

-- Release the stick to use (store.padRelease): on unless switched off
-- /fui padlog: the aim log on or off (out of combat: a secure attribute)
function RM.PadLogCommand()
    if not header or InCombatLockdown() then print("FlareUI: try again out of combat.") return end
    local on = not header:GetAttribute("flare-padlog")
    header:SetAttribute("flare-padlog", on or nil)
    print("FlareUI pad log " .. (on and "on" or "off"))
end

function RM:IsPadReleaseOn()
    local store = GetStore()
    return store ~= nil and store.padRelease ~= false
end

function RM:SetPadReleaseOn(on)
    local store = GetStore()
    if not store then return end
    store.padRelease = on and true or false
    ApplyBinding()
end

-- Press again to repeat (store.padRepeat): off unless switched on
function RM:IsPadRepeatOn()
    local store = GetStore()
    return store ~= nil and store.padRepeat == true
end

function RM:SetPadRepeatOn(on)
    local store = GetStore()
    if not store then return end
    store.padRepeat = on and true or nil
    ApplyBinding()
end

-- on unless switched off (store.controller == false)
function RM:IsControllerEnabled()
    local store = GetStore()
    return store ~= nil and store.controller ~= false
end

-- switching on stores nil, not true: true is the old setting that keeps L3 on the first radial
function RM:SetControllerEnabled(enabled)
    local store = GetStore()
    if not store then return end
    if not enabled then
        store.controller = false
    elseif store.controller == false then
        store.controller = nil
    end
    ApplyBinding()
end

function RM:ApplyBindings()
    ApplyBinding()
end

-- Older settings: the account key (store.key) opened each character's chosen radial (charDB.radial), each
-- character kept up to five extra keys (charDB.radialKeys), and a character never set up copied the
-- last setup changed (store.lastSetup). That last setup becomes the radials' own keys, and every
-- character that differed keeps its keys as its own, so nothing changes in game. Every radial
-- starts available to every character.
local function MigrateKeys()
    local store = GetStore()
    if not store or store.keysPerRadial then return end
    store.keysPerRadial = true
    local radials, order = store.radials, store.radialOrder
    -- as the old GetAssignedRadialID: "" chose none, nil or a deleted one gets the first radial
    local function Pick(choice)
        if choice == "" then return nil end
        if choice and radials[choice] then return choice end
        return order[1]
    end
    -- radial id -> key; a radial now has one key, the first it had
    local function Setup(choice, extras)
        local map, used = {}, {}
        local main = Pick(choice)
        if main and store.key then map[main], used[store.key] = store.key, true end
        for _, extra in ipairs(extras or {}) do
            local id, key = extra.radial, extra.key
            if key and id and radials[id] and not map[id] and not used[key] then map[id], used[key] = key, true end
        end
        return map
    end
    local last = store.lastSetup
    local shared = last and Setup(last.radial, last.keys) or Setup(nil, nil)
    for id, data in pairs(radials) do data.key = shared[id] end
    for _, charDB in pairs(ns.db.global.characters or {}) do
        local choice = charDB.radial
        if choice == nil then choice = charDB.ring end
        if choice ~= nil or charDB.radialKeys ~= nil then
            local own = Setup(choice, charDB.radialKeys)
            for id in pairs(radials) do
                if own[id] ~= shared[id] then
                    charDB.radialKeyOverride = charDB.radialKeyOverride or {}
                    charDB.radialKeyOverride[id] = own[id] or false
                end
            end
        end
        charDB.radial, charDB.ring, charDB.radialKeys = nil, nil, nil
    end
    store.key, store.lastSetup = nil, nil
end

function RM:PLAYER_REGEN_ENABLED()
    if self.securePending then
        self.securePending = nil
        CreateSecureLayer()
        ApplyBinding()
    end
    if self.bindingPending then ApplyBinding() end
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
-- 15. PUBLIC
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
            self:ClearBindings()
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
    -- a controller radial left open by a crash or reload: the stick-direction CVar goes back
    SetStickKeys(false)

    MigrateKeys()
    -- a controller combo saved as a key moves to its own field
    for _, data in pairs(GetStore() and GetStore().radials or {}) do
        if ns.ParsePadCombo(data.key) then data.padKey, data.key = data.padKey or data.key, nil end
    end
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
    -- the spellbook changed: each spell's best rank is read again
    self:RegisterEvent("SPELLS_CHANGED", RM.ForgetRanks)
    -- a loading screen during a hold: the key's release never comes
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        if isOpen and openMode == "hold" then
            RM.EndHold()
            CloseRadial()
        end
    end)
    -- a character that picks its faction now gets that faction's radials (absent on some clients)
    pcall(self.RegisterEvent, self, "NEUTRAL_FACTION_SELECT_RESULT", function() self:AvailabilityChanged() end)
    -- an item button resolves once its name is cached; the event fires for every item loaded
    local relayoutQueued = false
    self:RegisterEvent("ITEM_DATA_LOAD_RESULT", function(_, itemID, success)
        if not awaitedItems[itemID] then return end
        awaitedItems[itemID] = nil
        if success == false then return end   -- no data came: nothing new to show
        if relayoutQueued then return end
        relayoutQueued = true
        C_Timer.After(0.1, function()
            relayoutQueued = false
            if previewID then self:RefreshPreview() else self:LayoutRadial() end
        end)
    end)
end

-- anything that changes what a button resolves to (the spellbook, macros, bags, mounts, an edit)
-- rewrites the secure copy on the next open
function RM.MarkDirty() syncDirty = true end
local dirtyEvents = CreateFrame("Frame")
for _, event in ipairs({ "SPELLS_CHANGED", "UPDATE_MACROS", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED",
                         "NEW_MOUNT_ADDED", "COMPANION_LEARNED", "COMPANION_UNLEARNED", "PLAYER_GUILD_UPDATE",
                         "LEARNED_SPELL_IN_SKILL_LINE", "PLAYER_TALENT_UPDATE", "UPDATE_SHAPESHIFT_FORMS", "UNIT_PET",
                         "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_WATCH_LIST_CHANGED", "GROUP_ROSTER_UPDATE" }) do
    pcall(dirtyEvents.RegisterEvent, dirtyEvents, event)
end
dirtyEvents:SetScript("OnEvent", RM.MarkDirty)

function RM:RadialChanged(radialID)
    syncDirty = true
    if previewID and (radialID == nil or radialID == previewID) then
        self:RefreshPreview()
        return
    end
    if radialID == nil or radialID == self:GetDefaultRadialID() then
        self:LoadActiveRadial()
        self:LayoutRadial()
    end
end
