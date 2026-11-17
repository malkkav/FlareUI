local _, ns = ...
local L = ns.L

--------------------------------------------------
-- GROUP FINDER EYE
-- With Group Finder Icon on (minimap.finderEye), a small icon on the minimap in place of Blizzard's
-- large queue eye. Square style: above the day/night badge. Round style (11-17): on the circle's bottom-left.
-- Out of a queue, a left-click opens the group finder. In a queue it clicks Blizzard's eye, so both
-- buttons do the same (the battleground scoreboard, your listing...); the eye moves as Blizzard's does,
-- pointing at it shows the queue and a right-click opens Blizzard's queue menu.
-- Blizzard's eye stays where it is, unseen and without the mouse: Edit Mode owns it, and a move or a
-- hide from here would taint Edit Mode. In Edit Mode ours stays; on the round style Blizzard's shows
-- again under it, to be dragged, and ours follows.
--------------------------------------------------

--------------------------------------------------
-- 1. MODULE REGISTRATION
--------------------------------------------------
ns.MinimapEye = ns.MinimapEye or {}
local Eye = ns.MinimapEye

--------------------------------------------------
-- 2. UPVALUES
--------------------------------------------------
local _G = _G
local ipairs, pairs = ipairs, pairs
local hooksecurefunc = hooksecurefunc
local InCombatLockdown = InCombatLockdown
local C_Timer = C_Timer

--------------------------------------------------
-- 3. CONSTANTS
--------------------------------------------------
-- The button as FlareUI's own minimap button (Minimap.lua FlareButton): ground, picture, tracking ring
local BUTTON_SIZE = 31
local GROUND_SIZE = 24
local ICON_SIZE   = 20
local RING_SIZE   = 50
local SUN_GAP     = -4     -- square style: the day/night badge's top to the eye's bottom (11-15, Malkkav: closer; the ring art has empty room)
-- Blizzard's eye picture is 43 wide and its green part about 62 percent of that: at this scale the
-- green part fills ICON_SIZE, and the gray rim falls outside the round mask
local EYE_SCALE = ICON_SIZE / (43 * 0.62)
local ROUND_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
-- The pictures inside the eye: each animation frame holds one texture with the eye drawn in it
local EYE_PICTURES = {
    EyeInitial = "EyeInitialTexture",
    EyeSearchingLoop = "EyeSearchingTexture",
    EyeMouseOver = "EyeMouseOverTexture",
    EyeFoundInitial = "EyeFoundInitialTexture",
    EyeFoundLoop = "EyeFoundLoopTexture",
    EyePokeInitial = "EyePokeInitialTexture",
    EyePokeLoop = "EyePokeLoopTexture",
    EyePokeEnd = "EyePokeEndTexture",
}
-- The eye methods that start an animation from outside; the eye chains the others on its own
local EYE_STARTS = { "StartInitialAnimation", "StartSearchingAnimation", "StartFoundAnimationInit" }

--------------------------------------------------
-- 4. HELPERS
--------------------------------------------------
local function GetDb()
    return ns.db and ns.db.profile and ns.db.profile.minimap
end

local function Wanted()
    local db = GetDb()
    return Eye.initialized and db and db.finderEye and true or false
end

local function Editing()
    return EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()
end

-- Blizzard's eye shows only while there is something to show: a queue, a listing, a battleground
local function InQueue()
    return QueueStatusButton:IsShown()
end

-- A secure button changes only out of combat: in combat, the change waits for its end
local waiting = {}
local combatEnd = CreateFrame("Frame")
combatEnd:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    local due = waiting
    waiting = {}
    for fn in pairs(due) do fn() end
end)
local function CanChange(fn)
    if not InCombatLockdown() then return true end
    waiting[fn] = true
    combatEnd:RegisterEvent("PLAYER_REGEN_ENABLED")
    return false
end

--------------------------------------------------
-- 5. THE BUTTON
--------------------------------------------------
-- A secure button: the game itself clicks its own buttons for it. A click from addon code would mark
-- the group finder as touched by an addon, and the game then blocks posting or unlisting a group.
-- It is made while the addon loads, as a secure button can't be made in combat. Its parent is
-- UIParent and its place is in UIParent's units: a frame a secure button hangs from can't move or
-- hide in combat, and the map moves for node addons' scans (Minimap.lua Scan).
-- (named ^FlareUI: the Addon Button Drawer never adopts it)
local button = CreateFrame("Button", "FlareUIFinderEye", UIParent, "SecureActionButtonTemplate")
button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:Hide()
-- both press and release: a secure button acts on the one ActionButtonUseKeyDown names (on by default)
button:RegisterForClicks("AnyUp", "AnyDown")
-- the micro menu's own button runs the game's checks: a disabled finder, Kiosk mode, Quick Keybind
button:SetAttribute("type1", "click")
button:SetAttribute("clickbutton1", LFDMicroButton)
button:SetAttribute("clickbutton2", QueueStatusButton)

local function NewRoundMask(owner, size)
    local mask = owner:CreateMaskTexture()
    mask:SetTexture(ROUND_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetSize(size, size)
    mask:SetPoint("CENTER", button)
    return mask
end

-- Blizzard's eye picture, cut round; the mask lies on the scaled eye, so its size is in the eye's units
local function MaskEye(eye)
    local size = ICON_SIZE / EYE_SCALE
    eye.texture:AddMaskTexture(NewRoundMask(eye, size))
    for frameKey, textureKey in pairs(EYE_PICTURES) do
        local animationFrame = eye[frameKey]
        animationFrame[textureKey]:AddMaskTexture(NewRoundMask(animationFrame, size))
    end
end

-- the dark ground, Blizzard's eye and the ring on top
local function Dress()
    local ground = button:CreateTexture(nil, "BACKGROUND")
    ground:SetSize(GROUND_SIZE, GROUND_SIZE)
    ground:SetPoint("CENTER")
    ground:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local eye = CreateFrame("Frame", nil, button, "LFGEyeTemplate")
    eye:SetScale(EYE_SCALE)
    eye:SetPoint("CENTER")
    -- the template has its own mouse scripts, and it is larger than the button: it would take the clicks
    eye:EnableMouse(false)
    eye:Show()
    MaskEye(eye)
    -- the animation frames inside the eye sit one level above it, so the ring goes above them
    local front = CreateFrame("Frame", nil, button)
    front:SetAllPoints()
    front:SetFrameLevel(eye:GetFrameLevel() + 2)
    local ring = front:CreateTexture(nil, "OVERLAY")
    ring:SetSize(RING_SIZE, RING_SIZE)
    ring:SetPoint("TOPLEFT")
    -- (11-15, Malkkav: too bright) the gold ring greyed and tinted FlareUI's bronze, as the day/night badge's frame
    -- (11-15, Malkkav: then too dark) the bronze brightened by a third: a greyed texture tinted at
    -- full bronze came out darker than the badge's frame
    ring:SetDesaturated(true)
    local c = ns.BORDER_COLOR
    ring:SetVertexColor(math.min(1, c.r * 1.35), math.min(1, c.g * 1.35), math.min(1, c.b * 1.35))
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.Eye = eye
end
Dress()

-- The game stays the one source of the queue state: this eye repeats what Blizzard's eye is told
local function MirrorGameEye()
    local gameEye, eye = QueueStatusButton.Eye, button.Eye
    for _, name in ipairs(EYE_STARTS) do
        hooksecurefunc(gameEye, name, function() eye[name](eye) end)
    end
    hooksecurefunc(gameEye, "SetStaticMode", function(_, isStatic) eye:SetStaticMode(isStatic) end)
    -- Blizzard's first update may have run before the hooks were in place
    if InQueue() then eye:StartInitialAnimation() end
    eye:SetStaticMode(not InQueue() or gameEye:IsStaticMode())
end

button:SetScript("OnEnter", function(self)
    self.Eye:OnEnter()
    if InQueue() then
        -- where Blizzard's eye puts the queue window
        QueueStatusFrame:ClearAllPoints()
        QueueStatusFrame:SetPoint("RIGHT", self, "LEFT", 0, 28)
        QueueStatusFrame:Show()
    end
    -- (11-15, Malkkav) out of a queue no tooltip: the icon says what it is
end)
-- also on hide: a button that hides under the pointer gets no leave
local function Leave(self)
    self.Eye:OnLeave()
    if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    QueueStatusFrame:Hide()
end
button:SetScript("OnLeave", Leave)
button:SetScript("OnHide", Leave)

--------------------------------------------------
-- 6. PLACE AND STATE
--------------------------------------------------
-- (11-15, Malkkav: Blizzard's behaviour, all of it) in a queue both clicks are Blizzard's eye's own: the
-- left one opens what it opens (the scoreboard in a battleground, your listing, your applications), the
-- right one its queue menu. Out of a queue the left click opens the group finder.
local function SyncRightClick()
    if CanChange(SyncRightClick) then
        local queued = InQueue()
        button:SetAttribute("clickbutton1", queued and QueueStatusButton or LFDMicroButton)
        button:SetAttribute("type2", queued and "click" or nil)
    end
end

-- A frame's centre and top in screen pixels
local function ScreenRect(frame)
    local x, y = frame:GetCenter()
    local top = frame:GetTop()
    if not (x and y and top) then return nil end
    local s = frame:GetEffectiveScale()
    return x * s, y * s, top * s
end

-- Square style: the icon's centre in screen pixels, own = the icon's effective scale. With the sundial:
-- centred on the map's left edge, just above it. Without it (Sundial off, 11-17 Malkkav): on the map's
-- bottom-left corner. Measured from the border's frame, which sits where the map sits but stays still:
-- node addons slide the map under the cursor while they scan (11-15: its own left edge, not the real
-- map's width: farming HUDs resize the real map). Also the Vehicle Exit Icon's base, which stacks above
-- it (MinimapVehicle.lua). STEP: one icon to the next above it, as the eye sits above the badge.
-- (11-17, Malkkav) a few pixels more between the two, and both a few pixels in from the map's edge
Eye.STACK_GAP, Eye.INSET, Eye.SUN_LIFT = 3, 3, 3
Eye.BUTTON_SIZE, Eye.STEP = BUTTON_SIZE, BUTTON_SIZE + SUN_GAP + Eye.STACK_GAP
function Eye.SquareSpot(own)
    local art = ns.Minimap.Frame or Minimap
    local artLeft, artBottom = art:GetLeft(), art:GetBottom()
    if not (artLeft and artBottom) then return nil end
    local s = art:GetEffectiveScale()
    local bag = ns.MinimapBag
    local sunShown = not (bag and bag.SundialShown) or bag.SundialShown()
    local sun = MinimapCluster.DielFrame
    if sunShown and sun then
        local _, _, sunTop = ScreenRect(sun)
        if not sunTop then return nil end
        -- (11-17, Malkkav) a few pixels more above the sundial: the whole stack moves up with it
        return artLeft * s + Eye.INSET * own, sunTop + (SUN_GAP + Eye.SUN_LIFT + BUTTON_SIZE / 2) * own
    end
    return artLeft * s + Eye.INSET * own, artBottom * s + Eye.INSET * own
end

-- (11-17, Malkkav) Round style: the icons sit along the circle's lower left, the Group Finder Icon at
-- its bottom-left (225 degrees), each next one a step further up the edge (n: how many shown icons sit
-- below it), as they stack up the square map's left edge. Centred on the bronze border, a few pixels
-- past the map's edge (11-17, Malkkav: they sat too far inside, then too far out). Roomier than the
-- square stack (ROUND_SPREAD) and a little larger (ROUND_SCALE), so they round the border.
Eye.ROUND_START, Eye.ROUND_OUT, Eye.ROUND_SPREAD, Eye.ROUND_SCALE = 225, 1, 1.35, 1.15
-- the icons' scale: the map's, a little larger on the round map
function Eye.IconScale()
    local scale = Minimap:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if ns.Minimap and ns.Minimap.IsSquare and not ns.Minimap.IsSquare() then scale = scale * Eye.ROUND_SCALE end
    return scale
end
function Eye.RoundSpot(own, n)
    local map = Minimap
    local cx, cy = map:GetCenter()
    local w = map:GetWidth()
    if not (cx and cy and w and w > 0) then return nil end
    local s = map:GetEffectiveScale()
    local r = w / 2 * s + Eye.ROUND_OUT * own
    if r <= 0 then return nil end
    local a = math.rad(Eye.ROUND_START) - (n or 0) * (Eye.STEP * Eye.ROUND_SPREAD * own / r)
    return cx * s + r * math.cos(a), cy * s + r * math.sin(a)
end

-- Square style: Eye.SquareSpot. Round style: Eye.RoundSpot.
local function Place()
    if not CanChange(Place) then return end
    button:SetScale(Eye.IconScale())
    local own = button:GetEffectiveScale()
    local x, y
    if ns.Minimap.IsSquare() then
        x, y = Eye.SquareSpot(own)
    else
        -- (11-15) node addons slide the map while they scan: wait for it to be home, or a moved spot
        -- would be kept
        if ns.Minimap.AfterScan and ns.Minimap.AfterScan("finderEye", Place) then return end
        x, y = Eye.RoundSpot(own, 0)
    end
    if not (x and y) then return end
    button:ClearAllPoints()
    button:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / own, y / own)
end

-- after the map's own layout pass, which places the badge
local function PlaceSoon()
    C_Timer.After(0, Place)
end

-- Faded with the map (Visibility.lua fades MinimapCluster)
local function Fade()
    button:SetAlpha(MinimapCluster:GetAlpha())
end

local function UpdateShown()
    if not CanChange(UpdateShown) then return end
    -- the map too: the Toggle Minimap key hides it and leaves the cluster shown
    -- (11-15, Malkkav) ours shows in Edit Mode too. Round style: it sits on Blizzard's eye, which is the one
    -- dragged there, so ours lets the mouse through and follows it while Edit Mode is open
    -- (11-15, Malkkav, GitHub #57) only while Blizzard's eye would show (a queue, a listing, a
    -- battleground), as Blizzard's; Edit Mode shows it to be placed
    local show = Wanted() and (InQueue() or Editing()) and MinimapCluster:IsShown() and Minimap:IsShown()
    -- (11-17, Malkkav) ours on both styles now: it never follows Blizzard's eye
    local follow = false
    button:SetShown(show)
    button:EnableMouse(not follow)
    Eye.follower = Eye.follower or CreateFrame("Frame")
    Eye.follower:SetScript("OnUpdate", follow and Place or nil)
    if show then
        Fade()
        Place()
    end
end

-- Blizzard's eye: unseen while ours shows, back in Edit Mode or with the option off. (11-15) Only an
-- eye this file took is given back: with the option never on it is left alone, so another addon that
-- fades or hides it keeps its way (quiet defaults)
local eyeTaken = false
local function UpdateGameEye()
    -- (11-15) in Edit Mode Blizzard's eye comes back only on the round style, to be dragged: on the
    -- square style ours sits by the day/night badge and Blizzard's spot means nothing
    -- (11-17, Malkkav) the round style too: ours replaces it everywhere while the option is on
    local seen = not Wanted()
    if seen and not eyeTaken then return end
    eyeTaken = not seen
    QueueStatusButton:SetAlpha(seen and 1 or 0)
    QueueStatusButton:EnableMouse(seen)
    -- (11-17, Malkkav) its Edit Mode box ignores the eye's opacity (ignoreParentAlpha): hidden and
    -- ungrabbable with it, so square-style Edit Mode shows no stray Group Finder box
    local selection = QueueStatusButton.Selection
    if selection then
        selection:SetAlpha(seen and 1 or 0)
        selection:EnableMouse(seen)
        if not Eye.selectionHooked then
            Eye.selectionHooked = true
            local function Keep()
                if eyeTaken then
                    if selection:GetAlpha() ~= 0 then selection:SetAlpha(0) end
                    if selection:IsMouseEnabled() then selection:EnableMouse(false) end
                end
            end
            selection:HookScript("OnShow", Keep)
            hooksecurefunc(selection, "SetAlpha", Keep)
            hooksecurefunc(selection, "EnableMouse", Keep)
        end
    end
    -- Blizzard's one-time tip about the queue eye points at an eye that is no longer seen, and its
    -- invisible box would catch clicks on the map
    if not seen and LE_FRAME_TUTORIAL_HUD_REVAMP_LFG_QUEUE_CHANGES then
        SetCVarBitfield("closedInfoFrames", LE_FRAME_TUTORIAL_HUD_REVAMP_LFG_QUEUE_CHANGES, true)
    end
end

--------------------------------------------------
-- 7. PUBLIC
--------------------------------------------------
-- Settings > Minimap > Group Finder Icon (live)
function Eye.Update()
    -- (11-15) the swap as one: in combat both wait, or Blizzard's eye would go before ours shows
    if not CanChange(Eye.Update) then return end
    UpdateGameEye()
    UpdateShown()
end

-- Settings or Edit Mode changed the map's place or size (Minimap.lua MM:Refresh)
function Eye.Place()
    if button:IsShown() then PlaceSoon() end
end

-- From Minimap.lua MM:Init, after the badge is placed: both styles
function Eye.Init()
    if Eye.initialized or not (QueueStatusButton and QueueStatusButton.Eye and LFDMicroButton) then return end
    Eye.initialized = true
    MirrorGameEye()
    SyncRightClick()
    QueueStatusButton:HookScript("OnShow", SyncRightClick)
    QueueStatusButton:HookScript("OnHide", SyncRightClick)
    -- round style: on Blizzard's eye, whose spot Edit Mode sets; it may have none until it first shows
    QueueStatusButton:HookScript("OnShow", Eye.Place)
    -- ours comes and goes with Blizzard's eye (#57)
    QueueStatusButton:HookScript("OnShow", UpdateShown)
    QueueStatusButton:HookScript("OnHide", UpdateShown)
    EventRegistry:RegisterCallback("EditMode.Enter", Eye.Update)
    EventRegistry:RegisterCallback("EditMode.Exit", Eye.Update)
    MinimapCluster:HookScript("OnShow", UpdateShown)
    MinimapCluster:HookScript("OnHide", UpdateShown)
    Minimap:HookScript("OnShow", UpdateShown)
    Minimap:HookScript("OnHide", UpdateShown)
    hooksecurefunc(MinimapCluster, "SetAlpha", Fade)
    local events = CreateFrame("Frame")
    events:RegisterEvent("UI_SCALE_CHANGED")
    events:RegisterEvent("DISPLAY_SIZE_CHANGED")
    events:SetScript("OnEvent", Eye.Place)
    Eye.Update()
end
