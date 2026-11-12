local _, ns = ...
local L = ns.L

--------------------------------------------------
-- CONTROLLER NAVIGATION (Gamepad UI)
-- FlareUI's own windows (the settings window, with the radial editor inside it) work with the
-- controller: a listener frame takes the pad's buttons while the window is open, never Blizzard's
-- SmartNavigation (a pad click there runs FlareUI code inside its navigation, which hangs the client).
-- The window's buttons are found as it is drawn, so every page works without a list of its own:
--   D-pad      moves between controls, by where they sit (held: repeats)
--   A          clicks; on a stepper or list choice it grabs it (gold), left / right change it,
--              A or B lets go
--   B          closes the window (lets go first when something is grabbed)
--   LB / RB    the page's tabs        LT / RT   the pages
--   X / Y      what the focused control offers (the radial editor: remove, pick up and move)
-- A control can tune this: padSkip (never focused), padActivate(), padCycle(delta) (a dropdown left
-- and right change), padX(), padY(), padMove(delta) (moving it while picked up returns the control
-- to focus next), and a list (the parent of its cells) PadScroll(delta).
-- Paused while a FlareUI dialog is up, a key is being captured, or in combat (the listener lets go
-- of the pad there: its input flags can't change in a fight).
--------------------------------------------------
local PadNav = {}
ns.PadNav = PadNav

local KEY = {
    UP = "PADDUP", DOWN = "PADDDOWN", LEFT = "PADDLEFT", RIGHT = "PADDRIGHT",
    A = GAMEPAD_FACE_BOTTOM or "PAD1", B = GAMEPAD_FACE_RIGHT or "PAD2",
    X = GAMEPAD_FACE_LEFT or "PAD3", Y = GAMEPAD_FACE_TOP or "PAD4",
    LB = GAMEPAD_SHOULDER_LEFT or "PADLSHOULDER", RB = GAMEPAD_SHOULDER_RIGHT or "PADRSHOULDER",
    LT = "PADLTRIGGER", RT = "PADRTRIGGER",
}
local DIRECTIONS = {
    [KEY.UP] = { 0, 1 }, [KEY.DOWN] = { 0, -1 }, [KEY.LEFT] = { -1, 0 }, [KEY.RIGHT] = { 1, 0 },
}
local REPEAT_DELAY, REPEAT_RATE = 0.35, 0.08
local SIDE_WEIGHT = 2.5        -- how much being off to the side counts against a control
local REVEAL_MARGIN = 24       -- kept between a revealed control and its scroll frame's edge

local root, opts               -- the window being driven, and what it told Attach
local focus, focusKey, focusX, focusY
local grabbed                  -- the focused control, while it is grabbed
local repeatKey, nextRepeat
local listener, ring, hints

--------------------------------------------------
-- 1. CONTROLS
--------------------------------------------------
local function IsStepper(obj) return obj.IncrementButton and obj.DecrementButton and obj.Dropdown end
local function IsDropdown(obj) return obj:IsObjectType("DropdownButton") end

-- the settings row a control belongs to (its row frame's), for finding it again after a redraw
local function RowKey(obj)
    local parent = obj and obj:GetParent()
    local row = parent and parent.row
    return row and row.key or nil
end

local function Adjustable(obj)
    if IsStepper(obj) then return true end
    if obj.padCycle and obj:IsObjectType("Slider") then return true end
    if IsDropdown(obj) then
        local parent = obj:GetParent()
        return obj.padCycle ~= nil or (parent and parent.row and parent.row.Choices) ~= nil
    end
    return false
end

local function Usable(obj)
    if obj.padSkip or not obj:IsVisible() then return false end
    local w, h = obj:GetSize()
    return w >= 8 and h >= 8
end

local function Collect(obj, out)
    for _, child in ipairs({ obj:GetChildren() }) do
        if child:IsVisible() and not child.padSkip then
            if IsStepper(child) then
                out[#out + 1] = child           -- one control; its arrows and dropdown are not
            elseif child:IsObjectType("Slider") then
                if child:IsEnabled() and Usable(child) then out[#out + 1] = child end
            elseif child:IsObjectType("Button") then
                if child:IsEnabled() and child:IsMouseEnabled() and Usable(child) then out[#out + 1] = child end
                if child.padChildren then Collect(child, out) end
            else
                Collect(child, out)
            end
        end
    end
    return out
end

local function Controls()
    return root and Collect(root, {}) or {}
end

local function Center(obj)
    local x, y = obj:GetCenter()
    if not x then return nil end
    local s = obj:GetEffectiveScale()
    return x * s, y * s
end

local function IsInside(obj, ancestor)
    while obj do
        if obj == ancestor then return true end
        obj = obj:GetParent()
    end
    return false
end

--------------------------------------------------
-- 2. FOCUS
--------------------------------------------------
local function HoverTarget(obj) return IsStepper(obj) and obj.Dropdown or obj end

local function Run(obj, script)
    if obj and obj:GetScript(script) ~= nil then pcall(ExecuteFrameScript, obj, script) end
end

-- the control's own scroll frame keeps it in view
local function Reveal(obj)
    local scroll = obj:GetParent()
    while scroll and not scroll:IsObjectType("ScrollFrame") do scroll = scroll:GetParent() end
    local child = scroll and scroll:GetScrollChild()
    if not (child and child:GetTop() and obj:GetTop()) then return end
    local top, bottom = child:GetTop() - obj:GetTop(), child:GetTop() - obj:GetBottom()
    local current, view = scroll:GetVerticalScroll(), scroll:GetHeight()
    local range = scroll:GetVerticalScrollRange() or 0
    if top < current + REVEAL_MARGIN then
        scroll:SetVerticalScroll(math.max(0, top - REVEAL_MARGIN))
    elseif bottom > current + view - REVEAL_MARGIN then
        scroll:SetVerticalScroll(math.min(range, bottom - view + REVEAL_MARGIN))
    end
end

local function UpdateHints()
    if not hints then return end
    local K = ns.KeyText
    local parts = {
        K(KEY.LB) .. " " .. K(KEY.RB) .. " " .. L["Tabs"],
        K(KEY.LT) .. " " .. K(KEY.RT) .. " " .. L["Pages"],
        K(KEY.A) .. " " .. (grabbed and L["Done"] or L["Select"]),
        K(KEY.B) .. " " .. (grabbed and L["Done"] or L["Close"]),
    }
    if focus and focus.padX then parts[#parts + 1] = K(KEY.X) .. " " .. L["Remove"] end
    if focus and (focus.padY or focus.padMove) then parts[#parts + 1] = K(KEY.Y) .. " " .. (grabbed and L["Put Down"] or L["Move"]) end
    hints.text:SetText(table.concat(parts, "     "))
end

local function PlaceRing()
    if not focus then ring:Hide() return end
    ring:ClearAllPoints()
    ring:SetPoint("TOPLEFT", focus, "TOPLEFT", -3, 3)
    ring:SetPoint("BOTTOMRIGHT", focus, "BOTTOMRIGHT", 3, -3)
    local r, g, b = 1, 0.82, 0
    if grabbed then r, g, b = 1, 0.55, 0.1 end
    for _, edge in ipairs(ring.edges) do edge:SetColorTexture(r, g, b, 1) end
    ring:Show()
end

local function SetFocus(obj)
    if obj == focus then PlaceRing() return end
    if focus then Run(HoverTarget(focus), "OnLeave") end
    focus, grabbed = obj, nil
    if obj then
        Reveal(obj)
        focusKey = RowKey(obj)
        focusX, focusY = Center(obj)
        Run(HoverTarget(obj), "OnEnter")
    end
    PlaceRing()
    UpdateHints()
end

-- the first control of the window's content (opts.start), else the top left one
local function FirstControl(list)
    local start = opts and opts.start and opts.start()
    local best, bestY, bestX
    for pass = 1, 2 do
        for _, obj in ipairs(list) do
            if pass == 2 or (start and IsInside(obj, start)) then
                local x, y = Center(obj)
                if x and (not best or y > bestY + 4 or (math.abs(y - bestY) <= 4 and x < bestX)) then
                    best, bestX, bestY = obj, x, y
                end
            end
        end
        if best then return best end
    end
end

-- after a redraw: the same control if still there, else the one on the same settings row, else the
-- nearest to where it was
local function Revalidate()
    local list = Controls()
    if focus then
        for _, obj in ipairs(list) do
            if obj == focus and (not focusKey or RowKey(obj) == focusKey) then
                focusX, focusY = Center(obj)
                return
            end
        end
    end
    local found
    if focusKey then
        for _, obj in ipairs(list) do
            if RowKey(obj) == focusKey then found = obj break end
        end
    end
    if not found and focusX then
        local bestD
        for _, obj in ipairs(list) do
            local x, y = Center(obj)
            if x then
                local d = (x - focusX) ^ 2 + (y - focusY) ^ 2
                if not bestD or d < bestD then found, bestD = obj, d end
            end
        end
    end
    focus = nil
    SetFocus(found or FirstControl(list))
end

--------------------------------------------------
-- 3. ACTIONS
--------------------------------------------------
local function Move(key)
    local dir = DIRECTIONS[key]
    if not focus then SetFocus(FirstControl(Controls())) return end
    local fx, fy = Center(focus)
    if not fx then return end
    local best, bestScore
    for _, obj in ipairs(Controls()) do
        if obj ~= focus then
            local x, y = Center(obj)
            if x then
                local dx, dy = x - fx, y - fy
                local along = dx * dir[1] + dy * dir[2]
                if along > 4 then
                    local side = math.abs(dx * dir[2] - dy * dir[1])
                    local score = along + side * SIDE_WEIGHT
                    if not bestScore or score < bestScore then best, bestScore = obj, score end
                end
            end
        end
    end
    -- a list scrolls before its last visible cell is left
    local list = focus:GetParent()
    if dir[1] == 0 and list and list.PadScroll and (not best or best:GetParent() ~= list) then
        if list:PadScroll(-dir[2]) then
            Run(HoverTarget(focus), "OnEnter")
            UpdateHints()
            return
        end
    end
    if best then SetFocus(best) end
end

local function CycleRow(row, delta)
    -- toggles have no single value to step through: the menu opens instead
    if row.toggles then return end
    local choices = {}
    for _, c in ipairs(row:Choices() or {}) do
        if not c.divider then choices[#choices + 1] = c end
    end
    if #choices == 0 then return end
    local value, at = row:Get(), 0
    for i, c in ipairs(choices) do if c.value == value then at = i end end
    local nextAt = ((at - 1 + delta) % #choices) + 1
    if at == 0 then nextAt = delta > 0 and 1 or #choices end
    row:Set(choices[nextAt].value)
end

local function Adjust(delta)
    local obj = focus
    if not obj then return end
    if IsStepper(obj) then
        local arrow = delta > 0 and obj.IncrementButton or obj.DecrementButton
        if arrow:IsEnabled() then arrow:Click() end
    elseif obj.padCycle then
        obj.padCycle(delta)
    elseif obj:GetParent() and obj:GetParent().row then
        CycleRow(obj:GetParent().row, delta)
    end
    ns.ButtonSound()
end

local function Activate()
    local obj = focus
    if not obj then return end
    if grabbed then
        grabbed = nil
    elseif obj.padActivate then
        obj.padActivate()
    elseif Adjustable(obj) then
        grabbed = obj
    elseif IsDropdown(obj) then
        -- Blizzard's menus can't be opened from addon code in the Gamepad UI
        if UIErrorsFrame then UIErrorsFrame:AddMessage(L["Use the mouse for this list."], 1, 0.25, 0.25) end
    else
        obj:Click("LeftButton")
    end
    PlaceRing()
    UpdateHints()
end

local function Paused()
    return InCombatLockdown() or ns.AnyDialogShown() or ns.keyCapturing ~= nil
end

-- true: the press was FlareUI's (it does not reach the game)
local function Press(key)
    if not (root and root:IsShown()) or Paused() then return false end
    if DIRECTIONS[key] then
        local dir = DIRECTIONS[key]
        if grabbed and grabbed.padMove and dir[1] == 0 then
            local moved = grabbed.padMove(-dir[2])
            if moved then SetFocus(moved) grabbed = moved PlaceRing() UpdateHints() end
        elseif grabbed and dir[2] == 0 then
            Adjust(dir[1])
        else
            grabbed = nil
            Move(key)
        end
        return true
    elseif key == KEY.A then
        Activate()
        return true
    elseif key == KEY.B then
        if grabbed then
            grabbed = nil
            PlaceRing()
            UpdateHints()
        elseif opts and opts.close then
            opts.close()
        end
        return true
    elseif key == KEY.X then
        if focus and focus.padX then focus.padX() C_Timer.After(0, Revalidate) end
        return true
    elseif key == KEY.Y then
        -- a control that moves (padMove) is picked up and put down; any other runs its padY
        if grabbed then
            grabbed = nil
        elseif focus and focus.padMove then
            grabbed = focus
        elseif focus and focus.padY then
            focus.padY()
        end
        PlaceRing()
        UpdateHints()
        return true
    elseif key == KEY.LB or key == KEY.RB then
        grabbed = nil
        if opts and opts.tab then opts.tab(key == KEY.LB and -1 or 1) end
        C_Timer.After(0, Revalidate)
        return true
    elseif key == KEY.LT or key == KEY.RT then
        grabbed = nil
        if opts and opts.page then opts.page(key == KEY.LT and -1 or 1) end
        C_Timer.After(0, function() focus = nil; SetFocus(FirstControl(Controls())) end)
        return true
    end
    return false
end

--------------------------------------------------
-- 4. THE LISTENER
--------------------------------------------------
local function SetListening(on)
    if not listener then return end
    pcall(listener.EnableGamePadButton, listener, on and true or false)
    if not InCombatLockdown() then listener:SetPropagateKeyboardInput(true) end
    listener:SetShown(on)
    if not on then
        if focus then Run(HoverTarget(focus), "OnLeave") end
        focus, grabbed, repeatKey = nil, nil, nil
        ring:Hide()
    end
    hints:SetShown(on)
end

local function Build()
    listener = CreateFrame("Frame", "FlareUI_PadNav", UIParent)
    listener:SetFrameStrata("TOOLTIP")
    listener.smartNavigationIgnored = true
    listener:Hide()
    listener:SetScript("OnGamePadButtonDown", function(self, key)
        local handled = Press(key)
        if handled and DIRECTIONS[key] then repeatKey, nextRepeat = key, GetTime() + REPEAT_DELAY end
        if not InCombatLockdown() then self:SetPropagateKeyboardInput(not handled) end
    end)
    listener:SetScript("OnGamePadButtonUp", function(self, key)
        if key == repeatKey then repeatKey = nil end
        if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
    end)
    local elapsed = 0
    listener:SetScript("OnUpdate", function(_, dt)
        if repeatKey and GetTime() >= nextRepeat then
            nextRepeat = GetTime() + REPEAT_RATE
            Press(repeatKey)
        end
        elapsed = elapsed + dt
        if elapsed < 0.15 then return end
        elapsed = 0
        if Paused() then ring:Hide() return end
        Revalidate()
        PlaceRing()
    end)

    ring = CreateFrame("Frame", nil, UIParent)
    ring:SetFrameStrata("TOOLTIP")
    ring.edges = {}
    for i, points in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local edge = ring:CreateTexture(nil, "OVERLAY")
        edge:SetPoint(points[1])
        edge:SetPoint(points[2])
        if i <= 2 then edge:SetHeight(2) else edge:SetWidth(2) end
        ring.edges[i] = edge
    end
    ring:Hide()

    hints = CreateFrame("Frame", nil, UIParent)
    hints:SetSize(10, 22)
    hints:SetFrameStrata("TOOLTIP")
    hints.text = hints:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hints.text:SetPoint("LEFT")
    hints:Hide()

    local combat = CreateFrame("Frame")
    combat:RegisterEvent("PLAYER_REGEN_DISABLED")
    combat:RegisterEvent("PLAYER_REGEN_ENABLED")
    combat:SetScript("OnEvent", function(_, event)
        if not root then return end
        if event == "PLAYER_REGEN_DISABLED" then
            SetListening(false)
        elseif root:IsShown() then
            SetListening(true)
            C_Timer.After(0, Revalidate)
        end
    end)
end

--------------------------------------------------
-- 5. ATTACHING A WINDOW
--------------------------------------------------
-- opts: close(), tab(delta), page(delta), start() (the content's container, where focus starts)
function PadNav.Attach(window, options)
    if not ns.IsGamepadUI() or not window then return end
    if not listener then Build() end
    window.smartNavigationIgnored = true
    local function Start()
        root, opts = window, options or {}
        hints:ClearAllPoints()
        hints:SetPoint("BOTTOMLEFT", window, "TOPLEFT", 8, 4)
        if InCombatLockdown() then return end
        SetListening(true)
        C_Timer.After(0, function()
            if root == window and window:IsShown() then focus = nil; SetFocus(FirstControl(Controls())) end
        end)
    end
    window:HookScript("OnShow", Start)
    window:HookScript("OnHide", function()
        if root ~= window then return end
        SetListening(false)
        root, opts = nil, nil
    end)
    if window:IsShown() then Start() end
end

--------------------------------------------------
-- LISTS IN THE GAMEPAD UI (11-11, a player's ADDON_ACTION_FORBIDDEN)
-- Blizzard's menus can't be opened from addon code in the Gamepad UI: showing one hands the
-- controller navigation an untrusted call, which ends in a blocked protected call blamed on FlareUI
-- (SetPreferredGamepadInteractTarget). A dropdown's own mouse handler can't be replaced, so a catcher
-- button lies over it and opens this plain list instead, built from the same choices.
-- entries: { text, checked(), pick(), multi (stays open), divider, onEnter(), onLeave(), font(fs) }
--------------------------------------------------
PadNav.LIST_ROWS, PadNav.LIST_ROW_H = 16, 20

function PadNav.CloseList()
    local list = PadNav.list
    if list and list:IsShown() then list:Hide() end
end

function PadNav.OpenList(owner, entries, onClose)
    local list = PadNav.list
    if not list then
        list = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        list:SetFrameStrata("FULLSCREEN_DIALOG")
        list:SetClampedToScreen(true)
        list:EnableMouse(true)
        list:EnableMouseWheel(true)
        list:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        list:SetBackdropColor(0.05, 0.04, 0.03, 0.97)
        local c = ns.BORDER_COLOR
        list:SetBackdropBorderColor(c.r, c.g, c.b, 1)
        list.rows = {}
        for i = 1, PadNav.LIST_ROWS do
            local b = CreateFrame("Button", nil, list)
            b:SetHeight(PadNav.LIST_ROW_H)
            b:SetPoint("TOPLEFT", 4, -4 - (i - 1) * PadNav.LIST_ROW_H)
            b:SetPoint("TOPRIGHT", -4, -4 - (i - 1) * PadNav.LIST_ROW_H)
            b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            b.tick = b:CreateTexture(nil, "ARTWORK")
            b.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            b.tick:SetSize(16, 16)
            b.tick:SetPoint("LEFT", 2, 0)
            b.text = b:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            b.text:SetPoint("LEFT", 22, 0)
            b.text:SetPoint("RIGHT", -4, 0)
            b.text:SetJustifyH("LEFT")
            b.text:SetWordWrap(false)
            b.line = b:CreateTexture(nil, "ARTWORK")
            b.line:SetColorTexture(c.r, c.g, c.b, 0.6)
            b.line:SetHeight(1)
            b.line:SetPoint("LEFT", 6, 0)
            b.line:SetPoint("RIGHT", -6, 0)
            b:SetScript("OnClick", function(self)
                local e = self.entry
                if not e or e.divider then return end
                if e.pick then e.pick() end
                if e.multi then PadNav.FillList() else PadNav.CloseList() end
            end)
            b:SetScript("OnEnter", function(self) if self.entry and self.entry.onEnter then self.entry.onEnter() end end)
            b:SetScript("OnLeave", function(self) if self.entry and self.entry.onLeave then self.entry.onLeave() end end)
            list.rows[i] = b
        end
        list:SetScript("OnMouseWheel", function(_, delta)
            local maxOffset = math.max(0, #list.entries - PadNav.LIST_ROWS)
            list.offset = math.max(0, math.min(maxOffset, list.offset - delta * 3))
            PadNav.FillList()
        end)
        -- a click anywhere else closes it
        list:SetScript("OnEvent", function(self)
            if not (self:IsMouseOver() or (self.owner and self.owner:IsMouseOver())) then self:Hide() end
        end)
        list:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
        list:SetScript("OnHide", function(self)
            self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
            local done = self.onClose
            self.onClose, self.owner = nil, nil
            if done then done() end
        end)
        PadNav.list = list
    end
    -- the same owner again: it closes, as Blizzard's menu does
    if list:IsShown() then
        local same = list.owner == owner
        list:Hide()
        if same then return end
    end
    list.entries, list.offset, list.owner, list.onClose = entries, 0, owner, onClose
    -- start at the ticked choice
    for i, e in ipairs(entries) do
        if e.checked and e.checked() and not e.multi then
            list.offset = math.max(0, math.min(i - 1, #entries - PadNav.LIST_ROWS))
            break
        end
    end
    list:SetWidth(math.max(160, owner:GetWidth()))
    list:SetHeight(math.min(#entries, PadNav.LIST_ROWS) * PadNav.LIST_ROW_H + 8)
    list:ClearAllPoints()
    list:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
    PadNav.FillList()
    list:Show()
end

function PadNav.FillList()
    local list = PadNav.list
    if not list then return end
    for i, b in ipairs(list.rows) do
        local e = list.entries[list.offset + i]
        b.entry = e
        if e then
            b.line:SetShown(e.divider == true)
            b.text:SetShown(not e.divider)
            b.tick:SetShown(not e.divider and e.checked and e.checked() or false)
            if not e.divider then
                b.text:SetText(e.text or "")
                if e.font then e.font(b.text) else b.text:SetFontObject("GameFontHighlight") end
            end
            b:Show()
        else
            b:Hide()
        end
    end
end

-- a catcher over a dropdown in the Gamepad UI: clicks open the plain list (build() answers its entries)
function PadNav.GuardDropdown(dropdown, build, onClose)
    if not ns.IsGamepadUI() or dropdown.padCatcher then return end
    local catcher = CreateFrame("Button", nil, dropdown)
    catcher:SetAllPoints()
    catcher:SetFrameLevel(dropdown:GetFrameLevel() + 5)
    catcher:SetScript("OnClick", function()
        if not dropdown:IsEnabled() then return end
        PadNav.OpenList(dropdown, build(), function()
            if onClose then onClose() end
            -- the shown choice, as Blizzard's menu updates it
            if dropdown.GenerateMenu then dropdown:GenerateMenu() end
        end)
    end)
    catcher:SetScript("OnEnter", function() local s = dropdown:GetScript("OnEnter"); if s then s(dropdown) end end)
    catcher:SetScript("OnLeave", function() local s = dropdown:GetScript("OnLeave"); if s then s(dropdown) end end)
    dropdown.padCatcher = catcher
end
