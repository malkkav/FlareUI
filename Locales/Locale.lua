local _, ns = ...

--------------------------------------------------
-- LOCALIZATION
-- ns.L["English text"]: the phrase in the player's language, falling back to the English key.
-- Locales/<locale>.lua hold CurseForge packager keywords; Locales/enUS.lua (not loaded) is the phrase
-- list. Loads first: some files build labels as they load.
--------------------------------------------------
local L = setmetatable({}, {
    __index = function(_, key) return key end,
})
ns.L = L
