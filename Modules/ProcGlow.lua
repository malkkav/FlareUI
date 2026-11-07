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
    -- neither flagged nor a reaction ability: no glow either way, so Blizzard's own isn't asked about
    if not (flagged[name] or reactive[name]) then HideGlow(button) return end
    -- Blizzard already glows this exact rank
    local blizzard = button.SpellActivationAlert
    if blizzard and blizzard:IsShown() then HideGlow(button) return end

    if flagged[name] then
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
local function ScheduleNow()
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
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- (a3 can be secret in instances: then the glow keeps to what the game says)
        if SpellName(a3) == oneUseName then
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
    elseif event == "ACTIONBAR_SLOT_CHANGED" or event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        wipe(slotSpell)
        wipe(cooldownIDs)
        wipe(onGCD)
        if event == "PLAYER_ENTERING_WORLD" then SyncFlagged() end
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
            pcall(events.RegisterUnitEvent, events, "UNIT_SPELLCAST_SUCCEEDED", "player")
            pcall(events.RegisterUnitEvent, events, "UNIT_COMBAT", "player")
        end
        SyncFlagged()
    else
        events:UnregisterAllEvents()
        -- HIDE events are missed while off: a kept flag would glow on return
        wipe(flagged)
        wipe(slotSpell)
        wipe(cooldownIDs)
        wipe(onGCD)
        spentUntil = 0
    end
    UpdateAll()
end
