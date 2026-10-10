local _, ns = ...
local S = ns.Settings

--------------------------------------------------
-- UNIT FRAMES (Modules/UnitFrames.lua, PartyFrames.lua). Each frame is a row with its switch and
-- Edit; size, texts, portrait, auras and icons are set in Edit Mode. Frames are made at login, so
-- switching one asks for a reload. Class colours and the aura look apply to every frame.
--------------------------------------------------
local function Refresh()
    if ns.UnitFrames and ns.UnitFrames.Refresh then ns.UnitFrames:Refresh() end
    if ns.PartyFrames and ns.PartyFrames.Refresh then ns.PartyFrames:Refresh() end
    if ns.ResourceBars and ns.ResourceBars.Refresh then ns.ResourceBars:Refresh() end
end

local function Frame(key, path, frameName)
    S:Row{
        key = "uf." .. key, kind = "frame", reload = true, path = path,
        frame = function() return _G[frameName] end,
    }
end

S:Module{
    key = "uf", group = "HUD", order = 20, enabled = "unitframes.enabled",
    editFrames = { function() return _G.FlareUI_UF_Player end },
    -- the header button opens Edit Mode on the first frame that is on
    editMode = function()
        for _, name in ipairs({ "FlareUI_UF_Player", "FlareUI_UF_Target", "FlareUI_UF_Focus", "FlareUI_Party", "FlareUI_Boss" }) do
            if _G[name] then return _G[name] end
        end
    end,
}

-- Frames. Player, pet, target and focus go together: one switch for the four (Edit opens the
-- player frame)
local MAIN_UNITS = { "player", "pet", "target", "focus" }
S:Row{
    key = "uf.main", kind = "frame", reload = true,
    get = function() return S:GetPath("unitframes.units.player.enabled") and true or false end,
    set = function(on)
        for _, unit in ipairs(MAIN_UNITS) do S:SetPath("unitframes.units." .. unit .. ".enabled", on and true or false) end
    end,
    frame = function() return _G.FlareUI_UF_Player end,
}
Frame("castbar", "unitframes.playerCastbar.enabled", "FlareUI_UF_PlayerCastBar")
Frame("tot", "unitframes.units.targettarget.enabled", "FlareUI_UF_TargetOfTarget")
Frame("tof", "unitframes.units.focustarget.enabled", "FlareUI_UF_TargetOfFocus")
Frame("party", "unitframes.party.enabled", "FlareUI_Party")
Frame("raid", "unitframes.raid.enabled", "FlareUI_Raid")
Frame("boss", "unitframes.boss.enabled", "FlareUI_Boss")

-- Look: every frame, party frames and the resource health bar included
-- Addon style: the player, target and focus frames without the Forever style's bronze ring (the
-- default). Each style keeps its own whole unit frames setup (UnitFramesRing.lua), loaded on the reload.
S:Row{
    key = "uf.addonStyle", reload = true,
    get = function() return not (ns.UFRing and ns.UFRing.On()) end,
    set = function(on)
        if ns.UFRing then ns.UFRing.SetOn(not on) end
    end,
}
S:Row{ key = "uf.classColours", path = "unitframes.classColor", apply = Refresh }
-- the bars' colours: FlareUI's tones or Blizzard's bright originals
S:Row{
    key = "uf.palette", kind = "choice", path = "unitframes.palette", choices = { "flareui", "blizzard" },
    apply = function()
        if ns.UnitFrames and ns.UnitFrames.ApplyPalette then ns.UnitFrames.ApplyPalette() end
        Refresh()
    end,
}
S:Row{ key = "uf.auraShape", kind = "choice", path = "unitframes.auraStyle", choices = { "square", "round" }, apply = Refresh }
S:Row{ key = "uf.auraTimer", kind = "choice", path = "unitframes.auraTimer", choices = { "none", "below", "bottom", "middle" }, apply = Refresh }
