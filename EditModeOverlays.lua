local _, ns = ...
local L = ns.L

--------------------------------------------------
-- EDIT MODE OVERLAYS
-- An eye button beside Edit Mode's close button hides the selection boxes of every Edit Mode frame
-- (alpha 0: they still drag and click). Saved per profile.
--------------------------------------------------
local EYE_TEXTURE      = "Interface\\LFGFrame\\LFG-Eye"
local EYE_FRAME_OPEN   = 0
local EYE_FRAME_CLOSED = 4
local EYE_FRAME_SIZE   = 64
local EYE_TEXTURE_W, EYE_TEXTURE_H = 512, 256

local eyeButton
local LEM = LibStub("FlareEditMode")

--------------------------------------------------
-- HIDING OUR FRAMES IN EDIT MODE
-- A frame can be hidden for a reason while editing (Blizzard's checkbox for it is off): it goes
-- invisible and so does its selection box, which then cannot be clicked, until no reason is left. A
-- frame never hidden is never touched (its own alpha stays its module's).
--------------------------------------------------
local hiddenFor = {}   -- frame -> { reason = true }

function ns.EditModeHide(frame, reason, hide)
    if not frame then return end
    local reasons = hiddenFor[frame]
    if not hide and not (reasons and reasons[reason]) then return end
    reasons = reasons or {}
    hiddenFor[frame] = reasons
    reasons[reason] = hide and true or nil
    local off = next(reasons) ~= nil
    frame:SetAlpha(off and 0 or 1)
    local selection = LEM.frameSelections and LEM.frameSelections[frame]
    if not selection then return end
    if not selection.FlareUI_HideHooked then
        selection.FlareUI_HideHooked = true
        hooksecurefunc(selection, "Show", function(s) if s.FlareUI_Hidden then s:Hide() end end)
    end
    selection.FlareUI_Hidden = off
    if off then
        selection:Hide()
    elseif LEM:IsInEditMode() then
        selection:Show()
    end
end

-- Edit Mode's Frames checkboxes show and hide Blizzard's frames, which FlareUI keeps hidden; they
-- show and hide FlareUI's own in their place (in Edit Mode only)
local SWITCHES = {
    { setter = "SetTargetAndFocusShown", setting = "ShowTargetAndFocus",
      frames = { "FlareUI_UF_Target", "FlareUI_UF_Focus", "FlareUI_UF_TargetOfTarget", "FlareUI_UF_TargetOfFocus" } },
    { setter = "SetPartyFramesShown", setting = "ShowPartyFrames", frames = { "FlareUI_Party" } },
    { setter = "SetRaidFramesShown", setting = "ShowRaidFrames", frames = { "FlareUI_Raid", "FlareUI_RaidTanks" } },
    { setter = "SetBossFramesShown", setting = "ShowBossFrames", frames = { "FlareUI_Boss" } },
    { setter = "SetPetFrameShown", setting = "ShowPetFrame", frames = { "FlareUI_UF_Pet" } },
    { setter = "SetCastBarShown", setting = "ShowCastBar", frames = { "FlareUI_UF_PlayerCastBar" } },
    { setter = "SetBuffsAndDebuffsShown", setting = "ShowBuffsAndDebuffs", frames = { "FlareUI_Buffs", "FlareUI_Debuffs" } },
}

local function ApplySwitch(switch)
    local manager = EditModeManagerFrame
    local enum = Enum.EditModeAccountSetting and Enum.EditModeAccountSetting[switch.setting]
    if not (manager and enum) then return end
    local ok, shown = pcall(manager.GetAccountSettingValueBool, manager, enum)
    local off = LEM:IsInEditMode() and ok and shown == false or false
    for _, name in ipairs(switch.frames) do ns.EditModeHide(_G[name], "blizzard", off) end
end

local function ApplySwitches()
    for _, switch in ipairs(SWITCHES) do ApplySwitch(switch) end
end

local function IsHidden()
    return ns.db and ns.db.profile and ns.db.profile.editModeOverlaysHidden
end

local function SetEyeFrame(texture, index)
    local cols = EYE_TEXTURE_W / EYE_FRAME_SIZE
    local col, row = index % cols, math.floor(index / cols)
    texture:SetTexCoord(col * EYE_FRAME_SIZE / EYE_TEXTURE_W, (col + 1) * EYE_FRAME_SIZE / EYE_TEXTURE_W,
                        row * EYE_FRAME_SIZE / EYE_TEXTURE_H, (row + 1) * EYE_FRAME_SIZE / EYE_TEXTURE_H)
end

-- Every selection overlay: Blizzard's systems plus addon frames with the selection mixin
local function ForEachSelection(fn)
    local seen = {}
    local manager = EditModeManagerFrame
    if manager and manager.registeredSystemFrames then
        for _, system in ipairs(manager.registeredSystemFrames) do
            local selection = system.Selection
            if selection and not seen[selection] then
                seen[selection] = true
                fn(selection)
            end
        end
    end
    local frame = EnumerateFrames()
    while frame do
        if not seen[frame] and frame.ShowHighlighted and frame.ShowSelected and frame.MouseOverHighlight and frame.parent then
            seen[frame] = true
            fn(frame)
        end
        frame = EnumerateFrames(frame)
    end
end

local function ApplyOverlays()
    local alpha = IsHidden() and 0 or 1
    ForEachSelection(function(selection) selection:SetAlpha(alpha) end)
end

local function UpdateEye()
    if not eyeButton then return end
    local hidden = IsHidden()
    SetEyeFrame(eyeButton:GetNormalTexture(), hidden and EYE_FRAME_CLOSED or EYE_FRAME_OPEN)
end

function ns.ToggleEditModeOverlays(state)
    if not ns.db or not ns.db.profile then return end
    if state == nil then state = not ns.db.profile.editModeOverlaysHidden end
    ns.db.profile.editModeOverlaysHidden = state and true or false
    ApplyOverlays()
    UpdateEye()
end

local function CreateEye()
    if eyeButton or not EditModeManagerFrame then return end
    eyeButton = CreateFrame("Button", "FlareUI_EditModeEye", EditModeManagerFrame)
    eyeButton:SetSize(28, 28)
    eyeButton:SetFrameLevel(EditModeManagerFrame:GetFrameLevel() + 10)
    local close = EditModeManagerFrame.CloseButton
    if close then
        eyeButton:SetPoint("RIGHT", close, "LEFT", -2, 0)
    else
        eyeButton:SetPoint("TOPRIGHT", EditModeManagerFrame, "TOPRIGHT", -40, -6)
    end
    eyeButton:SetNormalTexture(EYE_TEXTURE)
    eyeButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    eyeButton:SetScript("OnClick", function() ns.ToggleEditModeOverlays() end)
    eyeButton:SetScript("OnEnter", function(self)
        ns.OwnGameTooltip(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Toggle Edit Mode Overlays"])
        GameTooltip:Show()
    end)
    eyeButton:SetScript("OnLeave", GameTooltip_Hide)
    UpdateEye()
end

local function OnEditModeShown()
    CreateEye()
    UpdateEye()
    -- after Blizzard and the libraries show their selections; shown is every frame's own state
    if IsHidden() then C_Timer.After(0, ApplyOverlays) end
end

local hooked = false
local function Hook()
    if hooked or not EditModeManagerFrame then return end
    hooked = true
    EditModeManagerFrame:HookScript("OnShow", OnEditModeShown)
    -- a selected system can be re-shown by Blizzard; keep it invisible
    hooksecurefunc(EditModeManagerFrame, "SelectSystem", function()
        if IsHidden() then C_Timer.After(0, ApplyOverlays) end
    end)
    -- the Frames checkboxes (a click, or Blizzard setting them as Edit Mode opens)
    local account = EditModeManagerFrame.AccountSettings
    for _, switch in ipairs(SWITCHES) do
        if account and type(account[switch.setter]) == "function" then
            hooksecurefunc(account, switch.setter, function() ApplySwitch(switch) end)
        end
    end
    -- after the modules have shown their frames for Edit Mode; leaving it shows them all again
    LEM:RegisterCallback("enter", function() C_Timer.After(0, ApplySwitches) end)
    LEM:RegisterCallback("exit", ApplySwitches)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    Hook()
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then OnEditModeShown() end
end)
