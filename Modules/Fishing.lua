local _, ns = ...

--------------------------------------------------
-- FISHING (Quality of Life > Convenience)
-- Double-click to fish: with a fishing pole in hand, a quick second right-click on the world casts
-- Fishing. The click goes to a secure button through an override binding set for that one click,
-- out of combat only.
-- Fishing sounds: from the first cast until you move, fight or zone, the music and ambience go down
-- and sound effects up, so the splash is heard. Your volumes come back after, and at the next login
-- if the game closed mid-session.
--------------------------------------------------
local Fishing = {}
ns.Fishing = Fishing

local BUTTON_NAME = "FlareUI_FishingCast"
local FISHING_SPELL = 7620          -- Fishing, for its name in the client's language
local DOUBLE_CLICK = 0.4            -- seconds at most between the two right-clicks
local DISARM_AFTER = 1              -- the binding goes back if no click came by then
local SESSION_IDLE = 30             -- no new cast this long after the line came in: the session ends

-- the volumes while fishing, from the player's own
local SOUNDS = {
    Sound_MusicVolume = function(v) return v * 0.3 end,
    Sound_AmbienceVolume = function(v) return v * 0.3 end,
    Sound_SFXVolume = function(v) return math.max(v, 0.8) end,
}

local function GetDb()
    local tweaks = ns.db and ns.db.profile and ns.db.profile.tweaks
    if not (tweaks and tweaks.enabled ~= false) then return nil end
    return tweaks
end

local function FishingName()
    return C_Spell.GetSpellName(FISHING_SPELL)
end

local function PoleInHand()
    local itemID = GetInventoryItemID("player", INVSLOT_MAINHAND or 16)
    if not itemID then return false end
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
    return classID == Enum.ItemClass.Weapon and subclassID == Enum.ItemWeaponSubclass.Fishingpole
end

local events = CreateFrame("Frame")

--------------------------------------------------
-- Fishing sounds
--------------------------------------------------
-- the player's volumes are kept account-wide (where the game keeps them) until put back
local function SavedSounds()
    return ns.db and ns.db.global
end

local inSession, idleTimer = false, nil

local function EndSession()
    if idleTimer then idleTimer:Cancel(); idleTimer = nil end
    inSession = false
    events:UnregisterEvent("PLAYER_STARTED_MOVING")
    local global = SavedSounds()
    local saved = global and global.fishingSounds
    if not saved then return end
    for name, value in pairs(saved) do pcall(SetCVar, name, value) end
    global.fishingSounds = nil
end

local function StartSession()
    if idleTimer then idleTimer:Cancel(); idleTimer = nil end
    if inSession then return end
    local db, global = GetDb(), SavedSounds()
    if not (db and db.fishSound and global) or InCombatLockdown() then return end
    inSession = true
    events:RegisterEvent("PLAYER_STARTED_MOVING")
    if global.fishingSounds then return end   -- still held from before
    local saved = {}
    for name, lower in pairs(SOUNDS) do
        local current = tonumber(GetCVar(name))
        if current then
            local want = lower(current)
            if math.abs(want - current) > 0.001 and pcall(SetCVar, name, ("%.2f"):format(want)) then
                saved[name] = tostring(current)
            end
        end
    end
    global.fishingSounds = saved
end

--------------------------------------------------
-- Double-click to fish
--------------------------------------------------
local button, owner
local armed, armedAt, lastRightClick = false, 0, 0

local function Disarm()
    if armed and not InCombatLockdown() then ClearOverrideBindings(owner) end
    armed = false
end

local function BuildButton()
    if button then return end
    button = CreateFrame("Button", BUTTON_NAME, UIParent, "SecureActionButtonTemplate")
    -- the binding is set while the second click is already down: its release casts
    button:RegisterForClicks("AnyUp")
    button:SetAttribute("type", "spell")
    button:Hide()
    button:SetScript("PostClick", Disarm)
    owner = CreateFrame("Frame")
end

local function OnWorldMouseDown(_, mouseButton)
    if mouseButton ~= "RightButton" then return end
    local db = GetDb()
    if not (db and db.fishCast) or ns.IsGamepadUI() or not button then return end
    local now = GetTime()
    -- a right-click that reels in (the line is out) never starts a double-click
    if UnitChannelInfo("player") then
        lastRightClick = 0
        return
    end
    local double = now - lastRightClick < DOUBLE_CLICK
    lastRightClick = double and 0 or now
    if not double or InCombatLockdown() or UnitExists("mouseover") or not PoleInHand() then return end
    local name = FishingName()
    if not (name and C_Spell.GetSpellInfo(name)) then return end
    button:SetAttribute("spell", name)
    SetOverrideBindingClick(owner, true, "BUTTON2", BUTTON_NAME)
    armed, armedAt = true, now
    C_Timer.After(DISARM_AFTER, function()
        if armed and GetTime() - armedAt >= DISARM_AFTER - 0.05 then Disarm() end
    end)
end

--------------------------------------------------
-- Events and switches
--------------------------------------------------
events:SetScript("OnEvent", function(_, event, _, _, spellID)
    if event == "UNIT_SPELLCAST_CHANNEL_START" then
        if canaccessvalue(spellID) and spellID and C_Spell.GetSpellName(spellID) == FishingName() then
            StartSession()
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        if inSession then
            if idleTimer then idleTimer:Cancel() end
            idleTimer = C_Timer.NewTimer(SESSION_IDLE, EndSession)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        Fishing:Apply()   -- a switch flipped in combat
    elseif event == "PLAYER_REGEN_DISABLED" then
        if armed then ClearOverrideBindings(owner); armed = false end
        EndSession()
    else
        -- PLAYER_STARTED_MOVING, PLAYER_LEAVING_WORLD
        EndSession()
    end
end)

local worldHooked = false
function Fishing:Apply()
    if InCombatLockdown() then
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    events:UnregisterEvent("PLAYER_REGEN_ENABLED")
    local db = GetDb()
    local cast, sound = db and db.fishCast, db and db.fishSound
    if not sound then EndSession() end
    Disarm()
    if not (cast or sound) then
        events:UnregisterAllEvents()
        return
    end
    events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
    events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_LEAVING_WORLD")
    -- never in the Gamepad UI: a hook there can run inside its secure navigation
    if cast and not worldHooked and not ns.IsGamepadUI() then
        BuildButton()
        worldHooked = true
        WorldFrame:HookScript("OnMouseDown", OnWorldMouseDown)
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    -- volumes still held when the game closed mid-session go back first
    local global = SavedSounds()
    if global and global.fishingSounds then
        for name, value in pairs(global.fishingSounds) do pcall(SetCVar, name, value) end
        global.fishingSounds = nil
    end
    Fishing:Apply()
end)
