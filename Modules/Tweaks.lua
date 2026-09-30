local _, ns = ...

--------------------------------------------------
-- 1. MODULE REGISTRATION
-- Small quality-of-life tweaks, each a toggle:
--   Windows & Settings  Move Any Frame, Sync Blizz UI (account-wide settings)
--   Vendor              Sell Junk Automatically, Repair Automatically, Durability Warning
--   Camera              Max Camera Zoom, Faster Camera Zoom
--   Nameplates          Combo Points under the target's nameplate, Tag Quest Objectives
--   Convenience         Faster Auto Loot, Auto-Type DELETE, Train All button
--   Hide                Error Messages, Zone Text, Party Title, Portrait Numbers, Contextual Tips,
--                       World Refresh Dialog, Addon Drawer, Quest Tracker in Boss Fights
--   Always on           Party frames unclamped from the screen edge, the world refresh toast in
--                       FlareUI's border bronze (no toggles)
-- Everything applies live except the ones that replace Blizzard scripts (those ask for a reload).
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
-- Every panel Blizzard registers in UIPanelWindows (plus load-on-demand ones as their addon
-- loads) becomes draggable, Ctrl+wheel scales it, Shift+right-click resets the position and
-- Ctrl+right-click the scale. Positions / scales are stored per frame name in the profile and
-- re-applied after Blizzard's panel manager places the frame.
--------------------------------------------------
local MIN_SCALE, MAX_SCALE, SCALE_STEP = 0.5, 2.0, 0.1
-- panels that must stay where Blizzard puts them
local MOVE_EXCLUDED = {
    EditModeManagerFrame = true, GameMenuFrame = true, SettingsPanel = true, HelpFrame = true,
    ChatConfigFrame = true, StaticPopup1 = true,
}
local moveFrames = {}          -- name -> frame (already set up)
local moveApplyQueued = false
local movePending = {}         -- frames whose saved position must be applied after combat
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

local function ApplySavedPosition(frame)
    if moveSuspended then return end
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

local function QueueApplyAll()
    if moveApplyQueued or moveSuspended then return end
    moveApplyQueued = true
    C_Timer.After(0, function()
        moveApplyQueued = false
        for _, frame in pairs(moveFrames) do
            if frame:IsShown() then ApplySavedPosition(frame) end
        end
    end)
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
    -- keep the top-left corner where it is so the frame does not jump while scaling
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
    if not CanTouch(frame) then return end
    frame:SetMovable(true)
    frame:StartMoving()
    frame.moveDragging = true
end

local function OnDragStop(handle)
    local frame = handle.moveTarget or handle
    if not frame.moveDragging then return end
    frame.moveDragging = false
    frame:StopMovingOrSizing()
    SavePosition(frame)
end

local function OnMouseWheel(handle, delta)
    if not IsControlKeyDown() then return end
    local frame = handle.moveTarget or handle
    SetFrameScale(frame, frame:GetScale() + SCALE_STEP * delta)
end

local function OnMouseUp(handle, button)
    if button ~= "RightButton" then return end
    local frame = handle.moveTarget or handle
    if IsShiftKeyDown() then ResetPosition(frame) end
    if IsControlKeyDown() then
        local store = GetFrameStore(frame.moveName)
        if store then store.scale = nil end
        if CanTouch(frame) then frame:SetScale(1) end
        SavePosition(frame)
    end
    -- plain right-click on a bag window opens its sorting menu, wherever you click
    if not IsShiftKeyDown() and not IsControlKeyDown() then
        local dropdown = frame.PortraitButton
        if dropdown and dropdown.OpenMenu then
            if dropdown.IsMenuOpen and dropdown:IsMenuOpen() then
                pcall(dropdown.CloseMenu, dropdown)
            else
                pcall(dropdown.OpenMenu, dropdown)
            end
        end
    end
end

-- Only the header drags. Enabling the mouse on the window itself (or its NineSlice) would swallow
-- every click inside it, so those are never used as handles.
local HEADER_HEIGHT = 26
local CLOSE_BUTTON_ROOM = 40

local function SetupHandle(frame, handle)
    if not handle or handle.moveHooked then return end
    handle.moveHooked = true
    handle.moveTarget = frame
    if handle.EnableMouse then handle:EnableMouse(true) end
    if handle.RegisterForDrag then handle:RegisterForDrag("LeftButton") end
    handle:HookScript("OnDragStart", OnDragStart)
    handle:HookScript("OnDragStop", OnDragStop)
    handle:HookScript("OnMouseUp", OnMouseUp)
end

-- Ctrl+wheel scales from anywhere over the window. EnableMouseWheel does not block clicks, and a
-- child that handles the wheel itself (scroll frames) still wins.
local function SetupWheel(frame)
    if frame.moveWheelHooked or not frame.EnableMouseWheel then return end
    frame.moveWheelHooked = true
    frame.moveTarget = frame
    frame:EnableMouseWheel(true)
    frame:HookScript("OnMouseWheel", OnMouseWheel)
end

-- the title bar if the frame has one, otherwise a strip across the top that sits below the
-- frame's own buttons and stops short of the close button
local function GetHeaderHandle(frame)
    if frame.TitleContainer then return frame.TitleContainer end
    if frame.moveStrip then return frame.moveStrip end
    local strip = CreateFrame("Frame", nil, frame)
    strip:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    strip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -CLOSE_BUTTON_ROOM, 0)
    strip:SetHeight(HEADER_HEIGHT)
    strip:SetFrameLevel(frame:GetFrameLevel())
    frame.moveStrip = strip
    return strip
end

local function SetupMovableFrame(name)
    if moveSuspended or moveFrames[name] or MOVE_EXCLUDED[name] then return end
    local frame = _G[name]
    if type(frame) ~= "table" or not frame.GetObjectType or not frame.StartMoving then return end
    frame.moveName = name
    moveFrames[name] = frame
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    SetupHandle(frame, GetHeaderHandle(frame))
    SetupWheel(frame)
    frame:HookScript("OnShow", function(f) C_Timer.After(0, function() ApplySavedPosition(f) end) end)
    if frame:IsShown() then ApplySavedPosition(frame) end
end

local function ScanUIPanels()
    local windows = _G.UIPanelWindows
    if type(windows) ~= "table" then return end
    for name in pairs(windows) do SetupMovableFrame(name) end
end

-- Bags are not UI panels, so they have to be named. Every container frame carries an invisible
-- "portrait button router" that covers the whole title bar and sends clicks to the sorting menu,
-- which also swallows the drag. Both it and the portrait button are disabled here; the sorting
-- menu is reached with a plain right-click anywhere on the window instead (see OnMouseUp).
local function UnrouteBagTitle(frame)
    if frame.bagRouterFixed then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        if child.routeToSibling == "PortraitButton" and child.EnableMouse then
            child:EnableMouse(false)
            frame.bagRouterFixed = true
        end
    end
    if frame.PortraitButton and frame.PortraitButton.EnableMouse then
        frame.PortraitButton:EnableMouse(false)
    end
end

local function ScanBagFrames()
    local names = { "ContainerFrameCombinedBags" }
    for i = 1, 13 do names[#names + 1] = "ContainerFrame" .. i end
    for _, name in ipairs(names) do
        SetupMovableFrame(name)
        local frame = moveFrames[name]
        if frame then UnrouteBagTitle(frame) end
    end
end

local function InitMoveAnyFrame()
    ScanUIPanels()
    ScanBagFrames()
    -- load-on-demand panels register themselves when their addon loads
    Tweaks:RegisterEvent("ADDON_LOADED", function() C_Timer.After(0, ScanUIPanels) end)
    -- Blizzard's panel manager re-anchors panels as they open / close; put ours back afterwards
    local delegate = _G.FramePositionDelegate
    if delegate then
        for _, method in ipairs({ "SetUIPanel", "UpdateUIPanelPositions", "ShowUIPanel" }) do
            if type(delegate[method]) == "function" then hooksecurefunc(delegate, method, QueueApplyAll) end
        end
    end
    hooksecurefunc("UpdateUIPanelPositions", QueueApplyAll)
    -- bags re-anchor (and re-scale) themselves every time they open or the layout changes
    hooksecurefunc("UpdateContainerFrameAnchors", function() ScanBagFrames() QueueApplyAll() end)
    Tweaks:RegisterEvent("BAG_UPDATE_DELAYED", ScanBagFrames)
    Tweaks:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        for frame in pairs(movePending) do movePending[frame] = nil; if frame:IsShown() then ApplySavedPosition(frame) end end
    end)
end

-- Forever's gamepad UI drives these same windows and trips over what this feature does to them: the
-- fields written on Blizzard panels and the panel-manager hooks tainted the Character panel opened
-- from the gamepad radial, and opening bags or the quest log from the gamepad menu froze the client
-- (2026-09-25). Hooks cannot be taken back once set, so it only ever starts in keyboard mode - at
-- login, or on the switch back. A switch to the gamepad UI after it has started stops it placing
-- windows at once, but what is already hooked stays hooked until a reload, so it asks for one.
-- The saved positions live in the profile throughout.
-- A private frame for the event: an AceEvent object keeps one callback per event.
local moveStarted = false

local function OnInterfaceTransition()
    if ns.IsGamepadUI() then
        if moveStarted and not moveSuspended then
            moveSuspended = true
            Print("Move Any Frame stands aside in gamepad mode - type |cffffff00/reload|r to finish switching.")
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
-- Snapshot of the character-specific Blizzard settings into the account-wide store
-- (ns.db.global.uiSync): CVars from the list below (filtered by what this client knows), the
-- active Edit Mode layout (by name), chat window setup and bag flags. Saved on logout and after
-- settings change; applied on login to any character whose applied stamp differs.
-- One character is the source and only its snapshot is kept. The source is chosen from that
-- character itself and named by GUID, so nothing lists characters: no roster to go stale when one
-- is deleted, and nothing to split in two when the client changes what UnitName returns.
--------------------------------------------------
local SYNC_CVARS = ns.SYNC_CVARS or {}   -- filled in Modules/TweaksCVars.lua
local syncSaveTimer

-- AceEvent keeps ONE callback per object per event, so two features registering the same event on
-- Tweaks silently replace each other. InitDurability registers PLAYER_ENTERING_WORLD after
-- InitSyncUI does, and was quietly taking the sync's handler away - which is why snapshots saved
-- (those ride other events) but nothing was ever loaded. The sync owns its own object now.
local SyncEvents = {}
LibStub("AceEvent-3.0"):Embed(SyncEvents)

-- The logged-in character as a source record: the GUID identifies it, the rest is for display.
local function Me()
    local guid, name = ns.PlayerGUID(), UnitName("player")
    if not (guid and name) then return nil end
    local _, class = UnitClass("player")
    return { guid = guid, name = name, realm = GetRealmName(), class = class }
end

local function IsSource(store)
    local source, guid = store and store.source, ns.PlayerGUID()
    return type(source) == "table" and guid ~= nil and source.guid == guid
end

-- "Name - Realm" for display. A source recorded before GUIDs only has its old name key.
local function SourceLabel(source)
    if type(source) ~= "table" then return nil end
    local legacy = source.legacy
    local name = source.name or (legacy and (legacy:match("^(.-) %- ") or legacy)) or "?"
    local realm = source.realm or (legacy and legacy:match(" %- (.+)$"))
    return realm and (name .. " - " .. realm) or name
end

-- A source recorded by name becomes a real one when its character logs in. Its old name is kept
-- for display when it is the fuller one: until 70009 it carried the surname.
local function ClaimLegacySource(store)
    local source = store.source
    if type(source) ~= "table" or source.guid or not ns.IsLegacyKeyMine(source.legacy) then return end
    local me = Me()
    if not me then return end
    local oldName = source.legacy:match("^(.-) %- ") or source.legacy
    if oldName:sub(1, #me.name + 1) == me.name .. " " then me.name = oldName end
    store.source = me
end

local function GetSyncStore()
    if not ns.db or not ns.db.global then return nil end
    local store = ns.db.global.uiSync or {}
    ns.db.global.uiSync = store

    -- The oldest format: one flat snapshot and its writer's bare name.
    if store.savedAt and not store.characters and not store.snapshot then
        -- editModeLayoutIndex is not carried over: it was an index into the wrong list
        store.snapshot = {
            cvars = store.cvars, editModeLayout = store.editModeLayout,
            chat = store.chat, bags = store.bags, savedAt = store.savedAt,
        }
        store.source = store.savedBy and { legacy = store.savedBy } or nil
        store.cvars, store.editModeLayout, store.editModeLayoutIndex = nil, nil, nil
        store.chat, store.bags, store.savedAt, store.savedBy = nil, nil, nil, nil
    end
    -- The next format kept a snapshot for every character, keyed by name, and the source's name.
    -- Only the source's snapshot was ever applied, so it is the one kept.
    if store.characters then
        local legacy = type(store.source) == "string" and store.source or nil
        store.snapshot = legacy and store.characters[legacy] or nil
        store.source = legacy and { legacy = legacy } or nil
        store.characters = nil
    end

    ClaimLegacySource(store)
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

    -- Only the source writes. With no source yet the first character to save becomes it, so an
    -- account with one character needs no setup at all.
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

    -- Edit Mode layout, by name and kind.
    -- C_EditMode.GetLayouts returns only the SAVED layouts, while its activeLayout is an index into
    -- the presets-then-saved list the manager assembles (EditModeManager.lua:947). Indexing one with
    -- the other read the wrong entry entirely - and read nothing at all on a character using a
    -- preset, which is why "Modern (preset)" never travelled. The manager holds the combined list,
    -- so it is the only place the name and the index agree.
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
    for i = 1, NUM_CHAT_WINDOWS do
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
    }

    -- Which action bars are shown is NOT a CVar: it is server-mirrored state behind
    -- GetActionBarToggles, which is why syncing CVars alone left the bars off.
    store.actionBars = { GetActionBarToggles() }

    -- The colour swatches in the chat config, one per message type.
    store.chatColors = {}
    for chatType in pairs(ChatTypeInfo) do
        local ok, r, g, b = pcall(GetMessageTypeColor, chatType)
        if ok and r then store.chatColors[chatType] = { r, g, b } end
    end

    store.savedAt = GetServerTime()
    store.savedBy = nil   -- older snapshots named their writer; the source record does that now
end

local function QueueSaveSync()
    if syncSaveTimer then syncSaveTimer:Cancel() end
    syncSaveTimer = C_Timer.NewTimer(5, function() syncSaveTimer = nil; SaveSync() end)
end

-- Copies the source's snapshot onto this character, once per snapshot. Nothing to do on the source
-- itself, which is where the settings came from.
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
    for name, value in pairs(store.cvars or {}) do
        if CVarKnown(name) then
            local ok, current = pcall(GetCVar, name)
            if ok and tostring(current) ~= tostring(value) then
                if pcall(SetCVar, name, value) then changed = changed + 1 end
            end
        end
    end

    -- Edit Mode layout. Matched on name AND kind, because a saved layout is free to be called
    -- "Modern" too, and searched over the manager's combined list so the index means what
    -- SetActiveLayout expects. Presets are in that list like anything else, so they carry over.
    local layoutChanged = false
    local manager = EditModeManagerFrame
    local layoutInfo = manager and manager.layoutInfo
    if store.editModeLayout and layoutInfo and layoutInfo.layouts then
        for index, layout in ipairs(layoutInfo.layouts) do
            local sameKind = store.editModeLayoutType == nil
                or layout.layoutType == store.editModeLayoutType
            if layout.layoutName == store.editModeLayout and sameKind then
                if index ~= layoutInfo.activeLayout and pcall(C_EditMode.SetActiveLayout, index) then
                    layoutChanged = true
                end
                break
            end
        end
    end

    -- Chat windows
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
                for _, group in ipairs(current) do pcall(RemoveChatWindowMessages, i, group) end
                for _, group in ipairs(w.messages) do pcall(AddChatWindowMessages, i, group) end
            end
            -- Only the window assignment: a channel this character has not joined cannot be put in
            -- a tab, and joining channels on someone's behalf is not this feature's business.
            if w.channels then
                local ok, current = pcall(function() return { GetChatWindowChannels(i) } end)
                for _, name in ipairs(ok and current or {}) do
                    if type(name) == "string" then pcall(RemoveChatWindowChannel, i, name) end
                end
                for _, name in ipairs(w.channels) do
                    if type(name) == "string" then pcall(AddChatWindowChannel, i, name) end
                end
            end
        end
        C_Timer.After(1, function()
            for i = 1, NUM_CHAT_WINDOWS do pcall(FloatingChatFrame_Update, i, true) end
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
    end

    -- Chat colours
    for chatType, c in pairs(store.chatColors or {}) do
        pcall(ChangeChatColor, chatType, c[1], c[2], c[3])
    end

    -- Action bars. Delayed because the server mirrors the toggles back asynchronously, and followed
    -- by MultiActionBar_Update because SetActionBarToggles records the choice without redrawing
    -- anything - which is why the options panel showed bars ticked that were not on screen.
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

    -- Applying a CVar that Blizzard watches runs its callback inside OUR call: the raid frame CVars
    -- drive CompactUnitFrameProfiles:ApplyCurrentSettings, which writes the shared compact frame
    -- option tables, and whatever reads them afterwards is tainted. Entering Edit Mode does, and
    -- then fails to compare the secret health colours it finds (CompactUnitFrame.lua:699).
    -- There is no way to launder that, so the settings are applied and the UI is reloaded - which is
    -- exactly what the addon this feature is modelled on does. The values live in CVars by now, so
    -- the reload keeps every one of them and starts clean.
    -- Asked once, after the action bar pass above, and only when something actually changed.
    -- A layout switch counts: it relays every system frame from our tainted call.
    if changed > 0 or layoutChanged then
        C_Timer.After(6, function()
            if not InCombatLockdown() then
                StaticPopup_Show("FLAREUI_SYNC_RELOAD", sourceName)
            end
        end)
    end

    charDB.syncApplied = store.savedAt
    Tweaks.syncLoading = false
    Print(("UI settings synced from %s (%d CVars changed)."):format(sourceName, changed))
end

-- A throw halfway through would leave the settings half applied and syncLoading stuck on, so it is
-- caught, the flag released and the failure said.
local function RunLoadSync()
    local ok, err = pcall(LoadSync)
    if not ok then
        Tweaks.syncLoading = false
        Print("|cffff4040Sync Blizz UI stopped partway:|r " .. tostring(err))
    end
end

local function InitSyncUI()
    SyncEvents:RegisterEvent("PLAYER_LOGOUT", SaveSync)
    SyncEvents:RegisterEvent("CVAR_UPDATE", QueueSaveSync)
    SyncEvents:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED", QueueSaveSync)
    SyncEvents:RegisterEvent("UPDATE_CHAT_WINDOWS", QueueSaveSync)
    SyncEvents:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS", QueueSaveSync)

    local started = false
    local function Start()
        if started then return end
        started = true
        C_Timer.After(3, function()
            -- a no-op when this character is the source, or when none is set yet
            RunLoadSync()
            -- recorded either way, so this character can be nominated as the source later
            C_Timer.After(1, SaveSync)
        end)
    end

    -- Modules initialise at PLAYER_LOGIN, which comes before PLAYER_ENTERING_WORLD, so the event is
    -- only a backstop. The first pass starts here as well, so it cannot depend on an event arriving.
    SyncEvents:RegisterEvent("PLAYER_ENTERING_WORLD", Start)
    Start()
end

--------------------------------------------------
-- Read by the source button in the options.
--------------------------------------------------
function Tweaks:IsSyncSource()
    return IsSource(GetSyncStore())
end

function Tweaks:GetSyncSourceLabel()
    local store = GetSyncStore()
    return store and SourceLabel(store.source) or nil
end

-- The snapshot is taken straight away, so the other characters copy this one from their next login
-- rather than from whenever it next changes a setting.
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
-- Junk is sold by Blizzard's own C_MerchantFrame.SellAllJunkItems, the call behind the merchant
-- window's "Sell All Junk" button, so Blizzard decides what counts as junk. The value is added up
-- from the bags first, while the items are still there to be counted.
--------------------------------------------------
local function JunkValue()
    local total = 0
    for bag = BACKPACK_CONTAINER, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.quality == Enum.ItemQuality.Poor and not info.hasNoValue then
                local price = select(11, C_Item.GetItemInfo(info.itemID))
                total = total + (price or 0) * (info.stackCount or 1)
            end
        end
    end
    return total
end

local function OnMerchantShow()
    local db = GetDb()
    if not db or IsShiftKeyDown() then return end
    if db.sellJunk and C_MerchantFrame.IsSellAllJunkEnabled() and C_MerchantFrame.GetNumJunkItems() > 0 then
        local value = JunkValue()
        C_MerchantFrame.SellAllJunkItems()
        if value > 0 then Print("Sold junk for " .. C_CurrencyInfo.GetCoinText(value) .. ".") end
    end
    if db.autoRepair and CanMerchantRepair() then
        local cost, canRepair = GetRepairAllCost()
        if canRepair and cost and cost > 0 then
            RepairAllItems()
            Print("Repaired for " .. C_CurrencyInfo.GetCoinText(cost) .. ".")
        end
    end
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
-- Prints a chat warning when the worst equipped item drops to the threshold, once per dip; the
-- warning arms itself again after a repair brings the gear back above it.
--------------------------------------------------
local DURABILITY_SLOTS = { 1, 3, 5, 6, 7, 8, 9, 10, 16, 17, 18 }   -- armour and weapons
local durabilityWarned = false

local function LowestDurability()
    local lowest
    for _, slot in ipairs(DURABILITY_SLOTS) do
        local current, max = GetInventoryItemDurability(slot)
        if current and max and max > 0 and canaccessvalue(current) and canaccessvalue(max) then
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
    local threshold = db.durabilityThreshold or 25
    if lowest <= threshold then
        if not durabilityWarned then
            durabilityWarned = true
            Print(("|cffff4040Durability at %d%%|r - time to repair."):format(math_floor(lowest + 0.5)))
        end
    elseif lowest > threshold + 5 then
        durabilityWarned = false   -- re-arm once repaired
    end
end

local function InitDurability()
    Tweaks:RegisterEvent("UPDATE_INVENTORY_DURABILITY", CheckDurability)
    Tweaks:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", CheckDurability)
    Tweaks:RegisterEvent("PLAYER_ENTERING_WORLD", CheckDurability)
end

--------------------------------------------------
-- 7. CAMERA & LOOT
--------------------------------------------------
local ZOOM_STEP = 4.0
local origZoomIn, origZoomOut

-- CameraZoomIn / Out are replaced rather than hooked: the mouse wheel bindings call the globals
-- directly, so there is no hook point that can change the step size. The originals are kept and
-- put back when the option is turned off.
local function ApplyCamera()
    local db = GetDb()
    if not db then return end
    pcall(SetCVar, "cameraDistanceMaxZoomFactor", db.maxCameraZoom and 2.6 or 1.9)
    if db.fasterCameraZoom then
        origZoomIn = origZoomIn or _G.CameraZoomIn
        origZoomOut = origZoomOut or _G.CameraZoomOut
        _G.CameraZoomIn = function() origZoomIn(ZOOM_STEP) end
        _G.CameraZoomOut = function() origZoomOut(ZOOM_STEP) end
        pcall(SetCVar, "cameraZoomSpeed", 50)
    elseif origZoomIn then
        _G.CameraZoomIn, _G.CameraZoomOut = origZoomIn, origZoomOut
        pcall(SetCVar, "cameraZoomSpeed", 20)
    end
end

-- LOOT_READY already says whether this loot is to be taken automatically (the auto-loot setting with
-- the modifier key applied), so every slot is taken at once instead of waiting on the loot window.
-- The event can fire more than once for the same window; only the first one takes the loot.
local lootTaken = false
local function FastLoot(_, autoLoot)
    local db = GetDb()
    if lootTaken or not (autoLoot and db and db.fasterLoot) then return end
    lootTaken = true
    for slot = GetNumLootItems(), 1, -1 do LootSlot(slot) end
end

local function InitCameraLoot()
    ApplyCamera()
    Tweaks:RegisterEvent("LOOT_READY", FastLoot)
    Tweaks:RegisterEvent("LOOT_CLOSED", function() lootTaken = false end)
end

--------------------------------------------------
-- 8. HIDE
--------------------------------------------------
-- Hide Error Messages takes UI_ERROR_MESSAGE away from UIErrorsFrame and hands back only the errors
-- about something the player would otherwise miss: loot that did not fit, money, the quest log.
-- They go through Blizzard's own TryDisplayMessage, so throttling and the error sound stay its own.
local KEPT_ERRORS = {
    "ERR_INV_FULL", "ERR_ITEM_MAX_COUNT", "ERR_LOOT_GONE",    -- loot that did not make it into the bags
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
    pcall(UIParent.UnregisterEvent, UIParent, "PING_SYSTEM_ERROR")
end

local function InitHideZoneText()
    if ZoneTextFrame then ZoneTextFrame:SetScript("OnShow", ZoneTextFrame.Hide) end
    if SubZoneTextFrame then SubZoneTextFrame:SetScript("OnShow", SubZoneTextFrame.Hide) end
end

local function ApplyPartyTitle()
    local db = GetDb()
    local title = _G.CompactPartyFrameTitle
    if not (db and title) then return end
    if db.hidePartyTitle then title:Hide() else title:Show() end
end

local function ApplyPortraitNumbers()
    local db = GetDb()
    if not db then return end
    local hide = db.hidePortraitNumbers
    local indicator = PlayerFrame and PlayerFrame.PlayerFrameContent and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain
        and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HitIndicator
    if indicator then indicator:SetShown(not hide) end
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
    if db.hideTips then
        pcall(SetCVar, "showTutorials", 0)
        pcall(SetCVar, "showNPETutorials", 0)
        HelpTip:HideAllSystem()
    else
        pcall(SetCVar, "showTutorials", 1)
        pcall(SetCVar, "showNPETutorials", 1)
    end
end

-- The addon drawer (AddonCompartmentFrame, under the minimap calendar). Blizzard shows it from its own
-- UpdateDisplay whenever an addon registers, so the hide is re-applied after that; switching the
-- option off lets UpdateDisplay decide again. While the Minimap module is on it hides the drawer
-- itself, and this option is out of the way.
local drawerHooked = false
local function ApplyAddonDrawer()
    local drawer = _G.AddonCompartmentFrame
    local db = GetDb()
    if not (drawer and db) then return end
    local minimap = ns.db.profile.minimap
    if minimap and minimap.enabled then return end
    if db.hideAddonDrawer then
        if not drawerHooked then
            drawerHooked = true
            hooksecurefunc(drawer, "UpdateDisplay", function(self)
                local current = GetDb()
                if current and current.hideAddonDrawer then self:Hide() end
            end)
        end
        drawer:Hide()
    elseif drawerHooked then
        drawer:UpdateDisplay()
    end
end

local function InitHide()
    local db = GetDb()
    if not db then return end
    if db.hideErrors then InitHideErrors() end
    if db.hideZoneText then InitHideZoneText() end
    ApplyPartyTitle()
    Tweaks:RegisterEvent("GROUP_ROSTER_UPDATE", ApplyPartyTitle)
    ApplyPortraitNumbers()
    ApplyTips()
    ApplyAddonDrawer()
end

--------------------------------------------------
-- 9. NAMEPLATE COMBO POINTS
-- Blizzard's classic combo point gems, centred under the target nameplate's health bar. Forever has
-- no nameplate combo bar of its own (the Mainline class nameplate bars are excluded from Camelot),
-- so the row is drawn here with the ComboFrame art. The count can be secret in combat: each lit gem
-- is a StatusBar with range [i-1, i] fed the raw count and seen through a clip window the size of
-- the gem's highlight, so no Lua compares the number. When the count is readable the row hides at
-- zero, as Blizzard's does; when it is not, it stays up for rogues and cat-form druids on a hostile
-- target.
--------------------------------------------------
local COMBO_ART         = "Interface\\ComboFrame\\ComboPoint"
local NP_COMBO_SPACING  = 13   -- the gems are 12 px wide
local NP_COMBO_OFFSET_Y = -1   -- below the health bar (negative = down)
local NP_COMBO_SCALE    = 1.1  -- on top of the nameplate's own scale
local NP_COMBO_MAX      = 10
local NP_COMBO_FALLBACK = 5

-- The art file holds three parts side by side: socket (0-0.375), highlight (0.375-0.5625) and shine.
-- The socket is a plain texture; the highlight is the lit StatusBar, drawn with the whole file at
-- the scale that makes its highlight part 8 px wide and slid so that part sits in the window.
local function CreateComboGem(parent, i)
    local gem = CreateFrame("Frame", nil, parent)
    gem:SetSize(12, 16)
    local socket = gem:CreateTexture(nil, "BACKGROUND")
    socket:SetTexture(COMBO_ART)
    socket:SetTexCoord(0, 0.375, 0, 1)
    socket:SetAllPoints()

    local window = CreateFrame("Frame", nil, gem)
    window:SetClipsChildren(true)
    window:SetPoint("TOPLEFT", gem, "TOPLEFT", 2, 0)
    window:SetSize(8, 16)
    local fileWidth = 8 / 0.1875
    local lit = CreateFrame("StatusBar", nil, window)
    lit:SetStatusBarTexture(COMBO_ART)
    lit:SetSize(fileWidth, 16)
    lit:SetPoint("TOPLEFT", window, "TOPLEFT", -0.375 * fileWidth, 0)
    lit:SetMinMaxValues(i - 1, i)
    lit:SetValue(i - 1)
    gem.lit = lit
    return gem
end

local npComboRow, npComboEvents

local function LayoutComboRow(row, count)
    for i = 1, count do
        local gem = row.gems[i]
        if not gem then
            gem = CreateComboGem(row, i)
            row.gems[i] = gem
        end
        gem:ClearAllPoints()
        gem:SetPoint("TOPLEFT", row, "TOPLEFT", (i - 1) * NP_COMBO_SPACING, 0)
        gem:Show()
    end
    for i = count + 1, #row.gems do row.gems[i]:Hide() end
    row:SetSize((count - 1) * NP_COMBO_SPACING + 12, 16)
    row.count = count
end

-- rogues always, druids only in a form that runs on energy (cat), and only on a hostile target
local function PlayerBuildsComboPoints()
    local _, class = UnitClass("player")
    if not canaccessvalue(class) or (class ~= "ROGUE" and class ~= "DRUID") then return false end
    if class == "DRUID" then
        local powerType = UnitPowerType("player")
        if not (canaccessvalue(powerType) and powerType == Enum.PowerType.Energy) then return false end
    end
    return UnitCanAttack("player", "target") and true or false
end

-- the plate's health bar, or the plate itself if its layout is not the one expected
local function PlateAnchor(plate)
    local unitFrame = plate.UnitFrame
    local bar = unitFrame and unitFrame.HealthBarsContainer and unitFrame.HealthBarsContainer.healthBar
    if bar and not bar:IsForbidden() then return bar end
    return plate
end

local function UpdateNameplateCombo()
    local row = npComboRow
    if not row then return end
    local plate = C_NamePlate.GetNamePlateForUnit("target")
    local points = GetComboPoints("player", "target")
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

    local anchor = PlateAnchor(plate)
    if row:GetParent() ~= plate then row:SetParent(plate) end
    row:ClearAllPoints()
    row:SetPoint("TOP", anchor, "BOTTOM", 0, NP_COMBO_OFFSET_Y)
    row:SetFrameLevel(anchor:GetFrameLevel() + 5)
    for i = 1, max do row.gems[i].lit:SetValue(points) end
    row:Show()
end

-- switched on and off live from the options
local function ApplyNameplateCombo()
    local db = GetDb()
    if not (db and db.nameplateCombo) then
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
-- 9b. NAMEPLATE QUEST TAGS
-- "Tag quest objectives": the unit frames' quest badge on the right end of an enemy nameplate whose
-- unit belongs to an active quest - a kill objective, or a mob that drops a quest item - as
-- C_QuestLog.UnitIsRelatedToActiveQuest reports it (a plain boolean, not a secret). The badge is
-- centred on the right edge of the plate's level box - half inside, half out - and a little shorter
-- than it; with no level box it does the same on the health bar. Plates are recycled, so a tag hangs off each plate and is
-- re-checked when a unit gets a plate, whenever the quest log changes and when a level box comes or
-- goes.
--------------------------------------------------
local QUEST_TAG_ATLAS   = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Quest"
local QUEST_TAG_FILE    = "Interface\\TargetingFrame\\PortraitQuestBadge"
local QUEST_TAG_SIZE    = 22     -- used when the box's height is not known yet
local QUEST_TAG_HEIGHT  = 0.85   -- the badge's height as a share of the box it sits on
local questTags = {}           -- plate -> tag
local questUnits = {}          -- nameplate unit tokens that currently have a plate
local questLevelHooked = {}    -- level boxes whose show / hide already re-places the tag
local questEvents
local UpdateQuestTag

local function GetQuestTag(plate)
    local tag = questTags[plate]
    if not tag then
        tag = CreateFrame("Frame", nil, plate)
        tag:SetSize(QUEST_TAG_SIZE, QUEST_TAG_SIZE)
        tag.icon = tag:CreateTexture(nil, "OVERLAY")
        tag.icon:SetAllPoints()
        if C_Texture.GetAtlasInfo(QUEST_TAG_ATLAS) then tag.icon:SetAtlas(QUEST_TAG_ATLAS) else tag.icon:SetTexture(QUEST_TAG_FILE) end
        questTags[plate] = tag
    end
    return tag
end

-- the plate's level box when it is showing, otherwise the health bar
local function QuestTagAnchor(plate)
    local unitFrame = plate.UnitFrame
    local level = unitFrame and unitFrame.PlayerLevelDiffFrame
    if level and not level:IsForbidden() then
        if not questLevelHooked[level] then
            questLevelHooked[level] = true
            local function Replace(self)
                local db, owner = GetDb(), self:GetParent()
                if db and db.nameplateQuest and owner and owner.unit and questUnits[owner.unit] then
                    UpdateQuestTag(owner.unit)
                end
            end
            level:HookScript("OnShow", Replace)
            level:HookScript("OnHide", Replace)
        end
        if level:IsShown() then return level end
    end
    return PlateAnchor(plate)
end

function UpdateQuestTag(unit)
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate or plate:IsForbidden() then return end
    local hostile = UnitCanAttack("player", unit)
    local related = C_QuestLog.UnitIsRelatedToActiveQuest(unit)
    local show = canaccessvalue(hostile) and hostile and canaccessvalue(related) and related
    if not show then
        if questTags[plate] then questTags[plate]:Hide() end
        return
    end
    local tag, anchor = GetQuestTag(plate), QuestTagAnchor(plate)
    -- the box's height in the tag's own units (the level box does not share the plate's scale)
    local size = anchor:GetHeight() * anchor:GetEffectiveScale() / tag:GetEffectiveScale() * QUEST_TAG_HEIGHT
    if not (size > 0) then size = QUEST_TAG_SIZE end
    tag:SetSize(size, size)
    tag:ClearAllPoints()
    tag:SetPoint("CENTER", anchor, "RIGHT", 0, 0)
    tag:SetFrameStrata(anchor:GetFrameStrata())   -- the level box draws at HIGH
    tag:SetFrameLevel(anchor:GetFrameLevel() + 5)
    tag:Show()
end

local function UpdateAllQuestTags()
    for unit in pairs(questUnits) do UpdateQuestTag(unit) end
end

local function OnQuestTagEvent(_, event, unit)
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
        UpdateAllQuestTags()
    end
end

-- switched on and off live from the options
local function ApplyQuestTags()
    local db = GetDb()
    if not (db and db.nameplateQuest) then
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
        if unit then questUnits[unit] = true end
    end
    UpdateAllQuestTags()
end

--------------------------------------------------
-- 10. PARTY FRAME UNCLAMP (always on)
-- Edit Mode clamps every system to the screen (EditModeSystemTemplate clampedToScreen="true", with the
-- clamp rect set to the selection box), which stops the party frames short of the left edge. Nothing
-- in Blizzard's code turns it back on, so switching it off once is enough. PartyFrame holds secure
-- unit buttons, so this waits for combat to end if it has to - on a frame of its own, because
-- Move Any Frame already owns the module's PLAYER_REGEN_ENABLED handler.
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
-- 11. WORLD REFRESH (shard transfer)
-- When the server is about to move the player to a fresh copy of the world, Blizzard opens the
-- SHARD_TRANSFER_IMMINENT_EVENT dialog ("Refresh Now" / "Okay") and a countdown toast above the chat.
-- "World Refresh Dialog" closes the dialog in the same frame it opens - before it is ever drawn -
-- which is all "Okay" does. Only the server's event is caught: clicking the toast still opens the
-- dialog, for "Refresh Now". The toast's grey border takes FlareUI's bronze (always on).
--------------------------------------------------
local function InitWorldRefresh()
    hooksecurefunc(GameEvent, "HandleShardTransferImminentEvent", function()
        local db = GetDb()
        if db and db.hideWorldRefresh then StaticPopup_Hide("SHARD_TRANSFER_IMMINENT_EVENT") end
    end)
    EventUtil.ContinueOnAddOnLoaded("Blizzard_SocialToast", function()
        local c = ns.BORDER_COLOR
        for _, toast in ipairs({ _G.ShardTransferImminentFrame, _G.ShardTransferImminentMinimizeButton }) do
            if toast then toast:SetBackdropBorderColor(c.r, c.g, c.b, 1) end
        end
    end)
end

--------------------------------------------------
-- 11b. AUTO-TYPE DELETE
-- Blizzard asks for the word DELETE before destroying a rare or better item. The word goes into the
-- box as the dialog opens (Blizzard's own text handler then enables Yes), so Yes or Enter still
-- has to be pressed: the dialog keeps asking, it just no longer needs the typing.
--------------------------------------------------
local DELETE_DIALOGS = { DELETE_GOOD_ITEM = true, DELETE_GOOD_QUEST_ITEM = true }

local function InitAutoDelete()
    hooksecurefunc("StaticPopup_Show", function(which)
        local db = GetDb()
        if not (db and db.autoDelete and DELETE_DIALOGS[which]) then return end
        local dialog = StaticPopup_FindVisible(which)
        local editBox = dialog and dialog:GetEditBox()
        if editBox then editBox:SetText(DELETE_ITEM_CONFIRM_STRING) end
    end)
end

--------------------------------------------------
-- 11c. TRAIN ALL
-- A "Train All" button beside the trainer's Train button: learns every skill the trainer lists as
-- available, as far as the gold goes. Never a new profession (Blizzard asks before those, and the
-- slots are limited), and not at pet trainers, which charge training points. The list is walked
-- from the bottom because a purchase reindexes the entries below it, which are then already done.
-- Skills that need a lower rank first become available after the click, so it can light up again.
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
    trainAll:SetText("Train All")
    trainAll:SetSize(90, train:GetHeight())
    trainAll:SetPoint("RIGHT", train, "LEFT", 0, 0)
    trainAll:SetScript("OnClick", function()
        for _, index in ipairs((TrainableSkills())) do BuyTrainerService(index) end
    end)
    trainAll:SetScript("OnEnter", function(self)
        local list, total = TrainableSkills()
        ns.OwnGameTooltip(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Train All", 1, 1, 1)
        if #list == 0 then
            GameTooltip:AddLine("Nothing you can afford to learn here.", nil, nil, nil, true)
        else
            GameTooltip:AddLine(string.format("Learns %d %s for %s.", #list, #list == 1 and "skill" or "skills",
                GetMoneyString(total)), nil, nil, nil, true)
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
-- 11d. QUEST TRACKER IN BOSS FIGHTS
-- Hidden from ENCOUNTER_START to ENCOUNTER_END. While the tracker shows a quest item button it is
-- protected in combat, and a pull is always in combat: then ns.HideFrameSecurely holds the hide
-- until combat ends and the tracker is only made invisible meanwhile (alpha 0).
--------------------------------------------------
local inEncounter, trackerHidden, trackerAlpha = false, false, 1

local function ApplyTrackerHide()
    local tracker = _G.ObjectiveTrackerFrame
    local db = GetDb()
    if not tracker then return end
    local hide = (inEncounter and db and db.hideTrackerInBoss) or false
    if hide == trackerHidden then return end
    trackerHidden = hide
    if hide then
        trackerAlpha = tracker:GetAlpha()
        tracker:SetAlpha(0)
    else
        tracker:SetAlpha(trackerAlpha)
    end
    ns.HideFrameSecurely(tracker, hide)
end

local function InitBossTracker()
    local events = CreateFrame("Frame")
    events:RegisterEvent("ENCOUNTER_START")
    events:RegisterEvent("ENCOUNTER_END")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")   -- a missed ENCOUNTER_END (disconnect, reload)
    events:SetScript("OnEvent", function(_, event)
        inEncounter = event == "ENCOUNTER_START"
        ApplyTrackerHide()
    end)
end

--------------------------------------------------
-- 12. PUBLIC
--------------------------------------------------
-- live re-apply for the options that need no reload
function Tweaks:Refresh()
    if not self.initialized then return end
    ApplyCamera()
    ApplyPartyTitle()
    ApplyPortraitNumbers()
    ApplyTips()
    ApplyAddonDrawer()
    ApplyNameplateCombo()
    ApplyQuestTags()
    UpdateTrainAll()
    ApplyTrackerHide()
    if MerchantSellAllJunkButton and MerchantSellAllJunkButton:IsShown() then
        local db = GetDb()
        if db and db.sellJunk then MerchantSellAllJunkButton:Hide() else MerchantSellAllJunkButton:Show() end
    end
end

function Tweaks:Init()
    if self.initialized then return end
    local db = GetDb()
    if not db then return end
    self.initialized = true

    if db.moveAnyFrame then StartMoveAnyFrame() end
    if db.syncUI then InitSyncUI() end
    InitVendor()
    InitDurability()
    InitCameraLoot()
    InitHide()
    InitWorldRefresh()
    InitAutoDelete()
    InitTrainAll()
    InitBossTracker()
    ApplyNameplateCombo()
    ApplyQuestTags()
    UnclampPartyFrame()
end
