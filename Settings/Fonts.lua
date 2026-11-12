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
-- Auto (0) first: unit frame aura text sized to the icon
local AUTO_SIZES = { { 0, ns.L["Auto"] } }
for _, size in ipairs(SIZES) do AUTO_SIZES[#AUTO_SIZES + 1] = size end

-- shadow offset per preset; "none" has no shadow
local SHADOWS = { soft = 1, strong = 2 }

-- every font LibSharedMedia knows
local function Faces()
    local list = {}
    for _, name in ipairs(LSM:List("font")) do list[#list + 1] = { name, name } end
    return list
end

-- def: module, tab, section, apply, fonts ({ { key = "text", path = "chat.chatFont" }, ... });
-- a font with autoSize adds the Auto size (0)
function S:FontRows(def)
    for _, font in ipairs(def.fonts) do
        local heading = def.module .. ".font." .. font.key
        if #def.fonts == 1 and open[heading] == nil then open[heading] = true end   -- a lone font starts open
        local function Closed() return not open[heading] end
        S:Row{
            key = heading, kind = "expander", tab = def.tab, section = def.section,
            previewFont = font.path,
            get = function() return true end,   -- never greys out its child rows
            isOpen = function() return open[heading] end,
            toggle = function() open[heading] = not open[heading] end,
        }
        local function Control(field, row)
            row.key = heading .. "." .. field
            if not row.get then row.path = font.path .. "." .. field end
            row.parent, row.tab, row.section, row.hidden, row.apply = heading, def.tab, def.section, Closed, def.apply
            -- optional (the bags' font): Default keeps Blizzard's and greys the rest; disabled (def's or the font's) greys all
            local own = row.disabled
            row.disabled = function()
                if (def.disabled and def.disabled()) or (font.disabled and font.disabled()) then return true end
                if field ~= "face" and font.optional and (S:GetPath(font.path .. ".face") or "") == "" then return true end
                return own and own() or false
            end
            row.collapsedBy = heading   -- searchable while folded; a search result opens the heading
            row.half = true
            row.previewFont = font.path
            S:Row(row)
        end
        -- faceOnly (Zone Text): the face alone, Default ("") first, keeping Blizzard's font
        if font.faceOnly then
            Control("face", { kind = "dropdown", dropdownWidth = 150, choices = function()
                local list = Faces()
                table.insert(list, 1, { "", ns.L["Default"] })
                return list
            end })
        else
        Control("face", { kind = "dropdown", dropdownWidth = 150, choices = not font.optional and Faces or function()
            local list = Faces()
            table.insert(list, 1, { "", ns.L["Default"] })
            return list
        end })
        Control("size", { kind = "choice", choices = font.autoSize and AUTO_SIZES or SIZES })
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
        -- Reset (11-11, Marcus): this font's fields back to the profile's defaults
        local FIELDS = { "face", "size", "flags", "enableShadow", "shadowX", "shadowY" }
        local function Changed()
            for _, field in ipairs(FIELDS) do
                local default = S:DefaultPath(font.path .. "." .. field)
                if default ~= nil and S:GetPath(font.path .. "." .. field) ~= default then return true end
            end
            return false
        end
        S:Row{
            key = heading .. ".reset", kind = "button", center = true, buttonWidth = 160,
            parent = heading, tab = def.tab, section = def.section, hidden = Closed, collapsedBy = heading,
            previewFont = font.path,
            disabled = function()
                return (def.disabled and def.disabled()) or (font.disabled and font.disabled()) or not Changed()
            end,
            apply = function()
                for _, field in ipairs(FIELDS) do
                    local default = S:DefaultPath(font.path .. "." .. field)
                    if default ~= nil then S:SetPath(font.path .. "." .. field, default) end
                end
                if def.apply then def.apply() end
                if ns.SettingsPanel and ns.SettingsPanel.Refresh then ns.SettingsPanel:Refresh() end
            end,
        }
    end
end
