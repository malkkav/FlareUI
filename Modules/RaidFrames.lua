local _, ns = ...
local L = ns.L

--------------------------------------------------
-- RAID FRAMES
-- Raid frames: everyone in a raid, on the party frames' Raid-Style tile (PartyFrames.lua's tile kit)
-- with settings of their own. Blizzard's secure group headers hand out the units, so the roster can
-- change in a fight. The raid stays centred on the frame's position as it grows: a small restricted
-- snippet places the groups around the middle whenever a group gains or loses its first member.
-- Also: main tank frames and the missing-buff reminder (the classic group buffs you can cast). Party frames show in a party, these in a raid.
--------------------------------------------------

--------------------------------------------------
-- 1. MODULE REGISTRATION
--------------------------------------------------
ns.RaidFrames = ns.RaidFrames or {}
local RF = ns.RaidFrames
ns.modules["RaidFrames"] = RF

LibStub("AceEvent-3.0"):Embed(RF)

--------------------------------------------------
-- 2. UPVALUES / CONSTANTS
--------------------------------------------------
local pairs, ipairs, pcall, type = pairs, ipairs, pcall, type
local math_floor, math_max, math_min, math_ceil = math.floor, math.max, math.min, math.ceil
local CreateFrame, InCombatLockdown = CreateFrame, InCombatLockdown
local LEM = LibStub("FlareEditMode")
local K = ns.UnitFrames and ns.UnitFrames.Kit
local PF = ns.PartyFrames

local canaccessvalue = canaccessvalue or function() return true end
local function readable(v) if canaccessvalue(v) then return v end end

local MAX_GROUPS, GROUP_SIZE, MAX_RAID = 8, 5, 40
local MAX_TANKS = 4
local TILE_TEMPLATE = "SecureUnitButtonTemplate,PingableUnitFrameTemplate,BackdropTemplate"
local DEFAULT_POSITION = { point = "LEFT", x = 2, y = 0 }
local TANK_DEFAULT_POSITION = { point = "BOTTOMLEFT", x = 2, y = 230 }
local RANGE_INTERVAL = 0.5
local READY_CHECK_HOLD = 6
local INSIDE = { "INSIDE_TOPLEFT", "INSIDE_TOPRIGHT", "INSIDE_BOTTOMLEFT", "INSIDE_BOTTOMRIGHT" }
-- Edit Mode's sample raids: 10, 25 or 40 players (every raid size uses the same settings)
local SAMPLE_RAIDS = { small = 2, medium = 5, large = 8 }   -- groups shown
local DEFAULT_W, DEFAULT_H = 90, 55
local CLASS_ORDER = "WARRIOR,DRUID,PALADIN,SHAMAN,PRIEST,MAGE,WARLOCK,HUNTER,ROGUE"
local ROLE_ORDER = "TANK,HEALER,DAMAGER,NONE"

-- Each tile's setup in the restricted environment (sizes and clicks are protected in a fight; the
-- header may make a tile then), then the Lua side (InitTile)
local INIT_SNIPPET = [[
    local header = self:GetParent()
    self:SetWidth(header:GetAttribute("tileWidth") or 90)
    self:SetHeight(header:GetAttribute("tileHeight") or 44)
    self:SetAttribute("*type1", "target")
    self:SetAttribute("*type2", "togglemenu")
    header:CallMethod("InitTile", self:GetName())
]]

-- Group mode: the groups in use, side by side (columns) or stacked (rows), centred on the frame.
-- Runs in the restricted environment, so it also works in a fight.
local LAYOUT_SNIPPET = [[
    if self:GetAttribute("mode") ~= "group" then return end
    local rows = self:GetAttribute("rows")
    local w, h = self:GetAttribute("tileW"), self:GetAttribute("tileH")
    local gap, ggap = self:GetAttribute("gap"), self:GetAttribute("groupGap")
    local used = 0
    local order = newtable()
    for k = 1, 8 do
        local c = self:GetFrameRef("c" .. k)
        if c and c:GetAttribute("unit") then
            used = used + 1
            order[used] = self:GetFrameRef("g" .. k)
        end
    end
    if used == 0 then return end
    local span = rows and h or w
    local across = 5 * (rows and w or h) + 4 * gap
    local total = used * span + (used - 1) * ggap
    for i = 1, used do
        local g = order[i]
        local offset = (i - 1) * (span + ggap) - total / 2
        g:ClearAllPoints()
        if rows then
            g:SetPoint("TOPLEFT", self, "CENTER", -across / 2, -offset)
        else
            g:SetPoint("TOPLEFT", self, "CENTER", offset, across / 2)
        end
    end
]]
-- a group's first tile changing hands: the groups take their places again
local WRAP_SNIPPET = [[ if name == "unit" then control:RunAttribute("layout") end ]]

-- Edit Mode samples: a raid of five-player groups (a tank, a healer, three damage dealers)
local SAMPLE_NAMES = {
    "Thalorien", "Elysande", "Morwen", "Sylvara", "Kestrel", "Brannoc", "Ysolde", "Garrick", "Liora", "Tamsin",
    "Orwyn", "Fenna", "Draven", "Isolde", "Corwin", "Maelis", "Torvald", "Seraphine", "Jorund", "Aveline",
    "Bastian", "Rowena", "Caelum", "Edric", "Nimue", "Halvard", "Oriel", "Thessaly", "Varric", "Wenna",
    "Aldric", "Brisa", "Cedran", "Dalia", "Emeric", "Faelan", "Gwyneth", "Hollis", "Ingrid", "Jessamy",
}
local SAMPLE_TANKS   = { "WARRIOR", "DRUID", "WARRIOR", "PALADIN", "WARRIOR", "DRUID", "WARRIOR", "WARRIOR" }
local SAMPLE_HEALERS = { "PRIEST", "DRUID", "PALADIN", "PRIEST", "SHAMAN", "PRIEST", "DRUID", "PRIEST" }
local SAMPLE_DPS     = { "MAGE", "ROGUE", "WARLOCK", "HUNTER", "MAGE", "ROGUE", "WARRIOR", "WARLOCK", "HUNTER", "MAGE",
                         "ROGUE", "WARLOCK", "HUNTER", "MAGE", "ROGUE", "WARLOCK", "HUNTER", "MAGE", "ROGUE", "WARLOCK",
                         "HUNTER", "MAGE", "ROGUE", "WARLOCK" }
local SAMPLES = {}
do
    local dps = 0
    for i = 1, MAX_RAID do
        local group, slot = math_ceil(i / GROUP_SIZE), (i - 1) % GROUP_SIZE + 1
        local role, class
        if slot == 1 then role, class = "TANK", SAMPLE_TANKS[group]
        elseif slot == 2 then role, class = "HEALER", SAMPLE_HEALERS[group]
        else dps = dps + 1; role, class = "DAMAGER", SAMPLE_DPS[dps] end
        SAMPLES[i] = { name = SAMPLE_NAMES[i], class = class, role = role,
                       health = 0.35 + ((i * 37) % 63) / 100, power = 0.4 + ((i * 53) % 55) / 100 }
    end
    SAMPLES[1].leader = true
    SAMPLES[3].marker, SAMPLES[3].highlight = 8, "Magic"
    SAMPLES[7].ready = "ready"
    SAMPLES[9].status = "IncomingResurrection"
    SAMPLES[12].dead, SAMPLES[12].health = true, 0
    SAMPLES[14].missing = { "fort", "mark" }
    SAMPLES[18].missing = { "int" }
    SAMPLES[21].marker = 1
    -- buffs and debuffs on some samples
    for i = 1, MAX_RAID do
        if i % 3 == 0 then SAMPLES[i].buffs = 1 + i % 2 end
        if i % 4 == 1 then SAMPLES[i].debuffs = 1 + i % 3 end
    end
    SAMPLES[4].bossDebuff = true
end

--------------------------------------------------
-- 3. SETTINGS ACCESS
--------------------------------------------------
local holder, tankHolder
local headers = {}          -- g1..g8 (group mode), all (role / class sort), tanks
local tiles = {}            -- every live tile
local previewTiles, tankPreview = {}, {}
local pendingLayout = false
local readyHold             -- C_Timer handle while a finished check's results stay up
local sampleRaid = "medium"   -- Edit Mode's sample raid (not saved)
local MB = {}               -- the missing-buff reminder (section 8)

local function GetDb()
    local db = K and K.GetDb()
    return db and db.raid
end

local function IsEditing()
    return LEM:IsInEditMode()
end

local function TileSize()
    local db = GetDb()
    return (db and db.width) or DEFAULT_W, (db and db.height) or DEFAULT_H
end

local function TankSize()
    local db = GetDb()
    local mt = db and db.mainTanks or {}
    return mt.w or 182, mt.h or 55
end

-- What a tile reads: the raid settings, at the size in use, without a cast bar
local function View(sizeFn)
    return setmetatable({}, { __index = function(_, key)
        local db = GetDb()
        if not db then return nil end
        if key == "width" then return (sizeFn()) end
        if key == "height" then return (select(2, sizeFn())) end
        if key == "castbar" then return false end
        return db[key]
    end })
end
local raidView = View(TileSize)
local tankView = View(TankSize)

local raidCtx = {
    Settings = function() return raidView end,
    PreviewData = function(f) return f.sample or SAMPLES[1] end,
    ReadyHold = function() return readyHold end,
}
local tankCtx = {
    Settings = function() return tankView end,
    PreviewData = function(f) return f.sample or SAMPLES[1] end,
    ReadyHold = function() return readyHold end,
}

local function Mode()
    local db = GetDb()
    return (db and db.sort ~= "GROUP" and db.sort) and "flat" or "group"
end

local function Rows()
    local db = GetDb()
    return not db or db.orientation ~= "COLUMNS"
end

--------------------------------------------------
-- 4. TILES
--------------------------------------------------
local Tile = PF and PF.Tile

-- the player's own tile is never faded for range
local function UpdateRange(f)
    if not f.unit then return end
    if readable(UnitIsUnit(f.unit, "player")) then f:SetAlpha(1) return end
    Tile.UpdateRange(f)
end

-- A header made a tile (from the restricted setup above; out of a fight it is made up front)
local function InitTile(header, name)
    local f = _G[name]
    if not f or f.flareTile then return end
    f.flareTile = true
    f.ctx = header.ctx
    f.auraPositions = INSIDE
    f:RegisterForClicks("AnyUp")
    if type(f.SetRolesets) == "function" then pcall(f.SetRolesets, f, "unitFrames") end
    _G.ClickCastFrames = _G.ClickCastFrames or {}
    _G.ClickCastFrames[f] = true
    f:SetScript("OnEnter", Tile.OnEnter)
    f:SetScript("OnLeave", Tile.OnLeave)
    Tile.Build(f, nil)
    f:HookScript("OnAttributeChanged", function(self, attr, value)
        if attr == "unit" then
            Tile.SetUnit(self, value)
            MB.Update(self)
        end
    end)
    if f.ctx == raidCtx then
        MB.Attach(f)
        f:HookScript("OnShow", MB.Update)   -- a tile can get its unit before the raid frame shows
    end
    tiles[#tiles + 1] = f
    if not InCombatLockdown() then pcall(Tile.Layout, f) end
end

local function NewHeader(name, parent, ctx, count)
    local h = CreateFrame("Frame", name, parent, "SecureGroupHeaderTemplate")
    h.ctx = ctx
    h.InitTile = InitTile
    h:SetAttribute("template", TILE_TEMPLATE)
    h:SetAttribute("showRaid", true)
    h:SetAttribute("initialConfigFunction", INIT_SNIPPET)
    h:SetAttribute("minWidth", 0.1)
    h:SetAttribute("minHeight", 0.1)
    h.count = count
    return h
end

-- makes all of a header's tiles now (out of a fight): the header is shown with a start far before
-- its first unit, then set back
local function Precreate(h)
    if h.precreated then return end
    h.precreated = true
    local parent = h:GetParent()
    local wasShown = parent:IsShown()
    parent:Show()
    h:Show()
    h:SetAttribute("startingIndex", 1 - h.count)
    h:SetAttribute("startingIndex", 1)
    if not wasShown then parent:Hide() end
end

-- a group's number beside it, shown while the group has players
local function AddGroupLabel(h, k)
    local label = h:CreateFontString(nil, "OVERLAY")
    local db = K.GetDb()
    K.ApplyFont(label, db and db.font)   -- a font before any text
    label:SetText(k)
    h.Label = label
    h:HookScript("OnSizeChanged", function(self, w, hh)
        local db = GetDb()
        local on = db and db.groupNumbers and Mode() == "group" and not IsEditing()
        self.Label:SetShown(on and (Rows() and w > 1 or not Rows() and hh > 1) or false)
    end)
end

local function EnsureHeaders()
    if Mode() == "group" then
        for k = 1, MAX_GROUPS do
            if not headers[k] then
                local h = NewHeader("FlareUI_RaidGroup" .. k, holder, raidCtx, GROUP_SIZE)
                h:SetAttribute("groupFilter", tostring(k))
                headers[k] = h
                AddGroupLabel(h, k)
                Precreate(h)
                -- the group's first tile tells the layout snippet whether the group is in use
                holder:SetFrameRef("g" .. k, h)
                holder:SetFrameRef("c" .. k, h[1])
                SecureHandlerWrapScript(h[1], "OnAttributeChanged", holder, WRAP_SNIPPET)
            end
        end
    elseif not headers.all then
        local h = NewHeader("FlareUI_RaidAll", holder, raidCtx, MAX_RAID)
        h:SetAttribute("groupFilter", "1,2,3,4,5,6,7,8")
        h:SetAttribute("maxColumns", MAX_GROUPS)
        h:SetAttribute("unitsPerColumn", GROUP_SIZE)
        -- the header lays out several columns as it makes them: it needs their direction first
        h:SetAttribute("point", Rows() and "LEFT" or "TOP")
        h:SetAttribute("columnAnchorPoint", Rows() and "TOP" or "LEFT")
        headers.all = h
        Precreate(h)
    end
end

--------------------------------------------------
-- 5. LAYOUT
--------------------------------------------------
-- the frame's own size: the largest raid, so its centre (where the raid grows from) stays put
local function HolderSize()
    local db = GetDb()
    local w, h = TileSize()
    local gap, ggap = db.spacing or 4, db.groupSpacing or 10
    if Rows() then
        return GROUP_SIZE * w + (GROUP_SIZE - 1) * gap, MAX_GROUPS * h + (MAX_GROUPS - 1) * ggap
    end
    return MAX_GROUPS * w + (MAX_GROUPS - 1) * ggap, GROUP_SIZE * h + (GROUP_SIZE - 1) * gap
end

-- a header's tiles: their size, and which way the members and columns go
local function ConfigureHeader(h, w, hh, gap, ggap)
    local rows = Rows()
    h:SetAttribute("_ignore", "batch")
    h:SetAttribute("tileWidth", w)
    h:SetAttribute("tileHeight", hh)
    h:SetAttribute("point", rows and "LEFT" or "TOP")
    h:SetAttribute("xOffset", rows and gap or 0)
    h:SetAttribute("yOffset", rows and 0 or -gap)
    h:SetAttribute("columnSpacing", ggap)
    h:SetAttribute("columnAnchorPoint", rows and "TOP" or "LEFT")
    h:SetAttribute("_ignore", nil)
    -- one change outside the batch: the header lays out again (when shown)
    h:SetAttribute("flareRefresh", (h:GetAttribute("flareRefresh") or 0) + 1)
    for i = 1, h.count or 0 do
        local f = h[i]
        if f then f:SetSize(w, hh) end
    end
end

local function LayoutGroups()
    local db = GetDb()
    local w, hh = TileSize()
    local gap, ggap = db.spacing or 4, db.groupSpacing or 10
    local mode = Mode()
    holder:SetAttribute("mode", mode)
    holder:SetAttribute("rows", Rows())
    holder:SetAttribute("tileW", w)
    holder:SetAttribute("tileH", hh)
    holder:SetAttribute("gap", gap)
    holder:SetAttribute("groupGap", ggap)
    for k = 1, MAX_GROUPS do
        local h = headers[k]
        if h then
            ConfigureHeader(h, w, hh, gap, ggap)
            h:SetShown(mode == "group" and not IsEditing())
            local font = K.GetDb() and K.GetDb().font
            K.ApplyFont(h.Label, font)
            h.Label:ClearAllPoints()
            if Rows() then h.Label:SetPoint("RIGHT", h, "LEFT", -4, 0) else h.Label:SetPoint("BOTTOM", h, "TOP", 0, 3) end
            local hw, hh2 = h:GetSize()
            h.Label:SetShown((db.groupNumbers and mode == "group" and (Rows() and hw > 1 or not Rows() and hh2 > 1)) and true or false)
        end
    end
    local all = headers.all
    if all then
        ConfigureHeader(all, w, hh, gap, ggap)
        local sort = db.sort or "GROUP"
        all:SetAttribute("groupBy", sort == "CLASS" and "CLASS" or "ASSIGNEDROLE")
        all:SetAttribute("groupingOrder", sort == "CLASS" and CLASS_ORDER or ROLE_ORDER)
        all:ClearAllPoints()
        all:SetPoint("CENTER", holder, "CENTER")
        all:SetShown(mode == "flat" and not IsEditing())
    end
    holder:SetSize(HolderSize())
    holder:Execute([[ self:RunAttribute("layout") ]])
end

local function LayoutTanks()
    if not tankHolder then return end
    local db = GetDb()
    local w, hh = TankSize()
    local gap = db.mainTanks and db.mainTanks.spacing or 2
    local h = headers.tanks
    h:SetAttribute("_ignore", "batch")
    h:SetAttribute("tileWidth", w)
    h:SetAttribute("tileHeight", hh)
    h:SetAttribute("point", "TOP")
    h:SetAttribute("yOffset", -gap)
    h:SetAttribute("_ignore", nil)
    h:SetAttribute("flareRefresh", (h:GetAttribute("flareRefresh") or 0) + 1)
    for i = 1, h.count do if h[i] then h[i]:SetSize(w, hh) end end
    h:ClearAllPoints()
    h:SetPoint("TOP", tankHolder, "TOP")
    h:SetShown(not IsEditing())
    tankHolder:SetSize(w, MAX_TANKS * hh + (MAX_TANKS - 1) * gap)
end

-- Edit Mode: the sample raid of the size being set, laid out as the live one would be
local function PlacePreview()
    local db = GetDb()
    local w, hh = TileSize()
    local gap, ggap = db.spacing or 4, db.groupSpacing or 10
    local groups = SAMPLE_RAIDS[sampleRaid] or 5
    local rows = Rows()
    local span = rows and hh or w
    local across = GROUP_SIZE * (rows and w or hh) + (GROUP_SIZE - 1) * gap
    local total = groups * span + (groups - 1) * ggap
    for i, f in ipairs(previewTiles) do
        if i <= groups * GROUP_SIZE then
            local g, slot = math_ceil(i / GROUP_SIZE), (i - 1) % GROUP_SIZE
            local offset = (g - 1) * (span + ggap) - total / 2
            local x, y
            if rows then
                x, y = -across / 2 + slot * (w + gap), -offset
            else
                x, y = offset, across / 2 - slot * (hh + gap)
            end
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", holder, "CENTER", x, y)
            f:Show()
        else
            f:Hide()
        end
    end
    -- the group numbers, beside each sample group
    holder.sampleLabels = holder.sampleLabels or {}
    local font = K.GetDb() and K.GetDb().font
    for g = 1, MAX_GROUPS do
        local label = holder.sampleLabels[g]
        if not label then
            label = holder:CreateFontString(nil, "OVERLAY")
            K.ApplyFont(label, font)
            label:SetText(g)
            holder.sampleLabels[g] = label
        end
        K.ApplyFont(label, font)
        local first = previewTiles[(g - 1) * GROUP_SIZE + 1]
        label:ClearAllPoints()
        if first and g <= groups and db.groupNumbers and Mode() == "group" then
            if rows then label:SetPoint("RIGHT", first, "LEFT", -4, 0) else label:SetPoint("BOTTOM", first, "TOP", 0, 3) end
            label:Show()
        else
            label:Hide()
        end
    end

    local tw, th = TankSize()
    local tgap = db.mainTanks and db.mainTanks.spacing or 2
    for i, f in ipairs(tankPreview) do
        f:ClearAllPoints()
        f:SetPoint("TOP", tankHolder, "TOP", 0, -(i - 1) * (th + tgap))
        f:SetShown(db.mainTanks and db.mainTanks.enabled ~= false)
    end
    if tankHolder then tankHolder:SetSize(tw, MAX_TANKS * th + (MAX_TANKS - 1) * tgap) end
end

local function SampleTile(parent, ctx, sample)
    local f = CreateFrame("Button", nil, parent, "BackdropTemplate")
    f.ctx = ctx
    f.noAuras = true
    f.sample = sample
    Tile.Build(f, nil)
    if ctx == raidCtx then MB.Attach(f) end
    f:Hide()
    pcall(Tile.Layout, f)   -- fonts and sizes before it is ever shown
    return f
end

local function EnsurePreview()
    if #previewTiles > 0 then return end
    for i = 1, MAX_RAID do previewTiles[i] = SampleTile(holder, raidCtx, SAMPLES[i]) end
    if tankHolder then
        tankPreview[1] = SampleTile(tankHolder, tankCtx, SAMPLES[1])
        tankPreview[2] = SampleTile(tankHolder, tankCtx, SAMPLES[6])
    end
end

--------------------------------------------------
-- 6. POSITION AND VISIBILITY
--------------------------------------------------
local function LayoutStore(key, layoutName)
    local db = GetDb()
    if not db then return nil end
    layoutName = layoutName or LEM:GetActiveLayoutName() or "Modern"
    db[key] = db[key] or {}
    db[key][layoutName] = db[key][layoutName] or {}
    return db[key][layoutName]
end

local function ApplyPosition(layoutName)
    if InCombatLockdown() then pendingLayout = true return end
    local store = LayoutStore("layouts", layoutName)
    local pos = (store and store.point) and store or DEFAULT_POSITION
    holder:ClearAllPoints()
    holder:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
    if tankHolder then
        local t = LayoutStore("tankLayouts", layoutName)
        local tpos = (t and t.point) and t or TANK_DEFAULT_POSITION
        tankHolder:ClearAllPoints()
        tankHolder:SetPoint(tpos.point, UIParent, tpos.point, tpos.x or 0, tpos.y or 0)
    end
end

local function Mover(key)
    return function(_, layoutName, point, x, y)
        local store = LayoutStore(key, layoutName)
        if store then store.point, store.x, store.y = point, math_floor(x + 0.5), math_floor(y + 0.5) end
    end
end

local function TanksOn()
    local db = GetDb()
    return db and db.mainTanks and db.mainTanks.enabled == true or false
end

-- in a raid only; in Edit Mode the samples show instead of the live tiles
local function ApplyVisibility()
    if InCombatLockdown() then pendingLayout = true return end
    local editing = IsEditing()
    for _, frame in ipairs({ holder, tankHolder }) do
        if editing then
            UnregisterStateDriver(frame, "visibility")
            frame:SetShown(frame == holder or TanksOn())
        elseif frame == holder or TanksOn() then
            RegisterStateDriver(frame, "visibility", "[group:raid] show; hide")
        else
            UnregisterStateDriver(frame, "visibility")
            frame:Hide()
        end
    end
    for _, f in ipairs(previewTiles) do if not editing then f:Hide() end end
    for _, label in ipairs(holder.sampleLabels or {}) do if not editing then label:Hide() end end
    for _, f in ipairs(tankPreview) do if not editing then f:Hide() end end
end

--------------------------------------------------
-- 7. REFRESH
--------------------------------------------------
local function Refresh()
    if not holder then return end
    if InCombatLockdown() then pendingLayout = true return end
    pendingLayout = false
    EnsureHeaders()
    LayoutGroups()
    LayoutTanks()
    local editing = IsEditing()
    -- the live tiles are hidden in Edit Mode: they are laid out when it closes (each change there
    -- would otherwise redo every one of them)
    if not editing then
        for _, f in ipairs(tiles) do
            local ok, err = pcall(Tile.Layout, f)
            if not ok then geterrorhandler()(err) end
        end
    end
    ApplyPosition()
    ApplyVisibility()
    if editing then
        -- only the samples of the raid size shown
        EnsurePreview()
        PlacePreview()
        for _, list in ipairs({ previewTiles, tankPreview }) do
            for _, f in ipairs(list) do
                if f:IsShown() then
                    pcall(Tile.Layout, f)
                    Tile.UpdateAll(f)
                    MB.Update(f)
                end
            end
        end
    else
        for _, f in ipairs(tiles) do
            if f:IsVisible() and f.unit then Tile.UpdateAll(f); UpdateRange(f); MB.Update(f) end
        end
    end
end

function RF:Refresh()
    Refresh()
end

--------------------------------------------------
-- 8. MISSING BUFFS
-- Each tile shows the icons of the group buffs its player lacks that you can cast: Fortitude,
-- Spirit and Arcane Intellect for mana users, Mark of the Wild, Thorns for tanks, and a paladin
-- blessing by role. Out of a fight only (buffing happens between pulls, and aura data can be
-- secret in one); a member whose buffs can't be read shows nothing.
--------------------------------------------------
local BUFFS = {
    { key = "fort",   class = "PRIEST",  who = "all",  ids = { 1243, 1244, 1245, 2791, 10937, 10938, 21562, 21564 } },
    { key = "spirit", class = "PRIEST",  who = "mana", ids = { 14752, 14818, 14819, 27841, 27681 } },
    { key = "int",    class = "MAGE",    who = "mana", ids = { 1459, 1460, 1461, 10156, 10157, 23028 } },
    { key = "mark",   class = "DRUID",   who = "all",  ids = { 1126, 5232, 6756, 5234, 8907, 9884, 9885, 21849, 21850 } },
    { key = "thorns", class = "DRUID",   who = "tank", ids = { 467, 782, 1075, 8914, 9756, 9910 } },
    { key = "blessing", class = "PALADIN", who = "all", ids = {} },   -- every blessing below
}
-- the blessings, and which one a role is reminded of first
local BLESSINGS = {
    might     = { 19740, 19834, 19835, 19836, 19837, 19838, 25291, 25782, 25916 },
    wisdom    = { 19742, 19850, 19852, 19853, 19854, 25290, 25894, 25918 },
    kings     = { 20217, 25898 },
    salvation = { 1038, 25895 },
    light     = { 19977, 19978, 19979, 25890 },
    sanctuary = { 20911, 20912, 20913, 20914, 25899 },
}
local BLESSING_PICK = {
    TANK = { "kings", "might", "sanctuary" }, HEALER = { "wisdom", "kings" },
    CASTER = { "wisdom", "kings" }, MELEE = { "might", "kings" },
}
local NO_MANA = { WARRIOR = true, ROGUE = true }
local MAX_ICONS = 3

local known          -- buff key -> { names = set, icon = texture } for the buffs you can cast
local blessingKnown  -- blessing name -> icon

local function SpellName(id)
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
    return name
end

local function Knows(id)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, yes = pcall(C_SpellBook.IsSpellKnown, id)
        if ok and yes then return true end
    end
    return IsPlayerSpell and IsPlayerSpell(id) or false
end

-- the buffs this character can give, looked up again when the spellbook changes
function MB.Learn()
    known, blessingKnown = {}, {}
    local _, class = UnitClass("player")
    for _, buff in ipairs(BUFFS) do
        if buff.class == class then
            if buff.key == "blessing" then
                local names = {}
                for kind, ids in pairs(BLESSINGS) do
                    for _, id in ipairs(ids) do
                        local name = SpellName(id)
                        if name then names[name] = true end
                        if Knows(id) then blessingKnown[kind] = C_Spell.GetSpellTexture(id) end
                    end
                end
                if next(blessingKnown) then known.blessing = { names = names } end
            else
                local names, icon = {}, nil
                for _, id in ipairs(buff.ids) do
                    local name = SpellName(id)
                    if name then names[name] = true end
                    if Knows(id) then icon = C_Spell.GetSpellTexture(id) end
                end
                if icon then known[buff.key] = { names = names, icon = icon, who = buff.who } end
            end
        end
    end
end

-- the icons a unit is missing (nil: can't tell)
local function MissingIcons(unit)
    if not known or not next(known) then return {} end
    if not readable(UnitIsConnected(unit)) or readable(UnitIsDeadOrGhost(unit)) ~= false then return nil end
    local have = {}
    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
        if not aura then break end
        local name = readable(aura.name)
        if name == nil then return nil end
        have[name] = true
    end
    local _, class = UnitClass(unit)
    class = readable(class)
    local role = readable(UnitGroupRolesAssigned(unit))
    local isTank = role == "TANK" or (GetPartyAssignment and readable(GetPartyAssignment("MAINTANK", unit)))
    local manaUser = class and not NO_MANA[class]
    local icons = {}
    local function Lacks(names) for name in pairs(names) do if have[name] then return false end end return true end
    for _, buff in ipairs(BUFFS) do
        local k = known[buff.key]
        if k and #icons < MAX_ICONS and Lacks(k.names) then
            if buff.key == "blessing" then
                local pick = isTank and BLESSING_PICK.TANK or role == "HEALER" and BLESSING_PICK.HEALER
                    or manaUser and BLESSING_PICK.CASTER or BLESSING_PICK.MELEE
                for _, kind in ipairs(pick) do
                    if blessingKnown[kind] then icons[#icons + 1] = blessingKnown[kind] break end
                end
            elseif k.who == "all" or (k.who == "mana" and manaUser) or (k.who == "tank" and isTank) then
                icons[#icons + 1] = k.icon
            end
        end
    end
    return icons
end

function MB.Attach(f)
    local frame = CreateFrame("Frame", nil, f)
    frame:SetFrameLevel(f:GetFrameLevel() + 7)
    frame:SetAllPoints(f.Health)
    frame.icons = {}
    for i = 1, MAX_ICONS do
        local t = frame:CreateTexture(nil, "OVERLAY")
        t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        t:Hide()
        frame.icons[i] = t
    end
    f.MissingBuffs = frame
end

local function ShowIcons(f, icons)
    local frame = f.MissingBuffs
    local size = math_max(10, math_min(16, math_floor((f:GetHeight() or 40) * 0.3)))
    -- a row in the middle of the health bar
    local count = icons and math_min(#icons, #frame.icons) or 0
    local start = -(count * size + (count - 1)) / 2
    for i, t in ipairs(frame.icons) do
        local icon = icons and icons[i]
        if icon then
            t:SetTexture(icon)
            t:SetSize(size, size)
            t:ClearAllPoints()
            t:SetPoint("LEFT", frame, "CENTER", start + (i - 1) * (size + 1), 0)
            t:Show()
        else
            t:Hide()
        end
    end
end

-- sample icons for Edit Mode
local SAMPLE_ICON_IDS = { fort = 1243, mark = 1126, int = 1459 }

function MB.Update(f)
    if not f.MissingBuffs then return end
    local db = GetDb()
    if not (db and db.missingBuffs ~= false) then ShowIcons(f) return end
    if IsEditing() then
        local icons = {}
        for _, key in ipairs(f.sample and f.sample.missing or {}) do
            icons[#icons + 1] = C_Spell.GetSpellTexture(SAMPLE_ICON_IDS[key])
        end
        ShowIcons(f, icons)
        return
    end
    if InCombatLockdown() or not f.unit or not f:IsVisible() then ShowIcons(f) return end
    ShowIcons(f, MissingIcons(f.unit))
end

function MB.UpdateAll()
    for _, f in ipairs(tiles) do MB.Update(f) end
end

-- aura changes come in bursts: the tiles touched are looked at once, a moment later
local dirty, scheduled = {}, false
function MB.OnAura(unit)
    if InCombatLockdown() then return end
    unit = readable(unit)
    if not (unit and unit:find("^raid")) then return end
    for _, f in ipairs(tiles) do if f.unit == unit then dirty[f] = true end end
    if scheduled then return end
    scheduled = true
    C_Timer.After(0.3, function()
        scheduled = false
        for f in pairs(dirty) do MB.Update(f) end
        wipe(dirty)
    end)
end

--------------------------------------------------
-- 9. EDIT MODE SETTINGS
--------------------------------------------------
local RebuildSettings

local function BuildSettings()
    local settings = {}
    local d = ns.defaults and ns.defaults.profile.unitframes.raid or {}
    local function get(key, default)
        return function()
            local db = GetDb()
            local v = db and db[key]
            if v == nil then return default end
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
    local function Section(key, title, items)
        settings[#settings + 1] = { name = "|cffffd100" .. title .. "|r", kind = LEM.SettingType.Expander, default = false,
            get = function() return SectionOpen(key) end,
            set = function(_, value)
                local db = K.GetDb()
                if not db then return end
                db.editSections = db.editSections or {}
                db.editSections[key] = value and true or nil
            end }
        for _, item in ipairs(items) do
            local own = item.hidden
            item.hidden = function(...)
                if not SectionOpen(key) then return true end
                if type(own) == "function" then return own(...) end
                return own
            end
            settings[#settings + 1] = item
        end
    end
    Section("Raid", L["Raid"], {
        { name = L["Sample Raid"], kind = LEM.SettingType.Dropdown, default = "medium",
          values = { { text = L["10 Players"], value = "small", isRadio = true }, { text = L["25 Players"], value = "medium", isRadio = true },
                     { text = L["40 Players"], value = "large", isRadio = true } },
          desc = L["Edit Mode only: how many sample players show, to see the raid grow from the middle."],
          get = function() return sampleRaid end,
          set = function(_, value)
              sampleRaid = value
              Refresh()
          end },
        { name = L["Sort By"], kind = LEM.SettingType.Dropdown, default = "GROUP",
          values = { { text = L["Group"], value = "GROUP", isRadio = true }, { text = L["Role"], value = "ROLE", isRadio = true },
                     { text = L["Class"], value = "CLASS", isRadio = true } },
          desc = L["Group keeps each raid group together. Role and Class fill rows of five, tanks or classes first."],
          get = get("sort", "GROUP"), set = set("sort") },
        { name = L["Groups"], kind = LEM.SettingType.Dropdown, default = "ROWS",
          values = { { text = L["Rows"], value = "ROWS", isRadio = true }, { text = L["Columns"], value = "COLUMNS", isRadio = true } },
          get = get("orientation", "ROWS"), set = set("orientation") },
        { name = L["Group Numbers"], kind = LEM.SettingType.Checkbox, default = false, get = get("groupNumbers", false), set = set("groupNumbers"),
          hidden = function() return Mode() ~= "group" end },
        { name = L["Main Tank Frames"], kind = LEM.SettingType.Checkbox, default = false,
          get = function() return TanksOn() end,
          set = function(_, value)
              local db = GetDb()
              if not db then return end
              db.mainTanks = db.mainTanks or {}
              db.mainTanks.enabled = value
              Refresh()
          end,
          desc = L["The raid's main tanks in a small frame of their own (set by the raid leader)."] },
    })

    Section("Frame", L["Frame"], {
        { name = L["Width"], kind = LEM.SettingType.Slider, default = DEFAULT_W, minValue = 40, maxValue = 200, valueStep = 1,
          get = get("width", DEFAULT_W), set = set("width") },
        { name = L["Height"], kind = LEM.SettingType.Slider, default = DEFAULT_H, minValue = 20, maxValue = 100, valueStep = 1,
          get = get("height", DEFAULT_H), set = set("height") },
        { name = L["Spacing"], kind = LEM.SettingType.Slider, default = d.spacing or 4, minValue = 0, maxValue = 20, valueStep = 1,
          get = get("spacing", 4), set = set("spacing") },
        { name = L["Group Spacing"], kind = LEM.SettingType.Slider, default = d.groupSpacing or 10, minValue = 0, maxValue = 40, valueStep = 1,
          get = get("groupSpacing", 10), set = set("groupSpacing") },
        { name = L["Power Bar Height"], kind = LEM.SettingType.Slider, default = d.powerHeight or 4, minValue = 0, maxValue = 15, valueStep = 1,
          get = get("powerHeight", 4), set = set("powerHeight"), formatter = function(value) return value == 0 and _G.OFF or value end },
        { name = L["Power Bar for Healers Only"], kind = LEM.SettingType.Checkbox, default = d.healersOnlyPower ~= false,
          get = get("healersOnlyPower", true), set = set("healersOnlyPower") },
        { name = L["Health Text"], kind = LEM.SettingType.Dropdown, default = d.healthText or "none", values = K.HEALTH_TEXT_MODES,
          get = get("healthText", "none"), set = set("healthText") },
    })

    -- inside the tile only; a place taken by one kind is greyed out on the others
    local places = {}
    for _, p in ipairs(Tile.AURA_POSITION_VALUES) do
        if p.value == "OFF" or p.value:find("^INSIDE") then places[#places + 1] = p end
    end
    local AURA_FIELDS = { "buffs", "debuffs", "dispels" }
    local function Place(field)
        return function(_, rootDescription, data)
            local db = GetDb()
            for _, p in ipairs(places) do
                local radio = rootDescription:CreateRadio(p.text,
                    function(value) local now = GetDb(); return now and now[field] == value end,
                    function(value) data.set(nil, value) end, p.value)
                if db and p.value ~= "OFF" and radio.SetEnabled then
                    for _, other in ipairs(AURA_FIELDS) do
                        if other ~= field and db[other] == p.value then radio:SetEnabled(false) end
                    end
                end
            end
        end
    end
    Section("Auras", L["Auras"], {
        { name = L["Buffs"], kind = LEM.SettingType.Dropdown, default = d.buffs, values = places, generator = Place("buffs"),
          get = get("buffs"), set = set("buffs") },
        { name = L["Debuffs"], kind = LEM.SettingType.Dropdown, default = d.debuffs, values = places, generator = Place("debuffs"),
          get = get("debuffs"), set = set("debuffs") },
        { name = L["Dispel Icons"], kind = LEM.SettingType.Dropdown, default = d.dispels, values = places, generator = Place("dispels"),
          get = get("dispels"), set = set("dispels") },
        { name = L["Bigger Boss Debuffs"], kind = LEM.SettingType.Checkbox, default = d.bigBossDebuffs ~= false,
          get = get("bigBossDebuffs", true), set = set("bigBossDebuffs") },
        { name = L["Missing Buffs"], kind = LEM.SettingType.Checkbox, default = true, get = get("missingBuffs", true), set = set("missingBuffs"),
          desc = L["Out of combat, the group buffs a player lacks that you can cast show on their frame."] },
        { name = L["Aura Size"], kind = LEM.SettingType.Slider, default = d.auraSize or 14, minValue = 8, maxValue = 30, valueStep = 1,
          get = get("auraSize", 14), set = set("auraSize") },
        { name = L["Dispel Highlight"], kind = LEM.SettingType.Dropdown, default = d.dispelHighlight or "mine",
          values = { { text = L["Off"], value = "off", isRadio = true }, { text = L["Dispellable by Me"], value = "mine", isRadio = true },
                     { text = L["Dispellable by the Group"], value = "all", isRadio = true } },
          get = get("dispelHighlight", "mine"), set = set("dispelHighlight") },
    })

    local iconItems = {}
    local sample = { ctx = raidCtx }   -- the icon switches read the raid settings through it
    for _, key in ipairs(Tile.ICON_ORDER) do
        iconItems[#iconItems + 1] = { name = Tile.ICON_LABELS[key], kind = LEM.SettingType.Checkbox, default = true,
            get = function() return Tile.IconShown(key, sample) end,
            set = function(_, value)
                local store = Tile.IconStore(key, true, sample)
                if not store then return end
                store.shown = value
                Refresh()
            end }
    end
    Section("Icons", L["Icons"], iconItems)
    return settings
end

local function BuildTankSettings()
    local function get(key, default)
        return function()
            local db = GetDb()
            local mt = db and db.mainTanks
            local v = mt and mt[key]
            if v == nil then return default end
            return v
        end
    end
    local function set(key)
        return function(_, value)
            local db = GetDb()
            if not db then return end
            db.mainTanks = db.mainTanks or {}
            db.mainTanks[key] = value
            Refresh()
        end
    end
    return {
        { name = L["Width"], kind = LEM.SettingType.Slider, default = 182, minValue = 40, maxValue = 240, valueStep = 1, get = get("w", 182), set = set("w") },
        { name = L["Height"], kind = LEM.SettingType.Slider, default = 55, minValue = 20, maxValue = 100, valueStep = 1, get = get("h", 55), set = set("h") },
        { name = L["Spacing"], kind = LEM.SettingType.Slider, default = 2, minValue = 0, maxValue = 20, valueStep = 1, get = get("spacing", 2), set = set("spacing") },
    }
end

RebuildSettings = function()
    if not holder then return end
    LEM:AddFrameSettings(holder, BuildSettings())
end

--------------------------------------------------
-- 10. EVENTS
--------------------------------------------------
local function ForTiles(fn)
    for _, f in ipairs(tiles) do
        if f.unit and f:IsVisible() then fn(f) end
    end
end

function RF:OnGlobalEvent(event, ...)
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingLayout then Refresh() end
        MB.UpdateAll()
        return
    elseif event == "PLAYER_REGEN_DISABLED" then
        for _, f in ipairs(tiles) do if f.MissingBuffs then ShowIcons(f) end end
        return
    elseif event == "UNIT_AURA" then
        MB.OnAura(...)
        return
    elseif event == "SPELLS_CHANGED" then
        MB.Learn()
        MB.UpdateAll()
        return
    end
    if IsEditing() then return end
    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        ForTiles(function(f) Tile.UpdateAll(f) end)
        MB.UpdateAll()
        return
    end
    if event == "READY_CHECK_FINISHED" then
        if readyHold then readyHold:Cancel() end
        readyHold = C_Timer.NewTimer(READY_CHECK_HOLD, function()
            readyHold = nil
            for _, f in ipairs(tiles) do f.lastReady = nil; if f.unit then Tile.UpdateReadyCheck(f) end end
        end)
    elseif event == "READY_CHECK" then
        if readyHold then readyHold:Cancel(); readyHold = nil end
    end
    ForTiles(function(f)
        if event == "PLAYER_TARGET_CHANGED" then
            Tile.UpdateTarget(f)
        elseif event == "RAID_TARGET_UPDATE" then
            Tile.UpdateRaidIcon(f)
        elseif event == "READY_CHECK" or event == "READY_CHECK_CONFIRM" or event == "READY_CHECK_FINISHED" then
            Tile.UpdateReadyCheck(f)
        elseif event == "INCOMING_SUMMON_CHANGED" or event == "INCOMING_RESURRECT_CHANGED" then
            Tile.UpdateStatus(f)
        elseif event == "PARTY_LEADER_CHANGED" then
            Tile.UpdateLeader(f)
        elseif event == "PLAYER_ROLES_ASSIGNED" then
            Tile.UpdateRole(f)
            Tile.UpdatePower(f)
        end
    end)
end

local GLOBAL_EVENTS = {
    "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "RAID_TARGET_UPDATE", "PLAYER_TARGET_CHANGED",
    "PLAYER_ROLES_ASSIGNED", "READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED",
    "INCOMING_SUMMON_CHANGED", "INCOMING_RESURRECT_CHANGED", "PLAYER_ENTERING_WORLD",
    "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "UNIT_AURA", "SPELLS_CHANGED",
}

-- Range has no event for every change; the tiles re-check twice a second
local function StartRangeTicker()
    C_Timer.NewTicker(RANGE_INTERVAL, function()
        if not holder:IsShown() or IsEditing() then return end
        ForTiles(UpdateRange)
    end)
end

-- Edit Mode: party frames and raid frames sit over one another. Each gets a layer of its own, the
-- party (the smaller) on top, so their tiles never interleave and the party's box can always be
-- picked. Edit Mode's Frames checkboxes hide either. Out of Edit Mode they never show together, and
-- all go back to the usual layer.
-- (each tile and its parts too: they keep the layer they were made on)
local GROUP_LAYERS = { FlareUI_Party = "MEDIUM", FlareUI_Raid = "LOW", FlareUI_RaidTanks = "LOW" }
local function SetLayer(frame, strata)
    frame:SetFrameStrata(strata)
    for _, child in ipairs({ frame:GetChildren() }) do SetLayer(child, strata) end
end
local function StackGroupFrames()
    if InCombatLockdown() then return end
    local editing = IsEditing()
    for name, strata in pairs(GROUP_LAYERS) do
        local frame = _G[name]
        if frame then SetLayer(frame, editing and strata or "LOW") end
    end
end

-- Blizzard's raid frames give way (the raid manager on the left stays)
local function HideBlizzardRaid()
    if _G.CompactRaidFrameContainer then K.HardHide("CompactRaidFrameContainer") end
end

--------------------------------------------------
-- 11. PUBLIC
--------------------------------------------------
function RF:ShouldLoad()
    local db = K and K.GetDb()
    return db and db.enabled and db.raid and db.raid.enabled and Tile and true or false
end

function RF:Init()
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

    holder = CreateFrame("Frame", "FlareUI_Raid", UIParent, "SecureHandlerStateTemplate")
    holder:SetFrameStrata("LOW")
    holder:SetClampedToScreen(true)
    holder:SetSize(400, 400)
    holder.editModeName = "FlareUI Raid Frames"
    holder:SetAttribute("layout", LAYOUT_SNIPPET)

    tankHolder = CreateFrame("Frame", "FlareUI_RaidTanks", UIParent, "SecureHandlerStateTemplate")
    tankHolder:SetFrameStrata("LOW")
    tankHolder:SetClampedToScreen(true)
    tankHolder:SetSize(110, 120)
    tankHolder.editModeName = "FlareUI Main Tanks"
    local tanks = NewHeader("FlareUI_RaidTanksHeader", tankHolder, tankCtx, MAX_TANKS)
    tanks:SetAttribute("groupFilter", "MAINTANK")
    headers.tanks = tanks
    Precreate(tanks)

    MB.Learn()
    Refresh()

    LEM:AddFrame(holder, Mover("layouts"), DEFAULT_POSITION, "FlareUI Raid Frames")
    LEM:AddFrameSettings(holder, BuildSettings())
    LEM:AddFrame(tankHolder, Mover("tankLayouts"), TANK_DEFAULT_POSITION, "FlareUI Main Tanks")
    LEM:AddFrameSettings(tankHolder, BuildTankSettings())
    HideBlizzardRaid()

    for _, event in ipairs(GLOBAL_EVENTS) do self:RegisterEvent(event, "OnGlobalEvent") end

    LEM:RegisterCallback("layout", function(layoutName) ApplyPosition(layoutName) end)
    LEM:RegisterCallback("enter", function()
        Refresh()
        RebuildSettings()
        StackGroupFrames()
    end)
    LEM:RegisterCallback("exit", function()
        StackGroupFrames()
        Refresh()
    end)

    StartRangeTicker()
    C_Timer.After(0, Refresh)
end
