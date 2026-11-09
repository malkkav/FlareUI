local _, ns = ...

--------------------------------------------------
-- FLAREUI EDIT MODE LAYOUT
-- The layout code exported from Edit Mode (Layout menu > Share > Copy to Clipboard). Players import
-- it themselves in Blizzard's own dialog: an addon that imports or switches layouts taints the
-- bars, and C_EditMode.SaveLayouts from addon code crashes the client. Offered on the About page
-- and in the setup tour.
--------------------------------------------------
local Layout = {
    -- Exported on 4K (2133 x 1200 UI units, Use UI Scale off), then re-anchored so each frame hangs
    -- off its nearest screen edge or the centre (layout_convert.js): it lands in the same place on
    -- 4K and keeps its shape on other screen sizes. Empty greys out the Copy buttons.
    code = [[5 0 59 0 0 0 0 7 UIParent -189.5 84.0 -1 ##$$%,&''%)$+$,$ 0 1 0 0 7 UIParent -189.5 41.5 -1 ##$$%,&''%(#,$ 0 2 0 0 7 UIParent -163.8 116.5 -1 ##$$%-&%'%(#,$ 0 3 0 1 4 UIParent 0.0 -2.0 -1 ##$$%/&('%(#,$ 0 4 0 0 7 UIParent -281.0 549.0 -1 ##$$%/&('%(#,$ 0 5 0 0 7 UIParent -281.0 500.0 -1 ##$$%/&('%(#,$ 0 6 0 0 7 UIParent -281.0 451.0 -1 ##$$%/&('%(#,$ 0 7 0 0 7 UIParent -281.0 402.0 -1 ##$$%/&('%(#,$ 0 10 0 0 7 UIParent -162.8 145.5 -1 ##$$&&'% 0 11 0 0 7 UIParent -532.0 64.0 -1 ##$%&('%,# 0 12 0 0 7 UIParent -186.8 130.4 -1 #$$$&%'% 1 -1 0 7 7 UIParent 0.0 361.0 -1 #($#%# 2 -1 0 0 2 UIParent -256.0 1.0 -1 ##$#%(&( 3 0 0 0 7 UIParent -452.0 380.0 -1 $#3# 3 1 0 0 7 UIParent 220.0 380.0 -1 %$3# 3 2 0 0 7 UIParent 428.0 369.7 -1 %$&#3# 3 3 0 0 3 UIParent 0.0 170.3 -1 '$(#)#-k.-/$1#3)5#6'7-7$8'9' 3 4 0 0 0 UIParent 4.0 0.0 -1 ,%-5.//$0$1#2(3#5#6'7U8'9' 3 5 0 2 2 UIParent -42.1 -447.5 -1 &$*$3# 3 6 1 5 5 UIParent 0.0 0.0 -1 -=.+/#4$5#6(7-7$8(9( 3 7 1 4 4 UIParent 0.0 0.0 -1 3# 4 -1 0 7 7 UIParent 0.0 152.0 -1 # 5 -1 0 0 7 UIParent -125.0 267.0 -1 # 6 0 0 0 2 UIParent -546.0 -4.0 -1 ##$#%#&-(&)( 6 1 0 0 2 UIParent -547.0 -178.0 -1 ##$$%#'-(&)(-$ 6 2 1 1 1 UIParent 0.0 -25.0 -1 ##$#%$&.(()(+#,-,$ 7 -1 1 7 7 UIParent 0.0 -4.0 -1 # 8 -1 0 0 6 UIParent 12.2 177.0 -1 #'$H%$&d 9 -1 0 0 2 UIParent -42.0 -213.4 -1 # 10 -1 1 0 0 UIParent 16.0 -116.0 -1 # 11 -1 0 7 7 UIParent 473.0 2.0 -1 # 12 -1 0 0 2 UIParent -241.0 -260.9 -1 #A$#%# 13 -1 0 0 0 UIParent 5.7 -6.0 -1 ##$#%% 14 -1 0 0 0 UIParent 4.1 -43.0 -1 ##$#%# 15 0 0 0 1 UIParent -298.0 -4.0 -1 &# 15 1 0 0 6 MainStatusTrackingBarContainer 0.0 -4.0 -1 &# 16 -1 0 0 7 UIParent -336.0 59.2 -1 #$ 17 -1 0 0 1 UIParent -103.0 -37.0 -1 ## 18 -1 1 5 5 UIParent 0.0 0.0 -1 #- 19 -1 1 7 7 UIParent 0.0 0.0 -1 ## 20 0 1 7 7 UIParent 0.0 310.0 -1 ##$/%$&('%(-($)#+$,$-$ 20 1 1 7 7 UIParent 0.0 240.0 -1 ##$*%$&('%(-($)#+$,$-$ 20 2 1 7 7 UIParent 0.0 370.0 -1 ##$$%$&('((-($)#+$,$-$ 20 3 1 7 7 UIParent 420.0 430.0 -1 #$$$%#&('((-($)#*#+$,$-$.-.$ 21 -1 0 4 4 UIParent 0.0 -270.0 -1 #$%$&#'&(&)#*-*$+%,&-#.#/-0#1# 22 0 1 8 7 UIParent -457.0 336.0 -1 #$$$%#&('((#)U*$+%,$-#.#/U0% 22 1 1 1 1 UIParent 0.0 -40.0 -1 &('()U*#+% 22 2 1 1 1 UIParent 0.0 -90.0 -1 &('()U*#+% 22 3 1 1 1 UIParent 0.0 -130.0 -1 &('()U*#+% 23 -1 0 0 8 UIParent -457.0 209.0 -1 #$$%%$&l&%'x($)U+$,$-3.(/# 24 -1 0 4 4 UIParent 0.0 280.0 -1 # 25 -1 0 0 7 UIParent -562.5 37.0 -1 # 26 0 0 7 7 UIParent -258.4 -2.0 -1 ## 26 1 0 7 7 UIParent 257.8 -2.0 -1 ## 27 -1 0 0 2 UIParent -252.0 -220.4 -1 #) 28 -1 1 4 4 UIParent 0.0 0.0 -1 #( 29 0 0 0 7 UIParent -161.5 353.0 -1 #($U%$&7&$'*(#)$ 29 1 0 0 7 UIParent -161.5 331.0 -1 #($U%$&7&$'*(#)$ 29 2 0 0 7 UIParent -161.5 353.0 -1 #($U%$&7&$'*(#)$]],
}
ns.EditModeLayout = Layout

function Layout.Has()
    return strtrim(Layout.code) ~= ""
end

-- the copy box (Chat.lua), all selected for Ctrl+C
function Layout.Copy()
    if not Layout.Has() then return end
    if ns.Chat and ns.Chat.ShowCopyText then ns.Chat.ShowCopyText(strtrim(Layout.code)) end
end

-- a Copy Layout Code button; greyed with a tooltip while there is no code yet
function Layout.Button(parent, width)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 160, 24)
    b:SetText(ns.L["Copy Layout Code"])
    b:SetMotionScriptsWhileDisabled(true)
    b:SetScript("OnClick", function()
        ns.ButtonSound()
        Layout.Copy()
    end)
    b:SetScript("OnShow", function(self) self:SetEnabled(Layout.Has()) end)
    b:SetScript("OnEnter", function(self)
        if Layout.Has() then return end
        ns.OwnGameTooltip(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.L["Coming soon"], 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetEnabled(Layout.Has())
    return b
end
