-- Saved client state is deliberately separate from live routing in this fixture.
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
    frames[id], _G['ChatFrame'..id] = f, f
    return f
end
addWindow(1,'General'); addWindow(2,'Combat Log'); addWindow(3,'Social')
DEFAULT_CHAT_FRAME = frames[1]
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
FCF_CanOpenNewWindow = function() return windows[4]==nil end
FCF_OpenNewWindow = function(name,blank) if not FCF_CanOpenNewWindow() then return end;local f=addWindow(4,name);windows[4].messages={};windows[4].channels={};f.messageTypeList={};f.channelList={};f.zoneChannelList={};fire('FCF_OpenNewWindow',name,blank);return f,4 end
FCF_Close = function(f) windows[f.id].shown=false;windows[f.id].docked=false;fire('FCF_Close',f) end
FCF_SetWindowName = function(f,name) windows[f.id].name=name;fire('FCF_SetWindowName',f,name) end
ns.Chat.PopOutWindow=function(_,f) f.isDocked=false;windows[f.id].docked=false end
ns.Chat.DockWindow=function(_,f) f.isDocked=true;windows[f.id].docked=true end
local function load(path) local f=loadfile(path); if f then f('FlareUI',ns) end end
load('Modules/ChatBuilderCatalog.lua'); load('Modules/ChatBuilder.lua')
assert(ns.ChatBuilder, 'chat builder backend is missing')
local B = ns.ChatBuilder
B:Watch(function() end)
local function handle(id) for _,h in ipairs(B:Windows()) do if h.id==id then return h end end end
local h=assert(handle(3))
assert(B:SetFilter(h,'message','GUILD',true))
assert(windows[3].messages.GUILD and not windows[1].messages.GUILD, 'toggle must affect selected window only')
assert(not set(frames[3].messageTypeList).GUILD, 'saved edits must not write live routing tables')
assert(B:Read(h).pending and B:Pending(), 'pending reload must be visible')
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
local created=assert(B:Create('New','blank')); assert(created.id==4)
assert(not B:Create('Full','blank'));assert(windows[3].name=='Social', 'capacity failure preserves existing windows')
assert(B:Close(h)); windows[3].shown=true;windows[3].docked=true
assert(not B:Rename(h,'Stale'), 'closed/reused frame must reject old handle even with same name')
h=assert(handle(3));assert(B:SetDocked(h,false));assert(not windows[3].docked)
assert(B:SetDocked(h,true));assert(windows[3].docked)
local savedAdd = AddChatWindowMessages
AddChatWindowMessages=function() end
windows[3].messages.GUILD=nil
assert(not B:SetFilter(h,'message','GUILD',true), 'a rejected write must not report success')
AddChatWindowMessages=savedAdd
windows[3].messages.SAY=nil;windows[3].messages.GUILD=nil
AddChatWindowMessages=function(id,g) if g=='GUILD' then error('client rejected change') end;savedAdd(id,g) end
local ok,result=pcall(function() return B:ApplyPreset(h,'social') end)
assert(ok and not result,'client errors must be reported without escaping UI callbacks')
assert(not windows[3].messages.SAY,'partial preset writes must roll back')
AddChatWindowMessages=savedAdd
ns.Tweaks={syncLoading=true};assert(not B:SetFilter(h,'message','SAY',true));ns.Tweaks=nil
local savedChannelPreset=assert(B:SavePreset(h,'Offline channels'))
assert(set(savedChannelPreset.channels)['name:unknown'],'saved templates retain unavailable channel assignments')
assert(not B:OpenBlizzard(h),'native configuration must not present stale active state while filters are pending')
local getMessages=GetChatWindowMessages;GetChatWindowMessages=nil
local readOK,readResult=pcall(function() return B:Read(h) end)
assert(readOK and readResult==nil,'unsupported clients must return unavailable state instead of throwing')
assert(not B:Pending(),'pending state must tolerate unavailable APIs')
GetChatWindowMessages=getMessages
print('PASS: chat builder saved state, presets, channel identity, guards, and lifecycle')
return ns
