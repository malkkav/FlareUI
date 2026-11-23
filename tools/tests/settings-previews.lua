-- Preview canvases use simulated data and render into ordinary mouse-free frames.
local setup = dofile("tools/tests/fixtures/settings-addon.lua")
local ui, ns = setup()
local E, S, P = ui.env, ns.Settings, ns.SettingsPreview
local profile = ns.db.profile
E.UnitName = function(unit) assert(unit == "player"); return "Tester" end
ns.HEALTH_GREEN = { 0.2, 0.8, 0.2 }
ns.ObjectiveTracker = { SampleColors = { TITLE = { 1, 1, 1 }, TITLE_FOCUS = { 0, 0.5, 1 },
    ZONE = { 1, 0.8, 0 }, OBJECTIVE = { 0.9, 0.9, 0.9 } },
    -- (11-23) the Colour Scheme's sources: Blizzard's colours, FlareUI's bronze picks
    blizzColors = { HEADING = { 1, 0.82, 0 }, ZONE = { 1, 0.82, 0 }, TITLE = { 1, 0.82, 0 }, TITLE_DONE = { 0.13, 1, 0.13 },
        TITLE_FOCUS = { 0.3, 0.6, 1 }, OBJECTIVE = { 0.8, 0.8, 0.8 }, OBJECTIVE_DONE = { 0.55, 0.55, 0.55 } },
    SCHEME_BRONZE = { HEADING = "bronze5", ZONE = "bronze5", TITLE = "bronze4" } }
ns.PALETTE = { bronze4 = { 0.7, 0.5, 0.3 }, bronze5 = { 0.8, 0.6, 0.35 } }
ns.SoftColor = function(r, g, b) return r * 0.8, g * 0.8, b * 0.8 end
ui:load("Settings/PreviewSamples.lua", ns)

local c = P.Create(E.UIParent, 280, 270)
local o = c.objects
local function draw(kind, key, value, path)
    assert(P.Show(c, { kind = kind, key = key, value = value, path = path }), kind)
    assert(c.frame:IsShown())
end
local function shown(object) return object and object:IsVisible() end
local function text(object, value) return object and object:GetText():find(value, 1, true) end

profile.chat = { betterTimestamps = true, classIcons = true, shortChannels = true, copyButton = true, showVolume = true }
draw("chat", "ch.combatLog")
assert(text(o.chatLine1, "[12:30] [2]") and text(o.chatLine1, "ClassIcon_Mage"), "chat shows timestamp, short channel and class icon")
assert(shown(o.copyButton) and shown(o.combatTab) and shown(o.chatHeader4))
local original = o.chatLine1
draw("chat", "ch.combatLog", true, "chat.hideCombatLog")
assert(original == o.chatLine1 and not shown(o.combatTab) and profile.chat.hideCombatLog == nil,
    "new settings render on cached objects without saving the preview value")
draw("chat", "ch.minAlpha", 0.35, "chat.minAlpha")
assert(c.frame:GetAlpha() == 0.35)
c.frame:SetAlpha(1)
-- (11-23) Frame Style, Header Buttons, Edit Box Style and Border, Icons and Tab Glow
draw("chat", "ch.frameStyle", "flareui", "chat.frameStyle")
assert(shown(o.chatStrip) and shown(o.chatFoot) and o.chatBox:GetBackdrop().edgeFile == "border/FlareUI Thick")
draw("chat", "ch.frameStyle", "modern", "chat.frameStyle")
assert(not shown(o.chatStrip))
draw("chat", "ch.headerButtons", "volume")
assert(shown(o.chatHeader4) and not shown(o.chatHeader1) and not shown(o.chatHeader2), "only the hovered pick")
draw("chat", "ch.editBoxStyle", "flareui", "chat.editBoxStyle")
assert(shown(o.editMid) and shown(o.editLeft))
draw("chat", "ch.editBoxBorder", "thick")
assert(not shown(o.editMid) and o.editBox:GetBackdrop().edgeFile == "border/FlareUI Thick")
draw("chat", "ch.icons", "raceIcons")
assert(text(o.chatLine1, "SCOURGE") and not text(o.chatLine1, "ClassIcon_Mage"), "the hovered icon pick")
draw("chat", "ch.unreadGlow", "guild", "chat.unreadGlow")
assert(text(o.chatTab2, "Guild") and shown(o.chatTabGlow))
draw("chat", "ch.unreadGlow", "none", "chat.unreadGlow")
assert(not shown(o.chatTabGlow))

profile.tooltips = { showThreat = true, showTarget = true, showGuild = true, showGuildRank = true, nameColor = "class" }
draw("tooltip", "tt.healthBar", "inside")
local tip = c.tooltipCanvas.objects
assert(tip.tooltipHealth:IsVisible() and tip.tooltipHealth:GetValue() == 0.8)
assert(text(tip.tooltipTitle, "|cff69ccf0") and text(tip.tooltipText, "<Dawnwatch> (Officer)") and text(tip.tooltipText, "Threat: 65%"))
draw("tooltip", "tt.healthBar", "off")
assert(not shown(tip.tooltipHealth) and profile.tooltips.hideHealthBar == nil)
draw("tooltip", "tt.ids", true)
assert(text(tip.tooltipText, "ID: 14152") and text(tip.tooltipTitle, "Robes of the Archmage"))
profile.tooltips.itemLevel = true
draw("tooltip", "tt.itemLevel")
assert(text(tip.tooltipText, "Item Level 76") and text(tip.tooltipTitle, "Robes of the Archmage"), "an item, not a player")
draw("tooltip", "tt.compareShift")
assert(text(o.comparisonText, "Equipped") and c.tooltipCanvas.frame:GetScale() == 0.6)

profile.objectivetracker = { zoneHeaders = true, showTags = true, frameStyle = "blizzard", minimizeStyle = "button" }
draw("tracker", "qt.overview")
assert(text(o.zone, "Elwynn Forest") and text(o.quest1, "[5] A Threat Within [G]") and shown(o.objective2))
local _, _, _, opacity = o.trackerBox:GetBackdropColor()
assert(opacity == 0, "the Blizzard tracker style has no painted background")
draw("tracker", "qt.minimizeButton")
assert(o.trackerBox:GetHeight() == 35 and o.trackerTitle:GetText() == "+" and not shown(o.objective2))
-- (11-23) the header buttons, the Colour Scheme, the complete tag, a finished objective, the scroll bar
profile.objectivetracker = { frameStyle = "flareui" }
draw("tracker", "qt.overview")
assert(shown(o.trackerFold) and shown(o.trackerBtn_sort) and shown(o.trackerBtn_filter) and not shown(o.trackerBtn_accept))
assert(text(o.quest1, "(Complete)") and shown(o.objectiveDone) and shown(o.trackerScroll))
local r = o.trackerTitle:GetTextColor()
assert(math.abs(r - 0.8) < 1e-6, "FlareUI scheme: the bronze heading, got " .. tostring(r))
draw("tracker", "qt.colorScheme", "blizzard")
r = o.trackerTitle:GetTextColor()
assert(r == 1, "hovering Blizzard: Blizzard's gold heading, got " .. tostring(r))
draw("tracker", "qt.headerButtons", "accept,turnin")
assert(shown(o.trackerBtn_accept) and shown(o.trackerBtn_turnin) and not shown(o.trackerBtn_sort), "a hovered Header Buttons pick")
profile.objectivetracker = { frameStyle = "flareui", showCompleteTag = false, hideFinished = true, hideScrollBar = true }
draw("tracker", "qt.overview")
assert(not text(o.quest1, "(Complete)") and not shown(o.objectiveDone) and not shown(o.trackerScroll))

profile.damagemeter = { threatValueDisplay = "percent", threatTankLead = true, threatPullLine = true }
draw("meter", "dm.pullFlash", true, "damagemeter.threatPullFlash")
assert(text(o.meterTitle, "Threat") and text(o.meterName1, "75% (+25%)") and shown(o.pullLine))
c.frame:RunScript("OnUpdate", 0.2)
local flash = o.pullFlash:GetAlpha()
assert(flash > 0 and flash < 0.55)
P.paused = true
c.frame:RunScript("OnUpdate", 0.5)
assert(o.pullFlash:GetAlpha() == flash, "pausing stops an active preview animation")
P.paused = false
draw("meter", "dm.chatTab", "click")
assert(shown(o.meterChatTab) and not shown(o.pullFlash), "switching preview discards old effects")

profile.minimap = { buttonBag = true, bagHover = true, clockStats = true, microMenu = true }
draw("minimap", "mm.style", "round")
local map = c.mapCanvas.objects
assert(shown(map.roundTerrain) and shown(map.mapRing) and not shown(map.mapBorder))
draw("minimap", "mm.squareBorder", "header")
assert(shown(map.squareTerrain) and shown(map.mapHeader) and not shown(map.mapRing))
draw("minimap", "mm.bagHover")
assert(shown(map.drawerPointer) and map.mapButton1:GetParent() == map.drawer)
draw("minimap", "mm.clockStats")
assert(text(map.clockFPS, "60 fps") and text(map.clockWorld, "36 ms") and not shown(map.drawer))
draw("minimap", "mm.microMenu")
assert(text(map.microText, "Spellbook"))
-- (11-23) the Info Bar: no cells, no bar (unless a bar row is hovered); its cells, box and place
assert(not shown(map.infoBar), "no Info Bar with every cell None")
profile.minimap.infoBar = { left = "gold", center = "coords", right = "fps" }
draw("minimap", "mm.barLeft")
assert(text(map.infoLeft, "128g") and text(map.infoCenter, "45.3, 62.1") and text(map.infoRight, "60 fps") and shown(map.infoBar))
local overY = select(3, map.infoBar:GetPoint())
draw("minimap", "mm.barBelow", true, "minimap.infoBarBelow")
local belowY = select(3, map.infoBar:GetPoint())
assert(belowY < overY, "Below the Map puts it lower")
draw("minimap", "mm.barBox", false, "minimap.infoBarBox")
assert(not shown(map.infoBar) and text(map.infoCenter, "45.3"), "Show Box off: the text alone")
profile.minimap.style = "round"
draw("minimap", "mm.barCenter")
assert(text(map.infoCenter, "45.3") and not shown(map.infoLeft) and not shown(map.infoRight), "the round map: Centre only")
profile.minimap.style, profile.minimap.infoBar = nil, nil

profile.tweaks = { bagColumns = 6, bagKeyring = true, bagReagent = true, bagButtons = true, bagJunkIcon = true, petFood = true, bagThickBorders = true }
draw("bags", "bl.bagView")
-- (11-23) 18 slots, the last two empty with their bag's picture
assert(shown(o.bagItem16) and not shown(o.bagItem17) and shown(o.bagEmpty17) and shown(o.bagEmpty18) and not shown(o.bagItem19))
assert(shown(o.junk) and shown(o.petFood))
assert(not shown(o.bagIlvl) and not shown(o.bagBoE) and not shown(o.bagEye), "the sword's marks are off")
assert(o.bagBorder1:GetBackdrop().edgeFile == "border/FlareUI Thick")
assert(text(o["tweaks.bagKeyringTitle"], "Keyring") and text(o["tweaks.bagReagentTitle"], "Crafting Bag") and shown(o.bagButton4))
profile.tweaks.bagItemLevel, profile.tweaks.bagBoE, profile.tweaks.bagUncollected = true, true, true
draw("bags", "bl.bagItemLevel")
assert(text(o.bagIlvl, "18") and text(o.bagBoE, "BoE") and shown(o.bagEye), "the sword shows its marks")
profile.tweaks.bagCombineEmpty = true
draw("bags", "bl.bagCombineEmpty")
assert(shown(o.bagEmpty17) and not shown(o.bagEmpty18) and text(o.bagFree, "2"), "one combined empty slot with the free count")
profile.tweaks.bagCombineEmpty, profile.tweaks.bagItemLevel, profile.tweaks.bagBoE, profile.tweaks.bagUncollected = nil, nil, nil, nil
draw("lootFeed", "bl.lootFeed")
assert(text(o.feedOff, "Disabled"))
draw("lootFeed", "bl.lootFeedQuality", 3, "tweaks.lootFeedQuality")
assert(text(o.feedText1, "Robes of the Archmage") and not text(o.feedText1, "Linen Cloth") and c.used > 0)
c.frame:RunScript("OnUpdate", 2.75)
assert(o.feedText1:GetAlpha() == 0.5)
draw("lootRolls", "bl.lootRolls")
assert(text(o.rollsOff, "Disabled"))
draw("lootRolls", "bl.lootRolls", true, "tweaks.lootRolls")
-- (11-23: no Background Opacity, the window always full)
assert(o.rollsWin.rock:GetAlpha() == 1 and text(o.rollsRowResulta, "Tester") and text(o.rollsRowResultb, "Miri"))
c.frame:RunScript("OnUpdate", 6)
assert(o.rollsTime:GetText() == "15" and o.rollsTimer:GetValue() == 0.5)
-- (11-23) the loot window: off says so; on, its rows take the Bags marks; Show Free Bag Slots adds
-- the footer in place of the money row
draw("lootWindow", "bl.lootWindow")
assert(text(o.lootWinOff, "Disabled"))
profile.tweaks.lootWindow, profile.tweaks.bagItemLevel, profile.tweaks.bagBoE = true, true, false
draw("lootWindow", "bl.lootWindow")
assert(shown(o.lootWinPanel) and text(o.lootWinName1, "Silver") and o.lootWinPanel.rock:GetAlpha() == 1)
assert(shown(o.lootWinMarks2.ilvl) and not shown(o.lootWinMarks2.boe) and shown(o.lootWinMarks4.junk))
assert(text(o.lootWinName3, "(4)"), "the owned count always shows")
profile.tweaks.lootWindowFreeSlots = true
draw("lootWindow", "bl.lootWindowFreeSlots")
assert(shown(o.lootWinFree) and not text(o.lootWinName1, "Silver"), "the footer takes the money row's room")
profile.tweaks.lootWindow, profile.tweaks.lootWindowFreeSlots = nil, nil
-- (11-23) the Buff Reminders page's own rows route to its preview (they kept old au.* keys before)
for _, key in ipairs({ "br.group", "br.before", "br.consumables", "br.upkeepPick" }) do
    local spec = P.Resolve({ key = key, Get = function() return nil end })
    assert(spec and spec.kind == "reminders", key .. " has no preview")
end
assert(P.Module("br").kind == "reminders")

profile.radialmenu = { showNames = true }
draw("radial", "rm.scale", 1.5, "radialmenu.scale")
assert(text(o.radialName, "Frostbolt") and o.wheelBackground:GetWidth() == 222)
c.frame:RunScript("OnUpdate", 1.7)
assert(text(o.radialName, "Heal"), "the hover label follows the selected slice")
profile.radialmenu.buttonNames = "always"
draw("radial", "rm.names")
assert(shown(o.radialName1) and text(o.radialName4, "Mount") and not shown(o.radialName))

profile.auras = { reminders = true, reminder = { group = "party", consumables = "all", glowMissing = true } }
draw("reminders", "au.reminderGroup")
assert(text(o.reminderGroup, "Party") and shown(o.reminderIcon4) and shown(o.reminderGlow1))
c.frame:RunScript("OnUpdate", 0.2)
assert(o.reminderGlow1:GetAlpha() < 1)

local function sampleFrame(parent, kind)
    local frame = E.CreateFrame("Frame", nil, parent)
    frame.sampleKind = kind
    return frame
end
ns.UnitFrames = {
    CreateSample = function(parent, unit)
        local frame = sampleFrame(parent, unit)
        frame.Health = E.CreateFrame("StatusBar", nil, frame)
        frame.Power = E.CreateFrame("StatusBar", nil, frame)
        return frame
    end,
    DrawSample = function(frame, style, opts)
        frame.drawnStyle, frame.usedPreset = style, opts and opts.preset
        frame.Health:SetStatusBarColor(0, 0.8, 0)
        frame.Power:SetStatusBarColor(0, 0, 1)
        return { width = 340, height = 52, left = 20, top = 10 }
    end,
    CreateCastSample = sampleFrame,
    DrawCastSample = function() return 200, 45 end,
}
ns.UFRing = { Style = function() return "forever" end, Overhang = function() return 18 end }
local card = P.Create(E.UIParent, 200, 100)
assert(P.Show(card, { kind = "unit", key = "uf.frameStyle", value = "flareui" }))
local sample = card.objects["playerSample:player"]
assert(sample:GetScale() < 1 and sample.drawnStyle == "flareui" and sample.usedPreset,
    "style cards show a scaled preview of the candidate preset")
draw("unit", "uf.simplePet", false, "unitframes.simplePet")
assert(o["petSample:pet"].drawnStyle == "forever")
draw("unit", "uf.simpleTargetOf", true, "unitframes.simpleTargetOf")
assert(o["totSample:targettarget"].drawnStyle == "addon" and o["tofSample:focustarget"].drawnStyle == "addon")
draw("unit", "uf.pickColors")
local r, g = o["playerSample:player"].Health:GetStatusBarColor()
assert(r > 0 and g < 0.8, "the FlareUI palette washes the unit colors")
draw("frames", "uf.main")
assert(shown(o["framePlayer:player"]) and shown(o["frameTarget:target"]))
draw("frames", "uf.castbar")
assert(shown(o.castSample) and not shown(o["frameTarget:target"]))

ns.PartyFrames = {
    SampleTile = function(parent, context, data, index)
        local frame = sampleFrame(parent, context and context.kind or "party")
        frame.data, frame.index = data, index
        return frame
    end,
    DrawSampleTile = function(frame)
        frame.ringKind, frame.ringSide = "party", "LEFT"
        return 65, 45
    end,
}
ns.RaidFrames = { PreviewCtx = { kind = "raid" }, PreviewSamples = { { name = "Raid Sample" } } }
ns.BossFrames = { PreviewCtx = { kind = "boss" }, PreviewSamples = { { name = "Boss Sample" } } }
draw("frames", "uf.raid")
local tiles = o["tiles:raid"].tiles
assert(#tiles == 25 and tiles[1].data.name == "Raid Sample" and select(5, tiles[1]:GetPoint()) > select(5, tiles[6]:GetPoint()))
draw("frames", "uf.boss")
assert(#o["tiles:boss"].tiles == 3 and o["tiles:boss"].tiles[1].sampleKind == "boss" and not shown(o["tiles:raid"]))

ns.ActionBars = {
    CreateSampleButton = function(parent)
        local frame = sampleFrame(parent)
        frame.icon = frame:CreateTexture()
        frame.cooldown = E.CreateFrame("Cooldown", nil, frame)
        return frame
    end,
    DrawSampleButton = function(frame, icon, _, skinned)
        frame.icon:SetTexture(icon)
        frame.skinned = skinned
        return 45
    end,
    PaintStatus = function(texture, state) texture.status = state end,
}
profile.actionbars = { procGlow = true, colors = { enableRange = true } }
draw("actions", "ab.overview")
local actions = o.actionRow
assert(#actions.buttons == 5 and actions.buttons[2].cooldown.cooldown[2] == 12 and actions.buttons[3].icon.status == "range"
    and actions.buttons[4].icon.status == "mana" and actions.glow:IsShown())
profile.actionbars.procGlow = false
draw("actions", "ab.overview")
assert(o.actionRow == actions and not actions.glow:IsShown())
draw("actionSkin", "ab.flareBorders", false, "actionbars.flareBorders")
local skins = o.actionSkinRows.rows
assert(not skins[1].buttons[1].skinned and skins[1].buttons[1]:GetAlpha() == 1 and skins[2].buttons[1]:GetAlpha() == 0.55)
assert(skins[2].buttons[1].skinned and not skins[2].buttons[3].icon:GetTexture(), "both styles show the empty action slot")

profile.cooldownmanager = { enabled = true, skin = true, keybinds = true, effectCooldown = true, press = true, softOverlay = true }
c.cdmTime = 0.1
draw("cdm", "cdm.press")
assert(shown(o.cdmPush) and text(o.cdmKey4, "4") and o.cdmBar:GetValue() == 0.6)
c.frame:RunScript("OnUpdate", 0.6)
assert(not shown(o.cdmPush) and o.cdmActive:GetText() == "8" and o.cdmEffect:GetText() == "12")
c.frame:RunScript("OnUpdate", 8)
assert(o.cdmActive:GetText() == "4" and o.cdmEffect:GetText() == "", "the corner timer appears only during the effect")
c.frame:RunScript("OnUpdate", 4)
assert(o.cdmActive:GetText() == "")
profile.cooldownmanager.enabled = false
draw("cdm", "cdm.overview")
assert(not shown(o.cdmKey4) and shown(o.cdmRing4) and not shown(o.cdmBarEdge))

ns.Minimap = {
    CreateSample = sampleFrame,
    DrawSample = function(frame, kind, spec)
        frame.candidate = spec.value
        return kind == "drawer" and 400 or 100, 60
    end,
}
draw("minimapDrawer", "mm.bagButtonSize", 125, "minimap.bagButtonSize")
assert(o["Minimap:drawer"].candidate == 125 and o["Minimap:drawer"]:GetScale() < 1 and profile.minimap.bagButtonSize == nil)

S:Module{ key = "ch", group = "interface" }
local face = S:Row{ key = "ch.font.text.face", previewFont = "chat.textFont", path = "chat.textFont.face", kind = "choice" }
local toggle = S:Row{ key = "ch.copyButton", invert = true, path = "chat.copyButton" }
assert(P.Resolve(toggle, true).value == false and P.Resolve(toggle, true).temporary, "an inverted toggle previews the stored value")
assert(P.Style(c, face, "Custom") and o.fontSample:GetFont() == "Fonts/Custom" and face:Get() == nil,
    "font picker preview shows the candidate face without saving it")
local errors = {}
E.geterrorhandler = function() return function(err) errors[#errors + 1] = err end end
P.renderers.broken = function(canvas) canvas:Text("partial", "Partial", 1, 1); error("broken preview") end
assert(not P.Show(c, { kind = "broken" }) and not P.Show(c, { kind = "broken" }))
assert(not c.frame:IsShown() and not o.partial:IsShown() and #errors == 1 and P.activeSpec == nil,
    "a preview exception hides partial output, restores context and reports once")
assert(not P.Show(c, nil) and not c.frame:IsShown())

print("PASS: settings preview states, animations, cache and fault isolation")
