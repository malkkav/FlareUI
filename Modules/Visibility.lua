local _, ns = ...
local L = ns.L

--------------------------------------------------
-- VISIBILITY
-- Show choices (always | mouseover | combat | target | harm), fade groups 1-5, Fade Speed and Min Alpha
-- for the action bars, bag bar, micro menu, XP bar and minimap, set in each element's Edit Mode dialog,
-- plus the Blizzard pieces hidden for good. Fake CM bars follow profile.fcm.show and never the mouse.
--------------------------------------------------

--------------------------------------------------
-- 1. MODULE REGISTRATION
--------------------------------------------------
ns.Visibility = ns.Visibility or {}
local Visibility = ns.Visibility
ns.modules["Visibility"] = Visibility

LibStub("AceEvent-3.0"):Embed(Visibility)

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

-- wait before fading out: covers the mouse crossing the gap between the bars of a group
local FADE_DELAY = 0.08

--------------------------------------------------
-- 3. ELEMENTS
--------------------------------------------------
-- in Edit Mode order, with their Blizzard system and sub-system
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
    { key = "xp" },   -- FlareUI's XP bar, its own Edit Mode frame
    { key = "minimap", frame = "MinimapCluster", needsMinimap = true },   -- with the Minimap module
}
local ELEMENT_BY_KEY = {}
for _, e in ipairs(ELEMENTS) do ELEMENT_BY_KEY[e.key] = e end

-- pieces that can only be hidden for good ("Hide Blizzard elements")
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

-- On Forever each end cap is its own Edit Mode system and ignores its parent's alpha: bar 1's fade
-- is applied to them too
local function ForEachEndCap(func, ...)
    local caps = _G.MainActionBar and _G.MainActionBar.EndCaps
    if not caps then return end
    if caps.LeftEndCap then func(caps.LeftEndCap, ...) end
    if caps.RightEndCap then func(caps.RightEndCap, ...) end
end

local function SetCapAlpha(cap, alpha) cap:SetAlpha(alpha) end

-- The game draws the minimap's player arrow, quest marks and other blips itself, at full strength
-- whatever the alpha, and has no API for them: only hiding the map removes them. So the map goes once
-- it has faded right out (the cluster stays, so pointing at it still brings it back), which is why it
-- has no Min Alpha, and no fade group that could give it one.
local minimapFadedOut = false
local function SetMinimapDrawn(alpha)
    local map = _G.Minimap
    if not map or (InCombatLockdown() and map:IsProtected()) then return end
    if alpha <= 0.01 then
        if map:IsShown() then
            if not map.FlareUI_FadeHooked then
                map.FlareUI_FadeHooked = true
                -- Blizzard may show it again: it stays out until the fade comes back
                map:HookScript("OnShow", function(self)
                    if minimapFadedOut then self:Hide() end
                end)
            end
            minimapFadedOut = true
            map:Hide()
        end
    elseif minimapFadedOut then
        minimapFadedOut = false
        map:Show()
    end
end

local function ApplyElementAlpha(frame, key, alpha)
    frame:SetAlpha(alpha)
    if key == "bar1" then ForEachEndCap(SetCapAlpha, alpha) end
    if key == "minimap" then SetMinimapDrawn(alpha) end
end

-- "endcaps" is the two gryphon frames
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

local function ActionBarsOn()
    local ab = ns.db and ns.db.profile and ns.db.profile.actionbars
    return ab and ab.enabled or false
end

local function MinimapOn()
    local mm = ns.db and ns.db.profile and ns.db.profile.minimap
    return mm and mm.enabled or false
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

-- an element in a group takes the group's Show choice
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

-- The group an element is in, or nil. A group owns its members' Show, Fade Speed and Min Alpha.
local function ElementGroup(key)
    local db, cfg = GetDb(), ElementConfig(key)
    return cfg and cfg.group and cfg.group > 0 and db.groups and db.groups[cfg.group] or nil
end

-- a setup from before these were per element keeps its one Fade Speed
function Visibility:GetFadeSpeed(key)
    local db, owner = GetDb(), ElementGroup(key) or ElementConfig(key)
    return (owner and owner.fadeSpeed) or (db and db.fadeSpeed) or "instant"
end

-- in percent
function Visibility:GetMinAlpha(key)
    local owner = ElementGroup(key) or ElementConfig(key)
    return owner and owner.minAlpha or 0
end

function Visibility:SetElementFade(key, field, value)
    local owner = ElementGroup(key) or ElementConfig(key)
    if not owner then return end
    owner[field] = value
    self:Refresh()
end

-- anyone else in this group?
local function GroupHasMembers(group, exceptKey)
    local db = GetDb()
    for elementKey, cfg in pairs(db and db.elements or {}) do
        if elementKey ~= exceptKey and cfg.group == group then return true end
    end
    return false
end

-- Joining a group takes on what's set for it; the first member brings its own choices. Leaving keeps them.
function Visibility:SetGroup(key, group)
    local db, cfg = GetDb(), ElementConfig(key)
    if not (db and cfg) then return end
    group = group or 0
    if group == (cfg.group or 0) then return end
    local show, speed, minAlpha = self:GetShow(key), self:GetFadeSpeed(key), self:GetMinAlpha(key)
    local target = db.groups and db.groups[group]
    if group == 0 then
        target = cfg
    elseif target and GroupHasMembers(group, key) then
        target = nil
    end
    if target then target.show, target.fadeSpeed, target.minAlpha = show, speed, minAlpha end
    cfg.group = group
    self:Refresh()
    -- the dialog's other rows now show the group's values (after the dropdown's own click)
    C_Timer.After(0, function() LEM:RefreshOpenSettings() end)
end

--------------------------------------------------
-- 5. SECURE HIDING AND EDIT MODE SELECTIONS OF HIDDEN FRAMES
--------------------------------------------------
local function ApplySecureHide(key, shouldHide)
    ForEachFrameOfKey(key, ns.HideFrameSecurely, shouldHide)
end

local function HideMoverOfFrame(frame)
    if frame and frame.Selection then
        if not frame.Selection.FlareUI_HiddenMover then
            frame.Selection.FlareUI_HiddenMover = true
            frame.FlareUI_MouseWas = frame:IsMouseEnabled()
        end
        frame.Selection:SetAlpha(0)
        if frame.Selection.Label then frame.Selection.Label:SetAlpha(0) end
        frame:EnableMouse(false)
        frame.Selection:EnableMouse(false)
    end
end

-- only a selection hidden above is restored, with the frame's own mouse setting
local function RestoreMoverOfFrame(frame)
    if frame and frame.Selection and frame.Selection.FlareUI_HiddenMover then
        frame.Selection.FlareUI_HiddenMover = nil
        frame.Selection:SetAlpha(1)
        if frame.Selection.Label then frame.Selection.Label:SetAlpha(1) end
        frame:EnableMouse(frame.FlareUI_MouseWas ~= false)
        frame.FlareUI_MouseWas = nil
        frame.Selection:EnableMouse(true)
    end
end

local function HideEditModeMover(key) ForEachFrameOfKey(key, HideMoverOfFrame) end
local function RestoreEditModeMover(key) ForEachFrameOfKey(key, RestoreMoverOfFrame) end
-- the engine hide: Edit Mode's HideOverride would re-anchor snapped frames under FlareUI's taint
local function HideFrame(frame) ns.RawHide(frame) end

-- in Edit Mode Blizzard re-shows some hidden bars itself (the stance bar)
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

-- A micro button with news (a new mount) flashes through UIFrameFlash, which shows its textures again
-- every frame: in a hidden menu they go blank, which touches none of Blizzard's alert state
local blankedFlashes = {}   -- texture -> its atlas
local function SetFlashBlank(texture, blank)
    if not texture then return end
    if blank then
        local atlas = not blankedFlashes[texture] and texture:GetAtlas()
        if atlas then
            blankedFlashes[texture] = atlas
            texture:SetTexture(nil)
        end
    elseif blankedFlashes[texture] then
        texture:SetAtlas(blankedFlashes[texture])
        blankedFlashes[texture] = nil
    end
end

local function SetMicroFlashesBlank(blank)
    local menu = _G.MicroMenu
    if not menu then return end
    for _, button in ipairs({ menu:GetChildren() }) do
        SetFlashBlank(button.FlashBorder, blank)
        SetFlashBlank(button.FlashContent, blank)
    end
end

-- The tips on those buttons ("unopened collectibles") sit on UIParent, so they outlive the menu. Closing
-- one from here would taint Blizzard's alert state and tip pool: it stays open, unseen and unclickable.
-- Pooled frames go to other tips too, so each HelpTip:Show sorts out every active one.
local maskedTips = {}   -- tip -> its mouse setting
local function SetTipMasked(tip, masked)
    if masked and maskedTips[tip] == nil then
        maskedTips[tip] = tip:IsMouseEnabled()
        tip:SetAlpha(0)
        tip:EnableMouse(false)
        tip.CloseButton:EnableMouse(false)
    elseif not masked and maskedTips[tip] ~= nil then
        tip:SetAlpha(1)
        tip:EnableMouse(maskedTips[tip])
        tip.CloseButton:EnableMouse(true)
        maskedTips[tip] = nil
    end
end

local function UpdateMicroTips()
    local db = GetDb()
    local hidden = db and db.hideMicroMenu and ActionBarsOn()
    for tip in _G.HelpTip.framePool:EnumerateActive() do
        SetTipMasked(tip, hidden and tip.info and tip.info.system == "MicroButtons" or false)
    end
end

--------------------------------------------------
-- 6. FADER ENGINE
-- One OnUpdate for every faded element, running only while something fades, a group is dirty, or
-- an element can be shown by the mouse (no event reports that). Conditions are checked on a
-- throttled tick or when marked dirty; alpha steps every frame only mid-fade.
--------------------------------------------------
local Fader = CreateFrame("Frame")
Fader.groups = {}
Fader.delays = {}
Fader.updateTimer = 0
Fader.dirty = {}
Fader.updateEnabled = false
Fader.watchesMouseover = false   -- set by Refresh(), not per tick
Fader.fading = false             -- something was mid-fade on the last pass

-- UnitCanAttack can be secret
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

-- an event may have changed a condition: every group is checked again this frame
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

local CHECK_INTERVAL = 0.05  -- seconds between condition checks
Fader.shows = {}            -- group -> fading in, from the last condition check
Fader.counting = {}         -- group -> its fade-out delay is running down
Fader.UpdateScript = function(self, elapsed)
    self.updateTimer = self.updateTimer + elapsed
    local check = self.updateTimer >= CHECK_INTERVAL or next(self.dirty) ~= nil
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
            local targetAlpha = effectiveShow and 1 or data.minAlpha
            local currentAlpha = frame:GetAlpha()
            if math_abs(currentAlpha - targetAlpha) > 0.005 then
                hasActiveFades = true
                local change = data.fadeTime > 0 and elapsed / data.fadeTime or 1
                local newAlpha = (currentAlpha < targetAlpha) and math_min(targetAlpha, currentAlpha + change) or math_max(targetAlpha, currentAlpha - change)
                ApplyElementAlpha(frame, data.key, newAlpha)
            end
        end

        self.dirty[groupName] = nil
    end

    self.fading = hasActiveFades
    -- a running fade or fade-out delay keeps the loop going
    for groupName, on in pairs(self.counting) do
        if not on then self.counting[groupName] = nil end
    end
    local idle = not hasActiveFades and not next(self.dirty) and not next(self.counting)
    if idle and not self.watchesMouseover then
        self:SetScript("OnUpdate", nil)
        self.updateEnabled = false
    end
end

--------------------------------------------------
-- 7. EDIT MODE SETTINGS
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

local SPEED_VALUES = { { text = L["Instant"], value = "instant", isRadio = true },
                       { text = L["Fast"], value = "fast", isRadio = true },
                       { text = L["Slow"], value = "slow", isRadio = true } }

local function BuildElementSettings(key)
    -- nothing fades while it's always shown
    local function AlwaysShown() return Visibility:GetShow(key) == "always" end
    return {
        {
            name = Label("ab.bar.group", L["Fade group"]), kind = LEM.SettingType.Dropdown, default = 0,
            values = Values("ab.bar.group", GROUP_VALUES, function(v) return v == 0 and L["None"] or tostring(v) end),
            get = function() return Visibility:GetGroup(key) end,
            set = function(_, value) Visibility:SetGroup(key, value) end,
        },
        {
            name = Label("ab.bar.show", L["Show"]), kind = LEM.SettingType.Dropdown, default = "always",
            values = Values("ab.bar.show", SHOW_VALUES, function(v) return v end),
            get = function() return Visibility:GetShow(key) end,
            set = function(_, value) Visibility:SetShow(key, value) end,
        },
        {
            name = L["Fade Speed"], kind = LEM.SettingType.Dropdown, default = "instant", values = SPEED_VALUES,
            get = function() return Visibility:GetFadeSpeed(key) end,
            set = function(_, value) Visibility:SetElementFade(key, "fadeSpeed", value) end,
            hidden = AlwaysShown,
            desc = L["How fast it appears and disappears.\n* Fast: 0.2 seconds\n* Slow: 0.4 seconds"],
        },
        {
            name = L["Min Alpha"], kind = LEM.SettingType.Slider, default = 0, minValue = 0, maxValue = 100, valueStep = 5,
            formatter = function(value) return value .. "%" end,
            get = function() return Visibility:GetMinAlpha(key) end,
            set = function(_, value) Visibility:SetElementFade(key, "minAlpha", value) end,
            hidden = AlwaysShown,
            desc = L["How see-through it gets when faded. 0% is invisible."],
        },
    }
end

-- The rows under a Visibility title that always stays open
local function WithVisibilityTitle(rows)
    table_insert(rows, 1, { name = "|cffffd100" .. L["Visibility"] .. "|r", kind = LEM.SettingType.Expander,
        static = true, hideArrow = true, get = function() return true end, set = function() end })
    return rows
end

-- for the Minimap module
function Visibility:MinimapSettings()
    local rows = BuildElementSettings("minimap")
    table.remove(rows, 4)   -- Min Alpha
    table.remove(rows, 1)   -- Fade group
    return WithVisibilityTitle(rows)
end

local systemsAdded, xpAdded = false, false
local function AddEditModeSettings()
    if not systemsAdded and ActionBarsOn() and Enum.EditModeSystem and Enum.EditModeActionBarSystemIndices then
        systemsAdded = true
        for _, e in ipairs(ELEMENTS) do
            local system = e.system and Enum.EditModeSystem[e.system]
            if system then
                local index = e.index and Enum.EditModeActionBarSystemIndices[e.index]
                if not e.index or index then
                    LEM:AddSystemSettings(system, WithVisibilityTitle(BuildElementSettings(e.key)), index)
                end
            end
        end
    end
    -- the XP bar is a FlareUI frame: its rows go after its own Width / Height
    local xp = GetFrame("xp")
    local settings = xp and LEM.GetFrameSettings and LEM:GetFrameSettings(xp)
    if settings and not xpAdded then
        xpAdded = true
        for _, setting in ipairs(WithVisibilityTitle(BuildElementSettings("xp"))) do table_insert(settings, setting) end
    end
end

--------------------------------------------------
-- 8. PUBLIC API
--------------------------------------------------
-- part of the Action Bars module, and fades the minimap for the Minimap module: each only touches its own
function Visibility:ShouldLoad()
    return ActionBarsOn() or MinimapOn()
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
    -- runs again when the fight ends (OnVisibilityStateChange)
    if InCombatLockdown() then
        self.refreshPending = true
        return
    end
    self.refreshPending = nil
    local db = GetDb()
    if not db then return end
    -- the minimap fades on its own, right out (SetMinimapDrawn), whatever an earlier setup stored
    local minimapCfg = db.elements and db.elements.minimap
    if minimapCfg then minimapCfg.group, minimapCfg.minAlpha = 0, nil end
    if not self:ShouldLoad() then
        Fader:SetScript("OnUpdate", nil)
        Fader.updateEnabled = false
        return
    end

    -- A frame hidden for good stays hidden in Edit Mode, its selection made invisible; lifting the hide
    -- would lose whether the frame comes back when the option goes off
    local inEditMode = _G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown()
    local barsOn = ActionBarsOn()
    for _, pair in ipairs(barsOn and HIDE_KEYS or {}) do
        local key, settingKey = pair[1], pair[2]
        local hidden = db[settingKey]
        if inEditMode then
            if hidden then
                ApplySecureHide(key, true)
                ForEachFrameOfKey(key, KeepHiddenInEditMode, settingKey)
                ForEachFrameOfKey(key, HideFrame)
                HideEditModeMover(key)
            else
                ApplySecureHide(key, false)
                RestoreEditModeMover(key)
            end
        else
            ApplySecureHide(key, hidden)
        end
    end
    if barsOn then
        SetMicroFlashesBlank(db.hideMicroMenu)
        UpdateMicroTips()
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
        local moduleOn = e.needsMinimap and MinimapOn() or (not e.needsMinimap and barsOn)
        if moduleOn and frame and frame.GetAlpha then
            local isBar = key:match("^bar[1-8]$") ~= nil
            local fcmBar = isBar and fcm and fcm.bars and fcm.bars[key]
            if fcmBar and fcmBar.enabled then
                -- Fake CM bars: their own rule, one group, no mouse
                AddMember("fcm", { key = key, frame = frame, isBar = true, fcm = true, show = fcm.show or "combat",
                                   fadeTime = ns.FadeTime(self:GetFadeSpeed(key)), minAlpha = 0 })
            else
                local show = self:GetShow(key)
                if show == "always" then
                    ApplyElementAlpha(frame, key, 1)
                else
                    local group = self:GetGroup(key)
                    AddMember(group > 0 and ("group" .. group) or key, { key = key, frame = frame, isBar = isBar, show = show,
                                                                         fadeTime = ns.FadeTime(self:GetFadeSpeed(key)),
                                                                         minAlpha = self:GetMinAlpha(key) / 100 })
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
    hooksecurefunc(_G.HelpTip, "Show", UpdateMicroTips)

    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnVisibilityStateChange")
    self:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED", "OnVisibilityStateChange")
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnVisibilityStateChange")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnVisibilityStateChange")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnVisibilityStateChange")

    if _G.EditModeManagerFrame then
        _G.EditModeManagerFrame:HookScript("OnShow", function() Visibility:Refresh() end)
        _G.EditModeManagerFrame:HookScript("OnHide", function() Visibility:Refresh() end)
    end
    -- Blizzard's dialogs now, the XP bar's once it exists
    AddEditModeSettings()
    LEM:RegisterCallback("enter", AddEditModeSettings)
    -- in Edit Mode, toggling Raid / Party Frames makes Blizzard show the raid manager again
    hooksecurefunc("CompactRaidFrameManager_UpdateShown", function()
        local db = GetDb()
        if db and db.hideRaidManager and ActionBarsOn() and _G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown() then
            local manager = _G.CompactRaidFrameManager
            if manager and manager:IsShown() and not InCombatLockdown() then ns.RawHide(manager) end
        end
    end)
end

--------------------------------------------------
-- 9. EVENT HANDLERS
--------------------------------------------------
function Visibility:OnVisibilityStateChange(event)
    if event == "PLAYER_REGEN_ENABLED" and self.refreshPending then
        self:Refresh()
    else
        MarkAllDirty()
    end
end
