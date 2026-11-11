local _, ns = ...
local L = ns.L

--------------------------------------------------
-- CLASS BUFF REMINDERS (Buffs & Debuffs > Buff Reminders, off)
-- After EnhanceQoL's class buff reminder: an icon for each of your class's buffs that is missing (or
-- running out) on you or your group, in FlareUI's buff look. Click an icon to cast it. Out of a fight
-- only: the row hides itself as a fight starts (a state driver), and it reads auras only while the
-- game lets addons read them. Known spells only, at your highest rank. Also (11-10, after EnhanceQoL's
-- reminder, the idea only): paladin blessings, picked per member (Blessing: Automatic gives warriors,
-- rogues and hunters Might and everyone else Wisdom, or one for all); a hunter's or warlock's pet
-- missing, dead or hurt (Pet Reminders, on); food and flask buffs (Food and Flask: off, in dungeons and
-- raids, or always; icons only, nothing to click). When It Shows: Solo / Party / Raid, Hide in Rested
-- Areas, Only When You're the Only Provider (a group buff no one else of your class gives). Alerts: a
-- sound when a reminder appears, a gold glow on missing buffs, an orange one on buffs running out.
--------------------------------------------------
local BR = {}
ns.BuffReminders = BR
ns.modules["BuffReminders"] = BR

local ipairs, pairs, wipe = ipairs, pairs, wipe
local math_floor, math_max = math.floor, math.max
local CreateFrame, InCombatLockdown, GetTime = CreateFrame, InCombatLockdown, GetTime
local LEM = LibStub("FlareEditMode")

local function AurasDb()
    return ns.db and ns.db.profile and ns.db.profile.auras
end
local function GetDb()
    local db = AurasDb()
    return db and db.reminder
end

--------------------------------------------------
-- 1. THE BUFFS
-- cast: the spell the icon casts, highest rank first; buffs: every aura that counts (ranks, the
-- group versions, look-alikes). group: checked on the group too; casters: only on mana users.
-- weapon: a temporary weapon enchant on the main hand instead of an aura (cast = nil: no click).
--------------------------------------------------
local FORTITUDE = { 10938, 10937, 2791, 1245, 1244, 1243 }
local INTELLECT = { 10157, 10156, 1461, 1460, 1459 }
local WILD      = { 9885, 9884, 8907, 5234, 6756, 5232, 1126 }
local function Join(a, b) local t = {} for _, v in ipairs(a) do t[#t + 1] = v end for _, v in ipairs(b) do t[#t + 1] = v end return t end

local REMINDERS = {
    PRIEST = {
        { key = "fortitude", cast = FORTITUDE, buffs = Join(FORTITUDE, { 21564, 21562 }), group = true },
        { key = "innerFire", cast = { 10952, 10951, 1006, 602, 7128, 588 } },
    },
    MAGE = {
        { key = "intellect", cast = INTELLECT, buffs = Join(INTELLECT, { 23028 }), group = true, casters = true },
        -- one armor of any kind
        { key = "armor", cast = { 22783, 22782, 6117, 10220, 10219, 7320, 7302, 7301, 7300, 168 } },
    },
    DRUID = {
        { key = "wild", cast = WILD, buffs = Join(WILD, { 21850, 21849 }), group = true },
        -- Thorns (11-10, a druid asked): kept on whoever the Thorns setting picks, tanks by default
        { key = "thorns", cast = { 9910, 9756, 8914, 1075, 782, 467 }, group = true, pick = "thorns" },
    },
    WARLOCK = {
        { key = "armor", cast = { 11735, 11734, 11733, 1086, 706, 696, 687 } },
    },
    SHAMAN = {
        -- Water Shield and Earth Shield count too
        { key = "shield", cast = { 10432, 10431, 8134, 945, 905, 325, 324 }, buffs = { 10432, 10431, 8134, 945, 905, 325, 324, 408510, 408514 } },
        { key = "imbue", weapon = true, cast = { 8232, 8024, 8017, 8033 } },
    },
    ROGUE = {
        { key = "poison", weapon = true, icon = 2842 },
    },
    PALADIN = {
        { key = "blessing", blessing = true, group = true },
        -- a tank's threat buff, only while your group role is tank
        { key = "fury", cast = { 25780 }, role = "TANK" },
        -- any aura on (Devotion, Retribution, Concentration, the resistances, Sanctity): Devotion to cast
        { key = "aura", cast = { 10293, 10292, 1032, 10291, 643, 10290, 465 },
          buffs = { 10293, 10292, 1032, 10291, 643, 10290, 465, 10301, 10300, 10299, 10298, 7294, 19746, 19896, 19895,
                    19876, 19898, 19897, 19888, 19900, 19899, 19891, 20218 } },
    },
    WARRIOR = {
        -- no stance at all (Battle Stance to cast)
        { key = "stance", stance = true, cast = { 2457 } },
    },
    HUNTER = {
        { key = "pet", pet = "HUNTER" },
    },
}
-- the warlock's pet joins its armor, then a healthstone in the bags (Create Healthstone, best rank)
table.insert(REMINDERS.WARLOCK, { key = "pet", pet = "WARLOCK" })
table.insert(REMINDERS.WARLOCK, { key = "healthstone", healthstone = true, cast = { 11730, 11729, 5699, 6202, 6201 } })
local HEALTHSTONES = { 5512, 5511, 5509, 5510, 9421, 19004, 19005, 19006, 19007, 19008, 19009, 19010, 19011, 19012, 19013 }
-- Camping and Rest (Forever, off): Camp Benefits from a campfire, and while levelling with a Cozy
-- Sleeping Bag in the bags, three Well-Rested stacks (click to use the bag). Gathering Tracking (off):
-- Find Herbs or Find Minerals off while you know one. (IDs from EnhanceQoL's Forever data.)
local CAMP_BUFF, SLEEPING_BAG, WELL_RESTED = 1229741, 211527, 429959
local EXTRAS = {
    { key = "camp", camp = true, buffs = { CAMP_BUFF }, icon = CAMP_BUFF },
    { key = "sleepingBag", bag = true },
    { key = "gathering", gathering = true, cast = { 2383, 8387, 2580, 8388 } },
}
-- food and flask, for every class
local CONSUMABLES = {
    { key = "food", consumable = true, buffs = { 19705 }, icon = 19705 },                       -- Well Fed
    { key = "flask", consumable = true, buffs = { 17626, 17627, 17628, 17629 }, icon = 17626 },  -- the four flasks
}

-- Paladin blessings: ranks (highest first) and their Greater versions, which count as covered too
local BLESSINGS = {
    might     = { cast = { 25291, 19838, 19837, 19836, 19835, 19834, 19740 }, greater = { 25916, 25782 } },
    wisdom    = { cast = { 25290, 19854, 19853, 19852, 19850, 19742 }, greater = { 25918, 25894 } },
    kings     = { cast = { 20217 }, greater = { 25898 } },
    salvation = { cast = { 1038 }, greater = { 25895 } },
    light     = { cast = { 19979, 19978, 19977 }, greater = { 25890 } },
    sanctuary = { cast = { 20914, 20913, 20912, 20911 }, greater = { 25899 } },
}
local BLESSING_ORDER = { "might", "wisdom", "kings", "salvation", "light", "sanctuary" }
-- Automatic: the fighters without much use for mana get Might
local MIGHT_CLASSES = { WARRIOR = true, ROGUE = true, HUNTER = true }
-- pets: hunters call, revive and mend; warlocks summon (the last one they summoned, else the first known)
local CALL_PET, REVIVE_PET, MEND_PET = 883, 982, 136
local WARLOCK_SUMMONS = { 691, 697, 712, 688 }   -- Felhunter, Voidwalker, Succubus, Imp
local MEND_BELOW = 0.5
local GLOW_MISSING, GLOW_EXPIRING = { 1, 0.82, 0.25 }, { 1, 0.45, 0.1 }

-- classes that never use mana
local NO_MANA = { WARRIOR = true, ROGUE = true }

--------------------------------------------------
-- 2. STATE
--------------------------------------------------
local holder, row          -- holder: the Edit Mode frame (hidden in a fight); row: the icons' parent
local icons = {}           -- [i] = secure button
local active = {}          -- this class's reminders, spell names resolved
local DEFAULTS = { point = "CENTER", x = 0, y = 189 }   -- Marcus's own spot (11-10)

local function Readable(v) return canaccessvalue == nil or canaccessvalue(v) end

local function AurasLocked()
    if not (C_Secrets and C_Secrets.ShouldAurasBeSecret) then return false end
    local ok, secret = pcall(C_Secrets.ShouldAurasBeSecret)
    return not ok or not Readable(secret) or secret == true
end

local function Known(id) return id and IsPlayerSpell(id) end

local function SpellName(id)
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
    return name
end

local function SpellIcon(id)
    return C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id) or 134400
end

-- the class's reminders with the spell to cast (highest known rank) and the aura names that count
local function Resolve()
    wipe(active)
    local _, class = UnitClass("player")
    for _, def in ipairs(REMINDERS[class] or {}) do
        local castID
        for _, id in ipairs(def.cast or {}) do
            if Known(id) then castID = id break end
        end
        -- a rogue's poisons have no spell to know: the reminder is there from level 20
        local usable = castID or (def.weapon and not def.cast and UnitLevel("player") >= 20)
        local entry
        if def.blessing then
            -- each known blessing: its best rank and the names that cover it
            local known = {}
            for _, key in ipairs(BLESSING_ORDER) do
                local b = BLESSINGS[key]
                local id
                for _, rank in ipairs(b.cast) do if Known(rank) then id = rank break end end
                if id then
                    local names = {}
                    for _, list in ipairs({ b.cast, b.greater }) do
                        for _, rank in ipairs(list) do
                            local name = SpellName(rank)
                            if name then names[name] = true end
                        end
                    end
                    known[key] = { castID = id, names = names, icon = SpellIcon(id) }
                end
            end
            if next(known) then
                local first = known[BLESSING_ORDER[1]] or select(2, next(known))
                entry = { def = def, blessings = known, castID = first.castID, icon = first.icon, names = first.names }
            end
            usable = false
        elseif def.pet then
            local any = def.pet == "HUNTER" and (Known(CALL_PET) or Known(REVIVE_PET))
            if def.pet == "WARLOCK" then
                for _, id in ipairs(WARLOCK_SUMMONS) do if Known(id) then any = true end end
            end
            if any then entry = { def = def, names = {}, icon = SpellIcon(def.pet == "HUNTER" and CALL_PET or 688) } end
            usable = false
        end
        if entry then active[#active + 1] = entry end
        if usable then
            local names = {}
            for _, id in ipairs(def.buffs or def.cast or {}) do
                local name = SpellName(id)
                if name then names[name] = true end
            end
            active[#active + 1] = { def = def, castID = castID, names = names,
                                    icon = SpellIcon(castID or def.icon) }
        end
    end
    for _, def in ipairs(EXTRAS) do
        local castID
        for _, id in ipairs(def.cast or {}) do
            if Known(id) then castID = id break end
        end
        -- gathering needs a known tracking spell; the camp and the bag are checked as they come
        if castID or not def.cast then
            local names = {}
            for _, id in ipairs(def.buffs or def.cast or {}) do
                local name = SpellName(id)
                if name then names[name] = true end
            end
            local icon = def.bag and (C_Item.GetItemIconByID and C_Item.GetItemIconByID(SLEEPING_BAG)) or SpellIcon(castID or def.icon)
            active[#active + 1] = { def = def, castID = castID, names = names, icon = icon }
        end
    end
    for _, def in ipairs(CONSUMABLES) do
        local names = {}
        for _, id in ipairs(def.buffs) do
            local name = SpellName(id)
            if name then names[name] = true end
        end
        active[#active + 1] = { def = def, names = names, icon = SpellIcon(def.icon) }
    end
end

-- the reminders the settings leave on
-- Right-click an icon: hide that reminder until reload, or for good (db.hidden, "CLASS:key", so a mage's
-- and a warlock's armour stay apart); the Buff Reminders tab shows them all again
local dismissed = {}
function BR.HideKey(entry)
    local _, class = UnitClass("player")
    return (class or "") .. ":" .. (entry.def and entry.def.key or "")
end
function BR.HiddenCount()
    local db = GetDb() or {}
    local n = 0
    for _ in pairs(db.hidden or {}) do n = n + 1 end
    for _ in pairs(dismissed) do n = n + 1 end
    return n
end
function BR.ShowHidden()
    local db = GetDb()
    if db then db.hidden = nil end
    wipe(dismissed)
    BR.Update()
end

local Enabled
-- the reminders the settings leave on, for From the Middle's room
function BR.EnabledCount()
    local n = 0
    for _, entry in ipairs(active) do if Enabled(entry) then n = n + 1 end end
    return math.min(n, 12)
end

function Enabled(entry)
    local db = GetDb() or {}
    local hideKey = BR.HideKey(entry)
    if dismissed[hideKey] or (db.hidden and db.hidden[hideKey]) then return false end

    if entry.def.camp or entry.def.bag then return db.camping == true end
    if entry.def.gathering then return db.gathering == true end
    if entry.def.role and not ns.EditPreviewing() then
        local ok, role = pcall(UnitGroupRolesAssigned, "player")
        return ok and Readable(role) and role == entry.def.role or false
    end
    if entry.def.consumable then
        local mode = db.consumables or "off"
        if mode == "off" then return false end
        if mode == "instance" and not ns.EditPreviewing() then
            local inInstance, kind = IsInInstance()
            return inInstance and (kind == "party" or kind == "raid") or false
        end
    end
    return true
end

--------------------------------------------------
-- 3. WHO IS MISSING WHAT
--------------------------------------------------
local function GroupUnits(out)
    wipe(out)
    local db = GetDb()
    local scope = db and db.group or "all"
    if scope ~= "self" and IsInRaid() then
        if scope == "all" then
            for i = 1, GetNumGroupMembers() do out[#out + 1] = "raid" .. i end
            return out
        end
    end
    out[1] = "player"
    if scope ~= "self" and IsInGroup() then
        for i = 1, 4 do out[#out + 1] = "party" .. i end
    end
    return out
end

-- someone a buff can reach: there, alive, online, seen and in your phase
local function Reachable(unit)
    if not UnitExists(unit) or UnitIsDeadOrGhost(unit) or not UnitIsConnected(unit) then return false end
    if unit ~= "player" and not UnitIsUnit(unit, "player") then
        if not UnitIsVisible(unit) then return false end
        if UnitPhaseReason and UnitPhaseReason(unit) then return false end
    end
    return true
end

-- true when the unit has one of the names with more than `before` seconds left; second: it has it,
-- but it is running out (Remind Before It Ends)
local function HasBuff(unit, names, before)
    local now = GetTime()
    for i = 1, 40 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
        if not ok or not aura then return false, false end
        local name = aura.name
        if Readable(name) and names[name] then
            local expires = aura.expirationTime
            if not Readable(expires) or not expires or expires == 0 then return true, false end
            local fine = expires - now > before
            return fine, not fine
        end
    end
    return false, false
end

-- the main hand's timed enchant (Forever's C_Item.GetWeaponEnchantInfo, slot 0 = main hand)
local function WeaponMissing(before)
    -- nothing to coat: no main hand weapon
    if not GetInventoryItemID("player", 16) then return false end
    if not (C_Item and C_Item.GetWeaponEnchantInfo) then return false end
    local ok, enchants = pcall(C_Item.GetWeaponEnchantInfo, 0)
    if not ok then return false end
    local some = false
    for _, e in ipairs(enchants or {}) do
        local left = e.hasEnchant and (e.timeLeft or 0) / 1000 or 0
        if left > before then return false end
        if left > 0 then some = true end
    end
    return true, some
end

-- the blessing a member should have, among the ones you know
local function BlessingFor(entry, unit)
    local db = GetDb() or {}
    local wanted = db.blessing or "auto"
    if wanted == "auto" then
        local _, class = UnitClass(unit)
        wanted = MIGHT_CLASSES[class] and "might" or "wisdom"
    end
    if entry.blessings[wanted] then return entry.blessings[wanted] end
    for _, key in ipairs(BLESSING_ORDER) do
        if entry.blessings[key] then return entry.blessings[key] end
    end
end

local function Readable2(a, b) return Readable(a) and Readable(b) end

-- the pet's state: the spell that fixes it and the unit to cast on, or nil when all is well
-- the pet set to Passive (the pet bar's mode button lit): its icon
local function PetPassive()
    if not GetPetActionInfo then return nil end
    for i = 1, (NUM_PET_ACTION_SLOTS or 10) do
        local name, texture, isToken, isActive = GetPetActionInfo(i)
        if (name == "PET_MODE_PASSIVE" or name == "PET_ACTION_MODE_PASSIVE") and isActive then
            return (isToken and _G[texture]) or texture or 132311
        end
    end
end

-- the pet's state: the spell that fixes it and the unit to cast on, or nil when all is well; a pet
-- left on Passive answers with a macro (/petdefensive) and the mode's icon
local function PetFix(entry)
    if IsMounted() then return nil end
    local exists = UnitExists("pet")
    if exists and not UnitIsDead("pet") then
        local passive = PetPassive()
        if passive then return nil, "pet", "/petdefensive", passive end
    end
    if entry.def.pet == "HUNTER" then
        if exists and UnitIsDead("pet") then return Known(REVIVE_PET) and REVIVE_PET, "player" end
        if not exists then return Known(CALL_PET) and CALL_PET, "player" end
        local ok, health, max = pcall(function() return UnitHealth("pet"), UnitHealthMax("pet") end)
        if ok and Readable2(health, max) and max and max > 0 and health / max < MEND_BELOW and Known(MEND_PET) then
            return MEND_PET, "pet"
        end
        return nil
    end
    if exists then return nil end
    local me = ns.CharDB and ns.CharDB()
    local last = me and me.lastSummon
    if last and Known(last) then return last, "player" end
    for _, id in ipairs(WARLOCK_SUMMONS) do
        if Known(id) then return id, "player" end
    end
end

-- a tank: by group role (the group finder's), or a raid's main tank
local function IsTank(unit)
    local ok, role = pcall(UnitGroupRolesAssigned, unit)
    if ok and Readable(role) and role == "TANK" then return true end
    if GetPartyAssignment then
        local okA, main = pcall(GetPartyAssignment, "MAINTANK", unit)
        if okA and Readable(main) and main then return true end
    end
    return false
end

-- Only When You're the Only Provider: someone else in the group of your class gives it already
local function OtherProvider()
    local _, mine = UnitClass("player")
    local list = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do list[#list + 1] = "raid" .. i end
    elseif IsInGroup() then
        for i = 1, 4 do list[#list + 1] = "party" .. i end
    end
    for _, unit in ipairs(list) do
        if UnitExists(unit) and not UnitIsUnit(unit, "player") and UnitIsConnected(unit) then
            local _, class = UnitClass(unit)
            if class == mine then return true end
        end
    end
    return false
end

local units = {}
-- each active reminder's missing / total, the first unit to cast on, the spell (when it is not the
-- reminder's own: a blessing or a pet's), and whether nothing is missing, only running out
local function Check(entry, before)
    local def = entry.def
    if (def.group or def.blessing) and (GetDb() or {}).onlyProvider and OtherProvider() then return 0, 0 end
    -- the role filters (When It Shows): your group role hides the group buffs, never your own
    if def.group or def.blessing then
        local db = GetDb() or {}
        local ok, role = pcall(UnitGroupRolesAssigned, "player")
        role = ok and Readable(role) and role or "NONE"
        if (role == "TANK" and db.hideTank) or (role == "HEALER" and db.hideHealer)
                or (role == "DAMAGER" and db.hideDamage) or (role == "NONE" and db.hideNoRole) then
            return 0, 0
        end
    end
    if def.weapon then
        local missing, running = WeaponMissing(before)
        return missing and 1 or 0, 1, "player", nil, nil, running
    end
    if def.pet then
        local fix, unit, macro, icon = PetFix(entry)
        if macro then return 1, 1, unit, nil, icon, false, { macro = macro } end
        if not fix then return 0, 1 end
        return 1, 1, unit, fix, SpellIcon(fix)
    end
    if def.stance then
        local form = GetShapeshiftForm and GetShapeshiftForm() or 1
        return (Readable(form) and form == 0) and 1 or 0, 1, "player"
    end
    if def.healthstone then
        for _, id in ipairs(HEALTHSTONES) do
            if (C_Item.GetItemCount and C_Item.GetItemCount(id) or 0) > 0 then return 0, 1 end
        end
        return 1, 1, "player"
    end
    if def.bag then
        -- while levelling, with the bag on you: fewer than three Well-Rested stacks
        if UnitLevel("player") >= 60 or (C_Item.GetItemCount and C_Item.GetItemCount(SLEEPING_BAG) or 0) == 0 then return 0, 1 end
        local stacks = 0
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, WELL_RESTED)
        if ok and aura and Readable(aura.applications) then stacks = aura.applications or 0 end
        if stacks >= 3 then return 0, 1 end
        return 1, 1, "player", nil, nil, false, { item = "item:" .. SLEEPING_BAG }
    end
    if def.gathering then
        -- the minimap's tracking list where the client has one, else the tracking buff
        if C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo then
            for i = 1, C_Minimap.GetNumTrackingTypes() do
                local info = C_Minimap.GetTrackingInfo(i)
                if info and info.active and info.spellID and tContains(def.cast, info.spellID) then return 0, 1 end
            end
        end
        return HasBuff("player", entry.names, 0) and 0 or 1, 1, "player"
    end
    if def.blessing then
        local missing, total, first, firstBlessing, gone = 0, 0, nil, nil, false
        for _, unit in ipairs(GroupUnits(units)) do
            if Reachable(unit) then
                local b = BlessingFor(entry, unit)
                if b then
                    total = total + 1
                    local fine, running = HasBuff(unit, b.names, before)
                    if not fine then
                        missing = missing + 1
                        if not running then gone = true end
                        if not first then first, firstBlessing = unit, b end
                    end
                end
            end
        end
        return missing, total, first, firstBlessing and firstBlessing.castID, firstBlessing and firstBlessing.icon, not gone
    end
    if not def.group then
        local fine, running = HasBuff("player", entry.names, before)
        return fine and 0 or 1, 1, "player", nil, nil, running
    end
    local missing, total, first, gone = 0, 0, nil, false
    -- Thorns: tanks (their group role, or the raid's main tanks; alone, yourself), you, or everyone
    local pick = def.pick and ((GetDb() or {})[def.pick] or "tank")
    local grouped = IsInGroup()
    for _, unit in ipairs(GroupUnits(units)) do
        local wanted = true
        if pick == "self" then
            wanted = unit == "player" or UnitIsUnit(unit, "player")
        elseif pick == "tank" then
            wanted = (not grouped and (unit == "player" or UnitIsUnit(unit, "player"))) or IsTank(unit)
        end
        if wanted and Reachable(unit) then
            local _, class = UnitClass(unit)
            if not (def.casters and NO_MANA[class]) then
                total = total + 1
                local fine, running = HasBuff(unit, entry.names, before)
                if not fine then
                    missing = missing + 1
                    if not running then gone = true end
                    first = first or unit
                end
            end
        end
    end
    return missing, total, first, nil, nil, not gone
end

--------------------------------------------------
-- 4. ICONS
--------------------------------------------------
-- an icon's look (icon, count, pulse, glow), on the secure button or a settings preview's plain frame
function BR.BuildIcon(b)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.pieces = {}
    -- the count sits over the icon's border (a frame two levels up)
    local over = CreateFrame("Frame", nil, b)
    over:SetAllPoints()
    over:SetFrameLevel(b:GetFrameLevel() + 5)
    b.count = over:CreateFontString(nil, "OVERLAY")
    b.count:SetPoint("BOTTOM", b, "BOTTOM", 0, 2)
    -- a slow pulse says "missing"
    local pulse = b.icon:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.45)
    fade:SetDuration(0.8)
    fade:SetSmoothing("IN_OUT")
    b.pulse = pulse
    -- Alerts: the glow (gold for missing, orange for running out), the button border's light, pulsing
    b.glow = b:CreateTexture(nil, "BACKGROUND", nil, -1)
    b.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    b.glow:SetBlendMode("ADD")
    b.glow:SetPoint("CENTER")
    b.glow:Hide()
    local glowPulse = b.glow:CreateAnimationGroup()
    glowPulse:SetLooping("BOUNCE")
    local glowFade = glowPulse:CreateAnimation("Alpha")
    glowFade:SetFromAlpha(1)
    glowFade:SetToAlpha(0.35)
    glowFade:SetDuration(0.6)
    glowFade:SetSmoothing("IN_OUT")
    b.glowPulse = glowPulse
    return b
end

local function Icon(i)
    local b = icons[i]
    if b then return b end
    b = CreateFrame("Button", "FlareUI_BuffReminder" .. i, row, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp", "AnyDown")
    BR.BuildIcon(b)
    -- right-click: no cast (an empty macro), the hide menu instead
    b:SetAttribute("type2", "macro")
    b:SetAttribute("macrotext2", "")
    b:HookScript("OnMouseUp", function(self, button) if button == "RightButton" then BR.Menu(self) end end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        if self.spellID then GameTooltip:SetSpellByID(self.spellID) end
        GameTooltip:AddLine(L["Right-click to hide this reminder."], 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    icons[i] = b
    return b
end

function BR.Menu(owner)
    local entry = owner.entry
    if not (entry and entry.def and MenuUtil and MenuUtil.CreateContextMenu) or InCombatLockdown() then return end
    local key = BR.HideKey(entry)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(owner.spellID and SpellName(owner.spellID) or L["Buff Reminders"])
        root:CreateButton(L["Hide Until Reload"], function()
            dismissed[key] = true
            BR.Update()
        end)
        root:CreateButton(L["Never Remind Me"], function()
            local db = GetDb()
            if not db then return end
            db.hidden = db.hidden or {}
            db.hidden[key] = true
            BR.Update()
        end)
        -- a reminder's own choice lives here, not in the settings (11-10, Marcus: no settings bloat)
        local db = GetDb()
        if not db then return end
        local function Radio(text, field, value)
            root:CreateRadio(text, function() return (db[field] or (field == "thorns" and "tank" or "auto")) == value end,
                function() db[field] = value; BR.Update() end)
        end
        if entry.def.blessing then
            root:CreateDivider()
            root:CreateTitle(L["Blessing"])
            for _, choice in ipairs(BR.BlessingChoices()) do Radio(choice[2], "blessing", choice[1]) end
        elseif entry.def.pick == "thorns" then
            root:CreateDivider()
            root:CreateTitle(L["Keep It On"])
            Radio(L["Tanks Only"], "thorns", "tank")
            Radio(L["Only Me"], "thorns", "self")
            Radio(L["Everyone"], "thorns", "all")
        end
    end)
end

local function StyleIcon(b, size)
    b:SetSize(size, size)
    local db = AurasDb()
    local AU = ns.Auras
    if AU and AU.StyleIcon then
        AU.StyleIcon(b, b.icon, b.pieces, (db and db.style or "round") == "round")
        AU.StackFont(b.count)
    else
        b.icon:SetAllPoints()
        b.count:SetFontObject(NumberFontNormal)
    end
end

-- shows: { { entry, missing, total, unit }, ... }
-- sample: a settings preview's plain frame, which holds its own icons (no clicks, no attributes)
local function Show(shows, sample)
    local db = GetDb() or {}
    local size = db.size or 36
    local spacing = db.spacing or 6
    local vertical = db.orientation == "VERTICAL"
    local back = db.grow == "BACK"   -- left in a row, up in a column
    local list, parentRow, frame = icons, row, holder
    if sample then list, parentRow, frame = sample.icons, sample, sample end
    -- From the Middle: the frame keeps room for every reminder that could show, and the icons sit in
    -- its middle, so a placed frame grows both ways from its centre
    local slots = #shows
    if db.grow == "CENTER" and not sample then slots = math_max(slots, BR.EnabledCount()) end
    local offset = (slots - #shows) * (size + spacing) / 2
    frame:SetAlpha((db.alpha or 100) / 100)
    for i, s in ipairs(shows) do
        local b
        if sample then
            b = list[i]
            if not b then
                b = BR.BuildIcon(CreateFrame("Frame", nil, sample))
                b:EnableMouse(false)
                list[i] = b
            end
        else
            b = Icon(i)
        end
        StyleIcon(b, size)
        local castID = s.castID or s.entry.castID
        b.icon:SetTexture(s.icon or s.entry.icon)
        b.spellID = castID
        if sample then
            -- a picture only
        elseif s.action and s.action.macro then
            b:SetAttribute("type", "macro")
            b:SetAttribute("macrotext", s.action.macro)
        elseif s.action and s.action.item then
            b:SetAttribute("type", "item")
            b:SetAttribute("item", s.action.item)
        elseif castID then
            b:SetAttribute("type", "spell")
            -- by name: the game casts your highest rank (imbues list only their first rank's ID)
            b:SetAttribute("spell", SpellName(castID) or castID)
            b:SetAttribute("unit", s.unit or "player")
        else
            b:SetAttribute("type", nil)
        end
        -- Count Text: missing / total, the missing alone, or none
        local countMode = db.countText or "both"
        local countText = ""
        if s.total > 1 and countMode == "both" then countText = s.missing .. "/" .. s.total
        elseif s.total > 1 and countMode == "missing" then countText = tostring(s.missing) end
        b.count:SetText(countText)
        b.entry = s.entry.def and s.entry or nil   -- for the right-click menu (not on Edit Mode's samples)
        -- Orientation and Growth: the first icon at the edge the row grows away from
        local step = offset + (i - 1) * (size + spacing)
        b:ClearAllPoints()
        if vertical then
            if back then b:SetPoint("BOTTOMLEFT", parentRow, "BOTTOMLEFT", 0, step) else b:SetPoint("TOPLEFT", parentRow, "TOPLEFT", 0, -step) end
        else
            if back then b:SetPoint("TOPRIGHT", parentRow, "TOPRIGHT", -step, 0) else b:SetPoint("TOPLEFT", parentRow, "TOPLEFT", step, 0) end
        end
        b:Show()
        if not b.pulse:IsPlaying() then b.pulse:Play() end
        -- Alerts: the glow
        local glow = (s.running and db.glowExpiring) and GLOW_EXPIRING or ((not s.running) and db.glowMissing) and GLOW_MISSING
        if glow then
            b.glow:SetSize(size * 1.9, size * 1.9)
            b.glow:SetVertexColor(glow[1], glow[2], glow[3])
            b.glow:Show()
            if not b.glowPulse:IsPlaying() then b.glowPulse:Play() end
        else
            b.glowPulse:Stop()
            b.glow:Hide()
        end
    end
    for i = #shows + 1, #list do
        list[i].pulse:Stop()
        list[i].glowPulse:Stop()
        list[i]:Hide()
    end
    local n = math_max(slots, 1)
    local length = n * size + (n - 1) * spacing
    if vertical then frame:SetSize(size, length) else frame:SetSize(length, size) end
    return frame:GetWidth(), frame:GetHeight()
end

-- a settings preview's row: Edit Mode's samples (Fortitude missing on 2 of 5, Arcane Intellect running
-- out) and a pet reminder, in the current look; kind is unused
function BR.CreateSample(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.fuiSample = true
    f.icons = {}
    f:EnableMouse(false)
    f:SetFrameLevel(parent:GetFrameLevel() + 1)
    f:SetSize(36, 36)
    return f
end

function BR.DrawSample(f)
    local _, class = UnitClass("player")
    local pet = SpellIcon(class == "WARLOCK" and 688 or CALL_PET)
    local shows = {
        { entry = { icon = SpellIcon(1243) }, missing = 2, total = 5, unit = "player", running = false },
        { entry = { icon = SpellIcon(1459) }, missing = 1, total = 5, unit = "player", running = true },
        { entry = { icon = pet }, missing = 1, total = 1, unit = "player", running = false },
    }
    local w, h = Show(shows, f)
    f:Show()
    return w, h
end

--------------------------------------------------
-- 5. UPDATE (out of a fight only)
--------------------------------------------------
local shows, pool = {}, {}
local function Entry(i)
    local s = pool[i] or {}
    pool[i] = s
    return s
end

-- When It Shows: alone, in a party, in a raid, and not in a rested area
local function ShowsHere(db)
    if db.hideRested and IsResting() then return false end
    if IsInRaid() then return db.showRaid ~= false end
    if IsInGroup() then return db.showParty ~= false end
    return db.showSolo ~= false
end

-- Alerts: a sound as a reminder appears (once per new one, not more than every 10 seconds)
local SOUNDS = { raidwarning = "RAID_WARNING", alarm = "ALARM_CLOCK_WARNING_3", whisper = "TELL_MESSAGE" }
local shownKeys, lastSound = {}, 0
function BR.PlayAlert(sample)
    local db = GetDb() or {}
    local kit = SOUNDS[db.sound or "off"]
    local id = kit and SOUNDKIT and SOUNDKIT[kit]
    if not id then return end
    if not sample then
        if GetTime() - lastSound < 10 then return end
        lastSound = GetTime()
    end
    PlaySound(id, "Master")
end

function BR.Update()
    if not holder or InCombatLockdown() then return end
    wipe(shows)
    local db = GetDb() or {}
    if ns.EditPreviewing and ns.EditPreviewing() then
        -- Edit Mode: every reminder of the class, so the row can be placed
        for _, entry in ipairs(active) do
            if Enabled(entry) then
                local s = Entry(#shows + 1)
                s.entry, s.missing, s.total, s.unit = entry, entry.def.group and 2 or 1, entry.def.group and 5 or 1, "player"
                s.castID, s.icon, s.running, s.action = nil, nil, false, nil
                shows[#shows + 1] = s
            end
        end
        -- at least two, so Orientation and Growth can be seen: Fortitude and Arcane Intellect as samples
        local samples = { 1243, 1459 }
        while #shows < 2 do
            local s = Entry(#shows + 1)
            s.entry, s.missing, s.total, s.unit = { icon = SpellIcon(samples[#shows + 1]) }, 2, 5, "player"
            s.castID, s.icon, s.running, s.action = nil, nil, false, nil
            shows[#shows + 1] = s
        end
    elseif ShowsHere(db) and not UnitIsDeadOrGhost("player") and not AurasLocked() and not UnitOnTaxi("player") then
        -- Remind Before It Ends, or its dungeon / raid choice when set ("same" or none: the main one)
        local minutes = db.before or 2
        local inInstance, kind = IsInInstance()
        local special = inInstance and ((kind == "party" and db.beforeDungeon) or (kind == "raid" and db.beforeRaid))
        if type(special) == "number" then minutes = special end
        local before = minutes * 60
        for _, entry in ipairs(active) do
            if Enabled(entry) then
                local missing, total, unit, castID, icon, running, action = Check(entry, before)
                if missing > 0 then
                    local s = Entry(#shows + 1)
                    s.entry, s.missing, s.total, s.unit = entry, missing, total, unit
                    s.castID, s.icon, s.running, s.action = castID, icon, running and true or false, action
                    shows[#shows + 1] = s
                end
            end
        end
    end
    -- a reminder that was not there before plays the sound (not in Edit Mode)
    if not (ns.EditPreviewing and ns.EditPreviewing()) then
        local fresh = false
        local now = {}
        for _, s in ipairs(shows) do
            local key = s.entry.def and s.entry.def.key
            if key then
                now[key] = true
                if not shownKeys[key] then fresh = true end
            end
        end
        shownKeys = now
        if fresh then BR.PlayAlert() end
    end
    Show(shows)
end

-- UNIT_AURA comes often: one check a moment later
local pending = false
local function Soon()
    if pending then return end
    pending = true
    C_Timer.After(0.3, function()
        pending = false
        BR.Update()
    end)
end

--------------------------------------------------
-- 6. POSITION (per Edit Mode layout)
--------------------------------------------------
local function GetLayoutStore(layoutName)
    local db = GetDb()
    if not db then return nil end
    layoutName = layoutName or LEM:GetActiveLayoutName() or "Modern"
    db.layouts = db.layouts or {}
    db.layouts[layoutName] = db.layouts[layoutName] or {}
    return db.layouts[layoutName]
end

local function ApplyPosition(layoutName)
    if not holder or InCombatLockdown() then return end
    local store = GetLayoutStore(layoutName)
    local pos = (store and store.point) and store or DEFAULTS
    holder:ClearAllPoints()
    holder:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
end

local function OnMoved(_, layoutName, point, x, y)
    local store = GetLayoutStore(layoutName)
    if not store then return end
    store.point, store.x, store.y = point, math_floor(x + 0.5), math_floor(y + 0.5)
end

-- the Blessing row's choices (Settings > Buffs & Debuffs): Automatic, then each blessing by its name
function BR.BlessingChoices()
    local list = { { "auto", L["Automatic"] } }
    for _, key in ipairs(BLESSING_ORDER) do
        local ranks = BLESSINGS[key].cast
        list[#list + 1] = { key, SpellName(ranks[#ranks]) or key }
    end
    return list
end

local function BuildSettings()
    local function get(key, default) return function() local db = GetDb(); return db and db[key] or default end end
    local function set(key)
        return function(_, value)
            local db = GetDb()
            if not db then return end
            db[key] = value
            BR.Update()
        end
    end
    local function Vertical() local db = GetDb(); return db and db.orientation == "VERTICAL" end
    -- the layout only: what it watches is in Settings > Buffs & Debuffs > Buff Reminders
    return ns.OrderEditSettings({
        { name = L["Orientation"], kind = LEM.SettingType.Dropdown, default = "HORIZONTAL",
          values = { { text = L["Horizontal"], value = "HORIZONTAL", isRadio = true }, { text = L["Vertical"], value = "VERTICAL", isRadio = true } },
          get = get("orientation", "HORIZONTAL"),
          set = function(layoutName, value) set("orientation")(layoutName, value); LEM:RefreshFrameSettings(holder) end },
        -- in a column, Right / Left read as Down / Up
        { name = L["Growth"], kind = LEM.SettingType.Dropdown, default = "FORWARD",
          values = function()
              if Vertical() then
                  return { { text = L["Down"], value = "FORWARD", isRadio = true }, { text = L["Up"], value = "BACK", isRadio = true },
                           { text = L["From the Middle"], value = "CENTER", isRadio = true } }
              end
              return { { text = L["Right"], value = "FORWARD", isRadio = true }, { text = L["Left"], value = "BACK", isRadio = true },
                       { text = L["From the Middle"], value = "CENTER", isRadio = true } }
          end,
          desc = L["Which way the icons go from the first one."],
          get = get("grow", "FORWARD"), set = set("grow") },
        { name = L["Count Text"], kind = LEM.SettingType.Dropdown, default = "both",
          values = { { text = L["Missing / Total"], value = "both", isRadio = true },
                     { text = L["Missing Only"], value = "missing", isRadio = true },
                     { text = L["Off"], value = "none", isRadio = true } },
          desc = L["The number on a group buff's icon: how many are missing, of how many."],
          get = get("countText", "both"), set = set("countText") },
        { name = L["Icon Size"], kind = LEM.SettingType.Slider, default = 36, minValue = 20, maxValue = 64, valueStep = 1,
          get = get("size", 36), set = set("size") },
        { name = L["Spacing"], kind = LEM.SettingType.Slider, default = 6, minValue = 0, maxValue = 20, valueStep = 1,
          get = get("spacing", 6), set = set("spacing") },
        { name = L["Opacity"], kind = LEM.SettingType.Slider, default = 100, minValue = 20, maxValue = 100, valueStep = 5,
          -- plain numbers, as Faded Opacity: "100%" ran past the dialog's edge (11-10)
          get = get("alpha", 100), set = set("alpha") },
    })
end

--------------------------------------------------
-- 7. SETUP
--------------------------------------------------
function BR:GetFrame() return holder end

function BR:ShouldLoad()
    local db = AurasDb()
    return db and db.enabled and db.reminders and not ns.IsGamepadUI() or false
end

function BR:Init()
    if holder then return end
    local db = AurasDb()
    if not db then return end
    db.reminder = db.reminder or {}
    -- Pet Reminders off and Thorns Off (their settings rows, gone 11-10) become hidden reminders
    local r = db.reminder
    if r.pets == false or r.thorns == "off" then
        r.hidden = r.hidden or {}
        if r.pets == false then r.hidden["HUNTER:pet"], r.hidden["WARLOCK:pet"] = true, true end
        if r.thorns == "off" then r.hidden["DRUID:thorns"] = true; r.thorns = nil end
        r.pets = nil
    end
    Resolve()

    holder = CreateFrame("Frame", "FlareUI_BuffReminders", UIParent)
    holder:SetClampedToScreen(true)
    holder:SetSize(36, 36)
    row = CreateFrame("Frame", nil, holder)
    row:SetAllPoints()
    -- gone in a fight (the icons are secure and can't be changed then)
    RegisterStateDriver(holder, "visibility", "[combat] hide; show")
    ApplyPosition()
    LEM:AddFrame(holder, OnMoved, DEFAULTS, L["Buff Reminders"])
    LEM:AddFrameSettings(holder, BuildSettings())
    LEM:RegisterCallback("layout", function(layoutName) ApplyPosition(layoutName) end)
    LEM:RegisterCallback("enter", BR.Update)
    LEM:RegisterCallback("exit", BR.Update)

    local events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE", "SPELLS_CHANGED",
                             "PLAYER_LEVEL_UP", "UNIT_INVENTORY_CHANGED", "PLAYER_UNGHOST", "PLAYER_ALIVE", "PLAYER_DEAD",
                             "UNIT_CONNECTION", "UNIT_PHASE", "PLAYER_CONTROL_GAINED" }) do
        pcall(events.RegisterEvent, events, event)
    end
    pcall(events.RegisterEvent, events, "WEAPON_ENCHANT_CHANGED")
    for _, event in ipairs({ "ZONE_CHANGED_NEW_AREA", "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_UPDATE_RESTING",
                             "UPDATE_SHAPESHIFT_FORM", "PET_BAR_UPDATE", "BAG_UPDATE_DELAYED", "MINIMAP_UPDATE_TRACKING" }) do
        pcall(events.RegisterEvent, events, event)
    end
    pcall(events.RegisterUnitEvent, events, "UNIT_PET", "player")
    pcall(events.RegisterUnitEvent, events, "UNIT_HEALTH", "pet")
    pcall(events.RegisterUnitEvent, events, "UNIT_SPELLCAST_SUCCEEDED", "player")
    events:RegisterEvent("UNIT_AURA")
    events:SetScript("OnEvent", function(_, event, unit, _, spellID)
        if event == "SPELLS_CHANGED" or event == "PLAYER_LEVEL_UP" then Resolve() end
        -- a warlock's summon is remembered for the next time the pet is gone
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            if Readable(spellID) and tContains(WARLOCK_SUMMONS, spellID) then
                local me = ns.CharDB and ns.CharDB()
                if me then me.lastSummon = spellID end
            end
            return
        end
        if event == "UNIT_AURA" and unit and not (unit == "player" or unit == "pet" or unit:find("^party") or unit:find("^raid")) then return end
        if event == "PLAYER_REGEN_ENABLED" then ApplyPosition() end
        Soon()
    end)
    -- buffs running out cross the reminder line without an event
    C_Timer.NewTicker(10, Soon)
    BR.Update()
end

-- Buffs & Debuffs' look changed (Aura Icon Shape, the stack font)
function BR:Refresh()
    BR.Update()
end
