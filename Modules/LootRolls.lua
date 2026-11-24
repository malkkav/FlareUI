local _, ns = ...
local L = ns.L

--------------------------------------------------
-- LOOT ROLLS (Bags & Looting > Looting > Loot Roll Window, off)
-- FlareUI's loot roll window in place of Blizzard's roll frames. Every roll still to decide gets a
-- card (Need / Greed / Pass, timer, the leader); the ones you chose on are one-line rows below, and
-- everyone's roll shows on hover. A roll you passed on or let run out leaves at once; the others hide
-- a few seconds after they are won or lost for you, which can be before the roll ends. The header icon opens Blizzard's loot history. Placed and scaled
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

-- no tooltips on the Edit Mode samples: LR.previewing while they show
local function Tip(owner, anchor)
    if LR.previewing then return false end
    ns.OwnGameTooltip(owner, anchor)
    return true
end

local W, PAD, HEADER = 300, 8, 26
local BOX_PAD = 8            -- inside the box of a card or row
local TEXT_W = W - 2 * PAD - 2 * BOX_PAD - 49   -- right of the icon, to the card's right edge
-- Need over Greed, Pass apart beside the two: side by side, Need is easy to click by mistake
local ICON, CARD_H, BUTTON, ROW, CARD_GAP = 40, 72, 21, 15, 6
local BUTTON_GAP, PASS_GAP = 4, 8
local BUTTON_COL = 2 * BUTTON + PASS_GAP + 8
local HOLD = 6               -- seconds a row stays once its roll is decided for you
local GUARD = 0.2            -- seconds a card's roll buttons ignore clicks after it came to rest under the pointer
local URGENT = 5             -- the last seconds of a roll you have not chosen on: its timer pulses
local RESULT_GRACE = 30     -- seconds after the roll's end to wait for its result
local ITEM_RETRY_DELAY = 0.25
-- the same as the Movers' loot default (one Edit Mode frame)
local DEFAULTS = { point = "TOP", x = 0, y = -221 }
local MOVER_KEY = "loot"     -- tweaks.moverLayouts[layout].loot: the Movers' "FlareUI Loot Rolls" spot
local HISTORY_ICON = "Interface\\AddOns\\FlareUI\\Media\\Icons\\DMSegments.tga"
local ICON_COLOR = { r = 0.61, g = 0.48, b = 0.29, a = 1 }

local RS = (Enum and Enum.EncounterLootDropRollState)
    or { NeedMainSpec = 0, NeedOffSpec = 1, Transmog = 2, Greed = 3, NoRoll = 4, Pass = 5 }
local TYPE = { [RS.NeedMainSpec] = 1, [RS.NeedOffSpec] = 1, [RS.Greed] = 2, [RS.Transmog] = 4, [RS.Pass] = 0 }
-- the client's own words, unless FlareUI's language has words of its own (Hungarian has no client)
local LABEL = {
    [0] = L["Pass"] ~= "Pass" and L["Pass"] or _G.PASS,
    [1] = L["Need"] ~= "Need" and L["Need"] or _G.NEED,
    [2] = L["Greed"] ~= "Greed" and L["Greed"] or _G.GREED,
    [4] = L["Transmog"] ~= "Transmog" and L["Transmog"] or _G.TRANSMOGRIFICATION,
}
local BUTTON_ATLAS = { [0] = "pass", [1] = "need", [2] = "greed", [4] = "transmog" }
local RANK = { [1] = 1, [4] = 2, [2] = 3, [0] = 4 }

local sessions, order = {}, {}   -- rollID -> session; sessions by start
local bound = {}                  -- "encounter:lootListKey" -> session, or true once forgotten
local guard, scroll, hold = 0, 0, 0
local holder, win, more, queued
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

-- won or lost, when the roll ends or as soon as that is certain (Outcome): the row leaves after HOLD
local function Settle(s)
    if s.settled or s.sample then return end
    s.settled = true
    C_Timer.After(HOLD, function() Forget(s) end)
end

local function Finish(s)
    if s.status == "done" then return end
    s.status = "done"
    Settle(s)
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
    local texture, name, count, quality, bop, canNeed, canGreed, _, reasonNeed, reasonGreed = GetLootRollItemInfo(s.rollID)
    if not name then
        if s.status == "rolling" then
            C_Timer.After(ITEM_RETRY_DELAY, function()
                if sessions[s.rollID] == s then ReadItem(s) end
            end)
        end
        return
    end
    s.texture, s.name, s.count, s.quality, s.bop = texture, name, count or 1, quality, bop
    s.canNeed, s.canGreed = canNeed, canGreed
    s.reasonNeed, s.reasonGreed = reasonNeed, reasonGreed
    s.link = GetLootRollItemLink(s.rollID)
    s.loaded = true
    BindAll()
    Refresh()
end

-- whether the game still lists the roll as open
local OPEN_LATE = 300   -- seconds past its time after which a listed roll is let go anyway
local function StillOpen(rollID)
    for _, id in ipairs(GetActiveLootRollIDs and GetActiveLootRollIDs() or {}) do
        if id == rollID then return true end
    end
    return false
end

local function StartRoll(rollID, rollTimeMs)
    if sessions[rollID] then return end
    rollTimeMs = rollTimeMs or (C_Loot and C_Loot.GetLootRollDuration and C_Loot.GetLootRollDuration(rollID))
    local s = NewSession(rollID, (rollTimeMs or 60000) / 1000)
    local since = C_LootHistory.GetLootHistoryTime and Safe(C_LootHistory.GetLootHistoryTime())
    s.since = type(since) == "number" and since or nil
    -- the roll's end event can be missed (a loading screen): closed after its time anyway. Not while the
    -- game still lists it (11-24): the server can keep a roll open past its time, and it can be answered.
    local function CloseLate()
        if sessions[rollID] ~= s or s.status ~= "rolling" then return end
        if StillOpen(rollID) and GetTime() < s.t0 + s.duration + OPEN_LATE then
            C_Timer.After(5, CloseLate)
            return
        end
        Close(s)
        Refresh()
    end
    C_Timer.After(s.duration + 5, CloseLate)
    ReadItem(s)
    Refresh()
end

local function TimeLeft(s)
    if s.status ~= "rolling" then return nil end
    if s.sample then return s.duration * 0.6 end
    local left = GetLootRollTimeLeft(s.rollID)
    left = left and left / 1000
    -- no time, or one that can't be (the game has answered far more than the roll's length): our own clock
    if not left or left < 0 or left > s.duration + 1 then left = math_max(0, s.t0 + s.duration - GetTime()) end
    return left
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
    local edge = LSM:Fetch("border", "FlareUI Thick")
    frame:SetBackdrop({ edgeFile = edge, edgeSize = ns.BorderEdgeSize(edge, 16) })
    -- a little darker than FlareUI's bronze, on the plain rock
    local c, dim = ns.BORDER_COLOR, 0.75
    frame:SetBackdropBorderColor(c.r * dim, c.g * dim, c.b * dim, c.a)
    if not frame.skin then
        local rock = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
        rock:SetPoint("TOPLEFT", 3, -3)
        rock:SetPoint("BOTTOMRIGHT", -3, 3)
        rock:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock", "REPEAT", "REPEAT")
        rock:SetHorizTile(true)
        rock:SetVertTile(true)
        -- the settings window's ground, "Rock, natural" (Settings/Panel.lua LOOK_BG): the rock as it is,
        -- the wash and glow kept hidden; the shade toward the bottom stays. For the bronze look: the wash
        -- at 0.62 and the glow shown.
        local wash = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
        wash:SetAllPoints(rock)
        wash:SetColorTexture(0.05, 0.038, 0.026, 0)
        wash:Hide()
        local glow = frame:CreateTexture(nil, "BACKGROUND", nil, 3)
        glow:SetPoint("TOPLEFT", rock)
        glow:SetPoint("TOPRIGHT", rock)
        glow:SetHeight(2 * HEADER)
        glow:SetColorTexture(1, 1, 1)
        glow:SetGradient("VERTICAL", CreateColor(0.55, 0.41, 0.22, 0), CreateColor(0.55, 0.41, 0.22, 0.20))
        glow:Hide()
        local shade = frame:CreateTexture(nil, "BACKGROUND", nil, 3)
        shade:SetAllPoints(rock)
        shade:SetColorTexture(1, 1, 1)
        shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.45), CreateColor(0, 0, 0, 0))
        frame.skin = { rock, wash, glow, shade }
    end
    -- (11-23, Malkkav: always full strength; Background Opacity removed, see-through read badly)
end

local function Box(frame)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = LSM:Fetch("border", "FlareUI Thin"), edgeSize = 8,
        insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    frame:SetBackdropColor(0, 0, 0, 0.3)
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
    b.icon:SetSize(12, 12)
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
-- Every roll still to decide gets a card, up to MAX_CARDS (the rest wait their turn); a roll you
-- chose on is a one-line row with the leader or winner and no buttons. A row can be closed (X); a
-- roll you passed on or let run out leaves at once.
--------------------------------------------------
local ROW_H, ROW_GAP, ROW_ICON, MAX_CARDS, MAX_ROWS = 32, 4, 20, 4, 5
local ROW_PAD = (ROW_H - ROW_ICON) / 2   -- left of a row's icon as above and below it
local ROW_W = W - 2 * PAD
local RESULT_W = 104

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
    b:SetScript("OnClick", function()
        if card.session and GetTime() >= math_max(guard, card.guard or 0) then Roll(card.session, rollType) end
    end)
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

local function RollButtons(card)
    card.pass = NewButton(card, 0, BUTTON)
    card.greed = NewButton(card, 2, BUTTON)
    card.need = NewButton(card, 1, BUTTON)
    card.need:SetPoint("TOPRIGHT", -BOX_PAD - BUTTON - PASS_GAP, -BOX_PAD)
    card.greed:SetPoint("TOP", card.need, "BOTTOM", 0, -BUTTON_GAP)
    card.pass:SetPoint("LEFT", card.need, "BOTTOMRIGHT", PASS_GAP, -BUTTON_GAP / 2)
end

local function FillButtons(card, s)
    local open = s.status == "rolling" and s.loaded
    SetButton(card.need, open, s.canNeed, s.reasonNeed)
    SetButton(card.greed, open, s.canGreed, s.reasonGreed)
    SetButton(card.pass, open, true)
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
    -- gold to red over the second half, in 20 steps: the colour is set per step, not per frame
    local low = fraction < 0.5 and math_ceil((1 - fraction * 2) * 20) or 0
    if card.timerLow ~= low then
        card.timerLow = low
        local t = low / 20
        card.timer:SetStatusBarColor(1 - 0.1 * t, 0.75 - 0.55 * t, 0.1 + 0.05 * t)
    end
    local second = math_ceil(left)
    if card.timerSecond ~= second then
        card.timerSecond = second
        card.timeText:SetText(second)
        local pulse = card.timer.pulse
        if pulse then
            local urgent = second <= URGENT and not (s.choice or s.pending)
            if urgent ~= pulse:IsPlaying() then
                if urgent then pulse:Play() else pulse:Stop() end
                card.timeText:SetTextColor(1, urgent and 0.3 or 1, urgent and 0.25 or 1)
            end
        end
    end
end

local function StartTimer(card, s)
    card.timerLow, card.timerSecond = nil, nil   -- pooled cards must repaint their first tick
    if card.timer.pulse then
        card.timer.pulse:Stop()
        card.timeText:SetTextColor(1, 1, 1)
    end
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
    card.timer:SetStatusBarTexture(LSM:Fetch("statusbar", "FlareUI Dark"))
    card.timer:SetMinMaxValues(0, 1)
    local bg = card.timer:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.6)
    card.timer.pulse = card.timer:CreateAnimationGroup()
    card.timer.pulse:SetLooping("BOUNCE")
    local dim = card.timer.pulse:CreateAnimation("Alpha")
    dim:SetFromAlpha(1)
    dim:SetToAlpha(0.3)
    dim:SetDuration(0.3)
    dim:SetSmoothing("IN_OUT")
    card.timeText = Text(card, "GameFontHighlightSmall", true)
end

local live = {}                              -- the cards and rows in use (frame -> true)
local free = { [true] = {}, [false] = {} }   -- the ones to use again: cards, rows

local function Release(card)
    card.session, card.leaving = nil, nil
    card.fade:Stop()
    card.out:Stop()
    if card.timer then card.timer.pulse:Stop() end
    card:SetScript("OnUpdate", nil)
    card:Hide()
    if live[card] then
        live[card] = nil
        local pool = free[card.big]
        pool[#pool + 1] = card
    end
end

-- the item icon with its tooltip and links; everyone's roll on the rest of the card
local function ItemParts(card, size)
    Box(card)
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
    card.won = card:CreateTexture(nil, "BACKGROUND", nil, 1)
    card.won:SetPoint("TOPLEFT", 4, -4)
    card.won:SetPoint("BOTTOMRIGHT", -4, 4)
    card.won:SetColorTexture(1, 1, 1, 1)
    card.won:SetGradient("HORIZONTAL", CreateColor(1, 0.82, 0, 0.28), CreateColor(1, 0.82, 0, 0))
    card.fade = card:CreateAnimationGroup()
    local alpha = card.fade:CreateAnimation("Alpha")
    alpha:SetFromAlpha(0)
    alpha:SetToAlpha(1)
    alpha:SetDuration(0.2)
    card.out = card:CreateAnimationGroup()
    card.outAlpha = card.out:CreateAnimation("Alpha")
    card.outAlpha:SetFromAlpha(1)
    card.outAlpha:SetToAlpha(0)
    card.outAlpha:SetDuration(0.25)
    card.out:SetScript("OnFinished", function() Release(card) end)
end

local function Hop(region)
    local g = region.hop
    if not g then
        g = region:CreateAnimationGroup()
        local up = g:CreateAnimation("Translation")
        up:SetOffset(0, 5)
        up:SetDuration(0.08)
        up:SetOrder(1)
        up:SetSmoothing("OUT")
        local down = g:CreateAnimation("Translation")
        down:SetOffset(0, -5)
        down:SetDuration(0.14)
        down:SetOrder(2)
        down:SetSmoothing("IN")
        region.hop = g
    end
    g:Stop()
    g:Play()
end

local function Flash(row, r, g, b)
    row.flash:SetColorTexture(r, g, b, 1)
    row.flash.anim:Stop()
    row.flash.anim:Play()
end

-- a card or row whose roll left the window fades out where it is; the rows wait for a row's fade (Slide)
local function Leave(row)
    if row.leaving then return end
    row.leaving, row.session = true, nil
    row:SetScript("OnUpdate", nil)
    row.fade:Stop()
    row.outAlpha:SetFromAlpha(row:GetAlpha())
    row.out:Play()
    if not row.big then hold = GetTime() + row.outAlpha:GetDuration() end
end

local function Won(s)
    local winner = s.drop and Safe(s.drop.winner)
    return type(winner) == "table" and Safe(winner.isSelf) and true or false
end

local function FillHead(card, s)
    if card.session ~= s then card.fade:Play() end
    card.won:SetShown(Won(s))
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

-- the item level and where it is worn; "" for an item that is not worn
local function InfoText(s)
    local link = s.link
    if type(link) ~= "string" or not link:find("item:") then return "" end
    local _, _, subType, equipLoc, _, classID, subClassID = C_Item.GetItemInfoInstant(link)
    local slot = equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE" and _G[equipLoc]
    if not slot then return "" end
    local kind = slot
    if classID == 2 then
        kind = subType or slot
    elseif classID == 4 and subClassID and subClassID >= 1 and subClassID <= 4 and subType then
        kind = slot .. ", " .. subType
    end
    local ok, level = pcall(C_Item.GetDetailedItemLevelInfo, link)
    local text = "|cffb0b0b0" .. kind .. "|r"
    if ok and type(level) == "number" and level > 1 then text = level .. "  " .. text end
    return text
end

-- your choice and roll, or what to know before choosing
local function MineText(s)
    local choice = s.choice or s.pending
    if not choice then
        local info = InfoText(s)
        if info ~= "" then return info end
        return s.bop and ("|cffff8040" .. (_G.ITEM_BIND_ON_PICKUP or "") .. "|r") or ""
    end
    local roll = MyRoll(s)
    return L["You: %s"]:format((LABEL[choice] or "?") .. (roll and (" " .. roll) or ""))
end

-- the Need / Greed / Transmog icon of what a player chose, to stand before their name
local function ChoiceMark(info)
    local rollType = StateType(info.state)
    return rollType and ("|A:" .. ChoiceAtlas(rollType) .. ":12:12|a ") or ""
end

-- the leader, then the winner; short (the rows): name and roll only
local function ResultText(s, short)
    local d = s.drop
    if d then
        if Safe(d.allPassed) then return "|cff999999" .. L["Everyone passed"] .. "|r" end
        local winner = Safe(d.winner)
        if type(winner) == "table" then
            local roll = Safe(winner.roll)
            local text = ChoiceMark(winner) .. ClassName(winner.playerName, winner.playerClass) .. (roll and (" |cff40ff40" .. roll .. "|r") or "")
            return short and text or L["Winner: %s"]:format(text)
        end
    end
    if s.unknown then return "|cff999999" .. L["No result"] .. "|r" end
    local lead = d and Safe(d.currentLeader)
    local leadRoll = type(lead) == "table" and Safe(lead.roll) or nil
    if leadRoll then
        local text = ChoiceMark(lead) .. ClassName(lead.playerName, lead.playerClass) .. " |cffffd100" .. leadRoll .. "|r"
        return short and text or L["Leading: %s"]:format(text)
    end
    return short and "" or ("|cff999999" .. L["No rolls yet"] .. "|r")
end

local function NewCard()
    local card = CreateFrame("Frame", nil, win, "BackdropTemplate")
    card:SetSize(ROW_W, CARD_H)
    card.big = true
    ItemParts(card, ICON)
    card.icon:SetPoint("TOPLEFT", BOX_PAD, -BOX_PAD)
    card.count = card.icon:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    card.count:SetPoint("BOTTOMRIGHT", -1, 1)
    RollButtons(card)
    card.name:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 9, -1)
    card.name:SetWidth(TEXT_W - BUTTON_COL)
    card.mine = Text(card, "GameFontHighlightSmall", true)
    card.mine:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -3)
    card.mine:SetWidth(TEXT_W - BUTTON_COL - 34)
    card.mine:SetJustifyH("LEFT")
    card.mine:SetWordWrap(false)
    card.sub = Text(card, "GameFontHighlightSmall", true)
    card.sub:SetPoint("TOPLEFT", card.mine, "BOTTOMLEFT", 0, -2)
    card.sub:SetWidth(TEXT_W - BUTTON_COL)
    card.sub:SetJustifyH("LEFT")
    card.sub:SetWordWrap(false)
    -- how many of the group have chosen: "3/5"
    card.rolled = Text(card, "GameFontHighlightSmall", true)
    card.rolled:SetPoint("TOP", card.mine, "TOP")
    card.rolled:SetPoint("RIGHT", card, "RIGHT", -BOX_PAD - BUTTON_COL, 0)
    Timer(card, 6)
    card.timer:SetPoint("BOTTOMLEFT", BOX_PAD, BOX_PAD)
    card.timer:SetWidth(ROW_W - 2 * BOX_PAD - 26)
    card.timeText:SetPoint("LEFT", card.timer, "RIGHT", 5, 0)
    return card
end

local function FillCard(card, s)
    FillHead(card, s)
    card.count:SetText((s.count or 1) > 1 and s.count or "")
    card.mine:SetText(MineText(s))
    card.sub:SetText(ResultText(s))
    local chose, waiting = SortedRolls(s.drop and s.drop.rollInfos)
    local total = #chose + #waiting
    card.rolled:SetText(total > 0 and ("|cff999999" .. #chose .. "/" .. total .. "|r") or "")
    FillButtons(card, s)
    StartTimer(card, s)
    card:Show()
    RefreshTooltip(card, s)
end

local function NewRow()
    local row = CreateFrame("Frame", nil, win, "BackdropTemplate")
    row:SetSize(ROW_W, ROW_H)
    row.big = false
    ItemParts(row, ROW_ICON)
    row.icon:SetPoint("LEFT", ROW_PAD, 0)
    texts[row.name] = true   -- the rows' item names in the small size
    StyleText(row.name, true)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 7, 0)
    row.close = CreateFrame("Button", nil, row)
    row.close:SetSize(14, 14)
    row.close:SetPoint("RIGHT", -BOX_PAD, 0)
    row.close:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
    row.close:SetHighlightTexture("Interface\\Buttons\\UI-StopButton", "ADD")
    local cross = row.close:GetNormalTexture()
    cross:SetDesaturated(true)
    cross:SetVertexColor(ICON_COLOR.r, ICON_COLOR.g, ICON_COLOR.b)
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
    -- on the right: your choice and roll, a divider, then the leader or winner (yours go when you lead)
    row.result = Text(row, "GameFontHighlightSmall", true)
    row.result:SetPoint("RIGHT", row.close, "LEFT", -6, 0)
    row.result:SetJustifyH("RIGHT")
    row.result:SetWordWrap(false)
    row.sep = Line(row, 0.6)
    row.sep:SetSize(1, 14)
    row.sep:SetPoint("RIGHT", row.result, "LEFT", -6, 0)
    row.roll = Text(row, "GameFontHighlightSmall", true)
    row.roll:SetPoint("RIGHT", row.sep, "LEFT", -6, 0)
    row.chosen = row:CreateTexture(nil, "ARTWORK")
    row.chosen:SetSize(15, 15)
    row.chosen:SetPoint("RIGHT", row.roll, "LEFT", -2, 0)
    row.flash = row:CreateTexture(nil, "OVERLAY")
    row.flash:SetPoint("TOPLEFT", 4, -4)
    row.flash:SetPoint("BOTTOMRIGHT", -4, 4)
    row.flash:SetBlendMode("ADD")
    row.flash:SetAlpha(0)
    row.flash.anim = row.flash:CreateAnimationGroup()
    local rise = row.flash.anim:CreateAnimation("Alpha")
    rise:SetFromAlpha(0)
    rise:SetToAlpha(0.35)
    rise:SetDuration(0.1)
    rise:SetOrder(1)
    local fall = row.flash.anim:CreateAnimation("Alpha")
    fall:SetFromAlpha(0.35)
    fall:SetToAlpha(0)
    fall:SetDuration(0.5)
    fall:SetOrder(2)
    return row
end

-- whether the leader already beats your choice and roll: the roll is lost before it ends
local function Beaten(s, choice, roll)
    local lead = s.drop and Safe(s.drop.currentLeader)
    if type(lead) ~= "table" or Safe(lead.isSelf) then return false end
    local mine, theirs = RANK[choice], RANK[StateType(lead.state)]
    if not mine or not theirs then return false end
    if theirs ~= mine then return theirs < mine end
    local leadRoll = Safe(lead.roll)
    return type(roll) == "number" and type(leadRoll) == "number" and leadRoll > roll
end

-- the roll is yours before the game says so: you lead and everyone in the group has chosen
local function Decided(s)
    local d = s.drop
    local lead = d and Safe(d.currentLeader)
    if type(lead) ~= "table" or not Safe(lead.isSelf) then return false end
    local chose, waiting = SortedRolls(d.rollInfos)
    return #waiting == 0 and #chose >= math_max(1, GetNumGroupMembers())
end

-- won, lost: how a roll you chose on stands for you (neither while it is open to both)
local function Outcome(s)
    local choice = s.choice or s.pending
    local won = Won(s) or Decided(s)
    return won, not won and (s.status == "done" or Beaten(s, choice, choice and MyRoll(s)))
end

local function FillRow(row, s)
    FillHead(row, s)
    local choice = s.choice or s.pending
    local roll = choice and MyRoll(s)
    local won, lost = Outcome(s)
    local lead = s.drop and Safe(s.drop.currentLeader)
    local leading = not won and type(lead) == "table" and Safe(lead.isSelf) and true or false
    local mine = choice and not won and not leading and true or false
    row.won:SetShown(won)
    row.result:SetText(ResultText(s, true))
    local resultW = math_min(RESULT_W, math_ceil(row.result:GetUnboundedStringWidth() or 0))
    row.result:SetWidth(math_max(1, resultW))
    row.chosen:SetShown(mine)
    row.roll:SetShown(mine)
    row.sep:SetShown(mine and resultW > 0)
    local mineW = 0
    if mine then
        row.chosen:SetAtlas(ChoiceAtlas(choice))
        row.chosen:SetDesaturated(lost)
        row.roll:SetText(roll or "")
        row.roll:SetTextColor(lost and 0.6 or 1, lost and 0.6 or 1, lost and 0.6 or 1)
        local rollW = math_ceil(row.roll:GetUnboundedStringWidth() or 0)
        row.roll:SetWidth(math_max(1, rollW))
        mineW = 15 + 2 + rollW + 13
    end
    row.icon.texture:SetDesaturated(lost)
    if lost then
        row.name:SetTextColor(0.6, 0.6, 0.6)
        local grey = ns.PALETTE.warmGrey   -- a lost roll: the palette's warm grey, not a cold one
        row.icon.edge:SetBackdropBorderColor(grey[1], grey[2], grey[3], 1)
    end
    row.name:SetWidth(ROW_W - ROW_PAD - BOX_PAD - ROW_ICON - 7 - mineW - (resultW + 14 + 12))
    row:SetAlpha(lost and 0.6 or 1)
    row:Show()
    if choice and s.fxChoice ~= choice then
        s.fxChoice = choice
        Hop(row.chosen)
    end
    if roll and s.fxRoll ~= roll then
        s.fxRoll = roll
        Hop(row.roll)
    end
    if (won or lost) and not s.fxDone then
        s.fxDone = true
        if won then Flash(row, 1, 0.82, 0) else Flash(row, 1, 1, 1) end
    end
    RefreshTooltip(row, s)
end

local function Shown(s)
    if s.dismissed then return false end
    return not (s.choice == 0 and s.status ~= "rolling" and not s.sample)
end

local function Slide(_, elapsed)
    -- a row that leaves fades out first; then the rows close the gap and the window shrinks.
    -- The cards never wait: their click guard counts from their last move.
    local held = GetTime() < hold
    local step = math_min(1, elapsed * 14)
    local busy = held
    for row in pairs(live) do
        if not row.leaving and row.y ~= row.target and (row.big or not held) then
            -- a card moves faster and snaps sooner: its buttons wait for it
            local d = row.target - row.y
            if math.abs(d) < (row.big and 2 or 0.5) then
                row.y = row.target
            else
                row.y = row.y + d * (row.big and math_min(1, step * 1.5) or step)
                busy = true
            end
            row:SetPoint("TOPLEFT", PAD, -row.y)
            if row.big then row.guard = GetTime() + GUARD end
        end
    end
    if win.h ~= win.target and not held then
        local d = win.target - win.h
        if math.abs(d) < 0.5 then
            win.h = win.target
        else
            win.h = win.h + d * step
            busy = true
        end
        win:SetHeight(win.h)
    end
    -- clamped to the screen, the window shifts as its height changes: the cards move under the pointer
    local top = win:GetTop()
    if top and win.top and math.abs(top - win.top) > 0.5 then guard = GetTime() + GUARD end
    win.top = top
    if not busy then win:SetScript("OnUpdate", nil) end
end

-- a card or row stays with its roll, so it can slide to a new place instead of jumping there
local function Place(s, big, y, instant)
    local frame = s.card
    if not frame or frame.big ~= big or frame.session ~= s then
        frame = tremove(free[big]) or (big and NewCard() or NewRow())
        live[frame] = true
        frame.y = nil
    end
    if big then
        -- a card that comes or moves may land under the pointer
        if not frame.y or frame.target ~= y then frame.guard = GetTime() + GUARD end
        FillCard(frame, s)
    else
        FillRow(frame, s)
    end
    frame.target = y
    if instant or not frame.y then
        frame.y = y
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", PAD, -y)
    end
    return frame
end

function Refresh()
    if not win then return end
    local open, rest, lost, listed, active = {}, {}, {}, {}, 0
    for _, s in ipairs(order) do
        if Shown(s) then
            listed[s] = true
            if s.status ~= "done" then active = active + 1 end
            if s.status == "rolling" then
                open[#open + 1] = s
            else
                local won, beaten = Outcome(s)
                if won or beaten then Settle(s) end
                local group = beaten and lost or rest
                group[#group + 1] = s
            end
        end
    end
    -- the rolls you lost go under the ones still to settle or won
    for _, s in ipairs(lost) do rest[#rest + 1] = s end

    local instant = LR.previewing or not win:IsShown()
    local used = {}
    local y, tail = HEADER + PAD - 2, 0   -- tail: the gap under the last piece
    for i = 1, math_min(#open, MAX_CARDS) do
        used[Place(open[i], true, y, instant)] = true
        y = y + CARD_H + CARD_GAP
        tail = CARD_GAP
    end
    local waiting = #open - MAX_CARDS
    queued:SetShown(waiting > 0)
    if waiting > 0 then
        queued:ClearAllPoints()
        queued:SetPoint("TOPLEFT", PAD + BOX_PAD, -y)
        queued:SetText(L["+%d more"]:format(waiting))
        y = y + ROW
        tail = ROW_GAP
    end
    local split = #open > 0 and #rest > 0
    win.split:SetShown(split)
    if split then
        win.split:ClearAllPoints()
        win.split:SetPoint("TOPLEFT", PAD, -y - 1)
        win.split:SetPoint("TOPRIGHT", -PAD, -y - 1)
        y = y + 8
    end

    -- more rows than fit: the mouse wheel scrolls them (only then, so the camera keeps its wheel)
    local maxScroll = math_max(0, #rest - MAX_ROWS)
    scroll = math_max(0, math_min(scroll, maxScroll))
    win:EnableMouseWheel(maxScroll > 0)
    local top = y
    for i = scroll + 1, math_min(#rest, scroll + MAX_ROWS) do
        used[Place(rest[i], false, y, instant)] = true
        y = y + ROW_H + ROW_GAP
        tail = ROW_GAP
    end
    -- shown another way or out of view: gone at once; a roll that left the window fades out
    for frame in pairs(live) do
        if not used[frame] then
            if instant or listed[frame.session] then Release(frame) else Leave(frame) end
        end
    end
    win.thumb:SetShown(maxScroll > 0)
    if maxScroll > 0 then
        local area = y - ROW_GAP - top
        win.thumb:ClearAllPoints()
        win.thumb:SetPoint("TOPRIGHT", -5, -(top + area * scroll / #rest))
        win.thumb:SetHeight(area * MAX_ROWS / #rest)
    end

    local extra = #rest - scroll - MAX_ROWS
    more:SetShown(extra > 0)
    if extra > 0 then
        more:ClearAllPoints()
        more:SetPoint("TOPLEFT", PAD + BOX_PAD, -y - 2)
        more:SetText(L["+%d more"]:format(extra))
        y = y + ROW
    end
    win.count:SetText(active > 0 and ("(" .. active .. ")") or "")
    -- grows at once (a new row is never outside the panel), shrinks with the rows sliding up
    win.target = y + PAD - tail
    if instant or not win.h or win.target > win.h then
        win.h = win.target
        win:SetHeight(win.h)
    end
    win:SetScript("OnUpdate", Slide)
    -- the Gamepad UI has its own roll frame (GamepadGroupLootRollFrame): this one steps back
    local total = #open + #rest
    if total > 0 and not ns.IsGamepadUI() then
        win.out:Stop()
        if not win:IsShown() then
            win:Show()
            -- (faded in a fight, it opens faded: the fade-in would flash it at full)
            if not LR.UpdateFade(true) then win.fade:Play() end
            guard = GetTime() + GUARD
        end
    elseif total == 0 and win:IsShown() then
        if not win.out:IsPlaying() then
            win.outAlpha:SetFromAlpha(win:GetAlpha())
            win.out:Play()
        end
    else
        win.out:Stop()
        win:Hide()
    end
    FitHolder()
end

--------------------------------------------------
-- 6. EDIT MODE SAMPLES: one roll still open, one lost (Shadowfang, Tail Spike)
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

-- quiet: no redraw (ShowSamples redraws once with the new samples)
local function HideSamples(quiet)
    LR.previewing = nil
    for i = #order, 1, -1 do
        if order[i].sample then RemoveQuiet(order[i]) end
    end
    if not quiet then
        Refresh()
        LR.UpdateFade()
    end
end

local function ShowSamples()
    HideSamples(true)
    LR.previewing = true
    LR.UpdateFade()
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

-- The holder is the Edit Mode box. Outside Edit Mode it is the header (W x HEADER): the saved spot is
-- that box's. While the samples show it covers the whole window, so the selection
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
-- 7b. FADE IN COMBAT (Edit Mode's Fading, off; 11-24, Aethamus). Not a Visibility element: those say when
-- a frame shows, and this window shows only while something is rolled. Pointing at it brings it back, and
-- so do the last seconds (URGENT) of a roll you have not chosen on; after the fight it is back at once.
--------------------------------------------------
LR.FADE_OPACITY, LR.FADE_TIME, LR.FADE_CHECK = 30, 0.2, 0.1   -- 30: at 0 a roll is easily lost
function LR.FadedAlpha()
    local db = GetDb()
    return math_max(0, math_min(100, db and tonumber(db.lootRollFadeOpacity) or LR.FADE_OPACITY)) / 100
end

-- faded now?
function LR.WantsFade()
    local db = GetDb()
    if not (db and db.lootRollFade and LR.inCombat) or LR.previewing or win:IsMouseOver() then return false end
    for _, s in ipairs(order) do
        if s.status == "rolling" and not (s.choice or s.pending) then
            local left = TimeLeft(s)
            if left and left <= URGENT then return false end
        end
    end
    return true
end

-- sets what the fader goes for; instant: at once. Returns whether the window is to be faded.
function LR.UpdateFade(instant)
    local fader = win and win.fader
    if not fader then return false end
    local faded = LR.WantsFade()
    local alpha = win:GetAlpha()
    if not faded then
        if alpha < 1 then
            win:SetAlpha(1)
            -- it came back under the pointer: not a roll by accident
            guard = GetTime() + GUARD
        end
    elseif instant then
        win:SetAlpha(LR.FadedAlpha())
    end
    local db = GetDb()
    -- it only runs (while the window shows) in a fight with the option on
    fader:SetShown(db and db.lootRollFade and LR.inCombat and not LR.previewing and true or false)
    fader.faded, fader.wait = faded, LR.FADE_CHECK
    return faded
end

function LR.FadeTick(fader, elapsed)
    fader.wait = (fader.wait or 0) - elapsed
    if fader.wait <= 0 then LR.UpdateFade() end
    if fader.faded then
        local alpha, target = win:GetAlpha(), LR.FadedAlpha()
        if alpha > target then
            win:SetAlpha(math_max(target, alpha - elapsed * (1 - target) / LR.FADE_TIME))
        end
    end
end

function LR.FadeSettings()
    return {
        { name = L["Faded Opacity"], kind = LEM.SettingType.Slider, default = LR.FADE_OPACITY, minValue = 0, maxValue = 100, valueStep = 5,
          formatter = function(value) return value end,   -- plain, as the other frames'
          get = function() return math_floor(LR.FadedAlpha() * 100 + 0.5) end,
          set = function(_, value)
              local db = GetDb()
              if not db then return end
              db.lootRollFadeOpacity = value ~= LR.FADE_OPACITY and value or nil
              LR.UpdateFade(true)
          end,
          hidden = function() local db = GetDb() return not (db and db.lootRollFade) end,
          desc = L["How see-through it gets when faded. 0% is invisible."] },
        { name = L["Fade in Combat"], kind = LEM.SettingType.Checkbox, default = false,
          get = function() local db = GetDb() return db and db.lootRollFade or false end,
          set = function(_, value)
              local db = GetDb()
              if not db then return end
              db.lootRollFade = value and true or nil
              LR.UpdateFade(true)
              LEM:RefreshFrameSettings(holder)
          end,
          desc = L["It fades while you fight. It comes back when you point at it, and for the last 5 seconds of a roll you haven't decided on."] },
    }
end

--------------------------------------------------
-- 8. BLIZZARD'S ROLL FRAMES
-- START_LOOT_ROLL doesn't reach them (Init), but Blizzard still opens them for every open roll
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
    LR.StyleTitle()
end

-- the title in the chat's and Damage Meter's header font (Damage Meter > Fonts > Header) and gold
function LR.StyleTitle()
    local title = win and win.title
    if not title then return end
    local DM = ns.DamageMeter
    local dm = ns.db and ns.db.profile and ns.db.profile.damagemeter
    local font = DM and DM.HeaderFontDb and DM.HeaderFontDb(dm)
    if not font then return end
    local flags = font.flags or "NONE"
    if flags == "NONE" then flags = "" end
    ns.SetFont(title, ns.GetFontPath(font.face or "Friz Quadrata TT"), font.size or 12, flags)
    if ns.ApplyShadow then ns.ApplyShadow(title, font) end
    local c = font.color or { r = 0.80, g = 0.60, b = 0.34 }
    title:SetTextColor(c.r, c.g, c.b, c.a or 1)
end

-- Bags & Looting > Fonts > Loot Rolls changed: every text in the window, live
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
    -- the header as the chat's and Damage Meter's: their title font and gold, the
    -- title and icon on one row centred 15 px down, the title 17 px in, the icon 21.5 px from the
    -- right edge, the separator at 24 px (DamageMeter.lua's TITLE_LEFT, ROW_CENTER_Y, ICON_RIGHT)
    local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", win, "TOPLEFT", 17, -15)
    title:SetText(L["Loot Rolls"])
    win.title = title
    LR.StyleTitle()
    win.count = Text(win, "GameFontDisableSmall", true)
    win.count:SetPoint("LEFT", title, "RIGHT", 5, 0)
    -- Blizzard's loot history window (/loot): every roll and its winner (FlareUI keeps no history)
    if ToggleLootHistoryFrame then
        local historyButton = HeaderButton(win, HISTORY_ICON, function()
            if ToggleLootHistoryFrame then ToggleLootHistoryFrame() end
        end, L["Loot History"])
        historyButton:SetSize(22, 22)
        historyButton.icon:SetSize(11, 11)   -- the meter's segments icon, drawn as there
        historyButton:SetPoint("CENTER", win, "TOPRIGHT", -21.5, -15)
    end
    -- the chat's and Damage Meter's header separator (Blizzard's tooltip divider)
    local line = win:CreateTexture(nil, "OVERLAY")
    line:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
    line:SetHeight(8)
    line:SetPoint("TOPLEFT", 3, -24)
    line:SetPoint("TOPRIGHT", -3, -24)
    more = Text(win, "GameFontDisableSmall", true)
    queued = Text(win, "GameFontDisableSmall", true)
    win.split = Line(win, 0.35)
    win.fade = win:CreateAnimationGroup()
    local alpha = win.fade:CreateAnimation("Alpha")
    alpha:SetFromAlpha(0)
    alpha:SetToAlpha(1)
    alpha:SetDuration(0.2)
    win.thumb = win:CreateTexture(nil, "OVERLAY")
    win.thumb:SetWidth(2)
    win.thumb:SetColorTexture(ICON_COLOR.r, ICON_COLOR.g, ICON_COLOR.b, 0.8)
    win.thumb:Hide()
    win:SetScript("OnMouseWheel", function(_, delta)
        scroll = scroll - delta
        Refresh()
    end)
    win.out = win:CreateAnimationGroup()
    local out = win.out:CreateAnimation("Alpha")
    win.outAlpha = out
    out:SetFromAlpha(1)
    out:SetToAlpha(0)
    out:SetDuration(0.25)
    win.out:SetScript("OnFinished", function()
        win:Hide()
        for row in pairs(live) do
            if row.leaving then Release(row) end
        end
    end)

    ApplyScale()   -- (and the spot: ApplyPosition)
    LEM:AddFrame(holder, OnMoved, DEFAULTS, L["FlareUI Loot Rolls"])
    local selection = LEM.frameSelections and LEM.frameSelections[holder]
    if selection then
        selection:SetFrameStrata("HIGH")
        selection:SetFrameLevel(win:GetFrameLevel() + 20)
    end
    win.fader = CreateFrame("Frame", nil, win)
    win.fader:SetScript("OnUpdate", LR.FadeTick)
    LR.inCombat = InCombatLockdown()
    LR.UpdateFade(true)
    local Section, settings = ns.EditSections()
    Section("Frame", { ScaleSetting() })
    Section("Fading", LR.FadeSettings())
    LEM:AddFrameSettings(holder, settings)
    LEM:RegisterCallback("layout", function(layoutName) ApplyPosition(layoutName) end)
    LEM:RegisterCallback("enter", ShowSamples)
    -- out of Edit Mode: back to the header box on its saved spot
    LEM:RegisterCallback("exit", function() HideSamples(); ApplyPosition() end)

    local events = CreateFrame("Frame")
    for _, event in ipairs({ "START_LOOT_ROLL", "CONFIRM_LOOT_ROLL", "CANCEL_LOOT_ROLL", "CANCEL_ALL_LOOT_ROLLS", "PLAYER_ENTERING_WORLD",
            "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
        events:RegisterEvent(event)
    end
    for _, event in ipairs({ "LOOT_HISTORY_UPDATE_DROP", "LOOT_HISTORY_UPDATE_ENCOUNTER", "LOOT_HISTORY_CLEAR_HISTORY",
            "INPUT_DEVICE_INTERFACE_TRANSITION" }) do
        pcall(events.RegisterEvent, events, event)
    end
    events:SetScript("OnEvent", function(_, event, a, b)
        if event == "START_LOOT_ROLL" then
            StartRoll(a, b)
        elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
            LR.inCombat = event == "PLAYER_REGEN_DISABLED"
            LR.UpdateFade()
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
