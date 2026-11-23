local _, ns = ...
local L = ns.L

--------------------------------------------------
-- VISIBILITY
-- Show conditions (always | mouseover | any of combat, hastarget, attackable, ingroup, unmounted), fade groups 1-5,
-- Show Speed, Hide Speed and Faded Opacity for the action bars, bag bar, micro menu, XP bar, minimap, buffs, debuffs,
-- quest tracker and the player, pet, target, focus and target-of unit frames (fade groups: the player and pet only), set in each element's Edit Mode dialog, plus the Blizzard pieces hidden for good. Fake CM bars follow profile.fcm.show and never the mouse.
-- Also the chat (every chat window, with New Messages and a Fade Delay), the damage meter (which fades
-- itself: this module says when it is wanted) and the separate threat window.
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
-- delay: a Fade Delay row and its default, in seconds (11-23, Malkkav: every frame that is always there
-- and fades only by its Visibility; not the frames the game itself shows and hides, as target, focus,
-- the cast bar, totems, swing, flight, timer and seal bars)
local ELEMENTS = {
    { key = "bar1", delay = 0, frame = "MainActionBar", system = "ActionBar", index = "MainBar" },
    { key = "bar2", delay = 0, frame = "MultiBarBottomLeft", system = "ActionBar", index = "Bar2" },
    { key = "bar3", delay = 0, frame = "MultiBarBottomRight", system = "ActionBar", index = "Bar3" },
    { key = "bar4", delay = 0, frame = "MultiBarRight", system = "ActionBar", index = "RightBar1" },
    { key = "bar5", delay = 0, frame = "MultiBarLeft", system = "ActionBar", index = "RightBar2" },
    { key = "bar6", delay = 0, frame = "MultiBar5", system = "ActionBar", index = "ExtraBar1" },
    { key = "bar7", delay = 0, frame = "MultiBar6", system = "ActionBar", index = "ExtraBar2" },
    { key = "bar8", delay = 0, frame = "MultiBar7", system = "ActionBar", index = "ExtraBar3" },
    { key = "pet", delay = 0, frame = "PetActionBar", system = "ActionBar", index = "PetActionBar" },
    { key = "stance", delay = 0, frame = "StanceBar", system = "ActionBar", index = "StanceBar" },
    -- Blizzard's shaman Totem Bar: fade groups, and a Size row (ActionBars.lua)
    { key = "totem", delay = 0, frame = "MultiCastActionBarFrame", system = "TotemActionBar" },
    -- The gryphons: on Forever each is its own Edit Mode system; their Visibility is their own (they
    -- ignore bar 1's alpha, Refresh). Same as Action Bar 1 was removed 11-20 (Malkkav): a fade group with
    -- bar 1 does the same; saved "bar1" choices were moved once (Visibility.MigrateCapsBar1).
    { key = "capLeft", delay = 0, cap = "LeftEndCap", system = "MainActionBarEndCap", index = "EndCapLeft",
      indices = "EditModeMainActionBarEndCapSystemIndices" },
    { key = "capRight", delay = 0, cap = "RightEndCap", system = "MainActionBarEndCap", index = "EndCapRight",
      indices = "EditModeMainActionBarEndCapSystemIndices" },
    { key = "bags", delay = 0, frame = "BagsBar", system = "Bags" },
    { key = "menu", delay = 0, frame = "MicroMenuContainer", system = "MicroMenu" },
    { key = "xp", delay = 0 },   -- FlareUI's XP bar, its own Edit Mode frame
    { key = "minimap", delay = 0, frame = "MinimapCluster", needsMinimap = true },   -- with the Minimap module
    -- FlareUI's own Edit Mode frames, each with its module
    -- (never: Visibility > Never hides them for good, SeanWcom's report 11-19)
    { key = "buffs", delay = 0, module = "auras", never = true },
    { key = "debuffs", delay = 0, module = "auras", never = true },
    { key = "quest", delay = 0, module = "objectivetracker" },
    -- The unit frames (UnitFrames.lua section 14). own: the fader keeps the value and sets it through
    -- apply (an alpha left by the health curve can't be read back); health: Missing Health, from that unit
    -- instant: a unit frame (own speeds only, Instant until picked); noOpacity: no Faded Opacity (faded right out)
    -- noGroup: never in a fade group. The player and pet frames can join one: they then fade at the
    -- group's speeds, and pointing at either brings the whole group back.
    -- mana: Missing Mana too (the player frame only)
    { key = "uf_player", delay = 0, unit = "player", module = "unitframes", own = true, instant = true, health = "player", mana = true },
    { key = "uf_pet", delay = 0, unit = "pet", module = "unitframes", own = true, instant = true, health = "pet" },
    { key = "uf_target", unit = "target", module = "unitframes", own = true, noGroup = true, instant = true, noOpacity = true },
    { key = "uf_targettarget", unit = "targettarget", module = "unitframes", own = true, noGroup = true, instant = true, noOpacity = true },
    { key = "uf_focus", unit = "focus", module = "unitframes", own = true, noGroup = true, instant = true, noOpacity = true },
    { key = "uf_focustarget", unit = "focustarget", module = "unitframes", own = true, noGroup = true, instant = true, noOpacity = true },
    -- the FlareUI Player Cast Bar: Visibility and Faded Opacity only. Not with Cinematic, which fades it
    -- between fights itself (its bar then ignores the holder's alpha)
    -- never: a Never choice, so neither FlareUI's bar nor Blizzard's shows (the player frame's
    -- own Cast Bar can take over); Edit Mode still shows it
    { key = "uf_playercastbar", castbar = true, module = "unitframes", own = true, noGroup = true, instant = true, never = true },
    -- FlareUI Totems (Totems.lua): fade groups, and never: a Never choice that
    -- keeps them out for good (Edit Mode still shows them)
    { key = "uf_totems", totems = true, module = "unitframes", never = true },
    -- The resource bars (ResourceBars.lua), fade groups allowed. They still hide on their own where they
    -- don't apply (druid mana, combo points, a swing bar with no weapon); inuse: a swing bar's Only When In
    -- Use, which the bar shows and hides itself
    { key = "rb_health", delay = 0, bar = "health", own = true, health = "player" },
    { key = "rb_power", delay = 0, bar = "power", own = true },
    { key = "rb_mana", delay = 0, bar = "mana", own = true },
    { key = "rb_combo", delay = 0, bar = "combo", own = true },
    { key = "rb_swingMain", bar = "swingMain", own = true, inuse = true },
    { key = "rb_swingOff", bar = "swingOff", own = true, inuse = true },
    { key = "rb_swingRanged", bar = "swingRanged", own = true, inuse = true },
    { key = "rb_flight", bar = "flight", own = true },   -- the Flight Timer: it shows only in flight itself
    { key = "rb_timer", bar = "timer", own = true },     -- Timer Bars: they show only while a timer runs
    { key = "rb_seal", bar = "seal", own = true },       -- Seals: a seal's bar shows only while that seal is up
    -- The chat, the damage meter and the separate threat window, faded from their Edit Mode dialogs.
    -- page: the settings page whose search lists the rows (EditSystems). delay: a Fade Delay row and
    -- its default, in seconds.
    -- chat: the fader sets every chat window's alpha (Chat.lua FadeApply); typing always shows it, and
    -- New Messages ("messages") is the chat's own condition (Chat.lua section 16)
    { key = "chat", system = "ChatFrame", module = "chat", chat = true, messages = true, delay = 5, page = "ch" },
    -- external: the meter fades itself (DamageMeter.lua section 22: Blizzard shows and hides it, and it
    -- can't be shown in a fight); the fader only says when it is wanted (ElementShown). Never: only in
    -- Edit Mode or at its Faded Opacity; In an Instance ("instance"): the meter's and the threat
    -- window's own condition
    { key = "meter", system = "DamageMeter", module = "damagemeter", external = true, never = true, instance = true,
      delay = 0, page = "dm" },
    -- the separate threat window: Same as Meter ("meter") by default, as a child of the meter it fades with
    -- it; any other choice, or a fade group, detaches it (DamageMeter.AttachThreatWindow)
    { key = "threat", threat = true, module = "damagemeter", instance = true, defaultShow = "meter" },
    -- Blizzard's Cooldown Manager viewers (CooldownManager.lua), behind its switch. keepAlpha: Blizzard's dialog has an
    -- Opacity of its own, so on Always the alpha is left alone unless FlareUI faded the viewer this session.
    -- cdmGrow: a Growth in a Frame section (CooldownManager.GrowSetting); cdmShape: an Icon Shape in a Look
    -- section (CooldownManager.ShapeSetting); both above Fading
    { key = "cdm_essential", delay = 0, page = "cdm", frame = "EssentialCooldownViewer", system = "CooldownViewer", index = "Essential",
      indices = "EditModeCooldownViewerSystemIndices", keepAlpha = true,
      cdmShape = "essential" },
    { key = "cdm_utility", delay = 0, page = "cdm", frame = "UtilityCooldownViewer", system = "CooldownViewer", index = "Utility",
      indices = "EditModeCooldownViewerSystemIndices", keepAlpha = true,
      cdmShape = "utility" },
    { key = "cdm_buffs", delay = 0, page = "cdm", frame = "BuffIconCooldownViewer", system = "CooldownViewer", index = "BuffIcon",
      indices = "EditModeCooldownViewerSystemIndices", keepAlpha = true,
      cdmShape = "buffs", cdmGrow = "buffs" },
    { key = "cdm_bars", delay = 0, page = "cdm", frame = "BuffBarCooldownViewer", system = "CooldownViewer", index = "BuffBar",
      indices = "EditModeCooldownViewerSystemIndices", keepAlpha = true, cdmGrow = "bars" },
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
    elseif key == "uf_totems" then
        return ns.Totems and ns.Totems.initialized and _G.FlareUI_Totems or nil
    elseif key == "chat" then
        return _G.ChatFrame1
    elseif key == "meter" then
        return _G.DamageMeter
    elseif key == "threat" then
        return _G.FlareUI_ThreatMeter
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


-- The game draws the minimap's player arrow, quest marks and other blips itself, at full strength
-- whatever the alpha, and has no API for them: only an empty mask or hiding removes them. So the map goes once
-- it has faded right out (the cluster stays, so pointing at it still brings it back).
-- With the Minimap module running, the map is masked empty instead (Minimap.lua MM:SetMapFaded):
-- gathering addons stop scanning a hidden map. Hiding stays the fallback.
local minimapFadedOut = false
local function SetMinimapDrawn(alpha)
    local map = _G.Minimap
    -- the blips go while the map is faded at all (they ignore alpha), so a Faded Opacity and a fade
    -- group work for the minimap too
    if ns.Minimap and ns.Minimap.SetIconsFaded then ns.Minimap:SetIconsFaded(alpha < 0.99) end
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
-- its own setting back, never the flash forced on (Blizzard's action buttons have it off: forced on,
-- every button flashed as the global cooldown ended)
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

-- ClassicUI Forever moves each bar's buttons out of the bar into its own
-- holder frames, and copies the bar's alpha onto the holder only now and then (its layout and fade
-- passes). A faded bar then showed whatever alpha was copied last: bars 4 and 5 popped up on a stance
-- bar hover. With the buttons taken, FlareUI fades the buttons themselves and leaves the bar at 1, so
-- the holder never copies a stale value. Checked each time: the other addon moves them after login.
local function ButtonsTaken(frame)
    local button = frame.actionButtons and frame.actionButtons[1]
    if not button then return false end
    local parent = button:GetParent()
    for _ = 1, 4 do
        if not parent then return true end
        if parent == frame then return false end
        parent = parent:GetParent()
    end
    return true
end

local function ApplyElementAlpha(frame, key, alpha)
    -- the chat: every window FlareUI skins, not only the first (Chat.lua)
    if key == "chat" then
        if ns.Chat and ns.Chat.FadeApply then ns.Chat:FadeApply(alpha) end
        return
    end
    if frame.actionButtons and ButtonsTaken(frame) then
        frame.FlareUI_FadeAlpha = alpha
        frame:SetAlpha(1)
        for _, button in ipairs(frame.actionButtons) do button:SetAlpha(alpha) end
    else
        if frame.FlareUI_FadeAlpha then
            -- the buttons came back (the other addon turned off): theirs back to full, the bar fades again
            frame.FlareUI_FadeAlpha = nil
            for _, button in ipairs(frame.actionButtons or {}) do button:SetAlpha(1) end
        end
        frame:SetAlpha(alpha)
    end
    if frame.actionButtons then SetBarBling(frame, alpha) end
    if key == "minimap" then SetMinimapDrawn(alpha) end
    -- the tracker's lone "+" and its quest item buttons sit on UIParent, outside its frame
    if key == "quest" and ns.ObjectiveTracker.SetFadeAlpha then ns.ObjectiveTracker:SetFadeAlpha(alpha) end
    -- faded right out, the totems can't be right-clicked away unseen
    if key == "uf_totems" and ns.Totems.SetFaded then ns.Totems.SetFaded(alpha <= 0.01) end
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

-- Mouseover is a condition ticked with the others; in older profiles any condition also showed the
-- element under the pointer. Once per profile, every condition choice gets Mouseover ticked, so
-- nothing changes until the player unticks it (Fake CM never followed the pointer: left alone)
local function MigrateMouseToken(db)
    db.mouseToken = true
    local C = ns.Conditions
    local function Add(show)
        show = type(show) == "string" and (C.BAR_LEGACY[show] or show) or show
        if type(show) ~= "string" or show == "always" or show == "inuse" or show == "bar1" or show == "meter" or show == "never" or show == "" then return nil end
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

-- The chat's, the damage meter's and the threat window's fading, once set on their settings pages:
-- once per profile, those old settings become their entries here, so nothing changes
-- for anyone. The old values stay where they were, unused. Runs after MigrateMouseToken, which must
-- not add Mouseover to these (the old chat and meter said themselves when the mouse counts).
local function MigrateMovedFades(db)
    db.fadesMoved = true
    local profile = ns.db.profile
    local elements = db.elements
    if not (profile and elements) then return end
    local C = ns.Conditions
    local function Percent(v) return math.floor(math_max(0, math_min(0.9, tonumber(v) or 0)) * 100 + 0.5) end
    local function Speed(old, field) return old[field] or old.fadeSpeed or "instant" end
    -- the chat: Chat Interactions (new messages, typing, pointing at it) and + In Combat; a test build
    -- saved toggles ("messages,incombat"), read as the nearest of the two (as Chat.VisibilityHas did)
    local chat = profile.chat
    if chat and elements.chat == nil then
        local v = chat.visibility or "always"
        local show = "always"
        if v ~= "always" then
            local combat = v == "combat" or (v ~= "interactions" and C.Has(v, "incombat"))
            show = combat and "mouseover,combat,messages" or "mouseover,messages"
        end
        local delay = tonumber(chat.autoHideDelay) or 5
        if show ~= "always" or chat.fadeIn or chat.fadeOut or Speed(chat, "fadeIn") ~= "instant"
                or Percent(chat.minAlpha) > 0 or delay ~= 5 then
            elements.chat = { show = show, group = 0, fadeIn = Speed(chat, "fadeIn"), fadeOut = Speed(chat, "fadeOut"),
                              minAlpha = Percent(chat.minAlpha), fadeDelay = delay }
        end
    end
    -- the meter: Always / In Combat / In a Group / In an Instance / Hidden, and Show on Mouseover; a test
    -- build saved toggles ("combat,group", "mouseover"), read as DamageMeter.lua's NormalizeChoices did
    local dm = profile.damagemeter
    if dm and elements.meter == nil then
        local v = dm.visibility or "always"
        local mouse = dm.showOnMouseover and true or false
        if v ~= "always" and v ~= "combat" and v ~= "group" and v ~= "instance" and v ~= "hidden" then
            local set = C.Set(v)
            if set.mouseover then mouse = true end
            v = (set.combat and "combat") or (set.group and "group") or "hidden"
        end
        local show = ({ always = "always", combat = "combat", group = "ingroup", instance = "instance" })[v]
        if v == "hidden" then show = mouse and "mouseover" or "never"
        elseif mouse and show ~= "always" then show = "mouseover," .. show end
        local delay = tonumber(dm.fadeDelay) or 0
        if show ~= "always" or dm.fadeIn or dm.fadeOut or Speed(dm, "fadeIn") ~= "instant"
                or Percent(dm.minAlpha) > 0 or delay ~= 0 then
            elements.meter = { show = show, group = 0, fadeIn = Speed(dm, "fadeIn"), fadeOut = Speed(dm, "fadeOut"),
                               minAlpha = Percent(dm.minAlpha), fadeDelay = delay }
        end
    end
    -- the threat window: With the Meter stays Same as Meter; its own In an Instance / In a Group /
    -- In Combat detach it, fading at the meter's speeds and to its Faded Opacity as before
    if dm and elements.threat == nil then
        local show = ({ instance = "instance", group = "ingroup", combat = "combat" })[dm.threatVisibility or "meter"]
        if show then
            elements.threat = { show = show, group = 0, fadeIn = Speed(dm, "fadeIn"), fadeOut = Speed(dm, "fadeOut"),
                                minAlpha = Percent(dm.minAlpha) }
        end
    end
end

local function GetDb()
    local db = ns.db and ns.db.profile and ns.db.profile.visibility
    if db and not db.mouseToken then MigrateMouseToken(db) end
    if db and not db.fadesMoved then MigrateMovedFades(db) end
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
    if e.system == "CooldownViewer" then
        local CM = ns.CooldownManager
        return CM and CM.Started and CM.Started() and CM.Enabled() or false
    end
    if e.bar then
        local uf = ns.db and ns.db.profile and ns.db.profile.unitframes
        return uf and uf.resource and uf.resource.enabled or false
    end
    if e.castbar then
        if C_AddOns.IsAddOnLoaded("Cinematic") then return false end
        local uf = ns.db and ns.db.profile and ns.db.profile.unitframes
        return uf and uf.enabled and uf.playerCastbar and uf.playerCastbar.enabled or false
    end
    -- the chat steps back while another chat addon runs (Chat.lua GetOtherChatAddon)
    if e.chat and ns.Chat and ns.Chat.GetOtherChatAddon and ns.Chat:GetOtherChatAddon() then return false end
    if e.threat then
        local dm = ns.db and ns.db.profile and ns.db.profile.damagemeter
        return dm and dm.enabled and dm.threatWindow and true or false
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
-- Same as Action Bar 1 (the gryphons' old default) is gone: once per profile, a gryphon on it joins bar
-- 1's fade group, or takes bar 1's own choices when bar 1 has none, so it keeps fading as it did
function Visibility.MigrateCapsBar1(db)
    if not db or db.capsBar1Moved then return end
    db.capsBar1Moved = true
    db.elements = db.elements or {}
    local bar1 = db.elements.bar1
    local bar1Group = bar1 and bar1.group or 0
    for _, key in ipairs({ "capLeft", "capRight" }) do
        local cfg = db.elements[key]
        local inGroup = cfg and cfg.group and cfg.group > 0
        if not inGroup and (not cfg or cfg.show == nil or cfg.show == "bar1") then
            cfg = cfg or {}
            db.elements[key] = cfg
            if bar1Group > 0 then
                cfg.group, cfg.show = bar1Group, "always"
            else
                cfg.group = 0
                cfg.show = (bar1 and bar1.show ~= "bar1" and bar1.show) or "always"
                if bar1 then cfg.fadeIn, cfg.fadeOut, cfg.minAlpha = bar1.fadeIn, bar1.fadeOut, bar1.minAlpha end
            end
        end
    end
end

-- NO TOOLTIPS FROM HIDDEN FRAMES (11-20, Malkkav, from a Discord report): a frame on Never is only
-- see-through, so its buttons, auras and icons would still show tooltips under the pointer. Any tooltip
-- owned by such a frame, or by anything inside it, closes as it opens. Edit Mode still shows them.
Visibility.neverFrames = {}
Visibility.NEVER_DEPTH = 6   -- parents climbed from the tooltip's owner
function Visibility.HideNeverTooltip(tip)
    if not next(Visibility.neverFrames) then return end
    if _G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown() then return end
    local owner = tip:GetOwner()
    for _ = 1, Visibility.NEVER_DEPTH do
        if not owner then return end
        if Visibility.neverFrames[owner] then tip:Hide() return end
        owner = owner.GetParent and owner:GetParent() or nil
    end
end
function Visibility.WatchNeverTooltips()
    if Visibility.neverWatched then return end
    Visibility.neverWatched = true
    for _, tip in ipairs({ _G.GameTooltip, _G.ItemRefTooltip }) do
        if tip then tip:HookScript("OnShow", Visibility.HideNeverTooltip) end
    end
end

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

-- The group an element is in, or nil. A group owns its members' Show, fade speeds and Faded Opacity.
local function ElementGroup(key)
    local db, cfg = GetDb(), ElementConfig(key)
    return cfg and cfg.group and cfg.group > 0 and db.groups and db.groups[cfg.group] or nil
end

-- Show Speed (coming back) and Hide Speed (fading away). Nothing is rewritten: an owner without its
-- own fadeIn / fadeOut reads the single fadeSpeed of older profiles for both, then the profile-wide
-- ones, so nothing changes until a player picks a new speed.
local function FadeSpeedOf(key, field)
    local db, group = GetDb(), ElementGroup(key)
    local owner = group or ElementConfig(key)
    -- a unit frame on its own has its own speeds: only what was picked for it, never the profile-wide
    -- speeds, so it stays Instant until a player picks one
    local e = ELEMENT_BY_KEY[key]
    if e and e.instant and not group then return (owner and (owner[field] or owner.fadeSpeed)) or "instant" end
    return (owner and (owner[field] or owner.fadeSpeed)) or (db and (db[field] or db.fadeSpeed)) or "instant"
end
function Visibility:GetFadeIn(key) return FadeSpeedOf(key, "fadeIn") end
function Visibility:GetFadeOut(key) return FadeSpeedOf(key, "fadeOut") end

-- in percent
function Visibility:GetMinAlpha(key)
    local owner = ElementGroup(key) or ElementConfig(key)
    return owner and owner.minAlpha or 0
end

-- Fade Delay: seconds it stays after its last reason to show. The chat and the meter keep their own,
-- also in a fade group (they wait themselves: Chat.lua FadeHold, DamageMeter.lua); every other frame
-- takes its fade group's, as its speeds
local function DelayOwner(key, create)
    local e = ELEMENT_BY_KEY[key]
    if e and (e.chat or e.external) then return ElementConfig(key, create) end
    return ElementGroup(key) or ElementConfig(key, create)
end

function Visibility:GetFadeDelay(key)
    local owner, e = DelayOwner(key), ELEMENT_BY_KEY[key]
    return math_max(0, tonumber(owner and owner.fadeDelay) or (e and e.delay) or 0)
end

function Visibility:SetFadeDelay(key, value)
    local cfg = DelayOwner(key, true)
    if not cfg then return end
    cfg.fadeDelay = value
    self:Refresh()
    -- Fade Old Lines: a line stays Fade Delay seconds
    if key == "chat" and ns.Chat and ns.Chat.ApplyLineFade then ns.Chat.ApplyLineFade() end
end

-- a condition ticked in the element's Visibility (its group's, in a group)
function Visibility:HasToken(key, token)
    return ns.Conditions.Has(self:GetShow(key), token, self.SpecOf and self.SpecOf(key) or nil)
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
    local show, fadeIn, fadeOut, minAlpha = self:GetShow(key), self:GetFadeIn(key), self:GetFadeOut(key), self:GetMinAlpha(key)
    local e = ELEMENT_BY_KEY[key]
    local delay = e and e.delay and not (e.chat or e.external) and self:GetFadeDelay(key) or nil
    -- (the threat window on Same as Meter brings the meter's; the meter's Never can't lead a group)
    if show == "meter" then show = self:GetShow("meter") end
    if show == "never" and (key == "meter" or key == "threat") then show = "always" end
    local target = db.groups and db.groups[group]
    if group == 0 then
        target = cfg
    elseif target and GroupHasMembers(group, key) then
        target = nil
    end
    if target then
        target.show, target.fadeIn, target.fadeOut, target.minAlpha = show, fadeIn, fadeOut, minAlpha
        -- (the Fade Delay too, when the frame has one: a group's members share it)
        if delay then target.fadeDelay = delay ~= 0 and delay or nil end
    end
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

-- only a selection hidden below is restored, with the frame's own mouse setting (and the Edit Mode
-- eye's choice of shown or hidden boxes, EditModeOverlays.lua)
local function RestoreMoverOfFrame(frame)
    if frame and frame.Selection and frame.Selection.FlareUI_HiddenMover then
        frame.Selection.FlareUI_HiddenMover = nil
        local eyeShut = ns.db and ns.db.profile and ns.db.profile.editModeOverlaysHidden
        frame.Selection:SetAlpha(eyeShut and 0 or 1)
        if frame.Selection.Label then frame.Selection.Label:SetAlpha(1) end
        frame:EnableMouse(frame.FlareUI_MouseWas ~= false)
        frame.FlareUI_MouseWas = nil
        frame.Selection:EnableMouse(true)
    end
end

-- only on a frame that really is hidden: a bar left on screen (a hide that didn't take) keeps a
-- selection that can be picked, never a visible bar that Edit Mode can't move
local function HideMoverOfFrame(frame)
    if not (frame and frame.Selection) then return end
    if frame:IsVisible() then
        RestoreMoverOfFrame(frame)
        return
    end
    if not frame.Selection.FlareUI_HiddenMover then
        frame.Selection.FlareUI_HiddenMover = true
        frame.FlareUI_MouseWas = frame:IsMouseEnabled()
    end
    frame.Selection:SetAlpha(0)
    if frame.Selection.Label then frame.Selection.Label:SetAlpha(0) end
    frame:EnableMouse(false)
    frame.Selection:EnableMouse(false)
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
        -- only while FlareUI still hides it: not after Action Bars went off without a reload
        if db and db[editHideHooked[f]] and f.FlareUI_Hidden and ActionBarsOn() and editing and not InCombatLockdown() then ns.RawHide(f) end
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
Fader.groupOf = {}         -- element key -> its group's name in Fader.groups (ElementShown)
Fader.delays = {}
Fader.groupDelay = {}      -- group -> its Fade Delay in seconds (AddMember: the longest member's)
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

-- In a Capital City: the six capitals' maps (the uiMapIDs Forever's addons use: Stormwind 1453 to
-- Undercity 1458). The map can't be asked in some places: then not in a city.
Visibility.CAPITALS = { [1453] = true, [1454] = true, [1455] = true, [1456] = true, [1457] = true, [1458] = true }
function Visibility.InCapital()
    local ok, map = pcall(C_Map.GetBestMapForUnit, "player")
    return ok and map ~= nil and Visibility.CAPITALS[map] == true or false
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
-- conditions: nothing shows under the pointer unless it is ticked. Nothing ticked is Always.
local Conditions = ns.Conditions
local SHOW_SPEC = { exclusive = { "always", "never" }, tokens = Conditions.MOUSE_TOKENS, legacy = Conditions.BAR_LEGACY, empty = "always" }
-- the player and pet frames also show while their unit is missing health (section 6b)
local HEALTH_TOKENS = { unpack(Conditions.MOUSE_TOKENS) }
HEALTH_TOKENS[#HEALTH_TOKENS + 1] = "health"
local HEALTH_SPEC = { exclusive = SHOW_SPEC.exclusive, tokens = HEALTH_TOKENS, legacy = SHOW_SPEC.legacy, empty = "always" }
-- and the player frame while you're missing mana (ticked with Missing Health: either bar under full)
local MANA_TOKENS = { unpack(HEALTH_TOKENS) }
MANA_TOKENS[#MANA_TOKENS + 1] = "mana"
-- Missing Health and Missing Mana can't be ticked together: Forever hides both values from
-- addons, and two hidden values can't be combined into "either is missing" (/fui fadedebug showed both
-- hidden out of combat, so the frame stayed shown). Ticking one unticks the other.
local MANA_SPEC = { exclusive = SHOW_SPEC.exclusive, tokens = MANA_TOKENS, legacy = SHOW_SPEC.legacy, empty = "always",
                    rivals = { health = "mana", mana = "health" } }
-- a swing bar's Only When In Use clears the rest, as Always does
local INUSE_SPEC = { exclusive = { "always", "inuse", "never" }, tokens = Conditions.MOUSE_TOKENS, legacy = SHOW_SPEC.legacy, empty = "always" }
-- the gryphons: as every frame (Same as Action Bar 1 removed 11-20)
local CAP_SPEC = { exclusive = { "always", "never" }, tokens = Conditions.MOUSE_TOKENS, legacy = SHOW_SPEC.legacy, empty = "always" }
-- Never (the totems) clears the rest too: out for good, outside Edit Mode
local NEVER_SPEC = { exclusive = { "always", "never" }, tokens = Conditions.MOUSE_TOKENS, legacy = SHOW_SPEC.legacy, empty = "always" }
-- the chat's New Messages (right under Mouseover); the meter's Never and In an Instance; the threat
-- window's Same as Meter and In an Instance. Kept in table fields: the main chunk is near its limit.
Visibility.CHAT_SPEC = { exclusive = { "always", "never" }, tokens = { "mouseover", "messages", "chatonly", "combat", "hastarget", "attackable", "ingroup", "instance", "unmounted", "city", "notcity" },
                         legacy = SHOW_SPEC.legacy, empty = "always" }
Visibility.METER_SPEC = { exclusive = { "always", "never" }, tokens = Conditions.MOUSE_TOKENS,
                          legacy = SHOW_SPEC.legacy, empty = "always" }
Visibility.THREAT_SPEC = { exclusive = { "meter", "always", "never" }, tokens = Visibility.METER_SPEC.tokens, legacy = SHOW_SPEC.legacy, empty = "always" }
local function SpecOf(key)
    local e = ELEMENT_BY_KEY[key]
    if e and e.chat then return Visibility.CHAT_SPEC end
    if e and e.external then return Visibility.METER_SPEC end
    if e and e.threat then return Visibility.THREAT_SPEC end
    if e and e.cap then return CAP_SPEC end
    if e and e.mana then return MANA_SPEC end
    if e and e.health then return HEALTH_SPEC end
    if e and e.inuse then return INUSE_SPEC end
    if e and e.never then return NEVER_SPEC end
    return SHOW_SPEC
end
Visibility.SpecOf = SpecOf

-- also the resource bars' and Fake CM's rule (ns.Visibility.ShowRule)
local function EvaluateShowRule(show)
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
    if set.city and Visibility.InCapital() then return true end
    -- Not in a Capital City (11-20, Discord): the reverse, for a frame that should fade in capitals
    if set.notcity and not Visibility.InCapital() then return true end
    -- the meter's and the threat window's: dungeons, raids, battlegrounds and arenas
    if set.instance and IsInInstance() then return true end
    return false
end
local function ShowRule(show, cache)
    if not cache or type(show) ~= "string" then return EvaluateShowRule(show) end
    local result = cache[show]
    if result == nil then result = EvaluateShowRule(show); cache[show] = result end
    return result
end
Visibility.ShowRule = ShowRule

-- the spellbook tab of the spells window, open: spells are dragged from it onto the bars
local function SpellbookOpen()
    local book = _G.PlayerSpellsFrame and _G.PlayerSpellsFrame.SpellBookFrame
    return book and book:IsVisible() or false
end

-- editMode, spellbook: read once per pass by the caller, not once per member
local function CheckMember(data, editMode, spellbook, ruleCache)
    if editMode then return true end
    -- the chat decides with its own reasons (typing, New Messages, its Fade Delay): Chat.lua FadeHold
    if data.hold then return data.hold(ShowRule(data.show, ruleCache), data.mouseOK) end
    local fcmState = ns.ActionBars and ns.ActionBars.fcm
    -- every action bar shows while something is dragged onto them, or the spellbook is open
    if data.isBar and ((fcmState and fcmState.wasDragging) or spellbook) then return true end
    if data.fcm then
        return (fcmState and fcmState.unlockMode) or ShowRule(data.show, ruleCache) or (data.mouseOK and data.frame:IsMouseOver()) or false
    end
    if ShowRule(data.show, ruleCache) then return true end
    -- shown while its own settings page is open
    if data.owner and data.owner.IsSettingsPreview and data.owner:IsSettingsPreview() then return true end
    -- the totem bar's flyout (a totem's list) stands above the bar: shown while it's open
    if data.key == "totem" and _G.MultiCastFlyoutFrame and _G.MultiCastFlyoutFrame:IsShown() then return true end
    -- the pointer counts only with Mouseover ticked
    if not data.mouseOK then return false end
    if data.key == "quest" and ns.ObjectiveTracker.IsMouseOverExtras and ns.ObjectiveTracker:IsMouseOverExtras() then return true end
    -- a unit frame's holder has no size: its frame (and a ring style's portrait) is what's pointed at
    if data.mouse then return data.mouse() end
    -- a hidden frame still has its place: a bar turned off in Edit Mode (or a pet bar with no pet)
    -- mustn't bring its group back when the pointer crosses where it would be
    if not data.frame:IsVisible() then return false end
    if data.frame:IsMouseOver() or (data.isBar and FlyoutOver(data.frame)) then return true end
    -- buttons another addon moved out of the bar can sit away from the bar's own frame
    if data.frame.FlareUI_FadeAlpha then
        for _, button in ipairs(data.frame.actionButtons) do
            if button:IsVisible() and button:IsMouseOver() then return true end
        end
    end
    return false
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
Fader.ruleCache = {}        -- public condition results, valid for one check pass only
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
        wipe(self.ruleCache)
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
                if CheckMember(data, editMode, spellbook, self.ruleCache) then groupShouldShow = true break end
            end

            if not self.delays[groupName] then self.delays[groupName] = 0 end
            -- (plus the group's Fade Delay: the longest of its members')
            if groupShouldShow then self.delays[groupName] = FADE_DELAY + (self.groupDelay[groupName] or 0)
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
                if data.external then
                    -- the meter fades itself: told only when its group's answer changes
                    if data.told ~= effectiveShow then
                        data.told = effectiveShow
                        data.notify()
                    end
                else
                    -- (a member with its own apply keeps its value: its alpha can be secret)
                    -- (a bar whose buttons another addon took keeps its fade in FlareUI_FadeAlpha, see ButtonsTaken)
                    local currentAlpha = data.apply and data.value or frame.FlareUI_FadeAlpha or frame:GetAlpha()
                    if math_abs(currentAlpha - targetAlpha) > 0.005 then
                        groupFading = true
                        -- coming back at Show Speed, fading away at Hide Speed
                        local rising = currentAlpha < targetAlpha
                        local fadeTime = rising and data.fadeIn or data.fadeOut
                        local newAlpha
                        if rising then
                            data.stageHold = nil
                            local change = fadeTime > 0 and elapsed / fadeTime or 1
                            newAlpha = math_min(targetAlpha, currentAlpha + change)
                        elseif data.fadeStaged then
                            -- Slower: down to the resting opacity, rest, then finish (Core.lua)
                            newAlpha = ns.StagedFall(data, currentAlpha, targetAlpha, elapsed)
                        else
                            local change = fadeTime > 0 and elapsed / fadeTime or 1
                            newAlpha = math_max(targetAlpha, currentAlpha - change)
                        end
                        if data.apply then data.apply(newAlpha) else ApplyElementAlpha(frame, data.key, newAlpha) end
                    else
                        -- at its alpha: the next Slower fade starts its stages afresh
                        data.stageHold = nil
                        if data.apply and repair then data.apply(currentAlpha) end
                    end
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
local SHOW_VALUES = { "always", "mouseover", "combat", "hastarget", "attackable", "ingroup", "instance", "unmounted", "city", "notcity" }
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

-- what the Show dropdown ticks, and a click in it (no condition left ticked is Always)
local function ShowSelection(key) return Conditions.Selection(Visibility:GetShow(key), SpecOf(key)) end
local function ToggleShow(key, value)
    -- Never can't lead a fade group: the other members would be out for good too
    if value == "never" and Visibility:GetGroup(key) > 0 then return end
    Visibility:SetShow(key, Conditions.Toggle(Visibility:GetShow(key), value, SpecOf(key)))
end

local function Label(copyKey, fallback)
    return ns.Settings and ns.Settings:Text(copyKey, "label") or fallback
end

local SPEED_VALUES = { { text = L["Instant"], value = "instant", isRadio = true },
                       { text = L["Fast"], value = "fast", isRadio = true },
                       { text = L["Slow"], value = "slow", isRadio = true } }
-- Hide Speed also has Slower: fades to about half, rests, then finishes (ns.FADE_STAGES)
local HIDE_SPEED_VALUES = { SPEED_VALUES[1], SPEED_VALUES[2], SPEED_VALUES[3],
                            { text = L["Slower"], value = "slower", isRadio = true } }

local function BuildElementSettings(key)
    -- nothing fades while it's always shown (or a swing bar shows and hides itself)
    -- (the meter's Never still fades it to its Faded Opacity)
    local external = ELEMENT_BY_KEY[key] and ELEMENT_BY_KEY[key].external
    local function AlwaysShown()
        local show = Visibility:GetShow(key)
        return show == "always" or show == "inuse" or show == "bar1" or show == "meter" or (show == "never" and not external)
    end
    local rows = {
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
                -- a line above the pair that can't be ticked together (the player frame)
                if e and e.health and e.mana then values[#values + 1] = { isDivider = true } end
                if e and e.health then values[#values + 1] = { text = L["Missing Health"], value = "health", isRadio = true } end
                if e and e.mana then values[#values + 1] = { text = L["Missing Mana"], value = "mana", isRadio = true } end
                if e and e.threat then table_insert(values, 1, { text = L["Same as Meter"], value = "meter", isRadio = true }) end
                -- Never on every Visibility (Malkkav 11-19: hide whatever you like), first (11-20: Off first); Edit Mode still shows it
                if e then table_insert(values, 1, { text = L["Never"], value = "never", isRadio = true }) end
                -- the chat's New Messages, right under Mouseover
                if e and e.messages then
                    for i, v in ipairs(values) do
                        if v.value == "mouseover" then
                            table_insert(values, i + 1, { text = L["New Messages"], value = "messages", isRadio = true })
                            -- (11-20, Discord) only lines people write: loot, skill-ups, XP and system lines don't wake it
                            table_insert(values, i + 2, { text = L["Only Chat Messages"], value = "chatonly", isRadio = true })
                            break
                        end
                    end
                end
                if e and e.inuse then
                    -- with the two that clear the rest, above the line
                    for i, v in ipairs(values) do
                        if v.isDivider then table_insert(values, i, { text = L["Only When in Use"], value = "inuse", isRadio = true }) break end
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
                or (ELEMENT_BY_KEY[key] and ELEMENT_BY_KEY[key].chat
                and L["Typing always shows the chat.\nNew Messages: a new line, or closing a quest or vendor window, brings it back.\nOnly Chat Messages: only lines people write. Loot, skill-ups and XP stay quiet."])
                or (external and L["Never: it shows only in Edit Mode, or at its Faded Opacity."])
                or (ELEMENT_BY_KEY[key] and ELEMENT_BY_KEY[key].threat
                and L["Same as Meter: it shows and fades with the Damage Meter."])
                or nil,
        },
        -- Show Speed and Hide Speed
        {
            name = L["Show Speed"], kind = LEM.SettingType.Dropdown, default = "instant", values = SPEED_VALUES,
            get = function() return Visibility:GetFadeIn(key) end,
            set = function(_, value) Visibility:SetElementFade(key, "fadeIn", value) end,
            hidden = AlwaysShown,
            desc = L["How fast it comes back.\n* Fast: 0.2 seconds\n* Slow: 0.4 seconds"],
        },
        {
            name = L["Hide Speed"], kind = LEM.SettingType.Dropdown, default = "instant", values = HIDE_SPEED_VALUES,
            get = function() return Visibility:GetFadeOut(key) end,
            set = function(_, value) Visibility:SetElementFade(key, "fadeOut", value) end,
            hidden = AlwaysShown,
            desc = L["How fast it fades away.\n* Fast: 0.2 seconds\n* Slow: 0.4 seconds\n* Slower: fades to about half over 2 seconds, then 2 seconds later fades out"],
        },
        {
            name = L["Faded Opacity"], kind = LEM.SettingType.Slider, default = 0, minValue = 0, maxValue = 100, valueStep = 5,
            formatter = function(value) return value end,   -- plain: "100%" clips the value box
            get = function() return Visibility:GetMinAlpha(key) end,
            set = function(_, value) Visibility:SetElementFade(key, "minAlpha", value) end,
            hidden = AlwaysShown,
            desc = L["How see-through it gets when faded. 0% is invisible."],
        },
    }
    -- Fade Delay (the chat and the meter): how long it stays before it fades
    local e = ELEMENT_BY_KEY[key]
    if e and e.delay then
        rows[#rows + 1] = {
            name = L["Fade Delay"], kind = LEM.SettingType.Slider, default = e.delay, minValue = 0, maxValue = 60, valueStep = 1,   -- up to 1 minute (11-20); longer = Always
            -- seconds, short (a word clips the dialog's edge)
            formatter = function(value) return value .. "s" end,   -- 0s, not Off: at 0 it still fades (terminology.md)
            get = function() return Visibility:GetFadeDelay(key) end,
            set = function(_, value) Visibility:SetFadeDelay(key, value) end,
            hidden = AlwaysShown,
            desc = L["How long it stays after it was last needed, in seconds, before it fades."],
        }
    end
    -- Fade Old Lines (the chat, 11-20, Discord): each line fades on its own, oldest first (Chat.lua
    -- ApplyLineFade). Off by default; shown with any Visibility, as it works with Always too.
    if e and e.chat then
        rows[#rows + 1] = {
            name = L["Fade Old Lines"], kind = LEM.SettingType.Checkbox, default = false,
            get = function() local c = ns.db and ns.db.profile.chat return c and c.fadeLines or false end,
            set = function(_, value)
                local c = ns.db and ns.db.profile.chat
                if not c then return end
                c.fadeLines = value and true or nil
                if ns.Chat and ns.Chat.ApplyLineFade then ns.Chat.ApplyLineFade() end
            end,
            desc = L["Lines fade one by one, oldest first, Fade Delay seconds after they arrive. Pointing at the chat or typing brings them back."],
        }
        -- Keep Messages Shown (11-23, Malkkav / Kalahan6; off): only the frame fades (Chat.lua KeepMessages)
        rows[#rows + 1] = {
            name = L["Keep Messages Shown"], kind = LEM.SettingType.Checkbox, default = false,
            get = function() local c = ns.db and ns.db.profile.chat return c and c.keepMessages or false end,
            set = function(_, value)
                local c = ns.db and ns.db.profile.chat
                if not c then return end
                c.keepMessages = value and true or nil
                if ns.Chat and ns.Chat.ApplyLineFade then ns.Chat.ApplyLineFade() end
            end,
            desc = L["The chat's frame, tabs and buttons fade as set, but the messages stay. Works with any Visibility."],
        }
    end
    return rows
end

-- for the unit frames' Fading section (UnitFrames.lua BuildSettings): no title, Faded Opacity on the
-- player and pet only. A fade group on the player and pet only; every unit frame has its own
-- Show Speed and Hide Speed, the group's while in one.
-- Link Pet Frame (the player frame's Fading): the pet frame fades with the
-- player frame, on the player's settings; pointing at either shows both. The pet's own Fading hides.
function Visibility:PetLinked()
    local db = GetDb()
    return db and db.petFollowsPlayer == true or false
end

function Visibility:UnitFrameSettings(unit)
    local key = "uf_" .. unit
    local rows = BuildElementSettings(key)
    local e = ELEMENT_BY_KEY[key]
    -- rows: 1 Fade Group, 2 Visibility, 3 Show Speed, 4 Hide Speed, 5 Faded Opacity
    -- the two speeds on every unit frame, in a fade group or not
    local kept = {}
    if not (e and e.noGroup) then kept[#kept + 1] = rows[1] end
    kept[#kept + 1] = rows[2]
    kept[#kept + 1] = rows[3]
    kept[#kept + 1] = rows[4]
    if not (e and e.noOpacity) then kept[#kept + 1] = rows[5] end
    -- 6 Fade Delay: the player and pet frames only (e.delay)
    if e and e.delay then kept[#kept + 1] = rows[6] end
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

-- for the player cast bar's Fading section (UnitFrames.lua BuildPlayerCastSettings): Visibility, the speeds and
-- Faded Opacity, hidden with Cinematic (it fades the bar itself)
function Visibility:PlayerCastSettings()
    local rows = BuildElementSettings("uf_playercastbar")
    local kept = { rows[2], rows[3], rows[4], rows[5] }   -- Visibility, Show Speed, Hide Speed, Faded Opacity (speeds 11-20)
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
    -- with its fade group and Faded Opacity: the blips go while it's faded (SetMinimapDrawn)
    local rows = BuildElementSettings("minimap")
    -- a Fading section that opens and closes like the other dialogs' (starts closed)
    return ns.EditSection("Fading", rows)
end

-- The Blizzard systems these settings go into, for the settings search (Settings/Registry.lua): page
-- picks the settings page's ("ab", the default: the bars; "ch" the chat, "dm" the meter)
function Visibility:EditSystems(page)
    local list = {}
    if not Enum.EditModeSystem then return list end
    page = page or "ab"
    for _, e in ipairs(ELEMENTS) do
        local system = e.system and (e.page or "ab") == page and Enum.EditModeSystem[e.system]
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

-- the meter in the chat's Meter tab (Settings > Meters): it fades with the chat, so its Fading says so
-- and keeps only the two speeds, which still fade it in and out as the tabs switch
local function MeterInChat()
    local dm = ns.DamageMeter
    return dm ~= nil and dm.ChatTabAvailable ~= nil and dm:ChatTabAvailable()
end
local function MeterRowsInChat(rows)
    for _, row in ipairs(rows) do
        local own, speed = row.hidden, row.name == L["Show Speed"] or row.name == L["Hide Speed"]
        row.hidden = function(...)
            if MeterInChat() then return not speed end
            if type(own) == "function" then return own(...) end
            return own and true or false
        end
    end
    table_insert(rows, 1, {
        name = "|cffff9933" .. L["The meter is in the chat's Meter tab: it fades with the chat."] .. "|r",
        kind = LEM.SettingType.Expander, static = true, hideArrow = true,
        get = function() return true end, set = function() end,
        hidden = function() return not MeterInChat() end,
    })
    return rows
end

-- added once each, as its module and frame exist (Blizzard's systems at once, FlareUI's frames on
-- entering Edit Mode)
local frameAdded = {}
local function AddEditModeSettings()
    for _, e in ipairs(Enum.EditModeSystem and ELEMENTS or {}) do
        local system = e.system and not frameAdded[e.key] and ElementOn(e) and Enum.EditModeSystem[e.system]
        if system then
            local indices = Enum[e.indices or "EditModeActionBarSystemIndices"]
            local index = e.index and indices and indices[e.index]
            if not e.index or index then
                frameAdded[e.key] = true
                local rows = BuildElementSettings(e.key)
                -- Blizzard's own Bar Visible, higher up in the same dialog, hides the bar for good
                -- whatever Show says: a line says so while it's set to anything but Always
                if e.system == "ActionBar" then
                    local key = e.key
                    -- a Fake CM bar follows the Fake CM page's Visibility: its own Fading rows hide
                    for _, row in ipairs(rows) do
                        local own = row.hidden
                        row.hidden = function(...)
                            local fcm = ns.db and ns.db.profile and ns.db.profile.fcm
                            if fcm and fcm.bars and fcm.bars[key] and fcm.bars[key].enabled then return true end
                            if type(own) == "function" then return own(...) end
                            return own and true or false
                        end
                    end
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
                if e.external then rows = MeterRowsInChat(rows) end
                -- a Fading section that opens and closes, starting closed, like every other
                -- the Cooldown Manager's viewers: Growth in Frame and Icon Shape in Look, as Buffs & Debuffs
                -- and Buff Reminders have them, then Fading
                local CM = ns.CooldownManager
                local frameRows, lookRows = {}, {}
                if e.cdmGrow and CM and CM.GrowSetting then frameRows[1] = CM.GrowSetting(e.cdmGrow) end
                if e.cdmShape and CM and CM.ShapeSetting then lookRows[1] = CM.ShapeSetting(e.cdmShape) end
                if #frameRows + #lookRows > 0 then
                    local Section, settings = ns.EditSections()
                    Section("Frame", frameRows)
                    Section("Look", lookRows)
                    Section("Fading", rows)
                    rows = settings
                else
                    rows = ns.EditSection("Fading", rows)
                end
                -- the totem bar: Blizzard gives it no Size, FlareUI does (above Fading)
                if e.key == "totem" and ns.ActionBars and ns.ActionBars.TotemSizeSetting then
                    table_insert(rows, 1, ns.ActionBars.TotemSizeSetting())
                end
                -- the gryphons: a Size each (Blizzard gives them none)
                if e.cap and ns.ActionBars and ns.ActionBars.CapSizeSetting then
                    table_insert(rows, 1, ns.ActionBars.CapSizeSetting(e.key))
                end
                -- the bag buttons: sizes below Blizzard's 75%
                if e.key == "bags" and ns.ActionBars and ns.ActionBars.BagBarSizeSetting then
                    table_insert(rows, 1, ns.ActionBars.BagBarSizeSetting())
                end
                LEM:AddSystemSettings(system, rows, index)
            end
        end
    end
    -- FlareUI's own frames (XP bar, buffs, debuffs, quest tracker, totems, the separate threat window):
    -- their rows go after their own
    for _, key in ipairs({ "xp", "buffs", "debuffs", "quest", "uf_totems", "threat" }) do
        local frame = not frameAdded[key] and ElementOn(ELEMENT_BY_KEY[key]) and GetFrame(key)
        local settings = frame and LEM.GetFrameSettings and LEM:GetFrameSettings(frame)
        if settings then
            frameAdded[key] = true
            -- a Fading section after the frame's own, one of the dialog's sections (one open at a time)
            for _, setting in ipairs(ns.EditSection("Fading", BuildElementSettings(key))) do
                settings[#settings + 1] = setting
            end
        end
    end
end
Visibility.AddEditModeSettings = AddEditModeSettings

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
-- the health percent into the alpha: 1 below full, the fader's value at full. Health changes apply it
-- again.
--------------------------------------------------
local unitValues, healthCurves = {}, {}   -- key -> the fader's last value; key -> its curve
local healthMembers = {}                  -- members applied through the curve, rebuilt by Refresh

-- Missing Mana (the player frame) the same way, through UnitPowerPercent: mana can be secret
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
    -- rebuilt only when the alpha changes, not on every health tick
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
    Fader.groupOf[data.key] = groupName
    if data.delay and data.delay > (Fader.groupDelay[groupName] or 0) then Fader.groupDelay[groupName] = data.delay end
end

-- Whether the element is wanted now: its Visibility, or its fade group's (any member's reason, and the
-- group's short wait). For the meter, which fades itself (DamageMeter.lua ApplyVisibility). Edit Mode
-- shows everything.
function Visibility:ElementShown(key)
    local show = self:GetShow(key)
    if show == "always" or show == "meter" then return true end
    if show == "never" then return false end
    local groupName = Fader.groupOf[key]
    local members = groupName and Fader.groups[groupName]
    if not members then return ShowRule(show) end
    if Fader.shows[groupName] then return true end
    local editMode = (_G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown()) or false
    local spellbook = SpellbookOpen()
    for _, data in ipairs(members) do
        if CheckMember(data, editMode, spellbook) then return true end
    end
    return false
end

-- the meter's (DamageMeter.lua), a frame later: Refresh can run inside its own checks
local function TellMeter()
    C_Timer.After(0, function()
        if ns.DamageMeter and ns.DamageMeter.ApplyVisibility then ns.DamageMeter:ApplyVisibility() end
    end)
end

function Visibility:Refresh()
    -- (a Reset Settings in Edit Mode runs this once, after its last setting: LEM:Defer)
    if LEM:Defer(Visibility.Refresh, Visibility) then return end
    -- In a fight only the fader is rebuilt (alpha, allowed on protected frames), so a Show or fade
    -- change counts at once; hiding for good waits, and the whole pass runs again when the fight
    -- ends (OnVisibilityStateChange)
    local inCombat = InCombatLockdown()
    self.refreshPending = inCombat or nil
    local db = GetDb()
    if not db then return end
    -- A frame hidden for good stays hidden in Edit Mode, its selection made invisible; lifting the hide
    -- would lose whether the frame comes back when the option goes off.
    -- Whatever is not hidden, or everything with Action Bars off (or every element off), comes back at
    -- once, in Edit Mode or not: its parent, its selection and its mouse (a bar left showing must stay
    -- pickable in Edit Mode). Both steps only undo what FlareUI did this session, so nothing of
    -- Blizzard's is forced. Runs before the ShouldLoad return below.
    local inEditMode = _G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown()
    local barsOn = ActionBarsOn() and self:ShouldLoad()
    for _, pair in ipairs(not inCombat and HIDE_KEYS or {}) do
        local key, settingKey = pair[1], pair[2]
        local hidden = barsOn and db[settingKey]
        if hidden then
            ApplySecureHide(key, true)
            if inEditMode then
                ForEachFrameOfKey(key, KeepHiddenInEditMode, settingKey)
                ForEachFrameOfKey(key, HideFrame)
                HideEditModeMover(key)
            end
        else
            ApplySecureHide(key, false)
            RestoreEditModeMover(key)
        end
    end

    if not self:ShouldLoad() then
        Fader:SetScript("OnUpdate", nil)
        Fader.updateEnabled = false
        return
    end
    if barsOn and not inCombat then
        SetMicroFlashesBlank(db.hideMicroMenu)
        UpdateMicroTips()
    end

    Fader.groups = {}
    Fader.groupOf = {}
    Fader.delays = {}
    Fader.groupDelay = {}
    wipe(Visibility.neverFrames)   -- filled again below, for each frame on Never
    Fader.dirty = {}
    Fader.shows = {}
    Fader.counting = {}
    Fader.settled = {}
    Fader.watchesMouseover = false
    Fader.fading = false
    healthMembers = {}
    local watchMana = false

    local fcm = ns.db.profile.fcm
    Visibility.MigrateCapsBar1(db)
    for _, e in ipairs(ELEMENTS) do
        local key = e.key
        local frame = GetFrame(key)
        -- the threat window: under the meter on Same as Meter, on its own otherwise (DamageMeter.lua 16b)
        if e.threat and ElementOn(e) and ns.DamageMeter and ns.DamageMeter.AttachThreatWindow then
            ns.DamageMeter.AttachThreatWindow(self:GetShow(key) == "meter")
        end
        -- the gryphons are children of bar 1 (MainActionBar.EndCaps) and took its alpha on every choice
        -- (Kelvan 11-20): they ignore it and fade on their own choice
        if e.cap and frame and frame.SetIgnoreParentAlpha and not frame:IsForbidden() then
            pcall(frame.SetIgnoreParentAlpha, frame, ElementOn(e) and true or false)
        end
        if e.threat and self:GetShow(key) == "meter" then
            -- a child of the meter: the meter's own fade is its fade
            if frame then frame:SetAlpha(1) end
        elseif e.external then
            -- the meter fades itself: the fader only tells it when its answer changes (ElementShown)
            local show = self:GetShow(key)
            if ElementOn(e) and show ~= "always" and show ~= "never" then
                local group = self:GetGroup(key)
                -- on its own, its own driver shows it under the pointer (Mouseover); in a group,
                -- pointing at it brings the whole group back too
                AddMember(group > 0 and ("group" .. group) or key, {
                    key = key, frame = frame, external = true, show = show, fadeIn = 0, fadeOut = 0, minAlpha = 0,
                    mouseOK = group > 0 and Conditions.Has(show, "mouseover", SpecOf(key)) or false,
                    mouse = function() local dm = ns.DamageMeter; return dm and dm.FadeMouse and dm.FadeMouse() or false end,
                    notify = TellMeter })
                Fader.watchesMouseover = true
            end
            if ElementOn(e) then TellMeter() end
        elseif ElementOn(e) and frame and frame.GetAlpha then
            local isBar = key:match("^bar[1-8]$") ~= nil
            local fcmBar = isBar and fcm and fcm.bars and fcm.bars[key]
            if fcmBar and fcmBar.enabled then
                -- Fake CM bars: their own rule, one group; the pointer only with Mouseover ticked
                local fcmShow = fcm.show or "combat"
                local mouseOK = Conditions.Has(fcmShow, "mouseover", SHOW_SPEC)
                AddMember("fcm", { key = key, frame = frame, isBar = true, fcm = true, show = fcmShow, mouseOK = mouseOK,
                                   fadeIn = ns.FadeTime(self:GetFadeIn(key)), fadeOut = ns.FadeTime(self:GetFadeOut(key)),
                                   fadeStaged = self:GetFadeOut(key) == "slower",
                                   minAlpha = 0 })
                if mouseOK then Fader.watchesMouseover = true end
            else
                local show = self:GetShow(key)
                -- Link Pet Frame: the pet takes the player frame's choices and fades in its group
                local linkPet = key == "uf_pet" and self:PetLinked() and ElementOn(ELEMENT_BY_KEY.uf_player)
                local settingsKey = linkPet and "uf_player" or key
                if linkPet then show = self:GetShow("uf_player") end
                -- a unit frame on Never takes no clicks either (out of a fight: its button is secure)
                local button = e.unit and ns.UnitFrames and ns.UnitFrames.GetUnitButton and ns.UnitFrames:GetUnitButton(e.unit)
                if button and button.EnableMouse and not InCombatLockdown() then
                    local editingNow = _G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown()
                    pcall(button.EnableMouse, button, show ~= "never" or editingNow or false)
                end
                -- the quest tracker on Never is hidden, not only faded: its lines would still show tooltips
                if key == "quest" and ns.ObjectiveTracker and ns.ObjectiveTracker.SetNever then
                    ns.ObjectiveTracker:SetNever(show == "never")
                end
                -- a frame on Never shows no tooltips (Visibility.HideNeverTooltip)
                Visibility.neverFrames[frame] = show == "never" or nil
                if show == "never" then Visibility.WatchNeverTooltips() end
                if show == "never" then
                    -- out for good; Edit Mode still shows it, to be found and set back
                    local editing = _G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown()
                    ApplyElementAlpha(frame, key, editing and 1 or 0)
                    if e.keepAlpha then e.faded = true end
                    if e.own then unitValues[key] = editing and 1 or 0 end
                elseif show == "always" or show == "inuse" then
                    if not e.keepAlpha then
                        ApplyElementAlpha(frame, key, 1)
                    elseif e.faded then
                        -- Blizzard's own Opacity back: it applies it only when that setting changes
                        e.faded = nil
                        local setting = Enum.EditModeCooldownViewerSetting
                        local ok, opacity = pcall(frame.GetSettingValue, frame, setting and setting.Opacity)
                        ApplyElementAlpha(frame, key, ok and type(opacity) == "number" and opacity > 0 and opacity / 100 or 1)
                    end
                    if e.own then unitValues[key] = 1 end
                else
                    local group = self:GetGroup(key)
                    local owner = (key == "quest" and ns.ObjectiveTracker) or ((key == "buffs" or key == "debuffs") and ns.Auras)
                        or (key == "threat" and ns.DamageMeter) or nil
                    local unit = e.unit
                    local mouse = unit and function() return ns.UnitFrames:IsMouseOverUnit(unit) end or nil
                    if e.noGroup then group = 0 end
                    -- a linked pet fades in the player frame's group, if it has one
                    if linkPet then group = self:GetGroup("uf_player") end
                    -- a unit frame fades at its own speeds on its own (Instant until picked), at its
                    -- group's speeds in one
                    local data = { key = key, frame = frame, isBar = isBar, show = show, owner = owner, mouse = mouse,
                                   fadeIn = ns.FadeTime(self:GetFadeIn(settingsKey)),
                                   fadeOut = ns.FadeTime(self:GetFadeOut(settingsKey)),
                                   fadeStaged = self:GetFadeOut(settingsKey) == "slower",
                                   minAlpha = e.noOpacity and 0 or self:GetMinAlpha(settingsKey) / 100,
                                   -- Fade Delay (the chat waits itself, in its hold)
                                   delay = e.delay and not e.chat and self:GetFadeDelay(settingsKey) or nil }
                    -- the pointer shows it only with Mouseover ticked
                    data.mouseOK = Conditions.Has(show, "mouseover", SpecOf(settingsKey))
                    if e.chat then
                        -- every chat window at one alpha (Chat.lua FadeApply); the chat's own reasons,
                        -- the pointer among them, in its hold (Chat.lua FadeHold)
                        data.value = ns.Chat.fadeAlpha or 1
                        data.apply = function(alpha) data.value = alpha; ApplyElementAlpha(frame, key, alpha) end
                        data.hold = ns.Chat.FadeHold
                    end
                    if e.own then
                        -- (a linked pet: the player's Missing Health / Mana show the pair; the pet's own health doesn't)
                        local health = not linkPet and e.health and Conditions.Has(show, "health", SpecOf(key)) or false
                        local mana = not linkPet and e.mana and Conditions.Has(show, "mana", SpecOf(key)) or false
                        -- both ticked (an older profile; they are exclusive): Missing Mana stays
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
                    -- a fade group's members share one entry: pointing at any of them (a unit frame
                    -- through its mouse check) brings the whole group back
                    if e.keepAlpha then e.faded = true end
                    AddMember(group > 0 and ("group" .. group) or (linkPet and "uf_player") or key, data)
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
    -- In a Capital City: entering or leaving one
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnVisibilityStateChange")
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
-- A condition changed (a drag began or ended, a chat line arrived): every fade group is checked
-- again, without the full rebuild of Refresh. One check on the spot per frame: further wakes in the
-- same frame (a burst of chat lines) only mark the groups for the next frame's check.
function Visibility:Wake()
    local now = GetTime()
    if self.wokeAt ~= now then
        self.wokeAt = now
        MarkAllDirty()
        return
    end
    for groupName in pairs(Fader.groups) do Fader.dirty[groupName] = true end
    if next(Fader.dirty) and not Fader.updateEnabled then
        Fader:SetScript("OnUpdate", Fader.UpdateScript)
        Fader.updateEnabled = true
        Fader.updateTimer = 0
    end
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
