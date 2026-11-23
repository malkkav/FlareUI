-- The embedded editor drives Radial Menu data through the settings panel.
local setup = dofile("tools/tests/fixtures/settings-addon.lua")
local ui, ns = setup()
local E, S = ui.env, ns.Settings
local store = { radials = {
    [1] = { name = "Utility", scope = "", buttons = { { kind = "spell", id = 101 } }, key = "F" },
    [2] = { name = "Travel", scope = "class:MAGE", buttons = {}, key = "G", group = 1 },
    [3] = { name = "Bank", scope = "faction:Horde", buttons = { { kind = "subradial", radial = 1 } }, key = "H" },
}, radialOrder = { 1, 2, 3 }, groups = { [1] = { name = "Road", open = true } }, nextRadialID = 4, nextGroupID = 2 }
local character, cursor, preview, changes = { radialKeyOverride = {} }, nil, nil, 0
local messages, macros, macroPicked = {}, {}, nil
local RM = {
    MAX_BUTTONS = 8, QUEST_ITEMS_ICON = 134400,
    MICRO_PANELS = { Character = { order = 2 }, Bags = { order = 1 } },
}
ns.RadialMenu = RM
ns.KeyText = function(key) return key ~= "" and key or "Unbound" end
ns.ParsePadCombo = function() return nil end
ns.CharDB = function() return character end
ns.PlayerGUID = function() return "Player-1" end
E.UnitClass = function() return "Mage", "MAGE" end
E.UnitFactionGroup = function() return "Alliance", "Alliance" end
E.UnitName = function() return "Tester" end
E.print = function(text) messages[#messages + 1] = text end
E.GetBindingAction = function(key) return key == "R" and "REPLY" or "" end
E.GetBindingName = function(action) return action == "REPLY" and "Reply to Whisper" or action end
E.GetCursorInfo = function() if cursor then return unpack(cursor, 1, 4) end end
E.ClearCursor = function() cursor = nil end
E.C_Spell = {
    GetSpellName = function(id) return ({ [101] = "Frostbolt", [102] = "Heal", [103] = "Growl", [11611] = "Alchemy", [818] = "Basic Campfire" })[id] end,
    GetSpellTexture = function(id) return id + 1000 end,
    GetSpellSubtext = function() return "Rank 3" end,
    IsSpellHelpful = function(id) return id == 102 end,
}
E.Enum.SpellBookSpellBank = { Player = 0, Pet = 1 }
E.Enum.SpellBookItemType = { FutureSpell = 1, PetAction = 2 }
E.C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 2 end,
    GetSpellBookSkillLineInfo = function(line)
        return line == 1 and { numSpellBookItems = 3, itemIndexOffset = 0 } or { offSpecID = 4 }
    end,
    GetSpellBookItemInfo = function(slot, bank)
        if bank == 1 then return { spellID = 103, itemType = 2 } end
        return ({ { spellID = 101 }, { spellID = 102 }, { spellID = 104, itemType = 1 } })[slot]
    end,
    HasPetSpells = function() return 1 end,
}
ns.IsPlayerSpell = function(id) return id == 11611 or id == 818 end
E.Constants = { MacroConsts = { MAX_ACCOUNT_MACROS = 120, MAX_CHARACTER_MACROS = 18 } }
E.GetNumMacros = function() return 1, 1 end
E.GetMacroInfo = function(index)
    if index == 1 then return "Account", 234, "/say Account"
    elseif index == 121 then return "Character", 235, "/say Character" end
end
E.CreateMacro = function(name, icon, body, perCharacter)
    macros[#macros + 1] = { name = name, icon = icon, body = body, perCharacter = perCharacter }
    return 122
end
E.PickupMacro = function(index) macroPicked = index end
E.C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and 2 or 0 end,
    GetContainerItemInfo = function() return { itemID = 10 } end,
}
E.C_MountJournal = {
    GetMountIDs = function() return { 1, 2 } end,
    GetMountInfoByID = function(id) return "Horse", nil, 20, nil, nil, nil, nil, nil, nil, nil, id == 1 end,
}
E.C_ToyBox = {
    GetNumFilteredToys = function() return 1 end,
    GetToyFromIndex = function() return 300 end,
    GetToyInfo = function() return 300, "Whistle", 32 end,
}
E.PlayerHasToy = function(id) return id == 300 end
function RM.GetStore() return store end
function RM.SplitScope(scope) return (scope or ""):match("^(%a+):(.+)$") end
function RM:GetScopeChoices() return { "", "class:MAGE", "char:Player-1" } end
function RM:GetDefaultRadialID() return 1 end
function RM:GetRadial(id) return store.radials[id] end
function RM:GetRadialOrder() return store.radialOrder end
function RM:GetRadialsByName() return { 3, 2, 1 } end
function RM:IsRadialAvailable(id) return store.radials[id].scope ~= "faction:Horde" end
function RM:GetRadialKey(id) return character.radialKeyOverride[id] or store.radials[id].key end
function RM:GetSharedKey(id) return store.radials[id].key end
function RM:SetRadialKey(id, key)
    if character.radialKeyOverride[id] then character.radialKeyOverride[id] = key else store.radials[id].key = key end
end
function RM:HasOwnKey(id) return character.radialKeyOverride[id] ~= nil end
function RM:SetOwnKey(id, on) character.radialKeyOverride[id] = on and self:GetRadialKey(id) or nil end
function RM:SetRadialScope(id, scope) store.radials[id].scope = scope end
function RM:GetGroup(id) return store.groups[id] end
function RM:IsGroupOpen(id) return store.groups[id].open end
function RM:SetGroupOpen(id, open) store.groups[id].open = open end
function RM:ResolveKeys()
    local result = {}
    for _, id in ipairs(store.radialOrder) do
        local key = self:GetRadialKey(id)
        if self:IsRadialAvailable(id) and key and key ~= "" then result[id] = { key = key } end
    end
    return {}, result
end
function RM:ResolveEntry(entry)
    if entry.kind == "spell" then
        local name = E.C_Spell.GetSpellName(entry.id)
        return name and { name = name, icon = { texture = entry.id } }
    elseif entry.kind == "micromenu" then
        return { name = entry.panel, icon = { texture = 111 } }
    elseif entry.kind == "subradial" then
        return { name = self:GetRadial(entry.radial).name, icon = { texture = 112 } }
    elseif entry.kind == "macro" then
        return { name = entry.name, icon = { texture = entry.icon } }
    elseif entry.kind == "questitems" then
        return { children = { 10 } }
    elseif entry.kind == "item" or entry.kind == "mount" or entry.kind == "toy" then
        return { name = entry.kind, icon = { texture = entry.id } }
    elseif entry.kind == "partycast" then
        return { name = E.C_Spell.GetSpellName(entry.id) }
    elseif entry.marker then
        return { name = entry.kind .. " " .. entry.marker, icon = { texture = 43 } }
    end
end
function RM:GetMacroText(id) return "/click TestRadial" .. id end
function RM:CreateRadial(name, scope)
    local id = store.nextRadialID
    store.nextRadialID = id + 1
    store.radials[id] = { name = name, scope = scope, buttons = {} }
    table.insert(store.radialOrder, id)
    return id
end
function RM:CopyRadial(id, name)
    local current = store.radials[id]
    local new = self:CreateRadial(name, current.scope)
    store.radials[new].buttons = E.CopyTable(current.buttons)
    return new
end
function RM:RenameRadial(id, name) store.radials[id].name = name end
function RM:DeleteRadial(id)
    store.radials[id] = nil
    for i, value in ipairs(store.radialOrder) do
        if value == id then table.remove(store.radialOrder, i) break end
    end
end
function RM:RadialChanged() changes = changes + 1 end
function RM:AvailabilityChanged() changes = changes + 1 end
function RM:ShowPreview(id, host) preview = { id, host } end
function RM:HidePreview() preview = nil end

S:Module{ key = "about", group = "top" }
S:SetPath("radialmenu.enabled", true)
ui:load("Settings/Pages/RadialMenu.lua", ns)
ui:load("Settings/PadNav.lua", ns)
ui:load("Settings/Panel.lua", ns)
ui:load("Settings/RadialEditor.lua", ns)
ns.SettingsPanel:Open("rm", "radials")

local host = assert(ui:find(function(w) return w.radialList ~= nil end))
assert(host:IsVisible() and host.nameText:GetText() == "Utility" and preview[1] == 1 and preview[2] == host.previewArea)
assert(not host.undoButton:IsEnabled() and #host.radialList.data == 5, "the editor lists groups and unavailable radials")
assert(host.overview:GetText():find("Travel", 1, true) and not host.overview:GetText():find("Bank", 1, true))
local group = assert(host.radialList:CellFor(2))
group:Click()
assert(not RM:IsGroupOpen(1) and #host.radialList.data == 4)
group:Click()
assert(RM:IsGroupOpen(1) and #host.radialList.data == 5)

local list = host.browseList
assert(list:CellFor(1).Text:GetText() == "Bags" and list:CellFor(2).Text:GetText() == "Character")
host.search:SetText("char")
assert(#list.data == 1 and list:CellFor(1).Text:GetText() == "Character")
list:CellFor(1):Click()
assert(store.radials[1].buttons[2].panel == "Character" and host.undoButton:IsEnabled())
host.search:SetText("does not exist")
assert(list.emptyText:IsShown() and list.emptyText:GetText() == "Nothing matches your search.")

cursor = { [1] = "spell", [2] = 1900, [4] = 102 }
host.dropZone:RunScript("OnReceiveDrag")
assert(cursor == nil and store.radials[1].buttons[3].id == 102,
    "dragging a spell saves its ID rather than the cursor's spellbook slot")
local buttons = host.buttonList
local third = buttons:CellFor(3)
third:RunScript("OnDragStart")
buttons:CellFor(1).mouseOver = true
third:RunScript("OnDragStop")
buttons:CellFor(1).mouseOver = nil
assert(store.radials[1].buttons[1].id == 102 and store.radials[1].buttons[2].id == 101)
buttons:CellFor(2):Click("RightButton")
assert(#store.radials[1].buttons == 2 and store.radials[1].buttons[2].panel == "Character")

local function category(key)
    local button = assert(ui:find(function(w) return w.key == key and w:GetParent() == host end), key)
    button:Click()
end
local function catalogCount(kind)
    local count = 0
    for _, item in ipairs(list.data) do if item.kind == kind then count = count + 1 end end
    return count
end
category("spells")
assert(catalogCount("spell") == 3 and list:CellFor(1).Text:GetText() == "Spells", "the spellbook excludes future spells but includes the pet's castable action")
category("party")
assert(catalogCount("partycast") == 1 and list:CellFor(1).Text:GetText():find("Heal", 1, true))
category("professions")
assert(catalogCount("spell") == 2 and list:CellFor(1).Text:GetText() == "Professions")
category("items")
assert(catalogCount("item") == 1 and list:CellFor(1).Text:GetText():find("(1)", 1, true), "bag items deduplicate and the quest item slot shows the count")
category("macros")
assert(catalogCount("macro") == 2 and list:CellFor(1).Text:GetText() == "General Macros")
category("markers")
assert(catalogCount("targetmarker") == 10 and catalogCount("worldmarker") == 9)
category("mounts")
assert(catalogCount("mount") == 1 and catalogCount("toy") == 1, "Collections includes only owned mounts and filtered toys")
category("radials")
assert(list:CellFor(1).item.radial == 2 and not list:CellFor(2),
    "the catalog excludes the current radial and another that would create a loop")
list:CellFor(1):Click()
assert(store.radials[1].buttons[3].radial == 2)

host.scopeDrop:OpenMenu().entries[2].pick()
assert(store.radials[1].scope == "class:MAGE")
host.ownKey:Click()
host.keyButton:Click()
host.keyButton:RunScript("OnKeyDown", "R")
local clash = ui.dialogs[#ui.dialogs]
assert(clash.key == "FLAREUI_RADIAL_KEY_TAKEN" and clash.message:find("Reply to Whisper", 1, true) and RM:GetRadialKey(1) == "F")
ns.Dialogs[clash.key].OnAccept(clash.data)
assert(character.radialKeyOverride[1] == "R" and store.radials[1].key == "F")

host.copyButton:Click()
assert(store.radials[4].name == "Utility (copy)" and preview[1] == 4)
host.renameButton:Click()
local popup = E.FlareUI_RadialEditorNewRadial
popup.box:SetText("  Other tools  ")
popup.box:RunScript("OnEnterPressed")
assert(store.radials[4].name == "Other tools" and not popup:IsShown())
host.deleteButton:Click()
local deletion = ui.dialogs[#ui.dialogs]
assert(deletion.key == "FLAREUI_RADIAL_DELETE" and deletion.data.id == 4)
ns.Dialogs[deletion.key].OnAccept(deletion.data)
assert(not store.radials[4] and preview[1] == 1)

host.undoButton:Click()
assert(store.radials[1].buttons[1].id == 101 and #store.radials[1].buttons == 1 and store.radials[1].scope == "")
assert(not character.radialKeyOverride[1] and #store.radialOrder == 3 and store.nextRadialID == 4 and not host.undoButton:IsEnabled())
host.newButton:Click()
popup.box:SetText("Secondary")
popup.accept:Click()
assert(store.radials[4].name == "Secondary" and store.radials[4].scope == "" and preview[1] == 4 and changes > 5)
ui.combat = true
host.macroButton:Click()
assert(#macros == 0 and #messages == 1, "macro creation is blocked in combat")
ui.combat = false
host.macroButton:Click()
assert(macros[1].name == "FUI Secondary" and macros[1].body == "/click TestRadial4" and macros[1].perCharacter and macroPicked == 122,
    "creating a macro writes the selected radial command and picks it up")

ns.SettingsPanel:Select("about")
assert(not host:IsShown() and preview == nil, "leaving the page stops the preview")
ns.SettingsPanel:Select("rm")
assert(store.radials[4].name == "Secondary" and not host.undoButton:IsEnabled(),
    "leaving keeps edits and reopening takes a new undo snapshot")

print("PASS: radial editor catalog, drag and drop, keys, scope and undo")
