std = "lua51"
exclude_files = { "Libs/**" }
quiet = 1
codes = true

-- Start with correctness checks that can run without a WoW API global list.
only = {
    "121", "122",         -- Writes to read-only Lua globals or fields.
    "221", "321", "341",  -- Reads or mutations of uninitialized locals.
    "314",                -- Duplicate table keys.
    "511", "512",         -- Unreachable code and loops that can run only once.
    "531", "532",         -- Mismatched assignment lengths.
    "571", "582",         -- Missing negative loop steps and ambiguous negation.
}

-- Any flight pin supplies the shared provider, so one iteration is enough.
files["Modules/FlightDestinations.lua"].ignore = { "512" }
