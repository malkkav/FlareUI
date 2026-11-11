local _, ns = ...

--------------------------------------------------
-- ZONE TEXT FONT (Quality of Life > Fonts > Zone Text, Default)
-- The big zone and subzone names that appear as you enter a new area (and the PvP line under them)
-- in a font of your choice. Only the face changes: Blizzard's sizes and thick outline stay (the zone
-- name is far past the Fonts tab's 8-24 sizes). Default (face "") leaves Blizzard's font alone.
-- (11-11, a player's request)
--------------------------------------------------
local ZT = {}
ns.ZoneText = ZT
ns.modules["ZoneText"] = ZT

-- each string and the Blizzard font object it inherits (ZoneText.xml)
local STRINGS = {
    ZoneTextString = "ZoneTextFont",
    SubZoneTextString = "SubZoneTextFont",
    PVPInfoTextString = "PVPInfoTextFont",
    PVPArenaTextString = "PVPInfoTextFont",
}

local function Face()
    local db = ns.db and ns.db.profile and ns.db.profile.tweaks
    local font = db and db.zoneTextFont
    return font and font.face or ""
end

function ZT:Apply()
    local face = Face()
    for name, objectName in pairs(STRINGS) do
        local fs, object = _G[name], _G[objectName]
        if fs and object and object.GetFont then
            if face == "" then
                -- back to Blizzard's font object, only if FlareUI changed it this session
                if self.changed then fs:SetFontObject(object) end
            else
                local _, size, flags = object:GetFont()
                -- the size already has Text Scale (the game's fonts are scaled as FlareUI loads), and
                -- SetFontFamily scales again: undo that. A family keeps Cyrillic zone names readable.
                ns.SetFontFamily(fs, ns.GetFontPath(face), (size or 32) / (ns.TEXT_SCALE or 1), flags or "OUTLINE")
            end
        end
    end
    self.changed = face ~= ""
end

function ZT:Init()
    if Face() ~= "" then self:Apply() end
end
