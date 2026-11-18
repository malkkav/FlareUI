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
local BASE_POSITION = { point = "RIGHT", x = -10, y = -11 }
-- Edit Mode keeps a reference to this table: ApplyPosition refills it for the style in use
local DEFAULT_POSITION = { point = "RIGHT", x = -10, y = -11 }
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
for _, s in ipairs(SAMPLES) do s.rgb = HOSTILE_RGB; s.classification = "worldboss" end

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

-- Edit Mode, unless a fight ended its previews (ns.OnEditFight)
local function IsEditing()
    return ns.EditPreviewing()
end

-- The tile settings: the boss db plus fixed values (no party icons or dispels; five
-- auras to a row)
local ICONS = { role = { shown = false }, leader = { shown = false }, readyCheck = { shown = false },
                status = { shown = false }, raidIcon = {}, classification = {} }
-- (amountTile: Buff / Debuff Amount apply, PartyFrames.lua PF.AmountTile)
local FIXED = { dispelHighlight = "off", dispels = "OFF", auraMax = 5, auraPerRow = 5, amountTile = true }
local view = setmetatable({}, { __index = function(_, key)
    local db = GetDb()
    if not db then return nil end
    if FIXED[key] ~= nil then return FIXED[key] end
    -- Portrait: None / 2D ("3d"); an older switch saved true / false, and a saved 3D model ("model")
    -- draws as 2D
    if key == "portrait" then
        local v = db.portrait
        if v == "model" then return "3d" end
        if type(v) == "string" then return v end
        return v and "3d" or "none"
    end
    if key == "icons" then
        ICONS.raidIcon.shown = db.raidIcon ~= false
        ICONS.classification.shown = db.classIcon ~= false
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
    classIcon = true,    -- the Elite & Rare skull in Addon Style (PartyFrames.lua PF.UpdateClassIcon)
    fontKey = "boss",    -- the boss frames' fonts (PartyFrames.lua PF.FontKey)
}
-- for the settings previews' sample tiles
BF.PreviewCtx, BF.PreviewSamples = ctx, SAMPLES

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
    f.fuiUnit = unit
    f:SetAttribute("unit", unit)
    f:SetAttribute("*type1", "target")
    f:SetAttribute("*type2", "togglemenu")
    f:RegisterForClicks("AnyUp")
    if type(f.SetRolesets) == "function" then pcall(f.SetRolesets, f, "unitFrames") end
    f:SetScript("OnEnter", Tile.OnEnter)
    f:SetScript("OnLeave", Tile.OnLeave)
    -- after the scripts: a click-cast addon wraps OnEnter / OnLeave as it registers the frame
    _G.ClickCastFrames = _G.ClickCastFrames or {}
    _G.ClickCastFrames[f] = true
    Tile.Build(f, unit)
    pcall(f.RegisterUnitEvent, f, "UNIT_TARGETABLE_CHANGED", unit)
    -- the tile shows the player's threat on this boss: its threat list, and the player's situation
    pcall(f.RegisterUnitEvent, f, "UNIT_THREAT_LIST_UPDATE", unit)
    pcall(f.RegisterUnitEvent, f, "UNIT_THREAT_SITUATION_UPDATE", unit, "player")
    tiles[i] = f
    return f
end

-- The first frame's offset, and the step between frames (frame, cast bar, auras, spacing)
local function Step()
    local above = Tile.LanesExtent(view, Tile.ABOVE_PLACES)
    local below = Tile.LanesExtent(view, Tile.BELOW_PLACES)
    local h = view.height or 50
    if view.castbar then h = h + (view.castHeight or 14) + K.CAST_GAP + K.INSET end
    return above, above + h + below + (view.spacing or 14)
end

-- The bosses there close up, in boss order, from the top (the bottom for Growth Up): a boss that
-- despawns leaves no gap. Bosses come and go in combat, when secure frames can only be moved by
-- secure code, so a stacker does it: one attribute per boss slot follows [@bossN,exists], and its
-- snippet re-anchors the tiles of the bosses there. Edit Mode shows all five in their places.
local STACK_SNIPPET = [[
    if name:sub(1, 10) ~= "state-boss" or self:GetAttribute("editing") then return end
    local above, step, up, count = self:GetAttribute("above"), self:GetAttribute("step"), self:GetAttribute("up"), self:GetAttribute("count")
    if not (above and step and count) then return end
    local slot = 0
    for i = 1, count do
        local v = self:GetAttribute("state-boss" .. i)
        if v == 1 or v == "1" then
            local tile = self:GetFrameRef("tile" .. i)
            local s = up and (count - 1 - slot) or slot
            tile:ClearAllPoints()
            tile:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -(above + s * step))
            slot = slot + 1
        end
    end
]]

local function CreateStacker()
    local st = CreateFrame("Frame", nil, holder, "SecureHandlerAttributeTemplate")
    st:SetAllPoints(holder)
    for i, f in ipairs(tiles) do SecureHandlerSetFrameRef(st, "tile" .. i, f) end
    st:SetAttribute("count", MAX_BOSSES)
    st:SetAttribute("_onattributechanged", STACK_SNIPPET)
    holder.Stacker = st
    for i = 1, MAX_BOSSES do
        RegisterAttributeDriver(st, "state-boss" .. i, ("[@boss%d,exists] 1; 0"):format(i))
    end
end

local function LayoutHolder()
    if not holder then return end
    local above, step = Step()
    local up = view.grow == "UP"
    local st = holder.Stacker
    local editing = IsEditing()
    if st then
        st:SetAttribute("above", above)
        st:SetAttribute("step", step)
        st:SetAttribute("up", up)
        st:SetAttribute("editing", editing)
    end
    local slot = 0
    for i, f in ipairs(tiles) do
        local here = editing or not st or tonumber(st:GetAttribute("state-boss" .. i)) == 1
        -- a boss not there keeps its own place (hidden), a boss there takes the next free one
        local s = here and slot or (i - 1)
        if here then slot = slot + 1 end
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", st or holder, "TOPLEFT", 0, -(above + (up and (MAX_BOSSES - 1 - s) or s) * step))
    end
    holder:SetSize(view.width or 200, math_max(1, MAX_BOSSES * step - (view.spacing or 14)))
end

--------------------------------------------------
-- 5. POSITION (per Edit Mode layout)
--------------------------------------------------
local function LayoutStore(layoutName)
    local db = GetDb()
    if not db then return nil end
    layoutName = layoutName or LEM:GetActiveLayoutName() or "Modern"
    db.layouts = db.layouts or {}
    -- (a layout with no spot of its own reads the profile's home layout's: ProfileLayout.lua)
    return ns.LayoutHome(db.layouts, layoutName)
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
    -- (a Reset Settings in Edit Mode runs this once, after its last setting: LEM:Defer)
    if LEM:Defer(Refresh) then return end
    if not holder then return end
    if InCombatLockdown() then pendingLayout = true return end
    pendingLayout = false
    local db = GetDb()
    -- the ring styles keep the target frame's layout: Mirror turns only the bars there
    ctx.fillMirror = not (db and db.mirror == false)
    -- the ring styles: Flip Portrait (db.portraitRight, on by default) puts the portrait
    -- on the right, as the target frame; off, on the left. Addon Style: Mirror Bars lays it out.
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
        -- ("Frame Gap", as on the party and raid frames; found by "Spacing" too)
        { name = L["Frame Gap"], search = L["Spacing"], kind = LEM.SettingType.Slider, default = D.spacing or 14, minValue = 0, maxValue = 80, valueStep = 1,
          get = get("spacing"), set = set("spacing"),
          desc = L["The gap between the boss frames."] },
    })

    -- Forever Style's plate: sized by Scale
    local function onPlate() return ns.UFRing and ns.UFRing.PlateOn() or false end
    -- the frame's own rows: Size and Text here, Behaviour after Look (Core.lua ns.SplitFrameItems)
    local frameItems = {
        { name = L["Scale"], kind = LEM.SettingType.Slider, default = ns.UFRing and ns.UFRing.PlateDefaultScale("boss") or 100,
          minValue = 75, maxValue = 250, valueStep = 5, formatter = function(value) return value end,   -- plain: "100%" clips the value box
          get = function() local db = GetDb(); return db and db.plateScale or (ns.UFRing and ns.UFRing.PlateDefaultScale("boss")) or 100 end,
          set = function(layoutName, value)
              if not onPlate() then return end
              -- saved for this Edit Mode layout (ProfileLayout.lua)
              local db = GetDb()
              if db and ns.SetLayoutPlateScale then
                  db.layouts = db.layouts or {}
                  ns.SetLayoutPlateScale(db.layouts, layoutName or LEM:GetActiveLayoutName() or "Modern", "scale",
                      db, value, ns.UFRing.PlateDefaultScale("boss"))
              else
                  ns.UFRing.ApplyPlateScale(db, value)
              end
              Refresh()
          end,
          hidden = function() return not onPlate() end,
          desc = L["Each Edit Mode layout keeps its own Scale."] },
        { name = L["Width"], kind = LEM.SettingType.Slider, default = D.width, minValue = 80, maxValue = 400, valueStep = 1, get = get("width"), set = set("width") },
        { name = L["Height"], kind = LEM.SettingType.Slider, default = D.height, minValue = 20, maxValue = 120, valueStep = 1, get = get("height"), set = set("height"),
          hidden = onPlate },
        { name = L["Power Height"], search = L["Power Bar Height"], kind = LEM.SettingType.Slider, default = D.powerHeight, minValue = 0, maxValue = 30, valueStep = 1,
          get = get("powerHeight"), set = set("powerHeight"), formatter = function(value) return value == 0 and _G.OFF or value end,
          hidden = onPlate },
        K.PlatePowerSetting(function() local db = GetDb(); return db and db.platePower end,
            function(value)
                -- (Edit Mode's reset runs hidden settings too)
                local db = GetDb()
                if not onPlate() or not db then return end
                db.platePower = value
                Refresh()
            end, onPlate),
        { name = L["Health Text"], kind = LEM.SettingType.Dropdown, default = D.healthText, values = K.HEALTH_TEXT_MODES, get = get("healthText"), set = set("healthText") },
        { name = L["Power Text"], kind = LEM.SettingType.Dropdown, default = "value", values = K.POWER_TEXT_MODES,
          get = function() local db = GetDb(); return K.PowerTextMode(db and db.powerText) end, set = set("powerText") },
        { name = L["Show Name"], kind = LEM.SettingType.Checkbox, default = true, get = function() return get("showName")() ~= false end, set = set("showName") },
        { name = L["Show Level"], kind = LEM.SettingType.Checkbox, default = D.showLevel ~= false, get = get("showLevel"), set = set("showLevel") },
        -- Flip Portrait, as on target and focus: on, the portrait on the right (default);
        -- off, on the left (db.portraitRight); the ring styles only, as there
        { name = L["Flip Portrait"], kind = LEM.SettingType.Checkbox, default = true,
          desc = L["The portrait on the right, as on the target frame. Off: on the left, as on the player frame."],
          get = function() local db = GetDb(); return not (db and db.portraitRight == false) end,
          set = function(layoutName, value) if value then set("portraitRight")(layoutName, nil) else set("portraitRight")(layoutName, false) end end,
          hidden = function() return not RingStyle() end },
        { name = L["Mirror Bars"], kind = LEM.SettingType.Checkbox, default = D.mirror ~= false,
          get = function() return get("mirror")() ~= false end, set = set("mirror"),
          desc = L["Laid out like the target frame: portrait on the right, bars filling from the right. In FlareUI and Forever Style, only the bars flip."] },
        -- None / 2D; the ring always has a (2D) portrait, so the row hides in the ring styles
        { name = L["Portrait"], kind = LEM.SettingType.Dropdown, default = "none",
          values = { { text = L["None"], value = "none", isRadio = true }, { text = L["2D"], value = "3d", isRadio = true } },
          get = function() return view.portrait end,
          set = set("portrait"), hidden = RingStyle },
        -- (in Frame: it changes how the frame behaves, not how it looks)
        { name = L["Range Check"], kind = LEM.SettingType.Checkbox, default = true,
          desc = L["The frame fades while the unit is out of range."],
          get = function() return get("rangeCheck")() ~= false end, set = set("rangeCheck") },
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
            item.hidden = K.NoBorderOptions   -- Forever Style's plate
            return item
        end)(),
        K.SmoothBarsSetting(get("smoothBars"), set("smoothBars")),
        K.BarEdgeGlowSetting(get("barEdgeGlow"), set("barEdgeGlow")),
        K.DamageTrailSetting(get("damageTrail"), set("damageTrail")),
        -- Threat Glow: in Look (Core.lua orders the section)
        { name = L["Threat Glow"], kind = LEM.SettingType.Checkbox, default = true,
          desc = L["The border pulses in the threat colour while you have threat on it."],
          get = function() return get("threatGlow")() ~= false end, set = set("threatGlow") },
    })
    Section("Behaviour", behaviourItems)

    local function noCast() return get("castbar")() == false end
    Section("Cast Bar", {
        { name = L["Cast Bar"], kind = LEM.SettingType.Checkbox, default = D.castbar ~= false, get = get("castbar"),
          set = function(layoutName, value) set("castbar")(layoutName, value); if holder then LEM:RefreshFrameSettings(holder) end end },
        { name = L["Bar Texture"], canon = "Cast Bar Texture", search = L["Cast Bar Texture"], kind = LEM.SettingType.Dropdown, default = D.castTexture, values = K.BuildTextureValues(),
          get = get("castTexture"), set = set("castTexture"), hidden = noCast, },
        { name = L["Border Texture"], canon = "Cast Bar Border", search = L["Cast Bar Border"], kind = LEM.SettingType.Dropdown, default = D.castBorderTexture, values = K.BuildBorderValues(true),
          get = get("castBorderTexture"), set = set("castBorderTexture"),
          hidden = function() return noCast() or K.NoBorderOptions() end,
          desc = L["The cast bar's border. Frame Border matches the frame's own border."] },
        { name = L["Height"], canon = "Cast Bar Height", search = L["Cast Bar Height"], kind = LEM.SettingType.Slider, default = D.castHeight or 14, minValue = 8, maxValue = 30, valueStep = 1,
          get = get("castHeight"), set = set("castHeight"), hidden = noCast },
        { name = L["Show Icon"], kind = LEM.SettingType.Checkbox, default = true,
          get = function() return get("castIcon")() ~= false end,
          set = function(layoutName, value) set("castIcon")(layoutName, value and true or false) end,
          hidden = noCast,
          desc = L["The spell's icon, left of the bar."] },
        { name = L["Show Spell Timer"], kind = LEM.SettingType.Checkbox, default = true,
          get = function() return get("castTimer")() ~= false end,
          set = function(layoutName, value) set("castTimer")(layoutName, value and true or false) end,
          hidden = noCast,
          desc = L["The time left, at the right end of the bar."] },
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
    Section("Auras", ns.AuraOrder.With({
        { name = L["Buffs"], kind = LEM.SettingType.Dropdown, default = D.buffs, values = places, generator = Place("buffs", "debuffs"),
          get = get("buffs"), set = set("buffs"), desc = L["Every buff on the boss, such as enrages and shields."] },
        { name = L["Debuffs"], kind = LEM.SettingType.Dropdown, default = D.debuffs, values = places, generator = Place("debuffs", "buffs"),
          get = get("debuffs"), set = set("debuffs"), desc = L["Debuffs on the boss. With Only My Debuffs, just yours."] },
        K.HideBuffsSetting("OFF", function() return get("hideBuffs")() or "OFF" end, set("hideBuffs")),
        { name = L["Buff Size"], kind = LEM.SettingType.Slider, default = D.auraSize, minValue = 10, maxValue = 40, valueStep = 1,
          get = function() return ns.AuraSize(GetDb(), false, D.auraSize) end, set = set("buffSize") },
        { name = L["Debuff Size"], kind = LEM.SettingType.Slider, default = D.auraSize, minValue = 10, maxValue = 40, valueStep = 1,
          get = function() return ns.AuraSize(GetDb(), true, D.auraSize) end, set = set("debuffSize") },
        PF.AmountSetting(get, set, false),
        PF.AmountSetting(get, set, true),
        { name = L["Only My Debuffs"], kind = LEM.SettingType.Checkbox, default = D.onlyMyDebuffs ~= false,
          get = function() return get("onlyMyDebuffs")() ~= false end, set = set("onlyMyDebuffs") },
    }, get, set))

    Section("Icons", {
        -- as on the target frame; the ring styles show the rank with the ring's dragon
        { name = L["Elite & Rare"], kind = LEM.SettingType.Checkbox, default = true,
          get = function() return get("classIcon")() ~= false end, set = set("classIcon"),
          hidden = RingStyle },
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

-- The boss frames' default spot and their holder's height, for frames that start where they do
-- (FlagCarriers.lua); works with the boss frames off too
function BF.DefaultSpot()
    local base = RingStyle() and ns.UFRing.TilePosition("boss") or BASE_POSITION
    local h = holder and holder:GetHeight()
    if not (h and h > 1) and K and Tile then
        local ok, _, step = pcall(Step)
        if ok and step then h = MAX_BOSSES * step - (view.spacing or 14) end
    end
    return base.point, base.x, base.y, h
end

function BF:ShouldLoad()
    local db = K and K.GetDb()
    return db and db.enabled and db.boss and db.boss.enabled and Tile and true or false
end

function BF:OnGlobalEvent(event)
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingLayout then Refresh() end
        return
    end
    if IsEditing() then return end
    -- the slots are still settling when the engage event lands: repaint once more next frame
    if event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
        C_Timer.After(0, function() BF:OnGlobalEvent("SETTLED") end)
    end
    for _, f in ipairs(tiles) do
        if f:IsShown() then
            if event == "PLAYER_TARGET_CHANGED" then
                Tile.UpdateTarget(f)
            elseif event == "RAID_TARGET_UPDATE" then
                Tile.UpdateRaidIcon(f)
            else
                Tile.UpdateAll(f)   -- the bosses changed
            end
        end
    end
end

local GLOBAL_EVENTS = {
    "INSTANCE_ENCOUNTER_ENGAGE_UNIT", "PLAYER_TARGET_CHANGED", "RAID_TARGET_UPDATE",
    "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
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
    CreateStacker()

    LEM:AddFrame(holder, OnFrameMoved, DEFAULT_POSITION, "FlareUI Boss Frames")
    LEM:AddFrameSettings(holder, BuildSettings())
    HideBlizzardBoss()

    for _, event in ipairs(GLOBAL_EVENTS) do self:RegisterEvent(event, "OnGlobalEvent") end
    -- out of range fading: no event covers a boss's range
    C_Timer.NewTicker(0.25, function()
        if not holder:IsShown() then return end
        for _, f in ipairs(tiles) do
            if f.fuiUnit and f:IsVisible() then
                Tile.UpdateRange(f)
                -- a boss slot can change hands with no event (an add takes boss2, the old boss2
                -- moves to boss3): a new readable GUID repaints the tile, name and auras included
                local guid = not IsEditing() and UnitGUID(f.fuiUnit)
                if canaccessvalue(guid) and guid and guid ~= f.bossGuid then
                    f.bossGuid = guid
                    Tile.UpdateAll(f)
                end
            end
        end
    end)

    LEM:RegisterCallback("layout", function(layoutName)
        -- Forever Style's Scale, saved per layout (ProfileLayout.lua); Refresh waits for a fight's end
        local db = GetDb()
        if db and db.layouts and ns.ApplyLayoutPlateScale and ns.UFRing and ns.UFRing.PlateOn()
            and ns.ApplyLayoutPlateScale(db.layouts, layoutName, "scale", db) then
            Refresh()
        end
        ApplyPosition(layoutName)
    end)
    local function ShowPreview()
        -- the aura rows are built again for Edit Mode: the fight's purge split filters by
        -- RAID_PLAYER_DISPELLABLE, and Blizzard's sample list reads any "RAID" in a filter as raid auras
        -- only, so the buffs row would have no samples
        if not InCombatLockdown() then LayoutHolder(); Refresh() end   -- the samples in all five places
        ApplyVisibility()
        SetAuraPreview(true)
        -- (out of a fight Refresh already drew all five)
        if InCombatLockdown() then
            for _, f in ipairs(tiles) do Tile.UpdateAll(f) end
        end
    end
    local function EndPreview()
        SetAuraPreview(false)
        Refresh()
    end
    LEM:RegisterCallback("enter", ShowPreview)
    LEM:RegisterCallback("exit", EndPreview)
    ns.OnEditFight(function() if IsEditing() then ShowPreview() else EndPreview() end end)

    Refresh()
    C_Timer.After(0, Refresh)
end
