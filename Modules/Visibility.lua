local _, ns = ...

--------------------------------------------------
-- 1. MODULE REGISTRATION
--------------------------------------------------
ns.Visibility = ns.Visibility or {}
local Visibility = ns.Visibility
ns.modules["Visibility"] = Visibility

LibStub("AceEvent-3.0"):Embed(Visibility)
LibStub("AceHook-3.0"):Embed(Visibility)

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
local UnitInVehicle = UnitInVehicle
local UnitOnTaxi = UnitOnTaxi
local IsMounted = IsMounted
local canaccessvalue = canaccessvalue

--------------------------------------------------
-- 3. FRAME MAPPING
--------------------------------------------------
local BAR_FRAMES = {
    -- Action Bars
    bar1 = "MainActionBar", bar2 = "MultiBarBottomLeft", bar3 = "MultiBarBottomRight",
    bar4 = "MultiBarRight", bar5 = "MultiBarLeft", bar6 = "MultiBar5",
    bar7 = "MultiBar6", bar8 = "MultiBar7",

    -- Command Bars
    pet = "PetActionBar", stance = "StanceBar", possess = "PossessActionBar",
    totem = "MultiCastActionBarFrame",   -- the shaman totem bar: hide only, no fading

    -- Utility
    bags = "BagsBar", menu = "MicroMenuContainer",

    -- Units & UI
    player = "PlayerFrame", petFrame = "PetFrame",
    raid = "CompactRaidFrameManager",
    minimap = "MinimapCluster", tracker = "ObjectiveTrackerFrame",
    xp = "MainStatusTrackingBarContainer", rep = "SecondaryStatusTrackingBarContainer",
}

local function GetFrame(key)
    -- the FlareUI XP bar replaces Blizzard's tracking bar when it is on
    if key == "xp" and ns.XPBar and ns.XPBar.GetFrame and ns.XPBar:GetFrame() then
        return ns.XPBar:GetFrame()
    end
    local name = BAR_FRAMES[key]
    local f = _G[name]

    if key == "menu" and not f then f = _G.MicroButtonAndBagsBar end
    if key == "minimap" and not f then f = _G.Minimap end

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

-- Runs func on every frame behind a hide / fade key ("endcaps" is the two gryphon frames)
local function ForEachFrameOfKey(key, func, ...)
    if key == "endcaps" then
        ForEachEndCap(func, ...)
    else
        local frame = GetFrame(key)
        if frame then func(frame, ...) end
    end
end

local function GetVisConfig(key)
    if not ns.db or not ns.db.profile or not ns.db.profile.visibility then
        return nil
    end
    return ns.db.profile.visibility[key]
end

--------------------------------------------------
-- 4. SECURE HIDING
--------------------------------------------------
local function ApplySecureHide(key, shouldHide)
    ForEachFrameOfKey(key, ns.HideFrameSecurely, shouldHide)
end

--------------------------------------------------
-- 5. EDIT MODE SELECTIONS OF HIDDEN FRAMES (invisible and unclickable)
--------------------------------------------------
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
        local db = ns.db and ns.db.profile and ns.db.profile.visibility
        local editing = _G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown()
        if db and db[editHideHooked[f]] and editing and not InCombatLockdown() then ns.RawHide(f) end
    end)
end

--------------------------------------------------
-- 6. FADER ENGINE
-- One OnUpdate for every faded element. It runs while something is mid-fade, a group is dirty, or a
-- group fades on mouseover (the one condition no event reports). Conditions are checked on a
-- throttled tick or when an event marks a group dirty; alpha steps every frame only mid-fade.
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

local function CheckCondition(cfg, frame, key, isBar)
    local editMode = _G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown()
    local fcmState = ns.ActionBars and ns.ActionBars.fcm

    -- an FCM bar follows its own conditions
    local fcm = fcmState and isBar and ns.db.profile.fcm
    local barCfg = fcm and fcm.bars[key]
    if barCfg and barCfg.enabled then
        if editMode or fcmState.unlockMode or fcmState.wasDragging or barCfg.condAlways then return true end
        if barCfg.condCombat and InCombatLockdown() then return true end
        if barCfg.condTarget and UnitExists("target") then return true end
        if barCfg.condHarm and TargetIsHostile() then return true end
        return false
    end

    if editMode then return true end
    -- every action bar shows while something is dragged onto them
    if isBar and fcmState and fcmState.wasDragging then return true end
    if cfg.condCombat and InCombatLockdown() then return true end
    if cfg.condTarget and UnitExists("target") then return true end
    if cfg.condHarm and TargetIsHostile() then return true end
    if cfg.condVehicle and (UnitInVehicle("player") or UnitOnTaxi("player") or IsMounted()) then
        return true
    end

    if cfg.condMouseover then
        if frame:IsMouseOver() then return true end
        if frame == _G.MinimapCluster and _G.Minimap and _G.Minimap:IsMouseOver() then return true end
    end

    return false
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

Fader.updateInterval = 0.1  -- condition checks; 0.2 when only mouseover keeps the loop running
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
            local delaySetting = 0

            for _, data in ipairs(members) do
                local cfg = data.cfg
                if CheckCondition(cfg, data.frame, data.key, data.isBar) then groupShouldShow = true end
                if cfg.fadeOutDelay and cfg.fadeOutDelay > delaySetting then delaySetting = cfg.fadeOutDelay end
            end

            if not self.delays[groupName] then self.delays[groupName] = 0 end
            if groupShouldShow then self.delays[groupName] = delaySetting
            else if self.delays[groupName] > 0 then self.delays[groupName] = self.delays[groupName] - tick end end

            self.shows[groupName] = groupShouldShow or (self.delays[groupName] > 0)
            self.counting[groupName] = (not groupShouldShow) and self.delays[groupName] > 0
        end
        local effectiveShow = self.shows[groupName]

        for _, data in ipairs(members) do
            local cfg, frame = data.cfg, data.frame
            local targetAlpha = effectiveShow and cfg.alphaMax or cfg.alphaMin
            local currentAlpha = frame:GetAlpha()
            if math_abs(currentAlpha - targetAlpha) > 0.005 then
                hasActiveFades = true
                local speed = effectiveShow and cfg.fadeInSpeed or cfg.fadeOutSpeed
                if speed <= 0 then
                    ApplyElementAlpha(frame, data.key, targetAlpha)
                else
                    local change = (1 / speed) * elapsed
                    local newAlpha = (currentAlpha < targetAlpha) and math_min(targetAlpha, currentAlpha + change) or math_max(targetAlpha, currentAlpha - change)
                    ApplyElementAlpha(frame, data.key, newAlpha)
                end
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
        self.updateInterval = idle and 0.2 or 0.1
    end
end

--------------------------------------------------
-- 7. PUBLIC API
--------------------------------------------------
-- Part of the Action Bars module: loads with it (settings in profile.visibility)
function Visibility:ShouldLoad()
    local ab = ns.db and ns.db.profile and ns.db.profile.actionbars
    return ab and ab.enabled or false
end

function Visibility:Refresh()
    if InCombatLockdown() then return end
    if not ns.db or not ns.db.profile or not ns.db.profile.visibility then return end

    local db = ns.db.profile.visibility
    if not self:ShouldLoad() then
        Fader:SetScript("OnUpdate", nil)
        Fader.updateEnabled = false
        return
    end

    -- In Edit Mode the secure hide is lifted (Edit Mode needs the frames); a frame set to hidden is
    -- hidden plainly instead, its selection made invisible.
    local inEditMode = _G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown()

    local function UpdateHide(key, settingKey)
        local userSetting = db[settingKey]
        if inEditMode then
            ApplySecureHide(key, false)
            if userSetting then
                ForEachFrameOfKey(key, KeepHiddenInEditMode, settingKey)
                ForEachFrameOfKey(key, HideFrame)
                HideEditModeMover(key)
            else
                RestoreEditModeMover(key)
            end
        else
            ApplySecureHide(key, userSetting)
        end
    end

    UpdateHide("menu", "hideMicroMenu")
    UpdateHide("bags", "hideBagBar")
    UpdateHide("pet", "hidePetBar")
    UpdateHide("stance", "hideStanceBar")
    UpdateHide("possess", "hidePossessBar")
    UpdateHide("totem", "hideTotemBar")
    UpdateHide("raid", "hideRaidManager")
    UpdateHide("endcaps", "hideEndCaps")

    Fader.groups = {}
    Fader.delays = {}
    Fader.dirty = {}
    Fader.shows = {}
    Fader.counting = {}
    Fader.watchesMouseover = false
    Fader.fading = false

    for key in pairs(BAR_FRAMES) do
        local cfg = GetVisConfig(key)
        local isBar = key:match("^bar[1-8]$") ~= nil
        local fcmBar = isBar and ns.db.profile.fcm and ns.db.profile.fcm.bars[key]
        local isFCMBar = fcmBar and fcmBar.enabled or false

        -- an FCM bar always fades
        if cfg and (cfg.enableFade or isFCMBar) then
            local groupName = cfg.faderGroup
            if not groupName or groupName == "" then groupName = key end
            if not Fader.groups[groupName] then Fader.groups[groupName] = {} end

            local frame = GetFrame(key)
            if frame and frame.GetAlpha then
                table_insert(Fader.groups[groupName], { key = key, frame = frame, cfg = cfg, isBar = isBar })
                if cfg.condMouseover then Fader.watchesMouseover = true end
            end
        elseif cfg then
            local frame = GetFrame(key)
            if frame and frame.SetAlpha then ApplyElementAlpha(frame, key, 1) end
        end
    end

    MarkAllDirty()
end

function Visibility:Init()
    if not ns.db or not ns.db.profile or not ns.db.profile.visibility then return end

    if not self:ShouldLoad() then return end
    self:Refresh()

    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnVisibilityStateChange")
    self:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED", "OnVisibilityStateChange")
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnVisibilityStateChange")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnVisibilityStateChange")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnVisibilityStateChange")
    self:RegisterEvent("UNIT_ENTERED_VEHICLE", "OnVisibilityStateChange")
    self:RegisterEvent("UNIT_EXITED_VEHICLE", "OnVisibilityStateChange")
    self:RegisterEvent("PLAYER_CONTROL_LOST", "OnVisibilityStateChange")
    self:RegisterEvent("PLAYER_CONTROL_GAINED", "OnVisibilityStateChange")
    self:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED", "OnVisibilityStateChange")

    if _G.EditModeManagerFrame then
        _G.EditModeManagerFrame:HookScript("OnShow", function() Visibility:Refresh() end)
        _G.EditModeManagerFrame:HookScript("OnHide", function() Visibility:Refresh() end)
    end
    -- In Edit Mode, toggling Raid / Party Frames makes Blizzard show the raid manager again
    hooksecurefunc("CompactRaidFrameManager_UpdateShown", function()
        local db = ns.db and ns.db.profile and ns.db.profile.visibility
        if db and db.hideRaidManager and _G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown() then
            local manager = _G.CompactRaidFrameManager
            if manager and manager:IsShown() and not InCombatLockdown() then ns.RawHide(manager) end
        end
    end)
end

--------------------------------------------------
-- 8. EVENT HANDLERS
--------------------------------------------------
-- combat, target, vehicle, mount...
function Visibility:OnVisibilityStateChange()
    MarkAllDirty()
end
