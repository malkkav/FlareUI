local _, ns = ...
local L = ns.L

--------------------------------------------------
-- BAR TEXT
-- Left, Middle and Right text slots on a frame's health, power and druid mana bars. Each slot is a
-- multi-pick dropdown in Edit Mode; what a slot holds is joined with " / ", in the order the player
-- ticked it (the menu numbers the ticks). A name (First Name or Full Name) is a slot of its own: picking
-- it clears the rest, picking a number clears it. Stored per frame as udb.barText[bar][slot] =
-- { item = n, ... } (n = place in the slot; true, from defaults and older saves, = BT.ORDER's place); a
-- slot never set reads the style's default, and a frame with an old Health Text / Power Text choice
-- gets it converted once, so nobody's frames change on update.
--   Addon and FlareUI Style: Left and Right are the name side and the far side (they follow Mirror,
--   so a target frame keeps its name by the portrait). Show Level puts the level before the name
--   (Addon Style; the ring styles keep it in the ring).
--   Forever Style: Left and Right are the bar's own ends; the name stays in the plate's name box.
--   Resource bars ("bar"): the bar's own ends, no name; their old Text choice was centred.
--------------------------------------------------
local BT = {}
ns.BarText = BT

BT.SLOTS = { "left", "middle", "right" }
BT.BARS = { "health", "power", "mana" }
BT.SEPARATOR = " / "
-- the order of items without a ticked place (defaults, older saves)
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

-- the starting slots of each style; mana as power
BT.DEFAULTS = {
    plain = {
        health = { left = { name = true }, right = { value = true } },
        power = { right = { value = true } },
    },
    plate = {
        health = { middle = { value = true, max = true } },
        power = { middle = { value = true, max = true } },
    },
    -- the resource bars: as Forever Style; mana as power
    bar = {
        health = { middle = { value = true, max = true } },
        power = { middle = { value = true, max = true } },
    },
}

-- a frame's own starting slots over its style's, in every style: no power text on the
-- pet and the target-of frames (mana as power). A frame's "plain" / "plate" table holds slots for
-- that style only (11-20: the party and boss frames start as their old Health Text: Percent, Power Value)
BT.UNIT_DEFAULTS = {
    pet = { power = {} }, targettarget = { power = {} }, focustarget = { power = {} },
    party = { plain = { health = { left = { name = true }, right = { percent = true } }, power = { right = { value = true } } } },
    boss = { plain = { health = { left = { name = true }, right = { percent = true } }, power = { right = { value = true } } } },
}

-- an old Health Text / Power Text choice as slots: where the numbers stood (side: "right" off the
-- plate, "middle" on it), plus the split and right-end modes' own places
local OLD = {
    none = {}, percent = { percent = true }, both = { percent = true, value = true },
    valuepct = { value = 1, percent = 2 }, value = { value = true },
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
            if mode == "splitvp" then out[side].value, out[side].percent = 1, 2
            else out[side].percent, out[side].value = 1, 2 end
        end
    elseif mode == "rvalue" or mode == "rpercent" then
        out[plate and "right" or side][mode == "rvalue" and "value" or "percent"] = true
    else
        for item, v in pairs(OLD[mode] or OLD.value) do out[side][item] = v end
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
                out[item] = v
            end
        end
    end
    return out
end

-- A slot's items in the order they show: ticked places first by number, the rest (true) after them
-- in BT.ORDER. into: a list to fill (reused by Fill, which runs on every tick); returns it and its count.
BT.RANK = {}
for i, item in ipairs(BT.ORDER) do BT.RANK[item] = 100 + i end
local function Rank(set, item)
    local v = set[item]
    return type(v) == "number" and v or BT.RANK[item]
end
function BT.Ordered(set, into)
    local list, n = into or {}, 0
    for _, item in ipairs(BT.ORDER) do
        if set[item] then
            -- insertion sort: a slot holds four items at most
            local r, i = Rank(set, item), n
            while i > 0 and Rank(set, list[i]) > r do list[i + 1] = list[i]; i = i - 1 end
            list[i + 1] = item
            n = n + 1
        end
    end
    for i = n + 1, #list do list[i] = nil end
    return list, n
end
-- the slot with every item numbered 1, 2, 3... in its current show order
local function Renumber(set)
    local list, n = BT.Ordered(set)
    local out = {}
    for i = 1, n do out[list[i]] = i end
    return out
end
-- an item's place in the slot (1, 2...), or nil when not ticked
function BT.Place(set, item)
    if not set[item] then return nil end
    local list, n = BT.Ordered(set)
    for i = 1, n do if list[i] == item then return i end end
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
    if own and (own.plain or own.plate) then own = own[style] end
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
    local set = Renumber(Copy(mine[slot] or current[slot], firstOnly))
    if BT.NAMES[value] then
        -- a name stands alone
        set = set[value] and {} or { [value] = 1 }
    else
        set.firstname, set.fullname = nil, nil
        -- a new tick goes last; an untick closes the gap
        if set[value] then set[value] = nil else set[value] = 1000 end
        set = Renumber(set)
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
-- (buffers reused by every call: this runs on every health and power tick of every frame)
BT.fmtBuf, BT.argBuf, BT.orderBuf = {}, {}, {}
function BT.Fill(fs, set, src, prefix)
    local fmt, args, n = BT.fmtBuf, BT.argBuf, 0
    local onlyLost = set.lost and not (set.percent or set.value or set.max)
    local list, count = BT.Ordered(set, BT.orderBuf)
    for k = 1, count do
        local item = list[k]
        if not BT.NAMES[item] then
            if item == "percent" then
                n = n + 1
                fmt[n], args[n] = "%.0f%%", src.percent
            elseif item == "value" then
                n = n + 1
                fmt[n], args[n] = "%s", ns.ShortNumber(src.cur)
            elseif item == "max" then
                n = n + 1
                fmt[n], args[n] = "%s", ns.ShortNumber(src.max)
            elseif item == "lost" and src.lost ~= nil then
                local lost = src.lost
                if onlyLost or not canaccessvalue(lost) or lost > 0 then
                    n = n + 1
                    fmt[n], args[n] = "-%s", ns.ShortNumber(lost)
                end
            end
        end
    end
    fs:SetAlpha(1)
    if n == 0 then
        fs:SetText("")
        return false
    end
    fs:SetFormattedText((prefix or "") .. table.concat(fmt, BT.SEPARATOR, 1, n), unpack(args, 1, n))
    for i = 1, n do args[i] = nil end   -- (no unit's numbers kept alive between ticks)
    if onlyLost and src.lostAlpha ~= nil then fs:SetAlpha(src.lostAlpha) end
    return true
end

-- The slot a status (Dead, Offline) shows in, in place of the numbers: the first slot that has some
-- (right, middle, left); with none, a side slot without the name, so the two never sit on each other
BT.STATUS_ORDER = { "right", "middle", "left" }
BT.STATUS_EMPTY_ORDER = { "right", "left", "middle" }
function BT.StatusSlot(slots)
    for _, slot in ipairs(BT.STATUS_ORDER) do
        if BT.HasNumbers(slots[slot]) then return slot end
    end
    for _, slot in ipairs(BT.STATUS_EMPTY_ORDER) do
        if not BT.NameOf(slots[slot]) then return slot end
    end
    return "middle"
end

-- Fills { left, middle, right } texts from a bar's slots; status (Dead, Offline) in place of the numbers
function BT.FillAll(texts, slots, src, status)
    local statusSlot = status and BT.StatusSlot(slots) or "middle"
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

-- The Edit Mode dropdown of one bar: Left, Middle and Right as submenus of ticks; the
-- closed box sums the three slots up left to right, "Full Name · — · Value".
BT.MENU_SLOTS = { left = L["Left"], middle = L["Centre"], right = L["Right"] }
BT.SHORT = { firstname = L["First Name"], fullname = L["Full Name"], percent = "%", value = L["Value"],
             max = L["Max"], lost = L["Lost"] }
function BT.Summary(slots)
    local parts = {}
    for _, slot in ipairs(BT.SLOTS) do
        local items = {}
        for _, item in ipairs((BT.Ordered(slots[slot]))) do items[#items + 1] = BT.SHORT[item] end
        parts[#parts + 1] = #items > 0 and table.concat(items, " / ") or "\226\128\148"   -- an em dash
    end
    return table.concat(parts, "  " .. (ns.DOT or "\194\183") .. "  ")   -- a middle dot between the slots (Core.lua ns.DOT)
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
                    local value, label = v.value, v.text
                    local box = sub:CreateCheckbox(label, function() return Picked(slot, value) end, function()
                        BT.Toggle(o.db(), o.bar, slot, o.style(), value, false, FirstOnly(), o.oldKey, o.unit)
                        Changed(owner)
                    end)
                    -- the tick's place in the slot when it holds two or more: "Health Value  2". A tick
                    -- refreshes the open menu, which runs this again, so the numbers follow every change.
                    if value ~= "none" and box and box.AddInitializer then
                        box:AddInitializer(function(button)
                            if not button.fontString then return end
                            local set = Slots()[slot]
                            local place = BT.Place(set, value)
                            local _, n = BT.Ordered(set)
                            button.fontString:SetText(place and n > 1 and (label .. "  |cffffd100" .. place .. "|r") or label)
                        end)
                    end
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

--------------------------------------------------
-- NAME ABOVE PLATES (11-20, Malkkav, the most asked-for change): the unit's name above the frame, so the
-- bars can stay clean. One Edit Mode dropdown in each frame's Text section: Off, then Left, Centre and
-- Right, each with First Name and Full Name. One pick in all: a new pick replaces the old one. Stored
-- per frame as udb.nameAbove = "<slot>:<firstname|fullname>". The spot is the frame's own left, centre
-- or right (not mirrored). Auras and a cast bar above the frame move up by the name's height
-- (f.nameAboveLift), so nothing covers it.
--------------------------------------------------
local NA = {}
ns.NameAbove = NA
NA.KINDS = { "firstname", "fullname" }
NA.GAP = 2      -- px between the frame's top and the name
NA.INSET = 3    -- px in from the frame's side for Left and Right

function NA.Get(udb)
    local v = udb and udb.nameAbove
    if type(v) ~= "string" then return nil end
    local slot, kind = v:match("^(%a+):(%a+)$")
    if BT.MENU_SLOTS[slot] and (kind == "firstname" or kind == "fullname") then return slot, kind end
    return nil
end

function NA.Summary(udb)
    local slot, kind = NA.Get(udb)
    if not slot then return L["Off"] end
    return BT.MENU_SLOTS[slot] .. ": " .. BT.SHORT[kind]
end

-- o: db() (the frame's stored table), changed() after a pick
function NA.Setting(o)
    local LEM = LibStub("FlareEditMode")
    local function Pick(owner, value)
        local udb = o.db()
        if not udb then return end
        udb.nameAbove = value
        if o.changed then o.changed() end
        if owner and owner.OverrideText then owner:OverrideText(NA.Summary(udb)) end
    end
    local function Is(value) local udb = o.db() return (udb and udb.nameAbove) == value end
    return {
        name = L["Name Above Plates"], kind = LEM.SettingType.Dropdown, hidden = o.hidden,
        desc = L["The name above the frame, on its left, centre or right. Auras above the frame move up to make room."],
        generator = function(owner, rootDescription)
            rootDescription:CreateRadio(L["Off"], function() return Is(nil) end, function() Pick(owner, nil) end)
            for _, slot in ipairs(BT.SLOTS) do
                local sub = rootDescription:CreateButton(BT.MENU_SLOTS[slot])
                for _, kind in ipairs(NA.KINDS) do
                    local value = slot .. ":" .. kind
                    sub:CreateRadio(BT.LABELS[kind], function() return Is(value) end, function() Pick(owner, value) end)
                end
            end
            if owner.OverrideText then owner:OverrideText(NA.Summary(o.db())) end
        end,
        get = function() return NA.Summary(o.db()) end,
        -- Edit Mode's Reset: Off
        set = function(_, _, reset)
            if not reset then return end
            local udb = o.db()
            if udb then udb.nameAbove = nil end
            if o.changed then o.changed() end
        end,
    }
end

-- Places (or hides) the name above anchor (the frame, or its health bar); font: the font string whose
-- font it copies (the frame's own name). Returns the height the name takes, 0 when off.
function NA.Layout(f, udb, anchor, font)
    local slot = NA.Get(udb)
    local fs = f.NameAboveText
    if not slot then
        if fs then fs:Hide() end
        f.nameAboveLift = 0
        return 0
    end
    if not fs then
        fs = f:CreateFontString(nil, "OVERLAY")
        fs:SetWordWrap(false)
        f.NameAboveText = fs
    end
    if font and font.GetFont then
        local face, size, flags = font:GetFont()
        if face then fs:SetFont(face, size, flags) end
        if font.GetShadowOffset then
            local sx, sy = font:GetShadowOffset()
            fs:SetShadowOffset(sx or 1, sy or -1)
            fs:SetShadowColor(font:GetShadowColor())
        end
        fs:SetTextColor(font:GetTextColor())
    else
        fs:SetFontObject("GameFontNormalSmall")
    end
    local at = (slot == "left" and "LEFT") or (slot == "right" and "RIGHT") or ""
    local x = (slot == "left" and NA.INSET) or (slot == "right" and -NA.INSET) or 0
    fs:ClearAllPoints()
    fs:SetPoint("BOTTOM" .. at, anchor, "TOP" .. at, x, NA.GAP)
    fs:SetJustifyH(at == "" and "CENTER" or at)
    fs:SetWidth(math.max(20, (anchor:GetWidth() or 100) - 2 * NA.INSET))
    fs:Show()
    local _, size = fs:GetFont()
    f.nameAboveLift = math.floor((size or 12) + NA.GAP + 1)
    return f.nameAboveLift
end

-- The name's text (secret names go to the widget as they are)
function NA.SetName(f, udb, unit, displayName)
    local fs = f.NameAboveText
    local slot, kind = NA.Get(udb)
    if not (fs and slot) then return end
    local name = ""
    if unit and UnitExists(unit) then name = (displayName or ns.UnitDisplayName)(unit, nil, kind == "fullname") end
    if canaccessvalue(name) and not name then name = "" end
    fs:SetText(name)
end
-- a sample's name in Edit Mode (first, surname)
function NA.SetSample(f, udb, first, surname)
    local fs = f.NameAboveText
    local slot, kind = NA.Get(udb)
    if not (fs and slot) then return end
    fs:SetText((kind == "fullname" and surname and surname ~= "") and (first .. " " .. surname) or first or "")
end
