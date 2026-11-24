local _, ns = ...
local L = ns.L

--------------------------------------------------
-- PROFILES AND EDIT MODE LAYOUTS
-- FlareUI's frames save their spots per Edit Mode layout name, and Blizzard's layout is per
-- character, so on a character using another layout a profile's frames sat at their defaults.
-- 1. Each profile remembers its home layout: the one its frames were last moved in. A layout with no
--    spot saved for a frame reads the home layout's (a metatable on that layout's store: reads fall
--    back, writes stay in it). Layouts that have their own spots keep them.
-- 2. After a profile switch, and on a character's first FlareUI login, a character not on the
--    profile's home layout is offered it: a switch (secure button, reloads) when this character
--    has it, otherwise where to get it (Copy Layout Code, Sync Blizz UI).
--------------------------------------------------
local LEM = LibStub("FlareEditMode")
ns.profileLayoutLoaded = true   -- LoadCheck.lua: a file added since the game started is missing

-- the layout name with the most saved spots, for profiles saved before home layouts were kept
local GUESS_ROOTS = { { "unitframes", "layouts" }, { "party", "layouts" }, { "resourcebars", "layouts" },
    { "objectivetracker", "layouts" } }
-- a layout's store with a spot in it (store.values holds per-layout Scales, not spots)
local function HasSpots(store)
    if type(store) ~= "table" then return false end
    for key in pairs(store) do
        if key ~= "values" then return true end
    end
    return false
end

local function GuessHome(p)
    local counts = {}
    for _, root in ipairs(GUESS_ROOTS) do
        local t = p[root[1]]
        local layouts = type(t) == "table" and rawget(t, root[2])
        if type(layouts) == "table" then
            for name, store in pairs(layouts) do
                if type(name) == "string" and HasSpots(store) then
                    counts[name] = (counts[name] or 0) + 1
                end
            end
        end
    end
    local best, most = nil, 0
    for name, n in pairs(counts) do
        if n > most then best, most = name, n end
    end
    return best
end

function ns.HomeLayout()
    local p = ns.db and ns.db.profile
    if not p then return nil end
    if type(p.homeLayout) ~= "string" then
        local guess = GuessHome(p)
        if guess then p.homeLayout = guess end
    end
    return p.homeLayout
end

-- The other layout in this store list with the most spots saved
local function FullestOther(layouts, name)
    local best, most = nil, 0
    for other, store in pairs(layouts) do
        if other ~= name and type(store) == "table" then
            local n = 0
            for _ in pairs(store) do n = n + 1 end
            if rawget(store, "values") then n = n - 1 end   -- (per-layout Scales, not spots)
            if n > most then best, most = store, n end
        end
    end
    return best
end

-- A layout's store (layouts[name], made if missing). What it lacks is read from the first of these that has
-- it: the home layout, the homes before it (newest first), the fullest other layout. Moving one frame in
-- a second layout makes it the home, so with the home alone every other frame of a third layout jumped to
-- its default (11-24). Each is read with rawget, so layouts reading each other never loop. Scales
-- ("values") stay a layout's own.
local function Spot(p, layouts, name, key)
    local function From(other)
        local store = type(other) == "string" and other ~= name and rawget(layouts, other)
        if type(store) == "table" then return rawget(store, key) end
    end
    local value = From(p.homeLayout)
    if value ~= nil then return value end
    for _, past in ipairs(type(p.homeLayoutPast) == "table" and p.homeLayoutPast or {}) do
        value = From(past)
        if value ~= nil then return value end
    end
    value = From(p.homeLayoutPrev)   -- (saved before the list was)
    if value ~= nil then return value end
    local fullest = FullestOther(layouts, name)
    return fullest and rawget(fullest, key)
end

function ns.LayoutHome(layouts, name)
    layouts[name] = layouts[name] or {}
    local store = layouts[name]
    ns.HomeLayout()   -- (guessed for a profile saved before homes were kept)
    local p = ns.db and ns.db.profile
    local meta = getmetatable(store)
    if not (type(meta) == "table" and meta.flareLayouts == layouts and meta.flareProfile == p) then
        setmetatable(store, p and { flareLayouts = layouts, flareProfile = p, __index = function(_, key)
            if key ~= "values" then return Spot(p, layouts, name, key) end
        end } or nil)
    end
    return store
end

-- every FlareUI frame moved in Edit Mode: that layout is the profile's home
local PAST_HOMES = 10
LEM.onAnyMove = function(layoutName)
    local p = ns.db and ns.db.profile
    if not (p and type(layoutName) == "string") then return end
    local old = ns.HomeLayout()
    if old and old ~= layoutName then
        -- every home there was, newest first
        local past = { old }
        local before = type(p.homeLayoutPast) == "table" and p.homeLayoutPast or { p.homeLayoutPrev }
        for _, name in ipairs(before) do
            if name ~= old and name ~= layoutName and #past < PAST_HOMES then past[#past + 1] = name end
        end
        p.homeLayoutPast, p.homeLayoutPrev = past, old
    end
    p.homeLayout = layoutName
end

--------------------------------------------------
-- VALUES PER LAYOUT (so two layouts at two UI scales can keep two frame Scales)
-- A frame's Edit Mode value (its Scale) is saved in the layout's own store, beside its spot:
-- store.values[key]. Unlike spots these never follow the home layout: a layout with no value of its
-- own uses the frame's base, the value it had before any layout kept its own (saved the first time one
-- is). So setting Scale in one layout never changes another, and nothing changes until a player sets it.
--------------------------------------------------
-- the layout's own value for key, else fallback
function ns.LayoutValue(layouts, name, key, fallback)
    local store = type(layouts) == "table" and type(name) == "string" and rawget(layouts, name)
    local values = type(store) == "table" and rawget(store, "values")
    local value = type(values) == "table" and values[key]
    if value == nil then return fallback end
    return value
end

function ns.SetLayoutValue(layouts, name, key, value)
    if type(layouts) ~= "table" or type(name) ~= "string" then return end
    local store = ns.LayoutHome(layouts, name)
    -- (rawget: the home layout's values, read through the store's metatable, are never written)
    local values = rawget(store, "values")
    if type(values) ~= "table" then
        values = {}
        rawset(store, "values", values)
    end
    values[key] = value
end

-- Forever Style's Scale (settings.plateScale, with the ring size and height it sets) per layout.
-- settings.plateScaleBase: the Scale before any layout kept its own.
function ns.SetLayoutPlateScale(layouts, name, key, settings, value, default)
    if not (settings and ns.UFRing) then return end
    if settings.plateScaleBase == nil then settings.plateScaleBase = settings.plateScale or default or value end
    ns.SetLayoutValue(layouts, name, key, value)
    ns.UFRing.ApplyPlateScale(settings, value)
end

-- The layout's Scale on the settings; true when it changed them (the frame then needs laying out)
function ns.ApplyLayoutPlateScale(layouts, name, key, settings)
    if not (settings and ns.UFRing) then return false end
    local want = tonumber(ns.LayoutValue(layouts, name, key, settings.plateScaleBase))
    if not want or want == settings.plateScale then return false end
    ns.UFRing.ApplyPlateScale(settings, want)
    return true
end

--------------------------------------------------
-- THE OFFER
--------------------------------------------------
local function ActiveLayout()
    local manager = _G.EditModeManagerFrame
    local info = manager and manager.layoutInfo
    if not (info and info.layouts and info.activeLayout) then return nil end
    return info.layouts[info.activeLayout], info
end

-- the home layout's index in Edit Mode's list: the account's first, then this character's
local function HomeIndex(info, home)
    local found
    for index, layout in ipairs(info.layouts) do
        if layout.layoutName == home then
            if layout.layoutType == Enum.EditModeLayoutType.Account then return index, layout end
            found = found or index
        end
    end
    if found then return found, info.layouts[found] end
end

-- (the texts take two names: set as each dialog is shown)
local SWITCH_TEXT = L["The profile |cffffff00%s|r was set up on the Edit Mode layout |cffffff00%s|r. Switch to it?"]
    .. "\n\n" .. L["This reloads your interface."]
local MISSING_TEXT = L["The profile |cffffff00%s|r was set up on the Edit Mode layout |cffffff00%s|r, which this character doesn't have. FlareUI's frames follow the profile anyway. For Blizzard's bars, export that layout in Edit Mode on the other character, or turn on Sync Blizz UI (General page)."]
-- FlareUI's own layout missing: its code is one click away
local MISSING_FLAREUI_TEXT = L["The profile |cffffff00%s|r was set up on the Edit Mode layout |cffffff00%s|r, which this character doesn't have. FlareUI's frames follow the profile anyway. For Blizzard's bars, copy FlareUI's layout code and import it in Edit Mode (Layout > Import)."]

ns.Dialogs["FLAREUI_PROFILE_LAYOUT"] = {
    button1 = L["Switch"],
    button2 = L["Not Now"],
    macro = function(data) return "/run C_EditMode.SetActiveLayout(" .. data.index .. ")\n/reload" end,
    -- Quality of Life's layout-per-mode memory takes this layout, so it doesn't offer the old one back
    OnMacro = function(data)
        if ns.Tweaks and ns.Tweaks.AdoptSyncedLayout and data then ns.Tweaks.AdoptSyncedLayout(data.layout) end
    end,
    hideOnEscape = true,
    padSecure = true,
}

ns.Dialogs["FLAREUI_PROFILE_LAYOUT_MISSING"] = {
    button1 = OKAY or "Okay",
    hideOnEscape = true,
}
ns.Dialogs["FLAREUI_PROFILE_LAYOUT_MISSING_FLAREUI"] = {
    button1 = L["Copy Layout Code"],
    button2 = OKAY or "Okay",
    OnAccept = function() if ns.EditModeLayout then ns.EditModeLayout.Copy() end end,
    hideOnEscape = true,
}

local function Offer()
    local char = ns.CharDB()
    if not char.offerLayout then return end
    local home = ns.HomeLayout()
    local active, info = ActiveLayout()
    if not active then return end   -- Edit Mode isn't ready: the next update tries again
    char.offerLayout = nil
    if not home or active.layoutName == home then return end
    local profile = ns.db:GetCurrentProfile()
    local index, layout = HomeIndex(info, home)
    if index then
        ns.Dialogs.FLAREUI_PROFILE_LAYOUT.text = SWITCH_TEXT:format(profile, home)
        ns.ShowDialog("FLAREUI_PROFILE_LAYOUT", nil, { index = index, layout = layout })
    else
        local flare = type(home) == "string" and home:lower():find("flareui", 1, true)
            and ns.EditModeLayout and ns.EditModeLayout.Has()
        local key = flare and "FLAREUI_PROFILE_LAYOUT_MISSING_FLAREUI" or "FLAREUI_PROFILE_LAYOUT_MISSING"
        ns.Dialogs[key].text = (flare and MISSING_FLAREUI_TEXT or MISSING_TEXT):format(profile, home)
        ns.ShowDialog(key)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function()
    if not (ns.db and ns.CharDB().offerLayout) then return end
    if InCombatLockdown() then return end   -- after the fight
    -- after the layout-per-mode check (Tweaks), and not from inside Edit Mode's own update
    C_Timer.After(2, function() if not InCombatLockdown() then Offer() end end)
end)
