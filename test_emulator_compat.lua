-- test_emulator_compat.lua
-- Regression tests for the BizHawk compatibility shim.

local tests = {}

local global_names = {
    "FCEU",
    "emu",
    "memory",
    "mainmemory",
    "joypad",
    "input",
    "console",
    "ppu",
    "rom",
    "AND",
    "BIT",
    "DW_EMULATOR_COMPAT",
}

local saved_globals = {}
local saved_loaded = package.loaded["emulator_compat"]

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

local function assert_contains(text, needle, message)
    if not text:find(needle, 1, true) then
        error(string.format("%s: expected to find %q in %q", message, needle, text), 2)
    end
end

local function save_globals()
    for _, name in ipairs(global_names) do
        saved_globals[name] = _G[name]
    end
end

local function restore_globals()
    for _, name in ipairs(global_names) do
        _G[name] = saved_globals[name]
    end
    package.loaded["emulator_compat"] = saved_loaded
end

local function make_fake_ines_file()
    local bytes = {
        [0] = 0x4E,
        [1] = 0x45,
        [2] = 0x53,
        [3] = 0x1A,
        [4] = 0x02,
        [5] = 0x01,
        [0x10] = 0xC0,
        [0x11] = 0xDE,
    }

    for map_id = 0, 29 do
        local base = 0x002A + map_id * 5
        local ptr = 0x8400 + map_id * 0x10
        bytes[base] = ptr % 256
        bytes[base + 1] = math.floor(ptr / 256)
        bytes[base + 2] = 9
        bytes[base + 3] = 9
        bytes[base + 4] = 0
    end

    return bytes
end

local function make_prg_only_domain(file_bytes)
    local prg = {}
    for address, value in pairs(file_bytes) do
        if address >= 0x10 then
            prg[address - 0x10] = value
        end
    end
    return prg
end

local function setup_bizhawk(domains, domain_names)
    save_globals()
    package.loaded["emulator_compat"] = nil

    local logs = {}
    _G.FCEU = nil
    _G.emu = {
        frameadvance = function() end,
    }
    _G.memory = {
        getmemorydomainlist = function()
            return domain_names
        end,
        read_u8 = function(address, domain)
            local domain_bytes = domains[domain]
            if not domain_bytes then
                error("unknown domain: " .. tostring(domain))
            end
            return domain_bytes[address] or 0
        end,
        write_u8 = function() end,
    }
    _G.mainmemory = {
        read_u8 = function()
            return 0
        end,
        write_u8 = function() end,
    }
    _G.joypad = {
        get = function()
            return {}
        end,
        set = function() end,
    }
    _G.input = {
        get = function()
            return {}
        end,
    }
    _G.console = {
        log = function(message)
            logs[#logs + 1] = tostring(message)
        end,
    }
    _G.ppu = nil
    _G.rom = nil
    _G.AND = nil
    _G.BIT = nil
    _G.DW_EMULATOR_COMPAT = nil

    return logs
end

function tests.rom_adapter_uses_identity_for_full_ines_rom_domain()
    local file_bytes = make_fake_ines_file()
    local logs = setup_bizhawk({ROM = file_bytes}, {"ROM"})

    require "emulator_compat"

    local throne_base = 0x002A + 0x05 * 5
    assert_equal(rom.readbyte(0), 0x4E, "iNES header byte should be visible")
    assert_equal(rom.readbyte(0x10), 0xC0, "first PRG byte should use file offset 0x10")
    assert_equal(rom.readbyte(throne_base + 2), 9, "throne room width byte should come from the metadata table")
    assert_equal(rom.readbyte(throne_base + 3), 9, "throne room height byte should come from the metadata table")
    assert_contains(table.concat(logs, "\n"), "ROM (identity", "full iNES ROM domain should use identity mapping")

    restore_globals()
end

function tests.rom_adapter_uses_prg_offset_for_headerless_rom_domain()
    local file_bytes = make_fake_ines_file()
    local prg_only = make_prg_only_domain(file_bytes)
    local logs = setup_bizhawk({ROM = prg_only}, {"ROM"})

    require "emulator_compat"

    local throne_base = 0x002A + 0x05 * 5
    assert_equal(rom.readbyte(0), 0x4E, "adapter should synthesize the iNES magic header")
    assert_equal(rom.readbyte(0x10), 0xC0, "file offset 0x10 should map to PRG offset 0")
    assert_equal(rom.readbyte(throne_base + 2), 9, "headerless ROM domain should still read the correct metadata width")
    assert_equal(rom.readbyte(throne_base + 3), 9, "headerless ROM domain should still read the correct metadata height")
    assert_contains(table.concat(logs, "\n"), "ROM (prg_offset", "headerless ROM domain should use PRG-offset mapping")

    restore_globals()
end

function tests.cart_work_ram_reads_system_bus_addresses()
    local logs = setup_bizhawk({
        ["System Bus"] = {
            [0x600C] = 4,
            [0x600D] = 7,
        },
    }, {"System Bus"})

    require "emulator_compat"

    assert_equal(memory.readbyte(0x600C), 4, "cart work RAM X byte should read from System Bus CPU address")
    assert_equal(memory.readbyte(0x600D), 7, "cart work RAM Y byte should read from System Bus CPU address")
    assert_contains(table.concat(logs, "\n"), "cart RAM adapter using memory domain: System Bus", "cart RAM adapter should log selected domain")

    restore_globals()
end

function tests.cart_work_ram_supports_prg_ram_offset_domains()
    local logs = setup_bizhawk({
        ["PRG RAM"] = {
            [0x000C] = 4,
            [0x000D] = 7,
        },
    }, {"PRG RAM"})

    require "emulator_compat"

    assert_equal(memory.readbyte(0x600C), 4, "cart work RAM X byte should map to PRG RAM offset")
    assert_equal(memory.readbyte(0x600D), 7, "cart work RAM Y byte should map to PRG RAM offset")
    assert_contains(table.concat(logs, "\n"), "PRG RAM (cart_offset", "cart RAM adapter should support offset domains")

    restore_globals()
end

local failures = 0
local total = 0

for name, fn in pairs(tests) do
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        io.write(string.format("PASS  %s\n", name))
    else
        failures = failures + 1
        io.write(string.format("FAIL  %s: %s\n", name, tostring(err)))
        restore_globals()
    end
end

restore_globals()

io.write(string.format("Ran %d Lua unit tests\n", total))

if failures > 0 then
    os.exit(1)
end
