local _, flare = ...

--------------------------------------------------
-- DOT ENGINE: its namespace
-- The files in this folder are Does It Die Advanced's tracking (MIT, LICENSES/DoesItDieAdvanced.txt), kept as they
-- were written: they share this table, as they shared their addon's, and know nothing of FlareUI's. What they
-- expect from the parts left behind (the options window, the drawing) is stood in for here; FlareUI's side is
-- Modules/DotTracker.lua, which starts the engine and reads it.
--------------------------------------------------
local E = {}
flare.DotEngine = E

local function noop() end

-- the engine's drawing hooks: DotTracker.lua puts FlareUI's in their place
E.refresh = noop
E.playFlash = noop
-- (its learned tick list asks for a school's colour: the drawing's, set by DotTracker.lua)
E.display = { schoolColors = {} }
