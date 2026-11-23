local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local function noop() end
local Widget = getmetatable(env.UIParent)
function Widget:EnableGamePadStick(on) self.stickEnabled = on end
function Widget:RemoveMaskTexture() end
function Widget:CreateLine() return self:CreateTexture() end
function Widget:SetThickness(value) self.thickness = value end
function Widget:SetStartPoint(...) self.startPoint = { ... } end
function Widget:SetEndPoint(...) self.endPoint = { ... } end
function Widget:SetCooldownFromDurationObject(duration) self.cooldownObject = duration end

local listeners = {}
env.LibStub = function(name)
    assert(name == "AceEvent-3.0")
    return { Embed = function(_, mod)
        function mod:RegisterEvent(event, method) listeners[event] = method or self[event] end
    end }
end
env.canaccessvalue = function() return true end
env.canaccessallvalues = env.canaccessvalue
env.CopyTable = function(source)
    local copy = {}
    for key, value in pairs(source) do copy[key] = type(value) == "table" and env.CopyTable(value) or value end
    return copy
end
env.UnitFactionGroup = function() return ui.faction or "Alliance" end
env.UnitClass = function() return "Mage", "MAGE" end
env.UnitName = function(unit) return unit == "party1" and "Aria" or "Frost" end
env.UnitExists = function(unit) return unit == "player" or unit == "party1" end
env.C_ClassColor = { GetClassColor = function() return env.CreateColor(0.7, 0.7, 1, 1) end }

local binds, secureWrites = {}, {}
env.ClearOverrideBindings = function(owner)
    assert(not ui.combat)
    binds[owner] = {}
end
env.SetOverrideBindingClick = function(owner, priority, key, frame, button)
    assert(priority and not ui.combat)
    binds[owner][key] = { frame, button }
end
env.SecureHandlerSetFrameRef = function(owner, key, frame)
    owner.references = owner.references or {}
    owner.references[key] = frame
end
env.SecureHandlerWrapScript = function(frame, event, owner, body)
    frame.secureScripts = frame.secureScripts or {}
    frame.secureScripts[event] = { owner, body }
end
env.SecureHandlerExecute = function(frame, snippet)
    assert(not ui.combat and frame.template == "SecureHandlerBaseTemplate")
    secureWrites[#secureWrites + 1] = snippet
end

local spells = { [101] = "Frostbolt", [102] = "Frostbolt", [103] = "Frostbolt", [201] = "Blink", [301] = "Summon Horse" }
local known = { [101] = true, [102] = true, [201] = true }
local spellBook, requested, loaded = { 101, 102, 201 }, {}, false
env.Enum = { SpellBookSpellBank = { Player = 0, Pet = 1 } }
env.C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 2 end,
    GetSpellBookSkillLineInfo = function(line)
        return line == 1 and { numSpellBookItems = #spellBook, itemIndexOffset = 0 } or { offSpecID = 1 }
    end,
    GetSpellBookItemInfo = function(index, bank)
        assert(bank == 0); return { spellID = spellBook[index] }
    end,
    IsSpellKnownOrInSpellBook = function(_, bank) assert(bank == 1); return false end,
}
env.C_Spell = {
    GetSpellName = function(id) return spells[id] end,
    GetSpellInfo = function(id) if spells[id] then return { name = spells[id], iconID = id + 1000 } end end,
    GetSpellSubtext = function(id) return id <= 103 and ("Rank " .. (id - 100)) or "" end,
    GetSpellCooldown = function(id) return { isActive = id == 201 } end,
    GetSpellCooldownDuration = function(id) return "duration:" .. id end,
    IsSpellUsable = function() return true, false end,
    IsSpellInRange = function(_, unit) return unit ~= "party1" end,
    GetSpellCharges = function(id) if id == 201 then return { maxCharges = 2, currentCharges = 1 } end end,
}
env.C_Item = {
    GetItemCount = function(id) return id == 500 and 3 or id == 501 and 1 or 0 end,
    IsEquippedItem = function(id) return id == 501 end,
    GetItemNameByID = function(id) if id == 500 and loaded then return "Healing Potion" end end,
    RequestLoadItemDataByID = function(id) requested[id] = true end,
    GetItemIconByID = function(id) return id + 1000 end,
    GetItemCooldown = function(id) if id == 500 then return 54, 6, true end end,
    IsUsableItem = function() return true end,
    GetItemMaxStackSizeByID = function(id) return id == 500 and 20 or 1 end,
}
env.C_MountJournal = {
    GetMountInfoByID = function(id)
        if id == 1 or id == 2 then return "Horse", 301, 1401, nil, nil, nil, nil, nil, nil, nil, id == 1 end
    end,
    GetMountUsabilityByID = function() return true end,
}
env.PlayerHasToy = function(id) return id == 501 end
env.C_ToyBox = { GetToyInfo = function(id) return id, "Toy Train", 1501 end }
env.C_QuestLog = {
    GetNumQuestWatches = function() return 1 end,
    GetQuestIDForQuestWatchIndex = function() return 12 end,
    GetLogIndexForQuestID = function() return 3 end,
    GetNumQuestLogEntries = function() return 4 end,
    GetInfo = function(index) return { isHeader = index == 1 } end,
}
env.GetQuestLogSpecialItemInfo = function(index)
    if index == 3 then return "|Hitem:503|h[Beacon]|h", 1503 end
    if index == 2 or index == 4 then return "|Hitem:504|h[Signal]|h", 1504 end
end
env.GetMacroIndexByName = function(name) return name == "Blink Macro" and 1 or 0 end
env.GetMacroInfo = function(index) if index == 1 then return "Blink Macro", 1234, "/cast Blink" end end
env.GetMacroSpell = function(index) if index == 1 then return 201 end end
env.GetMacroItem = noop
env.MAX_ACCOUNT_MACROS = 120
env.GetNumMacros = function() return 1, 0 end

env.IsRaidMarkerActive = function(id) return id == 1 end
env.C_Texture = { GetAtlasInfo = function(name) return name ~= "talents-node-circle-gray" and { width = 24, height = 24 } or nil end }
env.MAXEMOTEINDEX = 2
env.EMOTE1_TOKEN, env.EMOTE1_CMD1, env.EMOTE1_CMD2 = "WAVE", "/wave", "/greet"
env.EMOTE2_TOKEN, env.EMOTE2_CMD1 = "FORTHEHORDE", "/forthehorde"
env.CharacterMicroButton = env.CreateFrame("Button", "CharacterMicroButton", env.UIParent)

local stickValue = "1"
env.C_CVar = {
    GetCVar = function(key) assert(key == "GamePadStickAxisButtons"); return stickValue end,
    SetCVar = function(key, value) assert(key == "GamePadStickAxisButtons"); stickValue = value end,
}
local crossbarCallback
env.GamepadMode = { RegisterCrossBarModifierStateChanged = function(callback) crossbarCallback = callback end }
env.C_GamePad = {
    StickIndexToConfigName = function(index) return index == 1 and "Right" or "Left" end,
    ButtonBindingToIndex = function(button) return button == "PADLTRIGGER" and 4 or 5 end,
}
local main = {
    name = "Utility Wheel", slices = {
        { kind = "spell", id = 201 }, { kind = "item", id = 500 }, { kind = "ring", ring = "r2" },
        { kind = "emote", emote = "CUSTOM", command = "/GREET" }, { kind = "emote", emote = "CUSTOM" },
    },
}
local spare = { name = "Spare Wheel", slices = { { kind = "worldmarker", marker = 1 }, { kind = "mount", id = 1 } } }
local character = { radial = "r1", radialKeys = { { radial = "r2", key = "ALT-G" } } }
local other = { ring = "", radialKeys = {} }
local global = {
    radialmenu = { rings = { r1 = main, r2 = spare }, ringOrder = { "r1", "r2" }, nextRingID = 3, key = "F",
        lastSetup = { radial = "r2", keys = { { radial = "r1", key = "SHIFT-G" } } } },
    characters = { ["Player-1"] = character, ["Player-2"] = other }, padStickKeysRestore = "0",
}
local profile = { position = "center", showNames = "always", labelFont = { size = 15, flags = "NONE" }, countFont = { size = 12 } }
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }), modules = {},
    db = { profile = { radialmenu = profile, actionbars = { autoRanks = true } }, global = global },
    IsGamepadUI = function() return ui.gamepad == true end,
    IsPlayerSpell = function(id) return known[id] == true end,
    OtherControllerAddon = function() return false end,
    CharDB = function() return character end,
    PlayerGUID = function() return "Player-1" end,
    GetFontPath = function(face) return "Fonts/" .. (face or "Default") end,
    SetFont = function(widget, ...) widget:SetFont(...) end,
    SetFontFamily = function(widget, ...) widget:SetFont(...) end,
    ApplyShadow = noop,
    ParsePadCombo = function(key)
        if type(key) == "string" then return key:match("^PAD:(%w+):(%w+)$") end
    end,
    PadStickKey = function(stick) return stick == "L3" and "PADLSTICK" or "PADRSTICK" end,
    PadTriggerKey = function(side) return side == "LT" and "PADLTRIGGER" or "PADRTRIGGER" end,
}
ui:load("Modules/RadialMenu.lua", ns)
local rm = ns.RadialMenu
-- The secure host is only available after combat. This test inspects the attributes written to it.
ui.combat = true
rm:Init()
assert(rm.securePending and not env.FlareUI_RadialCaster)
ui.combat = false
rm:PLAYER_REGEN_ENABLED()
local radial, caster = env.FlareUI_Radial, assert(env.FlareUI_RadialCaster)
local header = caster.secureScripts.OnClick[1]
rm:Refresh()
local store = rm.GetStore()
assert(store.keysPerRadial and not store.rings and not store.lastSetup and not main.slices)
assert(#main.buttons == 4 and main.buttons[3].kind == "subradial" and main.buttons[3].radial == "r2")
assert(main.buttons[4].emote == "WAVE" and not main.buttons[4].command)
assert(character.radialKeyOverride.r1 == "F" and character.radialKeyOverride.r2 == "ALT-G")
assert(other.radialKeyOverride.r1 == false and other.radialKeyOverride.r2 == false)
assert(rm:GetSharedKey("r1") == "SHIFT-G" and rm:GetSharedKey("r2") == "F")
assert(stickValue == "0" and not global.padStickKeysRestore)
assert(binds[radial].F[2] == "r1" and binds[radial]["ALT-G"][2] == "r2")
assert(header:GetAttribute("r1-count") == 4 and header:GetAttribute("r1-s3-n") == 2)
assert(header:GetAttribute("r1-s2-1-item") == "item:500" and requested[500])
assert(header:GetAttribute("r1-s4-1-macrotext") == "/wave")
assert(header:GetAttribute("flare-assigned") == "r1" and header:GetAttribute("flare-center"))

loaded = true
listeners.ITEM_DATA_LOAD_RESULT(nil, 500, true)
ui:flushTimers()
assert(rm:ResolveEntry({ kind = "item", id = 500 }).name == "Healing Potion")
assert(not rm:ResolveEntry({ kind = "item", id = 599 }))
assert(rm:ResolveEntry({ kind = "toy", id = 501 }).attributes.toy == 501)
assert(not rm:ResolveEntry({ kind = "mount", id = 2 }))
assert(rm:ResolveEntry({ kind = "mount", id = 1 }).attributes.spell == "Summon Horse")
assert(rm:ResolveEntry({ kind = "spell", id = 101 }).attributes.spell == 101, "deliberate lower rank stays pinned")
assert(rm:ResolveEntry({ kind = "spell", id = 103 }).attributes.spell == 102, "unknown saved rank uses highest known")
assert(not rm:ResolveEntry({ kind = "spell", id = 999 }))
spellBook[4], known[103] = 103, true
listeners.SPELLS_CHANGED()
assert(rm.BestRank("Frostbolt") == 103)
local kind, id, icon = rm.MacroAction({ name = "Blink Macro" })
assert(kind == "spell" and id == 201 and icon == 1234)
assert(rm:ResolveEntry({ kind = "macro", name = "Blink Macro" }).attributes.macro == "Blink Macro")
assert(rm:ResolveEntry({ kind = "macro", name = "Absent", text = "/wave" }).attributes.macrotext == "/wave")
assert(rm:ResolveEntry({ kind = "micromenu", panel = "character" }).attributes.macrotext == "/click CharacterMicroButton")
assert(rm:ResolveEntry({ kind = "targetmarker", marker = -1 }).attributes.action == "clear-all")
assert(rm:ResolveEntry({ kind = "targetmarker", marker = 0 }).attributes.action == "clear")
assert(rm:ResolveEntry({ kind = "worldmarker", marker = 0 }).attributes.action == "clear")
assert(rm.WorldMarkerForIcon(rm.WorldMarkerIcon(4)) == 4)
assert(not rm.EmoteOffered({ token = "FORTHEHORDE", faction = "Horde" }))
assert(rm.EmoteKit.TokenFor(" /greet ") == "WAVE" and rm.EmoteKit.TokenFor("/wave Mo") == nil)
assert(rm.EmoteKit.Label("/волна") == "волна")
local questItems = rm:ResolveEntry({ kind = "questitems" })
assert(#questItems.children == 2 and questItems.children[1].name == "Beacon" and questItems.children[2].name == "Signal")
local party = rm:ResolveEntry({ kind = "partycast", id = 201 })
assert(#party.spread == 2 and party.spread[2].name == "Aria" and party.spread[2].attributes.unit == "party1")

local names = rm:GetScopeChoices()
assert(table.concat(names, ",") == ",faction:Alliance,class:MAGE,char:Player-1")
local class = rm:CreateRadial("Class Wheel", "class:MAGE")
local ally = rm:CreateRadial("Alliance Wheel", "faction:Alliance")
local enemy = rm:CreateRadial("Horde Wheel", "faction:Horde")
local own = rm:CreateRadial("My Wheel", "char:Player-1")
assert(rm:GetRadial(own).scopeName == "Frost" and not rm:IsRadialAvailable(enemy))
rm:SetRadialKey(class, "F")
rm:SetRadialKey(ally, "F")
rm:SetRadialKey(own, "F")
assert(rm:ResolveKeys().F == "r1", "own key overrides a character-scoped shared key")
rm:SetOwnKey("r1", false)
assert(rm:ResolveKeys().F == own)
local duplicate = rm:CopyRadial("r1", "Personal Tools")
local data = rm:GetRadial(duplicate)
assert(data.buttons[1] ~= main.buttons[1] and not data.key)
local oldMacro = rm:GetMacroText(duplicate)
rm:RenameRadial(duplicate, "Renamed Tools")
rm:RadialChanged()
assert(oldMacro == "/click FUIRadial PersonalTools" and rm:GetMacroText(duplicate) == "/click FUIRadial RenamedTools")
assert(header:GetAttribute("tag-personaltools") == duplicate, "renames keep existing macro tags")
local group = rm:CreateGroupWith(class, "Spellbooks")
rm:SetRadialGroup(duplicate, group)
rm:SetGroupOpen(group, false)
rm:RenameGroup(group, "Tools")
assert(rm:GetGroup(group).name == "Tools" and not rm:IsGroupOpen(group))
assert(rm:MoveGroup(group, enemy) and rm:MoveRadial(ally, class))
assert(rm:GetRadial(ally).group == group and not rm:MoveGroup(group, ally))
rm:Ungroup(group)
assert(not rm:GetGroup(group) and not rm:GetRadial(ally).group)
assert(rm:GetRadialsByName()[1] == ally)

main.buttons[#main.buttons + 1] = { kind = "subradial", radial = "r1" }
rm:SetRadialScope(enemy, "char:Player-2")
rm:RadialChanged()
local nested = rm:ResolveEntry({ kind = "subradial", radial = "r1" })
assert(#nested.children == 4, "recursive child is left out")
assert(not rm:ResolveEntry({ kind = "subradial", radial = enemy }))
rm:DeleteRadial(duplicate)
assert(not rm:GetRadial(duplicate) and not header:GetAttribute("tag-personaltools"))

profile.targetMouseover = "alt"
rm:SetRadialKey(own, "ALT-F")
local winners, details = rm:ResolveKeys()
assert(winners.F == class and details[own].reserved and details[ally].beatenBy == class)
assert(binds[radial]["ALT-F"][2] == class and header:GetAttribute("flare-mouseover") == "alt")
assert(rm.KeyWithModifier("SHIFT-G", "ALT") == "ALT-SHIFT-G")
assert(rm.HoldVariants("SHIFT-G", { ["ALT-SHIFT-G"] = true }) == "CTRL-SHIFT-G ALT-CTRL-SHIFT-G")
ui.combat = true
rm:SetRadialKey(class, "H")
assert(rm.bindingPending and binds[radial].F[2] == class)
ui.combat = false
rm:PLAYER_REGEN_ENABLED()
assert(not rm.bindingPending and binds[radial].H[2] == class)

ui.gamepad = true
rm:SetPadKey(ally, "PAD:L3:LT")
rm:SetPadKey(class, "PAD:L3:LT")
rm:SetPadKey("r1", "PAD:R3:TOP")
assert(rm:ResolvePadKeys()["PAD:L3:LT"] == class)
assert(header:GetAttribute("flare-pad-L3-LT") == class and binds[radial].PADRSTICK[2] == "PadR3")
assert(not binds[rm.triggerOwner].PADLSTICK)
crossbarCallback(nil, "left", true)
assert(binds[rm.triggerOwner].PADLSTICK[2] == "PadL3")
crossbarCallback(nil, "left", false)
assert(not binds[rm.triggerOwner].PADLSTICK)
rm:SetPadReleaseOn(false)
rm:SetPadRepeatOn(true)
assert(not header:GetAttribute("flare-padrelease") and header:GetAttribute("flare-padrepeat"))
rm:SetControllerEnabled(false)
assert(not rm:IsControllerEnabled() and not binds[radial].PADRSTICK)
rm:SetControllerEnabled(true)
assert(rm:IsControllerEnabled() and binds[radial].PADRSTICK)

local sample = rm.CreateSample(env.UIParent)
local sampleWidth, sampleHeight = rm.DrawSample(sample)
assert(sampleWidth == sampleHeight and sampleWidth > sample.wheel:GetWidth())
assert(sample.wheel.Pointer:IsShown() and sample.wheel.Ping.Glow:IsShown() and #sample.wheel.buttons >= 4)
rm:ShowPreview("r1", env.UIParent)
assert(radial:IsShown() and radial:GetFrameStrata() == "FULLSCREEN" and radial:GetScale() < 1)
rm:HidePreview()
assert(not radial:IsShown() and radial:GetFrameStrata() == "DIALOG" and radial:GetScale() == 1)
assert(#secureWrites > 0, "resolved state is sent to the secure host")
print("PASS: radial migration, action resolution, group and key precedence, gamepad bindings and previews")
