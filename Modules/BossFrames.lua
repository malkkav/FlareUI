local _, ns = ...
local L = ns.L

--------------------------------------------------
-- BOSS FRAMES
-- Boss frames: boss1 to boss5, on the party frames' classic tile (PartyFrames.lua's tile kit),
-- mirrored as the target frame is. A boss can show up mid fight, so each frame keeps a fixed place
-- and Blizzard's unit watch shows it. Auras: every buff on the boss and only the player's debuffs.
-- The frames sit as far apart as the party frames. Blizzard's boss frames are parked.
--------------------------------------------------

--------------------------------------------------
-- 1. MODULE REGISTRATION
--------------------------------------------------
ns.BossFrames = ns.BossFrames or {}
local BF = ns.BossFrames
ns.modules["BossFrames"] = BF

LibStub("AceEvent-3.0"):Embed(BF)

--------------------------------------------------
-- 2. UPVALUES / CONSTANTS
--------------------------------------------------
local ipairs, pcall = ipairs, pcall
local math_floor = math.floor
local CreateFrame, InCombatLockdown = CreateFrame, InCombatLockdown
local LEM = LibStub("FlareEditMode")
local K = ns.UnitFrames and ns.UnitFrames.Kit
local PF = ns.PartyFrames
local Tile = PF and PF.Tile

local MAX_BOSSES = 5
local DEFAULT_POSITION = { point = "RIGHT", x = -3, y = -11 }
local TILE_TEMPLATE = "SecureUnitButtonTemplate,PingableUnitFrameTemplate,BackdropTemplate"

-- hostile red, as on the unit frames
local HOSTILE_RGB = { 0.87, 0.27, 0.27 }
-- Edit Mode samples: three bosses, then two adds
local SAMPLES = {
    { name = "Onyxia", level = -1, health = 0.78, power = 0.62, marker = 8, buffs = 1, debuffs = 2,
      portrait = "Interface\\Icons\\INV_Misc_Head_Dragon_Black" },
    { name = "Ragnaros", level = -1, health = 0.54, power = 0.85, debuffs = 1,
      portrait = "Interface\\Icons\\Spell_Fire_Fire" },
    { name = "Nefarian", level = -1, health = 0.31, power = 0.40, buffs = 2,
      portrait = "Interface\\Icons\\INV_Misc_Head_Dragon_01" },
    { name = "Flamewaker Elite", level = -1, health = 0.92, power = 0.70,
      portrait = "Interface\\Icons\\Spell_Fire_Incinerate" },
    { name = "Core Hound", level = -1, health = 0.66, power = 0.25,
      portrait = "Interface\\Icons\\Ability_Hunter_Pet_Wolf" },
}
for _, s in ipairs(SAMPLES) do s.rgb = HOSTILE_RGB end

--------------------------------------------------
-- 3. SETTINGS ACCESS
--------------------------------------------------
local holder
local tiles = {}
local pendingLayout = false

local function GetDb()
    local db = K and K.GetDb()
    return db and db.boss
end

local function IsEditing()
    return LEM:IsInEditMode()
end

-- What a tile reads: the boss settings, plus what the boss frames never have (a mirrored look, no
-- range fading, no party icons, no dispel or defensive auras) and the party frames' spacing
local ICONS = { role = { shown = false }, leader = { shown = false }, readyCheck = { shown = false },
                status = { shown = false }, raidIcon = {} }
local FIXED = { mirror = true, rangeAlpha = 1, healersOnlyPower = false, bigBossDebuffs = false,
                bigDefensive = false, privateAuras = false, dispelHighlight = "off", dispels = "OFF" }
local view = setmetatable({}, { __index = function(_, key)
    local db = GetDb()
    if not db then return nil end
    if FIXED[key] ~= nil then return FIXED[key] end
    if key == "portrait" then return db.portrait and "3d" or "none" end
    if key == "spacing" then
        local party = ns.defaults and ns.defaults.profile.unitframes.party
        return party and party.classic and party.classic.spacing or 16
    end
    if key == "icons" then
        ICONS.raidIcon.shown = db.raidIcon ~= false
        return ICONS
    end
    return db[key]
end })

local ctx = {
    Settings = function() return view end,
    PreviewData = function(f) return f.sample or SAMPLES[1] end,
    ReadyHold = function() return nil end,
    classic = true, hostile = true, castbar = true,
}

--------------------------------------------------
-- 4. TILES AND LAYOUT
--------------------------------------------------
local function CreateTile(i)
    local unit = "boss" .. i
    local f = CreateFrame("Button", "FlareUI_Boss" .. i, holder, TILE_TEMPLATE)
    f.ctx = ctx
    f.index = i
    f.sample = SAMPLES[i]
    f.unit = unit
    f:SetAttribute("unit", unit)
    f:SetAttribute("*type1", "target")
    f:SetAttribute("*type2", "togglemenu")
    f:RegisterForClicks("AnyUp")
    if type(f.SetRolesets) == "function" then pcall(f.SetRolesets, f, "unitFrames") end
    _G.ClickCastFrames = _G.ClickCastFrames or {}
    _G.ClickCastFrames[f] = true
    f:SetScript("OnEnter", Tile.OnEnter)
    f:SetScript("OnLeave", Tile.OnLeave)
    Tile.Build(f, unit)
    -- a boss that becomes targetable (or stops) refreshes like any other change
    pcall(f.RegisterUnitEvent, f, "UNIT_TARGETABLE_CHANGED", unit)
    tiles[i] = f
    return f
end

-- One frame to the next: the frame, its cast bar, the auras above and below it, and the spacing
local function Step()
    local above = Tile.LanesExtent(view, { "ABOVE", "ABOVE_RIGHT" })
    local below = Tile.LanesExtent(view, { "BELOW", "BELOW_RIGHT" })
    local h = view.height or 50
    if view.castbar then h = h + (view.castHeight or 14) + K.CAST_GAP + K.INSET end
    return above, above + h + below + (view.spacing or 24)
end

-- Fixed places (a boss can show up in a fight, when nothing may move): boss 1 at the top, or at the
-- bottom when the frames grow up
local function LayoutHolder()
    if not holder then return end
    local above, step = Step()
    local up = view.grow == "UP"
    for i, f in ipairs(tiles) do
        local slot = up and (MAX_BOSSES - i) or (i - 1)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -(above + slot * step))
    end
    holder:SetSize(view.width or 200, math.max(1, MAX_BOSSES * step - (view.spacing or 24)))
end

--------------------------------------------------
-- 5. POSITION (per Edit Mode layout)
--------------------------------------------------
local function LayoutStore(layoutName)
    local db = GetDb()
    if not db then return nil end
    layoutName = layoutName or LEM:GetActiveLayoutName() or "Modern"
    db.layouts = db.layouts or {}
    db.layouts[layoutName] = db.layouts[layoutName] or {}
    return db.layouts[layoutName]
end

local function ApplyPosition(layoutName)
    if not holder then return end
    if InCombatLockdown() then pendingLayout = true return end
    local store = LayoutStore(layoutName)
    local pos = (store and store.point) and store or DEFAULT_POSITION
    holder:ClearAllPoints()
    holder:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
end

local function OnFrameMoved(_, layoutName, point, x, y)
    local store = LayoutStore(layoutName)
    if store then store.point, store.x, store.y = point, math_floor(x + 0.5), math_floor(y + 0.5) end
end

--------------------------------------------------
-- 6. VISIBILITY
-- Each frame follows its unit (Blizzard's unit watch, safe in a fight); in Edit Mode all five show,
-- with samples.
--------------------------------------------------
local function ApplyVisibility()
    if not holder then return end
    if InCombatLockdown() then pendingLayout = true return end
    local editing = IsEditing()
    for _, f in ipairs(tiles) do
        if editing then
            UnregisterUnitWatch(f)
            f:Show()
        else
            RegisterUnitWatch(f)
        end
    end
end

-- the aura containers' own samples, in Edit Mode
local function SetAuraPreview(enabled)
    for _, f in ipairs(tiles) do
        if f.AuraPos then
            for _, entry in pairs(f.AuraPos) do pcall(entry.container.SetEditModePreviewEnabled, entry.container, enabled) end
        end
    end
end

local function UpdateTile(f)
    Tile.UpdateAll(f)
end

local function Refresh()
    if not holder then return end
    if InCombatLockdown() then pendingLayout = true return end
    pendingLayout = false
    for _, f in ipairs(tiles) do
        local ok, err = pcall(Tile.Layout, f)
        if not ok then geterrorhandler()(err) end
    end
    LayoutHolder()
    ApplyPosition()
    ApplyVisibility()
    for _, f in ipairs(tiles) do
        if f:IsShown() then UpdateTile(f) end
    end
end

--------------------------------------------------
-- 7. EDIT MODE SETTINGS
--------------------------------------------------
local function BuildSettings()
    local settings = {}
    local D = (ns.defaults and ns.defaults.profile.unitframes.boss) or {}
    local function get(key)
        return function()
            local db = GetDb()
            local v = db and db[key]
            if v == nil then return D[key] end
            return v
        end
    end
    local function set(key)
        return function(_, value)
            local db = GetDb()
            if not db then return end
            db[key] = value
            Refresh()
        end
    end

    local function SectionOpen(name)
        local db = K.GetDb()
        return db and db.editSections and db.editSections[name] or false
    end
    local function Section(name, items)
        settings[#settings + 1] = { name = "|cffffd100" .. L[name] .. "|r", kind = LEM.SettingType.Expander, default = false,
            get = function() return SectionOpen(name) end,
            set = function(_, value)
                local db = K.GetDb()
                if not db then return end
                db.editSections = db.editSections or {}
                db.editSections[name] = value and true or nil
            end }
        for _, item in ipairs(items) do
            item.hidden = function() return not SectionOpen(name) end
            settings[#settings + 1] = item
        end
    end

    Section("Frame", {
        { name = L["Width"], kind = LEM.SettingType.Slider, default = D.width, minValue = 80, maxValue = 400, valueStep = 2, get = get("width"), set = set("width") },
        { name = L["Height"], kind = LEM.SettingType.Slider, default = D.height, minValue = 20, maxValue = 120, valueStep = 1, get = get("height"), set = set("height") },
        { name = L["Power Bar Height"], kind = LEM.SettingType.Slider, default = D.powerHeight, minValue = 0, maxValue = 30, valueStep = 1,
          get = get("powerHeight"), set = set("powerHeight"), formatter = function(value) return value == 0 and _G.OFF or value end },
        { name = L["Growth"], kind = LEM.SettingType.Dropdown, default = D.grow,
          values = { { text = L["Down"], value = "DOWN", isRadio = true }, { text = L["Up"], value = "UP", isRadio = true } },
          desc = L["Which way the frames go from the first boss."],
          get = get("grow"), set = set("grow") },
        { name = L["Health Text"], kind = LEM.SettingType.Dropdown, default = D.healthText, values = K.HEALTH_TEXT_MODES, get = get("healthText"), set = set("healthText") },
        { name = L["Power Text"], kind = LEM.SettingType.Checkbox, default = D.powerText or false, get = get("powerText"), set = set("powerText") },
        { name = L["Show Level"], kind = LEM.SettingType.Checkbox, default = D.showLevel ~= false, get = get("showLevel"), set = set("showLevel") },
        { name = L["Portrait"], kind = LEM.SettingType.Checkbox, default = D.portrait or false, get = get("portrait"), set = set("portrait") },
        { name = L["Raid Target"], kind = LEM.SettingType.Checkbox, default = D.raidIcon ~= false, get = get("raidIcon"), set = set("raidIcon") },
    })

    Section("Look", {
        { name = L["Bar Texture"], kind = LEM.SettingType.Dropdown, default = D.texture, values = K.BuildTextureValues(false),
          get = get("texture"), set = set("texture") },
        { name = L["Border Texture"], kind = LEM.SettingType.Dropdown, default = D.border, values = K.BuildBorderValues(false),
          get = get("border"), set = set("border") },
    })

    Section("Auras", {
        { name = L["Buffs"], kind = LEM.SettingType.Dropdown, default = D.buffs, values = Tile.AURA_POSITION_VALUES,
          get = get("buffs"), set = set("buffs"), desc = L["Every buff on the boss, such as enrages and shields."] },
        { name = L["Debuffs"], kind = LEM.SettingType.Dropdown, default = D.debuffs, values = Tile.AURA_POSITION_VALUES,
          get = get("debuffs"), set = set("debuffs"), desc = L["Only your own debuffs on the boss."] },
        { name = L["Aura Size"], kind = LEM.SettingType.Slider, default = D.auraSize, minValue = 10, maxValue = 40, valueStep = 1, get = get("auraSize"), set = set("auraSize") },
    })

    Section("Cast Bar", {
        { name = L["Cast Bars"], kind = LEM.SettingType.Checkbox, default = D.castbar ~= false, get = get("castbar"), set = set("castbar") },
    })
    return settings
end

--------------------------------------------------
-- 8. BLIZZARD'S BOSS FRAMES (parked with HardHide)
--------------------------------------------------
local function HideBlizzardBoss()
    if _G.BossTargetFrameContainer then K.HardHide("BossTargetFrameContainer") end
    for i = 1, MAX_BOSSES do
        if _G["Boss" .. i .. "TargetFrame"] then K.HardHide("Boss" .. i .. "TargetFrame") end
    end
end

--------------------------------------------------
-- 9. PUBLIC
--------------------------------------------------
function BF:Refresh()
    Refresh()
end

function BF:ShouldLoad()
    local db = K and K.GetDb()
    return db and db.enabled and db.boss and db.boss.enabled and Tile and true or false
end

function BF:OnGlobalEvent(event, unit)
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingLayout then Refresh() end
        return
    end
    if IsEditing() then return end
    for _, f in ipairs(tiles) do
        if f:IsShown() then
            if event == "PLAYER_TARGET_CHANGED" then
                Tile.UpdateTarget(f)
            elseif event == "RAID_TARGET_UPDATE" then
                Tile.UpdateRaidIcon(f)
            elseif event == "UNIT_THREAT_LIST_UPDATE" or event == "UNIT_THREAT_SITUATION_UPDATE" then
                Tile.UpdateThreat(f)
            else
                UpdateTile(f)   -- the bosses changed (an encounter, a phase)
            end
        end
    end
end

local GLOBAL_EVENTS = {
    "INSTANCE_ENCOUNTER_ENGAGE_UNIT", "PLAYER_TARGET_CHANGED", "RAID_TARGET_UPDATE",
    "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
}

function BF:Init()
    if self.initialized or not (K and Tile) then return end
    if InCombatLockdown() then
        -- secure frames cannot be made in a fight (a /reload mid-combat); they come after it
        self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            self:Init()
        end)
        return
    end
    self.initialized = true

    holder = CreateFrame("Frame", "FlareUI_Boss", UIParent)
    holder:SetFrameStrata("LOW")
    holder:SetClampedToScreen(true)
    holder:SetSize(200, 300)
    holder.editModeName = "FlareUI Boss Frames"
    for i = 1, MAX_BOSSES do CreateTile(i) end

    LEM:AddFrame(holder, OnFrameMoved, DEFAULT_POSITION, "FlareUI Boss Frames")
    LEM:AddFrameSettings(holder, BuildSettings())
    HideBlizzardBoss()

    for _, event in ipairs(GLOBAL_EVENTS) do self:RegisterEvent(event, "OnGlobalEvent") end

    LEM:RegisterCallback("layout", function(layoutName) ApplyPosition(layoutName) end)
    LEM:RegisterCallback("enter", function()
        ApplyVisibility()
        SetAuraPreview(true)
        for _, f in ipairs(tiles) do UpdateTile(f) end
    end)
    LEM:RegisterCallback("exit", function()
        SetAuraPreview(false)
        Refresh()
    end)

    Refresh()
    C_Timer.After(0, Refresh)
end
