local _, ns = ...
local L = ns.L

--------------------------------------------------
-- CONTROLLER NAVIGATION OF THE QUEST TRACKER
-- In the Gamepad UI, LB + RB and D-pad Up gives the pad to Blizzard's quest tracker. With FlareUI's
-- tracker on, Blizzard's is still "shown", shrunk to nothing (ObjectiveTracker.lua section 11): the D-pad
-- and the face buttons were caught on a window nobody sees until B. Here that press gives the pad
-- to FlareUI's tracker. With no tracker on screen it opens the quest log, through the game's own button.
--   D-pad  moves (held: repeats)   B  gives the pad back
--   A      focuses a quest, folds a zone, presses a button, uses a quest item
--   X      opens the quest on the map   Y  the quest's options (FlareUI's own small list)
-- As Blizzard's tracker has it. In a fight only the quest items: what else it does is blocked there.
--
-- How it works, with nothing of Blizzard's hooked, replaced or called (as PadGroupTargeting.lua):
-- * The watcher is a protected child of Blizzard's Shortcuts bar, which is shown exactly while LB + RB are
--   held. Its _onshow binds D-pad Up, its _onhide clears it.
-- * The nav button holds the bindings while the tracker has the pad: set and cleared by its secure
--   snippet, so B works in a fight. Never a listener frame: one that passes a press on breaks the
--   controller until a /reload, and one that doesn't keeps A from reaching a secure button.
-- * A and X are secure buttons. Focusing, the map, the details and a recipe go through Blizzard's own
--   buttons in its parked tracker (or its quest log button), aimed as the press comes, out of a fight.
--   They act on the release, so no half of a press reaches the window they open.
-- Off outside the Gamepad UI, with Blizzard's tracker in Gamepad mode (Force Blizzard Tracker), and while
-- another controller addon is loaded.
--------------------------------------------------
ns.PadTracker = ns.PadTracker or {}
local PT = ns.PadTracker

PT.BUTTON = "FlareUIPadTracker"           -- opens the quest log
PT.NAV = "FlareUIPadTrackerNav"           -- holds the bindings while the tracker has the pad
PT.A, PT.X = "FlareUIPadTrackerA", "FlareUIPadTrackerX"
PT.ACTION = "GAMEPADACTIONBUTTON2"        -- the D-pad's Up on every Gamepad action bar
PT.FALLBACK = "PADDUP"
PT.KEY = {
    A = GAMEPAD_FACE_BOTTOM or "PAD1", B = GAMEPAD_FACE_RIGHT or "PAD2",
    X = GAMEPAD_FACE_LEFT or "PAD3", Y = GAMEPAD_FACE_TOP or "PAD4",
}
PT.REPEAT_DELAY, PT.REPEAT_RATE = 0.35, 0.1
PT.REVEAL = 6                             -- kept between a quest and the list's edge
PT.GOLD = { 1, 0.82, 0 }
PT.LABEL = {
    focus = _G.CONTEXT_ACTION_LABEL_FOCUS or L["Focus"],
    map = _G.OBJECTIVES_SHOW_QUEST_MAP or _G.CONTEXT_ACTION_LABEL_DETAILS or L["Select"],
    options = _G.CONTEXT_ACTION_LABEL_OPTIONS or L["Options"],
    select = _G.ACTION_LABEL_SELECT or L["Select"],
    use = _G.USE or L["Select"],
    back = _G.BACK or L["Back"],
}

--------------------------------------------------
-- 1. SECURE SNIPPETS (restricted Lua: the word for a Lua closure may not appear anywhere in them)
--------------------------------------------------
-- self is the watcher: LB + RB went down. D-pad Up goes to the tracker, or to the quest log with no
-- tracker on screen (in a fight: with no quest item on screen)
PT.SHOW_SNIPPET = [[
    if self:GetAttribute("flare-on") ~= true then return end
    local target, click = "]] .. PT.BUTTON .. [[", "LeftButton"
    if self:GetAttribute("flare-nav") == true then
        local ok = not PlayerInCombat()
        if not ok then
            for i = 1, self:GetAttribute("flare-items") or 0 do
                local f = self:GetFrameRef("i" .. i)
                if f and f:IsVisible() then ok = true break end
            end
        end
        if ok then target, click = "]] .. PT.NAV .. [[", "Open" end
    end
    for k = 1, 2 do
        local key = self:GetAttribute("flare-key" .. k)
        if key then self:SetBindingClick(true, key, target, click) end
    end
    self:CallMethod("FlareBound", true)
]]
PT.HIDE_SNIPPET = [[
    self:ClearBindings()
    self:CallMethod("FlareBound", false)
]]

-- self is the nav button, control the watcher, button what was pressed. flare-open: "list" (out of a
-- fight, the rows are plain Lua's), "items" (in one, the quest items are walked here) or nil.
PT.NAV_SNIPPET = [[
    local open = self:GetAttribute("flare-open")
    if button == "Close" or (button == "Open" and open) then
        -- B on its release, so the rest of the press isn't the game's; with the list's options open, it
        -- closes those
        if (button == "Close") == (down and true or false) then return false end
        if button == "Close" and self:GetAttribute("flare-menu") then
            control:CallMethod("FlareMenuBack")
            return false
        end
        self:SetAttribute("flare-open", nil)
        self:ClearBindings()
        control:CallMethod("FlareClosed")
        return false
    end
    local pick
    local n = control:GetAttribute("flare-items") or 0
    if button == "Open" then
        if not down then return false end
        open = PlayerInCombat() and "items" or "list"
        if open == "items" then
            for i = 1, n do
                local f = control:GetFrameRef("i" .. i)
                if f and f:IsVisible() then pick = i break end
            end
            if not pick then return false end
        end
        self:SetAttribute("flare-open", open)
        self:SetBindingClick(true, "PADDUP", "]] .. PT.NAV .. [[", "Up")
        self:SetBindingClick(true, "PADDDOWN", "]] .. PT.NAV .. [[", "Down")
        self:SetBindingClick(true, "PADDLEFT", "]] .. PT.NAV .. [[", "Left")
        self:SetBindingClick(true, "PADDRIGHT", "]] .. PT.NAV .. [[", "Right")
        self:SetBindingClick(true, "]] .. PT.KEY.B .. [[", "]] .. PT.NAV .. [[", "Close")
        self:SetBindingClick(true, "]] .. PT.KEY.A .. [[", "]] .. PT.A .. [[", "LeftButton")
        if open == "list" then
            self:SetBindingClick(true, "]] .. PT.KEY.X .. [[", "]] .. PT.X .. [[", "LeftButton")
            self:SetBindingClick(true, "]] .. PT.KEY.Y .. [[", "]] .. PT.NAV .. [[", "Menu")
            control:CallMethod("FlareOpen")
            return false
        end
    elseif open == "list" then
        if button == "Menu" then
            if down then control:CallMethod("FlareMenu") end
        else
            control:CallMethod("FlareMove", button, down and true or false)
        end
        return false
    elseif open == "items" and down then
        local at = self:GetAttribute("flare-sel") or 1
        local step = (button == "Up" or button == "Left") and -1 or 1
        local i = at + step
        while i >= 1 and i <= n do
            local f = control:GetFrameRef("i" .. i)
            if f and f:IsVisible() then pick = i break end
            i = i + step
        end
    end
    if pick then
        local a = control:GetFrameRef("a")
        a:SetAttribute("type", "item")
        a:SetAttribute("item", control:GetFrameRef("i" .. pick):GetAttribute("item"))
        self:SetAttribute("flare-sel", pick)
        control:CallMethod("FlareMark", pick)
    end
    return false
]]

--------------------------------------------------
-- 2. ROWS: what the pad can stand on, from the tracker as it is drawn. A row is a list of cells, left to
-- right; each has a key that finds it again after a redraw.
--------------------------------------------------
PT.rows = {}
PT.HEADER_BUTTONS = { "zone", "sort", "autoAccept", "autoTurnIn", "minimize" }

local function ByLeft(a, b) return (a.frame:GetLeft() or 0) < (b.frame:GetLeft() or 0) end

-- the quest item button beside a title, if one is shown
function PT.ItemOf(line, itemButtons)
    if not line.logIndex then return end
    for _, b in ipairs(itemButtons) do
        if b:IsShown() and b.logIndex == line.logIndex then return b end
    end
end

function PT.BuildRows()
    local rows = PT.rows
    wipe(rows)
    local pad = ns.ObjectiveTracker and ns.ObjectiveTracker.Pad
    local p = pad and pad.Parts()
    if not (p and p.holder) then return rows end
    if p.miniButton and p.miniButton:IsShown() then
        rows[1] = { { kind = "button", key = "mini", frame = p.miniButton } }
        return rows
    end
    if not p.holder:IsShown() then return rows end
    local head = {}
    for _, name in ipairs(PT.HEADER_BUTTONS) do
        local b = p.header[name]
        if b and b:IsVisible() then head[#head + 1] = { kind = "button", key = "head:" .. name, frame = b } end
    end
    if #head > 0 then
        table.sort(head, ByLeft)
        rows[1] = head
    end
    if not p.scroll:IsShown() then return rows end
    for _, line in ipairs(p.lines) do
        if line:IsShown() and not line.leaving then
            local cells
            if line.zone then
                cells = { { kind = "zone", key = "zone:" .. line.zone, frame = line } }
            elseif line.kind == "title" and line.popupQuestID then
                cells = { { kind = "popup", key = "popup:" .. line.popupQuestID, frame = line } }
            elseif line.kind == "title" and line.recipeID then
                cells = { { kind = "recipe", key = "recipe:" .. line.recipeID, frame = line } }
            elseif line.kind == "title" and line.questID then
                cells = { { kind = "quest", key = "quest:" .. line.questID, frame = line, questID = line.questID } }
                local voice = line.playButton
                if voice and voice:IsShown() then
                    cells[2] = { kind = "voice", key = "voice:" .. line.questID, frame = voice, line = line }
                end
                local item = PT.ItemOf(line, p.itemButtons)
                if item then cells[#cells + 1] = { kind = "item", key = "item:" .. line.questID, frame = item, line = line } end
                table.sort(cells, ByLeft)
            end
            if cells then rows[#rows + 1] = cells end
        end
    end
    return rows
end

-- the cell a vertical move lands on: the same kind, else the row's own line
local function Landing(row, kind)
    local main
    for i, cell in ipairs(row) do
        if cell.kind == kind then return i end
        if cell.kind ~= "voice" and cell.kind ~= "item" and not main then main = i end
    end
    return main or 1
end

function PT.Cell()
    local row = PT.rows[PT.rowAt or 0]
    return row and row[PT.cellAt or 0]
end

function PT.Find(key)
    for r, row in ipairs(PT.rows) do
        for c, cell in ipairs(row) do
            if cell.key == key then return r, c end
        end
    end
end

--------------------------------------------------
-- 3. WHAT IS SHOWN: the gold frame, the buttons' legend, the options list
--------------------------------------------------
function PT.CreateLook()
    if PT.mark then return end
    local mark = CreateFrame("Frame", nil, UIParent)
    mark:SetFrameStrata("HIGH")
    mark:EnableMouse(false)
    for i, points in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local edge = mark:CreateTexture(nil, "OVERLAY")
        edge:SetColorTexture(PT.GOLD[1], PT.GOLD[2], PT.GOLD[3], 1)
        edge:SetPoint(points[1])
        edge:SetPoint(points[2])
        if i <= 2 then edge:SetHeight(2) else edge:SetWidth(2) end
    end
    mark:Hide()
    PT.mark = mark

    local hints = CreateFrame("Frame", nil, UIParent)
    hints:SetFrameStrata("HIGH")
    hints:SetClampedToScreen(true)
    hints:EnableMouse(false)
    hints.bg = hints:CreateTexture(nil, "BACKGROUND")
    hints.bg:SetAllPoints()
    hints.bg:SetColorTexture(0, 0, 0, 0.75)
    hints.text = hints:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hints.text:SetPoint("CENTER")
    hints:Hide()
    PT.hints = hints

    local menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    menu:SetFrameStrata("DIALOG")
    menu:SetClampedToScreen(true)
    menu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    menu:SetBackdropColor(0.06, 0.05, 0.04, 0.95)
    local c = ns.BORDER_COLOR
    if c then menu:SetBackdropBorderColor(c.r, c.g, c.b, c.a or 1) end
    menu.lines = {}
    menu.band = menu:CreateTexture(nil, "ARTWORK")
    menu.band:SetColorTexture(PT.GOLD[1], PT.GOLD[2], PT.GOLD[3], 0.25)
    menu:Hide()
    PT.menu = menu

    -- a held direction
    local ticker = CreateFrame("Frame")
    ticker:Hide()
    ticker:SetScript("OnUpdate", function(_, dt) PT.Repeat(dt) end)
    PT.ticker = ticker
end

function PT.PlaceMark(frame, pad)
    local mark = PT.mark
    if not mark then return end
    if not (frame and frame:IsVisible()) then mark:Hide() return end
    mark:ClearAllPoints()
    mark:SetPoint("TOPLEFT", frame, "TOPLEFT", -pad, pad)
    mark:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", pad, -pad)
    mark:Show()
end

function PT.ShowHints(parts)
    local hints = PT.hints
    local pad = ns.ObjectiveTracker.Pad
    local holder = pad.Parts().holder
    local text = {}
    for i, part in ipairs(parts) do text[i] = ns.KeyText(PT.KEY[part[1]]) .. " " .. part[2] end
    hints.text:SetText(table.concat(text, "     "))
    hints:SetSize(hints.text:GetStringWidth() + 16, 20)
    hints:ClearAllPoints()
    -- under the tracker; over it when that is off the screen
    if (holder:GetBottom() or 0) > 30 then
        hints:SetPoint("TOP", holder, "BOTTOM", 0, -4)
    else
        hints:SetPoint("BOTTOM", holder, "TOP", 0, 4)
    end
    hints:Show()
end

function PT.UpdateHints()
    local cell = PT.Cell()
    local label = PT.LABEL
    local parts = {}
    if PT.entries then
        parts[1] = { "A", label.select }
    elseif cell then
        if cell.kind == "quest" then
            parts[1], parts[2], parts[3] = { "A", label.focus }, { "X", label.map }, { "Y", label.options }
        elseif cell.kind == "recipe" then
            if PT.RecipeHeader(cell.frame.recipeID) then parts[1] = { "A", label.select } end
            parts[#parts + 1] = { "Y", label.options }
        elseif cell.kind == "item" then
            parts[1] = { "A", label.use }
        else
            parts[1] = { "A", label.select }
        end
    end
    parts[#parts + 1] = { "B", label.back }
    PT.ShowHints(parts)
end

-- the quest's lines stay in view (its title, when it is longer than the list)
function PT.Reveal(cell)
    local line = cell.line or cell.frame
    local p = ns.ObjectiveTracker.Pad.Parts()
    local scroll, content = p.scroll, p.content
    if line:GetParent() ~= content then return end
    local group = line.group and p.state.groups and p.state.groups[line.group]
    local top0, top, bottom = content:GetTop(), line:GetTop(), (group and group.last or line):GetBottom()
    if not (top0 and top and bottom) then return end
    local view, now = scroll:GetHeight(), scroll:GetVerticalScroll()
    local from, to = top0 - top - PT.REVEAL, top0 - bottom + PT.REVEAL
    local want = now
    if to > now + view then want = to - view end
    if from < want then want = from end
    local max = math.max(0, content:GetHeight() - view)
    want = math.min(max, math.max(0, want))
    if math.abs(want - now) > 0.5 then scroll:SetVerticalScroll(want) end
end

local function Leave(frame)
    local onLeave = frame and frame:GetScript("OnLeave")
    if onLeave then onLeave(frame) end
end

function PT.Select(r, c, quiet)
    local old = PT.Cell()
    PT.rowAt, PT.cellAt = r, c
    local cell = PT.Cell()
    PT.key = cell and cell.key
    local OT = ns.ObjectiveTracker
    if not cell then PT.PlaceMark(nil) return end
    if old and old.frame ~= cell.frame and (old.kind == "button" or old.kind == "voice" or old.kind == "item") then Leave(old.frame) end
    if not quiet then
        PT.busy = true
        PT.Reveal(cell)
        PT.busy = nil
        -- (the item buttons follow the list)
        PT.BuildRows()
        local r2, c2 = PT.Find(cell.key)
        if r2 then
            PT.rowAt, PT.cellAt = r2, c2
            cell = PT.Cell()
        end
        if cell.kind == "button" or cell.kind == "item" then
            local onEnter = cell.frame:GetScript("OnEnter")
            if onEnter then onEnter(cell.frame) end
        elseif cell.kind == "quest" then
            OT.Pad.Tooltip(cell.frame)
        else
            GameTooltip:Hide()
        end
    end
    OT:HighlightGroup((cell.line or cell.frame).group)
    PT.PlaceMark(cell.frame, (cell.kind == "item" or cell.kind == "button") and 2 or 3)
    PT.UpdateHints()
end

-- after a redraw: the same thing if it is still there, else the row that took its place
function PT.Refresh()
    if PT.open ~= "list" or PT.busy then return end
    if #PT.BuildRows() == 0 then PT.Close() return end
    local r, c = PT.Find(PT.key)
    if r then
        PT.Select(r, c, true)
    else
        PT.CloseMenu()
        r = math.min(PT.rowAt or 1, #PT.rows)
        PT.Select(r, Landing(PT.rows[r]), false)
    end
end

--------------------------------------------------
-- 4. MOVING
--------------------------------------------------
-- answers whether it moved
function PT.Move(dir)
    if PT.entries then
        local at = (PT.entryAt or 1) + ((dir == "Up" and -1) or (dir == "Down" and 1) or 0)
        if at == PT.entryAt or not PT.entries[at] then return false end
        PT.entryAt = at
        PT.DrawMenu()
        return true
    end
    local row = PT.rows[PT.rowAt or 0]
    if not row then return false end
    if dir == "Left" or dir == "Right" then
        local c = PT.cellAt + (dir == "Left" and -1 or 1)
        if not row[c] then return false end
        PT.Select(PT.rowAt, c)
        return true
    end
    local r = PT.rowAt + (dir == "Up" and -1 or 1)
    if not PT.rows[r] then return false end
    PT.Select(r, Landing(PT.rows[r], PT.Cell() and PT.Cell().kind))
    return true
end

function PT.OnMove(dir, down)
    if PT.open ~= "list" then return end
    if not down then PT.ticker:Hide() return end
    PT.held, PT.wait = dir, PT.REPEAT_DELAY
    PT.ticker:SetShown(PT.Move(dir))
end

-- (it stops at the end of the list, so a release the game kept can't leave it running)
function PT.Repeat(dt)
    PT.wait = PT.wait - dt
    if PT.wait > 0 then return end
    PT.wait = PT.REPEAT_RATE
    if PT.open ~= "list" or not PT.Move(PT.held) then PT.ticker:Hide() end
end

--------------------------------------------------
-- 5. THE BUTTONS
--------------------------------------------------
-- A recipe's header in Blizzard's parked tracker (its code opens the professions window)
function PT.RecipeHeader(recipeID)
    local module = _G.ProfessionsRecipeTracker
    if not (recipeID and module and module.GetExistingBlock) then return end
    local ok, block = pcall(module.GetExistingBlock, module, recipeID)
    local button = ok and block and block.HeaderButton
    if button and not button:IsForbidden() then return button end
end

local function AimAt(button, target)
    button:SetAttribute("type", "click")
    button:SetAttribute("clickbutton", target)
end

-- Aimed as the press comes (PreClick), out of a fight: in one the snippet has set the item. What the
-- press opens takes the pad, so ours is given back first.
function PT.AimA(button)
    if InCombatLockdown() then return end
    button:SetAttribute("type", nil)
    PT.todo = nil
    local cell = PT.open == "list" and PT.Cell()
    if not cell then return end
    local OT = ns.ObjectiveTracker
    if PT.entries then
        PT.todo = PT.RunEntry
    elseif cell.kind == "quest" then
        local icon = OT.Pad.QuestIcon(cell.questID)
        if icon then
            if OT.KeepFocusManual then OT.KeepFocusManual() end   -- the player's own choice
            AimAt(button, icon)
        else
            PT.todo = function() OT.Pad.ToggleFocus(cell.questID) end
        end
    elseif cell.kind == "item" then
        button:SetAttribute("type", "item")
        button:SetAttribute("item", cell.frame:GetAttribute("item"))
    elseif cell.kind == "recipe" then
        local target = PT.RecipeHeader(cell.frame.recipeID)
        if target then
            AimAt(button, target)
            PT.Close()
        end
    elseif cell.kind == "button" or cell.kind == "voice" then
        PT.todo = function() cell.frame:Click("LeftButton") end
    else
        PT.todo = function() OT.Pad.LineClick(cell.frame, "LeftButton") end
    end
end

function PT.AimX(button)
    if InCombatLockdown() then return end
    button:SetAttribute("type", nil)
    PT.todo = nil
    local cell = PT.open == "list" and not PT.entries and PT.Cell()
    if not cell or cell.kind ~= "quest" then return end
    if ns.ObjectiveTracker.Pad.AimDetails(button, cell.questID) then
        PT.Close()
    else
        PT.todo = function() ns.ObjectiveTracker.Pad.LineClick(cell.frame, "LeftButton") end
    end
end

function PT.AfterPress()
    local todo = PT.todo
    PT.todo = nil
    if todo and not InCombatLockdown() then todo() end
    if PT.open == "list" then PT.Refresh() end
end

-- the options list
function PT.BuildEntries(cell)
    local OT, pad = ns.ObjectiveTracker, ns.ObjectiveTracker.Pad
    local text = pad.TEXT
    local list = {}
    -- (Questie's entry is made for a menu)
    local root = { CreateButton = function(_, label, run) list[#list + 1] = { label, run } end }
    if cell.kind == "recipe" then
        local recipeID = cell.frame.recipeID
        root:CreateButton(text.untrack, function() C_TradeSkillUI.SetRecipeTracked(recipeID, false, false) end)
    elseif cell.kind == "quest" then
        local questID = cell.questID
        if IsInGroup() and C_QuestLog.IsPushableQuest(questID) then
            root:CreateButton(text.share, function() QuestUtil.ShareQuest(questID) end)
        end
        root:CreateButton(pad.IsCollapsed(questID) and L["Expand"] or L["Collapse"], function() pad.ToggleCollapsed(questID) end)
        root:CreateButton(pad.IsPinned(questID) and L["Unpin"] or L["Pin to Top"], function() pad.TogglePinned(questID) end)
        OT.AddQuestieIconsButton(root, questID)
        if C_QuestLog.GetQuestWatchType(questID) == nil then
            root:CreateButton(text.track, function() OT.SetWatched(questID, true) end)
        elseif QuestUtil.CanRemoveQuestWatch() then
            root:CreateButton(text.untrack, function() OT.SetWatched(questID, false) end)
        end
    end
    return list
end

function PT.OpenMenu()
    local cell = PT.open == "list" and PT.Cell()
    if InCombatLockdown() or not cell then return end
    if PT.entries then PT.CloseMenu() PT.UpdateHints() return end
    local list = PT.BuildEntries(cell)
    if #list == 0 then return end
    PT.entries, PT.entryAt = list, 1
    PT.nav:SetAttribute("flare-menu", true)
    GameTooltip:Hide()
    PT.DrawMenu()
    PT.UpdateHints()
end

function PT.DrawMenu()
    local menu, cell = PT.menu, PT.Cell()
    local width = 80
    for i, entry in ipairs(PT.entries) do
        local line = menu.lines[i]
        if not line then
            line = menu:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            line:SetPoint("TOPLEFT", 10, -8 - (i - 1) * 20)
            menu.lines[i] = line
        end
        line:SetText(entry[1])
        line:Show()
        width = math.max(width, line:GetStringWidth())
    end
    for i = #PT.entries + 1, #menu.lines do menu.lines[i]:Hide() end
    menu:SetSize(width + 20, #PT.entries * 20 + 10)
    menu.band:ClearAllPoints()
    menu.band:SetPoint("TOPLEFT", 2, -5 - (PT.entryAt - 1) * 20)
    menu.band:SetPoint("TOPRIGHT", -2, -5 - (PT.entryAt - 1) * 20)
    menu.band:SetHeight(20)
    -- on the side of the screen's middle
    local right = ns.ObjectiveTracker:Side()
    menu:ClearAllPoints()
    if right then
        menu:SetPoint("TOPRIGHT", cell.frame, "TOPLEFT", -16, 4)
    else
        menu:SetPoint("TOPLEFT", cell.frame, "TOPRIGHT", 16, 4)
    end
    menu:Show()
end

function PT.CloseMenu()
    PT.entries, PT.entryAt = nil, nil
    if PT.menu then PT.menu:Hide() end
    if PT.nav and not InCombatLockdown() then PT.nav:SetAttribute("flare-menu", nil) end
end

function PT.RunEntry()
    local entry = PT.entries and PT.entries[PT.entryAt]
    PT.CloseMenu()
    if entry then entry[2]() end
end

--------------------------------------------------
-- 6. OPEN AND CLOSE
--------------------------------------------------
-- the snippet has set the bindings
function PT.Opened()
    PT.CreateLook()
    local rows = PT.BuildRows()
    if #rows == 0 then PT.Close() return end
    PT.open = "list"
    if ns.Visibility and ns.Visibility.Wake then ns.Visibility:Wake() end   -- a faded tracker shows
    -- the focused quest, else the first quest, else the first row
    local focused = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID()
    local r, c = PT.Find("quest:" .. tostring(focused))
    if not r then
        r = 1
        for i, row in ipairs(rows) do
            local at = Landing(row, "quest")
            if row[at].kind == "quest" then r = i break end
        end
        c = Landing(rows[r], "quest")
    end
    PT.Select(r, c)
end

-- in a fight: a quest item
function PT.MarkItem(i)
    PT.CreateLook()
    PT.open = "items"
    local pad = ns.ObjectiveTracker.Pad
    PT.PlaceMark(pad.Parts().itemButtons[i], 2)
    PT.ShowHints({ { "A", PT.LABEL.use }, { "B", PT.LABEL.back } })
end

-- the bindings are gone
function PT.Closed()
    local was, cell = PT.open, PT.Cell()
    PT.open, PT.key, PT.rowAt, PT.cellAt, PT.todo = nil, nil, nil, nil, nil
    PT.CloseMenu()
    if not was then return end
    if PT.ticker then PT.ticker:Hide() end
    PT.mark:Hide()
    PT.hints:Hide()
    if cell and (cell.kind == "button" or cell.kind == "voice" or cell.kind == "item") then Leave(cell.frame) end
    ns.ObjectiveTracker:HighlightGroup(nil)
    GameTooltip:Hide()
    if ns.Visibility and ns.Visibility.Wake then ns.Visibility:Wake() end
end

-- From plain Lua: out of a fight only (in one, B)
function PT.Close()
    local nav = PT.nav
    if not nav or InCombatLockdown() then return end
    if nav:GetAttribute("flare-open") then
        nav:SetAttribute("flare-open", nil)
        ClearOverrideBindings(nav)
    end
    PT.Closed()
end

--------------------------------------------------
-- 7. SETUP
--------------------------------------------------
-- FlareUI's tracker stands in for Blizzard's in this session
function PT.Wanted()
    local OT = ns.ObjectiveTracker
    return ns.IsGamepadUI and ns.IsGamepadUI() and not (ns.OtherControllerAddon and ns.OtherControllerAddon())
        and OT and OT.initialized and _G.QuestLogMicroButton and true or false
end

function PT.UpdateKeys()
    local w = PT.watcher
    if not w then return end
    local k1, k2
    local context = C_KeyBindings and C_KeyBindings.GetBindingContextForAction
        and C_KeyBindings.GetBindingContextForAction(PT.ACTION)
    if context then
        local ok, a, b = pcall(GetBindingKey, PT.ACTION, nil, context)
        if ok then k1, k2 = a, b end
    end
    if not k1 then k1, k2 = GetBindingKey(PT.ACTION, 1) end
    if not k1 then k1, k2 = PT.FALLBACK, nil end
    if k2 == k1 then k2 = nil end
    w:SetAttribute("flare-key1", k1)
    w:SetAttribute("flare-key2", k2)
end

-- The tracker was drawn or scrolled (ObjectiveTracker.lua, OT:UpdateItemButtons, out of a fight)
function PT.OnTrackerDrawn()
    local w = PT.watcher
    if not w or InCombatLockdown() then return end
    local pad = ns.ObjectiveTracker.Pad
    local p = pad.Parts()
    local items = p.itemButtons
    for i = (PT.itemRefs or 0) + 1, #items do
        SecureHandlerSetFrameRef(w, "i" .. i, items[i])
        PT.itemRefs = i
    end
    w:SetAttribute("flare-items", PT.itemRefs or 0)
    local shown = p.holder and (p.holder:IsShown() or (p.miniButton and p.miniButton:IsShown())) and true or false
    w:SetAttribute("flare-nav", shown)
    if PT.open ~= "list" then return end
    if not shown or p.state.editMode then PT.Close() else PT.Refresh() end
end

local function SecureButton(name, onPress)
    local b = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
    -- parked off screen: a binding click needs no visible button
    b:SetSize(1, 1)
    b:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -500, 500)
    b:RegisterForClicks(onPress)
    b:SetAttribute("useOnKeyDown", onPress == "AnyDown")
    b:SetAttribute("pressAndHoldAction", false)
    return b
end

function PT.Setup()
    if InCombatLockdown() then PT.pending = true return end
    PT.pending = nil
    local wanted = PT.Wanted()
    if not PT.watcher then
        if not wanted then return end
        local main = _G.GamepadMainActionBarFrame
        local bar = main and main.PageUnit and main.PageUnit.ShortcutsActionBar
        if not bar then return end
        local w = CreateFrame("Frame", "FlareUIPadTrackerWatch", bar, "SecureHandlerShowHideTemplate")
        w:SetSize(1, 1)
        w:SetPoint("CENTER")
        w:EnableMouse(false)
        ns.IgnorePadNav(w)
        w.FlareBound = function(_, on) PT.bound = on end
        w.FlareOpen = function() PT.Opened() end
        w.FlareMove = function(_, dir, down) PT.OnMove(dir, down) end
        w.FlareMenu = function() PT.OpenMenu() end
        w.FlareMenuBack = function() PT.CloseMenu() PT.UpdateHints() end
        w.FlareMark = function(_, i) PT.MarkItem(i) end
        w.FlareClosed = function() PT.Closed() end
        w:SetAttribute("_onshow", PT.SHOW_SNIPPET)
        w:SetAttribute("_onhide", PT.HIDE_SNIPPET)
        PT.watcher = w

        local b = SecureButton(PT.BUTTON, "AnyDown")
        b:SetAttribute("type", "macro")
        b:SetAttribute("macrotext", "/click QuestLogMicroButton")
        PT.button = b

        local nav = SecureButton(PT.NAV, "AnyDown")
        nav:RegisterForClicks("AnyDown", "AnyUp")
        SecureHandlerWrapScript(nav, "OnClick", w, PT.NAV_SNIPPET)
        PT.nav = nav

        PT.buttonA, PT.buttonX = SecureButton(PT.A, "AnyUp"), SecureButton(PT.X, "AnyUp")
        PT.buttonA:SetScript("PreClick", PT.AimA)
        PT.buttonX:SetScript("PreClick", PT.AimX)
        PT.buttonA:SetScript("PostClick", PT.AfterPress)
        PT.buttonX:SetScript("PostClick", PT.AfterPress)
        SecureHandlerSetFrameRef(w, "a", PT.buttonA)

        -- a window of the game's took the pad (read only; a frame later, when it has finished)
        if EventRegistry and EventRegistry.RegisterCallback then
            EventRegistry:RegisterCallback("Gamepad.RefreshFrameFocus", function()
                if not PT.open then return end
                C_Timer.After(0, function()
                    local manager = GamepadMode and GamepadMode.FrameControlsManager
                    if PT.open and manager and manager.isUIFocused then PT.Close() end
                end)
            end, PT)
        end
    end
    PT.watcher:SetAttribute("flare-on", wanted)
    if not wanted then PT.Close() end
    if not PT.bound then PT.UpdateKeys() end
    if wanted then PT.OnTrackerDrawn() end
end

PT.events = CreateFrame("Frame")
PT.events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        -- (just before the lockdown: the pad goes back to the action bars)
        PT.Close()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if PT.pending then PT.Setup() end
        PT.Close()
        PT.OnTrackerDrawn()
    elseif event == "PLAYER_LEAVING_WORLD" then
        PT.Close()
    elseif event == "UPDATE_BINDINGS" then
        -- override bindings fire this too: only a change made while the key is free counts
        if not PT.watcher or PT.bound or PT.open then return end
        if InCombatLockdown() then PT.pending = true else PT.UpdateKeys() end
    else
        -- (next frame: every module has started, and the game has switched its input mode)
        C_Timer.After(0, PT.Setup)
    end
end)
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "INPUT_DEVICE_INTERFACE_TRANSITION",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_LEAVING_WORLD", "UPDATE_BINDINGS" }) do
    pcall(PT.events.RegisterEvent, PT.events, event)
end
