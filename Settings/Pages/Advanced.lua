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

-- Renames the profile in use: its saved table moves to the new name, so nothing reloads. Every
-- character that chose the old name follows it.
ns.Dialogs["FLAREUI_RENAME_PROFILE"] = {
    text = L["Rename the profile |cffffff00%s|r."],
    button1 = L["Rename"],
    button2 = L["Cancel"],
    hasEditBox = true,
    maxLetters = 32,
    editText = function(data) return data and data.from or "" end,
    OnAccept = function(data, text)
        local old = data and data.from
        local db = ns.db
        if not (old and db and db.sv and db.keys and db.keys.profile == old) then return end
        if text and strtrim(text) == old then return end
        local new = FreeName(text)
        if not new then return end
        local sv = db.sv
        sv.profiles = sv.profiles or {}
        sv.profiles[new], sv.profiles[old] = sv.profiles[old], nil
        db.keys.profile = new
        for key, name in pairs(sv.profileKeys or {}) do
            if name == old then sv.profileKeys[key] = new end
        end
        for _, entry in pairs(db.global and db.global.characters or {}) do
            if type(entry) == "table" and entry.profileName == old then entry.profileName = new end
        end
        if ns.SettingsPanel then ns.SettingsPanel:Refresh() end
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
-- Deflate and Base64 behind a "FlareUI1:" tag. Only the profile's changes from the defaults travel
-- (in play AceDB keeps the defaults in the saved table, until logout); an import becomes a new profile.
--------------------------------------------------
local SHARE_TAG = "FlareUI1:"

-- A shared string is anyone's text. At every level: a key whose type differs from its default goes
-- back to the default; numbers must be finite and within reason (up to spell and item IDs, counts
-- within their sliders); strings are kept short; nesting and size have limits. Keys the defaults
-- don't name (saved layouts, styles) stay, with the same checks on what they hold.
local MAX_NUMBER, MAX_STRING, MAX_DEPTH, MAX_NODES = 1e8, 512, 12, 50000
local COUNT_LIMITS = { max = 100, perRow = 100, rows = 100, columns = 100 }

local function Sanitize(profile, defaults, depth, budget)
    for key, value in pairs(profile) do
        budget.nodes = budget.nodes + 1
        local default = type(defaults) == "table" and defaults[key] or nil
        local kind = type(value)
        local keep = budget.nodes <= MAX_NODES and (type(key) == "string" or type(key) == "number")
        if keep and default ~= nil and kind ~= type(default) then keep = false end
        if keep then
            if kind == "number" then
                local limit = COUNT_LIMITS[key] or MAX_NUMBER
                keep = value == value and value >= -MAX_NUMBER and value <= limit
            elseif kind == "string" then
                keep = #value <= MAX_STRING
            elseif kind == "table" then
                keep = depth < MAX_DEPTH
                if keep then Sanitize(value, default, depth + 1, budget) end
            else
                keep = kind == "boolean"
            end
        end
        if not keep then profile[key] = nil end
    end
end

local function DropWrongTypes(profile, defaults)
    Sanitize(profile, defaults, 1, { nodes = 0 })
end

local function ExportString()
    local name = ns.db and ns.db:GetCurrentProfile()
    local saved = name and ns.db.sv and ns.db.sv.profiles and ns.db.sv.profiles[name]
    if not saved then return "" end
    local payload = { addon = "FlareUI", name = name,
        -- only the changes; AceDB's "*" and "**" sections aren't compared, so they travel whole
        profile = ns.ProfileChanges(saved, ns.defaults and ns.defaults.profile or {}),
        version = C_AddOns.GetAddOnMetadata("FlareUI", "Version"), uiScale = UIParent:GetScale() }
    local ok, text = pcall(function()
        local cbor = C_EncodingUtil.SerializeCBOR(payload)
        return C_EncodingUtil.EncodeBase64(C_EncodingUtil.CompressString(cbor, Enum.CompressionMethod.Deflate))
    end)
    return ok and text and (SHARE_TAG .. text) or ""
end

-- the payload, or nil
local MAX_TEXT, MAX_DATA = 256 * 1024, 4 * 1024 * 1024
local function ReadString(text)
    text = text and strtrim(text) or ""
    if text:sub(1, #SHARE_TAG) ~= SHARE_TAG or #text > MAX_TEXT then return nil end
    local ok, payload = pcall(function()
        local packed = C_EncodingUtil.DecodeBase64(text:sub(#SHARE_TAG + 1))
        local data = C_EncodingUtil.DecompressString(packed, Enum.CompressionMethod.Deflate)
        if type(data) ~= "string" or #data > MAX_DATA then return nil end
        return C_EncodingUtil.DeserializeCBOR(data)
    end)
    if not (ok and type(payload) == "table" and payload.addon == "FlareUI" and type(payload.profile) == "table") then
        return nil
    end
    return payload
end

-- the shared name, or with " (2)", " (3)"... when taken
local function ImportName(base)
    base = (type(base) == "string" and strtrim(base) ~= "") and strtrim(base) or L["Imported"]
    -- at most 28 bytes, cut between characters (never inside a multi-byte one)
    if #base > 28 then
        local cut = 28
        while cut > 0 and base:byte(cut + 1) and base:byte(cut + 1) >= 0x80 and base:byte(cut + 1) < 0xC0 do cut = cut - 1 end
        base = base:sub(1, cut)
    end
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

--------------------------------------------------
-- IMPORT PREVIEW
-- After a string is pasted: which parts to take, as a new profile or into this one, with the
-- FlareUI version and UI scale it was made with, and the fonts and textures it names that this
-- game doesn't have.
--------------------------------------------------
-- saved roots of each part (a module's own, plus the ones that serve it)
local EXTRA_ROOTS = { ab = { "fcm", "visibility" } }

-- { title, roots } for every part the profile holds, in the panel's module order
local function ImportParts(profile)
    local parts, byRoot = {}, {}
    for _, key in ipairs(S.order or {}) do
        local module = S.modules[key]
        local root = module and type(module.enabled) == "string" and module.enabled:match("^([^.]+)")
        if root then
            local part = byRoot[root]
            if not part then
                part = { titles = {}, roots = {} }
                byRoot[root] = part
                parts[#parts + 1] = part
                part.roots[#part.roots + 1] = root
                for _, extra in ipairs(EXTRA_ROOTS[key] or {}) do
                    part.roots[#part.roots + 1] = extra
                    byRoot[extra] = part
                end
            end
            part.titles[#part.titles + 1] = module:Title() or key
        end
    end
    local out = {}
    for _, part in ipairs(parts) do
        for _, root in ipairs(part.roots) do
            if profile[root] ~= nil then
                part.title = table.concat(part.titles, ", ")
                out[#out + 1] = part
                break
            end
        end
    end
    -- anything else the string holds comes as one more part
    local rest = { title = L["Other settings"], roots = {} }
    for root in pairs(profile) do
        if not byRoot[root] then rest.roots[#rest.roots + 1] = root end
    end
    if #rest.roots > 0 then out[#out + 1] = rest end
    return out
end

-- media names the profile asks for that LibSharedMedia doesn't know here
local MEDIA_FIELDS = {
    face = "font", font = "font",
    texture = "statusbar", barTexture = "statusbar", statusbar = "statusbar",
    borderTexture = "border", border = "border",
    background = "background", backgroundTexture = "background",
}
local function MissingMedia(profile, roots)
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if not LSM then return {} end
    local missing, seen = {}, {}
    local function Walk(t, depth)
        if depth > 12 then return end
        for key, value in pairs(t) do
            if type(value) == "table" then
                Walk(value, depth + 1)
            elseif type(value) == "string" and MEDIA_FIELDS[key] and value ~= "" and value ~= "None" then
                local kind = MEDIA_FIELDS[key]
                if not seen[kind .. value] and not LSM:IsValid(kind, value) then
                    seen[kind .. value] = true
                    missing[#missing + 1] = value
                end
            end
        end
    end
    for _, root in ipairs(roots) do
        if type(profile[root]) == "table" then Walk(profile[root], 1) end
    end
    table.sort(missing)
    return missing
end

-- "4.3.2" against this FlareUI's: true when the string's is newer
local function Newer(theirs)
    local mine = C_AddOns.GetAddOnMetadata("FlareUI", "Version") or ""
    if type(theirs) ~= "string" then return false end
    local a, b = {}, {}
    for n in theirs:gmatch("%d+") do a[#a + 1] = tonumber(n) end
    for n in mine:gmatch("%d+") do b[#b + 1] = tonumber(n) end
    for i = 1, math.max(#a, #b) do
        local x, y = a[i] or 0, b[i] or 0
        if x ~= y then return x > y end
    end
    return false
end

local picker
local function BuildPicker()
    local f = CreateFrame("Frame", "FlareUI_ImportPicker", UIParent, "BackdropTemplate")
    f:SetSize(380, 200)
    f:SetPoint("CENTER", 0, 60)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    f:SetBackdropBorderColor(0.6, 0.5, 0.3, 1)
    tinsert(UISpecialFrames, "FlareUI_ImportPicker")

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOP", 0, -14)
    f.title:SetText(L["Import profile"])
    f.info = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.info:SetPoint("TOP", f.title, "BOTTOM", 0, -6)
    f.info:SetWidth(340)

    f.checks = {}
    f.newRadio = CreateFrame("CheckButton", nil, f, "UIRadioButtonTemplate")
    f.newRadio.text:SetText(L["As a new profile:"])
    f.intoRadio = CreateFrame("CheckButton", nil, f, "UIRadioButtonTemplate")
    f.intoRadio.text:SetText(L["Into this profile (the ticked parts are replaced)"])
    f.name = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    f.name:SetSize(150, 20)
    f.name:SetAutoFocus(false)
    f.name:SetMaxLetters(32)
    local function Mode(into)
        f.into = into
        f.newRadio:SetChecked(not into)
        f.intoRadio:SetChecked(into)
        f.name:SetEnabled(not into)
    end
    f.newRadio:SetScript("OnClick", function() Mode(false) end)
    f.intoRadio:SetScript("OnClick", function() Mode(true) end)
    f.Mode = Mode

    f.missing = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.missing:SetWidth(340)
    f.missing:SetJustifyH("LEFT")
    f.missing:SetTextColor(1, 0.6, 0.2)

    f.import = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.import:SetSize(110, 22)
    f.import:SetText(L["Import"])
    f.cancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.cancel:SetSize(110, 22)
    f.cancel:SetText(L["Cancel"])
    f.cancel:SetScript("OnClick", function() f:Hide() end)
    f.import:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -4, 12)
    f.cancel:SetPoint("BOTTOMLEFT", f, "BOTTOM", 4, 12)
    f:Hide()
    return f
end

local function ChosenRoots(f)
    local roots = {}
    for _, check in ipairs(f.checks) do
        if check:IsShown() and check:GetChecked() then
            for _, root in ipairs(check.part.roots) do roots[#roots + 1] = root end
        end
    end
    return roots
end

local function UpdateMissing(f)
    local missing = MissingMedia(f.payload.profile, ChosenRoots(f))
    if #missing > 0 then
        f.missing:SetText(L["Not on this computer (FlareUI's default is used): %s"]:format(table.concat(missing, ", ")))
    else
        f.missing:SetText("")
    end
end

-- A part's changes laid over a copy of its defaults: the running modules read whole settings until
-- the reload. A list in the changes comes whole, as ns.ProfileChanges sends it.
local function WithDefaults(changes, defaults)
    if type(defaults) ~= "table" then return changes end
    if changes == nil then return CopyTable(defaults) end
    if type(changes) ~= "table" or changes[1] ~= nil then return changes end
    local out = CopyTable(defaults)
    for key, value in pairs(changes) do out[key] = WithDefaults(value, defaults[key]) end
    return out
end

function ns.ShowImportPicker(payload)
    picker = picker or BuildPicker()
    local f = picker
    f.payload = payload
    local profile = payload.profile

    -- made with: version (orange when newer than this FlareUI) and UI scale
    local bits = {}
    if type(payload.version) == "string" then
        local text = L["Made with FlareUI %s"]:format(payload.version)
        if Newer(payload.version) then text = "|cffff9933" .. text .. " (" .. L["newer than yours"] .. ")|r" end
        bits[#bits + 1] = text
    end
    if type(payload.uiScale) == "number" then
        bits[#bits + 1] = L["UI scale %.2f (yours %.2f)"]:format(payload.uiScale, UIParent:GetScale())
    end
    f.info:SetText(table.concat(bits, "  ·  "))

    -- one box per part, all ticked
    for _, check in ipairs(f.checks) do
        check:Hide()
        check.label:Hide()
    end
    local y = -54
    for i, part in ipairs(ImportParts(profile)) do
        local check = f.checks[i]
        if not check then
            check = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
            check:SetSize(22, 22)
            check.label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            check.label:SetPoint("LEFT", check, "RIGHT", 2, 0)
            check:SetScript("OnClick", function() UpdateMissing(f) end)
            f.checks[i] = check
        end
        check.part = part
        check.label:SetText(part.title)
        check:ClearAllPoints()
        check:SetPoint("TOPLEFT", 20, y)
        check:SetChecked(true)
        check:Show()
        check.label:Show()
        y = y - 24
    end

    y = y - 6
    f.newRadio:ClearAllPoints()
    f.newRadio:SetPoint("TOPLEFT", 20, y)
    f.name:ClearAllPoints()
    f.name:SetPoint("LEFT", f.newRadio.text, "RIGHT", 10, 0)
    f.name:SetText(ImportName(payload.name))
    y = y - 22
    f.intoRadio:ClearAllPoints()
    f.intoRadio:SetPoint("TOPLEFT", 20, y)
    y = y - 26
    f.missing:ClearAllPoints()
    f.missing:SetPoint("TOPLEFT", 22, y)
    f.Mode(false)
    UpdateMissing(f)
    f:SetHeight(-y + 30 + math.max(14, f.missing:GetStringHeight()) + 20)

    f.import:SetScript("OnClick", function()
        local roots = ChosenRoots(f)
        if #roots == 0 then return end
        local chosen = {}
        for _, root in ipairs(roots) do chosen[root] = profile[root] end
        DropWrongTypes(chosen, ns.defaults and ns.defaults.profile or {})
        if f.into then
            -- the ticked parts replace this profile's; the rest stays as it is
            local current = ns.db:GetCurrentProfile()
            local saved = ns.db.sv.profiles and ns.db.sv.profiles[current]
            if not saved then return end
            local defaults = ns.defaults and ns.defaults.profile or {}
            for _, root in ipairs(roots) do saved[root] = WithDefaults(chosen[root], defaults[root]) end
            f:Hide()
            ns.ShowDialog("FLAREUI_RELOAD")
        else
            local name = FreeName(f.name:GetText())
            if not name then return end
            ns.db.sv.profiles = ns.db.sv.profiles or {}
            ns.db.sv.profiles[name] = chosen
            f:Hide()
            ns.db:SetProfile(name)
        end
    end)
    f:Show()
end

ns.Dialogs["FLAREUI_IMPORT_PROFILE"] = {
    text = L["Paste a FlareUI profile string (Ctrl+V). It becomes a new profile."],
    button1 = L["Next"],
    button2 = L["Cancel"],
    hasEditBox = true,
    OnAccept = function(_, text)
        local payload = ReadString(text)
        if not (payload and ns.db and ns.db.sv) then
            UIErrorsFrame:AddMessage(L["That isn't a FlareUI profile string."], 1, 0.1, 0.1)
            return
        end
        -- the next step after this dialog closes
        C_Timer.After(0, function() ns.ShowImportPicker(payload) end)
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

-- the profile dropdown spans the width of the New / Rename / Duplicate / Delete buttons under it
local BUTTON_W, BUTTON_GAP = 108, 6
local MANAGE_W = (BUTTON_W * 3 + BUTTON_GAP * 2 - BUTTON_GAP * 3) / 4

S:Row{
    key = "adv.profiles", kind = "dropdown", choices = Profiles, dropdownWidth = BUTTON_W * 3 + BUTTON_GAP * 2,
    get = function() return ns.db and ns.db:GetCurrentProfile() end,
    set = function(name) if ns.db and name ~= ns.db:GetCurrentProfile() then ns.db:SetProfile(name) end end,
}

S:Row{
    key = "adv.manage", kind = "buttons", labelFn = function() return "" end,
    buttons = {
        { text = L["New"], width = MANAGE_W, onClick = function() ns.ShowDialog("FLAREUI_NEW_PROFILE") end },
        { text = L["Rename"], width = MANAGE_W, onClick = function()
              local current = ns.db and ns.db:GetCurrentProfile()
              if current then ns.ShowDialog("FLAREUI_RENAME_PROFILE", current, { from = current }) end
          end },
        { text = L["Duplicate"], width = MANAGE_W, onClick = function()
              local current = ns.db and ns.db:GetCurrentProfile()
              if current then ns.ShowDialog("FLAREUI_DUPLICATE_PROFILE", current, { from = current }) end
          end },
        -- its list is a Blizzard menu, which hangs the client when addon code opens it in the Gamepad UI
        { text = L["Delete"], width = MANAGE_W, disabled = function() return #Others() == 0 or ns.IsGamepadUI() end,
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
