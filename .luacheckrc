-- Luacheck configuration for FCEUX Lua scripts
-- See: https://luacheck.readthedocs.io/en/stable/config.html

-- Use Lua 5.1 (FCEUX uses LuaJIT which is 5.1 compatible)
std = "lua51"

-- FCEUX provides these globals
globals = {
    -- Emulator control
    "FCEU",

    -- Memory access
    "memory",
    "rom",
    "ppu",

    -- Input
    "joypad",
    "input",

    -- Graphics overlay
    "gui",
    "emu",

    -- Bitwise operations (FCEUX global functions)
    "AND",
    "OR",
    "XOR",
    "BIT",
}

-- LuaJIT FFI (used by tolk.lua)
read_globals = {
    "ffi",
}

-- Allow unused arguments starting with underscore
unused_args = false

-- Don't complain about unused loop variables
unused_secondaries = false

-- Max line length (0 = unlimited)
max_line_length = 120

-- Ignore certain warnings
ignore = {
    "212",  -- Unused argument (common in callbacks)
    "213",  -- Unused loop variable
}
