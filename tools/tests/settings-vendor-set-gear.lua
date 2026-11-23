-- The equipment-set warning is an independent, live Vendor option.
local function noop() end
local env = setmetatable({
    LibStub = noop,
    CreateFrame = function() return { RegisterEvent = noop, SetScript = noop } end,
}, { __index = _G })
local refreshed = 0
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    db = { profile = { tweaks = { bagModule = true } } },
    Bags = { SellSetGear = { Refresh = function() refreshed = refreshed + 1 end } },
}
for _, path in ipairs({ "Settings/Copy.lua", "Settings/Registry.lua", "Settings/Fonts.lua", "Settings/Pages/BagsLooting.lua" }) do
    setfenv(assert(loadfile(path)), env)("FlareUI", ns)
end

local settings = ns.Settings
local row = assert(settings.rows["qol.warnSellSetGear"], "Vendor has a setting for the equipment-set warning")
assert(row.module == "bl" and row.tab == "bags" and row.section == "qol.vendor" and row.kind == "toggle")
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
assert(refreshed == 2, "both toggles refresh protection at an open vendor")

print("PASS: the equipment-set sale warning is an opt-in Vendor setting")
