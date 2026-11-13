local _, ns = ...
local L = ns.L

--------------------------------------------------
-- ACTION BARS
-- Styles Blizzard's action bars (slot art, scale, hotkey/count text, range and mana colouring) and
-- runs the Fake Cooldown Manager (click-through bars), spell rank updates and Auto-Paging.
--------------------------------------------------

--------------------------------------------------
-- 1. MODULE REGISTRATION
--------------------------------------------------
ns.ActionBars = ns.ActionBars or {}
local ActionBars = ns.ActionBars
ns.modules["ActionBars"] = ActionBars

LibStub("AceEvent-3.0"):Embed(ActionBars)
LibStub("AceTimer-3.0"):Embed(ActionBars)
LibStub("AceHook-3.0"):Embed(ActionBars)

--------------------------------------------------
-- 2. UPVALUES
--------------------------------------------------
local _G = _G
local ipairs = ipairs
local table_insert = table.insert
local InCombatLockdown = InCombatLockdown
local GetActionInfo = GetActionInfo
local GetPetActionInfo = GetPetActionInfo
local GetPetActionSlotUsable = GetPetActionSlotUsable
local C_Spell = C_Spell
local C_Timer = C_Timer
local canaccessvalue = canaccessvalue

--------------------------------------------------
-- 3. CONSTANTS & DATA
--------------------------------------------------
local RANGE_INDICATOR = _G.RANGE_INDICATOR
local BUTTON_SCALE = 1.11   -- Bar Scale's default (actionbars.buttonScale; 1.06 until 11-11)

-- text offsets from the button's corner: hotkey top right, count bottom right, macro name bottom
local HOTKEY_X, HOTKEY_Y = -4, -4
local COUNT_X, COUNT_Y = -4, 4
local MACRO_X, MACRO_Y = -6, 4

local BAR_DATA = {
    { key = "bar1",    prefix = "ActionButton",              count = 12 },
    { key = "bar2",    prefix = "MultiBarBottomLeftButton",  count = 12 },
    { key = "bar3",    prefix = "MultiBarBottomRightButton", count = 12 },
    { key = "bar4",    prefix = "MultiBarRightButton",       count = 12 },
    { key = "bar5",    prefix = "MultiBarLeftButton",        count = 12 },
    { key = "bar6",    prefix = "MultiBar5Button",           count = 12 },
    { key = "bar7",    prefix = "MultiBar6Button",           count = 12 },
    { key = "bar8",    prefix = "MultiBar7Button",           count = 12 },
    { key = "pet",     prefix = "PetActionButton",           count = 10 },
    { key = "stance",  prefix = "StanceButton",              count = 10 },
    { key = "possess", prefix = "PossessButton",             count = 2 },
}

--------------------------------------------------
-- 4. FAKE COOLDOWN MANAGER (FCM) STATE
--------------------------------------------------
ActionBars.fcm = {
    unlockMode = false,
    wasDragging = false,
    dragWatching = nil,
}

--------------------------------------------------
-- 5. HELPERS
--------------------------------------------------
local function GetBarConfig()
    if not ns.db or not ns.db.profile or not ns.db.profile.actionbars then
        return nil
    end
    return ns.db.profile.actionbars
end

-- Blizzard creates the buttons before any addon loads, so each list is built once
local buttonsByKey = {}
local function GetButtonsForBarKey(key)
    local buttons = buttonsByKey[key]
    if buttons then return buttons end
    for _, data in ipairs(BAR_DATA) do
        if data.key == key then
            buttons = {}
            for i = 1, data.count do
                local btn = _G[data.prefix .. i]
                if btn then table_insert(buttons, btn) end
            end
            if #buttons > 0 then buttonsByKey[key] = buttons end
            return buttons
        end
    end
    return {}
end

local allButtons
local function GetAllActionButtons()
    if allButtons then return allButtons end
    local all = {}
    for _, data in ipairs(BAR_DATA) do
        for _, b in ipairs(GetButtonsForBarKey(data.key)) do table_insert(all, b) end
    end
    if #all > 0 then allButtons = all end
    return all
end

--------------------------------------------------
-- 6. BUTTON ART
--------------------------------------------------
-- Blizzard's UpdateButtonArt picks SlotArt or SlotBackground from the bar's hideBarArt flag; a
-- post-hook per button forces slot art. Bars 1-8 and pet only (the others render it badly).
local ART_BAR_KEYS = { bar1 = true, bar2 = true, bar3 = true, bar4 = true, bar5 = true, bar6 = true, bar7 = true, bar8 = true, pet = true }

local artButtons
local function GetAllArtButtons()
    if artButtons then return artButtons end
    local all = {}
    for _, data in ipairs(BAR_DATA) do
        if ART_BAR_KEYS[data.key] then
            for _, b in ipairs(GetButtonsForBarKey(data.key)) do table_insert(all, b) end
        end
    end
    if #all > 0 then artButtons = all end
    return all
end

-- remembered for switching off: re-running UpdateButtonArt does not restore it on Forever
local function SnapshotButtonArt(button)
    if button.FlareUI_ArtOrig then return end
    local nw, nh = button.NormalTexture:GetSize()
    local pw, ph = button.PushedTexture:GetSize()
    local hw, hh
    if button.HighlightTexture then
        hw, hh = button.HighlightTexture:GetSize()
    end
    local cw, ch
    if button.CheckedTexture then
        cw, ch = button.CheckedTexture:GetSize()
    end
    button.FlareUI_ArtOrig = {
        slotArt = button.SlotArt:IsShown(), slotBg = button.SlotBackground:IsShown(),
        normalAtlas = button.NormalTexture:GetAtlas(), normalLayer = button.NormalTexture:GetDrawLayer(), nw = nw, nh = nh,
        pushedAtlas = button.PushedTexture:GetAtlas(), pushedLayer = button.PushedTexture:GetDrawLayer(), pw = pw, ph = ph,
        hw = hw, hh = hh, cw = cw, ch = ch,
    }
end

local function RestoreButtonArt(button)
    local o = button.FlareUI_ArtOrig
    if not o then return end
    button.SlotArt:SetShown(o.slotArt)
    button.SlotBackground:SetShown(o.slotBg)
    if o.normalAtlas then button:SetNormalAtlas(o.normalAtlas) end
    button.NormalTexture:SetDrawLayer(o.normalLayer)
    button.NormalTexture:SetSize(o.nw, o.nh)
    if o.pushedAtlas then button:SetPushedAtlas(o.pushedAtlas) end
    button.PushedTexture:SetDrawLayer(o.pushedLayer)
    button.PushedTexture:SetSize(o.pw, o.ph)
    if o.hw and button.HighlightTexture then button.HighlightTexture:SetSize(o.hw, o.hh) end
    if o.cw and button.CheckedTexture then button.CheckedTexture:SetSize(o.cw, o.ch) end
    button.FlareUI_ArtOrig = nil
end

local function ApplyButtonArt(button)
    local db = GetBarConfig()
    if not db or not db.enabled or not db.buttonArt then return end
    if not button or not button.SlotArt or not button.SlotBackground or not button.NormalTexture or not button.PushedTexture then return end

    SnapshotButtonArt(button)
    button.SlotArt:Show()
    button.SlotBackground:Hide()

    -- read before the hook replaces UpdateButtonArt (after it, the comparison always fails)
    local small = button.FlareUI_Small
    if small == nil then small = SmallActionButtonMixin and button.UpdateButtonArt == SmallActionButtonMixin.UpdateButtonArt or false end
    local w, h = 46, 45
    if small then
        -- The frame atlases are drawn for a 45 px button and anchored TOPLEFT. Blizzard sizes them
        -- 35 (frame) or 46x45 (hover, checked) on the 30 px pet and possess buttons, so they hang
        -- over the right and bottom edges. They are kept in proportion to the button instead.
        local bw, bh = button:GetSize()
        if not bw or bw <= 0 then bw, bh = 30, 30 end
        w, h = bw * 46 / 45, bh
        if button.HighlightTexture then button.HighlightTexture:SetSize(w, h) end
        if button.CheckedTexture then button.CheckedTexture:SetSize(w, h) end
    end
    button:SetNormalAtlas("UI-HUD-ActionBar-IconFrame")
    button.NormalTexture:SetDrawLayer("OVERLAY")
    button.NormalTexture:SetSize(w, h)
    button:SetPushedAtlas("UI-HUD-ActionBar-IconFrame-Down")
    button.PushedTexture:SetDrawLayer("OVERLAY")
    button.PushedTexture:SetSize(w, h)
end

--------------------------------------------------
-- 6b. FLAREUI BORDERS (Bar Appearance, actionbars.flareBorders, off; 11-11, a player's request)
-- Only the frame changes (11-11 Marcus): Blizzard's bronze frame goes invisible and FlareUI Frames, the
-- chat and meter windows' border, goes where it was. The icon, its rounded corners, the slot art and every other
-- part of the button stay Blizzard's. Off shows Blizzard's frame again.
--------------------------------------------------
-- the border's fit, tuned by eye (11-11): how far it reaches past the button's edge (negative: in),
-- and its thickness. Neighbouring buttons' borders met in the gap between them at 3 px out.
local FLARE_BORDER_OUT, FLARE_BORDER_EDGE = 0, 16

local function SkinBorder(button, on)
    local icon = button.icon or button.Icon
    if not (icon and button.NormalTexture) then return end
    if on then
        if not button.FlareUI_Border then
            local b = CreateFrame("Frame", nil, button, "BackdropTemplate")
            button.FlareUI_Border = b
        end
        local b = button.FlareUI_Border
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", -FLARE_BORDER_OUT, FLARE_BORDER_OUT)
        b:SetPoint("BOTTOMRIGHT", FLARE_BORDER_OUT, -FLARE_BORDER_OUT)
        local LSM = LibStub("LibSharedMedia-3.0")
        -- (11-11: FlareUI Frames, the chat and meter windows' border; FlareUI Thin looked too faint here)
        local file = LSM:Fetch("border", "FlareUI Frames")
        b:SetBackdrop({ edgeFile = file, edgeSize = ns.BorderEdgeSize(file, FLARE_BORDER_EDGE) })
        local c = ns.BORDER_COLOR
        b:SetBackdropBorderColor(c.r, c.g, c.b, c.a or 1)
        -- over the cooldown swipe, under the texts' frame
        b:SetFrameLevel(button:GetFrameLevel() + 2)
        b:Show()
        button.NormalTexture:SetAlpha(0)
        button.FlareUI_Bordered = true
    elseif button.FlareUI_Bordered then
        if button.FlareUI_Border then button.FlareUI_Border:Hide() end
        button.NormalTexture:SetAlpha(1)
        button.FlareUI_Bordered = nil
    end
end

-- every bar's buttons: the bars above, the totem bar (its action buttons and its summon / recall),
-- and the vehicle and override bar (an addon of its own, loaded on demand). The Extra Action and
-- zone ability buttons keep their own decorated art.
local function SkinnedButtons()
    local list = {}
    for _, b in ipairs(GetAllActionButtons()) do list[#list + 1] = b end
    for i = 1, 12 do list[#list + 1] = _G["MultiCastActionButton" .. i] end
    list[#list + 1] = _G.MultiCastSummonSpellButton
    list[#list + 1] = _G.MultiCastRecallSpellButton
    local override = _G.OverrideActionBar
    for i = 1, 6 do list[#list + 1] = override and override["SpellButton" .. i] end
    return list
end

local function UpdateBordersAll()
    local db = GetBarConfig()
    local on = db and db.enabled and db.flareBorders or false
    if on and not ActionBars.overrideWatched and EventUtil and EventUtil.ContinueOnAddOnLoaded then
        ActionBars.overrideWatched = true
        EventUtil.ContinueOnAddOnLoaded("Blizzard_OverrideActionBar", function()
            if not InCombatLockdown() then UpdateBordersAll() end
        end)
    end
    for _, button in pairs(SkinnedButtons()) do
        -- Blizzard's art update sets the frame again: hidden again after it
        if on and not button.FlareUI_BorderHooked and button.UpdateButtonArt then
            button.FlareUI_BorderHooked = true
            hooksecurefunc(button, "UpdateButtonArt", function(self)
                local now = GetBarConfig()
                if now and now.enabled and now.flareBorders then SkinBorder(self, true) end
            end)
        end
        SkinBorder(button, on)
    end
end

local function UpdateButtonArtAll()
    local db = GetBarConfig()
    local force = db and db.enabled and db.buttonArt
    for _, button in ipairs(GetAllArtButtons()) do
        if not button.FlareUI_ArtHooked and button.UpdateButtonArt then
            button.FlareUI_ArtHooked = true
            button.FlareUI_Small = SmallActionButtonMixin and button.UpdateButtonArt == SmallActionButtonMixin.UpdateButtonArt or false
            hooksecurefunc(button, "UpdateButtonArt", ApplyButtonArt)
        end
        if force then
            ApplyButtonArt(button)
        elseif button.FlareUI_ArtForced then
            RestoreButtonArt(button)
        end
        button.FlareUI_ArtForced = force or nil
    end
end

--------------------------------------------------
-- 6b. ACTIVE HIGHLIGHT (Button Appearance, off; 11-12, a player's request)
-- The active stance or form, a queued Heroic Strike / Cleave / Maul / Raptor Strike, auto attack and a
-- repeating Auto Shot or wand, drawn plainly: a gold edge and a light over the icon, pulsing while an
-- attack waits for the next swing. Worked out on events and on each SetChecked (IsActiveButton below).
-- Looks only: nothing secure is touched, so it works in a fight.
--------------------------------------------------
local ACTIVE_COLOR = { 1, 0.82, 0.25 }
local QUEUED_SPELLS = { 78, 845, 6807, 2973 }   -- Heroic Strike, Cleave, Maul, Raptor Strike (every rank, by name)
local queuedNames
local function QueuedName(name)
    if not queuedNames then
        queuedNames = {}
        for _, id in ipairs(QUEUED_SPELLS) do
            local n = C_Spell.GetSpellName(id)
            if n then queuedNames[n] = true end
        end
    end
    return name and queuedNames[name] or false
end

-- the spell's name on an action slot (a macro: the spell it casts)
local function ActionSpellName(action)
    if not (action and GetActionInfo) then return nil end
    local kind, id = GetActionInfo(action)
    if kind == "macro" and id and GetMacroSpell then id = GetMacroSpell(id); kind = id and "spell" end
    if kind ~= "spell" or not id then return nil end
    return C_Spell.GetSpellName(id)
end

-- an on-next-swing attack on this button
local function HoldsQueuedAttack(button)
    return QueuedName(ActionSpellName(button.action))
end

-- the active stance / form / aura's spell name (rank-free), nil out of one
local function ActiveFormName()
    local form = GetShapeshiftForm and GetShapeshiftForm()
    if not form or form == 0 or not GetShapeshiftFormInfo then return nil end
    local _, _, _, spellID = GetShapeshiftFormInfo(form)
    return spellID and C_Spell.GetSpellName(spellID) or nil
end

-- What the highlight shows, worked out here rather than read from Blizzard's checked state (11-12, a
-- player report). That state also marks a spell for the moment it's cast, and on Forever it is
-- sometimes left on until the button is refreshed (pointing at it): Rend, Thunder Clap and others stayed
-- lit. As LibActionButton does, the action is asked directly, on events: the active stance or form, a
-- queued on-next-swing attack, auto attack and a repeating Auto Shot or wand. The stance and pet bars
-- (no action slot) keep Blizzard's checked state, which follows the form and the pet's mode.
local function ActionActive(action)
    if not C_ActionBar.HasAction(action) then return false end
    if C_ActionBar.IsAutoRepeatAction(action) then return true end
    local current = C_ActionBar.IsCurrentAction(action)
    if current and C_ActionBar.IsAttackAction(action) then return true end
    local name = ActionSpellName(action)
    if not name then return false end
    if current and QueuedName(name) then return true end
    return name == ActiveFormName()
end

local function IsActiveButton(button)
    local action = button.action
    if type(action) ~= "number" or not (C_ActionBar and C_ActionBar.HasAction) then
        return button.GetChecked and button:GetChecked() and true or false
    end
    -- (the slot APIs error on a slot number out of range)
    local ok, active = pcall(ActionActive, action)
    return ok and active or false
end

local function ActiveOverlay(button)
    local ov = button.FlareUI_Active
    if ov then return ov end
    -- (11-13, a player report: the square edge didn't match the frame) the edge is the button's own
    -- frame in gold, set in UpdateActive; the light takes the icon's rounded mask
    ov = CreateFrame("Frame", nil, button, "BackdropTemplate")
    ov:SetAllPoints(button)
    ov:SetFrameLevel(button:GetFrameLevel() + 3)
    ov.frame = ov:CreateTexture(nil, "OVERLAY", nil, 6)
    ov.frame:SetBlendMode("ADD")
    ov.light = ov:CreateTexture(nil, "OVERLAY")
    ov.light:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    ov.light:SetBlendMode("ADD")
    ov.light:SetAllPoints(button.icon or button)
    ov.light:SetAlpha(0.55)
    if button.IconMask then pcall(ov.light.AddMaskTexture, ov.light, button.IconMask) end
    local pulse = ov:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.35)
    fade:SetDuration(0.45)
    fade:SetSmoothing("IN_OUT")
    ov.pulse = pulse
    ov:Hide()
    button.FlareUI_Active = ov
    return ov
end

local function UpdateActive(button)
    local db = GetBarConfig()
    local on = db and db.enabled and db.activeHighlight and IsActiveButton(button) or false
    if not on then
        local ov = button.FlareUI_Active
        if ov then ov.pulse:Stop(); ov:Hide() end
        return
    end
    local ov = ActiveOverlay(button)
    -- (11-13 performance pass) already lit the same way: nothing to redo. The events behind this fire
    -- dozens of times a second in a fight, and each pass rebuilt every lit button's border.
    -- UpdateActiveAll clears fuiAtlas so a settings or scale change repaints.
    local bordered = button.FlareUI_Bordered or false
    local normalTex = button.NormalTexture
    local atlasNow = not bordered and normalTex and normalTex.GetAtlas and normalTex:GetAtlas() or nil
    local queued = HoldsQueuedAttack(button) and true or false
    if ov:IsShown() and ov.fuiBordered == bordered and ov.fuiAtlas == atlasNow and ov.fuiQueued == queued then return end
    ov.fuiBordered, ov.fuiAtlas, ov.fuiQueued = bordered, atlasNow, queued
    -- the edge: the frame the button wears right now, in gold
    local c = ACTIVE_COLOR
    if button.FlareUI_Bordered then
        local LSM = LibStub("LibSharedMedia-3.0")
        local file = LSM:Fetch("border", "FlareUI Frames")
        ov:SetBackdrop({ edgeFile = file, edgeSize = ns.BorderEdgeSize(file, FLARE_BORDER_EDGE) })
        ov:SetBackdropBorderColor(c[1], c[2], c[3], 1)
        ov.frame:Hide()
    else
        ov:SetBackdrop(nil)
        local normal = button.NormalTexture
        local atlas = normal and normal.GetAtlas and normal:GetAtlas()
        if atlas then
            ov.frame:SetAtlas(atlas)
            ov.frame:ClearAllPoints()
            ov.frame:SetPoint("CENTER", normal, "CENTER")
            ov.frame:SetSize(normal:GetSize())
            ov.frame:SetDesaturated(true)
            ov.frame:SetVertexColor(c[1], c[2], c[3], 1)
            ov.frame:Show()
        else
            ov.frame:Hide()
        end
    end
    ov:Show()
    if HoldsQueuedAttack(button) then
        if not ov.pulse:IsPlaying() then ov.pulse:Play() end
    else
        ov.pulse:Stop()
        ov:SetAlpha(1)
    end
end

local activeButtons = {}   -- every hooked button, for the event refresh
local function RefreshActive()
    for button in pairs(activeButtons) do UpdateActive(button) end
end

-- an event: every button now, once more the next frame and a moment later (the game's answers can
-- trail the event: a queued attack used, a cast ended)
local ACTIVE_EVENTS = { "ACTIONBAR_UPDATE_STATE", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED",
    "UPDATE_BONUS_ACTIONBAR", "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS", "START_AUTOREPEAT_SPELL",
    "STOP_AUTOREPEAT_SPELL", "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT", "PLAYER_REGEN_ENABLED" }
local ACTIVE_UNIT_EVENTS = { "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED_QUIET" }
local activeEvents, activeLater
local function OnActiveEvent()
    RefreshActive()
    if activeLater then return end
    activeLater = true
    C_Timer.After(0, RefreshActive)
    C_Timer.After(0.3, function() activeLater = nil; RefreshActive() end)
end

local function UpdateActiveAll()
    local db = GetBarConfig()
    local on = db and db.enabled and db.activeHighlight
    for _, button in pairs(SkinnedButtons()) do
        if on and not button.FlareUI_ActiveHooked and button.SetChecked then
            button.FlareUI_ActiveHooked = true
            hooksecurefunc(button, "SetChecked", UpdateActive)
            activeButtons[button] = true
        end
        if button.FlareUI_ActiveHooked then
            if button.FlareUI_Active then button.FlareUI_Active.fuiAtlas = false end   -- (repaint)
            UpdateActive(button)
        end
    end
    if on and not activeEvents then
        activeEvents = CreateFrame("Frame")
        for _, event in ipairs(ACTIVE_EVENTS) do pcall(activeEvents.RegisterEvent, activeEvents, event) end
        for _, event in ipairs(ACTIVE_UNIT_EVENTS) do pcall(activeEvents.RegisterUnitEvent, activeEvents, event, "player") end
    end
    if activeEvents then activeEvents:SetScript("OnEvent", on and OnActiveEvent or nil) end
end

--------------------------------------------------
-- 6c. MICRO MENU AND BAG BAR (Bars Appearance, 11-13, a player's request)
-- Borderless Micro Menu / Borderless Bag Bar: Forever's frame art round each (and the bag bar's
-- dividers) goes invisible; that art only fits the bars' default places.
-- Collapsible Bag Bar (needs Borderless Bag Bar: the frame would stay at full length round a folded
-- bar): an arrow by the backpack folds the bag slots away, as retail's. Forever left
-- Blizzard's own toggle out of its bag bar (BagsBar.hideExpandToggle), so the arrow is FlareUI's, in
-- Blizzard's art. The fold is Blizzard's own "expandBagBar" setting, and Blizzard's bag manager opens
-- it by itself while an item is on the cursor (so it can go in a bag). Nothing is hooked until one of
-- them is on: off leaves Blizzard's bars alone.
--------------------------------------------------
do
    local arrow, hooked, artTouched, collapsible = nil, false, false, false
    local borderlessMenu, borderlessBags = false, false
    local folded = setmetatable({}, { __mode = "k" })   -- bag buttons FlareUI hid

    local function Manager() return _G.MainMenuBarBagManager end
    local function Expanded()
        local m = Manager()
        return not (m and m.ShouldBarExpand) or m:ShouldBarExpand() and true or false
    end

    -- the frame art (alpha only: Blizzard's code never sees a change)
    local function DividerArt()
        local bar = _G.BagsBar
        if not (bar and (borderlessBags or artTouched)) then return end
        local a = borderlessBags and 0 or 1
        for _, pool in ipairs({ bar.HorizontalDividersPool or false, bar.VerticalDividersPool or false }) do
            if pool then for divider in pool:EnumerateActive() do divider:SetAlpha(a) end end
        end
    end
    local function SetArt()
        local menu, bar = _G.MicroMenu, _G.BagsBar
        local m, b = borderlessMenu and 0 or 1, borderlessBags and 0 or 1
        if menu and menu.BorderArt then menu.BorderArt:SetAlpha(m) end
        if menu and menu.BackgroundArt then menu.BackgroundArt:SetAlpha(m) end
        if bar and bar.BorderArt then bar.BorderArt:SetAlpha(b) end
        DividerArt()
    end

    -- the arrow points the way the slots go out (expanded) or come back (folded), as Blizzard's
    local function Rotation(bar)
        local expanded = Expanded()
        if bar:IsHorizontal() then
            if bar:IsDirectionLeft() then return expanded and math.pi or 0 end
            return expanded and 0 or math.pi
        end
        local up, down = 3 * math.pi / 2, math.pi / 2
        if bar:IsDirectionUp() then return expanded and down or up end
        return expanded and up or down
    end

    -- after Blizzard's layout: the arrow by the backpack, the first bag slot past it
    local function PlaceArrow()
        local bar, backpack, m = _G.BagsBar, _G.MainMenuBarBackpackButton, Manager()
        if not (arrow and collapsible and bar and backpack and m) then return end
        local point, relativePoint, x, y = bar:GetBagButtonAnchorPoints()
        local horizontal = bar:IsHorizontal()
        arrow:SetSize(horizontal and 10 or 16, horizontal and 16 or 10)
        arrow:ClearAllPoints()
        arrow:SetPoint(point, backpack, relativePoint, 0, 0)
        local rotation = Rotation(bar)
        arrow.Art:SetRotation(rotation)
        arrow.Glow:SetRotation(rotation)
        for _, button in m:EnumerateBagButtons() do
            if button ~= backpack and button:IsShown() then
                button:ClearAllPoints()
                button:SetPoint(point, arrow, relativePoint, x, y)
                break
            end
        end
        arrow:Show()
    end

    local function CanTouch(button) return not (InCombatLockdown() and button:IsProtected()) end

    -- folded: every bag slot but the backpack hidden (and remembered, so only those come back)
    local function Fold(collapse)
        local bar, backpack, m = _G.BagsBar, _G.MainMenuBarBackpackButton, Manager()
        if not (bar and m) then return end
        local changed = false
        for _, button in m:EnumerateBagButtons() do
            if button ~= backpack and CanTouch(button) then
                if collapse and button:IsShown() then
                    folded[button] = true
                    button:Hide()
                    changed = true
                elseif not collapse and folded[button] then
                    folded[button] = nil
                    button:Show()
                    changed = true
                end
            end
        end
        if changed then bar:Layout() else PlaceArrow() end
    end

    local function Arrow()
        if arrow then return arrow end
        arrow = CreateFrame("Button", "FlareUI_BagBarToggle", _G.BagsBar)
        arrow:SetFrameLevel(_G.BagsBar:GetFrameLevel() + 5)
        arrow.Art = arrow:CreateTexture(nil, "ARTWORK")
        arrow.Art:SetAtlas("bag-arrow")
        arrow.Art:SetSize(10, 16)
        arrow.Art:SetPoint("CENTER")
        arrow.Glow = arrow:CreateTexture(nil, "HIGHLIGHT")
        arrow.Glow:SetAtlas("bag-arrow")
        arrow.Glow:SetSize(10, 16)
        arrow.Glow:SetPoint("CENTER")
        arrow.Glow:SetBlendMode("ADD")
        arrow.Glow:SetAlpha(0.4)
        arrow:RegisterForClicks("LeftButtonUp")
        arrow:SetScript("OnClick", function()
            local m = Manager()
            if m and m.ToggleExpandBar then m:ToggleExpandBar() end
        end)
        arrow:SetScript("OnMouseDown", function(self) self.Art:SetPoint("CENTER", 1, -1) end)
        arrow:SetScript("OnMouseUp", function(self) self.Art:SetPoint("CENTER") end)
        return arrow
    end

    local function Hook()
        if hooked then return end
        local bar, m = _G.BagsBar, Manager()
        if not (bar and m) then return end
        hooked = true
        hooksecurefunc(bar, "Layout", PlaceArrow)
        if bar.UpdateDividers then hooksecurefunc(bar, "UpdateDividers", DividerArt) end
        -- the arrow's click, or an item picked up or put down
        EventRegistry:RegisterCallback("MainMenuBarManager.OnExpandChanged", function()
            if collapsible then Fold(not Expanded()) end
        end, ActionBars)
        -- a slot Blizzard shows again while folded (a bag equipped, the keyring) folds too
        for _, button in m:EnumerateBagButtons() do
            if button ~= _G.MainMenuBarBackpackButton then
                button:HookScript("OnShow", function(self)
                    if collapsible and not Expanded() and CanTouch(self) then
                        folded[self] = true
                        self:Hide()
                    end
                end)
            end
        end
    end

    function ActionBars.ApplyMenuBags()
        local db = GetBarConfig()
        local on = db and db.enabled
        -- (11-13: Borderless Menu and Bags split in two)
        if db and db.borderlessMenuBags ~= nil then
            if db.borderlessMenuBags then db.borderlessMenu, db.borderlessBags = true, true end
            db.borderlessMenuBags = nil
        end
        local wantMenu = on and db.borderlessMenu and true or false
        local wantBags = on and db.borderlessBags and true or false
        local wantCollapse = wantBags and db.collapsibleBags and true or false
        if not (wantMenu or wantBags or hooked) then return end
        Hook()
        if not hooked then return end
        borderlessMenu, borderlessBags = wantMenu, wantBags
        if wantMenu or wantBags or artTouched then
            SetArt()
            artTouched = wantMenu or wantBags
        end
        local was = collapsible
        collapsible = wantCollapse
        if collapsible then
            Arrow()
            Fold(not Expanded())
            PlaceArrow()
        elseif was then
            if arrow then arrow:Hide() end
            Fold(false)
            _G.BagsBar:Layout()   -- the first slot back on the backpack
        end
    end
end

--------------------------------------------------
-- 7. TYPOGRAPHY & TEXT
--------------------------------------------------
-- Applied in order to the raw (never localised) binding key: NUMPAD before PLUS, SPACEBAR before SPACE
local KEY_SHORT = {
    { "ALT%-", "A" }, { "CTRL%-", "C" }, { "SHIFT%-", "S" }, { "META%-", "M" },
    { "NUMPADDECIMAL", "N." },
    { "NUMPAD", "N" },
    { "PLUS", "+" }, { "MINUS", "-" }, { "MULTIPLY", "*" }, { "DIVIDE", "/" },
    { "BACKSPACE", "BS" }, { "CAPSLOCK", "Cp" }, { "CLEAR", "Cl" }, { "DELETE", "Del" },
    { "MOUSEWHEELDOWN", "WD" }, { "MOUSEWHEELUP", "WU" },
    { "NUMLOCK", "NL" }, { "PAGEDOWN", "PD" }, { "PAGEUP", "PU" },
    { "SCROLLLOCK", "SL" }, { "SPACEBAR", "SP" }, { "SPACE", "SP" }, { "TAB", "Tb" },
    { "DOWNARROW", "Dn" }, { "LEFTARROW", "Lf" }, { "RIGHTARROW", "Rt" }, { "UPARROW", "Up" },
    { "INSERT", "Ins" }, { "HOME", "Hm" }, { "END", "En" },
}

local function ShortenKey(key)
    if not key or key == "" then return key end
    key = key:upper()
    key = key:gsub(" ", "")
    key = key:gsub("BUTTON(%d+)", "M%1")
    for _, rule in ipairs(KEY_SHORT) do
        key = key:gsub(rule[1], rule[2])
    end
    return key
end

-- Blizzard's resolved action, the bar's command name, or the CLICK binding (Blizzard's fallback)
local function GetBindingKeyForButton(button)
    local action = button.bindingAction or button.commandName
    local key = action and GetBindingKey(action)
    if not key then
        local name = button.GetName and button:GetName()
        if name then key = GetBindingKey("CLICK " .. name .. ":LeftButton") end
    end
    return key
end

-- Blizzard's range dot: the "●" a button without a key shows while you have a target, red out of
-- range (6.3.2). Status Colouring on: no dot, the button's own red says it. Off: Blizzard's dot, in
-- Arial Narrow (Blizzard's keybind font) at the Keybinds size, as a chosen face may have no "●" and
-- draw a "?" box (a player's screenshot).
local function RangeDotWanted(db)
    return not (db and db.colors and db.colors.enableRange)
end
local function SetRangeDot(hotkey, db)
    if RangeDotWanted(db) then
        local font = db and db.hotkeyFont or {}
        ns.SetFont(hotkey, "Fonts\\ARIALN.TTF", font.size or 12, (font.flags == "NONE" and "") or font.flags or "OUTLINE")
        hotkey.fuiRangeDot = true
        hotkey:SetText(RANGE_INDICATOR)
    else
        hotkey:SetText("")
    end
    hotkey:Hide()   -- (Blizzard shows the dot with a target)
end
-- the pet bar's buttons: only the dot, their keys are looked up another way
function ActionBars.PetRangeDot(button)
    local hotkey = button and button.HotKey
    if not hotkey then return end
    local text = hotkey:GetText()
    if text == RANGE_INDICATOR or (text or "") == "" then SetRangeDot(hotkey, GetBarConfig()) end
end

local function FontArgs(font)
    return ns.GetFontPath(font.face), font.size, (font.flags == "NONE" and "") or font.flags or "OUTLINE"
end

-- after Blizzard's UpdateHotkeys, which rewrites text and anchor
local function UpdateHotkeyText(button)
    local hotkey = button and button.HotKey
    if not hotkey then return end
    local db = GetBarConfig()
    if not db then return end

    local key = GetBindingKeyForButton(button)
    if not key or key == "" then
        SetRangeDot(hotkey, db)
        return
    end
    -- a key after a range dot: the Keybinds font back
    if hotkey.fuiRangeDot then
        hotkey.fuiRangeDot = nil
        ns.SetFont(hotkey, FontArgs(db.hotkeyFont or {}))
    end
    if db.hideHotkeys then
        hotkey:Hide()
        return
    end
    -- off: Blizzard's own text, so switching off needs no reload; a controller button keeps
    -- Blizzard's icon either way
    local pad = IsBindingForGamePad and IsBindingForGamePad(key)
    local clean = db.cleanKeybinds and not pad
    if clean then hotkey:SetText(ShortenKey(key)) else hotkey:SetText(GetBindingText(key, 1)) end
    hotkey:Show()
    hotkey:ClearAllPoints()
    hotkey:SetPoint("TOPRIGHT", button, "TOPRIGHT", HOTKEY_X, HOTKEY_Y)
    -- Blizzard's box fits its own small font: the button's width and the text's own height, so a
    -- larger keybind font isn't cut off. Off (11-11): one line inside the border, as Blizzard's own
    -- box, so a long name ("Middle Mouse") is cut short instead of wrapping over the icon
    hotkey:SetWordWrap(false)
    hotkey:SetSize(math.max(1, button:GetWidth() - (clean and 2 or 8)), 0)
end

local function UpdateButtonText(button)
    if not button then return end
    local db = GetBarConfig()
    if not db then return end

    if button.HotKey then
        ns.SetFont(button.HotKey, FontArgs(db.hotkeyFont))
        ns.ApplyShadow(button.HotKey, db.hotkeyFont)
        UpdateHotkeyText(button)
    end

    local count = button.Count
    if count then
        local font = db.countFont
        ns.SetFont(count, FontArgs(font))
        count:ClearAllPoints()
        count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", COUNT_X, COUNT_Y)
        ns.ApplyShadow(count, font)
    end

    local name = button.Name
    if name then
        if db.hideMacroText then
            name:Hide()
        else
            name:Show()
            local font = db.macroFont
            ns.SetFont(name, FontArgs(font))
            name:ClearAllPoints()
            name:SetPoint("BOTTOM", button, "BOTTOM", MACRO_X, MACRO_Y)
            ns.ApplyShadow(name, font)
        end
    end
end

-- A settings preview's sample button (11-10): Blizzard's own action button look (ActionButtonTemplate,
-- not secure), styled by FlareUI as the bars are, with action slot i's real keybind. No mouse.
local sampleButtons = 0
function ActionBars.CreateSampleButton(parent, slot)
    sampleButtons = sampleButtons + 1
    -- the template's children are named after the button
    -- (its OnLoad runs Blizzard's art and flyout updates on a button with no action: guarded)
    local ok, b = pcall(CreateFrame, "CheckButton", "FlareUI_PreviewActionButton" .. sampleButtons, parent, "ActionButtonTemplate")
    if not ok or not b then return nil end
    b.commandName = "ACTIONBUTTON" .. slot
    b:EnableMouse(false)
    return b
end

-- icon: a texture, or nil for an empty slot (where Show Button Art shows). skin: Skin Action Bars'
-- border forced on or off (the option's own before / after preview), nil for the setting
function ActionBars.DrawSampleButton(b, icon, macro, skin)
    local db = GetBarConfig() or {}
    if icon then
        b.icon:SetTexture(icon)
        b.icon:SetDesaturated(false)
        b.icon:SetVertexColor(1, 1, 1)
        b.icon:Show()
    else
        b.icon:Hide()
    end
    if db.buttonArt then
        ApplyButtonArt(b)
    elseif not icon then
        -- an empty slot without the art: its border stays, the background goes
        if b.SlotArt then b.SlotArt:Hide() end
        if b.SlotBackground then b.SlotBackground:Hide() end
    end
    if b.NormalTexture then b.NormalTexture:SetAlpha(1) end
    if skin == nil then skin = db.flareBorders and true or false end
    SkinBorder(b, skin)
    if b.Name then b.Name:SetText(icon and macro or "") end
    UpdateButtonText(b)
    if b.Count then b.Count:SetText("") end
    b:Show()
    return b:GetSize()
end

--------------------------------------------------
-- 8. RANGE & STATUS COLORING
-- Post-hooks on UpdateUsable and ActionButton_UpdateRangeIndicator reuse the values Blizzard passed,
-- so nothing is polled; a repeated colour writes nothing.
--------------------------------------------------
-- range and mana also desaturate
local STATE_TINT = {
    normal   = { 1, 1, 1 },
    range    = { 1, 0.25, 0.25 },
    mana     = { 0.25, 0.25, 1 },
    unusable = { 0.5, 0.5, 0.5 },
}

-- what Blizzard's UpdateUsable paints (ActionButton.lua), for switching the colours off
local BLIZZARD_TINT = {
    mana     = { 0.5, 0.5, 1 },
    unusable = { 0.4, 0.4, 0.4 },
}

-- Dim on cooldown (section 8b) adds to the desaturation: button.FlareUI_OnCD is set while a real
-- cooldown runs
local function CooldownDims(button)
    if not button.FlareUI_OnCD then return false end
    local db = GetBarConfig()
    return db and db.enabled and db.dimOnCooldown or false
end

local function ApplyStateColor(button, state)
    if button.FlareUI_ColorState == state then return end
    button.FlareUI_ColorState = state

    local icon = button.icon
    if not icon then return end

    -- Blizzard desaturates level-linked actions itself; only its grey tint is undone
    if state == "locked" then
        icon:SetVertexColor(1, 1, 1, 1)
        return
    end

    local tint = STATE_TINT[state] or STATE_TINT.normal
    icon:SetVertexColor(tint[1], tint[2], tint[3], 1)

    local desaturate = state == "range" or state == "mana"
    if state == "unusable" then
        local db = GetBarConfig()
        desaturate = db and db.colors and db.colors.unusable and db.colors.unusable.desaturate or false
    end
    icon:SetDesaturated(desaturate or CooldownDims(button))
end

local OnUpdateUsable

local function RefreshButtonColor(button)
    local db = GetBarConfig()
    if not db or not db.colors or not db.colors.enableRange then
        -- switched off: Blizzard's own look until its next update
        if button.FlareUI_ColorState then
            if button.FlareUI_ColorState ~= "locked" and button.icon then
                local tint = BLIZZARD_TINT[button.FlareUI_Usable] or STATE_TINT.normal
                button.icon:SetVertexColor(tint[1], tint[2], tint[3], 1)
                button.icon:SetDesaturated(CooldownDims(button))
            end
            button.FlareUI_ColorState = nil
        end
        return
    end
    -- its usable state was skipped while the colours were off: read it now, as that update would have
    if button.FlareUI_UsableSkipped then
        button.FlareUI_UsableSkipped = nil
        OnUpdateUsable(button)
    end
    local usable = button.FlareUI_Usable or "normal"
    if usable == "normal" and button.FlareUI_OutOfRange then usable = "range" end
    ApplyStateColor(button, usable)
end

-- Blizzard has just rewritten the tint (and its Update the desaturation): a repeated state paints again
local function ForgetColorState(button)
    local db = GetBarConfig()
    if db and db.colors and db.colors.enableRange then button.FlareUI_ColorState = nil end
end

OnUpdateUsable = function(button, action, isUsable, notEnoughMana)
    local slot = button.action
    if not slot then return end   -- pet bar has its own path; stance buttons keep Blizzard's look
    -- colours off and nothing of ours left to undo: the state is only read once they're back on
    -- (RefreshButtonColor reads it then), so it isn't worked out on every Blizzard update meanwhile
    if not button.FlareUI_ColorState then
        local db = GetBarConfig()
        if not db or not db.colors or not db.colors.enableRange then
            button.FlareUI_UsableSkipped = true
            return
        end
    end
    button.FlareUI_UsableSkipped = nil
    if C_LevelLink.IsActionLocked(slot) then
        button.FlareUI_Usable = "locked"
    else
        if (canaccessvalue(isUsable) and isUsable == nil) or (canaccessvalue(notEnoughMana) and notEnoughMana == nil) then
            isUsable, notEnoughMana = C_ActionBar.IsUsableAction(slot)
        end
        -- an answer the client hides is left to Blizzard's own tint
        if not (canaccessvalue(isUsable) and canaccessvalue(notEnoughMana)) then
            button.FlareUI_ColorState = nil
            return
        end
        button.FlareUI_Usable = isUsable and "normal" or (notEnoughMana and "mana" or "unusable")
    end
    ForgetColorState(button)
    RefreshButtonColor(button)
end

-- A button's action changed (page, stance, form, a spell dragged in): Blizzard turns range checking
-- on for the new action but doesn't say whether it's in range until it next changes, so the old
-- answer would tint the new spell. Read it now.
local function OnUpdateAction(button)
    local slot = button.action
    if not (canaccessvalue(slot) and type(slot) == "number") then return end
    local out = false
    local has = C_ActionBar.HasAction(slot)
    if canaccessvalue(has) and has then
        local r = C_ActionBar.IsActionInRange(slot)
        out = (canaccessvalue(r) and r == false) or false
    end
    if out ~= button.FlareUI_OutOfRange then
        button.FlareUI_OutOfRange = out
        RefreshButtonColor(button)
    end
end

local function OnUpdateRangeIndicator(button, checksRange, inRange)
    if canaccessvalue(checksRange) and canaccessvalue(inRange) then
        button.FlareUI_OutOfRange = (checksRange and not inRange) or false
        RefreshButtonColor(button)
    end
    if button.HotKey then
        local db = GetBarConfig()
        if db and db.hideHotkeys then button.HotKey:Hide() end
    end
end

-- the pet bar has no per-button usable callback: refreshed whole when Blizzard updates it
local function UpdatePetColors()
    local db = GetBarConfig()
    if not db or not db.colors or not db.colors.enableRange then
        for _, button in ipairs(GetButtonsForBarKey("pet")) do RefreshButtonColor(button) end
        return
    end
    -- no pet bar and none on screen (Blizzard's Update has just hidden it, icons blank): nothing to
    -- colour. A pet coming runs Update again (UNIT_PET, PET_BAR_UPDATE) before the bar shows.
    local bar = _G.PetActionBar
    if not PetHasActionBar() and not (bar and bar:IsVisible()) then return end
    for index, button in ipairs(GetButtonsForBarKey("pet")) do
        local _, _, _, _, _, _, spellID, checksRange, inRange = GetPetActionInfo(index)
        local usable, notEnoughMana
        if spellID then
            usable, notEnoughMana = C_Spell.IsSpellUsable(spellID)
        else
            usable = GetPetActionSlotUsable(index)
        end
        if canaccessvalue(usable) and canaccessvalue(notEnoughMana) and canaccessvalue(checksRange) and canaccessvalue(inRange) then
            button.FlareUI_Usable = usable and "normal" or (notEnoughMana and "mana" or "unusable")
            button.FlareUI_OutOfRange = (checksRange and not inRange) or false
            ForgetColorState(button)
            RefreshButtonColor(button)
        end
    end
end

local function SetupRangeColors()
    if ActionBars.RangeHooked then return end
    ActionBars.RangeHooked = true
    if _G.ActionButton_UpdateRangeIndicator then
        ActionBars:SecureHook("ActionButton_UpdateRangeIndicator", OnUpdateRangeIndicator)
    end
    if _G.PetActionBar then
        ActionBars:SecureHook(_G.PetActionBar, "Update", UpdatePetColors)
    end
end

--------------------------------------------------
-- 8b. COOLDOWNS: DIM ON COOLDOWN, READY BURST
-- A real cooldown (not the global one) is read from isActive / isOnGCD, which are never secret, after
-- each of Blizzard's cooldown updates. Dim on cooldown greys the icon meanwhile; on Fake CM bars the end
-- of one plays the proc alert's opening burst. The game sends no event when a cooldown ends, so the
-- cooldown frame's OnCooldownDone reads it again.
--------------------------------------------------
local fcmButtons = {}        -- button -> on a Fake CM bar (Refresh)
local burstQuietUntil = 0    -- no bursts just after a loading screen: every cooldown is read anew
local GCD_SPAN = 1.5         -- a shorter arm span is a global cooldown read as a real one

local function BurstDone(anim) anim:GetParent():Hide() end

local function PlayBurst(button)
    local burst = button.FlareUI_ReadyBurst
    if not burst then
        burst = CreateFrame("Frame", nil, button, "ActionButtonSpellAlertTemplate")
        local w, h = button:GetSize()
        burst:SetSize(w * 1.4, h * 1.4)
        burst:SetPoint("CENTER", button, "CENTER", 0, 0)
        -- the start only: Blizzard's own script would carry on into the endless loop
        burst.ProcStartAnim:SetScript("OnFinished", BurstDone)
        button.FlareUI_ReadyBurst = burst
    end
    burst.ProcStartAnim:Stop()
    burst:Show()
    burst.ProcStartAnim:Play()
end

-- Greys or restores the icon after a change; with the colours painting, they repaint with it. Blizzard's
-- Update clears the desaturation, so a dimmed icon is greyed again on each pass.
local function PaintDim(button)
    local dim = CooldownDims(button)
    local changed = dim ~= (button.FlareUI_Dimmed or false)
    button.FlareUI_Dimmed = dim or nil
    if button.FlareUI_ColorState then
        if changed then
            button.FlareUI_ColorState = nil
            RefreshButtonColor(button)
        end
    elseif (dim or changed) and not C_LevelLink.IsActionLocked(button.action) then
        button.icon:SetDesaturated(dim)
    end
end

local function OnUpdateCooldown(button)
    local slot = button.action
    if not (button.icon and canaccessvalue(slot) and type(slot) == "number") then return end
    local db = GetBarConfig()
    local watch = db and db.enabled and (fcmButtons[button] or db.dimOnCooldown)
    if not watch and not button.FlareUI_OnCD then return end

    local onCD, id = false, nil
    local has = watch and C_ActionBar.HasAction(slot)
    if canaccessvalue(has) and has then
        local info = C_ActionBar.GetActionCooldown(slot)
        onCD = (info and info.isActive and not info.isOnGCD) or false
        local _, actionID = GetActionInfo(slot)
        id = canaccessvalue(actionID) and actionID or nil
    end
    -- a new action on the button (page, form, a spell dragged in) is no cooldown ending
    local same = id ~= nil and button.FlareUI_CDSlot == slot and button.FlareUI_CDID == id
    button.FlareUI_CDSlot, button.FlareUI_CDID = slot, id
    local armedAt, now = button.FlareUI_OnCD, GetTime()
    if onCD then
        if not (armedAt and same) then button.FlareUI_OnCD = now end
    elseif armedAt then
        button.FlareUI_OnCD = nil
        if same and fcmButtons[button] and now - armedAt >= GCD_SPAN and now >= burstQuietUntil then
            PlayBurst(button)
        end
    end
    PaintDim(button)
end

-- the cooldown frame reaches its end a moment before the client may report it over
local function OnCooldownDone(cooldown)
    local button = cooldown:GetParent()
    OnUpdateCooldown(button)
    if button.FlareUI_OnCD then C_Timer.After(0.1, function() OnUpdateCooldown(button) end) end
end

local function SetupCooldowns()
    if ActionBars.CooldownHooked then return end
    ActionBars.CooldownHooked = true
    if _G.ActionButton_UpdateCooldown then
        ActionBars:SecureHook("ActionButton_UpdateCooldown", OnUpdateCooldown)
    end
    for _, btn in ipairs(GetAllActionButtons()) do
        if btn.cooldown and btn.action then btn.cooldown:HookScript("OnCooldownDone", OnCooldownDone) end
    end
end

--------------------------------------------------
-- 9. ZONE ABILITY BUTTONS
--------------------------------------------------
local function StyleZoneAbilityButtonFonts(container)
    local db = GetBarConfig()
    local font = db and db.countFont
    if not (container and font) then return end
    for _, button in ipairs({ container:GetChildren() }) do
        local count = button:IsObjectType("Button") and button.Count
        if count then
            ns.SetFont(count, FontArgs(font))
            ns.ApplyShadow(count, font)
        end
    end
end

--------------------------------------------------
-- 10. FAKE COOLDOWN MANAGER (FCM) API
--------------------------------------------------
local function ApplyClickthroughToBar(key, enabled)
    -- a drop in combat leaves the bars clickable: the refresh after combat locks them again
    if InCombatLockdown() then
        ActionBars._pendingRefresh = true
        return false
    end
    for _, btn in ipairs(GetButtonsForBarKey(key)) do btn:EnableMouse(not enabled) end
    return true
end

local function ForEachFCMBar(fn)
    local fcm = ns.db.profile.fcm
    if not (fcm and ns.FCMActive()) then return end
    for i = 1, 8 do
        local barConfig = fcm.bars["bar" .. i]
        if barConfig and barConfig.enabled then fn("bar" .. i) end
    end
end

-- dragging something shows every faded bar and makes the FCM bars clickable (CURSOR_CHANGED)
local function OnCursorChanged()
    local isDragging = GetCursorInfo() ~= nil
    if isDragging == ActionBars.fcm.wasDragging then return end

    if isDragging then
        ActionBars.fcm.wasDragging = true
        ForEachFCMBar(function(key) ApplyClickthroughToBar(key, false) end)
        -- Visibility shows the bars while wasDragging (a check, not a rebuild: drags come in bursts)
        if ns.Visibility then ns.Visibility:Wake() end
    else
        ActionBars.fcm.wasDragging = false
        -- click-through again after a moment, unless Setup Mode is on
        ActionBars:ScheduleTimer(function()
            if ActionBars.fcm.wasDragging or ActionBars.fcm.unlockMode then return end
            ForEachFCMBar(function(key) ApplyClickthroughToBar(key, true) end)
            if ns.Visibility then ns.Visibility:Wake() end
        end, 0.2)
    end
end

-- Fake CM Setup Mode (session only): the FCM bars take clicks and show
function ns.ToggleFCMSetupMode()
    if InCombatLockdown() then
        print("|cffff0000FlareUI:|r " .. L["Cannot toggle setup mode in combat."])
        return
    end
    -- never with the module off (it must leave Blizzard's buttons alone) or no bar picked
    local db = GetBarConfig()
    if not (db and db.enabled and ns.FCMActive()) then return end
    local on = not ActionBars.fcm.unlockMode
    ActionBars:SetFCM_UnlockMode(on)
    print("|cff00ff00FlareUI:|r " .. (on and L["Fake CM setup mode on."] or L["Fake CM setup mode off."]))
end

function ActionBars:SetFCM_UnlockMode(enabled)
    if InCombatLockdown() then return false end
    self.fcm.unlockMode = enabled
    self:ApplyClickthrough(not enabled)
    if ns.Visibility then ns.Visibility:Refresh() end
    return true
end

function ActionBars:ApplyClickthrough(enabled)
    if InCombatLockdown() then return false end

    local db = GetBarConfig()
    if not db or not ns.db.profile.fcm then return false end

    ForEachFCMBar(function(key) ApplyClickthroughToBar(key, enabled) end)
    return true
end

function ActionBars:StartDragDetection()
    if not ns.db.profile.fcm then return false end
    if not self.fcm.dragWatching then
        self.fcm.dragWatching = true
        self:RegisterEvent("CURSOR_CHANGED", OnCursorChanged)
    end
    return true
end

--------------------------------------------------
-- 11. UPDATE SPELL RANKS
-- A newly learned rank replaces the best rank known below it on every bar; lower ranks placed on
-- purpose stay. Out of combat, with nothing on the cursor.
--------------------------------------------------
local MAX_ACTION_SLOT = 180
local pendingRanks = {}

local function RankOf(spellID)
    local subtext = C_Spell.GetSpellSubtext(spellID)
    return type(subtext) == "string" and tonumber(subtext:match("(%d+)")) or nil
end

-- The ranks the character knows of the spells just learned: name -> { rank -> spellID }. Low ranks
-- are spellbook items too (Blizzard's book only hides them); future spells aren't known yet.
-- learned = true reads every ranked spell in the book.
local function KnownRanks(learned)
    local known = {}
    local bank = Enum.SpellBookSpellBank.Player
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(line)
        -- another specialization's line holds spells the character can't cast now
        local count = (lineInfo and not lineInfo.offSpecID) and lineInfo.numSpellBookItems or 0
        for offset = 1, count do
            local info = C_SpellBook.GetSpellBookItemInfo(lineInfo.itemIndexOffset + offset, bank)
            local spellID = info and info.spellID
            local name = spellID and C_Spell.GetSpellName(spellID)
            if name and (learned == true or learned[name]) and C_SpellBook.IsSpellKnown(spellID, Enum.SpellBookSpellBank.Player) then
                local rank = RankOf(spellID)
                if rank then
                    known[name] = known[name] or {}
                    known[name][rank] = spellID
                end
            end
        end
    end
    return known
end

-- The rank a slot moves to: step up through the new ranks in order, while the slot holds the best
-- rank known below each one. A lower rank with a better one above it was put there on purpose.
local function TargetRank(rank, newRanks, known)
    -- the book should hold the slot's own rank; if not, only the rank just below counts
    local trusted = known[rank] ~= nil
    for _, newRank in ipairs(newRanks) do
        if newRank > rank then
            local below = newRank - 1
            if trusted then
                while below > rank and not known[below] do below = below - 1 end
            end
            if below == rank then rank = newRank end
        end
    end
    return rank
end

-- The top rank of each spell the character has had its bars brought up to: name -> rank, per character
local function TopRanks()
    local char = ns.CharDB()
    char.topRanks = char.topRanks or {}
    return char.topRanks
end

local FlushRanks
local cursorWait = CreateFrame("Frame")
cursorWait:SetScript("OnEvent", function(self)
    if GetCursorInfo() then return end
    self:UnregisterEvent("CURSOR_CHANGED")
    FlushRanks()
end)

local retried = {}   -- spellID -> true: a rank whose text wasn't loaded yet gets one more try
function FlushRanks()
    if InCombatLockdown() then return end   -- OnCombatEnd tries again
    -- with something on the cursor, wait until it's put down
    if GetCursorInfo() then cursorWait:RegisterEvent("CURSOR_CHANGED") return end
    -- Train All teaches several ranks in a row, in any order: all of a spell's go together
    local learned, again = {}, {}
    for _, spellID in ipairs(pendingRanks) do
        local name, rank = C_Spell.GetSpellName(spellID), RankOf(spellID)
        if name and rank then
            learned[name] = learned[name] or {}
            learned[name][rank] = spellID
        elseif not retried[spellID] then
            retried[spellID] = true
            again[#again + 1] = spellID
        end
    end
    wipe(pendingRanks)
    if #again > 0 then
        for _, spellID in ipairs(again) do pendingRanks[#pendingRanks + 1] = spellID end
        C_Timer.After(1, FlushRanks)
    end
    if not next(learned) then return end

    -- remembered, so the next catch-up scan doesn't take these ranks for new ones
    local tops = TopRanks()
    for name, ranks in pairs(learned) do
        for rank in pairs(ranks) do
            if rank > (tops[name] or 0) then tops[name] = rank end
        end
    end

    local known = KnownRanks(learned)
    local ordered = {}
    for name, ranks in pairs(learned) do
        known[name] = known[name] or {}
        local list = {}
        for rank, spellID in pairs(ranks) do
            known[name][rank] = spellID
            list[#list + 1] = rank
        end
        table.sort(list)
        ordered[name] = list
    end

    for slot = 1, MAX_ACTION_SLOT do
        local kind, id = GetActionInfo(slot)
        local name = kind == "spell" and id and C_Spell.GetSpellName(id)
        local rank = name and ordered[name] and RankOf(id)
        if rank then
            local target = TargetRank(rank, ordered[name], known[name])
            if target ~= rank then
                C_Spell.PickupSpell(known[name][target])
                -- with nothing picked up, placing would only empty the slot
                if GetCursorInfo() == "spell" then PlaceAction(slot) end
                ClearCursor()
            end
        end
    end
end

function ActionBars:OnSpellLearned(_, spellID)
    local db = GetBarConfig()
    if not (db and db.autoRanks and spellID) then return end
    pendingRanks[#pendingRanks + 1] = spellID
    C_Timer.After(0.2, FlushRanks)
end

-- Catch-up, at login and when the option is turned on: every rank above the top one the bars were
-- last brought up to counts as new, so ranks learned while the option was off move up too. A
-- character never scanned before has all its ranks moved up once.
function ActionBars:CatchUpRanks()
    local db = GetBarConfig()
    if not (db and db.enabled and db.autoRanks) then return end
    local tops = TopRanks()
    for name, ranks in pairs(KnownRanks(true)) do
        local top = tops[name] or 0
        for rank, spellID in pairs(ranks) do
            if rank > top then pendingRanks[#pendingRanks + 1] = spellID end
        end
    end
    if #pendingRanks > 0 then FlushRanks() end
end

-- the book is complete at the first SPELLS_CHANGED after login; a moment later the rank texts are too
local rankScan = CreateFrame("Frame")
rankScan:RegisterEvent("SPELLS_CHANGED")
rankScan:SetScript("OnEvent", function(self)
    self:UnregisterEvent("SPELLS_CHANGED")
    C_Timer.After(3, function() ActionBars:CatchUpRanks() end)
end)

--------------------------------------------------
-- 12. CLASS PAGING
-- A secure state driver sets "actionpage" on bar 1's buttons, which Blizzard's buttons read before their
-- bar's page; works in combat. Everything else on the bars is Blizzard's own paging.
-- Rogues and druids: Stealth and Prowl set no bonus bar of their own on Forever (GetBonusBarIndex
-- stays 0), so bar 1 doesn't page for them unless we do it. Warriors: stances do page bar 1; the toggle holds it on page 1, only while Blizzard
-- would swap it, so page keys and vehicle, override or temporary shapeshift bars stay Blizzard's.
--------------------------------------------------
local CLASS_PAGING = {
    -- Keep Page 1 in Stealth (11-11): Forever now pages bar 1 in Stealth itself, so the old Auto
    -- Paging for Stealth is turned round: the toggle holds page 1 while the game would swap it. Only
    -- while bar 1 shows page 1: Shift+number (or the page keys) still turn pages. [stealth] is
    -- Shadowmeld too; a rogue's stealth page is bonus bar 1 (held too, should it outlast Stealth).
    ROGUE = { key = "keepStealthPage", driver = "[possessbar][overridebar][vehicleui] default; [actionbar:1,stealth] 1; [actionbar:1,bonusbar:1] 1; default" },
    -- Druids: Prowl keeps Cat Form's page (7, Blizzard's), Shadowmeld in caster form page 1.
    -- offDriver (11-13, Marcus): Forever stopped paging Prowl (rogues' Stealth still pages), which was
    -- confusing, so with the toggle off FlareUI pages it itself: Prowl turns bar 1 to the prowl page
    -- (8, bonus bar 2, the page Forever used), only from page 1 (page keys still turn pages)
    DRUID = { key = "keepStealthPage", driver = "[possessbar][overridebar][vehicleui] default; [actionbar:1,stealth,form] 7; [actionbar:1,stealth] 1; default",
              offDriver = "[possessbar][overridebar][vehicleui] default; [actionbar:1,stealth,form] 8; default" },
    WARRIOR = { key = "noStancePaging", driver = "[possessbar][overridebar][vehicleui][shapeshift] default; [actionbar:1,bonusbar:1/2/3] 1; default" },
}
local PAGE_SNIPPET = [[
    local page = newstate ~= "default" and tonumber(newstate) or nil
    for i = 1, 12 do
        local button = self:GetFrameRef("b" .. i)
        if button then button:SetAttribute("actionpage", page) end
    end
]]
local classPager

-- out of combat (secure frames)
local function ApplyClassPaging()
    if InCombatLockdown() then
        ActionBars._pendingRefresh = true
        return
    end
    local db = GetBarConfig()
    if not db then return end
    -- an older single bar choice, carried over once: none turned Stealth paging off; none or another
    -- bar held stances
    if db.autoPagingBar ~= nil then
        if db.autoPagingBar == 0 then db.stealthPaging = false end
        if db.autoPagingBar ~= 1 then db.noStancePaging = true end
        db.autoPagingBar = nil
    end
    -- Auto Paging for Stealth turned off (bar 1 stayed put in stealth) becomes Keep Page 1 in
    -- Stealth on, now that the game pages it (11-11)
    if db.stealthPaging ~= nil then
        if db.stealthPaging == false then db.keepStealthPage = true end
        db.stealthPaging = nil
    end
    local _, class = UnitClass("player")
    local paging = CLASS_PAGING[class]
    if not paging then return end
    local on = db.enabled and db[paging.key]
    -- a class whose default is paged by FlareUI too (druids' Prowl): the pager runs either way
    local driver = on and paging.driver or (db.enabled and paging.offDriver) or nil
    if driver and not classPager then
        classPager = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
        for n, button in ipairs(GetButtonsForBarKey("bar1")) do classPager:SetFrameRef("b" .. n, button) end
        classPager:SetAttribute("_onstate-page", PAGE_SNIPPET)
    end
    -- off again: "default" hands the buttons back to their bar's own page
    if classPager then RegisterStateDriver(classPager, "page", driver or "default") end
end

-- The spellbook's "not on your bars" glow (11-11, a player's report): in a stance Blizzard counts the
-- stance's page as bar 1 and page 1 as hidden. While Keep Bar 1 in Stances holds page 1 it's the other
-- way round, so a spell put on bar 1 kept glowing and one left on the hidden stance page didn't. After
-- Blizzard's own answer each spell's glow is put right; Blizzard's functions are left alone (taint).
do
    local NOT_MISSING = 1
    -- the warrior toggle holding page 1 right now: the driver's own conditions
    local function HoldingPageOne()
        if not classPager then return false end
        local db = GetBarConfig()
        local _, class = UnitClass("player")
        if not (db and db.enabled and db.noStancePaging and class == "WARRIOR") then return false end
        if not C_ActionBar.HasBonusActionBar() or GetActionBarPage() ~= 1 then return false end
        return not (C_ActionBar.HasOverrideActionBar() or C_ActionBar.HasVehicleActionBar()
            or C_ActionBar.HasTempShapeshiftActionBar() or (HasPossessBar and HasPossessBar()))
    end
    -- on a bar you can see: page 1, or a shown extra bar (never the hidden stance page)
    local function OnShownBar(slots)
        for _, slot in ipairs(slots) do
            local page = math.floor((slot - 1) / 12) + 1
            if page == 1 then return true end
            local bar = MultiActionBar_GetBarForPage and MultiActionBar_GetBarForPage(page)
            if bar and bar:IsShown() then return true end
        end
        return false
    end
    local function FixGlow(item)
        if not (item.HasValidData and item:HasValidData() and item:IsShown()) then return end
        local anim = item.Button and item.Button.ActionBarHighlight and item.Button.ActionBarHighlight.Anim
        local info = item.spellBookItemInfo
        local spellID = info and (info.spellID or info.actionID)
        if not (anim and spellID and item.elementData and item.elementData.showActionBarStatus) then return end
        if item.spellGrabbed or item.inClickBindMode or not HoldingPageOne() then return end
        if C_Spell.IsSpellPassive(spellID) then return end
        local slots = C_ActionBar.FindSpellActionButtons(spellID, Enum.ActionBarSet.Mkb)
        if not slots then return end          -- on no bar: Blizzard's answer stands (stance buttons too)
        local missing = not OnShownBar(slots) and C_ActionBar.IsHighestSpellRank(spellID)
        if missing then
            if item.actionBarStatus == NOT_MISSING then item:UpdateSynchronizedAnimState(anim, true) end
        elseif anim:IsPlaying() then
            anim:Stop()
        end
    end
    EventUtil.ContinueOnAddOnLoaded("Blizzard_PlayerSpells", function()
        if SpellBookItemMixin and SpellBookItemMixin.UpdateActionBarAnim then
            hooksecurefunc(SpellBookItemMixin, "UpdateActionBarAnim", FixGlow)
        end
    end)
end

--------------------------------------------------
-- 13. PUBLIC API
--------------------------------------------------
-- button text draws at frame level 500: the end caps' container goes above it. Gryphons Behind
-- Bars puts it under every bar instead (the bars sit at level 50 and up in the same strata).
local GRYPHON_LEVEL_ABOVE = 501
local GRYPHON_LEVEL_BEHIND = 1
local function UpdateGryphonLayer(db)
    local caps = _G.MainActionBar and _G.MainActionBar.EndCaps
    if not caps or not caps.SetFrameLevel then return end
    if db and db.gryphonsBehind then
        caps:SetFrameLevel(GRYPHON_LEVEL_BEHIND)
    elseif caps:GetFrameLevel() < GRYPHON_LEVEL_ABOVE then
        caps:SetFrameLevel(GRYPHON_LEVEL_ABOVE)
    end
    -- bar 1's page number and arrows (level 100 in Blizzard's XML) stay above the gryphons, or the
    -- left one covers them; their arrow buttons go one higher
    local pager = _G.MainActionBar.ActionBarPageNumber
    if pager and pager.SetFrameLevel then
        local level = math.max(pager:GetFrameLevel(), caps:GetFrameLevel() + 1)
        pager:SetFrameLevel(level)
        for _, button in ipairs({ pager.UpButton, pager.DownButton }) do
            if button and button.SetFrameLevel then button:SetFrameLevel(level + 1) end
        end
    end
end

-- On Forever each gryphon is its own Edit Mode system, but the main bar's OnShow still runs
-- UpdateEndCaps(hideBarArt): with Hide Bar Art on, that would keep the container hidden after Alt+Z
-- or a cinematic. It is shown again with the bar; each gryphon keeps its own visibility.
local function KeepEndCapsWithBar(bar)
    local caps = bar and bar.EndCaps
    if not caps or caps:IsShown() or not bar:IsVisible() then return end
    -- Blizzard keeps them hidden in the Gamepad UI
    if ns.IsGamepadUI() then return end
    local faction = UnitFactionGroup("player")
    if not faction or faction == "Neutral" then return end
    if InCombatLockdown() and caps:IsProtected() then return end
    caps:Show()
end

local function HookEndCaps()
    local bar = _G.MainActionBar
    if not bar or bar.FlareUI_EndCapsHooked or type(bar.UpdateEndCaps) ~= "function" then return end
    if _G.MAIN_ACTION_BAR_MANAGE_END_CAPS ~= false then return end   -- Retail-style bars manage them
    bar.FlareUI_EndCapsHooked = true
    hooksecurefunc(bar, "UpdateEndCaps", KeepEndCapsWithBar)
    KeepEndCapsWithBar(bar)
end

-- switching the option off restores Blizzard's default once, then leaves the CVar to the player. The
-- mark is saved: the option or the whole module can go off across a reload (profile switch, module
-- switch), so this also runs at login with the module off.
local function UpdateAutoPushSpells(db)
    local global = ns.db.global
    if db and db.enabled and db.stopAutoAddSpells then
        -- written only when it differs (Refresh runs on every loading screen)
        if C_CVar.GetCVar("AutoPushSpellToActionBar") ~= "0" then C_CVar.SetCVar("AutoPushSpellToActionBar", "0") end
        global.autoPushSet = true
    elseif global.autoPushSet then
        C_CVar.SetCVar("AutoPushSpellToActionBar", "1")
        global.autoPushSet = nil
    end
    ActionBars.autoPushSet = global.autoPushSet
end

local autoPushLoader = CreateFrame("Frame")
autoPushLoader:RegisterEvent("PLAYER_LOGIN")
autoPushLoader:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    if not ns.db then return end
    UpdateAutoPushSpells(GetBarConfig())
    -- Reset wipes db.global too, the mark with it: undone now, from the copy kept above
    ns.db.RegisterCallback(ActionBars, "OnDatabaseReset", function()
        if ActionBars.autoPushSet then
            C_CVar.SetCVar("AutoPushSpellToActionBar", "1")
            ActionBars.autoPushSet = nil
        end
    end)
end)

function ActionBars:Refresh(event)
    if event == "PLAYER_ENTERING_WORLD" then burstQuietUntil = GetTime() + 3 end
    if InCombatLockdown() then
        self._pendingRefresh = true
        return
    end
    self._pendingRefresh = nil
    local db = GetBarConfig()
    if not db or not db.enabled then return end

    UpdateAutoPushSpells(db)
    ApplyClassPaging()

    UpdateGryphonLayer(db)
    if ActionBars.ApplyTotemScale then ActionBars.ApplyTotemScale() end   -- a profile's totem bar Size
    ActionBars.ApplyMenuBags()
    UpdateButtonArtAll()
    UpdateBordersAll()
    UpdateActiveAll()
    SetupRangeColors()
    SetupCooldowns()
    wipe(fcmButtons)
    ForEachFCMBar(function(key)
        for _, btn in ipairs(GetButtonsForBarKey(key)) do fcmButtons[btn] = true end
    end)

    if _G.ExtraActionButton1 then UpdateButtonText(_G.ExtraActionButton1) end
    if _G.ZoneAbilityFrame and _G.ZoneAbilityFrame.SpellButtonContainer then
        StyleZoneAbilityButtonFonts(_G.ZoneAbilityFrame.SpellButtonContainer)
    end

    local buttons = GetAllActionButtons()
    for _, btn in ipairs(buttons) do
        btn:SetScale(math.max(0.5, math.min(2, tonumber(db.buttonScale) or BUTTON_SCALE)))
        UpdateButtonText(btn)
        -- one-off repaint; the hooks keep it current
        OnUpdateUsable(btn)
        OnUpdateCooldown(btn)
    end
    UpdatePetColors()
    if ns.ProcGlow then ns.ProcGlow:Refresh() end

    -- FCM: click-through unless Setup Mode is on; drag detection for every faded bar
    if ns.db.profile.fcm then
        local fcm = ns.db.profile.fcm
        for i = 1, 8 do
            local bar = fcm.bars and fcm.bars["bar" .. i]
            if not (bar and bar.enabled) then ApplyClickthroughToBar("bar" .. i, false) end
        end
        if not ns.FCMActive() then self.fcm.unlockMode = false end
        self:ApplyClickthrough(not self.fcm.unlockMode)
        self:StartDragDetection()
    end
end

--------------------------------------------------
-- 13b. TOTEM BAR SIZE (11-11, a shaman asked)
-- Blizzard's Totem Bar has no Edit Mode settings, so no Size: FlareUI adds one to its dialog (Visibility.lua
-- puts it above Fading). 100% never touches the bar; its buttons are secure, so out of a fight only
-- (OnCombatEnd tries again).
--------------------------------------------------
local function ApplyTotemScale()
    local bar, db = _G.MultiCastActionBarFrame, GetBarConfig()
    if not (bar and db and db.enabled) then return end
    local scale = (db.totemScale or 100) / 100
    if scale == 1 and not bar.FlareUI_Scaled then return end
    if InCombatLockdown() then ActionBars._pendingTotemScale = true return end
    ActionBars._pendingTotemScale = nil
    bar:SetScale(scale)
    bar.FlareUI_Scaled = scale ~= 1 or nil
end
ActionBars.ApplyTotemScale = ApplyTotemScale

function ActionBars.TotemSizeSetting()
    local LEM = LibStub("FlareEditMode")
    return {
        name = L["Size"], kind = LEM.SettingType.Slider, default = 100, minValue = 50, maxValue = 200, valueStep = 5,
        formatter = function(value) return value .. "%" end,
        get = function() local db = GetBarConfig(); return db and db.totemScale or 100 end,
        set = function(_, value)
            local db = GetBarConfig()
            if not db then return end
            db.totemScale = value ~= 100 and value or nil
            ApplyTotemScale()
        end,
    }
end

function ActionBars:Init()
    local db = GetBarConfig()
    if not db or not db.enabled then return end

    self:Refresh()
    HookEndCaps()

    -- hooked per button: the mixin's functions are copied onto each frame
    for _, btn in ipairs(GetAllActionButtons()) do
        if not btn.FlareUI_ButtonHooked then
            btn.FlareUI_ButtonHooked = true
            if btn.UpdateHotkeys then ActionBars:SecureHook(btn, "UpdateHotkeys", UpdateHotkeyText) end
            -- (the pet bar's buttons set theirs in SetHotkeys: the range dot as on the others)
            if btn.SetHotkeys and not btn.UpdateHotkeys then ActionBars:SecureHook(btn, "SetHotkeys", ActionBars.PetRangeDot) end
            if btn.UpdateUsable then ActionBars:SecureHook(btn, "UpdateUsable", OnUpdateUsable) end
            if btn.UpdateAction then ActionBars:SecureHook(btn, "UpdateAction", OnUpdateAction) end
        end
    end

    -- the extra action button sets its hotkey when it appears
    local extraBtn = _G.ExtraActionButton1
    if extraBtn and extraBtn.UpdateHotkeys then
        ActionBars:SecureHook(extraBtn, "UpdateHotkeys", UpdateHotkeyText)
    end

    self:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED", "Refresh")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "Refresh")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEnd")
    self:RegisterEvent("UPDATE_EXTRA_ACTIONBAR", "OnExtraActionBarUpdate")
    self:RegisterEvent("UPDATE_BINDINGS", "OnExtraActionBarUpdate")
    self:RegisterEvent("LEARNED_SPELL_IN_SKILL_LINE", "OnSpellLearned")
end

--------------------------------------------------
-- 14. EVENT HANDLERS
--------------------------------------------------
function ActionBars:OnCombatEnd()
    if self._pendingRefresh then
        self:Refresh()
    end
    if #pendingRanks > 0 then FlushRanks() end
    if self._pendingTotemScale then ApplyTotemScale() end
end

-- after Blizzard's own hotkey update
function ActionBars:OnExtraActionBarUpdate()
    C_Timer.After(0, function()
        local db = GetBarConfig()
        if db and db.enabled and db.cleanKeybinds and _G.ExtraActionButton1 then
            UpdateHotkeyText(_G.ExtraActionButton1)
        end
    end)
end
