local _, ns = ...
local L = ns.L

--------------------------------------------------
-- XP ON FRAME (Unit Frames > XP on Frame, off)
-- Your experience on FlareUI's own player frame, so the XP bar can go: an arc round the level disc
-- or round the portrait ring, or the level disc filling up. Under the XP sit the rested bonus and, if
-- asked, what the quests ready to hand in would give. At max level the watched reputation takes its
-- place; a hunter's pet gets the same on its frame.
-- A frame style without the place picked uses the next one it has: the level disc (its ring or its
-- fill), the portrait ring, and last a thin line along the top of the health bar (the only one without
-- a ring). The frame's tooltip gets the numbers behind it all.
-- Idea after XP Portrait by trevware (no licence: ideas only, the ring art is FlareUI's own).
-- Everything here is an unprotected child of the frame: nothing of the frame itself is moved, and
-- UnitFrames.lua / UnitFramesRing.lua are followed through hooks on the ring's layout.
-- Hide XP Bars (the same section) hides FlareUI's XP bar or Blizzard's two, with this off as well.
--------------------------------------------------
local XP = {}
ns.UFXP = XP
ns.modules["UFXP"] = XP

local ipairs, pairs, type, tostring = ipairs, pairs, type, tostring
local math_floor, math_max, math_min = math.floor, math.max, math.min
local CreateFrame, GetTime = CreateFrame, GetTime

local C = {
    -- the arcs' art: a white band out to radius 122 of 128, from RING_INNER[thickness] (Ring Thickness)
    RING_FILE = "Interface\\AddOns\\FlareUI\\Media\\Frames\\XPRing",
    -- (each has a Back: the same band 4 wider on both sides, the dark groove it lies in)
    RING_INNER = { thin = 110, medium = 105, thick = 98 },
    RING_NAME = { thin = "Thin", medium = "Medium", thick = "Thick" },
    -- (and a Shaded: the band lit along its middle and dark at its edges, Ring Texture > Shaded)
    WHITE = "Interface\\Buttons\\WHITE8x8",
    CIRCLE_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
    -- where the band's inner edge stands: on the bronze rim's outer edge (of the ring's diameter), and
    -- on the level disc's own edge (of its frame's width: the disc is drawn at three quarters of it)
    PORTRAIT_EDGE = 0.52,
    LEVEL_EDGE = 0.42,          -- (the disc's art reaches 0.405 of its frame: a hair of groove between)
    -- the level ring tucks under the portrait's ring: without the frames' places, the portrait is
    -- taken to stand this way from the disc (degrees clockwise from the top) and to cover this much
    COVER = { LEFT = 45, RIGHT = 315, half = 60 },
    DISC_SHARE = 0.70,          -- the fill inside the level disc, of its width
    LINE_HEIGHT = 3,
    TRACK = { 0.06, 0.05, 0.04, 0.85 },
    -- the layers, as the FlareUI XP bar paints them (XPBar.lua FillSection): the rested bonus reaching
    -- past the quest XP, the quests in progress, the quests ready, and the XP itself over them all
    ALPHA = { 0.55, 0.25, 0.55, 1 },
    FLASH = { 1, 0.85, 0.3 },
    PET = { 0.35, 0.80, 0.45 },
    EASE = 0.45, SWEEP = 0.35, FLASH_TIME = 0.6,
    FULL = 0.9999,              -- a finished cooldown draws nothing: an arc is never quite whole
    DURATION = 1000,
}
local LAYERS = { "rested", "questOpen", "quest", "xp" }
local FALLBACK = { xp = { 0.58, 0, 0.55 }, rested = { 0, 0.39, 0.88 }, restBonus = { 0.4, 0.8, 1 }, quest = { 1, 0.76, 0.1 } }
-- each reaction's colour key in the XP bar's colours
local STANDING = { "repHostile", "repHostile", "repUnfriendly", "repNeutral", "repFriendly", "repFriendly", "repFriendly", "repFriendly" }

local binds = {
    player = { unit = "player", name = "FlareUI_UF_Player", views = {} },
    pet = { unit = "pet", name = "FlareUI_UF_Pet", views = {} },
}
local driver

local function Db()
    local uf = ns.db and ns.db.profile and ns.db.profile.unitframes
    return uf and uf.xp
end

local function Readable(value)
    return not canaccessvalue or canaccessvalue(value)
end

local function Color(key)
    if key == "pet" then return C.PET end
    local XPB = ns.XPBar
    return (XPB and XPB.Color and XPB.Color(key)) or FALLBACK[key] or FALLBACK.xp
end

local function Animated()
    local db = Db()
    if not db or db.animate == false then return false end
    if C_CVar and C_CVar.GetCVarBool and C_CVar.GetCVarBool("reduceMotion") then return false end
    return true
end

--------------------------------------------------
-- 1. WHAT THERE IS TO SHOW
--------------------------------------------------
-- The quest log's XP: what the quests ready to hand in would give (with each one, biggest first, for
-- the tooltip) and what the ones in progress would. Read again after the quest log changes.
local quest = { stale = true, total = 0, count = 0, open = 0, list = {} }
local function QuestXP()
    if not quest.stale then return quest end
    quest.stale = false
    local total, count, open, list = 0, 0, 0, {}
    local zoneTotal, zoneOpen = 0, 0   -- (the quests of the zone you are in: Quest XP > This Zone)
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo and GetQuestLogRewardXP then
        for i = 1, C_QuestLog.GetNumQuestLogEntries() do
            local info = C_QuestLog.GetInfo(i)
            local id = info and not info.isHeader and info.questID
            if id and id > 0 then
                local xp = GetQuestLogRewardXP(id) or 0
                if xp > 0 then
                    local here = C_QuestLog.IsOnMap and C_QuestLog.IsOnMap(id) and xp or 0
                    if (C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(id)) or (C_QuestLog.IsComplete and C_QuestLog.IsComplete(id)) then
                        total, count, zoneTotal = total + xp, count + 1, zoneTotal + here
                        list[#list + 1] = { info.title or "?", xp }
                    else
                        open, zoneOpen = open + xp, zoneOpen + here
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b) return a[2] > b[2] end)
    quest.total, quest.count, quest.open, quest.list = total, count, open, list
    quest.zoneTotal, quest.zoneOpen = zoneTotal, zoneOpen
    return quest
end

local function Share(value, maxValue)
    return math_max(0, math_min(1, value / maxValue))
end

-- The player's XP as shares of the level: { kind, value, max, xp, rested, quest, color, ... }.
-- nil when there is nothing to show.
function XP.State()
    local db = Db()
    if not db then return nil end
    local maxed = (IsPlayerAtEffectiveMaxLevel and IsPlayerAtEffectiveMaxLevel())
        or (IsXPUserDisabled and IsXPUserDisabled()) or false
    if not maxed then
        local value, maxValue = UnitXP("player"), UnitXPMax("player")
        if not (type(value) == "number" and type(maxValue) == "number" and maxValue > 0) then return nil end
        local rested = db.rested ~= false and GetXPExhaustion and GetXPExhaustion() or 0
        -- Quest XP, as the XP bar's: Ready to Hand In, All Quests (those in progress too, fainter) or This
        -- Zone. (The layers are Quest XP's; the tooltip tells the quests' XP either way.)
        local log = QuestXP()
        local mode = db.quest == true and "done" or db.quest
        local questXP, openXP = 0, 0
        if mode == "done" then questXP = log.total
        elseif mode == "all" then questXP, openXP = log.total, log.open
        elseif mode == "zone" then questXP, openXP = log.zoneTotal or 0, log.zoneOpen or 0 end
        return {
            kind = "xp", value = value, max = maxValue, xp = Share(value, maxValue),
            -- (rested reaches past the quest XP, or the quest layers would hide it)
            rested = rested > 0 and Share(value + questXP + openXP + rested, maxValue) or 0, restedXP = rested,
            quest = questXP > 0 and Share(value + questXP, maxValue) or 0,
            open = openXP > 0 and Share(value + questXP + openXP, maxValue) or 0, level = UnitLevel("player"),
            questReady = log.total, questCount = log.count, questOpen = log.open, questList = log.list,
            color = rested > 0 and "rested" or "xp",
        }
    end
    if db.repAtMax == false then return nil end
    local data = C_Reputation and C_Reputation.GetWatchedFactionData and C_Reputation.GetWatchedFactionData()
    if not (type(data) == "table" and data.name and data.name ~= "") then return nil end
    local low, high, standing = data.currentReactionThreshold or 0, data.nextReactionThreshold or 0, data.currentStanding or 0
    local span = high - low
    return {
        kind = "rep", name = data.name, reaction = data.reaction,
        value = standing - low, max = span, xp = span > 0 and Share(standing - low, span) or 1,
        rested = 0, quest = 0, open = 0, color = STANDING[data.reaction or 4] or "repNeutral",
    }
end

-- A hunter's pet (the only pets with experience)
function XP.PetState()
    local db = Db()
    if not db or db.pet == false or not GetPetExperience then return nil end
    local exists = UnitExists("pet")
    if not (Readable(exists) and exists) then return nil end
    local value, maxValue = GetPetExperience()
    if not (type(value) == "number" and type(maxValue) == "number" and maxValue > 0) then return nil end
    return { kind = "pet", value = value, max = maxValue, xp = Share(value, maxValue), rested = 0, quest = 0, open = 0, color = "pet" }
end

-- XP per hour this session: what was gained between readings, over the time since the first
local rate = {}
local function TrackRate()
    local value, maxValue, level = UnitXP("player"), UnitXPMax("player"), UnitLevel("player")
    if not (type(value) == "number" and type(maxValue) == "number" and type(level) == "number") then return end
    if not rate.start then
        rate.start, rate.total = GetTime(), 0
    elseif level > (rate.level or level) then
        rate.total = rate.total + math_max(0, (rate.max or 0) - (rate.value or 0)) + value
    elseif level == rate.level and value > (rate.value or value) then
        rate.total = rate.total + value - rate.value
    end
    rate.value, rate.max, rate.level = value, maxValue, level
end
local function PerHour()
    local elapsed = rate.start and GetTime() - rate.start or 0
    if elapsed < 60 or not rate.total or rate.total <= 0 then return nil end
    return rate.total * 3600 / elapsed
end

--------------------------------------------------
-- 2. THE FOUR LOOKS
-- Each is a view: view.holder, view:Set(layer, share), view:Tint(layer, color), view:Flash(),
-- view:Place(f). Layers: 1 rested, 2 quest, 3 XP.
--------------------------------------------------
local function NewFlash(texture)
    texture:SetBlendMode("ADD")
    texture:SetVertexColor(C.FLASH[1], C.FLASH[2], C.FLASH[3])
    texture:SetAlpha(0)
    local group = texture:CreateAnimationGroup()
    local fade = group:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetDuration(C.FLASH_TIME)
    return group
end

-- the arc: a paused cooldown whose swipe is the ring, so the game cuts the angle
local function SetArc(arc, share)
    if share <= 0 then arc:Hide() return end
    arc:Show()
    arc:SetCooldown(GetTime() - math_min(share, C.FULL) * C.DURATION, C.DURATION)
    if arc.Pause then arc:Pause() end
end

-- The part of the level ring in sight: the portrait's ring covers the rest. The arc can only start
-- at the top, so its start is put where the ring comes out from under the portrait, and the XP is
-- spread over what shows from there: (start, span) as shares of the whole circle. radius: the band's
-- middle. With the top of the ring in sight (no such layout today) the whole circle is used.
function XP.SightArc(f, radius)
    local ring = f.RingFrame
    local side = ns.UFRing and ns.UFRing.Side and ns.UFRing.Side(f) or "LEFT"
    local toward, half = C.COVER[side] or C.COVER.LEFT, C.COVER.half
    local x1, y1 = ring.Disc:GetCenter()
    local x2, y2 = ring.Centre:GetCenter()
    if x1 and x2 and Readable(x1) and Readable(x2) and Readable(y1) and Readable(y2) then
        local dx, dy = x2 - x1, y2 - y1
        local distance = math.sqrt(dx * dx + dy * dy)
        local cover = ring.Centre:GetWidth() * C.PORTRAIT_EDGE
        if distance > 0 and radius > 0 then
            toward = math.deg((math.atan2 or math.atan)(dx, dy)) % 360
            -- (two circles: the angle, seen from the disc, at which the band meets the portrait ring's edge)
            local cos = (distance * distance + radius * radius - cover * cover) / (2 * distance * radius)
            half = math.deg(math.acos(math_max(-1, math_min(1, cos))))
        end
    end
    local fromTop = math_min(toward, 360 - toward)
    if half <= 0 or fromTop > half then return 0, 1 end
    return ((toward + half) % 360) / 360, (360 - 2 * half) / 360
end

-- kind "ring": round the portrait, under it and the bronze ring. kind "levelRing": round the level
-- disc, under the portrait too, which hides the part of it on its side (XP.SightArc).
local function RingView(f, kind)
    local view = { kind = kind, arcs = {} }
    local small = kind == "levelRing"
    local file
    local holder = CreateFrame("Frame", nil, f)
    view.holder = holder
    local track = holder:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetVertexColor(C.TRACK[1], C.TRACK[2], C.TRACK[3], C.TRACK[4])
    for i = 1, #LAYERS do
        local arc = CreateFrame("Cooldown", nil, holder)
        arc:SetAllPoints()
        arc:SetDrawEdge(false)
        arc:SetDrawBling(false)
        arc:SetHideCountdownNumbers(true)
        arc:SetReverse(true)
        if arc.SetUseCircularEdge then arc:SetUseCircularEdge(true) end
        arc.noCooldownCount = true   -- (cooldown-count addons leave it alone)
        arc:Hide()
        view.arcs[i] = arc
    end
    local flashFrame = CreateFrame("Frame", nil, holder)
    flashFrame:SetAllPoints()
    local flash = flashFrame:CreateTexture(nil, "OVERLAY")
    flash:SetAllPoints()
    view.flashFrame, view.flash = flashFrame, NewFlash(flash)
    -- Ring Thickness: the band's art; its inner edge stays where it is, so a thicker one grows outward
    local function Thickness()
        local db = Db()
        local pick = db and db.thickness
        return C.RING_INNER[pick] and pick or "medium"
    end
    local function SetArt(pick)
        local db = Db()
        local shaded = not (db and db.texture == "flat")
        local key = pick .. (shaded and "+" or "")
        if file == key then return end
        file = key
        local path = C.RING_FILE .. C.RING_NAME[pick]
        track:SetTexture(path .. "Back")
        flash:SetTexture(path)
        for _, arc in ipairs(view.arcs) do arc:SetSwipeTexture(path .. (shaded and "Shaded" or "")) end
    end

    -- (the level ring: a share of the arc in sight, begun where it comes out from under the portrait)
    function view:Set(layer, share)
        if share > 0 and self.span then share = self.start + math_min(1, share) * self.span end
        SetArc(self.arcs[layer], share)
    end
    function view:Tint(layer, color)
        self.arcs[layer]:SetSwipeColor(color[1], color[2], color[3], C.ALPHA[layer])
    end
    function view:Flash() self.flash:Stop(); self.flash:Play() end
    function view:Place(frame)
        local ring = frame.RingFrame
        local level = frame:GetFrameLevel()
        local pick = Thickness()
        SetArt(pick)
        -- the file across, so that its band's inner edge lands on the edge it goes round
        local perEdge = 256 / C.RING_INNER[pick]
        local target, size, base, step = ring.Centre, ring.Centre:GetWidth() * C.PORTRAIT_EDGE * perEdge, level + 5, { 1, 1, 2, 3 }
        if small then
            -- under the portrait and its ring as well: they cover the part of it on their side, the disc
            -- lies over its middle
            target, size = ring.Disc, ring.Disc:GetWidth() * C.LEVEL_EDGE * perEdge
        end
        holder:SetFrameLevel(base)
        for i, arc in ipairs(self.arcs) do arc:SetFrameLevel(base + step[i]) end
        self.flashFrame:SetFrameLevel(base + step[#step])
        holder:ClearAllPoints()
        holder:SetSize(size, size)
        holder:SetPoint("CENTER", target, "CENTER")
        if small then
            self.start, self.span = XP.SightArc(frame, size / 2 * (C.RING_INNER[pick] + 122) / 256)
        end
    end
    return view
end

-- The disc's fill is drawn by the disc itself (its own textures, between its art and the level's
-- number): a frame of its own at the disc's level could land over the number.
local function DiscView(f)
    local view = { kind = "disc", fills = {}, on = false }
    local disc = f.RingFrame.Disc
    local area = disc:CreateTexture(nil, "ARTWORK", nil, 1)   -- never drawn: the fill's square
    area:SetPoint("CENTER", disc, "CENTER")
    area:SetColorTexture(0, 0, 0, 0)
    local mask = disc:CreateMaskTexture()
    mask:SetTexture(C.CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(area)
    for i = 1, #LAYERS do
        local fill = disc:CreateTexture(nil, "ARTWORK", nil, 1 + i)
        fill:SetTexture(C.WHITE)
        fill:SetPoint("BOTTOMLEFT", area, "BOTTOMLEFT")
        fill:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT")
        fill:AddMaskTexture(mask)
        fill:Hide()
        view.fills[i] = fill
    end
    local flash = disc:CreateTexture(nil, "ARTWORK", nil, 7)
    flash:SetTexture(C.WHITE)
    flash:SetAllPoints(area)
    flash:AddMaskTexture(mask)
    view.flash = NewFlash(flash)
    view.shares = {}
    -- (the rest of the file shows and hides a view through its holder)
    view.holder = {
        Show = function() view.on = true end,
        Hide = function()
            view.on = false
            for _, fill in ipairs(view.fills) do fill:Hide() end
        end,
    }

    -- the liquid rises from the bottom
    function view:Set(layer, share)
        local fill = self.fills[layer]
        self.shares[layer] = share
        fill:SetShown(self.on and share > 0)
        if share > 0 then fill:SetHeight(math_max(0.5, (self.size or 1) * math_min(1, share))) end
    end
    function view:Tint(layer, color)
        self.fills[layer]:SetVertexColor(color[1], color[2], color[3], C.ALPHA[layer])
    end
    function view:Flash() self.flash:Stop(); self.flash:Play() end
    function view:Place(frame)
        local size = frame.RingFrame.Disc:GetWidth() * C.DISC_SHARE
        self.size = size
        area:SetSize(size, size)
    end
    return view
end

-- the line (a frame style without a ring): status bars along the top of the health bar
local function LineView(f)
    local view = { kind = "line", bars = {} }
    local holder = CreateFrame("Frame", nil, f)
    view.holder = holder
    local track = holder:CreateTexture(nil, "BACKGROUND")
    track:SetTexture(C.WHITE)
    track:SetAllPoints()
    track:SetVertexColor(C.TRACK[1], C.TRACK[2], C.TRACK[3], C.TRACK[4])
    for i = 1, #LAYERS do
        local bar = CreateFrame("StatusBar", nil, holder)
        bar:SetAllPoints()
        bar:SetStatusBarTexture(C.WHITE)
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        view.bars[i] = bar
    end
    local flashFrame = CreateFrame("Frame", nil, holder)
    flashFrame:SetAllPoints()
    local flash = flashFrame:CreateTexture(nil, "OVERLAY")
    flash:SetTexture(C.WHITE)
    flash:SetAllPoints()
    view.flashFrame, view.flash = flashFrame, NewFlash(flash)
    function view:Set(layer, share) self.bars[layer]:SetValue(math_max(0, math_min(1, share))) end
    function view:Tint(layer, color)
        self.bars[layer]:SetStatusBarColor(color[1], color[2], color[3], C.ALPHA[layer])
    end
    function view:Flash() self.flash:Stop(); self.flash:Play() end
    function view:Place(frame)
        holder:ClearAllPoints()
        holder:SetPoint("BOTTOMLEFT", frame.Health, "TOPLEFT", 0, -C.LINE_HEIGHT)
        holder:SetPoint("BOTTOMRIGHT", frame.Health, "TOPRIGHT", 0, -C.LINE_HEIGHT)
        holder:SetHeight(C.LINE_HEIGHT)
        local level = frame.Health:GetFrameLevel() + 2
        holder:SetFrameLevel(level)
        for i, bar in ipairs(self.bars) do bar:SetFrameLevel(level + i) end
        self.flashFrame:SetFrameLevel(level + #self.bars + 1)
    end
    return view
end

local BUILD = { ring = function(f) return RingView(f, "ring") end, levelRing = function(f) return RingView(f, "levelRing") end,
    disc = DiscView, line = LineView }

-- The look this frame can give for the one picked: the level disc's two need a ring style with Show
-- Level on, the portrait ring a ring style; the line needs nothing. (An old "name" setup, the name box
-- look that is gone, counts as the level ring.)
function XP.Resolve(f, mode)
    local Ring = ns.UFRing
    local ring = Ring and Ring.Applies(f) and f.RingFrame or nil
    if mode == "name" then mode = "levelRing" end
    if mode == "disc" or mode == "levelRing" then
        if ring and ring.Disc and ring.Disc:IsShown() then return mode end
        mode = "ring"
    end
    if mode == "ring" and ring and ring.Centre then return "ring" end
    return "line"
end

--------------------------------------------------
-- 3. DRAWING AND MOVING
--------------------------------------------------
local function Paint(bind, share)
    local view, state = bind.view, bind.state
    if not (view and state) then return end
    bind.shown = share
    view:Set(1, state.rested)
    view:Set(2, state.open)
    view:Set(3, state.quest)
    view:Set(4, share)
end

-- The level disc's number: the level, or the share of it done (Level Text > Percent)
local function SyncLevelText(bind)
    local f = _G[bind.name]
    if not (f and f.Level) or bind.unit ~= "player" then return end
    local db = Db()
    local ring = f.RingFrame
    local state = bind.state
    local want = db and db.mode ~= "off" and db.levelText == "percent" and state and state.kind == "xp"
        and ring and ring.Disc and ring.Disc:IsShown() and ns.UFRing.Applies(f)
    if not want then
        if bind.percent then bind.percent:Hide() end
        if bind.levelHidden then
            bind.levelHidden = nil
            f.Level:SetAlpha(1)
        end
        return
    end
    local text = bind.percent
    if not text then
        text = ring.Disc:CreateFontString(nil, "OVERLAY")
        text:SetPoint("CENTER", ring.Disc, "CENTER", 0, 0)
        text:SetTextColor(1, 1, 1)
        text:SetShadowOffset(1, -1)
        text:SetShadowColor(0, 0, 0, 1)
        bind.percent = text
    end
    -- the level's own font, a little smaller: three characters where it has two
    local path, size, flags = f.Level:GetFont()
    if path and size then ns.SetFontUnscaled(text, path, math_max(7, math_floor(size * 0.8 + 0.5)), flags or "") end
    text:SetText(math_floor((bind.shown or state.xp) * 100) .. "%")
    text:Show()
    bind.levelHidden = true
    f.Level:SetAlpha(0)
end

local function HideBind(bind)
    for _, view in pairs(bind.views) do view.holder:Hide() end
    bind.view, bind.anim, bind.sweep = nil, nil, nil
    SyncLevelText(bind)
end

local function EaseOut(p)
    p = math_max(0, math_min(1, p))
    return 1 - (1 - p) * (1 - p)
end

local function StartMove(bind, from, to, seconds)
    bind.anim = { from = from, to = to, t = 0, time = seconds }
    if driver then driver:Show() end
end

-- every frame while a fill is on its way
function XP.Advance(dt)
    local busy = false
    for _, bind in pairs(binds) do
        local anim = bind.anim
        if anim and bind.view and bind.state then
            anim.t = anim.t + dt
            local p = anim.time > 0 and anim.t / anim.time or 1
            if p >= 1 then
                bind.anim = nil
                Paint(bind, anim.to)
                if bind.sweep then
                    -- the old level filled up: flash, empty, and on to the new level's share
                    bind.sweep = nil
                    bind.view:Flash()
                    Paint(bind, 0)
                    if bind.state.xp > 0 then StartMove(bind, 0, bind.state.xp, C.EASE) end
                end
            else
                Paint(bind, anim.from + (anim.to - anim.from) * EaseOut(p))
            end
            if bind.unit == "player" and bind.percent and bind.percent:IsShown() then SyncLevelText(bind) end
        elseif anim then
            bind.anim = nil
        end
        if bind.anim then busy = true end
    end
    if not busy and driver then driver:Hide() end
end

local function Refresh(bind)
    local f = _G[bind.name]
    local db = Db()
    if not (f and f.Health and db) or db.mode == nil or db.mode == "off" then return HideBind(bind) end
    local state
    if bind.unit == "player" then state = XP.State() else state = XP.PetState() end
    bind.state = state
    if not state then return HideBind(bind) end

    local kind = XP.Resolve(f, db.mode)
    local view = bind.views[kind]
    if not view then
        view = BUILD[kind](f)
        bind.views[kind] = view
    end
    for other, built in pairs(bind.views) do
        if other ~= kind then built.holder:Hide() end
    end
    view:Place(f)
    view:Tint(1, Color("restBonus"))
    view:Tint(2, Color("quest"))
    view:Tint(3, Color("quest"))
    view:Tint(4, Color(state.color))
    view.holder:Show()
    local fresh = bind.view ~= view
    bind.view = view

    local target = state.xp
    if bind.levelUp then
        bind.levelUp = nil
        if Animated() and not fresh and bind.shown then
            bind.sweep = true
            StartMove(bind, bind.shown, 1, C.SWEEP)
            return SyncLevelText(bind)
        end
    end
    if bind.sweep then
        -- (the sweep ends on the state just read)
    elseif fresh or not bind.shown or not Animated() or bind.shown == target then
        bind.anim = nil
        Paint(bind, target)
    else
        StartMove(bind, bind.shown, target, C.EASE)
        Paint(bind, bind.shown)
    end
    SyncLevelText(bind)
end

function XP:Refresh()
    quest.stale = true
    for _, bind in pairs(binds) do Refresh(bind) end
    XP.HideBars()
end

--------------------------------------------------
-- 4. THE TOOLTIP
-- A few lines under the frame's own tooltip: the frame keeps every click.
--------------------------------------------------
local function Big(value)
    value = math_floor(value + 0.5)
    return BreakUpLargeNumbers and BreakUpLargeNumbers(value) or tostring(value)
end

local QUEST_LINES = 10

-- "1,200 / 5,000 (24%)"
local function Progress(value, maxValue)
    return ("%s / %s (%d%%)"):format(Big(value), Big(maxValue), maxValue > 0 and math_floor(value / maxValue * 100) or 0)
end

-- The numbers behind the fill, as the FlareUI XP bar's tooltip has them, and where the quests ready
-- to hand in would leave you
local function AddLines(tip, bind)
    local state = bind.state
    if not state then return end
    tip:AddLine(" ")
    if state.kind == "rep" then
        local standing = _G["FACTION_STANDING_LABEL" .. tostring(state.reaction)]
        tip:AddDoubleLine(state.name, standing or "", 1, 0.82, 0, 1, 1, 1)
        tip:AddDoubleLine(L["Reputation"], Progress(state.value, state.max), 1, 1, 1, 1, 1, 1)
        return
    end
    if state.kind == "pet" then
        tip:AddDoubleLine(L["Pet Experience"], Progress(state.value, state.max), 1, 0.82, 0, 1, 1, 1)
        tip:AddDoubleLine(L["To next level"], Big(state.max - state.value), 1, 1, 1, 1, 1, 1)
        return
    end
    local left = state.max - state.value
    tip:AddDoubleLine(L["XP"], Progress(state.value, state.max), 1, 0.82, 0, 1, 1, 1)
    tip:AddDoubleLine(L["To next level"], Big(left), 1, 1, 1, 1, 1, 1)
    if state.restedXP and state.restedXP > 0 then
        local c = Color("restBonus")
        tip:AddDoubleLine(L["Rested"], ("%s (%d%%)"):format(Big(state.restedXP), math_floor(state.restedXP / state.max * 100)), 1, 1, 1, c[1], c[2], c[3])
    end
    local ready, open = state.questReady or 0, state.questOpen or 0
    local c = Color("quest")
    if ready > 0 then
        tip:AddDoubleLine(L["Quests ready to hand in"], Big(ready), 1, 1, 1, c[1], c[2], c[3])
        local list = state.questList or {}
        for i = 1, math_min(#list, QUEST_LINES) do
            tip:AddDoubleLine("   " .. list[i][1], Big(list[i][2]), 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
        end
        if #list > QUEST_LINES then tip:AddLine("   " .. L["and %d more"]:format(#list - QUEST_LINES), 0.6, 0.6, 0.6) end
        -- handed in: the share of the level reached, or how far past it
        if ready >= left then
            tip:AddDoubleLine(L["After handing in"], L["Level %d + %s XP"]:format((state.level or 0) + 1, Big(ready - left)), 1, 1, 1, 0.2, 1, 0.4)
        else
            tip:AddDoubleLine(L["After handing in"], Progress(state.value + ready, state.max), 1, 1, 1, c[1], c[2], c[3])
        end
    end
    if open > 0 then
        tip:AddDoubleLine(L["Quests in progress"], Big(open), 1, 1, 1, c[1], c[2], c[3])
        if ready + open >= left then
            tip:AddDoubleLine(L["After all quests"], L["Level %d + %s XP"]:format((state.level or 0) + 1, Big(ready + open - left)), 1, 1, 1, 0.2, 1, 0.4)
        else
            tip:AddDoubleLine(L["After all quests"], Progress(state.value + ready + open, state.max), 1, 1, 1, c[1], c[2], c[3])
        end
    end
    local hourly = PerHour()
    if hourly then
        tip:AddDoubleLine(L["XP per hour"], Big(hourly), 1, 1, 1, 1, 1, 1)
        if left > 0 and SecondsToTime then
            tip:AddDoubleLine(L["Time to level"], SecondsToTime(math_floor(left / hourly * 3600)), 1, 1, 1, 1, 1, 1)
        end
    end
end

-- How far the pointer is from a region's middle, in the region's own units; nil when its place can't be read
local function PointerFrom(region)
    if not (region and region.GetCenter and GetCursorPosition) then return nil end
    local x, y = region:GetCenter()
    local scale = region:GetEffectiveScale()
    local px, py = GetCursorPosition()
    if not (x and y and scale and px and py) then return nil end
    if not (Readable(x) and Readable(y) and Readable(scale)) or scale <= 0 then return nil end
    local dx, dy = px / scale - x, py / scale - y
    return math.sqrt(dx * dx + dy * dy)
end

-- The pointer is on the XP itself or on the level: the level disc with whatever ring stands round it,
-- and for the portrait ring its band (not the portrait inside it). The disc's click area is a square
-- bigger than the disc and reaches over the portrait, so the round shapes are measured, not the buttons.
-- The line (a frame style without a ring) has no shape of its own: the frame.
local function Hovered(bind)
    local f = _G[bind.name]
    local view = bind.view
    if not (f and view and f.IsMouseOver) then return false end
    if view.kind == "line" then return f:IsVisible() and f:IsMouseOver() or false end
    local ring = f.RingFrame
    if not (ring and ring.Disc) then return false end
    local band = (view.kind == "ring" or view.kind == "levelRing") and view.holder or nil
    local bandOut = band and band:GetWidth() / 2 * 122 / 128 or 0
    if ring.Disc:IsVisible() then
        local away = PointerFrom(ring.Disc)
        if away == nil then
            -- (its place unreadable: the click area will have to do)
            if ring.DiscHit and ring.DiscHit:IsVisible() and ring.DiscHit:IsMouseOver() then return true end
        else
            local reach = ring.Disc:GetWidth() * C.LEVEL_EDGE
            if view.kind == "levelRing" then reach = math_max(reach, bandOut) end
            if away <= reach then return true end
        end
    end
    if view.kind == "ring" then
        local away = PointerFrom(ring.Centre)
        local inner = ring.Centre:GetWidth() * 0.45   -- (the portrait's own edge: the band and the bronze rim count)
        if away and away >= inner and away <= bandOut then return true end
    end
    return false
end

local function TipWanted(bind)
    local db = Db()
    return db and db.tooltip ~= false and db.mode ~= "off" and bind.view and bind.state and true or false
end

-- The game builds a unit's tooltip again whenever its data changes, which drops lines added once: so
-- they are added each time it is built, while the mouse is on our frame.
local function HookTooltip()
    if XP.tipHooked then return end
    XP.tipHooked = true
    local unitType = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and unitType then
        TooltipDataProcessor.AddTooltipPostCall(unitType, function(tip)
            if tip ~= GameTooltip then return end
            for _, bind in pairs(binds) do
                if TipWanted(bind) and Hovered(bind) then return AddLines(tip, bind) end
            end
        end)
        return
    end
    -- (the watcher below builds the tooltip again as the pointer moves on and off the XP)
    -- an older client: once, after the frame's own tooltip is built
    for _, bind in pairs(binds) do
        local f = _G[bind.name]
        if f and f.HookScript then
            f:HookScript("OnEnter", function()
                if not TipWanted(bind) or bind.tipPending then return end
                bind.tipPending = true
                C_Timer.After(0, function()
                    bind.tipPending = nil
                    if GameTooltip and GameTooltip:IsShown() and TipWanted(bind) then
                        AddLines(GameTooltip, bind)
                        GameTooltip:Show()
                    end
                end)
            end)
        end
    end
end

-- Moving on and off the XP inside one click area builds no new tooltip, so the lines would stay (or
-- never come) until the pointer left the frame. A few times a second, while the pointer is on the
-- frame: when "on the XP" changes, the frame's own tooltip is built again.
local watch = { since = 0, state = {} }
local function WatchTooltip(elapsed)
    watch.since = watch.since + elapsed
    if watch.since < 0.1 then return end
    watch.since = 0
    for key, bind in pairs(binds) do
        local f = _G[bind.name]
        local ring = f and f.RingFrame
        local over = f and TipWanted(bind) and ((f:IsVisible() and f:IsMouseOver())
            or (ring and ring.Hit and ring.Hit:IsVisible() and ring.Hit:IsMouseOver())
            or (ring and ring.DiscHit and ring.DiscHit:IsVisible() and ring.DiscHit:IsMouseOver()))
        if not over then
            watch.state[key] = nil
        else
            local on = Hovered(bind)
            if watch.state[key] ~= nil and watch.state[key] ~= on and GameTooltip and GameTooltip:IsShown() then
                local script = f:GetScript("OnEnter")
                if script then pcall(script, f) end
            end
            watch.state[key] = on
        end
    end
end

--------------------------------------------------
-- 5. HIDE XP BARS
-- unitframes.xp.hideBars: "flare" (FlareUI's XP bar: XPBar.lua asks XP.Hides), "blizzard" and
-- "blizzard2" (Blizzard's first and second tracking bar, when FlareUI's bar isn't in their place).
-- Blizzard's are made see-through and deaf to the mouse, never hidden: they are the game's to show.
--------------------------------------------------
function XP.Hides(token)
    local db = Db()
    local value = db and db.hideBars
    if type(value) ~= "string" or value == "" then return false end
    return ("," .. value .. ","):find("," .. token .. ",", 1, true) ~= nil
end

local BLIZZARD = {
    blizzard = { "MainStatusTrackingBarContainer", "MainMenuExpBar" },
    blizzard2 = { "SecondaryStatusTrackingBarContainer", "ReputationWatchBar" },
}
local held, alphaHooked = {}, {}

local function SetMouse(frame, record, on)
    if not frame.GetChildren then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        if child.EnableMouse and child.IsMouseEnabled then
            if not on then
                if record[child] == nil then record[child] = child:IsMouseEnabled() and true or false end
                pcall(child.EnableMouse, child, false)
            elseif record[child] then
                pcall(child.EnableMouse, child, true)
            end
        end
    end
end

local function Hold(frame, hide)
    if not (frame and frame.SetAlpha) then return end
    if hide then
        held[frame] = held[frame] or {}
        if not alphaHooked[frame] then
            alphaHooked[frame] = true
            -- (Blizzard fades its bars in and out: back to nothing each time)
            hooksecurefunc(frame, "SetAlpha", function(self, alpha)
                if held[self] and alpha ~= 0 then self:SetAlpha(0) end
            end)
        end
        frame:SetAlpha(0)
        SetMouse(frame, held[frame], false)
    elseif held[frame] then
        local record = held[frame]
        held[frame] = nil
        frame:SetAlpha(1)
        SetMouse(frame, record, true)
    end
end

function XP.HideBars()
    for token, names in pairs(BLIZZARD) do
        local hide = XP.Hides(token)
        for _, name in ipairs(names) do Hold(_G[name], hide) end
    end
    local XPB = ns.XPBar
    if XPB and XPB.GetFrame and XPB:GetFrame() and XPB.Refresh then XPB:Refresh() end
end

--------------------------------------------------
-- 6. SETUP
--------------------------------------------------
local function BindOf(f)
    for _, bind in pairs(binds) do
        if _G[bind.name] == f then return bind end
    end
end

local EVENTS = { "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION", "PLAYER_UPDATE_RESTING",
    "ENABLE_XP_GAIN", "DISABLE_XP_GAIN", "PLAYER_MAX_LEVEL_UPDATE", "UPDATE_FACTION", "QUEST_LOG_UPDATE",
    "UNIT_PET", "UNIT_PET_EXPERIENCE", "PET_UI_UPDATE" }
local PET_EVENTS = { UNIT_PET = true, UNIT_PET_EXPERIENCE = true, PET_UI_UPDATE = true }

function XP:Init()
    if driver then return end
    driver = CreateFrame("Frame")
    driver:Hide()
    driver:SetScript("OnUpdate", function(_, elapsed) XP.Advance(elapsed) end)
    local watcher = CreateFrame("Frame")
    watcher:SetScript("OnUpdate", function(_, elapsed) WatchTooltip(elapsed) end)
    XP.WatchTooltip = WatchTooltip

    -- the ring laid out again (a style, a size, Show Level): the looks follow it
    local Ring = ns.UFRing
    if Ring then
        local function Follow(f)
            local bind = BindOf(f)
            if bind then Refresh(bind) end
        end
        hooksecurefunc(Ring, "Layout", Follow)
        hooksecurefunc(Ring, "Reset", Follow)
        hooksecurefunc(Ring, "LayoutLevel", Follow)
        -- (the ring shows the level's number again on each update)
        hooksecurefunc(Ring, "Update", function(f)
            local bind = BindOf(f)
            if bind and bind.levelHidden then f.Level:SetAlpha(0) end
        end)
    end

    local events = CreateFrame("Frame")
    for _, event in ipairs(EVENTS) do pcall(events.RegisterEvent, events, event) end
    events:SetScript("OnEvent", function(_, event, unit)
        if event == "QUEST_LOG_UPDATE" then
            local db = Db()
            if not (db and db.mode ~= "off") then return end
            quest.stale = true   -- (the tooltip tells the quests' XP even without the Quest XP layer)
        elseif event == "PLAYER_LEVEL_UP" then
            binds.player.levelUp = true
            quest.stale = true
        elseif event == "PLAYER_ENTERING_WORLD" then
            quest.stale = true
            HookTooltip()
            XP.HideBars()
        end
        if PET_EVENTS[event] then
            if event == "UNIT_PET" and unit ~= "player" then return end
            return Refresh(binds.pet)
        end
        TrackRate()
        Refresh(binds.player)
        if event == "PLAYER_ENTERING_WORLD" then Refresh(binds.pet) end
    end)

    local LEM = LibStub("FlareEditMode", true)
    if LEM and LEM.RegisterCallback then
        LEM:RegisterCallback("exit", function() XP:Refresh() end)
    end
end
