-- Part of FlareUI's DoT tracker. Taken from Does It Die Advanced 1.3.7 by WhiteKnight / Smuggz_, itself based on
-- Does It Die by JoeGG (MIT License, Copyright (c) 2026 Joe Greive: LICENSES/DoesItDieAdvanced.txt), and changed for
-- FlareUI: its own namespace; nothing else.
-- DoesItDie: Korean (koKR) spell descriptions and names. Registers itself with Locale.lua.
-- The Korean patterns only see descriptions the other languages didn't read, and can't match their text (they need
-- "초에 걸쳐", "피해", "마무리 일격", "연계").
--
-- The wording is WoW: Forever's own Korean tooltips (Wowhead's tooltip API, data env Forever, locale ko), for every
-- spell the addon tracks or ignores (issue #18). Not verified on a Korean client yet. How it differs from English:
--   * the duration comes first: "12초에 걸쳐 총 40의 암흑 피해를 입힙니다" (40 Shadow damage over 12 sec), with
--     optional "총" (in total), "추가로" (additionally) or "추가" (additional) around the amount
--   * the school is a word before "피해" (damage): 암흑 Shadow, 화염 Fire, ...; none is physical
--   * finishers: "마무리 일격" (finishing move), then "연계 점수 N점: S초에 걸쳐 X의 피해" per combo point count
--   * builders: "1의 연계 포인트가 주어집니다" (awards 1 combo point), or "연계 점수 1점을 생성합니다" (Claw)

local _, flare = ...
local ns = flare.DotEngine -- the tracker's own namespace (Namespace.lua), apart from FlareUI's

local PHYSICAL = 1

-- Patterns spell digits [0-9], not %d: %d and %s follow the C library's locale, and under some (e.g. Windows'
-- code page 1252) bytes inside Korean characters count as digits (0xB9 in "비") or spaces (0xA0).

-- School words, combined schools first (Frostfire Bolt's Korean school word is unverified: both likely spellings).
local SCHOOLS = {
    { "냉기화염", 4 + 16 }, { "냉기불꽃", 4 + 16 }, { "암흑", 32 }, { "화염", 4 }, { "자연", 8 }, { "냉기", 16 },
    { "신성", 2 }, { "비전", 64 },
}
local function schoolFromWords(words)
    for _, entry in ipairs(SCHOOLS) do
        if words:find(entry[1], 1, true) then return entry[2] end
    end
    return PHYSICAL
end

-- Korean names of the spells in DoesItDie.lua's name-keyed tables (Forever's, from Wowhead). Names the client
-- reports by spell ID are added at load anyway (Locale.lua), so these mostly matter for the tests.
local NAMES = {
    ["Insect Swarm"] = { "곤충 떼" },
    ["Bane of Agony"] = { "고통의 파멸" },
    ["Curse of Agony"] = { "고통의 저주" },
    ["Fireball"] = { "화염구" },
    ["Holy Fire"] = { "신성한 불꽃" },
    ["Rip"] = { "도려내기" },
    ["Rupture"] = { "파열" },
    ["Siphon Life"] = { "생명력 착취" },
    ["Serpent Sting"] = { "독사 쐐기" },
    ["Pyroblast"] = { "불덩이 작렬" },
    ["Rain of Fire"] = { "불의 비" },
    ["Hellfire"] = { "지옥의 불길" },
    ["Blizzard"] = { "눈보라" },
    ["Flamestrike"] = { "불기둥" },
    ["Consecration"] = { "신성화" },
    ["Hurricane"] = { "허리케인" },
    ["Volley"] = { "연발 사격" },
    ["Drain Life"] = { "생명력 흡수" },
    ["Drain Soul"] = { "영혼 흡수" },
    ["Drain Mana"] = { "마나 흡수" },
    ["Health Funnel"] = { "생명력 집중" },
    ["Mind Flay"] = { "정신의 채찍" },
    ["Arcane Missiles"] = { "신비한 화살" },
    ["Starshards"] = { "별조각" },
    ["Immolation Trap"] = { "제물의 덫" },
    ["Explosive Trap"] = { "폭발의 덫" },
}

-- Thousands separators ("1,132" -> "1132"), and the words that may sit around a DoT's amount, so one pattern reads
-- every clause: "12초에 걸쳐 추가로 총 28의 화염 피해" -> "12초에 걸쳐 28의 화염 피해".
local function normalize(desc)
    desc = desc:gsub("([0-9]),([0-9][0-9][0-9])", "%1%2")
    desc = desc:gsub("초에 걸쳐 추가로 총 ", "초에 걸쳐 "):gsub("초에 걸쳐 추가로 ", "초에 걸쳐 ")
    desc = desc:gsub("초에 걸쳐 총 ", "초에 걸쳐 ")
    return desc
end

local function isFinisher(desc)
    return desc:find("마무리 일격", 1, true) ~= nil
end

-- "1의 연계 포인트가 주어집니다" (Rake, Sinister Strike) or "연계 점수 1점을 생성합니다" (Claw).
local function comboPointsAwarded(desc)
    return tonumber(desc:match("([0-9]+)의 연계 포인트가 주어집니다") or desc:match("연계 점수 ([0-9]+)점을 생성합니다"))
end

-- "연계 점수 1점: 12초에 걸쳐 44의 피해" per combo point count (Rip, Rupture).
local function parseFinisher(desc, comboPoints)
    local byPoints, highest = {}, 0
    for pts, secs, amount in desc:gmatch("연계 점수 ([0-9]+)점 *: *([0-9]+%.?[0-9]*)초에 걸쳐 ([0-9]+)의") do
        local points = tonumber(pts)
        byPoints[points] = { total = tonumber(amount), duration = tonumber(secs) }
        highest = math.max(highest, points)
    end
    if highest == 0 then return nil end
    local entry = byPoints[math.max(1, math.min(comboPoints, highest))] or byPoints[highest]
    return entry.total, PHYSICAL, entry.duration
end

local function parseDot(desc, comboPoints)
    desc = normalize(desc)
    if isFinisher(desc) then return parseFinisher(desc, comboPoints or 5) end
    -- Weapon poisons ("무기에 ... 독을 바릅니다") are proc DoTs, not cast on the target.
    if desc:find("독을 바릅니다", 1, true) then return nil end

    -- The last "N초에 걸쳐 X의 [school] 피해" clause, so a direct hit first (Immolate, Moonfire, Fireball) yields the
    -- periodic part. Between the amount and "피해" there are no digits or sentence ends, so heals ("32의 생명력을
    -- 회복시킵니다.") don't match.
    local total, school, duration
    for secs, amount, words in desc:gmatch("([0-9]+%.?[0-9]*)초에 걸쳐 ([0-9]+)의 ([^0-9%.]-)피해") do
        total, school, duration = tonumber(amount), schoolFromWords(words), tonumber(secs)
    end
    if total and duration and duration > 0 then return total, school, duration end

    -- A drain stated as a rate: "3초마다 11의 생명력을 흡수합니다. 30초 동안 지속됩니다." (Siphon Life; its school
    -- comes from SCHOOL_BY_NAME). Drain Life and Drain Mana read the same way but are ignored by name.
    local every, amount = desc:match("([0-9]+%.?[0-9]*)초마다 ([0-9]+)의 생명력을 흡수")
    local lasts = desc:match("([0-9]+%.?[0-9]*)초 동안 지속")
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
    tag = "koKR",
    label = "한국어",
    strings = STRINGS,
    parseDot = parseDot,
    isFinisher = function(desc) return isFinisher(normalize(desc)) end,
    comboPointsAwarded = comboPointsAwarded,
    names = NAMES,
})
