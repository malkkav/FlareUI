local _, ns = ...
local L = ns.L

--------------------------------------------------
-- BAR TEXT (11-17, Malkkav)
-- Left, Middle and Right text slots on a frame's health, power and druid mana bars. Each slot is a
-- multi-pick dropdown in Edit Mode; what a slot holds is joined with " / ", in a fixed order (Percent,
-- Value, Max, Lost). A name (First Name or Full Name) is a slot of its own: picking it clears the rest,
-- picking a number clears it (11-17, Malkkav). Stored per frame as udb.barText[bar][slot] = { item = true, ... }; a
-- slot never set reads the style's default, and a frame with an old Health Text / Power Text choice
-- gets it converted once, so nobody's frames change on update.
--   Addon and FlareUI Style: Left and Right are the name side and the far side (they follow Mirror,
--   so a target frame keeps its name by the portrait). Show Level puts the level before the name
--   (Addon Style; the ring styles keep it in the ring).
--   Forever Style: Left and Right are the bar's own ends; the name stays in the plate's name box.
--   Resource bars ("bar", 11-17): the bar's own ends, no name; their old Text choice was centred.
--------------------------------------------------
local BT = {}
ns.BarText = BT

BT.SLOTS = { "left", "middle", "right" }
BT.BARS = { "health", "power", "mana" }
BT.SEPARATOR = " / "
-- the order items show in, whatever order they were picked in
BT.ORDER = { "firstname", "fullname", "percent", "value", "max", "lost" }
BT.NAMES = { firstname = true, fullname = true }
BT.ITEMS = {
    health = { "firstname", "fullname", "percent", "value", "max", "lost" },
    power = { "percent", "value", "max" },
    mana = { "percent", "value", "max" },
}
BT.LABELS = {
    firstname = L["First Name"], fullname = L["Full Name"], percent = L["Health Percent"], value = L["Health Value"], max = L["Health Max"], lost = L["Health Lost"],
}
BT.POWER_LABELS = { percent = L["Power Percent"], value = L["Power Value"], max = L["Power Max"] }

-- the starting slots of each style (Malkkav, 11-17); mana as power
BT.DEFAULTS = {
    plain = {
        health = { left = { name = true }, right = { value = true } },
        power = { right = { value = true } },
    },
    plate = {
        health = { middle = { value = true, max = true } },
        power = { middle = { value = true, max = true } },
    },
    -- the resource bars: as Forever Style (11-17, Malkkav); mana as power
    bar = {
        health = { middle = { value = true, max = true } },
        power = { middle = { value = true, max = true } },
    },
}

-- (11-17, Malkkav) a frame's own starting slots over its style's, in every style: no power text on the
-- pet and the target-of frames (mana as power)
BT.UNIT_DEFAULTS = {
    pet = { power = {} }, targettarget = { power = {} }, focustarget = { power = {} },
}

-- an old Health Text / Power Text choice as slots: where the numbers stood (side: "right" off the
-- plate, "middle" on it), plus the split and right-end modes' own places
local OLD = {
    none = {}, percent = { percent = true }, both = { percent = true, value = true },
    valuepct = { percent = true, value = true }, value = { value = true },
    valuemax = { value = true, max = true }, valuemaxpct = { value = true, max = true },
    valuelost = { value = true, lost = true }, lost = { lost = true },
}
local function Convert(mode, plate, side)
    local out = { left = {}, middle = {}, right = {} }
    if mode == "split" or mode == "splitvp" then
        if plate then
            out.left[mode == "split" and "percent" or "value"] = true
            out.right[mode == "split" and "value" or "percent"] = true
        else
            out[side].percent, out[side].value = true, true
        end
    elseif mode == "rvalue" or mode == "rpercent" then
        out[plate and "right" or side][mode == "rvalue" and "value" or "percent"] = true
    else
        for item in pairs(OLD[mode] or OLD.value) do out[side][item] = true end
    end
    return out
end

-- "name" (the defaults, an old choice converted) reads as First Name or Full Name: firstOnly for the
-- focus frame and the target-of frames, and for a setup that had Full Player Names off
local function Copy(set, firstOnly)
    local out = {}
    if set then
        for key, v in pairs(set) do
            if v then
                local item = key
                if item == "name" then item = firstOnly and "firstname" or "fullname" end
                out[item] = true
            end
        end
    end
    return out
end

-- The three slots of one bar: { left = set, middle = set, right = set }. style: "plate" (Forever
-- Style) or "plain" (Addon and FlareUI Style). An old choice is converted and stored here, once.
function BT.Slots(udb, bar, style, firstOnly, oldKey, unit)
    local plate = style == "plate"
    local named = style == "plain"
    local stored = udb and rawget(udb, "barText")
    local mine = stored and stored[bar]
    if not mine and udb then
        oldKey = oldKey or (bar == "health" and "healthText" or "powerText")
        local old = rawget(udb, oldKey)
        if type(old) == "string" then
            mine = Convert(old, plate, named and "right" or "middle")
            -- the name: by the old layout, on the name side (the plate keeps its own)
            if bar == "health" and named then mine.left.name = true end
            udb.barText = udb.barText or {}
            udb.barText[bar] = mine
        end
    end
    local defaults = BT.DEFAULTS[style] or BT.DEFAULTS.plain
    local fallback = defaults[bar] or defaults.power
    local own = unit and BT.UNIT_DEFAULTS[unit]
    if own and own[bar == "mana" and "power" or bar] then fallback = own[bar == "mana" and "power" or bar] end
    local out = {}
    for _, slot in ipairs(BT.SLOTS) do
        local set = (mine and mine[slot]) or fallback[slot]
        out[slot] = Copy(set, firstOnly)
        -- the plate's name has its own box; the resource bars have none
        if not named then out[slot].firstname, out[slot].fullname = nil, nil end
    end
    return out
end

-- Edit Mode: a slot's picks as a list (multi-pick dropdowns), and a pick turned on or off. "none"
-- empties the slot; reset (Edit Mode's Reset) goes back to the style's default.
function BT.Picked(udb, bar, slot, style, firstOnly, oldKey, unit)
    local list = {}
    for item in pairs(BT.Slots(udb, bar, style, firstOnly, oldKey, unit)[slot]) do list[#list + 1] = item end
    if #list == 0 then list[1] = "none" end
    return list
end
function BT.Toggle(udb, bar, slot, style, value, reset, firstOnly, oldKey, unit)
    if not udb then return end
    local current = BT.Slots(udb, bar, style, firstOnly, oldKey, unit)
    udb.barText = udb.barText or {}
    local mine = udb.barText[bar]
    if not mine then
        mine = { left = current.left, middle = current.middle, right = current.right }
        udb.barText[bar] = mine
    end
    if reset then
        -- an unset slot reads the style's default (BT.Slots)
        mine[slot] = nil
        return
    end
    if value == "none" then
        mine[slot] = {}
        return
    end
    local set = Copy(mine[slot] or current[slot], firstOnly)
    if BT.NAMES[value] then
        -- a name stands alone
        set = set[value] and {} or { [value] = true }
    else
        set[value] = not set[value] or nil
        set.firstname, set.fullname = nil, nil
    end
    mine[slot] = set
end

-- the dropdown's choices: None first, then the bar's items (no Name on the plate)
function BT.Values(bar, style)
    local values = { { text = L["None"], value = "none" } }
    local labels = bar == "health" and BT.LABELS or BT.POWER_LABELS
    for _, item in ipairs(BT.ITEMS[bar] or BT.ITEMS.power) do
        if not (BT.NAMES[item] and style ~= "plain") then values[#values + 1] = { text = labels[item], value = item } end
    end
    return values
end

-- whether a slot shows any number (anything but the name)
function BT.HasNumbers(set)
    for item in pairs(set) do if not BT.NAMES[item] then return true end end
    return false
end
-- the slot's name pick: "firstname", "fullname" or nil
function BT.NameOf(set)
    return (set.fullname and "fullname") or (set.firstname and "firstname") or nil
end

-- Fills fs with a slot's numbers, " / " between them; prefix goes in front (the name's "/ " when the
-- name shares the slot). Secret numbers go in as they are (SetFormattedText). Health Lost alone hides
-- at full health through a curve on the text's alpha (its amount can't be compared when secret); with
-- other numbers it shows only when it can be read and isn't 0.
--   src: { cur, max, percent, lost } read from the unit (percent 0-100), or numbers for samples.
function BT.Fill(fs, set, src, prefix)
    local fmt, args = {}, {}
    local onlyLost = set.lost and not (set.percent or set.value or set.max)
    for _, item in ipairs(BT.ORDER) do
        if set[item] and not BT.NAMES[item] then
            if item == "percent" then
                fmt[#fmt + 1] = "%.0f%%"
                args[#args + 1] = src.percent
            elseif item == "value" then
                fmt[#fmt + 1] = "%s"
                args[#args + 1] = ns.ShortNumber(src.cur)
            elseif item == "max" then
                fmt[#fmt + 1] = "%s"
                args[#args + 1] = ns.ShortNumber(src.max)
            elseif item == "lost" and src.lost ~= nil then
                local lost = src.lost
                if onlyLost or not canaccessvalue(lost) or lost > 0 then
                    fmt[#fmt + 1] = "-%s"
                    args[#args + 1] = ns.ShortNumber(lost)
                end
            end
        end
    end
    fs:SetAlpha(1)
    if #fmt == 0 then
        fs:SetText("")
        return false
    end
    fs:SetFormattedText((prefix or "") .. table.concat(fmt, BT.SEPARATOR), unpack(args, 1, #fmt))
    if onlyLost and src.lostAlpha ~= nil then fs:SetAlpha(src.lostAlpha) end
    return true
end

-- Fills { left, middle, right } texts from a bar's slots; status (Dead, Offline) in place of the
-- numbers, in the first slot that has some (right, middle, left), else the middle
BT.STATUS_ORDER = { "right", "middle", "left" }
function BT.FillAll(texts, slots, src, status)
    local statusSlot = "middle"
    if status then
        for _, slot in ipairs(BT.STATUS_ORDER) do
            if BT.HasNumbers(slots[slot]) then statusSlot = slot break end
        end
    end
    for _, slot in ipairs(BT.SLOTS) do
        local fs = texts[slot]
        if status then
            fs:SetAlpha(1)
            fs:SetText(slot == statusSlot and status or "")
        elseif src then
            BT.Fill(fs, slots[slot], src)
        else
            fs:SetText("")
        end
    end
end

-- The Edit Mode dropdown of one bar (11-17, Malkkav): Left, Middle and Right as submenus of ticks; the
-- closed box sums the three slots up left to right, "Full Name · — · Value".
BT.MENU_SLOTS = { left = L["Left"], middle = L["Middle"], right = L["Right"] }
BT.SHORT = { firstname = L["First Name"], fullname = L["Full Name"], percent = "%", value = L["Value"],
             max = L["Max"], lost = L["Lost"] }
function BT.Summary(slots)
    local parts = {}
    for _, slot in ipairs(BT.SLOTS) do
        local items = {}
        for _, item in ipairs(BT.ORDER) do
            if slots[slot][item] then items[#items + 1] = BT.SHORT[item] end
        end
        parts[#parts + 1] = #items > 0 and table.concat(items, " / ") or "\226\128\148"   -- an em dash
    end
    return table.concat(parts, "  \194\183  ")   -- a middle dot between the slots
end
-- o: name, bar, db() (the stored table), style() ("plain", "plate", "bar"), firstOnly() (optional),
-- oldKey (optional), changed() after a pick or a reset
function BT.Setting(o)
    local LEM = LibStub("FlareEditMode")
    local function FirstOnly() return o.firstOnly and o.firstOnly() or nil end
    local function Slots() return BT.Slots(o.db(), o.bar, o.style(), FirstOnly(), o.oldKey, o.unit) end
    local function Picked(slot, value)
        for _, v in ipairs(BT.Picked(o.db(), o.bar, slot, o.style(), FirstOnly(), o.oldKey, o.unit)) do
            if v == value then return true end
        end
        return false
    end
    local function Changed(owner)
        if o.changed then o.changed() end
        if owner and owner.OverrideText then owner:OverrideText(BT.Summary(Slots())) end
    end
    return {
        name = o.name, kind = LEM.SettingType.Dropdown,
        desc = L["Left, Middle and Right: what each part of the bar shows. Several numbers show together, split by /. A name stands alone."],
        generator = function(owner, rootDescription)
            for _, slot in ipairs(BT.SLOTS) do
                local sub = rootDescription:CreateButton(BT.MENU_SLOTS[slot])
                for _, v in ipairs(BT.Values(o.bar, o.style())) do
                    local value = v.value
                    sub:CreateCheckbox(v.text, function() return Picked(slot, value) end, function()
                        BT.Toggle(o.db(), o.bar, slot, o.style(), value, false, FirstOnly(), o.oldKey, o.unit)
                        Changed(owner)
                    end)
                end
            end
            if owner.OverrideText then owner:OverrideText(BT.Summary(Slots())) end
        end,
        get = function() return BT.Summary(Slots()) end,
        -- Edit Mode's Reset: every slot back to the style's default
        set = function(_, _, reset)
            if not reset then return end
            for _, slot in ipairs(BT.SLOTS) do
                BT.Toggle(o.db(), o.bar, slot, o.style(), nil, true, FirstOnly(), o.oldKey, o.unit)
            end
            Changed()
        end,
    }
end
