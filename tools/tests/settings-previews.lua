-- Preview canvases use simulated data and render into ordinary mouse-free frames.
local setup = dofile("tools/tests/fixtures/settings-addon.lua")
local ui, ns = setup()
local E, S, P = ui.env, ns.Settings, ns.SettingsPreview
local profile = ns.db.profile
E.UnitName = function(unit) assert(unit == "player"); return "Tester" end
ns.HEALTH_GREEN = { 0.2, 0.8, 0.2 }
ns.ObjectiveTracker = { SampleColors = { TITLE = { 1, 1, 1 }, TITLE_FOCUS = { 0, 0.5, 1 },
    ZONE = { 1, 0.8, 0 }, OBJECTIVE = { 0.9, 0.9, 0.9 } } }
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

profile.tooltips = { showThreat = true, showTarget = true, showGuild = true, showGuildRank = true, nameColor = "class" }
draw("tooltip", "tt.healthBar", "inside")
local tip = c.tooltipCanvas.objects
assert(tip.tooltipHealth:IsVisible() and tip.tooltipHealth:GetValue() == 0.8)
assert(text(tip.tooltipTitle, "|cff69ccf0") and text(tip.tooltipText, "<Dawnwatch> (Officer)") and text(tip.tooltipText, "Threat: 65%"))
draw("tooltip", "tt.healthBar", "off")
assert(not shown(tip.tooltipHealth) and profile.tooltips.hideHealthBar == nil)
draw("tooltip", "tt.ids", true)
assert(text(tip.tooltipText, "ID: 14152") and text(tip.tooltipTitle, "Robes of the Archmage"))
draw("tooltip", "tt.compareShift")
assert(text(o.comparisonText, "Equipped") and c.tooltipCanvas.frame:GetScale() == 0.6)

profile.objectivetracker = { zoneHeaders = true, showTags = true, frameStyle = "blizzard", minimizeStyle = "button" }
draw("tracker", "qt.overview")
assert(text(o.zone, "Elwynn Forest") and text(o.quest1, "[5] A Threat Within [G]") and shown(o.objective2))
local _, _, _, opacity = o.trackerBox:GetBackdropColor()
assert(opacity == 0, "the Blizzard tracker style has no painted background")
draw("tracker", "qt.minimizeButton")
assert(o.trackerBox:GetHeight() == 35 and o.trackerTitle:GetText() == "+" and not shown(o.objective2))

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

profile.tweaks = { bagColumns = 6, bagKeyring = true, bagReagent = true, bagButtons = true, bagJunkIcon = true, petFood = true, bagThickBorders = true }
draw("bags", "bl.bagView")
assert(shown(o.bagItem18) and not shown(o.bagItem19) and shown(o.junk) and shown(o.petFood))
assert(o.bagBorder1:GetBackdrop().edgeFile == "border/FlareUI Thick")
assert(text(o["tweaks.bagKeyringTitle"], "Keyring") and text(o["tweaks.bagReagentTitle"], "Crafting Bag") and shown(o.bagButton4))
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
