local _, ns = ...
local L = ns.L

--------------------------------------------------
-- PROFILES AND EDIT MODE LAYOUTS (11-11, a player's report: a profile loaded on another character
-- "changed nothing")
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

-- the layout name with the most saved spots, for profiles saved before home layouts were kept
local GUESS_ROOTS = { { "unitframes", "layouts" }, { "party", "layouts" }, { "resourcebars", "layouts" },
    { "objectivetracker", "layouts" } }
local function GuessHome(p)
    local counts = {}
    for _, root in ipairs(GUESS_ROOTS) do
        local t = p[root[1]]
        local layouts = type(t) == "table" and rawget(t, root[2])
        if type(layouts) == "table" then
            for name, store in pairs(layouts) do
                if type(name) == "string" and type(store) == "table" and next(store) then
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

-- A layout's store (layouts[name], made if missing), reading the home layout's for what it lacks
local fallbackMeta = setmetatable({}, { __mode = "k" })   -- home store -> its metatable
function ns.LayoutHome(layouts, name)
    layouts[name] = layouts[name] or {}
    local store = layouts[name]
    local home = ns.HomeLayout()
    local from = home and home ~= name and rawget(layouts, home)
    if type(from) == "table" then
        local meta = fallbackMeta[from]
        if not meta then meta = { __index = from }; fallbackMeta[from] = meta end
        setmetatable(store, meta)
    else
        setmetatable(store, nil)
    end
    return store
end

-- every FlareUI frame moved in Edit Mode: that layout is the profile's home
LEM.onAnyMove = function(layoutName)
    local p = ns.db and ns.db.profile
    if p and type(layoutName) == "string" then p.homeLayout = layoutName end
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
local MISSING_TEXT = L["The profile |cffffff00%s|r was set up on the Edit Mode layout |cffffff00%s|r, which this character doesn't have. FlareUI's frames follow the profile anyway. For Blizzard's bars, copy that layout from the other character (About > Copy Layout Code) or turn on Sync Blizz UI (Settings page)."]

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
        ns.Dialogs.FLAREUI_PROFILE_LAYOUT_MISSING.text = MISSING_TEXT:format(profile, home)
        ns.ShowDialog("FLAREUI_PROFILE_LAYOUT_MISSING")
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
