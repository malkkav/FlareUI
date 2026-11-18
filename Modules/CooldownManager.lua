local _, ns = ...

--------------------------------------------------
-- COOLDOWN MANAGER
-- Blizzard's Cooldown Manager in FlareUI's look. The Tracked Bars as FlareUI's cast bars (the unit
-- frames' bar texture, a thin bronze border), their icons as FlareUI's buffs, the Essential / Utility /
-- Tracked Buffs icons with the action buttons' FlareUI Borders, all with the Fonts tab's fonts. Blizzard
-- keeps driving its own pooled frames; it sets only values, text and the spark after a frame is made, so
-- each one is styled once as it is acquired. Its aura data is kept from addons
-- (CooldownViewerSecure.lua): nothing here reads it, re-parents its frames or calls their layout.
-- FlareUI's pieces live in a weak table. The viewers' fading is Visibility.lua's (cdm_ keys).
--------------------------------------------------
ns.CooldownManager = ns.CooldownManager or {}
local CM = ns.CooldownManager
ns.modules["CooldownManager"] = CM

local _G = _G
local pairs, ipairs = pairs, ipairs
local math_min, math_max, math_floor = math.min, math.max, math.floor
local CreateFrame = CreateFrame
local issecretvalue = issecretvalue

local OVERLAY = "UI-HUD-CoolDownManager-IconOverlay"
local BAR_BORDER = "FlareUI Thin"
local BUTTON_BORDER, BUTTON_EDGE, BUTTON_SIZE = "FlareUI Frames", 16, 50   -- (Essential's icon size)

local pieces = setmetatable({}, { __mode = "k" })
local function Pieces(frame)
    local p = pieces[frame]
    if not p then p = {}; pieces[frame] = p end
    return p
end

-- Blizzard hands its pooled frames out again at every layout: a frame keeps its look until a setting
-- changes (CM:Refresh)
local styleRun = 0
local function Styled(item)
    local p = Pieces(item)
    if p.styled == styleRun then return true end
    p.styled = styleRun
    return false
end

-- Skin Cooldown Manager was a Buffs & Debuffs option until this file: on there, it stays on here
local function GetDb()
    local profile = ns.db and ns.db.profile
    local db = profile and profile.cooldownmanager
    if db and not db.movedFromAuras then
        db.movedFromAuras = true
        local auras = profile.auras
        if auras then
            if auras.enabled and auras.skinCDM then db.enabled, db.skin = true, true end
            auras.skinCDM = nil
        end
    end
    return db
end

local function Readable(v) return v ~= nil and not (issecretvalue and issecretvalue(v)) end

local function Nothing() end
local function ActiveItems(name)
    local viewer = _G[name]
    local pool = viewer and viewer.itemFramePool
    if pool and pool.EnumerateActive then return pool:EnumerateActive() end
    return Nothing
end

-- A font of the Fonts tab on one of Blizzard's texts. Size Auto (0) keeps the size Blizzard gave it,
-- read once before FlareUI first sets it.
local function SetFont(fontString, font)
    if not (fontString and fontString.GetFont and font) then return end
    local p = Pieces(fontString)
    if not p.size then
        local _, size = fontString:GetFont()
        p.size = Readable(size) and type(size) == "number" and size > 0 and size or 12
    end
    local flags = font.flags or "OUTLINE"
    if flags == "NONE" then flags = "" end
    local face = ns.GetFontPath(font.face or ns.GLOBAL_FONT)
    if (font.size or 0) > 0 then
        ns.SetFont(fontString, face, font.size, flags)
    else
        ns.SetFontUnscaled(fontString, face, p.size, flags)
    end
    ns.ApplyShadow(fontString, font)
end

-- Blizzard's own Cooldown Manager switch (Options): with it off FlareUI leaves the manager alone
function CM.BlizzardOn()
    return (C_CooldownViewer and GetCVarBool("cooldownViewerEnabled")) and true or false
end

-- A module of its own (the Cooldown Manager page's switch); never under the Gamepad UI. Also for
-- Visibility.lua: the viewers' Edit Mode rows and fading.
function CM.Enabled()
    local db = GetDb()
    return db and db.enabled and not ns.IsGamepadUI() or false
end

-- (the switch as it was at login: one flipped on since takes effect with the reload it asks for)
local startedOn
function CM.Started()
    if startedOn == nil then startedOn = CM.Enabled() end
    return startedOn
end

local function On()
    return CM.Enabled() and CM.BlizzardOn()
end

--------------------------------------------------
-- 1. SKIN
--------------------------------------------------
-- A Tracked Bar: the bar as a FlareUI cast bar, its icon as a buff
local function StyleBar(item)
    if Styled(item) then return end
    local K = ns.UnitFrames and ns.UnitFrames.Kit
    local bar = item.Bar
    if not (K and bar) then return end
    local uf = ns.db.profile.unitframes or {}
    local player = uf.units and uf.units.player
    local p = Pieces(item)
    local texture = K.GetBarTexture(player and player.texture)
    bar:SetStatusBarTexture(texture)
    local color = GetDb().barColor
    bar:SetStatusBarColor(color[1], color[2], color[3])
    if bar.BarBG then bar.BarBG:SetAlpha(0) end
    if bar.Pip then bar.Pip:SetAlpha(0) end
    if not p.bg then
        p.bg = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
        p.bg:SetAllPoints(bar)
        p.backdrop = CreateFrame("Frame", nil, bar, "BackdropTemplate")
        p.backdrop:SetFrameLevel(math_max(0, bar:GetFrameLevel() - 1))
        p.barBorder = CreateFrame("Frame", nil, bar, "BackdropTemplate")
        p.barBorder:SetFrameLevel(bar:GetFrameLevel() + 3)
    end
    p.bg:SetTexture(texture)
    p.bg:SetVertexColor(0.15, 0.15, 0.15, K.BAR_BG_OPACITY / 100)
    -- the border wraps the bar, as on the cast bars (BorderFit's inset on a thin bar)
    local height = 19
    local edgeFile = K.GetBorderFile(BAR_BORDER)
    local _, wrap = K.BorderFit(height, edgeFile)
    p.backdrop:ClearAllPoints()
    p.backdrop:SetPoint("TOPLEFT", bar, "TOPLEFT", -wrap, wrap)
    p.backdrop:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", wrap, -wrap)
    p.backdrop:SetBackdrop({ bgFile = K.BACKDROP_FILE, insets = { left = wrap, right = wrap, top = wrap, bottom = wrap } })
    p.backdrop:SetBackdropColor(0, 0, 0, K.BG_OPACITY)
    p.barBorder:ClearAllPoints()
    p.barBorder:SetAllPoints(p.backdrop)
    K.ApplyBorderStyle(p.barBorder, edgeFile, height + 2 * K.INSET)
    -- Bar Text (Fonts tab)
    local db = GetDb()
    SetFont(bar.Name, db.barFont)
    SetFont(bar.Duration, db.barFont)
    local icon = item.Icon
    local AU = ns.Auras
    if icon and icon.Icon and AU and AU.StyleIcon then
        AU.StyleIcon(icon, icon.Icon, Pieces(icon), false)
        SetFont(icon.Applications, db.stackFont)
    end
end

-- An Essential, Utility or Tracked Buffs icon (one border for the rows together), as the action
-- buttons with FlareUI Borders (ActionBars.lua 6b): Blizzard's ring off and FlareUI Frames on the
-- icon's edge, the rest Blizzard's
local function StyleIcon(item)
    if Styled(item) then return end
    local db = GetDb()
    local p = Pieces(item)
    for _, region in ipairs({ item:GetRegions() }) do
        if region.GetAtlas and region:GetAtlas() == OVERLAY then region:SetAlpha(0) end
    end
    if not p.frameBorder then p.frameBorder = CreateFrame("Frame", nil, item, "BackdropTemplate") end
    local b = p.frameBorder
    b:ClearAllPoints()
    b:SetAllPoints(item)
    local file = LibStub("LibSharedMedia-3.0"):Fetch("border", BUTTON_BORDER)
    -- the edge follows the icon's size: Utility icons are 30 px to Essential's 50, and a 16 px edge
    -- covered most of them
    local width = item:GetWidth()
    local share = (Readable(width) and width > 0) and math_min(1, width / BUTTON_SIZE) or 1
    b:SetBackdrop({ edgeFile = file, edgeSize = ns.BorderEdgeSize(file, math_floor(BUTTON_EDGE * share + 0.5)) })
    local c = ns.BORDER_COLOR
    b:SetBackdropBorderColor(c.r, c.g, c.b, c.a or 1)
    -- over the cooldown swipe
    b:SetFrameLevel(item:GetFrameLevel() + 2)
    -- Stack Count and Cooldown Numbers (Fonts tab)
    SetFont(item.Applications and item.Applications.Applications, db.stackFont)
    SetFont(item.ChargeCount and item.ChargeCount.Current, db.stackFont)
    local cooldown = item.Cooldown
    if cooldown and cooldown.GetCountdownFontString then SetFont(cooldown:GetCountdownFontString(), db.cooldownFont) end
end

local VIEWERS = { BuffBarCooldownViewer = StyleBar, BuffIconCooldownViewer = StyleIcon,
                  EssentialCooldownViewer = StyleIcon, UtilityCooldownViewer = StyleIcon }

--------------------------------------------------
-- 2. ACTIVE OVERLAY
-- Soften Active Overlay, for the Essential and Utility icons. While an ability's effect runs (Serpent
-- Sting on the target), Blizzard shows the effect's time on the icon under a strong yellow swipe
-- (CooldownViewerConstants.ITEM_AURA_COLOR). Only the swipe's strength changes: the time, the edge and
-- the colour stay Blizzard's, and a cooldown's own swipe is never touched.
--------------------------------------------------
local SOFT_VIEWERS = { EssentialCooldownViewer = true, UtilityCooldownViewer = true }
local SOFT_ALPHA = 0.2

local function Soften(item)
    local p = Pieces(item)
    local db = GetDb()
    local wanted = db and db.softOverlay and On()
    if not wanted and not p.soft then return end
    local constants = _G.CooldownViewerConstants
    local cooldown = item.Cooldown
    local active, idle = constants and constants.ITEM_AURA_COLOR, constants and constants.ITEM_COOLDOWN_COLOR
    if not (cooldown and cooldown.SetSwipeColor and active and idle) then return end
    local fromAura = item.wasSetFromAura
    -- unreadable: the swipe stays as it is, FlareUI cannot tell what the icon shows
    if fromAura ~= nil and not Readable(fromAura) then return end
    fromAura = fromAura and true or false
    if wanted and fromAura then
        p.soft = true
        cooldown:SetSwipeColor(active.r, active.g, active.b, SOFT_ALPHA)
    elseif p.soft then
        -- FlareUI's faint swipe goes: Blizzard's colour for what the icon shows now
        p.soft = nil
        local color = fromAura and active or idle
        cooldown:SetSwipeColor(color.r, color.g, color.b, color.a)
    end
end

-- Show Cooldown During Effect. While the effect runs Blizzard shows only its time, though the ability
-- itself may be on cooldown as well (Cone of Cold on the target). The ability's cooldown then counts
-- down in the icon's corner, on a small Cooldown widget of FlareUI's own: the spell's duration object
-- goes to it as it is, so nothing is read from it. Blizzard's own display is not touched, and shows
-- the cooldown itself again once the effect ends.
local EFFECT_FONT_SIZE = 11

local function EffectCooldown(item)
    local p = Pieces(item)
    local db = GetDb()
    local wanted = db and db.effectCooldown and On()
    if not wanted and not p.effect then return end
    local fromAura = item.wasSetFromAura
    -- unreadable: FlareUI cannot tell what the icon shows, the corner stays as it is
    if fromAura ~= nil and not Readable(fromAura) then return end
    local info = item.cooldownInfo
    local id
    if wanted and fromAura and type(info) == "table" then
        -- (as Blizzard: the spell an override has put in the base spell's place)
        id = Readable(info.overrideSpellID) and info.overrideSpellID or info.spellID
    end
    local duration
    if Readable(id) and type(id) == "number" then
        local ok, cd = pcall(C_Spell.GetSpellCooldown, id)
        -- (without the global cooldown: the corner would flicker on every cast)
        if ok and cd and Readable(cd.isActive) and cd.isActive then duration = C_Spell.GetSpellCooldownDuration(id, true) end
    end
    if not duration then
        if p.effect then p.effect:Clear() end
        return
    end
    if not p.effect then
        local timer = CreateFrame("Cooldown", nil, item, "CooldownFrameTemplate")
        timer:ClearAllPoints()
        timer:SetPoint("BOTTOMLEFT", item, "BOTTOMLEFT", 0, 0)
        timer:SetPoint("TOPRIGHT", item, "CENTER", 0, 0)
        -- over Blizzard's own cooldown and the skin's border
        timer:SetFrameLevel(item:GetFrameLevel() + 3)
        timer:SetDrawSwipe(false)
        timer:SetDrawEdge(false)
        timer:SetDrawBling(false)
        timer:SetHideCountdownNumbers(false)
        timer:EnableMouse(false)
        timer:Show()
        p.effect = timer
    end
    -- the Cooldown Numbers font with the skin on, small; set again only after a settings change
    if p.effectRun ~= styleRun and p.effect.GetCountdownFontString then
        p.effectRun = styleRun
        local font = { size = EFFECT_FONT_SIZE }
        if db.skin and db.cooldownFont then
            for key, value in pairs(db.cooldownFont) do font[key] = value end
            font.size = EFFECT_FONT_SIZE
        end
        SetFont(p.effect:GetCountdownFontString(), font)
    end
    -- (shown again each time, in case the widget hides itself once cleared or done)
    p.effect:Show()
    p.effect:SetCooldownFromDurationObject(duration)
end

-- (after each pass of Blizzard's over the icon's cooldown, where it paints the swipe again or clears
-- the cooldown: the icon may show another spell, or nothing, by then)
local function HookSwipe(item)
    local p = Pieces(item)
    if p.swipeHooked or not item.RefreshSpellCooldownInfo then return end
    p.swipeHooked = true
    hooksecurefunc(item, "RefreshSpellCooldownInfo", function()
        Soften(item)
        EffectCooldown(item)
    end)
end

--------------------------------------------------
-- 3. APPLYING
--------------------------------------------------
local function ApplyItem(name, item)
    local db = GetDb()
    if db.skin then VIEWERS[name](item) end
    if SOFT_VIEWERS[name] then
        if db.softOverlay or db.effectCooldown then HookSwipe(item) end
        Soften(item)
        EffectCooldown(item)
    end
end

local function ApplyViewer(name)
    for item in ActiveItems(name) do ApplyItem(name, item) end
end

-- every frame showing now (a settings change, or the viewer was already up)
function CM:Refresh()
    styleRun = styleRun + 1
    -- (switched on but not started yet: the frames would be styled without the hooks that keep them so)
    if not (self.initialized and On()) then return end
    for name in pairs(VIEWERS) do ApplyViewer(name) end
end

-- new frames as Blizzard acquires them (tracking another buff), in a fight too
local hooked = false
local function Hook()
    if hooked then return end
    for name in pairs(VIEWERS) do
        local viewer = _G[name]
        if viewer and viewer.OnAcquireItemFrame then
            hooked = true
            hooksecurefunc(viewer, "OnAcquireItemFrame", function(_, item)
                if On() then ApplyItem(name, item) end
            end)
        end
    end
    CM:Refresh()
    -- the viewers exist now: their fading (Visibility.lua)
    C_Timer.After(0, function()
        if ns.Visibility and ns.Visibility.Refresh then ns.Visibility:Refresh() end
    end)
end

--------------------------------------------------
-- 4. EDIT MODE
-- Blizzard's own Visibility and Opacity rows leave the viewers' dialogs: FlareUI's Fading section does
-- both. A row whose stored value is not Blizzard's default stays, or a viewer hidden by it could never
-- be brought back. Done on the dialog's own rows after Blizzard builds them (as Minimap.lua trims the
-- minimap's), never in Blizzard's table: addon-written entries there would taint Edit Mode.
--------------------------------------------------
local function TrimDialog(dialog)
    local system = dialog and dialog.attachedToSystem
    local setting = Enum.EditModeCooldownViewerSetting
    if not (system and setting and system.system == Enum.EditModeSystem.CooldownViewer and dialog.Settings) then return end
    if not On() then return end
    local always = Enum.CooldownViewerVisibleSetting and Enum.CooldownViewerVisibleSetting.Always or 0
    local defaults = {}
    if setting.VisibleSetting then defaults[setting.VisibleSetting] = always end
    if setting.Opacity then defaults[setting.Opacity] = 100 end
    local changed = false
    for _, row in ipairs({ dialog.Settings:GetChildren() }) do
        local default = row:IsShown() and row.setting and defaults[row.setting]
        if default and system.GetSettingValue then
            local ok, value = pcall(system.GetSettingValue, system, row.setting)
            if ok and value == default then
                row:Hide()
                changed = true
            end
        end
    end
    if changed then
        dialog.Settings:Layout()
        if dialog.Layout then dialog:Layout() end
    end
end

local trimHooked = false
local function HookDialog()
    local dialog = _G.EditModeSystemSettingsDialog
    if not dialog then
        if not C_AddOns.IsAddOnLoaded("Blizzard_EditMode") then EventUtil.ContinueOnAddOnLoaded("Blizzard_EditMode", HookDialog) end
        return
    end
    if trimHooked or not (Enum.EditModeSystem and Enum.EditModeSystem.CooldownViewer) then return end
    trimHooked = true
    hooksecurefunc(dialog, "UpdateSettings", TrimDialog)
end

function CM:ShouldLoad()
    GetDb()
    startedOn = CM.Enabled()
    -- Blizzard's Cooldown Manager takes part in the Gamepad UI's controller navigation
    return not ns.IsGamepadUI()
end

function CM:Init()
    if self.initialized then return end
    self.initialized = true
    HookDialog()
    -- (its addon can load after FlareUI)
    if On() then EventUtil.ContinueOnAddOnLoaded("Blizzard_CooldownViewer", Hook) end
    local watch = CreateFrame("Frame")
    watch:RegisterEvent("CVAR_UPDATE")
    watch:SetScript("OnEvent", function(_, _, name)
        -- turned on in Blizzard's options later this session: skinned from then on
        if name ~= "cooldownViewerEnabled" then return end
        if On() then EventUtil.ContinueOnAddOnLoaded("Blizzard_CooldownViewer", Hook) end
        if ns.SettingsPanel and ns.SettingsPanel.Refresh then pcall(ns.SettingsPanel.Refresh, ns.SettingsPanel) end
    end)
end
