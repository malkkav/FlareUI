local H = dofile("tools/tests/perf-helpers.lua")
local source = H.read("Settings/Pages/Advanced.lua")
local s = assert(source:find("local MAX_NUMBER", 1, true))
local e = assert(source:find("\nlocal function ExportString", s, true))
local loader = loadstring or load
local chunk = assert(loader(source:sub(s, e) .. "\nreturn DropWrongTypes"))
local DropWrongTypes = chunk()

local function check(ok, message) assert(ok, message) end

local defaults = { off = false, on = true, count = 3, name = "a", nested = { off = false } }
local profile = {
    off = "text", on = "text", count = "text", name = 5,
    nested = { off = { 1 } },
    extra = "kept",
}
DropWrongTypes(profile, defaults)
check(profile.off == nil, "a string over a false default is dropped")
check(profile.on == nil, "a string over a true default is dropped")
check(profile.count == nil and profile.name == nil, "other wrong types are dropped")
check(profile.nested.off == nil, "a table over a nested false default is dropped")
check(profile.extra == "kept", "a key the defaults don't name stays")

local good = { off = true, on = false, count = 0, nested = { off = true } }
DropWrongTypes(good, defaults)
check(good.off == true and good.on == false and good.count == 0 and good.nested.off == true, "right types stay")

print("PASS: share sanitizer checks false defaults")
