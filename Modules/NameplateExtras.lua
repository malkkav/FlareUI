local _, ns = ...

--------------------------------------------------
-- NAMEPLATE EXTRAS
-- The parts of the Nameplates module that came out of Quality of Life (nothing in
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

-- Forever has no master switch for friendly plates (no nameplateShowFriends): only the three
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
-- master-switch memory of older versions: that CVar never existed, so it is dropped)
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
-- target's plate. A readable count hides the row at zero.
-- FlareUI's plates: the Nameplates page's Combo Points. Blizzard's plates (the Nameplates module off):
-- always, with no option (Malkkav 11-26; was Quality of Life's Nameplate Combo Points, tweaks.plateCombo)
--------------------------------------------------
local SIZE     = 14   -- the point's side
local SPACING  = ns.ComboPointStep(SIZE)   -- Blizzard's art never touches its neighbour
local OFFSET_Y = -5   -- below the plate, clear of the aggro glow (negative = down)
local SCALE    = 1.1  -- on top of the nameplate's own scale
local MAX      = 10
local FALLBACK = 5

local row, events

-- the points keep their share of the plate: as much bigger or smaller as the plate is wider or narrower than
-- the default one
NP.COMBO_WIDTH = 150   -- (enemies' own default: Nameplates.lua C.ENEMY_BASE)
function NP.ComboScale(width)
    if type(width) ~= "number" then return 1 end
    return math.max(0.6, math_min(2, width / NP.COMBO_WIDTH))
end

-- "flare", "blizzard" or nil: whose plates carry the points
function NP.ComboMode()
    local db = DB()
    if NP.ready and not NP.standDown then return db and db.comboPoints and "flare" or nil end
    if db and db.enabled then return nil end
    if NP.OtherAddon and NP.OtherAddon() then return nil end
    return "blizzard"
end

-- Under Blizzard's plate: below its cast bar's slot, which stays under the health bar whether the unit casts
-- or not, so the points never jump; else the health bar
function NP.BlizzardComboAnchor(plate)
    local unitFrame = plate.UnitFrame
    if not unitFrame or unitFrame:IsForbidden() then return nil end
    local casts = unitFrame.CastBarsContainer
    if casts and not casts:IsForbidden() then return casts end
    local bar = unitFrame.HealthBarsContainer and unitFrame.HealthBarsContainer.healthBar
    if bar and not bar:IsForbidden() then return bar end
end

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
    local mode = NP.ComboMode()
    local p = plate and mode == "flare" and NP.PartsFor(plate)
    local anchor = p and (p.below or p.box) or (plate and mode == "blizzard" and NP.BlizzardComboAnchor(plate)) or nil
    local points = GetComboPoints("player", "target")
    -- the points the shine compares against: none known after a target change or while secret
    local last = row.lastPoints
    if event == "PLAYER_TARGET_CHANGED" then last = nil end
    row.lastPoints = canaccessvalue(points) and points or nil
    -- (the target's unit type may have Combo Points off)
    local show = anchor and PlayerBuildsComboPoints() and (mode == "blizzard" or NP.ComboAllowed("target"))
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
        row:SetParent(plate)
        row:ClearAllPoints()
        row:SetPoint("TOP", anchor, "BOTTOM", 0, OFFSET_Y)
        row:SetFrameLevel(anchor:GetFrameLevel() + 5)
    end
    local tdb = p and p.kind and NP.TypeDB and NP.TypeDB(p.kind, true)
    local scale = SCALE * NP.ComboScale(tdb and tdb.width)
    if row.scaleNow ~= scale then
        row.scaleNow = scale
        row:SetScale(scale)
    end
    -- Blizzard's points (Core.lua), animated except right after a target change
    for i = 1, max do ns.SetComboPoint(row.gems[i], points, last ~= nil) end
    row:Show()
end

-- Switched on and off live from the options (Nameplates.lua NP:Init and NP:Refresh)
function NP.ApplyCombo()
    if not NP.ComboMode() then
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
    if not (row and NP.ComboMode()) then return end
    row:Hide()
    UpdateCombo()
end

--------------------------------------------------
-- 3. SMOOTH ANIMATED BARS
-- Its liquid on our plates' health, as on the unit frames (UnitFrames.lua ns.SAB). No option of ours: its own
-- Nameplates switches decide (enemy and friendly plates, off by default there), with its Other Addons' Bars on and
-- as many plates as it takes itself. Its settings are only read (it has no function for these two).
-- Its AddBar takes no nameplate token, so a bar is handed over with no unit ("none": it follows the bar's own
-- value and colour), or as "target" on your target's plate, which gets its DoT marker there when it is on for
-- nameplates. Colours (linowena): a theme picked for its nameplates is asked for (options.theme); Same as Target and
-- Game Colour keep ours. With its Your Colours on Their Bars it ignores that and paints every plate as the target
-- frame (Game Colour: plain green), so there it gets the plates only with real themes for both.
-- A plate's size can't be read under addon restrictions, and it reads a bar's size when it is first added: so that
-- happens before the plate goes on the unit (Prepare), and a size it can't know keeps our own fill.
--------------------------------------------------
local Sab = { LEVEL = 1, MAX = { enemy = 15, friend = 10 } }
NP.Sab = Sab

-- the settings it uses now: account-wide, or this character's own
function Sab.Settings()
    local root = _G.SmoothAnimatedBarsDB
    if type(root) ~= "table" then return nil end
    if type(root.ownSettings) == "table" and type(root.profiles) == "table" then
        local name, surname = UnitName("player")
        if type(name) == "string" then
            local start = name .. ((type(surname) == "string" and surname ~= "") and (" " .. surname) or "") .. " - "
            for key, own in pairs(root.ownSettings) do
                if own == true and type(key) == "string" and key:sub(1, #start) == start and type(root.profiles[key]) == "table" then
                    return root.profiles[key]
                end
            end
        end
    end
    return type(root.global) == "table" and root.global or nil
end

-- a theme that is a colour of its own: not Game Colour, nor Class Color (it needs the unit, which it isn't given)
function Sab.Real(choice)
    if type(choice) ~= "string" or choice == "game" or choice == "class" or choice == "same" then return false end
    if not Sab.themes then
        local ok, themes = pcall(_G.SmoothAnimatedBars.GetThemes)
        if not ok or type(themes) ~= "table" then return false end
        Sab.themes = themes
    end
    return tContains(Sab.themes, choice) and true or false
end

-- its colour for a frame, "same" followed as it does
Sab.COLORS = { friend = { "plateFriendlyColor", "enemy" }, enemy = { "plateHealthColor", "target" },
               target = { "targetHealthColor", "player" }, player = { "healthColor" } }
function Sab.Choice(s, frame)
    local entry = Sab.COLORS[frame]
    local choice = s[entry[1]]
    if choice == "same" and entry[2] then return Sab.Choice(s, entry[2]) end
    return choice
end

-- the theme to ask for on a plate of this side (nil: the bar's own colour)
function Sab.Theme(s, side)
    if s.externalColors == true then return nil end
    local choice = s[Sab.COLORS[side][1]]
    if side == "friend" and choice == "same" then choice = s.plateHealthColor end
    return Sab.Real(choice) and choice or nil
end

-- with Your Colours on Their Bars: whether what it would paint is what the player picked for plates
function Sab.Painted(s, side)
    return s.externalColors ~= true or (Sab.Real(Sab.Choice(s, side)) and Sab.Real(Sab.Choice(s, "target")))
end

-- "enemy" or "friend" (which of its switches the plate is under), or nil: not wanted
function Sab.Side(p, unit)
    local api = _G.SmoothAnimatedBars
    if type(api) ~= "table" or not unit or p.nameOnly or p.hiddenPlate or p.unitHidden then return nil end
    local ok, on = pcall(api.IsEnabled)
    local s = ok and on and Sab.Settings()
    if not s or not (s.plateHealth == true or s.plateFriendly == true) then return nil end
    if p.tdb and (p.tdb.height or 0) < ns.SAB.MIN_HEIGHT then return nil end
    local okA, attack = pcall(UnitCanAttack, "player", unit)
    if not okA or not canaccessvalue(attack) then return nil end
    local side = attack and (s.plateHealth == true and "enemy") or not attack and (s.plateFriendly == true and "friend") or nil
    return side and Sab.Painted(s, side) and side or nil
end

local function SizeKnown(p)
    local ok, w = pcall(p.health.GetWidth, p.health)
    return ok and canaccessvalue(w) and type(w) == "number" and w > 1
end

-- the liquid is drawn over our bar, so our tints on the fill, the mouse's light and the Execute mark move over it
local function Own(p, on)
    if (p.sab or false) == on then return end
    p.sab = on
    ns.SAB.owned[p.health] = on or nil
    ns.SAB.TrailChanged(p.trail, on)
    if ns.UnitFrames and ns.UnitFrames.BarLookOwnerChanged then ns.UnitFrames.BarLookOwnerChanged(p.health) end
    if on and not p.sabTop then
        p.sabTop = CreateFrame("Frame", nil, p.health)
        p.sabTop:SetAllPoints(p.health)
        p.sabTop:SetFrameLevel(p.health:GetFrameLevel() + Sab.LEVEL + 2)   -- (+1: the liquid over its DoT marker)
    end
    local parent = on and p.sabTop or p.health
    for _, t in ipairs({ p.execTint, p.targetTint, p.highlight, p.execMark }) do t:SetParent(parent) end
end

-- token: "none" or "target". False: declined.
local function Add(p, token, theme)
    local api = _G.SmoothAnimatedBars
    local ok, taken = pcall(api.AddBar, p.health, token, "health", { name = "FlareUI", level = Sab.LEVEL, theme = theme })
    if not (ok and taken) then
        pcall(api.RemoveBar, p.health)
        p.sabUnit = nil
        Own(p, false)
        return false
    end
    p.sabUnit, p.sabTheme, p.sabMade = token, theme, true
    Own(p, true)
    return true
end

-- A plate about to go on a unit for the first time with the liquid: added where its size can be read
function Sab.Prepare(p, unit)
    local side = not p.sabMade and Sab.Side(p, unit)
    if not side then return end
    p.root:ClearAllPoints()
    p.root:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    if SizeKnown(p) and Add(p, "none", Sab.Theme(Sab.Settings(), side)) then p.sabSize = p.plateW .. "x" .. p.boxH end
    p.root:ClearAllPoints()
end

-- A held plate: at the claim, with every target change (NP.UpdateTarget) and in the sync
function Sab.Apply(p)
    local side = p.unit and Sab.Side(p, p.unit)
    local held, size = 0, side and (p.plateW .. "x" .. p.boxH)
    if side then
        if SizeKnown(p) then p.sabSize = size elseif p.sabSize ~= size then side = nil end
    end
    if side then
        for _, other in pairs(NP.HeldPlates()) do
            if other ~= p and other.sab and other.sabSide == side then held = held + 1 end
        end
        if held >= Sab.MAX[side] then side = nil end
    end
    p.sabSide = side
    if not side then
        if p.sab then
            pcall(_G.SmoothAnimatedBars.RemoveBar, p.health)
            p.sabUnit = nil
            Own(p, false)
        end
        return
    end
    local s = Sab.Settings()
    local token = (p.targetShown and side == "enemy" and s and s.plateDots == true) and "target" or "none"
    local theme = s and Sab.Theme(s, side)
    if p.sab and p.sabUnit == token and p.sabTheme == theme then return end
    Add(p, token, theme)
end

function Sab.ApplyAll()
    local api = _G.SmoothAnimatedBars
    if type(api) ~= "table" then return end
    if not Sab.hooked then
        Sab.hooked = true
        pcall(api.RegisterCallback, function(event) if event == "enabled" then Sab.ApplyAll() end end)
    end
    for _, p in pairs(NP.HeldPlates()) do pcall(Sab.Apply, p) end
end

--------------------------------------------------
-- 4. MODULE
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
    NP.ApplyCombo()
end
