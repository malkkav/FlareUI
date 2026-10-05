local _, ns = ...

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

--------------------------------------------------
-- 3. CONSTANTS & DATA
--------------------------------------------------
local RANGE_INDICATOR = _G.RANGE_INDICATOR

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

local function GetButtonsForBarKey(key)
    local data
    for _, d in ipairs(BAR_DATA) do
        if d.key == key then data = d; break end
    end
    if not data then return {} end

    local buttons = {}
    local count = data.count or 12
    for i = 1, count do
        local btn = _G[data.prefix .. i]
        if btn then table_insert(buttons, btn) end
    end
    return buttons
end

local function GetAllActionButtons()
    local all = {}
    for _, data in ipairs(BAR_DATA) do
        local btns = GetButtonsForBarKey(data.key)
        for _, b in ipairs(btns) do table_insert(all, b) end
    end
    return all
end

--------------------------------------------------
-- 6. BUTTON ART (force Blizzard's slot art on every button)
--------------------------------------------------
-- Action buttons inherit ActionButtonTemplate, which carries SlotArt (the recessed slot with the
-- wings) and SlotBackground (the plain square). Blizzard's BaseActionButtonMixin:UpdateButtonArt()
-- picks one from the bar's hideBarArt flag; we post-hook it per button so our choice wins, including
-- after Edit Mode's "Hide Bar Art" runs it. Limited to bars 1-8 and the pet bar: the stance, possess
-- and totem buttons render the forced art badly and aren't worth the trouble.
local ART_BAR_KEYS = { bar1 = true, bar2 = true, bar3 = true, bar4 = true, bar5 = true, bar6 = true, bar7 = true, bar8 = true, pet = true }

local function GetAllArtButtons()
    local all = {}
    for _, data in ipairs(BAR_DATA) do
        if ART_BAR_KEYS[data.key] then
            for _, b in ipairs(GetButtonsForBarKey(data.key)) do table_insert(all, b) end
        end
    end
    return all
end

-- Remember how Blizzard left the button so disabling the option restores exactly that look
-- (Forever keeps bars 2-8 plain through logic we can't see, so re-running Blizzard's
-- UpdateButtonArt is not a reliable way back).
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

    -- read before our hook replaced UpdateButtonArt (UpdateButtonArtAll): after it the method is the
    -- hook wrapper and the comparison always failed, giving the pet bar's small buttons the big frame
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
-- 7. SCALING ENGINE
--------------------------------------------------
local function ApplyBarScale(key)
    local db = GetBarConfig()
    if not db then return end

    local scale = db.scales[key] or 1.0
    local buttons = GetButtonsForBarKey(key)
    for _, btn in ipairs(buttons) do btn:SetScale(scale) end
end

local function RefreshAllScales()
    for _, data in ipairs(BAR_DATA) do ApplyBarScale(data.key) end
end

--------------------------------------------------
-- 8. TYPOGRAPHY & TEXT
--------------------------------------------------
-- Blizzard puts an already-localised, already-abbreviated string in HotKey (GetBindingText(key, 1)),
-- so shortening that text again is guesswork: the rules differ per language and a clamp turns
-- "BUTTON4" into "BUT". Work from the raw binding key instead - GetBindingKey returns things like
-- "SHIFT-BUTTON4" or "NUMPAD1", always uppercase and never localised. The rules run in order, which
-- is why NUMPAD comes before PLUS and SPACEBAR before SPACE.
local KEY_SHORT = {
    { "ALT%-", "A" }, { "CTRL%-", "C" }, { "SHIFT%-", "S" }, { "META%-", "M" },
    { "NUMPAD", "N" },
    { "PLUS", "+" }, { "MINUS", "-" }, { "MULTIPLY", "*" }, { "DIVIDE", "/" },
    { "BACKSPACE", "BS" }, { "CAPSLOCK", "Cp" }, { "CLEAR", "Cl" }, { "DELETE", "Del" },
    { "MOUSEWHEELDOWN", "WD" }, { "MOUSEWHEELUP", "WU" },
    { "NUMLOCK", "NL" }, { "PAGEDOWN", "PD" }, { "PAGEUP", "PU" },
    { "SCROLLLOCK", "SL" }, { "SPACEBAR", "Sp" }, { "SPACE", "Sp" }, { "TAB", "Tb" },
    { "DOWNARROW", "Dn" }, { "LEFTARROW", "Lf" }, { "RIGHTARROW", "Rt" }, { "UPARROW", "Up" },
    { "INSERT", "Ins" }, { "HOME", "Hm" }, { "END", "En" },
}

local function ShortenKey(key)
    if not key or key == "" then return key end
    key = key:upper()
    key = key:gsub(" ", "")
    key = key:gsub("BUTTON(%d+)", "B%1")
    for _, rule in ipairs(KEY_SHORT) do
        key = key:gsub(rule[1], rule[2])
    end
    return key
end

-- bindingAction is what Blizzard's own UpdateHotkeys resolved; commandName is set by the bar when it
-- builds its buttons; the CLICK binding is the fallback Blizzard itself uses.
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

-- Hotkey text and anchor. Blizzard's UpdateHotkeys re-anchors the hotkey and rewrites its text on
-- every binding or gamepad change, so this runs after it; nothing else it touches needs repeating.
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
    -- when the option is off, leave Blizzard's own text alone
    if db.cleanKeybinds then hotkey:SetText(ShortenKey(key)) end
    hotkey:Show()
    local font = db.hotkeyFont
    hotkey:ClearAllPoints()
    hotkey:SetPoint("TOPRIGHT", button, "TOPRIGHT", font.x or 0, font.y or 0)
end

-- Fonts, count and macro-name placement. Blizzard sets none of these after the button is built, so
-- they are applied when the settings change rather than on every button update.
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
        count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", font.x or 0, font.y or 0)
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
            name:SetPoint("BOTTOM", button, "BOTTOM", font.x or 0, font.y or 0)
            ns.ApplyShadow(name, font)
        end
    end
end

--------------------------------------------------
-- 9. RANGE & STATUS COLORING
-- Blizzard already drives this from events: ACTION_USABLE_CHANGED lands in the button's UpdateUsable
-- and ACTION_RANGE_CHECK_UPDATE in ActionButton_UpdateRangeIndicator, and both are handed the values
-- the client just looked up. Post-hooking them and reusing those arguments means we never poll
-- IsUsableAction / IsActionInRange ourselves. Usable state and range state arrive separately, so each
-- is remembered on the button and the two are combined when either changes; the last colour applied
-- is remembered too, so a repeated update writes nothing.
--------------------------------------------------
local function ApplyStateColor(button, state)
    if button.FlareUI_ColorState == state then return end
    button.FlareUI_ColorState = state

    local icon = button.icon
    if not icon then return end

    -- Blizzard desaturates level-linked actions itself; only undo its grey tint and leave the rest
    if state == "locked" then
        icon:SetVertexColor(1, 1, 1, 1)
        return
    end

    local db = GetBarConfig()
    local color = db and db.colors and db.colors[state]
    if not color then
        icon:SetVertexColor(1, 1, 1, 1)
        icon:SetDesaturated(false)
        return
    end

    -- Use alpha to blend between tint color and white (neutral)
    -- This keeps the icon opaque while controlling tint intensity
    local alpha = color.a or 1
    icon:SetVertexColor((color.r or 1) * alpha + (1 - alpha),
                        (color.g or 1) * alpha + (1 - alpha),
                        (color.b or 1) * alpha + (1 - alpha), 1)

    -- Desaturate for out of range, out of mana, and unusable (if enabled)
    if state == "range" or state == "mana" then
        icon:SetDesaturated(true)
    elseif state == "unusable" and color.desaturate then
        icon:SetDesaturated(true)
    else
        icon:SetDesaturated(false)
    end
end

local function RefreshButtonColor(button)
    local db = GetBarConfig()
    if not db or not db.colors or not db.colors.enableRange then return end
    local usable = button.FlareUI_Usable or "normal"
    if usable == "normal" and button.FlareUI_OutOfRange then usable = "range" end
    ApplyStateColor(button, usable)
end

-- post-hook on the button's UpdateUsable; Blizzard passes what it just resolved
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
        button.FlareUI_Usable = isUsable and "normal" or (notEnoughMana and "mana" or "unusable")
    end
    RefreshButtonColor(button)
end

local function OnUpdateRangeIndicator(button, checksRange, inRange)
    button.FlareUI_OutOfRange = (checksRange and not inRange) or false
    RefreshButtonColor(button)
    if button.HotKey then
        local db = GetBarConfig()
        if db and db.hideHotkeys then button.HotKey:Hide() end
    end
end

-- The pet bar has no per-button usable callback, so it is refreshed as a whole when Blizzard updates
-- it. That is infrequent, and the per-button state cache keeps the writes down.
local function UpdatePetColors()
    local db = GetBarConfig()
    if not db or not db.colors or not db.colors.enableRange then return end
    for index, button in ipairs(GetButtonsForBarKey("pet")) do
        local _, _, _, _, _, _, spellID, checksRange, inRange = GetPetActionInfo(index)
        local usable, notEnoughMana
        if spellID then
            usable, notEnoughMana = C_Spell.IsSpellUsable(spellID)
        else
            usable = GetPetActionSlotUsable(index)
        end
        button.FlareUI_Usable = usable and "normal" or (notEnoughMana and "mana" or "unusable")
        button.FlareUI_OutOfRange = (checksRange and not inRange) or false
        RefreshButtonColor(button)
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
-- 10. ZONE ABILITY BUTTONS
--------------------------------------------------

local function StyleZoneAbilityButtonFonts(container)
    if not container then return end

    local db = GetBarConfig()
    if not db then return end

    for _, button in ipairs({ container:GetChildren() }) do
        if button and button:IsObjectType("Button") then
            -- Zone ability buttons have Count fontstrings
            local count = button.Count
            if count then
                local font = db.countFont
                if font then
                    local path = ns.GetFontPath(font.face)
                    local flags = (font.flags == "NONE" and "") or font.flags or "OUTLINE"

                    count:SetFont(path, font.size, flags)
                    ns.ApplyShadow(count, font)
                end
            end
        end
    end
end

--------------------------------------------------
-- 11. FAKE COOLDOWN MANAGER (FCM) API
--------------------------------------------------

-- Apply clickthrough to a single bar
local function ApplyClickthroughToBar(key, enabled)
    if InCombatLockdown() then return false end

    local buttons = GetButtonsForBarKey(key)
    if #buttons == 0 then return false end

    for _, btn in ipairs(buttons) do
        if btn and btn.EnableMouse then
            -- "stateful" was set here as well; it is not an attribute Blizzard reads anywhere, so it
            -- did nothing and is gone.
            btn:EnableMouse(not enabled)
        end
    end
    return true
end

local function ForEachFCMBar(fn)
    local fcm = ns.db.profile.fcm
    if not fcm then return end
    for _, data in ipairs(BAR_DATA) do
        if data.key:match("^bar[1-8]$") then
            local barConfig = fcm.bars[data.key]
            if barConfig and barConfig.enabled then fn(data.key) end
        end
    end
end

-- Drag detection was an OnUpdate polling GetCursorInfo ten times a second for as long as any FCM bar
-- was enabled. CURSOR_CHANGED reports the same transitions and costs nothing while idle.
local function OnCursorChanged()
    local isDragging = GetCursorInfo() ~= nil
    if isDragging == ActionBars.fcm.wasDragging then return end

    if isDragging then
        ActionBars.fcm.wasDragging = true
        ForEachFCMBar(function(key) ApplyClickthroughToBar(key, false) end)

        -- Trigger visibility refresh - CheckCondition will see wasDragging=true and show bars
        if ns.Visibility then ns.Visibility:Refresh() end
    else
        ActionBars.fcm.wasDragging = false
        -- Re-enable clickthrough after a short delay, and only when Setup Mode is OFF (it wins)
        ActionBars:ScheduleTimer(function()
            if ActionBars.fcm.wasDragging or ActionBars.fcm.unlockMode then return end
            ForEachFCMBar(function(key) ApplyClickthroughToBar(key, true) end)
            if ns.Visibility then ns.Visibility:Refresh() end
        end, 0.2)
    end
end

-- Public FCM Methods
function ActionBars:SetFCM_UnlockMode(enabled)
    if InCombatLockdown() then return false end
    self.fcm.unlockMode = enabled
    -- When Setup Mode is ON (enabled=true), DISABLE clickthrough (allow interaction)
    -- When Setup Mode is OFF (enabled=false), ENABLE clickthrough (bars become non-interactive)
    self:ApplyClickthrough(not enabled)

    -- Trigger visibility refresh to show/hide bars based on Setup Mode
    if ns.Visibility then
        ns.Visibility:Refresh()
    end

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
-- 11b. AUTO-PAGING
-- Blizzard switches bar 1 to another page in a stance or form: bonus bars 1-4 are action pages 7-10
-- (Cat Form, Bear Form, a warrior's stances, Stealth...). Here the player picks which of bars 1-8
-- does it (one bar: those four pages are the only stance pages there are). A bar that pages gets a secure state driver; its snippet sets "actionpage" on each of
-- the bar's buttons, which Blizzard's buttons read before their bar's own page
-- (SecureActionButtonMixin:CalculateAction) and update on (OnAttributeChanged). It all runs in the
-- restricted environment, in combat too, so Blizzard's buttons are never touched from our code.
-- Bar 1 with paging off keeps its own page (the paging arrows, Shift+number) and leaves Blizzard's
-- possess / override / vehicle pages to Blizzard. Switching a bar on or off waits for combat to end.
--------------------------------------------------
local PAGE_STANCES = "[bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10; default"
local PAGE_BAR1_FIXED = "[possessbar][overridebar][vehicleui][bonusbar:5] default; [bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6; 1"
local PAGE_SNIPPET = [[
    local page = newstate ~= "default" and tonumber(newstate) or nil
    for i = 1, 12 do
        local button = self:GetFrameRef("b" .. i)
        if button then button:SetAttribute("actionpage", page) end
    end
]]
local pagers = {}

local function ApplyAutoPaging()
    if InCombatLockdown() then
        ActionBars._pendingRefresh = true
        return
    end
    local db = GetBarConfig()
    local pagingBar = db and db.autoPagingBar or 1
    for i = 1, 8 do
        local key = "bar" .. i
        local paging = i == pagingBar
        local driver
        if i == 1 then
            if not paging then driver = PAGE_BAR1_FIXED end
        elseif paging then
            driver = PAGE_STANCES
        end
        local pager = pagers[key]
        if driver and not pager then
            pager = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
            for n, button in ipairs(GetButtonsForBarKey(key)) do pager:SetFrameRef("b" .. n, button) end
            pager:SetAttribute("_onstate-page", PAGE_SNIPPET)
            pagers[key] = pager
        end
        if pager then
            -- off again: the driver hands the buttons back to their bar's own page ("default")
            RegisterStateDriver(pager, "page", driver or "default")
        end
    end
end

--------------------------------------------------
-- 12. PUBLIC API
--------------------------------------------------

-- Hide/Show Cooldown Viewers (shared secure-hide helper, see Core.lua)
local HideFrameSecurely = ns.HideFrameSecurely

local function UpdateCooldownViewers()
    local fcm = ns.db.profile.fcm
    if not fcm then return end

    -- Utility Cooldown Viewer
    local utilityViewer = _G.UtilityCooldownViewer
    HideFrameSecurely(utilityViewer, fcm.hideUtilityCooldownViewer)

    -- Essential Cooldown Viewer
    local essentialViewer = _G.EssentialCooldownViewer
    HideFrameSecurely(essentialViewer, fcm.hideEssentialCooldownViewer)
end

-- Blizzard draws hotkey/count/macro text in each button's TextOverlayContainer at frame level 500.
-- Raising the end-cap container (MainActionBar.EndCaps) past 500 puts the art over the outer buttons
-- and their text. On Retail the caps are textures in that container; on Forever they are child
-- frames with useParentLevel (own Edit Mode systems), so they follow the container and ignore a
-- level set directly on them - always raise the container. It is a child of the secure bar, so this
-- only runs out of combat (Refresh guarantees that). The original level is remembered for undo.
local GRYPHON_LEVEL_ABOVE = 501
local function UpdateGryphonLayer()
    local db = GetBarConfig()
    local caps = _G.MainActionBar and _G.MainActionBar.EndCaps
    if not caps or not caps.SetFrameLevel then return end
    if caps.FlareUI_OrigLevel == nil then caps.FlareUI_OrigLevel = caps:GetFrameLevel() end
    local level = (db and db.gryphonsAboveButtons) and math.max(GRYPHON_LEVEL_ABOVE, caps.FlareUI_OrigLevel) or caps.FlareUI_OrigLevel
    if caps:GetFrameLevel() ~= level then caps:SetFrameLevel(level) end
end

-- Blizzard pushes newly learned spells onto the bars unless this CVar is off
local function UpdateAutoPushSpells(db)
    C_CVar.SetCVar("AutoPushSpellToActionBar", db.stopAutoAddSpells and "0" or "1")
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

    UpdateCooldownViewers()
    UpdateGryphonLayer()
    UpdateButtonArtAll()

    RefreshAllScales()
    SetupRangeColors()
    ApplyAutoPaging()

    -- Update Extra button (fonts + clean keybinds)
    if _G.ExtraActionButton1 then UpdateButtonText(_G.ExtraActionButton1) end

    -- Update Zone Ability button fonts
    if _G.ZoneAbilityFrame and _G.ZoneAbilityFrame.SpellButtonContainer then
        StyleZoneAbilityButtonFonts(_G.ZoneAbilityFrame.SpellButtonContainer)
    end

    local buttons = GetAllActionButtons()
    for _, btn in ipairs(buttons) do
        UpdateButtonText(btn)
        -- one-off repaint: after this the hooks keep the colour current
        btn.FlareUI_ColorState = nil
        OnUpdateUsable(btn)
    end
    UpdatePetColors()

    -- FCM Setup
    if ns.db.profile.fcm then
        -- Apply clickthrough when Setup Mode is OFF (not unlockMode)
        self:ApplyClickthrough(not self.fcm.unlockMode)

        -- Always start drag detection if any FCM bar is enabled
        local hasFCMBars = false
        for _, data in ipairs(BAR_DATA) do
            if data.key:match("^bar[1-8]$") then
                if ns.db.profile.fcm.bars[data.key].enabled then
                    hasFCMBars = true
                    break
                end
            end
        end

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

    self:Refresh()

    -- Hook each button rather than the mixin table. Blizzard applies ActionBarActionButtonMixin
    -- through CreateFromMixins + the template's mixin= attribute, both of which COPY the functions
    -- onto the frame, so a hook installed on the mixin table afterwards would never run. (The old
    -- code branched on "ActionBarActionMixin", which does not exist on Forever at all, and so always
    -- fell through to this path minus the Update hook.)
    for _, btn in ipairs(GetAllActionButtons()) do
        if not btn.FlareUI_ButtonHooked then
            btn.FlareUI_ButtonHooked = true
            if btn.UpdateHotkeys then ActionBars:SecureHook(btn, "UpdateHotkeys", UpdateHotkeyText) end
            if btn.UpdateUsable then ActionBars:SecureHook(btn, "UpdateUsable", OnUpdateUsable) end
        end
    end

    -- The extra action button has its own code path and sets its hotkey when it appears, so it gets
    -- the same hook plus a re-apply on UPDATE_EXTRA_ACTIONBAR / UPDATE_BINDINGS below.
    local extraBtn = _G.ExtraActionButton1
    if extraBtn and extraBtn.UpdateHotkeys then
        ActionBars:SecureHook(extraBtn, "UpdateHotkeys", UpdateHotkeyText)
    end

    self:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED", "OnLayoutUpdate")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnLayoutUpdate")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEnd")
    self:RegisterEvent("UPDATE_EXTRA_ACTIONBAR", "OnExtraActionBarUpdate")
    self:RegisterEvent("UPDATE_BINDINGS", "OnExtraActionBarUpdate")
end

--------------------------------------------------
-- 13. EVENT HANDLERS
--------------------------------------------------

-- Event: Edit mode layouts updated or player entering world
function ActionBars:OnLayoutUpdate()
    if not InCombatLockdown() then
        self:Refresh()
    end
end

-- Event: combat ended - run a refresh that was requested during combat
function ActionBars:OnCombatEnd()
    if self._pendingRefresh then
        self:Refresh()
    end
end

-- Event: Extra Action Bar updated (button appears in instances/combat) or bindings changed.
-- Defer so our clean keybind runs after Blizzard's secure hotkey update.
function ActionBars:OnExtraActionBarUpdate()
    C_Timer.After(0, function()
        local db = GetBarConfig()
        if db and db.enabled and db.cleanKeybinds and _G.ExtraActionButton1 then
            UpdateHotkeyText(_G.ExtraActionButton1)
        end
    end)
end
