local ADDON_NAME, ns = ...
local L = ns.L

--------------------------------------------------
-- CORE
-- FlareUI's namespace and shared code: colours, combo point art, AceDB defaults, utilities,
-- secure frame hiding, window sounds, shared dialogs and module start-up.
--------------------------------------------------
FlareUI = ns
ns.modules = {}

--------------------------------------------------
-- 1. UPVALUES
--------------------------------------------------
local ReloadUI = ReloadUI
local AceDB = LibStub("AceDB-3.0")

--------------------------------------------------
-- 2. COLOURS
--------------------------------------------------
-- Bronze tint of every FlareUI frame border
ns.BORDER_COLOR = { r = 0.65, g = 0.49, b = 0.27, a = 1 }   -- #A67D45

-- FlareUI's palette (colour audit 11-19): one bronze hue in even lightness steps, two golds, a warm
-- grey, one warm ground and one blue. New colours come from here; the older constants move onto it
-- module by module. Not for Blizzard's font colours, bar colours or class colours (Blizzard's own).
ns.PALETTE = {
    bronze1 = { 0.32, 0.24, 0.13 },   -- #523D21 shadow: scroll bars, deep edges
    bronze2 = { 0.50, 0.38, 0.21 },   -- #806136 chrome: idle buttons and icons, dividers, the radial ring
    bronze3 = { 0.65, 0.49, 0.27 },   -- #A67D45 frame: every border (= ns.BORDER_COLOR)
    bronze4 = { 0.80, 0.60, 0.34 },   -- #CC9957 accent: active tab, window titles, hovered chrome
    bronze5 = { 0.85, 0.68, 0.47 },   -- #D9AD78 light: hovered accent text
    goldHighlight = { 1, 0.84, 0.50 },   -- #FFD680 hover rims, selected outlines
    goldOn = { 1, 0.82, 0.25 },          -- #FFD140 switched-on states (Blizzard's yellow eased to bronze)
    warmGrey = { 0.56, 0.51, 0.46 },     -- #8F8275 inactive tabs, disabled or lost things
    ground = { 0.05, 0.04, 0.03 },       -- #0D0A08 every background FlareUI draws itself
    infoBlue = { 0.25, 0.60, 1 },        -- #4099FF Edit Mode's selection blue: selection, controller targeting
}

-- A colour in FlareUI's softer tones (the FlareUI colour schemes of the quest tracker and minimap): its
-- own hue, 35% less saturated and a quarter of the way to a warm light bronze. Green stays green,
-- red stays red, only calmer next to the bronze.
ns.SOFT = { DESAT = 0.35, MIX = 0.25, WARM = { 0.85, 0.70, 0.50 } }
function ns.SoftColor(r, g, b)
    local S = ns.SOFT
    local avg = (r + g + b) / 3
    r, g, b = r + (avg - r) * S.DESAT, g + (avg - g) * S.DESAT, b + (avg - b) * S.DESAT
    local w, m = S.WARM, S.MIX
    return r * (1 - m) + w[1] * m, g * (1 - m) + w[2] * m, b * (1 - m) + w[3] * m
end

-- FlareUI's windows: bronze edge, warm dark top fading to near black
ns.WINDOW_STYLE = {
    border = { 0.80, 0.60, 0.34 },
    top    = { 0.085, 0.075, 0.060, 1 },
    bottom = { 0.015, 0.015, 0.015, 1 },
}

-- Blizzard's health green and mana blue, toned down; other powers keep Blizzard's colours
ns.HEALTH_GREEN = { 0.15, 0.82, 0.15 }
-- The dot between parts of a line ("Chest · Cloth"): the Russian client's fonts have no middle dot and
-- draw a box, so a dash there (11-21, Archy)
ns.DOT = (GetLocale and GetLocale() == "ruRU") and "-" or "\194\183"
ns.MANA_BLUE = { 0.18, 0.48, 1.00 }   -- bright, to stand out from the deep blue of shaman health bars

-- A power's bar colour (r, g, b), or nil when Blizzard has none for it
function ns.PowerColor(token, powerType)
    -- Colour Palette: Custom's own power colours (UnitFrames.lua UF.ApplyPalette)
    local own = ns.POWER_OVERRIDE and token and ns.POWER_OVERRIDE[token]
    if own then return own[1], own[2], own[3] end
    if token == "MANA" or (token == nil and powerType == 0) then
        return ns.MANA_BLUE[1], ns.MANA_BLUE[2], ns.MANA_BLUE[3]
    end
    local tbl = _G.PowerBarColor
    local c = tbl and ((token and tbl[token]) or (powerType and tbl[powerType]))
    if c and c.r then return c.r, c.g, c.b end
end

-- An enemy's level colour as Blizzard's target frame has it: the server's difficulty for the unit
-- (the level formula when that can't be read)
function ns.LevelDifficultyColor(unit, level)
    local api = C_PlayerInfo and C_PlayerInfo.GetContentDifficultyCreatureForPlayer
    if api and GetDifficultyColor and unit then
        local ok, difficulty = pcall(api, unit)
        if ok and canaccessvalue(difficulty) and difficulty ~= nil then
            local color = GetDifficultyColor(difficulty)
            if color then return color end
        end
    end
    return level and GetQuestDifficultyColor and GetQuestDifficultyColor(level) or nil
end

-- Aura Ordering (every frame with auras): Blizzard's aura containers sort each group themselves (safe
-- with secret values). sort: "default" (Blizzard's: yours first, then important, then applied order),
-- "applied", "time" (time left; permanent last) or "name"; mineFirst (time, name): your own lead.
ns.AuraOrder = {}
function ns.AuraOrder.Options(sort, reverse, mineFirst)
    local M, D = AuraContainerSortMethod, AuraContainerSortDirection
    if not (M and D) then return nil, nil end
    local method = M.Default
    if sort == "applied" then method = M.AuraInstanceIDOnly
    elseif sort == "time" then method = mineFirst == false and M.ExpirationOnly or M.Expiration
    elseif sort == "name" then method = mineFirst == false and M.NameOnly or M.Name end
    return method, reverse and D.Reverse or D.Normal
end

-- The Edit Mode "Aura Ordering" rows; get(key) / set(key) are the dialog's own accessors. They sit
-- in the Auras section (Sort By below Debuffs, Reverse Order and Your Auras First below Only My
-- Buffs / Debuffs: ns.OrderEditSettings)
function ns.AuraOrder.With(items, get, set, defaultSort)
    for _, item in ipairs(ns.AuraOrder.Items(get, set, defaultSort)) do items[#items + 1] = item end
    return items
end

function ns.AuraOrder.Items(get, set, defaultSort)
    local LEM = LibStub("FlareEditMode")
    defaultSort = defaultSort or "default"
    local function Sort() return get("auraSort")() or defaultSort end
    return {
        { name = L["Sort By"], kind = LEM.SettingType.Dropdown, default = defaultSort, canon = "Aura Sort By",
          values = { { text = L["Default"], value = "default", isRadio = true }, { text = L["Order Applied"], value = "applied", isRadio = true },
                     { text = L["Time Left"], value = "time", isRadio = true }, { text = L["Name"], value = "name", isRadio = true } },
          get = Sort, set = set("auraSort"),
          desc = L["Default: yours first, then the important ones. Time Left: the soonest to end first."] },
        { name = L["Reverse Order"], kind = LEM.SettingType.Checkbox, default = false,
          get = function() return get("auraReverse")() and true or false end, set = set("auraReverse"),
          desc = L["Turns the order around: newest, longest left or Z first."] },
        { name = L["Your Auras First"], kind = LEM.SettingType.Checkbox, default = true,
          get = function() return get("auraMineFirst")() ~= false end, set = set("auraMineFirst"),
          hidden = function() local s = Sort(); return s ~= "time" and s ~= "name" end,
          desc = L["Your own auras lead, the rest follow in the same order."] },
    }
end

-- The level the frames show, as Blizzard's target frame reads it:
-- Forever's UnitLevel gives a far higher mob its real level (53), while UnitEffectiveLevel gives -1,
-- the "too high to tell" that Blizzard draws as the skull. UnitLevel only when that can't be read.
function ns.UnitShownLevel(unit)
    local level = UnitEffectiveLevel and UnitEffectiveLevel(unit)
    if canaccessvalue(level) and type(level) == "number" then return level end
    return UnitLevel(unit)
end
-- "Too high to tell": Blizzard's skull, sized to the level text (a frame's High Level Skull switch off: a red ??)
ns.HIGH_LEVEL_SKULL = "|A:UI-HUD-UnitFrame-Target-HighLevelTarget_Icon:0:0|a"
function ns.SetHighLevelText(fontString, icons)
    local store = icons and icons.highSkull
    if store and store.shown == false then
        fontString:SetText("??")
        fontString:SetTextColor(1, 0.1, 0.1)
    else
        fontString:SetText(ns.HIGH_LEVEL_SKULL)
        fontString:SetTextColor(1, 1, 1)
    end
end

-- A level on the frames: friendly units in Blizzard's gold, neutral and hostile ones by difficulty
local LEVEL_GOLD = { r = 1, g = 0.82, b = 0 }
function ns.UnitLevelColor(unit, level)
    local friend = UnitIsFriend("player", unit)
    if canaccessvalue(friend) and friend then return LEVEL_GOLD end
    return ns.LevelDifficultyColor(unit, level)
end

-- A unit's name on the frames. Forever's UnitName returns first name and surname apart; the full name
-- joins them as NameUtil.FormatUnitNameForDisplay does. A unit frame's text slot picks First Name or
-- Full Name (full false: first only); "focus" and "targetof" (the party target tiles) always show the
-- first name only.
-- A secret name or surname leaves the first name alone.
function ns.UnitDisplayName(unit, frameKind, full)
    local name, surname = UnitName(unit)
    -- (frames without a pick yet: party, raid; the saved Full Player Names choice)
    if full == nil then
        local uf = ns.db and ns.db.profile and ns.db.profile.unitframes
        full = not (uf and uf.fullNames == false)
    end
    if not full or frameKind == "targetof" or frameKind == "focus" then return name end
    if not (canaccessvalue(name) and canaccessvalue(surname)) then return name end
    if type(name) ~= "string" or type(surname) ~= "string" or surname == "" then return name end
    local consts = Constants and Constants.CharacterNameSeparatorConsts
    local sep = consts and consts.CHARACTERNAME_SURNAME_SEPARATOR
    return name .. (type(sep) == "string" and sep or " ") .. surname
end

-- Class colours on a frame's health bar (st: its settings). A frame not set yet follows the one switch
-- this replaced, so off carries over in every profile and style setup; on by default.
function ns.ClassColorsOn(st)
    if st and st.classColor ~= nil then return st.classColor end
    local uf = ns.db and ns.db.profile and ns.db.profile.unitframes
    return not uf or uf.classColor ~= false
end

-- Buffs Size and Debuffs Size on a frame (st: its settings). A frame not set yet follows the single
-- Aura Size these replaced, so every profile and style setup keeps the size it had.
function ns.AuraSize(st, isDebuff, fallback)
    if not st then return fallback end
    local size
    if isDebuff then size = st.debuffSize else size = st.buffSize end
    return size or st.auraSize or fallback
end

-- A built combo point on segmented bars, and the one-pixel line between segments
ns.COMBO_COLOR = { 1.00, 0.30, 0.18 }
ns.SEGMENT_LINE_COLOR = { 0, 0, 0, 1 }

--------------------------------------------------
-- 3. COMBO POINTS AND SEGMENTS
-- Parts are pixels (left, right, top, bottom) of the 128 px player-frame sheet. The shine is drawn
-- on black, so it uses the ADD blend.
--------------------------------------------------
local COMBO_FILE  = "Interface\\PlayerFrame\\ClassOverlayComboPoints"
local COMBO_SHEET = 128
local COMBO_RIM   = { 0.80, 0.60, 0.34 }   -- #CC9957
local COMBO_PARTS = {
    socket = { 28, 50, 65, 87 },
    gem    = { 3, 19, 79, 95 },
    shine  = { 0, 27, 49, 76 },
}
local SOCKET_PX = COMBO_PARTS.socket[2] - COMBO_PARTS.socket[1]
local GEM_RISE  = 1   -- sheet px the rim's centre sits above the socket cell's

-- RogueComboPointTemplate is 20 px, but its art reaches past the widget: points are spaced by
-- that reach plus a gap
local BLIZZ_POINT_SIZE = 20
local POINT_ART, POINT_GAP = 1.2, 2

-- One physical screen pixel in a frame's own units, so a 1-pixel line stays one pixel at any UI scale
-- (the screen height can read 0 for a moment while the display mode changes: one unit then)
function ns.PixelSize(frame)
    local factor = PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor()
    local scale = frame:GetEffectiveScale()
    if not (factor and factor > 0 and factor < math.huge and scale and scale > 0) then return 1 end
    return factor / scale
end

-- The pixel-exact layouts (combo segments, XP bar bubbles, the quest tracker's lines) again after a UI scale or
-- display change, out of combat
do
    local watcher = CreateFrame("Frame")
    local function Relayout()
        if InCombatLockdown() then
            watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
            return
        end
        watcher:UnregisterEvent("PLAYER_REGEN_ENABLED")
        for _, module in ipairs({ ns.ResourceBars, ns.UnitFrames, ns.XPBar }) do
            if module and module.initialized and module.Refresh then ns.SafeCall("Relayout Refresh", module.Refresh, module) end
        end
        local ot = ns.ObjectiveTracker
        if ot and ot.initialized and ot.RequestRender then ns.SafeCall("Relayout tracker", ot.RequestRender, ot) end
    end
    watcher:RegisterEvent("UI_SCALE_CHANGED")
    watcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
    watcher:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then Relayout() else C_Timer.After(0.2, Relayout) end
    end)
end

-- Segment i of n across a width, on whole screen pixels: left edge, width, pixel size
function ns.SegmentSpan(frame, width, n, i)
    local px = ns.PixelSize(frame)
    local total = math.floor(width / px + 0.5)
    local left = math.floor(total * (i - 1) / n + 0.5)
    local right = math.floor(total * i / n + 0.5)
    return left * px, (right - left) * px, px
end

-- scale: screen px per sheet px; sizes the texture when given
local function SetComboPart(tex, part, scale)
    local p = COMBO_PARTS[part]
    local l, r, t, b = p[1], p[2], p[3], p[4]
    tex:SetTexture(COMBO_FILE)
    tex:SetTexCoord(l / COMBO_SHEET, r / COMBO_SHEET, t / COMBO_SHEET, b / COMBO_SHEET)
    if scale then tex:SetSize((r - l) * scale, (b - t) * scale) end
    if part == "socket" then
        tex:SetDesaturated(true)
        tex:SetVertexColor(COMBO_RIM[1], COMBO_RIM[2], COMBO_RIM[3])
    elseif part == "shine" then
        tex:SetBlendMode("ADD")
    end
end

-- Blizzard's ComboFrame shine timings
local function CreateShineFlash(shine)
    local flash = shine:CreateAnimationGroup()
    local fadeIn = flash:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(0.3)
    fadeIn:SetOrder(1)
    local fadeOut = flash:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(0.4)
    fadeOut:SetOrder(2)
    return flash
end

-- size: the socket's side length
local function SizeComboGem(gem, size)
    local scale = size / SOCKET_PX
    local gemPart = COMBO_PARTS.gem
    local left, right, top, bottom = gemPart[1], gemPart[2], gemPart[3], gemPart[4]
    gem:SetSize(size, size)
    gem.window:SetSize((right - left) * scale, (bottom - top) * scale)
    gem.window:ClearAllPoints()
    gem.window:SetPoint("CENTER", gem, "CENTER", 0, GEM_RISE * scale)
    gem.lit:SetSize(COMBO_SHEET * scale, COMBO_SHEET * scale)
    gem.lit:ClearAllPoints()
    gem.lit:SetPoint("TOPLEFT", gem.window, "TOPLEFT", -left * scale, top * scale)
    SetComboPart(gem.shine, "shine", scale)
    gem.shine:ClearAllPoints()
    gem.shine:SetPoint("CENTER", gem.window, "CENTER")
end

-- The lit gem is a StatusBar with range [i-1, i] fed the raw count, so no Lua compares a secret
-- value. black: the empty socket is filled black.
local function CreateComboGem(parent, i, size, black)
    local gem = CreateFrame("Frame", nil, parent)
    local socket = gem:CreateTexture(nil, "BACKGROUND")
    SetComboPart(socket, "socket")
    socket:SetAllPoints()
    -- an additive copy of the socket: a tint can only darken, and the rim art is dark
    local boost = gem:CreateTexture(nil, "BACKGROUND", nil, 1)
    SetComboPart(boost, "socket")
    boost:SetBlendMode("ADD")
    boost:SetAllPoints(socket)

    local window = CreateFrame("Frame", nil, gem)
    window:SetClipsChildren(true)
    if black then
        local fill = window:CreateTexture(nil, "BACKGROUND")
        SetComboPart(fill, "gem")
        fill:SetDesaturated(true)
        fill:SetVertexColor(0, 0, 0)
        fill:SetAllPoints()
    end
    local lit = CreateFrame("StatusBar", nil, window)
    lit:SetStatusBarTexture(COMBO_FILE)
    lit:SetMinMaxValues(i - 1, i)
    lit:SetValue(i - 1)

    -- the shine is bigger than the gem, so it sits above the lit bar outside the clip window
    local shineHolder = CreateFrame("Frame", nil, gem)
    shineHolder:SetAllPoints(window)
    shineHolder:SetFrameLevel(lit:GetFrameLevel() + 1)
    local shine = shineHolder:CreateTexture(nil, "OVERLAY")
    shine:SetAlpha(0)
    gem.window, gem.lit, gem.shine = window, lit, shine
    gem.flash = CreateShineFlash(shine)
    SizeComboGem(gem, size)
    return gem
end

-- Centre-to-centre distance between points
function ns.ComboPointStep(size)
    return size * POINT_ART + POINT_GAP
end

-- Blizzard's RogueComboPointTemplate must be told whether it is lit, so it shows only while the
-- count is readable; FlareUI's gem stands in while the count is secret or the template is missing.
function ns.CreateComboPoint(parent, i, size, black)
    local p = CreateFrame("Frame", nil, parent)
    p.index = i
    p.gem = CreateComboGem(p, i, size, black)
    p.gem:SetPoint("CENTER")
    local ok, blizz = pcall(CreateFrame, "Frame", nil, p, "RogueComboPointTemplate")
    if ok and blizz and blizz.SetActive and blizz.SetActiveNoAnimation then
        blizz:Setup()
        blizz:SetPoint("CENTER")
        p.blizz = blizz
    end
    ns.SizeComboPoint(p, size)
    ns.SetComboPoint(p, 0, false)
    return p
end

function ns.SizeComboPoint(p, size)
    p:SetSize(size, size)
    SizeComboGem(p.gem, size)
    if p.blizz then p.blizz:SetScale(size / BLIZZ_POINT_SIZE) end
end

-- points: the raw count, possibly secret. animate: off right after a target change, as Blizzard does.
function ns.SetComboPoint(p, points, animate)
    local known = p.blizz and type(points) == "number" and (not canaccessvalue or canaccessvalue(points)) or false
    if p.blizz then p.blizz:SetShown(known) end
    p.gem:SetShown(not known)
    if known then
        local lit = p.index <= points
        if animate then p.blizz:SetActive(lit) else p.blizz:SetActiveNoAnimation(lit) end
    else
        p.gem.lit:SetValue(points)
    end
end

--------------------------------------------------
-- 4. DEFAULTS
--------------------------------------------------
-- Every element with a Show choice (Modules/Visibility.lua): always shown, in no fade group
local VISIBILITY_KEYS = { "bar1", "bar2", "bar3", "bar4", "bar5", "bar6", "bar7", "bar8", "pet", "stance", "bags", "menu", "xp", "minimap" }

local function VisibilityElements()
    local t = {}
    for _, key in ipairs(VISIBILITY_KEYS) do t[key] = { show = "always", group = 0 } end
    return t
end

local function FCMBars()
    local t = {}
    for i = 1, 8 do
        t["bar" .. i] = { enabled = false }
    end
    return t
end

-- Unit frame fonts: each frame's own texts, set on the Unit Frames page's
-- Fonts tab, a section per frame (Settings/Pages/UnitFrames.lua). Frames: player, target, focus, pet, targettarget, focustarget,
-- party, raid, boss. Saved per frame style (unitframes.frameFonts isn't a shared key).
do
    local function Font(size) return { face = "__global", size = size, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 } end
    ns.UF_FONT_DEFAULTS = {
        -- cast: the spell's name; castTime: its countdown
        names = Font(12), health = Font(12), level = Font(12), power = Font(10), cast = Font(12), castTime = Font(12),
        auras = Font(0), auraCount = Font(0),   -- 0: Auto, sized to the icon
        -- Show Combat Text (player, pet): 0 Auto, sized to the portrait; thick outline as Blizzard's
        combatText = { face = "__global", size = 0, flags = "THICKOUTLINE", enableShadow = false, shadowX = 1, shadowY = -1 },
    }
    -- the raid frames' own: health and power one size smaller; the rest as above
    -- the pet frame's name and health two sizes smaller, its power two (8); every cast bar but
    -- the player's (its frame's and the FlareUI Player Cast Bar) two smaller in the spell name and timer
    ns.UF_FONT_FRAME_DEFAULTS = {
        -- raid 10 / 8 / 6 in every style (the tiles draw the set size)
        raid = { names = Font(10), health = Font(8), power = Font(6) },
        -- target of target / of focus: 8 / 8 / 6 in every style (drawn at their set size)
        targettarget = { names = Font(8), health = Font(8), power = Font(6) },
        focustarget = { names = Font(8), health = Font(8), power = Font(6) },
        pet = { names = Font(10), health = Font(10), power = Font(8) },
        -- focus 10 / 10 / 8 (every style draws the set size)
        focus = { names = Font(10), health = Font(10), power = Font(8) },
    }
    for _, key in ipairs({ "target", "focus", "pet", "targettarget", "focustarget", "party", "raid", "boss", "flag" }) do
        local own = ns.UF_FONT_FRAME_DEFAULTS[key] or {}
        own.cast, own.castTime = Font(10), Font(10)
        ns.UF_FONT_FRAME_DEFAULTS[key] = own
    end
    function ns.UFFontDefault(key, element)
        local own = ns.UF_FONT_FRAME_DEFAULTS[key]
        return (own and own[element]) or ns.UF_FONT_DEFAULTS[element]
    end
end

local defaults = {
    profile = {
        -- Global Font (Settings page > Fonts): the face every font set to Global ("__global") uses
        -- Game Text, Nameplate Font and Combat Text Font (Settings/Fonts.lua ns.GameFonts): off and
        -- Default ("") leave Blizzard's fonts alone; combat.path: the chosen file, kept for the next login
        fonts = { global = { face = "Friz Quadrata TT" }, gameText = false, nameplate = { face = "" }, combat = { face = "" } },
        editModeOverlaysHidden = false,   -- eye button on the HUD Edit Mode window (EditModeOverlays.lua)

        -- [[ CHAT MODULE ]]
        chat = {
            enabled = false,

            -- General
            hideCombatLog = false,
            saveHistory = true,
            whisperSound = "off",       -- Whisper Sound: off | raidwarning | alarm | whisper

            copyButton = true,          -- the copy icon in each window's top right corner
            increaseLineHeight = false, -- a little more space between chat lines
            fadeLines = false,          -- Fade Old Lines (Edit Mode Fading): each line fades, oldest first
            formatNPC = false,
            formatPlayer = false,
            betterTimestamps = false,
            showLevel = false,          -- the sender's level in front of the name, when known
            shortChannels = false,      -- on for Channel Names Short or Number (channelNames picks which)
            channelNames = nil,         -- full | short | number (nil: number when shortChannels, else full)
            raceIcons = false,          -- the sender's race icon before the name
            classIcons = false,         -- the sender's class icon before the name
            linkIcons = false,          -- icons inside item and spell links
            whisperMarkers = false,     -- > and < instead of "whispers:" and "To"
            hideBubblesInInstance = false,

            -- Frame (Blizzard dark dialog background + the chosen border, tinted ns.BORDER_COLOR)
            frameStyle = "modern",       -- Frame Style: modern | flareui (the quest tracker's look; Chat.lua Chat.ApplyFrameStyleArt)
            borderTexture = "FlareUI Frames",
            opacity = 0.75,
            unreadGlow = "say,yell,party,raid,guild,whisper,channel",  -- Tab Glow: kinds of lines that light an unseen tab ("none" = none)
            tabChannel = false,         -- Tab Sets Channel: picking a tab that shows one kind of chat makes it the kind you type in

            -- Edit Box (fixed look: black background + tooltip border tinted ns.BORDER_COLOR)
            editBoxOpacity = 1.0,
            editBoxPosition = "inside",  -- inside | below | above the chat window
            editBoxStyle = "modern",     -- Edit Box Style: modern | flareui (Blizzard's own art); Edit Box Border: editBoxBorder, unset reads the chat's (Chat.lua Chat.EditBoxBorder)

            -- Header buttons
            showVolume = true,
            socialHide = false,
            menuHide = false,
            channelHide = false,

            -- the chat's Visibility, fade speeds, Faded Opacity and Fade Delay moved into its Edit Mode
            -- dialog (visibility.elements.chat, Modules/Visibility.lua). These four are only read once per
            -- profile to copy them over (MigrateMovedFades), so they keep their old defaults.
            visibility = "always",
            fadeSpeed = "instant",
            autoHideDelay = 5,          -- Fade Delay: seconds the chat stays after showing (0 = at once)
            minAlpha = 0,               -- Faded Opacity: how far the chat fades out (0 to 0.9)

            -- Typography
            chatFont = { face = "Arial Narrow", size = 12, flags = "NONE", enableShadow = true, shadowX = 1, shadowY = -1 },
            tabFont = { face = "__global", size = 12, flags = "NONE", enableShadow = true, shadowX = 1, shadowY = -1 },
            editBoxFont = { face = "__global", size = 12, flags = "NONE", enableShadow = true, shadowX = 1, shadowY = -1 },
        },

        -- [[ ACTION BARS MODULE ]]
        actionbars = {
            enabled = false,
            flareBorders = true,        -- Skin Action Bars: FlareUI Frames in place of the buttons' frame (ActionBars.lua 6b)
            buttonScale = 1.11,         -- Bar Scale: every button's scale

            -- General
            hideHotkeys = false,
            hideMacroText = true,
            procGlow = false,           -- Blizzard's proc glow on reaction abilities and flagged procs
            buttonArt = true,
            stopAutoAddSpells = false,
            gryphonsBehind = false,     -- Gryphons Behind Bars: the end caps draw under the bars
            borderlessMenu = false,     -- Borderless Micro Menu: no frame art round the micro menu
            -- Collapsible Bag Bar: no frame art or dividers on the bag bar, and an arrow folds the bag slots
            -- away
            collapsibleBags = false,
            equippedBorder = false,     -- Equipped Item Border: a worn item's button bordered in its quality colour
            activeHighlight = false,    -- Active Highlight: the checked button (stance, queued attack) drawn plainly
            autoRanks = false,          -- Update Spell Ranks: a new rank replaces the old one on the bars
            keepStealthPage = false,    -- Keep Page 1 in Stealth: bar 1 holds page 1 (druids: Cat Form's) in Stealth / Prowl
            noStancePaging = false,     -- No Auto-Paging for Stances: warriors' bar 1 stays on its page

            -- Status colouring (one row sets both)
            colors = {
                enableRange = true,
                unusable = { desaturate = true },
            },

            -- the FlareUI XP Bar (Modules/XPBar.lua), placed in Edit Mode; off leaves Blizzard's bars alone
            xpbar = { enabled = true, width = 560, height = 14, texture = "FlareUI Dark", border = "FlareUI Thin", textMode = "HOVER", textFormat = "VALUES", questXP = false, questXPMode = "done", bubbles = false, tooltip = false, layouts = {} },   -- bubbles: false / 10 / 20 (true from the old switch = 20)

            -- Typography
            hotkeyFont = { face = "Arial Narrow", size = 12, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 },
            countFont = { face = "Arial Narrow", size = 14, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 },
            macroFont = { face = "Arial Narrow", size = 10, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 },
            -- the XP bar's numbers (starts as a copy of the Keybinds font, XPBar.lua)
            xpFont = { face = "Arial Narrow", size = 12, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 },
        },

        -- [[ FAKE COOLDOWN MANAGER (FCM) ]]
        fcm = {
            bars = FCMBars(),           -- Fake CM is on while a bar is picked
            show = "combat",            -- always, or toggles joined by commas (ns.Conditions, Modules/Visibility.lua)
        },

        -- [[ DAMAGE METER MODULE ]]
        damagemeter = {
            enabled = false,
            -- fadeSpeed, minAlpha, fadeDelay, visibility, showOnMouseover and threatVisibility moved into
            -- the meter's and the threat window's Edit Mode dialogs (visibility.elements.meter / .threat,
            -- Modules/Visibility.lua): only read once per profile to copy them over (MigrateMovedFades)
            fadeSpeed = "instant",      -- instant | fast | slow: every show and hide (Visibility, mouseover)
            minAlpha = 0,               -- Faded Opacity: how far the meter fades out (0 to 0.9)
            fadeDelay = 0,              -- Fade Delay: seconds it stays up before fading (0 = Instant)

            opacity = 0.75,
            frameStyle = "modern",       -- Frame Style: modern | flareui (the chat's FlareUI look; Chat.lua Chat.ApplyFrameStyleArt)
            borderTexture = "FlareUI Frames",
            barTexture = "",            -- Bar Texture: "" = Blizzard's own, else a unit frame bar texture
            barFont = { face = "__global", size = 12, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 },
            -- the title row: Damage Meter / Threat, the session and its timer (in the header's gold)
            headerFont = { face = "__global", size = 12, flags = "NONE", enableShadow = true, shadowX = 1, shadowY = -1 },
            combatTimer = true,         -- Blizzard's "[mm:ss]" session timer in the title row
            visibility = "always",      -- always | combat | group | instance | hidden (overrules Blizzard's Edit Mode one)
            showOnMouseover = false,    -- while the visibility hides the meter, it shows under the mouse
            matchChatSize = false,      -- the meter takes the chat frame's size (Edit Mode's is overridden)
            chatTab = false,            -- a Meter tab with the chat's tabs: the meter in the chat window (Chat module on)
            chatTabIgnoreFade = false,  -- on the Meter tab the chat never fades, whatever its Visibility
            chatTabOpen = "combat",     -- the Meter tab opens on its own: click | combat | group | login
            autoThreat = false,         -- the Threat tab when combat starts, Blizzard's view when it ends
            resetOnInstance = false,    -- clear the meter on entering a new dungeon or raid
            resetOnGroupLeave = false,  -- Reset on Leaving a Group
            threatPullLine = true,      -- Threat tab: a line on the bars where you would pull the mob
            threatPullFlash = true,     -- Threat tab: your bar flashes as you near that line
            threatPullSound = false,    -- Pull Warning Sound: once as Pull Warning starts
            threatTankLead = true,      -- Threat tab: the tank's row shows its lead over second place, "(+25%)"
            threatValueDisplay = "percent", -- Threat tab: "both" / "percent" / "value"
            threatWindow = false,       -- Separate Window: threat in its own window, no Threat tab
            threatVisibility = "meter", -- its Visibility: meter (as the meter) / instance / group / combat
            reportLines = 5,            -- Report to Chat (meter menu): how many names it sends, 3 / 5 / 10
        },

        -- [[ MINIMAP MODULE ]]
        minimap = {
            enabled = false,
            buttonMoves = {},           -- edge icons the player moved: { [sundial|finder|vehicle|durability] = { angle, scale } } (Minimap.lua MM.Moves)
            style = "square",
            squareHeader = "headerless", -- Header (square style): headerless | art (Minimap.lua HEADER_STYLES)
            squareBorder = "bronze",    -- Border (with squareHeader headerless): bronze | thick | thin; Header = squareHeader art (Minimap.lua MM.SQUARE_BORDERS)
            autoZoom = 5,               -- seconds before zooming back out (0 = off)
            flareButton = true,         -- FlareUI Minimap Button: FlareUI's own button, on the map or in the drawer (Minimap.lua MM.UpdateFlareButton)
            buttonBag = true,           -- the badge opens a bag with every addon's minimap button (MinimapBag.lua)
            drawerStyle = "sundial",    -- Drawer Style: disabled / sundial / blizzard (MinimapBag.lua)
            sundial = true,             -- Sundial (Map Tools): the day/night badge shown (MinimapBag.lua)
            infoBarHover = false,       -- Info Bar On Mouseover: the bar only while pointing at the map
            infoBarBox = true,          -- Info Bar Show Box: the plates behind the cells
            infoBarBelow = false,       -- Info Bar Below the Map: under the map's frame, not over it
            barFont = { face = "__global", size = 11, flags = "NONE", enableShadow = true, shadowX = 1, shadowY = -1 },   -- Info Bar font, as Info Text
            bagHover = false,           -- Open on Mouseover: pointing at the badge opens the bag (MinimapBag.lua)
            bagButtonSize = 100,        -- Drawer Button Size: 100..150 percent of the drawer's buttons (MinimapBag.lua Bag.ButtonSize)
            clockStats = true,          -- framerate and latency in the clock's tooltip
            microMenu = false,          -- middle-click the map: a list of Blizzard's panels
            finderEye = false,          -- Group Finder Icon: a small icon in place of Blizzard's queue eye (MinimapEye.lua)
            durability = false,         -- Durability Icon: one icon for Blizzard's durability figure (MinimapDurability.lua)
            vehicleExit = false,        -- Vehicle Exit Icon: the exit button at the map's bottom (MinimapVehicle.lua)
            infoBar = { left = "none", center = "none", right = "none" },
            -- Fonts tab: the zone name and the clock (Forever's own look by default)
            zoneFont  = { face = "__global", size = 10, flags = "NONE", enableShadow = true, shadowX = 1, shadowY = -1 },
            clockFont = { face = "__global", size = 12, flags = "NONE", enableShadow = true, shadowX = 1, shadowY = -1 },
            -- coordinates, framerate and latency
            infoFont = { face = "__global", size = 11, flags = "NONE", enableShadow = true, shadowX = 1, shadowY = -1 },
        },

        -- [[ UNIT FRAMES MODULE ]]
        unitframes = {
            enabled = false,
            simplePet = false,          -- Simple Pet Frame: the plain pet frame in every style; off, it follows the style
            simpleTargetOf = false,     -- Simple "Target Of": the same for target of target and target of focus
            levelSize = 1,              -- Level Badge Size: the ring styles' level disc, 0.5-1 of its size (UnitFramesRing.lua LayoutLevel)
            fullNames = true,           -- (the retired Full Player Names switch: its saved "off" makes a setup's names start as First Name)
            palette = "flareui",        -- the bars' colours: flareui (FlareUI's softer tones) | blizzard (UnitFrames' ApplyPalette)
            foreverStyle = true,        -- Forever's bronze portrait ring on player / target / focus; off = Addon style (UnitFramesRing.lua)
            auraStyle = "square",       -- the unit frames' aura icons: square | round
            auraTimer = "none",         -- none | below | bottom | middle
            auraTimerColor = true,      -- Timer Colour: yellow under 10 s, red under 5
            auraSwipe = "both",         -- both | icon (over the icon) | border (around the edge) | none
            -- The look is set per frame in Edit Mode (units.* below).
            -- font: level, name and health; fontPower: power value; fontCast: spell name and timer.
            font      = { face = "__global", size = 12, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 },
            fontPower = { face = "__global", size = 10, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 },
            fontCast  = { face = "__global", size = 12, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 },
            -- positions per Edit Mode layout: layouts[name][unit] = { point, x, y }
            layouts = {},
            -- Blizzard's totem frame on FlareUI Totems (Modules/Totems.lua): size in %, totems per row
            totems = { size = 90, perRow = 4, swipe = "both", timer = "none" },
            -- aura timers and stack counts; size 0 (Auto) follows the icon size. The stack font starts
            -- as a copy of the timer font (ns.SeedFont)
            auraFont = { face = "__global", size = 0, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 },
            auraCountFont = { face = "__global", size = 0, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 },
            -- each frame's fonts (above: the shared ones they started from, kept for the first copy)
            -- (each frame's own defaults over the shared ones: ns.UF_FONT_FRAME_DEFAULTS)
            frameFonts = (function()
                local t = { ["**"] = ns.UF_FONT_DEFAULTS }
                for key, own in pairs(ns.UF_FONT_FRAME_DEFAULTS) do t[key] = own end
                return t
            end)(),
            editSections = {},          -- (unused: open sections are per session, Core.lua ns.EditSections)
            -- resource bars (Modules/ResourceBars.lua); positions in layouts[layout][bar]
            resource = {
                enabled = false,        -- the Resource Bars module (Settings: its own page)
                font = { face = "__global", size = 10, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 },
                layouts = {},
                bars = {
                    -- font: each bar's own (Edit Mode > Fonts), first copied from the shared font above plus
                    -- the bar's old size step
                    health      = { enabled = false, show = "combat", width = 220, height = 16, text = "both", font = { face = "__global", size = 12, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 } },
                    power       = { enabled = false, show = "combat", width = 220, height = 16, text = "value", fsr = false, font = { face = "__global", size = 12, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 } },
                    mana        = { enabled = false, show = "combat", width = 220, height = 16, text = "value", fsr = false, font = { face = "__global", size = 12, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 } },
                    combo       = { enabled = false, show = "combat", width = 220, height = 12 },
                    -- Queued Attack Colour, Stand-Still Zone and Waiting State on by default
                    swingMain   = { enabled = false, show = "inuse",        width = 220, height = 12, queueTint = true, waiting = true, font = { face = "__global", size = 10, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 } },
                    swingOff    = { enabled = false, show = "inuse",        width = 220, height = 12, waiting = true, font = { face = "__global", size = 10, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 } },
                    swingRanged = { enabled = false, show = "inuse",        width = 220, height = 12, standStill = true, waiting = true, font = { face = "__global", size = 10, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 } },
                    flight      = { enabled = false, show = "always",       width = 220, height = 14, font = { face = "__global", size = 10, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 } },   -- Flight Timer
                    seal        = { enabled = false, show = "always",       width = 220, height = 14, font = { face = "__global", size = 10, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 } },   -- Seals, paladins
                    timer       = { enabled = false, show = "always",       width = 220, height = 14, font = { face = "__global", size = 10, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 } },   -- Timer Bars: breath, fatigue, feign death
                },
            },
            -- party frames (Modules/PartyFrames.lua): two styles, each with its own settings
            party = {
                enabled = true,             -- on with the Unit Frames module
                style = "classic",          -- classic | raid
                showPlayer = true, pets = false, sortByRole = true,
                hidePlayerInParty = false,  -- Hide Player Frame while in party (with Show Player)
                showSolo = false,           -- Show When Solo: your own tile shows with no group (with Show Player)
                targets = false,                 -- Show Party Targets: each member's target beside its frame
                orientation = "VERTICAL",   -- VERTICAL | HORIZONTAL
                layouts = {},
                classic = {
                    width = 240, height = 70, powerHeight = 12, spacing = 14, healthText = "percent", powerText = "value",
                    showLevel = true, portrait = "none",
                    texture = "FlareUI Dark", border = "FlareUI Thick",
                    absorbTexture = "FlareUI Striped",
                    debuffs = "INSIDE_TOPRIGHT", buffs = "INSIDE_TOPLEFT", dispels = "PORTRAIT",
                    auraSize = 16, dispelHighlight = "mine",
                    castbar = false, castHeight = 16, castTexture = "FlareUI Dark", castBorderTexture = "FlareUI Thin", castIcon = true, castTimer = true,
                    petHeight = 19, petWidth = 120, petBorder = "FlareUI Thin", icons = {},
                    targetWidth = 100, targetHeight = 25, targetBorder = "FlareUI Thin",
                    threatGlow = true,          -- Threat Glow (Look): the border pulses with aggro
                },
                raid = {
                    width = 200, height = 70, powerHeight = 6, spacing = 12, healthText = "none",
                    texture = "FlareUI Dark", border = "FlareUI Thin",
                    absorbTexture = "FlareUI Striped",
                    debuffs = "INSIDE_BOTTOMRIGHT", buffs = "INSIDE_BOTTOMLEFT", dispels = "PORTRAIT",
                    auraSize = 16, dispelHighlight = "mine",
                    castbar = false, castHeight = 10, castTexture = "FlareUI Dark", castBorderTexture = "FlareUI Thin", castIcon = false, castTimer = false,
                    petHeight = 14, petWidth = 80, petBorder = "FlareUI Thin", icons = {},
                    targetWidth = 100, targetHeight = 25, targetBorder = "FlareUI Thin",
                    threatGlow = true,
                },
            },
            -- raid frames (Modules/RaidFrames.lua): the Raid-Style tile for everyone in a raid, main tank
            -- frames
            raid = {
                enabled = true,             -- on with the Unit Frames module
                hidePlayerInRaid = false,   -- Hide Player Frame in a Raid: player and pet frames hide in a raid
                layouts = {}, tankLayouts = {},
                sort = "GROUP",            -- GROUP | ROLE | CLASS
                orientation = "ROWS",      -- ROWS (each group a row, stacked) | COLUMNS
                spacing = 10, groupSpacing = 10, groupNumbers = false, absorbTexture = "FlareUI Striped",
                width = 90, height = 60,
                -- the main tank frames: their own size, and these of their own (the rest is the raid's)
                mainTanks = { enabled = false, w = 182, h = 60, spacing = 10,
                              buffs = "INSIDE_LEFT", debuffs = "INSIDE_RIGHT", auraSize = 14,
                              hideBuffs = "OFF", onlyMyBuffs = true, dispellableOnly = false },
                powerHeight = 10, healthText = "none", texture = "FlareUI Dark", border = "FlareUI Thin",
                debuffs = "INSIDE_RIGHT", buffs = "INSIDE_LEFT", dispels = "INSIDE_BOTTOMRIGHT",
                auraSize = 12, dispelHighlight = "mine",
                icons = {},
                threatGlow = true,          -- Threat Glow (Look; main tanks too)
            },
            -- boss frames (Modules/BossFrames.lua): boss1-5 on the classic party tile, mirrored
            boss = {
                enabled = true,
                layouts = {},
                width = 240, height = 70, powerHeight = 12, grow = "DOWN", spacing = 14,
                healthText = "percent", powerText = "value", showLevel = true, portrait = false, raidIcon = true,
                mirror = true, onlyMyDebuffs = true, absorbTexture = "FlareUI Striped",
                texture = "FlareUI Dark", border = "FlareUI Thick",
                debuffs = "INSIDE_TOPRIGHT", buffs = "INSIDE_TOPLEFT", auraSize = 16, hideBuffs = "OFF",
                castbar = true, castHeight = 14, castTexture = "FlareUI Dark", castBorderTexture = "FlareUI Thin", castIcon = true, castTimer = true,
                threatGlow = true,          -- Threat Glow (Look): the player's threat on the boss
            },
            -- Flag Carrier Frames (off; Modules/FlagCarriers.lua): the battleground flag carriers on
            -- FlareUI's own frames (arena1 / arena2, the boss frames' kit)
            flagCarriers = {
                enabled = false, layouts = {},
                width = 180, height = 50, powerHeight = 8, grow = "DOWN", spacing = 10,
                healthText = "percent", powerText = "value", showLevel = true,
                mirror = true, absorbTexture = "FlareUI Striped", texture = "FlareUI Dark", border = "FlareUI Thin",
                castbar = true, castHeight = 12, castTexture = "FlareUI Dark", castBorderTexture = "FlareUI Thin",
                castIcon = true, castTimer = true,
            },
            -- standalone player cast bar (replaces PlayerCastingBarFrame)
            playerCastbar = { enabled = true, width = 250, height = 25, texture = "FlareUI Dark", borderTexture = "FlareUI Thin", icon = true, timer = true, pushback = false },
            units = {
                player       = { enabled = true, width = 240, height = 60, powerHeight = 15, healthText = "percent", powerText = "value", showLevel = true,
                                 texture = "FlareUI Dark", border = "FlareUI Thick",
                                 absorbTexture = "FlareUI Striped",
                                 -- Cast Bar (off): a cast bar on the player frame, apart from the FlareUI Player Cast Bar
                                 castbar = false, castbarPosition = "BOTTOM", castHeight = 16, castTexture = "FlareUI Dark", castBorderTexture = "FlareUI Thin", castIcon = true, castTimer = true,
                                 pushback = false,
                                 buffs = "TOPLEFT", debuffs = "TOPRIGHT", auraSize = 24,
                                 combatGlow = true },   -- Combat Glow (Look)
                target       = { enabled = true, width = 240, height = 60, powerHeight = 15, healthText = "percent", powerText = "value", showLevel = true, mirror = true,
                                 texture = "FlareUI Dark", border = "FlareUI Thick",
                                 absorbTexture = "FlareUI Striped",
                                 castbar = true, castbarPosition = "BOTTOM", castHeight = 16, castTexture = "FlareUI Dark", castBorderTexture = "FlareUI Thin", castIcon = true, castTimer = true,
                                 buffs = "TOPLEFT", debuffs = "TOPRIGHT", auraSize = 24, onlyMyDebuffs = true,
                                 threatGlow = true },   -- Threat Glow (Look)
                targettarget = { mirror = true, enabled = true, width = 100, height = 25, powerHeight = 0, healthText = "none", powerText = "value", showLevel = false,
                                 texture = "FlareUI Dark", border = "FlareUI Thin" },
                focus        = { enabled = true, width = 160, height = 35, powerHeight = 0, healthText = "percent", powerText = "value", showLevel = true, mirror = true,
                                 texture = "FlareUI Dark", border = "FlareUI Thick",
                                 absorbTexture = "FlareUI Striped",
                                 castbar = true, castbarPosition = "BOTTOM", castHeight = 16, castTexture = "FlareUI Dark", castBorderTexture = "FlareUI Thin", castIcon = true, castTimer = true,
                                 buffs = "TOPLEFT", debuffs = "TOPRIGHT", auraSize = 18, onlyMyDebuffs = true,
                                 threatGlow = true },   -- Threat Glow (Look)
                focustarget  = { mirror = true, enabled = true, width = 100, height = 25, powerHeight = 0, healthText = "none", powerText = "value", showLevel = false,
                                 texture = "FlareUI Dark", border = "FlareUI Thin" },
                pet          = { enabled = true, width = 120, height = 30, powerHeight = 8, healthText = "none", powerText = "value", showLevel = false,
                                 texture = "FlareUI Dark", border = "FlareUI Thin",
                                 absorbTexture = "FlareUI Striped",
                                 castbar = false, castbarPosition = "BOTTOM", castHeight = 12, castTexture = "FlareUI Dark", castBorderTexture = "FlareUI Thin", castIcon = true, castTimer = true,
                                 buffs = "OFF", debuffs = "OFF", auraSize = 12, hideBuffs = "OFF",
                                 threatGlow = true },   -- Threat Glow (Look; the styled pet only)
            },
        },

        -- [[ VISIBILITY (Show choices, fade groups, permanent hiding; part of the Action Bars module) ]]
        -- show: always | mouseover | combat | target | harm. A group (1-5) owns its members' show.
        visibility = {
            elements = VisibilityElements(),
            groups = { { show = "combat,mouseover" }, { show = "combat,mouseover" }, { show = "combat,mouseover" },
                       { show = "combat,mouseover" }, { show = "combat,mouseover" } },
            fadeSpeed = "instant",      -- instant | fast | slow (ns.FadeTime). Fade In / Hide Speed read this while
                                        -- their own fadeIn / fadeOut are unset: no defaults for those, AceDB would fill them
            hideBagBar = false,
            hideMicroMenu = false,
            hidePetBar = false,
            hideStanceBar = false,
            hidePossessBar = false,
            hideRaidManager = false,
            hideTotemBar = false,
            hideEndCaps = false,
            petFollowsPlayer = false,   -- Link Pet Frame: the pet frame fades with the player frame
        },

        -- [[ COOLDOWN MANAGER ]] Blizzard's Cooldown Manager (Modules/CooldownManager.lua), a module of its own
        cooldownmanager = {
            enabled = false,            -- the Cooldown Manager page's switch: everything below, and the viewers' Edit Mode rows
            skin = false,               -- Skin Cooldown Manager: FlareUI's look on the Tracked Bars and the icons
            softOverlay = false,        -- Soften Active Overlay: a faint swipe while an ability's effect runs
            effectCooldown = false,     -- Show Cooldown During Effect: the ability's own cooldown in the icon's corner
            -- Bar Colour (Pick Your Colours): palette "custom" with customColors.bar, else FlareUI's (CM.COLORS)
            -- size 0: Auto, the size Blizzard gave the text
            stackFont = { face = "__global", size = 0, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 },
            cooldownFont = { face = "__global", size = 0, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 },
            barFont = { face = "__global", size = 0, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 },
            keybinds = false,           -- Show Keybinds: the action button's key on the Essential and Utility icons
            keybindFont = { face = "__global", size = 0, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 },
            press = false,              -- Show Button Presses: an icon lights up while its spell's key is held
            -- Icon Shape in each icon viewer's Edit Mode dialog: blizzard | rect
            shape = { essential = "blizzard", utility = "blizzard", buffs = "blizzard" },
            -- Grow From in the Tracked Buffs' and Tracked Bars' Edit Mode dialogs: blizzard | CENTER | START | END
            grow = { buffs = "blizzard", bars = "blizzard" },
        },

        -- [[ AURAS MODULE ]] the player's buffs and debuffs (Modules/Auras.lua)
        auras = {
            enabled = false,
            style = "round",            -- square | round
            swipe = "both",             -- both (default) | icon (over the icon) | border (around the edge) | none
            timer = "below",            -- below (under the icon) | bottom (along its bottom edge)
            timerColor = true,          -- Timer Colour: yellow under 10 s, red under 5
            arrive = true,               -- new icons fade in while dropping into place
            sort = "applied", reverse = false, mineFirst = true,   -- Aura Ordering (both frames)
            hidden = {},                -- Hide Auras: [spellID] = the places it hides on, "auras,player,..." (ns.HiddenAuras)
            shown = {},                 -- Always Show: [spellID] = the places it always shows on, "player,target,..."
            -- Buff Reminders (BuffReminders.lua): your class's missing buffs; Group Buffs all / party / self,
            -- Icon Size, Remind Before It Ends in minutes, set in Edit Mode
            reminders = false,
            reminder = { group = "all", size = 36, before = 2, orientation = "HORIZONTAL", grow = "FORWARD",
                         blessing = "auto", consumables = "off", pets = true, thorns = "tank", camping = false, gathering = false,
                         food = true, flask = true, elixirSource = "ticked", elixirMode = "each",   -- Food, Flask, Elixirs to Watch / to Keep Up
                         weaponOil = false,   -- Weapon Oil / Stone
                         elixirs = "none", weaponScope = "always", petScope = "always", readyCheck = false,
                         classScope = "always", timeLeft = true,   -- Where > Class Buffs; Edit Mode > Alerts > Time Left
                         supplies = false, durability = false,   -- Low Supplies, Low Durability
                         trinkets = false, extras = "none", hideMounted = false, playstyle = "auto", soulstone = "healer",
                         hideTank = false, hideHealer = false, hideDamage = false, hideNoRole = false,
                         countText = "both", spacing = 6, alpha = 100,
                         -- Edit Mode > Fonts: the counts and the time left
                         countFont = { face = "__global", size = 11, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 }, timeFont = { face = "__global", size = 11, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 },
                         -- When It Shows, Alerts (the Buff Reminders tab)
                         showSolo = true, showParty = true, showRaid = true, hideRested = false, onlyProvider = false,
                         fadeSpeed = "instant",   -- Edit Mode's Fading section
                         sound = "off", glowMissing = false, glowExpiring = false,
                         layouts = {} },
            font = { face = "__global", size = 11, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 },
            -- stack counts; starts as a copy of the timer font (ns.SeedFont)
            countFont = { face = "__global", size = 11, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 },
            -- per frame, set in Edit Mode
            -- (font / countFont: each frame's own, set on the settings page's Fonts tab; first copied
            -- from the shared ones above)
            buffs   = { size = 30, perRow = 8, max = 16, spacing = 4,
                        grow = "LEFT", wrap = "DOWN",
                        font = { face = "__global", size = 11, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 }, countFont = { face = "__global", size = 11, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 } },
            debuffs = { size = 30, perRow = 8, max = 16, spacing = 4, grow = "LEFT", wrap = "UP",
                        font = { face = "__global", size = 11, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 }, countFont = { face = "__global", size = 11, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 } },
            layouts = {},
        },

        -- [[ TOOLTIPS MODULE ]]
        tooltips = {
            enabled = false,

            -- look
            scale = 1,
            cursorX = 0,                -- Offset X / Offset Y: a mouseover tooltip's distance from the pointer
            cursorY = 0,
            corner = "auto",            -- Tooltip Corner: auto (Blizzard's nearest corner) | TOPLEFT | TOPRIGHT | BOTTOMLEFT | BOTTOMRIGHT
            opacity = 1,                -- Frame Opacity: the background's
            borderByReaction = true,
            borderByClass = true,
            borderByQuality = true,
            hideHealthBar = true,
            healthBarPlace = "below",   -- Health Bar: "below" the tooltip or "inside" it
            -- fonts: Blizzard's tooltip fonts (GameTooltipHeaderText / GameTooltipText), shadow on
            titleFont   = { face = "__global", size = 14, flags = "NONE", enableShadow = true, shadowX = 1, shadowY = -1 },
            contentFont = { face = "__global", size = 12, flags = "NONE", enableShadow = true, shadowX = 1, shadowY = -1 },

            -- content
            nameColor = "class",          -- none | class
            showThreat = false,         -- Blizzard's threat line on enemy tooltips
            showTarget = false,
            showGuild = true,           -- Blizzard's guild line on players
            showPvP = true,             -- Show PvP: Blizzard's "PvP" line on flagged units
            showGuildRank = false,      -- Show Guild Ranks: the rank after the guild's name
            showFaction = true,         -- Show Faction: the Alliance or Horde line (was Hide Faction)
            shortItemStats = false,     -- "+12 Spell Power" for the long Equip: stat lines (ItemStats.lua)
            healingDamage = "off",      -- Healing & Damage: off | damage | power, for "healing … and damage …" lines
            itemLevel = false,          -- Show Item Level: weapons' and armour's level on their tooltip
            compareShift = false,       -- comparison tooltips only while Shift is held
            showItemID = false,
            showSpellID = false,

            -- anchor: default | cursorOffset (shown as "Cursor"); Blizzard's corner by default
            anchor = "default",
            anchorFrames = "default",
            -- anchorBars, anchorOther: unset follows anchorFrames (per kind of tooltip)
            anchorAuras = "default",        -- buff and debuff icons (Mouseover: at the pointer)
            anchorGroupAuras = "default",   -- party and raid tiles' aura icons
            -- Mouseover: the main switch; mouseoverKinds[kind] = an exception; the anchors above
            -- convert into these once (mouseoverSet), Tooltips.lua TIP.Mouseover
            mouseover = false,

            -- visibility: always | combat | never; every tooltip shows by default, as with Blizzard
            visibility = {
                worldUnits = "always",
                worldObjects = "always",
                frameUnits = "always",
                actionBars = "always",
                other = "always",       -- Everything Else
                auras = "always",       -- every buff and debuff icon's tooltip
                groupAuras = "always",  -- party and raid aura icons show their tooltip ("never" confuses: the icons then let the mouse through to the frame; PartyFrames.lua)
            },
        },

        -- [[ RADIAL MENU MODULE ]] radial contents are per character (db.global)
        radialmenu = {
            enabled = false,
            showNames = true,           -- button names on (Off saves false; buttonNames picks hover or always)
            buttonNames = "hover",      -- Button Names: hover | always (showNames false = Off)
            targetMouseover = "off",    -- Target Mouseover: off | on | shift | ctrl | alt
            position = "cursor",        -- cursor | center: where a mouse radial opens
            activation = "hold",        -- hold (release to use) | toggle (press to open, click to use)
            subRadials = "reset",       -- reset | remember: a sub-radial's button when the radial opens again
            scale = 1,                  -- Radial Scale: the whole radial's size
            -- Fonts tab: the hovered button's name and the counts (Blizzard's sizes by default)
            labelFont = { face = "__global", size = 16, flags = "NONE", enableShadow = true, shadowX = 1, shadowY = -1 },
            countFont = { face = "Arial Narrow", size = 14, flags = "OUTLINE", enableShadow = false, shadowX = 1, shadowY = -1 },
        },

        -- [[ QUEST TRACKER MODULE ]] minimized and collapsed state per character (CharDB().objectiveTracker)
        objectivetracker = {
            enabled = false,
            width = 250,
            maxHeight = 300,
            borderTexture = "FlareUI Frames",
            opacity = 0.75,
            minimizeStyle = "header",   -- "header": the header stays; "button": only a "+" button
            padBlizzard = false,        -- Gamepad UI: Blizzard's tracker instead of this one (reload)
            zoneHeaders = true,
            zoneFirst = true,           -- quests of the current zone first
            zoneOnly = false,           -- the header's Zone / All switch
            headerFilter = true,        -- Header Buttons: the filter (Zone / All) button
            headerSort = true,          -- Header Buttons: the sort button
            sortByDistance = true,
            sortByLevel = false,        -- the lowest level quest first (zones mixed, no zone headings)
            sortByProgress = false,     -- the furthest along first (zones mixed, no zone headings)
            anchor = "auto",            -- auto | TOP | BOTTOM (Edit Mode); left / right follows the frame's half
            questGap = 9,               -- pixels between quests (Edit Mode)
            hideLevel = false,
            colorNames = false,         -- quest names in their difficulty colour (not complete or focused ones)
            autoButtons = false,        -- Auto Quest Buttons: the header's "!" / "?" for Auto Accept / Turn-In Quests
            playButtons = false,        -- Quest Buttons > Voice Button: plays the quest's voice line, with the Spoken addon
            collapseCompleted = false,  -- finished and failed quests fold, unless a timer runs
            hideFinished = false,       -- finished objectives leave the list
            completedLast = false,
            focusedFirst = false,       -- Focused Quest First: the focused quest (and its zone) at the top
            keepFocus = false,          -- Keep Quest Focus: a newly accepted quest gives the focus back
            showTags = true,
            showRecipes = true,
            showCompleteTag = true,     -- Show Complete Tag: green title + "(Complete)" on finished quests
            frameStyle = "custom",      -- Frame Style: blizzard | flareui | custom (Modern; the default since 11-20, older setups keep FlareUI: Core.lua audit1120) (ObjectiveTracker.lua Build.FrameStyle)
            hideScrollBar = false,      -- Hide Scroll Bar (FlareUI and Custom styles): no thumb; the mouse wheel still scrolls
            questIcons = false,         -- Quest Buttons > Quest Icon: Blizzard's round quest button before each title; click focuses
            focusButtons = false,       -- Quest Buttons > Focus Button: a dot before each title; click focuses
            showUntracked = false,      -- Show Untracked Quests: with zone headings, this zone's untracked quests too (dimmed)
            -- on the way in, and open again on the way out: "minimize" or "none"
            autoMinimize = { dungeon = "none", raid = "none", pvp = "none", arena = "none", combat = "none", taxi = "none" },
            headerFont = { face = "__global", size = 12, flags = "NONE", enableShadow = true, shadowX = 1, shadowY = -1 },
            titleFont = { face = "__global", size = 11, flags = "NONE", enableShadow = true, shadowX = 1, shadowY = -1 },
            objectiveFont = { face = "__global", size = 10, flags = "NONE", enableShadow = true, shadowX = 1, shadowY = -1 },
            layouts = {},
        },

        -- [[ NAMEPLATES MODULE ]] (Modules/Nameplates.lua): FlareUI's own plates (enemy and friendly); a reload turns it on or off
        nameplates = {
            enabled = false,
            width = 160, height = 16,   -- the health bar (tall enough for the name inside it)
            texture = "FlareUI Light", -- Bar Texture (the unit frames' list)
            border = "FlareUI Thick",   -- Border: "FlareUI Thick", "FlareUI Frames" (shown as FlareUI Thin), Shared Media, "None"
            bgOpacity = 90,             -- the bar's background, in percent (the unit frames' value)
            -- Bar Effects (the unit frames' three, all off): Animations (health glides), Edge Glow, Damage Trail
            smoothBars = false, edgeGlow = false, damageTrail = false,
            targetScale = 1.2,         -- your target's plate grows this much (the game's own zoom is set to 1: NP.PinZoom)
            healthColor = "class",      -- Health Colour: off (Blizzard's) | reaction | class (Class & Reaction) | health
            threat = "groups",          -- Threat Colours: off | groups | always
            role = "auto",              -- Role: auto | tank | damage
            -- Phase 2 (all off): mob type colours (instances only unless "everywhere"), focus, group members
            colorBoss = false, colorElite = false, colorCaster = false, colorTrivial = false, mobTypesWhere = "instances",
            colorFocus = false, groupColor = false,
            execute = "off",            -- Execute Range: off | auto | 20 | 25 | 30 | 35
            threatScale = false,        -- Threat Scale (tanks): lost mobs grow, held ones shrink a little
            nameOnlySize = 100,         -- Name Only Size (per type): the name on a Name Only plate, in % of the Names font
            combatPlates = "none",      -- Show Plates in Combat (Name Only Mode): types that leave Name Only in a fight
            threatPercent = false,      -- Threat Percentage: your threat % in the bar's middle, coloured as the unit frames' Threat Text
            peacefulNames = false,      -- Name Only While Unattackable: enemy NPCs you can't attack show only their name
            enemyPlayers = true, enemyNpcs = true,   -- Enemy Types: FlareUI's plates for enemy players / NPCs
            kickReady = false,          -- Kick Ready: interruptible casts in their own colour while your interrupt is ready
            rangeAlpha = 0.8,           -- Out of Range Opacity (1 = off)
            -- Targeting: size and opacity with no target, on your target, and on the others while you have one
            noTargetScale = 1, noTargetAlpha = 1, targetAlpha = 1, notTargetScale = 0.8,
            nonTargetAlpha = 1,         -- Not Targeted opacity (1 = off)
            -- Target Highlight: border in the target colour (on), bar tint, outer glow, arrows (off)
            targetBorder = true, targetBarColor = true, targetGlow = false,
            targetArrows = "off",       -- off | npe | npeGlow | chevron | hook | big | red (Blizzard's art)
            targetArrowSide = "both",   -- both | left | right | top
            castKickMark = false,       -- Kick Ready Mark: where on the cast your interrupt will be ready
            clampTarget = true,         -- Keep Target on Screen (the game's own setting, set while on)
            -- obscuredAlpha = 0.4 once picked: Out of Sight opacity (the game's own; untouched until then)
            plate = "bar",              -- Plate: blizzard | bar | name (Name Only) | hidden; per type below
            rarityIcon = true,          -- Rarity Icon: the gold elite / silver rare dragon on the bar's end
            castTargetedFlash = false, threatGlow = false, aggroFlash = false,
            defensives = false,         -- Defensives row (big and external defensives), left of the plate
            clickThrough = false,       -- Click-Through (per type)
            -- Plate types (Nameplates.lua C.TYPE_KEYS): types[kind] = { preset = full | compact | tiny |
            -- name | custom, custom = { the type's own values } }; presets are C.PRESETS over the values
            -- here (Enemy Player / NPC Full, Friendly Player / NPC Name Only, Minor Full: C.DEFAULT_PRESET)
            types = {},
            -- palette = "custom" + customColors = { [key] = { r, g, b } } once picked (Pick Your Colours)
            level = "box",              -- Level: off | box | disc | name (Follow Name)
            levelSide = "left",         -- Level Side (box and discs): left | right
            hideTextAtFull = false,     -- Hide Health Text at Full
            -- barText.health = { left = { firstname = 1 }, middle = {}, right = Blizzard's default } once picked (BarText.lua slots)
            castbar = true, castHeight = 10, castIcon = true, castTimer = true, castTarget = true, castImportant = true,
            debuffs = "mine",           -- Debuffs: off | all, or toggles "mine,dispel" (Only Mine, Only Dispellable)
            debuffSize = 20, debuffMax = 6,
            buffs = "purge",            -- Buffs: off | all, or toggles "purge,important,mine"
            hideBuffs = "OFF",          -- Hide Buffs: OFF | PERMANENT | longest full duration in seconds (as the unit frames)
            buffSize = 16, buffMax = 3,
            cc = true, ccSize = 28,     -- Crowd Control: one big icon right of the bar
            -- Auras (per type, the unit frames' four): Aura Icon Shape square | round, Aura Swipe none |
            -- icon | border | both, Aura Timer none | below | bottom | middle, Timer Colour
            auraStyle = "square", auraSwipe = "both", auraTimer = "none", auraTimerColor = true,
            auraRows = "one",           -- Aura Positions (per type, both rows on): one | buffsTop | debuffsTop
            -- nameAbove = "<left|middle|right>:<firstname|fullname>" once picked: Names Above Plate (per type)
            nameOnlyFull = true,        -- Show Full Name (per type): a Name Only plate's player surnames
            nameFont = { face = "__global", size = 11, flags = "OUTLINE", enableShadow = false, shadowX = 1, shadowY = -1 },
            healthFont = { face = "__global", size = 9, flags = "OUTLINE", enableShadow = false, shadowX = 1, shadowY = -1 },
            levelFont = { face = "__global", size = 10, flags = "OUTLINE", enableShadow = false, shadowX = 1, shadowY = -1 },
            castFont = { face = "__global", size = 9, flags = "NONE", enableShadow = true, shadowX = 1, shadowY = -1 },
        },

        -- [[ TWEAKS MODULE ]]
        tweaks = {
            acceptSummon = false,       -- Accept Summons: taken after 10 seconds unless cancelled
            combatFriendly = false,     -- Combat Friendly Plates: friendly players' plates only in a fight
            craftTotal = false,         -- Craft Batch Time: the batch's time left after the cast bar's timer
            enabled = false,
            moveAnyFrame = true,        -- drag any Blizzard panel by its header; positions in frames{}
            way = false,                -- /way map pins
            syncUI = false,             -- account-wide copy of character-specific Blizzard settings
            sellJunk = false,
            autoRepair = false,
            maxCameraZoom = false,      -- Better Camera's old switch: on becomes cameraMaxZoom 2.6 (Tweaks.lua ApplyCamera)
            fasterCameraZoom = false,   -- ...and cameraZoomSpeed 50. The two sliders have no default: nil = Blizzard's own
            fasterLoot = false,
            lootFeed = false,           -- Loot Feed: what you loot floats up beside you (LootFeed.lua)
            lootFeedQuality = 0,        -- items below this quality are left out (0 = Poor: all)
            lootFeedMoney = true,       -- money too
            lootFeedPosition = "cursor", -- cursor (starts at the pointer) | placed (the Edit Mode spot)
            lootFeedAlign = "center",   -- Alignment: left | center (the default) | right (icon on the right, text before it)
            lootFeedSkills = false,     -- skill-ups too ("Mining 76")
            lootFeedFont = { face = "__global", size = 14, flags = "OUTLINE", enableShadow = false, shadowX = 1, shadowY = -1 },
            zoneTextFont = { face = "" },  -- Zone Text font (ZoneText.lua): "" keeps Blizzard's; face only
            nameplateCombo = false,     -- classic combo point gems under the target's nameplate
            nameplateQuest = false,     -- quest badge on enemy nameplates that belong to an active quest
            nameplateHideLevel = false, -- Blizzard's level box on the right of nameplates hidden
            nameplateHideNames = false, -- unit names on Blizzard's nameplates hidden
            nameplateLevelName = false, -- with the level box hidden: the level before the plate's name
            -- Bags & Looting (its own module, Settings/Pages/BagsLooting.lua): its switch
            -- (ns.BagModuleOn); all off leaves Blizzard's bag windows alone
            bagModule = false,
            bagColumns = 0,             -- combined backpack columns; 0 = Blizzard's (10)
            bagGaps = false,            -- each bag starts a new row, with a gap
            bagButtons = false,         -- bag slot buttons down the combined backpack's side
            bagKeyring = false,         -- Keyring in Backpack: the keyring as a section of the combined backpack
            bagReagent = false,         -- Crafting Bag in Backpack: the crafting (reagent) bag there too
            bagCombineEmpty = false,    -- Combine Empty Slots: one empty slot with the free count
            bagReverse = false,         -- Reverse Bag Fill: the grid from the top left
            bagAutoOpen = false,        -- Auto Open Containers: clams, loot bags, opened lockboxes
            bankColumns = 0,            -- Bank Window Columns; 0 = Blizzard's (8) (Bags.lua 4e)
            bankGaps = false,           -- Bank Window: each bank bag starts a new row, with a gap
            bankTight = false,          -- Bank Window: slots 5 apart, as in the backpack, not Blizzard's 13/10
            bagView = "all",            -- Bag View: "all" | "filters" (Category Filters, Bags.lua 4b) | "rows" | "rowsSets" (Category Rows, + a row per equipment set; Bags.lua 1)
            bagWithCharacter = false,   -- Open with Character Window: the bags open and close with it (Bags.lua 4c)
            bagAutoSort = false,        -- Sort Bags on Open: Blizzard's clean-up each time the bags open (Bags.lua 4d)
            -- Bag Items font (Bags.lua StyleIconTexts): stack counts and cooldown numbers; face "" keeps Blizzard's
            bagItemFont = { face = "", size = 14, flags = "OUTLINE", enableShadow = false, shadowX = 1, shadowY = -1 },
            -- Free Bag Slots font: the count on the backpack button; face "" keeps Blizzard's
            bagItemLevelFont = { face = "", size = 12, flags = "OUTLINE", enableShadow = false, shadowX = 1, shadowY = -1 },   -- Item Level's numbers (bags and character sheet)
            bagFreeSlotsFont = { face = "", size = 16, flags = "OUTLINE", enableShadow = false, shadowX = 1, shadowY = -1 },
            -- the gold, silver and copper at the bags' foot: "" keeps Blizzard's font
            bagMoneyFont = { face = "", size = 14, flags = "OUTLINE", enableShadow = false, shadowX = 1, shadowY = -1 },
            bagSkinSlots = true,        -- Skin Item Slots: FlareUI's border on the slots (off: Blizzard's own, for bag skins)
            bagThickBorders = false,    -- Skin Item Slots' Thick Borders (else Thin); quality colours always on
            bagJunkIcon = false,        -- the junk coin on grey items always, not only at a vendor
            bagItemLevel = false,       -- Item Level: weapons' and armour's level, bottom left
            bagUncollected = false,     -- Uncollected Appearance: an eye, top right
            bagBoE = false,             -- BoE Text: "BoE" top left on items that bind when equipped, until bound
            bagPlainEmpty = false,      -- Plain Empty Slots: one plain look for every empty slot, not its bag's picture
            hideErrors = false,
            hideZoneText = false,
            hidePortraitNumbers = false,
            mailBook = false,           -- Mail Address Book: own characters beside Send Mail's "To:"
            merchantKnown = false,      -- Gray Out Known Items: known items greyed out at merchants
            bulkBuy = false,            -- Enhanced Vendor Purchases: Shift+click buys many stacks, Stack and MAX buttons
            acceptRes = false,          -- Accept Resurrections: out of combat
            repairGuild = false,        -- Repair with Guild Funds: Auto Repair uses the guild bank first
            merchantWide = false,       -- Wider Vendor Window: 20 items a page
            petFood = false,            -- Pet Food in Bags: a paw on food the hunter pet eats
            skipLootConfirm = false,    -- Skip Loot Confirmations: bind-on-loot and roll dialogs
            lootRollsOpacity = 1,       -- its Frame Opacity: the background's (100% by default: 60% is hard to read)
            lootRolls = false,          -- Loot Roll Window: FlareUI's loot roll window in place of Blizzard's roll frames (LootRolls.lua); on and off need a reload
            lootRollFont = { face = "__global", size = 12, flags = "NONE", enableShadow = true, shadowX = 1, shadowY = -1 },   -- Fonts > Loot Rolls: the item names; the small lines two smaller
            alertSounds = false,        -- Alert Sounds: taskbar flash + Master-channel sound
            gamepadPrompt = false,      -- Gamepad mode prompt: offer Blizzard's Gamepad UI on a controller press
            rumbleAlerts = false,       -- Rumble on alerts: the controller rumbles for ready checks, queue invites ...
            rumbleProcs = false,        -- Rumble on procs: a short rumble when a spell lights up
            mapFade = false,            -- Fade Map While Moving: Blizzard's mapFade CVar
            zoneLevels = false,         -- Zone Levels on the World Map: a zone's level range under its name
            keyDown = false,            -- Cast on Key Press: Blizzard's ActionButtonUseKeyDown CVar
            skipGossip = false,         -- Skip Gossip: a lone banker / vendor / trainer... option is picked at once (Tweaks.lua GOSSIP_SHOW)
            deleteJunkWhenFull = false, -- Delete Junk When Full: bags full, a loot click deletes the cheapest grey item first (JunkDelete.lua)
            taxiMap = false,            -- Open Flight Map at Once: a flight master with no quests skips its talk
            fishCast = false,           -- Double-click to fish: a second right-click casts with a pole in hand
            fishSound = false,          -- Fishing sounds: music and ambience down, effects up while fishing
            combatPlates = false,       -- Enemy Nameplates in Combat Only
            hideTips = false,
            hideLootAlerts = false,     -- Hide Clutter > Loot Alerts: Blizzard's loot / upgrade / money pop-ups (Tweaks.lua)
            autoDelete = false,         -- DELETE typed into the destroy-item confirmation
            autoAcceptQuests = false,   -- Auto accept quests
            autoTurnInQuests = false,   -- Auto turn-in quests
            trainAll = false,           -- Train All button at trainers
            moveLootToasts = true,      -- FlareUI Loot Rolls / FlareUI Toasts in Edit Mode (Modules/Movers.lua); positions in moverLayouts{}
            frames = {},
        },
    },
    -- account-wide, untouched by profile switching
    global = {},
}

--------------------------------------------------
-- 5. SHARED UTILITIES
--------------------------------------------------
-- Caught errors: the last 20 are kept (account-wide) for bug reports, shown with /fui errors. Nothing
-- is printed when one is caught.
-- Edit Mode's settings dialogs open where the player last dragged one, account-wide
-- (Libs/FlareEditMode/widgets/extension.lua PlaceSaved; global.editDialogPos)
LibStub("FlareEditMode").GetDialogStore = function() return ns.db and ns.db.global end

ns.ERRORS_KEPT = 20
function ns.LogError(where, err)
    local global = ns.db and ns.db.global
    if not global or err == nil then return end
    global.errors = global.errors or {}
    local list = global.errors
    local version = C_AddOns.GetAddOnMetadata("FlareUI", "Version") or "?"
    local build = select(2, GetBuildInfo()) or "?"
    local text = tostring(err):gsub("[\r\n]+", " ")
    list[#list + 1] = ("%s | %s | %s | %s | %s"):format(date("%Y-%m-%d %H:%M"), version, build, where, text)
    while #list > ns.ERRORS_KEPT do table.remove(list, 1) end
end

-- pcall that keeps what failed in the log (no table per call; trailing nil results survive)
local function LoggedResult(where, ok, ...)
    if not ok then ns.LogError(where, (...)) end
    return ok, ...
end
function ns.SafeCall(where, fn, ...)
    return LoggedResult(where, pcall(fn, ...))
end

-- /fui errors: the log in a window to copy from; /fui errors clear empties it
function ns.ErrorsCommand(args)
    local global = ns.db and ns.db.global
    if not global then return end
    if args == "clear" then
        global.errors = nil
        print("|cff33ff99FlareUI:|r " .. L["Error log cleared."])
        return
    end
    local list = global.errors
    if not list or #list == 0 then
        print("|cff33ff99FlareUI:|r " .. L["No errors caught."])
        return
    end
    local _, class = UnitClass("player")
    local head = ("FlareUI %s | build %s | %s | %s %d"):format(C_AddOns.GetAddOnMetadata("FlareUI", "Version") or "?",
        select(2, GetBuildInfo()) or "?", GetLocale(), class or "?", UnitLevel("player") or 0)
    ns.Perf.ShowText(L["FlareUI caught errors"], head .. "\n\n" .. table.concat(list, "\n"))
end
-- Buff and debuff timers read s, m, h and d in every language; Blizzard's own units follow the client's
-- ("min" in some). The same bands as Blizzard's: a unit runs to 1.5 of the next one, rounded up.
local AURA_TIME_BANDS = {
    { from = 129600, div = 86400, unit = "d" },
    { from = 5401, div = 3600, unit = "h" },
    { from = 91, div = 60, unit = "m" },
    { from = 0, div = 1, unit = "s" },
}

-- Bags & Looting's switch. Until it is set, it follows Quality of Life's, where these options lived:
-- once per profile (bagModuleSeeded). (11-22) Switched off it is saved as false, the default, which the
-- saved settings drop at logout: read as unset, it copied Quality of Life's switch again at every
-- login and came back on by itself.
function ns.BagModuleOn()
    local tweaks = ns.db and ns.db.profile and ns.db.profile.tweaks
    if not tweaks then return false end
    if not rawget(tweaks, "bagModuleSeeded") then
        if rawget(tweaks, "bagModule") == nil then tweaks.bagModule = rawget(tweaks, "enabled") == true end
        tweaks.bagModuleSeeded = true
    end
    return tweaks.bagModule == true
end

-- CAST BAR EDGE GLOW (11-22, Malkkav, Kelvan's idea): Blizzard's bright edge at the cast's front, on
-- every cast bar (each frame's Cast Bar section; the Player Cast Bar's Look). On for new players only:
-- decided once per profile (castGlowNew), on when FlareUI has never shown its What's New (a fresh
-- install), so existing players' cast bars stay as they were. Each bar's own switch (castGlow), never
-- set, reads this.
function ns.CastGlowDefault()
    local profile = ns.db and ns.db.profile
    if not profile then return false end
    local v = rawget(profile, "castGlowNew")
    if v == nil then
        local global = ns.db.global
        v = not (global and global.whatsNewSeen)
        profile.castGlowNew = v
    end
    return v
end
function ns.CastGlowOn(v)
    if v == nil then return ns.CastGlowDefault() end
    return v and true or false
end

-- For a time Lua can read (weapon enchants)
function ns.FormatAuraTime(seconds)
    for _, band in ipairs(AURA_TIME_BANDS) do
        if seconds >= band.from then return math.ceil(seconds / band.div) .. band.unit end
    end
end

-- SetDurationText's options. Aura times can be secret, so the client does the formatting, from these
-- rules; checked once, and if the client answers otherwise its own formatter stays.
local auraTimerOptions
local function AuraTimerOptions()
    if auraTimerOptions then return auraTimerOptions end
    auraTimerOptions = {}
    local ok, formatter = pcall(C_StringUtil.CreateNumericRuleFormatter)
    if not (ok and formatter) then return auraTimerOptions end
    local up = Enum.NumericRuleFormatRounding and Enum.NumericRuleFormatRounding.Up
    local rules = {}
    for i = #AURA_TIME_BANDS, 1, -1 do
        local band = AURA_TIME_BANDS[i]
        rules[#rules + 1] = { threshold = band.from, format = "%.0f" .. band.unit,
            components = { { div = band.div, step = 1, rounding = up } } }
    end
    if not pcall(formatter.SetBreakpoints, formatter, rules) then return auraTimerOptions end
    for seconds, text in pairs({ [30] = "30s", [300] = "5m", [7200] = "2h" }) do
        local okText, shown = pcall(formatter.FormatNumber, formatter, seconds)
        if not okText or shown ~= text then return auraTimerOptions end
    end
    auraTimerOptions.textFormatter = formatter
    return auraTimerOptions
end

-- Timer colour by time left: the client colours the text from a step curve on the time remaining
-- (secret-safe): red under 5 seconds, yellow under 10, white above. false when the client lacks it.
local auraTimerColorOptions
local function AuraTimerColorOptions()
    if auraTimerColorOptions ~= nil then return auraTimerColorOptions end
    auraTimerColorOptions = false
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and Enum.DurationTextBindingProperty) then return false end
    local ok, curve = pcall(C_CurveUtil.CreateColorCurve)
    if not (ok and curve) then return false end
    if Enum.LuaCurveType then pcall(curve.SetType, curve, Enum.LuaCurveType.Step) end
    for _, point in ipairs({ { 0, 1, 0.25, 0.2 }, { 5, 1, 0.82, 0 }, { 10, 1, 1, 1 } }) do
        if not pcall(curve.AddPoint, curve, point[1], CreateColor(point[2], point[3], point[4])) then return false end
    end
    local options = {}
    for k, v in pairs(AuraTimerOptions()) do options[k] = v end
    options.textColor = { curve = curve, property = Enum.DurationTextBindingProperty.RemainingDuration }
    auraTimerColorOptions = options
    return options
end

-- Hands an aura button its timer text. colorByTime: the timer colour follows the time left.
function ns.SetAuraDurationText(button, fontString, colorByTime)
    local colored = colorByTime and AuraTimerColorOptions()
    if colored and pcall(button.SetDurationText, button, fontString, colored) then return end
    if not pcall(button.SetDurationText, button, fontString, AuraTimerOptions()) then
        pcall(button.SetDurationText, button, fontString, {})
    end
    -- turned off: the text keeps the curve's last colour otherwise
    pcall(fontString.SetTextColor, fontString, 1, 1, 1)
end

-- GameTooltip's health bar only hides on close, so a tooltip reused without closing keeps it. Hidden
-- on every clear; a unit tooltip re-shows it as it builds. Hide only: writing to the bar taints.
if GameTooltip and GameTooltip.StatusBar then
    GameTooltip:HookScript("OnTooltipCleared", function(tooltip)
        if tooltip.StatusBar then tooltip.StatusBar:Hide() end
    end)
end

-- FlareUI's aura icons (Blizzard's aura containers draw them): "solo" or "group", for Tooltips'
-- Mouseover on Buffs/Debuffs and Party/Raid Auras (Tooltips.lua). Only noted here, never written on
-- the buttons, which show their tooltips through Blizzard's own code.
ns.auraTipKind = setmetatable({}, { __mode = "k" })
function ns.MarkAuraTooltip(button, kind)
    if button then ns.auraTipKind[button] = kind end
end

-- GameTooltip for FlareUI's own buttons. Another owner's tooltip is hidden first: Blizzard clears its
-- health, money and progress bars only in OnHide.
function ns.OwnGameTooltip(owner, anchor)
    if GameTooltip:IsShown() and not GameTooltip:IsOwned(owner) then GameTooltip:Hide() end
    GameTooltip:SetOwner(owner, anchor)
    -- a unit tooltip hidden mid-build can leave its health bar flagged shown
    if GameTooltip.StatusBar then GameTooltip.StatusBar:Hide() end
end

-- Edge size for a border file: FlareUI Thin is drawn at half size
function ns.BorderEdgeSize(edgeFile, size)
    size = size or 16
    if type(edgeFile) == "string" and edgeFile:find("FlareUI%-Thin%.tga") then return size / 2 end
    return size
end

-- (11-22, Aleksandr Vasinskyi) Blizzard's Latin-only fonts have Cyrillic twins: the same Latin letters
-- plus Russian. The game draws a whole string with one font, so a meter row like "1. Имя" (a Russian
-- name on an English client) took the Latin-only font and drew boxes; the twin draws both. Only where
-- the client has the file. (7.0.3 swapped every font: the twin looks crisper and has no "·", so
-- tooltips drew boxes and every text changed. 7.0.4: only the meter's rows use it, DamageMeter.lua)
ns.CYRILLIC_TWINS = {
    ["fonts\\frizqt__.ttf"] = "Fonts\\FRIZQT___CYR.TTF",
    ["fonts\\morpheus.ttf"] = "Fonts\\MORPHEUS_CYR.TTF",
    ["fonts\\skurri.ttf"] = "Fonts\\SKURRI_CYR.TTF",
}
function ns.CyrillicTwin(path)
    if type(path) ~= "string" then return path end
    local twin = ns.CYRILLIC_TWINS[path:lower():gsub("/", "\\")]
    if twin and C_UIFileAsset and C_UIFileAsset.IsKnownFile and C_UIFileAsset.IsKnownFile(twin) then return twin end
    return path
end

-- The client's own font for this language: always loaded, and it has the language's letters
local function BaseFont()
    return _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

-- Global Font: a font whose face is ns.GLOBAL_FONT uses the profile's Global Font. Every
-- font reads its face through ns.GetFontPath, so this one value changes all of them.
ns.GLOBAL_FONT = "__global"
function ns.GlobalFontFace()
    local fonts = ns.db and ns.db.profile and ns.db.profile.fonts
    local face = fonts and fonts.global and fonts.global.face
    if type(face) ~= "string" or face == "" or face == ns.GLOBAL_FONT then return "Friz Quadrata TT" end
    return face
end

-- Font path from LibSharedMedia, the client's own font when the name or file is unknown.
-- A known file need not be loaded yet: use ns.SetFont, which waits for it.
-- Only found paths are remembered (a name not registered yet may be later); a registered name keeps its
-- file, but LSM's global override changes every answer, so its callbacks forget them all.
do
    local foundPaths, listening = {}, false
    local function Forget() wipe(foundPaths) end

    function ns.GetFontPath(face)
        -- Global: the Global Font's face (Settings page > Fonts)
        if face == ns.GLOBAL_FONT then face = ns.GlobalFontFace() end
        local path = face ~= nil and foundPaths[face]
        if path then return path end
        local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
        if LSM then
            if not listening and LSM.RegisterCallback then
                listening = true
                LSM.RegisterCallback(foundPaths, "LibSharedMedia_SetGlobal", Forget)
                LSM.RegisterCallback(foundPaths, "LibSharedMedia_Registered", Forget)
            end
            local success, found = pcall(LSM.Fetch, LSM, "font", face, true)
            if success and found and C_UIFileAsset.IsKnownFile(found) then
                if face ~= nil then foundPaths[face] = found end
                return found
            end
        end
        return BaseFont()
    end
end

-- Most font files load only when a drawn font string asks for them. Until then SetFont answers false
-- and reads back the old font (a new font string has none, and any text on it throws), and the string
-- switches once the file is in. So a string gets the base font at the right size and asks again until
-- the client says yes. A blank or hidden string's request doesn't load the file: never test a font on one.
-- REDRAW (11-20, every font option at once; Ciron's blank Info Bar, TheHusky's blank keybinds): text
-- drawn before its font file loaded can stay blank after the file is in, and the same font set again
-- does nothing. A size change and back draws it anew. So every string styled here (and every font
-- object) is remembered, and redrawn: the moment its file answers yes, and 2 and 10 s after each
-- loading screen (a string the client said yes to at once can still have been drawn blank).
-- Strings and objects are weak keys: nothing is kept alive. Fields, not file-scope locals.
ns.FontRedraw = {
    strings = setmetatable({}, { __mode = "k" }),   -- font string -> { path, size, flags }
    objects = setmetatable({}, { __mode = "k" }),   -- font object -> { path, size, flags }
    AFTER_LOAD = { 2, 10 },
    NEW_FAMILY = { 0.5, 2, 5 },
    -- the game's own files, in from the start (memory: font-loading-research): never redrawn
    ALWAYS_IN = { ["fonts\\frizqt__.ttf"] = true, ["fonts\\frizqt___cyr.ttf"] = true, ["fonts\\arialn.ttf"] = true,
                  ["fonts\\arkai_t.ttf"] = true, ["fonts\\2002.ttf"] = true, ["fonts\\2002b.ttf"] = true },
    SLOW_SECONDS = 5, SLOW_TICKS = 60,              -- after the fast retries: every 5 s for 5 minutes
}
do
    local R = ns.FontRedraw
    -- whether a font file needs the redraws (a game file never does)
    function R.Wanted(path)
        return type(path) == "string" and not R.ALWAYS_IN[path:lower():gsub("/", "\\")]
    end
    -- only while it still holds the font asked for (another setter since then: left alone)
    function R.String(fontString, want)
        local _, size = fontString:GetFont()
        if not (size and math.abs(size - want.size) < 0.05) then return end
        fontString:SetFont(want.path, want.size + 1, want.flags)
        fontString:SetFont(want.path, want.size, want.flags)
    end
    -- (want.redraw: an object that redraws its own way, the chat windows)
    function R.Object(fontObject, want)
        if want.family then return R.Family(fontObject, want) end
        local _, size = fontObject:GetFont()
        if not (size and math.abs(size - want.size) < 0.05) then return end
        if want.redraw then return want.redraw(fontObject, want) end
        fontObject:SetFont(want.path, want.size + 1, want.flags)
        fontObject:SetFont(want.path, want.size, want.flags)
    end
    -- a font family (ns.SetFontFamily: the unit frames, meters, loot rolls...): member by member,
    -- each at its own file; every string using the family follows
    function R.Family(family, want)
        if not family.GetFontObjectForAlphabet then return end
        for _, alphabet in ipairs(ns.FontFamily.alphabets) do
            local ok, member = pcall(family.GetFontObjectForAlphabet, family, alphabet)
            local file = ok and member and member.GetFont and member:GetFont()
            if file and R.Wanted(file) then
                member:SetFont(file, want.size + 1, want.flags)
                member:SetFont(file, want.size, want.flags)
            end
        end
    end
    function R.All()
        for fontString, want in pairs(R.strings) do R.String(fontString, want) end
        for fontObject, want in pairs(R.objects) do R.Object(fontObject, want) end
    end
    local watch = CreateFrame("Frame")
    watch:RegisterEvent("PLAYER_ENTERING_WORLD")
    watch:SetScript("OnEvent", function()
        for _, delay in ipairs(R.AFTER_LOAD) do C_Timer.After(delay, R.All) end
    end)
end

local RETRY_SECONDS, RETRY_TICKS = 0.5, 60
local pendingFonts = setmetatable({}, { __mode = "k" })   -- font string -> what it's waiting for
local retryTicker, retryTicks

local function RetryFonts()
    retryTicks = retryTicks + 1
    for fontString, want in pairs(pendingFonts) do
        if fontString:SetFont(want.path, want.size, want.flags) ~= false then
            pendingFonts[fontString] = nil
            if ns.FontRedraw then ns.FontRedraw.String(fontString, want) end   -- the file is in: draw the text anew
        end
    end
    local R = ns.FontRedraw or { SLOW_TICKS = 0, SLOW_SECONDS = 5 }
    if not next(pendingFonts) or retryTicks >= RETRY_TICKS + R.SLOW_TICKS then
        wipe(pendingFonts)   -- never loaded: the base font stays until the next refresh asks again
        retryTicker:Cancel()
        retryTicker = nil
    elseif retryTicks == RETRY_TICKS then
        -- not in yet (a hidden string's request loads nothing): keep asking, slower
        retryTicker:Cancel()
        retryTicker = C_Timer.NewTicker(R.SLOW_SECONDS, RetryFonts)
    end
end

-- Text Scale (Settings page, account-wide): every FlareUI font size times this, set as FlareUI
-- loads (a change reloads). 1 leaves every size as it is. The settings window keeps its own sizes
-- (ns.SetFontUnscaled): its layout is fixed.
ns.TEXT_SCALE = 1

local function SetFontRaw(fontString, path, size, flags)
    pendingFonts[fontString] = nil
    -- remembered for the redraws (the base font is always in: nothing to redraw)
    local R = ns.FontRedraw
    if R and size and path ~= BaseFont() and R.Wanted(path) then
        R.strings[fontString] = { path = path, size = size, flags = flags or "" }
    elseif R then
        R.strings[fontString] = nil
    end
    if fontString:SetFont(path, size, flags) ~= false then return end
    fontString:SetFont(BaseFont(), size, flags)
    fontString:SetFont(path, size, flags)
    pendingFonts[fontString] = { path = path, size = size, flags = flags }
    retryTicks = 0
    retryTicker = retryTicker or C_Timer.NewTicker(RETRY_SECONDS, RetryFonts)
end

-- FlareUI in Russian, Korean or Chinese on a client of another language (boxes in place of
-- letters): the client's usual font may lack the selected language's alphabet, so every FlareUI font
-- goes through a family (ns.SetFontFamily), whose matching Blizzard member has the letters. Decided
-- once the locale files have loaded; same-language clients already have the selected alphabet.
local FONT_FAMILY_LOCALES = { koKR = true, ruRU = true, zhCN = true, zhTW = true }
function ns.FontFamiliesAlways()
    if ns.fontFamiliesAlways == nil and ns.LoadedLocale then
        local selectedLocale = ns.LoadedLocale()
        ns.fontFamiliesAlways = (FONT_FAMILY_LOCALES[selectedLocale] and selectedLocale ~= GetLocale()) or false
    end
    return ns.fontFamiliesAlways
end

function ns.SetFont(fontString, path, size, flags)
    if ns.FontFamiliesAlways() and CreateFontFamily and fontString.SetFontObject and path and size then
        return ns.SetFontFamily(fontString, path, size, flags)
    end
    if size and ns.TEXT_SCALE ~= 1 then size = size * ns.TEXT_SCALE end
    return SetFontRaw(fontString, path, size, flags)
end
ns.SetFontUnscaled = SetFontRaw

-- Font families for text other players write (names, meter rows, tooltips). The game draws a whole
-- string with one member of a family, picked by its letters: the chosen font for Latin text, and for
-- Russian, Korean or Chinese a font that has those letters. A plain SetFont keeps only the chosen
-- file, which on an English client draws Cyrillic and Chinese / Korean as boxes. Table fields, not
-- file-scope locals.
ns.FontFamily = {
    alphabets = { "roman", "russian", "korean", "simplifiedchinese", "traditionalchinese" },
    -- Blizzard's own face for each alphabet, as its font families have it
    stock = { russian = "Fonts\\FRIZQT___CYR.TTF", korean = "Fonts\\2002.TTF",
              simplifiedchinese = "Fonts\\ARKai_T.ttf", traditionalchinese = "Fonts\\blei00d.TTF" },
    -- the client's own alphabet takes the chosen font (on that client it has those letters)
    clientAlphabet = ({ koKR = "korean", zhCN = "simplifiedchinese", zhTW = "traditionalchinese", ruRU = "russian" })[GetLocale()],
    -- files that draw the Russian alphabet (lower case); FlareUI's own register theirs (Media.lua)
    cyrillic = { ["fonts\\frizqt___cyr.ttf"] = true, ["fonts\\arialn.ttf"] = true,
                 ["fonts\\morpheus_cyr.ttf"] = true, ["fonts\\skurri_cyr.ttf"] = true },
    built = {},
    count = 0,
}

function ns.FontHasCyrillic(path)
    return type(path) == "string" and ns.FontFamily.cyrillic[path:lower():gsub("/", "\\")] == true
end

-- whether an alphabet's member takes the chosen file, or keeps Blizzard's face
local function MemberTakesPath(alphabet, path)
    local F = ns.FontFamily
    return alphabet == "roman" or alphabet == F.clientAlphabet or (alphabet == "russian" and ns.FontHasCyrillic(path))
end

-- A string's font as a family. A string takes its family from its first font write: a plain SetFont
-- would fix its face for good. Falls back to ns.SetFont where families can't be made.
function ns.SetFontFamily(fontString, path, size, flags)
    local F = ns.FontFamily
    flags = flags or ""
    if not (CreateFontFamily and fontString.SetFontObject and path and size) then
        return ns.SetFont(fontString, path, size, flags)
    end
    if ns.TEXT_SCALE ~= 1 then size = size * ns.TEXT_SCALE end
    local key = path .. "|" .. size .. "|" .. flags
    local family = F.built[key]
    if not family then
        local members = {}
        for _, alphabet in ipairs(F.alphabets) do
            local file = MemberTakesPath(alphabet, path) and path or F.stock[alphabet]
            members[#members + 1] = { alphabet = alphabet, file = file, height = size, flags = flags }
        end
        F.count = F.count + 1
        local ok, made = pcall(CreateFontFamily, "FlareUI_FontFamily" .. F.count, members)
        if not (ok and made) then return SetFontRaw(fontString, path, size, flags) end
        family, F.built[key] = made, made
        if ns.FontRedraw and ns.FontRedraw.Wanted(path) then
            local want = { family = true, size = size, flags = flags }
            ns.FontRedraw.objects[family] = want
            -- (a family has no SetFont answer to retry on: its strings are drawn anew a few times
            -- while the file comes in)
            for _, delay in ipairs(ns.FontRedraw.NEW_FAMILY) do
                C_Timer.After(delay, function() ns.FontRedraw.Family(made, want) end)
            end
        end
    end
    fontString:SetFontObject(family)
end

-- Blizzard's own font objects (tooltip text): set member by member, so the Cyrillic and Chinese /
-- Korean members keep a face that has their letters, at the new size
local function SetFontObjectFaceRaw(fontObject, path, size, flags)
    flags = flags or ""
    fontObject:SetFont(path, size, flags)
    local R = ns.FontRedraw
    if R and size and R.Wanted(path) then
        R.objects[fontObject] = { path = path, size = size, flags = flags }
    elseif R then
        R.objects[fontObject] = nil
    end
    if not fontObject.GetFontObjectForAlphabet then return end
    for _, alphabet in ipairs(ns.FontFamily.alphabets) do
        local ok, member = pcall(fontObject.GetFontObjectForAlphabet, fontObject, alphabet)
        if ok and member and member.SetFont then
            if MemberTakesPath(alphabet, path) then
                member:SetFont(path, size, flags)
            else
                local file = member:GetFont() or ns.FontFamily.stock[alphabet]
                if file then member:SetFont(file, size, flags) end
            end
        end
    end
end

function ns.SetFontObjectFace(fontObject, path, size, flags)
    if size and ns.TEXT_SCALE ~= 1 then size = size * ns.TEXT_SCALE end
    return SetFontObjectFaceRaw(fontObject, path, size, flags)
end
-- a size already scaled (Settings/Fonts.lua ns.GameFonts: Blizzard's own sizes, read back)
ns.SetFontObjectFaceUnscaled = SetFontObjectFaceRaw

-- Text Scale on Blizzard's own text: every font object the game has, once, as FlareUI loads (before
-- any module sets a font). All sizes are read first: an object can inherit another's, which would
-- otherwise be scaled twice.
function ns.ScaleGameFonts(k)
    if not (GetFonts and k and k ~= 1) then return end
    local ok, names = pcall(GetFonts)
    if not (ok and type(names) == "table") then return end
    local found = {}
    for _, name in ipairs(names) do
        local font = type(name) == "string" and _G[name] or name
        -- FlareUI's own (the settings window's) keep their sizes
        local ours = type(name) == "string" and name:find("^FlareUI")
        if not ours and type(font) == "table" and font.GetFont and font.SetFont then
            local path, size, flags = font:GetFont()
            if path and type(size) == "number" and size > 0 then found[#found + 1] = { font, path, size, flags } end
        end
    end
    for _, f in ipairs(found) do pcall(SetFontObjectFaceRaw, f[1], f[2], f[3] * k, f[4]) end
end

-- The font a string shows or is waiting for, for copying its look to another string
function ns.GetWantedFont(fontString)
    local want = pendingFonts[fontString]
    if want then return want.path, want.size, want.flags end
    return fontString:GetFont()
end

function ns.ApplyShadow(fontString, fontConfig)
    if not fontString or not fontConfig then return end
    if fontConfig.enableShadow then
        fontString:SetShadowColor(0, 0, 0, 1)
        fontString:SetShadowOffset(fontConfig.shadowX or 1, fontConfig.shadowY or -1)
    else
        fontString:SetShadowColor(0, 0, 0, 0)
        fontString:SetShadowOffset(0, 0)
    end
end

-- A font split off another (aura stacks from aura timers) starts as the player's copy of it, once
-- per profile: only fields the player changed are copied, the rest are the same defaults anyway.
-- Size is copied only where the old font's size was in use.
function ns.SeedFont(db, fromKey, toKey, flagKey, skipSize)
    if not db or rawget(db, flagKey) then return end
    db[flagKey] = true
    local from, to = db[fromKey], db[toKey]
    if type(from) ~= "table" or type(to) ~= "table" then return end
    for _, field in ipairs({ "face", "size", "flags", "enableShadow", "shadowX", "shadowY" }) do
        local value = rawget(from, field)
        if value ~= nil and not (skipSize and field == "size") then to[field] = value end
    end
end

-- Aura groups can't be removed from a container, and each keeps its pooled buttons. So a group is
-- made once per lane, then reused: filter, size, sort, layout and the buttons' look change in place,
-- so dragging a size slider never leaves a group of buttons behind for each step.
-- store: the container's own table. Begin, then Add per lane, then Finish turns off the rest.
ns.AuraGroups = {}
local FONT_FIELDS = { "face", "size", "flags", "enableShadow", "shadowX", "shadowY" }

-- A look's key: tables by sorted fields (fonts also by FONT_FIELDS, as they inherit via __index)
function ns.AuraGroups.Sig(...)
    local parts = {}
    local function add(value, depth)
        if type(value) ~= "table" then
            parts[#parts + 1] = tostring(value)
            -- a Global face: the Global Font's own, so changing it rebuilds the look
            if value == ns.GLOBAL_FONT then parts[#parts + 1] = ns.GlobalFontFace() end
            return
        end
        if depth > 3 then parts[#parts + 1] = "{}" return end
        local keys = {}
        for k in pairs(value) do keys[#keys + 1] = tostring(k) end
        table.sort(keys)
        parts[#parts + 1] = "{"
        for _, k in ipairs(keys) do
            local v = value[k]
            if v == nil then v = value[tonumber(k)] end
            if type(v) ~= "function" then
                parts[#parts + 1] = k .. "="
                add(v, depth + 1)
            end
        end
        for _, field in ipairs(FONT_FIELDS) do
            if rawget(value, field) == nil and value[field] ~= nil then
                parts[#parts + 1] = field .. "=" .. tostring(value[field])
                if value[field] == ns.GLOBAL_FONT then parts[#parts + 1] = ns.GlobalFontFace() end
            end
        end
        parts[#parts + 1] = "}"
    end
    for i = 1, select("#", ...) do add((select(i, ...)), 0) end
    return table.concat(parts, "|")
end

function ns.AuraGroups.Begin(store)
    store.all = store.all or {}     -- every group key made, for Finish
    store.lanes = store.lanes or {} -- lane -> { key, look, init, buttons }: the lane's current group
    store.used = {}
end

-- A new look restyles the lane's group in place: its buttons' initializeFrame (all of FlareUI's can
-- run again) is handed the new look, and pooled buttons made later get it too. Blizzard locks the
-- buttons while auras are secret (in an instance even out of combat): a locked button keeps its old
-- look and is restyled once auras can be read again, so the group is never replaced.
local staleGroups, staleTicker = {}, nil
local function RetryStale()
    if C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then return end
    for group in pairs(staleGroups) do
        for button in pairs(group.stale) do
            if group.init and pcall(group.init, button) then group.stale[button] = nil end
        end
        if not group.init or not next(group.stale) then staleGroups[group] = nil end
    end
    if not next(staleGroups) and staleTicker then
        staleTicker:Cancel()
        staleTicker = nil
    end
end

local function Restyle(group, init)
    group.init = init
    group.stale = group.stale or setmetatable({}, { __mode = "k" })
    if not init then return end
    for button in pairs(group.buttons) do
        group.stale[button] = (not pcall(init, button)) or nil
    end
    if next(group.stale) then
        staleGroups[group] = true
        if not staleTicker then staleTicker = C_Timer.NewTicker(1, RetryStale) end
    end
end

-- Returns the group's key, or nil and the error
function ns.AuraGroups.Add(container, store, lane, look, filter, options)
    local group = store.lanes[lane]
    local key
    if group then
        if group.look ~= look then
            Restyle(group, options.initializeFrame)
            group.look = look
        end
        key = group.key
    end
    if key then
        local groupDefaults = CustomAuraContainerGroupDefaultOptions
        local ok, err = pcall(function()
            container:SetAuraGroupFilterString(key, filter)
            container:SetAuraGroupMaxFrameCount(key, options.maxFrameCount or groupDefaults.maxFrameCount)
            container:SetAuraGroupCandidateFilters(key, options.candidateFilters)
            container:SetAuraGroupSortMethod(key, options.sortMethod or groupDefaults.sortMethod, options.sortDirection or groupDefaults.sortDirection)
            container:SetAuraGroupLayout(key, options.layout)
            container:SetAuraGroupEnabled(key, true)
        end)
        if not ok then return nil, err end
    else
        store.count = (store.count or 0) + 1
        key = lane .. "#" .. store.count
        group = { key = key, look = look, init = options.initializeFrame, buttons = setmetatable({}, { __mode = "k" }) }
        local wrapped = {}
        for k, v in pairs(options) do wrapped[k] = v end
        wrapped.initializeFrame = function(button)
            group.buttons[button] = true
            if group.init then group.init(button) end
        end
        local ok, err = pcall(container.AddAuraGroup, container, key, filter, wrapped)
        if not ok then return nil, err end
        store.all[#store.all + 1] = key
        store.lanes[lane] = group
    end
    store.used[key] = true
    return key
end

function ns.AuraGroups.Finish(container, store)
    for _, key in pairs(store.all or {}) do
        if not store.used[key] then
            pcall(container.SetAuraGroupEnabled, container, key, false)
            pcall(container.SetAuraGroupMaxFrameCount, container, key, 0)
        end
    end
end

-- AURA POLICY: what every aura frame shows. The modules keep where (corners, places, sizes); the
-- rules live here once: the filter strings, candidate filters, processing policy, and what happens
-- when the unit behind a token changes. Blizzard's aura containers do the tracking, timers and sort.
-- A lane: { key, kind, place, filter, isDebuff, candidates, enemyFilter, policy }.
--   enemyFilter: the filter while the unit can be attacked (Only My Debuffs), else filter.
--   policy (tiles): "process" = Blizzard's raid frame rules (AuraUtil.ProcessAura), "none" = plain.
ns.AuraPolicy = {}
do
    local AP = ns.AuraPolicy

    -- Hide Buffs: Blizzard's maxDuration on the full duration, which also always drops permanent
    -- buffs, so Off is no filter. Not in Edit Mode: its samples have no duration.
    function AP.HideBuffs(hide, editing, candidates)
        hide = hide or "OFF"
        if editing or hide == "OFF" then return candidates end
        local max = (hide == "PERMANENT") and 999999 or tonumber(hide)
        if not max then return candidates end
        candidates = candidates or {}
        candidates.maxDuration = max
        return candidates
    end

    -- Can the player attack it? (Only My Debuffs counts on enemies: a friend's debuffs are all shown)
    function AP.IsEnemy(unit)
        if not unit or not UnitExists(unit) then return false end
        local enemy = UnitCanAttack("player", unit)
        return canaccessvalue(enemy) and enemy == true
    end

    -- Player, target, focus, pet. udb: the unit's settings. Debuffs first: nearest the frame when both
    -- share a corner.
    function AP.UnitLanes(unit, udb, editing)
        local lanes = {}
        if not udb or udb.hideAuras then return lanes end
        -- every debuff on yourself is yours to see: Only My Debuffs is for other units, and only enemies
        local mine = udb.onlyMyDebuffs and unit ~= "player"
        lanes[1] = { key = "debuffs", kind = "debuffs", place = udb.debuffs, isDebuff = true,
                     filter = "HARMFUL", enemyFilter = mine and "HARMFUL|PLAYER" or nil }
        -- Highlight Purgeable Buffs (target, focus): the buffs you or your group can purge or dispel
        -- lead the row with Blizzard's stealable border, the rest follow on the same row. The client
        -- decides from the filter, so secret auras sort too. Not in Edit Mode (one sample row).
        local candidates = AP.HideBuffs(udb.hideBuffs, editing)
        -- (always on: no switch; saved purgeHighlight values are unused)
        local purge = not editing and (unit == "target" or unit == "focus")
        -- enemies only (enemyOnly): on a friendly unit the purge row is turned off and every buff
        -- shows plainly; AP.UpdateSide switches it with the unit's side, also in a fight. (An "X and !X"
        -- filter meant to match nothing shows the friendly buffs twice, once with the white border.)
        if purge then
            lanes[#lanes + 1] = { key = "purge", kind = "buffs", place = udb.buffs, isDebuff = false, stealable = true,
                                  filter = "HELPFUL|RAID_PLAYER_DISPELLABLE", enemyOnly = true,
                                  enemyFilter = "HELPFUL|RAID_PLAYER_DISPELLABLE", candidates = candidates }
        end
        -- Only My Buffs (player): the PLAYER filter
        lanes[#lanes + 1] = { key = "buffs", kind = "buffs", place = udb.buffs, isDebuff = false, joinPrevious = purge or nil,
                     filter = purge and "HELPFUL"
                         or ((unit == "player" and udb.onlyMyBuffs) and "HELPFUL|PLAYER" or "HELPFUL"),
                     enemyFilter = purge and "HELPFUL|!RAID_PLAYER_DISPELLABLE" or nil,
                     candidates = candidates }
        return AP.ApplyHidden(lanes, unit, editing)
    end

    -- Hide Auras: the spell IDs hidden on this place (ns.HiddenAuras) join each lane's candidate
    -- filters, on a copy (lanes share their candidates). hiddenStamp: the list's version, so a
    -- module that caches its lanes' signature (ns.AuraGroups.Sig stops at depth 3) sees the change.
    -- Always Show (ns.HiddenAuras.ShownFor): the usual buff and debuff rows leave those spells out
    -- too, and a row of only them follows the last row of that kind, in the same place, on plain rules
    -- (no PLAYER filter, no Hide Buffs, no Blizzard raid rules). The purge row keeps them, with its
    -- border: the always row then skips purgeable buffs as the plain buff row does. Not in Edit Mode
    -- (Blizzard's samples). Debuffs on you or a friend: the client refuses spell ID lists there, so
    -- the always row stays empty and the usual row still shows the aura.
    function AP.ApplyHidden(lanes, place, editing)
        local HA = ns.HiddenAuras
        local hidden, leftOut = HA.For(place), HA.LeftOut(place)
        local shown = not editing and HA.ShownFor(place) or nil
        local last, purge = {}, nil
        for i, lane in ipairs(lanes) do
            lane.hiddenStamp = HA.stamp
            local usual = lane.key == "buffs" or lane.key == "debuffs"
            local exclude = (usual and shown) and leftOut or hidden
            if exclude then
                local candidates = lane.candidates and CopyTable(lane.candidates) or {}
                candidates.excludeSpellIDs = exclude
                lane.candidates = candidates
            end
            if usual then last[lane.key] = i end
            if lane.key == "purge" then purge = lane end
        end
        if not shown then return lanes end
        -- the debuffs row first in the list, so insert from the back
        local order = {}
        for key, i in pairs(last) do order[#order + 1] = { key = key, i = i } end
        table.sort(order, function(a, b) return a.i > b.i end)
        for _, o in ipairs(order) do
            local base = lanes[o.i]
            local isDebuff = o.key == "debuffs"
            local always = { key = isDebuff and "alwaysDebuffs" or "alwaysBuffs", kind = base.kind, place = base.place,
                             isDebuff = isDebuff, policy = "none", joinPrevious = true, always = true,
                             hiddenStamp = HA.stamp, filter = isDebuff and "HARMFUL" or "HELPFUL",
                             candidates = { includeSpellIDs = shown } }
            if purge and not isDebuff then
                if purge.enemyOnly then
                    always.enemyFilter = "HELPFUL|!RAID_PLAYER_DISPELLABLE"
                else
                    always.filter = "HELPFUL|!RAID_PLAYER_DISPELLABLE"
                end
            end
            table.insert(lanes, o.i + 1, always)
        end
        return lanes
    end

    -- Party, raid, main tank and boss tiles. st: the tile's settings; opts: { hostile, dispelPlace,
    -- editing, place ("party", "raid" or "boss": Hide Auras) }. Friendly debuff places take Blizzard's raid frame rules (ProcessAura: boss, role,
    -- priority and dispellable debuffs); a dispellable one shows in the debuff row and, when they are on,
    -- as a dispel icon too (as Blizzard's party frames, Debuff or Dispel)
    function AP.TileLanes(st, opts)
        local lanes = {}
        if not st then return lanes end
        local processed = AuraUtil and AuraUtil.AuraUpdateChangedType
        if opts.hostile then
            -- an enemy: every buff on it, and only the player's debuffs (damage over time, sunders);
            -- plain rules on every place, as the target frame
            lanes[1] = { key = "debuffs", kind = "debuffs", place = st.debuffs, isDebuff = true, policy = "none",
                         filter = st.onlyMyDebuffs == false and "HARMFUL" or "HARMFUL|PLAYER" }
            -- Highlight Purgeable Buffs (boss tiles): as on the target frame, purgeable buffs and
            -- enrages (Frenzy: Tranquilizing Shot) first with the stealable border, the rest after
            local candidates = AP.HideBuffs(st.hideBuffs, opts.editing)
            local purge = not opts.editing   -- (always on: no switch)
            if purge then
                lanes[#lanes + 1] = { key = "purge", kind = "buffs", place = st.buffs, isDebuff = false, policy = "none",
                                      stealable = true, filter = "HELPFUL|RAID_PLAYER_DISPELLABLE", candidates = candidates }
            end
            lanes[#lanes + 1] = { key = "buffs", kind = "buffs", place = st.buffs, isDebuff = false, policy = "none",
                                  joinPrevious = purge or nil,
                                  filter = purge and "HELPFUL|!RAID_PLAYER_DISPELLABLE" or "HELPFUL", candidates = candidates }
            return AP.ApplyHidden(lanes, opts.place, opts.editing)
        end
        local dispelIcons = opts.dispelPlace and opts.dispelPlace ~= "OFF"
        -- Dispellable Debuffs Only: Blizzard's own rule (its raid frames' option), which keeps boss,
        -- role and priority debuffs and drops only the plain ones you can't dispel. Its place takes the
        -- "processDispellable" policy; the dispel icons, in their own place, keep the usual rules.
        lanes[#lanes + 1] = { key = "debuffs", kind = "debuffs", place = st.debuffs, isDebuff = true,
                              policy = st.dispellableOnly and "processDispellable" or "process",
                              filter = "HARMFUL" }
        if dispelIcons then
            lanes[#lanes + 1] = { key = "dispels", kind = "dispels", place = opts.dispelPlace, isDebuff = true, policy = "process",
                                  filter = "HARMFUL", candidates = processed and { processedAuraType = processed.Dispel } }
        end
        -- Only My Buffs: on unless set false = Blizzard's rules (buffs you cast and can apply) + PLAYER;
        -- off shows everyone's, which needs the plain policy
        local onlyMine = st.onlyMyBuffs ~= false
        lanes[#lanes + 1] = { key = "buffs", kind = "buffs", place = st.buffs, isDebuff = false,
                              policy = onlyMine and "process" or "none",
                              filter = onlyMine and "HELPFUL|PLAYER" or "HELPFUL",
                              candidates = AP.HideBuffs(st.hideBuffs, opts.editing,
                                  (onlyMine and processed) and { processedAuraType = processed.Buff } or nil) }
        -- Blizzard's raid rules keep only a sample or two of Edit Mode's auras: there the buffs and debuffs take plain rules, so all
        -- of Blizzard's samples show and the Amount can be seen. The dispel icons keep theirs.
        if opts.editing then
            for _, lane in ipairs(lanes) do
                if lane.kind ~= "dispels" then
                    lane.policy = "none"
                    if lane.candidates and lane.candidates.processedAuraType then
                        local plain = CopyTable(lane.candidates)
                        plain.processedAuraType = nil
                        lane.candidates = next(plain) and plain or nil
                    end
                end
            end
        end
        return AP.ApplyHidden(lanes, opts.place, opts.editing)
    end

    -- The Buffs & Debuffs frames (Modules/Auras.lua): the player's whole list, permanent buffs too
    function AP.PlayerListLane(isDebuff)
        local lane
        if isDebuff then
            lane = { key = "debuffs", kind = "debuffs", isDebuff = true, filter = "HARMFUL", policy = "none" }
        else
            lane = { key = "buffs", kind = "buffs", isDebuff = false, filter = "HELPFUL", policy = "none" }
        end
        return AP.ApplyHidden({ lane }, "auras")[1]
    end

    -- The policy for a container holding these lanes. It is per container: a place holding any
    -- "process" lane keeps Blizzard's rules (processedAuraType candidates need them).
    function AP.PlacePolicy(lanes)
        local policy = "none"
        for _, lane in ipairs(lanes) do
            if lane.policy == "processDispellable" then return "processDispellable" end
            if lane.policy == "process" then policy = "process" end
        end
        return policy
    end

    -- A lane's filter for its unit right now
    function AP.FilterFor(lane, unit)
        if lane.enemyFilter and AP.IsEnemy(unit) then return lane.enemyFilter end
        return lane.filter
    end

    function AP.ApplyPolicy(container, policy)
        local P = _G.CustomAuraContainerAuraProcessingPolicy
        if not P then return end
        if policy == "process" then
            pcall(container.SetAuraProcessingPolicy, container, P.ProcessAura, {})
        elseif policy == "processDispellable" then
            pcall(container.SetAuraProcessingPolicy, container, P.ProcessAura, { displayOnlyDispellableDebuffs = true })
        else
            pcall(container.SetAuraProcessingPolicy, container, P.None)
        end
    end

    -- Live state per frame (f.auraLive): the groups whose filter follows the unit's side, and the ones
    -- with Hide Buffs' duration, which drops while a group member is too far to be visible (it then
    -- comes with no durations: every buff reads as permanent, so Hide Buffs would hide them all).
    -- Begin before a frame's groups are built; Track each built group; Done after.
    function AP.Begin(f)
        f.auraLive = { enemy = {}, reach = {} }
    end

    function AP.Track(f, container, key, lane)
        local live = f.auraLive
        if not (live and key) then return end
        if lane.enemyFilter then
            live.enemy[#live.enemy + 1] = { container = container, key = key, lane = lane }
        end
        if lane.candidates and lane.candidates.maxDuration then
            local far = CopyTable(lane.candidates)
            far.maxDuration = nil
            live.reach[#live.reach + 1] = { container = container, key = key, near = lane.candidates, far = far }
        end
    end

    -- Re-applies the side and reach state (the groups were just given their layout-time filters)
    function AP.Done(f, unit)
        local live = f.auraLive
        if not live then return end
        live.isEnemy, live.isFar = nil, nil
        AP.UpdateSide(f, unit)
        AP.UpdateReach(f, unit)
    end

    function AP.UpdateSide(f, unit)
        local live = f.auraLive
        if not (live and #live.enemy > 0) then return end
        local enemy = AP.IsEnemy(unit)
        if live.isEnemy == enemy then return end
        live.isEnemy = enemy
        for _, rec in ipairs(live.enemy) do
            if rec.lane.enemyOnly then
                pcall(rec.container.SetAuraGroupEnabled, rec.container, rec.key, enemy and true or false)
            else
                pcall(rec.container.SetAuraGroupFilterString, rec.container, rec.key, enemy and rec.lane.enemyFilter or rec.lane.filter)
            end
        end
    end

    -- noReach: enemy tiles and the player (always visible)
    function AP.UpdateReach(f, unit)
        local live = f.auraLive
        if not (live and #live.reach > 0) then return end
        local far = unit and unit ~= "player" and UnitExists(unit) and not UnitIsVisible(unit) or false
        if live.isFar == far then return end
        live.isFar = far
        for _, rec in ipairs(live.reach) do
            pcall(rec.container.SetAuraGroupCandidateFilters, rec.container, rec.key, far and rec.far or rec.near)
        end
    end

    -- Every aura container a frame owns: unit frames (f.Auras), tiles (f.AuraPos, f.AuraHighlight)
    local function EachContainer(f, fn)
        for _, entry in pairs(f.Auras or {}) do fn(entry.container) end
        for _, entry in pairs(f.AuraPos or {}) do fn(entry.container) end
        if f.AuraHighlight then fn(f.AuraHighlight.container) end
    end
    local function RebuildShown(container)
        if container:IsShown() then pcall(container.UpdateAllAuras, container) end
    end

    -- The unit behind the token changed. The containers only follow UNIT_AURA, so a new unit would
    -- keep the old one's auras: they rebuild, as Blizzard's TargetFrame does (not protected: fine in
    -- combat; UpdateAllAuras only marks them dirty). byGUID: only when the GUID changed (always when
    -- it is secret); else always.
    function AP.UnitChanged(f, unit, byGUID)
        AP.UpdateSide(f, unit)
        AP.UpdateReach(f, unit)
        if byGUID then
            local guid = unit and UnitGUID(unit)
            if not canaccessvalue(guid) then guid = nil end
            if guid and guid == f.auraGUID then return end
            f.auraGUID = guid
        end
        EachContainer(f, RebuildShown)
    end
end

-- HIDE AURAS: auras you never want to see, by spell ID, each with the frames it
-- hides on, saved as auras.hidden[spellID] = "auras,player,pet,..." (ns.Conditions tokens). Blizzard's
-- aura containers drop them (the excludeSpellIDs candidate filter), so secret auras hide too. The
-- client allows it for buffs on you, your pet and your group, and for debuffs on enemies; debuffs on
-- you or a friend only when the spell is never secret (Sated, Exhaustion).
-- ALWAYS SHOW, the other list (auras.shown[spellID] = places): those auras show even where Only My
-- Buffs / Debuffs or Hide Buffs would drop them, in a row of their own after the frame's buffs or
-- debuffs (the "only these spell IDs" candidate filter, so the same client limits apply). The Buffs &
-- Debuffs frames show every aura already, so "auras" isn't one of its places. An aura sits on one list.
ns.HiddenAuras = { stamp = 0 }
do
    local HA = ns.HiddenAuras
    -- "auras": the Buffs & Debuffs frames
    HA.PLACES = { "auras", "player", "pet", "target", "focus", "party", "raid", "boss", "nameplates" }
    HA.ALL = table.concat(HA.PLACES, ",")
    HA.SHOW_PLACES = { "player", "pet", "target", "focus", "party", "raid", "boss", "nameplates" }
    HA.SHOW_ALL = table.concat(HA.SHOW_PLACES, ",")
    local cache, cachedFrom = { hidden = {}, shown = {}, both = {} }, nil

    -- list: "hidden" (default) or "shown"
    function HA.Saved(list)
        local auras = ns.db and ns.db.profile and ns.db.profile.auras
        if not auras then return nil end
        if list == "shown" then
            auras.shown = auras.shown or {}
            return auras.shown
        end
        return auras.hidden
    end

    local function Map(list, place)
        local saved = HA.Saved(list)
        local map = false
        for id, places in pairs(saved or {}) do
            if type(id) == "number" and ns.Conditions.Has(places, place) then
                map = map or {}
                map[id] = true
            end
        end
        return map
    end

    -- { [spellID] = true } for this place on that list ("hidden", "shown", or "both" = the two
    -- together: what a frame's usual rows leave out), or nil when it's empty there
    local function Cached(list, place)
        if not place then return nil end
        local from = HA.Saved()
        if from ~= cachedFrom then   -- another profile
            for _, t in pairs(cache) do wipe(t) end
            cachedFrom = from
        end
        local map = cache[list][place]
        if map == nil then
            if list == "both" then
                local hidden, shown = Cached("hidden", place), Cached("shown", place)
                map = false
                if hidden or shown then
                    map = {}
                    for id in pairs(hidden or {}) do map[id] = true end
                    for id in pairs(shown or {}) do map[id] = true end
                end
            else
                map = Map(list, place)
            end
            cache[list][place] = map
        end
        return map or nil
    end
    function HA.For(place) return Cached("hidden", place) end
    function HA.ShownFor(place) return Cached("shown", place) end
    function HA.LeftOut(place) return Cached("both", place) end

    -- which list holds this spell, or nil
    function HA.ListOf(id)
        local hidden, shown = HA.Saved(), HA.Saved("shown")
        if hidden and hidden[id] then return "hidden" end
        if shown and shown[id] then return "shown" end
        return nil
    end

    -- a new one goes on every frame; the list's Hide On / Show On narrows it. Adding it to one list
    -- takes it off the other.
    function HA.Add(id, list)
        list = list == "shown" and "shown" or "hidden"
        local saved, other = HA.Saved(list), HA.Saved(list == "shown" and "hidden" or "shown")
        if not (saved and type(id) == "number") or saved[id] then return end
        if other then other[id] = nil end
        saved[id] = list == "shown" and HA.SHOW_ALL or HA.ALL
        HA.Changed()
        if ns.SettingsPanel and ns.SettingsPanel.Refresh then ns.SettingsPanel:Refresh() end
    end

    -- Aura Filters' Hide / Show: moves a listed spell to the other list, keeping its frames
    -- (Buffs & Debuffs drops off when it becomes Show: those frames show every aura already; a Show
    -- one that becomes Hide hides there too, as a new one does)
    function HA.SetList(id, list)
        list = list == "shown" and "shown" or "hidden"
        local from = HA.ListOf(id)
        if not from or from == list then return end
        local source, target = HA.Saved(from), HA.Saved(list)
        if not (source and target) then return end
        local places = source[id] or ""
        source[id] = nil
        if list == "shown" then
            local kept = {}
            for _, token in ipairs(HA.SHOW_PLACES) do
                if ns.Conditions.Has(places, token) then kept[#kept + 1] = token end
            end
            places = table.concat(kept, ",")
        elseif places ~= "" and not ns.Conditions.Has(places, "auras") then
            places = "auras," .. places
        end
        target[id] = places
        HA.Changed()
        if ns.SettingsPanel and ns.SettingsPanel.Refresh then ns.SettingsPanel:Refresh() end
    end

    function HA.Remove(id, list)
        local saved = HA.Saved(list)
        if not (saved and saved[id]) then return end
        saved[id] = nil
        HA.Changed()
        if ns.SettingsPanel and ns.SettingsPanel.Refresh then ns.SettingsPanel:Refresh() end
    end

    -- after a change to the list: every aura frame takes it
    function HA.Changed()
        for _, t in pairs(cache) do wipe(t) end
        HA.stamp = HA.stamp + 1
        for _, name in ipairs({ "Auras", "UnitFrames", "PartyFrames", "RaidFrames", "BossFrames", "Nameplates" }) do
            local module = ns[name]
            if module and module.Refresh then
                local ok, err = pcall(module.Refresh, module)
                if not ok then geterrorhandler()(err) end
            end
        end
    end
end

-- "Show Speed" / "Hide Speed" choices: seconds per fade
local FADE_TIMES = { instant = 0, fast = 0.2, slow = 0.4 }
function ns.FadeTime(speed) return FADE_TIMES[speed] or 0 end

-- Numbers on the bars (health, power, threat): in full up to 9999, then shortened as Blizzard does
-- (12K, 1.2M, 12M, 1.2B). AbbreviateNumbers takes secret values and custom breakpoints; Blizzard's own
-- start at 1000 ("1.2K"), so FlareUI hands it the same ones minus that first. The letters come from
-- the client's own output, so each language keeps its own. East Asian clients already count in
-- 10,000s and keep Blizzard's.
do
    local options   -- nil: not built yet; false: Blizzard's own breakpoints
    local function Suffix(n) return (AbbreviateNumbers(n):gsub("[%d%.,%s]", "")) end
    local function Build()
        local locale = GetLocale()
        if locale == "koKR" or locale == "zhCN" or locale == "zhTW" then return false end
        local ok, k, m, b, t = pcall(function()
            return Suffix(12345), Suffix(12345678), Suffix(12345678901), Suffix(12345678901234)
        end)
        if not ok or k == "" or m == "" then return false end
        local function At(breakpoint, abbreviation, significandDivisor, fractionDivisor)
            return { breakpoint = breakpoint, abbreviation = abbreviation, significandDivisor = significandDivisor,
                     fractionDivisor = fractionDivisor, abbreviationIsGlobal = false }
        end
        return { breakpointData = {
            At(1e13, t ~= "" and t or b, 1e12, 1), At(1e12, t ~= "" and t or b, 1e11, 10),
            At(1e10, b, 1e9, 1), At(1e9, b, 1e8, 10),
            At(1e7, m, 1e6, 1), At(1e6, m, 1e5, 10),
            At(1e4, k, 1e3, 1),
        } }
    end
    function ns.ShortNumber(n)
        if options == nil then options = Build() end
        if options then
            local ok, text = pcall(AbbreviateNumbers, n, options)
            if ok then return text end
            options = false   -- refused by a later client: Blizzard's own from now on
        end
        return AbbreviateNumbers(n)
    end
end

-- Edit Mode rows in one order everywhere (12-terminology.md, Ordering): within a section, dropdowns,
-- then sliders, then switches; inside each kind, the order below, so an option sits in the same place
-- on every frame. A section's master switch (Cast Bar) stays on top. Names not listed keep their own
-- order after the listed ones of their kind.
do
    local CANON = {
        -- dropdowns
        "Style", "Party Style", "Icon Shape", "Sample Raid", "Orientation", "Groups", "Growth", "Wrap", "Group Order", "Sort By", "Anchor", "Pets", "Party Targets", "Tank Targets",
        -- a Fade Group decides the rows after it (Fading: Fade Group, Visibility, Show Speed, Hide Speed)
        "Fade Group", "Visibility", "Show Speed", "Hide Speed", "Portrait", "Health Text", "Power Text", "Druid Mana Text", "Name Above Frames", "Text",
        "Tint Health", "Combo Points",
        "Bar Texture", "Border", "Absorb Texture",
        -- the Cast Bar section's rows have no prefix: placed by their canon names
        "@Cast Bar Position", "@Cast Bar Texture", "@Cast Bar Border",
        "Buffs", "Debuffs", "@Aura Sort By", "Hide Buffs", "Dispel Icons", "Dispel Highlight", "Aura Swipe", "Aura Timer",
        "Pet Border", "Target Border",
        -- sliders
        "Scale", "Size", "Width", "Height", "Portrait Scale", "Max Height", "Power Height",
        "Pet Frame Width", "Pet Frame Height", "Target Frame Width", "Target Frame Height",
        "Icon Size", "Icons per Row", "Totems per Row", "Max Icons", "Frame Gap", "Group Gap", "Spacing", "Quest Spacing",
        "Background", "@Cast Bar Background", "@Cast Bar Height", "Level Disc Size",
        -- each aura kind's size, then how many (the Amount names until the Max Buffs / Max Debuffs rename)
        "Buff Size", "Max Buffs", "Buff Amount", "Debuff Size", "Max Debuffs", "Debuff Amount",
        -- the Fading sections' sliders: Fade Delay (the chat and the meter) after Faded Opacity
        "Faded Opacity", "Fade Delay", "Fade Old Lines",
        -- switches
        -- first of their sections' switches: Range Check (Look) and Show Level (Frame)
        -- the resource bars' two texts right under the sliders, before Range Check
        "Bar Text", "Show Timer",
        "Range Check", "Show Name", "Show Level", "Show Combat Text", "Show Threat", "Threat Text",
        "Sort by Role", "Show Player", "Show When Solo", "Show My Frame in a Party", "Group Numbers", "Main Tank Frames", "Show My Frame in a Raid",
        "Combo Points@switch", "Flip Portrait", "Mirror Bars", "Portrait@switch", "Only Mana Power Bars",
        "Five-Second Rule", "GCD Spark", "Mana on Shapeshift", "Stand-Still Zone", "Queued Attack Colour", "Waiting State",
        "Show Icon", "Show Spell Timer", "Show Spell Pushback", "Edge Glow",
        "Class Colours", "Threat Glow", "Combat Glow", "Bar Animations", "Bar Edge Glow", "Damage Trail",
        -- the aura filters together, then the sort switches
        "Only My Buffs", "Only My Debuffs", "Only Dispellable Debuffs", "Dispellable Debuffs Only", "Show Weapon Enchants",
        "Reverse Order", "Your Auras First",
    }
    local LEAD = { "Cast Bar" }
    -- "Name@switch": the place of a name that is a dropdown on some frames and a switch on others
    local canon, lead   -- localized name -> place, built on first use (the locale is loaded by then)
    local function KindRank(kind)
        local T = LibStub("FlareEditMode").SettingType
        -- a note line (an Expander with no rows, e.g. Bar Visible above, the meter in the chat tab) stays first
        if kind == T.Expander then return 0 end
        if kind == T.Dropdown then return 1 end
        if kind == T.Slider then return 2 end
        return 3
    end
    function ns.OrderEditSettings(items)
        if not canon then
            canon, lead = {}, {}
            for i, name in ipairs(CANON) do
                local base, switch = name:match("^(.-)(@switch)$")
                local key = name:sub(1, 1) == "@" and name or switch and (ns.L[base] .. "@switch") or ns.L[name]
                canon[key] = canon[key] or i
            end
            for _, name in ipairs(LEAD) do lead[ns.L[name]] = true end
        end
        local keyed = {}
        for i, item in ipairs(items) do
            -- (afterSwitches: a row that belongs under the switch that shows it, Happiness Position)
            local rank = lead[item.name] and 0 or item.afterSwitches and 3.5 or KindRank(item.kind)
            local place = (item.canon and canon["@" .. item.canon]) or (rank == 3 and canon[(item.name or "") .. "@switch"])
                or canon[item.name] or (1000 + i)
            keyed[i] = { item = item, rank = rank, place = place, i = i }
        end
        table.sort(keyed, function(a, b)
            if a.rank ~= b.rank then return a.rank < b.rank end
            if a.place ~= b.place then return a.place < b.place end
            return a.i < b.i
        end)
        for i, k in ipairs(keyed) do items[i] = k.item end
        return items
    end
end

-- Edit Mode dialogs in collapsible sections, in a fixed order for every FlareUI frame:
--   (Party / Raid / Boss: the group)  Frame  Look  Cast Bar  Auras  Icons  Pet  Target  Fading
-- One section open at a time, each frame's own for the session: the dialog opens the
-- first section until the player picks one, and opening one closes the others (FlareEditMode
-- dialog.lua PlanSections / SectionClicked). A box with a single section shows it open as a plain title.
-- A section with every setting hidden hides too.
--   local Section, settings = ns.EditSections(); Section("Frame", { ... }); return settings
-- ns.EditSection(key, items): one section's settings, for a dialog that is one section.
function ns.EditSections()
    local LEM = LibStub("FlareEditMode")
    local open = {}   -- this dialog's sections (one EditSections call per frame)
    local function IsHidden(hidden, ...)
        if type(hidden) == "function" then return hidden(...) end
        return hidden and true or false
    end
    local settings = {}
    local function Section(key, items)
        -- a unit frame's Portrait, Flip Portrait and Mirror Bars (ns.SplitFrameItems), first in Look
        if key == "Look" and ns.lookCarry then
            local carry = ns.lookCarry
            ns.lookCarry = nil
            for i = #carry, 1, -1 do table.insert(items, 1, carry[i]) end
        end
        if #items == 0 then return end
        ns.OrderEditSettings(items)   -- dropdowns, sliders, switches; the same order on every frame
        local own = {}
        for i, item in ipairs(items) do own[i] = item.hidden end
        settings[#settings + 1] = { name = "|cffffd100" .. ns.L[key] .. "|r", kind = LEM.SettingType.Expander, default = false,
            editSection = key,
            get = function() return open[key] or false end,
            -- (a Reset Settings leaves the open section alone)
            set = function(_, value, fromReset) if fromReset then return end; open[key] = value and true or nil end,
            hidden = function(...)
                for i = 1, #items do
                    if not IsHidden(own[i], ...) then return false end
                end
                return true
            end }
        for i, item in ipairs(items) do
            item.hidden = function(...)
                if not open[key] then return true end
                return IsHidden(own[i], ...)
            end
            settings[#settings + 1] = item
        end
    end
    return Section, settings
end
function ns.EditSection(key, items)
    local Section, settings = ns.EditSections()
    Section(key, items)
    return settings
end

-- A unit frame's or resource bar's own rows (the old "Frame" section) in three
-- sections, the same on every frame: Size, Text and Behaviour. The dialogs call them in this order:
--   (group)  Size  Text  Look  Behaviour  Cast Bar  Auras  Icons  (Pets & Targets)  Fading
-- A row goes by its name; one not listed is Behaviour (Range Check, Mirror Bars, Combo Points, Show
-- Threat, Five-Second Rule, the swing timers' marks...).
do
    local PARTS = {
        size = { "Scale", "Width", "Height", "Portrait Scale", "Power Height", "Size",
                 "Power Bar for Mana Users Only", "Only Mana Power Bars" },
        -- the frame's look picks (11-20): first in its Look section (ns.EditSections takes them there)
        look = { "Portrait", "Flip Portrait", "Mirror Bars" },
        text = { "Health Text", "Power Text", "Druid Mana Text", "Name Above Frames", "Text", "Show Name", "Show Level", "Show Combat Text", "Show Threat",
                 "Threat Text", "Bar Text", "Show Timer", "Level Disc Size", "Values on Mouseover" },
    }
    -- the section titles reach ns.L as variables (EditSections): listed here for the phrase list
    -- (tools/enus.js reads L["..."] literals)
    ns.EDIT_SECTION_TITLES = function()
        return ns.L["Size"], ns.L["Text"], ns.L["Look"], ns.L["Behaviour"], ns.L["Cast Bar"], ns.L["Auras"],
            ns.L["Icons"], ns.L["Fading"], ns.L["Pets & Targets"], ns.L["Main Tanks"]
    end
    local partOf
    function ns.SplitFrameItems(items)
        if not partOf then
            partOf = {}
            for part, names in pairs(PARTS) do
                for _, name in ipairs(names) do partOf[ns.L[name]] = part end
            end
        end
        local size, text, behaviour, look = {}, {}, {}, {}
        for _, item in ipairs(items) do
            local part = partOf[item.name]
            local list = part == "size" and size or part == "text" and text or part == "look" and look or behaviour
            list[#list + 1] = item
        end
        -- the next Look section built (the same dialog, straight after) puts these on top
        ns.lookCarry = #look > 0 and look or nil
        return size, text, behaviour
    end
end

-- Each layout's own store. ProfileLayout.lua puts the real one over this; this stand-in keeps every
-- Edit Mode frame working when that file didn't load (an update read with /reload, not a restart)
ns.LayoutHome = ns.LayoutHome or function(layouts, name)
    layouts[name] = layouts[name] or {}
    return layouts[name]
end

-- A spell the player knows. IsPlayerSpell is one of Blizzard's deprecated globals on Forever: it exists
-- only while the loadDeprecationFallbacks setting is on (Blizzard_DeprecatedSpellBook), so C_SpellBook first
function ns.IsPlayerSpell(id)
    if not id then return false end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
        return C_SpellBook.IsSpellKnown(id, bank) and true or false
    end
    return IsPlayerSpell and IsPlayerSpell(id) or false
end

-- Show conditions ticked as toggles in a dropdown (Edit Mode's Show, and settings rows with toggles).
-- A value is one of the spec's exclusive choices ("always"), or the ticked tokens joined by commas
-- ("combat,ingroup"), any one of which shows the frame. spec = { exclusive = { ... }, tokens = { ... },
-- empty = the value when nothing is ticked, legacy = { old single value = "its,tokens" } }.
ns.Conditions = {}
do
    local C = ns.Conditions
    local sets = {}   -- value -> { token = true }
    local function IsExclusive(spec, value) return tContains(spec.exclusive, value) end

    function C.Set(value, spec)
        value = (spec and spec.legacy and spec.legacy[value]) or value
        if type(value) ~= "string" then value = "" end
        local set = sets[value]
        if not set then
            set = {}
            for token in value:gmatch("[^,]+") do set[token] = true end
            sets[value] = set
        end
        return set
    end

    function C.Has(value, token, spec) return C.Set(value, spec)[token] == true end

    -- whether the dropdown ticks this choice
    function C.Ticked(value, choice, spec)
        if IsExclusive(spec, choice) then return value == choice end
        if IsExclusive(spec, value) then return false end
        return C.Has(value, choice, spec)
    end

    -- every ticked choice, for Edit Mode's multiple-choice dropdowns
    function C.Selection(value, spec)
        if IsExclusive(spec, value) then return { value } end
        local set, list = C.Set(value, spec), {}
        for _, token in ipairs(spec.tokens) do
            if set[token] then list[#list + 1] = token end
        end
        return list
    end

    -- the value after a click on a choice: an exclusive one clears the rest, a token flips
    function C.Toggle(value, choice, spec)
        if IsExclusive(spec, choice) then return choice end
        local set = IsExclusive(spec, value) and {} or C.Set(value, spec)
        -- spec.rivals: two choices that can't be ticked together; ticking one unticks the other
        local rival = spec.rivals and spec.rivals[choice]
        local list = {}
        for _, token in ipairs(spec.tokens) do
            local on = set[token]
            if token == choice then on = not on end
            if rival and token == rival and not set[choice] then on = false end
            if on then list[#list + 1] = token end
        end
        return #list > 0 and table.concat(list, ",") or spec.empty
    end

    -- The bars' conditions (action bars and the frames faded with them, Fake CM, resource bars). The
    -- single choices from before the toggles each meant "in combat, or ...".
    -- In an Instance on every Visibility list, under In a Group
    -- In a Capital City last on every list (11-20), under Not Mounted
    C.BAR_TOKENS = { "combat", "hastarget", "attackable", "ingroup", "instance", "unmounted", "city", "notcity" }
    -- the faded elements' and Fake CM's: Mouseover is a condition ticked with the others
    C.MOUSE_TOKENS = { "mouseover", "combat", "hastarget", "attackable", "ingroup", "instance", "unmounted", "city", "notcity" }
    C.BAR_LEGACY = { target = "combat,hastarget", harm = "combat,attackable", nomount = "combat,unmounted", group = "combat,ingroup" }
end

-- Fake CM is on while at least one bar is picked
function ns.FCMActive()
    local fcm = ns.db and ns.db.profile and ns.db.profile.fcm
    for _, bar in pairs(fcm and fcm.bars or {}) do
        if bar.enabled then return true end
    end
    return false
end

-- ReloadUI is protected on Forever: a /reload hint is scheduled first and never fires if it works
function ns.Reload()
    C_Timer.After(0.5, function()
        -- still here: the reload was blocked, and later changes must ask again
        ns.reloading = nil
        print("|cffff9900FlareUI:|r " .. L["This client does not let addons reload the UI. Type |cffffff00/reload|r to apply the change."])
    end)
    pcall(ReloadUI)
end

-- A frame's strata can be secret and can't be passed on: the frame then keeps its own
function ns.CopyStrata(frame, from)
    local strata = from and from:GetFrameStrata()
    if strata ~= nil and (not canaccessvalue or canaccessvalue(strata)) then frame:SetFrameStrata(strata) end
end

-- A bar's value, gliding there when asked (Smooth Bar Animations). The client eases it and takes
-- secret values. Only for a change on the unit already shown: a new unit, or a bar just shown, lands at once
function ns.SetBarValue(bar, value, glide)
    if glide and bar:IsVisible() then
        bar:SetValue(value, Enum.StatusBarInterpolation.ExponentialEaseOut)
    else
        bar:SetValue(value)
    end
end

-- InputUtil.IsGamepadUIEnabled; switching reloads the UI, so the answer holds for the session
function ns.IsGamepadUI()
    return C_InputInterfaceStyle ~= nil
        and C_InputInterfaceStyle.GetCurrentStyle() == Enum.InputDeviceInterfaceType.Gamepad
end

-- Whether the target is in reach of your auto attack: true, false, or nil when there is no answer
-- (no target you can attack, or the game gives none). Forever's C_SwingTimer.IsTargetWithinSwingRange
-- answers nil near and far, even while attacking (tested), so this asks the spell book: Auto
-- Attack (6603) for melee, which Forever answers (confirmed in game), Auto Shot for hunters, a
-- wand's Shoot or an attack spell for casters. Melee with no answer falls back to the game's ~10 yard
-- check. Used by the resource bars' swing timers.
do
    local RANGED = {
        HUNTER = { 75 },                     -- Auto Shot
        MAGE = { 5019, 133, 116 },           -- Shoot (a wand), Fireball, Frostbolt
        PRIEST = { 5019, 585 },              -- Shoot, Smite
        WARLOCK = { 5019, 686 },             -- Shoot, Shadow Bolt
    }
    local MELEE = { ROGUE = { 6603, 1752 } } -- Auto Attack, Sinister Strike
    local AUTO_ATTACK = { 6603 }
    local RANGED_OTHER = { 75, 5019 }        -- Auto Shot, Shoot (classes not listed above)
    local playerClass
    -- a readable true or false, else nil (an "and v or nil" would lose false)
    local function Answer(v)
        if canaccessvalue(v) and type(v) == "boolean" then return v end
        return nil
    end

    -- ranged: the ranged slot's reach (a hunter's bow, a caster's wand or spell), else melee
    function ns.TargetInRange(ranged)
        local okE, exists = pcall(UnitExists, "target")
        local okA, attack = pcall(UnitCanAttack, "player", "target")
        local okD, dead = pcall(UnitIsDeadOrGhost, "target")
        if not (okE and okA and okD and canaccessallvalues(exists, attack, dead) and exists and attack and not dead) then
            return nil
        end
        if C_SwingTimer and C_SwingTimer.IsTargetWithinSwingRange and Enum.PlayerSwingType then
            local swingType = ranged and Enum.PlayerSwingType.Ranged or Enum.PlayerSwingType.MainHand
            local ok, v = pcall(C_SwingTimer.IsTargetWithinSwingRange, swingType)
            if ok and Answer(v) ~= nil then return v end
        end
        -- (asked four times a second per swing bar: the class is read once)
        if not playerClass then playerClass = select(2, UnitClass("player")) end
        local class = playerClass
        local list = ranged and (RANGED[class] or RANGED_OTHER) or (MELEE[class] or AUTO_ATTACK)
        for _, id in ipairs(list) do
            if id == 6603 or ns.IsPlayerSpell(id) then
                local ok, v = pcall(C_Spell.IsSpellInRange, id, "target")
                if ok and Answer(v) ~= nil then return v end
            end
        end
        if not ranged and CheckInteractDistance then
            local ok, v = pcall(CheckInteractDistance, "target", 3)
            if ok and Answer(v) ~= nil then return v end
        end
        return nil
    end
end

--------------------------------------------------
-- 6. WINDOW BACKGROUNDS AND HEADER ICONS
--------------------------------------------------
-- A vertical gradient filling a frame inside its border
function ns.Fade(frame, inset, top, bottom)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", inset, -inset)
    bg:SetPoint("BOTTOMRIGHT", -inset, inset)
    bg:SetColorTexture(1, 1, 1)
    bg:SetGradient("VERTICAL", CreateColor(bottom[1], bottom[2], bottom[3], bottom[4]),
                               CreateColor(top[1], top[2], top[3], top[4]))
    return bg
end

-- Header icons in struck bronze: a metal gradient over a dark copy 1 px down-right and a faint light
-- copy 1 px up; hovering lightens the gradient. (11-19: darker, TOP 1.38 -> 1.12 and BOTTOM 0.80 ->
-- 0.68, to sit with the rest of the bronze; the chat, meter and loot roll icons alike)
ns.BronzeIcon = {
    TOP = 1.12,           -- colour multiplier at the top
    BOTTOM = 0.68,        -- and at the bottom
    HOVER = 0.15,         -- added to both when hovered
    SHADOW = { 0, 0, 0, 0.85 },
    LIGHT = { 1, 0.93, 0.75, 0.16 },
}

function ns.BronzeIcon.Paint(icon, color, hover)
    local B = ns.BronzeIcon
    local r, g, b, a = color.r, color.g, color.b, color.a or 1
    local lift = hover and B.HOVER or 0
    local top = CreateColor(math.min(1, r * B.TOP + lift), math.min(1, g * B.TOP + lift), math.min(1, b * B.TOP + lift), a)
    local bottom = CreateColor(math.min(1, r * B.BOTTOM + lift), math.min(1, g * B.BOTTOM + lift), math.min(1, b * B.BOTTOM + lift), a)
    icon:SetVertexColor(1, 1, 1, 1)
    icon:SetGradient("VERTICAL", bottom, top)
end

function ns.BronzeIcon.Apply(icon, path, color)
    local B = ns.BronzeIcon
    local layer, sub = icon:GetDrawLayer()
    sub = math.max(sub or 0, 2)   -- the shadow and the light go two and one sublevels under it
    icon:SetDrawLayer(layer, sub)
    if not icon.FlareUI_Shadow then
        local parent = icon:GetParent()
        local shadow = parent:CreateTexture(nil, layer, nil, sub - 2)
        shadow:SetPoint("TOPLEFT", icon, "TOPLEFT", 1, -1)
        shadow:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
        local light = parent:CreateTexture(nil, layer, nil, sub - 1)
        light:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 1)
        light:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 1)
        icon.FlareUI_Shadow, icon.FlareUI_Light = shadow, light
        hooksecurefunc(icon, "Show", function() shadow:Show(); light:Show() end)
        hooksecurefunc(icon, "Hide", function() shadow:Hide(); light:Hide() end)
    end
    icon:SetTexture(path)
    icon.FlareUI_Shadow:SetTexture(path)
    icon.FlareUI_Shadow:SetVertexColor(B.SHADOW[1], B.SHADOW[2], B.SHADOW[3], B.SHADOW[4])
    icon.FlareUI_Light:SetTexture(path)
    icon.FlareUI_Light:SetVertexColor(B.LIGHT[1], B.LIGHT[2], B.LIGHT[3], B.LIGHT[4])
    B.Paint(icon, color, false)
end

--------------------------------------------------
-- 6c. UNDOCKED CHAT WINDOWS BACK ON THEIR SPOTS
-- Blizzard puts an undocked window back early in the load, from its saved spot as a share of the
-- screen; at that moment the screen (or UIParent's scale) is not yet what it will be, and the window
-- lands lower than it was left, over the main chat. Placed again with
-- Blizzard's own function once the load has settled.
--------------------------------------------------
function ns.RestoreUndockedChat()
    for i = 2, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        if cf and cf.isInitialized and not cf.isDocked and not cf.isTemporary
            and cf ~= DEFAULT_CHAT_FRAME and not cf:IsForbidden() and FCF_RestorePositionAndDimensions then
            FCF_RestorePositionAndDimensions(cf)
        end
    end
end
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        C_Timer.After(1, ns.RestoreUndockedChat)
    end)
end

--------------------------------------------------
-- 7. EDIT MODE SELECTION BOXES
-- For Blizzard systems FlareUI redraws (chat, minimap): the selection box and screen clamp go on the
-- visible border, not Blizzard's larger frame. bounds() returns the reference frame and the offsets
-- of its TOPLEFT and BOTTOMRIGHT corners.
--------------------------------------------------
local fittedBoxes = {}

function ns.FitEditModeBox(system, bounds)
    if not (system and system.Selection) then return end
    if system.FlareUI_FitBox then system.FlareUI_FitBox(system) return end
    local retries = 0
    local function Fit(self)
        if InCombatLockdown() and self:IsProtected() then return end
        local ref, left, top, right, bottom = bounds()
        if not (ref and ref:GetLeft() and self:GetLeft()) then
            -- not laid out yet
            if retries < 10 then
                retries = retries + 1
                C_Timer.After(0.5, function() Fit(self) end)
            end
            return
        end
        local selection = self.Selection
        -- offsets are in the reference's units
        local scale = ref:GetEffectiveScale() / self:GetEffectiveScale()
        local k = ref:GetEffectiveScale() / selection:GetEffectiveScale()
        selection:ClearAllPoints()
        selection:SetPoint("TOPLEFT", ref, "TOPLEFT", left * k, top * k)
        selection:SetPoint("BOTTOMRIGHT", ref, "BOTTOMRIGHT", right * k, bottom * k)
        self:SetClampRectInsets((ref:GetLeft() + left) * scale - self:GetLeft(), (ref:GetRight() + right) * scale - self:GetRight(),
                                (ref:GetTop() + top) * scale - self:GetTop(), (ref:GetBottom() + bottom) * scale - self:GetBottom())
        -- Blizzard's login placement used the old clamp and pushed the frame in from the screen edge:
        -- re-anchor once with ApplySystemAnchor's arithmetic (calling it would taint)
        if not self.FlareUI_Replaced then
            self.FlareUI_Replaced = true
            local anchor = self.systemInfo and self.systemInfo.anchorInfo
            local s = self:GetScale()
            if anchor and anchor.point and s and s > 0 then
                -- the engine methods: Edit Mode's overrides would mark its anchors dirty from addon code
                local clear = self.ClearAllPointsBase or self.ClearAllPoints
                local setPoint = self.SetPointBase or self.SetPoint
                clear(self)
                setPoint(self, anchor.point, anchor.relativeTo or UIParent, anchor.relativePoint or anchor.point,
                    (anchor.offsetX or 0) / s, (anchor.offsetY or 0) / s)
            end
        end
    end
    system.FlareUI_FitBox = Fit
    fittedBoxes[#fittedBoxes + 1] = system
    -- refit each time Edit Mode opens, after Blizzard places its boxes
    if #fittedBoxes == 1 and EditModeManagerFrame then
        EditModeManagerFrame:HookScript("OnShow", function()
            C_Timer.After(0, function() for _, s in ipairs(fittedBoxes) do s.FlareUI_FitBox(s) end end)
        end)
    end
    if type(system.AnchorSelectionFrame) == "function" then hooksecurefunc(system, "AnchorSelectionFrame", Fit) end
    if type(system.UpdateClampOffsets) == "function" then hooksecurefunc(system, "UpdateClampOffsets", Fit) end
    system:SetClampedToScreen(true)
    Fit(system)
end

--------------------------------------------------
-- 7b. EDIT MODE IN A FIGHT
-- Edit Mode stays open when a fight starts, but secure frames can't change visibility in one, so
-- samples left up could not be taken down and aura timers would keep their sample text. A fight
-- ends the previews (PLAYER_REGEN_DISABLED is the last moment before lockdown) and its end brings
-- them back while Edit Mode is still open. Modules read ns.EditPreviewing(), not LEM:IsInEditMode(),
-- and register what to redo with ns.OnEditFight.
--------------------------------------------------
do
    local LEM = LibStub("FlareEditMode")
    local fighting, callbacks = InCombatLockdown() and true or false, {}
    function ns.EditPreviewing() return LEM:IsInEditMode() and not fighting end
    function ns.OnEditFight(fn) callbacks[#callbacks + 1] = fn end
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function(_, event)
        fighting = event == "PLAYER_REGEN_DISABLED"
        if not LEM:IsInEditMode() then return end
        for _, fn in ipairs(callbacks) do securecallfunction(fn) end
    end)
end

--------------------------------------------------
-- 8. SECURE FRAME HIDING
-- Keeps a Blizzard frame hidden (Hide plus an OnShow re-hide); protected frames wait for combat to end
--------------------------------------------------
local pendingHides = {}
local hideWatcher = CreateFrame("Frame")
hideWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
hideWatcher:SetScript("OnEvent", function()
    for frame, shouldHide in pairs(pendingHides) do
        pendingHides[frame] = nil
        ns.HideFrameSecurely(frame, shouldHide)
    end
end)

-- Edit Mode systems override Hide / SetPoint / SetScale with Lua that spreads taint when run from
-- addon code: the engine methods (*Base) are called instead
function ns.RawHide(frame)
    local hide = frame.HideBase or frame.Hide
    return hide(frame)
end

-- SetScale that keeps the frame in place on screen, without Edit Mode's re-layout
function ns.SetSystemScale(frame, scale)
    local setScale = frame.SetScaleBase or frame.SetScale
    local old = frame:GetScale()
    setScale(frame, scale)
    if not frame.SetScaleBase or math.abs(old - scale) < 0.0001 then return end
    local setPoint = frame.SetPointBase or frame.SetPoint
    for i = 1, frame:GetNumPoints() do
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(i)
        setPoint(frame, point, relativeTo, relativePoint, x * old / scale, y * old / scale)
    end
end

-- Blizzard wanted it up (Edit Mode's samples don't count), so it comes back when the hiding ends; shown
-- in combat, it goes after the fight
local function ReHideOnShow(self)
    if not self.FlareUI_Hidden then return end
    if not (EditModeManagerFrame and EditModeManagerFrame:IsShown()) then self.FlareUI_WasShown = true end
    -- a protected bar shown in a fight was hidden again by its secure OnShow (SecureReHide); a plain
    -- frame can go at once
    if InCombatLockdown() and self:IsProtected() then
        pendingHides[self] = true
    else
        ns.RawHide(self)
    end
end

-- A protected bar Blizzard shows in a fight (a pet revived or called: the pet bar) can't be hidden
-- from addon code then, so its OnShow is wrapped in a secure snippet that hides it again, in combat
-- too, while its "flareui-hide" attribute is set. The engine's Hide runs there, not Edit Mode's Lua.
local secureHideHeader
-- the hide runs after Blizzard's own OnShow: the stance bar's OnShow runs Update, which would
-- show it again after a hide done before it. The pre-snippet only passes a message so the post runs.
local BAR_PRE  = [[ if self:GetAttribute("flareui-hide") then return nil, "hide" end ]]
local BAR_POST = [[ if self:GetAttribute("flareui-hide") then self:Hide() end ]]
-- the stance, pet and possess bars are protected only through their buttons: a wrap on
-- the bar never runs, and one on the buttons fires in the middle of the bar's own show (whose OnShow
-- runs Update and shows it again), so a form change in a fight would still bring the stance bar back.
-- Out of combat they move under a hidden parent instead: nothing Blizzard shows in a fight is drawn.
-- Turning the hiding off puts them back on their own parent (HideFrameSecurely).
local secureHider
-- A parked bar Blizzard shows again (any form change) keeps IsShown() true, and Edit Mode keeps its slot in the bottom stack: a gap under a
-- default-placed pet bar. Dropped right after Blizzard's own SetShownBase / ShowBase, before its
-- relayout. Out of combat only; a gap left by a fight closes at its end (the bar's own UpdateVisibility)
local function KeepParkedBarDown(self, shown)
    if shown == false or not self.FlareUI_HomeParent or InCombatLockdown() then return end
    local hide = self.HideBase or self.Hide
    hide(self)
end
local function SecureReHide(frame)
    if not frame:IsProtected() then return end
    local _, explicit = frame:IsProtected()
    if not explicit then
        if frame.actionButtons and not frame.FlareUI_HomeParent and not InCombatLockdown() then
            if not secureHider then
                -- named, so a /dump of a bar's parent tells "hidden by FlareUI" apart from UIParent
                secureHider = CreateFrame("Frame", "FlareUI_HiddenBarParent", UIParent)
                secureHider:SetAllPoints(UIParent)   -- parked bars keep valid rects (Edit Mode snapping)
                secureHider:Hide()
            end
            frame.FlareUI_HomeParent = frame:GetParent() or UIParent
            frame:SetParent(secureHider)
            if not frame.FlareUI_ParkHook and frame.SetShownBase then
                frame.FlareUI_ParkHook = true
                hooksecurefunc(frame, "SetShownBase", KeepParkedBarDown)
                hooksecurefunc(frame, "ShowBase", KeepParkedBarDown)
            end
        end
        return
    end
    if frame.FlareUI_SecureReHide or not SecureHandlerWrapScript then return end
    secureHideHeader = secureHideHeader or CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
    if pcall(SecureHandlerWrapScript, frame, "OnShow", secureHideHeader, BAR_PRE, BAR_POST) then
        frame.FlareUI_SecureReHide = true
    end
end

function ns.HideFrameSecurely(frame, shouldHide)
    if not frame or type(frame) ~= "table" or not frame.SetAttribute then
        return false
    end

    if InCombatLockdown() and frame:IsProtected() then
        pendingHides[frame] = shouldHide
        return true
    end
    pendingHides[frame] = nil
    if shouldHide then
        if not frame.FlareUI_Hidden then
            frame.FlareUI_WasShown = frame:IsShown()
        end
        frame.FlareUI_Hidden = true
        if not frame.FlareUI_ReHideHooked then
            frame.FlareUI_ReHideHooked = true
            frame:HookScript("OnShow", ReHideOnShow)
        end
        if frame:IsProtected() then
            frame:SetAttribute("flareui-hide", true)
            SecureReHide(frame)
        end
        ns.RawHide(frame)
    elseif frame.FlareUI_Hidden or frame.FlareUI_HomeParent or (secureHider and frame:GetParent() == secureHider) then
        -- only frames hidden here come back, and only if they were shown before. A bar still under the
        -- hidden parent comes back too, whatever its flags say: it must never stay parked with the
        -- hiding off (it would show but not be selectable in Edit Mode)
        frame.FlareUI_Hidden = nil
        if frame:GetAttribute("flareui-hide") then frame:SetAttribute("flareui-hide", nil) end
        -- back from the hidden parent (SecureReHide) before it can show again; a bar of Blizzard's goes
        -- home to UIParent if its own parent wasn't kept
        if frame.FlareUI_HomeParent or (secureHider and frame:GetParent() == secureHider) then
            local home = frame.FlareUI_HomeParent
            if not home or home == secureHider then home = UIParent end
            frame:SetParent(home)
            frame.FlareUI_HomeParent = nil
        end
        -- an action bar knows whether Blizzard wants it up (a pet bar, not after the pet is gone). The
        -- engine method: Edit Mode's override would re-lay the bars from addon code
        local wanted = frame.isShownExternal
        if wanted == nil then wanted = frame.FlareUI_WasShown end
        if wanted then
            local show = frame.ShowBase or frame.Show
            show(frame)
        end
        frame.FlareUI_WasShown = nil
        -- its size measured while it was parked can be 1 x 1: checked once it is drawn again
        if frame.shownButtonContainers and ns.QueueBarSizeCheck then ns.QueueBarSizeCheck(frame) end
    end
    return true
end

--------------------------------------------------
-- 8b. BAR SIZE CHECK
-- A stance bar can show its buttons while Edit Mode draws only a 1 px box at its corner, so it can't
-- be picked (/dump StanceBar:GetSize() gives 1, 1). Blizzard's bars size themselves to their shown button slots (ResizeLayoutMixin.Layout): it sets the bar
-- to 1 x 1, then measures each slot. A slot it can't measure (no valid rect yet: the bar under a hidden
-- parent, or never drawn) counts as 1 x 1, so the bar stays 1 x 1. Blizzard then never measures again
-- while the number of shown slots stays the same (ActionBarMixin:ShouldUpdateGrid), and the stance bar's
-- own OnShow (StanceBarMixin:OnShow) replaces the layout frame's re-measure on show.
-- The fix gives the bar the size Blizzard's layout would have given it, measured the same way, once the
-- slots can be measured. Only the engine's SetSize: no Blizzard function is called and none of its
-- fields is written (Layout writes self.dirty, which would taint the bar's later layouts in a fight).
-- Out of combat only; a fight queues it for the end.
--------------------------------------------------
do
    local BARS = { "StanceBar", "PetActionBar", "PossessActionBar" }
    local pendingSize = {}

    local function Readable(v) return v ~= nil and not (canaccessvalue and not canaccessvalue(v)) end

    -- true when the bar is fine or was fixed; false when it must be tried again later
    function ns.FixBarSize(bar)
        local slots = bar and bar.shownButtonContainers
        if not (slots and bar.SetSize) or #slots == 0 then return true end
        if InCombatLockdown() then pendingSize[bar] = true return false end
        pendingSize[bar] = nil
        local w, h = bar:GetSize()
        if not (Readable(w) and Readable(h)) or (w >= 2 and h >= 2) then return true end
        if bar.GetFixedSize then
            local fw, fh = bar:GetFixedSize()
            if fw and fh then return true end
        end
        local scale = bar:GetEffectiveScale()
        if not (Readable(scale) and scale > 0) then return true end
        local left, right, top, bottom
        for _, slot in ipairs(slots) do
            if slot.IsShown and slot:IsShown() then
                local l, b, sw, sh = slot:GetScaledRect()
                if not (Readable(l) and Readable(b) and Readable(sw) and Readable(sh)) then return false end
                l, b, sw, sh = l / scale, b / scale, sw / scale, sh / scale
                left = left and math.min(left, l) or l
                right = right and math.max(right, l + sw) or l + sw
                bottom = bottom and math.min(bottom, b) or b
                top = top and math.max(top, b + sh) or b + sh
            end
        end
        if not left then return true end
        local width = (right - left) + (bar.GetWidthPadding and bar:GetWidthPadding() or 0)
        local height = (top - bottom) + (bar.GetHeightPadding and bar:GetHeightPadding() or 0)
        if bar.minimumWidth then width = math.max(width, bar.minimumWidth) end
        if bar.minimumHeight then height = math.max(height, bar.minimumHeight) end
        if width < 2 or height < 2 then return true end
        bar:SetSize(width, height)
        return true
    end

    -- the next frame: the slots get their rects once the bar is drawn; tried once more a moment later
    function ns.QueueBarSizeCheck(bar)
        C_Timer.After(0, function()
            if not ns.FixBarSize(bar) then
                C_Timer.After(0.5, function() ns.FixBarSize(bar) end)
            end
        end)
    end

    local function CheckAll()
        for _, name in ipairs(BARS) do
            local bar = _G[name]
            if bar then ns.QueueBarSizeCheck(bar) end
        end
    end

    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("PLAYER_LOGIN")
    watcher:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_LOGIN" then
            -- hooksecurefunc keeps Blizzard's own call secure; the check runs a frame later
            for _, name in ipairs(BARS) do
                local bar = _G[name]
                if bar and bar.shownButtonContainers and not bar.FlareUI_SizeHook then
                    bar.FlareUI_SizeHook = true
                    if bar.Layout then hooksecurefunc(bar, "Layout", ns.QueueBarSizeCheck) end
                    bar:HookScript("OnShow", ns.QueueBarSizeCheck)
                end
            end
            if _G.EditModeManagerFrame then _G.EditModeManagerFrame:HookScript("OnShow", CheckAll) end
            self:RegisterEvent("PLAYER_ENTERING_WORLD")
            self:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
            self:RegisterEvent("PLAYER_REGEN_ENABLED")
            self:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
            CheckAll()
        elseif event == "PLAYER_REGEN_ENABLED" then
            for bar in pairs(pendingSize) do ns.QueueBarSizeCheck(bar) end
        else
            CheckAll()
        end
    end)
end

--------------------------------------------------
-- 9. WINDOW SOUNDS
-- Game Menu sounds, one per action: no window sound on the frame of a button click, and one sound
-- for windows closing together
--------------------------------------------------
local SOUND_OPEN, SOUND_CLOSE, SOUND_BUTTON = 850, 854, 852   -- SOUNDKIT.IG_MAINMENU_*
local lastClick, lastWindowSound

-- GetTime is fixed within a frame, so "this frame" is an equality test
function ns.ButtonSound(sound)
    lastClick = GetTime()
    PlaySound(sound or SOUND_BUTTON)
end

local function WindowSound(sound)
    local now = GetTime()
    if lastClick == now or lastWindowSound == now then return end
    lastWindowSound = now
    PlaySound(sound)
end

function ns.WindowOpenSound() WindowSound(SOUND_OPEN) end
function ns.WindowCloseSound() WindowSound(SOUND_CLOSE) end

--------------------------------------------------
-- 10. CHARACTER IDENTITY
-- Per-character state is keyed by GUID in db.global.characters: on Forever UnitName gives the first
-- name only and AceDB's char key can read "Unknown" at load.
--------------------------------------------------
-- What differs from the defaults (a saved style, a shared profile). A changed list (colours, fade
-- groups) comes whole, so no sparse list is made; a key the defaults don't have comes whole.
function ns.ProfileChanges(saved, defaults)
    local out = {}
    for key, value in pairs(saved) do
        local default
        if type(defaults) == "table" then default = defaults[key] end   -- (a false default stays false)
        if type(value) == "table" and type(default) == "table" then
            local sub = ns.ProfileChanges(value, default)
            if next(sub) ~= nil then out[key] = value[1] ~= nil and value or sub end
        elseif value ~= default then
            out[key] = value
        end
    end
    return out
end

function ns.PlayerGUID()
    local guid = UnitGUID("player")
    if guid == nil or (canaccessvalue and not canaccessvalue(guid)) then return nil end
    return guid
end

-- This character's table; a throwaway one while the GUID is unknown
function ns.CharDB()
    local guid = ns.PlayerGUID()
    local global = ns.db and ns.db.global
    if not (guid and global) then return {} end
    global.characters = global.characters or {}
    local entry = global.characters[guid]
    if not entry then
        entry = {}
        global.characters[guid] = entry
    end
    return entry
end

--------------------------------------------------
-- 11. DIALOGS
-- Shown by Dialog.lua, which loads after this file
--------------------------------------------------
ns.Dialogs = ns.Dialogs or {}

ns.Dialogs["FLAREUI_SYNC_SOURCE"] = {
    text = L["Make this character the Sync Blizzard UI source?\n\nEvery other character will copy this character's interface settings the next time it logs in."],
    button1 = L["Make Source"],
    button2 = L["Cancel"],
    OnAccept = function()
        if ns.Tweaks then ns.Tweaks:MakeSyncSource() end
        if ns.SettingsPanel and ns.SettingsPanel.Refresh then ns.SettingsPanel:Refresh() end
    end,
    hideOnEscape = true,
}

ns.Dialogs["FLAREUI_RESET"] = {
    text = L["Reset every FlareUI setting back to its default?\n\nThis cannot be undone."],
    button1 = L["Reset"],
    button2 = L["Cancel"],
    -- what undoes FlareUI's changes to the player's own settings, and the import marker, outlive the reset
    OnAccept = function()
        local global, kept = ns.db.global, {}
        for _, key in ipairs({ "forcedCVars", "hiddenBubbles", "chatStyleBeforeGamepad", "padCameraRestore", "fishingSounds",
                             "editModeSwitchesSet" }) do
            kept[key] = global[key]
        end
        -- CVars saved per character keep their memory per character
        local charForced = {}
        for guid, entry in pairs(global.characters or {}) do
            if type(entry) == "table" and entry.forcedCVars then charForced[guid] = entry.forcedCVars end
        end
        local imported = ns.db.sv.imported
        ns.db:ResetDB("Default")
        for key, value in pairs(kept) do ns.db.global[key] = value end
        if next(charForced) then
            ns.db.global.characters = ns.db.global.characters or {}
            for guid, forced in pairs(charForced) do
                ns.db.global.characters[guid] = ns.db.global.characters[guid] or {}
                ns.db.global.characters[guid].forcedCVars = forced
            end
        end
        ns.db.sv.imported = imported
    end,
    reloads = true,
    hideOnEscape = true,
    showAlert = true,
}

-- The layout switch runs from the secure button: from addon code it would taint every system
ns.Dialogs["FLAREUI_SYNC_RELOAD"] = {
    text = L["FlareUI copied this character's interface settings from %s.\n\nReload now to finish applying them. Until you do, some of Blizzard's own panels - Edit Mode in particular - can throw errors."],
    button1 = L["Reload Now"],
    button2 = L["Later"],
    macro = function(data)
        local layout = data and tonumber(data.layout)
        return (layout and ("/run C_EditMode.SetActiveLayout(" .. layout .. ")\n") or "") .. "/reload"
    end,
    reloads = true,   -- in combat the macro can't run: yes says how to reload
    hideOnEscape = true,
    padSecure = true,
    -- no more of these pop-ups on any character: syncs still apply and finish at the next
    -- reload. Settings > Sync Blizz UI > Hide Pop-up Alerts (global.syncHideAlerts) is the same switch
    button3 = L["Hide These Alerts"],
    OnAlt = function() if ns.db and ns.db.global then ns.db.global.syncHideAlerts = true end end,
}

-- the settings window closed with changes that need a reload
ns.Dialogs["FLAREUI_RELOAD_ON_CLOSE"] = {
    text = L["Some changes need a reload to take effect."],
    button1 = L["Reload Now"],
    button2 = L["Later"],
    reloads = true,
    hideOnEscape = true,
}

ns.Dialogs["FLAREUI_RELOAD"] = {
    text = L["Changing this setting requires a UI Reload to prevent layout issues."],
    button1 = L["Reload Now"],
    button2 = L["Cancel"],
    reloads = true,
    hideOnEscape = true,
}

--------------------------------------------------
-- 12. INITIALIZATION
-- Settings live in FlareUI2_DB; FlareUI_DB is imported once first (Import.lua)
--------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")

f:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= ADDON_NAME then return end
        self:UnregisterEvent("ADDON_LOADED")
        if ns.ImportOldSettings then ns.ImportOldSettings(defaults) end
        local success, db = pcall(AceDB.New, AceDB, "FlareUI2_DB", defaults, "Default")
        if not success or not db then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000FlareUI FATAL:|r Database initialization failed! Error: " .. tostring(db or "unknown"))
            return
        end

        ns.db = db
        ns.defaults = defaults
        ns.CastGlowDefault()   -- (decided before What's New marks this install as seen)

        -- 11-19: the bar textures FlareUI Forever and FlareUI Forever (Light) became FlareUI Dark and
        -- FlareUI Light: saved values in every profile are renamed once
        if not db.global.barNames2 then
            local RENAME = { ["FlareUI Forever"] = "FlareUI Dark", ["FlareUI Forever (Light)"] = "FlareUI Light" }
            local seen = {}
            local function Walk(t, depth)
                if depth > 12 or seen[t] then return end
                seen[t] = true
                for k, v in pairs(t) do
                    if type(v) == "string" and RENAME[v] then t[k] = RENAME[v]
                    elseif type(v) == "table" then Walk(v, depth + 1) end
                end
            end
            if type(db.sv) == "table" and type(db.sv.profiles) == "table" then pcall(Walk, db.sv.profiles, 0) end
            db.global.barNames2 = true
        end

        -- 11-20 (settings audit), once for setups made before it; a new install or a full reset
        -- starts with the flag unset and empty profiles, so it gets the new defaults:
        -- * Quest Tracker Frame Style default became Modern ("custom"): a profile that never picked
        --   one keeps FlareUI
        -- * Addons in the Drawer "None" no longer turns the drawer off (Drawer Style Off does): a
        --   saved None becomes Drawer Style Off
        if not db.global.audit1120 then
            local profiles = type(db.sv) == "table" and type(db.sv.profiles) == "table" and db.sv.profiles or {}
            for _, profile in pairs(profiles) do
                if type(profile) == "table" and next(profile) then
                    profile.objectivetracker = profile.objectivetracker or {}
                    if profile.objectivetracker.frameStyle == nil then profile.objectivetracker.frameStyle = "flareui" end
                    local mm = profile.minimap
                    if type(mm) == "table" and mm.buttonBag == false then
                        mm.drawerStyle, mm.buttonBag = "disabled", nil
                    end
                end
            end
            db.global.audit1120 = true
        end

        -- Text Scale: FlareUI's sizes and the game's font objects, before anything sets a font
        local textScale = tonumber(db.global.textScale)
        if textScale and textScale ~= 1 and textScale >= 0.5 and textScale <= 2 then
            ns.TEXT_SCALE = textScale
            ns.ScaleGameFonts(textScale)
        end
        -- Global Font > Game Text, Combat Text and Nameplates (Settings/Fonts.lua): before any
        -- module sets a font, so FlareUI's own fonts still go over Blizzard's
        if ns.GameFonts and ns.GameFonts.OnLoad then
            local ok, err = pcall(ns.GameFonts.OnLoad)
            if not ok then geterrorhandler()(err) end
        end

        -- Older manual settings may have no language saved until the dropdown was used.
        local global = db.global
        if global.useGameLanguage == false and global.language == nil then
            global.language = ns.LoadedLocale()
        end

        -- ResetDB (the Reset dialog) is already reloading, so it is not asked about again
        -- An open panel follows at once, for when the reload is declined
        local function OnProfileChanged()
            -- the character's choice, kept by GUID (AceDB's own record is keyed by a name that can
            -- read "Unknown" while the game starts; PLAYER_LOGIN below puts the choice back)
            if ns.PlayerGUID() and ns.db then
                ns.CharDB().profileName = ns.db:GetCurrentProfile()
                -- after the reload: offered the new profile's Edit Mode layout (ProfileLayout.lua)
                ns.CharDB().offerLayout = true
            end
            local panel = ns.SettingsPanel
            if panel and panel:IsShown() then panel:Refresh() end
            if not ns.reloading then ns.ShowDialog("FLAREUI_RELOAD") end
        end

        local callbackSuccess = pcall(function()
            ns.db.RegisterCallback(ns, "OnProfileChanged", OnProfileChanged)
            ns.db.RegisterCallback(ns, "OnProfileCopied", OnProfileChanged)
            ns.db.RegisterCallback(ns, "OnProfileReset", OnProfileChanged)
        end)

        if not callbackSuccess then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000FlareUI Warning:|r Failed to register profile callbacks")
        end

    elseif event == "PLAYER_LOGIN" then
        if not ns.db or not ns.db.profile then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000FlareUI Error:|r Database not initialized! Addon disabled.")
            return
        end

        -- Each character's profile, by GUID: before any module starts, so nothing needs a reload. A
        -- character with no choice kept yet takes the profile it opened with.
        local char = ns.CharDB()
        local wanted, currentProfile = char.profileName, ns.db:GetCurrentProfile()
        -- a character's first FlareUI login: offered its profile's Edit Mode layout (ProfileLayout.lua)
        if wanted == nil and ns.PlayerGUID() then char.offerLayout = true end
        if type(wanted) == "string" and wanted ~= currentProfile then
            local exists = false
            for _, name in ipairs(ns.db:GetProfiles() or {}) do
                if name == wanted then exists = true break end
            end
            if exists then
                ns.reloading = true
                pcall(ns.db.SetProfile, ns.db, wanted)
                ns.reloading = nil
            end
        end
        if ns.PlayerGUID() then char.profileName = ns.db:GetCurrentProfile() end

        local profile = ns.db.profile
        for name, module in pairs(ns.modules) do
            local shouldLoad = true

            if module.ShouldLoad then
                local loadCheckSuccess, loadResult = pcall(module.ShouldLoad, module)
                if loadCheckSuccess then
                    shouldLoad = loadResult
                else
                    print(string.format("|cffff0000FlareUI Warning:|r %s ShouldLoad() failed: %s", name, tostring(loadResult)))
                    ns.LogError(name .. " ShouldLoad", loadResult)
                    shouldLoad = false
                end
            end

            -- a module whose settings have a switch starts only when it is on
            local moduleDB = profile[name:lower()]
            if moduleDB and moduleDB.enabled == false then shouldLoad = false end

            if shouldLoad and module.Init then
                local initSuccess, initErr = pcall(module.Init, module)
                if not initSuccess then
                    print(string.format("|cffff0000FlareUI Error:|r %s failed to load: %s", name, tostring(initErr)))
                    ns.LogError(name .. " Init", initErr)
                end
            end
        end
    end
end)
