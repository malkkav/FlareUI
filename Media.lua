local ADDON_NAME, ns = ...

--------------------------------------------------
-- MEDIA
-- FlareUI's fonts, bar textures and borders, registered with LibSharedMedia.
--------------------------------------------------

--------------------------------------------------
-- 1. LIBRARY
--------------------------------------------------
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
if not LSM then return end   -- LoadCheck.lua tells the player

-- forward slashes so the paths work on every platform
local MEDIA_PATH = "Interface/AddOns/" .. ADDON_NAME .. "/Media/"

--------------------------------------------------
-- 2. CUSTOM ASSETS
--------------------------------------------------
local ASSETS = {
    -- Dark: Blizzard's Forever health bar art, greyed so the bar colours tint it. Light: the same art
    -- 1.25x brighter, as bright as Flat on average.
    statusbar = {
        ["FlareUI Flat"]    = "Bars/FlareUI-Flat.tga",
        ["FlareUI Striped"] = "Bars/FlareUI-Striped.tga",
        ["FlareUI Dark"]    = "Bars/FlareUI-Forever.tga",
        ["FlareUI Light"]   = "Bars/FlareUI-Forever-Bright.tga",
        -- (their old names: still registered so other addons and old saves find them; never
        -- listed, as every "FlareUI " name is FlareUI's own. Saved values are renamed once: Core.lua)
        ["FlareUI Forever"] = "Bars/FlareUI-Forever.tga",
        ["FlareUI Forever (Light)"] = "Bars/FlareUI-Forever-Bright.tga",
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
        ["Roboto Condensed Bold"] = "Fonts/RobotoCondensed-Bold.ttf",
        -- the settings window's titles; Latin only
        ["Marcellus"]        = "Fonts/Marcellus-Regular.ttf",
    },
}

-- Fonts need the alphabets they cover, or LibSharedMedia drops them on every non-Western client
local LATIN_CYRILLIC = LSM.LOCALE_BIT_western + LSM.LOCALE_BIT_ruRU
local FONT_ALPHABETS = {
    ["Asap Condensed"]   = LSM.LOCALE_BIT_western,
    ["Fira Condensed"]   = LATIN_CYRILLIC,
    ["Cabin Condensed"]  = LSM.LOCALE_BIT_western,
    ["Barlow Condensed"] = LSM.LOCALE_BIT_western,
    ["Roboto Condensed"] = LATIN_CYRILLIC,
    ["Roboto Condensed Bold"] = LATIN_CYRILLIC,
    ["Marcellus"]        = LSM.LOCALE_BIT_western,
}

for mediaType, entries in pairs(ASSETS) do
    for name, relativePath in pairs(entries) do
        -- FlareUI's own fonts with Russian letters: their families keep them (Core.lua, ns.FontFamily)
        if mediaType == "font" and FONT_ALPHABETS[name] == LATIN_CYRILLIC and ns.FontFamily then
            ns.FontFamily.cyrillic[(MEDIA_PATH .. relativePath):lower():gsub("/", "\\")] = true
        end
        local langMask = mediaType == "font" and FONT_ALPHABETS[name] or nil
        local ok, err = pcall(LSM.Register, LSM, mediaType, name, MEDIA_PATH .. relativePath, langMask)
        if not ok then
            print(("|cffff0000FlareUI Media:|r could not register %s '%s': %s"):format(mediaType, name, tostring(err)))
        end
    end
end

-- Friz Quadrata TT (Crisp): Blizzard's Russian copy of Friz Quadrata, which draws
-- sharper. 7.0.3 used it everywhere by accident and players liked it, so it is a pick of its own.
-- It lacks a few symbols (the middle dot "·" shows as a box): the Font row's tip says so.
do
    local CRISP = "Fonts\\FRIZQT___CYR.TTF"
    if C_UIFileAsset and C_UIFileAsset.IsKnownFile and C_UIFileAsset.IsKnownFile(CRISP) then
        pcall(LSM.Register, LSM, "font", "Friz Quadrata TT (Crisp)", CRISP, LATIN_CYRILLIC)
    end
end

--------------------------------------------------
-- 3. DROPDOWN LISTS
--------------------------------------------------
-- LibSharedMedia's own entries (added by every addon's copy, never removable): FlareUI's dropdowns
-- leave them out; a frame already set to one keeps it. The chat, damage meter and quest tracker keep
-- None as their own first choice.
local HIDDEN = {
    border = {
        ["None"] = true, ["Blizzard Achievement Wood"] = true, ["Blizzard Chat Bubble"] = true, ["Blizzard Dialog"] = true,
        ["Blizzard Dialog Gold"] = true, ["Blizzard Party"] = true, ["Blizzard Tooltip"] = true,
    },
    statusbar = {
        ["Blizzard"] = true, ["Blizzard Character Skills Bar"] = true, ["Blizzard Raid Bar"] = true, ["Solid"] = true,
    },
}

-- The names a media dropdown lists after FlareUI's own and a divider: other addons' bars or borders, A-Z
-- (Malkkav 11-27: Blizzard's art never shows in FlareUI's lists) also an entry whose file is the game's own,
-- whatever its name: a game file ID, or a path outside Interface\AddOns ("Solid" on WHITE8X8, say)
function ns.IsBlizzardMedia(mediaType, name)
    local path = LSM:Fetch(mediaType, name, true)
    if type(path) == "number" then return true end
    if type(path) ~= "string" or path == "" then return false end
    return not path:lower():gsub("/", "\\"):find("^interface\\addons\\")
end
function ns.AddonMedia(mediaType)
    local hidden = HIDDEN[mediaType] or {}
    local list = {}
    for _, name in ipairs(LSM:List(mediaType) or {}) do
        if not hidden[name] and not name:find("^FlareUI ") and not ns.IsBlizzardMedia(mediaType, name) then
            list[#list + 1] = name
        end
    end
    table.sort(list, function(a, b) return a:lower() < b:lower() end)
    return list
end
