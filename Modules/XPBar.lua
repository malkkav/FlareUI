local _, ns = ...

--------------------------------------------------
-- 1. MODULE REGISTRATION
-- Reskins Blizzard's two status tracking bars (Edit Mode "Status Tracking Bar 1 / 2") in the FlareUI
-- look: a flat fill in one colour per bar type, a dark track, Blizzard's tooltip border in bronze and
-- the action bar font. Blizzard still decides which bars show (XP, reputation, honor) and where they
-- sit, so they are placed in Edit Mode as before. Lives under the Action Bars module: it loads with
-- it, and its switch sits in Action Bars > General > "XP / Honor Bars".
-- Only widget calls and post-hooks: none of Blizzard's bar code ever runs from ours, and nothing is
-- written onto Blizzard's frames.
--------------------------------------------------
ns.XPBar = ns.XPBar or {}
local XPB = ns.XPBar
ns.modules["XPBar"] = XPB

--------------------------------------------------
-- 2. UPVALUES
--------------------------------------------------
local _G = _G
local ipairs, pairs = ipairs, pairs
local CreateFrame = CreateFrame
local LSM = LibStub("LibSharedMedia-3.0")

--------------------------------------------------
-- 3. CONSTANTS
--------------------------------------------------
local TEXTURE_NAME  = "Flat"
local BORDER_NAME   = "FlareUI Thin"
local BORDER_SIZE   = 16
local BORDER_OUTSET = 4                            -- the border sits this far outside the fill
local BORDER_COLOR  = { 0.80, 0.60, 0.34 }         -- #CC9957
local TRACK_COLOR   = { 0.15, 0.15, 0.15, 0.9 }
local RESTED_ALPHA  = 0.4

-- Inside a container a bar sits at BOTTOMLEFT (1, 2), sized container - 3 (StatusTrackingBarContainer
-- InitializeBars, STATUS_BAR_SIZE_ADJUSTMENT = 3), so its edges are these far in from the container's.
local FILL_LEFT, FILL_RIGHT, FILL_TOP, FILL_BOTTOM = 1, 2, 1, 2

-- Blizzard picks a fill atlas per bar and state; each one maps to one of Blizzard's own colours.
-- Atlases not listed here keep Blizzard's art.
local COLOR_XP     = { 0.58, 0.00, 0.55 }          -- #94008C, Blizzard's XP purple
local COLOR_RESTED = { 0.00, 0.39, 0.88 }          -- #0063E0, Blizzard's rested blue
local FIXED_COLORS = {
    ["UI-HUD-ExperienceBar-Fill-Experience"]              = COLOR_XP,
    ["UI-HUD-ExperienceBar-Fill-Rested"]                  = COLOR_RESTED,
    ["UI-HUD-ExperienceBar-Fill-Reputation-Faction-Blue"] = COLOR_RESTED,
}
-- the standing colours behind FACTION_BAR_COLORS, looked up by name when a bar is coloured
local STANDING_COLORS = {
    ["UI-HUD-ExperienceBar-Fill-Reputation-Faction-Red"]    = "FACTION_RED_COLOR",
    ["UI-HUD-ExperienceBar-Fill-Reputation-Faction-Orange"] = "FACTION_ORANGE_COLOR",
    ["UI-HUD-ExperienceBar-Fill-Reputation-Faction-Yellow"] = "FACTION_YELLOW_COLOR",
    ["UI-HUD-ExperienceBar-Fill-Reputation-Faction-Green"]  = "FACTION_GREEN_COLOR",
}
local HONOR_ATLAS = "UI-HUD-ExperienceBar-Fill-Honor"

--------------------------------------------------
-- 4. HELPERS
--------------------------------------------------
local function GetDb()
    local ab = ns.db and ns.db.profile and ns.db.profile.actionbars
    return ab and ab.xpbar
end

local function GetTexture()
    return LSM:Fetch("statusbar", TEXTURE_NAME) or "Interface\\Buttons\\WHITE8x8"
end

-- r, g, b for a fill atlas, or nothing to leave Blizzard's art in place
local function ColorForAtlas(atlas)
    local fixed = FIXED_COLORS[atlas]
    if fixed then return fixed[1], fixed[2], fixed[3] end
    local color
    if atlas == HONOR_ATLAS then
        local faction = UnitFactionGroup("player")
        color = (faction == "Alliance" and PLAYER_FACTION_COLOR_ALLIANCE) or (faction == "Horde" and PLAYER_FACTION_COLOR_HORDE)
    else
        color = STANDING_COLORS[atlas] and _G[STANDING_COLORS[atlas]]
    end
    if color then return color:GetRGB() end
end

local function ApplyFont(fontString)
    local fontDb = ns.db and ns.db.profile.actionbars and ns.db.profile.actionbars.hotkeyFont
    local flags = fontDb and fontDb.flags or "OUTLINE"
    if flags == "NONE" then flags = "" end
    fontString:SetFont(ns.GetFontPath(fontDb and fontDb.face or "Friz Quadrata TT"), fontDb and fontDb.size or 12, flags)
    ns.ApplyShadow(fontString, fontDb)
end

--------------------------------------------------
-- 5. SKIN
--------------------------------------------------
-- The flat fill replaces whichever atlas Blizzard just set. A texture deferred until the next level
-- comes back through SetBarTexture once the animation ends, and is handled then.
local function ApplyFill(statusBar, atlas)
    local r, g, b = ColorForAtlas(atlas)
    if not r then return end
    statusBar:SetStatusBarTexture(GetTexture())
    statusBar:GetStatusBarTexture():SetDrawLayer("BORDER")   -- where GradualAnimatedStatusBar keeps it
    statusBar:SetStatusBarColor(r, g, b, 1)
end

local function OnSetBarTexture(statusBar, atlas, deferUntilNextLevel)
    if deferUntilNextLevel then return end
    ApplyFill(statusBar, atlas)
end

local function SkinBar(bar)
    local statusBar = bar.StatusBar
    if not statusBar then return end
    local texture = GetTexture()

    -- whatever Blizzard set before we got here, then everything it sets from now on
    local current = statusBar:GetStatusBarTexture()
    ApplyFill(statusBar, current and current:GetAtlas())
    hooksecurefunc(statusBar, "SetBarTexture", OnSetBarTexture)

    if statusBar.Background then
        statusBar.Background:SetTexture(texture)
        statusBar.Background:SetVertexColor(TRACK_COLOR[1], TRACK_COLOR[2], TRACK_COLOR[3], TRACK_COLOR[4])
    end
    -- the rested XP still to come, drawn after the fill (the XP bar only)
    local rested = bar.ExhaustionLevelFillBar or statusBar.ExhaustionLevelFillBar
    if rested then
        rested:SetTexture(texture)
        rested:SetVertexColor(COLOR_RESTED[1], COLOR_RESTED[2], COLOR_RESTED[3], RESTED_ALPHA)
    end
    if bar.OverlayFrame and bar.OverlayFrame.Text then ApplyFont(bar.OverlayFrame.Text) end
end

-- the divider pool is refilled on every layout change (gamepad switch, resize)
local function HideDividers(container)
    local pool = container.HorizontalDividersPool
    if not pool then return end
    for divider in pool:EnumerateActive() do divider:Hide() end
end

-- Blizzard's frame art (on Forever a grey bevel with clipped corners) came back at full alpha some
-- time after a single SetAlpha(0) - one of the container's animations, as no code touches it - and
-- showed inside our border. It is hidden for good: hidden, at alpha 0, and put back if anything
-- shows it or lifts its alpha.
local function KeepHidden(texture)
    texture:SetAlpha(0)
    texture:Hide()
    hooksecurefunc(texture, "Show", function(t) t:Hide() end)
    hooksecurefunc(texture, "SetAlpha", function(t, alpha) if alpha ~= 0 then t:SetAlpha(0) end end)
end

local function SkinContainer(container)
    if container.BarFrameTexture then KeepHidden(container.BarFrameTexture) end
    HideDividers(container)
    hooksecurefunc(container, "UpdateDividers", HideDividers)

    local border = CreateFrame("Frame", nil, container, "BackdropTemplate")
    border:SetPoint("TOPLEFT", container, "TOPLEFT", FILL_LEFT - BORDER_OUTSET, BORDER_OUTSET - FILL_TOP)
    border:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", BORDER_OUTSET - FILL_RIGHT, FILL_BOTTOM - BORDER_OUTSET)
    border:SetFrameLevel(container:GetFrameLevel() + 20)
    border:SetBackdrop({ edgeFile = LSM:Fetch("border", BORDER_NAME), edgeSize = BORDER_SIZE })
    border:SetBackdropBorderColor(BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3], 1)

    for _, bar in pairs(container.bars or {}) do SkinBar(bar) end
end

--------------------------------------------------
-- 6. PUBLIC
--------------------------------------------------
function XPB:ShouldLoad()
    local ab = ns.db and ns.db.profile and ns.db.profile.actionbars
    return ab and ab.enabled and ab.xpbar and ab.xpbar.enabled or false
end

function XPB:Init()
    if self.initialized or not GetDb() then return end
    self.initialized = true
    for _, name in ipairs({ "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }) do
        local container = _G[name]
        if container then SkinContainer(container) end
    end
end
