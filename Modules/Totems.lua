local _, ns = ...
local L = ns.L

--------------------------------------------------
-- TOTEMS
-- Blizzard's TotemFrame lives in the parked PlayerFrame, so it moves onto FlareUI Totems, an Edit Mode
-- frame with a size and totems per row. Blizzard's code still runs it.
--------------------------------------------------

--------------------------------------------------
-- 1. MODULE REGISTRATION
--------------------------------------------------
ns.Totems = ns.Totems or {}
local TOT = ns.Totems
ns.modules["Totems"] = TOT

--------------------------------------------------
-- 2. UPVALUES / CONSTANTS
--------------------------------------------------
local LEM = LibStub("FlareEditMode")
local ipairs = ipairs
local math_floor, math_ceil, math_max, math_min = math.floor, math.ceil, math.max, math.min
local table_sort = table.sort

-- under the player frame, beside the pet frame
local DEFAULT_POSITION = { point = "BOTTOM", x = -361, y = 270 }
local DEFAULT_SIZE, DEFAULT_PER_ROW = 90, 4
-- Blizzard's totem button geometry (TotemButtonTemplate)
local BUTTON, ICON, RING = 37, 22, 30
local COL_STEP, ROW_STEP, TEXT_BELOW = 31, 42, 7
local MAX = _G.MAX_TOTEMS or 4
local PREVIEW_ICONS = { "Spell_Nature_StoneSkinTotem", "Spell_Fire_SearingTotem",
                        "Spell_Nature_ManaRegenTotem", "Spell_Nature_GroundingTotem" }
local PREVIEW_TIMES = { "1:45", "52", "4:10", "12" }

local holder
local coverHost   -- the In Range marks' frame (section 4b)

local function GetDb()
    return ns.db and ns.db.profile and ns.db.profile.unitframes
end

local function GetSettings()
    local db = GetDb()
    if not db then return DEFAULT_SIZE / 100, DEFAULT_PER_ROW end
    db.totems = db.totems or {}
    local size = db.totems.size or DEFAULT_SIZE
    local perRow = math_max(1, math_min(MAX, db.totems.perRow or DEFAULT_PER_ROW))
    return size / 100, perRow
end

--------------------------------------------------
-- 3. POSITION (per Edit Mode layout)
--------------------------------------------------
local function GetLayoutStore(layoutName)
    local db = GetDb()
    if not db then return nil end
    layoutName = layoutName or LEM:GetActiveLayoutName() or "Modern"
    db.totemLayouts = db.totemLayouts or {}
    -- (a layout with no spot of its own reads the profile's home layout's: ProfileLayout.lua)
    return ns.LayoutHome(db.totemLayouts, layoutName)
end

local function ApplyPosition(layoutName)
    if not holder then return end
    local store = GetLayoutStore(layoutName)
    local pos = (store and store.point) and store or DEFAULT_POSITION
    holder:ClearAllPoints()
    holder:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
end

local function OnFrameMoved(_, layoutName, point, x, y)
    local store = GetLayoutStore(layoutName)
    if not store then return end
    store.point, store.x, store.y = point, math_floor(x + 0.5), math_floor(y + 0.5)
end

--------------------------------------------------
-- 4. GRID (slot n, perRow to a row, rows going down; offsets in the scaled frame's units)
--------------------------------------------------
-- Rows keep room for the time only while it shows under the icons; otherwise they close up to the
-- columns' spacing
local function TimerBelow()
    local db = GetDb()
    local totems = db and db.totems
    return (totems and totems.timer or "none") == "below"
end

local function RowStep()
    return TimerBelow() and ROW_STEP or COL_STEP
end

local function SlotOffset(n, perRow)
    local col = (n - 1) % perRow
    local row = math_floor((n - 1) / perRow)
    return col * COL_STEP, -row * RowStep()
end

local function PlaceInGrid(buttons, parent, perRow)
    for n, button in ipairs(buttons) do
        local x, y = SlotOffset(n, perRow)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    end
end

local function ByLayoutIndex(a, b) return (a.layoutIndex or 0) < (b.layoutIndex or 0) end

-- Aura Swipe and Aura Timer, as on the Buffs & Debuffs icons (round): the swipe over the icon,
-- round the ring, both (one disc over icon and ring) or none; the time under the icon, along its
-- bottom, in its middle or not at all. On Blizzard's own buttons, and on the Edit Mode samples.
local MEDIA = "Interface\\AddOns\\FlareUI\\Media\\Auras\\"
local SWIPE_ROUND = MEDIA .. "BorderRoundThick"
local SWIPE_EDGE = MEDIA .. "Edge"
local SWIPE_DISC = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local function TotemLook()
    local db = GetDb()
    local t = db and db.totems or {}
    return t.swipe or "both", t.timer or "none"
end

-- button: the totem button; cd: its cooldown; text: its time; ring: its border art
local function StyleTotem(button, cd, text, ring)
    local swipe, timer = TotemLook()
    if cd then
        cd:ClearAllPoints()
        -- Blizzard draws the ring art 1 px right and 1.5 px down of the icon: only the ring swipe follows
        -- it. A disc stays on the icon at the icon's size, or it reads as a shadow growing bottom right.
        local onRing = swipe == "border"
        cd:SetPoint("CENTER", onRing and ring or button, "CENTER")
        cd:SetSize(onRing and RING or ICON, onRing and RING or ICON)
        cd:SetFrameLevel(button:GetFrameLevel() + ((onRing or swipe == "both") and 3 or 1))
        cd:SetUseCircularEdge(true)
        if swipe == "none" then
            cd:SetDrawSwipe(false)
            cd:SetDrawEdge(false)
        elseif swipe == "border" then
            cd:SetDrawSwipe(true)
            cd:SetDrawEdge(false)
            cd:SetSwipeTexture(SWIPE_ROUND)
            cd:SetSwipeColor(0, 0, 0, 0.7)
        else
            cd:SetDrawSwipe(true)
            cd:SetSwipeTexture(SWIPE_DISC)
            cd:SetSwipeColor(0, 0, 0, swipe == "both" and 0.7 or 0.82)
            cd:SetDrawEdge(true)
            cd:SetEdgeTexture(SWIPE_EDGE, 1, 1, 1, 1)
            if cd.SetEdgeScale then cd:SetEdgeScale(1.6) end
        end
    end
    if text then
        -- the time on a layer of its own, above the swipe (Blizzard keeps writing it)
        local layer = button.FlareUI_TextLayer
        if not layer then
            layer = CreateFrame("Frame", nil, button)
            layer:SetAllPoints(button)
            button.FlareUI_TextLayer = layer
        end
        layer:SetFrameLevel(button:GetFrameLevel() + 5)
        if text:GetParent() ~= layer then text:SetParent(layer) end
        text:SetDrawLayer("OVERLAY")
        text:ClearAllPoints()
        if timer == "middle" then
            text:SetPoint("CENTER", button, "CENTER", 0, 0)
        elseif timer == "bottom" then
            text:SetPoint("BOTTOM", ring or button, "BOTTOM", 0, 2)
        else
            text:SetPoint("TOP", button, "BOTTOM", 0, 5)
        end
        text:SetAlpha(timer == "none" and 0 or 1)
        -- the Unit Frames' Aura Timers font (11-13): its face, outline and shadow; Auto keeps Blizzard's size
        -- (the player frame's: totems are the player's)
        local font = ns.UnitFrames and ns.UnitFrames.Font and ns.UnitFrames.Font("player", "auras")
        if font then
            local flags = font.flags or ""
            if flags == "NONE" then flags = "" end
            local size = (font.size and font.size > 0) and font.size or 10
            ns.SetFont(text, ns.GetFontPath(font.face or ns.GLOBAL_FONT), size, flags)
            ns.ApplyShadow(text, font)
        end
    end
end

-- the live totems take clicks unless the samples cover them or Visibility has faded them right out
-- (Never, or a fade at 0%): an unseen totem can't be right-clicked away (plain buttons, safe in a fight)
local previewing, faded = false, false
local function ApplyMouse()
    local frame = _G.TotemFrame
    if not frame then return end
    local on = not previewing and not faded
    for _, button in ipairs({ frame:GetChildren() }) do
        if button.EnableMouse then pcall(button.EnableMouse, button, on) end
    end
end

-- After Blizzard's Layout the shown buttons go back into the grid
local UpdateRange   -- section 4b
local active = {}
local function ArrangeTotems()
    local frame = _G.TotemFrame
    if not (frame and frame.totemPool and holder) then return end
    local _, perRow = GetSettings()
    for i = #active, 1, -1 do active[i] = nil end
    for button in frame.totemPool:EnumerateActive() do
        if button:IsShown() then active[#active + 1] = button end
    end
    table_sort(active, ByLayoutIndex)
    PlaceInGrid(active, frame, perRow)
    for _, button in ipairs(active) do
        StyleTotem(button, button.Icon and button.Icon.Cooldown, button.Duration, button.Border)
    end
    if previewing or faded then ApplyMouse() end
    UpdateRange()
end

--------------------------------------------------
-- 4b. IN RANGE (11-15, a shaman asked)
-- A mark on a totem while its buff is on you: marching ants, yellow dashes moving round its edge. Walk out of the
-- totem's range and the mark goes. On the totems standing (FlareUI Totems), and with Also on Action
-- Bars on the totem's spell wherever it is slotted: Blizzard's totem bar and the action bars.
-- Your buffs are secret in a fight, so the game draws the mark, as on the Seal bar (ResourceBars.lua
-- 10c): an AuraContainer with one group filtered by the totem's buff IDs, whose button carries the
-- mark. Only a buff that is up can be shown this way (nothing can be shown for a missing one, and
-- whether an aura's frame shows is itself secret), which is why the mark says "in range".
-- A totem's buff IDs are learned out of a fight, by icon (any language), and kept account-wide:
-- db.global.totemBuffs[icon] = { [buff ID] = true }. Totems with no buff of their own (Searing, Tremor,
-- Windfury's weapon enchant) are never learned and never marked.
-- The art under a container's button has "secret aspects": no OnShow script may be set on it, and in a
-- fight it is a forbidden object (any call from an addon is an error). So it is set up once, as the
-- game makes it, and touched again only out of a fight, behind IsForbidden. Containers are made out of
-- a fight.
--------------------------------------------------
local MARK_YELLOW = { 1, 0.85, 0.1 }
-- Marching Ants (tools/auraart.js): dashes round a circle, turned; and 4 x 4 frames of dashes round a
-- square, each a step on, played as a flipbook
local ANTS_RING, ANTS_SQUARE = MEDIA .. "AntsRing", MEDIA .. "AntsSquare"
local ANTS_GRID = 4
local ANTS_TURN = 8      -- seconds a turn of the ring
local ANTS_STEP = 0.5    -- seconds the square's dashes take to move on by one dash and gap
local MARK_GROUP = "buff"
local LEVEL_MARK = 4   -- over a totem button: above the swipe (3), under the time (5)
local BAR_PREFIXES = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
    "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button", "MultiCastActionButton",
}

local function Readable(v) return canaccessvalue == nil or canaccessvalue(v) end

local function MarkOn()
    local db = GetDb()
    local t = db and db.totems
    return t and t.inRange == true or false
end

local function BarsOn()
    local db = GetDb()
    local t = db and db.totems
    return not (t and t.inRangeBars == false)
end

-- icon -> the IDs of the buffs seen with that totem down
local function Learned()
    local global = ns.db and ns.db.global
    if not global then return nil end
    global.totemBuffs = global.totemBuffs or {}
    return global.totemBuffs
end

-- Out of a fight: the buffs on you that share a standing totem's icon are that totem's
local function Learn()
    if InCombatLockdown() or ns.AurasLocked() then return end
    local learned = Learned()
    if not learned then return end
    local icons
    for slot = 1, MAX do
        local ok, have, _, _, _, icon = pcall(GetTotemInfo, slot)
        if ok and Readable(have) and have and Readable(icon) and icon then
            icons = icons or {}
            icons[icon] = true
        end
    end
    if not icons then return end
    local changed = false
    for i = 1, 40 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not ok or not Readable(aura) or not aura then break end
        local icon, id = aura.icon, aura.spellId
        if Readable(icon) and Readable(id) and icon and type(id) == "number" and icons[icon] then
            learned[icon] = type(learned[icon]) == "table" and learned[icon] or {}
            if not learned[icon][id] then
                learned[icon][id] = true
                changed = true
            end
        end
    end
    return changed
end

local function IDKey(ids)
    local list = {}
    for id in pairs(ids) do list[#list + 1] = id end
    table_sort(list)
    return table.concat(list, ",")
end

-- The mark's art on a frame, in the frame's shape (round on a totem, square on an action button):
-- marching ants, shown by StyleMark. The ants march by the texture's own
-- animation, so nothing runs in Lua: the round ones turn, the square ones play a flipbook of dashes a
-- step further round the square each frame (a client without flipbooks shows them standing).
local function MakeMark(art, round)
    art.Ants = art:CreateTexture(nil, "OVERLAY")
    art.Ants:SetTexture(round and ANTS_RING or ANTS_SQUARE)
    art.Ants:SetVertexColor(MARK_YELLOW[1], MARK_YELLOW[2], MARK_YELLOW[3], 1)
    art.Ants:SetAllPoints(art)
    art.March = art.Ants:CreateAnimationGroup()
    art.March:SetLooping("REPEAT")
    if round then
        local turn = art.March:CreateAnimation("Rotation")
        turn:SetDegrees(-360)   -- clockwise
        turn:SetDuration(ANTS_TURN)
    else
        art.Ants:SetTexCoord(0, 1 / ANTS_GRID, 0, 1 / ANTS_GRID)   -- the first frame
        local ok, flip = pcall(art.March.CreateAnimation, art.March, "FlipBook")
        if ok and flip then
            flip:SetDuration(ANTS_STEP)
            pcall(flip.SetFlipBookRows, flip, ANTS_GRID)
            pcall(flip.SetFlipBookColumns, flip, ANTS_GRID)
            pcall(flip.SetFlipBookFrames, flip, ANTS_GRID * ANTS_GRID)
        end
    end
    return art
end

-- The ants on or off; art in a fight is left as it is (the option is a setting: changed out of one)
local function StyleMark(art, on)
    if art.IsForbidden and art:IsForbidden() then return end
    art.Ants:SetShown(on)
    if on then art.March:Play() else art.March:Stop() end
end

local markFailed = false
local function MarkContainer(parent, ids, init)
    if markFailed or InCombatLockdown() then return nil end
    if C_AddOns.DoesAddOnExist("Blizzard_AuraContainer") and not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
    end
    local ok, container = pcall(CreateFrame, "AuraContainer", nil, parent, "CustomAuraContainerTemplate")
    if not (ok and type(container) == "table" and container.AddAuraGroup) then
        markFailed = true
        return nil
    end
    container:SetUnit("player")
    container:SetSize(1, 1)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    local E = Enum or {}
    local added = pcall(container.AddAuraGroup, container, MARK_GROUP, "HELPFUL", {
        maxFrameCount = 1,
        candidateFilters = { includeSpellIDs = ids },
        sortMethod = E.AuraContainerSortMethod and E.AuraContainerSortMethod.Default,
        sortDirection = E.AuraContainerSortDirection and E.AuraContainerSortDirection.Normal,
        initializeFrame = init,
        layout = { elementWidth = 1, elementHeight = 1, elementSpacing = 0, lineSpacing = 0 },
    })
    if not added then
        markFailed = true
        return nil
    end
    container:Show()
    pcall(container.SetEnabled, container, true)
    return container
end

-- THE TOTEMS STANDING. Blizzard's totem buttons are pooled and change slot, and the art can't be
-- moved in a fight, so each learned totem's mark is anchored to a frame of FlareUI's own, its spot,
-- on a frame of the holder's (faded with it; out of sight with the Edit Mode samples). The spot is
-- what moves: onto the icon of the totem standing, or off the screen.
-- mark: { container, sig, spot, arts, parked, used }
local marks = {}       -- marks[icon]
local markLevel = 0    -- a totem button's frame level, for art made later

local function ParkMark(mark)
    if mark.parked then return end
    mark.parked = true
    mark.spot:ClearAllPoints()
    mark.spot:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -50, 50)
    mark.spot:SetSize(1, 1)
end

local function SeatMark(mark, button)
    mark.parked = false
    mark.spot:ClearAllPoints()
    mark.spot:SetAllPoints(button.Icon)
end

local function BuildMarks(learned)
    if markFailed or InCombatLockdown() or not holder then return end
    coverHost = coverHost or CreateFrame("Frame", nil, holder)
    coverHost:SetAllPoints(holder)
    for icon, ids in pairs(learned) do
        local key = type(ids) == "table" and next(ids) and IDKey(ids)
        local mark = marks[icon]
        if key and not mark then
            mark = { arts = setmetatable({}, { __mode = "k" }), spot = CreateFrame("Frame", nil, coverHost) }
            ParkMark(mark)
            mark.container = MarkContainer(coverHost, ids, function(auraButton)
                local art = CreateFrame("Frame", nil, auraButton)
                art:SetAllPoints(mark.spot)
                art:SetFrameLevel(markLevel + LEVEL_MARK)
                StyleMark(MakeMark(art, true), MarkOn())
                mark.arts[art] = true
            end)
            if not mark.container then return end
            mark.sig = key
            marks[icon] = mark
        elseif key and mark.sig ~= key then
            -- another rank's buff learned since
            if pcall(mark.container.SetAuraGroupCandidateFilters, mark.container, MARK_GROUP, { includeSpellIDs = ids }) then
                mark.sig = key
            end
        end
    end
end

-- The icon of the totem on a button: GetTotemInfo by its slot; failing that, the icon it shows
local function TotemOn(button, tex)
    local slot = button.slot
    if Readable(slot) and type(slot) == "number" then
        local ok, have, _, _, _, icon = pcall(GetTotemInfo, slot)
        if ok and Readable(have) and have and Readable(icon) and icon then return icon end
    end
    local shown = tex.GetTextureFileID and tex:GetTextureFileID()
    if Readable(shown) and shown then return shown end
end

-- THE BARS. An action button holding a learned totem's spell (the totem's icon is its spell's) gets a
-- container of its own, its mark laid on the button's icon.
local barButtons
local function BarButtons()
    if barButtons then return barButtons end
    barButtons = {}
    for _, prefix in ipairs(BAR_PREFIXES) do
        for i = 1, 12 do
            local button = _G[prefix .. i]
            if button then barButtons[#barButtons + 1] = button end
        end
    end
    return barButtons
end

-- the icon of the spell in a button's slot (a spell, or a macro that casts one)
local function BarSpellIcon(button)
    local slot = button.action
    if not (Readable(slot) and type(slot) == "number" and slot > 0) then return nil end
    local ok, kind, id, subType = pcall(GetActionInfo, slot)
    if not (ok and Readable(kind) and Readable(id)) then return nil end
    if kind == "spell" or (kind == "macro" and Readable(subType) and subType == "spell") then
        local okIcon, icon = pcall(C_Spell.GetSpellTexture, id)
        if okIcon and Readable(icon) then return icon end
    end
end

local function SyncBarMark(button, learned, on)
    local mark = button.FlareUI_TotemMark
    local icon = learned and BarSpellIcon(button)
    local ids = icon and learned[icon]
    local key = type(ids) == "table" and next(ids) and IDKey(ids)
    if not key then
        if mark and mark.sig then
            -- (refused in a fight: tried again at its end)
            if pcall(mark.container.SetAuraGroupEnabled, mark.container, MARK_GROUP, false) then mark.sig = nil end
        end
        return
    end
    if not mark then
        mark = { arts = setmetatable({}, { __mode = "k" }) }
        mark.container = MarkContainer(button, ids, function(auraButton)
            local art = CreateFrame("Frame", nil, auraButton)
            art:SetAllPoints(button.icon or button)
            art:SetFrameLevel(button:GetFrameLevel() + LEVEL_MARK)
            StyleMark(MakeMark(art, false), MarkOn())
            mark.arts[art] = true
        end)
        if not mark.container then return end
        button.FlareUI_TotemMark = mark
        mark.sig = key
    elseif mark.sig ~= key then
        if pcall(mark.container.SetAuraGroupCandidateFilters, mark.container, MARK_GROUP, { includeSpellIDs = ids })
            and pcall(mark.container.SetAuraGroupEnabled, mark.container, MARK_GROUP, true) then
            mark.sig = key
        end
    end
    for art in pairs(mark.arts) do StyleMark(art, on) end
end

-- Listens while the option is on: totems and slots change, and out of a fight your buffs teach
local rangeEvents = CreateFrame("Frame")
local listening, pending = false, false
local RANGE_EVENTS = { "PLAYER_TOTEM_UPDATE", "PLAYER_REGEN_ENABLED", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED",
                       "UPDATE_BONUS_ACTIONBAR", "SPELLS_CHANGED", "PLAYER_ENTERING_WORLD" }
local function Listen(on)
    if on == listening then return end
    listening = on
    if on then
        rangeEvents:RegisterUnitEvent("UNIT_AURA", "player")
        for _, event in ipairs(RANGE_EVENTS) do rangeEvents:RegisterEvent(event) end
    else
        rangeEvents:UnregisterAllEvents()
    end
end

UpdateRange = function()
    local on = MarkOn()
    Listen(on)
    local learned = on and Learned()
    local calm = not InCombatLockdown()
    if learned and calm then
        Learn()
        BuildMarks(learned)
    end
    -- the totems standing
    local frame = _G.TotemFrame
    for _, mark in pairs(marks) do mark.used = false end
    if learned and frame and frame.totemPool then
        for button in frame.totemPool:EnumerateActive() do
            local tex = button.Icon and button.Icon.Texture
            local icon = tex and TotemOn(button, tex)
            local mark = icon and marks[icon]
            if mark and pcall(SeatMark, mark, button) then
                markLevel = button:GetFrameLevel()
                mark.used = true
            end
        end
    end
    for _, mark in pairs(marks) do
        if not mark.used then pcall(ParkMark, mark) end
        for art in pairs(mark.arts) do
            StyleMark(art, on)
            if calm and not art:IsForbidden() then art:SetFrameLevel(markLevel + LEVEL_MARK) end
        end
    end
    -- the bars
    local bars = learned and BarsOn() and learned or nil
    for _, button in ipairs(BarButtons()) do
        if bars or button.FlareUI_TotemMark then SyncBarMark(button, bars, on) end
    end
end

-- A burst of events is read once, on the next frame. Your buffs changing only matter when they teach
-- a totem's buff (never in a fight).
rangeEvents:SetScript("OnEvent", function(_, event)
    if event == "UNIT_AURA" and not Learn() then return end
    if pending then return end
    pending = true
    C_Timer.After(0, function()
        pending = false
        UpdateRange()
    end)
end)

--------------------------------------------------
-- 5. BLIZZARD'S TOTEM FRAME, REHOMED
-- A managed frame: Blizzard re-parents it into PlayerFrame on every show, so it is pulled back
--------------------------------------------------
local anchoring = false
local function AnchorTotemFrame()
    local frame = _G.TotemFrame
    if anchoring or not (frame and holder) then return end
    anchoring = true
    if frame:GetParent() ~= holder then frame:SetParent(holder) end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    anchoring = false
end

local function AdoptTotemFrame()
    local frame = _G.TotemFrame
    if not frame then return end
    AnchorTotemFrame()
    hooksecurefunc(frame, "SetParent", AnchorTotemFrame)
    hooksecurefunc(frame, "SetPoint", AnchorTotemFrame)
    if frame.Layout then hooksecurefunc(frame, "Layout", ArrangeTotems) end
end

--------------------------------------------------
-- 6. EDIT MODE PREVIEW (four sample totems in the same grid and size)
--------------------------------------------------
local function CreatePreview()
    local preview = CreateFrame("Frame", nil, holder)
    preview:SetSize(1, 1)
    preview:SetPoint("TOPLEFT")
    preview:Hide()
    preview.buttons = {}
    for i = 1, #PREVIEW_ICONS do
        local b = CreateFrame("Frame", nil, preview)
        b:SetSize(BUTTON, BUTTON)

        local icon = b:CreateTexture(nil, "BACKGROUND", nil, 2)
        icon:SetSize(ICON, ICON)
        icon:SetPoint("CENTER")
        icon:SetTexture("Interface\\Icons\\" .. PREVIEW_ICONS[i])
        local mask = b:CreateMaskTexture()
        mask:SetAtlas("CircleMask")
        mask:SetAllPoints(icon)
        icon:AddMaskTexture(mask)

        local ring = b:CreateTexture(nil, "OVERLAY")
        ring:SetAtlas("UI-HUD-UnitFrame-TotemFrame")
        ring:SetSize(RING, RING)
        ring:SetPoint("CENTER", 1, -1.5)

        local text = b:CreateFontString(nil, "BACKGROUND", "GameFontNormalSmall")
        text:SetPoint("TOP", b, "BOTTOM", 0, 5)
        text:SetText(PREVIEW_TIMES[i])
        local cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
        cd:SetHideCountdownNumbers(true)
        cd:SetReverse(true)
        b.Cooldown, b.Duration, b.Ring, b.IconTexture = cd, text, ring, icon

        preview.buttons[i] = b
    end
    holder.preview = preview
end

function TOT.SetFaded(out)
    out = out and true or false
    if out == faded then return end
    faded = out
    ApplyMouse()
end

-- shown: Edit Mode; a fight in it brings the live totems back (ns.OnEditFight)
local function SetPreview(shown)
    if not holder then return end
    shown = shown and ns.EditPreviewing()
    holder.preview:SetShown(shown)
    previewing = shown and true or false
    -- live totems step aside while the samples show
    local frame = _G.TotemFrame
    if frame then frame:SetAlpha(shown and 0 or 1) end
    if coverHost then coverHost:SetAlpha(shown and 0 or 1) end   -- the In Range marks with them
    ApplyMouse()
end

--------------------------------------------------
-- 7. SIZE AND GRID
-- The holder is sized to the grid and the totems scaled inside it, so its position stays put
--------------------------------------------------
local function ApplyLayout()
    if not holder then return end
    local scale, perRow = GetSettings()
    local rows = math_ceil(MAX / perRow)
    local width = BUTTON + (perRow - 1) * COL_STEP
    local height = BUTTON + (rows - 1) * RowStep() + (TimerBelow() and TEXT_BELOW or 0)
    holder:SetSize(width * scale, height * scale)

    holder.preview:SetScale(scale)
    PlaceInGrid(holder.preview.buttons, holder.preview, perRow)
    for i, b in ipairs(holder.preview.buttons) do
        StyleTotem(b, b.Cooldown, b.Duration, b.Ring)
        b.Cooldown:SetCooldown(GetTime() - 12 * i, 60)   -- a running sample swipe
    end
    -- the third sample wears the In Range mark (section 4b)
    local sample = holder.preview.buttons[3]
    if sample then
        if not sample.FlareUI_Mark then
            local art = CreateFrame("Frame", nil, sample)
            art:SetAllPoints(sample.IconTexture)
            sample.FlareUI_Mark = MakeMark(art, true)
        end
        sample.FlareUI_Mark:SetFrameLevel(sample:GetFrameLevel() + LEVEL_MARK)
        StyleMark(sample.FlareUI_Mark, MarkOn())
    end

    local frame = _G.TotemFrame
    if frame then
        frame:SetScale(scale)
        ArrangeTotems()
    end
end
TOT.ApplyLayout = ApplyLayout   -- the Unit Frames' Fonts tab restyles the timers (11-13)

local function BuildSettings()
    local function get(key, default)
        return function()
            local db = GetDb()
            return db and db.totems and db.totems[key] or default
        end
    end
    local function set(key)
        return function(_, value)
            local db = GetDb()
            if not db then return end
            db.totems = db.totems or {}
            db.totems[key] = value
            ApplyLayout()
        end
    end
    -- the ring styles have their own defaults
    local style = ns.UFRing and ns.UFRing.On() and ns.UFRing.DefaultTotems() or {}
    local size, perRow = style.size or DEFAULT_SIZE, style.perRow or DEFAULT_PER_ROW
    -- one Frame section (dropdowns, sliders, switches); Fading comes after it (Visibility.lua)
    return ns.EditSection("Frame", {
        { name = L["Size"], kind = LEM.SettingType.Slider, default = size, minValue = 50, maxValue = 200, valueStep = 5,
          get = get("size", size), set = set("size") },
        { name = L["Totems per Row"], kind = LEM.SettingType.Slider, default = perRow, minValue = 1, maxValue = MAX, valueStep = 1,
          get = get("perRow", perRow), set = set("perRow") },
        { name = L["Aura Swipe"], kind = LEM.SettingType.Dropdown, default = "both", get = get("swipe", "both"), set = set("swipe"),
          values = {
              { text = L["Over the Icon"], value = "icon", isRadio = true },
              { text = L["Around the Border"], value = "border", isRadio = true },
              { text = L["Both"], value = "both", isRadio = true },
              { text = L["Off"], value = "none", isRadio = true },
          } },
        { name = L["Aura Timer"], kind = LEM.SettingType.Dropdown, default = "none", get = get("timer", "none"), set = set("timer"),
          values = {
              { text = L["Under the Icon"], value = "below", isRadio = true },
              { text = L["Bottom of the Icon"], value = "bottom", isRadio = true },
              { text = L["Middle of the Icon"], value = "middle", isRadio = true },
              { text = L["Off"], value = "none", isRadio = true },
          } },
        { name = L["In Range Mark"], kind = LEM.SettingType.Checkbox, default = false,
          desc = L["Yellow dashes march round a totem while its buff is on you, and stop when you walk out of its range. Totems without a buff, such as Searing or Tremor, are never marked. A totem is learned the first time you stand in its buff out of combat."],
          get = function()
              local db = GetDb()
              return db and db.totems and db.totems.inRange == true or false
          end,
          set = set("inRange") },
        { name = L["Also on Action Bars"], kind = LEM.SettingType.Checkbox, default = true,
          desc = L["The In Range Mark on the totem's spell too, on the totem bar and wherever it is on your action bars."],
          get = function()
              local db = GetDb()
              return not (db and db.totems and db.totems.inRangeBars == false)
          end,
          set = set("inRangeBars") },
    })
end

--------------------------------------------------
-- 8. SETUP
--------------------------------------------------
-- Only with FlareUI's player frame on
function TOT:ShouldLoad()
    local db = GetDb()
    if not (db and db.enabled) then return false end
    local player = db.units and db.units.player
    return not (player and player.enabled == false)
end

function TOT:Init()
    if self.initialized or not _G.TotemFrame then return end
    self.initialized = true

    -- the ring styles have their own default position (a style switch reloads)
    if ns.UFRing and ns.UFRing.On() then
        local _, totemPosition = ns.UFRing.DefaultPositions()
        for key, value in pairs(totemPosition) do DEFAULT_POSITION[key] = value end
    end
    holder = CreateFrame("Frame", "FlareUI_Totems", UIParent)
    holder:SetFrameStrata("LOW")
    holder:SetClampedToScreen(true)
    CreatePreview()
    ApplyPosition()
    LEM:AddFrame(holder, OnFrameMoved, DEFAULT_POSITION, "FlareUI Totems")
    LEM:AddFrameSettings(holder, BuildSettings())

    AdoptTotemFrame()
    ApplyLayout()

    LEM:RegisterCallback("layout", function(layoutName) ApplyPosition(layoutName) end)
    LEM:RegisterCallback("enter", function() SetPreview(true) end)
    LEM:RegisterCallback("exit", function() SetPreview(false) end)
    ns.OnEditFight(function() SetPreview(LEM:IsInEditMode()) end)
end
