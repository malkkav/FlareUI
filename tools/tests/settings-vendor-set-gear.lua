-- The sale warnings are independent, live Vendor options.
local function noop() end
local env = setmetatable({
    LibStub = noop,
    CreateFrame = function() return { RegisterEvent = noop, SetScript = noop } end,
}, { __index = _G })
local refreshed = 0
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    db = { profile = { tweaks = { bagModule = true } } },
    Bags = { VendorSaleWarning = { Refresh = function() refreshed = refreshed + 1 end } },
}
for _, path in ipairs({ "Settings/Copy.lua", "Settings/Registry.lua", "Settings/Fonts.lua", "Settings/Pages/BagsLooting.lua" }) do
    setfenv(assert(loadfile(path)), env)("FlareUI", ns)
end

local settings = ns.Settings
local row = assert(settings.rows["qol.warnSellSetGear"], "Vendor has a setting for the equipment-set warning")
assert(row.module == "bl" and row.tab == "bank" and row.section == "qol.vendor" and row.kind == "toggle")
assert(not row:IsDisabled() and not row:Get(), "an existing profile can opt in")
assert(row:Label():find("Set Gear", 1, true) and row:Description():find("drag", 1, true),
    "the setting describes the sale warning in the Vendor panel")

local tweaks = ns.db.profile.tweaks
row:Set(true)
assert(tweaks.warnSellSetGear == true and row:Get() == true and not tweaks.sellJunk and settings:PendingCount() == 0,
    "enabling the warning takes effect without a reload or changing Auto Sell Junk")
row:Set(false)
assert(tweaks.warnSellSetGear == false and row:Get() == false and settings:PendingCount() == 0,
    "disabling the warning takes effect without a reload")
assert(refreshed == 2, "both changes refresh protection at an open vendor")

local quest = assert(settings.rows["qol.warnSellQuestItems"], "Vendor has a setting for the quest-item warning")
assert(quest.module == "bl" and quest.tab == "bank" and quest.section == "qol.vendor" and quest.kind == "toggle")
assert(row.half and quest.half, "both vendor warnings use the same two-column row")
assert(not quest:IsDisabled() and not quest:Get(), "the quest warning is off in existing profiles")
assert(quest:Label() == "Warn Before Selling Quest Items" and quest:Description():find("drag", 1, true),
    "the Vendor setting describes the quest-item warning")

quest:Set(true)
assert(tweaks.warnSellQuestItems == true and quest:Get() == true and not row:Get(),
    "the quest warning can be enabled by itself")
row:Set(true)
quest:Set(false)
assert(tweaks.warnSellQuestItems == false and quest:Get() == false and row:Get() == true,
    "turning off the quest warning leaves the equipment-set warning enabled")
assert(not tweaks.sellJunk and settings:PendingCount() == 0 and refreshed == 5,
    "each warning updates at an open vendor without reloading or changing Auto Sell Junk")

print("PASS: equipment-set and quest-item sale warnings are independent opt-in Vendor settings")
