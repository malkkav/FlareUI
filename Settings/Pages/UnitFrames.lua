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
    key = "uf", group = "HUD", order = 20, enabled = "unitframes.enabled",
    tabs = { { key = "settings" }, { key = "fonts" } },
    -- the frames behind the shared Player / Pet / Target / Focus row
    editFrames = {
        function() return _G.FlareUI_UF_Player end, function() return _G.FlareUI_UF_Target end,
        function() return _G.FlareUI_UF_Focus end, function() return _G.FlareUI_UF_Pet end,
        -- frames of their own with no row here
        function() return _G.FlareUI_UF_PlayerCastBar end, function() return _G.FlareUI_RaidTanks end,
        function() return _G.FlareUI_Totems end,
    },
    -- the header button opens Edit Mode on the first frame that exists
    editMode = function()
        for _, name in ipairs({ "FlareUI_UF_Player", "FlareUI_UF_Target", "FlareUI_UF_Focus", "FlareUI_Party", "FlareUI_Boss" }) do
            if _G[name] then return _G[name] end
        end
    end,
}

-- one switch for player, pet, target, focus and the player cast bar (Edit opens the player frame);
-- the cast bar has no other home, so it is made with the player frame (UnitFrames.lua)
local MAIN_UNITS = { "player", "pet", "target", "focus" }
S:Row{
    key = "uf.main", kind = "frame", reload = true, half = true,
    get = function() return S:GetPath("unitframes.units.player.enabled") and true or false end,
    set = function(on)
        for _, unit in ipairs(MAIN_UNITS) do S:SetPath("unitframes.units." .. unit .. ".enabled", on and true or false) end
        S:SetPath("unitframes.playerCastbar.enabled", on and true or false)
    end,
    frame = function() return _G.FlareUI_UF_Player end,
}
-- two columns: Main | Party, Raid | Boss, Target of Target | Target of Focus
Frame("party", "unitframes.party.enabled", "FlareUI_Party")
Frame("raid", "unitframes.raid.enabled", "FlareUI_Raid")
Frame("boss", "unitframes.boss.enabled", "FlareUI_Boss")
Frame("tot", "unitframes.units.targettarget.enabled", "FlareUI_UF_TargetOfTarget")
Frame("tof", "unitframes.units.focustarget.enabled", "FlareUI_UF_TargetOfFocus")

-- each style keeps its own unit frames setup (UnitFramesRing.lua), loaded on reload
S:Row{
    key = "uf.frameStyle", kind = "choice", reload = true, choices = { "flareui", "forever", "addon" },
    get = function() return ns.UFRing and ns.UFRing.Style() or "addon" end,
    set = function(value)
        if ns.UFRing then ns.UFRing.SetStyle(value) end
    end,
}
S:Row{
    key = "uf.palette", kind = "choice", path = "unitframes.palette", choices = { "flareui", "blizzard" },
    apply = function()
        if ns.UnitFrames and ns.UnitFrames.ApplyPalette then ns.UnitFrames.ApplyPalette() end
        Refresh()
    end,
}
-- player and pet frames fade out of combat unless moused over, down to this; 100% is no fading
local FADE_CHOICES = {}
for percent = 0, 100, 10 do FADE_CHOICES[#FADE_CHOICES + 1] = { percent, percent .. "%" } end
S:Row{
    key = "uf.hidePlayer", kind = "choice", choices = FADE_CHOICES, apply = Refresh,
    get = function()
        local fades = ns.UnitFrames and ns.UnitFrames.GetPlayerShow and ns.UnitFrames:GetPlayerShow() == "fade"
        if not fades then return 100 end
        return S:GetPath("unitframes.visibility.player.minAlpha") or 0
    end,
    set = function(percent)
        S:SetPath("unitframes.visibility.player.minAlpha", percent < 100 and percent or 0)
        if ns.UnitFrames and ns.UnitFrames.SetPlayerShow then ns.UnitFrames:SetPlayerShow(percent < 100 and "fade" or "always") end
    end,
}
S:Row{ key = "uf.fullNames", path = "unitframes.fullNames", apply = Refresh }
-- frames are made at login: the pet's style applies on reload
S:Row{ key = "uf.simplePet", path = "unitframes.simplePet", reload = true }
S:Row{ key = "uf.simpleTargetOf", path = "unitframes.simpleTargetOf", reload = true }
S:Row{ key = "uf.auraShape", kind = "choice", path = "unitframes.auraStyle", choices = { "square", "round" }, apply = Refresh }
S:Row{ key = "uf.auraSwipe", kind = "choice", path = "unitframes.auraSwipe", choices = { "icon", "border", "both", "none" }, apply = Refresh }
S:Row{ key = "uf.auraTimer", kind = "choice", path = "unitframes.auraTimer", choices = { "none", "below", "bottom", "middle" }, apply = Refresh }
S:Row{ key = "uf.auraTimerColor", path = "unitframes.auraTimerColor", apply = Refresh,
    disabled = function() return (S:GetPath("unitframes.auraTimer") or "none") == "none" end }

S:FontRows{ module = "uf", tab = "fonts", section = "uf.fonts", apply = Refresh, fonts = {
    { key = "names", path = "unitframes.font" },
    { key = "power", path = "unitframes.fontPower" },
    { key = "castBar", path = "unitframes.fontCast" },
    { key = "auras", path = "unitframes.auraFont", autoSize = true },
    { key = "auraCount", path = "unitframes.auraCountFont", autoSize = true },
} }
