local _, ns = ...
local L = ns.L

--------------------------------------------------
-- ADDON BUTTON BAG (part of the Minimap module, started from MM:Init)
-- The day/night badge opens a panel with every addon's shortcut:
--   * LibDBIcon buttons, redrawn from their LibDataBroker objects; the originals are parked and
--     LibDBIcon's settings are never written
--   * other addons' minimap buttons, moved into the bag as they are
--   * Blizzard's addon compartment entries, called as Blizzard's menu calls them
-- An addon in two lists shows once. Closes on the badge, Escape, a click elsewhere, or after use.
--------------------------------------------------
local Bag = {}
ns.MinimapBag = Bag

local LSM = LibStub("LibSharedMedia-3.0")
local ipairs, pairs, type, wipe = ipairs, pairs, type, wipe

local C = {
    BUTTON = 28,              -- one icon
    SPACING = 4,
    COLUMNS = 5,
    PAD = 9,                  -- inside the panel's border
    GAP = 6,                  -- between the badge and the panel
    BORDER = "FlareUI Frames",
    OPACITY = 0.9,
    -- names of minimap children that are Blizzard's (or ours) and never go in the bag
    SKIP = { "^Minimap", "^MiniMap", "^GameTime", "^TimeManager", "^QueueStatus", "^Expansion",
             "^GarrisonLandingPage", "^AddonCompartment", "^FlareUI", "^HybridMinimap", "^LibDBIcon10_" },
}

local panel, badgeButton
local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()
local entries = {}            -- what the bag shows, rebuilt on every open
local buttons = {}            -- the bag's own icon buttons (pool)
local adopted = {}            -- other addons' minimap buttons moved into the bag: frame -> true
local parked = {}             -- LibDBIcon buttons parked out of sight: frame -> their old parent

local function GetDb()
    return ns.db and ns.db.profile and ns.db.profile.minimap
end

function Bag:IsOn()
    local db = GetDb()
    return db and db.buttonBag ~= false or false
end

local function StripText(text)
    if type(text) ~= "string" then return "" end
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""))
end

--------------------------------------------------
-- SOURCES
--------------------------------------------------
local function LibDBIcon() return LibStub and LibStub("LibDBIcon-1.0", true) end
local function LibDataBroker() return LibStub and LibStub("LibDataBroker-1.1", true) end

-- A LibDBIcon button off the minimap, without touching LibDBIcon's settings
local function ParkIcon(frame)
    if not frame or parked[frame] then return end
    parked[frame] = frame:GetParent() or Minimap
    frame:SetParent(hiddenParent)
end

local function ParkAllIcons()
    local lib = LibDBIcon()
    if not lib then return end
    for _, name in ipairs(lib:GetButtonList() or {}) do ParkIcon(lib:GetMinimapButton(name)) end
end

-- Children of the minimap that look like an addon's button: a named, unprotected, small Button that
-- is not Blizzard's, LibDBIcon's or FlareUI's
local function IsForeignButton(frame)
    if not (frame and frame.IsObjectType and frame:IsObjectType("Button")) then return false end
    if frame:IsForbidden() or frame:IsProtected() then return false end
    local name = frame:GetName()
    if not name then return false end
    for _, pattern in ipairs(C.SKIP) do
        if name:find(pattern) then return false end
    end
    local w, h = frame:GetSize()
    return (w or 0) > 8 and (w or 0) <= 48 and (h or 0) > 8 and (h or 0) <= 48
end

local function CollectEntries()
    wipe(entries)
    local seen = {}

    -- LibDBIcon buttons, from their data objects
    local lib, ldb = LibDBIcon(), LibDataBroker()
    if lib and ldb then
        for _, name in ipairs(lib:GetButtonList() or {}) do
            local object = ldb:GetDataObjectByName(name)
            local frame = lib:GetMinimapButton(name)
            if object and frame then
                ParkIcon(frame)
                local label = StripText(object.label or object.text or name)
                entries[#entries + 1] = { kind = "ldb", name = name, label = label ~= "" and label or name,
                                          object = object, frame = frame }
                seen[name:lower()] = true
                seen[label:lower()] = true
            end
        end
    end

    -- other addons' buttons on the minimap
    for frame in pairs(adopted) do
        entries[#entries + 1] = { kind = "frame", name = frame:GetName(), label = frame:GetName(), frame = frame }
    end
    for _, parent in ipairs({ Minimap, MinimapCluster }) do
        for _, child in ipairs({ parent:GetChildren() }) do
            if not adopted[child] and IsForeignButton(child) then
                adopted[child] = true
                entries[#entries + 1] = { kind = "frame", name = child:GetName(), label = child:GetName(), frame = child }
            end
        end
    end

    -- Blizzard's addon compartment
    local compartment = AddonCompartmentFrame
    for _, data in ipairs(compartment and compartment.registeredAddons or {}) do
        local label = StripText(data.text)
        if label ~= "" and not seen[label:lower()] then
            seen[label:lower()] = true
            entries[#entries + 1] = { kind = "compartment", name = label, label = label, data = data }
        end
    end

    table.sort(entries, function(a, b) return a.label:lower() < b.label:lower() end)
end

--------------------------------------------------
-- THE PANEL
--------------------------------------------------
function Bag:Close()
    if panel then panel:Hide() end
end

local function AnchorTooltip(owner)
    ns.OwnGameTooltip(owner, "ANCHOR_NONE")
    local x = owner:GetCenter()
    if x and x > UIParent:GetWidth() / 2 then
        GameTooltip:SetPoint("TOPRIGHT", owner, "BOTTOMLEFT", 0, -2)
    else
        GameTooltip:SetPoint("TOPLEFT", owner, "BOTTOMRIGHT", 0, 2)
    end
end

local function OnIconEnter(self)
    local e = self.entry
    if not e then return end
    if e.kind == "ldb" then
        local object = e.object
        if object.OnTooltipShow then
            AnchorTooltip(self)
            object.OnTooltipShow(GameTooltip)
            GameTooltip:Show()
        elseif object.OnEnter then
            object.OnEnter(self)
        else
            AnchorTooltip(self)
            GameTooltip:AddLine(e.label)
            GameTooltip:Show()
        end
    elseif e.kind == "compartment" then
        if e.data.funcOnEnter then
            e.data.funcOnEnter(self)
        else
            AnchorTooltip(self)
            GameTooltip:AddLine(e.label)
            GameTooltip:Show()
        end
    end
end

local function OnIconLeave(self)
    local e = self.entry
    if e and e.kind == "ldb" and e.object.OnLeave then e.object.OnLeave(self)
    elseif e and e.kind == "compartment" and e.data.funcOnLeave then e.data.funcOnLeave(self) end
    GameTooltip:Hide()
end

local function OnIconClick(self, mouseButton)
    local e = self.entry
    if not e then return end
    GameTooltip:Hide()
    Bag:Close()
    if e.kind == "ldb" then
        if e.object.OnClick then e.object.OnClick(self, mouseButton) end
    elseif e.kind == "compartment" then
        if e.data.func then e.data.func(e.data, { buttonName = mouseButton }, nil) end
    end
end

-- The bag's own button for a LibDBIcon or compartment entry, in Blizzard's small action button look
-- (as the Quest Tracker's item buttons)
local function GetIconButton(i)
    local b = buttons[i]
    if b then return b end
    b = CreateFrame("Button", nil, panel)
    b:SetSize(C.BUTTON, C.BUTTON)
    b:RegisterForClicks("AnyUp")
    b.icon = b:CreateTexture(nil, "BACKGROUND")
    b.icon:SetAllPoints()
    local mask = b:CreateMaskTexture()
    mask:SetAtlas("UI-HUD-ActionBar-IconFrame-Mask")
    mask:SetPoint("CENTER", b.icon, "CENTER")
    mask:SetSize(C.BUTTON * 1.5, C.BUTTON * 1.5)
    b.icon:AddMaskTexture(mask)
    local art = C.BUTTON / 30
    b:SetNormalAtlas("UI-HUD-ActionBar-IconFrame")
    b:SetPushedAtlas("UI-HUD-ActionBar-IconFrame-Down")
    b:SetHighlightAtlas("UI-HUD-ActionBar-IconFrame-Mouseover")
    for _, t in ipairs({ b:GetNormalTexture(), b:GetPushedTexture(), b:GetHighlightTexture() }) do
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT")
        t:SetSize(31.6 * art, 30.9 * art)
    end
    b:SetScript("OnEnter", OnIconEnter)
    b:SetScript("OnLeave", OnIconLeave)
    b:SetScript("OnClick", OnIconClick)
    buttons[i] = b
    return b
end

local function SetIcon(texture, icon, object)
    texture:SetTexCoord(0, 1, 0, 1)
    texture:SetVertexColor(1, 1, 1)
    if type(icon) == "string" and C_Texture.GetAtlasInfo(icon) then
        texture:SetAtlas(icon)
    else
        texture:SetTexture(icon or 134400)
        local coords = object and object.iconCoords
        if type(coords) == "table" then texture:SetTexCoord(unpack(coords)) end
    end
    if object and object.iconR then texture:SetVertexColor(object.iconR, object.iconG or 1, object.iconB or 1) end
end

-- The panel opens beside the badge, towards the middle of the screen
local function AnchorPanel()
    local badge = MinimapCluster and MinimapCluster.DielFrame
    if not badge then return end
    local x, y = badge:GetCenter()
    local right = x and x > UIParent:GetWidth() / 2
    local top = y and y > UIParent:GetHeight() / 2
    panel:ClearAllPoints()
    local v = top and "TOP" or "BOTTOM"
    if right then
        panel:SetPoint(v .. "RIGHT", badge, v .. "LEFT", -C.GAP, 0)
    else
        panel:SetPoint(v .. "LEFT", badge, v .. "RIGHT", C.GAP, 0)
    end
end

function Bag:Layout()
    CollectEntries()
    local count = #entries
    local columns = math.max(1, math.min(C.COLUMNS, count))
    local rows = math.max(1, math.ceil(count / columns))
    local step = C.BUTTON + C.SPACING
    panel:SetSize(C.PAD * 2 + columns * step - C.SPACING, C.PAD * 2 + rows * step - C.SPACING)
    panel.empty:SetShown(count == 0)
    if count == 0 then panel:SetSize(170, 40) end

    local used = 0
    for i, e in ipairs(entries) do
        local col, row = (i - 1) % columns, math.floor((i - 1) / columns)
        local x, y = C.PAD + col * step, -(C.PAD + row * step)
        local frame
        if e.kind == "frame" then
            -- the addon's own button, moved into the cell (its own look and scripts)
            frame = e.frame
            frame:SetParent(panel)
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", panel, "TOPLEFT", x + C.BUTTON / 2, y - C.BUTTON / 2)
            frame:Show()
        else
            used = used + 1
            frame = GetIconButton(used)
            frame.entry = e
            SetIcon(frame.icon, e.kind == "ldb" and e.object.icon or e.data.icon, e.kind == "ldb" and e.object or nil)
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
            frame:Show()
        end
    end
    for i = used + 1, #buttons do buttons[i]:Hide(); buttons[i].entry = nil end
    AnchorPanel()
end

function Bag:Toggle()
    if not panel then return end
    if panel:IsShown() then
        panel:Hide()
    else
        self:Layout()
        panel:Show()
    end
end

local function CreatePanel()
    panel = CreateFrame("Frame", "FlareUI_MinimapBag", UIParent, "BackdropTemplate")
    panel:SetFrameStrata("HIGH")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:Hide()
    local bg = LSM:Fetch("background", "Blizzard Dialog Background Dark") or "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"
    local edge = LSM:IsValid("border", C.BORDER) and LSM:Fetch("border", C.BORDER) or nil
    panel:SetBackdrop({ bgFile = bg, edgeFile = edge, tile = false, tileSize = 0,
        edgeSize = ns.BorderEdgeSize(edge, 16), insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    panel:SetBackdropColor(1, 1, 1, C.OPACITY)
    local b = ns.BORDER_COLOR
    panel:SetBackdropBorderColor(b.r, b.g, b.b, b.a)

    panel.empty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.empty:SetPoint("CENTER")
    panel.empty:SetText(L["No addon buttons"])

    -- closes on Escape, and on a click anywhere that is not the bag or the badge
    tinsert(UISpecialFrames, "FlareUI_MinimapBag")
    panel:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
    panel:SetScript("OnHide", function(self) self:UnregisterEvent("GLOBAL_MOUSE_DOWN") end)
    panel:SetScript("OnEvent", function(self)
        if self:IsMouseOver() or (badgeButton and badgeButton:IsMouseOver()) then return end
        self:Hide()
    end)
end

-- The click area over the badge (Blizzard's badge takes no mouse)
local function CreateBadgeButton()
    local badge = MinimapCluster and MinimapCluster.DielFrame
    if not badge then return end
    badgeButton = CreateFrame("Button", nil, badge)
    badgeButton:SetAllPoints(badge)
    badgeButton:SetFrameLevel(badge:GetFrameLevel() + 2)
    badgeButton:RegisterForClicks("LeftButtonUp")
    badgeButton:SetScript("OnClick", function() Bag:Toggle() end)
end

-- A button another addon moves back onto the minimap goes straight back into the bag
local function KeepAdoptedInBag()
    for frame in pairs(adopted) do
        if not frame.FlareUI_BagHooked then
            frame.FlareUI_BagHooked = true
            hooksecurefunc(frame, "SetParent", function(self, parent)
                if parent ~= panel and adopted[self] and Bag:IsOn() then self:SetParent(panel) end
            end)
        end
        if not (panel and panel:IsShown()) and frame:GetParent() ~= panel then frame:SetParent(panel) end
    end
end

function Bag:Init()
    if self.initialized or not self:IsOn() then return end
    if not (MinimapCluster and MinimapCluster.DielFrame) then return end
    self.initialized = true
    CreatePanel()
    CreateBadgeButton()
    -- LibDBIcon buttons are parked at once and as they are made; other addons' buttons have no
    -- signal, so they are swept for a few times while addons finish loading
    local lib = LibDBIcon()
    if lib and lib.RegisterCallback then
        lib.RegisterCallback(Bag, "LibDBIcon_IconCreated", function(_, button) ParkIcon(button) end)
    end
    local function Sweep()
        ParkAllIcons()
        CollectEntries()
        KeepAdoptedInBag()
    end
    Sweep()
    for _, delay in ipairs({ 0, 0.5, 1.5, 4 }) do C_Timer.After(delay, Sweep) end
end
