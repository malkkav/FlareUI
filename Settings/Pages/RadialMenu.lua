local _, ns = ...
local L = ns.L
local S = ns.Settings

--------------------------------------------------
-- RADIAL MENU (Modules/RadialMenu.lua). Three tabs:
--   Buttons   the radial editor (Settings/RadialEditor.lua, BuildEmbedded), its live preview in
--             the right column
--   Keybinds  one list of keys, each opening a radial on this character. The first is the
--             module's main key (and the radial the controller opens), the rest its extra keys;
--             the player sees no difference.
--   Options   button names, controller support, and the radial macro maker
--------------------------------------------------
local function RM() return ns.RadialMenu end
local function Ready() return RM() and RM().initialized end

-- the radials, in the library's order, as { id, name } choices
local function RadialChoices()
    local list, rm = {}, RM()
    if not rm then return list end
    for _, id in ipairs(rm:GetRadialsByName()) do
        local data = rm:GetRadial(id)
        if data then list[#list + 1] = { id, data.name } end
    end
    return list
end

--------------------------------------------------
-- KEYBINDS TAB
--------------------------------------------------
-- the keys as one list: { key, radial, set key, set radial, remove }
local function Keys()
    local rm = RM()
    local list = {}
    if not rm then return list end
    list[1] = {
        key = rm:GetKey() or "", radial = rm:GetAssignedRadialID(),
        setKey = function(k) rm:SetKey(k) end,
        setRadial = function(id) rm:SetAssignedRadialID(id) end,
        -- the first key goes: the next one takes its place
        remove = function()
            local extra = rm:GetExtraBindings()[1]
            if extra then
                rm:SetKey(extra.key or "")
                rm:SetAssignedRadialID(extra.radial)
                rm:RemoveExtraBinding(1)
            else
                rm:SetKey("")
            end
        end,
    }
    for i, extra in ipairs(rm:GetExtraBindings()) do
        list[#list + 1] = {
            key = extra.key or "", radial = extra.radial,
            setKey = function(k) rm:SetExtraKey(i, k) end,
            setRadial = function(id) rm:SetExtraRadial(i, id) end,
            remove = function() rm:RemoveExtraBinding(i) end,
        }
    end
    return list
end

local KEY_ROW_H, MAX_KEY_ROWS = 32, 6

-- hovering a key fills the right column with what the keys do; leaving gives the module back
local function KeyHover(control)
    control:HookScript("OnEnter", function()
        ns.SettingsPanel:ShowPreview(S:Text("rm.keys", "label") or L["Keybinds"], S:Text("rm.keys", "desc"),
            S:Text("rm.keys", "tip"), "rm.keys", "rm")
    end)
    control:HookScript("OnLeave", function() ns.SettingsPanel:ShowModulePreview() end)
end

local function BuildKeys(host)
    host.rows = {}
    for i = 1, MAX_KEY_ROWS do
        local row = CreateFrame("Frame", nil, host)
        row:SetSize(470, KEY_ROW_H)
        row:SetPoint("TOPLEFT", 0, -8 - (i - 1) * KEY_ROW_H)
        row.key = ns.SettingsPanel.KeyButton(row, function(k) row.entry.setKey(k) ns.SettingsPanel:Refresh() end)
        row.key:SetPoint("LEFT", 4, 0)
        KeyHover(row.key)
        row.radial = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
        row.radial:SetWidth(180)
        row.radial:SetPoint("LEFT", row.key, "RIGHT", 10, 0)
        KeyHover(row.radial)
        row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.remove:SetSize(80, 22)
        row.remove:SetText(L["Remove"])
        row.remove:SetPoint("LEFT", row.radial, "RIGHT", 10, 0)
        row.remove:SetScript("OnClick", function() ns.ButtonSound(); row.entry.remove(); ns.SettingsPanel:Refresh() end)
        host.rows[i] = row
    end
    host.add = CreateFrame("Button", nil, host, "UIPanelButtonTemplate")
    host.add:SetSize(170, 22)
    host.add:SetText(L["+ Add keybind"])
    host.add:SetScript("OnClick", function()
        ns.ButtonSound()
        if RM() then RM():AddExtraBinding() end
        ns.SettingsPanel:Refresh()
    end)
    KeyHover(host.add)
end

local function RefreshKeys(host)
    local keys = Ready() and Keys() or {}
    local radials = RadialChoices()
    local shown = 0
    for i, row in ipairs(host.rows) do
        local entry = keys[i]
        row:SetShown(entry ~= nil)
        if entry then
            shown = i
            row.entry = entry
            if not row.key.waiting then row.key:ShowKey(entry.key) end
            row.radial:SetupMenu(function(_, root)
                for _, r in ipairs(radials) do
                    root:CreateRadio(r[2], function() return entry.radial == r[1] end, function()
                        entry.setRadial(r[1])
                        ns.SettingsPanel:Refresh()
                    end)
                end
            end)
            row.remove:SetEnabled(entry.key ~= "" or i > 1)
        end
    end
    host.add:ClearAllPoints()
    host.add:SetPoint("TOPLEFT", 4, -8 - shown * KEY_ROW_H - 6)
    host.add:SetShown(Ready() and #keys < MAX_KEY_ROWS and #keys - 1 < (RM().MAX_EXTRA_KEYS or 5) or false)
end

--------------------------------------------------
-- MODULE AND TABS
--------------------------------------------------
S:Module{
    key = "rm", group = "Tools", order = 10, enabled = "radialmenu.enabled",
    tabs = {
        {
            key = "buttons", preview = true,
            custom = function(host, previewHost)
                if ns.RadialEditorEmbed then ns.RadialEditorEmbed.Build(host, previewHost) end
            end,
            refresh = function() if ns.RadialEditorEmbed then ns.RadialEditorEmbed.Refresh() end end,
        },
        { key = "keys", custom = BuildKeys, refresh = RefreshKeys },
        { key = "options" },
    },
}

-- the keybind list as a row, for search: its button opens the Keybinds tab (the tab itself draws
-- the list, so the row never shows on the page)
S:Row{
    key = "rm.keys", kind = "button", tab = "keys", buttonText = L["Open"],
    apply = function() ns.SettingsPanel:Open("rm", "keys") end,
}

-- Options: look and controller
S:Row{ key = "rm.names", tab = "options", path = "radialmenu.showNames" }
S:Row{
    key = "rm.pad", tab = "options",
    get = function() return RM() and RM():IsControllerEnabled() or false end,
    set = function(on) if RM() then RM():SetControllerEnabled(on) end end,
}

-- Options: radial macros
local macroRadial
local function MacroRadial()
    local rm = RM()
    if not rm then return nil end
    if not (macroRadial and rm:GetRadial(macroRadial)) then macroRadial = rm:GetAssignedRadialID() or rm:GetRadialOrder()[1] end
    return macroRadial
end
local function MacroLine()
    local id = MacroRadial()
    return id and RM():GetMacroText(id) or ""
end

-- one line: the radial, and Create macro beside it
local function CreateRadialMacro()
    local id = MacroRadial()
    local data = id and RM():GetRadial(id)
    if not data then return end
    if InCombatLockdown() then
        print("|cffff4040FlareUI:|r " .. (S:Text("rm.macroCreate", "errorInCombat") or L["You can't create macros in combat."]))
        return
    end
    local _, perCharacter = GetNumMacros()
    if perCharacter >= (MAX_CHARACTER_MACROS or 18) then
        print("|cffff4040FlareUI:|r " .. (S:Text("rm.macroCreate", "errorMacrosFull") or L["Your macro list is full. Delete one and try again."]))
        return
    end
    local name = ("FUI " .. data.name):sub(1, 16)
    local index = CreateMacro(name, "INV_MISC_QUESTIONMARK", MacroLine(), true)
    if index then
        PickupMacro(index)
        local done = S:Text("rm.macroCreate", "done") or L["Macro \"{name}\" created and on your cursor. Drop it on a bar."]
        print("|cff00ccffFlareUI:|r " .. done:gsub("{name}", name))
    end
end
S:Row{
    key = "rm.macroRadial", kind = "dropdown", tab = "options", section = "rm.radialMacros",
    choices = RadialChoices, dropdownWidth = 180,
    get = MacroRadial, set = function(id) macroRadial = id end,
    sideButtons = { right = { text = S:Text("rm.macroCreate", "label") or L["Create macro"], width = 130, onClick = CreateRadialMacro } },
}
