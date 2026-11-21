-- A standalone Lua process has no WoW frames, units, or AceEvent message bus.
-- Supply just enough of each to run the real renderer and companion module.
local H = dofile("tools/tests/perf-helpers.lua")
local function noop() end
local listeners = {}
local ace = {}
function ace:Embed(module)
    function module:RegisterMessage(event, listener)
        listeners[event] = listener
    end
    function module:SendMessage(event, ...)
        if listeners[event] then listeners[event](event, ...) end
    end
end
function LibStub() return ace end
function CreateFrame() return { Hide = noop, SetScript = noop } end
function UnitName(unit) return unit end
function UnitIsPlayer() return true end
function canaccessvalue() return true end
UnitClass = noop
IsInRaid = noop
UnitInParty = noop
C_ClassColor = { GetClassColor = noop }

local ns = { L = {}, modules = {} }
local function loadModule(path)
    local chunk = assert(loadstring(H.read(path), "@" .. path))
    chunk("FlareUI", ns)
end
loadModule("Modules/Nameplates.lua")
loadModule("Modules/NameplatesMusician.lua")
local plates = ns.Nameplates
function plates.LevelPrefix() return "60 " end
-- Seed the real active-plate table without building the login-time frame pool.
local key, active = debug.getupvalue(plates.PartsFor, 1)
assert(key == "byPlate")

local client = { draw = plates.UpdateName }
function client.newPlate(unit)
    local label = { SetTextColor = noop }
    function label:SetText(text) self.text = text end
    function label:SetFormattedText(format, ...) self.text = string.format(format, ...) end
    local frame = { Hide = noop, SetParent = noop, ClearAllPoints = noop, SetAlpha = noop }
    return { unit = unit, gamePlate = {}, nameSlot = "middle", levelFollow = true, tdb = {}, name = label,
        holder = frame, root = frame, highlight = frame, testGamePlate = { UnitFrame = frame } }
end

function client.claim(plate)
    plate.gamePlate = plate.testGamePlate
    plate.gamePlate.unitToken = plate.unit
    plate.blizz = plate.gamePlate.UnitFrame
    active[plate.gamePlate] = plate
    plates:SendMessage("FlareUINameplateClaimed", plate)
end

function client.release(plate)
    plates.ReleasePlate(plate)
end

function client.remove(plate)
    plates:OnEvent("NAME_PLATE_UNIT_REMOVED", plate.unit)
end

function client.enableMusician(plate)
    local musician = { showIcon = true }
    function musician.ClaimName(_, _, redraw)
        musician.redraw = redraw
        return function(live) musician.released = live end
    end
    function musician.GetNoteIconForUnit(unit)
        if musician.showIcon and unit == "Alice" then return "NOTE" end
    end
    Musician.NamePlates = musician
    plates.ready = true
    C_NamePlate = { GetNamePlates = function() return { plate.gamePlate } end }
    listeners.MusicianNamePlatesReady()
    return musician
end

return client
