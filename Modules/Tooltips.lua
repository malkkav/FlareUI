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

-- Show guild name off: no guild line. Show guild ranks: the rank after the name. The line has no type of
-- its own, so it is found by the guild's name, in whatever form the client writes it.
local function ApplyGuildLine(tip, unit)
    local db = GetDb()
    if not db or (db.showGuild ~= false and not db.showGuildRank) then return end
    if not Readable(UnitIsPlayer(unit)) then return end
    local guild, rank = GetGuildInfo(unit)
    if not (canaccessvalue(guild) and type(guild) == "string" and guild ~= "") then return end
    for i = 2, tip:NumLines() do
        local line = LeftLine(i)
        local text = line and line:GetText()
        if canaccessvalue(text) and type(text) == "string" and text:find(guild, 1, true) then
            if db.showGuild == false then
                line:SetText(nil)
            elseif canaccessvalue(rank) and type(rank) == "string" and rank ~= "" then
                line:SetText(text .. " (" .. rank .. ")")
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
    ApplyGuildLine(tip, unit)
    ColorLevelLine(tip, unit)
    RemoveClassLine(tip, unit)
    ColorFactionLine(tip)
    ApplyColors(tip, GetUnitBorderColor(unit))
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
    AddIdLine(tip, "showItemID", L["Item ID"], data)
end

local function OnTooltipSetSpell(tip, data)
    if not SafeToTouch(tip) then return end
    ApplyColors(tip, nil)
    AddIdLine(tip, "showSpellID", L["Spell ID"], data)
end

local function OnTooltipSetAura(tip, data)
    if tip == GameTooltip and not tip:IsForbidden() and HideIfNeeded(tip, CAT_AURA) then return end
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
    -- Everything Else: a tooltip in Blizzard's spot for anything but the world, units and action bars
    if tip.fuiOther and HideIfNeeded(tip, CAT_OTHER) then return end
    -- Blizzard shows a tooltip after its post-calls: an item keeps the quality border just set
    if not tip:IsTooltipType(Enum.TooltipDataType.Item) then ApplyColors(tip, nil) end
    HideHealthBar()
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
-- an exception (tooltips.mouseoverKinds[kind], the Visibility tab) while it differs. Kinds: world,
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

local function OnAuraTipOwner(tip, owner)
    local kind = owner and ns.auraTipKind[owner]
    if not kind or ns.IsGamepadUI() then return end
    if TIP.Mouseover(kind == "group" and "groupAuras" or "auras") then pcall(tip.SetAnchorType, tip, "ANCHOR_CURSOR_RIGHT") end
end
local function HookAuraTooltips()
    for _, tip in ipairs({ GameTooltip, _G.AuraButtonTooltip }) do
        if tip and not tip.fuiAuraHooked and not (tip.IsForbidden and tip:IsForbidden()) then
            tip.fuiAuraHooked = true
            hooksecurefunc(tip, "SetOwner", OnAuraTipOwner)
        end
    end
end

local function ApplyAnchor(tooltip, parent)
    local db = GetDb()
    if not (db and tooltip and parent) then return end
    if tooltip ~= GameTooltip then return end
    local kind = AnchorKind(tooltip, parent)
    -- Everything Else's Show is checked as it shows (OnTooltipShow)
    tooltip.fuiOther = kind == "other" or nil

    -- the Gamepad UI has no cursor to follow
    if ns.IsGamepadUI() then return end
    if not TIP.Mouseover(kind) then return end
    tooltip:SetOwner(parent, "ANCHOR_CURSOR_RIGHT", 0, 0)
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
    add(TooltipDataProcessor.AllTypes, OnTooltipSetAny)

    -- "Show threat" off: a line pre-call returning true drops the threat line without a gap
    if Enum.TooltipDataLineType and Enum.TooltipDataLineType.UnitThreat and TooltipDataProcessor.AddLinePreCall then
        TooltipDataProcessor.AddLinePreCall(Enum.TooltipDataLineType.UnitThreat, function()
            local now = GetDb()
            if now and now.showThreat == false then return true end
        end)
    end

    GameTooltip:HookScript("OnShow", OnTooltipShow)
    GameTooltip:HookScript("OnHide", function(tip) tip.fuiOther = nil end)

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

    ApplyCompare()
    ApplyFonts()
    ApplyScaleToAll()
end

--------------------------------------------------
-- 12. SETTINGS PREVIEW SAMPLE
-- A made-up tooltip in the module's own look (border, background, colours, fonts). It is a plain
-- frame with the tooltip's NineSlice: a GameTooltip needs an owner to lay out its lines.
--------------------------------------------------
do
    local PAD, GAP, SPACING, WRAP = 10, 15, 2, 230
    local SAMPLE_CLASS = "MAGE"

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
        bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
        bar:SetStatusBarColor(0, 1, 0)
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(1)
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

    -- lines: { text, r, g, b, title = true, wrap = true, right = text, rr, rg, rb }
    local function Fill(tip, lines, showBar)
        local db = GetDb() or {}
        local width, height = 0, PAD
        for i, line in ipairs(lines) do
            local left = LineString(tip, "left", i)
            left:SetFontObject(line.title and "GameTooltipHeaderText" or "GameTooltipText")
            TIP.ApplyFontTo(left, line.title and db.titleFont or db.contentFont)
            left:SetWidth(line.wrap and WRAP or 0)
            left:SetWordWrap(line.wrap and true or false)
            left:SetJustifyH("LEFT")
            left:SetText(line[1])
            left:SetTextColor(line[2] or 1, line[3] or 1, line[4] or 1)
            left:ClearAllPoints()
            left:SetPoint("TOPLEFT", tip, "TOPLEFT", PAD, -height)
            left:Show()
            local w = left:GetStringWidth()
            if line.wrap and w > WRAP then w = WRAP end
            local h = left:GetStringHeight()
            local right = LineString(tip, "right", i)
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
        for i = #lines + 1, #tip.left do tip.left[i]:Hide() end
        for i = #lines + 1, #tip.right do tip.right[i]:Hide() end
        width = math.ceil(width + PAD * 2)
        height = math.ceil(height - SPACING + PAD)
        tip:SetSize(width, height)
        tip.bar:SetShown(showBar and true or false)
        tip:Show()
        return width, height + (showBar and 9 or 0)
    end

    local function ClassColorOf(classFile)
        local c = C_ClassColor and C_ClassColor.GetClassColor(classFile)
        return c and { c.r, c.g, c.b } or { 1, 1, 1 }
    end

    local function RaceName(raceID, fallback)
        local info = C_CreatureInfo and C_CreatureInfo.GetRaceInfo and C_CreatureInfo.GetRaceInfo(raceID)
        return info and info.raceName or fallback
    end

    -- a friendly player, as the unit post-call leaves the tooltip
    local function UnitLines(db)
        local class = ClassColorOf(SAMPLE_CLASS)
        local className = (_G.LOCALIZED_CLASS_NAMES_MALE and _G.LOCALIZED_CLASS_NAMES_MALE[SAMPLE_CLASS]) or "Mage"
        local horde = Readable(UnitFactionGroup("player")) == "Horde"
        local name = "Elaria"
        if db.nameColor == "class" then name = ColorToHex(class[1], class[2], class[3]) .. name .. "|r" end
        local lines = { { name, title = true } }
        if db.showGuild ~= false then
            local guild = "<Dawnwatch>"
            if db.showGuildRank then guild = guild .. " (" .. (_G.GUILD_RANK1_DESC or "Officer") .. ")" end
            lines[#lines + 1] = { guild }
        end
        -- "Level N" in the difficulty colour, the rest white with the class name (ColorLevelLine)
        local level = 60
        local head = (_G.LEVEL or "Level") .. " " .. level
        local difficulty = LevelColor(level)
        local text = difficulty and (ColorToHex(difficulty.r, difficulty.g, difficulty.b) .. head .. "|r") or head
        local race = horde and RaceName(5, "Undead") or RaceName(1, "Human")
        lines[#lines + 1] = { text .. "|cffffffff " .. race .. " " .. className .. "|r" }
        if not db.hideFaction then
            local f = FACTION_LINE_COLORS[horde and 1 or 2]
            lines[#lines + 1] = { f.hex .. (_G[f.word] or (horde and "Horde" or "Alliance")) .. "|r" }
        end
        if db.showTarget then
            lines[#lines + 1] = { (_G.TARGET or "Target") .. ": |cffff4040" .. (_G.YOU or "You") .. "|r" }
        end
        return lines, class
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
        lines[#lines + 1] = { Format(_G.ARMOR_TEMPLATE, armor .. " Armor", armor) }
        lines[#lines + 1] = { "+" .. (equipped and 20 or 16) .. " " .. (_G.SPELL_STAT3_NAME or "Stamina") }
        lines[#lines + 1] = { "+" .. (equipped and 10 or 16) .. " " .. (_G.SPELL_STAT4_NAME or "Intellect") }
        lines[#lines + 1] = { Format(_G.DURABILITY_TEMPLATE, "Durability 70 / 70", 70, 70) }
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
        if db.showItemID then
            lines[#lines + 1] = { " ", right = L["Item ID"] .. " " .. id, rr = 0.5, rg = 0.5, rb = 0.5 }
        end
        local border
        if db.borderByQuality then border = { Mute(r, g, b) } end
        return lines, border
    end

    local function DrawTip(tip, kind, equipped)
        local db = GetDb() or {}
        local w, h
        if kind == "unit" then
            local lines, class = UnitLines(db)
            w, h = Fill(tip, lines, not db.hideHealthBar)
            ApplyColors(tip, GetUnitBorderColor(nil, class, REACTION_COLORS[5]))
        else
            local lines, border = ItemLines(db, equipped)
            w, h = Fill(tip, lines, false)
            ApplyColors(tip, border)
        end
        return w, h
    end

    -- kind: "unit" (default), "item" or "compare" (the item beside the one it is compared with)
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
