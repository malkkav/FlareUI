local _, ns = ...

--------------------------------------------------
-- ITEM STATS
-- Item tooltips say "+12 Spell Power" where the game writes "Equip: Increases damage and healing
-- done by magical spells and effects by up to 12." The same goes for set bonuses. Always on.
-- The patterns come from the game's own strings, so every language works; a line that matches
-- none stays as the game wrote it.
--------------------------------------------------
if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall) then return end

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

-- A format string as a Lua pattern: each %d / %1$d / %.1f becomes a capture of the figure. The
-- figure's position among the arguments is kept, since a language may put them in another order.
local function ToPattern(format)
    local order, n = {}, 0
    local marked = format:gsub("%%(%d?)%$?[%d%.]*[dfs]", function(position)
        n = n + 1
        order[n] = tonumber(position) or n
        return "\001"
    end)
    marked = marked:gsub("%%%%", "\002")
    local pattern = marked:gsub(MAGIC, "%%%0"):gsub("\001", "([%%d%%.,]+)"):gsub("\002", "%%%%")
    return "^" .. pattern .. "$", order
end

-- rules: { pattern, sign, label, percent }, read once, the first time a tooltip needs them
local rules, prefixes
local function BuildRules()
    rules, prefixes = {}, {}
    local equip = type(ITEM_SPELL_TRIGGER_ONEQUIP) == "string" and ITEM_SPELL_TRIGGER_ONEQUIP or nil
    for key, short in pairs(STATS) do
        local label = _G["ITEM_MOD_" .. short]
        if type(label) == "string" and label ~= "" then
            for suffix, sign in pairs({ _INCREASE = "+", _DECREASE = "-" }) do
                local format = _G["TOOLTIP_ITEM_STAT_" .. key .. suffix]
                -- one figure only: a line naming two (healing and damage apart) stays as it is
                if type(format) == "string" and select(2, format:gsub("%%%d?%$?[%d%.]*[dfs]", "")) == 1 then
                    local percent = format:find("%%%%") and "%" or ""
                    local pattern = ToPattern(format)
                    rules[#rules + 1] = { pattern, sign, label, percent }
                    -- set bonuses carry the same words without the "Equip: " in front
                    if equip and format:sub(1, #equip) == equip then
                        local bare = format:sub(#equip + 1):gsub("^%s+", "")
                        rules[#rules + 1] = { (ToPattern(bare)), sign, label, percent }
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

local function Shorten(text)
    for i = 1, #rules do
        local rule = rules[i]
        local figure = text:match(rule[1])
        -- "1.0%" reads "1%" (one zero after the point only, so "1,000" stays)
        if figure then return rule[2] .. figure:gsub("^(%d+)[%.,]0$", "%1") .. rule[4] .. " " .. rule[3] end
    end
end

-- what each line became (false: left as it is); tooltips redraw often, so a repeat costs one lookup
local memo, memoSize = {}, 0
local function Rewrite(text)
    local done = memo[text]
    if done ~= nil then return done end
    local result = Shorten(text)
    if not result then
        for i = 1, #prefixes do
            local prefix, rest = text:match(prefixes[i])
            local short = rest and Shorten(rest)
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

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tip)
    if not (tip and tip.GetName and tip.NumLines) then return end
    local name = tip:GetName()
    if not name then return end
    if not rules then BuildRules() end
    if #rules == 0 then return end
    for i = 2, tip:NumLines() do
        local line = _G[name .. "TextLeft" .. i]
        local text = line and line:GetText()
        if text and canaccessvalue(text) then
            local short = Rewrite(text)
            if short then line:SetText(short) end
        end
    end
end)
