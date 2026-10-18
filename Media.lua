local ADDON_NAME, ns = ...

--------------------------------------------------
-- MEDIA
-- FlareUI's fonts, bar textures and borders, registered with LibSharedMedia.
--------------------------------------------------

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
    -- FlareUI's bar textures: Flat for every bar, Striped for absorbs, Forever: Blizzard's Forever
    -- health bar art (its gradient and grain), greyed so the bars' colours tint it
    statusbar = {
        ["FlareUI Flat"]    = "Bars/FlareUI-Flat.tga",
        ["FlareUI Striped"] = "Bars/FlareUI-Striped.tga",
        ["FlareUI Forever"] = "Bars/FlareUI-Forever.tga",
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

-- LibSharedMedia's own bar textures (it adds them in every addon's copy, and they can't be taken
-- out): FlareUI's dropdowns leave them out. A frame already set to one keeps it.
-- LibSharedMedia's own border list (the game's art and None), hidden the same way; the chat, damage
-- meter and quest tracker keep None as their own first choice
ns.HIDDEN_BORDERS = {
    ["None"] = true, ["Blizzard Achievement Wood"] = true, ["Blizzard Chat Bubble"] = true, ["Blizzard Dialog"] = true,
    ["Blizzard Dialog Gold"] = true, ["Blizzard Party"] = true, ["Blizzard Tooltip"] = true,
}

-- What a media dropdown offers: FlareUI's own (base, in that order), then a divider and every bar or
-- border other addons registered with LibSharedMedia, A-Z. LibSharedMedia's own Blizzard entries
-- and FlareUI's other media stay out. Returns the names after the divider.
function ns.AddonMedia(mediaType)
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local hidden = (mediaType == "border" and ns.HIDDEN_BORDERS) or (mediaType == "statusbar" and ns.HIDDEN_STATUSBARS) or {}
    local list = {}
    for _, name in ipairs(LSM and LSM:List(mediaType) or {}) do
        if not hidden[name] and not name:find("^FlareUI ") then list[#list + 1] = name end
    end
    table.sort(list, function(a, b) return a:lower() < b:lower() end)
    return list
end

ns.HIDDEN_STATUSBARS = {
    ["Blizzard"] = true, ["Blizzard Character Skills Bar"] = true, ["Blizzard Raid Bar"] = true, ["Solid"] = true,
}
