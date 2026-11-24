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
return H
