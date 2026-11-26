local _, ns = ...

--------------------------------------------------
-- NAMEPLATE DOTS
-- FlareUI's own DoT tracker (DotTracker.lua) on nameplates: the mark on each plate's health bar and,
-- if asked, a small kill icon at its left (DoT Tracker > Nameplates). On FlareUI's plates it lies on
-- the bar Nameplates.lua lays over its health bar for this (NP.DieProxy); with FlareUI's plates off, on
-- Blizzard's own bar. Other nameplate addons' bars are left alone.
--------------------------------------------------
local NPD = {}
ns.NameplateDots = NPD

local pairs, pcall, type = pairs, pcall, type
local ICON_SHARE = 1.5      -- the kill icon, of the bar's height
local ICON_GAP = 2
local PIECES = 4

local shown = {}            -- unit -> true while it has a plate
local records = {}          -- health bar -> its marker

-- The bar to draw on, or nil: ours on a plate FlareUI drew, Blizzard's when FlareUI's plates are off.
-- Then the status bar whose fill is the unit's health (on our plates the first only marks its place).
local function BarOf(plate)
    local ok, bar, health = pcall(function()
        if plate:IsForbidden() then return nil end
        local proxy = plate.FlareUI_DieHealth
        if proxy then
            if not proxy:IsShown() then return nil end
            return proxy, proxy.fuiHealth
        end
        local NP = ns.Nameplates
        if NP and NP.ready and not NP.standDown then return nil end
        local unitFrame = plate.UnitFrame
        if not unitFrame or unitFrame:IsForbidden() then return nil end
        local health = unitFrame.healthBar or (unitFrame.HealthBarsContainer and unitFrame.HealthBarsContainer.healthBar)
        if health and health:IsVisible() then return health, health end
        return nil
    end)
    if ok then return bar, health end
    return nil
end

local function HideAll()
    for _, rec in pairs(records) do rec:Hide() end
end

local function Update(unit)
    local D = ns.Dots
    local look = D.Look("plates")
    local plate = look and C_NamePlate.GetNamePlateForUnit(unit) or nil
    local bar, health
    if plate then bar, health = BarOf(plate) end
    -- (a plate's bar can change hands: whatever else was drawn for this plate goes)
    if plate then
        for other, rec in pairs(records) do
            if rec.host == plate and other ~= bar then rec:Hide() end
        end
    end
    if not bar then return end
    local rec = records[bar]
    local dead = UnitIsDead(unit)
    if canaccessvalue and canaccessvalue(dead) and dead then
        if rec then rec:Hide() end
        return
    end
    local total, count, list = D.API.GetRemainingDamage(unit)
    if not count or count == 0 then
        if rec then rec:Hide() end
        return
    end
    if not rec then
        rec = ns.DotMarker.New(plate, bar, PIECES, health)
        records[bar] = rec
    end
    local level = bar:GetFrameLevel()
    local size = bar:GetHeight() * ICON_SHARE * look.iconSize
    rec:SetStrata(bar:GetFrameStrata())
    rec:Place(level + 1, level + 3, bar, "LEFT", size, -(size / 2 + ICON_GAP), 0)
    look.shielded = look.icon ~= "off" and D.Shielded(unit)
    -- (a plate whose health bar we don't know keeps the mark at the bar's start)
    local atHealth = look.atHealth
    if not health then look.atHealth = false end
    rec:Draw(unit, list, total, look)
    look.atHealth = atHealth
end

function NPD:Refresh()
    local D = ns.Dots
    if not (D and D.Active() and D.Look("plates")) then return HideAll() end
    for unit in pairs(shown) do
        local ok = pcall(Update, unit)
        if not ok then shown[unit] = nil end
    end
end

function NPD:Start()
    if self.started or not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
    self.started = true
    local events = CreateFrame("Frame")
    events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    events:SetScript("OnEvent", function(_, event, unit)
        if type(unit) ~= "string" or (canaccessvalue and not canaccessvalue(unit)) then return end
        if event == "NAME_PLATE_UNIT_ADDED" then
            shown[unit] = true
        else
            shown[unit] = nil
            -- the plate goes back to the pool: its marker with it
            local plate = C_NamePlate.GetNamePlateForUnit(unit)
            for _, rec in pairs(records) do
                if rec.host == plate then rec:Hide() end
            end
        end
    end)
    ns.Dots.API.RegisterCallback("plates", function() NPD:Refresh() end)
end
