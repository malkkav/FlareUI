local _, ns = ...
local L, B = ns.L, ns.ChatBuilder
local Editor = {}
ns.ChatBuilderEditor = Editor
local ui, selected, presetID = nil, nil, "general"
local activeCategory = "all"
local selectedOnly = false
local Refresh

local function Text(parent, value, size)
    local f = parent:CreateFontString(nil,"OVERLAY",ns.SettingsPanel.FONT[size or "GameFontHighlight"] or size)
    f:SetJustifyH("LEFT");f:SetWordWrap(true);f:SetText(value or "")
    return f
end
local function Button(parent, label, width, action)
    local b = CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    if ns.SkinButton then ns.SkinButton(b) end
    b:SetSize(width,24);b:SetText(label)
    b:SetScript("OnClick",function() ns.ButtonSound();action() end)
    return b
end
local function Tip(control,text)
    control:HookScript("OnEnter",function(self)
        if GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(text,nil,nil,nil,nil,true);GameTooltip:Show() end
    end)
    control:HookScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
end
local function Report(ok, err)
    ui.notice = ok and L["Saved."] or (err or L["The change could not be saved."])
    Refresh()
end
local function Act(fn) local ok,err=fn();Report(ok,err);return ok,err end

-- Dialog callbacks capture a window handle, not the editor's later selection.
ns.Dialogs.CHAT_BUILDER_NAME = {
    text="%s",button1=L["Save"],button2=L["Cancel"],hasEditBox=true,maxLetters=31,hideOnEscape=true,padInput=true,
    editText=function(data) return data.initial or "" end,
    OnAccept=function(data,text) data.accept(text) end,
}
ns.Dialogs.CHAT_BUILDER_CONFIRM = {
    text="%s",button1=L["Confirm"],button2=L["Cancel"],hideOnEscape=true,padInput=true,
    OnAccept=function(data) data.accept() end,
}
local function AskName(title,initial,accept)
    ns.ShowDialog("CHAT_BUILDER_NAME",title,{initial=initial,accept=accept})
end
local function Confirm(title,accept) ns.ShowDialog("CHAT_BUILDER_CONFIRM",title,{accept=accept}) end
local function Select(id)
    selected=nil
    for _, h in ipairs(B:Windows()) do if h.id==id then selected=h end end
    ui.previewID=nil;ui.previewTarget=nil;ui.adding=false
    ui.notice=nil;ui.filters:SetVerticalScroll(0);Refresh()
end
local function Scroll(parent)
    local s=CreateFrame("ScrollFrame",nil,parent)
    local content=CreateFrame("Frame",nil,s)
    content:SetSize(100,1);s:SetScrollChild(content);s.content=content
    ns.SettingsPanel.AttachScrollLine(s,parent,36)
    local function move(delta)
        s:SetVerticalScroll(math.max(0,math.min(s:GetVerticalScrollRange(),s:GetVerticalScroll()+delta)))
    end
    s.PadScroll=function(_,delta) move(delta*36) end
    s:HookScript("OnSizeChanged",function(self,w) content:SetWidth(math.max(40,w)) end)
    return s
end
local function SelectedState()
    if not selected then return nil end
    return B:Read(selected)
end
local function DuplicateWindow()
    local source=selected;if not source then return end
    AskName(L["Duplicate %s into a new window"]:format(source.name),source.name,function(name)
        local h,result=B:Duplicate(source,name)
        if not h then Report(nil,result);return end
        selected=h;ui.notice=L["Window duplicated."]
        if #result.skipped>0 then ui.notice=ui.notice.."\n"..L["Skipped unavailable:"].." "..table.concat(result.skipped,", ") end
        Refresh()
    end)
end
local function Rename()
    local h=selected;if not h then return end
    AskName(L["Rename chat window"],h.name,function(name)
        local ok,err=B:Rename(h,name)
        if ok then Select(h.id) end
        Report(ok,err)
    end)
end
local function ApplyPreset()
    local h,id=ui.previewTarget,ui.previewID
    if not h or not id then return end
    local result,err=B:ApplyPreset(h,id)
    if result then ui.previewID=nil;ui.previewTarget=nil end
    Report(result,err)
    if result and #result.skipped>0 then ui.notice=L["Skipped unavailable:"].." "..table.concat(result.skipped,", ");Refresh() end
end
local function FilterRow(i)
    local row=ui.filterRows[i];if row then return row end
    row=CreateFrame("Frame",nil,ui.filters.content);row:SetHeight(32)
    row.heading=Text(row,"","GameFontNormalSmall")
    row.heading:SetPoint("LEFT",4,0);row.heading:SetPoint("RIGHT",-108,0)
    row.all=Button(row,L["All"],48,function() Act(function() return B:SetCategory(selected,row.category,true) end) end)
    row.all:SetPoint("RIGHT",-52,0)
    row.none=Button(row,L["None"],48,function() Act(function() return B:SetCategory(selected,row.category,false) end) end)
    row.none:SetPoint("RIGHT",0,0)
    row.check=ns.SettingsPanel.Switch(row)
    row.check:SetPoint("RIGHT",-6,0)
    row.label=Text(row);row.label:SetPoint("LEFT",6,0);row.label:SetPoint("RIGHT",row.check,"LEFT",-8,0)
    row.hover=row:CreateTexture(nil,"BACKGROUND")
    row.hover:SetAllPoints()
    ns.SettingsPanel.Rounded(row.hover,0.79,0.65,0.35,0.14)
    row.hover:Hide()
    row:EnableMouse(true)
    local function SetToggle(on)
        if not row.entry or not row.check:IsEnabled() then return end
        ns.ButtonSound()
        Act(function() return B:SetFilter(selected,row.entry.kind,row.entry.key,on) end)
    end
    row.check:SetScript("OnClick",function(self)
        SetToggle(self:GetChecked() and true or false)
    end)
    row:SetScript("OnMouseUp",function(_,button)
        if button=="LeftButton" then SetToggle(not row.check:GetChecked()) end
    end)
    local function Enter()
        if row.entry then row.hover:Show() end
        if GameTooltip and row.category=="channels" then GameTooltip:SetOwner(row,"ANCHOR_RIGHT");GameTooltip:SetText(L["Channel toggles change this window only; they never join or leave channels."],nil,nil,nil,nil,true);GameTooltip:Show() end
        if GameTooltip and row.entry then GameTooltip:SetOwner(row.check,"ANCHOR_RIGHT");GameTooltip:SetText(row.entry.label);GameTooltip:Show() end
    end
    local function Leave() row.hover:Hide();if GameTooltip then GameTooltip:Hide() end end
    row:SetScript("OnEnter",Enter);row:SetScript("OnLeave",Leave)
    row.check:HookScript("OnEnter",Enter);row.check:HookScript("OnLeave",Leave)
    ui.filterRows[i]=row;return row
end
local function RenderFilters(state,enabled)
    local search=ui.search:GetText():lower():match("^%s*(.-)%s*$")
    local count,y=0,0
    local width=math.max(100,ui.filters:GetWidth())
    local cellWidth=(width-10)/2
    if activeCategory=="all" or selectedOnly then ui.category:SetDefaultText(L["All categories"]) end
    for _, category in ipairs(B:Categories()) do
        local matches,total,on={},0,0
        for _, entry in ipairs(category.entries) do
            total=total+1
            local checked=state and (entry.kind=="message" and state.messages[entry.key] or entry.kind=="channel" and state.channels[entry.key])
            if checked then on=on+1 end
            local scope=activeCategory=="all" or selectedOnly or search~="" or category.key==activeCategory
            local matchesSearch=search=="" or category.name:lower():find(search,1,true) or entry.label:lower():find(search,1,true)
            if scope and matchesSearch and (not selectedOnly or checked) then matches[#matches+1]=entry end
        end
        if category.key==activeCategory then ui.category:SetDefaultText(selectedOnly and L["All categories"] or category.name.."  ("..on.."/"..total..")") end
        if #matches>0 or (not selectedOnly and search=="" and category.key==activeCategory) then
            count=count+1;local row=FilterRow(count);row.category=category.key;row.entry=nil
            row.hover:Hide()
            row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-y);row:SetWidth(width)
            row.check:Hide();row.label:Hide();row.heading:Show();row.all:Show();row.none:Show()
            row.heading:SetText(category.name.."  "..on.."/"..total)
            row.all:SetEnabled(enabled and total>0);row.none:SetEnabled(enabled and total>0);row:Show();y=y+34
                for index, entry in ipairs(matches) do
                    count=count+1;row=FilterRow(count);row.entry=entry;row.category=nil;row.hover:Hide()
                    local column=(index-1)%2
                    local line=math.floor((index-1)/2)
                    row:ClearAllPoints();row:SetPoint("TOPLEFT",column*(cellWidth+10),-y-line*32);row:SetWidth(cellWidth)
                    row.heading:Hide();row.all:Hide();row.none:Hide();row.label:Show();row.check:Show()
                    row.label:SetText(entry.label)
                    local checked=state and (entry.kind=="message" and state.messages[entry.key] or entry.kind=="channel" and state.channels[entry.key])
                    row.check:SetChecked(checked and true or false);row.check:SetEnabled(enabled and not entry.disabled)
                    row.label:SetTextColor(entry.disabled and 0.5 or 0.88,entry.disabled and 0.5 or 0.85,entry.disabled and 0.5 or 0.79)
                    row:Show()
                end
            y=y+math.ceil(#matches/2)*32+8
        end
    end
    for i=count+1,#ui.filterRows do ui.filterRows[i]:Hide() end
    ui.filters.content:SetHeight(math.max(y,1))
    ui.filters:SetVerticalScroll(math.min(ui.filters:GetVerticalScroll(),ui.filters:GetVerticalScrollRange()))
    ui.empty:SetText(selectedOnly and L["No selected filters match this view."] or (search=="" and L["No available filters in this category."] or L["No matching filters."]))
    ui.empty:SetShown(count==0 or (search=="" and count==1))
end
local function RenderWindows(windows)
    for i,h in ipairs(windows) do
        local b=ui.windowRows[i]
        if not b then
            b=ns.SettingsPanel.Plate(ui.windows.content)
            b:SetFontString(b.Text);b:SetWidth(148)
            b:SetScript("OnClick",function() ns.ButtonSound();Select(ui.windowRows[i].window.id) end)
            b:SetHeight(48);b:SetPoint("TOPLEFT",0,-(i-1)*54)
            b.Text:ClearAllPoints();b.Text:SetPoint("TOPLEFT",8,-6);b.Text:SetPoint("TOPRIGHT",-8,-6)
            b.detail=Text(b,"","GameFontDisableSmall");b.detail:SetPoint("BOTTOMLEFT",8,3);b.detail:SetWidth(132)
            ui.windowRows[i]=b
        end
        b.window=h;b:SetText(h.name)
        b:SetSelected(not ui.adding and selected and selected.id==h.id)
        b.detail:SetText(h.special and L["Combat Log"] or (h.docked and L["Docked"] or L["Popped out"]))
        b.detail:SetTextColor(not ui.adding and selected and selected.id==h.id and 1 or 0.6,0.65,0.4)
        b:Show()
    end
    for i=#windows+1,#ui.windowRows do ui.windowRows[i]:Hide() end
    ui.windows.content:SetHeight(math.max(1,#windows*54))
    if ui.revealSelected and selected then
        for i,h in ipairs(windows) do if h.id==selected.id then
            ui.windows:SetVerticalScroll(math.min(ui.windows:GetVerticalScrollRange(),(i-1)*54));break
        end end
        ui.revealSelected=nil
    end
end
local function LayoutSets(id)
    local p=B:Preset(id);local messages,channels={},{}
    if not p then return messages,channels end
    local wanted={}
    for _,key in ipairs(p.messages) do wanted[key]=true end
    for _,key in ipairs(p.channels) do wanted[key]=true end
    for _,category in ipairs(B:Categories()) do for _,entry in ipairs(category.entries) do
        if not entry.disabled and wanted[entry.key] then
            local values=entry.kind=="message" and messages or channels;values[entry.key]=true
        end
    end end
    return messages,channels
end
local function Matches(a,b)
    for key in pairs(a) do if not b[key] then return false end end
    for key in pairs(b) do if not a[key] then return false end end
    return true
end
local function CurrentLayout(state)
    if state then for _,p in ipairs(B:Presets()) do
        local messages,channels=LayoutSets(p.id)
        if Matches(state.messages,messages) and Matches(state.channels,channels) then return p.id,p.id=="blank" and L["Empty"] or p.name end
    end end
    return "custom",L["Custom"]
end
local function PreviewLayout(id)
    ui.adding=false
    ui.previewID=id~="custom" and id or nil;ui.previewTarget=ui.previewID and selected or nil
    ui.notice=nil;ui.search:SetText("");activeCategory="all";selectedOnly=false;ui.filters:SetVerticalScroll(0);Refresh()
end
local function LayoutDropdown(parent,onSelect,includeCustom,current)
    local dd=CreateFrame("DropdownButton",nil,parent,"WowStyle1DropdownTemplate");ns.SettingsPanel.SkinDropdown(dd);dd:SetHeight(26)
    local function Choices()
        local out={};if includeCustom then out[1]={id="custom",name=L["Custom"]} end
        for _,p in ipairs(B:Presets()) do out[#out+1]={id=p.id,name=p.id=="blank" and L["Empty"] or p.name} end
        return out
    end
    dd:SetupMenu(function(_,root)
        for _,p in ipairs(Choices()) do root:CreateRadio(p.name,function() return current()==p.id end,function() onSelect(p.id) end) end
    end)
    dd.padCycle=function(delta)
        local choices=Choices();for i,p in ipairs(choices) do if p.id==current() then onSelect(choices[((i-1+delta)%#choices)+1].id);return end end
    end
    return dd
end
function Refresh()
    if not ui or not ui.host:IsShown() then return end
    local windows=B:Windows();local found
    for _,h in ipairs(windows) do if selected and h.id==selected.id and h.generation==selected.generation then found=h end end
    selected=found or windows[1]
    local state=SelectedState();local ok,reason=B:Status();local editable=ok and state and not selected.special and true or false
    if ui.previewTarget and (not selected or selected.id~=ui.previewTarget.id or selected.generation~=ui.previewTarget.generation or selected.name~=ui.previewTarget.name) then ui.previewID=nil;ui.previewTarget=nil end
    if ui.previewID and not B:Preset(ui.previewID) then ui.previewID=nil;ui.previewTarget=nil end
    local shownState=state
    if ui.previewID and state then
        shownState={messages={},channels={}}
        for key,value in pairs(state.messages) do shownState.messages[key]=value end
        for key,value in pairs(state.channels) do shownState.channels[key]=value end
        local messages,channels=LayoutSets(ui.previewID)
        for _,category in ipairs(B:Categories()) do for _,entry in ipairs(category.entries) do if not entry.disabled then
            local values=entry.kind=="message" and shownState.messages or shownState.channels
            local wanted=entry.kind=="message" and messages or channels;values[entry.key]=wanted[entry.key]
        end end end
    end
    if ui.adding then
        local messages,channels=LayoutSets(presetID)
        shownState={messages=messages,channels=channels}
    end
    RenderWindows(windows);RenderFilters(shownState,editable and not ui.previewID and not ui.adding)
    local currentID,currentName=CurrentLayout(state)
    ui.currentLayout=currentID
    local preview=ui.previewID and B:PreviewPreset(ui.previewID)
    ui.layout:SetDefaultText(preview and (ui.previewID=="blank" and L["Empty"] or preview.preset.name) or currentName);ui.layout:SetEnabled(editable and not ui.adding)
    ui.layout:SetShown(not ui.adding);ui.layoutLabel:SetShown(not ui.adding)
    ui.applyLayout:SetShown(preview~=nil);ui.cancelLayout:SetShown(preview~=nil);ui.applyLayout:SetEnabled(editable)
    ui.previewBadge:SetShown(ui.adding or preview~=nil)
    ui.previewBadge.text:SetText(ui.adding and L["New window preview"] or L["Layout preview"])
    ui.addForm:SetShown(ui.adding and true or false)
    ui.addLayout:SetDefaultText(presetID=="blank" and L["Empty"] or B:Preset(presetID).name)
    local draftName=ui.name:GetText():match("^%s*(.-)%s*$")
    ui.title:SetText(ui.adding and (draftName~="" and L["New window: %s"]:format(draftName) or L["New window"]) or (selected and selected.name or L["Select a chat window"]))
    ui.contentTitle:SetText(L["Messages & channels"])
    for _,control in ipairs({ui.rename,ui.close,ui.dock,ui.duplicate}) do control:SetShown(not ui.adding) end
    ui.moveUp:SetEnabled(not ui.adding and selected and B:MoveTarget(selected,-1)~=nil);ui.moveDown:SetEnabled(not ui.adding and selected and B:MoveTarget(selected,1)~=nil)
    ui.rename:SetEnabled(editable);ui.close:SetEnabled(editable and not selected.primary)
    ui.dock:SetEnabled(editable and not selected.primary);ui.dock:SetText(selected and selected.docked and L["Pop out"] or L["Dock"])
    ui.native:SetEnabled(ok and selected~=nil);ui.native:SetShown(not ui.adding and selected and selected.special and true or false)
    local canCreate=ok and FCF_CanOpenNewWindow and FCF_CanOpenNewWindow() and true or false
    ui.new:SetEnabled(canCreate and not ui.adding);ui.duplicate:SetEnabled(editable and canCreate)
    ui.selectedOnly:SetChecked(selectedOnly);ui.category:SetEnabled(not selectedOnly)
    local actionOffset=preview and 38 or 0
    ui.dock:SetPoint("TOPLEFT",0,-174-actionOffset)
    ui.duplicate:SetPoint("TOPLEFT",0,-206-actionOffset)
    ui.close:SetPoint("TOPLEFT",0,-238-actionOffset)
    local status=reason or ""
    if ok and selected and selected.special then status=L["Combat Log uses its own filters. Open Blizzard Settings to edit them."] end
    if ok and ns.Tweaks and ns.db.profile.tweaks and ns.db.profile.tweaks.syncUI and ns.Tweaks.GetSyncSourceLabel then
        local source=ns.Tweaks:GetSyncSourceLabel()
        if source and not ns.Tweaks:IsSyncSource() then status=status.."\n"..L["Blizzard settings sync is enabled. Future changes from %s may replace this character's chat settings."]:format(source) end
    end
    if preview then
        if #preview.skipped>0 then status=status.."\n"..L["Skipped unavailable:"].." "..table.concat(preview.skipped,", ") end
    end
    if ui.adding then
        status=reason or ""
        local draft=B:PreviewPreset(presetID)
        if draft and #draft.skipped>0 then status=status.."\n"..L["Skipped unavailable:"].." "..table.concat(draft.skipped,", ") end
    end
    local notice=(ui.notice or status):gsub("^%s+", "")
    ui.noticeScroll:SetPoint("TOPLEFT",0,ui.adding and -310 or (preview and -316 or (selected and selected.special and -310 or -278)))
    if ui.lastNotice~=notice then ui.noticeScroll:SetVerticalScroll(0);ui.lastNotice=notice end
    ui.noticeScroll:SetShown(notice~="")
    ui.status:SetText(notice);ui.status:SetHeight(ui.status:GetStringHeight())
    ui.noticeScroll.content:SetHeight(ui.status:GetStringHeight()+4)
    ui.noticeScroll:SetVerticalScroll(math.min(ui.noticeScroll:GetVerticalScroll(),ui.noticeScroll:GetVerticalScrollRange()))
    ui.create:SetEnabled(canCreate)
end
function Editor.Build(host,side)
    ui={host=host,windowRows={},filterRows={}}
    local editor=CreateFrame("Frame",nil,host);editor:SetAllPoints();ui.editor=editor
    local title=Text(editor,L["Your chat windows"],"GameFontNormal");title:SetPoint("TOPLEFT",0,0)
    ui.new=Button(editor,L["Add window"],148,function() ui.adding=true;activeCategory="all";selectedOnly=false;ui.search:SetText("");ui.filters:SetVerticalScroll(0);ui.previewID=nil;ui.previewTarget=nil;presetID="general";ui.suggestedName=B:Preset(presetID).name;ui.name:SetText(ui.suggestedName);ui.notice=nil;Refresh() end);ui.new:SetPoint("TOPLEFT",0,-26)
    ui.windows=Scroll(editor);ui.windows:SetPoint("TOPLEFT",0,-62);ui.windows:SetPoint("BOTTOMLEFT",0,34);ui.windows:SetWidth(148)
    ui.moveUp=Button(editor,L["Move up"],71,function() Act(function() return B:Move(selected,-1) end) end);ui.moveUp:SetPoint("BOTTOMLEFT",0,0)
    ui.moveDown=Button(editor,L["Move down"],71,function() Act(function() return B:Move(selected,1) end) end);ui.moveDown:SetPoint("LEFT",ui.moveUp,"RIGHT",6,0)
    Tip(ui.moveUp,L["Move this docked tab left. General and Combat Log keep their positions."])
    Tip(ui.moveDown,L["Move this docked tab right. Pop-out windows are positioned by dragging them."])
    -- Three columns share one selection: windows, filters, and window controls.
    local body=CreateFrame("Frame",nil,editor);body:SetPoint("TOPRIGHT",0,0);body:SetPoint("BOTTOMRIGHT",0,0);body:SetWidth(216)
    local settingsTitle=Text(body,L["Window settings"],"GameFontNormal");settingsTitle:SetPoint("TOPLEFT",0,0)
    ui.title=Text(body,"","GameFontNormalLarge");ui.title:SetPoint("TOPLEFT",0,-24);ui.title:SetPoint("TOPRIGHT",0,-24);ui.title:SetHeight(36)
    ui.rename=Button(body,L["Rename"],216,Rename);ui.rename:SetPoint("TOPLEFT",0,-66)
    ui.dock=Button(body,L["Pop out"],216,function() local h=selected;Act(function() return B:SetDocked(h,not h.docked) end) end);ui.dock:SetPoint("TOPLEFT",0,-174)
    ui.duplicate=Button(body,L["Duplicate"],216,DuplicateWindow);ui.duplicate:SetPoint("TOPLEFT",0,-206)
    ui.close=Button(body,L["Delete window"],216,function()
        local h=selected;if h then Confirm(L["Delete %s? Its chat-window configuration will be removed."]:format(h.name),function() ui.previewID=nil;Act(function() return B:Close(h) end) end) end
    end);ui.close:SetPoint("TOPLEFT",0,-238)
    local layoutLabel=Text(body,L["Starting layout"],"GameFontNormal");ui.layoutLabel=layoutLabel;layoutLabel:SetPoint("TOPLEFT",0,-104)
    ui.layout=LayoutDropdown(body,PreviewLayout,true,function() return ui.previewID or ui.currentLayout or "custom" end)
    ui.layout:SetWidth(216);ui.layout:SetPoint("TOPLEFT",0,-126)
    ui.applyLayout=Button(body,L["Apply layout"],110,ApplyPreset);ui.applyLayout:SetPoint("TOPLEFT",0,-164)
    ui.cancelLayout=Button(body,L["Cancel"],100,function() ui.previewID=nil;ui.previewTarget=nil;ui.notice=nil;Refresh() end);ui.cancelLayout:SetPoint("LEFT",ui.applyLayout,"RIGHT",6,0)
    local add=CreateFrame("Frame",nil,body,"BackdropTemplate");ui.addForm=add;add:SetPoint("TOPLEFT",0,-66);add:SetPoint("TOPRIGHT",0,-66);add:SetHeight(232);add:Hide()
    local nameLabel=Text(add,L["Window name"],"GameFontNormal");nameLabel:SetPoint("TOPLEFT",0,0)
    ui.name=CreateFrame("EditBox",nil,add,"InputBoxTemplate");ui.name:SetAutoFocus(false);ui.name:SetMaxLetters(31);ui.name:SetFontObject(ns.SettingsPanel.FONT.GameFontHighlight)
    ui.name:SetHeight(24);ui.name:SetPoint("TOPLEFT",6,-24);ui.name:SetPoint("TOPRIGHT",0,-24)
    ui.name:HookScript("OnTextChanged",function() if ui.status and ui.adding then Refresh() end end)
    ui.editName=Button(add,L["Edit name"],86,function() AskName(L["Window name"],ui.name:GetText(),function(name) ui.name:SetText(name or "") end) end);ui.editName:SetPoint("TOPRIGHT",0,-54)
    local addLabel=Text(add,L["Starting layout"],"GameFontNormal");addLabel:SetPoint("TOPLEFT",0,-94)
    ui.addLayout=LayoutDropdown(add,function(id)
        presetID=id
        if ui.name:GetText()=="" or ui.name:GetText()==ui.suggestedName then ui.suggestedName=id=="blank" and L["New window"] or B:Preset(id).name;ui.name:SetText(ui.suggestedName) end
        Refresh()
    end,false,function() return presetID end);ui.addLayout:SetWidth(216);ui.addLayout:SetPoint("TOPLEFT",0,-116)
    ui.create=Button(add,L["Create window"],216,function()
        local h,result=B:Create(ui.name:GetText(),presetID)
        if not h then Report(nil,result);return end
        selected=h;ui.adding=false;ui.revealSelected=true;ui.notice=L["Window created. Filters are active."]
        if #result.skipped>0 then ui.notice=ui.notice.."\n"..L["Skipped unavailable:"].." "..table.concat(result.skipped,", ") end
        ui.name:ClearFocus();Refresh()
    end);ui.create:SetPoint("TOPLEFT",0,-156)
    local function CancelAdd() ui.adding=false;ui.name:ClearFocus();Refresh() end
    local cancel=Button(add,L["Cancel"],216,CancelAdd);cancel:SetPoint("TOPLEFT",0,-188);ui.name:SetScript("OnEscapePressed",CancelAdd)
    Tip(ui.create,L["Creates a new window. Your existing windows stay unchanged."])
    Tip(ui.applyLayout,L["Replace this window's supported filters with the previewed layout."])
    local filtersArea=CreateFrame("Frame",nil,editor);ui.filtersArea=filtersArea
    filtersArea:SetPoint("TOPLEFT",172,0);filtersArea:SetPoint("BOTTOMRIGHT",body,"BOTTOMLEFT",-24,0)
    ui.native=Button(body,L["Open Blizzard Settings"],216,function() Act(function() return B:OpenBlizzard(selected) end) end);ui.native:SetPoint("TOPLEFT",0,-272)
    local contentTitle=Text(filtersArea,L["What appears here"],"GameFontNormal");ui.contentTitle=contentTitle;contentTitle:SetPoint("TOPLEFT",0,0)
    ui.previewBadge=CreateFrame("Frame",nil,filtersArea);ui.previewBadge:SetSize(150,20);ui.previewBadge:SetPoint("TOPRIGHT",0,0);ui.previewBadge:EnableMouse(true)
    ui.previewBadge.text=Text(ui.previewBadge,"","GameFontNormalSmall");ui.previewBadge.text:SetAllPoints();ui.previewBadge.text:SetJustifyH("RIGHT")
    ui.previewBadge:SetScript("OnEnter",function(self)
        if GameTooltip then
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            GameTooltip:SetText(ui.adding and L["Preview only. Create window to add this chat window; existing windows are unchanged."] or L["Preview only. Apply layout to replace this window's filters, or Cancel."],nil,nil,nil,nil,true);GameTooltip:Show()
        end
    end)
    ui.previewBadge:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    ui.search=CreateFrame("EditBox",nil,filtersArea,"SearchBoxTemplate");ui.search:SetAutoFocus(false);ui.search:SetMaxLetters(80);ui.search:SetFontObject(ns.SettingsPanel.FONT.GameFontHighlight)
    if ui.search.Instructions then ui.search.Instructions:SetText(L["Find a message or channel"]) end
    ui.search:SetSize(200,24);ui.search:SetPoint("TOPLEFT",6,-26);ui.search:SetPoint("TOPRIGHT",-98,-26)
    ui.search:SetScript("OnEscapePressed",function(self) self:ClearFocus() end);ui.search:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
    ui.search:HookScript("OnTextChanged",function() if ui.filters then Refresh() end end)
    ui.searchButton=Button(filtersArea,L["Search"],90,function() AskName(L["Search chat filters (leave blank to show all)"],ui.search:GetText(),function(text) ui.search:SetText(text or "") end) end);ui.searchButton:SetPoint("TOPRIGHT",0,-26)
    ui.category=CreateFrame("DropdownButton",nil,filtersArea,"WowStyle1DropdownTemplate");ns.SettingsPanel.SkinDropdown(ui.category)
    ui.category:SetHeight(26);ui.category:SetPoint("TOPLEFT",0,-58);ui.category:SetPoint("TOPRIGHT",-142,-58)
    local selectedRow=CreateFrame("Frame",nil,filtersArea);selectedRow:SetSize(134,26);selectedRow:SetPoint("TOPRIGHT",0,-58);selectedRow:EnableMouse(true)
    ui.selectedOnly=ns.SettingsPanel.Switch(selectedRow);ui.selectedOnly:SetPoint("RIGHT",0,0)
    local selectedLabel=Text(selectedRow,L["Selected only"]);selectedLabel:SetPoint("LEFT",0,0);selectedLabel:SetPoint("RIGHT",ui.selectedOnly,"LEFT",-6,0)
    local function SetSelectedOnly(on) selectedOnly=on;ui.filters:SetVerticalScroll(0);ns.ButtonSound();Refresh() end
    ui.selectedOnly:SetScript("OnClick",function(self) SetSelectedOnly(self:GetChecked() and true or false) end)
    selectedRow:SetScript("OnMouseUp",function(_,button) if button=="LeftButton" then SetSelectedOnly(not selectedOnly) end end)
    ui.category:SetupMenu(function(_,root)
        local function Choice(key,name) root:CreateRadio(name,function() return activeCategory==key end,function() activeCategory=key;ui.filters:SetVerticalScroll(0);ui.search:SetText("");Refresh() end) end
        Choice("all",L["All categories"]);for _,cat in ipairs(B:Categories()) do Choice(cat.key,cat.name) end
    end)
    ui.category.padCycle=function(delta)
        if selectedOnly then return end
        local keys={"all"};for _,cat in ipairs(B:Categories()) do keys[#keys+1]=cat.key end
        for i,key in ipairs(keys) do if key==activeCategory then activeCategory=keys[((i-1+delta)%#keys)+1];ui.search:SetText("");Refresh();break end end
    end
    ui.filters=Scroll(filtersArea);ui.filters:SetPoint("TOPLEFT",0,-94);ui.filters:SetPoint("BOTTOMRIGHT",-16,0)
    ui.filters:HookScript("OnSizeChanged",function() if ui.empty then Refresh() end end)
    ui.empty=Text(filtersArea);ui.empty:SetPoint("TOPLEFT",8,-132);ui.empty:SetPoint("TOPRIGHT",-24,-132)
    ui.noticeScroll=Scroll(body);ui.noticeScroll:SetPoint("TOPLEFT",0,-278);ui.noticeScroll:SetPoint("BOTTOMRIGHT",-10,0)
    ui.status=Text(ui.noticeScroll.content,"","GameFontHighlightSmall");ui.status:SetPoint("TOPLEFT",0,0);ui.status:SetPoint("TOPRIGHT",0,0);ui.status:SetJustifyV("TOP")
    host:SetScript("OnShow",function() B:Watch(Refresh);Refresh() end)
    host:SetScript("OnHide",function() B:Unwatch(Refresh);ui.search:ClearFocus();ui.name:ClearFocus();ui.adding=false;ui.previewID=nil;ui.previewTarget=nil end)
    B:Watch(Refresh)
end
Editor.Refresh=function() Refresh() end
