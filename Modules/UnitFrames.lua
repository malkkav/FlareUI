local _, ns = ...
local L = ns.L

--------------------------------------------------
-- UNIT FRAMES
-- Player, target, target of target, focus, focus target and pet frames, set up in Edit Mode.
-- Secret values go straight into widget setters; Blizzard's frames are parked.
-- Main-chunk locals are near Lua's limit of 200: new constants go into tables.
--------------------------------------------------

--------------------------------------------------
-- 1. MODULE REGISTRATION
--------------------------------------------------
ns.UnitFrames = ns.UnitFrames or {}
local UF = ns.UnitFrames
ns.modules["UnitFrames"] = UF

LibStub("AceEvent-3.0"):Embed(UF)

--------------------------------------------------
-- 2. UPVALUES
--------------------------------------------------
local _G = _G
local pairs, ipairs, select, type, tostring = pairs, ipairs, select, type, tostring
local pcall = pcall
local unpack = unpack
local math_floor = math.floor
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local C_Timer = C_Timer
local LSM = LibStub("LibSharedMedia-3.0")
local LEM = LibStub("FlareEditMode")

local canaccessvalue = canaccessvalue or function() return true end

-- the value, or nil when it is secret
local function Readable(v)
    if canaccessvalue(v) then return v end
end

--------------------------------------------------
-- 3. CONSTANTS
--------------------------------------------------
local BORDER_FILE   = "Interface\\Tooltips\\UI-Tooltip-Border"
local BACKDROP_FILE = "Interface\\Buttons\\WHITE8x8"
-- the border art overlaps the bars by INSET; the backdrop is transparent
local INSET         = 4
local BORDER_SIZE   = 16
local BG_OPACITY    = 0
local DEFAULT_BORDER_COLOR = ns.BORDER_COLOR
local DEFAULT_BORDER  = "FlareUI Thick"
local DEFAULT_TEXTURE = "FlareUI Forever"
local SEPARATOR_TEXTURE = "Interface\\Common\\UI-TooltipDivider-Transparent"
local SEPARATOR_HEIGHT  = 8
local AURA_GAP      = 2     -- frame (or cast bar) to the aura rows
local TEXT_INSET    = 4
local PORTRAIT_GAP  = 0      -- portrait to bars; the divider straddles the seam
local CAST_HEIGHT   = 18
local CAST_GAP      = 4
local CAST_ICON_GAP = 0
local RAID_ICON     = 18     -- least pet happiness face size
local RAID_ICON_SHARE = 0.5  -- raid marker: mid health bar, this share of the bar's height
local HAPPINESS_SHARE = 0.7  -- pet happiness face: mid health bar, this share of the bar's height

local DEAD_TEXT     = _G.DEAD or "Dead"
local GHOST_TEXT    = _G.GHOST or "Ghost"
local OFFLINE_TEXT  = _G.PLAYER_OFFLINE or "Offline"

-- Reaction colours (FACTION_BAR_COLORS' shape)
local REACTION = {
    [1] = { 0.87, 0.27, 0.27 },  -- hated
    [2] = { 0.87, 0.27, 0.27 },  -- hostile
    [3] = { 0.87, 0.27, 0.27 },  -- unfriendly
    [4] = { 0.93, 0.78, 0.25 },  -- neutral
    [5] = { 0.30, 0.78, 0.30 },  -- friendly
    [6] = { 0.30, 0.78, 0.30 },
    [7] = { 0.30, 0.78, 0.30 },
    [8] = { 0.30, 0.78, 0.30 },
}
local GREY      = { 0.55, 0.55, 0.55 }
local CAST_COLOR            = { 0.80, 0.60, 0.36 }
local CAST_NOINTERRUPT      = { 0.55, 0.55, 0.55 }
local CAST_CHANNEL          = { 0.30, 0.65, 0.90 }
-- the player's bar is cool-toned so it never reads as the target's
local PLAYER_CAST_COLOR     = { 0.36, 0.56, 0.78 }
local PLAYER_CAST_CHANNEL   = { 0.50, 0.75, 0.88 }

-- "Colour palette": ApplyPalette copies the chosen set into the colour tables above and ns's, in place
UF.PALETTES = {
    flareui = {
        health = { 0.15, 0.82, 0.15 }, mana = { 0.24, 0.34, 1.00 }, grey = { 0.55, 0.55, 0.55 },
        hostile = { 0.87, 0.27, 0.27 }, neutral = { 0.93, 0.78, 0.25 }, friendly = { 0.30, 0.78, 0.30 },
        cast = { 0.80, 0.60, 0.36 }, castNoInterrupt = { 0.55, 0.55, 0.55 }, castChannel = { 0.30, 0.65, 0.90 },
        playerCast = { 0.36, 0.56, 0.78 }, playerChannel = { 0.50, 0.75, 0.88 },
    },
    -- Blizzard's own colours (the player's cast bar the same as everyone's)
    blizzard = {
        health = { 0, 1, 0 }, mana = { 0, 0, 1 }, grey = { 0.5, 0.5, 0.5 },
        hostile = { 1, 0, 0 }, neutral = { 1, 1, 0 }, friendly = { 0, 1, 0 },
        cast = { 1, 0.7, 0 }, castNoInterrupt = { 0.7, 0.7, 0.7 }, castChannel = { 0, 1, 0 },
        playerCast = { 1, 0.7, 0 }, playerChannel = { 0, 1, 0 },
        texture = "Interface\\AddOns\\FlareUI\\Media\\Bars\\FlareUI-Flat-Bright",
    },
}

function UF.ApplyPalette()
    local db = ns.db and ns.db.profile and ns.db.profile.unitframes
    UF.palette = (db and db.palette == "blizzard") and "blizzard" or "flareui"
    local p = UF.PALETTES[UF.palette]
    local function set(dst, src) dst[1], dst[2], dst[3] = src[1], src[2], src[3] end
    set(ns.HEALTH_GREEN, p.health)
    set(ns.MANA_BLUE, p.mana)
    set(GREY, p.grey)
    for reaction = 1, 8 do
        set(REACTION[reaction], reaction <= 3 and p.hostile or reaction == 4 and p.neutral or p.friendly)
    end
    set(CAST_COLOR, p.cast)
    set(CAST_NOINTERRUPT, p.castNoInterrupt)
    set(CAST_CHANNEL, p.castChannel)
    set(PLAYER_CAST_COLOR, p.playerCast)
    set(PLAYER_CAST_CHANNEL, p.playerChannel)
end

-- Power colours when PowerBarColor lacks one
local POWER_FALLBACK = {
    MANA        = { 0.00, 0.00, 1.00 },
    RAGE        = { 1.00, 0.00, 0.00 },
    FOCUS       = { 1.00, 0.50, 0.25 },
    ENERGY      = { 1.00, 1.00, 0.00 },
    RUNIC_POWER = { 0.00, 0.82, 1.00 },
    LUNAR_POWER = { 0.30, 0.52, 0.90 },
    MAELSTROM   = { 0.00, 0.50, 1.00 },
    INSANITY    = { 0.40, 0.00, 0.80 },
    FURY        = { 0.79, 0.26, 0.99 },
    PAIN        = { 1.00, 0.61, 0.00 },
}

-- Unit definitions. `driver` is the visibility condition; player is always shown.
local UNITS = {
    player = {
        key = "Player", label = L["Player"], order = 1, auras = true, portrait = true,
        blizzard = { "PlayerFrame" },
        events = { "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE" },
        globalEvents = { PLAYER_UPDATE_RESTING = true, GROUP_ROSTER_UPDATE = true, PARTY_LEADER_CHANGED = true,
                         PLAYER_FLAGS_CHANGED = "player", PVP_TIMER_UPDATE = true },
        indicators = { rest = true, leader = true, pvp = true, threat = true, heals = true, readyCheck = true,
                       pvpTimer = true, statusGlow = true, threatGlow = true },
    },
    target = {
        mirrorable = true,
        key = "Target", label = L["Target"], order = 2, auras = true, portrait = true,
        blizzard = { "TargetFrame" },
        driver = "[@target,exists] show; hide",
        globalEvents = { PLAYER_TARGET_CHANGED = true, GROUP_ROSTER_UPDATE = true, PARTY_LEADER_CHANGED = true, PLAYER_FLAGS_CHANGED = "target",
                         QUEST_LOG_UPDATE = true },
        castbar = true,
        comboPoints = true,
        indicators = { leader = true, pvp = true, classification = true, highSkull = true, quest = true, threat = true,
                       heals = true, readyCheck = true, threatGlow = true },
    },
    targettarget = {
        key = "TargetOfTarget", label = L["Target of Target"], order = 3, noRaidIcon = true,
        driver = "[@targettarget,exists] show; hide",
        globalEvents = { PLAYER_TARGET_CHANGED = true, UNIT_TARGET = "target" },
    },
    focus = {
        mirrorable = true,
        key = "Focus", label = L["Focus"], order = 4, auras = true, portrait = true,
        blizzard = { "FocusFrame", "TargetofFocusFrame" },
        driver = "[@focus,exists] show; hide",
        globalEvents = { PLAYER_FOCUS_CHANGED = true },
        castbar = true,
        indicators = { classification = true, highSkull = true, threat = true, heals = true, readyCheck = true,
                       threatGlow = true },
    },
    focustarget = {
        key = "TargetOfFocus", label = L["Target of Focus"], order = 6, noRaidIcon = true,
        driver = "[@focustarget,exists] show; hide",
        globalEvents = { PLAYER_FOCUS_CHANGED = true, UNIT_TARGET = "focus" },
        sample = { name = L["Target of Focus"] },
    },
    pet = {
        key = "Pet", label = L["Pet"], order = 5, happiness = true, noRaidIcon = true,
        sample = { name = L["Pet"], powerToken = "FOCUS", health = 0.85, power = 0.7 },
        blizzard = { "PetFrame" },
        driver = "[@pet,exists] show; hide",
        indicators = { heals = true },
        globalEvents = { UNIT_PET = "player" },
    },
}
local UNIT_ORDER = { "player", "target", "targettarget", "focus", "focustarget", "pet" }

-- The player's power events the target frame also takes, for its combo strip
local COMBO_EVENTS = { UNIT_POWER_FREQUENT = true, UNIT_MAXPOWER = true, UNIT_DISPLAYPOWER = true }

local UNIT_EVENTS = {
    "UNIT_HEALTH", "UNIT_MAXHEALTH",
    "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_POWER_FREQUENT",
    "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_FACTION", "UNIT_CONNECTION", "UNIT_FLAGS",
    "UNIT_CLASSIFICATION_CHANGED",
}

local CAST_EVENTS = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
}

local HEALTH_TEXT_MODES = {
    { text = L["None"],            value = "none",    isRadio = true },
    { text = L["Percent"],         value = "percent", isRadio = true },
    { text = L["Value"],           value = "value",   isRadio = true },
    { text = L["Value + Percent"], value = "both",    isRadio = true },
}

--------------------------------------------------
-- 4. HELPERS
--------------------------------------------------
local frames = {}          -- unit -> frame
local pendingLayout = false
local LayoutAuras          -- defined in 7

local function GetDb()
    if not ns.db or not ns.db.profile or not ns.db.profile.unitframes then return nil end
    return ns.db.profile.unitframes
end

local function GetUnitDb(unit)
    local db = GetDb()
    return db and db.units and db.units[unit]
end

-- Portrait: "none", "3d" or "class", a square taken from the bars. The ring styles always have one,
-- in the ring, and the bars keep their full width.
local function PortraitMode(f)
    local udb = GetUnitDb(f.unit)
    local mode = (f.Portrait and udb and udb.portrait) or "none"
    if mode == "none" and ns.UFRing and ns.UFRing.Applies(f) then mode = "3d" end
    return mode
end

local function PortraitSpace(f)
    if ns.UFRing and ns.UFRing.Applies(f) then return 0 end
    if PortraitMode(f) == "none" then return 0 end
    local udb = GetUnitDb(f.unit)
    return ((udb and udb.height) or 44) - 2 * INSET + PORTRAIT_GAP
end

-- The frame icons: one Show switch each in Edit Mode (udb.icons[key].shown); their places are fixed
local ICON_UI = {
    order = { "rest", "leader", "pvp", "pvpTimer", "classification", "highSkull", "quest", "raidIcon", "readyCheck",
              "statusGlow", "threatGlow", "happiness" },
    defs = {
        rest           = { label = L["Resting"],          field = "RestIcon" },
        leader         = { label = L["Leader"],           field = "LeaderIcon" },
        pvp            = { label = L["PvP Flag"],         field = "PvPIcon" },
        classification = { label = L["Elite & Rare"],     field = "ClassIcon", noRing = true },
        quest          = { label = L["Quest Objective"],  field = "QuestIcon" },
        raidIcon       = { label = L["Raid Markers"],      field = "RaidIcon" },
        happiness      = { label = L["Pet Happiness"],    field = "Happiness" },
        -- noRing: not in the ring styles (the dragon frame shows elites); ring: only in them
        readyCheck     = { label = L["Ready Check"],      field = "ReadyIcon" },
        pvpTimer       = { label = L["PvP Timer"],        default = false },
        -- threat: the ring's glow, or the border colour
        statusGlow     = { label = L["Rest & Combat Glow"], ring = true },
        -- the ring's level skull for a "??" unit that isn't a boss (bosses always have it)
        highSkull      = { label = L["High Level Skull"], ring = true },
        threatGlow     = { label = L["Threat Glow"] },
    },
    -- Blizzard's ready check marks
    READY = {
        ready    = _G.READY_CHECK_READY_TEXTURE or "UI-LFG-ReadyMark",
        notready = _G.READY_CHECK_NOT_READY_TEXTURE or "UI-LFG-DeclineMark",
        waiting  = _G.READY_CHECK_WAITING_TEXTURE or "UI-LFG-PendingMark",
    },
    HAPPINESS_GAP = 4,   -- the happiness face outside the frame
    READY_HOLD = 6,   -- seconds a finished check's results stay up
}

-- The icons a frame has, in dialog order
function ICON_UI.List(unit)
    local info, list = UNITS[unit], {}
    local ind = info and info.indicators or {}
    for _, key in ipairs(ICON_UI.order) do
        local has
        if key == "raidIcon" then has = not info.noRaidIcon
        elseif key == "happiness" then has = info.happiness
        elseif key == "quest" then has = ind.quest
        else has = ind[key] end
        if has then list[#list + 1] = key end
    end
    return list
end

function ICON_UI.Store(unit, key, create)
    local udb = GetUnitDb(unit)
    if not udb then return nil end
    if create then
        udb.icons = udb.icons or {}
        udb.icons[key] = udb.icons[key] or {}
    end
    return udb.icons and udb.icons[key]
end

-- every icon starts shown except those with default = false
function ICON_UI.Shown(unit, key)
    local store = ICON_UI.Store(unit, key)
    if store and store.shown ~= nil then return store.shown end
    return ICON_UI.defs[key].default ~= false
end

function ICON_UI.Place(region, width, height, point, relativeTo, relativePoint, x, y)
    region:ClearAllPoints()
    region:SetSize(width, height)
    region:SetPoint(point, relativeTo, relativePoint, x, y)
end

-- Percent curve (0..1 -> 0..100) so UnitHealthPercent's secret result can be shown directly
local percentCurve = CurveConstants.ScaleTo100

-- An unknown name falls back to FlareUI Forever; mirrored: its right-to-left gradient file
local function GetBarTexture(name, mirrored)
    if not (name and name ~= "" and LSM:IsValid("statusbar", name)) then name = DEFAULT_TEXTURE end
    if name == "FlareUI Flat" and UF.palette == "blizzard" then return UF.PALETTES.blizzard.texture end
    if mirrored and name == "FlareUI Forever" then return "Interface\\AddOns\\FlareUI\\Media\\Bars\\FlareUI-Forever-Mirrored.tga" end
    return LSM:Fetch("statusbar", name) or "Interface\\TargetingFrame\\UI-StatusBar"
end

-- An unknown border name falls back to the default
local function GetBorderFile(name)
    if not (name and name ~= "" and LSM:IsValid("border", name)) then name = DEFAULT_BORDER end
    return LSM:Fetch("border", name) or BORDER_FILE
end

-- fixed bronze at rest, a status colour (threat) otherwise
local function ResetBorderTint(border)
    local c = DEFAULT_BORDER_COLOR
    border:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
end

local function SetBorderTint(border, r, g, b)
    border:SetBackdropBorderColor(r, g, b, 1)
end

-- Edge and inset for a bar of this inner height: under 22 px the 16 px corners overlap, so both
-- shrink (FlareUI Thin's 8 px corners fit any bar)
local function BorderFit(innerHeight, edgeFile)
    if edgeFile and ns.BorderEdgeSize(edgeFile, BORDER_SIZE) ~= BORDER_SIZE then
        return ns.BorderEdgeSize(edgeFile, BORDER_SIZE), INSET
    end
    local total = innerHeight + 2 * INSET
    if total >= 22 then return BORDER_SIZE, INSET end
    local edge = math.max(6, math_floor(total * 2 / 3))
    return edge, INSET * edge / BORDER_SIZE
end

-- height: the bordered frame's height (BorderFit's rule). The thick edge fades on its inner side,
-- leaving a see-through seam, so it sits one scaled pixel in, over the bars' edges.
local function ApplyBorderStyle(border, edgeFile, height)
    local edge, thick = BORDER_SIZE, true
    if ns.BorderEdgeSize(edgeFile, BORDER_SIZE) ~= BORDER_SIZE then
        edge, thick = ns.BorderEdgeSize(edgeFile, BORDER_SIZE), false
    elseif height and height < 22 then
        edge = math.max(6, math_floor(height * 2 / 3))
    end
    local _, rel = border:GetPoint(1)
    rel = rel or border:GetParent()
    local d = thick and edge / BORDER_SIZE or 0
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", rel, "TOPLEFT", d, -d)
    border:SetPoint("BOTTOMRIGHT", rel, "BOTTOMRIGHT", -d, d)
    border:SetBackdrop({ edgeFile = edgeFile, edgeSize = edge })
    ResetBorderTint(border)
end

local function CreateBar(parent, level)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetFrameLevel(level)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetVertexColor(0.15, 0.15, 0.15, UF.BAR_BG_OPACITY / 100)
    return bar
end

-- "Background Opacity": the bars' empty part, in percent; 0 on the plate, whose slot shows there
UF.BAR_BG_OPACITY = 90
function UF.DefaultBgOpacity(unit)
    local plate = ns.UFRing and ns.UFRing.PlateOn() and ns.UFRing.PLATE_UNITS[unit] and ns.UFRing.Applies(frames[unit])
    return plate and 0 or UF.BAR_BG_OPACITY
end

function UF.SetBarBackground(bar, percent)
    if not bar.bg then return end
    if percent == nil then percent = UF.BAR_BG_OPACITY end
    bar.bg:SetAlpha(1)
    bar.bg:SetVertexColor(0.15, 0.15, 0.15, math.max(0, math.min(100, percent)) / 100)
end

function UF.BgOpacitySetting(default, get, set)
    return { name = L["Background Opacity"], kind = LEM.SettingType.Slider, default = default,
        minValue = 0, maxValue = 100, valueStep = 5,
        formatter = function(value) return value .. "%" end,
        get = get, set = set,
        desc = L["How dark the empty part of the bars is."] }
end

local function ApplyFont(fontString, fontDb, sizeDelta)
    local path = ns.GetFontPath(fontDb and fontDb.face or "Friz Quadrata TT")
    local flags = fontDb and fontDb.flags or "OUTLINE"
    if flags == "NONE" then flags = "" end
    fontString:SetFont(path, (fontDb and fontDb.size or 12) + (sizeDelta or 0), flags)
    ns.ApplyShadow(fontString, fontDb)
end

-- Health bar colour: class colour for players (green with Class Color off), reaction colour for
-- NPCs. A secret class falls back to the reaction colour, a secret reaction to friendly.
local function GetHealthColor(unit, classColor)
    if not UnitIsConnected(unit) then return GREY[1], GREY[2], GREY[3] end
    if UnitIsPlayer(unit) and not classColor then return ns.HEALTH_GREEN[1], ns.HEALTH_GREEN[2], ns.HEALTH_GREEN[3] end
    if UnitIsPlayer(unit) then
        local _, classFile = UnitClass(unit)
        if canaccessvalue(classFile) and classFile then
            local color = C_ClassColor.GetClassColor(classFile)
            if color then return color:GetRGB() end
        end
    end
    if UnitIsTapDenied(unit) then return GREY[1], GREY[2], GREY[3] end
    local reaction = Readable(UnitReaction(unit, "player"))
    local c = reaction and REACTION[reaction] or REACTION[5]
    return c[1], c[2], c[3]
end

local function GetPowerColor(unit)
    local powerType, powerToken = UnitPowerType(unit)
    local r, g, b = ns.PowerColor(powerToken, powerType)
    if r then return r, g, b end
    local c = POWER_FALLBACK[Readable(powerToken) or "MANA"] or POWER_FALLBACK.MANA
    return c[1], c[2], c[3]
end

local hiddenParent = CreateFrame("Frame", nil, UIParent)
hiddenParent:Hide()

-- Parks a Blizzard unit frame (an Edit Mode system) where it can never come back
local function HardHide(name)
    local frame = _G[name]
    if not frame or frame.FlareUI_Hidden then return end
    frame.FlareUI_Hidden = true
    pcall(frame.UnregisterAllEvents, frame)
    for _, key in ipairs({ "healthbar", "manabar", "spellbar", "castBar", "totFrame", "petFrame", "powerBarAlt" }) do
        local child = frame[key]
        if child and child.UnregisterAllEvents then pcall(child.UnregisterAllEvents, child) end
    end
    if not InCombatLockdown() then
        pcall(ns.RawHide, frame)
        pcall(frame.SetParent, frame, hiddenParent)
    end
    hooksecurefunc(frame, "Show", function(f) if not InCombatLockdown() then ns.RawHide(f) end end)
end

-- Gamepad UI: the target menu opens on TargetFrame and closes if it is hidden, so TargetFrame stays
-- shown, silent, invisible and mouse-deaf, pinned over this target frame. Out of combat only.
local function KeepAsMenuOwner(name, over)
    local frame = _G[name]
    if not frame or frame.FlareUI_Hidden then return end
    if InCombatLockdown() then
        local waiter = CreateFrame("Frame")
        waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
        waiter:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            KeepAsMenuOwner(name, over)
        end)
        return
    end
    frame.FlareUI_Hidden = true
    pcall(frame.UnregisterAllEvents, frame)
    for _, key in ipairs({ "healthbar", "manabar", "spellbar", "castBar", "totFrame", "petFrame", "powerBarAlt" }) do
        local child = frame[key]
        if child and child.UnregisterAllEvents then pcall(child.UnregisterAllEvents, child) end
    end
    frame:SetAlpha(0)
    local function Deafen(f)
        if f.IsMouseEnabled and f:IsMouseEnabled() then f:EnableMouse(false) end
        if f.IsMouseClickEnabled and f:IsMouseClickEnabled() then f:SetMouseClickEnabled(false) end
        for _, child in ipairs({ f:GetChildren() }) do Deafen(child) end
    end
    Deafen(frame)
    local placing = false
    local function Pin()
        if placing or InCombatLockdown() then return end
        placing = true
        local clear, setPoint = frame.ClearAllPointsBase or frame.ClearAllPoints, frame.SetPointBase or frame.SetPoint
        clear(frame)
        setPoint(frame, "TOPLEFT", over, "TOPLEFT")
        setPoint(frame, "BOTTOMRIGHT", over, "BOTTOMRIGHT")
        placing = false
    end
    Pin()
    hooksecurefunc(frame, "SetPoint", Pin)
    frame:Show()
    hooksecurefunc(frame, "Hide", function(f) if not InCombatLockdown() then f:Show() end end)
end

-- the parked TargetFrame no longer plays the target-select sounds, so they play here
do
    local listener = CreateFrame("Frame")
    listener:RegisterEvent("PLAYER_TARGET_CHANGED")
    listener:SetScript("OnEvent", function()
        local blizzard = _G.TargetFrame
        if not (blizzard and blizzard.FlareUI_Hidden) or not UnitExists("target") then return end
        local interaction = C_PlayerInteractionManager
        if interaction and interaction.IsReplacingUnit and interaction.IsReplacingUnit() then return end
        if Readable(UnitIsEnemy("target", "player")) then
            PlaySound(SOUNDKIT.IG_CREATURE_AGGRO_SELECT)
        elseif Readable(UnitIsFriend("player", "target")) then
            PlaySound(SOUNDKIT.IG_CHARACTER_NPC_SELECT)
        else
            PlaySound(SOUNDKIT.IG_CREATURE_NEUTRAL_SELECT)
        end
    end)
end

--------------------------------------------------
-- 5. UPDATERS (all secret-safe: values go straight into widgets)
--------------------------------------------------
local function UpdateName(f)
    -- focus: first name only outside Forever Style
    f.Name:SetText(ns.UnitDisplayName(f.unit, f.unit == "focus" and "focus" or nil) or "")
end

local function UpdateLevel(f)
    local unit = f.unit
    local udb = GetUnitDb(unit)
    if not (udb and udb.showLevel) then f.Level:SetText("") return end
    local level = UnitLevel(unit)
    local classification = Readable(UnitClassification(unit))
    local suffix = ""
    if classification == "elite" or classification == "rareelite" then suffix = "+" end
    if classification == "rare" or classification == "rareelite" then suffix = "R" .. suffix end
    if canaccessvalue(level) and level then
        if level < 0 then
            f.Level:SetText("??")
            f.Level:SetTextColor(1, 0.1, 0.1)
        else
            f.Level:SetFormattedText("%d%s", level, suffix)
            -- friendly: Blizzard's gold; neutral and hostile: by difficulty
            local color = ns.UnitLevelColor(unit, level)
            if color then f.Level:SetTextColor(color.r, color.g, color.b) else f.Level:SetTextColor(1, 1, 1) end
        end
    else
        f.Level:SetText(level)
        f.Level:SetTextColor(1, 1, 1)
    end
    -- ring styles: the player's level is white, as on Blizzard's frame
    if unit == "player" and ns.UFRing and ns.UFRing.Applies(f) then f.Level:SetTextColor(1, 1, 1) end
end

local function UpdateHealth(f)
    local unit = f.unit
    local udb = GetUnitDb(unit)
    local bar = f.Health

    -- Edit Mode: sample health in the unit's colour when there is one
    if LEM:IsInEditMode() then
        local health = (UNITS[unit].sample or {}).health or 0.75
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(health)
        if UnitExists(unit) then
            bar:SetStatusBarColor(GetHealthColor(unit, ns.ClassColorsOn()))
        else
            local c = REACTION[5]
            bar:SetStatusBarColor(c[1], c[2], c[3])
        end
        local mode = udb and udb.healthText or "percent"
        local value = AbbreviateNumbers(math_floor(health * 24000))
        if mode == "percent" then
            f.HealthText:SetFormattedText("%.0f%%", health * 100)
        elseif mode == "value" then
            f.HealthText:SetText(value)
        elseif mode == "both" then
            f.HealthText:SetFormattedText("%s | %.0f%%", value, health * 100)
        else
            f.HealthText:SetText("")
        end
        return
    end

    bar:SetMinMaxValues(0, UnitHealthMax(unit))
    bar:SetValue(UnitHealth(unit))
    bar:SetStatusBarColor(GetHealthColor(unit, ns.ClassColorsOn()))

    local mode = udb and udb.healthText or "percent"
    local text = f.HealthText
    if not UnitIsConnected(unit) then
        text:SetText(OFFLINE_TEXT)
    elseif UnitIsDeadOrGhost(unit) then
        text:SetText(UnitIsGhost(unit) and GHOST_TEXT or DEAD_TEXT)
    elseif mode == "percent" then
        text:SetFormattedText("%.0f%%", UnitHealthPercent(unit, true, percentCurve))
    elseif mode == "value" then
        text:SetText(AbbreviateNumbers(UnitHealth(unit)))
    elseif mode == "both" then
        text:SetFormattedText("%s | %.0f%%", AbbreviateNumbers(UnitHealth(unit)), UnitHealthPercent(unit, true, percentCurve))
    else
        text:SetText("")
    end
end

local function UpdatePower(f)
    local unit = f.unit
    local udb = GetUnitDb(unit)
    local bar = f.Power
    local powerType = UnitPowerType(unit)
    bar:SetMinMaxValues(0, UnitPowerMax(unit, powerType))
    bar:SetValue(UnitPower(unit, powerType))
    bar:SetStatusBarColor(GetPowerColor(unit))
    if f.ManaCost then f.ManaCost:Refresh(powerType) end
    if udb and udb.powerText and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) then
        f.PowerText:SetText(AbbreviateNumbers(UnitPower(unit, powerType)))
    else
        f.PowerText:SetText("")
    end
end

-- GetRaidTargetIndex can be secret. A secret is never nil, so it still means a marker is set, and
-- SetRaidTargetIconTexture takes it as is.
local function UpdateRaidIcon(f)
    if UNITS[f.unit].noRaidIcon then
        f.RaidIcon:Hide()
        return
    end
    local index = GetRaidTargetIndex(f.unit)
    local show
    if not ICON_UI.Shown(f.unit, "raidIcon") then
        show = false
    elseif not canaccessvalue(index) then
        show = true
    else
        show = index ~= nil and index > 0
    end
    if show then SetRaidTargetIconTexture(f.RaidIcon, index) end
    f.RaidIcon:SetShown(show)
    ICON_UI.Preview(f)
end

--------------------------------------------------
-- 6. CAST BARS
-- Target / focus bars and the standalone player bar. The client drives the bar (SetTimerDuration)
-- and the timer text (a duration text binding), so both move even when the cast data is secret.
--------------------------------------------------
local SAMPLE_CAST_SECONDS = 3
local SAMPLE_CAST_ICON = "Interface\\Icons\\Spell_Fire_FlameBolt"
local sampleCastTicker
local castBars = {}          -- every cast bar object, for previews

local timerFormatter
local function GetTimerFormatter()
    if timerFormatter ~= nil then return timerFormatter or nil end
    timerFormatter = false
    -- one decimal
    local ok, fmt = pcall(C_StringUtil.CreateNumericRuleFormatter)
    if ok and fmt and pcall(fmt.SetBreakpoints, fmt, { { threshold = 0, format = "%.1f" } }) then
        timerFormatter = fmt
    end
    -- fallback: whole seconds
    if not timerFormatter then
        ok, fmt = pcall(C_StringUtil.CreateSecondsFormatter)
        if ok and fmt then timerFormatter = fmt end
    end
    return timerFormatter or nil
end

-- style: { height, icon, timer, name, texture, border, borderTexture, width }
local function GetCastStyle(udb, standalone)
    if standalone then
        return {
            width = udb.width or 250, height = udb.height or 25,
            icon = udb.icon ~= false, timer = udb.timer ~= false, name = true,
            texture = udb.texture, border = true,
            borderTexture = ns.UFRing and ns.UFRing.Border(udb.borderTexture) or udb.borderTexture,
            bgOpacity = udb.bgOpacity,
        }
    end
    local castTexture = udb.castTexture
    if castTexture == "" then castTexture = udb.texture end
    local castBorder = udb.castBorderTexture
    if castBorder == "" then castBorder = udb.border end
    return {
        height = udb.castHeight or CAST_HEIGHT,
        icon = udb.castIcon ~= false, timer = udb.castTimer ~= false, name = true,
        texture = castTexture, border = true,
        borderTexture = ns.UFRing and ns.UFRing.Border(castBorder) or castBorder,
        bgOpacity = udb.bgOpacity,
    }
end

local function CreateCastBar(parent, unit)
    local cast = CreateBar(parent, parent:GetFrameLevel() + 1)
    cast.unit = unit
    cast:SetMinMaxValues(0, 1)
    cast:Hide()

    cast.Backdrop = CreateFrame("Frame", nil, cast, "BackdropTemplate")
    cast.Backdrop:SetFrameLevel(cast:GetFrameLevel() - 1)
    cast.Border = CreateFrame("Frame", nil, cast, "BackdropTemplate")
    cast.Border:SetFrameLevel(cast:GetFrameLevel() + 2)

    cast.Icon = cast:CreateTexture(nil, "ARTWORK")
    cast.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local overlay = CreateFrame("Frame", nil, cast)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(cast:GetFrameLevel() + 3)
    cast.Text = overlay:CreateFontString(nil, "OVERLAY")
    cast.Text:SetJustifyH("LEFT")
    cast.Text:SetWordWrap(false)
    cast.Time = overlay:CreateFontString(nil, "OVERLAY")
    cast.Time:SetJustifyH("RIGHT")

    -- remaining time, formatted by the client: SetFormatter (SetTextFormat takes "{}" placeholders)
    local ok, binding = pcall(C_DurationUtil.CreateDurationTextBinding)
    if ok and binding then
        pcall(binding.SetFontString, binding, cast.Time)
        local fmt = GetTimerFormatter()
        if fmt then pcall(binding.SetFormatter, binding, fmt) end
        pcall(binding.SetZeroDurationText, binding, "")
        -- without these the binding renders once; the interval is the minimum gap between updates
        pcall(binding.SetUpdateInterval, binding, 0.05)
        pcall(binding.Enable, binding)
        cast.TimerBinding = binding
    end

    -- shown / hidden: the owner moves the auras on the cast bar's side (cast.onShownChanged)
    local function ShownChanged(self) if self.onShownChanged then self.onShownChanged(self) end end
    cast:HookScript("OnShow", ShownChanged)
    cast:HookScript("OnHide", ShownChanged)

    castBars[#castBars + 1] = cast
    return cast
end

local function SetCastTimer(cast, duration)
    if cast.TimerBinding and duration then
        pcall(cast.TimerBinding.SetDuration, cast.TimerBinding, duration)
    end
end

-- mode "TOP" / "BOTTOM" hangs the bar off a unit frame; "FILL" fills the standalone holder. The
-- icon sits left of the bar; the border wraps both.
-- leftExtra / rightExtra: more room from the anchor's edges (the ring)
local function LayoutCastBar(cast, style, anchor, mode, leftExtra, rightExtra)
    local db = GetDb()
    if not db then return end
    local PADDING = INSET
    leftExtra, rightExtra = leftExtra or 0, rightExtra or 0
    local edgeFile = GetBorderFile(style.borderTexture)
    local texture = GetBarTexture(style.texture)
    local height = style.height
    local iconOffset = style.icon and (height + CAST_ICON_GAP) or 0

    cast.style = style
    cast:SetStatusBarTexture(texture)
    cast.bg:SetTexture(texture)
    UF.SetBarBackground(cast, style.bgOpacity)
    cast:ClearAllPoints()
    if mode == "TOP" then
        cast:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", PADDING + iconOffset + leftExtra, CAST_GAP)
        cast:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", -PADDING - rightExtra, CAST_GAP)
        cast:SetHeight(height)
    elseif mode == "BOTTOM" then
        cast:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", PADDING + iconOffset + leftExtra, -CAST_GAP)
        cast:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", -PADDING - rightExtra, -CAST_GAP)
        cast:SetHeight(height)
    else
        local _, pad = BorderFit(height, edgeFile)
        cast:SetPoint("TOPLEFT", anchor, "TOPLEFT", pad + iconOffset, -pad)
        cast:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -pad, pad)
    end

    cast.Icon:ClearAllPoints()
    cast.Icon:SetSize(height, height)
    cast.Icon:SetPoint("RIGHT", cast, "LEFT", -CAST_ICON_GAP, 0)
    cast.Icon:SetShown(style.icon)

    -- the border wrap: the inset shrinks with the edge on a thin bar (BorderFit)
    local _, wrap = BorderFit(height, style.border and edgeFile)
    cast.Backdrop:ClearAllPoints()
    cast.Backdrop:SetPoint("TOPLEFT", style.icon and cast.Icon or cast, "TOPLEFT", -wrap, wrap)
    cast.Backdrop:SetPoint("BOTTOMRIGHT", cast, "BOTTOMRIGHT", wrap, -wrap)
    cast.Backdrop:SetBackdrop({ bgFile = BACKDROP_FILE, insets = { left = wrap, right = wrap, top = wrap, bottom = wrap } })
    cast.Backdrop:SetBackdropColor(0, 0, 0, BG_OPACITY)
    cast.Border:ClearAllPoints()
    cast.Border:SetAllPoints(cast.Backdrop)
    if style.border then
        ApplyBorderStyle(cast.Border, edgeFile, height + 2 * PADDING)
        cast.Border:Show()
    else
        cast.Border:Hide()
    end

    ApplyFont(cast.Text, db.fontCast or db.font)
    ApplyFont(cast.Time, db.fontCast or db.font)
    cast.Time:ClearAllPoints()
    cast.Time:SetPoint("RIGHT", cast, "RIGHT", -TEXT_INSET, 0)
    cast.Time:SetShown(style.timer)
    cast.Text:ClearAllPoints()
    cast.Text:SetPoint("LEFT", cast, "LEFT", TEXT_INSET, 0)
    if style.timer then
        cast.Text:SetPoint("RIGHT", cast.Time, "LEFT", -4, 0)
    else
        cast.Text:SetPoint("RIGHT", cast, "RIGHT", -TEXT_INSET, 0)
    end
    cast.Text:SetShown(style.name)
end

-- Edit Mode: a looping 3 s sample cast so the bar can be placed without a casting unit
local function ShowSampleCast(cast)
    local duration = C_DurationUtil.CreateDuration()
    duration:SetTimeFromStart(GetTime(), SAMPLE_CAST_SECONDS)
    cast:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, Enum.StatusBarTimerDirection.ElapsedTime)
    SetCastTimer(cast, duration)
    cast.Text:SetText(L["Sample Cast"])
    cast.Icon:SetTexture(SAMPLE_CAST_ICON)
    local color = cast.standalone and PLAYER_CAST_COLOR or CAST_COLOR
    cast:SetStatusBarColor(color[1], color[2], color[3])
    cast:Show()
end

local function UpdateCastBar(cast, enabled)
    if not enabled then cast:Hide() return end
    if LEM:IsInEditMode() then ShowSampleCast(cast) return end
    local unit = cast.unit

    local channeling = false
    local n = select("#", UnitCastingInfo(unit))
    local name, text, texture, _, _, _, _, notInterruptible
    if n > 0 then
        name, text, texture, _, _, _, _, notInterruptible = UnitCastingInfo(unit)
    else
        n = select("#", UnitChannelInfo(unit))
        if n > 0 then
            name, text, texture, _, _, _, notInterruptible = UnitChannelInfo(unit)
            channeling = true
        end
    end
    if n == 0 then
        cast:Hide()
        return
    end

    local duration = channeling and UnitChannelDuration(unit) or UnitCastingDuration(unit)
    if not duration then cast:Hide() return end
    local direction = channeling and Enum.StatusBarTimerDirection.RemainingTime or Enum.StatusBarTimerDirection.ElapsedTime
    cast:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, direction)
    SetCastTimer(cast, duration)

    -- `text or name` would boolean-test a secret; only pick when the value is readable
    local label = text
    if canaccessvalue(text) then label = text or name or "" end
    cast.Text:SetText(label)
    if canaccessvalue(texture) and texture then
        cast.Icon:SetTexture(texture)
    else
        cast.Icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end

    local color
    if cast.standalone then
        color = channeling and PLAYER_CAST_CHANNEL or PLAYER_CAST_COLOR
    else
        color = channeling and CAST_CHANNEL or CAST_COLOR
    end
    if canaccessvalue(notInterruptible) and notInterruptible then
        color = CAST_NOINTERRUPT
    end
    cast:SetStatusBarColor(color[1], color[2], color[3])
    cast:Show()
end

local function IsCastEnabled(cast)
    if cast.isEnabled then return cast.isEnabled() end
    if cast.standalone then
        local db = GetDb()
        return db and db.playerCastbar and db.playerCastbar.enabled
    end
    return true
end

local function UpdateCast(f)
    if f.Cast then UpdateCastBar(f.Cast, IsCastEnabled(f.Cast)) end
end

local function SetCastPreview(enabled)
    if sampleCastTicker then sampleCastTicker:Cancel() sampleCastTicker = nil end
    if enabled then
        local function tick()
            for _, cast in ipairs(castBars) do
                if IsCastEnabled(cast) then ShowSampleCast(cast) end
            end
        end
        tick()
        sampleCastTicker = C_Timer.NewTicker(SAMPLE_CAST_SECONDS, tick)
    else
        for _, cast in ipairs(castBars) do UpdateCastBar(cast, IsCastEnabled(cast)) end
    end
end

local UpdateComboPoints   -- defined in 10 (needs the layout helpers)
local UpdateHappiness     -- defined in 8c
local UpdateIndicators, UpdateHealPrediction, UpdateThreat   -- defined in 9

-- Blizzard's portrait faces right for players and friendly NPCs, left for most hostile creatures.
-- A mirrored frame flips the right-facing ones; anything unreadable counts as right-facing.
local function PortraitFacesRight(unit)
    local isPlayer = UnitIsPlayer(unit)
    if not canaccessvalue(isPlayer) or isPlayer then return true end
    local reaction = UnitReaction("player", unit)
    if not canaccessvalue(reaction) or not reaction then return true end
    return reaction >= 5
end

-- Blizzard's render can reset the coordinates just after SetPortraitTexture: the flip is held for a second
local function KeepPortraitFlipped(portrait)
    if portrait.Tex:GetTexCoord() ~= 1 then portrait.Tex:SetTexCoord(1, 0, 0, 1) end
    if GetTime() > portrait.flipUntil then portrait:SetScript("OnUpdate", nil) end
end

-- 3D is Blizzard's static portrait (square, unmasked). Class Icon falls back to 3D for NPCs and
-- secret classes. A frame with no unit (Edit Mode) shows the player.
local function UpdatePortrait(f)
    local portrait = f.Portrait
    if not portrait then return end
    local mode = PortraitMode(f)
    if mode == "none" then
        portrait:Hide()
        return
    end
    local unit = UnitExists(f.unit) and f.unit or "player"
    local tex = portrait.Tex
    local class
    if mode == "class" then
        local isPlayer = UnitIsPlayer(unit)
        if canaccessvalue(isPlayer) and isPlayer then
            local _, classFile = UnitClass(unit)
            if canaccessvalue(classFile) then class = classFile end
        end
    end
    if class then
        portrait:SetScript("OnUpdate", nil)
        tex:SetAtlas(GetClassAtlas(class), false, nil, true)   -- reset coords: SetAtlas keeps a 3D flip otherwise
    else
        SetPortraitTexture(tex, unit, true)
        local udb = GetUnitDb(f.unit)
        if udb and UF.LayoutMirrored(f) and PortraitFacesRight(unit) then
            tex:SetTexCoord(1, 0, 0, 1)
            portrait.flipUntil = GetTime() + 1
            portrait:SetScript("OnUpdate", KeepPortraitFlipped)
        else
            portrait:SetScript("OnUpdate", nil)
            tex:SetTexCoord(0, 1, 0, 1)
        end
    end
    portrait:Show()
end

-- Edit Mode with no unit behind the frame: sample values, texts per the frame's settings
local function ApplySample(f)
    local info, udb = UNITS[f.unit], GetUnitDb(f.unit)
    local s = info.sample or {}
    local power = s.power or 0.6
    f.Name:SetText(s.name or info.label)
    if udb and udb.showLevel then
        f.Level:SetText(UnitLevel("player") or "")
        f.Level:SetTextColor(1, 0.82, 0)
    else
        f.Level:SetText("")
    end
    UpdateHealth(f)
    f.Power:SetMinMaxValues(0, 1)
    f.Power:SetValue(power)
    local r, g, b = ns.PowerColor(s.powerToken or "MANA")
    f.Power:SetStatusBarColor(r or ns.MANA_BLUE[1], g or ns.MANA_BLUE[2], b or ns.MANA_BLUE[3])
    f.PowerText:SetText((udb and udb.powerText) and AbbreviateNumbers(math_floor(power * 3000)) or "")
end

local function UpdateAll(f)
    if LEM:IsInEditMode() and not UnitExists(f.unit) then
        ApplySample(f)
        UpdateRaidIcon(f)
        UpdateCast(f)
        if f.Combo then UpdateComboPoints(f) end
        UpdateIndicators(f)
        UpdateThreat(f)
        UpdateHealPrediction(f)
        UpdateHappiness(f)
        UpdatePortrait(f)
        return
    end
    UpdateName(f)
    UpdateLevel(f)
    UpdateHealth(f)
    UpdatePower(f)
    UpdateRaidIcon(f)
    UpdateCast(f)
    if f.Combo then UpdateComboPoints(f) end
    UpdateIndicators(f)
    UpdateThreat(f)
    UpdateHealPrediction(f)
    UpdateHappiness(f)
    UpdatePortrait(f)
end

-- the most frequent events first
local function OnUnitEvent(f, event, arg1, arg2)
    if arg1 == "player" and f.unit ~= "player" and COMBO_EVENTS[event] then
        -- the player's energy ticks are not combo point changes
        if event == "UNIT_POWER_FREQUENT" and canaccessvalue(arg2) and arg2 ~= "COMBO_POINTS" then return end
        if f.Combo then UpdateComboPoints(f) end
        return
    end
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        UpdateHealth(f)
    elseif event == "UNIT_POWER_FREQUENT" or event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER"
        or event == "UNIT_DISPLAYPOWER" then
        UpdatePower(f)
    elseif event == "UNIT_THREAT_LIST_UPDATE" or event == "UNIT_THREAT_SITUATION_UPDATE" then
        UpdateThreat(f)
    elseif event == "UNIT_HEAL_PREDICTION" or event == "UNIT_ABSORB_AMOUNT_CHANGED" then
        UpdateHealPrediction(f)
    elseif event == "PLAYER_UPDATE_RESTING" or event == "GROUP_ROSTER_UPDATE" or event == "PARTY_LEADER_CHANGED"
        or event == "PLAYER_FLAGS_CHANGED" or event == "QUEST_LOG_UPDATE" or event == "PVP_TIMER_UPDATE" then
        UpdateIndicators(f)
    elseif event == "UNIT_NAME_UPDATE" then
        UpdateName(f)
    elseif event == "UNIT_LEVEL" or event == "UNIT_CLASSIFICATION_CHANGED" then
        UpdateLevel(f)
    elseif event == "UNIT_FACTION" or event == "UNIT_CONNECTION" or event == "UNIT_FLAGS" then
        UpdateHealth(f)
        UpdatePower(f)
        if f.Combo then UpdateComboPoints(f) end   -- a target can turn hostile (duels, mind control)
    elseif event == "RAID_TARGET_UPDATE" then
        UpdateRaidIcon(f)
    elseif event == "READY_CHECK" or event == "READY_CHECK_CONFIRM" or event == "READY_CHECK_FINISHED" then
        ICON_UI.UpdateReady(f, event)
    elseif event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED" then
        UpdatePortrait(f)
    elseif event:find("^UNIT_SPELLCAST") then
        UpdateCast(f)
    else
        UpdateAll(f)   -- the unit behind the token changed
        -- the containers only follow UNIT_AURA: a new unit would keep the old one's auras, so
        -- they rebuild, as Blizzard's TargetFrame does (not protected: fine in combat)
        if f.Auras then
            for _, entry in pairs(f.Auras) do
                if entry.container:IsShown() then pcall(entry.container.UpdateAllAuras, entry.container) end
            end
        end
    end
end

--------------------------------------------------
-- 7. AURAS (Blizzard's aura containers)
-- Aura data can be secret, so Blizzard's CustomAuraContainer renders the icons. One container per
-- place, created at login (later ones are access-restricted and never show).
--------------------------------------------------
local AURA_CONTAINER_TEMPLATE = "CustomAuraContainerTemplate"
-- TOP and BOTTOM take the frame's whole width
local AURA_CORNERS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT", "TOP", "BOTTOM" }
local AURA = { FULL = { TOP = true, BOTTOM = true } }
local AURA_SPACING = 2
local auraSupport   -- nil = unknown, true / false after the first probe

local function HasAuraSupport()
    if auraSupport ~= nil then return auraSupport end
    auraSupport = false
    if C_AddOns.DoesAddOnExist("Blizzard_AuraContainer") and not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
    end
    local ok, probe = pcall(CreateFrame, "AuraContainer", nil, hiddenParent, AURA_CONTAINER_TEMPLATE)
    if ok and probe and type(probe.AddAuraGroup) == "function" and type(probe.SetFlowLayoutAxis) == "function" then
        auraSupport = true
    end
    return auraSupport
end

-- initializeFrame: a pooled button's visuals, built once; the button drives them. look: the Buffs /
-- Debuffs look (ns.AuraLook), else the plain style.
local function InitAuraButton(button, size, isDebuff, unit, font, showTimer, look)
    if look then
        ns.AuraLook.Style(button, look)
        ns.AuraLook.Hook(button, look)
        return
    end
    button:SetSize(size, size)
    if not button.FlareUI_Icon then
        local bg = button:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 1)

        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", -1, 1)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.FlareUI_Icon = icon

        local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        cd:SetAllPoints(icon)
        cd:SetReverse(true)
        cd:SetDrawEdge(false)
        cd:SetDrawBling(false)
        cd:SetHideCountdownNumbers(true)
        button.FlareUI_Cooldown = cd

        local overlay = CreateFrame("Frame", nil, button)
        overlay:SetAllPoints()
        overlay:SetFrameLevel(cd:GetFrameLevel() + 5)
        button.FlareUI_Overlay = overlay

        local dispel = overlay:CreateTexture(nil, "OVERLAY", nil, 1)
        dispel:SetPoint("TOPLEFT", -1, 1)
        dispel:SetPoint("BOTTOMRIGHT", 1, -1)
        button.FlareUI_Dispel = dispel

        local count = overlay:CreateFontString(nil, "OVERLAY")
        count:SetDrawLayer("OVERLAY", 3)   -- above the dispel border
        count:SetPoint("BOTTOMRIGHT", -1, 1)
        count:SetJustifyH("RIGHT")
        button.FlareUI_Count = count

        local duration = overlay:CreateFontString(nil, "OVERLAY")
        duration:SetDrawLayer("OVERLAY", 3)
        duration:SetPoint("CENTER", 0, 0)
        duration:SetJustifyH("CENTER")
        button.FlareUI_Duration = duration
    end

    local fontPath = ns.GetFontPath(font and font.face or "Friz Quadrata TT")
    local textSize = math.max(8, math_floor(size * 0.45))
    button.FlareUI_Count:SetFont(fontPath, textSize, "OUTLINE")
    button.FlareUI_Duration:SetFont(fontPath, math.max(8, textSize - 1), "OUTLINE")
    ns.ApplyShadow(button.FlareUI_Count, font)
    ns.ApplyShadow(button.FlareUI_Duration, font)
    -- Blizzard shows and fills the duration text itself, so it is hidden by alpha
    button.FlareUI_Duration:SetAlpha(showTimer and 1 or 0)

    pcall(button.SetIcon, button, button.FlareUI_Icon)
    pcall(button.SetDurationCooldown, button, button.FlareUI_Cooldown)
    pcall(button.SetApplicationCount, button, button.FlareUI_Count, {})
    pcall(button.SetDurationText, button, button.FlareUI_Duration, {})
    pcall(button.ClearDispelTypeTextures, button)
    if isDebuff and Enum.CustomAuraButtonDispelTypeTextureStyle then
        button.FlareUI_Dispel:Show()
        pcall(button.AddDispelTypeTexture, button, button.FlareUI_Dispel, {
            style = Enum.CustomAuraButtonDispelTypeTextureStyle.Border,
            showWhenHarmful = true,
            showWhenHelpful = false,
        })
    else
        button.FlareUI_Dispel:Hide()
    end
    if unit == "player" and not isDebuff and button.SetCancelAuraButtons then
        pcall(button.SetCancelAuraButtons, button, "RightButtonUp")
    end
end

-- Called from CreateUnitFrame: one container per corner, all at login
local function PrecreateAuraContainers(f)
    if not UNITS[f.unit].auras or not HasAuraSupport() then return end
    f.Auras = {}
    for _, corner in ipairs(AURA_CORNERS) do
        local ok, container = pcall(CreateFrame, "AuraContainer", nil, f, AURA_CONTAINER_TEMPLATE)
        if ok and container then
            pcall(container.SetUnit, container, f.unit)
            container:SetFrameLevel(f:GetFrameLevel() + 4)
            container:Hide()
            f.Auras[corner] = { container = container, groups = {}, generation = 0 }
        end
    end
end

-- corner: TOPLEFT | TOPRIGHT | BOTTOMLEFT | BOTTOMRIGHT; lanes: { {key, filter, isDebuff, candidates}, ... }
local function ConfigureAuraCorner(f, corner, lanes)
    local entry = f.Auras and f.Auras[corner]
    if not entry then return end
    local container = entry.container
    local db, udb = GetDb(), GetUnitDb(f.unit)

    -- retire the previous generation of groups (keys must be unique per container)
    for _, key in ipairs(entry.groups) do
        pcall(container.SetAuraGroupEnabled, container, key, false)
        pcall(container.SetAuraGroupMaxFrameCount, container, key, 0)
    end
    entry.groups = {}

    if #lanes == 0 then
        pcall(container.SetEnabled, container, false)
        container:Hide()
        return
    end

    local size = udb.auraSize or 20
    -- a corner wraps before the frame's middle, at most two rows (an even count, 4+); Top / Bottom:
    -- the whole width less the ring's room
    local lineSize
    if AURA.FULL[corner] then
        local clear = (ns.UFRing and ns.UFRing.Applies(f)) and ns.UFRing.Clearance(f, AURA_GAP) or 0
        lineSize = math.max(size, f:GetWidth() - 2 * INSET - clear)
    else
        lineSize = math.max(size, math_floor(f:GetWidth() / 2) - INSET - 4)
    end
    local max = 2 * math.max(2, math_floor((lineSize + AURA_SPACING) / (size + AURA_SPACING)))
    entry.generation = entry.generation + 1
    local gen = entry.generation
    local unit, font = f.unit, db and db.font
    local auraTimer = db and db.auraTimer or "none"
    local showTimer = auraTimer ~= "none"
    for index, lane in ipairs(lanes) do
        local key = lane.key .. gen
        local isDebuff = lane.isDebuff
        local look = ns.AuraLook and ns.AuraLook.ForUnit(size, isDebuff, unit == "player", db and db.auraStyle or "square", "icon", auraTimer)
        local ok, err = pcall(container.AddAuraGroup, container, key, lane.filter, {
            maxFrameCount = max,
            candidateFilters = lane.candidates,
            initializeFrame = function(button) InitAuraButton(button, size, isDebuff, unit, font, showTimer, look) end,
            layout = {
                elementWidth = size, elementHeight = look and look.cellHeight or size,
                elementSpacing = AURA_SPACING, lineSpacing = AURA_SPACING,
                groupSpacing = AURA_SPACING, groupLineSpacing = AURA_SPACING,
                layoutIndex = index,
                forceNewLine = index > 1,
            },
        })
        if ok then
            entry.groups[#entry.groups + 1] = key
            if lane.bossFight and f.bossFightRecs then
                f.bossFightRecs[#f.bossFightRecs + 1] = { container = container, key = key, mode = lane.bossFight, base = lane.candidates }
            end
        else
            print("|cffff0000FlareUI:|r aura group failed: " .. tostring(err))
        end
    end

    -- grow away from the corner (Top / Bottom: from the left)
    local isTop, isLeft = corner:find("^TOP") ~= nil, AURA.FULL[corner] or corner:find("LEFT$") ~= nil
    pcall(container.SetFlowLayoutAxis, container, AnchorUtil.FlowLayoutAxis.Horizontal)
    pcall(container.SetFlowLayoutAnchorPoint, container, (isTop and "BOTTOM" or "TOP") .. (isLeft and "LEFT" or "RIGHT"))
    pcall(container.SetFlowLayoutGrowthDirection, container,
        isLeft and AnchorUtil.FlowDirection.Right or AnchorUtil.FlowDirection.Left,
        isTop and AnchorUtil.FlowDirection.Up or AnchorUtil.FlowDirection.Down)
    pcall(container.SetFlowLayoutMaximumLineSize, container, lineSize)
    pcall(container.SetFlowLayoutPadding, container, 0, 0, 0, 0)
    pcall(container.SetEnabled, container, true)
    pcall(container.SetEditModePreviewEnabled, container, LEM:IsInEditMode())
    container:Show()
    pcall(container.UpdateAllAuras, container)
end

-- A container's spot: a few px out from its corner, past the cast bar while it shows on that side,
-- and past the ring at that height on the ring's side
function AURA.Placement(f, corner)
    local isTop = corner:find("^TOP") ~= nil
    local isLeft = AURA.FULL[corner] or corner:find("LEFT$") ~= nil
    local x = isLeft and INSET or -INSET
    local y = isTop and AURA_GAP or -AURA_GAP
    local udb = GetUnitDb(f.unit)
    if f.Cast and f.Cast:IsShown() and udb and UNITS[f.unit].castbar and (udb.castbarPosition == "TOP") == isTop then
        -- the cast bar's gap from the frame, the bar, and the same gap again before the auras
        local reach = (udb.castHeight or CAST_HEIGHT) + 2 * CAST_GAP
        y = isTop and reach or -reach
    end
    if ns.UFRing and ns.UFRing.Applies(f) and (ns.UFRing.Side(f) == "LEFT") == isLeft then
        local clear = ns.UFRing.Clearance(f, math.abs(y))
        x = x + (isLeft and clear or -clear)
    end
    return isTop, isLeft, x, y
end

-- Two places clash: the same one, or a whole-width one and anything on its edge
function AURA.Clash(a, b)
    if not a or not b or a == "OFF" or b == "OFF" then return false end
    if a == b then return true end
    return (a:find("^TOP") ~= nil) == (b:find("^TOP") ~= nil) and (AURA.FULL[a] or AURA.FULL[b]) or false
end

local function PositionAuraContainers(f)
    if not f.Auras then return end
    for corner, entry in pairs(f.Auras) do
        local c = entry.container
        local isTop, isLeft, x, y = AURA.Placement(f, corner)
        c:ClearAllPoints()
        c:SetPoint((isTop and "BOTTOM" or "TOP") .. (isLeft and "LEFT" or "RIGHT"), f,
            (isTop and "TOP" or "BOTTOM") .. (isLeft and "LEFT" or "RIGHT"), x, y)
        c:SetFrameLevel(f:GetFrameLevel() + 4)
    end
end

LayoutAuras = function(f)
    local udb = GetUnitDb(f.unit)
    if not udb or not f.Auras then return end
    if InCombatLockdown() then pendingLayout = true return end
    local perCorner = {}
    for _, corner in ipairs(AURA_CORNERS) do perCorner[corner] = {} end
    local function AddLane(corner, key, filter, isDebuff, candidates, bossFight)
        local list = corner and perCorner[corner]
        if list then list[#list + 1] = { key = key, filter = filter, isDebuff = isDebuff, candidates = candidates, bossFight = bossFight } end
    end
    -- permanent buffs are left out, except in Edit Mode (its samples have no duration)
    local buffCandidates
    if not LEM:IsInEditMode() then
        buffCandidates = { maxDuration = 999999 }
        -- "Hide Buffs": filters by full duration (secret-safe); any maxDuration also drops permanent
        -- buffs, so Off is no filter
        if f.unit == "player" then
            local hide = udb.hideBuffs or "PERMANENT"
            if hide == "OFF" then
                buffCandidates = nil
            elseif hide ~= "PERMANENT" and tonumber(hide) then
                buffCandidates = { maxDuration = tonumber(hide) }
            end
        end
    end
    -- "Only My Debuffs": the PLAYER filter (isFromPlayerOrPlayerPet means any player); other units only
    local debuffFilter = (udb.onlyMyDebuffs and f.unit ~= "player") and "HARMFUL|PLAYER" or "HARMFUL"
    -- debuffs first: closest to the frame when both share a corner; none with Hide Auras (focus)
    if not udb.hideAuras then
        -- "Focus Boss Debuffs": ns.BossFight switches the filter in boss fights
        AddLane(udb.debuffs, "debuffs", debuffFilter, true, nil,
            (f.unit == "player" and udb.encounterOnly) and "filter" or nil)
        AddLane(udb.buffs, "buffs", "HELPFUL", false, buffCandidates)
    end
    f.bossFightRecs = {}
    for _, corner in ipairs(AURA_CORNERS) do
        ConfigureAuraCorner(f, corner, perCorner[corner])
    end
    ns.BossFight.Track(f, f.bossFightRecs)
    PositionAuraContainers(f)
end

-- Edit Mode: the containers render Blizzard's sample auras
local function SetAuraPreview(enabled)
    for _, f in pairs(frames) do
        if f.Auras then
            for _, entry in pairs(f.Auras) do
                pcall(entry.container.SetEditModePreviewEnabled, entry.container, enabled)
            end
        end
    end
end

--------------------------------------------------
-- 8. COMBO POINTS (target frame)
-- Combo points belong to the target, as in Classic. A segmented strip on the health bar's top edge:
-- each segment is a StatusBar with range [i-1, i] fed the raw (possibly secret) count. The ring
-- styles use Blizzard's ComboFrame instead.
--------------------------------------------------
local COMBO = {
    height = 5, maxSegments = 10, fallbackMax = 5, previewPoints = 3,
    color = ns.COMBO_COLOR,
}

local function PlayerClass()
    local _, class = UnitClass("player")
    if canaccessvalue(class) then return class end
    return nil
end

-- Rogues, and druids in cat form, on an attackable target. Edit Mode previews for both classes.
local function ShouldShowComboPoints()
    local class = PlayerClass()
    if class ~= "ROGUE" and class ~= "DRUID" then return false end
    if LEM:IsInEditMode() then return true end
    if class == "DRUID" then
        local powerType = UnitPowerType("player")
        if not (canaccessvalue(powerType) and powerType == Enum.PowerType.Energy) then return false end
    end
    local hostile = UnitCanAttack("player", "target")
    return canaccessvalue(hostile) and hostile or false
end

local function CreateComboPoints(f)
    local combo = CreateFrame("Frame", nil, f)
    -- above the health bar and the heal overlay it covers, still below the frame border
    combo:SetFrameLevel(f.Health:GetFrameLevel() + 2)
    combo.segments, combo.separators = {}, {}
    combo.count = 0
    -- the one-pixel lines between segments sit over them
    combo.Lines = CreateFrame("Frame", nil, combo)
    combo.Lines:SetAllPoints()
    combo.Lines:SetFrameLevel(combo:GetFrameLevel() + 1)
    -- a dark line along the strip's bottom edge parts it from the health bar
    combo.Shadow = combo:CreateTexture(nil, "BACKGROUND")
    combo.Shadow:SetColorTexture(0, 0, 0, 0.8)
    combo.Shadow:SetHeight(1)
    combo.Shadow:SetPoint("TOPLEFT", combo, "TOPLEFT", 0, -COMBO.height)
    combo.Shadow:SetPoint("TOPRIGHT", combo, "TOPRIGHT", 0, -COMBO.height)
    combo:Hide()
    f.Combo = combo
end

local function GetComboSegment(f, i)
    local seg = f.Combo.segments[i]
    if not seg then
        seg = CreateBar(f.Combo, f.Combo:GetFrameLevel())
        seg:SetMinMaxValues(i - 1, i)
        f.Combo.segments[i] = seg
    end
    return seg
end

-- Spreads the segments across the strip on whole pixels, a one-pixel line between each
local function LayoutComboSegments(f)
    local combo, udb = f.Combo, GetUnitDb(f.unit)
    if not combo or combo.count == 0 then return end
    local n = combo.count
    local width = (udb and udb.width or 220) - 2 * INSET - PortraitSpace(f)
    local texture = GetBarTexture(udb and udb.texture)
    for i = 1, n do
        local seg = GetComboSegment(f, i)
        local x, segWidth, px = ns.SegmentSpan(combo, width, n, i)
        seg:SetStatusBarTexture(texture)
        seg.bg:SetTexture(texture)
        -- unspent points: dark, with the health colour reading through
        seg.bg:SetVertexColor(0, 0, 0, 0.45)
        seg:SetStatusBarColor(COMBO.color[1], COMBO.color[2], COMBO.color[3])
        seg:ClearAllPoints()
        -- left to right even on a mirrored frame: the points are the player's, not the target's
        seg:SetPoint("TOPLEFT", combo, "TOPLEFT", x, 0)
        seg:SetSize(segWidth, COMBO.height)
        seg:Show()
        local sep = combo.separators[i]
        if not sep then
            sep = combo.Lines:CreateTexture(nil, "OVERLAY")
            local c = ns.SEGMENT_LINE_COLOR
            sep:SetColorTexture(c[1], c[2], c[3], c[4])
            combo.separators[i] = sep
        end
        sep:ClearAllPoints()
        sep:SetPoint("TOPLEFT", combo, "TOPLEFT", x + segWidth - px, 0)
        sep:SetSize(px, COMBO.height)
        sep:SetShown(i < n)
    end
    for i = n + 1, #combo.segments do combo.segments[i]:Hide() end
    for i = n + 1, #combo.separators do combo.separators[i]:Hide() end
end

local function IsComboShown(f)
    return f.Combo ~= nil and f.Combo.count > 0
end

-- Blizzard's ComboFrame: a row in the health bar's bottom-right corner, or round the ring; unused,
-- it is parked on a hidden parent, where Blizzard's code still runs it
local CLASSIC_COMBO = {
    x = -2,         -- from the health bar's right edge (negative = left)
    y = 2,          -- from the health bar's bottom edge
    size = 16,      -- the socket's side
    spacing = 15,   -- the rims nearly touch
    hooked = false, skinned = false,
}

-- Blizzard's points (RogueComboPointTemplate, a 20 px widget with its own animations) are kept as
-- Blizzard draws them, only scaled to the gem size
local function SkinClassicCombo(combo)
    if CLASSIC_COMBO.skinned then return end
    CLASSIC_COMBO.skinned = true
    for _, point in ipairs(combo.ComboPoints) do point:SetScale(CLASSIC_COMBO.size / 20) end
end

-- Re-applied after Blizzard's circle layout, which runs on every update. Anchors only: the count can
-- be secret. The last point sits against the corner.
local function PlaceClassicCombo(combo, f)
    if ns.UFRing and ns.UFRing.Applies(f) and f.RingFrame and ns.UFRing.PlaceCombo(combo, f) then return end
    combo:ClearAllPoints()
    combo:SetPoint("BOTTOMRIGHT", f.Health, "BOTTOMRIGHT", CLASSIC_COMBO.x, CLASSIC_COMBO.y)
    -- Blizzard arcs the points around its portrait, starting at 1
    local max = combo.maxComboPoints
    if not (canaccessvalue(max) and type(max) == "number" and max >= 1) then max = 5 end
    local first, last = 1, math.min(max, #combo.ComboPoints)
    for i, point in ipairs(combo.ComboPoints) do
        -- the row fills from the left: Blizzard fills its last points first, so they go left
        local steps = last - i
        -- offsets are in the point's own scale
        local s = point:GetScale() or 1
        point:ClearAllPoints()
        point:SetPoint("BOTTOMRIGHT", combo, "BOTTOMRIGHT", (steps - (last - first)) * CLASSIC_COMBO.spacing / s, 0)
    end
end

-- nil when the client's combo display is off (comboPointLocation); the strip is used then
local function GetClassicCombo()
    local combo = _G.ComboFrame
    if combo and combo:IsEventRegistered("PLAYER_TARGET_CHANGED") then return combo end
end

-- Classic combo points go with the style: on in the ring styles (round the ring), off in Addon Style
local function UsesClassicCombo(f)
    local ringOn = ns.UFRing and ns.UFRing.Applies(f)
    return (ringOn and GetClassicCombo()) and true or false
end

-- Puts Blizzard's ComboFrame on the frame, or parks it
local function ApplyComboMode(f)
    local combo = GetClassicCombo()
    if not combo then return end
    if not UsesClassicCombo(f) then
        combo:SetParent(hiddenParent)
        return
    end
    SkinClassicCombo(combo)
    combo:SetParent(f)
    ns.CopyStrata(combo, f)
    combo:SetFrameLevel(f.Border:GetFrameLevel() + 2)
    PlaceClassicCombo(combo, f)
    if not CLASSIC_COMBO.hooked then
        CLASSIC_COMBO.hooked = true
        -- Blizzard puts the points back in its circle layout on every update
        if type(combo.LayoutPointsCircle) == "function" then
            hooksecurefunc(combo, "LayoutPointsCircle", function(self) PlaceClassicCombo(self, f) end)
        end
    end
end

--------------------------------------------------
-- 8b. FIVE-SECOND RULE
-- A spark crosses the player's mana bar for five seconds after a mana-costing cast. Mana can be
-- secret, so the cast event and cost type are the signal (a secret amount counts). The same events
-- drive the mana cost preview: the cost shows darker at the fill's end while casting.
--------------------------------------------------
local FSR_SECONDS = 5
local FSR_SPARK   = "Interface\\CastingBar\\UI-CastingBar-Spark"
local fsrStart            -- GetTime() of the last mana cast while a window runs

local function CostsMana(spellID)
    if not (spellID and canaccessvalue(spellID)) then return false end
    local costs = C_Spell.GetSpellPowerCost(spellID)
    if not costs then return false end
    for _, cost in ipairs(costs) do
        if canaccessvalue(cost.type) and cost.type == Enum.PowerType.Mana then
            local amount = cost.cost
            if canaccessvalue(amount) and not (type(amount) == "number" and amount > 0) then return false end
            return true, amount
        end
    end
    return false
end

local function BarShowsMana()
    local powerType = UnitPowerType("player")
    return canaccessvalue(powerType) and powerType == Enum.PowerType.Mana
end

local function MoveFsrSpark(holder)
    local elapsed = fsrStart and (GetTime() - fsrStart)
    if not elapsed or elapsed >= FSR_SECONDS then
        fsrStart = nil
        holder:Hide()
        return
    end
    local bar = holder:GetParent()
    local width = bar:GetWidth()
    local x = width * elapsed / FSR_SECONDS
    if bar:GetReverseFill() then x = width - x end
    holder.Spark:SetPoint("CENTER", bar, "LEFT", x, 0)
end

local function CreateFsrSpark(f)
    local bar = f.Power
    -- Mana cost preview without arithmetic (mana can be secret): a clip to the fill's end holds a bar
    -- of the same width filling from the other end
    local clip = CreateFrame("Frame", nil, bar)
    clip:SetFrameLevel(bar:GetFrameLevel() + 1)
    clip:SetClipsChildren(true)
    clip:Hide()
    local cost = CreateFrame("StatusBar", nil, clip)
    cost:SetMinMaxValues(0, 1)
    cost:SetValue(0)
    function cost:Refresh(powerType)
        local amount = f.manaCost
        if amount == nil or not (canaccessvalue(powerType) and powerType == Enum.PowerType.Mana) then
            clip:Hide()
            return
        end
        local fill = bar:GetStatusBarTexture()
        local reverse = bar:GetReverseFill()
        clip:ClearAllPoints()
        self:ClearAllPoints()
        if reverse then
            clip:SetPoint("TOPLEFT", fill, "TOPLEFT")
            clip:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT")
            self:SetPoint("TOPLEFT", clip, "TOPLEFT")
            self:SetPoint("BOTTOMLEFT", clip, "BOTTOMLEFT")
        else
            clip:SetPoint("TOPLEFT", bar, "TOPLEFT")
            clip:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
            self:SetPoint("TOPRIGHT", clip, "TOPRIGHT")
            self:SetPoint("BOTTOMRIGHT", clip, "BOTTOMRIGHT")
        end
        self:SetWidth(bar:GetWidth())
        self:SetReverseFill(not reverse)
        self:SetStatusBarTexture(fill:GetTexture())
        local r, g, b = GetPowerColor("player")
        self:SetStatusBarColor(r * 0.6, g * 0.6, b * 0.6)
        self:SetMinMaxValues(bar:GetMinMaxValues())
        self:SetValue(amount)
        clip:Show()
    end
    f.ManaCost = cost

    local holder = CreateFrame("Frame", nil, bar)
    holder:SetAllPoints(bar)
    holder:SetFrameLevel(bar:GetFrameLevel() + 2)
    holder:Hide()
    local spark = holder:CreateTexture(nil, "OVERLAY")
    spark:SetTexture(FSR_SPARK)
    spark:SetBlendMode("ADD")
    holder.Spark = spark
    -- the spark art is mostly glow, so it is taller than the bar
    holder:SetScript("OnShow", function(self)
        local height = bar:GetHeight()
        self.Spark:SetSize(math.max(height, 8), math.max(height * 2.2, 18))
    end)
    holder:SetScript("OnUpdate", MoveFsrSpark)
    f.FsrSpark = holder
end

local function UpdateFsrSpark()
    local f = frames.player
    local holder = f and f.FsrSpark
    if not holder then return end
    if fsrStart and GetTime() - fsrStart >= FSR_SECONDS then fsrStart = nil end
    local u = GetUnitDb("player")
    local on = u and u.fsr == true
    holder:SetShown(on and fsrStart ~= nil and f.Power:IsShown() and BarShowsMana())
end

local function InitFsrSpark()
    local events = CreateFrame("Frame")
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    events:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
    for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }) do
        events:RegisterUnitEvent(event, "player")
    end
    events:SetScript("OnEvent", function(_, event, _, _, spellID)
        -- mana cost preview: set on cast start, cleared once no cast runs (an off-GCD spell keeps it)
        local f = frames.player
        if f and f.ManaCost and event ~= "UNIT_DISPLAYPOWER" then
            if event == "UNIT_SPELLCAST_START" then
                local costs, amount = CostsMana(spellID)
                f.manaCost = costs and amount or nil
            elseif select("#", UnitCastingInfo("player")) == 0 then   -- the count: the values may be secret
                f.manaCost = nil
            end
            UpdatePower(f)
            if event ~= "UNIT_SPELLCAST_SUCCEEDED" then return end
        end
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            if not CostsMana(spellID) then return end
            fsrStart = GetTime()
        end
        UpdateFsrSpark()
    end)
end

--------------------------------------------------
-- 8c. PET HAPPINESS
-- Blizzard's own indicator (PetFrameHappinessTemplate) mid health bar. Clicks pass through to the
-- frame; the hover keeps its tooltip. Edit Mode shows the happy face.
--------------------------------------------------
local HAPPINESS_PREVIEW = "UI-PetHappiness"

local function CreateHappiness(f)
    local face = CreateFrame("Frame", nil, f.Overlay, "PetFrameHappinessTemplate")
    face:Hide()
    pcall(face.SetPropagateMouseClicks, face, true)
    f.Happiness = face
end

function UpdateHappiness(f)
    local face = f.Happiness
    if not face then return end
    if ICON_UI.Shown(f.unit, "happiness") then
        face:RegisterEvent("UNIT_HAPPINESS")
        face:RegisterEvent("UNIT_PET")
        face:UpdateHappiness()
        if LEM:IsInEditMode() and not face:IsShown() then
            face.Texture:SetAtlas(HAPPINESS_PREVIEW)
            face:Show()
        end
    else
        face:UnregisterAllEvents()
        face:Hide()
    end
end

--------------------------------------------------
-- 9. INDICATORS
-- Icons (rested, leader, PvP, classification, quest), the threat border tint and the incoming-heal
-- / absorb overlays. Art: Blizzard atlases, with the classic textures as fallback.
--------------------------------------------------
local ICON_SIZE = {
    rest = 28, leader = 20, pvp = 24,   -- the Elite & Rare skull takes the PvP crest's size
    quest = 24,   -- the quest "!" height; its width follows the art
}
local QUEST_ATLAS     = "QuestNormal"   -- the map's quest-offer "!", as on the nameplate quest tags
local QUEST_FILE      = "Interface\\GossipFrame\\AvailableQuestIcon"
-- Blizzard's CUF_MY_HEAL_PREDICTION_COLOR, opaque: the overlays only cover the empty part of the bar
local HEAL_COLOR      = { 11/255, 136/255, 105/255, 1 }   -- #0B8869, incoming heals
local ABSORB_COLOR    = { 0.67, 0.78, 0.92, 1 }           -- damage absorbs, the shield art's steel blue
local HEAL_TEXTURE    = "FlareUI Forever"
local ABSORB_TEXTURE  = "FlareUI Striped"

local function HasAtlas(name)
    return name ~= nil and C_Texture.GetAtlasInfo(name) ~= nil
end

-- The atlas when the client has it, otherwise the classic texture
local function SetIconArt(tex, atlas, file, coords)
    if HasAtlas(atlas) then
        tex:SetAtlas(atlas, false)
    else
        tex:SetTexture(file)
        if coords then tex:SetTexCoord(unpack(coords)) else tex:SetTexCoord(0, 1, 0, 1) end
    end
end

local function CreateIndicators(f)
    local info = UNITS[f.unit]
    local ind = info.indicators
    if not ind then return end
    local overlay = f.Overlay

    if ind.rest then
        local rest = CreateFrame("Frame", nil, overlay)
        rest:SetSize(ICON_SIZE.rest, ICON_SIZE.rest)
        local tex = rest:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints()
        if HasAtlas("UI-HUD-UnitFrame-Player-Rest-Flipbook") then
            tex:SetAtlas("UI-HUD-UnitFrame-Player-Rest-Flipbook", false)
            local anim = rest:CreateAnimationGroup()
            anim:SetLooping("REPEAT")
            local ok, flip = pcall(anim.CreateAnimation, anim, "FlipBook")
            if ok and flip then
                flip:SetTarget(tex)
                flip:SetDuration(1.5)
                pcall(flip.SetFlipBookRows, flip, 7)
                pcall(flip.SetFlipBookColumns, flip, 6)
                pcall(flip.SetFlipBookFrames, flip, 42)
                rest.anim = anim
            end
        else
            tex:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
            tex:SetTexCoord(0, 0.5, 0, 0.421875)
        end
        rest.tex = tex
        rest:Hide()
        f.RestIcon = rest
    end
    if ind.leader then
        f.LeaderIcon = overlay:CreateTexture(nil, "OVERLAY")
        f.LeaderIcon:Hide()
    end
    if ind.pvp then
        f.PvPIcon = overlay:CreateTexture(nil, "OVERLAY")
        f.PvPIcon:Hide()
    end
    -- the PvP timer, right beside the flag (Addon Style; the ring has its own)
    if ind.pvpTimer and f.PvPIcon then
        f.PvPTimer = CreateFrame("Frame", nil, overlay)
        f.PvPTimer:SetAllPoints(overlay)
        f.PvPTimer.Text = f.PvPTimer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.PvPTimer.Text:SetPoint("RIGHT", f.PvPIcon, "LEFT", 0, 0)
        f.PvPTimer.Text:Hide()
    end
    if ind.classification then
        f.ClassIcon = overlay:CreateTexture(nil, "OVERLAY")
        f.ClassIcon:Hide()
    end
    if ind.readyCheck then
        f.ReadyIcon = overlay:CreateTexture(nil, "OVERLAY", nil, 6)
        f.ReadyIcon:Hide()
    end
    if ind.quest then
        -- under the raid marker (sublevel 4), which shares its spot mid health bar
        f.QuestIcon = overlay:CreateTexture(nil, "OVERLAY", nil, 1)
        f.QuestIcon:Hide()
    end
    -- threat tints the frame border (UpdateThreat)
    f.threatTint = ind.threat and true or false
    if ind.heals then
        -- the overlays live in a clip frame over the empty part of the health bar
        local clip = CreateFrame("Frame", nil, f.Health)
        clip:SetFrameLevel(f.Health:GetFrameLevel() + 1)
        clip:SetClipsChildren(true)
        local heal = CreateFrame("StatusBar", nil, clip)
        heal:SetStatusBarTexture(GetBarTexture(HEAL_TEXTURE))
        heal:SetStatusBarColor(unpack(HEAL_COLOR))
        heal:SetMinMaxValues(0, 1)
        heal:SetValue(0)
        local absorb = CreateFrame("StatusBar", nil, clip)
        absorb:SetStatusBarTexture(GetBarTexture(ABSORB_TEXTURE))
        absorb:SetStatusBarColor(unpack(ABSORB_COLOR))
        absorb:SetMinMaxValues(0, 1)
        absorb:SetValue(0)
        f.HealClip, f.HealBar, f.AbsorbBar = clip, heal, absorb
        if CreateUnitHealPredictionCalculator then
            local ok, calc = pcall(CreateUnitHealPredictionCalculator)
            if ok and calc then f.HealCalc = calc end
        end
    end
end

-- The frame laid out as the target frame (portrait, icons, texts). In the ring styles Mirror only
-- turns the bars' fill, so target and focus keep that layout; the fill always follows udb.mirror.
function UF.LayoutMirrored(f)
    local info = UNITS[f.unit]
    if info and info.mirrorable and ns.UFRing and ns.UFRing.Applies(f) then return true end
    local udb = GetUnitDb(f.unit)
    return udb and udb.mirror and true or false
end

local function LayoutIndicators(f)
    local udb = GetUnitDb(f.unit)
    local mirror = UF.LayoutMirrored(f)
    local fillMirror = udb and udb.mirror and true or false
    -- Forever style: the icons with a home on the ring go there
    local onRing = {}
    if ns.UFRing and ns.UFRing.Applies(f) then
        for _, key in ipairs({ "rest", "leader", "pvp", "classification", "quest", "readyCheck" }) do
            local region = f[ICON_UI.defs[key].field]
            if region then
                local point, rel, relPoint, x, y, w, h = ns.UFRing.IconSpot(f, key)
                if point then
                    ICON_UI.Place(region, w, h, point, rel, relPoint, x, y)
                    onRing[key] = true
                end
            end
        end
    end
    -- FlareUI's own placement
    if f.RestIcon and not onRing.rest then
        ICON_UI.Place(f.RestIcon, ICON_SIZE.rest, ICON_SIZE.rest, "CENTER", f, "TOPRIGHT", -2, 0)
    end
    if f.LeaderIcon and not onRing.leader then
        ICON_UI.Place(f.LeaderIcon, ICON_SIZE.leader, ICON_SIZE.leader, "CENTER", f, "TOPLEFT", 16, -2)
    end
    if f.PvPIcon and not onRing.pvp then
        -- bottom-left on the player, bottom-right on a mirrored frame: symmetrical across the screen
        if mirror then
            ICON_UI.Place(f.PvPIcon, ICON_SIZE.pvp, ICON_SIZE.pvp, "CENTER", f, "BOTTOMRIGHT", -4, 2)
        else
            ICON_UI.Place(f.PvPIcon, ICON_SIZE.pvp, ICON_SIZE.pvp, "CENTER", f, "BOTTOMLEFT", 4, 2)
        end
    end
    if f.ClassIcon and not onRing.classification then
        local info = C_Texture.GetAtlasInfo(ICON_UI.CLASS_SKULL)
        local aspect = (info and info.width > 0 and info.height > 0) and (info.width / info.height) or 1
        -- above the PvP crest, in its column and at its size (top-right on a mirrored frame, top-left otherwise)
        local size = ICON_SIZE.pvp
        if mirror then
            ICON_UI.Place(f.ClassIcon, size * aspect, size, "CENTER", f, "TOPRIGHT", -4, -2)
        else
            ICON_UI.Place(f.ClassIcon, size * aspect, size, "CENTER", f, "TOPLEFT", 4, -2)
        end
    end
    if f.QuestIcon and not onRing.quest then
        local info = C_Texture.GetAtlasInfo(QUEST_ATLAS)
        local aspect = (info and info.width > 0 and info.height > 0) and (info.width / info.height) or 1
        -- mid health bar, under the raid marker
        ICON_UI.Place(f.QuestIcon, ICON_SIZE.quest * aspect, ICON_SIZE.quest, "CENTER", f.Health, "CENTER", 0, 0)
    end
    if f.ReadyIcon and not onRing.readyCheck then
        -- mid-frame, over the raid marker
        local size = math.min(32, math.max(16, ((udb and udb.height) or 44) - 12))
        ICON_UI.Place(f.ReadyIcon, size, size, "CENTER", f, "CENTER", 0, 0)
    end
    if f.HealClip then
        local health, clip, heal, absorb = f.Health, f.HealClip, f.HealBar, f.AbsorbBar
        local fill = health:GetStatusBarTexture()
        local width = (udb and udb.width or 220) - 2 * INSET - PortraitSpace(f)
        -- Forever Style: the bar is bigger than its slot (its art has margins round the colour):
        -- the overlays keep to the colour, and scale with the bar's whole length as the health does
        local inset = health.FlareUI_PlateInset
        local ix, iy = 0, 0
        if inset then width, ix, iy = inset.length, inset.x, inset.y end
        -- shields grow back from the end of the bar, so they show at full health too
        local reverse = true

        clip:ClearAllPoints()
        heal:ClearAllPoints()
        absorb:ClearAllPoints()
        heal:SetWidth(width)
        absorb:SetWidth(width)
        mirror = fillMirror
        heal:SetReverseFill(mirror)
        -- incoming heals in the frame's own bar texture (on the plate, whose bars are Blizzard's art:
        -- FlareUI Forever, the same art)
        heal:SetStatusBarTexture(GetBarTexture(inset and "FlareUI Forever" or (udb and udb.texture), mirror))
        -- a reversed absorb grows back towards the health
        absorb:SetReverseFill(reverse ~= mirror)

        -- the clip keeps the overlays inside the bar without comparing (secret) values
        if mirror then
            -- bar fills from the right; the empty part is on the left
            clip:SetPoint("TOPLEFT", health, "TOPLEFT", ix, -iy)
            clip:SetPoint("BOTTOMRIGHT", fill, "BOTTOMLEFT", 0, iy)
            heal:SetPoint("TOPRIGHT", clip, "TOPRIGHT", 0, 0)
            heal:SetPoint("BOTTOMRIGHT", clip, "BOTTOMRIGHT", 0, 0)
        else
            clip:SetPoint("TOPLEFT", fill, "TOPRIGHT", 0, -iy)
            clip:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", -ix, iy)
            heal:SetPoint("TOPLEFT", clip, "TOPLEFT", 0, 0)
            heal:SetPoint("BOTTOMLEFT", clip, "BOTTOMLEFT", 0, 0)
        end

        -- the absorb starts where the heals end, or reversed, at the far end of the bar
        local edge, relTo, relEdge
        if reverse then
            edge = mirror and "LEFT" or "RIGHT"
            relTo, relEdge = clip, edge
        else
            edge = mirror and "RIGHT" or "LEFT"
            relTo, relEdge = heal:GetStatusBarTexture(), mirror and "LEFT" or "RIGHT"
        end
        absorb:SetPoint("TOP" .. edge, relTo, "TOP" .. relEdge, 0, 0)
        absorb:SetPoint("BOTTOM" .. edge, relTo, "BOTTOM" .. relEdge, 0, 0)

        -- the absorb sits over the heals
        local base = clip:GetFrameLevel()
        absorb:SetFrameLevel(base + 2)
        heal:SetFrameLevel(base + 1)

        -- "" is the dropdown's Frame Texture entry, so it means the frame's own bar texture
        local absorbTex = udb and udb.absorbTexture
        if absorbTex == nil then absorbTex = ABSORB_TEXTURE end
        if absorbTex == "" then absorbTex = udb and udb.texture end
        absorb:SetStatusBarTexture(GetBarTexture(absorbTex))
        absorb:SetStatusBarColor(unpack(ABSORB_COLOR))
    end
end

function UpdateHealPrediction(f)
    local heal, absorb = f.HealBar, f.AbsorbBar
    if not heal then return end
    -- Edit Mode: a sample incoming heal and barrier on the sample health (UpdateHealth, 0..1)
    if LEM:IsInEditMode() then
        heal:SetMinMaxValues(0, 1)
        absorb:SetMinMaxValues(0, 1)
        heal:SetValue(0.12)
        absorb:SetValue(0.15)
        return
    end
    local unit = f.unit
    local max = UnitHealthMax(unit)
    heal:SetMinMaxValues(0, max)
    absorb:SetMinMaxValues(0, max)
    -- the calculator hands back (possibly secret) numbers that SetValue accepts as-is
    local calc = f.HealCalc
    if calc and UnitGetDetailedHealPrediction then
        local ok = pcall(UnitGetDetailedHealPrediction, unit, "player", calc)
        if ok then
            local okH, incoming = pcall(calc.GetIncomingHeals, calc)
            local okA, absorbs = pcall(calc.GetDamageAbsorbs, calc)
            if okH then heal:SetValue(incoming) end
            if okA then absorb:SetValue(absorbs) end
            return
        end
    end
    pcall(function() heal:SetValue(UnitGetIncomingHeals(unit)) end)
    pcall(function() absorb:SetValue(UnitGetTotalAbsorbs(unit)) end)
end

-- Threat on this unit: 1 above the tank, 2 tanking insecurely, 3 tanking securely. Muted versions of
-- Blizzard's colours.
local THREAT_COLORS = {
    [1] = { 0.80, 0.68, 0.30 },   -- above the tank
    [2] = { 0.80, 0.48, 0.25 },   -- tanking, insecure
    [3] = { 0.78, 0.28, 0.24 },   -- tanking, secure
}
local function ThreatColor(status)
    local c = THREAT_COLORS[status] or THREAT_COLORS[3]
    return c[1], c[2], c[3]
end

-- the frame border takes the threat colour, and its fixed colour when clear (the player's: its
-- highest threat on anything)
function UpdateThreat(f)
    if not f.threatTint then return end
    if not ICON_UI.Shown(f.unit, "threatGlow") then ResetBorderTint(f.Border) return end
    local status
    if f.unit == "player" then
        status = Readable(UnitThreatSituation("player"))
    else
        status = Readable(UnitThreatSituation("player", f.unit))
    end
    if status and status >= 1 then
        SetBorderTint(f.Border, ThreatColor(status))
    else
        ResetBorderTint(f.Border)
    end
end

-- The ready check mark: during a check, and its result for a few seconds after (a member who never
-- answered counts as not ready, as on Blizzard's frames)
function ICON_UI.UpdateReady(f, event)
    local icon = f.ReadyIcon
    if not icon then return end
    if event == "READY_CHECK" then
        if f.readyHold then f.readyHold:Cancel(); f.readyHold = nil end
    elseif event == "READY_CHECK_FINISHED" then
        if f.readyHold then f.readyHold:Cancel() end
        f.readyHold = C_Timer.NewTimer(ICON_UI.READY_HOLD, function()
            f.readyHold, f.lastReady = nil, nil
            ICON_UI.UpdateReady(f)
        end)
    end
    if not ICON_UI.Shown(f.unit, "readyCheck") then icon:Hide() return end
    local status = Readable(GetReadyCheckStatus(f.unit))
    if not status and f.readyHold then status = f.lastReady end
    if f.readyHold and status == "waiting" then status = "notready" end
    local atlas = status and ICON_UI.READY[status]
    if atlas then
        if not f.readyHold then f.lastReady = status end
        icon:SetAtlas(atlas, false)
        icon:Show()
    elseif not LEM:IsInEditMode() then
        icon:Hide()
    end
end

function UpdateIndicators(f)
    local unit = f.unit
    local readable = Readable

    if f.RestIcon then
        local show = ICON_UI.Shown(unit, "rest") and IsResting()
        f.RestIcon:SetShown(show)
        if f.RestIcon.anim then
            if show then
                if not f.RestIcon.anim:IsPlaying() then f.RestIcon.anim:Play() end
            elseif f.RestIcon.anim:IsPlaying() then
                f.RestIcon.anim:Stop()
            end
        end
    end
    if f.LeaderIcon then
        local leader = readable(UnitIsGroupLeader(unit))
        local assist = readable(UnitIsGroupAssistant(unit))
        if not ICON_UI.Shown(unit, "leader") then
            f.LeaderIcon:Hide()
        elseif leader then
            SetIconArt(f.LeaderIcon, "UI-HUD-UnitFrame-Player-Group-LeaderIcon", "Interface\\GroupFrame\\UI-Group-LeaderIcon")
            f.LeaderIcon:Show()
        elseif assist then
            SetIconArt(f.LeaderIcon, nil, "Interface\\GroupFrame\\UI-Group-AssistantIcon")
            f.LeaderIcon:Show()
        else
            f.LeaderIcon:Hide()
        end
    end
    if f.PvPIcon then
        local ffa = readable(UnitIsPVPFreeForAll(unit))
        local pvp = readable(UnitIsPVP(unit))
        local faction = readable(UnitFactionGroup(unit))
        if not ICON_UI.Shown(unit, "pvp") then
            f.PvPIcon:Hide()
        elseif ffa then
            SetIconArt(f.PvPIcon, "UI-HUD-UnitFrame-Player-PVP-FFAIcon", "Interface\\TargetingFrame\\UI-PVP-FFA")
            f.PvPIcon:Show()
        elseif pvp and faction == "Horde" then
            SetIconArt(f.PvPIcon, "UI-HUD-UnitFrame-SmallCircle-Horde", "Interface\\TargetingFrame\\UI-PVP-Horde")
            f.PvPIcon:Show()
        elseif pvp and faction == "Alliance" then
            SetIconArt(f.PvPIcon, "UI-HUD-UnitFrame-SmallCircle-Alliance", "Interface\\TargetingFrame\\UI-PVP-Alliance")
            f.PvPIcon:Show()
        else
            f.PvPIcon:Hide()
        end
    end
    if f.ClassIcon then
        -- the level disc's skull: as it is for rares, gold for elites and bosses
        local c = readable(UnitClassification(unit))
        local kind = (c == "elite" or c == "worldboss") and "elite" or (c == "rare" or c == "rareelite") and "rare" or nil
        if kind and ICON_UI.Shown(unit, "classification") and ICON_UI.ClassArt(f.ClassIcon, kind) then
            f.ClassIcon:Show()
        else
            f.ClassIcon:Hide()
        end
    end
    if f.QuestIcon then
        -- a quest boss, or a hostile unit tied to an active quest (the nameplate quest tags' test)
        local show = false
        if ICON_UI.Shown(unit, "quest") then
            show = readable(UnitIsQuestBoss(unit)) == true
            if not show and readable(UnitCanAttack("player", unit)) then
                show = readable(C_QuestLog.UnitIsRelatedToActiveQuest(unit)) == true
            end
        end
        if show then SetIconArt(f.QuestIcon, QUEST_ATLAS, QUEST_FILE) end
        f.QuestIcon:SetShown(show)
    end
    ICON_UI.UpdateReady(f)
    ICON_UI.Preview(f)
    ICON_UI.UpdatePvPTimer(f)
    if ns.UFRing and ns.UFRing.Applies(f) then
        -- Forever style: Blizzard's art; elites get the dragon frame instead of the small icon, and the
        -- quest mark sits where the rare star would
        if f.QuestIcon and f.QuestIcon:IsShown() then
            SetIconArt(f.QuestIcon, "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Quest", QUEST_FILE)
            if f.ClassIcon then f.ClassIcon:Hide() end
        elseif f.ClassIcon then
            local c = readable(UnitClassification(unit))
            if c == "rare" or c == "rareelite" then
                SetIconArt(f.ClassIcon, "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star", nil)
                f.ClassIcon:SetVertexColor(1, 1, 1)
                f.ClassIcon:Show()
            elseif not LEM:IsInEditMode() then
                f.ClassIcon:Hide()
            end
        end
        ns.UFRing.Update(f)
    end
end

-- The Elite & Rare icon: Blizzard's high-level skull, gold for an elite (false without the art)
ICON_UI.CLASS_SKULL = "UI-HUD-UnitFrame-Target-HighLevelTarget_Icon"
ICON_UI.ELITE_GOLD = { 1, 0.82, 0.25 }
function ICON_UI.ClassArt(tex, kind)
    if not HasAtlas(ICON_UI.CLASS_SKULL) then return false end
    tex:SetAtlas(ICON_UI.CLASS_SKULL, false)
    local gold = ICON_UI.ELITE_GOLD
    if kind == "elite" then tex:SetVertexColor(gold[1], gold[2], gold[3]) else tex:SetVertexColor(1, 1, 1) end
    return true
end

-- The PvP timer (Addon Style): Blizzard's countdown to the flag dropping, readable values only; a
-- sample in Edit Mode
function ICON_UI.PvPTick(timer, elapsed)
    timer.wait = (timer.wait or 0) + elapsed
    if timer.wait < 0.2 then return end
    timer.wait = 0
    local left = timer.pvpEnd and timer.pvpEnd - GetTime()
    if not left or left < 0 then
        timer.pvpEnd = nil
        timer.Text:Hide()
        timer:SetScript("OnUpdate", nil)
    else
        timer.Text:SetFormattedText(SecondsToTimeAbbrev(math_floor(left)))
    end
end

function ICON_UI.UpdatePvPTimer(f)
    local timer = f.PvPTimer
    if not timer then return end
    local on = ICON_UI.Shown(f.unit, "pvpTimer") and not (ns.UFRing and ns.UFRing.Applies(f))
    timer.pvpEnd = nil
    timer:SetScript("OnUpdate", nil)
    if on and Readable(IsPVPTimerRunning()) then
        local ms = Readable(GetPVPTimer())
        if ms then
            timer.pvpEnd = GetTime() + ms / 1000
            timer.wait = 1   -- the text at once
            timer:SetScript("OnUpdate", ICON_UI.PvPTick)
            timer.Text:Show()
            return
        end
    end
    if on and LEM:IsInEditMode() then
        timer.Text:SetFormattedText(SecondsToTimeAbbrev(299))
        timer.Text:Show()
    else
        timer.Text:Hide()
    end
end

-- Edit Mode: every icon the frame shows appears with sample art
function ICON_UI.Preview(f)
    if not LEM:IsInEditMode() then return end
    for _, key in ipairs(ICON_UI.List(f.unit)) do
        if key ~= "happiness" and ICON_UI.defs[key].field and not ICON_UI.defs[key].ring and ICON_UI.Shown(f.unit, key) then ICON_UI.PreviewIcon(f, key) end
    end
end

function ICON_UI.PreviewIcon(f, key)
    local region = f[ICON_UI.defs[key].field]
    if not region then return end
    if key == "rest" then
        if region.anim and not region.anim:IsPlaying() then region.anim:Play() end
    elseif key == "leader" then
        SetIconArt(region, "UI-HUD-UnitFrame-Player-Group-LeaderIcon", "Interface\\GroupFrame\\UI-Group-LeaderIcon")
    elseif key == "pvp" then
        if UnitFactionGroup("player") == "Horde" then
            SetIconArt(region, "UI-HUD-UnitFrame-SmallCircle-Horde", "Interface\\TargetingFrame\\UI-PVP-Horde")
        else
            SetIconArt(region, "UI-HUD-UnitFrame-SmallCircle-Alliance", "Interface\\TargetingFrame\\UI-PVP-Alliance")
        end
    elseif key == "classification" then
        if not ICON_UI.ClassArt(region, "elite") then return end
    elseif key == "quest" then
        SetIconArt(region, QUEST_ATLAS, QUEST_FILE)
    elseif key == "raidIcon" then
        SetRaidTargetIconTexture(region, 8)
    elseif key == "readyCheck" then
        region:SetAtlas(ICON_UI.READY.ready, false)
    end
    region:Show()
end

--------------------------------------------------
-- 10. LAYOUT
--------------------------------------------------
-- Anchors health / power and the divider on their seam; the combo strip lies over the health bar's
-- top edge. Unprotected children only, so it may run in combat (cat form gains the strip at once).
local function LayoutBars(f)
    local udb = GetUnitDb(f.unit)
    if not udb then return end
    local PADDING = INSET
    local powerHeight = udb.powerHeight or 8
    local health, power = f.Health, f.Power
    local comboShown = IsComboShown(f)
    -- the portrait square on the left, or on the right of a mirrored frame
    local space, mirror = PortraitSpace(f), UF.LayoutMirrored(f)
    local left, right = PADDING + (mirror and 0 or space), PADDING + (mirror and space or 0)

    if f.Portrait and ns.UFRing and ns.UFRing.Plate(f) then
        -- Forever Style: the bars sit in the frame plate's slots, the ring beside it
        f.Separator:Hide()
        if f.Combo then f.Combo:Hide() end
        ns.UFRing.LayoutPlate(f)
        ns.UFRing.Layout(f)
        UpdatePortrait(f)
        return
    end

    health:ClearAllPoints()
    power:ClearAllPoints()
    health:SetPoint("TOPLEFT", f, "TOPLEFT", left, -PADDING)

    if f.Portrait and ns.UFRing and ns.UFRing.Applies(f) then
        ns.UFRing.Layout(f)
        UpdatePortrait(f)
    elseif f.Portrait then
        if ns.UFRing then ns.UFRing.Reset(f) end
        local portrait, divider = f.Portrait, f.PortraitDivider
        portrait:ClearAllPoints()
        divider:ClearAllPoints()
        if space > 0 then
            local size = space - PORTRAIT_GAP
            portrait:SetSize(size, size)
            local edge = mirror and "LEFT" or "RIGHT"
            if mirror then
                portrait:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, -PADDING)
            else
                portrait:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, -PADDING)
            end
            divider:SetPoint("TOP", portrait, "TOP" .. edge, 0, 0)
            divider:SetPoint("BOTTOM", portrait, "BOTTOM" .. edge, 0, 0)
            divider:SetWidth(SEPARATOR_HEIGHT)
            divider:Show()
        else
            divider:Hide()
        end
        UpdatePortrait(f)
    end

    if comboShown then
        local combo = f.Combo
        combo:ClearAllPoints()
        combo:SetPoint("TOPLEFT", health, "TOPLEFT", 0, 0)
        combo:SetPoint("TOPRIGHT", health, "TOPRIGHT", 0, 0)
        combo:SetHeight(COMBO.height)
        combo:Show()
        LayoutComboSegments(f)
    elseif f.Combo then
        f.Combo:Hide()
    end
    if powerHeight > 0 then
        power:Show()
        power:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", left, PADDING)
        power:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -right, PADDING)
        power:SetHeight(powerHeight)
        health:SetPoint("BOTTOMRIGHT", power, "TOPRIGHT", 0, 0)
        f.Separator:ClearAllPoints()
        f.Separator:SetPoint("TOPLEFT", power, "TOPLEFT", 0, SEPARATOR_HEIGHT / 2)
        f.Separator:SetPoint("TOPRIGHT", power, "TOPRIGHT", 0, SEPARATOR_HEIGHT / 2)
        f.Separator:SetHeight(SEPARATOR_HEIGHT)
        f.Separator:Show()
    else
        f.Separator:Hide()
        power:Hide()
        health:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -right, PADDING)
    end
end

-- Shows the strip with the right number of segments, feeds the values, and re-lays the bars when it
-- comes or goes
function UpdateComboPoints(f)
    local combo = f.Combo
    if not combo then return end
    local count = 0
    if not UsesClassicCombo(f) and ShouldShowComboPoints() then
        local max = UnitPowerMax("player", Enum.PowerType.ComboPoints)
        if not (canaccessvalue(max) and max and max >= 1) then max = COMBO.fallbackMax end
        count = math.min(max, COMBO.maxSegments)
    end
    if count ~= combo.count then
        combo.count = count
        LayoutBars(f)
    end
    if count > 0 then
        local value = LEM:IsInEditMode() and COMBO.previewPoints or GetComboPoints("player", "target")
        for i = 1, count do GetComboSegment(f, i):SetValue(value) end
    end
end

local function LayoutFrame(f)
    local db, udb = GetDb(), GetUnitDb(f.unit)
    if not db or not udb then return end
    if InCombatLockdown() then pendingLayout = true return end

    local width, height = udb.width or 220, udb.height or 44
    local powerHeight = udb.powerHeight or 8
    local PADDING = INSET
    -- Forever Style: the frame plate is the background and the border, and has a least size
    local plate = ns.UFRing and ns.UFRing.Plate(f)
    if plate then
        -- no stored Scale: the default (ring and height)
        if udb.plateScale == nil then
            ns.UFRing.SetPlateScale(f.unit, ns.UFRing.PlateDefaultScale(f.unit))
            height = udb.height
        end
        local minW, minH = ns.UFRing.PlateMinSize(f)
        width, height = math.max(width, minW), math.max(height, minH)
    end
    f:SetSize(width, height)

    if plate then
        f:SetBackdrop(nil)
        f.Border:Hide()
    else
        local edgeFile = GetBorderFile(ns.UFRing and ns.UFRing.Border(udb.border) or udb.border)
        f:SetBackdrop({ bgFile = BACKDROP_FILE, insets = { left = PADDING, right = PADDING, top = PADDING, bottom = PADDING } })
        f:SetBackdropColor(0, 0, 0, BG_OPACITY)
        -- the border's own frame sits above the bars
        ApplyBorderStyle(f.Border, edgeFile, height)
        f.Border:Show()
    end

    -- mirrored frames fill right to left, text order [health][name][level]
    local fillMirror = udb.mirror and true or false
    local mirror = UF.LayoutMirrored(f)
    local texture = GetBarTexture(udb.texture, fillMirror)
    local health, power = f.Health, f.Power
    health:SetStatusBarTexture(texture)
    power:SetStatusBarTexture(texture)
    health.bg:SetTexture(texture)
    power.bg:SetTexture(texture)
    health:SetReverseFill(fillMirror)
    power:SetReverseFill(fillMirror)

    LayoutBars(f)
    -- the bars' empty part (Background Opacity; after LayoutBars, which hides it on the plate)
    local bgOpacity = udb.bgOpacity
    if bgOpacity == nil then bgOpacity = UF.DefaultBgOpacity(f.unit) end
    UF.SetBarBackground(health, bgOpacity)
    UF.SetBarBackground(power, bgOpacity)

    -- ring styles: text one point smaller
    local fontDelta = (ns.UFRing and ns.UFRing.Applies(f)) and -1 or 0
    ApplyFont(f.Name, db.font, fontDelta)
    ApplyFont(f.Level, db.font, fontDelta)
    ApplyFont(f.HealthText, db.font, fontDelta)
    ApplyFont(f.PowerText, db.fontPower or db.font, fontDelta)

    f.Level:ClearAllPoints()
    f.Name:ClearAllPoints()
    f.HealthText:ClearAllPoints()
    f.PowerText:ClearAllPoints()
    -- ring styles: the level is in the ring's disc
    local ringOn = ns.UFRing and ns.UFRing.Applies(f)
    local levelInRow = udb.showLevel and not ringOn
    -- the name is always on the ring's side: it starts past the portrait
    local namePad = ringOn and ns.UFRing.TextPad(f) or 0
    if mirror then
        f.Level:SetJustifyH("RIGHT")
        f.Name:SetJustifyH("RIGHT")
        f.HealthText:SetJustifyH("LEFT")
        f.PowerText:SetJustifyH("LEFT")
        f.Level:SetPoint("RIGHT", health, "RIGHT", -TEXT_INSET, 0)
        if levelInRow then
            f.Name:SetPoint("RIGHT", f.Level, "LEFT", -3, 0)
        else
            f.Name:SetPoint("RIGHT", health, "RIGHT", -TEXT_INSET - namePad, 0)
        end
        f.HealthText:SetPoint("LEFT", health, "LEFT", TEXT_INSET, 0)
        f.Name:SetPoint("LEFT", f.HealthText, "RIGHT", 4, 0)
        f.PowerText:SetPoint("LEFT", power, "LEFT", TEXT_INSET, 0)
    else
        f.Level:SetJustifyH("LEFT")
        f.Name:SetJustifyH("LEFT")
        f.HealthText:SetJustifyH("RIGHT")
        f.PowerText:SetJustifyH("RIGHT")
        f.Level:SetPoint("LEFT", health, "LEFT", TEXT_INSET, 0)
        if levelInRow then
            f.Name:SetPoint("LEFT", f.Level, "RIGHT", 3, 0)
        else
            f.Name:SetPoint("LEFT", health, "LEFT", TEXT_INSET + namePad, 0)
        end
        f.HealthText:SetPoint("RIGHT", health, "RIGHT", -TEXT_INSET, 0)
        f.Name:SetPoint("RIGHT", f.HealthText, "LEFT", -4, 0)
        f.PowerText:SetPoint("RIGHT", power, "RIGHT", -TEXT_INSET, 0)
    end
    -- Forever Style: the name centred in the plate's name box, the numbers centred in their bars
    local nameBox = ringOn and ns.UFRing.NameBox(f)
    if nameBox then
        f.Name:ClearAllPoints()
        f.Name:SetPoint("LEFT", nameBox, "LEFT", TEXT_INSET, 0)
        f.Name:SetPoint("RIGHT", nameBox, "RIGHT", -TEXT_INSET, 0)
        f.Name:SetJustifyH("CENTER")
        f.HealthText:ClearAllPoints()
        f.HealthText:SetPoint("CENTER", health, "CENTER", 0, 0)
        f.HealthText:SetJustifyH("CENTER")
        f.PowerText:ClearAllPoints()
        f.PowerText:SetPoint("CENTER", power, "CENTER", 0, 0)
        f.PowerText:SetJustifyH("CENTER")
    end
    -- (the plate's power bar is always tall enough for its number)
    f.PowerText:SetShown(udb.powerText and (nameBox or powerHeight >= 10) and true or false)
    if ringOn then
        ns.UFRing.LayoutLevel(f)
        -- the classic gems follow the ring's size and side
        if f.Combo then ApplyComboMode(f) end
    end

    -- the raid marker and the happiness face sit mid health bar, sized off its height
    local healthHeight = height - 2 * PADDING - (powerHeight > 0 and powerHeight or 0)
    local markerSize = math.max(8, healthHeight * RAID_ICON_SHARE)
    local rp, rrel, rrelPoint, rx, ry, rw, rh
    if ringOn then rp, rrel, rrelPoint, rx, ry, rw, rh = ns.UFRing.IconSpot(f, "raidIcon") end
    if rp then
        ICON_UI.Place(f.RaidIcon, rw, rh, rp, rrel, rrelPoint, rx, ry)
    else
        ICON_UI.Place(f.RaidIcon, markerSize - 2, markerSize - 2, "CENTER", f, "TOP", 0, -2)
    end

    if f.Happiness then
        local size = math.max(RAID_ICON, healthHeight * HAPPINESS_SHARE) - 4
        -- Happiness Position: mid health bar, or just outside the frame on either side
        local store = ICON_UI.Store(f.unit, "happiness")
        local place = store and store.place
        if place == "RIGHT" then
            ICON_UI.Place(f.Happiness, size, size, "LEFT", f, "RIGHT", ICON_UI.HAPPINESS_GAP, 0)
        elseif place == "LEFT" then
            ICON_UI.Place(f.Happiness, size, size, "RIGHT", f, "LEFT", -ICON_UI.HAPPINESS_GAP, 0)
        else
            ICON_UI.Place(f.Happiness, size, size, "CENTER", f.Health, "CENTER", 0, 0)
        end
    end

    -- cast bar hangs off the frame
    if f.Cast then
        local leftExtra, rightExtra
        if ringOn then
            -- ends where the ring starts at the cast bar's height
            local clear = ns.UFRing.Clearance(f, CAST_GAP)
            if ns.UFRing.Side(f) == "LEFT" then leftExtra = clear else rightExtra = clear end
        end
        LayoutCastBar(f.Cast, GetCastStyle(udb, false), f, udb.castbarPosition == "TOP" and "TOP" or "BOTTOM", leftExtra, rightExtra)
        -- the auras on its side move out while it shows (in a fight too: they are not protected)
        f.Cast.onShownChanged = function() PositionAuraContainers(f) end
    end

    LayoutAuras(f)
    LayoutIndicators(f)
end

--------------------------------------------------
-- 11. BLIZZARD EXTRAS THAT FOLLOW OUR FRAMES
-- PlayerBottomManagedFrameContainer (anchored to PlayerFrame) goes under the player frame.
--------------------------------------------------
local function AttachExtras(f)
    if InCombatLockdown() then pendingLayout = true return end
    if f.unit == "player" then
        local container = _G.PlayerBottomManagedFrameContainer
        if container then
            container:ClearAllPoints()
            container:SetPoint("TOP", f, "BOTTOM", 0, -2)
        end
    end
end

local extrasHooked = false
local function HookExtras()
    if extrasHooked then return end
    extrasHooked = true
    -- Blizzard re-anchors the bottom container when the player art changes (vehicles)
    for _, name in ipairs({ "PlayerFrame_ToPlayerArt", "PlayerFrame_ToVehicleArt" }) do
        if type(_G[name]) == "function" then
            hooksecurefunc(name, function() if frames.player then AttachExtras(frames.player) end end)
        end
    end
end

--------------------------------------------------
-- 12. POSITIONS (per Edit Mode layout)
--------------------------------------------------
-- Each point anchors to the same point on UIParent
local DEFAULT_POSITIONS = {
    player        = { point = "CENTER", x = -305, y = -270 },
    target        = { point = "CENTER", x = 305,  y = -270 },
    targettarget  = { point = "BOTTOM", x = 235,  y = 252 },
    focus         = { point = "RIGHT",  x = -478, y = -257 },
    focustarget   = { point = "BOTTOM", x = 479,  y = 277 },
    pet           = { point = "BOTTOM", x = -245, y = 271 },   -- its right edge lines up with the player frame's
    playercastbar = { point = "CENTER", x = 0,    y = -221 },  -- mid-screen above the action bars
}

local function GetLayoutStore(layoutName)
    local db = GetDb()
    if not db then return nil end
    layoutName = layoutName or LEM:GetActiveLayoutName() or "Modern"
    db.layouts = db.layouts or {}
    db.layouts[layoutName] = db.layouts[layoutName] or {}
    return db.layouts[layoutName]
end

local function ApplyPosition(f, layoutName)
    if InCombatLockdown() then pendingLayout = true return end
    local store = GetLayoutStore(layoutName)
    local pos = store and store[f.unit] or DEFAULT_POSITIONS[f.unit]
    f:ClearAllPoints()
    f:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or 0, pos.y or 0)
end

local function OnFrameMoved(f, layoutName, point, x, y)
    local store = GetLayoutStore(layoutName)
    if not store then return end
    store[f.unit] = { point = point, x = math_floor(x + 0.5), y = math_floor(y + 0.5) }
end

--------------------------------------------------
-- 13. VISIBILITY (state drivers; in Edit Mode every frame shows)
--------------------------------------------------
local function ApplyVisibility(f)
    if InCombatLockdown() then pendingLayout = true return end
    local info = UNITS[f.unit]
    if LEM:IsInEditMode() then
        UnregisterStateDriver(f, "visibility")
        f:Show()
    elseif info.driver then
        RegisterStateDriver(f, "visibility", info.driver)
    else
        UnregisterStateDriver(f, "visibility")
        f:Show()
    end
end

--------------------------------------------------
-- 14. HIDE PLAYER AND PET (fading)
-- The player and pet frames are see-through unless in combat, with a target, missing health or
-- moused over. Alpha works in combat.
--------------------------------------------------
local FADE = { interval = 0.1, units = { "player", "pet" } }

-- UnitHealth can be secret; a comparison would throw
local function IsHealthMissing(unit)
    local hp, max = UnitHealth(unit), UnitHealthMax(unit)
    if not (canaccessvalue(hp) and canaccessvalue(max)) then return false end
    return hp < max
end

function FADE.ShouldShow()
    if LEM:IsInEditMode() or InCombatLockdown() or UnitExists("target") then return true end
    for _, unit in ipairs(FADE.units) do
        local f = frames[unit]
        if f and f:IsShown() and f:IsMouseOver() then return true end
    end
    return IsHealthMissing("player")
end

function FADE.SetAlpha(alpha)
    for _, unit in ipairs(FADE.units) do
        local f = frames[unit]
        if f and math.abs(f:GetAlpha() - alpha) > 0.005 then f:SetAlpha(alpha) end
    end
end

local fader = CreateFrame("Frame")
fader.elapsed = 0

local function FadeTick(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed < FADE.interval then return end
    self.elapsed = 0
    FADE.SetAlpha(FADE.ShouldShow() and 1 or 0)
end

-- The ticker runs only while the frames fade
local function RefreshVisibilityFader()
    fader.elapsed = FADE.interval
    if UF:GetPlayerShow() == "fade" then
        fader:SetScript("OnUpdate", FadeTick)
        FadeTick(fader, 0)
    else
        fader:SetScript("OnUpdate", nil)
        FADE.SetAlpha(1)
    end
end

-- Target, combat-end and health changes decide at once, so the player frame shows with the target
-- frame; the tick covers the mouse and combat start (InCombatLockdown is false in PLAYER_REGEN_DISABLED)
fader:RegisterEvent("PLAYER_TARGET_CHANGED")
fader:RegisterEvent("PLAYER_REGEN_ENABLED")
fader:RegisterUnitEvent("UNIT_HEALTH", "player")
fader:SetScript("OnEvent", function(self)
    if not self:GetScript("OnUpdate") then return end
    self.elapsed = FADE.interval
    FadeTick(self, 0)
end)

--------------------------------------------------
-- 15. FRAME CREATION
--------------------------------------------------
local function OnEnter(f)
    f.Highlight:Show()
    if GameTooltip:IsForbidden() then return end
    GameTooltip_SetDefaultAnchor(GameTooltip, f)
    GameTooltip:SetUnit(f.unit)
    GameTooltip:Show()
end

local function OnLeave(f)
    f.Highlight:Hide()
    if not GameTooltip:IsForbidden() then GameTooltip:Hide() end
end

local function CreateUnitFrame(unit)
    local info = UNITS[unit]
    local f = CreateFrame("Button", "FlareUI_UF_" .. info.key, UIParent, "SecureUnitButtonTemplate,PingableUnitFrameTemplate,BackdropTemplate")
    f.unit = unit
    f:SetFrameStrata("LOW")
    f:SetAttribute("unit", unit)
    f:SetAttribute("*type1", "target")
    f:SetAttribute("*type2", "togglemenu")
    f:RegisterForClicks("AnyUp")
    if type(f.SetRolesets) == "function" then pcall(f.SetRolesets, f, "unitFrames") end
    _G.ClickCastFrames = _G.ClickCastFrames or {}
    _G.ClickCastFrames[f] = true
    f:SetClampedToScreen(true)
    f.editModeName = "FlareUI " .. info.label
    -- stack order: the frames higher in the list draw above the ones after them, so two frames
    -- that touch never mix their borders
    f:SetFrameLevel(10 + (10 - (info.order or 9)) * 20)

    local level = f:GetFrameLevel()
    f.Health = CreateBar(f, level + 1)
    f.Power = CreateBar(f, level + 1)

    -- levels: bars +1, heal / absorb overlay +2, combo strip +3, border +4, text +5
    f.Border = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.Border:SetAllPoints()
    f.Border:SetFrameLevel(level + 4)

    local overlay = CreateFrame("Frame", nil, f)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(level + 5)
    f.Overlay = overlay
    f.Name = overlay:CreateFontString(nil, "OVERLAY")
    f.Name:SetJustifyH("LEFT")
    f.Name:SetWordWrap(false)
    f.Level = overlay:CreateFontString(nil, "OVERLAY")
    f.Level:SetJustifyH("LEFT")
    f.HealthText = overlay:CreateFontString(nil, "OVERLAY")
    f.HealthText:SetJustifyH("RIGHT")
    f.PowerText = overlay:CreateFontString(nil, "OVERLAY")
    f.PowerText:SetJustifyH("RIGHT")

    f.RaidIcon = overlay:CreateTexture(nil, "OVERLAY", nil, 4)   -- above the quest "!" it shares a spot with
    f.RaidIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    f.RaidIcon:Hide()

    f.Separator = overlay:CreateTexture(nil, "ARTWORK")
    f.Separator:SetTexture(SEPARATOR_TEXTURE)
    f.Separator:SetVertexColor(1, 1, 1, 1)
    f.Separator:Hide()

    if info.portrait then
        -- at the bars' level, under the border; the divider is the separator art turned upright
        f.Portrait = CreateFrame("Frame", nil, f)
        f.Portrait:SetFrameLevel(level + 1)
        f.Portrait.Tex = f.Portrait:CreateTexture(nil, "ARTWORK")
        f.Portrait.Tex:SetAllPoints()
        f.Portrait:Hide()
        f.PortraitDivider = overlay:CreateTexture(nil, "ARTWORK")
        f.PortraitDivider:SetTexture(SEPARATOR_TEXTURE)
        f.PortraitDivider:SetTexCoord(0, 0, 1, 0, 0, 1, 1, 1)
        f.PortraitDivider:SetVertexColor(1, 1, 1, 1)
        f.PortraitDivider:Hide()
        pcall(f.RegisterUnitEvent, f, "UNIT_PORTRAIT_UPDATE", unit)
        pcall(f.RegisterUnitEvent, f, "UNIT_MODEL_CHANGED", unit)
    end

    f.Highlight = overlay:CreateTexture(nil, "OVERLAY")
    f.Highlight:SetAllPoints(f.Health)
    f.Highlight:SetColorTexture(1, 1, 1, 0.08)
    f.Highlight:Hide()

    if info.castbar then f.Cast = CreateCastBar(f, unit) end
    if info.comboPoints then
        CreateComboPoints(f)
        ApplyComboMode(f)
    end
    CreateIndicators(f)
    if unit == "player" then CreateFsrSpark(f) end
    if info.happiness then CreateHappiness(f) end
    PrecreateAuraContainers(f)

    f:SetScript("OnEnter", OnEnter)
    f:SetScript("OnLeave", OnLeave)
    f:SetScript("OnEvent", OnUnitEvent)
    for _, event in ipairs(UNIT_EVENTS) do
        pcall(f.RegisterUnitEvent, f, event, unit)
    end
    if info.events then
        for _, event in ipairs(info.events) do pcall(f.RegisterUnitEvent, f, event, unit) end
    end
    if f.Combo then
        -- re-registered for the target and the player
        for event in pairs(COMBO_EVENTS) do pcall(f.RegisterUnitEvent, f, event, unit, "player") end
    end
    if info.castbar then
        for _, event in ipairs(CAST_EVENTS) do pcall(f.RegisterUnitEvent, f, event, unit) end
    end
    pcall(f.RegisterEvent, f, "RAID_TARGET_UPDATE")
    if info.indicators then
        if info.indicators.heals then
            pcall(f.RegisterUnitEvent, f, "UNIT_HEAL_PREDICTION", unit)
            pcall(f.RegisterUnitEvent, f, "UNIT_ABSORB_AMOUNT_CHANGED", unit)
        end
        if info.indicators.readyCheck then
            for _, event in ipairs({ "READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED" }) do
                pcall(f.RegisterEvent, f, event)
            end
        end
        if info.indicators.threat then
            pcall(f.RegisterUnitEvent, f, "UNIT_THREAT_LIST_UPDATE", unit)
            pcall(f.RegisterUnitEvent, f, "UNIT_THREAT_SITUATION_UPDATE", "player", unit)
        end
    end
    -- the unit behind a token changed: refresh everything
    if info.globalEvents then
        for event, filter in pairs(info.globalEvents) do
            if filter == true then
                pcall(f.RegisterEvent, f, event)
            else
                pcall(f.RegisterUnitEvent, f, event, filter)
            end
        end
    end

    frames[unit] = f
    return f
end

--------------------------------------------------
-- 16. EDIT MODE SETTINGS
--------------------------------------------------
-- Media dropdown values: FlareUI's own, then a divider and other addons' (ns.AddonMedia). A function,
-- so media registered later is listed. first: an entry before FlareUI's ("" = the frame's own).
function UF.MediaValues(mediaType, base, first)
    return function()
        local values = {}
        if first then values[1] = first end
        for _, name in ipairs(base) do
            if LSM:IsValid(mediaType, name) then values[#values + 1] = { text = name, value = name, isRadio = true } end
        end
        local others = ns.AddonMedia(mediaType)
        if #others > 0 then
            values[#values + 1] = { isDivider = true }
            for _, name in ipairs(others) do values[#values + 1] = { text = name, value = name, isRadio = true } end
        end
        return values
    end
end
UF.FLAREUI_BARS = { "FlareUI Flat", "FlareUI Forever", "FlareUI Striped" }

-- Bar, Cast Bar and Absorb Texture values
local function BuildTextureValues()
    return UF.MediaValues("statusbar", UF.FLAREUI_BARS)
end

-- Border Texture values (Frame Border first on the cast bars)
local function BuildBorderValues(withFrameDefault)
    return UF.MediaValues("border", { "FlareUI Thick", "FlareUI Thin" },
        withFrameDefault and { text = L["Frame Border"], value = "", isRadio = true } or nil)
end

-- Edit Mode dialogs in collapsible sections, in a fixed order for every FlareUI frame:
--   (Party / Raid: the group)  Frame  Look  Cast Bar  Auras  Icons  Pet
-- Open state is shared by all frames (editSections); a section with every setting hidden hides too.
--   local Section, settings = EditSections(); Section("Frame", { ... }); return settings
-- (helpers inside: the main chunk is near Lua's 200 locals)
local function EditSections()
    local function IsHidden(hidden, ...)
        if type(hidden) == "function" then return hidden(...) end
        return hidden and true or false
    end
    local function EditSectionOpen(key)
        local db = GetDb()
        return db and db.editSections and db.editSections[key] or false
    end
    local settings = {}
    local function Section(key, items)
        if #items == 0 then return end
        local own = {}
        for i, item in ipairs(items) do own[i] = item.hidden end
        settings[#settings + 1] = { name = "|cffffd100" .. L[key] .. "|r", kind = LEM.SettingType.Expander, default = false,
            get = function() return EditSectionOpen(key) end,
            set = function(_, value)
                local db = GetDb()
                if not db then return end
                db.editSections = db.editSections or {}
                db.editSections[key] = value and true or nil
            end,
            hidden = function(...)
                for i = 1, #items do
                    if not IsHidden(own[i], ...) then return false end
                end
                return true
            end }
        for i, item in ipairs(items) do
            item.hidden = function(...)
                if not EditSectionOpen(key) then return true end
                return IsHidden(own[i], ...)
            end
            settings[#settings + 1] = item
        end
    end
    return Section, settings
end

--------------------------------------------------
-- 17. STANDALONE PLAYER CAST BAR
-- Replaces PlayerCastingBarFrame with a bar in the unit-frame style that moves freely in Edit Mode.
--------------------------------------------------
local playerCastHolder

local function GetPlayerCastDb()
    local db = GetDb()
    return db and db.playerCastbar
end

local function LayoutPlayerCastBar()
    local holder = playerCastHolder
    local cfg = GetPlayerCastDb()
    if not holder or not cfg then return end
    if InCombatLockdown() then pendingLayout = true return end
    local style = GetCastStyle(cfg, true)
    local _, PADDING = BorderFit(style.height, style.border and GetBorderFile(style.borderTexture))
    local iconOffset = style.icon and (style.height + CAST_ICON_GAP) or 0
    holder:SetSize(style.width + iconOffset + 2 * PADDING, style.height + 2 * PADDING)
    LayoutCastBar(holder.Cast, style, holder, "FILL")
end

local function CreatePlayerCastBar()
    if playerCastHolder then return playerCastHolder end
    local holder = CreateFrame("Frame", "FlareUI_UF_PlayerCastBar", UIParent)
    holder:SetFrameStrata("MEDIUM")
    holder:SetClampedToScreen(true)
    holder.unit = "playercastbar"
    holder.editModeName = "FlareUI Player Cast Bar"
    holder.Cast = CreateCastBar(holder, "player")
    holder.Cast.standalone = true
    holder:SetScript("OnEvent", function(self) UpdateCastBar(self.Cast, IsCastEnabled(self.Cast)) end)
    for _, event in ipairs(CAST_EVENTS) do pcall(holder.RegisterUnitEvent, holder, event, "player") end
    pcall(holder.RegisterEvent, holder, "PLAYER_ENTERING_WORLD")
    playerCastHolder = holder
    return holder
end

local function BuildPlayerCastSettings()
    local function get(key, default)
        return function() local c = GetPlayerCastDb(); local v = c and c[key]; if v == nil then return default end; return v end
    end
    local function set(key)
        return function(_, value)
            local c = GetPlayerCastDb()
            if not c then return end
            c[key] = value
            LayoutPlayerCastBar()
            if playerCastHolder then UpdateCastBar(playerCastHolder.Cast, IsCastEnabled(playerCastHolder.Cast)) end
        end
    end
    -- the switches hide a part: on means the saved icon / timer is off
    local function hide(key)
        return function() local c = GetPlayerCastDb(); return c and c[key] == false or false end,
               function(layoutName, value) set(key)(layoutName, not value) end
    end
    local getHideIcon, setHideIcon = hide("icon")
    local getHideTimer, setHideTimer = hide("timer")
    local Section, settings = EditSections()
    Section("Frame", {
        { name = L["Width"], kind = LEM.SettingType.Slider, default = 250, minValue = 100, maxValue = 600, valueStep = 2, get = get("width", 250), set = set("width") },
        { name = L["Height"], kind = LEM.SettingType.Slider, default = 25, minValue = 8, maxValue = 48, valueStep = 1, get = get("height", 25), set = set("height") },
        { name = L["Hide Icon"], kind = LEM.SettingType.Checkbox, default = false, get = getHideIcon, set = setHideIcon,
          desc = L["No spell icon left of the bar."] },
        { name = L["Hide Spell Timer"], kind = LEM.SettingType.Checkbox, default = false, get = getHideTimer, set = setHideTimer,
          desc = L["No time left at the right end of the bar."] },
    })
    Section("Look", {
        { name = L["Bar Texture"], kind = LEM.SettingType.Dropdown, default = DEFAULT_TEXTURE, values = BuildTextureValues(), get = get("texture", DEFAULT_TEXTURE), set = set("texture") },
        { name = L["Border Texture"], kind = LEM.SettingType.Dropdown, default = "FlareUI Thin", values = BuildBorderValues(false), get = get("borderTexture", "FlareUI Thin"), set = set("borderTexture"),
          hidden = function() return ns.UFRing and ns.UFRing.PlateOn() or false end },
        UF.BgOpacitySetting(UF.BAR_BG_OPACITY, get("bgOpacity", UF.BAR_BG_OPACITY), set("bgOpacity")),
    })
    return settings
end

local function BuildSettings(unit)
    local info = UNITS[unit]
    local function get(key) return function() local u = GetUnitDb(unit); return u and u[key] end end
    local function set(key)
        return function(_, value)
            local u = GetUnitDb(unit)
            if not u then return end
            u[key] = value
            local f = frames[unit]
            if f then LayoutFrame(f); UpdateAll(f) end
        end
    end
    local defaults = ns.defaults and ns.defaults.profile.unitframes.units[unit] or {}

    -- sizes, then the portrait, then the texts. Forever Style's Scale sets ring and height together.
    local function onPlate() return ns.UFRing and ns.UFRing.Plate(frames[unit]) or false end
    local settings = {}
    if info.portrait and ns.UFRing and ns.UFRing.PLATE_UNITS[unit] then
        settings[#settings + 1] = { name = L["Scale"], kind = LEM.SettingType.Slider, default = ns.UFRing.PlateDefaultScale(unit),
            minValue = 75, maxValue = 250, valueStep = 5,
            formatter = function(value) return value .. "%" end,
            get = function() return ns.UFRing.GetPlateScale(unit) end,
            set = function(_, value)
                -- Forever Style only (Edit Mode's reset runs hidden settings too)
                if not onPlate() then return end
                ns.UFRing.SetPlateScale(unit, value)
                local f = frames[unit]
                if f then LayoutFrame(f); UpdateAll(f) end
            end,
            hidden = function() return not onPlate() end }
    end
    -- the ring styles' presets have their own widths
    local width = ns.UFRing and ns.UFRing.On() and ns.UFRing.PresetValue(unit, "width") or defaults.width or 220
    settings[#settings + 1] = { name = L["Width"], kind = LEM.SettingType.Slider, default = width, minValue = 60, maxValue = 500, valueStep = 2, get = get("width"), set = set("width") }
    settings[#settings + 1] = { name = L["Height"], kind = LEM.SettingType.Slider, default = defaults.height or 44, minValue = 16, maxValue = 120, valueStep = 1, get = get("height"), set = set("height"),
        hidden = onPlate }
    settings[#settings + 1] = { name = L["Power Bar Height"], kind = LEM.SettingType.Slider, default = defaults.powerHeight or 8, minValue = 0, maxValue = 40, valueStep = 1, get = get("powerHeight"), set = set("powerHeight"),
        formatter = function(value) return value == 0 and _G.OFF or value end,
        -- Forever Style: the plate has its own power slot
        hidden = onPlate }
    if info.portrait and ns.UFRing then
        -- FlareUI Style's ring (and the portrait in it)
        settings[#settings + 1] = { name = L["Portrait Size"], kind = LEM.SettingType.Slider, default = ns.UFRing.DefaultSize(unit),
            minValue = 36, maxValue = 120, valueStep = 1,
            get = function() local u = GetUnitDb(unit); return u and u.ringSize or ns.UFRing.DefaultSize(unit) end,
            set = set("ringSize"),
            hidden = function() return not ns.UFRing.On() or onPlate() end }
    end
    if info.portrait then
        local portraitValues = {
            { text = L["None"],       value = "none",  isRadio = true },
            { text = L["3D"],         value = "3d",    isRadio = true },
            { text = L["Class Icon"], value = "class", isRadio = true },
        }
        settings[#settings + 1] = { name = L["Portrait"], kind = LEM.SettingType.Dropdown, default = "none",
            values = portraitValues,
            -- the Forever style always has a portrait: None is left out there
            generator = function(_, rootDescription, data)
                local ring = ns.UFRing and ns.UFRing.On()
                for _, p in ipairs(portraitValues) do
                    if not (ring and p.value == "none") then
                        rootDescription:CreateRadio(p.text,
                            function(value) local u = GetUnitDb(unit); local cur = u and u.portrait or "none"; if ring and cur == "none" then cur = "3d" end; return cur == value end,
                            function(value) data.set(nil, value) end, p.value)
                    end
                end
            end,
            get = function() local u = GetUnitDb(unit); return u and u.portrait or "none" end, set = set("portrait") }
    end
    settings[#settings + 1] = { name = L["Health Text"], kind = LEM.SettingType.Dropdown, default = defaults.healthText or "percent", values = HEALTH_TEXT_MODES, get = get("healthText"), set = set("healthText") }
    settings[#settings + 1] = { name = L["Power Text"], kind = LEM.SettingType.Checkbox, default = defaults.powerText or false, get = get("powerText"), set = set("powerText") }
    -- (the ring styles show it in the ring's disc, which goes with it)
    settings[#settings + 1] = { name = L["Show Level"], kind = LEM.SettingType.Checkbox, default = defaults.showLevel ~= false, get = get("showLevel"), set = set("showLevel") }
    if info.mirrorable then
        -- flips text order and bar fill so the frame faces the player frame
        settings[#settings + 1] = { name = L["Mirror"], kind = LEM.SettingType.Checkbox, default = defaults.mirror or false, get = function() local u = GetUnitDb(unit); return u and u.mirror or false end,
            set = function(_, value) local u = GetUnitDb(unit); if not u then return end; u.mirror = value; local f = frames[unit]; if f then LayoutFrame(f); AttachExtras(f); UpdateAll(f) end end }
    end
    if unit == "player" then
        settings[#settings + 1] = { name = L["Five-Second Rule"], kind = LEM.SettingType.Checkbox, default = false,
            get = function() local u = GetUnitDb(unit); return u and u.fsr == true or false end,
            set = function(_, value) local u = GetUnitDb(unit); if not u then return end; u.fsr = value; UpdateFsrSpark() end,
            desc = L["A spark crosses the bar for five seconds after a spell that costs mana: spirit regen comes back when it ends."] }
    end
    -- everything above is the frame itself, and gets the first section
    local frameItems = settings
    local Section
    Section, settings = EditSections()
    Section("Frame", frameItems)

    -- the bars' texture and the border; the ring styles keep their own border
    local lookItems = {
        { name = L["Bar Texture"], kind = LEM.SettingType.Dropdown, default = defaults.texture or DEFAULT_TEXTURE, values = BuildTextureValues(),
          get = function() local u = GetUnitDb(unit); return u and u.texture or DEFAULT_TEXTURE end, set = set("texture") },
        { name = L["Border Texture"], kind = LEM.SettingType.Dropdown, default = defaults.border or DEFAULT_BORDER, values = BuildBorderValues(false),
          get = function() local u = GetUnitDb(unit); return u and u.border or DEFAULT_BORDER end, set = set("border"),
          -- Forever Style: one fixed border (the plate's own on its frames)
          hidden = function() return ns.UFRing and ns.UFRing.PlateOn() or false end },
    }
    -- the absorb overlay, on frames with heal prediction; "" is the frame's own texture
    if info.indicators and info.indicators.heals then
        lookItems[#lookItems + 1] = { name = L["Absorb Texture"], kind = LEM.SettingType.Dropdown, default = defaults.absorbTexture or ABSORB_TEXTURE,
            values = BuildTextureValues(),
            get = function() local u = GetUnitDb(unit); local v = u and u.absorbTexture; if v == nil then return ABSORB_TEXTURE end; return v end,
            set = set("absorbTexture"),
            desc = L["The texture of the shield (absorb) over the health bar."] }
    end
    -- last in Look: how dark the bars' empty part is
    local bgDefault = UF.DefaultBgOpacity(unit)
    lookItems[#lookItems + 1] = UF.BgOpacitySetting(bgDefault,
        function() local u = GetUnitDb(unit); local v = u and u.bgOpacity; if v == nil then return bgDefault end; return v end,
        set("bgOpacity"))
    Section("Look", lookItems)

    if info.castbar then
        Section("Cast Bar", {
            { name = L["Cast Bar Position"], kind = LEM.SettingType.Dropdown, default = defaults.castbarPosition or "BOTTOM",
              values = { { text = L["Above"], value = "TOP", isRadio = true }, { text = L["Below"], value = "BOTTOM", isRadio = true } },
              get = get("castbarPosition"), set = set("castbarPosition") },
            { name = L["Cast Bar Height"], kind = LEM.SettingType.Slider, default = defaults.castHeight or CAST_HEIGHT, minValue = 8, maxValue = 40, valueStep = 1,
              get = function() local u = GetUnitDb(unit); return u and u.castHeight or CAST_HEIGHT end, set = set("castHeight") },
            { name = L["Hide Icon"], kind = LEM.SettingType.Checkbox, default = false,
              get = function() local u = GetUnitDb(unit); return u and u.castIcon == false or false end,
              set = function(layoutName, value) set("castIcon")(layoutName, not value) end,
              desc = L["No spell icon left of the bar."] },
            { name = L["Hide Spell Timer"], kind = LEM.SettingType.Checkbox, default = false,
              get = function() local u = GetUnitDb(unit); return u and u.castTimer == false or false end,
              set = function(layoutName, value) set("castTimer")(layoutName, not value) end,
              desc = L["No time left at the right end of the bar."] },
            { name = L["Cast Bar Texture"], kind = LEM.SettingType.Dropdown, default = defaults.castTexture or "", values = BuildTextureValues(),
              get = function() local u = GetUnitDb(unit); return u and u.castTexture or "" end, set = set("castTexture") },
            { name = L["Cast Bar Border Texture"], kind = LEM.SettingType.Dropdown, default = defaults.castBorderTexture or "", values = BuildBorderValues(true),
              get = function() local u = GetUnitDb(unit); return u and u.castBorderTexture or "" end, set = set("castBorderTexture"),
              desc = L["Frame Border uses the frame's own border."],
              hidden = function() return ns.UFRing and ns.UFRing.PlateOn() or false end },
        })
    end
    if info.auras then
        local positions = {
            { text = L["Off"],          value = "OFF" },
            { text = L["Top"],          value = "TOP" },
            { text = L["Top Left"],     value = "TOPLEFT" },
            { text = L["Top Right"],    value = "TOPRIGHT" },
            { text = L["Bottom"],       value = "BOTTOM" },
            { text = L["Bottom Left"],  value = "BOTTOMLEFT" },
            { text = L["Bottom Right"], value = "BOTTOMRIGHT" },
        }
        -- buffs and debuffs never share a place: one that clashes with the other kind's (the same
        -- corner, or Top / Bottom and anything on that edge) is greyed out
        local function Corner(field, other)
            return function(_, rootDescription, data)
                for _, p in ipairs(positions) do
                    local radio = rootDescription:CreateRadio(p.text,
                        function(value) return (get(field)() or "OFF") == value end,
                        function(value) data.set(nil, value) end, p.value)
                    if AURA.Clash(p.value, get(other)()) and radio.SetEnabled then radio:SetEnabled(false) end
                end
            end
        end
        local auraItems = {
            { name = L["Buffs"], kind = LEM.SettingType.Dropdown, default = defaults.buffs or "OFF", values = positions,
              generator = Corner("buffs", "debuffs"), get = get("buffs"), set = set("buffs") },
            { name = L["Debuffs"], kind = LEM.SettingType.Dropdown, default = defaults.debuffs or "OFF", values = positions,
              generator = Corner("debuffs", "buffs"), get = get("debuffs"), set = set("debuffs") },
            { name = L["Aura Size"], kind = LEM.SettingType.Slider, default = defaults.auraSize or 22, minValue = 12, maxValue = 48, valueStep = 1, get = get("auraSize"), set = set("auraSize") },
        }
        -- the player: which buffs to leave out, by their full duration (one choice: Blizzard's filter
        -- for a longest duration always leaves out the permanent ones too)
        if unit == "player" then
            table.insert(auraItems, 3, { name = L["Hide Buffs"], kind = LEM.SettingType.Dropdown, default = "PERMANENT",
                values = {
                    { text = L["Off"], value = "OFF", isRadio = true },
                    { text = L["Permanent"], value = "PERMANENT", isRadio = true },
                    { text = L["Longer than 15 Minutes"], value = "900", isRadio = true },
                    { text = L["Longer than 10 Minutes"], value = "600", isRadio = true },
                    { text = L["Longer than 5 Minutes"], value = "300", isRadio = true },
                    { text = L["Longer than 1 Minute"], value = "60", isRadio = true },
                },
                get = function() local u = GetUnitDb(unit); return u and u.hideBuffs or "PERMANENT" end,
                set = set("hideBuffs"),
                desc = L["Buffs left off the player frame, by their full duration. Every choice but Off also hides permanent buffs."] })
        end
        -- the player: Focus Boss Debuffs, after Aura Size
        if unit == "player" then
            auraItems[#auraItems + 1] = { name = L["Focus Boss Debuffs"], kind = LEM.SettingType.Checkbox, default = false,
          get = function() local u = GetUnitDb(unit); return u and u.encounterOnly or false end, set = set("encounterOnly"),
          desc = L["In a boss fight, only the boss and role debuffs (the ones Blizzard marks as cast by a boss, or aimed at a role). Every debuff shows elsewhere."] }
        end
        -- the focus can do without auras altogether
        if unit == "focus" then
            auraItems[#auraItems + 1] = { name = L["Hide Auras"], kind = LEM.SettingType.Checkbox, default = false, get = get("hideAuras"), set = set("hideAuras"),
                desc = L["No buffs or debuffs on the focus frame."] }
        end
        -- every debuff on yourself is yours to see: other units only
        if unit ~= "player" then
            auraItems[#auraItems + 1] = { name = L["Only My Debuffs"], kind = LEM.SettingType.Checkbox, default = defaults.onlyMyDebuffs or false, get = get("onlyMyDebuffs"), set = set("onlyMyDebuffs") }
        end
        Section("Auras", auraItems)
    end

    -- one switch per icon; where they sit is fixed
    local icons = ICON_UI.List(unit)
    if #icons > 0 then
        local items = {}
        for _, key in ipairs(icons) do
            local def = ICON_UI.defs[key]
            items[#items + 1] = { name = def.label, kind = LEM.SettingType.Checkbox, default = def.default ~= false,
                hidden = (def.ring and function() return not (ns.UFRing and ns.UFRing.On()) end)
                    or (def.noRing and function() return ns.UFRing and ns.UFRing.On() or false end) or nil,
                get = function() return ICON_UI.Shown(unit, key) end,
                set = function(_, value)
                    local store = ICON_UI.Store(unit, key, true)
                    if not store then return end
                    store.shown = value
                    local f = frames[unit]
                    if f then LayoutFrame(f); UpdateAll(f) end
                end }
            -- the pet: where its happiness face sits (while it shows)
            if key == "happiness" then
                items[#items + 1] = { name = L["Happiness Position"], kind = LEM.SettingType.Dropdown, default = "CENTER",
                    values = { { text = L["Centre"], value = "CENTER", isRadio = true },
                               { text = L["Right of the Frame"], value = "RIGHT", isRadio = true },
                               { text = L["Left of the Frame"], value = "LEFT", isRadio = true } },
                    hidden = function() return not ICON_UI.Shown(unit, "happiness") end,
                    get = function() local store = ICON_UI.Store(unit, "happiness"); return store and store.place or "CENTER" end,
                    set = function(_, value)
                        local store = ICON_UI.Store(unit, "happiness", true)
                        if not store then return end
                        store.place = value
                        local f = frames[unit]
                        if f then LayoutFrame(f) end
                    end }
            end
        end
        Section("Icons", items)
    end
    return settings
end

local function RegisterEditMode(f)
    LEM:AddFrame(f, OnFrameMoved, DEFAULT_POSITIONS[f.unit], "FlareUI " .. UNITS[f.unit].label)
    LEM:AddFrameSettings(f, BuildSettings(f.unit))
end

--------------------------------------------------
-- 18. PUBLIC
--------------------------------------------------
-- Building blocks the party, raid and boss frames and the resource bars share with these frames
UF.Kit = {
    -- Forever Style's fixed border, and whether border options are hidden (Forever Style: always);
    -- Background Opacity's bar background and its Edit Mode slider
    Border = function(name) return ns.UFRing and ns.UFRing.Border(name) or name end,
    NoBorderOptions = function() return ns.UFRing and ns.UFRing.PlateOn() or false end,
    BAR_BG_OPACITY = UF.BAR_BG_OPACITY, SetBarBackground = UF.SetBarBackground, BgOpacitySetting = UF.BgOpacitySetting,
    INSET = INSET, BG_OPACITY = BG_OPACITY, BACKDROP_FILE = BACKDROP_FILE,
    SEPARATOR_TEXTURE = SEPARATOR_TEXTURE, SEPARATOR_HEIGHT = SEPARATOR_HEIGHT, TEXT_INSET = TEXT_INSET,
    CAST_GAP = CAST_GAP, AURA_GAP = AURA_GAP,
    DEFAULT_TEXTURE = DEFAULT_TEXTURE,
    HEAL_COLOR = HEAL_COLOR, ABSORB_COLOR = ABSORB_COLOR, HEAL_TEXTURE = HEAL_TEXTURE, ABSORB_TEXTURE = ABSORB_TEXTURE,
    HEALTH_TEXT_MODES = HEALTH_TEXT_MODES, CAST_EVENTS = CAST_EVENTS,
    DEAD_TEXT = DEAD_TEXT, GHOST_TEXT = GHOST_TEXT, OFFLINE_TEXT = OFFLINE_TEXT,
    percentCurve = percentCurve,
    GetDb = GetDb,
    GetBarTexture = GetBarTexture, GetBorderFile = GetBorderFile, BorderFit = BorderFit,
    ApplyBorderStyle = ApplyBorderStyle, ResetBorderTint = ResetBorderTint, SetBorderTint = SetBorderTint,
    CreateBar = CreateBar, ApplyFont = ApplyFont,
    GetHealthColor = GetHealthColor, GetPowerColor = GetPowerColor,
    HardHide = HardHide, SetIconArt = SetIconArt, HasAtlas = HasAtlas,
    CreateCastBar = CreateCastBar, LayoutCastBar = LayoutCastBar, UpdateCastBar = UpdateCastBar,
    InitAuraButton = InitAuraButton, HasAuraSupport = HasAuraSupport,
    BuildTextureValues = BuildTextureValues, BuildBorderValues = BuildBorderValues, BuildAbsorbValues = BuildTextureValues, EditSections = EditSections,
    ThreatColor = ThreatColor,
}

function UF:Refresh()
    if not self.initialized then return end
    if InCombatLockdown() then pendingLayout = true return end
    pendingLayout = false
    -- one frame failing to lay out must not leave the others (or the cast bar) half-built
    local function guard(label, fn, ...)
        local ok, err = pcall(fn, ...)
        if not ok then print("|cffff0000FlareUI UnitFrames:|r " .. label .. ": " .. tostring(err)) end
    end
    for unit, f in pairs(frames) do
        guard(unit, function()
            LayoutFrame(f)
            ApplyPosition(f)
            ApplyVisibility(f)
            AttachExtras(f)
            if f.Combo then ApplyComboMode(f) end
            UpdateAll(f)
        end)
    end
    RefreshVisibilityFader()
    -- the group frames and resource bars share the fonts, palette and class colours set here
    if ns.PartyFrames and ns.PartyFrames.initialized then guard("party frames", function() ns.PartyFrames:Refresh() end) end
    if ns.RaidFrames and ns.RaidFrames.initialized then guard("raid frames", function() ns.RaidFrames:Refresh() end) end
    if ns.BossFrames and ns.BossFrames.initialized then guard("boss frames", function() ns.BossFrames:Refresh() end) end
    if ns.ResourceBars and ns.ResourceBars.initialized then guard("resource bars", function() ns.ResourceBars:Refresh() end) end
    if playerCastHolder then
        guard("player cast bar", function()
            LayoutPlayerCastBar()
            ApplyPosition(playerCastHolder)
            UpdateCastBar(playerCastHolder.Cast, IsCastEnabled(playerCastHolder.Cast))
        end)
    end
end

-- Fade Player and Pet (Settings > Unit Frames): "always", or "fade" (section 14). Saved as the four
-- conditions it stands for; any one of them on reads as "fade".
UF.PLAYER_FADE = { condMouseover = true, condCombat = true, condTarget = true, condHealth = true }
function UF:GetPlayerShow()
    local db = GetDb()
    local v = db and db.visibility and db.visibility.player
    return v and (v.condCombat or v.condMouseover or v.condTarget or v.condHealth) and "fade" or "always"
end

function UF:SetPlayerShow(mode)
    local db = GetDb()
    local v = db and db.visibility and db.visibility.player
    if not v then return end
    for key, on in pairs(UF.PLAYER_FADE) do v[key] = (mode == "fade") and on or false end
    self:RefreshVisibility()
end

function UF:RefreshVisibility()
    if not self.initialized then return end
    RefreshVisibilityFader()
end

function UF:PLAYER_REGEN_ENABLED()
    if pendingLayout then self:Refresh() end
end

function UF:PLAYER_ENTERING_WORLD()
    for _, f in pairs(frames) do UpdateAll(f) end
    if playerCastHolder then UpdateCastBar(playerCastHolder.Cast, IsCastEnabled(playerCastHolder.Cast)) end
end

function UF:Init()
    if self.initialized then return end
    local db = GetDb()
    if not db then return end
    UF.ApplyPalette()
    -- the ring styles have their own default positions (a style switch reloads)
    if ns.UFRing and ns.UFRing.On() then
        for key, pos in pairs((ns.UFRing.DefaultPositions())) do DEFAULT_POSITIONS[key] = pos end
    end

    for _, unit in ipairs(UNIT_ORDER) do
        local udb = db.units[unit]
        if udb and udb.enabled then
            local f = CreateUnitFrame(unit)
            RegisterEditMode(f)
            if UNITS[unit].blizzard then
                for _, name in ipairs(UNITS[unit].blizzard) do
                    if name == "TargetFrame" and ns.IsGamepadUI() then KeepAsMenuOwner(name, f) else HardHide(name) end
                end
            end
        end
    end
    if db.playerCastbar and db.playerCastbar.enabled then
        local holder = CreatePlayerCastBar()
        LEM:AddFrame(holder, OnFrameMoved, DEFAULT_POSITIONS.playercastbar, holder.editModeName)
        LEM:AddFrameSettings(holder, BuildPlayerCastSettings())
        -- also the Gamepad UI's bar (Forever has no GamepadPlayerCastingBarFrame)
        HardHide("PlayerCastingBarFrame")
    end
    HookExtras()
    if frames.player then InitFsrSpark() end
    self.initialized = true

    LEM:RegisterCallback("layout", function(layoutName)
        for _, f in pairs(frames) do ApplyPosition(f, layoutName) end
        if playerCastHolder then ApplyPosition(playerCastHolder, layoutName) end
    end)
    LEM:RegisterCallback("enter", function()
        for _, f in pairs(frames) do ApplyVisibility(f); f:SetAlpha(1); if f.Combo then UpdateComboPoints(f) end; UpdateHappiness(f); UpdateAll(f) end
        for _, f in pairs(frames) do LayoutAuras(f) end
        SetAuraPreview(true)
        SetCastPreview(true)
    end)
    LEM:RegisterCallback("exit", function()
        for _, f in pairs(frames) do ApplyVisibility(f); if f.Combo then UpdateComboPoints(f) end; UpdateHappiness(f); UpdateAll(f) end
        RefreshVisibilityFader()
        for _, f in pairs(frames) do LayoutAuras(f) end
        SetAuraPreview(false)
        SetCastPreview(false)
    end)

    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")

    self:Refresh()
    C_Timer.After(0, function() self:Refresh() end)
end
