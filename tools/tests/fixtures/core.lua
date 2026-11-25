-- The whole of Core.lua, loaded with the client doubles it needs. Returns the fixture (its env and timers) and ns.
-- setup(env, ns), when given, runs just before Core.lua does: client doubles a test needs at load time.
return function(profile, setup)
    local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
    local env = ui.env
    local ns = {
        L = setmetatable({}, { __index = function(_, key) return key end }),
        db = { global = {}, profile = profile or { fonts = {} } },
    }
    local editMode = { IsInEditMode = function() return false end, SettingType = { Dropdown = 1, Checkbox = 2 } }
    env.LibStub = function(name) return name == "FlareEditMode" and editMode or {} end
    env.GetLocale = function() return "enUS" end
    env.canaccessvalue = function() return true end
    env.CopyTable = function(t)
        local copy = {}
        for key, value in pairs(t) do copy[key] = value end
        return copy
    end
    env.AuraContainerSortMethod = { Default = 1, AuraInstanceIDOnly = 2, ExpirationOnly = 3, Expiration = 4, NameOnly = 5, Name = 6 }
    env.AuraContainerSortDirection = { Normal = 1, Reverse = 2 }
    env.AuraUtil = { AuraUpdateChangedType = { Buff = 1, Dispel = 2 } }
    env.NUM_CHAT_WINDOWS = 1
    if setup then setup(env, ns) end
    ui:load("Core.lua", ns)
    return ui, ns
end
