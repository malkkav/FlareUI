local ADDON_NAME, ns = ...
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
}
ns.Settings = Settings

local GROUPS = { "top", "HUD", "Info", "Tools", "bottom" }

-- Rows that get a NEW badge, by row key -> the version that added them ("2.5"). The badge shows while
-- FlareUI's version starts with it, until the player has opened the row's page once (db.global.newSeen).
-- Filled by tools/newtags.js on each release.
Settings.NEW = {
    ["ab.dimOnCooldown"] = "5.0",
    ["ab.xpQuest"] = "5.0",
    ["au.skinCDM"] = "5.0",
    ["au.timerColor"] = "5.0",
    ["ch.copyButton"] = "5.0",
    ["ch.minAlpha"] = "5.0",
    ["dm.minAlpha"] = "5.0",
    ["dm.pullFlash"] = "5.0",
    ["dm.pullLine"] = "5.0",
    ["dm.resetOnInstance"] = "5.0",
    ["dm.tankLead"] = "5.0",
    ["dm.threatValue"] = "5.0",
    ["mm.coordsHover"] = "5.0",
    ["mm.microMenu"] = "5.0",
    ["qol.bagButtons"] = "5.0",
    ["qol.bagColumns"] = "5.0",
    ["qol.bagGaps"] = "5.0",
    ["qol.bagJunkIcon"] = "5.0",
    ["qol.bagRarityBorders"] = "5.0",
    ["qol.bagThickBorders"] = "5.0",
    ["qol.bagUpgradeArrow"] = "5.0",
    ["qol.bulkBuy"] = "5.0",
    ["qol.fishCast"] = "5.0",
    ["qol.fishSound"] = "5.0",
    ["qol.mapFade"] = "5.0",
    ["qol.npLevelName"] = "5.0",
    ["qol.rumbleAlerts"] = "5.0",
    ["qol.rumbleProcs"] = "5.0",
    ["qol.taxiMap"] = "5.0",
    ["qt.gamepad"] = "5.0",
    ["qt.maxHeight"] = "5.0",
    ["qt.spacing"] = "5.0",
    ["qt.width"] = "5.0",
    ["rm.padBar"] = "5.0",
    ["rm.padLegend"] = "5.0",
    ["rm.padRelease"] = "5.0",
    ["rm.padRepeat"] = "5.0",
    ["rm.padStick"] = "5.0",
    ["rm.scale"] = "5.0",
    ["tt.compareShift"] = "5.0",
    ["uf.auraSwipe"] = "5.0",
    ["uf.auraTimerColor"] = "5.0",
}

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
    if text == nil and field == "label" and not optional then return key end
    return text
end

function Settings:ModuleText(key, field)
    local m = ns.Copy and ns.Copy.modules and ns.Copy.modules[key]
    local text = m and m[field]
    if text == nil and field == "title" then return key end
    return text
end

function Settings:SectionText(key)
    local text = ns.Copy and ns.Copy.sections and ns.Copy.sections[key]
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

-- Rows seen on the page open now: their badges stay until the player leaves it
local newShowing = {}

local function NewSeen()
    local global = ns.db and ns.db.global
    if not global then return nil end
    global.newSeen = global.newSeen or {}
    return global.newSeen
end

-- A fresh install: nothing is new to this player
function Settings:MarkAllNewSeen()
    local seen = NewSeen()
    if not seen then return end
    for key, since in pairs(self.NEW) do seen[key] = since end
end

function Settings:EndNewVisit()
    for key, row in pairs(newShowing) do
        row.searchText = nil
        newShowing[key] = nil
    end
end

-- The player opened this page: its badges count as seen, in one tab (or the whole module when tabKey is nil).
-- Saved at once, so a reload on the page counts too.
function Module:MarkNewSeen(tabKey)
    local seen = NewSeen()
    if not seen or not next(Settings.NEW) then return end
    for _, section in ipairs(self.sections) do
        for _, row in ipairs(section.rows) do
            if row:IsNew() and not row:IsHidden()
                and (tabKey == nil or not self.tabs or (row.tab or self.tabs[1].key) == tabKey) then
                seen[row.key] = Settings.NEW[row.key]
                newShowing[row.key] = row
                row.searchText = nil
            end
        end
    end
end

-- Any visible row with a NEW badge, in one tab (or the whole module when tabKey is nil)
function Module:HasNew(tabKey)
    for _, section in ipairs(self.sections) do
        for _, row in ipairs(section.rows) do
            if row:IsNew() and not row:IsHidden()
                and (tabKey == nil or not self.tabs or (row.tab or self.tabs[1].key) == tabKey) then
                return true
            end
        end
    end
    return false
end

-- Any page the player could open that still has a NEW badge
function Settings:AnyNew()
    for _, module in pairs(self.modules) do
        if module:IsOn() and module:HasNew() then return true end
    end
    return false
end

-- def: key, group, order, enabled ("db.path"), editMode, editFrames, banner, navIcon, navIconRound,
-- headerButton (returns text, onClick: takes the Edit Mode button's place), custom,
-- tabs ({ key, custom = build(host, previewHost), refresh, preview })
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

local addonVersion   -- read once
function Row:IsNew()
    local since = Settings.NEW[self.key]
    if not since then return false end
    addonVersion = addonVersion or C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or ""
    local version = addonVersion
    if not (version == since or version:sub(1, #since + 1) == since .. ".") then return false end
    if newShowing[self.key] then return true end
    local seen = ns.db and ns.db.global and ns.db.global.newSeen
    return not (seen and seen[self.key] == since)
end

function Row:IsHidden()
    return self.hidden and self.hidden() or false
end

-- Greyed when its own check says so or its parent row is off
function Row:IsDisabled()
    if self.disabled and self.disabled() then return true end
    -- a row of a module that is off (found by search) does nothing until the module is on
    local module = Settings.modules[self.module]
    if module and module.IsOn and not module:IsOn() then return true end
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

-- Faded Opacity: how far a fading frame fades, 0% to 90%
function Settings:MinAlphaChoices()
    local list = {}
    for i = 0, 9 do list[#list + 1] = { i / 10, (i * 10) .. "%" } end
    return list
end

-- Frame Opacity choices: 0% to 100% in tens, stored as 0..1
function Settings:OpacityChoices()
    local list = {}
    for i = 0, 10 do list[#list + 1] = { i / 10, (i * 10) .. "%" } end
    return list
end

-- Choice names come from the row's own { value, "text" } pairs, else the copy (in order, dividers
-- not counted)
function Row:Choices()
    local list = {}
    local names = Settings:Text(self.key, "choices")
    local choices = self.choices
    if type(choices) == "function" then choices = choices() end
    local n = 0
    for i, choice in ipairs(choices or {}) do
        if type(choice) == "table" and choice.divider then
            list[i] = { divider = true }
        else
            n = n + 1
            local value, text = choice, nil
            if type(choice) == "table" then value, text = choice[1], choice[2] end
            list[i] = { value = value, text = text or (names and names[n]) or tostring(value) }
        end
    end
    return list
end

-- Search ignores case and accents: "ecran" finds "Écran"
function Settings:Fold(text)
    if CaseAccentInsensitiveParse then text = CaseAccentInsensitiveParse(text) end
    return text:lower()
end

-- Label, info title, description, tip and copy tags, folded and cached
function Row:SearchText()
    if not self.searchText then
        local parts = { self:Label() or "", Settings:Text(self.key, "info") or "", self:Description() or "", self:Tip() or "" }
        for _, tag in ipairs(Settings:Text(self.key, "tags") or {}) do parts[#parts + 1] = tag end
        -- the word "new" finds every row with a NEW badge
        if self:IsNew() then parts[#parts + 1] = L["new"] end
        self.searchText = Settings:Fold(table.concat(parts, " "))
    end
    return self.searchText
end

-- A section's rows in one order (12-terminology.md, Ordering): copy text, then dropdowns, then
-- switches, then keybinds, buttons and legends. A row with a parent sits under it, among its siblings
-- in the same order; lead = true keeps a row on top (a switch the others read the other way round);
-- rank = n places a row by hand (Fake CM's Visibility: 3.5, between the bar switches and the button).
local KIND_RANK = { text = 0, choice = 1, dropdown = 1, toggle = 3, frame = 3, keybind = 4, button = 4, buttons = 4,
                    editmode = 4, legend = 5, expander = 5 }
local function RowRank(row)
    if row.lead then return -1 end
    if row.rank then return row.rank end
    return KIND_RANK[row.kind] or 4
end
local function InsertOrdered(list, row)
    local rank = RowRank(row)
    if row.parent then
        local at
        for i, r in ipairs(list) do
            if r.key == row.parent then at = i end
        end
        if at then
            local last = at
            while list[last + 1] and list[last + 1].parent == row.parent do last = last + 1 end
            for i = at + 1, last do
                if RowRank(list[i]) > rank then table.insert(list, i, row) return end
            end
            table.insert(list, last + 1, row)
            return
        end
    end
    for i, r in ipairs(list) do
        if not r.parent and RowRank(r) > rank then table.insert(list, i, row) return end
    end
    list[#list + 1] = row
end

-- def: key ("module.row"), kind, path ("db.path") or get/set, choices, parent, tab, section, half,
-- reload, apply, hidden, disabled, lead, rank, gapAbove. Kinds: toggle, choice, dropdown, keybind, button, buttons, frame,
-- expander, editmode, legend (built in Settings/Panel.lua), text (custom-page copy, never drawn or searched)
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
        local title = ns.Copy and ns.Copy.sections and ns.Copy.sections[sectionKey]
        section = { key = sectionKey, title = title, rows = {} }
        module.sectionByKey[sectionKey] = section
        module.sections[#module.sections + 1] = section
    end
    InsertOrdered(section.rows, row)
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
-- the tab and section a row sits in, folded and cached: "fonts" finds every Fonts tab's rows
local function ContextText(row)
    if row.contextText then return row.contextText end
    local module = Settings.modules[row.module]
    local parts = {}
    if module and module.tabs and row.tab then
        local names = Settings:ModuleText(module.key, "tabs") or {}
        for i, tab in ipairs(module.tabs) do
            if tab.key == row.tab and names[i] then parts[#parts + 1] = names[i] end
        end
    end
    local section = module and row.section and module.sectionByKey[row.section]
    if section and section.title then parts[#parts + 1] = section.title end
    row.contextText = Settings:Fold(table.concat(parts, " "))
    return row.contextText
end

-- Other words for the same thing (folded), so "transparency" finds Opacity and "hotkey" finds Keybind
local SYNONYMS = {
    transparency = { "opacity", "alpha" }, transparent = { "opacity", "alpha" }, alpha = { "opacity" },
    opacity = { "alpha" }, hotkey = { "keybind", "key" }, hotkeys = { "keybind", "key" },
    keybind = { "key" }, binding = { "keybind", "key" }, aggro = { "threat" }, threat = { "aggro" },
    xp = { "experience" }, experience = { "xp" }, exp = { "xp", "experience" },
    plates = { "nameplate" }, plate = { "nameplate" }, inventory = { "bag" }, backpack = { "bag" },
    color = { "colour" }, colour = { "color" }, colors = { "colour" }, hover = { "mouseover" },
    mouse = { "mouseover" }, castbar = { "cast bar" }, buff = { "aura" }, debuff = { "aura" },
    hp = { "health" }, mana = { "power" }, combo = { "combo point" }, ping = { "marker" },
}

-- One typed word as the patterns that may find it: itself, its singular, its other words. Each must
-- start a word ("ids" finds "Show IDs", not "raids"); a word that begins with no letter or digit
-- ("/way", or a non-Latin script) can't pass that test and may match anywhere.
local function WordPatterns(word)
    local list, seen = {}, {}
    local function Add(text)
        if seen[text] or text == "" then return end
        seen[text] = true
        local escaped = text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
        list[#list + 1] = (text:find("^%w") and "%f[%w]" or "") .. escaped
    end
    Add(word)
    if #word > 3 and word:sub(-1) == "s" then Add(word:sub(1, -2)) end
    for _, other in ipairs(SYNONYMS[word] or {}) do Add(other) end
    -- run together ("castbar"): also looked for with the spaces taken out of the text
    list.joined = #word >= 5 and (word:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) or nil
    return list
end

local function AllWords(haystack, words)
    local joined   -- the text without spaces, made only when a word needs it
    for _, patterns in ipairs(words) do
        local found = false
        for _, pattern in ipairs(patterns) do
            if haystack:find(pattern) then found = true break end
        end
        if not found then
            if not patterns.joined then return false end
            joined = joined or haystack:gsub("%s+", "")
            if not joined:find(patterns.joined) then return false end
        end
    end
    return true
end

local function Matches(row, words, moduleTitle)
    if row.kind == "text" then return false end
    -- a row folded away under a closed heading is still found (opening it shows it)
    if row:IsHidden() and not row.collapsedBy then return false end
    return AllWords(row:SearchText() .. " " .. moduleTitle .. " " .. ContextText(row), words)
end

-- A tab or titled section whose name holds every word, as one result that opens it
local function PlaceResult(module, label, tabKey, sectionKey)
    local row = setmetatable({
        key = "link:" .. module.key .. ":" .. (sectionKey or tabKey or ""), kind = "button", module = module.key,
        tab = tabKey, section = sectionKey, buttonText = L["Open"],
        labelFn = function() return label end,
    }, Row)
    row.apply = function() if ns.SettingsPanel then ns.SettingsPanel:JumpTo(row) end end
    function row:SearchText() return "" end
    function row:IsDisabled() return false end   -- opening a page always works (an off module shows its card)
    return row
end

-- Rows and Edit Mode stubs whose text holds every word, tabs and sections first; within those,
-- rows whose own name holds every word come before rows found by their description
function Settings:Search(text)
    local words = {}
    for word in self:Fold(text):gmatch("%S+") do words[#words + 1] = WordPatterns(word) end
    local results = {}
    if #words == 0 then return results end
    local places, strong, weak = {}, {}, {}
    for _, key in ipairs(self.order) do
        local module = self.modules[key]
        local moduleTitle = self:Fold(module:Title() or "")
        -- the module's tabs and section titles
        if module.tabs then
            local names = self:ModuleText(key, "tabs") or {}
            for i, tab in ipairs(module.tabs) do
                local name = names[i]
                if name and AllWords(self:Fold(name), words) then
                    places[#places + 1] = PlaceResult(module, name, tab.key, nil)
                end
            end
        end
        for _, section in ipairs(module.sections) do
            if section.title and AllWords(self:Fold(section.title), words) then
                local first = section.rows[1]
                places[#places + 1] = PlaceResult(module, section.title, first and first.tab, section.key)
            end
            for _, row in ipairs(section.rows) do
                if Matches(row, words, moduleTitle) then
                    local name = self:Fold(row:Label() or "")
                    if AllWords(name, words) then strong[#strong + 1] = row else weak[#weak + 1] = row end
                end
            end
        end
        -- a module that is off has no frames to search
        if module:IsOn() then
            for _, row in ipairs(module:EditModeRows()) do
                if Matches(row, words, moduleTitle) then weak[#weak + 1] = row end
            end
        end
    end
    for _, list in ipairs({ places, strong, weak }) do
        for _, row in ipairs(list) do results[#results + 1] = row end
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

-- Not in the Gamepad UI: Edit Mode opened from addon code registers with Blizzard's controller focus
-- inside FlareUI's call, and its bindings then run tainted (the game menu's Edit Mode is fine there)
function Settings:CanEditFrames()
    return LEM and LEM.SelectFrame and not InCombatLockdown() and not ns.IsGamepadUI()
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
-- (one label -> key map per module, made on first use)
local labelKeys = {}
local function CopyKeyForSetting(moduleKey, name)
    local map = labelKeys[moduleKey]
    if not map then
        map = {}
        local prefix = moduleKey .. "."
        for key, entry in pairs(ns.Copy and ns.Copy.rows or {}) do
            if entry.label and key:sub(1, #prefix) == prefix then
                local lower = entry.label:lower()
                -- the first key in sorted order wins, so the pick never changes between sessions
                if not map[lower] or key < map[lower] then map[lower] = key end
            end
        end
        labelKeys[moduleKey] = map
    end
    return map[name:lower()]
end

local EditRow = setmetatable({}, { __index = Row })
EditRow.__index = EditRow
function EditRow:Label() return self.name end
function EditRow:Description()
    return self.copyKey and Settings:Text(self.copyKey, "desc") or nil
end
function EditRow:Tip() return self.copyKey and Settings:Text(self.copyKey, "tip") or nil end
-- a setting its dialog hides right now (Fade Speed on a frame that's always shown) isn't listed
function EditRow:IsHidden()
    local hidden = self.setting and self.setting.hidden
    if type(hidden) == "function" then
        local ok, result = pcall(hidden, LEM.GetActiveLayoutName and LEM:GetActiveLayoutName())
        return ok and result and true or false
    end
    return hidden and true or false
end
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
                        name = name, frame = frame, frameName = frameName, setting = setting,
                        copyKey = CopyKeyForSetting(self.key, name),
                    }, EditRow)
                end
            end
        end
    end
    -- settings FlareUI adds to Blizzard's own Edit Mode systems (action bars, the minimap): found
    -- the same way; their Edit button opens Edit Mode (selecting a Blizzard system from here could taint)
    local systems = self.editSystems
    if type(systems) == "function" then systems = systems() end
    for _, system in ipairs(LEM and systems or {}) do
        local list
        if system.index then
            list = LEM.subSystemSettings and LEM.subSystemSettings[system.system] and LEM.subSystemSettings[system.system][system.index]
        else
            list = LEM.systemSettings and LEM.systemSettings[system.system]
        end
        local frameName = system.name or "?"
        for _, setting in ipairs(list or {}) do
            local name = type(setting.name) == "string" and setting.name
            if name and not name:find("|c", 1, true) and setting.kind ~= LEM.SettingType.Divider
                and setting.kind ~= LEM.SettingType.Expander then
                rows[#rows + 1] = setmetatable({
                    key = "em:" .. frameName .. ":" .. name, kind = "editmode", module = self.key,
                    name = name, frame = nil, frameName = frameName, setting = setting,
                    copyKey = CopyKeyForSetting(self.key, name),
                }, EditRow)
            end
        end
    end
    self.editRows = rows
    return rows
end

-- After the modules made their frames: the back button in each dialog, and the return on exit
function Settings:LinkEditMode()
    -- none in the Gamepad UI: closing Edit Mode from addon code there taints Blizzard's controller focus
    if not (LEM and LEM.AddFrameSettingsButton) or self.linked or ns.IsGamepadUI() then return end
    self.linked = true
    local backText = self:WindowText("editModeDialogsBackLink", L["FlareUI Settings"])
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
    -- settings added while Edit Mode opens (fade rows) are searchable from then: the stubs are made again
    local function ForgetStubs()
        for _, module in pairs(self.modules) do module.editRows = nil end
    end
    LEM:RegisterCallback("enter", ForgetStubs)
    LEM:RegisterCallback("exit", function()
        ForgetStubs()
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
-- asked before a key bound to something else is taken over
ns.Dialogs = ns.Dialogs or {}
ns.Dialogs["FLAREUI_KEY_TAKEN"] = {
    text = "%s",
    button1 = L["Use It"],
    button2 = L["Cancel"],
    OnAccept = function(data)
        if data and data.apply then data.apply() end
        if ns.SettingsPanel and ns.SettingsPanel.Refresh then ns.SettingsPanel:Refresh() end
    end,
    hideOnEscape = true,
}

-- get/set for a Bindings.xml action; a new key replaces the old ones, saved to the current binding set
function Settings:BindingAccessors(action)
    return {
        get = function() return GetBindingKey(action) or "" end,
        set = function(key)
            if InCombatLockdown() then
                print("|cffff9900FlareUI:|r " .. L["key bindings can't change during a fight."])
                return
            end
            local function Apply()
                if InCombatLockdown() then return end
                local old1, old2 = GetBindingKey(action)
                if old1 then SetBinding(old1) end
                if old2 then SetBinding(old2) end
                if key and key ~= "" then SetBinding(key, action) end
                SaveBindings(GetCurrentBindingSet())
            end
            local taken = key and key ~= "" and GetBindingAction(key)
            if taken and taken ~= "" and taken ~= action then
                local name = GetBindingName and GetBindingName(taken)
                ns.ShowDialog("FLAREUI_KEY_TAKEN",
                    L["%s is bound to %s. Use it anyway?"]:format(GetBindingText and GetBindingText(key) or key,
                        (name and name ~= "") and name or taken),
                    { apply = Apply })
                return
            end
            Apply()
        end,
    }
end

-- Colours `code` spans of the copy in Blizzard's gold
function Settings:Format(text)
    if not text then return text end
    return (text:gsub("`([^`]+)`", "|cffffd100%1|r"))
end

