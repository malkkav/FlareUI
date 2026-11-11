-- Client methods update both live routing and persisted settings, as Forever's mixins do.
local function set(list) local t = {}; for _, v in pairs(list) do t[v] = true end; return t end
local function list(t) local a = {}; for k in pairs(t) do a[#a+1] = k end; table.sort(a); return a end
local hooks, frames, windows = {}, {}, {}
local combat = false
local ns = { L = setmetatable({}, {__index=function(_,k) return k end}), Chat = {started=true},
    db = {profile={chat={enabled=true}},global={}} }
Constants = {ChatFrameConstants={MaxChatWindows=5}}
ChatTypeGroup = {}
for _, g in ipairs({'SAY','GUILD','OFFICER','WHISPER','PARTY','LOOT','CHANNEL','SYSTEM','FUTURE_GROUP'}) do ChatTypeGroup[g] = {} end
InCombatLockdown = function() return combat end
local function addWindow(id, name, special)
    windows[id] = {name=name,shown=true,docked=true, messages={SAY=true,FUTURE_GROUP=true},channels={['Général']=1,['Unknown']=0}}
    local f = {id=id, messageTypeList={'SAY','FUTURE_GROUP'},channelList={'Général','Unknown'},zoneChannelList={1,0},isDocked=true}
    function f:GetID() return self.id end
    function f:IsForbidden() return false end
    function f:AddMessageGroup(group)
        table.insert(self.messageTypeList,group)
        AddChatWindowMessages(self.id,group)
    end
    function f:RemoveMessageGroup(group)
        for i,g in pairs(self.messageTypeList) do if g==group then self.messageTypeList[i]=nil end end
        RemoveChatWindowMessages(self.id,group)
    end
    function f:AddChannel(name)
        local zone=AddChatWindowChannel(self.id,name)
        if zone then local i=1;while self.channelList[i] do i=i+1 end;self.channelList[i]=name;self.zoneChannelList[i]=zone end
    end
    function f:RemoveChannel(name)
        for i,n in pairs(self.channelList) do if n==name then self.channelList[i]=nil;self.zoneChannelList[i]=nil end end
        RemoveChatWindowChannel(self.id,name)
    end
    frames[id], _G['ChatFrame'..id] = f, f
    return f
end
addWindow(1,'General'); addWindow(2,'Combat Log'); addWindow(3,'Social')
DEFAULT_CHAT_FRAME = frames[1]
GeneralDockManager={DOCKED_CHAT_FRAMES={frames[1],frames[2],frames[3]}}
local function undock(f)
    for i,v in ipairs(GeneralDockManager.DOCKED_CHAT_FRAMES) do if v==f then table.remove(GeneralDockManager.DOCKED_CHAT_FRAMES,i);return end end
end
local moves=0
ns.Chat.MoveWindowBefore=function(_,f,before)
    undock(f)
    local index=#GeneralDockManager.DOCKED_CHAT_FRAMES+1
    for i,v in ipairs(GeneralDockManager.DOCKED_CHAT_FRAMES) do if v==before then index=i;break end end
    table.insert(GeneralDockManager.DOCKED_CHAT_FRAMES,index,f);moves=moves+1
end
IsCombatLog = function(f) return f.id==2 end
GetChatWindowInfo = function(id) local w=windows[id]; if not w then return '' end; return w.name,14,0,0,0,0,w.shown,false,w.docked,false end
GetChatWindowMessages = function(id) return unpack(list(windows[id].messages)) end
GetChatWindowChannels = function(id) local a={}; for name,zone in pairs(windows[id].channels) do a[#a+1]=name;a[#a+1]=zone end; return unpack(a) end
AddChatWindowMessages = function(id,g) windows[id].messages[g]=true end
RemoveChatWindowMessages = function(id,g) windows[id].messages[g]=nil end
local joined = { {index=7,name='Général',zone=1}, {index=2,name='Commerce',zone=2}, {index=9,name='OOC',zone=0} }
GetChannelList = function() local a={};for _,c in ipairs(joined) do a[#a+1]=c.index;a[#a+1]=c.name;a[#a+1]=false end;return unpack(a) end
C_ChatInfo = {GetChannelInfoFromIdentifier=function(name) for _,c in ipairs(joined) do if c.name==name then return {name=name,zoneChannelID=c.zone,localID=c.index} end end end}
AddChatWindowChannel = function(id,name) for _,c in ipairs(joined) do if c.name==name then windows[id].channels[name]=c.zone;return c.zone end end end
RemoveChatWindowChannel = function(id,name) windows[id].channels[name]=nil end
local function fire(name,...) for _,f in ipairs(hooks[name] or {}) do f(...) end end
hooksecurefunc = function(name,fn) hooks[name]=hooks[name] or {};table.insert(hooks[name],fn) end
CreateFrame = function() return {SetScript=function(self,k,v) self[k]=v end,RegisterEvent=function() end,UnregisterAllEvents=function() end} end
C_Timer = {After=function(_,fn) fn() end}
FCF_CanOpenNewWindow = function() return windows[4]==nil or not windows[4].shown end
FCF_OpenNewWindow = function(name,blank) if not FCF_CanOpenNewWindow() then return end;local f=addWindow(4,name);table.insert(GeneralDockManager.DOCKED_CHAT_FRAMES,f);windows[4].messages={};windows[4].channels={};f.messageTypeList={};f.channelList={};f.zoneChannelList={};fire('FCF_OpenNewWindow',name,blank);return f,4 end
FCF_Close = function(f) undock(f);windows[f.id].shown=false;windows[f.id].docked=false;fire('FCF_Close',f) end
FCF_SetWindowName = function(f,name) windows[f.id].name=name;fire('FCF_SetWindowName',f,name) end
ns.Chat.PopOutWindow=function(_,f) undock(f);f.isDocked=false;windows[f.id].docked=false end
ns.Chat.DockWindow=function(_,f) undock(f);table.insert(GeneralDockManager.DOCKED_CHAT_FRAMES,f);f.isDocked=true;windows[f.id].docked=true end
local function load(path) local f=loadfile(path); if f then f('FlareUI',ns) end end
load('Modules/ChatBuilderCatalog.lua'); load('Modules/ChatBuilder.lua')
assert(ns.ChatBuilder, 'chat builder backend is missing')
local B = ns.ChatBuilder
-- Preset intent: broad everyday chat, focused social/group/reward/trade windows.
local presets={};local known={}
for _,cat in ipairs(ns.ChatBuilderCatalog.categories) do for _,entry in ipairs(cat.entries) do known[entry[1]]=true end end
for _,preset in ipairs(ns.ChatBuilderCatalog.presets) do
    presets[preset.id]=preset
    local seen={}
    for _,group in ipairs(preset.messages) do assert(known[group] and not seen[group],'preset group must be catalogued and unique');seen[group]=true end
    for _,channel in ipairs(preset.channels) do assert(ns.ChatBuilderCatalog.channelNames[channel],'preset channels need stable known identities') end
end
assert(set(presets.general.channels)['zone:1'] and set(presets.general.channels)['zone:22'])
assert(set(presets.general.messages).MONSTER_WHISPER and set(presets.general.messages).MONSTER_BOSS_EMOTE,'general retains quest and encounter dialogue')
assert(set(presets.social.messages).YELL and set(presets.social.messages).GUILD and #presets.social.channels==0)
assert(set(presets.group.messages).BG_NEUTRAL and set(presets.group.messages).RAID_WARNING and #presets.group.channels==0)
assert(set(presets.loot.messages).COMBAT_HONOR_GAIN and set(presets.loot.messages).TRADESKILLS and #presets.loot.channels==0)
assert(set(presets.trade.channels)['zone:2'] and set(presets.trade.channels)['zone:42'] and set(presets.trade.messages).WHISPER,'trade includes channels and replies')
assert(#presets.blank.messages==0 and #presets.blank.channels==0)

B:Watch(function() end)
local function handle(id) for _,h in ipairs(B:Windows()) do if h.id==id then return h end end end
local h=assert(handle(3))
assert(B:SetFilter(h,'message','GUILD',true))
assert(windows[3].messages.GUILD and not windows[1].messages.GUILD, 'toggle must affect selected window only')
assert(set(frames[3].messageTypeList).GUILD, 'filter edits must update active routing immediately')
assert(not B:Read(h).pending, 'live and saved filters must agree without reload')
assert(B:SetFilter(h,'message','GUILD',true))
local guildCount=0;for _,g in pairs(frames[3].messageTypeList) do if g=='GUILD' then guildCount=guildCount+1 end end
assert(guildCount==1,'reapplying a filter must not duplicate native routing entries')
assert(B:SetFilter(h,'message','GUILD',false)); assert(not B:Read(h).pending, 'reverting to live state clears pending')
assert(B:ApplyPreset(h,'blank')); assert(windows[3].messages.FUTURE_GROUP, 'preserve unknown groups')
assert(windows[3].channels.Unknown==0, 'preserve unavailable channel assignments')
assert(not windows[3].channels['Général'], 'clear known channel when applying blank')
assert(B:ApplyPreset(h,'general')); assert(windows[3].channels['Général']==1, 'resolve localized zone channel by identity')
assert(not windows[3].channels.Commerce)
assert(B:SetFilter(h,'channel','name:ooc',true)); assert(windows[3].channels.OOC==0)
local saved=assert(B:SavePreset(h,'Mine')); assert(saved.id)
assert(B:SetFilter(h,'message','SAY',false)); assert(B:ApplyPreset(h,saved.id)); assert(windows[3].messages.SAY, 'preset must be a copy')
joined[1].index=12; joined[1].name='General - New Zone'
local result=assert(B:ApplyPreset(h,saved.id)); assert(B:Read(h).channels['zone:1'], 'zone identity survives channel numbering and naming')
joined[1]=table.remove(joined); result=assert(B:ApplyPreset(h,'general')); assert(#result.skipped>0, 'unavailable preset channels reported')
combat=true; assert(not B:SetFilter(h,'message','SAY',false)); assert(not B:Close(h)); combat=false
ns.Chat.started=false;assert(not B:Rename(h,'Changed'));ns.Chat.started=true
assert(not B:Close(handle(1))); assert(not B:Close(handle(2))); assert(not B:SetFilter(handle(2),'message','SAY',false))
assert(not B:Rename(h,'  ')); assert(not B:Rename(h,'bad|cffff0000name'))
assert(not B:Rename(h,string.rep('x',32)), 'match the existing native 31-character name entry limit')
assert(B:RenamePreset(saved.id,'Renamed')); assert(B:DeletePreset(saved.id));assert(not B:ApplyPreset(h,saved.id));assert(not B:DeletePreset('general'))
local before=windows[3].messages.SAY
ns.db.global.chatBuilderPresets.items.bad={id='bad',name='bad',messages='broken',channels={}}
assert(not B:ApplyPreset(h,'bad'));assert(windows[3].messages.SAY==before, 'invalid preset must not partially apply')
local duplicate,copyResult=B:Duplicate(h,'Social copy')
assert(duplicate and duplicate.id==4,'duplicate creates a separate named window')
assert(windows[4].name=='Social copy' and windows[3].name=='Social')
assert(windows[4].messages.FUTURE_GROUP,'duplicate preserves supported native groups outside builder catalog')
assert(not B:Read(duplicate).pending,'duplicated filters must be live immediately')
assert(#copyResult.skipped>0,'duplicate reports unavailable channel assignments')
assert(not B:Duplicate(h,'No room'),'duplicate respects client capacity')
assert(B:Close(duplicate))
local created=assert(B:Create('New','blank')); assert(created.id==4)
assert(not B:Move(h,-1),'cannot move before protected Combat Log')
assert(not B:Move(handle(1),1) and not B:Move(handle(2),1),'fixed windows cannot move')
assert(B:Move(created,-1));assert(B:Windows()[3].id==4 and B:Windows()[4].id==3,'list must follow dock order')
assert(B:Move(created,1));assert(B:Windows()[4].id==4,'moving down restores order')
assert(not B:Move(created,1),'end boundary cannot move')
combat=true;assert(not B:Move(created,-1));combat=false
assert(B:SetDocked(created,false));assert(not B:Move(created,-1),'popped windows cannot reorder dock')
assert(B:SetDocked(created,true));assert(moves==2,'invalid moves never call dock mutation')

assert(not B:Create('Full','blank'));assert(windows[3].name=='Social', 'capacity failure preserves existing windows')
assert(B:Close(h)); windows[3].shown=true;windows[3].docked=true
assert(not B:Rename(h,'Stale'), 'closed/reused frame must reject old handle even with same name')
h=assert(handle(3));assert(B:SetDocked(h,false));assert(not windows[3].docked)
assert(B:SetDocked(h,true));assert(windows[3].docked)
local savedAdd = AddChatWindowMessages
frames[3]:RemoveMessageGroup('GUILD')
AddChatWindowMessages=function() end
assert(not B:SetFilter(h,'message','GUILD',true), 'a rejected write must not report success')
AddChatWindowMessages=savedAdd
frames[3]:RemoveMessageGroup('SAY');frames[3]:RemoveMessageGroup('GUILD')
AddChatWindowMessages=function(id,g) if g=='GUILD' then error('client rejected change') end;savedAdd(id,g) end
local ok,result=pcall(function() return B:ApplyPreset(h,'social') end)
assert(ok and not result,'client errors must be reported without escaping UI callbacks')
assert(not windows[3].messages.SAY,'partial preset writes must roll back')
assert(not set(frames[3].messageTypeList).SAY,'rollback must restore active routing too')
AddChatWindowMessages=savedAdd
-- Saved-only edits from UI sync or an older builder must survive a failed transaction exactly.
frames[3]:RemoveMessageGroup('SAY');savedAdd(3,'SAY')
AddChatWindowMessages=function(id,g) if g=='GUILD' then error('client rejected change') end;savedAdd(id,g) end
assert(not B:ApplyPreset(h,'social'))
assert(windows[3].messages.SAY and not set(frames[3].messageTypeList).SAY,'rollback preserves distinct saved and active snapshots')
AddChatWindowMessages=savedAdd
ns.Tweaks={syncLoading=true};assert(not B:SetFilter(h,'message','SAY',true));ns.Tweaks=nil
local savedChannelPreset=assert(B:SavePreset(h,'Offline channels'))
assert(set(savedChannelPreset.channels)['name:unknown'],'saved templates retain unavailable channel assignments')
ChatConfigFrame={ChatTabManager={UpdateSelection=function(_,id) assert(id==3) end}}
ShowUIPanel=function() end
assert(B:OpenBlizzard(h),'native settings remain available without a reload')
local getMessages=GetChatWindowMessages;GetChatWindowMessages=nil
local readOK,readResult=pcall(function() return B:Read(h) end)
assert(readOK and readResult==nil,'unsupported clients must return unavailable state instead of throwing')
assert(not B:Pending(),'pending state must tolerate unavailable APIs')
GetChatWindowMessages=getMessages
print('PASS: chat builder saved state, presets, channel identity, guards, and lifecycle')
return ns
