-- Parse every tracked or new Lua file without executing addon code.
local files = assert(io.popen('git ls-files --cached --others --exclude-standard -- "*.lua"'))
local count = 0
for path in files:lines() do
    assert(loadfile(path))
    count = count + 1
end
files:close()
assert(count > 0, 'Run from the repository root')
print('PASS: parsed ' .. count .. ' Lua files')
