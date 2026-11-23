local ui = dofile("tools/tests/fixtures/settings-ui.lua").new()
local env = ui.env
env.WorldFrame = env.CreateFrame("Frame", "WorldFrame", env.UIParent)
local widget = env.CreateFrame("Frame", nil, env.UIParent)
env.GetMouseFoci = function() return { ui.overUI and widget or env.WorldFrame } end
env.UnitExists = function(unit) return unit == "mouseover" and ui.hoverUnit end
env.UnitChannelInfo = function() return ui.channeling end
env.IsModifierKeyDown = function() return ui.modified end
env.IsMouseButtonDown = function(button) return button == "RightButton" and ui.held end
env.canaccessvalue = function() return true end
env.GetInventoryItemID = function() return not ui.noPole and 123 end
env.Enum = { ItemClass = { Weapon = 2 }, ItemWeaponSubclass = { Fishingpole = 20 } }
env.C_Item = { GetItemInfoInstant = function() return nil, nil, nil, nil, nil, 2, 20 end }
env.C_Spell = {
    GetSpellName = function(id) if id == 7620 or id == 7731 then return "Fishing" end end,
    GetSpellInfo = function(name) if name == "Fishing" then return true end end,
}
env.C_Timer.NewTimer = env.C_Timer.NewTicker
local bound, driver = nil, nil
env.RegisterStateDriver = function(owner, state, condition)
    assert(state == "combat" and condition == "[combat] combat; peace")
    driver = owner
end
env.SetOverrideBindingClick = function(owner, priority, key, button)
    assert(not ui.combat and owner == driver and priority and key == "BUTTON2")
    bound = button
end
env.ClearOverrideBindings = function(owner)
    assert(not ui.combat and owner == driver)
    bound = nil
end
local volumes = { Sound_MusicVolume = "0.10", Sound_AmbienceVolume = "0.5", Sound_SFXVolume = "0.2" }
env.GetCVar = function(key) return volumes[key] end
env.SetCVar = function(key, value) volumes[key] = value end
local db = { fishCast = true, fishSound = true }
local global = { fishingSounds = { Sound_MusicVolume = "0.7" } }
local ns = { db = { profile = { tweaks = db }, global = global },
    IsGamepadUI = function() return ui.gamepad end }
ui:load("Modules/Fishing.lua", ns)
ui:emit("PLAYER_LOGIN")
assert(volumes.Sound_MusicVolume == "0.7" and not global.fishingSounds)
local button = env.FlareUI_FishingCast
assert(button:GetAttribute("type") == "spell" and button:GetAttribute("useOnKeyDown") == false)
assert(driver:GetAttribute("_onstate-combat"):find("ClearBindings", 1, true))

local function click()
    ui:emit("GLOBAL_MOUSE_DOWN", "RightButton")
    ui:emit("GLOBAL_MOUSE_UP", "RightButton")
end
for _, condition in ipairs({ "overUI", "hoverUnit", "modified", "channeling", "noPole", "gamepad", "combat" }) do
    ui[condition] = true
    click()
    assert(not bound, condition .. " must not arm a fishing cast")
    ui[condition] = false
end
ui.time = 100
ui:emit("GLOBAL_MOUSE_DOWN", "RightButton")
ui.time = 100.3
ui:emit("GLOBAL_MOUSE_UP", "RightButton")
assert(not bound, "a held click is a camera action")
ui:emit("GLOBAL_MOUSE_DOWN", "RightButton")
ui.cursorX = 20
ui:emit("GLOBAL_MOUSE_UP", "RightButton")
assert(not bound, "camera travel disarms")
click()
assert(bound == "FlareUI_FishingCast" and button:GetAttribute("spell") == "Fishing")
ui.held = true
ui:flushTimers()
assert(bound, "an already held second click waits for release")
ui.held = false
button:RunScript("PostClick")
assert(not bound)
ui:flushTimers()
ui.time = 101
click()
ui:emit("GLOBAL_MOUSE_DOWN", "LeftButton")
assert(not bound, "another button breaks the double-click pair")
ui.time = 102
click()
ui:flushTimers()
assert(not bound, "an unused binding expires")

ui:emit("UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-1", 999)
assert(volumes.Sound_MusicVolume == "0.7")
ui:emit("UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-2", 7731)
assert(volumes.Sound_MusicVolume == "0.21" and volumes.Sound_AmbienceVolume == "0.15" and volumes.Sound_SFXVolume == "0.80")
assert(global.fishingSounds.Sound_MusicVolume == "0.7")
ui:emit("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-2", 7731)
ui:emit("UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-3", 7620)
ui:flushTimers()
assert(volumes.Sound_MusicVolume == "0.21", "recasting cancels the idle restoration")
ui:emit("PLAYER_STARTED_MOVING")
assert(volumes.Sound_MusicVolume == "0.7" and volumes.Sound_AmbienceVolume == "0.5" and volumes.Sound_SFXVolume == "0.2")
ui:emit("UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-4", 7620)
ui:emit("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-4", 7620)
ui:flushTimers()
assert(not global.fishingSounds and volumes.Sound_MusicVolume == "0.7")
ui.combat = true
db.fishCast, db.fishSound = false, false
ns.Fishing:Apply()
ui.combat = false
ui:emit("PLAYER_REGEN_ENABLED")
click()
assert(not bound)
print("PASS: fishing double-click guard and restoration of the player's sound settings")
