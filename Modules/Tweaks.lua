local _, ns = ...
local L = ns.L

--------------------------------------------------
-- 1. MODULE REGISTRATION
-- Small quality-of-life tweaks, each a toggle:
--   Windows & Settings  Move Any Frame, Sync Blizz UI (account-wide settings)
--   Vendor              Sell Junk Automatically, Repair Automatically, Durability Warning
--   Camera              Max Camera Zoom, Faster Camera Zoom
--   Nameplates          Combo Points under the target's nameplate, Tag Quest Objectives
--   Convenience         Faster Auto Loot, Auto-Type DELETE, Train All button
--   Hide                Error Messages, Zone Text, Party Title, Portrait Numbers, Contextual Tips,
--                       Addon Drawer, Quest Tracker in Boss Fights
--   Always on           Party frames unclamped from the screen edge
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
-- Every UIPanelWindows panel (and bags) drags by its header; Ctrl+wheel scales, Shift+right-click
-- resets the position, Ctrl+right-click the scale. Saved per frame name, re-applied after
-- Blizzard's panel manager places the frame.
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
    if not CanTouch(frame) or IsMaximized(frame) then return end
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
    if IsMaximized(frame) then return end
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

-- Only the header drags: a mouse-enabled window would swallow every click inside it
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

-- Ctrl+wheel scales from anywhere over the window (scroll frames keep their own wheel)
local function SetupWheel(frame)
    if frame.moveWheelHooked or not frame.EnableMouseWheel then return end
    frame.moveWheelHooked = true
    frame.moveTarget = frame
    frame:EnableMouseWheel(true)
    frame:HookScript("OnMouseWheel", OnMouseWheel)
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
    -- the panel manager has placed the window by OnShow: put ours back before it draws
    frame:HookScript("OnShow", function(f)
        ApplySavedPosition(f)
        C_Timer.After(0, function() ApplySavedPosition(f) end)
    end)
    if frame:IsShown() then ApplySavedPosition(frame) end
end

local function ScanUIPanels()
    local windows = _G.UIPanelWindows
    if type(windows) ~= "table" then return end
    for name in pairs(windows) do SetupMovableFrame(name) end
end

-- Bags are named, not UI panels. Their portrait router covers the title bar and swallows the drag,
-- so it is disabled; a plain right-click opens the sorting menu instead (OnMouseUp).
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
            if type(delegate[method]) == "function" then hooksecurefunc(delegate, method, ApplyAllNowAndNext) end
        end
    end
    hooksecurefunc("UpdateUIPanelPositions", ApplyAllNowAndNext)
    -- bags re-anchor (and re-scale) themselves every time they open or the layout changes
    hooksecurefunc("UpdateContainerFrameAnchors", function() ScanBagFrames() ApplyAllNowAndNext() end)
    Tweaks:RegisterEvent("BAG_UPDATE_DELAYED", ScanBagFrames)
    Tweaks:RegisterEvent("PLAYER_REGEN_ENABLED", function()
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

-- AceEvent keeps one callback per object per event, so the sync has its own object
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

-- A source recorded by name (before 70009) becomes a GUID record when its character logs in
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

    -- older formats: one flat snapshot, then one snapshot per character
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
    store.savedBy = nil
end

local function QueueSaveSync()
    if syncSaveTimer then syncSaveTimer:Cancel() end
    syncSaveTimer = C_Timer.NewTimer(5, function() syncSaveTimer = nil; SaveSync() end)
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
    for name, value in pairs(store.cvars or {}) do
        if CVarKnown(name) then
            local ok, current = pcall(GetCVar, name)
            if ok and tostring(current) ~= tostring(value) then
                if pcall(SetCVar, name, value) then changed = changed + 1 end
            end
        end
    end

    -- Edit Mode layout, matched on name and kind. The switch rides on the reload dialog's secure
    -- button (from our code it would taint every system). Only a layout of the current input mode,
    -- and none while Remember Layout per Mode picks the layouts.
    local layoutChanged, layoutIndex = false, nil
    local manager = EditModeManagerFrame
    local layoutInfo = manager and manager.layoutInfo
    local expected = ns.IsGamepadUI() and Enum.InputDeviceInterfaceType.Gamepad or Enum.InputDeviceInterfaceType.Mkb
    if store.editModeLayout and layoutInfo and layoutInfo.layouts and not db.layoutPerMode then
        for index, layout in ipairs(layoutInfo.layouts) do
            local sameKind = store.editModeLayoutType == nil
                or layout.layoutType == store.editModeLayoutType
            if layout.layoutName == store.editModeLayout and sameKind then
                local style = layout.interfaceStyle
                local sameMode = style == expected or (style == nil and expected == Enum.InputDeviceInterfaceType.Mkb)
                if index ~= layoutInfo.activeLayout and sameMode then
                    layoutChanged, layoutIndex = true, index
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

    -- A watched CVar runs Blizzard's callback inside our call and taints what it writes (the raid
    -- frame options), so after any change the UI is reloaded clean. Asked once, after the action
    -- bar pass.
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

    -- PLAYER_ENTERING_WORLD is only a backstop
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
-- Junk is sold by Blizzard's C_MerchantFrame.SellAllJunkItems; the value is counted first.
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
        if value > 0 then Print(L["Sold junk for %s."]:format(C_CurrencyInfo.GetCoinText(value))) end
    end
    if db.autoRepair and CanMerchantRepair() then
        local cost, canRepair = GetRepairAllCost()
        if canRepair and cost and cost > 0 then
            RepairAllItems()
            Print(L["Repaired for %s."]:format(C_CurrencyInfo.GetCoinText(cost)))
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
-- A chat warning when the worst equipped item drops to the threshold, once per dip
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
            Print(L["|cffff4040Durability at %d%%|r - time to repair."]:format(math_floor(lowest + 0.5)))
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

-- CameraZoomIn / Out are replaced (the wheel bindings call the globals; no hook can change the
-- step); the originals come back when the option is off. CVars go back to Blizzard's defaults only
-- when FlareUI changed them (ForcedCVars).
local function ForcedCVars()
    local global = ns.db and ns.db.global
    if not global then return {} end
    global.forcedCVars = global.forcedCVars or {}
    return global.forcedCVars
end

local function ApplyCamera()
    local db = GetDb()
    if not db then return end
    local forced = ForcedCVars()
    if db.maxCameraZoom then
        pcall(SetCVar, "cameraDistanceMaxZoomFactor", 2.6)
        forced.maxZoom = true
    elseif forced.maxZoom then
        pcall(SetCVar, "cameraDistanceMaxZoomFactor", 1.9)
        forced.maxZoom = nil
    end
    if db.fasterCameraZoom then
        origZoomIn = origZoomIn or _G.CameraZoomIn
        origZoomOut = origZoomOut or _G.CameraZoomOut
        _G.CameraZoomIn = function() origZoomIn(ZOOM_STEP) end
        _G.CameraZoomOut = function() origZoomOut(ZOOM_STEP) end
        pcall(SetCVar, "cameraZoomSpeed", 50)
        forced.zoomSpeed = true
    else
        if origZoomIn then _G.CameraZoomIn, _G.CameraZoomOut = origZoomIn, origZoomOut end
        if forced.zoomSpeed then
            pcall(SetCVar, "cameraZoomSpeed", 20)
            forced.zoomSpeed = nil
        end
    end
end

-- LOOT_READY says whether to auto-loot: every slot is taken at once, on the first event only
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
-- Hide Error Messages keeps only the errors the player would otherwise miss (loot, money, quest
-- log), shown through Blizzard's TryDisplayMessage
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

local partyTitleHidden = false
local function ApplyPartyTitle()
    local db = GetDb()
    local title = _G.CompactPartyFrameTitle
    if not (db and title) then return end
    if db.hidePartyTitle then
        title:Hide()
        partyTitleHidden = true
    elseif partyTitleHidden then
        title:Show()
        partyTitleHidden = false
    end
end

local function ApplyPortraitNumbers()
    local db = GetDb()
    if not db then return end
    local hide = db.hidePortraitNumbers
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
    local forced = ForcedCVars()
    if db.hideTips then
        pcall(SetCVar, "showTutorials", 0)
        pcall(SetCVar, "showNPETutorials", 0)
        HelpTip:HideAllSystem()
        forced.tips = true
    elseif forced.tips then
        pcall(SetCVar, "showTutorials", 1)
        pcall(SetCVar, "showNPETutorials", 1)
        forced.tips = nil
    end
end

-- The addon drawer, re-hidden after Blizzard's UpdateDisplay (the Minimap module hides it itself)
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
-- Combo point gems (Core.lua) under the target nameplate's health bar; Forever has no nameplate
-- combo bar. The count can be secret: each gem is fed the raw count. A readable count hides the row
-- at zero and flashes gained points.
--------------------------------------------------
local NP_COMBO_SIZE     = 16   -- the socket's side
local NP_COMBO_SPACING  = 15   -- the rims nearly touch; the sockets' shadows overlap
local NP_COMBO_OFFSET_Y = -5   -- below the health bar, clear of the aggro glow (negative = down)
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
    -- ElvUI's nameplates are one of its modules and can be switched off
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
            gem = ns.CreateComboGem(row, i, NP_COMBO_SIZE)
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

-- The plate's health bar, or the plate itself
local function PlateAnchor(plate)
    local unitFrame = plate.UnitFrame
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
    for i = 1, max do row.gems[i].lit:SetValue(points) end
    if last and row.lastPoints and row.lastPoints > last then
        for i = last + 1, math_min(row.lastPoints, max) do row.gems[i].flash:Restart() end
    end
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
-- 9b. NAMEPLATE QUEST TAGS
-- A quest "!" on the right edge of an enemy nameplate's level box (or health bar) whose unit is
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

-- Width / height of the art, so the tag keeps its shape at any height
local questTagAspect
local function QuestTagAspect()
    if not questTagAspect then
        local info = C_Texture.GetAtlasInfo(QUEST_TAG_ATLAS)
        questTagAspect = (info and info.width > 0 and info.height > 0) and (info.width / info.height) or 1
    end
    return questTagAspect
end

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

-- The plate's level box when it shows, otherwise the health bar
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
    if not canaccessvalue(unit) then return end
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
    tag:SetSize(size * QuestTagAspect(), size)
    tag:ClearAllPoints()
    tag:SetPoint("CENTER", anchor, "RIGHT", 0, 0)
    tag:SetFrameStrata(anchor:GetFrameStrata())   -- the level box draws at HIGH
    tag:SetFrameLevel(anchor:GetFrameLevel() + 5)
    tag:Show()
end

local function UpdateAllQuestTags()
    for unit in pairs(questUnits) do UpdateQuestTag(unit) end
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
        UpdateAllQuestTags()
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
-- 10. PARTY FRAME UNCLAMP (always on)
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
-- 11b. AUTO-TYPE DELETE (the word goes into the box; Yes still has to be pressed)
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
-- 11d. QUEST TRACKER IN BOSS FIGHTS
-- Hidden from ENCOUNTER_START to ENCOUNTER_END. A tracker with an item button is protected in combat,
-- so it is made invisible at once and hidden when combat ends.
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

--------------------------------------------------
-- 11e. EDIT MODE LAYOUT PER MODE
-- Switching the Gamepad UI falls back to the new mode's preset layout. FlareUI remembers the layout
-- last used in each mode (per character, by type and name) and offers it back after login. The
-- switch runs from the dialog's secure button (from our code it would taint every system); never
-- in combat.
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
    local db = GetDb()
    if not (db and db.layoutPerMode) then return end
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
    text = L["Restore your %s Edit Mode layout?"],
    button1 = L["Restore"],
    button2 = L["Not Now"],
    macro = function(data) return "/run C_EditMode.SetActiveLayout(" .. data.index .. ")" end,
    hideOnEscape = true,
    padSecure = true,
}

local function InitLayoutPerMode()
    sessionMode = ModeKey()
    local restored = false
    local events = CreateFrame("Frame")

    local function Restore()
        restored = true
        local db = GetDb()
        if not (db and db.layoutPerMode) then return end
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
-- Live re-apply for the options that need no reload
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
    InitAutoDelete()
    InitTrainAll()
    InitBossTracker()
    InitLayoutPerMode()
    ApplyNameplateCombo()
    ApplyQuestTags()
    UnclampPartyFrame()
end
