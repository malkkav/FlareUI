local _, ns = ...

--------------------------------------------------
-- NAMEPLATE EXTRAS
-- The parts of the Nameplates module that came out of Quality of Life (11-23, Malkkav: nothing in
-- Quality of Life may decide what plates show): the In Combat choice of Show Enemy Plates and Show
-- Friendly Plates, and the combo points under your target's plate.
--------------------------------------------------
local NP = ns.Nameplates
if not NP then return end

local ipairs, type = ipairs, type
local math_min = math.min
local CreateFrame, InCombatLockdown = CreateFrame, InCombatLockdown
local GetCVar, GetCVarBool, SetCVar = GetCVar, GetCVarBool, SetCVar
local canaccessvalue = canaccessvalue

local function DB() return ns.db and ns.db.profile and ns.db.profile.nameplates end

--------------------------------------------------
-- 1. IN COMBAT PLATES
-- Show Enemy Plates and Show Friendly Plates on In Combat (nameplates.enemyInCombat / friendlyInCombat):
-- shown when a fight starts, hidden after. They are Blizzard's own switches, so this runs with the module
-- off too (the Visibility tab works then). The player's own value is kept (Tweaks.ForcedCVars, the
-- shared memory of every game setting FlareUI holds) and put back when another choice is picked.
--------------------------------------------------
local function Forced(key) return ns.Tweaks.ForcedCVars(key) end

local function SetEnemyPlates(on)
    pcall(SetCVar, "nameplateShowEnemies", on and 1 or 0)
end

-- Forever has no master switch for friendly plates (no nameplateShowFriends, 11-21): only the three
-- type switches, so those are held at 0 out of combat and the player's picks are kept as a 3-character
-- string ("101" = players on, NPCs off, minions on)
NP.FRIENDLY_CVARS = { "nameplateShowFriendlyPlayers", "nameplateShowFriendlyNpcs", "nameplateShowFriendlyPlayerMinions" }

-- 1-3 for a friendly type switch (CVAR_UPDATE may send the name in lower case), else nil
function NP.FriendlyIndex(name)
    if type(name) ~= "string" then return nil end
    name = name:lower()
    for i, cvar in ipairs(NP.FRIENDLY_CVARS) do if cvar:lower() == name then return i end end
end

function NP.FriendlyPicks()
    local picks = ""
    for _, cvar in ipairs(NP.FRIENDLY_CVARS) do picks = picks .. (GetCVarBool(cvar) and "1" or "0") end
    return picks
end

function NP.SetFriendlyPicks(picks)
    for i, cvar in ipairs(NP.FRIENDLY_CVARS) do pcall(SetCVar, cvar, picks:sub(i, i) == "1" and "1" or "0") end
end

-- the held picks while In Combat holds the switches, else nil (a 1-character value is the old
-- master-switch memory, from before 11-21: that CVar never existed, so it is dropped)
function NP.FriendlyHeld()
    local forced = Forced("combatFriendly")
    local held = forced.combatFriendly
    if held ~= nil and not (type(held) == "string" and held:match("^[01][01][01]$")) then
        forced.combatFriendly = nil
        return nil
    end
    return held
end

function NP.ApplyCombatShow()
    if InCombatLockdown() then return end
    local db, forced = DB(), Forced("combatPlates")
    if db and db.enemyInCombat then
        if forced.combatPlates == nil then forced.combatPlates = GetCVar("nameplateShowEnemies") or "1" end
        SetEnemyPlates(false)
    elseif forced.combatPlates ~= nil then
        pcall(SetCVar, "nameplateShowEnemies", forced.combatPlates)
        forced.combatPlates = nil
    end
    forced = Forced("combatFriendly")
    local held = NP.FriendlyHeld()
    if db and db.friendlyInCombat then
        -- nothing picked: friendly players, what the option is about
        if not held then
            held = NP.FriendlyPicks()
            forced.combatFriendly = held == "000" and "100" or held
        end
        NP.SetFriendlyPicks("000")
    elseif held then
        NP.SetFriendlyPicks(held)
        forced.combatFriendly = nil
    end
end

local function OnCombat(_, event)
    if event ~= "PLAYER_REGEN_DISABLED" then NP.ApplyCombatShow() return end
    -- still allowed: combat lockdown begins right after this event
    local db = DB()
    if db and db.enemyInCombat then SetEnemyPlates(true) end
    local held = db and db.friendlyInCombat and NP.FriendlyHeld()
    if held then NP.SetFriendlyPicks(held) end
end

--------------------------------------------------
-- 2. COMBO POINTS
-- Combo points (Core.lua: Blizzard's points, or FlareUI's gem while the count is secret) under the
-- target's FlareUI plate. A readable count hides the row at zero.
--------------------------------------------------
local SIZE     = 14   -- the point's side
local SPACING  = ns.ComboPointStep(SIZE)   -- Blizzard's art never touches its neighbour
local OFFSET_Y = -5   -- below the plate, clear of the aggro glow (negative = down)
local SCALE    = 1.1  -- on top of the nameplate's own scale
local MAX      = 10
local FALLBACK = 5

local row, events

local function Layout(count)
    for i = 1, count do
        local gem = row.gems[i]
        if not gem then
            gem = ns.CreateComboPoint(row, i, SIZE)
            row.gems[i] = gem
        end
        gem:ClearAllPoints()
        gem:SetPoint("TOPLEFT", row, "TOPLEFT", (i - 1) * SPACING, 0)
        gem:Show()
    end
    for i = count + 1, #row.gems do row.gems[i]:Hide() end
    row:SetSize((count - 1) * SPACING + SIZE, SIZE)
    row.count = count
end

-- Rogues, and druids in cat form, on a hostile target
local function PlayerBuildsComboPoints()
    local _, class = UnitClass("player")
    if not canaccessvalue(class) or (class ~= "ROGUE" and class ~= "DRUID") then return false end
    if class == "DRUID" then
        local powerType = UnitPowerType("player")
        if not (canaccessvalue(powerType) and powerType == Enum.PowerType.Energy) then return false end
    end
    local hostile = UnitCanAttack("player", "target")
    return canaccessvalue(hostile) and hostile or false
end

local function UpdateCombo(_, event, _, powerToken)
    if not row then return end
    -- energy ticks are not combo point changes
    if event == "UNIT_POWER_FREQUENT" and canaccessvalue(powerToken) and powerToken ~= "COMBO_POINTS" then return end
    local plate = C_NamePlate.GetNamePlateForUnit("target")
    local p = plate and NP.PartsFor(plate)
    local points = GetComboPoints("player", "target")
    -- the points the shine compares against: none known after a target change or while secret
    local last = row.lastPoints
    if event == "PLAYER_TARGET_CHANGED" then last = nil end
    row.lastPoints = canaccessvalue(points) and points or nil
    -- (the target's unit type may have Combo Points off)
    local show = p and PlayerBuildsComboPoints() and NP.ComboAllowed("target")
    if show and canaccessvalue(points) and points == 0 then show = false end
    if not show then
        row:Hide()
        return
    end

    local max = UnitPowerMax("player", Enum.PowerType.ComboPoints)
    if not (canaccessvalue(max) and max and max >= 1) then max = FALLBACK end
    max = math_min(max, MAX)
    if row.count ~= max then Layout(max) end

    if row:GetParent() ~= plate or not row:IsShown() then
        -- centred under the plate, below its cast bar while one shows (NP.PlaceBelow)
        local anchor = p.below or p.box
        row:SetParent(plate)
        row:ClearAllPoints()
        row:SetPoint("TOP", anchor, "BOTTOM", 0, OFFSET_Y)
        row:SetFrameLevel(anchor:GetFrameLevel() + 5)
    end
    -- Blizzard's points (Core.lua), animated except right after a target change
    for i = 1, max do ns.SetComboPoint(row.gems[i], points, last ~= nil) end
    row:Show()
end

-- Switched on and off live from the options (Nameplates.lua NP:Init and NP:Refresh)
function NP.ApplyCombo()
    local db = DB()
    if not (NP.ready and not NP.standDown and db and db.comboPoints) then
        if events then events:UnregisterAllEvents() end
        if row then row:Hide() end
        return
    end
    if not row then
        row = CreateFrame("Frame", nil, UIParent)
        row.gems = {}
        row:SetScale(SCALE)
        row:Hide()
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", UpdateCombo)
    end
    for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED" }) do
        events:RegisterEvent(event)
    end
    -- combo points arrive as the player's power; UNIT_FACTION catches a target turning hostile
    for _, event in ipairs({ "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }) do
        events:RegisterUnitEvent(event, "player")
    end
    events:RegisterUnitEvent("UNIT_FACTION", "target")
    UpdateCombo()
end

-- The module took a plate or gave it back: the points follow (they may have been placed before the
-- module's own handler ran)
function NP.ComboPlateChanged()
    local db = DB()
    if not (row and db and db.comboPoints) then return end
    row:Hide()
    UpdateCombo()
end

--------------------------------------------------
-- 3. MODULE
-- Always started (In Combat plates work with the Nameplates module off); it has no switch of its own.
--------------------------------------------------
local Extras = {}
ns.modules["NameplateExtras"] = Extras

function Extras:ProfileChanged()
    NP.MigrateProfile()
    NP.ApplyCombatShow()
    NP.ApplyCombo()
end

function Extras:Init()
    if self.initialized then return end
    self.initialized = true
    NP.MigrateProfile()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", OnCombat)
    if ns.db.RegisterCallback then
        for _, event in ipairs({ "OnProfileChanged", "OnProfileCopied", "OnProfileReset" }) do
            ns.db.RegisterCallback(self, event, "ProfileChanged")
        end
    end
    NP.ApplyCombatShow()
end
