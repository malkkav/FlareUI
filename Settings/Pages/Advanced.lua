local _, ns = ...
local L = ns.L
local S = ns.Settings

--------------------------------------------------
-- PROFILES (under About, at the top of the list): switch, make, duplicate or delete a profile; reset FlareUI. A switch
-- reloads the UI (Core.lua OnProfileChanged). Sync Blizz UI lives in Quality of Life.
--------------------------------------------------
-- a new profile's name: trimmed, not empty and not one already in use (SetProfile would switch to it)
local function FreeName(text)
    text = text and strtrim(text) or ""
    if text == "" or not ns.db then return nil end
    for _, name in ipairs(ns.db:GetProfiles() or {}) do
        if name == text then
            UIErrorsFrame:AddMessage(L["There's already a profile with that name."], 1, 0.1, 0.1)
            return nil
        end
    end
    return text
end

ns.Dialogs["FLAREUI_NEW_PROFILE"] = {
    text = L["Name the new profile. It starts from FlareUI's defaults."],
    button1 = L["Create"],
    button2 = L["Cancel"],
    hasEditBox = true,
    maxLetters = 32,
    OnAccept = function(_, text)
        text = FreeName(text)
        if text then ns.db:SetProfile(text) end
    end,
    hideOnEscape = true,
}

-- the copy starts with the settings of the profile in use, then becomes the one in use
ns.Dialogs["FLAREUI_DUPLICATE_PROFILE"] = {
    text = L["Name the copy of |cffffff00%s|r."],
    button1 = L["Duplicate"],
    button2 = L["Cancel"],
    hasEditBox = true,
    maxLetters = 32,
    OnAccept = function(data, text)
        text = FreeName(text)
        if not (text and data and data.from) then return end
        ns.db:SetProfile(text)
        ns.db:CopyProfile(data.from)
    end,
    hideOnEscape = true,
}

ns.Dialogs["FLAREUI_DELETE_PROFILE"] = {
    text = L["Delete the profile |cffffff00%s|r?"],
    button1 = L["Delete"],
    button2 = L["Cancel"],
    OnAccept = function(data)
        if data and data.name and ns.db then pcall(ns.db.DeleteProfile, ns.db, data.name, true) end
        if ns.SettingsPanel then ns.SettingsPanel:Refresh() end
    end,
    hideOnEscape = true,
    showAlert = true,
}

local function Profiles()
    local list = {}
    if not ns.db then return list end
    local names = ns.db:GetProfiles() or {}
    table.sort(names)
    for _, name in ipairs(names) do list[#list + 1] = { name, name } end
    return list
end

-- the profiles other than the one in use: the ones that can be deleted
local function Others()
    local list, current = {}, ns.db and ns.db:GetCurrentProfile()
    for _, p in ipairs(Profiles()) do
        if p[1] ~= current then list[#list + 1] = p end
    end
    return list
end

S:Module{
    key = "adv", group = "top", order = 2,   -- right under About
    navIcon = "Interface\\Icons\\INV_Misc_Note_01", navIconRound = true,   -- a note of saved settings
}

-- The profile in use on its own line, and under it what can be done with profiles, as one block of
-- the same width: New (from defaults), Duplicate (from the one in use), Delete (a menu of the
-- profiles that can go, not the one in use, then a question).
local BUTTON_W, BUTTON_GAP = 108, 6

S:Row{
    key = "adv.profiles", kind = "dropdown", choices = Profiles, dropdownWidth = BUTTON_W * 3 + BUTTON_GAP * 2,
    get = function() return ns.db and ns.db:GetCurrentProfile() end,
    set = function(name) if ns.db and name ~= ns.db:GetCurrentProfile() then ns.db:SetProfile(name) end end,
}

S:Row{
    key = "adv.manage", kind = "buttons", labelFn = function() return "" end,
    buttons = {
        { text = L["New"], width = BUTTON_W, onClick = function() ns.ShowDialog("FLAREUI_NEW_PROFILE") end },
        { text = L["Duplicate"], width = BUTTON_W, onClick = function()
              local current = ns.db and ns.db:GetCurrentProfile()
              if current then ns.ShowDialog("FLAREUI_DUPLICATE_PROFILE", current, { from = current }) end
          end },
        { text = L["Delete"], width = BUTTON_W, disabled = function() return #Others() == 0 end,
          onClick = function(button)
              MenuUtil.CreateContextMenu(button, function(_, root)
                  for _, other in ipairs(Others()) do
                      root:CreateButton(other[2], function()
                          ns.ShowDialog("FLAREUI_DELETE_PROFILE", other[1], { name = other[1] })
                      end)
                  end
              end)
          end },
    },
}

-- Reset, alone at the bottom
S:Row{ key = "adv.reset", kind = "button", center = true, section = "adv.reset",
    apply = function() ns.ShowDialog("FLAREUI_RESET") end }
