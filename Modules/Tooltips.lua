local _, ns = ...
local L = ns.L

--------------------------------------------------
-- TOOLTIPS
-- Tooltip scale, colours, fonts, unit lines, anchoring and per-category visibility, through
-- TooltipDataProcessor post-calls and post-hooks only (never method replacement).
--------------------------------------------------

--------------------------------------------------
-- 1. MODULE REGISTRATION
--------------------------------------------------
ns.Tooltips = ns.Tooltips or {}
local TIP = ns.Tooltips
ns.modules["Tooltips"] = TIP

--------------------------------------------------
-- 2. UPVALUES
--------------------------------------------------
local _G = _G
local ipairs, type, select = ipairs, type, select
local pcall = pcall
local UnitExists, UnitName, UnitClass, UnitReaction = UnitExists, UnitName, UnitClass, UnitReaction
local UnitIsPlayer, UnitIsUnit, UnitClassification = UnitIsPlayer, UnitIsUnit, UnitClassification
local UnitAffectingCombat, IsShiftKeyDown = UnitAffectingCombat, IsShiftKeyDown
local canaccessvalue, issecretvalue = canaccessvalue, issecretvalue

local function GetDb()
    return ns.db and ns.db.profile and ns.db.profile.tooltips
end

--------------------------------------------------
-- 3. CONSTANTS
--------------------------------------------------
-- muted, as the unit frame threat tint
local REACTION_COLORS = {
    [1] = { 0.78, 0.28, 0.24 },   -- hated
    [2] = { 0.78, 0.28, 0.24 },   -- hostile
    [3] = { 0.80, 0.48, 0.25 },   -- unfriendly
    [4] = { 0.80, 0.68, 0.30 },   -- neutral
    [5] = { 0.35, 0.65, 0.38 },   -- friendly
    [6] = { 0.35, 0.65, 0.38 },   -- honored
    [7] = { 0.35, 0.65, 0.38 },   -- revered
    [8] = { 0.35, 0.65, 0.38 },   -- exalted
}
local DEFAULT_BORDER_COLOR = { 0.80, 0.60, 0.34 }   -- #CC9957
local BACKGROUND = { 0.05, 0.05, 0.06, 0.9 }
local MUTE = 0.85                                   -- class / quality colour multiplier

-- tooltips that follow the main one's scale and colours
local SATELLITES = {
    "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "EmbeddedItemTooltip",
    "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2", "FriendsTooltip",
}

-- visibility categories (items, spells, auras and plain UI tips always show)
local CAT_WORLD_UNIT   = "worldUnits"
local CAT_WORLD_OBJECT = "worldObjects"
local CAT_FRAME_UNIT   = "frameUnits"
local CAT_ACTION       = "actionBars"
local CAT_AURA         = "auras"
local CAT_OTHER        = "other"   -- Everything Else (11-12)

--------------------------------------------------
-- 4. SAFETY
-- A forbidden tooltip, a secret width or a child with a secret shownWidgetCount is never restyled
-- (SetBackdrop / SetPadding would poison Blizzard's layout). Every value passes canaccessvalue
-- before it is tested, compared or concatenated.
--------------------------------------------------
-- no table: runs on every tooltip shown
local function AnySecretWidgetCount(...)
    for i = 1, select("#", ...) do
        if issecretvalue((select(i, ...)).shownWidgetCount) then return true end
    end
    return false
end

local function SafeToTouch(tip)
    if type(tip) ~= "table" or not tip.GetObjectType then return false end
    if tip:IsForbidden() then return false end
    if issecretvalue(tip:GetWidth()) then return false end
    return not AnySecretWidgetCount(tip:GetChildren())
end

-- The value, or nil when it is secret
local function Readable(value)
    if canaccessvalue(value) then return value end
    return nil
end

-- "GameTooltipTextLeft<i>" names built once: the line walks run on every unit tooltip
local LEFT_LINE_NAMES = setmetatable({}, { __index = function(t, i)
    local name = "GameTooltipTextLeft" .. i
    t[i] = name
    return name
end })

local function LeftLine(i)
    return _G[LEFT_LINE_NAMES[i]]
end

local function ColorToHex(r, g, b)
    return ("|cff%02x%02x%02x"):format(r * 255, g * 255, b * 255)
end

local function Mute(r, g, b)
    return r * MUTE, g * MUTE, b * MUTE
end

-- halfway to white: a colour that reads on the dark background next to its full self
local function Lighten(c)
    local amount = 0.5
    return { c[1] + (1 - c[1]) * amount, c[2] + (1 - c[2]) * amount, c[3] + (1 - c[3]) * amount }
end

-- Any named tooltip's line ("Left" or "Right"): GameTooltip, ItemRefTooltip, a comparison. The global
-- names are built once per tooltip and line: the line walks run on every fill.
local lineNames = setmetatable({}, { __mode = "k" })
local function Line(tip, side, i)
    local names = lineNames[tip]
    if not names then
        local name = tip and tip.GetName and tip:GetName()
        if not name then return nil end
        names = { prefix = name .. "Text", Left = {}, Right = {} }
        lineNames[tip] = names
    end
    local key = names[side][i]
    if not key then
        key = names.prefix .. side .. i
        names[side][i] = key
    end
    return _G[key]
end

-- Details on Shift (11-17): IDs and disenchant info only while Shift is held
local function ShowDetails(db)
    return not db.detailsShift or IsShiftKeyDown()
end

local function InCombat()
    local inCombat = UnitAffectingCombat("player")
    if not canaccessvalue(inCombat) then inCombat = InCombatLockdown() end
    return inCombat and true or false
end

-- A format string from the game ("Durability %d / %d") as a Lua pattern that captures its figures
local PATTERN_MAGIC = "[%^%$%(%)%%%.%[%]%*%+%-%?]"
local function FormatPattern(format)
    if type(format) ~= "string" then return nil end
    local marked = format:gsub("%%%d?%$?[%d%.]*[dfgs]", "\001"):gsub("%%%%", "\002")
    return "^" .. marked:gsub(PATTERN_MAGIC, "%%%0"):gsub("\001", "([%%d%%.,%%-]+)"):gsub("\002", "%%%%") .. "$"
end

--------------------------------------------------
-- 5. COLOURS
--------------------------------------------------
local function GetReactionColor(unit)
    local reaction = Readable(UnitReaction("player", unit))
    if not reaction then return nil end
    return REACTION_COLORS[reaction]
end

local function GetClassColor(unit)
    if not Readable(UnitIsPlayer(unit)) then return nil end
    local classFile = select(2, UnitClass(unit))
    if not Readable(classFile) then return nil end
    local color = C_ClassColor.GetClassColor(classFile)
    if not color then return nil end
    return { color.r, color.g, color.b }
end

-- classColor / reactionColor: a settings preview's made-up unit (the real tooltip passes the unit only)
local function GetUnitBorderColor(unit, classColor, reactionColor)
    local db = GetDb()
    if not db then return nil end
    if db.borderByClass then
        local class = classColor or GetClassColor(unit)
        if class then return class end
    end
    if db.borderByReaction then
        return reactionColor or GetReactionColor(unit)
    end
    return nil
end

--------------------------------------------------
-- 6. APPEARANCE
--------------------------------------------------
local applyingBackdrop = false

local function ApplyColors(tip, borderColor)
    if applyingBackdrop or not SafeToTouch(tip) or not tip.NineSlice then return end
    applyingBackdrop = true

    local bg = BACKGROUND
    local db = GetDb()
    local alpha = db and tonumber(db.opacity) or bg[4]   -- Frame Opacity (Look)
    -- (11-14, a player's report) Frame Opacity is the background texture's own alpha, not its colour's:
    -- ClassicUI Forever's Bronze theme draws a copy of the background that follows the texture's alpha
    -- only, so a colour alpha left that copy solid black
    pcall(tip.NineSlice.SetCenterColor, tip.NineSlice, bg[1], bg[2], bg[3], 1)
    local center = tip.NineSlice.Center
    if center and center.SetAlpha then pcall(center.SetAlpha, center, alpha) end

    local c = borderColor or DEFAULT_BORDER_COLOR
    pcall(tip.NineSlice.SetBorderColor, tip.NineSlice, c[1], c[2], c[3], 1)
    if TIP.borderColorOf then TIP.borderColorOf[tip] = c end   -- (the health bar's border follows it, 11-16)

    applyingBackdrop = false
end

local function ApplyScale(tip)
    local db = GetDb()
    if not db or not tip or not tip.SetScale then return end
    pcall(tip.SetScale, tip, db.scale or 1)
end

local function ApplyScaleToAll()
    ApplyScale(GameTooltip)
    for _, name in ipairs(SATELLITES) do
        local tip = _G[name]
        if tip and tip.SetScale and tip.GetObjectType then ApplyScale(tip) end
    end
end

-- A backdrop on a frame whose size can be secret: the health bar spans the tooltip, and a tooltip with
-- secret text (a player's) has a secret width. Blizzard's size handler does arithmetic on it and errors
-- under FlareUI's taint, on every resize (11-17: thousands in Logs/General.log, then the game's "large
-- number of errors" warning). A secret size keeps the coordinates it had.
local function OnBackdropSize(frame)
    local w, h = frame:GetSize()
    if issecretvalue(w) or issecretvalue(h) then return end
    frame:OnBackdropSizeChanged()
end
function TIP.GuardBackdropSize(frame)
    frame:SetScript("OnSizeChanged", OnBackdropSize)
end

-- (11-16, Malkkav) FlareUI's look for the unit health bar: the FlareUI Forever texture in a thin FlareUI
-- border, on a dark back. Used on FlareUI's own bars only (the overlay below, the settings sample).
function TIP.StyleHealthBar(bar)
    local LSM = LibStub("LibSharedMedia-3.0", true)
    local tex = LSM and LSM:Fetch("statusbar", "FlareUI Forever", true)
    if tex then bar:SetStatusBarTexture(tex) end
    if bar.fuiBack then return end
    bar.fuiBack = bar:CreateTexture(nil, "BACKGROUND")
    bar.fuiBack:SetAllPoints()
    bar.fuiBack:SetColorTexture(0.04, 0.04, 0.04, 1)
    local edge = LSM and LSM:Fetch("border", "FlareUI Thin", true)
    if not edge then return end
    local border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    TIP.GuardBackdropSize(border)
    border:SetPoint("TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", 2, -2)
    border:SetFrameLevel(bar:GetFrameLevel() + 1)
    border:SetBackdrop({ edgeFile = edge, edgeSize = ns.BorderEdgeSize(edge, 8) })
    local c = ns.BORDER_COLOR
    border:SetBackdropBorderColor(c.r, c.g, c.b, 1)
    bar.fuiBorder = border
end

-- Health Bar (Content tab, 11-16 Malkkav): Off, Below the tooltip or Inside it. FlareUI's own bar does both;
-- Blizzard's bar (GameTooltipStatusBar) is only ever hidden: writing to it taints, and its health can be
-- secret. FlareUI's bar reads the same health Blizzard's does (the unit's GUID it watches), and its
-- border takes the tooltip's border colour. Inside: the tooltip grows at the bottom to hold it.
local INSIDE_PAD = 14          -- the room Inside adds under the lines
local INSIDE_X, INSIDE_Y = 10, 10
function TIP.HealthBarMode(db)
    db = db or GetDb()
    if not db or db.hideHealthBar then return "off" end
    return db.healthBarPlace == "inside" and "inside" or "below"
end
-- where a bar of FlareUI's sits on its tooltip
function TIP.PlaceHealthBar(bar, tip, mode)
    bar:ClearAllPoints()
    bar:SetHeight(8)
    if mode == "inside" then
        bar:SetPoint("BOTTOMLEFT", tip, "BOTTOMLEFT", INSIDE_X, INSIDE_Y)
        bar:SetPoint("BOTTOMRIGHT", tip, "BOTTOMRIGHT", -INSIDE_X, INSIDE_Y)
    else
        bar:SetPoint("TOPLEFT", tip, "BOTTOMLEFT", 2, -4)
        bar:SetPoint("TOPRIGHT", tip, "BOTTOMRIGHT", -2, -4)
    end
end
TIP.INSIDE_PAD = INSIDE_PAD
-- the tooltip border's colour as last set (ApplyColors), for the bar's border
local borderColorOf = setmetatable({}, { __mode = "k" })
TIP.borderColorOf = borderColorOf
-- Blizzard's own colours: green at full health to red at none (HealthBar_OnValueChanged)
local function HealthColor(value)
    if not canaccessvalue(value) or type(value) ~= "number" then return 0, 1, 0 end
    if value > 0.5 then return (1 - value) * 2, 1, 0 end
    return 1, value * 2, 0
end

local paddedTip
local function SetInsidePadding(tip, on)
    -- (never on a tooltip FlareUI leaves alone: SetPadding there would poison Blizzard's layout, section 4)
    if on and not SafeToTouch(tip) then on = false end
    if on then
        -- (every fill: the game clears the padding on its own, 11-17)
        pcall(tip.SetPadding, tip, 0, INSIDE_PAD)
        paddedTip = tip
    elseif paddedTip == tip then
        pcall(tip.SetPadding, tip, 0, 0); paddedTip = nil
    end
end
TIP.SetInsidePadding = SetInsidePadding

local function SetupHealthOverlay()
    local blizz, tip = _G.GameTooltipStatusBar, _G.GameTooltip
    if TIP.healthOverlay or not (blizz and tip) then return end
    local bar = CreateFrame("StatusBar", nil, tip)
    bar:SetMinMaxValues(0, 1)
    TIP.StyleHealthBar(bar)
    bar:Hide()
    TIP.healthOverlay = bar
    -- the Inside room goes with the tooltip (a plain text tooltip after it has none)
    tip:HookScript("OnHide", function() SetInsidePadding(tip, false) end)
    local watcher, wait, lastMode, lastColor, lastValue = CreateFrame("Frame", nil, tip), 0, nil, nil, nil
    watcher:SetScript("OnUpdate", function(_, elapsed)
        wait = wait + elapsed
        if wait < 0.05 then return end
        wait = 0
        local mode = TIP.HealthBarMode()
        local guid = mode ~= "off" and blizz:GetAttribute("guid") or nil
        if not guid then
            if bar:IsShown() then bar:Hide() end
            if tip.fuiCorner and tip.fuiLifted then TIP.PlaceInCorner(tip, false) end
            return
        end
        if mode ~= lastMode then lastMode = mode; TIP.PlaceHealthBar(bar, tip, mode) end
        local value = UnitPercentHealthFromGUID and UnitPercentHealthFromGUID(guid)
        -- (a readable value that hasn't changed: the bar already shows it)
        local same = canaccessvalue(value) and value == lastValue and bar:IsShown()
        lastValue = canaccessvalue(value) and value or nil
        if value ~= nil and not same then
            pcall(bar.SetValue, bar, value)
            bar:SetStatusBarColor(HealthColor(value))
        end
        local c = borderColorOf[tip]
        if c and c ~= lastColor and bar.fuiBorder then
            lastColor = c
            bar.fuiBorder:SetBackdropBorderColor(c[1], c[2], c[3], 1)
        end
        if not bar:IsShown() then
            bar:Show()
            -- (11-17, screenshots) the game can name the unit after the post-call that makes the Inside
            -- room, and the bar then covered the last line: the room is made as the bar first shows
            if mode == "inside" then
                SetInsidePadding(tip, true)
                tip:Show()
            end
        end
        -- Screen Corner: lifted exactly while the bar hangs under the tooltip
        local lift = mode == "below" and tip.fuiCorner and tip.fuiCorner:find("^BOTTOM") and true or false
        if tip.fuiCorner and (tip.fuiLifted or false) ~= lift then TIP.PlaceInCorner(tip, lift) end
    end)
end

-- After each unit tooltip: Blizzard's bar hidden (FlareUI's bar takes its place, or none: Off), and
-- the room for an Inside bar. Hide only: writing to Blizzard's bar taints.
local function HideHealthBar(isUnit)
    local db = GetDb()
    local bar, tip = _G.GameTooltipStatusBar, _G.GameTooltip
    if not (db and bar and tip) then return end
    bar:Hide()
    SetInsidePadding(tip, isUnit and TIP.HealthBarMode(db) == "inside" and bar:GetAttribute("guid") ~= nil or false)
end

--------------------------------------------------
-- 7. UNIT TOOLTIP CONTENT
--------------------------------------------------
-- Level line tag: a rare elite counts as rare, a "??" elite as a boss (as Blizzard shows them)
local CLASS_TAGS = {
    boss  = "|cffff4040(" .. L["Boss"] .. ")|r",
    elite = "|cffffd100(" .. L["Elite"] .. ")|r",
    rare  = "|cffffd100(" .. L["Rare"] .. ")|r",
}
local function ClassTag(unit, level)
    local class = Readable(UnitClassification(unit))
    if class == "worldboss" then return CLASS_TAGS.boss end
    if (class == "elite" or class == "rareelite") and level and level < 0 then return CLASS_TAGS.boss end
    if class == "rare" or class == "rareelite" then return CLASS_TAGS.rare end
    if class == "elite" then return CLASS_TAGS.elite end
    return nil
end

-- Drops the PvP and "right click for frame settings" lines
local function ScrubLines(tip)
    local rightClick, pvp = _G.UNIT_POPUP_RIGHT_CLICK, _G.PVP_ENABLED
    for i = 2, tip:NumLines() do
        local line = LeftLine(i)
        local text = line and line:GetText()
        if canaccessvalue(text) and type(text) == "string" then
            if rightClick and text == rightClick then
                line:SetText(nil)
                -- with the blank spacer line above it (never the name line)
                local previous = i > 2 and LeftLine(i - 1)
                if previous then previous:SetText(nil) end
            elseif pvp and text == pvp then
                line:SetText(nil)
            end
        end
    end
end

-- Name in class colour (reaction colour for NPCs)
local function ColorName(tip, unit)
    local db = GetDb()
    if not db or db.nameColor ~= "class" then return end
    local line = _G.GameTooltipTextLeft1
    local text = line and line:GetText()
    if not (canaccessvalue(text) and type(text) == "string") then return end
    local color = GetClassColor(unit) or GetReactionColor(unit)
    if not color then return end
    line:SetText(ColorToHex(color[1], color[2], color[3]) .. text .. "|r")
end

-- Quest difficulty colour of a level, by Blizzard's steps (Forever does not load
-- DifficultyUtil.GetRelativeDifficultyColor); nil when the player's level is unreadable
local DIFFICULTY_FALLBACK = {
    impossible = { r = 1, g = 0.1, b = 0.1 }, verydifficult = { r = 1, g = 0.5, b = 0.25 },
    difficult = { r = 1, g = 0.82, b = 0 }, standard = { r = 0.25, g = 0.75, b = 0.25 },
    trivial = { r = 0.5, g = 0.5, b = 0.5 },
}
local function LevelColor(level)
    local key
    if level < 0 then
        key = "impossible"
    else
        local mine = Readable(UnitEffectiveLevel and UnitEffectiveLevel("player")) or Readable(UnitLevel("player"))
        if not mine then return nil end
        local diff = level - mine
        local green = (UnitQuestTrivialLevelRange and Readable(UnitQuestTrivialLevelRange("player"))) or 8
        if diff >= 5 then key = "impossible"
        elseif diff >= 3 then key = "verydifficult"
        elseif diff >= -4 then key = "difficult"
        elseif -diff <= green then key = "standard"
        else key = "trivial" end
    end
    local colors = _G.QuestDifficultyColors
    return (colors and colors[key]) or DIFFICULTY_FALLBACK[key]
end

local function PlayerClassName(unit)
    if not Readable(UnitIsPlayer(unit)) then return nil end
    local name = UnitClass(unit)
    if canaccessvalue(name) and type(name) == "string" and name ~= "" then return name end
    return nil
end

-- "Level N" in the difficulty colour, the rest in the reaction colour (white plus the class name for
-- players); Blizzard's bracketed tags give way to the one ClassTag (with Badges on, to the badges
-- under it). Returns the line's index.
local function UnitLevelColor(unit, level)
    return (not Readable(UnitIsFriend("player", unit)) and ns.LevelDifficultyColor(unit, level)) or LevelColor(level)
end
local function ColorLevelLine(tip, unit)
    local className = PlayerClassName(unit)
    local color = className and { 1, 1, 1 } or GetReactionColor(unit)
    if not color then return end
    local levelWord = _G.LEVEL
    if not levelWord then return end
    local level = Readable(UnitLevel(unit))
    local difficulty = level and UnitLevelColor(unit, level)
    local db = GetDb()
    local badges = db and db.badges
    local tag = ClassTag(unit, level)
    -- Blizzard's own "(Elite)" goes whenever FlareUI shows the rank itself, on this line or as a badge
    local strip = tag or className
    if badges then tag = nil end
    for i = 2, tip:NumLines() do
        local line = LeftLine(i)
        local text = line and line:GetText()
        if canaccessvalue(text) and type(text) == "string" and text:find("^" .. levelWord) then
            local reaction = ColorToHex(color[1], color[2], color[3])
            local head, rest = text:match("^(" .. levelWord .. "%s+%S+)(.*)$")
            if not head then head, rest = nil, text end
            if strip then rest = rest:gsub("%s*%b()", "") end
            if className then rest = rest .. " " .. className end
            local out
            if difficulty and head then
                out = ColorToHex(difficulty.r, difficulty.g, difficulty.b) .. head .. "|r"
            else
                out = reaction .. (head or "") .. "|r"
            end
            if rest ~= "" then out = out .. reaction .. rest .. "|r" end
            if tag then out = out .. " " .. tag end
            line:SetText(out)
            return i
        end
    end
end

-- A player's class line; ColorLevelLine puts the class on the level line
local function RemoveClassLine(tip, unit)
    local className = PlayerClassName(unit)
    if not className then return end
    for i = 2, tip:NumLines() do
        local line = LeftLine(i)
        local text = line and line:GetText()
        if canaccessvalue(text) and text == className then
            line:SetText(nil)
            return
        end
    end
end

-- Show guild name off: no guild line (Show Guild Ranks was removed 11-16, Malkkav). The line has no type of
-- its own, so it is found by the guild's name, in whatever form the client writes it.
-- (11-17) With Class-Coloured Names, the guild takes a lighter shade of the class colour.
local function ApplyGuildLine(tip, unit)
    local db = GetDb()
    if not db then return end
    local hide = db.showGuild == false
    if not (hide or db.nameColor == "class") then return end
    if not Readable(UnitIsPlayer(unit)) then return end
    local guild = GetGuildInfo(unit)
    if not (canaccessvalue(guild) and type(guild) == "string" and guild ~= "") then return end
    for i = 2, tip:NumLines() do
        local line = LeftLine(i)
        local text = line and line:GetText()
        if canaccessvalue(text) and type(text) == "string" and text:find(guild, 1, true) then
            if hide then
                line:SetText(nil)
            else
                local class = GetClassColor(unit)
                if class then
                    local c = Lighten(class)
                    line:SetTextColor(c[1], c[2], c[3])
                end
            end
            return
        end
    end
end

-- Faction line in Blizzard's faction colours, or gone with Hide faction
local FACTION_LINE_COLORS = {
    { word = "FACTION_HORDE",    hex = "|cffe60d12" },
    { word = "FACTION_ALLIANCE", hex = "|cff4a9eff" },
}
local function ColorFactionLine(tip)
    for i = 2, tip:NumLines() do
        local line = LeftLine(i)
        local text = line and line:GetText()
        if canaccessvalue(text) and type(text) == "string" then
            for _, f in ipairs(FACTION_LINE_COLORS) do
                local word = _G[f.word]
                if word and text == word then
                    local db = GetDb()
                    if db and db.hideFaction then
                        line:SetText(nil)
                    else
                        line:SetText(f.hex .. text .. "|r")
                    end
                    return
                end
            end
        end
    end
end

local function AddTargetLine(tip, unit)
    local db = GetDb()
    if not (db and db.showTarget) then return end
    local target = unit .. "target"
    -- a truth test or comparison on a secret throws
    if not Readable(UnitExists(target)) then return end
    local prefix = (_G.TARGET or "Target") .. ": "
    if Readable(UnitIsUnit(target, "player")) then
        tip:AddLine(prefix .. "|cffff4040" .. (_G.YOU or "You") .. "|r")
        return
    end
    local color = GetClassColor(target) or GetReactionColor(target) or DEFAULT_BORDER_COLOR
    local name = UnitName(target)
    if not canaccessvalue(name) then
        -- a secret name can still be concatenated and shown
        local ok, text = pcall(function() return prefix .. name end)
        if ok then tip:AddLine(text, color[1], color[2], color[3]) end
        return
    end
    if not name or name == "" then return end
    tip:AddLine(prefix .. ColorToHex(color[1], color[2], color[3]) .. name .. "|r")
end

-- "Item ID 12345" / "Spell ID 678" in grey; a secret id is left out
-- Show Item Level (11-13, a player's request): weapons and armour, in Blizzard's gold, unless the game
-- already put its own item level line in
local ITEM_LEVEL_LINE = Enum.TooltipDataLineType and Enum.TooltipDataLineType.ItemLevel
local function AddItemLevelLine(tip, data)
    local db = GetDb()
    if not (db and db.itemLevel) then return end
    local lines = data and data.lines
    if ITEM_LEVEL_LINE and type(lines) == "table" then
        for _, line in ipairs(lines) do
            if canaccessvalue(line) and type(line) == "table" and line.type == ITEM_LEVEL_LINE then return end
        end
    end
    local _, link = TooltipUtil.GetDisplayedItem(tip)
    if not (canaccessvalue(link) and link) then return end
    local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(link)
    if classID ~= Enum.ItemClass.Weapon and classID ~= Enum.ItemClass.Armor then return end
    local ok, level = pcall(C_Item.GetDetailedItemLevelInfo, link)
    if not (ok and canaccessvalue(level) and type(level) == "number" and level > 1) then return end
    local c = NORMAL_FONT_COLOR
    tip:AddLine((_G.ITEM_LEVEL or L["Item Level %d"]):format(level), c.r, c.g, c.b)
    if tip:IsShown() then tip:Show() end
end

local function AddIdLine(tip, key, label, data)
    local db = GetDb()
    local id = data and data.id
    if not (db and db[key] and ShowDetails(db) and canaccessvalue(id) and type(id) == "number") then return end
    tip:AddDoubleLine(" ", label .. " " .. id, nil, nil, nil, 0.5, 0.5, 0.5)
    if tip:IsShown() then tip:Show() end   -- re-layout; never pop up a hidden (scanning) tooltip
end

-- Show IDs on creatures (11-17): the NPC ID out of the GUID ("Creature-0-...-<ID>-...")
local function AddNpcIdLine(tip, unit, data)
    local db = GetDb()
    if not (db and (db.showItemID or db.showSpellID) and ShowDetails(db)) then return end
    if Readable(UnitIsPlayer(unit)) ~= false then return end
    local guid = data and data.guid
    if not (canaccessvalue(guid) and type(guid) == "string") then guid = Readable(UnitGUID(unit)) end
    if type(guid) ~= "string" then return end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if (kind == "Creature" or kind == "Vehicle") and tonumber(id) then
        tip:AddDoubleLine(" ", L["NPC ID"] .. " " .. id, nil, nil, nil, 0.5, 0.5, 0.5)
    end
end

-- (11-17, after PrettyTooltip) A finished quest objective on a creature or an object in green. The
-- data's lines say which are done; without them (world objects), "Name: 3/3" counts as done.
local QUEST_OBJECTIVE = Enum.TooltipDataLineType and Enum.TooltipDataLineType.QuestObjective
local QUEST_DONE = { 0.25, 0.75, 0.25 }
local function ColorQuestProgress(tip, data)
    local done
    local lines = data and data.lines
    if QUEST_OBJECTIVE and canaccessvalue(lines) and type(lines) == "table" then
        for _, line in ipairs(lines) do
            if canaccessvalue(line) and type(line) == "table" and line.type == QUEST_OBJECTIVE then
                local text, completed = line.leftText, line.completed
                if canaccessvalue(text) and canaccessvalue(completed) and completed and type(text) == "string" then
                    done = done or {}
                    done[text] = true
                end
            end
        end
    end
    for i = 2, tip:NumLines() do
        local line = Line(tip, "Left", i)
        local text = line and line:GetText()
        if canaccessvalue(text) and type(text) == "string" then
            local have, need = text:match(":%s*(%d+)%s*/%s*(%d+)%s*$")
            if (done and done[text]) or (have and have == need) then line:SetTextColor(QUEST_DONE[1], QUEST_DONE[2], QUEST_DONE[3]) end
        end
    end
end

-- Gathering Levels (11-17): the skill a skinnable creature or a herb or ore node needs, and the
-- player's own. The game already colours the line by the skill-up chance; this adds the numbers.
local SKILL_LINES  = { Skinning = 393, Herbalism = 182, Mining = 186, Engineering = 202 }
local SKILL_SPELLS = { Skinning = 8613, Herbalism = 2366, Mining = 2575, Engineering = 4036 }
local function SpellName(spellID)
    local getter = C_Spell and C_Spell.GetSpellName or GetSpellInfo
    local ok, name = pcall(getter, spellID)
    if ok and canaccessvalue(name) and type(name) == "string" then return name end
end
-- The player's rank in a gathering skill, or nil without it
local function SkillRank(key)
    if GetProfessions and GetProfessionInfo then
        local ok, a, b, c, d, e, f = pcall(GetProfessions)
        if ok then
            for _, index in pairs({ a, b, c, d, e, f }) do
                if canaccessvalue(index) then
                    local _, _, rank, _, _, _, skillLine = GetProfessionInfo(index)
                    if canaccessvalue(skillLine) and skillLine == SKILL_LINES[key] and canaccessvalue(rank) then return rank end
                end
            end
        end
    end
    if GetNumSkillLines and GetSkillLineInfo then
        local name = SpellName(SKILL_SPELLS[key])
        local count = Readable(GetNumSkillLines()) or 0
        for i = 1, count do
            local skillName, isHeader, _, rank = GetSkillLineInfo(i)
            if canaccessvalue(skillName) and skillName == name and not isHeader and canaccessvalue(rank) then return rank end
        end
    end
end
-- Classic's Skinning (and corpse herb, ore and bolt) level by the creature's level
local function CorpseSkill(level)
    if level <= 10 then return 1 end
    if level <= 20 then return (level - 10) * 10 end
    return level * 5
end
local function MarkSkillLine(tip, i, key, needed)
    local line = Line(tip, "Left", i)
    line:SetText(line:GetText() .. " (" .. needed .. ")")
    local mine = SkillRank(key)
    local right = Line(tip, "Right", i)
    if mine and right then
        right:SetText(L["Your skill: %d"]:format(mine))
        right:SetTextColor(0.6, 0.6, 0.6)
        right:Show()
    end
end
local CORPSE_LINES = { UNIT_SKINNABLE_LEATHER = "Skinning", UNIT_SKINNABLE_HERB = "Herbalism",
                       UNIT_SKINNABLE_ROCK = "Mining", UNIT_SKINNABLE_BOLTS = "Engineering" }
local function AddCorpseSkill(tip, unit)
    local db = GetDb()
    if not (db and db.gatheringLevels) then return end
    local level = Readable(UnitLevel(unit))
    if type(level) ~= "number" or level < 1 then return end
    for i = 2, tip:NumLines() do
        local text = Line(tip, "Left", i):GetText()
        if canaccessvalue(text) and type(text) == "string" then
            for global, key in pairs(CORPSE_LINES) do
                if _G[global] and text == _G[global] then
                    MarkSkillLine(tip, i, key, CorpseSkill(level))
                    return
                end
            end
        end
    end
end
-- A herb or ore node: its name on line 1, "Requires Herbalism" / "Requires Mining" under it (the
-- game's LOCKED_WITH_SPELL; Herbalism's spell is called Herb Gathering, so the line is matched by its
-- start). The node table says which skill it is.
local requiresPrefix
local function IsRequirement(text)
    if requiresPrefix == nil then
        local format = _G.LOCKED_WITH_SPELL
        requiresPrefix = type(format) == "string" and format:match("^(.-)%%s") or false
        if requiresPrefix == "" then requiresPrefix = false end
    end
    local prefix = requiresPrefix
    if prefix and text:sub(1, #prefix) == prefix then return true end
    return text == _G.UNIT_SKINNABLE_HERB or text == _G.UNIT_SKINNABLE_ROCK
end
local function AddNodeSkill(tip)
    local db = GetDb()
    if not (db and db.gatheringLevels and ns.TooltipsData) then return false end
    local name = Line(tip, "Left", 1):GetText()
    if not canaccessvalue(name) then return false end
    local needed, key = ns.TooltipsData.NodeLevel(name)
    if not needed then return false end
    for i = 2, tip:NumLines() do
        local text = Line(tip, "Left", i):GetText()
        if canaccessvalue(text) and type(text) == "string" and IsRequirement(text) then
            MarkSkillLine(tip, i, key, needed)
            return true
        end
    end
    return false
end

-- (11-17, after PrettyTooltip) Worn gear's durability from yellow to red as it wears down; whole gear
-- stays white
local durabilityPattern
local function ColorDurability(tip)
    durabilityPattern = durabilityPattern or FormatPattern(_G.DURABILITY_TEMPLATE) or false
    if not durabilityPattern then return end
    for i = 2, tip:NumLines() do
        local line = Line(tip, "Left", i)
        local text = line and line:GetText()
        if canaccessvalue(text) and type(text) == "string" then
            local a, b = text:match(durabilityPattern)
            local have, most = tonumber(a), tonumber(b)
            if have and most and most > 0 and have < most then
                local first, last = text:find("%d.*%d")
                local value = have / most
                local r, g = 1, 1
                if value > 0.5 then r = (1 - value) * 2 else g = value * 2 end
                line:SetText(text:sub(1, first - 1) .. ColorToHex(r, g, 0.1) .. text:sub(first, last) .. "|r" .. text:sub(last + 1))
                return
            end
        end
    end
end

-- Disenchant Info (11-17): what a green, blue or purple weapon or armour piece gives (TooltipsData.lua)
local DISENCHANT_COLOR = { 0.78, 0.66, 1 }
local function AddDisenchantLine(tip)
    local db = GetDb()
    local D = ns.TooltipsData
    if not (db and db.disenchant and ShowDetails(db) and D) then return end
    local _, link = TooltipUtil.GetDisplayedItem(tip)
    if not (canaccessvalue(link) and link) then return end
    local itemID, _, _, equipLoc, _, classID = C_Item.GetItemInfoInstant(link)
    local _, _, quality, level = C_Item.GetItemInfo(link)
    if not (canaccessvalue(quality) and canaccessvalue(level) and canaccessvalue(itemID)) then return end
    local list = D.Disenchant(itemID, classID, quality, level, equipLoc)
    if not list then return end
    local names = {}
    for _, id in ipairs(list) do names[#names + 1] = D.MaterialName(id) or ("#" .. id) end
    local c = DISENCHANT_COLOR
    tip:AddLine(L["Disenchants into %s"]:format(table.concat(names, ", ")), c[1], c[2], c[3], true)
end

-- Price per Item (11-17): under a stack's sell price, the price of one
local SELL_PRICE_LINE = Enum.TooltipDataLineType and Enum.TooltipDataLineType.SellPrice
local function AddStackPriceLine(tip, data)
    local db = GetDb()
    if not (db and db.stackPrice and data) or db.hideSellPrice then return end
    local guid = data.guid
    if not (canaccessvalue(guid) and type(guid) == "string" and C_Item.GetItemLocation and C_Item.GetStackCount) then return end
    local found, location = pcall(C_Item.GetItemLocation, guid)
    if not (found and location) then return end
    local ok, count = pcall(C_Item.GetStackCount, location)
    if not (ok and canaccessvalue(count) and type(count) == "number" and count > 1) then return end
    -- only where the game shows a sell price (not at a vendor, which shows its own)
    local lines = data.lines
    if SELL_PRICE_LINE and canaccessvalue(lines) and type(lines) == "table" then
        local shown = false
        for _, line in ipairs(lines) do
            if canaccessvalue(line) and type(line) == "table" and line.type == SELL_PRICE_LINE then shown = true break end
        end
        if not shown then return end
    end
    local _, link = TooltipUtil.GetDisplayedItem(tip)
    if not (canaccessvalue(link) and link) then return end
    local price = select(11, C_Item.GetItemInfo(link))
    if not (canaccessvalue(price) and type(price) == "number" and price > 0) then return end
    tip:AddLine(L["%s each"]:format(GetCoinTextureString(price)), 0.6, 0.6, 0.6)
end

-- The aura a buff or debuff tooltip shows: only known while the game fills the tooltip, from the call
-- that filled it (SetUnitAura, SetUnitBuffByAuraInstanceID, ...). After PrettyTooltip's Aura.lua.
local function TooltipAura(tip)
    if not (tip.GetProcessingTooltipInfo and C_UnitAuras) then return nil end
    local ok, info = pcall(tip.GetProcessingTooltipInfo, tip)
    if not (ok and canaccessvalue(info) and type(info) == "table") then return nil end
    local getter, args = info.getterName, info.getterArgs
    if not (canaccessvalue(getter) and type(getter) == "string" and canaccessvalue(args) and type(args) == "table") then return nil end
    local unit, which, filter = args[1], args[2], args[3]
    if not (canaccessvalue(unit) and type(unit) == "string" and canaccessvalue(which) and which ~= nil) then return nil end
    if not canaccessvalue(filter) then filter = nil end
    if getter:find("Buff") then filter = "HELPFUL" elseif getter:find("Debuff") then filter = "HARMFUL" end
    local aura
    if getter:find("AuraInstanceID") and C_UnitAuras.GetAuraDataByAuraInstanceID then
        ok, aura = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unit, which)
    elseif C_UnitAuras.GetAuraDataByIndex then
        ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, which, filter)
    end
    if ok and canaccessvalue(aura) and type(aura) == "table" then return aura end
end

-- Show Caster (11-17): "Cast by Name", in the caster's class or reaction colour
local function AddCasterLine(tip, aura)
    local db = GetDb()
    if not (db and db.auraCaster and aura) then return end
    local source = aura.sourceUnit
    if not (canaccessvalue(source) and type(source) == "string") then return end
    local name = UnitName(source)
    if not (canaccessvalue(name) and type(name) == "string" and name ~= "") then return end
    local c = GetClassColor(source) or GetReactionColor(source) or { 1, 1, 1 }
    tip:AddLine(L["Cast by %s"]:format(ColorToHex(c[1], c[2], c[3]) .. name .. "|r"), 1, 1, 1)
end

-- (11-17, after PrettyTooltip) Magic, Curse, Poison or Disease on the name line's right, in the game's
-- debuff colours. The game writes the type there on debuffs; a buff gets it from these.
local DISPEL_NAMES = { Magic = L["Magic"], Curse = L["Curse"], Poison = L["Poison"], Disease = L["Disease"] }
local function ColorDispelType(tip, aura)
    if not aura then return end
    local dispel = aura.dispelName
    if not (canaccessvalue(dispel) and type(dispel) == "string") then return end
    local colors = _G.DebuffTypeColor
    local c = colors and colors[dispel]
    local right = Line(tip, "Right", 1)
    if not (c and right) then return end
    local text = right:GetText()
    if not canaccessvalue(text) then return end
    if not text or text == "" then
        right:SetText(DISPEL_NAMES[dispel] or dispel)
        right:Show()
    end
    right:SetTextColor(c.r, c.g, c.b)
end

-- for TooltipsLayout.lua (loaded after this file)
TIP.util = {
    GetDb = GetDb, Readable = Readable, Line = Line, ColorToHex = ColorToHex, UnitLevelColor = UnitLevelColor,
    FormatPattern = FormatPattern, PATTERN_MAGIC = PATTERN_MAGIC, DEFAULT_BORDER_COLOR = DEFAULT_BORDER_COLOR,
}

--------------------------------------------------
-- 8. VISIBILITY
--------------------------------------------------
local ACTION_OWNER_PATTERNS = { "^ActionButton", "^MultiBar", "^PetActionButton", "^StanceButton",
                                "^OverrideActionBarButton", "^ExtraActionButton", "^ZoneAbilityFrame" }

local function OwnerIsActionButton(tip)
    local owner = tip:GetOwner()
    if not owner or owner:IsForbidden() then return false end
    if owner.action ~= nil then return true end
    local name = owner.GetName and owner:GetName()
    if not name then return false end
    for _, pattern in ipairs(ACTION_OWNER_PATTERNS) do
        if name:find(pattern) then return true end
    end
    return false
end

local function MouseIsOverWorld()
    return WorldFrame:IsMouseMotionFocus()
end

-- per category: "always" shows, "combat" hides in combat, "never" hides
local function ShouldHide(category)
    local db = GetDb()
    -- the Gamepad UI keeps the mouse on the world, so world and UI cannot be told apart
    if not db or ns.IsGamepadUI() then return false end
    local mode = db.visibility and db.visibility[category] or "always"
    if mode == "always" then return false end
    if IsShiftKeyDown() then return false end
    if mode == "never" then return true end
    return InCombat()
end

-- Tooltips > On action/data bars, for FlareUI's own bars (the XP bar): true while it hides them (Hold
-- Shift shows them). With the Tooltips module off, nothing is hidden.
function ns.Tooltips.BarTooltipHidden()
    local db = GetDb()
    if not (db and db.enabled) then return false end
    return ShouldHide(CAT_ACTION)
end

local function HideIfNeeded(tip, category)
    if ShouldHide(category) then
        tip:Hide()
        return true
    end
    return false
end

--------------------------------------------------
-- 9. TOOLTIP HOOKS
--------------------------------------------------
-- A usable unit token: a secret one falls back to the owner frame's unit, or "mouseover" over the
-- world; nil leaves the tooltip as Blizzard drew it
local function TooltipUnit(tip)
    local _, unit = TooltipUtil.GetDisplayedUnit(tip)
    if canaccessvalue(unit) and unit == nil then unit = select(2, tip:GetUnit()) end
    if canaccessvalue(unit) and type(unit) == "string" then return unit end
    local owner = tip:GetOwner()
    if owner and not owner:IsForbidden() then
        local ownerUnit = owner.unit
        if canaccessvalue(ownerUnit) and ownerUnit == nil and owner.GetAttribute then ownerUnit = owner:GetAttribute("unit") end
        if ownerUnit and canaccessvalue(ownerUnit) and type(ownerUnit) == "string" then return ownerUnit end
    end
    if MouseIsOverWorld() then return "mouseover" end
end

-- A player's tooltip carries secret text and fails SafeToTouch: only the restyling is gated
local function OnTooltipSetUnit(tip, data)
    if tip ~= GameTooltip or tip:IsForbidden() then return end
    local unit = TooltipUnit(tip)
    local category = MouseIsOverWorld() and CAT_WORLD_UNIT or CAT_FRAME_UNIT
    if not unit then
        HideIfNeeded(tip, category)
        return
    end
    if not Readable(UnitExists(unit)) then return end
    if HideIfNeeded(tip, category) then return end

    AddTargetLine(tip, unit)
    HideHealthBar(true)
    if not SafeToTouch(tip) then return end
    ScrubLines(tip)
    ColorName(tip, unit)
    ApplyGuildLine(tip, unit)
    -- the class line goes only once it is on the level line: on a client whose level line does not
    -- start with LEVEL (ruRU: "60-го уровня") it stays where it is (11-13, a player report)
    local levelLine = ColorLevelLine(tip, unit)
    if levelLine then RemoveClassLine(tip, unit) end
    ColorFactionLine(tip)
    ColorQuestProgress(tip, data)
    AddCorpseSkill(tip, unit)
    AddNpcIdLine(tip, unit, data)
    ApplyColors(tip, GetUnitBorderColor(unit))
    -- (TooltipsLayout.lua: the portrait and badges, last: they need the final lines and border)
    if TIP.Layout then TIP.Layout.Unit(tip, unit, levelLine) end
end

-- "Action bars": every tooltip type an action button shows (spells and items, but also pet actions,
-- macros, mounts, toys and flyouts)
local function OnTooltipSetAny(tip)
    if tip == GameTooltip and SafeToTouch(tip) and OwnerIsActionButton(tip) then HideIfNeeded(tip, CAT_ACTION) end
end

local function OnTooltipSetItem(tip, data)
    if not SafeToTouch(tip) then return end

    local db = GetDb()
    local color
    if db and db.borderByQuality then
        local _, link = TooltipUtil.GetDisplayedItem(tip)
        if canaccessvalue(link) and link then
            local quality = select(3, C_Item.GetItemInfo(link))
            if canaccessvalue(quality) and quality then
                local r, g, b = C_Item.GetItemQualityColor(quality)
                if r then color = { Mute(r, g, b) } end
            end
        end
    end
    ApplyColors(tip, color)
    ColorDurability(tip)
    AddItemLevelLine(tip, data)
    AddStackPriceLine(tip, data)
    AddDisenchantLine(tip)
    AddIdLine(tip, "showItemID", L["Item ID"], data)
    if TIP.Layout then TIP.Layout.Item(tip, data) end
end

local function OnTooltipSetSpell(tip, data)
    if not SafeToTouch(tip) then return end
    ApplyColors(tip, nil)
    AddIdLine(tip, "showSpellID", L["Spell ID"], data)
    if TIP.Layout then TIP.Layout.Spell(tip, data) end
end

local function OnTooltipSetAura(tip, data)
    if tip == GameTooltip and not tip:IsForbidden() and HideIfNeeded(tip, CAT_AURA) then return end
    if not SafeToTouch(tip) then return end
    ApplyColors(tip, nil)
    local aura = TooltipAura(tip)
    ColorDispelType(tip, aura)
    AddCasterLine(tip, aura)
    AddIdLine(tip, "showSpellID", L["Spell ID"], data)
    if TIP.Layout then TIP.Layout.Aura(tip, data) end
end

-- (11-17) A macro with #showtooltip shows its spell's or item's tooltip: the data names it
-- in a nested block (as PrettyTooltip reads it), and the tooltip gets that spell's or item's treatment.
local NESTED = Enum.TooltipDataLineType and Enum.TooltipDataLineType.NestedBlock
local function OnTooltipSetMacro(tip, data)
    local lines = data and data.lines
    if not (NESTED and canaccessvalue(lines) and type(lines) == "table") then return end
    for index, line in ipairs(lines) do
        if not (canaccessvalue(line) and type(line) == "table") then return end
        if line.type == NESTED then
            local id, kind = line.tooltipID, line.tooltipType
            if not (canaccessvalue(id) and canaccessvalue(kind) and type(id) == "number") then return end
            if kind == Enum.TooltipDataType.Spell then
                OnTooltipSetSpell(tip, { id = id })
            elseif kind == Enum.TooltipDataType.Item then
                -- (the item's own lines: the sell price and item level checks read them)
                local shown = { id = id, lines = {} }
                for after = index + 1, #lines do shown.lines[#shown.lines + 1] = lines[after] end
                OnTooltipSetItem(tip, shown)
            end
            return
        end
    end
end

-- Anything not a unit / item / spell / aura: world objects and plain UI frames
local function OnTooltipShow(tip)
    if tip ~= GameTooltip or not SafeToTouch(tip) then return end
    -- a secret name still means a unit, handled in its own post-call
    local unitName = tip:GetUnit()
    if issecretvalue(unitName) or unitName then return end
    if MouseIsOverWorld() and HideIfNeeded(tip, CAT_WORLD_OBJECT) then return end
    -- Everything Else: a tooltip in Blizzard's spot for anything but the world, units and action bars
    if tip.fuiOther and HideIfNeeded(tip, CAT_OTHER) then return end
    -- Blizzard shows a tooltip after its post-calls: an item keeps the quality border just set
    if not tip:IsTooltipType(Enum.TooltipDataType.Item) then ApplyColors(tip, nil) end
    HideHealthBar(false)
    -- world objects (herbs, ore, quest objects) have no post-call of their own
    if MouseIsOverWorld() then
        ColorQuestProgress(tip, nil)
        if AddNodeSkill(tip) then tip:Show() end
    end
end

--------------------------------------------------
-- 10. ANCHORING
--------------------------------------------------
-- Per kind (11-12, a player asked): the world (anchor), unit frames (anchorFrames), action bars
-- (anchorBars) and everything else in Blizzard's spot (anchorOther); the last two start as the unit
-- frames' choice, which was everything off the world before
local function AnchorKind(tooltip, parent)
    if MouseIsOverWorld() then return "world" end
    if OwnerIsActionButton(tooltip) then return "bars" end
    if parent.IsForbidden and parent:IsForbidden() then return "other" end
    local unit = parent.unit
    if not (canaccessvalue(unit) and unit) and parent.GetAttribute then unit = parent:GetAttribute("unit") end
    if canaccessvalue(unit) and type(unit) == "string" then return "frames" end
    return "other"
end

-- Mouseover on Buffs/Debuffs and Party/Raid Auras: an aura icon's tooltip, once Blizzard has given it its
-- owner, is turned to follow the pointer. Only the anchor type changes, after Blizzard's call.
-- Mouseover (11-12): one main switch (tooltips.mouseover, Settings > Look) for every kind, and per kind
-- an exception (tooltips.mouseoverKinds[kind], Settings tab > Mouseover) while it differs. Kinds: world,
-- frames, bars, auras, groupAuras, other. The per-kind anchors of the day before convert once.
local MOUSEOVER_KINDS = { "world", "frames", "bars", "auras", "groupAuras", "other" }
TIP.MOUSEOVER_KINDS = MOUSEOVER_KINDS
local function ConvertAnchors(db)
    if db.mouseoverSet then return end
    db.mouseoverSet = true
    local function On(v) return v == "cursorOffset" end
    local old = { world = On(db.anchor), frames = On(db.anchorFrames),
                  bars = On(db.anchorBars or db.anchorFrames), other = On(db.anchorOther or db.anchorFrames),
                  auras = On(db.anchorAuras), groupAuras = On(db.anchorGroupAuras) }
    db.mouseover = old.world
    db.mouseoverKinds = {}
    for _, kind in ipairs(MOUSEOVER_KINDS) do
        if old[kind] ~= old.world then db.mouseoverKinds[kind] = old[kind] end
    end
end
function TIP.Mouseover(kind)
    local db = GetDb()
    if not db then return false end
    ConvertAnchors(db)
    local own = kind and db.mouseoverKinds and db.mouseoverKinds[kind]
    if own ~= nil then return own end
    return db.mouseover == true
end
-- a kind's switch: the same as the main one is no exception
function TIP.SetKindMouseover(kind, on)
    local db = GetDb()
    if not db then return end
    ConvertAnchors(db)
    db.mouseoverKinds = db.mouseoverKinds or {}
    if (on and true or false) == (db.mouseover == true) then db.mouseoverKinds[kind] = nil else db.mouseoverKinds[kind] = on and true or false end
end
-- the main switch: every kind follows it again
function TIP.SetMouseover(on)
    local db = GetDb()
    if not db then return end
    ConvertAnchors(db)
    db.mouseover = on and true or false
    db.mouseoverKinds = {}
end

-- Offset X / Offset Y (11-14, a player asked): how far a mouseover tooltip sits from the pointer
-- Off in Combat (11-17): in a fight, tooltips stay in Blizzard's spot instead of following the mouse
local function MouseoverNow(kind)
    if not TIP.Mouseover(kind) then return false end
    local db = GetDb()
    return not (db and db.cursorCombat and InCombat())
end
TIP.MouseoverNow = MouseoverNow

function TIP.CursorOffset()
    local db = GetDb()
    if not db then return 0, 0 end
    return tonumber(db.cursorX) or 0, tonumber(db.cursorY) or 0
end

local function OnAuraTipOwner(tip, owner)
    local kind = owner and ns.auraTipKind[owner]
    if not kind or ns.IsGamepadUI() then return end
    if MouseoverNow(kind == "group" and "groupAuras" or "auras") then pcall(tip.SetAnchorType, tip, "ANCHOR_CURSOR_RIGHT", TIP.CursorOffset()) end
end
local function HookAuraTooltips()
    for _, tip in ipairs({ GameTooltip, _G.AuraButtonTooltip }) do
        if tip and not tip.fuiAuraHooked and not (tip.IsForbidden and tip:IsForbidden()) then
            tip.fuiAuraHooked = true
            hooksecurefunc(tip, "SetOwner", OnAuraTipOwner)
        end
    end
end

local SCREEN_MARGIN = 14   -- Screen Corner's gap to the screen's edges
-- Screen Corner: the tooltip in its corner; lifted while a health bar hangs under it (11-17, a screenshot:
-- every tooltip was lifted, spells too). The health bar's watcher lifts and lowers it.
function TIP.PlaceInCorner(tooltip, barBelow)
    local at = tooltip.fuiCorner
    if not at then return end
    local x = at:find("RIGHT$") and -SCREEN_MARGIN or SCREEN_MARGIN
    local y = at:find("^TOP") and -SCREEN_MARGIN or SCREEN_MARGIN
    local lift = barBelow and at:find("^BOTTOM") and true or false
    if lift then y = y + 14 end
    tooltip:ClearAllPoints()
    tooltip:SetPoint(at, UIParent, at, x, y)
    tooltip.fuiLifted = lift
end
-- the health bar under the tooltip, as it is now
-- a unit's tooltip is coming (a unit frame's, or the world's over a unit): its bar will hang under it
local function BarBelowComing(kind)
    if TIP.HealthBarMode() ~= "below" then return false end
    return kind == "frames" or (kind == "world" and Readable(UnitExists("mouseover")) and true) or false
end
local function ApplyAnchor(tooltip, parent)
    local db = GetDb()
    if not (db and tooltip and parent) then return end
    if tooltip ~= GameTooltip then return end
    local kind = AnchorKind(tooltip, parent)
    -- Everything Else's Show is checked as it shows (OnTooltipShow)
    tooltip.fuiOther = kind == "other" or nil
    -- (Screen Corner below: only while this anchor puts it there, 11-17)
    tooltip.fuiCorner, tooltip.fuiLifted = nil, nil

    -- the Gamepad UI has no cursor to follow
    if not ns.IsGamepadUI() and MouseoverNow(kind) then
        tooltip:SetOwner(parent, "ANCHOR_CURSOR_RIGHT", TIP.CursorOffset())
        return
    end
    -- Tooltip Corner (11-14, a player asked): Blizzard grows the tooltip from the HUD Tooltip box's
    -- nearest corner when the box isn't snapped to one, so it jumps sides as the box moves. A fixed
    -- corner puts the tooltip's same corner on the box's.
    local corner = db.corner
    -- Screen Corner (11-17, a player asked): the very corner of the screen instead of the HUD Tooltip box;
    -- Auto is the bottom right. As far from the edges as FlareUI's minimap sits (11-17);
    -- a health bar under the tooltip keeps on screen.
    if db.screenCorner then
        tooltip.fuiCorner = (corner and corner ~= "auto") and corner or "BOTTOMRIGHT"
        -- (lifted at once for a unit, 11-17: no 14 px jump when the bar shows)
        TIP.PlaceInCorner(tooltip, BarBelowComing(kind))
        return
    end
    local box = _G.GameTooltipDefaultContainer or _G.SharedTooltipDefaultContainer
    if corner and corner ~= "auto" and box then
        tooltip:ClearAllPoints()
        tooltip:SetPoint(corner, box, corner)
    end
end

--------------------------------------------------
-- 11. PUBLIC
--------------------------------------------------
-- One font setting on a font object (or a settings preview's font string)
function TIP.ApplyFontTo(fontObject, fontDb, sizeOffset)
    if not (fontObject and fontDb) then return end
    local flags = fontDb.flags or "NONE"
    if flags == "NONE" then flags = "" end
    -- member by member: other alphabets keep a face that has their letters
    ns.SetFontObjectFace(fontObject, ns.GetFontPath(fontDb.face or "Friz Quadrata TT"), (fontDb.size or 12) + (sizeOffset or 0), flags)
    ns.ApplyShadow(fontObject, fontDb)
end

-- Blizzard's tooltip font objects; small lines two points under the content size
local function ApplyFonts()
    local db = GetDb()
    if not db then return end
    local Apply = TIP.ApplyFontTo
    Apply(_G.GameTooltipHeaderText, db.titleFont)
    Apply(_G.GameTooltipText, db.contentFont)
    Apply(_G.GameTooltipTextSmall, db.contentFont, -2)
end

-- Compare with Shift: the comparison tooltips show only while Shift is held (Blizzard's
-- alwaysCompareItems off). Off puts back the player's own value, only when FlareUI changed it.
local COMPARE_CVAR = "alwaysCompareItems"
local function Forced()
    return ns.Tweaks and ns.Tweaks.ForcedCVars and ns.Tweaks.ForcedCVars("compare")
end

local function RestoreCompare()
    local forced = Forced()
    if forced and forced.compare ~= nil then
        pcall(SetCVar, COMPARE_CVAR, forced.compare)
        forced.compare = nil
    end
end

local function ApplyCompare()
    local db = GetDb()
    local forced = Forced()
    if not (db and forced) then return end
    if db.compareShift then
        if forced.compare == nil then forced.compare = GetCVar(COMPARE_CVAR) or "1" end
        if GetCVar(COMPARE_CVAR) ~= "0" then pcall(SetCVar, COMPARE_CVAR, 0) end
    else
        RestoreCompare()
    end
end

-- With the module off, Init never runs: the value FlareUI changed goes back here
function TIP:ShouldLoad()
    local db = GetDb()
    if db and db.enabled == false then RestoreCompare() end
    return true
end

function TIP:Refresh()
    if not self.initialized then return end
    ApplyCompare()
    ApplyFonts()
    ApplyScaleToAll()
    if GameTooltip and GameTooltip:IsShown() then
        ApplyColors(GameTooltip, nil)
        HideHealthBar(true)   -- (a unit tooltip keeps its room: the GUID check decides)
    end
end

function TIP:Init()
    if self.initialized then return end
    local db = GetDb()
    if not db then return end
    self.initialized = true
    SetupHealthOverlay()

    -- world object tooltips only fire mouse motion when the world frame tracks it
    WorldFrame:EnableMouseMotion(true)

    local add = TooltipDataProcessor.AddTooltipPostCall
    add(Enum.TooltipDataType.Unit, OnTooltipSetUnit)
    add(Enum.TooltipDataType.Item, OnTooltipSetItem)
    add(Enum.TooltipDataType.Spell, OnTooltipSetSpell)
    add(Enum.TooltipDataType.UnitAura, OnTooltipSetAura)
    if Enum.TooltipDataType.Macro then add(Enum.TooltipDataType.Macro, OnTooltipSetMacro) end
    add(TooltipDataProcessor.AllTypes, OnTooltipSetAny)

    -- Hide Sell Price (11-17, a player asked): the item's sell price line is dropped the same way
    if Enum.TooltipDataLineType and Enum.TooltipDataLineType.SellPrice and TooltipDataProcessor.AddLinePreCall then
        TooltipDataProcessor.AddLinePreCall(Enum.TooltipDataLineType.SellPrice, function()
            local now = GetDb()
            if now and now.hideSellPrice then return true end
        end)
    end

    -- "Show threat" off: a line pre-call returning true drops the threat line without a gap
    if Enum.TooltipDataLineType and Enum.TooltipDataLineType.UnitThreat and TooltipDataProcessor.AddLinePreCall then
        TooltipDataProcessor.AddLinePreCall(Enum.TooltipDataLineType.UnitThreat, function()
            local now = GetDb()
            if now and now.showThreat == false then return true end
        end)
    end

    GameTooltip:HookScript("OnShow", OnTooltipShow)
    GameTooltip:HookScript("OnHide", function(tip) tip.fuiOther, tip.fuiCorner, tip.fuiLifted = nil, nil, nil end)

    -- Blizzard restyles tooltips often: the colours go back on after each restyle
    hooksecurefunc("SharedTooltip_SetBackdropStyle", function(tip)
        if tip == GameTooltip or tip == _G.ItemRefTooltip then ApplyColors(tip, nil) end
    end)
    hooksecurefunc("GameTooltip_SetDefaultAnchor", ApplyAnchor)
    HookAuraTooltips()
    -- (the aura containers' own tooltip comes with Blizzard_AuraContainer)
    if EventUtil and EventUtil.ContinueOnAddOnLoaded then
        EventUtil.ContinueOnAddOnLoaded("Blizzard_AuraContainer", HookAuraTooltips)
    end

    -- Details on Shift (11-17): the tooltip under the mouse redraws as Shift goes down or up
    local shift = CreateFrame("Frame")
    shift:RegisterEvent("MODIFIER_STATE_CHANGED")
    shift:SetScript("OnEvent", function(_, _, key)
        local now = GetDb()
        if not (now and now.detailsShift) or (key ~= "LSHIFT" and key ~= "RSHIFT") then return end
        -- (only a tooltip FlareUI may touch: a player's, rebuilt from here, runs Blizzard's code under
        -- FlareUI's taint on its secret line colours and errors, 11-17 Logs/General.log)
        if GameTooltip:IsShown() and SafeToTouch(GameTooltip) and GameTooltip.RefreshData then
            pcall(GameTooltip.RefreshData, GameTooltip)
        end
    end)

    ApplyCompare()
    ApplyFonts()
    ApplyScaleToAll()
end

--------------------------------------------------
-- 12. SETTINGS PREVIEW SAMPLE
-- A made-up tooltip in the module's own look (border, background, colours, fonts). It is a plain
-- frame with the tooltip's NineSlice: a GameTooltip needs an owner to lay out its lines.
-- (11-17) The Layout section's icon is drawn with TooltipsLayout.lua's.
--------------------------------------------------
do
    local PAD, GAP, SPACING, WRAP = 10, 15, 2, 230
    local ICON, ICON_GAP, PLATE = 34, 8, 17   -- as TooltipsLayout.lua (PLATE: its height and gap)
    local SAMPLE_CLASS = "MAGE"

    -- the saved settings, with the value the Info Panel is previewing in place of the saved one
    local function SampleDb()
        local db = GetDb() or {}
        local P = ns.SettingsPreview
        local spec = P and P.activeSpec
        local key = spec and spec.value ~= nil and type(spec.path) == "string" and spec.path:match("^tooltips%.(%w+)$")
        if not key then return db end
        return setmetatable({ [key] = spec.value }, { __index = db })
    end

    local function NewTip(parent)
        local tip = CreateFrame("Frame", nil, parent, "TooltipBackdropTemplate")
        tip.fuiSample = true
        tip:EnableMouse(false)
        tip:SetFrameLevel(parent:GetFrameLevel() + 1)
        if NineSliceUtil and NineSliceUtil.GetLayout then
            pcall(NineSliceUtil.ApplyLayout, tip.NineSlice, NineSliceUtil.GetLayout("TooltipDefaultLayout"))
        end
        tip.left, tip.right = {}, {}
        -- the health bar as Blizzard's template has it: under the tooltip, its full width
        local bar = CreateFrame("StatusBar", nil, tip)
        bar:SetHeight(8)
        bar:SetPoint("TOPLEFT", tip, "BOTTOMLEFT", 2, -1)
        bar:SetPoint("TOPRIGHT", tip, "BOTTOMRIGHT", -2, -1)
        TIP.StyleHealthBar(bar)   -- (FlareUI's look, as the live overlay, 11-16)
        bar:SetStatusBarColor(0.4, 1, 0)   -- (80%, in Blizzard's green-to-red)
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0.8)
        bar:Hide()
        tip.bar = bar
        return tip
    end

    local function LineString(tip, side, i)
        local fs = tip[side][i]
        if not fs then
            fs = tip:CreateFontString(nil, "ARTWORK", "GameTooltipText")
            tip[side][i] = fs
        end
        return fs
    end

    -- the Layout tab's parts on a sample, made once (nil before TooltipsLayout.lua has loaded)
    local function SampleParts(tip)
        local Layout = TIP.Layout
        if not Layout then return nil end
        if not tip.fuiIcon then
            tip.fuiIcon = Layout.NewIcon(tip)
        end
        return Layout
    end

    -- lines: { text, r, g, b, title = true, wrap = true, right = text, rr, rg, rb }
    -- barMode: the Health Bar's place, "off", "below" or "inside" (11-16)
    -- extras (11-17): icon = { texture or unit, plate }
    local function Fill(tip, lines, barMode, extras)
        local db = GetDb() or {}
        extras = extras or {}
        local Layout = SampleParts(tip)
        local icon = Layout and extras.icon
        local need = icon and (ICON + (icon.plate and PLATE or 0)) or 0
        local width, height = 0, PAD
        for i, line in ipairs(lines) do
            -- lines beside the icon start after it
            local indent = (icon and height - PAD < need) and (ICON + ICON_GAP) or 0
            local left = LineString(tip, "left", i)
            local right = LineString(tip, "right", i)
            left:SetFontObject(line.title and "GameTooltipHeaderText" or "GameTooltipText")
            TIP.ApplyFontTo(left, line.title and db.titleFont or db.contentFont)
            left:SetWidth(line.wrap and WRAP or 0)
            left:SetWordWrap(line.wrap and true or false)
            left:SetJustifyH("LEFT")
            left:SetText(line[1])
            left:SetTextColor(line[2] or 1, line[3] or 1, line[4] or 1)
            left:ClearAllPoints()
            left:SetPoint("TOPLEFT", tip, "TOPLEFT", PAD + indent, -height)
            left:Show()
            local w = left:GetStringWidth()
            if line.wrap and w > WRAP then w = WRAP end
            w = w + indent
            local h = left:GetStringHeight()
            if line.right then
                right:SetFontObject("GameTooltipText")
                TIP.ApplyFontTo(right, db.contentFont)
                right:SetText(line.right)
                right:SetTextColor(line.rr or 1, line.rg or 1, line.rb or 1)
                right:ClearAllPoints()
                right:SetPoint("TOPRIGHT", tip, "TOPRIGHT", -PAD, -height)
                right:Show()
                w = w + GAP + right:GetStringWidth()
                h = math.max(h, right:GetStringHeight())
            else
                right:Hide()
            end
            if w > width then width = w end
            height = height + h + SPACING
        end
        -- too few lines beside the icon: the tooltip is as tall as it
        if icon and height - PAD < need then height = PAD + need + SPACING end
        for i = #lines + 1, #tip.left do tip.left[i]:Hide() end
        for i = #lines + 1, #tip.right do tip.right[i]:Hide() end
        width = math.ceil(width + PAD * 2)
        height = math.ceil(height - SPACING + PAD)
        local mode = barMode or "off"
        if mode == "inside" then height = height + TIP.INSIDE_PAD end
        tip:SetSize(width, height)
        if mode ~= "off" then TIP.PlaceHealthBar(tip.bar, tip, mode) end
        tip.bar:SetShown(mode ~= "off")
        -- the Layout parts, coloured once the border's colour is known (PaintExtras)
        tip.fuiPending = { icon = icon }
        if tip.fuiIcon then tip.fuiIcon:Hide() end
        tip:Show()
        return width, height
    end

    local function PaintExtras(tip)
        local pending, Layout = tip.fuiPending, TIP.Layout
        if not (pending and Layout and tip.fuiIcon) then return end
        local border = TIP.borderColorOf[tip] or DEFAULT_BORDER_COLOR
        if pending.icon then
            tip.fuiIcon:ClearAllPoints()
            tip.fuiIcon:SetPoint("TOPLEFT", tip, "TOPLEFT", PAD, -PAD)
            Layout.PaintIcon(tip.fuiIcon, pending.icon, border, pending.icon.plate)
        end
    end

    local function ClassColorOf(classFile)
        local c = C_ClassColor and C_ClassColor.GetClassColor(classFile)
        return c and { c.r, c.g, c.b } or { 1, 1, 1 }
    end

    local function RaceName(raceID, fallback)
        local info = C_CreatureInfo and C_CreatureInfo.GetRaceInfo and C_CreatureInfo.GetRaceInfo(raceID)
        return info and info.raceName or fallback
    end

    local function Badges(list)
        local out = {}
        for _, b in ipairs(list) do out[#out + 1] = ColorToHex(b[2][1], b[2][2], b[2][3]) .. b[1] .. "|r" end
        return table.concat(out, " |cff6f6f6f\194\183|r ")
    end

    local function DifficultyText(level)
        local head = (_G.LEVEL or "Level") .. " " .. (level > 0 and level or "??")
        local difficulty = level > 0 and LevelColor(level) or { r = 1, g = 0.1, b = 0.1 }
        return difficulty and (ColorToHex(difficulty.r, difficulty.g, difficulty.b) .. head .. "|r") or head, difficulty
    end

    -- a friendly player, as the unit post-call leaves the tooltip
    local function UnitLines(db)
        local class = ClassColorOf(SAMPLE_CLASS)
        local className = (_G.LOCALIZED_CLASS_NAMES_MALE and _G.LOCALIZED_CLASS_NAMES_MALE[SAMPLE_CLASS]) or "Mage"
        local horde = Readable(UnitFactionGroup("player")) == "Horde"
        local name = "Elaria"
        if db.nameColor == "class" then name = ColorToHex(class[1], class[2], class[3]) .. name .. "|r" end
        local lines = { { name, title = true } }
        -- Badges (11-17): the tags on the name line's right
        if db.badges then lines[1].right = Badges({ { L["PvP"], { 1, 0.62, 0.4 } }, { L["AFK"], { 0.65, 0.65, 0.65 } } }) end
        if db.showGuild ~= false then
            local c = db.nameColor == "class" and Lighten(class) or { 1, 1, 1 }
            lines[#lines + 1] = { "<Dawnwatch>", c[1], c[2], c[3] }
        end
        -- "Level N" in the difficulty colour, the rest white with the class name (ColorLevelLine)
        local level = 60
        local text, difficulty = DifficultyText(level)
        local race = horde and RaceName(5, "Undead") or RaceName(1, "Human")
        -- (with the level on the portrait's plate, the line drops it: TooltipsLayout.lua DropLevelWord)
        if db.headerIcon then text = "" end
        lines[#lines + 1] = { text .. "|cffffffff" .. (text ~= "" and " " or "") .. race .. " " .. className .. "|r" }
        if not db.hideFaction then
            local f = FACTION_LINE_COLORS[horde and 1 or 2]
            lines[#lines + 1] = { f.hex .. (_G[f.word] or (horde and "Horde" or "Alliance")) .. "|r" }
        end
        if db.showTarget then
            lines[#lines + 1] = { (_G.TARGET or "Target") .. ": |cffff4040" .. (_G.YOU or "You") .. "|r" }
        end
        local extras = {}
        if db.headerIcon then
            local c = difficulty or { r = 1, g = 0.82, b = 0 }
            extras.icon = { unit = "player", plate = { text = tostring(level), color = { c.r, c.g, c.b } } }
        end
        return lines, class, extras
    end

    -- a dead rare beast (11-17): badges, the silver dragon on its level, Gathering Levels, a finished
    -- objective and its NPC ID
    local function CreatureLines(db)
        local reaction = REACTION_COLORS[2]
        local level = 37
        local text, difficulty = DifficultyText(level)
        local hex = ColorToHex(reaction[1], reaction[2], reaction[3])
        local beast = _G.BEAST or "Beast"
        local rare = db.badges and "" or (" " .. CLASS_TAGS.rare)
        local lines = { { "Broken Tooth", reaction[1], reaction[2], reaction[3], title = true },
            { (db.headerIcon and "" or (text .. " ")) .. hex .. beast .. "|r" .. rare } }
        if db.badges then lines[1].right = Badges({ { L["Rare"], { 0.8, 0.85, 0.95 } }, { _G.DEAD or L["Dead"], { 0.6, 0.6, 0.6 } } }) end
        local skin = { (_G.UNIT_SKINNABLE_LEATHER or "Skinnable"), 1, 0.82, 0 }
        if db.gatheringLevels then
            skin[1] = skin[1] .. " (" .. 185 .. ")"
            skin.right, skin.rr, skin.rg, skin.rb = L["Your skill: %d"]:format(172), 0.6, 0.6, 0.6
        end
        lines[#lines + 1] = skin
        lines[#lines + 1] = { " - Broken Tooth's fang: 1/1", QUEST_DONE[1], QUEST_DONE[2], QUEST_DONE[3] }
        if db.showItemID or db.showSpellID then
            lines[#lines + 1] = { " ", right = L["NPC ID"] .. " 2850", rr = 0.5, rg = 0.5, rb = 0.5 }
        end
        local extras = {}
        if db.headerIcon then
            local c = difficulty
            extras.icon = { texture = "Interface\\Icons\\Ability_Hunter_Pet_Wolf",
                plate = { text = tostring(level), color = { c.r, c.g, c.b }, dragon = "silver" } }
        end
        return lines, reaction, extras
    end

    local function Format(pattern, fallback, ...)
        if type(pattern) ~= "string" then return fallback end
        local ok, text = pcall(string.format, pattern, ...)
        return ok and text or fallback
    end

    -- an epic item (equipped: the rare one it is compared with)
    local function ItemLines(db, equipped)
        local id = equipped and 16808 or 16914
        local r, g, b = C_Item.GetItemQualityColor(equipped and 3 or 4)
        r, g, b = r or 1, g or 1, b or 1
        local name = Readable((C_Item.GetItemInfo(id)))
        if type(name) ~= "string" then name = equipped and "Felheart Horns" or "Netherwind Crown" end
        local lines = {}
        if equipped then lines[1] = { _G.CURRENTLY_EQUIPPED or "Currently Equipped", 0.5, 0.5, 0.5 } end
        lines[#lines + 1] = { name, r, g, b, title = not equipped }
        local cloth = C_Item.GetItemSubClassInfo and C_Item.GetItemSubClassInfo(4, 1)
        local armor = equipped and 81 or 87
        lines[#lines + 1] = { _G.ITEM_BIND_ON_PICKUP or "Binds when picked up" }
        lines[#lines + 1] = { _G.INVTYPE_HEAD or "Head", right = type(cloth) == "string" and cloth or "Cloth" }
        -- (Badges, 11-17: the binding goes beside a slot with nothing on its right; a head piece has
        -- its armour type there, so it stays)
        lines[#lines + 1] = { Format(_G.ARMOR_TEMPLATE, armor .. " Armor", armor) }
        lines[#lines + 1] = { "+" .. (equipped and 20 or 16) .. " " .. (_G.SPELL_STAT3_NAME or "Stamina") }
        lines[#lines + 1] = { "+" .. (equipped and 10 or 16) .. " " .. (_G.SPELL_STAT4_NAME or "Intellect") }
        -- worn down to 31 of 70, in its colour (ColorDurability, 11-17)
        local durability = Format(_G.DURABILITY_TEMPLATE, "Durability 31 / 70", 31, 70)
        if not equipped then
            local first, last = durability:find("%d.*%d")
            if first then durability = durability:sub(1, first - 1) .. "|cffffb31a" .. durability:sub(first, last) .. "|r" .. durability:sub(last + 1) end
        end
        lines[#lines + 1] = { durability }
        lines[#lines + 1] = { Format(_G.ITEM_MIN_LEVEL, "Requires Level 60", 60) }
        -- Simplified Item Stats (ItemStats.lua) writes the short form
        local power = equipped and 15 or 26
        if db.shortItemStats then
            lines[#lines + 1] = { "+" .. power .. " " .. (_G.ITEM_MOD_SPELL_POWER_SHORT or "Spell Power"), 0, 1, 0 }
        else
            lines[#lines + 1] = { Format(_G.TOOLTIP_ITEM_STAT_SPELL_POWER_INCREASE,
                "Equip: Increases damage and healing done by magical spells and effects by up to " .. power .. ".", power),
                0, 1, 0, wrap = true }
        end
        local details = not db.detailsShift or IsShiftKeyDown()
        if db.disenchant and details and not equipped and ns.TooltipsData then
            local c = DISENCHANT_COLOR
            lines[#lines + 1] = { L["Disenchants into %s"]:format(ns.TooltipsData.MaterialName(20725) or "Nexus Crystal"), c[1], c[2], c[3] }
        end
        if db.showItemID and details then
            lines[#lines + 1] = { " ", right = L["Item ID"] .. " " .. id, rr = 0.5, rg = 0.5, rb = 0.5 }
        end
        local border
        if db.borderByQuality then border = { Mute(r, g, b) } end
        local extras = {}
        if db.headerIcon and not equipped then extras.icon = { texture = select(5, C_Item.GetItemInfoInstant(id)) or "Interface\\Icons\\INV_Misc_QuestionMark" } end
        return lines, border, extras
    end

    -- a stack of cloth (11-17: Price per Item)
    local function StackLines(db)
        local name = Readable((C_Item.GetItemInfo(14047)))
        if type(name) ~= "string" then name = "Runecloth" end
        local lines = { { name .. " (20)", 1, 1, 1, title = true }, { (C_Item.GetItemClassInfo and C_Item.GetItemClassInfo(7)) or "Trade Goods" } }
        if not db.hideSellPrice then
            lines[#lines + 1] = { _G.SELL_PRICE and (_G.SELL_PRICE .. ": " .. GetCoinTextureString(800)) or GetCoinTextureString(800) }
            if db.stackPrice then lines[#lines + 1] = { L["%s each"]:format(GetCoinTextureString(40)), 0.6, 0.6, 0.6 } end
        end
        local extras = {}
        if db.headerIcon then extras.icon = { texture = select(5, C_Item.GetItemInfoInstant(14047)) or "Interface\\Icons\\INV_Fabric_Linen_01" } end
        return lines, nil, extras
    end

    -- Frostbolt (11-17): Badges's school and rank, the Spell Strip's one row, the icon
    local function SpellLines(db)
        local id = 116
        local name = Readable(C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or "Frostbolt"
        local rank = (_G.RANK or "Rank") .. " 3"
        local lines = {}
        if db.badges then
            lines[1] = { name, title = true, right = Badges({ { _G.STRING_SCHOOL_FROST or "Frost", { 0.5, 0.85, 1 } }, { rank, { 0.72, 0.72, 0.72 } } }) }
        else
            lines[1] = { name, title = true, right = rank, rr = 0.5, rg = 0.5, rb = 0.5 }
        end
        if db.spellStrip then
            -- the game's own words on one row, the cost in mana blue (TooltipsLayout.lua)
            lines[#lines + 1] = { "|cff80b3ff" .. Format(_G.MANA_COST, "50 Mana", 50) .. "|r |cff6f6f6f\194\183|r "
                .. Format(_G.SPELL_CAST_TIME_SEC, "2.2 sec cast", 2.2) .. " |cff6f6f6f\194\183|r " .. Format(_G.SPELL_RANGE, "30 yd range", "30") }
        else
            lines[#lines + 1] = { Format(_G.MANA_COST, "50 Mana", 50), right = Format(_G.SPELL_RANGE, "30 yd range", "30") }
            lines[#lines + 1] = { Format(_G.SPELL_CAST_TIME_SEC, "2.2 sec cast", 2.2) }
        end
        lines[#lines + 1] = { L["Launches a bolt of frost at the enemy, causing Frost damage and slowing movement speed."],
            1, 0.82, 0, wrap = true }
        if db.showSpellID and (not db.detailsShift or IsShiftKeyDown()) then
            lines[#lines + 1] = { " ", right = L["Spell ID"] .. " " .. id, rr = 0.5, rg = 0.5, rb = 0.5 }
        end
        local extras = {}
        if db.headerIcon then
            local icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
            extras.icon = { texture = icon or "Interface\\Icons\\Spell_Frost_FrostBolt02" }
        end
        return lines, nil, extras
    end

    -- Curse of Agony on you (11-17): its dispel type and Show Caster
    local function AuraLines(db)
        local id = 980
        local name = Readable(C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or "Curse of Agony"
        local curse = _G.DebuffTypeColor and _G.DebuffTypeColor.Curse
        local first = { name, title = true, right = L["Curse"] }
        if curse then first.rr, first.rg, first.rb = curse.r, curse.g, curse.b end
        local lines = { first, { L["Suffering Shadow damage every 3 sec."], 1, 1, 1, wrap = true },
            { Format(_G.SPELL_TIME_REMAINING_SEC, "18 seconds remaining", 18), 1, 0.82, 0 } }
        if db.auraCaster then
            local c = ClassColorOf("WARLOCK")
            lines[#lines + 1] = { L["Cast by %s"]:format(ColorToHex(c[1], c[2], c[3]) .. "Vexelia|r") }
        end
        local extras = {}
        if db.headerIcon then
            local icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
            extras.icon = { texture = icon or "Interface\\Icons\\Spell_Shadow_CurseOfSargeras" }
        end
        return lines, nil, extras
    end

    local KINDS = { creature = CreatureLines, stack = StackLines, spell = SpellLines, aura = AuraLines }

    local function DrawTip(tip, kind, equipped)
        local db = SampleDb()
        local w, h
        if kind == "unit" then
            local lines, class, extras = UnitLines(db)
            w, h = Fill(tip, lines, TIP.HealthBarMode(db), extras)
            ApplyColors(tip, GetUnitBorderColor(nil, class, REACTION_COLORS[5]))
            local c = TIP.borderColorOf[tip]
            if c and tip.bar.fuiBorder then tip.bar.fuiBorder:SetBackdropBorderColor(c[1], c[2], c[3], 1) end
        elseif KINDS[kind] then
            local lines, reaction, extras = KINDS[kind](db)
            w, h = Fill(tip, lines, "off", extras)
            ApplyColors(tip, reaction and db.borderByReaction and reaction or nil)
        else
            local lines, border, extras = ItemLines(db, equipped)
            w, h = Fill(tip, lines, "off", extras)
            ApplyColors(tip, border)
        end
        PaintExtras(tip)
        return w, h
    end

    -- kind: "unit" (default), "item", "compare" (the item beside the one it is compared with), and
    -- (11-17) "creature", "stack", "spell" or "aura"
    function TIP.CreateSample(parent, kind)
        kind = kind or "unit"
        if kind == "compare" then
            local holder = CreateFrame("Frame", nil, parent)
            holder.fuiSample, holder.fuiKind = true, kind
            holder:EnableMouse(false)
            holder:SetFrameLevel(parent:GetFrameLevel() + 1)
            holder.item, holder.equipped = NewTip(holder), NewTip(holder)
            return holder
        end
        local tip = NewTip(parent)
        tip.fuiKind = kind
        return tip
    end

    function TIP.DrawSample(f, kind)
        kind = kind or f.fuiKind or "unit"
        if kind ~= "compare" then return DrawTip(f, kind) end
        local w1, h1 = DrawTip(f.item, "item")
        local w2, h2 = DrawTip(f.equipped, "item", true)
        f.item:ClearAllPoints()
        f.item:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        f.equipped:ClearAllPoints()
        f.equipped:SetPoint("TOPLEFT", f.item, "TOPRIGHT", 4, 0)
        local w, h = w1 + 4 + w2, math.max(h1, h2)
        f:SetSize(w, h)
        f:Show()
        return w, h
    end
end
