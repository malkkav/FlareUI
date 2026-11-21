local _, ns = ...
local plates = ns.Nameplates

-- Musician keeps its animated notes; the pooled FlareUI label draws the inline icon.
local function claim(_, plate)
    local api = _G.Musician and _G.Musician.NamePlates
    if plate.musicianRelease or not (api and api.ClaimName and api.GetNoteIconForUnit) then return end

    plate.musicianRelease = api.ClaimName(plate.gamePlate, plate.unit, function()
        plates.UpdateName(plate)
    end)
    plate.nameIconForUnit = api.GetNoteIconForUnit
    plates.UpdateName(plate)
end

plates:RegisterMessage("FlareUINameplateClaimed", claim)
plates:RegisterMessage("FlareUINameplateReleased", function(_, plate, live)
    local release = plate.musicianRelease
    if not release then return end
    plate.musicianRelease = nil
    plate.nameIconForUnit = nil
    release(live)
end)

-- Musician can become available after FlareUI has claimed visible plates.
plates:RegisterMessage("MusicianNamePlatesReady", function()
    if not plates.ready then return end
    for _, gamePlate in ipairs(C_NamePlate.GetNamePlates()) do
        local plate = plates.PartsFor(gamePlate)
        if plate then claim(nil, plate) end
    end
end)
