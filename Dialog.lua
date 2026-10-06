local _, ns = ...

--------------------------------------------------
-- FLAREUI DIALOG
-- FlareUI's yes / no questions, in place of StaticPopups. In the Gamepad UI a StaticPopup shown
-- from addon code hangs the client (the gamepad focus manager runs tainted), so this window reads
-- the pad itself: bottom face button yes, right face button no.
--
-- A dialog is a table in ns.Dialogs:
--   text           shown as written; "%s" takes the text argument of ns.ShowDialog
--   button1/2      the yes and no labels (button2 optional)
--   OnAccept(data, text)  on yes; text is the edit box's when hasEditBox
--   OnCancel(data)        on no (and Escape / right face button, when hideOnEscape)
--   hasEditBox, maxLetters, editText(data)   an edit box, its limit and starting text
--   hideOnEscape   Escape (and the right face button) answers no
--   showAlert      the exclamation mark beside the text
--   padInput       reads the controller outside the gamepad UI too (the switch to Gamepad mode)
--   reloads        yes reloads the UI after OnAccept (see Reloading below)
--   macro          like reloads, but the secure button runs this macro (or function(data) returning
--                  it) and its PreClick calls OnMacro; OnAccept stays the pad's and combat's answer
--   padSecure      with macro: the pad's yes / no are bound to the secure buttons, so a pad yes runs
--                  the macro too
--------------------------------------------------
ns.Dialogs = ns.Dialogs or {}

local WIDTH     = 360
local PADDING   = 18
local BUTTON_W  = 130
local BUTTON_H  = 24

local frame, current, currentData

local function PadLabel(key, label, padInput)
    -- in the gamepad UI a pad button's binding text is its glyph
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
-- ReloadUI is protected on Forever, so "yes" on a reloads dialog is a secure button running /reload
-- as a macro (PreClick runs OnAccept first). It is parented to UIParent, laid over the yes button,
-- so the dialog itself stays unprotected. In combat, yes falls back to the /reload hint.
--------------------------------------------------
local reloadButton, secureReload, accepted

local function GetReloadButton()
    if reloadButton then return reloadButton end
    reloadButton = CreateFrame("Button", "FlareUIDialogReload", UIParent, "SecureActionButtonTemplate, UIPanelButtonTemplate")
    reloadButton:SetSize(BUTTON_W, BUTTON_H)
    -- above the dialog's strata, or the toplevel dialog takes the click
    reloadButton:SetFrameStrata("TOOLTIP")
    -- a mouse click acts on release, a bound key on press
    reloadButton:RegisterForClicks("AnyUp", "AnyDown")
    reloadButton:SetAttribute("type", "macro")
    -- PreClick runs for both halves of a click, so OnAccept is guarded to run once
    reloadButton:SetScript("PreClick", function(self)
        if accepted or not current then return end
        accepted = true
        ns.reloading = (self:GetAttribute("macrotext") or ""):find("/reload", 1, true) ~= nil
        ns.ButtonSound()
        local onYes = current.macro and current.OnMacro or (not current.macro and current.OnAccept)
        if onYes then onYes(currentData) end
    end)
    -- a macro that does not reload leaves the UI up, so the dialog closes here
    reloadButton:SetScript("PostClick", function()
        if not (accepted and current and frame and frame:IsShown()) then return end
        current, currentData = nil, nil
        frame:Hide()
    end)
    reloadButton:Hide()
    return reloadButton
end

-- Hidden with the dialog, or after combat
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

-- Escape and Enter are taken; every other key goes on to its binding. Propagation cannot change in
-- combat, where the keys fall through and only the buttons work.
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
    -- keep Blizzard's gamepad cursor out: a pad click would run FlareUI code inside its navigation
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
    -- a name, so a controller binding can click "no" (padSecure)
    frame.PadNo = CreateFrame("Button", "FlareUIDialogPadNo", frame)
    frame.PadNo:SetScript("OnClick", function() Answer(false) end)

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
    local padSecure = def.padSecure and def.macro and not InCombatLockdown()
    frame:EnableGamePadButton(not padSecure and (ns.IsGamepadUI() or def.padInput == true))

    if def.hasEditBox then
        if def.maxLetters then frame.EditBox:SetMaxLetters(def.maxLetters) end
        frame.EditBox:SetText(def.editText and def.editText(data) or "")
    end
    ReleaseReloadButton()
    accepted = false
    if (def.reloads or def.macro) and not InCombatLockdown() then
        local macro = def.macro
        if type(macro) == "function" then macro = macro(data) end
        GetReloadButton():SetAttribute("macrotext", macro or "/reload")
        GetReloadButton():SetText(frame.Button1:GetText())
        secureReload = true
        SetOverrideBindingClick(frame, true, "ENTER", "FlareUIDialogReload", "LeftButton")
        if padSecure then
            SetOverrideBindingClick(frame, true, PAD_YES, "FlareUIDialogReload", "LeftButton")
            SetOverrideBindingClick(frame, true, PAD_NO, "FlareUIDialogPadNo", "LeftButton")
        end
    end
    frame:Show()
    frame:Raise()
    if secureReload then
        -- a protected frame cannot anchor to an insecure one: place it on UIParent at the yes button
        local x, y = frame.Button1:GetCenter()
        reloadButton:ClearAllPoints()
        if x and y then
            reloadButton:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
        else
            reloadButton:SetPoint("TOP", UIParent, "TOP", 0, -135 - frame:GetHeight() + BUTTON_H)
        end
        reloadButton:Show()
        frame.Button1:Hide()
    end
    if def.hasEditBox then
        frame.EditBox:SetFocus()
        frame.EditBox:HighlightText()
    end
end

-- Closes the dialog if it is showing key, without answering it
function ns.HideDialog(key)
    if frame and frame:IsShown() and current == ns.Dialogs[key] then Close() end
end

function ns.AnyDialogShown()
    return frame ~= nil and frame:IsShown()
end
