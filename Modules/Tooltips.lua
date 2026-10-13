local _, ns = ...
local L = ns.L

--------------------------------------------------
-- TOOLTIPS
-- Tooltip scale, colours, health bar, anchoring and per-category visibility. Secret-safe rules:
--   * only TooltipDataProcessor post-calls and post-hooks, never method replacement
--   * never touch a tooltip that is forbidden, has a secret width, or has a child with a secret
--     shownWidgetCount (a Blizzard bug: SetBackdrop / SetPadding then poisons the layout)
--   * every unit or tooltip value is checked with canaccessvalue before it is tested, compared or
--     concatenated
--   * the tooltip health bar is hidden, never written to (Blizzard flags it as a taint path)
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
-- muted palette, same family as the unit frame threat tint
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
local MUTE = 0.85                                   -- class / quality colours are toned down by this

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
-- 4. SAFETY (one gate in front of everything that touches a tooltip's appearance)
--------------------------------------------------
-- runs on every tooltip shown, so the children are walked without building a table
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

-- Border colour for a unit tooltip, by class or reaction as switched on
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
    -- hide only: writing to this bar is a documented taint path
    if db.hideHealthBar then bar:Hide() end
end

--------------------------------------------------
-- 7. UNIT TOOLTIP CONTENT
--------------------------------------------------
local CLASSIFICATION_FORMAT = {
    elite      = "+%s",
    rareelite  = "+%s |cffe066ff(" .. L["Rare"] .. ")|r",
    rare       = "%s |cffe066ff(" .. L["Rare"] .. ")|r",
    worldboss  = "%s |cffff4040(" .. L["Boss"] .. ")|r",
    minus      = "-%s",
}

-- Drops the PvP and "right click for frame settings" lines
local function ScrubLines(tip)
    local rightClick, pvp = _G.UNIT_POPUP_RIGHT_CLICK, _G.PVP_ENABLED
    for i = 2, tip:NumLines() do
        local line = _G["GameTooltipTextLeft" .. i]
        local text = line and line:GetText()
        if canaccessvalue(text) and type(text) == "string" then
            if rightClick and text == rightClick then
                line:SetText(nil)
                -- the instruction line is preceded by a blank spacer line (never the name line)
                local previous = i > 2 and _G["GameTooltipTextLeft" .. (i - 1)]
                if previous then previous:SetText(nil) end
            elseif pvp and text == pvp then
                line:SetText(nil)
            end
        end
    end
end

-- While switched on: the name in its class colour (reaction colour for NPCs), with the
-- classification on the same line
local function ColorName(tip, unit)
    local db = GetDb()
    if not db or db.nameColor ~= "class" then return end
    local line = _G.GameTooltipTextLeft1
    local text = line and line:GetText()
    if not (canaccessvalue(text) and type(text) == "string") then return end

    local color = GetClassColor(unit) or GetReactionColor(unit)
    if not color then return end

    local class = Readable(UnitClassification(unit))
    local format = class and CLASSIFICATION_FORMAT[class]
    if format then text = format:format(text) end
    line:SetText(ColorToHex(color[1], color[2], color[3]) .. text .. "|r")
end

-- The level line is the first line that starts with the level word
local function ColorLevelLine(tip, unit)
    local color = GetReactionColor(unit)
    if not color then return end
    local levelWord = _G.LEVEL
    if not levelWord then return end
    for i = 2, tip:NumLines() do
        local line = _G["GameTooltipTextLeft" .. i]
        local text = line and line:GetText()
        if canaccessvalue(text) and type(text) == "string" and text:find("^" .. levelWord) then
            line:SetText(ColorToHex(color[1], color[2], color[3]) .. text .. "|r")
            return
        end
    end
end

local function AddTargetLine(tip, unit)
    local db = GetDb()
    if not (db and db.showTarget) then return end
    local target = unit .. "target"
    -- a bare truth test or comparison on a secret value throws: everything is asked through Readable
    if not Readable(UnitExists(target)) then return end
    local prefix = (_G.TARGET or "Target") .. ": "
    if Readable(UnitIsUnit(target, "player")) then
        tip:AddLine(prefix .. "|cffff4040" .. (_G.YOU or "You") .. "|r")
        return
    end
    local color = GetClassColor(target) or GetReactionColor(target) or DEFAULT_BORDER_COLOR
    local name = UnitName(target)
    if not canaccessvalue(name) then
        -- another player's name can be secret: the tooltip still shows it, in the unit's colour
        local ok, text = pcall(function() return prefix .. name end)
        if ok then tip:AddLine(text, color[1], color[2], color[3]) end
        return
    end
    if not name or name == "" then return end
    tip:AddLine(prefix .. ColorToHex(color[1], color[2], color[3]) .. name .. "|r")
end

-- "Item ID 12345" / "Spell ID 678" in grey, from the tooltip's own data (a secret id is left out)
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
    if not owner then return false end
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

-- category -> "always" (show) / "combat" (hide while in combat) / "never" (always hide)
local function ShouldHide(category)
    local db = GetDb()
    -- world and UI are told apart by the mouse, which the Gamepad UI keeps on the world: all show there
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
-- The tooltip's unit as a token addon code may use. A secret unit is replaced by the owner frame's
-- unit, or "mouseover" over the world; failing that the tooltip is left as Blizzard drew it.
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

-- Runs inside Blizzard's tooltip processing, which shows (and lays out) the tooltip right after.
-- A player's tooltip carries secret text (SafeToTouch fails): it still gets the visibility rule, the
-- target line and the health bar; only the appearance changes need the gate.
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

-- anything that is not a unit / item / spell / aura: world objects and plain UI frames
local function OnTooltipShow(tip)
    if tip ~= GameTooltip or not SafeToTouch(tip) then return end
    -- units are handled in their own post-call (a secret name still means a unit)
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
-- Blizzard's tooltip font objects: title (first line), content, and small lines two points under it
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

    GameTooltip:HookScript("OnShow", OnTooltipShow)

    -- Blizzard restyles tooltips constantly; put our colours back afterwards
    hooksecurefunc("SharedTooltip_SetBackdropStyle", function(tip)
        if tip == GameTooltip or tip == _G.ItemRefTooltip then ApplyColors(tip, nil) end
    end)
    hooksecurefunc("GameTooltip_SetDefaultAnchor", ApplyAnchor)

    ApplyFonts()
    ApplyScaleToAll()
end
