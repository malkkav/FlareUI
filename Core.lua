local ADDON_NAME, ns = ...
local L = ns.L

--------------------------------------------------
-- CORE
-- FlareUI's namespace and what every module shares: colours and art constants, the saved
-- settings (AceDB) and their defaults, utilities, secure frame hiding, and the modules' start-up.
--------------------------------------------------
FlareUI = ns
ns.addonName = ADDON_NAME
ns.modules = {}

-- Bronze tint of every FlareUI frame border
ns.BORDER_COLOR = { r = 0.65, g = 0.49, b = 0.27, a = 1 }   -- #A67D45

-- Combo point art (nameplate combo points, Classic Combo): the player-frame sheet, 128 px square.
-- Parts are sheet pixels (left, right, top, bottom). The socket is desaturated and tinted bronze;
-- the shine is drawn on black, so it uses the ADD blend.
local COMBO_FILE  = "Interface\\PlayerFrame\\ClassOverlayComboPoints"
local COMBO_SHEET = 128
local COMBO_RIM   = { 0.80, 0.60, 0.34 }   -- #CC9957, the tooltip / XP bar border bronze
local COMBO_PARTS = {
    socket = { 28, 50, 65, 87 },
    gem    = { 3, 19, 79, 95 },
    shine  = { 0, 27, 49, 76 },
}
ns.COMBO_FILE      = COMBO_FILE
ns.COMBO_SHEET     = COMBO_SHEET
ns.COMBO_SOCKET_PX = COMBO_PARTS.socket[2] - COMBO_PARTS.socket[1]
ns.COMBO_GEM_RISE  = 1   -- sheet px the rim's centre sits above the socket cell's

function ns.ComboPartRect(part)
    local p = COMBO_PARTS[part]
    return p[1], p[2], p[3], p[4]
end

-- Puts one part of the sheet on a texture; with a scale (screen px per sheet px) it also sizes it
function ns.SetComboPart(tex, part, scale)
    local l, r, t, b = ns.ComboPartRect(part)
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

-- Additive copy of the socket: a tint can only darken, and the rim art is dark
function ns.AddComboRimBoost(socket)
    local boost = socket:GetParent():CreateTexture(nil, "BACKGROUND", nil, 1)
    ns.SetComboPart(boost, "socket")
    boost:SetBlendMode("ADD")
    boost:SetAllPoints(socket)
    return boost
end

-- One physical screen pixel in a frame's own units, so a 1-pixel line stays one pixel at any UI scale
function ns.PixelSize(frame)
    local factor = PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor()
    local scale = frame:GetEffectiveScale()
    if not (factor and scale and scale > 0) then return 1 end
    return factor / scale
end

-- The one-pixel line between combo point segments
ns.SEGMENT_LINE_COLOR = { 0, 0, 0, 1 }

-- Splits a width into n segments on whole screen pixels. Returns segment i's left edge, its width
-- and the pixel size.
function ns.SegmentSpan(frame, width, n, i)
    local px = ns.PixelSize(frame)
    local total = math.floor(width / px + 0.5)
    local left = math.floor(total * (i - 1) / n + 0.5)
    local right = math.floor(total * i / n + 0.5)
    return left * px, (right - left) * px, px
end

-- A built combo point on the segmented bars (resource bar, target frame strip)
ns.COMBO_COLOR = { 1.00, 0.30, 0.18 }

-- Blizzard's ComboFrame timings: the shine fades in, then out
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

-- One combo point gem. The lit gem is a StatusBar drawn with the whole sheet, clipped to the gem's
-- window. Its range is [i-1, i] and it is fed the raw count, so no Lua compares a secret value.
-- black: the empty socket is filled black. gem.flash plays the shine.
function ns.CreateComboGem(parent, i, size, black)
    local gem = CreateFrame("Frame", nil, parent)
    local socket = gem:CreateTexture(nil, "BACKGROUND")
    ns.SetComboPart(socket, "socket")
    socket:SetAllPoints()
    ns.AddComboRimBoost(socket)

    local window = CreateFrame("Frame", nil, gem)
    window:SetClipsChildren(true)
    if black then
        local fill = window:CreateTexture(nil, "BACKGROUND")
        ns.SetComboPart(fill, "gem")
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
    ns.SizeComboGem(gem, size)
    return gem
end

-- size: the socket's side length
function ns.SizeComboGem(gem, size)
    local scale = size / ns.COMBO_SOCKET_PX
    local left, right, top, bottom = ns.ComboPartRect("gem")
    gem:SetSize(size, size)
    gem.window:SetSize((right - left) * scale, (bottom - top) * scale)
    gem.window:ClearAllPoints()
    gem.window:SetPoint("CENTER", gem, "CENTER", 0, ns.COMBO_GEM_RISE * scale)
    gem.lit:SetSize(COMBO_SHEET * scale, COMBO_SHEET * scale)
    gem.lit:ClearAllPoints()
    gem.lit:SetPoint("TOPLEFT", gem.window, "TOPLEFT", -left * scale, top * scale)
    ns.SetComboPart(gem.shine, "shine", scale)
    gem.shine:ClearAllPoints()
    gem.shine:SetPoint("CENTER", gem.window, "CENTER")
end

-- A combo point as Blizzard draws them since Forever's October 2026 update (RogueComboPointTemplate:
-- its own art and fill animations), sized to a gem. Blizzard's point has to be told whether it is
-- lit, so it shows while the count is readable; FlareUI's gem (fed the raw count, no compare)
-- stands in while it is secret, and on a client without the template.
local BLIZZ_POINT_SIZE = 20   -- the template's side
-- Blizzard's point art reaches past its widget: rows and arcs space the points by that reach plus a
-- small gap, so they never touch
ns.COMBO_POINT_ART, ns.COMBO_POINT_GAP = 1.2, 2
function ns.ComboPointStep(size)
    return size * ns.COMBO_POINT_ART + ns.COMBO_POINT_GAP
end

function ns.CreateComboPoint(parent, i, size, black)
    local p = CreateFrame("Frame", nil, parent)
    p.index = i
    p.gem = ns.CreateComboGem(p, i, size, black)
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
    ns.SizeComboGem(p.gem, size)
    if p.blizz then p.blizz:SetScale(size / BLIZZ_POINT_SIZE) end
end

-- points: the raw count (it may be secret). animate: play Blizzard's fill and empty animations (off
-- right after a target change, as Blizzard does)
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
-- 1. UPVALUES
--------------------------------------------------
local ReloadUI = ReloadUI
local AceDB = LibStub("AceDB-3.0")

--------------------------------------------------
-- 2. DEFAULTS
--------------------------------------------------
-- Builders for the repetitive defaults.
-- Every element with a Show choice (Modules/Visibility.lua): always shown, in no fade group
local VISIBILITY_KEYS = { "bar1", "bar2", "bar3", "bar4", "bar5", "bar6", "bar7", "bar8", "pet", "stance", "bags", "menu", "xp" }

local function VisibilityElements()
    local t = {}
    for _, key in ipairs(VISIBILITY_KEYS) do t[key] = { show = "always", group = 0 } end
    return t
end

local BAR_KEYS = { "bar1", "bar2", "bar3", "bar4", "bar5", "bar6", "bar7", "bar8", "pet", "stance", "possess" }

local function BarScales(scale)
    local t = {}
    for _, key in ipairs(BAR_KEYS) do t[key] = scale end
    return t
end

local function FCMBars()
    local t = {}
    for i = 1, 8 do
        t["bar" .. i] = { enabled = false }
    end
    return t
end

local defaults = {
    profile = {
        editModeOverlaysHidden = false,   -- global: eye button on the HUD Edit Mode window (EditModeOverlays.lua)

        -- [[ CHAT MODULE ]]
        chat = {
            enabled = false,

            -- General
            hideCombatLog = false,
            saveHistory = true,

            copyLinks = true,
            shiftInvite = false,        -- shift-click a player name in chat to invite them
            hideBubblesInInstance = false,

            -- Frame (Blizzard dark dialog background + the chosen border, tinted ns.BORDER_COLOR)
            borderTexture = "FlareUI Frames",
            opacity = 0.5,
            textPadding = 10,
            borderSize = 16,
            borderInset = 3,
            headerHeight = 24,
            tabOffsetY = -3,
            tabInactiveColor = { r = 0.56, g = 0.51, b = 0.46, a = 1 },   -- #8F8275
            showSeparator = true,
            separatorStyle = "Blizzard",
            separatorColor = { r = 1, g = 1, b = 1, a = 1 },

            -- Edit Box (fixed look: black background + tooltip border tinted ns.BORDER_COLOR)
            editBoxOpacity = 1.0,
            editBoxPosition = "inside",  -- inside | below | above the chat window

            -- Header buttons (fixed icon color #9C7A4A)
            showVolume = true,
            volumeY = -14,
            volumeScale = 0.6,
            volumeColor = { r = 0.61, g = 0.48, b = 0.29, a = 1 },

            socialHide = false,
            socialY = -14,
            socialScale = 0.6,
            socialColor = { r = 0.61, g = 0.48, b = 0.29, a = 1 },

            menuHide = false,
            menuY = -14,
            menuScale = 0.6,
            menuColor = { r = 0.61, g = 0.48, b = 0.29, a = 1 },

            channelHide = false,
            channelY = -14,
            channelScale = 0.6,
            channelColor = { r = 0.61, g = 0.48, b = 0.29, a = 1 },

            -- Visibility: always | interactions (new messages, typing) | combat (interactions and combat);
            -- pointing at the chat always shows it. fadeSpeed: instant | fast | slow
            visibility = "always",
            fadeSpeed = "instant",
            autoHideDelay = 5,          -- Fade Delay: seconds the chat stays after showing (0 = at once)
            alphaMin = 0,
            alphaMax = 1,

            showOnMessage = true,
            showOnEdit = true,
            showOnMouse = true,

            -- Typography
            chatFont = { face = "Arial Narrow", size = 12, flags = "NONE", enableShadow = true, shadowX = 1, shadowY = -1 },
            tabFont = { face = "Friz Quadrata TT", size = 12, flags = "NONE", enableShadow = true, shadowX = 1, shadowY = -1, useCustomColor = true, color = { r = 0.80, g = 0.60, b = 0.34, a = 1 } },   -- fixed (no options); active tab #CC9957
            editBoxFont = { face = "Friz Quadrata TT", size = 12, flags = "NONE", enableShadow = true, shadowX = 1, shadowY = -1 },
        },

        -- [[ ACTION BARS MODULE ]]
        actionbars = {
            enabled = false,

            -- General
            cleanKeybinds = true,
            hideHotkeys = false,
            hideMacroText = true,
            procGlow = false,           -- Blizzard's proc glow on reaction abilities and flagged procs
            gryphonsAboveButtons = true,
            buttonArt = true,
            stopAutoAddSpells = true,

            colors = {
                enableRange = true,
                range = { r = 1, g = 0, b = 0, a = 0.75 },
                mana = { r = 0, g = 0, b = 1, a = 0.75 },
                unusable = { r = 0.5, g = 0.5, b = 0.5, desaturate = true },
                normal = { r = 1, g = 1, b = 1 },
            },

            scales = BarScales(1.06),

            -- the bar that switches to the stance / form pages (Blizzard: bar 1)
            autoPagingBar = 1,

            -- the FlareUI XP Bar (Modules/XPBar.lua), placed in Edit Mode; off = Blizzard's bars untouched.
            -- fixed, no option: text on mouseover, no tooltip
            xpbar = { enabled = true, width = 560, height = 14, textMode = "HOVER", showTooltip = false, layouts = {} },

            -- Typography
            hotkeyFont = { face = "Arial Narrow", size = 12, flags = "OUTLINE", x = -4, y = -4, enableShadow = true, shadowX = 1, shadowY = -1 },
            countFont = { face = "Arial Narrow", size = 14, flags = "OUTLINE", x = -4, y = 4, enableShadow = true, shadowX = 1, shadowY = -1 },
            macroFont = { face = "Arial Narrow", size = 10, flags = "OUTLINE", x = -6, y = 4, enableShadow = true, shadowX = 1, shadowY = -1 },
        },

        -- [[ FAKE COOLDOWN MANAGER (FCM) ]]
        fcm = {
            enabled = false,            -- the Fake Cooldown Manager (Settings: its options show once on)
            bars = FCMBars(),
            show = "combat",            -- always | combat | target | harm (Modules/Visibility.lua)

            -- Setup Mode
            setupModeEnabled = false,
        },

        -- [[ DAMAGE METER MODULE ]]
        damagemeter = {
            enabled = false,
            fadeSpeed = "instant",      -- instant | fast | slow: every show and hide (Visibility, mouseover)

            -- Look shared with the chat frame (fixed, no option)
            opacity = 0.5,
            borderTexture = "FlareUI Frames",
            textPadding = 2,
            hideHeader = false,
            barFont = { face = "Friz Quadrata TT", size = 12, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 },
            threatTab = true,           -- Threat tab beside the meter title (right-click for Blizzard's types)
            combatTimer = true,         -- Blizzard's "[mm:ss]" session timer in the title row
            readyCheckButton = true,    -- Ready Check button in the header (Modules/DamageMeter.lua 7b)
            countdownButton = true,     -- Countdown button in the header
            visibility = "always",      -- always | combat | hidden | group (overrules Blizzard's Edit Mode one)
            showOnMouseover = false,    -- while the visibility hides the meter, it shows under the mouse
            matchChatSize = false,      -- the meter takes the chat frame's size (Edit Mode's is overridden)
            threatKey = nil,            -- a key that flips the meter between Blizzard's view and Threat
            autoThreat = false,         -- the Threat tab when combat starts, Blizzard's view when it ends
        },

        -- [[ MINIMAP MODULE ]]
        minimap = {
            enabled = false,
            autoZoom = 5,               -- seconds before zooming back out (0 = off)
            matchTrackerWidth = true,  -- objective tracker as wide as the minimap (no option)
            buttonBag = true,           -- the badge opens a bag with every addon's minimap button (MinimapBag.lua)
            clockStats = true,          -- framerate and latency in the clock's tooltip
        },

        -- [[ UNIT FRAMES MODULE ]]
        unitframes = {
            enabled = false,
            classColor = true,          -- class colours on every FlareUI health bar (one switch for every frame)
            palette = "flareui",        -- the bars' colours: flareui (FlareUI's softer tones) | blizzard (UnitFrames' ApplyPalette)
            foreverStyle = true,        -- Forever's bronze portrait ring on player / target / focus; off = Addon style (UnitFramesRing.lua)
            auraStyle = "square",       -- the unit frames' aura icons: square | round
            auraTimer = "none",         -- none | below | bottom | middle
            -- The look is set per frame in Edit Mode (units.* below).
            -- font: level, name and health; fontPower: power value; fontCast: spell name and timer.
            font      = { face = "Friz Quadrata TT", size = 12, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 },
            fontPower = { face = "Friz Quadrata TT", size = 10, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 },
            fontCast  = { face = "Friz Quadrata TT", size = 12, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 },
            -- positions per Edit Mode layout: layouts[name][unit] = { point, x, y }
            layouts = {},
            -- Blizzard's totem frame on FlareUI Totems (Modules/Totems.lua): size in %, totems per row
            totems = { size = 95, perRow = 4 },
            -- aura text; its size follows the icon size, so auraFont.size is not used
            auraFont = { face = "Friz Quadrata TT", size = 11, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 },
            editSections = {},          -- Edit Mode sections left open (shared by every frame)
            -- resource bars (Modules/ResourceBars.lua); positions in layouts[layout][bar]
            resource = {
                enabled = false,        -- the Resource Bars module (Settings: its own page)
                font = { face = "Friz Quadrata TT", size = 10, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 },
                layouts = {},
                bars = {
                    health      = { enabled = false, show = "target", width = 220, height = 16, text = "both", textAlign = "CENTER", textSize = 12, classColor = false },
                    power       = { enabled = false, show = "target", width = 220, height = 16, textAlign = "CENTER", textSize = 12, fsr = false },
                    mana        = { enabled = false, show = "target", width = 220, height = 16, textAlign = "CENTER", textSize = 12, fsr = false},
                    combo       = { enabled = false, show = "target", width = 220, height = 12, classic = false },
                    swingMain   = { enabled = false, show = "combat",       width = 220, height = 12, textSize = 10, label = true, timer = true },
                    swingOff    = { enabled = false, show = "combat",       width = 220, height = 12, textSize = 10, label = true, timer = true },
                    swingRanged = { enabled = false, show = "combat",       width = 220, height = 12, textSize = 10, label = true, timer = true },
                },
            },
            -- party frames (Modules/PartyFrames.lua): two styles, each with its own settings
            party = {
                enabled = false,
                style = "classic",          -- classic | raid
                showPlayer = true, pets = false, sortByRole = true,
                orientation = "VERTICAL",   -- VERTICAL | HORIZONTAL
                layouts = {},
                classic = {
                    width = 240, height = 70, powerHeight = 12, spacing = 16, healthText = "percent", powerText = false,
                    showLevel = true, portrait = "none", healersOnlyPower = false, rangeAlpha = 0.45,
                    texture = "FlareUI Flat", border = "FlareUI Thick", classColor = true,
                    absorbTexture = "FlareUI Striped", absorbReverseFill = true,
                    debuffs = "INSIDE_TOPRIGHT", buffs = "INSIDE_TOPLEFT", dispels = "INSIDE_BOTTOMRIGHT",
                    auraSize = 16, auraMax = 5, auraPerRow = 5, bigBossDebuffs = false,
                    bigDefensive = true, bigDefensiveSize = 30, dispelHighlight = "mine", privateAuras = false, privateAuraSize = 20,
                    castbar = false, castHeight = 16, castTexture = "FlareUI Flat", castBorderTexture = "FlareUI Thin", castIcon = true, castTimer = true,
                    petHeight = 19, petWidth = 120, petBorder = "FlareUI Thin", icons = {},
                },
                raid = {
                    width = 200, height = 70, powerHeight = 6, spacing = 4, healthText = "none", powerText = false,
                    showLevel = false, portrait = "none", healersOnlyPower = false, rangeAlpha = 0.45,
                    texture = "FlareUI Flat", border = "FlareUI Thin", classColor = true,
                    absorbTexture = "FlareUI Striped", absorbReverseFill = true,
                    debuffs = "INSIDE_BOTTOMRIGHT", buffs = "INSIDE_BOTTOMLEFT", dispels = "INSIDE_TOPRIGHT",
                    auraSize = 16, auraMax = 6, auraPerRow = 3, bigBossDebuffs = true,
                    bigDefensive = true, bigDefensiveSize = 30, dispelHighlight = "mine", privateAuras = false, privateAuraSize = 16,
                    castbar = false, castHeight = 10, castTexture = "FlareUI Flat", castBorderTexture = "FlareUI Thin", castIcon = false, castTimer = false,
                    petHeight = 14, petWidth = 80, petBorder = "FlareUI Thin", icons = { role = { scale = 120 } },
                },
            },
            -- raid frames (Modules/RaidFrames.lua): the Raid-Style tile for everyone in a raid, main tank
            -- frames and the missing-buff reminder
            raid = {
                enabled = false,
                layouts = {}, tankLayouts = {},
                sort = "CLASS",            -- GROUP | ROLE | CLASS
                orientation = "ROWS",      -- ROWS (each group a row, stacked) | COLUMNS
                spacing = 2, groupSpacing = 2, groupNumbers = false, missingBuffs = true,
                width = 90, height = 55,
                mainTanks = { enabled = false, w = 182, h = 55, spacing = 2 },
                powerHeight = 5, healersOnlyPower = true, healthText = "none", powerText = false, showLevel = false,
                portrait = "none", rangeAlpha = 0.45, texture = "FlareUI Flat", border = "FlareUI Thin",
                absorbTexture = "FlareUI Striped", absorbReverseFill = true,
                debuffs = "INSIDE_TOPRIGHT", buffs = "INSIDE_TOPLEFT", dispels = "INSIDE_BOTTOMRIGHT",
                auraSize = 10, auraMax = 3, auraPerRow = 3, bigBossDebuffs = true,
                bigDefensive = true, bigDefensiveSize = 22, dispelHighlight = "mine", privateAuras = false, privateAuraSize = 14,
                icons = { role = { scale = 120 } },
            },
            -- boss frames (Modules/BossFrames.lua): boss1-5 on the classic party tile, mirrored
            boss = {
                enabled = true,
                layouts = {},
                width = 240, height = 70, powerHeight = 12, grow = "DOWN",
                healthText = "percent", powerText = false, showLevel = true, portrait = false, raidIcon = true,
                texture = "FlareUI Flat", border = "FlareUI Thick", absorbTexture = "FlareUI Striped", absorbReverseFill = true,
                debuffs = "INSIDE_TOPRIGHT", buffs = "INSIDE_TOPLEFT", auraSize = 16, auraMax = 5, auraPerRow = 5,
                castbar = true, castHeight = 14, castTexture = "FlareUI Flat", castBorderTexture = "FlareUI Thin", castIcon = true, castTimer = true,
            },
            -- standalone player cast bar (replaces PlayerCastingBarFrame)
            playerCastbar = { enabled = true, width = 250, height = 25, texture = "FlareUI Flat", borderTexture = "FlareUI Thin", icon = true, name = true, timer = true },
            units = {
                player       = { enabled = true, width = 240, height = 60, powerHeight = 15, healthText = "percent", powerText = true, showLevel = true,
                                 texture = "FlareUI Flat", border = "FlareUI Thick",
                                 absorbTexture = "FlareUI Striped", absorbReverseFill = true,
                                 buffs = "TOPLEFT", debuffs = "TOPRIGHT", auraSize = 20, auraMax = 10, onlyMyDebuffs = true, hidePermanentBuffs = true },
                target       = { enabled = true, width = 240, height = 60, powerHeight = 15, healthText = "percent", powerText = true, showLevel = true, mirror = true,
                                 classicCombo = false,
                                 texture = "FlareUI Flat", border = "FlareUI Thick",
                                 absorbTexture = "FlareUI Striped", absorbReverseFill = true,
                                 castbarPosition = "BOTTOM", castHeight = 16, castTexture = "FlareUI Flat", castBorderTexture = "FlareUI Thin", castIcon = true, castTimer = true,
                                 buffs = "TOPLEFT", debuffs = "TOPRIGHT", auraSize = 20, auraMax = 10, onlyMyDebuffs = true, hidePermanentBuffs = true },
                targettarget = { enabled = false, width = 100, height = 25, powerHeight = 0, healthText = "none", powerText = false, showLevel = false,
                                 texture = "FlareUI Flat", border = "FlareUI Thin" },
                focus        = { enabled = true, width = 160, height = 35, powerHeight = 0, healthText = "percent", powerText = false, showLevel = true, mirror = true,
                                 texture = "FlareUI Flat", border = "FlareUI Thick",
                                 absorbTexture = "FlareUI Striped", absorbReverseFill = true,
                                 castbarPosition = "BOTTOM", castHeight = 16, castTexture = "FlareUI Flat", castBorderTexture = "FlareUI Thin", castIcon = true, castTimer = true,
                                 buffs = "TOPLEFT", debuffs = "TOPRIGHT", auraSize = 20, auraMax = 6, onlyMyDebuffs = true, hidePermanentBuffs = true },
                focustarget  = { enabled = false, width = 100, height = 25, powerHeight = 0, healthText = "none", powerText = false, showLevel = false,
                                 texture = "FlareUI Flat", border = "FlareUI Thin" },
                pet          = { enabled = true, width = 120, height = 30, powerHeight = 0, healthText = "none", powerText = false, showLevel = false,
                                 texture = "FlareUI Flat", border = "FlareUI Thin",
                                 absorbTexture = "FlareUI Striped", absorbReverseFill = true },
            },
            -- icons and overlays, each switched for every frame that has it (Unit Frames > General > Elements)
            elements = {
                rest = true, leader = true, pvp = true, classification = true, questBoss = true, raidIcon = true,
            },
            -- conditional visibility; "player" also drives the pet frame. No condition on = always visible.
            visibility = {
                player = { condMouseover = false, condCombat = false, condTarget = false, condHarm = false, condHealth = false, alphaMin = 0, alphaMax = 1 },
                target = { condCombat = false, condHarm = false, alphaMin = 0, alphaMax = 1 },
                focus  = { condCombat = false, condHarm = false, alphaMin = 0, alphaMax = 1 },
            },
        },

        -- [[ VISIBILITY (Show choices, fade groups, permanent hiding; part of the Action Bars module) ]]
        -- show: always | mouseover | combat | target | harm. A group (1-3) owns its members' show.
        visibility = {
            elements = VisibilityElements(),
            groups = { { show = "combat" }, { show = "combat" }, { show = "combat" }, { show = "combat" }, { show = "combat" } },
            fadeSpeed = "instant",      -- instant | fast | slow (ns.FADE_TIMES)
            hideBagBar = false,
            hideMicroMenu = false,
            hidePetBar = false,
            hideStanceBar = false,
            hidePossessBar = false,
            hideRaidManager = false,
            hideTotemBar = false,
            hideEndCaps = false,
        },

        -- [[ AURAS MODULE ]] the player's buffs and debuffs (Modules/Auras.lua)
        auras = {
            enabled = false,
            style = "round",            -- square | round
            swipe = "icon",             -- border | icon | none
            timer = "below",            -- below (under the icon) | bottom (along its bottom edge)
            weaponEnchants = true,
            font = { face = "Friz Quadrata TT", size = 11, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 },
            -- per frame, set in Edit Mode
            buffs   = { size = 26, perRow = 9, max = 27, spacing = 4, grow = "LEFT", wrap = "DOWN" },
            debuffs = { size = 30, perRow = 8, max = 16, spacing = 4, grow = "LEFT", wrap = "UP" },
            layouts = {},
        },

        -- [[ TOOLTIPS MODULE ]]
        tooltips = {
            enabled = false,

            -- look
            scale = 1,
            background = { r = 0.05, g = 0.05, b = 0.06, a = 0.9 },
            borderByReaction = true,
            borderByClass = true,
            borderByQuality = true,
            hideHealthBar = true,
            -- fonts: Blizzard's tooltip fonts (GameTooltipHeaderText / GameTooltipText), shadow on
            titleFont   = { face = "Friz Quadrata TT", size = 14, flags = "NONE", enableShadow = true, shadowX = 1, shadowY = -1 },
            contentFont = { face = "Friz Quadrata TT", size = 12, flags = "NONE", enableShadow = true, shadowX = 1, shadowY = -1 },

            -- content
            nameColor = "class",          -- none | reaction | class
            colorLevelLine = true,
            classification = true,
            showTarget = false,
            hidePvpLine = true,
            hideRightClick = true,
            showItemID = false,
            showSpellID = false,

            -- anchor: default | cursorOffset (shown as "Cursor"); Blizzard's corner by default
            anchor = "default",
            anchorFrames = "default",
            anchorX = 0,
            anchorY = 0,

            -- visibility: always | combat | never; every tooltip shows by default, as with Blizzard
            visibility = {
                worldUnits = "always",
                worldObjects = "always",
                frameUnits = "always",
                frameTips = "always",
                actionBars = "always",
                items = "always",
                spells = "always",
                auras = "always",
            },
            shiftReveal = true,
        },

        -- [[ RADIAL MENU MODULE ]] radial contents are per character (db.global)
        radialmenu = {
            enabled = false,
            showNames = true,           -- the hovered button names its action
        },

        -- [[ QUEST TRACKER MODULE ]] minimized and collapsed state per character (CharDB().objectiveTracker)
        objectivetracker = {
            enabled = false,
            width = 260,
            maxHeight = 300,
            borderTexture = "FlareUI Frames",
            opacity = 0.5,
            minimizeStyle = "header",   -- "header": the header stays; "button": only a "+" button
            hideEmpty = true,           -- nothing tracked: no tracker
            showCount = true,           -- "Quests 14/25" in the header
            zoneHeaders = true,
            zoneFirst = true,           -- quests of the zone you are in first
            zoneOnly = false,           -- the header's Zone / All switch
            sortByDistance = true,
            sortByLevel = false,        -- the lowest level quest first (zones mixed, no zone headings)
            anchor = "auto",            -- auto | TOP | BOTTOM (Edit Mode); left / right follows the frame's half
            completedLast = true,
            showLevel = true,
            showTags = true,
            numbersLast = false,        -- "Boar Tusks: 3/8" instead of Forever's "3/8 Boar Tusks"
            wrapText = true,
            showRecipes = true,
            untrackHighLevel = false,
            highLevelDiff = 3,
            -- once on the way in: "minimize", "expand" or "none"
            autoMinimize = { world = "none", resting = "none", dungeon = "minimize", raid = "minimize",
                             pvp = "minimize", arena = "minimize", combat = "none" },
            headerFont = { face = "Friz Quadrata TT", size = 13, flags = "NONE", enableShadow = true, shadowX = 1, shadowY = -1 },
            titleFont = { face = "Friz Quadrata TT", size = 12, flags = "NONE", enableShadow = true, shadowX = 1, shadowY = -1 },
            objectiveFont = { face = "Friz Quadrata TT", size = 11, flags = "NONE", enableShadow = true, shadowX = 1, shadowY = -1 },
            layouts = {},
        },

        -- [[ TWEAKS MODULE ]]
        tweaks = {
            enabled = false,
            moveAnyFrame = true,        -- drag any Blizzard panel by its header; positions in frames{}
            way = true,                 -- /way map pins
            syncUI = false,             -- account-wide copy of character-specific Blizzard settings
            sellJunk = false,
            autoRepair = false,
            durabilityWarning = false,
            durabilityThreshold = 50,
            maxCameraZoom = false,
            fasterCameraZoom = false,
            fasterLoot = false,
            nameplateCombo = false,     -- classic combo point gems under the target's nameplate
            nameplateQuest = false,     -- quest badge on enemy nameplates that belong to an active quest
            nameplateHideLevel = false, -- Blizzard's level box on the right of nameplates hidden
            hideErrors = false,
            hideZoneText = false,
            hidePartyTitle = false,
            hidePortraitNumbers = false,
            hideTips = false,
            hideAddonDrawer = false,    -- Blizzard's addon compartment button under the minimap calendar
            autoDelete = false,         -- DELETE typed into the destroy-item confirmation
            trainAll = false,           -- Train All button at trainers
            layoutPerMode = true,       -- the Edit Mode layout last used with keyboard / with the Gamepad UI comes back
            offerGamepad = true,        -- a controller press with keyboard and mouse offers Gamepad mode (GamepadMode.lua)
            moveLootToasts = true,      -- FlareUI Loot Rolls / FlareUI Toasts in Edit Mode (Modules/Movers.lua); positions in moverLayouts{}
            frames = {},
        },
    },
    -- account-wide, untouched by profile switching
    global = {
        radialmenu = {
            key = nil,
        },
    },
}

--------------------------------------------------
-- 3. SHARED UTILITIES
--------------------------------------------------
-- The GameTooltip for one of FlareUI's own buttons. A tooltip owned by something else is hidden
-- first: Blizzard clears its health, money and progress bars only in OnHide.
-- 2.0 colours: Blizzard's health green and mana blue, toned down a little (rage, energy and the
-- other powers stay Blizzard's). Shared by the unit frames, party frames and resource bars.
ns.HEALTH_GREEN = { 0.15, 0.82, 0.15 }
ns.MANA_BLUE = { 0.24, 0.34, 1.00 }   -- a violet-leaning blue, clear of the shaman (210°) and mage (193°) class colours

-- A power's bar colour (r, g, b), or nil when Blizzard has none for it
function ns.PowerColor(token, powerType)
    if token == "MANA" or (token == nil and powerType == 0) then
        return ns.MANA_BLUE[1], ns.MANA_BLUE[2], ns.MANA_BLUE[3]
    end
    local tbl = _G.PowerBarColor
    local c = tbl and ((token and tbl[token]) or (powerType and tbl[powerType]))
    if c and c.r then return c.r, c.g, c.b end
end

-- Class colours on FlareUI's health bars: one switch for every frame (Unit Frames page)
function ns.ClassColorsOn()
    local uf = ns.db and ns.db.profile and ns.db.profile.unitframes
    return not uf or uf.classColor ~= false
end

-- A Blizzard Edit Mode system FlareUI redraws (the chat window, the minimap): Blizzard sizes its
-- selection box, and the screen clamp it derives from it, from its own frame, bigger than what shows.
-- The box goes on the visible border instead (bounds() returns the frame and the offsets of its
-- TOPLEFT and BOTTOMRIGHT corners from it), and the clamp follows, so the frame can sit flush with the
-- screen edges and never leave the screen.
local fittedBoxes = {}
-- FlareUI's windows (the settings panel, the welcome): the bronze edge and a gradient from a warm
-- dark at the top to near black at the bottom
ns.WINDOW_STYLE = {
    border = { 0.80, 0.60, 0.34 },
    top    = { 0.085, 0.075, 0.060, 1 },
    bottom = { 0.015, 0.015, 0.015, 1 },
}

function ns.Fade(frame, inset, top, bottom)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", inset, -inset)
    bg:SetPoint("BOTTOMRIGHT", -inset, inset)
    bg:SetColorTexture(1, 1, 1)
    bg:SetGradient("VERTICAL", CreateColor(bottom[1], bottom[2], bottom[3], bottom[4]),
                               CreateColor(top[1], top[2], top[3], top[4]))
    return bg
end

-- Header icons in struck bronze (chat and damage meter): the white art gets a metal gradient, about
-- the selected tab's colour (#CC9957) at the top to a darker bronze at the bottom, over a dark copy
-- 1 px down-right (the icon sits raised) and a faint light copy 1 px up (a bevel along its top).
-- Hovered, the whole gradient lightens.
ns.BronzeIcon = {
    TOP = 1.38,           -- the colour times this at the top
    BOTTOM = 0.80,        -- and times this at the bottom
    HOVER = 0.15,         -- added to both when hovered
    SHADOW = { 0, 0, 0, 0.85 },
    LIGHT = { 1, 0.93, 0.75, 0.20 },
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
        -- they show and hide with the icon
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

function ns.FitEditModeBox(system, bounds)
    if not (system and system.Selection) then return end
    -- called again (the chat skin's padding changed): fit now
    if system.FlareUI_FitBox then system.FlareUI_FitBox(system) return end
    local retries = 0
    local function Fit(self)
        if InCombatLockdown() and self:IsProtected() then return end
        local ref, left, top, right, bottom = bounds()
        if not (ref and ref:GetLeft() and self:GetLeft()) then
            -- not laid out yet (just made): again in a moment
            if retries < 10 then
                retries = retries + 1
                C_Timer.After(0.5, function() Fit(self) end)
            end
            return
        end
        local selection = self.Selection
        -- offsets are measured in the reference's units; the box takes them in its own
        local scale = ref:GetEffectiveScale() / self:GetEffectiveScale()
        local k = ref:GetEffectiveScale() / selection:GetEffectiveScale()
        selection:ClearAllPoints()
        selection:SetPoint("TOPLEFT", ref, "TOPLEFT", left * k, top * k)
        selection:SetPoint("BOTTOMRIGHT", ref, "BOTTOMRIGHT", right * k, bottom * k)
        -- the clamp rect is the visible border: offsets from the frame's own edges
        self:SetClampRectInsets((ref:GetLeft() + left) * scale - self:GetLeft(), (ref:GetRight() + right) * scale - self:GetRight(),
                                (ref:GetTop() + top) * scale - self:GetTop(), (ref:GetBottom() + bottom) * scale - self:GetBottom())
        -- At login Blizzard placed the frame while the clamp was still its own box, which pushed it in
        -- from the screen edge: once, it goes back to its layout's place (Blizzard's ApplySystemAnchor
        -- arithmetic, without calling Blizzard's code)
        if not self.FlareUI_Replaced then
            self.FlareUI_Replaced = true
            local anchor = self.systemInfo and self.systemInfo.anchorInfo
            local s = self:GetScale()
            if anchor and anchor.point and s and s > 0 and not (InCombatLockdown() and self:IsProtected()) then
                self:ClearAllPoints()
                self:SetPoint(anchor.point, anchor.relativeTo or UIParent, anchor.relativePoint or anchor.point,
                    (anchor.offsetX or 0) / s, (anchor.offsetY or 0) / s)
            end
        end
    end
    system.FlareUI_FitBox = Fit
    fittedBoxes[#fittedBoxes + 1] = system
    -- and each time Edit Mode opens, once Blizzard has placed its boxes
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

-- A unit's health bar under GameTooltip is only hidden when the tooltip closes, so a tooltip reused
-- without closing (the mouse goes from a unit frame straight to another button) kept it under its new
-- text. Each time the tooltip is wiped for new content the bar hides; a unit tooltip shows it again as
-- it builds (Blizzard's TooltipDataRules.HealthBar). Hide only: writing to the bar taints.
if GameTooltip and GameTooltip.StatusBar then
    GameTooltip:HookScript("OnTooltipCleared", function(tooltip)
        if tooltip.StatusBar then tooltip.StatusBar:Hide() end
    end)
end

function ns.OwnGameTooltip(owner, anchor)
    if GameTooltip:IsShown() and not GameTooltip:IsOwned(owner) then GameTooltip:Hide() end
    GameTooltip:SetOwner(owner, anchor)
    -- a unit tooltip hidden mid-build can leave its health bar flagged shown; hide only (writing to
    -- the bar taints)
    if GameTooltip.StatusBar then GameTooltip.StatusBar:Hide() end
end

-- Edge size for a border file: FlareUI Thin is drawn at half size
function ns.BorderEdgeSize(edgeFile, size)
    size = size or 16
    if type(edgeFile) == "string" and edgeFile:find("FlareUI%-Thin%.tga") then return size / 2 end
    return size
end

-- Font path from LibSharedMedia, Friz Quadrata when unknown
function ns.GetFontPath(face)
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local success, found = pcall(LSM.Fetch, LSM, "font", face, true)
        if success and found then
            return found
        end
    end
    return "Fonts\\FRIZQT__.TTF"
end

-- Applies a font config's shadow to a font string
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

-- ReloadUI is protected on Forever, so a hint to /reload is scheduled first. If the reload goes
-- through, the timer never fires.
function ns.Reload()
    C_Timer.After(0.5, function()
        print("|cffff9900FlareUI:|r " .. L["This client does not let addons reload the UI. Type |cffffff00/reload|r to apply the change."])
    end)
    pcall(ReloadUI)
end

--------------------------------------------------
-- 4. SECURE FRAME HIDING
--------------------------------------------------
-- Keeps a Blizzard frame hidden: Hide plus an OnShow re-hide. Protected frames wait for combat
-- to end.
local pendingHides = {}
local hideWatcher = CreateFrame("Frame")
hideWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
hideWatcher:SetScript("OnEvent", function()
    for frame, shouldHide in pairs(pendingHides) do
        pendingHides[frame] = nil
        ns.HideFrameSecurely(frame, shouldHide)
    end
end)

-- Edit Mode systems replace Hide / SetPoint / SetScale with Lua that re-lays out other frames.
-- Run from addon code, that Lua spreads taint, so these call the engine methods (*Base) instead.
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

local function ReHideOnShow(self)
    if self.FlareUI_Hidden and not InCombatLockdown() then ns.RawHide(self) end
end

function ns.HideFrameSecurely(frame, shouldHide)
    if not frame or type(frame) ~= "table" or not frame.SetAttribute then
        return false
    end

    if InCombatLockdown() and frame:IsProtected() then
        pendingHides[frame] = shouldHide
        return true
    end
    if shouldHide then
        if not frame.FlareUI_Hidden then
            frame.FlareUI_WasShown = frame:IsShown()
        end
        frame.FlareUI_Hidden = true
        if not frame.FlareUI_ReHideHooked then
            frame.FlareUI_ReHideHooked = true
            frame:HookScript("OnShow", ReHideOnShow)
        end
        ns.RawHide(frame)
    elseif frame.FlareUI_Hidden then
        -- only frames we hid come back, and only if they were shown when we hid them
        frame.FlareUI_Hidden = nil
        if frame.FlareUI_WasShown then frame:Show() end
        frame.FlareUI_WasShown = nil
    end
    return true
end

--------------------------------------------------
-- 5. INITIALIZATION
--------------------------------------------------
-- Settings are saved as FlareUI2_DB. An account coming from 1.x has its FlareUI_DB brought over once
-- first (Import.lua), what this version still offers only.

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")

f:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addon = ...
        if addon == ADDON_NAME then
            if ns.ImportOldSettings then ns.ImportOldSettings(defaults) end
            local success, db = pcall(AceDB.New, AceDB, "FlareUI2_DB", defaults, "Default")
            if not success or not db then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000FlareUI FATAL:|r Database initialization failed! Error: " .. tostring(db or "unknown"))
                return
            end

            ns.db = db
            ns.defaults = defaults

            -- ResetDB (the Reset dialog) is already reloading, so it is not asked about again
            local function OnProfileChanged()
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
        end

    elseif event == "PLAYER_LOGIN" then
        if not ns.db or not ns.db.profile then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000FlareUI Error:|r Database not initialized! Addon disabled.")
            return
        end

        for name, module in pairs(ns.modules) do
            local shouldLoad = true

            if module.ShouldLoad then
                local loadCheckSuccess, loadResult = pcall(module.ShouldLoad, module)
                if loadCheckSuccess then
                    shouldLoad = loadResult
                else
                    print(string.format("|cffff0000FlareUI Warning:|r %s ShouldLoad() failed: %s", name, tostring(loadResult)))
                    shouldLoad = false
                end
            end

            local dbKey = name:lower()
            if ns.db.profile[dbKey] and ns.db.profile[dbKey].enabled ~= nil then
                if not ns.db.profile[dbKey].enabled then
                    shouldLoad = false
                end
            end

            if shouldLoad and module.Init then
                local initSuccess, initErr = pcall(module.Init, module)
                if not initSuccess then
                    print(string.format("|cffff0000FlareUI Error:|r %s failed to load: %s", name, tostring(initErr)))
                end
            end
        end
    end
end)

--------------------------------------------------
-- WINDOW SOUNDS
-- Game Menu sounds, one per action: a window opened or closed by a button click stays quiet, two
-- windows closing together are heard once, and ns.quietWindows silences a hand-over.
--------------------------------------------------
local SOUND_OPEN, SOUND_CLOSE, SOUND_BUTTON = 850, 854, 852   -- SOUNDKIT.IG_MAINMENU_*
local lastClick, lastWindowSound

-- GetTime is fixed within a frame, so "this frame" is an equality test
function ns.NoteClick()
    lastClick = GetTime()
end

function ns.ButtonSound(sound)
    ns.NoteClick()
    PlaySound(sound or SOUND_BUTTON)
end

local function WindowSound(sound)
    local now = GetTime()
    if ns.quietWindows or lastClick == now or lastWindowSound == now then return end
    lastWindowSound = now
    PlaySound(sound)
end

-- Fade Speed choices (action bars, chat, damage meter): seconds for a fade in or out; instant is 0
ns.FADE_TIMES = { instant = 0, fast = 0.2, slow = 0.4 }
function ns.FadeTime(speed) return ns.FADE_TIMES[speed] or 0 end

function ns.WindowOpenSound() WindowSound(SOUND_OPEN) end
function ns.WindowCloseSound() WindowSound(SOUND_CLOSE) end

-- Puts a frame on another's strata. The game can keep a frame's strata secret, and a secret can't be
-- passed on from addon code: the frame keeps its own then.
function ns.CopyStrata(frame, from)
    local strata = from and from:GetFrameStrata()
    if strata ~= nil and (not canaccessvalue or canaccessvalue(strata)) then frame:SetFrameStrata(strata) end
end

--------------------------------------------------
-- GAMEPAD UI
-- Blizzard's InputUtil.IsGamepadUIEnabled test. Switching the Gamepad UI reloads the UI, so the
-- answer holds for the session.
--------------------------------------------------
function ns.IsGamepadUI()
    return C_InputInterfaceStyle ~= nil
        and C_InputInterfaceStyle.GetCurrentStyle() == Enum.InputDeviceInterfaceType.Gamepad
end

--------------------------------------------------
-- CHARACTER IDENTITY
-- Per-character state lives in db.global.characters under the player's GUID. Names are unreliable
-- on Forever (Forever's UnitName gives the first name only, and AceDB's char key can read "Unknown" at load).
--------------------------------------------------
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

-- FlareUI's questions (Dialog.lua shows them; it loads after this file)
ns.Dialogs = ns.Dialogs or {}

ns.Dialogs["FLAREUI_SYNC_SOURCE"] = {
    text = L["Make this character the Sync Blizz UI source?\n\nEvery other character will copy this character's interface settings the next time it logs in."],
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
    OnAccept = function() ns.db:ResetDB("Default") end,
    reloads = true,
    hideOnEscape = true,
    showAlert = true,
}

-- The secure button switches the copied Edit Mode layout and reloads; from addon code the layout
-- switch would taint every system
ns.Dialogs["FLAREUI_SYNC_RELOAD"] = {
    text = L["FlareUI copied this character's interface settings from %s.\n\nReload now to finish applying them. Until you do, some of Blizzard's own panels - Edit Mode in particular - can throw errors."],
    button1 = L["Reload Now"],
    button2 = L["Later"],
    macro = function(data)
        local layout = data and data.layout
        return (layout and ("/run C_EditMode.SetActiveLayout(" .. layout .. ")\n") or "") .. "/reload"
    end,
    hideOnEscape = true,
    padSecure = true,
}

ns.Dialogs["FLAREUI_RELOAD"] = {
    text = L["Changing this setting requires a UI Reload to prevent layout issues."],
    button1 = L["Reload Now"],
    button2 = L["Cancel"],
    reloads = true,
    hideOnEscape = true,
}
