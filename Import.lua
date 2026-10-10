local _, ns = ...

--------------------------------------------------
-- IMPORT
-- Brings a 1.x account's saved settings (FlareUI_DB) into FlareUI's settings (FlareUI2_DB), once,
-- before the database opens. Only what this version still offers comes along, so nothing arrives
-- that the settings can't change back:
--   * account-wide: the radials, every character's own state (radial choice and keys, tracker,
--     chat history), the Sync Blizz UI data, and which character uses which profile
--   * per profile: the settings panel's options, every frame's Edit Mode settings and switches, and
--     the positions stored per Edit Mode layout
-- The 1.x file itself is left as it is.
--------------------------------------------------

--------------------------------------------------
-- 1. WHAT COMES ALONG
--------------------------------------------------
-- settings panel options, by path
local PATHS = {}
for _, path in ipairs({
    "actionbars.colors.enableRange", "actionbars.colors.unusable.desaturate", "actionbars.enabled",
    "actionbars.hideHotkeys", "actionbars.hideMacroText", "actionbars.procGlow", "actionbars.xpbar.enabled",
    "auras.enabled", "auras.style", "auras.timer",
    "chat.autoHideEnabled", "chat.channelHide", "chat.copyLinks", "chat.editBoxPosition", "chat.enabled",
    "chat.hideBubblesInInstance", "chat.hideCombatLog", "chat.menuHide", "chat.opacity", "chat.saveHistory",
    "chat.showVolume", "chat.socialHide",
    "damagemeter.autoThreat", "damagemeter.enabled", "damagemeter.matchChatSize", "damagemeter.opacity",
    "damagemeter.showOnMouseover", "damagemeter.visibility",
    "fcm.enabled", "fcm.show",
    "minimap.autoZoom", "minimap.buttonBag", "minimap.enabled",
    "objectivetracker.autoMinimize.dungeon", "objectivetracker.autoMinimize.raid", "objectivetracker.autoMinimize.pvp",
    "objectivetracker.autoMinimize.arena", "objectivetracker.autoMinimize.combat",
    "objectivetracker.enabled", "objectivetracker.opacity", "objectivetracker.sortByDistance",
    "objectivetracker.sortByLevel", "objectivetracker.zoneFirst",
    "radialmenu.enabled", "radialmenu.showNames",
    "tooltips.anchor", "tooltips.anchorFrames", "tooltips.borderByClass", "tooltips.borderByQuality",
    "tooltips.borderByReaction", "tooltips.enabled", "tooltips.nameColor", "tooltips.showItemID",
    "tooltips.showSpellID", "tooltips.visibility.actionBars", "tooltips.visibility.frameUnits",
    "tooltips.visibility.worldObjects", "tooltips.visibility.worldUnits",
    "tweaks.autoDelete", "tweaks.autoRepair", "tweaks.durabilityWarning", "tweaks.enabled",
    "tweaks.fasterCameraZoom", "tweaks.fasterLoot", "tweaks.hideErrors", "tweaks.hidePartyTitle",
    "tweaks.hideTips", "tweaks.hideZoneText", "tweaks.maxCameraZoom", "tweaks.moveAnyFrame",
    "tweaks.moveLootToasts", "tweaks.nameplateCombo", "tweaks.nameplateHideLevel", "tweaks.nameplateQuest",
    "tweaks.sellJunk", "tweaks.syncUI", "tweaks.trainAll", "tweaks.way",
    "unitframes.auraStyle", "unitframes.auraTimer", "unitframes.classColor", "unitframes.enabled",
    "unitframes.palette",
    "visibility.hideBagBar", "visibility.hideEndCaps", "visibility.hideMicroMenu", "visibility.hidePetBar",
    "visibility.hidePossessBar", "visibility.hideRaidManager", "visibility.hideStanceBar", "visibility.hideTotemBar",
}) do PATHS[path] = true end

-- the Fake Cooldown Manager bar switches
local PREFIXES = { "fcm.bars." }

-- Edit Mode dialog settings (and the frames' switches) under these roots
local EDIT_ROOTS = { "unitframes.", "auras.", "objectivetracker.", "actionbars.xpbar." }
local EDIT_KEYS = {}
for _, key in ipairs({
    "enabled", "auraSize", "bigBossDebuffs", "buffs", "castbar", "castbarPosition", "classic", "classicSize",
    "debuffs", "dispelHighlight", "dispels", "fsr", "groupNumbers", "groupSpacing", "grow", "healersOnlyPower",
    "healthText", "height", "max", "maxHeight", "missingBuffs", "onlyMyDebuffs", "orientation", "perRow",
    "portrait", "powerHeight", "powerText", "raidIcon", "ringSize", "show", "showLevel", "size", "sort",
    "spacing", "text", "width", "wrap", "mirror", "style",
}) do EDIT_KEYS[key] = true end

-- positions per Edit Mode layout, and Move Any Frame's window positions: copied whole
local STORES = { layouts = true, totemLayouts = true, tankLayouts = true, moverLayouts = true, frames = true }

-- account-wide keys that come along whole
local GLOBAL_KEYS = { "radialmenu", "characters", "uiSync" }

-- the unit frames keys both styles share (UnitFramesRing.lua SHARED_KEYS); the rest is a style's own
local SHARED_KEYS = { enabled = true, foreverStyle = true, styleProfiles = true, editSections = true,
                      party = true, raid = true, boss = true, resource = true, styleStart = true }

--------------------------------------------------
-- 2. HELPERS
--------------------------------------------------
local function Copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = Copy(x) end
    return t
end

local function StartsWith(s, prefix) return s:sub(1, #prefix) == prefix end

local function Wanted(path, key)
    if PATHS[path] then return true end
    -- fonts are fixed in this version
    if path:find("[Ff]ont") then return false end
    for _, prefix in ipairs(PREFIXES) do
        if StartsWith(path, prefix) and key == "enabled" then return true end
    end
    if EDIT_KEYS[key] then
        for _, root in ipairs(EDIT_ROOTS) do
            if StartsWith(path, root) then return true end
        end
    end
    return false
end

-- the default at the same place: nil when this version has no such table (the setting is gone)
local function DefaultAt(defaults, keys)
    local t = defaults
    for i = 1, #keys do
        if type(t) ~= "table" then return nil, false end
        t = t[keys[i]]
    end
    return t, true
end

local function Set(root, keys, value)
    local t = root
    for i = 1, #keys - 1 do
        if type(t[keys[i]]) ~= "table" then t[keys[i]] = {} end
        t = t[keys[i]]
    end
    t[keys[#keys]] = value
end

--------------------------------------------------
-- 3. ONE PROFILE
--------------------------------------------------
local function ImportProfile(old, defaults)
    local new = {}
    local keys = {}
    local function Walk(t)
        for k, v in pairs(t) do
            if type(k) == "string" then
                keys[#keys + 1] = k
                local path = table.concat(keys, ".")
                if type(v) == "table" then
                    if STORES[k] then
                        -- only where this version keeps such a store
                        local parentKeys = { unpack(keys, 1, #keys - 1) }
                        local parent = DefaultAt(defaults, parentKeys)
                        if type(parent) == "table" then Set(new, keys, Copy(v)) end
                    else
                        Walk(v)
                    end
                elseif Wanted(path, k) then
                    -- a value of the same kind as this version's default (none: a per-unit or per-bar
                    -- setting whose table exists)
                    local default = DefaultAt(defaults, keys)
                    local parent = DefaultAt(defaults, { unpack(keys, 1, #keys - 1) })
                    if (default ~= nil and type(default) == type(v)) or (default == nil and type(parent) == "table") then
                        Set(new, keys, v)
                    end
                end
                keys[#keys] = nil
            end
        end
    end
    Walk(old)

    -- 1.x frames were the Addon style: that setup is also kept as the Addon style's own, so switching
    -- to it brings the frames back as they were. The Forever style (the default) starts from its preset.
    local uf = new.unitframes
    if uf then
        local usual = {}
        for k, v in pairs(uf) do
            if not SHARED_KEYS[k] then usual[k] = Copy(v) end
        end
        if next(usual) then uf.styleProfiles = { usual = usual } end
    end
    return new
end

--------------------------------------------------
-- 4. THE ACCOUNT
--------------------------------------------------
-- Runs before AceDB opens FlareUI2_DB. Only into settings that are still empty, and only once.
function ns.ImportOldSettings(defaults)
    local old = _G.FlareUI_DB
    if type(old) ~= "table" then return end
    local db = _G.FlareUI2_DB
    if type(db) == "table" and (db.imported or next(db.profiles or {})) then return end
    db = type(db) == "table" and db or {}
    _G.FlareUI2_DB = db

    local ok, err = pcall(function()
        db.global = db.global or {}
        for _, key in ipairs(GLOBAL_KEYS) do
            if old.global and old.global[key] ~= nil and db.global[key] == nil then
                db.global[key] = Copy(old.global[key])
            end
        end
        db.profileKeys = db.profileKeys or {}
        for char, profile in pairs(old.profileKeys or {}) do
            if db.profileKeys[char] == nil then db.profileKeys[char] = profile end
        end
        db.profiles = db.profiles or {}
        for name, profile in pairs(old.profiles or {}) do
            if type(profile) == "table" then db.profiles[name] = ImportProfile(profile, defaults.profile) end
        end
    end)
    db.imported = ok and "1.x" or ("failed: " .. tostring(err))
    ns.importedOldSettings = ok
end
