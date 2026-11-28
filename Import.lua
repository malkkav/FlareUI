local _, ns = ...

--------------------------------------------------
-- IMPORT
-- Copies FlareUI_DB into FlareUI2_DB once, before the database opens, keeping only what the settings
-- offer: account-wide data, panel options, Edit Mode settings and per-layout positions. FlareUI_DB
-- itself is left untouched.
--------------------------------------------------

--------------------------------------------------
-- 1. WHAT COMES ALONG
--------------------------------------------------
-- settings panel options, by path
local PATHS = {}
for _, path in ipairs({
    "actionbars.colors.enableRange", "actionbars.colors.unusable.desaturate", "actionbars.enabled",
    "actionbars.hideHotkeys", "actionbars.hideMacroText", "actionbars.procGlow", "actionbars.xpbar.enabled", "actionbars.xpbar.textMode",
    "actionbars.buttonArt", "actionbars.stopAutoAddSpells",
    "auras.enabled", "auras.style", "auras.timer",
    "chat.borderTexture", "damagemeter.borderTexture", "objectivetracker.borderTexture",
    "tweaks.hidePortraitNumbers",
    "chat.editBoxOpacity", "chat.formatNPC", "chat.formatPlayer", "chat.betterTimestamps", "chat.shortChannels",
    "chat.showLevel", "chat.channelHide", "chat.editBoxPosition", "chat.enabled",
    "chat.hideBubblesInInstance", "chat.hideCombatLog", "chat.menuHide", "chat.opacity", "chat.saveHistory",
    "chat.showVolume", "chat.socialHide",
    "damagemeter.combatTimer", "chat.autoHideDelay",
    "damagemeter.autoThreat", "damagemeter.enabled", "damagemeter.matchChatSize", "damagemeter.opacity",
    "damagemeter.showOnMouseover", "damagemeter.visibility",
    "fcm.show",
    "minimap.autoZoom", "minimap.buttonBag", "minimap.enabled",
    "objectivetracker.autoMinimize.dungeon", "objectivetracker.autoMinimize.raid", "objectivetracker.autoMinimize.pvp",
    "objectivetracker.autoMinimize.arena", "objectivetracker.autoMinimize.combat",
    "objectivetracker.zoneHeaders", "objectivetracker.completedLast", "objectivetracker.showTags",
    "objectivetracker.showRecipes",
    "objectivetracker.enabled", "objectivetracker.minimizeStyle", "objectivetracker.opacity", "objectivetracker.sortByDistance",
    "objectivetracker.sortByLevel", "objectivetracker.zoneFirst",
    "radialmenu.enabled", "radialmenu.showNames",
    "tooltips.hideHealthBar", "tooltips.healthBarPlace", "tooltips.showTarget", "tooltips.scale", "tooltips.anchor", "tooltips.anchorFrames", "tooltips.borderByClass", "tooltips.borderByQuality",
    "tooltips.borderByReaction", "tooltips.enabled", "tooltips.nameColor", "tooltips.showItemID",
    "tooltips.showSpellID", "tooltips.visibility.actionBars", "tooltips.visibility.frameUnits",
    "tooltips.visibility.worldObjects", "tooltips.visibility.worldUnits",
    "tweaks.autoDelete", "tweaks.autoRepair", "tweaks.enabled",
    "tweaks.fasterCameraZoom", "tweaks.fasterLoot", "tweaks.hideErrors",
    "tweaks.hideTips", "tweaks.hideZoneText", "tweaks.maxCameraZoom", "tweaks.moveAnyFrame",
    "tweaks.moveLootToasts", "tweaks.nameplateCombo", "tweaks.nameplateQuest",
    "tweaks.sellJunk", "tweaks.syncUI", "tweaks.trainAll", "tweaks.way",
    "unitframes.auraStyle", "unitframes.auraTimer", "unitframes.classColor", "unitframes.enabled",
    "unitframes.palette",
    "visibility.hideBagBar", "visibility.hideEndCaps", "visibility.hideMicroMenu", "visibility.hidePetBar",
    "visibility.hidePossessBar", "visibility.hideRaidManager", "visibility.hideStanceBar", "visibility.hideTotemBar",
}) do PATHS[path] = true end

-- Fake CM bar switches (kept only from a profile that had Fake CM on)
local PREFIXES = { "fcm.bars." }

-- a font's controls on the Fonts tabs
local FONT_FIELDS = { face = true, size = true, flags = true, enableShadow = true, shadowX = true, shadowY = true }

-- Edit Mode dialog settings (and the frames' switches) under these roots
local EDIT_ROOTS = { "unitframes.", "auras.", "objectivetracker.", "actionbars.xpbar." }
local EDIT_KEYS = {}
for _, key in ipairs({
    "enabled", "auraSize", "buffs", "castbar", "castbarPosition", "classic", "classicSize",
    "debuffs", "dispelHighlight", "dispels", "fsr", "groupNumbers", "groupSpacing", "grow",
    "healthText", "height", "max", "maxHeight", "onlyMyDebuffs", "orientation", "perRow",
    "portrait", "powerHeight", "powerText", "raidIcon", "ringSize", "show", "showLevel", "size", "sort",
    "spacing", "text", "width", "wrap", "mirror", "style", "texture", "border", "borderTexture",
}) do EDIT_KEYS[key] = true end

-- per-layout positions and Move Any Frame's window positions: copied whole
local STORES = { layouts = true, totemLayouts = true, tankLayouts = true, moverLayouts = true, frames = true }

-- account-wide keys that come along whole
local GLOBAL_KEYS = { "radialmenu", "characters", "uiSync" }

-- unit frame keys both styles share (UnitFramesRing.lua SHARED_KEYS)
local SHARED_KEYS = { enabled = true, foreverStyle = true, plateStyle = true, styleProfiles = true, editSections = true,
                      raid = true, resource = true, styleStart = true, tileStyle = true, plateTiles = true,
                      simplePet = true, simpleTargetOf = true, palette = true, visibility = true, classColor = true, fullNames = true,
                      auraStyle = true, auraTimer = true, font = true, fontPower = true, fontCast = true, auraFont = true,
                      auraCountFont = true, auraCountFontSeeded = true }

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
    -- every font's fields (the Fonts tabs)
    if FONT_FIELDS[key] and path:find("[Ff]ont%a*%.%a+$") then return true end
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

-- The default at the same path; nil when the defaults have no such table
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
                        -- only where the defaults keep such a store
                        local parentKeys = { unpack(keys, 1, #keys - 1) }
                        local parent = DefaultAt(defaults, parentKeys)
                        if type(parent) == "table" then Set(new, keys, Copy(v)) end
                    else
                        Walk(v)
                    end
                elseif Wanted(path, k) then
                    -- same type as the default, or no default inside an existing table (per-unit keys)
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

    -- Fake CM has no switch of its own: it is on while a bar is picked
    local oldFCM = old.fcm
    if new.fcm and not (type(oldFCM) == "table" and oldFCM.enabled) then new.fcm.bars = nil end

    -- old chat fading settings map to "Visibility" and "Fade Speed"
    local oldChat = old.chat
    if type(oldChat) == "table" and oldChat.autoHideEnabled then
        new.chat = new.chat or {}
        new.chat.visibility = oldChat.showOnCombat and "combat" or "interactions"
        local out = tonumber(oldChat.fadeOutSpeed) or 0
        new.chat.fadeSpeed = out <= 0 and "instant" or (out <= 0.3 and "fast" or "slow")
    end
    -- "Fade Delay" offers 0, 5, 10, 15 or 30 seconds: the nearest
    local delay = new.chat and new.chat.autoHideDelay
    if type(delay) == "number" then
        local best = 0
        for _, choice in ipairs({ 0, 5, 10, 15, 30 }) do
            if math.abs(choice - delay) < math.abs(best - delay) then best = choice end
        end
        new.chat.autoHideDelay = best
    end

    -- Imported frames are Addon Style: kept as that style's profile; Forever Style starts from its preset
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
-- Runs before AceDB opens FlareUI2_DB; only into empty settings, and only once
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
    -- before the settings open: written straight into the error log /fui errors shows
    if not ok then
        db.global = db.global or {}
        db.global.errors = db.global.errors or {}
        table.insert(db.global.errors, ("%s | 1.x import | %s"):format(date("%Y-%m-%d %H:%M"), tostring(err)))
    end
end

--------------------------------------------------
-- 5. NEW DEFAULTS FOR NEW PLAYERS ONLY (Malkkav 11-27, defaults pass 2)
-- The defaults below changed for new installs. Runs once, before AceDB opens FlareUI2_DB (there a setting
-- the player never touched is missing; once open, AceDB fills in every default and they look alike).
-- An account that used FlareUI before gets each old value written where it has nothing saved, in every
-- profile, so nothing changes for it. A new install writes nothing and gets the new defaults.
--------------------------------------------------
-- path = the old default
ns.OLD_DEFAULTS_V2 = {
    -- Unit Frames
    ["unitframes.units.player.buffs"] = "TOPLEFT", ["unitframes.units.player.debuffs"] = "TOPRIGHT",
    ["unitframes.units.targettarget.enabled"] = true, ["unitframes.units.focustarget.enabled"] = true,
    ["unitframes.party.showPlayer"] = true,
    ["unitframes.raid.powerHeight"] = 10, ["unitframes.raid.mainTanks.enabled"] = false,
    ["unitframes.auraTimer"] = "none", ["unitframes.totems.timer"] = "none",
    ["unitframes.legacyStyle"] = true,   -- a profile not started yet starts in FlareUI Style (UnitFramesRing.lua Ring.StartStyle)
    -- Cooldowns, Action Bars
    ["cooldownmanager.skin"] = false,
    ["actionbars.equippedBorder"] = false, ["actionbars.procGlow"] = false, ["actionbars.activeHighlight"] = false,
    ["actionbars.stopAutoAddSpells"] = false, ["actionbars.autoRanks"] = false,
    ["actionbars.xpbar.questXP"] = false, ["actionbars.xpbar.textMode"] = "HOVER",
    -- Minimap
    ["minimap.finderEye"] = false, ["minimap.durability"] = false, ["minimap.vehicleExit"] = false,
    -- Quest Tracker
    ["objectivetracker.hideScrollBar"] = false, ["objectivetracker.playButtons"] = false,
    ["objectivetracker.colorNames"] = false, ["objectivetracker.hideFinished"] = false,
    -- Chat
    ["chat.unreadGlow"] = "say,yell,party,raid,guild,whisper,channel", ["chat.whisperSound"] = "off",
    ["chat.shortChannels"] = false, ["chat.formatPlayer"] = false, ["chat.formatNPC"] = false,
    ["chat.whisperMarkers"] = false,
    -- Tooltips
    ["tooltips.corner"] = "auto",
    -- Bags & Looting
    ["tweaks.bagGaps"] = false, ["tweaks.bagKeyring"] = false, ["tweaks.bagReverse"] = false,
    ["tweaks.bagButtons"] = false, ["tweaks.bagReagent"] = false, ["tweaks.bagCombineEmpty"] = false,
    ["tweaks.bagJunkIcon"] = false, ["tweaks.bagUncollected"] = false, ["tweaks.bagBoE"] = false,
    ["tweaks.bagItemLevel"] = false, ["tweaks.petFood"] = false, ["tweaks.bagPlainEmpty"] = false,
    ["tweaks.fasterLoot"] = false, ["tweaks.lootRolls"] = false, ["tweaks.lootWindow"] = false,
    ["tweaks.lootFeed"] = false, ["tweaks.lootFeedIcons"] = "square", ["tweaks.lootFeedSkills"] = false,
    ["tweaks.bankGaps"] = false, ["tweaks.bankTight"] = false,
    -- Nameplates (shared); the per-type values are the old tables, kept in Nameplates.lua (legacyBase)
    ["nameplates.questMarks"] = false, ["nameplates.peacefulNames"] = false,
    ["nameplates.combatPlates"] = "none", ["nameplates.fightingPlates"] = "none",
    ["nameplates.legacyBase"] = true,
}
-- (11-28, defaults pass 3: Malkkav's Edit Mode setup) the shared ones; the two styles' own setups only reach a
-- profile on its first start or switch (UnitFramesRing.lua Ring.STYLE_SETUP), so they need nothing here
ns.OLD_DEFAULTS_V3 = {
    ["unitframes.raid.spacing"] = 10, ["unitframes.raid.groupSpacing"] = 10, ["unitframes.raid.mainTanks.spacing"] = 10,
    ["unitframes.resource.bars.health.smoothBars"] = false, ["unitframes.resource.bars.health.barEdgeGlow"] = false,
    ["unitframes.resource.bars.power.smoothBars"] = false, ["unitframes.resource.bars.power.barEdgeGlow"] = false,
    ["unitframes.resource.bars.mana.smoothBars"] = false, ["unitframes.resource.bars.mana.barEdgeGlow"] = false,
    ["objectivetracker.width"] = 250, ["objectivetracker.maxHeight"] = 300, ["objectivetracker.questGap"] = 9,
}
-- each pass: its table and the flag that it ran (both run once; a new install skips both)
ns.DEFAULTS_PASSES = { { flag = "defaultsV2", old = ns.OLD_DEFAULTS_V2 }, { flag = "defaultsV3", old = ns.OLD_DEFAULTS_V3 } }
-- each unit frame style keeps its own setup of these (UnitFramesRing.lua styleProfiles)
local PER_STYLE = { units = true, party = true, totems = true }

-- writes value at path inside t where nothing is saved yet
local function WriteOld(t, path, value)
    local keys = {}
    for key in path:gmatch("[^%.]+") do keys[#keys + 1] = key end
    for i = 1, #keys - 1 do
        local nextT = t[keys[i]]
        if nextT == nil then nextT = {} t[keys[i]] = nextT end
        if type(nextT) ~= "table" then return end
        t = nextT
    end
    if t[keys[#keys]] == nil then t[keys[#keys]] = value end
end

-- Runs before AceDB opens FlareUI2_DB. Returns true for a new install (nothing was written).
function ns.NewPlayerDefaults()
    local sv = _G.FlareUI2_DB
    if type(sv) ~= "table" then return true end
    sv.global = sv.global or {}
    local passes = {}
    for _, pass in ipairs(ns.DEFAULTS_PASSES) do
        if not sv.global[pass.flag] then passes[#passes + 1] = pass end
    end
    if #passes == 0 then return false end
    for _, pass in ipairs(passes) do sv.global[pass.flag] = true end
    local profiles = type(sv.profiles) == "table" and sv.profiles or {}
    local used = sv.global.whatsNewSeen ~= nil or sv.global.welcomeSeen ~= nil
    for _, profile in pairs(profiles) do
        if type(profile) == "table" and next(profile) then used = true end
    end
    if not used then return true end
    local ok, err = pcall(function()
        for _, profile in pairs(profiles) do
            if type(profile) == "table" then
                for _, pass in ipairs(passes) do
                    for path, value in pairs(pass.old) do
                        WriteOld(profile, path, value)
                        -- the other styles' stored setups too: a switch back brings theirs, not the new default
                        local inner = path:match("^unitframes%.(.+)$")
                        local slots = inner and PER_STYLE[inner:match("^[^%.]+")] and type(profile.unitframes) == "table"
                            and type(profile.unitframes.styleProfiles) == "table" and profile.unitframes.styleProfiles
                        for _, slot in pairs(slots or {}) do
                            if type(slot) == "table" then WriteOld(slot, inner, value) end
                        end
                    end
                end
            end
        end
    end)
    if not ok then
        sv.global.errors = sv.global.errors or {}
        table.insert(sv.global.errors, ("%s | new defaults | %s"):format(date("%Y-%m-%d %H:%M"), tostring(err)))
    end
    return false
end
