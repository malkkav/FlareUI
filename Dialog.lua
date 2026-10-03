local _, ns = ...

--------------------------------------------------
-- FLAREUI DIALOG
-- FlareUI's own yes / no questions (reload, reset, sync, rename a chat window, unsaved radials), in
-- place of Blizzard's StaticPopups. With Forever's gamepad UI on, a StaticPopup shown from addon code
-- hands itself to Blizzard's gamepad focus manager inside the addon's tainted call
-- (StaticPopupGamepad.lua > FrameControlsManager:HandlePopupShown); the gamepad binding stack then
-- runs until "script ran too long" and the client hangs. This window never touches that system: it
-- reads the pad itself while it is up (bottom face button answers yes, right face button no), the
-- way it reads Enter and Escape from the keyboard.
--
-- A dialog is a table in ns.Dialogs, the StaticPopup fields FlareUI used:
--   text           shown as written; "%s" takes the text argument of ns.ShowDialog
--   button1/2      the yes and no labels (button2 optional)
--   OnAccept(data, text)  on yes; text is the edit box's when hasEditBox
--   OnCancel(data)        on no (and Escape / right face button, when hideOnEscape)
--   hasEditBox, maxLetters, editText(data)   an edit box, its limit and starting text
--   hideOnEscape   Escape (and the right face button) answers no
--   showAlert      the exclamation mark beside the text
--   padInput       reads the controller outside the gamepad UI too (the switch to Gamepad mode)
--   reloads        yes reloads the UI after OnAccept (see Reloading below)
--   macro          like reloads, but the secure button runs this macro instead of /reload, and its
--                  PreClick calls OnMacro (not OnAccept, which stays the pad's and combat's answer)
--------------------------------------------------
ns.Dialogs = ns.Dialogs or {}

local WIDTH     = 360
local PADDING   = 18
local BUTTON_W  = 130
local BUTTON_H  = 24

local frame, current, currentData

local function PadLabel(key, label, padInput)
    -- in the gamepad UI the binding text of a pad button is its glyph (A, Cross...), as on the bars
    if not (ns.IsGamepadUI() or padInput) then return label end
    local glyph = GetBindingText(key, 1)
    if not glyph or glyph == "" or glyph == key then return label end
    return glyph .. " " .. label
end

local function Close()
    if frame then frame:Hide() end
end

local function Answer(yes)
    local def, data = current, currentData
    if not def then return Close() end
    local text = def.hasEditBox and frame.EditBox:GetText() or nil
    current, currentData = nil, nil
    Close()
    ns.ButtonSound()
    if yes then
        if def.reloads then ns.reloading = true end
        if def.OnAccept then def.OnAccept(data, text) end
        if def.reloads then ns.Reload() end
    elseif def.OnCancel then
        def.OnCancel(data)
    end
end

--------------------------------------------------
-- Reloading
-- ReloadUI is protected on Forever: from a click it is blocked ("Interface action failed because of
-- an AddOn") and ns.Reload can only print its /reload hint. So a dialog with reloads = true answers
-- yes with a secure button that runs Blizzard's own /reload as a macro: its PreClick (ours) runs
-- OnAccept first, then the macro reloads in Blizzard's secure path. Enter is bound to it while the
-- dialog is up; the pad's yes button keeps Answer, which reloads. Being protected, the button is
-- parented to UIParent - a protected child would make the dialog protected and unshowable in combat
-- - laid over the yes button, and only used out of combat; in combat yes falls back to the hint.
--------------------------------------------------
local reloadButton, secureReload, accepted

local function GetReloadButton()
    if reloadButton then return reloadButton end
    reloadButton = CreateFrame("Button", "FlareUIDialogReload", UIParent, "SecureActionButtonTemplate, UIPanelButtonTemplate")
    reloadButton:SetSize(BUTTON_W, BUTTON_H)
    -- one strata above the dialog: in the same one the toplevel dialog drew over it and took the click
    reloadButton:SetFrameStrata("TOOLTIP")
    -- a mouse click acts on release, a bound key on press (ActionButtonUseKeyDown); the other half
    -- of each pair is ignored by the template
    reloadButton:RegisterForClicks("AnyUp", "AnyDown")
    reloadButton:SetAttribute("type", "macro")
    -- PreClick runs for both halves of a click, so OnAccept is guarded to run once
    reloadButton:SetScript("PreClick", function()
        if accepted or not current then return end
        accepted = true
        ns.reloading = true
        ns.ButtonSound()
        local onYes = current.macro and current.OnMacro or (not current.macro and current.OnAccept)
        if onYes then onYes(currentData) end
    end)
    reloadButton:Hide()
    return reloadButton
end

-- hidden with the dialog; a protected frame cannot be hidden in combat, so then after it
local releaseWaiter
local function ReleaseReloadButton()
    if not secureReload then return end
    if InCombatLockdown() then
        if not releaseWaiter then
            releaseWaiter = CreateFrame("Frame")
            releaseWaiter:SetScript("OnEvent", function(waiter)
                waiter:UnregisterEvent("PLAYER_REGEN_ENABLED")
                if not (frame and frame:IsShown()) then ReleaseReloadButton() end
            end)
        end
        releaseWaiter:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    secureReload = false
    reloadButton:Hide()
    ClearOverrideBindings(frame)
end

-- Escape and Enter are taken; every other key goes on to its binding, so the player can still move.
-- Propagation cannot change in combat, and none of these dialogs open in combat; the keys then fall
-- through, and the buttons still work.
local function OnKeyDown(self, key)
    -- with the secure reload button up, Enter goes on to its override binding
    local handled = (key == "ESCAPE" and current and current.hideOnEscape) or (key == "ENTER" and not secureReload)
    if not InCombatLockdown() then self:SetPropagateKeyboardInput(not handled) end
    if key == "ESCAPE" and handled then
        Answer(false)
    elseif key == "ENTER" and handled then
        Answer(true)
    end
end

local PAD_YES = GAMEPAD_FACE_BOTTOM or "PAD1"
local PAD_NO  = GAMEPAD_FACE_RIGHT or "PAD2"

local function OnGamePadButtonDown(self, button)
    local yes = button == PAD_YES
    -- the right face button answers no wherever there is a no to give: it wears B's glyph on it
    local no = button == PAD_NO and current and (current.hideOnEscape or current.button2)
    if not InCombatLockdown() then self:SetPropagateKeyboardInput(not (yes or no)) end
    if yes then
        Answer(true)
    elseif no then
        Answer(false)
    end
end

local function CreateDialogButton(parent, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(BUTTON_W, BUTTON_H)
    button:SetScript("OnClick", onClick)
    return button
end

local function Build()
    frame = CreateFrame("Frame", "FlareUIDialog", UIParent, "BackdropTemplate")
    frame:SetWidth(WIDTH)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -135)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    frame:SetBackdropBorderColor(ns.BORDER_COLOR.r, ns.BORDER_COLOR.g, ns.BORDER_COLOR.b, 1)
    frame:Hide()
    -- Blizzard's gamepad cursor must not walk into it: a pad click would run FlareUI code inside
    -- Blizzard's navigation, the trap this window exists to avoid. The pad is read directly instead.
    frame.smartNavigationIgnored = true

    frame.Alert = frame:CreateTexture(nil, "ARTWORK")
    frame.Alert:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")   -- StaticPopup's own
    frame.Alert:SetSize(32, 32)
    frame.Alert:SetPoint("TOPLEFT", PADDING, -PADDING + 4)

    frame.Text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    frame.Text:SetJustifyH("CENTER")
    frame.Text:SetSpacing(2)

    frame.EditBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.EditBox:SetSize(WIDTH - 2 * PADDING - 10, 22)
    frame.EditBox:SetAutoFocus(false)
    frame.EditBox:SetScript("OnEnterPressed", function() Answer(true) end)
    frame.EditBox:SetScript("OnEscapePressed", function() Answer(false) end)

    frame.Button1 = CreateDialogButton(frame, function() Answer(true) end)
    frame.Button2 = CreateDialogButton(frame, function() Answer(false) end)

    frame:SetScript("OnKeyDown", OnKeyDown)
    frame:SetScript("OnGamePadButtonDown", OnGamePadButtonDown)
    frame:SetScript("OnShow", function() ns.WindowOpenSound() end)
    frame:SetScript("OnHide", function(self)
        self.EditBox:ClearFocus()
        ReleaseReloadButton()
        if current then
            -- hidden from outside (ns.HideDialog): no answer, no callback
            current, currentData = nil, nil
        end
    end)
end

local function Layout(def, text)
    local textWidth = WIDTH - 2 * PADDING
    frame.Alert:SetShown(def.showAlert and true or false)
    if def.showAlert then textWidth = textWidth - 40 end
    frame.Text:ClearAllPoints()
    frame.Text:SetPoint("TOP", frame, "TOP", def.showAlert and 20 or 0, -PADDING)
    frame.Text:SetWidth(textWidth)
    frame.Text:SetText(text)

    local below = frame.Text
    local height = PADDING + frame.Text:GetStringHeight()
    if def.hasEditBox then
        frame.EditBox:ClearAllPoints()
        frame.EditBox:SetPoint("TOP", frame.Text, "BOTTOM", 0, -12)
        frame.EditBox:Show()
        below = frame.EditBox
        height = height + 12 + frame.EditBox:GetHeight()
    else
        frame.EditBox:Hide()
    end

    frame.Button1:SetText(PadLabel(PAD_YES, def.button1 or "Okay", def.padInput))
    frame.Button1:Show()
    frame.Button1:ClearAllPoints()
    if def.button2 then
        frame.Button2:SetText(PadLabel(PAD_NO, def.button2, def.padInput))
        frame.Button2:Show()
        frame.Button1:SetPoint("TOPRIGHT", below, "BOTTOM", -6, -16)
        frame.Button2:ClearAllPoints()
        frame.Button2:SetPoint("TOPLEFT", below, "BOTTOM", 6, -16)
    else
        frame.Button2:Hide()
        frame.Button1:SetPoint("TOP", below, "BOTTOM", 0, -16)
    end
    frame:SetHeight(height + 16 + BUTTON_H + PADDING)
end

-- key: the ns.Dialogs entry; textArg fills "%s"; data is handed to OnAccept / OnCancel
function ns.ShowDialog(key, textArg, data)
    local def = ns.Dialogs[key]
    if not def then return end
    if not frame then Build() end
    current, currentData = def, data
    local text = def.text or ""
    if textArg ~= nil then text = text:format(textArg) end
    Layout(def, text)

    frame:EnableKeyboard(true)
    if not InCombatLockdown() then frame:SetPropagateKeyboardInput(true) end
    frame:EnableGamePadButton(ns.IsGamepadUI() or def.padInput == true)

    if def.hasEditBox then
        if def.maxLetters then frame.EditBox:SetMaxLetters(def.maxLetters) end
        frame.EditBox:SetText(def.editText and def.editText(data) or "")
    end
    ReleaseReloadButton()
    accepted = false
    if (def.reloads or def.macro) and not InCombatLockdown() then
        GetReloadButton():SetAttribute("macrotext", def.macro or "/reload")
        GetReloadButton():SetText(frame.Button1:GetText())
        secureReload = true
        SetOverrideBindingClick(frame, true, "ENTER", "FlareUIDialogReload", "LeftButton")
    end
    frame:Show()
    frame:Raise()
    if secureReload then
        -- a protected frame cannot be anchored to an insecure one, so it goes on UIParent at the
        -- yes button's position (both share UIParent's scale)
        local x, y = frame.Button1:GetCenter()
        reloadButton:ClearAllPoints()
        if x and y then
            reloadButton:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
        else
            reloadButton:SetPoint("TOP", UIParent, "TOP", 0, -135 - frame:GetHeight() + BUTTON_H)
        end
        reloadButton:Show()
        -- the secure button stands in for it; nothing else may take the click
        frame.Button1:Hide()
    end
    if def.hasEditBox then
        frame.EditBox:SetFocus()
        frame.EditBox:HighlightText()
    end
end

-- closes the dialog if it is showing key, without answering it
function ns.HideDialog(key)
    if frame and frame:IsShown() and current == ns.Dialogs[key] then Close() end
end

function ns.AnyDialogShown()
    return frame ~= nil and frame:IsShown()
end

function ns.IsDialogShown(key)
    return frame ~= nil and frame:IsShown() and current == ns.Dialogs[key]
end
