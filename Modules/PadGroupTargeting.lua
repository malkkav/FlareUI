local _, ns = ...

--------------------------------------------------
-- CONTROLLER GROUP TARGETING
-- In the Gamepad UI, holding the friendly targeting button (LB) and pressing the D-pad moves
-- through the party or raid frames and targets the member landed on. Blizzard's version walks its
-- own Compact frames, which FlareUI hides, so this does the same on FlareUI's party and raid frames.
--
-- How it works, all secure so it runs in combat:
-- * The watcher is a protected child of Blizzard's Friendly Targeting action bar. That bar is shown
--   exactly while LB is held (and only then takes the D-pad), so the watcher's _onshow binds the
--   D-pad to the nav button and its _onhide clears the bindings. No Blizzard function or script is
--   hooked or replaced.
-- * The nav button is a SecureActionButton of type "target". Its wrapped OnClick picks the next
--   frame in the pressed direction (by screen position, wrapping at the edges) and sets its unit.
-- * The highlight is a plain frame the snippet places through CallMethod.
-- Blizzard's rules are kept: nothing while solo, and in a party with Blizzard's Party Targeting
-- option on (GamepadUsePartyTargeting: one D-pad direction per member) Blizzard keeps the D-pad.
-- Off outside the Gamepad UI and while ConsolePort or another controller addon is loaded.
--------------------------------------------------
ns.PadGroupTargeting = ns.PadGroupTargeting or {}
local PGT = ns.PadGroupTargeting

PGT.NAV_NAME = "FlareUIPadGroupNav"
PGT.buttons = {}        -- registered unit buttons, in order; their number is their frame ref "b<n>"
PGT.known = {}          -- button -> true
PGT.refCount = 0        -- how many of them the watcher has as frame refs

-- the mouse button each direction clicks with, its Gamepad action button (1-4 on the D-pad side,
-- 5-8 when Blizzard's Swap Friendly Target Actions moves them to the face buttons) and the keys used
-- when no binding is found
PGT.DIRECTIONS = {
    { click = "PadLeft",  slot = 1, dpad = "PADDLEFT",  face = "PAD3" },
    { click = "PadUp",    slot = 2, dpad = "PADDUP",    face = "PAD4" },
    { click = "PadRight", slot = 3, dpad = "PADDRIGHT", face = "PAD2" },
    { click = "PadDown",  slot = 4, dpad = "PADDDOWN",  face = "PAD1" },
}

PGT.HIGHLIGHT_COLOR = { 0.25, 0.60, 1, 1 }   -- the palette's blue (Edit Mode's selection blue)
PGT.HIGHLIGHT_SIZE = 2

--------------------------------------------------
-- SECURE SNIPPETS (restricted Lua: the word for a Lua closure may not appear anywhere in them)
--------------------------------------------------
-- self is the watcher. LB went down: bind the D-pad while there is a group frame to move over.
PGT.SHOW_SNIPPET = [[
    if self:GetAttribute("flare-on") ~= true then return end
    if SecureCmdOptionParse("[group:raid] 1; [@raid1,exists] 1; 0") ~= "1" then
        if SecureCmdOptionParse("[group:party] 1; [@party1,exists] 1; 0") ~= "1" then return end
        if self:GetAttribute("flare-direct") then return end
    end
    local any = false
    for i = 1, self:GetAttribute("flare-count") or 0 do
        local f = self:GetFrameRef("b" .. i)
        if f and f:IsVisible() then any = true break end
    end
    if not any then return end
    BOUND = true
    for d = 1, 4 do
        local click = self:GetAttribute("flare-click" .. d)
        for k = 1, 2 do
            local key = self:GetAttribute("flare-key" .. d .. "-" .. k)
            if key and click then self:SetBindingClick(true, key, "]] .. PGT.NAV_NAME .. [[", click) end
        end
    end
]]

-- self is the watcher. LB went up (or another bar took over): give the D-pad back.
PGT.HIDE_SNIPPET = [[
    if not BOUND then return end
    BOUND = nil
    self:ClearBindings()
    self:CallMethod("FlareHighlight", 0)
]]

-- self is the nav button, control the watcher, button the direction. SEL is the frame number
-- selected last (or the target's, kept out of combat). Moves along the row (left / right) or column
-- (up / down): the next frame on it, else back to its far end; with no other frame on that line,
-- the nearest frame in that direction, else the next (right / down) or previous (left / up) frame
-- in reading order. The first press with nothing selected takes the top-left frame.
PGT.NAV_SNIPPET = [[
    if not BOUND then return false end
    local dx, dy = 0, 0
    if button == "PadLeft" then dx = -1
    elseif button == "PadRight" then dx = 1
    elseif button == "PadUp" then dy = 1
    elseif button == "PadDown" then dy = -1
    else return false end
    local n = control:GetAttribute("flare-count") or 0
    local cx, cy, corder, tol
    if SEL then
        local f = control:GetFrameRef("b" .. SEL)
        if f and f:IsVisible() then
            local l, b, w, h = f:GetRect()
            if l then
                local s = f:GetEffectiveScale()
                cx, cy = (l + w / 2) * s, (b + h / 2) * s
                tol = (dx ~= 0 and h or w) * s / 2
                corder = -floor(cy + 0.5) * 100000 + cx
            else
                corder = 1000000000000 + SEL
            end
        else
            SEL = nil
        end
    end
    local pick, pickScore, wrapPick, wrapScore, nearPick, nearScore
    local firstPick, firstOrder, lastPick, lastOrder
    local nextPick, nextOrder, prevPick, prevOrder
    for i = 1, n do
        local f = control:GetFrameRef("b" .. i)
        if i ~= SEL and f and f:IsVisible() then
            local unit = f:GetAttribute("unit")
            if unit and UnitExists(unit) then
                local l, b, w, h = f:GetRect()
                local x, y, order
                if l then
                    local s = f:GetEffectiveScale()
                    x, y = (l + w / 2) * s, (b + h / 2) * s
                    order = -floor(y + 0.5) * 100000 + x
                else
                    order = 1000000000000 + i
                end
                if not firstOrder or order < firstOrder then firstPick, firstOrder = i, order end
                if not lastOrder or order > lastOrder then lastPick, lastOrder = i, order end
                if corder then
                    if order > corder and (not nextOrder or order < nextOrder) then nextPick, nextOrder = i, order end
                    if order < corder and (not prevOrder or order > prevOrder) then prevPick, prevOrder = i, order end
                end
                if cx and x then
                    local px, py = x - cx, y - cy
                    local along = px * dx + py * dy
                    local across = abs(px * dy) + abs(py * dx)
                    if across < tol then
                        if along > 1 and (not pickScore or along < pickScore) then pick, pickScore = i, along end
                        if along < -1 and (not wrapScore or along < wrapScore) then wrapPick, wrapScore = i, along end
                    elseif along > 1 then
                        local score = along + across * 2
                        if not nearScore or score < nearScore then nearPick, nearScore = i, score end
                    end
                end
            end
        end
    end
    local r = pick or wrapPick or nearPick
    if not r then
        if not corder then
            r = firstPick
        elseif dx > 0 or dy < 0 then
            r = nextPick or firstPick
        else
            r = prevPick or lastPick
        end
    end
    if not r then return false end
    SEL = r
    self:SetAttribute("unit", control:GetFrameRef("b" .. r):GetAttribute("unit"))
    control:CallMethod("FlareHighlight", r)
    return "LeftButton"
]]

--------------------------------------------------
-- HIGHLIGHT (a plain frame over the selected FlareUI frame, while LB is held)
--------------------------------------------------
function PGT.CreateHighlight()
    local hl = CreateFrame("Frame", nil, UIParent)
    hl:SetFrameStrata("MEDIUM")
    hl:EnableMouse(false)
    hl:Hide()
    local r, g, b, a = unpack(PGT.HIGHLIGHT_COLOR)
    local size = PGT.HIGHLIGHT_SIZE
    -- a dark line along the inside of the coloured edge keeps it readable on any frame colour
    for _, layer in ipairs({ { 0, 0, 0, 0.9, size + 1, "BACKGROUND" }, { r, g, b, a, size, "ARTWORK" } }) do
        local t = layer[5]
        local top = hl:CreateTexture(nil, layer[6])
        top:SetColorTexture(layer[1], layer[2], layer[3], layer[4])
        top:SetPoint("TOPLEFT")
        top:SetPoint("TOPRIGHT")
        top:SetHeight(t)
        local bottom = hl:CreateTexture(nil, layer[6])
        bottom:SetColorTexture(layer[1], layer[2], layer[3], layer[4])
        bottom:SetPoint("BOTTOMLEFT")
        bottom:SetPoint("BOTTOMRIGHT")
        bottom:SetHeight(t)
        local left = hl:CreateTexture(nil, layer[6])
        left:SetColorTexture(layer[1], layer[2], layer[3], layer[4])
        left:SetPoint("TOPLEFT")
        left:SetPoint("BOTTOMLEFT")
        left:SetWidth(t)
        local right = hl:CreateTexture(nil, layer[6])
        right:SetColorTexture(layer[1], layer[2], layer[3], layer[4])
        right:SetPoint("TOPRIGHT")
        right:SetPoint("BOTTOMRIGHT")
        right:SetWidth(t)
    end
    PGT.highlight = hl
    return hl
end

-- index 0 / nil hides it
function PGT.ShowHighlight(index)
    local hl = PGT.highlight
    if not hl then return end
    local f = index and PGT.buttons[index]
    if not (f and f:IsVisible()) then
        hl.owner = nil
        hl:Hide()
        return
    end
    hl.owner = f
    hl:ClearAllPoints()
    hl:SetPoint("TOPLEFT", f, "TOPLEFT", -1, 1)
    hl:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 1, -1)
    hl:SetFrameLevel(f:GetFrameLevel() + 30)
    hl:Show()
end

function PGT.HideHighlight()
    PGT.ShowHighlight(nil)
end

--------------------------------------------------
-- STATE (attributes and frame refs change out of combat only; queued for its end otherwise)
--------------------------------------------------
-- Party and raid frames register their unit buttons here (not pets, targets or the main tanks)
function PGT.Add(button)
    if not button or PGT.known[button] then return end
    PGT.known[button] = true
    PGT.buttons[#PGT.buttons + 1] = button
    -- a member leaving hides the frame: the highlight goes with it
    button:HookScript("OnHide", function(self)
        if PGT.highlight and PGT.highlight.owner == self then PGT.HideHighlight() end
    end)
    PGT.Sync()
end

-- the D-pad keys of the Friendly Targeting bar's four group directions
function PGT.UpdateKeys()
    local w = PGT.watcher
    if not w then return end
    local swap = C_CVar.GetCVarBool("GamepadSwapFriendlyTargetActions")
    for d, info in ipairs(PGT.DIRECTIONS) do
        local action = "GAMEPADACTIONBUTTON" .. (info.slot + (swap and 4 or 0))
        local k1, k2
        local ctx = C_KeyBindings and C_KeyBindings.GetBindingContextForAction
            and C_KeyBindings.GetBindingContextForAction(action)
        if ctx then
            local ok, a, b = pcall(GetBindingKey, action, nil, ctx)
            if ok then k1, k2 = a, b end
        end
        if not k1 then k1, k2 = GetBindingKey(action, 1) end
        if not k1 then k1, k2 = swap and info.face or info.dpad, nil end
        if k2 == k1 then k2 = nil end
        w:SetAttribute("flare-click" .. d, info.click)
        w:SetAttribute("flare-key" .. d .. "-1", k1)
        w:SetAttribute("flare-key" .. d .. "-2", k2)
    end
end

-- frame refs for new buttons, the on switch and Blizzard's Party Targeting option
function PGT.Sync()
    local w = PGT.watcher
    if not w then return end
    if InCombatLockdown() then PGT.dirty = true return end
    PGT.dirty = nil
    for i = PGT.refCount + 1, #PGT.buttons do
        SecureHandlerSetFrameRef(w, "b" .. i, PGT.buttons[i])
    end
    PGT.refCount = #PGT.buttons
    w:SetAttribute("flare-count", PGT.refCount)
    w:SetAttribute("flare-on", PGT.refCount > 0)
    w:SetAttribute("flare-direct", C_CVar.GetCVarBool("GamepadUsePartyTargeting") and true or false)
    if not PGT.bound then PGT.UpdateKeys() end
    PGT.SyncStart()
end

-- Out of combat the first D-pad press starts from the current target's frame, as Blizzard's does;
-- in combat it starts from the frame selected last
function PGT.SyncStart()
    local w = PGT.watcher
    if not w or InCombatLockdown() then return end
    local start
    if UnitExists("target") then
        for i = 1, PGT.refCount do
            local f = PGT.buttons[i]
            local unit = f:IsVisible() and f:GetAttribute("unit")
            if unit then
                local same = UnitIsUnit(unit, "target")
                if canaccessvalue(same) and same then start = i break end
            end
        end
    end
    SecureHandlerExecute(w, start and ("SEL = " .. start) or "SEL = nil")
end

--------------------------------------------------
-- SETUP
--------------------------------------------------
function PGT.Wanted()
    return ns.IsGamepadUI and ns.IsGamepadUI() and not (ns.OtherControllerAddon and ns.OtherControllerAddon())
end

function PGT.Setup()
    if PGT.watcher or not PGT.Wanted() then return end
    if InCombatLockdown() then PGT.setupPending = true return end
    PGT.setupPending = nil
    local main = _G.GamepadMainActionBarFrame
    local bar = main and main.PageUnit and main.PageUnit.FriendlyTargetingActionBar
    if not bar then return end

    -- shown and hidden with the bar
    local w = CreateFrame("Frame", "FlareUIPadGroupWatch", bar, "SecureHandlerShowHideTemplate")
    w:SetSize(1, 1)
    w:SetPoint("CENTER")
    w:EnableMouse(false)
    w.smartNavigationIgnored = true
    w.FlareHighlight = function(_, index) PGT.ShowHighlight(index) end
    w.FlareBound = function(_, on) PGT.bound = on end
    w:SetAttribute("_onshow", PGT.SHOW_SNIPPET .. [[ if BOUND then self:CallMethod("FlareBound", true) end ]])
    w:SetAttribute("_onhide", [[ self:CallMethod("FlareBound", false) ]] .. PGT.HIDE_SNIPPET)
    PGT.watcher = w

    -- the D-pad clicks this while bound; parked off screen, a binding click needs no visible button
    local nav = CreateFrame("Button", PGT.NAV_NAME, UIParent, "SecureActionButtonTemplate")
    nav:SetSize(1, 1)
    nav:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -500, 500)
    nav:RegisterForClicks("AnyDown")
    nav:SetAttribute("type", "target")
    nav:SetAttribute("useOnKeyDown", true)
    nav:SetAttribute("pressAndHoldAction", false)
    SecureHandlerWrapScript(nav, "OnClick", w, PGT.NAV_SNIPPET)
    PGT.nav = nav

    PGT.CreateHighlight()
    PGT.Sync()
end

PGT.events = CreateFrame("Frame")
PGT.events:SetScript("OnEvent", function(_, event, arg1)
    -- (11-23, Taylor: LB + D-pad did nothing) set up at login only, it missed a Gamepad UI that comes on
    -- later (a controller picked up after logging in): it tries again on every switch into it and
    -- after each loading screen
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        PGT.Setup()
    elseif event == "INPUT_DEVICE_INTERFACE_TRANSITION" then
        -- (once the game has switched: ns.IsGamepadUI reads the new state)
        C_Timer.After(0, PGT.Setup)
    elseif event == "PLAYER_REGEN_ENABLED" then
        if PGT.setupPending then PGT.Setup() end
        if PGT.dirty or PGT.keysDirty then
            PGT.keysDirty = nil
            PGT.Sync()
        else
            PGT.SyncStart()
        end
    elseif not PGT.watcher then
        return
    elseif event == "GROUP_ROSTER_UPDATE" then
        PGT.HideHighlight()
        PGT.SyncStart()
    elseif event == "PLAYER_TARGET_CHANGED" then
        PGT.SyncStart()
    elseif event == "UPDATE_BINDINGS" then
        -- override bindings fire this too: only a change made while the D-pad is free counts
        if PGT.bound then return end
        if InCombatLockdown() then PGT.keysDirty = true else PGT.UpdateKeys() end
    elseif event == "CVAR_UPDATE" then
        if arg1 == "GamepadSwapFriendlyTargetActions" or arg1 == "GamepadUsePartyTargeting" then
            PGT.Sync()
        end
    end
end)
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "INPUT_DEVICE_INTERFACE_TRANSITION", "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE",
    "PLAYER_TARGET_CHANGED", "UPDATE_BINDINGS", "CVAR_UPDATE" }) do
    pcall(PGT.events.RegisterEvent, PGT.events, event)
end
