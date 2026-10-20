local _, ns = ...
local L = ns.L

--------------------------------------------------
-- SETTINGS REGISTRY
-- Every settings page and row as data, read by the panel, its search, the reload footer and the
-- Edit Mode links. All text comes from ns.Copy (Settings/Copy.lua) by row key.
--------------------------------------------------
local Settings = {
    modules = {},       -- key -> module
    order = {},         -- module keys, in list order
    rows = {},          -- key -> row
    pending = {},       -- row key -> true while its value differs from the session start
    missing = {},       -- copy keys asked for and not found (listed by the harness)
}
ns.Settings = Settings

local GROUPS = { "top", "HUD", "Info", "Tools", "bottom" }

--------------------------------------------------
-- 1. TEXT
--------------------------------------------------
local function CopyRow(key)
    return ns.Copy and ns.Copy.rows and ns.Copy.rows[key]
end

-- A row's text field; falls back to a wildcard entry ("uf.*.healthText" serves "uf.target.healthText")
function Settings:Text(key, field, optional)
    local row = CopyRow(key)
    if not (row and row[field]) then
        local wild = key:gsub("^([^.]+)%.[^.]+%.", "%1.*.")
        row = CopyRow(wild)
    end
    -- font controls ("ch.font.text.size") share one entry per control ("font.size")
    if not (row and row[field]) then
        local control = key:match("%.font%.[^.]+%.(%w+)$")
        if control then row = CopyRow("font." .. control) end
    end
    local text = row and row[field]
    if text == nil and field == "label" and not optional then
        self.missing[key] = true
        return key
    end
    return text
end

function Settings:ModuleText(key, field)
    local m = ns.Copy and ns.Copy.modules and ns.Copy.modules[key]
    local text = m and m[field]
    if text == nil and field == "title" then
        self.missing["module " .. key] = true
        return key
    end
    return text
end

function Settings:SectionText(key)
    local text = ns.Copy and ns.Copy.sections and ns.Copy.sections[key]
    if text == nil then self.missing["section " .. key] = true end
    return text or key
end

function Settings:WindowText(key, fallback)
    local text = ns.Copy and ns.Copy.window and ns.Copy.window[key]
    return text or fallback
end

--------------------------------------------------
-- 2. SAVED VALUES
-- Dot paths into the profile ("actionbars.procGlow").
--------------------------------------------------
local function Walk(path, create)
    local node = ns.db and ns.db.profile
    if not node then return nil end
    local parts = {}
    for part in path:gmatch("[^.]+") do parts[#parts + 1] = part end
    for i = 1, #parts - 1 do
        local nextNode = node[parts[i]]
        if type(nextNode) ~= "table" then
            if not create then return nil end
            nextNode = {}
            node[parts[i]] = nextNode
        end
        node = nextNode
    end
    return node, parts[#parts]
end

function Settings:GetPath(path)
    local node, last = Walk(path, false)
    if node then return node[last] end
end

function Settings:SetPath(path, value)
    local node, last = Walk(path, true)
    if node then node[last] = value end
end

--------------------------------------------------
-- 3. MODULES
--------------------------------------------------
local Module = {}
Module.__index = Module

function Module:Title() return Settings:ModuleText(self.key, "title") end
function Module:Description() return Settings:ModuleText(self.key, "desc") end

-- Pages without a master switch count as on
function Module:IsOn()
    if not self.enabled then return true end
    return Settings:GetPath(self.enabled) and true or false
end

-- Modules start at login, so switching one asks for a reload
function Module:SetOn(on)
    if not self.enabled then return end
    if self.startedOn == nil then self.startedOn = self:IsOn() end
    Settings:SetPath(self.enabled, on and true or false)
    Settings:TrackReload("module:" .. self.key, on and true or false, self.startedOn)
end

-- Sections in order with their visible rows, limited to one tab when the module has tabs
function Module:Sections(tabKey)
    local list = {}
    for _, section in ipairs(self.sections) do
        local rows = {}
        for _, row in ipairs(section.rows) do
            -- a row without a tab belongs to the first one
            if not row:IsHidden() and (not self.tabs or (row.tab or self.tabs[1].key) == tabKey) then rows[#rows + 1] = row end
        end
        if #rows > 0 then list[#list + 1] = { key = section.key, title = section.title, rows = rows } end
    end
    return list
end

-- def: key, group, order, enabled ("db.path"), editMode, editFrames, banner, navIcon, navIconRound,
-- custom, tabs ({ key, custom = build(host, previewHost), refresh, preview })
function Settings:Module(def)
    assert(type(def.key) == "string", "Settings:Module needs a key")
    local module = setmetatable(def, Module)
    module.group = module.group or "HUD"
    module.order = module.order or 100
    module.sections = {}
    module.sectionByKey = {}
    self.modules[module.key] = module
    self.order[#self.order + 1] = module.key
    self.sorted = nil
    return module
end

-- Modules grouped for the left list: { { group = "HUD", modules = { ... } }, ... }
function Settings:Groups()
    if not self.sorted then
        local byGroup = {}
        for _, key in ipairs(self.order) do
            local module = self.modules[key]
            byGroup[module.group] = byGroup[module.group] or {}
            table.insert(byGroup[module.group], module)
        end
        self.sorted = {}
        for _, group in ipairs(GROUPS) do
            local list = byGroup[group]
            if list then
                table.sort(list, function(a, b)
                    if a.order ~= b.order then return a.order < b.order end
                    return a.key < b.key
                end)
                self.sorted[#self.sorted + 1] = { group = group, modules = list }
            end
        end
    end
    return self.sorted
end

--------------------------------------------------
-- 4. ROWS
--------------------------------------------------
local Row = {}
Row.__index = Row

function Row:Label()
    if self.labelFn then return self.labelFn() end
    if self.kind == "text" then return Settings:Text(self.key, "label", true) or "" end
    return Settings:Text(self.key, "label")
end
function Row:Description() return Settings:Text(self.key, "desc") end
function Row:Tip() return Settings:Text(self.key, "tip") end

function Row:IsHidden()
    return self.hidden and self.hidden() or false
end

-- Greyed when its own check says so or its parent row is off
function Row:IsDisabled()
    if self.disabled and self.disabled() then return true end
    local parent = self.parent and Settings.rows[self.parent]
    if parent and not parent:Get() then return true end
    return false
end

function Row:Get()
    if self.get then return self.get() end
    if self.path then return Settings:GetPath(self.path) end
end

function Row:Set(value)
    if self.reload and not self.started then
        self.started, self.startValue = true, self:Get()
    end
    if self.set then
        self.set(value)
    elseif self.path then
        Settings:SetPath(self.path, value)
    end
    if self.reload then
        Settings:TrackReload(self.key, value, self.startValue)
    elseif self.apply then
        local ok, err = pcall(self.apply, value)
        if not ok then geterrorhandler()(err) end
    end
    Settings:Fire("RowChanged", self)
end

-- Frame Border choices: None, FlareUI's border, then other addons' borders; rebuilt on each open
function Settings:BorderChoices()
    local list = { { "None", L["None"] }, { "FlareUI Frames", "FlareUI Frames" } }
    local others = ns.AddonMedia("border")
    if #others > 0 then
        list[#list + 1] = { divider = true }
        for _, name in ipairs(others) do list[#list + 1] = { name, name } end
    end
    return list
end

-- Frame Opacity choices: 0% to 100% in tens, stored as 0..1
function Settings:OpacityChoices()
    local list = {}
    for i = 0, 10 do list[#list + 1] = { i / 10, (i * 10) .. "%" } end
    return list
end

-- Choice names come from the row's own { value, "text" } pairs, else the copy (in order)
function Row:Choices()
    local list = {}
    local names = Settings:Text(self.key, "choices")
    local choices = self.choices
    if type(choices) == "function" then choices = choices() end
    for i, choice in ipairs(choices or {}) do
        if type(choice) == "table" and choice.divider then
            list[i] = { divider = true }
        else
            local value, text = choice, nil
            if type(choice) == "table" then value, text = choice[1], choice[2] end
            list[i] = { value = value, text = text or (names and names[i]) or tostring(value) }
        end
    end
    return list
end

-- Label, description, tip and copy tags, lowercased and cached
function Row:SearchText()
    if not self.searchText then
        local parts = { self:Label() or "", self:Description() or "", self:Tip() or "" }
        for _, tag in ipairs(Settings:Text(self.key, "tags") or {}) do parts[#parts + 1] = tag end
        self.searchText = table.concat(parts, " "):lower()
    end
    return self.searchText
end

-- def: key ("module.row"), kind, path ("db.path") or get/set, choices, parent, tab, section, half,
-- reload, apply, hidden, disabled. Kinds: toggle, choice, dropdown, keybind, button, buttons, frame,
-- expander, editmode (built in Settings/Panel.lua), text (custom-page copy, never drawn or searched)
function Settings:Row(def)
    assert(type(def.key) == "string", "Settings:Row needs a key")
    local moduleKey = def.module or def.key:match("^([^.]+)")
    local module = self.modules[moduleKey]
    assert(module, "Settings:Row: no module " .. tostring(moduleKey) .. " for " .. def.key)
    local row = setmetatable(def, Row)
    row.module = moduleKey
    row.kind = row.kind or "toggle"
    -- a row that is a section of its own in the copy uses that section
    local copySections = ns.Copy and ns.Copy.sections or {}
    local sectionKey = row.section or Settings:Text(row.key, "section")
        or (copySections[row.key] and row.key) or (moduleKey .. ".main")
    local section = module.sectionByKey[sectionKey]
    if not section then
        local title = (ns.Copy and ns.Copy.sections and ns.Copy.sections[sectionKey]) or row.sectionTitle
        section = { key = sectionKey, title = title, rows = {} }
        module.sectionByKey[sectionKey] = section
        module.sections[#module.sections + 1] = section
    end
    section.rows[#section.rows + 1] = row
    row.section = sectionKey
    self.rows[row.key] = row
    return row
end

--------------------------------------------------
-- 5. RELOAD FOOTER
-- A reload row or module switch is pending while its value differs from the session start.
--------------------------------------------------
function Settings:TrackReload(key, value, startValue)
    if value == startValue then
        self.pending[key] = nil
    else
        self.pending[key] = true
    end
    self:Fire("ReloadChanged")
end

function Settings:PendingCount()
    local n = 0
    for _ in pairs(self.pending) do n = n + 1 end
    return n
end

--------------------------------------------------
-- 6. SEARCH
--------------------------------------------------
local function Matches(row, words, moduleTitle)
    if row:IsHidden() or row.kind == "text" then return false end
    local haystack = row:SearchText() .. " " .. moduleTitle
    for _, word in ipairs(words) do
        if not haystack:find(word) then return false end
    end
    return true
end

-- Rows and Edit Mode stubs whose text holds every word
function Settings:Search(text)
    -- each word must start a word ("ids" finds "Show IDs", not "raids")
    local words = {}
    for word in text:lower():gmatch("%S+") do
        words[#words + 1] = "%f[%w]" .. word:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
    end
    local results = {}
    if #words == 0 then return results end
    for _, key in ipairs(self.order) do
        local module = self.modules[key]
        local moduleTitle = (module:Title() or ""):lower()
        for _, section in ipairs(module.sections) do
            for _, row in ipairs(section.rows) do
                if Matches(row, words, moduleTitle) then results[#results + 1] = row end
            end
        end
        -- a module that is off has no frames to search
        if module:IsOn() then
            for _, row in ipairs(module:EditModeRows()) do
                if Matches(row, words, moduleTitle) then results[#results + 1] = row end
            end
        end
    end
    return results
end

--------------------------------------------------
-- 7. CALLBACKS
--------------------------------------------------
local listeners = {}
function Settings:On(event, func)
    listeners[event] = listeners[event] or {}
    table.insert(listeners[event], func)
end

function Settings:Fire(event, ...)
    for _, func in ipairs(listeners[event] or {}) do
        local ok, err = pcall(func, ...)
        if not ok then geterrorhandler()(err) end
    end
end

--------------------------------------------------
-- 8. EDIT MODE
-- Frame rows and module.editFrames name FlareUI frames in Edit Mode: Edit selects the frame, each
-- frame's dialog links back to its page, and its settings are searchable as stub rows. Leaving Edit
-- Mode opened from the panel reopens the panel on the same page.
--------------------------------------------------
local LEM = LibStub and LibStub("FlareEditMode", true)
Settings.editModeReturn = nil   -- module key to reopen when Edit Mode closes

function Settings:CanEditFrames()
    return LEM and LEM.SelectFrame and not InCombatLockdown()
end

function Settings:EditFrame(frame, moduleKey)
    if not (frame and self:CanEditFrames()) then return false end
    local opened = LEM:SelectFrame(frame)
    if opened then
        self.editModeReturn = moduleKey
        if ns.SettingsPanel and ns.SettingsPanel:IsShown() then ns.SettingsPanel:Hide() end
    end
    return opened
end

-- Edit Mode with nothing selected (for Blizzard's bars)
function Settings:OpenEditMode(moduleKey)
    if not (self:CanEditFrames() and EditModeManagerFrame) then return false end
    if EditModeManagerFrame.CanEnterEditMode and not EditModeManagerFrame:CanEnterEditMode() then return false end
    self.editModeReturn = moduleKey
    if ns.SettingsPanel then ns.SettingsPanel:Hide() end
    ShowUIPanel(EditModeManagerFrame)
    return true
end

-- a module's frames: its frame rows plus module.editFrames getters
local function ModuleFrames(module)
    local frames, seen = {}, {}
    local function Add(frame)
        if frame and not seen[frame] then seen[frame] = true; frames[#frames + 1] = frame end
    end
    for _, section in ipairs(module.sections) do
        for _, row in ipairs(section.rows) do
            if type(row.frame) == "function" then Add(row.frame()) end
        end
    end
    for _, getter in ipairs(module.editFrames or {}) do Add(getter()) end
    return frames
end

-- a copy entry of this module whose label matches an Edit Mode setting name
local function CopyKeyForSetting(moduleKey, name)
    local lower = name:lower()
    for key, entry in pairs(ns.Copy and ns.Copy.rows or {}) do
        if entry.label and entry.label:lower() == lower and key:match("^" .. moduleKey .. "%.") then
            return key
        end
    end
end

local EditRow = setmetatable({}, { __index = Row })
EditRow.__index = EditRow
function EditRow:Label() return self.name end
function EditRow:Description()
    return self.copyKey and Settings:Text(self.copyKey, "desc") or nil
end
function EditRow:Tip() return self.copyKey and Settings:Text(self.copyKey, "tip") or nil end
function EditRow:IsHidden() return false end
function EditRow:IsDisabled() return not Settings:CanEditFrames() end
function EditRow:Get() return nil end

-- One stub row per Edit Mode setting of the module's frames, built on first search
function Module:EditModeRows()
    if self.editRows then return self.editRows end
    local rows = {}
    if LEM and LEM.GetFrameSettings then
        for _, frame in ipairs(ModuleFrames(self)) do
            local frameName = LEM:GetFrameName(frame) or "?"
            for _, setting in ipairs(LEM:GetFrameSettings(frame) or {}) do
                local name = type(setting.name) == "string" and setting.name
                if name and setting.kind ~= LEM.SettingType.Divider and setting.kind ~= LEM.SettingType.Expander then
                    rows[#rows + 1] = setmetatable({
                        key = "em:" .. frameName .. ":" .. name, kind = "editmode", module = self.key,
                        name = name, frame = frame, frameName = frameName,
                        copyKey = CopyKeyForSetting(self.key, name),
                    }, EditRow)
                end
            end
        end
    end
    self.editRows = rows
    return rows
end

-- After the modules made their frames: the back button in each dialog, and the return on exit
function Settings:LinkEditMode()
    if not (LEM and LEM.AddFrameSettingsButton) or self.linked then return end
    self.linked = true
    local backText = self:WindowText("editModeDialogsBackLink", L["FlareUI settings"])
    for _, key in ipairs(self.order) do
        local module = self.modules[key]
        for _, frame in ipairs(ModuleFrames(module)) do
            LEM:AddFrameSettingsButton(frame, {
                text = backText,
                click = function()
                    self.editModeReturn = nil
                    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then HideUIPanel(EditModeManagerFrame) end
                    if ns.SettingsPanel then ns.SettingsPanel:Open(key) end
                end,
            })
        end
    end
    LEM:RegisterCallback("exit", function()
        local back = self.editModeReturn
        self.editModeReturn = nil
        if back and ns.SettingsPanel and not InCombatLockdown() then
            C_Timer.After(0, function() ns.SettingsPanel:Open(back) end)
        end
    end)
end

do
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("PLAYER_LOGIN")
    loader:SetScript("OnEvent", function()
        -- one frame later, after Core started the modules
        C_Timer.After(0, function() Settings:LinkEditMode() end)
    end)
end

--------------------------------------------------
-- 9. HELPERS
--------------------------------------------------
-- get/set for a Bindings.xml action; a new key replaces the old ones, saved to the current binding set
function Settings:BindingAccessors(action)
    return {
        get = function() return GetBindingKey(action) or "" end,
        set = function(key)
            if InCombatLockdown() then return end
            local old1, old2 = GetBindingKey(action)
            if old1 then SetBinding(old1) end
            if old2 then SetBinding(old2) end
            if key and key ~= "" then SetBinding(key, action) end
            SaveBindings(GetCurrentBindingSet())
        end,
    }
end

-- Colours `code` spans of the copy in Blizzard's gold
function Settings:Format(text)
    if not text then return text end
    return (text:gsub("`([^`]+)`", "|cffffd100%1|r"))
end

