local _, ns = ...
local L = ns.L
local S = ns.Settings

--------------------------------------------------
-- QUALITY OF LIFE
-- Settings for Modules/Tweaks.lua in Gameplay, Interface and Advanced tabs. Options that replace
-- Blizzard scripts ask for a reload; the rest apply live.
--------------------------------------------------
local function Refresh()
    if ns.Tweaks then ns.Tweaks:Refresh() end
end

-- greys the nameplate rows while another nameplate addon draws the plates
local function NameplateAddon()
    return ns.Tweaks and ns.Tweaks.GetNameplateAddon and ns.Tweaks:GetNameplateAddon() and true or false
end

S:Module{
    key = "qol", group = "Tools", order = 20, enabled = "tweaks.enabled",
    tabs = { { key = "gameplay" }, { key = "interface" }, { key = "advanced" } },
}

-- ADVANCED ---------------------------------------
-- Sync Blizz UI: copies one character's Blizzard settings to the others
S:Row{ key = "qol.sync", tab = "advanced", path = "tweaks.syncUI", reload = true, section = "qol.syncBlizzUi" }
S:Row{
    key = "qol.source", kind = "button", tab = "advanced", parent = "qol.sync", section = "qol.syncBlizzUi",
    labelFn = function()
        local label = ns.Tweaks and ns.Tweaks.GetSyncSourceLabel and ns.Tweaks:GetSyncSourceLabel()
        return label and L["Current source: %s"]:format(label) or L["No source yet."]
    end,
    buttonText = L["Make this character the source"],
    disabled = function() return ns.Tweaks and ns.Tweaks.IsSyncSource and ns.Tweaks:IsSyncSource() or false end,
    apply = function() ns.ShowDialog("FLAREUI_SYNC_SOURCE") end,
}

-- one switch for moving windows and placing loot rolls / toasts
S:Row{
    key = "qol.move", tab = "advanced", reload = true,
    get = function() return S:GetPath("tweaks.moveAnyFrame") end,
    set = function(on)
        S:SetPath("tweaks.moveAnyFrame", on)
        S:SetPath("tweaks.moveLootToasts", on)
    end,
}

-- GAMEPLAY ---------------------------------------
S:Row{ key = "qol.fastLoot", tab = "gameplay", path = "tweaks.fasterLoot", apply = Refresh }
-- one switch for further and faster camera zoom
S:Row{
    key = "qol.camera", tab = "gameplay",
    get = function() return S:GetPath("tweaks.maxCameraZoom") end,
    set = function(on)
        S:SetPath("tweaks.maxCameraZoom", on)
        S:SetPath("tweaks.fasterCameraZoom", on)
    end,
    apply = Refresh,
}
S:Row{ key = "qol.delete", tab = "gameplay", path = "tweaks.autoDelete", apply = Refresh }
S:Row{ key = "qol.trainAll", tab = "gameplay", path = "tweaks.trainAll", apply = Refresh }
S:Row{ key = "qol.way", tab = "gameplay", path = "tweaks.way", reload = true }
S:Row{ key = "qol.mailBook", tab = "gameplay", path = "tweaks.mailBook", apply = Refresh }
S:Row{ key = "qol.alerts", tab = "gameplay", path = "tweaks.alertSounds" }
S:Row{ key = "qol.petFood", tab = "gameplay", path = "tweaks.petFood", apply = Refresh }
S:Row{ key = "qol.skipLoot", tab = "gameplay", path = "tweaks.skipLootConfirm" }

-- INTERFACE --------------------------------------
S:Row{ key = "qol.npCombo", tab = "interface", path = "tweaks.nameplateCombo", apply = Refresh, disabled = NameplateAddon }
S:Row{ key = "qol.npQuest", tab = "interface", path = "tweaks.nameplateQuest", apply = Refresh, disabled = NameplateAddon }
-- live when switched on; switching off leaves visible plates' bars wide until Blizzard re-lays
-- them, so the reload bar offers a reload
S:Row{ key = "qol.npLevel", tab = "interface", path = "tweaks.nameplateHideLevel", disabled = NameplateAddon,
    apply = function(on)
        Refresh()
        S:TrackReload("qol.npLevel", on and "on" or "off", "on")
    end }
-- Blizzard's own enemy plates, so another nameplate addon does not grey it out
S:Row{ key = "qol.npCombat", tab = "interface", path = "tweaks.combatPlates", apply = Refresh }

S:Row{ key = "qol.sellJunk", tab = "interface", path = "tweaks.sellJunk", apply = Refresh }
S:Row{ key = "qol.repair", tab = "interface", path = "tweaks.autoRepair", apply = Refresh }
S:Row{ key = "qol.durability", tab = "interface", path = "tweaks.durabilityWarning", apply = Refresh }
S:Row{ key = "qol.merchantKnown", tab = "interface", path = "tweaks.merchantKnown", apply = Refresh }

S:Row{ key = "qol.hideErrors", tab = "interface", path = "tweaks.hideErrors", reload = true }
S:Row{ key = "qol.hideZoneText", tab = "interface", path = "tweaks.hideZoneText", reload = true }
S:Row{ key = "qol.hidePartyTitle", tab = "interface", path = "tweaks.hidePartyTitle", apply = Refresh }
S:Row{ key = "qol.hideTips", tab = "interface", path = "tweaks.hideTips", apply = Refresh }
S:Row{ key = "qol.hideFrameNumbers", tab = "interface", path = "tweaks.hidePortraitNumbers", apply = Refresh }
