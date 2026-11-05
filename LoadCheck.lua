local _, ns = ...

--------------------------------------------------
-- LOAD CHECK
-- First in the TOC and needs nothing else, so it still runs when other files didn't load: a player
-- reported FlareUI listed in game, /fui doing nothing and LibSharedMedia missing, until a reinstall.
-- Without the libraries most files stop on their first lines and the errors stay hidden.
--------------------------------------------------
local LIBRARIES = {
    "CallbackHandler-1.0", "AceDB-3.0", "AceEvent-3.0", "AceTimer-3.0", "AceHook-3.0",
    "LibSharedMedia-3.0", "FlareEditMode",
}

local function FilesLoaded()
    if not LibStub then return false end
    for _, name in ipairs(LIBRARIES) do
        if not LibStub(name, true) then return false end
    end
    -- the saved settings, and the settings panel (the TOC's last file)
    return ns.db ~= nil and ns.SettingsPanel ~= nil
end

local function ShowMessage()
    -- (Locales may be among the files that didn't load)
    local L = ns.L or setmetatable({}, { __index = function(_, key) return key end })
    print("|cffff4040FlareUI:|r " .. L["FlareUI's files didn't load completely. Restart the game. If this keeps happening, reinstall FlareUI."])
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    -- next frame: after every file's own login code, /fui's included
    C_Timer.After(0, function()
        if FilesLoaded() then return end
        ShowMessage()
        SLASH_FLAREUI1 = "/flareui"
        SLASH_FLAREUI2 = "/fui"
        SlashCmdList.FLAREUI = ShowMessage
    end)
end)
