local ADDON_NAME = ...

--------------------------------------------------
-- 1. LIBRARY
--------------------------------------------------
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
if not LSM then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000FlareUI Error:|r LibSharedMedia-3.0 not found!")
    return
end

-- forward slashes so the paths work on every platform
local MEDIA_PATH = "Interface/AddOns/" .. ADDON_NAME .. "/Media/"

--------------------------------------------------
-- 2. CUSTOM ASSETS (registered with LibSharedMedia)
--------------------------------------------------
local ASSETS = {
    -- FlareUI's bar textures: Flat for every bar, Striped for absorbs
    statusbar = {
        ["FlareUI Flat"]    = "Bars/FlareUI-Flat.tga",
        ["FlareUI Striped"] = "Bars/FlareUI-Striped.tga",
    },
    -- grey frame borders, tinted by each frame's border colour; 16 px edge
    border = {
        ["FlareUI Thick"]  = "Borders/FlareUI-Thick.tga",
        ["FlareUI Frames"] = "Borders/FlareUI-Frames.tga",
        -- Frames cut to 16 px pieces, drawn at an 8 px edge (ns.BorderEdgeSize)
        ["FlareUI Thin"]   = "Borders/FlareUI-Thin.tga",
    },
    font = {
        ["Asap Condensed"]   = "Fonts/AsapCondensed-Regular.ttf",
        ["Fira Condensed"]   = "Fonts/FiraSansExtraCondensed-Regular.ttf",
        ["Cabin Condensed"]  = "Fonts/CabinCondensed-Regular.ttf",
        ["Barlow Condensed"] = "Fonts/BarlowCondensed-Regular.ttf",
        ["Roboto Condensed"] = "Fonts/RobotoCondensed-Regular.ttf",
    },
}

for mediaType, entries in pairs(ASSETS) do
    for name, relativePath in pairs(entries) do
        local ok, err = pcall(LSM.Register, LSM, mediaType, name, MEDIA_PATH .. relativePath)
        if not ok then
            print(("|cffff0000FlareUI Media:|r could not register %s '%s': %s"):format(mediaType, name, tostring(err)))
        end
    end
end
