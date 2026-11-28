local addonName, ns = ...
local L = ns.L

--------------------------------------------------
-- GAMEPAD MODE
-- Switches the InputDeviceInterfaceStyle CVar (reloads the UI): offered on the first controller press
-- with keyboard and mouse (once a session, never in combat, unless switched off in Quality of Life),
-- or via /fui pad. Also: the controller key names radials use, controller rumble, the login line.
--------------------------------------------------

--------------------------------------------------
-- 1. SWITCHING
--------------------------------------------------
local GAMEPAD, MKB = 1, 0           -- Enum.InputDeviceInterfaceType.Gamepad / .Mkb
local CVAR = "InputDeviceInterfaceStyle"

local declined, pendingOffer, padActive
-- After a reload the controller can still read as active: the offer waits for keyboard or mouse
-- input first. A fresh login starts armed.
local armed

local function CheckSwitched(on)
    -- still here a moment later: the switch did not go through
    C_Timer.After(1, function()
        if ns.IsGamepadUI() ~= on then
            print("|cffff9900FlareUI:|r " .. L["The switch did not go through. Use Blizzard's Settings > Gamepad > Enable Gamepad UI."])
        end
    end)
end

-- The pad's yes: the client allows this from a controller press, not a mouse click
local function SetGamepadMode(on)
    if InCombatLockdown() then
        print("|cffff9900FlareUI:|r " .. L["Gamepad mode cannot be switched in combat."])
        return
    end
    SetCVar(CVAR, on and GAMEPAD or MKB)
    CheckSwitched(on)
end

-- A click or Enter runs this through the dialog's secure button
local function SwitchMacro(on)
    return ('/run SetCVar("%s", %d)'):format(CVAR, on and GAMEPAD or MKB)
end

-- Controller addons that bind the pad's buttons themselves: with one loaded, FlareUI binds no
-- controller button (two owners of a stick press leave it stuck or dead) and never offers the switch
local CONTROLLER_ADDONS = { "ConsolePort", "ImprovedForever", "ImprovedForever_Wheel", "EasyController", "ControllerForever" }

-- the first one loaded, or nil
function ns.OtherControllerAddon()
    for _, name in ipairs(CONTROLLER_ADDONS) do
        if C_AddOns.IsAddOnLoaded(name) then return name end
    end
end

--------------------------------------------------
-- 2. STICK-PRESS COMBOS AND KEY TEXT
-- In the Gamepad UI, LT and RT are not keys: they hold the bar's crossbar modifiers (GAMEPADLEFTMOD /
-- GAMEPADRIGHTMOD), and LB / RB are its targeting. So a radial's controller key is saved as a combo,
-- "PADCOMBO-<side>-<stick>": the stick pressed (L3 or R3) and the triggers held (TOP for none, LT, RT
-- or LTRT). The radial reads the triggers itself when the stick is pressed.
--------------------------------------------------
local COMBO_STICKS = { L3 = "PADLSTICK", R3 = "PADRSTICK" }
local COMBO_SIDES = { TOP = true, LT = true, RT = true, LTRT = true }

-- stick ("L3" / "R3") and side, or nil for any other key
function ns.ParsePadCombo(key)
    if type(key) ~= "string" then return nil end
    local side, stick = key:match("^PADCOMBO%-(%u+)%-(%w+)$")
    if not side then
        stick = key:match("^PADCOMBO%-(%w+)$")
        side = "TOP"
    end
    if stick and COMBO_STICKS[stick] and COMBO_SIDES[side] then return stick, side end
end

function ns.PadComboKey(stick, side)
    return side == "TOP" and ("PADCOMBO-" .. stick) or ("PADCOMBO-" .. side .. "-" .. stick)
end

function ns.PadStickKey(stick) return COMBO_STICKS[stick] end

-- The button each crossbar modifier is on (the Gamepad UI keeps its bindings in mode 1), or the
-- default trigger
function ns.PadTriggerKey(side)
    local action = side == "LT" and "GAMEPADLEFTMOD" or "GAMEPADRIGHTMOD"
    local ok, key = pcall(GetBindingKey, action, 1)
    return (ok and key) or (side == "LT" and "PADLTRIGGER" or "PADRTRIGGER")
end

-- the triggers a side holds, as text, in a list the caller adds to
local function TriggersText(side)
    local parts = {}
    if side == "LT" or side == "LTRT" then parts[#parts + 1] = GetBindingText(ns.PadTriggerKey("LT")) end
    if side == "RT" or side == "LTRT" then parts[#parts + 1] = GetBindingText(ns.PadTriggerKey("RT")) end
    return parts
end

-- "LT + R3", with the client's controller icons where it has them; nil for any other key
function ns.PadComboText(key)
    local stick, side = ns.ParsePadCombo(key)
    if not stick then return nil end
    local parts = TriggersText(side)
    parts[#parts + 1] = GetBindingText(COMBO_STICKS[stick])
    return table.concat(parts, " + ")
end

-- A slot of the controller bar: "PADBAR-<side>-<button>", the triggers held (TOP, LT, RT or LTRT)
-- and the face button or D-pad direction pressed
function ns.PadBarKey(side, button)
    return "PADBAR-" .. side .. "-" .. button
end

function ns.ParsePadBar(key)
    if type(key) ~= "string" then return nil end
    local side, button = key:match("^PADBAR%-(%u+)%-(%w+)$")
    if side and COMBO_SIDES[side] then return side, button end
end

-- any key as text: a stick combo or bar slot ("LT + A"), else Blizzard's name for it
function ns.KeyText(key)
    if not key or key == "" then return "" end
    local combo = ns.PadComboText(key)
    if combo then return combo end
    local side, button = ns.ParsePadBar(key)
    if side then
        local parts = TriggersText(side)
        parts[#parts + 1] = GetBindingText(button)
        return table.concat(parts, " + ")
    end
    return (GetBindingText and GetBindingText(key)) or key
end

--------------------------------------------------
-- 3. SWITCH DIALOGS
--------------------------------------------------
ns.Dialogs = ns.Dialogs or {}

ns.Dialogs["FLAREUI_GAMEPAD_ON"] = {
    text = L["Switch to Gamepad mode?\n\nThe UI reloads into Blizzard's Gamepad UI. Type /fui pad to switch back."],
    button1 = L["Switch"],
    button2 = L["Not Now"],
    OnAccept = function() SetGamepadMode(true) end,
    macro = SwitchMacro(true),
    OnMacro = function() CheckSwitched(true) end,
    OnCancel = function() declined = true end,
    hideOnEscape = true,
    padInput = true,
}

ns.Dialogs["FLAREUI_GAMEPAD_OFF"] = {
    text = L["Switch to keyboard and mouse mode?\n\nThe UI reloads without Blizzard's Gamepad UI. Type /fui pad to switch back."],
    button1 = L["Switch"],
    button2 = L["Cancel"],
    OnAccept = function() SetGamepadMode(false) end,
    macro = SwitchMacro(false),
    OnMacro = function() CheckSwitched(false) end,
    hideOnEscape = true,
}

-- /fui pad
function ns.ToggleGamepadMode()
    if InCombatLockdown() then
        print("|cffff9900FlareUI:|r " .. L["Gamepad mode cannot be switched in combat."])
        return
    end
    ns.ShowDialog(ns.IsGamepadUI() and "FLAREUI_GAMEPAD_OFF" or "FLAREUI_GAMEPAD_ON")
end

--------------------------------------------------
-- 4. THE OFFER
--------------------------------------------------
local function Offer()
    if declined or ns.IsGamepadUI() or ns.AnyDialogShown() or ns.OtherControllerAddon() then return end
    if not ns.db.profile.tweaks.gamepadPrompt then return end   -- Quality of Life's Gamepad mode prompt
    if InCombatLockdown() then pendingOffer = true return end
    ns.ShowDialog("FLAREUI_GAMEPAD_ON")
end

--------------------------------------------------
-- 5. RUMBLE
-- Quality of Life > Controller: the controller rumbles for alerts (the same events as Alert Sounds)
-- and briefly when a spell lights up (Blizzard's action bar proc glow). Only while the controller is
-- what you play with: the Gamepad UI, or a controller press last. A pulse is the vibration sent
-- again every tenth of a second for its length, then stopped.
--------------------------------------------------
local RUMBLE_ALERTS = { READY_CHECK = true, CONFIRM_SUMMON = true, RESURRECT_REQUEST = true,
                        PARTY_INVITE_REQUEST = true, LFG_PROPOSAL_SHOW = true }
local PROC_GAP = 1          -- seconds between two proc rumbles
local pulseTicker, lastProc = nil, 0

local function PadInUse()
    return ns.IsGamepadUI() or padActive == true
end

local function Pulse(kind, strength, seconds)
    if not (C_GamePad and C_GamePad.SetVibration) or not PadInUse() then return end
    if pulseTicker then pulseTicker:Cancel() end
    local left = math.max(1, math.floor(seconds * 10 + 0.5))
    C_GamePad.SetVibration(kind, strength)
    pulseTicker = C_Timer.NewTicker(0.1, function(self)
        left = left - 1
        if left <= 0 then
            self:Cancel()
            pulseTicker = nil
            C_GamePad.StopVibration()
        else
            C_GamePad.SetVibration(kind, strength)
        end
    end)
end

local rumble = CreateFrame("Frame")
for event in pairs(RUMBLE_ALERTS) do rumble:RegisterEvent(event) end
rumble:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
rumble:SetScript("OnEvent", function(_, event, arg1)
    local db = ns.db and ns.db.profile.tweaks
    if not db then return end
    if event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
        if not db.rumbleProcs or GetTime() - lastProc < PROC_GAP then return end
        lastProc = GetTime()
        Pulse("Low", 0.6, 0.2)
        return
    end
    if not db.rumbleAlerts then return end
    -- not for the ready check you started yourself
    if event == "READY_CHECK" and arg1 and canaccessvalue(arg1) and UnitIsUnit("player", arg1) then return end
    Pulse("High", 0.8, 0.5)
end)

--------------------------------------------------
-- 6. EVENTS
--------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        local isInitialLogin = arg1
        armed = isInitialLogin and true or false
        -- after Chat's restored history (a second after login)
        if isInitialLogin then
            C_Timer.After(2, function()
                local version = C_AddOns.GetAddOnMetadata(addonName, "Version") or ""
                print(("|cff00ccffFlareUI|r " .. L["%s by |cffb39ddbMalkkav|r. Type |cffffff00/fui|r for settings."]):format(version))
            end)
        end
        if not ns.IsGamepadUI() then
            self:RegisterEvent("GAME_PAD_ACTIVE_CHANGED")
            self:RegisterEvent("PLAYER_REGEN_ENABLED")
        end
    elseif event == "GAME_PAD_ACTIVE_CHANGED" then
        padActive = arg1
        if not arg1 then
            armed = true
        elseif armed then
            Offer()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- only if the controller is still the last input
        if pendingOffer then
            pendingOffer = false
            if padActive then Offer() end
        end
    end
end)
