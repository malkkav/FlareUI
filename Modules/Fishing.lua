local _, ns = ...

--------------------------------------------------
-- FISHING (Quality of Life > Convenience)
-- Double-click to fish: with a fishing pole in hand, two quick right-clicks on the world cast
-- Fishing. The first arms an override binding that hands the second click to a secure button,
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
local armed, armedAt = false, 0
local press   -- the right button's last press on the world: { at, x, y }
local CLICK = { quick = 0.25, travel = 12 }   -- a click: shorter than this (else the camera turns), moved less (px)

-- the binding goes back; a second click still held keeps it until it comes up
local function Disarm()
    if armed and not InCombatLockdown() then ClearOverrideBindings(owner) end
    armed = false
end

local function BuildButton()
    if button then return end
    button = CreateFrame("Button", BUTTON_NAME, UIParent, "SecureActionButtonTemplate")
    -- the whole second click comes through the binding (armed by the first): it casts as it comes up,
    -- whatever Cast on Key Down says
    button:RegisterForClicks("AnyUp")
    button:SetAttribute("type", "spell")
    button:SetAttribute("useOnKeyDown", false)
    button:Hide()
    button:SetScript("PostClick", Disarm)
    -- the binding's owner drops it the moment a fight starts: secure, as plain code can't then
    owner = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
    owner:SetAttribute("_onstate-combat", [[ if newstate == "combat" then self:ClearBindings() end ]])
    RegisterStateDriver(owner, "combat", "[combat] combat; peace")
end

-- the cursor over the world itself, no frame in the way
local function OnWorld()
    local foci = GetMouseFoci and GetMouseFoci()
    if foci then
        for _, focus in ipairs(foci) do
            if focus ~= WorldFrame then return false end
        end
        return true
    end
    local focus = GetMouseFocus and GetMouseFocus()
    return focus == nil or focus == WorldFrame
end

local function CanCast(db)
    return db and db.fishCast and button and not ns.IsGamepadUI() and not InCombatLockdown()
        and not UnitChannelInfo("player")   -- the line is out: a right-click reels in
        and not UnitExists("mouseover") and not IsModifierKeyDown() and PoleInHand()
end

-- (6.3.3, "it's actually not working") The first quick right-click on the world arms the cast: for
-- DOUBLE_CLICK seconds the right button is bound to the cast button, so the second click goes to it
-- whole, press and release. Before, the binding was set during the second press itself, which the
-- game doesn't always hand over (Forever Fishing's way of arming, written anew)
local function OnRightMouse(event)
    local db = GetDb()
    if event == "GLOBAL_MOUSE_DOWN" then
        if armed then return end   -- the second press: the binding's
        if OnWorld() and CanCast(db) then
            local x, y = GetCursorPosition()
            press = { at = GetTime(), x = x, y = y }
        else
            press = nil
        end
        return
    end
    -- GLOBAL_MOUSE_UP
    if armed then
        -- the second click's release (it casts; PostClick disarms): disarmed next frame anyway
        C_Timer.After(0, Disarm)
        return
    end
    local p = press
    press = nil
    if not p or GetTime() - p.at > CLICK.quick or not CanCast(db) then return end
    local x, y = GetCursorPosition()
    if (x - p.x) ^ 2 + (y - p.y) ^ 2 > CLICK.travel ^ 2 then return end
    local name = FishingName()
    if not (name and C_Spell.GetSpellInfo(name)) then return end
    button:SetAttribute("spell", name)
    SetOverrideBindingClick(owner, true, "BUTTON2", BUTTON_NAME)
    armed, armedAt = true, GetTime()
    local at = armedAt
    local function Expire()
        if not armed or armedAt ~= at then return end
        -- a second press already down keeps the binding until it comes up
        if IsMouseButtonDown("RightButton") then C_Timer.After(0.2, Expire) else Disarm() end
    end
    C_Timer.After(DOUBLE_CLICK, Expire)
end

local function OnMouse(event, mouseButton)
    if mouseButton == "RightButton" then
        OnRightMouse(event)
    elseif event == "GLOBAL_MOUSE_DOWN" then
        -- another button breaks the pair
        press = nil
        Disarm()
    end
end

--------------------------------------------------
-- Events and switches
--------------------------------------------------
events:SetScript("OnEvent", function(_, event, ...)
    if event == "GLOBAL_MOUSE_DOWN" or event == "GLOBAL_MOUSE_UP" then
        OnMouse(event, (...))
        return
    end
    local spellID = select(3, ...)
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
        -- (the owner's secure driver has already dropped the binding)
        armed, press = false, nil
        EndSession()
    else
        -- PLAYER_STARTED_MOVING, PLAYER_LEAVING_WORLD
        EndSession()
    end
end)

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
    -- (the Gamepad UI is left out at each click: CanCast)
    if cast then
        BuildButton()
        events:RegisterEvent("GLOBAL_MOUSE_DOWN")
        events:RegisterEvent("GLOBAL_MOUSE_UP")
    else
        events:UnregisterEvent("GLOBAL_MOUSE_DOWN")
        events:UnregisterEvent("GLOBAL_MOUSE_UP")
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
