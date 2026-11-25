local H = dofile("tools/tests/perf-helpers.lua")
local UI = dofile("tools/tests/fixtures/settings-ui.lua")
return function(db)
    local ui = UI.new()
    local env = ui.env
    local function noop() end
    local function applyFont(widget, path, size, flags) widget:SetFont(path, size, flags) end
    local ns = {
        modules = {},
        L = setmetatable({}, { __index = function(_, key) return key end }),
        db = { profile = { unitframes = db } },
        defaults = { profile = { unitframes = { units = {} } } },
        BORDER_COLOR = { r = 0.6, g = 0.4, b = 0.2, a = 1 },
        HEALTH_GREEN = { 0, 1, 0 },
        MANA_BLUE = { 0, 0, 1 },
        COMBO_COLOR = { 1, 0.8, 0.2 },
        ShortNumber = tostring,
        GetFontPath = function(face) return "Fonts/" .. face end,
        UFFontDefault = function() return { size = 12 } end,
        SetFontFamily = applyFont,
        SetFontUnscaled = applyFont,
        ApplyShadow = noop,
        EditPreviewing = function() return false end,
        ClassColorsOn = function(udb) return udb.classColor ~= false end,
        PowerColor = function() return 0.1, 0.2, 0.8 end,
        UnitDisplayName = function(_, _, full) return full and "Juniper Vale" or "Juniper" end,
        BorderEdgeSize = function(_, size) return size end,
    }

    local media = {
        IsValid = function(_, _, name) return name ~= "" end,
        Fetch = function(_, kind, name) return kind .. "/" .. name end,
    }
    local ace, editMode = { Embed = noop }, { RegisterCallback = noop }
    function env.LibStub(name)
        if name == "LibSharedMedia-3.0" then return media end
        if name == "AceEvent-3.0" then return ace end
        if name == "FlareEditMode" then return editMode end
        error("unexpected library " .. name)
    end
    env.CurveConstants = { ScaleTo100 = {} }
    env.C_ClassColor = { GetClassColor = function() return env.CreateColor(0.2, 0.4, 0.6, 1) end }
    env.C_Texture = { GetAtlasInfo = function(atlas)
        return { width = 194, height = 68, file = "Atlas/" .. atlas,
            leftTexCoord = 0, rightTexCoord = 1, topTexCoord = 0, bottomTexCoord = 1 }
    end }
    env.UnitExists = function(unit) return unit == "player" end
    env.UnitIsPlayer, env.UnitIsConnected = env.UnitExists, env.UnitExists
    env.UnitClass = function() return "Mage", "MAGE" end
    env.UnitLevel = function() return 43 end
    env.GetClassAtlas = function(class) return "Class/" .. class end
    env.GetClassAtlasName = env.GetClassAtlas
    env.SetPortraitTexture = function(tex, unit) tex:SetTexture("Portrait/" .. unit) end
    env.canaccessvalue = function(v) return v ~= "hidden" end   -- ("hidden": a secret value)

    local Widget = getmetatable(env.UIParent)
    function Widget:SetTexCoord(...) self.coords = { ... } end
    function Widget:GetTexCoord() return unpack(self.coords or { 0, 1, 0, 1 }) end
    function Widget:SetVertexColor(...) self.color = { ... } end
    function Widget:AddMaskTexture(mask)
        self.masks = self.masks or {}
        self.masks[mask] = true
    end
    function Widget:RemoveMaskTexture(mask) if self.masks then self.masks[mask] = nil end end
    function Widget:SetTarget(frame) self.animationTarget = frame end
    function Widget:SetLooping(value) self.looping = value end
    function Widget:SetSmoothing(value) self.smoothing = value end
    function Widget:SetIgnoreParentAlpha(value) self.ignoreParentAlpha = value end
    function Widget:SetSnapToPixelGrid(value) self.snapToPixelGrid = value end
    function Widget:SetTexelSnappingBias(value) self.texelSnappingBias = value end

    env.ns = ns
    H.loadSections("Core.lua", {
        {"ns.THREAT_MAX = 999", "-- Edit Mode rows in one order everywhere"},
        {"function ns.ProfileChanges(", "function ns.PlayerGUID("},
    }, env)
    ui:load("Modules/BarText.lua", ns)
    ui:load("Modules/UnitFramesRing.lua", ns)
    ui:load("Modules/UnitFrames.lua", ns)
    return ui, ns
end
