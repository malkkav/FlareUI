local _, ns = ...
local L = ns.L

--------------------------------------------------
-- PICK YOUR COLOURS (11-11)
-- The Custom Colour Palette's own window: every colour the unit frames (or the resource bars) draw,
-- each a row with its swatch, and the frames themselves beside them (the modules' settings-preview
-- samples), repainted on every change. A click opens Blizzard's colour picker; a right-click gives
-- the row back to the palette Custom started from. The colours: unitframes.customColors and
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
        apply = function()
            local RB = ns.ResourceBars
            RB.ApplyPalette()
            if RB.Refresh then RB:Refresh() end
        end,
        rows = ResourceRows,
    },
}

local window, kindNow

--------------------------------------------------
-- 1. PREVIEWS (the modules' own samples, as the settings pages' pictures)
--------------------------------------------------
local samples = {}

local function Place(frame, x, y, maxW, maxH)
    if not frame then return 0 end
    frame:SetScale(1)
    local w, h = frame:GetSize()
    if not (w and w > 0 and h and h > 0) then return 0 end
    local k = math.min(1, maxW / w, (maxH or h) / h)
    frame:SetScale(k)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", window.preview, "TOPLEFT", x / k, -y / k)
    frame:Show()
    return h * k
end

local function UnitSample(id, unit, style)
    local UF = ns.UnitFrames
    local f = samples[id]
    if not f then
        f = UF.CreateSample(window.preview, unit)
        samples[id] = f
    end
    if not f then return nil end
    local e = UF.DrawSample(f, style)
    if not e then f:Hide() return nil end
    return f, e
end

local function DrawUnitPreviews()
    local UF, PF = ns.UnitFrames, ns.PartyFrames
    local style = ns.UFRing and ns.UFRing.Style() or "addon"
    local width = window.preview:GetWidth() - 2 * PAD
    local y = PAD
    for _, unit in ipairs({ "player", "target" }) do
        local f, e = UnitSample("unit:" .. unit, unit, style)
        if f and e then
            local k = math.min(1, width / e.width)
            f:SetScale(k)
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", window.preview, "TOPLEFT", (PAD + e.left * k) / k, -(y + e.top * k) / k)
            f:Show()
            y = y + e.height * k + 10
        end
    end
    -- the party, as the tiles draw it (a few classes)
    if PF and PF.SampleTile then
        local box = samples.party
        if not box then
            box = CreateFrame("Frame", nil, window.preview)
            box.tiles = {}
            for i = 1, 5 do box.tiles[i] = PF.SampleTile(box, nil, nil, i) end
            samples.party = box
        end
        local tw, th, gap = 0, 0, 6
        for _, t in ipairs(box.tiles) do tw, th = PF.DrawSampleTile(t) end
        for i, t in ipairs(box.tiles) do
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", box, "TOPLEFT", (i - 1) * (tw + gap), 0)
        end
        box:SetSize(5 * tw + 4 * gap, th)
        y = y + Place(box, PAD, y, width) + 12
    end
    -- your cast bar, casting
    if UF.CreateCastSample then
        local cast = samples.cast
        if not cast then cast = UF.CreateCastSample(window.preview); samples.cast = cast end
        if cast then
            UF.DrawCastSample(cast)
            Place(cast, PAD, y, width)
        end
    end
end

local function DrawResourcePreviews()
    local RB = ns.ResourceBars
    if not (RB and RB.CreateSample) then return end
    RB.ApplyPalette()
    local width = window.preview:GetWidth() - 2 * PAD
    local y = PAD
    for _, key in ipairs({ "health", "power", "mana", "combo", "swingMain", "swingOff", "swingRanged" }) do
        local holder = samples["rb:" .. key]
        if not holder then holder = RB.CreateSample(window.preview, key); samples["rb:" .. key] = holder end
        if holder then
            RB.DrawSample(holder)
            y = y + Place(holder, PAD, y, width) + 10
        end
    end
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
            row.own:SetShown(kind.store()[row.key] ~= nil)
        end
    end
    DrawPreviews()
end

local function SetColor(key, c)
    local kind = KINDS[kindNow]
    kind.store()[key] = c and { c[1], c[2], c[3] } or nil
    kind.apply()
    Repaint()
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
    close:SetScript("OnClick", function() f:Hide() end)
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

    -- the foot: what a click does, and Reset All
    f.hint = f:CreateFontString(nil, "OVERLAY", Panel.FONT.GameFontDisableSmall or "GameFontDisableSmall")
    f.hint:SetPoint("BOTTOMLEFT", 26, 28)
    f.hint:SetText(L["Click a colour to change it; right-click gives it back to the palette."])
    local reset = Panel.SkinButton(CreateFrame("Button", nil, f, "UIPanelButtonTemplate"))
    reset:SetSize(140, 28)
    reset:SetPoint("BOTTOMRIGHT", -24, 20)
    reset:SetText(L["Reset All"])
    reset:SetScript("OnClick", function()
        ns.ButtonSound()
        local kind = KINDS[kindNow]
        wipe(kind.store())
        kind.apply()
        Repaint()
    end)
    f:SetScript("OnHide", function() if ColorPickerFrame and ColorPickerFrame:IsShown() then ColorPickerFrame:Hide() end end)
    return f
end

-- kind: "uf" or "rb"
function CP.Open(kind)
    if not KINDS[kind] then return end
    window = window or Build()
    kindNow = kind
    window.sub:SetText(KINDS[kind].title())
    BuildList()
    window:Show()
    window:Raise()
    -- the samples measure the window once it is laid out
    C_Timer.After(0, Repaint)
    Repaint()
end
