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

local binds, secureWrites, bodies = {}, {}, {}
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
    if frame:GetName() then bodies[frame:GetName()] = body end
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
    GetSpellDisplayCount = function(id) return id == 201 and "17" or "" end,
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
-- every attribute an action sets reaches the secure button (11-23: "toy" didn't, so toys did nothing)
local copied = {}
for key in rm.ACTION_KEYS:gmatch("%S+") do copied[key] = true end
do
    local source = assert(io.open("Modules/RadialMenu.lua")):read("*a")
    local checked = 0
    for body in source:gmatch("{ (type = \"%a+\"[^}]*)}") do
        for key in (", " .. body):gmatch(", (%a+) = ") do
            assert(copied[key], "the secure button never gets the attribute " .. key)
            checked = checked + 1
        end
    end
    assert(checked > 20)
end
assert(not rm:ResolveEntry({ kind = "mount", id = 2 }))
assert(rm:ResolveEntry({ kind = "mount", id = 1 }).attributes.spell == "Summon Horse")
assert(rm:ResolveEntry({ kind = "spell", id = 101 }).attributes.spell == 101, "deliberate lower rank stays pinned")
assert(rm:ResolveEntry({ kind = "spell", id = 103 }).attributes.spell == 102, "unknown saved rank uses highest known")
assert(not rm:ResolveEntry({ kind = "spell", id = 999 }))
-- a party spell keeps the rank it was added at (11-24); one saved before follows the best rank
do
    local picked, before = { kind = "partycast", id = 101 }, { kind = "partycast", id = 101 }
    rm.MarkRank(picked, true)
    rm.MarkRank(before)
    assert(picked.pinned and picked.rankChecked and not before.pinned and not before.rankChecked)
    rm.MarkRank({ kind = "macro", id = 101 }, true)
    local best = { kind = "partycast", id = 102 }
    rm.MarkRank(best, true)
    assert(not best.pinned)
end
spellBook[4], known[103] = 103, true
listeners.SPELLS_CHANGED()
assert(rm.BestRank("Frostbolt") == 103)
local kind, id, icon = rm.MacroAction({ name = "Blink Macro" })
assert(kind == "spell" and id == 201 and icon == 1234)
assert(rm:ResolveEntry({ kind = "macro", name = "Blink Macro" }).attributes.macro == "Blink Macro")
assert(rm:ResolveEntry({ kind = "macro", name = "Absent", text = "/wave" }).attributes.macrotext == "/wave")
-- (11-24) macros that share a name: the one with the saved text, by its number; kept until macros change
do
    local byName, info, number, spell = env.GetMacroIndexByName, env.GetMacroInfo, env.GetNumMacros, env.GetMacroSpell
    local macros = { { " ", 11, "/cast Blink" }, { "Solo", 12, "/dance" }, [121] = { " ", 13, "/cast Frostbolt" }, [122] = { "7", 14, "/wave" } }
    env.GetMacroIndexByName = function(name) return name == " " and 1 or name == "Solo" and 2 or name == "7" and 122 or 0 end
    local reads = 0
    env.GetMacroInfo = function(i) reads = reads + 1; if macros[i] then return unpack(macros[i]) end end
    env.GetNumMacros = function() return 2, 2 end
    env.GetMacroSpell = function(i) if i == 121 then return 102 end end
    rm.macroFound = nil
    local entry = { kind = "macro", name = " ", text = "/cast Frostbolt" }
    local slice = rm:ResolveEntry(entry)
    assert(slice.attributes.macro == 121, "the second one of that name")
    local kind, id = rm.MacroAction(entry)
    assert(kind == "spell" and id == 102)
    assert(rm:ResolveEntry({ kind = "macro", name = " ", text = "/cast Blink" }).attributes.macro == 1)
    assert(rm:ResolveEntry({ kind = "macro", name = " ", text = "/gone" }).attributes.macro == 1, "neither: the first")
    assert(rm:ResolveEntry({ kind = "macro", name = "Solo", text = "/dance" }).attributes.macro == "Solo")
    assert(rm:ResolveEntry({ kind = "macro", name = "7", text = "/wave" }).attributes.macro == 122, "a name of digits")
    reads = 0
    assert(rm.MacroIndex(entry) == 121 and reads == 0, "found ones are kept")
    ui:emit("UPDATE_MACROS")
    assert(rm.MacroIndex(entry) == 121 and reads > 0)
    env.GetMacroIndexByName, env.GetMacroInfo, env.GetNumMacros, env.GetMacroSpell = byName, info, number, spell
    rm.macroFound = nil
end
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
assert(party.spread[1].attributes.unit == "player", "in a group your own button is you")
-- the person's name is read from the unit as it is now; a party spell in a sub-radial is a step per person
do
    assert(party.spread[2].person and party.spread[1].person)
    local oldName = env.UnitName
    env.UnitName = function(unit) return unit == "party1" and "Bryn" or oldName(unit) end
    assert(rm.PersonName("party1"):find("Bryn", 1, true))
    env.UnitName = oldName
    local get, available = rm.GetRadial, rm.IsRadialAvailable
    rm.GetRadial = function(_, id) return id == "kids" and { name = "Kids", buttons = { { kind = "partycast", id = 201 } } } or get(rm, id) end
    rm.IsRadialAvailable = function() return true end
    local sub = rm:ResolveEntry({ kind = "subradial", radial = "kids" })
    assert(#sub.children == 2 and sub.children[2].attributes.unit == "party1")
    rm.GetRadial, rm.IsRadialAvailable = get, available
end
-- ranks whose words aren't loaded yet: asked for, and nothing is settled on them
do
    local subtext, load, asked = env.C_Spell.GetSpellSubtext, env.C_Spell.RequestLoadSpellData, {}
    local late = true
    env.C_Spell.GetSpellSubtext = function(id) if late then return "" end return subtext(id) end
    env.C_Spell.RequestLoadSpellData = function(id) asked[id] = true end
    rm.ForgetRanks()
    rm.BestRank("Frostbolt")
    assert(rm.ranksLate.Frostbolt and next(asked) and rm.LowRank(101) == nil)
    local entry = { kind = "spell", id = 101 }
    rm.MarkRank(entry, true)
    assert(not entry.rankChecked and not entry.pinned)
    late = false
    rm.OnSpellText()
    assert(rm.BestRank("Frostbolt") == 103 and not rm.ranksLate.Frostbolt)
    env.C_Spell.GetSpellSubtext, env.C_Spell.RequestLoadSpellData = subtext, load
end
-- alone: the friendly target first, else yourself (11-24)
do
    local exists = env.UnitExists
    env.UnitExists = function(unit) return unit == "player" end
    local alone = rm:ResolveEntry({ kind = "partycast", id = 201 })
    assert(#alone.spread == 1 and alone.spread[1].name == "Blink" and alone.spread[1].attributes.unit == rm.HELP)
    local hard = true
    env.UnitExists = function(unit) if unit == "target" then return hard end return exists(unit) end
    local answer
    local oldParse, oldName = env.SecureCmdOptionParse, env.UnitName
    env.SecureCmdOptionParse = function(text)
        assert(text == "[@target,help] target; player")
        return answer
    end
    assert(rm.HelpUnit() == "player")
    answer = "target"
    assert(rm.HelpUnit() == "target")
    -- a soft target alone (the condition says target, nothing is selected): yourself (11-24)
    hard = false
    assert(rm.HelpUnit() == "player")
    hard = true

    -- every snippet that uses a button takes the unit this way
    local out
    local control = { GetAttribute = function(_, key)
        return ({ ["flare-keys"] = "type unit", ["p-type"] = "spell", ["p-unit"] = rm.HELP, ["q-unit"] = "party1" })[key]
    end }
    local function load(prefix)
        out = {}
        local chunk = assert(loadstring("local self, control, prefix = ... " .. rm.FIRE_SNIPPET))
        setfenv(chunk, { gmatch = string.gmatch, SecureCmdOptionParse = env.SecureCmdOptionParse, UnitExists = env.UnitExists })
        chunk({ SetAttribute = function(_, key, value) out[key] = value end }, control, prefix)
    end
    load("p-")
    assert(out.type == "spell" and out.unit == "target")
    hard = false
    load("p-")
    assert(out.unit == "player", "a soft target is no target")
    hard = true
    answer = "player"
    load("p-")
    assert(out.unit == "player")
    load("q-")
    assert(out.unit == "party1" and out.type == nil)
    local source = assert(io.open("Modules/RadialMenu.lua")):read("*a")
    assert(not source:find("self:SetAttribute(key, control:GetAttribute(prefix .. key))", 1, true))

    -- what the button shows: the target's name, class coloured for a player, and that unit's range
    local asked
    local oldRange, oldPlayer = env.C_Spell.IsSpellInRange, env.UnitIsPlayer
    env.C_Spell.IsSpellInRange = function(_, unit) asked = unit return true end
    env.UnitName = function(unit) return unit == "target" and "Mira" or oldName(unit) end
    local isPlayer = true
    env.UnitIsPlayer = function() return isPlayer end
    local button = env.CreateFrame("Button")
    button.Icon, button.Placed = button:CreateTexture(), button:CreateTexture()
    button.Label, button.Count, button.Rank = button:CreateFontString(), button:CreateFontString(), button:CreateFontString()
    button.Cooldown = { Clear = noop, SetCooldown = noop, SetCooldownFromDurationObject = noop }
    local info = { name = "Blink", attributes = alone.spread[1].attributes, entry = alone.spread[1].entry }
    local oldColor = env.C_ClassColor.GetClassColor
    env.C_ClassColor.GetClassColor = function() return { WrapTextInColorCode = function(_, t) return "|cff" .. t end } end
    answer = "target"
    rm.ApplyButtonState(button, info)
    assert(button.Label:GetText() == "|cffMira" and asked == "target")
    isPlayer = false
    button.helpText = nil
    rm.ApplyButtonState(button, info)
    assert(button.Label:GetText() == "Mira")
    -- the uses a spell's reagents leave, as on the action bars; nothing on other spells (11-24)
    assert(button.Count:IsShown() and button.Count:GetText() == "17")
    rm.ApplyButtonState(button, rm:ResolveEntry({ kind = "spell", id = 102 }))
    assert(button.Count:GetText() == "")
    rm.ApplyButtonState(button, rm:ResolveEntry({ kind = "micromenu", panel = "character" }))
    assert(not button.Count:IsShown())
    answer = "player"
    rm.ApplyButtonState(button, info)
    assert(button.Label:GetText() == "Blink" and asked == "player", "no friendly target: the spell's own name again")

    -- Show Spell Rank (11-24, off): a spell below its best rank, on the icon, after the name, or both
    local rdb = ns.db.profile.radialmenu
    local savedLevel = rdb.spellRank
    local lowName = function() return rm.ButtonName(rm:ResolveEntry({ kind = "spell", id = 101, pinned = true, rankChecked = true })) end
    for _, want in ipairs({ { nil, false, false }, { "off", false, false }, { "icon", true, false }, { "label", false, true }, { "both", true, true } }) do
        rdb.spellRank = want[1]
        rm.ApplyButtonState(button, rm:ResolveEntry({ kind = "spell", id = 101, pinned = true, rankChecked = true }))
        assert(button.Rank:IsShown() == want[2], tostring(want[1]))
        assert(lowName() == (want[3] and "Frostbolt (Rank 1)" or "Frostbolt"), tostring(want[1]))
    end
    rm.ApplyButtonState(button, info)
    assert(not button.Rank:IsShown(), "a spell without ranks")
    local function shown(id) rm.ApplyButtonState(button, rm:ResolveEntry({ kind = "spell", id = id, pinned = true, rankChecked = true })) end
    shown(102)
    assert(button.Rank:IsShown() and tostring(button.Rank:GetText()) == "2")
    shown(103)
    assert(not button.Rank:IsShown() and button.Rank:GetText() == "", "the best rank: nothing")
    local low = rm:ResolveEntry({ kind = "spell", id = 101, pinned = true, rankChecked = true })
    assert(low.name == "Frostbolt" and rm.ButtonName(low) == "Frostbolt (Rank 1)")
    assert(rm.ButtonName(rm:ResolveEntry({ kind = "spell", id = 103 })) == "Frostbolt")
    assert(rm.ButtonName({ name = "Aria", attributes = { type = "spell", spell = 101, unit = "party1" } }) == "Aria", "a party spell keeps the person")
    assert(rm.ButtonName({ name = "Charger", attributes = { type = "spell", spell = "Summon Horse" } }) == "Charger")
    assert(rm.LowRank(101) == 1 and rm.LowRank(201) == nil and rm.LowRank(nil) == nil)
    -- alone, the spell's own name carries the rank too
    local help = { name = "Frostbolt", attributes = { type = "spell", spell = 102, unit = rm.HELP }, entry = { kind = "spell", id = 102 } }
    button.helpText = nil
    rm.ApplyButtonState(button, help)
    assert(button.Label:GetText():gsub("\n", " ") == "Frostbolt (Rank 2)" and button.Label:GetText():find("(Rank 2)", 1, true), "never split inside the brackets")
    -- a best rank forgotten makes the next one the best, once the book is read again
    spellBook[4], known[103] = nil, nil
    listeners.SPELLS_CHANGED()
    assert(rm.LowRank(102) == nil and rm.LowRank(101) == 1)
    spellBook[4], known[103] = 103, true
    listeners.SPELLS_CHANGED()
    assert(rm.LowRank(102) == 2)
    rdb.spellRank = savedLevel
    env.C_ClassColor.GetClassColor = oldColor
    env.C_Spell.IsSpellInRange, env.UnitIsPlayer, env.UnitName, env.SecureCmdOptionParse = oldRange, oldPlayer, oldName, oldParse
    env.UnitExists = exists
end

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

env.C_GamePad.GetDeviceMappedState = function() return { sticks = { {}, { x = 0, y = 0, len = 0 } } } end
assert(not rm:IsPadOpen())
-- the sticks while it is open (11-23): the guard passes everything on and only watches; the blocker, up for
-- the camera's event alone, holds the camera still, so the left stick keeps moving the character
local guard, block = rm.Sticks.guard, rm.Sticks.block
assert(guard.propagate and not block.propagate, "only the blocker takes input")
assert(guard.template == nil and guard.stickEnabled and block.stickEnabled, "plain frames, so they can show in a fight")
assert(not guard:IsShown() and not block:IsShown(), "idle, neither takes a stick")
local function send(stick, x)   -- the game's dispatch: the blocker is above the guard; true: the game got it
    for _, w in ipairs({ block, guard }) do
        if w:IsShown() then
            w:RunScript("OnGamepadStick", stick, x or 1, 0, x or 1)
            if not w.propagate then return false end
        end
    end
    return true
end
assert(send("Right") and send("Camera") and not block:IsShown(), "no radial: the camera turns")
local trackerClosed = 0
ns.PadTracker = { Close = function() trackerClosed = trackerClosed + 1 end }
header.OnSecurePadOpen(header, "r1")
assert(rm:IsPadOpen() and trackerClosed == 1, "the quest tracker gives the pad up")
ns.PadTracker = nil
local frameEnd = assert(rm.Sticks.clock)
assert(frameEnd:IsShown())
local function nextFrame() frameEnd:RunScript("OnUpdate", 0.016) end
assert(send("Left") and send("Movement"), "moving")
nextFrame()
assert(send("Right") and not send("Camera") and not block:IsShown(), "aiming alone: the camera holds still")
nextFrame()
assert(send("Left") and send("Right") and send("Movement") and not send("Camera"), "moving and aiming: only the camera is held")
nextFrame()
assert(send("Left") and send("Movement"), "and movement goes on")
nextFrame()
assert(send("Right", 0) and send("Camera", 0), "the camera hears the stick centre")
nextFrame()
send("Right")
assert(block:IsShown())
nextFrame()
assert(not block:IsShown(), "never left up past its frame")
-- closed with the stick still out: the camera is held until it is back, at most HOLD_AFTER seconds
local stickLen = 1
env.C_GamePad.GetDeviceMappedState = function() return { sticks = { {}, { x = stickLen, y = 0, len = stickLen } } } end
send("Right")
header.OnSecureClose(header)
assert(not rm:IsPadOpen() and frameEnd:IsShown(), "still held: the stick is out")
frameEnd:RunScript("OnUpdate", 0.1)
assert(not block:IsShown() and send("Right") and not send("Camera"), "the spring-back doesn't turn the camera")
stickLen = 0.1
frameEnd:RunScript("OnUpdate", 0.1)
assert(not block:IsShown() and not frameEnd:IsShown() and not guard:IsShown())
assert(send("Right") and send("Camera"), "closed: the camera is the game's again")
stickLen = 1
header.OnSecurePadOpen(header, "r1")
header.OnSecureClose(header)
frameEnd:RunScript("OnUpdate", 0.5)
assert(not frameEnd:IsShown(), "never held longer than that")
-- from one controller radial to another the sticks stay ours, with no gap
header.OnSecurePadOpen(header, "r1")
header.OnSecurePadOpen(header, "r1")
assert(rm:IsPadOpen() and guard:IsShown() and frameEnd:IsShown() and stickValue == "1")
stickLen = 0
header.OnSecureClose(header)
assert(stickValue == "0" and global.padStickKeysRestore == nil and not guard:IsShown())
-- the game refusing the setting in a fight: nothing is remembered that never took, and a refused
-- restore is asked again after the fight
do
    local set, refuse = env.C_CVar.SetCVar, true
    env.C_CVar.SetCVar = function(...) if not refuse then set(...) end end
    header.OnSecurePadOpen(header, "r1")
    assert(stickValue == "0" and global.padStickKeysRestore == nil)
    header.OnSecureClose(header)
    refuse = false
    header.OnSecurePadOpen(header, "r1")
    assert(stickValue == "1" and global.padStickKeysRestore == "0")
    refuse = true
    header.OnSecureClose(header)
    assert(stickValue == "1" and global.padStickKeysRestore == "0")
    refuse = false
    rm:PLAYER_REGEN_ENABLED()
    assert(stickValue == "0" and global.padStickKeysRestore == nil)
    env.C_CVar.SetCVar = set
end
-- what is lit is what a release uses: the secure layer gets the lit button, out of a fight
stickLen = 1
header.OnSecurePadOpen(header, "r1")
radial:RunScript("OnUpdate", 0.02)
assert(type(header:GetAttribute("flare-lit")) == "number" and secureWrites[#secureWrites]:find("flare-lit", 1, true))
stickLen = 0
header.OnSecureClose(header)
header.OnSecureOpen(header, "r1")
assert(not rm:IsPadOpen())
header.OnSecureClose(header)

-- the secure snippets themselves, run with a stand-in for the restricted environment
do
    local stick, fired, closed = { x = 0, y = 1, len = 1 }, nil, 0
    local attributes = { ["r-count"] = 4, ["flare-padrelease"] = true, ["flare-keys"] = "type", ["slot-type"] = "spell" }
    local control = {
        GetAttribute = function(_, key) return attributes[key] end,
        CallMethod = function(_, method, index) if method == "OnSecureSticky" then attributes.sticky = index end end,
        RunAttribute = function(_, name)
            if name == "flare-closepad" then closed = closed + 1 elseif name == "flare-aimed" then return "slot-" end
        end,
    }
    local globals
    local function reset()
        globals = { MODE = "pad", ACTIVE = "r", HELD = {}, LAST = {}, math = math, next = next, gmatch = string.gmatch, strlower = string.lower,
            newtable = function() return {} end, GetGamePadState = function() return { sticks = { {}, stick } } end }
        fired, closed = nil, 0
    end
    local function run(frameName, button, down)
        local chunk = assert(loadstring("local self, control, button, down = ... " .. bodies[frameName]))
        setfenv(chunk, globals)
        local _, message = chunk({ SetAttribute = function() end }, control, button, down)
        if message == "fired" then fired = (fired or 0) + 1 end
    end
    local names = {}
    for _, d in ipairs({ "Up", "Down", "Left", "Right" }) do
        names[d] = "FlareUI_RadialAim" .. d
        assert(bodies[names[d]], "an aim button for each direction: " .. d)
    end
    local function key(d, down) run(names[d], "Aim" .. d, down) end
    local function at(x, y) stick.x, stick.y, stick.len = x, y, math.sqrt(x * x + y * y) end
    -- a plain flick: up, let go
    reset() at(0, 1) key("Up", true) at(0, 0.2) key("Up", false)
    assert(fired == 1 and closed == 1)
    -- a diagonal: both keys down, one release lost
    reset() at(0.7, 0.7) key("Up", true) key("Right", true) at(0.1, 0.1) key("Right", false)
    assert(fired == 1, "one of a diagonal's two releases is enough")
    reset() at(0.7, 0.7) key("Up", true) key("Right", true) at(0.1, 0.1) key("Up", false)
    assert(fired == 1, "also when the release that arrives is the other one's")
    -- rolling round the rim fires nothing
    reset() at(0, 1) key("Up", true) at(0.7, 0.7) key("Right", true) at(1, 0.1) key("Up", false)
    assert(not fired, "rolling on keeps the radial open")
    at(0.2, 0) key("Right", false)
    assert(fired == 1)
    -- the last release arrives while the stick is still fairly far out
    reset() at(0, 1) key("Up", true) at(0, 0.7) key("Up", false)
    assert(fired == 1)
    -- springing back past the middle doesn't move the aim
    reset() at(0, 1) key("Up", true)
    local aim = attributes.sticky
    at(0, -0.3) key("Up", false)
    assert(fired == 1 and globals.STICKY == aim and attributes.sticky == aim)
    -- the stick was already out when the radial opened: its release uses nothing
    reset() at(0, 0.2) globals.STICKY = 2 key("Up", false)
    assert(not fired)
    attributes["flare-padrelease"] = nil
    reset() at(0, 1) key("Up", true) at(0, 0.1) key("Up", false)
    assert(not fired, "Release the stick to use is off")
    -- B closes only on a release whose press was seen (a bar slot on B opens on the press)
    reset()
    run("FlareUI_RadialPad", "RightButton", false)
    assert(closed == 0)
    run("FlareUI_RadialPad", "RightButton", true)
    run("FlareUI_RadialPad", "RightButton", false)
    assert(closed == 1)
end

-- a macro just made isn't there to pick up yet: the slot is filled a moment later, and the game's own placing
-- is never asked with nothing on the cursor (its red error line)
do
    local util, pickup, cursor = env.GamepadActionBarBindingUtil, env.PickupMacro, env.GetCursorInfo
    local ready, held, placed, told = false, nil, nil, nil
    env.GamepadActionBarBindingUtil = { AssignActionToGamepadStandardSlot = function(slot, pick)
        assert(held and pick == nil, "only with the macro on the cursor")
        placed = slot
    end }
    env.ClearCursor = function() held = nil end
    env.PickupMacro = function(index) if ready then held = index end end
    env.GetCursorInfo = function() return held end
    local info = env.GetMacroInfo
    env.GetMacroInfo = function() return "x", 1, "#flareui-radial\n/click FlareUI_RadialPad r1" end
    rm.OnBarPlaced = function(id) told = id end
    rm.PutMacroOnSlot("r1", 5, "PADDUP", 3)
    assert(not placed, "not there yet")
    ready = true
    ui:flushTimers()
    assert(placed == 5 and told == "r1", "a moment later")
    rm.OnBarPlaced = nil
    env.GamepadActionBarBindingUtil, env.PickupMacro, env.GetCursorInfo, env.GetMacroInfo = util, pickup, cursor, info
end

-- (11-24, Dutra) pet commands: the ones on the pet's bar, as Blizzard's slash commands
do
    local has = true
    local bar = { "PET_ACTION_ATTACK", "PET_ACTION_MOVE_TO", "PET_MODE_PASSIVE", "PET_ACTION_MODE_DEFENSIVEASSIST", "Growl", "PET_ACTION_DISMISS" }
    local info, hasBar, label, slash = env.GetPetActionInfo, env.PetHasActionBar, env.PET_ACTION_ATTACK, env.SLASH_PET_PASSIVE1
    env.PetHasActionBar = function() return has end
    env.GetPetActionInfo = function(i) return bar[i], 1, bar[i] ~= nil and bar[i]:find("^PET_") ~= nil end
    env.PET_ACTION_ATTACK, env.SLASH_PET_PASSIVE1 = "Attack", "/petpassiv"
    local list = rm.PetCommands()
    assert(#list == 4 and list[1].command == "ATTACK" and list[2].command == "MOVE_TO"
        and list[3].command == "DEFENSIVEASSIST" and list[4].command == "PASSIVE")
    local attack, passive = rm:ResolveEntry(list[1]), rm:ResolveEntry(list[4])
    assert(attack.name == "Attack" and attack.attributes.type == "macro" and attack.attributes.macrotext == "/petattack")
    assert(passive.attributes.macrotext == "/petpassiv", "the client's own language")
    assert(not rm:ResolveEntry({ kind = "petcommand", command = "DANCE" }))
    has = false
    assert(#rm.PetCommands() == 0)
    env.GetPetActionInfo, env.PetHasActionBar, env.PET_ACTION_ATTACK, env.SLASH_PET_PASSIVE1 = info, hasBar, label, slash
end

-- (11-24, Kyu-ball) a controller bar macro names its radial by a word made from its name, the same on every
-- computer; one made before, by an id another computer gave out, goes to the radial of the macro's name
do
    local info, count, edit, delete = env.GetMacroInfo, env.GetNumMacros, env.EditMacro, env.DeleteMacro
    local word = rm.PadWord("Mounts")
    assert(word:match("^n%d+$") and rm.PadWord("MOUNTS ") == word and rm.PadWord("Mount") ~= word)
    assert(rm.PadWord("Маунты") ~= rm.PadWord("Зелья") and rm.PadWord(("x"):rep(300)):match("^n%d+$"))
    assert(rm.PadMacroWord("#flareui-radial\n/click FlareUI_RadialPad r7\n") == "r7")
    assert(not rm.PadMacroWord("#flareui-radial\n/click FlareUI_RadialPad r7\n/cast Blink"), "a line the player added")
    assert(not rm.PadMacroWord("/click FlareUI_RadialPad r7") and not rm.PadMacroWord(nil))

    local mounts, potions = rm:CreateRadial("Pad Mounts"), rm:CreateRadial("Pad Potions")
    local function body(name) return "#flareui-radial\n/click FlareUI_RadialPad " .. name end
    local macros
    env.GetMacroInfo = function(i) if macros[i] then return macros[i][1], 5, macros[i][2] end end
    env.GetNumMacros = function() return #macros, 0 end
    env.EditMacro = function(i, name, _, text) macros[i] = { name, text } end
    env.DeleteMacro = function(i) table.remove(macros, i) end
    -- the other computer's ids are swapped; one macro's name is nobody's, one isn't ours
    macros = { { "Pad Potions", body(mounts) }, { "Pad Mounts", body(potions) }, { "Mine", body(mounts) }, { "Pad Mounts", "/cast Blink" } }
    ui.combat = true
    rm.UpdatePadMacros()
    assert(macros[1][2] == body(mounts), "never in a fight")
    ui.combat = false
    rm.UpdatePadMacros()
    assert(macros[1][2] == body(rm.PadWord("Pad Potions")) and macros[2][2] == body(rm.PadWord("Pad Mounts")))
    assert(macros[3][2] == body(mounts) and macros[4][2] == "/cast Blink")
    -- the secure side knows the words
    rm.MarkDirty()
    header:OnSecureWarm()
    assert(header:GetAttribute("tag-" .. rm.PadWord("Pad Mounts")) == mounts)
    assert(header:GetAttribute("tag-" .. rm.PadWord("Pad Potions")) == potions)

    -- where it is: placed on another computer, so this one has no note of it
    local ui2, frame, util, key, action, char = env.C_GamepadUI, env.GamepadMainActionBarFrame, env.GamepadActionBarBindingUtil,
        env.GetBindingKey, env.GetActionInfo, nil
    local slots, cleared = { [202] = 2 }, {}
    env.C_GamepadUI = { GetFirstGamepadActionStorageSlotIndex = function() return 201 end,
        IsValidGamepadActionStorageSlotIndex = function(slot) return slot <= 204 end }
    env.GetActionInfo = function(slot) if slots[slot] then return "macro", slots[slot] end end
    env.GetBindingKey = function(command) return command == "GAMEPADACTIONBUTTON2" and "PAD2" or nil end
    local bar = { GetActionButtonByIndex = function(_, n) return { GetGamepadPageUnitSlotID = function() return n end } end }
    env.GamepadMainActionBarFrame = { PageUnit = { actionBars = { leftBar = bar }, GetCurrentPage = function() return 1 end } }
    env.GamepadActionBarBindingUtil = { IsBindablePageUnitSlotID = function() return true end,
        GetGamepadStorageSlotIndexFromPageAndPageUnitSlotID = function(_, slotID) return 200 + slotID end,
        ClearActionFromGamepadSlot = function(slot) cleared[#cleared + 1] = slot slots[slot] = nil end }
    ns.PadBarKey = ns.PadBarKey or function(side, button) return "PADBAR-" .. side .. "-" .. button end
    local parse = ns.ParsePadBar
    ns.ParsePadBar = function(k) return k:match("^PADBAR%-(%u+)%-(%w+)$") end
    assert(rm:GetBarKey(mounts) == ns.PadBarKey("LT", "PAD2"), "found on the bar")
    assert(rm:GetBarKey(potions) == nil)
    assert(rm:RemoveFromBar(mounts) and cleared[1] == 202 and rm:GetBarKey(mounts) == nil)
    ns.ParsePadBar = parse
    env.C_GamepadUI, env.GamepadMainActionBarFrame, env.GamepadActionBarBindingUtil, env.GetBindingKey, env.GetActionInfo =
        ui2, frame, util, key, action

    -- renamed: the macro follows, name and word; deleted: it goes
    rm:RenameRadial(mounts, "Pad Horses")
    assert(macros[2][1] == "Pad Horses" and macros[2][2] == body(rm.PadWord("Pad Horses")))
    rm:DeleteRadial(potions)
    assert(#macros == 3 and macros[1][1] == "Pad Horses")
    -- renamed in a fight the macro can't follow: its old word still opens the radial
    ui.combat = true
    local before = macros[1][2]
    rm:RenameRadial(mounts, "Pad Steeds")
    assert(macros[1][2] == before)
    ui.combat = false
    rm.MarkDirty()
    header:OnSecureWarm()
    assert(header:GetAttribute("tag-" .. rm.PadWord("Pad Horses")) == mounts)
    -- two radials of one name, each with its own macro: moving them leaves each macro on its radial
    local twin = rm:CreateRadial("Pad Steeds")
    macros = { { "Pad Steeds", body(rm.PadWord("Pad Steeds")) }, { "Pad Steeds", body(twin) } }
    assert(rm:MoveRadial(twin, mounts))
    assert(macros[1][2] == body(mounts) and macros[2][2] == body(rm.PadWord("Pad Steeds")))
    -- (an id macro of a name two radials share is left alone)
    macros[3] = { "Pad Steeds", body("r999") }
    rm.UpdatePadMacros()
    assert(macros[3][2] == body("r999"))
    -- undone (RadialEditor.lua): names swapped back, the macros follow; every macro of a deleted radial goes
    rm:RenameRadial(twin, "Pad Twin")
    assert(macros[2][1] == "Pad Twin" and macros[2][2] == body(rm.PadWord("Pad Twin")))
    rm.KeepPadMacros(function()
        rm:GetRadial(twin).name, rm:GetRadial(mounts).name = "Pad Steeds", "Pad Twin"
    end)
    assert(macros[2][1] == "Pad Steeds" and macros[2][2] == body(rm.PadWord("Pad Steeds")))
    assert(macros[1][1] == "Pad Twin" and macros[1][2] == body(rm.PadWord("Pad Twin")))
    macros[4] = { "Copy", body(twin) }
    rm:DeleteRadial(twin)
    assert(#macros == 2 and macros[1][1] == "Pad Twin" and macros[2][2] == body("r999"))
    rm:DeleteRadial(mounts)
    env.GetMacroInfo, env.GetNumMacros, env.EditMacro, env.DeleteMacro = info, count, edit, delete
end

-- opened near a screen edge the wheel moves in, and nothing is aimed until the cursor moves
do
    local width, height = env.UIParent:GetWidth(), env.UIParent:GetHeight()
    assert(header:GetAttribute("r1-reach") > 100, "the reach is sent to the secure side")
    local x, y = rm.Inside(5, 5, 60)
    assert(x == 60 and y == 60)
    x, y = rm.Inside(width, height, 60)
    assert(x == width - 60 and y == height - 60)
    x = rm.Inside(5, 5, width)
    assert(x == width / 2, "wider than the screen: in the middle")
    local mouseX, mouseY = 0.98, 0.5
    local screen = {
        GetWidth = function() return 1000 end, GetHeight = function() return 800 end,
        GetMousePosition = function() return mouseX, mouseY end,
    }
    local attributes = { ["r-reach"] = 160, ["r-count"] = 4 }
    local host = { GetAttribute = function(_, key) return attributes[key] end, GetFrameRef = function() return screen end }
    local globals = { math = math, MODE = "hold", ACTIVE = "r" }
    local function run(attribute)
        local chunk = assert(loadstring("local self = ... " .. header:GetAttribute(attribute)))
        return setfenv(chunk, globals)(host)
    end
    run("flare-openpoint")
    assert(globals.OPENX == 840 and globals.OPENY == 400 and globals.FROMX == 980)
    assert(run("flare-select") == nil, "the cursor is off the middle, but hasn't moved")
    mouseX = 0.94
    assert(run("flare-select") == 2, "moved: the right one")
    mouseX, mouseY = 0.84, 0.2
    assert(run("flare-select") == 3)
    mouseY = 0.5
    assert(run("flare-select") == nil, "back in the middle")
    attributes["flare-center"] = true
    mouseX = 0.98
    run("flare-openpoint")
    assert(globals.OPENX == 500 and globals.FROMX == nil and run("flare-select") == 2)
end

local sample = rm.CreateSample(env.UIParent)
local sampleWidth, sampleHeight = rm.DrawSample(sample)
assert(sampleWidth == sampleHeight and sampleWidth > sample.wheel:GetWidth())
assert(sample.wheel.Pointer:IsShown() and sample.wheel.Ping.Glow:IsShown() and #sample.wheel.buttons >= 4)
rm:ShowPreview("r1", env.UIParent)
assert(radial:IsShown() and radial:GetFrameStrata() == "FULLSCREEN" and radial:GetScale() < 1)
rm:HidePreview()
assert(not radial:IsShown() and radial:GetFrameStrata() == "DIALOG" and radial:GetScale() == 1)
assert(#secureWrites > 0, "resolved state is sent to the secure host")
-- (11-24) what changed since the last open is written as a fight starts: once, and never after the lockdown
do
    local function written() return #secureWrites end
    rm.MarkDirty()
    local before = written()
    listeners.PLAYER_REGEN_DISABLED(rm)
    assert(written() > before)
    before = written()
    listeners.PLAYER_REGEN_DISABLED(rm)
    assert(written() == before, "nothing changed: nothing to do")
    rm.MarkDirty()
    ui.combat = true
    listeners.PLAYER_REGEN_DISABLED(rm)
    header.OnSecureWarm()
    ui.combat = false
    assert(written() == before)
    header.OnSecureWarm()
    assert(written() > before, "and before an empty radial refuses to open")
    local body = header:GetAttribute("flare-openclick")
    local count, warmed, shown = 0, 0, 0
    local frame = { Show = function() shown = shown + 1 end }
    local chunk = setfenv(assert(loadstring(body)), { newtable = function() return {} end })
    local self = { GetAttribute = function(_, key) return key == "r9-count" and count or nil end,
        CallMethod = function(_, method) if method == "OnSecureWarm" then warmed = warmed + 1; count = 2 end end,
        RunAttribute = function() end, GetFrameRef = function() return frame end, SetBindingClick = function() end }
    getfenv(chunk).self = self
    local ok = chunk("r9")
    assert(ok ~= false and warmed == 1 and shown > 0, "a radial filled since the last sync opens")
end
-- (dutra_, 7.1) Sub-Radials on Remember: a rebuild keeps each sub-radial's pick while it still fits
do
    local rock = { name = "Rockbiter", icon = 1, attributes = { a = 1 } }
    local wind = { name = "Windfury", icon = 2, attributes = { a = 2 } }
    local old = { r1 = { { children = { rock, wind }, childIndex = 2 }, { children = { rock, wind }, childIndex = 2 } } }
    local fresh = { r1 = {
        { name = "Rockbiter", icon = 1, children = { rock, wind }, childIndex = 1 },
        { name = "Rockbiter", icon = 1, children = { rock }, childIndex = 1 },
    } }
    rm.KeepChildPicks(old, fresh)
    assert(fresh.r1[1].childIndex == 2 and fresh.r1[1].name == "Windfury" and fresh.r1[1].icon == 2, "the pick carries over")
    assert(fresh.r1[2].childIndex == 1 and fresh.r1[2].name == "Rockbiter", "a pick past a shorter list starts over")
end

print("PASS: radial migration, action resolution, group and key precedence, gamepad bindings and previews")
