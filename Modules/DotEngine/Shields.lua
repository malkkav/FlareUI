-- Part of FlareUI's DoT tracker. Taken from Does It Die Advanced 1.3.7 by WhiteKnight / Smuggz_, itself based on
-- Does It Die by JoeGG (MIT License, Copyright (c) 2026 Joe Greive: LICENSES/DoesItDieAdvanced.txt), and changed for
-- FlareUI: only the shield and immunity check of its PlayerHealth.lua (the rest measures enemy players' health
-- from the combat log, which Forever doesn't have).
local _, flare = ...
local ns = flare.DotEngine -- the tracker's own namespace (Namespace.lua), apart from FlareUI's

local function isSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, r = pcall(issecretvalue, v)
    return ok and r or false
end

-- Shields and immunities on a unit: damage goes into them before health, and the client doesn't say how much is left,
-- so while one is up the kill icon is hidden (the marker still shows). Names come from the client by spell ID, so they
-- match in every language; the English names are a fallback.
local SHIELD_SPELLS = {
    17,    -- Power Word: Shield
    11426, -- Ice Barrier
    1463,  -- Mana Shield
    7812,  -- Sacrifice (Voidwalker)
    543,   -- Fire Ward
    6143,  -- Frost Ward
    6229,  -- Shadow Ward
    642,   -- Divine Shield
    498,   -- Divine Protection
    1022,  -- Blessing of Protection
    45438, -- Ice Block (TBC)
    11958, -- Ice Block (Classic Era)
}
local SHIELD_NAMES = { ["Power Word: Shield"] = true, ["Ice Barrier"] = true, ["Mana Shield"] = true,
    ["Sacrifice"] = true, ["Fire Ward"] = true, ["Frost Ward"] = true, ["Shadow Ward"] = true,
    ["Divine Shield"] = true, ["Divine Protection"] = true, ["Blessing of Protection"] = true, ["Ice Block"] = true }
local namesFilled = false
local function fillShieldNames()
    if namesFilled then return end
    namesFilled = true
    for _, id in ipairs(SHIELD_SPELLS) do
        local ok, name = pcall(function()
            if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
            return GetSpellInfo and GetSpellInfo(id)
        end)
        if ok and type(name) == "string" and name ~= "" and not isSecret(name) then SHIELD_NAMES[name] = true end
    end
end

local function buffName(unit, i)
    if UnitBuff then
        local ok, name = pcall(UnitBuff, unit, i)
        if ok then return name end
    end
    if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
        local ok, data = pcall(C_UnitAuras.GetBuffDataByIndex, unit, i)
        if ok and type(data) == "table" then return data.name end
    end
end

function ns.shielded(unit)
    fillShieldNames()
    for i = 1, 40 do
        local name = buffName(unit, i)
        if name == nil then return false end
        if type(name) == "string" and not isSecret(name) and SHIELD_NAMES[name] then return true, name end
    end
    return false
end

