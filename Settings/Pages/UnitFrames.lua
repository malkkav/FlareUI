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
-- two columns: Main | Player Cast Bar, Party | Raid, Boss | Target of Target, Target of Focus
Frame("party", "unitframes.party.enabled", "FlareUI_Party")
Frame("raid", "unitframes.raid.enabled", "FlareUI_Raid")
Frame("boss", "unitframes.boss.enabled", "FlareUI_Boss")
Frame("tot", "unitframes.units.targettarget.enabled", "FlareUI_UF_TargetOfTarget")
Frame("tof", "unitframes.units.focustarget.enabled", "FlareUI_UF_TargetOfFocus")

-- each style keeps its own unit frames setup (UnitFramesRing.lua), loaded on reload
S:Row{
    -- (hideLabel: the row has a section of its own, Frame Style, 11-13)
    key = "uf.frameStyle", kind = "styles", reload = true, hideLabel = true, choices = { "flareui", "forever", "addon" },
    get = function() return ns.UFRing and ns.UFRing.Style() or "addon" end,
    set = function(value)
        if ns.UFRing then ns.UFRing.SetStyle(value) end
    end,
}
-- (11-11, Marcus: players missed the button) the row is only Pick Your Colours, always shown; the
-- palettes (FlareUI, Blizzard) are picked in its window (Settings/ColorPicker.lua)
S:Row{
    key = "uf.pickColors", kind = "button", buttonText = L["Pick Your Colours"],
    apply = function() if ns.ColorPicker then ns.ColorPicker.Open("uf") end end,
}
-- (each frame's fading is in its Edit Mode dialog: Visibility.lua, UnitFrames.lua section 14)
S:Row{ key = "uf.fullNames", path = "unitframes.fullNames", apply = Refresh }
-- frames are made at login: the pet's style applies on reload
S:Row{ key = "uf.simplePet", path = "unitframes.simplePet", reload = true }
S:Row{ key = "uf.simpleTargetOf", path = "unitframes.simpleTargetOf", reload = true }
S:Row{ key = "uf.auraShape", kind = "choice", path = "unitframes.auraStyle", choices = { "square", "round" }, apply = Refresh }
S:Row{ key = "uf.auraSwipe", kind = "choice", path = "unitframes.auraSwipe", choices = { "icon", "border", "both", "none" }, apply = Refresh }
S:Row{ key = "uf.auraTimer", kind = "choice", path = "unitframes.auraTimer", choices = { "none", "below", "bottom", "middle" }, apply = Refresh }
S:Row{ key = "uf.auraTimerColor", path = "unitframes.auraTimerColor", apply = Refresh,
    disabled = function() return (S:GetPath("unitframes.auraTimer") or "none") == "none" end }

-- FONTS (11-13, back from Edit Mode): a section per frame, each text a heading; saved per frame
-- style (UnitFrames.lua UF.FontDb).
local function FontsApply()
    if ns.UnitFrames and ns.UnitFrames.Refresh then ns.UnitFrames:Refresh() end
    -- the totem timers take the player's Aura Timers font (Totems.lua)
    if ns.Totems and ns.Totems.ApplyLayout then ns.Totems.ApplyLayout() end
end
local FONT_FRAMES = {
    { "player", "uf.fontsPlayer" }, { "target", "uf.fontsTarget" }, { "focus", "uf.fontsFocus" },
    { "pet", "uf.fontsPet" }, { "targettarget", "uf.fontsTot" }, { "focustarget", "uf.fontsTof" },
    { "playercast", "uf.fontsCast" }, { "party", "uf.fontsParty" }, { "raid", "uf.fontsRaid" }, { "boss", "uf.fontsBoss" },
}
local UFM = ns.UnitFrames
for _, frame in ipairs(FONT_FRAMES) do
    local key = frame[1]
    local fonts = {}
    for _, element in ipairs(UFM.FontElements(key)) do
        fonts[#fonts + 1] = {
            key = element, autoSize = element == "auras" or element == "auraCount",
            font = function() return UFM.FontDb(key, element) end,
            default = function() return ns.UF_FONT_DEFAULTS[element] end,
        }
    end
    S:FontRows{ module = "uf", tab = "fonts", section = frame[2], prefix = key, apply = FontsApply, fonts = fonts }
end
