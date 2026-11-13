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

-- every font LibSharedMedia knows (the Global Font row lists these)
local function Faces()
    local list = {}
    for _, name in ipairs(LSM:List("font")) do list[#list + 1] = { name, name } end
    return list
end
S.FontFaces = Faces

-- a font's faces: Global first, named after the face it stands for (11-13); an optional font
-- (Default keeps Blizzard's) has Default before it
local function GlobalChoice()
    return { ns.GLOBAL_FONT, ns.L["Global (%s)"]:format(ns.GlobalFontFace()) }
end
local function FontFaces()
    local list = Faces()
    table.insert(list, 1, GlobalChoice())
    return list
end
local function OptionalFaces()
    local list = FontFaces()
    table.insert(list, 1, { "", ns.L["Default"] })
    return list
end

-- Every font the Fonts tabs set, for the Settings page's Fonts section (Use Global Font
-- Everywhere, Reset All Fonts, the Global Font's refresh): { def, Get, Set, Default } in the order made
S.allFonts = {}
local FIELDS = { "face", "size", "flags", "enableShadow", "shadowX", "shadowY" }

-- every module that shows one of these fonts restyles, once each; first Blizzard's own text, if
-- FlareUI sets it (ns.GameFonts, below; fromGame: it asked for this)
function S:ApplyAllFonts(fromGame)
    if not fromGame and ns.GameFonts and ns.GameFonts.Apply then ns.GameFonts.Apply(false) end
    local done = {}
    for _, font in ipairs(self.allFonts) do
        -- the def's apply is read now: a def may set it after its font list; one run per apply
        -- (every unit frame section shares one)
        local def = font.def
        -- an off module isn't running: it takes its fonts as it starts
        local module = self.modules[def.module]
        if def.apply and not done[def.apply] and not (module and not module:IsOn()) then
            done[def.apply] = true
            local ok, err = pcall(def.apply)
            if not ok then geterrorhandler()(err) end
        end
    end
    if ns.SettingsPanel and ns.SettingsPanel.Refresh then ns.SettingsPanel:Refresh() end
end

-- every font's face set to Global
function S:UseGlobalFontEverywhere()
    for _, font in ipairs(self.allFonts) do font.Set("face", ns.GLOBAL_FONT) end
    self:ApplyAllFonts()
end

-- whether any font (or the Global Font) differs from the profile's defaults
-- (the Settings page's own: Global Font, Game Text, Nameplate Font, Combat Text Font)
local OWN_PATHS = { "fonts.global.face", "fonts.gameText", "fonts.nameplate.face", "fonts.combat.face" }
function S:AnyFontChanged()
    for _, path in ipairs(OWN_PATHS) do
        local default = self:DefaultPath(path)
        if default ~= nil and self:GetPath(path) ~= default then return true end
    end
    for _, font in ipairs(self.allFonts) do
        for _, field in ipairs(FIELDS) do
            local default = font.Default(field)
            if default ~= nil and font.Get(field) ~= default then return true end
        end
    end
    return false
end

-- every font, and the Global Font, back to the profile's defaults
function S:ResetAllFonts()
    for _, path in ipairs(OWN_PATHS) do self:SetPath(path, self:DefaultPath(path)) end
    if ns.GameFonts and ns.GameFonts.SaveCombatPath then ns.GameFonts.SaveCombatPath() end
    for _, font in ipairs(self.allFonts) do
        for _, field in ipairs(FIELDS) do
            local default = font.Default(field)
            if default ~= nil then font.Set(field, default) end
        end
    end
    self:ApplyAllFonts()
end

-- def: module, tab, section, apply, prefix, fonts; each font one of:
--   { key = "text", path = "chat.chatFont" }                    a saved path in the profile
--   { key = "names", font = fn -> table, default = fn -> table }  a table found when asked (the unit
--       frames' fonts are saved per frame style; others are seeded first)
-- Font options: autoSize (adds the Auto size, 0), label (fn: a heading the copy hasn't), hidden,
-- optional, faceOnly, disabled. Each heading has its own Reset (11-13, Marcus: as the sections';
-- no Apply to All: the Global Font gives every font one face).
-- prefix (11-13, fonts back from Edit Mode): several sections of one module with the same texts
-- ("player", "target"...): the row keys become "uf.font.player_names", whose copy falls back to
-- "uf.font.names".
function S:FontRows(def)
    local function RowKey(name) return def.module .. ".font." .. (def.prefix and (def.prefix .. "_") or "") .. name end
    for _, font in ipairs(def.fonts) do
        local Get, Set, Default
        if font.font then
            Get = function(field) local t = font.font(); if t then return t[field] end end
            Set = function(field, value) local t = font.font(); if t then t[field] = value end end
            Default = function(field) local d = font.default and font.default(); if d then return d[field] end end
        else
            Get = function(field) return S:GetPath(font.path .. "." .. field) end
            Set = function(field, value) S:SetPath(font.path .. "." .. field, value) end
            Default = function(field) return S:DefaultPath(font.path .. "." .. field) end
        end
        S.allFonts[#S.allFonts + 1] = { def = def, Get = Get, Set = Set, Default = Default }
        -- the settings preview reads a path, or the table itself (PreviewSamples.lua Font)
        local preview = font.path or font.font
        local heading = RowKey(font.key)
        local function Closed() return not open[heading] or (font.hidden and font.hidden()) or false end
        local function Disabled()
            return (def.disabled and def.disabled()) or (font.disabled and font.disabled()) or false
        end
        local function Changed()
            for _, field in ipairs(FIELDS) do
                local default = Default(field)
                if default ~= nil and Get(field) ~= default then return true end
            end
            return false
        end
        S:Row{
            key = heading, kind = "expander", tab = def.tab, section = def.section,
            previewFont = preview, labelFn = font.label, hidden = font.hidden,
            get = function() return true end,   -- never greys out its child rows
            isOpen = function() return open[heading] end,
            toggle = function() open[heading] = not open[heading] end,
            -- the heading's Reset (Panel.lua Fill.expander): this font back to the profile's defaults
            reset = {
                can = function() return not Disabled() and Changed() end,
                run = function()
                    for _, field in ipairs(FIELDS) do
                        local default = Default(field)
                        if default ~= nil then Set(field, default) end
                    end
                    if def.apply then
                        local ok, err = pcall(def.apply)
                        if not ok then geterrorhandler()(err) end
                    end
                end,
            },
        }
        local function Control(field, row)
            row.key = heading .. "." .. field
            if font.font then
                if not row.get then
                    row.get = function() return Get(field) end
                    row.set = function(value) Set(field, value) end
                end
                row.resetValue = row.resetValue or function() return Default(field) end
            elseif not row.get then
                row.path = font.path .. "." .. field
            end
            row.parent, row.tab, row.section, row.hidden, row.apply = heading, def.tab, def.section, Closed, def.apply
            -- optional (the bags' font): Default keeps Blizzard's and greys the rest; disabled (def's or the font's) greys all
            local own = row.disabled
            row.disabled = function()
                if Disabled() then return true end
                if field ~= "face" and font.optional and (Get("face") or "") == "" then return true end
                return own and own() or false
            end
            row.collapsedBy = heading   -- searchable while folded; a search result opens the heading
            row.half = true
            row.previewFont = preview
            S:Row(row)
        end
        -- faceOnly (Zone Text): the face alone, Default ("") first, keeping Blizzard's font
        if font.faceOnly then
            Control("face", { kind = "dropdown", dropdownWidth = 150, choices = OptionalFaces })
        else
        Control("face", { kind = "dropdown", dropdownWidth = 150, choices = font.optional and OptionalFaces or FontFaces })
        Control("size", { kind = "choice", choices = font.autoSize and AUTO_SIZES or SIZES })
        Control("flags", { kind = "choice", choices = { "NONE", "OUTLINE", "THICKOUTLINE" } })
        -- one choice sets the shadow and its offset
        Control("shadow", { kind = "choice", choices = { "none", "soft", "strong" },
            get = function()
                if not Get("enableShadow") then return "none" end
                return (Get("shadowX") or 1) >= 2 and "strong" or "soft"
            end,
            set = function(value)
                local offset = SHADOWS[value]
                Set("enableShadow", offset ~= nil)
                if offset then
                    Set("shadowX", offset)
                    Set("shadowY", -offset)
                end
            end,
            resetValue = function()
                if not Default("enableShadow") then return "none" end
                return (Default("shadowX") or 1) >= 2 and "strong" or "soft"
            end })
        end
    end
end

--------------------------------------------------
-- BLIZZARD'S TEXT (11-13, fonts phase 4)
-- The Settings page's Global Font section, all off by default:
--   Game Text       every Blizzard font object takes the Global Font's face; sizes, outlines and the
--                   other alphabets' faces stay (Core.lua SetFontObjectFaceRaw)
--   Nameplate Font  Blizzard's nameplate font objects take a face of their own (Default: as they are)
--   Combat Text     DAMAGE_TEXT_FONT, the numbers over what you hit: the game reads it as you log in,
--                   so it is set as FlareUI loads, from the file saved when it was picked
-- Each apply puts back Blizzard's fonts (a snapshot made before the first change), then sets what is
-- on; FlareUI's own fonts (tooltips, chat...) are restyled after it, so they stay on top.
--------------------------------------------------
ns.GameFonts = {}
local GF = ns.GameFonts
local NAMEPLATE_OBJECTS = { "SystemFont_NamePlate", "SystemFont_NamePlate_Outlined", "SystemFont_NamePlateFixed",
    "SystemFont_LargeNamePlate", "SystemFont_LargeNamePlateFixed", "SystemFont_NamePlateCastBar", "SystemFont_NamePlateLevel" }

local function FontsDb() return ns.db and ns.db.profile and ns.db.profile.fonts end

-- Blizzard's font objects as they are now: { object, path, size, flags, members = { alphabet = { path, size, flags } } }
function GF.Snapshot()
    if GF.original then return end
    GF.original = {}
    local ok, names = pcall(GetFonts)
    if not (ok and type(names) == "table") then return end
    for _, name in ipairs(names) do
        local object = type(name) == "string" and _G[name] or name
        -- FlareUI's own (the settings window's) keep theirs
        local ours = type(name) == "string" and name:find("^FlareUI")
        if not ours and type(object) == "table" and object.GetFont and object.SetFont then
            local path, size, flags = object:GetFont()
            if path and type(size) == "number" and size > 0 then
                local entry = { object = object, path = path, size = size, flags = flags or "", members = {} }
                if object.GetFontObjectForAlphabet then
                    for _, alphabet in ipairs(ns.FontFamily.alphabets) do
                        local found, member = pcall(object.GetFontObjectForAlphabet, object, alphabet)
                        if found and member and member.GetFont then
                            local p, s, f = member:GetFont()
                            if p and s then entry.members[alphabet] = { p, s, f or "" } end
                        end
                    end
                end
                GF.original[#GF.original + 1] = entry
                if type(name) == "string" then GF.byName = GF.byName or {}; GF.byName[name] = entry end
            end
        end
    end
end

local function Restore(entry)
    pcall(entry.object.SetFont, entry.object, entry.path, entry.size, entry.flags)
    if not entry.object.GetFontObjectForAlphabet then return end
    for alphabet, m in pairs(entry.members) do
        local found, member = pcall(entry.object.GetFontObjectForAlphabet, entry.object, alphabet)
        if found and member then pcall(member.SetFont, member, m[1], m[2], m[3]) end
    end
end

local function SetFace(entry, path)
    pcall(ns.SetFontObjectFaceUnscaled, entry.object, path, entry.size, entry.flags)
end

-- Game Text and the Nameplate Font onto Blizzard's font objects; restyle: FlareUI's own fonts after
function GF.Apply(restyle)
    local db = FontsDb()
    if not db then return end
    local gameText = db.gameText and true or false
    local nameplate = db.nameplate and db.nameplate.face or ""
    if not (gameText or nameplate ~= "" or GF.changed) then return end
    GF.Snapshot()
    if not GF.original then return end
    if GF.changed then for _, entry in ipairs(GF.original) do Restore(entry) end end
    if gameText then
        local path = ns.GetFontPath(ns.GLOBAL_FONT)
        for _, entry in ipairs(GF.original) do SetFace(entry, path) end
        GF.gamePath = path
    end
    if nameplate ~= "" then
        local path = ns.GetFontPath(nameplate)
        for _, name in ipairs(NAMEPLATE_OBJECTS) do
            local entry = GF.byName and GF.byName[name]
            if entry then SetFace(entry, path) end
        end
    end
    GF.changed = gameText or nameplate ~= ""
    if restyle then S:ApplyAllFonts(true) end
end

-- The combat text's file for the next login: the picked face's, once that file is known
function GF.SaveCombatPath()
    local db = FontsDb()
    if not db then return end
    local combat = db.combat
    if type(combat) ~= "table" then return end
    local face = combat.face or ""
    if face == "" then combat.path = nil return end
    local path = ns.GetFontPath(face)
    if path and C_UIFileAsset.IsKnownFile(path) then combat.path = path end
end

-- As FlareUI loads (Core.lua, before the modules set their fonts)
function GF.OnLoad()
    local db = FontsDb()
    if not db then return end
    local combat = db.combat
    local path = type(combat) == "table" and (combat.face or "") ~= "" and combat.path
    if path and C_UIFileAsset.IsKnownFile(path) then _G.DAMAGE_TEXT_FONT = path end
    GF.Apply(false)
end

-- Once every addon has loaded (other addons' fonts registered by then): the Global Font may only now
-- name a font another addon brings, and the combat text's file is saved for the next login
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    local db = FontsDb()
    if not db then return end
    GF.SaveCombatPath()
    if db.gameText and GF.gamePath ~= ns.GetFontPath(ns.GLOBAL_FONT) then GF.Apply(true) end
end)
