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
local canaccessvalue = canaccessvalue or function() return true end
local issecretvalue = issecretvalue or function() return false end

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
    "FriendsTooltip", "ReputationParagonTooltip",
}

-- visibility categories (items, spells, auras and plain UI tips always show)
local CAT_WORLD_UNIT   = "worldUnits"
local CAT_WORLD_OBJECT = "worldObjects"
local CAT_FRAME_UNIT   = "frameUnits"
local CAT_ACTION       = "actionBars"

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

local function GetUnitBorderColor(unit)
    local db = GetDb()
    if not db then return nil end
    if db.borderByClass then
        local class = GetClassColor(unit)
        if class then return class end
    end
    if db.borderByReaction then
        return GetReactionColor(unit)
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
    pcall(tip.NineSlice.SetCenterColor, tip.NineSlice, bg[1], bg[2], bg[3], bg[4])

    local c = borderColor or DEFAULT_BORDER_COLOR
    pcall(tip.NineSlice.SetBorderColor, tip.NineSlice, c[1], c[2], c[3], 1)

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

local function HideHealthBar()
    local db = GetDb()
    local bar = _G.GameTooltipStatusBar
    if not (db and bar) then return end
    -- hide only: writing to this bar taints
    if db.hideHealthBar then bar:Hide() end
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
-- players); Blizzard's bracketed tags give way to the one ClassTag
local function ColorLevelLine(tip, unit)
    local className = PlayerClassName(unit)
    local color = className and { 1, 1, 1 } or GetReactionColor(unit)
    if not color then return end
    local levelWord = _G.LEVEL
    if not levelWord then return end
    local level = Readable(UnitLevel(unit))
    local difficulty = level and ((not Readable(UnitIsFriend("player", unit)) and ns.LevelDifficultyColor(unit, level))
        or LevelColor(level))
    local tag = ClassTag(unit, level)
    for i = 2, tip:NumLines() do
        local line = LeftLine(i)
        local text = line and line:GetText()
        if canaccessvalue(text) and type(text) == "string" and text:find("^" .. levelWord) then
            local reaction = ColorToHex(color[1], color[2], color[3])
            local head, rest = text:match("^(" .. levelWord .. "%s+%S+)(.*)$")
            if not head then head, rest = nil, text end
            if tag or className then rest = rest:gsub("%s*%b()", "") end
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
            return
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

-- Faction line in Blizzard's faction colours
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
                    line:SetText(f.hex .. text .. "|r")
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
local function AddIdLine(tip, key, label, data)
    local db = GetDb()
    local id = data and data.id
    if not (db and db[key] and canaccessvalue(id) and type(id) == "number") then return end
    tip:AddDoubleLine(" ", label .. " " .. id, nil, nil, nil, 0.5, 0.5, 0.5)
    if tip:IsShown() then tip:Show() end   -- re-layout; never pop up a hidden (scanning) tooltip
end

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
    local inCombat = UnitAffectingCombat("player")
    if not canaccessvalue(inCombat) then inCombat = InCombatLockdown() end
    return inCombat and true or false
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
        if ownerUnit == nil and owner.GetAttribute then ownerUnit = owner:GetAttribute("unit") end
        if ownerUnit and canaccessvalue(ownerUnit) and type(ownerUnit) == "string" then return ownerUnit end
    end
    if MouseIsOverWorld() then return "mouseover" end
end

-- A player's tooltip carries secret text and fails SafeToTouch: only the restyling is gated
local function OnTooltipSetUnit(tip)
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
    HideHealthBar()
    if not SafeToTouch(tip) then return end
    ScrubLines(tip)
    ColorName(tip, unit)
    ColorLevelLine(tip, unit)
    RemoveClassLine(tip, unit)
    ColorFactionLine(tip)
    ApplyColors(tip, GetUnitBorderColor(unit))
end

local function OnTooltipSetItem(tip, data)
    if not SafeToTouch(tip) then return end
    if tip == GameTooltip and OwnerIsActionButton(tip) and HideIfNeeded(tip, CAT_ACTION) then return end

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
    AddIdLine(tip, "showItemID", L["Item ID"], data)
end

local function OnTooltipSetSpell(tip, data)
    if not SafeToTouch(tip) then return end
    if tip == GameTooltip and OwnerIsActionButton(tip) and HideIfNeeded(tip, CAT_ACTION) then return end
    ApplyColors(tip, nil)
    AddIdLine(tip, "showSpellID", L["Spell ID"], data)
end

local function OnTooltipSetAura(tip, data)
    if not SafeToTouch(tip) then return end
    ApplyColors(tip, nil)
    AddIdLine(tip, "showSpellID", L["Spell ID"], data)
end

-- Anything not a unit / item / spell / aura: world objects and plain UI frames
local function OnTooltipShow(tip)
    if tip ~= GameTooltip or not SafeToTouch(tip) then return end
    -- a secret name still means a unit, handled in its own post-call
    local unitName = tip:GetUnit()
    if issecretvalue(unitName) or unitName then return end
    if MouseIsOverWorld() and HideIfNeeded(tip, CAT_WORLD_OBJECT) then return end
    ApplyColors(tip, nil)
    HideHealthBar()
end

--------------------------------------------------
-- 10. ANCHORING
--------------------------------------------------
local function ApplyAnchor(tooltip, parent)
    local db = GetDb()
    if not (db and tooltip and parent) then return end
    if tooltip ~= GameTooltip then return end

    -- the Gamepad UI has no cursor to follow
    if ns.IsGamepadUI() then return end
    local overWorld = MouseIsOverWorld()
    local mode = overWorld and db.anchor or db.anchorFrames
    if mode == "default" then return end
    tooltip:SetOwner(parent, "ANCHOR_CURSOR_RIGHT", 0, 0)
end

--------------------------------------------------
-- 11. PUBLIC
--------------------------------------------------
-- Blizzard's tooltip font objects; small lines two points under the content size
local function ApplyFonts()
    local db = GetDb()
    if not db then return end
    local function Apply(fontObject, fontDb, sizeOffset)
        if not (fontObject and fontDb) then return end
        local flags = fontDb.flags or "NONE"
        if flags == "NONE" then flags = "" end
        fontObject:SetFont(ns.GetFontPath(fontDb.face or "Friz Quadrata TT"), (fontDb.size or 12) + (sizeOffset or 0), flags)
        ns.ApplyShadow(fontObject, fontDb)
    end
    Apply(_G.GameTooltipHeaderText, db.titleFont)
    Apply(_G.GameTooltipText, db.contentFont)
    Apply(_G.GameTooltipTextSmall, db.contentFont, -2)
end

function TIP:Refresh()
    if not self.initialized then return end
    ApplyFonts()
    ApplyScaleToAll()
    if GameTooltip and GameTooltip:IsShown() then
        ApplyColors(GameTooltip, nil)
        HideHealthBar()
    end
end

function TIP:Init()
    if self.initialized then return end
    local db = GetDb()
    if not db then return end
    self.initialized = true

    -- world object tooltips only fire mouse motion when the world frame tracks it
    WorldFrame:EnableMouseMotion(true)

    local add = TooltipDataProcessor.AddTooltipPostCall
    add(Enum.TooltipDataType.Unit, OnTooltipSetUnit)
    add(Enum.TooltipDataType.Item, OnTooltipSetItem)
    add(Enum.TooltipDataType.Spell, OnTooltipSetSpell)
    add(Enum.TooltipDataType.UnitAura, OnTooltipSetAura)

    -- "Show threat" off: a line pre-call returning true drops the threat line without a gap
    if Enum.TooltipDataLineType and Enum.TooltipDataLineType.UnitThreat and TooltipDataProcessor.AddLinePreCall then
        TooltipDataProcessor.AddLinePreCall(Enum.TooltipDataLineType.UnitThreat, function()
            local now = GetDb()
            if now and now.showThreat == false then return true end
        end)
    end

    GameTooltip:HookScript("OnShow", OnTooltipShow)

    -- Blizzard restyles tooltips often: the colours go back on after each restyle
    hooksecurefunc("SharedTooltip_SetBackdropStyle", function(tip)
        if tip == GameTooltip or tip == _G.ItemRefTooltip then ApplyColors(tip, nil) end
    end)
    hooksecurefunc("GameTooltip_SetDefaultAnchor", ApplyAnchor)

    ApplyFonts()
    ApplyScaleToAll()
end
