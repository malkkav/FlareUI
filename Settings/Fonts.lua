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
-- Everywhere, Reset All Fonts, the Global Font's refresh): { path, def } in the order made
S.allFonts = {}
-- and every Edit Mode Fonts section's (ns.EditFonts, below), by spec id: { texts, font, default, apply, group }
S.editFonts = {}

-- each Edit Mode font table once, with its default and its spec
local function EachEditFont(fn)
    for _, spec in pairs(S.editFonts) do
        for _, text in ipairs(spec.texts) do
            local font = spec.font(text.key)
            if font then fn(font, spec.default(text.key), spec) end
        end
    end
end
-- the Edit Mode sections' restyles, one per group (every unit frame shares one)
local function ApplyEditFonts()
    local done = {}
    for _, spec in pairs(S.editFonts) do
        local group = spec.group or spec.id
        if not done[group] then
            done[group] = true
            local ok, err = pcall(spec.apply)
            if not ok then geterrorhandler()(err) end
        end
    end
end
local FIELDS = { "face", "size", "flags", "enableShadow", "shadowX", "shadowY" }

-- every module that shows one of these fonts restyles, once each; first Blizzard's own text, if
-- FlareUI sets it (ns.GameFonts, below; fromGame: it asked for this)
function S:ApplyAllFonts(fromGame)
    if not fromGame and ns.GameFonts and ns.GameFonts.Apply then ns.GameFonts.Apply(false) end
    local done = {}
    for _, font in ipairs(self.allFonts) do
        -- the def's apply is read now: a def may set it after its font list
        local def = font.def
        -- an off module isn't running: it takes its fonts as it starts
        local module = self.modules[def.module]
        if def.apply and not done[def] and not (module and not module:IsOn()) then
            done[def] = true
            local ok, err = pcall(def.apply)
            if not ok then geterrorhandler()(err) end
        end
    end
    ApplyEditFonts()
    if ns.SettingsPanel and ns.SettingsPanel.Refresh then ns.SettingsPanel:Refresh() end
end

-- every font's face set to Global (the Fonts tabs' and the Edit Mode sections')
function S:UseGlobalFontEverywhere()
    for _, font in ipairs(self.allFonts) do self:SetPath(font.path .. ".face", ns.GLOBAL_FONT) end
    EachEditFont(function(font) font.face = ns.GLOBAL_FONT end)
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
            local default = self:DefaultPath(font.path .. "." .. field)
            if default ~= nil and self:GetPath(font.path .. "." .. field) ~= default then return true end
        end
    end
    local changed = false
    EachEditFont(function(font, default)
        for _, field in ipairs(FIELDS) do
            if default and default[field] ~= nil and font[field] ~= default[field] then changed = true end
        end
    end)
    return changed
end

-- every font, and the Global Font, back to the profile's defaults
function S:ResetAllFonts()
    for _, path in ipairs(OWN_PATHS) do self:SetPath(path, self:DefaultPath(path)) end
    if ns.GameFonts and ns.GameFonts.SaveCombatPath then ns.GameFonts.SaveCombatPath() end
    for _, font in ipairs(self.allFonts) do
        for _, field in ipairs(FIELDS) do
            local default = self:DefaultPath(font.path .. "." .. field)
            if default ~= nil then self:SetPath(font.path .. "." .. field, default) end
        end
    end
    EachEditFont(function(font, default)
        if default then for _, field in ipairs(FIELDS) do font[field] = default[field] end end
    end)
    self:ApplyAllFonts()
end

-- def: module, tab, section, apply, fonts ({ { key = "text", path = "chat.chatFont" }, ... });
-- a font with autoSize adds the Auto size (0)
function S:FontRows(def)
    for _, font in ipairs(def.fonts) do
        S.allFonts[#S.allFonts + 1] = { path = font.path, def = def }
        local heading = def.module .. ".font." .. font.key
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
            Control("face", { kind = "dropdown", dropdownWidth = 150, choices = OptionalFaces })
        else
        Control("face", { kind = "dropdown", dropdownWidth = 150, choices = font.optional and OptionalFaces or FontFaces })
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

--------------------------------------------------
-- EDIT MODE FONTS SECTION (11-13, fonts phase 3)
-- A frame's fonts in its Edit Mode dialog, always the last section: Text picks which of the frame's
-- texts the rows below edit (hidden with one text), then Font, Outline, Shadow and Size, then
-- Apply to All (this frame's fonts on its siblings) and Reset Fonts. Edit Mode's Reset To Default
-- resets them all through the Text row.
--   spec.id       unique key: the Text row's choice is kept per id for the session
--   spec.texts    { { key = "names", name = L["Names"], autoSize = true? }, ... }
--   spec.font     function(textKey) -> the saved, writable font table
--   spec.default  function(textKey) -> its default table (read only)
--   spec.apply    function() restyles the frame (and whatever shares its fonts)
--   spec.all      optional { text = the button's label, desc = what it does, run = function() end }
--   spec.group    optional: specs sharing one restyle (all unit frames: "uf")
--------------------------------------------------
local editPicks = {}   -- spec.id -> the picked text's key, for the session
local SHADOW_OFFSETS = { soft = 1, strong = 2 }

ns.Dialogs = ns.Dialogs or {}
ns.Dialogs["FLAREUI_FONTS_APPLY_ALL"] = {
    text = ns.L["Copy this frame's fonts to every frame of its kind?\n\n%s"],
    button1 = ns.L["Apply"],
    button2 = ns.L["Cancel"],
    OnAccept = function(data)
        if data and data.run then data.run() end
        local LEM = LibStub("FlareEditMode", true)
        if LEM and LEM.RefreshOpenSettings then LEM:RefreshOpenSettings() end
    end,
    hideOnEscape = true,
}

function ns.EditFonts(spec)
    S.editFonts[spec.id] = spec   -- for the Settings page's Fonts buttons and the Global Font
    local L = ns.L
    local LEM = LibStub("FlareEditMode")
    local T = LEM.SettingType
    local texts = spec.texts
    local function Current()
        local key = editPicks[spec.id]
        for _, text in ipairs(texts) do
            if text.key == key then return text end
        end
        return texts[1]
    end
    local function Font() return spec.font(Current().key) end
    local function Apply()
        local ok, err = pcall(spec.apply)
        if not ok then geterrorhandler()(err) end
    end
    local function Changed()
        for _, text in ipairs(texts) do
            local font, default = spec.font(text.key), spec.default(text.key)
            for _, field in ipairs(FIELDS) do
                if font and default and default[field] ~= nil and font[field] ~= default[field] then return true end
            end
        end
        return false
    end
    local function ResetAll()
        for _, text in ipairs(texts) do
            local font, default = spec.font(text.key), spec.default(text.key)
            if font and default then
                for _, field in ipairs(FIELDS) do font[field] = default[field] end
            end
        end
        Apply()
    end
    local function Later() C_Timer.After(0, function() LEM:RefreshOpenSettings() end) end

    local size   -- the Size row: its range follows the picked text (Auto on aura texts)
    local items = {}
    local choices = {}
    for _, text in ipairs(texts) do choices[#choices + 1] = { text = text.name, value = text.key } end
    items[#items + 1] = {
        name = L["Text"], kind = T.Dropdown, default = texts[1].key, values = choices,
        desc = L["Which text the rows below change."],
        hidden = #texts < 2,
        get = function() return Current().key end,
        set = function(_, value, fromReset)
            -- Edit Mode's Reset To Default: every font of the frame
            if fromReset then ResetAll() return end
            editPicks[spec.id] = value
            size.minValue = Current().autoSize and 0 or 6
            Later()
        end,
    }
    items[#items + 1] = {
        name = L["Font"], kind = T.Dropdown, default = ns.GLOBAL_FONT, height = 300,
        desc = L["The typeface. Global follows the Global Font on the Settings page."],
        values = function()
            local list = { { text = L["Global (%s)"]:format(ns.GlobalFontFace()), value = ns.GLOBAL_FONT, fontFace = ns.GLOBAL_FONT } }
            for _, name in ipairs(LSM:List("font")) do list[#list + 1] = { text = name, value = name, fontFace = name } end
            return list
        end,
        get = function() local f = Font(); return f and f.face end,
        set = function(_, value, fromReset)
            if fromReset then return end
            local f = Font(); if f then f.face = value; Apply() end
        end,
    }
    items[#items + 1] = {
        name = L["Outline"], kind = T.Dropdown, default = "OUTLINE",
        desc = L["A dark outline around the letters."],
        values = { { text = L["None"], value = "NONE" }, { text = L["Outline"], value = "OUTLINE" },
                   { text = L["Thick Outline"], value = "THICKOUTLINE" } },
        get = function() local f = Font(); return f and (f.flags or "NONE") end,
        set = function(_, value, fromReset)
            if fromReset then return end
            local f = Font(); if f then f.flags = value; Apply() end
        end,
    }
    items[#items + 1] = {
        name = L["Shadow"], kind = T.Dropdown, default = "soft",
        desc = L["A drop shadow under the letters.\n* Soft: 1 pixel away\n* Strong: 2 pixels away"],
        values = { { text = L["None"], value = "none" }, { text = L["Soft"], value = "soft" }, { text = L["Strong"], value = "strong" } },
        get = function()
            local f = Font()
            if not (f and f.enableShadow) then return "none" end
            return (f.shadowX or 1) >= 2 and "strong" or "soft"
        end,
        set = function(_, value, fromReset)
            if fromReset then return end
            local f = Font()
            if not f then return end
            local offset = SHADOW_OFFSETS[value]
            f.enableShadow = offset ~= nil
            if offset then f.shadowX, f.shadowY = offset, -offset end
            Apply()
        end,
    }
    size = {
        name = L["Size"], kind = T.Slider, default = 12, minValue = Current().autoSize and 0 or 6, maxValue = 32, valueStep = 1,
        desc = L["The text size."],
        formatter = function(value) return value == 0 and L["Auto"] or tostring(value) end,
        get = function() local f = Font(); return f and f.size or 12 end,
        set = function(_, value, fromReset)
            if fromReset then return end
            local f = Font(); if f then f.size = value; Apply() end
        end,
    }
    items[#items + 1] = size
    local buttons = {}
    if spec.all then
        buttons[#buttons + 1] = { text = spec.all.text, desc = spec.all.desc,
            click = function() ns.ShowDialog("FLAREUI_FONTS_APPLY_ALL", spec.all.desc or "", { run = spec.all.run }) end }
    end
    buttons[#buttons + 1] = { text = L["Reset Fonts"], desc = L["This frame's fonts back to their defaults."],
        disabled = function() return not Changed() end,
        click = function() ResetAll(); Later() end }
    items[#items + 1] = { name = "", kind = T.Buttons, buttons = buttons }
    return items
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
