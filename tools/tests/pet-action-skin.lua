local H = dofile('tools/tests/perf-helpers.lua')
local source = H.read('Modules/ActionBars.lua')

H.load([[
local combat = false
local function InCombatLockdown() return combat end
local ActionBars = { LiftCountdown = function() end }
local FLARE_BORDER_OUT, FLARE_BORDER_EDGE = 0, 16
local ns = { BORDER_COLOR = { r = 1, g = 1, b = 1 }, BorderEdgeSize = function(_, size) return size end }
local function LibStub() return { Fetch = function() return 'border' end } end

local function Texture(parent)
    local texture = { parent = parent, shown = false, alpha = 1 }
    function texture:GetParent() return self.parent end
    function texture:SetParent(frame) self.parent = frame end
    function texture:SetAlpha(alpha) self.alpha = alpha end
    function texture:GetAlpha() return self.alpha end
    function texture:SetShown(shown) self.shown = not not shown end
    function texture:Show() self.shown = true end
    function texture:Hide() self.shown = false end
    function texture:SetAtlas(atlas) self.atlas = atlas end
    function texture:SetTexture(path) self.path = path end
    function texture:SetBlendMode(mode) self.blend = mode end
    function texture:SetVertexColor(r, g, b, a) self.color = { r, g, b, a } end
    function texture:SetAllPoints() end
    return texture
end
local function Frame(parent)
    local frame = { parent = parent, level = parent and parent.level + 1 or 70, shown = true, textures = {} }
    function frame:GetFrameLevel() return self.level end
    function frame:SetFrameLevel(level) self.level = level end
    function frame:IsShown() return self.shown end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:SetAlpha(alpha) self.alpha = alpha end
    function frame:ClearAllPoints() end
    function frame:SetAllPoints() end
    function frame:SetPoint() end
    function frame:SetBackdrop() end
    function frame:SetBackdropBorderColor() end
    function frame:CreateTexture()
        assert(not combat, 'pet indicators must be created outside combat')
        local texture = Texture(self)
        self.textures[#self.textures + 1] = texture
        return texture
    end
    function frame:CreateAnimationGroup()
        local group = { playing = false }
        function group:SetLooping() end
        function group:Stop() self.playing = false end
        function group:Play() self.playing = true end
        function group:IsPlaying() return self.playing end
        function group:CreateAnimation()
            return { SetFromAlpha = function() end, SetToAlpha = function() end,
                SetDuration = function() end, SetSmoothing = function() end }
        end
        return group
    end
    return frame
end
local function CreateFrame(_, _, parent)
    assert(not combat, 'pet indicator frames must be created outside combat')
    return Frame(parent)
end
local function hooksecurefunc(object, name, callback)
    local original = object[name]
    object[name] = function(self, ...)
        original(self, ...)
        callback(self, ...)
    end
end
local function Button(id)
    local button = Frame()
    button.id, button.checked = id, false
    button.icon = {}
    button.NormalTexture = Texture(button)
    button.CheckedTexture = Texture(button)
    button.Flash = Texture(button)
    function button:GetID() return self.id end
    -- The reported client loses the association when this native texture is reparented.
    function button:GetCheckedTexture()
        return self.CheckedTexture:GetParent() == self and self.CheckedTexture or nil
    end
    function button:GetChecked() return self.checked end
    function button:SetChecked(checked) self.checked = not not checked end
    -- The relevant operations in Blizzard's UpdateButtonState, including its alpha change.
    function button:UpdatePetState(active, attack)
        if active then self:GetCheckedTexture():SetAlpha(attack and 0.5 or 1) end
        self:SetChecked(active)
    end
    return button
end
local pet = Button(1)
_G.PetActionBar = { actionButtons = { pet } }
]] .. H.section(source, 'function ActionBars.UpdatePetChecked(button)', '\n-- every bar\'s buttons:') .. [[
local db = { enabled = true, activeHighlight = true }
local ACTIVE_COLOR = { 1, 0.82, 0.25 }
local function GetBarConfig() return db end
local function IsActiveButton(button) return button:GetChecked() end
local function HoldsQueuedAttack() return false end
]] .. H.section(source, 'local function ActiveOverlay(button)', '\nlocal activeButtons =') .. [[
local function visibleIndicator(button)
    local border = button.FlareUI_Border
    if not border or not border.shown then return false end
    local indicator = button.FlareUI_PetState or border
    for _, texture in ipairs(indicator.textures) do
        if texture.shown and texture.alpha > 0 then return true end
    end
    return false
end
local function visibleIndicatorCount(button)
    local border = button.FlareUI_Border
    if not border or not border.shown then return 0 end
    local indicator = button.FlareUI_PetState or border
    local count = 0
    for _, texture in ipairs(indicator.textures) do
        if texture.shown and texture.alpha > 0 then count = count + 1 end
    end
    return count
end
local function indicatorAlpha(button)
    local indicator = button.FlareUI_PetState or button.FlareUI_Border
    for _, texture in ipairs(indicator.textures) do
        if texture.shown then return texture.alpha end
    end
end

pet:UpdatePetState(true, false)
SkinBorder(pet, true)
local ok, err = pcall(pet.UpdatePetState, pet, true, false)
assert(ok, 'skinning must not break Blizzard GetCheckedTexture: ' .. tostring(err))
assert(pet:GetCheckedTexture() == pet.CheckedTexture, 'the native checked texture must stay associated with its button')
assert(pet.Flash:GetParent() == pet, 'the native attack flash must remain on its button')
assert(visibleIndicator(pet), 'a selected pet command must remain visible over the skin')
assert(visibleIndicatorCount(pet) >= 2, 'a selected pet command needs an icon light as well as an outline')
UpdateActive(pet)
local activeHighlight = pet.FlareUI_Active
assert(activeHighlight and activeHighlight:IsShown(), 'the optional active highlight should be shown when enabled')
assert(pet.FlareUI_PetState and pet.FlareUI_PetState:GetFrameLevel() > activeHighlight:GetFrameLevel(),
    'pet command state must be above the optional active highlight when it is enabled')
db.activeHighlight = false
UpdateActive(pet)
assert(not activeHighlight:IsShown() and visibleIndicator(pet),
    'turning the optional active highlight off must leave the pet command state visible')
db.activeHighlight = true
UpdateActive(pet)
assert(activeHighlight:IsShown() and visibleIndicator(pet),
    'turning the optional active highlight back on must leave the pet command state visible')

pet:UpdatePetState(false, false)
assert(not visibleIndicator(pet), 'an unselected command must not stay highlighted')
pet:UpdatePetState(true, true)
assert(visibleIndicator(pet) and pet:GetCheckedTexture():GetAlpha() == 0.5, 'pet attack must remain visible with Blizzard alpha intact')
assert(indicatorAlpha(pet) == 0.5, 'the new indicator must follow Blizzard attack alpha')
pet:UpdatePetState(true, false)
assert(indicatorAlpha(pet) == 1, 'the indicator must brighten again for a non-attack command')
SkinBorder(pet, true) -- Blizzard may refresh button art repeatedly.
SkinBorder(pet, false)
assert(not visibleIndicator(pet) and pet:GetCheckedTexture() == pet.CheckedTexture, 'disabling the skin must leave the native state intact')
pet:UpdatePetState(false, false)
pet:UpdatePetState(true, false)
SkinBorder(pet, true)
assert(visibleIndicator(pet), 're-enabling the skin must reflect the current pet command')
combat = true
pet:UpdatePetState(false, false)
assert(not visibleIndicator(pet), 'the indicator must clear when the pet state changes in combat')
pet:UpdatePetState(true, true)
SkinBorder(pet, true)
assert(visibleIndicator(pet), 'an existing indicator must continue to update in combat')
combat = false

local ordinary = Button(1)
SkinBorder(ordinary, true)
assert(not visibleIndicator(ordinary), 'ordinary action buttons must not receive pet command indicators')

local pet2 = Button(2)
_G.PetActionBar.actionButtons[2] = pet2
combat = true
SkinBorder(pet2, true)
assert(ActionBars._pendingRefresh, 'creating the pet indicator in combat must wait until combat ends')
assert(pet2:GetCheckedTexture() == pet2.CheckedTexture, 'combat must preserve the native checked texture')
combat = false
SkinBorder(pet2, true)
pet2:UpdatePetState(true, false)
assert(visibleIndicator(pet2), 'the deferred update must restore the pet command indicator')
]])

print('PASS: pet skin preserves the native checked texture and shows command state across toggles and combat deferral')
