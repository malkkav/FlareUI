local _, ns = ...

--------------------------------------------------
-- 1. MODULE REGISTRATION
-- Tooltip customisation in the FlareUI style: scale, background / border colouring, health bar,
-- anchoring and per-category visibility. Written for 12.x secrets, which comes down to these rules:
--   * only TooltipDataProcessor post-calls and post-hooks, never method replacement
--   * never touch a tooltip that is forbidden, has a secret width, or has a child with a secret
--     shownWidgetCount (a 12.0 Blizzard bug: SetBackdrop / SetPadding then poisons the layout)
--   * every unit value is checked with canaccessvalue before it is compared or concatenated
--   * the tooltip health bar is hidden, never written to (Blizzard flags it as a taint path)
--------------------------------------------------
ns.Tooltips = ns.Tooltips or {}
local TIP = ns.Tooltips
ns.modules["Tooltips"] = TIP

--------------------------------------------------
-- 2. UPVALUES
--------------------------------------------------
local _G = _G
local ipairs, pairs, type, select = ipairs, pairs, type, select
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
local MUTE = 0.85                                   -- class / quality colours are toned down by this

-- tooltips that follow the main one's scale and colours
local SATELLITES = {
    "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "EmbeddedItemTooltip",
    "FriendsTooltip", "ReputationParagonTooltip",
}

-- visibility categories
local CAT_WORLD_UNIT   = "worldUnits"
local CAT_WORLD_OBJECT = "worldObjects"
local CAT_FRAME_UNIT   = "frameUnits"
local CAT_FRAME_TIP    = "frameTips"
local CAT_ACTION       = "actionBars"
local CAT_ITEM         = "items"
local CAT_SPELL        = "spells"
local CAT_AURA         = "auras"

--------------------------------------------------
-- 4. SAFETY
-- One gate in front of everything that touches a tooltip's appearance.
--------------------------------------------------
local function HasTaintedWidgetContainer(tip)
    for _, child in pairs({ tip:GetChildren() }) do
        if issecretvalue(child.shownWidgetCount) then return true end
    end
    return false
end

local function SafeToTouch(tip)
    if type(tip) ~= "table" or not tip.GetObjectType then return false end
    if tip:IsForbidden() then return false end
    if issecretvalue(tip:GetWidth()) then return false end
    if HasTaintedWidgetContainer(tip) then return false end
    return true
end

-- readable value or nil, so a secret never reaches a comparison
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

-- border colour for a unit tooltip, honouring the class / reaction toggles
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
    local db = GetDb()
    if not db or not SafeToTouch(tip) or not tip.NineSlice then return end
    if applyingBackdrop then return end
    applyingBackdrop = true

    local bg = db.background or { r = 0.05, g = 0.05, b = 0.06, a = 0.9 }
    pcall(tip.NineSlice.SetCenterColor, tip.NineSlice, bg.r, bg.g, bg.b, bg.a)

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
    -- hide only: writing to this bar is a documented taint path in 12.x
    if db.hideHealthBar then bar:Hide() end
end

--------------------------------------------------
-- 7. UNIT TOOLTIP CONTENT
--------------------------------------------------
local CLASSIFICATION_FORMAT = {
    elite      = "+%s",
    rareelite  = "+%s |cffe066ff(Rare)|r",
    rare       = "%s |cffe066ff(Rare)|r",
    worldboss  = "%s |cffff4040(Boss)|r",
    minus      = "-%s",
}

-- line scrubbing: drop the PvP and "right click for frame settings" lines
local function ScrubLines(tip)
    local db = GetDb()
    if not db then return end
    local rightClick = _G.UNIT_POPUP_RIGHT_CLICK
    for i = 2, tip:NumLines() do
        local line = _G["GameTooltipTextLeft" .. i]
        local text = line and line:GetText()
        if text and canaccessvalue(text) and type(text) == "string" then
            local drop = false
            if db.hideRightClick and rightClick and text == rightClick then
                drop = true
                -- the instruction line is preceded by a blank spacer line
                local previous = _G["GameTooltipTextLeft" .. (i - 1)]
                if previous and i > 1 then previous:SetText(nil) end
            elseif db.hidePvpLine and _G.PVP_ENABLED and text == _G.PVP_ENABLED then
                drop = true
            end
            if drop then line:SetText(nil) end
        end
    end
end

local function ColorName(tip, unit)
    local db = GetDb()
    if not db or db.nameColor == "none" then return end
    local line = _G.GameTooltipTextLeft1
    local text = line and line:GetText()
    if not (text and canaccessvalue(text) and type(text) == "string") then return end

    local color
    if db.nameColor == "class" then
        color = GetClassColor(unit) or GetReactionColor(unit)
    else
        color = GetReactionColor(unit)
    end
    if not color then return end

    -- classification prefix goes on the same line as the name
    if db.classification then
        local class = Readable(UnitClassification(unit))
        local format = class and CLASSIFICATION_FORMAT[class]
        if format then text = format:format(text) end
    end
    line:SetText(ColorToHex(color[1], color[2], color[3]) .. text .. "|r")
end

-- the level line is the first line that starts with the level word
local function ColorLevelLine(tip, unit)
    local db = GetDb()
    if not (db and db.colorLevelLine) then return end
    local color = GetReactionColor(unit)
    if not color then return end
    local levelWord = _G.LEVEL
    if not levelWord then return end
    for i = 2, tip:NumLines() do
        local line = _G["GameTooltipTextLeft" .. i]
        local text = line and line:GetText()
        if text and canaccessvalue(text) and type(text) == "string" and text:find("^" .. levelWord) then
            line:SetText(ColorToHex(color[1], color[2], color[3]) .. text .. "|r")
            return
        end
    end
end

local function AddTargetLine(tip, unit)
    local db = GetDb()
    if not (db and db.showTarget) then return end
    local target = unit .. "target"
    if not UnitExists(target) then return end
    local name = UnitName(target)
    if not (name and canaccessvalue(name) and name ~= "") then return end

    local label
    if Readable(UnitIsUnit(target, "player")) then
        label = "|cffff4040" .. (_G.YOU or "You") .. "|r"
    else
        local color = GetClassColor(target) or GetReactionColor(target) or DEFAULT_BORDER_COLOR
        label = ColorToHex(color[1], color[2], color[3]) .. name .. "|r"
    end
    tip:AddLine((_G.TARGET or "Target") .. ": " .. label)
end

-- "Item ID 12345" / "Spell ID 678" in grey at the bottom right of item, spell and aura tooltips. The id
-- comes from the tooltip's own data; a secret one is left out.
local function AddIdLine(tip, key, label, data)
    local db = GetDb()
    local id = data and data.id
    if not (db and db[key] and id and canaccessvalue(id) and type(id) == "number") then return end
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
    if not db then return false end
    local mode = db.visibility and db.visibility[category] or "always"
    if mode == "always" then return false end
    if db.shiftReveal and IsShiftKeyDown() then return false end
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
-- The unit a tooltip shows, as a token FlareUI may pass on. Under addon restrictions (instances,
-- encounters, PvP, combat) the tooltip hands its unit back as a secret, and a secret may not be passed
-- to UnitExists and the rest from addon code. A plain token is then taken from where the tooltip came
-- from: the unit frame that owns it (its unit field or attribute), or "mouseover" over the world.
-- Anything still unreadable leaves the tooltip as Blizzard drew it (visibility rules still apply).
local function TooltipUnit(tip)
    local _, unit = TooltipUtil.GetDisplayedUnit(tip)
    if not unit then unit = select(2, tip:GetUnit()) end
    if unit and canaccessvalue(unit) then return unit end
    local owner = tip:GetOwner()
    if owner and not owner:IsForbidden() then
        local ownerUnit = owner.unit
        if ownerUnit == nil and owner.GetAttribute then ownerUnit = owner:GetAttribute("unit") end
        if ownerUnit and canaccessvalue(ownerUnit) and type(ownerUnit) == "string" then return ownerUnit end
    end
    if MouseIsOverWorld() then return "mouseover" end
end

local function OnTooltipSetUnit(tip)
    if tip ~= GameTooltip or not SafeToTouch(tip) then return end
    local unit = TooltipUnit(tip)
    if not unit then
        HideIfNeeded(tip, MouseIsOverWorld() and CAT_WORLD_UNIT or CAT_FRAME_UNIT)
        return
    end
    if not UnitExists(unit) then return end

    local category = MouseIsOverWorld() and CAT_WORLD_UNIT or CAT_FRAME_UNIT
    if HideIfNeeded(tip, category) then return end

    ScrubLines(tip)
    ColorName(tip, unit)
    ColorLevelLine(tip, unit)
    AddTargetLine(tip, unit)
    ApplyColors(tip, GetUnitBorderColor(unit))
    HideHealthBar()
    tip:Show()   -- re-layout after the added line
end

local function OnTooltipSetItem(tip, data)
    if not SafeToTouch(tip) then return end
    if tip == GameTooltip and HideIfNeeded(tip, OwnerIsActionButton(tip) and CAT_ACTION or CAT_ITEM) then return end

    local db = GetDb()
    local color
    if db and db.borderByQuality then
        local _, link = TooltipUtil.GetDisplayedItem(tip)
        if link and canaccessvalue(link) then
            local quality = select(3, C_Item.GetItemInfo(link))
            if quality and canaccessvalue(quality) then
                local r, g, b = C_Item.GetItemQualityColor(quality)
                if r then color = { Mute(r, g, b) } end
            end
        end
    end
    ApplyColors(tip, color)
    AddIdLine(tip, "showItemID", "Item ID", data)
end

local function OnTooltipSetSpell(tip, data)
    if not SafeToTouch(tip) then return end
    if tip == GameTooltip and HideIfNeeded(tip, OwnerIsActionButton(tip) and CAT_ACTION or CAT_SPELL) then return end
    ApplyColors(tip, nil)
    AddIdLine(tip, "showSpellID", "Spell ID", data)
end

local function OnTooltipSetAura(tip, data)
    if not SafeToTouch(tip) then return end
    if tip == GameTooltip and HideIfNeeded(tip, CAT_AURA) then return end
    ApplyColors(tip, nil)
    AddIdLine(tip, "showSpellID", "Spell ID", data)
end

-- anything that is not a unit / item / spell / aura: world objects and plain UI frames
local function OnTooltipShow(tip)
    if tip ~= GameTooltip or not SafeToTouch(tip) then return end
    if tip:GetUnit() then return end            -- units are handled in their own post-call
    local category = MouseIsOverWorld() and CAT_WORLD_OBJECT or CAT_FRAME_TIP
    if HideIfNeeded(tip, category) then return end
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

    -- tooltips owned by a UI frame can keep Blizzard's placement
    local overWorld = MouseIsOverWorld()
    local mode = overWorld and db.anchor or db.anchorFrames
    if mode == "default" then return end
    tooltip:SetOwner(parent, "ANCHOR_CURSOR_RIGHT", db.anchorX or 0, db.anchorY or 0)
end

--------------------------------------------------
-- 11. PUBLIC
--------------------------------------------------
function TIP:Refresh()
    if not self.initialized then return end
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
    -- the plain "cursor" mode was folded into the offset one, which the options now call "Cursor"
    if db.anchor == "cursor" then db.anchor = "cursorOffset" end
    if db.anchorFrames == "cursor" then db.anchorFrames = "cursorOffset" end

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

    ApplyScaleToAll()
end
