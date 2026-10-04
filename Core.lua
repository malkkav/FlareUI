local ADDON_NAME, ns = ...
FlareUI = ns
ns.addonName = ADDON_NAME
ns.modules = {}

-- The bronze every FlareUI frame border is tinted with (unit frames, cast bars, chat, damage meter),
-- deep enough to sit with the metal of Blizzard's action button frames
ns.BORDER_COLOR = { r = 0.65, g = 0.49, b = 0.27, a = 1 }   -- #A67D45

-- Combo point art, shared by the nameplate combo points (Tweaks) and Classic Combo (Unit Frames):
-- retail's Legion player-frame sheet, the classic gem at four times the resolution of
-- Interface\ComboFrame\ComboPoint. Parts are sheet pixels (left, right, top, bottom; the sheet is
-- 128 square). The socket is drawn desaturated in a light bronze, the red gem sits in its hole and
-- the star is the shine (drawn on black, so it needs the ADD blend). The rim art is dark (about 30%
-- grey) and a tint can only darken, so AddComboRimBoost lays an additive copy over the socket.
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
ns.COMBO_GEM_RISE  = 1   -- sheet px the rim's centre sits above the socket cell's (its shadow is below)

function ns.ComboPartRect(part)
    local p = COMBO_PARTS[part]
    return p[1], p[2], p[3], p[4]
end

-- puts one part of the sheet on a texture; with a scale (screen px per sheet px) it also sizes it
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

-- an additive copy of the socket on top of it, about doubling the rim's brightness (the dark
-- interior barely changes)
function ns.AddComboRimBoost(socket)
    local boost = socket:GetParent():CreateTexture(nil, "BACKGROUND", nil, 1)
    ns.SetComboPart(boost, "socket")
    boost:SetBlendMode("ADD")
    boost:SetAllPoints(socket)
    return boost
end

--------------------------------------------------
-- 1. UPVALUES
--------------------------------------------------
local ReloadUI = ReloadUI
local AceDB = LibStub("AceDB-3.0")

--------------------------------------------------
-- 2. DEFAULTS
--------------------------------------------------
-- Every fadeable element has the same shape and differs only in its display name, and the eight
-- FCM bars and ten bar scales are likewise identical. AceDB still receives a plain table; these
-- builders just keep forty near-identical literals out of the file.
-- The ten action bars share one group name by default, so a fade on any of them takes all of them
-- with it - which is what people want the first time they touch this. Everything else stands alone.
local FADER_GROUPS = {
    bar1 = "ActionBars", bar2 = "ActionBars", bar3 = "ActionBars", bar4 = "ActionBars",
    bar5 = "ActionBars", bar6 = "ActionBars", bar7 = "ActionBars", bar8 = "ActionBars",
    pet = "ActionBars", stance = "ActionBars", possess = "Possess Bar",
    bags = "Bag Bar", menu = "Micro Menu",
    player = "Player Frame", petFrame = "Pet Frame",
    minimap = "Minimap", tracker = "Quest Tracker",
    xp = "Experience Bar", rep = "Reputation Bar",
}

local function WithFaders(target)
    for key, groupName in pairs(FADER_GROUPS) do
        target[key] = {
            enableFade = false,
            faderGroup = groupName,
            alphaMin = 0,
            alphaMax = 1,
            fadeInSpeed = 0,
            fadeOutSpeed = 0,
            fadeOutDelay = 0,
            condCombat = true,
            condTarget = true,
            condHarm = false,
            condVehicle = false,
            condMouseover = true,
        }
    end
    return target
end

local BAR_KEYS = { "bar1", "bar2", "bar3", "bar4", "bar5", "bar6", "bar7", "bar8", "pet", "stance" }

local function BarScales(scale)
    local t = {}
    for _, key in ipairs(BAR_KEYS) do t[key] = scale end
    return t
end

local function FCMBars()
    local t = {}
    for i = 1, 8 do
        t["bar" .. i] = { enabled = false, condAlways = false, condCombat = false, condTarget = false, condHarm = false }
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
            enableTT = true,
            enableWay = true,
            hideCombatLog = false,
            extendHistory = true,
            saveHistory = true,

            copyLinks = true,
            shiftInvite = false,        -- shift-click a player name in chat to invite them
            formatNPC = true,
            formatPlayer = true,
            betterTimestamps = false,
            shortChannels = true,
            hideBubblesInInstance = false,

            -- Frame (Blizzard dark dialog background + the chosen border, tinted ns.BORDER_COLOR)
            borderTexture = "FlareUI Thin",
            opacity = 0.6,
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
            editBoxX = 0,
            editBoxY = 0,

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

            -- Visibility
            autoHideEnabled = false,
            autoHideDelay = 6,
            fadeInSpeed = 0,
            fadeOutSpeed = 0,
            alphaMin = 0,
            alphaMax = 1,

            showOnMessage = true,
            showOnEdit = true,
            showOnMouse = true,
            showOnCombat = false,

            -- Typography
            chatFont = { face = "Arial Narrow", size = 12, flags = "NONE", enableShadow = true, shadowX = 1, shadowY = -1 },
            tabFont = { face = "Friz Quadrata TT", size = 12, flags = "NONE", enableShadow = true, shadowX = 1, shadowY = -1, useCustomColor = true, color = { r = 0.80, g = 0.60, b = 0.34, a = 1 } },   -- fixed (no options); active tab #CC9957
            editBoxFont = { face = "Friz Quadrata TT", size = 12, flags = "NONE", enableShadow = false, shadowX = 1, shadowY = -1 },
        },

        -- [[ ACTION BARS MODULE ]]
        actionbars = {
            enabled = false,

            -- General
            cleanKeybinds = true,
            hideHotkeys = false,
            hideMacroText = true,
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

            -- reskin of Blizzard's XP / honor / reputation bars (Modules/XPBar.lua); placed in Edit Mode
            xpbar = { enabled = true },

            -- Typography
            hotkeyFont = { face = "Arial Narrow", size = 12, flags = "OUTLINE", x = -4, y = -4, enableShadow = true, shadowX = 1, shadowY = -1 },
            countFont = { face = "Arial Narrow", size = 14, flags = "OUTLINE", x = -4, y = 4, enableShadow = true, shadowX = 1, shadowY = -1 },
            macroFont = { face = "Arial Narrow", size = 10, flags = "OUTLINE", x = -6, y = 4, enableShadow = true, shadowX = 1, shadowY = -1 },
        },

        -- [[ FAKE COOLDOWN MANAGER (FCM) ]]
        fcm = {
            -- Global Cooldown Viewer Hiding
            hideUtilityCooldownViewer = false,
            hideEssentialCooldownViewer = false,

            bars = FCMBars(),

            -- Setup Mode
            setupModeEnabled = false,
        },

        -- [[ DAMAGE METER MODULE ]]
        damagemeter = {
            enabled = false,

            -- Look shared with the chat frame: background opacity, border and bar texture are user-facing
            opacity = 0.6,
            borderTexture = "FlareUI Thin",
            barTexture = "",            -- "" = Blizzard's own bar
            textPadding = 2,
            hideHeader = false,
            barFont = { face = "Friz Quadrata TT", size = 12, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 },
            threatTab = true,           -- Threat tab beside the meter title (right-click for Blizzard's types)
            combatTimer = false,        -- Blizzard's "[mm:ss]" session timer in the title row
            readyCheckButton = true,    -- Ready Check button in the header (Modules/DamageMeter.lua 7b)
            countdownButton = true,     -- Countdown button in the header
            matchChatSize = false,      -- the meter takes the chat frame's size (Edit Mode's is overridden)
            threatKey = nil,            -- a key that flips the meter between Blizzard's view and Threat
        },

        -- [[ MINIMAP MODULE ]]
        minimap = {
            enabled = false,
            autoZoom = 5,               -- seconds before zooming back out (0 = off)
            matchTrackerWidth = true,  -- objective tracker as wide as the minimap
            showDayNight = true,        -- Forever's day/night badge on the map's corner
            clockStats = true,          -- FPS and latency in the clock tooltip
        },

        -- [[ UNIT FRAMES MODULE ]]
        unitframes = {
            enabled = false,
            -- look is per frame (Edit Mode): texture / border keys in units.* below; border colour is fixed
            -- (ns.BORDER_COLOR). Default textures: Flat health, Striped absorbs, Armory cast bars.
            -- Three fonts, because the three kinds of text on a frame want different sizes far more
            -- often than they want the same one: font covers level, name and health; fontPower the
            -- power value; fontCast the spell name and its timer.
            font      = { face = "Friz Quadrata TT", size = 12, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 },
            fontPower = { face = "Friz Quadrata TT", size = 10, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 },
            fontCast  = { face = "Friz Quadrata TT", size = 12, flags = "OUTLINE", enableShadow = true, shadowX = 1, shadowY = -1 },
            -- positions per Edit Mode layout: layouts[name][unit] = { point, x, y }
            layouts = {},
            -- standalone player cast bar (replaces PlayerCastingBarFrame)
            playerCastbar = { enabled = true, width = 292, height = 26, texture = "Armory", borderTexture = "FlareUI Thick", icon = true, name = true, timer = true },
            units = {
                player       = { enabled = true, width = 240, height = 60, powerHeight = 14, healthText = "percent", powerText = true, showLevel = true,
                                 texture = "Flat", border = "FlareUI Thick",
                                 absorbTexture = "Striped", absorbReverseFill = true,
                                 buffs = "TOPLEFT", debuffs = "TOPRIGHT", auraSize = 20, auraMax = 10, onlyMyDebuffs = true, hidePermanentBuffs = true },
                target       = { enabled = true, width = 240, height = 60, powerHeight = 0, healthText = "percent", powerText = true, showLevel = true, mirror = true,
                                 classicCombo = false,
                                 texture = "Flat", border = "FlareUI Thick",
                                 absorbTexture = "Striped", absorbReverseFill = true,
                                 castbarPosition = "BOTTOM", castHeight = 16, castTexture = "Armory", castBorderTexture = "FlareUI Thick", castIcon = true, castTimer = true,
                                 buffs = "TOPLEFT", debuffs = "TOPRIGHT", auraSize = 20, auraMax = 10, onlyMyDebuffs = true, hidePermanentBuffs = true },
                targettarget = { enabled = false, width = 120, height = 28, powerHeight = 0, healthText = "none", powerText = false, showLevel = false,
                                 texture = "Flat", border = "FlareUI Thick" },
                focus        = { enabled = true, width = 160, height = 36, powerHeight = 0, healthText = "percent", powerText = false, showLevel = true, mirror = true,
                                 texture = "Flat", border = "FlareUI Thick",
                                 absorbTexture = "Striped", absorbReverseFill = true,
                                 castbarPosition = "BOTTOM", castHeight = 16, castTexture = "Armory", castBorderTexture = "FlareUI Thick", castIcon = true, castTimer = true,
                                 buffs = "OFF", debuffs = "TOPRIGHT", auraSize = 20, auraMax = 6, onlyMyDebuffs = true, hidePermanentBuffs = true },
                pet          = { enabled = true, width = 160, height = 28, powerHeight = 0, healthText = "none", powerText = false, showLevel = false,
                                 texture = "Flat", border = "FlareUI Thick",
                                 absorbTexture = "Striped", absorbReverseFill = true },
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

        -- [[ VISIBILITY (fading + permanent hiding; part of the Action Bars module) ]]
        visibility = WithFaders({
            hideBagBar = false,
            hideMicroMenu = false,
            hidePetBar = false,
            hideStanceBar = false,
            hidePossessBar = false,
            hideRaidManager = false,
            hideEndCaps = false,
        }),

        -- [[ AURAS MODULE ]] the player's buffs and debuffs (Modules/Auras.lua)
        auras = {
            enabled = false,
            style = "square",           -- square | round
            swipe = "icon",             -- border | icon | none
            timer = "below",            -- below (under the icon) | bottom (along its bottom edge)
            weaponEnchants = true,
            font = { face = "Friz Quadrata TT", size = 11, flags = "OUTLINE", enableShadow = false, shadowX = 1, shadowY = -1 },
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

        -- [[ RADIAL MENU MODULE ]]
        -- Radial contents live in db.global, not here: the profile is shared between characters, and
        -- each character needs its own radial without having to fork the rest of its settings.
        radialmenu = {
            enabled = false,
        },

        -- [[ TWEAKS MODULE ]]
        tweaks = {
            enabled = false,
            moveAnyFrame = true,        -- drag / Ctrl+wheel any Blizzard panel; positions in frames{}
            syncUI = false,             -- account-wide copy of character-specific Blizzard settings
            sellJunk = true,
            autoRepair = true,
            durabilityWarning = true,
            durabilityThreshold = 25,
            maxCameraZoom = true,
            fasterCameraZoom = true,
            fasterLoot = true,
            nameplateCombo = false,     -- classic combo point gems under the target's nameplate
            nameplateQuest = false,     -- quest badge on enemy nameplates that belong to an active quest
            hideErrors = true,
            hideZoneText = false,
            hidePartyTitle = true,
            hidePortraitNumbers = true,
            hideTips = true,
            hideAddonDrawer = false,    -- Blizzard's addon compartment button under the minimap calendar
            hideTrackerInBoss = false,  -- quest tracker hidden from ENCOUNTER_START to ENCOUNTER_END
            autoDelete = true,          -- DELETE typed into the destroy-item confirmation
            trainAll = true,            -- Train All button at trainers
            layoutPerMode = true,       -- the Edit Mode layout last used with keyboard / with the Gamepad UI comes back
            offerGamepad = true,        -- a controller press with keyboard and mouse offers Gamepad mode (GamepadMode.lua)
            frames = {},
        },
    },
    char = {
        chatHistory = {},
    },
    -- Account-wide, untouched by profile switching. The radial menu keeps its binding and (later)
    -- its radials here on purpose: the profile is shared between characters, and each character needs
    -- its own radial without having to fork every other setting to go with it.
    global = {
        radialmenu = {
            key = nil,
        },
    },
}

--------------------------------------------------
-- 3. SHARED UTILITIES
--------------------------------------------------
-- The GameTooltip for one of FlareUI's own buttons. A tooltip still up for something else (a unit,
-- say) is hidden first: Blizzard clears the unit health bar, money and progress bars only when the
-- tooltip hides (GameTooltip_OnHide), so taking it over with SetOwner alone kept that leftover bar.
function ns.OwnGameTooltip(owner, anchor)
    if GameTooltip:IsShown() and not GameTooltip:IsOwned(owner) then GameTooltip:Hide() end
    GameTooltip:SetOwner(owner, anchor)
    -- A unit tooltip hidden while Blizzard is still building it (the Tooltips module's visibility
    -- rules hide it inside Blizzard's unit handler, which then starts the health bar) leaves the bar
    -- flagged shown on a hidden tooltip, and the next tooltip opened without a hide in between shows
    -- it. FlareUI's tooltips never show a unit, so the bar is hidden here (hide only: writing to this
    -- bar is a documented taint path).
    if GameTooltip.StatusBar then GameTooltip.StatusBar:Hide() end
end

-- Shared font path fetcher with LSM fallback
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

-- Shared shadow applier for font strings (like Chat module)
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

-- Asks the user to /reload. ReloadUI() is protected on the Forever client (calling it from
-- addon code is blocked), so the hint is scheduled first: if the reload does go through, the
-- UI is gone before the timer fires and nothing is printed.
function ns.Reload()
    C_Timer.After(0.5, function()
        print("|cffff9900FlareUI:|r This client does not let addons reload the UI. Type |cffffff00/reload|r to apply the change.")
    end)
    pcall(ReloadUI)
end

--------------------------------------------------
-- 4. SECURE FRAME HIDING
--------------------------------------------------
-- Keeps a Blizzard frame hidden: a plain Hide() plus an OnShow re-hide, deferred to after combat
-- for protected frames. The one thing it cannot stop is Blizzard re-showing a protected frame in
-- combat, and none of the frames hidden this way do that.
local pendingHides = {}
local hideWatcher = CreateFrame("Frame")
hideWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
hideWatcher:SetScript("OnEvent", function()
    for frame, shouldHide in pairs(pendingHides) do
        pendingHides[frame] = nil
        ns.HideFrameSecurely(frame, shouldHide)
    end
end)

local function ReHideOnShow(self)
    if self.FlareUI_Hidden and not InCombatLockdown() then self:Hide() end
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
        frame:Hide()
    elseif frame.FlareUI_Hidden then
        -- Only frames we hid ourselves come back, and only if they were visible when we hid them:
        -- many of these (rep bar, raid manager, possess bar...) are hidden by Blizzard most of the
        -- time and must stay that way when the user simply has the toggle off.
        frame.FlareUI_Hidden = nil
        if frame.FlareUI_WasShown then frame:Show() end
        frame.FlareUI_WasShown = nil
    end
    return true
end

--------------------------------------------------
-- 5. INITIALIZATION
--------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")

f:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addon = ...
        if addon == ADDON_NAME then
            local success, db = pcall(AceDB.New, AceDB, "FlareUI_DB", defaults, "Default")
            if not success or not db then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000FlareUI FATAL:|r Database initialization failed! Error: " .. tostring(db or "unknown"))
                return
            end

            ns.db = db
            ns.defaults = defaults

            -- One-time cleanup: remove deprecated/orphaned saved vars from old addon versions
            do
                local DEPRECATED_PROFILE_KEYS = {
                    bags = true,           -- legacy inventory module name
                    inventory = true,      -- module removed (Forever strip-down)
                    objectivetracker = true,
                    cooldownmanager = true,
                    classresources = true, -- module removed
                    devoureralerts = true, -- module removed
                }
                local p = db.profile
                if p then
                    for k in pairs(DEPRECATED_PROFILE_KEYS) do
                        if p[k] ~= nil then p[k] = nil end
                    end
                end
                -- Moved to ns.CharDB (see CHARACTER IDENTITY): AceDB's per-character slots are
                -- keyed by name, and on a cold start by "Unknown", which every character shares.
                if db.sv and type(db.sv.char) == "table" then
                    for _, charData in pairs(db.sv.char) do
                        if type(charData) == "table" then
                            charData.uiSyncApplied, charData.chatHistory = nil, nil
                        end
                    end
                end
                local c = db.char
                if c and type(c) == "table" then
                    for charName, charData in pairs(c) do
                        if type(charData) == "table" and charName:sub(1, 1) ~= "_" then
                            for k in pairs(DEPRECATED_PROFILE_KEYS) do
                                if charData[k] ~= nil then charData[k] = nil end
                            end
                        end
                    end
                end
            end

            -- All three take the same handler. Passing the function itself rather than a method
            -- name keeps CallbackHandler from having to find ns.OnProfileChanged, which only ever
            -- existed for this lookup.
            -- ResetDB (the Reset dialog) fires OnProfileChanged on its way to the reload it is
            -- already making, so that one is not asked about again
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

        -- Initialize modules with error handling
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
-- FlareUI's windows sound like the Game Menu (GameMenuFrame.lua): IG_MAINMENU_OPEN as one opens,
-- IG_MAINMENU_QUIT as it is dismissed, IG_MAINMENU_OPTION for a red button. And as there, one
-- action makes one sound: the Game Menu's buttons play their click and then hide the menu without
-- another, so a window opened or closed by a button stays quiet, two windows closing together are
-- heard once, and ns.quietWindows silences a window handing over to another.
--------------------------------------------------
local SOUND_OPEN, SOUND_CLOSE, SOUND_BUTTON = 850, 854, 852   -- SOUNDKIT.IG_MAINMENU_*
local lastClick, lastWindowSound

-- GetTime is fixed for the whole frame, so "in this frame" is an equality test
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

function ns.WindowOpenSound() WindowSound(SOUND_OPEN) end
function ns.WindowCloseSound() WindowSound(SOUND_CLOSE) end

--------------------------------------------------
-- GAMEPAD UI
-- True while Forever's gamepad UI is on - the test Blizzard's own InputUtil.IsGamepadUIEnabled
-- makes. Switching the Gamepad UI setting reloads the whole UI (seen on build 70170, in and out of
-- combat), so what this answers at load holds for the session.
--------------------------------------------------
function ns.IsGamepadUI()
    return C_InputInterfaceStyle ~= nil
        and C_InputInterfaceStyle.GetCurrentStyle() == Enum.InputDeviceInterfaceType.Gamepad
end

--------------------------------------------------
-- CHARACTER IDENTITY
-- Nothing in FlareUI keys a character by name. Forever build 70009 changed UnitName("player") from
-- "First Surname" to "First", which split every name-keyed record in two. AceDB's own per-character
-- key is worse: it is read when AceDB's file loads, before a cold-started Forever client knows the
-- name, so it comes out as "Unknown" and every character shares that slot.
-- Instead, a character's own state lives in the account-wide store under its GUID, which never changes.
-- (Per-character saved variables were broken on early Forever builds; they work since 70009, but
-- the GUID store keeps existing saves where they are.) Nothing ever lists these entries, so one
-- left behind by a deleted character is simply never seen.
--------------------------------------------------
function ns.PlayerGUID()
    local guid = UnitGUID("player")
    if guid == nil or (canaccessvalue and not canaccessvalue(guid)) then return nil end
    return guid
end

-- This character's own table. A throwaway one while the GUID is unknown, so a caller that runs too
-- early loses its write rather than filing it under the wrong character.
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

-- For moving records written before 70009 across: true when a name key ("Name - Realm", or the bare
-- name the oldest sync format stored) belongs to the logged-in character. Back then the name part
-- carried the surname, so it matches the name alone or the name followed by a space.
function ns.IsLegacyKeyMine(key)
    if type(key) ~= "string" then return false end
    local name, realm = UnitName("player"), GetRealmName()
    if not name then return false end
    local keyName, keyRealm = key:match("^(.-) %- (.+)$")
    keyName = keyName or key
    if keyRealm and keyRealm ~= realm then return false end
    return keyName == name or keyName:sub(1, #name + 1) == name .. " "
end

-- FlareUI's questions (Dialog.lua shows them; it loads after this file)
ns.Dialogs = ns.Dialogs or {}

ns.Dialogs["FLAREUI_SYNC_SOURCE"] = {
    text = "Make this character the Sync Blizz UI source?\n\n"
        .. "Every other character will copy this character's interface settings the next time it logs in.",
    button1 = "Make Source",
    button2 = "Cancel",
    OnAccept = function()
        if ns.Tweaks then ns.Tweaks:MakeSyncSource() end
        LibStub("AceConfigRegistry-3.0"):NotifyChange("FlareUI")
    end,
    hideOnEscape = true,
}

ns.Dialogs["FLAREUI_RESET"] = {
    text = "Reset every FlareUI setting back to its default?\n\nThis cannot be undone.",
    button1 = "Reset",
    button2 = "Cancel",
    OnAccept = function() ns.db:ResetDB("Default") end,
    reloads = true,
    hideOnEscape = true,
    showAlert = true,
}

ns.Dialogs["FLAREUI_SYNC_RELOAD"] = {
    text = "FlareUI copied this character's interface settings from %s.\n\n"
        .. "Reload now to finish applying them. Until you do, some of Blizzard's own panels - "
        .. "Edit Mode in particular - can throw errors.",
    button1 = "Reload Now",
    button2 = "Later",
    reloads = true,
    hideOnEscape = true,
}

ns.Dialogs["FLAREUI_RELOAD"] = {
    text = "Changing this setting requires a UI Reload to prevent layout issues.",
    button1 = "Reload Now",
    button2 = "Cancel",
    reloads = true,
    hideOnEscape = true,
}
