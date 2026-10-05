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
local pairs, ipairs = pairs, ipairs
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

-- The main bar's end caps (gryphons/wyverns). On Forever each cap is its own Edit Mode system
-- (MainActionBar.EndCaps.LeftEndCap / RightEndCap, from Blizzard_ActionBar/Camelot/MainMenuBarEndCaps.xml)
-- and ignores its parent's alpha, so bar 1's fade has to be applied to them explicitly.
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

-- Runs func on every frame behind a hide/fade key. Most keys map to one frame; "endcaps" is the
-- two gryphon frames (Forever's Edit Mode hide setting for them does nothing, so we offer our own).
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
-- 4. SECURE HIDING (STATE DRIVER)
--------------------------------------------------
local HideFrameSecurely = ns.HideFrameSecurely

local function ApplySecureHide(key, shouldHide)
    ForEachFrameOfKey(key, HideFrameSecurely, shouldHide)
end

--------------------------------------------------
-- 5. EDIT MODE MOVER HIDER
--------------------------------------------------
-- Makes the blue "Mover" box invisible and unclickable without deleting the frame (preventing crashes)
local function HideMoverOfFrame(frame)
    if frame and frame.Selection then
        -- Tag the selection so other code can tell it was hidden by us
        frame.Selection.FlareUI_HiddenMover = true

        frame.Selection:SetAlpha(0)
        if frame.Selection.Label then frame.Selection.Label:SetAlpha(0) end

        -- Disable mouse to prevent blocking
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
-- the C hide: Edit Mode's HideOverride breaks the frame's snaps from our tainted call, re-anchoring
-- whatever was snapped to it (the party frames then fail on secret health colours)
local function HideFrame(frame) ns.RawHide(frame) end

-- In Edit Mode a hidden bar must stay hidden, but Blizzard shows some of them again on its own (the
-- stance bar's Update runs SetShown as Edit Mode opens): each such show is undone, with the C hide.
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
-- One OnUpdate for every faded element. It only runs while something is mid-fade, a group has been
-- marked dirty by an event, or some group fades on mouseover (the one condition no event reports).
--------------------------------------------------
local Fader = CreateFrame("Frame")
Fader.groups = {}
Fader.delays = {}
Fader.updateTimer = 0
Fader.dirty = {}
Fader.updateEnabled = false
Fader.watchesMouseover = false   -- recomputed by Refresh(), not per tick

local function CheckCondition(cfg, frame, key)
    -- Fake CM override wins over everything else
    if ns.ActionBars and ns.ActionBars.fcm then
        local fcm = ns.db.profile.fcm
        if fcm and fcm.bars[key] and fcm.bars[key].enabled then
            local barCfg = fcm.bars[key]

            -- Edit Mode always shows
            if _G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown() then return true end

            -- Setup Mode always shows (for positioning and spell placement)
            if ns.ActionBars.fcm.unlockMode then return true end

            -- Show when dragging (for spell placement) - works even when Setup Mode is off
            if ns.ActionBars.fcm.wasDragging then return true end

            -- Always show overrides all other conditions
            if barCfg.condAlways then return true end

            -- Check FCM-specific conditions
            if barCfg.condCombat and InCombatLockdown() then return true end
            if barCfg.condTarget and UnitExists("target") then return true end
            if barCfg.condHarm and UnitExists("target") and UnitCanAttack("player", "target") then return true end

            return false -- FCM bar hidden (no conditions met)
        end
    end

    -- Normal visibility logic
    if _G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown() then return true end

    -- Show all action bars when dragging (for easy spell/item organization)
    if ns.ActionBars and ns.ActionBars.fcm and ns.ActionBars.fcm.wasDragging then
        if key and key:match("^bar[1-8]$") then
            return true
        end
    end

    if cfg.condCombat and InCombatLockdown() then return true end
    if cfg.condTarget and UnitExists("target") then return true end
    if cfg.condHarm and UnitExists("target") then
        -- UnitCanAttack can return a secret value under addon restrictions; a bare truth test would throw
        local canAttack = UnitCanAttack("player", "target")
        if canaccessvalue(canAttack) and canAttack then return true end
    end
    -- "Mounted / Vehicle" option
    if cfg.condVehicle and (UnitInVehicle("player") or UnitOnTaxi("player") or IsMounted()) then
        return true
    end

    if cfg.condMouseover then
        if frame:IsMouseOver() then return true end
        if frame == _G.MinimapCluster and _G.Minimap and _G.Minimap:IsMouseOver() then return true end
    end

    return false
end

-- Mark groups dirty when conditions might have changed
local function MarkAllDirty()
    for groupName in pairs(Fader.groups) do
        Fader.dirty[groupName] = true
    end
    if next(Fader.dirty) then
        -- Run one tick immediately so fades react in same frame as the triggering event
        Fader.UpdateScript(Fader, 0)
        if not Fader.updateEnabled then
            Fader:SetScript("OnUpdate", Fader.UpdateScript)
            Fader.updateEnabled = true
            Fader.updateTimer = 0
        end
    end
end

Fader.updateInterval = 0.1  -- condition checks; 0.2 when only mouseover (throttled)
Fader.shows = {}            -- group -> whether it is fading in (from the last condition check)
Fader.counting = {}         -- group -> its fade-out delay is running down
-- Conditions (mouseover, combat, target...) are checked on the throttled tick or when an event marks a
-- group dirty; the alpha itself steps every frame while anything is mid-fade, so fades run smoothly.
Fader.UpdateScript = function(self, elapsed)
    self.updateTimer = self.updateTimer + elapsed
    local check = self.updateTimer >= self.updateInterval or next(self.dirty) ~= nil
    local tick = self.updateTimer
    if check then self.updateTimer = 0 end

    local hasActiveFades = false

    for groupName, members in pairs(self.groups) do
        if check or self.shows[groupName] == nil then
            local groupShouldShow = false
            local delaySetting = 0

            for _, data in ipairs(members) do
                local cfg = GetVisConfig(data.key)
                if cfg then
                    if CheckCondition(cfg, data.frame, data.key) then groupShouldShow = true end
                    if cfg.fadeOutDelay and cfg.fadeOutDelay > delaySetting then delaySetting = cfg.fadeOutDelay end
                end
            end

            if not self.delays[groupName] then self.delays[groupName] = 0 end
            if groupShouldShow then self.delays[groupName] = delaySetting
            else if self.delays[groupName] > 0 then self.delays[groupName] = self.delays[groupName] - tick end end

            self.shows[groupName] = groupShouldShow or (self.delays[groupName] > 0)
            self.counting[groupName] = (not groupShouldShow) and self.delays[groupName] > 0
        end
        local effectiveShow = self.shows[groupName]

        for _, data in ipairs(members) do
            local cfg = GetVisConfig(data.key)
            local frame = data.frame
            if cfg and frame then
                local targetAlpha = effectiveShow and cfg.alphaMax or cfg.alphaMin
                local currentAlpha = frame:GetAlpha()

                if math_abs(currentAlpha - targetAlpha) > 0.005 then
                    hasActiveFades = true
                    local speed = effectiveShow and cfg.fadeInSpeed or cfg.fadeOutSpeed
                    if speed <= 0 then
                        frame.flareDesiredAlpha = targetAlpha; ApplyElementAlpha(frame, data.key, targetAlpha)
                    else
                        local change = (1 / speed) * elapsed
                        local newAlpha = (currentAlpha < targetAlpha) and math_min(targetAlpha, currentAlpha + change) or math_max(targetAlpha, currentAlpha - change)
                        frame.flareDesiredAlpha = newAlpha; ApplyElementAlpha(frame, data.key, newAlpha)
                    end
                else
                    frame.flareDesiredAlpha = targetAlpha
                end
            end
        end

        self.dirty[groupName] = nil
    end

    -- a fade still running, or a delay still counting down, keeps the frame-rate loop going
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
        -- half rate when only mouseover keeps us running
        self.updateInterval = idle and 0.2 or 0.1
    end
end

--------------------------------------------------
-- 7. PUBLIC API
--------------------------------------------------
-- Part of the Action Bars module: loads with it, no toggle of its own (settings stay in
-- profile.visibility so nothing moves).
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

    --------------------------------------------------
    -- EDIT MODE SAFETY CHECK
    --------------------------------------------------
    local inEditMode = _G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown()

    local function UpdateHide(key, settingKey)
        local userSetting = db[settingKey]
        if inEditMode then
            -- 1. Unregister Secure Hide (Prevents Crash)
            ApplySecureHide(key, false)

            -- 2. Handle Visuals in Edit Mode
            if userSetting then
                -- User wants it HIDDEN -> Force Hide frame + Hide Mover Overlay
                ForEachFrameOfKey(key, KeepHiddenInEditMode, settingKey)
                ForEachFrameOfKey(key, HideFrame)
                HideEditModeMover(key)
            else
                -- User wants it SHOWN -> ApplySecureHide above already restored it if we had hidden it;
                -- never force-show frames Blizzard keeps hidden (rep bar, raid manager, possess bar...)
                RestoreEditModeMover(key)
            end
        else
            -- Normal Mode: Apply Secure Hiding via State Driver
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

    for key, frameName in pairs(BAR_FRAMES) do
        local cfg = GetVisConfig(key)

        -- Check if this is an FCM-enabled bar
        local isFCMBar = false
        if key:match("^bar[1-8]$") and ns.db.profile.fcm and ns.db.profile.fcm.bars[key] then
            isFCMBar = ns.db.profile.fcm.bars[key].enabled
        end

        -- Enable fading if either cfg.enableFade is true OR it's an FCM-enabled bar
        if cfg and (cfg.enableFade or isFCMBar) then
            local groupName = cfg.faderGroup
            if not groupName or groupName == "" then groupName = key end
            if not Fader.groups[groupName] then Fader.groups[groupName] = {} end

            local frame = GetFrame(key)
            if frame and frame.GetAlpha then
                table_insert(Fader.groups[groupName], { key = key, frame = frame })
                if cfg.condMouseover then Fader.watchesMouseover = true end
            end
        elseif cfg and not cfg.enableFade and not isFCMBar then
            local frame = GetFrame(key)
            if frame and frame.SetAlpha then ApplyElementAlpha(frame, key, 1); frame.flareDesiredAlpha = nil end
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
    -- In Edit Mode the state driver is off and the raid manager is hidden with a plain Hide();
    -- toggling "Raid Frames" / "Party Frames" in the Edit Mode panel makes Blizzard SetShown() it
    -- again, so re-apply our hide after its shown-state update.
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

-- Event: Visibility state change (combat, target, vehicle, mount, etc.)
function Visibility:OnVisibilityStateChange()
    MarkAllDirty()
end
