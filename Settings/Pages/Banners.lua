local _, ns = ...
local L = ns.L
local S = ns.Settings

--------------------------------------------------
-- BANNERS
-- Settings for Modules/Banners.lua and BannerSources.lua in three tabs: Kinds (a switch for each
-- banner), Look (the animation, where they stay away, an example) and Fonts. The module's switch asks
-- for a reload; everything else applies at once. Placement and scale are in Edit Mode.
--------------------------------------------------
local function Refresh()
    if ns.Banners then ns.Banners:Refresh() end
end

S:Module{
    key = "bn", group = "interface", order = 38, enabled = "banners.enabled",
    tabs = { { key = "kinds" }, { key = "look" }, { key = "fonts" } },
    editMode = function() return _G.FlareUI_Banners end,
}

-- KINDS ------------------------------------------
local function Kind(key, option, section, extra)
    local row = { key = "bn." .. key, half = true, tab = "kinds", section = section, path = "banners." .. option, apply = Refresh }
    if extra then for field, value in pairs(extra) do row[field] = value end end
    S:Row(row)
end
local function NoZones() return not (S:GetPath("banners.zone") or S:GetPath("banners.subzone")) end
local function NoProgress() return not S:GetPath("banners.questProgress") end

Kind("zone", "zone", "bn.zones")
Kind("subzone", "subzone", "bn.zones")
Kind("discovery", "discovery", "bn.zones", { disabled = NoZones })
Kind("zoneColors", "zoneColors", "bn.zones", { disabled = NoZones })
Kind("hideZoneInSub", "hideZoneInSub", "bn.zones", { disabled = function() return not S:GetPath("banners.subzone") end })

Kind("questAccept", "questAccept", "bn.quests")
Kind("questComplete", "questComplete", "bn.quests")
Kind("questProgress", "questProgress", "bn.quests")
Kind("compactProgress", "compactProgress", "bn.quests", { disabled = NoProgress })

Kind("levelUp", "levelUp", "bn.character")
Kind("achievement", "achievement", "bn.character")
Kind("achievementProgress", "achievementProgress", "bn.character")

Kind("bossEmote", "bossEmote", "bn.encounters")
Kind("rare", "rare", "bn.encounters")
Kind("scenario", "scenario", "bn.encounters")

-- LOOK -------------------------------------------
S:Row{ key = "bn.example", kind = "button", center = true, tab = "look", section = "bn.look",
    buttonText = L["Show Example"],
    apply = function() if ns.Banners then ns.Banners:SampleNext() end end }
S:Row{ key = "bn.icons", half = true, tab = "look", section = "bn.look", path = "banners.icons", apply = Refresh }
S:Row{ key = "bn.animate", half = true, tab = "look", section = "bn.look", path = "banners.animate", apply = Refresh }

local function NoAnimation() return S:GetPath("banners.animate") == false end
local TIMES, HOLDS = {}, {}
for n = 2, 15 do TIMES[#TIMES + 1] = { n / 10, L["%.1f s"]:format(n / 10) } end
for n = 5, 20, 1 do HOLDS[#HOLDS + 1] = { n / 10, ("%d%%"):format(n * 10) } end
S:Row{ key = "bn.enterTime", kind = "range", half = true, tab = "look", section = "bn.timing", path = "banners.enterTime",
    choices = TIMES, disabled = NoAnimation }
S:Row{ key = "bn.exitTime", kind = "range", half = true, tab = "look", section = "bn.timing", path = "banners.exitTime",
    choices = TIMES, disabled = NoAnimation }
S:Row{ key = "bn.hold", kind = "range", tab = "look", section = "bn.timing", path = "banners.hold", choices = HOLDS }

-- Don't Show In: one dropdown over the four saved switches
local PLACES = { { "dungeon", "skipDungeon" }, { "raid", "skipRaid" }, { "arena", "skipArena" }, { "battleground", "skipBattleground" } }
local PLACE_SPEC = { exclusive = { "none" }, tokens = { "dungeon", "raid", "arena", "battleground" }, empty = "none" }
local function PlaceValue(read)
    local on = {}
    for _, place in ipairs(PLACES) do
        if read("banners." .. place[2]) then on[#on + 1] = place[1] end
    end
    return #on > 0 and table.concat(on, ",") or "none"
end
S:Row{ key = "bn.skip", kind = "dropdown", tab = "look", section = "bn.timing", toggles = PLACE_SPEC, apply = Refresh,
    choices = { "none", { divider = true }, "dungeon", "raid", "arena", "battleground" },
    get = function() return PlaceValue(function(path) return S:GetPath(path) end) end,
    set = function(value)
        local on = ns.Conditions.Set(value, PLACE_SPEC)
        for _, place in ipairs(PLACES) do S:SetPath("banners." .. place[2], on[place[1]] and true or false) end
    end,
    resetValue = function() return PlaceValue(function(path) return S:DefaultPath(path) end) end }

-- FONTS: the face, outline and shadow; the sizes belong to the banner's kind (scale it in Edit Mode)
S:FontRows{ module = "bn", tab = "fonts", section = "bn.fonts", fonts = {
    { key = "title", path = "banners.titleFont", noSize = true },
    { key = "text", path = "banners.textFont", noSize = true },
}, apply = function()
    if ns.Banners then ns.Banners:ApplyFont() end
end }
