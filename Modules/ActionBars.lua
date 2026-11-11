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
local BUTTON_SCALE = 1.06   -- Bar Scale's default (actionbars.buttonScale)

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
local FLARE_BORDER_OUT, FLARE_BORDER_EDGE = 0, 12

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

local function UpdateBordersAll()
    local db = GetBarConfig()
    local on = db and db.enabled and db.flareBorders or false
    for _, button in ipairs(GetAllActionButtons()) do
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

local function FontArgs(font)
    return ns.GetFontPath(font.face), font.size, (font.flags == "NONE" and "") or font.flags or "OUTLINE"
end

-- after Blizzard's UpdateHotkeys, which rewrites text and anchor
local function UpdateHotkeyText(button)
    local hotkey = button and button.HotKey
    if not hotkey then return end
    local db = GetBarConfig()
    if not db then return end

    if db.hideHotkeys then
        hotkey:Hide()
        return
    end
    local key = GetBindingKeyForButton(button)
    if not key or key == "" then
        hotkey:SetText(RANGE_INDICATOR)
        hotkey:Hide()
        return
    end
    -- off: Blizzard's own text, so switching off needs no reload; a controller button keeps
    -- Blizzard's icon either way
    local pad = IsBindingForGamePad and IsBindingForGamePad(key)
    if db.cleanKeybinds and not pad then hotkey:SetText(ShortenKey(key)) else hotkey:SetText(GetBindingText(key, 1)) end
    hotkey:Show()
    hotkey:ClearAllPoints()
    hotkey:SetPoint("TOPRIGHT", button, "TOPRIGHT", HOTKEY_X, HOTKEY_Y)
    -- Blizzard's box fits its own small font: the button's width and the text's own height, so a
    -- larger keybind font isn't cut off
    hotkey:SetSize(math.max(1, button:GetWidth() - 2), 0)
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

-- icon: a texture, or nil for an empty slot (where Show Button Art shows)
function ActionBars.DrawSampleButton(b, icon, macro)
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
    -- only while bar 1 shows page 1: Shift+number (or the page keys) still turn pages in stealth
    ROGUE = { key = "stealthPaging", driver = "[possessbar][overridebar][vehicleui] default; [actionbar:1,stealth] 7; default" },
    -- Druids: Prowl (Cat Form) gets page 8, Classic's prowl page, which is free (Blizzard pages Cat
    -- Form itself to 7). [stealth] is Shadowmeld too, as for rogues.
    DRUID = { key = "stealthPaging", driver = "[possessbar][overridebar][vehicleui] default; [actionbar:1,stealth] 8; default" },
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
    local _, class = UnitClass("player")
    local paging = CLASS_PAGING[class]
    if not paging then return end
    local on = db.enabled and db[paging.key]
    if on and not classPager then
        classPager = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
        for n, button in ipairs(GetButtonsForBarKey("bar1")) do classPager:SetFrameRef("b" .. n, button) end
        classPager:SetAttribute("_onstate-page", PAGE_SNIPPET)
    end
    -- off again: "default" hands the buttons back to their bar's own page
    if classPager then RegisterStateDriver(classPager, "page", on and paging.driver or "default") end
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
    UpdateButtonArtAll()
    UpdateBordersAll()
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
