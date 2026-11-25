-- Minimal loader for exercising real addon functions with deterministic client doubles.
local H = {}
function H.read(path)
    local f = assert(io.open(path, 'rb')); local s = f:read('*a'); f:close()
    return (s:gsub('\r\n', '\n'))   -- (#183: the cut marks below never depend on a file's line endings)
end
function H.section(source, first, last)
    local a = assert(source:find(first, 1, true), first)
    local b = assert(source:find(last, a, true), last)
    return source:sub(a, b - 1)
end
function H.load(code) return assert((loadstring or load)(code))() end

-- Keep every selected source line at its original line number so LuaCov
-- attributes it to the module. Doubles and assertions run in the caller.
function H.loadSections(path, ranges, env, exports)
    local source = H.read(path)
    local parts, previousEnd = {}, 1
    for _, range in ipairs(ranges) do
        local start = assert(source:find(range[1], previousEnd, true), range[1])
        local finish = assert(source:find(range[2], start + #range[1], true), range[2])
        local _, gap = source:sub(previousEnd, start - 1):gsub("\n", "")
        parts[#parts + 1] = string.rep("\n", gap)
        parts[#parts + 1] = source:sub(start, finish - 1)
        previousEnd = finish
    end
    if exports then
        local _, gap = source:sub(previousEnd):gsub("\n", "")
        parts[#parts + 1] = string.rep("\n", gap + 1)
        parts[#parts + 1] = "return " .. exports
    end
    return setfenv(assert(loadstring(table.concat(parts), "@" .. path)), env)()
end
-- The whole of Core.lua into env, with ns (no part cut out, #185). The doubles a test put in ns before
-- win over what Core.lua sets; libraries the test's LibStub doesn't know are empty while it loads.
function H.loadCore(env, ns)
    local doubles = {}
    for key, value in pairs(ns) do doubles[key] = value end
    local libStub = env.LibStub
    local editMode = { IsInEditMode = function() return false end, SettingType = { Dropdown = 1, Checkbox = 2 } }
    env.LibStub = function(name, ...)
        if libStub then
            local ok, lib = pcall(libStub, name, ...)
            if ok and lib then return lib end
        end
        if name == "FlareEditMode" then return editMode end
        return {}
    end
    env.GetLocale = env.GetLocale or function() return "enUS" end
    env.NUM_CHAT_WINDOWS = env.NUM_CHAT_WINDOWS or 1
    env.CopyTable = env.CopyTable or function(t) local c = {} for k, v in pairs(t) do c[k] = v end return c end
    env.ns = ns
    setfenv(assert(loadfile("Core.lua")), env)("FlareUI", ns)
    env.LibStub = libStub
    for key, value in pairs(doubles) do ns[key] = value end
end
return H
