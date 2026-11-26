local _, ns = ...

--------------------------------------------------
-- DOT MARKER
-- What FlareUI's own DoT tracker draws on a health bar (DotTracker.lua; the target and focus frames
-- through UnitFramesDoesItDie.lua, the nameplates through NameplateDots.lua): a mark as wide as the
-- damage the player's DoTs still have to deal, one piece per DoT, and a kill icon when that is
-- enough to finish the unit off.
-- The mark stands in one of two places (Mark Position):
--   * back from the health's end (the default): the stretch of health the DoTs will take. Its far
--     edge is where the health will end up; a mark that reaches the bar's start means a kill. Always
--     in sight where the health is, which matters on FlareUI's ring frames: there the portrait ring
--     lies over the bar's first pixels, and the target's mirrored bar starts under it.
--   * from the bar's start, as DoesItDie draws it: health inside the mark means a kill.
-- Health is secret in combat, so Lua never compares it: every piece is a status bar with the unit's
-- maximum health as its maximum, anchored to the health's fill where it follows it, and the kill
-- icon rides a bar whose maximum is the health left (the method is DoesItDie's own, MIT). Our own
-- damage numbers are plain.
--------------------------------------------------
local M = {}
ns.DotMarker = M

local ipairs, type, pcall = ipairs, type, pcall
local math_floor, math_min = math.floor, math.min
local CreateFrame = CreateFrame

local C = {
    WHITE = "Interface\\Buttons\\WHITE8x8",
    SKULL = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8",
    CROSS = "Interface\\RaidFrame\\ReadyCheck-NotReady",
    KILL_BAR_LENGTH = 10000,    -- the icon rides a bar this long, clipped to its last few pixels
    SINGLE = { 0.7, 0.3, 1 },   -- One Colour: the mark FlareUI draws for the DoesItDie addons
    EDGE = { 1, 1, 1, 0.9 },
    DIVIDER = { 0, 0, 0, 0.55 },
    FLASH = 0.4, PULSE = { 1, 0.45, 0.6 },
}
-- a DoT's colour is its school's (the school's mask, as the tracker reports it)
M.SCHOOL_COLORS = {
    [1] = { 0.90, 0.25, 0.25 },   -- Physical (bleeds)
    [2] = { 1.00, 0.88, 0.45 },   -- Holy
    [4] = { 1.00, 0.55, 0.15 },   -- Fire
    [8] = { 0.40, 0.90, 0.35 },   -- Nature
    [16] = { 0.45, 0.80, 1.00 },  -- Frost
    [20] = { 0.75, 0.60, 1.00 },  -- Frostfire
    [32] = { 0.62, 0.36, 1.00 },  -- Shadow
    [64] = { 1.00, 0.55, 1.00 },  -- Arcane
}

-- Each DoT its own colour: its school's, and paler for each further DoT of the same school (Corruption
-- and Curse of Agony are both Shadow)
local function PieceColor(list, index)
    local entry = list[index]
    local base = M.SCHOOL_COLORS[entry.school] or C.SINGLE
    local same = 0
    for i = 1, index - 1 do
        if list[i].school == entry.school then same = same + 1 end
    end
    if same == 0 then return base[1], base[2], base[3] end
    local mix = math_min(0.6, same * 0.3)
    return base[1] + (1 - base[1]) * mix, base[2] + (1 - base[2]) * mix, base[3] + (1 - base[3]) * mix
end

-- An invisible bar on the health's scale: its fill's end marks so much damage. Inside the clip, which
-- keeps a mark that runs past the bar's start within the bar.
local function NewGauge(rec)
    local bar = CreateFrame("StatusBar", nil, rec.clip)
    bar:SetStatusBarTexture(C.WHITE)
    bar:SetStatusBarColor(0, 0, 0, 0)
    bar:Hide()
    return bar
end

-- host: the frame it belongs to; bar: the bar it lies over; pieces: how many DoTs get one of their own;
-- health: the status bar whose fill is the unit's health (bar itself, unless bar only marks its place)
function M.New(host, bar, pieces, health)
    local rec = { host = host, bar = bar, health = health or bar, max = pieces or 8, gauges = {}, fills = {}, dividers = {} }
    local clip = CreateFrame("Frame", nil, host)
    clip:SetAllPoints(bar)
    clip:SetClipsChildren(true)
    rec.clip = clip
    -- the pieces are drawn by one frame, each between the ends of two gauges
    local art = CreateFrame("Frame", nil, host)
    art:SetAllPoints(bar)
    art:Hide()
    rec.art = art
    rec.edge = art:CreateTexture(nil, "OVERLAY")
    rec.edge:SetColorTexture(C.EDGE[1], C.EDGE[2], C.EDGE[3], C.EDGE[4])
    rec.edge:SetWidth(1)
    rec.flash = art:CreateTexture(nil, "OVERLAY", nil, 1)
    rec.flash:SetColorTexture(1, 1, 1, 1)
    rec.flash:SetAlpha(0)
    local group = rec.flash:CreateAnimationGroup()
    local fade = group:CreateAnimation("Alpha")
    fade:SetFromAlpha(0.7)
    fade:SetToAlpha(0)
    fade:SetDuration(C.FLASH)
    rec.flashAnim = group

    -- the kill icon: maximum = the health left, value = the damage: the fill only reaches the end when
    -- the damage is enough, and only the end shows through the window
    local window = CreateFrame("Frame", nil, host)
    window:SetClipsChildren(true)
    window:Hide()
    rec.window = window
    local killBar = CreateFrame("StatusBar", nil, window)
    killBar:SetPoint("RIGHT", window, "RIGHT")
    killBar:SetStatusBarTexture(C.WHITE)
    killBar:SetStatusBarColor(0, 0, 0, 0)
    rec.killBar = killBar
    rec.icon = killBar:CreateTexture(nil, "OVERLAY")
    rec.icon:SetPoint("RIGHT", killBar:GetStatusBarTexture(), "RIGHT")
    local pulse = rec.icon:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local beat = pulse:CreateAnimation("Alpha")
    beat:SetFromAlpha(C.PULSE[1])
    beat:SetToAlpha(C.PULSE[2])
    beat:SetDuration(C.PULSE[3])
    rec.pulse = pulse
    return setmetatable(rec, { __index = M })
end

-- The frame levels (the mark over the bar and its overlays, the icon over the portrait), and where the
-- icon sits: centred on `anchor` at `point`, `size` across
function M:Place(markLevel, iconLevel, anchor, point, size, x, y)
    self.art:SetFrameLevel(markLevel)
    self.clip:SetFrameLevel(markLevel)
    for _, gauge in ipairs(self.gauges) do gauge:SetFrameLevel(markLevel) end
    self.markLevel = markLevel
    local window = self.window
    window:SetFrameLevel(iconLevel)
    if anchor == self.placedOn and point == self.placedPoint and size == self.placedSize then return end
    self.placedOn, self.placedPoint, self.placedSize = anchor, point, size
    window:ClearAllPoints()
    window:SetPoint("CENTER", anchor, point, x or 0, y or 0)
    window:SetSize(size, size)
    self.killBar:SetSize(C.KILL_BAR_LENGTH, size)
    self.icon:SetSize(size, size)
end

-- (a nameplate's health bar can sit in another strata than its plate)
function M:SetStrata(strata)
    if self.strata == strata then return end
    self.strata = strata
    self.art:SetFrameStrata(strata)
    self.clip:SetFrameStrata(strata)
    if self.cap then self.cap:SetFrameStrata(strata) end
    self.window:SetFrameStrata(strata)
    for _, gauge in ipairs(self.gauges) do gauge:SetFrameStrata(strata) end
end

function M:Hide()
    if self.cap then self.cap:Hide() end
    self.art:Hide()
    self.window:Hide()
    for _, gauge in ipairs(self.gauges) do gauge:Hide() end
    if self.pulse:IsPlaying() then self.pulse:Stop() end
    self.drawn = nil
end

function M:Flash()
    if not self.art:IsShown() then return end
    self.flashAnim:Stop()
    self.flashAnim:Play()
end

-- A copy of a piece for the cap (M.SetCap): drawn by the cap's frame, between the same two ends
local function CapPiece(rec, i)
    if not rec.cap or rec.capFills[i] then return end
    rec.capFills[i] = rec.cap:CreateTexture(nil, "ARTWORK")
    rec.capFills[i]:SetTexture(C.WHITE)
end

-- The start of the bar can lie under something drawn over the frame (the ring styles' portrait ring
-- covers the bar's first pixels on its side): a mark that small would never be seen. The cap is that
-- stretch of the mark drawn again above it. level: over what covers the bar; width: how much of the
-- bar's start is covered (nil or 0: no cap).
function M:SetCap(level, width)
    if not width or width <= 0 then
        if self.cap then self.cap:Hide() end
        self.capWidth = nil
        return
    end
    if not self.cap then
        self.cap = CreateFrame("Frame", nil, self.host)
        self.cap:SetClipsChildren(true)
        self.cap:Hide()
        self.capFills = {}
        self.capEdge = self.cap:CreateTexture(nil, "OVERLAY")
        self.capEdge:SetColorTexture(C.EDGE[1], C.EDGE[2], C.EDGE[3], C.EDGE[4])
        self.capEdge:SetWidth(1)
        for i = 1, #self.gauges do CapPiece(self, i) end
        self.laid = nil   -- (laid out again, with the cap's pieces)
    end
    if self.strata then self.cap:SetFrameStrata(self.strata) end
    self.cap:SetFrameLevel(level)
    if self.capWidth ~= width then
        self.capWidth, self.capSide = width, nil
        self.cap:SetWidth(width)
    end
end

-- between the ends of two gauges (the first: its own gauge's whole fill)
local function Span(rec, texture, i, near, far)
    local own = rec.gauges[i]:GetStatusBarTexture()
    texture:ClearAllPoints()
    if i == 1 then
        texture:SetAllPoints(own)
    else
        local before = rec.gauges[i - 1]:GetStatusBarTexture()
        texture:SetPoint("TOP" .. near, before, "TOP" .. far)
        texture:SetPoint("BOTTOM" .. far, own, "BOTTOM" .. far)
    end
    texture:Show()
end

-- The pieces follow the side the health fills from (Mirror). atHealth: they grow back from the health's
-- end toward the bar's start; else from the bar's start. width: the bar's, for the gauges that hang on
-- the health's end.
local function Lay(rec, count, reverse, atHealth, width)
    local startSide, endSide = reverse and "RIGHT" or "LEFT", reverse and "LEFT" or "RIGHT"
    -- the side each piece grows from, and toward
    local near, far = startSide, endSide
    if atHealth then near, far = endSide, startSide end
    -- the cap sits on the bar's start, whichever side that is
    if rec.cap and rec.capWidth and rec.capSide ~= startSide then
        rec.capSide = startSide
        rec.cap:ClearAllPoints()
        rec.cap:SetPoint("TOP" .. startSide, rec.bar, "TOP" .. startSide)
        rec.cap:SetPoint("BOTTOM" .. startSide, rec.bar, "BOTTOM" .. startSide)
    end
    if rec.laid == count and rec.reverse == reverse and rec.atHealth == atHealth and rec.width == width then return end
    rec.laid, rec.reverse, rec.atHealth, rec.width = count, reverse, atHealth, width
    local healthFill = atHealth and rec.health:GetStatusBarTexture() or nil
    for i = 1, #rec.gauges do
        local gauge = rec.gauges[i]
        gauge:ClearAllPoints()
        if healthFill then
            -- its own start on the health's end, as long as the bar: so much of the health, counted back
            gauge:SetPoint("TOP" .. near, healthFill, "TOP" .. near)
            gauge:SetPoint("BOTTOM" .. near, healthFill, "BOTTOM" .. near)
            gauge:SetWidth(width)
        else
            gauge:SetAllPoints(rec.bar)
        end
        gauge:SetReverseFill(near == "RIGHT")
    end
    for i = 1, #rec.fills do
        rec.fills[i]:Hide()
        rec.dividers[i]:Hide()
    end
    for i = 1, count do
        Span(rec, rec.fills[i], i, near, far)
        local own = rec.gauges[i]:GetStatusBarTexture()
        local divider = rec.dividers[i]
        divider:ClearAllPoints()
        divider:SetPoint("TOP", own, "TOP" .. far)
        divider:SetPoint("BOTTOM", own, "BOTTOM" .. far)
        divider:SetShown(i < count)
    end
    local last = rec.gauges[count]:GetStatusBarTexture()
    rec.edge:ClearAllPoints()
    rec.edge:SetPoint("TOP", last, "TOP" .. far)
    rec.edge:SetPoint("BOTTOM", last, "BOTTOM" .. far)
    rec.flash:ClearAllPoints()
    rec.flash:SetAllPoints(last)
    if rec.cap then
        for i = 1, #rec.capFills do rec.capFills[i]:Hide() end
        for i = 1, count do Span(rec, rec.capFills[i], i, near, far) end
        rec.capEdge:ClearAllPoints()
        rec.capEdge:SetPoint("TOP", last, "TOP" .. far)
        rec.capEdge:SetPoint("BOTTOM", last, "BOTTOM" .. far)
    end
end

local function Piece(rec, i)
    if rec.gauges[i] then return end
    local gauge = NewGauge(rec)
    rec.laid = nil   -- (placed with the others at the next layout)
    if rec.strata then gauge:SetFrameStrata(rec.strata) end
    if rec.markLevel then gauge:SetFrameLevel(rec.markLevel) end
    rec.gauges[i] = gauge
    rec.fills[i] = rec.art:CreateTexture(nil, "ARTWORK")
    rec.fills[i]:SetTexture(C.WHITE)
    rec.dividers[i] = rec.art:CreateTexture(nil, "ARTWORK", nil, 1)
    rec.dividers[i]:SetColorTexture(C.DIVIDER[1], C.DIVIDER[2], C.DIVIDER[3], C.DIVIDER[4])
    rec.dividers[i]:SetWidth(1)
    CapPiece(rec, i)
end

-- unit: whose health; list: the tracker's DoTs on it, oldest first ({ school, damage }); total: their sum.
-- look: { marker, each, opacity, smooth, atHealth, icon ("off" | "skull" | "cross"), pulse, shielded }.
-- Returns false when the bars would not take the numbers (the mark is hidden then).
function M:Draw(unit, list, total, look)
    local count = look.each and math_min(#list, self.max) or 1
    for i = 1, count do Piece(self, i) end
    local reverse = self.health:GetReverseFill() and true or false
    local atHealth = look.atHealth and true or false
    -- (the bar's length, for the gauges that hang on the health's end; an unreadable one keeps the last)
    local width = atHealth and self.bar:GetWidth() or nil
    if width ~= nil and not (not canaccessvalue or canaccessvalue(width)) then width = self.width end
    if atHealth and not width then atHealth = false end
    Lay(self, count, reverse, atHealth, width)

    local maxHealth, health = UnitHealthMax(unit), UnitHealth(unit)
    local smooth = look.smooth and self.drawn and Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut or nil
    local reach, ok = 0, true
    for i = 1, count do
        local gauge = self.gauges[i]
        -- (the last piece takes whatever is left: the DoTs past the pieces there are, and rounding)
        reach = (look.each and i < count) and reach + list[i].damage or total
        ok = ok and pcall(gauge.SetMinMaxValues, gauge, 0, maxHealth)
        if smooth then ok = ok and pcall(gauge.SetValue, gauge, reach, smooth) else ok = ok and pcall(gauge.SetValue, gauge, reach) end
        gauge:Show()
        local r, g, b = C.SINGLE[1], C.SINGLE[2], C.SINGLE[3]
        if look.each then r, g, b = PieceColor(list, i) end
        self.fills[i]:SetVertexColor(r, g, b, look.opacity or 0.55)
        if self.cap then self.capFills[i]:SetVertexColor(r, g, b, look.opacity or 0.55) end
    end
    for i = count + 1, #self.gauges do self.gauges[i]:Hide() end
    ok = ok and pcall(self.killBar.SetMinMaxValues, self.killBar, 0, health)
        and pcall(self.killBar.SetValue, self.killBar, total)
    if not ok then
        self:Hide()
        return false
    end
    self.drawn = true
    self.art:SetShown(look.marker ~= false)
    if self.cap then self.cap:SetShown(look.marker ~= false and self.capWidth ~= nil) end

    local icon = look.icon or "skull"
    local showIcon = icon ~= "off" and not look.shielded
    if showIcon then
        if self.iconKind ~= icon then
            self.iconKind = icon
            self.icon:SetTexture(icon == "cross" and C.CROSS or C.SKULL)
        end
        if look.pulse then
            if not self.pulse:IsPlaying() then self.pulse:Play() end
        elseif self.pulse:IsPlaying() then
            self.pulse:Stop()
            self.icon:SetAlpha(1)
        end
    end
    self.window:SetShown(showIcon)
    return true
end
