local _, ns = ...
local L, B = ns.L, ns.ChatBuilder
local Editor = {}
ns.ChatBuilderEditor = Editor
local ui, selected, presetID = nil, nil, "general"
local activeCategory = "conversations"
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
    s:SetScript("OnSizeChanged",function(self,w) content:SetWidth(math.max(40,w)) end)
    return s
end
local function SelectedState()
    if not selected then return nil end
    return B:Read(selected)
end
local function NewWindow(id)
    local p=B:Preset(id)
    if not p then return end
    AskName(L["Create a chat window from the selected preset"],p.name,function(name)
        local h,result=B:Create(name,id)
        if h then selected=h;ui.notice=L["Window created. Filters are active."]
            if #result.skipped>0 then ui.notice=ui.notice.."\n"..L["Skipped unavailable:"].." "..table.concat(result.skipped,", ") end
            Refresh()
        else Report(nil,result) end
    end)
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
    local h,id=selected,presetID;local preview=B:PreviewPreset(id)
    if not h or not preview then return end
    local message=L["Replace the supported content filters in %s? Its name, position, and docking will stay the same."]:format(h.name)
    if #preview.skipped>0 then message=message.."\n\n"..L["Skipped unavailable:"].." "..table.concat(preview.skipped,", ") end
    Confirm(message,function()
        local result,err=B:ApplyPreset(h,id)
        Report(result,err)
        if result and #result.skipped>0 then ui.notice=L["Skipped unavailable:"].." "..table.concat(result.skipped,", ");Refresh() end
    end)
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
    for _, category in ipairs(B:Categories()) do
        local matches,total,on={},0,0
        for _, entry in ipairs(category.entries) do
            total=total+1
            local checked=state and (entry.kind=="message" and state.messages[entry.key] or entry.kind=="channel" and state.channels[entry.key])
            if checked then on=on+1 end
            local scope=selectedOnly or search~="" or category.key==activeCategory
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
        b:SetSelected(selected and selected.id==h.id)
        b.detail:SetText(h.special and L["Combat Log"] or (h.docked and L["Docked"] or L["Popped out"]))
        b.detail:SetTextColor(selected and selected.id==h.id and 1 or 0.6,0.65,0.4)
        b:Show()
    end
    for i=#windows+1,#ui.windowRows do ui.windowRows[i]:Hide() end
    ui.windows.content:SetHeight(math.max(1,#windows*54))
end
local function PresetSummary()
    local preview=B:PreviewPreset(presetID)
    if not preview then presetID="general";preview=B:PreviewPreset(presetID) end
    ui.preset:SetDefaultText(preview.preset.name)
    local lines={preview.preset.builtin and L["Built-in preset · editable after loading"] or L["Saved preset · shared across your characters"],"",L["Included:"]}
    lines[#lines+1]=#preview.included>0 and table.concat(preview.included,"\n") or L["No supported content selected."]
    if #preview.skipped>0 then lines[#lines+1]="\n"..L["Skipped unavailable:"];lines[#lines+1]=table.concat(preview.skipped,"\n") end
    ui.summary:SetText(table.concat(lines,"\n"))
    ui.summary:SetHeight(ui.summary:GetStringHeight())
    ui.presetScroll.content:SetHeight(ui.summary:GetStringHeight()+12)
    return preview.preset
end
function Refresh()
    if not ui or not ui.host:IsShown() then return end
    local windows=B:Windows()
    local found
    for _,h in ipairs(windows) do if selected and h.id==selected.id and h.generation==selected.generation then found=h end end
    selected=found or windows[1]
    local state=SelectedState()
    local ok,reason=B:Status();local editable=ok and state and not selected.special and true or false
    RenderWindows(windows);RenderFilters(state,editable)
    ui.title:SetText(selected and L["Editing: %s"]:format(selected.name) or L["Select a chat window"])
    ui.rename:SetEnabled(editable);ui.close:SetEnabled(editable and not selected.primary)
    ui.dock:SetEnabled(editable and not selected.primary)
    ui.dock:SetText(selected and selected.docked and L["Pop out"] or L["Dock"])
    ui.native:SetEnabled(ok and selected~=nil)
    local preset=PresetSummary()
    ui.apply:SetEnabled(editable);ui.save:SetEnabled(editable)
    ui.new:SetEnabled(ok and FCF_CanOpenNewWindow and FCF_CanOpenNewWindow() and true or false)
    ui.createPreset:SetEnabled(ui.new:IsEnabled())
    ui.duplicate:SetEnabled(editable and ui.new:IsEnabled())
    ui.renamePreset:SetEnabled(ok and not preset.builtin);ui.deletePreset:SetEnabled(ok and not preset.builtin)
    ui.preset:SetEnabled(ok and true or false)
    ui.selectedOnly:SetChecked(selectedOnly)
    ui.category:SetEnabled(not selectedOnly)
    local status=reason or L["Changes apply immediately."]
    if ok and selected and selected.special then status=L["Combat Log uses its own filters. Open Blizzard Settings to edit them."] end
    if ok and ns.Tweaks and ns.db.profile.tweaks and ns.db.profile.tweaks.syncUI and ns.Tweaks.GetSyncSourceLabel then
        local source=ns.Tweaks:GetSyncSourceLabel()
        if source and not ns.Tweaks:IsSyncSource() then status=status.."\n"..L["Blizzard settings sync is enabled. Future changes from %s may replace this character's chat settings."]:format(source) end
    end
    ui.status:SetText(status)
    ui.feedback:SetText(ui.notice or "")
end
function Editor.Build(host,side)
    -- The settings framework reuses the side host for other custom tabs.
    local column=CreateFrame("Frame",nil,side)
    column:SetAllPoints()
    side=column
    ui={host=host,side=side,windowRows={},filterRows={}}
    local title=Text(host,L["Chat windows"],"GameFontNormal");title:SetPoint("TOPLEFT",0,0)
    ui.new=Button(host,L["New window"],148,function() NewWindow("blank") end);ui.new:SetPoint("TOPLEFT",0,-26)
    ui.windows=Scroll(host);ui.windows:SetPoint("TOPLEFT",0,-62);ui.windows:SetPoint("BOTTOMLEFT",0,128);ui.windows:SetWidth(148)
    local help=Text(host,L["New window starts empty.\n\nUse Create from preset for a ready-made tab, or Duplicate to copy the window you are editing."])
    help:SetPoint("BOTTOMLEFT",0,8);help:SetSize(150,112)
    local body=CreateFrame("Frame",nil,host);body:SetPoint("TOPLEFT",180,0);body:SetPoint("BOTTOMRIGHT",0,0)
    ui.title=Text(body,"","GameFontNormalLarge");ui.title:SetPoint("TOPLEFT",0,0);ui.title:SetPoint("TOPRIGHT",0,0)
    ui.rename=Button(body,L["Rename"],82,Rename);ui.rename:SetPoint("TOPLEFT",0,-28)
    ui.duplicate=Button(body,L["Duplicate"],86,DuplicateWindow);ui.duplicate:SetPoint("LEFT",ui.rename,"RIGHT",6,0)
    ui.dock=Button(body,L["Pop out"],82,function() local h=selected;Act(function() return B:SetDocked(h,not h.docked) end) end);ui.dock:SetPoint("LEFT",ui.duplicate,"RIGHT",6,0)
    ui.close=Button(body,L["Close window"],110,function()
        local h=selected;if h then Confirm(L["Close %s? Its chat-window configuration will be removed."]:format(h.name),function() Act(function() return B:Close(h) end) end) end
    end);ui.close:SetPoint("LEFT",ui.dock,"RIGHT",6,0)
    ui.search=CreateFrame("EditBox",nil,body,"SearchBoxTemplate");ui.search:SetAutoFocus(false);ui.search:SetMaxLetters(80)
    ui.search:SetFontObject(ns.SettingsPanel.FONT.GameFontHighlight)
    if ui.search.Instructions then ui.search.Instructions:SetText(L["Search chat filters"]) end
    ui.search:SetSize(200,24);ui.search:SetPoint("TOPLEFT",6,-62);ui.search:SetPoint("TOPRIGHT",-98,-62)
    ui.search:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    ui.search:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
    ui.search:HookScript("OnTextChanged",function() if ui and ui.filters then Refresh() end end)
    ui.searchButton=Button(body,L["Search"],90,function()
        AskName(L["Search chat filters (leave blank to show all)"],ui.search:GetText(),function(text) ui.search:SetText(text or "") end)
    end);ui.searchButton:SetPoint("TOPRIGHT",0,-62)
    ui.category=CreateFrame("DropdownButton",nil,body,"WowStyle1DropdownTemplate")
    ns.SettingsPanel.SkinDropdown(ui.category)
    ui.category:SetHeight(26);ui.category:SetPoint("TOPLEFT",0,-96);ui.category:SetPoint("TOPRIGHT",-142,-96)
    local selectedRow=CreateFrame("Frame",nil,body)
    selectedRow:SetSize(134,26);selectedRow:SetPoint("TOPRIGHT",0,-96);selectedRow:EnableMouse(true)
    ui.selectedOnly=ns.SettingsPanel.Switch(selectedRow);ui.selectedOnly:SetPoint("RIGHT",0,0)
    local selectedLabel=Text(selectedRow,L["Selected only"])
    selectedLabel:SetPoint("LEFT",0,0);selectedLabel:SetPoint("RIGHT",ui.selectedOnly,"LEFT",-6,0)
    local function SetSelectedOnly(on)
        selectedOnly=on;ui.filters:SetVerticalScroll(0);ns.ButtonSound();Refresh()
    end
    ui.selectedOnly:SetScript("OnClick",function(self) SetSelectedOnly(self:GetChecked() and true or false) end)
    selectedRow:SetScript("OnMouseUp",function(_,button) if button=="LeftButton" then SetSelectedOnly(not selectedOnly) end end)
    ui.category:SetupMenu(function(_,root)
        local state=SelectedState()
        for _,category in ipairs(B:Categories()) do
            local on=0
            for _,entry in ipairs(category.entries) do
                local values=state and (entry.kind=="message" and state.messages or state.channels)
                if values and values[entry.key] then on=on+1 end
            end
            root:CreateRadio(category.name.."  ("..on.."/"..#category.entries..")",function() return activeCategory==category.key end,function()
                activeCategory=category.key;ui.filters:SetVerticalScroll(0);ui.search:SetText("");Refresh()
            end)
        end
    end)
    ui.category.padCycle=function(delta)
        if selectedOnly then return end
        local categories=B:Categories()
        for i,category in ipairs(categories) do if category.key==activeCategory then
            activeCategory=categories[((i-1+delta)%#categories)+1].key
            ui.filters:SetVerticalScroll(0);ui.search:SetText("");Refresh();break
        end end
    end
    ui.filters=Scroll(body);ui.filters:SetPoint("TOPLEFT",0,-132);ui.filters:SetPoint("BOTTOMRIGHT",-22,70)
    ui.filters.content:SetWidth(380)
    ui.filters:HookScript("OnSizeChanged",function() if ui.empty then Refresh() end end)
    ui.empty=Text(body,L["No matching filters."]);ui.empty:SetPoint("TOPLEFT",8,-180);ui.empty:SetPoint("TOPRIGHT",-24,-180)
    ui.status=Text(body);ui.status:SetPoint("BOTTOMLEFT",0,10);ui.status:SetPoint("BOTTOMRIGHT",0,10);ui.status:SetHeight(50)

    local heading=Text(side,L["Presets"],"GameFontNormalLarge");heading:SetPoint("TOPLEFT",4,-4)
    ui.preset=CreateFrame("DropdownButton",nil,side,"WowStyle1DropdownTemplate");ui.preset:SetSize(242,26);ui.preset:SetPoint("TOPLEFT",4,-30)
    ns.SettingsPanel.SkinDropdown(ui.preset)
    ui.preset:SetupMenu(function(_,root)
        for _,p in ipairs(B:Presets()) do root:CreateRadio(p.name,function() return presetID==p.id end,function() presetID=p.id;ui.notice=nil;Refresh() end) end
    end)
    ui.preset.padCycle=function(delta)
        local presets=B:Presets();for i,p in ipairs(presets) do if p.id==presetID then presetID=presets[((i-1+delta)%#presets)+1].id;Refresh();break end end
    end
    ui.presetScroll=Scroll(side);ui.presetScroll:SetPoint("TOPLEFT",6,-68);ui.presetScroll:SetPoint("BOTTOMRIGHT",-24,220)
    ui.summary=Text(ui.presetScroll.content);ui.summary:SetPoint("TOPLEFT",0,0);ui.summary:SetPoint("TOPRIGHT",-4,0)
    ui.presetScroll.content:SetWidth(220)
    ui.createPreset=Button(side,L["Create from preset"],242,function() NewWindow(presetID) end);ui.createPreset:SetPoint("BOTTOMLEFT",4,184)
    ui.apply=Button(side,L["Replace window filters"],242,ApplyPreset);ui.apply:SetPoint("BOTTOMLEFT",4,154)
    ui.save=Button(side,L["Save preset"],242,function()
        local h=selected;if h then AskName(L["Save these filters as a new preset"],h.name,function(name)
            local p,err=B:SavePreset(h,name);if p then presetID=p.id end;Report(p,err)
        end) end
    end);ui.save:SetPoint("BOTTOMLEFT",4,124)
    ui.renamePreset=Button(side,L["Rename preset"],118,function()
        local id=presetID;local p=B:Preset(id);if p then AskName(L["Rename saved preset"],p.name,function(name) Act(function() return B:RenamePreset(id,name) end) end) end
    end);ui.renamePreset:SetPoint("BOTTOMLEFT",4,94)
    ui.deletePreset=Button(side,L["Delete preset"],118,function()
        local id=presetID;local p=B:Preset(id);if p then Confirm(L["Delete preset %s? Existing chat windows will not change."]:format(p.name),function() Act(function() return B:DeletePreset(id) end) end) end
    end);ui.deletePreset:SetPoint("LEFT",ui.renamePreset,"RIGHT",6,0)
    ui.feedback=Text(side);ui.feedback:SetPoint("BOTTOMLEFT",6,64);ui.feedback:SetWidth(240);ui.feedback:SetHeight(24)
    ui.native=Button(side,L["Open Blizzard Settings"],242,function() Act(function() return B:OpenBlizzard(selected) end) end);ui.native:SetPoint("BOTTOMLEFT",4,38)
    local channelHelp=Text(side,L["Channel toggles change this window only; they never join or leave channels."])
    channelHelp:SetPoint("BOTTOMLEFT",6,0);channelHelp:SetSize(240,32)
    host:SetScript("OnShow",function() side:Show();B:Watch(Refresh);Refresh() end)
    host:SetScript("OnHide",function() side:Hide();B:Unwatch(Refresh);ui.search:ClearFocus() end)
    B:Watch(Refresh)
end
Editor.Refresh=function() Refresh() end
