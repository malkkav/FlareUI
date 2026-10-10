local _, ns = ...

--------------------------------------------------
-- PROC GLOW (Action Bars > Buttons, off by default)
-- Blizzard's proc glow on the action bars (and so on the Fake CM bars) for the abilities worth
-- reacting to:
--   * whatever the game flags with its own proc glow (SPELL_ACTIVATION_OVERLAY_GLOW_SHOW). Blizzard's
--     buttons only glow when the flagged spell ID is the exact one in the slot, which misses every
--     other rank; here the spell's name decides, so any rank on any bar lights up.
--   * the reaction abilities, which become usable only after something happens: Overpower (the
--     target dodged), Revenge (you blocked, dodged or parried), Riposte and Counterattack (you
--     parried), Mongoose Bite (the target dodged), Execute and Hammer of Wrath (the target is low).
--     They glow while usable and not on their own cooldown. In combat Forever may hide whether an
--     action is usable; the glow's alpha then takes that hidden answer directly (SetAlphaFromBoolean),
--     without FlareUI ever reading it.
-- Each glow is Blizzard's own (ActionButtonSpellAlertTemplate), on a frame of FlareUI's: Blizzard's
-- alert manager is never touched, so the buttons stay untainted.
--------------------------------------------------
local PG = {}
ns.ProcGlow = PG

-- the reaction abilities, by one rank's spell ID (the name covers every rank)
local REACTIVE_IDS = {
    7384,   -- Overpower
    6572,   -- Revenge
    5308,   -- Execute
    14251,  -- Riposte
    19306,  -- Counterattack
    1495,   -- Mongoose Bite
    24275,  -- Hammer of Wrath
}

local BAR_PREFIXES = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
    "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
}

local GLOW_SCALE = 1.4      -- Blizzard's own size for the alert around a button

local reactive = {}         -- localised spell name -> true
local flagged = {}          -- localised spell name -> true while the game flags it
local buttons = {}
local pending = false
local events

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

-- the spell in a button's slot (a spell, or a macro that casts one), with its name
local function ButtonSpell(button)
    local slot = button.action
    if not (Readable(slot) and type(slot) == "number" and slot > 0) then return nil end
    local ok, kind, id, subType = pcall(GetActionInfo, slot)
    if not (ok and Readable(kind)) then return nil end
    if kind == "spell" or (kind == "macro" and Readable(subType) and subType == "spell") then
        local name = SpellName(id)
        if name then return id, name, slot end
    end
end

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

-- on: true/false, or Forever's hidden answer (secret) for "usable"
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
        glow.ProcStartAnim:Play()   -- Blizzard's burst, then its loop
    end
end

-- on a real cooldown (not just the global one); both flags are always readable
local function OnCooldown(id)
    local ok, info = pcall(C_Spell.GetSpellCooldown, id)
    return ok and type(info) == "table" and info.isActive and not info.isOnGCD or false
end

local function UpdateButton(button)
    if not Enabled() then HideGlow(button) return end
    local id, name, slot = ButtonSpell(button)
    if not id then HideGlow(button) return end
    -- Blizzard already glows this one (same rank): its glow is enough
    local blizzard = button.SpellActivationAlert
    if blizzard and blizzard:IsShown() then HideGlow(button) return end

    if flagged[name] then
        ShowGlow(button, true)
    elseif reactive[name] then
        if OnCooldown(id) then HideGlow(button) return end
        local ok, usable = pcall(IsUsableAction, slot)
        if not ok then HideGlow(button) return end
        ShowGlow(button, usable)
    else
        HideGlow(button)
    end
end

local function UpdateAll()
    pending = false
    for _, button in ipairs(buttons) do UpdateButton(button) end
end

-- many events arrive together: one pass on the next frame
local function Schedule()
    if pending then return end
    pending = true
    C_Timer.After(0, UpdateAll)
end

local function OnEvent(_, event, spellID)
    if event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" or event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        local name = SpellName(spellID)
        if name then flagged[name] = (event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW") or nil end
    end
    Schedule()
end

local EVENTS = {
    "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
    "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
    "ACTIONBAR_UPDATE_USABLE", "SPELL_UPDATE_USABLE", "ACTIONBAR_UPDATE_COOLDOWN", "SPELL_UPDATE_COOLDOWN",
    "UPDATE_SHAPESHIFT_FORM", "PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED",
}

-- the buttons, the reaction abilities by name, and the event frame: once
local function Setup()
    if events then return end
    for _, prefix in ipairs(BAR_PREFIXES) do
        for i = 1, 12 do
            local button = _G[prefix .. i]
            if button then buttons[#buttons + 1] = button end
        end
    end
    for _, id in ipairs(REACTIVE_IDS) do
        local name = SpellName(id)
        if name then reactive[name] = true end
    end
    events = CreateFrame("Frame")
    events:SetScript("OnEvent", OnEvent)
end

function PG:Refresh()
    if not events and not Enabled() then return end
    Setup()
    if Enabled() then
        for _, event in ipairs(EVENTS) do pcall(events.RegisterEvent, events, event) end
        pcall(events.RegisterUnitEvent, events, "UNIT_HEALTH", "target")
    else
        events:UnregisterAllEvents()
    end
    UpdateAll()
end
