-- Client doubles for integration boundaries; state is outside frames so addon field searches stay realistic.
local M = { created = {}, state = {} }
local methods = {}
local function state(f) return assert(M.state[f], 'unknown region') end
function M.frame(kind, parent)
    local f = setmetatable({}, { __index = methods })
    M.state[f] = { kind = kind or 'Frame', parent = parent, shown = true, alpha = 1, level = 1,
        width = 150, height = 15, strata = 'MEDIUM', events = {}, scripts = {} }
    M.created[#M.created + 1] = f
    return f
end
function methods:GetObjectType() return state(self).kind end
function methods:GetParent() return state(self).parent end
function methods:SetParent(p) state(self).parent = p end
function methods:IsForbidden() return state(self).forbidden or false end
function methods:IsShown() return state(self).shown end
function methods:IsVisible()
    local s = state(self)
    return s.shown and (not s.parent or s.parent:IsVisible())
end
function methods:SetShown(v) state(self).shown = v end
function methods:Show() self:SetShown(true) end
function methods:Hide() self:SetShown(false) end
function methods:SetAlpha(v) state(self).alpha = v end
function methods:GetEffectiveAlpha()
    local s = state(self)
    return s.alpha * (s.parent and s.parent:GetEffectiveAlpha() or 1)
end
function methods:GetFrameLevel() return state(self).level end
function methods:SetFrameLevel(v) state(self).level = v end
function methods:GetFrameStrata() return state(self).strata end
function methods:SetFrameStrata(v) state(self).strata = v end
function methods:GetReverseFill() return state(self).reverse or false end
function methods:SetReverseFill(v) state(self).reverse = v end
function methods:GetWidth() return state(self).width end
function methods:GetHeight() return state(self).height end
function methods:SetWidth(v) state(self).width = v end
function methods:SetSize(w, h) state(self).width, state(self).height = w, h end
function methods:SetMinMaxValues(lo, hi) state(self).min, state(self).max = lo, hi end
function methods:SetValue(v) state(self).value = v end
function methods:CreateTexture() return M.frame('Texture', self) end
function methods:SetStatusBarTexture()
    local s = state(self)
    s.texture = s.texture or self:CreateTexture()
end
function methods:GetStatusBarTexture() return state(self).texture end
function methods:SetAllPoints(f) state(self).anchor = f end
function methods:ClearAllPoints() state(self).anchor = nil end
function methods:SetPoint(...) state(self).point = {...} end
function methods:RegisterEvent(e) state(self).events[e] = true end
function methods:UnregisterEvent(e) state(self).events[e] = nil end
function methods:UnregisterAllEvents() state(self).events = {} end
function methods:RegisterUnitEvent(e, ...) state(self).events[e] = {...} end
function methods:SetScript(e, fn) state(self).scripts[e] = fn end
for _, name in ipairs({'SetStatusBarColor', 'SetColorTexture', 'SetTexture', 'SetClipsChildren', 'SetScale'}) do
    methods[name] = function() end
end
return M
