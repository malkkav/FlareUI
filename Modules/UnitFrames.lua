local _, ns = ...
local L = ns.L

--------------------------------------------------
-- UNIT FRAMES
-- Player / target / target-of-target / focus / pet frames. Health, power and name values may be
-- secret: they go straight into widget setters and are never inspected. Placed and tuned in Edit
-- Mode; Blizzard's frames are parked.
-- Main-chunk locals are near Lua's limit of 200 (locals.js): new constants go into tables.
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
-- Fixed look: the border art overlaps the bar edges by INSET, the backdrop is transparent, the
-- border band is 16 px
local INSET         = 4
local BORDER_SIZE   = 16
local BG_OPACITY    = 0
local DEFAULT_BORDER_COLOR = ns.BORDER_COLOR
local DEFAULT_BORDER  = "FlareUI Thick"
local DEFAULT_TEXTURE = "FlareUI Flat"
local SEPARATOR_TEXTURE = "Interface\\Common\\UI-TooltipDivider-Transparent"   -- same as chat / damage meter
local SEPARATOR_HEIGHT  = 8
local AURA_GAP      = 4     -- between the frame (or cast bar) and the aura rows
local TEXT_INSET    = 4
local PORTRAIT_GAP  = 0      -- room between the portrait square and the bars; the divider straddles the seam
local CAST_HEIGHT   = 18
local CAST_GAP      = 4
local CAST_ICON_GAP = 0     -- icon sits flush against the bar
local RAID_ICON     = 18     -- the smallest pet happiness face
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
local CAST_COLOR            = { 0.80, 0.60, 0.36 }   -- #CC995C
local CAST_NOINTERRUPT      = { 0.55, 0.55, 0.55 }
local CAST_CHANNEL          = { 0.30, 0.65, 0.90 }
-- the player's own bar is cool-toned so it never reads as the target's
local PLAYER_CAST_COLOR     = { 0.36, 0.56, 0.78 }   -- #5C8FC7 steel blue
local PLAYER_CAST_CHANNEL   = { 0.50, 0.75, 0.88 }   -- #80BFE0 lighter sky for channels

-- Colour palettes (Unit Frames > Colour palette): FlareUI's tones, or Blizzard's original bright ones.
-- ApplyPalette writes the chosen one into the colour tables above and the shared ns ones, in place.
UF.PALETTES = {
    flareui = {
        health = { 0.15, 0.82, 0.15 }, mana = { 0.24, 0.34, 1.00 }, grey = { 0.55, 0.55, 0.55 },
        hostile = { 0.87, 0.27, 0.27 }, neutral = { 0.93, 0.78, 0.25 }, friendly = { 0.30, 0.78, 0.30 },
        cast = { 0.80, 0.60, 0.36 }, castNoInterrupt = { 0.55, 0.55, 0.55 }, castChannel = { 0.30, 0.65, 0.90 },
        playerCast = { 0.36, 0.56, 0.78 }, playerChannel = { 0.50, 0.75, 0.88 },
    },
    -- Blizzard's own: health green, PowerBarColor's mana, UnitSelectionColor's reactions, the cast bar's
    -- yellow / green channel / grey uninterruptible (the player's bar the same as everyone's)
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
                         PLAYER_FLAGS_CHANGED = "player" },
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
        indicators = { leader = true, pvp = true, classification = true, quest = true, threat = true, heals = true,
                       readyCheck = true, threatGlow = true },
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
        indicators = { classification = true, threat = true, heals = true, readyCheck = true, threatGlow = true },
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
local LayoutAuras          -- defined in 5b

local function GetDb()
    if not ns.db or not ns.db.profile or not ns.db.profile.unitframes then return nil end
    return ns.db.profile.unitframes
end

local function GetUnitDb(unit)
    local db = GetDb()
    return db and db.units and db.units[unit]
end

-- Portrait: "none", "3d" or "class". A square as tall as the frame's inside, taken from the bars.
-- Forever style (UnitFramesRing.lua): always a portrait, in the ring beside the frame; the bars give
-- up only the strip the ring covers.
local function PortraitMode(f)
    local udb = GetUnitDb(f.unit)
    local mode = (f.Portrait and udb and udb.portrait) or "none"
    if mode == "none" and ns.UFRing and ns.UFRing.Applies(f) then mode = "3d" end
    return mode
end

local function PortraitSpace(f)
    if ns.UFRing and ns.UFRing.Applies(f) then return ns.UFRing.BarSpace(f, INSET) end
    if PortraitMode(f) == "none" then return 0 end
    local udb = GetUnitDb(f.unit)
    return ((udb and udb.height) or 44) - 2 * INSET + PORTRAIT_GAP
end

-- The old global element switches, now only the fallback of a frame's own Show Icon
local function ElementOn(key)
    local db = GetDb()
    local elements = db and db.elements
    return not (elements and elements[key] == false)
end

-- The frame icons, per frame in Edit Mode: udb.icons[key] = { shown, x, y, scale }. x / y offset
-- FlareUI's placement, scale is a percentage. Preview (section 9) shows every shown icon in Edit Mode.
local ICON_UI = {
    order = { "rest", "leader", "pvp", "pvpTimer", "classification", "quest", "raidIcon", "readyCheck",
              "statusGlow", "threatGlow", "happiness" },
    defs = {
        rest           = { label = L["Resting"],          field = "RestIcon",  element = "rest" },
        leader         = { label = L["Leader"],           field = "LeaderIcon", element = "leader" },
        pvp            = { label = L["PvP Flag"],         field = "PvPIcon",   element = "pvp" },
        classification = { label = L["Elite & Rare"],     field = "ClassIcon", element = "classification", noRing = true },
        quest          = { label = L["Quest Objective"],  field = "QuestIcon", element = "questBoss" },
        raidIcon       = { label = L["Raid Target"],      field = "RaidIcon",  element = "raidIcon" },
        happiness      = { label = L["Pet Happiness"],    field = "Happiness" },
        -- noRing = not in the Forever style (its dragon frame shows elites and rares)
        -- ring = only in the Forever style (UnitFramesRing.lua draws them)
        readyCheck     = { label = L["Ready Check"],      field = "ReadyIcon", default = true },
        pvpTimer       = { label = L["PvP Timer"],        ring = true, default = false },
        -- the glows: the Forever style's resting / combat glow, and threat (the ring's glow, or the
        -- usual frames' border colour)
        statusGlow     = { label = L["Rest & Combat Glow"], ring = true, default = true },
        threatGlow     = { label = L["Threat Glow"],      default = true },
    },
    -- Blizzard's ready check marks
    READY = {
        ready    = _G.READY_CHECK_READY_TEXTURE or "UI-LFG-ReadyMark",
        notready = _G.READY_CHECK_NOT_READY_TEXTURE or "UI-LFG-DeclineMark",
        waiting  = _G.READY_CHECK_WAITING_TEXTURE or "UI-LFG-PendingMark",
    },
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

function ICON_UI.Shown(unit, key)
    local store = ICON_UI.Store(unit, key)
    if store and store.shown ~= nil then return store.shown end
    if key == "happiness" then
        local udb = GetUnitDb(unit)
        return not udb or udb.happiness ~= false
    end
    local def = ICON_UI.defs[key]
    if def.default ~= nil then return def.default end
    return ElementOn(def.element)
end

-- offset x, offset y, scale factor
function ICON_UI.Offsets(unit, key)
    local store = ICON_UI.Store(unit, key)
    if not store then return 0, 0, 1 end
    return store.x or 0, store.y or 0, (store.scale or 100) / 100
end

-- Sizes and anchors an icon at FlareUI's placement plus the frame's offsets and scale
function ICON_UI.Place(f, key, region, width, height, point, relativeTo, relativePoint, x, y)
    local dx, dy, scale = ICON_UI.Offsets(f.unit, key)
    region:ClearAllPoints()
    region:SetSize(width * scale, height * scale)
    region:SetPoint(point, relativeTo, relativePoint, x + dx, y + dy)
end

-- Percent curve (0..1 -> 0..100) so UnitHealthPercent's secret result can be shown directly
local percentCurve = CurveConstants.ScaleTo100

-- An unknown texture name falls back to FlareUI Flat
local function GetBarTexture(name)
    if not (name and name ~= "" and LSM:IsValid("statusbar", name)) then name = DEFAULT_TEXTURE end
    if name == DEFAULT_TEXTURE and UF.palette == "blizzard" then return UF.PALETTES.blizzard.texture end
    return LSM:Fetch("statusbar", name) or "Interface\\TargetingFrame\\UI-StatusBar"
end

-- An unknown border name falls back to the default
local function GetBorderFile(name)
    if not (name and name ~= "" and LSM:IsValid("border", name)) then name = DEFAULT_BORDER end
    return LSM:Fetch("border", name) or BORDER_FILE
end

local function GetColor(c, fallback)
    c = c or fallback or DEFAULT_BORDER_COLOR
    return c.r or 1, c.g or 1, c.b or 1, c.a or 1
end

-- Border colour: FlareUI's fixed bronze at rest, a status colour (threat) when there is one
local function ResetBorderTint(border)
    border:SetBackdropBorderColor(GetColor(nil))
end

local function SetBorderTint(border, r, g, b)
    border:SetBackdropBorderColor(r, g, b, 1)
end

-- The border edge and inset for a bar of this inner height: below 22 px in all the 16 px corners
-- overlap, so both shrink. FlareUI Thin's 8 px corners fit any bar.
local function BorderFit(innerHeight, edgeFile)
    if edgeFile and ns.BorderEdgeSize(edgeFile, BORDER_SIZE) ~= BORDER_SIZE then
        return ns.BorderEdgeSize(edgeFile, BORDER_SIZE), INSET
    end
    local total = innerHeight + 2 * INSET
    if total >= 22 then return BORDER_SIZE, INSET end
    local edge = math.max(6, math_floor(total * 2 / 3))
    return edge, INSET * edge / BORDER_SIZE
end

-- height: the bordered frame's height with the full inset (BorderFit's rule)
-- The thick edge's inner side is a soft fade that ends where the bars start, so a see-through seam
-- showed between the line and the bars: that border sits a pixel in (scaled with the edge), its line
-- overlapping the bars' edges. It keeps whatever frame it was anchored to.
local function ApplyBorderStyle(border, edgeFile, height)
    local edge, thick = BORDER_SIZE, true
    if ns.BorderEdgeSize(edgeFile, BORDER_SIZE) ~= BORDER_SIZE then
        edge, thick = ns.BorderEdgeSize(edgeFile, BORDER_SIZE), false   -- FlareUI Thin
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
    bar.bg:SetVertexColor(0.15, 0.15, 0.15, 0.9)
    return bar
end

local function ApplyFont(fontString, fontDb, sizeDelta)
    local path = ns.GetFontPath(fontDb and fontDb.face or "Friz Quadrata TT")
    local flags = fontDb and fontDb.flags or "OUTLINE"
    if flags == "NONE" then flags = "" end
    fontString:SetFont(path, (fontDb and fontDb.size or 12) + (sizeDelta or 0), flags)
    ns.ApplyShadow(fontString, fontDb)
end

-- Health bar colour: class colour for players (green with Class Color off), reaction colour for
-- NPCs. A secret class falls back to the reaction colour.
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
    local reaction = UnitReaction(unit, "player")
    local c = reaction and REACTION[reaction] or REACTION[5]
    return c[1], c[2], c[3]
end

local function GetPowerColor(unit)
    local powerType, powerToken = UnitPowerType(unit)
    local r, g, b = ns.PowerColor(powerToken, powerType)
    if r then return r, g, b end
    local c = POWER_FALLBACK[powerToken] or POWER_FALLBACK.MANA
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

-- Gamepad UI: the controller's target menu opens on TargetFrame, and closes at once if its owner is
-- hidden. So it stays shown, without its events, invisible and deaf to the mouse, pinned over our
-- target frame so the menu opens beside ours. Out of combat only.
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

--------------------------------------------------
-- 5. UPDATERS (all secret-safe: values go straight into widgets)
--------------------------------------------------
local function UpdateName(f)
    local unit = f.unit
    f.Name:SetText(UnitName(unit) or "")
end

local function UpdateLevel(f)
    local unit = f.unit
    local udb = GetUnitDb(unit)
    local ringOn = ns.UFRing and ns.UFRing.Applies(f)
    if not (udb and (udb.showLevel or ringOn)) then f.Level:SetText("") return end
    local level = UnitLevel(unit)
    local classification = UnitClassification(unit)
    local suffix = ""
    if classification == "elite" or classification == "rareelite" then suffix = "+" end
    if classification == "rare" or classification == "rareelite" then suffix = "R" .. suffix end
    if canaccessvalue(level) and level then
        if level < 0 then
            f.Level:SetText("??")
            f.Level:SetTextColor(1, 0.1, 0.1)
        else
            f.Level:SetFormattedText("%d%s", level, suffix)
            local color = GetQuestDifficultyColor and GetQuestDifficultyColor(level)
            if color then f.Level:SetTextColor(color.r, color.g, color.b) else f.Level:SetTextColor(1, 1, 1) end
        end
    else
        f.Level:SetText(level)
        f.Level:SetTextColor(1, 1, 1)
    end
    -- Forever style: the player's level is white, as on Blizzard's frame
    if ringOn and unit == "player" then f.Level:SetTextColor(1, 1, 1) end
end

local function UpdateHealth(f)
    local unit = f.unit
    local udb = GetUnitDb(unit)
    local bar = f.Health

    bar:SetMinMaxValues(0, UnitHealthMax(unit))
    bar:SetValue(UnitHealth(unit))
    bar:SetStatusBarColor(GetHealthColor(unit, UF:ClassColorsOn()))

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
    -- one decimal, the way a cast bar has always counted
    local ok, fmt = pcall(C_StringUtil.CreateNumericRuleFormatter)
    if ok and fmt and pcall(fmt.SetBreakpoints, fmt, { { threshold = 0, format = "%.1f" } }) then
        timerFormatter = fmt
    end
    -- "3s" if the rule formatter will not build
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
            width = udb.width or 292, height = udb.height or 26,
            icon = udb.icon ~= false, timer = udb.timer ~= false, name = udb.name ~= false,
            texture = udb.texture, border = true,
            borderTexture = udb.borderTexture,
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
        borderTexture = castBorder,
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

    -- Remaining time, formatted by the client. SetFormatter, as Blizzard's aura buttons use (not
    -- SetTextFormat, which takes "{}" placeholders).
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
-- leftExtra / rightExtra: more room from the anchor's edges (the Forever style's ring)
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

local UpdateComboPoints   -- defined in 5c (needs the layout helpers below)
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

-- Blizzard's render can land a moment after SetPortraitTexture and reset the coordinates: the flip
-- is kept up for a second after each portrait change (UNIT_PORTRAIT_UPDATE starts it again)
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
        if udb and udb.mirror and PortraitFacesRight(unit) then
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
    local health, power = s.health or 0.75, s.power or 0.6
    f.Name:SetText(s.name or info.label)
    if udb and udb.showLevel then
        f.Level:SetText(UnitLevel("player") or "")
        f.Level:SetTextColor(1, 0.82, 0)
    else
        f.Level:SetText("")
    end
    f.Health:SetMinMaxValues(0, 1)
    f.Health:SetValue(health)
    local c = REACTION[5]
    f.Health:SetStatusBarColor(c[1], c[2], c[3])
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
        if f.HealBar then f.HealBar:SetValue(0); f.AbsorbBar:SetValue(0) end
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
        or event == "PLAYER_FLAGS_CHANGED" or event == "QUEST_LOG_UPDATE" then
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
    end
end

--------------------------------------------------
-- 7. AURAS (Blizzard's aura containers)
-- Aura data can be secret, so Blizzard's CustomAuraContainer renders the icons; we hand it our
-- textures and the layout. One container per frame corner, created at login (ones created later
-- are access-restricted and never show).
--------------------------------------------------
local AURA_CONTAINER_TEMPLATE = "CustomAuraContainerTemplate"
local AURA_CORNERS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
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

-- initializeFrame: builds a pooled aura button's visuals once and hands them to the button, which
-- drives icon, cooldown, stacks, duration and dispel colour. With look: the Buffs / Debuffs look
-- (Auras.lua ns.AuraLook); the plain style is the fallback.
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
    -- each corner wraps a little before the middle of the frame; at most two full rows of the
    -- chosen size (so an even count, 4 or more): bigger icons, fewer of them
    local lineSize = math.max(size, math_floor(f:GetWidth() / 2) - INSET - 4)
    local max = 2 * math.max(2, math_floor((lineSize + AURA_SPACING) / (size + AURA_SPACING)))
    entry.generation = entry.generation + 1
    local gen = entry.generation
    for index, lane in ipairs(lanes) do
        local key = lane.key .. gen
        local isDebuff, unit, font = lane.isDebuff, f.unit, db and db.font
        -- the older Aura Timers checkbox left off reads as No Timer
        local db = GetDb()
        local auraTimer = db and db.auraTimer or "none"
        local showTimer = auraTimer ~= "none"
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
        else
            print("|cffff0000FlareUI:|r aura group failed: " .. tostring(err))
        end
    end

    -- grow away from the corner: right/left along the edge, up from the top, down from the bottom;
    -- wrap a little before the middle of the frame so two corners on one edge never meet
    local isTop, isLeft = corner:find("^TOP") ~= nil, corner:find("LEFT$") ~= nil
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

local function PositionAuraContainers(f)
    if not f.Auras then return end
    local inset = INSET
    for corner, entry in pairs(f.Auras) do
        local c = entry.container
        local isTop, isLeft = corner:find("^TOP") ~= nil, corner:find("LEFT$") ~= nil
        local x = isLeft and inset or -inset
        local y = isTop and AURA_GAP or -AURA_GAP
        -- beyond the cast bar when it sits on this side
        local udb = GetUnitDb(f.unit)
        if f.Cast and udb and UNITS[f.unit].castbar and (udb.castbarPosition == "TOP") == isTop then
            local castRoom = (udb.castHeight or CAST_HEIGHT) + CAST_GAP
            y = y + (isTop and castRoom or -castRoom)
        end
        -- Forever style: a corner on the ring's side starts where the ring ends at that height
        if ns.UFRing and ns.UFRing.Applies(f) and (ns.UFRing.Side(f) == "LEFT") == isLeft then
            local clear = ns.UFRing.Clearance(f, math.abs(y))
            x = x + (isLeft and clear or -clear)
        end
        c:ClearAllPoints()
        -- container's own corner nearest the frame sits on the frame's corner, a few px out
        c:SetPoint((isTop and "BOTTOM" or "TOP") .. (isLeft and "LEFT" or "RIGHT"), f, corner, x, y)
        c:SetFrameLevel(f:GetFrameLevel() + 4)
    end
end

LayoutAuras = function(f)
    local udb = GetUnitDb(f.unit)
    if not udb or not f.Auras then return end
    if InCombatLockdown() then pendingLayout = true return end
    local perCorner = {}
    for _, corner in ipairs(AURA_CORNERS) do perCorner[corner] = {} end
    local function AddLane(corner, key, filter, isDebuff, candidates)
        local list = corner and perCorner[corner]
        if list then list[#list + 1] = { key = key, filter = filter, isDebuff = isDebuff, candidates = candidates } end
    end
    -- Edit Mode's sample buffs have no duration: the permanent-buff filter would hide them all
    local buffCandidates
    if udb.hidePermanentBuffs and not LEM:IsInEditMode() then buffCandidates = { maxDuration = 999999 } end
    local debuffCandidates
    if udb.onlyMyDebuffs then debuffCandidates = { isFromPlayerOrPlayerPet = true } end
    -- debuffs first: closest to the frame when both share a corner
    AddLane(udb.debuffs, "debuffs", "HARMFUL", true, debuffCandidates)
    AddLane(udb.buffs, "buffs", "HELPFUL", false, buffCandidates)
    for _, corner in ipairs(AURA_CORNERS) do
        ConfigureAuraCorner(f, corner, perCorner[corner])
    end
    PositionAuraContainers(f)
end

-- Edit Mode: our containers render Blizzard's sample auras
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
-- On Forever combo points belong to the target, as in Classic. A thin segmented strip along the
-- health bar's top edge; each segment is a StatusBar with range [i-1, i] fed the raw (possibly
-- secret) count, so no Lua compares it. Blizzard's ComboFrame is hidden unless Classic Combo is on.
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

-- True when the strip is part of the frame
local function IsComboShown(f)
    return f.Combo ~= nil and f.Combo.count > 0
end

-- Classic Combo Points: Blizzard's ComboFrame in a row in the health bar's bottom-right corner.
-- With the option off it is parked on a hidden parent, where Blizzard's code still runs it.
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

local function UsesClassicCombo(f)
    local udb = GetUnitDb(f.unit)
    local ringOn = ns.UFRing and ns.UFRing.Applies(f)
    return (udb and (udb.classicCombo or ringOn) and GetClassicCombo()) and true or false
end

-- Puts Blizzard's ComboFrame on our frame, or parks it
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
-- A spark crosses the player's mana bar for five seconds after a spell that costs mana (spirit
-- regen stops meanwhile). Mana can be secret, so the cast event and the spell's cost type are the
-- signal; a free cast does not count, a secret amount does. Hidden while the bar shows another power.
-- The same events drive the mana cost preview: while a spell with a mana cost is cast, the mana it
-- will spend shows darker at the end of the bar, as on Blizzard's player frame.
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
    -- Mana cost preview. Mana can be secret, so no arithmetic: a clip runs from the bar's start to the
    -- end of its fill, and a bar of the same width filling from the other end shows the cost in it.
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
        -- the mana cost preview: set when a cast starts, cleared when it ends (a spell allowed during
        -- the cast, off the global cooldown, leaves it)
        local f = frames.player
        if f and f.ManaCost and event ~= "UNIT_DISPLAYPOWER" then
            if event == "UNIT_SPELLCAST_START" then
                local costs, amount = CostsMana(spellID)
                f.manaCost = costs and amount or nil
            elseif select(9, UnitCastingInfo("player")) == nil then
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
local HEAL_TEXTURE    = "FlareUI Flat"
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

local function LayoutIndicators(f)
    local udb = GetUnitDb(f.unit)
    local mirror = udb and udb.mirror and true or false
    -- Forever style: the icons with a home on the ring go there (offsets and scale still apply)
    local ring = ns.UFRing and ns.UFRing.Applies(f) and ns.UFRing
    if ring then
        for _, key in ipairs({ "rest", "leader", "pvp", "classification", "quest", "readyCheck" }) do
            local region = f[ICON_UI.defs[key].field]
            if region then
                local point, rel, relPoint, x, y, w, h = ring.IconSpot(f, key)
                if point then ICON_UI.Place(f, key, region, w, h, point, rel, relPoint, x, y) end
            end
        end
    end
    -- FlareUI's own placement; ICON_UI.Place adds the frame's Edit Mode offsets and scale
    if f.RestIcon and not (ring and ring.IconSpot(f, "rest")) then
        ICON_UI.Place(f, "rest", f.RestIcon, ICON_SIZE.rest, ICON_SIZE.rest, "CENTER", f, "TOPRIGHT", -2, 0)
    end
    if f.LeaderIcon and not (ring and ring.IconSpot(f, "leader")) then
        ICON_UI.Place(f, "leader", f.LeaderIcon, ICON_SIZE.leader, ICON_SIZE.leader, "CENTER", f, "TOPLEFT", 16, -2)
    end
    if f.PvPIcon and not (ring and ring.IconSpot(f, "pvp")) then
        -- bottom-left on the player, bottom-right on a mirrored frame: symmetrical across the screen
        if mirror then
            ICON_UI.Place(f, "pvp", f.PvPIcon, ICON_SIZE.pvp, ICON_SIZE.pvp, "CENTER", f, "BOTTOMRIGHT", -4, 2)
        else
            ICON_UI.Place(f, "pvp", f.PvPIcon, ICON_SIZE.pvp, ICON_SIZE.pvp, "CENTER", f, "BOTTOMLEFT", 4, 2)
        end
    end
    if f.ClassIcon and not (ring and ring.IconSpot(f, "classification")) then
        local info = C_Texture.GetAtlasInfo(ICON_UI.CLASS_SKULL)
        local aspect = (info and info.width > 0 and info.height > 0) and (info.width / info.height) or 1
        -- above the PvP crest, in its column and at its size (top-right on a mirrored frame, top-left otherwise)
        local size = ICON_SIZE.pvp
        if mirror then
            ICON_UI.Place(f, "classification", f.ClassIcon, size * aspect, size, "CENTER", f, "TOPRIGHT", -4, -2)
        else
            ICON_UI.Place(f, "classification", f.ClassIcon, size * aspect, size, "CENTER", f, "TOPLEFT", 4, -2)
        end
    end
    if f.QuestIcon and not (ring and ring.IconSpot(f, "quest")) then
        local info = C_Texture.GetAtlasInfo(QUEST_ATLAS)
        local aspect = (info and info.width > 0 and info.height > 0) and (info.width / info.height) or 1
        -- mid health bar, under the raid marker
        ICON_UI.Place(f, "quest", f.QuestIcon, ICON_SIZE.quest * aspect, ICON_SIZE.quest, "CENTER", f.Health, "CENTER", 0, 0)
    end
    if f.ReadyIcon and not (ring and ring.IconSpot(f, "readyCheck")) then
        -- mid-frame, over the raid marker
        local size = math.min(32, math.max(16, ((udb and udb.height) or 44) - 12))
        ICON_UI.Place(f, "readyCheck", f.ReadyIcon, size, size, "CENTER", f, "CENTER", 0, 0)
    end
    if f.HealClip then
        local health, clip, heal, absorb = f.Health, f.HealClip, f.HealBar, f.AbsorbBar
        local fill = health:GetStatusBarTexture()
        local width = (udb and udb.width or 220) - 2 * INSET - PortraitSpace(f)
        local reverse = (udb and udb.absorbReverseFill) and true or false

        clip:ClearAllPoints()
        heal:ClearAllPoints()
        absorb:ClearAllPoints()
        heal:SetWidth(width)
        absorb:SetWidth(width)
        heal:SetReverseFill(mirror)
        -- a reversed absorb grows back towards the health
        absorb:SetReverseFill(reverse ~= mirror)

        -- the clip keeps the overlays inside the bar without comparing (secret) values
        if mirror then
            -- bar fills from the right; the empty part is on the left
            clip:SetPoint("TOPLEFT", health, "TOPLEFT", 0, 0)
            clip:SetPoint("BOTTOMRIGHT", fill, "BOTTOMLEFT", 0, 0)
            heal:SetPoint("TOPRIGHT", clip, "TOPRIGHT", 0, 0)
            heal:SetPoint("BOTTOMRIGHT", clip, "BOTTOMRIGHT", 0, 0)
        else
            clip:SetPoint("TOPLEFT", fill, "TOPRIGHT", 0, 0)
            clip:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", 0, 0)
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
-- answered was not ready, as on Blizzard's frames)
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
    local space, mirror = PortraitSpace(f), udb.mirror and true or false
    local left, right = PADDING + (mirror and 0 or space), PADDING + (mirror and space or 0)

    health:ClearAllPoints()
    power:ClearAllPoints()
    health:SetPoint("TOPLEFT", f, "TOPLEFT", left, -PADDING)

    if f.Portrait and ns.UFRing and ns.UFRing.Applies(f) then
        ns.UFRing.Layout(f, PADDING)
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
    f:SetSize(width, height)

    local edgeFile = GetBorderFile(udb.border)
    f:SetBackdrop({ bgFile = BACKDROP_FILE, insets = { left = PADDING, right = PADDING, top = PADDING, bottom = PADDING } })
    f:SetBackdropColor(0, 0, 0, BG_OPACITY)
    -- the border's own frame sits above the bars
    ApplyBorderStyle(f.Border, edgeFile, height)

    local texture = GetBarTexture(udb.texture)
    local health, power = f.Health, f.Power
    health:SetStatusBarTexture(texture)
    power:SetStatusBarTexture(texture)
    health.bg:SetTexture(texture)
    power.bg:SetTexture(texture)
    -- mirrored frames fill right to left, text order [health][name][level]
    local mirror = udb.mirror and true or false
    health:SetReverseFill(mirror)
    power:SetReverseFill(mirror)

    LayoutBars(f)

    -- texts
    -- Forever style: one point smaller on the slimmer frames
    local fontDelta = (ns.UFRing and ns.UFRing.Applies(f)) and -1 or 0
    ApplyFont(f.Name, db.font, fontDelta)
    ApplyFont(f.Level, db.font, fontDelta)
    ApplyFont(f.HealthText, db.font, fontDelta)
    ApplyFont(f.PowerText, db.fontPower or db.font, fontDelta)

    f.Level:ClearAllPoints()
    f.Name:ClearAllPoints()
    f.HealthText:ClearAllPoints()
    f.PowerText:ClearAllPoints()
    -- Forever style: the level is in the ring's disc, so the name starts at the bar's edge
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
    f.PowerText:SetShown(udb.powerText and powerHeight >= 10)
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
        ICON_UI.Place(f, "raidIcon", f.RaidIcon, rw, rh, rp, rrel, rrelPoint, rx, ry)
    else
        ICON_UI.Place(f, "raidIcon", f.RaidIcon, markerSize - 2, markerSize - 2, "CENTER", f, "TOP", 0, -2)
    end

    if f.Happiness then
        local size = math.max(RAID_ICON, healthHeight * HAPPINESS_SHARE)
        ICON_UI.Place(f, "happiness", f.Happiness, size, size, "CENTER", f.Health, "CENTER", 0, 0)
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
    end

    LayoutAuras(f)
    LayoutIndicators(f)
end

--------------------------------------------------
-- 11. BLIZZARD EXTRAS THAT FOLLOW OUR FRAMES
-- PlayerBottomManagedFrameContainer (anchored to PlayerFrame) goes under our player frame.
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
-- Player and target mirror each other either side of the centre; target of target sits under the
-- target's cast bar; focus is pinned to the right edge. Each point anchors to the same point on
-- UIParent.
local DEFAULT_POSITIONS = {
    player        = { point = "CENTER", x = -330, y = -270 },
    target        = { point = "CENTER", x = 330,  y = -270 },
    targettarget  = { point = "BOTTOM", x = 260,  y = 252 },
    focus         = { point = "RIGHT",  x = -453, y = -257 },
    focustarget   = { point = "BOTTOM", x = 504,  y = 277 },
    pet           = { point = "BOTTOM", x = -270, y = 271 },   -- its right edge lines up with the player frame's
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
-- 14. CONDITIONAL VISIBILITY (fading)
-- Settings sets "player" (shared by the pet frame), "target", "focus". With no condition on a frame
-- sits at Max Alpha; otherwise at Min Alpha until a condition holds. Alpha works in combat.
--------------------------------------------------
local VIS_SET = { player = "player", pet = "player", target = "target", focus = "focus" }
local FADE_INTERVAL = 0.1

local function GetVisDb(set)
    local db = GetDb()
    return db and db.visibility and db.visibility[set]
end

local function HasConditions(cfg)
    return cfg.condMouseover or cfg.condCombat or cfg.condTarget or cfg.condHarm or cfg.condHealth
end

-- UnitCanAttack / UnitHealth can be secret; a bare truth test or comparison would throw
local function IsAttackable(unit)
    if not UnitExists(unit) then return false end
    local can = UnitCanAttack("player", unit)
    return canaccessvalue(can) and can and true or false
end

local function IsHealthMissing(unit)
    local hp, max = UnitHealth(unit), UnitHealthMax(unit)
    if not (canaccessvalue(hp) and canaccessvalue(max)) then return false end
    return hp < max
end

local function IsFrameMouseOver(f)
    return f and f:IsShown() and f:IsMouseOver()
end

local function ShouldShow(set, cfg)
    if LEM:IsInEditMode() then return true end
    if not HasConditions(cfg) then return true end
    if cfg.condCombat and InCombatLockdown() then return true end
    if set == "player" then
        if cfg.condMouseover and (IsFrameMouseOver(frames.player) or IsFrameMouseOver(frames.pet)) then return true end
        if cfg.condTarget and UnitExists("target") then return true end
        if cfg.condHarm and IsAttackable("target") then return true end
        if cfg.condHealth and IsHealthMissing("player") then return true end
    else
        if cfg.condHarm and IsAttackable(set) then return true end
    end
    return false
end

local fader = CreateFrame("Frame")
fader.elapsed = 0
fader.decided = {}   -- set -> shown, this tick

local function FadeTick(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed < FADE_INTERVAL then return end
    self.elapsed = 0

    local decided = self.decided
    wipe(decided)
    for unit, f in pairs(frames) do
        local set = VIS_SET[unit]
        local cfg = set and GetVisDb(set)
        if cfg then
            if decided[set] == nil then decided[set] = ShouldShow(set, cfg) end
            local target = decided[set] and (cfg.alphaMax or 1) or (cfg.alphaMin or 0)
            if math.abs(f:GetAlpha() - target) > 0.005 then f:SetAlpha(target) end
        end
    end
end

-- The ticker runs only while some set has a condition
local function RefreshVisibilityFader()
    local active = false
    for unit, f in pairs(frames) do
        local set = VIS_SET[unit]
        local cfg = set and GetVisDb(set)
        if cfg then
            if HasConditions(cfg) then
                active = true
            else
                f:SetAlpha(cfg.alphaMax or 1)
            end
        end
    end
    fader.elapsed = FADE_INTERVAL
    if active then
        fader:SetScript("OnUpdate", FadeTick)
        FadeTick(fader, 0)
    else
        fader:SetScript("OnUpdate", nil)
    end
end

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
-- LibSharedMedia names for the Edit Mode dropdowns; "" = the frame's own texture
local function BuildTextureValues(withFrameDefault)
    local values = {}
    if withFrameDefault then values[#values + 1] = { text = L["Frame Texture"], value = "", isRadio = true } end
    for _, name in ipairs(LSM:List("statusbar")) do
        values[#values + 1] = { text = name, value = name, isRadio = true }
    end
    return values
end

local function BuildBorderValues(withFrameDefault)
    local values = {}
    if withFrameDefault then values[#values + 1] = { text = L["Frame Border"], value = "", isRadio = true } end
    for _, name in ipairs(LSM:List("border")) do
        values[#values + 1] = { text = name, value = name, isRadio = true }
    end
    return values
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
    return {
        { name = L["Width"], kind = LEM.SettingType.Slider, default = 250, minValue = 100, maxValue = 600, valueStep = 2, get = get("width", 250), set = set("width") },
        { name = L["Height"], kind = LEM.SettingType.Slider, default = 25, minValue = 8, maxValue = 48, valueStep = 1, get = get("height", 25), set = set("height") },
    }
end

local function BuildSettings(unit)
    local info = UNITS[unit]
    local function get(key) return function() local u = GetUnitDb(unit); return u and u[key] end end
    local function set(key, refreshAll)
        return function(_, value)
            local u = GetUnitDb(unit)
            if not u then return end
            u[key] = value
            local f = frames[unit]
            if f then LayoutFrame(f); UpdateAll(f) end
        end
    end
    local defaults = ns.defaults and ns.defaults.profile.unitframes.units[unit] or {}

    local settings = {
        { name = L["Width"], kind = LEM.SettingType.Slider, default = defaults.width or 220, minValue = 60, maxValue = 500, valueStep = 2, get = get("width"), set = set("width") },
        { name = L["Height"], kind = LEM.SettingType.Slider, default = defaults.height or 44, minValue = 16, maxValue = 120, valueStep = 1, get = get("height"), set = set("height") },
        { name = L["Power Bar Height"], kind = LEM.SettingType.Slider, default = defaults.powerHeight or 8, minValue = 0, maxValue = 40, valueStep = 1, get = get("powerHeight"), set = set("powerHeight"),
          formatter = function(value) return value == 0 and _G.OFF or value end },
        { name = L["Health Text"], kind = LEM.SettingType.Dropdown, default = defaults.healthText or "percent", values = HEALTH_TEXT_MODES, get = get("healthText"), set = set("healthText") },
        { name = L["Power Text"], kind = LEM.SettingType.Checkbox, default = defaults.powerText or false, get = get("powerText"), set = set("powerText") },
        { name = L["Show Level"], kind = LEM.SettingType.Checkbox, default = defaults.showLevel ~= false, get = get("showLevel"), set = set("showLevel"),
          hidden = function() return info.portrait and ns.UFRing and ns.UFRing.On() or false end },
    }
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
    if info.portrait and ns.UFRing then
        settings[#settings + 1] = { name = L["Ring Size"], kind = LEM.SettingType.Slider, default = ns.UFRing.DefaultSize(unit),
            minValue = 36, maxValue = 120, valueStep = 1,
            get = function() local u = GetUnitDb(unit); return u and u.ringSize or ns.UFRing.DefaultSize(unit) end,
            set = set("ringSize"),
            hidden = function() return not ns.UFRing.On() end }
    end
    if info.mirrorable then
        -- flips text order and bar fill so the frame faces the player frame
        settings[#settings + 1] = { name = L["Mirror"], kind = LEM.SettingType.Checkbox, default = defaults.mirror or false, get = function() local u = GetUnitDb(unit); return u and u.mirror or false end,
            set = function(_, value) local u = GetUnitDb(unit); if not u then return end; u.mirror = value; local f = frames[unit]; if f then LayoutFrame(f); AttachExtras(f); UpdateAll(f) end end }
    end
    if info.comboPoints then
        settings[#settings + 1] = { name = L["Classic Combo Points"], kind = LEM.SettingType.Checkbox, default = false,
            get = function() local u = GetUnitDb(unit); return u and u.classicCombo or false end,
            set = function(_, value)
                local u = GetUnitDb(unit)
                if not u then return end
                u.classicCombo = value
                local f = frames[unit]
                if f then ApplyComboMode(f); UpdateAll(f) end
            end,
            desc = L["Classic combo point gems in the bottom-right corner of the health bar, instead of FlareUI's strip."],
            hidden = function() return ns.UFRing and ns.UFRing.On() or false end }
    end
    if unit == "player" then
        settings[#settings + 1] = { name = L["Five-Second Rule"], kind = LEM.SettingType.Checkbox, default = false,
            get = function() local u = GetUnitDb(unit); return u and u.fsr == true or false end,
            set = function(_, value) local u = GetUnitDb(unit); if not u then return end; u.fsr = value; UpdateFsrSpark() end,
            desc = L["A spark crosses the bar for five seconds after a spell that costs mana: spirit regen comes back when it ends."] }
    end
    -- collapsible sections; which are open is shared by every frame (unitframes.editSections)
    local function SectionOpen(name)
        local db = GetDb()
        return db and db.editSections and db.editSections[name] or false
    end
    local function Section(name, items)
        settings[#settings + 1] = { name = "|cffffd100" .. L[name] .. "|r", kind = LEM.SettingType.Expander, default = false,
            get = function() return SectionOpen(name) end,
            set = function(_, value)
                local db = GetDb()
                if not db then return end
                db.editSections = db.editSections or {}
                db.editSections[name] = value and true or nil
            end }
        for _, item in ipairs(items) do
            local own = item.hidden
            item.hidden = function(...)
                if not SectionOpen(name) then return true end
                if type(own) == "function" then return own(...) end
                return own
            end
            settings[#settings + 1] = item
        end
    end

    -- the player frame: always shown, or faded out of combat (back in combat, with a target,
    -- missing health, or under the mouse)
    if unit == "player" then
        settings[#settings + 1] = { name = L["Show"], kind = LEM.SettingType.Dropdown, default = "always",
            values = { { text = L["Always"], value = "always", isRadio = true },
                       { text = L["Fade Out of Combat"], value = "fade", isRadio = true } },
            get = function() return UF:GetPlayerShow() end,
            set = function(_, value) UF:SetPlayerShow(value) end }
    end

    -- everything above is the frame itself, and gets the first section
    local frameItems = settings
    settings = {}
    Section("Frame", frameItems)

    if info.castbar then
        Section("Cast Bar", {
            { name = L["Cast Bar Position"], kind = LEM.SettingType.Dropdown, default = defaults.castbarPosition or "BOTTOM",
              values = { { text = L["Above"], value = "TOP", isRadio = true }, { text = L["Below"], value = "BOTTOM", isRadio = true } },
              get = get("castbarPosition"), set = set("castbarPosition") },
        })
    end
    if info.auras then
        local positions = {
            { text = L["Off"],          value = "OFF" },
            { text = L["Top Left"],     value = "TOPLEFT" },
            { text = L["Top Right"],    value = "TOPRIGHT" },
            { text = L["Bottom Left"],  value = "BOTTOMLEFT" },
            { text = L["Bottom Right"], value = "BOTTOMRIGHT" },
        }
        -- buffs and debuffs never share a corner: the other kind's corner is greyed out
        local function Corner(field, other)
            return function(_, rootDescription, data)
                for _, p in ipairs(positions) do
                    local radio = rootDescription:CreateRadio(p.text,
                        function(value) return (get(field)() or "OFF") == value end,
                        function(value) data.set(nil, value) end, p.value)
                    if p.value ~= "OFF" and get(other)() == p.value and radio.SetEnabled then radio:SetEnabled(false) end
                end
            end
        end
        Section("Auras", {
            { name = L["Buffs"], kind = LEM.SettingType.Dropdown, default = defaults.buffs or "OFF", values = positions,
              generator = Corner("buffs", "debuffs"), get = get("buffs"), set = set("buffs") },
            { name = L["Debuffs"], kind = LEM.SettingType.Dropdown, default = defaults.debuffs or "OFF", values = positions,
              generator = Corner("debuffs", "buffs"), get = get("debuffs"), set = set("debuffs") },
            { name = L["Aura Size"], kind = LEM.SettingType.Slider, default = defaults.auraSize or 22, minValue = 12, maxValue = 48, valueStep = 1, get = get("auraSize"), set = set("auraSize") },
            { name = L["Only My Debuffs"], kind = LEM.SettingType.Checkbox, default = defaults.onlyMyDebuffs or false, get = get("onlyMyDebuffs"), set = set("onlyMyDebuffs") },
        })
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
-- Building blocks the party frames (PartyFrames.lua) share with these frames
UF.Kit = {
    INSET = INSET, BORDER_SIZE = BORDER_SIZE, BG_OPACITY = BG_OPACITY, BACKDROP_FILE = BACKDROP_FILE,
    SEPARATOR_TEXTURE = SEPARATOR_TEXTURE, SEPARATOR_HEIGHT = SEPARATOR_HEIGHT, TEXT_INSET = TEXT_INSET,
    CAST_GAP = CAST_GAP, CAST_ICON_GAP = CAST_ICON_GAP, AURA_GAP = AURA_GAP,
    DEFAULT_TEXTURE = DEFAULT_TEXTURE, DEFAULT_BORDER = DEFAULT_BORDER,
    HEAL_COLOR = HEAL_COLOR, ABSORB_COLOR = ABSORB_COLOR, HEAL_TEXTURE = HEAL_TEXTURE, ABSORB_TEXTURE = ABSORB_TEXTURE,
    HEALTH_TEXT_MODES = HEALTH_TEXT_MODES, CAST_EVENTS = CAST_EVENTS, UNIT_EVENTS = UNIT_EVENTS,
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
    BuildTextureValues = BuildTextureValues, BuildBorderValues = BuildBorderValues,
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
    -- the party frames share the fonts and textures set here
    if ns.PartyFrames and ns.PartyFrames.initialized then guard("party frames", function() ns.PartyFrames:Refresh() end) end
    if ns.ResourceBars and ns.ResourceBars.initialized then guard("resource bars", function() ns.ResourceBars:Refresh() end) end
    if playerCastHolder then
        guard("player cast bar", function()
            LayoutPlayerCastBar()
            ApplyPosition(playerCastHolder)
            UpdateCastBar(playerCastHolder.Cast, IsCastEnabled(playerCastHolder.Cast))
        end)
    end
end

-- Class colours: one switch for every frame (Settings > Unit Frames)
function UF:ClassColorsOn()
    return ns.ClassColorsOn()
end

-- The player frame's Show choice: "always", or "fade" (out of combat; back in combat, with a
-- target, with health missing, or under the mouse)
UF.PLAYER_FADE = { condMouseover = true, condCombat = true, condTarget = true, condHealth = true, condHarm = false }
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
    -- the Forever style has its own default positions (a style switch reloads)
    if ns.UFRing and ns.UFRing.On() then
        for key, pos in pairs(ns.UFRing.POSITIONS) do DEFAULT_POSITIONS[key] = pos end
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
        HardHide("PlayerCastingBarFrame")
        -- the Gamepad UI has a cast bar of its own, big and mid-screen
        if _G.GamepadPlayerCastingBarFrame then HardHide("GamepadPlayerCastingBarFrame") end
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
