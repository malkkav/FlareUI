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
local GetMacroInfo = GetMacroInfo
local GetMacroSpell = GetMacroSpell
local GetPetActionInfo = GetPetActionInfo
local GetPetActionSlotUsable = GetPetActionSlotUsable
local C_Spell = C_Spell
local C_Timer = C_Timer
local canaccessvalue = canaccessvalue

--------------------------------------------------
-- 3. CONSTANTS & DATA
--------------------------------------------------
local RANGE_INDICATOR = _G.RANGE_INDICATOR
local BUTTON_SCALE = 1.06

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
    button.FlareUI_ArtOrig = {
        slotArt = button.SlotArt:IsShown(), slotBg = button.SlotBackground:IsShown(),
        normalAtlas = button.NormalTexture:GetAtlas(), normalLayer = button.NormalTexture:GetDrawLayer(), nw = nw, nh = nh,
        pushedAtlas = button.PushedTexture:GetAtlas(), pushedLayer = button.PushedTexture:GetDrawLayer(), pw = pw, ph = ph,
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
    if small then w, h = 35, 35 end
    button:SetNormalAtlas("UI-HUD-ActionBar-IconFrame")
    button.NormalTexture:SetDrawLayer("OVERLAY")
    button.NormalTexture:SetSize(w, h)
    button:SetPushedAtlas("UI-HUD-ActionBar-IconFrame-Down")
    button.PushedTexture:SetDrawLayer("OVERLAY")
    button.PushedTexture:SetSize(w, h)
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
    -- off: Blizzard's own text, so switching off needs no reload
    if db.cleanKeybinds then hotkey:SetText(ShortenKey(key)) else hotkey:SetText(GetBindingText(key, 1)) end
    hotkey:Show()
    hotkey:ClearAllPoints()
    hotkey:SetPoint("TOPRIGHT", button, "TOPRIGHT", HOTKEY_X, HOTKEY_Y)
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
    icon:SetDesaturated(desaturate)
end

local function RefreshButtonColor(button)
    local db = GetBarConfig()
    if not db or not db.colors or not db.colors.enableRange then
        -- switched off: Blizzard's own look until its next update
        if button.FlareUI_ColorState then
            if button.FlareUI_ColorState ~= "locked" and button.icon then
                local tint = BLIZZARD_TINT[button.FlareUI_Usable] or STATE_TINT.normal
                button.icon:SetVertexColor(tint[1], tint[2], tint[3], 1)
                button.icon:SetDesaturated(false)
            end
            button.FlareUI_ColorState = nil
        end
        return
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

local function OnUpdateUsable(button, action, isUsable, notEnoughMana)
    local slot = button.action
    if not slot then return end   -- pet bar has its own path; stance buttons keep Blizzard's look
    if C_LevelLink.IsActionLocked(slot) then
        button.FlareUI_Usable = "locked"
    else
        if (canaccessvalue(isUsable) and isUsable == nil) or (canaccessvalue(notEnoughMana) and notEnoughMana == nil) then
            isUsable, notEnoughMana = C_ActionBar.IsUsableAction(slot)
        end
        -- a #showtooltip macro reports the macro's usability, not the spell's
        local actionType, id = GetActionInfo(slot)
        if actionType == "macro" then
            local _, _, body = GetMacroInfo(id)
            if body and body:sub(1, 1) == "#" then
                local spellID = GetMacroSpell(id)
                if canaccessvalue(spellID) and spellID then isUsable, notEnoughMana = C_Spell.IsSpellUsable(spellID) end
            end
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
        -- Visibility shows the bars while wasDragging
        if ns.Visibility then ns.Visibility:Refresh() end
    else
        ActionBars.fcm.wasDragging = false
        -- click-through again after a moment, unless Setup Mode is on
        ActionBars:ScheduleTimer(function()
            if ActionBars.fcm.wasDragging or ActionBars.fcm.unlockMode then return end
            ForEachFCMBar(function(key) ApplyClickthroughToBar(key, true) end)
            if ns.Visibility then ns.Visibility:Refresh() end
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
local function KnownRanks(learned)
    local known = {}
    local bank = Enum.SpellBookSpellBank.Player
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(line)
        for offset = 1, lineInfo and lineInfo.numSpellBookItems or 0 do
            local info = C_SpellBook.GetSpellBookItemInfo(lineInfo.itemIndexOffset + offset, bank)
            local spellID = info and info.spellID
            local name = spellID and C_Spell.GetSpellName(spellID)
            if name and learned[name] and IsPlayerSpell(spellID) then
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

local function FlushRanks()
    if InCombatLockdown() then return end   -- OnCombatEnd tries again
    if GetCursorInfo() then C_Timer.After(1, FlushRanks) return end
    -- Train All teaches several ranks in a row, in any order: all of a spell's go together
    local learned = {}
    for _, spellID in ipairs(pendingRanks) do
        local name, rank = C_Spell.GetSpellName(spellID), RankOf(spellID)
        if name and rank then
            learned[name] = learned[name] or {}
            learned[name][rank] = spellID
        end
    end
    wipe(pendingRanks)
    if not next(learned) then return end

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

--------------------------------------------------
-- 12. CLASS PAGING
-- A secure state driver sets "actionpage" on bar 1's buttons, which Blizzard's buttons read before their
-- bar's page; works in combat. Everything else on the bars is Blizzard's own paging.
-- Rogues: Stealth sets no bonus bar on Forever (GetBonusBarIndex stays 0), so bar 1 doesn't page for it
-- unless we do it. Warriors: stances do page bar 1; the toggle holds it on page 1, only while Blizzard
-- would swap it, so page keys and vehicle, override or temporary shapeshift bars stay Blizzard's.
--------------------------------------------------
local CLASS_PAGING = {
    ROGUE = { key = "stealthPaging", driver = "[possessbar][overridebar][vehicleui] default; [stealth] 7; default" },
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
    -- the 3.0 bar choice these toggles replaced: none turned Stealth paging off; none or another bar held stances
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
-- button text draws at frame level 500: the end caps' container goes above it
local GRYPHON_LEVEL_ABOVE = 501
local function UpdateGryphonLayer()
    local caps = _G.MainActionBar and _G.MainActionBar.EndCaps
    if not caps or not caps.SetFrameLevel then return end
    if caps:GetFrameLevel() < GRYPHON_LEVEL_ABOVE then caps:SetFrameLevel(GRYPHON_LEVEL_ABOVE) end
end

-- On Forever each gryphon is its own Edit Mode system, but the main bar's OnShow still runs
-- UpdateEndCaps(hideBarArt): with Hide Bar Art on, the container stayed hidden after Alt+Z or a
-- cinematic. Shown again with the bar; each gryphon keeps its own visibility.
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
        C_CVar.SetCVar("AutoPushSpellToActionBar", "0")
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

function ActionBars:Refresh()
    if InCombatLockdown() then
        self._pendingRefresh = true
        return
    end
    self._pendingRefresh = nil
    local db = GetBarConfig()
    if not db or not db.enabled then return end

    UpdateAutoPushSpells(db)
    ApplyClassPaging()

    UpdateGryphonLayer()
    UpdateButtonArtAll()
    SetupRangeColors()

    if _G.ExtraActionButton1 then UpdateButtonText(_G.ExtraActionButton1) end
    if _G.ZoneAbilityFrame and _G.ZoneAbilityFrame.SpellButtonContainer then
        StyleZoneAbilityButtonFonts(_G.ZoneAbilityFrame.SpellButtonContainer)
    end

    local buttons = GetAllActionButtons()
    for _, btn in ipairs(buttons) do
        btn:SetScale(BUTTON_SCALE)
        UpdateButtonText(btn)
        -- one-off repaint; the hooks keep it current
        OnUpdateUsable(btn)
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
