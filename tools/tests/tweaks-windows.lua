local ui, ns = dofile("tools/tests/fixtures/party-world.lua")
local env = ui.env
local db = ns.db.profile.tweaks
db.enabled, db.moveAnyFrame, db.way, db.zoneLevels = true, true, true, true
db.bagModule, db.bagModuleSeeded, db.bulkBuy, db.merchantKnown = true, true, true, true
local notes, buys = {}, {}
env.print = function(text) notes[#notes + 1] = text end
env.C_AddOns.IsAddOnLoaded = function(name) return name == "Blizzard_WorldMap" end
env.EventUtil = { ContinueOnAddOnLoaded = function() end }
env.C_NamePlate = { GetNamePlates = function() return {} end }
env.SlashCmdList = {}
env.StaticPopup_Show = function() end
env.UpdateContainerFrameAnchors = function() end
env.IsMouseButtonDown = function(button) return ui.leftDown and button == "LeftButton" end
env.GetCVar = function() return "0" end
env.GetCVarBool = function() return false end
env.SetCVar = function() end
env.C_CVar = { GetCVarInfo = function() return nil end }
env.C_Timer.NewTimer = env.C_Timer.NewTicker
env.GameTooltip.IsOwned = function(self, frame) return self.owner == frame end

local Widget = getmetatable(env.UIParent)
function Widget:GetID() return self.widgetID end
function Widget:StartMoving() self.moving = true end
function Widget:StopMovingOrSizing() self.moving = false end
function Widget:EnableMouseWheel(value) self.wheel = value end
function Widget:IsMouseWheelEnabled() return self.wheel end
function Widget:IsProtected() return self.protected == true end

local book = env.CreateFrame("Frame", "SpellBookFrame", env.UIParent)
book.TitleContainer = env.CreateFrame("Frame", nil, book)
book.protected = true
env.UIPanelWindows = { SpellBookFrame = {} }
env.UpdateUIPanelPositions = function()
    book:ClearAllPoints()
    book:SetPoint("CENTER", env.UIParent, "CENTER")
end
local map = env.CreateFrame("Frame", "WorldMapFrame", env.UIParent)
local areaLabel = env.CreateFrame("Frame", nil, map)
areaLabel.Name = areaLabel:CreateFontString()
map.dataProviders = { [{ Label = areaLabel }] = true }
function map:GetMapID() return 1 end
function map:GetNormalizedCursorPosition() return 0.4, 0.5 end
env.Enum.UIMapType = { Zone = 1, Continent = 2, Dungeon = 3, Micro = 4 }
local maps = {
    [1] = { mapID = 1, name = "Continent", mapType = 2 },
    [5] = { mapID = 5, name = "Élwynn Forest", mapType = 3, parentMapID = 1 },
    [1429] = { mapID = 1429, name = "Élwynn Forest", mapType = 1, parentMapID = 1 },
}
local pin, tracked
env.C_Map = {
    GetBestMapForUnit = function() return 1429 end,
    GetFallbackWorldMapID = function() return 5 end,
    GetMapInfo = function(id) return maps[id] end,
    GetMapChildrenInfo = function() return { maps[5], maps[1429] } end,
    CanSetUserWaypointOnMap = function(id) return id == 1429 end,
    SetUserWaypoint = function(point) pin = point end,
    GetMapInfoAtPosition = function() return maps[1429] end,
    GetMapLevels = function() end,
}
env.UiMapPoint = { CreateFromCoordinates = function(...) return { ... } end }
env.C_SuperTrack = { SetSuperTrackedUserWaypoint = function(value) tracked = value end }
env.GetQuestDifficultyColor = function() return { r = 0, g = 1, b = 0 } end
env.RGBTableToColorCode = function(color) assert(color.g == 1); return "|cff00ff00" end
env.FONT_COLOR_CODE_CLOSE = "|r"

local merchant = env.CreateFrame("Frame", "MerchantFrame", env.UIParent)
merchant.selectedTab, merchant.page = 1, 1
local slot = env.CreateFrame("Frame", "MerchantItem1", merchant)
local item = env.CreateFrame("Button", "MerchantItem1ItemButton", slot)
item.widgetID = 1
local split = env.CreateFrame("Frame", "StackSplitFrame", merchant)
split:Hide()
split.StackSplitText = split:CreateFontString()
split.LeftButton = env.CreateFrame("Button", nil, split)
split.RightButton = env.CreateFrame("Button", nil, split)
function split:OpenStackSplitFrame(cap, owner, _, _, unit)
    self.maxStack, self.owner, self.minSplit = cap, owner, unit
    self:Show()
end
local itemID = 200
env.GetMerchantItemID = function(index) if index == 1 then return itemID end end
env.GetMerchantItemMaxStack = function() return 5 end
env.MerchantItemButton_OnModifiedClick = function() split:OpenStackSplitFrame(5, item, nil, nil, 1) end
env.IsModifiedClick = function(key) return key == "SPLITSTACK" end
env.MerchantFrame_UpdateMerchantInfo = function() end
env.MerchantFrame_UpdateBuybackInfo = function() end
env.ITEM_SPELL_KNOWN = "Already known"
env.C_TooltipInfo = { GetMerchantItem = function() return { lines = { { leftText = env.ITEM_SPELL_KNOWN } } } end }
env.SetItemButtonDesaturated = function(button, value) button.desaturated = value end
env.SetItemButtonTextureVertexColor = function(button, ...) button.tint = { ... } end
env.SetItemButtonNameFrameVertexColor = function(button, ...) button.nameTint = { ... } end
env.GetMoney = function() return 160 end
env.C_MerchantFrame = { GetItemInfo = function() return { stackCount = 1, price = 10, numAvailable = 12 } end }
env.C_Item = { GetItemFamily = function() return 0 end, GetItemMaxStackSizeByID = function() return 10 end }
env.C_Container = {
    GetContainerNumFreeSlots = function(bag) return 1, bag == 0 and 0 or 1 end,
    GetContainerNumSlots = function() return 1 end,
    GetContainerItemInfo = function(bag) if bag == 0 then return { itemID = 200, stackCount = 8 } end end,
}
env.BACKPACK_CONTAINER, env.NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0, 1
env.BuyMerchantItem = function(index, amount) buys[#buys + 1] = { index, amount } end

ui:load("Modules/TweaksCVars.lua", ns)
ui:load("Modules/Tweaks.lua", ns)
ui.combat = true
ns.Tweaks:Init()
assert(not book.moveName, "A protected window loaded in combat waits for lockdown to end")
ui.combat = false
ui:emit("PLAYER_REGEN_ENABLED")
assert(book.moveName == "SpellBookFrame" and book.TitleContainer.moveTarget == book)
local title = book.TitleContainer
ui.leftDown = true
title:RunScript("OnMouseDown", "LeftButton")
local watcher = assert(ui:find(function(f) return f:IsShown() and f:GetScript("OnUpdate") and f.handle == title end))
watcher:RunScript("OnUpdate")
assert(not book.moving)
ui.cursorX = 1
watcher:RunScript("OnUpdate")
assert(book.moving)
book.left, book.top = 150.4, 340.6
title:RunScript("OnMouseUp", "LeftButton")
assert(not book.moving and db.frames.SpellBookFrame.x == 150 and db.frames.SpellBookFrame.y == 341)
env.UpdateUIPanelPositions()
local p, _, _, x, y = book:GetPoint()
assert(p == "TOPLEFT" and x == 150 and y == 341)
ui.control = true
ui:emit("MODIFIER_STATE_CHANGED", "LCTRL")
assert(book.wheel)
book:RunScript("OnMouseWheel", 2)
assert(book:GetScale() == 1.2 and db.frames.SpellBookFrame.scale == 1.2)
title:RunScript("OnMouseUp", "RightButton")
assert(book:GetScale() == 1 and db.frames.SpellBookFrame.scale == nil)
ui.control, ui.shift = false, true
title:RunScript("OnMouseUp", "RightButton")
assert(book:GetPoint() == "CENTER" and db.frames.SpellBookFrame.point == nil)

local way = env.SlashCmdList.FLAREWAY
assert(way and env.SLASH_FLAREWAY1 == "/way")
way("elwynn forest 42.5, 60")
assert(pin[1] == 1429 and pin[2] == 0.425 and pin[3] == 0.6 and tracked)
way("20 30")
assert(pin[2] == 0.2 and pin[3] == 0.3)
local oldPin = pin
way("#5 20 40")
assert(pin == oldPin and notes[#notes]:find("not allowed", 1, true))
way("Nowhere 10 20")
assert(pin == oldPin and notes[#notes]:find("Could not find", 1, true))
way(" 101 40 ")
assert(pin == oldPin and notes[#notes]:find("between 0 and 100", 1, true))
areaLabel.Name:SetText("Élwynn Forest")
assert(ns.Tweaks.zoneLevelLine:GetText() == "|cff00ff00(1-10)|r")
areaLabel.Name:SetText("Continent")
assert(ns.Tweaks.zoneLevelLine:GetText() == "")

env.MerchantFrame_UpdateMerchantInfo()
assert(item.desaturated and item.tint[1] == 0.6)
merchant.selectedTab = 2
env.MerchantFrame_UpdateBuybackInfo()
assert(not item.desaturated)
merchant.selectedTab = 1
env.MerchantItemButton_OnModifiedClick(item)
assert(split.owner ~= item and split.maxStack == 12, "Stock and compatible bag space cap the amount")
local stack = assert(ui:find(function(f) return f:GetParent() == split and f:GetText() == "Stack" end))
local max = assert(ui:find(function(f) return f:GetParent() == split and f:GetText() == "MAX" end))
stack:Click()
assert(split.split == 10 and split.LeftButton:IsEnabled() and split.RightButton:IsEnabled())
max:Click()
assert(split.split == 12 and not split.RightButton:IsEnabled())
split.owner:SplitStack(split.split)
assert(#buys == 1 and buys[1][1] == 1 and buys[1][2] == 5)
ui:emit("BAG_UPDATE_DELAYED")
ui:emit("BAG_UPDATE_DELAYED")
assert(#buys == 3 and buys[2][2] == 5 and buys[3][2] == 2)
ui:emit("BAG_UPDATE_DELAYED")
local progress = assert(ui:find(function(f)
    return f:GetObjectType() == "FontString" and f:GetParent() == merchant and f:GetText() == "Bought 12 of 12."
end))
split.owner:SplitStack(12)
ui:emit("MERCHANT_CLOSED")
assert(#buys == 4 and progress:GetText() == "Purchase stopped: 0 of 12 bought.")
split:Hide()
assert(not stack:IsShown() and not max:IsShown())
print("PASS: window drag and scale, map pins, zone levels, and merchant batch buying")
