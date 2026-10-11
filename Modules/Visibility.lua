local _, ns = ...
local L = ns.L

--------------------------------------------------
-- VISIBILITY
-- When the action bars, the bag bar, the micro menu and the XP bar show (part of the Action Bars
-- module), and the Blizzard pieces hidden for good:
--   * each element has a Show choice: always | mouseover | combat | target | harm
--     (Combat + Target, Combat + Attackable Target); with any choice but always, pointing at the
--     element shows it too
--   * an element can join fade group 1-5: the group owns the Show choice and its members fade in
--     and out together (point at one, they all appear)
--   * Fake CM bars follow profile.fcm.show, never the mouse (they are click-through), and always
--     show in Fake CM setup mode, in Edit Mode, and while something is dragged
-- Both choices sit in each element's Edit Mode dialog (FlareEditMode:AddSystemSettings).
--------------------------------------------------

--------------------------------------------------
-- 1. MODULE REGISTRATION
--------------------------------------------------
ns.Visibility = ns.Visibility or {}
local Visibility = ns.Visibility
ns.modules["Visibility"] = Visibility

LibStub("AceEvent-3.0"):Embed(Visibility)
LibStub("AceHook-3.0"):Embed(Visibility)

local LEM = LibStub("FlareEditMode")

--------------------------------------------------
-- 2. UPVALUES
--------------------------------------------------
local _G = _G
local pairs, ipairs, next = pairs, ipairs, next
local table_insert = table.insert
local math_abs = math.abs
local math_min = math.min
local math_max = math.max
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local UnitExists = UnitExists
local UnitCanAttack = UnitCanAttack
local canaccessvalue = canaccessvalue

-- seconds a faded element waits before fading out: covers the gap between the bars of a group (the
-- fade itself takes the Fade Speed, ns.FADE_TIMES)
local FADE_DELAY = 0.08

--------------------------------------------------
-- 3. ELEMENTS
--------------------------------------------------
-- the elements with a Show choice, in Edit Mode order: Blizzard system and sub-system
local ELEMENTS = {
    { key = "bar1", frame = "MainActionBar", system = "ActionBar", index = "MainBar" },
    { key = "bar2", frame = "MultiBarBottomLeft", system = "ActionBar", index = "Bar2" },
    { key = "bar3", frame = "MultiBarBottomRight", system = "ActionBar", index = "Bar3" },
    { key = "bar4", frame = "MultiBarRight", system = "ActionBar", index = "RightBar1" },
    { key = "bar5", frame = "MultiBarLeft", system = "ActionBar", index = "RightBar2" },
    { key = "bar6", frame = "MultiBar5", system = "ActionBar", index = "ExtraBar1" },
    { key = "bar7", frame = "MultiBar6", system = "ActionBar", index = "ExtraBar2" },
    { key = "bar8", frame = "MultiBar7", system = "ActionBar", index = "ExtraBar3" },
    { key = "pet", frame = "PetActionBar", system = "ActionBar", index = "PetActionBar" },
    { key = "stance", frame = "StanceBar", system = "ActionBar", index = "StanceBar" },
    { key = "bags", frame = "BagsBar", system = "Bags" },
    { key = "menu", frame = "MicroMenuContainer", system = "MicroMenu" },
    { key = "xp" },   -- the FlareUI XP bar (its own Edit Mode frame)
}
Visibility.ELEMENTS = ELEMENTS
local ELEMENT_BY_KEY = {}
for _, e in ipairs(ELEMENTS) do ELEMENT_BY_KEY[e.key] = e end

-- the pieces that can only be hidden for good (Action Bars > Hide Blizzard elements)
local HIDE_FRAMES = {
    menu = "MicroMenuContainer", bags = "BagsBar", pet = "PetActionBar", stance = "StanceBar",
    possess = "PossessActionBar", totem = "MultiCastActionBarFrame", raid = "CompactRaidFrameManager",
}

local function GetFrame(key)
    if key == "xp" then
        return ns.XPBar and ns.XPBar.GetFrame and ns.XPBar:GetFrame() or nil
    end
    local name = HIDE_FRAMES[key] or (ELEMENT_BY_KEY[key] and ELEMENT_BY_KEY[key].frame)
    local f = name and _G[name]
    if key == "menu" and not f then f = _G.MicroButtonAndBagsBar end
    return f
end

-- The main bar's end caps: on Forever each is its own Edit Mode system and ignores its parent's
-- alpha, so bar 1's fade is applied to them too.
local function ForEachEndCap(func, ...)
    local caps = _G.MainActionBar and _G.MainActionBar.EndCaps
    if not caps then return end
    if caps.LeftEndCap then func(caps.LeftEndCap, ...) end
    if caps.RightEndCap then func(caps.RightEndCap, ...) end
end

local function SetCapAlpha(cap, alpha) cap:SetAlpha(alpha) end

local function ApplyElementAlpha(frame, key, alpha)
    frame:SetAlpha(alpha)
    if key == "bar1" then ForEachEndCap(SetCapAlpha, alpha) end
end

-- Runs func on every frame behind a hide key ("endcaps" is the two gryphon frames)
local function ForEachFrameOfKey(key, func, ...)
    if key == "endcaps" then
        ForEachEndCap(func, ...)
    else
        local frame = GetFrame(key)
        if frame then func(frame, ...) end
    end
end

local function GetDb()
    return ns.db and ns.db.profile and ns.db.profile.visibility
end

--------------------------------------------------
-- 4. SHOW CHOICES AND FADE GROUPS
--------------------------------------------------
local function ElementConfig(key)
    local db = GetDb()
    local elements = db and db.elements
    if not elements then return nil end
    elements[key] = elements[key] or { show = "always", group = 0 }
    return elements[key]
end

function Visibility:GetGroup(key)
    local cfg = ElementConfig(key)
    return cfg and cfg.group or 0
end

-- An element in a group takes the group's Show choice
function Visibility:GetShow(key)
    local db, cfg = GetDb(), ElementConfig(key)
    if not (db and cfg) then return "always" end
    local group = cfg.group and cfg.group > 0 and db.groups and db.groups[cfg.group]
    return (group and group.show) or cfg.show or "always"
end

function Visibility:SetShow(key, show)
    local db, cfg = GetDb(), ElementConfig(key)
    if not (db and cfg) then return end
    local group = cfg.group and cfg.group > 0 and db.groups and db.groups[cfg.group]
    if group then group.show = show else cfg.show = show end
    self:Refresh()
end

-- Joining a group adopts the group's choice; leaving one keeps it
function Visibility:SetGroup(key, group)
    local cfg = ElementConfig(key)
    if not cfg then return end
    if (group or 0) == 0 and (cfg.group or 0) > 0 then cfg.show = self:GetShow(key) end
    cfg.group = group or 0
    self:Refresh()
end

--------------------------------------------------
-- 5. SECURE HIDING AND EDIT MODE SELECTIONS OF HIDDEN FRAMES (invisible and unclickable)
--------------------------------------------------
local function ApplySecureHide(key, shouldHide)
    ForEachFrameOfKey(key, ns.HideFrameSecurely, shouldHide)
end

local function HideMoverOfFrame(frame)
    if frame and frame.Selection then
        frame.Selection.FlareUI_HiddenMover = true
        frame.Selection:SetAlpha(0)
        if frame.Selection.Label then frame.Selection.Label:SetAlpha(0) end
        frame:EnableMouse(false)
        frame.Selection:EnableMouse(false)
    end
end

local function RestoreMoverOfFrame(frame)
    if frame and frame.Selection then
        frame.Selection.FlareUI_HiddenMover = nil

        frame.Selection:SetAlpha(1)
        if frame.Selection.Label then frame.Selection.Label:SetAlpha(1) end

        if frame.EnableMouse then frame:EnableMouse(true) end
        if frame.Selection.EnableMouse then frame.Selection:EnableMouse(true) end
    end
end

local function HideEditModeMover(key) ForEachFrameOfKey(key, HideMoverOfFrame) end
local function RestoreEditModeMover(key) ForEachFrameOfKey(key, RestoreMoverOfFrame) end
-- the engine hide: Edit Mode's HideOverride re-anchors snapped frames under our taint
local function HideFrame(frame) ns.RawHide(frame) end

-- In Edit Mode Blizzard re-shows some hidden bars itself (the stance bar); each show is undone
local editHideHooked = {}
local function KeepHiddenInEditMode(frame, settingKey)
    if editHideHooked[frame] then return end
    editHideHooked[frame] = settingKey
    frame:HookScript("OnShow", function(f)
        local db = GetDb()
        local editing = _G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown()
        if db and db[editHideHooked[f]] and editing and not InCombatLockdown() then ns.RawHide(f) end
    end)
end

--------------------------------------------------
-- 6. FADER ENGINE
-- One OnUpdate for every faded element. It runs while something is mid-fade, a group is dirty, or a
-- faded element can be shown by the mouse (the one condition no event reports). Conditions are
-- checked on a throttled tick or when an event marks a group dirty; alpha steps every frame only
-- mid-fade.
--------------------------------------------------
local Fader = CreateFrame("Frame")
Fader.groups = {}
Fader.delays = {}
Fader.updateTimer = 0
Fader.dirty = {}
Fader.updateEnabled = false
Fader.watchesMouseover = false   -- recomputed by Refresh(), not per tick
Fader.fading = false             -- something was mid-fade on the last pass

-- true while the target is attackable (UnitCanAttack can be secret)
local function TargetIsHostile()
    if not UnitExists("target") then return false end
    local canAttack = UnitCanAttack("player", "target")
    return canaccessvalue(canAttack) and canAttack or false
end

local function ShowRule(show)
    if show == "always" then return true end
    if show == "mouseover" then return false end
    if InCombatLockdown() then return true end
    if show == "target" then return UnitExists("target") end
    if show == "harm" then return TargetIsHostile() end
    return false   -- combat
end

local function CheckMember(data)
    local editMode = _G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown()
    if editMode then return true end
    local fcmState = ns.ActionBars and ns.ActionBars.fcm
    -- every action bar shows while something is dragged onto them
    if data.isBar and fcmState and fcmState.wasDragging then return true end
    if data.fcm then
        return (fcmState and fcmState.unlockMode) or ShowRule(data.show)
    end
    if ShowRule(data.show) then return true end
    return data.frame:IsMouseOver()
end

-- An event may have changed a condition: every group is checked again, this frame
local function MarkAllDirty()
    for groupName in pairs(Fader.groups) do
        Fader.dirty[groupName] = true
    end
    if next(Fader.dirty) then
        Fader.UpdateScript(Fader, 0)
        if not Fader.updateEnabled then
            Fader:SetScript("OnUpdate", Fader.UpdateScript)
            Fader.updateEnabled = true
            Fader.updateTimer = 0
        end
    end
end

Fader.updateInterval = 0.05 -- condition checks (the mouse leaving a bar is noticed within this)
Fader.shows = {}            -- group -> whether it is fading in (from the last condition check)
Fader.counting = {}         -- group -> its fade-out delay is running down
Fader.UpdateScript = function(self, elapsed)
    self.updateTimer = self.updateTimer + elapsed
    local check = self.updateTimer >= self.updateInterval or next(self.dirty) ~= nil
    -- between checks only a running fade has work to do
    if not check and not self.fading then return end
    local tick = self.updateTimer
    if check then self.updateTimer = 0 end

    local hasActiveFades = false

    for groupName, members in pairs(self.groups) do
        if check or self.shows[groupName] == nil then
            local groupShouldShow = false
            for _, data in ipairs(members) do
                if CheckMember(data) then groupShouldShow = true break end
            end

            if not self.delays[groupName] then self.delays[groupName] = 0 end
            if groupShouldShow then self.delays[groupName] = FADE_DELAY
            elseif self.delays[groupName] > 0 then self.delays[groupName] = self.delays[groupName] - tick end

            self.shows[groupName] = groupShouldShow or (self.delays[groupName] > 0)
            self.counting[groupName] = (not groupShouldShow) and self.delays[groupName] > 0
        end
        local effectiveShow = self.shows[groupName]

        for _, data in ipairs(members) do
            local frame = data.frame
            local targetAlpha = effectiveShow and 1 or 0
            local currentAlpha = frame:GetAlpha()
            if math_abs(currentAlpha - targetAlpha) > 0.005 then
                hasActiveFades = true
                local db = GetDb()
                local speed = ns.FadeTime(db and db.fadeSpeed)
                local change = speed > 0 and (1 / speed) * elapsed or 1
                local newAlpha = (currentAlpha < targetAlpha) and math_min(targetAlpha, currentAlpha + change) or math_max(targetAlpha, currentAlpha - change)
                ApplyElementAlpha(frame, data.key, newAlpha)
            end
        end

        self.dirty[groupName] = nil
    end

    self.fading = hasActiveFades
    -- a fade still running, or a delay still counting down, keeps the loop going
    local delaying = next(self.counting) ~= nil
    for groupName, on in pairs(self.counting) do
        if not on then self.counting[groupName] = nil end
    end
    delaying = delaying and next(self.counting) ~= nil
    local idle = not hasActiveFades and not next(self.dirty) and not delaying
    if idle and not self.watchesMouseover then
        self:SetScript("OnUpdate", nil)
        self.updateEnabled = false
    else
        self.updateInterval = 0.05
    end
end

--------------------------------------------------
-- 7. EDIT MODE SETTINGS (Show and Fade group in each element's dialog)
--------------------------------------------------
local SHOW_VALUES = { "always", "mouseover", "combat", "target", "harm" }
local GROUP_VALUES = { 0, 1, 2, 3, 4, 5 }

local function Values(copyKey, list, fallback)
    local names = ns.Settings and ns.Settings:Text(copyKey, "choices") or {}
    local values = {}
    for i, value in ipairs(list) do
        values[i] = { text = names[i] or fallback(value), value = value, isRadio = true }
    end
    return values
end

local function Label(copyKey, fallback)
    return ns.Settings and ns.Settings:Text(copyKey, "label") or fallback
end

local function BuildElementSettings(key)
    return {
        {
            name = Label("ab.bar.show", L["Show"]), kind = LEM.SettingType.Dropdown, default = "always",
            values = Values("ab.bar.show", SHOW_VALUES, function(v) return v end),
            get = function() return Visibility:GetShow(key) end,
            set = function(_, value) Visibility:SetShow(key, value) end,
        },
        {
            name = Label("ab.bar.group", L["Fade group"]), kind = LEM.SettingType.Dropdown, default = 0,
            values = Values("ab.bar.group", GROUP_VALUES, function(v) return v == 0 and L["None"] or tostring(v) end),
            get = function() return Visibility:GetGroup(key) end,
            set = function(_, value) Visibility:SetGroup(key, value) end,
        },
    }
end

local systemsAdded, xpAdded = false, false
local function AddEditModeSettings()
    if not systemsAdded and Enum.EditModeSystem and Enum.EditModeActionBarSystemIndices then
        systemsAdded = true
        for _, e in ipairs(ELEMENTS) do
            local system = e.system and Enum.EditModeSystem[e.system]
            if system then
                local index = e.index and Enum.EditModeActionBarSystemIndices[e.index]
                if not e.index or index then LEM:AddSystemSettings(system, BuildElementSettings(e.key), index) end
            end
        end
    end
    -- the XP bar is a FlareUI frame: its two rows go after its own Width / Height
    local xp = GetFrame("xp")
    local settings = xp and LEM.GetFrameSettings and LEM:GetFrameSettings(xp)
    if settings and not xpAdded then
        xpAdded = true
        for _, setting in ipairs(BuildElementSettings("xp")) do table_insert(settings, setting) end
    end
end

--------------------------------------------------
-- 8. PUBLIC API
--------------------------------------------------
-- Part of the Action Bars module: loads with it
function Visibility:ShouldLoad()
    local ab = ns.db and ns.db.profile and ns.db.profile.actionbars
    return ab and ab.enabled or false
end

local HIDE_KEYS = {
    { "menu", "hideMicroMenu" }, { "bags", "hideBagBar" }, { "pet", "hidePetBar" },
    { "stance", "hideStanceBar" }, { "possess", "hidePossessBar" }, { "totem", "hideTotemBar" },
    { "raid", "hideRaidManager" }, { "endcaps", "hideEndCaps" },
}

local function AddMember(groupName, data)
    Fader.groups[groupName] = Fader.groups[groupName] or {}
    table_insert(Fader.groups[groupName], data)
end

function Visibility:Refresh()
    if InCombatLockdown() then return end
    local db = GetDb()
    if not db then return end
    if not self:ShouldLoad() then
        Fader:SetScript("OnUpdate", nil)
        Fader.updateEnabled = false
        return
    end

    -- In Edit Mode the secure hide is lifted (Edit Mode needs the frames); a frame set to hidden is
    -- hidden plainly instead, its selection made invisible.
    local inEditMode = _G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown()
    for _, pair in ipairs(HIDE_KEYS) do
        local key, settingKey = pair[1], pair[2]
        local hidden = db[settingKey]
        if inEditMode then
            ApplySecureHide(key, false)
            if hidden then
                ForEachFrameOfKey(key, KeepHiddenInEditMode, settingKey)
                ForEachFrameOfKey(key, HideFrame)
                HideEditModeMover(key)
            else
                RestoreEditModeMover(key)
            end
        else
            ApplySecureHide(key, hidden)
        end
    end

    Fader.groups = {}
    Fader.delays = {}
    Fader.dirty = {}
    Fader.shows = {}
    Fader.counting = {}
    Fader.watchesMouseover = false
    Fader.fading = false

    local fcm = ns.db.profile.fcm
    for _, e in ipairs(ELEMENTS) do
        local key = e.key
        local frame = GetFrame(key)
        if frame and frame.GetAlpha then
            local isBar = key:match("^bar[1-8]$") ~= nil
            local fcmBar = isBar and fcm and fcm.enabled and fcm.bars and fcm.bars[key]
            if fcmBar and fcmBar.enabled then
                -- Fake CM bars: their own rule, together, no mouse
                AddMember("fcm", { key = key, frame = frame, isBar = true, fcm = true, show = fcm.show or "combat" })
            else
                local show = self:GetShow(key)
                if show == "always" then
                    ApplyElementAlpha(frame, key, 1)
                else
                    local group = self:GetGroup(key)
                    AddMember(group > 0 and ("group" .. group) or key, { key = key, frame = frame, isBar = isBar, show = show })
                    Fader.watchesMouseover = true
                end
            end
        end
    end

    MarkAllDirty()
end

function Visibility:Init()
    if not GetDb() or not self:ShouldLoad() then return end
    self:Refresh()

    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnVisibilityStateChange")
    self:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED", "OnVisibilityStateChange")
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnVisibilityStateChange")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnVisibilityStateChange")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnVisibilityStateChange")

    if _G.EditModeManagerFrame then
        _G.EditModeManagerFrame:HookScript("OnShow", function() Visibility:Refresh() end)
        _G.EditModeManagerFrame:HookScript("OnHide", function() Visibility:Refresh() end)
    end
    -- the Show and Fade group rows: Blizzard's dialogs now, the XP bar's once it exists
    AddEditModeSettings()
    LEM:RegisterCallback("enter", AddEditModeSettings)
    -- In Edit Mode, toggling Raid / Party Frames makes Blizzard show the raid manager again
    hooksecurefunc("CompactRaidFrameManager_UpdateShown", function()
        local db = GetDb()
        if db and db.hideRaidManager and _G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown() then
            local manager = _G.CompactRaidFrameManager
            if manager and manager:IsShown() and not InCombatLockdown() then ns.RawHide(manager) end
        end
    end)
end

--------------------------------------------------
-- 9. EVENT HANDLERS
--------------------------------------------------
-- combat, target, Edit Mode...
function Visibility:OnVisibilityStateChange()
    MarkAllDirty()
end
