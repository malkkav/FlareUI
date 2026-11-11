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
function Frame:SetText(t) self.text=t;if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end end
function Frame:GetText() return self.text or '' end
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
ns.SettingsPanel={Rounded=function() end,Open=function(_,module,tab) ns.opened=tab end}
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
click('Social');click('Rename');local before=GetChatWindowInfo(3)
assert(before=='Social','opening rename must not mutate');accept('Friends');assert(GetChatWindowInfo(3)=='Friends')
click('Save preset');accept('Friends preset')
local found;for _,p in ipairs(ns.ChatBuilder:Presets()) do if p.name=='Friends preset' then found=p end end
assert(found,'save action must persist preset')
local search
for _,o in ipairs(objects) do if o.kind=='EditBox' then search=o end end
assert(search);search:SetFocus();search:SetText('loot')
local loot
for _,o in ipairs(objects) do
    if o.kind=='CheckButton' and o:IsVisible() then
        assert(o.parent.entry.key=='LOOT','filter search must hide nonmatching entries')
        loot=o
    end
end
assert(loot,'search must find item loot');loot:SetChecked(true);loot.scripts.OnClick(loot)
local selectedHandle
for _,h in ipairs(ns.ChatBuilder:Windows()) do if h.id==3 then selectedHandle=h end end
assert(ns.ChatBuilder:Read(selectedHandle).messages.LOOT,'checkbox must change selected window saved filter')
assert(search:HasFocus() and search:GetText()=='loot','refresh preserves search input and focus')
search:SetText('')
for _,o in ipairs(objects) do
    if o.kind=='Button' and o:GetText()=='All' and o.parent.category=='conversations' and o:IsVisible() then o.scripts.OnClick(o);break end
end
assert(ns.ChatBuilder:Read(selectedHandle).messages.OFFICER,'category action includes individual supported groups')
local dropdown
for _,o in ipairs(objects) do if o.kind=='DropdownButton' then dropdown=o end end
local options={};dropdown.menu(dropdown,{CreateRadio=function(_,name,checked,action) options[name]=action end})
assert(options.Blank);options.Blank()
click('Load into selected window')
assert(ns.ChatBuilder:Read(selectedHandle).messages.LOOT,'opening preset confirmation must not apply it')
accept();assert(not ns.ChatBuilder:Read(selectedHandle).messages.LOOT,'accepting preset replaces supported filters')
assert(not pcall(click,'Delete preset'),'built-in presets cannot be deleted')
options['Friends preset']();click('Rename preset');accept('Private preset')
assert(ns.ChatBuilder:Preset(found.id).name=='Private preset')
click('Delete preset');assert(ns.ChatBuilder:Preset(found.id),'confirmation alone preserves preset')
accept();assert(not ns.ChatBuilder:Preset(found.id),'confirmed delete removes only the preset')
click('Close window');assert(select(7,GetChatWindowInfo(3)),'opening close confirmation must not close')
-- A pending confirmation is safe even after native close/reuse.
FCF_Close(ChatFrame3);accept();assert(GetChatWindowInfo(3)=='Friends')
click('Frame');assert(ns.opened=='frame','shared appearance route')
local count=#objects;host:Hide();side:Show();ns.ChatBuilderEditor.Refresh();assert(#objects==count,'hidden editor must not build more controls')
for _,o in ipairs(objects) do if o:GetText()=='Save preset' then assert(not o:IsVisible(),'sidebar controls must hide when another custom tab uses the shared side host') end end
host:Show();ns.ChatBuilderEditor.Refresh();assert(#objects<=count+5,'refresh must reuse controls')
for _,key in ipairs({'GetChatWindowMessages','GetChatWindowChannels'}) do
    local original=_G[key];_G[key]=nil
    assert(pcall(ns.ChatBuilderEditor.Refresh),'missing client API must render a disabled availability screen')
    _G[key]=original
end
print('PASS: chat builder UI selection, dialogs, preset persistence, shared appearance, and lifecycle')
