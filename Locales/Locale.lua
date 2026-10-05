local _, ns = ...

--------------------------------------------------
-- LOCALIZATION
-- ns.L["English text"] is the text in the player's language. English is the base language: a phrase
-- with no translation (and every phrase on an English client) falls back to its own key, so the
-- English text in the code is always what shows when nothing else is known.
-- The translations live in Locales/<locale>.lua, one file per language. Each holds a CurseForge
-- packager keyword that the packager replaces with the phrases translated on CurseForge's
-- localization page; Locales/enUS.lua (not loaded) is the phrase list to import there.
-- Loaded before everything else: some option tables and labels are built as their files load.
--------------------------------------------------
local L = setmetatable({}, {
    __index = function(_, key) return key end,
})
ns.L = L
ns.LOCALE = GetLocale()
