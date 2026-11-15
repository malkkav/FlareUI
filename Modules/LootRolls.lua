local _, ns = ...
local L = ns.L

--------------------------------------------------
-- LOOT ROLLS (Bags & Looting > Looting > Loot Roll Window, off; PR #43 by Nico-Mayer, 11-15)
-- FlareUI's loot roll window in place of Blizzard's roll frames. The first roll still to decide gets a
-- full card (Need / Greed / Pass, timer, your roll, the leader); the others are one-line rows, and
-- everyone's roll shows on hover. A roll you passed on or let run out leaves at once; the others hide
-- a few seconds after their result. The header icon opens Blizzard's loot history. Placed and scaled
-- in Edit Mode ("FlareUI Loot Rolls", the spot and scale the Movers' roll frame mover had). In the
-- Gamepad UI the window steps back for Blizzard's gamepad roll frame. Its text uses Bags & Looting >
-- Fonts > Loot Rolls. Roll handling after ForeverLootRoll by AKIMRX (MIT, LICENSES/ForeverLootRoll.txt).
--------------------------------------------------
local LR = {}
ns.LootRolls = LR
ns.modules["LootRolls"] = LR

local ipairs, pairs, tonumber, tremove, type = ipairs, pairs, tonumber, table.remove, type
local math_ceil, math_floor, math_max, math_min = math.ceil, math.floor, math.max, math.min
local CreateFrame, GetTime = CreateFrame, GetTime
local canaccessvalue, issecretvalue = canaccessvalue, issecretvalue
local LEM = LibStub("FlareEditMode")
local LSM = LibStub("LibSharedMedia-3.0")

-- (11-15, Marcus) no tooltips on the Edit Mode samples: LR.previewing while they show
local function Tip(owner, anchor)
    if LR.previewing then return false end
    ns.OwnGameTooltip(owner, anchor)
    return true
end

local W, PAD, HEADER = 300, 10, 26
local TEXT_W = 300 - 20 - 49   -- right of the icon, to the card's right edge
-- (11-15, Marcus) the Need / Greed / Pass buttons a little smaller: 24 -> 21
local ICON, CARD_H, BUTTON, ROW, CARD_GAP = 40, 52, 21, 15, 9
local HOLD = 8               -- seconds a card stays after its result
local RESULT_GRACE = 30      -- seconds after the roll's end to wait for its result
local ITEM_RETRY_DELAY = 0.25
local DEFAULTS = { point = "CENTER", x = -320, y = 160 }
local MOVER_KEY = "loot"     -- tweaks.moverLayouts[layout].loot: the Movers' "FlareUI Loot Rolls" spot
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
local holder, win, more
local Refresh, BindAll, FitHolder

local function GetDb()
    return ns.db and ns.db.profile and ns.db.profile.tweaks
end

-- a value the game hands over (loot history, names, rolls), or nil when this code may not read it:
-- a secret value can't index a table or be compared
local function Safe(value)
    if canaccessvalue then
        if not canaccessvalue(value) then return nil end
    elseif issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function StateType(state)
    state = Safe(state)
    return state ~= nil and TYPE[state] or nil
end

local function ItemID(link)
    return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

--------------------------------------------------
-- 0. FONTS (Bags & Looting > Fonts > Loot Rolls, tweaks.lootRollFont): the size is the item names';
-- the small lines (your roll, the leader, the rows) are two smaller
--------------------------------------------------
local texts = {}   -- font string -> true when small

local function StyleText(fs, small)
    local db = GetDb()
    local font = db and db.lootRollFont or {}
    local size = font.size or 12
    if small then size = math_max(6, size - 2) end
    local flags = font.flags or ""
    if flags == "NONE" then flags = "" end
    -- a family: other players' names keep their Cyrillic and Chinese / Korean letters
    ns.SetFontFamily(fs, ns.GetFontPath(font.face or ns.GLOBAL_FONT), size, flags)
    ns.ApplyShadow(fs, font)
end

-- a font string with FlareUI's font (the template first: a font string needs a font before SetText)
local function Text(parent, template, small)
    local fs = parent:CreateFontString(nil, "OVERLAY", template)
    texts[fs] = small and true or false
    StyleText(fs, small)
    return fs
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
            if StateType(info.state) then chose[#chose + 1] = info else waiting[#waiting + 1] = info end
        end
    end
    local function Roll(info)
        local roll = Safe(info.roll)
        return type(roll) == "number" and roll or 0
    end
    table.sort(chose, function(a, b)
        local ra, rb = RANK[StateType(a.state)] or 9, RANK[StateType(b.state)] or 9
        if ra ~= rb then return ra < rb end
        return Roll(a) > Roll(b)
    end)
    return chose, waiting
end

local function RollsTooltip(owner, title, rollInfos)
    if not Tip(owner, "ANCHOR_RIGHT") then return end
    GameTooltip:AddLine(title or "?")
    local chose, waiting = SortedRolls(rollInfos)
    if #chose == 0 and #waiting == 0 then GameTooltip:AddLine(L["No rolls yet"], 0.6, 0.6, 0.6) end
    for _, info in ipairs(chose) do
        local roll = Safe(info.roll)
        local right = (LABEL[StateType(info.state)] or "") .. (roll and ("  " .. roll) or "")
        if Safe(info.isWinner) then right = "|cff40ff40" .. right .. "|r" end
        local you = Safe(info.isSelf) and ("  |cff999999" .. L["(you)"] .. "|r") or ""
        GameTooltip:AddDoubleLine(ClassName(info.playerName, info.playerClass) .. you, right, 1, 1, 1, 0.9, 0.9, 0.9)
    end
    for _, info in ipairs(waiting) do
        GameTooltip:AddDoubleLine(ClassName(info.playerName, info.playerClass), "...", 1, 1, 1, 0.5, 0.5, 0.5)
    end
    GameTooltip:Show()
end

local function ItemTooltip(owner, link, rollID)
    if not Tip(owner, "ANCHOR_RIGHT") then return end
    if rollID then
        GameTooltip:SetLootRollItem(rollID)
    elseif link and link:find("item:") then
        GameTooltip:SetHyperlink(link)
    end
    GameTooltip:Show()
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
    if s.pending and s.asked and not s.confirmed and GetTime() >= s.t0 + s.duration - 1 then
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
    local since = C_LootHistory.GetLootHistoryTime and Safe(C_LootHistory.GetLootHistoryTime())
    s.since = type(since) == "number" and since or nil
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
    s.pending, s.asked, s.confirmed = rollType, nil, nil
    -- a Bind-on-Pickup item asks first: the choice counts once CANCEL_LOOT_ROLL comes
    RollOnLoot(s.rollID, rollType)
    Refresh()
end

-- Blizzard's "will bind to you" question for a Bind-on-Pickup roll: OK calls ConfirmLootRoll (hooked
-- in Init, as does Skip Loot Confirmations); closed any other way (Cancel, Escape) the roll is still
-- open and the pending "You: Need" goes. The dialog shows after this event, so it is watched for a
-- moment: seen, then gone without the OK.
local function WatchConfirm(s)
    s.asked, s.confirmed = true, nil
    local seen, waited = false, 0
    local ticker
    ticker = C_Timer.NewTicker(0.1, function()
        if sessions[s.rollID] ~= s or s.status ~= "rolling" or s.confirmed or not s.pending then
            ticker:Cancel()
            return
        end
        local dialog = StaticPopup_FindVisible and StaticPopup_FindVisible("CONFIRM_LOOT_ROLL")
        if dialog and dialog.data == s.rollID then
            seen = true
        elseif seen or waited >= 1 then
            ticker:Cancel()
            if seen then
                s.pending, s.asked = nil, nil
                Refresh()
            end
        end
        waited = waited + 0.1
    end)
end

--------------------------------------------------
-- 3. LOOT HISTORY (the game's)
--------------------------------------------------
-- an exact link beats a bare item ID; copies of one item bind only by your choice
-- (every value from the game's loot history goes through Safe before it indexes or is compared)
local function Pick(drop)
    local link = Safe(drop.itemHyperlink)
    if type(link) ~= "string" then link = nil end
    local start = Safe(drop.startTime)
    if type(start) ~= "number" then start = nil end
    local mine, id = StateType(drop.playerRollState), ItemID(link)
    local exact, loose = {}, {}
    for _, s in pairs(sessions) do
        if not s.key and not s.sample and s.loaded and not (s.since and start and start < s.since - 5) then
            if link and s.link == link then
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

-- "encounter:lootListKey", or nil when either can't be read
local function DropKey(encounterID, drop)
    encounterID, drop = Safe(encounterID), Safe(drop)
    local listKey = type(drop) == "table" and Safe(drop.lootListKey) or nil
    if encounterID == nil or listKey == nil then return nil end
    return encounterID .. ":" .. listKey
end

local function OnDrop(encounterID, drop)
    local key = DropKey(encounterID, drop)
    if not key then return end
    local s = bound[key]
    if s == true then return end
    if not s then
        s = Pick(drop)
        if not s then return end
        s.key, bound[key] = key, s
    end
    s.drop = drop
    local mine = StateType(drop.playerRollState)
    if mine then s.choice, s.pending = mine, nil end
    if Safe(drop.winner) or Safe(drop.allPassed) then
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
        local id = Safe(e.encounterID)
        if id ~= nil then
            for _, drop in ipairs(C_LootHistory.GetSortedDropsForEncounter(id) or {}) do
                local key = DropKey(id, drop)
                if key and bound[key] == nil then OnDrop(id, drop) end
            end
        end
    end
end

--------------------------------------------------
-- 4. FLAREUI PANEL PIECES
--------------------------------------------------
local function Panel(frame)
    local edge = LSM:Fetch("border", "FlareUI Thin")   -- (11-15, Marcus: thin, not thick)
    local bg = LSM:Fetch("background", "Blizzard Dialog Background Dark") or "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"
    frame:SetBackdrop({ bgFile = bg, edgeFile = edge, tile = false, edgeSize = ns.BorderEdgeSize(edge, 16),
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    -- Frame Opacity (Bags & Looting, tweaks.lootRollsOpacity; 11-15, Marcus: as the chat and meter)
    local db = GetDb()
    frame:SetBackdropColor(1, 1, 1, (db and tonumber(db.lootRollsOpacity)) or 1)
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
    b:SetSize(16, 16)
    b.icon = b:CreateTexture(nil, "OVERLAY")
    b.icon:SetPoint("CENTER")
    b.icon:SetSize(12, 12)   -- (11-15, Marcus: was 16, too big)
    ns.BronzeIcon.Apply(b.icon, iconPath, ICON_COLOR)
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self)
        ns.BronzeIcon.Paint(self.icon, ICON_COLOR, true)
        if not Tip(self, "ANCHOR_TOP") then return end
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
-- buttons while open, the leader or winner after). A row you chose on can be closed (X); a roll you
-- passed on or let run out leaves at once (always: the Hide Passed Rolls switch went, 11-15).
--------------------------------------------------
local ROW_H, ROW_ICON, ROW_BUTTON, MAX_ROWS = 24, 20, 20, 8
local ROW_W = W - 2 * PAD

local function OnButtonEnter(b)
    if not Tip(b, "ANCHOR_RIGHT") then return end
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
    card.timeText = Text(card, "GameFontHighlightSmall", true)
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
    card.name = Text(card, "GameFontNormal")
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
        if Safe(info.isSelf) then roll = Safe(info.roll) or roll end
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
    if not roll or Safe(info.isSelf) then return "" end
    return " |cff999999(" .. roll .. ")|r"
end

-- the leader, then the winner; short (the rows): name and roll only, and yours
local function ResultText(s, short)
    local d = s.drop
    if d then
        if Safe(d.allPassed) then return "|cff999999" .. L["Everyone passed"] .. "|r" end
        local winner = Safe(d.winner)
        if type(winner) == "table" then
            local roll = Safe(winner.roll)
            local text = ClassName(winner.playerName, winner.playerClass) .. (roll and (" |cff40ff40" .. roll .. "|r") or "")
            return short and (text .. Yours(s, winner)) or L["Winner: %s"]:format(text)
        end
    end
    if s.unknown then return "|cff999999" .. L["No result"] .. "|r" end
    local lead = d and Safe(d.currentLeader)
    local leadRoll = type(lead) == "table" and Safe(lead.roll) or nil
    if leadRoll then
        local text = ClassName(lead.playerName, lead.playerClass) .. " |cffffd100" .. leadRoll .. "|r"
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
    card.mine = Text(card, "GameFontHighlightSmall", true)
    card.mine:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -3)
    card.mine:SetWidth(TEXT_W - 20)
    card.mine:SetJustifyH("LEFT")
    card.mine:SetWordWrap(false)
    card.sub = Text(card, "GameFontHighlightSmall", true)
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
    texts[row.name] = true   -- the rows' item names in the small size
    StyleText(row.name, true)
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
        if not Tip(self, "ANCHOR_RIGHT") then return end
        GameTooltip:SetText(L["Close"])
        GameTooltip:Show()
    end)
    row.close:SetScript("OnLeave", GameTooltip_Hide)
    row.chosen = row:CreateTexture(nil, "ARTWORK")
    row.chosen:SetSize(15, 15)
    row.chosen:SetPoint("RIGHT", row.close, "LEFT", -4, 0)
    row.result = Text(row, "GameFontHighlightSmall", true)
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
    return not (s.choice == 0 and s.status ~= "rolling" and not s.sample)
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
    -- the Gamepad UI has its own roll frame (GamepadGroupLootRollFrame): this one steps back
    win:SetShown(#list > 0 and not ns.IsGamepadUI())
    FitHolder()
end

--------------------------------------------------
-- 6. EDIT MODE SAMPLES: one roll still open, one won (Shadowfang, Tail Spike)
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
    LR.previewing = nil
    for i = #order, 1, -1 do
        if order[i].sample then RemoveQuiet(order[i]) end
    end
    Refresh()
end

local function ShowSamples()
    HideSamples()
    LR.previewing = true
    GameTooltip:Hide()
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
-- 7. POSITION AND SCALE (per Edit Mode layout). The Movers' "FlareUI Loot Rolls" frame (Blizzard's roll
-- frames, Movers.lua) and this window are one Edit Mode frame, so they share its saved spot
-- (tweaks.moverLayouts[layout].loot) and scale (tweaks.lootScale): a spot placed before carries over.
-- Only one of the two is made in a session (Movers.lua skips its loot rolls while this module loads).
--------------------------------------------------
local function Scale()
    local db = GetDb()
    return math_max(0.5, math_min(2, db and tonumber(db.lootScale) or 1))
end

-- (as Movers.lua GetLayoutStore: a layout with no spot of its own starts from the home layout's)
local function GetLayoutStore(layoutName)
    local db = GetDb()
    if not db then return nil end
    layoutName = layoutName or LEM:GetActiveLayoutName() or "Modern"
    db.moverLayouts = db.moverLayouts or {}
    local store = ns.LayoutHome(db.moverLayouts, layoutName)
    if rawget(store, MOVER_KEY) == nil then
        local home = store[MOVER_KEY]
        store[MOVER_KEY] = type(home) == "table" and CopyTable(home) or {}
    end
    return store[MOVER_KEY]
end

-- (11-15) The holder is the Edit Mode box. Outside Edit Mode it is the header (W x HEADER): the saved
-- spot is that box's, as before. While the samples show it covers the whole window, so the selection
-- and the snapping take all of it; it keeps its top left, where the window hangs from (the window
-- grows down). Re-fitted after every Refresh (samples in or out, rows coming and going).
function FitHolder()
    if not holder then return end
    local scale = Scale()
    local height = (LR.previewing and win:IsShown()) and win:GetHeight() or HEADER
    local w, h = W * scale, height * scale
    if math.abs(holder:GetWidth() - w) < 0.01 and math.abs(holder:GetHeight() - h) < 0.01 then return end
    local left, top = holder:GetLeft(), holder:GetTop()
    holder:SetSize(w, h)
    if left and top then
        holder:ClearAllPoints()
        holder:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    end
end

-- the saved spot, on the header-size box; then fitted to the window again while the samples show
local function ApplyPosition(layoutName)
    local store = GetLayoutStore(layoutName)
    local pos = (store and store.point) and store or DEFAULTS
    local scale = Scale()
    holder:SetSize(W * scale, HEADER * scale)
    holder:ClearAllPoints()
    holder:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
    FitHolder()
end

local function ApplyScale()
    win:SetScale(Scale())
    ApplyPosition()
end

-- Edit Mode measured the whole window: the spot saved is the header box's at the same top left (the
-- same point, its x unchanged as the width is). Reset Position hands over the default as it is.
local function OnMoved(_, layoutName, point, x, y)
    local store = GetLayoutStore(layoutName)
    if not store then return end
    local reset = point == DEFAULTS.point and x == DEFAULTS.x and y == DEFAULTS.y
    local left, top = holder:GetLeft(), holder:GetTop()
    local headerH = HEADER * Scale()
    if not reset and left and top and holder:GetHeight() > headerH + 0.5 then
        local screenH = UIParent:GetHeight()
        if point:find("TOP") then
            y = top - screenH
        elseif point:find("BOTTOM") then
            y = top - headerH
        else
            y = top - headerH / 2 - screenH / 2
        end
        holder:ClearAllPoints()
        holder:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    end
    store.point, store.x, store.y = point, math_floor(x + 0.5), math_floor(y + 0.5)
    if reset then ApplyPosition(layoutName) end
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
-- 8. BLIZZARD'S ROLL FRAMES
-- START_LOOT_ROLL no longer reaches them (Init), but Blizzard still opens them for every open roll
-- after a loading screen or /reload (GameEvent.HandlePlayerEnteringWorld -> GroupLootContainer_RefreshRolls)
-- and on leaving the Gamepad UI (GroupLootContainer_UninitGamepad). They are left to Blizzard's own
-- bookkeeping (shown, removed on CANCEL_LOOT_ROLL) but drawn invisible and click-through, and their
-- container stays 1 high. Hiding the container instead would re-lay the bottom managed frames
-- (ExtraAbilityContainer among them) from FlareUI's code: taint. No Blizzard table is written.
--------------------------------------------------
local function MuteRollFrame(frame)
    frame:SetAlpha(0)
    frame:EnableMouse(false)
    if frame.IconFrame then frame.IconFrame:EnableMouse(false) end
    local buttons = frame.LootButtonContainer
    if buttons then
        for _, key in ipairs({ "NeedButton", "PassButton", "GreedButton", "TransmogButton" }) do
            if buttons[key] then buttons[key]:EnableMouse(false) end
        end
    end
end

local function MuteBlizzardRolls()
    for i = 1, 4 do
        local frame = _G["GroupLootFrame" .. i]
        if frame then
            MuteRollFrame(frame)
            frame:HookScript("OnShow", MuteRollFrame)
        end
    end
    -- (as Movers.lua FlattenLoot: the bottom managed frames and the toasts leave no room for it)
    local container = _G.GroupLootContainer
    if container then
        local sizing = false
        hooksecurefunc(container, "SetHeight", function(self, height)
            if sizing or height == 1 then return end
            sizing = true
            self:SetHeight(1)
            sizing = false
        end)
        if container:GetHeight() ~= 1 then container:SetHeight(1) end
    end
end

--------------------------------------------------
-- 9. SETUP
-- On needs a reload (the switch is a reload row); off does too: this loads only at login.
--------------------------------------------------
function LR:Refresh()
    Refresh()
end

-- Bags & Looting > Fonts > Loot Rolls changed: every text in the window, live
-- Frame Opacity, live
function LR:ApplyOpacity()
    if win then Panel(win) end
end

function LR:ApplyFont()
    for fs, small in pairs(texts) do StyleText(fs, small) end
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
    MuteBlizzardRolls()
    -- OK on the "will bind to you" question (Blizzard's dialog, or Skip Loot Confirmations)
    hooksecurefunc("ConfirmLootRoll", function(rollID)
        local s = sessions[Safe(rollID) or false]
        if s then s.confirmed = true end
    end)

    holder = CreateFrame("Frame", "FlareUI_LootRolls", UIParent)
    holder:SetClampedToScreen(true)
    win = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    win:SetWidth(W)
    win:SetPoint("TOPLEFT", holder, "TOPLEFT")
    win:SetFrameStrata("HIGH")
    win:SetClampedToScreen(true)
    Panel(win)
    win:Hide()
    local title = Text(win, "GameFontNormal")
    title:SetPoint("TOPLEFT", PAD + 2, -9)
    title:SetText(L["Loot Rolls"])
    -- (11-15, Marcus) FlareUI's bronze, as a selected chat tab, not Blizzard's yellow
    title:SetTextColor(0.80, 0.60, 0.34)
    win.count = Text(win, "GameFontDisableSmall", true)
    win.count:SetPoint("LEFT", title, "RIGHT", 5, 0)
    -- Blizzard's loot history window (/loot): every roll and its winner (FlareUI keeps no history)
    if ToggleLootHistoryFrame then
        local historyButton = HeaderButton(win, HISTORY_ICON, function()
            if ToggleLootHistoryFrame then ToggleLootHistoryFrame() end
        end, L["Loot History"])
        historyButton:SetPoint("TOPRIGHT", -PAD + 2, -5)
    end
    -- (11-15, Marcus) the chat's and Damage Meter's header separator (Blizzard's tooltip divider)
    local line = win:CreateTexture(nil, "OVERLAY")
    line:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
    line:SetHeight(8)
    line:SetPoint("TOPLEFT", 3, -HEADER + 4)
    line:SetPoint("TOPRIGHT", -3, -HEADER + 4)
    more = Text(win, "GameFontDisableSmall", true)
    win.split = Line(win, 0.35)

    ApplyScale()   -- (and the spot: ApplyPosition)
    LEM:AddFrame(holder, OnMoved, DEFAULTS, L["FlareUI Loot Rolls"])
    local selection = LEM.frameSelections and LEM.frameSelections[holder]
    if selection then
        selection:SetFrameStrata("HIGH")
        selection:SetFrameLevel(win:GetFrameLevel() + 20)
    end
    LEM:AddFrameSettings(holder, ns.EditSection("Frame", { ScaleSetting() }))
    LEM:RegisterCallback("layout", function(layoutName) ApplyPosition(layoutName) end)
    LEM:RegisterCallback("enter", ShowSamples)
    -- out of Edit Mode: back to the header box on its saved spot
    LEM:RegisterCallback("exit", function() HideSamples(); ApplyPosition() end)

    local events = CreateFrame("Frame")
    for _, event in ipairs({ "START_LOOT_ROLL", "CONFIRM_LOOT_ROLL", "CANCEL_LOOT_ROLL", "CANCEL_ALL_LOOT_ROLLS", "PLAYER_ENTERING_WORLD" }) do
        events:RegisterEvent(event)
    end
    for _, event in ipairs({ "LOOT_HISTORY_UPDATE_DROP", "LOOT_HISTORY_UPDATE_ENCOUNTER", "LOOT_HISTORY_CLEAR_HISTORY",
            "INPUT_DEVICE_INTERFACE_TRANSITION" }) do
        pcall(events.RegisterEvent, events, event)
    end
    events:SetScript("OnEvent", function(_, event, a, b)
        if event == "START_LOOT_ROLL" then
            StartRoll(a, b)
        elseif event == "CONFIRM_LOOT_ROLL" then
            local s = sessions[a]
            if s and s.status == "rolling" then WatchConfirm(s) end
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
        elseif event == "INPUT_DEVICE_INTERFACE_TRANSITION" then
            -- into or out of the Gamepad UI: the window steps back or returns (Refresh), once the style is set
            C_Timer.After(0, Refresh)
        elseif event == "PLAYER_ENTERING_WORLD" then
            for _, rollID in ipairs(GetActiveLootRollIDs and GetActiveLootRollIDs() or {}) do StartRoll(rollID) end
        end
    end)
end
