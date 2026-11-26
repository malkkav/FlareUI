-- Part of FlareUI's DoT tracker. Taken from Does It Die Advanced 1.3.7 by WhiteKnight / Smuggz_, itself based on
-- Does It Die by JoeGG (MIT License, Copyright (c) 2026 Joe Greive: LICENSES/DoesItDieAdvanced.txt), and changed for
-- FlareUI: its own namespace; nothing else.
-- DoesItDie: Chinese (zhCN and zhTW) spell descriptions and names. Registers itself with Locale.lua.
-- The Chinese patterns only see descriptions the other languages didn't read, and can't match their text (they
-- need "秒内", "点", "伤害", "终结技", "连击点").
--
-- The wording is WoW: Forever's own Simplified Chinese tooltips (Wowhead's tooltip API, data env Forever, locale cn),
-- for every spell the addon tracks or ignores. Wowhead has no Traditional Chinese for Forever; the zhTW client's text
-- (issue #20: "並在隨後的12秒內造成總計38點火焰傷害") is the same wording in traditional characters, so traditional
-- characters are turned into simplified ones first (TRADITIONAL) and one set of patterns reads both. Not verified
-- on a Chinese client yet. How it differs from English:
--   * "在12秒内造成总计40点暗影伤害" (40 Shadow damage over 12 sec), with words like 总计/累计 (in total), 对其
--     (to it), 额外(的) (additional) around the amount
--   * the school is a word before "伤害" (damage): 暗影 Shadow, 火焰 Fire, ...; some tooltips leave it out
--     (Corruption, Pyroblast), so those spells' schools are in SCHOOL_BY_NAME
--   * finishers: "终结技", then "1点：12秒内44点伤害" (Rip) or "1点：25点伤害，持续8秒" (Rupture)
--   * builders: "奖励1个连击点数" (awards 1 combo point)

local _, flare = ...
local ns = flare.DotEngine -- the tracker's own namespace (Namespace.lua), apart from FlareUI's

local PHYSICAL = 1

-- Patterns spell digits [0-9], not %d: %d and %s follow the C library's locale, and under some (e.g. Windows'
-- code page 1252) bytes inside Chinese characters count as digits or spaces.

-- Traditional characters in the words the patterns use -> simplified, and the full-width colon.
local TRADITIONAL = {
    ["點"] = "点", ["傷"] = "伤", ["內"] = "内", ["總"] = "总", ["計"] = "计", ["額"] = "额", ["對"] = "对",
    ["隨"] = "随", ["後"] = "后", ["個"] = "个", ["連"] = "连", ["擊"] = "击", ["獎"] = "奖", ["勵"] = "励",
    ["數"] = "数", ["終"] = "终", ["結"] = "结", ["續"] = "续", ["聖"] = "圣", ["術"] = "术", ["將"] = "将",
    ["標"] = "标", ["轉"] = "转", ["給"] = "给", ["獲"] = "获", ["："] = ":",
}

-- School words, combined schools first (Frostfire Bolt's Chinese school word is unverified). 秘法 is zhTW's Arcane.
local SCHOOLS = {
    { "霜火", 4 + 16 }, { "暗影", 32 }, { "火焰", 4 }, { "自然", 8 }, { "冰霜", 16 }, { "神圣", 2 }, { "奥术", 64 },
    { "奧术", 64 }, { "秘法", 64 },
}
local function schoolFromWords(words)
    for _, entry in ipairs(SCHOOLS) do
        if words:find(entry[1], 1, true) then return entry[2] end
    end
    return PHYSICAL
end

-- Chinese names of the spells in DoesItDie.lua's name-keyed tables: Forever's simplified ones (Wowhead), then the
-- same in traditional characters. Names the client reports by spell ID are added at load anyway (Locale.lua), so
-- these mostly matter for the tests.
local NAMES = {
    ["Insect Swarm"] = { "虫群", "蟲群" },
    ["Bane of Agony"] = { "痛苦灾祸", "痛苦災禍" },
    ["Curse of Agony"] = { "痛苦诅咒", "痛苦詛咒" },
    ["Corruption"] = { "腐蚀术", "腐蝕術" },
    ["Fireball"] = { "火球术", "火球術" },
    ["Holy Fire"] = { "神圣之火", "神聖之火" },
    ["Rip"] = { "撕扯" },
    ["Rupture"] = { "割裂" },
    ["Siphon Life"] = { "生命虹吸" },
    ["Serpent Sting"] = { "毒蛇钉刺", "毒蛇釘刺" },
    ["Pyroblast"] = { "炎爆术", "炎爆術" },
    ["Rain of Fire"] = { "火焰之雨" },
    ["Hellfire"] = { "地狱烈焰", "地獄烈焰" },
    ["Blizzard"] = { "暴风雪", "暴風雪" },
    ["Flamestrike"] = { "烈焰风暴", "烈焰風暴" },
    ["Consecration"] = { "奉献", "奉獻" },
    ["Hurricane"] = { "飓风", "颶風" },
    ["Volley"] = { "乱射", "亂射" },
    ["Drain Life"] = { "吸取生命" },
    ["Drain Soul"] = { "吸取灵魂", "吸取靈魂" },
    ["Drain Mana"] = { "吸取法力" },
    ["Health Funnel"] = { "生命通道" },
    ["Mind Flay"] = { "精神鞭笞" },
    ["Arcane Missiles"] = { "奥术飞弹", "奧術飛彈" },
    ["Starshards"] = { "星辰碎片" },
    ["Immolation Trap"] = { "献祭陷阱", "獻祭陷阱" },
    ["Explosive Trap"] = { "爆炸陷阱" },
}

local function normalize(desc)
    desc = desc:gsub("[\192-\255][\128-\191]*", TRADITIONAL)
    return (desc:gsub("([0-9]),([0-9][0-9][0-9])", "%1%2"))
end

local function isFinisher(desc)
    return desc:find("终结技", 1, true) ~= nil
end

-- "奖励1个连击点数" (Rake, Sinister Strike) or "奖励1个连击点" (Claw).
local function comboPointsAwarded(desc)
    return tonumber(normalize(desc):match("奖励([0-9]+)个连击点"))
end

-- Per combo point count: "1点:12秒内44点伤害" (Rip) or "1点:25点伤害，持续8秒" (Rupture).
local function parseFinisher(desc, comboPoints)
    local byPoints, highest = {}, 0
    local function add(pts, amount, secs)
        local points = tonumber(pts)
        byPoints[points] = { total = tonumber(amount), duration = tonumber(secs) }
        highest = math.max(highest, points)
    end
    for pts, secs, amount in desc:gmatch("([0-9]+)点 *: *([0-9]+%.?[0-9]*)秒内([0-9]+)点") do add(pts, amount, secs) end
    for pts, amount, secs in desc:gmatch("([0-9]+)点 *: *([0-9]+)点伤害[^0-9]-持续([0-9]+%.?[0-9]*)秒") do
        add(pts, amount, secs)
    end
    if highest == 0 then return nil end
    local entry = byPoints[math.max(1, math.min(comboPoints, highest))] or byPoints[highest]
    return entry.total, PHYSICAL, entry.duration
end

-- Whether text between two numbers stays inside one clause.
local function oneClause(words)
    return not (words:find("，", 1, true) or words:find("。", 1, true) or words:find("；", 1, true))
end

local function parseDot(desc, comboPoints)
    desc = normalize(desc)
    if isFinisher(desc) then return parseFinisher(desc, comboPoints or 5) end
    -- Weapon poisons ("给一件武器浸毒") are proc DoTs, not cast on the target.
    if desc:find("武器", 1, true) and desc:find("毒", 1, true) then return nil end

    -- The last "N秒内 ... X点[school]伤害" clause, so a direct hit first (Immolate, Moonfire, Flame Shock) yields the
    -- periodic part. Heals ("恢复总计45点生命值") have no "伤害".
    local total, school, duration
    for secs, before, amount, words in desc:gmatch("([0-9]+%.?[0-9]*)秒内([^0-9]-)([0-9]+)点([^0-9]-)伤害") do
        if oneClause(before) and oneClause(words) then
            total, school, duration = tonumber(amount), schoolFromWords(words), tonumber(secs)
        end
    end
    if total and duration and duration > 0 then return total, school, duration end

    -- A drain stated as a rate: "每3秒将目标的11点生命值转移给施法者，持续30秒" (Siphon Life; its school comes from
    -- SCHOOL_BY_NAME). Drain Life reads the same way but is ignored by name.
    local every, amount = desc:match("每([0-9]+%.?[0-9]*)秒[^0-9]-([0-9]+)点生命值")
    local lasts = desc:match("持续([0-9]+%.?[0-9]*)秒")
    if every and amount and lasts then
        every, lasts = tonumber(every), tonumber(lasts)
        if every > 0 and lasts > 0 then
            return tonumber(amount) * math.floor(lasts / every + 0.5), PHYSICAL, lasts, every
        end
    end
end

-- The options window in this language: English text -> translation (see T in Locale.lua). Untranslated text
-- stays English. Every key, ready to fill in: python tools/test_load.py --dump-strings strings.lua
local STRINGS = {
}

ns.locale.register({
    tag = "zhCN",
    label = "简体中文",
    strings = STRINGS,
    parseDot = parseDot,
    isFinisher = function(desc) return isFinisher(normalize(desc)) end,
    comboPointsAwarded = comboPointsAwarded,
    names = NAMES,
})
