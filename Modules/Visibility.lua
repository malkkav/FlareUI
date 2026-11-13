local _, ns = ...
local L = ns.L

--------------------------------------------------
-- VISIBILITY
-- Show conditions (always | mouseover | any of combat, hastarget, attackable, ingroup, unmounted), fade groups 1-5,
-- Fade Speed and Faded Opacity for the action bars, bag bar, micro menu, XP bar, minimap, buffs, debuffs,
-- quest tracker and the player, pet, target, focus and target-of unit frames (no fade groups), set in each element's Edit Mode dialog, plus the Blizzard pieces hidden for good. Fake CM bars follow profile.fcm.show and never the mouse.
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
local UnitIsDead = UnitIsDead
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
    -- Blizzard's shaman Totem Bar (11-11, a shaman asked): fade groups, and a Size row (ActionBars.lua)
    { key = "totem", frame = "MultiCastActionBarFrame", system = "TotemActionBar" },
    -- The gryphons: on Forever each is its own Edit Mode system and ignores bar 1's alpha. By default
    -- each follows bar 1 (Same as Action Bar 1, "bar1"); any other choice, or a fade group, detaches it.
    { key = "capLeft", cap = "LeftEndCap", system = "MainActionBarEndCap", index = "EndCapLeft",
      indices = "EditModeMainActionBarEndCapSystemIndices", defaultShow = "bar1" },
    { key = "capRight", cap = "RightEndCap", system = "MainActionBarEndCap", index = "EndCapRight",
      indices = "EditModeMainActionBarEndCapSystemIndices", defaultShow = "bar1" },
    { key = "bags", frame = "BagsBar", system = "Bags" },
    { key = "menu", frame = "MicroMenuContainer", system = "MicroMenu" },
    { key = "xp" },   -- FlareUI's XP bar, its own Edit Mode frame
    { key = "minimap", frame = "MinimapCluster", needsMinimap = true },   -- with the Minimap module
    -- FlareUI's own Edit Mode frames, each with its module
    { key = "buffs", module = "auras" },
    { key = "debuffs", module = "auras" },
    { key = "quest", module = "objectivetracker" },
    -- The unit frames: each on its own, never in a fade group (UnitFrames.lua section 14). own: the fader
    -- keeps the value and sets it through apply (an alpha left by the health curve can't be read back);
    -- health: Missing Health, from that unit
    -- instant: no Fade Speed (always instant); noOpacity: no Faded Opacity (faded right out)
    -- mana: Missing Mana too (the player frame only, 11-11)
    { key = "uf_player", unit = "player", module = "unitframes", own = true, noGroup = true, instant = true, health = "player", mana = true },
    { key = "uf_pet", unit = "pet", module = "unitframes", own = true, noGroup = true, instant = true, health = "pet" },
    { key = "uf_target", unit = "target", module = "unitframes", own = true, noGroup = true, instant = true, noOpacity = true },
    { key = "uf_targettarget", unit = "targettarget", module = "unitframes", own = true, noGroup = true, instant = true, noOpacity = true },
    { key = "uf_focus", unit = "focus", module = "unitframes", own = true, noGroup = true, instant = true, noOpacity = true },
    { key = "uf_focustarget", unit = "focustarget", module = "unitframes", own = true, noGroup = true, instant = true, noOpacity = true },
    -- the FlareUI Player Cast Bar: Visibility and Faded Opacity only. Not with Cinematic, which fades it
    -- between fights itself (its bar then ignores the holder's alpha)
    { key = "uf_playercastbar", castbar = true, module = "unitframes", own = true, noGroup = true, instant = true },
    -- The resource bars (ResourceBars.lua), fade groups allowed. They still hide on their own where they
    -- don't apply (druid mana, combo points, a swing bar with no weapon); inuse: a swing bar's Only When In
    -- Use, which the bar shows and hides itself
    { key = "rb_health", bar = "health", own = true, health = "player" },
    { key = "rb_power", bar = "power", own = true },
    { key = "rb_mana", bar = "mana", own = true },
    { key = "rb_combo", bar = "combo", own = true },
    { key = "rb_swingMain", bar = "swingMain", own = true, inuse = true },
    { key = "rb_swingOff", bar = "swingOff", own = true, inuse = true },
    { key = "rb_swingRanged", bar = "swingRanged", own = true, inuse = true },
    { key = "rb_flight", bar = "flight", own = true },   -- the Flight Timer: it shows only in flight itself
    { key = "rb_seal", bar = "seal", own = true },       -- Seals: a seal's bar shows only while that seal is up
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
    elseif key == "buffs" or key == "debuffs" then
        return ns.Auras and ns.Auras.GetFrame and ns.Auras:GetFrame(key) or nil
    elseif key == "quest" then
        return ns.ObjectiveTracker and ns.ObjectiveTracker.GetFrame and ns.ObjectiveTracker:GetFrame() or nil
    elseif ELEMENT_BY_KEY[key] and ELEMENT_BY_KEY[key].unit then
        local UF = ns.UnitFrames
        return UF and UF.initialized and UF.GetFadeFrame and UF:GetFadeFrame(ELEMENT_BY_KEY[key].unit) or nil
    elseif ELEMENT_BY_KEY[key] and ELEMENT_BY_KEY[key].cap then
        local caps = _G.MainActionBar and _G.MainActionBar.EndCaps
        return caps and caps[ELEMENT_BY_KEY[key].cap] or nil
    elseif key == "uf_playercastbar" then
        local UF = ns.UnitFrames
        return UF and UF.initialized and UF.GetPlayerCastHolder and UF.GetPlayerCastHolder() or nil
    elseif ELEMENT_BY_KEY[key] and ELEMENT_BY_KEY[key].bar then
        local RB = ns.ResourceBars
        return RB and RB.initialized and RB.GetHolder and RB:GetHolder(ELEMENT_BY_KEY[key].bar) or nil
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
-- the gryphons on Same as Action Bar 1, rebuilt by Refresh: cap frame -> true
local capsFollowBar1 = {}
local function SetFollowingCapAlpha(cap, alpha) if capsFollowBar1[cap] then cap:SetAlpha(alpha) end end

-- The game draws the minimap's player arrow, quest marks and other blips itself, at full strength
-- whatever the alpha, and has no API for them: only an empty mask or hiding removes them. So the map goes once
-- it has faded right out (the cluster stays, so pointing at it still brings it back), which is why it
-- has no Faded Opacity, and no fade group that could give it one.
-- With the Minimap module running, the map is masked empty instead (Minimap.lua MM:SetMapFaded):
-- gathering addons stop scanning a hidden map. Hiding stays the fallback.
local minimapFadedOut = false
local function SetMinimapDrawn(alpha)
    local map = _G.Minimap
    if not minimapFadedOut and ns.Minimap and ns.Minimap.SetMapFaded and ns.Minimap:SetMapFaded(alpha <= 0.01) then return end
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
        -- the Toggle Minimap key pressed while it was faded out: it stays hidden
        if not ns.minimapKeyHidden then map:Show() end
    end
end

-- The Toggle Minimap key: a press while the map is faded out (its show is undone at once) flips
-- what the fade's return does; otherwise the key's own result is noted
if ToggleMinimap then
    hooksecurefunc("ToggleMinimap", function()
        if C_GameRules and C_GameRules.IsGameRuleActive and Enum.GameRule and Enum.GameRule.MinimapDisabled
                and C_GameRules.IsGameRuleActive(Enum.GameRule.MinimapDisabled) then return end
        local map = _G.Minimap
        if minimapFadedOut then
            ns.minimapKeyHidden = not ns.minimapKeyHidden
        elseif map then
            ns.minimapKeyHidden = not map:IsShown()
        end
    end)
end

-- The cooldown-finished flash draws at full strength whatever the bar's alpha: a bar faded below
-- half has it off on its buttons, set again only when the alpha crosses half. Back up, a button gets
-- its own setting back, never the flash forced on (6.4.1, a player: every button flashed as the
-- global cooldown ended; Blizzard's action buttons have it off)
local blingOn = setmetatable({}, { __mode = "k" })
local ownBling = setmetatable({}, { __mode = "k" })   -- cooldown -> its setting before FlareUI's first change
local function SetBarBling(frame, alpha)
    local on = alpha > 0.5
    if blingOn[frame] == on then return end
    blingOn[frame] = on
    for _, button in ipairs(frame.actionButtons or {}) do
        local cd = button.cooldown
        if cd and cd.SetDrawBling then
            if ownBling[cd] == nil then
                local own = cd.GetDrawBling and cd:GetDrawBling()
                ownBling[cd] = own and true or false
            end
            cd:SetDrawBling(on and ownBling[cd])
        end
    end
end

local function ApplyElementAlpha(frame, key, alpha)
    frame:SetAlpha(alpha)
    if frame.actionButtons then SetBarBling(frame, alpha) end
    if key == "bar1" then ForEachEndCap(SetFollowingCapAlpha, alpha) end
    if key == "minimap" then SetMinimapDrawn(alpha) end
    -- the tracker's lone "+" and its quest item buttons sit on UIParent, outside its frame
    if key == "quest" and ns.ObjectiveTracker.SetFadeAlpha then ns.ObjectiveTracker:SetFadeAlpha(alpha) end
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

-- 11-12: Mouseover became a condition ticked with the others. Before, any condition also showed the
-- element under the pointer: once per profile, every condition choice gets Mouseover ticked, so
-- nothing changes until the player unticks it (Fake CM never followed the pointer: left alone)
local function MigrateMouseToken(db)
    db.mouseToken = true
    local C = ns.Conditions
    local function Add(show)
        show = type(show) == "string" and (C.BAR_LEGACY[show] or show) or show
        if type(show) ~= "string" or show == "always" or show == "inuse" or show == "bar1" or show == "" then return nil end
        local set = C.Set(show)
        if set.mouseover then return nil end
        local list = { "mouseover" }
        for token in show:gmatch("[^,]+") do list[#list + 1] = token end
        return table.concat(list, ",")
    end
    for _, cfg in pairs(db.elements or {}) do
        if type(cfg) == "table" then cfg.show = Add(cfg.show) or cfg.show end
    end
    for i = 1, 5 do
        local group = db.groups and db.groups[i]
        if type(group) == "table" then group.show = Add(group.show) or group.show end
    end
end

local function GetDb()
    local db = ns.db and ns.db.profile and ns.db.profile.visibility
    if db and not db.mouseToken then MigrateMouseToken(db) end
    return db
end

local function ActionBarsOn()
    local ab = ns.db and ns.db.profile and ns.db.profile.actionbars
    return ab and ab.enabled or false
end

local function MinimapOn()
    local mm = ns.db and ns.db.profile and ns.db.profile.minimap
    return mm and mm.enabled or false
end

-- an element's module is on: the bars' with Action Bars, the minimap with Minimap, the others with theirs
local function ElementOn(e)
    if e.needsMinimap then return MinimapOn() end
    if e.bar then
        local uf = ns.db and ns.db.profile and ns.db.profile.unitframes
        return uf and uf.resource and uf.resource.enabled or false
    end
    if e.castbar then
        if C_AddOns.IsAddOnLoaded("Cinematic") then return false end
        local uf = ns.db and ns.db.profile and ns.db.profile.unitframes
        return uf and uf.enabled and uf.playerCastbar and uf.playerCastbar.enabled or false
    end
    if e.module then
        local db = ns.db and ns.db.profile and ns.db.profile[e.module]
        return db and db.enabled or false
    end
    return ActionBarsOn()
end

--------------------------------------------------
-- 4. SHOW CHOICES AND FADE GROUPS
--------------------------------------------------
-- Reading never writes: an element nobody set reads the defaults, and gets its own entry in the
-- profile only when something is set (create)
local UNSET = setmetatable({}, { __index = { show = "always", group = 0 }, __newindex = function() end })
local function ElementConfig(key, create)
    local db = GetDb()
    local elements = db and db.elements
    if not elements then return nil end
    if create then
        local e = ELEMENT_BY_KEY[key]
        elements[key] = elements[key] or { show = e and e.defaultShow or "always", group = 0 }
    end
    return elements[key] or UNSET
end

function Visibility:GetGroup(key)
    local cfg = ElementConfig(key)
    return cfg and cfg.group or 0
end

-- an element in a group takes the group's Show choice
function Visibility:GetShow(key)
    local db, cfg = GetDb(), ElementConfig(key)
    local e = ELEMENT_BY_KEY[key]
    local fallback = e and e.defaultShow or "always"
    if not (db and cfg) or cfg == UNSET then return fallback end
    local group = cfg.group and cfg.group > 0 and db.groups and db.groups[cfg.group]
    return (group and group.show) or cfg.show or fallback
end

function Visibility:SetShow(key, show)
    local db, cfg = GetDb(), ElementConfig(key, true)
    if not (db and cfg) then return end
    local group = cfg.group and cfg.group > 0 and db.groups and db.groups[cfg.group]
    if group then group.show = show else cfg.show = show end
    self:Refresh()
end

-- The group an element is in, or nil. A group owns its members' Show, Fade Speed and Faded Opacity.
local function ElementGroup(key)
    local db, cfg = GetDb(), ElementConfig(key)
    return cfg and cfg.group and cfg.group > 0 and db.groups and db.groups[cfg.group] or nil
end

-- falls back to the profile-wide Fade Speed
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
    local owner = ElementGroup(key) or ElementConfig(key, true)
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
    local db, cfg = GetDb(), ElementConfig(key, true)
    if not (db and cfg) then return end
    group = group or 0
    if group == (cfg.group or 0) then return end
    local show, speed, minAlpha = self:GetShow(key), self:GetFadeSpeed(key), self:GetMinAlpha(key)
    -- a gryphon on Same as Action Bar 1 brings bar 1's own choice: a group can't follow bar 1
    if show == "bar1" then show = self:GetShow("bar1") end
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

-- UnitCanAttack can be secret. A corpse still counts as attackable, so it is left out: clicking it
-- to loot would bring the bars back
local function TargetIsHostile()
    if not UnitExists("target") then return false end
    local dead = UnitIsDead("target")
    if not (canaccessvalue(dead) and not dead) then return false end
    local canAttack = UnitCanAttack("player", "target")
    return canaccessvalue(canAttack) and canAttack or false
end

-- Not mounted: a druid's travel and aquatic forms and a flight path count as riding
local TRAVEL_FORMS = { [3] = true, [4] = true, [27] = true, [29] = true }
local function Riding()
    if IsMounted() or UnitOnTaxi("player") then return true end
    local form = GetShapeshiftFormID and GetShapeshiftFormID()
    return form ~= nil and TRAVEL_FORMS[form] == true
end

-- a spell flyout opened from one of this bar's buttons, with the mouse on it: Blizzard parents the
-- popup to the button, outside the bar's own rectangle
local function FlyoutOver(bar)
    local flyout = _G.SpellFlyout
    if not (flyout and flyout:IsShown() and flyout:IsMouseOver()) then return false end
    local parent = flyout:GetParent()
    while parent do
        if parent == bar then return true end
        parent = parent:GetParent()
    end
    return false
end

-- A Visibility is "always", or the conditions ticked in its dropdown joined by commas
-- ("mouseover,combat"): any one of them shows the element (ns.Conditions). Mouseover is one of those
-- conditions (11-12): nothing shows under the pointer unless it is ticked. Nothing ticked is Always.
local Conditions = ns.Conditions
local SHOW_SPEC = { exclusive = { "always" }, tokens = Conditions.MOUSE_TOKENS, legacy = Conditions.BAR_LEGACY, empty = "always" }
-- the player and pet frames also show while their unit is missing health (section 6b)
local HEALTH_TOKENS = { unpack(Conditions.MOUSE_TOKENS) }
HEALTH_TOKENS[#HEALTH_TOKENS + 1] = "health"
local HEALTH_SPEC = { exclusive = SHOW_SPEC.exclusive, tokens = HEALTH_TOKENS, legacy = SHOW_SPEC.legacy, empty = "always" }
-- and the player frame while you're missing mana (ticked with Missing Health: either bar under full)
local MANA_TOKENS = { unpack(HEALTH_TOKENS) }
MANA_TOKENS[#MANA_TOKENS + 1] = "mana"
-- (11-13) Missing Health and Missing Mana can't be ticked together: Forever hides both values from
-- addons, and two hidden values can't be combined into "either is missing" (/fui fadedebug showed both
-- hidden out of combat, so the frame stayed shown). Ticking one unticks the other.
local MANA_SPEC = { exclusive = SHOW_SPEC.exclusive, tokens = MANA_TOKENS, legacy = SHOW_SPEC.legacy, empty = "always",
                    rivals = { health = "mana", mana = "health" } }
-- a swing bar's Only When In Use clears the rest, as Always does
local INUSE_SPEC = { exclusive = { "always", "inuse" }, tokens = Conditions.MOUSE_TOKENS, legacy = SHOW_SPEC.legacy, empty = "always" }
-- a gryphon's Same as Action Bar 1 clears the rest too
local CAP_SPEC = { exclusive = { "bar1", "always" }, tokens = Conditions.MOUSE_TOKENS, legacy = SHOW_SPEC.legacy, empty = "always" }
local function SpecOf(key)
    local e = ELEMENT_BY_KEY[key]
    if e and e.cap then return CAP_SPEC end
    if e and e.mana then return MANA_SPEC end
    if e and e.health then return HEALTH_SPEC end
    if e and e.inuse then return INUSE_SPEC end
    return SHOW_SPEC
end

-- also the resource bars' and Fake CM's rule (ns.Visibility.ShowRule)
local function ShowRule(show)
    if show == "always" then return true end
    if show == "mouseover" or type(show) ~= "string" then return false end
    local set = Conditions.Set(show, SHOW_SPEC)
    -- InCombatLockdown is still false during PLAYER_REGEN_DISABLED: the event's own flag counts too
    -- (and UnitAffectingCombat, for the resource bars while this module isn't running)
    if set.combat and (InCombatLockdown() or Visibility.inFight or UnitAffectingCombat("player")) then return true end
    if set.hastarget and UnitExists("target") then return true end
    if set.attackable and TargetIsHostile() then return true end
    if set.ingroup and IsInGroup() then return true end
    if set.unmounted and not Riding() then return true end
    return false
end
Visibility.ShowRule = ShowRule

-- the spellbook tab of the spells window, open: spells are dragged from it onto the bars
local function SpellbookOpen()
    local book = _G.PlayerSpellsFrame and _G.PlayerSpellsFrame.SpellBookFrame
    return book and book:IsVisible() or false
end

-- editMode, spellbook: read once per pass by the caller, not once per member
local function CheckMember(data, editMode, spellbook)
    if editMode then return true end
    local fcmState = ns.ActionBars and ns.ActionBars.fcm
    -- every action bar shows while something is dragged onto them, or the spellbook is open
    if data.isBar and ((fcmState and fcmState.wasDragging) or spellbook) then return true end
    if data.fcm then
        return (fcmState and fcmState.unlockMode) or ShowRule(data.show) or (data.mouseOK and data.frame:IsMouseOver()) or false
    end
    if ShowRule(data.show) then return true end
    -- shown while its own settings page is open
    if data.owner and data.owner.IsSettingsPreview and data.owner:IsSettingsPreview() then return true end
    -- the totem bar's flyout (a totem's list) stands above the bar: shown while it's open
    if data.key == "totem" and _G.MultiCastFlyoutFrame and _G.MultiCastFlyoutFrame:IsShown() then return true end
    -- the pointer counts only with Mouseover ticked (11-12: some players don't want it)
    if not data.mouseOK then return false end
    if data.key == "quest" and ns.ObjectiveTracker.IsMouseOverExtras and ns.ObjectiveTracker:IsMouseOverExtras() then return true end
    -- a unit frame's holder has no size: its frame (and a ring style's portrait) is what's pointed at
    if data.mouse then return data.mouse() end
    return data.frame:IsMouseOver() or (data.isBar and FlyoutOver(data.frame))
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
-- A group whose members all reached its alpha isn't walked again until its show changes or an event
-- marks it; this slower pass still walks every group, to put back an alpha changed behind our back
local REPAIR_INTERVAL = 1
Fader.shows = {}            -- group -> fading in, from the last condition check
Fader.counting = {}         -- group -> its fade-out delay is running down
Fader.settled = {}          -- group -> the show every member had reached on its last walk
Fader.repairTimer = 0
Fader.UpdateScript = function(self, elapsed)
    self.updateTimer = self.updateTimer + elapsed
    local check = self.updateTimer >= CHECK_INTERVAL or next(self.dirty) ~= nil
    -- between checks only a running fade has work to do
    if not check and not self.fading then return end
    local tick = self.updateTimer
    local repair = false
    if check then
        self.updateTimer = 0
        self.repairTimer = self.repairTimer + tick
        if self.repairTimer >= REPAIR_INTERVAL then
            self.repairTimer = 0
            repair = true
        end
    end

    local hasActiveFades = false
    local editMode, spellbook   -- read once, on the first group checked

    for groupName, members in pairs(self.groups) do
        if check or self.shows[groupName] == nil then
            if editMode == nil then
                -- Quick Keybind mode too: Blizzard closes Edit Mode for it, and faded bars need binding
                editMode = (_G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown())
                    or (_G.QuickKeybindFrame and _G.QuickKeybindFrame:IsShown()) or false
                spellbook = SpellbookOpen()
            end
            local groupShouldShow = false
            for _, data in ipairs(members) do
                if CheckMember(data, editMode, spellbook) then groupShouldShow = true break end
            end

            if not self.delays[groupName] then self.delays[groupName] = 0 end
            if groupShouldShow then self.delays[groupName] = FADE_DELAY
            elseif self.delays[groupName] > 0 then self.delays[groupName] = self.delays[groupName] - tick end

            self.shows[groupName] = groupShouldShow or (self.delays[groupName] > 0)
            self.counting[groupName] = (not groupShouldShow) and self.delays[groupName] > 0
        end
        local effectiveShow = self.shows[groupName]

        if repair or self.dirty[groupName] or self.settled[groupName] ~= effectiveShow then
            local groupFading = false
            for _, data in ipairs(members) do
                local frame = data.frame
                local targetAlpha = effectiveShow and 1 or data.minAlpha
                -- (a member with its own apply keeps its value: its alpha can be secret)
                local currentAlpha = data.apply and data.value or frame:GetAlpha()
                if math_abs(currentAlpha - targetAlpha) > 0.005 then
                    groupFading = true
                    local change = data.fadeTime > 0 and elapsed / data.fadeTime or 1
                    local newAlpha = (currentAlpha < targetAlpha) and math_min(targetAlpha, currentAlpha + change) or math_max(targetAlpha, currentAlpha - change)
                    if data.apply then data.apply(newAlpha) else ApplyElementAlpha(frame, data.key, newAlpha) end
                elseif data.apply and repair then
                    data.apply(currentAlpha)
                end
            end
            if groupFading then
                hasActiveFades = true
                self.settled[groupName] = nil
            else
                self.settled[groupName] = effectiveShow
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
-- Always clears the rest; the conditions after the line (Mouseover first) are toggles
local SHOW_VALUES = { "always", "mouseover", "combat", "hastarget", "attackable", "ingroup", "unmounted" }
local GROUP_VALUES = { 0, 1, 2, 3, 4, 5 }

local function Values(copyKey, list, fallback)
    local names = ns.Settings and ns.Settings:Text(copyKey, "choices") or {}
    local values = {}
    for i, value in ipairs(list) do
        values[#values + 1] = { text = names[i] or fallback(value), value = value, isRadio = true }
        if value == "always" then values[#values + 1] = { isDivider = true } end
    end
    return values
end

-- what the Show dropdown ticks, and a click in it (no condition left ticked is Mouseover)
local function ShowSelection(key) return Conditions.Selection(Visibility:GetShow(key), SpecOf(key)) end
local function ToggleShow(key, value)
    Visibility:SetShow(key, Conditions.Toggle(Visibility:GetShow(key), value, SpecOf(key)))
end

local function Label(copyKey, fallback)
    return ns.Settings and ns.Settings:Text(copyKey, "label") or fallback
end

local SPEED_VALUES = { { text = L["Instant"], value = "instant", isRadio = true },
                       { text = L["Fast"], value = "fast", isRadio = true },
                       { text = L["Slow"], value = "slow", isRadio = true } }

local function BuildElementSettings(key)
    -- nothing fades while it's always shown (or a swing bar shows and hides itself)
    local function AlwaysShown()
        local show = Visibility:GetShow(key)
        return show == "always" or show == "inuse" or show == "bar1"
    end
    return {
        {
            name = Label("ab.bar.group", L["Fade Group"]), kind = LEM.SettingType.Dropdown, default = 0,
            values = Values("ab.bar.group", GROUP_VALUES, function(v) return v == 0 and L["None"] or tostring(v) end),
            get = function() return Visibility:GetGroup(key) end,
            set = function(_, value) Visibility:SetGroup(key, value) end,
        },
        {
            name = Label("ab.bar.show", L["Visibility"]), kind = LEM.SettingType.Dropdown, multiple = true,
            default = ELEMENT_BY_KEY[key] and ELEMENT_BY_KEY[key].defaultShow or "always",
            values = (function()
                local values = Values("ab.bar.show", SHOW_VALUES, function(v) return v end)
                local e = ELEMENT_BY_KEY[key]
                -- (11-13, Marcus) a line above the pair that can't be ticked together (the player frame)
                if e and e.health and e.mana then values[#values + 1] = { isDivider = true } end
                if e and e.health then values[#values + 1] = { text = L["Missing Health"], value = "health", isRadio = true } end
                if e and e.mana then values[#values + 1] = { text = L["Missing Mana"], value = "mana", isRadio = true } end
                if e and e.cap then table_insert(values, 1, { text = L["Same as Action Bar 1"], value = "bar1", isRadio = true }) end
                if e and e.inuse then
                    -- with the two that clear the rest, above the line
                    for i, v in ipairs(values) do
                        if v.isDivider then table_insert(values, i, { text = L["Only When In Use"], value = "inuse", isRadio = true }) break end
                    end
                end
                return values
            end)(),
            get = function() return ShowSelection(key) end,
            set = function(_, value) ToggleShow(key, value) end,
            desc = (ELEMENT_BY_KEY[key] and ELEMENT_BY_KEY[key].inuse
                and L["Only When In Use: the bar appears when this weapon swings and leaves soon after the swings stop."])
                or (ELEMENT_BY_KEY[key] and ELEMENT_BY_KEY[key].mana
                and L["Missing Health and Missing Mana can't be ticked together: the game hides both from addons, so they can't be combined."])
                or nil,
        },
        {
            name = L["Fade Speed"], kind = LEM.SettingType.Dropdown, default = "instant", values = SPEED_VALUES,
            get = function() return Visibility:GetFadeSpeed(key) end,
            set = function(_, value) Visibility:SetElementFade(key, "fadeSpeed", value) end,
            hidden = AlwaysShown,
            desc = L["How fast it appears and disappears.\n* Fast: 0.2 seconds\n* Slow: 0.4 seconds"],
        },
        {
            name = L["Faded Opacity"], kind = LEM.SettingType.Slider, default = 0, minValue = 0, maxValue = 100, valueStep = 5,
            formatter = function(value) return value .. "%" end,
            get = function() return Visibility:GetMinAlpha(key) end,
            set = function(_, value) Visibility:SetElementFade(key, "minAlpha", value) end,
            hidden = AlwaysShown,
            desc = L["How see-through it gets when faded. 0% is invisible."],
        },
    }
end

-- The rows under a Fading title that always stays open
local function WithVisibilityTitle(rows)
    table_insert(rows, 1, { name = "|cffffd100" .. L["Fading"] .. "|r", kind = LEM.SettingType.Expander,
        static = true, hideArrow = true, get = function() return true end, set = function() end })
    return rows
end

-- for the unit frames' Fading section (UnitFrames.lua BuildSettings): no fade group, no title
-- no Fade Speed either (they fade at once), and Faded Opacity on the player and pet only
-- Link Pet Frame (the player frame's Fading, 11-12, a player's idea): the pet frame fades with the
-- player frame, on the player's settings; pointing at either shows both. The pet's own Fading hides.
function Visibility:PetLinked()
    local db = GetDb()
    return db and db.petFollowsPlayer == true or false
end

function Visibility:UnitFrameSettings(unit)
    local key = "uf_" .. unit
    local rows = BuildElementSettings(key)
    local e = ELEMENT_BY_KEY[key]
    local kept = { rows[2] }   -- Visibility (1 Fade Group, 3 Fade Speed, 4 Faded Opacity)
    if not (e and e.noOpacity) then kept[#kept + 1] = rows[4] end
    if unit == "pet" then
        local function Linked() return Visibility:PetLinked() end
        for _, row in ipairs(kept) do
            local own = row.hidden
            row.hidden = function(...)
                if Linked() then return true end
                if type(own) == "function" then return own(...) end
                return own and true or false
            end
        end
    elseif unit == "player" then
        kept[#kept + 1] = {
            name = L["Link Pet Frame"], kind = LEM.SettingType.Checkbox, default = false,
            get = function() return Visibility:PetLinked() end,
            set = function(_, value)
                local db = GetDb()
                if not db then return end
                db.petFollowsPlayer = value and true or nil
                Visibility:Refresh()
            end,
            desc = L["The pet frame fades with the player frame, using these settings. Pointing at either shows both."],
        }
    end
    return kept
end

-- for the player cast bar's Fading section (UnitFrames.lua BuildPlayerCastSettings): Visibility and
-- Faded Opacity, hidden with Cinematic (it fades the bar itself)
function Visibility:PlayerCastSettings()
    local rows = BuildElementSettings("uf_playercastbar")
    local kept = { rows[2], rows[4] }
    for _, row in ipairs(kept) do
        local own = row.hidden
        row.hidden = function(...)
            if C_AddOns.IsAddOnLoaded("Cinematic") then return true end
            if own then return own(...) end
            return false
        end
    end
    return kept
end

-- for the resource bars' Fading section (ResourceBars.lua BuildSettings): with a fade group, no title
function Visibility:ResourceBarSettings(bar)
    return BuildElementSettings("rb_" .. bar)
end

-- for the Minimap module
function Visibility:MinimapSettings()
    local rows = BuildElementSettings("minimap")
    table.remove(rows, 4)   -- Faded Opacity
    table.remove(rows, 1)   -- Fade group
    -- a Fading section that opens and closes like the other dialogs' (11-13, Marcus: starts closed)
    return ns.EditSection("Fading", rows)
end

-- The Blizzard systems these settings go into, for the settings search (Settings/Registry.lua)
function Visibility:EditSystems()
    local list = {}
    if not (Enum.EditModeSystem and Enum.EditModeActionBarSystemIndices) then return list end
    for _, e in ipairs(ELEMENTS) do
        local system = e.system and Enum.EditModeSystem[e.system]
        local indices = Enum[e.indices or "EditModeActionBarSystemIndices"]
        local index = e.index and indices and indices[e.index]
        if system and (index or not e.index) then
            local frame = GetFrame(e.key)
            local ok, name = false, nil
            if frame and frame.GetSystemName then ok, name = pcall(frame.GetSystemName, frame) end
            list[#list + 1] = { system = system, index = index, name = (ok and type(name) == "string" and name) or e.frame or e.key }
        end
    end
    return list
end

local systemsAdded, frameAdded = false, {}
local function AddEditModeSettings()
    if not systemsAdded and ActionBarsOn() and Enum.EditModeSystem and Enum.EditModeActionBarSystemIndices then
        systemsAdded = true
        for _, e in ipairs(ELEMENTS) do
            local system = e.system and Enum.EditModeSystem[e.system]
            if system then
                local indices = Enum[e.indices or "EditModeActionBarSystemIndices"]
                local index = e.index and indices and indices[e.index]
                if not e.index or index then
                    local rows = BuildElementSettings(e.key)
                    -- Blizzard's own Bar Visible, higher up in the same dialog, hides the bar for good
                    -- whatever Show says: a line says so while it's set to anything but Always
                    if e.system == "ActionBar" then
                        local key = e.key
                        table_insert(rows, 1, {
                            name = "|cffff9933" .. L["Bar Visible above also hides this bar"] .. "|r",
                            kind = LEM.SettingType.Expander, static = true, hideArrow = true,
                            get = function() return true end, set = function() end,
                            hidden = function()
                                local frame = GetFrame(key)
                                local setting = frame and frame.visibility
                                return setting == nil or setting == "Always"
                            end,
                        })
                    end
                    rows = WithVisibilityTitle(rows)
                    -- the totem bar: Blizzard gives it no Size, FlareUI does (above Fading)
                    if e.key == "totem" and ns.ActionBars and ns.ActionBars.TotemSizeSetting then
                        table_insert(rows, 1, ns.ActionBars.TotemSizeSetting())
                    end
                    LEM:AddSystemSettings(system, rows, index)
                end
            end
        end
    end
    -- FlareUI's own frames (XP bar, buffs, debuffs, quest tracker): their rows go after their own
    for _, key in ipairs({ "xp", "buffs", "debuffs", "quest" }) do
        local frame = not frameAdded[key] and ElementOn(ELEMENT_BY_KEY[key]) and GetFrame(key)
        local settings = frame and LEM.GetFrameSettings and LEM:GetFrameSettings(frame)
        if settings then
            frameAdded[key] = true
            -- a Fading section that opens and closes like the frame's own (Core.lua ns.EditSections)
            -- before the Fonts section, which is always last (11-13)
            local at = #settings + 1
            for i, setting in ipairs(settings) do
                if setting.editSection == "Fonts" then at = i break end
            end
            for _, setting in ipairs(ns.EditSection("Fading", BuildElementSettings(key))) do
                table_insert(settings, at, setting)
                at = at + 1
            end
        end
    end
end

--------------------------------------------------
-- 8. PUBLIC API
--------------------------------------------------
-- part of the Action Bars module, and fades the minimap, buffs, debuffs and quest tracker for theirs:
-- each only touches its own
function Visibility:ShouldLoad()
    for _, e in ipairs(ELEMENTS) do
        if ElementOn(e) then return true end
    end
    return false
end

local HIDE_KEYS = {
    { "menu", "hideMicroMenu" }, { "bags", "hideBagBar" }, { "pet", "hidePetBar" },
    { "stance", "hideStanceBar" }, { "possess", "hidePossessBar" }, { "totem", "hideTotemBar" },
    { "raid", "hideRaidManager" }, { "endcaps", "hideEndCaps" },
}

--------------------------------------------------
-- 8b. UNIT FRAMES AND MISSING HEALTH
-- The fader keeps each unit frame's value itself and sets it through apply: with Missing Health the
-- holder's alpha comes from the unit's (secret) health, which Lua can't compare. A step curve turns
-- the health percent into the alpha: 1 below full, the fader's value at full (as the old Fade Player
-- and Pet did). Health changes apply it again.
--------------------------------------------------
local unitValues, healthCurves = {}, {}   -- key -> the fader's last value; key -> its curve
local healthMembers = {}                  -- members applied through the curve, rebuilt by Refresh

-- Missing Mana (the player frame, 11-11) the same way, through UnitPowerPercent: mana can be secret
-- too. With both ticked the frame shows while either is under full. Two secret answers can't be
-- joined in Lua, so a readable one decides (missing: shown; full: the other's answer counts), and with
-- both secret the frame shows.
local manaCurves = {}
local MANA = Enum.PowerType and Enum.PowerType.Mana or 0
local function Readable(v) return v ~= nil and not (issecretvalue and issecretvalue(v)) end

-- a class with no mana reads as 0 of 0 (missing): learned while the max is readable, else by class
local hasMana
local function HasMana()
    local ok, max = pcall(UnitPowerMax, "player", MANA)
    if ok and Readable(max) then hasMana = max > 0 end
    if hasMana == nil then
        local _, class = UnitClass("player")
        hasMana = class ~= "WARRIOR" and class ~= "ROGUE"
    end
    return hasMana
end

-- 1 below full, alpha at full
local function StepCurve(store, key, alpha)
    local curve = store[key]
    if not curve then
        curve = C_CurveUtil.CreateCurve()
        curve:SetType(Enum.LuaCurveType.Step)
        store[key] = curve
    end
    -- (11-13 performance pass) rebuilt only when the alpha changes, not on every health tick
    -- (the alpha kept in FlareUI's own table: the curve is Blizzard's object)
    local seen = key .. "_alpha"
    if store[seen] ~= alpha then
        curve:ClearPoints()
        curve:AddPoint(0, 1)
        curve:AddPoint(1, alpha)
        store[seen] = alpha
    end
    return curve
end

local function UnitApplier(data, unit, health, mana)
    return function(alpha)
        data.value, unitValues[data.key] = alpha, alpha
        local holder = data.frame
        if not (health or mana) or alpha >= 0.999 then holder:SetAlpha(alpha) return end
        local h, m
        if health then
            local ok, value = pcall(UnitHealthPercent, unit, false, StepCurve(healthCurves, data.key, alpha))
            if ok and value ~= nil then h = value end
        end
        if mana and HasMana() then
            local ok, value = pcall(UnitPowerPercent, "player", MANA, false, StepCurve(manaCurves, data.key, alpha))
            if ok and value ~= nil then m = value end
        end
        if h == nil and m == nil then holder:SetAlpha(alpha) return end
        if m == nil then holder:SetAlpha(h) return end
        if h == nil then holder:SetAlpha(m) return end
        -- both: a curve answers 1 while its bar is missing some
        if Readable(h) then holder:SetAlpha(h >= 0.999 and 1 or m)
        elseif Readable(m) then holder:SetAlpha(m >= 0.999 and 1 or h)
        else holder:SetAlpha(1) end
    end
end

-- /fui fadedebug: the player frame's Visibility, each condition, the health and mana answers (hidden
-- from addons or not) and the opacity it gets, for a report
function Visibility:DebugPlayer()
    local function S(x) if x == nil then return "nil" end; if issecretvalue and issecretvalue(x) then return "hidden" end; return tostring(x) end
    local show = self:GetShow("uf_player")
    print("|cffffd100FlareUI fade|r player frame, Visibility: " .. tostring(show))
    print("  in combat " .. S(UnitAffectingCombat("player")) .. ", target " .. S(UnitExists("target")) .. ", group " .. S(IsInGroup())
        .. ", mounted " .. S(IsMounted()))
    local member
    for _, data in ipairs(healthMembers) do if data.key == "uf_player" then member = data end end
    if not member then print("  not on the health / mana watch") return end
    print("  fader value " .. S(member.value) .. ", faded opacity " .. S(member.minAlpha) .. ", health " .. S(member.healthUnit)
        .. ", mana " .. S(member.manaWatch) .. ", has mana " .. S(HasMana()))
    local okH, h = pcall(UnitHealthPercent, "player", false, StepCurve(healthCurves, "dbgH", 0))
    local okM, m = pcall(UnitPowerPercent, "player", MANA, false, StepCurve(manaCurves, "dbgM", 0))
    print("  health curve " .. (okH and S(h) or "error") .. ", mana curve " .. (okM and S(m) or "error")
        .. ", frame alpha " .. S(member.frame:GetAlpha()))
end

local healthWatch = CreateFrame("Frame")
healthWatch:SetScript("OnEvent", function(_, event, unit, powerType)
    -- (UNIT_PET: a new pet's health)
    if event == "UNIT_PET" then unit = "pet" end
    local power = event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER"
    if power and powerType ~= "MANA" then return end
    for _, data in ipairs(healthMembers) do
        if (power and data.manaWatch) or (not power and data.healthUnit == unit) then data.apply(data.value) end
    end
end)
local function WatchHealth(on, mana)
    if on and not healthWatch.on then
        healthWatch:RegisterUnitEvent("UNIT_HEALTH", "player", "pet")
        healthWatch:RegisterUnitEvent("UNIT_MAXHEALTH", "player", "pet")
        healthWatch:RegisterUnitEvent("UNIT_PET", "player")
    elseif not on and healthWatch.on then
        healthWatch:UnregisterAllEvents()
        healthWatch.mana = nil
    end
    healthWatch.on = on
    if on and mana ~= healthWatch.mana then
        if mana then
            healthWatch:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
            healthWatch:RegisterUnitEvent("UNIT_MAXPOWER", "player")
        else
            healthWatch:UnregisterEvent("UNIT_POWER_UPDATE")
            healthWatch:UnregisterEvent("UNIT_MAXPOWER")
        end
        healthWatch.mana = mana
    end
end

local function AddMember(groupName, data)
    Fader.groups[groupName] = Fader.groups[groupName] or {}
    table_insert(Fader.groups[groupName], data)
end

function Visibility:Refresh()
    -- In a fight only the fader is rebuilt (alpha, allowed on protected frames), so a Show or fade
    -- change counts at once; hiding for good waits, and the whole pass runs again when the fight
    -- ends (OnVisibilityStateChange)
    local inCombat = InCombatLockdown()
    self.refreshPending = inCombat or nil
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
    for _, pair in ipairs((barsOn and not inCombat) and HIDE_KEYS or {}) do
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
    if barsOn and not inCombat then
        SetMicroFlashesBlank(db.hideMicroMenu)
        UpdateMicroTips()
    end

    Fader.groups = {}
    Fader.delays = {}
    Fader.dirty = {}
    Fader.shows = {}
    Fader.counting = {}
    Fader.settled = {}
    Fader.watchesMouseover = false
    Fader.fading = false
    healthMembers = {}
    local watchMana = false

    local fcm = ns.db.profile.fcm
    capsFollowBar1 = {}
    for _, e in ipairs(ELEMENTS) do
        local key = e.key
        local frame = GetFrame(key)
        if e.cap and frame and ElementOn(e) and self:GetShow(key) == "bar1" then
            capsFollowBar1[frame] = true
            local bar1 = GetFrame("bar1")
            local alpha = bar1 and bar1:GetAlpha()
            frame:SetAlpha(type(alpha) == "number" and canaccessvalue(alpha) and alpha or 1)
        elseif ElementOn(e) and frame and frame.GetAlpha then
            local isBar = key:match("^bar[1-8]$") ~= nil
            local fcmBar = isBar and fcm and fcm.bars and fcm.bars[key]
            if fcmBar and fcmBar.enabled then
                -- Fake CM bars: their own rule, one group; the pointer only with Mouseover ticked
                local fcmShow = fcm.show or "combat"
                local mouseOK = Conditions.Has(fcmShow, "mouseover", SHOW_SPEC)
                AddMember("fcm", { key = key, frame = frame, isBar = true, fcm = true, show = fcmShow, mouseOK = mouseOK,
                                   fadeTime = ns.FadeTime(self:GetFadeSpeed(key)), minAlpha = 0 })
                if mouseOK then Fader.watchesMouseover = true end
            else
                local show = self:GetShow(key)
                -- Link Pet Frame: the pet takes the player frame's choices and fades in its group
                local linkPet = key == "uf_pet" and self:PetLinked() and ElementOn(ELEMENT_BY_KEY.uf_player)
                local settingsKey = linkPet and "uf_player" or key
                if linkPet then show = self:GetShow("uf_player") end
                if show == "always" or show == "inuse" then
                    ApplyElementAlpha(frame, key, 1)
                    if e.own then unitValues[key] = 1 end
                else
                    local group = self:GetGroup(key)
                    local owner = (key == "quest" and ns.ObjectiveTracker) or ((key == "buffs" or key == "debuffs") and ns.Auras) or nil
                    local unit = e.unit
                    local mouse = unit and function() return ns.UnitFrames:IsMouseOverUnit(unit) end or nil
                    if e.noGroup then group = 0 end
                    local data = { key = key, frame = frame, isBar = isBar, show = show, owner = owner, mouse = mouse,
                                   fadeTime = e.instant and 0 or ns.FadeTime(self:GetFadeSpeed(settingsKey)),
                                   minAlpha = e.noOpacity and 0 or self:GetMinAlpha(settingsKey) / 100 }
                    -- the pointer shows it only with Mouseover ticked
                    data.mouseOK = Conditions.Has(show, "mouseover", SpecOf(settingsKey))
                    if e.own then
                        -- (a linked pet: the player's Missing Health / Mana show the pair; the pet's own health doesn't)
                        local health = not linkPet and e.health and Conditions.Has(show, "health", SpecOf(key)) or false
                        local mana = not linkPet and e.mana and Conditions.Has(show, "mana", SpecOf(key)) or false
                        -- a setup from before they were exclusive with both: Missing Mana stays
                        if health and mana then health = false end
                        data.healthUnit = health and e.health or nil
                        data.manaWatch = mana or nil
                        if mana then watchMana = true end
                        data.value = unitValues[key] or 1
                        data.apply = UnitApplier(data, e.health, health, mana)
                        if health or mana then healthMembers[#healthMembers + 1] = data end
                        -- the holder put right at once: an alpha left by the curve can't be read back
                        data.apply(data.value)
                    end
                    AddMember(linkPet and "uf_player" or (group > 0 and ("group" .. group) or key), data)
                    Fader.watchesMouseover = true
                end
            end
        end
    end

    WatchHealth(#healthMembers > 0, watchMana)
    MarkAllDirty()
end

function Visibility:Init()
    if not GetDb() or not self:ShouldLoad() then return end
    self:Refresh()
    -- modules start in no set order: once more when every one has made its frames
    C_Timer.After(0, function() Visibility:Refresh() end)
    hooksecurefunc(_G.HelpTip, "Show", UpdateMicroTips)

    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnVisibilityStateChange")
    self:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED", "OnVisibilityStateChange")
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnVisibilityStateChange")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnVisibilityStateChange")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnVisibilityStateChange")
    -- the Not mounted and In a group Show conditions
    self:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED", "OnVisibilityStateChange")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnVisibilityStateChange")
    -- bars show while the spellbook is open (Blizzard_PlayerSpells loads on demand)
    EventUtil.ContinueOnAddOnLoaded("Blizzard_PlayerSpells", function()
        local book = _G.PlayerSpellsFrame and _G.PlayerSpellsFrame.SpellBookFrame
        if not book then return end
        book:HookScript("OnShow", MarkAllDirty)
        book:HookScript("OnHide", MarkAllDirty)
    end)

    if _G.EditModeManagerFrame then
        _G.EditModeManagerFrame:HookScript("OnShow", function() Visibility:Refresh() end)
        _G.EditModeManagerFrame:HookScript("OnHide", function() Visibility:Refresh() end)
    end
    -- Quick Keybind mode shows every faded bar, as Edit Mode does
    if EventRegistry then
        EventRegistry:RegisterCallback("QuickKeybindFrame.QuickKeybindModeEnabled", function() Visibility:Refresh() end, Visibility)
        EventRegistry:RegisterCallback("QuickKeybindFrame.QuickKeybindModeDisabled", function() Visibility:Refresh() end, Visibility)
    end
    -- Blizzard's dialogs now, FlareUI's own frames once they exist
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
-- A condition changed (a drag began or ended): every fade group is checked again, without the
-- full rebuild of Refresh
function Visibility:Wake()
    MarkAllDirty()
end

function Visibility:OnVisibilityStateChange(event)
    if event == "PLAYER_REGEN_DISABLED" then self.inFight = true
    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" then self.inFight = nil end
    if event == "PLAYER_REGEN_ENABLED" and self.refreshPending then
        self:Refresh()
    else
        MarkAllDirty()
    end
end
