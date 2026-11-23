local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local ns = { L = setmetatable({}, { __index = function(_, key) return key end }) }
local edit = { SettingType = { Dropdown = 1, Slider = 2, Checkbox = 3, Expander = 4 }, callbacks = {} }
function edit:IsInEditMode() return ui.editing == true end
function edit:GetActiveLayoutName() return "Modern" end
function edit:AddFrame(frame, moved) frame.moved = moved end
function edit:AddFrameSettings(frame, rows) frame.settings = rows end
function edit:RegisterCallback(event, callback) self.callbacks[event] = callback end
function edit:AddSelectionArea() end
function edit:Defer() return false end
function edit:RefreshFrameSettings(frame) self.refreshed = frame end

local unit = {
    player = { name = "Alba", class = "PRIEST", level = 41, health = 95, power = 72, role = "HEALER" },
    party1 = { name = "Mira", surname = "Reed", class = "HUNTER", level = 42, health = 80, power = 60, role = "DAMAGER" },
    party2 = { name = "Lark", class = "WARRIOR", level = 45, health = 90, power = 20, role = "TANK", leader = true },
    partypet1 = { name = "Wolf", level = 42, health = 71, power = 0 },
    party1target = { name = "Spider", level = 40, health = 25, power = 0, hostile = true },
}
env.GetLocale = function() return "enUS" end
env.GetCurrentRegion = function() return 1 end
env.GetCurrentRegionName = function() return "US" end
env.GetRealmName = function() return "Forever" end
env.UnitNameUnmodified = function() return "Alba" end
env.UnitRace = function() return "Human", "Human" end
env.strlenutf8 = string.len
env.C_AddOns.DoesAddOnExist = function() return false end
env.UnitGUID = function(token) return unit[token] and (unit[token].guid or "GUID-" .. token) end
env.UnitExists = function(token) return unit[token] ~= nil end
env.UnitName = function(token) local u = unit[token]; if u then return u.name, u.surname end end
env.UnitIsUnit = function(a, b)
    if a == "target" then a = ui.targetUnit end
    if b == "target" then b = ui.targetUnit end
    return a == b
end
env.UnitClass = function(token) return nil, unit[token] and unit[token].class end
env.UnitClassification = function(token) return unit[token] and unit[token].classification or "normal" end
env.UnitIsPlayer = function(token) return unit[token] and unit[token].class ~= nil end
env.UnitGroupRolesAssigned = function(token) return unit[token] and unit[token].role or "NONE" end
env.UnitLevel = function(token) return unit[token] and unit[token].level end
env.UnitIsFriend = function(_, token) return unit[token] and not unit[token].hostile end
env.UnitCanAttack = function(_, token) return unit[token] and unit[token].hostile end
env.UnitReaction = function() return 2 end
env.UnitIsConnected = function(token) return unit[token] and not unit[token].offline end
env.UnitInRange = function(token) return unit[token] and not unit[token].far, true end
env.UnitIsVisible = function(token) return unit[token] and not unit[token].far end
env.UnitDistanceSquared = function(token) return unit[token] and unit[token].distance or 100, true end
env.UnitPhaseReason = function(token) return unit[token] and unit[token].phase end
env.UnitIsDead = function(token) return unit[token] and unit[token].dead end
env.UnitIsGhost = function(token) return unit[token] and unit[token].ghost end
env.UnitIsDeadOrGhost = function(token) return env.UnitIsDead(token) or env.UnitIsGhost(token) end
env.UnitHealth = function(token) return unit[token].health end
env.UnitHealthMax = function() return 100 end
env.UnitHealthMissing = function(token) return 100 - unit[token].health end
env.UnitHealthPercent = env.UnitHealth
env.AbbreviateNumbers = function(value) return tostring(value) end
env.UnitPower = function(token) return unit[token].power end
env.UnitPowerMax = function() return 100 end
env.UnitPowerPercent = env.UnitPower
env.UnitPowerType = function(token) if token == "party2" then return 1, "RAGE" end; return 0, "MANA" end
env.UnitGetIncomingHeals = function(token) return unit[token].heal or 0 end
env.UnitGetTotalAbsorbs = function(token) return unit[token].absorb or 0 end
env.UnitThreatSituation = function(_, token) return unit[token or "player"] and unit[token or "player"].threat end
env.UnitIsGroupLeader = function(token) return unit[token] and unit[token].leader end
env.UnitIsGroupAssistant = function() return false end
env.UnitIsPVPFreeForAll = function() return false end
env.UnitIsPVP = function(token) return unit[token] and unit[token].pvp end
env.UnitFactionGroup = function() return "Alliance" end
env.UnitHasIncomingResurrection = function(token) return unit[token] and unit[token].resurrection end
env.UnitIsTapDenied = function() return false end
env.UnitCastingInfo = function() end
env.UnitChannelInfo = function() end
env.IsInGroup = function() return ui.inGroup ~= false end
env.IsInRaid = function() return ui.inRaid == true end
env.UnitInRaid = function(token) return ui.inRaid and token:match("^raid%d+$") and unit[token] ~= nil end
env.UnitInParty = function(token) return token:match("^party%d+$") and unit[token] ~= nil end
env.GetReadyCheckStatus = function(token) return unit[token] and unit[token].ready end
env.GetRaidTargetIndex = function(token) return unit[token] and unit[token].mark end
env.SetRaidTargetIconTexture = function(icon, mark) icon.raidMark = mark end
env.SetPortraitTexture = function(tex, token) tex:SetTexture("portrait:" .. token) end
env.GetClassAtlas = function(class) return "class:" .. class end
env.GetClassAtlasName = env.GetClassAtlas
env.C_ClassColor = { GetClassColor = function() return env.CreateColor(0.2, 0.5, 0.9) end }
env.C_Texture = { GetAtlasInfo = function() return { width = 194, height = 68 } end }
env.C_SpellBook = { IsSpellKnown = function(id) return id == 2006 end, GetNumSpellBookSkillLines = function() return 0 end }
env.C_Spell = { IsSpellInRange = function(_, token) return env.UnitInRange(token) end, GetSpellName = function() end }
env.Enum = {
    PowerType = { Mana = 0 }, SpellBookSpellBank = { Player = 0 },
    StatusBarInterpolation = { ExponentialEaseOut = 1, Immediate = 0 },
}
env.CurveConstants = { ScaleTo100 = {} }
env.AnchorUtil = { FlowDirection = { Left = 1, Right = 2, Up = 3, Down = 4 }, FlowLayoutAxis = { Horizontal = 1 } }
env.C_DurationUtil = { CreateDurationTextBinding = function() end }
env.canaccessvalue = function(v) return v ~= "hidden" end
env.canaccessallvalues = function() return true end
env.securecallfunction = function(func, ...) return func(...) end
env.RegisterStateDriver = function(frame, attr, rule)
    frame:SetAttribute(attr, rule)
    if rule == "show" or rule == "hide" then frame:SetShown(rule == "show") end
end
env.UnregisterStateDriver = function(frame, attr) frame:SetAttribute(attr, nil) end
env.RegisterUnitWatch = function(frame)
    frame.unitWatched = true
    frame:SetShown(env.UnitExists(frame:GetAttribute("unit")))
end
env.UnregisterUnitWatch = function(frame) frame.unitWatched = nil end
env.C_Timer.NewTimer = env.C_Timer.NewTicker
env.GameTooltip_SetDefaultAnchor = function(tooltip, owner) tooltip:SetOwner(owner, "ANCHOR_DEFAULT") end
env.GameTooltip.SetUnit = function(self, value) self.unit = value end
local Widget = getmetatable(env.UIParent)
function Widget:SetVertexColor(...) self.color = { ... } end
function Widget:SetLooping(value) self.looping = value end
function Widget:SetPropagateMouseClicks(value) self.propagate = value end
function Widget:SetMouseClickEnabled(value) self.mouseClicks = value end
function Widget:SetIgnoreParentAlpha(value) self.ignoreParentAlpha = value end
function Widget:SetTarget(value) self.animationTarget = value end
function Widget:SetBorderBlendMode(value) self.borderBlendMode = value end
function Widget:SetTexCoord(...) self.coords = { ... } end
function Widget:GetTexCoord() return unpack(self.coords or { 0, 1, 0, 1 }) end

ui:load("Libs/LibStub/LibStub.lua", ns)
ui:load("Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua", ns)
ui:load("Libs/AceEvent-3.0/AceEvent-3.0.lua", ns)
ui:load("Libs/AceDB-3.0/AceDB-3.0.lua", ns)
local media = env.LibStub:NewLibrary("LibSharedMedia-3.0", 1)
function media:Fetch(kind, name) return (kind or "") .. "/" .. (name or "default") end
function media:IsValid(_, name) return type(name) == "string" end
function media:List(kind) return kind == "statusbar" and { "FlareUI Dark" } or { "FlareUI Thin" } end
env.C_UIFileAsset = { IsKnownFile = function() return true end }
local libEdit = env.LibStub:NewLibrary("FlareEditMode", 1)
for key, value in pairs(edit) do libEdit[key] = value end
ui:load("Core.lua", ns)
ui:emit("ADDON_LOADED", "FlareUI")
local profile = ns.db.profile.unitframes
profile.enabled, profile.foreverStyle, profile.plateStyle = true, false, false
profile.styleStart = true
env.PartyFrame = env.CreateFrame("Frame", "PartyFrame", env.UIParent)
env.PartyFrame.IsProtected = function() return false end
-- Some tests exercise the client-backed aura containers as well as the tiles.
if ... then dofile("tools/tests/fixtures/aura-containers.lua")(env) end
ui:load("Modules/BarText.lua", ns)
ui:load("Modules/UnitFrames.lua", ns)
ui:load("Modules/UnitFramesRing.lua", ns)
ui:load("Modules/PartyFrames.lua", ns)

-- Exercise secure snippets as plain Lua and model the roster assignments supplied by the client.
-- The fixture does not model protected execution or taint.
function ui:installGroupHeaders()
    local create = env.CreateFrame
    local function run(frame, source, attrs)
        local scope = setmetatable(attrs or {}, { __index = env })
        scope.self, scope.newtable = frame, function() return {} end
        return setfenv(assert(loadstring(source)), scope)()
    end
    function Widget:SetFrameRef(key, frame)
        self.frameRefs = self.frameRefs or {}
        self.frameRefs[key] = frame
    end
    function Widget:GetFrameRef(key) return self.frameRefs and self.frameRefs[key] end
    function Widget:Execute(source) return run(self, source) end
    function Widget:RunAttribute(key) return run(self, assert(self:GetAttribute(key))) end
    function Widget:CallMethod(key, ...) return self[key](self, ...) end
    env.SecureHandlerSetFrameRef = Widget.SetFrameRef
    env.SecureHandlerWrapScript = function(frame, _, owner, source)
        frame.secureWrap, frame.secureOwner = source, owner
    end
    env.CreateFrame = function(kind, name, parent, template)
        local frame = create(kind, name, parent, template)
        local setAttribute = frame.SetAttribute
        function frame:SetAttribute(key, value)
            local old = self:GetAttribute(key)
            setAttribute(self, key, value)
            if old == value then return end
            if template == "SecureGroupHeaderTemplate" and key == "startingIndex" and value < 0 then
                for i = 1, 1 - value do
                    local child = env.CreateFrame("Button", name .. "Unit" .. i, self, self:GetAttribute("template"))
                    self[i] = child
                    child:Hide()
                    run(child, assert(self:GetAttribute("initialConfigFunction")))
                end
            end
            self:RunScript("OnAttributeChanged", key, value)
            if self.secureWrap then run(self, self.secureWrap, { name = key, control = self.secureOwner }) end
            local changes = self:GetAttribute("_onattributechanged")
            if changes then run(self, changes, { name = key, value = value }) end
        end
        return frame
    end
    env.RegisterAttributeDriver = function(frame, key, rule)
        local token = assert(rule:match("@([^,]+)"))
        frame:SetAttribute(key, env.UnitExists(token) and "1" or "0")
    end
end

return ui, ns, unit, libEdit
