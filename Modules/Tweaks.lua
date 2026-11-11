local _, ns = ...
local L = ns.L

--------------------------------------------------
-- QUALITY OF LIFE (Tweaks)
-- The Quality of Life toggles: windows, Sync Blizz UI, vendor, camera, nameplates, convenience,
-- hiding, /way, plus the always-on party unclamp and Edit Mode layout per input mode. Most apply
-- live; the ones that replace Blizzard scripts need a reload.
--------------------------------------------------

--------------------------------------------------
-- 1. MODULE REGISTRATION
--------------------------------------------------
ns.Tweaks = ns.Tweaks or {}
local Tweaks = ns.Tweaks
ns.modules["Tweaks"] = Tweaks

LibStub("AceEvent-3.0"):Embed(Tweaks)

--------------------------------------------------
-- 2. UPVALUES
--------------------------------------------------
local _G = _G
local ipairs, pairs, type, tostring = ipairs, pairs, type, tostring
local pcall = pcall
local math_floor, math_max, math_min = math.floor, math.max, math.min
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local IsShiftKeyDown, IsControlKeyDown = IsShiftKeyDown, IsControlKeyDown
local C_Timer = C_Timer

local function GetDb()
    return ns.db and ns.db.profile and ns.db.profile.tweaks
end

local function Print(msg)
    print("|cff00ff00FlareUI:|r " .. msg)
end

--------------------------------------------------
-- 3. MOVE ANY FRAME
-- Every UIPanelWindows panel (plus bags and a few other windows) drags by its header; Ctrl+wheel
-- scales, Shift+right-click resets the position, Ctrl+right-click the scale. Saved per frame name,
-- re-applied after Blizzard's panel manager places the frame.
--------------------------------------------------
local MIN_SCALE, MAX_SCALE, SCALE_STEP = 0.5, 2.0, 0.1
-- panels that must stay where Blizzard puts them
local MOVE_EXCLUDED = {
    EditModeManagerFrame = true, GameMenuFrame = true, SettingsPanel = true, HelpFrame = true,
    ChatConfigFrame = true, StaticPopup1 = true,
    LootFrame = true,   -- an Edit Mode system: Edit Mode moves it
}
local moveFrames = {}          -- name -> frame (already set up)
local moveApplyQueued = false
local moveDragWatch            -- watches the cursor between a press on a title bar and the first movement
local movePending = {}         -- frames whose saved position must be applied after combat
local setupPending = {}        -- protected windows that loaded in combat: set up when it ends
local moveSuspended = false    -- the gamepad UI came on mid-session; see StartMoveAnyFrame

local function GetFrameStore(name, create)
    local db = GetDb()
    if not db then return nil end
    db.frames = db.frames or {}
    if create and not db.frames[name] then db.frames[name] = {} end
    return db.frames[name]
end

local function CanTouch(frame)
    return not (InCombatLockdown() and frame:IsProtected())
end

-- A maximized world map stays where Blizzard puts it
local function IsMaximized(frame)
    return frame.IsMaximized and frame:IsMaximized() and true or false
end

local function ApplySavedPosition(frame)
    if moveSuspended or IsMaximized(frame) then return end
    local store = GetFrameStore(frame.moveName)
    if not store then return end
    if not CanTouch(frame) then movePending[frame] = true return end
    if store.scale and frame:GetScale() ~= store.scale then
        frame:SetScale(store.scale)
    end
    if store.point then
        frame:ClearAllPoints()
        frame:SetPoint(store.point, UIParent, store.relativePoint or "BOTTOMLEFT", store.x or 0, store.y or 0)
    end
end

local function ApplyAll()
    if moveSuspended then return end
    for _, frame in pairs(moveFrames) do
        if frame:IsShown() then ApplySavedPosition(frame) end
    end
end

-- Once more on the next frame, for anything that re-anchors a window after the hooks ran
local function QueueApplyAll()
    if moveApplyQueued or moveSuspended then return end
    moveApplyQueued = true
    C_Timer.After(0, function()
        moveApplyQueued = false
        ApplyAll()
    end)
end

-- Right after Blizzard places the windows, so a moved one never shows at Blizzard's spot first
local function ApplyAllNowAndNext()
    ApplyAll()
    QueueApplyAll()
end

local function SavePosition(frame)
    local store = GetFrameStore(frame.moveName, true)
    if not store then return end
    local left, top = frame:GetLeft(), frame:GetTop()
    if not (left and top) then return end
    store.point, store.relativePoint = "TOPLEFT", "BOTTOMLEFT"
    store.x, store.y = math_floor(left + 0.5), math_floor(top + 0.5)
end

local function ResetPosition(frame)
    local store = GetFrameStore(frame.moveName)
    if store then store.point, store.relativePoint, store.x, store.y = nil, nil, nil, nil end
    if CanTouch(frame) and UpdateUIPanelPositions then pcall(UpdateUIPanelPositions, frame) end
end

local function SetFrameScale(frame, scale)
    scale = math_max(MIN_SCALE, math_min(MAX_SCALE, math_floor(scale * 100 + 0.5) / 100))
    if not CanTouch(frame) then return end
    -- the top-left corner stays put
    local left, top = frame:GetLeft(), frame:GetTop()
    local oldScale = frame:GetScale()
    frame:SetScale(scale)
    if left and top then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * oldScale / scale, top * oldScale / scale)
    end
    local store = GetFrameStore(frame.moveName, true)
    if store then
        store.scale = scale ~= 1 and scale or nil
        SavePosition(frame)
    end
end

local function OnDragStart(handle)
    local frame = handle.moveTarget or handle
    moveDragWatch:Hide()
    if frame.moveDragging or not CanTouch(frame) or IsMaximized(frame) then return end
    frame:SetMovable(true)
    frame:StartMoving()
    frame.moveDragging = true
    handle.bagDragged = true   -- a bag's portrait: this was a drag, not a click for its menu
end

-- The client only reports a drag after the cursor has gone several pixels, which felt like a dead zone:
-- the move starts on the first pixel instead. A click without movement leaves the window alone.
moveDragWatch = CreateFrame("Frame")
moveDragWatch:Hide()
moveDragWatch:SetScript("OnUpdate", function(self)
    if not IsMouseButtonDown("LeftButton") then
        self:Hide()
        return
    end
    local x, y = GetCursorPosition()
    if x ~= self.x or y ~= self.y then OnDragStart(self.handle) end
end)

local function OnMouseDown(handle, button)
    if button ~= "LeftButton" then return end
    moveDragWatch.handle = handle
    moveDragWatch.x, moveDragWatch.y = GetCursorPosition()
    moveDragWatch:Show()
end

local function OnDragStop(handle)
    local frame = handle.moveTarget or handle
    moveDragWatch:Hide()
    if not frame.moveDragging then return end
    frame.moveDragging = false
    frame:StopMovingOrSizing()
    SavePosition(frame)
end

local function OnMouseWheel(handle, delta)
    if not IsControlKeyDown() then return end
    local frame = handle.moveTarget or handle
    if IsMaximized(frame) then return end
    SetFrameScale(frame, frame:GetScale() + SCALE_STEP * delta)
end

-- A bag window's portrait menu (Assign To, Ignore This Bag, sorting): opens, or closes when open
local function ToggleBagMenu(frame)
    local dropdown = frame.PortraitButton
    if not (dropdown and dropdown.OpenMenu) then return end
    if dropdown.IsMenuOpen and dropdown:IsMenuOpen() then
        pcall(dropdown.CloseMenu, dropdown)
    else
        pcall(dropdown.OpenMenu, dropdown)
    end
end

local function OnMouseUp(handle, button)
    if button == "LeftButton" then OnDragStop(handle) end
    if button ~= "RightButton" then return end
    local frame = handle.moveTarget or handle
    if IsShiftKeyDown() then ResetPosition(frame) end
    if IsControlKeyDown() and CanTouch(frame) then
        local store = GetFrameStore(frame.moveName)
        if store then store.scale = nil end
        frame:SetScale(1)
        -- a window that was never moved stays where Blizzard's panel layout puts it
        if store and store.point then SavePosition(frame) end
    end
    -- a plain right-click anywhere on a bag window opens its sorting menu
    if not IsShiftKeyDown() and not IsControlKeyDown() then ToggleBagMenu(frame) end
end

-- Only the header drags: a mouse-enabled window would swallow every click inside it
local HEADER_HEIGHT = 26
local CLOSE_BUTTON_ROOM = 40
-- A title bar takes the mouse here, level with the close and maximize buttons, and on a window that hides
-- its portrait it runs the whole width over them: its right end stays clear of clicks.
local TITLE_BUTTONS_ROOM = 60

local function SetupHandle(frame, handle)
    if not handle or handle.moveHooked then return end
    handle.moveHooked = true
    handle.moveTarget = frame
    if handle.EnableMouse then handle:EnableMouse(true) end
    if handle.RegisterForDrag then handle:RegisterForDrag("LeftButton") end
    if handle ~= frame.moveStrip and handle.SetHitRectInsets then handle:SetHitRectInsets(0, TITLE_BUTTONS_ROOM, 0, 0) end
    handle:HookScript("OnMouseDown", OnMouseDown)
    handle:HookScript("OnDragStart", OnDragStart)
    handle:HookScript("OnDragStop", OnDragStop)
    handle:HookScript("OnMouseUp", OnMouseUp)
end

-- Ctrl+wheel scales from anywhere over the window (scroll frames keep their own wheel). A window
-- without a wheel of its own takes it only while Ctrl is down, so a plain wheel still zooms the camera.
local wheelOnCtrl = {}
local wheelWatcher

local function UpdateWheels()
    local ctrl = IsControlKeyDown()
    for frame in pairs(wheelOnCtrl) do
        if CanTouch(frame) then frame:EnableMouseWheel(ctrl) end
    end
end

local function SetupWheel(frame, target)
    if frame.moveWheelHooked or not frame.EnableMouseWheel then return end
    frame.moveWheelHooked = true
    frame.moveTarget = target or frame
    frame:HookScript("OnMouseWheel", OnMouseWheel)
    if frame:IsMouseWheelEnabled() then return end
    wheelOnCtrl[frame] = true
    if not wheelWatcher then
        wheelWatcher = CreateFrame("Frame")
        wheelWatcher:RegisterEvent("MODIFIER_STATE_CHANGED")
        wheelWatcher:SetScript("OnEvent", function(_, _, key)
            if key == "LCTRL" or key == "RCTRL" then UpdateWheels() end
        end)
    end
end

-- The title bar if the frame has one, otherwise a strip across the top short of the close button
local function GetHeaderHandle(frame)
    if frame.TitleContainer then return frame.TitleContainer end
    local border = frame.BorderFrame
    if type(border) == "table" and border.TitleContainer then return border.TitleContainer end
    if frame.moveStrip then return frame.moveStrip end
    local strip = CreateFrame("Frame", nil, frame)
    strip:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    strip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -CLOSE_BUTTON_ROOM, 0)
    strip:SetHeight(HEADER_HEIGHT)
    -- above the window itself: at its level the window (mouse-enabled) would take the press
    strip:SetFrameLevel(frame:GetFrameLevel() + 2)
    frame.moveStrip = strip
    return strip
end

local function SetupMovableFrame(name)
    if moveSuspended or moveFrames[name] or MOVE_EXCLUDED[name] then return end
    -- OpenMap places and scales the map itself, and puts it back whenever anything else changes it
    if name == "WorldMapFrame" and C_AddOns.IsAddOnLoaded("OpenMap") then return end
    local frame = _G[name]
    if type(frame) ~= "table" or not frame.GetObjectType or not frame.StartMoving then return end
    -- a forbidden window (the shop) can't be touched at all
    if frame.IsForbidden and frame:IsForbidden() then return end
    -- a protected window (the spellbook) loaded in combat is set up after it (SetMovable is blocked)
    if InCombatLockdown() and frame:IsProtected() then
        setupPending[name] = true
        return
    end
    setupPending[name] = nil
    frame.moveName = name
    moveFrames[name] = frame
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    SetupHandle(frame, GetHeaderHandle(frame))
    SetupWheel(frame)
    -- the panel manager has placed the window by OnShow: the saved position goes back before it draws
    frame:HookScript("OnShow", function(f)
        ApplySavedPosition(f)
        C_Timer.After(0, function() ApplySavedPosition(f) end)
    end)
    if frame:IsShown() then ApplySavedPosition(frame) end
    -- a window that closes while it is dragged (walked out of range) never hears the mouse-up: the drag
    -- ends here, where it was let go, so the next drag works
    frame:HookScript("OnHide", function(f)
        if not f.moveDragging then return end
        if InCombatLockdown() and f:IsProtected() then
            f.moveDragging = false
            return
        end
        OnDragStop(f)
    end)
end

-- windows Blizzard shows without registering them as panels (the clock, opened mail, the stable,
-- loot history, the group finder, the dressing preview): each one once it exists
local EXTRA_WINDOWS = {
    "TimeManagerFrame", "OpenMailFrame", "StableFrame", "PetStableFrame", "GroupLootHistoryFrame",
    "LFGParentFrame", "ModelPreviewFrame", "CinematicsMenu", "CooldownViewerSettings",
}

-- The group finder's pages fill its window and hold the only title bar, so they move the window. Moved
-- on their own they would come apart from it and its tabs.
local LFG_PAGES = { "LFGBrowseFrame", "LFGListingFrame", "LFGWhoListFrame" }

local function SetupLFGPages()
    local parent = moveFrames.LFGParentFrame
    if not parent then return end
    for _, name in ipairs(LFG_PAGES) do
        local page = _G[name]
        if type(page) == "table" and page.TitleContainer then
            SetupHandle(parent, page.TitleContainer)
            SetupWheel(page, parent)
        end
    end
end

-- Saved positions that must not be applied: the group finder pages belong inside their window, and
-- the loot window is an Edit Mode system (moving it from addon code taints Edit Mode)
local function ForgetLFGPagePositions()
    local db = GetDb()
    if not (db and db.frames) then return end
    for _, name in ipairs(LFG_PAGES) do db.frames[name] = nil end
    db.frames.LootFrame = nil
end

-- The client also remembers a dragged frame by name (layout-local.txt, per character) and puts it back
-- at login. A page found away from its window returns to it, and the client forgets its place.
local function ReattachLFGPage(page)
    local parent = _G.LFGParentFrame
    if not parent or not CanTouch(page) then return end
    local _, relativeTo = page:GetPoint(1)
    if relativeTo == parent and not page:IsUserPlaced() then return end
    local movable = page:IsMovable()
    page:SetMovable(true)   -- the client only takes this from a movable frame
    page:SetUserPlaced(false)
    page:SetMovable(movable)
    page:ClearAllPoints()
    page:SetAllPoints(parent)
end

-- Whether Move Any Frame is on or not: a page dragged while it was on stays detached after it goes off
local function KeepLFGPagesAttached()
    EventUtil.ContinueOnAddOnLoaded("Blizzard_GroupFinder_VanillaStyle", function()
        for _, name in ipairs(LFG_PAGES) do
            local page = _G[name]
            if type(page) == "table" and page.HookScript then
                page:HookScript("OnShow", ReattachLFGPage)
                ReattachLFGPage(page)
            end
        end
    end)
end

local function ScanUIPanels()
    local windows = _G.UIPanelWindows
    if type(windows) == "table" then
        for name in pairs(windows) do SetupMovableFrame(name) end
    end
    for _, name in ipairs(EXTRA_WINDOWS) do SetupMovableFrame(name) end
    SetupLFGPages()
end

-- A bag's portrait router covers the title bar and opens the menu on mouse down, which would
-- swallow the drag; it becomes the drag handle instead, opening the menu on a click without a drag.
local function BagRouterMouseDown(router)
    router.bagDragged = nil
end

local function BagRouterDragStart(router)
    router.bagDragged = true
    local dropdown = router.moveTarget and router.moveTarget.PortraitButton
    if dropdown and dropdown.IsMenuOpen and dropdown:IsMenuOpen() then pcall(dropdown.CloseMenu, dropdown) end
end

local function BagRouterMouseUp(router, button)
    if button ~= "LeftButton" or router.bagDragged then return end
    if router:IsMouseOver() then ToggleBagMenu(router.moveTarget) end
end

-- Right-click on the portrait opens the menu too, as it does on the title
local function BagPortraitMouseUp(portrait, button)
    if button == "RightButton" and portrait:IsMouseOver() then ToggleBagMenu(portrait:GetParent()) end
end

local function SetupBagTitle(frame)
    if frame.bagRouterFixed then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        if child.routeToSibling == "PortraitButton" and child.SetScript then
            child:SetScript("OnMouseDown", BagRouterMouseDown)
            SetupHandle(frame, child)
            child:HookScript("OnDragStart", BagRouterDragStart)
            child:HookScript("OnMouseUp", BagRouterMouseUp)
            frame.bagRouterFixed = true
        end
    end
    if not frame.bagRouterFixed then return end
    -- the title strip Move Any Frame set up lies over the router, which is the handle instead
    local title = frame.TitleContainer
    if title and title.EnableMouse then title:EnableMouse(false) end
    local portrait = frame.PortraitButton
    if portrait and portrait.HookScript and not portrait.FlareUI_RightHooked then
        portrait.FlareUI_RightHooked = true
        portrait:HookScript("OnMouseUp", BagPortraitMouseUp)
    end
end

-- The bag header's "Backpack / <click for bag settings>" tooltip, from the portrait (the title's
-- router shows it too): always hidden
local function HideBagTooltip(region)
    local portrait = region.routeToSibling and region:GetParent()[region.routeToSibling] or region
    if GameTooltip:IsOwned(portrait) then GameTooltip:Hide() end
end

-- index 0 is the combined bag, 1-13 the single bag windows
local function InitBagTooltip()
    for i = 0, 13 do
        local frame = _G[i == 0 and "ContainerFrameCombinedBags" or "ContainerFrame" .. i]
        if type(frame) == "table" and frame.GetChildren then
            if frame.PortraitButton and frame.PortraitButton.HookScript then
                frame.PortraitButton:HookScript("OnEnter", HideBagTooltip)
            end
            for _, child in ipairs({ frame:GetChildren() }) do
                if child.routeToSibling == "PortraitButton" and child.HookScript then
                    child:HookScript("OnEnter", HideBagTooltip)
                end
            end
        end
    end
end

-- runs on every bag update, so no list is built
local function ScanBagFrames()
    for i = 0, 13 do
        local name = i == 0 and "ContainerFrameCombinedBags" or "ContainerFrame" .. i
        SetupMovableFrame(name)
        local frame = moveFrames[name]
        if frame then SetupBagTitle(frame) end
    end
end

local function InitMoveAnyFrame()
    ForgetLFGPagePositions()
    ScanUIPanels()
    ScanBagFrames()
    -- load-on-demand panels register themselves when their addon loads
    Tweaks:RegisterEvent("ADDON_LOADED", function() C_Timer.After(0, ScanUIPanels) end)
    -- Blizzard's panel manager re-anchors panels as they open / close; saved positions go back after
    hooksecurefunc("UpdateUIPanelPositions", ApplyAllNowAndNext)
    -- bags re-anchor (and re-scale) themselves every time they open or the layout changes
    hooksecurefunc("UpdateContainerFrameAnchors", function() ScanBagFrames() ApplyAllNowAndNext() end)
    Tweaks:RegisterEvent("BAG_UPDATE_DELAYED", ScanBagFrames)
    Tweaks:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if next(setupPending) then
            for name in pairs(setupPending) do SetupMovableFrame(name) end
            ScanBagFrames()   -- a bag window set up late still needs its title bar
        end
        for frame in pairs(movePending) do movePending[frame] = nil; if frame:IsShown() then ApplySavedPosition(frame) end end
    end)
end

-- The Gamepad UI trips over this feature (taint, client freezes), and hooks cannot be undone, so it
-- only starts in keyboard mode. A switch to the Gamepad UI suspends it until the switch back.
local moveStarted = false

local function OnInterfaceTransition()
    if ns.IsGamepadUI() then
        if moveStarted and not moveSuspended then
            moveSuspended = true
        end
    else
        moveSuspended = false
        if moveStarted then
            QueueApplyAll()
        else
            moveStarted = true
            InitMoveAnyFrame()
        end
    end
end

local function StartMoveAnyFrame()
    local listener = CreateFrame("Frame")
    listener:RegisterEvent("INPUT_DEVICE_INTERFACE_TRANSITION")
    listener:SetScript("OnEvent", OnInterfaceTransition)
    OnInterfaceTransition()
end

--------------------------------------------------
-- 4. SYNC BLIZZ UI
-- The source character's per-character Blizzard settings (CVars, Edit Mode layout by name, chat
-- windows, bag flags...) are kept account-wide (db.global.uiSync), saved on logout and after
-- changes, and applied at login to every other character once per snapshot. The source is named
-- by GUID.
--------------------------------------------------
local SYNC_CVARS = ns.SYNC_CVARS or {}   -- filled in Modules/TweaksCVars.lua
local syncSaveTimer

-- These drift with play (camera distance, windows left open): copied, but no reason to ask for a reload
Tweaks.SYNC_NO_RELOAD = {
    cameraSavedDistance = true, cameraSavedPitch = true, cameraSavedVehicleDistance = true,
    cameraSavedPetBattleDistance = true, minimapZoom = true, minimapInsideZoom = true,
    questLogOpen = true, miniWorldMap = true, characterFrameCollapsed = true, closedInfoFrames = true,
    friendsSmallView = true, friendsViewButtons = true, guildRosterView = true,
    miniCommunitiesFrame = true, miniDressUpFrame = true,
}

-- AceEvent keeps one callback per object per event, so the sync has its own object
local SyncEvents = {}
LibStub("AceEvent-3.0"):Embed(SyncEvents)

-- The logged-in character as a source record: the GUID identifies it, the rest is for display.
local function Me()
    local guid, name = ns.PlayerGUID(), UnitName("player")
    if not (guid and name) then return nil end
    local _, class = UnitClass("player")
    -- full: first and second name, for the options' label (11-10)
    local _, surname = UnitName("player")
    local full = (type(surname) == "string" and surname ~= "") and (name .. " " .. surname) or name
    return { guid = guid, name = name, full = full, realm = GetRealmName(), class = class }
end

local function IsSource(store)
    local source, guid = store and store.source, ns.PlayerGUID()
    return type(source) == "table" and guid ~= nil and source.guid == guid
end

-- the character's name for display (first and second name; no realm, 11-10 Marcus)
local function SourceLabel(source)
    if type(source) ~= "table" then return nil end
    return source.full or source.name or "?"
end

local function GetSyncStore()
    if not ns.db or not ns.db.global then return nil end
    local store = ns.db.global.uiSync or {}
    ns.db.global.uiSync = store
    return store
end

local function CVarKnown(name)
    local ok, value = pcall(C_CVar.GetCVarInfo, name)
    return ok and value ~= nil
end

local function SaveSync()
    local db = GetDb()
    if not (db and db.syncUI) or InCombatLockdown() then return end
    local account = GetSyncStore()
    if not account then return end
    if Tweaks.syncLoading then return end

    -- only the source writes; with no source yet, the first character to save becomes it
    if not account.source then account.source = Me() end
    if not IsSource(account) then return end
    account.snapshot = account.snapshot or {}
    local store = account.snapshot

    -- CVars
    store.cvars = {}
    for _, name in ipairs(SYNC_CVARS) do
        if CVarKnown(name) then
            local ok, value = pcall(GetCVar, name)
            if ok and value ~= nil then store.cvars[name] = value end
        end
    end
    -- Enemy Nameplates in Combat Only holds the CVar at 0 out of combat: the player's own value travels
    local forced = ns.db.global and Tweaks.ForcedCVars("combatPlates")
    if forced and forced.combatPlates ~= nil and store.cvars.nameplateShowEnemies ~= nil then
        store.cvars.nameplateShowEnemies = forced.combatPlates
    end

    -- Edit Mode layout, by name and kind, from the manager's presets-then-saved list (the only place
    -- where the active index and the names agree)
    local manager = EditModeManagerFrame
    if manager and manager.GetActiveLayoutInfo then
        local ok, active = pcall(manager.GetActiveLayoutInfo, manager)
        if ok and type(active) == "table" then
            store.editModeLayout = active.layoutName
            store.editModeLayoutType = active.layoutType
        end
    end

    -- Chat windows
    store.chat = {}
    for i = 1, Constants.ChatFrameConstants.MaxChatWindows do
        local name, size, r, g, b, a, shown, locked, docked, uninteractable = GetChatWindowInfo(i)
        local point, x, y = GetChatWindowSavedPosition(i)
        local width, height = GetChatWindowSavedDimensions(i)
        store.chat[i] = {
            name = name, size = size, r = r, g = g, b = b, a = a,
            shown = shown, locked = locked, docked = docked, uninteractable = uninteractable,
            point = point, x = x, y = y, width = width, height = height,
            messages = { GetChatWindowMessages(i) },
            channels = { GetChatWindowChannels(i) },
        }
    end

    -- Bag flags
    store.bags = {
        sortRightToLeft = C_Container.GetSortBagsRightToLeft(),
        insertLeftToRight = C_Container.GetInsertItemsLeftToRight(),
        bankAutosortDisabled = C_Container.GetBankAutosortDisabled(),
        backpackSellJunkDisabled = C_Container.GetBackpackSellJunkDisabled(),
        backpackAutosortDisabled = C_Container.GetBackpackAutosortDisabled(),
    }

    -- each bag slot's flags (Assign To, Ignore This Bag, junk selling), slot onto slot
    store.bagFlags = {}
    for bag = 1, NUM_BAG_SLOTS do
        local flags = {}
        for _, flag in pairs(Enum.BagSlotFlags) do
            local ok, set = pcall(C_Container.GetBagSlotFlag, bag, flag)
            if ok and type(set) == "boolean" then flags[flag] = set end
        end
        store.bagFlags[bag] = flags
    end

    -- Social > Block Guild Invites. Server-side, per character.
    local okDecline, decline = pcall(GetAutoDeclineGuildInvites)
    if okDecline and type(decline) == "boolean" then store.declineGuildInvites = decline end

    -- which action bars show is server state, not a CVar
    store.actionBars = { GetActionBarToggles() }

    -- chat colours per message type, and Color Name by Class (kept in ChatTypeInfo)
    store.chatColors = {}
    store.chatClassNames = {}
    for chatType, info in pairs(ChatTypeInfo) do
        local ok, r, g, b = pcall(GetMessageTypeColor, chatType)
        if ok and r then store.chatColors[chatType] = { r, g, b } end
        if type(info) == "table" and info.colorNameByClass ~= nil then
            store.chatClassNames[chatType] = info.colorNameByClass and true or false
        end
    end

    store.savedAt = GetServerTime()
end

local function QueueSaveSync()
    if syncSaveTimer then syncSaveTimer:Cancel() end
    syncSaveTimer = C_Timer.NewTimer(5, function() syncSaveTimer = nil; SaveSync() end)
end

-- Builder edits use saved chat APIs; capture them for the existing source only.
-- SaveSync keeps the user's sync toggle and source-character ownership intact.
function Tweaks:ChatBuilderChanged()
    SaveSync()
end

-- Copies the source's snapshot onto this character, once per snapshot
local function LoadSync()
    local db = GetDb()
    local account = db and db.syncUI and GetSyncStore()
    if not (account and account.source) or IsSource(account) then return end
    local store = account.snapshot
    if not (store and store.savedAt) then return end
    local charDB = ns.CharDB()
    if charDB.syncApplied == store.savedAt or InCombatLockdown() then return end
    local sourceName = SourceLabel(account.source) or "another character"
    Tweaks.syncLoading = true

    -- CVars
    local changed = 0
    local forced = ns.db.global and Tweaks.ForcedCVars("combatPlates")
    for name, value in pairs(store.cvars or {}) do
        if name == "nameplateShowEnemies" and forced and forced.combatPlates ~= nil then
            -- Enemy Nameplates in Combat Only holds the CVar: the source's value is what comes back later
            forced.combatPlates = tostring(value)
        elseif CVarKnown(name) then
            local ok, current = pcall(GetCVar, name)
            if ok and tostring(current) ~= tostring(value) then
                if pcall(SetCVar, name, value) and not Tweaks.SYNC_NO_RELOAD[name] then changed = changed + 1 end
            end
        end
    end

    -- Edit Mode layout, matched on name and kind; the switch rides on the reload dialog's secure
    -- button (from addon code it taints every system). Only a layout of the current input mode, once
    -- per character, as each mode's layout is remembered (section 15).
    local layoutChanged, layoutIndex = false, nil
    local manager = EditModeManagerFrame
    local layoutInfo = manager and manager.layoutInfo
    local expected = ns.IsGamepadUI() and Enum.InputDeviceInterfaceType.Gamepad or Enum.InputDeviceInterfaceType.Mkb
    if store.editModeLayout and layoutInfo and layoutInfo.layouts and not charDB.syncLayoutTaken then
        for index, layout in ipairs(layoutInfo.layouts) do
            local sameKind = store.editModeLayoutType == nil
                or layout.layoutType == store.editModeLayoutType
            if layout.layoutName == store.editModeLayout and sameKind then
                local style = layout.interfaceStyle
                local sameMode = style == expected or (style == nil and expected == Enum.InputDeviceInterfaceType.Mkb)
                if index ~= layoutInfo.activeLayout and sameMode then
                    layoutChanged, layoutIndex = true, index
                    charDB.syncLayoutTaken = true
                    Tweaks.AdoptSyncedLayout(layout)
                end
                break
            end
        end
    end

    -- Chat windows. Tabs only read their filters and channels at login, and writing them live would
    -- taint the chat handler, so a change asks for the reload below.
    local chatChanged = false
    local function Strings(list)
        local out = {}
        for _, v in ipairs(list or {}) do
            if type(v) == "string" then out[#out + 1] = v end
        end
        return out
    end
    local function SameSet(a, b)
        a, b = Strings(a), Strings(b)
        if #a ~= #b then return false end
        local seen = {}
        for _, v in ipairs(a) do seen[v] = true end
        for _, v in ipairs(b) do
            if not seen[v] then return false end
        end
        return true
    end
    if store.chat then
        for i, w in pairs(store.chat) do
            if w.name then pcall(SetChatWindowName, i, w.name) end
            if w.size and w.size >= 10 then pcall(SetChatWindowSize, i, w.size) end
            if w.r then pcall(SetChatWindowColor, i, w.r, w.g, w.b) end
            if w.a then pcall(SetChatWindowAlpha, i, w.a) end
            pcall(SetChatWindowDocked, i, w.docked or false)
            pcall(SetChatWindowLocked, i, w.locked or false)
            pcall(SetChatWindowShown, i, w.shown or false)
            pcall(SetChatWindowUninteractable, i, w.uninteractable or false)
            if w.point and w.x then pcall(SetChatWindowSavedPosition, i, w.point, w.x, w.y) end
            if w.width then pcall(SetChatWindowSavedDimensions, i, w.width, w.height) end
            if w.messages then
                local ok, current = pcall(function() return { GetChatWindowMessages(i) } end)
                current = ok and current or {}
                if not SameSet(current, w.messages) then chatChanged = true end
                for _, group in ipairs(current) do pcall(RemoveChatWindowMessages, i, group) end
                for _, group in ipairs(w.messages) do pcall(AddChatWindowMessages, i, group) end
            end
            -- only the window assignment; channels are never joined
            if w.channels then
                local ok, current = pcall(function() return { GetChatWindowChannels(i) } end)
                if not SameSet(ok and current or {}, w.channels) then chatChanged = true end
                for _, name in ipairs(ok and current or {}) do
                    if type(name) == "string" then pcall(RemoveChatWindowChannel, i, name) end
                end
                for _, name in ipairs(w.channels) do
                    if type(name) == "string" then pcall(AddChatWindowChannel, i, name) end
                end
            end
        end
        C_Timer.After(1, function()
            for i = 1, Constants.ChatFrameConstants.MaxChatWindows do pcall(FloatingChatFrame_Update, i, true) end
            pcall(FCF_DockUpdate)
        end)
    end

    -- Bag flags
    local b = store.bags
    if b then
        if b.sortRightToLeft ~= nil then pcall(C_Container.SetSortBagsRightToLeft, b.sortRightToLeft) end
        if b.insertLeftToRight ~= nil then pcall(C_Container.SetInsertItemsLeftToRight, b.insertLeftToRight) end
        if b.bankAutosortDisabled ~= nil then pcall(C_Container.SetBankAutosortDisabled, b.bankAutosortDisabled) end
        if b.backpackSellJunkDisabled ~= nil then pcall(C_Container.SetBackpackSellJunkDisabled, b.backpackSellJunkDisabled) end
        if b.backpackAutosortDisabled ~= nil then pcall(C_Container.SetBackpackAutosortDisabled, b.backpackAutosortDisabled) end
    end

    -- bag slot flags, through the API only (the bag frames refresh themselves)
    for bag, flags in pairs(store.bagFlags or {}) do
        for flag, set in pairs(flags) do
            local ok, current = pcall(C_Container.GetBagSlotFlag, bag, flag)
            if ok and current ~= set then pcall(C_Container.SetBagSlotFlag, bag, flag, set) end
        end
    end

    local okDecline, decline = pcall(GetAutoDeclineGuildInvites)
    if store.declineGuildInvites ~= nil and okDecline and decline ~= store.declineGuildInvites then
        pcall(SetAutoDeclineGuildInvites, store.declineGuildInvites)
    end

    -- Chat colours and class-coloured names
    for chatType, c in pairs(store.chatColors or {}) do
        pcall(ChangeChatColor, chatType, c[1], c[2], c[3])
    end
    for chatType, byClass in pairs(store.chatClassNames or {}) do
        local info = ChatTypeInfo[chatType]
        if info and (info.colorNameByClass and true or false) ~= byClass then
            pcall(SetChatColorNameByClass, chatType, byClass)
        end
    end

    -- action bars: delayed (the server mirrors the toggles back), then redrawn
    if store.actionBars then
        local toggles = store.actionBars
        C_Timer.After(4, function()
            if InCombatLockdown() then return end
            pcall(SetActionBarToggles, unpack(toggles))
            C_Timer.After(1, function()
                if not InCombatLockdown() then
                    pcall(securecall, MultiActionBar_Update)
                end
            end)
        end)
    end

    -- A watched CVar runs Blizzard's callback inside this call and taints what it writes (the raid
    -- frame options): any change asks for a clean reload, after the action bar pass.
    if changed > 0 or layoutChanged or chatChanged then
        C_Timer.After(6, function()
            if not InCombatLockdown() then
                ns.ShowDialog("FLAREUI_SYNC_RELOAD", sourceName, { layout = layoutIndex })
            end
        end)
    end

    charDB.syncApplied = store.savedAt
    Tweaks.syncLoading = false
end

-- A throw halfway releases syncLoading and says so
local function RunLoadSync()
    local ok, err = pcall(LoadSync)
    if not ok then
        Tweaks.syncLoading = false
        Print("|cffff4040" .. L["Sync Blizz UI stopped partway:"] .. "|r " .. tostring(err))
    end
end

local function InitSyncUI()
    Tweaks.chatBuilderSyncPending = true
    SyncEvents:RegisterEvent("PLAYER_LOGOUT", SaveSync)
    -- Enemy Nameplates in Combat Only flips its CVar at every fight; the snapshot takes the player's
    -- own value from the forced-CVar memory, so those writes need no new snapshot
    SyncEvents:RegisterEvent("CVAR_UPDATE", function(_, name)
        if name ~= "nameplateShowEnemies" then QueueSaveSync() end
    end)
    SyncEvents:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED", QueueSaveSync)
    SyncEvents:RegisterEvent("UPDATE_CHAT_WINDOWS", QueueSaveSync)
    SyncEvents:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS", QueueSaveSync)

    C_Timer.After(3, function()
        -- a no-op when this character is the source, or when none is set yet
        RunLoadSync()
        Tweaks.chatBuilderSyncPending = false
        -- the source's first snapshot; with no source yet, this character becomes it
        C_Timer.After(1, SaveSync)
    end)
end

-- Read by the source button in the options
function Tweaks:IsSyncSource()
    return IsSource(GetSyncStore())
end

function Tweaks:GetSyncSourceLabel()
    local store = GetSyncStore()
    -- a source saved before full names were kept: this character's own full name (read, not saved)
    if store and IsSource(store) and not store.source.full then
        local me = Me()
        if me then return me.full end
    end
    return store and SourceLabel(store.source) or nil
end

-- The snapshot is taken at once, for the other characters' next login
function Tweaks:MakeSyncSource()
    local store, me = GetSyncStore(), Me()
    if not (store and me) then return end
    store.source = me
    -- the source never applies a snapshot, but if it hands the role on it must take the next one
    ns.CharDB().syncApplied = nil
    SaveSync()
end

--------------------------------------------------
-- 5. VENDOR: SELL JUNK / REPAIR
-- Junk is sold by Blizzard's C_MerchantFrame.SellAllJunkItems; the value is the gold that came in.
--------------------------------------------------
-- The gold that came in counts, not prices read beforehand: an item the client hasn't loaded has no
-- price yet, and the server sells in steps, past its rate limit skipping some (a second sale picks
-- those up)
-- the waits below register and drop events on an object of their own, so no other feature's
-- handler for the same events is replaced or dropped with them (AceEvent: one per object and event)
Tweaks.VendorEvents = {}
LibStub("AceEvent-3.0"):Embed(Tweaks.VendorEvents)

local function OnMerchantShow()
    local db = GetDb()
    if not db or IsShiftKeyDown() then return end
    local selling = db.sellJunk and C_MerchantFrame.IsSellAllJunkEnabled() and C_MerchantFrame.GetNumJunkItems() > 0
    local repairing = db.autoRepair and CanMerchantRepair()
    local before, spent, repaired = GetMoney(), 0, not repairing

    -- true once there is nothing left to repair or the repair was paid
    local function TryRepair()
        local cost, canRepair = GetRepairAllCost()
        if not (canRepair and cost and cost > 0) then return true end
        if GetMoney() < cost then return false end
        RepairAllItems()
        spent = spent + cost
        Print(L["Repaired for %s."]:format(C_CurrencyInfo.GetCoinText(cost)))
        return true
    end
    local function CantAfford()
        local cost = GetRepairAllCost()
        if cost and cost > 0 then
            Print(L["Not enough gold to repair (%s)."]:format(C_CurrencyInfo.GetCoinText(cost)))
        end
    end
    local function Finish()
        Tweaks.VendorEvents:UnregisterEvent("PLAYER_MONEY")
        Tweaks.VendorEvents:UnregisterEvent("MERCHANT_CLOSED")
    end

    if repairing then repaired = TryRepair() end
    if not selling then
        if not repaired then CantAfford() end
        return
    end

    local sold = C_MerchantFrame.GetNumJunkItems()
    C_MerchantFrame.SellAllJunkItems()
    -- The junk gold arrives a moment after the sale, so a repair it has to pay for waits for it
    if not repaired then
        Tweaks.VendorEvents:RegisterEvent("PLAYER_MONEY", function()
            if TryRepair() then
                repaired = true
                Tweaks.VendorEvents:UnregisterEvent("PLAYER_MONEY")
            end
        end)
        Tweaks.VendorEvents:RegisterEvent("MERCHANT_CLOSED", Finish)
    end
    local function Report()
        local gained = GetMoney() - before + spent
        if gained > 0 then Print(L["Sold %d junk items for %s."]:format(sold, C_CurrencyInfo.GetCoinText(gained))) end
        if not repaired then
            Finish()
            CantAfford()
        end
    end
    C_Timer.After(1.5, function()
        -- the second pass asks again: still on, Shift not held, and not on the Buyback tab (an item
        -- bought back just now would be sold again)
        local open = MerchantFrame and MerchantFrame:IsShown() and MerchantFrame.selectedTab == 1
        local db = GetDb()
        if open and db and db.sellJunk and not IsShiftKeyDown() and C_MerchantFrame.GetNumJunkItems() > 0 then
            sold = sold + C_MerchantFrame.GetNumJunkItems()
            C_MerchantFrame.SellAllJunkItems()
            C_Timer.After(1.5, Report)
        else
            Report()
        end
    end)
end

local function InitVendor()
    Tweaks:RegisterEvent("MERCHANT_SHOW", OnMerchantShow)
    -- Blizzard's own Sell All Junk button is redundant with auto-selling
    if MerchantSellAllJunkButton then
        MerchantSellAllJunkButton:HookScript("OnShow", function(btn)
            local db = GetDb()
            if db and db.sellJunk then btn:Hide() end
        end)
    end
end

--------------------------------------------------
-- 6. DURABILITY WARNING
-- A chat warning when the worst equipped item drops to 50%, once per dip
--------------------------------------------------
local DURABILITY_SLOTS = { 1, 3, 5, 6, 7, 8, 9, 10, 16, 17, 18 }   -- armour and weapons
local DURABILITY_THRESHOLD = 50
local durabilityWarned = false

-- A thrown weapon spends a point of durability per throw: its percentage counts throws left, not wear
local function IsThrown(slot)
    if slot ~= INVSLOT_RANGED and slot ~= 18 then return false end
    local itemID = GetInventoryItemID("player", slot)
    if not itemID then return false end
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
    return classID == Enum.ItemClass.Weapon and subclassID == Enum.ItemWeaponSubclass.Thrown
end

local function LowestDurability()
    local lowest
    for _, slot in ipairs(DURABILITY_SLOTS) do
        local current, max
        if not IsThrown(slot) then current, max = GetInventoryItemDurability(slot) end
        if canaccessvalue(current) and canaccessvalue(max) and current and max and max > 0 then
            local percent = current / max * 100
            if not lowest or percent < lowest then lowest = percent end
        end
    end
    return lowest
end

local function CheckDurability()
    local db = GetDb()
    if not (db and db.durabilityWarning) then return end
    local lowest = LowestDurability()
    if not lowest then return end
    local threshold = DURABILITY_THRESHOLD
    if lowest <= threshold then
        if not durabilityWarned then
            durabilityWarned = true
            local text = L["|cffff4040Durability at %d%%|r - time to repair."]:format(math_floor(lowest + 0.5))
            Print(text)
            -- also in the middle of the screen with a sound: a chat line is easy to miss in a fight
            if UIErrorsFrame and UIErrorsFrame.AddMessage then
                UIErrorsFrame:AddMessage(text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""), 1, 0.25, 0.25)
            end
            PlaySound(SOUNDKIT.RAID_WARNING)
        end
    elseif lowest > threshold + 5 then
        durabilityWarned = false   -- re-arm once repaired
    end
end

local function InitDurability()
    Tweaks:RegisterEvent("UPDATE_INVENTORY_DURABILITY", CheckDurability)
    Tweaks:RegisterEvent("UPDATE_INVENTORY_ALERTS", CheckDurability)   -- items that mend themselves
    Tweaks:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", CheckDurability)
    Tweaks:RegisterEvent("PLAYER_ENTERING_WORLD", CheckDurability)
end

--------------------------------------------------
-- 7. CAMERA & LOOT
--------------------------------------------------
local ZOOM_STEP = 4.0
local origZoomIn, origZoomOut

-- CameraZoomIn / Out are replaced (the wheel bindings call the globals; no hook can change the
-- step); the originals come back when the option is off. CVars go back to the player's own values
-- only when FlareUI changed them (ForcedCVars).
-- The memory lives where the game keeps the CVar: per character for a CVar saved per character (so
-- one character's switch never writes its value over another's), account-wide otherwise
Tweaks.FORCED_KEYS = {
    maxZoom = "cameraDistanceMaxZoomFactor", zoomSpeed = "cameraZoomSpeed",
    tips = "showTutorials", combatPlates = "nameplateShowEnemies", mapFade = "mapFade",
    compare = "alwaysCompareItems",   -- the Tooltips module's Compare with Shift
}

function Tweaks.SavedPerCharacter(cvar)
    if not (C_CVar and C_CVar.GetCVarInfo) then return false end
    local ok, _, _, _, perCharacter = pcall(C_CVar.GetCVarInfo, cvar)
    return ok and perCharacter == true
end

function Tweaks.ForcedCVars(key)
    local global = ns.db and ns.db.global
    if not global then return {} end
    global.forcedCVars = global.forcedCVars or {}
    local cvar = Tweaks.FORCED_KEYS[key]
    if not (cvar and Tweaks.SavedPerCharacter(cvar)) then return global.forcedCVars end
    local char = ns.CharDB()
    char.forcedCVars = char.forcedCVars or {}
    -- a value held account-wide for this key moves to the character
    if global.forcedCVars[key] ~= nil and char.forcedCVars[key] == nil then
        char.forcedCVars[key] = global.forcedCVars[key]
    end
    global.forcedCVars[key] = nil
    return char.forcedCVars
end
local ForcedCVars = Tweaks.ForcedCVars

-- The value to put back; a stored true (no value was read) puts back Blizzard's default
function Tweaks.StoredCVar(stored, cvar)
    if stored ~= true then return stored end
    local ok, default = pcall(C_CVar.GetCVarDefault, cvar)
    return ok and default or nil
end

function Tweaks.RestoreTips(stored)
    local saved = type(stored) == "table" and stored or {}
    pcall(SetCVar, "showTutorials", saved.tutorials or 1)
    pcall(SetCVar, "showNPETutorials", saved.npe or 1)
end

local function ApplyCamera()
    local db = GetDb()
    if not db then return end
    local forced = ForcedCVars("maxZoom")
    if db.maxCameraZoom then
        forced.maxZoom = forced.maxZoom or GetCVar("cameraDistanceMaxZoomFactor") or true
        pcall(SetCVar, "cameraDistanceMaxZoomFactor", 2.6)
    elseif forced.maxZoom then
        pcall(SetCVar, "cameraDistanceMaxZoomFactor", Tweaks.StoredCVar(forced.maxZoom, "cameraDistanceMaxZoomFactor"))
        forced.maxZoom = nil
    end
    -- The gamepad's stick zoom calls the same functions every frame with a small step of its own:
    -- with the Gamepad UI on they stay Blizzard's, and otherwise only the bindings' step of 1 grows
    if db.fasterCameraZoom and not ns.IsGamepadUI() then
        origZoomIn = origZoomIn or _G.CameraZoomIn
        origZoomOut = origZoomOut or _G.CameraZoomOut
        _G.CameraZoomIn = function(step, ...)
            if step == 1 then step = ZOOM_STEP end
            return origZoomIn(step, ...)
        end
        _G.CameraZoomOut = function(step, ...)
            if step == 1 then step = ZOOM_STEP end
            return origZoomOut(step, ...)
        end
        forced = ForcedCVars("zoomSpeed")
        forced.zoomSpeed = forced.zoomSpeed or GetCVar("cameraZoomSpeed") or true
        pcall(SetCVar, "cameraZoomSpeed", 50)
    else
        if origZoomIn then _G.CameraZoomIn, _G.CameraZoomOut = origZoomIn, origZoomOut end
        forced = ForcedCVars("zoomSpeed")
        if forced.zoomSpeed then
            pcall(SetCVar, "cameraZoomSpeed", Tweaks.StoredCVar(forced.zoomSpeed, "cameraZoomSpeed"))
            forced.zoomSpeed = nil
        end
    end
end

-- LOOT_READY says whether to auto-loot: every slot is taken at once, on the first event only
local lootTaken = false
local function FastLoot(_, autoLoot)
    local db = GetDb()
    if lootTaken or not (autoLoot and db and db.fasterLoot) then return end
    -- an event that comes before the slots are filled must not use up this window's one go
    if GetNumLootItems() == 0 then return end
    lootTaken = true
    for slot = GetNumLootItems(), 1, -1 do LootSlot(slot) end
end

-- Fade Map While Moving: Blizzard's own map fade (the mapFade CVar), which no options page offers
function Tweaks.ApplyMapFade()
    local db = GetDb()
    if not db then return end
    local forced = ForcedCVars("mapFade")
    if db.mapFade then
        if forced.mapFade == nil then forced.mapFade = GetCVar("mapFade") or "0" end
        pcall(SetCVar, "mapFade", 1)
    elseif forced.mapFade ~= nil then
        pcall(SetCVar, "mapFade", forced.mapFade)
        forced.mapFade = nil
    end
end

local function InitCameraLoot()
    ApplyCamera()
    Tweaks.ApplyMapFade()
    Tweaks:RegisterEvent("LOOT_READY", FastLoot)
    Tweaks:RegisterEvent("LOOT_OPENED", FastLoot)   -- the second chance, same payload (autoLoot first)
    Tweaks:RegisterEvent("LOOT_CLOSED", function() lootTaken = false end)
end

--------------------------------------------------
-- 8. HIDE
--------------------------------------------------
-- Hide Error Messages keeps only the errors the player would otherwise miss (loot, money, quest
-- log), shown through Blizzard's TryDisplayMessage
local KEPT_ERRORS = {
    "ERR_INV_FULL", "ERR_ITEM_MAX_COUNT", "ERR_LOOT_GONE",    -- loot that did not make it into the bags
    "ERR_BAG_FULL", "ERR_LOOT_NO_SPACE",                      -- (only those the client has are kept)
    "ERR_NOT_ENOUGH_MONEY", "ERR_TOO_MUCH_GOLD",              -- money
    "ERR_QUEST_LOG_FULL",                                     -- quests
}

local function InitHideErrors()
    local frame = _G.UIErrorsFrame
    if not frame then return end
    local kept = {}
    for _, key in ipairs(KEPT_ERRORS) do
        if _G[key] then kept[_G[key]] = true end
    end
    frame:UnregisterEvent("UI_ERROR_MESSAGE")
    local listener = CreateFrame("Frame")
    listener:RegisterEvent("UI_ERROR_MESSAGE")
    listener:SetScript("OnEvent", function(_, _, messageType, message)
        if message and kept[message] then
            frame:TryDisplayMessage(messageType, message, RED_FONT_COLOR:GetRGB())
        end
    end)
    -- ping errors come through Blizzard's own event router, straight into the errors frame
    local game = _G.GameEvent
    if game and game.UnregisterInternalEvent then
        game.UnregisterInternalEvent("PING_SYSTEM_ERROR")
    end
end

local function InitHideZoneText()
    if ZoneTextFrame then ZoneTextFrame:SetScript("OnShow", ZoneTextFrame.Hide) end
    if SubZoneTextFrame then SubZoneTextFrame:SetScript("OnShow", SubZoneTextFrame.Hide) end
end

-- Frame Numbers: the damage and healing numbers on the player and pet portraits, and the status text
-- (health and power numbers) on Blizzard's player, pet, target and focus frames. The texts fade to
-- nothing rather than hide: Blizzard shows and hides them on its own.
local function StatusBars()
    local bars = {}
    local function Add(bar) if bar then bars[#bars + 1] = bar end end
    if PlayerFrame_GetHealthBar then Add(PlayerFrame_GetHealthBar()) end
    if PlayerFrame_GetManaBar then Add(PlayerFrame_GetManaBar()) end
    Add(_G.PetFrameHealthBar)
    Add(_G.PetFrameManaBar)
    for _, frame in ipairs({ _G.TargetFrame, _G.FocusFrame }) do
        local main = frame and frame.TargetFrameContent and frame.TargetFrameContent.TargetFrameContentMain
        local container = main and main.HealthBarsContainer
        Add(container and container.HealthBar)
        Add(main and main.ManaBar)
    end
    return bars
end

local function ApplyStatusText(hide)
    if not (hide or Tweaks.statusTextHidden) then return end
    for _, bar in ipairs(StatusBars()) do
        -- (any of them can be missing)
        for _, key in ipairs({ "TextString", "LeftText", "RightText" }) do
            local text = bar[key]
            if text and text.SetAlpha then text:SetAlpha(hide and 0 or 1) end
        end
    end
    Tweaks.statusTextHidden = hide or nil
end

local function ApplyPortraitNumbers()
    local db = GetDb()
    if not db then return end
    local hide = db.hidePortraitNumbers
    ApplyStatusText(hide)
    local indicator = PlayerFrame and PlayerFrame.PlayerFrameContent and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain
        and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HitIndicator
    if indicator and (hide or Tweaks.hitIndicatorHidden) then
        indicator:SetShown(not hide)
        Tweaks.hitIndicatorHidden = hide or nil
    end
    if PetHitIndicator then
        if hide then
            if not Tweaks.petHitHooked then
                Tweaks.petHitHooked = true
                hooksecurefunc(PetHitIndicator, "Show", function(f) local d = GetDb(); if d and d.hidePortraitNumbers then f:Hide() end end)
            end
            PetHitIndicator:Hide()
        end
    end
end

local function ApplyTips()
    local db = GetDb()
    if not db then return end
    local forced = ForcedCVars("tips")
    if db.hideTips then
        forced.tips = forced.tips or { tutorials = GetCVar("showTutorials"), npe = GetCVar("showNPETutorials") }
        pcall(SetCVar, "showTutorials", 0)
        pcall(SetCVar, "showNPETutorials", 0)
        -- HideAllSystem() with no system only matches system-less tips: close every active one
        if HelpTip and HelpTip.framePool then
            local open = {}
            for frame in HelpTip.framePool:EnumerateActive() do open[#open + 1] = frame end
            for _, frame in ipairs(open) do frame:Close() end
        end
    elseif forced.tips then
        Tweaks.RestoreTips(forced.tips)
        forced.tips = nil
    end
end

local function InitHide()
    local db = GetDb()
    if not db then return end
    if db.hideErrors then InitHideErrors() end
    if db.hideZoneText then InitHideZoneText() end
    ApplyPortraitNumbers()
    ApplyTips()
end

--------------------------------------------------
-- 9. NAMEPLATE COMBO POINTS
-- Combo points (Core.lua: Blizzard's points, or FlareUI's gem while the count is secret) under the
-- target nameplate's health bar; Forever loads no nameplate combo bar. A readable count hides the
-- row at zero.
--------------------------------------------------
local NP_COMBO_SIZE     = 14   -- the point's side
local NP_COMBO_SPACING  = ns.ComboPointStep(NP_COMBO_SIZE)   -- Blizzard's art never touches its neighbour
local NP_COMBO_OFFSET_Y = -5   -- below the cast bar slot, clear of the aggro glow (negative = down)
local NP_COMBO_SCALE    = 1.1  -- on top of the nameplate's own scale
local NP_COMBO_MAX      = 10
local NP_COMBO_FALLBACK = 5

local npComboRow, npComboEvents

-- The combo points and quest tags stand down while a nameplate addon is loaded
local NAMEPLATE_ADDONS = {
    { "Platynator", "Platynator" }, { "Plater", "Plater" }, { "Kui_Nameplates", "KuiNameplates" },
    { "TidyPlates_ThreatPlates", "Threat Plates" }, { "TidyPlates", "Tidy Plates" },
    { "NeatPlates", "NeatPlates" }, { "BetterBlizzPlates", "BetterBlizzPlates" },
    { "EllesmereUINameplates", "EllesmereUI Nameplates" }, { "nPlates", "nPlates" },
}

-- The name of the nameplate addon in charge, or nil
function Tweaks:GetNameplateAddon()
    for _, entry in ipairs(NAMEPLATE_ADDONS) do
        if C_AddOns.IsAddOnLoaded(entry[1]) then return entry[2] end
    end
    -- a UI suite whose nameplates are a module that can be switched off
    local E = C_AddOns.IsAddOnLoaded("ElvUI") and _G.ElvUI and _G.ElvUI[1]
    if type(E) == "table" and type(E.private) == "table" and type(E.private.nameplates) == "table"
        and E.private.nameplates.enable then
        return "ElvUI"
    end
end

local function LayoutComboRow(row, count)
    for i = 1, count do
        local gem = row.gems[i]
        if not gem then
            gem = ns.CreateComboPoint(row, i, NP_COMBO_SIZE)
            row.gems[i] = gem
        end
        gem:ClearAllPoints()
        gem:SetPoint("TOPLEFT", row, "TOPLEFT", (i - 1) * NP_COMBO_SPACING, 0)
        gem:Show()
    end
    for i = count + 1, #row.gems do row.gems[i]:Hide() end
    row:SetSize((count - 1) * NP_COMBO_SPACING + NP_COMBO_SIZE, NP_COMBO_SIZE)
    row.count = count
end

-- Rogues, and druids in cat form, on a hostile target
local function PlayerBuildsComboPoints()
    local _, class = UnitClass("player")
    if not canaccessvalue(class) or (class ~= "ROGUE" and class ~= "DRUID") then return false end
    if class == "DRUID" then
        local powerType = UnitPowerType("player")
        if not (canaccessvalue(powerType) and powerType == Enum.PowerType.Energy) then return false end
    end
    local hostile = UnitCanAttack("player", "target")
    return canaccessvalue(hostile) and hostile or false
end

-- Below the plate's cast bar slot: Forever keeps it under the health bar whether the unit casts or
-- not (Blizzard's own widgets hang there too), so a cast never covers the points and they never
-- jump. Then the health bar, then the plate itself.
local function PlateAnchor(plate)
    local unitFrame = plate.UnitFrame
    local casts = unitFrame and unitFrame.CastBarsContainer
    if casts and not casts:IsForbidden() then return casts end
    local bar = unitFrame and unitFrame.HealthBarsContainer and unitFrame.HealthBarsContainer.healthBar
    if bar and not bar:IsForbidden() then return bar end
    return plate
end

local function UpdateNameplateCombo(_, event, _, powerToken)
    local row = npComboRow
    if not row then return end
    -- energy ticks are not combo point changes
    if event == "UNIT_POWER_FREQUENT" and canaccessvalue(powerToken) and powerToken ~= "COMBO_POINTS" then return end
    local plate = C_NamePlate.GetNamePlateForUnit("target")
    local points = GetComboPoints("player", "target")
    -- the points the shine compares against: none known after a target change or while secret
    local last = row.lastPoints
    if event == "PLAYER_TARGET_CHANGED" then last = nil end
    row.lastPoints = canaccessvalue(points) and points or nil
    local show = plate ~= nil and PlayerBuildsComboPoints()
    if show and canaccessvalue(points) and points == 0 then show = false end
    if not show then
        row:Hide()
        return
    end

    local max = UnitPowerMax("player", Enum.PowerType.ComboPoints)
    if not (canaccessvalue(max) and max and max >= 1) then max = NP_COMBO_FALLBACK end
    max = math_min(max, NP_COMBO_MAX)
    if row.count ~= max then LayoutComboRow(row, max) end

    if row:GetParent() ~= plate or not row:IsShown() then
        local anchor = PlateAnchor(plate)
        row:SetParent(plate)
        row:ClearAllPoints()
        row:SetPoint("TOP", anchor, "BOTTOM", 0, NP_COMBO_OFFSET_Y)
        row:SetFrameLevel(anchor:GetFrameLevel() + 5)
    end
    -- Blizzard's points (Core.lua), animated except right after a target change
    for i = 1, max do ns.SetComboPoint(row.gems[i], points, last ~= nil) end
    row:Show()
end

-- Switched on and off live from the options
local function ApplyNameplateCombo()
    local db = GetDb()
    if not (db and db.nameplateCombo) or Tweaks:GetNameplateAddon() then
        if npComboEvents then npComboEvents:UnregisterAllEvents() end
        if npComboRow then npComboRow:Hide() end
        return
    end
    if not npComboRow then
        npComboRow = CreateFrame("Frame", nil, UIParent)
        npComboRow.gems = {}
        npComboRow:SetScale(NP_COMBO_SCALE)
        npComboRow:Hide()
        npComboEvents = CreateFrame("Frame")
        npComboEvents:SetScript("OnEvent", UpdateNameplateCombo)
    end
    for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED" }) do
        npComboEvents:RegisterEvent(event)
    end
    -- combo points arrive as the player's power; UNIT_FACTION catches a target turning hostile
    for _, event in ipairs({ "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }) do
        npComboEvents:RegisterUnitEvent(event, "player")
    end
    npComboEvents:RegisterUnitEvent("UNIT_FACTION", "target")
    UpdateNameplateCombo()
end

--------------------------------------------------
-- 10. NAMEPLATE QUEST TAGS
-- A quest "!" just right of an enemy nameplate's level box (or health bar) whose unit is
-- related to an active quest. Plates are recycled: each plate has a tag, re-checked when a unit
-- gets a plate, when the quest log changes, and when the level box comes or goes.
--------------------------------------------------
local QUEST_TAG_ATLAS   = "QuestNormal"   -- the map's quest-offer "!", no shield
local QUEST_TAG_FILE    = "Interface\\GossipFrame\\AvailableQuestIcon"
local QUEST_TAG_SIZE    = 22     -- used when the box's height is not known yet
local QUEST_TAG_HEIGHT  = 0.85   -- the badge's height as a share of the box it sits on
local questTags = {}           -- plate -> tag
local questUnits = {}          -- nameplate unit tokens that currently have a plate
local questLevelHooked = {}    -- level boxes whose show / hide already re-places the tag
local questEvents
local UpdateQuestTag

-- Questie draws its own quest icons on nameplates. Read each time: its option applies live
function Tweaks:QuestieHasNameplateIcons()
    local questie = _G.Questie
    local db = type(questie) == "table" and questie.db
    local profile = type(db) == "table" and db.profile
    return type(profile) == "table" and profile.nameplateEnabled == true
end

-- Width / height of the art, so the tag keeps its shape at any height
local questTagAspect
local function QuestTagAspect()
    if not questTagAspect then
        local info = C_Texture.GetAtlasInfo(QUEST_TAG_ATLAS)
        questTagAspect = (info and info.width > 0 and info.height > 0) and (info.width / info.height) or 1
    end
    return questTagAspect
end

-- The "!" art (also the settings preview's sample plate)
function Tweaks.QuestTagArt(icon)
    if C_Texture.GetAtlasInfo(QUEST_TAG_ATLAS) then icon:SetAtlas(QUEST_TAG_ATLAS) else icon:SetTexture(QUEST_TAG_FILE) end
end

local function GetQuestTag(plate)
    local tag = questTags[plate]
    if not tag then
        tag = CreateFrame("Frame", nil, plate)
        tag:SetSize(QUEST_TAG_SIZE, QUEST_TAG_SIZE)
        tag.icon = tag:CreateTexture(nil, "OVERLAY")
        tag.icon:SetAllPoints()
        Tweaks.QuestTagArt(tag.icon)
        questTags[plate] = tag
    end
    return tag
end

-- Where the tag sits: the plate's level box when it shows, otherwise the health bar. The second
-- return is what sizes and layers it: the level box whenever there is one (with Hide Level it is only
-- invisible, so the tag keeps its usual size and stays above the plate), otherwise the health bar.
-- the health bar itself (PlateAnchor gives the cast bar's container first, which sits under it even
-- while nothing is cast: with Hide Level the badge sat below the bar, a player's report 11-11)
local function QuestTagBar(plate)
    local unitFrame = plate.UnitFrame
    local bar = unitFrame and unitFrame.HealthBarsContainer and unitFrame.HealthBarsContainer.healthBar
    if bar and not bar:IsForbidden() then return bar end
    return PlateAnchor(plate)
end

local function QuestTagAnchor(plate)
    local unitFrame = plate.UnitFrame
    local level = unitFrame and unitFrame.PlayerLevelDiffFrame
    local db = GetDb()
    if db and db.nameplateHideLevel then
        local bar = QuestTagBar(plate)
        if level and not level:IsForbidden() then return bar, level end
        return bar, bar
    end
    if level and not level:IsForbidden() then
        if not questLevelHooked[level] then
            questLevelHooked[level] = true
            local function Replace(self)
                local now, owner = GetDb(), self:GetParent()
                if now and now.nameplateQuest and owner and owner.unit and questUnits[owner.unit] then
                    UpdateQuestTag(owner.unit)
                end
            end
            level:HookScript("OnShow", Replace)
            level:HookScript("OnHide", Replace)
        end
        if level:IsShown() then return level, level end
    end
    local bar = QuestTagBar(plate)
    return bar, bar
end

function UpdateQuestTag(unit)
    if not canaccessvalue(unit) then return end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate or plate:IsForbidden() then return end
    if Tweaks:QuestieHasNameplateIcons() then
        if questTags[plate] then questTags[plate]:Hide() end
        return
    end
    local hostile = UnitCanAttack("player", unit)
    local related = C_QuestLog.UnitIsRelatedToActiveQuest(unit)
    local show = canaccessvalue(hostile) and hostile and canaccessvalue(related) and related
    if not show then
        if questTags[plate] then questTags[plate]:Hide() end
        return
    end
    local tag = GetQuestTag(plate)
    local anchor, look = QuestTagAnchor(plate)
    -- the box's height in the tag's own units (the level box does not share the plate's scale)
    local size = look:GetHeight() * look:GetEffectiveScale() / tag:GetEffectiveScale() * QUEST_TAG_HEIGHT
    if not (size > 0) then size = QUEST_TAG_SIZE end
    tag:SetSize(size * QuestTagAspect(), size)
    tag:ClearAllPoints()
    -- beside the box, clear of its edge (the art has its own margin, so no gap is added)
    tag:SetPoint("LEFT", anchor, "RIGHT", 0, 0)
    ns.CopyStrata(tag, look)   -- the level box draws at HIGH
    tag:SetFrameLevel(look:GetFrameLevel() + 5)
    tag:Show()
end

local function UpdateAllQuestTags()
    for unit in pairs(questUnits) do UpdateQuestTag(unit) end
end

-- QUEST_LOG_UPDATE comes in bursts: one pass on the next frame
local function QueueAllQuestTags()
    if Tweaks.questTagsQueued then return end
    Tweaks.questTagsQueued = true
    C_Timer.After(0, function()
        Tweaks.questTagsQueued = nil
        UpdateAllQuestTags()
    end)
end

-- A secret unit token cannot be used, so such a plate stays untagged
local function OnQuestTagEvent(_, event, unit)
    if unit and not canaccessvalue(unit) then return end
    if event == "NAME_PLATE_UNIT_ADDED" then
        questUnits[unit] = true
        UpdateQuestTag(unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        questUnits[unit] = nil
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        if plate and questTags[plate] then questTags[plate]:Hide() end
    elseif event == "UNIT_FACTION" then
        if questUnits[unit] then UpdateQuestTag(unit) end
    else
        QueueAllQuestTags()
    end
end

-- Switched on and off live from the options
local function ApplyQuestTags()
    local db = GetDb()
    if not (db and db.nameplateQuest) or Tweaks:GetNameplateAddon() then
        if questEvents then questEvents:UnregisterAllEvents() end
        for _, tag in pairs(questTags) do tag:Hide() end
        wipe(questUnits)
        return
    end
    if not questEvents then
        questEvents = CreateFrame("Frame")
        questEvents:SetScript("OnEvent", OnQuestTagEvent)
    end
    for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "QUEST_LOG_UPDATE", "UNIT_FACTION" }) do
        questEvents:RegisterEvent(event)
    end
    questEvents:RegisterUnitEvent("UNIT_QUEST_LOG_CHANGED", "player")
    -- plates already on screen when the option comes on
    wipe(questUnits)
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        local unit = plate.unitToken
        if unit and canaccessvalue(unit) then questUnits[unit] = true end
    end
    UpdateAllQuestTags()
end

--------------------------------------------------
-- 11. HIDE LEVEL
-- Blizzard's level box on the right of a nameplate goes invisible, and the health bar takes its room
-- back after each of Blizzard's layouts. Blizzard's own check for the box is left alone (replacing it
-- would taint the plates, whose values can be secret); the box only loses its alpha.
--------------------------------------------------
local levelHooked = {}   -- plate unit frames whose layout is followed
local levelEvents

-- the health bar back to the plate's right edge (Blizzard's NamePlateUnitFrameMixin:UpdateAnchors
-- stops it short of the box)
local function StretchHealthBar(unitFrame)
    local db = GetDb()
    if not (db and db.nameplateHideLevel) or unitFrame:IsForbidden() then return end
    local container, cast = unitFrame.HealthBarsContainer, unitFrame.CastBarsContainer
    if not (container and cast) or container:IsForbidden() then return end
    local spacing = _G.NamePlateSetupOptions and _G.NamePlateSetupOptions.castBarToHealthBarSpacing or 0
    pcall(container.SetPoint, container, "BOTTOMRIGHT", cast, "TOPRIGHT", 0, spacing)
    -- the crowd control and loss-of-control icons right after the bar: Blizzard puts them past the
    -- level box's width too, which left a gap with the box hidden (a player's report 11-11)
    local auras = unitFrame.AurasFrame
    if auras and not auras:IsForbidden() then
        for _, key in ipairs({ "CrowdControlListFrame", "LossOfControlFrame" }) do
            local list = auras[key]
            if list and not list:IsForbidden() then pcall(list.SetPoint, list, "LEFT", container, "RIGHT", 5, 0) end
        end
    end
end

local function ApplyHideLevel(plate)
    local unitFrame = plate and plate.UnitFrame
    if not unitFrame or unitFrame:IsForbidden() then return end
    local level = unitFrame.PlayerLevelDiffFrame
    if not level or level:IsForbidden() then return end
    local db = GetDb()
    local on = db and db.nameplateHideLevel and not Tweaks:GetNameplateAddon()
    -- never on this session: Blizzard's plate stays untouched
    if not on and not levelEvents then return end
    level:SetAlpha(on and 0 or 1)
    if not levelHooked[unitFrame] and type(unitFrame.UpdateAnchors) == "function" then
        levelHooked[unitFrame] = true
        hooksecurefunc(unitFrame, "UpdateAnchors", StretchHealthBar)
    end
    if on then StretchHealthBar(unitFrame) end
end

local function ApplyHideLevelAll()
    local db = GetDb()
    local on = db and db.nameplateHideLevel and not Tweaks:GetNameplateAddon()
    if on and not levelEvents then
        levelEvents = CreateFrame("Frame")
        levelEvents:SetScript("OnEvent", function(_, _, unit)
            if not canaccessvalue(unit) then return end
            ApplyHideLevel(C_NamePlate.GetNamePlateForUnit(unit))
        end)
    end
    if levelEvents then
        if on then levelEvents:RegisterEvent("NAME_PLATE_UNIT_ADDED") else levelEvents:UnregisterAllEvents() end
    end
    -- switched off, a plate gets the box's room back at Blizzard's next layout of it (calling that
    -- layout from here would taint the plate)
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do ApplyHideLevel(plate) end
    UpdateAllQuestTags()
end

--------------------------------------------------
-- 11b. HIDE NAMES
-- A nameplate's unit name goes invisible. Only its alpha: Blizzard's health text turns off with a
-- hidden name (NamePlateHealthBarMixin). A friendly player shown by name only keeps it, as that name
-- is the whole plate. Blizzard re-lays a plate when that mode changes, so the layout is followed.
--------------------------------------------------
local nameHooked = {}   -- plate unit frames whose layout is followed
local nameEvents

local function ApplyHideName(unitFrame)
    if not unitFrame or unitFrame:IsForbidden() then return end
    local name = unitFrame.name
    if not name or name:IsForbidden() then return end
    local db = GetDb()
    local on = db and db.nameplateHideNames and not Tweaks:GetNameplateAddon()
    -- never on this session: Blizzard's plate stays untouched
    if not on and not nameEvents then return end
    name:SetAlpha((on and not unitFrame:IsShowOnlyName()) and 0 or 1)
    if not nameHooked[unitFrame] and type(unitFrame.UpdateAnchors) == "function" then
        nameHooked[unitFrame] = true
        hooksecurefunc(unitFrame, "UpdateAnchors", ApplyHideName)
    end
end

local function ApplyHideNamesAll()
    local db = GetDb()
    local on = db and db.nameplateHideNames and not Tweaks:GetNameplateAddon()
    if on and not nameEvents then
        nameEvents = CreateFrame("Frame")
        nameEvents:SetScript("OnEvent", function(_, _, unit)
            if not canaccessvalue(unit) then return end
            local plate = C_NamePlate.GetNamePlateForUnit(unit)
            ApplyHideName(plate and plate.UnitFrame)
        end)
    end
    if nameEvents then
        if on then nameEvents:RegisterEvent("NAME_PLATE_UNIT_ADDED") else nameEvents:UnregisterAllEvents() end
    end
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do ApplyHideName(plate.UnitFrame) end
end

--------------------------------------------------
-- 11c. LEVEL BEFORE NAME
-- With Hide Level Box on and names shown, a nameplate's name gets the unit's level in front, in the
-- difficulty colour for enemies ("??" for a skull). Blizzard writes the name in
-- CompactUnitFrame_UpdateName; the hook writes it again from the same GetUnitName call, so the level is
-- never added twice. A secret level skips the plate; a secret name goes through SetFormattedText as is.
-- The hook is set the first time the option is on, so an untouched option leaves the plates alone.
--------------------------------------------------
local LevelName = { written = {} }   -- written: plate unit frames that carry a level

function LevelName.On()
    local db = GetDb()
    return db and db.nameplateHideLevel and db.nameplateLevelName and not db.nameplateHideNames
        and not Tweaks:GetNameplateAddon() and true or false
end

function LevelName.Text(frame)
    local unit = frame.unit
    local showFullName = frame.optionTable and frame.optionTable.updateNameUsesGetUnitName and not frame.hideRealmName
    return GetUnitName(unit, showFullName)
end

-- the level with its colour, or nil when it can't be read
function LevelName.Prefix(unit)
    local level = UnitEffectiveLevel(unit)
    if not canaccessvalue(level) or type(level) ~= "number" then return nil end
    if level <= 0 then return LevelName.Format(level) end
    local attackable = UnitCanAttack("player", unit)
    local color
    if canaccessvalue(attackable) and attackable then
        color = ns.LevelDifficultyColor(unit, level)
    else
        color = _G.UNIT_LEVEL_NON_ATTACKABLE
    end
    return LevelName.Format(level, color)
end

-- A level in its colour ("??" for a skull); also the settings preview's sample plate
function LevelName.Format(level, color)
    if level <= 0 then return "|cffff2020??|r" end
    if color and color.r then
        return ("|cff%02x%02x%02x%d|r"):format(color.r * 255, color.g * 255, color.b * 255, level)
    end
    return tostring(level)
end

function LevelName.Apply(frame)
    if not frame or frame:IsForbidden() then return end
    local unit = frame.unit
    if not (unit and canaccessvalue(unit) and type(unit) == "string" and unit:find("^nameplate")) then return end
    -- the settings preview and the commentator write their own names
    if frame.UpdateNameOverride then return end
    local name = frame.name
    if not name or name:IsForbidden() then return end
    if not LevelName.On() then
        -- switched off: the plain name back where a level was written
        if LevelName.written[frame] then
            LevelName.written[frame] = nil
            if name:IsShown() then name:SetText(LevelName.Text(frame)) end
        end
        return
    end
    if not name:IsShown() then return end
    local prefix = LevelName.Prefix(unit)
    if not prefix then return end
    name:SetFormattedText("%s %s", prefix, LevelName.Text(frame))
    LevelName.written[frame] = true
end

function LevelName.ApplyAll()
    if LevelName.On() and not LevelName.hooked then
        LevelName.hooked = true
        hooksecurefunc("CompactUnitFrame_UpdateName", LevelName.Apply)
    end
    if not LevelName.hooked then return end
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do LevelName.Apply(plate.UnitFrame) end
end

--------------------------------------------------
-- 11d. SETTINGS PREVIEW SAMPLE
-- A stand-in for the target's enemy nameplate in the settings panel's picture: Blizzard's bar, name
-- and level box at the sizes Blizzard's nameplate setup has now, with this module's combo row, quest
-- "!", Hide Level Box, Hide Names and Level Before Name applied as on real plates. A plain frame: no
-- events, no mouse, real plates untouched.
--------------------------------------------------
Tweaks.plateSample = {
    PAD = 2,             -- the bar's backdrop reaches 2 px past its left edge
    BAR_COLOR = { r = 1, g = 0, b = 0 },   -- hostile
    HEALTH = 1,
}

function Tweaks.CreateSample(parent, kind)
    if kind ~= nil and kind ~= "plate" then return nil end
    local f = CreateFrame("Frame", nil, parent)
    f.fuiSample = true
    f:EnableMouse(false)
    local bar = CreateFrame("StatusBar", nil, f)
    local fill = bar:CreateTexture(nil, "ARTWORK")
    fill:SetAtlas("UI-HUD-CoolDownManager-Bar")
    -- a client that only takes a file here gets the plain bar
    if not pcall(bar.SetStatusBarTexture, bar, fill) then bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar") end
    bar:SetMinMaxValues(0, 1)
    -- Blizzard's backdrop behind the bar, and a thin dark border round it
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAtlas("UI-HUD-CoolDownManager-Bar-BG")
    bg:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 3)
    bg:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 6, -6)
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", 0, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, -1 },
            { "TOPLEFT", "BOTTOMLEFT", -1, 0 }, { "TOPRIGHT", "BOTTOMRIGHT", 1, 0 } }) do
        local edge = bar:CreateTexture(nil, "BORDER")
        edge:SetColorTexture(0, 0, 0, 0.8)
        edge:SetPoint(side[1], bar, side[1], side[3], side[4])
        edge:SetPoint(side[2], bar, side[2], side[3], side[4])
        if side[3] == 0 then edge:SetHeight(1) else edge:SetWidth(1) end
    end
    f.Bar = bar
    -- texts over the bar
    local texts = CreateFrame("Frame", nil, f)
    texts:SetAllPoints(bar)
    texts:SetFrameLevel(bar:GetFrameLevel() + 2)
    f.Name = texts:CreateFontString(nil, "OVERLAY")
    f.Name:SetWordWrap(false)
    f.Health = texts:CreateFontString(nil, "OVERLAY")
    f.Health:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    -- the level box (Forever's NameplateLevelFrame)
    local level = CreateFrame("Frame", nil, f)
    level:SetFrameLevel(bar:GetFrameLevel() + 3)
    level.Icon = level:CreateTexture(nil, "BACKGROUND")
    level.Icon:SetAtlas("ui-hud-nameplates-levelindicator")
    level.Icon:SetAllPoints()
    level.Text = level:CreateFontString(nil, "OVERLAY")
    level.Text:SetPoint("CENTER", level.Icon, "CENTER", 0, 0)
    f.Level = level
    -- the cast bar's slot under the health bar: the combo row and a hidden box's quest tag hang on it
    f.CastSlot = CreateFrame("Frame", nil, f)
    f.Quest = CreateFrame("Frame", nil, f)
    f.Quest:SetFrameLevel(bar:GetFrameLevel() + 5)
    f.Quest.icon = f.Quest:CreateTexture(nil, "OVERLAY")
    f.Quest.icon:SetAllPoints()
    Tweaks.QuestTagArt(f.Quest.icon)
    f.Combo = CreateFrame("Frame", nil, f)
    f.Combo.gems = {}
    f.Combo:SetScale(NP_COMBO_SCALE)
    f.Combo:SetFrameLevel(bar:GetFrameLevel() + 5)
    f:Hide()
    return f
end

function Tweaks.DrawSample(f)
    local db = GetDb() or {}
    local look = Tweaks.plateSample
    local so = _G.NamePlateSetupOptions or {}
    local constants = _G.NamePlateConstants or {}
    local styles = constants.NAME_ANCHOR_STYLES or {}
    local addon = Tweaks:GetNameplateAddon()
    local hideLevel = db.nameplateHideLevel and not addon
    local hideName = db.nameplateHideNames and not addon
    local showQuest = db.nameplateQuest and not addon and not Tweaks:QuestieHasNameplateIcons()
    local showCombo = db.nameplateCombo and not addon

    -- Blizzard's sizes (NamePlateDriverMixin:UpdateNamePlateOptions), its defaults where unset
    local content = (constants.NAME_PLATE_WIDTH or 190) * (so.horizontalScale or 1) - 2 * (so.insetWidth or 12)
    local healthHeight = so.healthBarHeight or 20
    local levelWidth = so.playerLevelDiffWidth or 28
    local castHeight = so.castBarHeight or 16
    local castGap = so.castBarToHealthBarSpacing or 2
    local nameAbove = so.unitNameAnchorStyle ~= nil and so.unitNameAnchorStyle ~= styles.InsideHealthBar
    local nameRoom = nameAbove and ((so.healthBarFontHeight or 14) + (so.healthBarToNameAboveSpacing or 2)) or 0
    local top = math.max(nameRoom, 3)   -- the level box reaches 3 px above the bar

    -- Hide Level Box: the box only goes invisible, the bar takes its room (StretchHealthBar)
    local barWidth = hideLevel and content or (content - levelWidth - 5)
    local bar = f.Bar
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", look.PAD, -top)
    bar:SetSize(barWidth, healthHeight)
    bar:SetValue(look.HEALTH)
    bar:GetStatusBarTexture():SetVertexColor(look.BAR_COLOR.r, look.BAR_COLOR.g, look.BAR_COLOR.b)

    local level = f.Level
    level:ClearAllPoints()
    level:SetPoint("TOPLEFT", bar, "TOPRIGHT", 5, 3)
    level:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT", 5, -2)
    level:SetWidth(levelWidth)
    level:SetAlpha(hideLevel and 0 or 1)
    level.Text:SetFontObject(_G.SystemFont_NamePlateLevel or GameFontNormalSmall)
    local myLevel = UnitLevel("player")
    if not (canaccessvalue(myLevel) and type(myLevel) == "number" and myLevel > 0) then myLevel = 1 end
    local color = _G.FAIR_DIFFICULTY_COLOR or ns.LevelDifficultyColor(nil, myLevel)
    level.Text:SetText(LevelName.Format(myLevel, color))

    -- the name as Blizzard places it for the style, white; Level Before Name puts the level in front
    local name = f.Name
    name:SetFontObject(_G.SystemFont_NamePlate_Outlined or _G.SystemFont_NamePlate or GameFontNormalSmall)
    name:SetTextColor(1, 1, 1)
    local text = L["Duskbat"]
    if hideLevel and db.nameplateLevelName and not hideName then text = LevelName.Format(myLevel, color) .. " " .. text end
    name:SetText(text)
    name:ClearAllPoints()
    if nameAbove then
        name:SetJustifyH(so.nameJustificationWhenAboveHealthBar or "LEFT")
        name:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, so.healthBarToNameAboveSpacing or 2)
        name:SetPoint("RIGHT", hideLevel and bar or level, "RIGHT", 0, 0)
    else
        name:SetJustifyH("LEFT")
        name:SetPoint("LEFT", bar, "LEFT", 4, 0)
        name:SetPoint("RIGHT", f.Health, "LEFT", -2, 0)
    end
    name:SetAlpha(hideName and 0 or 1)
    f.Health:SetFontObject(_G.SystemFont_NamePlate_Outlined or _G.SystemFont_NamePlate or GameFontNormalSmall)
    f.Health:SetTextColor(1, 1, 1)
    f.Health:SetText(("%d%%"):format(look.HEALTH * 100))

    local cast = f.CastSlot
    cast:ClearAllPoints()
    cast:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -castGap)
    cast:SetSize(content, castHeight)

    -- the quest "!" beside the box, or beside the cast slot with the box hidden (QuestTagAnchor),
    -- sized by the box either way
    local questWidth = 0
    if showQuest then
        local size = (healthHeight + 5) * QUEST_TAG_HEIGHT
        questWidth = size * QuestTagAspect()
        f.Quest:SetSize(questWidth, size)
        f.Quest:ClearAllPoints()
        f.Quest:SetPoint("LEFT", hideLevel and cast or level, "RIGHT", 0, 0)
        f.Quest:Show()
    else
        f.Quest:Hide()
    end

    -- the combo row under the cast slot, three of five lit
    local height = top + healthHeight + castGap + castHeight
    if showCombo then
        local row = f.Combo
        if row.count ~= NP_COMBO_FALLBACK then LayoutComboRow(row, NP_COMBO_FALLBACK) end
        for i = 1, NP_COMBO_FALLBACK do ns.SetComboPoint(row.gems[i], 3, false) end
        row:ClearAllPoints()
        row:SetPoint("TOP", cast, "BOTTOM", 0, NP_COMBO_OFFSET_Y)
        row:Show()
        height = height + (-NP_COMBO_OFFSET_Y + NP_COMBO_SIZE) * NP_COMBO_SCALE
    else
        f.Combo:Hide()
    end

    local width = look.PAD + content + math.max(questWidth, 6)   -- the backdrop reaches 6 px past the bar's right
    height = height + 6
    f:SetSize(width, height)
    f:Show()
    return width, height
end

--------------------------------------------------
-- 12. PARTY FRAME UNCLAMP (always on)
-- Edit Mode's clamp stops the party frames short of the left edge; switched off once, after combat
-- if need be.
--------------------------------------------------
local function UnclampPartyFrame()
    local party = _G.PartyFrame
    if not party then return end
    if InCombatLockdown() then
        local waiter = CreateFrame("Frame")
        waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
        waiter:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            party:SetClampedToScreen(false)
        end)
        return
    end
    party:SetClampedToScreen(false)
end

--------------------------------------------------
-- 13. AUTO-TYPE DELETE (the word goes into the box; Yes still has to be pressed)
-- The dialog's Enter handler deletes as soon as the word is in, so the box gives up its focus.
--------------------------------------------------
local DELETE_DIALOGS = { DELETE_GOOD_ITEM = true, DELETE_GOOD_QUEST_ITEM = true }

local function InitAutoDelete()
    hooksecurefunc("StaticPopup_Show", function(which)
        local db = GetDb()
        if not (db and db.autoDelete and DELETE_DIALOGS[which]) then return end
        local dialog = StaticPopup_FindVisible(which)
        local editBox = dialog and dialog:GetEditBox()
        if editBox then
            editBox:SetText(DELETE_ITEM_CONFIRM_STRING)
            editBox:ClearFocus()
        end
    end)
end

--------------------------------------------------
-- 13b. AUTO ACCEPT AND TURN-IN QUESTS
-- Shift holds both back. Repeatable quests are never touched: accepting and turning them in by
-- themselves would spend every item they take. A choice of rewards, a gold cost and a PvP quest's
-- confirmation still wait for the player. Off in the Gamepad UI: its quest windows are Blizzard's own.
--------------------------------------------------
local function InitAutoQuests()
    -- checked on every event, so a switch to the Gamepad UI after login counts too
    local function On(key)
        local db = GetDb()
        return db and db[key] and not IsShiftKeyDown() and not ns.IsGamepadUI()
    end
    -- what the offer itself says (repeatable, daily, weekly) counts first: the quest log answers
    -- from cached quest data, which may not know a quest it hasn't seen yet
    local function Repeatable(questID, repeatable, frequency)
        return repeatable or (frequency and frequency > 0) or C_QuestLog.IsRepeatableQuest(questID)
    end
    -- grey when either the offer or the quest log says so
    local function CanAccept(questID, repeatable, frequency, trivial)
        return questID and not trivial and not Repeatable(questID, repeatable, frequency)
            and not C_QuestLog.IsQuestTrivial(questID)
    end
    -- battleground marks are worth keeping for other rewards: a quest that takes them is handed in by hand
    -- (Warsong Gulch, Arathi Basin, Alterac Valley)
    local MARKS = { [20558] = true, [20559] = true, [20560] = true }
    local function TakesMarks()
        for i = 1, GetNumQuestItems() do
            local link = GetQuestItemLink("required", i)
            local itemID = link and C_Item.GetItemInfoInstant(link)
            if itemID and MARKS[itemID] then return true end
        end
        return false
    end
    local function CanTurnIn()
        local money = GetQuestMoneyToGet()
        return not C_QuestLog.IsRepeatableQuest(GetQuestID()) and not (money and money > 0)
    end

    local TAXI_ICON = 132057   -- the flight master's gossip icon (Interface\GossipFrame\TaxiGossipIcon)
    local handlers = {}
    function handlers.GOSSIP_SHOW()
        if On("autoTurnInQuests") then
            for _, quest in ipairs(C_GossipInfo.GetActiveQuests()) do
                if quest.isComplete and not Repeatable(quest.questID, quest.repeatable, quest.frequency) then
                    C_GossipInfo.SelectActiveQuest(quest.questID)
                    return
                end
            end
        end
        if On("autoAcceptQuests") then
            for _, quest in ipairs(C_GossipInfo.GetAvailableQuests()) do
                if not quest.isIgnored and CanAccept(quest.questID, quest.repeatable, quest.frequency, quest.isTrivial) then
                    C_GossipInfo.SelectAvailableQuest(quest.questID)
                    return
                end
            end
        end
        -- a flight master with nothing else to say opens the flight map at once (Shift talks normally)
        if On("taxiMap") and #C_GossipInfo.GetAvailableQuests() == 0 and #C_GossipInfo.GetActiveQuests() == 0 then
            for _, option in ipairs(C_GossipInfo.GetOptions() or {}) do
                if option.gossipOptionID and (option.icon == TAXI_ICON or option.overrideIconID == TAXI_ICON) then
                    C_GossipInfo.SelectOption(option.gossipOptionID)
                    return
                end
            end
        end
    end
    function handlers.QUEST_GREETING()
        if On("autoTurnInQuests") then
            for i = 1, GetNumActiveQuests() do
                local _, isComplete = GetActiveTitle(i)
                if isComplete and not C_QuestLog.IsRepeatableQuest(GetActiveQuestID(i)) then
                    SelectActiveQuest(i)
                    return
                end
            end
        end
        if On("autoAcceptQuests") then
            for i = 1, GetNumAvailableQuests() do
                local trivial, frequency, repeatable, _, questID = GetAvailableQuestInfo(i)
                if CanAccept(questID, repeatable, frequency, trivial) then
                    SelectAvailableQuest(i)
                    return
                end
            end
        end
    end
    function handlers.QUEST_DETAIL(questStartItemID)
        if not On("autoAcceptQuests") then return end
        -- Blizzard offers these through the quest tracker's pop-up instead of this window
        if (questStartItemID and questStartItemID ~= 0) or QuestIsFromAdventureMap() then return end
        if QuestFlagsPVP() or not CanAccept(GetQuestID()) then return end
        if QuestGetAutoAccept() then
            if not QuestIsFromAreaTrigger() then AcknowledgeAutoAcceptQuest() end
        else
            AcceptQuest()
        end
    end
    function handlers.QUEST_PROGRESS()
        if On("autoTurnInQuests") and IsQuestCompletable() and CanTurnIn() and not TakesMarks() then CompleteQuest() end
    end
    function handlers.QUEST_COMPLETE()
        if not (On("autoTurnInQuests") and CanTurnIn()) then return end
        local choices = GetNumQuestChoices()
        if choices <= 1 then GetQuestReward(choices) end
    end

    local listener = CreateFrame("Frame")
    for event in pairs(handlers) do listener:RegisterEvent(event) end
    listener:SetScript("OnEvent", function(_, event, ...) handlers[event](...) end)
end

--------------------------------------------------
-- 14. TRAIN ALL
-- Learns every available skill as far as the gold goes; never a new profession, not at pet
-- trainers. Walked from the bottom: a purchase reindexes the entries below it.
--------------------------------------------------
local trainAll

local function TrainableSkills()
    local list, total, money = {}, 0, GetMoney()
    for i = GetNumTrainerServices(), 1, -1 do
        if select(2, GetTrainerServiceInfo(i)) == "available" then
            local cost, isProfession = GetTrainerServiceCost(i)
            cost = cost or 0
            if not isProfession and total + cost <= money then
                total = total + cost
                list[#list + 1] = i
            end
        end
    end
    return list, total
end

local function UpdateTrainAll()
    if not trainAll then return end
    local db = GetDb()
    local show = db and db.trainAll and C_Trainer.GetTrainerType() ~= Enum.TrainerType.Pet
    trainAll:SetShown(show or false)
    if show then trainAll:SetEnabled(#TrainableSkills() > 0) end
end

local function CreateTrainAll()
    local train = _G.ClassTrainerTrainButton
    if trainAll or not train then return end
    trainAll = CreateFrame("Button", nil, train:GetParent(), "MagicButtonTemplate")
    trainAll:SetText(L["Train All"])
    trainAll:SetSize(90, train:GetHeight())
    trainAll:SetPoint("RIGHT", train, "LEFT", 0, 0)
    trainAll:SetScript("OnClick", function()
        for _, index in ipairs((TrainableSkills())) do BuyTrainerService(index) end
    end)
    trainAll:SetScript("OnEnter", function(self)
        local list, total = TrainableSkills()
        ns.OwnGameTooltip(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Train All"], 1, 1, 1)
        if #list == 0 then
            GameTooltip:AddLine(L["Nothing you can afford to learn here."], nil, nil, nil, true)
        else
            local line = #list == 1 and L["Learns 1 skill for %s."]:format(GetMoneyString(total))
                or L["Learns %d skills for %s."]:format(#list, GetMoneyString(total))
            GameTooltip:AddLine(line, nil, nil, nil, true)
        end
        GameTooltip:Show()
    end)
    trainAll:SetScript("OnLeave", GameTooltip_Hide)
    hooksecurefunc("ClassTrainerFrame_Update", UpdateTrainAll)
    UpdateTrainAll()
end

local function InitTrainAll()
    EventUtil.ContinueOnAddOnLoaded("Blizzard_TrainerUI", CreateTrainAll)
end

--------------------------------------------------
-- 15. EDIT MODE LAYOUT PER MODE
-- Switching the Gamepad UI falls back to the new mode's preset layout. FlareUI remembers the layout
-- last used in each mode (per character, by type and name) and offers it back after login. The
-- switch runs from the dialog's secure button, never in combat, and reloads: SetActiveLayout applies
-- the layout inside the call and /run is forced insecure, so without the reload every system kept
-- tainted anchors and Blizzard's bar layout was blocked in the next fight.
--------------------------------------------------
local function ModeKey()
    return ns.IsGamepadUI() and "gamepad" or "keyboard"
end

-- The active layout of Edit Mode's list (presets first, then the saved ones)
local function ActiveLayout()
    local manager = _G.EditModeManagerFrame
    local info = manager and manager.layoutInfo
    if not (info and info.layouts and info.activeLayout) then return nil end
    return info.layouts[info.activeLayout], info
end

-- Not remembered: anything after the input mode changed this session, nor the fallback a restore
-- was offered over
local sessionMode, fallbackLayout

local function SameLayout(a, b)
    return a and b and a.layoutName == b.name and a.layoutType == b.layoutType
end

local function RememberLayout()
    if sessionMode and ModeKey() ~= sessionMode then return end
    local layout = ActiveLayout()
    if not (layout and layout.layoutName) then return end
    if fallbackLayout then
        if SameLayout(layout, fallbackLayout) then return end
        fallbackLayout = nil
    end
    local charDB = ns.CharDB()
    charDB.layoutByMode = charDB.layoutByMode or {}
    charDB.layoutByMode[ModeKey()] = { name = layout.layoutName, layoutType = layout.layoutType }
end

-- Sync Blizz UI is switching this character to the source's layout (after its reload): remember
-- that one for this mode, and not the layout still active until the reload
function Tweaks.AdoptSyncedLayout(layout)
    if not (layout and layout.layoutName) then return end
    local active = ActiveLayout()
    fallbackLayout = active and { name = active.layoutName, layoutType = active.layoutType }
    local charDB = ns.CharDB()
    charDB.layoutByMode = charDB.layoutByMode or {}
    charDB.layoutByMode[ModeKey()] = { name = layout.layoutName, layoutType = layout.layoutType }
end

-- Index of the remembered layout, when it is not the active one
local function RememberedIndex()
    local saved = ns.CharDB().layoutByMode
    saved = saved and saved[ModeKey()]
    local active, info = ActiveLayout()
    if not (saved and active) then return nil end
    if active.layoutName == saved.name and active.layoutType == saved.layoutType then return nil end
    for index, layout in ipairs(info.layouts) do
        if layout.layoutName == saved.name and layout.layoutType == saved.layoutType then return index, layout end
    end
end

ns.Dialogs["FLAREUI_RESTORE_LAYOUT"] = {
    text = L["Restore your %s Edit Mode layout?"] .. "\n\n" .. L["This reloads your interface."],
    button1 = L["Restore"],
    button2 = L["Not Now"],
    macro = function(data) return "/run C_EditMode.SetActiveLayout(" .. data.index .. ")\n/reload" end,
    hideOnEscape = true,
    padSecure = true,
}

local function InitLayoutPerMode()
    sessionMode = ModeKey()
    local restored = false
    local events = CreateFrame("Frame")

    local function Restore()
        restored = true
        local index, layout = RememberedIndex()
        if index then
            local active = ActiveLayout()
            fallbackLayout = active and { name = active.layoutName, layoutType = active.layoutType }
            local mode = ns.IsGamepadUI() and L["gamepad"] or L["keyboard and mouse"]
            ns.ShowDialog("FLAREUI_RESTORE_LAYOUT", mode .. " (|cffffff00" .. layout.layoutName .. "|r)",
                { index = index, name = layout.layoutName, mode = mode })
        else
            RememberLayout()
        end
    end

    local function TryRestore()
        if InCombatLockdown() then
            events:RegisterEvent("PLAYER_REGEN_ENABLED")
            return
        end
        -- a frame later: not from inside Edit Mode's own handling of the update
        C_Timer.After(0, Restore)
    end

    events:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            events:UnregisterEvent("PLAYER_REGEN_ENABLED")
            TryRestore()
        elseif restored then
            RememberLayout()   -- the player picked a layout (or the restore just landed)
        else
            TryRestore()
        end
    end)
    -- Edit Mode may have had its layouts before Tweaks started
    local manager = _G.EditModeManagerFrame
    if manager and manager.IsInitialized and manager:IsInitialized() then TryRestore() end
end

--------------------------------------------------
-- 16. /way MAP PINS
-- "/way 52.3 48.1" pins the current map; "/way Zone Name 52 48" looks the zone up by name.
--------------------------------------------------
local mapNameCache
-- Map names, lower case with accents folded (so "orgrimmar" finds Orgrimmar and "teldrassil" finds an
-- accented name too), read once in one walk of the map tree; on a name clash a zone wins over a
-- continent, then a dungeon, then a micro map
local function MapKey(name)
    -- Latin-1 letters in UTF-8: a capital (second byte 128-158) lowers by 32, then folds to its base letter
    local key = name:lower():gsub("\195([\128-\191])", function(byte)
        local b = byte:byte()
        if b >= 128 and b <= 158 and b ~= 151 then b = b + 32 end
        if b >= 160 and b <= 165 then return "a" end
        if b == 167 then return "c" end
        if b >= 168 and b <= 171 then return "e" end
        if b >= 172 and b <= 175 then return "i" end
        if b == 177 then return "n" end
        if (b >= 178 and b <= 182) or b == 184 then return "o" end
        if b >= 185 and b <= 188 then return "u" end
        if b == 159 then return "ss" end
        return "\195" .. string.char(b)
    end)
    return key
end

local function GetMapIDByName(targetName)
    local target = MapKey(targetName:match("^%s*(.-)%s*$"))
    if target == "" then return nil end
    if not mapNameCache then
        mapNameCache = {}
        local T = Enum.UIMapType
        local RANK = { [T.Zone] = 1, [T.Continent] = 2, [T.Dungeon] = 3, [T.Micro] = 4 }
        local rankOf = {}
        local function Add(info)
            if not (info and info.name and info.mapID) then return end
            local key, rank = MapKey(info.name), RANK[info.mapType] or 9
            if not mapNameCache[key] or rank < rankOf[key] then
                mapNameCache[key], rankOf[key] = info.mapID, rank
            end
        end
        -- up to the top of the tree, then every map below it in one call
        local root = C_Map.GetFallbackWorldMapID and C_Map.GetFallbackWorldMapID()
        local rootInfo = root and C_Map.GetMapInfo(root)
        while rootInfo and rootInfo.parentMapID and rootInfo.parentMapID ~= 0 do
            local parent = C_Map.GetMapInfo(rootInfo.parentMapID)
            if not parent then break end
            rootInfo = parent
        end
        local count = 0
        if rootInfo then
            Add(rootInfo)
            for _, info in ipairs(C_Map.GetMapChildrenInfo(rootInfo.mapID, nil, true) or {}) do
                Add(info)
                count = count + 1
            end
        end
        -- a tree that didn't come back whole: every ID is read instead
        if count < 50 then
            for mapID = 1, 4000 do Add(C_Map.GetMapInfo(mapID)) end
        end
    end
    return mapNameCache[target]
end

local function HandleWay(msg)
    local db = GetDb()
    if not db or not db.way then
        print("|cffff0000FlareUI:|r " .. L["/way is off in the Quality of Life settings."])
        return
    end

    msg = (msg or ""):match("^%s*(.-)%s*$")
    if msg == "" then
        print("|cff00ff00FlareUI:|r " .. L["/way usage:"])
        print("  /way 50.5 40.2  " .. L["(current zone)"])
        print("  /way Elwynn Forest 40 50  " .. L["(named zone)"])
        print("  /way #1429 40 50  " .. L["(map ID)"])
        return
    end

    local zonePart, xStr, yStr = msg:match("^(.*%S)%s+(%d+%.?%d*)%s*[,%s]%s*(%d+%.?%d*)$")
    if not zonePart then xStr, yStr = msg:match("^(%d+%.?%d*)%s*[,%s]%s*(%d+%.?%d*)$") end
    if not xStr or not yStr then
        print("|cffff0000FlareUI:|r " .. L["Invalid coordinates. Try |cffffff00/way|r for usage."])
        return
    end

    local mapID
    if zonePart then
        if zonePart:match("^#%d+$") then
            mapID = tonumber(zonePart:sub(2))
        else
            mapID = GetMapIDByName(zonePart)
            if not mapID then print("|cffff0000FlareUI:|r " .. L["Could not find a map named '%s'."]:format(zonePart)) return end
        end
    else
        mapID = C_Map.GetBestMapForUnit("player")
    end
    if not mapID then print("|cffff0000FlareUI:|r " .. L["Could not determine the current map."]) return end
    if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(mapID) then
        print("|cffff0000FlareUI:|r " .. L["Map pins are not allowed on this map."])
        return
    end

    local x, y = tonumber(xStr) / 100, tonumber(yStr) / 100
    if x > 1 or y > 1 then print("|cffff0000FlareUI:|r " .. L["Coordinates must be between 0 and 100."]) return end

    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)

    local mapInfo = C_Map.GetMapInfo(mapID)
    local mapName = mapInfo and mapInfo.name or ("Map #" .. mapID)
    print(string.format("|cff00ff00FlareUI:|r " .. L["Pin set for %s at %.1f, %.1f"], mapName, tonumber(xStr), tonumber(yStr)))
end

-- TomTom keeps /way: two addons on one slash command means either could win
function Tweaks:TomTomOwnsWay()
    return C_AddOns.IsAddOnLoaded("TomTom")
end

local function InitWay()
    local db = GetDb()
    if db and db.way and not SLASH_FLAREWAY1 and not Tweaks:TomTomOwnsWay() then
        SLASH_FLAREWAY1 = "/way"
        SlashCmdList["FLAREWAY"] = HandleWay
    end
end

--------------------------------------------------
-- 17. MAIL, MERCHANT, ALERTS, PET FOOD, LOOT CONFIRMATIONS, COMBAT NAMEPLATES
--------------------------------------------------
-- Every character is noted (name, realm, faction, class) for the Mail Address Book, whether the
-- option is on or not, so the list is full the day it is switched on
local function NoteCharacter()
    local me = ns.CharDB and ns.CharDB()
    if not me then return end
    me.mailName = UnitName("player")
    me.realm = GetRealmName()
    me.faction = UnitFactionGroup("player")
    me.class = select(2, UnitClass("player"))
end

-- Mail Address Book: a button beside Send Mail's "To:" box lists the account's other characters on
-- this realm and faction, and this character's last recipient
local function MailMenu(owner)
    local box = _G.SendMailNameEditBox
    if not box then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        local me = ns.CharDB and ns.CharDB() or {}
        local function Pick(name) return function() box:SetText(name); box:SetCursorPosition(#name) end end
        if me.lastMailTo then
            root:CreateTitle(L["Last Sent To"])
            root:CreateButton(me.lastMailTo, Pick(me.lastMailTo))
        end
        local list = {}
        for _, char in pairs(ns.db.global.characters or {}) do
            if char ~= me and char.mailName and char.realm == me.realm and char.faction == me.faction then
                list[#list + 1] = char
            end
        end
        table.sort(list, function(a, b) return a.mailName < b.mailName end)
        root:CreateTitle(L["Your Characters"])
        if #list == 0 then root:CreateTitle(L["Log in on your other characters to list them."]) end
        for _, char in ipairs(list) do
            local color = char.class and C_ClassColor.GetClassColor(char.class)
            local text = color and color:WrapTextInColorCode(char.mailName) or char.mailName
            root:CreateButton(text, Pick(char.mailName))
        end
    end)
end

local function InitMailBook()
    EventUtil.ContinueOnAddOnLoaded("Blizzard_MailFrame", function()
        local box = _G.SendMailNameEditBox
        -- not in the Gamepad UI: the controller cursor would land on it and run its menu (addon code)
        -- inside Blizzard's navigation, which hangs the client
        if not box or Tweaks.mailButton or ns.IsGamepadUI() then return end
        local button = CreateFrame("Button", nil, box)
        button:SetSize(22, 22)
        button:SetPoint("LEFT", box, "RIGHT", 2, 0)
        button:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
        button:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
        button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        button:SetScript("OnClick", MailMenu)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["Mail Address Book"])
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", GameTooltip_Hide)
        Tweaks.mailButton = button
        local db = GetDb()
        button:SetShown(db and db.mailBook or false)
        -- the last recipient, once the mail has gone
        hooksecurefunc("SendMailFrame_SendMail", function() Tweaks.mailPending = box:GetText() end)
        Tweaks:RegisterEvent("MAIL_SEND_SUCCESS", function()
            local me = ns.CharDB and ns.CharDB()
            local to = Tweaks.mailPending
            if me and to and to ~= "" then me.lastMailTo = to end
            Tweaks.mailPending = nil
        end)
    end)
end

local function ApplyMailBook()
    local db = GetDb()
    if Tweaks.mailButton then Tweaks.mailButton:SetShown(db and db.mailBook or false) end
end

-- Gray Out Known Items: known recipes (or any known item) greyed out at merchants
local knownMarked = {}
local function MarkKnownItems()
    local db = GetDb()
    for button in pairs(knownMarked) do
        SetItemButtonDesaturated(button, false)
        knownMarked[button] = nil
    end
    if not (db and db.merchantKnown) or not (MerchantFrame and MerchantFrame.selectedTab == 1) then return end
    local perPage = MERCHANT_ITEMS_PER_PAGE or 10
    for i = 1, perPage do
        local index = (MerchantFrame.page - 1) * perPage + i
        local button = _G["MerchantItem" .. i .. "ItemButton"]
        local data = button and button:IsShown() and C_TooltipInfo.GetMerchantItem(index)
        for _, line in ipairs(data and data.lines or {}) do
            if line.leftText == ITEM_SPELL_KNOWN then
                SetItemButtonDesaturated(button, true)
                SetItemButtonTextureVertexColor(button, 0.6, 0.6, 0.6)
                SetItemButtonNameFrameVertexColor(_G["MerchantItem" .. i], 0.5, 0.5, 0.5)
                knownMarked[button] = true
                break
            end
        end
    end
end

-- Enhanced Vendor Purchases (tweaks.bulkBuy), after EnhanceQoL's (the idea only): Shift+click on a
-- merchant item opens Blizzard's amount box with room for many stacks, or for many of an item that
-- doesn't stack, capped by gold, stock and bag room. Stack and MAX buttons under the box fill in one
-- stack or the most you can buy. It buys one stack (or one item) at a time and waits for each to
-- reach the bags, with its progress above the merchant window; an error, the merchant closing, the
-- item moving on the list or no delivery within five seconds stops it. Items paid in other items or
-- currencies keep Blizzard's own box.
local Bulk = { queue = nil }

-- room in the bags for itemID: empty slots that take it, plus what its partial stacks still hold
function Bulk.BagRoom(itemID, stackSize)
    local family = C_Item.GetItemFamily(itemID) or 0
    local room = 0
    for bag = BACKPACK_CONTAINER, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
        local free, bagFamily = C_Container.GetContainerNumFreeSlots(bag)
        if free and free > 0 and (not bagFamily or bagFamily == 0 or bit.band(bagFamily, family) ~= 0) then
            room = room + free * stackSize
        end
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == itemID and info.stackCount then
                room = room + math.max(0, stackSize - info.stackCount)
            end
        end
    end
    return room
end

-- the line above the merchant window; hides itself after a while
function Bulk.Say(text, r, g, b, hideAfter)
    local line = Bulk.progress
    if not line then
        line = MerchantFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        line:SetPoint("BOTTOM", MerchantFrame, "TOP", 0, 4)
        Bulk.progress = line
    end
    if Bulk.sayTimer then Bulk.sayTimer:Cancel() Bulk.sayTimer = nil end
    line:SetText(text)
    line:SetTextColor(r or 1, g or 0.82, b or 0)
    line:Show()
    if hideAfter then Bulk.sayTimer = C_Timer.NewTimer(hideAfter, function() line:Hide() end) end
end

function Bulk.Stop(early)
    if Bulk.timer then Bulk.timer:Cancel() Bulk.timer = nil end
    local q = Bulk.queue
    Bulk.queue = nil
    Bulk.events:UnregisterAllEvents()
    if q and early and Bulk.progress then
        Bulk.Say(L["Purchase stopped: %d of %d bought."]:format(q.total - q.left - (q.pending or 0), q.total), 1, 0.3, 0.3, 5)
    end
end

-- buys the next stack, or finishes
function Bulk.Next()
    local q = Bulk.queue
    if Bulk.timer then Bulk.timer:Cancel() Bulk.timer = nil end
    if not q then return end
    q.pending = 0
    if q.left <= 0 then
        Bulk.Say(L["Bought %d of %d."]:format(q.total, q.total), 0.4, 1, 0.4, 3)
        Bulk.Stop()
        return
    end
    -- the merchant closed, or the list changed under the index
    if not (MerchantFrame and MerchantFrame:IsShown()) or GetMerchantItemID(q.index) ~= q.itemID then Bulk.Stop(true) return end
    local amount = math.min(q.left, q.perBuy)
    Bulk.Say(L["Buying %d of %d..."]:format(q.total - q.left, q.total))
    q.left, q.pending = q.left - amount, amount
    BuyMerchantItem(q.index, amount)
    -- nothing reached the bags in five seconds: stop rather than guess
    Bulk.timer = C_Timer.NewTimer(5, function() Bulk.Stop(true) end)
end

function Bulk.Start(index, total, perBuy)
    Bulk.Stop()
    Bulk.queue = { index = index, itemID = GetMerchantItemID(index), total = total, left = total, perBuy = perBuy }
    Bulk.events:RegisterEvent("BAG_UPDATE_DELAYED")
    Bulk.events:RegisterEvent("UI_ERROR_MESSAGE")
    Bulk.events:RegisterEvent("MERCHANT_CLOSED")
    Bulk.Next()
end

-- puts an amount into Blizzard's box, as its arrows would
function Bulk.SetAmount(amount)
    local split = _G.StackSplitFrame
    if not (split and split:IsShown() and split.owner == Bulk.owner) then return end
    amount = math.max(split.minSplit or 1, math.min(split.maxStack or amount, amount))
    split.split, split.typing = amount, 0
    if split.UpdateStackText then split:UpdateStackText() else split.StackSplitText:SetText(amount) end
    if split.LeftButton then split.LeftButton:SetEnabled(amount > (split.minSplit or 1)) end
    if split.RightButton then split.RightButton:SetEnabled(amount < (split.maxStack or amount)) end
end

-- Stack and MAX, under the box while it is FlareUI's
function Bulk.Buttons(split)
    if Bulk.stackButton then return end
    local function Make(text, onClick)
        local b = CreateFrame("Button", nil, split, "UIPanelButtonTemplate")
        b:SetSize(60, 22)
        b:SetText(text)
        b:SetScript("OnClick", onClick)
        b:Hide()
        return b
    end
    Bulk.stackButton = Make(L["Stack"], function() Bulk.SetAmount(Bulk.owner.stack or 1) end)
    Bulk.maxButton = Make(L["MAX"], function() Bulk.SetAmount(Bulk.owner.cap or 1) end)
    Bulk.stackButton:SetPoint("TOPRIGHT", split, "BOTTOM", -2, 2)
    Bulk.maxButton:SetPoint("TOPLEFT", split, "BOTTOM", 2, 2)
    split:HookScript("OnHide", function()
        Bulk.stackButton:Hide()
        Bulk.maxButton:Hide()
    end)
end

function Bulk.Init()
    Bulk.events = CreateFrame("Frame")
    Bulk.events:SetScript("OnEvent", function(_, event)
        if event == "BAG_UPDATE_DELAYED" then Bulk.Next() else Bulk.Stop(true) end
    end)
    -- the amount box answers this frame's SplitStack, so no Blizzard button is changed
    Bulk.owner = CreateFrame("Frame", nil, UIParent)
    Bulk.owner.SplitStack = function(owner, split)
        if split and split > 0 and owner.index then Bulk.Start(owner.index, split, owner.perBuy) end
    end
    if not MerchantItemButton_OnModifiedClick then return end
    hooksecurefunc("MerchantItemButton_OnModifiedClick", function(button)
        local db = GetDb()
        if not (db and db.bulkBuy) or ns.IsGamepadUI() then return end
        if MerchantFrame.selectedTab ~= 1 or not IsModifiedClick("SPLITSTACK") then return end
        local split = _G.StackSplitFrame
        if not split then return end
        -- Blizzard opened its box (stacking items), or opened nothing (an item that doesn't stack);
        -- a chat link or a dress-up leaves it closed for another button
        local index = button:GetID()
        local perBuy = GetMerchantItemMaxStack(index)
        local opened = split:IsShown() and split.owner == button
        if not opened and not (perBuy == 1 and not split:IsShown()) then return end
        if button.extendedCost or button.showNonrefundablePrompt then return end
        -- Shift+click with the chat box open puts a link in it
        if not opened and ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() then return end
        local info = C_MerchantFrame.GetItemInfo(index)
        local itemID = GetMerchantItemID(index)
        if not (info and itemID and perBuy and perBuy > 0) or info.hasExtendedCost then return end
        local unit = math.max(1, info.stackCount or 1)
        local cap = math.huge
        if info.price and info.price > 0 then cap = math.floor(GetMoney() / (info.price / unit)) end
        if info.numAvailable and info.numAvailable >= 0 then cap = math.min(cap, info.numAvailable * unit) end
        local stackSize = C_Item.GetItemMaxStackSize(itemID) or perBuy
        cap = math.min(cap, Bulk.BagRoom(itemID, stackSize))
        cap = math.floor(cap / unit) * unit
        if cap < unit then return end   -- nothing affordable or no room: Blizzard's box (or nothing) stays
        local owner = Bulk.owner
        owner.index, owner.perBuy, owner.cap = index, math.max(unit, math.floor(perBuy / unit) * unit), cap
        owner.stack = math.min(cap, math.max(unit, math.floor(stackSize / unit) * unit))
        owner:ClearAllPoints()
        owner:SetAllPoints(button)
        split:OpenStackSplitFrame(cap, owner, "BOTTOMLEFT", "TOPLEFT", unit)
        Bulk.Buttons(split)
        Bulk.stackButton:SetShown(cap > 1)
        Bulk.maxButton:SetShown(cap > 1)
    end)
end

-- Wider Vendor Window (tweaks.merchantWide, reload): 20 items a page in four columns, after
-- EnhanceQoL's. Blizzard's page size is set before its merchant code first runs; items 13 to 20 are
-- made from Blizzard's own template; the Buyback tab gets Blizzard's narrow window back. Not in the
-- Gamepad UI (its own navigation knows Blizzard's layout).
do
    local Wide = {}
    Tweaks.WideMerchant = Wide
    local NARROW, COLUMN = 336, 165   -- Blizzard's width; one more column of items (153 + 12)
    local PER_PAGE = 20

    function Wide.On()
        local db = GetDb()
        return db and db.enabled ~= false and db.merchantWide and not ns.IsGamepadUI() or false
    end

    local rightBorder
    local function Layout(merchantTab)
        local frame = MerchantFrame
        if merchantTab then
            frame:SetWidth(NARROW + 2 * COLUMN)
            local item11 = _G.MerchantItem11
            item11:ClearAllPoints()
            item11:SetPoint("TOPLEFT", _G.MerchantItem2, "TOPRIGHT", 12, 0)
            for i = 11, PER_PAGE do
                local item = _G["MerchantItem" .. i]
                if i > 12 then
                    item:ClearAllPoints()
                    if i % 2 == 1 then
                        item:SetPoint("TOPLEFT", _G["MerchantItem" .. (i - 2)], "BOTTOMLEFT", 0, -8)
                    else
                        item:SetPoint("TOPLEFT", _G["MerchantItem" .. (i - 1)], "TOPRIGHT", 12, 0)
                    end
                end
                item:Show()
            end
            _G.MerchantNextPageButton:ClearAllPoints()
            _G.MerchantNextPageButton:SetPoint("CENTER", frame, "BOTTOMRIGHT", -26, 96)
            -- the bottom border art, on the right as well
            if not rightBorder then
                rightBorder = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
                rightBorder:SetAtlas("UI-Merchant-BotFrame")
                rightBorder:SetSize(334, 61)
                rightBorder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 26)
            end
            rightBorder:Show()
        else
            frame:SetWidth(NARROW)
            local item11 = _G.MerchantItem11
            item11:ClearAllPoints()
            item11:SetPoint("TOPLEFT", _G.MerchantItem9, "BOTTOMLEFT", 0, -15)
            for i = 13, PER_PAGE do _G["MerchantItem" .. i]:Hide() end
            _G.MerchantNextPageButton:ClearAllPoints()
            _G.MerchantNextPageButton:SetPoint("CENTER", frame, "BOTTOMLEFT", 310, 96)
            if rightBorder then rightBorder:Hide() end
        end
    end

    function Wide.Init()
        if not (Wide.On() and MerchantFrame and MerchantFrame_UpdateMerchantInfo and _G.MerchantItem12) then return end
        MERCHANT_ITEMS_PER_PAGE = PER_PAGE
        for i = 13, PER_PAGE do
            if not _G["MerchantItem" .. i] then CreateFrame("Frame", "MerchantItem" .. i, MerchantFrame, "MerchantItemTemplate") end
        end
        hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function() Layout(true) end)
        if MerchantFrame_UpdateBuybackInfo then hooksecurefunc("MerchantFrame_UpdateBuybackInfo", function() Layout(false) end) end
    end
end

local function InitMerchantKnown()
    if MerchantFrame_UpdateMerchantInfo then hooksecurefunc("MerchantFrame_UpdateMerchantInfo", MarkKnownItems) end
    -- the Buyback tab reuses the same buttons and never clears their greying itself
    if MerchantFrame_UpdateBuybackInfo then hooksecurefunc("MerchantFrame_UpdateBuybackInfo", MarkKnownItems) end
end

-- Alert Sounds: flashes the game's taskbar icon and plays an alert on the Master channel, so it is
-- heard with sound effects off or the game in the background
local ALERT_EVENTS = { "READY_CHECK", "CONFIRM_SUMMON", "RESURRECT_REQUEST", "PARTY_INVITE_REQUEST", "LFG_PROPOSAL_SHOW" }
-- Blizzard already plays this sound and flashes the icon for these, on the sound effects channel
Tweaks.BLIZZARD_SOUNDS = { READY_CHECK = true, LFG_PROPOSAL_SHOW = true }
local function OnAlert(_, event, initiator)
    local db = GetDb()
    if not (db and db.alertSounds) then return end
    -- a ready check the player started themself asks nothing of them (Blizzard stays quiet too)
    if event == "READY_CHECK" and initiator and canaccessvalue(initiator) and UnitIsUnit("player", initiator) then
        return
    end
    -- heard twice, a beat apart, when Blizzard's own sound already plays
    if Tweaks.BLIZZARD_SOUNDS[event] and GetCVarBool("Sound_EnableSFX") then return end
    if FlashClientIcon then FlashClientIcon() end
    PlaySound(SOUNDKIT.READY_CHECK, "Master")
end

local function InitAlerts()
    local frame = CreateFrame("Frame")
    for _, event in ipairs(ALERT_EVENTS) do frame:RegisterEvent(event) end
    frame:SetScript("OnEvent", OnAlert)
end

-- Pet Food in Bags: a paw on the food the hunter pet eats (C_PetInfo.CanPetEatItem)
local PAW = "Interface\\Icons\\Ability_Hunter_BeastTraining"
local function MarkPetFood(container)
    local db = GetDb()
    local hasPet = db and db.petFood and UnitExists("pet") and select(2, UnitClass("player")) == "HUNTER"
    -- nothing to mark, and no mark to take back
    if not hasPet and not Tweaks.petFoodMarked then return end
    for _, button in container:EnumerateValidItems() do
        local mark = button.FlareUI_PetFood
        local itemID = hasPet and C_Container.GetContainerItemID(button:GetBagID(), button:GetID())
        local food = itemID and C_PetInfo.CanPetEatItem(itemID)
        if food and not mark then
            mark = button:CreateTexture(nil, "OVERLAY", nil, 2)
            mark:SetSize(14, 14)
            mark:SetPoint("TOPLEFT", 2, -2)
            mark:SetTexture(PAW)
            mark:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            button.FlareUI_PetFood = mark
            Tweaks.petFoodMarked = true
        end
        if mark then mark:SetShown(food and true or false) end
    end
end

local function UpdatePetFood()
    for _, container in ipairs(Tweaks.petFoodBags or {}) do
        if container:IsShown() then MarkPetFood(container) end
    end
end

local function InitPetFood()
    Tweaks.petFoodBags = {}
    local names = { "ContainerFrameCombinedBags" }
    for i = 1, NUM_CONTAINER_FRAMES or 13 do names[#names + 1] = "ContainerFrame" .. i end
    for _, name in ipairs(names) do
        local container = _G[name]
        if type(container) == "table" and container.UpdateItems and container.EnumerateValidItems then
            hooksecurefunc(container, "UpdateItems", MarkPetFood)
            Tweaks.petFoodBags[#Tweaks.petFoodBags + 1] = container
        end
    end
    local frame = CreateFrame("Frame")
    frame:RegisterUnitEvent("UNIT_PET", "player")
    frame:SetScript("OnEvent", UpdatePetFood)
end

-- Skip Loot Confirmations: "will bind to you" when looting, and when rolling Need, Greed or Disenchant
local function InitLootConfirm()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("LOOT_BIND_CONFIRM")
    frame:RegisterEvent("CONFIRM_LOOT_ROLL")
    -- a Disenchant roll asks in the same dialog, with other text
    pcall(frame.RegisterEvent, frame, "CONFIRM_DISENCHANT_ROLL")
    frame:SetScript("OnEvent", function(_, event, id, rollType)
        local db = GetDb()
        if not (db and db.skipLootConfirm) then return end
        -- after Blizzard's own dialog is up, so it can be closed
        C_Timer.After(0, function()
            if event == "LOOT_BIND_CONFIRM" then
                ConfirmLootSlot(id)
                StaticPopup_Hide("LOOT_BIND")
            else
                ConfirmLootRoll(id, rollType)
                StaticPopup_Hide("CONFIRM_LOOT_ROLL")
            end
        end)
    end)
end

-- Enemy Nameplates in Combat Only: shown when a fight starts, hidden after. The player's own setting
-- is kept and put back when the option goes off.
local function SetEnemyPlates(on)
    pcall(SetCVar, "nameplateShowEnemies", on and 1 or 0)
end

local function ApplyCombatPlates()
    local db = GetDb()
    local forced = ForcedCVars("combatPlates")
    if InCombatLockdown() then return end
    if db and db.combatPlates then
        if forced.combatPlates == nil then forced.combatPlates = GetCVar("nameplateShowEnemies") or "1" end
        SetEnemyPlates(false)
    elseif forced.combatPlates ~= nil then
        pcall(SetCVar, "nameplateShowEnemies", forced.combatPlates)
        forced.combatPlates = nil
    end
end

local function InitCombatPlates()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", function(_, event)
        local db = GetDb()
        if event == "PLAYER_REGEN_DISABLED" then
            -- still allowed: combat lockdown begins right after this event
            if db and db.combatPlates then SetEnemyPlates(true) end
        else
            ApplyCombatPlates()
        end
    end)
    ApplyCombatPlates()
end

--------------------------------------------------
-- 17b. UI SCALE (Quality of Life > Advanced), as EnhanceQoL's "Login UI scaling": a preset applied
-- as you log in, account-wide (db.global.uiScale; db.global.uiScaleCustom for Custom). It sets
-- useUiScale and uiscale, then UIParent's scale itself (Blizzard's slider stops at 65%). nil or
-- "blizzard" touches nothing; going back to it puts the two CVars back as they were before.
--------------------------------------------------
do
    local UIScale = {}
    Tweaks.UIScale = UIScale
    -- pixel perfect for each screen height (768 / height), and for Windows' 125% display scaling
    UIScale.PRESETS = { ["4k"] = 768 / 2160, ["1440p"] = 768 / 1440, ["1440p125"] = 768 / 1440 * 1.25,
                        ["1080p"] = 768 / 1080, ["1080p125"] = 768 / 1080 * 1.25 }
    UIScale.CUSTOM_MIN, UIScale.CUSTOM_MAX = 0.3, 2

    -- the scale the preset asks for, or nil for Blizzard's
    function UIScale.Value()
        local db, g = GetDb(), ns.db and ns.db.global
        if not (db and db.enabled and g) then return nil end
        local preset = g.uiScale
        if preset == "auto" then
            local _, height = GetPhysicalScreenSize()
            if not (height and height > 0) then return nil end
            return 768 / height
        elseif preset == "custom" then
            local value = tonumber(g.uiScaleCustom) or 1
            return math.max(UIScale.CUSTOM_MIN, math.min(UIScale.CUSTOM_MAX, value))
        end
        return UIScale.PRESETS[preset]
    end

    function UIScale.Apply()
        local g = ns.db and ns.db.global
        if not g or InCombatLockdown() then return end
        local value = UIScale.Value()
        if value then
            if not g.uiScaleBack then
                g.uiScaleBack = { use = GetCVar("useUiScale"), scale = GetCVar("uiscale") }
            end
            if GetCVar("useUiScale") ~= "1" then SetCVar("useUiScale", "1") end
            if math.abs((tonumber(GetCVar("uiscale")) or 0) - value) > 0.0001 then
                SetCVar("uiscale", ("%.6f"):format(value))
            end
            if math.abs(UIParent:GetScale() - value) > 0.0001 then
                UIParent:SetScale(value)
                -- the undocked chat windows were put back at the old scale
                ns.RestoreUndockedChat()
            end
        elseif g.uiScaleBack then
            -- the engine scales UIParent from the two CVars again
            local back = g.uiScaleBack
            g.uiScaleBack = nil
            if back.use then SetCVar("useUiScale", back.use) end
            if back.scale then SetCVar("uiscale", back.scale) end
        end
    end

    -- once, as you log in (a change asks for a reload)
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_LOGIN")
    events:SetScript("OnEvent", function() UIScale.Apply() end)
end

--------------------------------------------------
-- 18. PUBLIC
--------------------------------------------------
-- Live re-apply for the options that need no reload
function Tweaks:Refresh()
    if not self.initialized then return end
    ApplyCamera()
    Tweaks.ApplyMapFade()
    if ns.Fishing then ns.Fishing:Apply() end
    ApplyPortraitNumbers()
    ApplyTips()
    ApplyNameplateCombo()
    ApplyQuestTags()
    ApplyHideLevelAll()
    ApplyHideNamesAll()
    LevelName.ApplyAll()
    UpdateTrainAll()
    ApplyMailBook()
    ApplyCombatPlates()
    UpdatePetFood()
    if MerchantFrame and MerchantFrame:IsShown() and MerchantFrame_UpdateMerchantInfo then MerchantFrame_UpdateMerchantInfo() end
    -- Blizzard's merchant update above shows the button again when Sell Junk goes off
    if MerchantSellAllJunkButton and MerchantSellAllJunkButton:IsShown() then
        local db = GetDb()
        if db and db.sellJunk then MerchantSellAllJunkButton:Hide() end
    end
end

-- With the module off, Init never runs: CVars FlareUI forced go back here (Core asks before the switch)
function Tweaks:ShouldLoad()
    local tweaks = ns.db and ns.db.profile and ns.db.profile.tweaks
    if tweaks and tweaks.enabled == false and ns.db.global and not InCombatLockdown() then
        local function Take(key)
            local forced = ForcedCVars(key)
            local value = forced[key]
            forced[key] = nil
            return value
        end
        local maxZoom, zoomSpeed, tips, plates = Take("maxZoom"), Take("zoomSpeed"), Take("tips"), Take("combatPlates")
        local mapFade = Take("mapFade")
        if mapFade ~= nil then pcall(SetCVar, "mapFade", mapFade) end
        if maxZoom then pcall(SetCVar, "cameraDistanceMaxZoomFactor", Tweaks.StoredCVar(maxZoom, "cameraDistanceMaxZoomFactor")) end
        if zoomSpeed then pcall(SetCVar, "cameraZoomSpeed", Tweaks.StoredCVar(zoomSpeed, "cameraZoomSpeed")) end
        if tips then Tweaks.RestoreTips(tips) end
        if plates ~= nil then pcall(SetCVar, "nameplateShowEnemies", plates) end
    end
    return true
end

function Tweaks:Init()
    if self.initialized then return end
    local db = GetDb()
    if not db then return end
    self.initialized = true

    KeepLFGPagesAttached()
    if db.moveAnyFrame then StartMoveAnyFrame() end
    if db.syncUI then InitSyncUI() end
    InitVendor()
    InitDurability()
    InitCameraLoot()
    InitHide()
    InitAutoDelete()
    InitAutoQuests()
    InitTrainAll()
    InitBagTooltip()
    InitWay()
    InitLayoutPerMode()
    NoteCharacter()
    InitMailBook()
    InitMerchantKnown()
    Bulk.Init()
    Tweaks.WideMerchant.Init()
    InitAlerts()
    InitPetFood()
    InitLootConfirm()
    InitCombatPlates()
    ApplyNameplateCombo()
    ApplyQuestTags()
    ApplyHideLevelAll()
    ApplyHideNamesAll()
    LevelName.ApplyAll()
    UnclampPartyFrame()
end
