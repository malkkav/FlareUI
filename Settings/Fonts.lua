local _, ns = ...
local S = ns.Settings

--------------------------------------------------
-- FONT ROWS
-- A module's Fonts tab: per font, an expander heading over face, size, outline and shadow rows.
-- Headings start closed (open state kept for the session); the copy's "font.*" texts serve all.
--------------------------------------------------
local LSM = LibStub("LibSharedMedia-3.0")

local open = {}   -- heading row key -> open

local SIZES = {}
for i = 8, 24 do SIZES[#SIZES + 1] = { i, tostring(i) } end

-- shadow offset per preset; "none" has no shadow
local SHADOWS = { soft = 1, strong = 2 }

-- every font LibSharedMedia knows
local function Faces()
    local list = {}
    for _, name in ipairs(LSM:List("font")) do list[#list + 1] = { name, name } end
    return list
end

-- def: module, tab, section, apply, fonts ({ { key = "text", path = "chat.chatFont" }, ... })
function S:FontRows(def)
    for _, font in ipairs(def.fonts) do
        local heading = def.module .. ".font." .. font.key
        if #def.fonts == 1 and open[heading] == nil then open[heading] = true end   -- a lone font starts open
        local function Closed() return not open[heading] end
        S:Row{
            key = heading, kind = "expander", tab = def.tab, section = def.section,
            get = function() return true end,   -- never greys out its child rows
            isOpen = function() return open[heading] end,
            toggle = function() open[heading] = not open[heading] end,
        }
        local function Control(field, row)
            row.key = heading .. "." .. field
            if not row.get then row.path = font.path .. "." .. field end
            row.parent, row.tab, row.section, row.hidden, row.apply = heading, def.tab, def.section, Closed, def.apply
            row.half = true
            S:Row(row)
        end
        Control("face", { kind = "dropdown", choices = Faces, dropdownWidth = 150 })
        Control("size", { kind = "choice", choices = SIZES })
        Control("flags", { kind = "choice", choices = { "NONE", "OUTLINE", "THICKOUTLINE" } })
        -- one choice sets the shadow and its offset
        Control("shadow", { kind = "choice", choices = { "none", "soft", "strong" },
            get = function()
                if not S:GetPath(font.path .. ".enableShadow") then return "none" end
                return (S:GetPath(font.path .. ".shadowX") or 1) >= 2 and "strong" or "soft"
            end,
            set = function(value)
                local offset = SHADOWS[value]
                S:SetPath(font.path .. ".enableShadow", offset ~= nil)
                if offset then
                    S:SetPath(font.path .. ".shadowX", offset)
                    S:SetPath(font.path .. ".shadowY", -offset)
                end
            end })
    end
end
