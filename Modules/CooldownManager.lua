local _, ns = ...

--------------------------------------------------
-- COOLDOWN MANAGER
-- Blizzard's Cooldown Manager in FlareUI's look. The Tracked Bars as FlareUI's cast bars (the unit
-- frames' bar texture, a thin bronze border), their icons as FlareUI's buffs, the Essential / Utility /
-- Tracked Buffs icons with the action buttons' FlareUI Borders. Blizzard
-- keeps driving its own pooled frames; it sets only values, text and the spark after a frame is made, so
-- each one is styled once as it is acquired. Its aura data is kept from addons
-- (CooldownViewerSecure.lua): nothing here reads it, re-parents its frames or calls their layout.
-- FlareUI's pieces live in a weak table.
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
local BAR_COLOR, BAR_BORDER = { 1, 0.5, 0.25 }, "FlareUI Thin"
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

-- Blizzard's own Cooldown Manager switch (Options): with it off FlareUI leaves the manager alone
function CM.BlizzardOn()
    return (C_CooldownViewer and GetCVarBool("cooldownViewerEnabled")) and true or false
end

-- A module of its own (the Cooldown Manager page's switch); never under the Gamepad UI.
function CM.Enabled()
    local db = GetDb()
    return db and db.enabled and not ns.IsGamepadUI() or false
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
    bar:SetStatusBarColor(BAR_COLOR[1], BAR_COLOR[2], BAR_COLOR[3])
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
    local icon = item.Icon
    local AU = ns.Auras
    if icon and icon.Icon and AU and AU.StyleIcon then
        AU.StyleIcon(icon, icon.Icon, Pieces(icon), false)
        if icon.Applications and AU.StackFont then AU.StackFont(icon.Applications) end
    end
end

-- An Essential, Utility or Tracked Buffs icon (one border for the rows together), as the action
-- buttons with FlareUI Borders (ActionBars.lua 6b): Blizzard's ring off and FlareUI Frames on the
-- icon's edge, the rest Blizzard's
local function StyleIcon(item)
    if Styled(item) then return end
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
end

-- Tracked Buffs: the cooldown icons' border, with the Buffs frame's stack font
local function StyleBuffIcon(item)
    StyleIcon(item)
    local count = item.Applications and item.Applications.Applications
    local AU = ns.Auras
    if count and AU and AU.StackFont then AU.StackFont(count) end
end

local VIEWERS = { BuffBarCooldownViewer = StyleBar, BuffIconCooldownViewer = StyleBuffIcon,
                  EssentialCooldownViewer = StyleIcon, UtilityCooldownViewer = StyleIcon }

--------------------------------------------------
-- 2. APPLYING
--------------------------------------------------
local function ApplyItem(name, item)
    local db = GetDb()
    if db.skin then VIEWERS[name](item) end
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
end

function CM:ShouldLoad()
    GetDb()
    -- Blizzard's Cooldown Manager takes part in the Gamepad UI's controller navigation
    return not ns.IsGamepadUI()
end

function CM:Init()
    if self.initialized then return end
    self.initialized = true
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
