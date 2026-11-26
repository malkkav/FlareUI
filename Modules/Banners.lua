local _, ns = ...
local L = ns.L

--------------------------------------------------
-- BANNERS (Banners page, off)
-- One line of big text at the top of the screen for the moments Blizzard announces in several places:
-- a new zone or subzone, a level, a quest taken, handed in or moved on, an achievement, a boss emote.
-- Each is a banner: a title in its kind's colour, a bronze line that grows from the middle, and a line
-- or two below. After Horizon Suite's Presence (MIT, LICENSES/HorizonSuite.txt): the way a banner plays, the
-- queue's rules and what silences Blizzard's own announcements follow it; the frame, its look and the
-- settings are FlareUI's.
-- This file is the frame, its animation and the queue; BannerSources.lua turns the game's events into
-- banners and puts away the Blizzard text each kind replaces. Placed in Edit Mode ("FlareUI Banners").
--------------------------------------------------
local B = {}
ns.Banners = B
ns.modules["Banners"] = B

local ipairs, pairs, type, tostring = ipairs, pairs, type, tostring
local math_max, math_min, math_floor = math.max, math.min, math.floor
local tremove = table.remove
local CreateFrame, GetTime = CreateFrame, GetTime
local LEM = LibStub("FlareEditMode")

--------------------------------------------------
-- 1. WHAT A BANNER IS
--------------------------------------------------
-- pri: a higher one cuts in on the banner showing; hold: seconds at full strength; option: its switch
-- in the settings; progress: a new one of the same title rewrites the banner showing
B.KINDS = {
    levelUp             = { pri = 4, size = "large",  hold = 5.0, option = "levelUp" },
    bossEmote           = { pri = 4, size = "large",  hold = 5.0, option = "bossEmote" },
    achievement         = { pri = 3, size = "large",  hold = 4.5, option = "achievement" },
    zone                = { pri = 2, size = "large",  hold = 4.0, option = "zone" },
    questComplete       = { pri = 2, size = "large",  hold = 4.0, option = "questComplete" },
    scenarioComplete    = { pri = 2, size = "large",  hold = 4.0, option = "scenario" },
    scenarioStart       = { pri = 2, size = "medium", hold = 3.5, option = "scenario" },
    rare                = { pri = 2, size = "medium", hold = 3.5, option = "rare" },
    questAccept         = { pri = 1, size = "medium", hold = 3.0, option = "questAccept" },
    subzone             = { pri = 1, size = "medium", hold = 3.0, option = "subzone" },
    scenarioProgress    = { pri = 1, size = "medium", hold = 2.5, option = "scenario", progress = true },
    questProgress       = { pri = 1, size = "small",  hold = 2.5, option = "questProgress", progress = true },
    achievementProgress = { pri = 1, size = "small",  hold = 2.5, option = "achievementProgress", progress = true },
}
-- the order the examples and /fui banner list them in
B.ORDER = { "zone", "subzone", "levelUp", "questAccept", "questProgress", "questComplete", "achievement",
    "achievementProgress", "bossEmote", "rare", "scenarioStart", "scenarioProgress", "scenarioComplete" }

B.COLORS = {
    text      = { 0.90, 0.90, 0.90 },
    gold      = { 1.00, 0.82, 0.20 },
    line      = { 0.80, 0.60, 0.34 },   -- FlareUI's bronze (#CC9957), as the XP bar's border
    dungeon   = { 0.64, 0.21, 0.93 },
    complete  = { 0.20, 1.00, 0.40 },
    bronze    = { 0.78, 0.48, 0.22 },
    boss      = { 1.00, 0.20, 0.20 },
    world     = { 0.78, 0.42, 0.95 },
    scenario  = { 0.38, 0.52, 0.88 },
    discovery = { 0.40, 1.00, 0.50 },
    friendly  = { 0.10, 1.00, 0.10 },
    hostile   = { 1.00, 0.10, 0.10 },
    contested = { 1.00, 0.70, 0.00 },
    sanctuary = { 0.41, 0.80, 0.94 },
}

local C = {
    WIDTH = 800, HEIGHT = 250,
    DEFAULTS = { point = "TOP", x = 0, y = -180 },
    TEXT_WIDTH = 780,
    LINE_Y = -65, LINE_WIDTH = 400, LINE_HEIGHT = 2, LINE_ALPHA = 0.9,
    TITLE_GAP = 8, SUB_GAP = 10, SUB_GAP_SMALL = 12, EXTRA_GAP = 5, ICON_GAP = 8, ICON = 24,
    SIZES = { large = { 48, 24 }, medium = { 36, 22 }, small = { 28, 20 } },
    EXTRA_SIZE = 16,
    -- the entrance: each piece takes ELEMENT of ENTER, starting at its share of it
    ENTER = 0.7, ELEMENT = 0.4, AT = { title = 0, line = 0.15, sub = 0.30, extra = 0.45 },
    TITLE_SLIDE = 20, SUB_SLIDE = 10, EXIT_TITLE = 15, EXIT_SUB = 10,
    REWRITE = 0.12,       -- a progress line fades out and back in
    QUEUE = 8,
}

local holder, driver
local queue = {}
B.queue = queue

local function GetDb()
    return ns.db and ns.db.profile and ns.db.profile.banners
end

-- (the game's check for a value Lua may read; not there outside the game)
local function Readable(value)
    return not canaccessvalue or canaccessvalue(value)
end
B.Readable = Readable

function B.Enabled(option)
    local db = GetDb()
    return db and db[option] and true or false
end

-- Don't Show In: the instance kinds picked in the settings
local SKIP = { party = "skipDungeon", raid = "skipRaid", arena = "skipArena", pvp = "skipBattleground" }
function B.Skipped()
    if not IsInInstance then return false end
    local inside, kind = IsInInstance()
    local option = inside and SKIP[kind]
    return option and B.Enabled(option) or false
end

local function Animated()
    local db = GetDb()
    if db and db.animate == false then return false end
    if C_CVar and C_CVar.GetCVarBool and C_CVar.GetCVarBool("reduceMotion") then return false end
    return true
end

local function Seconds(key, fallback)
    local db = GetDb()
    local value = db and tonumber(db[key])
    return value and value > 0 and value or fallback
end

--------------------------------------------------
-- 2. THE FRAME
-- Two layers, so a banner that cuts in comes up while the one before fades out under it.
--------------------------------------------------
local function ApplyFontTo(fontString, fontDb, size)
    local flags = fontDb and fontDb.flags or "OUTLINE"
    if flags == "NONE" then flags = "" end
    ns.SetFont(fontString, ns.GetFontPath(fontDb and fontDb.face or "__global"), size, flags)
    ns.ApplyShadow(fontString, fontDb)
end

local function Half(layer, side)
    local tex = layer:CreateTexture(nil, "ARTWORK")
    tex:SetTexture("Interface\\Buttons\\WHITE8x8")
    tex:SetHeight(C.LINE_HEIGHT)
    local c = B.COLORS.line
    -- solid at the middle, gone at its end
    if tex.SetGradient and CreateColor then
        local clear, solid = CreateColor(c[1], c[2], c[3], 0), CreateColor(c[1], c[2], c[3], 1)
        if side == "LEFT" then tex:SetGradient("HORIZONTAL", clear, solid) else tex:SetGradient("HORIZONTAL", solid, clear) end
    else
        tex:SetVertexColor(c[1], c[2], c[3])
    end
    tex:SetPoint(side == "LEFT" and "RIGHT" or "LEFT", layer, "TOP", 0, C.LINE_Y)
    return tex
end

local function NewLayer()
    local layer = CreateFrame("Frame", nil, holder)
    layer:SetAllPoints()
    layer:Hide()
    layer.left, layer.right = Half(layer, "LEFT"), Half(layer, "RIGHT")
    local gem = layer:CreateTexture(nil, "OVERLAY")
    gem:SetTexture("Interface\\Buttons\\WHITE8x8")
    gem:SetSize(6, 6)
    gem:SetPoint("CENTER", layer, "TOP", 0, C.LINE_Y)
    local c = B.COLORS.line
    gem:SetVertexColor(c[1], c[2], c[3])
    if gem.SetRotation then gem:SetRotation(math.pi / 4) end
    layer.gem = gem
    layer.title = layer:CreateFontString(nil, "OVERLAY")
    layer.title:SetJustifyH("CENTER")
    layer.title:SetWordWrap(false)
    layer.sub = layer:CreateFontString(nil, "OVERLAY")
    layer.sub:SetJustifyH("CENTER")
    layer.sub:SetWidth(C.TEXT_WIDTH)
    if layer.sub.SetMaxLines then layer.sub:SetMaxLines(2) end
    layer.extra = layer:CreateFontString(nil, "OVERLAY")
    layer.extra:SetJustifyH("CENTER")
    layer.extra:SetWidth(C.TEXT_WIDTH)
    layer.extra:SetPoint("TOP", layer.sub, "BOTTOM", 0, -C.EXTRA_GAP)
    layer.icon = layer:CreateTexture(nil, "OVERLAY")
    layer.icon:SetPoint("RIGHT", layer.title, "LEFT", -C.ICON_GAP, 0)
    return layer
end

local function SetColor(fontString, color, fallback)
    color = color or fallback
    fontString:SetTextColor(color[1], color[2], color[3])
end

-- A banner's texts, fonts and colours on a layer (nothing of the animation)
local function Fill(layer, item)
    local db = GetDb()
    local kind = B.KINDS[item.kind]
    local sizes = C.SIZES[kind.size]
    layer.small = kind.size == "small"
    ApplyFontTo(layer.title, db and db.titleFont, sizes[1])
    ApplyFontTo(layer.sub, db and db.textFont, sizes[2])
    ApplyFontTo(layer.extra, db and db.textFont, C.EXTRA_SIZE)

    local compact = kind.progress and db and db.compactProgress
    local hasTitle = item.title ~= nil and not compact
    layer.title:SetWidth(0)
    layer.title:SetText(hasTitle and item.title or "")
    layer.title:SetShown(hasTitle)
    -- a title wider than the frame is cut at its edge (a secret one can't be measured: held to the width)
    if hasTitle then
        if not Readable(item.title) then
            layer.title:SetWidth(C.TEXT_WIDTH)
        else
            local width = layer.title:GetStringWidth()
            if Readable(width) and width > C.TEXT_WIDTH then layer.title:SetWidth(C.TEXT_WIDTH) end
        end
    end
    SetColor(layer.title, item.color, B.COLORS.text)

    layer.sub:SetText(item.subtitle ~= nil and item.subtitle or "")
    layer.sub:SetShown(item.subtitle ~= nil)
    SetColor(layer.sub, item.subColor, B.COLORS.text)

    layer.extra:SetText(item.extra ~= nil and item.extra or "")
    layer.extra:SetShown(item.extra ~= nil)
    SetColor(layer.extra, B.COLORS.discovery)

    local icon = hasTitle and db and db.icons and item.icon or nil
    if icon then
        local size = math_floor(C.ICON * (kind.size == "large" and 1.5 or 1) + 0.5)
        layer.icon:SetSize(size, size)
        layer.icon:SetTexture(icon)
        if item.iconCoords then layer.icon:SetTexCoord(unpack(item.iconCoords)) else layer.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
    end
    layer.icon:SetShown(icon ~= nil)
end

-- Where everything stands at a strength of 0..1 each: the title above the line, the rest below
local function Place(layer, title, line, sub, extra, titleShift, subShift)
    layer.title:ClearAllPoints()
    layer.title:SetPoint("BOTTOM", layer, "TOP", 0, C.LINE_Y + C.TITLE_GAP + titleShift)
    layer.title:SetAlpha(title)
    layer.icon:SetAlpha(title)
    local half = C.LINE_WIDTH / 2 * line
    layer.left:SetWidth(math_max(0.01, half))
    layer.right:SetWidth(math_max(0.01, half))
    layer.left:SetAlpha(C.LINE_ALPHA * line)
    layer.right:SetAlpha(C.LINE_ALPHA * line)
    layer.gem:SetAlpha(line)
    layer.sub:ClearAllPoints()
    layer.sub:SetPoint("TOP", layer, "TOP", 0, C.LINE_Y - (layer.small and C.SUB_GAP_SMALL or C.SUB_GAP) - subShift)
    layer.sub:SetAlpha(sub * (layer.subFade or 1))
    layer.extra:SetAlpha(extra)
end

local function EaseOut(p)
    p = math_max(0, math_min(1, p))
    return 1 - (1 - p) * (1 - p)
end

--------------------------------------------------
-- 3. THE ANIMATION
-- One banner plays at a time, as in Horizon Suite's Presence (MIT, LICENSES/HorizonSuite.txt: the
-- flow below follows its PresenceCore): one clock and one phase for the whole frame, so nothing can
-- be left on screen by a layer the clock forgot.
--   entrance  : the banner comes in
--   crossfade : it comes in over the one it cut in on, which fades out on the other layer
--   hold      : it stands for its kind's time
--   exit      : it leaves; then the next one waiting plays
-- B:Advance runs the clock every frame while a banner is up (and in the tests).
--------------------------------------------------
local anim = { phase = "idle", elapsed = 0, hold = 0, enter = 0, exit = 0 }
local cur, old            -- the layer playing, and the one fading out under it
local rewrite             -- a progress line changing: { phase, elapsed, text }

local function ResetLayer(layer)
    if not layer then return end
    layer.item, layer.subFade, layer.hasExtra = nil, nil, nil
    layer:SetAlpha(1)
    layer:Hide()
end

local function Idle()
    anim.phase, anim.elapsed = "idle", 0
    rewrite = nil
    B.active = nil
    ResetLayer(cur)
    ResetLayer(old)
    if driver then driver:Hide() end
end

-- The banner in place, whole (the entrance's last frame, and a banner with no animation)
local function Settle()
    Place(cur, 1, 1, 1, cur.hasExtra and 1 or 0, 0, 0)
end

local function UpdateEntrance()
    local k = anim.enter / C.ENTER
    local function At(key) return EaseOut((anim.elapsed - C.AT[key] * k) / (C.ELEMENT * k)) end
    local title, sub = At("title"), At("sub")
    Place(cur, title, At("line"), sub, cur.hasExtra and At("extra") or 0, (1 - title) * C.TITLE_SLIDE, (1 - sub) * C.SUB_SLIDE)
end

local function UpdateExit()
    local p = anim.exit > 0 and math_min(1, anim.elapsed / anim.exit) or 1
    local left = 1 - p
    Place(cur, left, left, left, cur.hasExtra and left or 0, p * C.EXIT_TITLE, p * C.EXIT_SUB)
end

-- a progress line: out, the new text, back in
local function UpdateRewrite(dt)
    rewrite.elapsed = rewrite.elapsed + dt
    if rewrite.phase == "out" then
        cur.subFade = math_max(0, 1 - rewrite.elapsed / C.REWRITE)
        if rewrite.elapsed >= C.REWRITE then
            cur.sub:SetText(rewrite.text)
            cur.sub:Show()
            rewrite.phase, rewrite.elapsed = "in", 0
        end
    else
        cur.subFade = math_min(1, rewrite.elapsed / C.REWRITE)
        if rewrite.elapsed >= C.REWRITE then
            cur.subFade = nil
            rewrite = nil
        end
    end
    if anim.phase == "hold" then Settle() end
end

local Play

-- the banner is done: the frame is cleared, and the most pressing one waiting (the oldest of those) is next
local function Complete()
    Idle()
    if #queue == 0 then return end
    local best = 1
    for i = 2, #queue do
        if queue[i].pri > queue[best].pri then best = i end
    end
    Play(tremove(queue, best))
end

function B:Advance(dt)
    if anim.phase == "idle" or anim.phase == "pinned" then return end
    anim.elapsed = anim.elapsed + dt
    if rewrite then UpdateRewrite(dt) end

    if anim.phase == "entrance" or anim.phase == "crossfade" then
        if anim.phase == "crossfade" and old then
            old:SetAlpha(anim.enter > 0 and math_max(0, 1 - anim.elapsed / anim.enter) or 0)
        end
        if anim.elapsed >= anim.enter then
            Settle()
            ResetLayer(old)
            anim.phase, anim.elapsed = "hold", 0
        else
            UpdateEntrance()
        end
    elseif anim.phase == "hold" then
        if anim.elapsed >= anim.hold then
            anim.phase, anim.elapsed = "exit", 0
            if anim.exit <= 0 then return Complete() end
        end
    elseif anim.phase == "exit" then
        if anim.elapsed >= anim.exit then return Complete() end
        UpdateExit()
    end
end

-- item on the frame, from its first frame. crossfade: over the banner showing, which fades out
-- under it. pinned: standing still until cleared (Edit Mode).
Play = function(item, crossfade, pinned)
    local kind = B.KINDS[item.kind]
    if crossfade then
        cur, old = old, cur        -- the banner showing goes on fading on its own layer
    else
        ResetLayer(old)
    end
    ResetLayer(cur)
    rewrite = nil
    cur.item = item
    Fill(cur, item)
    cur.hasExtra = item.extra ~= nil
    local animated = Animated() and not pinned
    anim.enter = animated and Seconds("enterTime", C.ENTER) or 0
    anim.exit = animated and Seconds("exitTime", 0.8) or 0
    anim.hold = kind.hold * Seconds("hold", 1)
    anim.elapsed = 0
    B.active = item
    cur:Show()
    if pinned then
        anim.phase = "pinned"
        Settle()
        return
    end
    if anim.enter > 0 then
        anim.phase = crossfade and "crossfade" or "entrance"
        Place(cur, 0, 0, 0, 0, C.TITLE_SLIDE, C.SUB_SLIDE)
    else
        anim.phase = "hold"
        ResetLayer(old)
        Settle()
    end
    if driver then driver:Show() end
end

function B.Phase() return anim.phase end

--------------------------------------------------
-- 4. THE QUEUE
-- Presence's rules (its QueueOrPlay):
--   * a progress banner of the kind showing rewrites its line and takes its time again
--   * a more pressing banner cuts in with a crossfade
--   * anything else waits, up to eight; one with the title and kind showing is dropped, and a
--     progress banner takes the place of the last one of its kind waiting
--------------------------------------------------
-- item: { kind, title, subtitle, extra, icon, iconCoords, color, subColor, force, questID }
-- Returns what became of it: "shown", "queued", "updated" or "dropped".
function B:Push(item)
    local kind = item and B.KINDS[item.kind]
    if not (kind and holder) then return "dropped" end
    if B.editing then return "dropped" end
    if not item.force and (not B.Enabled(kind.option) or B.Skipped()) then return "dropped" end
    item.pri = kind.pri

    local active = B.active
    if not active then
        Play(item)
        return "shown"
    end
    if kind.progress and active.kind == item.kind and (anim.phase == "entrance" or anim.phase == "hold") then
        -- (a secret line can't be compared: it is taken as new)
        local same = Readable(item.subtitle) and Readable(active.subtitle) and item.subtitle == active.subtitle
        if not same then
            active.subtitle = item.subtitle
            local text = item.subtitle ~= nil and item.subtitle or ""
            if anim.enter > 0 then
                if rewrite then rewrite.text = text else rewrite = { phase = "out", elapsed = 0, text = text } end
            else
                cur.sub:SetText(text)
                cur.sub:Show()
            end
            if anim.phase == "hold" then anim.elapsed = 0 end
        end
        return "updated"
    end
    if item.pri > active.pri then
        Play(item, true)
        return "shown"
    end
    if #queue >= C.QUEUE then return "dropped" end
    if active.kind == item.kind and Readable(item.title) and Readable(active.title) and active.title == item.title then
        return "dropped"
    end
    if kind.progress then
        for i = #queue, 1, -1 do
            if queue[i].kind == item.kind then
                queue[i] = item
                return "updated"
            end
        end
    end
    queue[#queue + 1] = item
    return "queued"
end

-- The zone or subzone banner showing stops at once, and the ones waiting are dropped: the next zone
-- banner is about where you are now (Presence's CancelZoneAnim)
function B:CancelZone()
    local active = B.active
    if active and (active.kind == "zone" or active.kind == "subzone") and anim.phase ~= "pinned" then Idle() end
    for i = #queue, 1, -1 do
        if queue[i].kind == "zone" or queue[i].kind == "subzone" then tremove(queue, i) end
    end
end

-- A quest handed in or dropped: its progress banners waiting are stale
function B:PurgeQuest(questID)
    if not questID then return end
    for i = #queue, 1, -1 do
        if queue[i].kind == "questProgress" and queue[i].questID == questID then tremove(queue, i) end
    end
end

-- "Discovered" (BannerSources.lua reads it off the error text): a third line under the banner playing,
-- while it is still coming in or standing. Returns true when it was put there.
function B:Extra(text)
    if not (B.active and cur and (anim.phase == "entrance" or anim.phase == "hold" or anim.phase == "crossfade")) then return false end
    if not B.Enabled("discovery") then return false end
    B.active.extra = text
    cur.extra:SetText(text)
    cur.extra:Show()
    cur.hasExtra = true
    if anim.phase == "hold" then cur.extra:SetAlpha(1) end
    return true
end

-- Everything off the screen at once (Edit Mode, an example)
function B:Clear()
    for i = #queue, 1, -1 do queue[i] = nil end
    Idle()
end

--------------------------------------------------
-- 5. EXAMPLES
-- The settings' Show Example button, /fui banner <kind> and the banner standing in Edit Mode.
--------------------------------------------------
local QUEST_ICON = { accept = "Interface\\GossipFrame\\AvailableQuestIcon", done = "Interface\\GossipFrame\\ActiveQuestIcon" }
B.QUEST_ICON = QUEST_ICON

local function SampleItem(kind)
    local zone = GetRealZoneText and GetRealZoneText() or ""
    if zone == "" then zone = L["Elwynn Forest"] end
    local sub = GetSubZoneText and GetSubZoneText() or ""
    if sub == "" then sub = L["Goldshire"] end
    local col = B.COLORS
    local quest, boss = L["A Threat Within"], L["Edwin VanCleef"]
    local samples = {
        zone = { title = zone, subtitle = sub, subColor = col.gold, extra = L["Discovered: %s"]:format(sub) },
        subzone = { title = sub, subtitle = zone, subColor = col.gold },
        levelUp = { title = L["Level Up"], subtitle = L["You have reached level %d"]:format((UnitLevel and UnitLevel("player") or 1)), color = col.complete },
        questAccept = { title = L["Quest Accepted"], subtitle = quest, icon = QUEST_ICON.accept },
        questProgress = { title = quest, subtitle = L["Kobold Vermin slain: %d/%d"]:format(4, 10) },
        questComplete = { title = L["Quest Complete"], subtitle = quest, color = col.complete, icon = QUEST_ICON.done },
        achievement = { title = L["Achievement Earned"], subtitle = L["Level 10"], color = col.bronze, icon = "Interface\\Icons\\Achievement_Level_10" },
        achievementProgress = { title = L["Explore Elwynn Forest"], subtitle = L["Areas discovered: %d/%d"]:format(3, 9) },
        bossEmote = { title = boss, subtitle = L["%s calls for help!"]:format(boss), color = col.boss },
        rare = { title = L["Rare Defeated"], subtitle = L["Mother Fang"], color = col.gold },
        scenarioStart = { title = L["A Sample Scenario"], subtitle = L["Stage %d of %d"]:format(1, 3), color = col.scenario },
        scenarioProgress = { title = L["A Sample Scenario"], subtitle = L["Enemies defeated: %d/%d"]:format(2, 8), color = col.scenario },
        scenarioComplete = { title = L["Scenario Complete"], subtitle = L["A Sample Scenario"], color = col.complete },
    }
    local item = samples[kind]
    if item then item.kind, item.force = kind, true end
    return item
end

function B:Sample(kind)
    local item = SampleItem(kind)
    if not item then return false end
    B:Clear()
    Play(item)
    return true
end

-- Show Example: each press shows the next kind
local sampleIndex = 0
function B:SampleNext()
    sampleIndex = sampleIndex % #B.ORDER + 1
    return B:Sample(B.ORDER[sampleIndex])
end

-- /fui banner <kind>: an example of one kind; alone, the kinds it knows
function B:Command(text)
    if not holder then
        print("|cffb39ddbFlareUI|r: " .. L["Banners are off. Turn them on in the settings, then reload."])
        return
    end
    text = (text or ""):lower():gsub("%s+", "")
    for _, kind in ipairs(B.ORDER) do
        if kind:lower() == text then return B:Sample(kind) end
    end
    print("|cffb39ddbFlareUI|r: /fui banner " .. table.concat(B.ORDER, " | "))
end

--------------------------------------------------
-- 6. SETUP
--------------------------------------------------
local function GetLayoutStore(layoutName)
    local db = GetDb()
    if not db then return nil end
    layoutName = layoutName or LEM:GetActiveLayoutName() or "Modern"
    db.layouts = db.layouts or {}
    return ns.LayoutHome(db.layouts, layoutName)
end

local function ApplyPosition(layoutName)
    local store = GetLayoutStore(layoutName)
    local pos = (store and store.point) and store or C.DEFAULTS
    holder:ClearAllPoints()
    holder:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
end

local function OnMoved(_, layoutName, point, x, y)
    local store = GetLayoutStore(layoutName)
    if not store then return end
    store.point, store.x, store.y = point, math_floor(x + 0.5), math_floor(y + 0.5)
end

local function ApplyScale()
    local db = GetDb()
    holder:SetScale(db and tonumber(db.scale) or 1)
end

-- Fonts changed: the banner showing takes them at once
function B:ApplyFont()
    if not holder then return end
    if cur and cur.item then Fill(cur, cur.item) end
end

-- An option changed: Blizzard's own text comes back for the kinds switched off
function B:Refresh()
    if not holder then return end
    ApplyScale()
    if ns.BannerSources then ns.BannerSources:Refresh() end
end

function B:ShouldLoad()
    local db = GetDb()
    return db and db.enabled or false
end

function B:Init()
    if holder then return end
    holder = CreateFrame("Frame", "FlareUI_Banners", UIParent)
    holder:SetSize(C.WIDTH, C.HEIGHT)
    holder:SetFrameStrata("HIGH")
    holder:SetClampedToScreen(true)
    holder:EnableMouse(false)
    ApplyPosition()
    ApplyScale()
    cur, old = NewLayer(), NewLayer()
    driver = CreateFrame("Frame", nil, holder)
    driver:Hide()
    driver:SetScript("OnUpdate", function(_, elapsed) B:Advance(elapsed) end)

    LEM:AddFrame(holder, OnMoved, C.DEFAULTS, L["FlareUI Banners"])
    LEM:AddFrameSettings(holder, ns.EditSection("Frame", {
        { name = L["Scale"], kind = LEM.SettingType.Slider, default = 100, minValue = 50, maxValue = 200, valueStep = 5,
          get = function() local db = GetDb(); return math_floor((db and tonumber(db.scale) or 1) * 100 + 0.5) end,
          set = function(_, value)
              local db = GetDb()
              if not db then return end
              db.scale = value ~= 100 and value / 100 or nil
              ApplyScale()
          end },
    }))
    LEM:RegisterCallback("layout", function(layoutName) ApplyPosition(layoutName) end)
    -- Edit Mode: a banner stands there to be placed, and none comes while it does
    LEM:RegisterCallback("enter", function()
        B:Clear()
        Play(SampleItem("zone"), false, true)
        B.editing = true
    end)
    LEM:RegisterCallback("exit", function()
        B.editing = nil
        B:Clear()
        ApplyPosition()
    end)

    if ns.BannerSources then ns.BannerSources:Start() end
end
