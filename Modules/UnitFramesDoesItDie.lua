local _, ns = ...

--------------------------------------------------
-- DOESITDIE
-- (With FlareUI's own DoT Tracker running instead, DotTracker.lua: its estimate, drawn by DotMarker.lua.)
-- With DoesItDie or DoesItDiePlus, its estimate on FlareUI's target and focus frames, which replace the Blizzard
-- frames it draws on: a mark for the damage the player's DoTs still have to deal, and a skull when that is
-- enough to kill. Numbers come from its public API; its marker and skull settings are followed, and a frame
-- it was pointed at by hand under its Advanced options is left to it.
-- Health can be secret, so Lua never compares it: status bars do (the method is DoesItDie's own, MIT).
--------------------------------------------------
local LEM = LibStub("FlareEditMode")

local DIE = {}
ns.UFDoesItDie = DIE

local UNITS = {
    target = { frame = "FlareUI_UF_Target", customBar = "customHealthBar" },
    focus = { frame = "FlareUI_UF_Focus", customBar = "customFocusHealthBar" },
}

local WHITE = "Interface\\Buttons\\WHITE8x8"
local SKULL = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
local MARK_COLOR = { 0.7, 0.3, 1, 0.55 }
local KILL_BAR_LENGTH = 10000           -- the skull rides a bar this long, clipped to its last few pixels
local KILL_ON_PORTRAIT = 0.6            -- of the portrait's width
local KILL_ON_BAR = 1.4                 -- of the health bar's height

local records = {}

-- The mark lies over the whole health bar with the same maximum, so it shares its scale. Above the bars and
-- their heal overlays, under the border and text.
local function Build(f)
    local rec = { frame = f }
    local mark = CreateFrame("StatusBar", nil, f)
    mark:SetAllPoints(f.Health)
    mark:SetFrameLevel(f:GetFrameLevel() + 3)
    mark:SetStatusBarTexture(WHITE)
    mark:SetStatusBarColor(MARK_COLOR[1], MARK_COLOR[2], MARK_COLOR[3], MARK_COLOR[4])
    mark:Hide()
    rec.mark = mark
    rec.edge = mark:CreateTexture(nil, "OVERLAY")
    rec.edge:SetColorTexture(1, 1, 1, 0.9)
    rec.edge:SetWidth(1)

    -- maximum = current health, value = damage: the fill only reaches the end when the damage is enough, and
    -- only the end shows through the window
    local window = CreateFrame("Frame", nil, f)
    window:SetClipsChildren(true)
    window:SetFrameLevel(f:GetFrameLevel() + 12)
    window:Hide()
    rec.window = window
    local killBar = CreateFrame("StatusBar", nil, window)
    killBar:SetPoint("RIGHT", window, "RIGHT")
    killBar:SetStatusBarTexture(WHITE)
    killBar:SetStatusBarColor(0, 0, 0, 0)
    rec.killBar = killBar
    rec.skull = killBar:CreateTexture(nil, "OVERLAY")
    rec.skull:SetTexture(SKULL)
    rec.skull:SetPoint("RIGHT", killBar:GetStatusBarTexture(), "RIGHT")
    return rec
end

-- The mark fills from the side the health does (Mirror), its edge at the far end
local function FollowFill(rec, direction)
    local reverse = rec.frame.Health:GetReverseFill() and true or false
    if direction == "rtl" then reverse = true elseif direction == "ltr" then reverse = false end
    if rec.reverse == reverse then return end
    rec.reverse = reverse
    rec.mark:SetReverseFill(reverse)
    local side = reverse and "LEFT" or "RIGHT"
    local fill = rec.mark:GetStatusBarTexture()
    rec.edge:ClearAllPoints()
    rec.edge:SetPoint("TOP", fill, "TOP" .. side)
    rec.edge:SetPoint("BOTTOM", fill, "BOTTOM" .. side)
end

-- On the portrait while it shows, else on the health bar's far end
local function PlaceSkull(rec)
    local f, window = rec.frame, rec.window
    local portrait = f.Portrait and f.Portrait:IsShown() and f.Portrait or nil
    local size
    if portrait then
        size = portrait:GetWidth() * KILL_ON_PORTRAIT
    else
        size = f.Health:GetHeight() * KILL_ON_BAR
    end
    if portrait == rec.placedOn and size == rec.placedSize and rec.reverse == rec.placedReverse then return end
    rec.placedOn, rec.placedSize, rec.placedReverse = portrait, size, rec.reverse
    window:ClearAllPoints()
    if portrait then
        window:SetPoint("CENTER", portrait, "CENTER")
    else
        local side = rec.reverse and "LEFT" or "RIGHT"
        window:SetPoint("CENTER", f.Health, side)
    end
    window:SetSize(size, size)
    rec.killBar:SetSize(KILL_BAR_LENGTH, size)
    rec.skull:SetSize(size, size)
end

local function HideRecord(rec)
    if not rec then return end
    rec.mark:Hide()
    rec.window:Hide()
end

-- Like DoesItDie's custom-frame resolver, accept a frame/region path, not merely nonblank text.
-- A stale path falls back to our bars without rewriting the user's setting; a late-created frame
-- takes over on the next refresh. Foreign frame fields can throw, so resolve under pcall.
local function HasCustomBar(path)
    if type(path) ~= "string" then return false end
    local ok, bar = pcall(function()
        local value = _G
        for key in strtrim(path):gmatch("[^%.]+") do
            if not canaccessvalue(value) or type(value) ~= "table" then return end
            value = value[key]
        end
        if canaccessvalue(value) and type(value) == "table" and value ~= _G
            and type(value.GetObjectType) == "function" and type(value.GetWidth) == "function" then
            return value
        end
    end)
    return ok and bar ~= nil
end

-- Keep the original integration first when both addons are loaded. Plus's root lookup omits
-- disabled modules; its legacy DoT global remains present even when the module is off.
local function Source()
    local api = _G.DoesItDie
    if api and type(api.GetRemainingDamage) == "function" and type(api.RegisterCallback) == "function" then
        return api, _G.DoesItDieDB, false
    end
    local root = _G.UsefulPlatesAndTooltips_API
    api = root and type(root.Get) == "function" and root.Get("DoT")
    if api and type(api.GetRemainingDamage) == "function" and type(api.RegisterCallback) == "function" then
        return api, _G.UsefulPlatesAndTooltips_DoTInfoDB, true
    end
end

-- FlareUI's own tracker (DotTracker.lua) running: its estimate, drawn by DotMarker.lua with the DoT Tracker
-- page's look: a piece per DoT, the kill icon on the portrait (on the bar's far end without one).
local own = {}
local function UpdateOwn(unit, flash)
    local info = UNITS[unit]
    if not info then return end
    local D = ns.Dots
    local rec = own[unit]
    local look = D.Look(unit)
    if not look or ns.EditPreviewing() then
        if rec then rec:Hide() end
        return
    end
    local exists, dead = UnitExists(unit), UnitIsDead(unit)
    if not canaccessvalue(exists) or not exists or (canaccessvalue(dead) and dead) then
        if rec then rec:Hide() end
        return
    end
    local total, count, list = D.API.GetRemainingDamage(unit)
    if not count or count == 0 then
        if rec then rec:Hide() end
        return
    end
    if not rec then
        local f = _G[info.frame]
        if not (f and f.Health) then return end
        rec = ns.DotMarker.New(f, f.Health, 8)
        own[unit] = rec
    end
    local f = rec.host
    local level = f:GetFrameLevel()
    local portrait = f.Portrait and f.Portrait:IsShown() and f.Portrait or nil
    if portrait then
        rec:Place(level + 3, level + 12, portrait, "CENTER", portrait:GetWidth() * KILL_ON_PORTRAIT * look.iconSize)
    else
        local side = f.Health:GetReverseFill() and "LEFT" or "RIGHT"
        rec:Place(level + 3, level + 12, f.Health, side, f.Health:GetHeight() * KILL_ON_BAR * look.iconSize)
    end
    -- The ring styles: the portrait ring lies over the bar's first pixels on its side. Where the health
    -- starts on that side (the target frame's mirrored bar), a small mark would be all under the ring:
    -- that stretch of it is drawn again over the ring.
    local Ring = ns.UFRing
    local startSide = f.Health:GetReverseFill() and "RIGHT" or "LEFT"
    if not look.atHealth and Ring and Ring.Applies and Ring.Applies(f) and Ring.Side(f) == startSide then
        rec:SetCap(level + 11, Ring.TextPad(f))
    else
        rec:SetCap(nil)
    end
    look.shielded = D.Shielded(unit)
    rec:Draw(unit, list, total, look)
    if flash then rec:Flash() end
end

-- /fui dots: the own tracker's mark on a frame, in words
function DIE.Describe(unit)
    local info = UNITS[unit]
    local f = info and _G[info.frame]
    if not f then return "no frame " .. tostring(info and info.frame) end
    local rec = own[unit]
    if not rec then return ("frame %s shown %s, health bar %s, no mark made yet"):format(info.frame, tostring(f:IsShown()), tostring(f.Health ~= nil)) end
    local gauge = rec.gauges[1]
    return ("frame shown %s (level %s), mark shown %s (level %s), pieces %s, first piece shown %s, icon shown %s, health bar level %s, width %s, bar starts %s, over the ring %s"):format(
        tostring(f:IsVisible()), tostring(f:GetFrameLevel()), tostring(rec.art:IsVisible()), tostring(rec.art:GetFrameLevel()),
        tostring(#rec.gauges), tostring(gauge and gauge:IsVisible()), tostring(rec.window:IsVisible()),
        tostring(f.Health:GetFrameLevel()), tostring(f.Health:GetWidth()),
        f.Health:GetReverseFill() and "right" or "left", tostring(rec.capWidth))
end

local function Update(unit)
    local info = UNITS[unit]
    if not info then return end
    if ns.Dots and ns.Dots.Active() then return UpdateOwn(unit) end
    local rec = records[unit]
    local api, db, plus = Source()
    if not api then return HideRecord(rec) end
    local custom = type(db) == "table" and db[info.customBar]
    if plus then
        local settings = _G.UsefulPlatesAndTooltipsDB
        local paths = type(settings) == "table" and settings.frames
        custom = type(paths) == "table" and paths[unit]
    end
    local handOver = HasCustomBar(custom)
    local off = handOver or (unit == "focus" and type(db) == "table" and db.focusMode == "off")
    if off or ns.EditPreviewing() then return HideRecord(rec) end

    local exists, dead = UnitExists(unit), UnitIsDead(unit)
    if not canaccessvalue(exists) or not exists or (canaccessvalue(dead) and dead) then return HideRecord(rec) end
    local damage, count = api.GetRemainingDamage(unit)
    if not count or count == 0 then return HideRecord(rec) end

    if not rec then
        local f = _G[info.frame]
        if not (f and f.Health) then return end
        rec = Build(f)
        records[unit] = rec
    end
    local direction = plus and type(db) == "table" and db[unit == "target" and "fillDirection" or "plateFillDirection"]
    FollowFill(rec, direction)
    PlaceSkull(rec)
    local showMark = not (type(db) == "table" and db.showMarkers == false)
    local showSkull = not (type(db) == "table" and db.showSkull == false)
    if plus and type(db) == "table" then
        if unit == "target" then
            showMark = showMark and db.targetMarkers ~= false
        else
            -- In Plus, the focus icon belongs to its marker mode; showSkull is target-only.
            showSkull = showMark and db.focusMode == "markerIcon"
        end
    end
    -- (secret numbers go into the bars unread)
    local ok = pcall(rec.mark.SetMinMaxValues, rec.mark, 0, UnitHealthMax(unit))
        and pcall(rec.mark.SetValue, rec.mark, damage)
        and pcall(rec.killBar.SetMinMaxValues, rec.killBar, 0, UnitHealth(unit))
        and pcall(rec.killBar.SetValue, rec.killBar, damage)
    if not ok then return HideRecord(rec) end
    rec.mark:SetShown(showMark)
    rec.window:SetShown(showSkull)
end

function DIE:Refresh()
    for unit in pairs(UNITS) do Update(unit) end
end

local EVENT_UNITS = { PLAYER_TARGET_CHANGED = "target", PLAYER_FOCUS_CHANGED = "focus" }

-- Once a tracker is there: DoesItDie or DoesItDiePlus at login, or FlareUI's own as its module starts
local loader = CreateFrame("Frame")
function DIE:Attach()
    if self.attached then return end
    if ns.Dots and ns.Dots.Active() then
        ns.Dots.API.RegisterCallback("frames", function(_, unit, flash)
            if unit then
                UpdateOwn(unit, flash)
            else
                for each in pairs(UNITS) do UpdateOwn(each) end
            end
        end)
    else
        local api = Source()
        if not api then return end
        api.RegisterCallback("FlareUI", function(_, unit) Update(unit) end)
    end
    self.attached = true
    loader:RegisterEvent("PLAYER_ENTERING_WORLD")
    loader:RegisterEvent("PLAYER_TARGET_CHANGED")
    loader:RegisterEvent("PLAYER_FOCUS_CHANGED")
    loader:RegisterUnitEvent("UNIT_HEALTH", "target", "focus")
    loader:RegisterUnitEvent("UNIT_MAXHEALTH", "target", "focus")
    LEM:RegisterCallback("enter", function() DIE:Refresh() end)
    LEM:RegisterCallback("exit", function() DIE:Refresh() end)
    ns.OnEditFight(function() DIE:Refresh() end)
    DIE:Refresh()
end

loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event, arg)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        DIE:Attach()
    elseif event == "PLAYER_ENTERING_WORLD" then
        DIE:Refresh()
    else
        Update(EVENT_UNITS[event] or arg)
    end
end)
