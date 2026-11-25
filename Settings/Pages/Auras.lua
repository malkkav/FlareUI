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

S:Row{ key = "au.shape", kind = "choice", path = "auras.style", choices = { "square", "round" }, apply = Refresh }   -- (as Unit Frames')
S:Row{ key = "au.swipe", kind = "choice", path = "auras.swipe", choices = { "none", "icon", "border", "both" }, apply = Refresh }
S:Row{ key = "au.timer", kind = "choice", path = "auras.timer", choices = { "none", "below", "bottom", "middle" }, apply = Refresh }
S:Row{ key = "au.timerColor", path = "auras.timerColor", apply = Refresh, half = true,
    disabled = function() return S:GetPath("auras.timer") == "none" end }
S:Row{ key = "au.arrive", path = "auras.arrive", apply = Refresh, half = true }
-- TOTEMS (from their Edit Mode dialog): the shape, the swipe and the time on the player's totems
-- (unitframes.totems, Totems.lua StyleTotem). The totems come with FlareUI's player frame, not this module.
local function TotemsRefresh() if ns.Totems and ns.Totems.ApplyLayout then ns.Totems.ApplyLayout() end end
local function TotemsOff()
    return not (S:GetPath("unitframes.enabled") and S:GetPath("unitframes.units.player.enabled"))
end
S:Row{ key = "au.totemShape", kind = "choice", section = "au.totems", path = "unitframes.totems.shape", ignoreModule = true,
    choices = { "round", "square" }, apply = TotemsRefresh, disabled = TotemsOff,
    resetValue = function() return "round" end }
S:Row{ key = "au.totemSwipe", kind = "choice", section = "au.totems", path = "unitframes.totems.swipe", ignoreModule = true,
    choices = { "none", "icon", "border", "both" }, apply = TotemsRefresh, disabled = TotemsOff,
    resetValue = function() return "both" end }
S:Row{ key = "au.totemTimer", kind = "choice", section = "au.totems", path = "unitframes.totems.timer", ignoreModule = true,
    choices = { "none", "below", "bottom", "middle" }, apply = TotemsRefresh, disabled = TotemsOff,
    resetValue = function() return "none" end }

local function NoMineFirst()
    local sort = S:GetPath("auras.sort")
    return sort ~= "time" and sort ~= "name"
end
S:Row{ key = "au.sort", kind = "choice", path = "auras.sort", choices = { "default", "applied", "time", "name" }, apply = Refresh }
S:Row{ key = "au.reverse", path = "auras.reverse", apply = Refresh, half = true }
S:Row{ key = "au.mineFirst", path = "auras.mineFirst", apply = Refresh, disabled = NoMineFirst, half = true }

-- (Buff Reminders: its own page, Settings/Pages/BuffReminders.lua)

-- AURA FILTERS: add one of your auras or a spell ID (it starts as Hide), then pick for each one Hide
-- or Show and its frames (ns.HiddenAuras in Core.lua does it, on every aura frame; Hide and Show are
-- saved apart, in auras.hidden and auras.shown)
local HA = ns.HiddenAuras

-- (zbee's Boosted Rest) a debuff the game won't let addons filter on you or a friend (see the
-- Restrictions note): not marked never-secret, and harmful (by the spell, or as it sits on you now:
-- passive effects such as Boosted Rest don't call themselves harmful)
local function BlockedOnYou(id)
    local okS, secrecy = pcall(C_Secrets.GetSpellAuraSecrecy, id)
    if okS and Enum.SecrecyLevel and secrecy == Enum.SecrecyLevel.NeverSecret then return false end
    local okH, harmful = pcall(C_Spell.IsSpellHarmful, id)
    if okH and canaccessvalue(harmful) and harmful then return true end
    local okA, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
    return okA and aura and canaccessvalue(aura) and aura.isHarmful == true or false
end

local function SpellLabel(id, withId)
    local name = C_Spell.GetSpellName(id) or ("#" .. id)
    local icon = C_Spell.GetSpellTexture(id) or 134400
    local text = ("|T%s:16:16:0:0:64:64:5:59:5:59|t %s"):format(icon, name)
    if withId then
        text = text .. "  |cff808080" .. id .. "|r"
        if BlockedOnYou(id) then text = text .. "  |cffff8040" .. L["Not on You"] .. "|r" end
    end
    return text
end

S:Row{ key = "au.hideRulesNote", kind = "text", noTitle = true, tab = "hide", section = "au.hideRules" }

-- your buffs, then your debuffs, minus the ones already listed (an aura whose ID is secret in a
-- fight is left out)
local function OwnAuras()
    local list = { { 0, L["Pick One of Yours"] } }
    local seen = {}
    for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
        local first = true
        for i = 1, 40 do
            -- while the game keeps auras secret (a fight, a flagged player near) the call errors
            -- for addon code: the list then simply has none of yours
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, filter)
            if not ok or not aura or not canaccessvalue(aura) then break end
            local id = aura.spellId
            if canaccessvalue(id) and type(id) == "number" and not HA.ListOf(id) and not seen[id] then
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
    text = L["The spell ID of the aura to add. Wowhead shows it in the spell's web address."],
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

-- the list, both kinds together by name: a fixed set of rows, each showing the n-th aura (sorted once
-- per change)
local sorted, sortedStamp, sortedFrom = {}, -1, nil
local function SortedIds()
    local hidden, shown = HA.Saved(), HA.Saved("shown")
    if sortedStamp ~= HA.stamp or sortedFrom ~= hidden then
        sortedStamp, sortedFrom = HA.stamp, hidden
        wipe(sorted)
        for _, saved in ipairs({ hidden or {}, shown or {} }) do
            for id in pairs(saved) do
                if type(id) == "number" then sorted[#sorted + 1] = id end
            end
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

-- the frames list follows the aura's Hide / Show (Show has no Buffs & Debuffs: those show every aura)
-- (None first, as every toggle list; saved as "")
local FRAMES = { exclusive = { "none" }, tokens = HA.PLACES, empty = "none" }
local MODES = { { "hidden", L["Hide"] }, { "shown", L["Show"] } }
for i = 1, 60 do
    local key = "au." .. i .. ".filterOn"
    local function Id() return SortedIds()[i] end
    local function List() local id = Id() return id and HA.ListOf(id) or "hidden" end
    S:Row{ key = key, kind = "dropdown", tab = "hide", section = "au.hideList", dropdownWidth = 150,
        choices = function()
            local names, out = S:Text(key, "choices") or {}, { { "none", L["None"] }, { divider = true } }
            local show = List() == "shown"
            for n, token in ipairs(HA.PLACES) do
                if not (show and token == "auras") then out[#out + 1] = { token, names[n] or token } end
            end
            return out
        end,
        toggles = FRAMES,
        labelFn = function() local id = Id() return id and SpellLabel(id, true) or "" end,
        hidden = function() return Id() == nil end,
        get = function()
            local id, saved = Id(), HA.Saved(List())
            local value = id and saved and saved[id] or ""
            return value ~= "" and value or "none"
        end,
        set = function(value)
            local id, saved = Id(), HA.Saved(List())
            if not (id and saved) then return end
            saved[id] = (value and value ~= "none") and value or ""
            HA.Changed()
        end,
        sideMenu = { width = 90, choices = MODES, get = List,
            set = function(list) local id = Id() if id then HA.SetList(id, list) end end },
        sideButtons = { right = { text = L["Remove"], width = 80,
            onClick = function() local id = Id() if id then HA.Remove(id, List()) end end } } }
end

-- FONTS (back from Edit Mode): Buffs and Debuffs each in a section
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
