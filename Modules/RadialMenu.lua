local _, ns = ...

--------------------------------------------------
-- 1. MODULE REGISTRATION
-- A radial menu: hold the binding, sweep the mouse, release to fire the button you
-- landed on. It works the same in combat as out of it:
--   * the radial is ordinary art, so we can show / move / resize it whenever we like, and plain Lua
--     highlights the hovered button from the cursor angle
--   * ONE SecureActionButton (the caster) carries the action, and the binding clicks it on release
--   * a secure snippet wrapped round the caster picks the radial button again, with the same maths,
--     and writes the caster's attributes - secure code may do that in combat, plain Lua may not
-- The snippet layer needs Forever build 1.60.1.70009 or later: earlier builds could not compile
-- snippets at all, and the radial kept only its panel buttons in a fight.
-- Radial macros: "/click FUIRadial <radial name>" opens any radial in click mode, for macros with
-- conditionals and for a radial button that opens another radial. A /click never delivers a key
-- release, so a macro radial stays open: click the button you want (or press the macro again to fire
-- the aimed one); right-click or Escape closes it. See section 9.
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
-- Geometry and the selection maths follow Blizzard's own radial wheel
-- (SharedXML/Blizzard_RadialWheel.lua), which drives the in-game ping wheel: button one at the top,
-- a dead zone in the middle that means "cancel", and the pointer rotated to the cursor angle.
--------------------------------------------------
local TAU = math_pi * 2
local QUARTER = math_pi / 2

local CASTER_NAME  = "FlareUI_RadialCaster"
local WHEEL_NAME   = "FlareUI_RadialWheel"
local CATCHER_NAME = "FlareUI_RadialCatcher"
local MACRO_NAME   = "FUIRadial"   -- the button macros /click; kept short, users type it
local PAD_NAME     = "FlareUI_RadialPad"   -- what the stick press clicks in controller mode
local PAD_CANCEL   = GAMEPAD_FACE_RIGHT or "PAD2"   -- B / Circle closes a controller radial
local PAD_DEAD_LEN = 0.5          -- a stick pushed less than this aims at nothing (the X)

-- Blizzard's ping wheel art. The pointer and the backdrop are independent of button count; only the
-- wheel plate and wedge highlight are count-specific (Count_4 is the only one the client ships),
-- so the selection is shown by scaling the icon up and brightening it past its own colours.
local ATLAS_POINTER       = "Radial_Wheel_Select_Pointer"
-- Blizzard's wheel plate (Radial_Wheel_BG) is deliberately not used: it darkens whatever is behind
-- the radial, and the radial reads better floating over the world.
local ATLAS_CIRCLE_MASK   = "CircleMaskScalable"
-- the X in the middle of the ping wheel, and the circle that lights up behind it
local ATLAS_CANCEL_ICON   = "Radial_Wheel_Icon_Close"
local ATLAS_CANCEL_SELECT = "Radial_Wheel_Select_Close"
local CANCEL_ICON_SIZE    = 24
local CANCEL_SELECT_SIZE  = 48
local CANCEL_ALPHA_IDLE   = 0.5
-- Blizzard calls Pointer:SetRotation(angle) with the raw atan2 result; if the art turns out to
-- rest pointing up rather than right, this is the one value to change.
local POINTER_ROTATION_OFFSET = 0
local POINTER_SIZE = 84

local DEAD_ZONE_SQ = 500          -- cursor closer than this to the centre selects nothing
local ICON_SIZE    = 46
-- Centre of the radial to centre of a button icon, from the button count rather than a setting, so any
-- radial spreads its icons out comfortably: 90 up to four buttons, then 7.5 more per button, which is
-- 120 at eight and 150 at the maximum of twelve.
local RADIUS_MIN, RADIUS_FLAT_BUTTONS, RADIUS_PER_BUTTON = 90, 4, 7.5
-- Round buttons are sized on their own, not off ICON_SIZE, so the icon can run right up to its rim
-- and the whole button reads bigger at the same footprint.
local ROUND_SIZE   = 52           -- outer diameter of a round button
local ROUND_BORDER = 3            -- rim thickness for the drawn fallback below
local ROUND_ICON   = ROUND_SIZE - ROUND_BORDER * 2

-- A round button is framed by the first of these the client actually has. The first is the rim the
-- spellbook puts round a passive ability (Blizzard_SpellBookItem.lua:694, the Circle art set) with
-- the gold rim of the same family for the selected button - one family, same geometry, so the two
-- swap cleanly with no tinting at all. The second is Blizzard's azerite rim, which carries its own
-- padding and so holds a smaller icon, and has to be tinted because it has no second state.
-- None of these atlases are in the Forever API snapshot, so the choice is made in the client.
local ROUND_STYLES = {
    {
        mask = "talents-node-circle-mask",
        idle = "talents-node-circle-gray", active = "talents-node-circle-yellow",
        -- the silver is neutral, so a warm multiply pulls it towards the bronze of the rest of the
        -- UI without flattening the metal out of it
        idleTint = { 0.92, 0.76, 0.52 },
        iconFactor = 1.00,
    },
    {
        mask = "CircleMaskScalable",
        idle = "Azerite-Trait-Ring", active = "Azerite-Trait-Ring", tint = true,
        iconFactor = 0.74,
    },
}
local RIM_TINT_NONE = { 1, 1, 1 }
-- Idle borders sit at the dark bronze of the action bar gryphons; the selected one jumps to the
-- yellow of Blizzard's own pointer art, so the border and the arrow read as one piece.
local BORDER_COLOR         = { 0.45, 0.33, 0.19 }   -- #735430, the brown of the panel frames
local BORDER_COLOR_ACTIVE  = { 0.98, 0.87, 0.26 }   -- #FADE42, the Radial_Wheel pointer yellow
-- Idle icons show their art as it is; the hovered one gets an additive white wash on top, which
-- lifts it above its own colours rather than just undoing a dim.
local ICON_SCALE_IDLE      = 0.88
local ICON_GLOW_ALPHA      = 0.30 -- additive wash over the selected button's own art

-- Unusable buttons are tinted the way Blizzard's action buttons are (ActionButton.lua): grey when
-- the action cannot be used, blue when only the mana is missing. The cooldown swipe is cut to a
-- circle by its texture, the portrait mask, so it stays inside the round icon.
local TINT_USABLE   = { 1, 1, 1 }
local TINT_UNUSABLE = { 0.4, 0.4, 0.4 }
local TINT_NO_MANA  = { 0.5, 0.5, 1 }
local SWIPE_TEXTURE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

local STUCK_OPEN_SECONDS = 20     -- see the guard in UpdateSelection

local MAX_BUTTONS = 12             -- more than this and a radial stops being quicker than a bar
local MAX_EXTRA_KEYS = 5           -- extra keybinds per character, each opening its own radial
local MAX_RADIAL_DEPTH = 4          -- a radial inside a radial inside a radial is already past useful

local radial, caster, header, wheel, buttons = nil, nil, nil, nil, {}
local catcher, macroButton          -- click mode's full-screen catcher, and the button macros click
local padButton                     -- controller mode's button, clicked by the stick press
local padStickIndex = 2             -- the right stick in C_GamePad's mapped state (RightStickIndex)
local isOpen, selectedIndex, currentRadial = false, nil, nil
local currentID                     -- the radial id currentRadial belongs to
local openMode                      -- "hold" (the keybind), "click" (a macro) or "pad"; see section 8
local resolved = {}               -- currentRadial resolved to names / icons / attributes
local resolvedCache = {}          -- every radial resolved, as the secure layer holds them (SyncSecure)
local syncedIDs = {}              -- radial ids written to the secure layer, to retire deleted ones
local syncedTags = {}             -- macro tags written to the secure layer, to retire renamed ones
local openedAt = 0
local previewID, previewAnchor     -- set while the radial editor is open
local CloseRadial                   -- defined in section 8, used by the guard in section 7
local SyncSecure                  -- defined in section 9, run at the end of every layout
local layoutPending               -- a layout held back by combat; see LayoutRadial

--------------------------------------------------
-- 4. HELPERS
--------------------------------------------------
local function RadialRadius(count)
    return RADIUS_MIN + math_max(0, count - RADIUS_FLAT_BUTTONS) * RADIUS_PER_BUTTON
end

-- Resolved once, in the client, and remembered. false means none of the styles are available and
-- the drawn rim takes over.
local roundStyle
local function RoundStyle()
    if roundStyle ~= nil then return roundStyle or nil end
    local exists = C_Texture and (C_Texture.GetAtlasExists
        or (C_Texture.GetAtlasInfo and function(name) return C_Texture.GetAtlasInfo(name) ~= nil end))
    if exists then
        for _, style in ipairs(ROUND_STYLES) do
            if exists(style.mask) and exists(style.idle) and exists(style.active) then
                roundStyle = style
                return style
            end
        end
    end
    roundStyle = false
    return nil
end

local function CursorPosition()
    local scale = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    return x / scale, y / scale
end

--------------------------------------------------
-- 5. ACTIONS
-- A button is stored as a small description - { kind = "spell", id = 133 } - and resolved to a name,
-- an icon and a set of secure attributes when the radial is laid out. Every kind maps onto one of
-- Blizzard's own SECURE_ACTIONS handlers (SecureTemplates.lua), so nothing here reimplements
-- casting, marking or panel opening; it only decides which attributes to write.
-- Resolvers return: name, icon, attributes. Icon is { atlas = } or { texture = }.
--------------------------------------------------
local ACTIONS = {}
local ResolveEntry                -- defined below; ACTIONS.subradial recurses through it

-- Most panels click the real Blizzard micro button, so each one keeps its own behaviour rather than
-- having its toggle reimplemented here. Bags has no micro button and runs the toggle instead.
-- Both go through a macro on the secure button, so the panel opens from Blizzard's own untainted
-- code. That matters: a panel opened from our tainted call leaves taint on every frame it touches,
-- and the client then refuses to compare the secret numbers it finds there (TextStatusBar.lua:110
-- reading player health as the Character panel opens).
-- Icons and names match the macro set these replaced, so a radial built from those macros looks the
-- same after being rebuilt from panels. Forever keeps Spellbook, Talents and Legacy as separate
-- micro buttons where retail merged or dropped them.
local MICRO_PANELS = {
    bags        = { order = 1,  label = "Bags",         icon = 133633,  macrotext = "/run ToggleAllBags()" },
    character   = { order = 2,  label = "Character",    icon = 136047,  button = "CharacterMicroButton" },
    collections = { order = 3,  label = "Collections",  icon = 132261,  button = "CollectionsMicroButton" },
    groupfinder = { order = 4,  label = "Group Finder", icon = 132161,  button = "LFDMicroButton" },
    guild       = { order = 5,  label = "Guild & Communities",          button = "GuildMicroButton" },
    legacy      = { order = 6,  label = "Legacy",       icon = 4279397, button = "LegacyMicroButton" },
    professions = { order = 7,  label = "Professions",  icon = 4202228, button = "ProfessionMicroButton" },
    quests      = { order = 8,  label = "Quest Log",    icon = 8197102, button = "QuestLogMicroButton" },
    spellbook   = { order = 9,  label = "Spellbook",    icon = 133741,  button = "SpellbookMicroButton" },
    talents     = { order = 10, label = "Talents",      icon = 132222,  button = "TalentMicroButton" },
    -- FlareUI's own settings: with a controller, R3's way to them (Options/ControllerNav.lua)
    flareui     = { order = 11, label = "FlareUI Settings", icon = "Interface\\AddOns\\FlareUI\\Media\\Art\\Icon.png",
                    macrotext = "/run FlareUI_ToggleSettings()" },
    -- flips the damage meter between Blizzard's view and FlareUI's threat view (Modules/DamageMeter.lua)
    threat      = { order = 12, label = "Toggle Threat Meter", icon = "Interface\\Icons\\Ability_Physical_Taunt",
                    macrotext = "/run FlareUI_ToggleThreatMeter()" },
}
RM.MICRO_PANELS = MICRO_PANELS

-- Guild & Communities: the guild tabard, rather than the muted micro menu art or a faction crest.
-- A texture path, not an atlas, because this icon predates atlases and is in every client.
local GUILD_ICON = "Interface\\Icons\\INV_Shirt_GuildTabard_01"

-- A button that has just had its type changed has no id yet, and the lookup APIs raise a usage error
-- rather than returning nil when handed one. Every id-based resolver bails out first; the button
-- then counts as unavailable and is left out of the radial until it is filled in.
ACTIONS.spell = function(entry)
    if not entry.id then return nil end
    local info = C_Spell.GetSpellInfo(entry.id)
    if not info then return nil end
    return info.name, { texture = info.iconID }, { type = "spell", spell = entry.id }
end

-- Mounts are spells; the journal is only used to look the spell and icon up by mount ID.
ACTIONS.mount = function(entry)
    if not (entry.id and C_MountJournal) then return nil end
    local name, spellID, icon = C_MountJournal.GetMountInfoByID(entry.id)
    if not (name and spellID) then return nil end
    return name, { texture = icon }, { type = "spell", spell = spellID }
end

-- Blizzard's "item" action runs the attribute through SecureCmdItemParse, which reads it as an item
-- NAME or a "bag slot" pair - an item ID is parsed as a slot number and blows up downstream. So the
-- ID is only what we store; the name is what the button is given. A name the client has not cached
-- yet makes the button unavailable for the moment, and the request below fixes that for next time.
ACTIONS.item = function(entry)
    if not entry.id then return nil end
    local name = C_Item.GetItemNameByID(entry.id)
    if not name then
        C_Item.RequestLoadItemDataByID(entry.id)
        return nil
    end
    local icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(entry.id)
    return name, { texture = icon }, { type = "item", item = name }
end

ACTIONS.macro = function(entry)
    return entry.name or "Macro", { texture = entry.icon or 134400 },
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

    if panel.macrotext then
        return panel.label, icon, { type = "macro", macrotext = panel.macrotext }
    end
    if not _G[panel.button] then return nil end
    -- /click rather than a clickbutton attribute: the secure layer copies each action as plain values
    -- (section 9), and a frame cannot travel that way. /click also puts Blizzard's own guards in front
    -- of the click (SlashCommands.lua:738), so a frame the client has fenced off is left alone.
    return panel.label, icon, { type = "macro", macrotext = "/click " .. panel.button }
end

-- A button that stands for another radial. The sub-radial is never drawn: the button shows one of the
-- nested actions at a time and the mouse wheel steps through them. The children are resolved here, so an unavailable one is skipped exactly as it would
-- be in its own radial, and a radial whose children all fail is itself unavailable.
-- seen holds the radials on the current path, so a radial cannot contain itself however long the chain.
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

    -- the button wears the first child until the wheel moves it; see SetButtonChild
    local first = children[1]
    return first.name, first.icon, first.attributes,
        { children = children, childIndex = 1, radialName = data.name, radialID = id }
end

-- Resolution can fail: a mount that is not collected, an item the character does not have, a panel
-- whose addon has not loaded. An unavailable button is dropped from the radial entirely and the rest
-- close up around it, rather than leaving a gap. Because availability changes, the radial is
-- resolved afresh every time it opens.
local UNKNOWN_ICON = 134400

function ResolveEntry(entry, depth, seen)
    local resolver = entry and ACTIONS[entry.kind]
    if not resolver then return nil end
    local name, icon, attributes, extra = resolver(entry, depth or 0, seen or {})
    if not attributes then return nil end
    local info = { name = name, icon = icon or { texture = UNKNOWN_ICON }, attributes = attributes, entry = entry }
    -- a sub-radial hands back its children here
    if extra then
        for key, value in pairs(extra) do info[key] = value end
    end
    return info
end

-- The radial a new account starts with: the eight raid target markers.
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

    -- The fallback rim when the client has no rim art: a flat colour disc under the icon, clipped
    -- to a circle. Only one of this and RimArt is ever shown.
    button.Rim = button:CreateTexture(nil, "BACKGROUND")
    button.Rim:SetColorTexture(1, 1, 1)
    button.Rim:SetPoint("CENTER")
    button.Rim:SetSize(ROUND_SIZE, ROUND_SIZE)
    button.Rim:Hide()

    button.RimMask = button:CreateMaskTexture()
    button.RimMask:SetAtlas(ATLAS_CIRCLE_MASK)
    button.RimMask:SetAllPoints(button.Rim)
    button.Rim:AddMaskTexture(button.RimMask)

    -- anchored by ApplyButtonShape, which differs between the two shapes
    button.Icon = button:CreateTexture(nil, "ARTWORK")

    button.Mask = button:CreateMaskTexture()
    button.Mask:SetAtlas(style and style.mask or ATLAS_CIRCLE_MASK)
    button.Mask:SetAllPoints(button.Icon)

    -- An additive white wash over the icon, so the selected button lifts its own art rather than
    -- only its border. It tracks the icon, so one mask serves both.
    button.Glow = button:CreateTexture(nil, "OVERLAY")
    button.Glow:SetColorTexture(1, 1, 1)
    button.Glow:SetBlendMode("ADD")
    button.Glow:SetAllPoints(button.Icon)
    button.Glow:SetAlpha(0)

    -- above the wash, so the rim reads as a frame around the lit icon rather than under it
    button.RimArt = button:CreateTexture(nil, "OVERLAY", nil, 1)
    button.RimArt:SetPoint("CENTER")
    button.RimArt:SetSize(ROUND_SIZE, ROUND_SIZE)
    button.RimArt:Hide()

    -- the cooldown swipe over the icon; see ApplyButtonState
    button.Cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.Cooldown:SetAllPoints(button.Icon)
    button.Cooldown:SetSwipeTexture(SWIPE_TEXTURE)
    button.Cooldown:SetDrawEdge(false)
    button.Cooldown:SetDrawBling(false)

    button.index = index
    return button
end

local function ApplyButtonShape(button)
    local style = RoundStyle()
    button.Icon:ClearAllPoints()
    button.Icon:SetPoint("CENTER")
    local size = style and (ROUND_SIZE * style.iconFactor) or ROUND_ICON
    button.Icon:SetSize(size, size)
    if not button.masked then
        button.Icon:AddMaskTexture(button.Mask)
        button.Glow:AddMaskTexture(button.Mask)
        button.masked = true
    end
    -- whichever of the two is in use; see ROUND_STYLES
    button.RimArt:SetShown(style ~= nil)
    button.Rim:SetShown(style == nil)
end

-- Square icon files get the usual border crop; atlases carry their own coordinates and must not be
-- cropped, so SetAtlas is applied on its own.
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
    button.Glow:SetAlpha(selected and ICON_GLOW_ALPHA or 0)
    if button.RimArt:IsShown() then
        -- A style with two atlases changes art and needs no tint beyond its own cast; a style with
        -- only one has to say "selected" in colour, so it borrows the pointer's yellow.
        local style = RoundStyle()
        button.RimArt:SetAtlas(selected and style.active or style.idle)
        local t = RIM_TINT_NONE
        if selected then
            if style.tint then t = BORDER_COLOR_ACTIVE end
        else
            t = style.idleTint or RIM_TINT_NONE
        end
        button.RimArt:SetVertexColor(t[1], t[2], t[3])
    else
        local c = selected and BORDER_COLOR_ACTIVE or BORDER_COLOR
        button.Rim:SetVertexColor(c[1], c[2], c[3])
    end
end

-- Cooldown swipe and usable tint for what a button fires now (a sub-radial's current child). Spells
-- and mounts go through the spell API; the cooldown is handed over as Blizzard's duration object,
-- which carries the timing even when cooldowns are secret, and the global cooldown is left out so a
-- recent cast does not sweep every button. Items read their own cooldown. Markers, panels and
-- macros have neither and stay as they are. Anything unreadable leaves the button looking usable.
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

-- While the radial is up, cooldowns starting or ending and power changing re-run the states
local stateEvents = CreateFrame("Frame")
stateEvents:SetScript("OnEvent", RefreshButtonStates)
local STATE_EVENTS = { "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_USABLE", "BAG_UPDATE_COOLDOWN", "ACTIONBAR_UPDATE_USABLE" }

local function WatchButtonStates(watch)
    for _, event in ipairs(STATE_EVENTS) do
        if watch then stateEvents:RegisterEvent(event) else stateEvents:UnregisterEvent(event) end
    end
end

-- Puts a sub-radial button on one of its children. Called back from the secure wheel handler, which
-- owns the choice (section 9): the art only follows it, so what is shown is what the release fires.
-- The radial itself is not rebuilt, so the sweep is never interrupted.
local function SetButtonChild(index, childIndex)
    local info, button = resolved[index], buttons[index]
    if not (info and button and info.children) then return end
    local child = info.children[childIndex]
    if not child then return end
    info.childIndex = childIndex
    info.name, info.icon, info.attributes = child.name, child.icon, child.attributes
    SetButtonIcon(button, child.icon)
    ApplyButtonState(button, info)
end

-- Unavailable buttons are skipped, so the radial closes up around them.
local function ResolveButtons(list)
    local out = {}
    for i = 1, #(list or {}) do
        if #out >= MAX_BUTTONS then break end
        local entry = ResolveEntry(list[i], 0, {})
        if entry then out[#out + 1] = entry end
    end
    return out
end

-- Every radial in the library, since a macro may open any of them in combat
local function ResolveAll()
    wipe(resolvedCache)
    for _, id in ipairs(RM:GetRadialOrder()) do
        local data = RM:GetRadial(id)
        if data then resolvedCache[id] = ResolveButtons(data.buttons) end
    end
end

function RM:LayoutRadial()
    if not (radial and currentRadial) then return end
    -- The secure layer holds a copy of every radial's layout (SyncSecure), and that copy cannot be
    -- rewritten in combat. Resolving afresh there would let the art drift from what a click actually
    -- fires, so in combat the art draws the copy made out of combat, and a new one is made on the way
    -- out. Resolving happens here rather than per frame; LayoutRadial runs whenever a radial opens or
    -- is edited.
    if InCombatLockdown() then
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
                -- button 1 at the top, the rest clockwise from it
                local angle = QUARTER - (i - 1) * interval
                button:ClearAllPoints()
                button:SetPoint("CENTER", radial, "CENTER", math_cos(angle) * radius, math_sin(angle) * radius)
                ApplyButtonShape(button)
                SetButtonIcon(button, entry.icon)
                SetButtonSelected(button, false)
                button:Show()
            else
                button:Hide()
            end
        end
    end
    RefreshButtonStates()
    SyncSecure()
end

local function CreateRadial()
    if radial then return end
    radial = CreateFrame("Frame", "FlareUI_Radial", UIParent)
    radial:SetFrameStrata("DIALOG")
    radial:EnableMouse(false)          -- the cursor is polled, never captured
    -- the mouse wheel is taken by the secure layer's wheel frame, not here; see section 9
    radial:Hide()

    -- The cancel X sits in the middle, with its own highlight circle behind it. Blizzard layers these
    -- the same way: the pointer above everything, and it hides whenever the X is the selection.
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
end

local function SetCancelSelected(selected)
    radial.CancelSelect:SetShown(selected)
    radial.CancelIcon:SetAlpha(selected and 1 or CANCEL_ALPHA_IDLE)
end

--------------------------------------------------
-- 7. SELECTION
-- The cursor angle picks the button - or, in controller mode, the stick's. Button one sits at the
-- top and the rest run clockwise, so the offset from the top is measured backwards, and half an
-- interval is added so that each button owns the wedge centred on it rather than the one starting
-- at it.
--------------------------------------------------
-- the aiming stick, from the same table the secure snippet reads through GetGamePadState
local function PadStick()
    local state = C_GamePad.GetDeviceMappedState()
    return state and state.sticks and state.sticks[padStickIndex]
end

local function UpdateSelection()
    if not (isOpen and currentRadial) then return end

    -- Safety net for the one thing that cannot be checked outside the game: whether a CLICK binding
    -- really delivers the key-up as well as the key-down. If it does not, the radial would hang open
    -- with no way to dismiss it, so it closes itself instead of trapping the screen.
    if openMode == "hold" and GetTime() - openedAt > STUCK_OPEN_SECONDS then
        CloseRadial()
        print("|cffff9900FlareUI:|r radial menu timed out - the binding did not report a key release.")
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
        radial.Pointer:SetRotation(angle + POINTER_ROTATION_OFFSET)
        radial.Pointer:Show()

        local interval = TAU / count
        index = math_floor(((QUARTER - angle) % TAU + interval / 2) / interval) % count + 1
        SetCancelSelected(false)
    else
        -- inside the dead zone: the X is the selection, and releasing here cancels
        radial.Pointer:Hide()
        SetCancelSelected(true)
    end

    if index ~= selectedIndex then
        if selectedIndex and buttons[selectedIndex] then SetButtonSelected(buttons[selectedIndex], false) end
        if index and buttons[index] then SetButtonSelected(buttons[index], true) end
        selectedIndex = index
    end
end

--------------------------------------------------
-- 8. OPEN / CLOSE
--------------------------------------------------
-- While a controller radial is up the right stick aims instead of turning the camera: a frame taking
-- stick input is shown, and its OnGamePadStick returns false - handled, as Blizzard's own
-- inputBindingAxisListener does (InputAxisBinding.lua) - for the right stick and the camera it
-- drives, true for the rest, so the left stick still walks. (Setting the gamepad turn-speed CVars
-- to 0 does not stop the camera on Forever.) A plain frame's Show is not protected: fine in combat.
local BLOCKED_STICKS = { Right = true, Camera = true }
local stickBlocker
local function SetPadFreeze(on)
    if on then
        if not stickBlocker then
            stickBlocker = CreateFrame("Frame", nil, UIParent)
            stickBlocker:EnableGamePadStick(true)
            stickBlocker:SetScript("OnGamePadStick", function(_, stick)
                return not BLOCKED_STICKS[stick]
            end)
        end
        stickBlocker:Show()
    elseif stickBlocker then
        stickBlocker:Hide()
    end
end

-- mode "hold" is the keybind (the assigned radial, or the one the editor previews); "click" is a
-- macro, which names its radial; "pad" is the controller's stick press. A radial already up gives
-- way to the new one.
local function OpenRadial(radialID, mode)
    if isOpen then CloseRadial() end
    openMode = mode or "hold"
    -- Laid out on every open so that availability (mounts, items, loaded panels) is current. In
    -- combat LayoutRadial draws the copy the secure layer holds.
    if radialID then
        RM:LoadRadial(radialID)
    elseif previewID then
        RM:LoadRadial(previewID)
    else
        RM:LoadActiveRadial()
    end
    RM:LayoutRadial()
    if #resolved == 0 then return end
    RefreshButtonStates()   -- in combat LayoutRadial kept the old layout, but the states are current
    WatchButtonStates(true)
    radial:SetScale(1)

    -- a controller radial opens mid-screen: there is no cursor to open it at
    local x, y
    if openMode == "pad" then x, y = UIParent:GetCenter() else x, y = CursorPosition() end
    radial:ClearAllPoints()
    radial:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    radial.Pointer:Hide()
    SetCancelSelected(true)   -- the cursor starts dead centre

    selectedIndex = nil
    isOpen = true
    openedAt = GetTime()
    if openMode == "pad" then SetPadFreeze(true) end
    radial:Show()
    radial:SetScript("OnUpdate", UpdateSelection)
    UpdateSelection()
end

function CloseRadial()
    if not isOpen then return end
    SetPadFreeze(false)
    isOpen = false
    openMode = nil
    radial:SetScript("OnUpdate", nil)
    WatchButtonStates(false)
    -- The secure release hides the wheel frame itself. This covers the radial closing any other way,
    -- such as the stuck-open guard; in combat that has to wait for PLAYER_REGEN_ENABLED.
    if wheel and not InCombatLockdown() then wheel:Hide() end
    if selectedIndex and buttons[selectedIndex] then SetButtonSelected(buttons[selectedIndex], false) end
    selectedIndex = nil
    -- the editor gets its preview back rather than an empty box
    if previewID then RM:ShowPreview(previewID, previewAnchor) else radial:Hide() end
end

--------------------------------------------------
-- 9. THE SECURE LAYER
-- One SecureActionButton, the caster, carries every action and the binding clicks it: down on the press, up on
-- the release. useOnKeyDown = false makes Blizzard act on the release (SecureActionButton_OnClick in
-- SecureTemplates.lua), which is what gives the hold-sweep-release feel.
-- The radial button is chosen by a snippet wrapped round the caster's OnClick. It runs as secure
-- code, so it can write the caster's attributes in combat, where plain Lua cannot. It finds the radial
-- button from the cursor with the same maths as UpdateSelection, so the highlighted button is the one
-- that fires.
-- Snippets can only read plain values, so SyncSecure copies the layout onto the header out of
-- combat: the button count, and for each button every child's attributes as "s<button>-<child>-<key>".
-- A plain button is a sub-radial of one child, which keeps the snippets free of special cases.
-- The mouse wheel is caught by a full-screen secure frame, shown only while the radial is open. It
-- steps a sub-radial button's child in secure state and tells the art through CallMethod, for the same
-- reason: the choice has to live where the release can read it in combat.
-- Every radial is copied, each under its own id ("<id>-count", "<id>-s<button>-<child>-<key>"), and
-- ACTIVE names the one that is open: the keybind opens "flare-assigned", a macro names its own.
-- Radial macros (click mode, OPie's model): the macro clicks MACRO_NAME with the radial's tag as
-- the mouse button: its name without spaces or symbols, any case ("tag-<lower case>" holds the id;
-- a bare id works too). A /click sends no key release, so the radial waits for a click on CATCHER_NAME, a
-- full-screen SecureActionButton shown only meanwhile: left-click fires the aimed button, right-click
-- or Escape (a binding the header holds while open) closes. The same macro pressed again fires the
-- aimed button from MACRO_NAME itself, so tap - aim - tap works without the mouse buttons.
-- Controller support (MODE "pad"): R3 clicks PAD_NAME on its release. The first press opens the
-- radial this character's keybind opens; the next fires the button the right stick aims at, read
-- from GetGamePadState() right here in the restricted environment - so it works in combat - from
-- the stick "flare-padstick" names. B and Escape are bound to PAD_NAME's RightButton meanwhile,
-- which closes.
--------------------------------------------------
local ACTION_KEYS = "type spell item macro macrotext unit marker action"

-- self is the header. Returns the button under the cursor, or nil in the dead zone. OPENX / OPENY are
-- where the radial opened, recorded by the click snippet in the same restricted environment.
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

-- self is the header. The attribute prefix of the button the cursor aims at in the open radial.
local AIMED_SNIPPET = [[
    local index = self:RunAttribute("flare-select")
    if not (index and ACTIVE) then return nil end
    local child = (CHILD[ACTIVE] and CHILD[ACTIVE][index]) or 1
    return ACTIVE .. "-s" .. index .. "-" .. child .. "-"
]]

-- self is the header; ... = quiet. Ends click mode: catcher, wheel frame and Escape binding go. The
-- art is told unless quiet (the keybind opening over a macro radial redraws the art itself).
local CLOSE_CLICK_SNIPPET = [[
    if MODE ~= "click" then return end
    MODE = nil
    OPENX, OPENY = nil, nil
    self:GetFrameRef("catcher"):Hide()
    self:GetFrameRef("wheel"):Hide()
    self:ClearBindings()
    if not ... then self:CallMethod("OnSecureClose") end
]]

-- self is the header; ... = the radial id. Opens that radial in click mode at the cursor.
local OPEN_CLICK_SNIPPET = [[
    local id = ...
    if (self:GetAttribute(id .. "-count") or 0) == 0 then return false end
    local screen = self:GetFrameRef("wheel")
    ACTIVE, MODE = id, "click"
    screen:Show()
    local x, y = screen:GetMousePosition()
    if x then
        OPENX, OPENY = x * screen:GetWidth(), y * screen:GetHeight()
    else
        OPENX, OPENY = nil, nil
    end
    self:GetFrameRef("catcher"):Show()
    self:SetBindingClick(true, "ESCAPE", "]] .. CATCHER_NAME .. [[", "RightButton")
    self:CallMethod("OnSecureOpen", id)
    return true
]]

-- self is the header; ... = quiet. Ends controller mode (its B / Escape bindings go with the rest).
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
    self:CallMethod("OnSecurePadOpen", id)
]]

-- self is the pad button, control the header. LeftButton is the stick press: open, or fire what the
-- stick aims at. RightButton (B, Escape) closes.
local PAD_SNIPPET = [[
    if button ~= "LeftButton" then
        control:RunAttribute("flare-closepad")
        return false
    end
    if MODE == "pad" then
        local prefix = control:RunAttribute("flare-aimed")
        control:RunAttribute("flare-closepad")
        if not prefix then return false end
        for key in gmatch(control:GetAttribute("flare-keys"), "%S+") do
            self:SetAttribute(key, control:GetAttribute(prefix .. key))
        end
        return nil, "fired"
    end
    local id = control:GetAttribute("flare-assigned")
    if not id or (control:GetAttribute(id .. "-count") or 0) == 0 then return false end
    control:RunAttribute("flare-closeclick", true)
    control:RunAttribute("flare-openpad", id)
    return false
]]

-- self is the caster, control the header. Returning false cancels the button's own click, which is
-- what stops a press on its own, or a release in the dead zone, from casting anything.
local CLICK_SNIPPET = [[
    local screen = control:GetFrameRef("wheel")
    if down then
        control:RunAttribute("flare-closeclick", true)
        control:RunAttribute("flare-closepad", true)
        for key in gmatch(control:GetAttribute("flare-keys"), "%S+") do self:SetAttribute(key, nil) end
        -- an extra keybind clicks with its radial's id as the button; the main one with LeftButton
        local id = button
        if (control:GetAttribute(id .. "-count") or 0) < 1 then id = control:GetAttribute("flare-assigned") end
        ACTIVE, MODE = id, "hold"
        screen:Show()
        local x, y = screen:GetMousePosition()
        if x then
            OPENX, OPENY = x * screen:GetWidth(), y * screen:GetHeight()
        else
            OPENX, OPENY = nil, nil
        end
        return false
    end
    local prefix = MODE == "hold" and control:RunAttribute("flare-aimed") or nil
    screen:Hide()
    MODE = nil
    OPENX, OPENY = nil, nil
    if not prefix then return false end
    for key in gmatch(control:GetAttribute("flare-keys"), "%S+") do
        self:SetAttribute(key, control:GetAttribute(prefix .. key))
    end
    return nil, "fired"
]]

-- self is the catcher, control the header: left-click fires the aimed button, right-click closes
local CATCHER_SNIPPET = [[
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

-- self is the macro button, button the radial id the macro named (or a mouse button when it named
-- none: the radial this character's keybind opens). The same radial again fires the aimed button.
local MACRO_SNIPPET = [[
    local id = control:GetAttribute("tag-" .. strlower(button)) or button
    if (control:GetAttribute(id .. "-count") or -1) < 0 then
        if id == "LeftButton" or id == "RightButton" then
            id = control:GetAttribute("flare-assigned")
        else
            print("|cffff9900FlareUI:|r no radial called \"" .. tostring(id) .. "\". Copy its macro from the Radial Menu settings.")
            return false
        end
        if not id then return false end
    end
    if MODE == "click" and ACTIVE == id then
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

-- After the action has run: the button is left empty between uses.
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

-- A radial's macro tag: its name with the spaces and symbols taken out ("Summon Minions" ->
-- "SummonMinions"), since a /click passes one word. Matched in any case. When two radials come out
-- the same, the first in the library keeps the tag and the other is opened by its id.
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

-- Copies every radial's layout onto the header, and which radial the keybind opens. Out of combat
-- only, which is enough: in combat LayoutRadial does not change the layouts either. Every key is
-- written for every child, nil included, so a slot that changed kind cannot keep a key from what it
-- used to be. A deleted radial is left with a count of 0, so a macro naming it opens nothing.
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
    header:SetAttribute("flare-assigned", previewID or RM:GetAssignedRadialID())
    -- sub-radial buttons start on their first child again, as the art does after a layout
    SecureHandlerExecute(header, "CHILD = newtable()")
end

local function OnPreClick(_, button, down)
    if down then OpenRadial(RM:GetRadial(button) and button or nil, "hold") end
end

-- Only a radial the keybind opened: a button whose macro opens another radial (click mode) has
-- already replaced it by the time this runs, and that one stays up for its click.
local function OnPostClick(_, _, down)
    if not down and openMode == "hold" then CloseRadial() end
end

-- Frames, snippets and wraps all have to be set up out of combat; Init defers this if it is not.
local function CreateSecureLayer()
    if caster then return end
    caster = CreateFrame("Button", CASTER_NAME, UIParent, "SecureActionButtonTemplate")
    -- parked off screen: a binding click never needs the button to be visible or moused over
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
    header.OnSecureChild = function(_, index, child) SetButtonChild(index, child) end
    header.OnSecureOpen = function(_, radialID) OpenRadial(radialID, "click") end
    header.OnSecurePadOpen = function(_, radialID) OpenRadial(radialID, "pad") end
    header.OnSecureClose = function() if openMode == "click" or openMode == "pad" then CloseRadial() end end
    header:SetAttribute("flare-openpad", OPEN_PAD_SNIPPET)
    header:SetAttribute("flare-closepad", CLOSE_PAD_SNIPPET)

    -- Full screen so the wheel works wherever the cursor has swept to, and so it doubles as the
    -- coordinate frame for SELECT_SNIPPET: GetMousePosition answers nil outside the frame it is
    -- asked about. It takes the wheel only, never clicks.
    wheel = CreateFrame("Frame", WHEEL_NAME, UIParent, "SecureFrameTemplate")
    wheel:SetAllPoints(UIParent)
    wheel:SetFrameStrata("FULLSCREEN_DIALOG")
    wheel:EnableMouse(false)
    wheel:EnableMouseWheel(true)
    wheel:Hide()
    SecureHandlerSetFrameRef(header, "wheel", wheel)

    -- Click mode's catcher: above the wheel frame, so it takes the wheel too while it is up
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

    -- what macros click; never shown, a /click needs no visible button
    macroButton = CreateFrame("Button", MACRO_NAME, UIParent, "SecureActionButtonTemplate")
    macroButton:RegisterForClicks("AnyUp", "AnyDown")
    macroButton:SetAttribute("useOnKeyDown", false)
    macroButton:SetAttribute("pressAndHoldAction", false)

    SecureHandlerWrapScript(caster, "OnClick", header, CLICK_SNIPPET, CLEAR_SNIPPET)
    SecureHandlerWrapScript(wheel, "OnMouseWheel", header, WHEEL_SNIPPET)
    SecureHandlerWrapScript(catcher, "OnClick", header, CATCHER_SNIPPET, CLEAR_SNIPPET)
    SecureHandlerWrapScript(catcher, "OnMouseWheel", header, WHEEL_SNIPPET)
    SecureHandlerWrapScript(macroButton, "OnClick", header, MACRO_SNIPPET, CLEAR_SNIPPET)

    -- controller mode: the stick press clicks this on its release (see PAD_SNIPPET)
    padButton = CreateFrame("Button", PAD_NAME, UIParent, "SecureActionButtonTemplate")
    padButton:RegisterForClicks("AnyUp")
    padButton:SetAttribute("useOnKeyDown", false)
    padButton:SetAttribute("pressAndHoldAction", false)
    SecureHandlerWrapScript(padButton, "OnClick", header, PAD_SNIPPET, CLEAR_SNIPPET)
    SecureHandlerExecute(header, "CHILD = newtable()")
end

--------------------------------------------------
-- 10. LIVE PREVIEW
-- Used by the radial editor. The radial is ordinary art, so previewing it is just a matter of pointing
-- it at a different radial, parking it in the editor's box and scaling it down if the radial is wider
-- than the box.
--------------------------------------------------
local PREVIEW_BOX = 270

function RM:ShowPreview(radialID, anchor)
    if not radial then return end
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
    radial:Show()
end

function RM:HidePreview()
    previewID, previewAnchor = nil, nil
    if radial then
        radial:SetScale(1)
        if not isOpen then radial:Hide() end
    end
    self:LoadActiveRadial()
    self:LayoutRadial()
end

function RM:RefreshPreview()
    if previewID then self:ShowPreview(previewID, previewAnchor) end
end

--------------------------------------------------
-- 11. RADIAL LIBRARY
-- Radials live in db.global, deliberately away from the shared profile: a profile change is meant to
-- reach every character, while a radial is meant to belong to one. Radials are keyed by a stable id so
-- that renaming one does not orphan the characters using it, with a separate order list for display.
-- Which radial a character opens is kept by that character (GetAssignedRadialID):
-- nothing here lists characters, so there is no roster to go stale when one is deleted.
--------------------------------------------------
local function GetStore()
    if not (ns.db and ns.db.global) then return nil end
    local store = ns.db.global.radialmenu or {}
    ns.db.global.radialmenu = store
    -- Saves from before the rename (rings of slices, nested rings) move to the new keys once
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
    store.roster = nil   -- leftover from an earlier per-character settings table
    return store
end
RM.GetStore = function() return GetStore() end

function RM:GetRadialOrder()
    local store = GetStore()
    return store and store.radialOrder or {}
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
    -- a character that chose it falls back to the first radial; see GetAssignedRadialID
    self:LoadActiveRadial()
    self:LayoutRadial()
    self:ApplyBindings()
end

-- The radial this character opens, kept with the character's own state (ns.CharDB) rather than in a
-- table of characters. nil means it never chose and gets the first radial in the library, so a new
-- character's key works straight away; "" means it chose none.
function RM:GetAssignedRadialID()
    local charDB = ns.CharDB()
    if charDB.ring ~= nil then   -- saved before the rename
        if charDB.radial == nil then charDB.radial = charDB.ring end
        charDB.ring = nil
    end
    local choice = charDB.radial
    if choice == "" then return nil end
    if choice and self:GetRadial(choice) then return choice end
    return self:GetRadialOrder()[1]
end

function RM:SetAssignedRadialID(radialID)
    ns.CharDB().radial = radialID or ""
    self:LoadActiveRadial()
    self:LayoutRadial()
end

-- currentRadial points straight at the saved button list, so edits show up without copying
function RM:LoadRadial(radialID)
    local data = self:GetRadial(radialID)
    currentID = data and radialID or nil
    currentRadial = data and data.buttons or {}
end

-- The line a macro needs to open this radial (Radial Menu settings, "Radial Macros"): its tag, or
-- its id when another radial already has the tag (see MacroTags)
function RM:GetMacroText(radialID)
    if not radialID then return "" end
    local _, tagOf = MacroTags()
    return "/click " .. MACRO_NAME .. " " .. (tagOf[radialID] or radialID)
end

function RM:LoadActiveRadial()
    self:LoadRadial(self:GetAssignedRadialID())
end

-- Older saves keep every character's choice in one account table keyed by name, which build 70009
-- broke (UnitName became the first name only). This character's entries move into its own state;
-- other characters' entries wait for them to log in, and a deleted character's is never claimed.
local function MigrateLegacyAssignment()
    local store = GetStore()
    if not (store and store.assign and ns.PlayerGUID()) then return end
    local charDB = ns.CharDB()
    for key, radialID in pairs(store.assign) do
        if ns.IsLegacyKeyMine(key) then
            if charDB.radial == nil then charDB.radial = radialID end
            store.assign[key] = nil
        end
    end
    if not next(store.assign) then store.assign = nil end
end

--------------------------------------------------
-- 12. BINDING
-- The key is captured in FlareUI's own settings rather than Blizzard's Key Bindings panel, so
-- everything about the radial lives in one place. It is stored account-wide: one key on every
-- character, each opening that character's own radial.
-- SetOverrideBindingClick is protected, so a change made during combat is applied on the way out.
--------------------------------------------------
-- Extra keybinds belong to the character, like its radial choice: { key = "F", radial = "r2" } each.
local function ExtraBindings()
    local charDB = ns.CharDB()
    charDB.radialKeys = charDB.radialKeys or {}
    return charDB.radialKeys
end

-- C_GamePad numbers sticks from 0 (StickIndexToConfigName), the mapped state lists them from 1. Seen
-- on 70170: 0 Left, 1 Right, 2 Gyro, 3 Pad, 4 Movement, 5 Camera, 6 Look, 7 Cursor.
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
    -- each extra key clicks the caster with its radial's id as the mouse button (see CLICK_SNIPPET)
    for _, extra in ipairs(ExtraBindings()) do
        if extra.key and extra.key ~= "" and extra.radial and RM:GetRadial(extra.radial) then
            SetOverrideBindingClick(radial, true, extra.key, CASTER_NAME, extra.radial)
        end
    end
    -- Controller support, Gamepad UI only (switching it reloads the UI): R3 opens the radial and
    -- fires the aimed button. Ping, R3's own, moves to L3 in place of Auto Run.
    if ns.IsGamepadUI() and store and store.controller and padButton then
        padStickIndex = RightStickIndex()
        header:SetAttribute("flare-padstick", padStickIndex)
        SetOverrideBindingClick(radial, true, "PADRSTICK", PAD_NAME, "LeftButton")
        SetOverrideBinding(radial, true, "PADLSTICK", "TOGGLEPINGSYSTEM")
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
    store.padMode = nil   -- the setting before it became one toggle
    ApplyBinding()
end

function RM:ApplyBindings()
    ApplyBinding()
end

-- One key opens one radial: whichever row takes a key, any other row holding it lets go (the
-- account-wide main keybind included). index 0 is the main keybind.
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

-- A new row starts on the character's own radial, with no key yet
function RM:AddExtraBinding()
    local list = ExtraBindings()
    if #list >= MAX_EXTRA_KEYS then return end
    list[#list + 1] = { radial = self:GetAssignedRadialID() or self:GetRadialOrder()[1] }
end

function RM:SetExtraKey(index, key)
    local extra = ExtraBindings()[index]
    if not extra then return end
    key = (key ~= "" and key) or nil
    ReleaseKey(key, index)
    extra.key = key
    ApplyBinding()
end

function RM:SetExtraRadial(index, radialID)
    local extra = ExtraBindings()[index]
    if not extra then return end
    extra.radial = radialID
    ApplyBinding()
end

function RM:RemoveExtraBinding(index)
    table.remove(ExtraBindings(), index)
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
    if not isOpen then
        -- whatever the fight held back: a layout (see LayoutRadial), or a wheel frame left showing by
        -- a radial that closed some other way than a release
        if layoutPending then
            if previewID then self:RefreshPreview() else self:LayoutRadial() end
        end
        if wheel then wheel:Hide() end
        if catcher and catcher:IsShown() then SecureHandlerExecute(header, [[self:RunAttribute("flare-closeclick", true)]]) end
    end
end

--------------------------------------------------
-- 13. PUBLIC
--------------------------------------------------
function RM:Refresh()
    if not radial then return end
    self:LayoutRadial()
end

function RM:Init()
    if self.initialized then return end
    self.initialized = true


    CreateRadial()
    -- a /reload in combat: the secure frames and wraps wait for the fight to end
    if InCombatLockdown() then
        self.securePending = true
    else
        CreateSecureLayer()
    end
    MigrateLegacyAssignment()

    -- first run: give the account one radial to edit, so the editor is never looking at an empty
    -- library; as the first radial it is also what every character opens until it picks another
    local store = GetStore()
    if store and not next(store.radials) then
        local id = self:CreateRadial("Markers")
        self:GetRadial(id).buttons = MarkerButtons()
    end

    self:LoadActiveRadial()
    self:LayoutRadial()

    ApplyBinding()
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    -- an item button resolves only once its name is cached; redraw when a request comes back
    self:RegisterEvent("ITEM_DATA_LOAD_RESULT", function()
        if previewID then self:RefreshPreview() else self:LayoutRadial() end
    end)
end

-- called by the editor after any change to a radial's contents
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
