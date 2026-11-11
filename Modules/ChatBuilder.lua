local _, ns = ...
local L, catalog = ns.L, ns.ChatBuilderCatalog
local B = {}
ns.ChatBuilder = B
local generations, observers = {}, {}
local events, hooked, notifying

local function Copy(t)
    if type(t) ~= "table" then return t end
    local out = {}; for k, v in pairs(t) do out[k] = Copy(v) end; return out
end
local function Set(t)
    local out = {}; for _, v in pairs(t or {}) do if type(v) == "string" then out[v] = true end end; return out
end
local function Same(a, b)
    for k in pairs(a) do if not b[k] then return false end end
    for k in pairs(b) do if not a[k] then return false end end
    return true
end
local function MaxWindows() return Constants.ChatFrameConstants.MaxChatWindows end
local function ChannelKey(name, zone)
    return type(zone) == "number" and zone > 0 and ("zone:" .. zone) or ("name:" .. name:lower())
end
local function Changed()
    if notifying then return end
    notifying = true
    C_Timer.After(0, function()
        notifying = false
        for callback in pairs(observers) do callback() end
    end)
end
local function SavedChanged()
    if ns.Tweaks and ns.Tweaks.ChatBuilderChanged then ns.Tweaks:ChatBuilderChanged() end
    Changed()
end
local function Name(value)
    if type(value) ~= "string" then return nil end
    value = value:match("^%s*(.-)%s*$")
    -- Match FlareUI's native rename dialog, counting UTF-8 characters rather than bytes.
    local _, length = value:gsub("[^\128-\191]", "")
    if value == "" or length > 31 or value:find("[|%c]") then return nil end
    return value
end
function B:Status()
    if InCombatLockdown() then return nil, L["Chat editing is unavailable during combat."] end
    if not (ns.db and ns.db.profile.chat and ns.db.profile.chat.enabled and ns.Chat and ns.Chat.started) then
        return nil, L["Enable Chat and reload before using the builder."]
    end
    if ns.Tweaks and ns.Tweaks.syncLoading then return nil, L["Wait for Blizzard settings sync to finish."] end
    if ns.Tweaks and ns.Tweaks.chatBuilderSyncPending then return nil, L["Wait for Blizzard settings sync to finish."] end
    for _, key in ipairs({"GetChatWindowInfo","GetChatWindowMessages","GetChatWindowChannels","AddChatWindowMessages","RemoveChatWindowMessages","AddChatWindowChannel","RemoveChatWindowChannel"}) do
        if type(_G[key]) ~= "function" then return nil, L["Chat configuration is unavailable on this client."] end
    end
    return true
end
function B:Windows()
    local out = {}
    if not GetChatWindowInfo then return out end
    for id = 1, MaxWindows() do
        local frame = _G["ChatFrame" .. id]
        local name, _, _, _, _, _, shown, _, docked = GetChatWindowInfo(id)
        if frame and not frame:IsForbidden() and not frame.isTemporary and (shown or docked or id == 1 or id == 2) then
            out[#out+1] = {id=id, frame=frame, generation=generations[id] or 0, name=name or "", docked=docked and true or false,
                special=(id == 2 or (IsCombatLog and IsCombatLog(frame))) and true or false, primary=(id == 1 or frame == DEFAULT_CHAT_FRAME)}
        end
    end
    return out
end
local function Current(handle)
    if type(handle) ~= "table" then return nil, L["Select a chat window."] end
    for _, window in ipairs(B:Windows()) do
        if window.id == handle.id and window.frame == handle.frame and window.generation == handle.generation and window.name == handle.name then return window end
    end
    return nil, L["This chat window changed. Select it again."]
end
local function Guard(handle, allowSpecial)
    local ok, err = B:Status(); if not ok then return nil, err end
    local window; window, err = Current(handle)
    if not window then return nil, err end
    if window.special and not allowSpecial then return nil, L["Use Blizzard settings for the Combat Log."] end
    return window
end
function B:Channels()
    local out = {}
    if not GetChannelList then return out end
    local values = {GetChannelList()}
    for i = 1, #values, 3 do
        local index, name, disabled = values[i], values[i+1], values[i+2]
        if type(name) == "string" and name ~= "" then
            local info = C_ChatInfo and C_ChatInfo.GetChannelInfoFromIdentifier and C_ChatInfo.GetChannelInfoFromIdentifier(name)
            local zone = info and info.zoneChannelID or 0
            local label = ChatFrameUtil and ChatFrameUtil.ResolveChannelName and ChatFrameUtil.ResolveChannelName(name) or name
            if C_ChatInfo and C_ChatInfo.IsChannelRegional and C_ChatInfo.IsChannelRegional(index) then
                disabled = disabled or not C_ChatInfo.IsRegionalServiceAvailable()
            end
            out[#out+1] = {key=ChannelKey(name,zone), name=name, label=label, kind="channel", index=index, disabled=disabled and true or false}
        end
    end
    return out
end
function B:Categories()
    local out = {}
    for _, category in ipairs(catalog.categories) do
        local item = {key=category.key, name=category.name, entries={}}
        if category.key == "channels" then item.entries = self:Channels()
        else
            for _, entry in ipairs(category.entries) do
                local supported = ChatTypeGroup and ChatTypeGroup[entry[1]] ~= nil
                if entry[1] == "VOICE_TEXT" then supported = supported and C_VoiceChat and C_VoiceChat.IsTranscriptionAllowed and C_VoiceChat.IsTranscriptionAllowed() end
                if supported then item.entries[#item.entries+1] = {key=entry[1],label=entry[2],kind="message"} end
            end
        end
        out[#out+1] = item
    end
    return out
end
local function SavedChannels(id)
    local out, names = {}, {}
    local values = {GetChatWindowChannels(id)}
    for i = 1, #values, 2 do
        if type(values[i]) == "string" then
            local key = ChannelKey(values[i], values[i+1])
            out[key], names[key] = true, values[i]
        end
    end
    return out, names
end
function B:Read(handle)
    if type(GetChatWindowMessages)~="function" or type(GetChatWindowChannels)~="function" then
        return nil,L["Chat configuration is unavailable on this client."]
    end
    local window, err = Current(handle); if not window then return nil, err end
    local messages = Set({GetChatWindowMessages(window.id)})
    local channels, channelNames = SavedChannels(window.id)
    local activeMessages, activeChannels = Set(window.frame.messageTypeList), {}
    for i, name in pairs(window.frame.channelList or {}) do
        activeChannels[ChannelKey(name, (window.frame.zoneChannelList or {})[i])] = true
    end
    return {messages=messages,channels=channels,channelNames=channelNames,activeMessages=activeMessages,activeChannels=activeChannels,
        pending=not Same(messages, activeMessages) or not Same(channels,activeChannels),window=window}
end
function B:Pending()
    for _, h in ipairs(self:Windows()) do
        local state=not h.special and self:Read(h)
        if state and state.pending then return true end
    end
    return false
end
local function Filter(handle, kind, key, enabled)
    local state = B:Read(handle)
    local allowed
    for _, category in ipairs(B:Categories()) do
        for _, entry in ipairs(category.entries) do if entry.kind == kind and entry.key == key then allowed = entry end end
    end
    if not allowed or allowed.disabled then return nil, L["This filter is unavailable."] end
    if kind == "message" then
        if (state.messages[key] or false) ~= enabled then
            local fn = enabled and AddChatWindowMessages or RemoveChatWindowMessages
            local ok = pcall(fn,handle.id,key)
            if not ok then return nil,L["The client could not save this filter."] end
        end
    else
        if (state.channels[key] or false) ~= enabled then
            local ok
            if enabled then ok=pcall(AddChatWindowChannel,handle.id,allowed.name)
            else ok=pcall(RemoveChatWindowChannel,handle.id,state.channelNames[key] or allowed.name) end
            if not ok then return nil,L["The client could not save this filter."] end
        end
    end
    local after=B:Read(handle)
    local saved=kind=="message" and after.messages or after.channels
    if (saved[key] or false)~=enabled then return nil,L["The client could not save this filter."] end
    return true
end
-- Snapshot before a batch; rejected writes must not leave half a preset applied.
local function ChangeFilters(window, changes)
    local before=B:Read(window)
    for i,change in ipairs(changes) do
        local ok,err=Filter(window,change.kind,change.key,change.enabled)
        if not ok then
            local restored=true
            for j=i,1,-1 do
                local old=changes[j]
                local saved=old.kind=="message" and before.messages or before.channels
                if not Filter(window,old.kind,old.key,saved[old.key] and true or false) then restored=false end
            end
            SavedChanged()
            return nil,restored and err or L["Some filters could not be restored. Review the saved selections before reloading."]
        end
    end
    SavedChanged()
    return true
end
function B:SetFilter(handle, kind, key, enabled)
    local window, err = Guard(handle); if not window then return nil, err end
    return ChangeFilters(window,{{kind=kind,key=key,enabled=enabled and true or false}})
end
function B:SetCategory(handle, key, enabled)
    local window, err = Guard(handle); if not window then return nil, err end
    for _, category in ipairs(self:Categories()) do
        if category.key == key then
            local changes={}
            for _, entry in ipairs(category.entries) do
                if not entry.disabled then changes[#changes+1]={kind=entry.kind,key=entry.key,enabled=enabled and true or false} end
            end
            return ChangeFilters(window,changes)
        end
    end
    return nil, L["This filter is unavailable."]
end
local function Store(create)
    local global = ns.db and ns.db.global
    if not global then return nil end
    if global.chatBuilderPresets == nil and create then global.chatBuilderPresets = {version=1,nextID=1,items={}} end
    local store = global.chatBuilderPresets
    if type(store) ~= "table" or store.version ~= 1 or type(store.items) ~= "table" then return nil end
    return store
end
local function ValidPreset(p)
    if type(p) ~= "table" or not Name(p.name) or type(p.messages) ~= "table" or type(p.channels) ~= "table" then return false end
    for _, field in ipairs({"messages","channels"}) do
        for k,v in pairs(p[field]) do
            if type(k) ~= "number" or k < 1 or k % 1 ~= 0 or k > #p[field] or type(v) ~= "string" then return false end
            if field == "channels" and not v:match("^zone:%d+$") and not v:match("^name:.+") then return false end
        end
    end
    return true
end
function B:Presets()
    local out = Copy(catalog.presets)
    for _, p in ipairs(out) do p.builtin = true end
    local store = Store()
    local custom = {}
    for id,p in pairs(store and store.items or {}) do
        if ValidPreset(p) and type(id)=="string" then local c=Copy(p);c.id=id;c.builtin=false;custom[#custom+1]=c end
    end
    table.sort(custom,function(a,b) return a.name:lower()<b.name:lower() end)
    for _, p in ipairs(custom) do out[#out+1] = p end
    return out
end
function B:Preset(id)
    for _, p in ipairs(self:Presets()) do if p.id == id then return p end end
end
function B:PreviewPreset(id)
    local preset = self:Preset(id); if not preset then return nil, L["This preset is unavailable."] end
    local available, labels = {}, {}
    for _, cat in ipairs(self:Categories()) do
        for _, entry in ipairs(cat.entries) do if not entry.disabled then available[entry.key]=true;labels[entry.key]=entry.label end end
    end
    local result = {preset=preset,skipped={},included={}}
    for _, field in ipairs({"messages","channels"}) do
        for _, key in ipairs(preset[field]) do
            local label = labels[key] or catalog.channelNames[key] or key
            if available[key] then result.included[#result.included+1]=label else result.skipped[#result.skipped+1]=label end
        end
    end
    return result
end
function B:ApplyPreset(handle, id)
    local window, err = Guard(handle); if not window then return nil, err end
    local preview; preview,err = self:PreviewPreset(id); if not preview then return nil,err end
    local messages, channels = Set(preview.preset.messages), Set(preview.preset.channels)
    local changes={}
    for _, cat in ipairs(self:Categories()) do
        for _, entry in ipairs(cat.entries) do
            if not entry.disabled then changes[#changes+1]={kind=entry.kind,key=entry.key,enabled=(entry.kind=="message" and messages[entry.key] or channels[entry.key]) and true or false} end
        end
    end
    local ok;ok,err=ChangeFilters(window,changes)
    if not ok then return nil,err end
    return preview
end
function B:SavePreset(handle, name)
    local window, err = Guard(handle); if not window then return nil,err end
    name = Name(name); if not name then return nil,L["Use a name of 1–31 characters without formatting or line breaks."] end
    local store = Store(true); if not store then return nil,L["Saved presets use an unsupported format."] end
    local state, preset = self:Read(window), {name=name,messages={},channels={}}
    for _, cat in ipairs(self:Categories()) do for _, entry in ipairs(cat.entries) do
        if entry.kind=="message" and state.messages[entry.key] then preset.messages[#preset.messages+1]=entry.key end
    end end
    -- Keep saved assignments even when a zone/service channel is not currently available.
    for key in pairs(state.channels) do preset.channels[#preset.channels+1]=key end
    table.sort(preset.channels)
    local n = type(store.nextID)=="number" and store.nextID>=1 and store.nextID<1000000 and math.floor(store.nextID) or 1
    while store.items["custom:"..n] do n=n+1 end
    preset.id="custom:"..n;store.nextID=n+1;store.items[preset.id]=preset
    Changed();return Copy(preset)
end
function B:RenamePreset(id,name)
    local ok,err=self:Status();if not ok then return nil,err end
    local store=Store();local p=store and store.items[id]
    if not p or not ValidPreset(p) then return nil,L["Only saved presets can be changed."] end
    name=Name(name);if not name then return nil,L["Use a name of 1–31 characters without formatting or line breaks."] end
    p.name=name;Changed();return true
end
function B:DeletePreset(id)
    local ok,err=self:Status();if not ok then return nil,err end
    local store=Store();if not store or not store.items[id] then return nil,L["Only saved presets can be changed."] end
    store.items[id]=nil;Changed();return true
end
function B:Create(name,presetID)
    local ok,err=self:Status();if not ok then return nil,err end
    name=Name(name);if not name then return nil,L["Use a name of 1–31 characters without formatting or line breaks."] end
    if not self:Preset(presetID) then return nil,L["This preset is unavailable."] end
    if not FCF_OpenNewWindow or not FCF_CanOpenNewWindow or not FCF_CanOpenNewWindow() then return nil,L["No chat window slots are available."] end
    local frame=FCF_OpenNewWindow(name,true)
    if not frame then return nil,L["No chat window slots are available."] end
    for _, h in ipairs(self:Windows()) do if h.frame==frame then
        local result;result,err=self:ApplyPreset(h,presetID)
        if not result then
            -- This window was created by this call; dispose of it if its preset was rejected.
            if FCF_Close then FCF_Close(frame) end
            return nil,err
        end
        return h,result
    end end
    return nil,L["The new chat window could not be selected."]
end
function B:Rename(handle,name)
    local window,err=Guard(handle);if not window then return nil,err end
    name=Name(name);if not name then return nil,L["Use a name of 1–31 characters without formatting or line breaks."] end
    if not FCF_SetWindowName then return nil,L["Chat configuration is unavailable on this client."] end
    FCF_SetWindowName(window.frame,name);SavedChanged();return true
end
function B:Close(handle)
    local window,err=Guard(handle);if not window then return nil,err end
    if window.primary then return nil,L["The primary chat window cannot be closed."] end
    if not FCF_Close then return nil,L["Chat configuration is unavailable on this client."] end
    FCF_Close(window.frame);SavedChanged();return true
end
function B:SetDocked(handle,enabled)
    local window,err=Guard(handle);if not window then return nil,err end
    if window.primary then return nil,L["The primary chat window stays docked."] end
    local method=enabled and ns.Chat.DockWindow or ns.Chat.PopOutWindow
    if not method then return nil,L["Chat configuration is unavailable on this client."] end
    method(ns.Chat,window.frame);SavedChanged();return true
end
function B:OpenBlizzard(handle)
    local window,err=Guard(handle,true);if not window then return nil,err end
    if self:Pending() then return nil,L["Reload to activate saved filters before opening Blizzard settings."] end
    if not ChatConfigFrame then return nil,L["Chat configuration is unavailable on this client."] end
    CURRENT_CHAT_FRAME_ID=window.id
    ShowUIPanel(ChatConfigFrame)
    if ChatConfigFrame.ChatTabManager then ChatConfigFrame.ChatTabManager:UpdateSelection(window.id) end
    return true
end
function B:Watch(callback)
    observers[callback]=true
    if not hooked then
        hooked=true
        for _, name in ipairs({"FCF_Close","FCF_OpenNewWindow","FCF_SetWindowName","FCF_DockFrame","FCF_UnDockFrame","AddChatWindowMessages","RemoveChatWindowMessages","AddChatWindowChannel","RemoveChatWindowChannel"}) do
            if type(_G[name])=="function" then
                hooksecurefunc(name,function(frame,fallback)
                    if name=="FCF_Close" then
                        frame=fallback or frame or (FCF_GetCurrentChatFrame and FCF_GetCurrentChatFrame())
                        if frame and frame.GetID then local id=frame:GetID();generations[id]=(generations[id] or 0)+1 end
                    end
                    if next(observers) then Changed() end
                end)
            end
        end
    end
    if not events then events=CreateFrame("Frame");events:SetScript("OnEvent",Changed) end
    for _, event in ipairs({"UPDATE_CHAT_WINDOWS","UPDATE_FLOATING_CHAT_WINDOWS","CHANNEL_UI_UPDATE","PLAYER_ENTERING_WORLD","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED"}) do events:RegisterEvent(event) end
end
function B:Unwatch(callback)
    observers[callback]=nil
    if not next(observers) and events then events:UnregisterAllEvents() end
end
