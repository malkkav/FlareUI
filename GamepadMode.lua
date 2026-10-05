local addonName, ns = ...
local L = ns.L

--------------------------------------------------
-- GAMEPAD MODE
-- Blizzard's Gamepad UI is the CVar InputDeviceInterfaceStyle (Settings > Gamepad > Enable Gamepad
-- UI); changing it reloads the whole UI. Blizzard's own /console sets CVars from insecure code
-- (SlashCommands.lua: forceinsecure + ConsoleExec), so FlareUI can set it the same way.
--   * With keyboard and mouse, the first press on a controller (GAME_PAD_ACTIVE_CHANGED) offers the
--     switch, once a session, never in combat (Tweaks > Convenience > Offer Gamepad Mode).
--   * /fui pad asks to switch either way.
--   * After a switch, by FlareUI or by Blizzard's setting, chat says which mode is on.
-- Also the login line in chat.
--------------------------------------------------
local GAMEPAD, MKB = 1, 0           -- Enum.InputDeviceInterfaceType.Gamepad / .Mkb
local CVAR = "InputDeviceInterfaceStyle"

local declined, pendingOffer, padActive
-- After a reload the client reports the controller as the active device again if it was the last one
-- used (the switch back to keyboard is often confirmed with A), so the offer waits for one keyboard or
-- mouse input first. A fresh login starts armed.
local armed

local function CheckSwitched(on)
    -- the switch reloads the UI; still here a moment later means it did not go through
    C_Timer.After(1, function()
        if ns.IsGamepadUI() ~= on then
            print("|cffff9900FlareUI:|r " .. L["The switch did not go through. Use Blizzard's Settings > Gamepad > Enable Gamepad UI."])
        end
    end)
end

-- the pad's A answer (and Answer in general): FlareUI's own call, which the client allows from a
-- controller press but blocks from a mouse click
local function SetGamepadMode(on)
    if InCombatLockdown() then
        print("|cffff9900FlareUI:|r " .. L["Gamepad mode cannot be switched in combat."])
        return
    end
    SetCVar(CVAR, on and GAMEPAD or MKB)
    CheckSwitched(on)
end

-- a click or Enter goes through the dialog's secure button, which runs this as Blizzard's /run
local function SwitchMacro(on)
    return ('/run SetCVar("%s", %d)'):format(CVAR, on and GAMEPAD or MKB)
end

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
    padInput = true,    -- answered with the controller that brought it up
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

local function OfferEnabled()
    local tweaks = ns.db and ns.db.profile and ns.db.profile.tweaks
    return not tweaks or tweaks.offerGamepad ~= false
end

local function Offer()
    if declined or ns.IsGamepadUI() or not OfferEnabled() or ns.AnyDialogShown() then return end
    if InCombatLockdown() then pendingOffer = true return end
    ns.ShowDialog("FLAREUI_GAMEPAD_ON")
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        local isInitialLogin = arg1
        armed = isInitialLogin and true or false
        local isGamepad = ns.IsGamepadUI()
        -- after Chat's history (restored a second after login), so it comes last
        if isInitialLogin then
            C_Timer.After(2, function()
                local version = C_AddOns.GetAddOnMetadata(addonName, "Version") or ""
                print(("|cff00ccffFlareUI|r " .. L["%s by |cffb39ddbMalkkav|r. Type |cffffff00/fui|r for settings."]):format(version))
            end)
        end
        if not isGamepad then
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
        -- only if the controller is still the last thing used
        if pendingOffer then
            pendingOffer = false
            if padActive then Offer() end
        end
    end
end)
