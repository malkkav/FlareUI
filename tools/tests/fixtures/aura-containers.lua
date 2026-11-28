-- Record the settings FlareUI passes to Blizzard's AuraContainer and AuraButton.
-- Tests can run a group's initializer by calling the stored opts.initializeFrame.
return function(env)
    local Widget = getmetatable(env.UIParent)
    env.AnchorUtil = { FlowLayoutAxis = { Horizontal = 1 }, FlowDirection = { Left = -1, Right = 1, Down = -1, Up = 1 } }
    env.AuraContainerSortMethod = {
        Default = 1, AuraInstanceIDOnly = 2, Expiration = 3, ExpirationOnly = 4, Name = 5, NameOnly = 6,
    }
    env.AuraContainerSortDirection = { Normal = 1, Reverse = 2 }
    env.CustomAuraContainerGroupDefaultOptions = { maxFrameCount = 32, sortMethod = 1, sortDirection = 1 }
    env.CustomAuraContainerAuraProcessingPolicy = { None = 0, ProcessAura = 1 }

    for method, property in pairs({
        SetFlowLayoutAxis = "axis", SetFlowLayoutAnchorPoint = "corner", SetFlowLayoutGrowthDirection = "growth",
        SetFlowLayoutMaximumLineSize = "lineSize", SetFlowLayoutPadding = "padding", SetUnit = "unit",
    }) do
        Widget[method] = function(self, ...) self[property] = { ... } end
    end
    function Widget:AddAuraGroup(key, filter, opts)
        self.groups = self.groups or {}
        assert(not self.groups[key])
        self.groups[key] = { filter = filter, opts = opts, enabled = true, candidates = opts.candidateFilters,
            layout = opts.layout, maxFrameCount = opts.maxFrameCount, sortMethod = opts.sortMethod }
    end
    for method, property in pairs({
        SetAuraGroupFilterString = "filter", SetAuraGroupMaxFrameCount = "maxFrameCount",
        SetAuraGroupCandidateFilters = "candidates", SetAuraGroupLayout = "layout",
        SetAuraGroupSortMethod = "sortMethod", SetAuraGroupEnabled = "enabled",
    }) do
        Widget[method] = function(self, key, value) self.groups[key][property] = value end
    end
    function Widget:UpdateAllAuras() self.updates = (self.updates or 0) + 1 end
    function Widget:SetDurationText(text) self.duration = text end
    function Widget:SetDurationCooldown(cd) self.auraCooldown = cd end
    function Widget:SetIcon(icon) self.auraIcon = icon end
    function Widget:SetApplicationCount(count) self.auraCount = count end
    function Widget:SetCancelAuraButtons(click) self.cancelClick = click end
    function Widget:ClearDispelTypeTextures() self.dispelTextures = {} end
    function Widget:AddDispelTypeTexture(texture, opts) self.dispelTextures[texture] = opts end
    function Widget:ClearAuraShownAnimations() self.arrival = nil end
    function Widget:AddAuraShownAnimation(anim) self.arrival = anim end

    function Widget:SetEditModePreviewEnabled(on) self.editPreview = on end
    function Widget:SetAuraProcessingPolicy(policy, opts) self.auraPolicy, self.auraOptions = policy, opts end
    function Widget:AddAuraSlot(key, filter, opts)
        self.auraSlots = self.auraSlots or {}
        assert(not self.auraSlots[key])
        local slot = env.CreateFrame("Frame", nil, self)
        self.auraSlots[key] = { frame = slot, filter = filter, opts = opts, enabled = true }
        if opts.initializeFrame then opts.initializeFrame(slot) end
        return slot
    end
    function Widget:SetAuraSlotEnabled(key, on) self.auraSlots[key].enabled = on end
end
