local _, ns = ...
local S = ns.Settings
local L = ns.L

--------------------------------------------------
-- NAMEPLATES
-- Settings for Modules/Nameplates.lua. A preview strip sits pinned above every tab: a real plate drawn
-- by the module's own code (NP.CreateSample / DrawSample), larger, in the states its chips pick, plus
-- the state of the row under the mouse. The Info panel keeps only each row's text.
--------------------------------------------------
local function NP() return ns.Nameplates end
local function Refresh()
    local np = NP()
    if np and np.Refresh then np:Refresh() end
end

-- THE INFO PANEL'S LOWER PART (Panel.lua module.sidePanel)
-- The row's text keeps the top part. Below it, two boxes as the Radial page's:
--   Plate Setup: the unit being edited and its preset, picked from text links (as the Radial
--     Catalog's), and Undo Changes
--   Live Preview: a real plate drawn by the module's own code (NP.CreateSample / DrawSample) showing
--     everything the type's settings draw, and Test in Game
-- The hovered row adds its own state.
local PIN = { hover = nil, scale = 1.5, kind = "enemyNpc" }
-- (11-20: players and NPCs split again; Minions are part of Minor)
local KINDS = { { "enemyPlayer", L["Enemy Player"] }, { "enemyNpc", L["Enemy NPC"] }, { "friendlyPlayer", L["Friendly Player"] },
                { "friendlyNpc", L["Friendly NPC"] }, { "minor", L["Minor"] } }
local PRESETS = { { "full", L["Full"] }, { "compact", L["Simple"] }, { "tiny", L["Minimal"] }, { "name", L["Name Only"] },
                  { "custom", L["Custom"] } }
local function Named(list, key) for _, e in ipairs(list) do if e[1] == key then return e[2] end end return key end
-- a preset's name; each type's own Custom says whose it is (11-20): "Custom Enemy NPC"
local function PresetName(key, kind)
    if key == "custom" then return L["Custom %s"]:format(Named(KINDS, kind or PIN.kind)) end
    return Named(PRESETS, key)
end
-- the tabs whose rows every unit type shares (the others are each type's own)
local SHARED_TABS = { targeting = true, visibility = true, fonts = true }
-- a setting of the type being edited
local function TV(key) local np = NP() return np and np.TypeDB(PIN.kind)[key] end
-- what the preview shows: every state the type's settings draw (Can't Interrupt aside: the cast shows
-- as one you can interrupt)
local function Shows(state)
    local tweaks = ns.db and ns.db.profile and ns.db.profile.tweaks or {}
    local cast = TV("castbar") and TV("plate") ~= "name"
    if state == "cast" then return cast and true or false end
    if state == "important" then return (cast and TV("castImportant")) and true or false end
    if state == "kick" then return (cast and TV("kickReady")) and true or false end
    if state == "targeted" then return (cast and TV("castTargetedFlash")) and true or false end
    if state == "threat" then return TV("threat") ~= "off" end
    if state == "focus" then return TV("colorFocus") and true or false end
    if state == "execute" then return TV("execute") ~= "off" end
    if state == "quest" then local np = NP() return (np and np.QuestOn and np.QuestOn()) and true or false end
    if state == "combo" then return tweaks.nameplateCombo and true or false end
    return true
end
local STATES = { "target", "cast", "important", "kick", "targeted", "threat", "focus", "execute", "quest", "combo" }
-- the state each row is about, while the mouse is on it
local HOVER = {
    ["np.targetScale"] = { target = true }, ["np.border"] = { target = true },
    -- (threat rows show a plate that isn't your target: your target's own border wins over Threat Glow)
    ["np.threat"] = { threat = true, target = false }, ["np.role"] = { threat = true, target = false },
    ["np.threatScale"] = { threat = true, target = false },
    ["np.castbar"] = { cast = true }, ["np.castHeight"] = { cast = true }, ["np.castIcon"] = { cast = true },
    ["np.castTarget"] = { cast = true }, ["np.castImportant"] = { cast = true, important = true },
    ["np.kickReady"] = { cast = true, kick = true }, ["np.execute"] = { execute = true },
    ["np.colorFocus"] = { focus = true }, ["np.questMarks"] = { quest = true }, ["np.comboPoints"] = { combo = true },
    ["np.castTargetedFlash"] = { cast = true, targeted = true }, ["np.threatGlow"] = { threat = true, target = false },
    ["np.aggroFlash"] = { threat = true, target = false },
    ["np.targetAlpha"] = { target = true }, ["np.targetArrows"] = { target = true }, ["np.targetArrowSide"] = { target = true },
    ["np.targetBorder"] = { target = true }, ["np.targetBarColor"] = { target = true }, ["np.targetGlow"] = { target = true },
    ["np.castKickMark"] = { cast = true },
}

local function RefreshAll(draw)
    if ns.SettingsPanel and ns.SettingsPanel.Refresh then ns.SettingsPanel:Refresh() else draw() end
end

-- Bar Effects on: the preview takes a hit every couple of seconds (and heals back up), so the
-- animation, the edge glow and the damage trail show
local DEMO_EVERY = 2
local function DemoTick(host, elapsed)
    host.demoWait = (host.demoWait or 0) + elapsed
    if host.demoWait < DEMO_EVERY then return end
    host.demoWait = 0
    local np = NP()
    local db = S:GetPath("nameplates") or {}
    if np and np.SampleHit and (db.smoothBars or db.edgeGlow or db.damageTrail) and host.sample then np.SampleHit(host.sample) end
end

local DrawSide
local SIDE_PAD, CELL_H, CELL_GAP = 12, 18, 2
-- the picked choice: the rows' soft bronze rounded box behind it
local PICK_COLOR = { 1, 0.84, 0.50, 0.26 }   -- palette goldHighlight

-- Undo Changes: each type's setup (preset and Custom) as it was when the settings window opened
local function CopyOf(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = CopyOf(x) end
    return t
end
local function Setup(kind)
    local types = S:GetPath("nameplates.types")
    local own = types and types[kind]
    return { preset = own and own.preset, custom = own and CopyOf(own.custom) }
end
local function Changed(kind)
    local snap = PIN.snap and PIN.snap[kind]
    local np = NP()
    if not (snap and np and np.SameValue) then return false end
    local now = Setup(kind)
    return not (now.preset == snap.preset and np.SameValue(now.custom, snap.custom))
end
local function Undo(kind)
    local snap = PIN.snap and PIN.snap[kind]
    local np = NP()
    if not (snap and np) then return end
    local own = np.TypeStore(kind)
    if not own then return end
    own.preset, own.custom = snap.preset, CopyOf(snap.custom)
end

-- a text link: picked in WoW yellow, the rest grey (the Radial Catalog's)
local function PaintLink(b)
    local fs = b:GetFontString()
    if b.on then fs:SetTextColor(1, 0.82, 0)
    elseif b.hover then fs:SetTextColor(0.9, 0.9, 0.9)
    else fs:SetTextColor(0.5, 0.5, 0.5) end
end
local function LinkEnter(self) self.hover = true PaintLink(self) end
local function LinkLeave(self) self.hover = nil PaintLink(self) end

local function Build(host, np)
    local Panel = ns.SettingsPanel
    local function Label(parent, text, font)
        local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
        fs:SetText(text)
        return fs
    end
    -- a small action link (Undo Changes, Test in Game), as the Radial page's
    local function Action(parent, text, font, onClick)
        local b = CreateFrame("Button", nil, parent)
        b:SetNormalFontObject(font or "GameFontNormalSmall")
        b:SetHighlightFontObject("GameFontHighlightSmall")
        b:SetDisabledFontObject("GameFontDisableSmall")
        b:SetText(text)
        b:SetHeight(18)
        b:SetScript("OnClick", function()
            if ns.ButtonSound then ns.ButtonSound() end
            onClick()
        end)
        return b
    end
    local function Box()
        local box = CreateFrame("Frame", nil, host, "BackdropTemplate")
        Panel.Box(box, 0.40)
        box:SetFrameLevel(host:GetFrameLevel())
        return box
    end
    host.editBox = Box()
    host.editBox:SetPoint("TOPLEFT", host, "TOPLEFT")
    host.editBox:SetPoint("RIGHT", host, "RIGHT")
    host.previewBox = Box()
    host.previewBox:SetPoint("TOPLEFT", host.editBox, "BOTTOMLEFT", 0, -8)
    host.previewBox:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT")

    -- PLATE SETUP: Undo Changes beside the title; Unit and Preset as link lists
    host.editTitle = Label(host.editBox, L["Plate Setup"])
    host.editTitle:SetPoint("TOPLEFT", host.editBox, "TOPLEFT", SIDE_PAD, -12)
    host.undo = Action(host.editBox, L["Undo Changes"], nil, function()
        Undo(PIN.kind)
        if np.Refresh then np:Refresh() end
        RefreshAll(DrawSide)
    end)
    -- Reset: the unit back to its default preset (its Custom goes; Undo Changes brings it back)
    host.reset = Action(host.editBox, L["Reset"], nil, function()
        local own = np.TypeStore(PIN.kind)
        if own then own.preset, own.custom = nil, nil end
        if np.Refresh then np:Refresh() end
        RefreshAll(DrawSide)
    end)
    host.reset:SetPoint("RIGHT", host.editBox, "RIGHT", -SIDE_PAD + 3, 0)
    host.reset:SetPoint("BOTTOM", host.editTitle, "BOTTOM", 0, -2)
    host.undo:SetPoint("RIGHT", host.reset, "LEFT", -6, 0)
    host.undo:SetPoint("BOTTOM", host.editTitle, "BOTTOM", 0, -2)
    -- a list of choices: in aligned columns (the picked one in yellow on a rounded box), or with
    -- cols 0 in one line split by yellow slashes, as the Radial Catalog (the picked one in yellow)
    local function Group(text, list, cols, picked, pick)
        local g = { label = Label(host.editBox, text), cells = {}, cols = cols, picked = picked }
        for i, e in ipairs(list) do
            local b = CreateFrame("Button", nil, host.editBox)
            b:SetNormalFontObject("GameFontNormalSmall")
            b:SetText(e[2])
            local fs = b:GetFontString()
            fs:ClearAllPoints()
            fs:SetPoint("LEFT", cols == 0 and 1 or 6, 0)
            fs:SetPoint("RIGHT", cols == 0 and -1 or -2, 0)
            if cols == 0 then
                b.textW = (fs:GetStringWidth() or 40) + 2
                g.slashes = g.slashes or {}
                local slash = host.editBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                slash:SetText("/")
                slash:SetTextColor(1, 0.82, 0)
                g.slashes[i] = slash
            end
            fs:SetJustifyH("LEFT")
            fs:SetWordWrap(false)
            b.box = b:CreateTexture(nil, "BACKGROUND")
            b.box:SetAllPoints()
            ns.SettingsPanel.Rounded(b.box, PICK_COLOR[1], PICK_COLOR[2], PICK_COLOR[3], PICK_COLOR[4])
            b.key = e[1]
            b:SetScript("OnClick", function(self)
                if ns.ButtonSound then ns.ButtonSound() end
                pick(self.key)
            end)
            b:SetScript("OnEnter", LinkEnter)
            b:SetScript("OnLeave", LinkLeave)
            g.cells[i] = b
        end
        return g
    end
    -- (two columns: the five names don't fit one line)
    host.unitGroup = Group(L["Unit"], KINDS, 2, function() return PIN.kind end, function(key)
        PIN.kind = key
        if np.testing then np.TestMode(true, PIN.kind) end
        RefreshAll(DrawSide)
    end)
    -- Preset: a dropdown as the rows' (only the one in use shows)
    host.presetLabel = Label(host.editBox, L["Preset"])
    host.presetDrop = CreateFrame("DropdownButton", nil, host.editBox, "WowStyle2DropdownTemplate")
    if ns.SettingsPanel.BoxArrow then ns.SettingsPanel.BoxArrow(host.presetDrop) end
    host.presetDrop:SetupMenu(function(_, root)
        for _, pr in ipairs(PRESETS) do
            root:CreateRadio(PresetName(pr[1]), function() return np.PresetOf(PIN.kind) == pr[1] end, function()
                np.SetPreset(PIN.kind, pr[1])
                if np.Refresh then np:Refresh() end
                RefreshAll(DrawSide)
            end)
        end
    end)

    -- LIVE PREVIEW: Test in Game beside the title, the plate below
    host.previewTitle = Label(host.previewBox, L["Live Preview"])
    host.previewTitle:SetPoint("TOPLEFT", host.previewBox, "TOPLEFT", SIDE_PAD, -12)
    host.test = Action(host.previewBox, L["Test in Game"], nil, function()
        if np.testing then np.TestMode(false) DrawSide() else ns.NameplatesPinned.StartTest() end
    end)
    host.test:SetPoint("RIGHT", host.previewBox, "RIGHT", -SIDE_PAD + 3, 0)
    host.test:SetPoint("BOTTOM", host.previewTitle, "BOTTOM", 0, -2)
    host.area = CreateFrame("Frame", nil, host.previewBox)
    host.area:SetPoint("TOPLEFT", host.previewBox, "TOPLEFT", SIDE_PAD, -36)
    host.area:SetPoint("BOTTOMRIGHT", host.previewBox, "BOTTOMRIGHT", -SIDE_PAD, SIDE_PAD)
    host.sample = np.CreateSample(host.area, "pinned")
    host:SetScript("OnUpdate", DemoTick)
    -- a fresh Undo each time the settings window opens (the column shows with it)
    local column = host:GetParent()
    -- (not when it comes back from a test: the changes before the test can still be undone)
    if column then column:HookScript("OnShow", function() if not PIN.fromTest then PIN.snap = {} end end) end
end

-- a group's choices in its columns, after its label; returns the y under its last row
local function PlaceGroup(host, g, y, startX)
    local box = host.editBox
    local bw = box:GetWidth()
    if not bw or bw <= 0 then bw = ns.SettingsPanel.RIGHT_W or 280 end   -- (not laid out yet)
    local picked = g.picked()
    g.label:ClearAllPoints()
    g.label:SetPoint("LEFT", box, "TOPLEFT", SIDE_PAD, y - CELL_H / 2)
    if g.cols == 0 then
        -- one line: each choice as wide as its name, a slash between two
        local SLASH_W = 14
        local x = startX
        for i, b in ipairs(g.cells) do
            if i > 1 then x = x + SLASH_W end
            b:ClearAllPoints()
            b:SetSize(b.textW, CELL_H)
            b:SetPoint("TOPLEFT", box, "TOPLEFT", x, y)
            local slash = g.slashes[i]
            slash:ClearAllPoints()
            slash:SetPoint("CENTER", b, "LEFT", -SLASH_W / 2, 0)
            slash:SetShown(i > 1)
            x = x + b.textW
            b.on = b.key == picked
            b.box:Hide()
            PaintLink(b)
        end
        return y - CELL_H
    end
    local cellW = math.floor((bw - SIDE_PAD - startX - (g.cols - 1) * CELL_GAP) / g.cols)
    local rows = 0
    for i, b in ipairs(g.cells) do
        local row, col = math.floor((i - 1) / g.cols), (i - 1) % g.cols
        rows = row + 1
        b:ClearAllPoints()
        b:SetSize(cellW, CELL_H)
        b:SetPoint("TOPLEFT", box, "TOPLEFT", startX + col * (cellW + CELL_GAP), y - row * (CELL_H + CELL_GAP))
        b.on = b.key == picked
        b.box:SetShown(b.on)
        PaintLink(b)
    end
    return y - rows * (CELL_H + CELL_GAP) + CELL_GAP
end

DrawSide = function()
    local host = PIN.host
    local np = NP()
    if not (host and host:IsShown() and np and np.CreateSample) then return end
    if not host.editBox then Build(host, np) end
    -- Plate Setup: the two lists, as tall as they need (the labels share one column)
    local labelW = math.max(host.unitGroup.label:GetStringWidth() or 30, host.presetLabel:GetStringWidth() or 40)
    local startX = SIDE_PAD + labelW + 6
    local y = PlaceGroup(host, host.unitGroup, -38, startX)
    -- Preset: its dropdown from the links' column to the box's right
    y = y - 8
    local dd = host.presetDrop
    dd:ClearAllPoints()
    dd:SetPoint("TOPLEFT", host.editBox, "TOPLEFT", startX, y)
    dd:SetPoint("RIGHT", host.editBox, "RIGHT", -SIDE_PAD, 0)
    host.presetLabel:ClearAllPoints()
    host.presetLabel:SetPoint("LEFT", host.editBox, "LEFT", SIDE_PAD, 0)
    host.presetLabel:SetPoint("TOP", dd, "TOP")
    host.presetLabel:SetPoint("BOTTOM", dd, "BOTTOM")
    dd:GenerateMenu()
    y = y - (dd:GetHeight() > 0 and dd:GetHeight() or 26)
    host.editBox:SetHeight(-y + SIDE_PAD)
    -- Undo Changes: from the setup this type had when the window opened
    PIN.snap = PIN.snap or {}
    if not PIN.snap[PIN.kind] then PIN.snap[PIN.kind] = Setup(PIN.kind) end
    host.undo:SetEnabled(Changed(PIN.kind))
    local own = (S:GetPath("nameplates.types") or {})[PIN.kind]
    local default = np.C.DEFAULT_PRESET[PIN.kind] or "full"
    host.reset:SetEnabled((own and ((own.preset and own.preset ~= default) or own.custom)) and true or false)
    host.reset:SetWidth((host.reset:GetFontString():GetStringWidth() or 30) + 6)
    host.undo:SetWidth((host.undo:GetFontString():GetStringWidth() or 60) + 6)
    host.test:SetText(np.testing and L["Stop Test"] or L["Test in Game"])
    host.test:SetWidth((host.test:GetFontString():GetStringWidth() or 60) + 6)
    -- the preview: everything this type's settings draw, plus the hovered row's state
    local states = {}
    for _, state in ipairs(STATES) do
        if Shows(state) then states[state] = true end
    end
    for k, v in pairs(PIN.hover or {}) do states[k] = v end
    local f = host.sample
    f.kind = PIN.kind
    f:SetScale(1)
    f:Show()
    local w, h = np.DrawSample(f, states)
    if not (w and h and w > 0 and h > 0) then return end
    local aw, ah = host.area:GetWidth(), host.area:GetHeight()
    local k = PIN.scale
    if aw and aw > 0 then k = math.min(k, aw / w) end
    if ah and ah > 0 then k = math.min(k, ah / h) end
    f:SetScale(k)
    f:ClearAllPoints()
    f:SetPoint("CENTER", host.area, "CENTER", 0, 0)
end
ns.NameplatesPinned = { Draw = DrawSide }

-- Test in Game: the settings window steps aside for a single Stop Testing button in the middle of the
-- screen; the test runs until it is pressed, then the window comes back on this page
function ns.NameplatesPinned.StartTest()
    local np = NP()
    if not np then return end
    local stop = PIN.stopButton
    if not stop then
        stop = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
        stop:SetSize(180, 34)
        stop:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        stop:SetFrameStrata("DIALOG")
        stop:SetText(L["Stop Testing"])
        stop:SetScript("OnClick", function(self)
            self:Hide()
            np.TestMode(false)
            PIN.fromTest = true
            if ns.SettingsPanel then ns.SettingsPanel:Open("np") end
            PIN.fromTest = nil
        end)
        stop:Hide()
        PIN.stopButton = stop
    end
    np.TestMode(true, PIN.kind, true)
    if ns.SettingsPanel then ns.SettingsPanel:Hide() end
    stop:Show()
end
local STATE_ROWS = { ["np.plateState"] = true, ["np.stateScale"] = true, ["np.stateAlpha"] = true }
function ns.NameplatesPinned.Hover(key)
    local want = key and HOVER[key] or nil
    -- (the state rows show the target plate while Targeted is picked)
    if key and STATE_ROWS[key] and PIN.plateState == "target" then want = HOVER["np.targetScale"] end
    if want == PIN.hover then return end
    PIN.hover = want
    DrawSide()
end

S:Module{ key = "np", group = "combat", order = 5,   -- (first in Combat)
    enabled = "nameplates.enabled",
    -- (11-20: Targeting moved next to Visibility; it, Visibility and Fonts are shared by every type)
    tabs = { { key = "style" }, { key = "extras" }, { key = "cast" }, { key = "auras" }, { key = "targeting" },
             { key = "visibility" }, { key = "fonts" } },
    -- the page's subtitle names what the rows change
    subtitle = function(tab)
        local np = NP()
        if not np then return nil end
        -- the shared tabs say so, instead of the unit being edited (11-20)
        if SHARED_TABS[tab] then return L["Overall options for all plates"] end
        return L["Editing: %s (%s)"]:format(Named(KINDS, PIN.kind), PresetName(np.PresetOf(PIN.kind)))
    end,
    sidePanel = {
        -- Plate Setup and Live Preview at the bottom; the text box gets the rest
        height = 360,   -- (11-20: +30 for the Unit list's three rows)
        show = function(host)
            PIN.host = host
            DrawSide()
            C_Timer.After(0, DrawSide)   -- (again once the column is laid out)
        end,
        hover = function(key) ns.NameplatesPinned.Hover(key) end,
        -- shown while no setting is under the mouse
        idle = { L["How It Works"], L["* Pick the Unit to change: enemy or friendly players, enemy or friendly NPCs, or Minor (minor mobs, pets, totems and guardians).\n* Pick a Preset. Change any setting and it becomes Custom, saved for that unit.\n* Live Preview shows everything the plate can show. Test in Game puts it on the plates around you."] },
    } }

-- the default preset's value of a per-type setting (what Reset brings back)
local function TypeDefault(key)
    local np = NP()
    if not (np and np.PresetValue) then return nil end
    return np.PresetValue(np.C.DEFAULT_PRESET[PIN.kind] or "full", key, PIN.kind)
end
-- NAME ONLY MODE (11-20, Malkkav): with it on, the type's other rows on its own tabs grey out (a
-- Name Only plate draws none of them), unless Show Plates in Combat gives it its bar in a fight
local OWN_TABS = { style = true, extras = true, cast = true, auras = true }
local function NameOnlyLocked()
    if TV("plate") ~= "name" then return false end
    local v = S:GetPath("nameplates.combatPlates")
    if type(v) == "string" then
        for t in v:gmatch("[^,]+") do if t == PIN.kind then return false end end
    end
    return true
end
local function Row(def)
    def.apply = def.apply or Refresh
    if OWN_TABS[def.tab] and def.section ~= "np.nameOnlySection" then
        local own = def.disabled
        def.disabled = function()
            if NameOnlyLocked() then return true end
            if type(own) == "function" then return own() end
            return own
        end
    end
    if def.path and not def.path:find("%.") then
        local np = NP()
        local key = def.path
        if np and np.C and np.C.TYPE_KEYS[key] then
            -- a per-type setting: the type picked on the strip (a change makes its preset Custom)
            def.path = nil
            def.get = function() return np.TypeDB(PIN.kind)[key] end
            def.set = function(v) np.TypeSet(PIN.kind, key, v) end
            def.resetValue = def.resetValue or function() return TypeDefault(key) end
        else
            def.path = "nameplates." .. key
        end
    end
    return S:Row(def)
end
local function Steps(from, to, step, fmt)
    local list = {}
    for v = from, to + step / 2, step do
        local value = math.floor(v * 100 + 0.5) / 100
        list[#list + 1] = { value, fmt and fmt(value) or tostring(value) }
    end
    return list
end

-- PLATE (tab key "style"): how the plate is built - its look, size, level, bar text and health colour
-- Bar Texture: the unit frames' list (FlareUI's bars, a divider, Shared Media)
local function Textures()
    local list = {}
    local values = ns.UnitFrames and ns.UnitFrames.Kit and ns.UnitFrames.Kit.BuildTextureValues
    local made = values and values()
    if type(made) == "function" then made = made() end
    for _, v in ipairs(made or {}) do
        if v.isDivider then list[#list + 1] = { divider = true }
        elseif v.value then list[#list + 1] = { v.value, v.text } end
    end
    return list
end
-- FRAME: size and background first, then texture, border and level
Row{ key = "np.width", kind = "range", path = "width", choices = Steps(50, 240, 10), tab = "style", section = "np.frameSection" }
Row{ key = "np.height", kind = "range", path = "height", choices = Steps(10, 30, 1), tab = "style", section = "np.frameSection" }
Row{ key = "np.bgOpacity", kind = "range", path = "bgOpacity", choices = Steps(0, 100, 5, function(v) return v .. "%" end), tab = "style", section = "np.frameSection" }
Row{ key = "np.texture", kind = "choice", path = "texture", choices = Textures, tab = "style", section = "np.frameSection" }
-- Border: None, FlareUI Thin and Thick (the "FlareUI Frames" and "FlareUI Thick" art), Shared Media
local function Borders()
    local list = { { "None", L["None"] }, { "FlareUI Frames", L["FlareUI Thin"] }, { "FlareUI Thick", L["FlareUI Thick"] } }
    local skip = { ["FlareUI Thin"] = true, ["FlareUI Frames"] = true, ["FlareUI Thick"] = true }
    local others = {}
    for _, name in ipairs(ns.AddonMedia and ns.AddonMedia("border") or {}) do
        if not skip[name] then others[#others + 1] = name end
    end
    if #others > 0 then
        list[#list + 1] = { divider = true }
        for _, name in ipairs(others) do list[#list + 1] = { name, name } end
    end
    return list
end
Row{ key = "np.border", kind = "choice", path = "border", choices = Borders, tab = "style", section = "np.frameSection" }
-- Level: Off, a box or a disc on the left or right of the bar, or in front of the name. One choice
-- for two saved settings (level, levelSide), both per unit type
local function LevelGet()
    local np = NP()
    local db = np and np.TypeDB(PIN.kind) or {}
    local mode = db.level or "box"
    if mode ~= "box" and mode ~= "disc" then return mode end
    return mode .. (db.levelSide == "right" and "Right" or "Left")
end
local function LevelSet(v)
    local np = NP()
    if not np then return end
    local mode, side = v:match("^(%l+)(%u%l+)$")
    if mode then
        np.TypeSet(PIN.kind, "level", mode)
        np.TypeSet(PIN.kind, "levelSide", side:lower())
    else
        np.TypeSet(PIN.kind, "level", v)
    end
end
Row{ key = "np.level", kind = "choice", choices = { "off", "boxLeft", "boxRight", "discLeft", "discRight", "name" },
    tab = "style", section = "np.frameSection", get = LevelGet, set = LevelSet,
    resetValue = function()
        local mode, side = TypeDefault("level") or "box", TypeDefault("levelSide")
        if mode ~= "box" and mode ~= "disc" then return mode end
        return mode .. (side == "right" and "Right" or "Left")
    end }
-- LOOK: Bar Effects, Colour By (how the bar is coloured) and every colour the plates paint
-- Bar Effects: the unit frames' three, ticked together (each its own saved switch)
local EFFECTS = { { "animations", "smoothBars" }, { "glow", "edgeGlow" }, { "trail", "damageTrail" } }
Row{ key = "np.barEffects", kind = "dropdown", tab = "style", section = "np.look",
    choices = { "none", { divider = true }, "animations", "glow", "trail" },
    toggles = { exclusive = { "none" }, tokens = { "animations", "glow", "trail" }, empty = "none" },
    get = function()
        local list = {}
        for _, e in ipairs(EFFECTS) do
            if TV(e[2]) then list[#list + 1] = e[1] end
        end
        return #list > 0 and table.concat(list, ",") or "none"
    end,
    set = function(value)
        local on = {}
        for token in tostring(value or ""):gmatch("[^,]+") do on[token] = true end
        -- the type's own (11-20), as every row on this tab
        local np = NP()
        for _, e in ipairs(EFFECTS) do if np then np.TypeSet(PIN.kind, e[2], on[e[1]] and true or false) end end
    end,
    resetValue = function() return "none" end }
Row{ key = "np.healthColor", kind = "choice", path = "healthColor", choices = { "off", "reaction", "class", "health" }, tab = "style", section = "np.look" }
-- every colour the plates paint, in the colour window (Settings/ColorPicker.lua "np")
Row{ key = "np.pickColors", kind = "button", buttonText = L["Pick Your Colours"], tab = "style", section = "np.look", lead = true,
    apply = function() if ns.ColorPicker then ns.ColorPicker.Open("np") end end }
-- Bar text: Left, Middle and Right inside the bar, the unit frames' Health Text items, in the order
-- ticked. First Name stands alone in its slot (ticking it clears the numbers; a number clears it).
-- One dropdown, as on the unit frames: Left, Middle and Right submenus of ticks, numbered in the
-- order ticked; the box sums the three up. The row's value is the three slots in one string,
-- "left=firstname;middle=;right=value,max" (what Reset compares and writes back).
local BAR_SLOTS = { "left", "middle", "right" }
local function TextSlotsNow()
    local np = NP()
    return (np and np.TextSlots) and np.TextSlots(np.TypeDB(PIN.kind)) or { left = {}, middle = {}, right = {} }
end
local function EncodeSlots(all)
    local parts = {}
    for i, slot in ipairs(BAR_SLOTS) do
        parts[i] = slot .. "=" .. table.concat((ns.BarText.Ordered(all[slot] or {})), ",")
    end
    return table.concat(parts, ";")
end
Row{ key = "np.barText", kind = "dropdown", tab = "style", section = "np.health",
    choices = { "none", { divider = true }, "firstname", "percent", "value", "max", "lost" },
    slots = { { key = "left", text = L["Left"] }, { key = "middle", text = L["Centre"] }, { key = "right", text = L["Right"] } },
    slotTicked = function(slot, value)
        local set = TextSlotsNow()[slot]
        if value == "none" then return next(set) == nil end
        return set[value] and true or false
    end,
    slotPlace = function(slot, value)
        local set = TextSlotsNow()[slot]
        local _, n = ns.BarText.Ordered(set)
        return n > 1 and ns.BarText.Place(set, value) or nil
    end,
    -- the new value after a tick: None empties the slot; the name stands alone (ticking it clears
    -- the numbers, a number clears it); a new number goes last, an untick closes the gap
    slotToggle = function(slot, value)
        local all = TextSlotsNow()
        local out = { left = all.left, middle = all.middle, right = all.right }
        local list, n = ns.BarText.Ordered(all[slot])
        local set = {}
        if value == "firstname" then
            if not all[slot].firstname then set = { firstname = 1 } end
        elseif value ~= "none" then
            local k = 0
            for i = 1, n do
                local item = list[i]
                if item ~= "firstname" and item ~= value then k = k + 1; set[item] = k end
            end
            if not all[slot][value] then set[value] = k + 1 end
        end
        out[slot] = set
        return EncodeSlots(out)
    end,
    boxText = function() return ns.BarText.Summary(TextSlotsNow()) end,
    get = function() return EncodeSlots(TextSlotsNow()) end,
    set = function(value)
        local np = NP()
        if not np then return end
        local health = { left = {}, middle = {}, right = {} }
        for slot, items in tostring(value or ""):gmatch("(%a+)=([^;]*)") do
            if health[slot] then
                local n = 0
                for item in items:gmatch("[^,]+") do n = n + 1; health[slot][item] = n end
            end
        end
        np.TypeSet(PIN.kind, "barText", { health = health })
    end,
    resetValue = function()
        local np = NP()
        local right = np and np.BlizzardHealthDefault and np.BlizzardHealthDefault() or {}
        return EncodeSlots({ left = { firstname = true }, middle = {}, right = right })
    end }
Row{ key = "np.hideTextAtFull", path = "hideTextAtFull", tab = "style", section = "np.health" }

-- NAME ONLY MODE (11-20): the switch (the type's Plate: Name Only, as the Name Only preset), the name's
-- size, and which types get their whole plate back in a fight (shared: one list of types)
local function NameOnlyOff() return TV("plate") ~= "name" end
Row{ key = "np.nameOnlyMode", tab = "style", section = "np.nameOnlySection", lead = true,
    get = function() return TV("plate") == "name" end,
    set = function(on) local np = NP() if np then np.TypeSet(PIN.kind, "plate", on and "name" or "bar") end end,
    resetValue = function() return TypeDefault("plate") == "name" end,
    apply = function() Refresh() if ns.SettingsPanel and ns.SettingsPanel.Refresh then ns.SettingsPanel:Refresh() end end }
Row{ key = "np.nameOnlySize", kind = "range", path = "nameOnlySize", choices = Steps(50, 200, 10, function(v) return v .. "%" end),
    tab = "style", section = "np.nameOnlySection", disabled = NameOnlyOff }
Row{ key = "np.combatPlates", kind = "dropdown", tab = "style", section = "np.nameOnlySection",
    choices = { "none", { divider = true }, "enemyPlayer", "enemyNpc", "friendlyPlayer", "friendlyNpc", "minor" },
    toggles = { exclusive = { "none" }, tokens = { "enemyPlayer", "enemyNpc", "friendlyPlayer", "friendlyNpc", "minor" }, empty = "none" },
    get = function() return S:GetPath("nameplates.combatPlates") or "none" end,
    set = function(v) S:SetPath("nameplates.combatPlates", v) end,
    resetValue = function() return "none" end,
    apply = function() Refresh() if ns.SettingsPanel and ns.SettingsPanel.Refresh then ns.SettingsPanel:Refresh() end end }

-- TARGETING: size and opacity in three states (no target, your target, the others while you have
-- one), out of range, and how your target stands out
local function Scales(from, to)
    return Steps(from, to, 0.05, function(v) return math.floor(v * 100 + 0.5) .. "%" end)
end
-- Opacity: 0% up to 100% in 5% steps (full on the right)
local function Fades()
    local list = {}
    for v = 0, 100, 5 do list[#list + 1] = { v / 100, v .. "%" } end
    return list
end
-- State picker: one state at a time (No Target, Targeted, Not Targeted), its Scale and Opacity below
-- (the same saved settings as the six sliders before; the pick itself isn't saved)
PIN.plateState = PIN.plateState or "none"
local STATE_KEYS = {
    none = { "noTargetScale", "noTargetAlpha" }, target = { "targetScale", "targetAlpha" },
    other = { "notTargetScale", "nonTargetAlpha" },
}
local function StateRow(key, i, choices)
    Row{ key = key, kind = "range", choices = choices, tab = "targeting", section = "np.scaleSection",
        get = function() return S:GetPath("nameplates." .. STATE_KEYS[PIN.plateState][i]) end,
        set = function(v) S:SetPath("nameplates." .. STATE_KEYS[PIN.plateState][i], v) end,
        resetValue = function() return S:DefaultPath("nameplates." .. STATE_KEYS[PIN.plateState][i]) end }
end
Row{ key = "np.plateState", kind = "choice", choices = { "none", "target", "other" }, tab = "targeting", section = "np.scaleSection",
    get = function() return PIN.plateState end,
    set = function(v) PIN.plateState = STATE_KEYS[v] and v or "none" end,
    resetValue = function() return PIN.plateState end }
StateRow("np.stateScale", 1, Scales(0.5, 2))
StateRow("np.stateAlpha", 2, Fades())
-- Fading: for every plate, whatever State is picked above
Row{ key = "np.rangeAlpha", kind = "range", path = "rangeAlpha", choices = Fades(), tab = "targeting", section = "np.fadeSection" }
-- Out of Sight: the game's own fade for units behind walls (FlareUI sets it once picked; before that
-- the slider shows the game's value)
local function Sights()
    local list = {}
    for v = 0, 100, 5 do list[#list + 1] = { v / 100, v .. "%" } end
    return list
end
Row{ key = "np.obscuredAlpha", kind = "range", choices = Sights(), tab = "targeting", section = "np.fadeSection",
    get = function()
        local db = S:GetPath("nameplates") or {}
        if db.obscuredAlpha then return db.obscuredAlpha end
        local v = tonumber(C_CVar.GetCVar("nameplateOccludedAlphaMult")) or 0.4
        return math.floor(v * 20 + 0.5) / 20   -- (the game's value, on the slider's 5% steps)
    end,
    set = function(v) S:SetPath("nameplates.obscuredAlpha", v) end,
    resetValue = function() return 0.4 end }
-- Target Highlight: Arrows (Blizzard's own art) and where, then the switches
local function ArrowChoices()
    local list = { { "off", L["Off"] } }
    local np = NP()
    for _, a in ipairs(np and np.C.ARROW_ORDER or {}) do
        local art = np.C.ARROWS[a]
        -- (each pictured pointing right, as it does on the plate's left side)
        list[#list + 1] = { a, art[3], icon = { art[1], -np.C.ARROW_ANGLE[art[2]] } }
    end
    return list
end
Row{ key = "np.targetArrows", kind = "choice", path = "targetArrows", choices = ArrowChoices, tab = "targeting", section = "np.highlights" }
Row{ key = "np.targetArrowSide", kind = "choice", path = "targetArrowSide", choices = { "both", "left", "right", "top" }, tab = "targeting", section = "np.highlights",
    disabled = function() return TV("targetArrows") == "off" end }
Row{ key = "np.targetBorder", path = "targetBorder", tab = "targeting", section = "np.highlights", half = true }
Row{ key = "np.targetBarColor", path = "targetBarColor", tab = "targeting", section = "np.highlights", half = true }
Row{ key = "np.targetGlow", path = "targetGlow", tab = "targeting", section = "np.highlights", half = true }
Row{ key = "np.colorFocus", path = "colorFocus", tab = "targeting", section = "np.highlights", half = true }

-- EXTRAS: what sits on top of the plate - icons, bar effects, threat and the special colours
-- (moved from Quality of Life while this module is on: the same saved switches, Tweaks.lua)
local function TweaksApply() if ns.Tweaks then ns.Tweaks:Refresh() end Refresh() end
Row{ key = "np.rarityIcon", path = "rarityIcon", tab = "extras", section = "np.marks", half = true }
-- Combo Points and Objective Icon (11-20, per type): the shared Quality of Life switch (Blizzard's plates
-- use it too) and the type's own; ticking one on turns the shared one on as well
local function TypeSwitch(tweakPath, key)
    return function()
        return (S:GetPath(tweakPath) and TV(key) ~= false) and true or false
    end, function(on)
        local np = NP()
        if on then S:SetPath(tweakPath, true) end
        if np then np.TypeSet(PIN.kind, key, on and true or false) end
    end
end
do
    local get, set = TypeSwitch("tweaks.nameplateCombo", "combo")
    Row{ key = "np.comboPoints", tab = "extras", section = "np.marks", half = true, apply = TweaksApply,
        get = get, set = set, resetValue = function() return false end }
end
-- Objective Icon (the saved quest switch, shared with Blizzard's plates) and Objective Progress (never
-- set, it follows the icon: NP.QuestParts)
do
    local get, set = TypeSwitch("tweaks.nameplateQuest", "questIcon")
    Row{ key = "np.questMarks", tab = "extras", section = "np.marks", half = true, apply = TweaksApply,
        get = get, set = set, resetValue = function() return false end }
end
Row{ key = "np.questProgress", tab = "extras", section = "np.marks", half = true, apply = TweaksApply,
    get = function()
        local v = TV("questProgress")
        if v == nil then v = S:GetPath("tweaks.nameplateQuest") and TV("questIcon") ~= false end
        return v and true or false
    end,
    set = function(on) local np = NP() if np then np.TypeSet(PIN.kind, "questProgress", on and true or false) end end,
    resetValue = function() return false end }
Row{ key = "np.threat", kind = "choice", path = "threat", choices = { "off", "groups", "always" }, tab = "extras", section = "np.threatSection" }
Row{ key = "np.role", kind = "choice", path = "role", choices = { "auto", "tank", "damage" }, tab = "extras", section = "np.threatSection",
    apply = function()
        local np = NP()
        if np and np.UpdateRole then np.UpdateRole() end
        Refresh()
    end }
Row{ key = "np.threatGlow", path = "threatGlow", tab = "extras", section = "np.threatSection", half = true }
Row{ key = "np.aggroFlash", path = "aggroFlash", tab = "extras", section = "np.threatSection", half = true }
-- (11-20: Threat Scale paired with Threat Percentage, two columns as the rows above)
Row{ key = "np.threatScale", path = "threatScale", tab = "extras", section = "np.threatSection", half = true }
Row{ key = "np.threatPercent", path = "threatPercent", tab = "extras", section = "np.threatSection", half = true }
-- Special Colours: each a switch (its colour is picked in Pick Your Colours)
local function NoMobTypes()
    return not (TV("colorBoss") or TV("colorElite") or TV("colorCaster") or TV("colorTrivial"))
end
Row{ key = "np.execute", kind = "choice", path = "execute", choices = { "off", "auto", "20", "25", "30", "35" }, tab = "extras", section = "np.specialColors" }
-- Colour Mob Types: the four switches ticked in one dropdown (each its own saved switch), then where
local MOB_TYPES = { { "boss", "colorBoss" }, { "elite", "colorElite" }, { "caster", "colorCaster" }, { "trivial", "colorTrivial" } }
Row{ key = "np.mobTypes", kind = "dropdown", tab = "extras", section = "np.specialColors",
    choices = { "none", { divider = true }, "boss", "elite", "caster", "trivial" },
    toggles = { exclusive = { "none" }, tokens = { "boss", "elite", "caster", "trivial" }, empty = "none" },
    get = function()
        local list = {}
        for _, m in ipairs(MOB_TYPES) do
            if TV(m[2]) then list[#list + 1] = m[1] end
        end
        return #list > 0 and table.concat(list, ",") or "none"
    end,
    set = function(value)
        local on = {}
        for token in tostring(value or ""):gmatch("[^,]+") do on[token] = true end
        local np = NP()
        for _, m in ipairs(MOB_TYPES) do if np then np.TypeSet(PIN.kind, m[2], on[m[1]] and true or false) end end
    end,
    resetValue = function() return "none" end }
Row{ key = "np.mobTypesWhere", kind = "choice", path = "mobTypesWhere", choices = { "instances", "everywhere" }, tab = "extras", section = "np.specialColors",
    disabled = NoMobTypes }
-- Party Colour (the old Group Colour's saved switch) and Raid Colour (never set: follows it)
Row{ key = "np.groupColor", path = "groupColor", tab = "extras", section = "np.specialColors", half = true }
Row{ key = "np.raidColor", tab = "extras", section = "np.specialColors", half = true,
    get = function()
        local v = TV("raidColor")
        if v == nil then v = TV("groupColor") end
        return v and true or false
    end,
    set = function(on) local np = NP() if np then np.TypeSet(PIN.kind, "raidColor", on and true or false) end end,
    resetValue = function() return false end }

-- CAST BAR: the switch alone, then its frame and how it behaves
local function NoCast() return not TV("castbar") end
Row{ key = "np.castbar", path = "castbar", tab = "cast", section = "np.castSection" }
Row{ key = "np.castHeight", kind = "range", path = "castHeight", choices = Steps(6, 18, 1), tab = "cast", section = "np.castFrame", disabled = NoCast }
Row{ key = "np.castIcon", path = "castIcon", tab = "cast", section = "np.castFrame", half = true, disabled = NoCast }
Row{ key = "np.castTimer", path = "castTimer", tab = "cast", section = "np.castFrame", half = true, disabled = NoCast }
Row{ key = "np.castTarget", path = "castTarget", tab = "cast", section = "np.castFrame", disabled = NoCast }
Row{ key = "np.kickReady", path = "kickReady", tab = "cast", section = "np.castBehaviour", half = true, disabled = NoCast }
Row{ key = "np.castKickMark", path = "castKickMark", tab = "cast", section = "np.castBehaviour", half = true, disabled = NoCast }
Row{ key = "np.castTargetedFlash", path = "castTargetedFlash", tab = "cast", section = "np.castBehaviour", half = true, disabled = NoCast }
Row{ key = "np.castImportant", path = "castImportant", tab = "cast", section = "np.castBehaviour", half = true, disabled = NoCast }

-- AURAS
-- Debuffs and Buffs: one dropdown each, Off or All, or filters ticked as toggles (every one
-- ticked must match: Nameplates.lua AuraLanes)
Row{ key = "np.buffs", kind = "dropdown", path = "buffs", tab = "auras", section = "np.buffSection",
    choices = { "off", "all", { divider = true }, "purge", "important", "mine" },
    toggles = { exclusive = { "off", "all" }, tokens = { "purge", "important", "mine" }, empty = "all" } }
-- as the unit frames' Hide Buffs
Row{ key = "np.hideBuffs", kind = "choice", path = "hideBuffs", choices = { "OFF", "PERMANENT", "900", "600", "300", "60" },
    tab = "auras", section = "np.buffSection", disabled = function() return TV("buffs") == "off" end }
Row{ key = "np.buffSize", kind = "range", path = "buffSize", choices = Steps(12, 32, 1), tab = "auras", section = "np.buffSection",
    disabled = function() return TV("buffs") == "off" end }
Row{ key = "np.buffMax", kind = "range", path = "buffMax", choices = Steps(1, 16, 1), tab = "auras", section = "np.buffSection",
    disabled = function() return TV("buffs") == "off" end }
Row{ key = "np.debuffs", kind = "dropdown", path = "debuffs", tab = "auras", section = "np.debuffSection",
    choices = { "off", "all", { divider = true }, "mine", "dispel" },
    toggles = { exclusive = { "off", "all" }, tokens = { "mine", "dispel" }, empty = "all" } }
Row{ key = "np.debuffSize", kind = "range", path = "debuffSize", choices = Steps(12, 32, 1), tab = "auras", section = "np.debuffSection",
    disabled = function() return TV("debuffs") == "off" end }
Row{ key = "np.debuffMax", kind = "range", path = "debuffMax", choices = Steps(1, 16, 1), tab = "auras", section = "np.debuffSection",
    disabled = function() return TV("debuffs") == "off" end }
-- (defensives first: they sit left of the plate, crowd control right)
Row{ key = "np.defensives", path = "defensives", tab = "auras", section = "np.ccSection", half = true }
Row{ key = "np.cc", path = "cc", tab = "auras", section = "np.ccSection", half = true }
Row{ key = "np.ccSize", kind = "range", path = "ccSize", choices = Steps(16, 40, 2), tab = "auras", section = "np.ccSection",
    disabled = function() return not (TV("cc") or TV("defensives")) end }

-- VISIBILITY: Blizzard's own nameplate and name settings (the game saves them; not in a fight), in
-- three sections: which plates show and when, how they behave, and the names over heads
local function Locked() return InCombatLockdown() end
local function SetGameCVar(cvar, on)
    if NP() and NP().SetCVar then NP().SetCVar(cvar, on) elseif not InCombatLockdown() then SetCVar(cvar, on and "1" or "0") end
end
local function TweaksRefresh() if ns.Tweaks then ns.Tweaks:Refresh() end end
-- Show Enemy Plates / Show Friendly Plates: Off, Always, or Only in Combat. One choice over the
-- game's master switch and FlareUI's combat-only switch (Tweaks.lua holds the master off out of
-- combat, and keeps the player's own value to put back)
local function ShowRow(key, cvar, tweakKey)
    Row{ key = key, kind = "choice", choices = { "off", "always", "combat" }, tab = "visibility", section = "np.which",
        get = function()
            if S:GetPath("tweaks." .. tweakKey) then return "combat" end
            return GetCVarBool(cvar) and "always" or "off"
        end,
        set = function(v)
            if InCombatLockdown() then return end
            S:SetPath("tweaks." .. tweakKey, v == "combat")
            TweaksRefresh()   -- (turning combat-only off puts the player's own value back first)
            if v ~= "combat" then SetGameCVar(cvar, v == "always") end
        end,
        resetValue = function() return "always" end,
        disabled = Locked, apply = function() end }
end
-- a toggle dropdown over several of the game's switches (None first)
local function SwitchesRow(key, section, list, setCVar)
    local tokens, choices = {}, { "none", { divider = true } }
    for _, e in ipairs(list) do tokens[#tokens + 1] = e[1]; choices[#choices + 1] = e[1] end
    Row{ key = key, kind = "dropdown", tab = "visibility", section = section, choices = choices,
        toggles = { exclusive = { "none" }, tokens = tokens, empty = "none" },
        get = function()
            local on = {}
            for _, e in ipairs(list) do if GetCVarBool(e[2]) then on[#on + 1] = e[1] end end
            return #on > 0 and table.concat(on, ",") or "none"
        end,
        set = function(value)
            if InCombatLockdown() then return end
            local on = {}
            for token in tostring(value or ""):gmatch("[^,]+") do on[token] = true end
            for _, e in ipairs(list) do
                if GetCVarBool(e[2]) ~= (on[e[1]] or false) then setCVar(e[2], on[e[1]] and true or false) end
            end
        end,
        disabled = Locked, apply = function() end }
end
-- PLATES
ShowRow("np.enemyShow", "nameplateShowEnemies", "combatPlates")
-- Enemy Types (11-20): Players and NPCs too. The game has no switch for those two: they are FlareUI's
-- (nameplates.enemyPlayers / enemyNpcs, Nameplates.lua NP.UnitHidden); Minions and Minor are the game's
do
    local GAME = { minions = "nameplateShowEnemyMinions", minor = "nameplateShowEnemyMinus" }
    local OWN = { players = "nameplates.enemyPlayers", npcs = "nameplates.enemyNpcs" }
    local ORDER = { "players", "npcs", "minions", "minor" }
    local function On(token)
        if OWN[token] then return S:GetPath(OWN[token]) ~= false end
        return GetCVarBool(GAME[token])
    end
    Row{ key = "np.enemyTypes", kind = "dropdown", tab = "visibility", section = "np.which",
        choices = { "none", { divider = true }, "players", "npcs", "minions", "minor" },
        toggles = { exclusive = { "none" }, tokens = ORDER, empty = "none" },
        get = function()
            local on = {}
            for _, t in ipairs(ORDER) do if On(t) then on[#on + 1] = t end end
            return #on > 0 and table.concat(on, ",") or "none"
        end,
        set = function(value)
            if InCombatLockdown() then return end
            local want = {}
            for token in tostring(value or ""):gmatch("[^,]+") do want[token] = true end
            for _, t in ipairs(ORDER) do
                local v = want[t] or false
                if OWN[t] then S:SetPath(OWN[t], v)
                elseif GetCVarBool(GAME[t]) ~= v then SetGameCVar(GAME[t], v) end
            end
        end,
        resetValue = function() return "players,npcs" end,
        disabled = Locked, apply = Refresh }
end
ShowRow("np.friendlyShow", "nameplateShowFriends", "combatFriendly")
SwitchesRow("np.friendlyTypes", "np.which", { { "players", "nameplateShowFriendlyPlayers" }, { "npcs", "nameplateShowFriendlyNpcs" },
    { "minions", "nameplateShowFriendlyPlayerMinions" } }, SetGameCVar)
Row{ key = "np.showAll", tab = "visibility", section = "np.which",
    get = function() return GetCVarBool("nameplateShowAll") end,
    set = function(on) SetGameCVar("nameplateShowAll", on) end,
    disabled = Locked, apply = function() end }

-- BEHAVIOUR: Stacking, then the switches in pairs
local STACK = { enemy = 1, friendly = 2 }
local function StackOn(index)
    local ok, on = pcall(C_CVar.GetCVarBitfield, "nameplateStackingTypes", index)
    return ok and on and true or false
end
Row{ key = "np.stacking", kind = "dropdown", tab = "visibility", section = "np.platesBehaviour",
    choices = { "none", { divider = true }, "enemy", "friendly" },
    toggles = { exclusive = { "none" }, tokens = { "enemy", "friendly" }, empty = "none" },
    get = function()
        local list = {}
        if StackOn(STACK.enemy) then list[#list + 1] = "enemy" end
        if StackOn(STACK.friendly) then list[#list + 1] = "friendly" end
        return #list > 0 and table.concat(list, ",") or "none"
    end,
    set = function(value)
        if InCombatLockdown() then return end
        local on = {}
        for token in tostring(value or ""):gmatch("[^,]+") do on[token] = true end
        local mask = (on.enemy and 1 or 0) + (on.friendly and 2 or 0)
        pcall(CVarCallbackRegistry.SetCVarBitfieldMask, CVarCallbackRegistry, "nameplateStackingTypes", mask)
    end,
    disabled = Locked, apply = function() end }
-- Keep Target on Screen (on): your target's plate stays at the screen's edge when the unit is off it
Row{ key = "np.clampTarget", path = "clampTarget", tab = "visibility", section = "np.platesBehaviour", half = true,
    disabled = function() local np = NP() return not (np and np.ClampCVar and np.ClampCVar()) end }
Row{ key = "np.showOffscreen", tab = "visibility", section = "np.platesBehaviour", half = true,
    get = function() return GetCVarBool("nameplateShowOffscreen") end,
    set = function(on) SetGameCVar("nameplateShowOffscreen", on) end,
    disabled = Locked, apply = function() end }
Row{ key = "np.clickThrough", path = "clickThrough", tab = "visibility", section = "np.platesBehaviour", half = true }
-- (11-20: Realm Names removed, Forever has no realms) Name Only While Unattackable, off (Nameplates.lua NP.Peaceful)
Row{ key = "np.peacefulNames", path = "peacefulNames", tab = "visibility", section = "np.platesBehaviour", half = true }

-- WORLD NAMES: the names over units' heads (Blizzard's own switches)
local function SetNameCVar(cvar, on) if not InCombatLockdown() then SetCVar(cvar, on and "1" or "0") end end
-- NPC Names, as Blizzard's own dropdown (the same five settings)
local NPC_NAMES = {
    tracked = { UnitNameFriendlySpecialNPCName = "1", UnitNameNPC = "0", UnitNameHostleNPC = "0", UnitNameInteractiveNPC = "0", ShowQuestUnitCircles = "0" },
    hostile = { UnitNameFriendlySpecialNPCName = "1", UnitNameHostleNPC = "1", UnitNameInteractiveNPC = "0", UnitNameNPC = "0", ShowQuestUnitCircles = "1" },
    interactive = { UnitNameFriendlySpecialNPCName = "1", UnitNameHostleNPC = "1", UnitNameInteractiveNPC = "1", UnitNameNPC = "0", ShowQuestUnitCircles = "1" },
    all = { UnitNameFriendlySpecialNPCName = "0", UnitNameHostleNPC = "0", UnitNameInteractiveNPC = "0", UnitNameNPC = "1", ShowQuestUnitCircles = "1" },
    none = { UnitNameFriendlySpecialNPCName = "0", UnitNameHostleNPC = "0", UnitNameInteractiveNPC = "0", UnitNameNPC = "0", ShowQuestUnitCircles = "1" },
}
Row{ key = "np.npcNames", kind = "choice", tab = "visibility", section = "np.worldNames",
    choices = { "none", "tracked", "hostile", "interactive", "all" },
    get = function()
        if GetCVarBool("UnitNameNPC") then return "all" end
        local special, hostile = GetCVarBool("UnitNameFriendlySpecialNPCName"), GetCVarBool("UnitNameHostleNPC")
        if special and hostile and GetCVarBool("UnitNameInteractiveNPC") then return "interactive" end
        if special and hostile then return "hostile" end
        if special then return "tracked" end
        return "none"
    end,
    set = function(value)
        if InCombatLockdown() then return end
        for cvar, v in pairs(NPC_NAMES[value] or NPC_NAMES.none) do pcall(SetCVar, cvar, v) end
    end,
    disabled = Locked, apply = function() end }
SwitchesRow("np.playerNames", "np.worldNames", { { "own", "UnitNameOwn" }, { "friendly", "UnitNameFriendlyPlayerName" },
    { "enemy", "UnitNameEnemyPlayerName" } }, SetNameCVar)
SwitchesRow("np.minionNames", "np.worldNames", { { "friendly", "UnitNameFriendlyMinionName" }, { "enemy", "UnitNameEnemyMinionName" },
    { "critters", "UnitNameNonCombatCreatureName" } }, SetNameCVar)

-- FONTS
S:FontRows{ module = "np", tab = "fonts", section = "np.fonts", apply = Refresh, fonts = {
    { key = "name", path = "nameplates.nameFont" },
    { key = "health", path = "nameplates.healthFont" },
    { key = "level", path = "nameplates.levelFont" },
    { key = "cast", path = "nameplates.castFont" },
} }
-- (11-20: the Blizzard's Names section, a link to the General page, removed)
