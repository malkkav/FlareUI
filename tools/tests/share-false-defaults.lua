local setup = dofile("tools/tests/fixtures/settings-addon.lua")
local ui, ns = setup()
local E, db = ui.env, ns.db
db.sv = { profiles = { Main = {} }, profileKeys = { player = "Main" } }
db.keys = { profile = "Main" }
function db:GetCurrentProfile() return self.keys.profile end
function db:GetProfiles()
    local names = {}
    for name in pairs(self.sv.profiles) do names[#names + 1] = name end
    return names
end
function db:SetProfile(name)
    self.keys.profile = name
    self.sv.profiles[name] = self.sv.profiles[name] or {}
end
ns.defaults.profile.shared = { off = false, on = true, count = 3, name = "a", nested = { off = false } }
ui:load("Settings/Pages/Advanced.lua", ns)

local function check(ok, message) assert(ok, message) end
local function import(shared)
    ns.ShowImportPicker({ addon = "FlareUI", name = "Shared", profile = { shared = shared } })
    E.FlareUI_ImportPicker.import:Click()
    return db.sv.profiles[db:GetCurrentProfile()].shared
end

local wrong = import({
    off = "text", on = "text", count = "text", name = 5,
    nested = { off = { 1 } },
    extra = "kept",
})
check(wrong.off == nil, "a string over a false default is dropped")
check(wrong.on == nil, "a string over a true default is dropped")
check(wrong.count == nil and wrong.name == nil, "other wrong types are dropped")
check(wrong.nested.off == nil, "a table over a nested false default is dropped")
check(wrong.extra == "kept", "a key the defaults don't name stays")

local good = import({ off = true, on = false, count = 0, nested = { off = true } })
check(good.off == true and good.on == false and good.count == 0 and good.nested.off == true, "right types stay")

print("PASS: share sanitizer checks false defaults")
