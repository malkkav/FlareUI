-- Part of FlareUI's DoT tracker. Taken from Does It Die Advanced 1.3.7 by WhiteKnight / Smuggz_, itself based on
-- Does It Die by JoeGG (MIT License, Copyright (c) 2026 Joe Greive: LICENSES/DoesItDieAdvanced.txt), and changed for
-- FlareUI: its own namespace; nothing else.
-- DoesItDie: German (deDE) spell descriptions and names. Registers itself with Locale.lua.
-- The German patterns only see descriptions the English ones didn't read, and can't match English text (they need
-- "Sek", "Schaden", "Punkt").
--
-- The German wording is Classic Era deDE (Wowhead and Blizzard API tooltips); Forever's own German text is
-- unverified. How it differs from English:
--   * the duration usually comes first: "verursacht 12 Sek. lang 40 Punkt(e) Schattenschaden", but not always:
--     "75 Schattenschaden im Verlauf von 3 Sek." (Mind Flay), and it can change between ranks (Wyvern Sting)
--   * the school is glued to the noun: Schattenschaden, Feuerschaden; plain "Schaden" is physical
--   * numbers: "1.132" is a thousand one hundred and thirty-two, "7,1 Sek." is seven point one seconds

local _, flare = ...
local ns = flare.DotEngine -- the tracker's own namespace (Namespace.lua), apart from FlareUI's

local PHYSICAL = 1

-- The school word glued to "schaden", lower-cased. Anything else (Blutungs-, Vulkan-) counts as physical, like
-- an English school word missing from SCHOOL_MASKS.
local SCHOOLS = {
    heilig = 2, feuer = 4, natur = 8, frost = 16, schatten = 32, arkan = 64,
    frostfeuer = 4 + 16,
}

-- Words that may sit between the amount and "...schaden": "40 Punkt(e) Schattenschaden", "20 zusätzlichen
-- Feuerschaden", "42 körperlichen Schaden". Longer spellings first ("zusätzlichen" before "zusätzlich").
local FILLERS = { "Punkt%(en%)", "Punkt%(e%)", "Punkte", "Punkt", "zusätzlichen", "zusätzlich", "insgesamt", "körperlichen" }

-- Where a DoT's duration stands before its amount: "12 Sek. lang", "im Verlauf von 12 Sek.", "über 12 Sek.",
-- also written out ("über 8 Sekunden"). Captures: start, seconds, end.
local DURATION_FIRST = {
    "()(%d+%.?%d*) Sek%a*%.? lang()",
    "()im Verlauf von (%d+%.?%d*) Sek%a*%.?()",
    "()über (%d+%.?%d*) Sek%a*%.?()",
}
-- Where it stands after: "75 Schattenschaden im Verlauf von 3 Sek.", "39 Punkt(e) zusätzlichen Schaden über 9 Sek."
-- Captures: start, amount, words before "schaden", seconds.
local DURATION_AFTER = {
    "()(%d+)([^%d%.\n]-)[Ss]chaden%s+im Verlauf von (%d+%.?%d*) Sek",
    "()(%d+)([^%d%.\n]-)[Ss]chaden%s+über (%d+%.?%d*) Sek",
}

-- Finisher lines between the amount and the seconds: "1 Punkt: 40 Schaden über 8 Sekunden." (Rupture),
-- "2 Punkte: 66 Schaden im Verlauf von 12 Sek." (Rip); Retail leaves out "Schaden".
local FINISHER_LINE_WORDS = {
    ["Schaden über"] = true, ["Schaden im Verlauf von"] = true, ["über"] = true, ["im Verlauf von"] = true,
}

-- German names of the spells in DoesItDie.lua's name-keyed tables: C_Spell.GetSpellName returns these on a German
-- client.
local NAMES = {
    ["Insect Swarm"] = { "Insektenschwarm" },
    ["Curse of Agony"] = { "Fluch der Pein" },
    ["Bane of Agony"] = { "Omen der Pein" }, -- Cataclysm's German name; Forever's is unverified
    ["Fireball"] = { "Feuerball" },
    ["Holy Fire"] = { "Heiliges Feuer" },
    ["Rip"] = { "Zerfetzen" },
    ["Rupture"] = { "Blutung" },
    ["Siphon Life"] = { "Lebensentzug" },
    ["Rain of Fire"] = { "Feuerregen" },
    ["Hellfire"] = { "Höllenfeuer" },
    ["Blizzard"] = { "Blizzard" },
    ["Flamestrike"] = { "Flammenstoß" },
    ["Consecration"] = { "Weihe" },
    ["Hurricane"] = { "Hurrikan" },
    ["Volley"] = { "Salve" },
    ["Drain Life"] = { "Blutsauger" },
    ["Drain Soul"] = { "Seelendieb" },
    ["Drain Mana"] = { "Mana entziehen" },
    ["Health Funnel"] = { "Lebenslinie" },
    ["Mind Flay"] = { "Gedankenschinden" },
    ["Arcane Missiles"] = { "Arkane Geschosse" },
    ["Starshards"] = { "Sternensplitter" },
    ["Immolation Trap"] = { "Feuerbrandfalle" },
    ["Explosive Trap"] = { "Sprengfalle" },
    ["Wyvern Sting"] = { "Stich des Flügeldrachen" },
}

local function isFinisher(desc)
    return desc:find("Finishing%-Move") ~= nil
end

-- "Gewährt 1 Combopunkt." (Retail: "Gewährt für jeden Treffer 1 Combopunkt.")
local function comboPointsAwarded(desc)
    return tonumber(desc:match("Gewährt[^%.]-(%d+) Combopunkt"))
end

-- German number formats to Lua's: "1.132" -> "1132", "7,1" -> "7.1".
local function plainNumbers(desc)
    local text, count = desc, 1
    while count > 0 do text, count = text:gsub("(%d)%.(%d%d%d)%f[%D]", "%1%2") end
    return (text:gsub("(%d),(%d)", "%1.%2"))
end

-- The school of "<amount><words>schaden", or nil if `words` holds more than fillers and a school word.
local function schoolFromWords(words)
    for _, filler in ipairs(FILLERS) do words = words:gsub(filler, " ") end
    local school = words:match("^%s*(%a*)$")
    if not school then return nil end
    return SCHOOLS[school:lower()] or PHYSICAL
end

-- The first "<amount> ...schaden" in `clause`: amount, school, and where it starts.
local function firstDamage(clause)
    for start, amount, words in clause:gmatch("()(%d+)([^%d]-)[Ss]chaden") do
        local school = schoolFromWords(words)
        if school then return tonumber(amount), school, start end
    end
end

-- Same shape as parseFinisher in DoesItDie.lua.
local function parseFinisher(text, comboPoints)
    local byPoints, highest = {}, 0
    for pointsText, amount, words, secs in text:gmatch("(%d+) Punkte?%s*:%s*(%d+)%s+([^%d\n]-)(%d+%.?%d*) Sek") do
        if FINISHER_LINE_WORDS[words:match("^(.-)%s*$")] then
            local points = tonumber(pointsText)
            byPoints[points] = { total = tonumber(amount), duration = tonumber(secs) }
            highest = math.max(highest, points)
        end
    end
    if highest == 0 then return nil end
    local entry = byPoints[math.max(1, math.min(comboPoints, highest))] or byPoints[highest]
    return entry.total, PHYSICAL, entry.duration
end

-- Same returns as parseDot in DoesItDie.lua: total damage, school mask, duration, stated tick interval.
--   "verursacht 12 Sek. lang 40 Punkt(e) Schattenschaden."  (Corruption)
--   "fügt ihm 11 Feuerschaden sowie im Verlauf von 15 Sek. insgesamt 20 zusätzlichen Feuerschaden zu."  (Immolate:
--       the clause after the duration holds the periodic part)
--   "lässt es 9 Sek. lang bluten und fügt damit 15 Punkt(e) Schaden zu."  (Rend: words in between)
--   "Überträgt alle 3 Sek. 15 Punkt(e) Gesundheit vom Ziel auf den Zaubernden. Hält 30 Sek. lang an."  (Siphon Life)
-- Like the English reader, the last DoT clause wins, and per-second channels ("6 Sek. lang pro Sekunde 50 ...")
-- and minutes ("Hält 1 Min. lang an") aren't read. Neither is a buff or debuff whose duration comes before direct
-- damage ("30 Sek. lang um 10% und fügt ihnen 103 Schaden zu"), which English words so that it isn't read either.
local function parseDot(desc, comboPoints)
    if isFinisher(desc) then return parseFinisher(plainNumbers(desc), comboPoints) end
    -- Rogue poisons: "Überzieht eine Waffe mit Gift", Retail "Überzieht Eure Waffen".
    if desc:find("Überzieht %a+ Waffe") then return nil end
    -- Heals over time: Rejuvenation reads "Heilt beim Ziel 12 Sek. lang 32 Punkt(e) Schaden."
    if desc:find("^Heilt") then return nil end
    local text = plainNumbers(desc)

    local best, total, school, duration
    for _, pattern in ipairs(DURATION_FIRST) do
        for start, secs, after in text:gmatch(pattern) do
            -- The amount follows in the same clause.
            local clause = text:sub(after):match("^[^%.\n]*")
            local amount, amountSchool, at = firstDamage(clause)
            -- Words between the duration and the amount that make it the duration of something else: per second
            -- (a channel), or a percentage (Thunder Clap: "erhöht die Zeit zwischen ihren Angriffen 30 Sek. lang um
            -- 10% und fügt ihnen 103 Schaden zu"; Holy Shield: "Erhöht die Blockchance 10 Sek. lang um 30% und
            -- verursacht ... 130 Heiligschaden").
            local between = amount and clause:sub(1, at - 1)
            if amount and not between:find("Sekunde") and not between:find("%%")
                and (not best or start > best) then
                best, total, school, duration = start, amount, amountSchool, tonumber(secs)
            end
        end
    end
    for _, pattern in ipairs(DURATION_AFTER) do
        for start, amount, words, secs in text:gmatch(pattern) do
            local amountSchool = schoolFromWords(words)
            if amountSchool and (not best or start > best) then
                best, total, school, duration = start, tonumber(amount), amountSchool, tonumber(secs)
            end
        end
    end
    if total and duration > 0 then return total, school, duration end

    -- "alle 1 Sek. 72 Naturschaden ... Hält 10 Sek. lang an."
    local every, amount, words = text:match("alle (%d+%.?%d*) Sek%a*%.?%s*(%d+)([^%d%.\n]-)[Ss]chaden")
    school = words and schoolFromWords(words)
    if not school then
        every, amount, words = text:match("alle (%d+%.?%d*) Sek%a*%.?%s*(%d+)([^%d%.\n]-)Gesundheit")
        school = words and schoolFromWords(words) and PHYSICAL
    end
    local lasts = text:match("Hält (%d+%.?%d*) Sek")
    if school and every and lasts then
        every, lasts = tonumber(every), tonumber(lasts)
        if every > 0 and lasts > 0 then
            return tonumber(amount) * math.floor(lasts / every + 0.5), school, lasts, every
        end
    end
end

-- The options window in this language: English text -> translation (see T in Locale.lua). Untranslated text
-- stays English. Every key, ready to fill in: python tools/test_load.py --dump-strings strings.lua
local STRINGS = {
    ["%d learned tick sizes"] = "%d gelernte Tickgrößen",
    ["%d, every %gs (%gs)"] = "%d, alle %gs (%gs)",
    ["(%d-%d shown; scroll for more)"] = "(%d-%d angezeigt; scrollen für mehr)",
    ["/did - open the options window"] = "/did - das Optionsfenster öffnen",
    ["/did debug - toggle echoing the trace log (casts, ticks, estimates) to chat"] = "/did debug - Ausgabe des Ablaufprotokolls (Zauber, Ticks, Schätzungen) im Chat umschalten",
    ["/did exec [percent] - test showing when the target is below 20% (or the given percent); again to stop"] = "/did exec [Prozent] - Anzeige testen, wenn das Ziel unter 20% (oder dem angegebenen Prozentwert) liegt; erneut eingeben zum Beenden",
    ["/did line - toggle health bar markers on/off"] = "/did line - Markierungen auf der Lebensleiste an-/ausschalten",
    ["/did plates - check what the addon can reach on visible nameplates (logged)"] = "/did plates - prüfen, worauf das Addon bei sichtbaren Namensplaketten zugreifen kann (wird protokolliert)",
    ["/did reset - forget learned tick sizes"] = "/did reset - gelernte Tickgrößen vergessen",
    ["/did skull - show the kill icon for 5 seconds to check its position"] = "/did skull - das Kill-Symbol 5 Sekunden lang anzeigen, um seine Position zu prüfen",
    ["/did ticks - show learned tick sizes"] = "/did ticks - gelernte Tickgrößen anzeigen",
    ["1 learned tick size"] = "1 gelernte Tickgröße",
    ["A bright flare on the marker's edge when a DoT lands."] = "Ein heller Funke am Rand der Markierung, wenn ein DoT trifft.",
    ["Above the health bar"] = "Über der Lebensleiste",
    ["Advanced"] = "Erweitert",
    ["Always (real ticks only)"] = "Immer (nur echte Ticks)",
    ["Animates the diagonal stripes fill."] = "Animiert die Füllung mit diagonalen Streifen.",
    ["Auto (game client)"] = "Automatisch (Spielclient)",
    ["Black"] = "Schwarz",
    ["Bonus"] = "Bonus",
    ["Boss skull"] = "Boss-Totenkopf",
    ["By spell school"] = "Nach Zauberschule",
    ["Centered on the bar"] = "Mittig auf der Leiste",
    ["Classic"] = "Klassisch",
    ["Click where the kill icon should go (you may need to move this window). Right-click cancels."] = "Klicke dorthin, wo das Kill-Symbol sitzen soll (eventuell musst du dieses Fenster verschieben). Rechtsklick bricht ab.",
    ["Click your target's health bar (you may need to move this window). Right-click cancels."] = "Klicke auf die Lebensleiste deines Ziels (eventuell musst du dieses Fenster verschieben). Rechtsklick bricht ab.",
    ["Color"] = "Farbe",
    ["Combo"] = "Combo",
    ["Combo points"] = "Combopunkte",
    ["Copy from Marker tab"] = "Vom Reiter Markierung kopieren",
    ["Copy from Nameplates tab"] = "Vom Reiter Namensplaketten kopieren",
    ["Cyan"] = "Cyan",
    ["Dash length"] = "Strichlänge",
    ["Dashed"] = "Gestrichelt",
    ["Dashes (8px)"] = "Striche (8px)",
    ["Debug"] = "Debug",
    ["Diagonal stripes"] = "Diagonale Streifen",
    ["Different color per DoT"] = "Eigene Farbe pro DoT",
    ["Dividers between DoTs"] = "Trennlinien zwischen DoTs",
    ["DoT colors"] = "DoT-Farben",
    ["DoT damage"] = "DoT-Schaden",
    ["DoTs finish it: the kill icon shows"] = "DoTs erledigen es: Das Kill-Symbol erscheint",
    ["Dots (2px)"] = "Punkte (2px)",
    ["Draws a marker (and optionally the kill icon) on every enemy nameplate with your DoTs on it, in its own look below."] = "Zeichnet eine Markierung (und optional das Kill-Symbol) auf jede gegnerische Namensplakette mit deinen DoTs, im eigenen Aussehen weiter unten.",
    ["Draws the marker (and optionally the kill icon) on your focus's health bar, for your DoTs on it, in its own look below. /cast [@focus] macros put the DoT on your focus. For another addon's focus frame, see the Advanced tab."] = "Zeichnet die Markierung (und optional das Kill-Symbol) auf die Lebensleiste deines Fokus, für deine DoTs darauf, im eigenen Aussehen weiter unten. Mit /cast-[@focus]-Makros wirkst du den DoT auf deinen Fokus. Für das Fokusfenster eines anderen Addons siehe Reiter Erweitert.",
    ["Echo trace log to chat"] = "Ablaufprotokoll im Chat ausgeben",
    ["Effects"] = "Effekte",
    ["English"] = "Englisch",
    ["English text"] = "Englischer Text",
    ["Estimate during casting"] = "Schätzen während des Zauberns",
    ["Fade in from left"] = "Von links einblenden",
    ["Fill color"] = "Füllfarbe",
    ["Fill opacity"] = "Fülldeckkraft",
    ["Fill style"] = "Füllstil",
    ["Fine dots (1px)"] = "Feine Punkte (1px)",
    ["Flash"] = "Aufblitzen",
    ["Flash on new DoT"] = "Aufblitzen bei neuem DoT",
    ["Flat"] = "Flach",
    ["Focus"] = "Fokus",
    ["Focus bar in use"] = "Verwendete Fokusleiste",
    ["Focus health bar"] = "Lebensleiste des Fokus",
    ["For unit frame addons that replace Blizzard's focus frame. Focus something, click Pick, then click its health bar. Leave empty for Blizzard's, or EllesmereUI's when it shows its own focus frame."] = "Für Einheitenfenster-Addons, die das Fokusfenster von Blizzard ersetzen. Setze einen Fokus, klicke auf Wählen und dann auf die Lebensleiste. Leer lassen für die von Blizzard oder die von EllesmereUI, wenn es ein eigenes Fokusfenster zeigt.",
    ["For unit frame addons that replace Blizzard's target frame. Target something, click Pick, then click its health bar. Or type the frame's name (/fstack shows it). The bar must fill left to right. Leave empty for Blizzard's, or EllesmereUI's when it shows its own target frame."] = "Für Einheitenfenster-Addons, die das Zielfenster von Blizzard ersetzen. Wähle ein Ziel, klicke auf Wählen und dann auf die Lebensleiste. Oder gib den Namen des Fensters ein (/fstack zeigt ihn an). Die Leiste muss sich von links nach rechts füllen. Leer lassen für die von Blizzard oder die von EllesmereUI, wenn es ein eigenes Zielfenster zeigt.",
    ["Forget all"] = "Alle vergessen",
    ["Forget this tick size"] = "Diese Tickgröße vergessen",
    ["Full duration"] = "Volle Dauer",
    ["Gently pulses the icon while it's showing."] = "Lässt das Symbol sanft pulsieren, solange es angezeigt wird.",
    ["Glow"] = "Leuchten",
    ["Glow size"] = "Leuchtgröße",
    ["Gold"] = "Gold",
    ["Green"] = "Grün",
    ["Green checkmark"] = "Grünes Häkchen",
    ["Health bar in use"] = "Verwendete Lebensleiste",
    ["Health bar texture"] = "Textur der Lebensleiste",
    ["Horizontal offset"] = "Horizontaler Versatz",
    ["Icon"] = "Symbol",
    ["Icon horizontal offset"] = "Horizontaler Symbolversatz",
    ["Icon vertical offset"] = "Vertikaler Symbolversatz",
    ["In combat: the marker and kill icon are showing on your target. The preview resumes after combat."] = "Im Kampf: Markierung und Kill-Symbol werden auf deinem Ziel angezeigt. Die Vorschau läuft nach dem Kampf weiter.",
    ["Inside the bar, right end"] = "In der Leiste, rechtes Ende",
    ["Juicy"] = "Knallig",
    ["Kill icon"] = "Kill-Symbol",
    ["Kill icon in use"] = "Verwendetes Kill-Symbol",
    ["Kill icon position"] = "Position des Kill-Symbols",
    ["Kill icon size"] = "Größe des Kill-Symbols",
    ["Kill icon spot"] = "Ort des Kill-Symbols",
    ["Learned from this spell's ticks on your targets; used instead of the tooltip's number, which leaves out spell power and attack power."] = "Aus den Ticks dieses Zaubers auf deinen Zielen gelernt; wird anstelle der Zahl aus dem Tooltip verwendet, die Zaubermacht und Angriffskraft nicht berücksichtigt.",
    ["Learned per tick"] = "Gelernt pro Tick",
    ["Learned tick sizes"] = "Gelernte Tickgrößen",
    ["Left of the bar"] = "Links der Leiste",
    ["Left of the health bar"] = "Links der Lebensleiste",
    ["Live preview"] = "Live-Vorschau",
    ["Long dashes (16px)"] = "Lange Striche (16px)",
    ["Marker"] = "Markierung",
    ["Marker and kill icon"] = "Markierung und Kill-Symbol",
    ["Marker only"] = "Nur Markierung",
    ["Marks the damage your DoTs still have to deal on the target's health bar. If the health ends inside it, the target dies."] = "Markiert auf der Lebensleiste des Ziels den Schaden, den deine DoTs noch verursachen. Endet die Gesundheit innerhalb der Markierung, stirbt das Ziel.",
    ["Minimal"] = "Minimal",
    ["Most nameplate addons' health bars are found automatically (Plater, EllesmereUI, Platynator, ...). If the marker doesn't show on yours, type the keys from Blizzard's nameplate to its bar, like unitFrame.healthBar. /did plates logs what each plate uses. Leave empty for automatic."] = "Die Lebensleisten der meisten Namensplaketten-Addons werden automatisch gefunden (Plater, EllesmereUI, Platynator, ...). Wenn die Markierung bei deinem nicht erscheint, gib die Schlüssel von Blizzards Namensplakette bis zu ihrer Leiste ein, z. B. unitFrame.healthBar. /did plates protokolliert, was jede Plakette verwendet. Leer lassen für automatisch.",
    ["Mottled Boar"] = "Gefleckter Eber",
    ["Nameplate"] = "Namensplakette",
    ["Nameplate bar in use"] = "Verwendete Plakettenleiste",
    ["Nameplate health bar"] = "Lebensleiste der Namensplakette",
    ["Nameplates"] = "Namensplaketten",
    ["Never (estimate straight away)"] = "Nie (sofort schätzen)",
    ["No DoTs on the target"] = "Keine DoTs auf dem Ziel",
    ["None"] = "Keine",
    ["Nothing learned yet. Tick sizes are learned as your DoTs tick on your targets."] = "Noch nichts gelernt. Tickgrößen werden gelernt, während deine DoTs auf deinen Zielen ticken.",
    ["Off"] = "Aus",
    ["One color (fill color)"] = "Eine Farbe (Füllfarbe)",
    ["One color, or one segment per DoT colored by spell school or with a different color each."] = "Eine Farbe oder ein Segment pro DoT, gefärbt nach Zauberschule oder jeweils in einer eigenen Farbe.",
    ["Open Does It Die Advanced options"] = "Does It Die Advanced-Optionen öffnen",
    ["Orange"] = "Orange",
    ["Outline"] = "Umrandung",
    ["Outline color"] = "Umrandungsfarbe",
    ["Outline opacity"] = "Umrandungsdeckkraft",
    ["Outline thickness"] = "Umrandungsstärke",
    ["Per tick"] = "Pro Tick",
    ["Pick"] = "Wählen",
    ["Picked %s."] = "%s gewählt.",
    ["Pink"] = "Rosa",
    ["Pixels right (+) or left (-) of the chosen position."] = "Pixel rechts (+) oder links (-) von der gewählten Position.",
    ["Pixels right (+) or left (-) of the portrait's center (or the custom spot's, see Advanced)."] = "Pixel rechts (+) oder links (-) von der Mitte des Porträts (oder des eigenen Ortes, siehe Erweitert).",
    ["Pixels up (+) or down (-) from the chosen position."] = "Pixel oberhalb (+) oder unterhalb (-) der gewählten Position.",
    ["Pixels up (+) or down (-) from the portrait's center (or the custom spot's, see Advanced)."] = "Pixel oberhalb (+) oder unterhalb (-) der Mitte des Porträts (oder des eigenen Ortes, siehe Erweitert).",
    ["Position"] = "Position",
    ["Presets"] = "Vorlagen",
    ["Prints each DoT cast, matched tick and estimate to chat."] = "Gibt jeden DoT-Zauber, zugeordneten Tick und jede Schätzung im Chat aus.",
    ["Pulse"] = "Pulsieren",
    ["Pulse outline"] = "Umrandung pulsieren lassen",
    ["Purple"] = "Lila",
    ["Raid bar texture"] = "Leistentextur (Schlachtzug)",
    ["Raid skull"] = "Schlachtzug-Totenkopf",
    ["Red"] = "Rot",
    ["Red X"] = "Rotes X",
    ["Remaining DoT damage next to the health bar (a per-DoT breakdown with DoT colors)."] = "Verbleibender DoT-Schaden neben der Lebensleiste (aufgeschlüsselt pro DoT in den DoT-Farben).",
    ["Remaining damage of two sample DoTs, in % of the target's max health."] = "Verbleibender Schaden zweier Beispiel-DoTs, in % der maximalen Gesundheit des Ziels.",
    ["Reset"] = "Zurücksetzen",
    ["Reset this tab"] = "Diesen Reiter zurücksetzen",
    ["Right of the health bar"] = "Rechts der Lebensleiste",
    ["Scroll stripes"] = "Streifen scrollen",
    ["Settings have their own window with a live preview. You can also type /did."] = "Die Einstellungen haben ein eigenes Fenster mit Live-Vorschau. Du kannst auch /did eingeben.",
    ["Shift-click to link it in chat."] = "Umschalt-Klick, um es im Chat zu verlinken.",
    ["Shine every"] = "Glanz alle",
    ["Shine sweep"] = "Glanzreflex",
    ["Short dashes (4px)"] = "Kurze Striche (4px)",
    ["Show damage marker"] = "Schadensmarkierung anzeigen",
    ["Show damage text"] = "Schadenstext anzeigen",
    ["Show icon on portrait"] = "Symbol auf dem Porträt anzeigen",
    ["Show on focus frame"] = "Auf dem Fokusfenster anzeigen",
    ["Show on nameplates"] = "Auf Namensplaketten anzeigen",
    ["Shows a DoT with a cast time while you're still casting it. Once the cast lands the normal estimate takes over; an interrupted or failed cast removes it."] = "Zeigt einen DoT mit Zauberzeit schon an, während du ihn noch wirkst. Sobald der Zauber trifft, übernimmt die normale Schätzung; ein unterbrochener oder fehlgeschlagener Zauber entfernt ihn.",
    ["Shows an icon over the target's portrait when your DoTs on it will kill it."] = "Zeigt ein Symbol über dem Porträt des Ziels, wenn deine DoTs es töten werden.",
    ["Simulate fight"] = "Kampf simulieren",
    ["Size"] = "Größe",
    ["Smooth motion"] = "Sanfte Bewegung",
    ["Soft halo in the outline color."] = "Weicher Schein in der Umrandungsfarbe.",
    ["Solid"] = "Durchgezogen",
    ["Spark"] = "Funke",
    ["Spell"] = "Zauber",
    ["Stop"] = "Stopp",
    ["Sunglasses"] = "Sonnenbrille",
    ["Survives by %d%% of its health"] = "Überlebt mit %d%% seiner Gesundheit",
    ["Target health"] = "Gesundheit des Ziels",
    ["Target health bar"] = "Lebensleiste des Ziels",
    ["Test"] = "Test",
    ["Text"] = "Text",
    ["The kill icon on the target's portrait means your DoTs will kill it."] = "Das Kill-Symbol auf dem Porträt des Ziels bedeutet, dass deine DoTs es töten werden.",
    ["The language of this window and the addon's messages. Auto follows your game client. Changes apply after /reload."] = "Die Sprache dieses Fensters und der Addon-Meldungen. Automatisch folgt deinem Spielclient. Änderungen gelten nach /reload.",
    ["The marker grows in when it appears and glides to new values instead of jumping."] = "Die Markierung wächst beim Erscheinen ein und gleitet zu neuen Werten, statt zu springen.",
    ["The next cast starts from the tooltip again and learns it anew."] = "Der nächste Zauber startet wieder mit dem Tooltip und lernt den Wert neu.",
    ["The window language changes after a /reload."] = "Die Fenstersprache ändert sich nach einem /reload.",
    ["Ticks"] = "Ticks",
    ["Tooltip"] = "Tooltip",
    ["Tooltip per tick"] = "Tooltip pro Tick",
    ["Total"] = "Gesamt",
    ["Used when DoT colors is set to one color."] = "Wird verwendet, wenn DoT-Farben auf eine Farbe eingestellt ist.",
    ["Vertical offset"] = "Vertikaler Versatz",
    ["View"] = "Ansicht",
    ["Wait for first tick"] = "Auf ersten Tick warten",
    ["What each DoT really ticks for, learned from your casts and used instead of its tooltip. Tooltips leave out spell power and attack power: Bonus is how much more yours do. Hover a spell for details, shift-click to link it."] = "Wie viel jeder DoT tatsächlich tickt, gelernt aus deinen Zaubern und anstelle des Tooltips verwendet. Tooltips berücksichtigen Zaubermacht und Angriffskraft nicht: Der Bonus zeigt, wie viel mehr deine verursachen. Fahre über einen Zauber für Details, Umschalt-Klick verlinkt ihn.",
    ["What each of your DoTs really ticks for, learned from earlier casts, next to what its tooltip says. Reset forgets them all."] = "Wie viel jeder deiner DoTs tatsächlich tickt, gelernt aus früheren Zaubern, neben dem Wert aus dem Tooltip. Zurücksetzen vergisst alle.",
    ["When unsure"] = "Bei Unsicherheit",
    ["Where the kill icon is centered (e.g. the custom frame's portrait). Empty: Blizzard's portrait, or EllesmereUI's when its target frame shows one; else the health bar in use. Fine-tune with the offsets on the Kill icon tab."] = "Wo das Kill-Symbol zentriert wird (z. B. das Porträt des eigenen Fensters). Leer: das Porträt von Blizzard oder das von EllesmereUI, wenn dessen Zielfenster eines zeigt; sonst die verwendete Lebensleiste. Feinabstimmung mit den Versätzen im Reiter Kill-Symbol.",
    ["Whether a new DoT counts before its first tick lands. \"When unsure\" waits for finishers with unknown combo points and spells the addon hasn't seen tick yet."] = "Ob ein neuer DoT zählt, bevor sein erster Tick eintrifft. „Bei Unsicherheit“ wartet bei Finishern mit unbekannten Combopunkten und bei Zaubern, die das Addon noch nicht ticken gesehen hat.",
    ["While this window is open, the marker and kill icon are drawn here instead of on your target."] = "Solange dieses Fenster offen ist, werden Markierung und Kill-Symbol hier statt auf deinem Ziel gezeichnet.",
    ["White"] = "Weiß",
    ["Window language"] = "Fenstersprache",
}

ns.locale.register({
    tag = "deDE",
    label = "Deutsch",
    strings = STRINGS,
    parseDot = parseDot,
    isFinisher = isFinisher,
    comboPointsAwarded = comboPointsAwarded,
    names = NAMES,
})
