local _, ns = ...
local L = ns.L
local S = ns.Settings

--------------------------------------------------
-- UNIT FRAMES
-- One switch + Edit row per frame (unit, party, raid, boss); frames are made at login, so switching
-- asks for a reload. Look options apply to every frame; the rest is in Edit Mode.
--------------------------------------------------
-- UnitFrames:Refresh also refreshes party, raid, boss and resource bars
local function Refresh()
    if ns.UnitFrames and ns.UnitFrames.Refresh then ns.UnitFrames:Refresh() end
end

local function Frame(key, path, frameName)
    S:Row{
        key = "uf." .. key, kind = "frame", reload = true, path = path, half = true,
        frame = function() return _G[frameName] end,
    }
end

S:Module{
    key = "uf", group = "combat", order = 20, enabled = "unitframes.enabled",
    tabs = { { key = "settings" }, { key = "fonts" } },
    -- the frames behind the shared Player / Pet / Target / Focus row
    editFrames = {
        function() return _G.FlareUI_UF_Player end, function() return _G.FlareUI_UF_Target end,
        function() return _G.FlareUI_UF_Focus end, function() return _G.FlareUI_UF_Pet end,
        -- frames of their own with no row here
        function() return _G.FlareUI_RaidTanks end,
        function() return _G.FlareUI_Totems end,
    },
    -- the header button opens Edit Mode on the first frame that exists
    editMode = function()
        for _, name in ipairs({ "FlareUI_UF_Player", "FlareUI_UF_Target", "FlareUI_UF_Focus", "FlareUI_Party", "FlareUI_Boss" }) do
            if _G[name] then return _G[name] end
        end
    end,
}

-- one switch for player, pet, target and focus (Edit opens the player frame)
local MAIN_UNITS = { "player", "pet", "target", "focus" }
S:Row{
    key = "uf.main", kind = "frame", reload = true, half = true,
    get = function() return S:GetPath("unitframes.units.player.enabled") and true or false end,
    set = function(on)
        for _, unit in ipairs(MAIN_UNITS) do S:SetPath("unitframes.units." .. unit .. ".enabled", on and true or false) end
    end,
    frame = function() return _G.FlareUI_UF_Player end,
}
-- off, Blizzard's cast bar comes back
Frame("castbar", "unitframes.playerCastbar.enabled", "FlareUI_UF_PlayerCastBar")
-- two columns: Main | Player Cast Bar, Party | Raid, Boss | Target of Target, Target of Focus | Flag Carriers
Frame("party", "unitframes.party.enabled", "FlareUI_Party")
Frame("raid", "unitframes.raid.enabled", "FlareUI_Raid")
Frame("tot", "unitframes.units.targettarget.enabled", "FlareUI_UF_TargetOfTarget")
Frame("tof", "unitframes.units.focustarget.enabled", "FlareUI_UF_TargetOfFocus")
Frame("boss", "unitframes.boss.enabled", "FlareUI_Boss")
-- Blizzard's battleground flag carrier frames, moved in Edit Mode (FlagCarriers.lua)
Frame("flagCarriers", "unitframes.flagCarriers.enabled", "FlareUI_FlagCarriers")

-- each style keeps its own unit frames setup (UnitFramesRing.lua), loaded on reload
S:Row{
    -- (hideLabel: the row has a section of its own, Frame Style)
    key = "uf.frameStyle", kind = "styles", reload = true, hideLabel = true, choices = { "flareui", "forever", "addon" },
    -- (the pick waits for the reload: Ring.ChooseStyle)
    get = function() return ns.UFRing and ns.UFRing.ChosenStyle() or "addon" end,
    set = function(value)
        if ns.UFRing then ns.UFRing.ChooseStyle(value) end
    end,
}
-- the row is only Pick Your Colours, always shown; the
-- palettes (FlareUI, Blizzard) are picked in its window (Settings/ColorPicker.lua)
S:Row{
    -- (lead: first in Look, above the slider and the switches)
    key = "uf.pickColors", kind = "button", buttonText = L["Pick Your Colours"], lead = true,
    apply = function() if ns.ColorPicker then ns.ColorPicker.Open("uf") end end,
}
-- (each frame's fading is in its Edit Mode dialog: Visibility.lua, UnitFrames.lua section 14)
-- frames are made at login: the pet's style applies on reload
-- (two columns: Simple Pet Frame | Simple Target of Target; hidden in Modern, where every frame is plain)
local function ModernStyle() return not (ns.UFRing and ns.UFRing.Style() ~= "addon") end
S:Row{ key = "uf.simplePet", path = "unitframes.simplePet", reload = true, half = true, hidden = ModernStyle }
S:Row{ key = "uf.simpleTargetOf", path = "unitframes.simpleTargetOf", reload = true, half = true, hidden = ModernStyle }
-- (Level Disc Scale: each frame's Edit Mode Text section)
S:Row{ key = "uf.auraShape", kind = "choice", path = "unitframes.auraStyle", choices = { "square", "round" }, apply = Refresh }
S:Row{ key = "uf.auraSwipe", kind = "choice", path = "unitframes.auraSwipe", choices = { "none", "icon", "border", "both" }, apply = Refresh }
S:Row{ key = "uf.auraTimer", kind = "choice", path = "unitframes.auraTimer", choices = { "none", "below", "bottom", "middle" }, apply = Refresh }   -- (Off first in every dropdown)
S:Row{ key = "uf.auraTimerColor", path = "unitframes.auraTimerColor", apply = Refresh,
    disabled = function() return (S:GetPath("unitframes.auraTimer") or "none") == "none" end }

-- FONTS (back from Edit Mode): a section per frame, each text a heading; saved per frame
-- style (UnitFrames.lua UF.FontDb).
local function FontsApply()
    if ns.UnitFrames and ns.UnitFrames.Refresh then ns.UnitFrames:Refresh() end
    -- the totem timers take the player's Aura Timers font (Totems.lua)
    if ns.Totems and ns.Totems.ApplyLayout then ns.Totems.ApplyLayout() end
end
local FONT_FRAMES = {
    { "player", "uf.fontsPlayer" }, { "target", "uf.fontsTarget" }, { "focus", "uf.fontsFocus" },
    { "pet", "uf.fontsPet" }, { "targettarget", "uf.fontsTot" }, { "focustarget", "uf.fontsTof" },
    { "playercast", "uf.fontsCast" }, { "party", "uf.fontsParty" }, { "raid", "uf.fontsRaid" }, { "boss", "uf.fontsBoss" }, { "flag", "uf.fontsFlag" },
}
local UFM = ns.UnitFrames
-- one frame at a time: a Frame picker, then that frame's section only. Search still finds every frame's fonts; a jump picks the frame first.
local pickedFont = "player"
local FONT_FIELDS = { "face", "size", "flags", "enableShadow", "shadowX", "shadowY" }
S:Row{ key = "uf.fontFrame", kind = "choice", tab = "fonts", section = "uf.fontsPick",
    choices = function()
        local list = {}
        for _, frame in ipairs(FONT_FRAMES) do list[#list + 1] = { frame[1], (ns.Copy.sections or {})[frame[2]] or frame[1] } end
        return list
    end,
    get = function() return pickedFont end,
    set = function(value) pickedFont = value end,
    resetValue = function() return pickedFont end }
-- Copy to All Frames: the picked frame's fonts to every other frame, text by text (only the texts both
-- have), in the frame style in use; asks first
ns.Dialogs = ns.Dialogs or {}
ns.Dialogs["FLAREUI_UF_FONT_COPYALL"] = {
    text = L["Give every other unit frame the fonts of %s?"],
    button1 = L["Copy"],
    button2 = L["Cancel"],
    OnAccept = function(data)
        if not data then return end
        local source = {}
        for _, element in ipairs(UFM.FontElements(data.frame)) do source[element] = UFM.FontDb(data.frame, element) end
        for _, frame in ipairs(FONT_FRAMES) do
            if frame[1] ~= data.frame then
                for _, element in ipairs(UFM.FontElements(frame[1])) do
                    local from, to = source[element], UFM.FontDb(frame[1], element)
                    if from and to then
                        for _, field in ipairs(FONT_FIELDS) do
                            if from[field] ~= nil then to[field] = from[field] end
                        end
                    end
                end
            end
        end
        FontsApply()
        if ns.SettingsPanel and ns.SettingsPanel.Refresh then ns.SettingsPanel:Refresh() end
    end,
    hideOnEscape = true,
}
S:Row{ key = "uf.fontCopyAll", kind = "button", tab = "fonts", section = "uf.fontsPick",
    buttonText = L["Copy to All Frames"],
    apply = function()
        local name = pickedFont
        for _, frame in ipairs(FONT_FRAMES) do
            if frame[1] == pickedFont then name = (ns.Copy.sections or {})[frame[2]] or name end
        end
        ns.ShowDialog("FLAREUI_UF_FONT_COPYALL", name, { frame = pickedFont })
    end }
for _, frame in ipairs(FONT_FRAMES) do
    local key = frame[1]
    local fonts = {}
    for _, element in ipairs(UFM.FontElements(key)) do
        fonts[#fonts + 1] = {
            key = element, autoSize = element == "auras" or element == "auraCount" or element == "combatText",
            -- the level has no size of its own: the name's in Addon Style, the level disc's in the ring styles
            noSize = element == "level",
            font = function() return UFM.FontDb(key, element) end,
            default = function() return ns.UFFontDefault(key, element) end,
            -- (11-26, Aphoex) the player frame's Cast Name and Spell Timer style the cast bar on the player
            -- frame; with the Player Cast Bar on, its own section (Player Cast Bar) holds them, so they hide here
            hidden = key == "player" and (element == "cast" or element == "castTime")
                and function() return S:GetPath("unitframes.playerCastbar.enabled") and true or false end or nil,
        }
    end
    S:FontRows{ module = "uf", tab = "fonts", section = frame[2], prefix = key, apply = FontsApply, fonts = fonts, previewKind = key == "playercast" and "castbar" or nil,
        pageHidden = function() return pickedFont ~= key end,
        beforeJump = function() pickedFont = key end }
end
