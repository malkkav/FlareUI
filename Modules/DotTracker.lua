local _, ns = ...

--------------------------------------------------
-- DOT TRACKER (DoT Tracker page, off)
-- FlareUI's own "does it die": how much damage your DoTs still have to deal to a unit, and whether
-- that finishes it off, with no other addon. The tracking is Does It Die Advanced's (Modules/DotEngine,
-- MIT); this file starts it, hands it FlareUI's settings and answers the drawing: the target and focus
-- frames (UnitFramesDoesItDie.lua), the nameplates (NameplateDots.lua), both through DotMarker.lua.
-- With DoesItDie, DoesItDiePlus or Does It Die Advanced loaded it stands down: one tracker at a time
-- (FlareUI already draws the first two's estimate on its frames).
-- Learned tick sizes are the character's (ns.CharDB().dots); the look is the profile's (profile.dots).
--------------------------------------------------
local D = {}
ns.Dots = D
ns.modules["Dots"] = D

local E = ns.DotEngine
local pairs, type = pairs, type
local math_floor = math.floor

local function Db()
    return ns.db and ns.db.profile and ns.db.profile.dots
end
D.Db = Db

-- Another tracker loaded: its name, for the settings page's note
function D.OtherAddon()
    if _G.DoesItDie then return "DoesItDie" end
    if _G.UsefulPlatesAndTooltips_API then return "DoesItDiePlus" end
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if loaded and loaded("DoesItDieAdvanced") then return "Does It Die Advanced" end
    return nil
end

function D.Active() return D.running == true end

--------------------------------------------------
-- 1. WHAT THE DRAWING READS
--------------------------------------------------
local listeners = {}

-- owner, fn(owner, unit, flash): unit nil = everything may have changed (ten times a second while
-- running); flash: a DoT just landed on that unit
-- (one place failing must not stop the others: its error is kept for /fui dots and shown once)
local function Fire(unit, flash)
    for owner, fn in pairs(listeners) do
        local ok, err = pcall(fn, owner, unit, flash)
        if not ok then
            D.errors = D.errors or {}
            if not D.errors[owner] then
                D.errors[owner] = tostring(err)
                if ns.LogError then ns.LogError("DoT Tracker " .. tostring(owner), err) end
            end
        end
    end
end

D.API = {
    -- the damage the player's DoTs still have to deal to the unit, how many DoTs, and each of them
    -- ({ name, school, damage, appliedAt }, oldest first)
    GetRemainingDamage = function(unit)
        if not D.running then return 0, 0, {} end
        local list, total = E.dotBreakdownForUnit(unit)
        return math_floor(total + 0.5), #list, list
    end,
    RegisterCallback = function(owner, fn) listeners[owner] = fn end,
}

-- a shield or an immunity soaks the damage first: no kill icon while one is up
function D.Shielded(unit)
    if not E.shielded then return false end
    local ok, shielded = pcall(E.shielded, unit)
    return ok and shielded or false
end

-- The marker's look for a place ("target", "focus", "plates"), or nil when that place is off
function D.Look(place)
    local db = Db()
    if not (db and D.running) then return nil end
    local on = db[place]
    if not on or on == "off" then return nil end
    local icon = db.icon or "skull"
    if place == "plates" and on ~= "icon" then icon = "off" end
    D.look = D.look or {}
    local look = D.look
    look.marker = db.marker ~= false
    look.each = db.colors ~= "single"
    look.opacity = (tonumber(db.opacity) or 55) / 100
    look.smooth = db.smooth ~= false
    look.atHealth = db.position ~= "start"   -- Mark Position: back from the health's end, or from the bar's start
    look.icon = icon
    look.pulse = db.pulse ~= false
    look.iconSize = (tonumber(db.iconSize) or 100) / 100
    look.shielded = false
    return look
end

--------------------------------------------------
-- 2. SETUP
--------------------------------------------------
-- the accuracy options live in the engine's own saved table (it reads them there)
local function Sync()
    local db, saved = Db(), D.saved
    if not (db and saved) then return end
    saved.waitFirstTick = db.waitFirstTick or "off"
    saved.estimateDuringCast = db.estimateDuringCast ~= false
    saved.trackChannels = db.trackChannels ~= false
end

function D:Refresh()
    if not D.running then return end
    Sync()
    Fire(nil)
end

-- Reset Learned Ticks: the tick sizes go back to what the tooltips say
function D:ResetLearned()
    if D.running and E.resetLearnedTicks then E.resetLearnedTicks() end
end

-- A line in the tracker's log each time the target's estimate changes: which DoTs count and for how much.
-- With the casts, ticks and drops the engine notes itself, a fight can be read back afterwards.
function D.Note()
    if not (D.running and E.trace) then return end
    local total, count, list = D.API.GetRemainingDamage("target")
    local parts = {}
    for i, entry in ipairs(list) do
        parts[i] = ("%s %d%s"):format(tostring(entry.name), math_floor((entry.damage or 0) + 0.5), entry.provisional and " (casting)" or "")
    end
    local line = ("ESTIMATE target %d from %d DoT(s): %s"):format(total, count, table.concat(parts, ", "))
    if line == D.lastNote then return end
    D.lastNote = line
    E.trace(line)
end

-- /fui dots: what the tracker sees right now, for "the mark doesn't show" reports
function D.Report()
    local function say(text) print("|cffb39ddbFlareUI|r " .. text) end
    local db = Db()
    say(("DoT Tracker: enabled %s, running %s, other addon %s"):format(tostring(db and db.enabled), tostring(D.running), tostring(D.OtherAddon())))
    if not D.running then return end
    for owner in pairs(listeners) do
        say(("  drawing '%s': %s"):format(owner, D.errors and D.errors[owner] and ("ERROR " .. D.errors[owner]) or "ok"))
    end
    for _, unit in ipairs({ "target", "focus" }) do
        local exists = UnitExists(unit)
        local ok, total, count, list = pcall(D.API.GetRemainingDamage, unit)
        say(("  %s: exists %s, shown in settings %s, DoTs %s, damage %s"):format(unit, tostring(exists),
            tostring(D.Look(unit) ~= nil), tostring(ok and count), tostring(ok and total or total)))
        -- each DoT counted, so "the kill icon ignores one of them" can be told from "one was never counted"
        if ok and type(list) == "table" then
            for _, entry in ipairs(list) do
                say(("    %s: %d%s"):format(tostring(entry.name), math_floor((entry.damage or 0) + 0.5), entry.provisional and " (being cast)" or ""))
            end
        end
        if ns.UFDoesItDie and ns.UFDoesItDie.Describe then say("    " .. ns.UFDoesItDie.Describe(unit)) end
    end
    -- the tracker's own notes on its last moves (casts, ticks matched, DoTs dropped)
    local log = D.saved and D.saved.log
    if type(log) == "table" and #log > 0 then
        say("  last notes:")
        for i = math.max(1, #log - 13), #log do say("    " .. tostring(log[i])) end
    end
end

function D:ShouldLoad()
    local db = Db()
    return db and db.enabled or false
end

function D:Init()
    if D.running or not E or D.OtherAddon() then return end
    local char = ns.CharDB()
    if type(char.dots) ~= "table" then char.dots = {} end
    D.saved = char.dots
    Sync()
    E.display.schoolColors = ns.DotMarker.SCHOOL_COLORS
    E.refresh = function()
        D.Note()
        Fire(nil)
    end
    E.playFlash = function() Fire("target", true) end
    E.start(D.saved)
    D.running = E.isStarted()
    if not D.running then return end
    if ns.UFDoesItDie and ns.UFDoesItDie.Attach then ns.UFDoesItDie:Attach() end
    if ns.NameplateDots then ns.NameplateDots:Start() end
end
