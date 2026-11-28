local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local function noop() end
local callbacks, edit = {}, { SettingType = { Slider = "slider" } }
function edit:GetActiveLayoutName() return "Modern" end
function edit:AddFrame(_, move) self.move = move end
function edit:AddFrameSettings(_, settings) self.scale = settings[1] end
function edit:RegisterCallback(event, fn) callbacks[event] = fn end
env.LibStub = function(name) assert(name == "FlareEditMode"); return edit end
env.LOOT_ITEM_SELF_MULTIPLE = "Received (%2$d) %1$s."
env.LOOT_ITEM_SELF = "Received %s."
env.SKILL_RANK_UP = "%2$d reached in %1$s."
env.UnitGUID = function() return "Player-1" end
local cash = 10000
env.GetMoney = function() return cash end
env.GetMoneyString = function(value) return value .. "c" end
env.ITEM_QUALITY_COLORS = { [3] = { r = 0, g = 0.5, b = 1 } }
env.C_Item = {
    GetItemQualityByID = function(id) return id == 1 and 3 or id == 2 and 0 or nil end,
    GetItemIconByID = function(id) return id + 100 end,
    GetItemCount = function(id) return ({ [1] = 12 })[id] or 0 end,
    GetItemNameByID = function(id) return ({ [2589] = "Linen Cloth", [2770] = "Copper Ore", [2447] = "Peacebloom" })[id] end,
}
env.C_Spell = { GetSpellTexture = function(name) return name == "Mining" and 300 end }
env.canaccessvalue = function() return true end
env.issecretvalue = function(text) return text == "Secret" end
local db = { lootFeed = true, lootFeedAlign = "center", lootFeedQuality = 2, lootFeedSkills = true, lootFeedIcons = "round" }
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }), modules = {},
    db = { profile = { tweaks = db } },
    BagModuleOn = function() return true end,
    LayoutHome = function(layouts, key)
        layouts[key] = layouts[key] or {}
        return layouts[key]
    end,
    EditSection = function(_, settings) return settings end,
    SetFont = function(w, ...) w:SetFont(...) end,
    GetFontPath = function(face) return "Fonts/" .. face end,
    ApplyShadow = noop,
}
ui:load("Modules/LootFeed.lua", ns)
local feed = ns.LootFeed
assert(feed:ShouldLoad())
feed:Init()
local holder = env.FlareUI_LootFeed
assert(holder:GetWidth() == 220 and edit.scale.get() == 100)
callbacks.enter()
assert(not holder:IsShown(), "cursor mode has nothing to place")
assert(holder:GetFrameStrata() == "HIGH", "behind Blizzard's Edit Mode dialog (11-27)")
callbacks.exit()
assert(holder:IsShown() and holder:GetFrameStrata() == "FULLSCREEN_DIALOG", "out of Edit Mode: above every window again")

local function textIs(text)
    return ui:find(function(w) return w:GetParent() == holder and w:IsVisible() and w.text and w.text:GetText() == text end)
end
local function loot(text, guid)
    ui:emit("CHAT_MSG_LOOT", text, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, guid)
end
local linen = "|Hitem:1:0|h[Linen Cloth]|h"
local rare = "|cff8844ee|Hitem:3|h[Enchanting Dust]|h|r"
ui.cursorX, ui.cursorY = 500, 320
loot("Received (2) " .. linen .. ".")
local cloth = assert(textIs("Linen Cloth x2"))
assert(cloth.icon:GetTexture() == 101 and cloth.mask:GetAtlas() == "talents-node-circle-mask")
assert(holder:GetPoint() == "BOTTOM" and select(4, holder:GetPoint()) == 500 and select(5, holder:GetPoint()) == 336)
ui.cursorX, ui.cursorY = 100, 200
loot("Received " .. linen .. ".")
assert(textIs("Linen Cloth x3") == cloth and select(4, holder:GetPoint()) == 500)
-- Owned Count (on by default): how many you have, on the icon; again after the bags update
assert(cloth.owned:IsShown() and tostring(cloth.owned:GetText()) == "12")
assert(cloth.owned:IsShown() and tostring(cloth.owned:GetText()) == "12")
env.C_Item.GetItemCount = function(id) return id == 1 and 15 or 0 end
ui:emit("BAG_UPDATE_DELAYED")
assert(tostring(cloth.owned:GetText()) == "15")
db.lootFeedOwned = false
feed.UpdateAllOwned()
assert(not cloth.owned:IsShown(), "Owned Count off hides it")
db.lootFeedOwned = nil
loot("Received |Hitem:2|h[Junk]|h.")
assert(not textIs("Junk"))
loot("Different locale " .. rare .. " × 4", "Other")
assert(not textIs("Enchanting Dust x4"))
loot("Different locale " .. rare .. " x 4", "Player-1")
local dust = assert(textIs("Enchanting Dust x4"))
assert(dust.text:GetTextColor() == 0x88 / 255)

ui:emit("CHAT_MSG_SKILL", "78 reached in Mining.")
local mining = assert(textIs("Mining 78"))
assert(mining.icon:GetTexture() == 300)
ui:emit("CHAT_MSG_SKILL", "79 reached in Mining.")
assert(textIs("Mining 79") == mining and not textIs("Mining 78"))
cash = 11200
ui:emit("PLAYER_MONEY")
assert(not textIs("1200c"), "money waits for a loot chat event")
ui:emit("CHAT_MSG_MONEY")
local money = assert(textIs("1200c"))
assert(not money.icon:IsShown() and not money.border:IsShown() and not money.owned:IsShown())
ui.time = 102
ui:emit("CHAT_MSG_MONEY")
cash = 11240
ui:emit("PLAYER_MONEY")
assert(textIs("40c"), "pair loot and money events in either order")
ui.time = 106
cash = 13240
ui:emit("PLAYER_MONEY")
ui.time = 109
ui:emit("CHAT_MSG_MONEY")
assert(not textIs("2000c"), "a delayed chat line must not claim unrelated income")

db.lootFeedAlign, db.lootFeedIcons, db.lootFeedFont = "right", "square", { face = "Test", size = 16, flags = "NONE" }
feed:ApplyFont()
holder:RunScript("OnUpdate", 0.1)
assert(cloth:GetPoint() == "BOTTOMRIGHT" and cloth.border:GetTexture():find("IconBorder", 1, true))
assert(cloth.text:GetFont() == "Fonts/Test" and cloth:GetAlpha() == 0.5)
holder:RunScript("OnUpdate", 4.5)
assert(not holder:GetScript("OnUpdate") and not cloth:IsShown())
loot("Received " .. linen .. ".")
assert(select(4, holder:GetPoint()) == 82, "a new right-aligned feed starts left of the pointer")

db.lootFeedPosition = "placed"
edit.move(nil, "Modern", "TOP", 12.4, -230.6)
feed:Refresh()
assert(holder:GetPoint() == "TOP" and select(4, holder:GetPoint()) == 12 and select(5, holder:GetPoint()) == -231)
edit.scale.set(nil, 125)
assert(holder:GetScale() == 1.25 and edit.scale.get() == 125)
callbacks.enter()
assert(holder.preview:IsShown() and holder.preview.lines[1].text:GetText() == "Linen Cloth x2")
callbacks.exit()
assert(not holder.preview:IsShown() and holder:GetPoint() == "TOP")
print("PASS: loot feed localization, aggregation, money pairing, placement and Edit Mode")
