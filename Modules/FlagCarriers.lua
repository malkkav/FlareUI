local _, ns = ...
local L = ns.L

--------------------------------------------------
-- FLAG CARRIERS
-- Edit Mode frame "FlareUI Flag Carriers" (Unit Frames > Flag Carrier Frames, off). In a battleground
-- Blizzard shows the flag carriers on its old arena frames (Blizzard_Deprecated_ArenaUI: arena1 and
-- arena2). FlareUI's own frames replace them, on the boss frames' tile kit (PartyFrames.lua), in the
-- player's frame style: the carrier's name, health and power, a class portrait (always), the faction
-- crest FlareUI's target frame uses, a cast bar. No auras (Blizzard's show none). Clicks as Blizzard's: left targets, right sets the focus.
-- Blizzard's container is parked on a hidden frame, out of combat only (it holds secure buttons); a
-- move held back by combat waits for the fight to end. Ours show and hide by a unit watch.
--------------------------------------------------

--------------------------------------------------
-- 1. MODULE REGISTRATION
--------------------------------------------------
ns.FlagCarriers = ns.FlagCarriers or {}
local FC = ns.FlagCarriers
ns.modules["FlagCarriers"] = FC

LibStub("AceEvent-3.0"):Embed(FC)

--------------------------------------------------
-- 2. UPVALUES / CONSTANTS
--------------------------------------------------
local ipairs, pcall, type = ipairs, pcall, type
local math_floor, math_max = math.floor, math.max
local CreateFrame, InCombatLockdown = CreateFrame, InCombatLockdown
local LEM = LibStub("FlareEditMode")
local K = ns.UnitFrames and ns.UnitFrames.Kit
local PF = ns.PartyFrames
local Tile = PF and PF.Tile

local CARRIERS = 2   -- a battleground's flag carriers: one per side
local TILE_TEMPLATE = "SecureUnitButtonTemplate,PingableUnitFrameTemplate,BackdropTemplate"
-- Edit Mode keeps a reference to this table: ApplyPosition refills it for the style in use
-- (Addon Style's spot here, the ring styles' in UnitFramesRing.lua TILE_POSITIONS.flag)
local BASE_POSITION = { point = "RIGHT", x = -36, y = 173 }
local DEFAULT_POSITION = { point = "RIGHT", x = -36, y = 173 }

-- Edit Mode samples: two carriers, one per side
local SAMPLES = {
    { name = "Kaelith", class = "WARRIOR", faction = "Alliance", health = 0.72, power = 0.35, level = 60 },
    { name = "Zorgath", class = "ROGUE",   faction = "Horde",    health = 0.41, power = 0.80, level = 60 },
}

--------------------------------------------------
-- 3. SETTINGS ACCESS
--------------------------------------------------
local holder, hidden
local tiles = {}
local pendingLayout = false

local function GetDb()
    local db = K and K.GetDb()
    return db and db.flagCarriers
end

local function IsEditing()
    return ns.EditPreviewing()
end

-- the tile settings: the flag carriers' db plus fixed values (no auras, no party icons; the role
-- icon's place holds the faction crest, ctx.factionIcon)
-- No range fading and no raid markers, to stay on the safe side: Blizzard's own flag
-- carrier frames show neither, so FlareUI's show nothing more than they do
local ICONS = { role = { shown = true }, leader = { shown = false }, readyCheck = { shown = false },
                status = { shown = false }, raidIcon = { shown = false } }
local FIXED = { buffs = "OFF", debuffs = "OFF", dispels = "OFF", dispelHighlight = "off", portrait = "class",
                auraMax = 5, auraPerRow = 5, rangeCheck = false, raidIcon = false }
-- In FlareUI and Forever Style the boss frames' size preset (UnitFramesRing.lua
-- FOREVER_TILES.boss) where the player set nothing, so both kinds start the same size
local SIZE_KEYS = { width = true, height = true, powerHeight = true, ringSize = true, castHeight = true, spacing = true }
local function RingSize(db, key)
    if not SIZE_KEYS[key] or rawget(db, key) ~= nil then return nil end
    local preset = ns.UFRing and ns.UFRing.TileDefaults("boss")
    return preset and preset[key]
end
local view = setmetatable({}, { __index = function(_, key)
    local db = GetDb()
    if not db then return nil end
    if FIXED[key] ~= nil then return FIXED[key] end
    if key == "icons" then return ICONS end
    local ring = RingSize(db, key)
    if ring ~= nil then return ring end
    return db[key]
end, __newindex = function(_, key, value)
    -- writes land in the db (Forever Style's Scale sets the height through the view)
    local db = GetDb()
    if db then db[key] = value end
end })

local ctx = {
    Settings = function() return view end,
    PreviewData = function(f) return f.sample or SAMPLES[1] end,
    ReadyHold = function() return nil end,
    classic = true, mirror = true, hostile = true, castbar = true,
    barText = true, TextDb = function() return GetDb() end,   -- the unit frames' text slots (PartyFrames.lua PF.SlotOn)
    ringKind = "boss",       -- the target frame's ring in the ring styles (PartyFrames.lua RingKind)
    fontKey = "flag",        -- their own fonts (Unit Frames > Fonts > Flag Carriers)
    factionIcon = true,      -- the faction crest in the role icon's place (PartyFrames.lua UpdateRole)
    noRank = true,           -- no elite / boss art around the ring (UnitFramesRing.lua)
}

local function RingStyle()
    return ns.UFRing and ns.UFRing.Style() ~= "addon" or false
end

--------------------------------------------------
-- 4. TILES AND LAYOUT
--------------------------------------------------
local function CreateTile(i)
    local unit = "arena" .. i
    local f = CreateFrame("Button", "FlareUI_FlagCarrier" .. i, holder, TILE_TEMPLATE)
    f.ctx = ctx
    f.index = i
    f.sample = SAMPLES[i]
    f.fuiUnit = unit
    -- Blizzard's clicks (SecureUnitButton_OnLoad with FocusUnit as its menu): left targets, right
    -- sets the focus; the game's own secure actions, nothing of FlareUI's runs on a click
    f:SetAttribute("unit", unit)
    f:SetAttribute("*type1", "target")
    f:SetAttribute("*type2", "focus")
    f:RegisterForClicks("AnyUp")
    if type(f.SetRolesets) == "function" then pcall(f.SetRolesets, f, "unitFrames") end
    f:SetScript("OnEnter", Tile.OnEnter)
    f:SetScript("OnLeave", Tile.OnLeave)
    _G.ClickCastFrames = _G.ClickCastFrames or {}
    _G.ClickCastFrames[f] = true
    Tile.Build(f, unit)
    tiles[i] = f
    return f
end

local function Step()
    local h = view.height or 50
    if view.castbar then h = h + (view.castHeight or 12) + K.CAST_GAP + K.INSET end
    return 0, h + (view.spacing or 10)
end

local function LayoutHolder()
    if not holder then return end
    local above, step = Step()
    local up = view.grow == "UP"
    for i, f in ipairs(tiles) do
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -(above + (up and (CARRIERS - i) or (i - 1)) * step))
    end
    holder:SetSize(view.width or 180, math_max(1, CARRIERS * step - (view.spacing or 10)))
end

--------------------------------------------------
-- 5. POSITION (per Edit Mode layout)
--------------------------------------------------
local function RefillDefault()
    local base = (RingStyle() and ns.UFRing.TilePosition("flag")) or BASE_POSITION
    DEFAULT_POSITION.point, DEFAULT_POSITION.x, DEFAULT_POSITION.y = base.point, base.x, base.y
end

local function LayoutStore(layoutName)
    local db = GetDb()
    if not db then return nil end
    layoutName = layoutName or LEM:GetActiveLayoutName() or "Modern"
    db.layouts = db.layouts or {}
    return ns.LayoutHome(db.layouts, layoutName)
end

local function ApplyPosition(layoutName)
    if not holder then return end
    if InCombatLockdown() then pendingLayout = true return end
    RefillDefault()
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
-- 6. VISIBILITY: each frame follows its carrier (unit watch, combat-safe); Edit Mode shows both
--------------------------------------------------
-- On top of the boss, party and raid frames when placed over them: the same LOW
-- strata as theirs but far above their frame levels (HOLDER_LEVEL); in Edit Mode, where the party
-- frames rise to MEDIUM (RaidFrames.lua GROUP_LAYERS), one strata higher than that. Children keep
-- the strata they were made with, hence the recursion; out of combat only (secure buttons).
local HOLDER_LEVEL = 200
-- (siblings as varargs: no table per frame)
-- (an aura container's locked buttons are skipped, as in RaidFrames.lua)
local function SetLayer(strata, frame, ...)
    if not frame then return end
    if not frame:IsForbidden() and pcall(frame.SetFrameStrata, frame, strata) then
        SetLayer(strata, frame:GetChildren())
    end
    return SetLayer(strata, ...)
end
local function ApplyLayer(editing)
    local strata = editing and "HIGH" or "LOW"
    if holder.fuiStrata ~= strata then
        holder.fuiStrata = strata
        SetLayer(strata, holder)
    end
end

local function ApplyVisibility()
    if not holder then return end
    if InCombatLockdown() then pendingLayout = true return end
    local editing = IsEditing()
    ApplyLayer(editing)
    for _, f in ipairs(tiles) do
        if editing then
            UnregisterUnitWatch(f)
            f:Show()
        else
            RegisterUnitWatch(f)
        end
    end
end

local function Refresh()
    -- (a Reset Settings in Edit Mode runs this once, after its last setting: LEM:Defer)
    if LEM:Defer(Refresh) then return end
    if not holder then return end
    if InCombatLockdown() then pendingLayout = true return end
    pendingLayout = false
    local db = GetDb()
    -- as the boss frames: Mirror Bars turns the bars; in the ring styles Flip Portrait picks the side
    ctx.fillMirror = not (db and db.mirror == false)
    if RingStyle() then ctx.mirror = not (db and db.portraitRight == false) else ctx.mirror = ctx.fillMirror end
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
-- 7. BLIZZARD'S FRAMES: parked on a hidden frame, out of combat only
--------------------------------------------------
local parking = false
local function Park()
    local container = _G.ArenaEnemyFramesContainer
    if parking or not (container and hidden) then return end
    if InCombatLockdown() then pendingLayout = true return end
    parking = true
    if container:GetParent() ~= hidden then container:SetParent(hidden) end
    parking = false
end

--------------------------------------------------
-- 8. EDIT MODE SETTINGS
--------------------------------------------------
local function BuildSettings()
    local base = (ns.defaults and ns.defaults.profile.unitframes.flagCarriers) or {}
    -- the ring styles' sizes first, as the boss frames' settings do
    local D = setmetatable({}, { __index = function(_, k)
        local preset = SIZE_KEYS[k] and ns.UFRing and ns.UFRing.TileDefaults("boss")
        if preset and preset[k] ~= nil then return preset[k] end
        return base[k]
    end })
    local function get(key)
        return function()
            local v = view[key]
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

    Section("Flag Carriers", {
        { name = L["Growth"], kind = LEM.SettingType.Dropdown, default = D.grow,
          values = { { text = L["Down"], value = "DOWN", isRadio = true }, { text = L["Up"], value = "UP", isRadio = true } },
          desc = L["Which way the second frame goes from the first."],
          get = get("grow"), set = set("grow") },
        { name = L["Frame Gap"], search = L["Spacing"], kind = LEM.SettingType.Slider, default = D.spacing or 10, minValue = 0, maxValue = 80, valueStep = 1,
          get = get("spacing"), set = set("spacing"),
          desc = L["The gap between the two frames."] },
    })

    local function onPlate() return ns.UFRing and ns.UFRing.PlateOn() or false end
    local frameItems = {
        { name = L["Scale"], kind = LEM.SettingType.Slider, default = ns.UFRing and ns.UFRing.PlateDefaultScale("boss") or 100,
          minValue = 50, maxValue = 250, valueStep = 5, formatter = function(value) return value end,   -- plain: "100%" clips the value box
          get = function() local db = GetDb(); return db and db.plateScale or (ns.UFRing and ns.UFRing.PlateDefaultScale("boss")) or 100 end,
          set = function(layoutName, value)
              if not onPlate() then return end
              local db = GetDb()
              if db and ns.SetLayoutPlateScale then
                  db.layouts = db.layouts or {}
                  ns.SetLayoutPlateScale(db.layouts, layoutName or LEM:GetActiveLayoutName() or "Modern", "scale",
                      db, value, ns.UFRing.PlateDefaultScale("boss"))
              elseif db then
                  ns.UFRing.ApplyPlateScale(db, value)
              end
              Refresh()
          end,
          hidden = function() return not onPlate() end,
          desc = L["Each Edit Mode layout keeps its own Scale."] },
        { name = L["Width"], kind = LEM.SettingType.Slider, default = D.width, minValue = 80, maxValue = 400, valueStep = 1, get = get("width"), set = set("width") },
        { name = L["Height"], kind = LEM.SettingType.Slider, default = D.height, minValue = 20, maxValue = 120, valueStep = 1, get = get("height"), set = set("height"),
          hidden = onPlate },
        -- Portrait Scale (11-20, FlareUI Style, as on the unit frames): the ring in proportion, apart from the height
        { name = L["Portrait Scale"], kind = LEM.SettingType.Slider, default = 100, minValue = 50, maxValue = 150, valueStep = 5,
          formatter = function(value) return value end,
          get = function() return get("portraitScale")() or 100 end, set = set("portraitScale"),
          hidden = function() return not (ns.UFRing and ns.UFRing.Style() == "flareui") end,
          desc = L["The portrait ring in percent of its usual size. It keeps its shape, and the frame keeps its height."] },
        { name = L["Power Height"], search = L["Power Bar Height"], kind = LEM.SettingType.Slider, default = D.powerHeight, minValue = 0, maxValue = 30, valueStep = 1,
          get = get("powerHeight"), set = set("powerHeight"), formatter = function(value) return value == 0 and _G.OFF or value end,
          hidden = onPlate },
        K.PlatePowerSetting(function() local db = GetDb(); return db and db.platePower end,
            function(value)
                local db = GetDb()
                if not onPlate() or not db then return end
                db.platePower = value
                Refresh()
            end, onPlate),
        -- the unit frames' Left / Middle / Right text slots, with their defaults (tc's report 11-19)
        ns.BarText.Setting({ name = L["Health Text"], bar = "health", db = GetDb, changed = Refresh,
            style = function() return onPlate() and "plate" or "plain" end }),
        ns.BarText.Setting({ name = L["Power Text"], bar = "power", db = GetDb, changed = Refresh,
            style = function() return onPlate() and "plate" or "plain" end }),
        -- Name Above Frames (BarText.lua): not on Forever Style's plate (its name box)
        ns.NameAbove.Setting({ db = GetDb, changed = Refresh, hidden = onPlate }),
        -- (Forever Style's name box only: elsewhere the name is a Health Text pick)
        { name = L["Show Name"], kind = LEM.SettingType.Checkbox, default = true, get = function() return get("showName")() ~= false end, set = set("showName"),
          hidden = function() return not onPlate() end },
        { name = L["Show Level"], kind = LEM.SettingType.Checkbox, default = D.showLevel == true, get = function() return get("showLevel")() == true end, set = set("showLevel") },
        K.ValuesOnHoverSetting(get("valuesOnHover"), set("valuesOnHover")),
        -- Level Disc Size (11-20, per frame): the ring styles' level disc, with Show Level on
        { name = L["Level Disc Size"], kind = LEM.SettingType.Slider, default = 100, minValue = 50, maxValue = 100, valueStep = 5,
          formatter = function(value) return value end,   -- plain: "100%" clips the value box
          get = function() local v = get("levelSize")(); return math.floor((tonumber(v) or 1) * 100 + 0.5) end,
          set = function(layoutName, value) set("levelSize")(layoutName, value ~= 100 and value / 100 or nil) end,
          hidden = function() return not (ns.UFRing and ns.UFRing.Style() ~= "addon") or not (get("showLevel")() == true) end },
        -- Flip Portrait (on: the portrait on the right) and Mirror Bars, as on the boss frames
        { name = L["Flip Portrait"], kind = LEM.SettingType.Checkbox, default = true,
          desc = L["The portrait on the right, as on the target frame. Off: on the left, as on the player frame."],
          get = function() local db = GetDb(); return not (db and db.portraitRight == false) end,
          set = function(layoutName, value) if value then set("portraitRight")(layoutName, nil) else set("portraitRight")(layoutName, false) end end,
          hidden = function() return not RingStyle() end },
        { name = L["Mirror Bars"], kind = LEM.SettingType.Checkbox, default = D.mirror ~= false,
          get = function() return get("mirror")() ~= false end, set = set("mirror"),
          desc = L["Laid out like the target frame: portrait on the right, bars filling from the right. In FlareUI and Forever Style, only the bars flip."] },
        -- Behaviour
        K.HealthColorSetting(get("healthColor"), set("healthColor")),
    }
    local sizeItems, textItems, behaviourItems = ns.SplitFrameItems(frameItems)
    Section("Size", sizeItems)
    Section("Text", textItems)

    Section("Look", {
        { name = L["Bar Texture"], kind = LEM.SettingType.Dropdown, default = D.texture, values = K.BuildTextureValues(),
          get = get("texture"), set = set("texture") },
        { name = L["Border"], kind = LEM.SettingType.Dropdown, default = D.border, values = K.BuildBorderValues(false),
          get = get("border"), set = set("border"), hidden = K.NoBorderOptions },
        { name = L["Absorb Texture"], kind = LEM.SettingType.Dropdown, default = D.absorbTexture, values = K.BuildAbsorbValues(),
          get = get("absorbTexture"), set = set("absorbTexture"),
          desc = L["The texture of the shield (absorb) over the health bar."] },
        (function()
            local item = K.BgOpacitySetting(K.BAR_BG_OPACITY,
                function() local v = get("bgOpacity")(); if v == nil then return K.BAR_BG_OPACITY end; return v end,
                set("bgOpacity"))
            item.hidden = K.NoBorderOptions
            return item
        end)(),
        -- (11-20) as on every other player frame; unset, it follows the Unit Frames' Class Colours
        K.ClassColorSetting(function() return ns.ClassColorsOn(GetDb()) end, set("classColor")),
        K.SmoothBarsSetting(get("smoothBars"), set("smoothBars")),
        K.BarEdgeGlowSetting(get("barEdgeGlow"), set("barEdgeGlow")),
        K.DamageTrailSetting(get("damageTrail"), set("damageTrail")),
    })
    Section("Behaviour", behaviourItems)

    local function noCast() return get("castbar")() == false end
    Section("Cast Bar", {
        { name = L["Cast Bar"], kind = LEM.SettingType.Checkbox, default = D.castbar ~= false, get = get("castbar"),
          set = function(layoutName, value) set("castbar")(layoutName, value); if holder then LEM:RefreshFrameSettings(holder) end end },
        { name = L["Bar Texture"], canon = "Cast Bar Texture", search = L["Cast Bar Texture"], kind = LEM.SettingType.Dropdown, default = D.castTexture, values = K.BuildTextureValues(),
          get = get("castTexture"), set = set("castTexture"), hidden = noCast },
        { name = L["Border"], canon = "Cast Bar Border", search = L["Cast Bar Border"], kind = LEM.SettingType.Dropdown, default = D.castBorderTexture, values = K.BuildBorderValues(true),
          get = get("castBorderTexture"), set = set("castBorderTexture"),
          hidden = function() return noCast() or K.NoBorderOptions() end,
          desc = L["The cast bar's border. Frame Border matches the frame's own border."] },
        { name = L["Height"], canon = "Cast Bar Height", search = L["Cast Bar Height"], kind = LEM.SettingType.Slider, default = D.castHeight or 12, minValue = 8, maxValue = 40, valueStep = 1,
          get = get("castHeight"), set = set("castHeight"), hidden = noCast },
        { name = L["Position"], canon = "Cast Bar Position", search = L["Cast Bar Position"], kind = LEM.SettingType.Dropdown, default = "BOTTOM",
          values = { { text = L["Above"], value = "TOP", isRadio = true }, { text = L["Below"], value = "BOTTOM", isRadio = true } },
          get = function() return get("castbarPosition")() or "BOTTOM" end, set = set("castbarPosition"), hidden = noCast },
        (function()
            -- the cast bar's own Background (11-20, as on the unit frames); unset, the frame's
            local item = K.BgOpacitySetting(K.BAR_BG_OPACITY,
                function() local v = get("castBgOpacity")(); if v == nil then v = get("bgOpacity")() end; if v == nil then return K.BAR_BG_OPACITY end; return v end,
                set("castBgOpacity"))
            item.canon, item.search, item.hidden = "Cast Bar Background", L["Cast Bar Background"], noCast
            return item
        end)(),
        { name = L["Show Icon"], kind = LEM.SettingType.Checkbox, default = true,
          get = function() return get("castIcon")() ~= false end,
          set = function(layoutName, value) set("castIcon")(layoutName, value and true or false) end,
          hidden = noCast, desc = L["The spell's icon, left of the bar."] },
        { name = L["Show Spell Timer"], kind = LEM.SettingType.Checkbox, default = true,
          get = function() return get("castTimer")() ~= false end,
          set = function(layoutName, value) set("castTimer")(layoutName, value and true or false) end,
          hidden = noCast, desc = L["The time left, at the right end of the bar."] },
        { name = L["Edge Glow"], kind = LEM.SettingType.Checkbox, default = ns.CastGlowDefault(),
          get = function() return ns.CastGlowOn(get("castGlow")()) end,
          set = function(layoutName, value) set("castGlow")(layoutName, value and true or false) end,
          hidden = noCast, desc = L["A bright edge at the front of the cast, as on Blizzard's cast bars."] },
    })

    return settings
end

--------------------------------------------------
-- 9. PUBLIC
--------------------------------------------------
function FC:Refresh()
    Refresh()
end

function FC:ShouldLoad()
    local uf = ns.db and ns.db.profile and ns.db.profile.unitframes
    return uf and uf.enabled and uf.flagCarriers and uf.flagCarriers.enabled and Tile and K and true or false
end

function FC:OnGlobalEvent(event)
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingLayout then Refresh(); Park() end
        return
    end
    if IsEditing() then return end
    for _, f in ipairs(tiles) do
        if f:IsShown() then
            if event == "PLAYER_TARGET_CHANGED" then
                Tile.UpdateTarget(f)
            else
                Tile.UpdateAll(f)   -- the carriers changed
            end
        end
    end
end

local GLOBAL_EVENTS = {
    "ARENA_OPPONENT_UPDATE", "PLAYER_TARGET_CHANGED",
    "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
}

function FC:Init()
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

    hidden = CreateFrame("Frame")
    hidden:Hide()
    holder = CreateFrame("Frame", "FlareUI_FlagCarriers", UIParent)
    holder:SetFrameStrata("LOW")
    holder.fuiStrata = "LOW"
    holder:SetFrameLevel(HOLDER_LEVEL)   -- before the tiles: their parts are levelled from it
    holder:SetClampedToScreen(true)
    holder:SetSize(180, 100)
    holder.editModeName = "FlareUI Flag Carriers"
    for i = 1, CARRIERS do CreateTile(i) end

    RefillDefault()
    LEM:AddFrame(holder, OnFrameMoved, DEFAULT_POSITION, "FlareUI Flag Carriers")
    LEM:AddFrameSettings(holder, BuildSettings())

    -- Blizzard hands its container back to its column on every show: parked again each time
    local container = _G.ArenaEnemyFramesContainer
    if container then
        hooksecurefunc(container, "SetParent", Park)
        Park()
    end

    for _, event in ipairs(GLOBAL_EVENTS) do self:RegisterEvent(event, "OnGlobalEvent") end
    -- a carrier changing hands with no event: a new readable GUID repaints
    C_Timer.NewTicker(0.25, function()
        if not holder:IsShown() or IsEditing() then return end
        for _, f in ipairs(tiles) do
            if f.fuiUnit and f:IsVisible() then
                local guid = UnitGUID(f.fuiUnit)
                if canaccessvalue(guid) and guid and guid ~= f.carrierGuid then
                    f.carrierGuid = guid
                    Tile.UpdateAll(f)
                end
            end
        end
    end)

    LEM:RegisterCallback("layout", function(layoutName)
        local db = GetDb()
        if db and db.layouts and ns.ApplyLayoutPlateScale and ns.UFRing and ns.UFRing.PlateOn()
            and ns.ApplyLayoutPlateScale(db.layouts, layoutName, "scale", db) then
            Refresh()
        end
        ApplyPosition(layoutName)
    end)
    local function ShowPreview()
        -- (out of a fight Refresh already shows and draws both samples)
        if not InCombatLockdown() then LayoutHolder(); Refresh() return end
        ApplyVisibility()
        for _, f in ipairs(tiles) do Tile.UpdateAll(f) end
    end
    LEM:RegisterCallback("enter", ShowPreview)
    LEM:RegisterCallback("exit", Refresh)
    ns.OnEditFight(function() if IsEditing() then ShowPreview() else Refresh() end end)

    Refresh()
    C_Timer.After(0, Refresh)
end
