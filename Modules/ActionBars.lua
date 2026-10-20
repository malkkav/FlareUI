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
        button.HotKey:SetFont(FontArgs(db.hotkeyFont))
        ns.ApplyShadow(button.HotKey, db.hotkeyFont)
        UpdateHotkeyText(button)
    end

    local count = button.Count
    if count then
        local font = db.countFont
        count:SetFont(FontArgs(font))
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
            name:SetFont(FontArgs(font))
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
        -- switched off: drop the desaturation (Blizzard rewrites the tint itself)
        if button.FlareUI_ColorState then
            if button.FlareUI_ColorState ~= "locked" and button.icon then button.icon:SetDesaturated(false) end
            button.FlareUI_ColorState = nil
        end
        return
    end
    local usable = button.FlareUI_Usable or "normal"
    if usable == "normal" and button.FlareUI_OutOfRange then usable = "range" end
    ApplyStateColor(button, usable)
end

local function OnUpdateUsable(button, action, isUsable, notEnoughMana)
    local slot = button.action
    if not slot then return end   -- pet bar has its own path; stance buttons keep Blizzard's look
    if C_LevelLink.IsActionLocked(slot) then
        button.FlareUI_Usable = "locked"
    else
        if isUsable == nil or notEnoughMana == nil then
            isUsable, notEnoughMana = C_ActionBar.IsUsableAction(slot)
        end
        -- a #showtooltip macro reports the macro's usability, not the spell's
        local actionType, id = GetActionInfo(slot)
        if actionType == "macro" then
            local name = GetMacroInfo(id)
            if name and name:sub(1, 1) == "#" then
                local spellID = GetMacroSpell(id)
                if spellID then isUsable, notEnoughMana = C_Spell.IsSpellUsable(spellID) end
            end
        end
        -- an answer the client hides is left to Blizzard's own tint
        if not (canaccessvalue(isUsable) and canaccessvalue(notEnoughMana)) then
            button.FlareUI_ColorState = nil
            return
        end
        button.FlareUI_Usable = isUsable and "normal" or (notEnoughMana and "mana" or "unusable")
    end
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
            count:SetFont(FontArgs(font))
            ns.ApplyShadow(count, font)
        end
    end
end

--------------------------------------------------
-- 10. FAKE COOLDOWN MANAGER (FCM) API
--------------------------------------------------
local function ApplyClickthroughToBar(key, enabled)
    if InCombatLockdown() then return false end
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

-- dragging something makes the FCM bars clickable (CURSOR_CHANGED, only while FCM bars exist)
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
    local fcm = ns.db.profile.fcm
    fcm.setupModeEnabled = not fcm.setupModeEnabled
    ActionBars:SetFCM_UnlockMode(fcm.setupModeEnabled)
    print("|cff00ff00FlareUI:|r " .. (fcm.setupModeEnabled and L["Fake CM setup mode on."] or L["Fake CM setup mode off."]))
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

function ActionBars:StopDragDetection()
    if self.fcm.dragWatching then
        self.fcm.dragWatching = nil
        self:UnregisterEvent("CURSOR_CHANGED")
    end
    self.fcm.wasDragging = false
end

--------------------------------------------------
-- 11. UPDATE SPELL RANKS
-- A newly learned rank replaces the rank just below it on every bar; older ranks placed on purpose
-- stay. Out of combat, with nothing on the cursor.
--------------------------------------------------
local MAX_ACTION_SLOT = 180
local pendingRanks = {}

local function RankOf(spellID)
    local subtext = C_Spell.GetSpellSubtext(spellID)
    return subtext and tonumber(subtext:match("(%d+)"))
end

local function UpgradeRank(newID)
    local name, rank = C_Spell.GetSpellName(newID), RankOf(newID)
    if not (name and rank and rank > 1) then return end
    for slot = 1, MAX_ACTION_SLOT do
        local kind, id = GetActionInfo(slot)
        if kind == "spell" and id and id ~= newID and C_Spell.GetSpellName(id) == name and RankOf(id) == rank - 1 then
            C_Spell.PickupSpell(newID)
            PlaceAction(slot)
            ClearCursor()
        end
    end
end

local function FlushRanks()
    if InCombatLockdown() then return end   -- OnCombatEnd tries again
    if GetCursorInfo() then C_Timer.After(1, FlushRanks) return end
    -- in the order learned: Train All teaches several ranks in a row
    for _, spellID in ipairs(pendingRanks) do UpgradeRank(spellID) end
    wipe(pendingRanks)
end

function ActionBars:OnSpellLearned(_, spellID)
    local db = GetBarConfig()
    if not (db and db.autoRanks and spellID) then return end
    pendingRanks[#pendingRanks + 1] = spellID
    C_Timer.After(0.2, FlushRanks)
end

--------------------------------------------------
-- 12. AUTO-PAGING
-- Forever never sets a bonus bar (GetBonusBarIndex stays 0 in Stealth or a form), so bar 1 never
-- pages. A secure state driver on the character's forms sets "actionpage" (Classic pages 7-10) on
-- the picked bar's buttons, which Blizzard's buttons read before their bar's page; works in combat.
--------------------------------------------------
-- a form -> its page, by Classic spell ID or, should Forever's differ, its icon
local FORM_PAGES = {
    { spells = { 768 },          icon = 132115, page = 7 },    -- Cat Form
    { spells = { 5487, 9634 },   icon = 132276, page = 9 },    -- Bear Form, Dire Bear Form
    { spells = { 24858 },        icon = 136036, page = 10 },   -- Moonkin Form
    { spells = { 2457 },         icon = 132349, page = 7 },    -- Battle Stance
    { spells = { 71 },           icon = 132341, page = 8 },    -- Defensive Stance
    { spells = { 2458 },         icon = 132275, page = 9 },    -- Berserker Stance
    { spells = { 15473 },        icon = 136200, page = 7 },    -- Shadowform
}
local PAGE_FIRST = "[possessbar][overridebar][vehicleui] default; [bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10"
local PAGE_SNIPPET = [[
    local page = newstate ~= "default" and tonumber(newstate) or nil
    for i = 1, 12 do
        local button = self:GetFrameRef("b" .. i)
        if button then button:SetAttribute("actionpage", page) end
    end
]]
local pagers = {}

local function FormPage(icon, spellID)
    for _, entry in ipairs(FORM_PAGES) do
        if icon and icon == entry.icon then return entry.page end
        for _, id in ipairs(entry.spells) do
            if spellID == id then return entry.page end
        end
    end
end

-- Stealth (rogues; a druid's Prowl is Cat Form's second page), then each form by its stance index
local function PagingDriver()
    local parts = { PAGE_FIRST }
    local _, class = UnitClass("player")
    if class == "ROGUE" then parts[#parts + 1] = "[stealth] 7" end
    for i = 1, GetNumShapeshiftForms() or 0 do
        local icon, _, _, spellID = GetShapeshiftFormInfo(i)
        local page = FormPage(icon, spellID)
        if page then
            if class == "DRUID" and page == 7 then parts[#parts + 1] = "[stance:" .. i .. ",stealth] 8" end
            parts[#parts + 1] = "[stance:" .. i .. "] " .. page
        end
    end
    parts[#parts + 1] = "default"
    return table.concat(parts, "; ")
end

-- the picked bar pages, the others keep their own page; out of combat (secure frames)
local function ApplyAutoPaging()
    if InCombatLockdown() then
        ActionBars._pendingRefresh = true
        return
    end
    local db = GetBarConfig()
    local picked = db and db.enabled and tonumber(db.autoPagingBar) or 0
    local driver = PagingDriver()
    for i = 1, 8 do
        local key = "bar" .. i
        local pager = pagers[key]
        if i == picked and not pager then
            pager = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
            for n, button in ipairs(GetButtonsForBarKey(key)) do pager:SetFrameRef("b" .. n, button) end
            pager:SetAttribute("_onstate-page", PAGE_SNIPPET)
            pagers[key] = pager
        end
        -- off again: "default" hands the buttons back to their bar's own page
        if pager then RegisterStateDriver(pager, "page", i == picked and driver or "default") end
    end
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

-- switching the option off restores Blizzard's default once, then leaves the CVar to the player
local function UpdateAutoPushSpells(db)
    if db.stopAutoAddSpells then
        C_CVar.SetCVar("AutoPushSpellToActionBar", "0")
        ActionBars.autoPushSet = true
    elseif ActionBars.autoPushSet then
        C_CVar.SetCVar("AutoPushSpellToActionBar", "1")
        ActionBars.autoPushSet = nil
    end
end

function ActionBars:Refresh()
    if InCombatLockdown() then
        self._pendingRefresh = true
        return
    end
    self._pendingRefresh = nil
    local db = GetBarConfig()
    if not db or not db.enabled then return end

    UpdateAutoPushSpells(db)
    ApplyAutoPaging()

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
        btn.FlareUI_ColorState = nil
        OnUpdateUsable(btn)
    end
    UpdatePetColors()
    if ns.ProcGlow then ns.ProcGlow:Refresh() end

    -- FCM: click-through unless Setup Mode is on; drag detection while any FCM bar exists
    if ns.db.profile.fcm then
        local fcm = ns.db.profile.fcm
        for i = 1, 8 do
            local bar = fcm.bars and fcm.bars["bar" .. i]
            if not (bar and bar.enabled) then ApplyClickthroughToBar("bar" .. i, false) end
        end
        if not ns.FCMActive() and self.fcm.unlockMode then
            fcm.setupModeEnabled = false
            self.fcm.unlockMode = false
        end
        self:ApplyClickthrough(not self.fcm.unlockMode)
        local hasFCMBars = false
        ForEachFCMBar(function() hasFCMBars = true end)
        if hasFCMBars then
            self:StartDragDetection()
        else
            self:StopDragDetection()
        end
    end
end

function ActionBars:Init()
    local db = GetBarConfig()
    if not db or not db.enabled then return end
    -- Setup Mode is for the session only
    if ns.db.profile.fcm then ns.db.profile.fcm.setupModeEnabled = false end

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

    self:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED", "OnLayoutUpdate")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnLayoutUpdate")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEnd")
    self:RegisterEvent("UPDATE_EXTRA_ACTIONBAR", "OnExtraActionBarUpdate")
    self:RegisterEvent("UPDATE_BINDINGS", "OnExtraActionBarUpdate")
    self:RegisterEvent("LEARNED_SPELL_IN_SKILL_LINE", "OnSpellLearned")
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORMS", "OnFormsChanged")
end

--------------------------------------------------
-- 14. EVENT HANDLERS
--------------------------------------------------
function ActionBars:OnLayoutUpdate()
    if not InCombatLockdown() then
        self:Refresh()
    end
end

function ActionBars:OnFormsChanged()
    ApplyAutoPaging()
end

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
