local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local Widget = getmetatable(env.UIParent)
function Widget:SetNormalAtlas(atlas) self:SetNormalTexture(atlas) end
function Widget:SetPushedAtlas(atlas) self:SetPushedTexture(atlas) end
function Widget:SetHighlightAtlas(atlas) self:SetHighlightTexture(atlas) end
function Widget:IsProtected() return false end
function Widget:IsOwned(owner) return self:GetOwner() == owner end
env.MinimapCluster = env.CreateFrame("Frame", "MinimapCluster", env.UIParent)
env.MinimapCluster.DielFrame = env.CreateFrame("Frame", nil, env.MinimapCluster)
env.Minimap = env.CreateFrame("Minimap", "Minimap", env.MinimapCluster)
env.GameTimeFrame = env.CreateFrame("Button", "GameTimeFrame", env.MinimapCluster)
env.C_Texture = { GetAtlasInfo = function(key) return key == "journal-atlas" and {} end }
env.C_AddOns = { IsAddOnLoaded = function() return false end, GetAddOnTitle = function() return nil end }
local menuOpen = false
env.Menu = { GetManager = function() return { IsAnyMenuOpen = function() return menuOpen end } end }
local fired = {}
local objects = {
    Alpha = {
        label = "|cff33bb22Alpha|r", icon = "journal-atlas", type = "launcher",
        OnTooltipShow = function(tip) tip:AddLine("Alpha launcher") end,
        OnClick = function(_, button) fired[#fired + 1] = "alpha:" .. button; menuOpen = button == "RightButton" end,
    },
    Beta = {
        type = "data source", text = "Time left 00:59", icon = 200, iconCoords = { 0.1, 0.9, 0.1, 0.9 },
        OnEnter = function() fired[#fired + 1] = "beta:enter" end,
        OnLeave = function() fired[#fired + 1] = "beta:leave" end,
    },
}
local icons = {}
for _, name in ipairs({ "Alpha", "Beta" }) do
    icons[name] = env.CreateFrame("Button", "LibDBIcon10_" .. name, env.Minimap)
    icons[name]:SetScript("OnClick", function() error("original broker frame should be parked") end)
end
env.AddonCompartmentFrame = {
    registeredAddons = {
        { text = "Alpha", icon = "journal-atlas", func = function() error("duplicated broker entry") end },
        { text = "FlareUI", icon = 300, func = function(_, state) fired[#fired + 1] = "flare:" .. state.buttonName end },
        { text = "Zephyr", icon = 400, func = function(_, state) fired[#fired + 1] = "zephyr:" .. state.buttonName end },
    },
}
local foreign = env.CreateFrame("Button", "SomeOtherMinimapButton", env.Minimap)
foreign:SetSize(32, 32)

foreign:SetScript("OnClick", function() fired[#fired + 1] = "foreign" end)
local pin = env.CreateFrame("Button", "QuestiePin12", env.Minimap)
pin:SetSize(14, 14)
pin:SetScript("OnClick", function() error("a pin cannot be an addon button") end)
local brokerCallback
env.LibStub = function(name)
    if name == "LibSharedMedia-3.0" then
        return { IsValid = function() return true end, Fetch = function(_, _, key) return "Media/" .. key end }
    elseif name == "LibDBIcon-1.0" then
        return {
            GetButtonList = function()
                local names = {}
                for key in pairs(icons) do names[#names + 1] = key end
                return names
            end,
            GetMinimapButton = function(_, key) return icons[key] end,
            RegisterCallback = function(_, event, callback)
                assert(event == "LibDBIcon_IconCreated"); brokerCallback = callback
            end,
        }
    elseif name == "LibDataBroker-1.1" then
        return { GetDataObjectByName = function(_, key) return objects[key] end }
    end
end

local db = { sundial = false, bagHover = true, bagButtonSize = 125 }
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    db = { profile = { minimap = db } },
    BORDER_COLOR = env.CreateColor(0.8, 0.6, 0.34, 1),
    BorderEdgeSize = function(_, v) return v end,
    CopyStrata = function(target, source) target:SetFrameStrata(source:GetFrameStrata()) end,
    OwnGameTooltip = function(owner, anchor)
        env.GameTooltip:SetOwner(owner, anchor)
        env.GameTooltip.lines = nil
    end,
    Conditions = { Set = function(value)
        local t = {}
        for token in value:gmatch("[^,]+") do t[token] = true end
        return t
    end },
    Minimap = { UpdateFlareButton = function() ui.flareUpdates = (ui.flareUpdates or 0) + 1 end },
}
ui:load("Modules/MinimapBag.lua", ns)
local bag = ns.MinimapBag
assert(bag.Style() == "blizzard" and bag:IsOn() and bag.ButtonSize() == 30)
assert(bag.ButtonSize(12) == 24 and bag.ButtonSize(999) == 36)
bag.ApplyStyle()
local dial = env.MinimapCluster.DielFrame
dial:SetAlpha(0.75)
assert(dial:IsShown() and dial:GetAlpha() == 0, "hidden sundial stays active without showing")
bag:Init()
ui:flushTimers()
local drawer, badge = env.FlareUI_MinimapBag, env.FlareUI_DrawerButton
assert(not drawer:IsShown() and badge.Text:GetText() == "5")
assert(icons.Alpha:GetParent() ~= env.Minimap and foreign:GetParent() == drawer and pin:GetParent() == env.Minimap)
assert(bag.FlareIn())
local function button(name)
    return ui:find(function(w)
        return w:GetParent() == drawer and w:IsVisible() and w.entry and w.entry.name == name
    end)
end
badge:Click()
assert(drawer:IsShown() and button("Alpha").icon:GetAtlas() == "journal-atlas")
assert(button("Beta").entry.label == "Beta" and button("Alpha"):GetWidth() == 30)
button("Alpha"):RunScript("OnEnter")
assert(env.GameTooltip:IsShown() and env.GameTooltip.lines[1] == "Alpha launcher")
button("Beta"):RunScript("OnEnter")
button("Beta"):RunScript("OnLeave")
assert(fired[1] == "beta:enter" and fired[2] == "beta:leave" and not env.GameTooltip:IsShown())
button("Alpha"):Click("RightButton")
ui:flushTimers()
assert(drawer:IsShown() and fired[3] == "alpha:RightButton", "an addon's open menu keeps its owner visible")
menuOpen = false
button("Zephyr"):Click()
ui:flushTimers()
assert(not drawer:IsShown() and fired[4] == "zephyr:LeftButton")

badge:RunScript("OnEnter")
assert(drawer:IsShown() and badge.Add:IsShown())
local hover = ui:find(function(w) return w:IsShown() and w ~= drawer and w:GetScript("OnUpdate") end)
drawer.mouseOver = true
hover:RunScript("OnUpdate", 0.2)
assert(drawer:IsShown())
drawer.mouseOver = false
hover:RunScript("OnUpdate", 0.1)
assert(drawer:IsShown())
hover:RunScript("OnUpdate", 0.06)
assert(not drawer:IsShown())
badge:RunScript("OnLeave")
assert(not badge.Add:IsShown())

badge:Click()
local handle = bag.GetCatcher(1)
handle:RunScript("OnDragStart")
ui.cursorX, ui.cursorY = drawer:GetLeft() + 9 + 34 * 2, drawer:GetTop() - 10
drawer:RunScript("OnUpdate", 0.1)
assert(select(2, button("Alpha"):GetPoint()) == env.UIParent)
ui:emit("GLOBAL_MOUSE_UP")
assert(db.bagOrder[3] == "ldb:Alpha")
ui:flushTimers()
db.bagButtonSize = 150
bag.SizeChanged()
assert(button("Alpha"):GetWidth() == 36)
badge.left = 1700
bag.Reanchor()
assert(drawer:GetPoint():find("RIGHT", 1, true))
ui:emit("GLOBAL_MOUSE_DOWN")
assert(not drawer:IsShown())

bag.AddonChoices()
bag.SetInDrawer("alpha,beta,zephyr")
assert(not bag.FlareSelected() and not bag.FlareIn() and ui.flareUpdates == 1)
badge:Click()
assert(not button("FlareUI") and button("Zephyr"))
local sample = bag.CreateSample(env.UIParent)
local width, height, count = bag.DrawSample(sample, { flareIn = true, buttonSize = 36 })
assert(width > height and count == 5 and sample.icons[3].icon:GetTexture():find("Icon.png", 1, true))
assert(not sample.icons[4]:IsShown())
local extra = env.CreateFrame("Button", "LibDBIcon10_Later", env.Minimap)
icons.Later, objects.Later = extra, { label = "Later", icon = 500 }
brokerCallback(nil, extra, "Later")
assert(extra:GetParent() ~= env.Minimap)
ui:emit("ADDON_LOADED")
ui:flushTimers()
assert(button("Later") and badge.Text:GetText() == "5")
db.flareButton = false
bag.FlareChanged()
assert(not bag.FlareOn() and not bag.FlareIn())
print("PASS: minimap drawer deduplication, click routing, hover, ordering, sizing and late registrations")
