-- A language's own shorter names for the Nameplates tabs (Russian) stand only in that language
local function load(locale)
    local env = setmetatable({ GetLocale = function() return locale end }, { __index = _G })
    env._G = env
    local ns = {}
    for _, file in ipairs({ "Locales/Locale.lua", "Locales/ruRU.lua" }) do
        setfenv(assert(loadfile(file)), env)("FlareUI", ns)
    end
    return ns.L
end
local ru, en = load("ruRU"), load("enUS")
for _, name in ipairs({ "Plate", "Extras", "Cast Bar", "Targeting" }) do
    assert(rawget(ru, name .. " (tab)"), name)
    assert(rawget(en, name .. " (tab)") == nil and en[name] == name)
end
assert(ru["Extras"] ~= ru["Extras (tab)"], "the full word stays everywhere else")
print("PASS: shorter tab names stay in their language")
