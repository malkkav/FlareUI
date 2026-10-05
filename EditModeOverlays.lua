local _, ns = ...
local L = ns.L

--------------------------------------------------
-- EDIT MODE OVERLAYS
-- A global FlareUI convenience (no module, no option): an eye button next to the HUD Edit Mode
-- close button toggles the blue selection boxes on EVERY Edit Mode frame - Blizzard systems and
-- any addon frame built on EditModeSystemSelectionTemplate (LibEditMode, EnhanceQoL...). Boxes
-- keep working while invisible: frames still drag and click. The choice persists per profile.
--------------------------------------------------
local EYE_TEXTURE      = "Interface\\LFGFrame\\LFG-Eye"
local EYE_FRAME_OPEN   = 0
local EYE_FRAME_CLOSED = 4
local EYE_FRAME_SIZE   = 64
local EYE_TEXTURE_W, EYE_TEXTURE_H = 512, 256

local eyeButton

local function IsHidden()
    return ns.db and ns.db.profile and ns.db.profile.editModeOverlaysHidden
end

local function SetEyeFrame(texture, index)
    local cols = EYE_TEXTURE_W / EYE_FRAME_SIZE
    local col, row = index % cols, math.floor(index / cols)
    texture:SetTexCoord(col * EYE_FRAME_SIZE / EYE_TEXTURE_W, (col + 1) * EYE_FRAME_SIZE / EYE_TEXTURE_W,
                        row * EYE_FRAME_SIZE / EYE_TEXTURE_H, (row + 1) * EYE_FRAME_SIZE / EYE_TEXTURE_H)
end

-- Every selection overlay in existence: Blizzard's registered systems plus anything else that
-- carries the selection mixin (addon frames registered with LibEditMode-style libraries)
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
    -- selections are (re)shown by Blizzard and the libraries as Edit Mode opens; apply after them
    C_Timer.After(0, ApplyOverlays)
end

local hooked = false
local function Hook()
    if hooked or not EditModeManagerFrame then return end
    hooked = true
    EditModeManagerFrame:HookScript("OnShow", OnEditModeShown)
    -- a system selected later can be re-shown by Blizzard code; keep it invisible
    hooksecurefunc(EditModeManagerFrame, "SelectSystem", function()
        if IsHidden() then C_Timer.After(0, ApplyOverlays) end
    end)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    Hook()
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then OnEditModeShown() end
end)
