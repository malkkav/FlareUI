-- Minimal loader for exercising real addon functions with deterministic client doubles.
local H = {}
function H.read(path)
    local f = assert(io.open(path)); local s = f:read('*a'); f:close(); return s
end
function H.section(source, first, last)
    local a = assert(source:find(first, 1, true), first)
    local b = assert(source:find(last, a, true), last)
    return source:sub(a, b - 1)
end
function H.load(code) return assert((loadstring or load)(code))() end
return H
