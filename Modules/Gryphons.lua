local _, ns = ...

--------------------------------------------------
-- GRYPHONS (Quality of Life > Hide Clutter > Gryphons, and each gryphon's Edit Mode Scale)
-- The main bar's two end caps (MainActionBar.EndCaps) are Blizzard's, not FlareUI's action bars, so
-- everything about them lives here, in Quality of Life, and works with Action Bars off (Malkkav 11-26):
-- * Behind Bars: the caps' container under every bar instead of over the button text
-- * Hidden: Visibility.lua hides them (Visibility.HidesOn asks this module)
-- * Scale: a 50-200% slider in each gryphon's Edit Mode dialog (Blizzard gives them none)
-- * the end caps come back with bar 1 after Alt+Z or a cinematic (Blizzard's UpdateEndCaps keeps them
--   hidden while its Hide Bar Art is on)
-- Saved where they always were (actionbars.gryphonsBehind, actionbars.capScale,
-- visibility.hideEndCaps), so nobody's setup changes.
--------------------------------------------------
local G = {}
ns.Gryphons = G

local function QoLOn()
    local db = ns.db and ns.db.profile and ns.db.profile.tweaks
    return db and db.enabled ~= false or false
end
G.On = QoLOn
local function BarDB() return ns.db and ns.db.profile and ns.db.profile.actionbars end

-- button text draws at frame level 500: the caps' container goes above it. Behind Bars puts it under
-- every bar instead (the bars sit at level 50 and up in the same strata).
G.LEVEL_ABOVE, G.LEVEL_BEHIND = 501, 1
function G.UpdateLayer()
    local caps = _G.MainActionBar and _G.MainActionBar.EndCaps
    if not caps or not caps.SetFrameLevel then return end
    local db = BarDB()
    local behind = QoLOn() and db and db.gryphonsBehind
    if behind then
        caps:SetFrameLevel(G.LEVEL_BEHIND)
        G.layerSet = true
    elseif caps:GetFrameLevel() < G.LEVEL_ABOVE and (G.layerSet or (db and db.enabled)) then
        -- (back above the text: only after FlareUI moved it, or with FlareUI's bars, whose text sits at 500)
        caps:SetFrameLevel(G.LEVEL_ABOVE)
        G.layerSet = nil
    end
    -- bar 1's page number and arrows (level 100 in Blizzard's XML) stay above the gryphons, or the
    -- left one covers them; their arrow buttons go one higher
    local pager = _G.MainActionBar.ActionBarPageNumber
    if pager and pager.SetFrameLevel then
        local level = math.max(pager:GetFrameLevel(), caps:GetFrameLevel() + 1)
        pager:SetFrameLevel(level)
        for _, button in ipairs({ pager.UpButton, pager.DownButton }) do
            if button and button.SetFrameLevel then button:SetFrameLevel(level + 1) end
        end
    end
end

-- On Forever each gryphon is its own Edit Mode system, but the main bar's OnShow still runs
-- UpdateEndCaps(hideBarArt): with Hide Bar Art on, that would keep the container hidden after Alt+Z
-- or a cinematic. It is shown again with the bar; each gryphon keeps its own visibility.
local function KeepWithBar(bar)
    local caps = bar and bar.EndCaps
    if not QoLOn() or not caps or caps:IsShown() or not bar:IsVisible() then return end
    if ns.IsGamepadUI and ns.IsGamepadUI() then return end   -- Blizzard keeps them hidden there
    local faction = UnitFactionGroup("player")
    if not faction or faction == "Neutral" then return end
    if InCombatLockdown() and caps:IsProtected() then return end
    caps:Show()
end
function G.HookEndCaps()
    local bar = _G.MainActionBar
    if not bar or bar.FlareUI_EndCapsHooked or type(bar.UpdateEndCaps) ~= "function" then return end
    if _G.MAIN_ACTION_BAR_MANAGE_END_CAPS ~= false then return end   -- Retail-style bars manage them
    bar.FlareUI_EndCapsHooked = true
    hooksecurefunc(bar, "UpdateEndCaps", KeepWithBar)
    KeepWithBar(bar)
end

-- SCALE: 50-200% on top of bar 1's scale (they sit inside it). 100% never touches a gryphon; out of a
-- fight only.
G.CAP_FRAMES = { capLeft = "LeftEndCap", capRight = "RightEndCap" }
function G.ApplyScales()
    local db = BarDB()
    local caps = _G.MainActionBar and _G.MainActionBar.EndCaps
    if not (db and caps) then return end
    if InCombatLockdown() then G.pendingScale = true return end
    G.pendingScale = nil
    local sizes = QoLOn() and db.capScale or {}
    for key, field in pairs(G.CAP_FRAMES) do
        local cap = caps[field]
        local scale = (sizes[key] or 100) / 100
        if cap and not cap:IsForbidden() and (scale ~= 1 or cap.FlareUI_Scaled) then
            -- its place on screen kept: at login Edit Mode places it before this scale, which
            -- then stretched its offsets too
            ns.SetSystemScale(cap, scale)
            cap.FlareUI_Scaled = scale ~= 1 or nil
        end
    end
end

-- the Scale row in each gryphon's dialog (Visibility.lua puts it above Fading)
function G.SizeSetting(key)
    local LEM = LibStub("FlareEditMode")
    return {
        name = ns.L["Scale"], kind = LEM.SettingType.Slider, default = 100, minValue = 50, maxValue = 200, valueStep = 5,
        formatter = function(value) return value end,   -- plain: "100%" clips the value box
        get = function() local db = BarDB(); return db and db.capScale and db.capScale[key] or 100 end,
        set = function(_, value)
            local db = BarDB()
            if not db then return end
            db.capScale = db.capScale or {}
            db.capScale[key] = value ~= 100 and value or nil
            G.ApplyScales()
        end,
        -- (with Quality of Life off nothing applies it)
        hidden = function() return not QoLOn() end,
    }
end

function G.Refresh()
    if InCombatLockdown() then G.pending = true return end
    G.pending = nil
    G.HookEndCaps()
    G.UpdateLayer()
    G.ApplyScales()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
events:SetScript("OnEvent", function(_, event)
    if not ns.db then return end
    if event == "PLAYER_REGEN_ENABLED" then
        if G.pending then G.Refresh() elseif G.pendingScale then G.ApplyScales() end
        return
    end
    G.Refresh()
end)
