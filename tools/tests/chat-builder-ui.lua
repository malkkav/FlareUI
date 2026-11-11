local ns = dofile('tools/tests/chat-builder.lua')
local objects, dialogs = {}, {}
local Frame = {}; Frame.__index=Frame
function Frame:SetPoint(...) self.point={...} end
function Frame:ClearAllPoints() self.point=nil end
function Frame:SetAllPoints() end
function Frame:SetSize(w,h) self.width=w;self.height=h end
function Frame:SetWidth(w) self.width=w end
function Frame:SetHeight(h) self.height=h end
function Frame:GetWidth() return self.width or 680 end
function Frame:GetHeight() return self.height or 520 end
function Frame:SetText(t) if self.buttonFont then self.buttonFont:SetText(t) else self.text=t end;if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end end
function Frame:GetText() return self.buttonFont and self.buttonFont:GetText() or self.text or '' end
function Frame:SetFontString(f) self.buttonFont=f end
function Frame:SetTextColor() end
function Frame:SetFontObject() end
function Frame:SetJustifyH() end
function Frame:SetJustifyV() end
function Frame:SetWordWrap() end
function Frame:SetColorTexture() end
function Frame:SetTexture() end
function Frame:SetVertexColor() end
function Frame:SetAutoFocus() end
function Frame:SetMaxLetters() end
function Frame:ClearFocus() self.focus=false end
function Frame:HasFocus() return self.focus or false end
function Frame:SetFocus() self.focus=true end
function Frame:SetScript(k,fn) self.scripts[k]=fn end
function Frame:HookScript(k,fn) local prev=self.scripts[k];self.scripts[k]=function(...) if prev then prev(...) end;fn(...) end end
function Frame:Show() self.shown=true;if self.scripts.OnShow then self.scripts.OnShow(self) end end
function Frame:Hide() self.shown=false;if self.scripts.OnHide then self.scripts.OnHide(self) end end
function Frame:SetShown(v) if v then self:Show() else self:Hide() end end
function Frame:IsShown() return self.shown~=false end
function Frame:IsVisible() return self:IsShown() and (not self.parent or self.parent:IsVisible()) end
function Frame:SetEnabled(v) self.enabled=v end
function Frame:IsEnabled() return self.enabled~=false end
function Frame:SetChecked(v) self.checked=v end
function Frame:GetChecked() return self.checked end
function Frame:EnableMouse() end
function Frame:EnableMouseWheel() end
function Frame:SetScrollChild(c) self.scrollChild=c end
function Frame:SetVerticalScroll(v) self.scroll=v end
function Frame:GetVerticalScroll() return self.scroll or 0 end
function Frame:GetVerticalScrollRange() return math.max(0,(self.scrollChild and self.scrollChild:GetHeight() or 0)-self:GetHeight()) end
function Frame:GetParent() return self.parent end
function Frame:SetDefaultText(v) self.text=v end
function Frame:SetupMenu(fn) self.menu=fn end
function Frame:GenerateMenu() end
function Frame:RegisterEvent() end
function Frame:UnregisterAllEvents() end
function Frame:SetNormalFontObject() end
function Frame:SetHighlightFontObject() end
function Frame:SetDisabledFontObject() end
function Frame:SetHighlightTexture() end
function Frame:GetFontString() return self end
function Frame:GetUnboundedStringWidth() return #self:GetText()*7 end
function Frame:GetStringHeight() return 40 end
local function new(kind,parent)
    local f=setmetatable({kind=kind,parent=parent,scripts={},children={}},Frame)
    objects[#objects+1]=f;if parent then parent.children[#parent.children+1]=f end
    return f
end
function Frame:CreateFontString() return new('FontString',self) end
function Frame:CreateTexture() return new('Texture',self) end
CreateFrame=function(kind,name,parent,template) local f=new(kind,parent);if kind=='CheckButton' then f.Text=f:CreateFontString() end;return f end
ns.SkinButton=function() end;ns.ButtonSound=function() end
ns.SettingsPanel={Box=function() end,FONT={GameFontHighlight="PanelText"}, AttachScrollLine=function(scroll) scroll.standardScroll=true end, SkinDropdown=function(dd) dd.standardDropdown=true end, Rounded=function() end,Open=function(_,module,tab) ns.opened=tab end,
    Switch=function(parent) local f=CreateFrame('CheckButton',nil,parent);f.standardSwitch=true;return f end,
    Plate=function(parent) local f=CreateFrame('Button',nil,parent);f.Text=f:CreateFontString();function f:SetSelected(on) self.isSelected=on end;return f end}
ns.Dialogs={}
ns.ShowDialog=function(key,text,data) dialogs[#dialogs+1]={key=key,text=text,data=data} end
local function click(text)
    for i=#objects,1,-1 do local o=objects[i];if o.kind=='Button' and o:GetText()==text and o:IsVisible() and o:IsEnabled() then assert(o.scripts.OnClick,'no click handler');o.scripts.OnClick(o);return o end end
    error('No enabled visible button: '..text)
end
local function accept(text) local d=assert(dialogs[#dialogs]);ns.Dialogs[d.key].OnAccept(d.data,text) end
local f=loadfile('Settings/ChatBuilder.lua');if f then f('FlareUI',ns) end
assert(ns.ChatBuilderEditor,'chat builder editor is missing')
local host,side=new('Frame'),new('Frame');side:SetWidth(260)
ns.ChatBuilderEditor.Build(host,side);host:Show();ns.ChatBuilderEditor.Refresh()
local originalStatus=ns.ChatBuilder.Status
ns.ChatBuilder.Status=function() return nil,'Long warning' end;ns.ChatBuilderEditor.Refresh()
local noticeScroll
for _,o in ipairs(objects) do if o.kind=='FontString' and o:GetText()=='Long warning' then noticeScroll=o.parent.parent end end
assert(noticeScroll);noticeScroll:SetVerticalScroll(100)
ns.ChatBuilder.Status=function() return nil,'New error' end;ns.ChatBuilderEditor.Refresh()
assert(noticeScroll:GetVerticalScroll()==0,'new notices must start visible after scrolling an older message')
ns.ChatBuilder.Status=originalStatus;ns.ChatBuilderEditor.Refresh()
local dropdowns={}
for _,o in ipairs(objects) do if o.kind=='DropdownButton' then dropdowns[#dropdowns+1]=o end end
local layout,addLayout,category=unpack(dropdowns)
local function choose(dd,label)
    local choices={};dd.menu(dd,{CreateRadio=function(_,name,checked,action) choices[name]=action end})
    assert(choices[label],'missing choice '..label);choices[label]()
end
assert(not pcall(click,'More options') and not pcall(click,'Use a preset'),'no extra menus or preset screen')
click('Social');click('Move up');assert(ns.ChatBuilder:Windows()[3].id==3)
click('Rename');accept('Friends');assert(GetChatWindowInfo(3)=='Friends')
local function selectedHandle() for _,h in ipairs(ns.ChatBuilder:Windows()) do if h.id==3 then return h end end end
local search,nameBox
for _,o in ipairs(objects) do if o.kind=='EditBox' then if o:IsVisible() then search=o else nameBox=o end end end
assert(search and nameBox)
local filterScroll
for _,o in ipairs(objects) do if o.kind=='CheckButton' and o.parent.entry then filterScroll=o.parent.parent.parent;break end end
assert(filterScroll and filterScroll.point[1]=='BOTTOMRIGHT' and filterScroll.point[3]==0,'filter list uses the bottom edge with no status footer')
local middle=filterScroll.parent
local rename;for _,o in ipairs(objects) do if o.kind=='Button' and o:GetText()=='Rename' then rename=o end end
assert(rename.parent~=middle and rename.parent.parent==middle.parent,'window actions occupy a separate right column')
local layoutAnchor=middle.point
assert(layoutAnchor[1]=='BOTTOMRIGHT' and layoutAnchor[3]=='BOTTOMLEFT','middle ends before the right control column')

search:SetText('loot')
local loot
for _,o in ipairs(objects) do if o.kind=='CheckButton' and o:IsVisible() and o.parent.entry then assert(o.parent.entry.key=='LOOT');loot=o end end
assert(loot);loot.parent.scripts.OnMouseUp(loot.parent,'LeftButton')
assert(ns.ChatBuilder:Read(selectedHandle()).activeMessages.LOOT)
search:SetText('');choose(category,'Public Channels')
for _,o in ipairs(objects) do if o.kind=='CheckButton' and o:IsVisible() and o.parent.entry then assert(o.parent.entry.kind=='channel') end end
choose(category,'All categories')
-- Starting layouts only preview; Apply is the explicit destructive boundary.
choose(layout,'Empty');assert(ns.ChatBuilder:Read(selectedHandle()).messages.LOOT,'preview preserves actual routing')
for _,o in ipairs(objects) do if o.kind=='CheckButton' and o:IsVisible() and o.parent.entry then assert(not o:IsEnabled(),'preview cannot accidentally edit live routing') end end
click('Cancel');assert(ns.ChatBuilder:Read(selectedHandle()).messages.LOOT,'cancel leaves current settings intact')
choose(layout,'Empty');click('Apply layout');assert(not ns.ChatBuilder:Read(selectedHandle()).messages.LOOT)
choose(layout,'Friends & Guild');click('General');assert(not pcall(click,'Apply layout'),'switching window cancels pending layout')
click('Friends');choose(layout,'Friends & Guild');click('Apply layout');assert(ns.ChatBuilder:Read(selectedHandle()).activeMessages.GUILD)
-- Add is an inline name/layout form, with the selected window still visible.
FCF_Close(ChatFrame4);ns.ChatBuilderEditor.Refresh()
local countWindows=#ns.ChatBuilder:Windows()
local beforeDraft=table.concat({GetChatWindowMessages(3)},',')
click('Add window');assert(not layout:IsVisible(),'existing-window layout is hidden while adding')
assert(middle.point==layoutAnchor and filterScroll.point[3]==0,'creation does not shrink the channel selection area')
local previewBadge=false
for _,o in ipairs(objects) do if o:IsVisible() and o:GetText()=='New window preview' then previewBadge=true end end
assert(previewBadge,'draft has a compact preview label')
assert(not pcall(click,'Rename') and not pcall(click,'Delete window') and not pcall(click,'Duplicate'),'old window actions hidden during creation')
for _,o in ipairs(objects) do if o.window then assert(not o.isSelected,'no existing window looks selected during a draft') end end
choose(addLayout,'Party & Raid')
local draftParty,draftGuild
for _,o in ipairs(objects) do if o.kind=='CheckButton' and o:IsVisible() and o.parent.entry then
    assert(not o:IsEnabled(),'draft preview cannot mutate old window')
    if o.parent.entry.key=='PARTY' then draftParty=o:GetChecked() end
    if o.parent.entry.key=='GUILD' then draftGuild=o:GetChecked() end
end end
assert(draftParty and not draftGuild,'draft filters follow new layout, not the old window')
assert(table.concat({GetChatWindowMessages(3)},',')==beforeDraft,'draft preserves existing routing')
choose(addLayout,'Friends & Guild');assert(nameBox:GetText()=='Friends & Guild')
click('Edit name');assert(ns.Dialogs.CHAT_BUILDER_NAME.padInput);accept('My own name');choose(addLayout,'Loot')
assert(nameBox:GetText()=='My own name','changing a starting layout preserves a user-entered name')
local draftTitle=false;for _,o in ipairs(objects) do if o:IsVisible() and o:GetText()=='New window: My own name' then draftTitle=true end end
assert(draftTitle,'heading follows draft name')
click('Cancel');assert(#ns.ChatBuilder:Windows()==countWindows)
click('Add window');choose(addLayout,'Empty');nameBox:SetText('Empty test');click('Create window')
assert(GetChatWindowInfo(4)=='Empty test' and #({GetChatWindowMessages(4)})==0)
local newSelected,newTitle=false,false
for _,o in ipairs(objects) do
    if o.window and o.window.id==4 and o.isSelected then newSelected=true end
    if o.kind=='FontString' and o:GetText()=='Empty test' and o:IsVisible() and not o.parent.window then newTitle=true end
end
assert(newSelected and newTitle,'creation focuses new window in list and editor')
click('Delete window');accept();click('Friends')
click('Add window');choose(addLayout,'Friends & Guild');nameBox:SetText('Preset copy');click('Create window')
assert(GetChatWindowInfo(4)=='Preset copy')
local groups={};for _,g in ipairs({GetChatWindowMessages(4)}) do groups[g]=true end;assert(groups.GUILD)
click('Delete window');accept();click('Friends');click('Duplicate');accept('Duplicate test')
assert(GetChatWindowInfo(4)=='Duplicate test');click('Delete window');accept();click('Friends')
-- Native close invalidates a pending preview rather than redirecting it to another window.
choose(layout,'Empty');FCF_Close(ChatFrame3);ns.ChatBuilderEditor.Refresh();assert(not pcall(click,'Apply layout'))
click('General');assert(not pcall(click,'Pop out') and not pcall(click,'Delete window'))
click('Combat Log');assert(not layout:IsEnabled() and not pcall(click,'Duplicate'))
local nativeVisible=false;for _,o in ipairs(objects) do if o:GetText()=='Open Blizzard Settings' and o:IsVisible() then nativeVisible=true end end;assert(nativeVisible)
click('General');choose(layout,'Friends & Guild');host:Hide();side:Show();host:Show();assert(not pcall(click,'Apply layout'))
for _,key in ipairs({'GetChatWindowMessages','GetChatWindowChannels'}) do
    local original=_G[key];_G[key]=nil;assert(pcall(ns.ChatBuilderEditor.Refresh));_G[key]=original
end
local registered
ns.Settings={Module=function(_,definition) registered=definition end,Row=function() end,On=function() end,
    FontRows=function() end,OpacityChoices=function() return {} end,MinAlphaChoices=function() return {} end}
assert(loadfile('Settings/Pages/Chat.lua'))('FlareUI',ns)
local builderTab
for _,tab in ipairs(registered.tabs) do if tab.key=='builder' then builderTab=tab end end
assert(builderTab and not builderTab.wide and builderTab.spanRight and builderTab.label=='Windows','Windows reuses the right column without growing the panel')
-- Execute the actual custom-page layout lifecycle with minimal frame primitives.
local file=assert(io.open('Settings/Panel.lua'));local source=file:read('*a');file:close()
local first=assert(source:find('local function HideCustom()',1,true))
local last=assert(source:find('local UpdateNav',first,true))
local panel={middleBox=new('Frame')};local page={right=new('Frame'),root=new('Frame'),header=new('Frame')}
local preview={host=new('Frame'),picture=new('Frame'),title=new('Frame'),desc=new('Frame'),tip=new('Frame')}
local env=setmetatable({Panel=panel,page=page,preview=preview,customHosts={},GAP=8},{__index=_G})
local chunk=assert(loadstring(source:sub(first,last-1)..'\nreturn HideCustom,ShowCustom'));setfenv(chunk,env)
local hide,show=chunk();local built=0
show({key='chat'},{key='windows',spanRight=true,custom=function() built=built+1 end})
assert(not page.right:IsShown() and panel.middleBox.point[3]=='BOTTOMRIGHT','spanning hides the old sidebar')
hide();assert(page.right:IsShown() and panel.middleBox.point[3]=='BOTTOMLEFT','leaving restores normal settings geometry')
show({key='chat'},{key='windows',spanRight=true,custom=function() built=built+1 end});assert(built==1,'custom host reused')
hide()
print('PASS: single-screen chat editor, inline add, layout preview/apply, protections, and settings lifecycle')
