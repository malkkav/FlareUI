local _, ns = ...
local S = ns.Settings
local L = ns.L

--------------------------------------------------
-- BUFFS & DEBUFFS
-- Settings for the player's buff and debuff frames (Modules/Auras.lua).
--------------------------------------------------
local function Refresh()
    if ns.Auras and ns.Auras.Refresh then ns.Auras:Refresh() end
end

local function Holder(kind)
    return function() return ns.Auras and ns.Auras.GetFrame and ns.Auras:GetFrame(kind) end
end

S:Module{
    key = "au", group = "combat", order = 50, enabled = "auras.enabled",
    tabs = { { key = "settings" }, { key = "hide" }, { key = "fonts" } },
    editMode = Holder("buffs"),
    editFrames = { Holder("buffs"), Holder("debuffs") },
}

-- the sample icons show on this page, so Timer, Icon Shape and Swipe can be seen
S:On("PageShown", function(key)
    if ns.Auras and ns.Auras.SetSettingsPreview then ns.Auras:SetSettingsPreview(key == "au") end
end)

S:Row{ key = "au.shape", kind = "choice", path = "auras.style", choices = { "square", "round" }, apply = Refresh }   -- (as Unit Frames', 11-16)
S:Row{ key = "au.swipe", kind = "choice", path = "auras.swipe", choices = { "none", "icon", "border", "both" }, apply = Refresh }
S:Row{ key = "au.timer", kind = "choice", path = "auras.timer", choices = { "none", "below", "bottom", "middle" }, apply = Refresh }
S:Row{ key = "au.arrive", path = "auras.arrive", apply = Refresh }

local function NoMineFirst()
    local sort = S:GetPath("auras.sort")
    return sort ~= "time" and sort ~= "name"
end
S:Row{ key = "au.sort", kind = "choice", path = "auras.sort", choices = { "default", "applied", "time", "name" }, apply = Refresh }
S:Row{ key = "au.reverse", path = "auras.reverse", apply = Refresh }
S:Row{ key = "au.mineFirst", path = "auras.mineFirst", apply = Refresh, disabled = NoMineFirst }

-- (Buff Reminders: its own page since 11-12, Settings/Pages/BuffReminders.lua)

-- HIDE AURAS (11-16, Malkkav): add one of your auras or a spell ID, then pick where each one hides
-- (ns.HiddenAuras in Core.lua does the hiding, on every aura frame)
local HA = ns.HiddenAuras

local function SpellLabel(id, withId)
    local name = C_Spell.GetSpellName(id) or ("#" .. id)
    local icon = C_Spell.GetSpellTexture(id) or 134400
    local text = ("|T%s:16:16:0:0:64:64:5:59:5:59|t %s"):format(icon, name)
    if withId then text = text .. "  |cff808080" .. id .. "|r" end
    return text
end

-- your buffs, then your debuffs, minus the ones already hidden (an aura whose ID is secret in a
-- fight is left out)
local function OwnAuras()
    local list = { { 0, L["Pick One of Yours"] } }
    local saved, seen = HA.Saved() or {}, {}
    for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
        local first = true
        for i = 1, 40 do
            local aura = C_UnitAuras.GetAuraDataByIndex("player", i, filter)
            if not aura then break end
            local id = aura.spellId
            if canaccessvalue(id) and type(id) == "number" and not saved[id] and not seen[id] then
                seen[id] = true
                if first then list[#list + 1] = { divider = true } first = false end
                list[#list + 1] = { id, SpellLabel(id) }
            end
        end
    end
    return list
end

S:Row{ key = "au.hidePick", kind = "dropdown", tab = "hide", section = "au.hideAdd", choices = OwnAuras,
    get = function() return 0 end,
    set = function(id) if type(id) == "number" and id > 0 then HA.Add(id) end end }
S:Row{ key = "au.hideById", kind = "button", center = true, tab = "hide", section = "au.hideAdd",
    apply = function() ns.ShowDialog("FLAREUI_HIDE_AURA_ID") end }

ns.Dialogs["FLAREUI_HIDE_AURA_ID"] = {
    text = L["The spell ID of the aura to hide. Wowhead shows it in the spell's web address."],
    button1 = L["Add"],
    button2 = L["Cancel"],
    hasEditBox = true,
    maxLetters = 10,
    OnAccept = function(_, text)
        local id = tonumber(strtrim(text or ""))
        if not (id and C_Spell.GetSpellName(id)) then
            print("|cffff9900FlareUI:|r " .. L["No spell has that ID."])
            return
        end
        HA.Add(id)
    end,
    hideOnEscape = true,
}

-- the list, by name: a fixed set of rows, each showing the n-th hidden aura (sorted once per change)
local sorted, sortedStamp, sortedFrom = {}, -1, nil
local function SortedIds()
    local saved = HA.Saved()
    if sortedStamp ~= HA.stamp or sortedFrom ~= saved then
        sortedStamp, sortedFrom = HA.stamp, saved
        wipe(sorted)
        for id in pairs(saved or {}) do
            if type(id) == "number" then sorted[#sorted + 1] = id end
        end
        table.sort(sorted, function(a, b)
            local na, nb = C_Spell.GetSpellName(a) or "", C_Spell.GetSpellName(b) or ""
            if na ~= nb then return na < nb end
            return a < b
        end)
    end
    return sorted
end

S:Row{ key = "au.hideEmpty", kind = "text", noTitle = true, tab = "hide", section = "au.hideList",
    hidden = function() return #SortedIds() > 0 end }

local HIDE_ON = { exclusive = {}, tokens = HA.PLACES, empty = "" }
for i = 1, 60 do
    local function Id() return SortedIds()[i] end
    S:Row{ key = "au." .. i .. ".hideOn", kind = "dropdown", tab = "hide", section = "au.hideList",
        choices = HA.PLACES, toggles = HIDE_ON,
        labelFn = function() local id = Id() return id and SpellLabel(id, true) or "" end,
        hidden = function() return Id() == nil end,
        get = function()
            local id, saved = Id(), HA.Saved()
            return id and saved and saved[id] or ""
        end,
        set = function(value)
            local id, saved = Id(), HA.Saved()
            if not (id and saved) then return end
            saved[id] = value or ""
            HA.Changed()
        end,
        sideButtons = { right = { text = L["Remove"], width = 80,
            onClick = function() local id = Id() if id then HA.Remove(id) end end } } }
end

-- FONTS (11-13, back from Edit Mode): Buffs and Debuffs each in a section
for _, kind in ipairs({ "buffs", "debuffs" }) do
    local function Font(key)
        return {
            key = key == "font" and "timer" or "count",
            font = function() return ns.Auras.KindFont(kind, key) end,
            default = function() return S:DefaultPath("auras." .. kind .. "." .. key) end,
        }
    end
    S:FontRows{ module = "au", tab = "fonts", section = kind == "buffs" and "au.fontsBuffs" or "au.fontsDebuffs",
        prefix = kind, apply = Refresh, fonts = { Font("font"), Font("countFont") } }
end
