local _, ns = ...
local S = ns.Settings

--------------------------------------------------
-- FONT ROWS
-- A module's Fonts tab: one heading per font that opens its controls, two lines of two: face and
-- size, outline and shadow (None, Soft or Strong). Headings start closed, so the page stays short;
-- what is open is remembered for the session. Each module gives its fonts and the function that re-applies them.
-- The controls' texts are shared ("font.size" in the copy serves every "*.font.*.size").
--------------------------------------------------
local LSM = LibStub("LibSharedMedia-3.0")

local open = {}   -- heading row key -> open

local SIZES = {}
for i = 8, 24 do SIZES[#SIZES + 1] = { i, tostring(i) } end

-- the shadow presets: offset of each (none: no shadow)
local SHADOWS = { soft = 1, strong = 2 }

-- every font LibSharedMedia knows (FlareUI's, the game's, and other addons')
local function Faces()
    local list = {}
    for _, name in ipairs(LSM:List("font")) do list[#list + 1] = { name, name } end
    return list
end

-- def = { module = "ch", tab = "fonts", section = "ch.fonts", apply = fn,
--         fonts = { { key = "text", path = "chat.chatFont" }, ... } }
function S:FontRows(def)
    for _, font in ipairs(def.fonts) do
        local heading = def.module .. ".font." .. font.key
        if #def.fonts == 1 and open[heading] == nil then open[heading] = true end   -- alone: open from the start
        local function Closed() return not open[heading] end
        S:Row{
            key = heading, kind = "expander", tab = def.tab, section = def.section,
            get = function() return true end,   -- never greys out its controls (they sit under it)
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
        -- one choice for the shadow and its offset
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
