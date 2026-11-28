-- Run from the repository root: luajit tools/tests/bags-no-open-all.lua
-- FlareUI never opens all the bags itself (GitHub #200, 11-26). Blizzard's OpenAllBags run from addon
-- code builds the crafting bag's window (ContainerFrame6) and its button pool as FlareUI's; the next
-- bank visit reads that pool, its bank type turns FlareUI's, and every item use from the bags is blocked
-- until /reload. The guild bank and Open with Character Window did that, and were removed.
local BANNED = { "OpenAllBags", "CloseAllBags", "ToggleAllBags", "OpenBackpack", "CloseBackpack", "ToggleBackpack" }
-- every Lua file the game loads, from the TOC (libraries and locales left out)
local files = {}
for line in io.lines("FlareUI.toc") do
    local path = line:gsub("\r$", ""):gsub("\\", "/")
    if path:find("%.lua$") and not path:find("^Libs/") and not path:find("^Locales/") then files[#files + 1] = path end
end
assert(#files > 20, "the addon's files were found")

local found = {}
for _, path in ipairs(files) do
    local n = 0
    for line in io.lines(path) do
        n = n + 1
        local code = line:gsub("%-%-.*$", ""):gsub('"[^"]*"', '""')
        for _, name in ipairs(BANNED) do
            -- a call, not a field or a hook name in a string (hooksecurefunc("ToggleBackpack_Combined", ...))
            if code:find("[^%w_%.:]" .. name .. "%s*%(") or code:find("^" .. name .. "%s*%(") then
                found[#found + 1] = ("%s:%d %s"):format(path, n, name)
            end
        end
    end
end
assert(#found == 0, "FlareUI calls Blizzard's bag openers: " .. table.concat(found, ", "))
print("PASS: FlareUI never opens or closes all the bags itself")
