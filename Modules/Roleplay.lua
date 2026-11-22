local _, ns = ...

-- Total RP 3 owns profiles. This module reads available data; the nameplates
-- and unit frames keep their normal rendering, including their health tints.
local RP = {}
ns.Roleplay, ns.modules.Roleplay = RP, RP
local ready, initialized, pending
local names, colours, health, frameNames = false, false, false, false
local cache, subscriptions = {}, {}

function RP.Hidden() return not ready end
function RP:ShouldLoad() return TRP3_Addon ~= nil and TRP3_API ~= nil end

local function Profile(unit)
    if not canaccessallvalues(UnitNameUnmodified(unit)) then return end
    local id = TRP3_NameUtil.GetQualifiedName(unit)
    if not id then return end
    local p = cache[unit]
    if p and p.id == id then return p end
    local player = AddOn_TotalRP3.Player.CreateFromCharacterID(id)
    p = { id = id, firstName = player:GetFirstName(), fullName = player:GetFullName() }
    local raw = player:GetCustomColor()
    if raw then
        p.r, p.g, p.b = raw:GetRGB()
        p.dr, p.dg, p.db = player:GetCustomColorForDisplay():GetRGB()
    end
    cache[unit] = p
    return p
end

local function ProfileName(p, full)
    if not p then return end
    local name
    if full then name = p.fullName else name = p.firstName end
    if name ~= "" then return name end
end

local function FrameName(unit, full)
    if unit ~= "player" and unit ~= "target" then return end
    local player = UnitIsPlayer(unit)
    if canaccessvalue(player) and player then return ProfileName(Profile(unit), full) end
end

local function Nameplate(unit, full)
    local p = Profile(unit)
    if p then
        local name = names and ProfileName(p, full) or nil
        if colours then return name, p.dr, p.dg, p.db end
        return name
    end
end

local function Health(unit)
    local p = Profile(unit)
    if p and p.r then return p.r, p.g, p.b end
    return "class"
end

local function QueueRefresh()
    if pending then return end
    pending = true
    C_Timer.After(0, function()
        pending = nil
        wipe(cache)
        if names or colours then ns.RefreshNameplateText() end
        if health then ns.RefreshUnitFrameHealthColor() end
        if frameNames then ns.RefreshUnitFrameNames() end
    end)
end

local function Watch(source, event, callback)
    subscriptions[#subscriptions + 1] = TRP3_API.RegisterCallback(source, event, callback)
end

function RP.Refresh()
    if not (ready and initialized) then return end
    local np, uf = ns.db.profile.nameplates, ns.db.profile.unitframes
    local oldNames, oldColours, oldHealth = names, colours, health
    local oldFrameNames = frameNames
    names, colours, health = np.enabled and np.rpNames, np.enabled and np.rpColours, uf.enabled and uf.rpHealth
    ns.NameplateTextProvider = (names or colours) and Nameplate or nil
    ns.UnitFrameHealthColorProvider = health and Health or nil
    frameNames = uf.enabled and uf.rpNames
    ns.UnitFrameNameProvider = frameNames and FrameName or nil
    wipe(cache)
    if names or colours or health or frameNames then
        if #subscriptions == 0 then
            Watch(TRP3_Addon, "REGISTER_DATA_UPDATED", function(_, id)
                if not id then QueueRefresh() return end
                for _, p in pairs(cache) do
                    if p.id == id then QueueRefresh() return end
                end
            end)
            Watch(TRP3_Addon, "REGISTER_PROFILES_LOADED", QueueRefresh)
            Watch(TRP3_Addon, "REGISTER_PROFILE_DELETED", QueueRefresh)
            Watch(TRP3_Addon, "CONFIGURATION_CHANGED", function(_, key)
                if colours and key == "color_contrast_level" then QueueRefresh() end
            end)
            Watch(TRP3_API.GameEvents, "PLAYER_REGEN_ENABLED", QueueRefresh)
        end
    else
        for _, sub in ipairs(subscriptions) do sub:Unregister() end
        wipe(subscriptions)
    end
    if names ~= oldNames or colours ~= oldColours then ns.RefreshNameplateText() end
    if health ~= oldHealth then ns.RefreshUnitFrameHealthColor() end
    if frameNames ~= oldFrameNames then ns.RefreshUnitFrameNames() end
end

function RP:Init()
    initialized = true
    RP.Refresh()
end

-- OptionalDeps orders file loading; either addon's login initialization can finish first.
if TRP3_API and TRP3_API.RegisterCallback and TRP3_Addon then
    TRP3_API.RegisterCallback(TRP3_Addon, "WORKFLOW_ON_LOADED", function()
        ready = AddOn_TotalRP3 and AddOn_TotalRP3.Player and TRP3_NameUtil and TRP3_NameUtil.GetQualifiedName ~= nil
        RP.Refresh()
    end)
end
