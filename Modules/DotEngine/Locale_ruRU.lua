-- Part of FlareUI's DoT tracker. Taken from Does It Die Advanced 1.3.7 by WhiteKnight / Smuggz_, itself based on
-- Does It Die by JoeGG (MIT License, Copyright (c) 2026 Joe Greive: LICENSES/DoesItDieAdvanced.txt), and changed for
-- FlareUI: its own namespace; nothing else.
-- DoesItDie: Russian (ruRU) spell descriptions and names. Registers itself with Locale.lua.
-- The Russian patterns only see descriptions the other languages didn't read, and can't match their text (they
-- need "урона"/"здоровья" with "за N сек." or "в течение N сек.", "Завершающий прием", "Длина серии").
--
-- The wording is WoW: Forever's own Russian tooltips (Wowhead's tooltip API, data env Forever, locale 7), for every
-- spell the addon tracks or ignores. Not verified on a Russian client yet. How it differs:
--   * "нанося 40 ед. урона от темной магии за 12 сек." (40 Shadow damage over 12 sec), or "в течение 12 сек.";
--     Moonfire leaves out "ед.": "12 дополнительного урона от тайной магии в течение 9 сек."
--   * the school follows "урона": "от огня", "от темной магии", "от сил природы", "от магии льда", "от светлой
--     магии", "от тайной магии"; bleeds name none, or are worded as lost health: "теряет 15 ед. здоровья за 9 сек."
--   * finishers: "Завершающий прием", then "5 приемов: 189 ед. урона за 12 сек." per combo point count
--   * builders: "Длина серии приемов увеличивается на 1."
-- Wowhead spells "е" where the client may print "ё" (приём, тёмной): the patterns accept both.
-- Digits are spelled [0-9] next to Cyrillic text (multibyte), as in the Korean and Chinese files.

local _, flare = ...
local ns = flare.DotEngine -- the tracker's own namespace (Namespace.lua), apart from FlareUI's

local PHYSICAL = 1

-- School words between "урона" and the duration, combined schools first (Frostfire Bolt: fire and frost together).
local function schoolFromWords(words)
    local fire, frost = words:find("огн", 1, true), words:find("льд", 1, true)
    if fire and frost then return 4 + 16 end
    if words:find("темн", 1, true) or words:find("тёмн", 1, true) then return 32 end
    if fire then return 4 end
    if words:find("природ", 1, true) then return 8 end
    if frost then return 16 end
    if words:find("светл", 1, true) then return 2 end
    if words:find("тайн", 1, true) then return 64 end
    return PHYSICAL
end

-- Russian names of the spells in DoesItDie.lua's name-keyed tables (Forever's, from Wowhead). Names the client
-- reports by spell ID are added at load anyway (Locale.lua), so these mostly matter for the tests.
local NAMES = {
    ["Insect Swarm"] = { "Рой насекомых" },
    ["Bane of Agony"] = { "Бич агонии" },
    ["Curse of Agony"] = { "Проклятие агонии" }, -- Classic's name; unverified on Forever
    ["Corruption"] = { "Порча" },
    ["Fireball"] = { "Огненный шар" },
    ["Holy Fire"] = { "Священный огонь" },
    ["Rip"] = { "Разорвать" },
    ["Rupture"] = { "Рваная рана" },
    ["Siphon Life"] = { "Вытягивание жизни" },
    ["Serpent Sting"] = { "Укус змеи" },
    ["Pyroblast"] = { "Огненная глыба" },
    ["Rain of Fire"] = { "Огненный ливень" },
    ["Hellfire"] = { "Адское Пламя", "Адское пламя" },
    ["Blizzard"] = { "Снежная буря" },
    ["Flamestrike"] = { "Огненный столб" },
    ["Consecration"] = { "Освящение" },
    ["Hurricane"] = { "Гроза" },
    ["Volley"] = { "Град стрел" },
    ["Drain Life"] = { "Похищение жизни" },
    ["Drain Soul"] = { "Похищение души" },
    ["Drain Mana"] = { "Похищение маны" },
    ["Health Funnel"] = { "Канал здоровья" },
    ["Mind Flay"] = { "Пытка разума" },
    ["Arcane Missiles"] = { "Чародейские снаряды" },
    ["Starshards"] = { "Звездные осколки", "Звёздные осколки" },
    ["Immolation Trap"] = { "Обжигающая ловушка" },
    ["Explosive Trap"] = { "Взрывная ловушка" },
}

-- Decimal commas ("1,5 сек." -> "1.5 сек.") and thousands separators ("1 132", plain or non-breaking space).
local function normalize(desc)
    desc = desc:gsub("([0-9]),([0-9])", "%1.%2")
    desc = desc:gsub("([0-9])\194\160([0-9][0-9][0-9])%f[^0-9]", "%1%2")
    return (desc:gsub("([0-9]) ([0-9][0-9][0-9])%f[^0-9]", "%1%2"))
end

local function isFinisher(desc)
    return desc:find("Завершающий при", 1, true) ~= nil
end

-- "Длина серии приемов увеличивается на 1." (Rake, Sinister Strike, Garrote).
local function comboPointsAwarded(desc)
    return tonumber(desc:match("Длина серии [^0-9]-увеличивается на ([0-9]+)"))
end

-- "5 приемов: 189 ед. урона за 12 сек." per combo point count (Rip, Rupture).
local function parseFinisher(desc, comboPoints)
    local byPoints, highest = {}, 0
    for pts, amount, secs in desc:gmatch("([0-9]+) при[^:\n]-: *([0-9]+) ед%. урона за ([0-9]+%.?[0-9]*) сек") do
        local points = tonumber(pts)
        byPoints[points] = { total = tonumber(amount), duration = tonumber(secs) }
        highest = math.max(highest, points)
    end
    if highest == 0 then return nil end
    local entry = byPoints[math.max(1, math.min(comboPoints, highest))] or byPoints[highest]
    return entry.total, PHYSICAL, entry.duration
end

-- The last "<amount> ... <noun> ... за/в течение <secs> сек." clause in the description, so a direct hit first
-- (Immolate, Moonfire, Fireball) yields the periodic part. No digits between the amount and the duration.
local function lastClause(desc, noun)
    local bestAt, total, words, duration
    for _, lead in ipairs({ " за ", " в течение " }) do
        local pattern = "()([0-9]+)[^0-9]-" .. noun .. "([^0-9]-)" .. lead .. "([0-9]+%.?[0-9]*) сек"
        for at, amount, between, secs in desc:gmatch(pattern) do
            if not bestAt or at > bestAt then bestAt, total, words, duration = at, amount, between, secs end
        end
    end
    if bestAt then return tonumber(total), words, tonumber(duration), bestAt end
end

-- FlareUI: the damage dealt at once, before the DoT (Locale.lua L.directPart): what the text says ahead of its
-- periodic clause. "нанося 90 ед. урона от огня и еще 160 ед. урона от огня за 15 сек." -> 90 (Immolate);
-- "теряет 27 и дополнительно 60 здоровья за 9 сек." -> 27 (Rake); nothing ahead of it -> 0 (Corruption).
-- nil when there are numbers ahead that aren't read as damage: better not to learn than to learn wrong.
local function directPart(desc)
    desc = normalize(desc)
    if isFinisher(desc) then return 0 end
    local _, _, duration, at = lastClause(desc, "урона")
    if not (at and duration and duration > 0) and desc:find("теряет", 1, true) then
        _, _, duration, at = lastClause(desc, "здоровья")
    end
    if not (at and duration and duration > 0) then return nil end
    local head = desc:sub(1, at - 1)
    if not head:find("[0-9]") then return 0 end
    local low, high = head:match("от ([0-9]+) до ([0-9]+)")
    if low then return (tonumber(low) + tonumber(high)) / 2 end
    local amount
    for found in head:gmatch("([0-9]+)[^0-9]-урона") do amount = found end
    amount = amount or head:match("теряет ([0-9]+)")
    return tonumber(amount)
end

local function parseDot(desc, comboPoints)
    desc = normalize(desc)
    if isFinisher(desc) then return parseFinisher(desc, comboPoints or 5) end
    -- Weapon poisons ("Смазать оружие ядом") are proc DoTs, not cast on the target.
    if desc:find("Смазать оружие", 1, true) then return nil end

    local total, words, duration = lastClause(desc, "урона")
    if total and duration > 0 then return total, schoolFromWords(words), duration end

    -- Bleeds worded as lost health: "теряет 15 ед. здоровья за 9 сек." (Rend), "Противник теряет 27 и
    -- дополнительно 60 здоровья за 9 сек." (Rake). Only with "теряет", so a heal over time is never read.
    if desc:find("теряет", 1, true) then
        total, words, duration = lastClause(desc, "здоровья")
        if total and duration > 0 then return total, PHYSICAL, duration end
    end

    -- A drain stated as a rate: "Вы похищаете у цели 11 ед. здоровья раз в 3 сек. ... Время действия – 30 сек."
    -- (Siphon Life; its school comes from SCHOOL_BY_NAME). Drain Life reads the same way but is ignored by name.
    local amount, every = desc:match("похищаете у цели ([0-9]+) ед%. здоровья раз в ([0-9]+%.?[0-9]*) сек")
    local lasts = desc:match("Время действия [^0-9]-([0-9]+%.?[0-9]*) сек")
    if amount and every and lasts then
        every, lasts = tonumber(every), tonumber(lasts)
        if every > 0 and lasts > 0 then
            return tonumber(amount) * math.floor(lasts / every + 0.5), PHYSICAL, lasts, every
        end
    end
end

-- The options window in this language: English text -> translation (see T in Locale.lua). Untranslated text
-- stays English. Every key, ready to fill in: python tools/test_load.py --dump-strings strings.lua
-- Translated by donesvad (PR #33).
local STRINGS = {
    ["%d learned tick sizes"] = "%d изученных интервалов тиков",
    ["%d, every %gs (%gs)"] = "%d, каждые %g с (%g с)",
    ["(%d-%d shown; scroll for more)"] = "(показаны %d-%d, прокрутите для остальных)",
    ["/did - open the options window"] = "/did - открыть окно настроек",
    ["/did debug - toggle echoing the trace log (casts, ticks, estimates) to chat"] = "/did debug - включить или выключить вывод журнала (применения заклинаний, тики, оценки) в чат",
    ["/did exec [percent] - test showing when the target is below 20% (or the given percent); again to stop"] = "/did exec [процент] - проверить отображение при здоровье цели ниже 20% (или указанного процента); повторить для остановки",
    ["/did line - toggle health bar markers on/off"] = "/did line - включить или выключить маркеры на полосе здоровья",
    ["/did plates - check what the addon can reach on visible nameplates (logged)"] = "/did plates - проверить доступные элементы видимых индикаторов здоровья (результат записывается в журнал)",
    ["/did reset - forget learned tick sizes"] = "/did reset - забыть изученные интервалы тиков",
    ["/did skull - show the kill icon for 5 seconds to check its position"] = "/did skull - показать значок добивания на 5 секунд для проверки его положения",
    ["/did ticks - show learned tick sizes"] = "/did ticks - показать изученные интервалы тиков",
    ["1 learned tick size"] = "1 изученный интервал тика",
    ["A bright flare on the marker's edge when a DoT lands."] = "Яркая вспышка на краю маркера при наложении периодического эффекта.",
    ["Above the health bar"] = "Над полосой здоровья",
    ["Advanced"] = "Дополнительно",
    ["Always (real ticks only)"] = "Всегда (только реальные тики)",
    ["Animates the diagonal stripes fill."] = "Анимирует диагональные полосы заливки.",
    ["Auto (game client)"] = "Автоматически (язык клиента игры)",
    ["Black"] = "Чёрный",
    ["Bonus"] = "Бонус",
    ["Boss skull"] = "Череп босса",
    ["By spell school"] = "По школе магии",
    ["Centered on the bar"] = "По центру полосы",
    ["Classic"] = "Классический",
    ["Click where the kill icon should go (you may need to move this window). Right-click cancels."] = "Нажмите там, где должен находиться значок добивания (возможно, окно придётся переместить). Щелчок правой кнопкой отменяет действие.",
    ["Click your target's health bar (you may need to move this window). Right-click cancels."] = "Нажмите на полосу здоровья цели (возможно, окно придётся переместить). Щелчок правой кнопкой отменяет действие.",
    ["Color"] = "Цвет",
    ["Combo"] = "Комбо",
    ["Combo points"] = "Очки серии приёмов",
    ["Copy from Marker tab"] = "Скопировать со вкладки «Маркер»",
    ["Copy from Nameplates tab"] = "Скопировать со вкладки «Индикаторы здоровья»",
    ["Cyan"] = "Голубой",
    ["Dash length"] = "Длина штриха",
    ["Dashed"] = "Пунктир",
    ["Dashes (8px)"] = "Штрихи (8 пикс.)",
    ["Debug"] = "Отладка",
    ["Diagonal stripes"] = "Диагональные полосы",
    ["Different color per DoT"] = "Отдельный цвет для каждого эффекта",
    ["Dividers between DoTs"] = "Разделители между эффектами",
    ["DoT colors"] = "Цвета периодического урона",
    ["DoT damage"] = "Урон периодического эффекта",
    ["DoTs finish it: the kill icon shows"] = "Периодический урон добьёт цель: появится значок добивания",
    ["Dots (2px)"] = "Точки (2 пикс.)",
    ["Draws a marker (and optionally the kill icon) on every enemy nameplate with your DoTs on it, in its own look below."] = "Показывает маркер (и, при необходимости, значок добивания) на каждом индикаторе здоровья противника, на котором действуют ваши периодические эффекты. Внешний вид настраивается ниже.",
    ["Draws the marker (and optionally the kill icon) on your focus's health bar, for your DoTs on it, in its own look below. /cast [@focus] macros put the DoT on your focus. For another addon's focus frame, see the Advanced tab."] = "Показывает маркер (и, при необходимости, значок добивания) на полосе здоровья вашей цели фокуса, если на ней действуют ваши периодические эффекты. Макросы /cast [@focus] накладывают эффект на фокус. Для рамки фокуса из другого аддона смотрите вкладку «Дополнительно».",
    ["Echo trace log to chat"] = "Выводить журнал отладки в чат",
    ["Effects"] = "Эффекты",
    ["English"] = "Английский",
    ["English text"] = "Английский текст",
    ["Estimate during casting"] = "Оценивать во время произнесения",
    ["Fade in from left"] = "Появление слева",
    ["Fill color"] = "Цвет заливки",
    ["Fill opacity"] = "Непрозрачность заливки",
    ["Fill style"] = "Стиль заливки",
    ["Fine dots (1px)"] = "Мелкие точки (1 пикс.)",
    ["Flash"] = "Вспышка",
    ["Flash on new DoT"] = "Вспышка при новом эффекте",
    ["Flat"] = "Плоская",
    ["Focus"] = "Фокус",
    ["Focus bar in use"] = "Используемая полоса здоровья фокуса",
    ["Focus health bar"] = "Полоса здоровья фокуса",
    ["For unit frame addons that replace Blizzard's focus frame. Focus something, click Pick, then click its health bar. Leave empty for Blizzard's, or EllesmereUI's when it shows its own focus frame."] = "Для аддонов рамок юнитов, заменяющих рамку фокуса Blizzard. Установите фокус, нажмите «Выбрать», затем нажмите на его полосу здоровья. Оставьте поле пустым для рамки Blizzard или EllesmereUI, если она показывает собственную рамку фокуса.",
    ["For unit frame addons that replace Blizzard's target frame. Target something, click Pick, then click its health bar. Or type the frame's name (/fstack shows it). The bar must fill left to right. Leave empty for Blizzard's, or EllesmereUI's when it shows its own target frame."] = "Для аддонов рамок юнитов, заменяющих рамку цели Blizzard. Выберите цель, нажмите «Выбрать», затем нажмите на её полосу здоровья. Либо введите имя рамки вручную (/fstack показывает его). Полоса должна заполняться слева направо. Оставьте поле пустым для рамки Blizzard или EllesmereUI, если она показывает собственную рамку цели.",
    ["Forget all"] = "Забыть всё",
    ["Forget this tick size"] = "Забыть этот интервал тика",
    ["Full duration"] = "Полная длительность",
    ["Gently pulses the icon while it's showing."] = "Значок плавно пульсирует, пока отображается.",
    ["Glow"] = "Свечение",
    ["Glow size"] = "Размер свечения",
    ["Gold"] = "Золотой",
    ["Green"] = "Зелёный",
    ["Green checkmark"] = "Зелёная галочка",
    ["Health bar in use"] = "Используемая полоса здоровья",
    ["Health bar texture"] = "Текстура полосы здоровья",
    ["Horizontal offset"] = "Смещение по горизонтали",
    ["Icon"] = "Значок",
    ["Icon horizontal offset"] = "Смещение значка по горизонтали",
    ["Icon vertical offset"] = "Смещение значка по вертикали",
    ["In combat: the marker and kill icon are showing on your target. The preview resumes after combat."] = "В бою маркер и значок добивания отображаются на вашей цели. Предпросмотр возобновится после боя.",
    ["Inside the bar, right end"] = "Внутри полосы, у правого края",
    ["Juicy"] = "Насыщенный",
    ["Kill icon"] = "Значок добивания",
    ["Kill icon in use"] = "Используемый значок добивания",
    ["Kill icon position"] = "Положение значка добивания",
    ["Kill icon size"] = "Размер значка добивания",
    ["Kill icon spot"] = "Место для значка добивания",
    ["Learned from this spell's ticks on your targets; used instead of the tooltip's number, which leaves out spell power and attack power."] = "Значение вычислено по тикам этого заклинания на ваших целях. Оно используется вместо числа из подсказки, в котором не учитываются сила заклинаний и сила атаки.",
    ["Learned per tick"] = "Изученный урон за тик",
    ["Learned tick sizes"] = "Изученные значения тиков",
    ["Left of the bar"] = "Слева от полосы",
    ["Left of the health bar"] = "Слева от полосы здоровья",
    ["Live preview"] = "Предпросмотр",
    ["Long dashes (16px)"] = "Длинные штрихи (16 пикс.)",
    ["Marker"] = "Маркер",
    ["Marker and kill icon"] = "Маркер и значок добивания",
    ["Marker only"] = "Только маркер",
    ["Marks the damage your DoTs still have to deal on the target's health bar. If the health ends inside it, the target dies."] = "Отмечает на полосе здоровья цели урон, который ещё нанесут ваши периодические эффекты. Если здоровье заканчивается внутри маркера, цель погибает.",
    ["Minimal"] = "Минималистичный",
    ["Most nameplate addons' health bars are found automatically (Plater, EllesmereUI, Platynator, ...). If the marker doesn't show on yours, type the keys from Blizzard's nameplate to its bar, like unitFrame.healthBar. /did plates logs what each plate uses. Leave empty for automatic."] = "Полосы здоровья большинства аддонов индикаторов находятся автоматически (Plater, EllesmereUI, Platynator и другие). Если маркер не отображается, укажите путь от индикатора Blizzard до его полосы, например unitFrame.healthBar. Команда /did plates записывает используемые пути в журнал. Оставьте поле пустым для автоматического поиска.",
    ["Mottled Boar"] = "Пятнистый вепрь",
    ["Nameplate"] = "Индикатор здоровья",
    ["Nameplate bar in use"] = "Используемая полоса индикатора",
    ["Nameplate health bar"] = "Полоса здоровья индикатора",
    ["Nameplates"] = "Индикаторы здоровья",
    ["Never (estimate straight away)"] = "Никогда (сразу оценивать)",
    ["No DoTs on the target"] = "На цели нет периодических эффектов",
    ["None"] = "Нет",
    ["Nothing learned yet. Tick sizes are learned as your DoTs tick on your targets."] = "Пока ничего не изучено. Значения тиков изучаются по мере срабатывания ваших периодических эффектов на целях.",
    ["Off"] = "Выкл.",
    ["One color (fill color)"] = "Один цвет (цвет заливки)",
    ["One color, or one segment per DoT colored by spell school or with a different color each."] = "Один цвет или отдельный сегмент для каждого периодического эффекта: по школе магии или разными цветами.",
    ["Open DoesItDie options"] = "Открыть настройки DoesItDie",
    ["Orange"] = "Оранжевый",
    ["Outline"] = "Контур",
    ["Outline color"] = "Цвет контура",
    ["Outline opacity"] = "Непрозрачность контура",
    ["Outline thickness"] = "Толщина контура",
    ["Per tick"] = "За тик",
    ["Pick"] = "Выбрать",
    ["Picked %s."] = "Выбрано: %s.",
    ["Pink"] = "Розовый",
    ["Pixels right (+) or left (-) of the chosen position."] = "Смещение в пикселях вправо (+) или влево (-) от выбранной позиции.",
    ["Pixels right (+) or left (-) of the portrait's center (or the custom spot's, see Advanced)."] = "Смещение в пикселях вправо (+) или влево (-) от центра портрета (или заданного места, см. «Дополнительно»).",
    ["Pixels up (+) or down (-) from the chosen position."] = "Смещение в пикселях вверх (+) или вниз (-) от выбранной позиции.",
    ["Pixels up (+) or down (-) from the portrait's center (or the custom spot's, see Advanced)."] = "Смещение в пикселях вверх (+) или вниз (-) от центра портрета (или заданного места, см. «Дополнительно»).",
    ["Position"] = "Положение",
    ["Presets"] = "Пресеты",
    ["Prints each DoT cast, matched tick and estimate to chat."] = "Выводит в чат каждое применение периодического эффекта, соответствующий тик и оценку урона.",
    ["Pulse"] = "Пульсация",
    ["Pulse outline"] = "Пульсация контура",
    ["Purple"] = "Фиолетовый",
    ["Raid bar texture"] = "Текстура полосы рейда",
    ["Raid skull"] = "Рейдовый череп",
    ["Red"] = "Красный",
    ["Red X"] = "Красный крест",
    ["Remaining DoT damage next to the health bar (a per-DoT breakdown with DoT colors)."] = "Оставшийся периодический урон рядом с полосой здоровья (с разбивкой по эффектам и их цветам).",
    ["Remaining damage of two sample DoTs, in % of the target's max health."] = "Оставшийся урон двух примеров периодических эффектов в процентах от максимального здоровья цели.",
    ["Reset"] = "Сбросить",
    ["Reset this tab"] = "Сбросить эту вкладку",
    ["Right of the health bar"] = "Справа от полосы здоровья",
    ["Scroll stripes"] = "Движение полос",
    ["Settings have their own window with a live preview. You can also type /did."] = "Настройки открываются в отдельном окне с предпросмотром. Также можно ввести /did.",
    ["Shift-click to link it in chat."] = "Shift+щелчок, чтобы добавить ссылку в чат.",
    ["Shine every"] = "Интервал блеска",
    ["Shine sweep"] = "Блик",
    ["Short dashes (4px)"] = "Короткие штрихи (4 пикс.)",
    ["Show damage marker"] = "Показывать маркер урона",
    ["Show damage text"] = "Показывать значение урона",
    ["Show icon on portrait"] = "Показывать значок на портрете",
    ["Show on focus frame"] = "Показывать на рамке фокуса",
    ["Show on nameplates"] = "Показывать на индикаторах здоровья",
    ["Shows a DoT with a cast time while you're still casting it. Once the cast lands the normal estimate takes over; an interrupted or failed cast removes it."] = "Показывает периодический эффект с временем произнесения, пока вы его применяете. После успешного применения используется обычная оценка; прерванное или неудачное применение удаляет его.",
    ["Shows an icon over the target's portrait when your DoTs on it will kill it."] = "Показывает значок над портретом цели, если ваши периодические эффекты её добьют.",
    ["Simulate fight"] = "Симулировать бой",
    ["Size"] = "Размер",
    ["Smooth motion"] = "Плавное движение",
    ["Soft halo in the outline color."] = "Мягкое свечение цветом контура.",
    ["Solid"] = "Сплошной",
    ["Spark"] = "Искра",
    ["Spell"] = "Заклинание",
    ["Stop"] = "Остановить",
    ["Sunglasses"] = "Солнечные очки",
    ["Survives by %d%% of its health"] = "У цели останется %d%% здоровья",
    ["Target health"] = "Здоровье цели",
    ["Target health bar"] = "Полоса здоровья цели",
    ["Test"] = "Тест",
    ["Text"] = "Текст",
    ["The kill icon on the target's portrait means your DoTs will kill it."] = "Значок добивания на портрете цели означает, что ваши периодические эффекты её убьют.",
    ["The language of this window and the addon's messages. Auto follows your game client. Changes apply after /reload."] = "Язык этого окна и сообщений аддона. В режиме «Автоматически» используется язык клиента игры. Изменения применяются после /reload.",
    ["The marker grows in when it appears and glides to new values instead of jumping."] = "Маркер плавно появляется и перемещается к новым значениям вместо резких скачков.",
    ["The next cast starts from the tooltip again and learns it anew."] = "При следующем применении значение снова берётся из подсказки и изучается заново.",
    ["The window language changes after a /reload."] = "Язык окна изменится после /reload.",
    ["Ticks"] = "Тики",
    ["Tooltip"] = "Подсказка",
    ["Tooltip per tick"] = "По подсказке за тик",
    ["Total"] = "Всего",
    ["Used when DoT colors is set to one color."] = "Используется, когда для периодического урона выбран один цвет.",
    ["Vertical offset"] = "Смещение по вертикали",
    ["View"] = "Вид",
    ["Wait for first tick"] = "Ждать первого тика",
    ["What each DoT really ticks for, learned from your casts and used instead of its tooltip. Tooltips leave out spell power and attack power: Bonus is how much more yours do. Hover a spell for details, shift-click to link it."] = "Фактический урон за тик каждого периодического эффекта, изученный по вашим применениям и используемый вместо значения из подсказки. Подсказки не учитывают силу заклинаний и силу атаки: бонус показывает разницу. Наведите курсор на заклинание для подробностей, Shift+щелчок добавит ссылку.",
    ["What each of your DoTs really ticks for, learned from earlier casts, next to what its tooltip says. Reset forgets them all."] = "Фактический урон за тик каждого вашего периодического эффекта, изученный по предыдущим применениям, рядом со значением из подсказки. Кнопка «Сбросить» удаляет все изученные значения.",
    ["When unsure"] = "Если неизвестно",
    ["Where the kill icon is centered (e.g. the custom frame's portrait). Empty: Blizzard's portrait, or EllesmereUI's when its target frame shows one; else the health bar in use. Fine-tune with the offsets on the Kill icon tab."] = "Где будет центр значка добивания (например, портрет в пользовательской рамке). Пустое поле: портрет Blizzard или EllesmereUI, если рамка цели показывает его; иначе используется полоса здоровья. Точную позицию можно настроить смещениями на вкладке «Значок добивания».",
    ["Whether a new DoT counts before its first tick lands. \"When unsure\" waits for finishers with unknown combo points and spells the addon hasn't seen tick yet."] = "Учитывать ли новый периодический эффект до первого тика. Режим «Если неизвестно» ожидает для завершающих приёмов с неизвестным количеством очков серии и для заклинаний, тики которых аддон ещё не наблюдал.",
    ["While this window is open, the marker and kill icon are drawn here instead of on your target."] = "Пока это окно открыто, маркер и значок добивания отображаются здесь, а не на вашей цели.",
    ["White"] = "Белый",
    ["Window language"] = "Язык окна",
    ["%s preset applied."] = "Пресет «%s» применён.",
    ["Couldn't create the options panel; slash commands still work (/did help)."] = "Не удалось создать панель настроек; slash-команды продолжают работать (/did help).",
    ["Debug OFF."] = "Отладка выключена.",
    ["Debug ON."] = "Отладка включена.",
    ["Frame pick cancelled."] = "Выбор рамки отменён.",
    ["Health bar markers OFF."] = "Маркеры на полосе здоровья выключены.",
    ["Health bar markers ON."] = "Маркеры на полосе здоровья включены.",
    ["Kill icon test for 5 seconds: one icon ON the portrait (the real one) and one ABOVE it (plain test)."] = "Тест значка добивания на 5 секунд: один значок НА портрете (настоящий), второй НАД ним (обычный тестовый).",
    ["Learned tick sizes cleared."] = "Изученные значения тиков очищены.",
    ["Nothing to pick there."] = "В этом месте нечего выбрать.",
    ["Target frame health bar not found; health bar markers unavailable."] = "Полоса здоровья рамки цели не найдена; маркеры на полосе здоровья недоступны.",
    ["Target portrait not found; kill icon shown beside the target frame."] = "Портрет цели не найден; значок добивания показан рядом с рамкой цели.",
    ["That frame has no name to save, so it can't be found again after a reload. Try the frame around it, or type a path."] = "У этой рамки нет имени, поэтому после перезагрузки её не удастся найти. Попробуйте выбрать внешнюю рамку или введите путь вручную.",
}

ns.locale.register({
    tag = "ruRU",
    label = "Русский",
    strings = STRINGS,
    parseDot = parseDot,
    directPart = directPart,
    isFinisher = function(desc) return isFinisher(normalize(desc)) end,
    comboPointsAwarded = comboPointsAwarded,
    names = NAMES,
})
