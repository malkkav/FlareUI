local _, ns = ...

--------------------------------------------------
-- PROC GLOW
-- Blizzard's proc glow on the action bars for game-flagged procs (matched by spell name, so every
-- rank lights) and for reaction abilities (Overpower, Execute...) while usable and off cooldown.
-- Glows are FlareUI frames from ActionButtonSpellAlertTemplate; Blizzard's alert manager is never
-- touched, so the buttons stay untainted.
--------------------------------------------------

--------------------------------------------------
-- 1. MODULE AND DATA
--------------------------------------------------
local PG = {}
ns.ProcGlow = PG

-- one rank's spell ID each; the name covers every rank. By class: names can match other classes' spells
-- in some languages (French Revenge is "Vengeance", also a paladin talent)
local REACTIVE_IDS = {
    WARRIOR = {
        7384,   -- Overpower
        6572,   -- Revenge
        5308,   -- Execute
        402927, -- Victory Rush
    },
    ROGUE = { 14251 },              -- Riposte
    HUNTER = { 19306, 1495 },       -- Counterattack, Mongoose Bite
    PALADIN = { 24275 },            -- Hammer of Wrath
}
-- the classes above with one that lights by the target's health (Execute, Hammer of Wrath): only they
-- listen to the target's health, the others' windows come with the usable events
local TARGET_HEALTH_CLASSES = { WARRIOR = true, PALADIN = true }

-- Revenge: no cooldown, and its cast doesn't close its window, so the game goes on calling it usable.
-- After a cast it stays dark until the window closes or you avoid another attack.
local ONE_USE_ID = 6572
local ONE_USE_SECONDS = 5
local AVOIDED = { BLOCK = true, DODGE = true, PARRY = true }

-- Buff procs: a buff on you that empowers other spells (Fingers of Frost -> Ice Lance). The game doesn't
-- flag those spells for the bars, and hides your buffs from addons in combat, so a buff proc is followed
-- three ways (BP below): the game's own proc alert (SPELL_ACTIVATION_OVERLAY_SHOW names the buff), your
-- buffs while they can be read (out of combat), and Blizzard's Cooldown Manager icons, which stay live in
-- combat when you track the buff there yourself (read only: FlareUI never changes its setup).
-- Forever's buff IDs come from ProcDoc by wsmaxcy (credited in LICENSES); `name` is the English name, used
-- when an ID is unknown or doesn't resolve. glows: { spellID, English name } of the spells it lights.
-- The rune procs' IDs were read from the client. Forever has one Eclipse, from Wrath, empowering
-- Starfire (no Solar half). Searing Light's free Holy Nova buff has another name, still unknown: by name only.
local BUFF_PROCS = {
    MAGE = {
        { buffs = { 400669 }, name = "Fingers of Frost", glows = { { 30455, "Ice Lance" } } },
        { buffs = { 400588 }, name = "Missile Barrage", glows = { { 5143, "Arcane Missiles" } } },
        { buffs = { 11078 }, name = "Wake of Fire", glows = { { 2136, "Fire Blast" } } },
    },
    WARLOCK = {
        { buffs = { 17941 }, name = "Shadow Trance", glows = { { 686, "Shadow Bolt" } } },
        { buffs = { 440873 }, name = "Decimation", glows = { { 6353, "Soul Fire" } } },
    },
    DRUID = {
        { buffs = { 408255, 441260 }, name = "Eclipse", glows = { { 2912, "Starfire" } } },
    },
    SHAMAN = {
        { buffs = { 408505 }, name = "Maelstrom Weapon", glows = { { 403, "Lightning Bolt" } } },
    },
    HUNTER = {
        { buffs = { 415407 }, name = "Rapid Killing", glows = { { 19434, "Aimed Shot" }, { 3044, "Arcane Shot" }, { 2643, "Multi-Shot" } } },
    },
    PRIEST = {
        { name = "Searing Light", glows = { { 15237, "Holy Nova" } } },
    },
    PALADIN = {
        { buffs = { 437063 }, name = "Infusion of Light", glows = { { 635, "Holy Light" } } },
    },
}
local CDM_VIEWERS = { "BuffIconCooldownViewer", "BuffBarCooldownViewer" }
local CDM_INTERVAL = 1   -- a safety net: the reads follow aura changes, fights and the viewers themselves

local BAR_PREFIXES = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
    "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
}

local GLOW_SCALE = 1.4      -- Blizzard's alert size around a button

local reactive = {}         -- localised spell name -> true
local flagged = {}          -- localised spell name -> the flagged spell's ID, while the game flags it
local oneUseName            -- this character's Revenge, by name
local spentUntil = 0        -- until when it stays dark after a cast
local cooldownIDs = {}      -- reactive spell ID on the bars -> true
local onGCD = {}            -- spell ID -> its isOnGCD, as read during SPELL_UPDATE_COOLDOWN
local buttons = {}
local slotSpell = {}        -- action slot -> { id, name }, or false: not a spell (macros are read each time)
local pending, pendingNow = false, false
local events
local playerClass
local boosted = {}          -- localised spell name -> true while a buff proc empowers it
local ScheduleNow           -- section 3

local function Enabled()
    local db = ns.db and ns.db.profile and ns.db.profile.actionbars
    return db and db.enabled and db.procGlow and true or false
end

local function Readable(v)
    return v ~= nil and canaccessvalue(v)
end

local function SpellName(id)
    if not Readable(id) then return nil end
    local ok, name = pcall(C_Spell.GetSpellName, id)
    if ok and Readable(name) and type(name) == "string" then return name end
end

-- the spell in a button's slot (a spell, or a macro that casts one)
local function ButtonSpell(button)
    local slot = button.action
    if not (Readable(slot) and type(slot) == "number" and slot > 0) then return nil end
    local cached = slotSpell[slot]
    if cached then return cached.id, cached.name, slot end
    if cached == false then return nil end
    local ok, kind, id, subType = pcall(GetActionInfo, slot)
    if not (ok and Readable(kind)) then
        if ok and canaccessvalue(kind) then slotSpell[slot] = false end   -- an empty slot
        return nil
    end
    if kind == "spell" or (kind == "macro" and Readable(subType) and subType == "spell") then
        local name = SpellName(id)
        if not name then return nil end
        -- a macro's spell changes with its conditions, without an event
        if kind == "spell" then slotSpell[slot] = { id = id, name = name } end
        return id, name, slot
    end
    if kind ~= "macro" then slotSpell[slot] = false end
end

--------------------------------------------------
-- 2. GLOWS
--------------------------------------------------
local function Glow(button)
    local glow = button.FlareUI_ProcGlow
    if not glow then
        glow = CreateFrame("Frame", nil, button, "ActionButtonSpellAlertTemplate")
        local w, h = button:GetSize()
        glow:SetSize(w * GLOW_SCALE, h * GLOW_SCALE)
        glow:SetPoint("CENTER", button, "CENTER", 0, 0)
        button.FlareUI_ProcGlow = glow
    end
    return glow
end

local function HideGlow(button)
    local glow = button.FlareUI_ProcGlow
    if not glow or not glow:IsShown() then return end
    glow.ProcStartAnim:Stop()
    glow.ProcLoop:Stop()
    glow:Hide()
    glow:SetAlpha(1)
end

-- on: a boolean, or a secret "usable" fed to SetAlphaFromBoolean unread
local function ShowGlow(button, on)
    local glow = Glow(button)
    if not canaccessvalue(on) then
        glow:SetAlphaFromBoolean(on, 1, 0)
        if not glow:IsShown() then
            glow:Show()
            glow.ProcLoop:Play()
        end
        return
    end
    if not on then HideGlow(button) return end
    glow:SetAlpha(1)
    if not glow:IsShown() then
        glow:Show()
        glow.ProcStartAnim:Play()
    end
end

--------------------------------------------------
-- 2b. BUFF PROCS
-- Each proc has three sources: overlay (the game's proc alert is up), cdm (its Cooldown Manager icon is
-- active), aura (seen on you while buffs could be read: until it runs out, or you cast what it empowers).
-- In combat a proc the Cooldown Manager watches follows only the icon and the alert, as the aura is stale.
--------------------------------------------------
local BP = { procs = {}, byID = {}, byName = {}, glowName = {}, cdmProc = {}, hookedViewers = {}, want = {} }

-- the class's procs with their names resolved (on setup and when spells change). A proc keeps its
-- state: SPELLS_CHANGED can come in a fight, when the buffs can't be read again.
function BP.Build()
    local old = {}
    for _, proc in ipairs(BP.procs) do old[proc.data] = proc end
    wipe(BP.procs); wipe(BP.byID); wipe(BP.byName); wipe(BP.glowName); wipe(BP.cdmProc)
    for _, data in ipairs(BUFF_PROCS[playerClass] or {}) do
        local was = old[data]
        local proc = { data = data, glows = {}, overlay = was and was.overlay or false, cdm = was and was.cdm or false,
            cdmSeen = was and was.cdmSeen or false, auraUntil = was and was.auraUntil or nil }
        proc.name = (data.buffs and SpellName(data.buffs[1])) or data.name
        BP.byName[proc.name] = proc
        BP.byName[data.name] = proc
        for _, id in ipairs(data.buffs or {}) do BP.byID[id] = proc end
        for _, g in ipairs(data.glows) do
            local name = SpellName(g[1]) or g[2]
            proc.glows[#proc.glows + 1] = name
            BP.glowName[name] = proc
        end
        BP.procs[#BP.procs + 1] = proc
    end
end

function BP.ForSpell(id)
    if not Readable(id) then return nil end
    return BP.byID[id] or BP.byName[SpellName(id) or ""]
end

function BP.AurasLocked()
    local ok, secret = pcall(C_Secrets.ShouldAurasBeSecret)
    return not ok or not Readable(secret) or secret
end

function BP.IsOn(proc)
    if proc.overlay then return true end
    -- the Cooldown Manager is the truth in combat when it watches this proc; out of combat the buff
    -- itself is (a viewer's icon can lag behind it)
    local locked = BP.AurasLocked()
    if proc.cdmSeen and locked then return proc.cdm and true or false end
    return proc.auraUntil ~= nil and GetTime() < proc.auraUntil
end

-- recomputes which spells glow; a change lights or darks them on the next frame
function BP.Recompute()
    local changed = false
    local want = BP.want
    wipe(want)
    for _, proc in ipairs(BP.procs) do
        if BP.IsOn(proc) then
            for _, name in ipairs(proc.glows) do want[name] = true end
        end
    end
    for name in pairs(boosted) do
        if not want[name] then boosted[name] = nil; changed = true end
    end
    for name in pairs(want) do
        if not boosted[name] then boosted[name] = true; changed = true end
    end
    if changed then ScheduleNow() end
end

-- Your buffs, while the game lets addons read them. In combat the last reading is kept.
function BP.ReadAuras()
    if BP.AurasLocked() then return end
    BP.wasLocked = false
    local now = GetTime()
    for _, proc in ipairs(BP.procs) do
        local aura
        for _, id in ipairs(proc.data.buffs or {}) do
            local ok, a = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
            if ok and a then aura = a break end
        end
        if not aura then
            local ok, a = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", proc.name, "HELPFUL")
            if ok and a then aura = a end
        end
        local expires = aura and aura.expirationTime
        if not aura then
            proc.auraUntil = nil
            -- the game's proc alert only shows with the buff: a missed (or secret) hide ends here
            proc.overlay = false
        elseif Readable(expires) and type(expires) == "number" and expires > 0 then
            -- one timer per new end time (UNIT_AURA comes often)
            if proc.auraUntil ~= expires then C_Timer.After(math.max(0, expires - now) + 0.05, BP.Recompute) end
            proc.auraUntil = expires
        else
            proc.auraUntil = math.huge   -- no end time: until it's gone or spent
        end
    end
    BP.Recompute()
end

-- a cast of an empowered spell spends the proc we can't see any more (charges aren't counted)
function BP.OnCast(spellID)
    local proc = BP.glowName[SpellName(spellID) or ""]
    if proc and proc.auraUntil and BP.AurasLocked() then
        proc.auraUntil = nil
        BP.Recompute()
    end
end

function BP.OnOverlay(event, spellID)
    if event == "SPELL_ACTIVATION_OVERLAY_SHOW" then
        local proc = BP.ForSpell(spellID)
        if proc then proc.overlay = true; BP.Recompute() end
        return
    end
    -- HIDE with no spell clears every alert; a secret spell can't be matched
    if spellID == nil then
        for _, proc in ipairs(BP.procs) do proc.overlay = false end
        BP.Recompute()
    elseif Readable(spellID) then
        local proc = BP.ForSpell(spellID)
        if proc then proc.overlay = false; BP.Recompute() end
    end
end

-- The proc a Cooldown Manager entry follows (by the spells Blizzard ties to it), cached per entry
function BP.CDMProcFor(cooldownID)
    local cached = BP.cdmProc[cooldownID]
    if cached ~= nil then return cached or nil end
    local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cooldownID)
    local proc
    if ok and type(info) == "table" then
        local ids = {}
        local function Add(v) if Readable(v) and type(v) == "number" then ids[#ids + 1] = v end end
        Add(info.spellID); Add(info.overrideSpellID); Add(info.overrideTooltipSpellID)
        local linked = info.linkedSpellIDs
        if Readable(linked) and type(linked) == "table" then
            for _, id in ipairs(linked) do Add(id) end
        end
        for _, id in ipairs(ids) do
            proc = BP.ForSpell(id)
            if proc then break end
        end
    end
    BP.cdmProc[cooldownID] = proc or false
    return proc
end

-- true / false, or nil when the icon shows nothing readable. Blizzard keeps isActive up to date in
-- combat; an aura instance (even a secret one) also means the buff is there.
function BP.IconActive(f)
    local v = f.isActive
    if Readable(v) and type(v) == "boolean" then return v end
    local inst = f.auraInstanceID
    if not canaccessvalue(inst) then return true end
    if inst ~= nil then return true end
end

-- one icon of a viewer: the proc it follows, and whether it's lit
local function VisitIcon(f, seen, on)
    local cid = f.cooldownID
    if Readable(cid) and type(cid) == "number" then
        local proc = BP.CDMProcFor(cid)
        if proc then
            seen[proc] = true
            if BP.IconActive(f) then on[proc] = true end
        end
    end
end

-- a viewer shown or hidden (its Visibility setting, a fight) is read at once. Retried on each read, as
-- the Cooldown Manager can load after FlareUI.
function BP.HookViewers()
    for _, viewerName in ipairs(CDM_VIEWERS) do
        local viewer = _G[viewerName]
        if viewer and viewer.UpdateShownState and not BP.hookedViewers[viewer] then
            BP.hookedViewers[viewer] = true
            hooksecurefunc(viewer, "UpdateShownState", BP.ScheduleCDM)
        end
    end
end

-- Reads the Cooldown Manager's buff icons (never moves, hides or changes them)
BP.seen, BP.on = {}, {}
function BP.ReadCDM()
    BP.HookViewers()
    local seen, on = BP.seen, BP.on
    wipe(seen)
    wipe(on)
    local enabled = C_CooldownViewer and GetCVarBool("cooldownViewerEnabled")
    for _, viewerName in ipairs(CDM_VIEWERS) do
        local viewer = enabled and _G[viewerName]
        -- a hidden viewer stops following auras (its icons keep their last state): shown ones only.
        -- IsShown, not IsVisible: one faded to nothing still follows them
        if viewer and viewer.GetChildren and viewer:IsShown() then
            local pool = viewer.itemFramePool
            if pool and pool.EnumerateActive then
                for f in pool:EnumerateActive() do VisitIcon(f, seen, on) end   -- its icons in use
            else
                for _, f in ipairs({ viewer:GetChildren() }) do VisitIcon(f, seen, on) end
            end
        end
    end
    -- buffs just locked (a fight started): a watched proc now follows its icon, not the old reading
    local locked = BP.AurasLocked()
    local changed = locked ~= BP.wasLocked
    BP.wasLocked = locked
    for _, proc in ipairs(BP.procs) do
        local cdm, cdmSeen = on[proc] or false, seen[proc] or false
        if cdm ~= proc.cdm or cdmSeen ~= proc.cdmSeen then
            proc.cdm, proc.cdmSeen = cdm, cdmSeen
            changed = true
        end
    end
    if changed then BP.Recompute() end
end

-- the next frame: the viewer has handled the same aura event by then
function BP.ScheduleCDM()
    if BP.cdmPending then return end
    BP.cdmPending = true
    C_Timer.After(0, function()
        BP.cdmPending = nil
        BP.ReadCDM()
    end)
end

function BP.Start()
    if #BP.procs == 0 or BP.ticker then return end
    BP.ticker = C_Timer.NewTicker(CDM_INTERVAL, BP.ReadCDM)
    BP.ScheduleCDM()
end

function BP.Stop()
    if BP.ticker then BP.ticker:Cancel(); BP.ticker = nil end
    for _, proc in ipairs(BP.procs) do
        proc.overlay, proc.cdm, proc.cdmSeen, proc.auraUntil = false, false, false, nil
    end
    wipe(boosted)
end

--------------------------------------------------
-- 3. UPDATES
--------------------------------------------------
-- on a real cooldown (not just the global one). Both flags are always readable, but Blizzard only vouches
-- for isOnGCD during SPELL_UPDATE_COOLDOWN, so it's kept from there; isActive is read live
local function OnCooldown(id)
    local ok, info = pcall(C_Spell.GetSpellCooldown, id)
    if not (ok and type(info) == "table" and info.isActive) then return false end
    local gcd = onGCD[id]
    if gcd == nil then gcd = info.isOnGCD end
    return not gcd
end

local function NoteCooldowns()
    for id in pairs(cooldownIDs) do
        local ok, info = pcall(C_Spell.GetSpellCooldown, id)
        if ok and type(info) == "table" then onGCD[id] = info.isOnGCD or false end
    end
end

local function UpdateButton(button, enabled)
    if not enabled then HideGlow(button) return end
    local id, name, slot = ButtonSpell(button)
    if not id then HideGlow(button) return end
    -- not flagged, empowered or a reaction ability: no glow either way, so Blizzard's own isn't asked about
    if not (flagged[name] or boosted[name] or reactive[name]) then HideGlow(button) return end
    -- Blizzard already glows this exact rank
    local blizzard = button.SpellActivationAlert
    if blizzard and blizzard:IsShown() then HideGlow(button) return end

    if flagged[name] or boosted[name] then
        ShowGlow(button, true)
    elseif reactive[name] then
        cooldownIDs[id] = true
        if OnCooldown(id) then HideGlow(button) return end
        local ok, usable = pcall(C_ActionBar.IsUsableAction, slot)
        if not ok then HideGlow(button) return end
        if name == oneUseName and spentUntil > 0 then
            -- the window has closed: the next "usable" is a new one
            if GetTime() >= spentUntil or (canaccessvalue(usable) and not usable) then
                spentUntil = 0
            else
                HideGlow(button)
                return
            end
        end
        ShowGlow(button, usable)
    else
        HideGlow(button)
    end
end

local function UpdateAll()
    local enabled = Enabled()
    for _, button in ipairs(buttons) do UpdateButton(button, enabled) end
end

local function UpdateThrottled()
    pending = false
    UpdateAll()
end

local function UpdateNow()
    pendingNow = false
    UpdateAll()
end

-- usable, cooldown and target health events arrive in bursts: one pass per tenth of a second
local function Schedule()
    if pending then return end
    pending = true
    C_Timer.After(0.1, UpdateThrottled)
end

-- a proc lights on the next frame, once Blizzard's own glow has had its turn
function ScheduleNow()
    if pendingNow then return end
    pendingNow = true
    C_Timer.After(0, UpdateNow)
end

local function IsOverlayed(id)
    local ok, on = pcall(C_SpellActivationOverlay.IsSpellOverlayed, id)
    if ok and Readable(on) then return on end
end

-- Asks the game what's flagged: none of the events arrive across a /reload or while switched off, and
-- one missed over a loading screen would leave a glow on
local function SyncFlagged()
    for name, id in pairs(flagged) do
        if IsOverlayed(id) == false then flagged[name] = nil end
    end
    for _, button in ipairs(buttons) do
        local id, name = ButtonSpell(button)
        if id and IsOverlayed(id) then flagged[name] = id end
    end
end

local function OnEvent(_, event, a1, a2, a3)
    if event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" or event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        local name = SpellName(a1)
        if name then flagged[name] = event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" and a1 or nil end
        ScheduleNow()
        return
    end
    if event == "SPELL_ACTIVATION_OVERLAY_SHOW" or event == "SPELL_ACTIVATION_OVERLAY_HIDE" then
        BP.OnOverlay(event, a1)
        return
    end
    if event == "UNIT_AURA" or event == "PLAYER_REGEN_ENABLED" then
        BP.ReadAuras()
        BP.ScheduleCDM()
        return
    end
    if event == "PLAYER_REGEN_DISABLED" then
        BP.ScheduleCDM()   -- buffs lock: the watched procs follow their icons now
        return
    end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        BP.OnCast(a3)
        -- (a3 can be secret in instances: then the glow keeps to what the game says)
        if oneUseName and SpellName(a3) == oneUseName then
            spentUntil = GetTime() + ONE_USE_SECONDS
            ScheduleNow()
            C_Timer.After(ONE_USE_SECONDS + 0.05, Schedule)
        end
        return
    end
    if event == "UNIT_COMBAT" then
        if spentUntil > 0 and ((Readable(a2) and AVOIDED[a2]) or (Readable(a3) and a3 == "BLOCK")) then
            spentUntil = 0
            ScheduleNow()
        end
        return
    end
    if event == "SPELL_UPDATE_COOLDOWN" then
        NoteCooldowns()
    elseif event == "ACTIONBAR_SLOT_CHANGED" and Readable(a1) and type(a1) == "number" and a1 > 0 then
        -- one slot changed: only its spell is read again (the GCD flags belong to spells, not slots)
        slotSpell[a1] = nil
    elseif event == "ACTIONBAR_SLOT_CHANGED" or event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        wipe(slotSpell)
        wipe(cooldownIDs)
        wipe(onGCD)
        if event == "PLAYER_ENTERING_WORLD" then SyncFlagged() end
        if event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
            BP.Build()
            BP.ReadAuras()
        end
    end
    Schedule()
end

local EVENTS = {
    "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
    "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
    "UPDATE_SHAPESHIFT_FORM", "PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED",
}
-- only for classes with reaction abilities: they come in bursts
local REACTIVE_EVENTS = {
    "ACTIONBAR_UPDATE_USABLE", "SPELL_UPDATE_USABLE", "ACTIONBAR_UPDATE_COOLDOWN", "SPELL_UPDATE_COOLDOWN",
}

--------------------------------------------------
-- 4. PUBLIC
--------------------------------------------------
local function Setup()
    if events then return end
    for _, prefix in ipairs(BAR_PREFIXES) do
        for i = 1, 12 do
            local button = _G[prefix .. i]
            if button then buttons[#buttons + 1] = button end
        end
    end
    local _, class = UnitClass("player")
    playerClass = class
    for _, id in ipairs(REACTIVE_IDS[class] or {}) do
        local name = SpellName(id)
        if name then
            reactive[name] = true
            if id == ONE_USE_ID then oneUseName = name end
        end
    end
    BP.Build()
    events = CreateFrame("Frame")
    events:SetScript("OnEvent", OnEvent)
end

function PG:Refresh()
    if not events and not Enabled() then return end
    Setup()
    if Enabled() then
        for _, event in ipairs(EVENTS) do pcall(events.RegisterEvent, events, event) end
        if next(reactive) then
            for _, event in ipairs(REACTIVE_EVENTS) do pcall(events.RegisterEvent, events, event) end
            if TARGET_HEALTH_CLASSES[playerClass] then
                pcall(events.RegisterUnitEvent, events, "UNIT_HEALTH", "target")
            end
        end
        if oneUseName then
            pcall(events.RegisterUnitEvent, events, "UNIT_COMBAT", "player")
        end
        if oneUseName or #BP.procs > 0 then
            pcall(events.RegisterUnitEvent, events, "UNIT_SPELLCAST_SUCCEEDED", "player")
        end
        -- buff procs: the game's proc alert, your buffs, and the Cooldown Manager's icons
        if #BP.procs > 0 then
            pcall(events.RegisterEvent, events, "SPELL_ACTIVATION_OVERLAY_SHOW")
            pcall(events.RegisterEvent, events, "SPELL_ACTIVATION_OVERLAY_HIDE")
            pcall(events.RegisterEvent, events, "PLAYER_REGEN_ENABLED")
            pcall(events.RegisterEvent, events, "PLAYER_REGEN_DISABLED")
            pcall(events.RegisterUnitEvent, events, "UNIT_AURA", "player")
            BP.Start()
            BP.ReadAuras()
        end
        SyncFlagged()
    else
        events:UnregisterAllEvents()
        BP.Stop()
        -- HIDE events are missed while off: a kept flag would glow on return
        wipe(flagged)
        wipe(slotSpell)
        wipe(cooldownIDs)
        wipe(onGCD)
        spentUntil = 0
    end
    UpdateAll()
end
