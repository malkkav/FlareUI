local _, ns = ...

--------------------------------------------------
-- 1. UPVALUES
--------------------------------------------------
local wipe = wipe
local table_insert = table.insert
local ipairs = ipairs

-- State (default to bar1 since player/pet/minimap/tracker are excluded from fading)
local CurrentFrame = "bar1"

--------------------------------------------------
-- 2. DATA DEFINITIONS
--------------------------------------------------
local FRAMES_LIST = {
    -- Bars
    bar1 = "Action Bar 1", bar2 = "Action Bar 2", bar3 = "Action Bar 3",
    bar4 = "Action Bar 4", bar5 = "Action Bar 5", bar6 = "Action Bar 6",
    bar7 = "Action Bar 7", bar8 = "Action Bar 8",
    pet = "Pet Bar", stance = "Stance Bar",

    -- UI
    player = "Player Frame", petFrame = "Pet Frame",
    minimap = "Minimap", tracker = "Quest Tracker",
    menu = "Micro Menu", bags = "Bag Bar",
    xp = "XP Bar", rep = "Reputation Bar",
}

local MASTER_SORT_ORDER = {
    "player", "petFrame",
    "bar1", "bar2", "bar3", "bar4", "bar5", "bar6", "bar7", "bar8",
    "pet", "stance",
    "minimap", "tracker",
    "menu", "bags", "xp", "rep"
}

-- Dynamic list passed to AceConfig
local CURRENT_SORT_ORDER = {}

-- Map keys to Global Hiding settings
local HIDE_DEPENDENCIES = {
    pet = "hidePetBar",
    stance = "hideStanceBar",
    menu = "hideMicroMenu",
    bags = "hideBagBar",
}

--------------------------------------------------
-- 3. HELPERS
--------------------------------------------------
local function RefreshVis()
    if ns.Visibility and ns.Visibility.Refresh then ns.Visibility:Refresh() end
end

local function SetAndReload(key, val)
    ns.db.profile.visibility[key] = val

    -- Safety: If hiding the currently selected frame, reset to Player
    for frameKey, hideKey in pairs(HIDE_DEPENDENCIES) do
        if hideKey == key and val == true and CurrentFrame == frameKey then
            CurrentFrame = "bar1"
        end
    end

    RefreshVis()
    ns.ShowDialog("FLAREUI_RELOAD")
end

local FADING_EXCLUDED = { player = true, petFrame = true, minimap = true, tracker = true }

local function GetVisibleFrameList()
    local t = {}
    wipe(CURRENT_SORT_ORDER)

    local fcm = ns.db.profile.fcm

    for _, key in ipairs(MASTER_SORT_ORDER) do
        if FADING_EXCLUDED[key] then
            -- Skip frames excluded from fading tab
        else
            local isFCMBar = fcm and fcm.bars[key] and fcm.bars[key].enabled
            if not isFCMBar then
                local hideKey = HIDE_DEPENDENCIES[key]
                if not hideKey or not ns.db.profile.visibility[hideKey] then
                    t[key] = FRAMES_LIST[key]
                    table_insert(CURRENT_SORT_ORDER, key)
                end
            end
        end
    end
    -- Reset selection if current frame was excluded from fading
    if FADING_EXCLUDED[CurrentFrame] or not t[CurrentFrame] then
        CurrentFrame = CURRENT_SORT_ORDER[1] or "bar1"
    end
    return t
end

-- Dynamic Accessors
local function GetVal(info)
    return ns.db.profile.visibility[CurrentFrame][info[#info]]
end

local function SetVal(info, val)
    ns.db.profile.visibility[CurrentFrame][info[#info]] = val
    RefreshVis()
end

local function IsToggleDisabled()
    local dep = HIDE_DEPENDENCIES[CurrentFrame]
    if dep and ns.db.profile.visibility[dep] then return true end
    return false
end

local function IsOptionsDisabled()
    if IsToggleDisabled() then return true end
    return not ns.db.profile.visibility[CurrentFrame].enableFade
end

--------------------------------------------------
-- 4. VISIBILITY TAB (Action Bars > Visibility)
-- Fading rules per frame first, then everything that is hidden for good.
--------------------------------------------------
local hideToggle = function(key, label, order)
    return {
        type = "toggle", name = label, order = order,
        get = function() return ns.db.profile.visibility[key] end,
        set = function(_, val) SetAndReload(key, val) end,
    }
end

ns.Options.args.actionbars.args.visibilityTab = {
    type = "group", name = "Visibility", order = 20,
    args = {
        selector = {
            type = "select", name = "Select Frame to Edit",
            order = 10,
            width = 1.5,
            style = "dropdown",
            values = GetVisibleFrameList,
            sorting = CURRENT_SORT_ORDER,
            get = function() return CurrentFrame end,
            set = function(_, val) CurrentFrame = val end,
        },

        header = { type = "header", name = "Fading Rules", order = 20 },

        enableFade = {
            type = "toggle", name = "Enable Fading", order = 30, width = "full",
            disabled = IsToggleDisabled,
            get = GetVal, set = SetVal
        },

        condGroup = {
            type = "group", name = "Show Conditions", order = 40, inline = true,
            disabled = IsOptionsDisabled,
            args = {
                condMouseover = { type = "toggle", name = "Mouseover", width = 0.7, order = 10, get = GetVal, set = SetVal },
                spacer1 = { type = "description", name = "", width = 0.1, order = 11 },
                condCombat    = { type = "toggle", name = "Combat", width = 0.7, order = 20, get = GetVal, set = SetVal },
                spacer2 = { type = "description", name = "", width = 0.1, order = 21 },
                condTarget    = { type = "toggle", name = "Target", width = 0.6, order = 30, get = GetVal, set = SetVal },
                spacer3 = { type = "description", name = "", width = 0.1, order = 31 },
                condHarm      = { type = "toggle", name = "Attackable", width = 0.7, order = 40, get = GetVal, set = SetVal },
                spacer4 = { type = "description", name = "", width = 0.1, order = 41 },
                condVehicle   = { type = "toggle", name = "Mounted / Vehicle", width = 0.9, order = 50, get = GetVal, set = SetVal },
            }
        },

        settingsGroup = {
            type = "group", name = "Animation Settings", order = 50, inline = true,
            disabled = IsOptionsDisabled,
            args = {
                alphaMin      = { type = "range", name = "Min Alpha", min = 0, max = 1, step = 0.05, order = 10, get = GetVal, set = SetVal },
                spacer1       = { type = "description", name = "", width = 0.1, order = 11 },
                alphaMax      = { type = "range", name = "Max Alpha", min = 0, max = 1, step = 0.05, order = 20, get = GetVal, set = SetVal },

                break1        = { type = "description", name = " ", order = 25, width = "full" },

                fadeInSpeed   = { type = "range", name = "Fade In Speed", min = 0, max = 2, step = 0.1, order = 30, get = GetVal, set = SetVal },
                spacer2       = { type = "description", name = "", width = 0.1, order = 31 },
                fadeOutSpeed  = { type = "range", name = "Fade Out Speed", min = 0, max = 2, step = 0.1, order = 40, get = GetVal, set = SetVal },
                spacer3       = { type = "description", name = "", width = 0.1, order = 41 },
                fadeOutDelay  = { type = "range", name = "Fade Delay", min = 0, max = 5, step = 0.1, order = 50, get = GetVal, set = SetVal },
            }
        },

        linkGroup = {
            type = "group", name = "Advanced", order = 60, inline = true,
            disabled = IsOptionsDisabled,
            args = {
                faderGroup    = { type = "input", name = "Link Group", desc = "Type a name here (e.g., 'MainBars'). Any frames sharing this name will fade together.", order = 10, get = GetVal, set = SetVal }
            }
        },

        hidingGroup = {
            type = "group", name = "Permanent Hiding", order = 70, inline = true,
            args = {
                hideMicroMenu   = hideToggle("hideMicroMenu", "Micro Menu", 10),
                spacer1 = { type = "description", name = "", width = 0.1, order = 11 },
                hideBagBar      = hideToggle("hideBagBar", "Bag Bar", 20),
                spacer2 = { type = "description", name = "", width = 0.1, order = 21 },
                hidePetBar      = hideToggle("hidePetBar", "Pet Bar", 30),
                spacer3 = { type = "description", name = "", width = 0.1, order = 31 },
                hideStanceBar   = hideToggle("hideStanceBar", "Stance Bar", 40),
                spacer4 = { type = "description", name = "", width = 0.1, order = 41 },
                hidePossessBar  = hideToggle("hidePossessBar", "Possess Bar", 50),
                spacer5 = { type = "description", name = "", width = 0.1, order = 51 },
                hideEndCaps     = hideToggle("hideEndCaps", "Gryphons", 60),
                spacer6 = { type = "description", name = "", width = 0.1, order = 61 },
                hideRaidManager = hideToggle("hideRaidManager", "Raid Manager", 70),
            }
        },
    }
}
