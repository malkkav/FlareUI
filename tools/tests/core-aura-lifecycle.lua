local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local settings = { buffs = "TOP", debuffs = "BOTTOM", onlyMyBuffs = true, onlyMyDebuffs = true, hideBuffs = "30" }
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    db = { global = {}, profile = { auras = { hidden = {} }, fonts = { global = { face = "Friz" } } } },
}
local editMode = { IsInEditMode = function() return false end, SettingType = { Dropdown = 1, Checkbox = 2 } }
env.LibStub = function(name) return name == "FlareEditMode" and editMode or {} end
env.GetLocale = function() return "enUS" end
env.CopyTable = function(t)
    local copy = {}
    for key, value in pairs(t) do copy[key] = value end
    return copy
end
env.AuraContainerSortMethod = { Default = 1, AuraInstanceIDOnly = 2, ExpirationOnly = 3, Expiration = 4, NameOnly = 5, Name = 6 }
env.AuraContainerSortDirection = { Normal = 1, Reverse = 2 }
env.AuraUtil = { AuraUpdateChangedType = { Buff = 1, Dispel = 2 } }
env.CustomAuraContainerAuraProcessingPolicy = { None = 0, ProcessAura = 1 }
env.CustomAuraContainerGroupDefaultOptions = { maxFrameCount = 16, sortMethod = 1, sortDirection = 1 }
local enemy, visible, guid = true, true, "Creature-A"
env.UnitExists = function(unit) return unit ~= "missing" end
env.UnitCanAttack = function() return enemy end
env.UnitIsVisible = function() return visible end
env.UnitGUID = function() return guid end
env.canaccessvalue = function(value) return value ~= "hidden" end

ui:load("Core.lua", ns)

local sorts = ns.AuraOrder.With({ { name = "Existing" } },
    function(key) return function() return settings[key] end end,
    function(key) return function(value) settings[key] = value end end, "applied")
assert(sorts[2].get() == "applied" and sorts[4].hidden())
sorts[2].set("time")
sorts[3].set(true)
sorts[4].set(false)
assert(not sorts[4].hidden() and sorts[3].get() and not sorts[4].get())
local sort, direction = ns.AuraOrder.Options(sorts[2].get(), sorts[3].get(), sorts[4].get())
assert(sort == env.AuraContainerSortMethod.ExpirationOnly and direction == env.AuraContainerSortDirection.Reverse)

local refreshes, panelRefreshes = 0, 0
ns.UnitFrames = { Refresh = function() refreshes = refreshes + 1 end }
ns.SettingsPanel = { Refresh = function() panelRefreshes = panelRefreshes + 1 end }
local hidden = ns.HiddenAuras
hidden.Add(11)
hidden.Add(12, "shown")
hidden.Add("12", "shown")
assert(refreshes == 2 and panelRefreshes == 2 and hidden.stamp == 2)
assert(hidden.For("target")[11] and hidden.ShownFor("target")[12] and not hidden.ShownFor("auras"))
local leftOut = hidden.LeftOut("target")
assert(leftOut[11] and leftOut[12] and hidden.LeftOut("target") == leftOut)
hidden.SetList(11, "shown")
assert(hidden.ListOf(11) == "shown" and not hidden.For("target") and not hidden.ShownFor("auras"))
hidden.SetList(11, "hidden")
assert(hidden.For("auras")[11])
hidden.Remove(12, "shown")
assert(not hidden.ShownFor("target") and not hidden.ListOf(12))
hidden.Add(12, "shown")
assert(refreshes == 6 and panelRefreshes == 6)

local aura = ns.AuraPolicy
local target = aura.UnitLanes("target", settings, false)
assert(#target == 5 and target[1].filter == "HARMFUL" and target[1].enemyFilter == "HARMFUL|PLAYER")
assert(target[2].filter == "HARMFUL" and target[2].candidates.includeSpellIDs[12])
assert(target[3].stealable and target[3].enemyOnly and target[3].candidates.excludeSpellIDs[11])
assert(not target[3].candidates.excludeSpellIDs[12] and target[3].candidates.maxDuration == 30)
assert(target[4].joinPrevious and target[4].candidates.excludeSpellIDs[12])
assert(target[5].enemyFilter == "HELPFUL|!RAID_PLAYER_DISPELLABLE" and target[5].candidates.includeSpellIDs[12])
local player = aura.UnitLanes("player", settings, true)
assert(#player == 2 and player[1].enemyFilter == nil and player[2].filter == "HELPFUL|PLAYER")
assert(not player[2].candidates.maxDuration)
assert(#aura.UnitLanes("focus", { hideAuras = true }, true) == 0)
assert(aura.PlayerListLane(false).candidates.excludeSpellIDs[11] and aura.PlayerListLane(true).isDebuff)
local boss = aura.TileLanes(settings, { hostile = true, place = "boss" })
assert(#boss == 5 and boss[1].filter == "HARMFUL|PLAYER" and boss[5].filter == "HELPFUL|!RAID_PLAYER_DISPELLABLE")
settings.dispellableOnly = true
local party = aura.TileLanes(settings, { place = "party", dispelPlace = "TOP" })
assert(aura.PlacePolicy(party) == "processDispellable")
assert(party[3].kind == "dispels" and party[3].candidates.processedAuraType == 2)
assert(party[4].filter == "HELPFUL|PLAYER" and party[4].candidates.processedAuraType == 1)
party = aura.TileLanes(settings, { place = "party", dispelPlace = "TOP", editing = true })
assert(#party == 3 and aura.PlacePolicy(party) == "process")
assert(party[1].policy == "none" and party[2].policy == "process" and not party[3].candidates.processedAuraType)

local function newContainer()
    local container = { groups = {}, shown = true, updates = 0 }
    function container:AddAuraGroup(key, filter, options)
        assert(not self.groups[key], "The same group must be reused")
        self.groups[key] = { filter = filter, options = options }
    end
    function container:SetAuraGroupFilterString(key, filter) self.groups[key].filter = filter end
    function container:SetAuraGroupMaxFrameCount(key, count) self.groups[key].count = count end
    function container:SetAuraGroupCandidateFilters(key, filters) self.groups[key].filters = filters end
    function container:SetAuraGroupSortMethod(key, method, direction) self.groups[key].sort = { method, direction } end
    function container:SetAuraGroupLayout(key, layout) self.groups[key].layout = layout end
    function container:SetAuraGroupEnabled(key, enabled) self.groups[key].enabled = enabled end
    function container:SetAuraProcessingPolicy(policy, options) self.policy, self.policyOptions = policy, options end
    function container:IsShown() return self.shown end
    function container:UpdateAllAuras() self.updates = self.updates + 1 end
    return container
end

local container = newContainer()
aura.ApplyPolicy(container, "processDispellable")
assert(container.policy == 1 and container.policyOptions.displayOnlyDispellableDebuffs)
aura.ApplyPolicy(container, "process")
assert(container.policy == 1 and not next(container.policyOptions))
aura.ApplyPolicy(container, "none")
assert(container.policy == 0)

local groups, store = ns.AuraGroups, {}
local look = { font = setmetatable({}, { __index = { face = ns.GLOBAL_FONT } }) }
local oldSignature = groups.Sig(look)
ns.db.profile.fonts.global.face = "Alternate"
assert(groups.Sig(look) ~= oldSignature)
assert(groups.Sig({ 8, n = 10 }) == groups.Sig({ n = 10, 8 }))

groups.Begin(store)
local targetFrame = { Auras = { TOP = { container = container } } }
aura.Begin(targetFrame)
local locked = false
env.C_Secrets = { ShouldAurasBeSecret = function() return locked end }
local function setLook(size)
    return function(button)
        if locked then error("locked aura button") end
        button.size = size
    end
end
local keys = {}
for _, lane in ipairs(target) do
    local key = assert(groups.Add(container, store, lane.key, "small", aura.FilterFor(lane, "target"), {
        initializeFrame = setLook(16),
        candidateFilters = lane.candidates,
    }))
    keys[lane.key] = key
    aura.Track(targetFrame, container, key, lane)
end
groups.Finish(container, store)
aura.Done(targetFrame, "target")
assert(container.groups[keys.debuffs].filter == "HARMFUL|PLAYER" and container.groups[keys.purge].enabled)
enemy, visible = "hidden", false
aura.UnitChanged(targetFrame, "target", true)
assert(container.groups[keys.debuffs].filter == "HARMFUL" and not container.groups[keys.purge].enabled)
local distant = container.groups[keys.buffs].filters
assert(distant.maxDuration == nil and distant.excludeSpellIDs[11] and distant.excludeSpellIDs[12])
assert(container.updates == 1)
aura.UnitChanged(targetFrame, "target", true)
assert(container.updates == 1, "A repeated readable GUID does not rebuild visible aura containers")
guid, visible = "hidden", true
aura.UnitChanged(targetFrame, "target", true)
aura.UnitChanged(targetFrame, "target", true)
assert(container.updates == 3 and container.groups[keys.buffs].filters.maxDuration == 30)

local firstButton, pooledButton = {}, {}
local existing = container.groups[keys.buffs]
existing.options.initializeFrame(firstButton)
assert(firstButton.size == 16)
locked = true
groups.Begin(store)
assert(groups.Add(container, store, "buffs", "large", "HELPFUL", {
    initializeFrame = setLook(24), maxFrameCount = 5, sortMethod = 6, sortDirection = 2, layout = "new",
}) == keys.buffs)
assert(firstButton.size == 16 and existing.count == 5 and existing.sort[1] == 6 and existing.sort[2] == 2 and existing.layout == "new")
local retry = ui.timers[#ui.timers]
assert(retry and not retry.cancelled)
retry.callback()
assert(firstButton.size == 16 and not retry.cancelled)
locked = false
retry.callback()
assert(firstButton.size == 24 and retry.cancelled)
existing.options.initializeFrame(pooledButton)
assert(pooledButton.size == 24, "Later pooled buttons should receive the latest group style")
groups.Finish(container, store)
assert(existing.enabled and not container.groups[keys.purge].enabled and container.groups[keys.purge].count == 0)

ns.db.profile.auras = { hidden = { [99] = "target" } }
assert(hidden.For("target")[99] and not hidden.For("target")[11] and hidden.ShownFor("target") == nil)
do   -- (11-24) the dispel type icons follow the unit's side, with or without side filters
    local sides, attack, exists = {}, env.UnitCanAttack, env.UnitExists
    env.UnitExists = function() return true end
    ns.AuraLook = { DispelSide = function(_, side) sides[#sides + 1] = side end }
    env.UnitCanAttack = function() return true end
    aura.UpdateSide({}, "target")
    env.UnitCanAttack = function() return false end
    aura.UpdateSide({}, "target")
    assert(#sides == 2 and sides[1] == true and sides[2] == false)
    ns.AuraLook, env.UnitCanAttack, env.UnitExists = nil, attack, exists
end

print("PASS: aura filters, target changes, layout reuse and locked-button restyling")
