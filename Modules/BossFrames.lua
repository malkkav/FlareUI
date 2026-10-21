local _, ns = ...
local L = ns.L

--------------------------------------------------
-- BOSS FRAMES
-- boss1 to boss5 on the party frames' classic tile (PartyFrames.lua tile kit), mirrored like the
-- target frame. Fixed places and a unit watch, so a boss can appear mid-fight. Blizzard's are hidden.
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
local pairs, ipairs, pcall, type = pairs, ipairs, pcall, type
local math_floor, math_max = math.floor, math.max
local CreateFrame, InCombatLockdown = CreateFrame, InCombatLockdown
local LEM = LibStub("FlareEditMode")
local K = ns.UnitFrames and ns.UnitFrames.Kit
local PF = ns.PartyFrames
local Tile = PF and PF.Tile

local MAX_BOSSES = 5
local BASE_POSITION = { point = "RIGHT", x = -3, y = -11 }
-- Edit Mode keeps a reference to this table: ApplyPosition refills it for the style in use
local DEFAULT_POSITION = { point = "RIGHT", x = -3, y = -11 }
local TILE_TEMPLATE = "SecureUnitButtonTemplate,PingableUnitFrameTemplate,BackdropTemplate"

local HOSTILE_RGB = { 0.87, 0.27, 0.27 }
-- Edit Mode samples
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

-- The tile settings: the boss db plus fixed values (no party icons, dispels or defensives; five
-- auras to a row)
local ICONS = { role = { shown = false }, leader = { shown = false }, readyCheck = { shown = false },
                status = { shown = false }, raidIcon = {} }
local FIXED = { bigBossDebuffs = false, bigDefensive = false, dispelHighlight = "off",
                dispels = "OFF", auraMax = 5, auraPerRow = 5 }
local view = setmetatable({}, { __index = function(_, key)
    local db = GetDb()
    if not db then return nil end
    if FIXED[key] ~= nil then return FIXED[key] end
    if key == "portrait" then return db.portrait and "3d" or "none" end
    if key == "icons" then
        ICONS.raidIcon.shown = db.raidIcon ~= false
        return ICONS
    end
    return db[key]
end, __newindex = function(_, key, value)
    -- writes land in the boss db (Forever Style's Scale sets the height through the view)
    local db = GetDb()
    if db then db[key] = value end
end })

local ctx = {
    Settings = function() return view end,
    PreviewData = function(f) return f.sample or SAMPLES[1] end,
    ReadyHold = function() return nil end,
    classic = true, mirror = true, hostile = true, castbar = true,
    ringKind = "boss",   -- the portrait ring in the ring styles (PartyFrames.lua RingKind)
}

-- FlareUI Style and Forever Style both use the ring
local function RingStyle()
    return ns.UFRing and ns.UFRing.Style() ~= "addon" or false
end

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
    pcall(f.RegisterUnitEvent, f, "UNIT_TARGETABLE_CHANGED", unit)
    tiles[i] = f
    return f
end

-- The first frame's offset, and the step between frames (frame, cast bar, auras, spacing)
local function Step()
    local above = Tile.LanesExtent(view, Tile.ABOVE_PLACES)
    local below = Tile.LanesExtent(view, Tile.BELOW_PLACES)
    local h = view.height or 50
    if view.castbar then h = h + (view.castHeight or 14) + K.CAST_GAP + K.INSET end
    return above, above + h + below + (view.spacing or 16)
end

-- Fixed places: a boss can appear in combat, when secure frames cannot move. Boss 1 at the top
-- (the bottom for Growth Up).
local function LayoutHolder()
    if not holder then return end
    local above, step = Step()
    local up = view.grow == "UP"
    for i, f in ipairs(tiles) do
        local slot = up and (MAX_BOSSES - i) or (i - 1)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -(above + slot * step))
    end
    holder:SetSize(view.width or 200, math_max(1, MAX_BOSSES * step - (view.spacing or 16)))
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
    -- the ring styles' default leaves room for the ring
    local base = RingStyle() and ns.UFRing.TilePosition("boss") or BASE_POSITION
    for k, v in pairs(base) do DEFAULT_POSITION[k] = v end
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
-- Each frame follows its unit (unit watch, combat-safe); Edit Mode shows all five with samples.
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

local function Refresh()
    if not holder then return end
    if InCombatLockdown() then pendingLayout = true return end
    pendingLayout = false
    local db = GetDb()
    -- the ring styles keep the target frame's layout: Mirror turns only the bars there
    ctx.fillMirror = not (db and db.mirror == false)
    ctx.mirror = RingStyle() or ctx.fillMirror
    for _, f in ipairs(tiles) do
        local ok, err = pcall(Tile.Layout, f)
        if not ok then geterrorhandler()(err) end
    end
    LayoutHolder()
    ApplyPosition()
    ApplyVisibility()
    for _, f in ipairs(tiles) do
        if f:IsShown() then Tile.UpdateAll(f) end
    end
end

--------------------------------------------------
-- 7. EDIT MODE SETTINGS
--------------------------------------------------
local function BuildSettings()
    local base = (ns.defaults and ns.defaults.profile.unitframes.boss) or {}
    -- the ring style's defaults first
    local ring = ns.UFRing and ns.UFRing.TileDefaults("boss")
    local D = ring and setmetatable({}, { __index = function(_, k)
        if ring[k] ~= nil then return ring[k] end
        return base[k]
    end }) or base
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

    local Section, settings = K.EditSections()

    Section("Boss", {
        { name = L["Growth"], kind = LEM.SettingType.Dropdown, default = D.grow,
          values = { { text = L["Down"], value = "DOWN", isRadio = true }, { text = L["Up"], value = "UP", isRadio = true } },
          desc = L["Which way the frames go from the first boss."],
          get = get("grow"), set = set("grow") },
        { name = L["Spacing"], kind = LEM.SettingType.Slider, default = D.spacing or 16, minValue = 0, maxValue = 80, valueStep = 1,
          get = get("spacing"), set = set("spacing"),
          desc = L["The gap between the boss frames."] },
    })

    -- Forever Style's plate: sized by Scale
    local function onPlate() return ns.UFRing and ns.UFRing.PlateOn() or false end
    Section("Frame", {
        { name = L["Scale"], kind = LEM.SettingType.Slider, default = ns.UFRing and ns.UFRing.PlateDefaultScale("boss") or 100,
          minValue = 75, maxValue = 250, valueStep = 5, formatter = function(value) return value .. "%" end,
          get = function() local db = GetDb(); return db and db.plateScale or (ns.UFRing and ns.UFRing.PlateDefaultScale("boss")) or 100 end,
          set = function(_, value)
              if not onPlate() then return end
              ns.UFRing.ApplyPlateScale(GetDb(), value)
              Refresh()
          end,
          hidden = function() return not onPlate() end },
        { name = L["Width"], kind = LEM.SettingType.Slider, default = D.width, minValue = 80, maxValue = 400, valueStep = 2, get = get("width"), set = set("width") },
        { name = L["Height"], kind = LEM.SettingType.Slider, default = D.height, minValue = 20, maxValue = 120, valueStep = 1, get = get("height"), set = set("height"),
          hidden = onPlate },
        { name = L["Power Bar Height"], kind = LEM.SettingType.Slider, default = D.powerHeight, minValue = 0, maxValue = 30, valueStep = 1,
          get = get("powerHeight"), set = set("powerHeight"), formatter = function(value) return value == 0 and _G.OFF or value end,
          hidden = onPlate },
        { name = L["Portrait Size"], kind = LEM.SettingType.Slider, default = ns.UFRing and ns.UFRing.DefaultSize("boss") or 80,
          minValue = 36, maxValue = 120, valueStep = 1,
          get = function() local db = GetDb(); return db and db.ringSize or (ns.UFRing and ns.UFRing.DefaultSize("boss")) or 80 end,
          set = set("ringSize"), hidden = function() return not RingStyle() or onPlate() end },
        { name = L["Health Text"], kind = LEM.SettingType.Dropdown, default = D.healthText, values = K.HEALTH_TEXT_MODES, get = get("healthText"), set = set("healthText") },
        { name = L["Power Text"], kind = LEM.SettingType.Checkbox, default = D.powerText or false, get = get("powerText"), set = set("powerText") },
        { name = L["Show Level"], kind = LEM.SettingType.Checkbox, default = D.showLevel ~= false, get = get("showLevel"), set = set("showLevel") },
        { name = L["Mirror"], kind = LEM.SettingType.Checkbox, default = D.mirror ~= false,
          get = function() return get("mirror")() ~= false end, set = set("mirror"),
          desc = L["Laid out as the target frame: portrait on the right, bars filling from the right. In FlareUI and Forever Style, only the bars' direction."] },
        -- the ring always has a portrait
        { name = L["Portrait"], kind = LEM.SettingType.Checkbox, default = D.portrait or false, get = get("portrait"), set = set("portrait"),
          hidden = RingStyle },
    })

    Section("Look", {
        { name = L["Bar Texture"], kind = LEM.SettingType.Dropdown, default = D.texture, values = K.BuildTextureValues(),
          get = get("texture"), set = set("texture") },
        { name = L["Border Texture"], kind = LEM.SettingType.Dropdown, default = D.border, values = K.BuildBorderValues(false),
          get = get("border"), set = set("border"), hidden = K.NoBorderOptions },
        { name = L["Absorb Texture"], kind = LEM.SettingType.Dropdown, default = D.absorbTexture, values = K.BuildAbsorbValues(),
          get = get("absorbTexture"), set = set("absorbTexture"),
          desc = L["The texture of the shield (absorb) over the health bar."] },
        K.BgOpacitySetting(K.BAR_BG_OPACITY,
            function() local v = get("bgOpacity")(); if v == nil then return K.BAR_BG_OPACITY end; return v end,
            set("bgOpacity")),
    })

    local function noCast() return get("castbar")() == false end
    Section("Cast Bar", {
        { name = L["Cast Bars"], kind = LEM.SettingType.Checkbox, default = D.castbar ~= false, get = get("castbar"),
          set = function(layoutName, value) set("castbar")(layoutName, value); if holder then LEM:RefreshFrameSettings(holder) end end },
        { name = L["Cast Bar Height"], kind = LEM.SettingType.Slider, default = D.castHeight or 14, minValue = 8, maxValue = 30, valueStep = 1,
          get = get("castHeight"), set = set("castHeight"), hidden = noCast },
        { name = L["Hide Icon"], kind = LEM.SettingType.Checkbox, default = false,
          get = function() return get("castIcon")() == false end,
          set = function(layoutName, value) set("castIcon")(layoutName, not value) end,
          hidden = noCast,
          desc = L["No spell icon left of the bar."] },
        { name = L["Hide Spell Timer"], kind = LEM.SettingType.Checkbox, default = false,
          get = function() return get("castTimer")() == false end,
          set = function(layoutName, value) set("castTimer")(layoutName, not value) end,
          hidden = noCast,
          desc = L["No time left at the right end of the bar."] },
        { name = L["Cast Bar Texture"], kind = LEM.SettingType.Dropdown, default = D.castTexture, values = K.BuildTextureValues(),
          get = get("castTexture"), set = set("castTexture"), hidden = noCast, },
        { name = L["Cast Bar Border Texture"], kind = LEM.SettingType.Dropdown, default = D.castBorderTexture, values = K.BuildBorderValues(true),
          get = get("castBorderTexture"), set = set("castBorderTexture"),
          hidden = function() return noCast() or K.NoBorderOptions() end,
          desc = L["Frame Border uses the frame's own border."] },
    })

    -- no Right of the Frame (the frames sit at the screen's right edge); clashing places grey out
    local places = PF.AuraPlaces("RIGHT")
    -- Forever Style's plate: no inside places (the bars are too slim)
    if ns.UFRing and ns.UFRing.PlateOn() then
        local kept = {}
        for _, p in ipairs(places) do if not p.value:find("^INSIDE") then kept[#kept + 1] = p end end
        places = kept
    end
    local function Place(field, other)
        return function(_, rootDescription, data)
            for _, p in ipairs(places) do
                local radio = rootDescription:CreateRadio(p.text,
                    function(value) return get(field)() == value end,
                    function(value) data.set(nil, value) end, p.value)
                if radio.SetEnabled and Tile.PlacesClash(p.value, get(other)()) then radio:SetEnabled(false) end
            end
        end
    end
    Section("Auras", {
        { name = L["Buffs"], kind = LEM.SettingType.Dropdown, default = D.buffs, values = places, generator = Place("buffs", "debuffs"),
          get = get("buffs"), set = set("buffs"), desc = L["Every buff on the boss, such as enrages and shields."] },
        { name = L["Debuffs"], kind = LEM.SettingType.Dropdown, default = D.debuffs, values = places, generator = Place("debuffs", "buffs"),
          get = get("debuffs"), set = set("debuffs"), desc = L["Debuffs on the boss: only your own with Only My Debuffs."] },
        { name = L["Aura Size"], kind = LEM.SettingType.Slider, default = D.auraSize, minValue = 10, maxValue = 40, valueStep = 1, get = get("auraSize"), set = set("auraSize") },
        { name = L["Only My Debuffs"], kind = LEM.SettingType.Checkbox, default = D.onlyMyDebuffs ~= false,
          get = function() return get("onlyMyDebuffs")() ~= false end, set = set("onlyMyDebuffs") },
    })
    Section("Aura Ordering", ns.AuraOrder.Items(get, set))

    Section("Icons", {
        { name = L["Raid Markers"], kind = LEM.SettingType.Checkbox, default = D.raidIcon ~= false, get = get("raidIcon"), set = set("raidIcon") },
    })
    return settings
end

--------------------------------------------------
-- 8. BLIZZARD'S BOSS FRAMES (hidden with HardHide)
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
                Tile.UpdateAll(f)   -- the bosses changed
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
        -- secure frames cannot be created in combat (a /reload mid-fight): wait for it to end
        self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            self:Init()
        end)
        return
    end
    self.initialized = true

    -- Right of the Frame is not offered: saved auras there move to the left (off when taken)
    local db = GetDb()
    if db then
        for _, field in ipairs({ "buffs", "debuffs" }) do
            if db[field] == "RIGHT" then
                local other = field == "buffs" and "debuffs" or "buffs"
                db[field] = db[other] == "LEFT" and "OFF" or "LEFT"
            end
        end
    end

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
        for _, f in ipairs(tiles) do Tile.UpdateAll(f) end
    end)
    LEM:RegisterCallback("exit", function()
        SetAuraPreview(false)
        Refresh()
    end)

    Refresh()
    C_Timer.After(0, Refresh)
end
