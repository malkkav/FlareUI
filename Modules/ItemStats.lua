local _, ns = ...

--------------------------------------------------
-- ITEM STATS
-- Item tooltips say "+12 Spell Power" where the game writes "Equip: Increases damage and healing
-- done by magical spells and effects by up to 12." The same goes for set bonuses. Tooltips >
-- Simplified Item Stats (tooltips.shortItemStats, off by default), with the Tooltips module on.
-- Healing & Damage (tooltips.healingDamage) picks how "healing … and damage …" lines shorten.
-- The patterns come from the game's own strings, so every language works; a line that matches
-- none stays as the game wrote it.
--------------------------------------------------
if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall) then return end

-- the Healing & Damage choice ("off", "damage" or "power") when shortening is on, else nil
local function Mode()
    local db = ns.db and ns.db.profile and ns.db.profile.tooltips
    return db and db.enabled and db.shortItemStats and (db.healingDamage or "off") or nil
end

-- the long form (TOOLTIP_ITEM_STAT_<key>_INCREASE / _DECREASE) -> the short label (ITEM_MOD_<label>)
local STATS = {
    SPELL_POWER = "SPELL_POWER_SHORT",
    SPELL_DAMAGE = "SPELL_DAMAGE_DONE_SHORT",
    SPELL_HEALING = "SPELL_HEALING_DONE_SHORT",
    HOLY_DAMAGE = "HOLY_DAMAGE_DONE_SHORT",
    FIRE_DAMAGE = "FIRE_DAMAGE_DONE_SHORT",
    FROST_DAMAGE = "FROST_DAMAGE_DONE_SHORT",
    NATURE_DAMAGE = "NATURE_DAMAGE_DONE_SHORT",
    SHADOW_DAMAGE = "SHADOW_DAMAGE_DONE_SHORT",
    ARCANE_DAMAGE = "ARCANE_DAMAGE_DONE_SHORT",
    SPELL_PENETRATION = "SPELL_PENETRATION_SHORT",
    ATTACK_POWER = "ATTACK_POWER_SHORT",
    RANGED_ATTACK_POWER = "RANGED_ATTACK_POWER_SHORT",
    ARMOR_PENETRATION = "ARMOR_PENETRATION_RATING_SHORT",
    CRIT_PERCENT = "CRIT_RATING_SHORT",
    HIT_PERCENT = "HIT_RATING_SHORT",
    HASTE_PCT = "HASTE_RATING_SHORT",
    EXPERTISE_PCT = "EXPERTISE_RATING_SHORT",
    DEFENSE = "DEFENSE_SKILL_RATING_SHORT",
    DODGE_PCT = "DODGE_RATING_SHORT",
    PARRY_PCT = "PARRY_RATING_SHORT",
    BLOCK_CHANCE = "BLOCK_RATING_SHORT",
    BLOCK_VALUE = "BLOCK_VALUE_SHORT",
    MANA_REGEN = "POWER_REGEN0_SHORT",
    HEALTH_REGEN = "HEALTH_REGEN_SHORT",
}

local MAGIC = "[%^%$%(%)%%%.%[%]%*%+%-%?]"

-- A format string as a Lua pattern: each %d / %1$d / %.1f becomes a capture of the figure (the rules
-- take formats with one figure only, so its position among the arguments doesn't matter)
local function ToPattern(format)
    local marked = format:gsub("%%%d?%$?[%d%.]*[dfs]", "\001")
    marked = marked:gsub("%%%%", "\002")
    local pattern = marked:gsub(MAGIC, "%%%0"):gsub("\001", "([%%d%%.,]+)"):gsub("\002", "%%%%")
    return "^" .. pattern .. "$"
end

-- a stat's pattern, and its set bonus form: set bonuses carry the same words without the "Equip: " in front
local function Patterns(format, equip)
    local list = { ToPattern(format) }
    if equip and format:sub(1, #equip) == equip then
        list[2] = ToPattern((format:sub(#equip + 1):gsub("^%s+", "")))
    end
    return list
end

local function Figures(format)
    return select(2, format:gsub("%%%d?%$?[%d%.]*[dfs]", ""))
end

-- rules: { pattern, sign, label, percent }; healRules: { pattern, healSign, damageSign, damageFirst }
-- for "healing done by up to %1$d and damage done by up to %2$d", Forever's only stat line with two
-- figures (Tooltips > Healing & Damage). Read once, the first time a tooltip needs them.
local rules, healRules, prefixes
local healLabel, damageLabel, powerLabel
local function BuildRules()
    rules, healRules, prefixes = {}, {}, {}
    local equip = type(ITEM_SPELL_TRIGGER_ONEQUIP) == "string" and ITEM_SPELL_TRIGGER_ONEQUIP or nil
    for key, short in pairs(STATS) do
        local label = _G["ITEM_MOD_" .. short]
        if type(label) == "string" and label ~= "" then
            for suffix, sign in pairs({ _INCREASE = "+", _DECREASE = "-" }) do
                local format = _G["TOOLTIP_ITEM_STAT_" .. key .. suffix]
                if type(format) == "string" and Figures(format) == 1 then
                    local percent = format:find("%%%%") and "%" or ""
                    for _, pattern in ipairs(Patterns(format, equip)) do
                        rules[#rules + 1] = { pattern, sign, label, percent }
                    end
                end
            end
        end
    end
    healLabel, damageLabel, powerLabel = ITEM_MOD_SPELL_HEALING_DONE_SHORT, ITEM_MOD_SPELL_DAMAGE_DONE_SHORT, ITEM_MOD_SPELL_POWER_SHORT
    if type(healLabel) == "string" and type(damageLabel) == "string" and type(powerLabel) == "string" then
        for heal, healSign in pairs({ INCREASE = 1, DECREASE = -1 }) do
            for damage, damageSign in pairs({ INCREASE = 1, DECREASE = -1 }) do
                local format = _G["TOOLTIP_ITEM_STAT_SPELL_HEALING_" .. heal .. "_DAMAGE_" .. damage]
                if type(format) == "string" and Figures(format) == 2 then
                    -- a language may name the damage first
                    local damageFirst = format:match("%%(%d)%$") == "2"
                    for _, pattern in ipairs(Patterns(format, equip)) do
                        healRules[#healRules + 1] = { pattern, healSign, damageSign, damageFirst }
                    end
                end
            end
        end
    end
    -- "Set: %s" and "(%d) Set: %s": the bonus after the prefix is shortened, the prefix kept
    for _, format in ipairs({ ITEM_SET_BONUS, ITEM_SET_BONUS_GRAY }) do
        local prefix = type(format) == "string" and format:match("^(.-)%%s$")
        if prefix and prefix ~= "" then
            prefixes[#prefixes + 1] = "^(" .. prefix:gsub(MAGIC, "%%%0"):gsub("%%%%d", "%%d+") .. ")(.+)$"
        end
    end
end

-- two lines, healing first: "+26 Spell Healing" and "+9 Spell Damage", or with "power" the damage
-- as Spell Power and the healing that comes on top of it ("+17 Spell Healing" and "+9 Spell Power")
local function ShortenHealing(text, mode)
    for i = 1, #healRules do
        local rule = healRules[i]
        local heal, damage = text:match(rule[1])
        if heal then
            if rule[4] then heal, damage = damage, heal end
            heal, damage = tonumber(heal), tonumber(damage)
            if not (heal and damage) then return end
            heal, damage = heal * rule[2], damage * rule[3]
            if mode == "power" then
                return ("%+d %s\n%+d %s"):format(heal - damage, healLabel, damage, powerLabel)
            end
            return ("%+d %s\n%+d %s"):format(heal, healLabel, damage, damageLabel)
        end
    end
end

local function Shorten(text, mode)
    for i = 1, #rules do
        local rule = rules[i]
        local figure = text:match(rule[1])
        -- "1.0%" reads "1%" (one zero after the point only, so "1,000" stays)
        if figure then return rule[2] .. figure:gsub("^(%d+)[%.,]0$", "%1") .. rule[4] .. " " .. rule[3] end
    end
    if mode ~= "off" then return ShortenHealing(text, mode) end
end

-- what each line became (false: left as it is); tooltips redraw often, so a repeat costs one lookup.
-- Forgotten when Healing & Damage changes.
local memo, memoSize, memoMode = {}, 0, nil
local function Rewrite(text, mode)
    if mode ~= memoMode then wipe(memo); memoSize, memoMode = 0, mode end
    local done = memo[text]
    if done ~= nil then return done end
    local result = Shorten(text, mode)
    if not result then
        for i = 1, #prefixes do
            local prefix, rest = text:match(prefixes[i])
            local short = rest and Shorten(rest, mode)
            if short then
                result = prefix .. short
                break
            end
        end
    end
    if memoSize > 2000 then wipe(memo); memoSize = 0 end
    memo[text], memoSize = result or false, memoSize + 1
    return result or false
end

-- "<tooltip>TextLeft<i>" names built once per tooltip and line (item tooltips refresh several times a second)
local lineNames = setmetatable({}, { __index = function(t, name)
    local names = setmetatable({}, { __index = function(u, i)
        local s = name .. "TextLeft" .. i
        u[i] = s
        return s
    end })
    t[name] = names
    return names
end })

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tip)
    local mode = Mode()
    if not (tip and tip.GetName and tip.NumLines) or not mode then return end
    local name = tip:GetName()
    if not name then return end
    if not rules then BuildRules() end
    if #rules == 0 and #healRules == 0 then return end
    local names = lineNames[name]
    for i = 2, tip:NumLines() do
        local line = _G[names[i]]
        local text = line and line:GetText()
        if text and canaccessvalue(text) then
            local short = Rewrite(text, mode)
            if short then line:SetText(short) end
        end
    end
end)
