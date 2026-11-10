local _, ns = ...

--------------------------------------------------
-- MOUSE RING (Quality of Life > Gameplay > Cursor > Mouse Ring: Off, Always, In Combat, While Right-Clicking)
-- A ring with a dot round the cursor, so it is easy to find: always, only in a fight, or only while
-- the right mouse button is held (where the cursor was as you turn the camera). After EnhanceQoL's
-- mouse ring (all rights reserved: the idea only), in FlareUI's bronze or your class colour.
-- Every ring is a white disc (the CircleMaskScalable art) cut by Media/Masks/RingHole.tga
-- sized for its hole, so Size is the diameter and Thickness stays the same at any size. Each extra is
-- off by default; an arc is two copies of its ring clipped by rotated half-plane masks (the radial
-- menu's slice glow), the second only past half way:
--   Cast Ring        over the ring: fills as you cast, runs back as you channel
--   GCD Ring         inside the ring, a small gap away: the global cooldown running down; hidden
--                    while the cast ring runs (and while the game keeps its timing secret)
--   Swing Ring       outside the ring: your next main-hand or ranged auto attack (C_SwingTimer)
--   Out-of-Range     the ring turns red while the target is past your auto attack (wand or bow for
--                    hunters, mages, priests and warlocks; melee for the rest)
--   Hide While Turning   no ring while the mouse turns the camera (not with While Right-Clicking)
--------------------------------------------------
local MR = {}
ns.MouseRing = MR
ns.modules["MouseRing"] = MR

local CreateFrame, GetCursorPosition, IsMouseButtonDown = CreateFrame, GetCursorPosition, IsMouseButtonDown
local InCombatLockdown, UnitAffectingCombat, GetTime = InCombatLockdown, UnitAffectingCombat, GetTime
local math_rad, math_min, math_max = math.rad, math.min, math.max

local HOLE = "Interface\\AddOns\\FlareUI\\Media\\Masks\\RingHole.tga"
local HOLE_SHARE = 0.93               -- the hole's diameter, of RingHole.tga's width
local HALF = "Interface\\AddOns\\FlareUI\\Media\\Radial\\HalfMask.tga"   -- shows x > 0 unrotated
local DOT = "Interface\\AddOns\\FlareUI\\Media\\Radial\\Dot.tga"
local BRONZE = { 0.92, 0.76, 0.52 }   -- the radial's rim tint: the neutral silver warmed to bronze
local OUT_OF_RANGE = { 1, 0.25, 0.25 }
local DOT_SHARE = 0.12                -- the dot's size, of the ring's
local GAP = 2                         -- between the ring and the GCD or swing ring
local COLORS = { cast = { 1, 0.85, 0.3 }, gcd = { 0.92, 0.76, 0.52 }, swing = { 0.85, 0.85, 0.85 } }
local GCD_SPELL = 61304
local RANGE_POLL = 0.25
-- auto attacks from a wand or bow: these classes' range check follows the ranged slot
local RANGED_CLASSES = { HUNTER = true, MAGE = true, PRIEST = true, WARLOCK = true }

local function GetDb()
    return ns.db and ns.db.profile and ns.db.profile.tweaks
end

local frame, base, dot, driver
local arcs = {}
local fighting, outOfRange = false, false
local cast, gcd, swing = {}, {}, {}   -- start, duration (seconds); cast.channel
local rangeWait = 0

-- one choice turns it on and says when it shows; the first builds' separate switch carries over
local function On()
    local db = GetDb()
    if not db then return false end
    if db.mouseRing ~= nil then
        if db.mouseRing == true and rawget(db, "mouseRingShow") == nil then db.mouseRingShow = "always" end
        db.mouseRing = nil
    end
    return db.enabled ~= false and (db.mouseRingShow or "off") ~= "off"
end

local function Readable(...)
    for i = 1, select("#", ...) do
        if not canaccessvalue(select(i, ...)) then return false end
    end
    return true
end

--------------------------------------------------
-- 1. RINGS
--------------------------------------------------
-- a ring's hole, for its textures to share. The outside is the texture's own: a white disc (the
-- circle mask's art drawn as a texture), since a texture takes at most three masks and an arc's
-- halves need the hole and two half-planes.
local function Shape()
    local hole = frame:CreateMaskTexture()
    hole:SetTexture(HOLE, "CLAMPTOWHITE", "CLAMPTOWHITE")
    hole:SetPoint("CENTER")
    return { hole = hole }
end

local function SizeShape(shape, diameter, thickness)
    local inner = math_max(1, diameter - 2 * thickness) / HOLE_SHARE
    shape.hole:SetSize(inner, inner)
    shape.diameter = diameter
end

local function RingTexture(shape, layer, sub)
    local t = frame:CreateTexture(nil, layer, nil, sub)
    if not t:SetAtlas("CircleMaskScalable", TextureKitConstants and TextureKitConstants.IgnoreAtlasSize) then
        t:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")   -- the classic white circle
    end
    t:SetPoint("CENTER")
    t:AddMaskTexture(shape.hole)
    return t
end

-- an arc: two halves, each a ring cut to a wedge by two half-plane masks
local function Arc(key, sub)
    local arc = arcs[key]
    if arc then return arc end
    arc = { shape = Shape(), halves = {} }
    for i = 1, 2 do
        local t = RingTexture(arc.shape, "OVERLAY", sub)
        local from, to = frame:CreateMaskTexture(), frame:CreateMaskTexture()
        for _, m in ipairs({ from, to }) do
            m:SetTexture(HALF, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            m:SetAllPoints(t)
            t:AddMaskTexture(m)
        end
        t:Hide()
        arc.halves[i] = { tex = t, from = from, to = to }
    end
    local c = COLORS[key]
    for _, h in ipairs(arc.halves) do h.tex:SetVertexColor(c[1], c[2], c[3]) end
    arcs[key] = arc
    return arc
end

-- the wedge between two angles (degrees, counter-clockwise, at most 180 apart)
local function Wedge(half, low, high)
    half.from:SetRotation(math_rad(low + 90))    -- keeps low .. low + 180
    half.to:SetRotation(math_rad(high - 90))     -- keeps high - 180 .. high
    half.tex:Show()
end

-- progress 0..1, clockwise from the top
local function SetArc(arc, progress)
    if not arc then return end
    local h1, h2 = arc.halves[1], arc.halves[2]
    if not progress or progress <= 0 then
        h1.tex:Hide()
        h2.tex:Hide()
        return
    end
    progress = math_min(progress, 1)
    Wedge(h1, 90 - math_min(progress, 0.5) * 360, 90)
    if progress > 0.5 then Wedge(h2, 90 - progress * 360, -90) else h2.tex:Hide() end
end

local function SizeArc(arc, diameter, thickness)
    SizeShape(arc.shape, diameter, thickness)
    for _, h in ipairs(arc.halves) do h.tex:SetSize(diameter, diameter) end
end

--------------------------------------------------
-- 2. TIMERS
--------------------------------------------------
local function Wants(key)
    local db = GetDb()
    if not db then return false end
    if key == "cast" then return db.mouseRingCast end
    if key == "gcd" then return db.mouseRingGCD end
    if key == "swing" then return db.mouseRingSwing end
end

local function ReadCast()
    cast.start = nil
    if not Wants("cast") then return end
    local _, _, _, startMs, endMs = UnitCastingInfo("player")
    local channel = false
    if not startMs then
        _, _, _, startMs, endMs = UnitChannelInfo("player")
        channel = true
    end
    if startMs and endMs and Readable(startMs, endMs) and endMs > startMs then
        cast.start, cast.duration, cast.channel = startMs / 1000, (endMs - startMs) / 1000, channel
    end
end

-- the global cooldown, while the game lets addons read it
local function ReadGCD()
    gcd.start = nil
    if not Wants("gcd") then return end
    local ok, info = pcall(C_Spell.GetSpellCooldown, GCD_SPELL)
    if not (ok and info) or not Readable(info.startTime, info.duration) then return end
    if info.duration and info.duration > 0 then gcd.start, gcd.duration = info.startTime, info.duration end
end

local function OnSwing(duration, swingType)
    if not Wants("swing") or swingType == Enum.PlayerSwingType.OffHand or not Readable(duration) then return end
    swing.start, swing.duration = GetTime(), duration
end

local function Progress(t, now)
    if not (t.start and t.duration and t.duration > 0) then return nil end
    local p = (now - t.start) / t.duration
    if p < 0 or p >= 1 then t.start = nil return nil end
    return p
end

local function UpdateArcs()
    local now = GetTime()
    local p = Progress(cast, now)
    if p and cast.channel then p = 1 - p end
    SetArc(arcs.cast, p)
    local g = (not p) and Progress(gcd, now)
    SetArc(arcs.gcd, g and 1 - g)          -- what is left of it
    SetArc(arcs.swing, Progress(swing, now))
end

--------------------------------------------------
-- 3. OUT OF RANGE (the auto attack's range check)
--------------------------------------------------
local function RangeType()
    local _, class = UnitClass("player")
    return RANGED_CLASSES[class] and Enum.PlayerSwingType.Ranged or Enum.PlayerSwingType.MainHand
end

local function BaseColor()
    local db = GetDb()
    local r, g, b = BRONZE[1], BRONZE[2], BRONZE[3]
    if db.mouseRingClassColor then
        local _, class = UnitClass("player")
        local c = class and C_ClassColor and C_ClassColor.GetClassColor(class)
        if c then r, g, b = c.r, c.g, c.b end
    end
    if db.mouseRingRange and outOfRange then r, g, b = OUT_OF_RANGE[1], OUT_OF_RANGE[2], OUT_OF_RANGE[3] end
    base:SetVertexColor(r, g, b)
    dot:SetVertexColor(r, g, b)
end

-- Blizzard's own (hidden) swing timers can turn the shared range check off, as the resource bars
-- found: it is turned on again with each target
local function EnableRange()
    if C_SwingTimer and C_SwingTimer.EnableRangeCheck then pcall(C_SwingTimer.EnableRangeCheck, RangeType(), true) end
end

-- only an enemy or neutral target you can attack; no answer never counts as out of range
-- (ns.TargetInRange in Core.lua: the spell book's answer, as Forever's swing check gives none)
local function CheckRange()
    local _, class = UnitClass("player")
    local out = ns.TargetInRange(RANGED_CLASSES[class] or false) == false
    if out ~= outOfRange then
        outOfRange = out
        BaseColor()
    end
end

--------------------------------------------------
-- 4. FOLLOWING THE CURSOR
--------------------------------------------------
local function Wanted(db)
    local show = db.mouseRingShow or "always"
    if show == "combat" then return fighting end
    if show == "rightclick" then return IsMouseButtonDown("RightButton") and true or false end
    if db.mouseRingHideTurning and IsMouselooking and IsMouselooking() then return false end
    return true
end

local function OnUpdate(_, elapsed)
    local db = GetDb()
    if not db then return end
    if db.mouseRingRange then
        rangeWait = rangeWait - elapsed
        if rangeWait <= 0 then
            rangeWait = RANGE_POLL
            CheckRange()
        end
    end
    if Wanted(db) then
        if not frame:IsShown() then frame:Show() end
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
        UpdateArcs()
    elseif frame:IsShown() then
        frame:Hide()
    end
end

--------------------------------------------------
-- 5. LOOK, EVENTS, SETUP
--------------------------------------------------
local function Style()
    local db = GetDb()
    local size = db.mouseRingSize or 40
    local thick = db.mouseRingThickness or 3
    frame:SetSize(size, size)
    SizeShape(frame.shape, size, thick)
    base:SetSize(size, size)
    dot:SetSize(math_max(4, size * DOT_SHARE), math_max(4, size * DOT_SHARE))
    -- the cast arc lies over the ring; the GCD sits inside it and the swing outside, a gap away
    local diameters = { cast = size, gcd = size - 2 * (thick + GAP), swing = size + 2 * (thick + GAP) }
    for key, sub in pairs({ gcd = 1, cast = 2, swing = 1 }) do
        if Wants(key) then
            SizeArc(Arc(key, sub), math_max(thick * 2 + 2, diameters[key]), thick)
        elseif arcs[key] then
            SetArc(arcs[key], nil)
        end
    end
    BaseColor()
end

local function OnEvent(_, event, ...)
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        fighting = event == "PLAYER_REGEN_DISABLED"
    elseif event == "SPELL_UPDATE_COOLDOWN" or event == "ACTIONBAR_UPDATE_COOLDOWN" then
        ReadGCD()
    elseif event == "PLAYER_SWING" then
        OnSwing(...)
    elseif event == "PLAYER_SWING_RANGE_UPDATE" then
        local swingType, inRange, checksRange = ...
        if swingType == RangeType() and Readable(inRange, checksRange) then
            local out = checksRange and not inRange or false
            if out ~= outOfRange then
                outOfRange = out
                BaseColor()
            end
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        EnableRange()
        CheckRange()
    else
        ReadCast()   -- UNIT_SPELLCAST_*
    end
end

local CAST_EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
                      "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE",
                      "UNIT_SPELLCAST_CHANNEL_STOP" }

local function RegisterEvents(db)
    driver:UnregisterAllEvents()
    driver:RegisterEvent("PLAYER_REGEN_DISABLED")
    driver:RegisterEvent("PLAYER_REGEN_ENABLED")
    if db.mouseRingCast then
        for _, event in ipairs(CAST_EVENTS) do pcall(driver.RegisterUnitEvent, driver, event, "player") end
    end
    if db.mouseRingGCD then
        driver:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        pcall(driver.RegisterEvent, driver, "ACTIONBAR_UPDATE_COOLDOWN")
    end
    if db.mouseRingSwing then pcall(driver.RegisterEvent, driver, "PLAYER_SWING") end
    if db.mouseRingRange then
        -- turned on only: the resource bars' swing timer may use the same check
        EnableRange()
        pcall(driver.RegisterEvent, driver, "PLAYER_SWING_RANGE_UPDATE")
        driver:RegisterEvent("PLAYER_TARGET_CHANGED")
    end
end

-- Live from the options
function MR:Refresh()
    if not On() then
        if driver then
            driver:SetScript("OnUpdate", nil)
            driver:UnregisterAllEvents()
        end
        if frame then frame:Hide() end
        return
    end
    if not frame then
        frame = CreateFrame("Frame", "FlareUI_MouseRing", UIParent)
        frame:SetFrameStrata("TOOLTIP")
        frame:EnableMouse(false)
        frame:Hide()
        frame.shape = Shape()
        base = RingTexture(frame.shape, "ARTWORK", 0)
        dot = frame:CreateTexture(nil, "OVERLAY", nil, 3)
        dot:SetTexture(DOT)
        dot:SetPoint("CENTER")
        driver = CreateFrame("Frame")
        driver:SetScript("OnEvent", OnEvent)
    end
    local db = GetDb()
    fighting = InCombatLockdown() or UnitAffectingCombat("player") or false
    outOfRange = false
    RegisterEvents(db)
    Style()
    ReadCast()
    ReadGCD()
    if db.mouseRingRange then CheckRange() end
    driver:SetScript("OnUpdate", OnUpdate)
end

function MR:ShouldLoad() return true end

function MR:Init()
    self:Refresh()
end
