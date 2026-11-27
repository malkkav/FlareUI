local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
local db = { warnSellSetGear = false }
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    modules = {}, Dialogs = {}, db = { profile = { tweaks = db } },
    BagModuleOn = function() return true end,
}
local prompt, sales, otherClicks, promptCount = nil, {}, 0, 0
function ns.ShowDialog(key, text, data)
    prompt = { key = key, text = text, data = data }
    promptCount = promptCount + 1
end
local function answer(accept)
    local dialog = assert(prompt, "expected a sale confirmation")
    prompt = nil
    ns.Dialogs[dialog.key][accept and "OnAccept" or "OnCancel"](dialog.data)
end
function ns.CancelDialog(key)
    if prompt and prompt.key == key then answer(false) end
end
function ns.AnyDialogShown() return prompt ~= nil end

env.SELL, env.CANCEL = "Sell", "Cancel"
env.Enum = {}
-- The click catchers are mouse-transparent for motion and opt in to individual mouse buttons.
local frameMethods = getmetatable(env.UIParent)
function frameMethods:SetMouseClickEnabled(enabled) self.mouseClickEnabled = enabled end
function frameMethods:SetMouseMotionEnabled(enabled) self.mouseMotionEnabled = enabled end
function frameMethods:SetPropagateMouseMotion(enabled) self.propagateMouseMotion = enabled end
function frameMethods:SetPassThroughButtons(...) self.passThroughButtons = { ... } end
function frameMethods:RegisterForClicks(...) self.registeredClicks = { ... } end

local foci = {}
env.GetMouseFoci = function() return foci end
local function hover(target, parent)
    foci = { target, parent }
    local watcher = env.FlareUIVendorSaleWatcher
    if watcher and watcher:IsShown() then watcher:RunScript("OnUpdate") end
end

local function catchesClick(catcher, target, button)
    if not (catcher and catcher:IsVisible() and catcher.allPoints == target and catcher.mouseClickEnabled) then
        return false
    end
    for _, passThrough in ipairs(catcher.passThroughButtons or {}) do
        if button == passThrough then return false end
    end
    return true
end

local function clickBag(button, mouseButton)
    hover(button)
    local catcher = env.FlareUIVendorBagSaleCatcher
    if catchesClick(catcher, button, mouseButton) then
        for _, click in ipairs(catcher.registeredClicks or {}) do
            if click == mouseButton .. "Up" or click == "AnyUp" then catcher:RunScript("OnClick", mouseButton) end
        end
    else
        button:RunScript("OnClick", mouseButton)
    end
end

local function dropAt(target, nativeScript, button)
    ui:emit("CURSOR_CHANGED")
    hover(target)
    local catcherName = target == env.MerchantFrame and "FlareUIVendorDropCatcher" or "FlareUIVendorDropCatcher1"
    local catcher = env[catcherName]
    if catchesClick(catcher, target, button) then
        catcher:RunScript(nativeScript == "OnReceiveDrag" and nativeScript or "OnMouseUp", button)
    else
        target:RunScript(nativeScript, button)
    end
end
local merchant = env.CreateFrame("Frame", "MerchantFrame", env.UIParent)
merchant.selectedTab = 1
merchant:Hide()
local merchantItem = env.CreateFrame("Button", "MerchantItem1ItemButton", merchant)
local combined = env.CreateFrame("Frame", "ContainerFrameCombinedBags", env.UIParent)
local separate = env.CreateFrame("Frame", "ContainerFrame1", env.UIParent)
local function slot(frame, bag, index)
    local button = env.CreateFrame("Button", nil, frame)
    button.buttonContext = "ButtonContext_ContainerFrameItemButton"
    function button:GetBagID() return bag end
    function button:GetID() return index end
    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" and not ui.modified and merchant:IsShown() and merchant.selectedTab == 1 then
            sales[#sales + 1] = { "right", bag, index }
        else
            otherClicks = otherClicks + 1
        end
    end)
    return button
end
local gear = slot(combined, 0, 1)
local duplicate = slot(separate, 1, 1)
local separateItems = { duplicate }
local reagentProbe = slot(combined, 5, 1)
local originalProbeClick = reagentProbe:GetScript("OnClick")
function combined:EnumerateValidItems() return ipairs({ gear, reagentProbe }) end
function separate:EnumerateValidItems() return ipairs(separateItems) end
env.ContainerFrame_GenerateFrame = function() end
env.NUM_CONTAINER_FRAMES = 1

local items = {
    [0] = { [1] = "gear-guid" }, [1] = { [1] = "duplicate-guid" }, [5] = { [1] = "reagent-guid" },
    worn = { [4] = "worn-guid" },
}
local function location(bag, index)
    return {
        IsBagAndSlot = function() return bag ~= "worn" end,
        IsEquipmentSlot = function() return bag == "worn" end,
        GetBagAndSlot = function() if bag ~= "worn" then return bag, index end end,
        GetEquipmentSlot = function() return index end,
        IsValid = function() return items[bag][index] ~= nil end,
    }
end
local function itemGUID(loc)
    if loc:IsEquipmentSlot() then return items.worn[loc:GetEquipmentSlot()] end
    local bag, index = loc:GetBagAndSlot()
    return items[bag][index]
end
env.ItemLocation = { CreateFromBagAndSlot = function(_, bag, index) return location(bag, index) end }
env.C_Item = {
    GetItemGUID = itemGUID,
    GetItemLink = function() return "[Steel Chestplate]" end,
}
env.C_Cursor = { GetCursorItem = function() return ui.cursor end }
env.GetCursorInfo = function() return ui.cursor and "item" end
env.ClearCursor = function() ui.cursor = nil end
env.IsModifiedClick = function() return ui.modified end
env.C_EquipmentSet = {
    GetEquipmentSetIDs = function() return { 1, 2 } end,
    GetEquipmentSetInfo = function(id) return id == 1 and "Tank" or "Healing" end,
    GetItemLocations = function(id) return id == 1 and { 100, 200, 400 } or { 100, 400 } end,
}
env.EquipmentManager_GetLocationData = function(value)
    if value == 100 then return { isBags = true, bag = 0, slot = 1 } end
    if value == 200 then return { isBags = true, isBank = true, bag = 1, slot = 1 } end
    if value == 400 then return { isPlayer = true, slot = 4 } end
    return {}
end

local function drop(_, button)
    if ui.cursor then
        sales[#sales + 1] = { "drop", itemGUID(ui.cursor), button }
        ui.cursor = nil
    else
        otherClicks = otherClicks + 1
    end
end
merchant:SetScript("OnMouseUp", drop)
merchant:SetScript("OnReceiveDrag", drop)
merchantItem:SetScript("OnClick", drop)
merchantItem:SetScript("OnDragStart", drop)
local originalBagClick = gear:GetScript("OnClick")
local bagHookCalls, merchantHookCalls = 0, 0
local function onBagClick() bagHookCalls = bagHookCalls + 1 end
local function onMerchantMouseUp() merchantHookCalls = merchantHookCalls + 1 end
gear:HookScript("OnClick", onBagClick)
merchant:HookScript("OnMouseUp", onMerchantMouseUp)

local function assertNativeScripts()
    assert(gear:GetScript("OnClick") == originalBagClick and gear.hooks.OnClick and gear.hooks.OnClick[1] == onBagClick,
        "vendor warnings leave Blizzard's native bag click and existing hooks intact")
    assert(merchant:GetScript("OnMouseUp") == drop and merchant.hooks.OnMouseUp and merchant.hooks.OnMouseUp[1] == onMerchantMouseUp,
        "vendor warnings leave Blizzard's merchant mouse-up and existing hooks intact")
    assert(merchant:GetScript("OnReceiveDrag") == drop and merchantItem:GetScript("OnClick") == drop
        and merchantItem:GetScript("OnDragStart") == drop,
        "vendor warnings leave Blizzard's drag and merchant item scripts intact")
end

ui:load("Modules/Bags.lua", ns)
assert(ns.modules.VendorSaleWarning, "FlareUI registers the sale warning at login"):Init()
merchant:Show()
clickBag(gear, "RightButton")
assert(#sales == 1 and not prompt and gear:GetScript("OnClick") == originalBagClick, "opt-out leaves native scripts intact")

db.warnSellSetGear = true
ns.Bags.VendorSaleWarning.Refresh()
assertNativeScripts()
hover(reagentProbe)
assert(reagentProbe:GetScript("OnClick") == originalProbeClick, "vendor warnings keep the fallback reagent slot native")
clickBag(gear, "RightButton")
assert(#sales == 1 and prompt and prompt.text:find("[Steel Chestplate]", 1, true), "right-click waits for confirmation")
assert(prompt.text:find("Tank", 1, true) and prompt.text:find("Healing", 1, true), "prompt names every set using the item")
answer(false)
assert(#sales == 1, "cancel keeps the item")
clickBag(gear, "RightButton")
answer(true)
assert(#sales == 2 and sales[2][1] == "right", "Sell resumes the original bag click exactly once")

clickBag(duplicate, "RightButton")
assert(#sales == 3 and not prompt, "another copy outside the set sells normally")
clickBag(gear, "LeftButton")
ui.modified = true
clickBag(gear, "RightButton")
ui.modified = false
assert(otherClicks == 2 and not prompt, "other bag interactions use their original scripts")

clickBag(gear, "RightButton")
items[0][1] = "replaced-guid"
answer(true)
assert(#sales == 3, "a slot that changed while the prompt was up never sells")
items[0][1] = "gear-guid"

ui.cursor = location(0, 1)
local beforeDropPrompt = promptCount
dropAt(merchant, "OnReceiveDrag")
dropAt(merchant, "OnMouseUp", "LeftButton")
assert(#sales == 3 and prompt and promptCount == beforeDropPrompt + 1,
    "both drag events share one confirmation")
answer(false)
assert(#sales == 3 and not ui.cursor, "cancel returns the dragged item")
ui.cursor = location(0, 1)
dropAt(merchant, "OnMouseUp", "LeftButton")
answer(true)
assert(#sales == 4 and sales[4][2] == "gear-guid" and sales[4][3] == "LeftButton", "Sell resumes the original drop")

ui.cursor = location("worn", 4)
dropAt(merchantItem, "OnClick", "LeftButton")
assert(prompt and #sales == 4, "set gear dragged from the character sheet also waits")
ui.cursor = location(1, 1)
answer(true)
assert(#sales == 4 and ui.cursor:GetBagAndSlot() == 1, "Sell cannot affect a different cursor item")
dropAt(merchantItem, "OnClick", "LeftButton")
assert(#sales == 5 and not prompt, "unrelated drops work normally")

local generated = slot(separate, 0, 1)
separateItems[2] = generated
env.ContainerFrame_GenerateFrame(separate)
clickBag(generated, "RightButton")
assert(prompt and #sales == 5, "slots generated while a vendor is open get the warning")
merchant.selectedTab = 2
answer(true)
assert(#sales == 5, "switching tabs invalidates the pending right-click sale")
ui.cursor = location(0, 1)
dropAt(merchant, "OnMouseUp", "LeftButton")
assert(prompt and #sales == 5, "the merchant background also warns on the Buyback tab")
answer(false)
merchant.selectedTab = 1

ui.cursor = location(0, 1)
dropAt(merchant, "OnReceiveDrag")
db.warnSellSetGear = false
ns.Bags.VendorSaleWarning.Refresh()
assert(not prompt and not ui.cursor and #sales == 5, "turning the option off cancels a pending sale")
assertNativeScripts()
db.warnSellSetGear = true
ns.Bags.VendorSaleWarning.Refresh()

ui.cursor = location(0, 1)
dropAt(merchantItem, "OnReceiveDrag")
assert(prompt and #sales == 5, "drag onto a vendor item opens the warning")
merchant:Hide()
assert(not prompt and not ui.cursor and #sales == 5, "closing the vendor cancels the sale")
assertNativeScripts()
local beforeUse, beforeBagHook, beforeVendorHook = otherClicks, bagHookCalls, merchantHookCalls
clickBag(gear, "RightButton")
assert(otherClicks == beforeUse + 1 and bagHookCalls == beforeBagHook + 1,
    "right-click uses an item through the unchanged native path after the vendor closes")
merchant:RunScript("OnMouseUp", "LeftButton")
assert(merchantHookCalls == beforeVendorHook + 1, "the merchant's original hook still runs after closing")

-- Baganator uses Blizzard's item-button template in its own pooled window.
-- The item button is outside Blizzard's ContainerFrames and sells on mouse-up.
local replacementBag = env.CreateFrame("Frame", "ReplacementBag", env.UIParent)
local replacementSlot = slot(replacementBag, 0, 1)
local originalReplacementClick = replacementSlot:GetScript("OnClick")
merchant:Show()
hover(replacementSlot, replacementBag)
assert(replacementSlot:GetScript("OnClick") == originalReplacementClick, "arming a bag catcher leaves the replacement slot untouched")
clickBag(replacementSlot, "RightButton")
assert(prompt and #sales == 5, "the first right-click in a replacement bag waits for confirmation")
assert(prompt.text:find("Tank", 1, true), "replacement-bag prompt names the equipment set")
answer(false)
assert(#sales == 5, "cancel in a replacement bag keeps the gear")
clickBag(replacementSlot, "RightButton")
answer(true)
assert(#sales == 6 and sales[6][1] == "right", "confirmed replacement-bag click executes the native sale once")
merchant:Hide()
hover(replacementSlot, replacementBag)
assert(replacementSlot:GetScript("OnClick") == originalReplacementClick,
    "the replacement slot keeps its script after closing")
assert(not env.FlareUIVendorBagSaleCatcher:IsVisible(), "no bag catcher stays active outside the vendor")

-- Exercise quest protection independently of the equipment-set option.
local questItems = { [0] = {}, [1] = { [1] = { questID = 23 } }, [5] = {} }
env.C_Container = { GetContainerItemQuestInfo = function(bag, index)
    return questItems[bag][index] or { isQuestItem = false, isActive = false }
end }
local questTitles = { [23] = "The Lost Satchel" }
env.C_QuestLog = { GetTitleForQuestID = function(id) return questTitles[id] end }

db.warnSellSetGear = false
db.warnSellQuestItems = false
merchant:Show()
local beforeQuestSales = #sales
clickBag(duplicate, "RightButton")
assert(not prompt and #sales == beforeQuestSales + 1, "quest warnings are opt-in")
beforeQuestSales = #sales

db.warnSellQuestItems = true
ns.Bags.VendorSaleWarning.Refresh()
clickBag(duplicate, "RightButton")
assert(#sales == beforeQuestSales and prompt and prompt.text:find("starts The Lost Satchel", 1, true),
    "quest starter right-click identifies the quest and waits")
answer(false)
assert(#sales == beforeQuestSales, "cancel keeps the quest starter")

questItems[1][1] = { isQuestItem = true, isActive = true }
ui.cursor = location(1, 1)
dropAt(merchant, "OnReceiveDrag")
assert(#sales == beforeQuestSales and prompt and prompt.text:find("quest item", 1, true),
    "a dragged quest item still warns when the client supplies no title")
answer(true)
assert(#sales == beforeQuestSales + 1 and not ui.cursor, "accept resumes the native quest-item drop")
beforeQuestSales = #sales

questItems[0][1] = { isQuestItem = true, questID = 23, isActive = true }
clickBag(replacementSlot, "RightButton")
assert(prompt and prompt.text:find("used for The Lost Satchel", 1, true)
    and not prompt.text:find("Tank", 1, true), "quest warnings also work in replacement bags with set protection off")
answer(false)
db.warnSellSetGear = true
ns.Bags.VendorSaleWarning.Refresh()
clickBag(replacementSlot, "RightButton")
assert(prompt and prompt.text:find("Tank", 1, true) and prompt.text:find("The Lost Satchel", 1, true),
    "an item with both protections displays both reasons in a single prompt")
items[0][1] = "new-gear-guid"
answer(true)
assert(#sales == beforeQuestSales, "a stale quest confirmation cannot sell the replacement item")
items[0][1] = "gear-guid"

questItems[1][1] = nil
clickBag(duplicate, "RightButton")
assert(not prompt and #sales == beforeQuestSales + 1, "unrelated items sell normally with both warnings enabled")
beforeQuestSales = #sales

-- The quest log can expose an exact usable-item link without flagging the bag slot.
env.C_Item.GetItemID = function(loc) return loc:GetBagAndSlot() == 1 and 789 or 456 end
env.C_QuestLog.GetNumQuestLogEntries = function() return 2 end
env.C_QuestLog.GetInfo = function(index)
    if index == 1 then return { isHeader = true } end
    return { title = "A Signal for Help", questID = 24 }
end
env.GetQuestLogSpecialItemInfo = function(index)
    assert(index == 2, "quest headers do not have usable items")
    return "|Hitem:789:0|h[Signal Flare]|h"
end
ui:emit("QUEST_LOG_UPDATE")
clickBag(duplicate, "RightButton")
assert(prompt and #sales == beforeQuestSales and prompt.text:find("used for A Signal for Help", 1, true),
    "an exact quest-log item link warns even when the bag slot has no quest flag")
answer(false)

-- A normally sellable weapon can be an active turn-in without either a bag flag or use-item link.
local writTitle = "Craftsman's Writ: Heavy Bronze Mace"
local maceName = "Heavy Bronze Mace"
local maceSlot = slot(replacementBag, 1, 1)
env.C_Item.GetItemID = function() return 3491 end
env.C_Item.GetItemName = function() return maceName end
env.C_Item.GetItemLink = function() return "[Heavy Bronze Mace]" end
env.GetQuestLogSpecialItemInfo = function() end
env.QUEST_ITEMS_NEEDED = "%s：%d/%d"
local visibleQuest = true
env.C_QuestLog.GetInfo = function(index)
    if index == 1 then return { isHeader = true } end
    if visibleQuest then return { title = writTitle, questID = 94224 } end
end
local objectives = {
    { type = "item", text = writTitle .. "：1/1", numRequired = 1, numFulfilled = 1, finished = true },
    { type = "item", text = maceName .. "：1/1", numRequired = 1, numFulfilled = 1, finished = true },
}
env.C_QuestLog.GetQuestObjectives = function(id)
    if id == 94224 then return objectives end
end
beforeQuestSales = #sales
clickBag(maceSlot, "RightButton")
assert(prompt and #sales == beforeQuestSales and prompt.text:find(writTitle, 1, true)
    and prompt.text:find("[Heavy Bronze Mace]", 1, true), "a ready-to-turn-in mace pauses sale in a replacement bag")
answer(false)

objectives[2].text = maceName .. ": 1/1"
ui:emit("QUEST_LOG_UPDATE")
clickBag(maceSlot, "RightButton")
assert(prompt and #sales == beforeQuestSales, "the older count-after-name layout still matches")
answer(false)

visibleQuest = false
env.C_QuestLog.GetNumQuestLogEntries = function() return 1 end
env.C_QuestLog.GetNumQuestWatches = function() return 1 end
env.C_QuestLog.GetQuestIDForQuestWatchIndex = function() return 94224 end
env.C_QuestLog.GetLogIndexForQuestID = function() end
env.C_QuestLog.GetTitleForQuestID = function(id) if id == 94224 then return writTitle end end
objectives[2].text = "1/1 " .. maceName
ui.cursor = location(1, 1)
dropAt(merchant, "OnReceiveDrag")
assert(prompt and #sales == beforeQuestSales and prompt.text:find(writTitle, 1, true),
    "a tracked quest still protects an objective item when its log header is collapsed")
answer(false)
assert(not ui.cursor and #sales == beforeQuestSales, "cancel returns the turn-in item without selling")

objectives[2].type = "object"
ui:emit("QUEST_LOG_UPDATE")
clickBag(maceSlot, "RightButton")
assert(not prompt and #sales == beforeQuestSales + 1, "an object objective with the same text does not warn")
objectives[2].type = "item"
objectives[2].text = "Greater " .. maceName .. "：1/1"
ui:emit("QUEST_LOG_UPDATE")
clickBag(maceSlot, "RightButton")
assert(not prompt and #sales == beforeQuestSales + 2, "a longer item name containing the selected item does not warn")

clickBag(gear, "RightButton")
assert(prompt, "set gear still warns after quest changes")
ui.combat = true
ui:emit("PLAYER_REGEN_DISABLED")
assert(not prompt and not env.FlareUIVendorBagSaleCatcher:IsVisible() and #sales == beforeQuestSales + 2,
    "entering combat cancels the pending sale and removes its catcher")
assertNativeScripts()
ui.combat = false
ui:emit("PLAYER_REGEN_ENABLED")
clickBag(gear, "RightButton")
assert(prompt and #sales == beforeQuestSales + 2, "protection resumes after combat with the merchant still open")
answer(false)
merchant:Hide()

print("PASS: opt-in confirmations for equipment set gear and quest items")
