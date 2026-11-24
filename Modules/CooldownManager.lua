local _, ns = ...
local L = ns.L

--------------------------------------------------
-- COOLDOWN MANAGER
-- Blizzard's Cooldown Manager in FlareUI's look, with an Icon Shape for its icon viewers. The
-- Tracked Bars as FlareUI's cast bars (the unit frames' bar texture, a thin bronze border), their icons
-- as FlareUI's buffs, the Essential / Utility / Tracked Buffs icons with the action buttons' FlareUI
-- Borders, all with the Fonts tab's fonts. Blizzard keeps driving its own pooled frames; it sets only
-- values, text and the spark after a frame is made, so each one is styled once as it is acquired. Its
-- aura data is kept from addons (CooldownViewerSecure.lua): nothing here reads it, re-parents its frames
-- or calls their layout. FlareUI's pieces live in a weak table. The viewers' fading is Visibility.lua's
-- (cdm_ keys).
--------------------------------------------------
ns.CooldownManager = ns.CooldownManager or {}
local CM = ns.CooldownManager
ns.modules["CooldownManager"] = CM

local _G = _G
local pairs, ipairs = pairs, ipairs
local math_min, math_max, math_floor, math_abs = math.min, math.max, math.floor, math.abs
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
    -- the first Bar Colour (a plain colour) becomes the colour window's Custom palette
    if db and db.barColor then
        db.customColors = db.customColors or {}
        db.customColors.bar = db.barColor
        db.palette, db.barColor = "custom", nil
    end
    return db
end

-- Bar Colour (Settings > Cooldown Manager > Pick Your Colours, the colour window's "cdm" kind):
-- FlareUI's colours, or the player's own (palette "custom")
CM.COLORS = { bar = { 1, 0.5, 0.25 } }
function CM.Palette()
    local db = GetDb()
    return db and db.palette == "custom" and "custom" or "flareui"
end
function CM.Color(key)
    local db = GetDb()
    local own = CM.Palette() == "custom" and db.customColors and db.customColors[key]
    return own or CM.COLORS[key]
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
    local color = CM.Color("bar")
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

-- The colour window's sample (Settings/ColorPicker.lua, kind "cdm"): a Tracked Bar built as Blizzard's
-- (an icon, a bar with its name and time) and skinned by StyleBar, so it shows the bar as it will look
function CM.CreateSample(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.fuiSample = true
    f:SetSize(240, 20)
    f.Icon = CreateFrame("Frame", nil, f)
    f.Icon:SetSize(20, 20)
    f.Icon:SetPoint("LEFT")
    f.Icon.Icon = f.Icon:CreateTexture(nil, "ARTWORK")
    f.Icon.Icon:SetAllPoints()
    f.Icon.Icon:SetTexture("Interface\\Icons\\Spell_Holy_WordFortitude")
    f.Icon.Applications = f.Icon:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    f.Icon.Applications:SetPoint("BOTTOMRIGHT")
    f.Bar = CreateFrame("StatusBar", nil, f)
    f.Bar:SetPoint("TOPLEFT", f.Icon, "TOPRIGHT", 6, 0)
    f.Bar:SetPoint("BOTTOMRIGHT")
    f.Bar:SetMinMaxValues(0, 1)
    f.Bar:SetValue(0.6)
    f.Bar.Name = f.Bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.Bar.Name:SetPoint("LEFT", 5, 0)
    f.Bar.Name:SetText(L["Spell"])
    f.Bar.Duration = f.Bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.Bar.Duration:SetPoint("RIGHT", -5, 0)
    f.Bar.Duration:SetText("8")
    return f
end
function CM.DrawSample(f)
    Pieces(f).styled = nil   -- (styled anew each time: the colour may have changed)
    StyleBar(f)
    return f:GetWidth(), f:GetHeight()
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
-- 2. ICON SHAPE
-- Icon Shape, for each icon viewer in its Edit Mode dialog (Visibility.lua adds the row). Default
-- leaves the icon as Blizzard made it. Rectangle keeps Blizzard's width and takes a quarter off the
-- height, so Blizzard's own Icon Size still scales it; the art is cut to the new shape, not squeezed.
-- An icon is touched only when its shape changes.
--------------------------------------------------
local SHAPE_KEYS = { EssentialCooldownViewer = "essential", UtilityCooldownViewer = "utility", BuffIconCooldownViewer = "buffs" }
local RECT_HEIGHT = 0.75

local function ApplyShape(item, shape)
    local p = Pieces(item)
    if (p.shape or "blizzard") == shape then return end
    local icon = item.Icon
    local width = item:GetWidth()
    -- (a width that cannot be read: tried again at the next pass)
    if not (icon and icon.SetTexCoord and Readable(width) and width > 0) then return end
    local rect = shape == "rect"
    p.shape = shape
    local was = item:GetHeight()
    -- Blizzard's icons are square: its width is the height to give back
    item:SetSize(width, width * (rect and RECT_HEIGHT or 1))
    local cut = rect and (1 - RECT_HEIGHT) / 2 or 0
    icon:SetTexCoord(0, 1, cut, 1 - cut)
    return Readable(was) and was or nil
end

-- The Icon Shape row of a viewer's Edit Mode dialog; key: essential / utility / buffs. Asking Blizzard
-- for a layout from addon code could taint the viewer: Reflow (7) gives the box its new height.
function CM.ShapeSetting(key)
    local LEM = LibStub("FlareEditMode")
    return {
        name = L["Icon Shape"], kind = LEM.SettingType.Dropdown, default = "blizzard",
        values = function()
            return { { text = L["Square"], value = "blizzard", isRadio = true },
                     { text = L["Rectangle"], value = "rect", isRadio = true } }
        end,
        desc = L["Square is Blizzard's. Rectangle is shorter, with the art cut to fit."],
        get = function()
            local db = GetDb()
            return db and db.shape and db.shape[key] or "blizzard"
        end,
        set = function(_, value)
            local db = GetDb()
            if not db then return end
            db.shape = db.shape or {}
            db.shape[key] = value
            CM:Refresh()
        end,
    }
end

--------------------------------------------------
-- 3. GROW FROM
-- Blizzard keeps a slot for every tracked buff, so the Tracked Buffs and Tracked Bars show gaps. With
-- Growth set, the frames showing now are packed from the chosen edge (or the middle) of the viewer,
-- in Blizzard's order, after each of Blizzard's layouts and whenever Blizzard shows or hides one. Only the
-- frames' points change: the viewer and its Edit Mode box stay Blizzard's. Default leaves all of it
-- alone; back on Default, each frame gets the point Blizzard gave it.
--------------------------------------------------
local GROW_KEYS = { BuffIconCooldownViewer = "buffs", BuffBarCooldownViewer = "bars" }
local showing, arranged = {}, {}

local function Number(v) return Readable(v) and type(v) == "number" and v or nil end
local function ByLayoutIndex(a, b) return a.layoutIndex < b.layoutIndex end

local function Grow(name)
    local key = GROW_KEYS[name]
    local db = GetDb()
    return key and db and db.grow and db.grow[key] or "blizzard"
end

-- Where the i-th of count shown frames goes. The edge is the player's choice, the order Blizzard's:
-- the first frame sits left (in a column: at the bottom), or at the other end when reversed.
function CM.GrowPoint(grow, i, count, step, horizontal, reversed)
    local slot = reversed and (count - i) or (i - 1)
    local point, offset
    if grow == "CENTER" then
        point, offset = horizontal and "TOP" or "LEFT", (slot - (count - 1) / 2) * step
    elseif horizontal then
        if grow == "END" then
            point, offset = "TOPRIGHT", -(count - 1 - slot) * step
        else
            point, offset = "TOPLEFT", slot * step
        end
    elseif grow == "END" then
        point, offset = "BOTTOMLEFT", slot * step
    else
        point, offset = "TOPLEFT", -(count - 1 - slot) * step
    end
    return point, horizontal and offset or 0, horizontal and 0 or offset
end

-- Is the frame still where FlareUI put it (Blizzard's layout has not placed it since)?
local function Own(p, viewer, point, relative, x, y)
    return p.moved and point == p.movedPoint and relative == viewer
        and math_abs(x - p.movedX) < 0.01 and math_abs(y - p.movedY) < 0.01
end

-- Blizzard's point is kept before FlareUI's first move after each of its layouts. A frame whose point
-- cannot be read stays where it is: it could not be given back.
local function Move(item, viewer, point, x, y)
    local p = Pieces(item)
    local was, relative, relativePoint, wasX, wasY = item:GetPoint(1)
    if not (Readable(was) and Number(wasX) and Number(wasY)) then return end
    if not Own(p, viewer, was, relative, wasX, wasY) then
        p.b1, p.b2, p.b3, p.b4, p.b5 = was, relative, relativePoint, wasX, wasY
    end
    item:ClearAllPoints()
    item:SetPoint(point, viewer, point, x, y)
    p.moved, p.movedPoint, p.movedX, p.movedY = true, point, x, y
end

-- (a frame Blizzard has placed again since is already back)
local function Restore(name)
    local viewer = _G[name]
    for item in ActiveItems(name) do
        local p = Pieces(item)
        if p.moved then
            local point, relative, _, x, y = item:GetPoint(1)
            if p.b1 and Readable(point) and Number(x) and Number(y) and Own(p, viewer, point, relative, x, y) then
                item:ClearAllPoints()
                item:SetPoint(p.b1, p.b2, p.b3, p.b4, p.b5)
            end
            p.moved = nil
        end
    end
    arranged[name] = nil
end

local function Arrange(name)
    local grow = Grow(name)
    if grow == "blizzard" then
        if arranged[name] then Restore(name) end
        return
    end
    if not On() then return end
    wipe(showing)
    for item in ActiveItems(name) do
        local shown = item:IsShown()
        if Readable(shown) and shown and Number(item.layoutIndex) then showing[#showing + 1] = item end
    end
    local count = #showing
    if count == 0 then return end
    local viewer = _G[name]
    table.sort(showing, ByLayoutIndex)
    local width, height = Number(showing[1]:GetWidth()), Number(showing[1]:GetHeight())
    if not (width and height and width > 0 and height > 0) then return end
    local bars = GROW_KEYS[name] == "bars"
    local horizontal = not bars and viewer.isHorizontal ~= false
    -- (Blizzard's padding is in the frames' own units, whatever its Icon Size: GridLayoutUtil)
    local step = (horizontal and width or height) + (Number(horizontal and viewer.childXPadding or viewer.childYPadding) or 0)
    -- the bars start at the chosen edge
    local reversed = viewer.iconDirection ~= nil and viewer.iconDirection ~= 1
    if bars then reversed = grow == "START" end
    arranged[name] = true
    for i, item in ipairs(showing) do
        Move(item, viewer, CM.GrowPoint(grow, i, count, step, horizontal, reversed))
    end
end

-- (one function for every frame; Blizzard shows and hides a frame only in UpdateShownState, mostly
-- with nothing changed)
local function ItemChanged(item)
    local p = Pieces(item)
    local shown = item:IsShown()
    shown = Readable(shown) and shown and true or false
    if shown == p.shown then return end
    p.shown = shown
    -- (released for a layout, no place yet: Blizzard's layout follows, and the packing with it)
    local points = item:GetNumPoints()
    if Readable(points) and points == 0 then return end
    Arrange(p.viewer)
end

local function HookArrange(name, item)
    local p = Pieces(item)
    if p.arrangeHooked then return end
    p.arrangeHooked, p.viewer = true, name
    if item.UpdateShownState then hooksecurefunc(item, "UpdateShownState", ItemChanged) end
end

-- The Growth row of a viewer's Edit Mode dialog (its Frame section); key: buffs / bars. Named as Buff
-- Reminders' Growth: the way the row grows (START packs at the left or top, so it grows right or down)
function CM.GrowSetting(key)
    local LEM = LibStub("FlareEditMode")
    local name = key == "buffs" and "BuffIconCooldownViewer" or "BuffBarCooldownViewer"
    return {
        name = L["Growth"], kind = LEM.SettingType.Dropdown, default = "blizzard",
        values = function()
            local viewer = _G[name]
            local horizontal = key == "buffs" and not (viewer and viewer.isHorizontal == false)
            local values = { { text = L["Blizzard"], value = "blizzard", isRadio = true } }
            values[#values + 1] = { text = horizontal and L["Right"] or L["Down"], value = "START", isRadio = true }
            values[#values + 1] = { text = horizontal and L["Left"] or L["Up"], value = "END", isRadio = true }
            if key == "buffs" then values[#values + 1] = { text = L["From the Middle"], value = "CENTER", isRadio = true } end
            return values
        end,
        desc = L["How the shown icons line up:\n* Blizzard: a fixed spot for each, with gaps\n* The others: packed together, growing that way"],
        get = function() return Grow(name) end,
        set = function(_, value)
            local db = GetDb()
            if not db then return end
            db.grow = db.grow or {}
            db.grow[key] = value
            CM:Refresh()
        end,
    }
end

--------------------------------------------------
-- 4. ACTIVE OVERLAY
-- Soften Active Overlay, for the Essential and Utility icons. While an ability's effect runs (Serpent
-- Sting on the target), Blizzard shows the effect's time on the icon under a strong yellow swipe
-- (CooldownViewerConstants.ITEM_AURA_COLOR). Only the swipe's strength changes: the time, the edge and
-- the colour stay Blizzard's, and a cooldown's own swipe is never touched.
--------------------------------------------------
-- (the viewers whose icons are abilities: Show Keybinds too)
local ABILITY_VIEWERS = { EssentialCooldownViewer = true, UtilityCooldownViewer = true }
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
-- 5. KEYBINDS
-- Show Keybinds: the key of the action button that holds an Essential or Utility icon's spell, in the
-- icon's corner as on the action buttons. One table of spell -> key, read from Blizzard's bars and
-- built again only after a bar or a binding changed. A spell on no bar, or bound without a bar, has
-- no key to show.
--------------------------------------------------
local KEY_BARS = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
                   "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button" }
local KEY_EVENTS = { "UPDATE_BINDINGS", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
                     "UPDATE_SHAPESHIFT_FORM", "SPELLS_CHANGED", "PLAYER_ENTERING_WORLD" }
local keys, keysStale, keyWatch, keysQueued = {}, true, nil, false

-- (kept: asked for every icon on each pass and each key press)
local spellNames = {}
local function SpellName(id)
    local name = spellNames[id]
    if not name then
        local ok, got = pcall(C_Spell.GetSpellName, id)
        name = ok and Readable(got) and got or nil
        spellNames[id] = name
    end
    return name
end

-- the spell in a button's slot (a spell, or a macro that casts one)
local function ButtonSpell(button)
    local slot = button.action
    if not (Readable(slot) and type(slot) == "number") then return nil end
    local ok, kind, id, subType = pcall(GetActionInfo, slot)
    if not (ok and Readable(kind) and Readable(id) and type(id) == "number") then return nil end
    if kind == "spell" or (kind == "macro" and Readable(subType) and subType == "spell") then return id end
end

-- A bar's spell under every name an icon may know it by: the bar may hold another form or rank of
-- the icon's spell. An entry already there stays.
local function NoteOne(t, spell, value)
    if Readable(spell) and t[spell] == nil then t[spell] = value end
end
local function NoteSpell(t, id, value)
    NoteOne(t, id, value)
    if C_SpellBook and C_SpellBook.FindBaseSpellByID then NoteOne(t, C_SpellBook.FindBaseSpellByID(id), value) end
    if C_Spell.GetOverrideSpell then NoteOne(t, C_Spell.GetOverrideSpell(id), value) end
    NoteOne(t, SpellName(id), value)
end

local function ItemValue(item, t)
    local info = item.cooldownInfo
    if type(info) ~= "table" then return nil end
    local id, override = info.spellID, info.overrideSpellID
    local value = (Readable(id) and t[id]) or (Readable(override) and t[override])
    if not value and Readable(id) then
        local name = SpellName(id)
        value = name and t[name]
    end
    return value or nil
end

-- FlareUI's pieces on an icon sit over the cooldown swipe and the skin's border
local function Holder(item)
    local p = Pieces(item)
    if not p.holder then
        p.holder = CreateFrame("Frame", nil, item)
        p.holder:SetAllPoints(item)
        p.holder:SetFrameLevel(item:GetFrameLevel() + 3)
    end
    return p.holder
end

local function BuildKeys()
    wipe(keys)
    keysStale = false
    local AB = ns.ActionBars
    if not (AB and AB.BindingKey and AB.ShortenKey) then return end
    -- the first bar with the spell wins
    for _, prefix in ipairs(KEY_BARS) do
        for i = 1, 12 do
            local button = _G[prefix .. i]
            local key = button and AB.BindingKey(button)
            local id = key and key ~= "" and ButtonSpell(button)
            if id then NoteSpell(keys, id, AB.ShortenKey(key)) end
        end
    end
end

local function ItemKey(item)
    if keysStale then BuildKeys() end
    return ItemValue(item, keys)
end

local function UpdateKey(item)
    local p = Pieces(item)
    local db = GetDb()
    local text = db.keybinds and ItemKey(item)
    if not text then
        if p.key then p.key:Hide() end
        return
    end
    if not p.key then
        p.key = Holder(item):CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
        p.key:SetPoint("TOPRIGHT", item, "TOPRIGHT", -2, -2)
    end
    if p.keyRun ~= styleRun then
        p.keyRun = styleRun
        SetFont(p.key, db.keybindFont)
    end
    p.key:SetText(text)
    p.key:Show()
end

local function UpdateKeys(name)
    for item in ActiveItems(name) do UpdateKey(item) end
end

local function WatchKeys()
    local want = GetDb().keybinds
    keysStale = true
    if not want then
        if keyWatch then keyWatch:UnregisterAllEvents() end
        return
    end
    if not keyWatch then
        keyWatch = CreateFrame("Frame")
        -- (the bar events come in bursts: one pass on the next frame)
        local function Flush()
            keysQueued = false
            if On() and GetDb().keybinds then
                for name in pairs(ABILITY_VIEWERS) do UpdateKeys(name) end
            end
        end
        keyWatch:SetScript("OnEvent", function()
            keysStale = true
            if keysQueued then return end
            keysQueued = true
            C_Timer.After(0, Flush)
        end)
    end
    for _, event in ipairs(KEY_EVENTS) do keyWatch:RegisterEvent(event) end
end

--------------------------------------------------
-- 6. BUTTON PRESSES
-- Show Button Presses: an Essential or Utility icon lights up while the key of its spell is held, as
-- the action button does. Blizzard's bindings call the four functions hooked here, on press and on
-- release; a mouse click on a bar does not pass through them.
--------------------------------------------------
-- (the action buttons' own pushed frame)
local PUSH_ATLAS = "UI-HUD-ActionBar-IconFrame-Down"
local lit, pressed, pressHooked = {}, {}, false

local function Press(button, down)
    if not button then return end
    local items = lit[button]
    if items then
        lit[button] = nil
        for _, item in ipairs(items) do
            local push = Pieces(item).push
            if push then push:Hide() end
        end
    end
    if not (down and On() and GetDb().press) then return end
    local id = ButtonSpell(button)
    if not id then return end
    wipe(pressed)
    NoteSpell(pressed, id, true)
    items = nil
    for name in pairs(ABILITY_VIEWERS) do
        for item in ActiveItems(name) do
            if item:IsShown() and ItemValue(item, pressed) then
                local p = Pieces(item)
                if not p.push then
                    p.push = Holder(item):CreateTexture(nil, "ARTWORK")
                    p.push:SetAllPoints(item)
                    p.push:SetAtlas(PUSH_ATLAS)
                end
                p.push:Show()
                items = items or {}
                items[#items + 1] = item
            end
        end
    end
    lit[button] = items
end

local function HookPress()
    if pressHooked or not GetDb().press then return end
    if not (ActionButtonDown and ActionButtonUp and MultiActionButtonDown and MultiActionButtonUp and GetActionButtonForID) then return end
    pressHooked = true
    local function Main(down)
        return function(id) Press(GetActionButtonForID(id), down) end
    end
    local function Multi(down)
        return function(barName, id)
            local bar = _G[barName]
            local buttons = bar and bar.actionButtons
            Press(buttons and buttons[id], down)
        end
    end
    hooksecurefunc("ActionButtonDown", Main(true))
    hooksecurefunc("ActionButtonUp", Main(false))
    hooksecurefunc("MultiActionButtonDown", Multi(true))
    hooksecurefunc("MultiActionButtonUp", Multi(false))
end

--------------------------------------------------
-- 7. APPLYING
--------------------------------------------------
-- A new Icon Shape reaches the viewer only at Blizzard's next layout: until then its box kept the old
-- height, and the icons jumped when the layout came (leaving Edit Mode). So the rows and the box get
-- here what that layout will give them; was: the icons' height before. Anything unreadable, or a box
-- that is not whole rows of icons: left to Blizzard, as before.
local function Reflow(name, was)
    local viewer = _G[name]
    if not viewer or InCombatLockdown() then return end
    local pad, box = Number(viewer.childYPadding), Number(viewer:GetHeight())
    local now, scale
    for item in ActiveItems(name) do
        local height, itemScale = Number(item:GetHeight()), Number(item:GetScale())
        if not (height and itemScale and itemScale > 0) or (now and math_abs(height - now) > 0.01) then return end
        now, scale = height, itemScale
    end
    if not (now and pad and box) or was + pad <= 0 or math_abs(now - was) < 0.01 then return end
    local rows = (box / scale + pad) / (was + pad)
    local whole = math_floor(rows + 0.5)
    if whole < 1 or math_abs(rows - whole) > 0.05 then return end
    for item in ActiveItems(name) do
        -- (a frame Growth has packed: Arrange places it again)
        if not Pieces(item).moved then
            local point, relative, relativePoint, x, y = item:GetPoint(1)
            if Readable(point) and Number(x) and Number(y) then
                item:ClearAllPoints()
                item:SetPoint(point, relative, relativePoint, x, math_floor(y / (was + pad) + 0.5) * (now + pad))
            end
        end
    end
    viewer:SetHeight(box + whole * (now - was) * scale)
end

local function ApplyItem(name, item)
    local db = GetDb()
    local shapeKey = SHAPE_KEYS[name]
    local was = shapeKey and ApplyShape(item, db.shape and db.shape[shapeKey] or "blizzard")
    if db.skin then VIEWERS[name](item) end
    if Grow(name) ~= "blizzard" then HookArrange(name, item) end
    if ABILITY_VIEWERS[name] then
        if db.softOverlay or db.effectCooldown then HookSwipe(item) end
        Soften(item)
        EffectCooldown(item)
        UpdateKey(item)
        -- (a frame Blizzard hands to another spell while its key is held)
        local push = Pieces(item).push
        if push then push:Hide() end
    end
    return was
end

local function ApplyViewer(name)
    local was
    for item in ActiveItems(name) do was = ApplyItem(name, item) or was end
    if was then Reflow(name, was) end
end

-- every frame showing now (a settings change, or the viewer was already up)
function CM:Refresh()
    styleRun = styleRun + 1
    -- (switched on but not started yet: the frames would be styled without the hooks that keep them so)
    if not (self.initialized and On()) then return end
    WatchKeys()
    HookPress()
    for name in pairs(VIEWERS) do ApplyViewer(name) end
    for name in pairs(GROW_KEYS) do Arrange(name) end
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
                -- (Blizzard cleared the frame's points on release: no place of FlareUI's is left on it)
                Pieces(item).moved = nil
                if On() then ApplyItem(name, item) end
            end)
            -- Blizzard gives a frame its spell after acquiring it, and swaps spells in place
            if ABILITY_VIEWERS[name] and viewer.RefreshData then
                hooksecurefunc(viewer, "RefreshData", function()
                    if On() and GetDb().keybinds then UpdateKeys(name) end
                end)
            end
            -- Blizzard's layout gives every frame its slot again (RefreshLayout ends in one)
            if GROW_KEYS[name] and viewer.Layout then
                hooksecurefunc(viewer, "Layout", function() Arrange(name) end)
            end
        end
    end
    CM:Refresh()
    -- the viewers exist now: their fading (Visibility.lua)
    C_Timer.After(0, function()
        if ns.Visibility and ns.Visibility.Refresh then ns.Visibility:Refresh() end
    end)
end

--------------------------------------------------
-- 8. EDIT MODE
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
