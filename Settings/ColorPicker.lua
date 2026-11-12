local _, ns = ...
local L = ns.L

--------------------------------------------------
-- PICK YOUR COLOURS (11-11)
-- The Custom Colour Palette's own window: every colour the unit frames (or the resource bars) draw,
-- each a row with its swatch, and the frames themselves beside them (the modules' settings-preview
-- samples), repainted on every change. A click opens Blizzard's colour picker; a right-click gives
-- the row back to the palette Custom started from. The settings' Colour Palette row is only the button
-- that opens it (11-11): the palettes themselves are picked here, in the foot; Apply keeps the changes. The colours: unitframes.customColors and
-- unitframes.resource.customColors (UnitFrames.lua UF.ApplyPalette, ResourceBars.lua RB.ApplyPalette).
--------------------------------------------------
local CP = {}
ns.ColorPicker = CP

local WIDTH, HEIGHT = 980, 640
local LIST_W, ROW_H, PAD = 330, 26, 16

local function CLASS_NAME(class)
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class
end

-- the rows, in groups: { title, { key, label } ... }
local function UnitRows()
    local classes = {}
    for _, class in ipairs(ns.UnitFrames.CLASSES) do classes[#classes + 1] = { "class:" .. class, CLASS_NAME(class) } end
    return {
        { L["Health"], { { "health", L["Default Health"] }, { "grey", L["Tapped / Offline"] } } },
        { L["Class Colours"], classes },
        { L["Reaction"], { { "hostile", L["Hostile"] }, { "neutral", L["Neutral"] }, { "friendly", L["Friendly"] } } },
        { L["Power"], { { "mana", _G.MANA or L["Mana"] }, { "rage", _G.RAGE or "Rage" }, { "energy", _G.ENERGY or "Energy" },
            { "focus", (_G.FOCUS or "Focus") .. " (" .. L["Pets"] .. ")" } } },
        { L["Cast Bars"], { { "cast", L["Cast"] }, { "castChannel", L["Channel"] }, { "castNoInterrupt", L["Uninterruptible"] },
            { "interrupted", L["Interrupted"] } } },
        { L["Your Cast Bar"], { { "playerCast", L["Your Cast"] }, { "playerChannel", L["Your Channel"] }, { "latency", L["Latency Zone"] } } },
        { L["Heals and Shields"], { { "heal", L["Incoming Heals"] }, { "absorb", L["Shields"] } } },
    }
end

local function ResourceRows()
    return {
        { L["Health"], { { "health", L["Default Health"] }, { "classHealth", L["Your Class"] }, { "low", L["Low Health Colour"] } } },
        { L["Power"], { { "mana", _G.MANA or L["Mana"] }, { "rage", _G.RAGE or "Rage" }, { "energy", _G.ENERGY or "Energy" },
            { "druidMana", L["Druid Mana"] } } },
        { L["Combo Points"], { { "combo", L["Combo Points"] } } },
        { L["Swing Timers"], { { "swingMain", L["Main-Hand Swing"] }, { "swingOff", L["Off-Hand Swing"] }, { "swingRanged", L["Ranged Swing"] },
            { "outOfRange", L["Out of Range"] }, { "queued", L["Queued Attack Colour"] }, { "waiting", L["Waiting State"] },
            { "zone", L["Stand-Still Zone"] } } },
        { L["Heals and Shields"], { { "heal", L["Incoming Heals"] }, { "absorb", L["Shields"] } } },
        { L["Paladin Seals"], (function()
            -- each seal by its own name (a seal this client lacks is left out)
            local list = {}
            for _, s in ipairs({ { "sealRighteousness", 20293 }, { "sealCrusader", 20308 }, { "sealCommand", 20920 },
                                 { "sealJustice", 20164 }, { "sealLight", 20349 }, { "sealWisdom", 20357 },
                                 { "sealFury", 20423 }, { "sealMartyrdom", 407798 } }) do
                local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(s[2])
                if name then list[#list + 1] = { s[1], name } end
            end
            return list
        end)() },
        { L["Flight Timer"], { { "flight", L["Flight Timer"] } } },
    }
end

-- where a module's custom colours live, and how they are put to use
local KINDS = {
    uf = {
        title = function() return L["Unit Frames"] end,
        store = function()
            local db = ns.db.profile.unitframes
            db.customColors = db.customColors or {}
            return db.customColors
        end,
        color = function(key) return ns.UnitFrames.Color(key) end,
        palette = function()
            local p = ns.db.profile.unitframes.palette
            return (p == "blizzard" or p == "custom") and p or "flareui"
        end,
        base = function() return ns.db.profile.unitframes.customBase end,
        setPalette = function(p, base)
            local db = ns.db.profile.unitframes
            db.palette = p
            if base then db.customBase = base end
        end,
        apply = function()
            ns.UnitFrames.ApplyPalette()
            if ns.UnitFrames.Refresh then ns.UnitFrames:Refresh() end
            if ns.PartyFrames and ns.PartyFrames.Refresh then ns.PartyFrames:Refresh() end
            if ns.RaidFrames and ns.RaidFrames.Refresh then ns.RaidFrames:Refresh() end
            if ns.BossFrames and ns.BossFrames.Refresh then ns.BossFrames:Refresh() end
            -- Resource Bars that follow the unit frames' palette follow its base too
            if ns.ResourceBars and ns.ResourceBars.Refresh then ns.ResourceBars:Refresh() end
        end,
        rows = UnitRows,
    },
    rb = {
        title = function() return L["Resource Bars"] end,
        store = function()
            local db = ns.db.profile.unitframes.resource
            db.customColors = db.customColors or {}
            return db.customColors
        end,
        color = function(key)
            local RB = ns.ResourceBars
            RB.ApplyPalette()
            return RB.colors[key] or { 1, 1, 1 }
        end,
        -- until set, the unit frames' palette (RB.PaletteName)
        palette = function() return ns.ResourceBars.PaletteName() end,
        base = function() return ns.db.profile.unitframes.resource.customBase end,
        setPalette = function(p, base)
            local db = ns.db.profile.unitframes.resource
            db.palette = p
            if base then db.customBase = base end
        end,
        apply = function()
            local RB = ns.ResourceBars
            RB.ApplyPalette()
            if RB.Refresh then RB:Refresh() end
        end,
        rows = ResourceRows,
    },
}

local window, kindNow

-- The colour last picked shows on the samples (11-11): a health colour on the player's and target's
-- health bars, a power colour on their power bars, a cast colour on the cast bar, whatever the
-- class you play (shown: part -> key, per window kind)
local shown = { uf = {}, rb = {} }
local PARTS = {
    health = "health", grey = "health", hostile = "health", neutral = "health", friendly = "health",
    mana = "power", rage = "power", energy = "power", focus = "power",
    cast = "cast", castChannel = "cast", castNoInterrupt = "cast", interrupted = "cast",
    playerCast = "playerCast", playerChannel = "playerCast",
}
local function PartOf(key)
    if key:match("^class:") then return "health" end
    return PARTS[key]
end
local function Show(key)
    local part = kindNow == "uf" and PartOf(key)
    if part then shown.uf[part] = key end
end

--------------------------------------------------
-- 1. PREVIEWS (the modules' own samples, as the settings pages' pictures)
--------------------------------------------------
local samples = {}


-- The box is filled row by row (11-11): each row's frames sized up to fill its width (no more than
-- maxK), side by side in equal columns, then the whole stack shrunk if it is too tall and centred.
-- An item: { frame, ex = { left, top, width, height } } (ex: the drawn extents, the frame's TOPLEFT
-- inset by left / top inside them)
local ROW_GAP, COL_GAP = 18, 24

local function Item(frame, ex)
    if not frame then return nil end
    if not ex then
        local w, h = frame:GetSize()
        if not (w and w > 0 and h and h > 0) then return nil end
        ex = { left = 0, top = 0, width = w, height = h }
    end
    return { frame = frame, ex = ex }
end

-- a row: its items, how much of the width they may take, and their largest scale
local function Row(items, share, maxK)
    local list = {}
    for _, it in ipairs(items) do if it then list[#list + 1] = it end end
    if #list == 0 then return nil end
    return { items = list, share = share or 1, maxK = maxK or 1.5 }
end

local function LayRows(rows)
    local preview = window.preview
    local W, H = preview:GetWidth(), preview:GetHeight()
    local innerW, innerH = W - 2 * PAD, H - 2 * PAD
    local laid, total = {}, 0
    for _, row in ipairs(rows) do
        if row then
            local n = #row.items
            local colW = (innerW * row.share - COL_GAP * (n - 1)) / n
            local k, h = row.maxK, 0
            for _, it in ipairs(row.items) do k = math.min(k, colW / it.ex.width) end
            for _, it in ipairs(row.items) do h = math.max(h, it.ex.height * k) end
            laid[#laid + 1] = { row = row, k = k, h = h, colW = colW }
            total = total + h
        end
    end
    if #laid == 0 then return end
    local gaps = ROW_GAP * (#laid - 1)
    local s = math.min(1, (innerH - gaps) / total)
    local y = PAD + (innerH - total * s - gaps) / 2
    for _, r in ipairs(laid) do
        local k, n = r.k * s, #r.row.items
        local colW = r.colW
        -- the columns as one block, centred
        local blockW = colW * n + COL_GAP * (n - 1)
        if n == 1 then colW = r.row.items[1].ex.width * k; blockW = colW end
        local x0 = PAD + (innerW - blockW) / 2
        for i, it in ipairs(r.row.items) do
            local ex, f = it.ex, it.frame
            local x = x0 + (i - 1) * (colW + COL_GAP) + (colW - ex.width * k) / 2
            local top = y + (r.h * s - ex.height * k) / 2
            f:SetScale(k)
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", preview, "TOPLEFT", (x + ex.left * k) / k, -(top + ex.top * k) / k)
            f:Show()
        end
        y = y + r.h * s + ROW_GAP
    end
end

-- Incoming heals and a shield after the sample's health (the samples have no unit to predict from):
-- two strips past the fill, in the colours in use
local function HealOverlay(f)
    local UF, health = ns.UnitFrames, f.Health
    if not health then return end
    local o = f.fuiPickHeals
    if not o then
        o = CreateFrame("Frame", nil, health)
        o.heal = o:CreateTexture(nil, "ARTWORK", nil, 1)
        o.absorb = o:CreateTexture(nil, "ARTWORK", nil, 2)
        f.fuiPickHeals = o
    end
    o:SetFrameLevel(health:GetFrameLevel() + 1)
    o:SetAllPoints(health)
    local fill = health:GetStatusBarTexture()
    local inset = health.FlareUI_PlateInset
    local length = inset and inset.length or health:GetWidth()
    local reverse = health.GetReverseFill and health:GetReverseFill()
    local near, far = reverse and "RIGHT" or "LEFT", reverse and "LEFT" or "RIGHT"
    local file = fill and fill:GetTexture()
    for i, part in ipairs({ { o.heal, UF.HEAL_COLOR, 0.12 }, { o.absorb, UF.ABSORB_COLOR, 0.10 } }) do
        local tex, c, share = part[1], part[2], part[3]
        tex:ClearAllPoints()
        local after = i == 1 and fill or o.heal
        tex:SetPoint("TOP" .. near, after, "TOP" .. far, 0, 0)
        tex:SetPoint("BOTTOM" .. near, after, "BOTTOM" .. far, 0, 0)
        tex:SetWidth(math.max(1, length * share))
        if file then tex:SetTexture(file) else tex:SetColorTexture(1, 1, 1) end
        tex:SetVertexColor(c[1], c[2], c[3], 1)
    end
    o:Show()
end

local function UnitSample(id, unit, style)
    local UF = ns.UnitFrames
    local f = samples[id]
    if not f then
        f = UF.CreateSample(window.preview, unit)
        samples[id] = f
    end
    if not f then return nil end
    f:SetScale(1)
    local e = UF.DrawSample(f, style)
    if not e then f:Hide() return nil end
    return f, e
end

local function DrawUnitPreviews()
    local UF = ns.UnitFrames
    local style = ns.UFRing and ns.UFRing.Style() or "addon"
    local units = {}
    local own = shown.uf
    for _, unit in ipairs({ "player", "target" }) do
        local f, e = UnitSample("unit:" .. unit, unit, style)
        if f and e then
            for part, bar in pairs({ health = f.Health, power = f.Power }) do
                local key = own[part]
                if key and bar then
                    local c = UF.Color(key)
                    bar:SetStatusBarColor(c[1], c[2], c[3])
                end
            end
            HealOverlay(f)
            units[#units + 1] = Item(f, e)
        end
    end
    -- the cast bars: yours under the player, the target's under the target
    local casts = {}
    if UF.CreateCastSample then
        for _, info in ipairs({ { "player", "playerCast" }, { "target", "cast" } }) do
            local unit, part = info[1], info[2]
            local cast = samples["cast:" .. unit]
            if not cast then
                cast = UF.CreateCastSample(window.preview, unit)
                samples["cast:" .. unit] = cast
                -- the sample recolours itself on each loop: the shown colour over it
                if cast and cast.Cast then
                    local busy
                    hooksecurefunc(cast.Cast, "SetStatusBarColor", function(bar)
                        local key = shown.uf[part]
                        if busy or not key then return end
                        busy = true
                        local c = UF.Color(key)
                        bar:SetStatusBarColor(c[1], c[2], c[3])
                        busy = false
                    end)
                end
            end
            if cast then
                cast:SetScale(1)
                UF.DrawCastSample(cast)
                local key = shown.uf[part]
                if key and cast.Cast then local c = UF.Color(key); cast.Cast:SetStatusBarColor(c[1], c[2], c[3]) end
                casts[#casts + 1] = Item(cast)
            end
        end
    end
    LayRows({
        Row(units, 1, 1.6),
        Row(casts, 1, 1.6),
    })
end

local function DrawResourcePreviews()
    local RB = ns.ResourceBars
    if not (RB and RB.CreateSample) then return end
    RB.ApplyPalette()
    local rows = {}
    for _, key in ipairs({ "health", "power", "mana", "combo", "swingMain", "swingOff", "swingRanged" }) do
        local holder = samples["rb:" .. key]
        if not holder then holder = RB.CreateSample(window.preview, key); samples["rb:" .. key] = holder end
        if holder then
            holder:SetScale(1)
            RB.DrawSample(holder)
            rows[#rows + 1] = Row({ Item(holder) }, 0.8, 2)
        end
    end
    LayRows(rows)
end

local function DrawPreviews()
    for _, s in pairs(samples) do s:Hide() end
    local ok, err = pcall(kindNow == "rb" and DrawResourcePreviews or DrawUnitPreviews)
    if not ok and geterrorhandler then geterrorhandler()(err) end
end

--------------------------------------------------
-- 2. THE LIST
--------------------------------------------------
local function Hex(c) return ("%02X%02X%02X"):format(c[1] * 255 + 0.5, c[2] * 255 + 0.5, c[3] * 255 + 0.5) end

local function Repaint()
    local kind = KINDS[kindNow]
    for _, row in ipairs(window.rows) do
        if row.key then
            local c = kind.color(row.key)
            row.swatch:SetColorTexture(c[1], c[2], c[3])
            row.hex:SetText(Hex(c))
            row.own:SetShown(kind.palette() == "custom" and kind.store()[row.key] ~= nil)
        end
    end
    DrawPreviews()
end

-- PALETTES (11-11, Marcus): the foot's dropdown picks FlareUI (the default), Blizzard or Custom, shown
-- at once. FlareUI and Blizzard drop your own colours; Custom with nothing changed draws FlareUI's.
-- Changing any colour makes it Custom (from the palette shown). Reset (only on Custom with changes)
-- gives every colour back. Apply keeps it all and closes; closing any other way puts back what the
-- window opened with.
local PALETTES = { "flareui", "blizzard", "custom" }
local function PaletteText(p)
    return p == "blizzard" and L["Blizzard"] or p == "custom" and L["Custom"] or L["FlareUI"]
end
-- the palette in use for the open window (none yet while it is being built: the dropdown builds its
-- menu as it is set up)
local function CurrentPalette() return kindNow and KINDS[kindNow].palette() or "flareui" end

local function UpdatePaletteControls()
    if not window then return end
    local kind = kindNow and KINDS[kindNow]
    window.reset:SetShown(kind and kind.palette() == "custom" and next(kind.store()) ~= nil or false)
    window.palette:GenerateMenu()
end

local function Changed()
    KINDS[kindNow].apply()
    Repaint()
    UpdatePaletteControls()
end

local function SetColor(key, c)
    local kind = KINDS[kindNow]
    Show(key)
    kind.store()[key] = c and { c[1], c[2], c[3] } or nil
    if c and kind.palette() ~= "custom" then kind.setPalette("custom", kind.palette()) end
    Changed()
end

local function PickPalette(p)
    local kind = KINDS[kindNow]
    if p == kind.palette() then return end
    if p == "custom" then
        kind.setPalette("custom", "flareui")
    else
        wipe(kind.store())
        kind.setPalette(p, p)
    end
    Changed()
end

-- what the window opened with, put back unless Apply closed it
local function Snapshot()
    local kind = KINDS[kindNow]
    local copy = {}
    for key, c in pairs(kind.store()) do copy[key] = { c[1], c[2], c[3] } end
    window.saved = { kind = kindNow, palette = kind.palette(), base = kind.base(), store = copy }
end
local function Restore()
    local s = window.saved
    window.saved = nil
    if not s then return end
    local kind = KINDS[s.kind]
    local store = kind.store()
    wipe(store)
    for key, c in pairs(s.store) do store[key] = c end
    kind.setPalette(s.palette, s.base)
    kind.apply()
end

-- anything changed since the window opened (the palette or a colour)
local function Dirty()
    local s = window and window.saved
    if not s then return false end
    local kind = KINDS[s.kind]
    if kind.palette() ~= s.palette then return true end
    local store = kind.store()
    for key, c in pairs(store) do
        local o = s.store[key]
        if not o or o[1] ~= c[1] or o[2] ~= c[2] or o[3] ~= c[3] then return true end
    end
    for key in pairs(s.store) do if not store[key] then return true end end
    return false
end

-- Escape or the close button with changes not applied: Apply keeps them, Discard drops them
ns.Dialogs = ns.Dialogs or {}
ns.Dialogs["FLAREUI_COLORS_UNSAVED"] = {
    text = L["You changed colours without applying them."],
    button1 = L["Apply"],
    button2 = L["Discard"],
    OnAccept = function()
        if not window then return end
        window.saved = nil
        window:Hide()
    end,
    OnCancel = function()
        if not window then return end
        window.discard = true
        window:Hide()
    end,
}
local function TryClose()
    if Dirty() then ns.ShowDialog("FLAREUI_COLORS_UNSAVED") else window:Hide() end
end

local function PickColor(row)
    local kind = KINDS[kindNow]
    local start = kind.color(row.key)
    local before = kind.store()[row.key]
    local info = {
        r = start[1], g = start[2], b = start[3], hasOpacity = false,
        swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            SetColor(row.key, { r, g, b })
        end,
        cancelFunc = function() SetColor(row.key, before) end,
    }
    Show(row.key)
    DrawPreviews()
    if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end
end

local function BuildList()
    local Panel = ns.SettingsPanel
    local child = window.listChild
    for _, row in ipairs(window.rows or {}) do row:Hide() end
    window.rows = {}
    local y = 0
    for _, group in ipairs(KINDS[kindNow].rows()) do
        local head = CreateFrame("Frame", nil, child)
        head:SetSize(LIST_W - 30, ROW_H)
        head:SetPoint("TOPLEFT", 0, -y)
        head.text = head:CreateFontString(nil, "OVERLAY", Panel.FONT.GameFontNormalLarge or "GameFontNormalLarge")
        head.text:SetPoint("BOTTOMLEFT", 4, 3)
        head.text:SetText(group[1])
        local line = head:CreateTexture(nil, "ARTWORK")
        line:SetPoint("BOTTOMLEFT", 0, 0)
        line:SetPoint("BOTTOMRIGHT", 0, 0)
        line:SetHeight(1)
        line:SetColorTexture(0.55, 0.42, 0.24, 0.6)
        window.rows[#window.rows + 1] = head
        y = y + ROW_H + 4
        for _, item in ipairs(group[2]) do
            local row = CreateFrame("Button", nil, child)
            row:SetSize(LIST_W - 30, ROW_H)
            row:SetPoint("TOPLEFT", 0, -y)
            row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            row.key = item[1]
            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            Panel.Rounded(hl, 1, 0.82, 0.45, 0.10)
            hl:SetAllPoints()
            local rim = row:CreateTexture(nil, "ARTWORK", nil, 1)
            rim:SetSize(18, 18)
            rim:SetPoint("LEFT", 6, 0)
            rim:SetColorTexture(0.55, 0.42, 0.24)
            row.swatch = row:CreateTexture(nil, "ARTWORK", nil, 2)
            row.swatch:SetPoint("TOPLEFT", rim, "TOPLEFT", 2, -2)
            row.swatch:SetPoint("BOTTOMRIGHT", rim, "BOTTOMRIGHT", -2, 2)
            row.label = row:CreateFontString(nil, "OVERLAY", Panel.FONT.GameFontHighlight or "GameFontHighlight")
            row.label:SetPoint("LEFT", rim, "RIGHT", 10, 0)
            row.label:SetText(item[2])
            row.hex = row:CreateFontString(nil, "OVERLAY", Panel.FONT.GameFontDisableSmall or "GameFontDisableSmall")
            row.hex:SetPoint("RIGHT", -6, 0)
            -- a dot beside a colour the player picked (the rest come from the palette)
            row.own = row:CreateTexture(nil, "OVERLAY")
            row.own:SetSize(6, 6)
            row.own:SetPoint("RIGHT", row.hex, "LEFT", -6, 0)
            row.own:SetColorTexture(1, 0.83, 0.47)
            row:SetScript("OnClick", function(self, button)
                ns.ButtonSound()
                if button == "RightButton" then SetColor(self.key, nil) else PickColor(self) end
            end)
            row:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(item[2], 1, 1, 1)
                GameTooltip:AddLine(L["Click: pick a colour. Right-click: the palette's own."], 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", GameTooltip_Hide)
            window.rows[#window.rows + 1] = row
            y = y + ROW_H
        end
        y = y + 8
    end
    child:SetSize(LIST_W - 30, y)
end

--------------------------------------------------
-- 3. THE WINDOW
--------------------------------------------------
local function Build()
    local Panel = ns.SettingsPanel
    local f = CreateFrame("Frame", "FlareUI_ColorPickerWindow", UIParent, "BackdropTemplate")
    f:SetSize(WIDTH, HEIGHT)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    local close = Panel.DressWindow(f)
    close:SetScript("OnClick", TryClose)
    tinsert(UISpecialFrames, "FlareUI_ColorPickerWindow")

    f.title = f:CreateFontString(nil, "OVERLAY", Panel.FONT.GameFontNormalHuge or "GameFontNormalHuge")
    f.title:SetPoint("TOPLEFT", 24, -20)
    f.title:SetText(L["Pick Your Colours"])
    f.sub = f:CreateFontString(nil, "OVERLAY", Panel.FONT.GameFontHighlight or "GameFontHighlight")
    f.sub:SetPoint("LEFT", f.title, "RIGHT", 14, -2)
    f.sub:SetTextColor(0.66, 0.61, 0.53)

    -- the list, left
    local listBox = CreateFrame("Frame", nil, f, "BackdropTemplate")
    listBox:SetPoint("TOPLEFT", 20, -62)
    listBox:SetPoint("BOTTOMLEFT", 20, 62)
    listBox:SetWidth(LIST_W)
    Panel.Box(listBox, 0.35)
    local scroll = CreateFrame("ScrollFrame", nil, listBox, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -26, 8)
    f.listChild = CreateFrame("Frame", nil, scroll)
    f.listChild:SetSize(LIST_W - 30, 10)
    scroll:SetScrollChild(f.listChild)

    -- the samples, right
    local previewBox = CreateFrame("Frame", nil, f, "BackdropTemplate")
    previewBox:SetPoint("TOPLEFT", listBox, "TOPRIGHT", 14, 0)
    previewBox:SetPoint("BOTTOMRIGHT", -20, 62)
    Panel.Box(previewBox, 0.35)
    f.preview = CreateFrame("Frame", nil, previewBox)
    f.preview:SetAllPoints()
    f.preview:SetClipsChildren(true)

    -- the foot: what a click does, then Reset (Custom with changes only), the palettes and Apply
    f.hint = f:CreateFontString(nil, "OVERLAY", Panel.FONT.GameFontDisableSmall or "GameFontDisableSmall")
    f.hint:SetPoint("BOTTOMLEFT", 26, 28)
    f.hint:SetText(L["Click a colour to change it; right-click gives it back to the palette."])
    f.apply = Panel.SkinButton(CreateFrame("Button", nil, f, "UIPanelButtonTemplate"))
    f.apply:SetSize(100, 28)
    f.apply:SetPoint("BOTTOMRIGHT", -24, 20)
    f.apply:SetText(L["Apply"])
    f.apply:SetScript("OnClick", function()
        ns.ButtonSound()
        f.saved = nil   -- kept
        f:Hide()
    end)
    f.palette = CreateFrame("DropdownButton", nil, f, "WowStyle1DropdownTemplate")
    f.palette:SetWidth(150)
    f.palette:SetPoint("RIGHT", f.apply, "LEFT", -8, 0)
    if Panel.SkinDropdown then Panel.SkinDropdown(f.palette) end
    local function Picked(p) return CurrentPalette() == p end
    f.palette:SetupMenu(function(_, root)
        for _, p in ipairs(PALETTES) do
            root:CreateRadio(PaletteText(p), function() return Picked(p) end, function() PickPalette(p) end)
        end
    end)
    f.palette:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip_SetTitle(GameTooltip, L["Colour Palette"], HIGHLIGHT_FONT_COLOR)
        GameTooltip_AddNormalLine(GameTooltip, L["FlareUI is the default. Change any colour and it becomes Custom. Apply keeps your choice."])
        GameTooltip:Show()
    end)
    f.palette:HookScript("OnLeave", GameTooltip_Hide)
    -- the Gamepad UI: FlareUI's plain list in place of Blizzard's menu (PadNav.GuardDropdown)
    if ns.PadNav and ns.PadNav.GuardDropdown then
        ns.PadNav.GuardDropdown(f.palette, function()
            local entries = {}
            for _, p in ipairs(PALETTES) do
                entries[#entries + 1] = { text = PaletteText(p), checked = function() return Picked(p) end,
                                          pick = function() PickPalette(p) end }
            end
            return entries
        end)
    end
    f.reset = Panel.SkinButton(CreateFrame("Button", nil, f, "UIPanelButtonTemplate"))
    f.reset:SetSize(100, 28)
    f.reset:SetPoint("RIGHT", f.palette, "LEFT", -12, 0)
    f.reset:SetText(L["Reset"])
    f.reset:SetScript("OnClick", function()
        ns.ButtonSound()
        wipe(KINDS[kindNow].store())
        Changed()
    end)
    f:SetScript("OnHide", function()
        if ColorPickerFrame and ColorPickerFrame:IsShown() then ColorPickerFrame:Hide() end
        -- Escape (UISpecialFrames) with changes not applied: back up, and ask
        if not f.discard and Dirty() then
            C_Timer.After(0, function()
                f:Show()
                ns.ShowDialog("FLAREUI_COLORS_UNSAVED")
            end)
            return
        end
        -- closed without Apply (nothing changed, or Discard): back to what it opened with
        f.discard = nil
        Restore()
    end)
    return f
end

-- kind: "uf" or "rb"
function CP.Open(kind)
    if not KINDS[kind] then return end
    window = window or Build()
    -- another kind's window still open: its changes are asked about first
    if window:IsShown() and kindNow ~= kind then
        if Dirty() then ns.ShowDialog("FLAREUI_COLORS_UNSAVED") return end
        window:Hide()
    end
    kindNow = kind
    if not window.saved then Snapshot() end
    window.sub:SetText(KINDS[kind].title())
    BuildList()
    UpdatePaletteControls()
    window:Show()
    window:Raise()
    -- the samples measure the window once it is laid out
    C_Timer.After(0, Repaint)
    Repaint()
end
