local _, ns = ...
local L = ns.L
local S = ns.Settings

--------------------------------------------------
-- PROFILES
-- Switch, create, duplicate or delete a profile, and reset FlareUI. A profile switch asks for a
-- reload (Core.lua OnProfileChanged).
--------------------------------------------------
-- a trimmed, unused profile name or nil (SetProfile on an existing name would switch to it)
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

-- the copy takes the current profile's settings and becomes current
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

--------------------------------------------------
-- SHARE
-- A profile as one line of text: Blizzard's own pipeline (as Cooldown Manager strings) of CBOR,
-- Deflate and Base64 behind a "FlareUI1:" tag. Only the profile's own changes travel (AceDB keeps
-- defaults out of the saved table); an import becomes a new profile.
--------------------------------------------------
local SHARE_TAG = "FlareUI1:"

local function ExportString()
    local name = ns.db and ns.db:GetCurrentProfile()
    local saved = name and ns.db.sv and ns.db.sv.profiles and ns.db.sv.profiles[name]
    if not saved then return "" end
    local payload = { addon = "FlareUI", name = name, profile = saved,
        version = C_AddOns.GetAddOnMetadata("FlareUI", "Version") }
    local ok, text = pcall(function()
        local cbor = C_EncodingUtil.SerializeCBOR(payload)
        return C_EncodingUtil.EncodeBase64(C_EncodingUtil.CompressString(cbor, Enum.CompressionMethod.Deflate))
    end)
    return ok and text and (SHARE_TAG .. text) or ""
end

-- the payload, or nil and why not
local function ReadString(text)
    text = text and strtrim(text) or ""
    if text:sub(1, #SHARE_TAG) ~= SHARE_TAG then return nil end
    local ok, payload = pcall(function()
        local packed = C_EncodingUtil.DecodeBase64(text:sub(#SHARE_TAG + 1))
        return C_EncodingUtil.DeserializeCBOR(C_EncodingUtil.DecompressString(packed, Enum.CompressionMethod.Deflate))
    end)
    if not (ok and type(payload) == "table" and payload.addon == "FlareUI" and type(payload.profile) == "table") then
        return nil
    end
    return payload
end

-- the shared name, or with " (2)", " (3)"... when taken
local function ImportName(base)
    base = (type(base) == "string" and strtrim(base) ~= "") and strtrim(base):sub(1, 28) or L["Imported"]
    local taken = {}
    for _, name in ipairs(ns.db:GetProfiles() or {}) do taken[name] = true end
    if not taken[base] then return base end
    local n = 2
    while taken[("%s (%d)"):format(base, n)] do n = n + 1 end
    return ("%s (%d)"):format(base, n)
end

ns.Dialogs["FLAREUI_EXPORT_PROFILE"] = {
    text = L["Copy this text (Ctrl+C) to share the profile |cffffff00%s|r."],
    button1 = L["Close"],
    hasEditBox = true,
    editText = function() return ExportString() end,
    hideOnEscape = true,
}

ns.Dialogs["FLAREUI_IMPORT_PROFILE"] = {
    text = L["Paste a FlareUI profile string (Ctrl+V). It becomes a new profile."],
    button1 = L["Import"],
    button2 = L["Cancel"],
    hasEditBox = true,
    OnAccept = function(_, text)
        local payload = ReadString(text)
        if not (payload and ns.db and ns.db.sv) then
            UIErrorsFrame:AddMessage(L["That isn't a FlareUI profile string."], 1, 0.1, 0.1)
            return
        end
        local name = ImportName(payload.name)
        ns.db.sv.profiles = ns.db.sv.profiles or {}
        ns.db.sv.profiles[name] = payload.profile
        ns.db:SetProfile(name)
    end,
    hideOnEscape = true,
}

local function Profiles()
    local list = {}
    if not ns.db then return list end
    local names = ns.db:GetProfiles() or {}
    table.sort(names)
    for _, name in ipairs(names) do list[#list + 1] = { name, name } end
    return list
end

-- the profiles that can be deleted (all but the current one)
local function Others()
    local list, current = {}, ns.db and ns.db:GetCurrentProfile()
    for _, p in ipairs(Profiles()) do
        if p[1] ~= current then list[#list + 1] = p end
    end
    return list
end

S:Module{
    key = "adv", group = "top", order = 2,
    navIcon = "Interface\\Icons\\INV_Misc_Note_01", navIconRound = true,
}

-- the profile dropdown spans the width of the New / Duplicate / Delete buttons under it
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

-- Export / Import: two buttons as wide as the three above
local SHARE_W = (BUTTON_W * 3 + BUTTON_GAP) / 2
S:Row{
    key = "adv.share", kind = "buttons", labelFn = function() return "" end, gapAbove = 12,
    buttons = {
        { text = L["Export"], width = SHARE_W, onClick = function()
              local current = ns.db and ns.db:GetCurrentProfile()
              if current then ns.ShowDialog("FLAREUI_EXPORT_PROFILE", current) end
          end },
        { text = L["Import"], width = SHARE_W, onClick = function() ns.ShowDialog("FLAREUI_IMPORT_PROFILE") end },
    },
}

S:Row{ key = "adv.reset", kind = "button", center = true, section = "adv.reset",
    apply = function() ns.ShowDialog("FLAREUI_RESET") end }
