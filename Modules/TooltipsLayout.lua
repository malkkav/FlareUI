local _, ns = ...
local L = ns.L

--------------------------------------------------
-- TOOLTIPS LAYOUT
-- Tooltips > Layout (11-17): Header Icon, Badges and Spell Strip, on GameTooltip and ItemRefTooltip
-- (items: their comparisons too). The game's tooltip is reshaped in place, never covered: the icon gets
-- its room from a blank texture at the start of the header lines, the badges sit on the name line's
-- right, and the strip is the game's cost and cast lines on one row. A line that can't be read (a
-- secret) leaves the tooltip as the game drew it.
-- Ideas from PrettyTooltip by FallenShard (MIT License, LICENSES/PrettyTooltip.txt); FlareUI's code.
--------------------------------------------------
local TIP = ns.Tooltips
if not (TIP and TIP.util) then return end
local U = TIP.util
local Readable, Line, ColorToHex = U.Readable, U.Line, U.ColorToHex
local canaccessvalue = canaccessvalue

local Layout = {}
TIP.Layout = Layout

--------------------------------------------------
-- 1. CONSTANTS
--------------------------------------------------
local BLANK = "Interface\\AddOns\\FlareUI\\Media\\Art\\Empty"
local ICON, ICON_GAP = 34, 8          -- the icon, and the room between it and the text
local PLATE_H, PLATE_GAP = 13, 4      -- the level plate under a unit's portrait
local LINE_GAP = 2                    -- GameTooltip's space between lines
local DOT = " |cff6f6f6f\194\183|r "  -- " · "

-- a blank texture of the given size, as text: room on a line
local function Room(height, width)
    return ("|T%s:%d:%d|t"):format(BLANK, height, width)
end
local ROOM_START = "|T" .. BLANK .. ":"
local ROOM_BELOW = 4   -- under the plate's border, before an Inside health bar
local ICON_BELOW = 6   -- under the icon, before the text that follows the header (11-17, a screenshot: 2 px was tight)

-- lighter than the game's, to read on the dark background
local BADGE_COLORS = {
    boss = { 1, 0.45, 0.4 }, elite = { 1, 0.85, 0.35 }, rare = { 0.8, 0.85, 0.95 },
    pvp = { 1, 0.62, 0.4 }, afk = { 0.65, 0.65, 0.65 }, dnd = { 1, 0.45, 0.45 }, dead = { 0.6, 0.6, 0.6 },
}
local SCHOOL_COLORS = {
    Holy = { 1, 0.9, 0.5 }, Fire = { 1, 0.55, 0.25 }, Nature = { 0.45, 1, 0.45 }, Frost = { 0.5, 0.85, 1 },
    Shadow = { 0.68, 0.58, 1 }, Arcane = { 1, 0.6, 1 }, Frostfire = { 0.75, 0.7, 1 },
}
-- the game's name for a school (STRING_SCHOOL_FROST), else these
local SCHOOL_NAMES = { Holy = L["Holy"], Fire = L["Fire"], Nature = L["Nature"], Frost = L["Frost"],
    Shadow = L["Shadow"], Arcane = L["Arcane"], Frostfire = L["Frostfire"] }
local RANK_COLOR = { 0.72, 0.72, 0.72 }
-- An elite's, rare's or boss's level plate wears the nameplate's dragon: gold, or silver for rares.
-- The nameplate's atlas where the client has it, else Classic's nameplate file.
local ELITE_ART = {
    gold = { atlas = "nameplates-icon-elite-gold", file = "Interface\\Tooltips\\EliteNameplateIcon" },
    silver = { atlas = "nameplates-icon-elite-silver", file = "Interface\\Tooltips\\EliteNameplateIcon", grey = true },
}
local ELITE_SIZE = 18

--------------------------------------------------
-- 2. PARTS
-- One icon per tooltip, made the first time it's needed and hidden whenever
-- the tooltip clears or hides.
--------------------------------------------------
local function ThinBorder(frame)
    local LSM = LibStub("LibSharedMedia-3.0", true)
    local edge = LSM and LSM:Fetch("border", "FlareUI Thin", true)
    local border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    if TIP.GuardBackdropSize then TIP.GuardBackdropSize(border) end   -- (on a tooltip line: its position can be secret)
    border:SetPoint("TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", 2, -2)
    border:SetFrameLevel(frame:GetFrameLevel() + 1)
    if edge then border:SetBackdrop({ edgeFile = edge, edgeSize = ns.BorderEdgeSize(edge, 8) }) end
    return border
end

local function SetBorderColor(border, c)
    if border.SetBackdropBorderColor then border:SetBackdropBorderColor(c[1], c[2], c[3], 1) end
end

-- the icon or portrait in a thin FlareUI border, with a level plate under it for units
function Layout.NewIcon(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(ICON, ICON)
    f.back = f:CreateTexture(nil, "BACKGROUND")
    f.back:SetAllPoints()
    f.back:SetColorTexture(0, 0, 0, 1)
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetAllPoints()
    f.border = ThinBorder(f)
    local plate = CreateFrame("Frame", nil, f)
    plate:SetSize(ICON, PLATE_H)
    plate:SetPoint("TOP", f, "BOTTOM", 0, -PLATE_GAP)
    plate.back = plate:CreateTexture(nil, "BACKGROUND")
    plate.back:SetAllPoints()
    plate.border = ThinBorder(plate)
    plate.text = plate:CreateFontString(nil, "OVERLAY", "GameTooltipTextSmall")
    plate.text:SetPoint("CENTER", 0, 0)
    -- the nameplate's elite dragon on the plate's right end, over its border
    local holder = CreateFrame("Frame", nil, plate)
    holder:SetAllPoints()
    holder:SetFrameLevel(plate:GetFrameLevel() + 3)
    plate.dragon = holder:CreateTexture(nil, "OVERLAY")
    plate.dragon:SetSize(ELITE_SIZE, ELITE_SIZE)
    plate.dragon:SetPoint("CENTER", plate, "RIGHT", 0, 0)
    plate.dragon:Hide()
    f.plate = plate
    f:Hide()
    return f
end

-- source: { texture = fileID or path } or { unit = token } (a portrait); plate: { text, color, dragon }
-- or nil (dragon: "gold", "silver" or nil)
-- (a hovered unit frame's tooltip refills five times a second: the portrait, a model render, is drawn
-- again only for another unit, by its GUID, 11-17)
local atlasKnown = {}
function Layout.PaintIcon(f, source, borderColor, plate)
    if source.unit and SetPortraitTexture then
        if not (source.guid and f.portrait == source.guid) then
            pcall(SetPortraitTexture, f.tex, source.unit)
            f.portrait = source.guid
        end
        f.tex:SetTexCoord(0.12, 0.88, 0.12, 0.88)
    elseif f.portrait or f.texture ~= source.texture then
        f.portrait = nil
        f.tex:SetTexture(source.texture)
        f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    f.texture = not f.portrait and source.texture or nil
    if f.borderColor ~= borderColor then
        f.borderColor = borderColor
        SetBorderColor(f.border, borderColor)
    end
    -- (the plate is painted again only when it changes: a refill draws the same one)
    local key = plate and (plate.text .. (plate.dragon or "") .. ("%.3f%.3f%.3f"):format(plate.color[1], plate.color[2], plate.color[3]))
    if key and key ~= f.plateKey then
        local c = plate.color
        f.plate.text:SetText(plate.text)
        f.plate.text:SetTextColor(c[1], c[2], c[3])
        f.plate.back:SetColorTexture(c[1] * 0.16, c[2] * 0.16, c[3] * 0.16, 0.95)
        f.plate.border:SetBackdropBorderColor(c[1] * 0.75, c[2] * 0.75, c[3] * 0.75, 1)
        local art = plate.dragon and ELITE_ART[plate.dragon]
        local dragon = f.plate.dragon
        if art then
            local atlas = atlasKnown[art.atlas]
            if atlas == nil then
                atlas = (C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(art.atlas)) and true or false
                atlasKnown[art.atlas] = atlas
            end
            if atlas then
                dragon:SetAtlas(art.atlas)
                dragon:SetDesaturated(false)
            else
                dragon:SetTexture(art.file)
                dragon:SetTexCoord(0, 1, 0, 1)
                dragon:SetDesaturated(art.grey or false)
            end
            dragon:Show()
        else
            dragon:Hide()
        end
    end
    f.plateKey = key
    f.plate:SetShown(plate and true or false)
    f:Show()
end

-- Per tooltip: its icon, the right-hand texts FlareUI put there this fill (badges, a binding: the
-- header may hold them), the lines it gave a height (emptied, or padded under the icon; with their
-- own vertical justify), and whether this fill is laid out. Reset when the tooltip clears or hides.
local states = setmetatable({}, { __mode = "k" })

local function Reset(tip)
    local st = states[tip]
    if not st then return end
    for line, justify in pairs(st.sized) do line:SetHeight(0); line:SetJustifyV(justify) end
    wipe(st.sized)
    wipe(st.own)
    st.laid = false
    if st.icon then st.icon:Hide() end
end

local function State(tip)
    local st = states[tip]
    if st then return st end
    st = { own = {}, sized = {}, laid = false }
    states[tip] = st
    tip:HookScript("OnTooltipCleared", Reset)
    tip:HookScript("OnHide", Reset)
    return st
end

-- An emptied line still takes a row of height (11-17, a screenshot: the strip's emptied cast line left a
-- gap over the description), so it's made 1 px tall, and back to its own height when the tooltip clears.
local function SetLineHeight(tip, line, height)
    local sized = State(tip).sized
    if sized[line] == nil then sized[line] = line:GetJustifyV() or "MIDDLE" end
    line:SetJustifyV("TOP")
    line:SetHeight(height)
end
local function Collapse(tip, line)
    line:SetText(nil)
    SetLineHeight(tip, line, 1)
end

local function BorderColor(tip)
    return (TIP.borderColorOf and TIP.borderColorOf[tip]) or U.DEFAULT_BORDER_COLOR
end

--------------------------------------------------
-- 3. ROOM
-- Lines never move: the game decides per line which ones wrap, so text moved to another line could
-- run the tooltip as wide as the screen (11-17, a screenshot). New rows go into an existing line
-- after a line break, and blank room is a texture in the text.
--------------------------------------------------
-- The client scales an inline texture with the line's font (11-17, a screenshot: a 42 px room on the
-- 14 pt name line came out wider than on the 12 pt lines). Each font size's scale is measured once.
local measure, scaleBySize = nil, {}
local function Measure(tip, line)
    measure = measure or tip:CreateFontString(nil, "BACKGROUND")
    local font = line:GetFontObject()
    if font then measure:SetFontObject(font) end
    return measure
end
local function FontSize(line)
    local _, size = line:GetFont()
    if canaccessvalue(size) and type(size) == "number" then return size end
end
local function Scale(tip, line)
    local size = FontSize(line)
    if not size then return 1 end
    if not scaleBySize[size] then
        local m = Measure(tip, line)
        m:SetText(Room(1, 100))
        local width = m:GetStringWidth()
        m:SetText(nil)
        scaleBySize[size] = (canaccessvalue(width) and type(width) == "number" and width > 0) and 100 / width or 1
    end
    return scaleBySize[size]
end
-- blank room of height x width pixels on this line
local function RoomFor(tip, line, height, width)
    local s = Scale(tip, line)
    return Room(math.max(1, math.floor(height * s + 0.5)), math.max(1, math.floor(width * s + 0.5)))
end

local function Rows(text)
    local rows = {}
    for row in ((text or "") .. "\n"):gmatch("(.-)\n") do rows[#rows + 1] = row end
    return rows
end

-- Text on a line's right, in place of what the game put there (none, or a spell's rank). false when
-- the line can't be read.
local function SetRight(tip, i, text)
    local right = Line(tip, "Right", i)
    if not right or not canaccessvalue(right:GetText()) then return false end
    right:SetText(text)
    right:SetTextColor(1, 1, 1)
    right:Show()
    State(tip).own[right] = true
    return true
end

local function Badge(text, c)
    return ColorToHex(c[1], c[2], c[3]) .. text .. "|r"
end

--------------------------------------------------
-- 4. HEADER ICON
-- The header's rows get blank room in front, down to the icon's (and plate's) bottom. The header is
-- the name and the short lines under it, at most four: a long line may wrap (its wrapped rows would
-- start under the icon, 11-17 an apple's Use: line), and a line with text on its right is content, as
-- another addon's "Vendor 87c" (11-17). Where the header is shorter than the icon, its last line gets
-- a blank row as tall as what's missing, so everything after it starts under the icon. false when a
-- line can't be read.
--------------------------------------------------
local rowBySize = {}
local function RowHeight(tip, line)
    local _, size = line:GetFont()
    size = canaccessvalue(size) and type(size) == "number" and size or 12
    if not rowBySize[size] then
        local m = Measure(tip, line)
        m:SetText("Xg")
        local h = m:GetStringHeight()
        m:SetText(nil)
        rowBySize[size] = (canaccessvalue(h) and type(h) == "number" and h > 0) and h or size + 2
    end
    return rowBySize[size]
end
local SHORT = 300        -- narrower than this, unwrapped, a line doesn't wrap ("Level 27 High Order Skyborne Hunter" is ~270)
local HEADER_LINES = 4
-- below: room wanted under the icon (the Inside health bar's); size: the icon's
local function MakeRoom(tip, need, below, size)
    need = need + (below or 0)
    size = size or ICON
    local y, edits, last, lastI = 0, {}, nil, 0
    for i = 1, math.min(tip:NumLines(), HEADER_LINES) do
        if y >= need then break end
        local line, right = Line(tip, "Left", i), Line(tip, "Right", i)
        local text, h, w = line:GetText(), line:GetStringHeight(), line:GetStringWidth()
        local side = right:GetText()
        if not (canaccessvalue(text) and canaccessvalue(h) and canaccessvalue(w) and canaccessvalue(side)) then return false end
        if not right:IsShown() then side = nil end
        text = text or ""
        local rows = Rows(text)
        -- (an emptied line, as the strip's second, takes no room and stays empty)
        local empty = i > 1 and text == ""
        if i > 1 and not empty then
            local long = type(w) == "number" and w > SHORT and #rows == 1
            local content = type(side) == "string" and side ~= "" and #rows == 1 and not State(tip).own[right]
            if long or content then break end
        end
        if not empty then
            local rowH = (h or 0) / #rows
            local room = RoomFor(tip, line, 1, size + ICON_GAP)
            for r, row in ipairs(rows) do
                -- (rows that are room themselves stay as they are)
                if y + (r - 1) * rowH < need and row:sub(1, #ROOM_START) ~= ROOM_START then rows[r] = room .. row end
            end
            edits[#edits + 1] = { line, table.concat(rows, "\n"), h or 0 }
            last, lastI = #edits, i
            y = y + (h or 0) + LINE_GAP
        end
    end
    if not last then return false end
    -- room under the icon when text follows the header (the tooltip's own padding does at its end)
    if lastI < tip:NumLines() then need = need + math.max(0, ICON_BELOW - (below or 0)) end
    -- too short: a blank row under the header where a text row's missing (a blank row is never shorter
    -- than one: units' plates, one-line headers), else the last line made that much taller, its text at
    -- the top (the icon is sized to a two-line header, ShowIcon)
    local edit, missing = edits[last], need - y
    local blankRow = missing >= RowHeight(tip, edit[1])
    if blankRow then edit[2] = edit[2] .. "\n" .. RoomFor(tip, edit[1], missing, 1) end
    for _, e in ipairs(edits) do e[1]:SetText(e[2]) end
    if missing > 0.5 and not blankRow then
        SetLineHeight(tip, edit[1], edit[3] + missing)
    end
    return true
end

-- Every icon, portrait or not, is the same size (11-17): as tall as the name line and one
-- line of text under it, in the tooltip's fonts, between 24 and 40 px. A two-line header fits it exactly
-- (11-17, screenshots: a fixed 34 px icon was a few pixels taller than "Life Tap / Instant", and no blank
-- row can be that small).
local function IconSize(tip)
    local title = Line(tip, "Left", 1)
    local text = Line(tip, "Left", 2) or title
    local h = RowHeight(tip, title) + LINE_GAP + RowHeight(tip, text)
    return math.max(24, math.min(40, math.floor(h + 0.5)))
end

local function ShowIcon(tip, source, plate)
    local size = IconSize(tip)
    local need = size + (plate and (PLATE_GAP + PLATE_H) or 0)
    local below = plate and TIP.HealthBarMode and TIP.HealthBarMode() == "inside" and ROOM_BELOW or 0
    if not MakeRoom(tip, need, below, size) then return false end
    local st = State(tip)
    if not st.icon then
        st.icon = Layout.NewIcon(tip)
        st.icon:SetPoint("TOPLEFT", Line(tip, "Left", 1), "TOPLEFT", 0, 0)
    end
    if st.icon.size ~= size then
        st.icon.size = size
        st.icon:SetSize(size, size)
        st.icon.plate:SetWidth(size)
    end
    Layout.PaintIcon(st.icon, source, BorderColor(tip), plate)
    return true
end

-- With the level on the plate, the level line drops its "Level 27" (11-17): "High Order
-- Skyborne Hunter", "Humanoid"; a line that was only the level ("Level 39") empties. The line is
-- ColorLevelLine's: the level in its own colour code first. Returns a function that puts it back.
local function DropLevelWord(tip, levelLine)
    local word = _G.LEVEL
    local line = levelLine and Line(tip, "Left", levelLine)
    local text = line and line:GetText()
    if not (type(word) == "string" and canaccessvalue(text) and type(text) == "string") then return nil end
    local escaped = word:gsub(U.PATTERN_MAGIC, "%%%0")
    local rest, n = text:gsub("|c%x%x%x%x%x%x%x%x" .. escaped .. "%s+%S+|r", "", 1)
    if n == 0 then return nil end
    -- the space that followed the level, now in front
    rest = rest:gsub("(|c%x%x%x%x%x%x%x%x)%s+", "%1", 1)
    local plain = rest:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    if plain:find("%S") then line:SetText(rest) else Collapse(tip, line) end
    return function()
        local sized = State(tip).sized
        if sized[line] ~= nil then line:SetHeight(0); line:SetJustifyV(sized[line]); sized[line] = nil end
        line:SetText(text)
    end
end

--------------------------------------------------
-- 5. SPELL STRIP
-- Blizzard's cost / range and cast / cooldown lines, read with patterns made from the game's own
-- strings (every language), on one row in the game's own words: "50 Mana · 2.2 sec cast · 30 yd
-- range", the cost in its power's colour. A line that doesn't read as one of those ends it. (11-17:
-- plain text, after a four-cell overlay over blank room kept landing on the header.)
--------------------------------------------------
local POWERS = {
    { "MANA_COST", { 0.5, 0.7, 1 } }, { "MANA_COST_LARGE", { 0.5, 0.7, 1 } }, { "RAGE_COST", { 1, 0.45, 0.45 } },
    { "ENERGY_COST", { 1, 0.9, 0.4 } }, { "FOCUS_COST", { 1, 0.65, 0.35 } },
}
local parsers
local function Add(kind, global, color)
    local pattern = U.FormatPattern(_G[global])
    if pattern then parsers[#parsers + 1] = { kind = kind, pattern = pattern, color = color } end
end
-- a line the game words without a figure ("Instant", "Melee Range")
local function AddWord(kind, global)
    local word = _G[global]
    if type(word) == "string" and word ~= "" then parsers[#parsers + 1] = { kind = kind, word = word } end
end
local function BuildParsers()
    parsers = {}
    for _, power in ipairs(POWERS) do Add("cost", power[1], power[2]) end
    Add("cast", "SPELL_CAST_TIME_SEC")
    Add("cast", "SPELL_CAST_TIME_MIN")
    AddWord("cast", "SPELL_CAST_TIME_INSTANT")
    AddWord("cast", "SPELL_CAST_TIME_INSTANT_NO_MANA")
    AddWord("cast", "SPELL_CAST_CHANNELED")
    AddWord("cast", "SPELL_ON_NEXT_SWING")
    Add("cooldown", "SPELL_RECAST_TIME_SEC")
    Add("cooldown", "SPELL_RECAST_TIME_MIN")
    Add("cooldown", "SPELL_RECAST_TIME_HOURS")
    Add("cooldown", "SPELL_RECAST_TIME_DAYS")
    Add("range", "SPELL_RANGE")
    AddWord("range", "MELEE_RANGE")
    AddWord("range", "SPELL_RANGE_UNLIMITED")
end

-- kind and colour of one side of a line, or nil
local function Parse(text)
    for _, p in ipairs(parsers) do
        if (p.word and text == p.word) or (p.pattern and text:match(p.pattern)) then return p.kind, p.color end
    end
end

local ORDER = { "cost", "cast", "cooldown", "range" }

-- the strip's lines from first: their count and the row, or nil
local function FindStrip(tip, first)
    if not parsers then BuildParsers() end
    local found, count = {}, 0
    for i = first, math.min(first + 2, tip:NumLines()) do
        local left, right = Line(tip, "Left", i), Line(tip, "Right", i)
        local leftText, rightText = left:GetText(), right:GetText()
        if not (canaccessvalue(leftText) and canaccessvalue(rightText)) then return nil end
        if not right:IsShown() then rightText = nil end
        local any, ok = false, true
        for side = 1, 2 do
            local text = rightText
            if side == 1 then text = leftText end
            if type(text) == "string" and text ~= "" then
                any = true
                local kind, color = Parse(text)
                if kind and not found[kind] then
                    found[kind] = color and ColorToHex(color[1], color[2], color[3]) .. text .. "|r" or text
                elseif not kind then
                    ok = false
                end
            end
        end
        if not (any and ok) then break end
        count = count + 1
    end
    if count == 0 then return nil end
    local parts = {}
    for _, kind in ipairs(ORDER) do parts[#parts + 1] = found[kind] end
    return count, table.concat(parts, DOT)
end

-- the row in the strip's first line, the other lines emptied
local function ShowStrip(tip, first, count, row)
    for i = first, first + count - 1 do
        if i == first then Line(tip, "Left", i):SetText(row) else Collapse(tip, Line(tip, "Left", i)) end
        local right = Line(tip, "Right", i)
        right:SetText(nil)
        right:Hide()
    end
end

--------------------------------------------------
-- 6. RANK
--------------------------------------------------
local function UnitRank(unit)
    local class = Readable(UnitClassification(unit))
    local level = Readable(UnitLevel(unit))
    if class == "worldboss" or ((class == "elite" or class == "rareelite") and level and level < 0) then return "boss" end
    if class == "elite" or class == "rare" or class == "rareelite" then return class end
end
local RANK_DRAGON = { boss = "gold", elite = "gold", rare = "silver", rareelite = "silver" }

--------------------------------------------------
-- 7. PER KIND
--------------------------------------------------
-- the main tooltip and a clicked link's; for items also the comparisons beside them (11-17)
local COMPARISONS = { ShoppingTooltip1 = true, ShoppingTooltip2 = true, ItemRefShoppingTooltip1 = true,
    ItemRefShoppingTooltip2 = true }
-- True when this tooltip gets a layout now: the right tooltip, an option on, and not laid out yet this
-- fill (a second post-call on the same fill would lay it out twice). The post-calls have already
-- checked SafeToTouch.
local function Begin(tip, db, comparisons)
    if not (db and (db.headerIcon or db.badges or db.spellStrip)) then return false end
    local name = tip and tip.GetName and tip:GetName()
    local known = tip == GameTooltip or tip == _G.ItemRefTooltip or (comparisons and name and COMPARISONS[name])
    if not known then return false end
    local st = State(tip)
    if st.laid then return false end
    Reset(tip)
    st.laid = true
    return true
end

-- Boss / Rare Elite / Rare / Elite, then PvP, AFK, DND and Dead
local function UnitBadges(unit)
    local list = {}
    local kind = UnitRank(unit)
    local C = BADGE_COLORS
    if kind == "boss" then list[#list + 1] = Badge(L["Boss"], C.boss)
    elseif kind == "rareelite" then list[#list + 1] = Badge(L["Rare Elite"], C.rare)
    elseif kind == "rare" then list[#list + 1] = Badge(L["Rare"], C.rare)
    elseif kind == "elite" then list[#list + 1] = Badge(L["Elite"], C.elite) end
    if Readable(UnitIsPVP(unit)) then list[#list + 1] = Badge(L["PvP"], C.pvp) end
    if Readable(UnitIsAFK(unit)) then list[#list + 1] = Badge(L["AFK"], C.afk) end
    if Readable(UnitIsDND(unit)) then list[#list + 1] = Badge(L["DND"], C.dnd) end
    if Readable(UnitIsDeadOrGhost(unit)) then list[#list + 1] = Badge(_G.DEAD or L["Dead"], C.dead) end
    return list
end

function Layout.Unit(tip, unit, levelLine)
    local db = U.GetDb()
    if not Begin(tip, db) then return end
    if db.badges then
        local badges = UnitBadges(unit)
        if #badges > 0 then SetRight(tip, 1, table.concat(badges, DOT)) end
    end
    if db.headerIcon then
        local level = Readable(UnitLevel(unit))
        local plate
        if type(level) == "number" then
            local c = level > 0 and U.UnitLevelColor(unit, level)
            local color = c and { c.r, c.g, c.b } or { 1, 0.25, 0.25 }
            plate = { text = level > 0 and tostring(level) or "??", color = color, dragon = RANK_DRAGON[UnitRank(unit) or ""] }
        end
        -- (the level goes first, so the room is measured on the lines as they'll be; back if no icon)
        local putBack = plate and DropLevelWord(tip, levelLine)
        if not ShowIcon(tip, { unit = unit, guid = Readable(UnitGUID(unit)) }, plate) and putBack then putBack() end
    end
end

-- The binding ("Binds when equipped") goes to the right of the slot line under it ("Back"), in grey,
-- when that line has nothing on its right (a weapon's "Sword", armour's "Cloth": the binding stays).
local BINDS = { "ITEM_BIND_ON_EQUIP", "ITEM_BIND_ON_PICKUP", "ITEM_BIND_ON_USE", "ITEM_SOULBOUND", "ITEM_BIND_QUEST",
    "ITEM_BIND_TO_ACCOUNT", "ITEM_BIND_TO_BNETACCOUNT", "ITEM_ACCOUNTBOUND" }
local bindings
local function IsBinding(text)
    if not bindings then
        bindings = {}
        for _, global in ipairs(BINDS) do
            if type(_G[global]) == "string" then bindings[_G[global]] = true end
        end
    end
    return bindings[text] or false
end
local BIND_COLOR = { 0.72, 0.72, 0.72 }
local function BindingToSlot(tip)
    for i = 2, math.min(4, tip:NumLines() - 1) do
        local left = Line(tip, "Left", i)
        local text = left:GetText()
        if not canaccessvalue(text) then return end
        if type(text) == "string" and IsBinding(text) then
            local slot, slotRight = Line(tip, "Left", i + 1), Line(tip, "Right", i + 1)
            local slotText, side = slot:GetText(), slotRight:GetText()
            if not (canaccessvalue(slotText) and canaccessvalue(side)) then return end
            if type(slotText) ~= "string" or slotText == "" or (slotRight:IsShown() and type(side) == "string" and side ~= "") then return end
            -- the slot moves up into the binding's line, the binding to its right; the slot's own line empties
            local r, g, b = slot:GetTextColor()
            left:SetText(slotText)
            left:SetTextColor(r, g, b)
            local right = Line(tip, "Right", i)
            right:SetText(text)
            right:SetTextColor(BIND_COLOR[1], BIND_COLOR[2], BIND_COLOR[3])
            right:Show()
            State(tip).own[right] = true
            Collapse(tip, slot)
            return
        end
    end
end

function Layout.Item(tip, data)
    local db = U.GetDb()
    if not Begin(tip, db, true) then return end
    if db.badges then BindingToSlot(tip) end
    if not db.headerIcon then return end
    -- (a macro's item has no displayed item: its ID comes with the data)
    local _, link = TooltipUtil.GetDisplayedItem(tip)
    if not (canaccessvalue(link) and link) then link = data and canaccessvalue(data.id) and data.id or nil end
    if not link then return end
    local icon = select(5, C_Item.GetItemInfoInstant(link))
    if canaccessvalue(icon) and icon then ShowIcon(tip, { texture = icon }) end
end

local function SpellIcon(spellID)
    local getter = C_Spell and C_Spell.GetSpellTexture or GetSpellTexture
    local ok, icon = pcall(getter, spellID)
    if ok and canaccessvalue(icon) and icon then return icon end
end

-- School and rank on the name line's right, in place of the game's rank: "Fire · Rank 4"; nil without
local function SpellBadges(tip, spellID)
    local list = {}
    local school = ns.TooltipsData and ns.TooltipsData.SpellSchool(spellID)
    if school then
        local name = _G["STRING_SCHOOL_" .. school:upper()] or SCHOOL_NAMES[school] or school
        list[#list + 1] = Badge(name, SCHOOL_COLORS[school] or RANK_COLOR)
    end
    local right = Line(tip, "Right", 1)
    local rank = right and right:IsShown() and right:GetText()
    if not canaccessvalue(rank) then return nil end
    if type(rank) == "string" and rank ~= "" then list[#list + 1] = Badge(rank, RANK_COLOR) end
    if #list == 0 then return nil end
    return table.concat(list, DOT)
end

function Layout.Spell(tip, data)
    local db = U.GetDb()
    if not Begin(tip, db) then return end
    local spellID = data and data.id
    if not (canaccessvalue(spellID) and type(spellID) == "number") then return end
    if db.spellStrip then
        local count, row = FindStrip(tip, 2)
        if count then ShowStrip(tip, 2, count, row) end
    end
    if db.badges then
        local badges = SpellBadges(tip, spellID)
        if badges then SetRight(tip, 1, badges) end
    end
    local icon = db.headerIcon and SpellIcon(spellID)
    if icon then ShowIcon(tip, { texture = icon }) end
end

function Layout.Aura(tip, data)
    local db = U.GetDb()
    if not (db and db.headerIcon and Begin(tip, db)) then return end
    local spellID = data and data.id
    if not (canaccessvalue(spellID) and type(spellID) == "number") then return end
    local icon = SpellIcon(spellID)
    if icon then ShowIcon(tip, { texture = icon }) end
end
