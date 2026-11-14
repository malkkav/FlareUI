local _, ns = ...
local L = ns.L

--------------------------------------------------
-- ADDON BUTTON BAG (part of the Minimap module, started from MM:Init)
-- The day/night badge opens a panel with LibDBIcon buttons (redrawn, originals parked), other addons'
-- minimap buttons (moved in) and addon compartment entries, each addon once, in a draggable order.
--------------------------------------------------

--------------------------------------------------
-- 1. MODULE AND CONSTANTS
--------------------------------------------------
local Bag = {}
ns.MinimapBag = Bag

local LSM = LibStub("LibSharedMedia-3.0")
local ipairs, pairs, type, wipe = ipairs, pairs, type, wipe

local C = {
    BUTTON = 24,              -- one icon
    SPACING = 4,
    COLUMNS = 6,
    PIN_LIBS = { "HereBeDragons-Pins-2.0", "HereBeDragons-Pins-1.0" },   -- (one table, not one per check)
    PAD = 9,                  -- inside the panel's border
    GAP = 6,                  -- between the badge and the panel
    BORDER = "FlareUI Frames",
    OPACITY = 0.9,
    -- minimap children that are Blizzard's or FlareUI's
    SKIP = { "^Minimap", "^MiniMap", "^GameTime", "^TimeManager", "^QueueStatus", "^Expansion",
             "^GarrisonLandingPage", "^AddonCompartment", "^FlareUI", "^HybridMinimap", "^ExternalEventURL" },
    -- map pins other addons draw on the minimap: small named buttons, but never shortcuts
    PINS = { "^Questie", "^HandyNotes", "^GatherMate", "^GatherNote", "^TomTom", "^Archy", "^ZGV",
             "^DugisArrow", "^poiMinimap", "^Spy_Map", "^RareTracker", "^Routes", "^WestPointer",
             "^MapNote", "^Carbonite", "^NxMinimap", "Pin%d*$", "^HereBeDragons" },
    MAX_FOREIGN = 40,         -- more than this many "buttons" means something is drawing pins
    BUTTON_BORDER_FILE = 136430,   -- Interface\Minimap\MiniMap-TrackingBorder
}

local panel, badgeButton
local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()
local entries = {}            -- rebuilt on every open
local buttons = {}            -- the bag's own icon buttons (pool)
local adopted = {}            -- other addons' buttons moved into the bag: frame -> true
local parked = {}             -- parked LibDBIcon buttons: frame -> true
local cells = {}              -- index -> frame shown in that cell
local catchers = {}           -- drag handles over the cells (pool)
local drag                    -- { from = index, frame = frame }

local function GetDb()
    return ns.db and ns.db.profile and ns.db.profile.minimap
end

function Bag:IsOn()
    local db = GetDb()
    return db and db.buttonBag ~= false or false
end

-- Open on Mouseover (minimap.bagHover, off): pointing at the badge opens the drawer, and it closes a
-- moment after the pointer leaves both, as EnhanceQoL's button sink does
local function HoverOn()
    local db = GetDb()
    return db and db.bagHover == true or false
end

local function StripText(text)
    if type(text) ~= "string" then return "" end
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""))
end

--------------------------------------------------
-- 2. SOURCES
--------------------------------------------------
local function LibDBIcon() return LibStub and LibStub("LibDBIcon-1.0", true) end
local function LibDataBroker() return LibStub and LibStub("LibDataBroker-1.1", true) end

-- Addons in the Drawer (11-13, Marcus: replaces Shift+Right-Click "Keep on the Minimap", which clashed
-- with addons' own right-click menus): a list on the Minimap page. An addon unticked there
-- (minimap.bagLeave[id], id "ldb:<name>" / "frame:<name>" / "compartment:<title>") is left alone: its
-- button isn't parked, moved or redrawn, and it has no icon in the drawer. Ticked is the default, so a
-- new addon goes in. The old bagKeep choices become left-alone ones, once.
local known = {}   -- id -> label, every addon the drawer has seen (for the settings list)

-- OneForAll's "Collect minimap buttons" (OneForAllDB.qol.mmCollect) gathers the same buttons, but only
-- from the minimap: while it is on, the addon buttons stay there for it (6.4.1, a player: its bar
-- was empty). The drawer keeps the addon compartment entries. Read as the drawer builds: a change
-- in OneForAll applies at the next reload.
function Bag.OtherCollector()
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("OneForAll")
    local qol = type(_G.OneForAllDB) == "table" and type(_G.OneForAllDB.qol) == "table" and _G.OneForAllDB.qol
    return (loaded and qol and qol.mmCollect == true) and true or false
end

local function Left(id)
    if Bag.OtherCollector() and type(id) == "string" and (id:find("^ldb:") or id:find("^frame:")) then return true end
    local db = GetDb()
    if not db then return false end
    if type(db.bagKeep) == "table" then
        db.bagLeave = type(db.bagLeave) == "table" and db.bagLeave or {}
        for keptId in pairs(db.bagKeep) do db.bagLeave[keptId] = true end
        db.bagKeep = nil
    end
    return type(db.bagLeave) == "table" and db.bagLeave[id] or false
end
local function Kept(name) return Left("ldb:" .. name) end
-- the drawer takes this LibDBIcon button (Minimap.lua leaves its place alone)
function Bag.Holds(name) return Bag:IsOn() and not Kept(name) end

-- A LibDBIcon button off the minimap, without touching LibDBIcon's settings
local function ParkIcon(frame, name)
    if not frame or parked[frame] or (name and Kept(name)) then return end
    parked[frame] = true
    frame:SetParent(hiddenParent)
end

local function ParkAllIcons()
    local lib = LibDBIcon()
    if not lib then return end
    for _, name in ipairs(lib:GetButtonList() or {}) do ParkIcon(lib:GetMinimapButton(name), name) end
end

-- A button LibDBIcon really made; look-alike names without the library count as foreign buttons
local function IsLibDBIconButton(frame, name)
    local lib = LibDBIcon()
    local id = name:match("^LibDBIcon10_(.+)$")
    return id ~= nil and lib ~= nil and lib:GetMinimapButton(id) == frame
end

-- A minimap pin registered with HereBeDragons
local function IsMapPin(frame)
    for _, major in ipairs(C.PIN_LIBS) do
        local pins = LibStub and LibStub(major, true)
        if pins and ((pins.minimapPins and pins.minimapPins[frame]) or (pins.activeMinimapPins and pins.activeMinimapPins[frame])) then
            return true
        end
    end
    return false
end

-- Wears Blizzard's round minimap button border, the one thing that tells a button with no name from a pin
local function HasButtonBorder(frame)
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("Texture") then
            local ok, id = pcall(region.GetTextureFileID, region)
            if ok and id == C.BUTTON_BORDER_FILE then return true end
        end
    end
    return false
end

-- An addon's minimap button: named or wearing the button border, unprotected, small, clickable, and not
-- Blizzard's, LibDBIcon's, FlareUI's or a map pin
local function IsForeignButton(frame)
    if not (frame and frame.IsObjectType and frame:IsObjectType("Button")) then return false end
    -- (11-13 performance pass) pins first: the cheapest test, and gathering addons add thousands
    if frame:IsForbidden() or frame:IsProtected() or IsMapPin(frame) then return false end
    local name = frame:GetName()
    if name then
        if IsLibDBIconButton(frame, name) then return false end
        -- some icon libraries name their buttons "MinimapButton_<lib>_LibDBIcon_<addon>": an addon's, not Blizzard's
        local addonIcon = name:find("^MinimapButton_") and name:find("LibDBIcon", 1, true)
        for _, pattern in ipairs(C.SKIP) do
            if not addonIcon and name:find(pattern) then return false end
        end
        for _, pattern in ipairs(C.PINS) do
            if name:find(pattern) then return false end
        end
    elseif not HasButtonBorder(frame) then
        return false
    end
    if not (frame:GetScript("OnClick") or frame:GetScript("OnMouseUp")) then return false end
    local w, h = frame:GetSize()
    return (w or 0) > 8 and (w or 0) <= 48 and (h or 0) > 8 and (h or 0) <= 48
end

-- The addon folder that made a button with no name, from where the client says it was created
local function SourceAddon(frame)
    local location = frame.GetSourceLocation and frame:GetSourceLocation()
    return type(location) == "string" and location:match("AddOns[\\/]([^\\/]+)") or nil
end

-- Compartment titles ("Lorever") are matched to button names ("LoreverMinimapButton") loosely:
-- lower case, letters and digits only, the usual button words dropped
local NAME_NOISE = { "libdbicon10", "minimapbutton", "minimap", "button", "btn", "icon", "ldb", "broker" }
local function NameKey(text)
    local key = StripText(text):lower():gsub("[^%w]", "")
    for _, word in ipairs(NAME_NOISE) do key = key:gsub(word, "") end
    return key
end

-- An adopted button's id in the saved order: its frame name, else the addon that made it
local function FrameId(frame)
    return frame:GetName() or SourceAddon(frame) or L["Addon button"]
end

-- An adopted button's label: its data object's text, else its frame name or its addon's title
local function FrameLabel(frame)
    local object = type(frame.dataObject) == "table" and frame.dataObject or nil
    local label = object and StripText(object.label or object.text) or ""
    if label ~= "" then return label end
    local name = frame:GetName()
    local addon = SourceAddon(frame)
    if name then
        name = name:gsub("^LibDBIcon10_", "")
        -- (11-13) its addon's title when it names the same addon: "Social Diary", not "SocialDiaryMinimapButton"
        local title = addon and StripText(C_AddOns.GetAddOnTitle(addon) or "") or ""
        if title ~= "" and NameKey(title) ~= "" and NameKey(title) == NameKey(name) then return title end
        return name
    end
    local title = addon and StripText(C_AddOns.GetAddOnTitle(addon)) or ""
    return title ~= "" and title or FrameId(frame)
end

-- "Graphics Enhanced Forever" -> "gef", for buttons named by the initials
local function Initials(text)
    local letters = {}
    for word in StripText(text):gmatch("%a+") do letters[#letters + 1] = word:sub(1, 1):lower() end
    return table.concat(letters)
end

local function SameName(title, other)
    local a, b = NameKey(title), NameKey(other)
    if a == "" or b == "" then return false end
    if a == b then return true end
    if #a >= 4 and #b >= 4 and (a:find(b, 1, true) or b:find(a, 1, true)) then return true end
    local initials = Initials(title)
    return #initials >= 2 and b == initials
end

-- The textures a minimap button shows: file IDs and atlases
local function FrameArt(frame)
    local art = {}
    local function add(region)
        if not (region and region.IsObjectType and region:IsObjectType("Texture")) then return end
        local ok, id = pcall(region.GetTextureFileID, region)
        if ok and type(id) == "number" and id > 0 then art[id] = true end
        local atlas = region.GetAtlas and region:GetAtlas()
        if type(atlas) == "string" and atlas ~= "" then art[atlas:lower()] = true end
    end
    for _, region in ipairs({ frame:GetRegions() }) do add(region) end
    add(frame.icon or frame.Icon)
    return art
end

local function SameIcon(icon, art)
    if type(icon) == "number" then return art[icon] or false end
    if type(icon) ~= "string" or icon == "" then return false end
    if art[icon:lower()] then return true end
    local ok, id = pcall(GetFileIDFromPath, icon)
    return ok and type(id) == "number" and id > 0 and art[id] or false
end

-- A compartment entry for an addon already in the bag as a button (by name or icon)
local function AlreadyListed(data, label)
    for _, e in ipairs(entries) do
        if e.kind ~= "compartment" and (SameName(label, e.label) or SameName(label, e.name)) then return true end
        if e.kind == "frame" then
            e.art = e.art or FrameArt(e.frame)
            if SameIcon(data.icon, e.art) then return true end
        elseif e.kind == "ldb" and data.icon ~= nil and data.icon == e.object.icon then
            return true
        end
    end
    return false
end

local function CollectEntries()
    wipe(entries)
    local seen = {}

    local lib, ldb = LibDBIcon(), LibDataBroker()
    if lib and ldb then
        for _, name in ipairs(lib:GetButtonList() or {}) do
            local frame = lib:GetMinimapButton(name)
            -- (11-13, the research: an addon can register its button under another name than its data
            -- object, RareScanner's "RareScannerMinimapIcon" for "RareScannerLDB": the button carries it)
            local object = ldb:GetDataObjectByName(name) or (frame and type(frame.dataObject) == "table" and frame.dataObject)
            if object and frame then
                local label = StripText(object.label or object.text or name)
                label = label ~= "" and label or name
                known["ldb:" .. name] = label
                -- one unticked by the name of its compartment entry (the list had both) is left alone too
                if Left("compartment:" .. label) and not Kept(name) then
                    local db = GetDb()
                    if db then db.bagLeave["ldb:" .. name] = true end
                end
                -- left alone but parked earlier this session: back on the minimap where LibDBIcon keeps it
                -- (its points cleared first: LibDBIcon's placing never clears them)
                if Kept(name) and parked[frame] then
                    parked[frame] = nil
                    frame:SetParent(Minimap)
                    frame:ClearAllPoints()
                    if lib.Refresh then pcall(lib.Refresh, lib, name) end
                    if ns.Minimap and ns.Minimap.PullButtonsIn then ns.Minimap.PullButtonsIn() end
                end
                -- (left alone: still "seen", so its compartment entry doesn't slip into the drawer)
                if not Kept(name) then
                    ParkIcon(frame, name)
                    entries[#entries + 1] = { kind = "ldb", name = name, label = label, object = object, frame = frame }
                end
                seen[name:lower()] = true
                seen[label:lower()] = true
            end
        end
    end

    -- other addons' buttons; a flood of them, hidden ones included, is some addon's pins, so none are
    -- taken. One its addon or player has hidden waits on the minimap until it's shown
    local found = {}
    for _, parent in ipairs({ Minimap, MinimapBackdrop, MinimapCluster }) do
        for _, child in ipairs(parent and { parent:GetChildren() } or {}) do
            if not adopted[child] and IsForeignButton(child) then found[#found + 1] = child end
        end
    end
    if #found <= C.MAX_FOREIGN then
        for _, child in ipairs(found) do
            known["frame:" .. FrameId(child)] = FrameLabel(child)
            if child:IsShown() and not Left("frame:" .. FrameId(child)) then adopted[child] = true end
        end
    end
    for frame in pairs(adopted) do
        -- one its addon has hidden since gets no cell (the panel's being hidden doesn't count)
        if frame:IsShown() then
            local label = FrameLabel(frame)
            known["frame:" .. FrameId(frame)] = label
            entries[#entries + 1] = { kind = "frame", name = FrameId(frame), label = label, frame = frame }
            seen[label:lower()] = true
        end
    end

    local compartment = AddonCompartmentFrame
    for _, data in ipairs(compartment and compartment.registeredAddons or {}) do
        local label = StripText(data.text)
        -- FlareUI's own entry only while FlareUI Minimap Button is on (Bag.FlareOn)
        if label == "FlareUI" and not Bag.FlareOn() then label = "" end
        if label ~= "" and not seen[label:lower()] and not AlreadyListed(data, label) then
            seen[label:lower()] = true
            known["compartment:" .. label] = label
            if not Left("compartment:" .. label) then
                entries[#entries + 1] = { kind = "compartment", name = label, label = label, data = data }
            end
        end
    end

    -- the dragged order (minimap.bagOrder), then the rest A to Z
    table.sort(entries, function(a, b) return a.label:lower() < b.label:lower() end)
    local db = GetDb()
    local order = db and db.bagOrder
    if type(order) == "table" and #order > 0 then
        local rank = {}
        for i, id in ipairs(order) do rank[id] = i end
        for i, e in ipairs(entries) do e.alpha = i end
        table.sort(entries, function(a, b)
            local ra, rb = rank[a.kind .. ":" .. a.name], rank[b.kind .. ":" .. b.name]
            if ra and rb then return ra < rb end
            if ra or rb then return ra ~= nil end
            return a.alpha < b.alpha
        end)
    end
end

local function EntryId(e) return e.kind .. ":" .. e.name end

-- Addons in the Drawer's list: every addon seen, A to Z, as { token, label } (a comma in an id would
-- split the saved list, so tokens have none), and the drawer's choice for each
-- (11-13: one addon can be there twice, its button and its compartment entry, e.g. RareScanner: one tick
-- box per name covers both, so unticking it really leaves the button alone)
local tokenIds = {}   -- token -> { id, ... }
function Bag.AddonChoices()
    if not next(known) then pcall(CollectEntries) end
    local list, byKey = {}, {}
    wipe(tokenIds)
    -- one row per addon (11-13, Marcus: BtWQuests listed twice): its compartment entry, data object and
    -- own button are matched loosely by name (NameKey: "BtWQuests" = "BtWQuestsMinimapButton"), shown by
    -- the shortest of their labels
    for id, label in pairs(known) do
        local key = NameKey(label)
        if key == "" then key = label:lower():gsub("[,%s]", "") end
        local row = byKey[key]
        if not row then
            row = { key, label }
            byKey[key] = row
            tokenIds[key] = {}
            list[#list + 1] = row
        elseif #label < #row[2] then
            row[2] = label
        end
        table.insert(tokenIds[key], id)
    end
    table.sort(list, function(a, b) return a[2]:lower() < b[2]:lower() end)
    return list
end
function Bag.InDrawer()
    local list = {}
    for _, c in ipairs(Bag.AddonChoices()) do
        local inside = true
        for _, id in ipairs(tokenIds[c[1]] or {}) do
            if Left(id) then inside = false end
        end
        if inside then list[#list + 1] = c[1] end
    end
    return #list > 0 and table.concat(list, ",") or "none"
end
function Bag.SetInDrawer(value)
    local db = GetDb()
    if not db then return end
    local ticked = ns.Conditions.Set(value or "")
    db.bagLeave = {}
    for token, ids in pairs(tokenIds) do
        if not ticked[token] then
            for _, id in ipairs(ids) do db.bagLeave[id] = true end
        end
    end
    if ns.Minimap and ns.Minimap.UpdateFlareButton then ns.Minimap.UpdateFlareButton() end
end

-- FlareUI itself (its compartment entry). (11-14, Marcus) FlareUI Minimap Button (minimap.flareButton,
-- on) says whether FlareUI has a button at all; the drawer only says where: in it, unless unticked in
-- Addons in the Drawer, then on the minimap (Minimap.lua MM.UpdateFlareButton). Off, it is in neither.
local FLARE_ID = "compartment:FlareUI"   -- (the TOC title, as the compartment lists it)
function Bag.FlareOn()
    local db = GetDb()
    return db ~= nil and db.flareButton ~= false
end
-- FlareUI in the drawer right now
function Bag.FlareIn()
    return Bag.initialized and Bag:IsOn() and Bag.FlareOn() and not Left(FLARE_ID) or false
end
-- the option changed: the drawer redrawn if open, the minimap button shown or hidden
function Bag.FlareChanged()
    known[FLARE_ID] = nil   -- (CollectEntries puts it back while the option is on)
    if panel and panel:IsShown() then Bag:Layout() else pcall(CollectEntries) end
    if ns.Minimap and ns.Minimap.UpdateFlareButton then ns.Minimap.UpdateFlareButton() end
end

--------------------------------------------------
-- 3. THE PANEL
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

-- a menu an addon opened from its icon (Blizzard's menus, or the old dropdown list)
local function AnyMenuOpen()
    local manager = Menu and Menu.GetManager and Menu.GetManager()
    if manager and manager:IsAnyMenuOpen() then return true end
    local list = _G.DropDownList1
    return list and list:IsShown() or false
end

-- The click runs first and the bag closes a frame later: Blizzard closes a menu whose owner is hidden,
-- so a launcher's right-click menu would vanish at once. A menu it opens keeps the bag open.
local function OnIconClick(self, mouseButton)
    local e = self.entry
    if not e or Bag.justDragged then return end
    GameTooltip:Hide()
    C_Timer.After(0, function()
        if not AnyMenuOpen() then Bag:Close() end
    end)
    if e.kind == "ldb" then
        if e.object.OnClick then e.object.OnClick(self, mouseButton) end
    elseif e.kind == "compartment" then
        if e.data.func then e.data.func(e.data, { buttonName = mouseButton }, nil) end
    end
end

-- The action button look of the bag's own icons (also the settings preview's sample)
function Bag.NewIconButton(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(C.BUTTON, C.BUTTON)
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
    return b
end

-- The bag's own button for a LibDBIcon or compartment entry
local function GetIconButton(i)
    local b = buttons[i]
    if b then return b end
    b = Bag.NewIconButton(panel)
    b:RegisterForClicks("AnyUp")
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

-- Beside the badge, towards the middle of the screen
local function AnchorPanel()
    local badge = MinimapCluster and MinimapCluster.DielFrame
    if not badge then return end
    -- the badge's own units (its scale and Edit Mode's) to UIParent's
    local x, y = badge:GetCenter()
    local k = badge:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local right = x and x * k > UIParent:GetWidth() / 2
    local top = y and y * k > UIParent:GetHeight() / 2
    panel:ClearAllPoints()
    local v = top and "TOP" or "BOTTOM"
    if right then
        panel:SetPoint(v .. "RIGHT", badge, v .. "LEFT", -C.GAP, 0)
    else
        panel:SetPoint(v .. "LEFT", badge, v .. "RIGHT", C.GAP, 0)
    end
end

-- the cell an adopted button sits in; true while FlareUI itself places one
local placing = false
local function PlaceInCell(frame)
    local cell = frame.FlareUI_BagCell
    if not cell then return end
    placing = true
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", panel, "TOPLEFT", cell[1], cell[2])
    placing = false
end

-- A button another addon moves back onto the minimap goes straight back into the bag, and one its addon
-- re-anchors (on its own events) goes back into its cell
local function KeepAdoptedInBag()
    for frame in pairs(adopted) do
        if not frame.FlareUI_BagHooked then
            frame.FlareUI_BagHooked = true
            hooksecurefunc(frame, "SetParent", function(self, parent)
                if parent ~= panel and adopted[self] and Bag:IsOn() then self:SetParent(panel) end
            end)
            hooksecurefunc(frame, "SetPoint", function(self)
                if placing or not (adopted[self] and Bag:IsOn() and self:GetParent() == panel) then return end
                PlaceInCell(self)
            end)
        end
        if not (panel and panel:IsShown()) and frame:GetParent() ~= panel then frame:SetParent(panel) end
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
    wipe(cells)
    for i, e in ipairs(entries) do
        local col, row = (i - 1) % columns, math.floor((i - 1) / columns)
        local x, y = C.PAD + col * step, -(C.PAD + row * step)
        local frame
        if e.kind == "frame" then
            -- the addon's own button, moved into the cell
            frame = e.frame
            frame:SetParent(panel)
            -- (11-13, a player: Social Diary's button dimmed and dead in the drawer) a button that fixed
            -- its own strata and level (Social Diary: MEDIUM 8, SetFixedFrameStrata/Level) kept them
            -- under the panel; the drawer holds it until a reload, so they're unfixed while it's here
            if frame.HasFixedFrameStrata and frame:HasFixedFrameStrata() then frame:SetFixedFrameStrata(false) end
            if frame.HasFixedFrameLevel and frame:HasFixedFrameLevel() then frame:SetFixedFrameLevel(false) end
            -- its own strata or a lower level would put it under the panel
            ns.CopyStrata(frame, panel)
            frame:SetFrameLevel(panel:GetFrameLevel() + 2)
            frame.FlareUI_BagCell = { x + C.BUTTON / 2, y - C.BUTTON / 2 }
            PlaceInCell(frame)
        else
            used = used + 1
            frame = GetIconButton(used)
            frame.entry = e
            SetIcon(frame.icon, e.kind == "ldb" and e.object.icon or e.data.icon, e.kind == "ldb" and e.object or nil)
            -- kept on the minimap: dimmed here
            frame:SetAlpha(1)
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
            -- back under the drag handles (a dragged icon is lifted)
            frame:SetFrameLevel(panel:GetFrameLevel() + 2)
            frame:Show()
        end
        cells[i] = frame
    end
    for i = used + 1, #buttons do buttons[i]:Hide(); buttons[i].entry = nil end
    -- a drag handle over each cell; clicks and mouse-over pass through to the icon
    for i = 1, count do
        local catcher = Bag.GetCatcher(i)
        if catcher then
            local col, row = (i - 1) % columns, math.floor((i - 1) / columns)
            catcher:ClearAllPoints()
            catcher:SetPoint("TOPLEFT", panel, "TOPLEFT", C.PAD + col * step, -(C.PAD + row * step))
            catcher:SetSize(C.BUTTON, C.BUTTON)
            catcher:SetFrameLevel(panel:GetFrameLevel() + 10)
            catcher:Show()
        end
    end
    for i = count + 1, #catchers do catchers[i]:Hide() end
    Bag.columns = columns
    AnchorPanel()
    KeepAdoptedInBag()
end

--------------------------------------------------
-- 4. DRAG TO REORDER
-- The order is saved by entry id (kind and name), so it holds when addons come and go
--------------------------------------------------
local function CursorInUI()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    return x / scale, y / scale
end

local function FollowCursor()
    if not drag then return end
    local x, y = CursorInUI()
    local frame = drag.frame
    local k = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x * k, y * k)
end

local function OnDragStart(self)
    local frame = cells[self.index]
    if not frame then return end
    drag = { from = self.index, frame = frame }
    -- drop on any mouse-up: OnDragStop may never come (cursor leaving the game window)
    panel:RegisterEvent("GLOBAL_MOUSE_UP")
    -- skip the icon's click the mouse-up may still bring
    Bag.justDragged = true
    GameTooltip:Hide()
    frame:SetFrameLevel(panel:GetFrameLevel() + 20)
    panel:SetScript("OnUpdate", FollowCursor)
end

local function OnDragStop()
    if not drag then return end
    panel:SetScript("OnUpdate", nil)
    panel:UnregisterEvent("GLOBAL_MOUSE_UP")
    local from = drag.from
    drag = nil
    -- the cell under the cursor, clamped to the bag
    local x, y = CursorInUI()
    local left, top = panel:GetLeft(), panel:GetTop()
    local step = C.BUTTON + C.SPACING
    local columns = Bag.columns or 1
    local col = math.max(0, math.min(columns - 1, math.floor((x - left - C.PAD) / step)))
    local row = math.max(0, math.floor((top - y - C.PAD) / step))
    local to = math.max(1, math.min(#entries, row * columns + col + 1))
    if to ~= from then
        local moved = table.remove(entries, from)
        table.insert(entries, to, moved)
        local db = GetDb()
        if db then
            db.bagOrder = {}
            for i, e in ipairs(entries) do db.bagOrder[i] = EntryId(e) end
        end
    end
    C_Timer.After(0, function() Bag.justDragged = nil end)
    Bag:Layout()
end

function Bag.GetCatcher(i)
    local catcher = catchers[i]
    if catcher then catcher.index = i; return catcher end
    -- mouse propagation can't be set in combat: no drag handle until the next open
    if InCombatLockdown() then return nil end
    catcher = CreateFrame("Frame", nil, panel)
    catcher:EnableMouse(true)
    catcher:RegisterForDrag("LeftButton")
    if catcher.SetPropagateMouseClicks then catcher:SetPropagateMouseClicks(true) end
    if catcher.SetPropagateMouseMotion then catcher:SetPropagateMouseMotion(true) end
    catcher:SetScript("OnDragStart", OnDragStart)
    catcher:SetScript("OnDragStop", OnDragStop)
    catcher.index = i
    catchers[i] = catcher
    return catcher
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

-- Hover mode: how long the pointer may be away from the badge and the drawer before it closes. A
-- menu an icon opened, or an icon being dragged, keeps it open.
local HOVER_CLOSE = 0.15   -- (0.5 until 11-11: too slow, Marcus)
local hoverWatch = CreateFrame("Frame")
hoverWatch:Hide()
hoverWatch:SetScript("OnUpdate", function(self, elapsed)
    if not (panel and panel:IsShown()) then self:Hide() return end
    if drag or AnyMenuOpen() or panel:IsMouseOver() or (badgeButton and badgeButton:IsMouseOver()) then
        self.away = 0
        return
    end
    self.away = (self.away or 0) + elapsed
    if self.away >= HOVER_CLOSE then
        self:Hide()
        panel:Hide()
    end
end)

local function OpenOnHover()
    if not (panel and HoverOn()) then return end
    if not panel:IsShown() then
        Bag:Layout()
        panel:Show()
    end
    hoverWatch.away = 0
    hoverWatch:Show()
end

-- The panel's backdrop on any BackdropTemplate frame (also the settings preview's sample)
function Bag.StylePanel(f)
    local bg = LSM:Fetch("background", "Blizzard Dialog Background Dark") or "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"
    local edge = LSM:IsValid("border", C.BORDER) and LSM:Fetch("border", C.BORDER) or nil
    f:SetBackdrop({ bgFile = bg, edgeFile = edge, tile = false, tileSize = 0,
        edgeSize = ns.BorderEdgeSize(edge, 16), insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    f:SetBackdropColor(1, 1, 1, C.OPACITY)
    local b = ns.BORDER_COLOR
    f:SetBackdropBorderColor(b.r, b.g, b.b, b.a)
end

local function CreatePanel()
    panel = CreateFrame("Frame", "FlareUI_MinimapBag", UIParent, "BackdropTemplate")
    panel:SetFrameStrata("HIGH")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:Hide()
    Bag.StylePanel(panel)

    panel.empty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.empty:SetPoint("CENTER")
    panel.empty:SetText(L["No addon buttons"])

    -- closes on Escape and on a click outside the bag and badge
    tinsert(UISpecialFrames, "FlareUI_MinimapBag")
    panel:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
    panel:SetScript("OnHide", function(self)
        self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
        -- closed mid-drag: the icon returns to its cell next time
        if drag then drag = nil; Bag.justDragged = nil; self:SetScript("OnUpdate", nil); self:UnregisterEvent("GLOBAL_MOUSE_UP") end
    end)
    panel:SetScript("OnEvent", function(self, event)
        if event == "GLOBAL_MOUSE_UP" then OnDragStop() return end
        -- a press on an addon's menu beside the bag: the menu needs its owner until the click lands
        if AnyMenuOpen() then return end
        if self:IsMouseOver() or (badgeButton and badgeButton:IsMouseOver()) then return end
        self:Hide()
    end)
end

--------------------------------------------------
-- 5. BADGE AND SETUP
--------------------------------------------------
-- The click area over the badge (Blizzard's badge takes no mouse)
local function CreateBadgeButton()
    local badge = MinimapCluster and MinimapCluster.DielFrame
    if not badge then return end
    badgeButton = CreateFrame("Button", nil, badge)
    badgeButton:SetAllPoints(badge)
    badgeButton:SetFrameLevel(badge:GetFrameLevel() + 2)
    badgeButton:RegisterForClicks("LeftButtonUp")
    -- with Open on Mouseover a click still toggles it (a quick close, or a second look)
    badgeButton:SetScript("OnClick", function() Bag:Toggle() end)
    badgeButton:SetScript("OnEnter", OpenOnHover)
end

function Bag:Init()
    if self.initialized or not self:IsOn() then return end
    if not (MinimapCluster and MinimapCluster.DielFrame) then return end
    self.initialized = true
    CreatePanel()
    CreateBadgeButton()
    -- LibDBIcon buttons are parked as they are made; other buttons have no signal, so a few sweeps
    -- run while addons finish loading
    local lib = LibDBIcon()
    if lib and lib.RegisterCallback then
        lib.RegisterCallback(Bag, "LibDBIcon_IconCreated", function(_, button, name) ParkIcon(button, name) end)
    end
    local function Sweep()
        ParkAllIcons()
        CollectEntries()
        KeepAdoptedInBag()
    end
    Sweep()
    for _, delay in ipairs({ 0, 0.5, 1.5, 4 }) do C_Timer.After(delay, Sweep) end
    -- an addon loaded later (on demand, or one that waits) gets its button parked too: one sweep a
    -- moment after a burst of loads
    local loads = CreateFrame("Frame")
    local pending = false
    loads:RegisterEvent("ADDON_LOADED")
    loads:SetScript("OnEvent", function()
        if pending then return end
        pending = true
        C_Timer.After(0.5, function() pending = false; Sweep() end)
    end)
end

--------------------------------------------------
-- 6. SETTINGS PREVIEW SAMPLE (drawn under the Minimap module's sample)
-- The panel's look and grid with one row of icons: the player's own LibDBIcon icons, only read (no
-- button is parked or adopted), else stand-ins
--------------------------------------------------
local SAMPLE_ICONS = { "Interface\\Icons\\INV_Misc_Bag_08", "Interface\\Icons\\INV_Misc_Book_09",
                       "Interface\\Icons\\INV_Misc_Map_01", "Interface\\Icons\\INV_Misc_Gear_01" }

function Bag.CreateSample(parent)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f.fuiSample = true
    f:EnableMouse(false)
    Bag.StylePanel(f)
    f.icons = {}
    for i = 1, C.COLUMNS do
        local b = Bag.NewIconButton(f)
        b:EnableMouse(false)
        f.icons[i] = b
    end
    return f
end

function Bag.DrawSample(f)
    local objects = {}
    local lib, ldb = LibDBIcon(), LibDataBroker()
    if lib and ldb then
        for _, name in ipairs(lib:GetButtonList() or {}) do
            local object = ldb:GetDataObjectByName(name)
            if object and object.icon then objects[#objects + 1] = object end
            if #objects >= C.COLUMNS then break end
        end
    end
    local count = #objects > 0 and #objects or #SAMPLE_ICONS
    local step = C.BUTTON + C.SPACING
    for i, b in ipairs(f.icons) do
        if i <= count then
            local object = objects[i]
            SetIcon(b.icon, object and object.icon or SAMPLE_ICONS[i], object)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", f, "TOPLEFT", C.PAD + (i - 1) * step, -C.PAD)
            b:Show()
        else
            b:Hide()
        end
    end
    local width, height = C.PAD * 2 + count * step - C.SPACING, C.PAD * 2 + C.BUTTON
    f:SetSize(width, height)
    f:Show()
    return width, height
end
