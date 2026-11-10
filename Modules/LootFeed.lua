local _, ns = ...
local L = ns.L

--------------------------------------------------
-- LOOT FEED (Quality of Life > Bags and Looting > Loot Feed, off)
-- What you loot floats up beside your character: the item's icon and "+3 Name" in its quality
-- colour, and money in coins, so you don't have to read the chat. Idea after OneForAll's loot feed
-- (GPL: ideas only). Items come from your own loot lines in the chat (the game's LOOT_ITEM_* strings
-- turned into patterns, so every language works and other players' loot never matches); money from
-- the rise in your gold paired with the chat's money line, so a split shows only your share. A repeat
-- of the same item joins its line. Placed in Edit Mode ("FlareUI Loot Feed", samples while it's open).
--------------------------------------------------
local LF = {}
ns.LootFeed = LF
ns.modules["LootFeed"] = LF

local ipairs, pairs, select, tonumber, type = ipairs, pairs, select, tonumber, type
local math_floor, math_max, math_min = math.floor, math.max, math.min
local tinsert, tremove = table.insert, table.remove
local CreateFrame, GetTime = CreateFrame, GetTime
local LEM = LibStub("FlareEditMode")

-- six lines' room (MAX_LINES): the lines rise through it and fade at its top
local WIDTH, HEIGHT = 220, 132
local LIFE = 4.5          -- seconds a line lives
local RISE = 40           -- pixels a second
local FADE_IN, FADE_OUT = 0.2, 1
local SPACING = 22        -- between lines
local MAX_LINES = 6
local JOIN = 1.5          -- a repeat this soon joins the line
local PAIR = 1.5          -- the gold rise and the chat's money line arrive this close together
local ICON = 18
local MONEY_ICON = "Interface\\Icons\\INV_Misc_Coin_02"
local DEFAULTS = { point = "CENTER", x = 220, y = 0 }   -- right of your character
-- At the Cursor (lootFeedPosition "cursor", the default): the feed starts where the pointer is as the
-- first line comes (the corpse you just clicked), a little to its right, and stays there while lines
-- rise; "placed" keeps the Edit Mode spot, and only then does Edit Mode show the frame
local CURSOR_X, CURSOR_Y = 18, -8

local function AtCursor()
    local db = ns.db and ns.db.profile and ns.db.profile.tweaks
    return not (db and db.lootFeedPosition == "placed")
end

local function GetDb()
    return ns.db and ns.db.profile and ns.db.profile.tweaks
end

local holder
local lines, pool = {}, {}

--------------------------------------------------
-- 1. LINES
--------------------------------------------------
local function NewLine(parent)
    local line = CreateFrame("Frame", nil, parent)
    line:SetSize(WIDTH, ICON)
    line.icon = line:CreateTexture(nil, "ARTWORK")
    line.icon:SetSize(ICON, ICON)
    line.icon:SetPoint("LEFT")
    line.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    -- a font object first: SetText errors on a font string with no font yet
    line.text = line:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    line.text:SetPoint("LEFT", line.icon, "RIGHT", 5, 0)
    line.text:SetJustifyH("LEFT")
    return line
end

local function Fill(line, icon, text, r, g, b)
    line.icon:SetTexture(icon or 134400)
    -- FlareUI's font goes on with the text in place (a blank string can't show if a font took)
    line.text:SetText(text)
    ns.SetFont(line.text, ns.GetFontPath("Friz Quadrata TT"), 14, "OUTLINE")
    line.text:SetTextColor(r or 1, g or 1, b or 1)
end

local function Release(i)
    local line = tremove(lines, i)
    line:Hide()
    pool[#pool + 1] = line
end

local function OnUpdate(self, elapsed)
    -- newest first: each line rises, kept a line's height above the one below it
    local below
    for i = #lines, 1, -1 do
        local line = lines[i]
        line.age = line.age + elapsed
        line.y = line.y + RISE * elapsed
        if below then line.y = math_max(line.y, below.y + SPACING) end
        below = line
    end
    for i = #lines, 1, -1 do
        local line = lines[i]
        if line.age >= LIFE or line.y > HEIGHT - ICON then
            Release(i)
        else
            line:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, line.y)
            line:SetAlpha(math_min(1, line.age / FADE_IN, (LIFE - line.age) / FADE_OUT))
        end
    end
    if #lines == 0 then self:SetScript("OnUpdate", nil) end
end

local function Add(key, icon, label, count, r, g, b)
    if not holder then return end
    -- the same item again, still near the bottom: its count grows
    for _, line in ipairs(lines) do
        if key and line.key == key and line.age < JOIN then
            line.count = line.count + count
            line.age = math_min(line.age, FADE_IN)
            Fill(line, icon, "+" .. line.count .. " " .. label, r, g, b)
            return
        end
    end
    if #lines >= MAX_LINES then Release(1) end
    -- At the Cursor: a new feed (nothing rising) starts at the pointer
    if #lines == 0 and AtCursor() then
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        holder:ClearAllPoints()
        holder:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / scale + CURSOR_X, y / scale + CURSOR_Y)
    end
    local line = tremove(pool) or NewLine(holder)
    line.key, line.count, line.age, line.y = key, count, 0, 0
    Fill(line, icon, key and ("+" .. count .. " " .. label) or label, r, g, b)
    line:ClearAllPoints()
    line:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
    line:SetAlpha(0)
    line:Show()
    lines[#lines + 1] = line
    holder:SetScript("OnUpdate", OnUpdate)
end

--------------------------------------------------
-- 2. ITEMS (your loot lines in the chat)
--------------------------------------------------
-- the game's sentence as a pattern: "%s" (or "%1$s") is the link, "%d" the count
local function Pattern(format)
    if type(format) ~= "string" then return nil end
    local p = format:gsub("%%%d*%$?s", "\001"):gsub("%%%d*%$?d", "\002")
    p = p:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0")
    p = p:gsub("\001", "(.+)"):gsub("\002", "(%%d+)")
    return "^" .. p .. "$"
end

local patterns
local function Patterns()
    if patterns then return patterns end
    patterns = {}
    -- the "multiple" sentences first: the single ones would match them too
    for _, name in ipairs({ "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "LOOT_ITEM_CREATED_SELF_MULTIPLE",
                            "LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_CREATED_SELF" }) do
        local p = Pattern(_G[name])
        if p then patterns[#patterns + 1] = p end
    end
    return patterns
end

-- the link and the count in a matched line, whatever order the language puts them in
local function LinkAndCount(...)
    local link, count
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if v:find("|H") then link = v elseif tonumber(v) then count = tonumber(v) end
    end
    return link, count or 1
end

local function ItemLine(text)
    for _, p in ipairs(Patterns()) do
        local link, count = LinkAndCount(text:match(p))
        if link then return link, count end
    end
end

local function OnLoot(text)
    if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then return end
    local link, count = ItemLine(text)
    if not link then return end
    local db = GetDb()
    local id = tonumber(link:match("item:(%d+)"))
    local name = link:match("%[(.-)%]") or link
    local quality
    if id and C_Item then
        if C_Item.GetItemQualityByID then
            local ok, q = pcall(C_Item.GetItemQualityByID, id)
            if ok then quality = q end
        end
    end
    if quality and quality < (db and db.lootFeedQuality or 0) then return end
    local icon = id and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
    local r, g, b = 1, 1, 1
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color then
        r, g, b = color.r, color.g, color.b
    else
        -- not cached yet: the link's own colour
        local hex = link:match("|c%x%x(%x%x%x%x%x%x)")
        if hex then
            r = tonumber(hex:sub(1, 2), 16) / 255
            g = tonumber(hex:sub(3, 4), 16) / 255
            b = tonumber(hex:sub(5, 6), 16) / 255
        end
    end
    Add(id or name, icon, name, count, r, g, b)
end

--------------------------------------------------
-- 3. MONEY (the rise in your gold, when the chat says it was loot)
--------------------------------------------------
local lastMoney, gain, gainAt, chatAt = 0, 0, 0, 0

local function ShowMoney(amount)
    local db = GetDb()
    if not (db and db.lootFeedMoney ~= false) or amount <= 0 then return end
    local text = GetMoneyString and GetMoneyString(amount, true) or GetCoinTextureString(amount)
    Add(nil, MONEY_ICON, text)
end

local function OnMoney()
    local now = GetMoney()
    local delta = now - lastMoney
    lastMoney = now
    if delta <= 0 then return end
    if GetTime() - chatAt <= PAIR then
        chatAt = 0
        ShowMoney(delta)
    else
        gain, gainAt = delta, GetTime()
    end
end

local function OnMoneyChat()
    if gain > 0 and GetTime() - gainAt <= PAIR then
        ShowMoney(gain)
        gain = 0
    else
        chatAt = GetTime()
    end
end

--------------------------------------------------
-- 4. POSITION (per Edit Mode layout) AND SAMPLES
--------------------------------------------------
local function GetLayoutStore(layoutName)
    local db = GetDb()
    if not db then return nil end
    layoutName = layoutName or LEM:GetActiveLayoutName() or "Modern"
    db.lootFeedLayouts = db.lootFeedLayouts or {}
    db.lootFeedLayouts[layoutName] = db.lootFeedLayouts[layoutName] or {}
    return db.lootFeedLayouts[layoutName]
end

local function ApplyPosition(layoutName)
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

-- Edit Mode samples: real items (Linen Cloth, Copper Ore, Peacebloom), named in your language as the
-- preview opens, and some money
local SAMPLES = { { 2589, 2 }, { 2770, 1 }, { 2447, 3 } }
local function ShowPreview()
    local preview = holder.preview
    if not preview then
        preview = CreateFrame("Frame", nil, holder)
        preview:SetAllPoints()
        preview.lines = {}
        for i = 1, #SAMPLES + 1 do
            local line = NewLine(preview)
            line:SetPoint("BOTTOMLEFT", preview, "BOTTOMLEFT", 0, (#SAMPLES + 1 - i) * SPACING)
            preview.lines[i] = line
        end
        holder.preview = preview
    end
    for i, s in ipairs(SAMPLES) do
        local id, count = s[1], s[2]
        local line = preview.lines[i]
        local icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
        local name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
        Fill(line, icon, "+" .. count .. " " .. (name or ""))
        -- not in the game's item cache yet: the name comes once it loads
        if not name and Item and Item.CreateFromItemID then
            Item:CreateFromItemID(id):ContinueOnItemLoad(function()
                local loaded = C_Item.GetItemNameByID(id)
                if loaded and line:IsVisible() then Fill(line, icon, "+" .. count .. " " .. loaded) end
            end)
        end
    end
    Fill(preview.lines[#SAMPLES + 1], MONEY_ICON, GetMoneyString and GetMoneyString(12345, true) or "1 23 45")
    preview:Show()
end

--------------------------------------------------
-- 5. SETUP
--------------------------------------------------
-- Position changed in the settings: back to the Edit Mode spot, or to the cursor next time
function LF:Refresh()
    if not holder then return end
    if not AtCursor() then ApplyPosition() end
end

function LF:ShouldLoad()
    local db = GetDb()
    return db and db.enabled ~= false and db.lootFeed or false
end

function LF:Init()
    if holder then return end
    holder = CreateFrame("Frame", "FlareUI_LootFeed", UIParent)
    holder:SetSize(WIDTH, HEIGHT)
    holder:SetFrameStrata("HIGH")
    holder:SetClampedToScreen(true)
    ApplyPosition()
    LEM:AddFrame(holder, OnMoved, DEFAULTS, L["FlareUI Loot Feed"])
    LEM:RegisterCallback("layout", function(layoutName) ApplyPosition(layoutName) end)
    -- At the Cursor: nothing to place, so Edit Mode leaves the frame out
    LEM:RegisterCallback("enter", function()
        if AtCursor() then holder:Hide() else holder:Show(); ShowPreview() end
    end)
    LEM:RegisterCallback("exit", function()
        if holder.preview then holder.preview:Hide() end
        holder:Show()
        if not AtCursor() then ApplyPosition() end
    end)

    lastMoney = GetMoney()
    local events = CreateFrame("Frame")
    events:RegisterEvent("CHAT_MSG_LOOT")
    events:RegisterEvent("CHAT_MSG_MONEY")
    events:RegisterEvent("PLAYER_MONEY")
    events:SetScript("OnEvent", function(_, event, text)
        if event == "CHAT_MSG_LOOT" then
            OnLoot(text)
        elseif event == "CHAT_MSG_MONEY" then
            OnMoneyChat()
        else
            OnMoney()
        end
    end)
end
