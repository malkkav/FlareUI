local _, ns = ...
local L = ns.L

--------------------------------------------------
-- LOOT ROLLS (Bags & Looting > Looting > Loot Roll Results, off)
-- FlareUI's loot roll window in place of Blizzard's roll frames. The first roll still to decide gets a
-- full card (Need / Greed / Pass, timer, your roll, the leader); the others are one-line rows, and
-- everyone's roll shows on hover. The window shows while rolls are open and hides a few seconds after
-- the last result; finished rolls go to the Loot History window, kept per character. Placed and scaled
-- in Edit Mode ("FlareUI Loot Rolls"). Roll and history handling after ForeverLootRoll by AKIMRX (MIT,
-- LICENSES/ForeverLootRoll.txt).
--------------------------------------------------
local LR = {}
ns.LootRolls = LR
ns.modules["LootRolls"] = LR

local ipairs, pairs, tonumber, tremove, tinsert = ipairs, pairs, tonumber, table.remove, table.insert
local math_ceil, math_floor, math_max, math_min = math.ceil, math.floor, math.max, math.min
local CreateFrame, GetTime = CreateFrame, GetTime
local LEM = LibStub("FlareEditMode")
local LSM = LibStub("LibSharedMedia-3.0")

local W, PAD, HEADER = 300, 10, 26
local TEXT_W = 300 - 20 - 49   -- right of the icon, to the card's right edge
local ICON, CARD_H, BUTTON, ROW, CARD_GAP = 40, 52, 24, 15, 9
local HOLD = 8               -- seconds a card stays after its result
local RESULT_GRACE = 30      -- seconds after the roll's end to wait for its result
local HISTORY_MAX = 200
local ITEM_RETRY_DELAY = 0.25
local DEFAULTS = { point = "CENTER", x = -320, y = 160 }
local HISTORY_ICON = "Interface\\AddOns\\FlareUI\\Media\\Icons\\DMSegments.tga"
local ICON_COLOR = { r = 0.61, g = 0.48, b = 0.29, a = 1 }

local RS = (Enum and Enum.EncounterLootDropRollState)
    or { NeedMainSpec = 0, NeedOffSpec = 1, Transmog = 2, Greed = 3, NoRoll = 4, Pass = 5 }
local TYPE = { [RS.NeedMainSpec] = 1, [RS.NeedOffSpec] = 1, [RS.Greed] = 2, [RS.Transmog] = 4, [RS.Pass] = 0 }
local LABEL = { [0] = _G.PASS, [1] = _G.NEED, [2] = _G.GREED, [4] = _G.TRANSMOGRIFICATION }
local BUTTON_ATLAS = { [0] = "pass", [1] = "need", [2] = "greed", [4] = "transmog" }
local RANK = { [1] = 1, [4] = 2, [2] = 3, [0] = 4 }

local sessions, order = {}, {}   -- rollID -> session; sessions by start
local bound = {}                  -- "encounter:lootListKey" -> session, or true once forgotten
local cards = {}
local holder, win, more, history
local Refresh, BindAll

local function GetDb()
    return ns.db and ns.db.profile and ns.db.profile.tweaks
end

local function Safe(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

local function ItemID(link)
    return link and tonumber(link:match("item:(%d+)"))
end

local function QualityColor(q)
    local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

local function ClassName(name, class)
    name = Safe(name) or "?"
    class = Safe(class)
    local color = class and C_ClassColor and C_ClassColor.GetClassColor(class)
    return color and color:WrapTextInColorCode(name) or name
end

local function ChoiceAtlas(rollType)
    return "lootroll-toast-icon-" .. (BUTTON_ATLAS[rollType] or "pass") .. "-up"
end

-- everyone who chose, best first; the ones still to choose apart
local function SortedRolls(rollInfos)
    local chose, waiting = {}, {}
    for _, info in ipairs(rollInfos or {}) do
        if Safe(info.playerName) then
            if TYPE[info.state] then chose[#chose + 1] = info else waiting[#waiting + 1] = info end
        end
    end
    table.sort(chose, function(a, b)
        local ra, rb = RANK[TYPE[a.state]] or 9, RANK[TYPE[b.state]] or 9
        if ra ~= rb then return ra < rb end
        return (Safe(a.roll) or 0) > (Safe(b.roll) or 0)
    end)
    return chose, waiting
end

local function RollsTooltip(owner, title, rollInfos)
    ns.OwnGameTooltip(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(title or "?")
    local chose, waiting = SortedRolls(rollInfos)
    if #chose == 0 and #waiting == 0 then GameTooltip:AddLine(L["No rolls yet"], 0.6, 0.6, 0.6) end
    for _, info in ipairs(chose) do
        local roll = Safe(info.roll)
        local right = (LABEL[TYPE[info.state]] or "") .. (roll and ("  " .. roll) or "")
        if info.isWinner then right = "|cff40ff40" .. right .. "|r" end
        local you = info.isSelf and ("  |cff999999" .. L["(you)"] .. "|r") or ""
        GameTooltip:AddDoubleLine(ClassName(info.playerName, info.playerClass) .. you, right, 1, 1, 1, 0.9, 0.9, 0.9)
    end
    for _, info in ipairs(waiting) do
        GameTooltip:AddDoubleLine(ClassName(info.playerName, info.playerClass), "...", 1, 1, 1, 0.5, 0.5, 0.5)
    end
    GameTooltip:Show()
end

local function ItemTooltip(owner, link, rollID)
    ns.OwnGameTooltip(owner, "ANCHOR_RIGHT")
    if rollID then
        GameTooltip:SetLootRollItem(rollID)
    elseif link and link:find("item:") then
        GameTooltip:SetHyperlink(link)
    end
    GameTooltip:Show()
end

--------------------------------------------------
-- 1. HISTORY STORE (per character)
--------------------------------------------------
local function HistoryList()
    local char = ns.CharDB()
    char.lootRollHistory = char.lootRollHistory or {}
    return char.lootRollHistory
end

local function Record(s)
    if s.sample then return end
    local rolls = {}
    for _, info in ipairs(s.drop and s.drop.rollInfos or {}) do
        local name = Safe(info.playerName)
        if name and TYPE[info.state] then
            rolls[#rolls + 1] = { playerName = name, playerClass = Safe(info.playerClass), state = info.state,
                roll = Safe(info.roll), isWinner = info.isWinner, isSelf = info.isSelf }
        end
    end
    local list = HistoryList()
    tinsert(list, 1, { t = time(), link = s.link, name = s.name, texture = s.texture, quality = s.quality,
        rolls = rolls, allPassed = s.drop and s.drop.allPassed or nil })
    for i = #list, HISTORY_MAX + 1, -1 do list[i] = nil end
    if history and history:IsShown() then history:Update() end
end

--------------------------------------------------
-- 2. SESSIONS
--------------------------------------------------
local function RemoveQuiet(s)
    sessions[s.rollID] = nil
    for i = #order, 1, -1 do
        if order[i] == s then tremove(order, i) end
    end
    if s.key then bound[s.key] = true end
end

local function Forget(s)
    if sessions[s.rollID] ~= s then return end
    -- the card under the pointer stays until the pointer leaves
    if s.card and s.card.session == s and s.card:IsMouseOver() then
        C_Timer.After(1, function() Forget(s) end)
        return
    end
    if s.status == "done" then Record(s) end
    RemoveQuiet(s)
    Refresh()
end

local function Finish(s)
    if s.status == "done" then return end
    s.status = "done"
    if s.sample then return end
    C_Timer.After(HOLD, function() Forget(s) end)
end

local function Close(s)
    if s.status ~= "rolling" then return end
    s.status = "waiting"
    if s.pending and s.asked and GetTime() >= s.t0 + s.duration - 1 then
        s.pending = nil   -- the "will bind to you" question was never answered
    end
    s.choice = s.choice or s.pending or 0   -- no click: timed out, a pass
    s.pending = nil
    StaticPopup_Hide("CONFIRM_LOOT_ROLL", s.rollID)
    -- the others may roll until the timer ends; wait for the result from then
    local rollEnd = math_max(0, s.t0 + s.duration - GetTime())
    C_Timer.After(rollEnd + RESULT_GRACE, function()
        if sessions[s.rollID] == s and s.status == "waiting" then
            s.unknown = true
            Finish(s)
            Refresh()
        end
    end)
    BindAll()   -- your choice is known now: copies of one item can bind
end

local function NewSession(rollID, seconds)
    local s = { rollID = rollID, status = "rolling", t0 = GetTime(), duration = seconds or 60 }
    sessions[rollID] = s
    order[#order + 1] = s
    return s
end

local function ReadItem(s)
    local texture, name, count, quality, bop, canNeed, canGreed, _, reasonNeed, reasonGreed, _, _, canTransmog =
        GetLootRollItemInfo(s.rollID)
    if not name then
        if s.status == "rolling" then
            C_Timer.After(ITEM_RETRY_DELAY, function()
                if sessions[s.rollID] == s then ReadItem(s) end
            end)
        end
        return
    end
    s.texture, s.name, s.count, s.quality, s.bop = texture, name, count or 1, quality, bop
    s.canNeed, s.canGreed, s.canTransmog = canNeed, canGreed, canTransmog
    s.reasonNeed, s.reasonGreed = reasonNeed, reasonGreed
    s.link = GetLootRollItemLink(s.rollID)
    s.loaded = true
    BindAll()
    Refresh()
end

local function StartRoll(rollID, rollTimeMs)
    if sessions[rollID] then return end
    rollTimeMs = rollTimeMs or (C_Loot and C_Loot.GetLootRollDuration and C_Loot.GetLootRollDuration(rollID))
    local s = NewSession(rollID, (rollTimeMs or 60000) / 1000)
    s.since = C_LootHistory.GetLootHistoryTime and C_LootHistory.GetLootHistoryTime()
    -- the roll's end event can be missed (a loading screen): close it after its time anyway
    C_Timer.After(s.duration + 5, function()
        if sessions[rollID] == s and s.status == "rolling" then
            Close(s)
            Refresh()
        end
    end)
    ReadItem(s)
    Refresh()
end

local function TimeLeft(s)
    if s.status ~= "rolling" then return nil end
    if s.sample then return s.duration * 0.6 end
    local left = GetLootRollTimeLeft(s.rollID)
    return left and left / 1000 or nil
end

local function Roll(s, rollType)
    if s.status ~= "rolling" or s.sample then return end
    s.pending, s.asked = rollType, nil
    -- a Bind-on-Pickup item asks first: the choice counts once CANCEL_LOOT_ROLL comes
    RollOnLoot(s.rollID, rollType)
    Refresh()
end

--------------------------------------------------
-- 3. LOOT HISTORY (the game's)
--------------------------------------------------
-- an exact link beats a bare item ID; copies of one item bind only by your choice
local function Pick(drop)
    local mine, id = TYPE[drop.playerRollState], ItemID(drop.itemHyperlink)
    local exact, loose = {}, {}
    for _, s in pairs(sessions) do
        if not s.key and not s.sample and s.loaded and not (s.since and drop.startTime and drop.startTime < s.since - 5) then
            if s.link == drop.itemHyperlink then
                exact[#exact + 1] = s
            elseif id and id == ItemID(s.link) then
                loose[#loose + 1] = s
            end
        end
    end
    local pool = #exact > 0 and exact or loose
    if #pool == 1 and (not mine or not pool[1].choice or pool[1].choice == mine) then return pool[1] end
    local best
    for _, s in ipairs(pool) do
        if mine and s.choice == mine and (not best or s.rollID < best.rollID) then best = s end
    end
    return best
end

local function OnDrop(encounterID, drop)
    if not (drop and drop.lootListKey) then return end
    local key = encounterID .. ":" .. drop.lootListKey
    local s = bound[key]
    if s == true then return end
    if not s then
        s = Pick(drop)
        if not s then return end
        s.key, bound[key] = key, s
    end
    s.drop = drop
    local mine = TYPE[drop.playerRollState]
    if mine then s.choice, s.pending = mine, nil end
    if drop.winner or drop.allPassed then
        Close(s)
        s.unknown = nil
        Finish(s)
    end
    Refresh()
end

local function HasUnbound()
    for _, s in ipairs(order) do
        if not s.key and not s.sample and s.status ~= "done" then return true end
    end
    return false
end

function BindAll(encounterID)
    if not C_LootHistory.GetSortedDropsForEncounter or not HasUnbound() then return end
    local list = encounterID and { { encounterID = encounterID } } or C_LootHistory.GetAllEncounterInfos() or {}
    for _, e in ipairs(list) do
        for _, drop in ipairs(C_LootHistory.GetSortedDropsForEncounter(e.encounterID) or {}) do
            if bound[e.encounterID .. ":" .. drop.lootListKey] == nil then OnDrop(e.encounterID, drop) end
        end
    end
end

--------------------------------------------------
-- 4. FLAREUI PANEL PIECES
--------------------------------------------------
local function Panel(frame)
    local edge = LSM:Fetch("border", "FlareUI Thick")
    local bg = LSM:Fetch("background", "Blizzard Dialog Background Dark") or "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"
    frame:SetBackdrop({ bgFile = bg, edgeFile = edge, tile = false, edgeSize = ns.BorderEdgeSize(edge, 16),
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    frame:SetBackdropColor(1, 1, 1, 0.9)
    local c = ns.BORDER_COLOR
    frame:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
end

local function Line(parent, alpha)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    local c = ns.BORDER_COLOR
    line:SetColorTexture(c.r, c.g, c.b, alpha or 0.45)
    return line
end

local function HeaderButton(parent, iconPath, onClick, tooltip)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(18, 18)
    b.icon = b:CreateTexture(nil, "OVERLAY")
    b.icon:SetPoint("CENTER")
    b.icon:SetSize(16, 16)
    ns.BronzeIcon.Apply(b.icon, iconPath, ICON_COLOR)
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self)
        ns.BronzeIcon.Paint(self.icon, ICON_COLOR, true)
        ns.OwnGameTooltip(self, "ANCHOR_TOP")
        GameTooltip:SetText(tooltip)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        ns.BronzeIcon.Paint(self.icon, ICON_COLOR, false)
        GameTooltip:Hide()
    end)
    return b
end

local function IconButton(parent, size)
    local icon = CreateFrame("Button", nil, parent)
    icon:SetSize(size, size)
    local black = icon:CreateTexture(nil, "BACKGROUND")
    black:SetPoint("TOPLEFT", -1, 1)
    black:SetPoint("BOTTOMRIGHT", 1, -1)
    black:SetColorTexture(0, 0, 0, 1)
    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints()
    icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon.edge = CreateFrame("Frame", nil, icon, "BackdropTemplate")
    icon.edge:SetPoint("TOPLEFT", -4, 4)
    icon.edge:SetPoint("BOTTOMRIGHT", 4, -4)
    icon.edge:SetBackdrop({ edgeFile = LSM:Fetch("border", "FlareUI Thin"), edgeSize = 8 })
    return icon
end

--------------------------------------------------
-- 5. CARDS AND ROWS
-- The first roll still to decide gets the full card; every other roll is a one-line row (its own
-- buttons while open, the leader or winner after). A row you chose on can be closed (X); with Hide
-- Passed Rolls, passing closes it at once. Closed rolls still reach the history.
--------------------------------------------------
local ROW_H, ROW_ICON, ROW_BUTTON, MAX_ROWS = 24, 20, 20, 8
local ROW_W = W - 2 * PAD

local function OnButtonEnter(b)
    ns.OwnGameTooltip(b, "ANCHOR_RIGHT")
    GameTooltip:SetText(LABEL[b.rollType])
    if b.reason then GameTooltip:AddLine(b.reason, 1, 0.2, 0.2, true) end
    GameTooltip:Show()
end

local function NewButton(card, rollType, size)
    local b = CreateFrame("Button", nil, card)
    b:SetSize(size, size)
    local atlas = "lootroll-toast-icon-" .. BUTTON_ATLAS[rollType]
    b:SetNormalAtlas(atlas .. "-up")
    b:SetHighlightAtlas(atlas .. "-highlight", "ADD")
    b:SetPushedAtlas(atlas .. "-down")
    b:SetMotionScriptsWhileDisabled(true)
    b.rollType = rollType
    b:SetScript("OnClick", function() if card.session then Roll(card.session, rollType) end end)
    b:SetScript("OnEnter", OnButtonEnter)
    b:SetScript("OnLeave", GameTooltip_Hide)
    return b
end

local function SetButton(b, shown, enabled, reason)
    b:SetShown(shown)
    b:SetEnabled(enabled and true or false)
    b:SetAlpha(enabled and 1 or 0.35)
    b.reason = not enabled and reason and reason > 0 and _G["LOOT_ROLL_INELIGIBLE_REASON" .. reason] or nil
end

local function RollButtons(card, size, gap)
    card.pass = NewButton(card, 0, size)
    card.greed = NewButton(card, 2, size)
    card.greed:SetPoint("RIGHT", card.pass, "LEFT", -gap, 0)
    card.transmog = NewButton(card, 4, size)
    card.transmog:SetPoint("RIGHT", card.pass, "LEFT", -gap, 0)
    card.need = NewButton(card, 1, size)
    card.need:SetPoint("RIGHT", card.greed, "LEFT", -gap, 0)
end

-- returns whether the buttons show
local function FillButtons(card, s)
    local open = s.status == "rolling" and s.loaded
    local transmog = s.canTransmog and true or false
    SetButton(card.need, open, s.canNeed, s.reasonNeed)
    SetButton(card.greed, open and not transmog, s.canGreed, s.reasonGreed)
    SetButton(card.transmog, open and transmog, true)
    SetButton(card.pass, open, true)
    return open
end

local function UpdateTimer(card)
    local s = card.session
    local left = s and TimeLeft(s)
    if not left then
        card:SetScript("OnUpdate", nil)
        return
    end
    local fraction = s.duration > 0 and math_min(1, left / s.duration) or 0
    card.timer:SetValue(fraction)
    if fraction < 0.5 then card.timer:SetStatusBarColor(0.9, 0.2, 0.15) else card.timer:SetStatusBarColor(1, 0.75, 0.1) end
    card.timeText:SetText(math_ceil(left))
end

local function StartTimer(card, s)
    local rolling = TimeLeft(s) ~= nil
    card.timer:SetShown(rolling)
    card.timeText:SetShown(rolling)
    if rolling then
        UpdateTimer(card)
        card:SetScript("OnUpdate", UpdateTimer)
    else
        card:SetScript("OnUpdate", nil)
    end
end

local function Timer(card, height)
    card.timer = CreateFrame("StatusBar", nil, card)
    card.timer:SetHeight(height)
    card.timer:SetStatusBarTexture(LSM:Fetch("statusbar", "FlareUI Forever"))
    card.timer:SetMinMaxValues(0, 1)
    local bg = card.timer:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.6)
    card.timeText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
end

-- the item icon with its tooltip and links; everyone's roll on the rest of the card
local function ItemParts(card, size)
    card:EnableMouse(true)
    card.icon = IconButton(card, size)
    card.icon:SetScript("OnEnter", function(self)
        local s = card.session
        if s then ItemTooltip(self, s.link, not s.sample and s.status == "rolling" and s.rollID or nil) end
    end)
    card.icon:SetScript("OnLeave", GameTooltip_Hide)
    card.icon:SetScript("OnClick", function()
        local s = card.session
        if s and s.link then HandleModifiedItemClick(s.link) end
    end)
    card:SetScript("OnEnter", function(self)
        local s = self.session
        if s then RollsTooltip(self, s.link or s.name, s.drop and s.drop.rollInfos) end
    end)
    card:SetScript("OnLeave", GameTooltip_Hide)
    card.name = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.name:SetJustifyH("LEFT")
    card.name:SetWordWrap(false)
end

local function FillHead(card, s)
    card.session, s.card = s, card
    local r, g, b = QualityColor(s.quality)
    card.icon.texture:SetTexture(s.texture or 134400)
    card.icon.edge:SetBackdropBorderColor(r, g, b, 1)
    card.name:SetText(s.name or _G.RETRIEVING_ITEM_INFO or "")
    card.name:SetTextColor(r, g, b)
end

local function RefreshTooltip(card, s)
    if GameTooltip:IsOwned(card) then RollsTooltip(card, s.link or s.name, s.drop and s.drop.rollInfos) end
end

local function MyRoll(s)
    local roll
    for _, info in ipairs(s.drop and s.drop.rollInfos or {}) do
        if info.isSelf then roll = Safe(info.roll) or roll end
    end
    return roll
end

-- your choice and roll, or what to know before choosing
local function MineText(s)
    local choice = s.choice or s.pending
    if not choice then
        return s.bop and ("|cffff8040" .. (_G.ITEM_BIND_ON_PICKUP or "") .. "|r") or ""
    end
    local roll = MyRoll(s)
    return L["You: %s"]:format((LABEL[choice] or "?") .. (roll and (" " .. roll) or ""))
end

-- in the rows: your roll in brackets when someone else leads or won
local function Yours(s, info)
    local roll = MyRoll(s)
    if not roll or info.isSelf then return "" end
    return " |cff999999(" .. roll .. ")|r"
end

-- the leader, then the winner; short (the rows): name and roll only, and yours
local function ResultText(s, short)
    local d = s.drop
    if d then
        if d.allPassed then return "|cff999999" .. L["Everyone passed"] .. "|r" end
        if d.winner then
            local roll = Safe(d.winner.roll)
            local text = ClassName(d.winner.playerName, d.winner.playerClass) .. (roll and (" |cff40ff40" .. roll .. "|r") or "")
            return short and (text .. Yours(s, d.winner)) or L["Winner: %s"]:format(text)
        end
    end
    if s.unknown then return "|cff999999" .. L["No result"] .. "|r" end
    local lead = d and d.currentLeader
    if lead and Safe(lead.roll) then
        local text = ClassName(lead.playerName, lead.playerClass) .. " |cffffd100" .. Safe(lead.roll) .. "|r"
        return short and (text .. Yours(s, lead)) or L["Leading: %s"]:format(text)
    end
    local mine = short and MyRoll(s)
    if mine then return "|cff999999(" .. mine .. ")|r" end
    return short and "" or ("|cff999999" .. L["No rolls yet"] .. "|r")
end

local function NewCard()
    local card = CreateFrame("Frame", nil, win)
    card:SetSize(ROW_W, CARD_H)
    ItemParts(card, ICON)
    card.icon:SetPoint("TOPLEFT")
    card.count = card.icon:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    card.count:SetPoint("BOTTOMRIGHT", -1, 1)
    RollButtons(card, BUTTON, 1)
    card.pass:SetPoint("TOPRIGHT", 0, 3)
    card.name:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 9, -1)
    card.name:SetWidth(TEXT_W - 3 * (BUTTON + 1) - 4)
    card.mine = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.mine:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -3)
    card.mine:SetWidth(TEXT_W - 20)
    card.mine:SetJustifyH("LEFT")
    card.mine:SetWordWrap(false)
    card.sub = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.sub:SetPoint("TOPLEFT", card.mine, "BOTTOMLEFT", 0, -2)
    card.sub:SetWidth(TEXT_W - 20)
    card.sub:SetJustifyH("LEFT")
    card.sub:SetWordWrap(false)
    Timer(card, 6)
    card.timer:SetPoint("BOTTOMLEFT")
    card.timer:SetWidth(ROW_W - 26)
    card.timeText:SetPoint("LEFT", card.timer, "RIGHT", 5, 0)
    return card
end

local function FillCard(card, s)
    FillHead(card, s)
    card.count:SetText((s.count or 1) > 1 and s.count or "")
    card.mine:SetText(MineText(s))
    card.sub:SetText(ResultText(s))
    FillButtons(card, s)
    StartTimer(card, s)
    card:Show()
    RefreshTooltip(card, s)
end

local function NewRow()
    local row = CreateFrame("Frame", nil, win)
    row:SetSize(ROW_W, ROW_H)
    ItemParts(row, ROW_ICON)
    row.icon:SetPoint("LEFT", 0, 1)
    row.name:SetFontObject("GameFontNormalSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 7, 0)
    RollButtons(row, ROW_BUTTON, 0)
    row.pass:SetPoint("RIGHT", 0, 1)
    Timer(row, 2)
    row.timer:SetPoint("BOTTOMLEFT", ROW_ICON + 7, 0)
    row.timer:SetWidth(ROW_W - ROW_ICON - 7)
    row.timeText:SetPoint("RIGHT", row.need, "LEFT", -4, 0)
    row.close = CreateFrame("Button", nil, row)
    row.close:SetSize(14, 14)
    row.close:SetPoint("RIGHT", 0, 1)
    row.close:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
    row.close:SetHighlightTexture("Interface\\Buttons\\UI-StopButton", "ADD")
    row.close:GetNormalTexture():SetVertexColor(0.8, 0.8, 0.8)
    row.close:SetScript("OnClick", function()
        local s = row.session
        if s then
            s.dismissed = true
            GameTooltip:Hide()
            Refresh()
        end
    end)
    row.close:SetScript("OnEnter", function(self)
        ns.OwnGameTooltip(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Close"])
        GameTooltip:Show()
    end)
    row.close:SetScript("OnLeave", GameTooltip_Hide)
    row.chosen = row:CreateTexture(nil, "ARTWORK")
    row.chosen:SetSize(15, 15)
    row.chosen:SetPoint("RIGHT", row.close, "LEFT", -4, 0)
    row.result = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.result:SetPoint("RIGHT", row.chosen, "LEFT", -5, 0)
    row.result:SetWidth(120)
    row.result:SetJustifyH("RIGHT")
    row.result:SetWordWrap(false)
    return row
end

local function FillRow(row, s)
    FillHead(row, s)
    local open = FillButtons(row, s)
    local choice = not open and (s.choice or s.pending)
    row.close:SetShown(s.status ~= "rolling")
    row.chosen:SetShown(choice and true or false)
    if choice then row.chosen:SetAtlas(ChoiceAtlas(choice)) end
    row.result:SetShown(not open)
    row.result:SetText(ResultText(s, true))
    row.name:SetWidth(open and (ROW_W - ROW_ICON - 7 - 4 * ROW_BUTTON - 20) or (ROW_W - ROW_ICON - 7 - 120 - 15 - 14 - 16))
    StartTimer(row, s)
    row.timeText:SetShown(open)
    row:SetAlpha(s.status == "done" and 0.7 or 1)
    row:Show()
    RefreshTooltip(row, s)
end

local function Shown(s)
    if s.dismissed then return false end
    local db = GetDb()
    return not (db and db.lootRollsHidePass ~= false and s.choice == 0 and s.status ~= "rolling" and not s.sample)
end

local function Release(card)
    card.session = nil
    card:SetScript("OnUpdate", nil)
    card:Hide()
end

local rows = {}
function Refresh()
    if not win then return end
    local list, active = {}, 0
    for _, s in ipairs(order) do
        if Shown(s) then
            list[#list + 1] = s
            if s.status ~= "done" then active = active + 1 end
        end
    end
    local focus
    for _, s in ipairs(list) do
        if s.status == "rolling" then
            focus = s
            break
        end
    end

    local y = HEADER + 6
    local card = cards[1]
    if focus then
        card = card or NewCard()
        cards[1] = card
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", PAD, -y)
        FillCard(card, focus)
        y = y + CARD_H + CARD_GAP
    elseif card then
        Release(card)
    end
    local splitY = y - math_floor(CARD_GAP / 2) - 1
    win.split:SetShown(focus ~= nil and #list > 1)
    win.split:ClearAllPoints()
    win.split:SetPoint("TOPLEFT", PAD, -splitY)
    win.split:SetPoint("TOPRIGHT", -PAD, -splitY)

    local n = 0
    for _, s in ipairs(list) do
        if s ~= focus and n < MAX_ROWS then
            n = n + 1
            local row = rows[n] or NewRow()
            rows[n] = row
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", PAD, -y)
            FillRow(row, s)
            y = y + ROW_H + 2
        end
    end
    for i = n + 1, #rows do Release(rows[i]) end

    local extra = #list - n - (focus and 1 or 0)
    more:SetShown(extra > 0)
    if extra > 0 then
        more:ClearAllPoints()
        more:SetPoint("TOPLEFT", PAD, -y - 2)
        more:SetText(L["+%d more"]:format(extra))
        y = y + ROW
    end
    win.count:SetText(active > 0 and ("(" .. active .. ")") or "")
    win:SetHeight(y + PAD - 2)
    win:SetShown(#list > 0)
end

--------------------------------------------------
-- 6. HISTORY WINDOW
--------------------------------------------------
local HISTORY_ROWS, HISTORY_ROW = 16, 20

local function HistoryRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(HISTORY_ROW)
    row.time = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.time:SetPoint("LEFT", 2, 0)
    row.time:SetWidth(34)
    row.time:SetJustifyH("LEFT")
    row.item = CreateFrame("Button", nil, row)
    row.item:SetPoint("LEFT", 38, 0)
    row.item:SetSize(180, HISTORY_ROW)
    row.icon = row.item:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT")
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.name = row.item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
    row.name:SetPoint("RIGHT")
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.item:SetScript("OnEnter", function(self) if row.entry then ItemTooltip(self, row.entry.link) end end)
    row.item:SetScript("OnLeave", GameTooltip_Hide)
    row.item:SetScript("OnClick", function() if row.entry and row.entry.link then HandleModifiedItemClick(row.entry.link) end end)
    row.winner = CreateFrame("Button", nil, row)
    row.winner:SetPoint("LEFT", row.item, "RIGHT", 6, 0)
    row.winner:SetPoint("RIGHT")
    row.winner:SetHeight(HISTORY_ROW)
    row.winnerText = row.winner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.winnerText:SetAllPoints()
    row.winnerText:SetJustifyH("RIGHT")
    row.winnerText:SetWordWrap(false)
    row.winner:SetScript("OnEnter", function(self)
        local e = row.entry
        if e then RollsTooltip(self, e.link or e.name, e.rolls) end
    end)
    row.winner:SetScript("OnLeave", GameTooltip_Hide)
    return row
end

local function WinnerText(e)
    if e.allPassed then return "|cff999999" .. L["Everyone passed"] .. "|r" end
    for _, info in ipairs(e.rolls or {}) do
        if info.isWinner then
            return ClassName(info.playerName, info.playerClass) .. (info.roll and ("  " .. info.roll) or "")
        end
    end
    return "|cff999999" .. L["No result"] .. "|r"
end

local function CreateHistory()
    local h = CreateFrame("Frame", "FlareUI_LootHistory", UIParent, "BackdropTemplate")
    h:SetSize(400, HEADER + HISTORY_ROWS * HISTORY_ROW + 2 * PAD + 4)
    h:SetPoint("CENTER")
    h:SetFrameStrata("HIGH")
    h:SetClampedToScreen(true)
    h:SetMovable(true)
    h:EnableMouse(true)
    h:RegisterForDrag("LeftButton")
    h:SetScript("OnDragStart", h.StartMoving)
    h:SetScript("OnDragStop", h.StopMovingOrSizing)
    h:EnableMouseWheel(true)
    Panel(h)
    tinsert(UISpecialFrames, "FlareUI_LootHistory")

    local title = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", PAD + 2, -9)
    title:SetText(L["Loot History"])
    local close = CreateFrame("Button", nil, h, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 1, 1)
    local clear = CreateFrame("Button", nil, h)
    clear:SetSize(40, 16)
    clear:SetPoint("RIGHT", close, "LEFT", -2, 0)
    clear.text = clear:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    clear.text:SetAllPoints()
    clear.text:SetText(L["Clear"])
    clear:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
    clear:SetScript("OnLeave", function(self) self.text:SetTextColor(1, 0.82, 0) end)
    clear:SetScript("OnClick", function()
        wipe(HistoryList())
        h.offset = 0
        h:Update()
    end)
    local line = Line(h)
    line:SetPoint("TOPLEFT", PAD, -HEADER)
    line:SetPoint("TOPRIGHT", -PAD, -HEADER)
    h.empty = h:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    h.empty:SetPoint("CENTER", 0, -HEADER / 2)
    h.empty:SetText(L["No loot rolls yet"])

    h.rows = {}
    for i = 1, HISTORY_ROWS do
        local row = HistoryRow(h)
        row:SetPoint("TOPLEFT", PAD, -(HEADER + 4 + (i - 1) * HISTORY_ROW))
        row:SetPoint("TOPRIGHT", -PAD, -(HEADER + 4 + (i - 1) * HISTORY_ROW))
        h.rows[i] = row
    end
    h.offset = 0
    h:SetScript("OnMouseWheel", function(self, delta)
        local maxOffset = math_max(0, #HistoryList() - HISTORY_ROWS)
        self.offset = math_max(0, math_min(maxOffset, self.offset - delta * 3))
        self:Update()
    end)
    function h:Update()
        local list = HistoryList()
        self.empty:SetShown(#list == 0)
        for i, row in ipairs(self.rows) do
            local e = list[self.offset + i]
            row.entry = e
            if e then
                row.time:SetText(date(date("%x", e.t) == date("%x") and "%H:%M" or "%d.%m.", e.t))
                row.icon:SetTexture(e.texture or 134400)
                local r, g, b = QualityColor(e.quality)
                row.name:SetText(e.name or e.link or "?")
                row.name:SetTextColor(r, g, b)
                row.winnerText:SetText(WinnerText(e))
                row:Show()
            else
                row:Hide()
            end
        end
    end
    h:SetScript("OnShow", h.Update)
    h:Hide()
    return h
end

function LR:ToggleHistory()
    history = history or CreateHistory()
    history:SetShown(not history:IsShown())
end

-- also with Loot Roll Results off: Bindings.xml, the radial menu's Loot History panel, /fui loot and
-- the settings button
BINDING_NAME_FLAREUI_LOOT_HISTORY = L["Loot History"]
function FlareUI_ToggleLootHistory()
    LR:ToggleHistory()
end

--------------------------------------------------
-- 7. EDIT MODE SAMPLES: one roll still open, one won (Shadowfang, Tail Spike)
--------------------------------------------------
local nextSample = 0

local function SampleSession(itemID)
    nextSample = nextSample - 1
    local s = NewSession(nextSample, 60)
    s.sample, s.count, s.canNeed, s.canGreed, s.loaded = true, 1, true, true, true
    local name, link, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
    s.name, s.link, s.quality = name or L["Sample Item"], link, quality or 3
    s.texture = icon or C_Item.GetItemIconByID(itemID)
    return s
end

local function HideSamples()
    for i = #order, 1, -1 do
        if order[i].sample then RemoveQuiet(order[i]) end
    end
    Refresh()
end

local function ShowSamples()
    HideSamples()
    local _, class = UnitClass("player")
    local me = UnitName("player")
    local rolling = SampleSession(1482)
    local arvel = { playerName = "Arvel", playerClass = "PALADIN", state = RS.NeedMainSpec, roll = 87 }
    rolling.drop = { currentLeader = arvel, rollInfos = { arvel,
        { playerName = "Miri", playerClass = "MAGE", state = RS.Greed, roll = 64 },
        { playerName = "Tharok", playerClass = "WARRIOR", state = RS.Pass },
        { playerName = "Lyss", playerClass = "PRIEST", state = RS.NoRoll },
        { playerName = me, playerClass = class, state = RS.NoRoll, isSelf = true } } }
    local done = SampleSession(6448)
    local miri = { playerName = "Miri", playerClass = "MAGE", state = RS.Greed, roll = 64, isWinner = true }
    done.choice, done.status = 2, "done"
    done.drop = { winner = miri, rollInfos = { miri, { playerName = me, playerClass = class, state = RS.Greed, roll = 23, isSelf = true } } }
    Refresh()
end

--------------------------------------------------
-- 8. POSITION AND SCALE (per Edit Mode layout; the scale is the Loot Rolls mover's, tweaks.lootScale)
--------------------------------------------------
local function Scale()
    local db = GetDb()
    return math_max(0.5, math_min(2, db and tonumber(db.lootScale) or 1))
end

local function ApplyScale()
    local scale = Scale()
    holder:SetSize(W * scale, HEADER * scale)
    win:SetScale(scale)
end

local function GetLayoutStore(layoutName)
    local db = GetDb()
    if not db then return nil end
    layoutName = layoutName or LEM:GetActiveLayoutName() or "Modern"
    db.lootRollLayouts = db.lootRollLayouts or {}
    return ns.LayoutHome(db.lootRollLayouts, layoutName)
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

local function ScaleSetting()
    return { name = L["Scale"], kind = LEM.SettingType.Slider, default = 100, minValue = 50, maxValue = 200, valueStep = 5,
        get = function() return math_floor(Scale() * 100 + 0.5) end,
        set = function(_, value)
            local db = GetDb()
            if not db then return end
            db.lootScale = value ~= 100 and value / 100 or nil
            ApplyScale()
        end }
end

--------------------------------------------------
-- 9. SETUP
--------------------------------------------------
function LR:Refresh()
    Refresh()
end

function LR:ShouldLoad()
    local db = GetDb()
    return db and ns.BagModuleOn() and db.lootRolls and C_LootHistory
        and GameEvent and GameEvent.UnregisterInternalEvent and not ns.IsGamepadUI() and true or false
end

function LR:Init()
    if holder then return end
    -- Blizzard's roll frames stay closed: START_LOOT_ROLL reaches them through GameEvent only
    GameEvent.UnregisterInternalEvent("START_LOOT_ROLL")

    holder = CreateFrame("Frame", "FlareUI_LootRolls", UIParent)
    holder:SetClampedToScreen(true)
    win = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    win:SetWidth(W)
    win:SetPoint("TOPLEFT", holder, "TOPLEFT")
    win:SetFrameStrata("HIGH")
    win:SetClampedToScreen(true)
    Panel(win)
    win:Hide()
    local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", PAD + 2, -9)
    title:SetText(L["Loot Rolls"])
    win.count = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    win.count:SetPoint("LEFT", title, "RIGHT", 5, 0)
    local historyButton = HeaderButton(win, HISTORY_ICON, function() LR:ToggleHistory() end, L["Loot History"])
    historyButton:SetPoint("TOPRIGHT", -PAD + 2, -5)
    local line = Line(win)
    line:SetPoint("TOPLEFT", PAD, -HEADER)
    line:SetPoint("TOPRIGHT", -PAD, -HEADER)
    more = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    win.split = Line(win, 0.35)

    ApplyScale()
    ApplyPosition()
    LEM:AddFrame(holder, OnMoved, DEFAULTS, L["FlareUI Loot Rolls"])
    local selection = LEM.frameSelections and LEM.frameSelections[holder]
    if selection then
        selection:SetFrameStrata("HIGH")
        selection:SetFrameLevel(win:GetFrameLevel() + 20)
    end
    LEM:AddFrameSettings(holder, ns.EditSection("Frame", { ScaleSetting() }))
    LEM:RegisterCallback("layout", function(layoutName) ApplyPosition(layoutName) end)
    LEM:RegisterCallback("enter", ShowSamples)
    LEM:RegisterCallback("exit", HideSamples)

    local events = CreateFrame("Frame")
    for _, event in ipairs({ "START_LOOT_ROLL", "CONFIRM_LOOT_ROLL", "CANCEL_LOOT_ROLL", "CANCEL_ALL_LOOT_ROLLS", "PLAYER_ENTERING_WORLD" }) do
        events:RegisterEvent(event)
    end
    for _, event in ipairs({ "LOOT_HISTORY_UPDATE_DROP", "LOOT_HISTORY_UPDATE_ENCOUNTER", "LOOT_HISTORY_CLEAR_HISTORY" }) do
        pcall(events.RegisterEvent, events, event)
    end
    events:SetScript("OnEvent", function(_, event, a, b)
        if event == "START_LOOT_ROLL" then
            StartRoll(a, b)
        elseif event == "CONFIRM_LOOT_ROLL" then
            if sessions[a] then sessions[a].asked = true end
        elseif event == "CANCEL_LOOT_ROLL" then
            local s = sessions[a]
            if s then
                Close(s)
                Refresh()
            end
        elseif event == "CANCEL_ALL_LOOT_ROLLS" then
            for _, s in ipairs(order) do
                if not s.sample then Close(s) end
            end
            Refresh()
        elseif event == "LOOT_HISTORY_UPDATE_DROP" then
            OnDrop(a, C_LootHistory.GetSortedInfoForDrop(a, b))
        elseif event == "LOOT_HISTORY_UPDATE_ENCOUNTER" then
            BindAll(a)
        elseif event == "LOOT_HISTORY_CLEAR_HISTORY" then
            wipe(bound)
        elseif event == "PLAYER_ENTERING_WORLD" then
            for _, rollID in ipairs(GetActiveLootRollIDs and GetActiveLootRollIDs() or {}) do StartRoll(rollID) end
        end
    end)
end
